--
--  texecute.sql
--
--  $Id$
--
--  exec suite testing
--  
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--  
--  Copyright (C) 1998-2013 OpenLink Software
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
echo BOTH "\nSTARTED: exec suite (texecute.sql)\n";
SET ARGV[0] 0;
SET ARGV[1] 0;

create procedure EXEC_TEST_RETCODES ()
{
  declare retcode integer;
  declare state, message varchar;

  retcode := exec ('select * from rexecnonexistent', state, message);
  result_names(retcode, state, message);
  result(retcode, state, message);
};
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": creating test proc EXEC_TEST_RETCODES: STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create procedure EXEC_TEST_PARAMS_EXEC ()
{
  declare params varchar;
  declare n, rows_updated integer;
  declare data varchar;

  n := 1;
  while (n <= 10)
    {
      data := vector(n, sprintf('DATA %d', n));
      exec ('insert into EXECTEST (ID, DATA) values (?, ?)', null, null, data);
      n := n + 1;
    }
};
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": creating test proc EXEC_TEST_PARAMS_EXEC: STATE=" $STATE " MESSAGE=" $MESSAGE "\n";


create procedure EXEC_TEST_PLAIN_SELECT ()
{
  declare r_id, n, n_cols integer;
  declare r_data, meta, resultset, resultrow varchar;

  exec ('select ID, DATA from EXECTEST',
      null, null, null, 1000, meta, resultset);

  if (isarray(meta) = 0)
    signal ('SELPL', sprintf('non-valid metadata : metadata is not an array'));

  if (aref(meta, 1) = 0)
    signal ('SELPL', sprintf('non-valid metadata : is select=%d', aref(meta, 1)));

  if (isarray(aref(meta, 0)) = 0)
    signal ('SELPL', sprintf('non-valid metadata : columns not an array '));

  if (length(aref(meta, 0)) <> 2)
    signal ('SELPL', sprintf('non-valid metadata : num columns : %d', length(aref(meta, 0))));

  if (isarray(resultset) = 0 or length(resultset) <> 10 or
      isarray(aref(resultset, 5)) = 0 or length(aref(resultset, 5)) <> 2)
    signal('SELPL', 'non-valid resultset');

  if (aref(aref(aref(meta, 0), 0), 1) <> 189)
    signal ('SELPL', sprintf('non-valid metadata : ID not DV_LONG_INT : %d', aref(aref(aref(meta, 0), 0), 1)));

  if (aref(aref(aref(meta, 0), 1), 1) <> 182)
    signal ('SELPL', sprintf('non-valid metadata : DATA not DV_LONG_STRING : %d', aref(aref(aref(meta, 0), 1), 1)));
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
}
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": creating test proc EXEC_TEST_PLAIN_SELECT: STATE=" $STATE " MESSAGE=" $MESSAGE "\n";


create procedure EXEC_TEST_CURSOR_SELECT ()
{
  declare r_id, n, retcode, handle integer;
  declare r_data, resultrow varchar;

  exec ('select ID, DATA from EXECTEST',
      null, null, null, 1000, null, null, handle);

  n := 0;
  while (n < 10 and 0 = exec_next(handle, NULL, NULL, resultrow))
    {
      if (isarray(resultrow) = 0 or length(resultrow) <> 2)
	signal('SELC1', sprintf('invalid resultrow %d', n + 1));
      r_id := aref(resultrow, 0);
      r_data := aref(resultrow, 1);
      if (r_id <> n + 1 or r_data <> sprintf('DATA %d', n + 1))
	signal('SELC2', sprintf('invalid data on row %d (id = %d, data=%s)', n + 1, r_id, r_data));
      n := n + 1;
    }
  if (n <> 10 or 100 <> exec_next (handle, NULL, NULL, resultrow))
    signal('SELC3', 'invalid row count');

  exec_close (handle);
};
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": creating test proc EXEC_TEST_CURSOR_SELECT: STATE=" $STATE " MESSAGE=" $MESSAGE "\n";


create procedure EXEC_RESULTSET_PROC1 ()
{
  declare res_col integer;
  result_names (res_col);
  result (1);
  result (2);
  end_result();
};
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": creating test proc EXEC_RESULTSET_PROC1: STATE=" $STATE " MESSAGE=" $MESSAGE "\n";


create procedure EXEC_RESULTSET_PROC2 ()
{
  declare res_col integer;
  result_names (res_col);
  result (1);
  result (2);
  result_names (res_col);
  result (1);
  result (2);
  end_result();
};
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": creating test proc EXEC_RESULTSET_PROC2: STATE=" $STATE " MESSAGE=" $MESSAGE "\n";


