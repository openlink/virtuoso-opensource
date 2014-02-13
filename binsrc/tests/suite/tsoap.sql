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
ECHO BOTH "STARTED: SOAP tests\n";

SET ARGV[0] 0;
SET ARGV[1] 0;

create user SOAP;
grant all privileges to SOAP;

-- get stats for previous http runs.
ws_stat (1);

create procedure WS.SOAP.SOAPTEST (
  in _varchar	varchar,
  in _real	real,
  in _double	double precision,
  in _numeric	numeric,
  in _datetime	datetime,
  in _vector	any,
  in _integer	integer) returns any
{
  --dbg_obj_print ('SOAPTEST params : _varchar', _varchar);
  --dbg_obj_print ('SOAPTEST params : _real', _real);
  --dbg_obj_print ('SOAPTEST params : _double', _double);
  ---dbg_obj_print ('SOAPTEST params : _numeric', _numeric);
  --dbg_obj_print ('SOAPTEST params : _datetime', _datetime);
  --dbg_obj_print ('SOAPTEST params : _vector', _vector);
  --dbg_obj_print ('SOAPTEST params : _integer', _integer);
  declare ret any;
  ret := vector (
---      _varchar,
      tree_md5 (_varchar, 1),
      dv_type_title (__tag (_varchar)),
      tree_md5 (_real, 1),
      dv_type_title (__tag (_real)),
      tree_md5 (_double, 1),
      dv_type_title (__tag (_double)),
      tree_md5 (_numeric, 1),
      dv_type_title (__tag (_numeric)),
      tree_md5 (_datetime, 1),
      dv_type_title (__tag (_datetime)),
---      _vector,
      tree_md5 (_vector, 1),
      dv_type_title (__tag (_vector)),
      tree_md5 (_integer, 1),
      dv_type_title (__tag (_integer))
      );
--  dbg_obj_print ('SOAPTEST :ret=', ret);
  return ret;
}
ECHO BOTH $IF $EQU $STATE OK "PASSED" "*** FAILED";
ECHO BOTH ": creating SOAP server procedure STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create procedure SOAP (in port varchar, in the_null_is integer, in soap_ver integer, in dime integer := 0)
{
  declare ret any;
  declare _varchar	varchar (20);
  declare _real	real;
  declare _double	double precision;
  declare _numeric	numeric;
  declare _datetime	datetime;
  declare _vector	any;
  declare _integer	integer;

  declare md5_varchar, md5_real, md5_double, md5_numeric, md5_datetime, md5_vector, md5_integer varchar(32);
  declare ret_varchar, ret_real, ret_double, ret_numeric, ret_datetime, ret_vector, ret_integer varchar(32);

---  declare vector_differs integer;

  _varchar := 'varchar';
  if (the_null_is = 1) _varchar := NULL;
  md5_varchar := tree_md5 (_varchar, 1);
  _real := cast ('12345.6789' as real);
  if (the_null_is = 2) _real := NULL;
  md5_real := tree_md5 (_real, 1);
  _double := cast ('12345.6789' as double precision);
  if (the_null_is = 3) _double := NULL;
  md5_double := tree_md5 (_double, 1);
  _numeric := cast ('12345.6789' as numeric);
  if (the_null_is = 4) _numeric := NULL;
  md5_numeric := tree_md5 (_numeric, 1);
  _datetime := cast( '2000-06-13 15:19:42.000000' as datetime);
  if (the_null_is = 5) _datetime := NULL;
  md5_datetime := tree_md5 (_datetime, 1);
  _vector := vector ('one', 'two');
  if (the_null_is = 6) _vector := NULL;
  md5_vector := tree_md5 (_vector, 1);
  _integer := cast ('123456' as integer);
  if (the_null_is = 7) _integer := NULL;
  md5_integer := tree_md5 (_integer, 1);

  ret := soap_call (concat ('localhost:', port), '/SOAP', 'fake', 'SOAPTEST',
		    vector (
			    '_varchar',	_varchar,
			    '_real',	_real,
			    '_double',	_double,
			    '_numeric',	_numeric,
			    '_datetime',	_datetime,
			    '_vector',	_vector,
			    '_integer',	_integer),
		    soap_ver, null, null, null, dime, 'soaptest', 'soaptest');
  if (ret is null)
    signal ('.....', 'return from soap call is empty');
  --dbg_obj_print ('ret=', ret);
  ret := aref (ret, 1);

  ret_varchar := soap_box_xml_entity (aref (ret, 1), 'string');
  ret_real := soap_box_xml_entity (aref (ret, 3), 'string');
  ret_double := soap_box_xml_entity (aref (ret, 5), 'string');
  ret_numeric := soap_box_xml_entity (aref (ret, 7), 'string');
  ret_datetime := soap_box_xml_entity (aref (ret, 9), 'string');
  ret_vector := soap_box_xml_entity (aref (ret, 11), NULL);
  ret_integer := soap_box_xml_entity (aref (ret, 13), 'string');

  if (ret_varchar <> md5_varchar)
    dbg_obj_print ('varchar : ', ret_varchar, md5_varchar);
  if (ret_real <> md5_real)
    dbg_obj_print ('real : ', ret_real, md5_real);
  if (ret_double <> md5_double)
    dbg_obj_print ('double : ', ret_double, md5_double);
  if (ret_numeric <> md5_numeric)
    dbg_obj_print ('numeric : ', ret_numeric, md5_numeric);
  if (ret_datetime <> md5_datetime)
    dbg_obj_print ('datetime : ', ret_datetime, md5_datetime);
  if (ret_vector <> md5_vector)
    dbg_obj_print ('vector : ', ret_vector, md5_vector);
  if (ret_integer <> md5_integer)
    dbg_obj_print ('integer : ', ret_integer, md5_integer);

--  vector_differs := 1;
--  if (ret_vector is null)
--    {
--      if (the_null_is = 6)
--	vector_differs := 0;
--      else
--	dbg_obj_print ('vector : ', ret_vector, _vector);
--    }
--  else
--    {
--      if (the_null_is <> 6)
--	{
--	    if (aref (ret_vector, 0) = aref (_vector, 0) and aref (ret_vector, 1) = aref (_vector, 1))
--	      vector_differs := 0;
--	    else
--	      dbg_obj_print ('vector : ', ret_vector, _vector);
--	}
--      else
--	dbg_obj_print ('vector : ', ret_vector, _vector);
--    }


  result_names (
      ret_varchar,
      ret_varchar,
      ret_real,
      ret_real,
      ret_double,
      ret_double,
      ret_numeric,
      ret_numeric,
      ret_datetime,
      ret_datetime,
      ret_vector,
      ret_vector,
      ret_integer,
      ret_integer);
  result (
      either (neq (ret_varchar, md5_varchar), 'Differ', 'OK'),
      soap_box_xml_entity (aref (ret, 2), 'string'),
      either (neq (ret_real, md5_real), 'Differ', 'OK'),
      soap_box_xml_entity (aref (ret, 4), 'string'),
      either (neq (ret_double, md5_double), 'Differ', 'OK'),
      soap_box_xml_entity (aref (ret, 6), 'string'),
      either (neq (ret_numeric, md5_numeric), 'Differ', 'OK'),
      soap_box_xml_entity (aref (ret, 8), 'string'),
      either (neq (ret_datetime, md5_datetime), 'Differ', 'OK'),
      soap_box_xml_entity (aref (ret, 10), 'string'),
      either (neq (ret_vector, md5_vector), 'Differ', 'OK'),
      soap_box_xml_entity (aref (ret, 12), 'string'),
      either (neq (ret_integer, md5_integer), 'Differ', 'OK'),
      soap_box_xml_entity (aref (ret, 14), 'string'));
}
ECHO BOTH $IF $EQU $STATE OK "PASSED" "*** FAILED";
ECHO BOTH ": creating SOAP client procedure STATE=" $STATE " MESSAGE=" $MESSAGE "\n";


---WS.SOAP.SOAPTEST ('1', 1, 2, 3, curdatetime(), vector (1, 2));
SOAP ('$U{HTTPPORT}', 1, 1);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "*** FAILED";
ECHO BOTH ": calling SOAP 1.0 1 STATE=" $STATE " MESSAGE=" $MESSAGE "\n";
ECHO BOTH $IF $NEQ $LAST[1] OK "*** FAILED" $IF $NEQ $LAST[2] 'DB_NULL' "*** FAILED" "PASSED";
ECHO BOTH ": varchar NULL param\n";
ECHO BOTH $IF $NEQ $LAST[3] OK "*** FAILED" $IF $NEQ $LAST[4] 'REAL' "*** FAILED" "PASSED";
ECHO BOTH ": real param\n";
ECHO BOTH $IF $NEQ $LAST[5] OK "*** FAILED" $IF $NEQ $LAST[6] 'DOUBLE PRECISION' "*** FAILED" "PASSED";
ECHO BOTH ": double param\n";
ECHO BOTH $IF $NEQ $LAST[7] OK "*** FAILED" $IF $NEQ $LAST[8] 'DECIMAL' "*** FAILED" "PASSED";
ECHO BOTH ": numeric param\n";
ECHO BOTH $IF $NEQ $LAST[9] OK "*** FAILED" $IF $NEQ $LAST[10] 'DATETIME' "*** FAILED" "PASSED";
ECHO BOTH ": datetime param\n";
ECHO BOTH $IF $NEQ $LAST[11] OK "*** FAILED" $IF $NEQ $LAST[12] ARRAY_OF_POINTER "*** FAILED" "PASSED";
ECHO BOTH ": vector param\n";
ECHO BOTH $IF $NEQ $LAST[13] OK "*** FAILED" $IF $NEQ $LAST[14] 'INTEGER' "*** FAILED" "PASSED";
ECHO BOTH ": integer param\n";


