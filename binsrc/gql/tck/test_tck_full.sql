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
--
--
--  openGQL TCK Runner Schema
--
--  Creates the TCK case and result tables and the runner procedures.
--

create procedure DB.DBA.OGQL_TCK_DROP_TABLE (in _table varchar)
{
  declare exit handler for sqlstate '*'
    { return; };
  exec (sprintf ('DROP TABLE %s', _table));
}
;

DB.DBA.OGQL_TCK_DROP_TABLE ('DB.DBA.OGQL_TCK_CASES');
DB.DBA.OGQL_TCK_DROP_TABLE ('DB.DBA.OGQL_TCK_RESULTS');

create table DB.DBA.OGQL_TCK_CASES (
  CASE_ID integer not null primary key,
  FEATURE_PATH varchar not null,
  SCENARIO varchar not null,
  QUERY_TEXT varchar not null,
  EXPECTED_RESULT varchar
);

create table DB.DBA.OGQL_TCK_RESULTS (
  CASE_ID integer not null,
  FEATURE_PATH varchar not null,
  SCENARIO varchar not null,
  STATUS varchar not null,
  DETAIL varchar,
  primary key (CASE_ID)
);

----------------------------------------------------------------------
-- Classify whether a SPARQL statement is read-only
----------------------------------------------------------------------

create procedure DB.DBA.OGQL_TCK_SPARQL_IS_READ (in _sparql varchar)
{
  -- The generated text begins with 'SPARQL ' and a PREFIX/BASE/DEFINE
  -- preamble before the query form, so a leading-anchored match is not
  -- enough. Treat anything containing an update keyword as a write; among
  -- the rest, a SELECT/ASK/CONSTRUCT/DESCRIBE query form is a read.
  declare u varchar;
  u := upper (trim (_sparql));
  if (strstr (u, 'INSERT ') is not null or strstr (u, 'DELETE ') is not null
      or strstr (u, 'MODIFY ') is not null or strstr (u, 'CLEAR ') is not null
      or strstr (u, 'DROP ') is not null or strstr (u, 'CREATE ') is not null
      or strstr (u, 'LOAD ') is not null)
    return 0;
  if (strstr (u, 'SELECT ') is not null or strstr (u, 'SELECT(') is not null
      or strstr (u, 'ASK ') is not null or strstr (u, 'ASK{') is not null
      or strstr (u, 'CONSTRUCT ') is not null or strstr (u, 'DESCRIBE ') is not null)
    return 1;
  return 0;
}
;

----------------------------------------------------------------------
-- Golden-comparison helpers
--
-- Serialize an actual SPARQL result set into the SAME canonical form the
-- extractor produces from the expected Gherkin table (see
-- extract_tck_cases.py): each row is its 'colname=value' pairs sorted by
-- column name and joined by '|'; rows are joined by ' ; ' (sorted, for the
-- unordered case) inside [ ]. Values are normalized so the SPARQL-over-RDF
-- representation lines up with the property-graph expectations (GQL booleans
-- already arrive as 1/0, NULL -> 'null', IRIs -> <...>).
----------------------------------------------------------------------

create procedure DB.DBA.OGQL_TCK_VAL (in v any)
{
  if (v is null) return 'null';
  if (isiri_id (v)) return concat ('<', coalesce (id_to_iri (v), cast (v as varchar)), '>');
  if (isinteger (v)) return cast (v as varchar);
  if (isstring (v)) return v;
  return cast (v as varchar);
}
;

-- Lexical insertion sort of a small varchar vector (result sets here are tiny).
create procedure DB.DBA.OGQL_TCK_SORT (in v any)
{
  declare i, j, n integer;
  declare tmp varchar;
  n := length (v);
  for (i := 1; i < n; i := i + 1)
    {
      tmp := aref (v, i);
      j := i - 1;
      while (j >= 0 and aref (v, j) > tmp)
        { aset (v, j + 1, aref (v, j)); j := j - 1; }
      aset (v, j + 1, tmp);
    }
  return v;
}
;

