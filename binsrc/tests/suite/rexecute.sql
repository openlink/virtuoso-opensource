--
--  rexecute.sql
--
--  $Id: rexecute.sql,v 1.14.10.1 2013/01/02 16:14:52 source Exp $
--
--  rexecute suite testing
--  
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--  
--  Copyright (C) 1998-2015 OpenLink Software
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
--  Start the test
--
echo BOTH "\nSTARTED: rexecute suite (rexecute.sql)\n";
SET ARGV[0] 0;
SET ARGV[1] 0;

create procedure test_retcodes(in dsn varchar)
{
  declare retcode integer;
  declare state, message varchar;

  retcode := rexecute(dsn, 'select * from rexecnonexistent', state, message);
  result_names(retcode, state, message);
  result(retcode, state, message);
};

create procedure test_params_exec(in dsn varchar)
{
  declare params varchar;
  declare n, rows_updated integer;
  declare data varchar;

  n := 1;
  while (n <= 10)
    {
      data := vector(n, sprintf('DATA %d', n));
      rexecute(dsn, 'insert into EXECTEST (ID, DATA) values (?, ?)', null, null, data, rows_updated);
      if (rows_updated <> 1)
	signal('PARUP', sprintf('bad row count %d (<>1)', rows_updated));
      n := n + 1;
    }
};

create procedure test_plain_select(in dsn varchar)
{
  declare r_id, n, n_cols integer;
  declare r_data, meta, resultset, resultrow varchar;

  rexecute(dsn, 'select ID, DATA from EXECTEST',
      null, null, null, n_cols, meta, resultset);

  if (n_cols <> 2)
    signal('SELPL', 'invalid number of resultset columns');

  if (isarray(meta) = 0)
    signal ('SELPL', sprintf('non-valid metadata : metadata is not an array'));

  if (aref(meta, 1) = 0)
    signal ('SELPL', sprintf('non-valid metadata : is select=%d', aref(meta, 1)));

  if (isarray(aref(meta, 0)) = 0)
    signal ('SELPL', sprintf('non-valid metadata : columns not an array '));

  if (length(aref(meta, 0)) <> 2)
    signal ('SELPL', sprintf('non-valid metadata : num columns : %d'), length(aref(meta, 0)));

  if (isarray(resultset) = 0 or length(resultset) <> 10 or
      isarray(aref(resultset, 5)) = 0 or length(aref(resultset, 5)) <> 2)
    signal('SELPL', 'non-valid resultset');

  if (aref(aref(aref(meta, 0), 0), 1) <> 189)
    signal ('SELPL', sprintf('non-valid metadata : ID not DV_LONG_INT : %d'), aref(aref(aref(meta, 0), 0), 1));

  if (aref(aref(aref(meta, 0), 1), 1) <> 182)
    signal ('SELPL', sprintf('non-valid metadata : DATA not DV_LONG_STRING : %d'), aref(aref(aref(meta, 0), 1), 1));
  if (ucase(aref(aref(aref(meta, 0), 0), 0)) <> 'ID' or
      ucase(aref(aref(aref(meta, 0), 1), 0)) <> 'DATA')
    signal('SELPL', 'non-valid column names');

  n := 1;
  while (n <= 10)
    {
      resultrow := aref(resultset, n - 1);
      if (isarray(resultrow) = 0 or length(resultrow) <> 2)
	signal('SELPL', sprintf('invalid resultrow %d', n));
      r_id := aref(resultrow, 0);
      r_data := aref(resultrow, 1);
      if (isinteger(r_id)  = 0 or r_id <> n or
	  isstring(r_data)  = 0 or r_data <> sprintf('DATA %d', n))
	signal('SELPL', sprintf('invalid data on row %d (id = %d, data=%s)', n, r_id, r_data));
      n := n + 1;
    }
};

