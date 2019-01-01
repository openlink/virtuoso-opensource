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
trace_off();

select BPEL..upload_script ('file:/fi/','fi.bpel','fi.wsdl');
ECHO BOTH $IF $EQU $STATE OK  "PASSED:" "***FAILED:";
ECHO BOTH " FI sync script upload status:" $STATE "\n";
BPEL..wsdl_process_remote ('FiService', 'file:/fi/fi.wsdl', 'file:/fi/fi.bpel');
ECHO BOTH $IF $EQU $STATE OK  "PASSED:" "***FAILED:";
ECHO BOTH " FI sync PL status:" $STATE "\n";


select BPEL..upload_script ('file:/fi/','fia.bpel','fia.wsdl');
ECHO BOTH $IF $EQU $STATE OK  "PASSED:" "***FAILED:";
ECHO BOTH " FI1 async upload status:" $STATE "\n";
BPEL..wsdl_process_remote ('FiService', 'file:/fi/fia.wsdl', 'file:/fi/fia.bpel');
ECHO BOTH $IF $EQU $STATE OK  "PASSED:" "***FAILED:";
ECHO BOTH " FI1 async PL status:" $STATE "\n";


select BPEL..upload_script ('file:/fi/','fib.bpel','fib.wsdl');
ECHO BOTH $IF $EQU $STATE OK  "PASSED:" "***FAILED:";
ECHO BOTH " FI2 links script upload status:" $STATE "\n";
BPEL..wsdl_process_remote ('FiService', 'file:/fi/fib.wsdl', 'file:/fi/fib.bpel');
ECHO BOTH $IF $EQU $STATE OK  "PASSED:" "***FAILED:";
ECHO BOTH " FI2 links PL status:" $STATE "\n";

-- remove all in the queue
delete from BPEL..queue;

-- XXX: this is a cludge because currently messages & assigment are not working correctly
update BPEL..remote_operation set ro_style = 1 where ro_operation = 'onResult' and ro_style is null and
	ro_script in (select bs_id from BPEL..script where bs_uri like 'file:/fi/%');

create user FIA;

db..vhost_remove (lpath=>'/fia');
db..vhost_define (lpath=>'/fia', ppath=>'/SOAP/', soap_user => 'FIA');

create table FIA..onResult (res int);

create table FIB..onResult (res int);

db..soap_dt_define ('', '<xsd:element name="result" type="xsd:int" targetNamespace="http://temp.org" xmlns:xsd="http://www.w3.org/2001/XMLSchema"/>');

create procedure FIA..onResult (in result any __soap_type 'http://temp.org:result') __soap_doc '__VOID__'
{
  http_request_status ('HTTP/1.1 202 Accepted');
  http_flush ();
  dbg_obj_print (result);
  insert into FIA..onResult values (result);
}
;

grant execute on FIA..onResult to FIA
;

create user FIB;

db..vhost_remove (lpath=>'/fib');
db..vhost_define (lpath=>'/fib', ppath=>'/SOAP/', soap_user => 'FIB');

create procedure FIB..onResult (in result any __soap_type 'http://temp.org:result') __soap_doc '__VOID__'
{
  http_request_status ('HTTP/1.1 202 Accepted');
  http_flush ();
  dbg_obj_print (result);
  insert into FIB..onResult values (result);
}
;

grant execute on FIB..onResult to FIB
;



select xpath_eval ('//result/text()', xml_tree_doc (db.dba.soap_client (
	direction=>0,
	style=>1,
	url=>concat ('http://localhost:', server_http_port(), '/BPELGUI/bpel.vsp?script=file:/fi/fi.bpel'),
	operation =>'initiate',
	parameters =>  vector ('par1', xtree_doc ('<value xmlns="http://temp.org">5</value>'))
	)));
ECHO BOTH $IF $EQU $LAST[1] 5 "PASSED:" "***FAILED:";
ECHO BOTH " FI test returns returns " $LAST[1] "\n";

select xpath_eval ('//result/text()', xml_tree_doc (db.dba.soap_client (
	direction=>1,
	style=>1,
	url=>concat ('http://localhost:', server_http_port(), '/BPELGUI/bpel.vsp?script=file:/fi/fia.bpel'),
	operation =>'initiate',
	headers=> vector ('part1', xtree_doc ('<wsa:ReplyTo xmlns:wsa="http://schemas.xmlsoap.org/ws/2003/03/addressing"><wsa:Address>http://localhost:'||server_http_port()||'/fia</wsa:Address></wsa:ReplyTo>')),
	parameters =>  vector ('par1', xtree_doc ('<value xmlns="http://temp.org">5</value>'))
	)));

delay (15);

select res from  FIA..onResult;

ECHO BOTH $IF $EQU $LAST[1] 5 "PASSED:" "***FAILED:";
ECHO BOTH " FI1 test returns returns " $LAST[1] "\n";

select xpath_eval ('//result/text()', xml_tree_doc (db.dba.soap_client (
	direction=>1,
	style=>1,
	url=>concat ('http://localhost:', server_http_port(), '/BPELGUI/bpel.vsp?script=file:/fi/fib.bpel'),
	operation =>'initiate',
	headers=> vector ('part1', xtree_doc ('<wsa:ReplyTo xmlns:wsa="http://schemas.xmlsoap.org/ws/2003/03/addressing"><wsa:Address>http://localhost:'||server_http_port()||'/fib</wsa:Address></wsa:ReplyTo>')),
	parameters =>  vector ('par1', xtree_doc ('<value xmlns="http://temp.org">5</value>'))
	)));

delay (15);

select res from  FIB..onResult;

ECHO BOTH $IF $EQU $LAST[1] 5 "PASSED:" "***FAILED:";
ECHO BOTH " FI2 test returns returns " $LAST[1] "\n";
