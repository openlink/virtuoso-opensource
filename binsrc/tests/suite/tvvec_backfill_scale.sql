--
--  tvvec_backfill_scale.sql
--
--  Regression test for the SPARQL vector-index backfill row-count cap.
--
--  VEC_INDEX_REFRESH used to enumerate the selector's whole (key,text) set with
--  exec(..., 10000, ...) -- exec's 5th argument is MAX-ROWS -- in both the
--  shorthand and general branches, so any index over 10,000 documents was
--  silently built incomplete (only the first 10,000 rows indexed; state still
--  'active', no error).  The fix streams the enumeration into a staging table
--  and embeds it in bounded keyset pages (VEC_INDEX_BACKFILL_PAGED).
--
--  This test builds BOTH a general (KEY/EMBEDDING/WHERE) and a shorthand
--  (ON GRAPH / FOR PREDICATE) index over a corpus that is deliberately LARGER
--  than the old 10,000 cap (10,500 docs -> two keyset pages of 10,000 + 500),
--  and asserts every document made it into the native index
--  (graph_nodes == corpus size), and that no staging table leaked.
--
--  Requires a real embedding backend: it uses 'granite-384-local', registered
--  and loaded by tvvec_begin.sql, so tvvec.sh runs it only under the ONNX gate.
--  (The deterministic 'test_embedding' model cannot exercise this path -- it has
--  no embedding handle, so the backfill's embed step is a no-op there.)
--
--  Run with (after tvvec_begin.sql, on an ONNX-enabled server):
--    isql <port> dba dba binsrc/tests/suite/tvvec_backfill_scale.sql
--

echo BOTH "STARTED: SPARQL Vector Index backfill row-cap / scale\n";

-- Corpus size: exceeds the old 10,000 exec cap AND the 10,000-row keyset page
-- size, so the multi-page backfill path is exercised (10,000 + 500).

-- Helper: fetch a field from __VEC_INDEX_METRICS output (key-value vector).
create function DB.DBA.TVEC_BFS_KV_GET (in kv any, in key_name varchar) returns any
{
  declare inx integer;
  if (not isvector (kv))
    return null;
  for (inx := 0; inx < length (kv); inx := inx + 2)
    {
      if (cast (aref (kv, inx) as varchar) = key_name)
        return aref (kv, inx + 1);
    }
  return null;
};
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": create TVEC_BFS_KV_GET helper STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

-- Helper: count leftover backfill staging tables ("<internal>_BF").
create function DB.DBA.TVEC_BFS_STAGING_COUNT () returns integer
{
  return (select count (*) from DB.DBA.SYS_KEYS
          where right (upper (KEY_TABLE), 3) = '_BF' and KEY_IS_MAIN = 1);
};
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": create TVEC_BFS_STAGING_COUNT helper STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

-- Helper: generate an n-document corpus into a graph (isql does not execute a
-- bare compound block).  Each subject carries a type triple (general selector)
-- and a distinctive text triple (both selectors); "zeta<N>kappa" keeps texts unique.
create procedure DB.DBA.TVEC_BFS_LOAD (in g varchar, in n integer)
{
  declare ses any;
  declare i integer;
  ses := string_output ();
  for (i := 1; i <= n; i := i + 1)
    {
      http (sprintf ('<%s:d:%d> <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <urn:bfscale:Doc> .\n', g, i), ses);
      http (sprintf ('<%s:d:%d> <urn:bfscale:text> "confidential scale document zeta%dkappa on fiscal topic %d in segment %d" .\n', g, i, i, i, i), ses);
    }
  DB.DBA.TTLP (string_output_string (ses), '', g);
};
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": create TVEC_BFS_LOAD helper STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

-- Pre-clean any leftovers from a prior run.
sparql define input:storage "" drop silent vector index <urn:bfscale:gen-idx>;
sparql define input:storage "" drop silent vector index <urn:bfscale:short-idx>;
sparql define input:storage "" clear graph <urn:bfscale>;
sparql define input:storage "" clear graph <urn:bfscale2>;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": backfill-scale pre-clean STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

-- Generate a >10,000-document corpus into <urn:bfscale> for the general selector
-- (this is what proves the cap is gone), and a small corpus into <urn:bfscale2>
-- for the shorthand wiring smoke-test (both branches call the same helper, so the
-- >10k path only needs proving once and the shorthand corpus is kept small to
-- keep total embedding time reasonable).
DB.DBA.TVEC_BFS_LOAD ('urn:bfscale', 10500);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": load 10500-doc general corpus STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

DB.DBA.TVEC_BFS_LOAD ('urn:bfscale2', 40);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": load 40-doc shorthand corpus STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select count (*) from (sparql define input:storage ""
  select ?s where { graph <urn:bfscale> { ?s a <urn:bfscale:Doc> } }) as sub;
ECHO BOTH $IF $EQU $LAST[1] 10500 "PASSED" "***FAILED";
ECHO BOTH ": corpus document count (expect 10500)=" $LAST[1] "\n";

-- ===========================================================================
--  General selector (KEY / EMBEDDING / WHERE), manual maintenance.
-- ===========================================================================
sparql define input:storage ""
create vector index <urn:bfscale:gen-idx>
  key ?doc
  embedding ?txt
  where {
    graph <urn:bfscale> {
      ?doc a <urn:bfscale:Doc> ;
           <urn:bfscale:text> ?txt
    }
  }
  using model 'granite-384-local'
  with (dimensions = 384, distance = 'cosine', maintenance = 'manual')
;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": CREATE VECTOR INDEX (general) STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

