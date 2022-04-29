--
--  $Id: twstr.sql,v 1.3.10.1 2013/01/02 16:15:35 source Exp $
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2022 OpenLink Software
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
drop table WS_S_5
;


create table WS_S_5 (
	ID 	varchar primary key,
	LINK	varchar,
	TITLE	varchar,
	AUTHOR	varchar,
	ISSUED  datetime,
	CONTENT varchar
)
;

ECHO BOTH $IF $EQU $STATE 'OK'  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": WS-TRUST CREATE CLIENT TABLE \n";

create user WS_TRUST
;

ECHO BOTH $IF $EQU $STATE 'OK'  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": WS-TRUST CREATE USER WS_TRUST \n";

USER_SET_PASSWORD ('WS_TRUST', 'TRUST_PASSWORD')
;

ECHO BOTH $IF $EQU $STATE 'OK'  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": WS-TRUST CHANGE PASSWORD WS_TRUST \n";

create procedure
WSS_SETUP ()
{
  if (not exists (select 1 from SYS_USERS where U_NAME = 'WSE'))
    exec ('create user WSE');
}
;

WSS_SETUP ()
;

create procedure trust_client ()
{
   declare token POLICY_STRUCT;
   declare req SOAP_CLIENT_REQ;
   declare ret any;

   token := new POLICY_STRUCT ();
   req := new SOAP_CLIENT_REQ ();

   token.usage := 'ReqIssue';
   token.token_type := 'X509v3';
   token.token_issuer := 'http://localhost:' || server_http_port () || '/ws_s_5ts';
   token.user_name := 'WS_TRUST';
   token.user_pass := 'TRUST_PASSWORD';
   token.debug := 0;

   req.url := 'http://localhost:' || server_http_port () || '/ws_s_5';
   req.parameters := vector (vector ('AddEntry', 'http://weblogs.contoso.com/wse/samples/2003/07:AddEntry'),
		     vector (soap_box_structure ('title', 'Test title', 'author', 'Test author', 'issued', now (),
						 'content', 'Test content')));
   req.soap_action := 'http://weblogs.contoso.com/wse/samples/2003/07:AddEntry';
   req.operation := 'AddEntry';

   ret := WST_CLI (req, token);

   if (token.debug <> 0)
     return ret;

   insert into WS_S_5 (ID, LINK, TITLE, AUTHOR, ISSUED, CONTENT) values
		(ret[2][2][1], ret[2][4][1], ret[2][6][1], ret[2][8][1], ts (ret[2][10][1]), ret[2][12][1]);
}
;

ECHO BOTH $IF $EQU $STATE 'OK'  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": WS-TRUST CREATE PROCEDURE TRUST_CLIENT \n";


VHOST_REMOVE (lpath=>'/ws_s_5');

VHOST_DEFINE (lpath=>'/ws_s_5', ppath=>'/SOAP/', soap_user=>'WSE',
              soap_opts=>vector('Namespace','http://temp.uri/',
		                'MethodInSoapAction','yes',
				'ServiceName', 'WSSecure',
				'CR-escape', 'no',
				'WS-SEC','yes',
				'WSS-Type', 0,
				'WSS-Validate-Signature', 2,
				'WSS-Func-Template', 'DB.DBA.SOAP_WS_TRUST_OUT_XENC_TEMPLATE'))
;

ECHO BOTH $IF $EQU $STATE 'OK'  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": WS-TRUST CREATE END POINT VIRTUAL DIR \n";

VHOST_REMOVE (lpath=>'/ws_s_5ts');

VHOST_DEFINE (lpath=>'/ws_s_5ts', ppath=>'/SOAP/', soap_user=>'WSE',
              soap_opts=>vector('Namespace','http://temp.uri/',
		                'MethodInSoapAction','yes',
				'ServiceName', 'WSSecure',
				'CR-escape', 'no',
				'WS-SEC','yes',
				'WSS-KEY', 'ws_s_5',
				'WSS-Template', 'ws_s_5',
				'WSS-Type', 0,
				'WSS-Validate-Signature', 2,
				'WSS-Func-Template', 'DB.DBA.SOAP_WS_TRUST_OUT_XENC_TEMPLATE'))
