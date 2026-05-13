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
--  Full openCypher 2024.3 TCK query compatibility harness.
--
--  This file defines the database-side runner.  Populate
--  DB.DBA.OPENCYPHER_TCK_CASES with extract_tck_cases.py, then run
--  DB.DBA.OPENCYPHER_TCK_RUN().  By default callers should use translation-only
--  mode; generated SPARQL compilation is useful but can be expensive.
--

create procedure DB.DBA.OPENCYPHER_TCK_DROP_TABLE (in _table_name varchar)
{
  declare exit handler for sqlstate '*'
    {
      return;
    };
  exec (sprintf ('DROP TABLE %s', _table_name));
}
;

DB.DBA.OPENCYPHER_TCK_DROP_TABLE ('DB.DBA.OPENCYPHER_TCK_RESULTS');
DB.DBA.OPENCYPHER_TCK_DROP_TABLE ('DB.DBA.OPENCYPHER_TCK_CASES');

CREATE TABLE DB.DBA.OPENCYPHER_TCK_CASES
  (
    CASE_ID integer not null primary key,
    FEATURE_PATH varchar not null,
    FEATURE_NAME varchar not null,
    SCENARIO_LINE integer not null,
    SCENARIO_NAME varchar not null,
    QUERY_LINE integer not null,
    BLOCK_INDEX integer not null,
    PHASE varchar not null,
    CYPHER_QUERY long varchar not null
  )
;

CREATE TABLE DB.DBA.OPENCYPHER_TCK_RESULTS
  (
    CASE_ID integer not null primary key,
    FEATURE_PATH varchar not null,
    FEATURE_NAME varchar not null,
    SCENARIO_LINE integer not null,
    SCENARIO_NAME varchar not null,
    QUERY_LINE integer not null,
    BLOCK_INDEX integer not null,
    PHASE varchar not null,
    STATUS varchar not null,
    SQL_STATE varchar,
    MESSAGE long varchar,
    SPARQL_TEXT long varchar
  )
;

create procedure DB.DBA.OPENCYPHER_TCK_SPARQL_IS_READ (in _sparql long varchar)
{
  declare s varchar;
  s := ltrim (cast (_sparql as varchar));
  if (length (s) >= 7 and upper (subseq (s, 0, 7)) = 'SPARQL ')
    s := ltrim (subseq (s, 7));
  if (length (s) >= 7 and upper (subseq (s, 0, 7)) = 'DEFINE ')
    return 1;
  if (length (s) >= 7 and upper (subseq (s, 0, 7)) = 'PREFIX ')
    return 1;
  if (length (s) >= 5 and upper (subseq (s, 0, 5)) = 'BASE ')
    return 1;
  if (length (s) >= 7 and upper (subseq (s, 0, 7)) = 'SELECT ')
    return 1;
  if (length (s) >= 4 and upper (subseq (s, 0, 4)) = 'ASK ')
    return 1;
  if (length (s) >= 10 and upper (subseq (s, 0, 10)) = 'CONSTRUCT ')
    return 1;
  if (length (s) >= 9 and upper (subseq (s, 0, 9)) = 'DESCRIBE ')
    return 1;
  return 0;
}
;

create procedure DB.DBA.OPENCYPHER_TCK_RUN_CASE
  (
    in _case_id integer,
    in _feature_path varchar,
    in _feature_name varchar,
    in _scenario_line integer,
    in _scenario_name varchar,
    in _query_line integer,
    in _block_index integer,
    in _phase varchar,
    in _query long varchar,
    in _compile_reads integer := 0
  )
{
  declare state, msg varchar;
  declare meta, data any;
  declare sparql_text long varchar;
  declare status varchar;

  state := '00000';
  msg := null;
  sparql_text := null;
  status := null;

  if (length (_query) >= 29 and subseq (_query, 0, 29) = '__OPENCYPHER_TCK_QUERY_TOO_LARGE__')
    {
      status := 'HARNESS_SKIP_QUERY_TOO_LARGE';
      state := 'TCKSK';
      msg := _query;
      goto record_result;
    }

  exec ('SELECT DB.DBA.CYPHER_TO_SPARQL (?)',
        state, msg, vector (_query), 0, meta, data);

  if (state <> '00000')
    {
      status := 'TRANSLATE_FAIL';
      goto record_result;
    }

  if (data is null or length (data) = 0)
    {
      state := 'CYTCK';
      msg := 'CYPHER_TO_SPARQL returned no data';
      status := 'TRANSLATE_FAIL';
      goto record_result;
    }

  sparql_text := aref (aref (data, 0), 0);
  if (_compile_reads = 0)
    {
      status := 'TRANSLATE_OK';
      goto record_result;
    }

  if (DB.DBA.OPENCYPHER_TCK_SPARQL_IS_READ (sparql_text) = 0)
    {
      status := 'TRANSLATE_OK_UPDATE_NOT_COMPILED';
      goto record_result;
    }

  state := '00000';
  msg := null;
  exec (sparql_text, state, msg, vector (), 0, meta, data);
  if (state <> '00000')
    status := 'SPARQL_FAIL';
  else
    status := 'SPARQL_OK';

record_result:
  INSERT REPLACING DB.DBA.OPENCYPHER_TCK_RESULTS
    (CASE_ID, FEATURE_PATH, FEATURE_NAME, SCENARIO_LINE, SCENARIO_NAME,
     QUERY_LINE, BLOCK_INDEX, PHASE, STATUS, SQL_STATE, MESSAGE, SPARQL_TEXT)
  VALUES
    (_case_id, _feature_path, _feature_name, _scenario_line, _scenario_name,
     _query_line, _block_index, _phase, status, state, msg, sparql_text);
}
;

