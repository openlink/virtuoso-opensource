--
--  tvvec_rdf_quad.sql
--
--  Vector indexes over RDF literals (DB.DBA.RDF_OBJ) searched with knnSimilar (SQL) and
--  bif:knnSimilar (SPARQL).  The driver has loaded the Northwind demo and its quad maps.
--
--  Phase A: copy the Demo# RDF view to the physical graph urn:tvr:nw, create an index in one
--  call, query it, add probe literals (SPARQL inserts and a Products row that the view sync
--  triggers turn into a quad), drain the change log, query again, remove graphs and triples,
--  query again, drop the index and check that queries -- including ones already cached on
--  this connection -- refuse.
--  Phase B: the same index made step by step -- define, embed (interrupted and resumed),
--  build -- with the change log held while it is not built; name collisions, two indexes,
--  a repeated build, then drop.
--
--  The model is an in-core test_embedding of 1024 dimensions: it puts 1.0 at the positions
--  of the first two integers in the text (modulo 1024), and at a hashed position when there
--  is none.  Each probe literal "tvr probe 653 100N ..." has a vector of its own, and against
--  the query "tvr probe 653" every one of them has cosine 1/sqrt(2): similarity 0.854,
--  distance 0.293.  A literal with no 653 scores 0.5, one hashed onto 653 scores 1, so the
--  band 0.84-0.87 is exactly the probes.  The positions are ones no system literal uses: the
--  W3C datatype IRIs, "http://www.w3.org/2001/...", all read as positions 3 and 977.  Distinct vectors, because the graph builder is weak on exact ties.
--  Assertions are counts; a similarity is only compared with a threshold inside SQL.  Counts
--  over literals the test does not control are bounds: RDF_OBJ also holds literals no quad
--  uses any more, which a search returns but a join to RDF_QUAD drops.
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

echo BOTH "STARTED: RDF_OBJ vector index and knnSimilar\n";

registry_set ('__vec_embed_concurrency', '2');

select DB.DBA.ONNX_REGISTRY_INIT ();
delete from DB.DBA.ONNX_MODELS where model_name = 'tvr-1024';
insert into DB.DBA.ONNX_MODELS
  (model_name, description, model_path, model_type, output_name, output_shape, created_at, updated_at)
values
  ('tvr-1024', 'RDF_OBJ vector index test model', 'internal:tvr-1024', 'test_embedding', 'embedding', '1,1024', now (), now ());
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": register tvr-1024 STATE=" $STATE "\n";

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

-- The name a table was stored under, whatever the case mode folded it to; NULL when none.
create procedure DB.DBA.TVR_TABLE (in tb_name varchar) returns varchar
{
  for (select distinct KEY_TABLE as kt from DB.DBA.SYS_KEYS where KEY_TABLE like 'DB.DBA.%') do
    if (upper (kt) = upper (tb_name))
      return kt;
  return null;
}
;

-- Rows of a table, -1 when it does not exist.
create procedure DB.DBA.TVR_ROWS (in tb_name varchar) returns integer
{
  declare tb, st, msg varchar;
  declare md, rs any;
  tb := DB.DBA.TVR_TABLE (tb_name);
  if (tb is null)
    return -1;
  st := '00000';
  exec (sprintf ('select count (*) from "%I"."%I"."%I"', name_part (tb, 0), name_part (tb, 1), name_part (tb, 2)),
        st, msg, vector (), 0, md, rs);
  if (st <> '00000')
    return -1;
  return rs[0][0];
}
;

-- The literals an index without filters embeds: string literals that are not XML, not empty.
create procedure DB.DBA.TVR_ELIGIBLE () returns integer
{
  return (select count (*) from DB.DBA.RDF_OBJ
           where bit_and (RO_FLAGS, 2) = 0 and __vec_rdf_obj_is_string_dt (RO_DT_AND_LANG) = 1
             and (RO_LONG is not null or length (RO_VAL) > 0));
}
;

-- 1 when the EXPLAIN of Q contains PAT.
create procedure DB.DBA.TVR_PLAN_HAS (in q varchar, in pat varchar) returns integer
{
  declare st, msg varchar;
  declare md, rs any;
  declare inx integer;
  st := '00000';
  exec ('explain (?)', st, msg, vector (q), 0, md, rs);
  if (st <> '00000')
    return -1;
  for (inx := 0; inx < length (rs); inx := inx + 1)
    if (strstr (cast (rs[inx][0] as varchar), pat) is not null)
      return 1;
  return 0;
}
;

-- Distinct literals of graph G the index can return: in the graph and embedded.
create procedure DB.DBA.TVR_GRAPH_INDEXED (in g varchar, in src_name varchar) returns integer
{
  declare src, st, msg varchar;
  declare md, rs any;
  src := DB.DBA.TVR_TABLE (src_name);
  if (src is null)
    return -1;
  st := '00000';
  exec (sprintf ('select count (distinct q.O) from DB.DBA.RDF_QUAD q, "%I"."%I"."%I" s '
                 || 'where q.G = iri_to_id (?) and s.RV_ID = rdf_box_ro_id (q.O)',
                 name_part (src, 0), name_part (src, 1), name_part (src, 2)),
        st, msg, vector (g), 0, md, rs);
  if (st <> '00000')
    return -1;
  return rs[0][0];
}
;

-- Category descriptions of urn:tvr:nw that have an RDF_OBJ row; a short one is inline in O.
create procedure DB.DBA.TVR_DESCRIPTIONS () returns integer
{
  return (select count (*) from DB.DBA.RDF_QUAD where G = iri_to_id ('urn:tvr:nw')
           and P = iri_to_id ('http://localhost:8890/schemas/Demo/description') and rdf_box_ro_id (O) > 0);
}
;

