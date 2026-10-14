--
--  tvvec_recovery_graph.sql
--
--  Fixture for tvvec_recovery_graph.sh: a vector index whose graph must
--  survive both a logical restore and a crash roll-forward.
--
--  A native vector index keeps its HNSW graph in DPF_VEC pages that are
--  persisted only through itc_delta_this_buffer () -- the checkpoint dirty
--  set (vvec.c:1173).  Nothing about the graph reaches the transaction log,
--  and walk_db () skips the tree entirely (recovery.c:227), so neither
--  "virtuoso-t +backup-dump" nor a roll-forward past the last checkpoint can
--  bring the graph back.  The table rows and the embeddings do come back --
--  they are ordinary logged tables -- which leaves the index pointing at data
--  that moved on without it, and every search then raises VEC80.
--
--  A deterministic internal test_embedding model is used rather than a real
--  ONNX model: this driver is about durability, not about embedding quality,
--  and the fixture must be reproducible across a restart.
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

echo BOTH "STARTED: VVEC recovery graph fixture\n";

select DB.DBA.ONNX_REGISTRY_INIT ();
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": registry init STATE=" $STATE "\n";

delete from DB.DBA.ONNX_MODELS where model_name = 'vrg-32';
insert into DB.DBA.ONNX_MODELS
  (model_name, description, model_path, model_type, output_name, output_shape, created_at, updated_at)
  values ('vrg-32', 'recovery graph test model', 'internal:vrg-32', 'test_embedding', 'embedding', '1,32', now (), now ());
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": register vrg-32 STATE=" $STATE "\n";

create table DB.DBA.VRG_T (id integer not null primary key, content varchar);

create procedure DB.DBA.VRG_FILL ()
{
  declare i integer;
  for (i := 1; i <= 80; i := i + 1)
    insert into DB.DBA.VRG_T values (i, 'hot 0 ' || cast (1 + mod (i, 30) as varchar));
};
DB.DBA.VRG_FILL ();

--  Small key-value reader over the __VEC_INDEX_VALIDATE () result vector, so
--  the assertions below can name a field instead of indexing blind.
create function DB.DBA.VRG_KV (in kv any, in key_name varchar) returns any
{
  declare inx integer;
  if (not isvector (kv))
    return null;
  for (inx := 0; inx < length (kv); inx := inx + 2)
    {
      if (aref (kv, inx) = key_name)
        return aref (kv, inx + 1);
    }
  return null;
};

--  Enough rows that the graph spans more than one node page, so a recovery
--  path that happens to restore only the root cannot pass.
CREATE VECTOR INDEX VRG_IDX ON DB.DBA.VRG_T (content) USING 'vrg-32'
  WITH (dimensions = 32, distance_metric = 'cosine', hnsw_m = 8, ef_construction = 32);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": create + backfill VRG_IDX STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select count (*) from DB.DBA.VRG_T;
ECHO BOTH $IF $EQU $LAST[1] 80 "PASSED" "***FAILED";
ECHO BOTH ": fixture rows=" $LAST[1] " expected 80\n";

select count (*) from DB.DBA.VRG_IDX_vec_embeddings;
ECHO BOTH $IF $EQU $LAST[1] 80 "PASSED" "***FAILED";
ECHO BOTH ": fixture embeddings=" $LAST[1] " expected 80\n";

--  Baseline: the index answers before anything is backed up or crashed.  Every
--  later assertion is this same pair, so a failure says "recovery lost it",
--  not "the fixture never worked".
select length (__VEC_INDEX_SEARCH ('VRG_IDX', __VEC_INDEX_QUERY_TEXT_VECTOR ('VRG_IDX', 'hot 0 1'), 20, 40));
ECHO BOTH $IF $EQU $LAST[1] 20 "PASSED" "***FAILED";
ECHO BOTH ": pre-recovery ANN search hits=" $LAST[1] " expected 20\n";

select count (*) from DB.DBA.VRG_T where X_SIMILAR (content, 'hot 0 1') > 0.6;
ECHO BOTH $IF $EQU $LAST[1] 80 "PASSED" "***FAILED";
ECHO BOTH ": pre-recovery X_SIMILAR count=" $LAST[1] " expected 80\n";

select DB.DBA.VRG_KV (__VEC_INDEX_VALIDATE ('VRG_IDX'), 'consistent');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": pre-recovery consistent=" $LAST[1] " expected 1\n";

--  A packed graph, as any index of 10,000+ rows gets; no rebuild option, so an automatic repair replays it to legacy and fails the format checks.
create table DB.DBA.VRG_PT (id integer not null primary key, content varchar);

create procedure DB.DBA.VRG_PFILL ()
{
  declare i integer;
  for (i := 1; i <= 80; i := i + 1)
    insert into DB.DBA.VRG_PT values (i, 'hot 0 ' || cast (1 + mod (i, 30) as varchar));
};
DB.DBA.VRG_PFILL ();

CREATE VECTOR INDEX VRG_P_IDX ON DB.DBA.VRG_PT (content) USING 'vrg-32'
  WITH (dimensions = 32, distance_metric = 'cosine', hnsw_m = 8, ef_construction = 32);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": create + backfill VRG_P_IDX STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select __VEC_INDEX_REBUILD ('VRG_P_IDX', 'fast');
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": fast rebuild VRG_P_IDX rows=" $LAST[1] " STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select get_keyword ('format', __VEC_INDEX_PAGE_STATS ('VRG_P_IDX'));
ECHO BOTH $IF $EQU $LAST[1] packed "PASSED" "***FAILED";
ECHO BOTH ": VRG_P_IDX format=" $LAST[1] " expected packed\n";

select case when get_keyword ('physical_node_pages', __VEC_INDEX_PAGE_STATS ('VRG_P_IDX')) between 2 and 79 then 1 else 0 end;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": VRG_P_IDX spans several packed pages, fewer than its 80 nodes=" $LAST[1] "\n";

select length (__VEC_INDEX_SEARCH ('VRG_P_IDX', __VEC_INDEX_QUERY_TEXT_VECTOR ('VRG_P_IDX', 'hot 0 1'), 20, 40));
ECHO BOTH $IF $EQU $LAST[1] 20 "PASSED" "***FAILED";
ECHO BOTH ": pre-recovery packed ANN search hits=" $LAST[1] " expected 20\n";

select DB.DBA.VRG_KV (__VEC_INDEX_VALIDATE ('VRG_P_IDX'), 'consistent');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": pre-recovery packed consistent=" $LAST[1] " expected 1\n";

--  Checkpoint, so the graph is on disk and the two recovery paths start from a
--  known point.
checkpoint;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": fixture checkpoint STATE=" $STATE "\n";

echo BOTH "COMPLETED: VVEC recovery graph fixture\n";
