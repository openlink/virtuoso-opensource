--  
--  $Id$
--  
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--  
--  Copyright (C) 1998-2013 OpenLink Software
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
create user "interop4hsd";

user_set_qualifier ('interop4hsd', 'interop4hsd');


VHOST_REMOVE (lpath=>'/r4/groupH/simple/doc')
;

VHOST_DEFINE (lpath=>'/r4/groupH/simple/doc', ppath=>'/SOAP/', soap_user=>'interop4hsd',
    soap_opts => vector (
      'Namespace','http://soapinterop.org/wsdl','MethodInSoapAction','empty',
      'ServiceName', 'GroupHService', 'FaultNS', 'http://soapinterop.org/wsdl'
      )
    )
;

-- methods

use interop4hsd;

create procedure
"echoEmptyFault" (in param any __soap_type 'http://soapinterop.org/types/requestresponse:echoEmptyFaultRequest',
    out part1 any __soap_fault 'http://soapinterop.org/types/part:EmptyPart')
    __soap_doc 'http://soapinterop.org/types/requestresponse:echoEmptyFaultResponse'
{
  dbg_obj_print ('echoEmptyFault');
  declare exit handler for sqlstate 'SF000'
    {
      http_request_status ('HTTP/1.1 500 Internal Server Error');
      part1 := 0;
      connection_set ('SOAPFault', vector ('400', 'EmptyFault'));
      return;
    };
  signal ('SF000', 'echoEmptyFault');
  return;
};

create procedure
"echoStringFault" (
    in param varchar __soap_type 'http://soapinterop.org/types/requestresponse:echoStringFaultRequest',
    out part2 varchar __soap_fault 'http://soapinterop.org/types/part:StringPart')
__soap_doc 'http://soapinterop.org/types/requestresponse:echoStringFaultResponse'
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
"echoIntArrayFault" (
    in param any __soap_type 'http://soapinterop.org/types/requestresponse:echoIntArrayFaultRequest',
    out part5 any __soap_fault 'http://soapinterop.org/types/part:ArrayOfIntPart')
__soap_doc 'http://soapinterop.org/types/requestresponse:echoIntArrayFaultResponse'
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
    in param any __soap_type 'http://soapinterop.org/types/requestresponse:echoMultipleFaults1Request',
    out part1 any __soap_fault 'http://soapinterop.org/types/part:EmptyPart',
    out part2 varchar __soap_fault 'http://soapinterop.org/types/part:StringPart',
    out part7 any __soap_fault 'http://soapinterop.org/types/part:ArrayOfFloatPart'
    )
__soap_doc 'http://soapinterop.org/types/requestresponse:echoMultipleFaults1Response'
{
  declare whichFault int;
  declare param1, param2 any;

  dbg_obj_print ('echoMultipleFaults1', param);
  whichFault := get_keyword ('whichFault', param, 1);
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
	  part2 := get_keyword ('param1', param);
	}
      else if (whichFault = 3)
	{
	  part7 := get_keyword ('param2', param);
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
    in param any __soap_type 'http://soapinterop.org/types/requestresponse:echoMultipleFaults2Request',
    out part2 varchar __soap_fault 'http://soapinterop.org/types/part:StringPart',
    out part4 varchar __soap_fault 'http://soapinterop.org/types/part:FloatPart',
    out part6 any __soap_fault 'http://soapinterop.org/types/part:ArrayOfStringPart'
    )
__soap_doc 'http://soapinterop.org/types/requestresponse:echoMultipleFaults2Response'
{
  declare whichFault, param1, param2, param3 any;

  whichFault := get_keyword ('whichFault', param, 1);
  dbg_obj_print ('echoMultipleFaults2');
  declare exit handler for sqlstate 'SF000'
    {
      http_request_status ('HTTP/1.1 500 Internal Server Error');
      if (whichFault = 2)
	{
          part2 := get_keyword ('param1', param);
	}
      else if (whichFault = 3)
	{
	  part6 := get_keyword ('param3', param);
	}
      else
	{
	  part4 := get_keyword ('param2', param);
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
    in param any __soap_type 'http://soapinterop.org/types/requestresponse:echoMultipleFaults3Request',
    out part2_1 varchar __soap_fault 'http://soapinterop.org/types/part:StringPart',
    out part2_2 varchar __soap_fault 'http://soapinterop.org/types/part:String2Part'
    )
__soap_doc 'http://soapinterop.org/types/requestresponse:echoMultipleFaults3Response'
{

  declare whichFault, param1, param2, param3 any;

  whichFault := get_keyword ('whichFault', param, 1);
  dbg_obj_print ('echoMultipleFaults3');
  if (whichFault > 2)
    whichFault := mod (whichFault, 3) + 1;
  declare exit handler for sqlstate 'SF000'
    {
      http_request_status ('HTTP/1.1 500 Internal Server Error');
      if (whichFault = 1)
	{
          part2_1 := get_keyword ('param1', param);
	}
      else if (whichFault = 2)
	{
	  part2_2 := get_keyword ('param2', param);
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
    in param any __soap_type 'http://soapinterop.org/types/requestresponse:echoMultipleFaults4Request',
    out part3 varchar __soap_fault 'http://soapinterop.org/types/part:IntPart',
    out part9 varchar __soap_fault 'http://soapinterop.org/types/part:EnumPart'
    )
__soap_doc 'http://soapinterop.org/types/requestresponse:echoMultipleFaults4Response'
{

  declare whichFault, param1, param2, param3 any;

  whichFault := get_keyword ('whichFault', param, 1);
  dbg_obj_print ('echoMultipleFaults4');
  if (whichFault > 2)
    whichFault := mod (whichFault, 3) + 1;
  declare exit handler for sqlstate 'SF000'
    {
      http_request_status ('HTTP/1.1 500 Internal Server Error');
      if (whichFault = 1)
	{
          part3 := get_keyword ('param1', param);
	}
      else if (whichFault = 2)
	{
	  part9 := get_keyword ('param2', param);
	}

      connection_set ('SOAPFault', vector ('400', 'echoMultipleFaults4'));
      return;
    };
  signal ('SF000', 'echoEmptyFault');
  return;
}
;

-- grants

grant execute on "echoEmptyFault" to "interop4hsd";
grant execute on "echoStringFault" to "interop4hsd";
grant execute on "echoIntArrayFault" to "interop4hsd";
grant execute on "echoMultipleFaults1" to "interop4hsd";
grant execute on "echoMultipleFaults2" to "interop4hsd";
grant execute on "echoMultipleFaults3" to "interop4hsd";
grant execute on "echoMultipleFaults4" to "interop4hsd";

-- back
use DB;
