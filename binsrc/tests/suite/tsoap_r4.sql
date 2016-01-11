--
--  $Id: tsoap_r4.sql,v 1.8.10.1 2013/01/02 16:15:26 source Exp $
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2016 OpenLink Software
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
ECHO BOTH "STARTED: SOAP Interop IV tests\n";

SET ARGV[0] 0;
SET ARGV[1] 0;
create procedure att_reslt (in arr any, in w int := 1)
{
  declare res varchar;
  result_names (res);
  if (w = 1)
    res := arr[4][1][2];
  else if (w = 2)
    res := arr[4][0][2];
  else
    {
      declare tmp any;
      tmp := arr[0];
      tmp := xml_tree_doc (tmp);
      res := xpath_eval ('//text()', tmp, 1);
    }
  dbg_obj_print ('---', res);
  result (res);
}
;

ECHO BOTH "group G, DIME Document Literal\n";
ECHO BOTH "=== MIME ===\n";

att_reslt (soap_client (url=>'http://localhost:$U{HTTPPORT}/r4/groupG/mime/doc',
      operation=>'EchoAttachments',
      parameters=>
      vector(vector('In', 'http://soapinterop.org/attachments/xsd:EchoAttachment'),
      vector (vector (uuid(), 'application/octetstream' , '123456789'))),
      style=>515,
      soap_action=>'http://soapinterop.org/attachments/'
      )) ;
ECHO BOTH $IF $EQU $LAST[1] '123456789' "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": EchoAttachments : " $LAST[1] "\n";

att_reslt (soap_client (url=>'http://localhost:$U{HTTPPORT}/r4/groupG/mime/doc', operation=>'EchoBase64AsAttachment', parameters=>vector(vector('EchoBase64AsAttachment', 'http://soapinterop.org/attachments/xsd:EchoBase64AsAttachment'), vector(encode_base64('Hello DocLit'))), style=>515, soap_action=>'http://soapinterop.org/attachments/')) ;

ECHO BOTH $IF $EQU $LAST[1] 'Hello DocLit' "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": EchoBase64AsAttachment : " $LAST[1] "\n";

att_reslt (soap_client (url=>'http://localhost:$U{HTTPPORT}/r4/groupG/mime/doc', operation=>'EchoAttachmentAsBase64', parameters=>vector(vector ('In', 'http://soapinterop.org/attachments/xsd:EchoAttachmentAsBase64'), vector (vector (uuid(), 'application/octetstream' , '1234567890'))), style=>515, soap_action=>'http://soapinterop.org/attachments/'), 3);
ECHO BOTH $IF $EQU $LAST[1] 'MTIzNDU2Nzg5MA==' "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": EchoAttachmentAsBase64 : " $LAST[1] "\n";

att_reslt (soap_client (url=>'http://localhost:$U{HTTPPORT}/r4/groupG/mime/doc', operation=>'EchoAttachments',
      parameters=>
      vector(vector('In', 'http://soapinterop.org/attachments/xsd:EchoAttachments'),
      vector (vector(uuid(), '', '123'), vector (uuid(), '', '345'))
      ), style=>515,
      soap_action=>'http://soapinterop.org/attachments/'
      )) ;
ECHO BOTH $IF $EQU $LAST[1] '123' "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": EchoAttachments : " $LAST[1] "\n";

ECHO BOTH "=== DIME ===\n";
att_reslt (soap_client (url=>'http://localhost:$U{HTTPPORT}/r4/groupG/dime/doc', operation=>'EchoBase64AsAttachment', parameters=>vector(vector('EchoBase64AsAttachment', 'http://soapinterop.org/attachments/xsd:EchoBase64AsAttachment'), vector(encode_base64('Hello DocLit'))), style=>11, soap_action=>'http://soapinterop.org/attachments/')) ;

ECHO BOTH $IF $EQU $LAST[1] 'Hello DocLit' "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": EchoBase64AsAttachment : " $LAST[1] "\n";

