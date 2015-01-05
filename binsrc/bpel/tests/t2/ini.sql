--  
--  $Id$
--  
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--  
--  Copyright (C) 1998-2015 OpenLink Software
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
upload_script (sprintf ('http://localhost:%s/t2/',server_http_port()),'FlowSample.bpel','FlowSample.wsdl');
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
ECHO BOTH " FlowSample script upload status:" $STATE "\n";

create table resOnResult (
	res	any
)
;

create procedure BPEL.BPEL.onResult (in parameters any)
{
	dbg_printf ('onResult is invoked:\n');
	dbg_obj_print (parameters);
	insert into resOnResult values (parameters);
}
;
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
ECHO BOTH " Buyer script: onResult interceptor creation status:" $STATE "\n";

select dbg_obj_print (db.dba.soap_client (direction=>1, url=>sprintf ('http://localhost:%s/BPEL/FLOWSAMPLE',server_http_port() ), operation=>'initiate', parameters =>  vector ('par1', xtree_doc ('<parameters><xmlLoanApp><SSN>12345QQ</SSN><Email>bgates_AT_microsoft.com</Email><CustomerName>Billy G.</CustomerName><LoanAmount>15000.00</LoanAmount><CarModel>Mazda 3</CarModel><CarYear>2003</CarYear><CreditRating>12</CreditRating></xmlLoanApp></parameters>'))));

ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
ECHO BOTH " Buyer script: purchase operation status:" $STATE "\n";

sleep 5;

select * from resOnResult;
ECHO BOTH $IF $EQU $ROWCNT 3  "PASSED" "***FAILED";
ECHO BOTH " The t2 test produced:" $ROWCNT "\n";

		
select count (bi_last_error) from BPEL.BPEL.instance where bi_last_error is not null;
ECHO BOTH $IF $EQU $LAST[1] 0  "PASSED" "***FAILED";
ECHO BOTH $LAST[1] " errors found" "\n";

