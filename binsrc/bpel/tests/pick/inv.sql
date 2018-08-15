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

select db.dba.soap_client (
		direction=>1,
		url=>sprintf ('http://localhost:%s/BPELGUI/bpel.vsp?script=file:/pick/pick.bpel', server_http_port()),
		soap_action=>'#initiate',
		operation=>'initiate',
		style=>1,
		parameters =>  vector ('par1', xtree_doc ('<loanApplication xmlns="http://www.autoloan.com/ns/autoloan"><SSN>12345QQ</SSN><email>bgates_AT_microsoft.com</email><customerName>Billy G.</customerName><loanAmount>15000.00</loanAmount><carModel>Mazda 3</carModel><carYear>2003</carYear><creditRating>12</creditRating></loanApplication>')),
		headers=> vector ('part1', xtree_doc ('<wsa:ReplyTo xmlns:wsa="http://schemas.xmlsoap.org/ws/2003/03/addressing"><wsa:Address>http://localhost:' || server_http_port() || '/pick</wsa:Address></wsa:ReplyTo>'))
		);

ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": call /pick.bpel state: " $STATE "\n";

select db.dba.soap_client (
		direction=>1,
		url=>sprintf ('http://localhost:%s/BPELGUI/bpel.vsp?script=file:/pick/pick.bpel', server_http_port()),
		soap_action=>'#initiate',
		operation=>'initiate',
		style=>1,
		parameters =>  vector ('par1', xtree_doc ('<loanApplication xmlns="http://www.autoloan.com/ns/autoloan"><SSN>12345QQ</SSN><email>bgates_AT_microsoft.com</email><customerName>Billy G.</customerName><loanAmount>15000.00</loanAmount><carModel>Mazda 3</carModel><carYear>2003</carYear><creditRating>12</creditRating></loanApplication>')),
		headers=> vector ('part1', xtree_doc ('<wsa:ReplyTo xmlns:wsa="http://schemas.xmlsoap.org/ws/2003/03/addressing"><wsa:Address>http://localhost:' || server_http_port() || '/pick</wsa:Address></wsa:ReplyTo>'))
		);

ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": call /pick.bpel state: " $STATE "\n";

select db.dba.soap_client (
		direction=>1,
		url=>sprintf ('http://localhost:%s/BPELGUI/bpel.vsp?script=file:/pick/pick.bpel', server_http_port()),
		soap_action=>'#initiate',
		operation=>'initiate',
		style=>1,
		parameters =>  vector ('par1', xtree_doc ('<loanApplication xmlns="http://www.autoloan.com/ns/autoloan"><SSN>12345QQ</SSN><email>bgates_AT_microsoft.com</email><customerName>Billy G.</customerName><loanAmount>15000.00</loanAmount><carModel>Mazda 3</carModel><carYear>2003</carYear><creditRating>12</creditRating></loanApplication>')),
		headers=> vector ('part1', xtree_doc ('<wsa:ReplyTo xmlns:wsa="http://schemas.xmlsoap.org/ws/2003/03/addressing"><wsa:Address>http://localhost:' || server_http_port() || '/pick</wsa:Address></wsa:ReplyTo>'))
		);

ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": call /pick.bpel state: " $STATE "\n";

delay (10);

select * from PICK..onResult;

ECHO BOTH $IF $EQU $ROWCNT 3 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Rows in PICK..onResult: " $ROWCNT "\n";

create procedure ASVC..initiate (
	in loanApplication any __soap_type 'http://www.autoloan.com/ns/autoloan:loanApplication',
	in "ReplyTo" any := null __soap_header 'http://schemas.xmlsoap.org/ws/2003/03/addressing:ReplyTo',
	in "MessageID" any := null __soap_header 'http://schemas.xmlsoap.org/ws/2003/03/addressing:MessageID'
	) __soap_doc '__VOID__'
{
  declare url any;
  url := get_keyword ('Address', coalesce ("ReplyTo", vector ()));
  dbg_obj_print ('Application:', loanApplication);
  http_request_status ('HTTP/1.1 202 Accepted');
  http_flush ();
  delay (5);
  dbg_printf ('sending reponse for : %s', url);
  declare exit handler for sqlstate '*' {
    dbg_obj_print (__SQL_MESSAGE);
  };
  DB.DBA.SOAP_CLIENT (direction=>1,
  		url=>cast (url as varchar),
		style=>1,
  		operation=>'onResult',
  		parameters =>  vector (vector ('loanApplication' , 'http://www.autoloan.com/ns/autoloan:loanApplication_resp') , loanApplication),
		headers => ASVC..wsa_hdr ("MessageID")
  	);
  return;
}
;

grant execute on ASVC..initiate to ASVC;

ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": reload procedure ASVC..initiate state: " $STATE "\n";

select db.dba.soap_client (
		direction=>1,
		url=>sprintf ('http://localhost:%s/BPELGUI/bpel.vsp?script=file:/pick/pick.bpel', server_http_port()),
		soap_action=>'#initiate',
		operation=>'initiate',
		style=>1,
		parameters =>  vector ('par1', xtree_doc ('<loanApplication xmlns="http://www.autoloan.com/ns/autoloan"><SSN>12345QQ</SSN><email>bgates_AT_microsoft.com</email><customerName>Billy G.</customerName><loanAmount>15000.00</loanAmount><carModel>Mazda 3</carModel><carYear>2003</carYear><creditRating>12</creditRating></loanApplication>')),
		headers=> vector ('part1', xtree_doc ('<wsa:ReplyTo xmlns:wsa="http://schemas.xmlsoap.org/ws/2003/03/addressing"><wsa:Address>http://localhost:' || server_http_port() || '/pick</wsa:Address></wsa:ReplyTo>'))
		);

ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": call /pick.bpel state: " $STATE "\n";

delay (10);

select * from PICK..onResult;

ECHO BOTH $IF $EQU $ROWCNT 3 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Rows in PICK..onResult: " $ROWCNT "\n";

select * from BPEL.BPEL.pick_fault;

ECHO BOTH $IF $EQU $ROWCNT 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Rows in pick_fault: " $ROWCNT "\n";
