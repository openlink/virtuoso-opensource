--  
--  $Id$
--  
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--  
--  Copyright (C) 1998-2014 OpenLink Software
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
BPEL.BPEL.upload_script ('file://pick1','pick1.bpel','pick1.wsdl');

ECHO BOTH $IF $EQU $STATE OK  "PASSED:" "***FAILED:";
ECHO BOTH " pick1 script upload status:" $STATE "\n";

select  xpath_eval ('/address/name/text()', xml_tree_doc (DB.DBA.soap_client (url=>sprintf ('http://localhost:%s/BPELGUI/bpel.vsp?script=file://pick1/pick1.bpel',server_http_port()), operation=>'getAddress', soap_action=>'getAddress', parameters=> vector ('par', xtree_doc ('<email>test_a_yahoo.com</email>')))));
ECHO BOTH $IF $EQU $LAST[1] "Dave" "PASSED:" "***FAILED:";
ECHO BOTH " pick1 result: " $LAST[1] "\n";

select  xpath_eval ('/creditCard/number/text()', xml_tree_doc (DB.DBA.soap_client (url=>sprintf ('http://localhost:%s/BPELGUI/bpel.vsp?script=file://pick1/pick1.bpel',server_http_port()), operation=>'getCreditCard', soap_action=>'getCreditCard', parameters=> vector ('par', xtree_doc ('<email>test_a_yahoo.com</email>')))));
ECHO BOTH $IF $EQU $LAST[1] "1234567890123456" "PASSED:" "***FAILED:";
ECHO BOTH " pick1 result: " $LAST[1] "\n";
