--
--  tvvec_search_graph_var.sql
--
--  bif:vector_search inside GRAPH ?g, and over a default graph of several
--  FROM graphs.
--
--  The search was a derived table with the subject and score columns only,
--  while the rest of the query reads the triple's graph wherever the graph is
--  a variable: every such form failed to compile with
--  SQ200 No column s_1_1_t0.G.  GRAPH ?g { ... } filter (?g = <g>) also
--  passed required_graph_iri = 0.
--
--  The search is given the graphs the query allows -- the FROM NAMED or FROM
--  graphs, or any graph -- so that `limit` counts hits in them, and gives the
--  graph of each hit: a shorthand index's hits are in its graph; a general
--  selector's hit is in each allowed graph that has a triple with the hit as
--  its subject.  graph ?g { ... } filter (?g = <g>) and graph <g> { ... } agree.
--  A default graph of several FROM graphs is their merge: a subject comes once.
--  A subject in two indexes keeps the graph of each with GRAPH ?g.
--
--  1-11, 13-17 are tests of the change; 12 is a guard and holds on both
--  sides.  Run by tvvec_rdf_quad.sh, which sets CaseMode 2,
--  so a score variable ?G meets the graph's column name case-insensitively:
--  before, 13 read the score as the graph.
--
--  Self-contained: its own graphs, model and indexes, removed at the end.  Every
--  search asks for more hits than there are documents, so the answers do not
--  depend on scores.
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

echo BOTH "STARTED: bif:vector_search with a variable graph\n";

-- ---------------------------------------------------------------------------
-- Fixtures
-- ---------------------------------------------------------------------------
--  g1: a, b, c named; g2: d named; g3: a and e annotated (not indexed);
--  g4: e titled.  <urn:tgv:idx> is a general selector over the names in g1
--  and g2, <urn:tgv:sh> a shorthand index over the titles in g4.

delete from DB.DBA.ONNX_MODELS where model_name = 'tgv-8';
insert into DB.DBA.ONNX_MODELS
  (model_name, description, model_path, model_type, output_name, output_shape, created_at, updated_at)
values
  ('tgv-8', 'graph variable test model', 'internal:tgv-8', 'test_embedding', 'embedding', '1,8', now (), now ());
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": register tgv-8 STATE=" $STATE "\n";

sparql define input:storage "" drop silent vector index <urn:tgv:idx>;
sparql define input:storage "" drop silent vector index <urn:tgv:sh>;
sparql define input:storage "" drop silent vector index <urn:tgv:sh3>;
sparql define input:storage "" clear graph <urn:tgv:g1>;
sparql define input:storage "" clear graph <urn:tgv:g2>;
sparql define input:storage "" clear graph <urn:tgv:g3>;
sparql define input:storage "" clear graph <urn:tgv:g4>;
sparql define input:storage ""
insert data {
  graph <urn:tgv:g1> {
    <urn:tgv:a> <urn:tgv:name> "alpha 1" .
    <urn:tgv:b> <urn:tgv:name> "beta 2" .
    <urn:tgv:c> <urn:tgv:name> "gamma 3" .
  }
  graph <urn:tgv:g2> {
    <urn:tgv:d> <urn:tgv:name> "delta 4" .
  }
  graph <urn:tgv:g3> {
    <urn:tgv:a> <urn:tgv:note> "also here" .
    <urn:tgv:e> <urn:tgv:note> "also here" .
  }
  graph <urn:tgv:g4> {
    <urn:tgv:e> <urn:tgv:title> "epsilon 2" .
  }
};
sparql define input:storage ""
create vector index <urn:tgv:idx> key ?d embedding ?t
  where { graph ?g { ?d <urn:tgv:name> ?t } filter (?g in (<urn:tgv:g1>, <urn:tgv:g2>)) }
  using model 'tgv-8' with (dimensions = 8, hnsw_m = 8, ef_construction = 16);
sparql define input:storage ""
create vector index <urn:tgv:sh> on graph <urn:tgv:g4> for predicate <urn:tgv:title>
  using model 'tgv-8' with (dimensions = 8, hnsw_m = 8, ef_construction = 16);
--  <urn:tgv:sh3>: a shorthand index over the notes in g3, so e is a hit of
--  two shorthand indexes over two graphs (16).
sparql define input:storage ""
create vector index <urn:tgv:sh3> on graph <urn:tgv:g3> for predicate <urn:tgv:note>
  using model 'tgv-8' with (dimensions = 8, hnsw_m = 8, ef_construction = 16);
