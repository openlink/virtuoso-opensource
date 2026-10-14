--
--  tvvec_filter_mode.sql
--
--  Regression test for the similarity filter/rerank mode and its session knob
--  sqlo_vvec_filter_mode (vision Phase 6.2/6.3: "the same similarity node must be
--  usable in two modes -- leading index access, and filter over candidate ids").
--
--  The optimizer already realizes both modes: a leading ANN vvec_search_node for a
--  pure top-k similarity query, and a scalar __VEC_INDEX_ROW_SIMILARITY recompute
--  ("filter" plan) when another predicate accompanies the similarity call.  This
--  test pins that two-mode contract and the knob that makes the choice explicit:
--
--    0 AUTO   optimizer decides (default);
--    1 FILTER force the filter/rerank plan -- never take the leading ANN path;
--    2 ANN    prefer leading ANN (hint; currently == AUTO for the planner).
--
--  Self-contained: in-core 'test_embedding' model, index backfilled on a small
--  populated table -- no ONNX, no SPARQL backfill bootstrap dependency.
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS) project.
--  Copyright (C) 1998-2026 OpenLink Software.  GNU GPL v2, 1991.
--

echo BOTH "STARTED: VVEC filter/rerank mode\n";

select DB.DBA.ONNX_REGISTRY_INIT ();
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": registry init STATE=" $STATE "\n";

delete from DB.DBA.ONNX_MODELS where model_name = 'fm-8';
insert into DB.DBA.ONNX_MODELS
  (model_name, description, model_path, model_type, output_name, output_shape, created_at, updated_at)
  values ('fm-8', 'filter-mode test model', 'internal:fm-8', 'test_embedding', 'embedding', '1,8', now (), now ());
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": register fm-8 STATE=" $STATE "\n";

create table DB.DBA.FM_T (id integer not null primary key, category varchar, content varchar);
insert into DB.DBA.FM_T values (1, 'a', 'positions 1 2');
insert into DB.DBA.FM_T values (2, 'b', 'positions 3 4');
insert into DB.DBA.FM_T values (3, 'a', 'positions 1 3');
insert into DB.DBA.FM_T values (4, 'b', 'positions 5 6');
insert into DB.DBA.FM_T values (5, 'a', 'positions 2 2');
CREATE VECTOR INDEX FM_IDX ON DB.DBA.FM_T (content) USING 'fm-8'
  WITH (dimensions = 8, distance_metric = 'cosine', hnsw_m = 8, ef_construction = 16);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": create + backfill FM_IDX STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

-- EXPLAIN-contains helper, and a "sorted id list" helper for result-set compare.
create function DB.DBA.FM_EXPL (in q varchar, in pat varchar) returns integer
{
  return case when strstr (__vvec_explain_str (q), pat) is not null then 1 else 0 end;
};
create function DB.DBA.FM_IDS (in mode integer) returns varchar
{
  declare s varchar;
  sqlo_vvec_filter_mode (mode);
  s := '';
  for (select id from DB.DBA.FM_T
        where category = 'a' and X_SIMILAR (content, 'positions 1 2') > -1.0
        order by id) do
    s := s || cast (id as varchar) || ',';
  return s;
};
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": create helpers STATE=" $STATE "\n";

--------------------------------------------------------------------------------
-- Knob get/set + validation.
--------------------------------------------------------------------------------
select sqlo_vvec_filter_mode (0);
select sqlo_vvec_filter_mode ();
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": default/get filter_mode=" $LAST[1] "\n";
select sqlo_vvec_filter_mode (1);
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": set returns previous value=" $LAST[1] "\n";
select sqlo_vvec_filter_mode ();
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": get after set filter=" $LAST[1] "\n";
select sqlo_vvec_filter_mode (0);

-- invalid value rejected with VEC64
create function DB.DBA.FM_BAD_MODE () returns integer
{
  declare exit handler for sqlstate '*'
    { if (__SQL_MESSAGE like '%VEC64%') return 1; return -1; };
  sqlo_vvec_filter_mode (3);
  return 0;
};
select DB.DBA.FM_BAD_MODE ();
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": invalid mode rejected (VEC64)=" $LAST[1] "\n";
select sqlo_vvec_filter_mode (0);

--------------------------------------------------------------------------------
-- Plan shapes: the two modes are distinct and observable in EXPLAIN.
--------------------------------------------------------------------------------
-- Pure top-k similarity: AUTO takes the leading ANN node.
select sqlo_vvec_filter_mode (0);
select DB.DBA.FM_EXPL ('select top 5 id from DB.DBA.FM_T where X_SIMILAR(content, ''positions 1 2'', 5) > 0.0', 'vvec_search_node');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": AUTO pure top-k uses leading ANN node=" $LAST[1] "\n";

-- FILTER forces the scalar/filter plan: no leading ANN node, row-similarity present.
select sqlo_vvec_filter_mode (1);
select DB.DBA.FM_EXPL ('select top 5 id from DB.DBA.FM_T where X_SIMILAR(content, ''positions 1 2'', 5) > 0.0', 'vvec_search_node');
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": FILTER pure top-k drops leading ANN node=" $LAST[1] "\n";
select DB.DBA.FM_EXPL ('select top 5 id from DB.DBA.FM_T where X_SIMILAR(content, ''positions 1 2'', 5) > 0.0', '__VEC_INDEX_ROW_SIMILARITY');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": FILTER pure top-k uses scalar row similarity=" $LAST[1] "\n";

-- With a secondary predicate, AUTO now KEEPS the leading ANN node: the
-- predicate is routed into after_preds and applied as a per-row filter on the
-- top-k candidates, instead of cancelling leading-ANN and forcing an
-- exhaustive __VEC_INDEX_ROW_SIMILARITY rescan.
select sqlo_vvec_filter_mode (0);
select DB.DBA.FM_EXPL ('select top 5 id from DB.DBA.FM_T where category = ''a'' and X_SIMILAR(content, ''positions 1 2'', 5) > 0.0', 'vvec_search_node');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": AUTO+filter predicate keeps leading ANN=" $LAST[1] "\n";
select DB.DBA.FM_EXPL ('select top 5 id from DB.DBA.FM_T where category = ''a'' and X_SIMILAR(content, ''positions 1 2'', 5) > 0.0', '__VEC_INDEX_ROW_SIMILARITY');
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": AUTO+filter predicate drops the scalar rescan=" $LAST[1] "\n";

--------------------------------------------------------------------------------
-- Correctness: filter mode reranks the complete filtered set, and the knob does
-- not change results -- only the plan.
--------------------------------------------------------------------------------
select DB.DBA.FM_IDS (1);
ECHO BOTH $IF $EQU $LAST[1] "1,3,5," "PASSED" "***FAILED";
ECHO BOTH ": FILTER returns complete category=a set ids=" $LAST[1] "\n";
select case when DB.DBA.FM_IDS (0) = DB.DBA.FM_IDS (1) then 1 else 0 end;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": AUTO and FILTER return identical result set=" $LAST[1] "\n";
select sqlo_vvec_filter_mode (0);

echo BOTH "COMPLETED: VVEC filter/rerank mode\n";
