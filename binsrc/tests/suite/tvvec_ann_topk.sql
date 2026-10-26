--
--  tvvec_ann_topk.sql
--
--  Regression test for how many candidates the leading ANN path asks for.
--
--  X_SIMILAR (col, query) > threshold means "every row more similar than
--  threshold".  The optimizer answers it with a leading ANN search whose k
--  bounds how many candidates the index produces, and that k used to be a
--  hardcoded 10 whenever the call carried no explicit k argument
--  (sqldf.c: "if (!k_arg) k_arg = t_box_num (10)").  The TOP clause was never
--  consulted.  So on a table with 60 matching rows:
--
--    select count (*) ... where X_SIMILAR (c, q) > 0.6          -> 10, not 60
--    select TOP 50 ... where X_SIMILAR (c, q) > 0.6             -> 10, not 50
--
--  Wrong answers, silently, with no way to ask for more short of passing k by
--  hand.  The fix takes k from the enclosing TOP, and where the query gives no
--  bound at all it does not take the leading ANN path -- the filter/rerank plan
--  answers the whole predicate instead.
--
--  A leading ANN with k = TOP n is sound here even with a threshold: ANN
--  returns candidates in descending similarity, so if fewer than n of them
--  clear the threshold, fewer than n rows in the table clear it.
--
--  FILTER mode (sqlo_vvec_filter_mode (1)) never takes the ANN path and scans,
--  so it is used throughout as the independent control for what the right
--  answer is.
--
--  Self-contained: in-core 'test_embedding' model, no ONNX.
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

echo BOTH "STARTED: VVEC ANN top-k bound\n";

select DB.DBA.ONNX_REGISTRY_INIT ();
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": registry init STATE=" $STATE "\n";

delete from DB.DBA.ONNX_MODELS where model_name = 'tk-64';
insert into DB.DBA.ONNX_MODELS
  (model_name, description, model_path, model_type, output_name, output_shape, created_at, updated_at)
  values ('tk-64', 'ANN top-k test model', 'internal:tk-64', 'test_embedding', 'embedding', '1,64', now (), now ());
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": register tk-64 STATE=" $STATE "\n";

--
--  Fixture.  The in-core test model turns the integers in a text into the hot
--  positions of a 64-wide one/two-hot vector.  60 "near" rows all share hot
--  position 0 with the query 'hot 0 1'; 20 "far" rows share nothing with it.
--  X_SIMILAR reports 1 - distance/2, so the near rows score 0.75 and the far
--  ones (orthogonal) score 0.5: threshold 0.6 selects exactly the 60 --
--  comfortably more than the old hardcoded k of 10, and over a real graph
--  rather than 60 copies of one vector.
--
create table DB.DBA.TK_T (id integer not null primary key, content varchar);

create procedure DB.DBA.TK_FILL ()
{
  declare i integer;
  for (i := 1; i <= 60; i := i + 1)
    insert into DB.DBA.TK_T values (i, 'hot 0 ' || cast (2 + mod (i, 30) as varchar));
  for (i := 61; i <= 80; i := i + 1)
    insert into DB.DBA.TK_T values (i, 'hot 40 ' || cast (41 + mod (i, 20) as varchar));
};
DB.DBA.TK_FILL ();

CREATE VECTOR INDEX TK_IDX ON DB.DBA.TK_T (content) USING 'tk-64'
  WITH (dimensions = 64, distance_metric = 'cosine', hnsw_m = 16, ef_construction = 64);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": create + backfill TK_IDX STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select count (*) from DB.DBA.TK_T;
ECHO BOTH $IF $EQU $LAST[1] 80 "PASSED" "***FAILED";
ECHO BOTH ": fixture rows=" $LAST[1] " expected 80\n";

--  Helpers.  Every query runs through exec (): the filter mode is read when a
--  statement is *compiled*, and static SQL inside a procedure is compiled once
--  at CREATE time, so a mode set at call time would never reach it.  Each helper
--  also restores AUTO, so a mode left behind can never decide a later assertion.
create function DB.DBA.TK_SCALAR (in mode integer, in stmt varchar) returns integer
{
  declare _stat, _msg varchar;
  declare _meta, _rows any;
  sqlo_vvec_filter_mode (mode);
  _stat := '00000';
  exec (stmt, _stat, _msg, vector (), 0, _meta, _rows);
  sqlo_vvec_filter_mode (0);
  if (_stat <> '00000')
    return -1;
  return _rows[0][0];
};

create function DB.DBA.TK_COUNT (in mode integer) returns integer
{
  return DB.DBA.TK_SCALAR (mode,
      'select count (*) from DB.DBA.TK_T where X_SIMILAR (content, ''hot 0 1'') > 0.6');
};

create function DB.DBA.TK_TOP (in mode integer, in n integer) returns integer
{
  return DB.DBA.TK_SCALAR (mode,
      'select count (*) from (select TOP ' || cast (n as varchar) ||
      ' id from DB.DBA.TK_T where X_SIMILAR (content, ''hot 0 1'') > 0.6) x');
};

