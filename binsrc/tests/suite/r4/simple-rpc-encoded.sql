--  
--  $Id: simple-rpc-encoded.sql,v 1.3.10.1 2013/01/02 16:15:47 source Exp $
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
create user "interop4h";

user_set_qualifier ('interop4h', 'interop4h');


VHOST_REMOVE (lpath=>'/r4/groupH/simple/rpc')
;

VHOST_DEFINE (lpath=>'/r4/groupH/simple/rpc', ppath=>'/SOAP/', soap_user=>'interop4h',
    soap_opts => vector (
      'Namespace','http://soapinterop.org/wsdl','MethodInSoapAction','empty',
      'ServiceName', 'GroupHService', 'FaultNS', 'http://soapinterop.org/wsdl'
      )
    )
;

-- methods

use interop4h;

create procedure
"echoEmptyFault" (out part1 any __soap_fault 'http://soapinterop.org/types:EmptyFault')
__soap_type '__VOID__'
{
  dbg_obj_print ('echoEmptyFault');
  declare exit handler for sqlstate 'SF000'
    {
      part1 := 0;
      http_request_status ('HTTP/1.1 500 Internal Server Error');
      connection_set ('SOAPFault', vector ('400', 'EmptyFault'));
      return;
    };
  signal ('SF000', 'echoEmptyFault');
  return;
};

create procedure
"echoStringFault" (in param varchar __soap_type 'http://www.w3.org/2001/XMLSchema:string',
                 out part2 varchar __soap_fault 'http://www.w3.org/2001/XMLSchema:string')
__soap_type '__VOID__'
{
  dbg_obj_print ('echoStringFault');
  declare exit handler for sqlstate 'SF000'
    {
      http_request_status ('HTTP/1.1 500 Internal Server Error');
      part2 := param;
      connection_set ('SOAPFault', vector ('400', 'StringFault'));
      return;
    };
  signal ('SF000', 'echoEmptyFault');
  return;
}
;

create procedure
"echoIntArrayFault" (in param any __soap_type 'http://soapinterop.org/types:ArrayOfInt',
    out part5 any __soap_fault 'http://soapinterop.org/types:ArrayOfInt')
__soap_type '__VOID__'
{
  dbg_obj_print ('echoIntArrayFault');
  declare exit handler for sqlstate 'SF000'
    {
      http_request_status ('HTTP/1.1 500 Internal Server Error');
      part5 := param;
      connection_set ('SOAPFault', vector ('400', 'echoIntArrayFault'));
      return;
    };
  signal ('SF000', 'echoIntArrayFault');
  return;
}
;

-- XXX: how about whichFault > 3 ?
create procedure
"echoMultipleFaults1" (
    in whichFault int __soap_type 'http://www.w3.org/2001/XMLSchema:int',
    in param1 varchar __soap_type 'http://www.w3.org/2001/XMLSchema:string',
    in param2 any __soap_type 'http://soapinterop.org/types:ArrayOfFloat',
    out part1 any __soap_fault 'http://soapinterop.org/types:EmptyFault',
    out part2 varchar __soap_fault 'http://www.w3.org/2001/XMLSchema:string',
    out part7 any __soap_fault 'http://soapinterop.org/types:ArrayOfFloat'
    )
