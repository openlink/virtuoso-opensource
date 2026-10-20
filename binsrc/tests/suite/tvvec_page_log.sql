--
--  tvvec_page_log.sql
--
--  Fixture for tvvec_page_log.sh.
--
--  Builds a vector index and then dirties its graph pages WITHOUT a
--  checkpoint, which is the state the driver needs: a DPF_VEC page stays dirty
--  from the write that touched it until the next checkpoint, and it is exactly
--  in that window that a read path must still be a read path.
--
--  Nothing here asserts the log size -- a .sql cannot stat a file.  The
--  assertions are in the driver; this script only has to leave the database in
--  the right state and prove the index answers, so that a later failure means
--  "the search logged something", not "the search never ran".
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

echo BOTH "STARTED: VVEC page log fixture\n";

select DB.DBA.ONNX_REGISTRY_INIT ();
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": registry init STATE=" $STATE "\n";

delete from DB.DBA.ONNX_MODELS where model_name = 'vpl-32';
insert into DB.DBA.ONNX_MODELS
  (model_name, description, model_path, model_type, output_name, output_shape, created_at, updated_at)
  values ('vpl-32', 'page log test model', 'internal:vpl-32', 'test_embedding', 'embedding', '1,32', now (), now ());
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": register vpl-32 STATE=" $STATE "\n";

create table DB.DBA.VPL_T (id integer not null primary key, content varchar);

create procedure DB.DBA.VPL_FILL (in first_id integer, in last_id integer)
{
  declare i integer;
  for (i := first_id; i <= last_id; i := i + 1)
    insert into DB.DBA.VPL_T values (i, 'hot 0 ' || cast (1 + mod (i, 40) as varchar));
};

--  A batch of searches, as one call, so the driver's measured window contains
--  exactly this and nothing else.  Each one walks the graph: entry point, then
--  a descent through the layers, so it touches a good spread of node pages.
create procedure DB.DBA.VPL_SEARCH (in n_searches integer)
{
  declare i, hits integer;
  hits := 0;
  for (i := 1; i <= n_searches; i := i + 1)
    hits := hits + length (__VEC_INDEX_SEARCH ('VPL_IDX',
        __VEC_INDEX_QUERY_TEXT_VECTOR ('VPL_IDX', 'hot 0 ' || cast (1 + mod (i, 40) as varchar)),
        20, 64));
  return hits;
};

DB.DBA.VPL_FILL (1, 200);

CREATE VECTOR INDEX VPL_IDX ON DB.DBA.VPL_T (content) USING 'vpl-32'
  WITH (dimensions = 32, distance_metric = 'cosine', hnsw_m = 8, ef_construction = 32);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": create + backfill VPL_IDX STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select count (*) from DB.DBA.VPL_IDX_vec_embeddings;
ECHO BOTH $IF $EQU $LAST[1] 200 "PASSED" "***FAILED";
ECHO BOTH ": fixture embeddings=" $LAST[1] " expected 200\n";

--  Packed, as any index of 10,000+ rows is: the inserts below then mix legacy nodes into a packed graph, and the searches read both formats.
select __VEC_INDEX_REBUILD ('VPL_IDX', 'fast');
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": fast rebuild VPL_IDX rows=" $LAST[1] " STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select get_keyword ('format', __VEC_INDEX_PAGE_STATS ('VPL_IDX'));
ECHO BOTH $IF $EQU $LAST[1] packed "PASSED" "***FAILED";
ECHO BOTH ": VPL_IDX format=" $LAST[1] " expected packed\n";

--  Dirty the graph AFTER the DDL, so the window does not depend on whether
--  CREATE VECTOR INDEX ends in a checkpoint of its own.  These go through the
--  incremental insert path, which writes the new node's page, the root, and a
--  backlink into each chosen neighbour.
--
--  This has to be a SECOND procedure, created here rather than reusing
--  VPL_FILL above: a procedure's static SQL is compiled once, at CREATE, and
--  VPL_FILL was compiled before CREATE VECTOR INDEX existed to put a trigger
--  on the table.  Calling it now inserts the rows and silently embeds none of
--  them.
create procedure DB.DBA.VPL_FILL_INDEXED (in first_id integer, in last_id integer)
{
  declare i integer;
  for (i := first_id; i <= last_id; i := i + 1)
    insert into DB.DBA.VPL_T values (i, 'hot 0 ' || cast (1 + mod (i, 40) as varchar));
};

DB.DBA.VPL_FILL_INDEXED (201, 260);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": post-DDL inserts STATE=" $STATE "\n";

--  Embedding is queued, not synchronous, so the rows are in the table well
--  before they are in the graph.  Drain before measuring anything.
select DB.DBA.VEC_SQL_QUEUE_DRAIN (100);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": drain the embed queue drained=" $LAST[1] " STATE=" $STATE "\n";

select count (*) from DB.DBA.VPL_T;
ECHO BOTH $IF $EQU $LAST[1] 260 "PASSED" "***FAILED";
ECHO BOTH ": rows after post-DDL inserts=" $LAST[1] " expected 260\n";

select count (*) from DB.DBA.VPL_IDX_vec_embeddings;
ECHO BOTH $IF $EQU $LAST[1] 260 "PASSED" "***FAILED";
ECHO BOTH ": embeddings after post-DDL inserts=" $LAST[1] " expected 260\n";

--  Warm-up.  Anything a first search does once -- an epoch sync, a health
--  recheck, a compiled query going into the cache -- happens here, OUTSIDE the
--  driver's measured window, so it cannot be charged to the searches.
select DB.DBA.VPL_SEARCH (5);
ECHO BOTH $IF $EQU $LAST[1] 100 "PASSED" "***FAILED";
ECHO BOTH ": warm-up search hits=" $LAST[1] " expected 100\n";

--  NO checkpoint here.  A checkpoint would both truncate the log and write the
--  dirty pages out, and the driver would then measure nothing at all.

echo BOTH "COMPLETED: VVEC page log fixture\n";