SOAP ('$U{HTTPPORT}', 2, 1);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "*** FAILED";
ECHO BOTH ": calling SOAP 1.0 2 STATE=" $STATE " MESSAGE=" $MESSAGE "\n";
ECHO BOTH $IF $NEQ $LAST[1] OK "*** FAILED" $IF $NEQ $LAST[2] 'VARCHAR' "*** FAILED" "PASSED";
ECHO BOTH ": varchar param\n";
ECHO BOTH $IF $NEQ $LAST[3] OK "*** FAILED" $IF $NEQ $LAST[4] 'DB_NULL' "*** FAILED" "PASSED";
ECHO BOTH ": real NULL param\n";
ECHO BOTH $IF $NEQ $LAST[5] OK "*** FAILED" $IF $NEQ $LAST[6] 'DOUBLE PRECISION' "*** FAILED" "PASSED";
ECHO BOTH ": double param\n";
ECHO BOTH $IF $NEQ $LAST[7] OK "*** FAILED" $IF $NEQ $LAST[8] 'DECIMAL' "*** FAILED" "PASSED";
ECHO BOTH ": numeric param\n";
ECHO BOTH $IF $NEQ $LAST[9] OK "*** FAILED" $IF $NEQ $LAST[10] 'DATETIME' "*** FAILED" "PASSED";
ECHO BOTH ": datetime param\n";
ECHO BOTH $IF $NEQ $LAST[11] OK "*** FAILED" $IF $NEQ $LAST[12] ARRAY_OF_POINTER "*** FAILED" "PASSED";
ECHO BOTH ": vector param\n";
ECHO BOTH $IF $NEQ $LAST[13] OK "*** FAILED" $IF $NEQ $LAST[14] 'INTEGER' "*** FAILED" "PASSED";
ECHO BOTH ": integer param\n";


SOAP ('$U{HTTPPORT}', 3, 1);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "*** FAILED";
ECHO BOTH ": calling SOAP 1.0 3 STATE=" $STATE " MESSAGE=" $MESSAGE "\n";
ECHO BOTH $IF $NEQ $LAST[1] OK "*** FAILED" $IF $NEQ $LAST[2] 'VARCHAR' "*** FAILED" "PASSED";
ECHO BOTH ": varchar param\n";
ECHO BOTH $IF $NEQ $LAST[3] OK "*** FAILED" $IF $NEQ $LAST[4] 'REAL' "*** FAILED" "PASSED";
ECHO BOTH ": real param\n";
ECHO BOTH $IF $NEQ $LAST[5] OK "*** FAILED" $IF $NEQ $LAST[6] 'DB_NULL' "*** FAILED" "PASSED";
ECHO BOTH ": double NULL param\n";
ECHO BOTH $IF $NEQ $LAST[7] OK "*** FAILED" $IF $NEQ $LAST[8] 'DECIMAL' "*** FAILED" "PASSED";
ECHO BOTH ": numeric param\n";
ECHO BOTH $IF $NEQ $LAST[9] OK "*** FAILED" $IF $NEQ $LAST[10] 'DATETIME' "*** FAILED" "PASSED";
ECHO BOTH ": datetime param\n";
ECHO BOTH $IF $NEQ $LAST[11] OK "*** FAILED" $IF $NEQ $LAST[12] ARRAY_OF_POINTER "*** FAILED" "PASSED";
ECHO BOTH ": vector param\n";
ECHO BOTH $IF $NEQ $LAST[13] OK "*** FAILED" $IF $NEQ $LAST[14] 'INTEGER' "*** FAILED" "PASSED";
ECHO BOTH ": integer param\n";


SOAP ('$U{HTTPPORT}', 4, 1);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "*** FAILED";
ECHO BOTH ": calling SOAP 1.0 4 STATE=" $STATE " MESSAGE=" $MESSAGE "\n";
ECHO BOTH $IF $NEQ $LAST[1] OK "*** FAILED" $IF $NEQ $LAST[2] 'VARCHAR' "*** FAILED" "PASSED";
ECHO BOTH ": varchar param\n";
ECHO BOTH $IF $NEQ $LAST[3] OK "*** FAILED" $IF $NEQ $LAST[4] 'REAL' "*** FAILED" "PASSED";
ECHO BOTH ": real param\n";
ECHO BOTH $IF $NEQ $LAST[5] OK "*** FAILED" $IF $NEQ $LAST[6] 'DOUBLE PRECISION' "*** FAILED" "PASSED";
ECHO BOTH ": double param\n";
ECHO BOTH $IF $NEQ $LAST[7] OK "*** FAILED" $IF $NEQ $LAST[8] 'DB_NULL' "*** FAILED" "PASSED";
ECHO BOTH ": numeric NULL param\n";
ECHO BOTH $IF $NEQ $LAST[9] OK "*** FAILED" $IF $NEQ $LAST[10] 'DATETIME' "*** FAILED" "PASSED";
ECHO BOTH ": datetime param\n";
ECHO BOTH $IF $NEQ $LAST[11] OK "*** FAILED" $IF $NEQ $LAST[12] ARRAY_OF_POINTER "*** FAILED" "PASSED";
ECHO BOTH ": vector param\n";
ECHO BOTH $IF $NEQ $LAST[13] OK "*** FAILED" $IF $NEQ $LAST[14] 'INTEGER' "*** FAILED" "PASSED";
ECHO BOTH ": integer param\n";


SOAP ('$U{HTTPPORT}', 5, 1);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "*** FAILED";
ECHO BOTH ": calling SOAP 1.0 5 STATE=" $STATE " MESSAGE=" $MESSAGE "\n";
ECHO BOTH $IF $NEQ $LAST[1] OK "*** FAILED" $IF $NEQ $LAST[2] 'VARCHAR' "*** FAILED" "PASSED";
ECHO BOTH ": varchar param\n";
ECHO BOTH $IF $NEQ $LAST[3] OK "*** FAILED" $IF $NEQ $LAST[4] 'REAL' "*** FAILED" "PASSED";
ECHO BOTH ": real param\n";
ECHO BOTH $IF $NEQ $LAST[5] OK "*** FAILED" $IF $NEQ $LAST[6] 'DOUBLE PRECISION' "*** FAILED" "PASSED";
ECHO BOTH ": double param\n";
ECHO BOTH $IF $NEQ $LAST[7] OK "*** FAILED" $IF $NEQ $LAST[8] 'DECIMAL' "*** FAILED" "PASSED";
ECHO BOTH ": numeric param\n";
ECHO BOTH $IF $NEQ $LAST[9] OK "*** FAILED" $IF $NEQ $LAST[10] 'DB_NULL' "*** FAILED" "PASSED";
ECHO BOTH ": datetime NULL param\n";
ECHO BOTH $IF $NEQ $LAST[11] OK "*** FAILED" $IF $NEQ $LAST[12] ARRAY_OF_POINTER "*** FAILED" "PASSED";
ECHO BOTH ": vector param\n";
ECHO BOTH $IF $NEQ $LAST[13] OK "*** FAILED" $IF $NEQ $LAST[14] 'INTEGER' "*** FAILED" "PASSED";
ECHO BOTH ": integer param\n";


SOAP ('$U{HTTPPORT}', 6, 1);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "*** FAILED";
ECHO BOTH ": calling SOAP 1.0 6 STATE=" $STATE " MESSAGE=" $MESSAGE "\n";
ECHO BOTH $IF $NEQ $LAST[1] OK "*** FAILED" $IF $NEQ $LAST[2] 'VARCHAR' "*** FAILED" "PASSED";
ECHO BOTH ": varchar param\n";
ECHO BOTH $IF $NEQ $LAST[3] OK "*** FAILED" $IF $NEQ $LAST[4] 'REAL' "*** FAILED" "PASSED";
ECHO BOTH ": real param\n";
ECHO BOTH $IF $NEQ $LAST[5] OK "*** FAILED" $IF $NEQ $LAST[6] 'DOUBLE PRECISION' "*** FAILED" "PASSED";
ECHO BOTH ": double param\n";
ECHO BOTH $IF $NEQ $LAST[7] OK "*** FAILED" $IF $NEQ $LAST[8] 'DECIMAL' "*** FAILED" "PASSED";
ECHO BOTH ": numeric param\n";
ECHO BOTH $IF $NEQ $LAST[9] OK "*** FAILED" $IF $NEQ $LAST[10] 'DATETIME' "*** FAILED" "PASSED";
ECHO BOTH ": datetime param\n";
ECHO BOTH $IF $NEQ $LAST[11] OK "*** FAILED" $IF $NEQ $LAST[12] 'DB_NULL' "*** FAILED" "PASSED";
ECHO BOTH ": vector NULL param\n";
ECHO BOTH $IF $NEQ $LAST[13] OK "*** FAILED" $IF $NEQ $LAST[14] 'INTEGER' "*** FAILED" "PASSED";
ECHO BOTH ": integer param\n";


SOAP ('$U{HTTPPORT}', 7, 1);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "*** FAILED";
ECHO BOTH ": calling SOAP 1.0 7 STATE=" $STATE " MESSAGE=" $MESSAGE "\n";
ECHO BOTH $IF $NEQ $LAST[1] OK "*** FAILED" $IF $NEQ $LAST[2] 'VARCHAR' "*** FAILED" "PASSED";
ECHO BOTH ": varchar param\n";
ECHO BOTH $IF $NEQ $LAST[3] OK "*** FAILED" $IF $NEQ $LAST[4] 'REAL' "*** FAILED" "PASSED";
ECHO BOTH ": real param\n";
ECHO BOTH $IF $NEQ $LAST[5] OK "*** FAILED" $IF $NEQ $LAST[6] 'DOUBLE PRECISION' "*** FAILED" "PASSED";
ECHO BOTH ": double param\n";
ECHO BOTH $IF $NEQ $LAST[7] OK "*** FAILED" $IF $NEQ $LAST[8] 'DECIMAL' "*** FAILED" "PASSED";
ECHO BOTH ": numeric param\n";
ECHO BOTH $IF $NEQ $LAST[9] OK "*** FAILED" $IF $NEQ $LAST[10] 'DATETIME' "*** FAILED" "PASSED";
ECHO BOTH ": datetime param\n";
ECHO BOTH $IF $NEQ $LAST[11] OK "*** FAILED" $IF $NEQ $LAST[12] ARRAY_OF_POINTER "*** FAILED" "PASSED";
ECHO BOTH ": vector param\n";
ECHO BOTH $IF $NEQ $LAST[13] OK "*** FAILED" $IF $NEQ $LAST[14] 'DB_NULL' "*** FAILED" "PASSED";
ECHO BOTH ": integer NULL param\n";

