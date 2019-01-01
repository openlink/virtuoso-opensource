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
use bpel;
drop table evcomp_test_1;
drop table evcomp_test_2;

create table evcomp_test_1  (id int identity primary key, seq int);
create table evcomp_test_2  (id int identity primary key, seq int);

use DB;
create user TESTSVC;


vhost_define (lpath=>'/TSvc', ppath=>'/SOAP/', soap_user=>'TESTSVC', soap_opts=>vector ('Use', 'literal', 'GeneratePartnerLink', 'yes', 'Namespace', 'http://temp.org', 'SchemaNS', 'http://temp.org', 'ServiceName', 'TestService'));

create procedure TESTSVC..Test (in Seq int) returns int
{
  dbg_obj_print ('Test', Seq);
  insert into bpel..evcomp_test_1 (seq) values (Seq);
  if (Seq > 3)
    {
      DB.DBA.SOAP_CLIENT (direction=>1,
  		url=>'http://localhost:'||server_http_port ()||'/BPELGUI/bpel.vsp?script=file:/mix/evcomp.bpel',
  		operation=>'onEvent',
  		soap_action=>'onEvent',
		style=>1,
  		parameters =>  vector ('par0' ,
			xtree_doc ('<event xmlns="http://temp.org">Cancel the rest</event>'))
  	);
    }
  delay (1);
  return Seq;
}
;

create procedure TESTSVC..TestCancel (in Seq int) returns int
{
  dbg_obj_print ('Test', Seq);
  insert into bpel..evcomp_test_2 (seq) values (Seq);
  return Seq;
}
;

grant execute on TESTSVC..Test to TESTSVC;
grant execute on TESTSVC..TestCancel to TESTSVC;

use bpel;
delete from script where bs_name = 'file:/mix/evcomp.bpel';

select BPEL.BPEL.upload_script ('file:/mix/', 'evcomp.bpel', 'evcomp.wsdl');
ECHO BOTH $IF $EQU $LAST[1] NULL  "PASSED:" "***FAILED:";
ECHO BOTH " evcomp script upload error status:" $LAST[1] "\n";

BPEL.BPEL.wsdl_process_remote ('svc',         'file:/mix/tsvc.wsdl',         'file:/mix/evcomp.bpel');
ECHO BOTH $IF $EQU $STATE OK  "PASSED:" "***FAILED:";
ECHO BOTH " evcomp script pl status:" $STATE "\n";

select  xpath_eval ('//result/text()',
	xml_tree_doc (
		DB.DBA.soap_client (
		url=>sprintf ('http://localhost:%s/BPELGUI/bpel.vsp?script=file:/mix/evcomp.bpel',
		  server_http_port()),
		operation=>'initiate',
		soap_action=>'initiate',
		parameters=> vector ('par', xtree_doc ('<request>123</request>')))
		));
ECHO BOTH $IF $NEQ $STATE OK  "PASSED:" "***FAILED:";
ECHO BOTH " Invoke of evcomp failed :" $STATE "\n";

select seq from bpel..evcomp_test_1 except select seq from bpel..evcomp_test_2;
ECHO BOTH $IF $EQU $ROWCNT 1  "PASSED:" "***FAILED:";
ECHO BOTH " records different " $ROWCNT "\n";

select max(seq)-1 from  bpel..evcomp_test_1 except select max(seq) from  bpel..evcomp_test_2;
ECHO BOTH $IF $EQU $ROWCNT 0  "PASSED:" "***FAILED:";
ECHO BOTH " nTestCancel = nTest - 1 " $ROWCNT "\n";
