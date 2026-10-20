--
--  tvvec_general_from.sql
--
--  FROM / FROM NAMED on a general (KEY/EMBEDDING/WHERE) vector index selector.
--
--  The point of the clause is not only enumeration: a triple that is not inside
--  an explicit GRAPH used to make the selector non-async-scopable, and a FROM
--  now supplies the graph it is read from, so async maintenance becomes
--  available for patterns that previously could not have it.
--
--  Builds its own graph and uses a test_embedding model, so it needs no ONNX.
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

delete from DB.DBA.ONNX_MODELS where model_name = 'vvec-from-8';
insert into DB.DBA.ONNX_MODELS
  (model_name, description, model_path, model_type, output_name, output_shape, created_at, updated_at)
values
  ('vvec-from-8', 'FROM selector test model', 'internal:vvec-test-8', 'test_embedding', 'embedding', '1,8', now (), now ());
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": register vvec-from-8 STATE=" $STATE "\n";

--  The integers matter: a test_embedding model derives its vector from the
--  first integer in the text, so these make each row individually retrievable.
DB.DBA.TTLP ('<urn:vf:a> <http://example.org/name> "alpha 1" . <urn:vf:b> <http://example.org/name> "beta 2" . <urn:vf:c> <http://example.org/name> "gamma 3" .', '', 'urn:vf:g1');
DB.DBA.TTLP ('<urn:vf:d> <http://example.org/name> "delta 4" .', '', 'urn:vf:g2');
commit work;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": load fixture graphs STATE=" $STATE "\n";

--  A pattern with no GRAPH, scoped by FROM.  Before FROM was accepted this
--  could not be created with maintenance = 'async' at all.
sparql prefix ex: <http://example.org/>
create vector index <urn:vf:idx1>
  key ?d embedding ?t
  from <urn:vf:g1>
  where { ?d ex:name ?t }
  using model 'vvec-from-8'
  with (dimensions = 8, maintenance = 'async');
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": create FROM-scoped selector with async STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select cast (SVI_DATASET_TEXT as varchar) from DB.DBA.SPARQL_VEC_INDEX where SVI_IRI = 'urn:vf:idx1';
ECHO BOTH $IF $EQU $LAST[1] "FROM <urn:vf:g1> " "PASSED" "***FAILED";
ECHO BOTH ": dataset clause stored = [" $LAST[1] "]\n";

--  The FROM graph must reach the trigger table, which is what makes async work.
select count (*) from DB.DBA.SPARQL_VEC_INDEX_TRIGGER
 where SVT_INDEX_IRI = 'urn:vf:idx1' and SVT_GRAPH_IRI = 'urn:vf:g1'
   and SVT_PRED_IRI = 'http://example.org/name';
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": trigger pair derived from FROM = " $LAST[1] " expected 1\n";

