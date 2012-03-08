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
create procedure GEN_WST_USER ()
{
  if (not exists (select 1 from SYS_USERS where U_NAME = 'WS_TRUST'))
    {
      exec ('create user WS_TRUST');
      USER_SET_PASSWORD ('WS_TRUST', 'TRUST_PASSWORD');
    }
}
;

GEN_WST_USER ()
;

create procedure TRUST_CLIENT (in title varchar, in content any, in debug int := 1)
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
   token.debug := debug;
   req.url := 'http://localhost:' || server_http_port () || '/ws_s_5';
   req.parameters := vector (vector ('AddEntry', 'http://weblogs.contoso.com/wse/samples/2003/07:AddEntry'),
		     vector (soap_box_structure ('title', title, 'author', token.user_name, 'issued', now (),
						 'content', content)));
   req.soap_action := 'http://weblogs.contoso.com/wse/samples/2003/07:AddEntry';
   req.operation := 'AddEntry';
   ret := WST_CLI (req, token);
   return ret;
}
;


VHOST_REMOVE (lpath=>'/ws_s_5')
;

VHOST_DEFINE (lpath=>'/ws_s_5', ppath=>'/SOAP/', soap_user=>'WSS',
              soap_opts=>vector('Namespace','http://temp.uri/',
		                'MethodInSoapAction','yes',
				'ServiceName', 'WSSecure',
				'CR-escape', 'no',
				'WS-SEC','yes',
				'WSS-Type', 0,
				'WSS-Validate-Signature', 2,
				'WSS-Func-Template', 'DB.DBA.SOAP_WS_TRUST_OUT_XENC_TEMPLATE'))
;

VHOST_REMOVE (lpath=>'/ws_s_5ts')
;

VHOST_DEFINE (lpath=>'/ws_s_5ts', ppath=>'/SOAP/', soap_user=>'WSS',
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

grant execute on WS.SOAP.RequestSecurityToken to WSS
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
  SOAP_LOAD_SCH (string_output_string (ses));
}
;

WS_S_5_XSD ()
;

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

grant execute on WS.SOAP.AddEntry to WSS
;

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
	<KeyName>wss.pfx</KeyName>
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

create procedure DB.DBA.WST_GET_SECURITY_TOKEN (in "From" any,
    						in "MessageID" any,
						in "RequestSecurityToken" any,
						in "Timestamp" any,
						in "To" any)
{
  if (connection_get ('wss-user') = 'WS_TRUST')
    return xenc_X509_certificate_serialize ('wss.pfx');
  else
    signal ('42000', 'Cannot resolve certificate');
}
;
