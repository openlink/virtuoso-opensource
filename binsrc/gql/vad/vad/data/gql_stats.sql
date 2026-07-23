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
--  openGQL: GQL for Virtuoso - Observability (logging, timing, metrics)
--
--  Provides opt-in, low-overhead observability at the GQL translation layer:
--    - Structured logging of GQL input, translated SPARQL, outcome, timings
--    - Lightweight counters (total requests, errors by code family, timing)
--    - DB.DBA.GQL_STATS() for scraping/dashboards
--    - DB.DBA.GQL_EXPLAIN() for translated SPARQL + execution plan
--
--  All features are off by default and cheap when off.  Enable with:
--    registry_set ('__opengql_stats_enabled', 'on');   -- counters + timing
--    registry_set ('__opengql_log_enabled', 'on');      -- structured logging
--    registry_set ('__opengql_log_bodies', 'on');       -- log GQL/SPARQL text
--    registry_set ('__opengql_log_truncate', '2000');   -- max body length
--
--  Primary interface:
--    DB.DBA.GQL_STATS()               -- returns counters as a vector
--    DB.DBA.GQL_STATS_RESET()         -- zeros all counters
--    DB.DBA.GQL_STATS_RECORD(...)     -- called by GQL_RUN/GQL_TO_SPARQL
--    DB.DBA.GQL_LOG_REQUEST(...)      -- logs a request to the server log
--    DB.DBA.GQL_EXPLAIN(query, graph?) -- returns translated SPARQL + plan
--

----------------------------------------------------------------------
-- Stats table: persistent counters survive server restarts.
-- The table is small (one row per error-code family + aggregate rows).
----------------------------------------------------------------------

create table DB.DBA.GQL_STATS_COUNTERS (
    GS_COUNTER varchar not null primary key,
    GS_VALUE integer not null,
    GS_TOTAL_TIME bigint not null,   -- cumulative msec for timing counters
    GS_MIN_TIME integer not null,    -- min msec (0 = not yet set)
    GS_MAX_TIME integer not null     -- max msec
)
;

-- Bootstrap: the counters table starts empty.  Counter rows are created
-- on demand by GQL_STATS_INCREMENT and GQL_STATS_RECORD_TIMING (which
-- both check existence and insert if missing).  GQL_STATS_RESET creates
-- the standard counter rows.  This avoids bootstrap compiler issues with
-- complex PL constructs in the init section.

----------------------------------------------------------------------
-- GQL_STATS_ENABLED / GQL_LOG_ENABLED: cheap flag checks.
-- These are called on every request, so they must be fast.
-- We cache the registry value on the connection to avoid a registry
-- lookup per request.  The cache is invalidated by GQL_STATS_SET_FLAG.
----------------------------------------------------------------------

create procedure DB.DBA.GQL_STATS_ENABLED ()
{
  declare cached varchar;
  cached := connection_get ('__gql_stats_enabled');
  if (cached is not null)
    {
      if (cached = 'on')
        return 1;
      return 0;
    }
  cached := coalesce (registry_get ('__opengql_stats_enabled'), 'off');
  connection_set ('__gql_stats_enabled', cached);
  if (cached = 'on')
    return 1;
  return 0;
}
;

create procedure DB.DBA.GQL_LOG_ENABLED ()
{
  declare cached varchar;
  cached := connection_get ('__gql_log_enabled');
  if (cached is not null)
    {
      if (cached = 'on')
        return 1;
      return 0;
    }
  cached := coalesce (registry_get ('__opengql_log_enabled'), 'off');
  connection_set ('__gql_log_enabled', cached);
  if (cached = 'on')
    return 1;
  return 0;
}
;