SOAP ('$U{HTTPPORT}', 1, 11);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "*** FAILED";
ECHO BOTH ": calling SOAP 1.1 1 STATE=" $STATE " MESSAGE=" $MESSAGE "\n";
ECHO BOTH $IF $NEQ $LAST[1] OK "*** FAILED" $IF $NEQ $LAST[2] 'DB_NULL' "*** FAILED" "PASSED";
ECHO BOTH ": varchar NULL param\n";
ECHO BOTH $IF $NEQ $LAST[3] OK "*** FAILED" $IF $NEQ $LAST[4] 'REAL' "*** FAILED" "PASSED";
ECHO BOTH ": real param\n";
ECHO BOTH $IF $NEQ $LAST[5] OK "*** FAILED" $IF $NEQ $LAST[6] 'DOUBLE PRECISION' "*** FAILED" "PASSED";
ECHO BOTH ": double param\n";
ECHO BOTH $IF $NEQ $LAST[7] OK "*** FAILED" $IF $NEQ $LAST[8] 'DECIMAL' "*** FAILED" "PASSED";
ECHO BOTH ": numeric param\n";
ECHO BOTH $IF $NEQ $LAST[9] OK "*** FAILED" $IF $NEQ $LAST[10] 'DATETIME' "*** FAILED" "PASSED";
ECHO BOTH ": datetime param\n";
ECHO BOTH $IF $NEQ $LAST[11] OK "*** FAILED" $IF $NEQ $LAST[12] ARRAY_OF_POINTER "*** FAILED" "PASSED";
ECHO BOTH ": vector param\n";
ECHO BOTH $IF $NEQ $LAST[13] OK "*** FAILED" $IF $NEQ $LAST[14] 'INTEGER' "*** FAILED" "PASSED";
ECHO BOTH ": integer param\n";

select xml_tree_doc (xml_tree (http_get ('http://localhost:$U{HTTPPORT}/SOAP/services.xml')));
ECHO BOTH $IF $EQU $STATE OK "PASSED" "*** FAILED";
ECHO BOTH ": The MS ROPE SDL for the SOAP server is a valid XML STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select xpath_eval('translate (/serviceDescription/soap/service/requestResponse[@name = "SOAPTEST"]/parameterorder/text(), "abcdefghijklmnopqrstuvwxyz", "ABCDEFGHIJKLMNOPQRSTUVWXYZ")', xml_tree_doc (xml_tree (http_get ('http://localhost:$U{HTTPPORT}/SOAP/services.xml'))));
ECHO BOTH $IF $EQU $STATE OK "PASSED" "*** FAILED";
ECHO BOTH ": The MS ROPE SDL for the SOAP server is a valid SDL STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

ECHO BOTH $IF $EQU $LAST[1] "_VARCHAR _REAL _DOUBLE _NUMERIC _DATETIME _VECTOR _INTEGER CALLRETURN" "PASSED" "*** FAILED";
ECHO BOTH ": The MS ROPE SDL for the SOAP server describes the SOAPTEST procedure OK STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select xml_tree_doc (xml_tree (http_get ('http://localhost:$U{HTTPPORT}/SOAP/services.wsdl')));
ECHO BOTH $IF $EQU $STATE OK "PASSED" "*** FAILED";
ECHO BOTH ": The WSDL for the SOAP server is a valid XML STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select xpath_eval('count(/definitions/portType/operation[@name = "SOAPTEST"])', xml_tree_doc (xml_tree (http_get ('http://localhost:$U{HTTPPORT}/SOAP/services.wsdl'))));
ECHO BOTH $IF $EQU $STATE OK "PASSED" "*** FAILED";
ECHO BOTH ": The WSDL for the SOAP server is a valid WSDL STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "*** FAILED";
ECHO BOTH ": The WSDL for the SOAP server describes the SOAPTEST procedure OK STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create procedure DB.DBA.SOAPTEST ()
{
  return 12;
};
ECHO BOTH $IF $EQU $STATE OK "PASSED" "*** FAILED";
ECHO BOTH ": creating VSP SOAP server procedure STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create user SOAP_SRV;
grant execute on DB.DBA.SOAPTEST to SOAP_SRV;

soap_call ('localhost:$U{HTTPPORT}', '/vspsoap.vsp', 'fake', 'test', vector(), 11);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "*** FAILED";
ECHO BOTH ": calling the VSP SOAP server with fake#test STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

soap_call ('localhost:$U{HTTPPORT}', '/vspsoap.vsp', 'fake', 'test1', vector(), 11);
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "*** FAILED";
ECHO BOTH ": calling the VSP SOAP server with fake#test1 STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

soap_call ('localhost:$U{HTTPPORT}', '/vspsoap.vsp', NULL, 'test', vector(), 11);
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "*** FAILED";
ECHO BOTH ": calling the VSP SOAP server with test STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create module DB.DBA.SOAPMOD {
  procedure SOAPMOD1(in par int) returns int { return par + 1; };
  procedure SOAPMOD2(inout par2 int) { return par2 + 1; };
  procedure SOAPMOD3() { return 14; };
};

GRANT EXECUTE ON DB.DBA.SOAPMOD TO SOAP_SRV;

select xml_tree_doc (soap_sdl ('DB.DBA.SOAPMOD', 'URL'));
ECHO BOTH $IF $EQU $STATE OK "PASSED" "*** FAILED";
ECHO BOTH ": SDL for a module valid STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select xml_tree_doc (soap_wsdl ('DB.DBA.SOAPMOD', 'URL', 'NS'));
ECHO BOTH $IF $EQU $STATE OK "PASSED" "*** FAILED";
ECHO BOTH ": WSDL for a module valid STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

dbg_obj_print ( soap_call ('localhost:$U{HTTPPORT}', '/vspsoap_mod.vsp', 'fake', 'SOAPMOD3', vector(), 11));
ECHO BOTH $IF $EQU $STATE OK "PASSED" "*** FAILED";
ECHO BOTH ": calling the VSP SOAP server with SOAPMOD3 from module SOAPMOD STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

ECHO BOTH "STARTED: UDDI tests\n";

use uddi;
create user SOAP;
set user group SOAP dba;

create procedure
add_bussines_1 (in uri varchar)
{
  declare s1, name varchar;
  declare ret any;

  s1 :=
'<save_business xmlns="urn:uddi-org:api" generic="1.0">
<businessEntity authorizedName="Matthew MacKenzie" businessKey="871C648D-B219-4E3A-89E9-FCA87D3114A5" operator="Microsoft Corporation">
	<discoveryURLs>
		<discoveryURL useType="businessEntity">http://uddi.microsoft.com/discovery?businessKey=871C648D-B219-4E3A-89E9-FCA87D3114A5</discoveryURL>
	</discoveryURLs>
	<name>XML Global Technologies, Inc.</name>
	<description xml:lang="en">Manufacturer of XML based business and technology solutions.</description>
	<contacts>
		<contact>
			<description xml:lang="en">Technical Contact</description>
			<personName>Matthew MacKenzie</personName>
			<email>matt@xmlglobal.com</email>
		</contact>
		<contact>
			<description xml:lang="en">Administrative Contact</description>
			<personName>Liz Altman</personName>
			<email>liz.altman@xmlglobal.com</email>
		</contact>
	</contacts>
	<businessServices>
		<businessService businessKey="871C648D-B219-4E3A-89E9-FCA87D3114A5" serviceKey="433D4C51-065D-49DA-99C3-7016E39A0A1C">
			<name>CartNetwork</name>
			<description xml:lang="en">Remotely hosted shopping cart system</description>
			<bindingTemplates>
				<bindingTemplate bindingKey="D07D769F-7F94-448C-80E3-8449E5CD8CAF" serviceKey="433D4C51-065D-49DA-99C3-7016E39A0A1C">
					<description xml:lang="en">Sign up for service</description>
					<accessPoint URLType="http">http://www.cartnetwork.com</accessPoint>
					<tModelInstanceDetails/>
				</bindingTemplate>
			</bindingTemplates>
			<categoryBag>
				<keyedReference keyName="All Other Professional, Scientific, and Technical Services" keyValue="54199" tModelKey="uuid:C0B9FE13-179F-413D-8A5B-5004DB8E5BB2"/>
				<keyedReference keyName="Software Publishers" keyValue="5112" tModelKey="uuid:C0B9FE13-179F-413D-8A5B-5004DB8E5BB2"/>
			</categoryBag>
		</businessService>
	</businessServices>
	<categoryBag>
		<keyedReference keyName="Software Publishers" keyValue="5112" tModelKey="uuid:C0B9FE13-179F-413D-8A5B-5004DB8E5BB2"/>
	</categoryBag>
</businessEntity>
</save_business>';

  ret := uddi_str_get (uri, s1);
  ret := xml_tree_doc (ret);
  name := xpath_eval ('/Envelope/Body/businessDetail/businessEntity/name', ret, 0);

  if (name is NULL)
    signal ('UDDI1', 'Can\'t get name business entry "XML Global Technologies, Inc."');

  name := cast (aref (name, 0) as varchar);

  if (name = 'XML Global Technologies, Inc.')
    return 1;

  return 0;
}
;


create procedure
add_bussines_2 (in uri varchar)
{
  declare s1, name varchar;
  declare ret any;

  s1 :=
'<save_business xmlns="urn:uddi-org:api" generic="1.0">
	<businessEntity xmlns:n0="urn:uddi-org:api" authorizedName="Kingsley Idehen" businessKey="2E4BF055-63FF-40E7-B54C-0467CEE060D5" operator="Microsoft Corporation">
		<discoveryURLs>
			<discoveryURL useType="businessEntity">http://uddi.microsoft.com/discovery?businessKey=2E4BF055-63FF-40E7-B54C-0467CEE060D5</discoveryURL>
		</discoveryURLs>
		<name>OpenLink Software</name>
		<description xml:lang="en"/>
		<contacts>
			<contact>
				<personName>Kingsley Idehen</personName>
			</contact>
		</contacts>
		<businessServices>
			<businessService businessKey="2E4BF055-63FF-40E7-B54C-0467CEE060D5" serviceKey="43DCC41D-D221-4F9D-B0F7-6ED581CB5720">
				<name>High-Performance Database Connectivity Middleware</name>
				<description xml:lang="en">ODBC, JDBC, and OLE-DB Providers</description>
				<bindingTemplates/>
			</businessService>
			<businessService businessKey="2E4BF055-63FF-40E7-B54C-0467CEE060D5" serviceKey="51EA0545-19AC-4402-93C3-CB0C8AD3A2A1">
				<name>eBusiness Infrastructure Technology</name>
				<description xml:lang="en">Virtuoso eBusiness Integration Server</description>
				<bindingTemplates/>
			</businessService>
		</businessServices>
	</businessEntity>
</save_business>';

  ret := uddi_str_get (uri, s1);
  ret := xml_tree_doc (ret);

  get_err (ret);

  name := xpath_eval ('/Envelope/Body/businessDetail/businessEntity/name', ret, 0);

  if (name is NULL)
    signal ('UDDI1', 'Can\'t get name business entry "OpenLink Software"');

  name := cast (aref (name, 0) as varchar);

  if (name = 'OpenLink Software')
    return 1;

  signal ('UDDI1', 'Can\'t add business entry "OpenLink Software"');
}
;


