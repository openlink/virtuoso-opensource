--
--  tvvec_literal_ids.sql
--
--  What a vector index embeds, and in what form it keeps the result.
--
--  1. An RDF selector embeds literals, and only literals.  The backfill
--     enumerates <subject, literal> straight from RDF_QUAD and resolves each
--     literal's text from its RDF_OBJ id -- which is where the long-literal
--     (RO_LONG) and typed/language-tagged cases are handled -- so:
--       * an IRI object or a blank node must never reach the model as the
--         string "urn:..." or "nodeID://b..." (both did);
--       * a subject with an IRI and a literal embeds the literal, whichever
--         sorts first as a string;
--       * a subject with several literals gets exactly one row;
--       * an empty literal is not embedded at all.
--  2. A refresh re-embeds exactly the rows whose literal changed, adds the new
--     ones and removes the vanished ones -- identity by RDF_OBJ id, not text.
--  3. A bulk-built index whose graph no longer agrees with its data is rebuilt
--     by the next refresh even when nothing needs embedding.
--  4. Embeddings are stored as DV_ARRAY_OF_FLOAT (tag 202) whatever form they
--     arrive in, and VEC_INDEX_EMBEDDINGS_TO_FLOAT converts a table written in
--     the old DV_ARRAY_OF_POINTER form (tag 193) in place.
--  5. fvector()/make_array (n, 'float') report their real length, and
--     isvector () accepts every vector constructor's result.
--  6. A rebuild run with logging off stays unlogged across its own internal
--     commit: the transaction log does not grow by the graph's size.  (A
--     regression guard -- see the section for why it held already.)
--  7. With the ONNX plugin: embeddings come back as DV_ARRAY_OF_FLOAT, a batch
--     is bounded per vector (not per batch), and a helper error reaches SQL
--     intact rather than read out of a freed, unterminated buffer.
--
--  The model is an in-core test_embedding: it puts 1.0 at the positions named
--  by the first two integers in the text, so "alpha 1 2" -> positions 1 and 2.
--  Every literal below carries its own pair, which is what lets an assertion
--  say exactly WHICH text was embedded for a subject, not merely that
--  something was.
--
--  Every threshold is computed in SQL and asserted as 1 or 0: isql's $GT and
--  $LT compare as strings.
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2026 OpenLink Software
--
--  This project is free software; you can redistribute it and/or modify it
--  under the terms of the GNU General Public License as published by the
--  Free Software Foundation; only version 2 of the License, dated June 1991.
--
--  This program is distributed in the hope that it will be useful, but
--  WITHOUT ANY WARRANTY; without even the implied warranty of
--  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
--  General Public License for more details.
--
--  You should have received a copy of the GNU General Public License along
--  with this program; if not, write to the Free Software Foundation, Inc.,
--  51 Franklin St, Fifth Floor, Boston, MA 02110-1301 USA
--

echo BOTH "STARTED: vector index literal identity and float storage\n";

select DB.DBA.ONNX_REGISTRY_INIT ();
delete from DB.DBA.ONNX_MODELS where model_name = 'tli-64';
insert into DB.DBA.ONNX_MODELS
  (model_name, description, model_path, model_type, output_name, output_shape, created_at, updated_at)
values
  ('tli-64', 'literal identity test model', 'internal:tli-64', 'test_embedding', 'embedding', '1,64', now (), now ());
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": register tli-64 STATE=" $STATE "\n";

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

create procedure DB.DBA.TLI_HIDDEN (in idx varchar) returns varchar
{
  return sprintf ('DB.DBA.%s_vec_embeddings', DB.DBA.VEC_INDEX_GENERATE_NAME (idx));
}
;

-- The stored embedding for one subject of a SPARQL vector index, or NULL.
create procedure DB.DBA.TLI_STORED (in idx varchar, in subj varchar) returns any
{
  declare st, msg varchar;
  declare md, rs, sid any;
  sid := iri_to_id (subj, 0);
  if (sid is null)
    return null;
  st := '00000';
  exec (sprintf ('select VE_EMBEDDING from %s where VE_D_ID = ?', DB.DBA.TLI_HIDDEN (idx)),
        st, msg, vector (iri_id_num (sid)), 0, md, rs);
  if (st <> '00000' or length (rs) = 0)
    return null;
  return rs[0][0];
}
;

