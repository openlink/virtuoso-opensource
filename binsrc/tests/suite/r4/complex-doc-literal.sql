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
-- schema definition
--drop type DB.DBA."SOAPStruct";
--drop type DB.DBA."SOAPStructFault";
drop type DB.DBA."BaseStruct_literal";
drop type DB.DBA."ExtendedStruct_literal";
drop type DB.DBA."MoreExtendedStruct_literal";
drop type DB.DBA."echoMultipleFaults1Request";
drop type DB.DBA."echoMultipleFaults2Request";


create type DB.DBA."BaseStruct_literal" as (
    "structMessage" DB.DBA."SOAPStruct" __soap_type 'http://soapinterop.org/types:SOAPStruct',
    "shortMessage" int __soap_type 'short');
grant execute on DB.DBA."BaseStruct_literal" to public;

create type DB.DBA."ExtendedStruct_literal" under DB.DBA."BaseStruct_literal" as (
    "stringMessage" nvarchar __soap_type 'string',
    "intMessage" int __soap_type 'int',
    "anotherIntMessage" int __soap_type 'int'
    );
grant execute on DB.DBA."ExtendedStruct_literal" to public;

create type DB.DBA."MoreExtendedStruct_literal" under DB.DBA."ExtendedStruct_literal" as ("booleanMessage" smallint __soap_type 'boolean');
grant execute on DB.DBA."MoreExtendedStruct_literal" to public;

create type DB.DBA."echoMultipleFaults1Request" as (
    "whichFault" int,
    "param1" DB.DBA."SOAPStruct",
    "param2" DB.DBA."BaseStruct_literal");

create type DB.DBA."echoMultipleFaults2Request" as (
    "whichFault" int,
    "param1" DB.DBA."BaseStruct_literal",
    "param2" DB.DBA."ExtendedStruct_literal",
    "param3" DB.DBA."MoreExtendedStruct_literal"
    );

-- virtual directory setup
create user "interop4hcd";
user_set_qualifier ('interop4hcd', 'interop4hcd');


VHOST_REMOVE (lpath=>'/r4/groupH/complex/doc')
;

VHOST_DEFINE (lpath=>'/r4/groupH/complex/doc', ppath=>'/SOAP/', soap_user=>'interop4hcd',
    soap_opts => vector (
      'Namespace','http://soapinterop.org/wsdl','MethodInSoapAction','empty',
      'ServiceName', 'GroupHService', 'FaultNS', 'http://soapinterop.org/wsdl'
      )
    )
;

use interop4hcd;

-- methods
create procedure
"echoSOAPStructFault" (
    in param DB.DBA."SOAPStruct" __soap_type 'http://soapinterop.org/types/requestresponse:echoSOAPStructFaultRequest',
    out part3 DB.DBA."SOAPStructFault" __soap_fault 'http://soapinterop.org/types/part:SOAPStructFaultPart')
__soap_doc 'http://soapinterop.org/types/requestresponse:echoSOAPStructFaultResponse'
{
  dbg_obj_print (param);
  declare exit handler for sqlstate 'SF000'
    {
      part3 := new DB.DBA."SOAPStructFault" ();
      part3.soapStruct := param;
      http_request_status ('HTTP/1.1 500 Internal Server Error');
      connection_set ('SOAPFault', vector ('400', 'SOAPStructFault'));
      return;
    };
  signal ('SF000', '...');
}
;

create procedure
"echoBaseStructFault" (
    in param DB.DBA."BaseStruct_literal"
       __soap_type 'http://soapinterop.org/types/requestresponse:echoBaseStructFaultRequest',
    out part1 DB.DBA."BaseStruct_literal"
       __soap_fault 'http://soapinterop.org/types/part:BaseStructPart')
