--  
--  $Id$
--  
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--  
--  Copyright (C) 1998-2012 OpenLink Software
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
use DB;

select U_NAME from SYS_USERS where U_NAME = 'ASVC';
$IF $EQU $ROWCNT 1 "" "create user ASVC";

create procedure ASVC..wsa_hdr (in mid1 any)
{
  declare wsa_rel, mid, id any;

  mid := coalesce (mid1, vector (null, null, null));

  id := mid[2];

  if (id is null)
    return null;

  wsa_rel := vector (composite (), '', id);
  return vector (
            vector ('RelatesTo', 'http://schemas.xmlsoap.org/ws/2003/03/addressing:RelatesTo'), wsa_rel
	);
}
;


create procedure ASVC..initiate (
	in loanApplication any __soap_type 'http://www.autoloan.com/ns/autoloan:loanApplication',
	in "ReplyTo" any := null __soap_header 'http://schemas.xmlsoap.org/ws/2003/03/addressing:ReplyTo',
	in "MessageID" any := null __soap_header 'http://schemas.xmlsoap.org/ws/2003/03/addressing:MessageID'
	) __soap_doc '__VOID__'
{
  declare url any;
  url := get_keyword ('Address', coalesce ("ReplyTo", vector ()));
  --dbg_obj_print ('Application:', loanApplication);
  http_request_status ('HTTP/1.1 202 Accepted');
  http_flush ();
  --delay (1);
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
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": create procedure ASVC..initiate state: " $STATE "\n";

vhost_remove (lpath=>'/asyncLoan');

vhost_define (lpath=>'/asyncLoan', ppath=>'/SOAP/', soap_user => 'ASVC',
	soap_opts => vector (
		'ServiceName','AsyncLoanService'
		));
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": vhost_define /asyncLoan state: " $STATE "\n";

grant execute on ASVC..initiate to ASVC;

create user PICK;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": create user PICK state: " $STATE "\n";


db..vhost_remove (lpath=>'/pick');
db..vhost_define (lpath=>'/pick', ppath=>'/SOAP/', soap_user => 'PICK');
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": vhost_define /pick state: " $STATE "\n";


drop table PICK..onResult;
create table PICK..onResult (res any);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": create table PICK..onResult state: " $STATE "\n";

-- dirty handler
create procedure PICK..onResult (in loanApplication any __soap_type 'http://www.autoloan.com/ns/autoloan:loanApplication_resp') returns any __soap_doc '__VOID__'
{
  dbg_obj_print (loanApplication);
  insert into PICK..onResult values (loanApplication);
}
;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": create procedure PICK..onResult state: " $STATE "\n";

grant execute on PICK..onResult to PICK
;

soap_dt_define ('', '<element name="loanApplication_resp" targetNamespace="http://www.autoloan.com/ns/autoloan" xmlns="http://www.w3.org/2001/XMLSchema">
      <complexType name="LoanApplicationType">
          <sequence>
            <element name="SSN" type="string"/>
            <element name="email" type="string"/>
            <element name="customerName" type="string"/>
            <element name="loanAmount" type="double"/>
            <element name="carModel" type="string"/>
            <element name="carYear" type="string"/>
            <element name="creditRating" type="int"/>
          </sequence>
      </complexType>
    </element>');
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": soap_dt_define element name='loanApplication_resp' state: " $STATE "\n";

soap_dt_define ('', '<element name="loanApplication" targetNamespace="http://www.autoloan.com/ns/autoloan" xmlns="http://www.w3.org/2001/XMLSchema">
      <complexType name="LoanApplicationType">
          <sequence>
            <element name="SSN" type="string"/>
            <element name="email" type="string"/>
            <element name="customerName" type="string"/>
            <element name="loanAmount" type="double"/>
            <element name="carModel" type="string"/>
            <element name="carYear" type="string"/>
            <element name="creditRating" type="int"/>
          </sequence>
      </complexType>
    </element>');

ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": soap_dt_define element name='loanApplication' state: " $STATE "\n";