select aref (aref (DB.DBA.VEC_INDEX_REFRESH ('urn:tgv:idx'), 0), 0), aref (aref (DB.DBA.VEC_INDEX_REFRESH ('urn:tgv:sh'), 0), 0),
  aref (aref (DB.DBA.VEC_INDEX_REFRESH ('urn:tgv:sh3'), 0), 0);
ECHO BOTH $IF $EQU $LAST[1] "00000" "PASSED" "***FAILED";
ECHO BOTH ": three indexes built: " $LAST[1] " " $LAST[2] " " $LAST[3] "\n";

--  Every row of a query, its columns joined by ',' and each row ended by ';',
--  with 'urn:tgv:' taken off; 'ERR <message>' when it is refused.
create function DB.DBA.TGV_RUN (in _stmt varchar, in _as varchar := null) returns varchar
{
  declare _st, _msg varchar;
  declare _md, _rows any;
  declare _res varchar;
  declare _i, _j integer;
  _st := '00000';
  if (_as is not null)
    __set_user_id (_as);
  exec (_stmt, _st, _msg, vector (), 1000, _md, _rows);
  if (_as is not null)
    __pop_user_id ();
  if (_st <> '00000' and _st <> 0)
    return 'ERR ' || "LEFT" (coalesce (_msg, cast (_st as varchar)), 60);
  _res := '';
  if (isvector (_rows))
    for (_i := 0; _i < length (_rows); _i := _i + 1)
      {
        for (_j := 0; _j < length (_rows[_i]); _j := _j + 1)
          _res := _res || case when _j > 0 then ',' else '' end
            || replace (cast (_rows[_i][_j] as varchar), 'urn:tgv:', '');
        _res := _res || ';';
      }
  return _res;
};

-- ---------------------------------------------------------------------------
-- 1-11: the graph is a variable
-- ---------------------------------------------------------------------------

select DB.DBA.TGV_RUN ('sparql select ?g ?d where { graph ?g { ?d bif:vector_search "2" option (index <urn:tgv:idx>, limit 10) } } order by ?g ?d');
ECHO BOTH $IF $EQU $LAST[1] "g1,a;g1,b;g1,c;g2,d;g3,a;" "PASSED" "***FAILED";
ECHO BOTH ": 1. general selector, GRAPH ?g: every graph a hit is a subject in: " $LAST[1] "\n";

select DB.DBA.TGV_RUN ('sparql select ?g ?d where { graph ?g { ?d bif:vector_search "2" option (index <urn:tgv:sh>, limit 10) } } order by ?g ?d');
ECHO BOTH $IF $EQU $LAST[1] "g4,e;" "PASSED" "***FAILED";
ECHO BOTH ": 2. shorthand index, GRAPH ?g: its own graph only: " $LAST[1] "\n";

select DB.DBA.TGV_RUN ('sparql select ?g ?d where { graph ?g { ?d bif:vector_search "2" option (index (<urn:tgv:idx>, <urn:tgv:sh>), limit 10) } } order by ?g ?d');
ECHO BOTH $IF $EQU $LAST[1] "g1,a;g1,b;g1,c;g2,d;g3,a;g4,e;" "PASSED" "***FAILED";
ECHO BOTH ": 3. an index list, GRAPH ?g: " $LAST[1] "\n";

select DB.DBA.TGV_RUN ('sparql select ?g ?d ?t where { graph ?g { ?d bif:vector_search "2" option (index <urn:tgv:idx>, limit 10) . ?d <urn:tgv:name> ?t } } order by ?g ?d');
ECHO BOTH $IF $EQU $LAST[1] "g1,a,alpha 1;g1,b,beta 2;g1,c,gamma 3;g2,d,delta 4;" "PASSED" "***FAILED";
ECHO BOTH ": 4. joined with a triple in the same graph: " $LAST[1] "\n";

select DB.DBA.TGV_RUN ('sparql select distinct ?g where { graph ?g { ?d bif:vector_search "2" option (index <urn:tgv:idx>, limit 10) } } order by ?g');
ECHO BOTH $IF $EQU $LAST[1] "g1;g2;g3;" "PASSED" "***FAILED";
ECHO BOTH ": 5. DISTINCT ?g: " $LAST[1] "\n";