create procedure TEST_RESULTSET_PROC (in test integer)
{
  declare meta, rs, resultrow any;
  declare n, r_id integer;
  if (test = 1)
    {
      exec ('EXEC_RESULTSET_PROC1()', NULL, NULL, NULL, 100, meta, rs);
      if (0 = isarray (meta))
	signal ('.....', 'resultset description not an array');
      if (0 = isarray (rs))
	signal ('.....', 'resultset not an array');
      if (aref (meta, 1) <> 2)
	signal ('.....', sprintf('non-valid metadata : is stored proc =%d', aref(meta, 1)));
      if (isarray(aref(meta, 0)) = 0)
	signal ('.....', sprintf('non-valid metadata : columns not an array '));
      if (length(aref(meta, 0)) <> 1)
	signal ('.....', sprintf('non-valid metadata : num columns : %d'), length(aref(meta, 0)));
      if (isarray(rs) = 0 or length(rs) <> 2 or
	  isarray(aref(rs, 1)) = 0 or length(aref(rs, 1)) <> 1)
	signal ('.....', 'non-valid resultset');
      if (aref(aref(aref(meta, 0), 0), 1) <> 189)
	signal ('.....', sprintf('non-valid metadata : ID not DV_LONG_INT : %d'), aref(aref(aref(meta, 0), 0), 1));

      n := 1;
      while (n <= 2)
	{
	  resultrow := aref(rs, n - 1);
	  if (isarray(resultrow) = 0 or length(resultrow) <> 1)
	    signal('.....', sprintf('invalid resultrow %d', n));
	  r_id := aref(resultrow, 0);
	  if (isinteger(r_id)  = 0 or r_id <> n)
	    signal('SELPL', sprintf('invalid data on row %d (id = %d)', n, r_id));
	  n := n + 1;
	}
    }
  else if (test = 2)
    {
      exec ('EXEC_RESULTSET_PROC1()', NULL, NULL, NULL, 1, meta, rs);
      if (0 = isarray (meta))
	signal ('.....', 'resultset description not an array');
      if (0 = isarray (rs))
	signal ('.....', 'resultset not an array');
      if (aref (meta, 1) <> 2)
	signal ('.....', sprintf('non-valid metadata : is stored proc =%d', aref(meta, 1)));
      if (isarray(aref(meta, 0)) = 0)
	signal ('.....', sprintf('non-valid metadata : columns not an array '));
      if (length(aref(meta, 0)) <> 1)
	signal ('.....', sprintf('non-valid metadata : num columns : %d'), length(aref(meta, 0)));
      if (isarray(rs) = 0 or length(rs) <> 1 or
	  isarray(aref(rs, 0)) = 0 or length(aref(rs, 0)) <> 1)
	signal ('.....', 'non-valid resultset');
      if (aref(aref(aref(meta, 0), 0), 1) <> 189)
	signal ('.....', sprintf('non-valid metadata : ID not DV_LONG_INT : %d'), aref(aref(aref(meta, 0), 0), 1));

      n := 1;
      while (n <= 1)
	{
	  resultrow := aref(rs, n - 1);
	  if (isarray(resultrow) = 0 or length(resultrow) <> 1)
	    signal('.....', sprintf('invalid resultrow %d', n));
	  r_id := aref(resultrow, 0);
	  if (isinteger(r_id)  = 0 or r_id <> n)
	    signal('SELPL', sprintf('invalid data on row %d (id = %d)', n, r_id));
	  n := n + 1;
	}
    }
  else if (test = 3)
    {
      exec ('EXEC_RESULTSET_PROC2()', NULL, NULL, NULL, 100, meta, rs);
    }
  else if (test = 4)
    {
      exec ('EXEC_RESULTSET_PROC1()', NULL, NULL, NULL, 1, NULL, rs);
      if (0 = isarray (rs))
	signal ('.....', 'resultset not an array');
      if (isarray(rs) = 0 or length(rs) <> 1 or
	  isarray(aref(rs, 0)) = 0 or length(aref(rs, 0)) <> 1)
	{
	  dbg_obj_print (rs);
	  signal ('.....', sprintf ('non-valid resultset tag = %d, length = %d', __tag (rs), length (rs)));
	}

      n := 1;
      while (n <= 1)
	{
	  resultrow := aref(rs, n - 1);
	  if (isarray(resultrow) = 0 or length(resultrow) <> 1)
	    signal('.....', sprintf('invalid resultrow %d', n));
	  r_id := aref(resultrow, 0);
	  if (isinteger(r_id)  = 0 or r_id <> n)
	    signal('SELPL', sprintf('invalid data on row %d (id = %d)', n, r_id));
	  n := n + 1;
	}
    }
  else if (test = 5)
    {
      exec ('EXEC_RESULTSET_PROC1()', NULL, NULL, NULL, 0, meta, rs);
      dbg_obj_print (meta);
      if (0 = isarray (meta))
	signal ('.....', 'resultset description not an array');
      if (aref (meta, 1) <> 2)
	signal ('.....', sprintf('non-valid metadata : is stored proc =%d', aref(meta, 1)));
      if (isarray(aref(meta, 0)) = 0)
	signal ('.....', sprintf('non-valid metadata : columns not an array '));
      if (length(aref(meta, 0)) <> 1)
	signal ('.....', sprintf('non-valid metadata : num columns : %d'), length(aref(meta, 0)));
      if (aref(aref(aref(meta, 0), 0), 1) <> 189)
	signal ('.....', sprintf('non-valid metadata : ID not DV_LONG_INT : %d'), aref(aref(aref(meta, 0), 0), 1));
    }
  else if (test = 6)
    {
      exec ('EXEC_RESULTSET_PROC1()', NULL, NULL, NULL, 100, meta, NULL);
      if (0 = isarray (meta))
	signal ('.....', 'resultset description not an array');
      if (aref (meta, 1) <> 2)
	signal ('.....', sprintf('non-valid metadata : is stored proc =%d', aref(meta, 1)));
      if (isarray(aref(meta, 0)) = 0)
	signal ('.....', sprintf('non-valid metadata : columns not an array '));
      if (length(aref(meta, 0)) <> 1)
	signal ('.....', sprintf('non-valid metadata : num columns : %d'), length(aref(meta, 0)));
      if (aref(aref(aref(meta, 0), 0), 1) <> 189)
	signal ('.....', sprintf('non-valid metadata : ID not DV_LONG_INT : %d'), aref(aref(aref(meta, 0), 0), 1));
    }
};
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": creating test proc TEST_RESULTSET_PROC: STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

