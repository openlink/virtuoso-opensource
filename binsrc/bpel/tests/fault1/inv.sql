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

select db.dba.soap_client (direction=>1, soap_action=>'initiate', style=>1, url=>concat ('http://localhost:', server_http_port(), '/BPELGUI/bpel.vsp?script=file:/While.bpel'), operation =>'initiate', parameters =>  vector ('par1', xtree_doc ('<value>5</value>')));
ECHO BOTH $IF $EQU $STATE OK "PASSED:" "***FAILED:";
ECHO BOTH " While [with connection error 3] state: " $STATE "\n";


