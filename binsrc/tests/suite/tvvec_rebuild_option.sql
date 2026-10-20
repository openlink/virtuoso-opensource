--
--  tvvec_rebuild_option.sql
--
--  Regression test for the per-index rebuild-method option and the
--  __VEC_INDEX_REBUILD per-call override.
--
--  __VEC_INDEX_REBUILD chooses between two implementations -- the fast in-memory
--  bulk build and the one-insert-at-a-time replay (both durability-equivalent,
--  see tvvec_rebuild_durable).  The method is selected, highest precedence first,
--  by: an explicit __VEC_INDEX_REBUILD(idx, method) argument; the index's stored
--  default WITH (rebuild = 'fast'|'replay'|'auto'); the VVEC_FAST_REBUILD env
--  fallback; else replay.  'auto' picks fast past an embedding-count threshold.
--
--  This phase covers what is observable inside SQL: that each option value is
--  accepted at CREATE (native SQL and SPARQL surfaces) and stored, that invalid
--  values are rejected with VEC81, that a plain rebuild honors the stored default
--  and a per-call argument overrides it, and that every rebuilt index still
--  answers.  The companion .sh additionally asserts which implementation ran by
--  reading the server log.
--
--  Self-contained: uses the 'test_embedding' model type, so it runs without the
--  ONNX plugin.
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

echo BOTH "STARTED: VVEC rebuild-method option\n";

select DB.DBA.ONNX_REGISTRY_INIT ();
delete from DB.DBA.ONNX_MODELS where model_name = 'vro-8';
insert into DB.DBA.ONNX_MODELS
  (model_name, description, model_path, model_type, output_name, output_shape, created_at, updated_at)
  values ('vro-8', 'rebuild-option test model', 'internal:vro-8',
          'test_embedding', 'embedding', '1,8', now (), now ());
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": register vro-8 STATE=" $STATE "\n";

create function DB.DBA.VRO_HITS (in index_name varchar, in txt varchar) returns integer
{
  return length (__VEC_INDEX_SEARCH (index_name, __VEC_INDEX_QUERY_TEXT_VECTOR (index_name, txt), 10, 20));
};

-- Reports whether an operation raised VEC81, so it can be asserted rather than
-- aborting the script.
create function DB.DBA.VRO_VEC81 (in stmt varchar) returns integer
{
  declare st, msg varchar;
  declare md, rs any;
  st := '00000';
  exec (stmt, st, msg, vector (), 10000, md, rs);
  if (st = '00000' or st = 0) return 0;
  if (msg like '%VEC81%') return 1;
  return -1;
};
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": create helpers STATE=" $STATE "\n";

--
--  1. Native SQL DDL: each rebuild value is accepted; a bad value is VEC81.
--

create table DB.DBA.VRO_FASTT (id integer not null primary key, content varchar);
create table DB.DBA.VRO_REPT  (id integer not null primary key, content varchar);
create table DB.DBA.VRO_DEFT  (id integer not null primary key, content varchar);
create table DB.DBA.VRO_AUTOT (id integer not null primary key, content varchar);
CREATE VECTOR INDEX VRO_FASTX ON DB.DBA.VRO_FASTT (content) USING 'vro-8'
  WITH (dimensions=8, distance_metric='cosine', hnsw_m=8, ef_construction=24, rebuild='fast');
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": create rebuild=fast STATE=" $STATE " MSG=" $MESSAGE "\n";
CREATE VECTOR INDEX VRO_REPX ON DB.DBA.VRO_REPT (content) USING 'vro-8'
  WITH (dimensions=8, distance_metric='cosine', hnsw_m=8, ef_construction=24, rebuild='replay');
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": create rebuild=replay STATE=" $STATE "\n";
CREATE VECTOR INDEX VRO_DEFX ON DB.DBA.VRO_DEFT (content) USING 'vro-8'
  WITH (dimensions=8, distance_metric='cosine', hnsw_m=8, ef_construction=24);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": create default STATE=" $STATE "\n";
CREATE VECTOR INDEX VRO_AUTOX ON DB.DBA.VRO_AUTOT (content) USING 'vro-8'
  WITH (dimensions=8, distance_metric='cosine', hnsw_m=8, ef_construction=24, rebuild='auto');
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": create rebuild=auto STATE=" $STATE "\n";

select DB.DBA.VRO_VEC81 ('CREATE VECTOR INDEX VRO_BADX ON DB.DBA.VRO_AUTOT (content) USING ''vro-8'' WITH (dimensions=8, distance_metric=''cosine'', hnsw_m=8, ef_construction=24, rebuild=''nope'')');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": native create rebuild=nope rejected VEC81=" $LAST[1] "\n";

--
--  2. Populate and rebuild each; the plain rebuild honors the stored default and
--     the rebuilt index answers.
--

