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
DB.DBA.vhost_define (vhost=>'*ini*',lhost=>'*ini*',lpath=>'/BPELREQ/',ppath=>'/SOAP/',soap_user=>'DBA');
create table results (r any);

create procedure WS.DBA.initiate (in xmlLoanApp any)  __soap_options (__soap_doc := '__VOID__', DefaultOperation := 0)
{
        http_request_status ('HTTP/1.1 202 Accepted');
	http_flush ();
	insert into results values (xmlLoanApp); delay (10);
        db.dba.soap_client (direction=>1, url=>sprintf ('http://localhost:%s/BPELGUI/bpel.vsp?script=file://Flow/Flow.bpel', server_http_port()), operation=>'onResult', parameters =>  vector ('par1', xtree_doc ('<loanOffer><providerName>United Loan</providerName><selected>false</selected><approved>true</approved><APR>6.8</APR></loanOffer>')));
};

create user DBA2;

grant all privileges to DBA2;

DB.DBA.vhost_define (vhost=>'*ini*',lhost=>'*ini*',lpath=>'/BPELREQ2/',ppath=>'/SOAP/',soap_user=>'DBA2');

create table DB.DBA.results2 (r any);

create procedure WS.DBA2.initiate (in xmlLoanApp any)   __soap_options (__soap_doc := '__VOID__', DefaultOperation := 0)
{
        http_request_status ('HTTP/1.1 202 Accepted');
	http_flush ();
	insert into DB.DBA.results2 values (xmlLoanApp); delay (15);
        db.dba.soap_client (direction=>1, url=>sprintf ('http://localhost:%s/BPELGUI/bpel.vsp?script=file://Flow/Flow.bpel', server_http_port ()), operation=>'onResult', parameters =>  vector ('par1', xtree_doc ('<loanOffer><providerName>American  Loan</providerName><selected>false</selected><approved>true</approved><APR>5.4</APR></loanOffer>')));
};

upload_script ('file://Flow','Flow.bpel','Flow.wsdl');
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
ECHO BOTH " Flow script upload status:" $STATE "\n";

BPEL.BPEL.wsdl_process_remote ('AmericanLoanService',
	sprintf ('http://localhost:%s/BPELREQ/services.wsdl', '$U{req_http_port_one}'),
	'file://Flow/Flow.bpel');
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
ECHO BOTH " AmericanLoanService WSDL upload status:" $STATE "\n";

BPEL.BPEL.wsdl_process_remote ('UnitedLoanService',
	sprintf ('http://localhost:%s/BPELREQ2/services.wsdl', '$U{req_http_port_one}'),
	'file://Flow/Flow.bpel');
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
ECHO BOTH " UnitedLoanService WSDL upload status:" $STATE "\n";

create table BPEL.BPEL.resOnResult (
	res	any
)
;

create procedure BPEL.BPEL.onResult (in loanOffer any) __soap_options (__soap_doc := '__VOID__', DefaultOperation := 0)
{
	BPEL.BPEL.dbgprintf ('onResult is invoked:\n');
	BPEL.BPEL.obj_print (loanOffer);
	insert into BPEL.BPEL.resOnResult values (loanOffer);
}
;

ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
ECHO BOTH " Buyer script: onResult interceptor creation status:" $STATE "\n";

select db.dba.soap_client (direction=>1, url=>sprintf ('http://localhost:%s/BPELGUI/bpel.vsp?script=file://Flow/Flow.bpel',server_http_port() ), soap_action=>'initiate', operation=>'initiate', parameters =>  vector ('par1', xtree_doc ('<xmlLoanApp><SSN>12345QQ</SSN><Email>bgates_AT_microsoft.com</Email><CustomerName>Billy G.</CustomerName><LoanAmount>15000.00</LoanAmount><CarModel>Mazda 3</CarModel><CarYear>2003</CarYear><creditRating>12</creditRating></xmlLoanApp>')));

ECHO BOTH $IF $EQU $STATE OK  "PASSED:" "***FAILED";
ECHO BOTH " Buyer script: purchase operation status:" $STATE "\n";

sleep 90;

select * from BPEL.BPEL.resOnResult;
ECHO BOTH $IF $EQU $ROWCNT 1  "PASSED:" "***FAILED";
ECHO BOTH " The t2 test produced:" $ROWCNT "\n";

sleep 2;

select count (bi_last_error) from BPEL.BPEL.instance where bi_last_error is not null;
ECHO BOTH $IF $EQU $LAST[1] 0  "PASSED:" "***FAILED";
ECHO BOTH $LAST[1] " errors found" "\n";


