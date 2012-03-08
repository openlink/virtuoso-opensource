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

DB.DBA.USER_CREATE ('interop4m', uuid(), vector ('DISABLED', 1))
;

DB.DBA.user_set_qualifier ('interop4m', 'interop4m');
DB.DBA.VHOST_REMOVE (lpath=>'/r4/groupG/mime/doc')
;


DB.DBA.VHOST_DEFINE (lpath=>'/r4/groupG/mime/doc', ppath=>'/SOAP/', soap_user=>'interop4m',
    soap_opts => vector (
      'Namespace','http://soapinterop.org/attachments/','MethodInSoapAction','no', 'ServiceName', 'GroupGService'
      )
    )
;

-- methods

use interop4m;

create procedure
"EchoAttachment" (in "In" nvarchar __soap_type 'http://soapinterop.org/attachments/xsd:EchoAttachment')
returns nvarchar __soap_doc 'http://soapinterop.org/attachments/xsd:EchoAttachmentResponse'
__soap_enc_mime inout
{
  if (not isarray ("In"[0]))
    signal ('TEST2' ,'The attachment is missing or not MIME encoded.');
  return vector (vector (uuid(), "In"[0][1], "In"[0][2]));
}
;


create procedure
"EchoBase64AsAttachment" (in "In" nvarchar
     __soap_type 'http://soapinterop.org/attachments/xsd:EchoBase64AsAttachment')
returns nvarchar __soap_doc 'http://soapinterop.org/attachments/xsd:EchoBase64AsAttachmentResponse'
__soap_enc_mime out
{
  declare _Out any;
  _Out := decode_base64 (cast ("In"[0] as varchar));
  return vector(vector (uuid(), 'application/octetstream', _Out));
}
;

create procedure
"EchoAttachmentAsBase64" (
    in "In" nvarchar __soap_type 'http://soapinterop.org/attachments/xsd:EchoAttachmentAsBase64'
    )
returns nvarchar __soap_doc 'http://soapinterop.org/attachments/xsd:EchoAttachmentAsBase64Response'
__soap_enc_mime in
{
  if (not isarray ("In"[0]))
    signal ('TEST1' ,'The attachment is missing or not MIME encoded.');
  return vector (encode_base64 (cast ("In"[0][2] as varchar)));
}
;


create procedure
"EchoAttachments" (in "In" any __soap_type 'http://soapinterop.org/attachments/xsd:EchoAttachments')
returns nvarchar __soap_doc 'http://soapinterop.org/attachments/xsd:EchoAttachmentsResponse'
__soap_enc_mime inout
{
  declare i, l int;
  declare arr any;

  l := length ("In");
  arr := make_array (l, 'any');
  while (i < l)
    {
      if (not isarray ("In"[i]))
	signal ('TEST3' ,'The attachment is missing or not MIME encoded.');
      aset (arr, i, vector (uuid(), "In"[i][1], "In"[i][2]));
      i := i + 1;
    }

  return arr;
}
;

-- grants
grant execute on "EchoBase64AsAttachment" to "interop4m"
;

grant execute on "EchoAttachmentAsBase64" to "interop4m"
;

grant execute on "EchoAttachment" to "interop4m"
;

grant execute on "EchoAttachments" to "interop4m"
;

use DB;

