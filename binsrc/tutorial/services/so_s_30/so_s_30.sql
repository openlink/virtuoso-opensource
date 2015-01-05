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
create type SO_S_30 language java external name 'so_s_30'
  as (
      "varString" nvarchar,
      "varInt" integer external type 'I',
      "varFloat" real,
      "processingResult" nvarchar,
      "vmVersion" nvarchar external name 'javavmVersion')
  constructor method SO_S_30 (),
  method "process_data" () returns nvarchar
;

create type SO_S_30_2 language java external name 'so_s_30'
  as (
      "varString" nvarchar,
      "varInt" integer external type 'I',
      "varFloat" real,
      "processingResult" nvarchar,
      "vmVersion" nvarchar external name 'javavmVersion')
  constructor method SO_S_30_2 (),
  method "process_data" () returns nvarchar
;

grant execute on SO_S_30 to SOAPDEMO
;

grant execute on SO_S_30_2 to SOAPDEMO
;

soap_dt_define ('',
'<complexType name="SOAPJavaStruct"
   xmlns:enc="http://schemas.xmlsoap.org/soap/encoding/"
   xmlns:wsdl="http://schemas.xmlsoap.org/wsdl/"
   xmlns="http://www.w3.org/2001/XMLSchema"
   targetNamespace="services.wsdl"
   xmlns:tns="services.wsdl">
  <all>
    <element name="varString" type="string" nillable="true"/>
    <element name="varInt" type="int" nillable="true"/>
    <element name="varFloat" type="float" nillable="true"/>
    <element name="processingResult" type="string" nillable="true"/>
    <element name="vmVersion" type="string" nillable="true"/>
  </all>
</complexType>', 'SO_S_30')
;

create procedure "echoSOAPJavaStructSch" (
    in sst SO_S_30 __soap_type 'services.wsdl:SOAPJavaStruct')
returns SO_S_30 __soap_type 'services.wsdl:SOAPJavaStruct'
{
  declare procesingResult nvarchar;
  procesingResult := sst."process_data" ();
  return sst;
}
;

grant execute on "echoSOAPJavaStructSch" to SOAPDEMO
;

create procedure "echoSOAPJavaStructUdt" (
    in sst SO_S_30_2)
returns SO_S_30_2
{
  declare procesingResult nvarchar;
  procesingResult := sst."process_data" ();
  return sst;
}
;

grant execute on "echoSOAPJavaStructUdt" to SOAPDEMO
;
