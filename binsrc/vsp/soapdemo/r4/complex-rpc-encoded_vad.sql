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
-- schema definition
DB.DBA.exec_no_error('drop type DB.DBA."SOAPStruct"');
DB.DBA.exec_no_error('drop type DB.DBA."SOAPStructFault"');
DB.DBA.exec_no_error('drop type DB.DBA."BaseStruct"');
DB.DBA.exec_no_error('drop type DB.DBA."ExtendedStruct"');
DB.DBA.exec_no_error('drop type DB.DBA."MoreExtendedStruct"');

create type DB.DBA."SOAPStruct" as (
    "varString" nvarchar __soap_type 'string',
    "varInt" int __soap_type 'int',
    "varFloat" real __soap_type 'float');

DB.DBA.exec_no_error('create type DB.DBA."SOAPStructFault" as ("soapStruct" DB.DBA."SOAPStruct")');

DB.DBA.exec_no_error('create type DB.DBA."BaseStruct" as ("floatMessage" real, "shortMessage" int __soap_type \'short\')');

DB.DBA.exec_no_error('create type DB.DBA."ExtendedStruct" under DB.DBA."BaseStruct" as (
    "stringMessage" nvarchar __soap_type \'string\',
    "intMessage" int __soap_type \'int\',
    "anotherIntMessage" int __soap_type \'int\'
    )');

DB.DBA.exec_no_error('create type DB.DBA."MoreExtendedStruct" under DB.DBA."ExtendedStruct" as ("booleanMessage" smallint __soap_type \'boolean\')');

-- virtual directory setup
USER_CREATE ('interop4hcr', uuid(), vector ('DISABLED', 1));
user_set_qualifier ('interop4hcr', 'interop4hcr');


VHOST_REMOVE (lpath=>'/r4/groupH/complex/rpc')
;

VHOST_DEFINE (lpath=>'/r4/groupH/complex/rpc', ppath=>'/SOAP/', soap_user=>'interop4hcr',
    soap_opts => vector (
      'Namespace','http://soapinterop.org/wsdl','MethodInSoapAction','empty',
      'ServiceName', 'GroupHService', 'FaultNS', 'http://soapinterop.org/wsdl'
      )
    )
;

use interop4hcr;

-- methods
create procedure
"echoBaseStructFault" (
    in param DB.DBA."BaseStruct" __soap_type 'http://soapinterop.org/types:BaseStruct',
    out part2 DB.DBA."BaseStruct" __soap_fault 'http://soapinterop.org/types:BaseStruct')
    __soap_type '__VOID__'
{
  --dbg_obj_print ('echoBaseStructFault', param);
  declare exit handler for sqlstate 'SF000'
    {
      part2 := param;
      http_request_status ('HTTP/1.1 500 Internal Server Error');
      connection_set ('SOAPFault', vector ('400', 'BaseStructFault'));
      return;
    };
  signal ('SF000', 'echoEmptyFault');
  return;
}
;

create procedure
"echoSOAPStructFault" (in param DB.DBA."SOAPStructFault" __soap_type 'http://soapinterop.org/types:SOAPStructFault',
    out part1 DB.DBA."SOAPStructFault" __soap_fault 'http://soapinterop.org/types:SOAPStructFault')
__soap_type '__VOID__'
{
  --dbg_obj_print (param);
  declare exit handler for sqlstate 'SF000'
    {
      part1 := param;
      http_request_status ('HTTP/1.1 500 Internal Server Error');
      connection_set ('SOAPFault', vector ('400', 'SOAPStructFault'));
      return;
    };
  signal ('SF000', 'echoEmptyFault');
}
;

create procedure
"echoExtendedStructFault" (
    in param DB.DBA."ExtendedStruct" __soap_type 'http://soapinterop.org/types:ExtendedStruct',
    out part3 DB.DBA."ExtendedStruct" __soap_fault 'http://soapinterop.org/types:ExtendedStruct'
    )
__soap_type '__VOID__'
{
  --dbg_obj_print (param);
  declare exit handler for sqlstate 'SF000'
    {
      part3 := param;
      http_request_status ('HTTP/1.1 500 Internal Server Error');
      connection_set ('SOAPFault', vector ('400', 'ExtendedStructFault'));
      return;
    };
  signal ('SF000', '...');
}
;

create procedure
"echoMultipleFaults1" (
    in whichFault int __soap_type 'http://www.w3.org/2001/XMLSchema:int',
    in param1 DB.DBA."SOAPStruct" __soap_type 'http://soapinterop.org/types:SOAPStruct',
    in param2 DB.DBA."BaseStruct" __soap_type 'http://soapinterop.org/types:BaseStruct',
    out part1 DB.DBA."SOAPStructFault" __soap_fault 'http://soapinterop.org/types:SOAPStructFault',
    out part2 DB.DBA."BaseStruct" __soap_fault 'http://soapinterop.org/types:BaseStruct'
    )
__soap_type '__VOID__'
{
  --dbg_obj_print ('echoMultipleFaults1', param1, param2);
  declare exit handler for sqlstate 'SF000'
    {
      if (whichFault = 2)
        part2 := param2;
      else
        {
          part1 := new DB.DBA."SOAPStructFault"();
          part1.soapStruct := param1;
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
    in whichFault int __soap_type 'http://www.w3.org/2001/XMLSchema:int',
    in param1 DB.DBA."BaseStruct" __soap_type 'http://soapinterop.org/types:BaseStruct',
    in param2 DB.DBA."ExtendedStruct" __soap_type 'http://soapinterop.org/types:ExtendedStruct',
    in param3 DB.DBA."MoreExtendedStruct" __soap_type 'http://soapinterop.org/types:MoreExtendedStruct',
    out part2 DB.DBA."BaseStruct" __soap_fault 'http://soapinterop.org/types:BaseStruct',
    out part3 DB.DBA."ExtendedStruct" __soap_fault 'http://soapinterop.org/types:ExtendedStruct',
    out part4 DB.DBA."MoreExtendedStruct" __soap_fault 'http://soapinterop.org/types:MoreExtendedStruct'
    )
__soap_type '__VOID__'
{
  --dbg_obj_print ('echoMultipleFaults2', param1, param2, param3);
  declare exit handler for sqlstate 'SF000'
    {
      if (whichFault = 2)
        part3 := param2;
      else if (whichFault = 3)
        part4 := param3;
      else
        part2 := param1;
      http_request_status ('HTTP/1.1 500 Internal Server Error');
      connection_set ('SOAPFault', vector ('400', 'echoMultipleFaults2'));
      return;
    };
  signal ('SF000', 'echoEmptyFault');
  return;
}
;

-- grants
grant execute on "echoBaseStructFault" to "interop4hcr";
grant execute on "echoSOAPStructFault" to "interop4hcr";
grant execute on "echoExtendedStructFault" to "interop4hcr";
grant execute on "echoMultipleFaults1" to "interop4hcr";
grant execute on "echoMultipleFaults2" to "interop4hcr";

grant execute on DB.DBA."SOAPStruct" to "interop4hcr";
grant execute on DB.DBA."SOAPStructFault" to "interop4hcr";
grant execute on DB.DBA."BaseStruct" to "interop4hcr";
grant execute on DB.DBA."ExtendedStruct" to "interop4hcr";
grant execute on DB.DBA."MoreExtendedStruct" to "interop4hcr";

use DB;
