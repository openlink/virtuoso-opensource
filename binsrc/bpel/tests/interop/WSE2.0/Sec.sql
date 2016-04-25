--  
--  $Id$
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
use BPEL;

create procedure doc_upl ()
{
  declare id int;
  id := script_upload ('', 'file:/interop/Sec.bpel');
  wsdl_upload (id, 'file:/interop/Sec.wsdl');
  wsdl_upload (id, 'file:/interop/SecSvc.wsdl', null, 'service');
  compile_script (id, '/SecEcho', vector ('WSS-Validate-Signature', 2));

  update BPEL..partner_link_init set bpl_opts =
  '<wsOptions>
    <addressing version="http://schemas.xmlsoap.org/ws/2004/03/addressing"/>
    <security>
      <key name="ClientPrivate.pfx" />
      <pubkey name="ServerPublic.cer" />
      <in>
        <encrypt type="Optional" />
        <signature type="Optional" />
      </in>
      <out>
        <encrypt type="AES192" />
        <signature type="Default" />
      </out>
    </security>
    <delivery>
      <in type="NONE" />
      <out type="NONE" />
    </delivery>
   </wsOptions>' where bpl_script = id  and bpl_name in ('service','caller');

};

doc_upl();

drop procedure doc_upl;

create procedure BPEL..load_keys ()
{
  set_user_id ('BPEL');
  if (xenc_key_exists ('ServerPublic.cer'))
    return;
  db..user_key_load ('ClientPrivate.pfx', file_to_string (http_root () || '/interop/ClientPrivate.pfx'),
	'X.509', 'PKCS12', 'wse2qs', null, 1);
  db..user_key_load ('ServerPublic.cer', file_to_string (http_root () || '/interop/ServerPublic.cer'),
	'X.509', 'DER', 'wse2qs', null, 1);
};

BPEL..load_keys ();

drop procedure BPEL..load_keys;