create procedure DB.DBA.OPENCYPHER_TCK_RUN (in _compile_reads integer := 0)
{
  declare cid, sline, qline, bidx integer;
  declare fpath, fname, sname, cphase varchar;
  declare q long varchar;
  declare cr cursor for
    select CASE_ID, FEATURE_PATH, FEATURE_NAME, SCENARIO_LINE, SCENARIO_NAME,
           QUERY_LINE, BLOCK_INDEX, PHASE, CYPHER_QUERY
      from DB.DBA.OPENCYPHER_TCK_CASES
     order by CASE_ID;

  DELETE FROM DB.DBA.OPENCYPHER_TCK_RESULTS;

  whenever not found goto done;
  open cr;
  while (1)
    {
      fetch cr into cid, fpath, fname, sline, sname, qline, bidx, cphase, q;
      DB.DBA.OPENCYPHER_TCK_RUN_CASE
        (cid, fpath, fname, sline, sname, qline, bidx, cphase, q, _compile_reads);
    }
done:
  close cr;
  return DB.DBA.OPENCYPHER_TCK_SUMMARY ();
}
;

create procedure DB.DBA.OPENCYPHER_TCK_SUMMARY ()
{
  declare out_s long varchar;
  declare total integer;
  total := (select count (*) from DB.DBA.OPENCYPHER_TCK_RESULTS);
  out_s := sprintf ('OPEN CYPHER 2024.3 TCK QUERY COMPATIBILITY: %d cases\n', total);
  for select STATUS as st, count (*) as cnt
        from DB.DBA.OPENCYPHER_TCK_RESULTS
       group by STATUS
       order by STATUS do
    {
      out_s := concat (out_s, sprintf ('%s: %d\n', st, cnt));
    }
  return out_s;
}
;

create procedure DB.DBA.OPENCYPHER_TCK_FAILURES (in _limit integer := 100)
{
  declare out_s long varchar;
  declare n integer;
  n := 0;
  out_s := '';
  for select CASE_ID as cid, FEATURE_PATH as fp, SCENARIO_LINE as sl,
             SCENARIO_NAME as sn, QUERY_LINE as ql, PHASE as ph,
             STATUS as st, SQL_STATE as ss, MESSAGE as msg
        from DB.DBA.OPENCYPHER_TCK_RESULTS
       where STATUS in ('TRANSLATE_FAIL', 'SPARQL_FAIL')
       order by CASE_ID do
    {
      if (n >= _limit)
        goto done;
      out_s := concat (out_s,
        sprintf ('#%d %s:%d query:%d [%s] %s %s %s\n',
                 cid, fp, sl, ql, ph, st, coalesce (ss, ''),
                 coalesce (msg, '')));
      n := n + 1;
    }
done:
  if (length (out_s) = 0)
    return 'No TRANSLATE_FAIL or SPARQL_FAIL rows';
  return out_s;
}
;

create procedure DB.DBA.OPENCYPHER_TCK_FEATURE_SUMMARY ()
{
  declare out_s long varchar;
  out_s := '';
  for select FEATURE_PATH as fp,
             sum (case when STATUS = 'SPARQL_OK' then 1 else 0 end) as ok_cnt,
             sum (case when STATUS = 'TRANSLATE_OK' then 1 else 0 end) as tr_ok_cnt,
             sum (case when STATUS = 'TRANSLATE_OK_UPDATE_NOT_COMPILED' then 1 else 0 end) as upd_cnt,
             sum (case when STATUS = 'TRANSLATE_FAIL' then 1 else 0 end) as tr_fail_cnt,
             sum (case when STATUS = 'SPARQL_FAIL' then 1 else 0 end) as sp_fail_cnt,
             count (*) as total_cnt
        from DB.DBA.OPENCYPHER_TCK_RESULTS
       group by FEATURE_PATH
       order by tr_fail_cnt desc, sp_fail_cnt desc, FEATURE_PATH do
    {
      out_s := concat (out_s,
        sprintf ('%s total=%d sparql_ok=%d translate_ok=%d update_not_compiled=%d translate_fail=%d sparql_fail=%d\n',
                 fp, total_cnt, ok_cnt, tr_ok_cnt, upd_cnt, tr_fail_cnt, sp_fail_cnt));
    }
  return out_s;
}
;