att_reslt (soap_client (url=>'http://localhost:$U{HTTPPORT}/r4/groupG/dime/doc', operation=>'EchoAttachmentAsBase64', parameters=>vector(
	       vector ('In', 'http://soapinterop.org/attachments/xsd:EchoAttachmentAsBase64'),
	       vector (vector (uuid(), 'application/octetstream' , '1234567890'))), style=>11,
      soap_action=>'http://soapinterop.org/attachments/'
      ), 3);
ECHO BOTH $IF $EQU $LAST[1] 'MTIzNDU2Nzg5MA==' "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": EchoAttachmentAsBase64 : " $LAST[1] "\n";

att_reslt (soap_client (url=>'http://localhost:$U{HTTPPORT}/r4/groupG/dime/doc', operation=>'EchoAttachmentAsString',
      parameters=>vector(
	       vector('In', 'http://soapinterop.org/attachments/xsd:EchoAttachmentAsString'),
	       vector(vector (uuid(), 'text/plain' , '<html><body><p>Hello World</p></body></html>'))), style=>11,
      soap_action=>'http://soapinterop.org/attachments/'
      ), 3);
ECHO BOTH $IF $EQU $LAST[1] '&lt;html&gt;&lt;body&gt;&lt;p&gt;Hello World&lt;/p&gt;&lt;/body&gt;&lt;/html&gt;' "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": EchoAttachmentAsString : " $LAST[1] "\n";


att_reslt (soap_client (url=>'http://localhost:$U{HTTPPORT}/r4/groupG/dime/doc', operation=>'EchoAttachments',
      parameters=>
      vector(vector('In', 'http://soapinterop.org/attachments/xsd:EchoAttachments'),
      vector (vector(uuid(), '', '123'), vector (uuid(), '', '345'))
      ), style=>11,
      soap_action=>'http://soapinterop.org/attachments/'
      )) ;
ECHO BOTH $IF $EQU $LAST[1] '123' "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": EchoAttachments : " $LAST[1] "\n";


att_reslt (soap_client (url=>'http://localhost:$U{HTTPPORT}/r4/groupG/dime/doc', operation=>'EchoUnrefAttachments', parameters=>
      vector(vector('In', 'http://soapinterop.org/attachments/xsd:EchoUnrefAttachments'), vector ()),
      style=>11,
      soap_action=>'http://soapinterop.org/attachments/'
      ),2) ;
ECHO BOTH $IF $EQU $LAST[1] '0' "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": EchoUnrefAttachments : " $LAST[1] "\n";


ECHO BOTH "group G, DIME RPC encoded\n";
ECHO BOTH "=== MIME ===\n";

att_reslt (soap_client (url=>'http://localhost:$U{HTTPPORT}/r4/groupG/mime/rpc', operation=>'EchoAttachment', parameters=>vector(vector('In', 'http://soapinterop.org/attachments/xsd:EchoAttachment'), vector (vector (uuid(), 'application/octetstream' , '123456789'))), style=>514, soap_action=>'http://soapinterop.org/attachments/'));
ECHO BOTH $IF $EQU $LAST[1] '123456789' "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": EchoAttachment : " $LAST[1] "\n";

att_reslt (soap_client (url=>'http://localhost:$U{HTTPPORT}/r4/groupG/mime/rpc', operation=>'EchoBase64AsAttachment', parameters=>vector('In', encode_base64 ('1234567890')), style=>514, soap_action=>'http://soapinterop.org/attachments/'));
ECHO BOTH $IF $EQU $LAST[1] '1234567890' "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": EchoBase64AsAttachment : " $LAST[1] "\n";

att_reslt (soap_client (url=>'http://localhost:$U{HTTPPORT}/r4/groupG/mime/rpc', operation=>'EchoAttachmentAsBase64', parameters=>vector(vector('In', 'base64Binary'), vector (uuid(), 'application/octetstream' , '1234567890')), style=>514, soap_action=>'http://soapinterop.org/attachments/'), 3);
ECHO BOTH $IF $EQU $LAST[1] 'MTIzNDU2Nzg5MA==' "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": EchoAttachmentAsBase64 : " $LAST[1] "\n";

