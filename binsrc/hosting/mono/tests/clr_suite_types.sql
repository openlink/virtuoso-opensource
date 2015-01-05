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

drop type "Test_Two";
drop type "Test_a1";
drop type "Test_a2";

import_clr ('sample', vector ('Test.Two'));

ECHO BOTH $IF $EQU $STATE "OK" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": import_clr 'Test.Two' = " $STATE "\n";

create procedure test_1 (in val1 integer, in val2 integer)
{
   declare test Test_Two;
   declare ret integer;

   test := new Test_Two();

   ret := test.TestInt (val1, val2);

   return ret;
}
;

select test_1(13, 9);
ECHO BOTH $IF $EQU $LAST[1] 22 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Test 1 - LAST = " $LAST[1] "\n";


create procedure test_2 ()
{
   declare test Test_Two;
   declare ret integer;

   test := new Test_Two();

   ret := test.TestFloat (cast (2.2 as real), cast (99.7 as real));

   return cast (ret as integer);
}
;

select test_2();
ECHO BOTH $IF $EQU $LAST[1] 101 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Test 2 - LAST = " $LAST[1] "\n";


create procedure test_3 ()
{
   declare test Test_Two;
   declare ret integer;

   test := new Test_Two();

   ret := test.TestDouble (cast (2.8 as float), cast (99.9 as float));

   return ret;
}
;


select test_3();
ECHO BOTH $IF $EQU $LAST[1] 102.7 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Test 3 - LAST = " $LAST[1] "\n";

create procedure test_4 (in val smallint)
{
   declare test Test_Two;
   declare ret integer;

   test := new Test_Two();

   ret := test.TestBoolean (val);

   return ret;
}
;


select test_4(1);
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Test 4.1 - LAST = " $LAST[1] "\n";

select test_4(0);
ECHO BOTH $IF $NEQ $LAST[1] 0 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Test 4.2 - LAST = " $LAST[1] "\n";

create procedure test_5 ()
{
   declare test Test_Two;
   declare ret integer;

   test := new Test_Two();

   ret := test.int_test;

   return ret;
}
;

select test_5();
ECHO BOTH $IF $EQU $LAST[1] 125 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Test 5 - LAST = " $LAST[1] "\n";

select new Test_Two().TestInt (11, 15) + 1;
ECHO BOTH $IF $EQU $LAST[1] 27 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Test_Two().TestInt - LAST = " $LAST[1] "\n";

select new Test_Two().TestDouble (11.1001, 15.1001) + cast (1.1001 as double precision);
ECHO BOTH $IF $EQU $LAST[1] 27.3003 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Test_Two().TestDouble - LAST = " $LAST[1] "\n";

select new Test_Two().int_test;
ECHO BOTH $IF $EQU $LAST[1] 125 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Test_Two().int_test - LAST = " $LAST[1] "\n";

select new Test_Two().non_existant;
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": non_existant property = " $STATE "\n";

select aref (new Test_Two().TestSringArray (), 0);
ECHO BOTH $IF $EQU $LAST[1] "aa" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Test_Two().TestSringArray[0] - LAST = " $LAST[1] "\n";

select aref (new Test_Two().TestSringArray (), 2);
ECHO BOTH $IF $EQU $LAST[1] "cc" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Test_Two().TestSringArray[2] - LAST = " $LAST[1] "\n";

drop type "Test_Two";
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": drop type Test_Two STATE=" $STATE "\n";

create type "Test_Two"
language CLR external name 'sample/Test.Two'
AS (int_test integer)
TEMPORARY
        CONSTRUCTOR METHOD "Test_Two" ("_in" integer external type 'System.Int32'),

        METHOD "MyInt" ("i" integer external type 'System.Int32',
			"t" integer external type 'System.Int32')
  	returns integer external type 'System.Int32'  external name '_MyInt_',

        METHOD "TestInt" ("val1" integer external type 'Int32',
			  "val2" integer external type 'Int32')	returns integer,

        METHOD "TestDouble" (bla1 double precision external type 'System.Double',
			     bla2 double precision external type 'System.Double')
        returns double precision external type 'System.Double' external name 'None',

        METHOD "TestBoolean" ("i" integer external type 'System.Int32') returns smallint
;

ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": create type Test_Two TEMPORARY STATE=" $STATE "\n";

select new Test_Two().int_test;
ECHO BOTH $IF $EQU $LAST[1] 125 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Test_Two().int_test - LAST = " $LAST[1] "\n";

