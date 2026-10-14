--
--  tvvec_ann_explain.sql
--
--  EXPLAIN regression tests for ANN vector search.
--

echo BOTH "STARTED: VVEC ANN EXPLAIN shape tests\n";

create function DB.DBA.VVEC_EXPLAIN_CONTAINS (in query varchar, in pattern varchar) returns integer
{
  declare expl_str varchar;
  expl_str := __vvec_explain_str (query);
  if (strstr (expl_str, pattern) is not null)
    return 1;
  return 0;
};
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": create VVEC_EXPLAIN_CONTAINS STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select DB.DBA.VVEC_EXPLAIN_CONTAINS (
  'select top 5 id from DB.DBA.VVEC_BEGIN_DOCS order by VECTOR_DISTANCE(content, DB.DBA.VVEC_BEGIN_MAKE_VEC (123, 124))',
  'vvec_search_node'
);
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": EXPLAIN TOP 5 contains vvec_search_node\n";

select DB.DBA.VVEC_EXPLAIN_CONTAINS (
  'select top 5 id from DB.DBA.VVEC_BEGIN_DOCS order by VECTOR_DISTANCE(content, DB.DBA.VVEC_BEGIN_MAKE_VEC (123, 124))',
  'mode=ann'
);
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": EXPLAIN TOP 5 contains mode=ann\n";

select DB.DBA.VVEC_EXPLAIN_CONTAINS (
  'select top 5 id from DB.DBA.VVEC_BEGIN_DOCS order by VECTOR_DISTANCE(content, DB.DBA.VVEC_BEGIN_MAKE_VEC (123, 124))',
  'metric=cosine'
);
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": EXPLAIN TOP 5 contains metric=cosine\n";

select DB.DBA.VVEC_EXPLAIN_CONTAINS (
  'select top 5 id from DB.DBA.VVEC_BEGIN_DOCS order by VECTOR_DISTANCE(content, DB.DBA.VVEC_BEGIN_MAKE_VEC (123, 124))',
  'k='
);
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": EXPLAIN TOP 5 contains k field\n";

select DB.DBA.VVEC_EXPLAIN_CONTAINS (
  'select id from DB.DBA.VVEC_BEGIN_DOCS where id > 0 order by VECTOR_DISTANCE(content, DB.DBA.VVEC_BEGIN_MAKE_VEC (123, 124))',
  'vvec_search_node'
);
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": EXPLAIN without TOP does not use ANN\n";

select DB.DBA.VVEC_EXPLAIN_CONTAINS (
  'select top 5 id from DB.DBA.VVEC_BEGIN_DOCS where X_SIMILAR(content, DB.DBA.VVEC_BEGIN_MAKE_VEC (123, 124), 5) > 0.5',
  'vvec_search_node'
);
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": EXPLAIN leading X_SIMILAR contains vvec_search_node\n";

select DB.DBA.VVEC_EXPLAIN_CONTAINS (
  'select top 5 id from DB.DBA.VVEC_BEGIN_DOCS where X_SIMILAR(content, DB.DBA.VVEC_BEGIN_MAKE_VEC (123, 124), 5) > 0.5',
  'mode=ann'
);
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": EXPLAIN leading X_SIMILAR contains mode=ann\n";

select DB.DBA.VVEC_EXPLAIN_CONTAINS (
  'select top 5 id from DB.DBA.VVEC_BEGIN_DOCS where X_SIMILAR(content, DB.DBA.VVEC_BEGIN_MAKE_VEC (123, 124), 5) > 0.5',
  'vector index VVEC_BEGIN_IDX'
);
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": EXPLAIN leading X_SIMILAR contains vector index annotation\n";

select DB.DBA.VVEC_EXPLAIN_CONTAINS (
  'select top 5 id from DB.DBA.VVEC_BEGIN_DOCS where X_SIMILAR(content, ''explain positions 123 124'', 5) > 0.5',
  'vvec_search_node'
);
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": EXPLAIN leading text X_SIMILAR contains vvec_search_node\n";

select DB.DBA.VVEC_EXPLAIN_CONTAINS (
  'select top 5 id from DB.DBA.VVEC_BEGIN_DOCS where X_SIMILAR(content, ''explain positions 123 124'', 5) > 0.5',
  'mode=ann'
);
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": EXPLAIN leading text X_SIMILAR contains mode=ann\n";

select DB.DBA.VVEC_EXPLAIN_CONTAINS (
  'select id from DB.DBA.VVEC_BEGIN_DOCS where id = 2 and X_SIMILAR(content, DB.DBA.VVEC_BEGIN_MAKE_VEC (123, 124)) > 0.5',
  '__VEC_INDEX_ROW_SIMILARITY'
);
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": EXPLAIN constrained X_SIMILAR shows scalar filter mode\n";

select DB.DBA.VVEC_EXPLAIN_CONTAINS (
  'select id from DB.DBA.VVEC_BEGIN_DOCS where id = 2 and X_SIMILAR(content, DB.DBA.VVEC_BEGIN_MAKE_VEC (123, 124)) > 0.5',
  'vvec_search_node'
);
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": EXPLAIN constrained X_SIMILAR has no leading ANN node\n";

select DB.DBA.VVEC_EXPLAIN_CONTAINS (
  'select id from DB.DBA.VVEC_BEGIN_DOCS where id = 2 and X_SIMILAR(content, ''explain positions 123 124'') > 0.5',
  '__VEC_INDEX_ROW_SIMILARITY'
);
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": EXPLAIN constrained text X_SIMILAR shows scalar filter mode\n";

select DB.DBA.VVEC_EXPLAIN_CONTAINS (
  'select id from DB.DBA.VVEC_BEGIN_DOCS where id = 2 and X_SIMILAR(content, ''explain positions 123 124'') > 0.5',
  'vvec_search_node'
);
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": EXPLAIN constrained text X_SIMILAR has no leading ANN node\n";

drop function DB.DBA.VVEC_EXPLAIN_CONTAINS;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": drop VVEC_EXPLAIN_CONTAINS STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

echo BOTH "COMPLETED: VVEC ANN EXPLAIN shape tests\n";