ECHO BOTH "=== DIME ===\n";
att_reslt (soap_client (url=>'http://localhost:$U{HTTPPORT}/r4/groupG/dime/rpc', operation=>'EchoBase64AsAttachment',
      parameters=>vector('In', encode_base64 ('1234567890')), style=>10,
      soap_action=>'http://soapinterop.org/attachments/',
      target_namespace=>'http://soapinterop.org/attachments/'
      ));
ECHO BOTH $IF $EQU $LAST[1] '1234567890' "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": EchoBase64AsAttachment : " $LAST[1] "\n";

att_reslt (soap_client (url=>'http://localhost:$U{HTTPPORT}/r4/groupG/dime/rpc', operation=>'EchoAttachmentAsBase64',
      parameters=>vector(
	       vector('In', 'base64Binary'),
	       vector (uuid(), 'application/octetstream' , '1234567890')), style=>10,
      soap_action=>'http://soapinterop.org/attachments/',
      target_namespace=>'http://soapinterop.org/attachments/'
      ), 3);
ECHO BOTH $IF $EQU $LAST[1] 'MTIzNDU2Nzg5MA==' "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": EchoAttachmentAsBase64 : " $LAST[1] "\n";


att_reslt (soap_client (url=>'http://localhost:$U{HTTPPORT}/r4/groupG/dime/rpc', operation=>'EchoAttachmentAsString',
      parameters=>vector(
	       vector('In', 'base64Binary'),
	       vector (uuid(), 'text/plain' , '<html><body><p>Hello World</p></body></html>')), style=>10,
      soap_action=>'http://soapinterop.org/attachments/',
      target_namespace=>'http://soapinterop.org/attachments/'
      ), 3);

att_reslt (soap_client (url=>'http://localhost:$U{HTTPPORT}/r4/groupG/dime/rpc', operation=>'EchoAttachments', parameters=>
      vector(vector('In', 'http://soapinterop.org/attachments/xsd:ArrayOfBinary'),
      vector (vector(uuid(), '', '123'), vector (uuid(), '', '345')) ), style=>10,
      soap_action=>'http://soapinterop.org/attachments/',
      target_namespace=>'http://soapinterop.org/attachments/')) ;
ECHO BOTH $IF $EQU $LAST[1] '123' "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": EchoAttachments : " $LAST[1] "\n";


att_reslt (soap_client (url=>'http://localhost:$U{HTTPPORT}/r4/groupG/dime/rpc', operation=>'EchoUnrefAttachments', parameters=>
      vector(), style=>10,
      soap_action=>'http://soapinterop.org/attachments/',
      target_namespace=>'http://soapinterop.org/attachments/'), 2) ;
ECHO BOTH $IF $EQU $LAST[1] '0' "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": EchoUnrefAttachments : " $LAST[1] "\n";

ECHO BOTH "group H - SOAP:Fault tests \n";

create procedure
fault_result (in res any, in tp varchar := 'string', in elm varchar := null)
{
  declare xt any;
  declare ret any;
  xt := xml_tree_doc (res[0]);
  dbg_obj_print (xt);
  xt := xpath_eval ('//detail/*[1]', xt, 1);
  ret := soap_box_xml_entity_validating (xml_cut(xt), tp);
  dbg_obj_print ('result', ret);
  result_names (ret);
  if (tp = 'string')
    result (ret);
  if (isinteger (elm) and isarray(ret) and length (ret) >= elm)
    result (ret[elm - 1]);
  if (isstring (elm) and udt_instance_of (ret, elm))
    result (call (elm || 'Echo') (ret, 1));
}
;

create procedure DB.DBA."ExtendedStructEcho" (in stru DB.DBA."ExtendedStruct", in elm int)
{
  return stru."floatMessage";
}
;

