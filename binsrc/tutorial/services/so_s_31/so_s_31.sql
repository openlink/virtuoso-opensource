--  
--  $Id$
--  
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--  
--  Copyright (C) 1998-2018 OpenLink Software
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
use DB;

drop type SO_S_31;
drop type SO_S_31_2;


create type DB.DBA.SO_S_31
  as (
      "varString" nvarchar default null,
      "varInt" integer default 0,
      "varFloat" real default 0,
      "processingResult" nvarchar default null,
      "vmVersion" nvarchar default null)
  method "process_data" () returns nvarchar
;

create method "process_data" () returns nvarchar for SO_S_31
{
  SELF."processingResult" := concat (
      N'processing varString=[',
      cast (SELF."varString" as nvarchar),
      N'] varInt =',
      cast (SELF."varInt" as nvarchar),
      N' varFloat=',
      cast (SELF."varFloat" as nvarchar));
  SELF."vmVersion" := N'Virtuoso PL';
--  dbg_printf ('%s\n', cast (SELF."vmVersion" as varchar));
  return SELF."processingResult";
}
;

create type SO_S_31_2
  as (
      "varString" nvarchar default null,
      "varInt" integer default 0,
      "varFloat" real default 0,
      "processingResult" nvarchar default null,
      "vmVersion" nvarchar default null)
  method "process_data" () returns nvarchar
;

grant execute on SO_S_31 to SOAPDEMO;
grant execute on SO_S_31_2 to SOAPDEMO;

create method "process_data" () returns nvarchar for SO_S_31_2
{
  SELF."processingResult" := concat (
      N'processing varString=[',
      cast (SELF."varString" as nvarchar),
      N'] varInt =',
      cast (SELF."varInt" as nvarchar),
      N' varFloat=',
      cast (SELF."varFloat" as nvarchar));
  SELF."vmVersion" := N'Virtuoso PL';
--  dbg_printf ('%s\n', cast (SELF."vmVersion" as varchar));
  return SELF."processingResult";
}
;

soap_dt_define ('',
'<complexType name="SOAPSQLStruct"
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
</complexType>', 'DB.DBA.SO_S_31')
;

create procedure "echoSOAPSQLStructSch" (
    in sst SO_S_31 __soap_type 'services.wsdl:SOAPSQLStruct')
returns SO_S_31 __soap_type 'services.wsdl:SOAPSQLStruct'
{
  declare procesingResult nvarchar;
  procesingResult := sst."process_data" ();
  return sst;
}
;

grant execute on "echoSOAPSQLStructSch" to SOAPDEMO
;

create procedure "echoSOAPSQLStructUdt" (
    in sst SO_S_31_2)
returns SO_S_31_2
{
  declare procesingResult nvarchar;
  procesingResult := sst."process_data" ();
  return sst;
}
;

grant execute on "echoSOAPSQLStructUdt" to SOAPDEMO
;
