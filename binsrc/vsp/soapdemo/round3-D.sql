--  
--  $Id$
--  
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--  
--  Copyright (C) 1998-2019 OpenLink Software
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

DB.DBA.USER_CREATE ('EmptySA', uuid(), vector ('DISABLED', 1));
DB.DBA.USER_CREATE ('Import1', uuid(), vector ('DISABLED', 1));
DB.DBA.USER_CREATE ('Import2', uuid(), vector ('DISABLED', 1));
DB.DBA.USER_CREATE ('Import3', uuid(), vector ('DISABLED', 1));
DB.DBA.USER_CREATE ('Compound1', uuid(), vector ('DISABLED', 1));
DB.DBA.USER_CREATE ('Compound2', uuid(), vector ('DISABLED', 1));
DB.DBA.USER_CREATE ('DocLit', uuid(), vector ('DISABLED', 1));
DB.DBA.USER_CREATE ('DocPars', uuid(), vector ('DISABLED', 1));
DB.DBA.USER_CREATE ('RpcEnc', uuid(), vector ('DISABLED', 1));

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
      returns any __soap_doc 'http://soapinterop.org/xsd:result_Person'
{
  --dbg_obj_print ('Compund1.echoPerson', x);
  return x;
};

create procedure
Compund1.echoDocument (in x any __soap_type 'http://soapinterop.org/xsd:x_Document')
returns any __soap_doc 'http://soapinterop.org/xsd:result_Document'
{
  --dbg_obj_print ('echoDocument', x);
  return x;
};

-- Compund2
create procedure
Compund2.echoEmployee (in x any __soap_type 'http://soapinterop.org/employee:x_Employee')
      returns any __soap_doc 'http://soapinterop.org/employee:result_Employee'
{
  --dbg_obj_print ('echoEmployee: ', x);
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
      --dbg_obj_print (echoStringArrayParam);
      return echoStringArrayParam;
};

create procedure
DocLit.echoVoid () __soap_doc '__VOID__'
{
  --dbg_obj_print ('DocLit.echoVoid');
  return;
};


-- Doc/Literal Parameters
create procedure
DocPars.echoString (in echoString varchar __soap_type 'http://soapinterop.org/xsd:echoString')
      returns any __soap_docw 'http://soapinterop.org/xsd:echoStringResponse'
{
      --dbg_obj_print ('DocPars.echoString: ', echoString);
      return echoString;
};

create procedure
DocPars.echoStruct (in echoStruct varchar __soap_type 'http://soapinterop.org/xsd:echoStruct')
      returns any __soap_docw 'http://soapinterop.org/xsd:echoStructResponse'
{
      --dbg_obj_print (echoStruct);
      return echoStruct;
};

create procedure
DocPars.echoStringArray (in echoStringArray varchar __soap_type 'http://soapinterop.org/xsd:echoStringArray')
      returns any __soap_docw 'http://soapinterop.org/xsd:echoStringArrayResponse'
{
      --dbg_obj_print (echoStringArray);
      return echoStringArray;
};

create procedure
DocPars.echoVoid (in echoVoid varchar __soap_type 'http://soapinterop.org/xsd:echoVoid') __soap_docw 'http://soapinterop.org/xsd:echoVoidResponse'
{
  --dbg_obj_print ('DocPars.echoVoid');
  return;
};

-- RPC encoded
create procedure
RpcEnc.echoString (in param0 nvarchar __soap_type 'http://www.w3.org/2001/XMLSchema:string')
returns nvarchar __soap_type 'http://www.w3.org/2001/XMLSchema:string'
{
  --dbg_obj_print ('\nechoString', param0, '\n');
  return param0;
};


create procedure
RpcEnc.echoStringArray (
    in param0 any __soap_type 'http://soapinterop.org/xsd:ArrayOfstring')
__soap_type 'http://soapinterop.org/xsd:ArrayOfstring'
{
  --dbg_obj_print ('\nechoStringArray', param0, '\n');
  return param0;
};

create procedure
RpcEnc.echoStruct (
    in param0 any __soap_type 'http://soapinterop.org/xsd:SOAPStruct')