;

ECHO BOTH $IF $EQU $STATE 'OK'  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": WS-TRUST CREATE ISSUER VIRTUAL DIR \n";

grant execute on WS.SOAP.RequestSecurityToken to WSE
;

CREATE PROCEDURE WS_S_5_XSD ()
{
  declare ses any;
  ses := string_output ();
  http ('<xsd:schema\n', ses);
  http ('    xmlns:xsd="http://www.w3.org/2001/XMLSchema"\n', ses);
  http ('    xmlns:tns="http://weblogs.contoso.com/wse/samples/2003/07"\n', ses);
  http ('    targetNamespace="http://weblogs.contoso.com/wse/samples/2003/07">\n', ses);
  http ('    <xsd:element name="AddEntry">\n', ses);
  http ('	<xsd:complexType>\n', ses);
  http ('	    <xsd:sequence>\n', ses);
  http ('		<xsd:element name="entry" minOccurs="1" maxOccurs="1" type="tns:entry_t" />\n', ses);
  http ('	    </xsd:sequence>\n', ses);
  http ('	</xsd:complexType>\n', ses);
  http ('    </xsd:element>\n', ses);
  http ('    <xsd:element name="WeblogEntry">\n', ses);
  http ('	<xsd:complexType>\n', ses);
  http ('	    <xsd:sequence>\n', ses);
  http ('		<xsd:element name="WeblogEntry" minOccurs="1" maxOccurs="1" type="tns:entry_t" />\n', ses);
  http ('	    </xsd:sequence>\n', ses);
  http ('	</xsd:complexType>\n', ses);
  http ('    </xsd:element>\n', ses);
  http ('    <xsd:element name="AddEntryResponse">\n', ses);
  http ('	<xsd:complexType>\n', ses);
  http ('	    <xsd:sequence>\n', ses);
  http ('		<xsd:element name="WeblogEntry" minOccurs="1" maxOccurs="1" type="tns:entry_t" />\n', ses);
  http ('	    </xsd:sequence>\n', ses);
  http ('	</xsd:complexType>\n', ses);
  http ('    </xsd:element>\n', ses);
  http ('    <xsd:complexType name="entry_t">\n', ses);
  http ('	    <xsd:sequence>\n', ses);
  http ('		<xsd:element name="id" minOccurs="0" maxOccurs="1" type="xsd:string" />\n', ses);
  http ('		<xsd:element name="link" minOccurs="0" maxOccurs="1" type="xsd:string" />\n', ses);
  http ('		<xsd:element name="title" minOccurs="0" maxOccurs="1" type="xsd:string" />\n', ses);
  http ('		<xsd:element name="author" minOccurs="0" maxOccurs="1" type="xsd:string" />\n', ses);
  http ('		<xsd:element name="issued" minOccurs="0" maxOccurs="1" type="xsd:dateTime" />\n', ses);
  http ('		<xsd:element name="content" minOccurs="0" maxOccurs="1" type="xsd:string" />\n', ses);
  http ('	    </xsd:sequence>\n', ses);
  http ('    </xsd:complexType>\n', ses);
  http ('</xsd:schema>\n', ses);
  return string_output_string (ses);
}
;

SOAP_LOAD_SCH (WS_S_5_XSD ())
;

ECHO BOTH $IF $EQU $STATE 'OK'  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": WS-TRUST LOAD SAMPLE XSD \n";

create procedure WS.SOAP.AddEntry
(
in  AddEntry any := null __soap_type 'http://weblogs.contoso.com/wse/samples/2003/07:AddEntry',
out AddEntryResponse any __soap_type 'http://weblogs.contoso.com/wse/samples/2003/07:AddEntryResponse',
inout "From" any __soap_header 'http://schemas.xmlsoap.org/ws/2003/03/addressing:From',
inout "MessageID" any __soap_header 'http://schemas.xmlsoap.org/ws/2003/03/addressing:MessageID',
  out "Timestamp" any __soap_header 'http://schemas.xmlsoap.org/ws/2002/07/utility:Timestamp',
inout "To" any __soap_header 'http://schemas.xmlsoap.org/ws/2003/03/addressing:To'
) __soap_doc '__VOID__'

