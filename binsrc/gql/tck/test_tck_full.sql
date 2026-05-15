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
  declare upper_sparql varchar;
  upper_sparql := upper (trim (_sparql));
  if (upper_sparql like 'SELECT%') return 1;
  if (upper_sparql like 'ASK%') return 1;
  if (upper_sparql like 'CONSTRUCT%') return 1;
  if (upper_sparql like 'DESCRIBE%') return 1;
  if (upper_sparql like 'PREFIX%SELECT%') return 1;
  return 0;
}
;

----------------------------------------------------------------------
-- Run a single TCK case
----------------------------------------------------------------------

create procedure DB.DBA.OGQL_TCK_RUN_CASE (
  in _case_id integer,
  in _feature_path varchar,
  in _scenario varchar,
  in _query_text varchar,
  in _compile_reads integer)
{
  declare sparql, status, detail varchar;
  declare state, msg varchar;
  declare meta, data any;

  -- Skip queries that are too large
  if (length (_query_text) > 50000)
    {
      insert into DB.DBA.OGQL_TCK_RESULTS (CASE_ID, FEATURE_PATH, SCENARIO, STATUS, DETAIL)
        values (_case_id, _feature_path, _scenario, 'HARNESS_SKIP', 'Query too large');
      return;
    }

  -- Attempt translation
  declare exit handler for sqlstate '*'
    {
      rollback work;
      insert into DB.DBA.OGQL_TCK_RESULTS (CASE_ID, FEATURE_PATH, SCENARIO, STATUS, DETAIL)
        values (_case_id, _feature_path, _scenario, 'TRANSLATE_FAIL',
                concat (__SQL_STATE, ': ', __SQL_MESSAGE));
      return;
    };

  sparql := DB.DBA.GQL_TO_SPARQL (_query_text);

  if (sparql is null or trim (sparql) = '')
    {
      -- DML-only queries: translation succeeded
      insert into DB.DBA.OGQL_TCK_RESULTS (CASE_ID, FEATURE_PATH, SCENARIO, STATUS, DETAIL)
        values (_case_id, _feature_path, _scenario, 'TRANSLATE_OK', 'DML-only query');
      return;
    }

  -- If compile_reads is on and this is a read query, execute it
  if (_compile_reads and DB.DBA.OGQL_TCK_SPARQL_IS_READ (sparql))
    {
      declare exit handler for sqlstate '*'
        {
          rollback work;
          insert into DB.DBA.OGQL_TCK_RESULTS (CASE_ID, FEATURE_PATH, SCENARIO, STATUS, DETAIL)
            values (_case_id, _feature_path, _scenario, 'SPARQL_FAIL',
                    concat (__SQL_STATE, ': ', __SQL_MESSAGE));
          return;
        };
      exec (sparql);
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
  declare _case_id, _total, _done integer;
  declare _feature_path, _scenario, _query_text varchar;

  _total := 0;
  _done := 0;

  for (select CASE_ID, FEATURE_PATH, SCENARIO, QUERY_TEXT from DB.DBA.OGQL_TCK_CASES order by CASE_ID) do
    {
      _total := _total + 1;
      DB.DBA.OGQL_TCK_RUN_CASE (_case_id, _feature_path, _scenario, _query_text, _compile_reads);
      if (mod (_total, 10) = 0)
        {
          _done := _done + 10;
          dbg_obj_print (concat ('Progress: ', cast (_done as varchar), ' of ', cast (_total as varchar)));
        }
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
     where STATUS in ('TRANSLATE_FAIL', 'SPARQL_FAIL')
     order by CASE_ID);
}
;