__soap_doc 'http://soapinterop.org/types/requestresponse:echoBaseStructFaultResponse'
{
  dbg_obj_print ('echoBaseStructFault', param);
  declare exit handler for sqlstate 'SF000'
    {
      part1 := param;
      http_request_status ('HTTP/1.1 500 Internal Server Error');
      connection_set ('SOAPFault', vector ('400', 'BaseStructFault'));
      return;
    };
  signal ('SF000', '...');
  return;
}
;

create procedure
"echoExtendedStructFault" (
    in param DB.DBA."ExtendedStruct_literal"
    __soap_type 'http://soapinterop.org/types/requestresponse:echoExtendedStructFaultRequest',
    out part2 DB.DBA."ExtendedStruct_literal"
    __soap_fault 'http://soapinterop.org/types/part:ExtendedStructPart'
    )
__soap_doc 'http://soapinterop.org/types/requestresponse:echoExtendedStructFaultResponse'
{
  dbg_obj_print (param);
  declare exit handler for sqlstate 'SF000'
    {
      part2 := param;
      http_request_status ('HTTP/1.1 500 Internal Server Error');
      connection_set ('SOAPFault', vector ('400', 'ExtendedStructFault'));
      return;
    };
  signal ('SF000', '...');
}
;

create procedure
"echoMultipleFaults1" (
    in param DB.DBA."echoMultipleFaults1Request"
    __soap_type 'http://soapinterop.org/types/requestresponse:echoMultipleFaults1Request_complex',
    out part3 DB.DBA."SOAPStructFault"
    __soap_fault 'http://soapinterop.org/types/part:SOAPStructFaultPart',
    out part1 DB.DBA."BaseStruct_literal"
    __soap_fault 'http://soapinterop.org/types/part:BaseStructPart'
    )
__soap_doc 'http://soapinterop.org/types/requestresponse:echoMultipleFaults1Response'
{
  dbg_obj_print ('echoMultipleFaults1', param);
  declare exit handler for sqlstate 'SF000'
    {
      if (param.whichFault = 2)
        part1 := param.param2;
      else
	{
          part3 := new DB.DBA."SOAPStructFault"();
          part3.soapStruct := param.param1;
	}
      http_request_status ('HTTP/1.1 500 Internal Server Error');
      connection_set ('SOAPFault', vector ('400', 'echoMultipleFaults1'));
      return;
    };
  signal ('SF000', 'echoEmptyFault');
  return;
}
;

create procedure
"echoMultipleFaults2" (
    in param DB.DBA."echoMultipleFaults2Request"
    __soap_type 'http://soapinterop.org/types/requestresponse:echoMultipleFaults2Request_complex',
    out part1 DB.DBA."BaseStruct_literal" __soap_fault 'http://soapinterop.org/types/part:BaseStructPart',
    out part2 DB.DBA."ExtendedStruct_literal" __soap_fault 'http://soapinterop.org/types/part:ExtendedStructPart',
    out part5 DB.DBA."MoreExtendedStruct_literal" __soap_fault 'http://soapinterop.org/types/part:MoreExtendedStructPart'
    )
__soap_doc 'http://soapinterop.org/types/requestresponse:echoMultipleFaults2Response'
{
  dbg_obj_print ('echoMultipleFaults2', param);
  declare exit handler for sqlstate 'SF000'
    {
      if (param.whichFault = 2)
        part2 := param.param2;
      else if (param.whichFault = 3)
	part5 := param.param3;
      else
	part1 := param.param1;
      http_request_status ('HTTP/1.1 500 Internal Server Error');
      connection_set ('SOAPFault', vector ('400', 'echoMultipleFaults2'));
      return;
    };
  signal ('SF000', 'echoEmptyFault');
  return;
}
;

-- grants
grant execute on "echoBaseStructFault" to "interop4hcd";
grant execute on "echoSOAPStructFault" to "interop4hcd";
grant execute on "echoExtendedStructFault" to "interop4hcd";
grant execute on "echoMultipleFaults1" to "interop4hcd";
grant execute on "echoMultipleFaults2" to "interop4hcd";

use DB;
