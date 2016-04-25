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
-- round 2 B schema definition
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
FOREACH BLOB INSERT REPLACING DB.DBA.SYS_SOAP_DATATYPES(SDT_NAME,SDT_SCH,SDT_SOAP_SCH) VALUES('ArrayOfString2D',?,?);
<n0:complexType xmlns:n0="http://www.w3.org/2001/XMLSchema"  name="ArrayOfString2D">
                <n0:complexContent>
\11\11\11\11\11<n0:restriction base="http://schemas.xmlsoap.org/soap/encoding/:Array">
\11\11\11\11\11\11<n0:sequence>
          \11\11\11\11\11<n0:element name="item" type="string" minOccurs="0" maxOccurs="unbounded" nillable="true" />
\11\11  \11\11\11\11</n0:sequence>
 \11\11\11\11\11\11<n0:attributeGroup ref="http://schemas.xmlsoap.org/soap/encoding/:commonAttributes" />\11\11\11\11\11
\11\11\11\11\11\11<n0:attribute ref="http://schemas.xmlsoap.org/soap/encoding/:offset" />
\11                    <n0:attribute ref="http://schemas.xmlsoap.org/soap/encoding/:arrayType"  xmlns:n2="http://schemas.xmlsoap.org/wsdl/" n2:arrayType="string[\c
,]" />
\11\11\11\11\11</n0:restriction>
                </n0:complexContent>
            </n0:complexType>\c
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
FOREACH BLOB INSERT REPLACING DB.DBA.SYS_SOAP_DATATYPES(SDT_NAME,SDT_SCH,SDT_SOAP_SCH) VALUES('SOAPArrayStruct',?,?);
<n0:complexType xmlns:n0="http://www.w3.org/2001/XMLSchema"  name="SOAPArrayStruct">
\11\11\11\11<n0:all>
\11\11\11\11\11<n0:element name="varString" type="string" nillable="true" />
\11\11\11\11\11<n0:element name="varInt" type="int" nillable="true" />
\11\11\11\11\11<n0:element name="varFloat" type="float" nillable="true" />
\11\11\11\11\11<n0:element name="varArray" type="services.wsdl:ArrayOfstring" />
\11\11\11\11</n0:all>
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
FOREACH BLOB INSERT REPLACING DB.DBA.SYS_SOAP_DATATYPES(SDT_NAME,SDT_SCH,SDT_SOAP_SCH) VALUES('SOAPStructStruct',?,?);
<n0:complexType xmlns:n0="http://www.w3.org/2001/XMLSchema"  name="SOAPStructStruct">
\11\11\11\11<n0:all>
\11\11\11\11\11<n0:element name="varString" type="string" nillable="true" />
\11\11\11\11\11<n0:element name="varInt" type="int" nillable="true" />
\11\11\11\11\11<n0:element name="varFloat" type="float" nillable="true" />
\11\11\11\11\11<n0:element name="varStruct" type="services.wsdl:SOAPStruct" />
\11\11\11\11</n0:all>
\11\11\11</n0:complexType>\c
BLOB
END

select __soap_dt_define (SDT_NAME, xslt ('__soap_sch', xml_tree_doc(xml_tree(SDT_SCH)))) from DB.DBA.SYS_SOAP_DATATYPES;
-- Round 2 B methods

create procedure Interop.INTEROP.echoStructAsSimpleTypes (in inputStruct any __soap_type 'services.wsdl:SOAPStruct',
    out outputString varchar, out outputInteger integer, out outputFloat real)
{
  outputString := get_keyword ('varString',inputStruct);
  outputInteger := get_keyword ('varInt',inputStruct);
  outputFloat := get_keyword ('varFloat',inputStruct);
};

create procedure Interop.INTEROP.echoSimpleTypesAsStruct(in inputString varchar,in inputInteger integer,in inputFloat real)
   __soap_type 'services.wsdl:SOAPStruct'
{
  return soap_box_structure ('varString', inputString, 'varInt', inputInteger, 'varFloat', inputFloat);
};

create procedure Interop.INTEROP.echoNestedStruct (in inputStruct any __soap_type 'services.wsdl:SOAPStructStruct')
__soap_type 'services.wsdl:SOAPStructStruct'
{
  return inputStruct;
};

create procedure Interop.INTEROP.echoNestedArray (in inputStruct any __soap_type 'services.wsdl:SOAPArrayStruct')
__soap_type 'services.wsdl:SOAPArrayStruct'
{
  return inputStruct;
};

create procedure Interop.INTEROP.echo2DStringArray (in input2DStringArray any __soap_type 'services.wsdl:ArrayOfString2D')
__soap_type 'services.wsdl:ArrayOfString2D'
{
  return input2DStringArray;
};



grant execute on Interop.INTEROP.echoStructAsSimpleTypes to INTEROP;
grant execute on Interop.INTEROP.echoSimpleTypesAsStruct to INTEROP;
grant execute on Interop.INTEROP.echoNestedStruct to INTEROP;
grant execute on Interop.INTEROP.echoNestedArray to INTEROP;
grant execute on Interop.INTEROP.echo2DStringArray to INTEROP;
