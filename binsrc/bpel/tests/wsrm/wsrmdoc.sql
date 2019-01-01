--  
--  $Id$
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
use DB;

vhost_remove (lpath=>'/RmSvc');

select U_NAME from SYS_USERS where U_NAME = 'WSRM';
$IF $EQU $ROWCNT 1 "" "create user WSRM";

vhost_define (lpath=>'/RmSvc', ppath=>'/SOAP/', soap_user=>'WSRM',
	soap_opts=>vector ('WSRM-Callback', 'WSRM.WSRM.CALLBACK'));

grant execute on WSRMSequence to WSRM;

grant execute on WSRMSequenceTerminate to WSRM;

grant execute on WSRMAckRequested to WSRM;

create procedure WSRM.WSRM.CALLBACK (in msg any, in seq any, in msgid any)
{
  dbg_obj_print (seq, msgid);
  --dbg_obj_print (msg);
  soap_server (msg, '', null, 11, null, vector ('Use', 'literal'));
}
;

create procedure WSRM..wsa_hdr (in mid1 any)
{
  declare wsa_rel, mid, id any;
  mid := coalesce (mid1, vector (null, null, null));
  id := mid[2];
  if (id is null)
    return null;
  wsa_rel := vector (composite (), '', id);
  return vector (
            vector ('RelatesTo', 'http://schemas.xmlsoap.org/ws/2003/03/addressing:RelatesTo'), wsa_rel
	);
}
;

create procedure WSRM..echo
(
  in var varchar,
  in "ReplyTo" any := null __soap_options(__soap_header:='http://schemas.xmlsoap.org/ws/2003/03/addressing:ReplyTo', "Use":='literal'),
  in "MessageID" any := null __soap_options(__soap_header:= 'http://schemas.xmlsoap.org/ws/2003/03/addressing:MessageID', "Use":='literal')
)
{
  declare url any;
  url := get_keyword ('Address', "ReplyTo");
  dbg_obj_print ('WSRM.echo var=', var);
  --http_request_status ('HTTP/1.1 202 Accepted');
  --http_flush ();
  dbg_printf ('sending reponse for : %s', url);
  DB.DBA.SOAP_CLIENT (direction=>1,
  		url=>cast (url as varchar),
  		operation=>'onResult',
		style=>1,
  		parameters =>  vector ('par0' , xtree_doc ('<echoResponse>var='||var||'</echoResponse>')),
		headers => WSRM..wsa_hdr ("MessageID")
  	);
  return null;
}
;

grant execute on WSRM.WSRM.CALLBACK to WSRM;
grant execute on WSRM..echo to WSRM;

use bpel;

create procedure doc_upl ()
{
  declare id int;
  id := script_upload ('', 'file:/wsrm/doc.bpel');
  wsdl_upload (id, 'file:/wsrm/doc.wsdl');
  wsdl_upload (id, 'file:/wsrm/wsrmsvc.wsdl', null, 'service');
  compile_script (id, '/RmEcho');
  BPEL..stat_init (id);
  update BPEL..partner_link_init set bpl_opts =
'<wsOptions>
    <security>
      <key name="" />
      <pubkey name="" />
      <in>
        <encrypt type="NONE" />
        <signature type="NONE" />
      </in>
      <out>
        <encrypt type="NONE" />
        <signature type="NONE" />
      </out>
    </security>
    <delivery>
      <in type="ExactlyOnce" />
      <out type="ExactlyOnce" />
    </delivery>
   </wsOptions>' where bpl_script = id  and bpl_name in ('service');
};

doc_upl();

select xpath_eval ('//varString/text()',
	xml_tree_doc (DB.DBA.soap_client (url=>sprintf ('http://localhost:%s/RmEcho',server_http_port()),
	operation=>'echo',
	style=>5,
	soap_action=>'echo', parameters=>vector (vector ('varString','string'), 'wsrm'))));
ECHO BOTH $IF $EQU $LAST[1] "var=wsrm" "PASSED:" "***FAILED:";
ECHO BOTH " WSRM ECHO returns " $LAST[1] " word\n";
