--  
--  $Id$
--  
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--  
--  Copyright (C) 1998-2016 OpenLink Software
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
--test
use DB;

create user CRATS1;


create user SLOAN1;

create user ULOAN1;

create user LOAN1;

db..user_set_option ('CRATS1', 'DISABLED', 1);
db..user_set_option ('SLOAN1', 'DISABLED', 1);
db..user_set_option ('ULOAN1', 'DISABLED', 1);
db..user_set_option ('LOAN1', 'DISABLED', 1);

commit work;

DB.DBA.vhost_remove (lpath=>'/SecLoan');

DB.DBA.vhost_remove (lpath=>'/SecCreditRating');

DB.DBA.vhost_remove (lpath=>'/SecStarLoan');

DB.DBA.vhost_remove (lpath=>'/SecUnitedLoan');

DB.DBA.vhost_remove (lpath=>'/SecLoanReply');

DB.DBA.vhost_define (lpath=>'/SecLoan',ppath=>'/SecLoan/', vsp_user=>'dba');

DB.DBA.vhost_define (lpath=>'/SecLoanReply',ppath=>'/SOAP/', soap_user=>'LOAN1');

DB.DBA.vhost_define (lpath=>'/SecCreditRating',ppath=>'/SOAP/',soap_user=>'CRATS1',
    soap_opts=>vector ('WS-SEC','yes', 'WSS-Validate-Signature', 1));

DB.DBA.vhost_define (lpath=>'/SecStarLoan',ppath=>'/SOAP/',soap_user=>'SLOAN1',
        soap_opts=>vector ('WS-SEC','yes', 'WSS-Validate-Signature', 1));

DB.DBA.vhost_define (lpath=>'/SecUnitedLoan',ppath=>'/SOAP/',soap_user=>'ULOAN1',
        soap_opts=>vector ('WS-SEC','yes', 'WSS-Validate-Signature', 1));

soap_dt_define ('', '<element name="ssn" targetNamespace="http://www.autoloan.com/ns/autoloan" xmlns="http://www.w3.org/2001/XMLSchema" type="string" />');

soap_dt_define ('', '<element name="rating" targetNamespace="http://www.autoloan.com/ns/autoloan" xmlns="http://www.w3.org/2001/XMLSchema" type="int" />');

soap_dt_define ('', '<element name="error" targetNamespace="http://www.autoloan.com/ns/autoloan" xmlns="http://www.w3.org/2001/XMLSchema" type="string" />');

