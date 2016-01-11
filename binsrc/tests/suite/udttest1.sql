--
--  $Id: udttest1.sql,v 1.5.10.1 2013/01/02 16:15:38 source Exp $
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
echo BOTH "\nSTARTED: SQL200n user defined types suite (udttest1.sql)\n";
SET ARGV[0] 0;
SET ARGV[1] 0;
drop table udt_test_TBL;
drop procedure test_OVERLOAD_FLD;
drop procedure test_OVERLOAD;
drop procedure test_DOT_NOTATION;
drop procedure test_NO_RETS;
drop type udt_test_Sub;
drop type udt_test;
drop type udt_INOUT_test;
drop type DB.DBA.udt_TEMP;
drop procedure udt_INOUT_test_PROC;
drop type Sub_udt_TEMP;
drop type Sub_udt_test_TEMP;
drop type udt_JAVA;
drop type udt_SQL;
drop type udt_REF_CLASS;
drop procedure test_observers;
drop procedure test_observers;
drop procedure test_and_run_method;
drop table udt_TEMP_TB;
drop table udt_ANY_TB;
drop type udt_FR_BASE;
drop type udt_FR_SUPER;
drop type udt_FR_COL;
drop type udt_BM_BASE;
drop type udt_BM_Sub;



create type udt_test
  as (A integer default 1, B integer default 2)
  CONSTRUCTOR METHOD udt_test(_a integer, _b integer) specific DB.DBA.construct_x,
  CONSTRUCTOR METHOD udt_test(),
  STATIC METHOD _Add(_xx integer, _yy integer) returns integer specific DB.DBA.static_Add,
  METHOD AddIT() returns integer specific DB.DBA.Add_them1,
  METHOD AddIT(c integer) returns integer specific DB.DBA.Add_them2,
  METHOD Sub_IT () returns integer;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": type udt_test declared STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create constructor method udt_test (in _a integer, in _b integer) for udt_test
{
  A(SELF, _a);
  B(SELF, _b);
};
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": constructor for udt_test defined STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create constructor method udt_test () for udt_test
{
  A(SELF, -1);
  B(SELF, -2);
};
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": default constructor for udt_test defined STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create static method _Add (in a1 integer, in a2 integer) for udt_test
{
  return a1 + a2;
};
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": static method for udt_test defined STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