create procedure DB.DBA.OGQL_TCK_SER_RESULT (in meta any, in rows any, in _ordered integer)
{
  declare i, j, ncols integer;
  declare colnames, rowstrs, pairs any;
  declare rs varchar;
  if (meta is null or length (meta) = 0) return '[]';
  colnames := aref (meta, 0);
  ncols := length (colnames);
  rowstrs := vector ();
  for (i := 0; i < (case when rows is null then 0 else length (rows) end); i := i + 1)
    {
      pairs := vector ();
      for (j := 0; j < ncols; j := j + 1)
        pairs := vector_concat (pairs, vector (concat (
                   cast (aref (aref (colnames, j), 0) as varchar), '=',
                   DB.DBA.OGQL_TCK_VAL (aref (aref (rows, i), j)))));
      pairs := DB.DBA.OGQL_TCK_SORT (pairs);
      rs := '';
      for (j := 0; j < length (pairs); j := j + 1)
        rs := concat (rs, case when j > 0 then '|' else '' end, aref (pairs, j));
      rowstrs := vector_concat (rowstrs, vector (rs));
    }
  if (not _ordered and length (rowstrs) > 1)
    rowstrs := DB.DBA.OGQL_TCK_SORT (rowstrs);
  rs := '';
  for (i := 0; i < length (rowstrs); i := i + 1)
    rs := concat (rs, case when i > 0 then ' ; ' else '' end, aref (rowstrs, i));
  return concat ('[', rs, ']');
}
;

----------------------------------------------------------------------
-- ERROR-expectation case: the query must be rejected. A translation failure
-- OR an execution failure both satisfy "should raise"; any side effect is
-- rolled back. Kept as its own procedure so the exit handler is the first
-- statement of the block.
----------------------------------------------------------------------

create procedure DB.DBA.OGQL_TCK_RUN_ERROR_CASE (
  in _case_id integer,
  in _feature_path varchar,
  in _scenario varchar,
  in _query_text varchar,
  in _expected varchar)
{
  declare _sparql, state, msg varchar;
  declare meta, data any;

  declare exit handler for sqlstate '*'
    {
      rollback work;
      insert into DB.DBA.OGQL_TCK_RESULTS (CASE_ID, FEATURE_PATH, SCENARIO, STATUS, DETAIL)
        values (_case_id, _feature_path, _scenario, 'ERROR_OK', _expected);
      return;
    };

  _sparql := DB.DBA.GQL_TO_SPARQL (_query_text);
  if (_sparql is not null and trim (_sparql) <> '')
    {
      state := '00000';
      exec (_sparql, state, msg, vector (), 0, meta, data);
      if (state <> '00000') signal (state, msg);
    }
  else
    DB.DBA.GQL_RUN (_query_text);
  rollback work;
  insert into DB.DBA.OGQL_TCK_RESULTS (CASE_ID, FEATURE_PATH, SCENARIO, STATUS, DETAIL)
    values (_case_id, _feature_path, _scenario, 'ERROR_MISMATCH', 'no error raised');
}
;

----------------------------------------------------------------------
-- Run a single TCK case
--
-- Statuses:
--   TRANSLATE_OK / TRANSLATE_FAIL     translation only (no expected result)
--   SPARQL_OK / SPARQL_FAIL           read executed (compile_reads, no expected)
--   ERROR_OK / ERROR_MISMATCH         EXPECTED_RESULT = ERROR:<code>
--   EMPTY_OK / EMPTY_MISMATCH         EXPECTED_RESULT = EMPTY
--   RESULT_OK / RESULT_MISMATCH       EXPECTED_RESULT = ROWS:/ROWSORD:
--   RESULT_SKIP                       expected rows but query is not a read
----------------------------------------------------------------------

