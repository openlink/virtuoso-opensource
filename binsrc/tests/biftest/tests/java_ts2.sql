--
--  $Id$
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

USE JAVATS;

echo BOTH "\nSTARTED: SQL200n user defined types java suite (java_ts2.sql)\n";
SET ARGV[0] 0;
SET ARGV[1] 0;
select java_call_method ('java.lang.System', null, 'getProperty', 'Ljava/lang/String;', 'java.class.path');
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": VM loaded classpath=" $LAST[1]"\n";

select java_call_method ('java.lang.System', null, 'getProperty', 'Ljava/lang/String;', 'java.vm.name');
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": VM name=" $LAST[1]"\n";

select java_call_method ('java.lang.System', null, 'getProperty', 'Ljava/lang/String;', 'java.vm.version');
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": VM version=" $LAST[1]"\n";


select testsuite_base::get_static_ro_I();
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": static final member observer =" $LAST[1]"\n";

select testsuite_base::get_static_I();
ECHO BOTH $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": static member observer =" $LAST[1]"\n";

select testsuite_base::get_protected_static_I();
ECHO BOTH $IF $EQU $LAST[1] 3 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": static protected member observer =" $LAST[1]"\n";

select testsuite_base::get_private_static_I();
ECHO BOTH $IF $EQU $LAST[1] 13 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": static private member observer =" $LAST[1]"\n";

select new testsuite_base();
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": making instance =" $LAST[1]"\n";

select new testsuite_base().sZ;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": boolean true member observer =" $LAST[1]"\n";

select new testsuite_base().sfalseZ;
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": boolean false member observer =" $LAST[1]"\n";

select testsuite_base::test_bool (1);
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": boolean method call w/true =" $LAST[1]"\n";

select testsuite_base::test_bool (0);
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": boolean method call w/false =" $LAST[1]"\n";

select new testsuite_base().sB;
ECHO BOTH $IF $EQU $LAST[1] 5 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": byte member observer =" $LAST[1]"\n";

select chr (new testsuite_base().sC);
ECHO BOTH $IF $EQU $LAST[1] a "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": char member observer =" $LAST[1]"\n";

select new testsuite_base().sS;
ECHO BOTH $IF $EQU $LAST[1] 6 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": short member observer =" $LAST[1]"\n";

select new testsuite_base().sI;
ECHO BOTH $IF $EQU $LAST[1] 7 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": int member observer =" $LAST[1]"\n";

select new testsuite_base().sJ;
ECHO BOTH $IF $EQU $LAST[1] 8 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": long member observer =" $LAST[1]"\n";

select sprintf ('%.4f', new testsuite_base().sF);
ECHO BOTH $IF $EQU $LAST[1] 0.1234 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": float member observer =" $LAST[1]"\n";

select sprintf ('%.5f', new testsuite_base().sD);
--- XXXX: should return ECHO BOTH $IF $EQU $LAST[1] 8.1234567890123456 "PASSED" "***FAILED";
ECHO BOTH $IF $EQU $LAST[1] 8.12346 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": double member observer =" $LAST[1]"\n";

select  testsuite_base::getObjectType(new testsuite_base().sL);
ECHO BOTH $IF $EQU $LAST[1] "java.lang.Short" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": unknown object member observer =" $LAST[1]"\n";

select new testsuite_base().sAI[0];
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": array of int member observer 1st elt=" $LAST[1]"\n";

select testsuite_base::getObjectType (new testsuite_base().sAL[0]);
ECHO BOTH $IF $EQU $LAST[1] "java.lang.Short" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": array of unknown objects member observer tag (1st elt) =" $LAST[1]"\n";

select new testsuite_base().sstr;
ECHO BOTH $IF $EQU $LAST[1] "abc" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": String member observer =" $LAST[1]"\n";

select year (new testsuite_base().sdat);
ECHO BOTH $IF $EQU $LAST[1] 1972 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Date member observer year=" $LAST[1]"\n";

select sprintf ('%.4f', new testsuite_base().tF);
ECHO BOTH $IF $EQU $LAST[1] 0.1234 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": implied type float member observer =" $LAST[1]"\n";

select sprintf ('%.4f', new testsuite_base()."F");
ECHO BOTH $IF $EQU $LAST[1] 0.1234 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": implied type & name member observer =" $LAST[1]"\n";

select new testsuite_base(-12).sI;
ECHO BOTH $IF $EQU $LAST[1] -12 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": constructor w/ params =" $LAST[1]"\n";

select testsuite_base::getObjectType (testsuite_base::echoDouble (12));
ECHO BOTH $IF $EQU $LAST[1] "java.lang.Double" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": dynamic method w/ unknown object =" $LAST[1]"\n";

select testsuite_base::echoThis (new testsuite_base());
ECHO BOTH $IF $EQU $LAST[1] -7 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": static method w/ object param =" $LAST[1]"\n";

select testsuite_base::echoThis (new testsuite());
ECHO BOTH $IF $EQU $LAST[1] -7 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": static method w/ subtype object param =" $LAST[1]"\n";

select testsuite_base::static_EchoInt (-12);
ECHO BOTH $IF $EQU $LAST[1] -12 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": static method w/ int param =" $LAST[1]"\n";

select testsuite_base::change_it (new testsuite_base());
ECHO BOTH $IF $EQU $LAST[1] -7 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": static method modifying the object =" $LAST[1]"\n";

select new testsuite_base()."overload_method"(-13);
ECHO BOTH $IF $EQU $LAST[1] -11 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": dynamic overloaded method in base =" $LAST[1]"\n";

select new testsuite()."overload_method"(-13);
ECHO BOTH $IF $EQU $LAST[1] -1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": dynamic overloaded method in sub class =" $LAST[1]"\n";

