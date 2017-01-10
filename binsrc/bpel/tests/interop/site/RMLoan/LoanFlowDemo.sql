--  
--  $Id$
--  
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--  
--  Copyright (C) 1998-2017 OpenLink Software
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
/*
  this script depends from SecLoan example
 */

use DB;

create user CRATS2;


create user SLOAN2;
create user ULOAN2;
create user LOAN2;
create user LWSRM;
grant all privileges to LWSRM;

db..user_set_option ('CRATS2', 'DISABLED', 1);
db..user_set_option ('SLOAN2', 'DISABLED', 1);
db..user_set_option ('ULOAN2', 'DISABLED', 1);
db..user_set_option ('LOAN2', 'DISABLED', 1);
db..user_set_option ('LWSRM', 'DISABLED', 1);

DB.DBA.vhost_remove (lpath=>'/RMLoan');

DB.DBA.vhost_remove (lpath=>'/RMCreditRating');

DB.DBA.vhost_remove (lpath=>'/RMLoanReply');

DB.DBA.vhost_remove (lpath=>'/RMStarLoan');

DB.DBA.vhost_remove (lpath=>'/RMUnitedLoan');

DB.DBA.vhost_define (lpath=>'/RMLoan',ppath=>'/RMLoan/', vsp_user=>'dba');

DB.DBA.vhost_define (lpath=>'/RMCreditRating',ppath=>'/SOAP/',soap_user=>'CRATS2');

DB.DBA.vhost_define (lpath=>'/RMLoanReply',ppath=>'/SOAP/',soap_user=>'LOAN2');

DB.DBA.vhost_define (lpath=>'/RMStarLoan',ppath=>'/SOAP/',soap_user=>'LWSRM',
        soap_opts=>vector ('WSRM-Callback', 'WSRM.WSRM.CALLBACK1'))
;

DB.DBA.vhost_define (lpath=>'/RMUnitedLoan',ppath=>'/SOAP/',soap_user=>'LWSRM',
        soap_opts=>vector ('WSRM-Callback', 'WSRM.WSRM.CALLBACK2'))
;

create table LOAN2..resOnResult (
	id int primary key,
	res	any
)
;

create procedure LOAN2..initiate (in loanApplication any __soap_type 'http://www.autoloan.com/ns/autoloan:loanApplication') __soap_doc '__VOID__'
{
   insert replacing LOAN2..resOnResult (id, res) values (1, loanApplication);
}
;
grant execute on LOAN2..initiate to LOAN2;

create procedure LOAN2..onResult (in loanOffer any __soap_type 'http://www.autoloan.com/ns/autoloan:loanOffer') __soap_doc '__VOID__'
{
   insert replacing LOAN2..resOnResult (id, res) values (1, loanOffer);
}
;

grant execute on LOAN2..onResult to LOAN2;

create procedure CRATS2..process
	(
	  in ssn varchar __soap_type 'services.wsdl:ssn',
	  out rating int __soap_type 'services.wsdl:rating',
	  out error varchar __soap_fault 'services.wsdl:error'
	)
  __soap_doc '__VOID__'
{
  dbg_obj_print ('CRATS2..process');
  if (atoi(cast(ssn as varchar)) = 0)
    {
      error := 'services:NegativeCredit';
      connection_set ('SOAPFault', vector ('400', 'services:NegativeCredit'));
      return;
    }
  rating := 100;
  error := null;
  return;
}
;

grant execute on CRATS2..process to CRATS2
;


create procedure ULOAN2..initiate (
	in loanApplication any __soap_type 'http://www.autoloan.com/ns/autoloan:loanApplication',
	in "ReplyTo" any := null __soap_header 'http://schemas.xmlsoap.org/ws/2003/03/addressing:ReplyTo',
	in "MessageID" any := null __soap_header 'http://schemas.xmlsoap.org/ws/2003/03/addressing:MessageID'
		)
	__soap_doc '__VOID__'
{
	declare ssn, apr, url any;
	--## United Loan Service
	dbg_obj_print ('ULOAN2..initiate');
        url := get_keyword ('Address', "ReplyTo");
        db.dba.soap_client (direction=>1,
		style=>1,
		url=>cast (url as varchar),
		operation=>'onResult',
		parameters =>  vector ('par1',
			xtree_doc ('<loanOffer xmlns="http://www.autoloan.com/ns/autoloan"><providerName>United Loan</providerName><selected>false</selected><approved>true</approved><APR>6.8</APR></loanOffer>')),
		headers => wsa_hdr ("MessageID")
		);
}
;