create procedure
t_find_business (in uri varchar)
{

  declare res, name any;

  res := uddi_get (uri,'<find_business xmlns="urn:uddi-org:api" generic="1.0"><name>o</name></find_business>');

  get_err (res);

  name := xpath_eval ('//Body/businessList/businessInfos/businessInfo/name', res, 1);

  if (name is NULL)
    signal ('UDDI3', 'Can\'t find business entry');

  name := cast (xpath_eval ('//Body/businessList/businessInfos/businessInfo/name', res, 1) as varchar);

  if (name <> 'OpenLink Software')
    signal ('UDDI3', 'Can\'t find business entry "OpenLink Software"');

  return 1;
}
;


create procedure
t_find_business_order_a (in uri varchar)
{

  declare res, names any;
  declare name1, name2 varchar;

  res := uddi_get (uri,'<find_business xmlns="urn:uddi-org:api" generic="1.0"><findQualifiers><findQualifier>sortByNameAsc</findQualifier></findQualifiers><name/></find_business>');

  get_err (res);

  names := xpath_eval ('//Body/businessList/businessInfos/businessInfo/name', res, 0);

  if (length (names) <> 2)
    signal ('UDDI4', 't_find_business_order_a Can\'t get names');

  name1 := cast (aref (names, 0) as varchar);
  name2 := cast (aref (names, 1) as varchar);

  if (LEFT (name1, 1) <> 'O')
    signal ('UDDI3', 't_find_business_order_a LEFT (name1, 1) is not OpenLink Software');

  if (LEFT (name2, 1) <> 'X')
    signal ('UDDI3', 't_find_business_order_a LEFT (name2, 1) is not XML Global Technologies, Inc.');

  return 1;
}
;


create procedure
t_find_business_order_d (in uri varchar)
{

  declare res, names any;
  declare name1, name2 varchar;

  res := uddi_get (uri,'<find_business xmlns="urn:uddi-org:api" generic="1.0"><findQualifiers><findQualifier>sortByNameDesc</findQualifier></findQualifiers><name/></find_business>');

  get_err (res);

  names := xpath_eval ('//Body/businessList/businessInfos/businessInfo/name', res, 0);

  if (length (names) <> 2)
    signal ('UDDI4', 't_find_business_order_a Can\'t get names');

  name1 := cast (aref (names, 0) as varchar);
  name2 := cast (aref (names, 1) as varchar);

  if (LEFT (name2, 1) <> 'O')
    signal ('UDDI3', 't_find_business_order_a LEFT (name2, 1) is not OpenLink Software');

  if (LEFT (name1, 1) <> 'X')
    signal ('UDDI3', 't_find_business_order_a LEFT (name1, 1) is not XML Global Technologies, Inc.');

  return 1;
}
;


create procedure
t_find_business_2 (in uri varchar, in num integer)
{

  declare res, name any;

  res := uddi_get (uri,'<find_business xmlns="urn:uddi-org:api" generic="1.0"><name>xml</name></find_business>');

  get_err (res);

  name := xpath_eval ('//Body/businessList/businessInfos/businessInfo/serviceInfos/serviceInfo/name', res, 0);

  if (length (name) <> num)
    signal ('UDDI3', 't_find_business_2 wrong name length');

  return 1;
}
;