-- 1 when V is exactly the test embedding of TXT, 0 otherwise.
create procedure DB.DBA.TLI_SAME (in v any, in txt varchar) returns integer
{
  declare e any;
  declare i, n integer;
  e := __VEC_INDEX_TEST_EMBEDDING (64, txt);
  n := VVEC_DIMENSION (e);
  if (VVEC_DIMENSION (v) <> n)
    return 0;
  for (i := 0; i < n; i := i + 1)
    if (abs (aref (v, i) - aref (e, i)) > 1e-6)
      return 0;
  return 1;
}
;

-- 1 when SUBJ's stored vector is the embedding of TXT, 0 when it is some other
-- vector, -1 when the subject has no row at all.
create procedure DB.DBA.TLI_IS (in idx varchar, in subj varchar, in txt varchar) returns integer
{
  declare v any;
  v := DB.DBA.TLI_STORED (idx, subj);
  if (v is null)
    return -1;
  return DB.DBA.TLI_SAME (v, txt);
}
;

create procedure DB.DBA.TLI_ROWS (in hidden varchar, in tag integer := null) returns integer
{
  declare st, msg varchar;
  declare md, rs any;
  st := '00000';
  if (tag is null)
    exec (sprintf ('select count (*) from %s', hidden), st, msg, vector (), 0, md, rs);
  else
    exec (sprintf ('select count (*) from %s where __tag (VE_EMBEDDING) = ?', hidden),
          st, msg, vector (tag), 0, md, rs);
  if (st <> '00000')
    return -1;
  return rs[0][0];
}
;

create procedure DB.DBA.TLI_NODES (in idx varchar) returns integer
{
  return cast (get_keyword ('graph_nodes',
      __VEC_INDEX_METRICS (DB.DBA.VEC_INDEX_GENERATE_NAME (idx)), -1) as integer);
}
;

-- Live nodes: graph_nodes counts a replaced or deleted node until a rebuild.
create procedure DB.DBA.TLI_ACTIVE (in idx varchar) returns integer
{
  declare m any;
  m := __VEC_INDEX_METRICS (DB.DBA.VEC_INDEX_GENERATE_NAME (idx));
  return cast (get_keyword ('graph_nodes', m, -1) as integer)
       - cast (get_keyword ('deleted_nodes', m, 0) as integer);
}
;

-- Refresh and return how many rows it reports having (re)embedded.
create procedure DB.DBA.TLI_REFRESH (in idx varchar) returns integer
{
  declare r any;
  r := DB.DBA.VEC_INDEX_REFRESH (idx);
  return cast (regexp_substr ('refreshed, ([0-9]+) rows processed', cast (r[0][1] as varchar), 1) as integer);
}
;

create procedure DB.DBA.TLI_LONG_TEXT (in a integer, in b integer) returns varchar
{
  return sprintf ('%d %d ', a, b) || repeat ('long literal text ', 300);
}
;

-- A 64-wide vector() of boxed doubles -- the DV_ARRAY_OF_POINTER form -- with
-- 1.0 at POS.
create procedure DB.DBA.TLI_DVEC (in pos integer) returns any
{
  declare v any;
  declare i integer;
  v := make_array (64, 'any');
  for (i := 0; i < 64; i := i + 1)
    aset (v, i, case when i = pos then 1.0e0 else 0.0e0 end);
  return v;
}
;

-- A SPARQL search's top hit for TXT, as an IRI string.
create procedure DB.DBA.TLI_TOP1 (in idx varchar, in txt varchar) returns varchar
{
  declare st, msg varchar;
  declare md, rs any;
  st := '00000';
  exec (sprintf ('sparql define input:storage "" select ?s where { ?s bif:vector_search "%s" option (index <%s>, limit 1) }', txt, idx),
        st, msg, vector (), 0, md, rs);
  if (st <> '00000' or length (rs) = 0)
    return sprintf ('<no hit: %s %s>', st, msg);
  return id_to_iri (iri_to_id (rs[0][0]));
}
;

-- ===========================================================================
-- 1. What an RDF selector embeds
-- ===========================================================================

sparql define input:storage "" drop silent vector index <urn:tli:idx>;
sparql clear graph <urn:tli:g>;
sparql insert data { graph <urn:tli:g> {
  <urn:tli:s1>  <urn:tli:text> "alpha 1 2" .
  <urn:tli:s3>  <urn:tli:text> "bonjour 5 6"@fr .
  <urn:tli:s4>  <urn:tli:text> "typed 7 8"^^<urn:tli:type> .
  <urn:tli:s5>  <urn:tli:text> 9 .
  <urn:tli:s6>  <urn:tli:text> <urn:tli:iri_object_10_11> .
  <urn:tli:s7>  <urn:tli:text> [] .
  <urn:tli:s8>  <urn:tli:text> "zeta 12 13" , "alpha 14 15" .
  <urn:tli:s9>  <urn:tli:text> <urn:tli:aaa_16_17> , "zzz 18 19" .
  <urn:tli:s10> <urn:tli:text> "" .
  <urn:tli:s11> <urn:tli:other> "another predicate 20 21" .
} };
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": load <urn:tli:g> STATE=" $STATE "\n";