select new Test_Two().TestInt (15, 2);
ECHO BOTH $IF $EQU $LAST[1] 17 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Test_Two().TestInt - LAST = " $LAST[1] "\n";

select new Test_Two().TestDouble (1.101, 15.101);
ECHO BOTH $IF $EQU $LAST[1] 16.202 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Test_Two().TestDouble - LAST = " $LAST[1] "\n";

drop type "Test_Two";
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": drop type Test_Two STATE=" $STATE "\n";

create type "Test_Two"
language CLR external name 'sample/Test.Two'
AS ("int_test" integer external name 'int_test' external type 'System.Int32',
    "non_existant" integer external name 'non_existant' external type 'System.Int32')

        CONSTRUCTOR METHOD "Test_Two" ("_in" integer external type 'System.Int32'),

        METHOD "MyInt" ("i" integer external type 'System.Int32',
			"t" integer external type 'System.Int32')
	returns integer external type 'System.Int32'  external name 'MyInt',

        METHOD "TestInt" ("i" integer external type 'System.Int32',
			  "t" integer external type 'System.Int32')
	returns integer external type 'System.Int32'  external name 'TestInt',

        METHOD "TestFloat" ("i" real external type 'System.Single',
			    "t" real external type 'System.Single')
	returns real external type 'System.Single'  external name 'TestFloat',

        METHOD "TestDouble" ("i" double precision external type 'System.Double',
			     "t" double precision external type 'System.Double')
        returns double precision external type 'System.Double'  external name 'TestDouble',

        METHOD "TestBoolean" ("i" integer external type 'System.Int32') returns smallint
;

ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": create type Test_Two (import) STATE=" $STATE "\n";

select new Test_Two().non_existant;
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": non_existant property = " $STATE "\n";

create procedure test_4 (in val smallint)
{
   declare test1 Test_Two;
   declare test2 Test_Two;

   test1 := new Test_Two();
   test2 := test1;

   return test2.TestBoolean (val);
}
;

select test_4(1);
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Test 4.1 - LAST = " $LAST[1] "\n";

select test_4(0);
ECHO BOTH $IF $NEQ $LAST[1] 0 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Test 4.2 - LAST = " $LAST[1] "\n";

select new Test_Two().TestInt (cast (11 as real), 15) - 1;
ECHO BOTH $IF $EQU $LAST[1] 25 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Test_Two().TestInt cast real - LAST = " $LAST[1] "\n";

select new Test_Two().TestInt (cast (11 as float), 15) - 1;
ECHO BOTH $IF $EQU $LAST[1] 25 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Test_Two().TestInt cast float - LAST = " $LAST[1] "\n";

select new Test_Two().TestInt (cast (11 as float), cast (14 as double precision));
ECHO BOTH $IF $EQU $LAST[1] 25 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Test_Two().TestInt cast double precision - LAST = " $LAST[1] "\n";

select new Test_Two().TestInt (cast (11 as varchar), cast (14 as varchar));
ECHO BOTH $IF $EQU $LAST[1] 25 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Test_Two().TestInt cast varchar - LAST = " $LAST[1] "\n";

select import_clr ('sample', vector ('Test.a1'));
ECHO BOTH $IF $EQU $STATE "OK" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": import_clr 'Test_a1' = " $STATE "\n";

select import_clr ('sample', vector ('Test.a2'));
ECHO BOTH $IF $EQU $STATE "OK" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": import_clr 'Test_a2' = " $STATE "\n";

select new Test_a1().ToString_o();
ECHO BOTH $IF $EQU $LAST[1] String "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Test_a1() overload method - LAST = " $LAST[1] "\n";

select new Test_a2().ToString_o();
ECHO BOTH $IF $EQU $LAST[1] String1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Test_a2() overload method - LAST = " $LAST[1] "\n";

drop type "Test_a1";
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": drop type Test_a1 STATE=" $STATE "\n";

select new Test_a1().ToString_o();
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Type Test_a1 not exist - LAST = " $LAST[1] "\n";

select new Test_a2().ToString_o();
ECHO BOTH $IF $EQU $LAST[1] String1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Test_a2() overload method - LAST = " $LAST[1] "\n";

drop type "Test_a2";
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": drop type Test_a2 STATE=" $STATE "\n";

drop type "Test_Two";
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": drop type Test_Two STATE=" $STATE "\n";
