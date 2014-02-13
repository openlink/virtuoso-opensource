--  
--  $Id$
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
create user "EmptySA";
create user "Import1";
create user "Import2";
create user "Import3";
create user "Compound1";
create user "Compound2";
create user "DocLit";
create user "DocPars";
create user "RpcEnc";

use Interop3;

-- Empty SOAP Action
create procedure
EmptySA.echoString (in a nvarchar __soap_type 'http://www.w3.org/2001/XMLSchema:string')
returns nvarchar __soap_type 'http://www.w3.org/2001/XMLSchema:string'
{
  return a;
};

-- Import1
create procedure
Import1.echoString (in x nvarchar __soap_type 'http://www.w3.org/2001/XMLSchema:string')
returns nvarchar __soap_type 'http://www.w3.org/2001/XMLSchema:string'
{
  return x;
};


-- Import2
create procedure
Import2.echoStruct (in inputStruct any __soap_type 'http://soapinterop.org/xsd:SOAPStruct')
returns any __soap_type 'http://soapinterop.org/xsd:SOAPStruct'
{
  return inputStruct;
};


-- Import3
create procedure
Import3.echoStructArray (in inputArray any __soap_type 'http://soapinterop.org/xsd2:ArrayOfSOAPStruct')
returns any __soap_type 'http://soapinterop.org/xsd2:ArrayOfSOAPStruct'
{
  return inputArray;
};

create procedure
Import3.echoStruct (in inputStruct any __soap_type 'http://soapinterop.org/xsd:SOAPStruct')
returns any __soap_type 'http://soapinterop.org/xsd:SOAPStruct'
{
  return inputStruct;
};

-- Compund1
create procedure
Compund1.echoPerson (in x any __soap_type 'http://soapinterop.org/xsd:x_Person')
      returns any __soap_doc 'http://soapinterop.org/xsd:echoPersonReturn'
{
  dbg_obj_print ('Compund1.echoPerson', x);
  return x;
};

create procedure
Compund1.echoDocument (in x any __soap_type 'http://soapinterop.org/xsd:x_Document')
returns any __soap_doc 'http://soapinterop.org/xsd:result_Document'
{
  dbg_obj_print ('echoDocument', x);
  return x;
};

-- Compund2
create procedure
Compund2.echoEmployee (in x any __soap_type 'http://soapinterop.org/employee:x_Employee')
      returns any __soap_doc 'http://soapinterop.org/employee:result_Employee'
{
  dbg_obj_print ('echoEmployee: ', x);
  return x;
};

-- Doc/Literal
create procedure
DocLit.echoString (in echoStringParam varchar __soap_type 'http://soapinterop.org/xsd:echoStringParam')
      returns any __soap_doc 'http://soapinterop.org/xsd:echoStringReturn'
{
      return echoStringParam;
};

create procedure
DocLit.echoStruct (in echoStructParam any __soap_type 'http://soapinterop.org/xsd:echoStructParam')
      returns any __soap_doc 'http://soapinterop.org/xsd:echoStructReturn'
{
      return echoStructParam;
};

create procedure
DocLit.echoStringArray (in echoStringArrayParam any
                           __soap_type 'http://soapinterop.org/xsd:echoStringArrayParam')
      returns any __soap_doc 'http://soapinterop.org/xsd:echoStringArrayReturn'
{
      dbg_obj_print (echoStringArrayParam);
      return echoStringArrayParam;
};

-- Doc/Literal Parameters
create procedure
DocPars.echoString (in echoString varchar __soap_type 'http://soapinterop.org/xsd:echoString')
      returns any __soap_docw 'http://soapinterop.org/xsd:echoStringResponse'
{
      dbg_obj_print ('DocPars.echoString: ', echoString);
      return echoString;
};

create procedure
DocPars.echoStruct (in echoStruct varchar __soap_type 'http://soapinterop.org/xsd:echoStruct')
      returns any __soap_docw 'http://soapinterop.org/xsd:echoStructResponse'
{
      dbg_obj_print (echoStruct);
      return echoStruct;
};

create procedure
DocPars.echoStringArray (in echoStringArray varchar __soap_type 'http://soapinterop.org/xsd:echoStringArray')
      returns any __soap_docw 'http://soapinterop.org/xsd:echoStringArrayResponse'
{
      dbg_obj_print (echoStringArray);
      return echoStringArray;
};

