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
create user "interop4"
;

user_set_qualifier ('interop4', 'interop4');

VHOST_REMOVE (lpath=>'/r4/groupG/dime/rpc')
;

VHOST_DEFINE (lpath=>'/r4/groupG/dime/rpc', ppath=>'/SOAP/', soap_user=>'interop4',
    soap_opts => vector (
      'Namespace','http://soapinterop.org/attachments/','MethodInSoapAction','no', 'ServiceName', 'GroupGService'
      )
    )
;

-- methods

use interop4;

create procedure
"EchoBase64AsAttachment" (in "In" nvarchar __soap_type 'http://www.w3.org/2001/XMLSchema:base64Binary')
returns nvarchar __soap_type 'http://soapinterop.org/attachments/xsd:ReferencedBinary'
__soap_dime_enc out
{
  declare _Out any;
  _Out := decode_base64 (cast ("In" as varchar));
  dbg_obj_print ('echoBase64AsAttachment :', _Out);
  return vector (uuid(), 'application/octetstream', _Out);
}
;

create procedure
"EchoAttachmentAsBase64" (in "In" nvarchar __soap_type 'http://soapinterop.org/attachments/xsd:ReferencedBinary')
returns nvarchar __soap_type 'http://www.w3.org/2001/XMLSchema:base64Binary'
__soap_dime_enc in
{
  dbg_obj_print ('EchoAttachmentAsBase64 :', "In");
  if (not isarray ("In"))
    signal ('TEST1' ,'The attachment is missing or not DIME encoded.');
  return encode_base64 (cast ("In"[2] as varchar));
}
;

create procedure
"EchoAttachment" (in "In" nvarchar __soap_type 'http://soapinterop.org/attachments/xsd:ReferencedBinary')
returns nvarchar __soap_type 'http://soapinterop.org/attachments/xsd:ReferencedBinary'
__soap_dime_enc inout
{
  dbg_obj_print ('EchoAttachment :', "In");
  if (not isarray ("In"))
    signal ('TEST2' ,'The attachment is missing or not DIME encoded.');
  return vector (uuid(), "In"[1], "In"[2]);
}
;

create procedure
"EchoAttachments" (in "In" any __soap_type 'http://soapinterop.org/attachments/xsd:ArrayOfBinary')
returns nvarchar __soap_type 'http://soapinterop.org/attachments/xsd:ArrayOfBinary'
__soap_dime_enc inout
{
  declare i, l int;
  declare arr any;
  dbg_obj_print ('EchoAttachments :', "In");

  l := length ("In");
  arr := make_array (l, 'any');
  while (i < l)
    {
      if (not isarray ("In"[i]))
	signal ('TEST3' ,'The attachment is missing or not DIME encoded.');
      aset (arr, i, vector (uuid(), "In"[i][1], "In"[i][2]));
      i := i + 1;
    }

  return arr;
}
;

create procedure
"EchoAttachmentAsString" (in "In" nvarchar __soap_type 'http://soapinterop.org/attachments/xsd:ReferencedText')
returns nvarchar __soap_type 'http://www.w3.org/2001/XMLSchema:string'
__soap_dime_enc in
{
  declare enc, typ, src varchar;
  declare decoded nvarchar;

  if (not isarray ("In"))
    signal ('TEST4' ,'The attachment is missing or not DIME encoded.');

  src := "In"[2];
  enc := "In"[1];
  typ :=  http_request_header (vector('Content-Type:' || enc), 'Content-Type');
  enc := http_request_header (vector('Content-Type:' || enc), 'Content-Type', 'charset', current_charset ());
  if (typ like 'text/%')
    {
      declare exit handler for sqlstate '*'
	{
	  if (lower(enc) = 'utf-16')
	    {
	      decoded := charset_recode (src, 'UTF-16LE', '_WIDE_');
              goto next;
	    }
	  else
	    resignal;
	};
      decoded := charset_recode (src, enc, '_WIDE_');
    }
  else
    decoded := src;
next:
  dbg_obj_print ('EchoAttachmentAsString: ', decoded);
  return decoded;
}
;

create procedure
"EchoUnrefAttachments" (inout ws_soap_attachments any)
__soap_type '__VOID__'
__soap_dime_enc inout
{
  declare arr any;
  declare i, l int;
  l := length (ws_soap_attachments);
  if (l > 1)
    {
      arr := make_array (l-1, 'any'); i := 1;
      while (i < l)
	{
	  if (not isarray (ws_soap_attachments[i]))
	    signal ('TEST5' ,'The attachment is missing or not DIME encoded.');
	  aset (arr, i-1, vector (uuid(), ws_soap_attachments[i][1], ws_soap_attachments[i][2]));
	  i := i + 1;
	}
      ws_soap_attachments := arr;
    }
  else
    ws_soap_attachments := NULL;
  --dbg_obj_print ('EchoUnrefAttachments', ws_soap_attachments);
  return;
}
;


-- grants
grant execute on "EchoBase64AsAttachment" to "interop4"
;

grant execute on "EchoAttachmentAsBase64" to "interop4"
;

grant execute on "EchoAttachment" to "interop4"
;

grant execute on "EchoAttachments" to "interop4"
;

grant execute on "EchoAttachmentAsString" to "interop4"
;

grant execute on "EchoUnrefAttachments" to "interop4"
;

use DB;

