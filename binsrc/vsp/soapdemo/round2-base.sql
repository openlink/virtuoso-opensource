--  
--  $Id$
--  
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--  
--  Copyright (C) 1998-2014 OpenLink Software
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
-- round 2 schema definition
FOREACH BLOB INSERT REPLACING DB.DBA.SYS_SOAP_DATATYPES(SDT_NAME,SDT_SCH,SDT_SOAP_SCH) VALUES('ArrayOfSOAPStruct',?,?);
<n0:complexType xmlns:n0="http://www.w3.org/2001/XMLSchema"  name="ArrayOfSOAPStruct">
\11\11\11\11<n0:complexContent>
\11\11\11\11\11<n0:restriction base="http://schemas.xmlsoap.org/soap/encoding/:Array">
\11\11\11\11\11\11<n0:sequence>
          \11\11\11\11\11<n0:element name="item" type="services.wsdl:SOAPStruct" minOccurs="0" maxOccurs="unbounded" />
\11\11  \11\11\11\11</n0:sequence>
 \11\11\11\11\11\11<n0:attributeGroup ref="http://schemas.xmlsoap.org/soap/encoding/:commonAttributes" />\11\11\11\11\11
\11\11\11\11\11\11<n0:attribute ref="http://schemas.xmlsoap.org/soap/encoding/:offset" />
\11\11\11\11\11\11<n0:attribute ref="http://schemas.xmlsoap.org/soap/encoding/:arrayType"  xmlns:n2="http://schemas.xmlsoap.org/wsdl/" n2:arrayType="services.wsdl:SOAPStruct[]" />
\11\11\11\11\11</n0:restriction>
\11\11\11\11</n0:complexContent>
\11\11\11</n0:complexType>\c
BLOB
END
FOREACH BLOB INSERT REPLACING DB.DBA.SYS_SOAP_DATATYPES(SDT_NAME,SDT_SCH,SDT_SOAP_SCH) VALUES('ArrayOffloat',?,?);
<n0:complexType xmlns:n0="http://www.w3.org/2001/XMLSchema"  name="ArrayOffloat">
\11\11\11\11<n0:complexContent>
\11\11\11\11\11<n0:restriction base="http://schemas.xmlsoap.org/soap/encoding/:Array">
\11\11\11\11\11\11<n0:sequence>
          \11\11\11\11\11<n0:element name="item" type="float" minOccurs="0" maxOccurs="unbounded" nillable="true" />
\11\11  \11\11\11\11</n0:sequence>
 \11\11\11\11\11\11<n0:attributeGroup ref="http://schemas.xmlsoap.org/soap/encoding/:commonAttributes" />\11\11\11\11\11
\11\11\11\11\11\11<n0:attribute ref="http://schemas.xmlsoap.org/soap/encoding/:offset" />
\11\11\11\11\11\11<n0:attribute ref="http://schemas.xmlsoap.org/soap/encoding/:arrayType"  xmlns:n2="http://schemas.xmlsoap.org/wsdl/" n2:arrayType="float[]" />
\11\11\11\11\11</n0:restriction>
\11\11\11\11</n0:complexContent>
\11\11\11</n0:complexType>\c
BLOB
END
FOREACH BLOB INSERT REPLACING DB.DBA.SYS_SOAP_DATATYPES(SDT_NAME,SDT_SCH,SDT_SOAP_SCH) VALUES('ArrayOfint',?,?);
<n0:complexType xmlns:n0="http://www.w3.org/2001/XMLSchema"  name="ArrayOfint">
\11\11\11\11<n0:complexContent>
\11\11\11\11\11<n0:restriction base="http://schemas.xmlsoap.org/soap/encoding/:Array">
\11\11\11\11\11\11<n0:sequence>
          \11\11\11\11\11<n0:element name="item" type="int" minOccurs="0" maxOccurs="unbounded" nillable="true" />
\11\11  \11\11\11\11</n0:sequence>
 \11\11\11\11\11\11<n0:attributeGroup ref="http://schemas.xmlsoap.org/soap/encoding/:commonAttributes" />\11\11\11\11\11