soap_dt_define ('', '<complexType name="loanApplicationType" targetNamespace="http://www.autoloan.com/ns/autoloan" xmlns="http://www.w3.org/2001/XMLSchema">
        <sequence>
          <element name="SSN" type="string"/>
          <element name="email" type="string"/>
          <element name="customerName" type="string"/>
          <element name="loanAmount" type="double"/>
          <element name="carModel" type="string"/>
          <element name="carYear" type="string"/>
          <element name="creditRating" type="int"/>
        </sequence>
      </complexType>')
;

soap_dt_define ('', '<element name="loanApplication" targetNamespace="http://www.autoloan.com/ns/autoloan" xmlns="http://www.w3.org/2001/XMLSchema" type="tns:loanApplicationType" xmlns:tns="http://www.autoloan.com/ns/autoloan" />')
;

soap_dt_define ('', '<xsd:element name="ssn" targetNamespace="services.wsdl" xmlns:xsd="http://www.w3.org/2001/XMLSchema" type="xsd:string" />')
;

soap_dt_define ('', '<xsd:element name="rating" targetNamespace="services.wsdl" xmlns:xsd="http://www.w3.org/2001/XMLSchema" type="xsd:int" />')
;

soap_dt_define ('', '<xsd:element name="error" targetNamespace="services.wsdl" xmlns:xsd="http://www.w3.org/2001/XMLSchema" type="xsd:string" />')
;

create procedure CRATS1..process
	(
	  in ssn varchar __soap_type 'services.wsdl:ssn',
	  out rating int __soap_type 'services.wsdl:rating',
	  out error varchar __soap_fault 'services.wsdl:error'
	)
  __soap_doc '__VOID__'
{
  dbg_obj_print ('CRATS1..process');
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

grant execute on CRATS1..process to CRATS1
;


create procedure wsa_hdr (in mid1 any)
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

create procedure ULOAN1..initiate (
	in loanApplication any __soap_type 'http://www.autoloan.com/ns/autoloan:loanApplication',
	in "ReplyTo" any := null __soap_header 'http://schemas.xmlsoap.org/ws/2003/03/addressing:ReplyTo',
	in "MessageID" any := null __soap_header 'http://schemas.xmlsoap.org/ws/2003/03/addressing:MessageID'
		)
	__soap_options (__soap_doc:='__VOID__', "OneWay":=1)
{
	declare ssn, apr, url any;
	--## United Loan Service
	dbg_obj_print ('ULOAN1..initiate');
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

grant execute on ULOAN1..initiate to ULOAN1
;

create procedure SLOAN1..initiate (
	in loanApplication any __soap_type 'http://www.autoloan.com/ns/autoloan:loanApplication',
	in "ReplyTo" any := null __soap_header 'http://schemas.xmlsoap.org/ws/2003/03/addressing:ReplyTo',
	in "MessageID" any := null __soap_header 'http://schemas.xmlsoap.org/ws/2003/03/addressing:MessageID'
		)
	__soap_options (__soap_doc:='__VOID__', "OneWay":=1)
{
	declare ssn, apr, url any;
	--## Star Loan Service
	dbg_obj_print ('SLOAN1..initiate');
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


grant execute on SLOAN1..initiate to SLOAN1
;

db..soap_dt_define ('', '<xsd:element name="loanOffer" type="s1:LoanOfferType" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:s1="http://www.autoloan.com/ns/autoloan" targetNamespace="http://www.autoloan.com/ns/autoloan"/>')
;

db..soap_dt_define ('', '<complexType name="LoanOfferType" xmlns:xsd="http://www.w3.org/2001/XMLSchema" targetNamespace="http://www.autoloan.com/ns/autoloan">
              <sequence>
                <element name="providerName" type="string"/>
                <element name="selected" type="boolean"/>
                <element name="approved" type="boolean"/>
                <element name="APR" type="double"/>
              </sequence>
          </complexType>')
;

create table BPEL.BPEL.resOnResult1 (
	id int primary key,
	res	any
)
;

create procedure BPEL.BPEL.onResult (in loanOffer any __soap_type 'http://www.autoloan.com/ns/autoloan:loanOffer') __soap_doc '__VOID__'
{
   insert replacing BPEL.BPEL.resOnResult1 (id, res) values (1, loanOffer);
}
;

create table LOAN1..resOnResult1 (
	id int primary key,
	res	any
)
;

create procedure LOAN1..initiate (in loanApplication any __soap_type 'http://www.autoloan.com/ns/autoloan:loanApplication')
   __soap_doc '__VOID__'
{
   insert replacing LOAN1..resOnResult1 (id, res) values (1, loanApplication);
}
;
grant execute on LOAN1..initiate to LOAN1;

create procedure LOAN1..onResult (in loanOffer any __soap_type 'http://www.autoloan.com/ns/autoloan:loanOffer')
   __soap_doc '__VOID__'
{
   insert replacing LOAN1..resOnResult1 (id, res) values (1, loanOffer);
}
;

grant execute on LOAN1..onResult to LOAN1;

create procedure BPEL..load_paths (in pkey any)

{
  declare sPath varchar;
  declare s1, s2 varchar;

  if (BPEL.BPEL.vdir_base() = '/vad/vsp')
  {
   sPath := http_root ();
    return file_to_string (sPath  || BPEL.BPEL.vdir_base () || '/bpeldemo/SecLoan/' || pkey);
  }
  else
  {
    sPath := concat('http://localhost:',server_http_port ());
    return http_get(sPath  || BPEL.BPEL.vdir_base () || '/bpeldemo/SecLoan/' || pkey);
  };
}
;

create procedure BPEL..load_keys (in u any, in pk any, in pub any)
{
  set_user_id (u);
  if (not xenc_key_exists (pk))
    {
      db..user_key_load (pk, BPEL..load_paths(pk), 'X.509', 'PKCS12', 'wse2qs', null, 1);
    }
  if (not xenc_key_exists (pub))
    {
      db..user_key_load (pub, BPEL..load_paths(pub), 'X.509', 'DER', 'wse2qs', null, 1);
    }
}
;

BPEL..load_keys ('CRATS1', 'ServerPrivate.pfx', 'ClientPublic.cer');
BPEL..load_keys ('ULOAN1', 'ServerPrivate.pfx', 'ClientPublic.cer');
BPEL..load_keys ('SLOAN1', 'ServerPrivate.pfx', 'ClientPublic.cer');
BPEL..load_keys ('BPEL',  'ClientPrivate.pfx', 'ServerPublic.cer');

create procedure LF_SEC_OPTS ()
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
	  <in type="NONE" />
	  <out type="NONE" />
      </delivery>
  </wsOptions>';
}
;

create procedure LF_DEPLOY ()
{
  declare scp int;
  if (exists (select 1 from BPEL..script where bs_name = 'SecLoanFlow'))
    return;
  BPEL.BPEL.import_script (sprintf ('http://localhost:%s/BPELDemo/SecLoan/bpel.xml', server_http_port ()),
      'SecLoanFlow', scp);
  BPEL..compile_script (scp, '/SecLoanFlow');
  update BPEL..partner_link_init set bpl_opts = LF_SEC_OPTS () where bpl_name in ('creditRatingService', 'StarLoanService', 'UnitedLoanService') and bpl_script = scp;

}
;

commit work
;

LF_DEPLOY ()
;

