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
--  GQL for Virtuoso - GQL_EXECUTE result tests
--
--  GQL_EXECUTE is the entry point the SQL scanner rewrites a leading GQL
--  keyword into, so it is what an ODBC/JDBC client runs.  It streams rows
--  with exec_result; these tests capture them by exec-ing the procedure call
--  and compare them with GQL_RUN, which returns the same rows as a vector.
--
--  Run via isql: isql <host>:<port> dba dba test_gql_exec.sql
--

ECHO "STARTED: GQL_EXECUTE tests\n";

SET ARGV[0] 0;
SET ARGV[1] 0;

sparql clear graph <urn:gql:exec>;

create procedure DB.DBA.GQL_EXEC_T_LOAD (in _n integer)
{
  declare _i integer;
  for (_i := 0; _i < _n; _i := _i + 1)
    DB.DBA.GQL_RUN (sprintf ('INSERT (:Item { id: ''i%03d'', grp: %d })', _i, mod (_i, 4)),
      'urn:gql:exec');
  commit work;
}
;

DB.DBA.GQL_EXEC_T_LOAD (40);

-- Rows GQL_EXECUTE streams for _q, captured by exec-ing the call.
create procedure DB.DBA.GQL_EXEC_T_ROWS (in _q varchar, in _g varchar, out _meta any) returns any
{
  declare _st, _msg varchar;
  declare _data any;
  _st := '00000'; _msg := '';
  exec ('DB.DBA.GQL_EXECUTE (?, ?)', _st, _msg, vector (_q, _g), 100000, _meta, _data);
  if (_st <> '00000')
    signal (_st, _msg);
  return _data;
}
;

-- X1: GQL_EXECUTE streams exactly the rows GQL_RUN returns.
create procedure DB.DBA.GQL_EXEC_T_SAME_ROWS (in _q varchar) returns integer
{
  declare _meta, _streamed, _returned any;
  _streamed := DB.DBA.GQL_EXEC_T_ROWS (_q, 'urn:gql:exec', _meta);
  _returned := DB.DBA.GQL_RUN (_q, 'urn:gql:exec');
  if (length (_streamed) > 0 and serialize (_streamed) = serialize (_returned))
    return 1;
  return 0;
}
;

select 0;
select DB.DBA.GQL_EXEC_T_SAME_ROWS ('MATCH (n:Item) RETURN n.id AS id, n.grp AS grp ORDER BY id');
ECHO $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": X1 GQL_EXECUTE streams the rows GQL_RUN returns (40 rows)\n";

-- X2: the column names reach the client.
create procedure DB.DBA.GQL_EXEC_T_COLUMNS () returns integer
{
  declare _meta, _rows any;
  _rows := DB.DBA.GQL_EXEC_T_ROWS ('MATCH (n:Item) WHERE n.grp = 1 RETURN n.id AS id, n.grp AS grp ORDER BY id',
    'urn:gql:exec', _meta);
  if (length (_rows) = 10 and aref (_meta, 0, 0, 0) = 'id' and aref (_meta, 0, 1, 0) = 'grp')
    return 1;
  return 0;
}
;

select 0;
select DB.DBA.GQL_EXEC_T_COLUMNS ();
ECHO $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": X2 GQL_EXECUTE returns the projected column names\n";

-- X3: an empty result is zero rows, with its column names.
create procedure DB.DBA.GQL_EXEC_T_EMPTY () returns integer
{
  declare _meta, _rows any;
  _rows := DB.DBA.GQL_EXEC_T_ROWS ('MATCH (n:Item) WHERE n.grp = 9 RETURN n.id AS id',
    'urn:gql:exec', _meta);
  -- exec () hands back 0, not an empty vector, when there are no rows.
  if ((not isarray (_rows) or length (_rows) = 0) and aref (_meta, 0, 0, 0) = 'id')
    return 1;
  return 0;
}
;

select 0;
select DB.DBA.GQL_EXEC_T_EMPTY ();
ECHO $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": X3 GQL_EXECUTE returns no rows for an empty result\n";

-- X4: a statement that translates to two SPARQL updates (SET, then REMOVE)
-- runs both, as GQL_RUN does.
create procedure DB.DBA.GQL_EXEC_T_COUNT (in _q varchar, in _g varchar) returns integer
{
  declare _r any;
  _r := DB.DBA.GQL_RUN (_q, _g);
  if (not isarray (_r))
    return 0;
  return length (_r);
}
;

create procedure DB.DBA.GQL_EXEC_T_TWO_UPDATES () returns varchar
{
  declare _st, _msg varchar;
  declare _meta, _data any;
  sparql clear graph <urn:gql:exec:two>;
  DB.DBA.GQL_RUN ('INSERT (:Person { name: ''t-a'', age: 1, x: 1 })', 'urn:gql:exec:two');
  commit work;
  _st := '00000'; _msg := '';
  exec ('DB.DBA.GQL_EXECUTE (?, ?)', _st, _msg,
    vector ('MATCH (n:Person { name: ''t-a'' }) SET n.age = 10 REMOVE n.x', 'urn:gql:exec:two'), 10, _meta, _data);
  commit work;
  if (_st <> '00000')
    return concat (_st, ' ', subseq (_msg, 0, 60));
  if (DB.DBA.GQL_EXEC_T_COUNT ('MATCH (n:Person { name: ''t-a'' }) WHERE n.age = 10 RETURN n', 'urn:gql:exec:two') = 1
      and DB.DBA.GQL_EXEC_T_COUNT ('MATCH (n:Person { name: ''t-a'' }) WHERE n.x IS NOT NULL RETURN n', 'urn:gql:exec:two') = 0)
    return 'ok';
  return 'not applied';
}
;

select 0;
select DB.DBA.GQL_EXEC_T_TWO_UPDATES ();
ECHO $IF $EQU $LAST[1] "ok" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": X4 GQL_EXECUTE runs both updates of SET ... REMOVE (" $LAST[1] ")\n";

ECHO "COMPLETED WITH " $ARGV[0] " FAILED, " $ARGV[1] " PASSED: GQL_EXECUTE tests\n";
