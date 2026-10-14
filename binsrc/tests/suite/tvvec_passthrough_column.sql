--
--  tvvec_passthrough_column.sql
--
--  Regression test for the precomputed-vector ("bring your own vectors")
--  passthrough column mode: CREATE VECTOR INDEX ... WITH (source_kind = 'vector')
--  over a table column that already holds embedding vectors, with no model.
--
--  Covers (phase 1, single server lifetime):
--    * the __vvec_passthrough_column gate (VEC83 when off);
--    * SQL create over an empty table + DML triggers + hidden-table guard;
--    * INSERT / UPDATE / DELETE async upsert for both the serialized-vector and
--      the native-array column value forms;
--    * by-vector search (X_SIMILAR predicate + __VEC_INDEX_SEARCH);
--    * text-query rejection (VEC88);
--    * the VEC82 guard STILL blocking non-DBA direct hidden-table DML;
--    * non-empty backfill;
--    * bad-row policy (wrong dimension fails the CREATE; a bad DML row is
--      terminal; a NULL column value is treated as absent);
--    * the create-time column-type check (VEC87);
--    * SPARQL VEC_INDEX_SET_OPTIONS accepting + storing source_kind;
--    * a fast rebuild, then a checkpoint so tvvec_passthrough_column_reopen.sql
--      can assert durability after a clean restart.
--
--  The in-core 'test_embedding' model is used only where a model index is needed
--  as a control; the passthrough path itself needs no ONNX plugin.
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

echo BOTH "STARTED: VVEC passthrough column (source_kind='vector')\n";

DB.DBA.VEC_SQL_QUEUE_INIT ();

create function DB.DBA.PT_VEC8 (in a real) returns any
{ return vector (a, a+1, a+2, a+3, a+4, a+5, a+6, a+7); };
create function DB.DBA.PT_3D (in a real) returns any { return vector (a, a+1, a+2); };
create function DB.DBA.PT_KV (in kv any, in k varchar) returns any
{ declare i int; if (not isvector(kv)) return null;
  for (i:=0;i<length(kv);i:=i+2) if (cast(aref(kv,i) as varchar)=k) return aref(kv,i+1); return null; };
create function DB.DBA.PT_METRIC (in idx varchar, in k varchar) returns integer
{ return cast (DB.DBA.PT_KV (__VEC_INDEX_METRICS (idx), k) as integer); };
create function DB.DBA.PT_TOP (in idx varchar, in a real, in k int) returns integer
{ return cast (aref (aref (__VEC_INDEX_SEARCH (idx, DB.DBA.PT_VEC8 (a), k, 64), 0), 0) as integer); };
create function DB.DBA.PT_ERRCODE (in q varchar, in code varchar) returns integer
{ declare st, msg varchar; declare md, rs any; st:='00000'; msg:='';
  exec (q, st, msg, vector(), 10000, md, rs);
  if (msg is not null and strstr (msg, code) is not null) return 1; return 0; };
create function DB.DBA.PT_OKAY (in q varchar) returns integer
{ declare st, msg varchar; declare md, rs any; st:='00000'; msg:='';
  exec (q, st, msg, vector(), 10000, md, rs); if (st = '00000') return 1; return 0; };
create function DB.DBA.PT_WORKER_CLEAN () returns integer
{ return (select count(*) from DB.DBA.VEC_SQL_WORKER_STATE where VS_ID=1 and VS_LAST_ERROR is null); };

-- ============ 1. GATE (off by default) ============
create table DB.DBA.PT_T (id integer not null primary key, emb any);
select DB.DBA.PT_ERRCODE ('create vector index PT_IDX on DB.DBA.PT_T (emb) with (dimensions=8, distance_metric=''cosine'', hnsw_m=8, ef_construction=64, source_kind=''vector'')', 'VEC83');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": gate OFF rejects source_kind=vector (VEC83)=" $LAST[1] "\n";

registry_set ('__vvec_passthrough_column', 'on');

