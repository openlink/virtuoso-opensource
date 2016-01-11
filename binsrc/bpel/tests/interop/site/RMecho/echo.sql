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
-- depends of Aecho and RMLoan
use DB;

vhost_remove (lpath=>'/RMEchoReply');
vhost_define (lpath=>'/RMEchoReply', ppath=>'/SOAP/', soap_user=>'LWSRM',
    		soap_opts=>vector ('WSRM-Callback', 'WSRM.WSRM.CALLBACK3'));

create procedure WSRM.WSRM.CALLBACK3 (in msg any, in seq any, in msgid any)
{
  dbg_obj_print ('CALLBACK3', seq, msgid);
  set_user_id ('AECHO');
  soap_server (msg, '', null, 11, null, vector ('Use', 'literal'));
}
;

grant execute on WSRM.WSRM.CALLBACK3 to LWSRM;

create procedure rmaecho_deploy ()
{
  declare scp int;
  BPEL.BPEL.import_script ('file:/RMecho/bpel.xml', 'RMEcho', scp);
  BPEL..compile_script (scp, '/RMEcho');
  update BPEL..partner_link_init set bpl_opts = LF_RM_OPTS () where bpl_name in ('caller') and bpl_script = scp;
}
;

rmaecho_deploy ();

