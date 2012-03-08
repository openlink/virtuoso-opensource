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
use DB;

drop user WSRP;

drop user soap12doc;

drop user soap12rpc;

DB.DBA.USER_CREATE ('WSRP', uuid(), vector ('DISABLED', 1));
DB.DBA.USER_CREATE ('soap12doc', uuid(), vector ('DISABLED', 1));
DB.DBA.USER_CREATE ('soap12rpc', uuid(), vector ('DISABLED', 1));

DB.DBA.VHOST_REMOVE (lpath=>'/router');

DB.DBA.VHOST_DEFINE (lpath=>'/router', ppath=>'/SOAP/', soap_user=>'WSRP', soap_opts=>vector ('router', 'yes', 'role', 'http://example.org/ts-tests/B'));

DB.DBA.VHOST_REMOVE (lpath=>'/soap12');

DB.DBA.VHOST_REMOVE (lpath=>'/soap12-doc');
DB.DBA.VHOST_REMOVE (lpath=>'/soap12-rpc');

DB.DBA.VHOST_DEFINE (lpath=>'/soap12', ppath=>'/SOAP/', soap_user=>'INTEROP', soap_opts=>vector('ServiceName', 'InteropTests', 'CR-escape', 'yes', 'router', 'no', 'role', 'http://example.org/ts-tests/C', 'HttpSOAPVersion', '12'));

DB.DBA.VHOST_DEFINE (lpath=>'/soap12-doc', ppath=>'/SOAP/', soap_user=>'soap12doc', soap_opts=>vector('ServiceName', 'InteropTests', 'CR-escape', 'yes', 'router', 'no', 'role', 'http://example.org/ts-tests/C', 'HttpSOAPVersion', '12'));

DB.DBA.VHOST_DEFINE (lpath=>'/soap12-rpc', ppath=>'/SOAP/', soap_user=>'soap12rpc', soap_opts=>vector('ServiceName', 'InteropTests', 'CR-escape', 'yes', 'router', 'no', 'role', 'http://example.org/ts-tests/C', 'HttpSOAPVersion', '12'));