-- ============ 2. SQL CREATE over empty table + triggers + hidden guard ============
create vector index PT_IDX on DB.DBA.PT_T (emb)
  with (dimensions=8, distance_metric='cosine', hnsw_m=8, ef_construction=64, source_kind='vector');
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": create empty passthrough index STATE=" $STATE " MSG=" $MESSAGE "\n";
select count(*) from DB.DBA.SYS_TRIGGERS where T_TABLE='DB.DBA.PT_T' and name_part (T_NAME, 2) like 'PT_IDX_VVEC_A_';
ECHO BOTH $IF $EQU $LAST[1] 3 "PASSED" "***FAILED";
ECHO BOTH ": DML triggers created=" $LAST[1] "\n";
select count(*) from DB.DBA.SYS_TRIGGERS where upper(T_TABLE)= upper('DB.DBA.PT_IDX_vec_embeddings');
ECHO BOTH $IF $EQU $LAST[1] 3 "PASSED" "***FAILED";
ECHO BOTH ": hidden-table guard triggers present on passthrough index=" $LAST[1] "\n";

-- ============ 3. INSERT/UPDATE/DELETE upsert (serialized + native forms) ============
insert into DB.DBA.PT_T (id, emb) values (1, serialize (DB.DBA.PT_VEC8 (10)));
insert into DB.DBA.PT_T (id, emb) values (2, serialize (DB.DBA.PT_VEC8 (50)));
insert into DB.DBA.PT_T (id, emb) values (3, serialize (DB.DBA.PT_VEC8 (90)));
insert into DB.DBA.PT_T (id, emb) values (4, DB.DBA.PT_VEC8 (200));
DB.DBA.VEC_SQL_QUEUE_DRAIN (1000);
select DB.DBA.PT_WORKER_CLEAN ();
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": worker clean after inserts=" $LAST[1] "\n";
select DB.DBA.PT_METRIC ('PT_IDX', 'graph_nodes');
ECHO BOTH $IF $EQU $LAST[1] 4 "PASSED" "***FAILED";
ECHO BOTH ": graph_nodes after 4 inserts (serialized+native)=" $LAST[1] "\n";
select DB.DBA.PT_TOP ('PT_IDX', 10, 3);
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": nearest to seed10 (serialized row)=" $LAST[1] "\n";
select DB.DBA.PT_TOP ('PT_IDX', 200, 3);
ECHO BOTH $IF $EQU $LAST[1] 4 "PASSED" "***FAILED";
ECHO BOTH ": nearest to seed200 (native-array row)=" $LAST[1] "\n";
update DB.DBA.PT_T set emb = serialize (DB.DBA.PT_VEC8 (1000)) where id = 1;
DB.DBA.VEC_SQL_QUEUE_DRAIN (1000);
select DB.DBA.PT_TOP ('PT_IDX', 1000, 3);
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": UPDATE moved row1 to seed1000=" $LAST[1] "\n";
delete from DB.DBA.PT_T where id = 3;
DB.DBA.VEC_SQL_QUEUE_DRAIN (1000);
select DB.DBA.PT_METRIC ('PT_IDX', 'managed_rows');
ECHO BOTH $IF $EQU $LAST[1] 3 "PASSED" "***FAILED";
ECHO BOTH ": managed_rows after delete (1,2,4 live)=" $LAST[1] "\n";
select (select count(*) from DB.DBA.PT_IDX_vec_embeddings where VE_D_ID = 3);
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": deleted row gone from hidden table=" $LAST[1] "\n";

-- ============ 4. BY-VECTOR QUERY (X_SIMILAR predicate) ============
select count(*) from (select id from DB.DBA.PT_T where X_SIMILAR (emb, DB.DBA.PT_VEC8 (10), 3) > 0.0) sub;
ECHO BOTH $IF $GTE $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": X_SIMILAR(col,<vector>,k) predicate returns rows=" $LAST[1] "\n";

-- ============ 5. TEXT-QUERY REJECTION (VEC88) ============
select DB.DBA.PT_ERRCODE ('select __VEC_INDEX_QUERY_TEXT_VECTOR (''PT_IDX'', ''hello world'')', 'VEC88');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": text query on passthrough raises VEC88=" $LAST[1] "\n";