select DB.DBA.TGV_RUN ('sparql select ?g (count (*) as ?n) where { graph ?g { ?d bif:vector_search "2" option (index <urn:tgv:idx>, limit 10) } } group by ?g order by ?g');
ECHO BOTH $IF $EQU $LAST[1] "g1,3;g2,1;g3,1;" "PASSED" "***FAILED";
ECHO BOTH ": 6. GROUP BY ?g: " $LAST[1] "\n";

select DB.DBA.TGV_RUN ('sparql select ?g ?d from named <urn:tgv:g1> from named <urn:tgv:g2> where { graph ?g { ?d bif:vector_search "2" option (index <urn:tgv:idx>, limit 10) } } order by ?g ?d');
ECHO BOTH $IF $EQU $LAST[1] "g1,a;g1,b;g1,c;g2,d;" "PASSED" "***FAILED";
ECHO BOTH ": 7. FROM NAMED: " $LAST[1] "\n";

--  8.  A variable fixed by a filter: the plan passes the graph as the
--  required graph, which was 0 here, and reads the variable.
select DB.DBA.TGV_RUN ('sparql select ?g ?d where { graph ?g { ?d bif:vector_search "2" option (index <urn:tgv:idx>, limit 10) } filter (?g = <urn:tgv:g1>) } order by ?d');
ECHO BOTH $IF $EQU $LAST[1] "g1,a;g1,b;g1,c;" "PASSED" "***FAILED";
ECHO BOTH ": 8. GRAPH ?g fixed by FILTER: " $LAST[1] "\n";

--  9.  ... and it finds what GRAPH <g> finds, for each graph.
select case when DB.DBA.TGV_RUN ('sparql select ?d where { graph ?g { ?d bif:vector_search "2" option (index <urn:tgv:idx>, limit 10) } filter (?g = <urn:tgv:g3>) } order by ?d')
  = DB.DBA.TGV_RUN ('sparql select ?d where { graph <urn:tgv:g3> { ?d bif:vector_search "2" option (index <urn:tgv:idx>, limit 10) } } order by ?d')
  and DB.DBA.TGV_RUN ('sparql select ?d where { graph <urn:tgv:g3> { ?d bif:vector_search "2" option (index <urn:tgv:idx>, limit 10) } } order by ?d') = 'a;'
  then 1 else 0 end;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": 9. GRAPH ?g filtered to g3 = GRAPH <g3>, same=" $LAST[1] "\n";

select DB.DBA.TGV_RUN ('sparql select ?d from <urn:tgv:g1> from <urn:tgv:g2> where { ?d bif:vector_search "2" option (index <urn:tgv:idx>, limit 10) } order by ?d');
ECHO BOTH $IF $EQU $LAST[1] "a;b;c;d;" "PASSED" "***FAILED";
ECHO BOTH ": 10. a default graph of two FROM graphs: " $LAST[1] "\n";

select DB.DBA.TGV_RUN ('sparql select ?g ?d where { graph ?g { ?d bif:vector_search "2" option (index <urn:tgv:idx>, limit 10) } } order by ?g ?d', 'SPARQL');
ECHO BOTH $IF $EQU $LAST[1] "g1,a;g1,b;g1,c;g2,d;g3,a;" "PASSED" "***FAILED";
ECHO BOTH ": 11. GRAPH ?g as the anonymous account SPARQL: " $LAST[1] "\n";

-- ---------------------------------------------------------------------------
-- 12: a guard; 13: the graph's column name
-- ---------------------------------------------------------------------------

select DB.DBA.TGV_RUN ('sparql select ?d where { ?d bif:vector_search "2" option (index <urn:tgv:idx>, limit 10) } order by ?d')
  || '|' || DB.DBA.TGV_RUN ('sparql select ?d where { graph <urn:tgv:g1> { ?d bif:vector_search "2" option (index <urn:tgv:idx>, limit 10) } } order by ?d');
ECHO BOTH $IF $EQU $LAST[1] "a;b;c;d;|a;b;c;" "PASSED" "***FAILED";
ECHO BOTH ": 12. no graph, and GRAPH <g1>, as before: " $LAST[1] "\n";

