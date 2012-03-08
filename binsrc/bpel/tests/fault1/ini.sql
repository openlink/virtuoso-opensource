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

-- XXX: caller is on same instance
--insert into BPEL.BPEL.partner_link_conf values ('caller',
--	sprintf ('http://localhost:%s/BPELREQ', '$U{http_port_two}'));
--ECHO BOTH $IF $EQU $STATE OK  "PASSED:" "***FAILED:";
--ECHO BOTH " Fault1 script configuration status:" $STATE "\n";
create table BPEL.BPEL.sql_exec_test (messg varchar);

BPEL.BPEL.upload_script ('file://','UseStockReviewSheet.bpel','UseStockReviewSheet.wsdl');
select count (bs_uri) from BPEL.BPEL.script;
ECHO BOTH $IF $EQU $LAST[1] "1" "PASSED:" "***FAILED:";
ECHO BOTH " UseStockReviewSheet.bpel script upload status:" $LAST[1] "\n";

BPEL.BPEL.upload_script ('file://', 'sql_exec.bpel', 'sql_exec.wsdl');
select count (bs_uri) from BPEL.BPEL.script;
ECHO BOTH $IF $EQU $LAST[1] "2" "PASSED:" "***FAILED:";
ECHO BOTH " sql_exec.bpel script upload status:" $LAST[1] "\n";

BPEL.BPEL.upload_script ('file://','While.bpel','While.wsdl');
select count (bs_uri) from BPEL.BPEL.script;
ECHO BOTH $IF $EQU $LAST[1] "3" "PASSED:" "***FAILED:";
ECHO BOTH " WHILE script upload status:" $LAST[1] "\n";

BPEL.BPEL.upload_script ('file://','fault.bpel','fault.wsdl');
select count (bs_uri) from BPEL.BPEL.script;
ECHO BOTH $IF $EQU $LAST[1] "4" "PASSED:" "***FAILED:";
ECHO BOTH " Fault1 script upload status:" $LAST[1] "\n";

BPEL.BPEL.wsdl_process_remote ('test', sprintf ('http://localhost:%s/servicewsdl.vsp', '$U{http_port_two}'),
	'file:/fault.bpel');
ECHO BOTH $IF $EQU $STATE OK  "PASSED:" "***FAILED:";
ECHO BOTH " Fault script configuration status:" $STATE "\n";

BPEL.BPEL.upload_script ('file://','fault2.bpel','fault.wsdl');
select count (bs_uri) from BPEL.BPEL.script;
ECHO BOTH $IF $EQU $LAST[1] "5" "PASSED:" "***FAILED:";
ECHO BOTH " Fault1 2 script upload status:" $LAST[1] "\n";
BPEL.BPEL.wsdl_process_remote ('test',
	sprintf ('http://localhost:%s/servicewsdl.vsp', '$U{http_port_two}'),
	'file:/fault2.bpel');
ECHO BOTH $IF $EQU $STATE OK  "PASSED:" "***FAILED:";
ECHO BOTH " Fault2 script configuration status:" $STATE "\n";

BPEL.BPEL.upload_script ('file://','fault3.bpel','fault.wsdl');
select count (bs_uri) from BPEL.BPEL.script;
ECHO BOTH $IF $EQU $LAST[1] "6" "PASSED:" "***FAILED:";
ECHO BOTH " Fault3 script upload status:" $LAST[1] "\n";
BPEL.BPEL.wsdl_process_remote ('test',
	sprintf ('http://localhost:%s/servicewsdl.vsp', '$U{http_port_two}'),
	'file:/fault3.bpel');
ECHO BOTH $IF $EQU $STATE OK  "PASSED:" "***FAILED:";
ECHO BOTH " Fault3 script configuration status:" $STATE "\n";

BPEL.BPEL.upload_script ('file://','comp1.bpel','fault.wsdl');
select count (bs_uri) from BPEL.BPEL.script;
ECHO BOTH $IF $EQU $LAST[1] "7" "PASSED:" "***FAILED:";
ECHO BOTH " Comp1 script upload status:" $LAST[1] "\n";
BPEL.BPEL.wsdl_process_remote ('test',
	sprintf ('http://localhost:%s/servicewsdl.vsp', '$U{http_port_two}'),
	'file:/comp1.bpel');
ECHO BOTH $IF $EQU $STATE OK  "PASSED:" "***FAILED:";
ECHO BOTH " Comp1 script configuration status:" $STATE "\n";

create table DB.DBA.restart_test (val varchar);
ECHO BOTH $IF $EQU $STATE OK "PASSED:" "***FAILED:";
ECHO BOTH " Restart script test table create: " $STATE "\n";

