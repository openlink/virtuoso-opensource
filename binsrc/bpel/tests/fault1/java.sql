--  
--  $Id$
--  
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--  
--  Copyright (C) 1998-2016 OpenLink Software
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
select BPEL.BPEL.upload_script ('file://', 'java_exec.bpel', 'java_exec.wsdl');
ECHO BOTH " java_exec upload:" $LAST[1] "\n";
select count (*) from BPEL.BPEL.script where bs_uri like '%java_exec.bpel';
ECHO BOTH $IF $EQU $LAST[1] "1" "PASSED:" "***FAILED:";
ECHO BOTH " java_exec.bpel script upload status:" $LAST[1] "\n";

select  xpath_eval ('/destResponse/country/text()', xml_tree_doc (db.dba.soap_client (url=>sprintf ('http://localhost:%s/BPELGUI/bpel.vsp?script=file:/java_exec.bpel',server_http_port()), style=>1, soap_action=>'check_dest', operation=>'check_dest', parameters =>  vector ('par1', xtree_doc ('<destRequest xmlns="urn:echo:echoService"><city>ALA</city></destRequest>')))));
ECHO BOTH $IF $EQU $LAST[1] "KZ" "PASSED:" "***FAILED:";
ECHO BOTH " java_exec.bpel returns:" $LAST[1] "\n";