--  A literal long enough to live in RDF_OBJ.RO_LONG: RO_VAL then holds a
--  checksum, not the text, so the text is only reachable through the engine's
--  own completion path.
DB.DBA.RDF_QUAD_URI_L ('urn:tli:g', 'urn:tli:s2', 'urn:tli:text', DB.DBA.TLI_LONG_TEXT (3, 4));
select count (*) from DB.DBA.RDF_QUAD q, DB.DBA.RDF_OBJ o
  where q.G = iri_to_id ('urn:tli:g') and q.S = iri_to_id ('urn:tli:s2')
    and o.RO_ID = rdf_box_ro_id (q.O) and o.RO_LONG is not null;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": precondition -- s2's literal is an RO_LONG literal, n=" $LAST[1] "\n";

sparql define input:storage ""
create vector index <urn:tli:idx>
  on graph <urn:tli:g>
  for predicate <urn:tli:text>
  using model 'tli-64'
  with (dimensions = 64, distance = 'cosine', maintenance = 'manual')
;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": create <urn:tli:idx> STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select DB.DBA.TLI_REFRESH ('urn:tli:idx');
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": first refresh STATE=" $STATE " MESSAGE=" $MESSAGE " rows=" $LAST[1] "\n";

--  s1, s2, s3, s4, s5, s8, s9: seven subjects carry a non-empty literal.
select DB.DBA.TLI_NODES ('urn:tli:idx');
ECHO BOTH $IF $EQU $LAST[1] 7 "PASSED" "***FAILED";
ECHO BOTH ": graph_nodes=" $LAST[1] " (expect 7: only subjects with a non-empty literal)\n";

select DB.DBA.TLI_ROWS (DB.DBA.TLI_HIDDEN ('urn:tli:idx'));
ECHO BOTH $IF $EQU $LAST[1] 7 "PASSED" "***FAILED";
ECHO BOTH ": stored embeddings=" $LAST[1] " (expect 7)\n";

select DB.DBA.TLI_IS ('urn:tli:idx', 'urn:tli:s1', 'alpha 1 2');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": short plain literal embedded as its own text, got " $LAST[1] "\n";

select DB.DBA.TLI_IS ('urn:tli:idx', 'urn:tli:s2', DB.DBA.TLI_LONG_TEXT (3, 4));
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": RO_LONG literal embedded as its full text, got " $LAST[1] "\n";

select DB.DBA.TLI_IS ('urn:tli:idx', 'urn:tli:s3', 'bonjour 5 6');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": language-tagged literal embedded as its plain text, got " $LAST[1] "\n";

select DB.DBA.TLI_IS ('urn:tli:idx', 'urn:tli:s4', 'typed 7 8');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": typed literal embedded as its plain text, got " $LAST[1] "\n";

select DB.DBA.TLI_IS ('urn:tli:idx', 'urn:tli:s5', '9');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": numeric literal embedded as its lexical form, got " $LAST[1] "\n";

select DB.DBA.TLI_IS ('urn:tli:idx', 'urn:tli:s6', 'urn:tli:iri_object_10_11');
ECHO BOTH $IF $EQU $LAST[1] -1 "PASSED" "***FAILED";
ECHO BOTH ": a subject whose only object is an IRI has no embedding, got " $LAST[1] " (0 or 1 = the IRI string was embedded)\n";

select case when DB.DBA.TLI_STORED ('urn:tli:idx', 'urn:tli:s7') is null then 1 else 0 end;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": a subject whose only object is a blank node has no embedding, got " $LAST[1] "\n";

select DB.DBA.TLI_IS ('urn:tli:idx', 'urn:tli:s8', 'zeta 12 13') + DB.DBA.TLI_IS ('urn:tli:idx', 'urn:tli:s8', 'alpha 14 15');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": a subject with two literals has exactly one of them embedded, got " $LAST[1] "\n";

select DB.DBA.TLI_IS ('urn:tli:idx', 'urn:tli:s9', 'zzz 18 19');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": an IRI and a literal -- the literal is embedded even though the IRI sorts first, got " $LAST[1] "\n";

select case when DB.DBA.TLI_STORED ('urn:tli:idx', 'urn:tli:s10') is null then 1 else 0 end;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": an empty literal is not embedded, got " $LAST[1] "\n";

