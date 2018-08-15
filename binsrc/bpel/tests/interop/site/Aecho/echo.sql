--  
--  $Id$
--  
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--  
--  Copyright (C) 1998-2018 OpenLink Software
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

DB.DBA.USER_CREATE ('AECHO', uuid(), vector ('DISABLED', 1));

vhost_remove (lpath=>'/AEchoReply');
vhost_define (lpath=>'/AEchoReply', ppath=>'/SOAP/', soap_user=>'AECHO');

create procedure AECHO..reply (in echoString varchar, in ws_soap_request any)
{
  declare tid int;
  tid := 2;
  if (http_path () = '/RMEchoReply')
    tid := 4;
  else if  (http_path () = '/SecAEchoReply')
    tid := 3;
  dbg_obj_print (echoString, tid);
  insert into BPWSI..test_queue (tq_test, tq_msg, tq_ip)
      values (tid, xml_tree_doc (ws_soap_request), http_client_ip ());
  return;
}
;

grant execute on AECHO..reply to AECHO;

create procedure aecho_deploy ()
{
  declare scp int;
  BPEL.BPEL.import_script ('file:/Aecho/bpel.xml', 'AEcho', scp);
  BPEL..compile_script (scp, '/AEcho');
}
;

aecho_deploy ();

