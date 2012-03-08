--
--  rtrxdead.sql
--
--  $Id$
--
--  Remote database transaction testing
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2012 OpenLink Software
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

create procedure deadlock_test (in with_commit integer)
{
  declare cr cursor for select ROW_NO from R1..T1;
  declare _row_no integer;
  declare _remote_dsn varchar;
  select RT_DSN into _remote_dsn from DB.DBA.SYS_REMOTE_TABLE where upper (RT_NAME) like 'R1.%.T1';

  open cr;
  fetch cr into _row_no;
  while (1)
    {
      fetch cr into _row_no;
      whenever sqlstate '40001' goto cont;
      rexecute (_remote_dsn, 'txn_error (2)');
cont:
      _row_no := 0;
      if (with_commit)
        commit work;
      whenever sqlstate '40001' default;
    }
};

create procedure lock_test (in with_commit integer)
{
  declare cr cursor for select ROW_NO from R1..T1;
  declare _row_no integer;
  declare _remote_dsn varchar;
  select RT_DSN into _remote_dsn from DB.DBA.SYS_REMOTE_TABLE where upper (RT_NAME) like 'R1.%.T1';

  open cr;
  fetch cr into _row_no;
  while (1)
    {
      fetch cr into _row_no;
      whenever sqlstate '08U01' goto cont;
      rexecute (_remote_dsn, 'cl_exec (''raw_exit ()'')');
cont:
      _row_no := 0;
      if (with_commit)
        commit work;
      whenever sqlstate '08U01' default;
    }
};

set autocommit off;
-- not relevant in 6
--deadlock_test (0);
--ECHO BOTH $IF $EQU $STATE 40001 "PASSED" "***FAILED";
--ECHO BOTH ": Remote deadlocking with an opened cursor : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

lock_test (0);
ECHO BOTH $IF $EQU $STATE 08U01 "PASSED" "***FAILED";
ECHO BOTH ": Remote dropping the connection with an opened cursor : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";