{
   declare ret any;
   declare param any;
   declare wsa_from, wsu_time, created, expr, m_id, a_to, headers soap_parameter;
   declare in_title, in_author, in_content, out_id, out_link any;

   in_title := get_keyword ('title', AddEntry[0], '');
   in_author := get_keyword ('author', AddEntry[0], '');
   in_content := get_keyword ('content', AddEntry[0], '');

   out_id := lower (uuid ());
   out_link := sys_connected_server_address () || '/ws-trust/sample?' || out_id;

   wsa_from := new soap_parameter ();
   wsa_from.set_xsd ('http://schemas.xmlsoap.org/ws/2003/03/addressing:From');
   wsa_from.add_member ('Address', 'http://' || sys_connected_server_address () || '/WSE');
   wsa_from.set_attribute ('Id', 'Id-' || uuid());

   created := new soap_parameter (dt_set_tz (now (), 0));
   created.set_xsd ('http://schemas.xmlsoap.org/ws/2002/07/utility:Created');
   created.set_attribute ('Id', 'Id-' || uuid());

   expr := new soap_parameter (dt_set_tz (dateadd ('minute', 500, now ()), 0));
   expr.set_xsd ('http://schemas.xmlsoap.org/ws/2002/07/utility:Expires');
   expr.set_attribute ('Id', 'Id-' || uuid());

   wsu_time := new soap_parameter ();
   wsu_time.set_xsd ('http://schemas.xmlsoap.org/ws/2002/07/utility:Timestamp');
   wsu_time.add_member ('Created', created);
   wsu_time.add_member ('Expires', expr);

   m_id := new soap_parameter (lower ('UUID:'||uuid ()));
   m_id.set_xsd ('http://schemas.xmlsoap.org/ws/2003/03/addressing:MessageID');
   m_id.set_attribute ('Id', 'Id-' || uuid());

   a_to := new soap_parameter ('http://schemas.xmlsoap.org/ws/2003/03/addressing/role/anonymous');
   a_to.set_xsd ('http://schemas.xmlsoap.org/ws/2003/03/addressing:To');
   a_to.set_attribute ('Id', 'Id-' || uuid());

   param :=  (vector ('WeblogEntry', 'http://weblogs.contoso.com/wse/samples/2003/07:AddEntry'),
	      vector (soap_box_structure ('id', out_id,
					  'link', out_link,
					  'title', in_title,
					  'author', in_author,
					  'issued', now (),
					  'content', in_content)));

    AddEntryResponse := param;
    "From" := wsa_from.s;
    "MessageID" := m_id.s;
    "Timestamp" := wsu_time.s;
    "To" := a_to.s;
}
;

ECHO BOTH $IF $EQU $STATE 'OK'  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": WS-TRUST CREATE END POINT PROCEDURE \n";

grant execute on WS.SOAP.AddEntry to WSE;