create procedure DB.DBA.GQL_LOG_BODIES_ENABLED ()
{
  declare cached varchar;
  cached := connection_get ('__gql_log_bodies');
  if (cached is not null)
    {
      if (cached = 'on')
        return 1;
      return 0;
    }
  cached := coalesce (registry_get ('__opengql_log_bodies'), 'off');
  connection_set ('__gql_log_bodies', cached);
  if (cached = 'on')
    return 1;
  return 0;
}
;

create procedure DB.DBA.GQL_LOG_TRUNCATE ()
{
  declare cached varchar;
  declare n integer;
  cached := connection_get ('__gql_log_truncate');
  if (cached is not null)
    {
      n := atoi (cached);
      if (n > 0)
        { return n; }
    }
  cached := coalesce (registry_get ('__opengql_log_truncate'), '2000');
  connection_set ('__gql_log_truncate', cached);
  n := atoi (cached);
  if (n <= 0)
    { n := 2000; }
  return n;
}
;

-- Call this after changing any registry flag to invalidate the
-- connection-level cache.  This is NOT automatic across connections;
-- the caller should reconnect or call this after setting flags.
create procedure DB.DBA.GQL_STATS_SET_FLAG (in flag varchar, in value varchar)
{
  registry_set (flag, value);
  connection_set ('__gql_stats_enabled', null);
  connection_set ('__gql_log_enabled', null);
  connection_set ('__gql_log_bodies', null);
  connection_set ('__gql_log_truncate', null);
}
;

----------------------------------------------------------------------
-- GQL_STATS_INCREMENT: atomically increment a counter.
----------------------------------------------------------------------

create procedure DB.DBA.GQL_STATS_INCREMENT (in counter varchar, in delta integer := 1)
{
  -- Use a merge-style upsert to be safe against concurrent calls.
  -- The table is tiny (13 rows) so this is cheap.
  if (exists (select 1 from DB.DBA.GQL_STATS_COUNTERS where GS_COUNTER = counter))
    {
      update DB.DBA.GQL_STATS_COUNTERS set GS_VALUE = GS_VALUE + delta
        where GS_COUNTER = counter;
    }
  else
    {
      insert into DB.DBA.GQL_STATS_COUNTERS (GS_COUNTER, GS_VALUE, GS_TOTAL_TIME, GS_MIN_TIME, GS_MAX_TIME)
        values (counter, delta, 0, 0, 0);
    }
}
;

----------------------------------------------------------------------
-- GQL_STATS_RECORD_TIMING: record a timing sample.
-- Updates total, count, min, max for the given timing counter.
----------------------------------------------------------------------

create procedure DB.DBA.GQL_STATS_RECORD_TIMING (in counter_prefix varchar, in elapsed_msec integer)
{
  declare total_name, count_name varchar;
  total_name := counter_prefix || '_total';
  count_name := counter_prefix || '_count';
  -- Update the total time
  if (exists (select 1 from DB.DBA.GQL_STATS_COUNTERS where GS_COUNTER = total_name))
    {
      update DB.DBA.GQL_STATS_COUNTERS set GS_TOTAL_TIME = GS_TOTAL_TIME + elapsed_msec
        where GS_COUNTER = total_name;
    }
  else
    {
      insert into DB.DBA.GQL_STATS_COUNTERS (GS_COUNTER, GS_VALUE, GS_TOTAL_TIME, GS_MIN_TIME, GS_MAX_TIME)
        values (total_name, 0, elapsed_msec, 0, 0);
    }
  -- Update the count + min + max
  if (exists (select 1 from DB.DBA.GQL_STATS_COUNTERS where GS_COUNTER = count_name))
    {
      update DB.DBA.GQL_STATS_COUNTERS
        set GS_VALUE = GS_VALUE + 1,
            GS_MIN_TIME = case when GS_MIN_TIME = 0 or elapsed_msec < GS_MIN_TIME then elapsed_msec else GS_MIN_TIME end,
            GS_MAX_TIME = case when elapsed_msec > GS_MAX_TIME then elapsed_msec else GS_MAX_TIME end
        where GS_COUNTER = count_name;
    }
  else
    {
      insert into DB.DBA.GQL_STATS_COUNTERS (GS_COUNTER, GS_VALUE, GS_TOTAL_TIME, GS_MIN_TIME, GS_MAX_TIME)
        values (count_name, 1, 0, elapsed_msec, elapsed_msec);
    }
}
;

