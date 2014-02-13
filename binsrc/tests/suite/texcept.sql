--
--  texcept.sql
--
--  $Id: texcept.sql,v 1.8.10.1 2013/01/02 16:15:08 source Exp $
--
--  Exception handling tests
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

ECHO BOTH "STARTED: Exception handling tests (texcept.sql)\n";
SET ARGV[0] 0;
SET ARGV[1] 0;

create procedure H_STATE_TEST (in stat varchar) {
  declare res varchar;
  result_names (res);
  declare exit handler for sqlstate '*', not found result ('catchall');
  declare exit handler for sqlwarning result ('warning');
  declare exit handler for sqlexception result ('exception');
  declare exit handler for sqlstate 'A*' result ('A');
  declare exit handler for sqlstate 'AB*' result ('AB');
  whenever sqlstate 'ABC' GOTO end1;
  signal (stat, 'signalled');
end1:
  result ('ABC');
};
ECHO BOTH $IF $EQU $STATE OK 'PASSED' '*** FAILED';
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Procedure H_STATE_TEST created. STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

H_STATE_TEST ('ABC');
ECHO BOTH $IF $EQU $LAST[1] 'ABC' 'PASSED' '*** FAILED';
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Longest match first for ABC=" $LAST[1] "\n";

H_STATE_TEST ('ABX');
ECHO BOTH $IF $EQU $LAST[1] 'AB' 'PASSED' '*** FAILED';
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Longest match first for ABX=" $LAST[1] "\n";

H_STATE_TEST ('AXX');
ECHO BOTH $IF $EQU $LAST[1] 'A' 'PASSED' '*** FAILED';
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Longest match first for AXX=" $LAST[1] "\n";

H_STATE_TEST ('XXX');
ECHO BOTH $IF $EQU $LAST[1] 'exception' 'PASSED' '*** FAILED';
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Longest match first for SQLEXCEPTION condition XXX=" $LAST[1] "\n";

H_STATE_TEST ('01000');
ECHO BOTH $IF $EQU $LAST[1] 'warning' 'PASSED' '*** FAILED';
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Longest match first for SQLWARNING condition 01000=" $LAST[1] "\n";


H_STATE_TEST ('02000');
ECHO BOTH $IF $EQU $LAST[1] 'catchall' 'PASSED' '*** FAILED';
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Longest match first for * condition 02000=" $LAST[1] "\n";


H_STATE_TEST (100);
ECHO BOTH $IF $EQU $LAST[1] 'catchall' 'PASSED' '*** FAILED';
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Longest match first for INT 100 (NOT FOUND)=" $LAST[1] "\n";


create procedure H_TYPE_TEST (in stat varchar)
{
  declare res varchar;
  result_names (res);
    {
      declare exit handler for sqlstate 'A*' result ('exit');
      declare continue handler for sqlstate 'B*';
      signal (stat, 'signalled');
      result ('continued');
    }
};
ECHO BOTH $IF $EQU $STATE OK 'PASSED' '*** FAILED';
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Procedure H_TYPE_TEST created. STATE=" $STATE " MESSAGE=" $MESSAGE "\n";


H_TYPE_TEST ('AX');
ECHO BOTH $IF $EQU $LAST[1] 'exit' 'PASSED' '*** FAILED';
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Exit handler activation=" $LAST[1] "\n";

H_TYPE_TEST ('BX');
ECHO BOTH $IF $EQU $LAST[1] 'continued' 'PASSED' '*** FAILED';
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Continue handler activation=" $LAST[1] "\n";


create procedure H_SCOPE_TEST (in stat varchar)
{
  declare res varchar;
  result_names (res);
  declare exit handler for sqlstate '*' result ('globa');
    {
      declare exit handler for sqlstate '*' result ('local');
      if (stat = 'local')
	signal (stat, 'signalled');
    }
  if (stat = 'globa')
    signal (stat, 'signalled');
};
ECHO BOTH $IF $EQU $STATE OK 'PASSED' '*** FAILED';
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Procedure H_SCOPE_TEST created. STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

H_SCOPE_TEST ('local');
ECHO BOTH $IF $EQU $LAST[1] 'local' 'PASSED' '*** FAILED';
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Handler in local scope takes precedence=" $LAST[1] "\n";

