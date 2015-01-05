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


create user CRATS
;

create user SLOAN
;

create user ULOAN
;

DB.DBA.vhost_remove (lpath=>'/CreditRating')
;

DB.DBA.vhost_remove (lpath=>'/StarLoan')
;

DB.DBA.vhost_remove (lpath=>'/UnitedLoan')
;

DB.DBA.vhost_define (vhost=>'*ini*',lhost=>'*ini*',lpath=>'/CreditRating',ppath=>'/SOAP/',soap_user=>'CRATS')
;

DB.DBA.vhost_define (vhost=>'*ini*',lhost=>'*ini*',lpath=>'/StarLoan',ppath=>'/SOAP/',soap_user=>'SLOAN')
;

DB.DBA.vhost_define (vhost=>'*ini*',lhost=>'*ini*',lpath=>'/UnitedLoan',ppath=>'/SOAP/',soap_user=>'ULOAN')
;

soap_dt_define ('', '<element name="ssn" targetNamespace="http://www.autoloan.com/ns/autoloan" xmlns="http://www.w3.org/2001/XMLSchema" type="string" />')
;

soap_dt_define ('', '<element name="rating" targetNamespace="http://www.autoloan.com/ns/autoloan" xmlns="http://www.w3.org/2001/XMLSchema" type="int" />')
;

soap_dt_define ('', '<element name="error" targetNamespace="http://www.autoloan.com/ns/autoloan" xmlns="http://www.w3.org/2001/XMLSchema" type="string" />')
;

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

soap_dt_define ('', '<xsd:element name="ssn" targetNamespace="http://services.openlinksw.com" xmlns:xsd="http://www.w3.org/2001/XMLSchema" type="xsd:string" />')
;

soap_dt_define ('', '<xsd:element name="rating" targetNamespace="http://services.openlinksw.com" xmlns:xsd="http://www.w3.org/2001/XMLSchema" type="xsd:int" />')
;

soap_dt_define ('', '<xsd:element name="error" targetNamespace="http://services.openlinksw.com" xmlns:xsd="http://www.w3.org/2001/XMLSchema" type="xsd:string" />')
;

create procedure CRATS..process
	(
	  in ssn varchar __soap_type 'http://services.openlinksw.com:ssn',
	  out rating int __soap_type 'http://services.openlinksw.com:rating',
	  out error varchar __soap_fault 'http://services.openlinksw.com:error'
	)
  __soap_doc '__VOID__'
{
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

grant execute on CRATS..process to CRATS
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

create procedure ULOAN..initiate (
	in loanApplication any __soap_type 'http://www.autoloan.com/ns/autoloan:loanApplication',
	in "ReplyTo" any := null __soap_header 'http://schemas.xmlsoap.org/ws/2003/03/addressing:ReplyTo',
	in "MessageID" any := null __soap_header 'http://schemas.xmlsoap.org/ws/2003/03/addressing:MessageID'
		)
	__soap_options (__soap_doc:='__VOID__', "OneWay":=1)
{
	declare ssn, apr, url any;
	--## United Loan Service
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

grant execute on ULOAN..initiate to ULOAN
;

create procedure SLOAN..initiate (
	in loanApplication any __soap_type 'http://www.autoloan.com/ns/autoloan:loanApplication',
	in "ReplyTo" any := null __soap_header 'http://schemas.xmlsoap.org/ws/2003/03/addressing:ReplyTo',
	in "MessageID" any := null __soap_header 'http://schemas.xmlsoap.org/ws/2003/03/addressing:MessageID'
		)
	__soap_options (__soap_doc:='__VOID__', "OneWay":=1)
{
	declare ssn, apr, url any;
	--## Star Loan Service
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


grant execute on SLOAN..initiate to SLOAN
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

create table BPEL.BPEL.resOnResult (
	id int primary key,
	res	any
)
;

create procedure BPEL.BPEL.onResult (in loanOffer any __soap_type 'http://www.autoloan.com/ns/autoloan:loanOffer') __soap_doc '__VOID__'
{
   insert replacing BPEL.BPEL.resOnResult (id, res) values (1, loanOffer);
}
;


create procedure LF_DEPLOY ()
{
  declare scp int;
  if (exists (select 1 from BPEL..script where bs_name = 'LoanFlow'))
    return;
  BPEL.BPEL.import_script (sprintf ('http://localhost:%s/BPELDemo/LoanFlow/bpel.xml', server_http_port ()),
      'LoanFlow', scp);
  BPEL..compile_script (scp, '/LoanFlow');
}
;

commit work
;

LF_DEPLOY ()
;