----------------------------------------------------------------------
-- GQL_STATS_CLASSIFY_ERROR: map a SQLSTATE to an error-code family.
-- Returns one of: 'errors_parse', 'errors_translate', 'errors_scope',
-- 'errors_exec', 'errors_dml', 'errors_other'.
----------------------------------------------------------------------

create procedure DB.DBA.GQL_STATS_CLASSIFY_ERROR (in err_state varchar)
{
  if (err_state is null)
    { return 'errors_other'; }
  -- GQ0xx: lexer/parser errors
  if (length (err_state) >= 3 and subseq (err_state, 0, 3) = 'GQ0')
    { return 'errors_parse'; }
  -- GQ1xx: endpoint/plugin errors
  if (length (err_state) >= 3 and subseq (err_state, 0, 3) = 'GQ1')
    { return 'errors_other'; }
  -- G2xxx: semantic errors
  if (length (err_state) >= 2 and subseq (err_state, 0, 2) = 'G2')
    { return 'errors_translate'; }
  -- G3xxx: scope/translate errors
  if (length (err_state) >= 2 and subseq (err_state, 0, 2) = 'G3')
    { return 'errors_scope'; }
  -- G4xxx: exec/DML errors
  if (length (err_state) >= 2 and subseq (err_state, 0, 2) = 'G4')
    { return 'errors_dml'; }
  -- SP030: SPARQL syntax errors (from the SPARQL engine after translation)
  if (err_state = 'SP030')
    { return 'errors_translate'; }
  -- S1TAT: timeout
  if (err_state = 'S1TAT')
    { return 'errors_exec'; }
  -- 42xxx, 37xxx: SQL errors from execution
  if (length (err_state) >= 2 and (subseq (err_state, 0, 2) = '42' or subseq (err_state, 0, 2) = '37'))
    { return 'errors_exec'; }
  return 'errors_other';
}
;

----------------------------------------------------------------------
-- GQL_STATS_RECORD: record a completed request.
-- Called by GQL_PARAMS and GQL_TO_SPARQL after each request.
-- Parameters:
--   outcome      = 'ok' or 'error'
--   err_state     = SQLSTATE on error, null on success
--   translate_ms = translation time in msec
--   execute_ms   = execution time in msec (0 for translation-only calls)
----------------------------------------------------------------------

create procedure DB.DBA.GQL_STATS_RECORD (in outcome varchar, in err_state varchar := null, in translate_ms integer := 0, in execute_ms integer := 0)
{
  if (not DB.DBA.GQL_STATS_ENABLED ())
    { return; }

  DB.DBA.GQL_STATS_INCREMENT ('requests_total');
  if (outcome = 'ok')
    { DB.DBA.GQL_STATS_INCREMENT ('requests_ok'); }
  else
    {
      declare family varchar;
      DB.DBA.GQL_STATS_INCREMENT ('requests_error');
      family := DB.DBA.GQL_STATS_CLASSIFY_ERROR (err_state);
      DB.DBA.GQL_STATS_INCREMENT (family);
    }

  if (translate_ms > 0)
    { DB.DBA.GQL_STATS_RECORD_TIMING ('time_translate', translate_ms); }
  if (execute_ms > 0)
    { DB.DBA.GQL_STATS_RECORD_TIMING ('time_execute', execute_ms); }
}
;

----------------------------------------------------------------------
-- GQL_LOG_REQUEST: structured logging of a GQL request.
-- Writes to the server log via log_message.
-- Body logging (GQL text, SPARQL text) is separately toggleable.
----------------------------------------------------------------------

