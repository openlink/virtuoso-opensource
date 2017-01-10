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
 this script needs RM & Security one to be installed
 */

use DB;

create user LOAN3;

db..user_set_option ('LOAN3', 'DISABLED', 1);

DB.DBA.vhost_remove (lpath=>'/SecRMLoanReply');
DB.DBA.vhost_define (lpath=>'/SecRMLoanReply',ppath=>'/SOAP/', soap_user=>'LOAN3');

DB.DBA.vhost_remove (lpath=>'/SecRMLoanFlowSrc');
DB.DBA.vhost_define (lpath=>'/SecRMLoanFlowSrc',ppath=>'/SecRMLoan/', vsp_user=>'dba');

DB.DBA.vhost_remove (lpath=>'/SecRMStarLoan');

DB.DBA.vhost_remove (lpath=>'/SecRMUnitedLoan');

DB.DBA.vhost_define (lpath=>'/SecRMStarLoan',ppath=>'/SOAP/',soap_user=>'LWSRM',
        soap_opts=>vector ('WSRM-Callback', 'WSRM.WSRM.CALLBACK1', 'WS-SEC','yes', 'WSS-Validate-Signature', 1, 'WSS-SecurityCheck', 'WSRM.WSRM.SECURITY_CHECK'))
;

DB.DBA.vhost_define (lpath=>'/SecRMUnitedLoan',ppath=>'/SOAP/',soap_user=>'LWSRM',
        soap_opts=>vector ('WSRM-Callback', 'WSRM.WSRM.CALLBACK2', 'WS-SEC','yes', 'WSS-Validate-Signature', 1, 'WSS-SecurityCheck', 'WSRM.WSRM.SECURITY_CHECK'))
;

create table LOAN3..resOnResult (
	id int primary key,
	res	any
)
;

create procedure LOAN3..initiate (in loanApplication any __soap_type 'http://www.autoloan.com/ns/autoloan:loanApplication')
   __soap_doc '__VOID__'
{
   insert replacing LOAN3..resOnResult (id, res) values (1, loanApplication);
}
;
grant execute on LOAN3..initiate to LOAN3;

create procedure LOAN3..onResult (in loanOffer any __soap_type 'http://www.autoloan.com/ns/autoloan:loanOffer')
   __soap_doc '__VOID__'
{
   insert replacing LOAN3..resOnResult (id, res) values (1, loanOffer);
}
;

grant execute on LOAN3..onResult to LOAN3;

create procedure WSRM.WSRM.SECURITY_CHECK (inout msg any)
{
  --dbg_obj_print (msg);
  dbg_obj_print (connection_get ('wss-token-owner'));
  return;
}
;

BPEL..load_keys ('LWSRM', 'ServerPrivate.pfx', 'ClientPublic.cer');

create procedure LF_RMSEC_OPTS ()
{
  return
  '<wsOptions>
      <addressing version="http://schemas.xmlsoap.org/ws/2004/03/addressing" />
      <security>
	  <http-auth username="" password="" />
	  <key name="ClientPrivate.pfx" />
	  <pubkey name="ServerPublic.cer" />
	  <in>
	      <encrypt type="Optional" />
	      <signature type="Optional" />
	  </in>
	  <out>
	      <encrypt type="AES128" />
	      <signature type="Default" function="" />
	  </out>
      </security>
      <delivery>
	  <in type="ExactlyOnce" />
	  <out type="ExactlyOnce" />
      </delivery>
  </wsOptions>';
}
;

create procedure SECRMLF_DEPLOY ()
{
  declare scp int;
  if (exists (select 1 from BPEL..script where bs_name = 'SecRMLoanFlow'))
    return;
  BPEL.BPEL.import_script (sprintf ('http://localhost:%s/SecRMLoanFlowSrc/bpel.xml', server_http_port ()),
      'SecRMLoanFlow', scp);
  BPEL..compile_script (scp, '/SecRMLoanFlow');
  update BPEL..partner_link_init set bpl_opts = LF_RMSEC_OPTS () where bpl_name in ('StarLoanService', 'UnitedLoanService') and bpl_script = scp;
  update BPEL..partner_link_init set bpl_opts = LF_SEC_OPTS () where bpl_name = 'creditRatingService' and bpl_script = scp;

}
;

commit work
;

SECRMLF_DEPLOY ()
;

