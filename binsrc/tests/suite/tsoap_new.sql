--
--  $Id: tsoap_new.sql,v 1.3.10.1 2013/01/02 16:15:26 source Exp $
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

  ret := soap_call_new (concat ('localhost:', port), '/SOAP', 'fake', 'SOAPTEST',
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

create procedure DB.DBA.SOAPTEST ()
{
  return 12;
};
ECHO BOTH $IF $EQU $STATE OK "PASSED" "*** FAILED";
ECHO BOTH ": creating VSP SOAP server procedure STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

soap_call_new ('localhost:$U{HTTPPORT}', '/vspsoap.vsp', 'fake', 'test', vector(), 11);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "*** FAILED";
ECHO BOTH ": calling the VSP SOAP server with fake#test STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

soap_call_new ('localhost:$U{HTTPPORT}', '/vspsoap.vsp', 'fake', 'test1', vector(), 11);
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "*** FAILED";
ECHO BOTH ": calling the VSP SOAP server with fake#test1 STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

soap_call_new ('localhost:$U{HTTPPORT}', '/vspsoap.vsp', NULL, 'test', vector(), 11);
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "*** FAILED";
ECHO BOTH ": calling the VSP SOAP server with test STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create module DB.DBA.SOAPMOD {
  procedure SOAPMOD1(in par int) returns int { return par + 1; };
  procedure SOAPMOD2(inout par2 int) { return par2 + 1; };
  procedure SOAPMOD3() { return 14; };
};

select xml_tree_doc (soap_sdl ('DB.DBA.SOAPMOD', 'URL'));
ECHO BOTH $IF $EQU $STATE OK "PASSED" "*** FAILED";
ECHO BOTH ": SDL for a module valid STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select xml_tree_doc (soap_wsdl ('DB.DBA.SOAPMOD', 'URL', 'NS'));
ECHO BOTH $IF $EQU $STATE OK "PASSED" "*** FAILED";
ECHO BOTH ": WSDL for a module valid STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

dbg_obj_print ( soap_call_new ('localhost:$U{HTTPPORT}', '/vspsoap_mod.vsp', 'fake', 'SOAPMOD3', vector(), 11));
ECHO BOTH $IF $EQU $STATE OK "PASSED" "*** FAILED";
ECHO BOTH ": calling the VSP SOAP server with SOAPMOD3 from module SOAPMOD STATE=" $STATE " MESSAGE=" $MESSAGE "\n";
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
