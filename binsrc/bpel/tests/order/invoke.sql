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
 select xpath_eval ('//orderItemsResponse/orderItemResponse[1]//itemNo/text()',xml_tree_doc( db.dba.soap_client (         direction=>0,         url=>sprintf ('http://localhost:%s/BPELGUI/bpel.vsp?script=file:/order/order.bpel',server_http_port() ),         soap_action=>'initiate',         operation=>'initiate',         parameters =>         vector ('par1',                 xtree_doc (file_to_string (http_root () || '/order/input.xml'))), style=>1) ));

ECHO BOTH $IF $EQU $LAST[1] "1" "PASSED:" "***FAILED:";
ECHO BOTH " Order test returns returns for itemNo[1] " $LAST[1] "\n";

 select xpath_eval ('//orderItemsResponse/orderItemResponse[2]//itemNo/text()',xml_tree_doc( db.dba.soap_client (         direction=>0,         url=>sprintf ('http://localhost:%s/BPELGUI/bpel.vsp?script=file:/order/order.bpel',server_http_port() ),         soap_action=>'initiate',         operation=>'initiate',         parameters =>         vector ('par1',                 xtree_doc (file_to_string (http_root () || '/order/input.xml'))), style=>1) ));
ECHO BOTH $IF $EQU $LAST[1] "2" "PASSED:" "***FAILED:";
ECHO BOTH " Order test returns returns for itemNo[2] " $LAST[1] "\n";

 select xpath_eval ('//orderItemsResponse/orderItemResponse[3]//itemNo/text()',xml_tree_doc( db.dba.soap_client (         direction=>0,         url=>sprintf ('http://localhost:%s/BPELGUI/bpel.vsp?script=file:/order/order.bpel',server_http_port() ),         soap_action=>'initiate',         operation=>'initiate',         parameters =>         vector ('par1',                 xtree_doc (file_to_string (http_root () || '/order/input.xml'))), style=>1) ));
ECHO BOTH $IF $EQU $LAST[1] "3" "PASSED:" "***FAILED:";
ECHO BOTH " Order test returns returns for itemNo[3] " $LAST[1] "\n";