SOAP_LOAD_SCH ('<schema xmlns="http://www.w3.org/2001/XMLSchema"
    xmlns:xsd="http://www.w3.org/2001/XMLSchema"
    xmlns:enc="http://www.w3.org/2003/05/soap-encoding"
    xmlns:tns="http://whitemesa.net/wsdl/soap12-test"
    xmlns:types="http://example.org/ts-tests/xsd"
    xmlns:test="http://example.org/ts-tests"
    xmlns:xlink="http://www.w3.org/1999/xlink"
    elementFormDefault="qualified"
    targetNamespace="http://example.org/ts-tests">
    <import namespace="http://www.w3.org/1999/xlink" />
    <element name="RelativeReference" type="test:RelativeReference_t"/>
    <complexType name="RelativeReference_t">
	  <attribute ref="xml:base"/>
	  <attribute ref="xlink:href"/>
    </complexType>
    <element name="echoResolvedRef" type="test:echoResolvedRef_t"/>
    <complexType name="echoResolvedRef_t">
	<sequence>
	    <element ref="test:RelativeReference" minOccurs="1" maxOccurs="1"/>
	</sequence>
    </complexType>
    <element name="echoOk" type="string" />
    <element name="concatAndForwardEchoOk" type="string" />
    <element name="concatAndForwardEchoOkArg1" type="string" />
    <element name="concatAndForwardEchoOkArg2" type="string" />
    <element name="responseOk" type="string" />
    <element name="requiredHeader" type="string" />
    <element name="echoHeaderResponse" type="string" />
    <element name="echoHeader" type="string" />
    <element name="responseResolvedRef" type="string" />
    <element name="validateCountryCode" type="string" />
    <element name="validateCountryCodeFault" type="string" />
</schema>');

SOAP_LOAD_SCH ('<schema xmlns="http://www.w3.org/2001/XMLSchema"
    xmlns:xsd="http://www.w3.org/2001/XMLSchema"
    xmlns:enc="http://www.w3.org/2003/05/soap-encoding"
    elementFormDefault="qualified"
    targetNamespace="http://soapinterop.org/">
    <element name="time" type="time" />
</schema>');


use Interop;

create procedure INTEROP.emptyBody
    (
      in  echoOkRequest nvarchar := NULL __soap_header 'http://example.org/ts-tests:echoOk',
      out echoOkResponse nvarchar := NULL __soap_header 'http://example.org/ts-tests:responseOk'
    )
  __soap_doc '__VOID__'
{
  --dbg_obj_print ('INTEROP.emptyBody',echoOkRequest);
  echoOkResponse := echoOkRequest;
};

create procedure INTEROP.echoOk
    (
      in  echoOkHdrRequest nvarchar := NULL __soap_header 'http://example.org/ts-tests:echoOk',
      out echoOkHdrResponse nvarchar := NULL __soap_header 'http://example.org/ts-tests:responseOk',
      in  echoOkRequest nvarchar := NULL __soap_type 'http://example.org/ts-tests:echoOk',
      out echoOkResponse nvarchar := NULL __soap_type 'http://example.org/ts-tests:responseOk'
    )
  __soap_doc '__VOID__'
{
  --dbg_obj_print ('INTEROP.echoOk', echoOkRequest);
  echoOkHdrResponse := echoOkHdrRequest;
  echoOkResponse := echoOkRequest;
};

create procedure INTEROP.echoHeader
    (
      in  requiredHeader 	nvarchar := NULL __soap_header 'http://example.org/ts-tests:requiredHeader',
      in  echoHeader 		any 	 := NULL __soap_type 'http://example.org/ts-tests:echoHeader',
      out echoHeaderResponse 	nvarchar := NULL __soap_type 'http://example.org/ts-tests:echoHeaderResponse'
    )
  __soap_doc '__VOID__'
{
  --dbg_obj_print ('INTEROP.echoHeader', requiredHeader);
  echoHeaderResponse := requiredHeader;
};


create procedure INTEROP.returnVoid
    (
    )
  __soap_type '__VOID__'
{
  --dbg_obj_print ('INTEROP.returnVoid');
  return;
};

create procedure INTEROP.countItems
	(
	  in inputStringArray any
    	)
  returns int
{
  --dbg_obj_print ('INTEROP.countItems', inputStringArray);
  return length (inputStringArray);
};

create procedure INTEROP.isNil
	(
	  in inputString nvarchar := NULL
    	)
  returns smallint
{
   if (inputString is null)
     return soap_boolean (1);
   else
    return soap_boolean (0);
};

create procedure
INTEROP.echoVoid
   (
     in echoMeStringRequest nvarchar := NULL
       __soap_options
                (
	 	__soap_header:='http://www.w3.org/2001/XMLSchema:string',
		RequestNamespace:='http://soapinterop.org/echoheader/'
		),
     out echoMeStringResponse nvarchar := NULL
       __soap_options
       		(
		 __soap_header:='http://www.w3.org/2001/XMLSchema:string',
		 ResponseNamespace:='http://soapinterop.org/echoheader/'
		),
     in echoMeStructRequest any := NULL
       __soap_options
                (
		 __soap_header:='http://soapinterop.org/xsd:SOAPStruct',
		RequestNamespace:='http://soapinterop.org/echoheader/'
		),
     out echoMeStructResponse any := NULL
       __soap_options
       		(
		 __soap_header:='http://soapinterop.org/xsd:SOAPStruct',
		 ResponseNamespace:='http://soapinterop.org/echoheader/'
		)
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

grant execute on Interop.INTEROP.emptyBody to INTEROP;
grant execute on Interop.INTEROP.echoRef to INTEROP;
grant execute on Interop.INTEROP.echoOk to INTEROP;
grant execute on Interop.INTEROP.returnVoid to INTEROP;
grant execute on Interop.INTEROP.echoVoid to INTEROP;
grant execute on Interop.INTEROP.countItems to INTEROP;
grant execute on Interop.INTEROP.isNil to INTEROP;
grant execute on Interop.INTEROP.echoHeader to INTEROP;

use WSRP;

create procedure WSRP.emptyBody
    (
      in  echoOkRequest nvarchar := NULL
      __soap_header  'http://example.org/ts-tests:echoOk',
      in concatAndForwardEchoOk nvarchar := NULL
      __soap_header  'http://example.org/ts-tests:concatAndForwardEchoOk',
      in concatAndForwardEchoOkArg1 nvarchar := NULL
      __soap_header  'http://example.org/ts-tests:concatAndForwardEchoOkArg1',
      in concatAndForwardEchoOkArg2 nvarchar := NULL
      __soap_header  'http://example.org/ts-tests:concatAndForwardEchoOkArg2',

      in ws_soap_headers any,
      in all_params_xml any,

      out echoOkResponse nvarchar := NULL
      __soap_header 'http://example.org/ts-tests:responseOk'
    )
  __soap_doc '__VOID__'
{

  --dbg_obj_print ('WSRP.emptyBody',echoOkRequest);

  echoOkResponse := echoOkRequest;

  if (concatAndForwardEchoOk is not null)
    {
      declare hdr any;
      hdr := '<env:Header xmlns:env="http://www.w3.org/2003/05/soap-envelope">' ||
	'<test:echoOk xmlns:test="http://example.org/ts-tests"' ||
	'      env:role="http://example.org/ts-tests/C"' ||
	'      env:mustUnderstand="1">'||
       sprintf ('%V', concatAndForwardEchoOk||concatAndForwardEchoOkArg1||concatAndForwardEchoOkArg2)
       || '</test:echoOk>'
       || '</env:Header>';
       ws_soap_headers := xml_tree_doc (hdr);
    }
  DB.DBA.SOAP12_ROUTER ('http://localhost:'||server_http_port ()||'/soap12',
  			'http://example.org/ts-tests/B',
			ws_soap_headers,
			all_params_xml);
};

grant execute on WSRP.WSRP.emptyBody to WSRP;

use Interop;

create procedure soap12doc.getTime ()
__soap_doc 'http://soapinterop.org/:time'
{
  return cast (now() as time);
}
;

create procedure soap12rpc.getTime ()
__soap_options (__soap_type:='http://www.w3.org/2001/XMLSchema:time',
ResponseNamespace:='http://soapinterop.org/')
{
  return cast (now() as time);
}
;

grant execute on soap12doc.getTime to soap12doc
;

grant execute on soap12rpc.getTime to soap12rpc
;

create procedure
INTEROP.validateCountryCode
		(
		 in validateCountryCode
		 	varchar __soap_header 'http://example.org/ts-tests:validateCountryCode',
		 out validateCountryCodeFault
		 	varchar __soap_header 'http://example.org/ts-tests:validateCountryCodeFault'
		)
__soap_doc '__VOID__'
 {
   validateCountryCode := cast (validateCountryCode as varchar);
   validateCountryCode := trim (validateCountryCode, ' \r\n');
   --dbg_obj_print (validateCountryCode);
   if (length (validateCountryCode) <> 2)
     {
       validateCountryCodeFault := 'Country code must be 2 letters.';
       http_request_status ('HTTP/1.1 400 Bad request');
       connection_set ('SOAPFault', vector ('300', 'Not a valid country code'));
     }
   return;
 }
;

create procedure INTEROP.echoRef
(
  in echoResolvedRef any __soap_header 'http://example.org/ts-tests:echoResolvedRef',
  out responseResolvedRef any __soap_header 'http://example.org/ts-tests:responseResolvedRef'
)
  __soap_doc '__VOID__'
{
  --dbg_obj_print ('INTEROP.echoRef', echoResolvedRef);
  if (length (echoResolvedRef) > 0 and length (echoResolvedRef[0]) > 1)
    {
      declare attrs any;
      declare base, href any;

      attrs := echoResolvedRef[0][1];
      if (isarray (attrs) and not isstring (attrs))
	{
	  base := cast (get_keyword ('base', attrs,  '') as varchar);
	  href := cast (get_keyword ('href', attrs , '') as varchar);
	  responseResolvedRef := WS.WS.EXPAND_URL (base, href);
	}
    }
}
;


grant execute on INTEROP.echoRef to INTEROP
;

grant execute on INTEROP.validateCountryCode to INTEROP
;



