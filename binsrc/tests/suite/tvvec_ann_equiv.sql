--
--  tvvec_ann_equiv.sql
--
--  Plan/executor equivalence tests for ANN vector search.
--

echo BOTH "STARTED: VVEC ANN plan equivalence tests\n";

create function DB.DBA.VVEC_ANN_COMPARE_SEARCH (in sql_query varchar, in index_name varchar, in pos integer, in pos2 integer, in k integer) returns integer
{
  declare arr1 any;
  declare arr2 any;
  declare state any;
  declare message any;
  declare meta any;
  declare inx integer;
  declare jnx integer;
  declare hit integer;
  exec (sql_query, state, message, vector (), k, meta, arr1);
  if (state <> 0 and state <> '00000' and state <> 'OK')
    return 0;
  arr2 := __VEC_INDEX_SEARCH (index_name, DB.DBA.VVEC_BEGIN_MAKE_VEC (pos, pos2), k, k);
  if (not isvector (arr1) or not isvector (arr2))
    return 0;
  if (length (arr1) <> length (arr2))
    return 0;
  --  Compare as SETS, not as ordered sequences.  The seeded documents are
  --  deliberately orthogonal to the probe vector, so every non-matching row
  --  sits at an identical distance -- an exact tie that the ANN traversal and
  --  the SQL sort are each free to order differently.  The HNSW graph is
  --  randomised on top of that (vvec_random_layer draws on a rand() seeded
  --  from time(NULL) in vvec.c), so a positional comparison fails at random
  --  for any k > 1.  Row ids are unique, so equal lengths plus containment
  --  is full multiset equality -- which is what this file's header always
  --  said it checked ("equivalent row sets").
  for (inx := 0; inx < length (arr1); inx := inx + 1)
    {
      hit := 0;
      for (jnx := 0; jnx < length (arr2); jnx := jnx + 1)
        {
          if (aref (aref (arr1, inx), 0) = aref (aref (arr2, jnx), 0))
            hit := 1;
        }
      if (not hit)
        return 0;
    }
  return 1;
};
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": create VVEC_ANN_COMPARE_SEARCH STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select DB.DBA.VVEC_ANN_COMPARE_SEARCH (
  'select top 1 id from DB.DBA.VVEC_BEGIN_DOCS order by VECTOR_DISTANCE(content, DB.DBA.VVEC_BEGIN_MAKE_VEC (123, 124))',
  'VVEC_BEGIN_IDX',
  123,
  124,
  1
);
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": TOP 1 ANN SQL/search equivalence\n";

select DB.DBA.VVEC_ANN_COMPARE_SEARCH (
  'select top 3 id from DB.DBA.VVEC_BEGIN_DOCS order by VECTOR_DISTANCE(content, DB.DBA.VVEC_BEGIN_MAKE_VEC (123, 124))',
  'VVEC_BEGIN_IDX',
  123,
  124,
  3
);
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": TOP 3 ANN SQL/search equivalence\n";

select DB.DBA.VVEC_ANN_COMPARE_SEARCH (
  'select top 10 id from DB.DBA.VVEC_BEGIN_DOCS order by VECTOR_DISTANCE(content, DB.DBA.VVEC_BEGIN_MAKE_VEC (123, 124))',
  'VVEC_BEGIN_IDX',
  123,
  124,
  10
);
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": TOP 10 ANN SQL/search equivalence\n";

drop function DB.DBA.VVEC_ANN_COMPARE_SEARCH;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": drop VVEC_ANN_COMPARE_SEARCH STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

echo BOTH "COMPLETED: VVEC ANN plan equivalence tests\n";