select __VEC_INDEX_INSERT_TEST_EMBEDDING ('VRO_FASTX', 1, 0, 1);
select __VEC_INDEX_INSERT_TEST_EMBEDDING ('VRO_FASTX', 2, 1, 2);
select __VEC_INDEX_INSERT_TEST_EMBEDDING ('VRO_FASTX', 3, 2, 3);
select __VEC_INDEX_INSERT_TEST_EMBEDDING ('VRO_REPX', 1, 0, 1);
select __VEC_INDEX_INSERT_TEST_EMBEDDING ('VRO_REPX', 2, 1, 2);
select __VEC_INDEX_INSERT_TEST_EMBEDDING ('VRO_REPX', 3, 2, 3);
select __VEC_INDEX_INSERT_TEST_EMBEDDING ('VRO_DEFX', 1, 0, 1);
select __VEC_INDEX_INSERT_TEST_EMBEDDING ('VRO_DEFX', 2, 1, 2);
select __VEC_INDEX_INSERT_TEST_EMBEDDING ('VRO_DEFX', 3, 2, 3);
select __VEC_INDEX_INSERT_TEST_EMBEDDING ('VRO_AUTOX', 1, 0, 1);
select __VEC_INDEX_INSERT_TEST_EMBEDDING ('VRO_AUTOX', 2, 1, 2);
select __VEC_INDEX_INSERT_TEST_EMBEDDING ('VRO_AUTOX', 3, 2, 3);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": populate STATE=" $STATE "\n";

select __VEC_INDEX_REBUILD ('VRO_FASTX');
ECHO BOTH $IF $EQU $LAST[1] 3 "PASSED" "***FAILED";
ECHO BOTH ": rebuild VRO_FASTX rows=" $LAST[1] "\n";
select __VEC_INDEX_REBUILD ('VRO_REPX');
ECHO BOTH $IF $EQU $LAST[1] 3 "PASSED" "***FAILED";
ECHO BOTH ": rebuild VRO_REPX rows=" $LAST[1] "\n";
select __VEC_INDEX_REBUILD ('VRO_DEFX');
ECHO BOTH $IF $EQU $LAST[1] 3 "PASSED" "***FAILED";
ECHO BOTH ": rebuild VRO_DEFX rows=" $LAST[1] "\n";
select __VEC_INDEX_REBUILD ('VRO_AUTOX');
ECHO BOTH $IF $EQU $LAST[1] 3 "PASSED" "***FAILED";
ECHO BOTH ": rebuild VRO_AUTOX rows=" $LAST[1] "\n";

select DB.DBA.VRO_HITS ('VRO_FASTX', 'alpha 10 11');
ECHO BOTH $IF $EQU $LAST[1] 3 "PASSED" "***FAILED";
ECHO BOTH ": fast-default index searchable hits=" $LAST[1] "\n";

--
--  3. Per-call override wins over the stored default; a bad method is VEC81.
--

select __VEC_INDEX_REBUILD ('VRO_REPX', 'fast');
ECHO BOTH $IF $EQU $LAST[1] 3 "PASSED" "***FAILED";
ECHO BOTH ": override replay-index with fast rows=" $LAST[1] "\n";
select __VEC_INDEX_REBUILD ('VRO_FASTX', 'replay');
ECHO BOTH $IF $EQU $LAST[1] 3 "PASSED" "***FAILED";
ECHO BOTH ": override fast-index with replay rows=" $LAST[1] "\n";
select DB.DBA.VRO_VEC81 ('select __VEC_INDEX_REBUILD (''VRO_DEFX'', ''nope'')');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": override method=nope rejected VEC81=" $LAST[1] "\n";

--
--  4. SPARQL DDL surface: the option is stored in SVI_REBUILD; a bad value is
--     rejected and leaves no catalogue row behind (VEC_INDEX_ABORT_CREATE runs
--     from an exit handler between BEGIN_CREATE and END_CREATE).
--

sparql define input:storage ""
create vector index <urn:vro:fast-idx>
  on graph <urn:vro:graph> for predicate <urn:vro:content>
  using model 'vro-8'
  with (dimensions = 8, distance = 'cosine', hnsw_m = 8, ef_construction = 16, rebuild = 'fast')
;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": SPARQL create rebuild=fast STATE=" $STATE " MSG=" $MESSAGE "\n";
select SVI_REBUILD from DB.DBA.SPARQL_VEC_INDEX where SVI_IRI = 'urn:vro:fast-idx';
ECHO BOTH $IF $EQU $LAST[1] fast "PASSED" "***FAILED";
ECHO BOTH ": SPARQL SVI_REBUILD stored=" $LAST[1] "\n";

sparql define input:storage ""
create vector index <urn:vro:bogus-idx>
  on graph <urn:vro:graph> for predicate <urn:vro:content>
  using model 'vro-8'
  with (dimensions = 8, distance = 'cosine', hnsw_m = 8, ef_construction = 16, rebuild = 'bogus')
;
-- count(*) rather than SVI_STATE: it always returns exactly one row, so an
-- empty result cannot be misread as a value $LAST[1] still holds from the
-- preceding statement.
select count(*) from DB.DBA.SPARQL_VEC_INDEX where SVI_IRI = 'urn:vro:bogus-idx';
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": SPARQL rebuild=bogus rejected, no catalogue residue, rows=" $LAST[1] "\n";

--
--  Cleanup.
--

drop index VRO_FASTX;
drop index VRO_REPX;
drop index VRO_DEFX;
drop index VRO_AUTOX;
sparql define input:storage "" drop silent vector index <urn:vro:fast-idx>;
sparql define input:storage "" drop silent vector index <urn:vro:bogus-idx>;
drop table DB.DBA.VRO_FASTT;
drop table DB.DBA.VRO_REPT;
drop table DB.DBA.VRO_DEFT;
drop table DB.DBA.VRO_AUTOT;
drop function DB.DBA.VRO_HITS;
drop function DB.DBA.VRO_VEC81;
delete from DB.DBA.ONNX_MODELS where model_name = 'vro-8';
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": cleanup STATE=" $STATE " MSG=" $MESSAGE "\n";

echo BOTH "COMPLETED: VVEC rebuild-method option\n";
