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
drop table bpel..comp4_test;
drop table bpel..comp5_test;
drop table bpel..comp6_test;

create table bpel..comp4_test (id int identity primary key, dt varchar);
create table bpel..comp5_test (id int identity primary key, dt varchar);
create table bpel..comp6_test (id int identity primary key, dt varchar);

delete from bpel..comp4_test;
delete from bpel..comp5_test;
delete from bpel..comp6_test;

delete from bpel..script where bs_name = 'file:/mix/comp4.bpel';
delete from bpel..script where bs_name = 'file:/mix/comp5.bpel';
delete from bpel..script where bs_name = 'file:/mix/comp6.bpel';

select BPEL.BPEL.upload_script ('file:/mix/', 'comp4.bpel', 'fault.wsdl');
ECHO BOTH $IF $EQU $LAST[1] NULL  "PASSED:" "***FAILED:";
ECHO BOTH " comp4 script upload error status:" $LAST[1] "\n";

select BPEL.BPEL.upload_script ('file:/mix/', 'comp5.bpel', 'fault.wsdl');
ECHO BOTH $IF $EQU $LAST[1] NULL  "PASSED:" "***FAILED:";
ECHO BOTH " comp5 script upload error status:" $LAST[1] "\n";

select BPEL.BPEL.upload_script ('file:/mix/', 'comp6.bpel', 'fault.wsdl');
ECHO BOTH $IF $EQU $LAST[1] NULL  "PASSED:" "***FAILED:";
ECHO BOTH " comp6 script upload error status:" $LAST[1] "\n";

select xpath_eval ('//*[1]/text()', xml_tree_doc  ( db.dba.soap_client (url=>sprintf ('http://localhost:%s/BPELGUI/bpel.vsp?script=file:/mix/comp4.bpel',server_http_port()), soap_action=>'echo', operation=>'echo', parameters =>  vector ('echoString', 'hello world')) ));
ECHO BOTH $IF $EQU $LAST[1] 'Comp4'  "PASSED:" "***FAILED:";
ECHO BOTH " Compensate 4 returns " $LAST[1] "\n";

select xpath_eval ('//*[1]/text()', xml_tree_doc  ( db.dba.soap_client (url=>sprintf ('http://localhost:%s/BPELGUI/bpel.vsp?script=file:/mix/comp5.bpel',server_http_port()), soap_action=>'echo', operation=>'echo', parameters =>  vector ('echoString', 'hello world')) ));
ECHO BOTH $IF $EQU $LAST[1] 'Comp5'  "PASSED:" "***FAILED:";
ECHO BOTH " Compensate 5 returns " $LAST[1] "\n";

select xpath_eval ('//*[1]/text()', xml_tree_doc  ( db.dba.soap_client (url=>sprintf ('http://localhost:%s/BPELGUI/bpel.vsp?script=file:/mix/comp6.bpel',server_http_port()), soap_action=>'echo', operation=>'echo', parameters =>  vector ('echoString', 'hello world')) ));
ECHO BOTH $IF $EQU $LAST[1] 'Comp6'  "PASSED:" "***FAILED:";
ECHO BOTH " Compensate 6 returns " $LAST[1] "\n";

-- check result from comp4

select dt from bpel..comp4_test where id = 1;
ECHO BOTH $IF $EQU $LAST[1] 'outer compensating 2'  "PASSED:" "***FAILED:";
ECHO BOTH " Compensate 4 script 1-st compensated " $LAST[1] "\n";


select dt from bpel..comp4_test where id = 2;
ECHO BOTH $IF $EQU $LAST[1] 'inner compensating 1'  "PASSED:" "***FAILED:";
ECHO BOTH " Compensate 4 script 2-d  compensated " $LAST[1] "\n";

select dt from bpel..comp4_test where id = 3;
ECHO BOTH $IF $EQU $LAST[1] 'error catched'  "PASSED:" "***FAILED:";
ECHO BOTH " Compensate 4 script fault catched " $LAST[1] "\n";

-- check result from comp5
select dt from bpel..comp5_test where id = 2;
ECHO BOTH $IF $EQU $LAST[1] 'inner compensating 2 2'  "PASSED:" "***FAILED:";
ECHO BOTH " Compensate 5 script 1-st compensated " $LAST[1] "\n";


select dt from bpel..comp5_test where id = 3;
ECHO BOTH $IF $EQU $LAST[1] 'inner compensating 2 1'  "PASSED:" "***FAILED:";
ECHO BOTH " Compensate 5 script 2-d  compensated " $LAST[1] "\n";

select dt from bpel..comp5_test where id = 1;
ECHO BOTH $IF $EQU $LAST[1] 'error catched'  "PASSED:" "***FAILED:";
ECHO BOTH " Compensate 5 script fault catched " $LAST[1] "\n";

-- check result from comp6
select dt from bpel..comp6_test where id = 2;
ECHO BOTH $IF $EQU $LAST[1] 'compensating scope-2: 1'  "PASSED:" "***FAILED:";
ECHO BOTH " Compensate 6 script scope-2 is compensated by name " $LAST[1] "\n";


select count(*) from bpel..comp6_test;
ECHO BOTH $IF $EQU $LAST[1] 2  "PASSED:" "***FAILED:";
ECHO BOTH " Compensate 6 two records in test table (scope-3 is not compensated) " $LAST[1] "\n";

select dt from bpel..comp6_test where id = 1;
ECHO BOTH $IF $EQU $LAST[1] 'error catched'  "PASSED:" "***FAILED:";
ECHO BOTH " Compensate 6 script fault catched " $LAST[1] "\n";

