--
--  tplmodule.sql
--
--  $Id: tplmodule.sql,v 1.5.10.1 2013/01/02 16:15:17 source Exp $
--
--  PL Modules suite testing
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2016 OpenLink Software
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
echo BOTH "\nSTARTED: PL Modules suite (tplmodule.sql)\n";
SET ARGV[0] 0;
SET ARGV[1] 0;

delete user MODU1;
delete user MODU2;
delete user MOD;

create user MODU1;
create user MODU2;
use PLAY;
drop module MOD;
drop procedure MOD1;
drop table TMOD;

create table TMOD (ID int not null primary key);
insert into TMOD values (1);

create module MOD
{
  function MOD1 () returns varchar {
    return ('MOD1');
  };

  procedure MOD2 () {
    return concat (MOD1(), 'MOD2');
  };

  procedure MODT () {
    declare res any;
    select ID into res from TMOD;
    return res;
  };
};
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": module MOD created STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create module MOD1
{
  function MOD1 () returns varchar {
    return ('MOD1');
  };

  procedure MOD2 () {
    return concat (MOD1(), 'MOD2');
  };
  select * from gogo;
};
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": wrong module MOD2 with non-procedure in it STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select PLAY..MOD.MOD1();
ECHO BOTH $IF $EQU $LAST[1] MOD1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": calling module procedure MOD1 returned " $LAST[1] "\n";

select PLAY..MOD.MOD2();
ECHO BOTH $IF $EQU $LAST[1] MOD1MOD2 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": calling module procedure MOD2 witch references MOD1 returned " $LAST[1] "\n";

select MOD.MOD1();
ECHO BOTH $IF $EQU $LAST[1] MOD1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": calling module procedure MOD1 (by using MOD.MOD1 Non-FQN) returned " $LAST[1] "\n";

grant execute on PLAY..MOD.MOD1 to MODU1;
grant execute on PLAY..MOD to MODU2;

reconnect MODU1;
use PLAY;
select MOD.MOD1();
ECHO BOTH $IF $EQU $LAST[1] MOD1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": calling module procedure MOD1 as user MODU1 (explicit grant) returned " $LAST[1] "\n";

select MOD.MOD2();
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": calling module procedure MOD2 as user MODU1 (no grant) returned " $LAST[1] "\n";

reconnect MODU2;
use PLAY;
select MOD.MOD1();
ECHO BOTH $IF $EQU $LAST[1] MOD1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": calling module procedure MOD1 as user MODU2 (grant to module) returned " $LAST[1] "\n";

select MOD.MOD2();
ECHO BOTH $IF $EQU $LAST[1] MOD1MOD2 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": calling module procedure MOD2 as user MODU2 (grant to module) returned " $LAST[1] "\n";

reconnect dba;
USE NOMOD;

select PLAY..MOD.MOD1();
ECHO BOTH $IF $EQU $LAST[1] MOD1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": calling module procedure MOD1 from another qual returned " $LAST[1] "\n";

select MOD.MOD1();
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": calling module proc MOD1 (by using MOD.MOD1 Non-FQN) from another qual causes error\n";

USE PLAY;
create USER MOD;
reconnect MOD;
USE PLAY;

create procedure MOD1()
{
  return 'USERMOD1';
}

reconnect dba;
USE PLAY;

select MOD.MOD1();
ECHO BOTH $IF $EQU $LAST[1] USERMOD1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": user MOD procedure MOD1 is preferred over MOD1() from module MOD\n";

select PLAY..MOD.MOD1();
ECHO BOTH $IF $EQU $LAST[1] MOD1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": module proc MOD.MOD1 still callable by absolute ref\n";

create procedure MOD () { return 0; };
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": create procedure with the same name as a module\n";

select MOD.MODT();
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": procedure refering to a table\n";

alter table TMOD add data varchar;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": adding a column to table referenced in a module proc compilation\n";

select MOD.MODT();
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": procedure refering to a table after auto recompile\n";

create module DROPMOD {
  procedure p1 () { return 1; };
}

drop procedure DROPMOD;
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": droping module using drop procedure STATE=" $STATE "\n";