drop table EXECTEST;

create table EXECTEST(ID integer, DATA varchar(50));
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Creating table : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

call EXEC_TEST_RETCODES();
ECHO BOTH $IF $NEQ $LAST[1] 0 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Bad table select error return : STATE=" $LAST[2] " MESSAGE=" $LAST[3] "\n";

call EXEC_TEST_PARAMS_EXEC();
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Insert with parameters : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select count(*) from EXECTEST;
ECHO BOTH $IF $EQU $LAST[1] 10 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Counting the rows of the attached table\n";

call EXEC_TEST_PLAIN_SELECT();
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": exec with resultset output : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

call EXEC_TEST_CURSOR_SELECT();
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": exec with exec_next and exec_close : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

call TEST_RESULTSET_PROC(1);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": exec an procedure returning a single resultset : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

call TEST_RESULTSET_PROC(2);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": exec an procedure returning a single resultset limit the rowset size to 1: STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

call TEST_RESULTSET_PROC(3);
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": exec an procedure returning two resultsets : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

call TEST_RESULTSET_PROC(4);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": exec an procedure returning a single resultset with a null metadata: STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

call TEST_RESULTSET_PROC(5);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": exec an procedure returning a single resultset limit the rowset size to 0: STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

call TEST_RESULTSET_PROC(6);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": exec an procedure returning a single resultset with a null resultset: STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

drop table EXEC_WIDE;
create table EXEC_WIDE (ID int not null primary key, DATA nvarchar);
insert into EXEC_WIDE (ID, DATA) values (1, N'\x451');
exec (N'insert into EXEC_WIDE (ID, DATA) values (2, N''\x451'')');

select (select aref (DATA, 1) from EXEC_WIDE where ID = 1) - (select aref (DATA, 1) from EXEC_WIDE where ID = 2);
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": exec with nvarchar string : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

--- suite for the bug #1119
create procedure PARAMTYPE (in v varchar)
{
  if (v > 0)
    return;
  result_names (v);
  result (v);
};

create procedure TESTPARAMTYPE ()
{
  declare meta, res any;

  exec ('PARAMTYPE (''a'')', null, null, null, 0, meta, res);
  return dv_type_title (meta[0][0][1]);
};

select TESTPARAMTYPE ();
ECHO BOTH $IF $EQU $LAST[1] VARCHAR "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": preserving parameter types for procedure returned : " $LAST[1] "\n";


create procedure XX1 ()
{
  declare meta, _dt any;
  declare inx integer;
  exec ('select U_ID, U_NAME from SYS_USERS', null, null, null, 0, meta, _dt);
  inx := 0;

  exec_result_names (meta[0]);
  while (inx < length (_dt))
    {
      exec_result (_dt[inx]);
      inx := inx + 1;
    }
};

create procedure XX2 ()
{
  declare meta, _dt any;
  declare inx integer;
  exec ('select U_ID, U_NAME from SYS_USERS', null, null, null, 0, meta, _dt);
  inx := 0;

  exec_result_names (vector ('a', 'b'));
  while (inx < length (_dt))
    {
      exec_result (_dt[inx]);
      inx := inx + 1;
    }
};

call XX1();
ECHO BOTH $IF $NEQ $ROWCNT 0 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Calling exec_result_names/exec_result\n";
call XX2();
ECHO BOTH $IF $NEQ $ROWCNT 0 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Calling exec_result_names(strings)/exec_result\n";

select * from XX1() (N1 integer, N2 varchar)  a ;
ECHO BOTH $IF $NEQ $ROWCNT 0 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Calling exec_result_names/exec_result in a proc table\n";

create procedure CALL_XX ()
{
  declare res, meta any;
  exec ('XX1()', null, null, null, 0, meta, res);
  return res;
};

select length (CALL_XX());
ECHO BOTH $IF $NEQ $LAST[1] 0 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Calling exec_result_names/exec_result in exec\n";
--
-- End of test
--
ECHO BOTH "COMPLETED: exec suite (texecute.sql) WITH " $ARGV[0] " FAILED, " $ARGV[1] " PASSED\n\n";
