--
--  tvvec_ann_fastlane.sql
--
--  Phase 5: native query fast-lane regression tests.
--
--  Verifies that the vvec_search_node plan node (which calls
--  vvec_search_run_key directly, bypassing the PL->BIF marshalling)
--  returns results equivalent to the direct __VEC_INDEX_SEARCH BIF.
--
--  Also verifies that EXPLAIN shows the vvec_search_node for ANN queries.
--
--  Depends on the tvvec_begin.sql bootstrap (VVEC_BEGIN_DOCS, VVEC_BEGIN_IDX,
--  VVEC_BEGIN_MAKE_VEC).
--

echo BOTH "STARTED: VVEC ANN fast-lane equivalence tests\n";

-- Equivalence: BIF path vs SQL plan node path must return the same row IDs
-- in the same order.  The plan node uses vvec_search_run_key (pre-resolved
-- dbe_key_t*) instead of vvec_search_run (name->key schema scan).
create function DB.DBA.VVEC_ANN_FASTLANE_EQUIV (in pos1 integer, in pos2 integer, in k integer) returns integer
{
  declare bif_result any;
  declare state, msg, meta any;
  declare arr any;
  declare i integer;
  declare j integer;
  declare hit integer;
  declare vec any;
  declare sql_row any;

  vec := DB.DBA.VVEC_BEGIN_MAKE_VEC (pos1, pos2);
  bif_result := __VEC_INDEX_SEARCH ('VVEC_BEGIN_IDX', vec, k, k);

  exec (
    'select top ' || cast (k as varchar) || ' id from DB.DBA.VVEC_BEGIN_DOCS order by VECTOR_DISTANCE(content, ?)',
    state, msg, vector (vec), k, meta, arr);

  if (state <> 0 and state <> '00000' and state <> 'OK')
    return -1;
  if (not isvector (bif_result) or not isvector (arr))
    return -2;
  if (length (bif_result) <> length (arr))
    return length (bif_result) * 100 + length (arr);

  --  Set comparison, not positional: the probe vector is orthogonal to every
  --  non-matching document, so those rows are an exact distance tie that the
  --  native fast lane and the SQL sort may order differently -- and the HNSW
  --  graph is randomised per run (vvec_random_layer -> rand(), seeded from
  --  time(NULL)).  Row ids are unique, so equal lengths plus containment is
  --  multiset equality.
  for (i := 0; i < length (bif_result); i := i + 1)
    {
      hit := 0;
      for (j := 0; j < length (arr); j := j + 1)
	{
	  sql_row := aref (arr, j);
	  if (isarray (sql_row))
	    sql_row := aref (sql_row, 0);
	  if (aref (aref (bif_result, i), 0) = sql_row)
	    hit := 1;
	}
      if (not hit)
	return 1000 + i;
    }
  return 1;
};
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": create VVEC_ANN_FASTLANE_EQUIV STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

-- TOP 1 equivalence
select DB.DBA.VVEC_ANN_FASTLANE_EQUIV (123, 124, 1);
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": fast-lane TOP 1 BIF/plan equivalence\n";

-- TOP 3 equivalence
select DB.DBA.VVEC_ANN_FASTLANE_EQUIV (123, 124, 3);
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": fast-lane TOP 3 BIF/plan equivalence\n";

-- TOP 5 equivalence
select DB.DBA.VVEC_ANN_FASTLANE_EQUIV (123, 124, 5);
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": fast-lane TOP 5 BIF/plan equivalence\n";

-- TOP 10 equivalence
select DB.DBA.VVEC_ANN_FASTLANE_EQUIV (123, 124, 10);
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": fast-lane TOP 10 BIF/plan equivalence\n";

-- Different query vectors
select DB.DBA.VVEC_ANN_FASTLANE_EQUIV (33, 34, 5);
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": fast-lane TOP 5 different vector BIF/plan equivalence\n";

select DB.DBA.VVEC_ANN_FASTLANE_EQUIV (77, 78, 5);
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": fast-lane TOP 5 another vector BIF/plan equivalence\n";

-- Self-contained EXPLAIN helper: tvvec_ann_explain.sql creates VVEC_EXPLAIN_CONTAINS
-- but DROPs it at its end, and this suite runs after it in tvvec.sh, so define our
-- own copy rather than depend on the dropped one (otherwise the two EXPLAIN checks
-- below fail with "undefined procedure", not because the plan lacks the node).
create function DB.DBA.VVEC_EXPLAIN_CONTAINS (in query varchar, in pattern varchar) returns integer
{
  declare expl_str varchar;
  expl_str := __vvec_explain_str (query);
  if (strstr (expl_str, pattern) is not null)
    return 1;
  return 0;
};
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": create fast-lane VVEC_EXPLAIN_CONTAINS STATE=" $STATE "\n";

-- EXPLAIN must show vvec_search_node (the fast-lane plan node)
select DB.DBA.VVEC_EXPLAIN_CONTAINS (
  'select top 5 id from DB.DBA.VVEC_BEGIN_DOCS order by VECTOR_DISTANCE(content, DB.DBA.VVEC_BEGIN_MAKE_VEC (123, 124))',
  'vvec_search_node'
);
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": fast-lane EXPLAIN shows vvec_search_node\n";

-- EXPLAIN must show mode=ann
select DB.DBA.VVEC_EXPLAIN_CONTAINS (
  'select top 5 id from DB.DBA.VVEC_BEGIN_DOCS order by VECTOR_DISTANCE(content, DB.DBA.VVEC_BEGIN_MAKE_VEC (123, 124))',
  'mode=ann'
);
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": fast-lane EXPLAIN shows mode=ann\n";

drop function DB.DBA.VVEC_ANN_FASTLANE_EQUIV;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": drop VVEC_ANN_FASTLANE_EQUIV STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

echo BOTH "COMPLETED: VVEC ANN fast-lane equivalence tests\n";