--  Same, with an explicit k argument on the call.
create function DB.DBA.TK_TOP_K (in n integer, in k integer) returns integer
{
  return DB.DBA.TK_SCALAR (0,
      'select count (*) from (select TOP ' || cast (n as varchar) ||
      ' id from DB.DBA.TK_T where X_SIMILAR (content, ''hot 0 1'', ' || cast (k as varchar) ||
      ') > 0.6) x');
};

--  Every row a query returns must really clear the threshold: count the ones
--  that do not.  0 means the plan returned no row it should not have.
create function DB.DBA.TK_BAD_ROWS (in n integer) returns integer
{
  declare _stat, _msg varchar;
  declare _meta, _rows any;
  declare bad, inx integer;
  bad := 0;
  sqlo_vvec_filter_mode (0);
  _stat := '00000';
  exec ('select id from (select TOP ' || cast (n as varchar) ||
        ' id from DB.DBA.TK_T where X_SIMILAR (content, ''hot 0 1'') > 0.6) x',
        _stat, _msg, vector (), 0, _meta, _rows);
  sqlo_vvec_filter_mode (0);
  if (_stat <> '00000')
    return -1;
  for (inx := 0; inx < length (_rows); inx := inx + 1)
    {
      declare s any;
      --  Scored one row at a time under FILTER, which never takes the ANN
      --  path, so this is the independent opinion of what the row scores.
      s := DB.DBA.TK_SCALAR (1,
          'select cast (100 * X_SIMILAR (content, ''hot 0 1'') as integer) from DB.DBA.TK_T where id = ' ||
          cast (_rows[inx][0] as varchar));
      if (s is null or s <= 60)
        bad := bad + 1;
    }
  return bad;
};

create function DB.DBA.TK_EXPL (in q varchar, in pat varchar) returns integer
{
  return case when strstr (__vvec_explain_str (q), pat) is not null then 1 else 0 end;
};
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": create helpers STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

--
--  1. The control: FILTER mode scans and reranks, so it sees all 60.
--
select DB.DBA.TK_COUNT (1);
ECHO BOTH $IF $EQU $LAST[1] 60 "PASSED" "***FAILED";
ECHO BOTH ": FILTER-mode control count=" $LAST[1] " expected 60\n";

--
--  2. An unbounded predicate must return the whole answer, not a top-10 slice.
--
select DB.DBA.TK_COUNT (0);
ECHO BOTH $IF $EQU $LAST[1] 60 "PASSED" "***FAILED";
ECHO BOTH ": AUTO-mode count (no TOP, no k) count=" $LAST[1] " expected 60\n";

select DB.DBA.TK_COUNT (2);
ECHO BOTH $IF $EQU $LAST[1] 60 "PASSED" "***FAILED";
ECHO BOTH ": ANN-mode count (no TOP, no k) count=" $LAST[1] " expected 60\n";

--
--  3. k follows TOP.  Under the old hardcoded 10 every one of these was 10.
--
select DB.DBA.TK_TOP (0, 5);
ECHO BOTH $IF $EQU $LAST[1] 5 "PASSED" "***FAILED";
ECHO BOTH ": TOP 5 rows=" $LAST[1] " expected 5\n";

select DB.DBA.TK_TOP (0, 10);
ECHO BOTH $IF $EQU $LAST[1] 10 "PASSED" "***FAILED";
ECHO BOTH ": TOP 10 rows=" $LAST[1] " expected 10\n";

select DB.DBA.TK_TOP (0, 25);
ECHO BOTH $IF $EQU $LAST[1] 25 "PASSED" "***FAILED";
ECHO BOTH ": TOP 25 rows=" $LAST[1] " expected 25\n";

select DB.DBA.TK_TOP (0, 50);
ECHO BOTH $IF $EQU $LAST[1] 50 "PASSED" "***FAILED";
ECHO BOTH ": TOP 50 rows=" $LAST[1] " expected 50\n";

--  TOP larger than the matching set is capped by the threshold, not by k.
select DB.DBA.TK_TOP (0, 100);
ECHO BOTH $IF $EQU $LAST[1] 60 "PASSED" "***FAILED";
ECHO BOTH ": TOP 100 rows=" $LAST[1] " expected 60 (all matching)\n";

--  The ANN answer must equal the scanning answer at every bound.
select DB.DBA.TK_TOP (0, 50) - DB.DBA.TK_TOP (1, 50);
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": TOP 50 AUTO == FILTER diff=" $LAST[1] "\n";

select DB.DBA.TK_TOP (0, 100) - DB.DBA.TK_TOP (1, 100);
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": TOP 100 AUTO == FILTER diff=" $LAST[1] "\n";

--
--  4. An explicit k argument still wins over TOP, in both directions.
--
select DB.DBA.TK_TOP_K (50, 100);
ECHO BOTH $IF $EQU $LAST[1] 50 "PASSED" "***FAILED";
ECHO BOTH ": TOP 50 with explicit k=100 rows=" $LAST[1] " expected 50\n";

