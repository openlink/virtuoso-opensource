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
CREATE USER XML_A;
USER_SET_QUALIFIER ('XML_A', 'WS');
VHOST_DEFINE (vhost=>'*ini*',lhost=>'*ini*',lpath=>'/xml_a',ppath=>'/SOAP/',soap_user=>'XML_A');

DB..SOAP_DT_DEFINE ('VSXMLA.Discover.Result',
'<schema targetNamespace="http://tempuri.org/type"
         xmlns="http://www.w3.org/2001/XMLSchema"
	 xmlns:SOAP-ENC="http://schemas.xmlsoap.org/soap/encoding/"
	 xmlns:wsdl="http://schemas.xmlsoap.org/wsdl/"
	 elementFormDefault="qualified">
  <complexType  name ="VSXMLA.Discover.Result">
    <sequence>
      <any minOccurs="0" maxOccurs="unbounded" namespace="#any" processContents="skip"/>
    </sequence>
  </complexType>
</schema>');

DB..SOAP_DT_DEFINE ('VSXMLA.Discover.Restrictions',
'<schema targetNamespace="http://tempuri.org/type"
        xmlns="http://www.w3.org/2001/XMLSchema"
        xmlns:SOAP-ENC="http://schemas.xmlsoap.org/soap/encoding/"
	xmlns:wsdl="http://schemas.xmlsoap.org/wsdl/"
	elementFormDefault="qualified">
   <complexType  name ="VSXMLA.Discover.Restrictions">
     <sequence>
       <any minOccurs="0" maxOccurs="unbounded" namespace="#any" processContents="skip"/>
     </sequence>
   </complexType>
</schema>');

DB..SOAP_DT_DEFINE ('VSXMLA.Discover.Properties',
'<schema targetNamespace="http://tempuri.org/type"
        xmlns="http://www.w3.org/2001/XMLSchema"
        xmlns:SOAP-ENC="http://schemas.xmlsoap.org/soap/encoding/"
	xmlns:wsdl="http://schemas.xmlsoap.org/wsdl/"
	elementFormDefault="qualified">
  <complexType  name ="VSXMLA.Discover.Properties">
    <sequence>
      <any minOccurs="0" maxOccurs="unbounded" namespace="#any" processContents="skip"/>
    </sequence>
  </complexType>
</schema>');

DB..SOAP_DT_DEFINE ('VSXMLA.Execute.Result',
'<schema targetNamespace="http://tempuri.org/type"
        xmlns="http://www.w3.org/2001/XMLSchema"
        xmlns:SOAP-ENC="http://schemas.xmlsoap.org/soap/encoding/"
	xmlns:wsdl="http://schemas.xmlsoap.org/wsdl/"
	elementFormDefault="qualified">
  <complexType  name ="VSXMLA.Execute.Result">
    <sequence>
      <any minOccurs="0" maxOccurs="unbounded" namespace="#any" processContents="skip"/>
    </sequence>
  </complexType>
</schema>');

DB..SOAP_DT_DEFINE ('VSXMLA.Execute.Command',
'<schema targetNamespace="http://tempuri.org/type"
        xmlns="http://www.w3.org/2001/XMLSchema"
        xmlns:SOAP-ENC="http://schemas.xmlsoap.org/soap/encoding/"
	xmlns:wsdl="http://schemas.xmlsoap.org/wsdl/"
	elementFormDefault="qualified">
  <complexType  name ="VSXMLA.Execute.Command">
    <sequence>
      <any minOccurs="0" maxOccurs="unbounded" namespace="#any" processContents="skip"/>
    </sequence>
  </complexType>
</schema>');

DB..SOAP_DT_DEFINE ('VSXMLA.Execute.Properties',
'<schema targetNamespace="http://tempuri.org/type"
        xmlns="http://www.w3.org/2001/XMLSchema"
        xmlns:SOAP-ENC="http://schemas.xmlsoap.org/soap/encoding/"
	xmlns:wsdl="http://schemas.xmlsoap.org/wsdl/"
	elementFormDefault="qualified">
  <complexType  name ="VSXMLA.Execute.Properties">
    <sequence>
      <any minOccurs="0" maxOccurs="unbounded" namespace="#any" processContents="skip"/>
    </sequence>
  </complexType>
</schema>');

create procedure
"WS"."XML_A"."Discover" (in RequestType varchar,
			 in Restrictions any __soap_type 'VSXMLA.Discover.Restrictions',
			 in Properties any __soap_type 'VSXMLA.Discover.Properties',
			 out Response any __soap_type 'VSXMLA.Discover.Result')
{
  return (null);
}
;

create procedure
"WS"."XML_A"."Execute" (in Command any __soap_type 'VSXMLA.Execute.Command',
			in Properties any __soap_type 'VSXMLA.Execute.Properties',
			out Response any __soap_type 'VSXMLA.Execute.Result')
{
  return (null);
}
;

grant execute on "WS"."XML_A"."Discover" to XML_A;
grant execute on "WS"."XML_A"."Execute" to XML_A;
