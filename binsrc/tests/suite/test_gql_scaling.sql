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
--  GQL for Virtuoso - front-end scaling tests
--
--  The GQL front end (tokenize, parse, translate) must cost time linear in
--  the size of the statement.  Each test times one stage on an INSERT of
--  N nodes and on one of 4N nodes, in the same run, and asserts that the
--  larger input costs less than 8 times the smaller: a linear stage
--  measures about 4, a quadratic one about 16.  The ratio, not an absolute
--  time, is what is asserted, so the result does not depend on the
--  machine.  A fourth test does the same for one long string literal
--  (N characters against 4N), whose value the tokenizer must also build in
--  linear time.  The last two tests compare per-item costs that should be
--  of the same order: classifying an identifier that is not a keyword
--  against one that is, and tokenizing a long identifier against a string
--  literal of the same length.
--
--  Run via isql: isql <host>:<port> dba dba test_gql_scaling.sql
--

ECHO "STARTED: GQL front-end scaling tests\n";

SET ARGV[0] 0;
SET ARGV[1] 0;

create procedure DB.DBA.GQL_SCALE_INSERT_TEXT (in _n integer) returns varchar
{
  declare _ses any;
  declare _i integer;
  _ses := string_output ();
  http ('INSERT ', _ses);
  for (_i := 0; _i < _n; _i := _i + 1)
    {
      if (_i > 0)
        http (', ', _ses);
      http (sprintf ('(:Review { id: ''r%d'', stars: %d, text: ''review %d'' })',
        _i, mod (_i, 5) + 1, _i), _ses);
    }
  return string_output_string (_ses);
}
;

