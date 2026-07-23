----------------------------------------------------------------------
-- GQL PL Procedures
-- Virtuoso/PL implementations for GQL functions that have no native BIF.
-- These are called via bif: prefix from generated SPARQL.
----------------------------------------------------------------------

----------------------------------------------------------------------
-- Hyperbolic functions (no BIF exists)
-- sinh(x) = (e^x - e^(-x)) / 2
-- cosh(x) = (e^x + e^(-x)) / 2
-- tanh(x) = sinh(x) / cosh(x)
----------------------------------------------------------------------

create procedure DB.DBA.GQL_SINH (in x double precision)
{
  return (exp(x) - exp(-x)) / 2.0;
}
;

create procedure DB.DBA.GQL_COSH (in x double precision)
{
  return (exp(x) + exp(-x)) / 2.0;
}
;

create procedure DB.DBA.GQL_TANH (in x double precision)
{
  declare e2x double precision;
  e2x := exp(2.0 * x);
  return (e2x - 1.0) / (e2x + 1.0);
}
;

----------------------------------------------------------------------
-- CAST wrapper
-- Dispatches to appropriate conversion based on target type name.
-- Called as: bif:GQL_CAST(value, 'INTEGER')
----------------------------------------------------------------------

create procedure DB.DBA.GQL_CAST (in _val any, in _target_type varchar)
{
  declare tt varchar;
  tt := upper(_target_type);

  if (tt = 'INTEGER' or tt = 'INT')
    return atoi (cast (_val as varchar));
  if (tt = 'STRING' or tt = 'VARCHAR' or tt = 'TEXT')
    return cast (_val as varchar);
  if (tt = 'BOOLEAN' or tt = 'BOOL')
    return case when _val is null then null when _val then 1 else 0 end;
  if (tt = 'FLOAT' or tt = 'REAL')
    return atof (cast (_val as varchar));
  if (tt = 'DOUBLE' or tt = 'DOUBLE PRECISION')
    return atod (cast (_val as varchar));
  if (tt = 'DATE')
    return stringdate (cast (_val as varchar));
  if (tt = 'TIME')
    return stringtime (cast (_val as varchar));
  if (tt = 'DATETIME' or tt = 'TIMESTAMP')
    return stringdate (cast (_val as varchar));
  if (tt = 'DECIMAL' or tt = 'NUMERIC')
    return atod (cast (_val as varchar));

  signal ('GQ005', sprintf ('Unsupported CAST target type: %s', _target_type));
}
;

----------------------------------------------------------------------
-- DURATION functions
-- DURATION(string) parses ISO 8601 duration format PnYnMnDTnHnMnS
-- DURATION_BETWEEN(a, b) returns the duration between two datetimes
----------------------------------------------------------------------

create procedure DB.DBA.GQL_DURATION (in _dur_str varchar)
{
  declare s varchar;
  declare sign integer;
  declare yrs, mos, dys, hrs, mns, secs double precision;
  declare in_time integer;
  declare num_str varchar;
  declare ch varchar;
  declare i, len integer;

  s := trim(_dur_str);
  sign := 1;
  if (length(s) > 0 and subseq(s, 0, 1) = '-')
    { sign := -1; s := subseq(s, 1); }
  if (length(s) < 1 or subseq(s, 0, 1) <> 'P')
    signal ('GQ005', sprintf('Invalid duration format: %s', _dur_str));
  s := subseq(s, 1);
  len := length(s);
  yrs := 0; mos := 0; dys := 0; hrs := 0; mns := 0; secs := 0;
  in_time := 0;
  num_str := '';
  i := 0;
  while (i < len)
    {
      ch := subseq(s, i, i+1);
      if (ch = 'T') { in_time := 1; }
      else if (ch >= '0' and ch <= '9' or ch = '.')
        num_str := concat(num_str, ch);
      else
        {
          if (num_str = '' and ch <> 'T')
            signal ('GQ005', sprintf('Invalid duration format at pos %d: %s', i, _dur_str));
          if (ch = 'Y' and not in_time) yrs := atof(num_str);
          else if (ch = 'M' and not in_time) mos := atof(num_str);
          else if (ch = 'D' and not in_time) dys := atof(num_str);
          else if (ch = 'H' and in_time) hrs := atof(num_str);
          else if (ch = 'M' and in_time) mns := atof(num_str);
          else if (ch = 'S' and in_time) secs := atof(num_str);
          else signal ('GQ005', sprintf('Invalid duration unit: %s', ch));
          num_str := '';
        }
      i := i + 1;
    }
  return vector (sign * yrs, sign * mos, sign * dys, sign * hrs, sign * mns, sign * secs);
}
;

