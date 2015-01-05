--
--  $Id$
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
echo BOTH "\nSTARTED: SQL200n user defined types suite (udttest.sql)\n";
SET ARGV[0] 0;
SET ARGV[1] 0;
drop table UDT_TEST_TBL;
drop table UDT_TEST_BLOB_TBL;
drop procedure TEST_OVERLOAD_FLD;
drop procedure TEST_OVERLOAD;
drop procedure TEST_DOT_NOTATION;
drop procedure TEST_NO_RETS;
drop type UDT_TEST_SUB;
drop type UDT_TEST;
drop type UDT_TEST_BLOB;
drop type UDT_INOUT_TEST;
drop type DB.DBA.UDT_TEMP;
drop procedure UDT_INOUT_TEST_PROC;
drop type SUB_UDT_TEMP;
drop type SUB_UDT_TEST_TEMP;
drop type UDT_JAVA;
drop type UDT_SQL;
drop type UDT_REF_CLASS;
drop procedure test_observers;
drop procedure test_observers;
drop procedure test_and_run_method;
drop table UDT_TEMP_TB;
drop table UDT_ANY_TB;
drop type UDT_FR_BASE;
drop type UDT_FR_SUPER;
drop type UDT_FR_COL;
drop type UDT_BM_SUB;
drop type UDT_BM_BASE;



create type UDT_TEST
  as (A integer default 1, B integer default 2)
  CONSTRUCTOR METHOD UDT_TEST(_a integer, _b integer) specific DB.DBA.construct_x,
  CONSTRUCTOR METHOD UDT_TEST(),
  STATIC METHOD _ADD(_xx integer, _yy integer) returns integer specific DB.DBA.static_add,
  METHOD ADDIT() returns integer specific DB.DBA.add_them1,
  METHOD ADDIT(c integer) returns integer specific DB.DBA.add_them2,
  METHOD SUB_IT () returns integer;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": type UDT_TEST declared STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create constructor method UDT_TEST (in _a integer, in _b integer) for UDT_TEST
{
  A(SELF, _a);
  B(SELF, _b);
};
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": constructor for UDT_TEST defined STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create constructor method UDT_TEST () for UDT_TEST
{
  A(SELF, -1);
  B(SELF, -2);
};
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": default constructor for UDT_TEST defined STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create static method _ADD (in a1 integer, in a2 integer) for UDT_TEST
{
  return a1 + a2;
};
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": static method for UDT_TEST defined STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

