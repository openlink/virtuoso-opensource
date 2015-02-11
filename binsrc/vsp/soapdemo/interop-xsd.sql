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
select DB.DBA.soap_dt_define('','

<element xmlns="http://www.w3.org/2001/XMLSchema" name="echoStringArrayParam" targetNamespace="http://soapinterop.org/xsd" type="xsd1:ArrayOfstring_literal" xmlns:xsd1="http://soapinterop.org/xsd" />
');

select DB.DBA.soap_dt_define('','
<complexType name="ArrayOfstring_literal" xmlns="http://www.w3.org/2001/XMLSchema"  targetNamespace="http://soapinterop.org/xsd">
    <sequence>
        <element maxOccurs="unbounded" minOccurs="1" name="string" type="string"/>
    </sequence>
</complexType>
');

select DB.DBA.soap_dt_define('','

<element xmlns="http://www.w3.org/2001/XMLSchema" name="echoStringArrayReturn" targetNamespace="http://soapinterop.org/xsd" type="xsd1:ArrayOfstring_literal" xmlns:xsd1="http://soapinterop.org/xsd" />
');

select DB.DBA.soap_dt_define('','

			<element name="x_Document" type="typens:Document" targetNamespace="http://soapinterop.org/xsd" xmlns="http://www.w3.org/2001/XMLSchema" xmlns:typens="http://soapinterop.org/xsd" />
');

select DB.DBA.soap_dt_define('','

			<element name="result_Document" type="typens:Document" targetNamespace="http://soapinterop.org/xsd" xmlns="http://www.w3.org/2001/XMLSchema" xmlns:typens="http://soapinterop.org/xsd" />
');

select DB.DBA.soap_dt_define('','

<complexType name="Document"
xmlns="http://www.w3.org/2001/XMLSchema"
xmlns:xsd="http://www.w3.org/2001/XMLSchema"
targetNamespace="http://soapinterop.org/xsd"
>
<simpleContent>
<extension base="string">
<xsd:attribute name ="ID" type="string"/>
</extension>
</simpleContent>
</complexType>
');

select DB.DBA.soap_dt_define('','

<element  xmlns="http://www.w3.org/2001/XMLSchema" name="x_Employee" type="emp:Employee" targetNamespace = "http://soapinterop.org/employee" xmlns:emp="http://soapinterop.org/employee" />
');

select DB.DBA.soap_dt_define('','

			<complexType name="Person" xmlns="http://www.w3.org/2001/XMLSchema" targetNamespace="http://soapinterop.org/person">
				<sequence>
					<element minOccurs="1" maxOccurs="1" name="Name" type="string"/>
					<element minOccurs="1" maxOccurs="1" name="Male" type="boolean"/>
				</sequence>
			</complexType>
');

select DB.DBA.soap_dt_define('','

			<element xmlns="http://www.w3.org/2001/XMLSchema"  name="result_Employee" type="emp:Employee" targetNamespace = "http://soapinterop.org/employee" xmlns:emp="http://soapinterop.org/employee" />
');

select DB.DBA.soap_dt_define('','

      <complexType name="Header1"
xmlns="http://www.w3.org/2001/XMLSchema"
xmlns:types="http://soapinterop.org/xsd"
targetNamespace="http://soapinterop.org/xsd"
      >
        <sequence>
          <element name="string" type="string" />
          <element name="int" type="int" />
        </sequence>
	<anyAttribute />
      </complexType>
');

select DB.DBA.soap_dt_define('','

<element
xmlns="http://www.w3.org/2001/XMLSchema"
xmlns:types="http://soapinterop.org/xsd"
targetNamespace="http://soapinterop.org/xsd"

name="Header1" type="types:Header1" />
');

select DB.DBA.soap_dt_define('','

      <complexType name="Header2"
xmlns="http://www.w3.org/2001/XMLSchema"
xmlns:types="http://soapinterop.org/xsd"
targetNamespace="http://soapinterop.org/xsd"

      >
        <sequence>
          <element name="int" type="int" />
          <element name="string" type="string" />
        </sequence>
	<anyAttribute />
      </complexType>
');

select DB.DBA.soap_dt_define('','

<element
xmlns="http://www.w3.org/2001/XMLSchema"
xmlns:types="http://soapinterop.org/xsd"
targetNamespace="http://soapinterop.org/xsd"

name="Header2" type="types:Header2" />
');

select DB.DBA.soap_dt_define('','
<complexType name="ArrayOfstring" targetNamespace="http://soapinterop.org/xsd"
   xmlns:enc="http://schemas.xmlsoap.org/soap/encoding/"
   xmlns:wsdl="http://schemas.xmlsoap.org/wsdl/"
   xmlns="http://www.w3.org/2001/XMLSchema"
   xmlns:tns="http://soapinterop.org/xsd">
  <complexContent>
     <restriction base="enc:Array">
	<sequence>
	   <element name="item" type="string" minOccurs="0" maxOccurs="unbounded" nillable="true"/>
	</sequence>
	<attributeGroup ref="enc:commonAttributes"/>
	<attribute ref="enc:arrayType" wsdl:arrayType="string[]"/>
     </restriction>
  </complexContent>
</complexType>
');

select DB.DBA.soap_dt_define('','
<complexType name="ArrayOfint" targetNamespace="http://soapinterop.org/xsd"
   xmlns:enc="http://schemas.xmlsoap.org/soap/encoding/"
   xmlns:wsdl="http://schemas.xmlsoap.org/wsdl/"
   xmlns="http://www.w3.org/2001/XMLSchema"
   xmlns:tns="http://soapinterop.org/xsd">
<complexContent>
<restriction base="enc:Array">
  <sequence>
    <element name="item" type="int" minOccurs="0" maxOccurs="unbounded" nillable="true"/>
  </sequence>
<attribute ref="enc:arrayType" wsdl:arrayType="int[]"/>
<attributeGroup ref="enc:commonAttributes"/>
<attribute ref="enc:offset"/>
</restriction>
</complexContent>
</complexType>
');

select DB.DBA.soap_dt_define('','
<complexType name="ArrayOflong" targetNamespace="http://soapinterop.org/xsd"
   xmlns:enc="http://schemas.xmlsoap.org/soap/encoding/"
   xmlns:wsdl="http://schemas.xmlsoap.org/wsdl/"
   xmlns="http://www.w3.org/2001/XMLSchema"
   xmlns:tns="http://soapinterop.org/xsd">

   <complexContent>
   <restriction base="enc:Array">
   <sequence>
   <element name="item" type="long" minOccurs="0" maxOccurs="unbounded" nillable="true"/>
   </sequence>
   <attribute ref="enc:arrayType" wsdl:arrayType="long[]"/>
   <attributeGroup ref="enc:commonAttributes"/>
   <attribute ref="enc:offset"/>
   </restriction>
   </complexContent>
</complexType>
');

select DB.DBA.soap_dt_define('','
<complexType name="ArrayOffloat" targetNamespace="http://soapinterop.org/xsd"
   xmlns:enc="http://schemas.xmlsoap.org/soap/encoding/"
   xmlns:wsdl="http://schemas.xmlsoap.org/wsdl/"
   xmlns="http://www.w3.org/2001/XMLSchema"
   xmlns:tns="http://soapinterop.org/xsd">
   <complexContent>
   <restriction base="enc:Array">
   <sequence>
   <element name="item" type="float" minOccurs="0" maxOccurs="unbounded" nillable="true"/>
   </sequence>
   <attributeGroup ref="enc:commonAttributes"/>
   <attribute ref="enc:offset"/>
   <attribute ref="enc:arrayType" wsdl:arrayType="float[]"/>
   </restriction>
   </complexContent>
</complexType>
');

select DB.DBA.soap_dt_define('','
<complexType name="ArrayOfSOAPStruct" targetNamespace="http://soapinterop.org/xsd"
   xmlns:enc="http://schemas.xmlsoap.org/soap/encoding/"
   xmlns:wsdl="http://schemas.xmlsoap.org/wsdl/"
   xmlns="http://www.w3.org/2001/XMLSchema"
   xmlns:tns="http://soapinterop.org/xsd">

   <complexContent>
   <restriction base="enc:Array">
   <sequence>
   <element name="item" type="tns:SOAPStruct" minOccurs="0" maxOccurs="unbounded"/>
   </sequence>
   <attribute ref="enc:arrayType" wsdl:arrayType="tns:SOAPStruct[]"/>
   <attributeGroup ref="enc:commonAttributes"/>
   <attribute ref="enc:offset"/>
   </restriction>
   </complexContent>
</complexType>
');

select DB.DBA.soap_dt_define('','
<complexType name="SOAPStruct" targetNamespace="http://soapinterop.org/xsd"
   xmlns:enc="http://schemas.xmlsoap.org/soap/encoding/"
   xmlns:wsdl="http://schemas.xmlsoap.org/wsdl/"
   xmlns="http://www.w3.org/2001/XMLSchema"
   xmlns:tns="http://soapinterop.org/xsd">

   <all>
     <element name="varString" type="string" nillable="true"/>
     <element name="varInt" type="int" nillable="true"/>
     <element name="varFloat" type="float" nillable="true"/>
   </all>
</complexType>
');

select DB.DBA.soap_dt_define('','
<complexType name="ArrayOfString2D" targetNamespace="http://soapinterop.org/xsd"
   xmlns:enc="http://schemas.xmlsoap.org/soap/encoding/"
   xmlns:wsdl="http://schemas.xmlsoap.org/wsdl/"
   xmlns="http://www.w3.org/2001/XMLSchema">
   <complexContent>
     <restriction base="enc:Array">
        <sequence>
	  <element name="item" type="string" minOccurs="0" maxOccurs="unbounded" nillable="true" />
	</sequence>
        <attribute ref="enc:arrayType" wsdl:arrayType="string[,]" />
        <attribute ref="enc:offset"/>
     </restriction>
   </complexContent>
</complexType>
');

select DB.DBA.soap_dt_define('','
<complexType xmlns="http://www.w3.org/2001/XMLSchema"  name="SOAPArrayStruct" targetNamespace="http://soapinterop.org/xsd" >
<all>
  <element name="varString" type="string" nillable="true" />
  <element name="varInt" type="int" nillable="true" />
  <element name="varFloat" type="float" nillable="true" />
  <element name="varArray" type="http://soapinterop.org/xsd:ArrayOfstring" />
  </all>
</complexType>
');

select DB.DBA.soap_dt_define('','
<complexType xmlns="http://www.w3.org/2001/XMLSchema"  name="SOAPStructStruct" targetNamespace="http://soapinterop.org/xsd">
    <all>
     <element name="varString" type="string" nillable="true" />
     <element name="varInt" type="int" nillable="true" />
     <element name="varFloat" type="float" nillable="true" />
     <element name="varStruct" type="http://soapinterop.org/xsd:SOAPStruct" />
    </all>
</complexType>
');

select DB.DBA.soap_dt_define('','

	      <complexType  name ="ArrayOfSOAPStruct"
	      targetNamespace="http://soapinterop.org/xsd2"
	      xmlns="http://www.w3.org/2001/XMLSchema"
	      xmlns:SOAP-ENC="http://schemas.xmlsoap.org/soap/encoding/"
	      xmlns:wsdl = "http://schemas.xmlsoap.org/wsdl/"
	      xmlns:typens="http://soapinterop.org/xsd"
	      >
	        <complexContent>
        	  <restriction base="SOAP-ENC:Array">
            		<attribute ref="SOAP-ENC:arrayType" wsdl:arrayType="typens:SOAPStruct[]"/>
	          </restriction>
        	</complexContent>
	      </complexType>
');

select DB.DBA.soap_dt_define('','
            <complexType name="List"
	    targetNamespace="http://soapinterop.org/xsd"
	    xmlns:xsd1="http://soapinterop.org/xsd"
            xmlns="http://www.w3.org/2001/XMLSchema"
            xmlns:xsd="http://www.w3.org/2001/XMLSchema"

	    >
                <sequence>
                    <element name="varInt" type="xsd:int"/>
                    <element name="varString" type="xsd:string"/>
		    <element name="child" type = "xsd1:List"/>
                </sequence>
            </complexType>
');

select DB.DBA.soap_dt_define('','
<complexType xmlns="http://www.w3.org/2001/XMLSchema" name="Person" xmlns:xsd="http://www.w3.org/2001/XMLSchema" targetNamespace="http://soapinterop.org/xsd">
<sequence>
<element minOccurs="1" maxOccurs="1" name="Age" type="double"/>
<element minOccurs="1" maxOccurs="1" name="ID" type="xsd:float"/>
</sequence>
<attribute name="Name" type="string"/>
<attribute name="Male" type="boolean"/>
</complexType>


');

select DB.DBA.soap_dt_define('','

<element xmlns="http://www.w3.org/2001/XMLSchema" name="x_Person" targetNamespace="http://soapinterop.org/xsd" xmlns:pers="http://soapinterop.org/xsd" type="pers:Person" />
');

select DB.DBA.soap_dt_define('','

			<element  xmlns="http://www.w3.org/2001/XMLSchema" name="x_Person" type="pers:Person" targetNamespace = "http://soapinterop.org/person" xmlns:pers="http://soapinterop.org/person" />
');

select DB.DBA.soap_dt_define('','

			<complexType name="Employee" targetNamespace = "http://soapinterop.org/employee"
			xmlns="http://www.w3.org/2001/XMLSchema"
			xmlns:prs = "http://soapinterop.org/person">
				<sequence>
					<element minOccurs="1" maxOccurs="1" name="person" type="prs:Person"/>
					<element minOccurs="1" maxOccurs="1" name="salary" type="double"/>
					<element minOccurs="1" maxOccurs="1" name="ID" type="int"/>
				</sequence>
			</complexType>
');

select DB.DBA.soap_dt_define('','

<element xmlns="http://www.w3.org/2001/XMLSchema" name="result_Person" targetNamespace="http://soapinterop.org/xsd" xmlns:pers="http://soapinterop.org/xsd" type="pers:Person" />
');

select DB.DBA.soap_dt_define('','

			<element xmlns="http://www.w3.org/2001/XMLSchema"  name="result_Person" type="pers:Person" targetNamespace = "http://soapinterop.org/person" xmlns:pers="http://soapinterop.org/person" />
');

select DB.DBA.soap_dt_define('','

<element xmlns="http://www.w3.org/2001/XMLSchema" name="echoStructParam" targetNamespace="http://soapinterop.org/xsd" type="xsd1:SOAPStruct" xmlns:xsd1="http://soapinterop.org/xsd" />
');

select DB.DBA.soap_dt_define('','

<element xmlns="http://www.w3.org/2001/XMLSchema" name="echoStructReturn" targetNamespace="http://soapinterop.org/xsd" type="xsd1:SOAPStruct" xmlns:xsd1="http://soapinterop.org/xsd" />
');

select DB.DBA.soap_dt_define('','

            <element name="echoStringArray"
xmlns="http://www.w3.org/2001/XMLSchema"
xmlns:xsd1="http://soapinterop.org/xsd"
targetNamespace="http://soapinterop.org/xsd"
	    >
                <complexType>
                    <sequence>
                        <element name="param0" type="xsd1:ArrayOfstring_literal" form="unqualified"/>
                    </sequence>
                </complexType>
            </element>
');

select DB.DBA.soap_dt_define('','

            <element name="echoStringArrayResponse"
xmlns="http://www.w3.org/2001/XMLSchema"
xmlns:xsd1="http://soapinterop.org/xsd"
targetNamespace="http://soapinterop.org/xsd"
	    >
                <complexType>
                    <sequence>
                        <element name="return" type="xsd1:ArrayOfstring_literal" form="unqualified" />
                    </sequence>
                </complexType>
            </element>
');

select DB.DBA.soap_dt_define('','

<element
xmlns="http://www.w3.org/2001/XMLSchema"
name="echoStringParam"
targetNamespace="http://soapinterop.org/xsd"
type="string" />
');

select DB.DBA.soap_dt_define('','

<element xmlns="http://www.w3.org/2001/XMLSchema" name="echoStringReturn" targetNamespace="http://soapinterop.org/xsd" type="string" />
');

select DB.DBA.soap_dt_define('','

            <element name="echoString"
xmlns="http://www.w3.org/2001/XMLSchema"
xmlns:xsd="http://www.w3.org/2001/XMLSchema"
targetNamespace="http://soapinterop.org/xsd"

	    >
                <complexType>
                    <sequence>
                        <element name="param0" type="xsd:string" form="unqualified"/>
                    </sequence>
                </complexType>
            </element>
');

select DB.DBA.soap_dt_define('','

            <element name="echoStringResponse"
xmlns="http://www.w3.org/2001/XMLSchema"
xmlns:xsd="http://www.w3.org/2001/XMLSchema"
targetNamespace="http://soapinterop.org/xsd"

	    >
                <complexType>
                    <sequence>
                        <element name="return" type="xsd:string" form="unqualified" />
                    </sequence>
                </complexType>
            </element>
');

select DB.DBA.soap_dt_define('','
<complexType name="SOAPStruct" targetNamespace="http://soapinterop.org/xsd"
   xmlns:enc="http://schemas.xmlsoap.org/soap/encoding/"
   xmlns:wsdl="http://schemas.xmlsoap.org/wsdl/"
   xmlns="http://www.w3.org/2001/XMLSchema"
   xmlns:tns="http://soapinterop.org/xsd">

   <all>
     <element name="varString" type="string" nillable="true"/>
     <element name="varInt" type="int" nillable="true"/>
     <element name="varFloat" type="float" nillable="true"/>
   </all>
</complexType>
');

select DB.DBA.soap_dt_define('','

            <element name="echoStruct"
xmlns="http://www.w3.org/2001/XMLSchema"
xmlns:xsd1="http://soapinterop.org/xsd"
targetNamespace="http://soapinterop.org/xsd"
	    >
                <complexType>
                    <sequence>
                        <element name="param0" type="xsd1:SOAPStruct" form="unqualified" />
                    </sequence>
                </complexType>
            </element>
');

select DB.DBA.soap_dt_define('','

            <element name="echoStructResponse"
xmlns="http://www.w3.org/2001/XMLSchema"
xmlns:xsd1="http://soapinterop.org/xsd"
targetNamespace="http://soapinterop.org/xsd"
	    >
                <complexType>
                    <sequence>
                        <element name="return" type="xsd1:SOAPStruct" form="unqualified"/>
                    </sequence>
                </complexType>
            </element>
');

select DB.DBA.soap_dt_define('','

            <element name="echoVoid"
  		xmlns="http://www.w3.org/2001/XMLSchema"
		targetNamespace="http://soapinterop.org/xsd"
	    >
                <complexType/>
            </element>
');

select DB.DBA.soap_dt_define('','

            <element name="echoVoidResponse"
  		xmlns="http://www.w3.org/2001/XMLSchema"
		targetNamespace="http://soapinterop.org/xsd"
	    >
                <complexType/>
            </element>
');

