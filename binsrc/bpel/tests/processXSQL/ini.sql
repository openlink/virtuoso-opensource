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
create table Demo.demo.Products (ProductId int, ProductName varchar);
insert into Demo.demo.Products values (1, 'unknown');
insert into Demo.demo.Products values (9, 'Mishi Kobe Niku');



select BPEL.BPEL.upload_script ('file://processXSQL', 'XSQLSample.bpel', 'XSQLSample.wsdl');
ECHO BOTH " XSQLSample upload:" $LAST[1] "\n";

select count (*) from BPEL.BPEL.script where bs_uri like '%XSQLSample.bpel';
ECHO BOTH $IF $EQU $LAST[1] "1" "PASSED:" "***FAILED:";
ECHO BOTH " XSQLSample.bpel script upload status:" $LAST[1] "\n";

select xpath_eval ('/ROWSET/ROW/productname/text()', xml_tree_doc (db.dba.soap_client (url=>sprintf ('http://localhost:%s/BPELGUI/bpel.vsp?script=file://processXSQL/XSQLSample.bpel',server_http_port()), style=>1, soap_action=>'initiate', operation=>'initiate', parameters =>  vector ('par1', xtree_doc ('<n0:id xmlns:n0="http://samples.openlinksw.com/bpel" type="int">9</n0:id>')))));
ECHO BOTH $IF $EQU $LAST[1] "Mishi Kobe Niku" "PASSED:" "***FAILED:";
ECHO BOTH " XSQLSample invoke: " $LAST[1] "\n";



