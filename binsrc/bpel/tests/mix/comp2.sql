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
use bpel;

drop table cmpflow_test;
create table cmpflow_test (id int identity primary key, dt varchar);

use DB;

vhost_remove (lpath=>'/TimeSvc');

create user TSVC;

vhost_define (lpath=>'/TimeSvc', ppath=>'/SOAP/', soap_user=>'TSVC', soap_opts=>vector ('GeneratePartnerLink', 'yes', 'ServiceName', 'TimeSvc'));


create procedure TSVC..wsa_hdr (in mid1 any)
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

soap_dt_define ('', '<xsd:element name="Interval" targetNamespace="services.wsdl" xmlns:xsd="http://www.w3.org/2001/XMLSchema" type="xsd:int" />');
soap_dt_define ('', '<xsd:element name="CancelInterval" targetNamespace="services.wsdl" xmlns:xsd="http://www.w3.org/2001/XMLSchema" type="xsd:int" />');

create procedure TSVC..tWait
	(
	in "Interval" varchar __soap_type 'services.wsdl:Interval',
	in "ReplyTo" any := null __soap_header 'http://schemas.xmlsoap.org/ws/2003/03/addressing:ReplyTo',
	in "MessageID" any := null __soap_header 'http://schemas.xmlsoap.org/ws/2003/03/addressing:MessageID'
	)
    __soap_doc '__VOID__'
{
  declare url any;

  dbg_obj_print ('tWait var=', "Interval");

  url := get_keyword ('Address', "ReplyTo");

  if ("Interval" <= 0)
    signal ('22023', 'BadInterval');

  http_request_status ('HTTP/1.1 202 Accepted');
  http_flush ();

  delay ("Interval");

  dbg_obj_print ('sending response to=', url);
  db.dba.soap_client (direction=>1,
	style=>1,
	url=>cast (url as varchar),
	operation=>'onWait',
	soap_action=>'onWait',
	parameters =>  vector ('par1',
		xtree_doc ('<cli:tWaitResponse xmlns:cli="services.wsdl">1</cli:tWaitResponse>')),
		headers => TSVC..wsa_hdr ("MessageID")
		);
  --insert into bpel..cmpflow_test (dt) values ('resp sent');
  dbg_obj_print ('finished sending response...');
  return;
}
;


create procedure TSVC..tCancelWait
	(
	in "CancelInterval" varchar __soap_type 'services.wsdl:CancelInterval',
	in "ReplyTo" any := null __soap_header 'http://schemas.xmlsoap.org/ws/2003/03/addressing:ReplyTo',
	in "MessageID" any := null __soap_header 'http://schemas.xmlsoap.org/ws/2003/03/addressing:MessageID'
	)
    __soap_options (__soap_doc:='__VOID__', OneWay:=1)
{
  declare url any;

  dbg_obj_print ('tCancelWait var=', "CancelInterval");

  url := get_keyword ('Address', "ReplyTo");
  delay (5);
  dbg_obj_print ('sending cancelation response to=', url);
  db.dba.soap_client (direction=>1,
	style=>1,
	url=>cast (url as varchar),
	operation=>'onCancelWait',
	soap_action=>'onCancelWait',
	parameters =>  vector ('par1',
		xtree_doc ('<cli:tCancelWaitResponse xmlns:cli="services.wsdl">0</cli:tCancelWaitResponse>')),
		headers => TSVC..wsa_hdr ("MessageID")
		);
  --insert into bpel..cmpflow_test (dt) values ('cancel resp sent');
  dbg_obj_print ('finished sending cancelation response...');
  return;
}
;


grant execute on TSVC..tWait to TSVC;
grant execute on TSVC..tCancelWait to TSVC;



use bpel;
delete from script where bs_name = 'file:/mix/cmpflow.bpel';

select BPEL.BPEL.upload_script ('file:/mix/', 'cmpflow.bpel', 'cmpflow.wsdl');
ECHO BOTH $IF $EQU $LAST[1] NULL  "PASSED:" "***FAILED:";
ECHO BOTH " compflow script upload error status:" $LAST[1] "\n";

BPEL.BPEL.wsdl_process_remote ('svc', 'file:/mix/timesvc.wsdl', 'file:/mix/cmpflow.bpel');
ECHO BOTH $IF $EQU $STATE OK  "PASSED:" "***FAILED:";
ECHO BOTH " compflow script pl status:" $STATE "\n";

select  xpath_eval ('/echoResponse/echoString/text()',
	xml_tree_doc (
		DB.DBA.soap_client (
		url=>sprintf ('http://localhost:%s/BPELGUI/bpel.vsp?script=file:/mix/cmpflow.bpel',
		  server_http_port()),
		operation=>'echo',
		soap_action=>'echo',
		parameters=> vector ('par', xtree_doc ('<echoString>hello world</echoString>')))
		));
ECHO BOTH $IF $EQU $LAST[1] 'hello world'  "PASSED:" "***FAILED:";
ECHO BOTH " compflow script returns : " $LAST[1] "\n";

select dt from bpel..cmpflow_test where id = 1;
ECHO BOTH $IF $EQU $LAST[1] 'catch'  "PASSED:" "***FAILED:";
ECHO BOTH " compflow process test 1-st record " $LAST[1] "\n";

select dt from bpel..cmpflow_test where id = 2;
ECHO BOTH $IF $EQU $LAST[1] 'comp'  "PASSED:" "***FAILED:";
ECHO BOTH " compflow process test 2-d record " $LAST[1] "\n";


--select dt from bpel..cmpflow_test where id = 3;
--ECHO BOTH $IF $EQU $LAST[1] 'resp sent'  "PASSED:" "***FAILED:";
--ECHO BOTH " compflow process test 3-d record " $LAST[1] "\n";

--select dt from bpel..cmpflow_test where id = 4;
--ECHO BOTH $IF $EQU $LAST[1] 'cancel resp sent'  "PASSED:" "***FAILED:";
--ECHO BOTH " compflow process test 4-th record " $LAST[1] "\n";

select dt from bpel..cmpflow_test where id = 3;
ECHO BOTH $IF $EQU $LAST[1] 'comp end'  "PASSED:" "***FAILED:";
ECHO BOTH " compflow process test 3-d record " $LAST[1] "\n";

select dt from bpel..cmpflow_test where id = 4;
ECHO BOTH $IF $EQU $LAST[1] 'flow end'  "PASSED:" "***FAILED:";
ECHO BOTH " compflow process test 4-th record " $LAST[1] "\n";