--  13.  CaseMode 2: a score variable ?G meets the graph's column name.
select DB.DBA.TGV_RUN ('sparql select ?g ?d where { graph ?g { ?d bif:vector_search "2" option (index <urn:tgv:idx>, limit 10, score ?G) } filter (?G > 0) } order by ?g ?d');
ECHO BOTH $IF $EQU $LAST[1] "g1,a;g1,b;g1,c;g2,d;g3,a;" "PASSED" "***FAILED";
ECHO BOTH ": 13. score ?G beside GRAPH ?g: " $LAST[1] "\n";

-- ---------------------------------------------------------------------------
-- 14-17: the graphs are decided inside the search
-- ---------------------------------------------------------------------------

--  14.  limit counts hits in the allowed graphs: d is the only hit in g2, so
--  one hit from FROM NAMED g2 is d whatever the scores, as with GRAPH <g2>.
select DB.DBA.TGV_RUN ('sparql select ?g ?d from named <urn:tgv:g2> where { graph ?g { ?d bif:vector_search "2" option (index <urn:tgv:idx>, limit 1) } }')
  || '|' || DB.DBA.TGV_RUN ('sparql select ?d where { graph <urn:tgv:g2> { ?d bif:vector_search "2" option (index <urn:tgv:idx>, limit 1) } }');
ECHO BOTH $IF $EQU $LAST[1] "g2,d;|d;" "PASSED" "***FAILED";
ECHO BOTH ": 14. limit 1 in FROM NAMED g2 = GRAPH <g2>: " $LAST[1] "\n";

--  15.  a default graph of FROM g1 and g3 is their merge: a is in both and
--  comes once.
select DB.DBA.TGV_RUN ('sparql select ?d from <urn:tgv:g1> from <urn:tgv:g3> where { ?d bif:vector_search "2" option (index <urn:tgv:idx>, limit 10) } order by ?d');
ECHO BOTH $IF $EQU $LAST[1] "a;b;c;" "PASSED" "***FAILED";
ECHO BOTH ": 15. a subject in two FROM graphs once: " $LAST[1] "\n";

--  16.  e is a hit of sh (g4) and sh3 (g3): GRAPH ?g over both gives it in
--  both graphs, as graph <g3> and graph <g4> each find it.
select DB.DBA.TGV_RUN ('sparql select ?g ?d where { graph ?g { ?d bif:vector_search "2" option (index (<urn:tgv:sh>, <urn:tgv:sh3>), limit 10) } } order by ?g ?d')
  || '|' || DB.DBA.TGV_RUN ('sparql select ?d where { graph <urn:tgv:g3> { ?d bif:vector_search "2" option (index (<urn:tgv:sh>, <urn:tgv:sh3>), limit 10) } } order by ?d');
ECHO BOTH $IF $EQU $LAST[1] "g3,a;g3,e;g4,e;|a;e;" "PASSED" "***FAILED";
ECHO BOTH ": 16. a subject of two shorthand indexes keeps both graphs: " $LAST[1] "\n";

--  17.  with GRAPH ?g, limit counts subjects, not rows: a is in g1 and g3.
select DB.DBA.TGV_RUN ('sparql select (count (distinct ?d) as ?n) (count (*) as ?r) from named <urn:tgv:g1> from named <urn:tgv:g3> where { graph ?g { ?d bif:vector_search "2" option (index <urn:tgv:idx>, limit 3) } }');
ECHO BOTH $IF $EQU $LAST[1] "3,4;" "PASSED" "***FAILED";
ECHO BOTH ": 17. limit 3 subjects, a in two graphs: " $LAST[1] "\n";

-- ---------------------------------------------------------------------------
-- Cleanup
-- ---------------------------------------------------------------------------
sparql define input:storage "" drop silent vector index <urn:tgv:idx>;
sparql define input:storage "" drop silent vector index <urn:tgv:sh>;
sparql define input:storage "" drop silent vector index <urn:tgv:sh3>;
sparql define input:storage "" clear graph <urn:tgv:g1>;
sparql define input:storage "" clear graph <urn:tgv:g2>;
sparql define input:storage "" clear graph <urn:tgv:g3>;
sparql define input:storage "" clear graph <urn:tgv:g4>;
delete from DB.DBA.ONNX_MODELS where model_name = 'tgv-8';
drop function DB.DBA.TGV_RUN;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": cleanup STATE=" $STATE "\n";

echo BOTH "COMPLETED: bif:vector_search with a variable graph\n";
