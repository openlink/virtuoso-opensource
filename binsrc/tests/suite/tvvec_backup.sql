--
--  tvvec_backup.sql
--
--  Fixture and pre-backup assertions for the vector-index backup test.
--
--  Both backup surfaces -- the online "backup '<prefix>'" statement and
--  "virtuoso-t +backup-dump" -- go through walk_db (), which walked every
--  index tree registered in dbs_trees.  A native vector index is not a
--  B-tree: its root is a DPF_VEC page with no content map, so itc_reset ()
--  reached it_new_root_image () and dereferenced NULL.  The server died with
--  SIGSEGV, taking the backup with it, for any database that had ever had a
--  vector index created in it.
--
--  This script builds such a database, proves the index answers, then takes
--  both kinds of backup: the logical one that had the crash, and the
--  page-image backup_online () that did not.  tvvec_backup.sh drives the rest:
--  +backup-dump and the two restores.  tvvec_backup_pages.sql and
--  tvvec_backup_verify.sql re-check the restored copies.
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

echo BOTH "STARTED: VVEC backup fixture\n";

select DB.DBA.ONNX_REGISTRY_INIT ();
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": registry init STATE=" $STATE "\n";

delete from DB.DBA.ONNX_MODELS where model_name = 'bk-32';
insert into DB.DBA.ONNX_MODELS
  (model_name, description, model_path, model_type, output_name, output_shape, created_at, updated_at)
  values ('bk-32', 'backup test model', 'internal:bk-32', 'test_embedding', 'embedding', '1,32', now (), now ());
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": register bk-32 STATE=" $STATE "\n";

create table DB.DBA.BK_T (id integer not null primary key, content varchar);

--  __VEC_INDEX_VALIDATE returns a key/value vector and isql cannot index into
--  one.  Defined here so it survives into the restored database, where
--  tvvec_backup_verify.sql uses it to ask whether the graph came back before
--  anything has had a chance to rebuild it.
create function DB.DBA.BK_KV (in kv any, in k varchar) returns any
{
  declare i integer;
  if (not isvector (kv)) return null;
  for (i := 0; i < length (kv); i := i + 2)
    if (cast (aref (kv, i) as varchar) = k) return aref (kv, i + 1);
  return null;
};

create procedure DB.DBA.BK_FILL ()
{
  declare i integer;
  for (i := 1; i <= 80; i := i + 1)
    insert into DB.DBA.BK_T values (i, 'hot 0 ' || cast (1 + mod (i, 30) as varchar));
};
DB.DBA.BK_FILL ();

--  Enough rows that the graph spans more than one node page, so the walk has
--  something to trip over beyond the root.
CREATE VECTOR INDEX BK_IDX ON DB.DBA.BK_T (content) USING 'bk-32'
  WITH (dimensions = 32, distance_metric = 'cosine', hnsw_m = 8, ef_construction = 32);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": create + backfill BK_IDX STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select count (*) from DB.DBA.BK_T;
ECHO BOTH $IF $EQU $LAST[1] 80 "PASSED" "***FAILED";
ECHO BOTH ": fixture rows=" $LAST[1] " expected 80\n";

select count (*) from DB.DBA.BK_IDX_vec_embeddings;
ECHO BOTH $IF $EQU $LAST[1] 80 "PASSED" "***FAILED";
ECHO BOTH ": embeddings rows=" $LAST[1] " expected 80\n";

select length (__VEC_INDEX_SEARCH ('BK_IDX', __VEC_INDEX_QUERY_TEXT_VECTOR ('BK_IDX', 'hot 0 1'), 20, 40));
ECHO BOTH $IF $EQU $LAST[1] 20 "PASSED" "***FAILED";
ECHO BOTH ": pre-backup ANN search hits=" $LAST[1] " expected 20\n";

--  A second index on a second table, so a failure that depends on which tree
--  the walk reaches first cannot hide.
create table DB.DBA.BK_T2 (id integer not null primary key, content varchar);
insert into DB.DBA.BK_T2 values (1, 'hot 3 4');
insert into DB.DBA.BK_T2 values (2, 'hot 3 5');
CREATE VECTOR INDEX BK_IDX2 ON DB.DBA.BK_T2 (content) USING 'bk-32'
  WITH (dimensions = 32, distance_metric = 'cosine', hnsw_m = 8, ef_construction = 32);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": create BK_IDX2 STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