select new testsuite().ts_fld;
ECHO BOTH $IF $EQU $LAST[1] 12 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": member in sub class =" $LAST[1]"\n";

select new testsuite().echoInt(cast (12 as double precision));
ECHO BOTH $IF $EQU $LAST[1] 25 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": method w/ two sigs sig1 =" $LAST[1]"\n";

select new testsuite().echoInt(cast (12 as integer));
ECHO BOTH $IF $EQU $LAST[1] 24 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": method w/ two sigs sig2 =" $LAST[1]"\n";

select new testsuite().echoInt(cast (12 as varchar));
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": ambiguous method call STATE=" $STATE" MESSAGE=" $MESSAGE "\n";

select new testsuite_base().protected_echo_int(-12);
ECHO BOTH $IF $EQU $LAST[1] -12 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": protected method =" $LAST[1]"\n";

select new testsuite_base().private_echo_int(-12);
ECHO BOTH $IF $EQU $LAST[1] -12 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": private method =" $LAST[1]"\n";

select new testsuite().private_echo_int(-12);
ECHO BOTH $IF $EQU $LAST[1] -12 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": private through subclass method =" $LAST[1]"\n";

select new testsuite_base()."echoDbl"(12.12);
ECHO BOTH $IF $EQU $LAST[1] 12.12 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": implied name/args method =" $LAST[1]"\n";

select new testsuite()."echoDbl"('12.12');
ECHO BOTH $IF $EQU $LAST[1] 12.12 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": implied name/args w/varchar for double param method =" $LAST[1]"\n";

select testsuite_base::non_existant_static_var();
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": invalid static member STATE=" $STATE" MESSAGE=" $MESSAGE "\n";

select new testsuite_base().non_existant_method();
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": invalid method STATE=" $STATE" MESSAGE=" $MESSAGE "\n";

select (deserialize (serialize (new testsuite_base ())) as testsuite_base).sI;
ECHO BOTH $IF $EQU $LAST[1] 7 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": serializing/deserializing base class =" $LAST[1]"\n";

select (deserialize (serialize (new testsuite ())) as testsuite).sI;
ECHO BOTH $IF $EQU $LAST[1] 7 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": serializing/deserializing subtype basef =" $LAST[1]"\n";

select (deserialize (serialize (new testsuite ())) as testsuite).ts_fld;
ECHO BOTH $IF $EQU $LAST[1] 12 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": serializing/deserializing subtype subf =" $LAST[1]"\n";

select (deserialize (serialize (new testsuite_ns ())) as testsuite_ns).ts_fld;
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": serializing/deserializing non-serializable type STATE=" $STATE" MESSAGE=" $MESSAGE "\n";


select isnull (deserialize (serialize (new testsuite_ns ())));
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": serializing/deserializing non-serializable returns NULL =" $LAST[1]"\n";

select udt_instance_of (deserialize (serialize (new testsuite_ns ())));

delete from testsuite;

insert into testsuite (id) values (1);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": inserting nulls into obj cols STATE=" $STATE" MESSAGE=" $MESSAGE "\n";

insert into testsuite (id, b_data) values (2, new testsuite_base());
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": inserting base class into col STATE=" $STATE" MESSAGE=" $MESSAGE "\n";

insert into testsuite (id, b_data) values (3, new testsuite());
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": inserting sub class into base col STATE=" $STATE" MESSAGE=" $MESSAGE "\n";

insert into testsuite (id, ns_data) values (4, new testsuite());
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": inserting wrong class into ns_data col STATE=" $STATE" MESSAGE=" $MESSAGE "\n";

insert into testsuite (id, ts_data) values (5, new testsuite_base());
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": inserting super class into derived class col STATE=" $STATE" MESSAGE=" $MESSAGE "\n";

insert into testsuite (id, a_data) values (6, new testsuite_base());
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": inserting class into ANY col STATE=" $STATE" MESSAGE=" $MESSAGE "\n";

insert into testsuite (id, a_data) values (7, new testsuite());
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": inserting sub class into ANY col STATE=" $STATE" MESSAGE=" $MESSAGE "\n";

insert into testsuite (id, ts_data) values (8, new testsuite());
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": inserting sub class into sub class col STATE=" $STATE" MESSAGE=" $MESSAGE "\n";

select (a_data as testsuite_base).sI from testsuite where id = 6;
ECHO BOTH $IF $EQU $LAST[1] 7 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": deserializing class from ANY col =" $LAST[1] "\n";

select (a_data as testsuite).sI from testsuite where id = 7;
ECHO BOTH $IF $EQU $LAST[1] 7 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": deserializing derived from ANY col =" $LAST[1] "\n";

select s.b_data."overload_method"(s.b_data.sI) from testsuite s where s.id = 2;
ECHO BOTH $IF $EQU $LAST[1] 9 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": deserializing class from base class col =" $LAST[1] "\n";

select s.b_data."overload_method" (s.b_data.sI) from testsuite s where s.id = 3;
ECHO BOTH $IF $EQU $LAST[1] 19 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": deserializing subclass from base class col =" $LAST[1] "\n";

select s.ts_data.ts_fld from testsuite s where s.id = 8;
ECHO BOTH $IF $EQU $LAST[1] 12 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": deserializing derived class from derived class col =" $LAST[1] "\n";

create procedure get_property (in x varchar) returns varchar
  language java external name 'java.lang.System.getProperty';
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": CREATE PROCEDURE .. EXTERNAL NAME STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select get_property ('java.vm.name');
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": CREATE PROCEDURE .. EXTERNAL NAME STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

ECHO BOTH "COMPLETED: SQL200n user defined types java suite (java_ts2.sql) WITH " $ARGV[0] " FAILED, " $ARGV[1] " PASSED\n\n";
