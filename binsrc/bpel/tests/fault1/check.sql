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
--BPEL..restart_all_instances ();
--ECHO BOTH $IF $EQU $STATE OK "PASSED:" "***FAILED:";
--ECHO BOTH " Restart all intstances state: " $STATE "\n";

sleep 30;
select val from DB.DBA.restart_test;
ECHO BOTH $IF $EQU $LAST[1] "PASSED:" "PASSED:" "***FAILED:";
ECHO BOTH " Restart script produced: " $LAST[1] "\n";

select count (*) from BPEL.BPEL.instance where bi_state < 2;
ECHO BOTH $IF $EQU $LAST[1] "0" "PASSED:" "***FAILED:";
ECHO BOTH " Number of instances running: " $LAST[1] "\n";

select count (*) from BPEL.BPEL.instance where bi_state = 3;
ECHO BOTH $IF $EQU $LAST[1] "0" "PASSED:" "***FAILED:";
ECHO BOTH " Number of instances aborted: " $LAST[1] "\n";

BPEL.BPEL.wsdl_process_remote ('IncrementService', sprintf ('http://localhost:%s/incsvcwsdl.vsp', '$U{http_port_two}'),         'file:/While.bpel');
ECHO BOTH $IF $Equ $sTATE OK "PASSED:" "***FAILED:";
ECHO BOTH " IncrementService processed for While state: " $STATE "\n";