-- ============ 6. VEC82 GUARD still blocks non-DBA hidden-table DML ============
insert into DB.DBA.PT_IDX_vec_embeddings (VE_D_ID, VE_EMBEDDING, EMBED_STATUS, MODEL_ID, UPDATED_AT)
  values (999, 'x', 'ready', 0, now ());
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": DBA direct hidden insert allowed STATE=" $STATE "\n";
delete from DB.DBA.PT_IDX_vec_embeddings where VE_D_ID = 999;
DB.DBA.USER_CREATE ('ptu', 'ptupass');
grant select, insert, update, delete on DB.DBA.PT_IDX_vec_embeddings to "ptu";
create procedure DB.DBA.PT_TRY (in op varchar) returns integer
{
  declare exit handler for sqlstate '*'
    { __pop_user_id (); if (__SQL_MESSAGE like '%VEC82%') return 1; return -1; };
  __set_user_id ('ptu');
  if (op = 'insert')
    insert into DB.DBA.PT_IDX_vec_embeddings (VE_D_ID, VE_EMBEDDING, EMBED_STATUS, MODEL_ID, UPDATED_AT)
      values (777, 'y', 'ready', 0, now ());
  else if (op = 'update')
    update DB.DBA.PT_IDX_vec_embeddings set EMBED_STATUS = 'hacked' where VE_D_ID = 1;
  else
    delete from DB.DBA.PT_IDX_vec_embeddings where VE_D_ID = 1;
  __pop_user_id ();
  return 0;
};
select DB.DBA.PT_TRY ('insert');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": non-dba INSERT into passthrough hidden table rejected (VEC82)=" $LAST[1] "\n";
select DB.DBA.PT_TRY ('update');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": non-dba UPDATE rejected (VEC82)=" $LAST[1] "\n";
select DB.DBA.PT_TRY ('delete');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": non-dba DELETE rejected (VEC82)=" $LAST[1] "\n";

-- ============ 7. NON-EMPTY BACKFILL ============
create table DB.DBA.PT_B (id integer not null primary key, emb any);
insert into DB.DBA.PT_B (id, emb) values (1, serialize (DB.DBA.PT_VEC8 (10)));
insert into DB.DBA.PT_B (id, emb) values (2, serialize (DB.DBA.PT_VEC8 (50)));
insert into DB.DBA.PT_B (id, emb) values (3, serialize (DB.DBA.PT_VEC8 (90)));
create vector index PT_BIDX on DB.DBA.PT_B (emb)
  with (dimensions=8, distance_metric='cosine', hnsw_m=8, ef_construction=64, source_kind='vector');
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": create passthrough over NON-EMPTY table (backfill) STATE=" $STATE "\n";
select DB.DBA.PT_METRIC ('PT_BIDX', 'graph_nodes');
ECHO BOTH $IF $EQU $LAST[1] 3 "PASSED" "***FAILED";
ECHO BOTH ": backfill built graph_nodes=" $LAST[1] "\n";
select DB.DBA.PT_TOP ('PT_BIDX', 10, 3);
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": backfilled index searchable=" $LAST[1] "\n";

