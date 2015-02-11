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
select DB.DBA.soap_dt_define ('',
'<complexType xmlns="http://www.w3.org/2001/XMLSchema" name="cte" targetNamespace="http://tempuri.org/">
  <all>
    <element name="ctLeftAngleBrackets" type="int"/>
    <element name="ctRightAngleBrackets" type="int"/>
    <element name="ctAmpersands" type="int"/>
    <element name="ctApostrophes" type="int"/>
    <element name="ctQuotes" type="int"/>
  </all>
</complexType>');


create procedure WS.SOAP.countTheEntities (in s any __soap_type 'http://www.w3.org/2001/XMLSchema:string')
returns any __soap_type 'http://tempuri.org/:cte'
{
  --##Counts the number of predefined entities, namely <, >, &, ' and ".
  declare c varchar;
  declare ret varchar;
  declare inx, cleft, cright, camps, capos, cquotes integer;

  cleft := 0;
  cright := 0;
  camps := 0;
  capos := 0;
  cquotes := 0;
  inx := 0;

  while (inx < length (s))
    {
      c := chr (s[inx]);
      if (c = '<')
         cleft := cleft + 1;
      else if (c = '>')
         cright := cright + 1;
      else if (c = '&')
         camps := camps + 1;
      else if (c = '''')
         capos := capos + 1;
      else if (c = '"')
         cquotes := cquotes + 1;
      inx := inx + 1;
    }
  ret := soap_box_structure (
	   'ctLeftAngleBrackets', cleft,
	   'ctRightAngleBrackets', cright,
	   'ctAmpersands', camps,
	   'ctApostrophes', capos,
	   'ctQuotes', cquotes);
  return ret;
};

select DB.DBA.soap_dt_define ('',
'<complexType xmlns="http://www.w3.org/2001/XMLSchema" name="stooges" targetNamespace="http://tempuri.org/">
  <all>
    <element name="curly" type="int"/>
    <element name="larry" type="int"/>
    <element name="moe" type="int"/>
  </all>
</complexType>');

create procedure WS.SOAP.easyStructTest (in stooges any __soap_type 'http://tempuri.org/:stooges') returns integer
{
  --##Add the three numbers from input struct and return the result.
  declare ret integer;
  ret :=
      get_keyword ('curly', stooges) +
      get_keyword ('larry', stooges) +
      get_keyword ('moe', stooges);
  return ret;
};


--create procedure WS.SOAP.echoStructTest (in myStruct any __soap_type 'http://tempuri.org/:soap_test_myStruct')
create procedure WS.SOAP.echoStructTest (in myStruct any)
{
  --##This handler must echo back the input struct.
  return myStruct;
};


create procedure WS.SOAP.manyTypesTest (
in num integer, in bool integer, in state varchar, in doub varchar, in dat datetime, in bin varchar)
-- returns any __soap_type 'http://tempuri.org/:m_type'
{
  declare ret any;
  --##This handler takes six parameters and returns an array containing all the parameters.

  ret := vector (num, soap_boolean (bool), state, doub, dat, bin);
  return ret;
};

select DB.DBA.soap_dt_define('','
<complexType name="ArrayOfstring" targetNamespace="http://tempuri.org/"
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


create procedure WS.SOAP.moderateSizeArrayCheck (in myArray any __soap_type 'http://tempuri.org/:ArrayOfstring' ) returns varchar
{
  --##This handler returns a string containing the concatenated text of the first and last elements of input array.
  return concat (myArray[0], myArray[length(myArray) - 1]);
};


--create procedure WS.SOAP.nestedStructTest (in myStruct any __soap_type 'http://tempuri.org/:test_myStruct') returns integer
create procedure WS.SOAP.nestedStructTest (in myStruct any) returns integer
{
  --##This handler add the three numbers from input struct and return the result.
  declare year2k, month_april, day_1 any;
  declare res integer;

  if (isarray (myStruct) and isstring (myStruct))
    return myStruct;

  year2k := get_keyword ('year2000', myStruct);
  month_april := get_keyword ('month04', year2k);
  day_1 := get_keyword ('day01', month_april);

  res := get_keyword ('moe', day_1) +
	   get_keyword ('larry', day_1) +
	   get_keyword ('curly', day_1);
  return res;
};

select DB.DBA.soap_dt_define ('',
'<complexType xmlns="http://www.w3.org/2001/XMLSchema" name="ssrt" targetNamespace="http://tempuri.org/">
  <all>
    <element name="times10" type="int"/>
    <element name="times100" type="int"/>
    <element name="times1000" type="int"/>
  </all>
</complexType>');

create procedure WS.SOAP.simpleStructReturnTest (in myNumber any __soap_type 'http://www.w3.org/2001/XMLSchema:int')
returns any __soap_type 'http://tempuri.org/:ssrt'
{
  declare ret any;
  ret :=  soap_box_structure ('times10', myNumber * 10, 'times100', myNumber * 100, 'times1000', myNumber * 1000);
  --##This handler takes one parameter a number named myNumber, and returns a struct containing three elements, times10, times100 and times1000, the result of multiplying the number by 10, 100 and 1000.
  return ret;
};


select DB.DBA.soap_dt_define ('',
'<complexType xmlns="http://www.w3.org/2001/XMLSchema" name="toolkit_info" targetNamespace="http://tempuri.org/">
  <all>
    <element name="toolkitDocsUrl" type="string"/>
    <element name="toolkitName" type="string"/>
    <element name="toolkitVersion" type="string"/>
    <element name="toolkitOperatingSystem" type="string"/>
  </all>
</complexType>');

create procedure WS.SOAP.whichToolkit ()
returns any __soap_type 'http://tempuri.org/:toolkit_info'
{
  --##Provides a information about the SOAP toolkit
  declare ret any;

  ret := soap_box_structure (
      'toolkitDocsUrl', 'http://www.openlinksw.com/virtuoso',
      'toolkitName', 'Virtuoso SOAP server',
      'toolkitVersion', sys_stat('st_dbms_ver'),
      'toolkitOperatingSystem', 'Any');

  return ret;
};

grant execute on WS.SOAP.countTheEntities to SOAP;
grant execute on WS.SOAP.easyStructTest  to SOAP;
grant execute on WS.SOAP.echoStructTest  to SOAP;
grant execute on WS.SOAP.manyTypesTest  to SOAP;
grant execute on WS.SOAP.moderateSizeArrayCheck  to SOAP;
grant execute on WS.SOAP.nestedStructTest  to SOAP;
grant execute on WS.SOAP.simpleStructReturnTest  to SOAP;
grant execute on WS.SOAP.whichToolkit  to SOAP;

DB.DBA.exec_no_error('drop module WS.SOAP.SOAPValidator');

create module WS.SOAP.SOAPValidator
{

    procedure countTheEntities (in s any __soap_type 'http://www.w3.org/2001/XMLSchema:string')
    returns any __soap_type 'http://tempuri.org/:cte'
    {
      --##Counts the number of predefined entities, namely <, >, &, ' and ".
      declare c varchar;
      declare ret varchar;
      declare inx, cleft, cright, camps, capos, cquotes integer;

      cleft := 0;
      cright := 0;
      camps := 0;
      capos := 0;
      cquotes := 0;
      inx := 0;

      while (inx < length (s))
	{
	  c := chr (s[inx]);
	  if (c = '<')
	     cleft := cleft + 1;
	  else if (c = '>')
	     cright := cright + 1;
	  else if (c = '&')
	     camps := camps + 1;
	  else if (c = '''')
	     capos := capos + 1;
	  else if (c = '"')
	     cquotes := cquotes + 1;
	  inx := inx + 1;
	}
      ret := soap_box_structure (
	       'ctLeftAngleBrackets', cleft,
	       'ctRightAngleBrackets', cright,
	       'ctAmpersands', camps,
	       'ctApostrophes', capos,
	       'ctQuotes', cquotes);
      return ret;
    };

    procedure easyStructTest (in stooges any __soap_type 'http://tempuri.org/:stooges') returns integer
    {
      --##Add the three numbers from input struct and return the result.
      declare ret integer;
      ret :=
	  get_keyword ('curly', stooges) +
	  get_keyword ('larry', stooges) +
	  get_keyword ('moe', stooges);
      return ret;
    };


    procedure echoStructTest (in myStruct any)
    {
      --##This handler must echo back the input struct.
      return myStruct;
    };


    procedure manyTypesTest (
    in num integer, in bool integer, in state varchar, in doub varchar, in dat datetime, in bin varchar)
    -- returns any __soap_type 'http://tempuri.org/:m_type'
    {
      declare ret any;
      --##This handler takes six parameters and returns an array containing all the parameters.

      ret := vector (num, soap_boolean (bool), state, doub, dat, bin);
      return ret;
    };

    procedure moderateSizeArrayCheck (in myArray any __soap_type 'http://tempuri.org/:ArrayOfstring' ) returns varchar
    {
      --##This handler returns a string containing the concatenated text of the first and last elements of input array.
      return concat (myArray[0], myArray[length(myArray) - 1]);
    };


    procedure nestedStructTest (in myStruct any) returns integer
    {
      --##This handler add the three numbers from input struct and return the result.
      declare year2k, month_april, day_1 any;
      declare res integer;

      if (isarray (myStruct) and isstring (myStruct))
	return myStruct;

      year2k := get_keyword ('year2000', myStruct);
      month_april := get_keyword ('month04', year2k);
      day_1 := get_keyword ('day01', month_april);

      res := get_keyword ('moe', day_1) +
	       get_keyword ('larry', day_1) +
	       get_keyword ('curly', day_1);
      return res;
    };

    procedure simpleStructReturnTest (in myNumber any __soap_type 'http://www.w3.org/2001/XMLSchema:int')
    returns any __soap_type 'http://tempuri.org/:ssrt'
    {
      declare ret any;
      ret :=  soap_box_structure ('times10', myNumber * 10, 'times100', myNumber * 100, 'times1000', myNumber * 1000);
      --##This handler takes one parameter a number named myNumber, and returns a struct containing three elements, times10, times100 and times1000, the result of multiplying the number by 10, 100 and 1000.
      return ret;
    };


    procedure whichToolkit ()
    returns any __soap_type 'http://tempuri.org/:toolkit_info'
    {
      --##Provides a information about the SOAP toolkit
      declare ret any;

      ret := soap_box_structure (
	  'toolkitDocsUrl', 'http://www.openlinksw.com/virtuoso',
	  'toolkitName', 'Virtuoso SOAP server',
	  'toolkitVersion', sys_stat('st_dbms_ver'),
	  'toolkitOperatingSystem', 'Any');

      return ret;
    };

};