--explain ('
create method AddIT () for udt_test
{
  return udt_test::_Add (A(SELF), B(SELF));
}
--')
;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": dynamic method 'AddIT' for udt_test defined STATE=" $STATE " MESSAGE=" $MESSAGE "\n";


--explain ('
create method AddIT (in c integer) for udt_test
{
  return udt_test::_Add (A(SELF), B(SELF)) + c;
}
--')
;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": dynamic method 'AddIT' w/arg for udt_test defined STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

--explain ('
create method Sub_IT () for udt_test
{
  return A(SELF) - B(SELF);
}
--')
;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": dynamic method 'Sub_IT' for udt_test defined STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create type udt_test_Sub under udt_test
  as (C integer default 12, _D integer default 32)
  STATIC METHOD _Add(_xx integer, _yy integer, _zz integer, _qq integer) returns integer
       specific DB.DBA.static2_Add,
  OVERRIDING METHOD AddIT() returns integer specific DB.DBA.Add2_them1,
  METHOD MULTIPLY_IT () returns integer;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Subtype udt_test_Sub declared STATE=" $STATE " MESSAGE=" $MESSAGE "\n";


create static method _Add (in _xx integer,in _yy integer,in _zz integer,in _qq integer) for udt_test_Sub
{
  return _xx + _yy + _zz + _qq;
}
;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": static method (same name different args) for udt_test_Sub defined STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create method AddIT () for udt_test_Sub
{
  return udt_test_Sub::_Add (A(SELF), B(SELF), C(SELF), _D(SELF));
}
;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": overloading method for udt_test_Sub defined STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create method MULTIPLY_IT () for udt_test_Sub
{
  return A(SELF) * B(SELF) * C(SELF) * _D(SELF);
}
;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": dynamic method for udt_test_Sub defined STATE=" $STATE " MESSAGE=" $MESSAGE "\n";


-- tests

select A(udt_test());
ECHO BOTH $IF $EQU $LAST[1] -1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": testing observer for the base type returned " $LAST[1]"\n";

select A(udt_test_Sub());
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": testing observer for the Subtype returned " $LAST[1]"\n";

select A(A(udt_test(), -100));
ECHO BOTH $IF $EQU $LAST[1] -100 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": testing mutator for the base type returned " $LAST[1]"\n";

select A(A(udt_test_Sub(), -100));
ECHO BOTH $IF $EQU $LAST[1] -100 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": testing mutator for the Subtype returned " $LAST[1]"\n";

--explain ('
create procedure test_OVERLOAD (in xx udt_test) returns integer
{
  return xx.AddIT ();
}
--')
;

select test_OVERLOAD (udt_test());
ECHO BOTH $IF $EQU $LAST[1] -3 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": testing overloaded method for the base type returned " $LAST[1]"\n";

select test_OVERLOAD (udt_test_Sub());
ECHO BOTH $IF $EQU $LAST[1] 47 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": testing overloaded method for the Subtype returned " $LAST[1]"\n";

select udt_test_Sub::_Add (22, 33);
ECHO BOTH $IF $EQU $LAST[1] 55 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": testing inherited static method for the Subtype returned " $LAST[1]"\n";

select udt_test_Sub::_Add (22, 33, 44, 55);
ECHO BOTH $IF $EQU $LAST[1] 154 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": testing local static method for the Subtype returned " $LAST[1]"\n";

select udt_test_Sub().MULTIPLY_IT();
ECHO BOTH $IF $EQU $LAST[1] 768 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": testing local method for the Subtype returned " $LAST[1]"\n";

create procedure test_OVERLOAD_FLD (in xx udt_test) returns integer
{
  return A(xx);
}
;

select test_OVERLOAD_FLD (udt_test());
ECHO BOTH $IF $EQU $LAST[1] -1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": testing overloaded member access for the base type returned " $LAST[1]"\n";

select test_OVERLOAD_FLD (udt_test_Sub())
;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": testing overloaded member access for the Subtype returned " $LAST[1]"\n";

create table udt_test_TBL (id integer primary key, data udt_test);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": column of type udt_test STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

insert into udt_test_TBL (id, data) values (1, udt_test());
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": inserted value into udt_test column STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

insert into udt_test_TBL (id, data) values (2, NULL);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": inserted NULL value into udt_test column STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

insert into udt_test_TBL (id, data) values (3, udt_test_Sub());
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": inserted udt value into udt_test column STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

insert into udt_test_TBL (id, data) values (4, 44);
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": inserted wrong (int) value into udt_test column STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select A(data) from udt_test_TBL where id = 1;
ECHO BOTH $IF $EQU $LAST[1] -1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": retrieved value from udt_test column = " $LAST[1] "\n";

select x.data.A from udt_test_TBL x where x.id = 1;
ECHO BOTH $IF $EQU $LAST[1] -1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": using .MEMBER for udt_test column = " $LAST[1] "\n";

select x.data.Addit() from udt_test_TBL x where x.id = 1;
ECHO BOTH $IF $EQU $LAST[1] -3 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": using .method() for udt_test column = " $LAST[1] "\n";

select data.A from udt_test_TBL where id = 1;
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": no corelation name for .MEMBER STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select new udt_test().A;
ECHO BOTH $IF $EQU $LAST[1] -1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": using .MEMBER for udt_test column = " $LAST[1] "\n";

create procedure test_DOT_NOTATION ()
{
  declare uu udt_test;

  uu := new udt_test();

  uu.A := 40;

  uu.B := uu.A + 10;

  return (uu.A  + uu.B);
};

select test_DOT_NOTATION();
ECHO BOTH $IF $EQU $LAST[1] 90 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": using .MEMBER for observers & mutators = " $LAST[1] "\n";

create procedure test_NO_RETS ()
{
  declare uu udt_test;

  uu := new udt_test();

  udt_test();

  A(uu, 12);
};

ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": missing various return slots STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create type udt_INOUT_test
as
  (A integer default 1,
   B integer default 2)
;

create procedure CHANGE_IT (inout z integer)
{
  z := z + 1000;
};

create procedure udt_INOUT_test_PROC ()
{
  declare dt udt_INOUT_test;
  dt := new udt_INOUT_test();

  CHANGE_IT (dt.A);
  return dt.A;
};

select udt_INOUT_test_PROC();
ECHO BOTH $IF $EQU $LAST[1] 1001 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": inout directly to udt member returned " $LAST[1] "\n";


--- temporary classes
create type DB.DBA.udt_TEMP AS (A integer default -1) temporary
method getA () returns integer,
method setA (new_a integer) returns integer,
method setA (new_a varchar) returns integer;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": temporary class created STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select * from SYS_USER_TYPES where UT_NAME = fix_identifier_case ('DB.DBA.udt_TEMP');
ECHO BOTH $IF $EQU $ROWCNT 0 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": temporary class records into SYS_USER_TYPES ROWCNT=" $ROWCNT "\n";

create method getA() returns integer for DB.DBA.udt_TEMP
{
  return SELF.A;
};
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": method getA created STATE=" $STATE " MESSAGE=" $MESSAGE "\n";


create method setA(in new_a integer) returns integer for DB.DBA.udt_TEMP
{
  declare old_a integer;
  old_a := SELF.A;
  SELF.A := new_a;
  return old_a;
};
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": method setA (int) created STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select new DB.DBA.udt_TEMP ().setA(cast (1 as integer));
ECHO BOTH $IF $EQU $LAST[1] -1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": method setA (int) called return=" $LAST[1] "\n";

select new DB.DBA.udt_TEMP ().setA(cast (1 as varchar));
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": method setA (varchar) not defined STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select new DB.DBA.udt_TEMP ().setA(cast (1 as double precision));
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": ambigulty in calling method setA (double precision) STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create method setA(in new_a varchar) returns integer for DB.DBA.udt_TEMP
{
  SELF.A := atoi (new_a);
  return SELF.A;
};
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": method setA (varchar) created STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select new DB.DBA.udt_TEMP ().setA(cast (1 as varchar));
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": method setA (varchar) called STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create type Sub_udt_TEMP under DB.DBA.udt_TEMP as (B integer);
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": persistent Subtype of a temp type STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create type Sub_udt_test_TEMP under udt_test as (B integer) temporary;
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": temp Subtype of a persistent type STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create type udt_JAVA under DB.DBA.udt_TEMP language java external name 'dummy' as (A integer) temporary;
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": JAVA Subtype of a SQL type STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create type udt_JAVA language java external name 'dummy' as (A integer) temporary method xx() returns integer;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": JAVA type created STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create type udt_SQL under udt_JAVA language SQL as (B integer) temporary;
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": SQL Subtype of a JAVA type STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create type udt_SQL under udt_JAVA as (B integer) temporary;
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": unspecified lang := SQL STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create method xx () returns integer for udt_JAVA
{
  return SELF.B;
};
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": SQL method for JAVA class STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create procedure test_ASET()
{
  declare inst DB.DBA.udt_TEMP;

  inst := new DB.DBA.udt_TEMP();

  inst.A := vector (0);
  aset (inst.A, 0, 12);
  return inst.A[0];
};

-- XXX: we need to have aset on variables derived from observer,
-- as there is no way to distinguish between varables and observers
-- we we'll allow it for now!
--select test_ASET();
--ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
--SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
--ECHO BOTH ": aset w/ member observer STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

explain ('
create procedure test_SETTABLE()
{
  declare inst DB.DBA.udt_TEMP;
  declare msg any;

  inst := new DB.DBA.udt_TEMP();

  exec (''signal (''''state'''', ''''message'''')'', inst.A, msg);
  return inst.A;
}');

select test_SETTABLE();
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": member observer result is not settable in BIFs STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create type udt_REF_CLASS as (A integer default -2) temporary self as ref
constructor method udt_REF_CLASS (new_a integer);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": self as ref class created STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create constructor method udt_REF_CLASS (in new_a integer) for udt_REF_CLASS
{
  SELF.A := new_a;
};

create procedure refs_tryout ()
{
  declare inst1 udt_REF_CLASS;
  inst1 := new udt_REF_CLASS(33);

  if (inst1.A <> 33)
    signal ('tsudt', 'Constructor not called');

  inst1 := new udt_REF_CLASS();
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
  declare inst1, inst2 udt_REF_CLASS;
  inst1 := new udt_REF_CLASS();
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
  declare inst1, inst2 udt_test;
  inst1 := new udt_test();
  inst2 := inst1;

  inst1.A := 12;
  return inst2.A;
};
select modify_non_refs ();
ECHO BOTH $IF $EQU $LAST[1] -1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": modifying a member not visible trough copied instance =" $LAST[1] "\n";

create procedure test_instance_of (in udt udt_test)
{
  declare class_name varchar;
  declare instance_of_udt_test_Sub integer;
  result_names (class_name, instance_of_udt_test_Sub);

  class_name := udt_instance_of (udt);
  instance_of_udt_test_Sub := udt_instance_of (udt, fix_identifier_case('udt_test_Sub'));
  result (class_name, instance_of_udt_test_Sub);
};
test_instance_of (new udt_test());
ECHO BOTH $IF $EQU $LAST[1] "DB.DBA.udt_test" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": instance class is =" $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[2] 0 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": is instance of udt_test_Sub =" $LAST[2] "\n";

test_instance_of (new udt_test_Sub());
ECHO BOTH $IF $EQU $LAST[1] "DB.DBA.udt_test_Sub" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": instance class is =" $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[2] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": is instance of udt_test_Sub =" $LAST[2] "\n";

select (new udt_test () as udt_test_Sub).MULTIPLY_IT();
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": forced cast syntax in method call for wrong class STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select (new udt_test_Sub () as udt_test_Sub).MULTIPLY_IT();
ECHO BOTH $IF $EQU $LAST[1] 768 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": forced cast syntax for method call returned =" $LAST[1] "\n";

select (new udt_test () as udt_test_Sub).C;
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": forced cast syntax in member observer for wrong class STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select (new udt_test_Sub () as udt_test_Sub).C;
ECHO BOTH $IF $EQU $LAST[1] 12 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": forced cast syntax for member observer returned =" $LAST[1] "\n";

create procedure forced_cast_try (in udt udt_test)
{
  declare _c integer;
  _c := (udt as udt_test_Sub).C;
  (udt as udt_test_Sub).C := _c + 1;
  (new udt_test_Sub() as udt_test_Sub).C := _c + 1;
  return (udt as udt_test_Sub).MULTIPLY_IT();
};
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": forced cast syntax proc created STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select forced_cast_try (new udt_test_Sub());
ECHO BOTH $IF $EQU $LAST[1] 832 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": forced cast syntax returned =" $LAST[1] "\n";

select forced_cast_try (new udt_test());
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": forced cast syntax for wrong class STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create procedure test_observers ()
{
  declare udt udt_test_Sub;
  udt := new udt_test_Sub ();
  declare ret integer;

  ret := udt.C;
  ret := udt_test_Sub().C;
  ret := (udt as udt_test_Sub).C;
  ret := (udt_test_Sub() as udt_test_Sub).C;
};
test_observers();
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": various observer forms in Virtuoso/PL STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create procedure test_mutators ()
{
  declare udt udt_test_Sub;
  udt := new udt_test_Sub ();
  declare ret integer;

  C(udt, 1);
  udt := C(udt, 1);
  udt_test_Sub().C := 1;
  (udt as udt_test_Sub).C := 1;
  (udt_test_Sub() as udt_test_Sub).C := 1;
};
test_mutators();
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": various mutator forms in Virtuoso/PL STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

--explain ('
METHOD CALL udt_test_Sub().MULTIPLY_IT()
--')
;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": top level dynamic method STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

--explain ('
METHOD CALL udt_test::_Add(1, 2)
--')
;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": top level static method STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select udt_defines_field ('udt_test', 'A');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": checking for member using string names =" $LAST[1] "\n";

select udt_defines_field ('udt_test', 'C');
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": checking for non-existent member using string names =" $LAST[1] "\n";

select udt_defines_field ('udt_test_Sub', 'A');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": checking for inherited member using string names =" $LAST[1] "\n";

select udt_defines_field ('udt_test_Sub', 'C');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": checking for local Subclass member using string names =" $LAST[1] "\n";

select udt_defines_field (udt_test(), 'A');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": checking for member using instance =" $LAST[1] "\n";

select udt_defines_field (udt_test(), 'C');
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": checking for non-existent member using instance =" $LAST[1] "\n";

select udt_defines_field (udt_test_Sub(), 'A');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": checking for inherited member using instance =" $LAST[1] "\n";

select udt_defines_field (udt_test_Sub(), 'C');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": checking for local Subclass member using instance =" $LAST[1] "\n";

select udt_get (udt_test(), 'C');
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": getting a non-existent field STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select udt_get (udt_test(), 'A');
ECHO BOTH $IF $EQU $LAST[1] -1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": getting field value =" $LAST[1] "\n";

select udt_get (udt_test_Sub(), 'A');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": getting inherited field value =" $LAST[1] "\n";

select udt_set (udt_test(), 'C', 12);
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": setting a non-existent field STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select udt_get (udt_set (udt_test(), 'A', 12), 'A');
ECHO BOTH $IF $EQU $LAST[1] 12 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": getting field value =" $LAST[1] "\n";

select udt_get (udt_set (udt_test_Sub(), 'A', 12), 'A');
ECHO BOTH $IF $EQU $LAST[1] 12 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": getting inherited field value =" $LAST[1] "\n";

create procedure test_and_run_method (in cls any, in method_name varchar)
{
  declare mtd_ptr, ret any;
  declare exist integer;
  mtd_ptr := udt_implements_method (fix_identifier_case(cls), fix_identifier_case(method_name));
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

CALL test_and_run_method ('udt_test', 'MULTIPLY_IT');
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": check method MULTIPLY_IT in udt_test returned =" $LAST[1] "\n";

CALL test_and_run_method ('udt_test', '_Add');
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": check static method _Add in udt_test returned =" $LAST[1] "\n";

CALL test_and_run_method ('udt_test', 'Sub_IT');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": check method Sub_IT in udt_test returned =" $LAST[1] "\n";

CALL test_and_run_method ('udt_test_Sub', 'Sub_IT');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": check method Sub_IT in udt_test_Sub returned =" $LAST[1] "\n";

CALL test_and_run_method ('udt_test_Sub', 'MULTIPLY_IT');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": check method MULTIPLY_IT in udt_test_Sub returned =" $LAST[1] "\n";



CALL test_and_run_method (udt_test(), 'MULTIPLY_IT');
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": check method MULTIPLY_IT in udt_test inst returned =" $LAST[1] "\n";

CALL test_and_run_method (udt_test(), '_Add');
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": check static method _Add in udt_test inst returned =" $LAST[1] "\n";

CALL test_and_run_method (udt_test(), 'Sub_IT');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": check method Sub_IT in udt_test inst returned =" $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[2] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": result from method Sub_IT in udt_test inst =" $LAST[1] "\n";

CALL test_and_run_method (udt_test_Sub(), 'Sub_IT');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": check method Sub_IT in udt_test_Sub inst returned =" $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[2] -1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": result from method Sub_IT in udt_test_Sub =" $LAST[2] "\n";

CALL test_and_run_method (udt_test_Sub(), 'MULTIPLY_IT');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": check method MULTIPLY_IT in udt_test_Sub inst returned =" $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[2] 768 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": result from method MULTIPLY_IT in udt_test_Sub inst =" $LAST[2] "\n";

create table udt_TEMP_TB (id int primary key, tdata DB.DBA.udt_TEMP);
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": not able to create a column of temp type STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create table udt_ANY_TB (ID int primary key, ADATA any);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": table w/ ANY column created STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

insert into udt_ANY_TB (ID, ADATA) values (1, udt_test());
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": inserting instance into ANY col STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select (ADATA as udt_test).A from udt_ANY_TB where ID = 1;
ECHO BOTH $IF $EQU $LAST[1] -1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": deserializing instance from ANY column STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

insert into udt_ANY_TB (ID, ADATA) values (2, DB.DBA.udt_TEMP ());
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": inserting temp instance into ANY col STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select udt_instance_of (ADATA) from udt_ANY_TB where ID = 2;
ECHO BOTH $IF $EQU $LAST[1] 'DB.DBA.SYS_SERIALIZATION_ERROR' "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": deserializing temp instance shows it wrote " $LAST[1] "\n";

create type udt_FR_BASE UNDER udt_FR_SUPER as (A int default 11, udt_M udt_FR_COL)
    constructor method udt_FR_BASE (a int, b int);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": creating an non-instantiable class STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select new udt_FR_BASE ();
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": constructor call failed STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create type udt_FR_COL language JAVA as (B int default 12);
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": forward reference defined as different language STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create type udt_FR_SUPER as (S int default 12);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": forward reference for super defined STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select new udt_FR_BASE ().A;
ECHO BOTH $IF $EQU $LAST[1] 11 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": udt_FR_BASE now instantiable A=" $LAST[1] "\n";

select new udt_FR_BASE ().udt_M;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": accessing a FR member STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create type udt_FR_COL as (B int default 12);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": column FR defined STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create constructor method udt_FR_BASE (in a int, in b int) for udt_FR_BASE
{
  declare new_udt_m udt_FR_COL;
  new_udt_m := new udt_FR_COL();
  new_udt_m.B := b;

  SELF.A := a;
  SELF.udt_M := new_udt_m;
};

select new udt_FR_BASE (1, 2).udt_M.B;
ECHO BOTH $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": accessing an udt member's member =" $LAST[1] "\n";

create type udt_BM_BASE
  method GET_ID () returns integer;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": udt_BM_BASE created STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create type udt_BM_Sub under udt_BM_BASE
  overriding method GET_ID () returns integer;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": udt_BM_Sub created STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create method GET_ID () returns integer for udt_BM_BASE
{
  return 12;
};
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": GET_ID for udt_BM_BASE created STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create method GET_ID () returns integer for udt_BM_Sub
{
  return (SELF as udt_BM_BASE).GET_ID() * 2;
};
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": GET_ID for udt_BM_Sub calling it's parent's GET_ID defined STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select new udt_BM_Sub().GET_ID();
ECHO BOTH $IF $EQU $LAST[1] 24 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": calling parent overloaded method returned =" $LAST[1] "\n";

drop table udt_DOT_TB;
drop type udt_DOT;
drop type udt_DOT_Sub;
create type udt_DOT_Sub as (A integer default 1, B integer default 2)
  method do_it () returns integer;
create type udt_DOT as (A udt_DOT_Sub, B integer default 3)
  constructor method udt_DOT ();

create method do_it () returns integer for udt_DOT_Sub
{
  return self.A + self.B;
};

create constructor method udt_DOT () for udt_DOT
{
  self.A := new udt_DOT_Sub ();
};

create table udt_DOT_TB (ID int primary key, DATA udt_DOT);

insert into udt_DOT_TB values (1, new udt_DOT());

select (DB.DBA.udt_DOT_TB.DATA as udt_DOT).A.A from udt_DOT_TB;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": dot notation returned =" $LAST[1] "\n";

select (DB.DBA.udt_DOT_TB.DATA.A as udt_DOT_Sub).A from udt_DOT_TB;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": dot notation 2 returned =" $LAST[1] "\n";

select DB.DBA.udt_DOT_TB.DATA.A.A from udt_DOT_TB;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": dot notation 3 returned =" $LAST[1] "\n";

select C.DATA.A.A from udt_DOT_TB C;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": dot notation 4 returned =" $LAST[1] "\n";

select (C.DATA.A as udt_DOT_Sub).A from udt_DOT_TB C;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": dot notation 5 returned =" $LAST[1] "\n";


select (DB.DBA.udt_DOT_TB.DATA as udt_DOT).A.DO_IT() from udt_DOT_TB;
ECHO BOTH $IF $EQU $LAST[1] 3 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": dot method_call 1 returned =" $LAST[1] "\n";

select (DB.DBA.udt_DOT_TB.DATA.A as udt_DOT_Sub).DO_IT() from udt_DOT_TB;
ECHO BOTH $IF $EQU $LAST[1] 3 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": dot method_call 2 returned =" $LAST[1] "\n";

select DB.DBA.udt_DOT_TB.DATA.A.DO_IT() from udt_DOT_TB;
ECHO BOTH $IF $EQU $LAST[1] 3 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": dot method_call 3 returned =" $LAST[1] "\n";

select C.DATA.A.DO_IT() from udt_DOT_TB C;
ECHO BOTH $IF $EQU $LAST[1] 3 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": dot method_call 4 returned =" $LAST[1] "\n";

select (C.DATA.A as udt_DOT_Sub).DO_IT() from udt_DOT_TB C;
ECHO BOTH $IF $EQU $LAST[1] 3 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": dot method_call 5 returned =" $LAST[1] "\n";


drop type udt_ALTER_TYPE;
create type udt_ALTER_TYPE as (A integer default 1)
    method m1 (i integer) returns integer;
create method m1 (in i integer) returns integer for udt_ALTER_TYPE
{
  return i;
};

select new udt_ALTER_TYPE().A;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": udt_ALTER_TYPE().A returned =" $LAST[1] "\n";

alter type udt_ALTER_TYPE Add attribute A integer default 2;
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Add another A to udt_ALTER_TYPE STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select new udt_ALTER_TYPE().m1 (1);
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": udt_ALTER_TYPE().m1(1) returned =" $LAST[1] "\n";

select new udt_ALTER_TYPE().A;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": udt_ALTER_TYPE().A returned =" $LAST[1] "\n";

alter type udt_ALTER_TYPE Add attribute B integer default 2;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Add B to udt_ALTER_TYPE STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select new udt_ALTER_TYPE().A;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": udt_ALTER_TYPE().A returned =" $LAST[1] "\n";

select new udt_ALTER_TYPE().B;
ECHO BOTH $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": udt_ALTER_TYPE().B returned =" $LAST[1] "\n";

select new udt_ALTER_TYPE().m1 (1);
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": udt_ALTER_TYPE().m1(1) returned =" $LAST[1] "\n";

select new udt_ALTER_TYPE().m1 (2);
ECHO BOTH $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": udt_ALTER_TYPE().m1(2) returned =" $LAST[1] "\n";

alter type udt_ALTER_TYPE drop attribute C;
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": drop non-existant attribute STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

alter type udt_ALTER_TYPE drop attribute A;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": drop A from udt_ALTER_TYPE STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select new udt_ALTER_TYPE().A;
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": udt_ALTER_TYPE().A returned STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select new udt_ALTER_TYPE().B;
ECHO BOTH $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": udt_ALTER_TYPE().B returned =" $LAST[1] "\n";

select new udt_ALTER_TYPE().B + 0;
ECHO BOTH $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": recompile udt_ALTER_TYPE().B returned =" $LAST[1] "\n";

select count (*) from SYS_USER_TYPES where UT_NAME like '%.udt_ALTER_TYPE__%' and UT_MIGRATE_TO is not null;
ECHO BOTH $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": count (*) obsolete types returned =" $LAST[1] "\n";

alter type udt_ALTER_TYPE Add method m1 (id integer) returns integer;
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Adding duplicate method STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

alter type udt_ALTER_TYPE Add method m2 (id integer) returns integer;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Adding method m2 STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create method m2 (in id integer) returns integer for udt_ALTER_TYPE
{
  return id + 100;
};
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": declaring method m2 STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select count (*) from SYS_USER_TYPES where UT_NAME like '%.udt_ALTER_TYPE__%' and UT_MIGRATE_TO is not null;
ECHO BOTH $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": count (*) obsolete types returned =" $LAST[1] "\n";

select new udt_ALTER_TYPE().m1 (1);
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": calling original m1 returned =" $LAST[1] "\n";

select new udt_ALTER_TYPE().m2 (1);
ECHO BOTH $IF $EQU $LAST[1] 101 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": calling m2 returned =" $LAST[1] "\n";

alter type udt_ALTER_TYPE Add method m1 (id float) returns float;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Adding method m1 (float) STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create method m1 (in id float) returns float for udt_ALTER_TYPE
{
  return id + 2.0;
};
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": declaring method m1 (float) STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select new udt_ALTER_TYPE().m1 (cast (3 as float));
ECHO BOTH $IF $EQU $LAST[1] 5 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": calling m1(float = 3) returned =" $LAST[1] "\n";

alter type udt_ALTER_TYPE drop method m1 (id integer) returns integer;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": dropping method m1 (int) STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select new udt_ALTER_TYPE().m1 (4);
ECHO BOTH $IF $EQU $LAST[1] 6 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": calling m1 (4) (qr cached) returned =" $LAST[1] "\n";

select new udt_ALTER_TYPE().m2 (1);
ECHO BOTH $IF $EQU $LAST[1] 101 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": calling m2 returned =" $LAST[1] "\n";

drop type udt_ALTER_TYPE;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": dropping udt_ALTER_TYPE STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select count (*) from SYS_USER_TYPES where UT_NAME like '%.udt_ALTER_TYPE%';
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": DROP TYPE cleaning the obsolete types returned =" $LAST[1] "\n";

-- inheritance in ALTER type
drop type udt_ALTER_Sub;
drop type udt_ALTER_T;

create type udt_ALTER_T as (A integer default 1);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": creating udt_ALTER_T STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create type udt_ALTER_Sub under udt_ALTER_T as (B integer default 2);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": creating udt_ALTER_Sub STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select new udt_ALTER_Sub().A;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": access the super's attr from Subtype returned =" $LAST[1] "\n";

alter type udt_ALTER_T Add method m1 (i int) returns int;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": declaring method m1 to udt_ALTER_T STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create method m1 (in i int) returns int for udt_ALTER_T
{
  return i;
};
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": defining method m1 to udt_ALTER_T STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select new udt_ALTER_T().m1 (10);
ECHO BOTH $IF $EQU $LAST[1] 10 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": calling udt_ALTER_T.m1 (10) returned =" $LAST[1] "\n";

select new udt_ALTER_Sub().m1 (10);
ECHO BOTH $IF $EQU $LAST[1] 10 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": calling udt_ALTER_Sub.m1 (10) returned =" $LAST[1] "\n";

select count (*) from SYS_USER_TYPES where UT_NAME like fix_identifier_case('%.udt_ALTER_Sub%') and UT_MIGRATE_TO is not null;
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": # obsolete types for udt_ALTER_Sub returned =" $LAST[1] "\n";

alter type udt_ALTER_T Add attribute B integer default 3;
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Adding B to udt_ALTER_T clashes w/ B in udt_ALTER_Sub STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

alter type udt_ALTER_T Add attribute C integer default 3;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Adding C to udt_ALTER_T STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select new udt_ALTER_T().C;
ECHO BOTH $IF $EQU $LAST[1] 3 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": checking the access to C in udt_ALTER_T =" $LAST[1] "\n";

select new udt_ALTER_Sub().C;
ECHO BOTH $IF $EQU $LAST[1] 3 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": checking the access to C in udt_ALTER_Sub =" $LAST[1] "\n";

select count (*) from SYS_USER_TYPES where UT_NAME like '%.udt_ALTER_Sub%' and UT_MIGRATE_TO is not null;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": # obsolete types for udt_ALTER_Sub after parent change returned =" $LAST[1] "\n";

-- udt instance migration test
drop table udt_ALTER_TABLE;
drop type udt_ALTER_PERS;

create type udt_ALTER_PERS as (A integer default 1);
create table udt_ALTER_TABLE (ID int primary key, DATA udt_ALTER_PERS);

insert into udt_ALTER_TABLE (ID, DATA) values (1, new udt_ALTER_PERS());

alter type udt_ALTER_PERS Add attribute B integer default 2;
insert into udt_ALTER_TABLE (ID, DATA) values (2, new udt_ALTER_PERS());

alter type udt_ALTER_PERS Add attribute C integer default 3;
insert into udt_ALTER_TABLE (ID, DATA) values (3, new udt_ALTER_PERS());

select C.DATA.A from udt_ALTER_TABLE C where C.ID = 3;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": deserializing a fresh instance returned A =" $LAST[1] "\n";

select C.DATA.B from udt_ALTER_TABLE C where C.ID = 3;
ECHO BOTH $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": deserializing a fresh instance returned B =" $LAST[1] "\n";

select C.DATA.C from udt_ALTER_TABLE C where C.ID = 3;
ECHO BOTH $IF $EQU $LAST[1] 3 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": deserializing a fresh instance returned B =" $LAST[1] "\n";

select C.DATA.A from udt_ALTER_TABLE C where C.ID = 2;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": deserializing one old instance returned A =" $LAST[1] "\n";

select C.DATA.B from udt_ALTER_TABLE C where C.ID = 2;
ECHO BOTH $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": deserializing one old instance returned B =" $LAST[1] "\n";

select C.DATA.C from udt_ALTER_TABLE C where C.ID = 2;
ECHO BOTH $IF $EQU $LAST[1] 3 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": deserializing one old instance returned B =" $LAST[1] "\n";

select C.DATA.A from udt_ALTER_TABLE C where C.ID = 1;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": deserializing two old instance returned A =" $LAST[1] "\n";

select C.DATA.B from udt_ALTER_TABLE C where C.ID = 1;
ECHO BOTH $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": deserializing two old instance returned B =" $LAST[1] "\n";

select C.DATA.C from udt_ALTER_TABLE C where C.ID = 1;
ECHO BOTH $IF $EQU $LAST[1] 3 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": deserializing two old instance returned B =" $LAST[1] "\n";

ECHO BOTH "COMPLETED: SQL200n user defined types suite (udttest1.sql) WITH " $ARGV[0] " FAILED, " $ARGV[1] " PASSED\n\n";
