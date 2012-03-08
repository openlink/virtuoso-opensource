--  
--  $Id$
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
ECHO BOTH "STARTED: SOAP complex types tests\n";

SET ARGV[0] 0;
SET ARGV[1] 0;

vhost_remove (lpath=>'/soap-cpl');
drop user SOAP_U1;
create user SOAP_U1;
vhost_define (lpath=>'/soap-cpl', ppath=>'/SOAP/', soap_user=>'SOAP_U1',
    soap_opts=>
    vector ('ServiceName', 'soap-cpl',
	    'MethodInSoapAction', 'yes',
	    'elementFormDefault', 'unqualified',
	    'Use', 'literal')
);

ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": /soap-cpl defined : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";



drop type soap_stru;

create type soap_stru as
	(
	    id  int,
	    dt  varchar,
	    arr int array
	);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": soap_stru defined : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";


create procedure soap_stru_array (in x soap_stru array)
 returns soap_stru array
{
  return x;
}
;

ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": soap_stru_array defined : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";


create procedure echoIntArray (in inputArray int array [5])
returns int array [5]
{
  return inputArray;
}
;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": echoIntArray defined : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";


create procedure echoMultiArray (in i int array array [3] array [2])
returns int array array array
{
  return i;
};
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": echoMultiArray defined : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";


grant execute on soap_stru to SOAP_U1;
grant execute on soap_stru_array to SOAP_U1;
grant execute on echoIntArray to SOAP_U1;
grant execute on echoMultiArray to SOAP_U1;

create procedure test_soap_stru_array ()
{
  declare s1,s2 soap_stru;
  declare ret, xt any;

  s1 := new soap_stru ();
  s1.id := 1;
  s1.dt := 'abc';
  s1.arr := vector (1,2,3);

  s2 := new soap_stru ();
  s2.id := 1;
  s2.dt := 'abc';
  s2.arr := vector (3,4,5);
  ret := soap_client (url=>'http://localhost:$U{HTTPPORT}/soap-cpl',
	operation=>'SOAP_STRU_ARRAY', parameters=>vector ('X', vector (s1,s2)),
	style=>5, target_namespace=>'services.wsdl');
  xt := xml_tree_doc (ret);
  return xpath_eval ('//CallReturn/item[2]/ARR/item[3]/text()', xt);
}
;

select test_soap_stru_array ();
ECHO BOTH $IF $EQU $LAST[1] 5 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": //CallReturn/item[2]/ARR/item[3]/text() = " $LAST[1] "\n";

create procedure test_int_array ()
{
  declare ret, xt any;
  ret := soap_client (url=>'http://localhost:$U{HTTPPORT}/soap-cpl',
	operation=>'ECHOINTARRAY', parameters=>vector ('INPUTARRAY', vector (1,2,3,4,5)),
	style=>5, target_namespace=>'services.wsdl');
  xt := xml_tree_doc (ret);
  return xpath_eval ('//CallReturn/item[4]/text()', xt);
}
;

select test_int_array ();
ECHO BOTH $IF $EQU $LAST[1] 4 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": //CallReturn/item[4]/text() = " $LAST[1] "\n";

create procedure test_int_marray ()
{
  declare ret, xt any;
  ret := soap_client (url=>'http://localhost:$U{HTTPPORT}/soap-cpl',
	operation=>'ECHOMULTIARRAY', parameters=>vector ('I', vector (vector(vector(1,2), vector(3)), vector(vector(null,6), vector(7,8)))),
	style=>5, target_namespace=>'services.wsdl');
  xt := xml_tree_doc (ret);
  return xpath_eval ('//CallReturn/item[2]/item[2]/item[2]/text()', xt);
}
;

select test_int_marray ();
ECHO BOTH $IF $EQU $LAST[1] 8 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": //CallReturn/item[2]/item[2]/item[2]/text() = " $LAST[1] "\n";

