--
--  $Id: tsoap_rpc.sql,v 1.6.10.2 2013/01/02 16:15:27 source Exp $
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2017 OpenLink Software
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
select soap_dt_define('','

<element xmlns="http://www.w3.org/2001/XMLSchema" name="echoStringArrayParam" targetNamespace="http://soapinterop.org/xsd" type="xsd1:ArrayOfstring_literal" xmlns:xsd1="http://soapinterop.org/xsd" />
');

select soap_dt_define('','
<complexType name="ArrayOfstring_literal" xmlns="http://www.w3.org/2001/XMLSchema"  targetNamespace="http://soapinterop.org/xsd">
    <sequence>
        <element maxOccurs="unbounded" minOccurs="1" name="string" type="string"/>
    </sequence>
</complexType>
');

select soap_dt_define('','

<element xmlns="http://www.w3.org/2001/XMLSchema" name="echoStringArrayReturn" targetNamespace="http://soapinterop.org/xsd" type="xsd1:ArrayOfstring_literal" xmlns:xsd1="http://soapinterop.org/xsd" />
');

select soap_dt_define('','

			<element name="x_Document" type="typens:Document" targetNamespace="http://soapinterop.org/xsd" xmlns="http://www.w3.org/2001/XMLSchema" xmlns:typens="http://soapinterop.org/xsd" />
');

select soap_dt_define('','

			<element name="result_Document" type="typens:Document" targetNamespace="http://soapinterop.org/xsd" xmlns="http://www.w3.org/2001/XMLSchema" xmlns:typens="http://soapinterop.org/xsd" />
');

select soap_dt_define('','

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

select soap_dt_define('','

<element  xmlns="http://www.w3.org/2001/XMLSchema" name="x_Employee" type="emp:Employee" targetNamespace = "http://soapinterop.org/employee" xmlns:emp="http://soapinterop.org/employee" />
');

select soap_dt_define('','

			<complexType name="Person" xmlns="http://www.w3.org/2001/XMLSchema" targetNamespace="http://soapinterop.org/person">
				<sequence>
					<element minOccurs="1" maxOccurs="1" name="Name" type="string"/>
					<element minOccurs="1" maxOccurs="1" name="Male" type="boolean"/>
				</sequence>
			</complexType>
');

select soap_dt_define('','

			<element xmlns="http://www.w3.org/2001/XMLSchema"  name="result_Employee" type="emp:Employee" targetNamespace = "http://soapinterop.org/employee" xmlns:emp="http://soapinterop.org/employee" />
');

select soap_dt_define('','

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

select soap_dt_define('','

<element
xmlns="http://www.w3.org/2001/XMLSchema"
xmlns:types="http://soapinterop.org/xsd"
targetNamespace="http://soapinterop.org/xsd"

name="Header1" type="types:Header1" />
');

select soap_dt_define('','

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

select soap_dt_define('','

<element
xmlns="http://www.w3.org/2001/XMLSchema"
xmlns:types="http://soapinterop.org/xsd"
targetNamespace="http://soapinterop.org/xsd"

name="Header2" type="types:Header2" />
');

select soap_dt_define('','
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

select soap_dt_define('','
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

select soap_dt_define('','
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

select soap_dt_define('','
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

select soap_dt_define('','
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

select soap_dt_define('','
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

select soap_dt_define('','
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
        <attribute ref="soapenc:offset"/>
     </restriction>
   </complexContent>
</complexType>
');

select soap_dt_define('','
<complexType xmlns="http://www.w3.org/2001/XMLSchema"  name="SOAPArrayStruct" targetNamespace="http://soapinterop.org/xsd" >
<all>
  <element name="varString" type="string" nillable="true" />
  <element name="varInt" type="int" nillable="true" />
  <element name="varFloat" type="float" nillable="true" />
  <element name="varArray" type="http://soapinterop.org/xsd:ArrayOfstring" />
  </all>
</complexType>
');

select soap_dt_define('','
<complexType xmlns="http://www.w3.org/2001/XMLSchema"  name="SOAPStructStruct" targetNamespace="http://soapinterop.org/xsd">
    <all>
     <element name="varString" type="string" nillable="true" />
     <element name="varInt" type="int" nillable="true" />
     <element name="varFloat" type="float" nillable="true" />
     <element name="varStruct" type="http://soapinterop.org/xsd:SOAPStruct" />
    </all>
</complexType>
');

select soap_dt_define('','

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

select soap_dt_define('','
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

select soap_dt_define('','
<complexType xmlns="http://www.w3.org/2001/XMLSchema" name="Person" xmlns:xsd="http://www.w3.org/2001/XMLSchema" targetNamespace="http://soapinterop.org/xsd">
<sequence>
<element minOccurs="1" maxOccurs="1" name="Age" type="double"/>
<element minOccurs="1" maxOccurs="1" name="ID" type="xsd:float"/>
</sequence>
<attribute name="Name" type="string"/>
<attribute name="Male" type="boolean"/>
</complexType>


');

select soap_dt_define('','

<element xmlns="http://www.w3.org/2001/XMLSchema" name="x_Person" targetNamespace="http://soapinterop.org/xsd" xmlns:pers="http://soapinterop.org/xsd" type="pers:Person" />
');

select soap_dt_define('','

			<element  xmlns="http://www.w3.org/2001/XMLSchema" name="x_Person" type="pers:Person" targetNamespace = "http://soapinterop.org/person" xmlns:pers="http://soapinterop.org/person" />
');

select soap_dt_define('','

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

select soap_dt_define('','

<element xmlns="http://www.w3.org/2001/XMLSchema" name="echoPersonReturn" targetNamespace="http://soapinterop.org/xsd" xmlns:pers="http://soapinterop.org/xsd" type="pers:Person" />
');

select soap_dt_define('','

			<element xmlns="http://www.w3.org/2001/XMLSchema"  name="result_Person" type="pers:Person" targetNamespace = "http://soapinterop.org/person" xmlns:pers="http://soapinterop.org/person" />
');

select soap_dt_define('','

<element xmlns="http://www.w3.org/2001/XMLSchema" name="echoStructParam" targetNamespace="http://soapinterop.org/xsd" type="xsd1:SOAPStruct" xmlns:xsd1="http://soapinterop.org/xsd" />
');

select soap_dt_define('','

<element xmlns="http://www.w3.org/2001/XMLSchema" name="echoStructReturn" targetNamespace="http://soapinterop.org/xsd" type="xsd1:SOAPStruct" xmlns:xsd1="http://soapinterop.org/xsd" />
');

select soap_dt_define('','

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

select soap_dt_define('','

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

select soap_dt_define('','

<element
xmlns="http://www.w3.org/2001/XMLSchema"
name="echoStringParam"
targetNamespace="http://soapinterop.org/xsd"
type="string" />
');

select soap_dt_define('','

<element xmlns="http://www.w3.org/2001/XMLSchema" name="echoStringReturn" targetNamespace="http://soapinterop.org/xsd" type="string" />
');

select soap_dt_define('','

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

select soap_dt_define('','

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

select soap_dt_define('','
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

select soap_dt_define('','

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

select soap_dt_define('','

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

select soap_dt_define('','

            <element name="echoVoid"
  		xmlns="http://www.w3.org/2001/XMLSchema"
		targetNamespace="http://soapinterop.org/xsd"
	    >
                <complexType/>
            </element>
');

select soap_dt_define('','

            <element name="echoVoidResponse"
  		xmlns="http://www.w3.org/2001/XMLSchema"
		targetNamespace="http://soapinterop.org/xsd"
	    >
                <complexType/>
            </element>
');

create user INTEROP;

user_set_password ('INTEROP', 'interop');

user_set_qualifier ('INTEROP', 'Interop');


VHOST_REMOVE (lpath=>'/Interop');

VHOST_DEFINE (lpath=>'/Interop', ppath=>'/SOAP/', soap_user=>'INTEROP', soap_opts=>vector('Namespace','http://soapinterop.org/','MethodInSoapAction','no', 'ServiceName', 'InteropTests', 'HeaderNS', 'http://soapinterop.org/echoheader/', 'CR-escape', 'yes'));


use Interop;

create procedure
INTEROP.echoString (
    in inputString nvarchar __soap_type 'http://www.w3.org/2001/XMLSchema:string'
    )
returns nvarchar
__soap_type 'http://www.w3.org/2001/XMLSchema:string'
{
  --##This method accepts a single string and echoes it back to the client.
  dbg_obj_print ('\nechoString', inputString, '\n');
  return inputString;
};

create procedure
INTEROP.echoStringArray (
    in inputStringArray any __soap_type 'http://soapinterop.org/xsd:ArrayOfstring')
__soap_type 'http://soapinterop.org/xsd:ArrayOfstring'
{
  --##This method accepts an array of strings and echoes it back to the client.
  dbg_obj_print ('\nechoStringArray', inputStringArray, '\n');
  return inputStringArray;
};

create procedure
INTEROP.echoInteger (in inputInteger integer) returns integer
{
  --##This method accepts an single integer and echoes it back to the client.
  dbg_obj_print ('\nechoInteger', inputInteger, '\n');
  return inputInteger;
};

create procedure
INTEROP.echoIntegerArray (
    in inputIntegerArray any __soap_type 'http://soapinterop.org/xsd:ArrayOfint')
__soap_type 'http://soapinterop.org/xsd:ArrayOfint'
{
  --##This method accepts an array of integers and echoes it back to the client.
  dbg_obj_print ('\nechoIntegerArray', inputIntegerArray, '\n');
  return inputIntegerArray;
};

create procedure
INTEROP.echoFloat (
    in inputFloat float __soap_type 'http://www.w3.org/2001/XMLSchema:float')
returns float
__soap_type 'http://www.w3.org/2001/XMLSchema:float'
{
  --##This method accepts a single float and echoes it back to the client.
  dbg_obj_print ('\nechoFloat', inputFloat, '\n');
  return inputFloat;
};

create procedure
INTEROP.echoFloatArray (
    in inputFloatArray any __soap_type 'http://soapinterop.org/xsd:ArrayOffloat')
__soap_type 'http://soapinterop.org/xsd:ArrayOffloat'
{
  --##This method accepts an array of floats and echoes it back to the client.
  dbg_obj_print ('\nechoFloatArray', inputFloatArray, '\n');
  return inputFloatArray;
};


create procedure
INTEROP.echoStruct (
    in inputStruct any __soap_type 'http://soapinterop.org/xsd:SOAPStruct')
__soap_type 'http://soapinterop.org/xsd:SOAPStruct'
{
  --##This method accepts a single structure and echoes it back to the client.
  dbg_obj_print ('\nechoStruct', inputStruct, '\n');
  return inputStruct;
};


create procedure
INTEROP.echoStructArray (
    in inputStructArray any __soap_type 'http://soapinterop.org/xsd:ArrayOfSOAPStruct')
__soap_type 'http://soapinterop.org/xsd:ArrayOfSOAPStruct'
{
  declare ses any;
  declare inx integer;
  --##This method accepts an array of  structures and echoes it back to the client.
  dbg_obj_print ('\nechoStructArray', inputStructArray, '\n');
  return inputStructArray;
};


create procedure
INTEROP.echoBase64 (
    in inputBase64 varchar __soap_type 'http://www.w3.org/2001/XMLSchema:base64Binary')
__soap_type 'http://www.w3.org/2001/XMLSchema:base64Binary'
{
  --##This methods accepts a hex encoded object and echoes it back to the client.
  dbg_obj_print ('\nechoBase64', inputBase64, '\n');
  return inputBase64;
};


create procedure
INTEROP.echoHexBinary (in inputHexBinary varchar
    __soap_type 'http://www.w3.org/2001/XMLSchema:hexBinary')
__soap_type 'http://www.w3.org/2001/XMLSchema:hexBinary'
{
  --##This methods accepts a binary object and echoes it back to the client.
  dbg_obj_print ('\nechoHexBinary', inputHexBinary, '\n');
  return inputHexBinary;
};


create procedure
INTEROP.echoDate (in inputDate datetime) returns datetime
{
  --##This method accepts a Date/Time and echoes it back to the client.
  dbg_obj_print ('\nechoDate', inputDate, '\n');
  return inputDate;
};

create procedure
INTEROP.echoDecimal (in inputDecimal numeric) returns numeric
{
  --##This method accepts a decimal and echoes it back to the client.
  dbg_obj_print ('\nechoDecimal', inputDecimal, '\n');
  return inputDecimal;
};


create procedure
INTEROP.echoBoolean (
    in inputBoolean smallint __soap_type 'http://www.w3.org/2001/XMLSchema:boolean')
__soap_type 'http://www.w3.org/2001/XMLSchema:boolean'
{
  --##This method accepts a boolean and echoes it back to the client.
  dbg_obj_print ('\nechoBoolean', inputBoolean, '\n');
  return soap_boolean (inputBoolean);
};

create procedure
INTEROP.echoDuration (
    in inputDuration varchar __soap_type 'http://www.w3.org/2001/XMLSchema:duration')
returns varchar
__soap_type 'http://www.w3.org/2001/XMLSchema:duration'
{
  --##This method accepts a duration and echoes it back to the client.
  dbg_obj_print ('\nechoDuration', inputDuration, '\n');
  return inputDuration;
};


-- round 2 B
create procedure
INTEROP.echoStructAsSimpleTypes (
    in inputStruct any __soap_type 'http://soapinterop.org/xsd:SOAPStruct',
    out outputString varchar,
    out outputInteger integer,
    out outputFloat real __soap_type 'http://www.w3.org/2001/XMLSchema:float')
__soap_type '__VOID__'
{
  --##This method accepts a single struct and echoes it back to the client decomposed into three output parameters
  outputString := get_keyword ('varString',inputStruct);
  outputInteger := get_keyword ('varInt',inputStruct);
  outputFloat := get_keyword ('varFloat',inputStruct);
};

create procedure INTEROP.echoSimpleTypesAsStruct (
    in inputString varchar,in inputInteger integer,in inputFloat real)
   __soap_type 'http://soapinterop.org/xsd:SOAPStruct'
{
  --##This method accepts three input parameters and echoes them back to the client incorporated into a single struct.
  return soap_box_structure ('varString', inputString, 'varInt', inputInteger, 'varFloat', inputFloat);
};

create procedure INTEROP.echoNestedStruct (
    in inputStruct any __soap_type 'http://soapinterop.org/xsd:SOAPStructStruct')
__soap_type 'http://soapinterop.org/xsd:SOAPStructStruct'
{
  --##This method accepts a single struct with a nested struct type member and echoes it back to the client.
  return inputStruct;
};

create procedure INTEROP.echoNestedArray (in inputStruct any __soap_type 'http://soapinterop.org/xsd:SOAPArrayStruct')
__soap_type 'http://soapinterop.org/xsd:SOAPArrayStruct'
{
  --##This method accepts a single struct with a nested Array type member and echoes it back to the client.
  return inputStruct;
};

create procedure INTEROP.echo2DStringArray (in input2DStringArray any __soap_type 'http://soapinterop.org/xsd:ArrayOfString2D')
__soap_type 'http://soapinterop.org/xsd:ArrayOfString2D'
{
  --##This method accepts an single 2 dimensional array of xsd:string and echoes it back to the client.
  return input2DStringArray;
};

create procedure
INTEROP.echoVoid
   (
     in echoMeStringRequest nvarchar := NULL __soap_header 'http://www.w3.org/2001/XMLSchema:string',
     out echoMeStringResponse nvarchar := NULL __soap_header 'http://www.w3.org/2001/XMLSchema:string',
     in echoMeStructRequest any := NULL __soap_header 'http://soapinterop.org/xsd:SOAPStruct',
     out echoMeStructResponse any := NULL __soap_header 'http://soapinterop.org/xsd:SOAPStruct'
   )

   __soap_type '__VOID__'
{
  dbg_obj_print ('\nechoVoid\n', echoMeStructRequest);
  --##This method exists to test the "void" return case.  It accepts no arguments, and returns no arguments.
  if (echoMeStructRequest is not null)
    echoMeStructResponse := echoMeStructRequest;
  else if (echoMeStringRequest is not null)
    echoMeStringResponse := echoMeStringRequest;
  return;
};


grant execute on Interop.INTEROP.echoString to INTEROP;
grant execute on Interop.INTEROP.echoStringArray to INTEROP;
grant execute on Interop.INTEROP.echoInteger to INTEROP;
grant execute on Interop.INTEROP.echoIntegerArray to INTEROP;
grant execute on Interop.INTEROP.echoFloat to INTEROP;
grant execute on Interop.INTEROP.echoFloatArray to INTEROP;
grant execute on Interop.INTEROP.echoStruct to INTEROP;
grant execute on Interop.INTEROP.echoStructArray to INTEROP;
grant execute on Interop.INTEROP.echoBase64 to INTEROP;
grant execute on Interop.INTEROP.echoHexBinary to INTEROP;
grant execute on Interop.INTEROP.echoDate to INTEROP;
grant execute on Interop.INTEROP.echoDecimal to INTEROP;
grant execute on Interop.INTEROP.echoBoolean to INTEROP;
grant execute on Interop.INTEROP.echoDuration to INTEROP;
grant execute on Interop.INTEROP.echoStructAsSimpleTypes to INTEROP;
grant execute on Interop.INTEROP.echoSimpleTypesAsStruct to INTEROP;
grant execute on Interop.INTEROP.echoNestedStruct to INTEROP;
grant execute on Interop.INTEROP.echoNestedArray to INTEROP;
grant execute on Interop.INTEROP.echo2DStringArray to INTEROP;
grant execute on Interop.INTEROP.echoVoid to INTEROP;

use DB;

ECHO BOTH "STARTED: SOAP Interop II tests\n";

SET ARGV[0] 0;
SET ARGV[1] 0;

drop module InteropTests;

SOAP_WSDL_IMPORT ('http://localhost:$U{HTTPPORT}/Interop/services.wsdl');
ECHO BOTH $IF $EQU $STATE OK "PASSED" "*** FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": The Interop II tests Imported STATE=" $STATE " MESSAGE=" $MESSAGE "\n";


-- VOID operation
select xml_tree_doc (InteropTests.echoVoid ());
ECHO BOTH $IF $EQU $STATE OK "PASSED" "*** FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": echoVoid () STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

-- XSD types
select soap_box_xml_entity_validating (aref(InteropTests.echoString('This is a test'),1), 'string');
ECHO BOTH $IF $EQU $LAST[1] 'This is a test' "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": InteropTests.echoString : " $LAST[1] "\n";

select soap_box_xml_entity_validating (aref(InteropTests.echoFloat(cast(3.14 as float)),1), 'float');
ECHO BOTH $IF $EQU $LAST[1] '3.14' "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": InteropTests.echoFloat : " $LAST[1] "\n";

select soap_box_xml_entity_validating (aref(InteropTests.echoFloat(cast(1e40 as float)),1), 'float');
ECHO BOTH $IF $EQU $LAST[1] '1e+40' "PASSED" $if $EQU $LAST[1] '1e+040' "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": InteropTests.echoFloat : " $LAST[1] "\n";

select soap_box_xml_entity_validating (aref(InteropTests.echoInteger(123456789),1), 'integer');
ECHO BOTH $IF $EQU $LAST[1] '123456789' "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": InteropTests.echoInteger : " $LAST[1] "\n";

select soap_box_xml_entity_validating (aref(InteropTests.echoDuration('100'),1), 'duration');
ECHO BOTH $IF $EQU $LAST[1] '100' "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": InteropTests.echoDuration : " $LAST[1] "\n";

select soap_box_xml_entity_validating (aref(InteropTests.echoDecimal(cast (1456789.3456 as decimal)),1),'decimal');
ECHO BOTH $IF $EQU $LAST[1] '1456789.3456' "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": InteropTests.echoDecimal : " $LAST[1] "\n";

select soap_box_xml_entity_validating (aref(InteropTests.echoBoolean(soap_boolean (1)),1), 'boolean');
ECHO BOTH $IF $EQU $LAST[1] '1' "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": InteropTests.echoBoolean (true) : " $LAST[1] "\n";

select soap_box_xml_entity_validating (aref(InteropTests.echoBoolean(soap_boolean (0)),1), 'boolean');
ECHO BOTH $IF $EQU $LAST[1] '0' "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": InteropTests.echoBoolean (false) : " $LAST[1] "\n";

select soap_box_xml_entity_validating (aref(InteropTests.echoDate(stringdate ('1999-01-12 14:56:45')),1), 'dateTime');
ECHO BOTH $IF $EQU $LAST[1] '1999-01-12 14:56:45' "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": InteropTests.echoDate : " $LAST[1] "\n";

select soap_box_xml_entity_validating (aref(InteropTests.echoHexBinary('0340465465645'),1), 'hexBinary');
ECHO BOTH $IF $EQU $LAST[1] '0340465465645' "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": InteropTests.echoHexBinary : " $LAST[1] "\n";

select soap_box_xml_entity_validating (aref(InteropTests.echoBase64('dGhpcyBpcyBhIHRlc3Q='),1), 'base64Binary');
ECHO BOTH $IF $EQU $LAST[1] 'dGhpcyBpcyBhIHRlc3Q=' "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": InteropTests.echoBase64 : " $LAST[1] "\n";



-- Arrays
select aref(soap_box_xml_entity_validating (aref(InteropTests.echoStringArray (vector ('This','is','a','test','.')), 1), 'http://soapinterop.org/xsd:ArrayOfstring'),3);
ECHO BOTH $IF $EQU $LAST[1] 'test' "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": InteropTests.echoStringArray (4-th element) : " $LAST[1] "\n";

select length(soap_box_xml_entity_validating (aref (InteropTests.echoStringArray (vector ()),1), 'http://soapinterop.org/xsd:ArrayOfstring'));
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": InteropTests.echoStringArray (empty) : " $LAST[1] "\n";


select length(soap_box_xml_entity_validating (aref (InteropTests.echoStringArray (NULL),1), 'http://soapinterop.org/xsd:ArrayOfstring'));
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": InteropTests.echoStringArray (nil) : " $LAST[1] "\n";



select aref(soap_box_xml_entity_validating (aref (InteropTests.echoIntegerArray (vector (1,2,3,4,5,6,7,8,9)), 1), 'http://soapinterop.org/xsd:ArrayOfint'), 6);
ECHO BOTH $IF $EQU $LAST[1] 7 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": InteropTests.echoIntegerArray (7-th element) : " $LAST[1] "\n";

select aref(soap_box_xml_entity_validating (aref  (InteropTests.echoFloatArray (vector (cast(3.14 as float), cast(1.34 as float), cast(4.5 as float))), 1), 'http://soapinterop.org/xsd:ArrayOffloat'), 1);
ECHO BOTH $IF $EQU $LAST[1] 1.34 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": InteropTests.echoFloatArray (2-th element) : " $LAST[1] "\n";

select get_keyword ('varString', soap_box_xml_entity_validating (aref (InteropTests.echoStruct (soap_box_structure ('varString', 'This is a test', 'varInt', 123,'varFloat', cast(3.14 as float))), 1), 'http://soapinterop.org/xsd:SOAPStruct'), NULL);
ECHO BOTH $IF $EQU $LAST[1] 'This is a test' "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": InteropTests.echoStruct (varString element) : " $LAST[1] "\n";

select get_keyword ('varInt', soap_box_xml_entity_validating (aref (InteropTests.echoStruct (soap_box_structure ('varString', 'This is a test', 'varInt', 123,'varFloat', cast(3.14 as float))), 1), 'http://soapinterop.org/xsd:SOAPStruct'), NULL);
ECHO BOTH $IF $EQU $LAST[1] '123' "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": InteropTests.echoStruct (varInt element) : " $LAST[1] "\n";

select get_keyword ('varFloat', soap_box_xml_entity_validating (aref (InteropTests.echoStruct (soap_box_structure ('varString', 'This is a test', 'varInt', 123,'varFloat', cast(3.14 as float))), 1), 'http://soapinterop.org/xsd:SOAPStruct'), NULL);
ECHO BOTH $IF $EQU $LAST[1] '3.14' "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": InteropTests.echoStruct (varFloat element) : " $LAST[1] "\n";


select length (soap_box_xml_entity_validating (aref (InteropTests.echoStruct (null), 1), 'http://soapinterop.org/xsd:SOAPStruct'));
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": InteropTests.echoStruct (nil) : " $LAST[1] "\n";


select soap_box_xml_entity_validating (aref (InteropTests.echoStructAsSimpleTypes (soap_box_structure ('varString', 'This is a test', 'varInt',         123,'varFloat', cast(3.14 as float))),1), 'string');
ECHO BOTH $IF $EQU $LAST[1] 'This is a test' "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": InteropTests.echoStructAsSimpleTypes (varString element) : " $LAST[1] "\n";


select get_keyword ('varString', aref(soap_box_xml_entity_validating (aref (InteropTests.echoStructArray (vector (soap_box_structure ('varString', 'This is a test', 'varInt', 123,'varFloat', cast(3.14 as float)),soap_box_structure ('varString', 'This is a test', 'varInt', 123,'varFloat', cast(3.14 as float)))),1), 'http://soapinterop.org/xsd:ArrayOfSOAPStruct'), 0), NULL);

ECHO BOTH $IF $EQU $LAST[1] 'This is a test' "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": InteropTests.echoStructArray (varString element of 1-st item) : " $LAST[1] "\n";


select get_keyword ('varInt', soap_box_xml_entity_validating (aref  (InteropTests.echoSimpleTypesAsStruct ('This is a test', 234, cast(3.14 as float)) , 1), 'http://soapinterop.org/xsd:SOAPStruct'), NULL);

ECHO BOTH $IF $EQU $LAST[1] '234' "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": InteropTests.echoSimpleTypesAsStruct (varInt element) : " $LAST[1] "\n";


select get_keyword ('varInt', get_keyword('varStruct',soap_box_xml_entity_validating( aref (InteropTests.echoNestedStruct (
      soap_box_structure ('varString','This is a test','varInt', 123,'varFloat', cast(3.14 as float), 'varStruct',
	soap_box_structure ('varString', 'This is a test', 'varInt', 456, 'varFloat', cast(3.14 as float)))), 1),
       'http://soapinterop.org/xsd:SOAPStructStruct'), NULL), NULL);
ECHO BOTH $IF $EQU $LAST[1] '456' "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": InteropTests.echoNestedStruct (varInt element, nested child) : " $LAST[1] "\n";


select aref(get_keyword('varArray',soap_box_xml_entity_validating( aref (InteropTests.echoNestedArray (soap_box_structure ('varString', 'This is a test', 'varInt', 123,        'varFloat', cast(3.14 as float), 'varArray', vector ('This', 'is', 'a test'))),1), 'http://soapinterop.org/xsd:SOAPArrayStruct'), NULL), 2);
ECHO BOTH $IF $EQU $LAST[1] 'a test' "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": InteropTests.echoNestedArray (4-th element, nested child array) : " $LAST[1] "\n";


select aref(aref(soap_box_xml_entity_validating( aref (InteropTests.echo2DStringArray (vector (vector ('r1c1', 'r1c2'), vector ('r2c1','r2c2'), vector ('r3c1','r3c2'))), 1), 'http://soapinterop.org/xsd:ArrayOfString2D'), 1), 1);

ECHO BOTH $IF $EQU $LAST[1] 'r2c2' "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": InteropTests.echo2DStringArray (row 2 col 2 element) : " $LAST[1] "\n";


ECHO BOTH "COMPLETED WITH " $ARGV[0] " FAILED, " $ARGV[1] " PASSED: SOAP Interop II tests\n";
