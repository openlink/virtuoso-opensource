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
-- depends of SecLoan and Aecho
use DB;

vhost_remove (lpath=>'/SecAEchoReply');
vhost_define (lpath=>'/SecAEchoReply', ppath=>'/SOAP/', soap_user=>'AECHO',
    soap_opts=>vector ('WS-SEC','yes', 'WSS-Validate-Signature', 1));

BPEL..load_keys ('AECHO', 'ServerPrivate.pfx', 'ClientPublic.cer');

create procedure secaecho_deploy ()
{
  declare scp int;
  BPEL.BPEL.import_script ('file:/SecAecho/bpel.xml', 'SecAEcho', scp);
  BPEL..compile_script (scp, '/SecAEcho');
  update BPEL..partner_link_init set bpl_opts = LF_SEC_OPTS () where bpl_name in ('caller') and bpl_script = scp;
}
;

secaecho_deploy ();

