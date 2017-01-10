--  
--  $Id$
--  
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--  
--  Copyright (C) 1998-2017 OpenLink Software
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

drop table event_test_1;
drop table event_test_2;

create table event_test_1 (id int identity primary key, dt varchar);
create table event_test_2 (id int identity primary key, dt varchar);

delete from bpel..script where bs_name in ('Event', 'AsyncBPELService');

create procedure upload_async_process ()
{
  declare id any;
  bpel..import_script ('file:/tevent/AsyncBPELService/bpel.xml', 'AsyncBPELService', id);
  bpel..compile_script (id, '/AsyncBPELService');
};

create procedure upload_event_process ()
{
  declare id any;
  bpel..import_script ('file:/tevent/bpel.xml', 'Event', id);
  bpel..compile_script (id, '/Event');
};

upload_async_process ();
ECHO BOTH $IF $EQU $STATE OK  "PASSED:" "***FAILED:";
ECHO BOTH " AsyncBPELService created : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

upload_event_process ();
ECHO BOTH $IF $EQU $STATE OK  "PASSED:" "***FAILED:";
ECHO BOTH " Event process created : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select xpath_eval ('//loanApplication/loanAmount/text()', xml_tree_doc  (
	db.dba.soap_client (url=>sprintf ('http://localhost:%s/Event',
	    server_http_port()),
	  soap_action=>'initiate', operation=>'initiate',
	  parameters =>  vector ('par0', xtree_doc (
	'<loanApplication xmlns="http://www.autoloan.com/ns/autoloan">
	    <SSN>1234567890</SSN>
	    <email>a@a.com</email>
	    <customerName>joe doe</customerName>
	    <loanAmount>10000</loanAmount>
	    <carModel>zaz</carModel>
	    <carYear>1960</carYear>
	    <creditRating/>
	</loanApplication>')),
	  style=>1,
	  time_out=>180
	  )));

ECHO BOTH $IF $EQU $LAST[1] 10000  "PASSED:" "***FAILED:";
ECHO BOTH " Event returns " $LAST[1] "\n";

select count(*) from event_test_1;
ECHO BOTH $IF $EQU $LAST[1] 0  "PASSED:" "***FAILED:";
ECHO BOTH " event_test_1 contains " $LAST[1] "\n";

select count(*) from event_test_2;
ECHO BOTH $IF $EQU $LAST[1] 0  "PASSED:" "***FAILED:";
ECHO BOTH " event_test_2 contains " $LAST[1] "\n";

select xpath_eval ('//loanApplication/loanAmount/text()', xml_tree_doc  (
	db.dba.soap_client (url=>sprintf ('http://localhost:%s/Event',
	    server_http_port()),
	  soap_action=>'initiate', operation=>'initiate',
	  parameters =>  vector ('par0', xtree_doc (
	'<loanApplication xmlns="http://www.autoloan.com/ns/autoloan">
	    <SSN>9234567890</SSN>
	    <email>a@a.bar</email>
	    <customerName>joe doe</customerName>
	    <loanAmount>100000</loanAmount>
	    <carModel>bmw</carModel>
	    <carYear>2003</carYear>
	    <creditRating/>
	</loanApplication>')),
	  style=>1,
	  time_out=>180
	  )));
ECHO BOTH $IF $EQU $LAST[1] 100000  "PASSED:" "***FAILED:";
ECHO BOTH " Event returns " $LAST[1] "\n";

select count(*) from event_test_1;
ECHO BOTH $IF $EQU $LAST[1] 2  "PASSED:" "***FAILED:";
ECHO BOTH " event_test_1 contains " $LAST[1] "\n";

select dt from event_test_2;
ECHO BOTH $IF $EQU $LAST[1] 'Alarm timeout: no response from AsyncBPELService after 15 seconds'  "PASSED:" "***FAILED:";
ECHO BOTH " event_test_2 record " $LAST[1] "\n";

select count(*) from event_test_2;
ECHO BOTH $IF $EQU $LAST[1] 1  "PASSED:" "***FAILED:";
ECHO BOTH " event_test_2 contains " $LAST[1] "\n";

select dt from event_test_1;
ECHO BOTH $IF $EQU $LAST[1] 'we will finish processing your request soon'  "PASSED:" "***FAILED:";
ECHO BOTH " event_test_1 2-d record " $LAST[1] "\n";