create procedure
soap_cli_wrap ()
{
  declare stru DB.DBA."ExtendedStruct";
  declare ret any;
  stru := new DB.DBA."ExtendedStruct" ();
  stru."stringMessage" := 'string1';
  stru."intMessage" := 1;
  stru."anotherIntMessage" := 0;
  stru."floatMessage" := 3.1415;
  stru."shortMessage" := 4096;
  ret :=
      soap_client (url=>'http://localhost:$U{HTTPPORT}/r4/groupH/complex/rpc', operation=>'echoExtendedStructFault',
      parameters=> vector( vector ('param', 'http://soapinterop.org/types:ExtendedStruct'), stru), style=>2);
  return ret;
};


create procedure
soap_cli_wrap1 ()
{
  declare stru1 DB.DBA."BaseStruct";
  declare stru2 DB.DBA."ExtendedStruct";
  declare stru3 DB.DBA."MoreExtendedStruct";
  declare ret any;
  stru1 := new DB.DBA."BaseStruct" ();
  stru2 := new DB.DBA."ExtendedStruct" ();
  stru3 := new DB.DBA."MoreExtendedStruct" ();

  stru1."floatMessage" := 3.1415;
  stru1."shortMessage" := 4096;

  stru2."stringMessage" := 'string1';
  stru2."intMessage" := 1;
  stru2."anotherIntMessage" := 0;
  stru2."floatMessage" := 3.1415;
  stru2."shortMessage" := 4096;

  stru3."booleanMessage" := soap_boolean (1);
  stru3."stringMessage" := 'string1';
  stru3."intMessage" := 1;
  stru3."anotherIntMessage" := 0;
  stru3."floatMessage" := 3.1415;
  stru3."shortMessage" := 4096;

  ret :=
      soap_client (url=>'http://localhost:$U{HTTPPORT}/r4/groupH/complex/rpc', operation=>'echoMultipleFaults2',
      parameters=> vector(
	'whichFault', 3,
	vector ('param1', 'http://soapinterop.org/types:BaseStruct'), stru1,
	vector ('param2', 'http://soapinterop.org/types:ExtendedStruct'), stru2,
	vector ('param3', 'http://soapinterop.org/types:MoreExtendedStruct'), stru3
	), style=>2);
  return ret;
};

create procedure DB.DBA."MoreExtendedStructEcho" (in stru DB.DBA."MoreExtendedStruct", in elm int)
{
  return stru."booleanMessage";
}
;

fault_result (soap_client (url=>'http://localhost:$U{HTTPPORT}/r4/groupH/simple/rpc', operation=>'echoStringFault',  parameters=> vector('param', 'string'), style=>2));
ECHO BOTH $IF $EQU $LAST[1] 'string' "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": echoStringFault : " $LAST[1] "\n";

fault_result (soap_client (url=>'http://localhost:$U{HTTPPORT}/r4/groupH/simple/rpc', operation=>'echoIntArrayFault',  parameters=> vector('param', vector(1,4096,3)), style=>2), 'http://soapinterop.org/types:ArrayOfInt', 2);

ECHO BOTH $IF $EQU $LAST[1] '4096' "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": echoIntArrayFault : " $LAST[1] "\n";

fault_result (soap_client (url=>'http://localhost:$U{HTTPPORT}/r4/groupH/simple/rpc', operation=>'echoMultipleFaults2',  parameters=> vector('whichFault', 3, 'param1', 'string', 'param2', 3.1415, 'param3' , vector('', 'string2', '')), style=>2), 'http://soapinterop.org/types:ArrayOfString', 2);

ECHO BOTH $IF $EQU $LAST[1] 'string2' "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": echoMultipleFaults2 : " $LAST[1] "\n";

fault_result (soap_cli_wrap (), 'http://soapinterop.org/types:ExtendedStruct', 'DB.DBA.ExtendedStruct');
ECHO BOTH $IF $EQU $LAST[1] '3.1415' "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": echoExtendedStructFault : " $LAST[1] "\n";