-- Best of _reps wall-clock milliseconds for one stage over an N-node INSERT.
create procedure DB.DBA.GQL_SCALE_STAGE_MS (in _stage varchar, in _n integer, in _reps integer) returns integer
{
  declare _q varchar;
  declare _tokens, _r any;
  declare _rep, _it, _iters, _t0, _dt, _best integer;
  if (_stage = 'string')
    _q := concat ('INSERT (:Doc { body: ''', repeat ('abcdefghij', _n / 10), ''' })');
  else
    _q := DB.DBA.GQL_SCALE_INSERT_TEXT (_n);
  _tokens := DB.DBA.GQL_TOKENIZE (_q);
  -- One long literal tokenizes in about a millisecond, so time several to
  -- stay clear of the clock's resolution.
  _iters := case when _stage = 'string' then 5 else 1 end;
  _best := 1000000000;
  for (_rep := 0; _rep < _reps; _rep := _rep + 1)
    {
      _t0 := msec_time ();
      for (_it := 0; _it < _iters; _it := _it + 1)
        {
          if (_stage = 'tokenize' or _stage = 'string')
            _r := DB.DBA.GQL_TOKENIZE (_q);
          else if (_stage = 'parse')
            _r := DB.DBA.GQL_PARSE (_tokens);
          else
            _r := DB.DBA.GQL_TO_SPARQL (_q, 'urn:gql:scale');
        }
      _dt := msec_time () - _t0;
      if (_dt < _best)
        _best := _dt;
    }
  return _best;
}
;

-- 1 if the stage is linear (4x input costs < 8x time), else 0.  The
-- measured times are left in connection variable gql_scale_detail.
create procedure DB.DBA.GQL_SCALE_IS_LINEAR (in _stage varchar, in _n integer) returns integer
{
  declare _small, _large integer;
  declare _ratio double precision;
  _small := DB.DBA.GQL_SCALE_STAGE_MS (_stage, _n, 3);
  _large := DB.DBA.GQL_SCALE_STAGE_MS (_stage, 4 * _n, 2);
  -- Below 1 ms the ratio is clock noise; count it as 1 ms.
  if (_small < 1)
    _small := 1;
  _ratio := cast (_large as double precision) / _small;
  connection_set ('gql_scale_detail',
    sprintf ('%s: %d %s %d ms, %d %s %d ms, ratio %.1f',
      _stage, _n, case when _stage = 'string' then 'chars' else 'nodes' end, _small,
      4 * _n, case when _stage = 'string' then 'chars' else 'nodes' end, _large, _ratio));
  if (_ratio < 8.0)
    return 1;
  return 0;
}
;

select 0;
select DB.DBA.GQL_SCALE_IS_LINEAR ('tokenize', 30);
ECHO $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": GQL_TOKENIZE cost is linear in statement size\n";
select connection_get ('gql_scale_detail');
ECHO "    " $LAST[1] "\n";

select 0;
select DB.DBA.GQL_SCALE_IS_LINEAR ('parse', 30);
ECHO $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": GQL_PARSE cost is linear in statement size\n";
select connection_get ('gql_scale_detail');
ECHO "    " $LAST[1] "\n";

select 0;
select DB.DBA.GQL_SCALE_IS_LINEAR ('translate', 30);
ECHO $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": GQL_TO_SPARQL cost is linear in statement size\n";
select connection_get ('gql_scale_detail');
ECHO "    " $LAST[1] "\n";

select 0;
select DB.DBA.GQL_SCALE_IS_LINEAR ('string', 20000);
ECHO $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": GQL_TOKENIZE builds a long string literal in linear time\n";
select connection_get ('gql_scale_detail');
ECHO "    " $LAST[1] "\n";

-- 1 if two workloads timed back to back cost within 3x of each other.
create procedure DB.DBA.GQL_SCALE_SAME_ORDER (in _what varchar) returns integer
{
  declare _i, _t0, _a, _b integer;
  declare _r any;
  declare _qi, _qs, _la, _lb varchar;
  if (_what = 'keyword')
    {
      _la := 'keyword MATCH'; _lb := 'identifier stars';
      _t0 := msec_time ();
      for (_i := 0; _i < 20000; _i := _i + 1) _r := DB.DBA.GQL_KEYWORD ('MATCH');
      _a := msec_time () - _t0;
      _t0 := msec_time ();
      for (_i := 0; _i < 20000; _i := _i + 1) _r := DB.DBA.GQL_KEYWORD ('stars');
      _b := msec_time () - _t0;
    }
  else
    {
      _la := '4000-char string'; _lb := '4000-char identifier';
      _qs := concat ('MATCH (n) RETURN ''', repeat ('abcdefghij', 400), '''');
      _qi := concat ('MATCH (n) RETURN n.', repeat ('abcdefghij', 400));
      _t0 := msec_time ();
      for (_i := 0; _i < 20; _i := _i + 1) _r := DB.DBA.GQL_TOKENIZE (_qs);
      _a := msec_time () - _t0;
      _t0 := msec_time ();
      for (_i := 0; _i < 20; _i := _i + 1) _r := DB.DBA.GQL_TOKENIZE (_qi);
      _b := msec_time () - _t0;
    }
  if (_a < 1)
    _a := 1;
  connection_set ('gql_scale_detail',
    sprintf ('%s %d ms, %s %d ms, ratio %.1f', _la, _a, _lb, _b, cast (_b as double precision) / _a));
  if (_b < 3 * _a)
    return 1;
  return 0;
}
;

select 0;
select DB.DBA.GQL_SCALE_SAME_ORDER ('keyword');
ECHO $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": GQL_KEYWORD classifies a non-keyword as cheaply as a keyword\n";
select connection_get ('gql_scale_detail');
ECHO "    " $LAST[1] "\n";

select 0;
select DB.DBA.GQL_SCALE_SAME_ORDER ('identifier');
ECHO $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": GQL_TOKENIZE scans an identifier as cheaply as a string literal\n";
select connection_get ('gql_scale_detail');
ECHO "    " $LAST[1] "\n";

ECHO "COMPLETED WITH " $ARGV[0] " FAILED, " $ARGV[1] " PASSED: GQL front-end scaling tests\n";