H_SCOPE_TEST ('globa');
ECHO BOTH $IF $EQU $LAST[1] 'globa' 'PASSED' '*** FAILED';
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Handler in local scope not active=" $LAST[1] "\n";


create procedure H_EXCEPTION_VARS_PROC_SCOPE_TEST (in stat varchar)
{
  declare state, msg varchar;
  result_names (state, msg);
  declare continue handler for sqlexception, not found;
  if (stat is not null)
    signal (stat, 'signalled');
  result (__SQL_state, __SQL_message);
};


drop table t1;
create table t1 (i int primary key, a varchar (20));


create trigger TRS before update on t1 referencing old as O
{
  declare result integer;
  dbg_obj_print(__SQL_MESSAGE);
  dbg_obj_print(__SQL_STATE);
}
;

ECHO BOTH $IF $EQU $STATE OK 'PASSED' '*** FAILED';
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Triger TRS created. STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create procedure RESIGNAL1()
{
  declare exit handler for SQLSTATE '42001'
   {
      dbg_obj_print('ECI_RUN_TIME');
      dbg_obj_print(__SQL_STATE);
      dbg_obj_print(__SQL_MESSAGE);
      RESIGNAL;
   };

  dbg_obj_print(__SQL_STATE);
  dbg_obj_print(__SQL_MESSAGE);
  dbg_obj_printf('OK');
  dbg_obj_print(__SQL_STATE);
  dbg_obj_print(__SQL_MESSAGE);
  return 1;
}


create procedure RESIGNAL2()
{
  whenever SQLSTATE '42001' goto ECI_RUN_TIME;
  dbg_obj_print(__SQL_STATE);
  dbg_obj_print(__SQL_MESSAGE);
  dbg_obj_printf('OK');
  dbg_obj_print(__SQL_STATE);
  dbg_obj_print(__SQL_MESSAGE);
  return 1;

ECI_RUN_TIME:;

  whenever SQLSTATE '42001' default; -- Free old error handler.
  dbg_obj_print('ECI_RUN_TIME');
  dbg_obj_print(__SQL_STATE);
  dbg_obj_print(__SQL_MESSAGE);
  RESIGNAL;
}

drop table TEST_EH;
create table TEST_EH (ID integer not null,
                      VAL integer not null,
                      NAME varchar(50) not null,
                      primary key(ID));

create unique index TEST_SK01 on TEST_EH (VAL,NAME);

INSERT INTO TEST_EH (ID,VAL,NAME) values(1,1,'name');
INSERT INTO TEST_EH (ID,VAL,NAME) values(2,2,'name');

create procedure test_ex1()
{
  declare exit handler for SQLSTATE '*'
    {
       return 1;
    };

 UPDATE TEST_EH SET NAME='name',VAL=1 WHERE ID = 2;
 return 0;
}
;

create procedure test_ex2()
{
  declare exit handler  for SQLSTATE '*'
    {
       return 1;
    };

 INSERT INTO TEST_EH (ID,VAL,NAME) values(3,1,'name');
 return 0;
}
;


ECHO BOTH $IF $EQU $STATE OK 'PASSED' '*** FAILED';
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Procedure H_EXCEPTION_VARS_PROC_SCOPE_TEST created. STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

H_EXCEPTION_VARS_PROC_SCOPE_TEST (NULL);
ECHO BOTH $IF $EQU $LAST[1] '0' 'PASSED' '*** FAILED';
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Initial exception __SQL_STATE value=" $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[2] '0' 'PASSED' '*** FAILED';
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Initial exception __SQL_MESSAGE value=" $LAST[2] "\n";

H_EXCEPTION_VARS_PROC_SCOPE_TEST ('ERRST');
ECHO BOTH $IF $EQU $LAST[1] 'ERRST' 'PASSED' '*** FAILED';
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": __SQL_STATE set on error=" $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[2] 'signalled' 'PASSED' '*** FAILED';
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": __SQL_MESSAGE set on error=" $LAST[2] "\n";

H_EXCEPTION_VARS_PROC_SCOPE_TEST (100);
ECHO BOTH $IF $EQU $LAST[1] '100' 'PASSED' '*** FAILED';
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": __SQL_STATE set on NO DATA FOUND=" $LAST[1] "\n";