select case when DB.DBA.TLI_STORED ('urn:tli:idx', 'urn:tli:s11') is null then 1 else 0 end;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": a literal of another predicate is not embedded, got " $LAST[1] "\n";

select DB.DBA.TLI_TOP1 ('urn:tli:idx', 'zzz 18 19');
ECHO BOTH $IF $EQU $LAST[1] "urn:tli:s9" "PASSED" "***FAILED";
ECHO BOTH ": search for s9's literal finds s9 first, got " $LAST[1] "\n";

select DB.DBA.TLI_ROWS (DB.DBA.TLI_HIDDEN ('urn:tli:idx')) - DB.DBA.TLI_ROWS (DB.DBA.TLI_HIDDEN ('urn:tli:idx'), 202);
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": no embedding of the RDF index is stored outside DV_ARRAY_OF_FLOAT, n=" $LAST[1] "\n";

-- ===========================================================================
-- 2. A refresh re-embeds exactly what changed
-- ===========================================================================

sparql delete data { graph <urn:tli:g> {
  <urn:tli:s1> <urn:tli:text> "alpha 1 2" .
  <urn:tli:s3> <urn:tli:text> "bonjour 5 6"@fr .
} };
sparql insert data { graph <urn:tli:g> {
  <urn:tli:s1>  <urn:tli:text> "alpha 22 23" .
  <urn:tli:s12> <urn:tli:text> "new 24 25" .
} };
delete from DB.DBA.RDF_QUAD where G = iri_to_id ('urn:tli:g') and S = iri_to_id ('urn:tli:s2');
DB.DBA.RDF_QUAD_URI_L ('urn:tli:g', 'urn:tli:s2', 'urn:tli:text', DB.DBA.TLI_LONG_TEXT (26, 27));
commit work;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": modify s1 and s2, remove s3, add s12 STATE=" $STATE "\n";

--  s1 (changed short), s2 (changed RO_LONG) and s12 (new): three rows, and
--  nothing that did not change.
select DB.DBA.TLI_REFRESH ('urn:tli:idx');
ECHO BOTH $IF $EQU $LAST[1] 3 "PASSED" "***FAILED";
ECHO BOTH ": second refresh re-embedded " $LAST[1] " row(s) (expect 3: s1, s2, s12)\n";

select DB.DBA.TLI_ACTIVE ('urn:tli:idx');
ECHO BOTH $IF $EQU $LAST[1] 7 "PASSED" "***FAILED";
ECHO BOTH ": live graph nodes after the delta=" $LAST[1] " (expect 7: minus s3, plus s12)\n";

select DB.DBA.TLI_IS ('urn:tli:idx', 'urn:tli:s1', 'alpha 22 23');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": s1 carries its new text, got " $LAST[1] "\n";

select DB.DBA.TLI_IS ('urn:tli:idx', 'urn:tli:s2', DB.DBA.TLI_LONG_TEXT (26, 27));
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": s2 carries its new long text, got " $LAST[1] "\n";

select case when DB.DBA.TLI_STORED ('urn:tli:idx', 'urn:tli:s3') is null then 1 else 0 end;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": s3, whose literal was deleted, is gone, got " $LAST[1] "\n";

select DB.DBA.TLI_IS ('urn:tli:idx', 'urn:tli:s12', 'new 24 25');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": s12 was added, got " $LAST[1] "\n";

select DB.DBA.TLI_IS ('urn:tli:idx', 'urn:tli:s4', 'typed 7 8');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": s4 is untouched, got " $LAST[1] "\n";

select DB.DBA.TLI_REFRESH ('urn:tli:idx');
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": a refresh with nothing changed embeds " $LAST[1] " row(s) (expect 0)\n";

-- ===========================================================================
-- 3. A refresh leaves a bulk index whose epochs disagree healthy
--
--    A regression guard, not a discriminating test: an epoch sync during the
--    refresh can re-agree the pair on its own, so this passes whether or not
--    the refresh also decides to rebuild.  The case the rebuild decision
--    exists for -- a graph left EMPTY with agreeing epochs by a run that died
--    between staging and building -- cannot be produced without a fault
--    injection point in the backfill.
-- ===========================================================================

create procedure DB.DBA.TLI_LOAD_G2 ()
{
  declare k integer;
  for (k := 30; k < 50; k := k + 1)
    DB.DBA.RDF_QUAD_URI_L ('urn:tli:g2', sprintf ('urn:tli:b%d', k), 'urn:tli:text', sprintf ('item %d %d', k, k));
  commit work;
}
;
sparql define input:storage "" drop silent vector index <urn:tli:bulk>;
sparql clear graph <urn:tli:g2>;
DB.DBA.TLI_LOAD_G2 ();

