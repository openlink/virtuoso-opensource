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
select BPEL.BPEL.upload_script ('file:/mix/','fault4.bpel','fault.wsdl');
ECHO BOTH $IF $EQU $LAST[1] NULL  "PASSED:" "***FAILED:";
ECHO BOTH " Fault4 script upload error status:" $LAST[1] "\n";

select BPEL.BPEL.upload_script ('file:/mix/','while1.bpel','while1.wsdl');
ECHO BOTH $IF $EQU $LAST[1] NULL  "PASSED:" "***FAILED:";
ECHO BOTH " While1 script upload error status:" $LAST[1] "\n";

select BPEL.BPEL.upload_script ('file:/mix/','sw.bpel','sw.wsdl');
ECHO BOTH $IF $EQU $LAST[1] NULL  "PASSED:" "***FAILED:";
ECHO BOTH " Switch script upload error status:" $LAST[1] "\n";

select BPEL.BPEL.upload_script ('file:/mix/','comp2.bpel','fault.wsdl');
ECHO BOTH $IF $EQU $LAST[1] NULL  "PASSED:" "***FAILED:";
ECHO BOTH " Compensate2 script upload error status:" $LAST[1] "\n";

select BPEL.BPEL.upload_script ('file:/mix/','comp3.bpel','fault.wsdl');
ECHO BOTH $IF $EQU $LAST[1] NULL  "PASSED:" "***FAILED:";
ECHO BOTH " Compensate3 script upload error status:" $LAST[1] "\n";

select xpath_eval ('//*[1]/text()',
	xml_tree_doc (db.dba.soap_client (
	url=>sprintf ('http://localhost:%s/BPELGUI/bpel.vsp?script=file:/mix/fault4.bpel',server_http_port()),
	soap_action=>'echo', operation=>'echo', parameters =>  vector ('echoString', 'hello world'),
	direction=>0)));
ECHO BOTH $IF $EQU $LAST[1] "Request is invalid" "PASSED:" "***FAILED:";
ECHO BOTH " Fault 4 test returns returns " $LAST[1] " word\n";

select xpath_eval ('//result/text()', xml_tree_doc ( db.dba.soap_client (direction=>0, soap_action=>'initiate', style=>1, url=>concat ('http://localhost:', server_http_port(), '/BPELGUI/bpel.vsp?script=file:/mix/while1.bpel'), operation =>'initiate', parameters =>  vector ('par1', xtree_doc ('<value>10</value>'))) ));
ECHO BOTH $IF $EQU $LAST[1] "10" "PASSED:" "***FAILED:";
ECHO BOTH " While1 test returns returns " $LAST[1] " \n";

-- call 3 times w/ 0 2 6
select xpath_eval ('//result/text()', xml_tree_doc ( db.dba.soap_client (direction=>0, soap_action=>'initiate', style=>1, url=>concat ('http://localhost:', server_http_port(), '/BPELGUI/bpel.vsp?script=file:/mix/sw.bpel'), operation =>'initiate', parameters =>  vector ('par1', xtree_doc ('<value>0</value>'))) ));
ECHO BOTH $IF $EQU $LAST[1] "3" "PASSED:" "***FAILED:";
ECHO BOTH " Switch test returns returns " $LAST[1] " for otherwise\n";

select xpath_eval ('//result/text()', xml_tree_doc ( db.dba.soap_client (direction=>0, soap_action=>'initiate', style=>1, url=>concat ('http://localhost:', server_http_port(), '/BPELGUI/bpel.vsp?script=file:/mix/sw.bpel'), operation =>'initiate', parameters =>  vector ('par1', xtree_doc ('<value>2</value>'))) ));
ECHO BOTH $IF $EQU $LAST[1] "2" "PASSED:" "***FAILED:";
ECHO BOTH " Switch test returns returns " $LAST[1] " for > 1\n";

select xpath_eval ('//result/text()', xml_tree_doc ( db.dba.soap_client (direction=>0, soap_action=>'initiate', style=>1, url=>concat ('http://localhost:', server_http_port(), '/BPELGUI/bpel.vsp?script=file:/mix/sw.bpel'), operation =>'initiate', parameters =>  vector ('par1', xtree_doc ('<value>6</value>'))) ));
ECHO BOTH $IF $EQU $LAST[1] "1" "PASSED:" "***FAILED:";
ECHO BOTH " Switch test returns returns " $LAST[1] " for > 5\n";


select xpath_eval ('//*[1]/text()', xml_tree_doc  ( db.dba.soap_client (url=>sprintf ('http://localhost:%s/BPELGUI/bpel.vsp?script=file:/mix/comp2.bpel',server_http_port()), soap_action=>'echo', operation=>'echo', parameters =>  vector ('echoString', 'hello world'), direction=>0) ));
ECHO BOTH $IF $EQU $LAST[1] "echo2" "PASSED:" "***FAILED:";
ECHO BOTH " Compensation 2 test returns returns " $LAST[1] " word\n";