-- RPC encoded
create procedure
RpcEnc.echoString (in param0 nvarchar __soap_type 'http://www.w3.org/2001/XMLSchema:string')
returns nvarchar __soap_type 'http://www.w3.org/2001/XMLSchema:string'
{
  dbg_obj_print ('\nechoString', param0, '\n');
  return param0;
};


create procedure
RpcEnc.echoStringArray (
    in param0 any __soap_type 'http://soapinterop.org/xsd:ArrayOfstring')
__soap_type 'http://soapinterop.org/xsd:ArrayOfstring'
{
  dbg_obj_print ('\nechoStringArray', param0, '\n');
  return param0;
};

create procedure
RpcEnc.echoStruct (
    in param0 any __soap_type 'http://soapinterop.org/xsd:SOAPStruct')
__soap_type 'http://soapinterop.org/xsd:SOAPStruct'
{
  dbg_obj_print ('\nechoStruct', param0, '\n');
  return param0;
};

-- Grants
grant execute on EmptySA.echoString to "EmptySA";

grant execute on Import1.echoString to "Import1";

grant execute on Import2.echoStruct to "Import2";

grant execute on Import3.echoStructArray to "Import3";
grant execute on Import3.echoStruct to "Import3";

grant execute on Compund1.echoPerson to "Compound1";
grant execute on Compund1.echoDocument to "Compound1";

grant execute on Compund2.echoEmployee to "Compound2";

grant execute on DocLit.echoString to "DocLit";
grant execute on DocLit.echoStruct to "DocLit";
grant execute on DocLit.echoStringArray to "DocLit";

grant execute on DocPars.echoString to "DocPars";
grant execute on DocPars.echoStruct  to "DocPars";
grant execute on DocPars.echoStringArray  to "DocPars";

grant execute on RpcEnc.echoString  to "RpcEnc";
grant execute on RpcEnc.echoStringArray to "RpcEnc";
grant execute on RpcEnc.echoStruct  to "RpcEnc";

use DB;

VHOST_DEFINE (
    lpath=>'/r3/EmptySA',
    ppath=>'/SOAP/',
    soap_user=>'EmptySA',
    soap_opts=>vector(
      'Namespace','http://soapinterop/',
      'MethodInSoapAction','empty',
      'ServiceName', 'EmptySA',
      'CR-escape', 'yes')
    );

VHOST_DEFINE (
    lpath=>'/r3/Import1',
    ppath=>'/SOAP/',
    soap_user=>'Import1',
    soap_opts=>vector(
      'Namespace','http://soapinterop.org/',
      'MethodInSoapAction','no',
      'ServiceName', 'Import1',
      'CR-escape', 'yes')
    );

VHOST_DEFINE (
    lpath=>'/r3/Import2',
    ppath=>'/SOAP/',
    soap_user=>'Import2',
    soap_opts=>vector(
      'Namespace','http://soapinterop.org/',
      'MethodInSoapAction','no',
      'ServiceName', 'Import2',
      'CR-escape', 'yes')
    );

VHOST_DEFINE (
    lpath=>'/r3/Import3',
    ppath=>'/SOAP/',
    soap_user=>'Import3',
    soap_opts=>vector(
      'Namespace','http://soapinterop.org/',
      'MethodInSoapAction','no',
      'ServiceName', 'Import3',
      'CR-escape', 'yes')
    );

VHOST_DEFINE (
    lpath=>'/r3/Compound1',
    ppath=>'/SOAP/',
    soap_user=>'Compound1',
    soap_opts=>vector(
      'Namespace','http://soapinterop/',
      'MethodInSoapAction','no',
      'ServiceName', 'Compound1',
      'elementFormDefault','qualified',
      'CR-escape', 'yes')
    );

VHOST_DEFINE (
    lpath=>'/r3/Compound2',
    ppath=>'/SOAP/',
    soap_user=>'Compound2',
    soap_opts=>vector(
      'Namespace','http://soapinterop/',
      'MethodInSoapAction','only',
      'ServiceName', 'Compound2',
      'elementFormDefault','qualified',
      'CR-escape', 'yes')
    );

VHOST_DEFINE (
    lpath=>'/r3/DocLit',
    ppath=>'/SOAP/',
    soap_user=>'DocLit',
    soap_opts=>vector(
      'Namespace','http://soapinterop.org/',
      'MethodInSoapAction','no',
      'ServiceName', 'WSDLInteropTestDocLit',
      'elementFormDefault','qualified',
      'CR-escape', 'yes')
    );