sparql define input:storage ""
create vector index <urn:tli:bulk>
  on graph <urn:tli:g2>
  for predicate <urn:tli:text>
  using model 'tli-64'
  with (dimensions = 64, distance = 'cosine', maintenance = 'manual', build = 'bulk')
;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": create <urn:tli:bulk> build=bulk STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select DB.DBA.TLI_REFRESH ('urn:tli:bulk');
select DB.DBA.TLI_NODES ('urn:tli:bulk');
ECHO BOTH $IF $EQU $LAST[1] 20 "PASSED" "***FAILED";
ECHO BOTH ": bulk build graph_nodes=" $LAST[1] " (expect 20)\n";

--  What a rebuild that died part way leaves behind: the graph and the data no
--  longer agree.  Moving the catalog's data epoch reproduces it exactly, with
--  nothing timing-dependent.
update DB.DBA.VEC_INDEX_EPOCH set VIE_EPOCH = VIE_EPOCH - 3
  where VIE_NAME = DB.DBA.VEC_INDEX_GENERATE_NAME ('urn:tli:bulk');
commit work;
select __VEC_INDEX_HEALTH_RECHECK (DB.DBA.VEC_INDEX_GENERATE_NAME ('urn:tli:bulk'));
ECHO BOTH $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";
ECHO BOTH ": precondition -- the index now reports needs-rebuild, health=" $LAST[1] "\n";

--  Nothing in the RDF changed, so there is nothing to embed.  The refresh must
--  still notice the graph is unusable and build it.
select DB.DBA.TLI_REFRESH ('urn:tli:bulk');
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": refresh with nothing to embed STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select __VEC_INDEX_HEALTH_RECHECK (DB.DBA.VEC_INDEX_GENERATE_NAME ('urn:tli:bulk'));
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": the refresh rebuilt the graph, health=" $LAST[1] " (expect 1)\n";

select DB.DBA.TLI_TOP1 ('urn:tli:bulk', 'item 37 37');
ECHO BOTH $IF $EQU $LAST[1] "urn:tli:b37" "PASSED" "***FAILED";
ECHO BOTH ": and it answers searches again, top hit " $LAST[1] "\n";

-- ===========================================================================
-- 4. Stored form: DV_ARRAY_OF_FLOAT, and the in-place converter
-- ===========================================================================

create table DB.DBA.TLI_T (ID integer not null primary key, TXT varchar);
insert into DB.DBA.TLI_T values (1, 'row 1 1');
insert into DB.DBA.TLI_T values (2, 'row 2 2');
CREATE VECTOR INDEX TLI_T_IDX ON DB.DBA.TLI_T (TXT) USING 'tli-64' WITH (dimensions = 64);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": create TLI_T_IDX STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select __tag (DB.DBA.TLI_DVEC (7));
ECHO BOTH $IF $EQU $LAST[1] 193 "PASSED" "***FAILED";
ECHO BOTH ": precondition -- the input vector is a DV_ARRAY_OF_POINTER, tag=" $LAST[1] "\n";

--  A vector handed in as boxed doubles is stored flat.
select __VEC_INDEX_INSERT_EMBEDDING ('TLI_T_IDX', 100, DB.DBA.TLI_DVEC (7));
select __tag (VE_EMBEDDING) from DB.DBA.TLI_T_IDX_vec_embeddings where VE_D_ID = 100;
ECHO BOTH $IF $EQU $LAST[1] 202 "PASSED" "***FAILED";
ECHO BOTH ": a DV_ARRAY_OF_POINTER input is stored as DV_ARRAY_OF_FLOAT, tag=" $LAST[1] "\n";

select aref (VE_EMBEDDING, 7) from DB.DBA.TLI_T_IDX_vec_embeddings where VE_D_ID = 100;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": and keeps its value, v[7]=" $LAST[1] "\n";

select __tag (VVEC_TO_FLOAT_VECTOR (vector (1.0e0, 2.5e0)));
ECHO BOTH $IF $EQU $LAST[1] 202 "PASSED" "***FAILED";
ECHO BOTH ": VVEC_TO_FLOAT_VECTOR returns DV_ARRAY_OF_FLOAT, tag=" $LAST[1] "\n";

select case when aref (VVEC_TO_FLOAT_VECTOR (vector (1.0e0, 2.5e0)), 1) = 2.5 then 1 else 0 end;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": VVEC_TO_FLOAT_VECTOR preserves values, ok=" $LAST[1] "\n";

