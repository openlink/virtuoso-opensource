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
BPEL.BPEL.upload_script ('file://post','post.bpel','post.wsdl');

ECHO BOTH $IF $EQU $STATE OK  "PASSED:" "***FAILED:";
ECHO BOTH " post script upload status:" $STATE "\n";

select  xpath_eval ('/postResponse/result/text()', xml_tree_doc (DB.DBA.soap_client (direction=>1,style=>1,url=>sprintf ('http://localhost:%s/BPELGUI/bpel.vsp?script=file://post/post.bpel',server_http_port()), operation=>'process', soap_action=>'process', parameters=> vector ('par1', xtree_doc ('<postRequest xmlns="http://services.otn.com"><ssn>11aa</ssn><id>1</id></postRequest>')))));
ECHO BOTH $IF $EQU $LAST[1] "11aa,1" "PASSED:" "***FAILED:";
ECHO BOTH " post script result: " $LAST[1] "\n";