create procedure test_cursor_select(in dsn varchar)
{
  declare r_id, n, retcode, handle integer;
  declare r_data, resultrow varchar;

  rexecute(dsn, 'select ID, DATA from EXECTEST',
      null, null, null, null, null, null, handle);

  n := 0;
  while (n < 10 and 0 = rnext(handle, resultrow))
    {
      if (isarray(resultrow) = 0 or length(resultrow) <> 2)
	signal('SELC1', sprintf('invalid resultrow %d', n + 1));
      r_id := aref(resultrow, 0);
      r_data := aref(resultrow, 1);
      if (r_id <> n + 1 or r_data <> sprintf('DATA %d', n + 1))
	signal('SELC2', sprintf('invalid data on row %d (id = %d, data=%s)', n + 1, r_id, r_data));
      n := n + 1;
    }
  if (n <> 10 or 100 <> rnext(handle, resultrow))
    signal('SELC3', 'invalid row count');

  if (rmoreresults(handle) <> 100)
    signal('SELC4', 'there are more results (rmoreresults failure)');
  rclose(handle);
};

create procedure test_rows_affected (in dsn varchar)
{
  declare num_rows varchar;
  declare _sqlstate, _errcode varchar;
  declare _ncols integer;
  declare _meta, _res any;

  _sqlstate := '00000';

  rexecute (dsn, 'select count(*) from EXECTEST',
    _sqlstate, _errcode, null, _ncols, _meta, _res);

  if (_sqlstate <> '00000')
    signal ('RATS1', 'Remote execution failed');

  if (row_count () <> 0)
    {
      signal ('RATS2',
              'row_count () <> 0 after rexecute of non-DML statement');
    }

  num_rows := cast (aref (aref (_res, 0), 0) as integer);

  rexecute (dsn, 'update EXECTEST set DATA = ''blurb''');

  if (row_count () <> num_rows)
    {
      signal ('RATS3', 'row count wrong after rexecute of DML statement');
    }
};

create procedure REXEC_RETCODE_WRAP (in x integer) returns integer
{
  declare params any;
  params := vector (
	      vector ('out', 'INTEGER', 0),
	      x);
  rexecute ('$U{PORT}', '{?=call RPROC_RETCODE(?)}', null, null, params);
  return params[0];
};

create procedure REXEC_INOUT_WRAP (in x integer) returns integer
{
  declare params any;
  params := vector (
	      vector ('inout', 'INTEGER', 0, x)
	      );
  rexecute ('$U{PORT}', '{call RPROC_INOUT(?)}', null, null, params);
  return params[0];
};

create procedure REXEC_TEST2_VARCHAR (in param varchar)
{
  declare P2, P3, RETCODE varchar;
  P2 := 'P2';
  P3:= NULL;
  declare params any;
  params := vector (
	      vector ('out', 'VARCHAR', 40),
	      param,
	      vector ('inout', 'VARCHAR', 40, P2),
	      vector ('out', 'VARCHAR', 40, P3)
	      );

  rexecute ('$U{PORT}', '{?=call RPROC_TEST2 (?, ?, ?)}', null, null, params);
  result_names (RETCODE, P2, P3);
  result (params[0], params[2], params[3]);
};


DB..vd_remote_data_source('$U{PORT}', '', 'dba', 'dba');

rexecute('$U{PORT}', 'create table EXECTEST(ID integer, DATA varchar(50))');
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Creating table using basic rexecute syntax : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

call test_retcodes('$U{PORT}');
ECHO BOTH $IF $NEQ $LAST[1] 0 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Bad table select error return : STATE=" $LAST[2] " MESSAGE=" $LAST[3] "\n";

call test_params_exec('$U{PORT}');
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Insert with parameters : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

DB.DBA.RSTMTEXEC ('$U{PORT}', 'select * from EXECTEST');
ECHO BOTH $IF $EQU $ROWCNT 10 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": BUG 4741 DB.DBA.RSTMTEXEC test : ROWCNT=" $ROWCNT " STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

DB.DBA.RSTMTEXEC ('$U{PORT}', 'select * from EXECTEST', 1);
ECHO BOTH $IF $EQU $ROWCNT 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": BUG 4741 DB.DBA.RSTMTEXEC 1 row test : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

DB.DBA.RSTMTEXEC ('$U{PORT}', 'select * from EXECTEST', -1);
ECHO BOTH $IF $EQU $ROWCNT 0 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": BUG 4741 DB.DBA.RSTMTEXEC 0 row test : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

DB.DBA.RSTMTEXEC ('$U{PORT}', 'select * from EXECTEST', 0);
ECHO BOTH $IF $EQU $ROWCNT 10 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": BUG 4741 DB.DBA.RSTMTEXEC many row test : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