--  Enumeration: the dataset clause has to be spliced into the refresh query in
--  a form the SPARQL-inside-SQL parser accepts -- that embedding is where a
--  malformed clause actually bites, and where an over-allocated buffer once
--  put padding inside the generated SPARQL.  Checked directly first, then
--  through a real refresh below.
select count (*) from (sparql define input:storage ""
  select ?d (MIN (str (?t))) as ?t FROM <urn:vf:g1> where { ?d <http://example.org/name> ?t } group by ?d) as sub;
ECHO BOTH $IF $EQU $LAST[1] 3 "PASSED" "***FAILED";
ECHO BOTH ": FROM enumerates inside a derived table, rows = " $LAST[1] " expected 3\n";

select count (*) from (sparql define input:storage ""
  select ?d (MIN (str (?t))) as ?t FROM <urn:vf:g1> FROM <urn:vf:g2> where { ?d <http://example.org/name> ?t } group by ?d) as sub;
ECHO BOTH $IF $EQU $LAST[1] 4 "PASSED" "***FAILED";
ECHO BOTH ": two FROM graphs merge, rows = " $LAST[1] " expected 4\n";

--  End to end: a real refresh through the FROM clause.  This also covers
--  DB.DBA.VEC_INDEX_EMBED_TEXTS accepting a test_embedding model -- it used to
--  raise VEC33 for one, so an index VEC_INDEX_REFRESH's own guard admitted
--  could not actually be refreshed.
sparql define input:storage "" refresh vector index <urn:vf:idx1>;
select count (*) from DB.DBA.SPARQL_VEC_INDEX where SVI_IRI = 'urn:vf:idx1' and SVI_STATE = 'active';
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": refresh through FROM with a test_embedding model leaves the index active\n";

--  The test model puts a 1 at the integer it finds in the text, so a query for
--  that integer must retrieve that row.  If the PL embedding path had produced
--  vectors differing from the ones the C insert/search path makes, this is
--  where it would show.
sparql define input:storage "" select ?d where { ?d bif:vector_search "2" option (index <urn:vf:idx1>, score ?s, limit 1) } order by desc(?s);
ECHO BOTH $IF $EQU $LAST[1] "urn:vf:b" "PASSED" "***FAILED";
ECHO BOTH ": search finds the row whose text carries that integer = " $LAST[1] "\n";

--  Two FROM graphs: a change in either can alter what the selector enumerates,
--  so both have to be watched.
sparql prefix ex: <http://example.org/>
create vector index <urn:vf:idx2>
  key ?d embedding ?t
  from <urn:vf:g1> from <urn:vf:g2>
  where { ?d ex:name ?t }
  using model 'vvec-from-8'
  with (dimensions = 8, maintenance = 'async');
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": create with two FROM graphs STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select count (*) from DB.DBA.SPARQL_VEC_INDEX_TRIGGER where SVT_INDEX_IRI = 'urn:vf:idx2';
ECHO BOTH $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";
ECHO BOTH ": one trigger pair per FROM graph = " $LAST[1] " expected 2\n";

--  Regression: without FROM and without GRAPH the pattern is still not
--  scopable, so async must still be refused.
sparql prefix ex: <http://example.org/>
create vector index <urn:vf:idx3>
  key ?d embedding ?t
  where { ?d ex:name ?t }
  using model 'vvec-from-8'
  with (dimensions = 8, maintenance = 'async');
--  SPARQL DDL reports its status as a result ROW, not as a SQL error, so
--  $STATE stays OK on a refusal.  Assert on the catalogue instead.
select count (*) from DB.DBA.SPARQL_VEC_INDEX where SVI_IRI = 'urn:vf:idx3' and SVI_STATE = 'active';
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": async refused with neither FROM nor GRAPH, active rows = " $LAST[1] " expected 0\n";

--  Regression: an explicit GRAPH still scopes on its own, with no FROM.
sparql prefix ex: <http://example.org/>
create vector index <urn:vf:idx4>
  key ?d embedding ?t
  where { graph <urn:vf:g1> { ?d ex:name ?t } }
  using model 'vvec-from-8'
  with (dimensions = 8, maintenance = 'async');
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": explicit GRAPH still scopes without FROM STATE=" $STATE "\n";

select coalesce (cast (SVI_DATASET_TEXT as varchar), '<none>') from DB.DBA.SPARQL_VEC_INDEX where SVI_IRI = 'urn:vf:idx4';
ECHO BOTH $IF $EQU $LAST[1] "<none>" "PASSED" "***FAILED";
ECHO BOTH ": a selector written without FROM stores no dataset clause = " $LAST[1] "\n";

DB.DBA.VEC_INDEX_DROP ('urn:vf:idx1', 1);
DB.DBA.VEC_INDEX_DROP ('urn:vf:idx3', 1);
delete from DB.DBA.SPARQL_VEC_INDEX where SVI_IRI = 'urn:vf:idx3';
DB.DBA.VEC_INDEX_DROP ('urn:vf:idx2', 1);
DB.DBA.VEC_INDEX_DROP ('urn:vf:idx4', 1);
sparql clear graph <urn:vf:g1>;
sparql clear graph <urn:vf:g2>;
delete from DB.DBA.ONNX_MODELS where model_name = 'vvec-from-8';
commit work;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": cleanup STATE=" $STATE "\n";