select BPEL.BPEL.upload_script ('file://', 'Restart.bpel', 'Restart.wsdl');
select count (*) from BPEL.BPEL.script;
ECHO BOTH $IF $EQU $LAST[1] "8" "PASSED:" "***FAILED:";
ECHO BOTH " Restart script upload status:" $LAST[1] "\n";


BPEL.BPEL.upload_script ('file://','faultHTCLI.bpel','fault.wsdl');
select count (bs_uri) from BPEL.BPEL.script;
ECHO BOTH $IF $EQU $LAST[1] "9" "PASSED:" "***FAILED:";
ECHO BOTH " Comp1 script upload status:" $LAST[1] "\n";
BPEL.BPEL.wsdl_process_remote ('test',
	sprintf ('http://localhost:%s/servicewsdl.vsp', '$U{http_port_two}'),
	'file:/faultHTCLI.bpel');
ECHO BOTH $IF $EQU $STATE OK  "PASSED:" "***FAILED:";
ECHO BOTH " faultHTCLI script configuration status:" $STATE "\n";

update BPEL.BPEL.partner_link_init set bpl_endpoint = sprintf ('http://localhost:%d/nowhere', atoi(server_http_port())+5)
	where bpl_script = (select bs_id from BPEL.BPEL.script where
				bs_uri like '%HTCLI.bpel');
ECHO BOTH $IF $EQU $STATE OK  "PASSED:" "***FAILED:";
ECHO BOTH " faultHTCLI script configuration-2 status:" $STATE "\n";

select xpath_eval ('//*[1]/text()', xml_tree_doc (db.dba.soap_client (url=>sprintf ('http://localhost:%s/BPELGUI/bpel.vsp?script=file:/fault.bpel',server_http_port()), soap_action=>'echo', operation=>'echo', parameters =>  vector ('echoString', 'hello world'))));
ECHO BOTH $IF $EQU $LAST[1] "hello world" "PASSED:" "***FAILED:";
ECHO BOTH " Fault test returns returns " $LAST[1] " word\n";

select aref (aref (db.dba.soap_client (url=>sprintf ('http://localhost:%s/BPELGUI/bpel.vsp?script=file:/fault2.bpel',server_http_port()), soap_action=>'echo', operation=>'echo', parameters =>  vector ('echoString', 'hello world')),1),1);
ECHO BOTH $IF $EQU $LAST[1] "Request is invalid, catchAll" "PASSED:" "***FAILED:";
ECHO BOTH " Fault 2 test returns returns " $LAST[1] " word\n";

select aref (aref (db.dba.soap_client (url=>sprintf ('http://localhost:%s/BPELGUI/bpel.vsp?script=file:/fault3.bpel',server_http_port()), soap_action=>'echo', operation=>'echo', parameters =>  vector ('echoString', 'hello world')),1),1);
ECHO BOTH $IF $EQU $LAST[1] "Request is invalid, invalidRequest" "PASSED:" "***FAILED:";
ECHO BOTH " Fault 3 test returns returns " $LAST[1] " word\n";

select xpath_eval ('//*[1]/text()', xml_tree_doc (db.dba.soap_client (url=>sprintf ('http://localhost:%s/BPELGUI/bpel.vsp?script=file:/comp1.bpel',server_http_port()), soap_action=>'echo', operation=>'echo', parameters =>  vector ('echoString', 'hello world'))));
-- the compensation is executed in sandbox like enviroment
ECHO BOTH $IF $EQU $LAST[1] "hello world" "PASSED:" "***FAILED:";
ECHO BOTH " Comp 1 test returns returns " $LAST[1] " word\n";

select xpath_eval ('//*[1]/text()', xml_tree_doc (db.dba.soap_client (url=>sprintf ('http://localhost:%s/BPELGUI/bpel.vsp?script=file:/faultHTCLI.bpel',server_http_port()), soap_action=>'echo', operation=>'echo', parameters =>  vector ('echoString', 'hello world'))));
ECHO BOTH $IF $EQU $LAST[1] "HTCLI" "PASSED:" "***FAILED:";
ECHO BOTH " faultHTCLI test returned " $LAST[1] " word\n";


-- XXX: temporary disabled to run new engine
select count (bi_last_error) from BPEL.BPEL.instance where bi_last_error is not null;
--ECHO BOTH $IF $EQU $LAST[1] 2  "PASSED:" "***FAILED:";
--ECHO BOTH " " $LAST[1] " errors found" "\n";

DB.DBA.vhost_define (vhost=>'*ini*', lhost=>'*ini*', lpath=>'/BPEL3/', ppath=>'/SOAP', soap_user=>'DBA');
ECHO BOTH $IF $EQU $STATE OK "PASSED:" "***FAILED:";
ECHO BOTH " New SOAP host define: " $STATE "\n";