attach table "EXECTEST" as "R_EXECTEST" from '$U{PORT}';
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Attaching the table back using VDB : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select count(*) from "R_EXECTEST";
ECHO BOTH $IF $EQU $LAST[1] 10 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Counting the rows of the attached table\n";

call test_plain_select('$U{PORT}');
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": rexecute with resultset output : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

call test_cursor_select('$U{PORT}');
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": rexecute with rnext and rclose : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

call test_rows_affected('$U{PORT}');
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": rexecute rows affected count : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";


select REXEC_RETCODE_WRAP (NULL);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": rexec retcode test procedure with NULL param : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";
ECHO BOTH $IF $EQU $LAST[1] 'NULL' "PASSED" $IF $EQU $U{DO_RPROC} "NO" "SKIPPED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": rexec retcode test procedure with NULL param return NULL : RETURN=" $LAST[1] "\n";

select REXEC_RETCODE_WRAP (1);
ECHO BOTH $IF $EQU $STATE OK "PASSED" $IF $EQU $U{DO_RPROC} "NO" "SKIPPED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": rexec retcode test procedure with 1 : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";
ECHO BOTH $IF $EQU $LAST[1] 11 "PASSED" $IF $EQU $U{DO_RPROC} "NO" "SKIPPED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": rexec retcode test procedure with 1 param return 11 : RETURN=" $LAST[1] "\n";

select REXEC_INOUT_WRAP (NULL);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": rexec inout test procedure with NULL param : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";
ECHO BOTH $IF $EQU $LAST[1] NULL "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": rexec inout test procedure with NULL param return NULL : RETURN=" $LAST[1] "\n";

select REXEC_INOUT_WRAP (1);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": rexec inout test procedure with 1 : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";
ECHO BOTH $IF $EQU $LAST[1] 11 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": rexec inout test procedure with 1 param return 11 : RETURN=" $LAST[1] "\n";

REXEC_TEST2_VARCHAR ('P1');
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": rexec mixed test procedure : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";
ECHO BOTH $IF $EQU $LAST[1] P1ORET "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": rexec mixed test procedure : RETURN=" $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[2] P2O2 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": rexec mixed test procedure : INOUT=" $LAST[2] "\n";
ECHO BOTH $IF $EQU $LAST[3] P1O3 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": rexec mixed test procedure : OUT=" $LAST[3] "\n";


drop user REXEC_GRANTEE;
drop user REXEC_GRANTEE2;
create user REXEC_GRANTEE;
create user REXEC_GRANTEE2;

grant rexecute on '$U{PORT}' to REXEC_GRANTEE2;

reconnect REXEC_GRANTEE;

rexecute ('$U{PORT}', 'select 1');
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": rexec permissions check non-dba : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

reconnect REXEC_GRANTEE2;

rexecute ('$U{PORT}', 'select 1');
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": rexec permissions check exp grant : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

grant rexecute on '$U{PORT}' to REXEC_GRANTEE;
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": rexec permissions check non-dba grant : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

reconnect dba;

revoke rexecute on '$U{PORT}' from REXEC_GRANTEE2;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": rexec permissions revoke grant : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

reconnect REXEC_GRANTEE2;
rexecute ('$U{PORT}', 'select 1');
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": rexec permissions check revoked grant : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

reconnect dba;

rexecute ('$U{PORT}', '
create procedure b4790_kaboom(in foo any)
{
  dbg_printf(''b4790_kaboom called'');
}
');


create procedure b4790_foo ()
{
  declare _stat, _msg varchar;
  declare _params any;

  _stat := '00000';
  _msg := '';
  _params := vector(
      vector ('out', 'integer', 0),
      repeat ('X', 32768));
  if (0 <> rexecute ('$U{PORT}', '{? = call b4790_kaboom(?)}',
          _stat, _msg, _params))
    signal (_stat, _msg);

  -- once again
  _stat := '00000';
  _msg := '';
  _params := vector(
      vector ('out', 'integer', 0),
      repeat ('X', 32768));
  if (0 <> rexecute ('$U{PORT}', '{? = call b4790_kaboom(?)}',
          _stat, _msg, _params))
    signal (_stat, _msg);
}

b4790_foo ();
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": rexec on a large str in parm : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

--
-- End of test
--
ECHO BOTH "COMPLETED: rexecute suite (rexecute.sql) WITH " $ARGV[0] " FAILED, " $ARGV[1] " PASSED\n\n";
