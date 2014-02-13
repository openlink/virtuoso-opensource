--
--  drop_hosts.sql
--
--  $Id$
--
--  Delete from BPEL.BPEL.script to activate triggers for removing defined Virtual Directories
--  
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--  
--  Copyright (C) 1998-2014 OpenLink Software
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

create procedure BPEL.BPEL.silent_exec (in form varchar)
{
	whenever sqlstate '42S0*' goto ign;
	whenever sqlstate '42000' goto ign;
	EXEC (form);
ign:
	;
}
;
-- additional tables from tutorials
BPEL.BPEL.silent_exec ('drop table LOAN2..resOnResult');
BPEL.BPEL.silent_exec ('drop table LOAN1..resOnResult1');
BPEL.BPEL.silent_exec ('drop table LOAN3..resOnResult');
BPEL.BPEL.silent_exec ('drop table Demo.demo.Wholesalers');
BPEL.BPEL.silent_exec ('drop table Demo.demo.EmailNotification');
-- UDT
BPEL.BPEL.silent_exec ('drop type STORE..LineItem');
BPEL.BPEL.silent_exec ('drop type STORE..Quote');

-- from sqlexec tutorial
BPEL.BPEL.silent_exec ('drop procedure DB..update_inventory');
create procedure BPEL.BPEL.delete_processes ()
{

  DECLARE EXIT HANDLER FOR SQLSTATE '40001' GOTO DEADLOCK;

  start:
  whenever not found goto no_data;
  declare cr cursor for
  select bs_id
    from BPEL.BPEL.script;

  declare inx integer;
  inx := 0;

  open cr (exclusive);
  while(inx < 10)
  {
    inx := inx + 1;
    declare tmp integer;
    fetch cr into tmp;

    delete from BPEL.BPEL.script where bs_id = tmp;
    commit work;
  };

  close cr;
  GOTO start;

  DEADLOCK:
  {
    rollback work;
    goto start;
  };

  no_data: return;
}
;


BPEL.BPEL.delete_processes ()
;

drop procedure BPEL.BPEL.delete_processes
;

create procedure BPEL.BPEL.delete_other_vdirs ()
{
  -- delete vdirs execute as <> 'dba'
  for (select HP_HOST, HP_LISTEN_HOST, HP_LPATH from DB.DBA.HTTP_PATH where HP_RUN_SOAP_AS in
     ('CRATS', 'SLOAN', 'ULOAN', 'CRATS1', 'SLOAN1', 'ULOAN1', 'LOAN1', 'LOAN3', 'CRATS2', 'SLOAN2', 'ULOAN2', 'LOAN2', 'LWSRM', 'STORE', 'AECHO', 'TESTXSLTCRATS') )
  do
    {
      VHOST_REMOVE (HP_HOST, HP_LISTEN_HOST, HP_LPATH, 0);
    };

  -- delete vdirs execute as 'dba'
  for (select HP_HOST, HP_LISTEN_HOST, HP_LPATH from DB.DBA.HTTP_PATH where HP_RUN_VSP_AS = 'dba' and HP_LPATH in ('/RMLoan','/SecLoan','/SecRMLoan'))
  do
    {
      VHOST_REMOVE (HP_HOST, HP_LISTEN_HOST, HP_LPATH, 0);
    };
}
;

BPEL.BPEL.delete_other_vdirs ()
;

drop procedure BPEL.BPEL.delete_other_vdirs
;

create procedure BPEL.BPEL.DROP_ALL_ADD_PROC (in pName varchar)
{
  declare arr any;
  arr := vector ();
  declare sName varchar;

  for select P_NAME from DB.DBA.SYS_PROCEDURES where P_NAME like sprintf('%s.%s',pName,'%')
    do
    {
      arr := vector_concat (arr, vector (P_NAME));
    }
  foreach (any elm in arr) do
    {
      DB.DBA.EXEC_STMT ('drop procedure "'||elm||'"', 0);
    }
}
;

create procedure BPEL.BPEL.delete_other_users ()
{
  for (select U_NAME from DB.DBA.SYS_USERS where U_NAME in
     ('CRATS', 'SLOAN', 'ULOAN', 'CRATS1', 'SLOAN1', 'ULOAN1', 'LOAN1', 'LOAN3', 'CRATS2', 'SLOAN2', 'ULOAN2', 'LOAN2', 'LWSRM', 'STORE', 'AECHO') )
  do
    {
      BPEL.BPEL.DROP_ALL_ADD_PROC(U_NAME);
      DB.DBA.USER_DROP(U_NAME);
    };
}
;

BPEL.BPEL.delete_other_users ()
;

drop procedure BPEL.BPEL.delete_other_users
;

-- dropping procedures for WSRM from WS_Sec tutorials
BPEL.BPEL.DROP_ALL_ADD_PROC('WSRM')
;

