--  
--  $Id$
--  
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--  
--  Copyright (C) 1998-2017 OpenLink Software
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

DB.DBA.USER_CREATE ('INTEROP', '_interop8027918273', vector ('DISABLED', 1));

DB.DBA.user_set_qualifier ('INTEROP', 'Interop');


DB.DBA.VHOST_REMOVE (lpath=>'/Interop');

DB.DBA.VHOST_REMOVE (lpath=>'/interop');

DB.DBA.VHOST_DEFINE (lpath=>'/Interop', ppath=>'/SOAP/', soap_user=>'INTEROP', soap_opts=>vector('Namespace','http://soapinterop.org/','MethodInSoapAction','no', 'ServiceName', 'InteropTests', 'HeaderNS', 'http://soapinterop.org/echoheader/', 'CR-escape', 'yes'));

DB.DBA.VHOST_DEFINE (lpath=>'/interop', ppath=>'/SOAP/', soap_user=>'INTEROP', soap_opts=>vector('Namespace','http://soapinterop.org/','MethodInSoapAction','no', 'ServiceName', 'InteropTests', 'HeaderNS', 'http://soapinterop.org/echoheader/', 'CR-escape', 'yes'));


use Interop;

create procedure
INTEROP.echoString (
    in inputString nvarchar __soap_type 'http://www.w3.org/2001/XMLSchema:string'
    )
returns nvarchar
__soap_type 'http://www.w3.org/2001/XMLSchema:string'
{
  --##This method accepts a single string and echoes it back to the client.
  --dbg_obj_print ('\nechoString', inputString, '\n');
  return inputString;
};

create procedure
INTEROP.echoStringArray (
    in inputStringArray any __soap_type 'http://soapinterop.org/xsd:ArrayOfstring')
__soap_type 'http://soapinterop.org/xsd:ArrayOfstring'
{
  --##This method accepts an array of strings and echoes it back to the client.
  --dbg_obj_print ('\nechoStringArray', inputStringArray, '\n');
  return inputStringArray;
};

create procedure
INTEROP.echoInteger (in inputInteger integer) returns integer
{
  --##This method accepts an single integer and echoes it back to the client.
  --dbg_obj_print ('\nechoInteger', inputInteger, '\n');
  return inputInteger;
};

create procedure
INTEROP.echoIntegerArray (
    in inputIntegerArray any __soap_type 'http://soapinterop.org/xsd:ArrayOfint')
__soap_type 'http://soapinterop.org/xsd:ArrayOfint'
{
  --##This method accepts an array of integers and echoes it back to the client.
  --dbg_obj_print ('\nechoIntegerArray', inputIntegerArray, '\n');
  return inputIntegerArray;
};

create procedure
INTEROP.echoFloat (
    in inputFloat float __soap_type 'http://www.w3.org/2001/XMLSchema:float')
returns float
__soap_type 'http://www.w3.org/2001/XMLSchema:float'
{
  --##This method accepts a single float and echoes it back to the client.
  --dbg_obj_print ('\nechoFloat', inputFloat, '\n');
  return inputFloat;
};

create procedure
INTEROP.echoFloatArray (
    in inputFloatArray any __soap_type 'http://soapinterop.org/xsd:ArrayOffloat')
__soap_type 'http://soapinterop.org/xsd:ArrayOffloat'
{
  --##This method accepts an array of floats and echoes it back to the client.
  --dbg_obj_print ('\nechoFloatArray', inputFloatArray, '\n');
  return inputFloatArray;
};


create procedure
INTEROP.echoStruct (
    in inputStruct any __soap_type 'http://soapinterop.org/xsd:SOAPStruct')
__soap_type 'http://soapinterop.org/xsd:SOAPStruct'
{
  --##This method accepts a single structure and echoes it back to the client.
  --dbg_obj_print ('\nechoStruct', inputStruct, '\n');
  return inputStruct;
};


create procedure
INTEROP.echoStructArray (
    in inputStructArray any __soap_type 'http://soapinterop.org/xsd:ArrayOfSOAPStruct')
__soap_type 'http://soapinterop.org/xsd:ArrayOfSOAPStruct'
{
  declare ses any;
  declare inx integer;
  --##This method accepts an array of  structures and echoes it back to the client.
  --dbg_obj_print ('\nechoStructArray', inputStructArray, '\n');
  return inputStructArray;
};


create procedure
INTEROP.echoBase64 (
    in inputBase64 varchar __soap_type 'http://www.w3.org/2001/XMLSchema:base64Binary')
__soap_type 'http://www.w3.org/2001/XMLSchema:base64Binary'
{
  --##This methods accepts a hex encoded object and echoes it back to the client.
  --dbg_obj_print ('\nechoBase64', inputBase64, '\n');
  return inputBase64;
};


create procedure
INTEROP.echoHexBinary (in inputHexBinary varchar
    __soap_type 'http://www.w3.org/2001/XMLSchema:hexBinary')
__soap_type 'http://www.w3.org/2001/XMLSchema:hexBinary'
{
  --##This methods accepts a binary object and echoes it back to the client.
  --dbg_obj_print ('\nechoHexBinary', inputHexBinary, '\n');
  return inputHexBinary;
};


create procedure
INTEROP.echoDate (in inputDate datetime) returns datetime
{
  --##This method accepts a Date/Time and echoes it back to the client.
  --dbg_obj_print ('\nechoDate', inputDate, '\n');
  return inputDate;
};