\11\11\11\11\11\11<n0:attribute ref="http://schemas.xmlsoap.org/soap/encoding/:offset" />
\11\11\11\11\11\11<n0:attribute ref="http://schemas.xmlsoap.org/soap/encoding/:arrayType"  xmlns:n2="http://schemas.xmlsoap.org/wsdl/" n2:arrayType="int[]" />
\11\11\11\11\11</n0:restriction>
\11\11\11\11</n0:complexContent>
\11\11\11</n0:complexType>\c
BLOB
END
FOREACH BLOB INSERT REPLACING DB.DBA.SYS_SOAP_DATATYPES(SDT_NAME,SDT_SCH,SDT_SOAP_SCH) VALUES('ArrayOfstring',?,?);
<n0:complexType xmlns:n0="http://www.w3.org/2001/XMLSchema"  name="ArrayOfstring">
\11\11\11\11<n0:complexContent>
\11\11\11\11\11<n0:restriction base="http://schemas.xmlsoap.org/soap/encoding/:Array">
\11\11\11\11\11\11<n0:sequence>
          \11\11\11\11\11<n0:element name="item" type="string" minOccurs="0" maxOccurs="unbounded" nillable="true" />
\11\11  \11\11\11\11</n0:sequence>
 \11\11\11\11\11\11<n0:attributeGroup ref="http://schemas.xmlsoap.org/soap/encoding/:commonAttributes" />\11\11\11\11\11
\11\11\11\11\11\11<n0:attribute ref="http://schemas.xmlsoap.org/soap/encoding/:offset" />
\11\11\11\11\11\11<n0:attribute ref="http://schemas.xmlsoap.org/soap/encoding/:arrayType"  xmlns:n2="http://schemas.xmlsoap.org/wsdl/" n2:arrayType="string[]" />
\11\11\11\11\11</n0:restriction>
\11\11\11\11</n0:complexContent>
\11\11\11</n0:complexType>\c
BLOB
END
FOREACH BLOB INSERT REPLACING DB.DBA.SYS_SOAP_DATATYPES(SDT_NAME,SDT_SCH,SDT_SOAP_SCH) VALUES('SOAPStruct',?,?);
<n0:complexType xmlns:n0="http://www.w3.org/2001/XMLSchema"  name="SOAPStruct">
\11\11\11\11<n0:all>
\11\11\11\11\11<n0:element name="varString" type="string" nillable="true" />
\11\11\11\11\11<n0:element name="varInt" type="int" nillable="true" />
\11\11\11\11\11<n0:element name="varFloat" type="float" nillable="true" />
\11\11\11\11</n0:all>
\11\11\11</n0:complexType>\c
BLOB
END

select __soap_dt_define (SDT_NAME, xslt ('__soap_sch', xml_tree_doc(xml_tree(SDT_SCH)))) from DB.DBA.SYS_SOAP_DATATYPES;

-- Round 2 methods
create procedure Interop.INTEROP.echoString (in inputString nvarchar) returns nvarchar
{
  --dbg_obj_print ('\nechoString', inputString, '\n');
  return inputString;
};

create procedure Interop.INTEROP.echoStringArray (in inputStringArray any __soap_type 'services.wsdl:ArrayOfstring')
__soap_type 'services.wsdl:ArrayOfstring'
{
  --dbg_obj_print ('\nechoStringArray', inputStringArray, '\n');
  return inputStringArray;
};

create procedure Interop.INTEROP.echoInteger (in inputInteger integer) returns integer
{
  --dbg_obj_print ('\nechoInteger', inputInteger, '\n');
  return inputInteger;
};

create procedure Interop.INTEROP.echoIntegerArray (in inputIntegerArray any __soap_type 'services.wsdl:ArrayOfint')
__soap_type 'services.wsdl:ArrayOfint'
{
  --dbg_obj_print ('\nechoIntegerArray', inputIntegerArray, '\n');
  return inputIntegerArray;
};

create procedure Interop.INTEROP.echoFloat (in inputFloat float __soap_type 'http://www.w3.org/2001/XMLSchema:float') returns float
__soap_type 'http://www.w3.org/2001/XMLSchema:float'
{
  --dbg_obj_print ('\nechoFloat', inputFloat, '\n');
  return inputFloat;
};

