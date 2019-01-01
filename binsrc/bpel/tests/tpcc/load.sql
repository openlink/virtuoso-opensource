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
select BPEL.BPEL.upload_script ('file:/bpeltpcc/', 'Sut.bpel','Sut.wsdl');
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
ECHO BOTH " upload_script Sut.bpel status:" $STATE "\n";

BPEL..wsdl_process_remote ('db', 'file:/bpeltpcc/dbservices.wsdl', 'file:/bpeltpcc/Sut.bpel');
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
ECHO BOTH " wsdl_process_remote dbservices status:" $STATE "\n";

BPEL..wsdl_process_remote ('TestDrive', 'file:/bpeltpcc/tdservices.wsdl', 'file:/bpeltpcc/Sut.bpel');
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
ECHO BOTH " wsdl_process_remote TestDrive status:" $STATE "\n";


-- Values for the Configuration partner links
--for Test Driver: http://leon:8883/DAV/t/tdservices.wsdl
--for Database Driver: http://leon:8882/DAV/test/dbservices.wsdl