create procedure test_int_marray ()
{
  declare ret, xt any;
  ret := soap_client (url=>'http://localhost:$U{HTTPPORT}/soap-cpl',
	operation=>'ECHOMULTIARRAY', parameters=>vector ('I', vector (vector(vector(1,null), vector(3,4)), vector(vector(5,6), vector(15,16), vector (10,11,12), vector(7,8, 9)))),
	style=>5, target_namespace=>'services.wsdl');
  xt := xml_tree_doc (ret);
  return xpath_eval ('//CallReturn/item[2]/item[2]/item[2]/text()', xt);
}
;

select test_int_marray ();
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": array over limit : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

vhost_remove (lpath=>'/soap-udt');
create user SOAP_U2;
vhost_define (lpath=>'/soap-udt', ppath=>'/SOAP/', soap_user=>'SOAP_U2',
    soap_opts=>
    vector ('ServiceName', 'soap-udt',
	    'MethodInSoapAction', 'yes',
	    'elementFormDefault', 'unqualified',
	    'Use', 'encoded')
);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": /soap-udt defined : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";



drop type MyWebSvc;
create type MyWebSvc
constructor method MyWebSvc (in a int),
static method echoSInt (in a int, out b int) returns int,
method echoInt (in a int, out b int) returns int,
method echoIntArray (in a int array) returns int array;

ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": MyWebSvc defined : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";


create constructor method MyWebSvc (in a int) for MyWebSvc
{
  return;
}
;

create static method echoSInt (in a int, out b int)
returns int for MyWebSvc
{
  b := a + 1;
  return a;
}
;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Static method defined : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";



create method echoInt (in a int, out b int)
returns int __soap_type 'long' for MyWebSvc
{
  b := a + 1;
  return a;
}
;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": non-static method defined : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";


create method echoIntArray (in a int array)
returns int array for MyWebSvc
{
  return a;
}
;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": echoIntArray method defined : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";



grant execute on MyWebSvc to SOAP_U2;
insert soft SYS_SOAP_UDT_PUB values ('DB.DBA.MYWEBSVC', '*ini*', '*ini*', '/soap-udt');
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": publishing MyWebSvc on /soap-udt : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select xpath_eval ('//CallReturn/text()', xml_tree_doc (soap_client(url=>'http://localhost:$U{HTTPPORT}/soap-udt',operation=>'ECHOSINT',parameters=>vector('a', 15))));

ECHO BOTH $IF $EQU $LAST[1] 15 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": MyWebSvc.echoSInt returned = " $LAST[1] "\n";

select xpath_eval ('//CallReturn/text()', xml_tree_doc (soap_client(url=>'http://localhost:$U{HTTPPORT}/soap-udt',operation=>'ECHOINT',parameters=>vector('a', 16))));
ECHO BOTH $IF $EQU $LAST[1] 16 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": MyWebSvc.echoInt returned = " $LAST[1] "\n";

select xpath_eval ('//CallReturn/item[7]/text()', xml_tree_doc (soap_client(url=>'http://localhost:$U{HTTPPORT}/soap-udt',operation=>'ECHOINTARRAY',parameters=>vector('a', vector(1,2,3,4,null,6,7,8,9,10)))));
ECHO BOTH $IF $EQU $LAST[1] 7 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": MyWebSvc.echoIntArray[7] returned = " $LAST[1] "\n";

select xpath_eval ('count(//CallReturn/item)', xml_tree_doc (soap_client(url=>'http://localhost:$U{HTTPPORT}/soap-udt',operation=>'ECHOINTARRAY',parameters=>vector('a', vector(1,2,3,4,null,6,7,8,9,10)))));
ECHO BOTH $IF $EQU $LAST[1] 10 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": MyWebSvc.echoIntArray count(item) returned = " $LAST[1] "\n";


ECHO BOTH "COMPLETED WITH " $ARGV[0] " FAILED, " $ARGV[1] " PASSED: SOAP complex types tests\n";
