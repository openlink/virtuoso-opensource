--  
--  $Id: byteorder.sql,v 1.3.10.1 2013/01/02 16:14:38 source Exp $
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


select count(*) from "Demo.demo.Orders";
ECHO BOTH $IF $EQU $LAST[1] 830 "PASSED" "***FAILED";
ECHO BOTH ": Demo.demo.Orders contains " $LAST[1] " rows\n";

select count(*) from "Demo.demo.Order_Details";
ECHO BOTH $IF $EQU $LAST[1] 2155 "PASSED" "***FAILED";
ECHO BOTH ": Demo.demo.Order_Details " $LAST[1] " rows\n";

backup '/dev/null';
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": BACKUP STATE: " $STATE "\n";

create procedure check_dav_blobs(in name_ varchar, in l_ integer)
{
	for select res_name, length (res_content) as res_length, res_content from WS.WS.SYS_DAV_RES 
		where res_name = name_ do {
		  if ( l_ <> res_length)
		     {
		        signal ('DAVE', 'the size of dav content is wrong');
		     }
		  string_to_file ('fc.xml', cast (res_content as varchar), -1);
		  return 'OK';
	}
	signal ('DAVE', 'wrong dav name');
}

set blobs on;

select check_dav_blobs ('errors.xml', 246899);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": BACKUP STATE: " $STATE "\n";

select check_dav_blobs ('virtclientref.xml',208219);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": BACKUP STATE: " $STATE "\n";

select check_dav_blobs ('vspxdoc.xml',                                                                       169146);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": BACKUP STATE: " $STATE "\n";

select check_dav_blobs ('dbpoolx.mod',                                                                       205277);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": BACKUP STATE: " $STATE "\n";

select check_dav_blobs ('vspconcept.jpg',                                                                    131136);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": BACKUP STATE: " $STATE "\n";

select check_dav_blobs ('vspxconcept.jpg',                                                                   139565);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": BACKUP STATE: " $STATE "\n";

select check_dav_blobs ('errors.html',                                                                       280786);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": BACKUP STATE: " $STATE "\n";

select check_dav_blobs ('functionidx.html',                                                                  247423);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": BACKUP STATE: " $STATE "\n";

select check_dav_blobs ('virtclientref.html',                                                                182111);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": BACKUP STATE: " $STATE "\n";

select check_dav_blobs ('vspconcept.jpg',                                                                    131136);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": BACKUP STATE: " $STATE "\n";

select check_dav_blobs ('vspxconcept.jpg',                                                                   139565);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": BACKUP STATE: " $STATE "\n";

select check_dav_blobs ('factbook.xml',                                                                      4222646);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": BACKUP STATE: " $STATE "\n";