create procedure Interop.INTEROP.echoFloatArray (in inputFloatArray any __soap_type 'services.wsdl:ArrayOffloat')
__soap_type 'services.wsdl:ArrayOffloat'
{
  --dbg_obj_print ('\nechoFloatArray', inputFloatArray, '\n');
  return inputFloatArray;
};


create procedure Interop.INTEROP.echoStruct (in inputStruct any __soap_type 'services.wsdl:SOAPStruct')
__soap_type 'services.wsdl:SOAPStruct'
{
  --dbg_obj_print ('\nechoStruct', inputStruct, '\n');
  return inputStruct;
};


create procedure Interop.INTEROP.echoStructArray (in inputStructArray any __soap_type 'services.wsdl:ArrayOfSOAPStruct')
__soap_type 'services.wsdl:ArrayOfSOAPStruct'
{
  declare ses any;
  declare inx integer;
  --dbg_obj_print ('\nechoStructArray', inputStructArray, '\n');
  return inputStructArray;
};


create procedure Interop.INTEROP.echoVoid ()
{
  --dbg_obj_print ('\nechoVoid\n');
};

create procedure Interop.INTEROP.echoBase64 (in inputBase64 varchar __soap_type 'http://www.w3.org/2001/XMLSchema:base64Binary')
__soap_type 'http://www.w3.org/2001/XMLSchema:base64Binary'
{
  --dbg_obj_print ('\nechoBase64', inputBase64, '\n');
  return inputBase64;
};


create procedure Interop.INTEROP.echoHexBinary (in inputHexBinary varchar)
{
  --dbg_obj_print ('\nechoHexBinary', inputHexBinary, '\n');
  return inputHexBinary;
};


create procedure Interop.INTEROP.echoDate (in inputDate datetime) returns datetime
{
  --dbg_obj_print ('\nechoDate', inputDate, '\n');
  return inputDate;
};

create procedure Interop.INTEROP.echoDecimal (in inputDecimal numeric) returns numeric
{
  --dbg_obj_print ('\nechoDecimal', inputDecimal, '\n');
  return inputDecimal;
};


create procedure Interop.INTEROP.echoBoolean (in inputBoolean smallint __soap_type 'http://www.w3.org/2001/XMLSchema:boolean')
__soap_type 'http://www.w3.org/2001/XMLSchema:boolean'
{
  --dbg_obj_print ('\nechoBoolean', inputBoolean, '\n');
  return soap_boolean (inputBoolean);
};


DB.DBA.USER_CREATE ('INTEROP', 'interop', vector ('DISABLED', 1));

DB.DBA.user_set_qualifier ('INTEROP', 'Interop');


DB.DBA.VHOST_DEFINE (lpath=>'/Interop', ppath=>'/SOAP/', soap_user=>'INTEROP', soap_opts=>vector('SchemaNS','http://soapinterop.org/xsd','Namespace','http://soapinterop.org/','MethodInSoapAction','no', 'ServiceName', 'InteropTests'));

grant execute on Interop.INTEROP.echoString to INTEROP;
grant execute on Interop.INTEROP.echoStringArray to INTEROP;
grant execute on Interop.INTEROP.echoInteger to INTEROP;
grant execute on Interop.INTEROP.echoIntegerArray to INTEROP;
grant execute on Interop.INTEROP.echoFloat to INTEROP;
grant execute on Interop.INTEROP.echoFloatArray to INTEROP;
grant execute on Interop.INTEROP.echoStruct to INTEROP;
grant execute on Interop.INTEROP.echoStructArray to INTEROP;
grant execute on Interop.INTEROP.echoVoid to INTEROP;
grant execute on Interop.INTEROP.echoBase64 to INTEROP;
grant execute on Interop.INTEROP.echoHexBinary to INTEROP;
grant execute on Interop.INTEROP.echoDate to INTEROP;
grant execute on Interop.INTEROP.echoDecimal to INTEROP;
grant execute on Interop.INTEROP.echoBoolean to INTEROP;