sparql define input:storage "" refresh vector index <urn:bfscale:gen-idx>;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": REFRESH (general) STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select SVI_STATE from DB.DBA.SPARQL_VEC_INDEX where SVI_IRI = 'urn:bfscale:gen-idx';
ECHO BOTH $IF $EQU $LAST[1] active "PASSED" "***FAILED";
ECHO BOTH ": general index state (expect active)=" $LAST[1] "\n";

-- THE regression assertion: every one of the 10,500 docs is in the native index
-- (was capped at 10,000 before the fix).
select cast (DB.DBA.TVEC_BFS_KV_GET (
  __VEC_INDEX_METRICS (DB.DBA.VEC_INDEX_GENERATE_NAME ('urn:bfscale:gen-idx')),
  'graph_nodes') as integer);
ECHO BOTH $IF $EQU $LAST[1] 10500 "PASSED" "***FAILED";
ECHO BOTH ": general graph_nodes (expect 10500, was capped at 10000)=" $LAST[1] "\n";

select cast (DB.DBA.TVEC_BFS_KV_GET (
  __VEC_INDEX_METRICS (DB.DBA.VEC_INDEX_GENERATE_NAME ('urn:bfscale:gen-idx')),
  'managed_rows') as integer);
ECHO BOTH $IF $EQU $LAST[1] 10500 "PASSED" "***FAILED";
ECHO BOTH ": general managed_rows (expect 10500)=" $LAST[1] "\n";

select cast (DB.DBA.TVEC_BFS_KV_GET (
  __VEC_INDEX_METRICS (DB.DBA.VEC_INDEX_GENERATE_NAME ('urn:bfscale:gen-idx')),
  'deleted_nodes') as integer);
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": general deleted_nodes (expect 0)=" $LAST[1] "\n";

-- A document beyond the old cap is reachable end to end -- it was entirely
-- absent from the index before the fix.
--
-- Asserted as membership in the top 20, not as rank 1.  HNSW is approximate and
-- does not guarantee the true nearest neighbour: the backfill embeds through
-- VEC_INDEX_EMBED_CONCURRENCY workers (4 by default), so rows reach the graph in
-- a nondeterministic order and the neighbour lists differ between builds of the
-- same corpus.  At limit 1 this failed about one run in three on unchanged code
-- (581/1, 582/0, 582/0 measured 2026-09-18) while graph_nodes, managed_rows and
-- deleted_nodes above passed on the failing run too.  Do not tighten it back.
--
-- Completeness is what the three assertions above are for; this one is here for
-- the path -- SPARQL bif:vector_search through the general selector into the
-- native index -- and a top-20 miss on a self-query would be a real recall
-- failure worth looking at.
select count (*) from (sparql define input:storage ""
  select (str (?doc)) as ?d where {
    ?doc bif:vector_search "confidential scale document zeta10345kappa on fiscal topic 10345 in segment 10345"
         option (index <urn:bfscale:gen-idx>, score ?sc, limit 20)
  }) as sub;
ECHO BOTH $IF $EQU $LAST[1] 20 "PASSED" "***FAILED";
ECHO BOTH ": general search over the >10k index returns hits=" $LAST[1] " (expect 20)\n";

-- Matched with a SPARQL FILTER rather than in SQL: a str () projection comes
-- back RDF-boxed and does not compare equal to a plain SQL string, so the SQL
-- form silently counts zero.
select count (*) from (sparql define input:storage ""
  select ?doc where {
    ?doc bif:vector_search "confidential scale document zeta10345kappa on fiscal topic 10345 in segment 10345"
         option (index <urn:bfscale:gen-idx>, score ?sc, limit 20)
    filter (?doc = <urn:bfscale:d:10345>)
  }) as sub;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": doc 10345 (beyond old cap) is among the top 20, found=" $LAST[1] " (expect 1)\n";

-- ===========================================================================
--  Shorthand selector (ON GRAPH / FOR PREDICATE), manual maintenance.
--  Small corpus: proves the shorthand branch builds its enumeration and drives
--  the same VEC_INDEX_BACKFILL_PAGED helper (the >10k path is proven above).
-- ===========================================================================
sparql define input:storage ""
create vector index <urn:bfscale:short-idx>
  on graph <urn:bfscale2>
  for predicate <urn:bfscale:text>
  using model 'granite-384-local'
  with (dimensions = 384, distance = 'cosine', maintenance = 'manual')
;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": CREATE VECTOR INDEX (shorthand) STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

sparql define input:storage "" refresh vector index <urn:bfscale:short-idx>;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": REFRESH (shorthand) STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select cast (DB.DBA.TVEC_BFS_KV_GET (
  __VEC_INDEX_METRICS (DB.DBA.VEC_INDEX_GENERATE_NAME ('urn:bfscale:short-idx')),
  'graph_nodes') as integer);
ECHO BOTH $IF $EQU $LAST[1] 40 "PASSED" "***FAILED";
ECHO BOTH ": shorthand graph_nodes (expect 40)=" $LAST[1] "\n";

-- ===========================================================================
--  Staging table must not leak after either backfill.
-- ===========================================================================
select DB.DBA.TVEC_BFS_STAGING_COUNT ();
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": no backfill staging tables leaked (expect 0)=" $LAST[1] "\n";

-- ===========================================================================
--  Cleanup.
-- ===========================================================================
sparql define input:storage "" drop silent vector index <urn:bfscale:gen-idx>;
sparql define input:storage "" drop silent vector index <urn:bfscale:short-idx>;
sparql define input:storage "" clear graph <urn:bfscale>;
sparql define input:storage "" clear graph <urn:bfscale2>;
drop function DB.DBA.TVEC_BFS_KV_GET;
drop function DB.DBA.TVEC_BFS_STAGING_COUNT;
drop procedure DB.DBA.TVEC_BFS_LOAD;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": backfill-scale cleanup STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

echo BOTH "COMPLETED: SPARQL Vector Index backfill row-cap / scale\n";