-- ---------------------------------------------------------------------------
-- A.1 The physical copy of the Northwind RDF view
-- ---------------------------------------------------------------------------

echo BOTH "\n--- A. index created and built in one call ---\n";

sparql clear graph <urn:tvr:nw>;
DB.DBA.RDF_VIEW_SYNC_TO_PHYSICAL ('http://localhost:8890/Demo#', 1, 'urn:tvr:nw', 2, 0);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": RDF_VIEW_SYNC_TO_PHYSICAL Demo# -> urn:tvr:nw STATE=" $STATE "\n";

select case when count (*) > 0 then 1 else 0 end, count (*) from DB.DBA.RDF_QUAD where G = iri_to_id ('urn:tvr:nw');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": urn:tvr:nw has quads: " $LAST[2] "\n";

sparql select count (*) from <urn:tvr:nw> where { ?c <http://localhost:8890/schemas/Demo/description> ?d };
ECHO BOTH $IF $EQU $LAST[1] 8 "PASSED" "***FAILED";
ECHO BOTH ": 8 category descriptions in urn:tvr:nw: " $LAST[1] "\n";

-- ---------------------------------------------------------------------------
-- A.2 Nothing indexed yet
-- ---------------------------------------------------------------------------

select count (*) from DB.DBA.RDF_OBJ_VEC_INDEX;
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": registry empty: " $LAST[1] "\n";

select __vec_rdf_obj_active ();
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": no active RDF_OBJ index: " $LAST[1] "\n";

select count (*) from DB.DBA.RDF_QUAD where knnSimilar (O, 'tvr probe 653', 20);
ECHO BOTH $IF $EQU $STATE 42S12 "PASSED" "***FAILED";
ECHO BOTH ": knnSimilar with no index refused STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

-- ---------------------------------------------------------------------------
-- A.3 Create and build in one call
-- ---------------------------------------------------------------------------

DB.DBA.RDF_OBJ_VEC_INDEX_CREATE ('urn:tvr:nw:all', 'tvr-1024', null, 0, null);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": create and build urn:tvr:nw:all STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select RVI_NAME, RVI_IRI, RVI_STATE from DB.DBA.RDF_OBJ_VEC_INDEX;
ECHO BOTH $IF $EQU $ROWCNT 1 "PASSED" "***FAILED";
ECHO BOTH ": one registry row\n";
ECHO BOTH $IF $EQU $LAST[1] RDF_OBJ_urn_tvr_nw_all "PASSED" "***FAILED";
ECHO BOTH ": key name " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[2] urn:tvr:nw:all "PASSED" "***FAILED";
ECHO BOTH ": RVI_IRI " $LAST[2] "\n";
ECHO BOTH $IF $EQU $LAST[3] ready "PASSED" "***FAILED";
ECHO BOTH ": state " $LAST[3] "\n";

select count (*) from DB.DBA.SYS_KEYS where KEY_TABLE = 'DB.DBA.RDF_OBJ' and KEY_NAME = 'RDF_OBJ_urn_tvr_nw_all';
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": index key on DB.DBA.RDF_OBJ: " $LAST[1] "\n";

select case when DB.DBA.TVR_ROWS ('DB.DBA.RDF_OBJ_urn_tvr_nw_all_embeddings') = DB.DBA.TVR_ELIGIBLE ()
             and DB.DBA.TVR_ROWS ('DB.DBA.RDF_OBJ_urn_tvr_nw_all_ROSRC') = DB.DBA.TVR_ELIGIBLE ()
             and (select RVI_ROWS from DB.DBA.RDF_OBJ_VEC_INDEX) = DB.DBA.TVR_ELIGIBLE () then 1 else 0 end,
       DB.DBA.TVR_ROWS ('DB.DBA.RDF_OBJ_urn_tvr_nw_all_embeddings'), DB.DBA.TVR_ELIGIBLE ();
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": embeddings = bookkeeping = RVI_ROWS = eligible: " $LAST[2] " / " $LAST[3] "\n";

select count (*) from DB.DBA.SYS_TRIGGERS where upper (T_TABLE) = upper ('DB.DBA.RDF_OBJ_urn_tvr_nw_all_embeddings');
ECHO BOTH $IF $EQU $LAST[1] 3 "PASSED" "***FAILED";
ECHO BOTH ": 3 guard triggers on the embeddings table: " $LAST[1] "\n";

select count (*) from DB.DBA.SYS_TRIGGERS where T_TABLE = 'DB.DBA.RDF_OBJ' and T_NAME like '%VVEC%';
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": no vector-index triggers on RDF_OBJ: " $LAST[1] "\n";

select __vec_rdf_obj_active ();
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": one active RDF_OBJ index: " $LAST[1] "\n";

select count (*) from DB.DBA.RDF_OBJ_VEC_LOG;
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": change log empty: " $LAST[1] "\n";

-- ---------------------------------------------------------------------------
-- A.4 Queries over the Northwind literals
-- ---------------------------------------------------------------------------

select case when count (distinct O) between 1 and 5 then 1 else 0 end, count (distinct O) from DB.DBA.RDF_QUAD where knnSimilar (O, 'Soft drinks, coffees, teas', 5);
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": k = 5 gives 1 to 5 distinct literals: " $LAST[2] "\n";

select case when count (distinct O) between 1 and 3 then 1 else 0 end, count (distinct O) from DB.DBA.RDF_QUAD where knnSimilar (O, 'Soft drinks, coffees, teas', 'urn:tvr:nw:all', 3);
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": named index, k = 3 gives 1 to 3: " $LAST[2] "\n";

-- k = the whole index: the indexed literals of the graph come back.  A bound, not equality: with
-- this model many literals share one one-hot vector, and the graph builder can leave some of
-- such exact ties unreachable.
select case when count (distinct O) <= DB.DBA.TVR_GRAPH_INDEXED ('urn:tvr:nw', 'DB.DBA.RDF_OBJ_urn_tvr_nw_all_ROSRC')
             and 10 * count (distinct O) >= 9 * DB.DBA.TVR_GRAPH_INDEXED ('urn:tvr:nw', 'DB.DBA.RDF_OBJ_urn_tvr_nw_all_ROSRC') then 1 else 0 end,
       count (distinct O), DB.DBA.TVR_GRAPH_INDEXED ('urn:tvr:nw', 'DB.DBA.RDF_OBJ_urn_tvr_nw_all_ROSRC')
  from DB.DBA.RDF_QUAD where G = iri_to_id ('urn:tvr:nw')
   and knnSimilar (O, 'Soft drinks, coffees, teas', 100000);
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": k = whole index returns at least 90% of the indexed literals of urn:tvr:nw: " $LAST[2] " / " $LAST[3] "\n";

select case when x."c" between 1 and 7 then 1 else 0 end, x."c" from
  (sparql select (count (distinct ?o) as ?c) where { ?s ?p ?o . ?o bif:knnSimilar "Soft drinks, coffees, teas" option (limit 7) }) x;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": SPARQL limit 7 gives 1 to 7 distinct literals: " $LAST[2] "\n";

select case when x."c" = DB.DBA.TVR_DESCRIPTIONS () then 1 else 0 end, x."c", DB.DBA.TVR_DESCRIPTIONS () from
  (sparql select (count (distinct ?c) as ?c) from <urn:tvr:nw> where { ?c <http://localhost:8890/schemas/Demo/description> ?d .
    ?d bif:knnSimilar "Soft drinks, coffees, teas" option (index <urn:tvr:nw:all>, limit 100000, score ?sim) }) x;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": every indexed category description matches with k = everything: " $LAST[2] " / " $LAST[3] "\n";

select DB.DBA.TVR_PLAN_HAS ('select S from DB.DBA.RDF_QUAD where knnSimilar (O, ''tvr probe 653'', 5)', 'rdf_obj driving');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": plan: the vector search leads: " $LAST[1] "\n";

select DB.DBA.TVR_PLAN_HAS ('select count (*) from DB.DBA.RDF_QUAD where G = iri_to_id (''urn:tvr:probe'') and knnSimilar (O, ''tvr probe 653'', 100000)', 'rdf_obj check');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": plan: in a small graph with a large k the vector search is a check: " $LAST[1] "\n";

-- ---------------------------------------------------------------------------
-- A.5 Add probe literals; they reach the index through the change log
-- ---------------------------------------------------------------------------

sparql insert data { graph <urn:tvr:probe> {
  <urn:tvr:s1> <urn:tvr:text> "tvr probe 653 1001 alpha literal one" ; <urn:tvr:note> "tvr note 587 701 first subject note text" .
  <urn:tvr:s2> <urn:tvr:text> "tvr probe 653 1002 beta literal two" ; <urn:tvr:note> "tvr note 587 702 second subject note text" .
  <urn:tvr:s3> <urn:tvr:text> "tvr probe 653 1003 gamma literal three" .
  <urn:tvr:s4> <urn:tvr:text> "tvr probe 653 1004 delta literal four" .
  <urn:tvr:s5> <urn:tvr:text> "tvr probe 653 1005 epsilon literal five" . } };
sparql insert data { graph <urn:tvr:probe2> {
  <urn:tvr:s4> <urn:tvr:text> "tvr probe 653 1004 delta literal four" .
  <urn:tvr:s5> <urn:tvr:text> "tvr probe 653 1005 epsilon literal five" .
  <urn:tvr:s6> <urn:tvr:text> "tvr probe 653 1006 zeta literal six only in two" . } };
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": probe literals inserted STATE=" $STATE "\n";

select count (*) from DB.DBA.RDF_OBJ_VEC_LOG;
ECHO BOTH $IF $EQU $LAST[1] 8 "PASSED" "***FAILED";
ECHO BOTH ": 8 new literals logged: " $LAST[1] "\n";

select DB.DBA.RDF_OBJ_VEC_LOG_DRAIN (10000);
ECHO BOTH $IF $EQU $LAST[1] 8 "PASSED" "***FAILED";
ECHO BOTH ": drain consumed 8: " $LAST[1] "\n";

select count (*) from DB.DBA.RDF_OBJ_VEC_LOG;
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": change log empty again: " $LAST[1] "\n";

select case when DB.DBA.TVR_ROWS ('DB.DBA.RDF_OBJ_urn_tvr_nw_all_embeddings') = DB.DBA.TVR_ELIGIBLE () then 1 else 0 end,
       DB.DBA.TVR_ROWS ('DB.DBA.RDF_OBJ_urn_tvr_nw_all_embeddings'), DB.DBA.TVR_ELIGIBLE ();
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": embeddings = eligible after the drain: " $LAST[2] " / " $LAST[3] "\n";

select count (distinct O) from DB.DBA.RDF_QUAD where knnSimilar (O, 'tvr probe 653', 20) and SIMILARITY between 0.84 and 0.87;
ECHO BOTH $IF $EQU $LAST[1] 6 "PASSED" "***FAILED";
ECHO BOTH ": 6 probe literals: " $LAST[1] "\n";

select count (*) from DB.DBA.RDF_QUAD where knnSimilar (O, 'tvr probe 653', 20) and SIMILARITY between 0.84 and 0.87;
ECHO BOTH $IF $EQU $LAST[1] 8 "PASSED" "***FAILED";
ECHO BOTH ": 8 quads carry them: " $LAST[1] "\n";

-- a literal is its own nearest neighbour (a text with no integers would not do: its one-hot vector is
-- orthogonal to nearly everything, which leaves the graph search nothing to follow)
select count (distinct O) from DB.DBA.RDF_QUAD where knnSimilar (O, 'tvr probe 653 1002 beta literal two', 20) and SIMILARITY > 0.999;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": a probe literal finds itself (similarity > 0.999): " $LAST[1] "\n";

select count (distinct O) from DB.DBA.RDF_QUAD where knnSimilar (O, 'tvr note 587', 20) and SIMILARITY between 0.84 and 0.87;
ECHO BOTH $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";
ECHO BOTH ": 2 note literals: " $LAST[1] "\n";

select count (*) from DB.DBA.RDF_QUAD where G = iri_to_id ('urn:tvr:probe') and knnSimilar (O, 'tvr probe 653', 100000) and SIMILARITY between 0.84 and 0.87;
ECHO BOTH $IF $EQU $LAST[1] 5 "PASSED" "***FAILED";
ECHO BOTH ": check mode finds the 5 probe literals of urn:tvr:probe: " $LAST[1] "\n";

select count (*) from DB.DBA.RDF_QUAD where S = iri_to_id ('urn:tvr:s2') and P = iri_to_id ('urn:tvr:text') and knnSimilar (O, 'tvr probe 653', 20);
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": and with k = 20, whichever plan: " $LAST[1] "\n";

select count (*) from DB.DBA.RDF_QUAD where G = iri_to_id ('urn:tvr:probe') and P = iri_to_id ('urn:tvr:text') and knnSimilar (O, 'tvr note 587', 2);
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": check mode rejects them for another text: " $LAST[1] "\n";

sparql select count (*) where { ?s ?p ?o . ?o bif:knnSimilar "tvr probe 653" option (limit 20, score ?sim) . filter (?sim > 0.84 && ?sim < 0.87) };
ECHO BOTH $IF $EQU $LAST[1] 8 "PASSED" "***FAILED";
ECHO BOTH ": SPARQL score filter: " $LAST[1] "\n";

sparql select count (*) where { ?s ?p ?o . ?o bif:knnSimilar "tvr probe 653" option (limit 20, distance ?d) . filter (?d > 0.28 && ?d < 0.31) };
ECHO BOTH $IF $EQU $LAST[1] 8 "PASSED" "***FAILED";
ECHO BOTH ": SPARQL distance filter: " $LAST[1] "\n";

sparql select count (*) where { graph <urn:tvr:probe> { ?s ?p ?o . ?o bif:knnSimilar "tvr probe 653" option (limit 20, score ?sim) . filter (?sim > 0.84 && ?sim < 0.87) } };
ECHO BOTH $IF $EQU $LAST[1] 5 "PASSED" "***FAILED";
ECHO BOTH ": GRAPH <urn:tvr:probe>: " $LAST[1] "\n";

sparql select count (*) from <urn:tvr:probe2> where { ?s ?p ?o . ?o bif:knnSimilar "tvr probe 653" option (limit 20, score ?sim) . filter (?sim > 0.84 && ?sim < 0.87) };
ECHO BOTH $IF $EQU $LAST[1] 3 "PASSED" "***FAILED";
ECHO BOTH ": FROM <urn:tvr:probe2>: " $LAST[1] "\n";

sparql select count (*) where { ?s <urn:tvr:text> ?t . ?s <urn:tvr:note> ?n .
  ?t bif:knnSimilar "tvr probe 653" option (limit 20, score ?s1) .
  ?n bif:knnSimilar "tvr note 587" option (limit 20, score ?s2) . filter (?s1 > 0.84 && ?s1 < 0.87 && ?s2 > 0.84 && ?s2 < 0.87) };
ECHO BOTH $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";
ECHO BOTH ": two knnSimilar in one pattern: " $LAST[1] "\n";

sparql select count (*) where {
  { ?s ?p ?o . ?o bif:knnSimilar "tvr probe 653" option (limit 20, score ?x) . filter (?x > 0.84 && ?x < 0.87) }
  union
  { ?s ?p ?o . ?o bif:knnSimilar "tvr note 587" option (limit 20, score ?x) . filter (?x > 0.84 && ?x < 0.87) } };
ECHO BOTH $IF $EQU $LAST[1] 10 "PASSED" "***FAILED";
ECHO BOTH ": UNION of two searches: " $LAST[1] "\n";

sparql select count (?n) where { graph <urn:tvr:probe> { ?s <urn:tvr:text> ?t }
  optional { ?s <urn:tvr:note> ?n . ?n bif:knnSimilar "tvr note 587" option (limit 20) } };
ECHO BOTH $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";
ECHO BOTH ": knnSimilar inside OPTIONAL: " $LAST[1] "\n";

sparql select count (distinct ?s) where { graph <urn:tvr:probe> { ?s <urn:tvr:text> ?t }
  filter not exists { ?s <urn:tvr:note> ?n . ?n bif:knnSimilar "tvr note 587" option (limit 20) } };
ECHO BOTH $IF $EQU $LAST[1] 3 "PASSED" "***FAILED";
ECHO BOTH ": knnSimilar inside FILTER NOT EXISTS: " $LAST[1] "\n";

sparql select count (*) where { { select distinct ?o where { ?s ?p ?o . ?o bif:knnSimilar "tvr probe 653" option (limit 20, score ?x) . filter (?x > 0.84 && ?x < 0.87) } limit 3 } };
ECHO BOTH $IF $EQU $LAST[1] 3 "PASSED" "***FAILED";
ECHO BOTH ": subquery with LIMIT 3: " $LAST[1] "\n";

sparql select ?g count (*) where { graph ?g { ?s ?p ?o . ?o bif:knnSimilar "tvr probe 653" option (limit 20, score ?sim) . filter (?sim > 0.84 && ?sim < 0.87) } } group by ?g order by desc (count (*));
ECHO BOTH $IF $EQU $ROWCNT 2 "PASSED" "***FAILED";
ECHO BOTH ": GROUP BY graph gives 2 graphs\n";
ECHO BOTH $IF $EQU $LAST[2] 3 "PASSED" "***FAILED";
ECHO BOTH ": the smaller one has 3: " $LAST[2] "\n";

-- a Products row: the view sync trigger turns it into a quad of urn:tvr:nw
insert into "Demo"."demo"."Products" ("ProductID", "ProductName", "SupplierID", "CategoryID", "QuantityPerUnit", "UnitPrice", "UnitsInStock", "UnitsOnOrder", "ReorderLevel", "Discontinued")
  values (9001, 'tvr probe 653 1007 northwind product', 1, 1, '1 box', 1.0, 1, 0, 0, 0);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": Products row inserted STATE=" $STATE "\n";

select case when count (*) >= 1 then 1 else 0 end, count (*) from DB.DBA.RDF_OBJ_VEC_LOG;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": the product's literals were logged: " $LAST[2] "\n";

select case when DB.DBA.RDF_OBJ_VEC_LOG_DRAIN (10000) >= 1 then 1 else 0 end;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": drain consumed them\n";

select count (*) from DB.DBA.RDF_OBJ_VEC_LOG;
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": change log empty: " $LAST[1] "\n";

select count (*) from DB.DBA.RDF_QUAD where G = iri_to_id ('urn:tvr:nw') and knnSimilar (O, 'tvr probe 653', 20) and SIMILARITY between 0.84 and 0.87;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": the new product is found in urn:tvr:nw: " $LAST[1] "\n";

select count (distinct O) from DB.DBA.RDF_QUAD where knnSimilar (O, 'tvr probe 653', 20) and SIMILARITY between 0.84 and 0.87;
ECHO BOTH $IF $EQU $LAST[1] 7 "PASSED" "***FAILED";
ECHO BOTH ": 7 probe literals now: " $LAST[1] "\n";

delete from "Demo"."demo"."Products" where "ProductID" = 9001;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": Products row deleted STATE=" $STATE "\n";

select count (*) from DB.DBA.RDF_QUAD where G = iri_to_id ('urn:tvr:nw') and knnSimilar (O, 'tvr probe 653', 20) and SIMILARITY between 0.84 and 0.87;
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": its quad is gone from urn:tvr:nw: " $LAST[1] "\n";

-- ---------------------------------------------------------------------------
-- A.6 Remove a graph and a triple
-- ---------------------------------------------------------------------------

sparql clear graph <urn:tvr:probe2>;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": clear graph urn:tvr:probe2 STATE=" $STATE "\n";

select count (distinct O) from DB.DBA.RDF_QUAD where knnSimilar (O, 'tvr probe 653', 20) and SIMILARITY between 0.84 and 0.87;
ECHO BOTH $IF $EQU $LAST[1] 5 "PASSED" "***FAILED";
ECHO BOTH ": 5 probe literals still in a quad: " $LAST[1] "\n";

select count (*) from DB.DBA.RDF_QUAD where knnSimilar (O, 'tvr probe 653', 20) and SIMILARITY between 0.84 and 0.87;
ECHO BOTH $IF $EQU $LAST[1] 5 "PASSED" "***FAILED";
ECHO BOTH ": 5 quads: " $LAST[1] "\n";

sparql delete data { graph <urn:tvr:probe> { <urn:tvr:s1> <urn:tvr:text> "tvr probe 653 1001 alpha literal one" } };
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": delete one triple STATE=" $STATE "\n";

sparql select count (*) where { ?s ?p ?o . ?o bif:knnSimilar "tvr probe 653" option (limit 20, score ?sim) . filter (?sim > 0.84 && ?sim < 0.87) };
ECHO BOTH $IF $EQU $LAST[1] 4 "PASSED" "***FAILED";
ECHO BOTH ": 4 left: " $LAST[1] "\n";

select count (*) from DB.DBA.RDF_OBJ_VEC_LOG;
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": removals log nothing: " $LAST[1] "\n";

-- ---------------------------------------------------------------------------
-- A.7 Drop
-- ---------------------------------------------------------------------------

DB.DBA.RDF_OBJ_VEC_INDEX_DROP ('urn:tvr:nw:all');
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": drop urn:tvr:nw:all STATE=" $STATE "\n";

select count (*) from DB.DBA.RDF_OBJ_VEC_INDEX;
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": registry empty: " $LAST[1] "\n";

select count (*) from DB.DBA.SYS_KEYS where KEY_TABLE = 'DB.DBA.RDF_OBJ' and KEY_NAME = 'RDF_OBJ_urn_tvr_nw_all';
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": index key gone: " $LAST[1] "\n";

select DB.DBA.TVR_ROWS ('DB.DBA.RDF_OBJ_urn_tvr_nw_all_embeddings'), DB.DBA.TVR_ROWS ('DB.DBA.RDF_OBJ_urn_tvr_nw_all_ROSRC');
ECHO BOTH $IF $EQU $LAST[1] -1 "PASSED" "***FAILED";
ECHO BOTH ": embeddings table gone: " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[2] -1 "PASSED" "***FAILED";
ECHO BOTH ": bookkeeping table gone: " $LAST[2] "\n";

select count (*) from DB.DBA.SYS_TRIGGERS where upper (T_TABLE) = upper ('DB.DBA.RDF_OBJ_urn_tvr_nw_all_embeddings');
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": guard triggers gone: " $LAST[1] "\n";

-- its key_id goes to the next key created, so its epoch row must not stay behind
select count (*) from DB.DBA.VEC_INDEX_EPOCH where VIE_NAME = 'RDF_OBJ_urn_tvr_nw_all';
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": epoch row gone: " $LAST[1] "\n";

select __vec_rdf_obj_active ();
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": no active RDF_OBJ index: " $LAST[1] "\n";

-- the same statement texts as above, so these are the plans this connection has cached
select count (distinct O) from DB.DBA.RDF_QUAD where knnSimilar (O, 'tvr probe 653', 20) and SIMILARITY between 0.84 and 0.87;
ECHO BOTH $IF $EQU $STATE 42S12 "PASSED" "***FAILED";
ECHO BOTH ": cached SQL plan recompiled and refused STATE=" $STATE "\n";

sparql select count (*) where { ?s ?p ?o . ?o bif:knnSimilar "tvr probe 653" option (limit 20, score ?sim) . filter (?sim > 0.84 && ?sim < 0.87) };
ECHO BOTH $IF $EQU $STATE 42S12 "PASSED" "***FAILED";
ECHO BOTH ": cached SPARQL plan recompiled and refused STATE=" $STATE "\n";

-- ---------------------------------------------------------------------------
-- B.1 Define only
-- ---------------------------------------------------------------------------

echo BOTH "\n--- B. index created step by step ---\n";

DB.DBA.RDF_OBJ_VEC_INDEX_CREATE ('urn:tvr:nw:steps', 'tvr-1024', null, 0, null, 'bulk', 0);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": define urn:tvr:nw:steps STATE=" $STATE "\n";

select RVI_NAME, RVI_STATE from DB.DBA.RDF_OBJ_VEC_INDEX;
ECHO BOTH $IF $EQU $LAST[1] RDF_OBJ_urn_tvr_nw_steps "PASSED" "***FAILED";
ECHO BOTH ": key name " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[2] new "PASSED" "***FAILED";
ECHO BOTH ": state " $LAST[2] "\n";

select DB.DBA.TVR_ROWS ('DB.DBA.RDF_OBJ_urn_tvr_nw_steps_embeddings'), DB.DBA.TVR_ROWS ('DB.DBA.RDF_OBJ_urn_tvr_nw_steps_ROSRC');
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": nothing embedded yet: " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[2] 0 "PASSED" "***FAILED";
ECHO BOTH ": bookkeeping empty: " $LAST[2] "\n";

-- ---------------------------------------------------------------------------
-- B.2 Embed
-- ---------------------------------------------------------------------------

select aref (DB.DBA.RDF_OBJ_VEC_INDEX_EMBED ('urn:tvr:nw:steps'), 0) - DB.DBA.TVR_ELIGIBLE ();
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": embed stages every eligible literal (embedded - eligible = " $LAST[1] ")\n";

select RVI_STATE from DB.DBA.RDF_OBJ_VEC_INDEX;
ECHO BOTH $IF $EQU $LAST[1] embedded "PASSED" "***FAILED";
ECHO BOTH ": state " $LAST[1] "\n";

select case when DB.DBA.TVR_ROWS ('DB.DBA.RDF_OBJ_urn_tvr_nw_steps_embeddings') = DB.DBA.TVR_ELIGIBLE ()
             and DB.DBA.TVR_ROWS ('DB.DBA.RDF_OBJ_urn_tvr_nw_steps_ROSRC') = DB.DBA.TVR_ELIGIBLE () then 1 else 0 end,
       DB.DBA.TVR_ROWS ('DB.DBA.RDF_OBJ_urn_tvr_nw_steps_embeddings'), DB.DBA.TVR_ELIGIBLE ();
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": embeddings = bookkeeping = eligible: " $LAST[2] " / " $LAST[3] "\n";

-- new literals while embedded: logged, and the drain holds them
sparql insert data { graph <urn:tvr:probe> {
  <urn:tvr:s7> <urn:tvr:text> "tvr third 293 401 seventh subject literal" .
  <urn:tvr:s8> <urn:tvr:text> "tvr third 293 402 eighth subject literal" . } };
select count (*) from DB.DBA.RDF_OBJ_VEC_LOG;
ECHO BOTH $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";
ECHO BOTH ": 2 new literals logged: " $LAST[1] "\n";

select DB.DBA.RDF_OBJ_VEC_LOG_DRAIN (10000);
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": drain holds them while the index is not built: " $LAST[1] "\n";

select count (*) from DB.DBA.RDF_OBJ_VEC_LOG;
ECHO BOTH $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";
ECHO BOTH ": still logged: " $LAST[1] "\n";

-- an interrupted embedding: bookkeeping for 5 literals lost; the next run redoes just
-- those and the 2 new literals
create procedure DB.DBA.TVR_FORGET_5 ()
{
  declare st, msg varchar;
  declare md, rs any;
  declare inx integer;
  exec ('select top 5 RV_ID from DB.DBA."RDF_OBJ_urn_tvr_nw_steps_ROSRC" order by RV_ID', st, msg, vector (), 0, md, rs);
  for (inx := 0; inx < length (rs); inx := inx + 1)
    exec ('delete from DB.DBA."RDF_OBJ_urn_tvr_nw_steps_ROSRC" where RV_ID = ?', st, msg, vector (rs[inx][0]));
  commit work;
}
;
DB.DBA.TVR_FORGET_5 ();
select DB.DBA.TVR_ROWS ('DB.DBA.RDF_OBJ_urn_tvr_nw_steps_ROSRC') - DB.DBA.TVR_ELIGIBLE ();
ECHO BOTH $IF $EQU $LAST[1] -7 "PASSED" "***FAILED";
ECHO BOTH ": 7 literals short of complete: " $LAST[1] "\n";

select aref (DB.DBA.RDF_OBJ_VEC_INDEX_EMBED ('urn:tvr:nw:steps'), 0);
ECHO BOTH $IF $EQU $LAST[1] 7 "PASSED" "***FAILED";
ECHO BOTH ": resumed embedding did only the missing 7: " $LAST[1] "\n";

select case when DB.DBA.TVR_ROWS ('DB.DBA.RDF_OBJ_urn_tvr_nw_steps_ROSRC') = DB.DBA.TVR_ELIGIBLE ()
             and DB.DBA.TVR_ROWS ('DB.DBA.RDF_OBJ_urn_tvr_nw_steps_embeddings') = DB.DBA.TVR_ELIGIBLE () then 1 else 0 end;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": complete again\n";

select aref (DB.DBA.RDF_OBJ_VEC_INDEX_EMBED ('urn:tvr:nw:steps'), 0);
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": a further embed has nothing to do: " $LAST[1] "\n";

-- ---------------------------------------------------------------------------
-- B.3 Build
-- ---------------------------------------------------------------------------

select DB.DBA.RDF_OBJ_VEC_INDEX_BUILD ('urn:tvr:nw:steps');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": build STATE=" $STATE "\n";

select RVI_STATE from DB.DBA.RDF_OBJ_VEC_INDEX;
ECHO BOTH $IF $EQU $LAST[1] ready "PASSED" "***FAILED";
ECHO BOTH ": state " $LAST[1] "\n";

select DB.DBA.RDF_OBJ_VEC_LOG_DRAIN (10000);
ECHO BOTH $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";
ECHO BOTH ": the held literals are drained once built: " $LAST[1] "\n";

select count (*) from DB.DBA.RDF_OBJ_VEC_LOG;
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": change log empty: " $LAST[1] "\n";

select case when DB.DBA.TVR_ROWS ('DB.DBA.RDF_OBJ_urn_tvr_nw_steps_embeddings') = DB.DBA.TVR_ELIGIBLE () then 1 else 0 end;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": embeddings = eligible\n";

-- ---------------------------------------------------------------------------
-- B.4 The same queries against the step-by-step index
-- ---------------------------------------------------------------------------

select case when count (distinct O) between 1 and 5 then 1 else 0 end, count (distinct O) from DB.DBA.RDF_QUAD where knnSimilar (O, 'Soft drinks, coffees, teas', 5);
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": k = 5 gives 1 to 5 distinct literals: " $LAST[2] "\n";

select count (*) from DB.DBA.RDF_QUAD where knnSimilar (O, 'tvr probe 653', 20) and SIMILARITY between 0.84 and 0.87;
ECHO BOTH $IF $EQU $LAST[1] 4 "PASSED" "***FAILED";
ECHO BOTH ": 4 probe quads, as left by phase A: " $LAST[1] "\n";

select count (distinct O) from DB.DBA.RDF_QUAD where knnSimilar (O, 'tvr third 293', 20) and SIMILARITY between 0.84 and 0.87;
ECHO BOTH $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";
ECHO BOTH ": the 2 literals added while embedded: " $LAST[1] "\n";

select case when x."c" = DB.DBA.TVR_DESCRIPTIONS () then 1 else 0 end, x."c", DB.DBA.TVR_DESCRIPTIONS () from
  (sparql select (count (distinct ?c) as ?c) from <urn:tvr:nw> where { ?c <http://localhost:8890/schemas/Demo/description> ?d .
    ?d bif:knnSimilar "Soft drinks, coffees, teas" option (index <urn:tvr:nw:steps>, limit 100000) }) x;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": every indexed category description with k = everything: " $LAST[2] " / " $LAST[3] "\n";

sparql select count (*) where { ?s <urn:tvr:text> ?t . ?t bif:knnSimilar "tvr probe 653" option (limit 20, score ?sim, distance ?d) . filter (?sim > 0.84 && ?sim < 0.87 && ?d > 0.28 && ?d < 0.31) };
ECHO BOTH $IF $EQU $LAST[1] 4 "PASSED" "***FAILED";
ECHO BOTH ": SPARQL score and distance: " $LAST[1] "\n";

select DB.DBA.TVR_PLAN_HAS ('select S from DB.DBA.RDF_QUAD where knnSimilar (O, ''tvr probe 653'', 5)', 'rdf_obj driving');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": plan: the vector search leads: " $LAST[1] "\n";

-- ---------------------------------------------------------------------------
-- B.5 Names: a collision, and a second index
-- ---------------------------------------------------------------------------

DB.DBA.RDF_OBJ_VEC_INDEX_CREATE ('urn/tvr/nw/steps', 'tvr-1024', null, 0, null, 'bulk', 0);
ECHO BOTH $IF $EQU $STATE 42000 "PASSED" "***FAILED";
ECHO BOTH ": a name that maps to the same key is refused STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

DB.DBA.RDF_OBJ_VEC_INDEX_CREATE ('urn:tvr:nw:steps', 'tvr-1024', null, 0, null, 'bulk', 0);
ECHO BOTH $IF $EQU $STATE 42000 "PASSED" "***FAILED";
ECHO BOTH ": creating it again is refused STATE=" $STATE "\n";

DB.DBA.RDF_OBJ_VEC_INDEX_CREATE ('urn:tvr:second', 'tvr-1024', null, 20, vector ('en'), 'bulk', 0);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": define a second index STATE=" $STATE "\n";

select count (*) from DB.DBA.RDF_OBJ_VEC_INDEX;
ECHO BOTH $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";
ECHO BOTH ": two registry rows: " $LAST[1] "\n";

select count (*) from DB.DBA.RDF_QUAD where knnSimilar (O, 'tvr probe 653', 20);
ECHO BOTH $IF $EQU $STATE 42000 "PASSED" "***FAILED";
ECHO BOTH ": no index named with two to choose from is refused STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select count (*) from DB.DBA.RDF_QUAD where knnSimilar (O, 'tvr probe 653', 'urn:tvr:nw:steps', 20) and SIMILARITY between 0.84 and 0.87;
ECHO BOTH $IF $EQU $LAST[1] 4 "PASSED" "***FAILED";
ECHO BOTH ": the named one answers: " $LAST[1] "\n";

sparql select count (*) where { ?s ?p ?o . ?o bif:knnSimilar "tvr probe 653" option (index <urn:tvr:nw:steps>, limit 20, score ?sim) . filter (?sim > 0.84 && ?sim < 0.87) };
ECHO BOTH $IF $EQU $LAST[1] 4 "PASSED" "***FAILED";
ECHO BOTH ": SPARQL names it: " $LAST[1] "\n";

select count (*) from DB.DBA.RDF_QUAD where knnSimilar (O, 'tvr probe 653', 'urn:tvr:no:such', 20);
ECHO BOTH $IF $EQU $STATE 42S12 "PASSED" "***FAILED";
ECHO BOTH ": an unknown index name is refused STATE=" $STATE "\n";

DB.DBA.RDF_OBJ_VEC_INDEX_DROP ('urn:tvr:second');
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": drop the second index STATE=" $STATE "\n";

select count (*) from DB.DBA.RDF_OBJ_VEC_INDEX;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": one registry row again: " $LAST[1] "\n";

-- ---------------------------------------------------------------------------
-- B.6 Build again, then drop
-- ---------------------------------------------------------------------------

select DB.DBA.RDF_OBJ_VEC_INDEX_BUILD ('urn:tvr:nw:steps');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": a second build STATE=" $STATE "\n";

select count (*) from DB.DBA.RDF_QUAD where knnSimilar (O, 'tvr probe 653', 20) and SIMILARITY between 0.84 and 0.87;
ECHO BOTH $IF $EQU $LAST[1] 4 "PASSED" "***FAILED";
ECHO BOTH ": same answer after it: " $LAST[1] "\n";

DB.DBA.RDF_OBJ_VEC_INDEX_DROP ('urn:tvr:nw:steps');
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": drop urn:tvr:nw:steps STATE=" $STATE "\n";

select count (*) from DB.DBA.RDF_OBJ_VEC_INDEX;
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": registry empty: " $LAST[1] "\n";

select count (*) from DB.DBA.SYS_KEYS where KEY_TABLE = 'DB.DBA.RDF_OBJ' and upper (KEY_NAME) like 'RDF_OBJ_URN_TVR_%';
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": no index key left: " $LAST[1] "\n";

select count (*) from DB.DBA.VEC_INDEX_EPOCH where VIE_NAME like 'RDF_OBJ_urn_tvr_%';
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": no epoch row left: " $LAST[1] "\n";

select count (*) from DB.DBA.SYS_KEYS where upper (KEY_TABLE) like 'DB.DBA.RDF_OBJ_URN_TVR_%';
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": no index table left (embeddings, bookkeeping, staging): " $LAST[1] "\n";

select count (*) from DB.DBA.RDF_QUAD where knnSimilar (O, 'tvr probe 653', 20) and SIMILARITY between 0.84 and 0.87;
ECHO BOTH $IF $EQU $STATE 42S12 "PASSED" "***FAILED";
ECHO BOTH ": query refused after the drop STATE=" $STATE "\n";

-- ---------------------------------------------------------------------------
-- Cleanup
-- ---------------------------------------------------------------------------

sparql clear graph <urn:tvr:probe>;
sparql clear graph <urn:tvr:probe2>;
delete from DB.DBA.ONNX_MODELS where model_name = 'tvr-1024';
drop procedure DB.DBA.TVR_ROWS;
drop procedure DB.DBA.TVR_TABLE;
drop procedure DB.DBA.TVR_ELIGIBLE;
drop procedure DB.DBA.TVR_PLAN_HAS;
drop procedure DB.DBA.TVR_GRAPH_INDEXED;
drop procedure DB.DBA.TVR_FORGET_5;
drop procedure DB.DBA.TVR_DESCRIPTIONS;
registry_remove ('__vec_embed_concurrency');

echo BOTH "COMPLETED: RDF_OBJ vector index and knnSimilar\n";
