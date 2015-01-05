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
use DB;

create procedure get_assembly_physical_path (in assembly_name varchar, in class_name varchar)
{
  declare ht_path, sl, current_loc, pwd varchar;
  ht_path := http_physical_path ();
  sl := strrchr (ht_path, '/');
  current_loc := substring (ht_path, 1, sl);
  pwd := concat (TUTORIAL_ROOT_DIR(), current_loc);
  return concat (replace (pwd, '\\', '/'), '/', assembly_name, '/', class_name);
}
;

exec (sprintf ('
create type DB.DBA.SO_S_32 language CLR external name ''%s''
  as (
      "varString" nvarchar external type ''String'',
      "varInt" integer external type ''Int32'',
      "varFloat" real external type ''Single'',
      "processingResult" nvarchar external type ''String'',
      "vmVersion" nvarchar external name ''clrVersion'' external type ''String'')
  constructor method SO_S_32 (),
  method "process_data" () returns nvarchar external type ''String''
', get_assembly_physical_path ('so_s_32.dll', 'so_s_32')))
;

exec (sprintf ('
create type SO_S_32_2 language CLR external name ''%s''
  as (
      "varString" nvarchar external type ''String'',
      "varInt" integer external type ''Int32'',
      "varFloat" real external type ''Single'',
      "processingResult" nvarchar external type ''String'',
      "vmVersion" nvarchar external name ''clrVersion'' external type ''String'')
  constructor method SO_S_32_2 (),
  method "process_data" () returns nvarchar external type ''String''
', get_assembly_physical_path ('so_s_32.dll', 'so_s_32')))
;

grant execute on SO_S_32 to SOAPDEMO;
grant execute on SO_S_32_2 to SOAPDEMO;


soap_dt_define ('',
'<complexType name="SOAPCLRStruct"
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
</complexType>', 'DB.DBA.SO_S_32')
;

create procedure "echoSOAPCLRStructSch" (
    in sst SO_S_32 __soap_type 'services.wsdl:SOAPCLRStruct')
returns SO_S_32 __soap_type 'services.wsdl:SOAPCLRStruct'
{
  declare procesingResult nvarchar;
  procesingResult := sst."process_data" ();
  return sst;
}
;

grant execute on "echoSOAPCLRStructSch" to SOAPDEMO
;

create procedure "echoSOAPCLRStructUdt" (
    in sst SO_S_32_2)
returns SO_S_32_2
{
  declare procesingResult nvarchar;
  procesingResult := sst."process_data" ();
  return sst;
}
;

grant execute on "echoSOAPCLRStructUdt" to SOAPDEMO
;