create procedure
INTEROP.echoDecimal (in inputDecimal numeric) returns numeric
{
  --##This method accepts a decimal and echoes it back to the client.
  --dbg_obj_print ('\nechoDecimal', inputDecimal, '\n');
  return inputDecimal;
};


create procedure
INTEROP.echoBoolean (
    in inputBoolean smallint __soap_type 'http://www.w3.org/2001/XMLSchema:boolean')
__soap_type 'http://www.w3.org/2001/XMLSchema:boolean'
{
  --##This method accepts a boolean and echoes it back to the client.
  --dbg_obj_print ('\nechoBoolean', inputBoolean, '\n');
  return soap_boolean (inputBoolean);
};

create procedure
INTEROP.echoDuration (
    in inputDuration varchar __soap_type 'http://www.w3.org/2001/XMLSchema:duration')
returns varchar
__soap_type 'http://www.w3.org/2001/XMLSchema:duration'
{
  --##This method accepts a duration and echoes it back to the client.
  --dbg_obj_print ('\nechoDuration', inputDuration, '\n');
  return inputDuration;
};


-- round 2 B
create procedure
INTEROP.echoStructAsSimpleTypes (
    in inputStruct any __soap_type 'http://soapinterop.org/xsd:SOAPStruct',
    out outputString varchar,
    out outputInteger integer,
    out outputFloat real __soap_type 'http://www.w3.org/2001/XMLSchema:float')
__soap_type '__VOID__'
{
  --##This method accepts a single struct and echoes it back to the client decomposed into three output parameters
  outputString := get_keyword ('varString',inputStruct);
  outputInteger := get_keyword ('varInt',inputStruct);
  outputFloat := get_keyword ('varFloat',inputStruct);
};

create procedure INTEROP.echoSimpleTypesAsStruct (
    in inputString varchar,in inputInteger integer,in inputFloat real)
   __soap_type 'http://soapinterop.org/xsd:SOAPStruct'
{
  --##This method accepts three input parameters and echoes them back to the client incorporated into a single struct.
  return soap_box_structure ('varString', inputString, 'varInt', inputInteger, 'varFloat', inputFloat);
};

create procedure INTEROP.echoNestedStruct (
    in inputStruct any __soap_type 'http://soapinterop.org/xsd:SOAPStructStruct')
__soap_type 'http://soapinterop.org/xsd:SOAPStructStruct'
{
  --##This method accepts a single struct with a nested struct type member and echoes it back to the client.
  return inputStruct;
};

create procedure INTEROP.echoNestedArray (in inputStruct any __soap_type 'http://soapinterop.org/xsd:SOAPArrayStruct')
__soap_type 'http://soapinterop.org/xsd:SOAPArrayStruct'
{
  --##This method accepts a single struct with a nested Array type member and echoes it back to the client.
  return inputStruct;
};

create procedure INTEROP.echo2DStringArray (in input2DStringArray any __soap_type 'http://soapinterop.org/xsd:ArrayOfString2D')
__soap_type 'http://soapinterop.org/xsd:ArrayOfString2D'
{
  --##This method accepts an single 2 dimensional array of xsd:string and echoes it back to the client.
  return input2DStringArray;
};

create procedure
INTEROP.echoVoid
   (
     in echoMeStringRequest nvarchar := NULL __soap_header 'http://www.w3.org/2001/XMLSchema:string',
     out echoMeStringResponse nvarchar := NULL __soap_header 'http://www.w3.org/2001/XMLSchema:string',
     in echoMeStructRequest any := NULL __soap_header 'http://soapinterop.org/xsd:SOAPStruct',
     out echoMeStructResponse any := NULL __soap_header 'http://soapinterop.org/xsd:SOAPStruct'
   )

   __soap_type '__VOID__'
{
  --dbg_obj_print ('\nechoVoid\n', echoMeStructRequest);
  --##This method exists to test the "void" return case.  It accepts no arguments, and returns no arguments.
  if (echoMeStructRequest is not null)
    echoMeStructResponse := echoMeStructRequest;
  else if (echoMeStringRequest is not null)
    echoMeStringResponse := echoMeStringRequest;
  return;
};


grant execute on Interop.INTEROP.echoString to INTEROP;
grant execute on Interop.INTEROP.echoStringArray to INTEROP;
grant execute on Interop.INTEROP.echoInteger to INTEROP;
grant execute on Interop.INTEROP.echoIntegerArray to INTEROP;
grant execute on Interop.INTEROP.echoFloat to INTEROP;
grant execute on Interop.INTEROP.echoFloatArray to INTEROP;
grant execute on Interop.INTEROP.echoStruct to INTEROP;
grant execute on Interop.INTEROP.echoStructArray to INTEROP;
grant execute on Interop.INTEROP.echoBase64 to INTEROP;
grant execute on Interop.INTEROP.echoHexBinary to INTEROP;
grant execute on Interop.INTEROP.echoDate to INTEROP;
grant execute on Interop.INTEROP.echoDecimal to INTEROP;
grant execute on Interop.INTEROP.echoBoolean to INTEROP;
grant execute on Interop.INTEROP.echoDuration to INTEROP;
grant execute on Interop.INTEROP.echoStructAsSimpleTypes to INTEROP;
grant execute on Interop.INTEROP.echoSimpleTypesAsStruct to INTEROP;
grant execute on Interop.INTEROP.echoNestedStruct to INTEROP;
grant execute on Interop.INTEROP.echoNestedArray to INTEROP;
grant execute on Interop.INTEROP.echo2DStringArray to INTEROP;
grant execute on Interop.INTEROP.echoVoid to INTEROP;