create procedure
add_service (in uri varchar)
{
  declare s1, name varchar;
  declare ret any;

  s1 :=
'
<save_service xmlns="urn:uddi-org:api" generic="1.0">
<businessService businessKey="871C648D-B219-4E3A-89E9-FCA87D3114A5" serviceKey="6828022E-00E2-E46A-9849-C6113993AA77">
	<name>Buy from IBM</name>
	<description xml:lang="en">This service enables direct purchasing from IBM through the ShopIBM web site.</description>
	<bindingTemplates>
		<bindingTemplate bindingKey="68280396-00E2-F348-8D37-C6113993AA77" serviceKey="6828022E-00E2-E46A-9849-C6113993AA77">
			<description xml:lang="en">Register to ShopIBM</description>
			<accessPoint URLType="https">https://commerce.www.ibm.com/cgi-bin/ncommerce/RegisterForm?Krypto=rux5N33YF4onmRRYrM2MK6JbZDJCQIqsYZjyy6s330dHEcqYH6sVJako2B%2FwXQuQ</accessPoint>
			<tModelInstanceDetails>
				<tModelInstanceInfo tModelKey="uuid:68DE9E80-AD09-469D-8A37-088422BFBC36"/>
			</tModelInstanceDetails>
		</bindingTemplate>
		<bindingTemplate bindingKey="682804F4-00E2-F2AE-7A76-C6113993AA77" serviceKey="6828022E-00E2-E46A-9849-C6113993AA77">
			<description xml:lang="en">Buy through ShopIBM</description>
			<accessPoint URLType="http">http://commerce.www.ibm.com/content/</accessPoint>
			<tModelInstanceDetails>
				<tModelInstanceInfo tModelKey="uuid:68DE9E80-AD09-469D-8A37-088422BFBC36"/>
			</tModelInstanceDetails>
		</bindingTemplate>
		<bindingTemplate bindingKey="68280524-00E2-F48B-780D-C6113993AA77" serviceKey="6828022E-00E2-E46A-9849-C6113993AA77">
			<description xml:lang="en">Request product catalog using IBM web page</description>
			<accessPoint URLType="http">http://commerce.www.ibm.com/home/shop_ShopIBM/en_US/catrequest_840.html</accessPoint>
			<tModelInstanceDetails>
				<tModelInstanceInfo tModelKey="uuid:68DE9E80-AD09-469D-8A37-088422BFBC36"/>
			</tModelInstanceDetails>
		</bindingTemplate>
		<bindingTemplate bindingKey="68280558-00E2-F35B-7599-C6113993AA77" serviceKey="6828022E-00E2-E46A-9849-C6113993AA77">
			<description xml:lang="en">Place order (eMail)</description>
			<accessPoint URLType="mailto">mailto:ibm_direct@vnet.ibm.com</accessPoint>
			<tModelInstanceDetails>
				<tModelInstanceInfo tModelKey="uuid:93335D49-3EFB-48A0-ACEA-EA102B60DDC6"/>
			</tModelInstanceDetails>
		</bindingTemplate>
		<bindingTemplate bindingKey="68280585-00E2-ED57-730C-C6113993AA77" serviceKey="6828022E-00E2-E46A-9849-C6113993AA77">
			<description xml:lang="en">Place order (phone)</description>
			<accessPoint URLType="phone">1 888 746 7426</accessPoint>
			<tModelInstanceDetails>
				<tModelInstanceInfo tModelKey="uuid:68DE9E80-AD09-469D-8A37-088422BFBC36"/>
			</tModelInstanceDetails>
		</bindingTemplate>
		<bindingTemplate bindingKey="682805C1-00E2-FA9A-709C-C6113993AA77" serviceKey="6828022E-00E2-E46A-9849-C6113993AA77">
			<description xml:lang="en">Place order (Fax)</description>
			<accessPoint URLType="fax">1 800 242 6329</accessPoint>
			<tModelInstanceDetails>
				<tModelInstanceInfo tModelKey="uuid:1A2B00BE-6E2C-42F5-875B-56F32686E0E7"/>
			</tModelInstanceDetails>
		</bindingTemplate>
		<bindingTemplate bindingKey="682805F7-00E2-F9B2-6E33-C6113993AA77" serviceKey="6828022E-00E2-E46A-9849-C6113993AA77">
			<description xml:lang="en">Order IBM products and services for resale</description>
			<accessPoint URLType="http">http://www.ibm.com/PartnerWorld</accessPoint>
			<tModelInstanceDetails>
				<tModelInstanceInfo tModelKey="uuid:68DE9E80-AD09-469D-8A37-088422BFBC36"/>
			</tModelInstanceDetails>
		</bindingTemplate>
		<bindingTemplate bindingKey="68280627-00E2-EE8D-6BBF-C6113993AA77" serviceKey="6828022E-00E2-E46A-9849-C6113993AA77">
			<description xml:lang="en">Order Status (Phone)</description>
			<accessPoint URLType="phone">1 888 746 7426</accessPoint>
			<tModelInstanceDetails>
				<tModelInstanceInfo tModelKey="uuid:68DE9E80-AD09-469D-8A37-088422BFBC36"/>
			</tModelInstanceDetails>
		</bindingTemplate>
		<bindingTemplate bindingKey="68280651-00E2-F4D5-6932-C6113993AA77" serviceKey="6828022E-00E2-E46A-9849-C6113993AA77">
			<description xml:lang="en">Order Status using IBM web page</description>
			<accessPoint URLType="http">http://commerce.www.ibm.com/cgi-bin/ncommerce/ExecMacro/signin.d2w/report?cntry=840&amp;lang=en_US&amp;cntrfnbr=1&amp;mmerfnbr=1&amp;shoprfnbr=1&amp;pagename=orderlstc%2Ed2w</accessPoint>
			<tModelInstanceDetails>
				<tModelInstanceInfo tModelKey="uuid:68DE9E80-AD09-469D-8A37-088422BFBC36"/>
			</tModelInstanceDetails>
		</bindingTemplate>
	</bindingTemplates>
	<categoryBag>
		<keyedReference keyName="NAICS: Computer and Computer Peripheral Equipment and Software Wholesalers" keyValue="42143" tModelKey="uuid:C0B9FE13-179F-413D-8A5B-5004DB8E5BB2"/>
		<keyedReference keyName="NAICS: Computer Facilities Management Services" keyValue="541513" tModelKey="uuid:C0B9FE13-179F-413D-8A5B-5004DB8E5BB2"/>
		<keyedReference keyName="NAICS: Computer Systems Design and Related Services" keyValue="5415" tModelKey="uuid:C0B9FE13-179F-413D-8A5B-5004DB8E5BB2"/>
		<keyedReference keyName="NAICS: Computer Systems Design and Related Services" keyValue="54151" tModelKey="uuid:C0B9FE13-179F-413D-8A5B-5004DB8E5BB2"/>
		<keyedReference keyName="NAICS: Computer Systems Design Services" keyValue="541512" tModelKey="uuid:C0B9FE13-179F-413D-8A5B-5004DB8E5BB2"/>
		<keyedReference keyName="NAICS: Computer Training" keyValue="61142" tModelKey="uuid:C0B9FE13-179F-413D-8A5B-5004DB8E5BB2"/>
		<keyedReference keyName="NAICS: Custom Computer Programming Services" keyValue="541511" tModelKey="uuid:C0B9FE13-179F-413D-8A5B-5004DB8E5BB2"/>
		<keyedReference keyName="NAICS: Data Processing Services" keyValue="5142" tModelKey="uuid:C0B9FE13-179F-413D-8A5B-5004DB8E5BB2"/>
		<keyedReference keyName="NAICS: Data Processing Services" keyValue="51421" tModelKey="uuid:C0B9FE13-179F-413D-8A5B-5004DB8E5BB2"/>
		<keyedReference keyName="NAICS: Other Computer Related Services" keyValue="541519" tModelKey="uuid:C0B9FE13-179F-413D-8A5B-5004DB8E5BB2"/>
		<keyedReference keyName="NAICS: Professional Management Development Training" keyValue="61143" tModelKey="uuid:C0B9FE13-179F-413D-8A5B-5004DB8E5BB2"/>
		<keyedReference keyName="NAICS: Software Publishers" keyValue="51121" tModelKey="uuid:C0B9FE13-179F-413D-8A5B-5004DB8E5BB2"/>
		<keyedReference keyName="UNSPSC: Administration software" keyValue="43162611" tModelKey="uuid:DB77450D-9FA8-45D4-A7BC-04411D14E384"/>
		<keyedReference keyName="UNSPSC: Backup or recovery software" keyValue="43162501" tModelKey="uuid:DB77450D-9FA8-45D4-A7BC-04411D14E384"/>
		<keyedReference keyName="UNSPSC: Cache memory" keyValue="43171901" tModelKey="uuid:DB77450D-9FA8-45D4-A7BC-04411D14E384"/>
		<keyedReference keyName="UNSPSC: Compiling softwares" keyValue="43162401" tModelKey="uuid:DB77450D-9FA8-45D4-A7BC-04411D14E384"/>
		<keyedReference keyName="UNSPSC: Computer mice" keyValue="43172205" tModelKey="uuid:DB77450D-9FA8-45D4-A7BC-04411D14E384"/>
		<keyedReference keyName="UNSPSC: Computer programmed instruction" keyValue="86141703" tModelKey="uuid:DB77450D-9FA8-45D4-A7BC-04411D14E384"/>
		<keyedReference keyName="UNSPSC: Computer vocational training services" keyValue="86101601" tModelKey="uuid:DB77450D-9FA8-45D4-A7BC-04411D14E384"/>
		<keyedReference keyName="UNSPSC: Configuration management software" keyValue="43162402" tModelKey="uuid:DB77450D-9FA8-45D4-A7BC-04411D14E384"/>
		<keyedReference keyName="UNSPSC: Database software" keyValue="43161501" tModelKey="uuid:DB77450D-9FA8-45D4-A7BC-04411D14E384"/>
		<keyedReference keyName="UNSPSC: Desktop communications software" keyValue="43162701" tModelKey="uuid:DB77450D-9FA8-45D4-A7BC-04411D14E384"/>
		<keyedReference keyName="UNSPSC: Development software" keyValue="43162403" tModelKey="uuid:DB77450D-9FA8-45D4-A7BC-04411D14E384"/>
		<keyedReference keyName="UNSPSC: Direct sales services" keyValue="80141701" tModelKey="uuid:DB77450D-9FA8-45D4-A7BC-04411D14E384"/>
		<keyedReference keyName="UNSPSC: Disk arrays" keyValue="43172304" tModelKey="uuid:DB77450D-9FA8-45D4-A7BC-04411D14E384"/>
		<keyedReference keyName="UNSPSC: Docking stations" keyValue="43171802" tModelKey="uuid:DB77450D-9FA8-45D4-A7BC-04411D14E384"/>
		<keyedReference keyName="UNSPSC: Dot matrix printers" keyValue="43172503" tModelKey="uuid:DB77450D-9FA8-45D4-A7BC-04411D14E384"/>
		<keyedReference keyName="UNSPSC: Electronic catalogs" keyValue="55111504" tModelKey="uuid:DB77450D-9FA8-45D4-A7BC-04411D14E384"/>
		<keyedReference keyName="UNSPSC: Electronic directories" keyValue="55111501" tModelKey="uuid:DB77450D-9FA8-45D4-A7BC-04411D14E384"/>
		<keyedReference keyName="UNSPSC: Engineering vocational training services" keyValue="86101610" tModelKey="uuid:DB77450D-9FA8-45D4-A7BC-04411D14E384"/>
		<keyedReference keyName="UNSPSC: File security or data security software" keyValue="43162503" tModelKey="uuid:DB77450D-9FA8-45D4-A7BC-04411D14E384"/>
		<keyedReference keyName="UNSPSC: Flat panel displays" keyValue="43172402" tModelKey="uuid:DB77450D-9FA8-45D4-A7BC-04411D14E384"/>
		<keyedReference keyName="UNSPSC: Gateway software" keyValue="43162609" tModelKey="uuid:DB77450D-9FA8-45D4-A7BC-04411D14E384"/>
		<keyedReference keyName="UNSPSC: General utility software" keyValue="43162508" tModelKey="uuid:DB77450D-9FA8-45D4-A7BC-04411D14E384"/>
		<keyedReference keyName="UNSPSC: Graphic accelerator cards" keyValue="43172005" tModelKey="uuid:DB77450D-9FA8-45D4-A7BC-04411D14E384"/>
		<keyedReference keyName="UNSPSC: Graphical user interface (GUI) tools" keyValue="43162404" tModelKey="uuid:DB77450D-9FA8-45D4-A7BC-04411D14E384"/>
		<keyedReference keyName="UNSPSC: Hard drives" keyValue="43172313" tModelKey="uuid:DB77450D-9FA8-45D4-A7BC-04411D14E384"/>
		<keyedReference keyName="UNSPSC: Interactive voice response software" keyValue="43162703" tModelKey="uuid:DB77450D-9FA8-45D4-A7BC-04411D14E384"/>
		<keyedReference keyName="UNSPSC: Keyboards" keyValue="43172204" tModelKey="uuid:DB77450D-9FA8-45D4-A7BC-04411D14E384"/>
		<keyedReference keyName="UNSPSC: Label printers" keyValue="43172504" tModelKey="uuid:DB77450D-9FA8-45D4-A7BC-04411D14E384"/>
		<keyedReference keyName="UNSPSC: Large format printers" keyValue="43172505" tModelKey="uuid:DB77450D-9FA8-45D4-A7BC-04411D14E384"/>
		<keyedReference keyName="UNSPSC: Laser printers" keyValue="43172510" tModelKey="uuid:DB77450D-9FA8-45D4-A7BC-04411D14E384"/>
		<keyedReference keyName="UNSPSC: License management software" keyValue="43162608" tModelKey="uuid:DB77450D-9FA8-45D4-A7BC-04411D14E384"/>
		<keyedReference keyName="UNSPSC: Line matrix printers" keyValue="43172506" tModelKey="uuid:DB77450D-9FA8-45D4-A7BC-04411D14E384"/>
		<keyedReference keyName="UNSPSC: Mainframe computers" keyValue="43171805" tModelKey="uuid:DB77450D-9FA8-45D4-A7BC-04411D14E384"/>
		<keyedReference keyName="UNSPSC: Mainframe transaction processing software" keyValue="43162607" tModelKey="uuid:DB77450D-9FA8-45D4-A7BC-04411D14E384"/>
		<keyedReference keyName="UNSPSC: Modems" keyValue="43172802" tModelKey="uuid:DB77450D-9FA8-45D4-A7BC-04411D14E384"/>
		<keyedReference keyName="UNSPSC: Monitors" keyValue="43172401" tModelKey="uuid:DB77450D-9FA8-45D4-A7BC-04411D14E384"/>
		<keyedReference keyName="UNSPSC: Multi-drive hard drive towers" keyValue="43172307" tModelKey="uuid:DB77450D-9FA8-45D4-A7BC-04411D14E384"/>
		<keyedReference keyName="UNSPSC: Network connectivity terminal emulation software" keyValue="43162606" tModelKey="uuid:DB77450D-9FA8-45D4-A7BC-04411D14E384"/>
		<keyedReference keyName="UNSPSC: Network interface cards" keyValue="43172006" tModelKey="uuid:DB77450D-9FA8-45D4-A7BC-04411D14E384"/>
		<keyedReference keyName="UNSPSC: Network operating system software" keyValue="43162604" tModelKey="uuid:DB77450D-9FA8-45D4-A7BC-04411D14E384"/>
		<keyedReference keyName="UNSPSC: Networking developer\'s software" keyValue="43162605" tModelKey="uuid:DB77450D-9FA8-45D4-A7BC-04411D14E384"/>
		<keyedReference keyName="UNSPSC: Notebook computers" keyValue="43171801" tModelKey="uuid:DB77450D-9FA8-45D4-A7BC-04411D14E384"/>
		<keyedReference keyName="UNSPSC: Operating system enhancement software" keyValue="43162603" tModelKey="uuid:DB77450D-9FA8-45D4-A7BC-04411D14E384"/>
		<keyedReference keyName="UNSPSC: Page printers" keyValue="43172507" tModelKey="uuid:DB77450D-9FA8-45D4-A7BC-04411D14E384"/>
		<keyedReference keyName="UNSPSC: Platform interconnectivity software" keyValue="43162601" tModelKey="uuid:DB77450D-9FA8-45D4-A7BC-04411D14E384"/>
		<keyedReference keyName="UNSPSC: Port replicators" keyValue="43171807" tModelKey="uuid:DB77450D-9FA8-45D4-A7BC-04411D14E384"/>
		<keyedReference keyName="UNSPSC: Program testing software" keyValue="43162406" tModelKey="uuid:DB77450D-9FA8-45D4-A7BC-04411D14E384"/>
		<keyedReference keyName="UNSPSC: Programming languages" keyValue="43162405" tModelKey="uuid:DB77450D-9FA8-45D4-A7BC-04411D14E384"/>
		<keyedReference keyName="UNSPSC: Reel to reel tape drives" keyValue="43172309" tModelKey="uuid:DB77450D-9FA8-45D4-A7BC-04411D14E384"/>
		<keyedReference keyName="UNSPSC: Sales promotion services" keyValue="80141601" tModelKey="uuid:DB77450D-9FA8-45D4-A7BC-04411D14E384"/>
		<keyedReference keyName="UNSPSC: Servers" keyValue="43171806" tModelKey="uuid:DB77450D-9FA8-45D4-A7BC-04411D14E384"/>
		<keyedReference keyName="UNSPSC: Single optical drives" keyValue="43172310" tModelKey="uuid:DB77450D-9FA8-45D4-A7BC-04411D14E384"/>
		<keyedReference keyName="UNSPSC: Tape arrays" keyValue="43172311" tModelKey="uuid:DB77450D-9FA8-45D4-A7BC-04411D14E384"/>
		<keyedReference keyName="UNSPSC: Tape drive auto loaders or libraries" keyValue="43172312" tModelKey="uuid:DB77450D-9FA8-45D4-A7BC-04411D14E384"/>
		<keyedReference keyName="UNSPSC: Temporary information technology networking specialists" keyValue="80111610" tModelKey="uuid:DB77450D-9FA8-45D4-A7BC-04411D14E384"/>
		<keyedReference keyName="UNSPSC: Temporary information technology software developers" keyValue="80111608" tModelKey="uuid:DB77450D-9FA8-45D4-A7BC-04411D14E384"/>
		<keyedReference keyName="UNSPSC: Temporary information technology systems or database administrators" keyValue="80111609" tModelKey="uuid:DB77450D-9FA8-45D4-A7BC-04411D14E384"/>
		<keyedReference keyName="UNSPSC: Touch screen monitors" keyValue="43172403" tModelKey="uuid:DB77450D-9FA8-45D4-A7BC-04411D14E384"/>
		<keyedReference keyName="UNSPSC: Transaction server software" keyValue="43162612" tModelKey="uuid:DB77450D-9FA8-45D4-A7BC-04411D14E384"/>
		<keyedReference keyName="UNSPSC: Voice microphones for computers" keyValue="43172211" tModelKey="uuid:DB77450D-9FA8-45D4-A7BC-04411D14E384"/>
		<keyedReference keyName="UNSPSC: Voice recognition software" keyValue="43161804" tModelKey="uuid:DB77450D-9FA8-45D4-A7BC-04411D14E384"/>
		<keyedReference keyName="UNSPSC: Wholesale distribution services" keyValue="80141702" tModelKey="uuid:DB77450D-9FA8-45D4-A7BC-04411D14E384"/>
		<keyedReference keyName="UNSPSC: Workstations, desktop computers" keyValue="43171803" tModelKey="uuid:DB77450D-9FA8-45D4-A7BC-04411D14E384"/>
	</categoryBag>
</businessService>
</save_service>
';

  ret := uddi_str_get (uri, s1);
  ret := xml_tree_doc (ret);

  get_err (ret);

  name := xpath_eval ('/Envelope/Body/serviceDetail/businessService/categoryBag/keyedReference', ret, 0);

  if (length (name) = 75)
    return 1;

  signal ('UDDI3', 'add_service wrong service name length');
}
;