fault_result (soap_cli_wrap1 (), 'http://soapinterop.org/types:MoreExtendedStruct', 'DB.DBA.MoreExtendedStruct');
ECHO BOTH $IF $EQU $LAST[1] '1' "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": echoMultipleFaults2 : " $LAST[1] "\n";

ECHO BOTH "group I - XSD tests \n";

-- testing special types, the rest are from round II
-- echoChoice
-- echoEnum
-- echoAnyType
-- echoAnyElement
-- echoVoidSoapHeader

create procedure
unwrap_result (in res any, in what varchar := '')
{
  declare xt any;
  declare ret varchar;
  dbg_obj_print (res);
  xt := xml_tree_doc (res[0]);
  result_names (ret);
  ret := xpath_eval ('//' || what || 'text()', xt, 1);
  result (ret);
}
;

unwrap_result (soap_client (url=>'http://localhost:$U{HTTPPORT}/r4/groupI', operation=>'echoChoice',
      parameters=>vector(vector('inputChoice', 'http://soapinterop.org/xsd:ChoiceComplexType'),
	                         soap_box_structure ('name0','My Name')),
      style=>7, target_namespace=>'http://soapinterop.org/'));
ECHO BOTH $IF $EQU $LAST[1] 'My Name' "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": echoChoice : " $LAST[1] "\n";


unwrap_result (soap_client (url=>'http://localhost:$U{HTTPPORT}/r4/groupI', operation=>'echoEnum',
      parameters=>vector(vector('inputEnum', 'http://soapinterop.org/xsd:Enum'),
	                         vector (composite (), 'Enum', 'BitTwo')),
      style=>7, target_namespace=>'http://soapinterop.org/'));
ECHO BOTH $IF $EQU $LAST[1] 'BitTwo' "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": echoEnum : " $LAST[1] "\n";


unwrap_result (soap_client (url=>'http://localhost:$U{HTTPPORT}/r4/groupI', operation=>'echoAnyType',
      parameters=>vector('inputAnyType', 1),
      style=>7, target_namespace=>'http://soapinterop.org/'));
ECHO BOTH $IF $EQU $LAST[1] '1' "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": echoAnyType : " $LAST[1] "\n";


unwrap_result (soap_client (url=>'http://localhost:$U{HTTPPORT}/r4/groupI', operation=>'echoAnyElement',
      parameters=>vector(vector('inputAny', 'http://soapinterop.org/:AnyElementType'), vector (xml_tree_doc ('<string xsi:type="xsd:string" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" >any element</string>'))),
      style=>7, target_namespace=>'http://soapinterop.org/'));
ECHO BOTH $IF $EQU $LAST[1] 'any element' "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": echoAnyElement : " $LAST[1] "\n";

unwrap_result (vector (http_get ('http://localhost:$U{HTTPPORT}/r4/groupI', null, 'POST', 'Content-Type: text/xml\r\nSOAPAction: ""', file_to_string ('hdr.xml'))), 'varString/');
ECHO BOTH $IF $EQU $LAST[1] 'I&#39;m in a header' "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": echoVoidSoapHeader : " $LAST[1] "\n";

unwrap_result (vector(aref(soap_client (url=>'http://localhost:$U{HTTPPORT}/r4/groupI', operation=>'echoVoidSoapHeader', parameters=>vector(), headers=>vector(vector('echoMeStringRequest', 'http://soapinterop.org/:echoMeStringRequest', 1, 'http://schemas.xmlsoap.org/soap/actor/next') ,  vector('String')), style=>7, target_namespace=>'http://soapinterop.org', soap_action=>'"http://soapinterop.org"'), 2)), 'varString/');
ECHO BOTH $IF $EQU $LAST[1] 'String' "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": echoVoidSoapHeader : " $LAST[1] "\n";

ECHO BOTH "COMPLETED WITH " $ARGV[0] " FAILED, " $ARGV[1] " PASSED: SOAP Interop IV tests\n";