__soap_type '__VOID__'
{

  dbg_obj_print ('echoMultipleFaults1');
  if (whichFault > 3)
    whichFault := mod (whichFault, 4) + 1;
  declare exit handler for sqlstate 'SF000'
    {
      http_request_status ('HTTP/1.1 500 Internal Server Error');
      if (whichFault = 1)
	{
          part1 := 0;
	}
      else if (whichFault = 2)
	{
	  part2 := param1;
	}
      else if (whichFault = 3)
	{
	  part7 := param2;
	}

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
    in param1 varchar __soap_type 'http://www.w3.org/2001/XMLSchema:string',
    in param2 any __soap_type 'http://www.w3.org/2001/XMLSchema:float',
    in param3 any __soap_type 'http://soapinterop.org/types:ArrayOfString',
    out part2 varchar __soap_fault 'http://www.w3.org/2001/XMLSchema:string',
    out part4 varchar __soap_fault 'http://www.w3.org/2001/XMLSchema:float',
    out part6 any __soap_fault 'http://soapinterop.org/types:ArrayOfString'
    )
__soap_type '__VOID__'
{

  dbg_obj_print ('echoMultipleFaults2');
  declare exit handler for sqlstate 'SF000'
    {
      http_request_status ('HTTP/1.1 500 Internal Server Error');
      if (whichFault = 2)
	{
          part2 := param1;
	}
      else if (whichFault = 3)
	{
	  part6 := param3;
	}
      else
	{
	  part4 := param2;
	}

      connection_set ('SOAPFault', vector ('400', 'echoMultipleFaults2'));
      return;
    };
  signal ('SF000', 'echoEmptyFault');
  return;
}
;


create procedure
"echoMultipleFaults3" (
    in whichFault int __soap_type 'http://www.w3.org/2001/XMLSchema:int',
    in param1 varchar __soap_type 'http://www.w3.org/2001/XMLSchema:string',
    in param2 varchar __soap_type 'http://www.w3.org/2001/XMLSchema:string',
    out part2_1 varchar __soap_options (
        __soap_fault:='http://www.w3.org/2001/XMLSchema:string',
	PartName:='part2',
        ResponseNamespace:='http://soapinterop.org/wsdl/fault1'),
    out part2_2 varchar __soap_options (
        __soap_fault:='http://www.w3.org/2001/XMLSchema:string',
	PartName:='part2',
        ResponseNamespace:='http://soapinterop.org/wsdl/fault2')
    )
__soap_type '__VOID__'
{

  dbg_obj_print ('echoMultipleFaults3');
  if (whichFault > 2)
    whichFault := mod (whichFault, 3) + 1;
  declare exit handler for sqlstate 'SF000'
    {
      http_request_status ('HTTP/1.1 500 Internal Server Error');
      if (whichFault = 1)
	{
          part2_1 := param1;
	}
      else if (whichFault = 2)
	{
	  part2_2 := param2;
	}

      connection_set ('SOAPFault', vector ('400', 'echoMultipleFaults3'));
      return;
    };
  signal ('SF000', 'echoEmptyFault');
  return;
}
;


create procedure
"echoMultipleFaults4" (
    in whichFault int __soap_type 'http://www.w3.org/2001/XMLSchema:int',
    in param1 int __soap_type 'http://www.w3.org/2001/XMLSchema:int',
    in param2 varchar __soap_type 'http://soapinterop.org/types:Enum',
    out part3 varchar __soap_fault 'http://www.w3.org/2001/XMLSchema:int',
    out part9 varchar __soap_fault 'http://soapinterop.org/types:Enum'
    )
__soap_type '__VOID__'
{

  dbg_obj_print ('echoMultipleFaults4');
  if (whichFault > 2)
    whichFault := mod (whichFault, 3) + 1;
  declare exit handler for sqlstate 'SF000'
    {
      http_request_status ('HTTP/1.1 500 Internal Server Error');
      if (whichFault = 1)
	{
          part3 := param1;
	}
      else if (whichFault = 2)
	{
	  part9 := param2;
	}

      connection_set ('SOAPFault', vector ('400', 'echoMultipleFaults4'));
      return;
    };
  signal ('SF000', 'echoEmptyFault');
  return;
}
;

-- grants

grant execute on "echoEmptyFault" to "interop4h";
grant execute on "echoStringFault" to "interop4h";
grant execute on "echoIntArrayFault" to "interop4h";
grant execute on "echoMultipleFaults1" to "interop4h";
grant execute on "echoMultipleFaults2" to "interop4h";
grant execute on "echoMultipleFaults3" to "interop4h";
grant execute on "echoMultipleFaults4" to "interop4h";

-- back
use DB;