create procedure DB.DBA.GQL_LOG_REQUEST (in _gql varchar, in _sparql varchar, in outcome varchar, in err_state varchar := null, in msg varchar := null, in translate_ms integer := 0, in execute_ms integer := 0)
{
  declare max_len integer;
  declare gql_log, sparql_log varchar;

  if (not DB.DBA.GQL_LOG_ENABLED ())
    { return; }

  max_len := DB.DBA.GQL_LOG_TRUNCATE ();

  -- Build the log line.  Always log the outcome + timings; log bodies only
  -- if __opengql_log_bodies is on.
  if (DB.DBA.GQL_LOG_BODIES_ENABLED ())
    {
      if (_gql is not null and length (_gql) > max_len)
        { gql_log := subseq (_gql, 0, max_len) || '...(' || cast (length (_gql) as varchar) || ' chars)'; }
      else
        { gql_log := _gql; }
      if (_sparql is not null and length (_sparql) > max_len)
        { sparql_log := subseq (_sparql, 0, max_len) || '...(' || cast (length (_sparql) as varchar) || ' chars)'; }
      else
        { sparql_log := _sparql; }
    }
  else
    {
      -- Without bodies, log only lengths (privacy-safe)
      gql_log := '<' || cast (coalesce (length (_gql), 0) as varchar) || ' chars>';
      sparql_log := '<' || cast (coalesce (length (_sparql), 0) as varchar) || ' chars>';
    }

  if (outcome = 'ok')
    {
      log_message (sprintf ('openGQL OK translate=%dms execute=%dms gql=%s sparql=%s',
        translate_ms, execute_ms, gql_log, sparql_log));
    }
  else
    {
      log_message (sprintf ('openGQL ERROR %s %s translate=%dms execute=%dms gql=%s sparql=%s',
        coalesce (err_state, '???'), coalesce (msg, ''), translate_ms, execute_ms,
        gql_log, sparql_log));
    }
}
;

----------------------------------------------------------------------
-- GQL_STATS: return current counters as a result set.
-- Returns one row per counter with: counter, value, total_time, min, max, avg.
----------------------------------------------------------------------

create procedure DB.DBA.GQL_STATS ()
{
  declare result any;
  declare rows any;
  declare i integer;
  result := vector ();
  whenever sqlstate '*' goto stats_done;
  for select GS_COUNTER, GS_VALUE, GS_TOTAL_TIME, GS_MIN_TIME, GS_MAX_TIME
    from DB.DBA.GQL_STATS_COUNTERS order by GS_COUNTER do
    {
      declare avg_ms integer;
      declare row_vec any;
      avg_ms := case when GS_VALUE > 0 then GS_TOTAL_TIME / GS_VALUE else 0 end;
      row_vec := vector (
        GS_COUNTER, GS_VALUE, GS_TOTAL_TIME, GS_MIN_TIME, GS_MAX_TIME, avg_ms
      );
      result := vector_concat (result, vector (row_vec));
    }
  stats_done:
  return result;
}
;

----------------------------------------------------------------------
-- GQL_STATS_RESET: zero all counters.
----------------------------------------------------------------------