PROCEDURES DROPMOD%;
ECHO BOTH $IF $EQU $ROWCNT 0 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": module not displayed in SQLProcedures\n";

-- Bugzilla bug #427
drop procedure CAL..C;
drop module CAL..TEST1;
drop module CAL..TEST;

create procedure CAL..C(){
    return concat('C',CAL..TEST.B());
};

create module CAL..TEST{

    procedure A(){
          return concat('A',B());           --  signal: "undefined procedure B"  ???
	        };

    procedure A1() {
	      return concat('A',CAL..C());      --  signal: "undefined procedure CAL..C()"  ???
    };

    procedure A2() {
	      return concat('A',CAL..B());      --  return what I expect: 'A B '
    };

    procedure A3() {
	      return concat('A',CAL.dba.C()); --  return what I expect: 'A C B '
    };

    procedure A4() {
	      return concat('A',CAL..TEST1.A()); --  return what I expect: 'A TEST1.A '
    };

      procedure B(){
	    return 'B';
      };

};

create module CAL..TEST1{
    procedure A(){
          return 'TEST1.A';
    };
};

select CAL..TEST.A();
ECHO BOTH $IF $EQU $LAST[1] 'AB' "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Bugzilla #427 test 1 returned " $LAST[1] "\n";

select CAL..TEST.A1();
ECHO BOTH $IF $EQU $LAST[1] 'ACB' "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Bugzilla #427 test 2 returned " $LAST[1] "\n";

select CAL..TEST.A2();
ECHO BOTH $IF $EQU $LAST[1] 'AB' "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Bugzilla #427 test 3 returned " $LAST[1] "\n";

select CAL..TEST.A3();
ECHO BOTH $IF $EQU $LAST[1] 'ACB' "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Bugzilla #427 test 4 returned " $LAST[1] "\n";

select CAL..TEST.A4();
ECHO BOTH $IF $EQU $LAST[1] 'ATEST1.A' "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Bugzilla #427 test 5 returned " $LAST[1] "\n";

-- test for bug #1430
drop module TEST1430;
create module TEST1430 {
    procedure A() { return 'A';};
      procedure B() { return 'B';};
};
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": bug 1430: creating a module STATE=" $STATE "\n";

select TEST1430.A(),TEST1430.B();
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": bug 1430: procedures exist STATE=" $STATE "\n";

create module TEST1430 {
    procedure B() { return 'B1';};
    procedure C() { return 'C';};
};
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": bug 1430: redefining a module STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select TEST1430.A();
ECHO BOTH $IF $EQU $LAST[1] "A" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": bug 1430: procs from the old module still here returned=" $LAST[1] "\n";
select TEST1430.B();
ECHO BOTH $IF $EQU $LAST[1] "B" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": bug 1430: overlapping procs from the old module unchanged returned=" $LAST[1] "\n";
select TEST1430.C();
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": bug 1430: procs from the new module undefined STATE=" $STATE "\n";


drop module TEST1430;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": bug 1430: dropping module STATE=" $STATE "\n";

drop module TEST1430;
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": bug 1430: dropping module second time STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select TEST1430.A();
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": bug 1430: no proc A (dropped module) STATE=" $STATE "\n";
select TEST1430.B();
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": bug 1430: no proc B (dropped module) STATE=" $STATE "\n";
select TEST1430.C();
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": bug 1430: no proc C (dropped module) STATE=" $STATE "\n";

reconnect;

select TEST1430.A();
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": bug 1430: no proc A (dropped module) STATE=" $STATE "\n";
select TEST1430.B();
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": bug 1430: no proc B (dropped module) STATE=" $STATE "\n";
select TEST1430.C();
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": bug 1430: no proc C (dropped module) STATE=" $STATE "\n";

select count(*) from DB.DBA.SYS_PROCEDURES where upper (P_NAME) like upper ('%TEST1430');
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": bug 1430: " $LAST[1] " rows in the sys table after dropping a module\n";

--
-- End of test
--
ECHO BOTH "COMPLETED:  PL Modules suite (tplmodule.sql) WITH " $ARGV[0] " FAILED, " $ARGV[1] " PASSED\n\n";