create table DB.DBA.ws_addr_test (params any);

create procedure WS.DBA.onResult (in currentPrice any __SOAP_XML_TYPE 'http://www.w3.org/2001/XMLSchema:anyType') {
  http_request_status ('HTTP/1.1 202 Accepted');
  http_flush();

  insert into DB.DBA.ws_addr_test values (currentPrice);
};
ECHO BOTH $IF $EQU $STATE OK  "PASSED:" "***FAILED:";
ECHO BOTH " create DB.DBA.onResult status:" $STATE "\n";

-- select db.dba.soap_client (direction=>1,headers=>vector (vector ('ReplyTo', '__XML__', 0),xtree_doc (concat ('<wsa:ReplyTo xmlns:wsa="http://schemas.xmlsoap.org/ws/2004/03/addressing"><wsa:Address>',sprintf ('http://localhost:%s/BPEL3/', server_http_port()),'</wsa:Address></wsa:ReplyTo>'))),url=>sprintf ('http://localhost:%s/BPELGUI/bpel.vsp?script=file:/UseStockReviewSheet.bpel',server_http_port()), soap_action=>'initiate', operation=>'initiate',parameters =>  vector ('par', xtree_doc ('<useStockReviewSheetRequest><symbol>1</symbol><targetPrice>44.8</targetPrice><currentPrice>22.9</currentPrice><action>BUY</action><quantity>10</quantity></useStockReviewSheetRequest>')));
ECHO BOTH $IF $EQU $STATE OK "PASSED:" "***FAILED:";
ECHO BOTH " UseStockReviewSheet.bpel invokation state :"  $STATE "\n";

sleep 10;

select count(*) from DB.DBA.ws_addr_test;
-- ECHO BOTH $IF $EQU $LAST[1] 1  "PASSED:" "***FAILED:";
-- ECHO BOTH $LAST[1] " Catch by WS-Addressing:" $LAST[1] "\n";


select  xpath_eval ('/destResponse/country/text()', xml_tree_doc (db.dba.soap_client (url=>sprintf ('http://localhost:%s/BPELGUI/bpel.vsp?script=file:/sql_exec.bpel',server_http_port()), style=>1, soap_action=>'check_dest', operation=>'check_dest', parameters =>  vector ('par1', xtree_doc ('<destRequest xmlns="urn:echo:echoService"><city>ALA</city></destRequest>')))));
ECHO BOTH $IF $EQU $LAST[1] 'KZ' "PASSED:" "***FAILED:";
ECHO BOTH " <bpelv:exec> ALA: " $LAST[1] "\n";

select  xpath_eval ('/destResponse/country/text()', xml_tree_doc (db.dba.soap_client (url=>sprintf ('http://localhost:%s/BPELGUI/bpel.vsp?script=file:/sql_exec.bpel',server_http_port()), style=>1, soap_action=>'check_dest', operation=>'check_dest', parameters =>  vector ('par1', xtree_doc ('<destRequest xmlns="urn:echo:echoService"><city>SYD</city></destRequest>')))));
ECHO BOTH $IF $EQU $LAST[1] 'AU' "PASSED:" "***FAILED:";
ECHO BOTH " <bpelv:exec> SYD: " $LAST[1] "\n";

select  xpath_eval ('/destResponse/country/text()', xml_tree_doc (db.dba.soap_client (url=>sprintf ('http://localhost:%s/BPELGUI/bpel.vsp?script=file:/sql_exec.bpel',server_http_port()), style=>1, soap_action=>'check_dest', operation=>'check_dest', parameters =>  vector ('par1', xtree_doc ('<destRequest xmlns="urn:echo:echoService"><city>Taldykorgan</city></destRequest>')))));
ECHO BOTH $IF $EQU $LAST[1] 'Unknown' "PASSED:" "***FAILED:";
ECHO BOTH " <bpelv:exec> Taldykorgan: " $LAST[1] "\n";

select messg from BPEL.BPEL.sql_exec_test;
ECHO BOTH $IF $EQU $LAST[1] "hello world" "PASSED:" "***FAILED:";
ECHO BOTH " <bpelv:exec> test inserted value: " $LAST[1] "\n";

db..vhost_define (lpath=>'/', ppath=>'/', vsp_user=>'dba');
ECHO BOTH $IF $EQU $STATE "OK" "PASSED:" "***FAILED:";
ECHO BOTH " root lpath: " $STATE "\n";