create procedure
if_ok (in ret varchar)
{
  declare ret_temp varchar;

  ret_temp := ret;

  if (__tag(ret) <> 230)
    ret := xml_tree_doc (ret);

  ret := cast (xpath_eval ('//@errCode', ret, 1) as varchar);

  if (ret = 'E_success')
    return 1;

  get_err (ret_temp);
}
;


create procedure
get_err (in ret varchar)
{
  declare err varchar;
  err := cast (xpath_eval ('//@errCode', ret, 1) as varchar);

  if (not err is NULL)
    signal ('UDDI1', cast (xpath_eval ('/Envelope/Body/Fault/detail/dispositionReport/result/errInfo',
	ret, 1) as varchar));

  return 1;
}
;


create procedure
t_delete_service (in uri varchar)
{
  declare s1 varchar;

  s1 := '<delete_service xmlns="urn:uddi-org:api" generic="1.0"><serviceKey>6828022E-00E2-E46A-9849-C6113993AA77</serviceKey></delete_service>';

  return if_ok (uddi_str_get (uri, s1));
}
;


create procedure
t_delete_business (in uri varchar)
{
  declare s1, res varchar;
  declare ret any;

  s1 := '<delete_business xmlns="urn:uddi-org:api" generic="1.0"><businessKey>871C648D-B219-4E3A-89E9-FCA87D3114A5</businessKey><businessKey>2E4BF055-63FF-40E7-B54C-0467CEE060D5</businessKey></delete_business>';

  return if_ok (uddi_str_get (uri, s1));
}
;


create procedure
t_delete_business_wrong (in uri varchar)
{
  declare s1, res varchar;
  declare ret any;

  s1 := '<delete_business xmlns="urn:uddi-org:api" generic="1.0"><businessKey>871C648D-B219-4E3A-89E9-FCA87D3114A8</businessKey></delete_business>';

  ret := uddi_str_get (uri, s1);
  ret := xml_tree_doc (ret);
  ret := cast (xpath_eval ('//@errCode', ret, 1) as varchar);

  if (ret = 'E_invalidKeyPassed')
    return 1;

  return 0;
}
;


select add_bussines_1 ('http://localhost:$U{HTTPPORT}/SOAP');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": UDDI save_business 1: STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select add_bussines_2 ('http://localhost:$U{HTTPPORT}/SOAP');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": UDDI save_business 2: STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select t_find_business_order_a ('http://localhost:$U{HTTPPORT}/SOAP');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": UDDI find_business sortByNameAsc : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select t_find_business_order_d ('http://localhost:$U{HTTPPORT}/SOAP');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": UDDI find_business sortByNameDesc : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select t_find_business ('http://localhost:$U{HTTPPORT}/SOAP');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": UDDI find_business : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select t_find_business_2 ('http://localhost:$U{HTTPPORT}/SOAP', 1);
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": UDDI find_business before add service: STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select add_service ('http://localhost:$U{HTTPPORT}/SOAP');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": UDDI save_service : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select t_find_business_2 ('http://localhost:$U{HTTPPORT}/SOAP', 2);
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": UDDI find_business after add service: STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select t_delete_service ('http://localhost:$U{HTTPPORT}/SOAP');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": UDDI delete_service: STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select t_find_business_2 ('http://localhost:$U{HTTPPORT}/SOAP', NULL);
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": UDDI find_business after delete service: STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select t_delete_business_wrong ('http://localhost:$U{HTTPPORT}/SOAP');
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": UDDI delete_business wrong Business key: STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select t_delete_business ('http://localhost:$U{HTTPPORT}/SOAP');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": UDDI delete_business : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select count (*) from UDDI.DBA.BUSINESS_ENTITY;
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": UDDI count (*) UDDI.DBA.BUSINESS_ENTITY: STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select count (*) from UDDI.DBA.DISCOVERY_URL;
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": UDDI count (*) UDDI.DBA.DISCOVERY_URL: STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select count (*) from UDDI.DBA.CONTACTS;
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": UDDI count (*) UDDI.DBA.CONTACTS: STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select count (*) from UDDI.DBA.ADDRESS_LINE;
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": UDDI count (*) UDDI.DBA.ADDRESS_LINE: STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select count (*) from UDDI.DBA.BUSINESS_SERVICE;
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": UDDI count (*) UDDI.DBA.BUSINESS_SERVICE: STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select count (*) from UDDI.DBA.BINDING_TEMPLATE;
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": UDDI count (*) UDDI.DBA.BINDING_TEMPLATE: STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select count (*) from UDDI.DBA.INSTANCE_DETAIL;
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": UDDI count (*) UDDI.DBA.INSTANCE_DETAIL: STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select count (*) from UDDI.DBA.OVERVIEW_DOC;
ECHO BOTH $IF $EQU $LAST[1] 14 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": UDDI count (*) UDDI.DBA.OVERVIEW_DOC: STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select count (*) from UDDI.DBA.TMODEL;
ECHO BOTH $IF $EQU $LAST[1] 14 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": UDDI count (*) UDDI.DBA.TMODEL: STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select count (*) from UDDI.DBA.IDENTIFIER_BAG;
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": UDDI count (*) UDDI.DBA.IDENTIFIER_BAG: STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select count (*) from UDDI.DBA.CATEGORY_BAG;
ECHO BOTH $IF $EQU $LAST[1] 20 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": UDDI count (*) UDDI.DBA.CATEGORY_BAG: STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select count (*) from UDDI.DBA.DESCRIPTION;
ECHO BOTH $IF $EQU $LAST[1] 28 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": UDDI count (*) UDDI.DBA.DESCRIPTION: STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select count (*) from UDDI.DBA.EMAIL;
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": UDDI count (*) UDDI.DBA.EMAIL: STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select count (*) from UDDI.DBA.PHONE;
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": UDDI count (*) UDDI.DBA.PHONE: STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

-- SOAP datatypes tests
use DB;

select soap_dt_define ('', file_to_string ('xsd/c1.xsd'));
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": STATE=" $STATE " MESSAGE=" $MESSAGE;
select xpath_eval ('string(/complexType/@name)', xml_tree_doc (file_to_string ('xsd/c1.xsd')), 1);
ECHO BOTH " (" $LAST[1] ")\n";

select soap_dt_define ('', file_to_string ('xsd/c2.xsd'));
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": " $LAST[1];
ECHO BOTH " STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