create procedure DB.DBA.GQL_STATS_RESET ()
{
  -- Delete all existing rows, then insert the standard counter rows.
  delete from DB.DBA.GQL_STATS_COUNTERS;
  insert into DB.DBA.GQL_STATS_COUNTERS (GS_COUNTER, GS_VALUE, GS_TOTAL_TIME, GS_MIN_TIME, GS_MAX_TIME) values ('requests_total', 0, 0, 0, 0);
  insert into DB.DBA.GQL_STATS_COUNTERS (GS_COUNTER, GS_VALUE, GS_TOTAL_TIME, GS_MIN_TIME, GS_MAX_TIME) values ('requests_ok', 0, 0, 0, 0);
  insert into DB.DBA.GQL_STATS_COUNTERS (GS_COUNTER, GS_VALUE, GS_TOTAL_TIME, GS_MIN_TIME, GS_MAX_TIME) values ('requests_error', 0, 0, 0, 0);
  insert into DB.DBA.GQL_STATS_COUNTERS (GS_COUNTER, GS_VALUE, GS_TOTAL_TIME, GS_MIN_TIME, GS_MAX_TIME) values ('errors_parse', 0, 0, 0, 0);
  insert into DB.DBA.GQL_STATS_COUNTERS (GS_COUNTER, GS_VALUE, GS_TOTAL_TIME, GS_MIN_TIME, GS_MAX_TIME) values ('errors_translate', 0, 0, 0, 0);
  insert into DB.DBA.GQL_STATS_COUNTERS (GS_COUNTER, GS_VALUE, GS_TOTAL_TIME, GS_MIN_TIME, GS_MAX_TIME) values ('errors_scope', 0, 0, 0, 0);
  insert into DB.DBA.GQL_STATS_COUNTERS (GS_COUNTER, GS_VALUE, GS_TOTAL_TIME, GS_MIN_TIME, GS_MAX_TIME) values ('errors_exec', 0, 0, 0, 0);
  insert into DB.DBA.GQL_STATS_COUNTERS (GS_COUNTER, GS_VALUE, GS_TOTAL_TIME, GS_MIN_TIME, GS_MAX_TIME) values ('errors_dml', 0, 0, 0, 0);
  insert into DB.DBA.GQL_STATS_COUNTERS (GS_COUNTER, GS_VALUE, GS_TOTAL_TIME, GS_MIN_TIME, GS_MAX_TIME) values ('errors_other', 0, 0, 0, 0);
  insert into DB.DBA.GQL_STATS_COUNTERS (GS_COUNTER, GS_VALUE, GS_TOTAL_TIME, GS_MIN_TIME, GS_MAX_TIME) values ('time_translate_total', 0, 0, 0, 0);
  insert into DB.DBA.GQL_STATS_COUNTERS (GS_COUNTER, GS_VALUE, GS_TOTAL_TIME, GS_MIN_TIME, GS_MAX_TIME) values ('time_execute_total', 0, 0, 0, 0);
  insert into DB.DBA.GQL_STATS_COUNTERS (GS_COUNTER, GS_VALUE, GS_TOTAL_TIME, GS_MIN_TIME, GS_MAX_TIME) values ('time_translate_count', 0, 0, 0, 0);
  insert into DB.DBA.GQL_STATS_COUNTERS (GS_COUNTER, GS_VALUE, GS_TOTAL_TIME, GS_MIN_TIME, GS_MAX_TIME) values ('time_execute_count', 0, 0, 0, 0);
  return 1;
}
;

----------------------------------------------------------------------
-- GQL_EXPLAIN: return translated SPARQL + execution plan for a GQL query.
-- Useful for support/debugging.  Returns a vector:
--   vector(sparql_text, explain_report)
-- The explain_report is the SPARQL compiler's internal explanation.
----------------------------------------------------------------------

create procedure DB.DBA.GQL_EXPLAIN (in _query varchar, in _graph varchar := null)
{
  declare sparql_str varchar;
  declare explain_report varchar;
  declare state, msg varchar;
  declare meta, rset any;

  -- Translate the GQL to SPARQL
  sparql_str := DB.DBA.GQL_TO_SPARQL (_query, _graph);

  if (sparql_str is null or trim (sparql_str) = '')
    { return vector ('', 'No SPARQL generated (DML-only query)'); }

  -- Get the SPARQL compiler's explanation
  whenever sqlstate '*' goto explain_err;
  explain_report := sparql_explain (sparql_str);
  return vector (sparql_str, explain_report);

explain_err:
  return vector (sparql_str, sprintf ('EXPLAIN error: %s %s', __SQL_STATE, __SQL_MESSAGE));
}
;
