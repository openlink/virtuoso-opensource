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
BPEL.BPEL.upload_script ('file://echo','echo.bpel','echo.wsdl');

select count (bs_uri) from BPEL.BPEL.script;
ECHO BOTH $IF $EQU $LAST[1] "1" "PASSED:" "***FAILED:";
ECHO BOTH " ECHO script has been uploaded:" $LAST[1] "\n";

select  xpath_eval ('/echoResponse/echoString/text()',
	xml_tree_doc (
		DB.DBA.soap_client (
		url=>sprintf ('http://localhost:%s/BPELGUI/bpel.vsp?script=file://echo/echo.bpel',server_http_port()),
		operation=>'echo',
		soap_action=>'echo',
		parameters=> vector ('par', xtree_doc ('<echoString>hello world</echoString>')))
		));
ECHO BOTH $IF $EQU $LAST[1] "hello world" "PASSED:" "***FAILED:";
ECHO BOTH " ECHO returns " $LAST[1] " word\n";

select count (bi_error) from BPEL.BPEL.instance where bi_error is not null;
ECHO BOTH $IF $EQU $LAST[1] 0  "PASSED:" "***FAILED:";
ECHO BOTH $LAST[1] " errors found" "\n";

