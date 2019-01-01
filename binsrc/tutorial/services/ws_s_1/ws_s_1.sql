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

create procedure
WSS_SETUP ()
{
  if (not exists (select 1 from SYS_USERS where U_NAME = 'WSS'))
    exec ('create user WSS');
}
;

WSS_SETUP ()
;

create procedure AddInt (in a int, in b int) returns int __soap_type 'int'
{
  return (a + b);
}
;

grant execute on AddInt to WSS
;

VHOST_REMOVE (lpath=>'/SecureWebServices');

VHOST_DEFINE (lpath=>'/SecureWebServices', ppath=>'/SOAP/', soap_user=>'WSS',
              soap_opts=>vector('Namespace','http://temp.uri/',
		                'MethodInSoapAction','yes',
				'ServiceName', 'WSSecure',
				'CR-escape', 'no',
				'WS-SEC','yes',
				'WSS-KEY', NULL,
				'WSS-Template', NULL,
				'WSS-Type', 0,
				'WSS-Validate-Signature', 2))
;


-- define a key for client
USER_KEY_LOAD ('WSDK Sample Symmetric Key', 'EE/uaFF5N3ZNJWUTR8DYe+OEbwaKQnso', '3DES', 'DER', null)
;

-- this can be used for 'WSS-KEY'
create procedure
DB.DBA.WSDK_GET_KEY ()
{
  return xenc_key_inst_create ('WSDK Sample Symmetric Key');
}
;

create procedure
WSS_SRV_SETUP ()
{
  __pop_user_id();
  __set_user_id('WSS');
  if (not xenc_key_exists ('WSDK Sample Symmetric Key'))
    USER_KEY_LOAD ('WSDK Sample Symmetric Key', 'EE/uaFF5N3ZNJWUTR8DYe+OEbwaKQnso', '3DES', 'DER', null);
  __pop_user_id();
  __set_user_id('dba');
}
;

WSS_SRV_SETUP ()
;

CREATE PROCEDURE WSS_STOCK_XSD ()
{
  declare ses any;
  ses := string_output ();
http ('<xsd:schema\n', ses);
http ('    xmlns:xsd="http://www.w3.org/2001/XMLSchema"\n', ses);
http ('    xmlns:tns="http://stockservice.contoso.com/wse/samples/2003/06"\n', ses);
http ('    targetNamespace="http://stockservice.contoso.com/wse/samples/2003/06">\n', ses);
http ('    <xsd:element name="StockQuoteRequest">\n', ses);
http ('	<xsd:complexType>\n', ses);
http ('	    <xsd:sequence>\n', ses);
http ('		<xsd:element name="symbols" minOccurs="1" maxOccurs="1" type="tns:symbols_t" />\n', ses);
http ('	    </xsd:sequence>\n', ses);
http ('	</xsd:complexType>\n', ses);
http ('    </xsd:element>\n', ses);
http ('    <xsd:element name="StockQuotes">\n', ses);
http ('	<xsd:complexType>\n', ses);
http ('	    <xsd:sequence>\n', ses);
http ('		<xsd:element name="StockQuote" minOccurs="0" maxOccurs="unbounded" type="tns:StockQuote_t" />\n', ses);
http ('	    </xsd:sequence>\n', ses);
http ('	</xsd:complexType>\n', ses);
http ('    </xsd:element>\n', ses);
http ('    <xsd:complexType name="symbols_t">\n', ses);
http ('	    <xsd:sequence>\n', ses);
http ('		<xsd:element name="Symbol" minOccurs="1" maxOccurs="unbounded" type="xsd:string" />\n', ses);
http ('	    </xsd:sequence>\n', ses);
http ('    </xsd:complexType>\n', ses);
http ('    <xsd:complexType name="StockQuote_t">\n', ses);
http ('	    <xsd:sequence>\n', ses);
http ('		<xsd:element name="Symbol" minOccurs="0" maxOccurs="1" type="xsd:string" />\n', ses);
http ('		<xsd:element name="Last" minOccurs="0" maxOccurs="1" type="xsd:int" />\n', ses);
http ('		<xsd:element name="Date" minOccurs="0" maxOccurs="1" type="xsd:dateTime" />\n', ses);
http ('		<xsd:element name="Change" minOccurs="0" maxOccurs="1" type="xsd:int" />\n', ses);
http ('		<xsd:element name="Open" minOccurs="0" maxOccurs="1" type="xsd:int" />\n', ses);
http ('		<xsd:element name="High" minOccurs="0" maxOccurs="1" type="xsd:int" />\n', ses);
http ('		<xsd:element name="Low" minOccurs="0" maxOccurs="1" type="xsd:int" />\n', ses);
http ('		<xsd:element name="Volume" minOccurs="0" maxOccurs="1" type="xsd:int" />\n', ses);
http ('		<xsd:element name="MarketCap" minOccurs="0" maxOccurs="1" type="xsd:int" />\n', ses);
http ('		<xsd:element name="PreviousClose" minOccurs="0" maxOccurs="1" type="xsd:float" />\n', ses);
http ('		<xsd:element name="PreviousChange" minOccurs="0" maxOccurs="1" type="xsd:float" />\n', ses);
http ('		<xsd:element name="Low52Week" minOccurs="0" maxOccurs="1" type="xsd:int" />\n', ses);
http ('		<xsd:element name="High52Week" minOccurs="0" maxOccurs="1" type="xsd:int" />\n', ses);
http ('		<xsd:element name="Name" minOccurs="0" maxOccurs="1" type="xsd:string" />\n', ses);
http ('	    </xsd:sequence>\n', ses);
http ('    </xsd:complexType>\n', ses);
http ('</xsd:schema>\n', ses);
  SOAP_LOAD_SCH (string_output_string (ses));
}
;

WSS_STOCK_XSD ()
;

create procedure
WSE_DEMO_TEMPLATE (in body varchar)
{
  declare tmpl, algo, key_name varchar;
  key_name := 'Client Private.pfx';
  algo := xenc_get_key_algo (key_name);
  if (algo is null)
    return NULL;
  tmpl := sprintf ('<?xml version="1.0" encoding="UTF-8"?>
<Signature xmlns="http://www.w3.org/2000/09/xmldsig#" >
  <SignedInfo>
    <CanonicalizationMethod Algorithm="http://www.w3.org/2001/10/xml-exc-c14n#" />
    <SignatureMethod Algorithm="%s" />
  </SignedInfo>
  <SignatureValue></SignatureValue>
  <KeyInfo>
    <KeyName>%s</KeyName>
  </KeyInfo>
</Signature>', algo, key_name);
  return dsig_template_ext (xtree_doc (body), tmpl, vector ('wsse', WSSE_OASIS_URI (),'wsu', WSSU_OASIS_URI()),
      'http://schemas.xmlsoap.org/soap/envelope/', 'Body',
 	'http://schemas.xmlsoap.org/ws/2004/03/addressing', 'From',
 	'http://schemas.xmlsoap.org/ws/2004/03/addressing', 'ReplyTo',
 	'http://schemas.xmlsoap.org/ws/2004/03/addressing', 'To',
 	'http://schemas.xmlsoap.org/ws/2004/03/addressing', 'Action',
 	'http://schemas.xmlsoap.org/ws/2004/03/addressing', 'MessageID',
 	WSSU_OASIS_URI(), 'Timestamp'
      );
}
;