--  A table written before the change: put row 100 back in the old boxed form,
--  as a DBA may, and convert.
insert replacing DB.DBA.TLI_T_IDX_vec_embeddings (VE_D_ID, VE_EMBEDDING, SOURCE_HASH, EMBED_STATUS, MODEL_ID, UPDATED_AT)
  select VE_D_ID, DB.DBA.TLI_DVEC (7), SOURCE_HASH, EMBED_STATUS, MODEL_ID, UPDATED_AT
    from DB.DBA.TLI_T_IDX_vec_embeddings where VE_D_ID = 100;
commit work;
select __tag (VE_EMBEDDING) from DB.DBA.TLI_T_IDX_vec_embeddings where VE_D_ID = 100;
ECHO BOTH $IF $EQU $LAST[1] 193 "PASSED" "***FAILED";
ECHO BOTH ": precondition -- row 100 is back in the old boxed form, tag=" $LAST[1] "\n";

select DB.DBA.VEC_INDEX_EMBEDDINGS_TO_FLOAT ('DB.DBA.TLI_T_IDX_vec_embeddings');
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": VEC_INDEX_EMBEDDINGS_TO_FLOAT STATE=" $STATE " MESSAGE=" $MESSAGE " converted=" $LAST[1] "\n";

select count (*) from DB.DBA.TLI_T_IDX_vec_embeddings where __tag (VE_EMBEDDING) <> 202;
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": no row is left in the old form, n=" $LAST[1] "\n";

select case when aref (VE_EMBEDDING, 7) = 1 and VVEC_DIMENSION (VE_EMBEDDING) = 64 then 1 else 0 end
  from DB.DBA.TLI_T_IDX_vec_embeddings where VE_D_ID = 100;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": the converted row keeps its 64 values, ok=" $LAST[1] "\n";

select log_enable (null);
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": the converter put the caller's log mode back, log_enable=" $LAST[1] "\n";

-- ===========================================================================
-- 5. Vector constructors
-- ===========================================================================

select length (make_array (3, 'float'));
ECHO BOTH $IF $EQU $LAST[1] 3 "PASSED" "***FAILED";
ECHO BOTH ": length (make_array (3, 'float'))=" $LAST[1] "\n";

create procedure DB.DBA.TLI_FLOAT_ASET () returns integer
{
  declare v any;
  v := make_array (64, 'float');
  aset (v, 40, 1.5);
  return case when aref (v, 40) = 1.5 then 1 else 0 end;
}
;
select DB.DBA.TLI_FLOAT_ASET ();
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": aset past the midpoint of a 64-wide float array works, ok=" $LAST[1] "\n";

select length (fvector (1.0, 2.0, 3.0));
ECHO BOTH $IF $EQU $LAST[1] 3 "PASSED" "***FAILED";
ECHO BOTH ": length (fvector (1.0, 2.0, 3.0))=" $LAST[1] "\n";

select isvector (fvector (1.0));
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": isvector (fvector (1.0))=" $LAST[1] "\n";

select isvector (dvector (1.0));
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": isvector (dvector (1.0))=" $LAST[1] "\n";

select isvector (vector (1)) + 2 * isvector ('abc');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": control -- isvector (vector (1)) is 1 and isvector ('abc') is 0, got " $LAST[1] "\n";

-- ===========================================================================
-- 6. A rebuild with logging off stays unlogged across its own commit
-- ===========================================================================

create table DB.DBA.TLI_R (ID integer not null primary key, TXT varchar);
CREATE VECTOR INDEX TLI_R_IDX ON DB.DBA.TLI_R (TXT) USING 'tli-64' WITH (dimensions = 64);

create procedure DB.DBA.TLI_STAGE_RANDOM (in n integer)
{
  declare ids, vecs, v any;
  declare i, j, b integer;
  b := 0;
  ids := make_array (500, 'any');
  vecs := make_array (500, 'any');
  for (i := 1; i <= n; i := i + 1)
    {
      v := make_array (64, 'any');
      for (j := 0; j < 64; j := j + 1)
        aset (v, j, (rnd (10000) + 1) / 10000.0e0);
      aset (ids, b, i);
      aset (vecs, b, v);
      b := b + 1;
      if (b = 500)
        {
          __VEC_INDEX_STAGE_BATCH ('TLI_R_IDX', ids, vecs);
          commit work;
          b := 0;
        }
    }
  if (b > 0)
    __VEC_INDEX_STAGE_BATCH ('TLI_R_IDX', subseq (ids, 0, b), subseq (vecs, 0, b));
  commit work;
}
;
DB.DBA.TLI_STAGE_RANDOM (12000);
select count (*) from DB.DBA.TLI_R_IDX_vec_embeddings;
ECHO BOTH $IF $EQU $LAST[1] 12000 "PASSED" "***FAILED";
ECHO BOTH ": staged " $LAST[1] " vectors for the rebuild\n";

