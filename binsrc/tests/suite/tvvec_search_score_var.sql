--
--  tvvec_search_score_var.sql
--
--  bif:vector_search's score and distance variables may have any name,
--  ?s and ?S included.
--
--  The generated SQL named the search's subject column "S" and its score
--  and distance columns after their variables.  With CaseMode 2 -- the stock
--  virtuoso.ini -- column names compare without case, so `score ?s` and
--  `distance ?s` read the subject, and under any case mode `score ?S` was a
--  second column "S" and failed to compile (SQ149).  ?s is the commonest
--  variable name a SPARQL query has.
--
--  Run by tvvec_rdf_quad.sh, which sets CaseMode 2.  Each query is compared
--  with the same query written with another variable name.
--
--  1-4 are tests of the change (each fails before it); 5-7 are guards and
--  hold on both sides:
--    1. score ?s is the score.
--    2. distance ?s is the distance.
--    3. score ?S compiles and is the score.
--    4. score ?s over an index list is the score.
--    5. The scores compared are three numbers, from 0.5 to 1.
--    6. The subject joins a triple pattern.
--    7. ... with a score beside it.
--
--  Self-contained: its own graph, model and SPARQL vector index, removed at
--  the end.  The in-core test embedding scores the three documents 1, 0.75
--  and 0.5 for the query.
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

echo BOTH "STARTED: bif:vector_search score and distance variables of any name\n";

-- ---------------------------------------------------------------------------
-- Fixtures
-- ---------------------------------------------------------------------------

delete from DB.DBA.ONNX_MODELS where model_name = 'tsv-8';
insert into DB.DBA.ONNX_MODELS
  (model_name, description, model_path, model_type, output_name, output_shape, created_at, updated_at)
values
  ('tsv-8', 'score variable test model', 'internal:tsv-8', 'test_embedding', 'embedding', '1,8', now (), now ());
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": register tsv-8 STATE=" $STATE "\n";

sparql define input:storage "" drop silent vector index <urn:tsv:a>;
sparql define input:storage "" drop silent vector index <urn:tsv:b>;
sparql define input:storage "" clear graph <urn:tsv:ga>;
sparql define input:storage "" clear graph <urn:tsv:gb>;
sparql define input:storage ""
insert data {
  graph <urn:tsv:ga> {
    <urn:tsv:a1> <urn:tsv:txt> "doc 1 2" .
    <urn:tsv:a2> <urn:tsv:txt> "doc 1 3" .
    <urn:tsv:a3> <urn:tsv:txt> "doc 4 5" .
  }
  graph <urn:tsv:gb> {
    <urn:tsv:b1> <urn:tsv:txt> "doc 2 6" .
    <urn:tsv:b2> <urn:tsv:txt> "doc 6 7" .
  }
};
sparql define input:storage ""
create vector index <urn:tsv:a> on graph <urn:tsv:ga> for predicate <urn:tsv:txt>
  using model 'tsv-8' with (dimensions = 8, hnsw_m = 8, ef_construction = 16);
sparql define input:storage ""
create vector index <urn:tsv:b> on graph <urn:tsv:gb> for predicate <urn:tsv:txt>
  using model 'tsv-8' with (dimensions = 8, hnsw_m = 8, ef_construction = 16);
select aref (aref (DB.DBA.VEC_INDEX_REFRESH ('urn:tsv:a'), 0), 0), aref (aref (DB.DBA.VEC_INDEX_REFRESH ('urn:tsv:b'), 0), 0);
ECHO BOTH $IF $EQU $LAST[1] "00000" "PASSED" "***FAILED";
ECHO BOTH ": two indexes built: " $LAST[1] " " $LAST[2] "\n";

--  The first column of every row, space joined; 'ERR <state>' when refused.
create function DB.DBA.TSV_RUN (in _stmt varchar) returns varchar
{
  declare _st, _msg varchar;
  declare _md, _rows any;
  declare _out varchar;
  declare i integer;
  _st := '00000';
  exec (_stmt, _st, _msg, vector (), 1000, _md, _rows);
  if (_st <> '00000' and _st <> 0)
    return 'ERR ' || cast (_st as varchar);
  _out := '';
  if (isvector (_rows))
    for (i := 0; i < length (_rows); i := i + 1)
      _out := _out || case when _out = '' then '' else ' ' end || cast (_rows[i][0] as varchar);
  return case when _out = '' then '(none)' else _out end;
};

-- ---------------------------------------------------------------------------
-- 1-4. Variables named like the subject column
-- ---------------------------------------------------------------------------

