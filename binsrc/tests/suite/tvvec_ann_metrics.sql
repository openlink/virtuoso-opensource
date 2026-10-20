--
--  tvvec_ann_metrics.sql
--
--  Metrics counter verification tests for ANN vector search.
--

echo BOTH "STARTED: VVEC ANN metrics counter tests\n";

create function DB.DBA.VVEC_ANN_METRIC_INCREASED (in metric_name varchar, in sql_query varchar) returns integer
{
  declare before_val any;
  declare after_val any;
  declare ignored any;
  before_val := cast (DB.DBA.VVEC_BEGIN_KV_GET (__VEC_INDEX_METRICS ('VVEC_BEGIN_IDX'), metric_name) as integer);
  ignored := exec (sql_query);
  after_val := cast (DB.DBA.VVEC_BEGIN_KV_GET (__VEC_INDEX_METRICS ('VVEC_BEGIN_IDX'), metric_name) as integer);
  if (after_val > before_val)
    return 1;
  return 0;
};
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": create VVEC_ANN_METRIC_INCREASED STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create function DB.DBA.VVEC_ANN_METRIC_NONDECREASED (in metric_name varchar, in sql_query varchar) returns integer
{
  declare before_val any;
  declare after_val any;
  declare ignored any;
  before_val := cast (DB.DBA.VVEC_BEGIN_KV_GET (__VEC_INDEX_METRICS ('VVEC_BEGIN_IDX'), metric_name) as integer);
  ignored := exec (sql_query);
  after_val := cast (DB.DBA.VVEC_BEGIN_KV_GET (__VEC_INDEX_METRICS ('VVEC_BEGIN_IDX'), metric_name) as integer);
  if (after_val >= before_val)
    return 1;
  return 0;
};
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": create VVEC_ANN_METRIC_NONDECREASED STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select DB.DBA.VVEC_ANN_METRIC_INCREASED (
  'search_count',
  'select top 5 id from DB.DBA.VVEC_BEGIN_DOCS order by VECTOR_DISTANCE(content, DB.DBA.VVEC_BEGIN_MAKE_VEC (123, 124))'
);
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": search_count incremented after ANN TOP 5\n";

select DB.DBA.VVEC_ANN_METRIC_INCREASED (
  'search_count',
  'select top 3 id from DB.DBA.VVEC_BEGIN_DOCS order by VECTOR_DISTANCE(content, DB.DBA.VVEC_BEGIN_MAKE_VEC (33, 34))'
);
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": search_count incremented after ANN TOP 3\n";

select DB.DBA.VVEC_ANN_METRIC_NONDECREASED (
  'search_usec',
  'select top 1 id from DB.DBA.VVEC_BEGIN_DOCS order by VECTOR_DISTANCE(content, DB.DBA.VVEC_BEGIN_MAKE_VEC (77, -1))'
);
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": search_usec did not decrease after ANN query\n";

drop function DB.DBA.VVEC_ANN_METRIC_INCREASED;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": drop VVEC_ANN_METRIC_INCREASED STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

drop function DB.DBA.VVEC_ANN_METRIC_NONDECREASED;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": drop VVEC_ANN_METRIC_NONDECREASED STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

echo BOTH "COMPLETED: VVEC ANN metrics counter tests\n";