--explain ('
create method ADDIT () for UDT_TEST
{
  return UDT_TEST::_ADD (A(SELF), B(SELF));
}
--')
;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": dynamic method 'ADDIT' for UDT_TEST defined STATE=" $STATE " MESSAGE=" $MESSAGE "\n";


--explain ('
create method ADDIT (in c integer) for UDT_TEST
{
  return UDT_TEST::_ADD (A(SELF), B(SELF)) + c;
}
--')
;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": dynamic method 'ADDIT' w/arg for UDT_TEST defined STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

--explain ('
create method SUB_IT () for UDT_TEST
{
  return A(SELF) - B(SELF);
}
--')
;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": dynamic method 'SUB_IT' for UDT_TEST defined STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create type UDT_TEST_SUB under UDT_TEST
  as (C integer default 12, _D integer default 32)
  STATIC METHOD _ADD(_xx integer, _yy integer, _zz integer, _qq integer) returns integer
       specific DB.DBA.static2_add,
  OVERRIDING METHOD ADDIT() returns integer specific DB.DBA.add2_them1,
  METHOD MULTIPLY_IT () returns integer;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": subtype UDT_TEST_SUB declared STATE=" $STATE " MESSAGE=" $MESSAGE "\n";


create static method _ADD (in _xx integer,in _yy integer,in _zz integer,in _qq integer) for UDT_TEST_SUB
{
  return _xx + _yy + _zz + _qq;
}
;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": static method (same name different args) for UDT_TEST_SUB defined STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create method ADDIT () for UDT_TEST_SUB
{
  return UDT_TEST_SUB::_ADD (A(SELF), B(SELF), C(SELF), _D(SELF));
}
;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": overloading method for UDT_TEST_SUB defined STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create method MULTIPLY_IT () for UDT_TEST_SUB
{
  return A(SELF) * B(SELF) * C(SELF) * _D(SELF);
}
;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": dynamic method for UDT_TEST_SUB defined STATE=" $STATE " MESSAGE=" $MESSAGE "\n";


-- tests

select A(UDT_TEST());
ECHO BOTH $IF $EQU $LAST[1] -1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": testing observer for the base type returned " $LAST[1]"\n";

select A(UDT_TEST_SUB());
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": testing observer for the subtype returned " $LAST[1]"\n";

select A(A(UDT_TEST(), -100));
ECHO BOTH $IF $EQU $LAST[1] -100 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": testing mutator for the base type returned " $LAST[1]"\n";

select A(A(UDT_TEST_SUB(), -100));
ECHO BOTH $IF $EQU $LAST[1] -100 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": testing mutator for the subtype returned " $LAST[1]"\n";

--explain ('
create procedure TEST_OVERLOAD (in xx UDT_TEST) returns integer
{
  return xx.ADDIT ();
}
--')
;

select TEST_OVERLOAD (UDT_TEST());
ECHO BOTH $IF $EQU $LAST[1] -3 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": testing overloaded method for the base type returned " $LAST[1]"\n";

select TEST_OVERLOAD (UDT_TEST_SUB());
ECHO BOTH $IF $EQU $LAST[1] 47 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": testing overloaded method for the subtype returned " $LAST[1]"\n";

select UDT_TEST_SUB::_ADD (22, 33);
ECHO BOTH $IF $EQU $LAST[1] 55 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": testing inherited static method for the subtype returned " $LAST[1]"\n";

select UDT_TEST_SUB::_ADD (22, 33, 44, 55);
ECHO BOTH $IF $EQU $LAST[1] 154 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": testing local static method for the subtype returned " $LAST[1]"\n";

select UDT_TEST_SUB().MULTIPLY_IT();
ECHO BOTH $IF $EQU $LAST[1] 768 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": testing local method for the subtype returned " $LAST[1]"\n";

create procedure TEST_OVERLOAD_FLD (in xx UDT_TEST) returns integer
{
  return A(xx);
}
;

select TEST_OVERLOAD_FLD (UDT_TEST());
ECHO BOTH $IF $EQU $LAST[1] -1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": testing overloaded member access for the base type returned " $LAST[1]"\n";

select TEST_OVERLOAD_FLD (UDT_TEST_SUB())
;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": testing overloaded member access for the subtype returned " $LAST[1]"\n";

create table UDT_TEST_TBL (id integer primary key, data UDT_TEST);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": column of type UDT_TEST STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

insert into UDT_TEST_TBL (id, data) values (1, UDT_TEST());
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": inserted value into UDT_TEST column STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

insert into UDT_TEST_TBL (id, data) values (2, NULL);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": inserted NULL value into UDT_TEST column STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

insert into UDT_TEST_TBL (id, data) values (3, UDT_TEST_SUB());
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": inserted udt value into UDT_TEST column STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

insert into UDT_TEST_TBL (id, data) values (4, 44);
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": inserted wrong (int) value into UDT_TEST column STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select A(data) from UDT_TEST_TBL where id = 1;
ECHO BOTH $IF $EQU $LAST[1] -1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": retrieved value from UDT_TEST column = " $LAST[1] "\n";

select x.data.A from UDT_TEST_TBL x where x.id = 1;
ECHO BOTH $IF $EQU $LAST[1] -1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": using .MEMBER for UDT_TEST column = " $LAST[1] "\n";

select x.data.addit() from UDT_TEST_TBL x where x.id = 1;
ECHO BOTH $IF $EQU $LAST[1] -3 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": using .method() for UDT_TEST column = " $LAST[1] "\n";

select data.A from UDT_TEST_TBL where id = 1;
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": no corelation name for .MEMBER STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select new UDT_TEST().A;
ECHO BOTH $IF $EQU $LAST[1] -1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": using .MEMBER for UDT_TEST column = " $LAST[1] "\n";

create procedure TEST_DOT_NOTATION ()
{
  declare uu UDT_TEST;

  uu := new UDT_TEST();

  uu.A := 40;

  uu.B := uu.A + 10;

  return (uu.A  + uu.B);
};

select TEST_DOT_NOTATION();
ECHO BOTH $IF $EQU $LAST[1] 90 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": using .MEMBER for observers & mutators = " $LAST[1] "\n";

create procedure TEST_NO_RETS ()
{
  declare uu UDT_TEST;

  uu := new UDT_TEST();

  UDT_TEST();

  A(uu, 12);
};

ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": missing various return slots STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create type UDT_INOUT_TEST
as
  (A integer default 1,
   B integer default 2)
;

create procedure CHANGE_IT (inout z integer)
{
  z := z + 1000;
};

create procedure UDT_INOUT_TEST_PROC ()
{
  declare dt UDT_INOUT_TEST;
  dt := new UDT_INOUT_TEST();

  CHANGE_IT (dt.A);
  return dt.A;
};

select UDT_INOUT_TEST_PROC();
ECHO BOTH $IF $EQU $LAST[1] 1001 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": inout directly to udt member returned " $LAST[1] "\n";


--- temporary classes
create type DB.DBA.UDT_TEMP AS (A integer default -1) temporary
method getA () returns integer,
method setA (new_a integer) returns integer,
method setA (new_a varchar) returns integer;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": temporary class created STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select * from SYS_USER_TYPES where UT_NAME = 'DB.DBA.UDT_TEMP';
ECHO BOTH $IF $EQU $ROWCNT 0 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": temporary class records into SYS_USER_TYPES ROWCNT=" $ROWCNT "\n";

create method getA() returns integer for DB.DBA.UDT_TEMP
{
  return SELF.A;
};
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": method getA created STATE=" $STATE " MESSAGE=" $MESSAGE "\n";


create method setA(in new_a integer) returns integer for DB.DBA.UDT_TEMP
{
  declare old_a integer;
  old_a := SELF.A;
  SELF.A := new_a;
  return old_a;
};
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": method setA (int) created STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select new DB.DBA.UDT_TEMP ().setA(cast (1 as integer));
ECHO BOTH $IF $EQU $LAST[1] -1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": method setA (int) called return=" $LAST[1] "\n";

select new DB.DBA.UDT_TEMP ().setA(cast (1 as varchar));
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": method setA (varchar) not defined STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select new DB.DBA.UDT_TEMP ().setA(cast (1 as double precision));
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": ambigulty in calling method setA (double precision) STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create method setA(in new_a varchar) returns integer for DB.DBA.UDT_TEMP
{
  SELF.A := atoi (new_a);
  return SELF.A;
};
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": method setA (varchar) created STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select new DB.DBA.UDT_TEMP ().setA(cast (1 as varchar));
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": method setA (varchar) called STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create type SUB_UDT_TEMP under DB.DBA.UDT_TEMP as (B integer);
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": persistent subtype of a temp type STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create type SUB_UDT_TEST_TEMP under UDT_TEST as (B integer) temporary;
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": temp subtype of a persistent type STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

--create type UDT_JAVA under DB.DBA.UDT_TEMP language java external name 'dummy' as (A integer) temporary;
--ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
--SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
--ECHO BOTH ": JAVA subtype of a SQL type STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create type UDT_JAVA language java external name 'dummy' as (A integer) temporary method xx() returns integer;
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": JAVA type created STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

-- the UDT_JAVA cannot be created by the current binary so the test is void
--create type UDT_SQL under UDT_JAVA language SQL as (B integer) temporary;
--ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
--SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
--ECHO BOTH ": SQL subtype of a JAVA type STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

--create type UDT_SQL under UDT_JAVA as (B integer) temporary;
--ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
--SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
--ECHO BOTH ": unspecified lang := SQL STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

--create method xx () returns integer for UDT_JAVA
--{
--  return SELF.B;
--};
--ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
--SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
--ECHO BOTH ": SQL method for JAVA class STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create procedure TEST_ASET()
{
  declare inst DB.DBA.UDT_TEMP;

  inst := new DB.DBA.UDT_TEMP();

  inst.A := vector (0);
  aset (inst.A, 0, 12);
  return inst.A[0];
};

-- XXX: we need to have aset on variables derived from observer,
-- as there is no way to distinguish between varables and observers
-- we we'll allow it for now!
--select TEST_ASET();
--ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
--SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
--ECHO BOTH ": aset w/ member observer STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

explain ('
create procedure TEST_SETTABLE()
{
  declare inst DB.DBA.UDT_TEMP;
  declare msg any;

  inst := new DB.DBA.UDT_TEMP();

  exec (''signal (''''state'''', ''''message'''')'', inst.A, msg);
  return inst.A;
}');

select TEST_SETTABLE();
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": member observer result is not settable in BIFs STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create type UDT_REF_CLASS as (A integer default -2) temporary self as ref
constructor method UDT_REF_CLASS (new_a integer);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": self as ref class created STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create constructor method UDT_REF_CLASS (in new_a integer) for UDT_REF_CLASS
{
  SELF.A := new_a;
};

create procedure refs_tryout ()
{
  declare inst1 UDT_REF_CLASS;
  inst1 := new UDT_REF_CLASS(33);

  if (inst1.A <> 33)
    signal ('tsudt', 'Constructor not called');

  inst1 := new UDT_REF_CLASS();
  if (inst1.A <> -2)
    signal ('tsudt', 'implicit constructor not setting default values');

  inst1.A := 12;
  return inst1.A;
};
select refs_tryout ();
ECHO BOTH $IF $EQU $LAST[1] 12 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": trying all the ops w/ ref class STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create procedure modify_refs ()
{
  declare inst1, inst2 UDT_REF_CLASS;
  inst1 := new UDT_REF_CLASS();
  inst2 := inst1;

  inst1.A := 12;
  return inst2.A;
};
select modify_refs ();
ECHO BOTH $IF $EQU $LAST[1] 12 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": modifying a member visible trough copied ref =" $LAST[1] "\n";

create procedure modify_non_refs ()
{
  declare inst1, inst2 UDT_TEST;
  inst1 := new UDT_TEST();
  inst2 := inst1;

  inst1.A := 12;
  return inst2.A;
};
select modify_non_refs ();
ECHO BOTH $IF $EQU $LAST[1] -1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": modifying a member not visible trough copied instance =" $LAST[1] "\n";

create procedure test_instance_of (in udt UDT_TEST)
{
  declare class_name varchar;
  declare instance_of_UDT_TEST_SUB integer;
  result_names (class_name, instance_of_UDT_TEST_SUB);

  class_name := udt_instance_of (udt);
  instance_of_UDT_TEST_SUB := udt_instance_of (udt, 'UDT_TEST_SUB');
  result (class_name, instance_of_UDT_TEST_SUB);
};
test_instance_of (new UDT_TEST());
ECHO BOTH $IF $EQU $LAST[1] "DB.DBA.UDT_TEST" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": instance class is =" $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[2] 0 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": is instance of UDT_TEST_SUB =" $LAST[2] "\n";

test_instance_of (new UDT_TEST_SUB());
ECHO BOTH $IF $EQU $LAST[1] "DB.DBA.UDT_TEST_SUB" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": instance class is =" $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[2] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": is instance of UDT_TEST_SUB =" $LAST[2] "\n";

select (new UDT_TEST () as UDT_TEST_SUB).MULTIPLY_IT();
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": forced cast syntax in method call for wrong class STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select (new UDT_TEST_SUB () as UDT_TEST_SUB).MULTIPLY_IT();
ECHO BOTH $IF $EQU $LAST[1] 768 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": forced cast syntax for method call returned =" $LAST[1] "\n";

select (new UDT_TEST () as UDT_TEST_SUB).C;
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": forced cast syntax in member observer for wrong class STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select (new UDT_TEST_SUB () as UDT_TEST_SUB).C;
ECHO BOTH $IF $EQU $LAST[1] 12 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": forced cast syntax for member observer returned =" $LAST[1] "\n";

create procedure forced_cast_try (in udt UDT_TEST)
{
  declare _c integer;
  _c := (udt as UDT_TEST_SUB).C;
  (udt as UDT_TEST_SUB).C := _c + 1;
  (new UDT_TEST_SUB() as UDT_TEST_SUB).C := _c + 1;
  return (udt as UDT_TEST_SUB).MULTIPLY_IT();
};
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": forced cast syntax proc created STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select forced_cast_try (new UDT_TEST_SUB());
ECHO BOTH $IF $EQU $LAST[1] 832 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": forced cast syntax returned =" $LAST[1] "\n";

select forced_cast_try (new UDT_TEST());
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": forced cast syntax for wrong class STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create procedure test_observers ()
{
  declare udt UDT_TEST_SUB;
  udt := new UDT_TEST_SUB ();
  declare ret integer;

  ret := udt.C;
  ret := UDT_TEST_SUB().C;
  ret := (udt as UDT_TEST_SUB).C;
  ret := (UDT_TEST_SUB() as UDT_TEST_SUB).C;
};
test_observers();
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": various observer forms in Virtuoso/PL STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create procedure test_mutators ()
{
  declare udt UDT_TEST_SUB;
  udt := new UDT_TEST_SUB ();
  declare ret integer;

  C(udt, 1);
  udt := C(udt, 1);
  UDT_TEST_SUB().C := 1;
  (udt as UDT_TEST_SUB).C := 1;
  (UDT_TEST_SUB() as UDT_TEST_SUB).C := 1;
};
test_mutators();
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": various mutator forms in Virtuoso/PL STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

--explain ('
METHOD CALL UDT_TEST_SUB().MULTIPLY_IT()
--')
;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": top level dynamic method STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

--explain ('
METHOD CALL UDT_TEST::_ADD(1, 2)
--')
;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": top level static method STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select udt_defines_field ('UDT_TEST', 'A');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": checking for member using string names =" $LAST[1] "\n";

select udt_defines_field ('UDT_TEST', 'C');
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": checking for non-existent member using string names =" $LAST[1] "\n";

select udt_defines_field ('UDT_TEST_SUB', 'A');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": checking for inherited member using string names =" $LAST[1] "\n";

select udt_defines_field ('UDT_TEST_SUB', 'C');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": checking for local subclass member using string names =" $LAST[1] "\n";

select udt_defines_field (UDT_TEST(), 'A');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": checking for member using instance =" $LAST[1] "\n";

select udt_defines_field (UDT_TEST(), 'C');
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": checking for non-existent member using instance =" $LAST[1] "\n";

select udt_defines_field (UDT_TEST_SUB(), 'A');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": checking for inherited member using instance =" $LAST[1] "\n";

select udt_defines_field (UDT_TEST_SUB(), 'C');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": checking for local subclass member using instance =" $LAST[1] "\n";

select udt_get (UDT_TEST(), 'C');
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": getting a non-existent field STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select udt_get (UDT_TEST(), 'A');
ECHO BOTH $IF $EQU $LAST[1] -1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": getting field value =" $LAST[1] "\n";

select udt_get (UDT_TEST_SUB(), 'A');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": getting inherited field value =" $LAST[1] "\n";

select udt_set (UDT_TEST(), 'C', 12);
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": setting a non-existent field STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select udt_get (udt_set (UDT_TEST(), 'A', 12), 'A');
ECHO BOTH $IF $EQU $LAST[1] 12 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": getting field value =" $LAST[1] "\n";

select udt_get (udt_set (UDT_TEST_SUB(), 'A', 12), 'A');
ECHO BOTH $IF $EQU $LAST[1] 12 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": getting inherited field value =" $LAST[1] "\n";

create procedure test_and_run_method (in cls any, in method_name varchar)
{
  declare mtd_ptr, ret any;
  declare exist integer;
  mtd_ptr := udt_implements_method (cls, method_name);
  exist := 0;
  result_names (exist, ret);
  if (mtd_ptr <> 0)
    exist := 1;
  if (mtd_ptr <> 0 and isstring (cls) = 0)
    {
      ret := call (mtd_ptr) (cls);
    }
  result (exist, ret);
};

CALL test_and_run_method ('UDT_TEST', 'MULTIPLY_IT');
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": check method MULTIPLY_IT in UDT_TEST returned =" $LAST[1] "\n";

CALL test_and_run_method ('UDT_TEST', '_ADD');
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": check static method _ADD in UDT_TEST returned =" $LAST[1] "\n";

CALL test_and_run_method ('UDT_TEST', 'SUB_IT');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": check method SUB_IT in UDT_TEST returned =" $LAST[1] "\n";

CALL test_and_run_method ('UDT_TEST_SUB', 'SUB_IT');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": check method SUB_IT in UDT_TEST_SUB returned =" $LAST[1] "\n";

CALL test_and_run_method ('UDT_TEST_SUB', 'MULTIPLY_IT');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": check method MULTIPLY_IT in UDT_TEST_SUB returned =" $LAST[1] "\n";



CALL test_and_run_method (UDT_TEST(), 'MULTIPLY_IT');
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": check method MULTIPLY_IT in UDT_TEST inst returned =" $LAST[1] "\n";

CALL test_and_run_method (UDT_TEST(), '_ADD');
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": check static method _ADD in UDT_TEST inst returned =" $LAST[1] "\n";

CALL test_and_run_method (UDT_TEST(), 'SUB_IT');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": check method SUB_IT in UDT_TEST inst returned =" $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[2] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": result from method SUB_IT in UDT_TEST inst =" $LAST[1] "\n";

CALL test_and_run_method (UDT_TEST_SUB(), 'SUB_IT');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": check method SUB_IT in UDT_TEST_SUB inst returned =" $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[2] -1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": result from method SUB_IT in UDT_TEST_SUB =" $LAST[2] "\n";

CALL test_and_run_method (UDT_TEST_SUB(), 'MULTIPLY_IT');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": check method MULTIPLY_IT in UDT_TEST_SUB inst returned =" $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[2] 768 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": result from method MULTIPLY_IT in UDT_TEST_SUB inst =" $LAST[2] "\n";

create table UDT_TEMP_TB (id int primary key, tdata DB.DBA.UDT_TEMP);
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": not able to create a column of temp type STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create table UDT_ANY_TB (ID int primary key, ADATA any);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": table w/ ANY column created STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

insert into UDT_ANY_TB (ID, ADATA) values (1, UDT_TEST());
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": inserting instance into ANY col STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select (ADATA as UDT_TEST).A from UDT_ANY_TB where ID = 1;
ECHO BOTH $IF $EQU $LAST[1] -1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": deserializing instance from ANY column STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

insert into UDT_ANY_TB (ID, ADATA) values (2, DB.DBA.UDT_TEMP ());
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": inserting temp instance into ANY col STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select udt_instance_of (ADATA) from UDT_ANY_TB where ID = 2;
ECHO BOTH $IF $EQU $LAST[1] 'DB.DBA.SYS_SERIALIZATION_ERROR' "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": deserializing temp instance shows it wrote " $LAST[1] "\n";

create type UDT_FR_BASE UNDER UDT_FR_SUPER as (A int default 11, UDT_M UDT_FR_COL)
    constructor method UDT_FR_BASE (a int, b int);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": creating an non-instantiable class STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select new UDT_FR_BASE ();
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": constructor call failed STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create type UDT_FR_COL language JAVA as (B int default 12);
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": forward reference defined as different language STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create type UDT_FR_SUPER as (S int default 12);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": forward reference for super defined STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select new UDT_FR_BASE ().A;
ECHO BOTH $IF $EQU $LAST[1] 11 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": UDT_FR_BASE now instantiable A=" $LAST[1] "\n";

select new UDT_FR_BASE ().UDT_M;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": accessing a FR member STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create type UDT_FR_COL as (B int default 12);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": column FR defined STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create constructor method UDT_FR_BASE (in a int, in b int) for UDT_FR_BASE
{
  declare new_udt_m UDT_FR_COL;
  new_udt_m := new UDT_FR_COL();
  new_udt_m.B := b;

  SELF.A := a;
  SELF.UDT_M := new_udt_m;
};

select new UDT_FR_BASE (1, 2).UDT_M.B;
ECHO BOTH $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": accessing an udt member's member =" $LAST[1] "\n";

create type UDT_BM_BASE
  method GET_ID () returns integer;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": UDT_BM_BASE created STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create type UDT_BM_SUB under UDT_BM_BASE
  overriding method GET_ID () returns integer;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": UDT_BM_SUB created STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create method GET_ID () returns integer for UDT_BM_BASE
{
  return 12;
};
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": GET_ID for UDT_BM_BASE created STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create method GET_ID () returns integer for UDT_BM_SUB
{
  return (SELF as UDT_BM_BASE).GET_ID() * 2;
};
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": GET_ID for UDT_BM_SUB calling it's parent's GET_ID defined STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select new UDT_BM_SUB().GET_ID();
ECHO BOTH $IF $EQU $LAST[1] 24 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": calling parent overloaded method returned =" $LAST[1] "\n";

drop table UDT_DOT_TB;
drop type UDT_DOT;
drop type UDT_DOT_SUB;
create type UDT_DOT_SUB as (A integer default 1, B integer default 2)
  method do_it () returns integer;
create type UDT_DOT as (A UDT_DOT_SUB, B integer default 3)
  constructor method UDT_DOT ();

create method do_it () returns integer for UDT_DOT_SUB
{
  return self.A + self.B;
};

create constructor method UDT_DOT () for UDT_DOT
{
  self.A := new UDT_DOT_SUB ();
};

create table UDT_DOT_TB (ID int primary key, DATA UDT_DOT);

insert into UDT_DOT_TB values (1, new UDT_DOT());

select (DB.DBA.UDT_DOT_TB.DATA as UDT_DOT).A.A from UDT_DOT_TB;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": dot notation returned =" $LAST[1] "\n";

select (DB.DBA.UDT_DOT_TB.DATA.A as UDT_DOT_SUB).A from UDT_DOT_TB;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": dot notation 2 returned =" $LAST[1] "\n";

select DB.DBA.UDT_DOT_TB.DATA.A.A from UDT_DOT_TB;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": dot notation 3 returned =" $LAST[1] "\n";

select C.DATA.A.A from UDT_DOT_TB C;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": dot notation 4 returned =" $LAST[1] "\n";

select (C.DATA.A as UDT_DOT_SUB).A from UDT_DOT_TB C;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": dot notation 5 returned =" $LAST[1] "\n";


select (DB.DBA.UDT_DOT_TB.DATA as UDT_DOT).A.DO_IT() from UDT_DOT_TB;
ECHO BOTH $IF $EQU $LAST[1] 3 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": dot method_call 1 returned =" $LAST[1] "\n";

select (DB.DBA.UDT_DOT_TB.DATA.A as UDT_DOT_SUB).DO_IT() from UDT_DOT_TB;
ECHO BOTH $IF $EQU $LAST[1] 3 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": dot method_call 2 returned =" $LAST[1] "\n";

select DB.DBA.UDT_DOT_TB.DATA.A.DO_IT() from UDT_DOT_TB;
ECHO BOTH $IF $EQU $LAST[1] 3 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": dot method_call 3 returned =" $LAST[1] "\n";

select C.DATA.A.DO_IT() from UDT_DOT_TB C;
ECHO BOTH $IF $EQU $LAST[1] 3 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": dot method_call 4 returned =" $LAST[1] "\n";

select (C.DATA.A as UDT_DOT_SUB).DO_IT() from UDT_DOT_TB C;
ECHO BOTH $IF $EQU $LAST[1] 3 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": dot method_call 5 returned =" $LAST[1] "\n";


drop type UDT_ALTER_TYPE;
create type UDT_ALTER_TYPE as (A integer default 1)
    method M1 (i integer) returns integer;
create method M1 (in i integer) returns integer for UDT_ALTER_TYPE
{
  return i;
};

select new UDT_ALTER_TYPE().A;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": UDT_ALTER_TYPE().A returned =" $LAST[1] "\n";

alter type UDT_ALTER_TYPE add attribute A integer default 2;
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": add another A to UDT_ALTER_TYPE STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select new UDT_ALTER_TYPE().M1 (1);
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": UDT_ALTER_TYPE().M1(1) returned =" $LAST[1] "\n";

select new UDT_ALTER_TYPE().A;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": UDT_ALTER_TYPE().A returned =" $LAST[1] "\n";

alter type UDT_ALTER_TYPE add attribute B integer default 2;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": add B to UDT_ALTER_TYPE STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select new UDT_ALTER_TYPE().A;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": UDT_ALTER_TYPE().A returned =" $LAST[1] "\n";

select new UDT_ALTER_TYPE().B;
ECHO BOTH $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": UDT_ALTER_TYPE().B returned =" $LAST[1] "\n";

select new UDT_ALTER_TYPE().M1 (1);
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": UDT_ALTER_TYPE().M1(1) returned =" $LAST[1] "\n";

select new UDT_ALTER_TYPE().M1 (2);
ECHO BOTH $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": UDT_ALTER_TYPE().M1(2) returned =" $LAST[1] "\n";

alter type UDT_ALTER_TYPE drop attribute C;
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": drop non-existant attribute STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

alter type UDT_ALTER_TYPE drop attribute A;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": drop A from UDT_ALTER_TYPE STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select new UDT_ALTER_TYPE().A;
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": UDT_ALTER_TYPE().A returned STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select new UDT_ALTER_TYPE().B;
ECHO BOTH $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": UDT_ALTER_TYPE().B returned =" $LAST[1] "\n";

select new UDT_ALTER_TYPE().B + 0;
ECHO BOTH $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": recompile UDT_ALTER_TYPE().B returned =" $LAST[1] "\n";

select count (*) from SYS_USER_TYPES where UT_NAME like '%.UDT_ALTER_TYPE__%' and UT_MIGRATE_TO is not null;
ECHO BOTH $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": count (*) obsolete types returned =" $LAST[1] "\n";

alter type UDT_ALTER_TYPE add method M1 (id integer) returns integer;
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": adding duplicate method STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

alter type UDT_ALTER_TYPE add method M2 (id integer) returns integer;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": adding method M2 STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create method M2 (in id integer) returns integer for UDT_ALTER_TYPE
{
  return id + 100;
};
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": declaring method M2 STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select count (*) from SYS_USER_TYPES where UT_NAME like '%.UDT_ALTER_TYPE__%' and UT_MIGRATE_TO is not null;
ECHO BOTH $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": count (*) obsolete types returned =" $LAST[1] "\n";

select new UDT_ALTER_TYPE().M1 (1);
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": calling original M1 returned =" $LAST[1] "\n";

select new UDT_ALTER_TYPE().M2 (1);
ECHO BOTH $IF $EQU $LAST[1] 101 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": calling M2 returned =" $LAST[1] "\n";

alter type UDT_ALTER_TYPE add method M1 (id float) returns float;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": adding method M1 (float) STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create method M1 (in id float) returns float for UDT_ALTER_TYPE
{
  return id + 2.0;
};
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": declaring method M1 (float) STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select new UDT_ALTER_TYPE().M1 (cast (3 as float));
ECHO BOTH $IF $EQU $LAST[1] 5 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": calling M1(float = 3) returned =" $LAST[1] "\n";

alter type UDT_ALTER_TYPE drop method M1 (id integer) returns integer;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": dropping method M1 (int) STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select new UDT_ALTER_TYPE().M1 (4);
ECHO BOTH $IF $EQU $LAST[1] 6 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": calling M1 (4) (qr cached) returned =" $LAST[1] "\n";

select new UDT_ALTER_TYPE().M2 (1);
ECHO BOTH $IF $EQU $LAST[1] 101 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": calling M2 returned =" $LAST[1] "\n";

drop type UDT_ALTER_TYPE;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": dropping UDT_ALTER_TYPE STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select count (*) from SYS_USER_TYPES where UT_NAME like '%.UDT_ALTER_TYPE%';
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": DROP TYPE cleaning the obsolete types returned =" $LAST[1] "\n";

-- inheritance in ALTER type
drop type UDT_ALTER_SUB;
drop type UDT_ALTER_T;

create type UDT_ALTER_T as (A integer default 1);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": creating UDT_ALTER_T STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create type UDT_ALTER_SUB under UDT_ALTER_T as (B integer default 2);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": creating UDT_ALTER_SUB STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select new UDT_ALTER_SUB().A;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": access the super's attr from subtype returned =" $LAST[1] "\n";

alter type UDT_ALTER_T add method M1 (i int) returns int;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": declaring method M1 to UDT_ALTER_T STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create method M1 (in i int) returns int for UDT_ALTER_T
{
  return i;
};
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": defining method M1 to UDT_ALTER_T STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select new UDT_ALTER_T().M1 (10);
ECHO BOTH $IF $EQU $LAST[1] 10 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": calling UDT_ALTER_T.M1 (10) returned =" $LAST[1] "\n";

select new UDT_ALTER_SUB().M1 (10);
ECHO BOTH $IF $EQU $LAST[1] 10 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": calling UDT_ALTER_SUB.M1 (10) returned =" $LAST[1] "\n";

select count (*) from SYS_USER_TYPES where UT_NAME like '%.UDT_ALTER_SUB%' and UT_MIGRATE_TO is not null;
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": # obsolete types for UDT_ALTER_SUB returned =" $LAST[1] "\n";

alter type UDT_ALTER_T add attribute B integer default 3;
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": adding B to UDT_ALTER_T clashes w/ B in UDT_ALTER_SUB STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

alter type UDT_ALTER_T add attribute C integer default 3;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": adding C to UDT_ALTER_T STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select new UDT_ALTER_T().C;
ECHO BOTH $IF $EQU $LAST[1] 3 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": checking the access to C in UDT_ALTER_T =" $LAST[1] "\n";

select new UDT_ALTER_SUB().C;
ECHO BOTH $IF $EQU $LAST[1] 3 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": checking the access to C in UDT_ALTER_SUB =" $LAST[1] "\n";

select count (*) from SYS_USER_TYPES where UT_NAME like '%.UDT_ALTER_SUB%' and UT_MIGRATE_TO is not null;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": # obsolete types for UDT_ALTER_SUB after parent change returned =" $LAST[1] "\n";

-- udt instance migration test
drop table UDT_ALTER_TABLE;
drop type UDT_ALTER_PERS;

create type UDT_ALTER_PERS as (A integer default 1);
create table UDT_ALTER_TABLE (ID int primary key, DATA UDT_ALTER_PERS);

insert into UDT_ALTER_TABLE (ID, DATA) values (1, new UDT_ALTER_PERS());

alter type UDT_ALTER_PERS add attribute B integer default 2;
insert into UDT_ALTER_TABLE (ID, DATA) values (2, new UDT_ALTER_PERS());

alter type UDT_ALTER_PERS add attribute C integer default 3;
insert into UDT_ALTER_TABLE (ID, DATA) values (3, new UDT_ALTER_PERS());

select C.DATA.A from UDT_ALTER_TABLE C where C.ID = 3;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": deserializing a fresh instance returned A =" $LAST[1] "\n";

select C.DATA.B from UDT_ALTER_TABLE C where C.ID = 3;
ECHO BOTH $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": deserializing a fresh instance returned B =" $LAST[1] "\n";

select C.DATA.C from UDT_ALTER_TABLE C where C.ID = 3;
ECHO BOTH $IF $EQU $LAST[1] 3 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": deserializing a fresh instance returned B =" $LAST[1] "\n";

select C.DATA.A from UDT_ALTER_TABLE C where C.ID = 2;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": deserializing one old instance returned A =" $LAST[1] "\n";

select C.DATA.B from UDT_ALTER_TABLE C where C.ID = 2;
ECHO BOTH $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": deserializing one old instance returned B =" $LAST[1] "\n";

select C.DATA.C from UDT_ALTER_TABLE C where C.ID = 2;
ECHO BOTH $IF $EQU $LAST[1] 3 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": deserializing one old instance returned B =" $LAST[1] "\n";

select C.DATA.A from UDT_ALTER_TABLE C where C.ID = 1;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": deserializing two old instance returned A =" $LAST[1] "\n";

select C.DATA.B from UDT_ALTER_TABLE C where C.ID = 1;
ECHO BOTH $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": deserializing two old instance returned B =" $LAST[1] "\n";

select C.DATA.C from UDT_ALTER_TABLE C where C.ID = 1;
ECHO BOTH $IF $EQU $LAST[1] 3 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": deserializing two old instance returned B =" $LAST[1] "\n";


drop type dropt_t2;
drop type dropt_t1;

create type dropt_t1 as (a int);
create type dropt_t2 under dropt_t1 as (b int);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": drop type check types created STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

drop type dropt_t1;
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": drop supertype w/ a sub-type STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

drop type B4928;
create type B4928 as (COMPANY_NAME_MASK varchar default 'C')
temporary self as ref
method CURSOR_METHOD () returns varchar
;

create method CURSOR_METHOD () returns varchar for B4928
{
  declare xx,yy any;
  declare cr keyset cursor for
         select
	   SELF.COMPANY_NAME_MASK from SYS_USERS;
  open cr;
  fetch cr first into yy;
  return yy;
}

select new B4928().CURSOR_METHOD ();
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": 4928: observer in PL scrollable cursor STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

drop type MUTATOR_FETCH_T;
create type MUTATOR_FETCH_T as
(D1 integer)
temporary self as ref;

drop type MUTATOR_FETCH_T2;
create type MUTATOR_FETCH_T2 as
(T1 MUTATOR_FETCH_T)
temporary self as ref
;

drop type MUTATOR_FETCH_T3;
create type MUTATOR_FETCH_T3 as
(T2 MUTATOR_FETCH_T2)
temporary self as ref;

create procedure MUTATOR_FETCH1 ()
{
  declare xxi MUTATOR_FETCH_T;
  xxi := new MUTATOR_FETCH_T ();

  declare cr cursor for select 2 from SYS_USERS;
  open cr;
  fetch cr into xxi.D1;
  close cr;

  return xxi.D1;
};

create procedure MUTATOR_FETCH2 ()
{
  declare xxi MUTATOR_FETCH_T2;
  xxi := new MUTATOR_FETCH_T2 ();
  xxi.T1 := new MUTATOR_FETCH_T();

  declare cr cursor for select 2 from SYS_USERS;
  open cr;
  fetch cr into xxi.T1.D1;
  close cr;

  return xxi.T1.D1;
}
;

create procedure MUTATOR_FETCH3 ()
{
  declare xxi MUTATOR_FETCH_T3;
  xxi := new MUTATOR_FETCH_T3 ();
  xxi.T2 := new MUTATOR_FETCH_T2 ();
  xxi.T2.T1 := new MUTATOR_FETCH_T();

  declare cr cursor for select 2 from SYS_USERS;
  open cr;
  fetch cr into xxi.T2.T1.D1;
  close cr;

  return xxi.T2.T1.D1;
}
;

create procedure MUTATOR_FETCH4 ()
{
  declare xxi MUTATOR_FETCH_T3;
  xxi := new MUTATOR_FETCH_T3 ();
  xxi.T2 := new MUTATOR_FETCH_T2 ();
  xxi.T2.T1 := new MUTATOR_FETCH_T();

  select top 1 2 into xxi.T2.T1.D1 from SYS_USERS;
  return xxi.T2.T1.D1;
}
;

select MUTATOR_FETCH1 (), MUTATOR_FETCH2 (), MUTATOR_FETCH3 (), MUTATOR_FETCH4 ();
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": observer in FETCH .. INTO .. STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

drop procedure MPU_G1;
drop module MPU_G1;
drop type MPU_G1;


create procedure MPU_G1 () {;};
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": procedure MPU_G1 created STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create procedure MPU_G1 () {;};
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": procedure MPU_G1 overwritten STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create module MPU_G1 { procedure G2 () {;}; };
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": no module MPU_G1 created STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create type MPU_G1 as (XX int);
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": no type MPU_G1 created STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

drop procedure MPU_G1;

create type MPU_G1 as (XX int);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": type MPU_G1 created STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create type MPU_G1 as (XX int);
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": no type MPU_G1 overwritten STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create module MPU_G1 { procedure G2 () {;}; };
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": no module MPU_G1 created STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create procedure MPU_G1 () {;};
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": no procedure MPU_G1 created STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

drop type MPU_G1;

create module MPU_G1 { procedure G2 () {;}; };
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": module MPU_G1 created STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create
type MPU_G1 as (XX int);
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": no type MPU_G1 overwritten STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create module MPU_G1 { procedure G2 () {;}; };
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": no module MPU_G1 created STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create procedure MPU_G1 () {;};
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": no procedure MPU_G1 created STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create type UDT_TEST_BLOB under UDT_TEST as (DATA varchar)
    CONSTRUCTOR METHOD UDT_TEST_BLOB ();

create constructor method UDT_TEST_BLOB () for UDT_TEST_BLOB
{
  A(SELF, -1);
  B(SELF, -2);
  DATA(SELF, repeat ('a', 20000));
};

create table UDT_TEST_BLOB_TBL (id integer primary key, data LONG UDT_TEST_BLOB);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": blob column of type UDT_TEST_BLOB STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

insert into UDT_TEST_BLOB_TBL (id, data) values (1, UDT_TEST_BLOB());
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": inserted value into UDT_TEST_BLOB blob column STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

insert into UDT_TEST_BLOB_TBL (id, data) values (2, NULL);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": inserted NULL value into UDT_TEST_BLOB blob column STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

insert into UDT_TEST_BLOB_TBL (id, data) values (4, 44);
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": inserted wrong (int) value into UDT_TEST_BLOB blob column STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select A(data) from UDT_TEST_BLOB_TBL where id = 1;
ECHO BOTH $IF $EQU $LAST[1] -1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": retrieved value from UDT_TEST_BLOB blob column = " $LAST[1] "\n";

select x.data.A from UDT_TEST_BLOB_TBL x where x.id = 1;
ECHO BOTH $IF $EQU $LAST[1] -1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": using .MEMBER for UDT_TEST_BLOB blob column = " $LAST[1] "\n";

select x.data.addit() from UDT_TEST_BLOB_TBL x where x.id = 1;
ECHO BOTH $IF $EQU $LAST[1] -3 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": using .method() for UDT_TEST_BLOB blob column = " $LAST[1] "\n";

select data.A from UDT_TEST_BLOB_TBL where id = 1;
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": no corelation name for .MEMBER STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

insert into UDT_TEST_TBL (id, data) values (4, new UDT_TEST_BLOB ());
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": inserted too large value into UDT_TEST column STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

drop table B5312_TB1;
drop table B5312_TB2;
drop type B5312_TYPEA;

create type B5312_TYPEA as (ID int)
constructor method B5312_TYPEA (ID int)
;

create constructor method B5312_TYPEA (in ID int) for B5312_TYPEA
{
  self.ID := ID;
}
;

create table B5312_TB1 (ID int, DT long B5312_TYPEA);

insert into B5312_TB1 values (1, B5312_TYPEA (1));

select B5312_TB1.DT.ID from B5312_TB1 order by ID;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": B5312: LONG UDT temp ser STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

drop table UDTOBYTEST_TB;

drop type UDTOBYTEST;
create type UDTOBYTEST as (A integer, B varchar)
constructor method UDTOBYTEST (A integer, B varchar);

create constructor method UDTOBYTEST (in A integer, in B varchar) for UDTOBYTEST
  {
    SELF.A := A;
    SELF.B := B;
  };

create table UDTOBYTEST_TB (ID integer primary key, DATA UDTOBYTEST);

insert into UDTOBYTEST_TB values (1, new UDTOBYTEST (1, 'a'));
insert into UDTOBYTEST_TB values (2, new UDTOBYTEST (2, 'b'));
insert into UDTOBYTEST_TB values (3, new UDTOBYTEST (3, 'c'));

select * from UDTOBYTEST_TB order by DATA;
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": UDT in order by STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create table B5312_TB2 (ID int, DT long varchar);
insert into B5312_TB2 values (1, B5312_TYPEA (1));
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": B5312: LONG UDT into non-udt blob STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

drop type B5976_U;
drop table B5976_T;

create table B5976_T (ID int primary key, DT varchar (100));
create procedure B5976_P ()
{
  declare I integer;
  declare RES any;

  res := (select I.ID from B5976_T I where I.DT is not null);
};
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": B5976: B5976_P created STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select B5976_P ();
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": B5976-2: scalar var not checked for observer inst STATE=" $STATE " MESSAGE=" $MESSAGE "\n";


create type B5976_U as (ID integer);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": B5976-3: B5976_U defined STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create procedure B5976_P2 ()
{
  declare I B5976_U;
  declare RES any;

  res := (select I.ID from B5976_T I where I.DT is not null);
};
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": B5976-4: udt var checked for observer inst STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

drop table B6805_T;
drop type B6805_U;
create type B6805_U as (X integer);
create table B6805_T (ID integer primary key, DATA B6805_U, LDATA long B6805_U);

insert into B6805_T (ID, DATA, LDATA) values (1, new B6805_U(), new B6805_U ());
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": B6805-1: some data added to the UDT table STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

insert into B6805_T (ID, DATA, LDATA) values (2, NULL, NULL);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": B6805-2: NULL data added to the UDT table STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

-- XXX: disabled until fixed in VJ
--select 1 from B6805_T where DATA = new B6805_U();
--ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
--SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
--ECHO BOTH ": B6805-3: search on udt inst STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

--select 1 from B6805_T where DATA = new B6805_U();
--ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
--SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
--ECHO BOTH ": B6805-4: search on long udt inst STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select 1 from B6805_T where DATA is NULL and LDATA is NULL;
ECHO BOTH $IF $EQU $ROWCNT 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": B6805-5: search on udt being null STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

DROP TYPE B7151;

CREATE TYPE B7151
AS (KEYVALS any, KEYNAME varchar, NUMOFVALS integer)
temporary self as ref
CONSTRUCTOR METHOD B7151(KNAME varchar, PARAMS any),
METHOD IS_VALUE(VAL varchar) RETURNS integer,
METHOD IS_VALUE(VAL varchar, TAGOPTION varchar) RETURNS varchar;

CREATE CONSTRUCTOR METHOD B7151(in KNAME varchar, in PARAMS any)
  for B7151
{
  declare i, l integer;
  declare VALS any;
  VALS := vector();
  l := length(PARAMS);
  i := 0;
  while (i < l)
  {
    if (PARAMS[i] = KNAME)
      VALS := vector_concat(VALS, vector(PARAMS[i+1]));
    i := i + 2;
  }

  SELF := KEYVALS(SELF, VALS);

  SELF := KEYNAME(SELF, KNAME);
  SELF := NUMOFVALS(SELF, length(VALS));
  return SELF;
};
CREATE METHOD IS_VALUE(in VAL varchar) RETURNS integer
  for B7151
{
  return 1;
};

CREATE METHOD IS_VALUE(in VAL varchar, in TAGOPTION varchar) RETURNS varchar
  for B7151
{
  return 'a';
};

select (new B7151 ('key', vector ('key', 'a'))).IS_VALUE (aref (vector ('a'), 0), ' b ');
ECHO BOTH $IF $EQU $LAST[1] a "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": B7151-1: polymorfism  STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select (new B7151 ('key', vector ('key', 'a'))).IS_VALUE (aref (vector ('a'), 0));
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": B7151-2: polymorfism  STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

ECHO BOTH "COMPLETED: SQL200n user defined types suite (udttest.sql) WITH " $ARGV[0] " FAILED, " $ARGV[1] " PASSED\n\n";