-- choice is handled now
select soap_dt_define ('', file_to_string ('xsd/c3.xsd'));
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": " $LAST[1];
ECHO BOTH ": STATE=" $STATE " MESSAGE=" $MESSAGE;
--select xpath_eval ('string(/complexType/@name)', xml_tree_doc (file_to_string ('xsd/c3.xsd')), 1);
--ECHO BOTH " (" $LAST[1] ")\n";

select soap_dt_define ('', file_to_string ('xsd/c4.xsd'));
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": " $LAST[1];
ECHO BOTH " STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select soap_dt_define ('', file_to_string ('xsd/i1.xsd'));
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": " $LAST[1];
ECHO BOTH " STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select soap_dt_define ('', file_to_string ('xsd/i2.xsd'));
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": " $LAST[1];
ECHO BOTH " STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select soap_dt_define ('', file_to_string ('xsd/i3.xsd'));
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": " $LAST[1];
ECHO BOTH " STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select soap_dt_define ('', file_to_string ('xsd/i4.xsd'));
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": " $LAST[1];
ECHO BOTH " STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select soap_dt_define ('', file_to_string ('xsd/i5.xsd'));
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": " $LAST[1];
ECHO BOTH " STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select soap_dt_define ('', file_to_string ('xsd/i6.xsd'));
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": " $LAST[1];
ECHO BOTH " STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select soap_dt_define ('', file_to_string ('xsd/m1.xsd'));
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": " $LAST[1];
ECHO BOTH " STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select soap_dt_define ('', file_to_string ('xsd/m2.xsd'));
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": STATE=" $STATE " MESSAGE=" $MESSAGE;
select xpath_eval ('string(/complexType/@name)', xml_tree_doc (file_to_string ('xsd/m2.xsd')), 1);
ECHO BOTH " (" $LAST[1] ")\n";

select soap_dt_define ('', file_to_string ('xsd/m3.xsd'));
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": STATE=" $STATE " MESSAGE=" $MESSAGE;
select xpath_eval ('string(/complexType/@name)', xml_tree_doc (file_to_string ('xsd/m3.xsd')), 1);
ECHO BOTH " (" $LAST[1] ")\n";

select soap_dt_define ('', file_to_string ('xsd/m4.xsd'));
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": " $LAST[1];
ECHO BOTH ": STATE=" $STATE " MESSAGE=" $MESSAGE;
--select xpath_eval ('string(/complexType/@name)', xml_tree_doc (file_to_string ('xsd/m4.xsd')), 1);
--ECHO BOTH " (" $LAST[1] ")\n";

select soap_dt_define ('', file_to_string ('xsd/mx1.xsd'));
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": STATE=" $STATE " MESSAGE=" $MESSAGE;
select xpath_eval ('string(/complexType/@name)', xml_tree_doc (file_to_string ('xsd/mx1.xsd')), 1);
ECHO BOTH " (" $LAST[1] ")\n";

select soap_dt_define ('', file_to_string ('xsd/o1.xsd'));
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": " $LAST[1];
ECHO BOTH " STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select soap_dt_define ('', file_to_string ('xsd/o2.xsd'));
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": " $LAST[1];
ECHO BOTH " STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select soap_dt_define ('', file_to_string ('xsd/o3.xsd'));
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": " $LAST[1];
ECHO BOTH " STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select soap_dt_define ('', file_to_string ('xsd/o4.xsd'));
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": STATE=" $STATE " MESSAGE=" $MESSAGE;
select xpath_eval ('string(/complexType/@name)', xml_tree_doc (file_to_string ('xsd/o4.xsd')), 1);
ECHO BOTH " (" $LAST[1] ")\n";

select soap_dt_define ('', file_to_string ('xsd/o5.xsd'));
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": " $LAST[1];
ECHO BOTH " STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select soap_dt_define ('', file_to_string ('xsd/s1.xsd'));
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": " $LAST[1];
ECHO BOTH " STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select soap_dt_define ('', file_to_string ('xsd/mda.xsd'));
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": " $LAST[1];
ECHO BOTH " STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select soap_dt_define ('', file_to_string ('xsd/fake.xsd'));
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": " $LAST[1];
ECHO BOTH " STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select SDT_NAME from SYS_SOAP_DATATYPES;









select soap_print_box_validating (soap_box_structure ('i1',1,'i2',2,'i3',3), 'A', 'services.wsdl:IntStruct', 1, 1);
ECHO BOTH $IF $EQU $LAST[1] "<A xsi:type='wsdl:IntStruct' xmlns:xsi='http://www.w3.org/2001/XMLSchema-instance' xmlns:wsdl='services.wsdl'><i1 xsi:type='xsd:int' xmlns:xsi='http://www.w3.org/2001/XMLSchema-instance' xmlns:xsd='http://www.w3.org/2001/XMLSchema'>1</i1><i2 xsi:type='xsd:int' xmlns:xsi='http://www.w3.org/2001/XMLSchema-instance' xmlns:xsd='http://www.w3.org/2001/XMLSchema'>2</i2><i3 xsi:type='xsd:int' xmlns:xsi='http://www.w3.org/2001/XMLSchema-instance' xmlns:xsd='http://www.w3.org/2001/XMLSchema'>3</i3></A>" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": IntStruct (struct of integers) STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select aref(soap_box_xml_entity_validating(xml_tree(
	soap_print_box_validating (soap_box_structure ('i1',1,'i2',2,'i3',3), 'A', 'services.wsdl:IntStruct', 1, 1) ), 'services.wsdl:IntStruct')
    , 7);
ECHO BOTH $IF $EQU $LAST[1] 3 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": xml_entity_validating for IntStruct last value : " $LAST[1] "\n";

select soap_print_box_validating (vector (1,2,3), 'A', 'services.wsdl:ArrayOfint2', 1, 1);
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": upper limmit for array elements STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select soap_print_box_validating (vector (1,2,3,4), 'A', 'services.wsdl:ArrayOfint2', 1, 1);
ECHO BOTH $IF $NEQ $STATE OK  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": above max elements limit  STATE=" $STATE " MESSAGE=" $MESSAGE "\n";


select soap_print_box_validating (vector (1), 'A', 'services.wsdl:ArrayOfint2', 1, 1);
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": min elements limit  STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select soap_print_box_validating (vector (), 'A', 'services.wsdl:ArrayOfint2', 1, 1);
ECHO BOTH $IF $NEQ $STATE OK  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": under min elements limit  STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

-- can be crash of the server , test it
select soap_print_box_validating (vector (soap_box_structure ()), 'A', 'services.wsdl:', 1, 1);
ECHO BOTH $IF $NEQ $STATE OK  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": missing data type name STATE=" $STATE " MESSAGE=" $MESSAGE "\n";


-- empty array test
select soap_print_box_validating (vector (soap_box_structure ()), 'A', 'services.wsdl:ArrayOfSOAPStruct', 0, 0);
ECHO BOTH $IF $EQU $LAST[1] "<A xsi:type='SOAP-ENC:Array' SOAP-ENC:arrayType='wsdl:SOAPStruct[1]'><item xsi:nil='1' /></A>"  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": empty array test result : " $LAST[1] "\n";

select soap_print_box_validating (vector (), 'A', 'services.wsdl:ArrayOfSOAPStruct', 1, 1);

select soap_print_box_validating (vector (soap_box_structure ('varString','aa','varInt',12, 'varFloat', cast (14.0 as float))), 'A', 'services.wsdl:ArrayOfSOAPStruct', 1, 1);

soap_box_xml_entity_validating(xml_tree(soap_print_box_validating (vector (soap_box_structure ('varString','aa','varInt',12, 'varFloat', cast (14.0 as real)),soap_box_structure ('varString','aa','varInt',12, 'varFloat', cast (14.0 as real))), 'A', 'services.wsdl:ArrayOfSOAPStruct', 1, 1)), 'services.wsdl:IntStruct');

select aref (aref (soap_box_xml_entity_validating(xml_tree(soap_print_box_validating (vector (soap_box_structure ('varString','aa','varInt',12, 'varFloat', cast (14.0 as real)),soap_box_structure ('varString','aa','varInt',12, 'varFloat', cast (14.0 as real))), 'A', 'services.wsdl:ArrayOfSOAPStruct', 1, 1)), 'services.wsdl:ArrayOfSOAPStruct'),1), 7);

ECHO BOTH $IF $EQU $LAST[1] '14' "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": xml_entity_validating for ArrayOfSOAPStruct last value : " $LAST[1] "\n";

select soap_print_box_validating (vector (vector('a','b'), vector('c','d')), 'A', 'services.wsdl:ArrayOf2Dstring', 1, 1);
ECHO BOTH $IF $EQU $STATE OK  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": 2D string array data type STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select soap_print_box_validating (vector (vector('a','b'), vector('c')), 'A', 'services.wsdl:ArrayOf2Dstring', 1, 1);
ECHO BOTH $IF $NEQ $STATE OK  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": wrong PL type of 2D string array data type STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select aref (aref (soap_box_xml_entity_validating (xml_tree (soap_print_box_validating (vector (vector('a','b'), vector('cdata','d')), 'A', 'services.wsdl:ArrayOf2Dstring', 1, 1)),'services.wsdl:ArrayOf2Dstring'),1),0);
ECHO BOTH $IF $EQU $LAST[1] 'cdata' "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": xml_entity_validating for ArrayOf2Dstring value of (2,1) is : " $LAST[1] "\n";

-- PL value validating  against XSD

-- boolean errors
select soap_print_box_validating ('', 'A', 'boolean', 0, 0);
ECHO BOTH $IF $NEQ $STATE OK  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": boolean STATE=" $STATE " MESSAGE=" $MESSAGE "\n";
select soap_print_box_validating (2, 'A', 'boolean', 0, 0);
ECHO BOTH $IF $NEQ $STATE OK  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": boolean STATE=" $STATE " MESSAGE=" $MESSAGE "\n";
select soap_print_box_validating (soap_boolean(2), 'A', 'boolean', 0, 0);
ECHO BOTH $IF $NEQ $STATE OK  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": boolean STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

-- datetime errors
select soap_print_box_validating ('', 'A', 'dateTime', 0, 0);
ECHO BOTH $IF $NEQ $STATE OK  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": dateTime STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