select DB.DBA.TSV_RUN ('sparql define input:storage "" select ?s where { ?d bif:vector_search "doc 1 2" option (index <urn:tsv:a>, score ?s, limit 3) } order by desc (?s)'),
       DB.DBA.TSV_RUN ('sparql define input:storage "" select ?sc where { ?d bif:vector_search "doc 1 2" option (index <urn:tsv:a>, score ?sc, limit 3) } order by desc (?sc)');
ECHO BOTH $IF $EQU $LAST[1] $LAST[2] "PASSED" "***FAILED";
ECHO BOTH ": score ?s is the score: " $LAST[1] " = " $LAST[2] "\n";

select DB.DBA.TSV_RUN ('sparql define input:storage "" select ?s where { ?d bif:vector_search "doc 1 2" option (index <urn:tsv:a>, distance ?s, limit 3) } order by asc (?s)'),
       DB.DBA.TSV_RUN ('sparql define input:storage "" select ?dist where { ?d bif:vector_search "doc 1 2" option (index <urn:tsv:a>, distance ?dist, limit 3) } order by asc (?dist)');
ECHO BOTH $IF $EQU $LAST[1] $LAST[2] "PASSED" "***FAILED";
ECHO BOTH ": distance ?s is the distance: " $LAST[1] " = " $LAST[2] "\n";

select DB.DBA.TSV_RUN ('sparql define input:storage "" select ?S where { ?d bif:vector_search "doc 1 2" option (index <urn:tsv:a>, score ?S, limit 3) } order by desc (?S)'),
       DB.DBA.TSV_RUN ('sparql define input:storage "" select ?sc where { ?d bif:vector_search "doc 1 2" option (index <urn:tsv:a>, score ?sc, limit 3) } order by desc (?sc)');
ECHO BOTH $IF $EQU $LAST[1] $LAST[2] "PASSED" "***FAILED";
ECHO BOTH ": score ?S compiles and is the score: " $LAST[1] " = " $LAST[2] "\n";

select DB.DBA.TSV_RUN ('sparql define input:storage "" select ?s where { ?d bif:vector_search "doc 1 2" option (index (<urn:tsv:a>, <urn:tsv:b>), score ?s, limit 5) } order by desc (?s)'),
       DB.DBA.TSV_RUN ('sparql define input:storage "" select ?sc where { ?d bif:vector_search "doc 1 2" option (index (<urn:tsv:a>, <urn:tsv:b>), score ?sc, limit 5) } order by desc (?sc)');
ECHO BOTH $IF $EQU $LAST[1] $LAST[2] "PASSED" "***FAILED";
ECHO BOTH ": score ?s over an index list is the score: " $LAST[1] " = " $LAST[2] "\n";

-- ---------------------------------------------------------------------------
-- 5-7. Guards
-- ---------------------------------------------------------------------------

select DB.DBA.TSV_RUN ('sparql define input:storage "" select (count (*) as ?c) where { ?d bif:vector_search "doc 1 2" option (index <urn:tsv:a>, score ?sc, limit 3) . filter (?sc >= 0.5 && ?sc <= 1.0001) }');
ECHO BOTH $IF $EQU $LAST[1] "3" "PASSED" "***FAILED";
ECHO BOTH ": three scores from 0.5 to 1=" $LAST[1] "\n";

select DB.DBA.TSV_RUN ('sparql define input:storage "" select ?t where { ?d bif:vector_search "doc 1 2" option (index <urn:tsv:a>, limit 1) . ?d <urn:tsv:txt> ?t }');
ECHO BOTH $IF $EQU $LAST[1] "doc 1 2" "PASSED" "***FAILED";
ECHO BOTH ": the subject joins a triple pattern=" $LAST[1] "\n";

select DB.DBA.TSV_RUN ('sparql define input:storage "" select ?t where { ?d bif:vector_search "doc 1 2" option (index <urn:tsv:a>, score ?sc, limit 1) . ?d <urn:tsv:txt> ?t }');
ECHO BOTH $IF $EQU $LAST[1] "doc 1 2" "PASSED" "***FAILED";
ECHO BOTH ": ... with a score beside it=" $LAST[1] "\n";

-- ---------------------------------------------------------------------------
-- Cleanup
-- ---------------------------------------------------------------------------

sparql define input:storage "" drop silent vector index <urn:tsv:a>;
sparql define input:storage "" drop silent vector index <urn:tsv:b>;
sparql define input:storage "" clear graph <urn:tsv:ga>;
sparql define input:storage "" clear graph <urn:tsv:gb>;
delete from DB.DBA.ONNX_MODELS where model_name = 'tsv-8';
drop function DB.DBA.TSV_RUN;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": cleanup STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

echo BOTH "COMPLETED: bif:vector_search score and distance variables of any name\n";