create procedure DB.DBA.GQL_DURATION_BETWEEN (in _start any, in _end any)
{
  declare diff integer;
  diff := datediff('second', _start, _end);
  return diff;
}
;

----------------------------------------------------------------------
-- Aggregate functions
-- These operate on a vector of values collected by the translator.
-- The translator generates a sub-SELECT to collect values into a list,
-- then calls these PL procedures.
--
-- Note: STDDEV, STDDEV_SAMP, STDDEV_POP are native SQL user-defined
-- aggregates (create aggregate DB.DBA.STDDEV...), accessible via sql:
-- prefix in SPARQL. No PL wrapper needed.
----------------------------------------------------------------------

create procedure DB.DBA.GQL_PERCENTILE_CONT (in _vals any, in _p double precision)
{
  declare n integer;
  declare sorted any;
  declare rank, lo, hi double precision;
  declare lo_val, hi_val double precision;
  declare i, j integer;
  declare tmp any;
  n := length(_vals);
  if (n < 1) return null;
  if (_p < 0 or _p > 1) signal ('GQ005', 'Percentile must be between 0 and 1');
  sorted := _vals;
  for (i := 1; i < n; i := i + 1)
    {
      tmp := aref(sorted, i);
      j := i - 1;
      while (j >= 0 and cast(aref(sorted, j) as double precision) > cast(tmp as double precision))
        {
          aset(sorted, j+1, aref(sorted, j));
          j := j - 1;
        }
      aset(sorted, j+1, tmp);
    }
  if (n = 1) return cast(aref(sorted, 0) as double precision);
  rank := _p * (n - 1);
  lo := floor(rank);
  hi := ceiling(rank);
  if (lo = hi) return cast(aref(sorted, lo) as double precision);
  lo_val := cast(aref(sorted, lo) as double precision);
  hi_val := cast(aref(sorted, hi) as double precision);
  return lo_val + (hi_val - lo_val) * (rank - lo);
}
;

create procedure DB.DBA.GQL_PERCENTILE_DISC (in _vals any, in _p double precision)
{
  declare n integer;
  declare sorted any;
  declare idx integer;
  declare i, j integer;
  declare tmp any;
  n := length(_vals);
  if (n < 1) return null;
  if (_p < 0 or _p > 1) signal ('GQ005', 'Percentile must be between 0 and 1');
  sorted := _vals;
  for (i := 1; i < n; i := i + 1)
    {
      tmp := aref(sorted, i);
      j := i - 1;
      while (j >= 0 and cast(aref(sorted, j) as double precision) > cast(tmp as double precision))
        {
          aset(sorted, j+1, aref(sorted, j));
          j := j - 1;
        }
      aset(sorted, j+1, tmp);
    }
  idx := ceiling(_p * n) - 1;
  if (idx < 0) idx := 0;
  if (idx >= n) idx := n - 1;
  return cast(aref(sorted, idx) as double precision);
}
;

----------------------------------------------------------------------
-- UNNEST helper: runtime array expansion
-- Returns a result set with (value, index) columns.
-- Used by GQL_GEN_UNNEST for variable/complex expressions and
-- by FOR ... WITH ORDINALITY (shared infrastructure, see §7).
-- Called via sql: prefix from generated SPARQL.
----------------------------------------------------------------------

create procedure DB.DBA.GQL_UNNEST_PL (in _arr any)
{
  declare i integer;
  declare _val any;
  declare _idx integer;
  _idx := 0;
  result_names (_val, _idx);
  if (isarray (_arr))
    {
      for (i := 0; i < length (_arr); i := i + 1)
        {
          _val := aref (_arr, i);
          _idx := i;
          result (_val, _idx);
        }
    }
}
;

----------------------------------------------------------------------
-- GQL list TRIM: TRIM(list, n) returns the first n elements of the list
-- (i.e. the list truncated to length n). n <= 0 yields an empty list;
-- n >= length(list) yields the whole list. The list is a Virtuoso vector
-- (see GQL_GEN_LIST_VECTOR); the result is a vector, so it composes with
-- CARDINALITY/SIZE. A PL procedure, so it is called via the sql: prefix
-- from generated SPARQL (bif: is only for built-in/C functions).
----------------------------------------------------------------------

create procedure DB.DBA.GQL_LIST_TRIM (in _list any, in _n integer)
{
  declare _len, i integer;
  declare _out any;
  if (not isarray (_list))
    return vector ();
  _len := length (_list);
  if (_n <= 0)
    return vector ();
  if (_n >= _len)
    return _list;
  _out := vector ();
  for (i := 0; i < _n; i := i + 1)
    _out := vector_concat (_out, vector (aref (_list, i)));
  return _out;
}
;
