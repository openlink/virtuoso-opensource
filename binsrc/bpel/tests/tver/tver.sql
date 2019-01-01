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
use db;
vhost_remove (lpath=>'/LifeSvc');

vhost_remove (lpath=>'/LifeSvc');

select U_NAME from SYS_USERS where U_NAME = 'LSVC';
$IF $EQU $ROWCNT 1 "" "create user LSVC";

vhost_define (lpath=>'/LifeSvc', ppath=>'/SOAP/', soap_user=>'LSVC', soap_opts=>vector ('Use', 'literal', 'GeneratePartnerLink', 'yes', 'ServiceName', 'LifeSvc'));


create procedure LSVC..wsa_hdr (in mid1 any)
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

create procedure LSVC..echoSync (in var varchar) returns varchar
{
  dbg_obj_print ('echoSync var=',var);
  declare scp_id, scp_id_new int;
  whenever not found goto nf;
  if (1)
    {
  select bs_id into scp_id from BPEL.BPEL.script where bs_state = 0 and bs_name = 'tver';
  scp_id_new := BPEL..copy_script(scp_id);
  BPEL..script_source_update(scp_id_new, 'file://tver/tvernew1.bpel',null);
  BPEL..compile_script(scp_id_new);
    }
  nf:
  return 'var='||var;
}
;

soap_dt_define ('', '<xsd:element name="var" targetNamespace="services.wsdl" xmlns:xsd="http://www.w3.org/2001/XMLSchema" type="xsd:string" />');

create procedure LSVC..echoASync
	(
	in var varchar __soap_type 'services.wsdl:var',
	in "ReplyTo" any := null __soap_header 'http://schemas.xmlsoap.org/ws/2003/03/addressing:ReplyTo',
	in "MessageID" any := null __soap_header 'http://schemas.xmlsoap.org/ws/2003/03/addressing:MessageID'
	)
    __soap_options (__soap_doc:='__VOID__', OneWay:=1)
{
  declare scp_id, scp_id_new, retr int;
  declare url any;
  dbg_obj_print ('echoASync var=',var);
  whenever not found goto nf;
  if (1)
    {
  select bs_id into scp_id from BPEL.BPEL.script where bs_state = 0 and bs_name = 'tver' with (exclusive);
  scp_id_new := BPEL..copy_script(scp_id);
  BPEL..script_source_update(scp_id_new, 'file://tver/tvernew2.bpel',null);
  BPEL..compile_script(scp_id_new);
  commit work;
    }
  nf:
  url := get_keyword ('Address', "ReplyTo");
  retr := 2;
  --trace_on ('soap');
  declare exit handler for sqlstate '*' {
    -- give a chance to the script to put something into wait table,
    -- otherwise the new version have no onResult and message will
    -- be rejected as unknown
    if (retr > 0)
      {
        dbg_obj_print ('error ... retrying');
	retr := retr - 1;
	delay (1);
	goto again;
      }
    --trace_off ('soap');
  };

  again:
  --delay (1);
  dbg_obj_print ('sending response to=', url);
  db.dba.soap_client (direction=>1,
	style=>1,
	url=>cast (url as varchar),
	operation=>'onResult',
	--soap_action=>'onResult',
	parameters =>  vector ('par1',
		xtree_doc (sprintf('<cli:echoSyncResponse xmlns:cli="services.wsdl"><CallReturn>ASYNC=%s</CallReturn></cli:echoSyncResponse>', var))),
		headers => LSVC..wsa_hdr ("MessageID")
		);
  dbg_obj_print ('finished sending response...');
  --trace_off ('soap');
  return;
}
;


grant all privileges to LSVC;
grant execute on LSVC..echoSync to LSVC;
grant execute on LSVC..echoASync to LSVC;

use bpel;

delete from script where bs_name = 'tver';

create procedure doc_upl ()
{
  declare id int;
  id := script_upload ('tver', 'file:/tver/tver.bpel');
  wsdl_upload (id, 'file:/tver/tver.wsdl');
  wsdl_upload (id, 'file:/tver/service.wsdl', null, 'service');
  compile_script (id);
};

doc_upl();
ECHO BOTH $IF $EQU $STATE OK "PASSED:" "***FAILED:";
ECHO BOTH " tver script has been uploaded:" $STATE "\n";
drop procedure doc_upl;

select  xpath_eval ('/echoResponse/varString/text()',
    xml_tree_doc (
      DB.DBA.soap_client (
      url=>sprintf ('http://localhost:%s/BPELGUI/bpel.vsp?script=tver',server_http_port()),
      operation=>'echo',
      soap_action=>'echo',
      style=>1,
      parameters=> vector ('par', xtree_doc ('<echo xmlns="http://temp.org"><varString>12</varString></echo>')))
      ));
ECHO BOTH $IF $EQU $LAST[1] "var=12" "PASSED:" "***FAILED:";
ECHO BOTH " tver initial version returns " $LAST[1] " word\n";


select  xpath_eval ('/echoResponse/varString/text()',
    xml_tree_doc (
      DB.DBA.soap_client (
      url=>sprintf ('http://localhost:%s/BPELGUI/bpel.vsp?script=tver',server_http_port()),
      operation=>'echo',
      soap_action=>'echo',
      style=>1,
      parameters=> vector ('par', xtree_doc ('<echo xmlns="http://temp.org"><varString>12</varString></echo>')))
      ));
ECHO BOTH $IF $EQU $LAST[1] "ASYNC=12" "PASSED:" "***FAILED:";
ECHO BOTH " tver second version returns " $LAST[1] " word\n";



select  xpath_eval ('/echoResponse/varString/text()',
    xml_tree_doc (
      DB.DBA.soap_client (
      url=>sprintf ('http://localhost:%s/BPELGUI/bpel.vsp?script=tver',server_http_port()),
      operation=>'echo',
      soap_action=>'echo',
      style=>1,
      parameters=> vector ('par', xtree_doc ('<echo xmlns="http://temp.org"><varString>12</varString></echo>')))
      ));
ECHO BOTH $IF $EQU $LAST[1] "12" "PASSED:" "***FAILED:";
ECHO BOTH " tver last version returns " $LAST[1] " word\n";

select  xpath_eval ('/echoResponse/varString/text()',
    xml_tree_doc (
      DB.DBA.soap_client (
      url=>sprintf ('http://localhost:%s/BPELGUI/bpel.vsp?script=tver',server_http_port()),
      operation=>'echo',
      soap_action=>'echo',
      style=>1,
      parameters=> vector ('par', xtree_doc ('<echo xmlns="http://temp.org"><varString>12</varString></echo>')))
      ));
ECHO BOTH $IF $EQU $LAST[1] "12" "PASSED:" "***FAILED:";
ECHO BOTH " tver last version returns " $LAST[1] " word\n";