create procedure DB.DBA.OGQL_TCK_RUN_CASE (
  in _case_id integer,
  in _feature_path varchar,
  in _scenario varchar,
  in _query_text varchar,
  in _compile_reads integer,
  in _expected varchar := null)
{
  declare _sparql varchar;
  declare state, msg varchar;
  declare meta, data any;
  declare is_read integer;

  if (length (_query_text) > 50000)
    {
      insert into DB.DBA.OGQL_TCK_RESULTS (CASE_ID, FEATURE_PATH, SCENARIO, STATUS, DETAIL)
        values (_case_id, _feature_path, _scenario, 'HARNESS_SKIP', 'Query too large');
      return;
    }

  -- ERROR expectation is handled in a dedicated procedure (see above).
  if (_expected is not null and _expected like 'ERROR:%')
    {
      DB.DBA.OGQL_TCK_RUN_ERROR_CASE (_case_id, _feature_path, _scenario, _query_text, _expected);
      return;
    }

  -- Otherwise translate (a genuine translation failure is TRANSLATE_FAIL).
  declare exit handler for sqlstate '*'
    {
      rollback work;
      insert into DB.DBA.OGQL_TCK_RESULTS (CASE_ID, FEATURE_PATH, SCENARIO, STATUS, DETAIL)
        values (_case_id, _feature_path, _scenario, 'TRANSLATE_FAIL',
                concat (__SQL_STATE, ': ', __SQL_MESSAGE));
      return;
    };

  _sparql := DB.DBA.GQL_TO_SPARQL (_query_text);
  is_read := 0;
  if (_sparql is not null and trim (_sparql) <> '' and DB.DBA.OGQL_TCK_SPARQL_IS_READ (_sparql))
    is_read := 1;

  -- EMPTY / ROWS expectations require executing a read and inspecting rows.
  if (_expected is not null
      and (_expected = 'EMPTY' or _expected like 'ROWS:%' or _expected like 'ROWSORD:%'))
    {
      if (not is_read)
        {
          insert into DB.DBA.OGQL_TCK_RESULTS (CASE_ID, FEATURE_PATH, SCENARIO, STATUS, DETAIL)
            values (_case_id, _feature_path, _scenario, 'RESULT_SKIP',
                    'expected rows but query is not a read');
          return;
        }
      declare exit handler for sqlstate '*'
        {
          rollback work;
          insert into DB.DBA.OGQL_TCK_RESULTS (CASE_ID, FEATURE_PATH, SCENARIO, STATUS, DETAIL)
            values (_case_id, _feature_path, _scenario, 'SPARQL_FAIL',
                    concat (__SQL_STATE, ': ', __SQL_MESSAGE));
          return;
        };
      state := '00000';
      exec (_sparql, state, msg, vector (), 0, meta, data);
      if (state <> '00000') signal (state, msg);
      if (_expected = 'EMPTY')
        {
          declare nrows integer;
          nrows := case when data is null then 0 else length (data) end;
          insert into DB.DBA.OGQL_TCK_RESULTS (CASE_ID, FEATURE_PATH, SCENARIO, STATUS, DETAIL)
            values (_case_id, _feature_path, _scenario,
                    case when nrows = 0 then 'EMPTY_OK' else 'EMPTY_MISMATCH' end,
                    concat ('rows=', cast (nrows as varchar)));
        }
      else
        {
          declare want, got varchar;
          declare ordered integer;
          ordered := case when _expected like 'ROWSORD:%' then 1 else 0 end;
          want := subseq (_expected, case when ordered then 8 else 5 end);
          got := DB.DBA.OGQL_TCK_SER_RESULT (meta, data, ordered);
          insert into DB.DBA.OGQL_TCK_RESULTS (CASE_ID, FEATURE_PATH, SCENARIO, STATUS, DETAIL)
            values (_case_id, _feature_path, _scenario,
                    case when got = want then 'RESULT_OK' else 'RESULT_MISMATCH' end,
                    case when got = want then null else concat ('want ', want, ' got ', got) end);
        }
      return;
    }

  -- No expected value: existing translate-only / execute behavior.
  if (_sparql is null or trim (_sparql) = '')
    {
      insert into DB.DBA.OGQL_TCK_RESULTS (CASE_ID, FEATURE_PATH, SCENARIO, STATUS, DETAIL)
        values (_case_id, _feature_path, _scenario, 'TRANSLATE_OK', 'DML-only query');
      return;
    }
  if (_compile_reads and is_read)
    {
      declare exit handler for sqlstate '*'
        {
          rollback work;
          insert into DB.DBA.OGQL_TCK_RESULTS (CASE_ID, FEATURE_PATH, SCENARIO, STATUS, DETAIL)
            values (_case_id, _feature_path, _scenario, 'SPARQL_FAIL',
                    concat (__SQL_STATE, ': ', __SQL_MESSAGE));
          return;
        };
      state := '00000';
      exec (_sparql, state, msg, vector (), 0, meta, data);
      if (state <> '00000') signal (state, msg);
      insert into DB.DBA.OGQL_TCK_RESULTS (CASE_ID, FEATURE_PATH, SCENARIO, STATUS, DETAIL)
        values (_case_id, _feature_path, _scenario, 'SPARQL_OK', null);
    }
  else
    {
      insert into DB.DBA.OGQL_TCK_RESULTS (CASE_ID, FEATURE_PATH, SCENARIO, STATUS, DETAIL)
        values (_case_id, _feature_path, _scenario, 'TRANSLATE_OK', 'Translation only');
    }
}
;