-- ============ 8. BAD-ROW POLICY ============
create table DB.DBA.PT_BADB (id integer not null primary key, emb any);
insert into DB.DBA.PT_BADB (id, emb) values (1, serialize (DB.DBA.PT_VEC8 (10)));
insert into DB.DBA.PT_BADB (id, emb) values (2, serialize (DB.DBA.PT_3D (1)));
select DB.DBA.PT_ERRCODE ('create vector index PT_BADBIDX on DB.DBA.PT_BADB (emb) with (dimensions=8, distance_metric=''cosine'', hnsw_m=8, ef_construction=64, source_kind=''vector'')', 'VEC31');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": wrong-dimension row FAILS create (VEC31)=" $LAST[1] "\n";
select (select count(*) from DB.DBA.SYS_KEYS where KEY_NAME = 'PT_BADBIDX');
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": failed create left no index=" $LAST[1] "\n";
insert into DB.DBA.PT_B (id, emb) values (99, serialize (DB.DBA.PT_3D (1)));
DB.DBA.VEC_SQL_QUEUE_DRAIN (1000);
select cast ((select VQ_STATE from DB.DBA.VEC_SQL_QUEUE where VQ_INDEX='PT_BIDX' and cast(VQ_PK as integer)=99) as varchar);
ECHO BOTH $IF $EQU $LAST[1] error "PASSED" "***FAILED";
ECHO BOTH ": bad DML row terminal state=" $LAST[1] "\n";
select (select VQ_TRIES from DB.DBA.VEC_SQL_QUEUE where VQ_INDEX='PT_BIDX' and cast(VQ_PK as integer)=99);
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": terminal without 5x retry, tries=" $LAST[1] "\n";
insert into DB.DBA.PT_B (id, emb) values (77, null);
DB.DBA.VEC_SQL_QUEUE_DRAIN (1000);
select (select count(*) from DB.DBA.VEC_SQL_QUEUE where VQ_INDEX='PT_BIDX' and cast(VQ_PK as integer)=77);
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": NULL-vector row drained as absent=" $LAST[1] "\n";

-- ============ 9. CREATE-TIME COLUMN-TYPE CHECK ============
create table DB.DBA.PT_TXT (id integer not null primary key, emb varchar);
select DB.DBA.PT_ERRCODE ('create vector index PT_TXTIDX on DB.DBA.PT_TXT (emb) with (dimensions=8, source_kind=''vector'')', 'VEC87');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": VARCHAR source rejected (VEC87)=" $LAST[1] "\n";
create table DB.DBA.PT_VB (id integer not null primary key, emb varbinary);
select DB.DBA.PT_OKAY ('create vector index PT_VBIDX on DB.DBA.PT_VB (emb) with (dimensions=8, distance_metric=''cosine'', hnsw_m=8, ef_construction=64, source_kind=''vector'')');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": VARBINARY source accepted=" $LAST[1] "\n";

-- ============ 10. SPARQL VEC_INDEX_SET_OPTIONS accept + store source_kind ============
DB.DBA.VEC_INDEX_BEGIN_CREATE ('urn:pt:sparql');
DB.DBA.VEC_INDEX_SET_OPTIONS ('urn:pt:sparql', vector ('dimensions', 8, 'distance', 'cosine', 'source_kind', 'vector'));
select cast ((select SVI_SOURCE_KIND from DB.DBA.SPARQL_VEC_INDEX where SVI_IRI='urn:pt:sparql') as varchar);
ECHO BOTH $IF $EQU $LAST[1] vector "PASSED" "***FAILED";
ECHO BOTH ": SPARQL SET_OPTIONS stored source_kind=" $LAST[1] "\n";
create procedure DB.DBA.PT_SPARQL_BAD () returns integer
{ declare exit handler for sqlstate '*' { if (__SQL_STATE='VEC85' or strstr(__SQL_MESSAGE,'VEC85') is not null) return 1; return 0; };
  DB.DBA.VEC_INDEX_SET_OPTIONS ('urn:pt:sparql', vector ('dimensions', 8, 'source_kind', 'bogus')); return 0; };
select DB.DBA.PT_SPARQL_BAD ();
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": SPARQL SET_OPTIONS rejects bad source_kind (VEC85)=" $LAST[1] "\n";

-- ============ 11. FAST REBUILD + checkpoint for the reopen durability phase ============
select DB.DBA.PT_ERRCODE ('select __VEC_INDEX_REBUILD (''PT_IDX'', ''fast'')', 'VEC');
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": fast rebuild on passthrough returned no error=" $LAST[1] "\n";
select DB.DBA.PT_METRIC ('PT_IDX', 'graph_nodes');
ECHO BOTH $IF $EQU $LAST[1] 3 "PASSED" "***FAILED";
ECHO BOTH ": graph_nodes after fast rebuild (rows 1,2,4)=" $LAST[1] "\n";

checkpoint;

echo BOTH "COMPLETED: VVEC passthrough column phase 1\n";
