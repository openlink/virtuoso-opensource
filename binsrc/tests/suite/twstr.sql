--  
--  $Id: twstr.sql,v 1.3.10.1 2013/01/02 16:15:35 source Exp $
--  
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--  
--  Copyright (C) 1998-2013 OpenLink Software
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

create procedure cert ()
{
    return uudecode (
   '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', 2);
}
;

create procedure server_pub_x509_key ()
{
  return
   'MIICxzCCAjCgAwIBAgIBADANBgkqhkiG9w0BAQQFADBSMQswCQYDVQQGEwJCRzEQMA4GA1UE' ||
   'CBMHUGxvdmRpdjEQMA4GA1UEBxMHUGxvdmRpdjEfMB0GA1UEChMWT3BlbkxpbmsgU29mdHdh' ||
   'cmUgTHRkLjAeFw0wNDAxMjExNDA4MzhaFw0wNTAxMjAxNDA4MzhaMFIxCzAJBgNVBAYTAkJH' ||
   'MRAwDgYDVQQIEwdQbG92ZGl2MRAwDgYDVQQHEwdQbG92ZGl2MR8wHQYDVQQKExZPcGVuTGlu' ||
   'ayBTb2Z0d2FyZSBMdGQuMIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQDp4LEkZOl/Nbve' ||
   'sKUYbJkYS615oB0nPbu3n0dCCC37xswbluBQcS+P/zHdvQZaWzWsluGpGctHzTYcD7+UkiLJ' ||
   'Xrd+PddqkgfogqaW7/9jB2CJSA1paoJTqX6b06/KOi4Jj1WYHwkGOfiD+WybUWcX65gtaM52' ||
   'OUoenVOy7v5zrwIDAQABo4GsMIGpMB0GA1UdDgQWBBTrS3v9pmTo/jCtrd9+7FBESXGVHDB6' ||
   'BgNVHSMEczBxgBTrS3v9pmTo/jCtrd9+7FBESXGVHKFWpFQwUjELMAkGA1UEBhMCQkcxEDAO' ||
   'BgNVBAgTB1Bsb3ZkaXYxEDAOBgNVBAcTB1Bsb3ZkaXYxHzAdBgNVBAoTFk9wZW5MaW5rIFNv' ||
   'ZnR3YXJlIEx0ZC6CAQAwDAYDVR0TBAUwAwEB/zANBgkqhkiG9w0BAQQFAAOBgQCCzqtd0ej6' ||
   'f5NSORqyLlJ90L1FPAiF1lg+dFSatMpxbv6zPTK9qnHp3VWK0cPwK1GxxC3B2QyuhCIkeRs7' ||
   'qymH8S6W9maUMIvLD1dDQFxKStgxJe0IDEIG9CygaDGsTpkPwq/qPqhRGamGeLO9GU8wPnUN' ||
   'OleyHzY8Y4ZkCznSFQ==';
}
;

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