BPEL.BPEL.wsdl_process_remote ('IncrementService', sprintf ('http://localhost:%s/incsvcwsdl.vsp', '$U{http_port_two}'),         'file:/While.bpel');
ECHO BOTH $IF $Equ $sTATE OK "PASSED:" "***FAILED:";
ECHO BOTH " IncrementService processed for While state: " $STATE "\n";
BPEL.BPEL.wsdl_process_remote ('IncrementService', sprintf ('http://localhost:%s/incsvcwsdl.vsp', '$U{http_port_two}'),         'file:/Restart.bpel');
ECHO BOTH $IF $EQU $STATE OK "PASSED:" "***FAILED:";
ECHO BOTH " IncrementService processed for Restart state: " $STATE "\n";

grant execute on BPEL.BPEL.process to INCR;
create table DB.DBA.while_test_table (res int);

db..soap_dt_define ('', '<xsd:element name="result" type="xsd:int" targetNamespace="http://samples.cxdn.com" xmlns:xsd="http://www.w3.org/2001/XMLSchema"/>');
create procedure BPEL.BPEL.onResult (in result int __soap_type 'http://samples.cxdn.com:result') __soap_doc '__VOID__'
{
	insert into DB.DBA.while_test_table values (result);
};
ECHO BOTH $IF $EQU $STATE OK "PASSED:" "***FAILED:";
ECHO BOTH " Interceptor for While test state: " $STATE "\n";


select db.dba.soap_client (direction=>1, soap_action=>'initiate', style=>1, url=>concat ('http://localhost:', server_http_port(), '/BPELGUI/bpel.vsp?script=file:/While.bpel'), operation =>'initiate', parameters =>  vector ('par1', xtree_doc ('<value>10</value>')));
ECHO BOTH $IF $EQU $STATE OK "PASSED:" "***FAILED:";
ECHO BOTH " While initiate state: " $STATE "\n";

sleep 10;
select res from DB.DBA.while_test_table;
ECHO BOTH $IF $EQU $LAST[1] "11" "PASSED:" "***FAILED:";
ECHO BOTH " While test returns: " $LAST[1] "\n";
delete from DB.DBA.while_test_table;
BPEL.BPEL.set_backup_endpoint_by_name ('file:/While.bpel', 'IncrementService', 'http://localhost:' || '$U{http_port_two}' || '/increment'); 
ECHO BOTH $IF $EQU $STATE OK "PASSED:" "***FAILED:";
ECHO BOTH " While: setting backup endpoint state: " $STATE "\n";
  update BPEL.BPEL.partner_link_init set bpl_endpoint = sprintf ('http://localhost:%d/nowhere', atoi(server_http_port())+5)
where bpl_endpoint like '%increment' and bpl_script = 3;

select db.dba.soap_client (direction=>1, soap_action=>'initiate', style=>1, url=>concat ('http://localhost:', server_http_port(), '/BPELGUI/bpel.vsp?script=file:/While.bpel'), operation =>'initiate', parameters =>  vector ('par1', xtree_doc ('<value>2</value>')));
ECHO BOTH $IF $EQU $STATE OK "PASSED:" "***FAILED:";
ECHO BOTH " While [ with connection error ] initiate state: " $STATE "\n";
sleep 50;

select res from DB.DBA.while_test_table;
ECHO BOTH $IF $EQU $LAST[1] "3" "PASSED:" "***FAILED:";
ECHO BOTH " While test returns: " $LAST[1] "\n";

BPEL.BPEL.set_backup_endpoint_by_name ('file:/While.bpel', 'IncrementService', null); 
ECHO BOTH $IF $EQU $STATE OK "PASSED:" "***FAILED:";
ECHO BOTH " While: unsetting backup endpoint state: " $STATE "\n";

select db.dba.soap_client (direction=>1, soap_action=>'initiate', style=>1, url=>concat ('http://localhost:', server_http_port(), '/BPELGUI/bpel.vsp?script=file:/While.bpel'), operation =>'initiate', parameters =>  vector ('par1', xtree_doc ('<value>2</value>')));
ECHO BOTH $IF $EQU $STATE OK "PASSED:" "***FAILED:";
ECHO BOTH " While [ with connection error ] initiate state: " $STATE "\n";

sleep 20;

select max (bi_state) from BPEL.BPEL.instance, BPEL.BPEL.script where bs_id = bi_script and bs_uri = 'file:/While.bpel';
ECHO BOTH $IF $EQU $LAST[1] 4 "PASSED:" "***FAILED:";
ECHO BOTH " While [ with connection error ] is in frozen state: " $LAST[1] "\n";

select db.dba.soap_client (direction=>1, soap_action=>'initiate', style=>1, url=>concat ('http://localhost:', server_http_port(), '/BPELGUI/bpel.vsp?script=file:/Restart.bpel'), operation =>'initiate', parameters =>  vector ('par1', xtree_doc ('<value>10</value>')));
ECHO BOTH $IF $EQU $STATE OK "PASSED:" "***FAILED:";
ECHO BOTH " Restart initiate state: " $STATE "\n";

sleep 10;