----------------------------------------------------------------------
-- Run all TCK cases
----------------------------------------------------------------------

create procedure DB.DBA.OGQL_TCK_RUN (in _compile_reads integer := 0)
{
  declare _total, i integer;
  declare cases, c any;

  -- Materialize the case list first. RUN_CASE issues COMMIT/ROLLBACK per case
  -- (to persist its result row and undo the query's side effects); doing that
  -- inside an open cursor over OGQL_TCK_CASES would close the cursor, so we
  -- read the cases into memory and iterate over the vector instead.
  cases := vector ();
  for (select CASE_ID, FEATURE_PATH, SCENARIO, QUERY_TEXT, EXPECTED_RESULT
         from DB.DBA.OGQL_TCK_CASES order by CASE_ID) do
    cases := vector_concat (cases,
      vector (vector (CASE_ID, FEATURE_PATH, SCENARIO, QUERY_TEXT, EXPECTED_RESULT)));

  _total := length (cases);
  for (i := 0; i < _total; i := i + 1)
    {
      c := aref (cases, i);
      DB.DBA.OGQL_TCK_RUN_CASE (aref (c, 0), aref (c, 1), aref (c, 2), aref (c, 3),
                               _compile_reads, aref (c, 4));
      commit work;
      if (mod (i + 1, 10) = 0)
        dbg_obj_print (concat ('Progress: ', cast (i + 1 as varchar), ' of ', cast (_total as varchar)));
    }

  dbg_obj_print (concat ('TCK run complete: ', cast (_total as varchar), ' cases'));
  return _total;
}
;

----------------------------------------------------------------------
-- Summary and failure details
----------------------------------------------------------------------

create procedure DB.DBA.OGQL_TCK_SUMMARY ()
{
  return
    (select cast (STATUS as varchar) || ': ' || cast (COUNT(*) as varchar)
     from DB.DBA.OGQL_TCK_RESULTS
     group by STATUS
     order by STATUS);
}
;

create procedure DB.DBA.OGQL_TCK_FAILURES (in _limit integer := 50)
{
  return
    (select TOP (_limit) CASE_ID, FEATURE_PATH, SCENARIO, STATUS, DETAIL
     from DB.DBA.OGQL_TCK_RESULTS
     where STATUS in ('TRANSLATE_FAIL', 'SPARQL_FAIL',
                      'ERROR_MISMATCH', 'EMPTY_MISMATCH', 'RESULT_MISMATCH')
     order by CASE_ID);
}
;