-- integer errors
select soap_print_box_validating ('', 'A', 'int', 0, 0);
ECHO BOTH $IF $NEQ $STATE OK  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": int STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select soap_print_box_validating ('1', 'A', 'int', 0, 0);
ECHO BOTH $IF $NEQ $STATE OK  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": int STATE=" $STATE " MESSAGE=" $MESSAGE "\n";


-- string errors
select soap_print_box_validating (1, 'A', 'string', 0, 0);
ECHO BOTH $IF $NEQ $STATE OK  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": string STATE=" $STATE " MESSAGE=" $MESSAGE "\n";
select soap_print_box_validating (now (), 'A', 'string', 0, 0);
ECHO BOTH $IF $NEQ $STATE OK  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": string STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

-- schema errors
select soap_print_box_validating (vector (), 'A', 'services.wsdl:SOAPfake', 0, 0);
ECHO BOTH $IF $NEQ $STATE OK  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": no definition STATE=" $STATE " MESSAGE=" $MESSAGE "\n";
select soap_print_box_validating (vector (), 'A', 'services.wsdl:Fakeint', 0, 0);
ECHO BOTH $IF $NEQ $STATE OK  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": wrong base type STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

-- structure errors
select soap_print_box_validating (vector (), 'A', 'services.wsdl:SOAPStruct', 0, 0);
ECHO BOTH $IF $NEQ $STATE OK  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": PL struct STATE=" $STATE " MESSAGE=" $MESSAGE "\n";
select soap_print_box_validating (soap_box_structure ('varInt',0,'varString','str'), 'A', 'services.wsdl:SOAPStruct', 0, 0);
ECHO BOTH $IF $NEQ $STATE OK  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": PL struct STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

-- array errors
select soap_print_box_validating (vector (), 'A', 'services.wsdl:ArrayOfint2', 0, 0);
ECHO BOTH $IF $NEQ $STATE OK  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": PL array STATE=" $STATE " MESSAGE=" $MESSAGE "\n";
select soap_print_box_validating (vector (1,2,3,4), 'A', 'services.wsdl:ArrayOfint2', 0, 0);
ECHO BOTH $IF $NEQ $STATE OK  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": PL array STATE=" $STATE " MESSAGE=" $MESSAGE "\n";
select soap_print_box_validating ('', 'A', 'services.wsdl:ArrayOfint2', 0, 0);
ECHO BOTH $IF $NEQ $STATE OK  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": PL array STATE=" $STATE " MESSAGE=" $MESSAGE "\n";
select soap_print_box_validating (soap_boolean(1), 'A', 'services.wsdl:ArrayOfint2', 0, 0);
ECHO BOTH $IF $NEQ $STATE OK  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": PL array STATE=" $STATE " MESSAGE=" $MESSAGE "\n";




ECHO BOTH "COMPLETED WITH " $ARGV[0] " FAILED, " $ARGV[1] " PASSED: SOAP&UDDI tests\n";

ECHO BOTH "STARTED: DIME functions checkup\n";

SET ARGV[0] 0;
SET ARGV[1] 0;


select aref(aref(dime_tree(dime_compose(vector(vector ('id', 'unknown', '1234567890')))), 0), 0);
ECHO BOTH $IF $EQU $LAST[1] 'id' "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": dime_tree(dime_compose(id/unknown/1234567890)) produced ID: " $LAST[1] "\n";

select aref(aref(dime_tree(dime_compose(vector(vector ('id', 'unknown', '1234567890')))), 0), 1);
ECHO BOTH $IF $EQU $LAST[1] '' "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": dime_tree(dime_compose(id/unknown/1234567890)) produced TYPE: " $LAST[1] "\n";

select aref(aref(dime_tree(dime_compose(vector(vector ('id', 'unknown', '1234567890')))), 0), 2);
ECHO BOTH $IF $EQU $LAST[1] '1234567890' "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": dime_tree(dime_compose(id/unknown/1234567890)) produced DATA: " $LAST[1] "\n";

select aref(aref(dime_tree(dime_compose(vector(vector ('id', '', '1234567890')))), 0), 1);
ECHO BOTH $IF $EQU $LAST[1] '' "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": dime_tree(dime_compose(id//1234567890)) produced TYPE: " $LAST[1] "\n";

select aref(aref(dime_tree(dime_compose(vector(vector ('id', 'text/xml', '1234567890')))), 0), 1);
ECHO BOTH $IF $EQU $LAST[1] 'text/xml' "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": dime_tree(dime_compose(id / text/xml / 1234567890)) produced TYPE: " $LAST[1] "\n";

select aref(aref(dime_tree(dime_compose(vector(vector ('id', 'http://some.url.org', '1234567890')))), 0), 1);
ECHO BOTH $IF $EQU $LAST[1] 'http://some.url.org' "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": dime_tree(dime_compose(id / text/xml / 1234567890)) produced TYPE: " $LAST[1] "\n";


select aref(aref(dime_tree(dime_compose(vector(vector ('id', 'unknown', '12345', 1), vector ('','','67890', 1)))), 0), 2);
ECHO BOTH $IF $EQU $LAST[1] '1234567890' "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": dime_tree(dime_compose(id/unknown/12345///67890)) CHUNKED payload produced data: " $LAST[1] "\n";

create procedure
make_garbage (in dm any, in f varchar, in val integer)
{
  if (f = 'MB')
    aset (dm, 0, val);
  if (f = 'TNF')
    aset (dm, 2, val);
  if (f = 'TNF1')
    aset (dm, 18, val);
  return dm;
}

--dime_tree(make_garbage (dime_compose(vector(vector ('id', 'http://some.url.org', '1234567890'))), 'MB', 0));
dime_tree('\x08\x00\x00\x00\x00\x02\x00\x13\x00\x00\x00\x0A\x69\x64\x00\x00\x68\x74\x74\x70\x3A\x2F\x2F\x73\x6F\x6D\x65\x2E\x75\x72\x6C\x2E\x6F\x72\x67\x00\x31\x32\x33\x34\x35\x36\x37\x38\x39\x30\x00\x00');
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Wrong MB : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

dime_tree('\x0E\x30\x00\x00\x00\x02\x00\x13\x00\x00\x00\x0A\x69\x64\x00\x00\x68\x74\x74\x70\x3A\x2F\x2F\x73\x6F\x6D\x65\x2E\x75\x72\x6C\x2E\x6F\x72\x67\x00\x31\x32\x33\x34\x35\x36\x37\x38\x39\x30\x00\x00');
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Wrong TNF : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

dime_tree(make_garbage (dime_compose(vector(vector ('id', 'http', '1234', 1),vector ('','','6789', 1))), 'TNF1', 96));
dime_tree ('\x0D\x00\x00\x00\x00\x02\x00\x00\x00\x00\x00\x04\x69\x64\x00\x00\x31\x32\x33\x34\x0A\x30\x00\x00\x00\x00\x00\x00\x00\x00\x00\x04\x36\x37\x38\x39');
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Wrong TNF : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

dime_tree ('\x0D\x00\x00\x00\x00\x02\x00\x00\x00\x00\x00\x04\x69\x64\x00\x00\x31\x32\x33\x34\x0D\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x04\x36\x37\x38\x39');
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Wrong ME : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";


dime_tree ('\x80\x02\x60\x00\x00\x00\x00\x04\x69\x64\x00\x00\x31\x32\x33\x34\x00\x02\x60\x00\x00\x00\x00\x04\x69\x64\x00\x00\x31\x32\x33\x34');
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Wrong Version : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

dime_tree ('\x80\x02\x60\x00\x00\x00\x00\x04\x69\x64\x00\x00\x31\x32\x33\x34\x60\x02\x60\x00\x00\x00\x00\x04\x69\x64\x00\x00\x31\x32\x33\x34');
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Wrong ME : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

dime_tree ('\xA0\x02\x60\x00\x00\x00\x00\x04\x69\x64\x00\x00\x31\x32\x33\x34\x40\x02\x60\x00\x00\x00\x00\x04\x69\x64\x00\x00\x31\x32\x33\x34');
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Wrong TNF : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

dime_tree ('\xA0\x02\x60\x00\x00\x00\x00\x04\x69\x64\x00\x00\x31\x32\x33\x34\x40\x02\x00\x02\x00\x00\x00\x04\x69\x64\x00\x00\x31\x32\x33\x34');
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Wrong type on middle chunk : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

SOAP ('$U{HTTPPORT}', 1, 11, 8);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "*** FAILED";
ECHO BOTH ": calling SOAP 1.1 (DIME encoded) 1 STATE=" $STATE " MESSAGE=" $MESSAGE "\n";
ECHO BOTH $IF $NEQ $LAST[1] OK "*** FAILED" $IF $NEQ $LAST[2] 'DB_NULL' "*** FAILED" "PASSED";
ECHO BOTH ": varchar NULL param\n";
ECHO BOTH $IF $NEQ $LAST[3] OK "*** FAILED" $IF $NEQ $LAST[4] 'REAL' "*** FAILED" "PASSED";
ECHO BOTH ": real param\n";
ECHO BOTH $IF $NEQ $LAST[5] OK "*** FAILED" $IF $NEQ $LAST[6] 'DOUBLE PRECISION' "*** FAILED" "PASSED";
ECHO BOTH ": double param\n";
ECHO BOTH $IF $NEQ $LAST[7] OK "*** FAILED" $IF $NEQ $LAST[8] 'DECIMAL' "*** FAILED" "PASSED";
ECHO BOTH ": numeric param\n";
ECHO BOTH $IF $NEQ $LAST[9] OK "*** FAILED" $IF $NEQ $LAST[10] 'DATETIME' "*** FAILED" "PASSED";
ECHO BOTH ": datetime param\n";
ECHO BOTH $IF $NEQ $LAST[11] OK "*** FAILED" $IF $NEQ $LAST[12] ARRAY_OF_POINTER "*** FAILED" "PASSED";
ECHO BOTH ": vector param\n";
ECHO BOTH $IF $NEQ $LAST[13] OK "*** FAILED" $IF $NEQ $LAST[14] 'INTEGER' "*** FAILED" "PASSED";
ECHO BOTH ": integer param\n";

ECHO BOTH "COMPLETED WITH " $ARGV[0] " FAILED, " $ARGV[1] " PASSED: DIME functions tests\n";