select RESIGNAL1();
ECHO BOTH $IF $EQU $STATE '42001' "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": RESIGNAL execution error 1 : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select RESIGNAL2();
ECHO BOTH $IF $EQU $STATE '42001' "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": RESIGNAL execution error 2 : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select test_ex1();
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": HANDLER executed (ins_subq) : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select test_ex2();
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": HANDLER executed (ins_qnode) : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";


create procedure H_EXCEPTION_OFF_TEST (in stat varchar)
{
  declare state varchar;
  result_names (state);
  declare exit handler for sqlexception, not found result ('handler');
  if (stat like '%glo')
    signal (stat, 'signalled');
  whenever sqlstate 'G*' default;
  if (stat like '%loc')
    signal (stat, 'signalled');
};
ECHO BOTH $IF $EQU $STATE OK 'PASSED' '*** FAILED';
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Procedure H_EXCEPTION_OFF_TEST created. STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

H_EXCEPTION_OFF_TEST ('G_glo');
ECHO BOTH $IF $EQU $LAST[1] 'handler' 'PASSED' '*** FAILED';
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": caught non-turned off exception for G_global=" $LAST[1] "\n";

H_EXCEPTION_OFF_TEST ('G_loc');
ECHO BOTH $IF $EQU $STATE 'G_loc' 'PASSED' '*** FAILED';
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Exception handling turned off STATE=" $STATE "\n";


create procedure H_EXCEPTION_RESIGNAL_TEST (in stat varchar)
{
  declare state varchar;
  result_names (state);
  declare exit handler for sqlexception, not found
    {
      if (__SQL_STATE = 'GX')
	result (__SQL_STATE);
      else if (__SQL_STATE = 100)
	resignal 'NODAT';
      else
	resignal;
    };
  signal (stat, 'signalled');
};
ECHO BOTH $IF $EQU $STATE OK 'PASSED' '*** FAILED';
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Procedure H_EXCEPTION_RESIGNAL_TEST created. STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

H_EXCEPTION_RESIGNAL_TEST ('GX');
ECHO BOTH $IF $EQU $LAST[1] 'GX' 'PASSED' '*** FAILED';
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Exception handler didn't resignalled GX\n";

H_EXCEPTION_RESIGNAL_TEST (100);
ECHO BOTH $IF $EQU $STATE 'NODAT' 'PASSED' '*** FAILED';
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Exception handling resignalled STATE=" $STATE "\n";

H_EXCEPTION_RESIGNAL_TEST ('AX');
ECHO BOTH $IF $EQU $STATE 'AX' 'PASSED' '*** FAILED';
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Exception handling resignalled STATE=" $STATE "\n";

CREATE PROCEDURE H_NEW_CURSOR_TEST ()
{
  declare user_name varchar;
  result_names (user_name);
  DECLARE c1 CURSOR FOR
      SELECT U_NAME FROM SYS_USERS;
  DECLARE EXIT HANDLER FOR NOT FOUND;
  DECLARE EXIT HANDLER FOR sqlexception resignal;
  OPEN c1;
  WHILE (__SQL_STATE = 0)
    {
      FETCH c1 INTO user_name;
      result (user_name);
    }
  CLOSE c1;
};
ECHO BOTH $IF $EQU $STATE OK 'PASSED' '*** FAILED';
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Procedure H_NEW_CURSOR_TEST created. STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

H_NEW_CURSOR_TEST ();
ECHO BOTH $IF $GTE $ROWCNT 1 'PASSED' '*** FAILED';
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Procedure H_NEW_CURSOR_TEST called. STATE=" $STATE " MESSAGE=" $MESSAGE "\n";


create procedure B4217(){
  declare sResult varchar;

  result_names(sResult);

  result('-= start =-');

  declare continue handler for SQLSTATE '*' result(__SQL_STATE);
  {
    signal('test 1','test 1 body');
    signal('test 2','test 2 body');
  };
  result('-= finish =-');
};

B4217();
ECHO BOTH $IF $EQU $STATE OK 'PASSED' '*** FAILED';
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": BUG4217: Continue handler twice in a row saves nest level. STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

ECHO BOTH "COMPLETED: Exception handling tests (texcept.sql) WITH " $ARGV[0] " FAILED, " $ARGV[1] " PASSED\n\n";