--  A packed graph, as any index of 10,000+ rows gets; no rebuild option, so a repair after restore replays it to legacy and fails the format check.
create table DB.DBA.BK_PT (id integer not null primary key, content varchar);

create procedure DB.DBA.BK_PFILL ()
{
  declare i integer;
  for (i := 1; i <= 80; i := i + 1)
    insert into DB.DBA.BK_PT values (i, 'hot 0 ' || cast (1 + mod (i, 30) as varchar));
};
DB.DBA.BK_PFILL ();

CREATE VECTOR INDEX BK_P_IDX ON DB.DBA.BK_PT (content) USING 'bk-32'
  WITH (dimensions = 32, distance_metric = 'cosine', hnsw_m = 8, ef_construction = 32);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": create + backfill BK_P_IDX STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select __VEC_INDEX_REBUILD ('BK_P_IDX', 'fast');
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": fast rebuild BK_P_IDX rows=" $LAST[1] " STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select get_keyword ('format', __VEC_INDEX_PAGE_STATS ('BK_P_IDX'));
ECHO BOTH $IF $EQU $LAST[1] packed "PASSED" "***FAILED";
ECHO BOTH ": BK_P_IDX format=" $LAST[1] " expected packed\n";

select case when get_keyword ('physical_node_pages', __VEC_INDEX_PAGE_STATS ('BK_P_IDX')) between 2 and 79 then 1 else 0 end;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": BK_P_IDX spans several packed pages, fewer than its 80 nodes=" $LAST[1] "\n";

select length (__VEC_INDEX_SEARCH ('BK_P_IDX', __VEC_INDEX_QUERY_TEXT_VECTOR ('BK_P_IDX', 'hot 0 1'), 20, 40));
ECHO BOTH $IF $EQU $LAST[1] 20 "PASSED" "***FAILED";
ECHO BOTH ": pre-backup packed ANN search hits=" $LAST[1] " expected 20\n";

checkpoint;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": checkpoint STATE=" $STATE "\n";

--
--  The backup statement.  This is where the server used to die; if it does,
--  the next statement never reports and the driver sees a lost connection.
--  db_backup () takes the walk_db () route, the same one virtuoso-t
--  +backup-dump takes.
--
backup 'vbk_';
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": backup statement with a vector index STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select count (*) from DB.DBA.BK_T;
ECHO BOTH $IF $EQU $LAST[1] 80 "PASSED" "***FAILED";
ECHO BOTH ": server alive after backup, rows=" $LAST[1] " expected 80\n";

select length (__VEC_INDEX_SEARCH ('BK_IDX', __VEC_INDEX_QUERY_TEXT_VECTOR ('BK_IDX', 'hot 0 1'), 20, 40));
ECHO BOTH $IF $EQU $LAST[1] 20 "PASSED" "***FAILED";
ECHO BOTH ": index still answers after backup hits=" $LAST[1] " expected 20\n";

--
--  backup_online () is the other backup surface.  It does not go through
--  walk_db () -- it copies page images (obackup.c) -- so it never had the
--  crash, but it is what an operator actually schedules, and being page-level
--  it is the one form that carries the DPF_VEC graph itself rather than
--  leaving it to be rebuilt.  Covered here so that stays true.
--
checkpoint;
backup_online ('vbk_o_#', 150, 0, vector ('.'));
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": backup_online with a vector index STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select length (__VEC_INDEX_SEARCH ('BK_IDX', __VEC_INDEX_QUERY_TEXT_VECTOR ('BK_IDX', 'hot 0 1'), 20, 40));
ECHO BOTH $IF $EQU $LAST[1] 20 "PASSED" "***FAILED";
ECHO BOTH ": index still answers after backup_online hits=" $LAST[1] " expected 20\n";

echo BOTH "COMPLETED: VVEC backup fixture\n";