create table DB.DBA.TLI_MARK (M varchar primary key, SZ integer);
create procedure DB.DBA.TLI_TRX_MARK (in m varchar)
{
  insert replacing DB.DBA.TLI_MARK values (m, cast (file_stat ('virtuoso.trx', 1) as integer));
  commit work;
}
;
create procedure DB.DBA.TLI_TRX_DELTA (in a varchar, in b varchar) returns integer
{
  return (select SZ from DB.DBA.TLI_MARK where M = a) - (select SZ from DB.DBA.TLI_MARK where M = b);
}
;

--  One statement, so nothing between log_enable and the rebuild can hand the
--  connection a fresh transaction with the default log mode.
create procedure DB.DBA.TLI_REBUILD (in logged integer)
{
  declare prev_mode integer;
  prev_mode := log_enable (null);
  if (not logged)
    log_enable (0, 1);
  __VEC_INDEX_REBUILD ('TLI_R_IDX', 'fast', 2);
  commit work;
  log_enable (prev_mode, 1);
}
;

--  Control: logging on.  The fast rebuild's serialize phase logs every page
--  it writes, so the log grows by roughly the graph's size.
checkpoint;
DB.DBA.TLI_TRX_MARK ('on0');
DB.DBA.TLI_REBUILD (1);
DB.DBA.TLI_TRX_MARK ('on1');
select DB.DBA.TLI_TRX_DELTA ('on1', 'on0'), case when DB.DBA.TLI_TRX_DELTA ('on1', 'on0') > 1000000 then 1 else 0 end;
ECHO BOTH $IF $EQU $LAST[2] 1 "PASSED" "***FAILED";
ECHO BOTH ": control -- a logged fast rebuild grows the log by " $LAST[1] " bytes (expect > 1000000)\n";

--  Logging off.  The rebuild commits between resetting the graph and building
--  it.  An ordinary commit hands the connection a transaction whose log mode
--  comes from the connection default, not from log_enable (lt_restart, lock.c)
--  -- but the rebuild commits through ddl_commit_trx, which carries the mode
--  across, so this held before any fix as well: a regression guard that the
--  serialize phase stays unlogged, not a test of a change.
checkpoint;
DB.DBA.TLI_TRX_MARK ('off0');
DB.DBA.TLI_REBUILD (0);
DB.DBA.TLI_TRX_MARK ('off1');
select DB.DBA.TLI_TRX_DELTA ('off1', 'off0'), case when 20 * DB.DBA.TLI_TRX_DELTA ('off1', 'off0') < DB.DBA.TLI_TRX_DELTA ('on1', 'on0') then 1 else 0 end;
ECHO BOTH $IF $EQU $LAST[2] 1 "PASSED" "***FAILED";
ECHO BOTH ": with log_enable (0) the rebuild grows the log by " $LAST[1] " bytes (expect under 5% of the logged run)\n";

select get_keyword ('graph_nodes', __VEC_INDEX_METRICS ('TLI_R_IDX'));
ECHO BOTH $IF $EQU $LAST[1] 12000 "PASSED" "***FAILED";
ECHO BOTH ": the unlogged rebuild built the whole graph, graph_nodes=" $LAST[1] "\n";

-- ===========================================================================
-- 7. The ONNX plugin: output form, batch bound, helper error text
-- ===========================================================================

create procedure DB.DBA.TLI_ONNX_READY () returns integer
{
  declare exit handler for sqlstate '*' { return 0; };
  if (__proc_exists ('ONNX_EMBED_BATCH', 2) is null)
    return 0;
  ONNX_EMBED_TEXT_FOR_MODEL ('granite-384-local', 'warm up');
  return 1;
}
;

create procedure DB.DBA.TLI_ONNX_HANDLE () returns integer
{
  return (select handle from DB.DBA.ONNX_MODELS where model_name = 'granite-384-local');
}
;

-- Embed N distinct texts in one ONNX_EMBED_BATCH call; the number of
-- 384-wide vectors that came back, or the error text.
create procedure DB.DBA.TLI_BATCH (in n integer) returns varchar
{
  declare texts, r any;
  declare i, good integer;
  declare exit handler for sqlstate '*' { return __SQL_MESSAGE; };
  texts := make_array (n, 'any');
  for (i := 0; i < n; i := i + 1)
    aset (texts, i, sprintf ('sentence number %d about the batch bound', i));
  r := ONNX_EMBED_BATCH (DB.DBA.TLI_ONNX_HANDLE (), texts);
  good := 0;
  for (i := 0; i < length (r); i := i + 1)
    if (VVEC_DIMENSION (r[i]) = 384)
      good := good + 1;
  return cast (good as varchar);
}
;