VHOST_DEFINE (
    lpath=>'/r3/DocPars',
    ppath=>'/SOAP/',
    soap_user=>'DocPars',
    soap_opts=>vector(
      'Namespace','http://soapinterop.org/',
      'MethodInSoapAction','no',
      'ServiceName', 'WSDLInteropTestDocLit',
      'elementFormDefault','unqualified',
      'CR-escape', 'yes')
    );

VHOST_DEFINE (
    lpath=>'/r3/RpcEnc',
    ppath=>'/SOAP/',
    soap_user=>'RpcEnc',
    soap_opts=>vector(
      'Namespace','http://soapinterop.org/',
      'MethodInSoapAction','empty',
      'ServiceName', 'WSDLInteropTestRpcEnc',
      'CR-escape', 'yes')
    );

use Interop3;

create user "TestList";

create procedure
TestList.echoLinkedList (in param0 any __soap_type 'http://soapinterop.org/xsd:List')
returns any __soap_type 'http://soapinterop.org/xsd:List'
{
  dbg_obj_print ('echoLinkedList: \n', param0);
  return param0;
};

grant execute on TestList.echoLinkedList to "TestList";

use DB;

VHOST_DEFINE (
    lpath=>'/r3/List',
    ppath=>'/SOAP/',
    soap_user=>'TestList',
    soap_opts=>vector(
      'SchemaNS','http://soapinterop.org/xsd',
      'Namespace','http://soapinterop.org/',
      'MethodInSoapAction','empty',
      'ServiceName', 'WSDLInteropTestList',
      'CR-escape', 'yes')
    );
use Interop3;

create user "TestHeaders";

create procedure
Header.echoString (in a varchar __soap_type 'http://soapinterop.org/xsd:echoStringParam',
    in Header1 any __soap_header 'http://soapinterop.org/xsd:Header1',
    in Header2 any __soap_header 'http://soapinterop.org/xsd:Header2'
    )
      returns any __soap_doc 'http://soapinterop.org/xsd:echoStringReturn'
{

      dbg_obj_print ('Header1: ', Header1);
      dbg_obj_print ('Header2: ', Header2);
      return a;
};

grant execute on Header.echoString to "TestHeaders";

use DB;

VHOST_DEFINE (
    lpath=>'/r3/Hdr',
    ppath=>'/SOAP/',
    soap_user=>'TestHeaders',
    soap_opts=>vector(
      'Namespace','http://soapinterop.org/',
      'MethodInSoapAction','no',
      'ServiceName', 'RetHeader',
      'elementFormDefault','qualified',
      'CR-escape', 'yes')

    );


use DB;


ECHO BOTH "STARTED: SOAP Interop III tests\n";

SET ARGV[0] 0;
SET ARGV[1] 0;

drop module InteropTests;

-- Empty SA

drop module EmptySA;
SOAP_WSDL_IMPORT ('http://localhost:$U{HTTPPORT}/r3/EmptySA/services.wsdl');
ECHO BOTH $IF $EQU $STATE OK "PASSED" "*** FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": The Interop III tests Imported EmptySA STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select soap_box_xml_entity_validating (aref(EmptySA.echoString('This is a test'),1), 'string');
ECHO BOTH $IF $EQU $LAST[1] 'This is a test' "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": EmptySA.echoString : " $LAST[1] "\n";


-- Import3
drop module Import3;
SOAP_WSDL_IMPORT ('http://localhost:$U{HTTPPORT}/r3/Import3/services.wsdl');
ECHO BOTH $IF $EQU $STATE OK "PASSED" "*** FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": The Interop III tests Imported Import3 STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select get_keyword ('varString', soap_box_xml_entity_validating (aref (Import3.echoStruct (soap_box_structure ('varString', 'This is a test', 'varInt', 123,'varFloat', cast(3.14 as float))), 1), 'http://soapinterop.org/xsd:SOAPStruct'), NULL);
ECHO BOTH $IF $EQU $LAST[1] 'This is a test' "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Import3.echoStruct (varString element) : " $LAST[1] "\n";

select get_keyword ('varString', aref(soap_box_xml_entity_validating (aref (Import3.echoStructArray (vector (soap_box_structure ('varString', 'This is a test', 'varInt', 123,'varFloat', cast(3.14 as float)),soap_box_structure ('varString', 'This is a test', 'varInt', 123,'varFloat', cast(3.14 as float)))),1), 'http://soapinterop.org/xsd:ArrayOfSOAPStruct'), 0), NULL);

ECHO BOTH $IF $EQU $LAST[1] 'This is a test' "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Import3.echoStructArray (varString element of 1-st item) : " $LAST[1] "\n";