__soap_type 'http://soapinterop.org/xsd:SOAPStruct'
{
  --dbg_obj_print ('\nechoStruct', param0, '\n');
  return param0;
};

create procedure
RpcEnc.echoVoid () __soap_type '__VOID__'
{
  --dbg_obj_print ('RpcEnc.echoVoid');
  return;
};


-- Grants
grant execute on EmptySA.echoString to EmptySA;

grant execute on Import1.echoString to Import1;

grant execute on Import2.echoStruct to Import2;

grant execute on Import3.echoStructArray to Import3;
grant execute on Import3.echoStruct to Import3;

grant execute on Compund1.echoPerson to Compound1;
grant execute on Compund1.echoDocument to Compound1;

grant execute on Compund2.echoEmployee to Compound2;

grant execute on DocLit.echoString to DocLit;
grant execute on DocLit.echoStruct to DocLit;
grant execute on DocLit.echoStringArray to DocLit;
grant execute on DocLit.echoVoid to DocLit;

grant execute on DocPars.echoString to DocPars;
grant execute on DocPars.echoStruct  to DocPars;
grant execute on DocPars.echoStringArray  to DocPars;
grant execute on DocPars.echoVoid  to DocPars;

grant execute on RpcEnc.echoString  to RpcEnc;
grant execute on RpcEnc.echoStringArray to RpcEnc;
grant execute on RpcEnc.echoStruct  to RpcEnc;
grant execute on RpcEnc.echoVoid  to RpcEnc;

use DB;

DB.DBA.vhost_remove (lpath=>'/r3/EmptySA');

DB.DBA.VHOST_DEFINE (
    lpath=>'/r3/EmptySA',
    ppath=>'/SOAP/',
    soap_user=>'EmptySA',
    soap_opts=>vector(
      'Namespace','http://soapinterop/',
      'MethodInSoapAction','empty',
      'ServiceName', 'EmptySA',
      'CR-escape', 'yes')
    );

DB.DBA.vhost_remove (lpath=>'/r3/Import1');

DB.DBA.VHOST_DEFINE (
    lpath=>'/r3/Import1',
    ppath=>'/SOAP/',
    soap_user=>'Import1',
    soap_opts=>vector(
      'Namespace','http://soapinterop.org/',
      'MethodInSoapAction','no',
      'ServiceName', 'Import1',
      'CR-escape', 'yes')
    );

DB.DBA.vhost_remove (lpath=>'/r3/Import2');

DB.DBA.VHOST_DEFINE (
    lpath=>'/r3/Import2',
    ppath=>'/SOAP/',
    soap_user=>'Import2',
    soap_opts=>vector(
      'Namespace','http://soapinterop.org/',
      'MethodInSoapAction','no',
      'ServiceName', 'Import2',
      'CR-escape', 'yes')
    );

DB.DBA.vhost_remove (lpath=>'/r3/Import3');

DB.DBA.VHOST_DEFINE (
    lpath=>'/r3/Import3',
    ppath=>'/SOAP/',
    soap_user=>'Import3',
    soap_opts=>vector(
      'Namespace','http://soapinterop.org/',
      'MethodInSoapAction','no',
      'ServiceName', 'Import3',
      'CR-escape', 'yes')
    );

DB.DBA.vhost_remove (lpath=>'/r3/Compound1');

DB.DBA.VHOST_DEFINE (
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

DB.DBA.vhost_remove (lpath=>'/r3/Compound2');

DB.DBA.VHOST_DEFINE (
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

DB.DBA.vhost_remove (lpath=>'/r3/DocLit');

DB.DBA.VHOST_DEFINE (
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

DB.DBA.vhost_remove (lpath=>'/r3/DocPars');

DB.DBA.VHOST_DEFINE (
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

DB.DBA.vhost_remove (lpath=>'/r3/RpcEnc');

DB.DBA.VHOST_DEFINE (
    lpath=>'/r3/RpcEnc',
    ppath=>'/SOAP/',
    soap_user=>'RpcEnc',
    soap_opts=>vector(
      'Namespace','http://soapinterop.org/',
      'MethodInSoapAction','empty',
      'ServiceName', 'WSDLInteropTestRpcEnc',
      'CR-escape', 'yes')
    );