create procedure SLOAN2..initiate (
	in loanApplication any __soap_type 'http://www.autoloan.com/ns/autoloan:loanApplication',
	in "ReplyTo" any := null __soap_header 'http://schemas.xmlsoap.org/ws/2003/03/addressing:ReplyTo',
	in "MessageID" any := null __soap_header 'http://schemas.xmlsoap.org/ws/2003/03/addressing:MessageID'
		)
	__soap_doc '__VOID__'
{
	declare ssn, apr, url any;
	--## Star Loan Service
	dbg_obj_print ('SLOAN2..initiate');
        url := get_keyword ('Address', "ReplyTo");
        ssn := get_keyword ('SSN', loanApplication);
        if (0 = atoi(cast(ssn as varchar)))
          apr := '7.8';
        else
          apr := '5.6';
        db.dba.soap_client (direction=>1,
		style=>1,
		url=> cast (url as varchar),
		operation=>'onResult',
		parameters =>  vector ('par1',
			xtree_doc ('<loanOffer xmlns="http://www.autoloan.com/ns/autoloan"><providerName>Star Loan</providerName><selected>false</selected><approved>true</approved><APR>'||apr||'</APR></loanOffer>')),
		headers => wsa_hdr ("MessageID")
		);
}
;

create procedure WSRM.WSRM.CALLBACK1 (in msg any, in seq any, in msgid any)
{
  dbg_obj_print ('CALLBACK1', seq, msgid);
  set_user_id ('SLOAN2');
  soap_server (msg, '', null, 11, null, vector ());
}
;

create procedure WSRM.WSRM.CALLBACK2 (in msg any, in seq any, in msgid any)
{
  dbg_obj_print ('CALLBACK2', seq, msgid);
  set_user_id ('ULOAN2');
  soap_server (msg, '', null, 11, null, vector ());
}
;

-- even LWSRM have rights it still need a explicit grant
-- to 'find' the WS RM routines inside SOAP server
grant execute on WSRMSequence to LWSRM;
grant execute on WSRMSequenceTerminate to LWSRM;
grant execute on WSRMAckRequested to LWSRM;
grant execute on WSRMSequenceAcknowledgement to LWSRM;
grant execute on WSRM.WSRM.CALLBACK1 to LWSRM;
grant execute on WSRM.WSRM.CALLBACK2 to LWSRM;

grant execute on ULOAN2..initiate to ULOAN2;
grant execute on SLOAN2..initiate to SLOAN2;

create procedure LF_RM_OPTS ()
{
  return
  '<wsOptions>
      <addressing version="http://schemas.xmlsoap.org/ws/2004/03/addressing" />
      <security>
	  <http-auth username="" password="" />
	  <key name="" />
	  <pubkey name="" />
	  <in>
	      <encrypt type="NONE" />
	      <signature type="NONE" />
	  </in>
	  <out>
	      <encrypt type="NONE" />
	      <signature type="NONE" function="" />
	  </out>
      </security>
      <delivery>
	  <in type="ExactlyOnce" />
	  <out type="ExactlyOnce" />
      </delivery>
  </wsOptions>';
}
;

create procedure RMLF_DEPLOY ()
{
  declare scp int;
  if (exists (select 1 from BPEL..script where bs_name = 'RMLoanFlow'))
    return;
  BPEL.BPEL.import_script (sprintf ('http://localhost:%s/BPELDemo/RMLoan/bpel.xml', server_http_port ()),
      'RMLoanFlow', scp);
  BPEL..compile_script (scp, '/RMLoanFlow');
  update BPEL..partner_link_init set bpl_opts = LF_RM_OPTS () where bpl_name in ('StarLoanService', 'UnitedLoanService') and bpl_script = scp;

}
;

commit work
;

RMLF_DEPLOY ()
;