-- Compund1
drop module Compound1;
SOAP_WSDL_IMPORT ('http://localhost:$U{HTTPPORT}/r3/Compound1/services.wsdl');
ECHO BOTH $IF $EQU $STATE OK "PASSED" "*** FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": The Interop III tests Imported Compound1 STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select get_keyword ('Name' , aref (soap_box_xml_entity_validating (Compound1.echoPerson (vector (composite (), vector ('Name','the test','Male', soap_boolean(1)), 'Age', cast (1234 as double precision), 'ID', cast (3.14 as float))), 'http://soapinterop.org/xsd:Person'), 1), NULL);
ECHO BOTH $IF $EQU $LAST[1] 'the test' "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Compound1.echoPerson (Name attributte) : " $LAST[1] "\n";

select get_keyword ('ID' , aref (soap_box_xml_entity_validating (Compound1.echoDocument (vector (composite (), vector ('ID','123456'), 'this is a doc')), 'http://soapinterop.org/xsd:Document'), 1), NULL);
ECHO BOTH $IF $EQU $LAST[1] '123456' "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Compound1.echoDocument (ID attributte) : " $LAST[1] "\n";


-- Compund2
drop module Compound2;
SOAP_WSDL_IMPORT ('http://localhost:$U{HTTPPORT}/r3/Compound2/services.wsdl');
ECHO BOTH $IF $EQU $STATE OK "PASSED" "*** FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": The Interop III tests Imported Compound2 STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select get_keyword ('ID' , soap_box_xml_entity_validating (Compound2.echoEmployee (soap_box_structure ('person', soap_box_structure ('Name', 'the test','Male', soap_boolean(1)),'salary',cast (12 as double precision),'ID',12345)), 'http://soapinterop.org/employee:Employee'), NULL);
ECHO BOTH $IF $EQU $LAST[1] '12345' "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Compound2.echoPerson (ID element) : " $LAST[1] "\n";

-- Doc/Lit
drop module WSDLInteropTestDocLit;
SOAP_WSDL_IMPORT ('http://localhost:$U{HTTPPORT}/r3/DocLit/services.wsdl');
ECHO BOTH $IF $EQU $STATE OK "PASSED" "*** FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": The Interop III tests Imported DocLit STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select soap_box_xml_entity_validating (WSDLInteropTestDocLit.echoString('This is a test'), 'string');
ECHO BOTH $IF $EQU $LAST[1] 'This is a test' "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": DocLit.echoString : " $LAST[1] "\n";

select aref(soap_box_xml_entity_validating (WSDLInteropTestDocLit.echoStringArray(vector('This','is','a test')), 'http://soapinterop.org/xsd:ArrayOfstring'), 2);
ECHO BOTH $IF $EQU $LAST[1] 'a test' "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": DocLit.echoStringArray : " $LAST[1] "\n";

-- Doc/Lit params
drop module WSDLInteropTestDocLit;
SOAP_WSDL_IMPORT ('http://localhost:$U{HTTPPORT}/r3/DocPars/services.wsdl');
ECHO BOTH $IF $EQU $STATE OK "PASSED" "*** FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": The Interop III tests Imported DocLit parameters STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select aref(soap_box_xml_entity_validating (WSDLInteropTestDocLit.echoString(vector('This is a test')), 'http://soapinterop.org/xsd:ArrayOfstring'), 0);
ECHO BOTH $IF $EQU $LAST[1] 'This is a test' "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": DocLitPars.echoString : " $LAST[1] "\n";

-- List
drop module WSDLInteropTestList;
SOAP_WSDL_IMPORT ('http://localhost:$U{HTTPPORT}/r3/List/services.wsdl');
ECHO BOTH $IF $EQU $STATE OK "PASSED" "*** FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": The Interop III tests Imported List parameters STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select get_keyword ('varString', get_keyword ('child', soap_box_xml_entity_validating (aref(WSDLInteropTestList.echoLinkedList(soap_box_structure ('varInt',123,'varString','test 1','child', soap_box_structure ('varInt',123,'varString','test 2','child',NULL))),1), 'http://soapinterop.org/xsd:List')));

ECHO BOTH $IF $EQU $LAST[1] 'test 2' "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": echoLinkedList (varString of 1-st child) : " $LAST[1] "\n";

ECHO BOTH "COMPLETED WITH " $ARGV[0] " FAILED, " $ARGV[1] " PASSED: SOAP Interop III tests\n";