select DB.DBA.TLI_ONNX_READY ();
ECHO BOTH ": ONNX plugin with granite-384-local available=" $LAST[1] "\n";

select case when DB.DBA.TLI_ONNX_READY () = 0 then 202
  else __tag (ONNX_EMBED_TEXT_FOR_MODEL ('granite-384-local', 'hello world')) end;
ECHO BOTH $IF $EQU $LAST[1] 202 "PASSED" "***FAILED";
ECHO BOTH ": ONNX embeddings come back as DV_ARRAY_OF_FLOAT, tag=" $LAST[1] "\n";

--  384 floats per text: 43 texts are over the helper's 16384-float bound if it
--  is applied to the whole batch, and far under it per vector.
select case when DB.DBA.TLI_ONNX_READY () = 0 then 1 else ONNX_CONFIG ('max_batch', 64) end;
select case when DB.DBA.TLI_ONNX_READY () = 0 then '64' else DB.DBA.TLI_BATCH (64) end;
ECHO BOTH $IF $EQU $LAST[1] 64 "PASSED" "***FAILED";
ECHO BOTH ": a 64-text batch returns 64 embeddings, got " $LAST[1] "\n";

--  A text over the helper's own per-text bound (512 KB), with the plugin's
--  bound raised past it, so the helper answers with an error.  Its text must
--  arrive exactly: the framing carries no terminator and the buffer it sits in
--  is freed before the message is raised.  (This used a 129-text batch, over
--  the helper's old compile-time limit of 128; a request is now bounded by the
--  model's max_texts, which the plugin checks before it sends anything.)
select case when DB.DBA.TLI_ONNX_READY () = 0 then 1 else ONNX_CONFIG ('max_input_bytes', 1048576) end;
create procedure DB.DBA.TLI_BATCH_TOO_LONG () returns varchar
{
  declare r any;
  declare exit handler for sqlstate '*' { return __SQL_MESSAGE; };
  r := ONNX_EMBED_BATCH (DB.DBA.TLI_ONNX_HANDLE (), vector (repeat ('x', 600000), 'a short text'));
  return cast (length (r) as varchar);
}
;
--  Whether stale bytes follow the text depends on what the buffer held
--  before, so ask five times and require every answer clean.
create procedure DB.DBA.TLI_BATCH_ERR_CLEAN (in tries integer) returns integer
{
  declare i, clean integer;
  clean := 0;
  for (i := 0; i < tries; i := i + 1)
    {
      DB.DBA.TLI_BATCH (64);
      if (DB.DBA.TLI_BATCH_TOO_LONG () like '%Helper error: text too long')
        clean := clean + 1;
    }
  return clean;
}
;
select case when DB.DBA.TLI_ONNX_READY () = 0 then 5 else DB.DBA.TLI_BATCH_ERR_CLEAN (5) end;
ECHO BOTH $IF $EQU $LAST[1] 5 "PASSED" "***FAILED";
ECHO BOTH ": a helper error message arrives intact, " $LAST[1] " of 5 clean\n";

select case when DB.DBA.TLI_ONNX_READY () = 0 then '<skipped>' else DB.DBA.TLI_BATCH_TOO_LONG () end;
ECHO BOTH ": (the helper error text was: " $LAST[1] ")\n";

select case when DB.DBA.TLI_ONNX_READY () = 0 then 1 else ONNX_CONFIG ('max_input_bytes', 524288) end;
select case when DB.DBA.TLI_ONNX_READY () = 0 then 1 else ONNX_CONFIG ('max_batch', 32) end;

-- ===========================================================================
-- Cleanup
-- ===========================================================================
sparql define input:storage "" drop silent vector index <urn:tli:idx>;
sparql define input:storage "" drop silent vector index <urn:tli:bulk>;
sparql clear graph <urn:tli:g>;
sparql clear graph <urn:tli:g2>;
drop table DB.DBA.TLI_T;
drop table DB.DBA.TLI_R;
drop table DB.DBA.TLI_MARK;
delete from DB.DBA.ONNX_MODELS where model_name = 'tli-64';
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": cleanup STATE=" $STATE "\n";

echo BOTH "COMPLETED: vector index literal identity and float storage\n";