select DB.DBA.TK_TOP_K (50, 7);
ECHO BOTH $IF $EQU $LAST[1] 7 "PASSED" "***FAILED";
ECHO BOTH ": TOP 50 with explicit k=7 rows=" $LAST[1] " expected 7 (k caps TOP)\n";

--
--  5. No row is returned that does not clear the threshold.
--
select DB.DBA.TK_BAD_ROWS (50);
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": rows returned below the threshold=" $LAST[1] " expected 0\n";

--
--  6. Plan shape.  With a bound the leading ANN runs and asks for exactly that
--     many candidates; with no bound at all it must not run.
--
select DB.DBA.TK_EXPL ('select TOP 25 id from DB.DBA.TK_T where X_SIMILAR (content, ''hot 0 1'') > 0.6', 'mode=ann');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": TOP 25 plan takes the leading ANN path\n";

select DB.DBA.TK_EXPL ('select TOP 25 id from DB.DBA.TK_T where X_SIMILAR (content, ''hot 0 1'') > 0.6', 'k= 25');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": TOP 25 plan asks the index for k=25\n";

select DB.DBA.TK_EXPL ('select TOP 25 id from DB.DBA.TK_T where X_SIMILAR (content, ''hot 0 1'') > 0.6', 'k= 10');
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": TOP 25 plan does not fall back to k=10\n";

select DB.DBA.TK_EXPL ('select id from DB.DBA.TK_T where X_SIMILAR (content, ''hot 0 1'') > 0.6', 'mode=ann');
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": unbounded plan does not take a k-bounded leading ANN\n";

select DB.DBA.TK_EXPL ('select id from DB.DBA.TK_T where X_SIMILAR (content, ''hot 0 1'', 100) > 0.6', 'mode=ann');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": explicit k without TOP still takes the leading ANN path\n";

--
--  7. ORDER BY VECTOR_DISTANCE, the other ANN entry point, is unchanged: its k
--     has always come from TOP.
--
create function DB.DBA.TK_OBY (in n integer) returns integer
{
  declare _stat, _msg varchar;
  declare _meta, _rows any;
  _stat := '00000';
  exec ('select count (*) from (select TOP ' || cast (n as varchar) ||
        ' id from DB.DBA.TK_T order by VECTOR_DISTANCE (content, ''hot 0 1'')) x',
        _stat, _msg, vector (), 0, _meta, _rows);
  if (_stat <> '00000')
    return -1;
  return _rows[0][0];
};

select DB.DBA.TK_OBY (30);
ECHO BOTH $IF $EQU $LAST[1] 30 "PASSED" "***FAILED";
ECHO BOTH ": TOP 30 order by VECTOR_DISTANCE rows=" $LAST[1] " expected 30\n";

--
--  8. A text index on the same column: with a TOP the ANN search leads and
--     contains checks its candidates; without one the text index leads and
--     X_SIMILAR, like any other predicate on the text key, stays a filter.
--
create text index on DB.DBA.TK_T (content) with key id;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": create text index STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select DB.DBA.TK_SCALAR (0, 'select count (*) from (select top 2 id from DB.DBA.TK_T where contains (content, ''hot'') and X_SIMILAR (content, ''hot 0 1'') > 0.6) x');
ECHO BOTH $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";
ECHO BOTH ": TOP 2 contains + X_SIMILAR rows=" $LAST[1] " expected 2\n";

select DB.DBA.TK_SCALAR (0, 'select count (*) from (select top 100 id from DB.DBA.TK_T where contains (content, ''hot'') and X_SIMILAR (content, ''hot 0 1'') > 0.6) x');
ECHO BOTH $IF $EQU $LAST[1] 60 "PASSED" "***FAILED";
ECHO BOTH ": TOP 100 contains + X_SIMILAR rows=" $LAST[1] " expected 60\n";

select DB.DBA.TK_SCALAR (0, 'select count (*) from DB.DBA.TK_T where contains (content, ''hot'') and X_SIMILAR (content, ''hot 0 1'') > 0.6');
ECHO BOTH $IF $EQU $LAST[1] 60 "PASSED" "***FAILED";
ECHO BOTH ": count contains + X_SIMILAR=" $LAST[1] " expected 60\n";

select DB.DBA.TK_SCALAR (0, 'select count (*) from DB.DBA.TK_T where contains (content, ''hot'') and abs (id) > 70');
ECHO BOTH $IF $EQU $LAST[1] 10 "PASSED" "***FAILED";
ECHO BOTH ": count contains + abs (id) > 70=" $LAST[1] " expected 10\n";

--
--  Cleanup.
--
drop function DB.DBA.TK_OBY;
drop function DB.DBA.TK_EXPL;
drop function DB.DBA.TK_BAD_ROWS;
drop function DB.DBA.TK_TOP_K;
drop function DB.DBA.TK_TOP;
drop function DB.DBA.TK_COUNT;
drop function DB.DBA.TK_SCALAR;
drop procedure DB.DBA.TK_FILL;
drop index TK_IDX;
drop table DB.DBA.TK_T;
delete from DB.DBA.ONNX_MODELS where model_name = 'tk-64';
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": cleanup STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

echo BOTH "COMPLETED: VVEC ANN top-k bound\n";