create procedure
DB.DBA.SOAP_WS_TRUST_OUT_XENC_TEMPLATE (in body varchar)
{
  declare tmpl varchar;

  tmpl := sprintf ('<?xml version="1.0" encoding="UTF-8"?>
<Signature xmlns="http://www.w3.org/2000/09/xmldsig#" >
  <SignedInfo>
    <CanonicalizationMethod Algorithm="http://www.w3.org/2001/10/xml-exc-c14n#" />
    <SignatureMethod Algorithm="http://www.w3.org/2000/09/xmldsig#rsa-sha1" />
  </SignedInfo>
  <SignatureValue></SignatureValue>
  <KeyInfo>
    <KeyName>ws_s_5</KeyName>
  </KeyInfo>
</Signature>');

  return dsig_template_ext (body, tmpl,
      'http://schemas.xmlsoap.org/soap/envelope/', 'Body',
      'http://schemas.xmlsoap.org/ws/2003/03/addressing', 'MessageID',
      'http://schemas.xmlsoap.org/ws/2003/03/addressing', 'From',
      'http://schemas.xmlsoap.org/ws/2003/03/addressing', 'RelatesTo',
      'http://schemas.xmlsoap.org/ws/2003/03/addressing', 'To',
      'http://schemas.xmlsoap.org/ws/2002/07/utility', 'Expires',
      'http://schemas.xmlsoap.org/ws/2002/07/utility', 'Created'
      );

}
;

create procedure
gen_x509_self_signed (in key_base varchar, in DN_name varchar, in replace int := 0)
{
  declare sn, attrs, key_name any;
  set_user_id ('dba');
  key_name := key_base || '_base';
  attrs := split_and_decode (DN_name, 0, '\0\0,=');
  if (xenc_key_exists (key_name) and replace)
    xenc_key_remove (key_name);
  if (not xenc_key_exists (key_name))
    {
      xenc_key_RSA_create (key_name, 2048);
      sn := deserialize (hex2bin('F700' || subseq (bin2hex (xenc_digest (uuid(), 'sha256')), 0, 14))); 
      xenc_x509_ss_generate (key_name, sn, 356, attrs, vector (
      'basicConstraints', 'critical,CA:FALSE',
      'extendedKeyUsage', 'serverAuth,clientAuth'));
    }
  return cast (xenc_pkcs12_export (key_name, key_base, key_base) as varchar);
}
;

create procedure server_pub_x509_key ()
{
   set_user_id ('dba');
   return xenc_X509_certificate_serialize ('ws_s_5_base');  
};

create procedure cert ()
{
  return gen_x509_self_signed ('ws_s_5', 'C=US,ST=MA,L=Boston,O=OpenLink Software Ltd.');
}
;

cert();

insert soft WST_SERVER_ISSUER_TOKENS (WSK_TOKEN_TYPE, WSK_REQUEST_TYPE, WSK_APPLIES_TO, WSK_FROM,
					   WSK_SERVICE_NAME, WSK_PORT_TYPE, WSK_TOKEN) values
		 ('wsse:X509v3', 'wsse:ReqIssue', NULL,
		  'http://schemas.xmlsoap.org/ws/2003/03/addressing/role/anonymous', NULL, NULL,
		   server_pub_x509_key ())
;

grant execute on cert to public
;

commit work
;

USER_KEY_LOAD ('ws_s_5', cert(), 'X.509', 'PKCS12', 'ws_s_5', null, 1)
;

ECHO BOTH $IF $EQU $STATE 'OK'  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": WS-TRUST LOAD SERVER CERTIFICATE \n";

reconnect WSE
;

USER_KEY_LOAD ('ws_s_5', cert(), 'X.509', 'PKCS12', 'ws_s_5', null, 1)
;

ECHO BOTH $IF $EQU $STATE 'OK'  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": WS-TRUST LOAD USER CERTIFICATE \n";

reconnect dba
;

checkpoint
;

select TRUST_CLIENT ();
ECHO BOTH $IF $EQU $STATE 'OK'  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": WS-TRUST TRUST_CLIENT 1 \n";

select TRUST_CLIENT ();
ECHO BOTH $IF $EQU $STATE 'OK'  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": WS-TRUST TRUST_CLIENT 2 \n";

select count (*) from WS_S_5;
ECHO BOTH $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": WS-TRUST CHECK RESULT TABLE ROWS = " $LAST[1] "\n";

select TRUST_CLIENT ();
ECHO BOTH $IF $EQU $STATE 'OK'  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": WS-TRUST TRUST_CLIENT 3 \n";

select count (*) from WS_S_5;
ECHO BOTH $IF $EQU $LAST[1] 3 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": WS-TRUST CHECK RESULT TABLE ROWS = " $LAST[1] "\n";

