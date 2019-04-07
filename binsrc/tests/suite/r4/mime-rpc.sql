--  
--  $Id: mime-rpc.sql,v 1.4.10.1 2013/01/02 16:15:46 source Exp $
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

USER_CREATE ('interop4gm', uuid(), vector ('DISABLED', 1))
;

user_set_qualifier ('interop4gm', 'interop4gm');

VHOST_REMOVE (lpath=>'/r4/groupG/mime/rpc')
;

VHOST_DEFINE (lpath=>'/r4/groupG/mime/rpc', ppath=>'/SOAP/', soap_user=>'interop4gm',
    soap_opts => vector (
      'Namespace','http://soapinterop.org/attachments/','MethodInSoapAction','no', 'ServiceName', 'GroupGService'
      )
    )
;

-- methods

use interop4gm;

create procedure
"EchoBase64AsAttachment" (in "In" nvarchar __soap_type 'http://www.w3.org/2001/XMLSchema:base64Binary')
returns nvarchar __soap_type 'http://soapinterop.org/attachments/xsd:ReferencedBinary'
__soap_enc_mime out
{
  declare _Out any;
  _Out := decode_base64 (cast ("In" as varchar));
  return vector (uuid(), 'application/octetstream', _Out);
}
;

create procedure
"EchoAttachmentAsBase64" (in "In" nvarchar __soap_type 'http://soapinterop.org/attachments/xsd:ReferencedBinary')
returns nvarchar __soap_type 'http://www.w3.org/2001/XMLSchema:base64Binary'
__soap_enc_mime in
{
  if (not isarray ("In"))
    signal ('TEST1' ,'The attachment is missing or not MIME encoded.');
  return encode_base64 (cast ("In"[2] as varchar));
}
;

create procedure
"EchoAttachment" (in "In" nvarchar __soap_type 'http://soapinterop.org/attachments/xsd:EchoAttachment')
returns nvarchar __soap_type 'http://soapinterop.org/attachments/xsd:EchoAttachmentResponse'
__soap_enc_mime inout
{
  if (not isarray ("In"[0]))
    signal ('TEST2' ,'The attachment is missing or not MIME encoded.');
  return vector (vector (uuid(), "In"[0][1], "In"[0][2]));
}
;

-- grants
grant execute on "EchoBase64AsAttachment" to "interop4gm"
;

grant execute on "EchoAttachmentAsBase64" to "interop4gm"
;

grant execute on "EchoAttachment" to "interop4gm"
;

use DB;

