--  
--  $Id$
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
create procedure DB.DBA.exec_no_error (in expr varchar) {                                                     
  declare state, message, meta, result any;                                                                   
    exec(expr, state, message, vector(), 0, meta, result);                                                      
    }                                                                                                             
    ;

DB.DBA.VHOST_REMOVE (lpath=>'/Interop/documents');

DB.DBA.VHOST_DEFINE (lpath=>'/Interop/documents', ppath=>'/soapdemo/', vsp_user=>'dba', def_page=>'interop.html');

--drop table SERVICES;
DB.DBA.exec_no_error('create table SERVICES(
S_ID varchar not null,
S_NAME varchar,
S_DESCRIPTION varchar,
S_WSDL_URL varchar,
S_WEB_URL varchar,
PRIMARY KEY (S_ID)
)')
;

--drop table SERVERS;
DB.DBA.exec_no_error('create table SERVERS(
SV_NAME varchar,
SV_GROUP_NAME varchar,
SV_WSDL_URL varchar,
S_WEB_URL varchar,
R_SERVER_ERROR varchar,
PRIMARY KEY (SV_NAME, SV_GROUP_NAME)
)')
;

--drop table RESULTS;
DB.DBA.exec_no_error('create table RESULTS(
R_END_POINT varchar,
R_SERVER_NAME varchar,
R_SERVER_VERSION varchar,
R_SERVICE_WSDL varchar,
R_SERVICE_GROUP varchar,
R_SERVICE_NAME varchar,
R_SERVICE_RESULT varchar,
R_SERVICE_ERROR varchar,
R_SERVICE_REQ long varchar,
R_SERVICE_RESP long varchar,
R_TIME timestamp,
PRIMARY KEY (R_END_POINT, R_SERVICE_NAME)
)')
;

registry_set ('interop_clien_clear_stat', 'X registry_set (''interop_client'', ''0'')');
registry_set ('interop_client', '0');


create procedure FILL_SERVICE_LIST ()
{
   declare _list, ret any;
   declare len, idx integer;

   delete from SERVICES;
   commit work;

   ret := SOAP_WSDL_IMPORT ('http://www.pocketsoap.com/registration/service.wsdl', wire_dump=>1, drop_module=>1);

   _list := registrationAndNotificationService.ServiceList ();
   _list := _list[2];
   _list := xml_tree_doc (_list);

   _list := xpath_eval ('/Envelope/Body/ServiceListResponse/services/*', _list, 0);
   len := length (_list);
   idx := 0;

   while (idx < len)
     {
        declare _id, _name, _desc, _wsdl_url, _web_url varchar;
	declare _line any;

	_line := xml_cut (_list[idx]);

        _id := cast (xpath_eval ('/Service/id', _line, 1) as varchar);
        _name := cast (xpath_eval ('/Service/name', _line, 1) as varchar);
        _desc := cast (xpath_eval ('/Service/description', _line, 1) as varchar);
        _web_url := cast (xpath_eval ('/Service/websiteURL', _line, 1) as varchar);
        _wsdl_url := cast (xpath_eval ('/Service/wsdlURL', _line, 1) as varchar);

	insert into SERVICES (S_ID, S_NAME, S_DESCRIPTION, S_WEB_URL, S_WSDL_URL)
	       values (_id, _name, _desc, _web_url, _wsdl_url);

	idx := idx + 1;
     }
}
;

--FILL_SERVICE_LIST ()
--;
delete from DB.DBA.SYS_SCHEDULED_EVENT where SE_SQL = 'RUN_TESTS()'
;


create procedure START_TESTS ()
{
   insert into DB.DBA.SYS_SCHEDULED_EVENT (SE_NAME, SE_START, SE_SQL, SE_INTERVAL)
       values ('SOAP_CLIENT_ALL_TESTS', dateadd ('minute', -10, now ()), 'RUN_TESTS()', 144000);
   scheduler_do_round (0);
}
;


create procedure RUN_TESTS ()
{
  declare exit handler for SQLSTATE '*'
    {
	goto _end;
    };

  registry_set ('interop_client', '1');
  GET_SERVERS ();

_end:;
  registry_set ('interop_client', '0');

}
;


create procedure INIT_RESULT_TABLE ()
{
   delete from RESULTS;
}
;

create procedure UPDATE_RESULT_TABLE
(in end_poin_url varchar, in op_name varchar, in ins_result varchar, in ins_error varchar, in request varchar,
 in responce varchar, in _name varchar, in _version varchar, in wsdl_url varchar, in end_poin_url varchar,
 in op_name varchar, in _service_name varchar)

{

   if (isinteger (responce))
     responce := '';

   if (isinteger (request))
     request := '';

   if (exists (select 1 from RESULTS where R_END_POINT = end_poin_url and R_SERVICE_NAME = op_name))
     {
       update RESULTS set R_SERVICE_RESULT = ins_result, R_SERVICE_ERROR = ins_error,
       	       R_SERVICE_REQ = request, R_SERVICE_RESP = responce, R_SERVER_NAME = _name,
       	       R_SERVER_VERSION = _version, R_SERVICE_WSDL = wsdl_url, R_SERVICE_GROUP =  _service_name
       	       where R_END_POINT = end_poin_url and R_SERVICE_NAME = op_name;
     }
   else
     {
       insert into RESULTS (R_END_POINT, R_SERVER_NAME, R_SERVER_VERSION, R_SERVICE_NAME, R_SERVICE_RESULT,
       		     R_SERVICE_ERROR, R_SERVICE_REQ, R_SERVICE_RESP, R_SERVICE_WSDL, R_SERVICE_GROUP)
       	    values  (end_poin_url, _name, _version, op_name, ins_result, ins_error,
       		     request, responce, wsdl_url, _service_name);
     }

   commit work;

-- GENERATE_OUTPUT_XML ();
}
;


create procedure test_all_results (in _test_type varchar, in int_value any, in res_int_value any,
	in float_value any, in res_float_value any, in string_value1 any, in res_string_value1 any,
	in string_value2 any, in res_string_value2 any)
{
    if (int_if (int_value, res_int_value))
       return int_failed_text (_test_type, int_value, res_int_value);

    if (float_if (float_value, res_float_value))
       return float_failed_text (_test_type, float_value, res_float_value);

    if (string_if (res_string_value1, string_value1))
       return string_failed_text (_test_type, string_value1, res_string_value1);

    if (string_if (res_string_value2, string_value2))
       return string_failed_text (_test_type, string_value2, res_string_value2);

    return 'OK';
}
;


create procedure IS_IN_TEST_LIST (in _test_name varchar, in _grp_name varchar)
{
  declare temp varchar;

  if (_grp_name = 'Round 2 Base')
    {
      temp := get_keyword (_test_name, vector ('echoBase64', '', 'echoBoolean', '', 'echoDecimal', '',
			  'echoDate', '', 'echoFloat', '', 'echoFloatArray', '', 'echoHexBinary', '',
			  'echoInteger', '', 'echoIntegerArray', '', 'echoString', '', 'echoStringArray', '',
			  'echoStruct', '', 'echoStructArray', '', 'echoVoid', ''), 'NO');
      if (temp = 'NO')
	return 0;
    }

  if (_grp_name = 'Round 2 Group B')
    {
      temp := get_keyword (_test_name, vector ('echo2DStringArray', '', 'echoNestedArray', '',
			  'echoNestedStruct', '', 'echoSimpleTypesAsStruct', '',
			  'echoStructAsSimpleTypes', ''), 'NO');
      if (temp = 'NO')
	return 0;
    }

  if (_grp_name = 'Round 2 Group C')
    {
      temp := get_keyword (_test_name, vector ('echoVoid', ''), 'NO');

      if (temp = 'NO')
	return 0;
    }

  if (_grp_name = 'Round 4 XSD')
    {
      temp := get_keyword (_test_name, vector ('NoSuchMethod', ''), 'NO');

      if (temp = '')
	return 0;
    }

  return 1;
}
;

create procedure IS_IN_NEW_TEST_LIST (in _test_name varchar, in _grp_name varchar)
{
  declare temp varchar;

  if (_grp_name = 'Round 3 Group D DocLitParams')
    {
      temp := get_keyword (_test_name, vector ('echoString', '', 'echoStringArray', '',
			  'echoStruct', '', 'echoVoid', ''
			  ), 'NO');
      if (temp <> 'NO')
	return 1;
    }

  return 0;
}
;


create procedure GET_SERVERS ()
{
   declare _all integer;

   set isolation='committed';

   select count (*) into _all from SERVICES;
   if (_all = 0)
     FILL_SERVICE_LIST ();
   else
     _all := 0;

   for (select S_ID, S_NAME, S_DESCRIPTION, S_WSDL_URL from SERVICES) do
      {
	 declare all_servers any;
	 declare _service_id varchar;
	 declare len, idx integer;

         _service_id := replace (S_ID, '{' , '');
         _service_id := replace (_service_id, '}' , '');

	 all_servers := registrationAndNotificationService.Servers (_service_id);
	 all_servers := all_servers[2];
	 all_servers := xml_tree_doc (all_servers);

	 all_servers := xpath_eval ('/Envelope/Body/ServersResponse/Servers/*', all_servers, 0);

	 len := length (all_servers);
	 idx := 0;

   	 while (idx < len)
	   {
	      declare _wsdl, _name, _version, _end_point varchar;
	      declare _line any;

	      _line := xml_cut (all_servers[idx]);
	      _name := cast (xpath_eval ('/serverInfo/name', _line, 1) as varchar);
	      _version := cast (xpath_eval ('/serverInfo/version', _line, 1) as varchar);
	      _wsdl := cast (xpath_eval ('/serverInfo/wsdlURL', _line, 1) as varchar);
	      _end_point := cast (xpath_eval ('/serverInfo/endpointURL', _line, 1) as varchar);

	      _all := _all + 1;
	      TEST_SERVER (_wsdl, _name, _version, _end_point, S_NAME);
	      idx := idx + 1;
	   }
       }

  return _all;

}
;

create procedure TEST_SERVER (in wsdl_url varchar, in _name varchar, in _version varchar,
			      in end_poin_url varchar, in _service_name varchar)
{
   declare _hdr, _ret, s_mtd, meta any;
   declare is_literal integer;
   declare len, idx integer;
   declare module_name varchar;
   declare ins_result varchar;
   declare ins_error varchar;
   declare state, msg varchar;
   declare tns, c_type varchar;
   declare service_list any;
   declare all_types any;

   declare exit handler for SQLSTATE '*'
   {
      update SERVERS set R_SERVER_ERROR = concat (__SQL_STATE , ' : ' , __SQL_MESSAGE)
	where SV_NAME = _name and SV_GROUP_NAME = _service_name;
      return 1;
   };

   insert soft SERVERS (SV_NAME, SV_GROUP_NAME, SV_WSDL_URL, S_WEB_URL, R_SERVER_ERROR) values
			(_name, _service_name, wsdl_url, end_poin_url, '');

   commit work;

   s_mtd := SOAP_WSDL_IMPORT (wsdl_url, wire_dump=>1, drop_module=>1);

   whenever SQLSTATE '*' default;

   _ret := http_get (wsdl_url, _hdr);

-- string_to_file ('wsdl.xml', _ret, -2);

   _ret := xml_tree_doc (_ret);
   service_list := xpath_eval ('/definitions/binding/operation', _ret, 0);

   tns := xpath_eval ('/definitions/@targetNamespace', _ret, 1);
      if (tns is not null)
	{
	  tns := cast (tns as varchar);
	  tns := concat (tns, ':');
	}
      else
	 tns := '';

   all_types := xpath_eval ('/definitions/binding/operation/@name', _ret, 0);

   if (not isarray(service_list))
     service_list := vector ();


   declare literal_str varchar;
   literal_str := cast (xpath_eval ('/definitions/binding/operation/input/body/@use', _ret, 1) as varchar);

   is_literal := 0;
   if (literal_str = 'literal')
     is_literal := 1;

   idx := 0;
   len := length (service_list);
   module_name := cast (xpath_eval ('/definitions/service/@name', _ret, 1) as varchar);

   while (idx < len)
     {
	declare curent_result varchar;
	declare request, responce varchar;
	declare op_name varchar;
	declare _line any;
	declare s_type varchar;

	request := '';
	responce := '';
        _line := service_list[idx];

	op_name := cast (xpath_eval ('@name', _line, 1) as varchar);
	s_type := concat (tns, all_types[idx]);

	request := '';
	responce:= '';

   declare exit handler for SQLSTATE '*'
   {
	UPDATE_RESULT_TABLE (end_poin_url, op_name, 'Failed TEST_SERVICE',
			     concat (__SQL_STATE , ' : ' , __SQL_MESSAGE), request, responce, _name,
			     _version, wsdl_url, end_poin_url, op_name, _service_name);

	goto next;
   };

        if (IS_IN_NEW_TEST_LIST (op_name, _service_name))
          {
             curent_result := NEW_TEST_SERVICE (module_name, op_name, wsdl_url, request, responce);
          }
        else if (IS_IN_TEST_LIST (op_name, _service_name))
	  {
	     curent_result := TEST_SERVICE (module_name, op_name, s_type, request, responce,
					    wsdl_url, is_literal, _ret);
	  }
	else
	  goto next;

	whenever SQLSTATE '*' default;

--	dbg_obj_print ('curent_result = ', curent_result);

        if (curent_result = 'OK')
	  {
	    ins_result := 'Passed';
	    ins_error  := '';
	  }
	else
	  {
	    ins_result := 'Failed';
	    ins_error  := curent_result;
	  }

	UPDATE_RESULT_TABLE (end_poin_url, op_name, ins_result, ins_error, request, responce, _name,
			     _version, wsdl_url, end_poin_url, op_name, _service_name);

next:

	idx := idx + 1;
     }

  return 0;
}
;


create procedure EXEC_STMT (in stmt_text varchar, in mode integer)
{
   declare state, msg varchar;
   declare meta, res any;

   if (mode)
     return execstr (stmt_text);

   msg := '';

   exec (stmt_text, state, msg, vector (), 100, meta, res);

   if (msg = '')
     return vector (1, res);
   else
     return vector (0, concat (msg, ':', state));
}
;


create procedure GET_REQ_RESP (inout _all any, inout request varchar, inout responce varchar)
{
        _all := _all[1];
        request := _all[0];
        request := _all[0];
        request := request[0];
        responce := request[2];
        request := request[1];
}
;

create procedure GET_REQ_RESP_2 (inout _all any, inout request varchar, inout responce varchar, inout ret any)
{
	request := _all[1];
        responce := _all[2];
	ret := xml_tree_doc (responce);
}
;

create procedure INTEROP_GET_RESULT (in responce varchar, in _type varchar)
{
  declare _xml any;
  declare in_value, temp any;
  declare ses any;

--dbg_obj_print ('In INTEROP_GET_RESULT');
  _xml := xml_tree_doc (responce);
  in_value := xpath_eval ('/Envelope/Body/*', _xml, 1);
  ses := string_output ();
  http_value (in_value, 0, ses);
  ses :=  string_output_string (ses);
  temp := xml_tree (ses);

  return soap_box_xml_entity_validating (temp, _type);
}
;


create procedure INTEROP_XML_RESULT (in responce varchar)
{
  declare _xml any;
  declare in_value any;
  declare ses any;

  _xml := xml_tree_doc (xml_expand_refs (xml_tree(responce)));

  in_value := xpath_eval ('/Envelope/Body/*', _xml, 1);
  ses := string_output ();
  http_value (in_value, 0, ses);
  ses :=  string_output_string (ses);

  if (in_value is NULL)
    return NULL;

  return xml_cut (in_value);
}
;


create procedure int_failed_text (in test_name varchar, in val1 any, in val2 any)
{
  if (val1 is null)
    val1 := 'Null';

  if (val2 is null)
    val2 := 'Null';

  if (not isstring (val1))
    val1 := cast (val1 as varchar);

  if (not isstring (val2))
    val2 := cast (val2 as varchar);

  return concat ('Failed: ', test_name, ' integer value [', val1, '] <> [', val2, ']');
}
;


create procedure float_failed_text (in test_name varchar, in val1 any, in val2 any)
{
  if (val1 is null)
    val1 := 'Null';

  if (val2 is null)
    val2 := 'Null';

  if (not isstring (val1))
    val1 := cast (val1 as varchar);

  if (not isstring (val2))
    val2 := cast (val2 as varchar);

  return concat ('Failed: ', test_name, ' float value [', val1, '] <> [', val2, ']');
}
;

create procedure string_failed_text (in test_name varchar, in val1 any, in val2 any)
{
  if (val1 is null)
    val1 := 'Null';

  if (val2 is null)
    val2 := 'Null';

  if (not isstring (val1))
    val1 := cast (val1 as varchar);

  if (not isstring (val2))
    val2 := cast (val2 as varchar);

  return concat ('Failed: ', test_name, ' string value [', val1, '] <> [', val2, ']');
}
;
create procedure int_if (in val1 any, in val2 any)
{
  if (val1 is null)
    return 1;

  if (val2 is null)
    return 1;

  if (not isinteger (val1))
    val1 := cast (val1 as integer);

  if (not isinteger (val2))
    val2 := cast (val2 as integer);

  if (val1 = val2)
    return 0;

  return 1;
}
;


create procedure float_if (in val1 any, in val2 any)
{
  if (val1 is null)
    return 1;

  if (val2 is null)
    return 1;

  if (not isfloat (val1))
    val1 := cast (cast (val1 as varchar) as float);

  if (not isfloat (val2))
    val2 := cast (cast (val2 as varchar) as float);

  val1 := (100 * cast (val1 as integer)) / 100;
  val2 := (100 * cast (val2 as integer)) / 100;

  if (val1 = val2)
    return 0;

  return 1;
}
;


create procedure string_if (in val1 any, in val2 any)
{
  if (val1 is null)
    return 1;

  if (val2 is null)
    return 1;

  if (not isstring(val1))
    val1 := cast (val1 as varchar);

  if (not isstring (val2))
    val2 := cast (val2 as varchar);

  val1 := trim_all (val1);
  val2 := trim_all (val2);

  if (val1 = val2)
    return 0;

  return 1;
}
;

create procedure remove_ns (in _element varchar)
{
  declare pos integer;

  while (1)
    {
       pos := strchr (_element, ':');

       if (pos is null)
	 return _element;

       _element := subseq (_element, pos + 1);
    }

}
;

create procedure trim_all (in in_string varchar)
{
  in_string := replace (in_string, '\r', '');
  in_string := replace (in_string, '\n', '');
  in_string := replace (in_string, '\t', '');
  return trim (in_string);
}
;


create procedure make_integer_array (in _begin integer, in _end integer)
{
   declare ret any;

   ret := '';

   while (_begin <= _end)
     {
        if (_begin = _end)
           ret := concat (ret, cast (_begin as varchar));
        else
           ret := concat (ret, cast (_begin as varchar), ',');
        _begin := _begin + 1;
     }

   return ret;
}
;

create procedure NEW_TEST_SERVICE (in module_name varchar, in op_name varchar, in wsdl_url varchar,
 inout request any, inout responce any)
{
  declare stmt any;
  declare exit handler for sqlstate '*'
  {
    return __SQL_STATE || ':' || __SQL_MESSAGE;
  };
  WSDL_IMPORT_UDT (wsdl_url, null, 1);
  stmt := 'create procedure tmp_newtest_proc (in pars any, inout request any, inout response any) {
     declare s ' || module_name || ';
     declare ret any;
     s := new ' || module_name || ' ();
     s.debug := 1;
     s.' || op_name || case op_name when 'echoVoid' then '();' else ' (pars, ret);' end || '
     request := s.request;
     response := s.response;
     return ret;
  }';
  exec (stmt, null, null);

  --dbg_obj_print (stmt);

  if (op_name = 'echoString')
    {
      declare a, b nvarchar;
      a := N'This is a test';
      b := tmp_newtest_proc (a, request, responce);
      if (a = b)
        return 'OK';
    }
  else if (op_name = 'echoVoid')
    {
      tmp_newtest_proc (null, request, responce);
      return 'OK';
    }
  else if (op_name = 'echoStringArray')
    {
      declare a, b any;
      a := vector (N'This',N'is',N'a',N'test');
      b := tmp_newtest_proc (a, request, responce);
       if (a[0]=b[0] and a[1]=b[1] and a[2]=b[2] and a[3]=b[3])
         return 'OK';
    }
  else if (op_name = 'echoStruct')
    {
      declare a, b any;
      a := soap_box_structure ('varString',N'String','varInt',256,'varFloat',3.14);
      b := tmp_newtest_proc (a, request, responce);
      if (
            get_keyword ('varString',a) = get_keyword ('varString', b) and
            get_keyword ('varInt',a) = get_keyword ('varInt', b) and
            get_keyword ('varFloat',a) = get_keyword ('varFloat', b)
          )
        return 'OK';
    }

  return 'Failed';
}
;
create procedure TEST_SERVICE (in module_name varchar, in test_type varchar, in parameters varchar,
			       inout request varchar, inout responce varchar, in wsdl_url varchar,
			       in is_literal integer, in _wsdl varchar)
{
   declare int_value, float_value, string_value1, string_value2 varchar;
   declare res_int_value, res_float_value, res_string_value1, res_string_value2 varchar;
   declare stmt, res, temp, ret_sch, ret_name, parameters_type varchar;
   declare idx, len integer;
   declare test_vec any;

   int_value := '975';
   float_value := '3.14';
   string_value1 := 'Test string 1';
   string_value2 := 'Test string 2';
   test_vec := vector ('This', 'is', 'a', 'test', '.');

-- dbg_obj_print ('test_type = ', test_type);
-- if (test_type <> 'echoStringArray') test_type := concat (test_type, '!!!');

   if (test_type = 'echoDocument')
     {
	stmt := concat ('select ', module_name, '.echoDocument (vector (composite (), vector (''ID'',''',
			int_value, '''), ''', string_value1, '''))');

	res := EXEC_STMT (stmt, 0);
	if (res[0] = 0) return res[1];
	GET_REQ_RESP (res, request, responce);

        res := soap_box_xml_entity_validating (res[0][0][0], 'http://soapinterop.org/xsd:Document');

	res_string_value1 := cast (res[2] as varchar);
	res_int_value := cast (res[1][1] as integer);

	return test_all_results (test_type, int_value, res_int_value, float_value, float_value,
				 string_value1, res_string_value1, string_value2, string_value2);

     }
   else if (test_type = 'echoEmployee')
     {
	declare _name, _salary, _id varchar;
	declare _res_name, _res_salary, _res_id varchar;

	_name := 'Test Name';
	_salary := '3500';
	_id := '3579';

	stmt := concat ('select ', module_name, '.echoEmployee (soap_box_structure (''person'', soap_box_structure (''Name'', ''', _name, ''',''Male'', soap_boolean(1)),''salary'',cast (', _salary, ' as double precision),''ID'',', _id, '))');
	res := EXEC_STMT (stmt, 0);
	if (res[0] = 0) return res[1];
	GET_REQ_RESP (res, request, responce);

        res := INTEROP_GET_RESULT (responce, 'http://soapinterop.org/employee:Employee');

--	dbg_obj_print ('res = ', res);

        _res_salary := res[5];
        _res_id := res[7];

        if (length (res[3]) > 1)
	  _res_name := res[3][3];
	else
	  _res_name := res[3];

	if (_res_name is NULL)
	  _res_name := '';

        if (_res_name <> _name)
	  return concat ('Error echoEmployee name [', _res_name, '] <> [', _name, ']');

        if (cast (_res_salary as float) <> cast (_salary as float))
	  return concat ('Error echoEmployee _salary [', _res_salary, '] <> [', _salary, ']');

        if (cast (_res_id as float) <> cast (_id as float))
	  return concat ('Error echoEmployee ID [', _res_id, '] <> [', _id, ']');

	return 'OK';
     }
   else if (test_type = 'echoPerson')
     {
	stmt := concat ('select ', module_name, '.echoPerson (vector (composite (), vector (''Name'',''',
			 string_value1, ''',''Male'', soap_boolean(1)), ''Age'', cast (', int_value,
			' as double precision), ''ID'', cast (', float_value, ' as float)))');

	res := EXEC_STMT (stmt, 0);
	if (res[0] = 0) return res[1];
	GET_REQ_RESP (res, request, responce);

        res := INTEROP_GET_RESULT (responce, 'http://soapinterop.org/xsd:Person');

	return test_all_results (test_type, int_value, res[3], float_value, res[5],
				 string_value1, res[1][1], string_value2, string_value2);
     }
   else if (test_type = 'echoVoid')
     {
	parameters_type := cast (xpath_eval ('//message[@name="echoVoidResponse"]/part/@name', _wsdl, 1) as varchar);

	if (is_literal and parameters_type = 'parameters')
	  stmt := concat ('select ', module_name, '.echoVoid (vector ())');
	else
	  stmt := concat ('select ', module_name, '.echoVoid ()');

	res := EXEC_STMT (stmt, 0);
	if (res[0] = 0) return res[1];
	GET_REQ_RESP (res, request, responce);
	res := INTEROP_XML_RESULT (responce);

        if (res is NULL) return 'OK';

	temp := trim_all (cast (xpath_eval ('//echoVoidResponse', res, 1) as varchar));

        if (trim (temp) <> '') return 'Failed echoVoid';

	return 'OK';
     }
   else if (test_type = 'echoString')
     {
	parameters_type := cast (xpath_eval ('//message[@name="echoStringResponse"]/part/@name', _wsdl, 1) as varchar);
	if (is_literal and parameters_type = 'parameters')
	  stmt := concat ('select DB.DBA.', module_name, '.echoString(vector (''', string_value1, '''))');
	else
	  stmt := concat ('select DB.DBA.', module_name, '.echoString(''', string_value1, ''')');

	res := EXEC_STMT (stmt, 0);
	if (res[0] = 0)
	  return res[1];

	GET_REQ_RESP (res, request, responce);
        res := INTEROP_XML_RESULT (responce);

	if (is_literal)
	  ret_name := cast (xpath_eval ('//element[@name="echoStringResponse"]/complexType/sequence/element/@name', _wsdl, 1) as varchar);
	else
	  ret_name := cast (xpath_eval ('//message[@name="echoStringOutput"]/part/@name', _wsdl, 1) as varchar);

	if (parameters_type = 'parameters')
	  ret_sch := concat ('/echoStringResponse/', ret_name);
	else
	  ret_sch := concat ('/', remove_ns (cast (xpath_eval ('//message[@name="echoStringResponse"]/part/@element', _wsdl, 1) as varchar)));

	res_string_value1 := xpath_eval (ret_sch, res, 1);

	if (string_if (res_string_value1, string_value1))
	  return string_failed_text ('echoString', string_value1, res_string_value1);

	return 'OK';
     }
   else if (test_type = 'echoStruct')
     {
	parameters_type := cast (xpath_eval ('//message[@name="echoStructResponse"]/part/@name', _wsdl, 1) as varchar);

	if (is_literal and parameters_type = 'parameters')
	  stmt := concat ('select ', module_name, '.echoStruct (vector (soap_box_structure (''varString'', ''',
			   string_value1, ''', ''varInt'', ', cast (int_value as varchar),
			   ',''varFloat'', cast(', cast (float_value as varchar), ' as float))))');
	else
	  stmt := concat ('select ', module_name, '.echoStruct (soap_box_structure (''varString'', ''',
			   string_value1, ''', ''varInt'', ', cast (int_value as varchar),
			   ',''varFloat'', cast(', cast (float_value as varchar), ' as float)))');

	res := EXEC_STMT (stmt, 0);
	if (res[0] = 0) return res[1];
	GET_REQ_RESP (res, request, responce);
        res := INTEROP_XML_RESULT (responce);

	res_string_value1 := xpath_eval ('//varString', res, 1);
	res_int_value := xpath_eval ('//varInt', res, 1);
	res_float_value := xpath_eval ('//varFloat', res, 1);

	return test_all_results (test_type, int_value, res_int_value, float_value, res_float_value,
				 string_value1, res_string_value1, string_value2, string_value2);
     }
   else if (test_type = 'echoStringArray')
     {
	parameters_type := cast (xpath_eval ('//message[@name="echoStringArray"]/part/@name', _wsdl, 1) as varchar);

	if (is_literal and parameters_type = 'parameters')
	  stmt := concat ('select ', module_name, '.echoStringArray (vector (vector (''', test_vec[0], ''',''',
			 test_vec [1], ''',''', test_vec [2] ,''',''', test_vec [3], ''',''', test_vec [4], ''')))');
	else
	  stmt := concat ('select ', module_name, '.echoStringArray (vector (''', test_vec[0], ''',''',
			 test_vec [1], ''',''', test_vec [2] ,''',''', test_vec [3], ''',''', test_vec [4], '''))');

	res := EXEC_STMT (stmt, 0);
	if (res[0] = 0) return res[1];
	GET_REQ_RESP (res, request, responce);
        res := INTEROP_XML_RESULT (responce);

        temp := xpath_eval ('//string', res, 0);
	if (length (temp) = 0) temp := xpath_eval ('//i', res, 0);
	if (length (temp) = 0) temp := xpath_eval ('//item', res, 0);
	if (length (temp) = 0) temp := xpath_eval ('//Item', res, 0);

	if (cast (xpath_eval ('//*', res, 1) as varchar) = 'Thisisatest.') return 'OK';

	res := temp;
	idx := 0;

	len := length (res);

	if (len <> 5) return concat ('Failed: echoStringArray responce string len = 0');

	while (idx < len)
	  {
	     temp := cast (res[idx] as varchar);

	     if (string_if (temp, test_vec [idx]))
	       return string_failed_text ('echoStringArray', temp, test_vec [idx]);

	     idx := idx + 1;
	  }

	return 'OK';
     }
   else if (test_type = 'echoStringFault')
     {
	res := soap_client (url=>wsdl_url, operation=>'echoStringFault', parameters=> vector('param', string_value1), style=>2);
	GET_REQ_RESP_2 (res, request, responce, temp);
        res_string_value1 := cast (xpath_eval ('//detail', temp, 1) as varchar);

        if (string_if (res_string_value1, string_value1))
	  return string_failed_text ('echoStringFault', string_value1, res_string_value1);

	return 'OK';
     }
   else if (test_type = 'echoEmptyFault')
     {
	string_value1 := '';

	res := soap_client (url=>wsdl_url, operation=>'echoEmptyFault', parameters=> vector(), style=>2);

	GET_REQ_RESP_2 (res, request, responce, temp);
        res_string_value1 := cast (xpath_eval ('//detail', temp, 1) as varchar);

        if (string_if (res_string_value1, string_value1))
	  return string_failed_text ('echoStringFault', string_value1, res_string_value1);

	return 'OK';
     }
   else if (test_type = 'echoIntArrayFault')
     {
	res := soap_client (url=>wsdl_url, operation=>'echoIntArrayFault', parameters=> vector('param', vector(1,4096,3)), style=>2);

	GET_REQ_RESP_2 (res, request, responce, temp);

        res := xpath_eval ('//item', temp, 0);

        if (int_if (res[0], 1))
	  return int_failed_text ('echoIntArrayFault', res[0], 1);
        if (int_if (res[1], 4096))
	  return int_failed_text ('echoIntArrayFault', res[1], 4096);
        if (int_if (res[2], 3))
	  return int_failed_text ('echoIntArrayFault', res[2], 3);

	return 'OK';
     }
   else if (test_type = 'echoMultipleFaults2')
     {
	res := soap_client (url=>wsdl_url, operation=>'echoMultipleFaults2', parameters=>vector('whichFault', 3, 'param1', 'string', 'param2', 3.1415, 'param3' , vector('', string_value1, '')), style=>2);

	GET_REQ_RESP_2 (res, request, responce, temp);
        res_string_value1 := cast (xpath_eval ('//item', temp, 2) as varchar);

	if (string_if (res_string_value1, string_value1))
	  return string_failed_text ('echoMultipleFaults2', string_value1, res_string_value1);

	return 'OK';
     }
   else if (test_type = 'echoStructAsSimpleTypes')
     {
	stmt := concat ('select ', module_name, '.echoStructAsSimpleTypes (soap_box_structure (''varString'', ''',
	        string_value1, ''', ''varInt'', ', int_value,',''varFloat'', cast(', float_value ,' as float)))');

	res := EXEC_STMT (stmt, 0);
	if (res[0] = 0) return res[1];
	GET_REQ_RESP (res, request, responce);
        res := INTEROP_XML_RESULT (responce);

	res_int_value := cast (xpath_eval ('//outputInteger', res, 1) as varchar);
	res_float_value := cast (xpath_eval ('//outputFloat', res, 1) as varchar);
	res_string_value1 := cast (xpath_eval ('//outputString', res, 1) as varchar);

	return test_all_results (test_type, int_value, res_int_value, float_value, res_float_value,
				 string_value1, res_string_value1, string_value2, string_value2);
     }
   else if (test_type = 'echoSimpleTypesAsStruct')
     {
	stmt := concat ('select ', module_name, '.echoSimpleTypesAsStruct (''', string_value1, ''', ', int_value, ', cast(', float_value, ' as float))');

	res := EXEC_STMT (stmt, 0);
	if (res[0] = 0) return res[1];
	GET_REQ_RESP (res, request, responce);
        res := INTEROP_XML_RESULT (responce);

	res_int_value := cast (xpath_eval ('//varInt', res, 1) as varchar);
	res_float_value := cast (xpath_eval ('//varFloat', res, 1) as varchar);
	res_string_value1 := cast (xpath_eval ('//varString', res, 1) as varchar);

	return test_all_results (test_type, int_value, res_int_value, float_value, res_float_value,
				 string_value1, res_string_value1, string_value2, string_value2);
     }
   else if (test_type = 'echo2DStringArray')
     {
	declare val, res_val varchar;

	stmt := concat ('select ', module_name, '.echo2DStringArray (vector (vector (''result0'', ''result1''), vector (''result2'',''result3''), vector (''result4'',''result5'')))');

	res := EXEC_STMT (stmt, 0);

	GET_REQ_RESP (res, request, responce);
	if (res[0] = 0) return res[1];
        res := INTEROP_XML_RESULT (responce);
	res := xpath_eval ('/echo2DStringArrayResponse/result/item', res, 0);

	idx := 0;
	while (idx < length (res))
	  {
	     res_val := cast (res[idx] as varchar);
	     val := concat ('result', cast (idx as varchar));

	     if (res_val <> val)
		return concat ('Failed echo2DStringArray values [', res_val, '] <> [', val, ']');

	     idx := idx + 1;
	  }

	return 'OK';
     }
   else if (test_type = 'echoNestedStruct')
     {
	declare int_value2 varchar;
	int_value2 := '537';

	stmt := concat ('select ', module_name, '.echoNestedStruct (soap_box_structure (''varString'',''', string_value1, ''',''varInt'', ', int_value, ',''varFloat'', cast(', float_value, ' as float), ''varStruct'',soap_box_structure (''varString'', ''', string_value2, ''', ''varInt'', 456, ''varFloat'', cast(3.14 as float))))');

	res := EXEC_STMT (stmt, 0);
	if (res[0] = 0) return res[1];
	GET_REQ_RESP (res, request, responce);
        res := INTEROP_XML_RESULT (responce);

	res_string_value1 := cast (xpath_eval ('//varString', res, 1) as varchar);
	res_string_value2 := cast (xpath_eval ('//varStruct/varString', res, 1) as varchar);
	if (string_if (res_string_value2, string_value2))
	  return string_failed_text ('echoNestedStruct', string_value2, res_string_value2);

	return 'OK';
     }
   else if (test_type = 'echoNestedArray')
     {
	stmt := concat ('select ', module_name, '.echoNestedArray (soap_box_structure (''varString'', ''', string_value1, ''', ''varInt'', ', int_value, ', ''varFloat'', cast(', float_value, ' as float), ''varArray'', vector (''OpenLink'', ''Virtuoso'', ''client'')))');

	res := EXEC_STMT (stmt, 0);
	if (res[0] = 0) return res[1];
	GET_REQ_RESP (res, request, responce);
        res := INTEROP_XML_RESULT (responce);

	res_int_value := cast (xpath_eval ('//varInt', res, 1) as varchar);
	res_float_value := cast (xpath_eval ('//varFloat', res, 1) as varchar);
	res_string_value1 := cast (xpath_eval ('//varString', res, 1) as varchar);

	if (cast (xpath_eval ('/echoNestedArrayResponse/result/varArray/item', res, 1) as varchar) <> 'OpenLink')
	  return 'Failed echoNestedArray varArray';
	if (cast (xpath_eval ('/echoNestedArrayResponse/result/varArray/item', res, 2) as varchar) <> 'Virtuoso')
	  return 'Failed echoNestedArray varArray';
	if (cast (xpath_eval ('/echoNestedArrayResponse/result/varArray/item', res, 3) as varchar) <> 'client')
	  return 'Failed echoNestedArray varArray';
	if (cast (xpath_eval ('/echoNestedArrayResponse/result/varArray/item', res, 4) as varchar) <> NULL)
	  return 'Failed echoNestedArray varArray';

	return test_all_results (test_type, int_value, res_int_value, float_value, res_float_value,
				 string_value1, res_string_value1, string_value2, string_value2);
     }
   else if (test_type = 'echoBoolean')
     {
	if (is_literal)
	  stmt := concat ('select ', module_name, '.echoBoolean(vector (soap_boolean (1)))');
	else
	  stmt := concat ('select ', module_name, '.echoBoolean(soap_boolean (1))');

	res := EXEC_STMT (stmt, 0);
	if (res[0] = 0) return res[1];
	GET_REQ_RESP (res, request, responce);
        res := INTEROP_XML_RESULT (responce);
	res := trim_all (cast (xpath_eval ('//*', res, 1) as varchar));

	if (res = '1') res :=  'true';
	if (res <> 'true') return 'Failed echoBoolean true';

	if (is_literal)
	  stmt := concat ('select ', module_name, '.echoBoolean(vector (soap_boolean (0)))');
	else
	  stmt := concat ('select ', module_name, '.echoBoolean(soap_boolean (0))');

	res := EXEC_STMT (stmt, 0);
	if (res[0] = 0) return res[1];
	GET_REQ_RESP (res, request, responce);
        res := INTEROP_XML_RESULT (responce);
	res := trim_all (cast (xpath_eval ('//*', res, 1) as varchar));

	if (res = '0') res :=  'false';
	if (res <> 'false') return 'Failed echoBoolean false';

	return 'OK';
     }
   else if (test_type = 'echoDecimal')
     {
	if (is_literal)
	  stmt := concat ('select ', module_name, '.echoDecimal(vector (cast (', float_value, ' as decimal)))');
	else
	  stmt := concat ('select ', module_name, '.echoDecimal(cast (', float_value, ' as decimal))');

	res := EXEC_STMT (stmt, 0);
	if (res[0] = 0) return res[1];
	GET_REQ_RESP (res, request, responce);
        res := INTEROP_XML_RESULT (responce);
	res_float_value := cast (xpath_eval ('//*', res, 1) as varchar);

	if (float_if (float_value, res_float_value))
           return float_failed_text ('echoDecimal', float_value, res_float_value);

	return 'OK';
     }
   else if (test_type = 'echoHexBinary')
     {
	if (is_literal)
	  stmt := concat ('select ', module_name, '.echoHexBinary(vector (''A9FD64E1''))');
	else
	  stmt := concat ('select ', module_name, '.echoHexBinary(''A9FD64E1'')');

	res := EXEC_STMT (stmt, 0);
	if (res[0] = 0) return res[1];
	GET_REQ_RESP (res, request, responce);
        res := INTEROP_XML_RESULT (responce);

	temp := ucase (cast (xpath_eval ('//*', res, 1) as varchar));

	if (string_if (temp, 'A9FD64E1'))
	  return string_failed_text ('echoHexBinary', temp, 'A9FD64E1');

	return 'OK';
     }
   else if (test_type = 'echoDate')
     {
	declare _now varchar;
	declare _now_t datetime;

	_now_t := stringdate (substring (datestring (now()), 1,  19));
	_now := datestring (_now_t);

	if (is_literal)
	  stmt := concat ('select ', module_name, '.echoDate(vector (stringdate (''', _now, ''')))');
	else
	  stmt := concat ('select ', module_name, '.echoDate(stringdate (''', _now, '''))');

	res := EXEC_STMT (stmt, 0);
	if (res[0] = 0) return res[1];
	GET_REQ_RESP (res, request, responce);
        res := INTEROP_XML_RESULT (responce);

	temp := cast (xpath_eval ('//*', res, 1) as varchar);
	temp := soap_box_xml_entity_validating( xml_tree ('<a>'||temp||'</a>'), 'dateTime') ;

	if (_now_t = temp)
	  return 'OK';

	return string_failed_text ('echoDate', soap_print_box (temp, '', 1), soap_print_box (_now, '', 1));
     }
   else if (test_type = 'echoBase64')
     {
	if (is_literal)
	  stmt := concat ('select ', module_name, '.echoBase64(vector (''dGhpcyBpcyBhIHRlc3Q=''))');
	else
	  stmt := concat ('select ', module_name, '.echoBase64(''dGhpcyBpcyBhIHRlc3Q='')');

	res := EXEC_STMT (stmt, 0);
	if (res[0] = 0) return res[1];
	GET_REQ_RESP (res, request, responce);
        res := INTEROP_XML_RESULT (responce);

	temp := cast (xpath_eval ('//*', res, 1) as varchar);

	if (string_if (decode_base64 (temp), decode_base64 ('dGhpcyBpcyBhIHRlc3Q=')))
	  return string_failed_text ('echoBase64', temp, 'dGhpcyBpcyBhIHRlc3Q=');

	return 'OK';
     }
   else if (test_type = 'echoFloatArray')
     {
	stmt := concat ('select ', module_name, '.echoFloatArray (vector (cast(''', float_value, ''' as float)))');

	res := EXEC_STMT (stmt, 0);
	if (res[0] = 0) return res[1];
	GET_REQ_RESP (res, request, responce);
        res := INTEROP_XML_RESULT (responce);

	res_float_value := cast (xpath_eval ('//*', res, 1) as varchar);

	if (float_if (float_value, res_float_value))
	  return float_failed_text ('echoFloatArray', float_value, res_float_value);

	return 'OK';
     }
   else if (test_type = 'echoFloat')
     {
	if (is_literal)
	  stmt := concat ('select ', module_name, '.echoFloat(vector (cast (''', float_value, ''' as float)))');
	else
	  stmt := concat ('select ', module_name, '.echoFloat(cast(''', float_value, ''' as float))');

	res := EXEC_STMT (stmt, 0);
	if (res[0] = 0) return res[1];
	GET_REQ_RESP (res, request, responce);
        res := INTEROP_XML_RESULT (responce);

	res_float_value := cast (xpath_eval ('//*', res, 1) as varchar);

	if (float_if (float_value, res_float_value))
	  return float_failed_text ('echoFloat', float_value, res_float_value);

	return 'OK';
     }
   else if (test_type = 'echoInteger')
     {
	if (is_literal)
	  stmt := concat ('select ', module_name, '.echoInteger(vector (', int_value, '))');
	else
	  stmt := concat ('select ', module_name, '.echoInteger(', int_value, ')');

	res := EXEC_STMT (stmt, 0);
	if (res[0] = 0) return res[1];
	GET_REQ_RESP (res, request, responce);
        res := INTEROP_XML_RESULT (responce);

	res_int_value := cast (xpath_eval ('//*', res, 1) as varchar);

        if (int_if (res_int_value, int_value))
	  return int_failed_text ('echoInteger', int_value, res_int_value);

	return 'OK';
     }
   else if (test_type = 'echoIntegerArray')
     {
	len := 5;
	temp := make_integer_array (0, len);

	stmt := concat ('select ', module_name, '.echoIntegerArray (vector (', temp, '))');
	res := EXEC_STMT (stmt, 0);
	if (res[0] = 0) return res[1];
	GET_REQ_RESP (res, request, responce);
        res := INTEROP_XML_RESULT (responce);

	temp := xpath_eval ('//*', res, 1);
	temp := cast (temp as varchar);
	temp := trim_all (temp);

	while (strchr (temp, ' ')) { temp := replace (temp, ' ', ''); }

	if (length (temp) <> 6)
	  return int_failed_text ('echoIntegerArray', length (temp), 6);

	idx := 0;
	while (idx <= len)
	  {
	     res_int_value := chr (temp [idx]);
	     if (int_if (res_int_value, idx))
	       return int_failed_text ('echoIntegerArray', idx + 1, res_int_value);
	     idx := idx + 1;
	  }

	return 'OK';
     }
   else if (test_type = 'echoStructArray')
     {
	stmt := concat ('select ', module_name, '.echoStructArray (vector (soap_box_structure (''varString'', ''', string_value1, ''', ''varInt'', ', int_value, ',''varFloat'', cast(', float_value, ' as float)),soap_box_structure (''varString'', ''', string_value2, ''', ''varInt'', ', int_value, ',''varFloat'', cast(', float_value, ' as float))))');

	res := EXEC_STMT (stmt, 0);
	if (res[0] = 0) return res[1];
	GET_REQ_RESP (res, request, responce);
        res := INTEROP_XML_RESULT (responce);

	res_string_value1 := cast (xpath_eval ('//varString', res, 1) as varchar);
	res_string_value2 := cast (xpath_eval ('//varString', res, 2) as varchar);
	res_int_value := cast (xpath_eval ('//varInt', res, 1) as varchar);
	res_float_value := cast (xpath_eval ('//varFloat', res, 1) as varchar);
	temp := cast (xpath_eval ('//varInt', res, 2) as varchar);

	return test_all_results (test_type, int_value, res_int_value, float_value, res_float_value,
				 string_value1, res_string_value1, string_value2, res_string_value2);
     }
   else if (test_type = 'echoAnyElement')
     {
	res := soap_client (url=>wsdl_url, operation=>'echoChoice',
	       parameters=>vector(vector('inputChoice', 'http://soapinterop.org/xsd:ChoiceComplexType'),
	       soap_box_structure ('name0', string_value1)), style=>7, target_namespace=>'http://soapinterop.org/');

	GET_REQ_RESP_2 (res, request, responce, temp);
        res_string_value1 := cast (xpath_eval ('//*', temp, 1) as varchar);
        if (string_if (res_string_value1, string_value1))
	  return string_failed_text ('echoAnyElement', string_value1, res_string_value1);

	return 'OK';
     }
   else if (test_type = 'echoChoice')
     {
	res := soap_client (url=>wsdl_url, operation=>'echoChoice',
	       parameters=>vector(vector('inputChoice', 'http://soapinterop.org/xsd:ChoiceComplexType'),
	       soap_box_structure ('name0',string_value1)),
	       style=>7, target_namespace=>'http://soapinterop.org/');

	GET_REQ_RESP_2 (res, request, responce, temp);
        res_string_value1 := cast (xpath_eval ('//*', temp, 1) as varchar);

        if (string_if (res_string_value1, string_value1))
	  return string_failed_text ('echoChoice', string_value1, res_string_value1);

	return 'OK';
     }
   else if (test_type = 'echoEnum')
     {
	string_value1 := 'BitTwo';

	res := soap_client (url=>wsdl_url, operation=>'echoEnum',
               parameters=>vector(vector('inputEnum', 'http://soapinterop.org/xsd:Enum'),
               vector (composite (), 'Enum', string_value1)),
               style=>7, target_namespace=>'http://soapinterop.org/');

	GET_REQ_RESP_2 (res, request, responce, temp);
        res_string_value1 := cast (xpath_eval ('//*', temp, 1) as varchar);

        if (string_if (res_string_value1, string_value1))
	  return string_failed_text ('echoEnum', string_value1, res_string_value1);

	return 'OK';
     }
   else if (test_type = 'echoAnyType')
     {
	res := soap_client (url=>wsdl_url, operation=>'echoAnyType',
	       parameters=>vector('inputAnyType', int_value),
	       style=>7, target_namespace=>'http://soapinterop.org/');

	GET_REQ_RESP_2 (res, request, responce, temp);
        res_int_value := cast (xpath_eval ('//*', temp, 1) as integer);

        if (int_if (res_int_value, int_value))
	  return int_failed_text ('echoAnyType', int_value, res_int_value);

	return 'OK';
     }
   else if (test_type = 'echoVoidSoapHeader')
     {
	res := soap_client (url=>wsdl_url, operation=>'echoVoidSoapHeader', parameters=>vector(),
	       headers=>vector(vector('echoMeStringRequest', 'http://soapinterop.org/:echoMeStringRequest', 1,
			'http://schemas.xmlsoap.org/soap/actor/next') ,  vector(string_value1)), style=>7,
	       target_namespace=>'http://soapinterop.org', soap_action=>'"http://soapinterop.org"');

	GET_REQ_RESP_2 (res, request, responce, temp);
        res_string_value1 := cast (xpath_eval ('//*', temp, 1) as varchar);

        if (string_if (res_string_value1, string_value1))
	  return string_failed_text ('echoVoidSoapHeader', string_value1, res_string_value1);

	return 'OK';
     }
   else if (test_type = 'echoComplexType')
     {
	stmt := concat ('select ', module_name, '.echoComplexType (vector (soap_box_structure (''varString'', ''',
		         string_value1, ''', ''varInt'', ', cast (int_value as varchar),
			 ',''varFloat'', cast(', cast (float_value as varchar), ' as float))))');

	res := EXEC_STMT (stmt, 0);
	if (res[0] = 0) return res[1];
	GET_REQ_RESP (res, request, responce);
        res := INTEROP_XML_RESULT (responce);

	res_string_value1 := xpath_eval ('//varString', res, 1);
	res_int_value := xpath_eval ('//varInt', res, 1);
	res_float_value := xpath_eval ('//varFloat', res, 1);

	return test_all_results (test_type, int_value, res_int_value, float_value, res_float_value,
				 string_value1, res_string_value1, string_value2, string_value2);
     }
   else if (test_type = 'echoComplexTypeAsSimpleTypes')
     {
	stmt := concat ('select ', module_name,
			 '.echoComplexTypeAsSimpleTypes (vector (soap_box_structure (''varString'', ''',
		         string_value1, ''', ''varInt'', ', cast (int_value as varchar),
			 ',''varFloat'', cast(', cast (float_value as varchar), ' as float))))');

	res := EXEC_STMT (stmt, 0);
	if (res[0] = 0) return res[1];
	GET_REQ_RESP (res, request, responce);
        res := INTEROP_XML_RESULT (responce);

	res_string_value1 := xpath_eval ('//outputString', res, 1);
	res_int_value := xpath_eval ('//outputInteger', res, 1);
	res_float_value := xpath_eval ('//outputFloat', res, 1);

	return test_all_results (test_type, int_value, res_int_value, float_value, res_float_value,
				 string_value1, res_string_value1, string_value2, string_value2);
     }
   else if (test_type = 'echoStringMultiOccurs')
     {
	stmt := concat ('select ', module_name, '.echoStringMultiOccurs (vector (vector (''', test_vec[0], ''',''',
			test_vec [1], ''',''', test_vec [2] ,''',''', test_vec [3], ''',''', test_vec [4], ''')))');

	res := EXEC_STMT (stmt, 0);
	if (res[0] = 0) return res[1];
	GET_REQ_RESP (res, request, responce);
        res := INTEROP_XML_RESULT (responce);

	res := xpath_eval ('//return', res, 0);

	len := length (res);
	idx := 0;

	if (len <> 5)
	  return concat ('Failed: echoStringMultiOccurs responce string len = 0');

	while (idx < len)
	  {
	     temp := cast (res[idx] as varchar);
	     if (string_if (temp, test_vec [idx]))
	       return string_failed_text ('echoStringMultiOccurs', temp, test_vec [idx]);
	     idx := idx + 1;
	  }

	return 'OK';
     }
   else if (test_type = 'echoSimpleTypesAsComplexType')
     {
	stmt := concat ('select ', module_name,
			 '.echoSimpleTypesAsComplexType (soap_box_structure (''inputString'', ''',
		         string_value1, ''', ''inputInteger'', ', cast (int_value as varchar),
			 ',''inputFloat'', cast(', cast (float_value as varchar), ' as float)))');

	res := EXEC_STMT (stmt, 0);
	if (res[0] = 0) return res[1];
	GET_REQ_RESP (res, request, responce);
        res := INTEROP_XML_RESULT (responce);

	res_string_value1 := xpath_eval ('//varString', res, 1);
	res_int_value := xpath_eval ('//varInt', res, 1);
	res_float_value := xpath_eval ('//varFloat', res, 1);

	return test_all_results (test_type, int_value, res_int_value, float_value, res_float_value,
				 string_value1, res_string_value1, string_value2, string_value2);
     }
   else if (test_type = 'echoNestedMultiOccurs')
     {
	stmt := concat ('select ', module_name,
			 '.echoNestedMultiOccurs (vector (soap_box_structure (''varString'', ''',
		         string_value1, ''', ''varInt'', ', cast (int_value as varchar),
			 ',''varFloat'', cast(', cast (float_value as varchar),
			 ' as float), ''varMultiOccurs'', vector (''', string_value2, '''))))');

	res := EXEC_STMT (stmt, 0);
	if (res[0] = 0) return res[1];
	GET_REQ_RESP (res, request, responce);
        res := INTEROP_XML_RESULT (responce);

	res_string_value1 := xpath_eval ('//varString', res, 1);
	res_string_value2 := xpath_eval ('//varMultiOccurs', res, 1);
	res_int_value := xpath_eval ('//varInt', res, 1);
	res_float_value := xpath_eval ('//varFloat', res, 1);

	return test_all_results (test_type, int_value, res_int_value, float_value, res_float_value,
				 string_value1, res_string_value1, string_value2, res_string_value2);
     }
   else if (test_type = 'echoNestedComplexType')
     {
	stmt := concat ('select ', module_name,
			 '.echoNestedComplexType (vector (soap_box_structure (''varString'', ''',
		         string_value1, ''', ''varInt'', ', cast (int_value as varchar),
			 ',''varFloat'', cast(', cast (float_value as varchar),
			 ' as float), ''varComplexType'', soap_box_structure (''varInt'',12356,''varString'',''',
			 string_value2, ''',''varFloat'', cast (98765 as float)))))');

	res := EXEC_STMT (stmt, 0);
	if (res[0] = 0) return res[1];
	GET_REQ_RESP (res, request, responce);
        res := INTEROP_XML_RESULT (responce);

	res_int_value := xpath_eval ('//varInt', res, 1);
	res_float_value := xpath_eval ('//varFloat', res, 1);
	res_string_value1 := xpath_eval ('//return/varString', res, 1);
	res_string_value2 := xpath_eval ('//varComplexType/varString', res, 1);

	return test_all_results (test_type, int_value, res_int_value, float_value, res_float_value,
				 string_value1, res_string_value1, string_value2, res_string_value2);
     }
   else if (test_type = 'echoIntegerMultiOccurs')
     {
	temp := make_integer_array (0, 5);
	stmt := concat ('select ', module_name, '. echoIntegerMultiOccurs (vector (vector (', temp, ')))');

	res := EXEC_STMT (stmt, 0);
	if (res[0] = 0) return res[1];
	GET_REQ_RESP (res, request, responce);
        res := INTEROP_XML_RESULT (responce);

	temp := xpath_eval ('//*', res, 1);
	temp := cast (temp as varchar);
	temp := trim_all (temp);

	while (strchr (temp, ' ')) { temp := replace (temp, ' ', ''); }

	if (length (temp) <> 6) return int_failed_text ('echoIntegerArray', length (temp), 6);

	idx := 0;
	while (idx <= len)
	  {
	     res_int_value := chr (temp [idx]);
	     if (int_if (res_int_value, idx))
	       return int_failed_text ('echoIntegerMultiOccurs', idx + 1, res_int_value);
	     idx := idx + 1;
	  }

	return 'OK';
     }
   else if (test_type = 'echoFloatMultiOccurs')
     {
	stmt := concat ('select ', module_name, '. echoFloatMultiOccurs (vector (vector ( cast (',
			float_value , ' as float))))');

	res := EXEC_STMT (stmt, 0);
	if (res[0] = 0) return res[1];
	GET_REQ_RESP (res, request, responce);
        res := INTEROP_XML_RESULT (responce);

	res_float_value := cast (xpath_eval ('//*', res, 1) as varchar);

	if (float_if (float_value, res_float_value))
	  return float_failed_text ('echoFloatMultiOccurs', float_value, res_float_value);

	return 'OK';
     }
   else if (test_type = 'echoComplexTypeMultiOccurs')
     {
	stmt := concat ('select ', module_name,
			 '.echoComplexTypeMultiOccurs (vector (vector (soap_box_structure (''varString'', ''',
		         string_value1, ''', ''varInt'', ', cast (int_value as varchar),
			 ',''varFloat'', cast(', cast (float_value as varchar), ' as float)))))');

	res := EXEC_STMT (stmt, 0);
	if (res[0] = 0) return res[1];
	GET_REQ_RESP (res, request, responce);
        res := INTEROP_XML_RESULT (responce);

	res_string_value1 := xpath_eval ('//varString', res, 1);
	res_int_value := xpath_eval ('//varInt', res, 1);
	res_float_value := xpath_eval ('//varFloat', res, 1);

	return test_all_results (test_type, int_value, res_int_value, float_value, res_float_value,
				 string_value1, res_string_value1, string_value2, string_value2);
     }
   else if (test_type = 'RetAny')
     {
	stmt := concat ('select ', module_name, '.RetAny (vector (vector (xml_tree_doc (''<RetAny>',
	string_value1, '</RetAny>''))))');

	res := EXEC_STMT (stmt, 0);
	if (res[0] = 0) return res[1];
	GET_REQ_RESP (res, request, responce);
        res := INTEROP_XML_RESULT (responce);

	res_string_value1 := xpath_eval ('//*', res, 1);

	if (string_if (res_string_value1, string_value1))
	  return string_failed_text ('RetAny', string_value1, res_string_value1);

	return 'OK';
     }
   else if (test_type = 'RetAnyType')
     {
	stmt := concat ('select ', module_name, '.RetAnyType (vector (''RetAnyType''))');

	res := EXEC_STMT (stmt, 0);
	if (res[0] = 0) return res[1];
	GET_REQ_RESP (res, request, responce);
        res := INTEROP_XML_RESULT (responce);

	res_string_value1 := xpath_eval ('//*', res, 1);

	if (string_if (res_string_value1, ''))
	  return string_failed_text ('RetAnyType', '', res_string_value1);

	return 'OK';
     }
   else if (test_type = 'echo2DStringMultiOccurs')
     {
	stmt := concat ('select ', module_name, '.echo2DStringMultiOccurs (vector ( vector (vector (''',
			string_value1,'''))))');

	res := EXEC_STMT (stmt, 0);
	if (res[0] = 0) return res[1];
	GET_REQ_RESP (res, request, responce);
        res := INTEROP_XML_RESULT (responce);

	res_string_value1 := xpath_eval ('//*', res, 1);

	if (string_if (res_string_value1, string_value1))
	  return string_failed_text ('echo2DStringMultiOccurs', string_value1, res_string_value1);

	return 'OK';
     }
   else if (test_type = 'echoDuration')
     {
	stmt := concat ('select ', module_name, '.echoDuration (''P1Y2M3DT10H30M'')');

	res := EXEC_STMT (stmt, 0);
	if (res[0] = 0) return res[1];
	GET_REQ_RESP (res, request, responce);
        res := INTEROP_XML_RESULT (responce);

	res_string_value1 := xpath_eval ('//*', res, 1);

	if (string_if (res_string_value1, 'P1Y2M3DT10H30M'))
	  return string_failed_text ('echoDuration', 'P1Y2M3DT10H30M', res_string_value1);

	return 'OK';
     }
   else if (test_type = 'echoMultipleFaults1')
     {
	stmt := concat ('select ', module_name, '.echoMultipleFaults1 (2 , ''', string_value1,
			''', vector(cast (', float_value, ' as float)))');

	res := EXEC_STMT (stmt, 0);
	if (res[0] = 0) return res[1];
	GET_REQ_RESP (res, request, responce);
        res := INTEROP_XML_RESULT (responce);

	res_string_value1 := xpath_eval ('//detail', res, 1);

	if (string_if (res_string_value1, string_value1))
	  return string_failed_text ('echoMultipleFaults1', string_value1, res_string_value1);

	return 'OK';
     }
   else if (test_type = 'echoMultipleFaults3')
     {
	stmt := concat ('select ', module_name, '.echoMultipleFaults3 (1 , ''', string_value1,
			''', ''', string_value2, ''')');

	res := EXEC_STMT (stmt, 0);
	if (res[0] = 0) return res[1];
	GET_REQ_RESP (res, request, responce);
        res := INTEROP_XML_RESULT (responce);

	res_string_value1 := xpath_eval ('//detail', res, 1);

	if (string_if (res_string_value1, string_value1))
	  return string_failed_text ('echoMultipleFaults3', string_value1, res_string_value1);

	return 'OK';
     }
   else if (test_type = 'echoMultipleFaults4')
     {
	stmt := concat ('select ', module_name, '.echoMultipleFaults4 (2 , 234, vector (composite(), '''', 2))');

	res := EXEC_STMT (stmt, 0);
	if (res[0] = 0) return res[1];
	GET_REQ_RESP (res, request, responce);
        res := INTEROP_XML_RESULT (responce);

	res_int_value := xpath_eval ('//detail', res, 1);

	if (int_if (res_int_value, 2))

	  return string_failed_text ('echoMultipleFaults1', res_int_value, 2);
	return 'OK';
     }
   else if (test_type = 'echoLinkedList')
     {
	stmt := concat ('select ', module_name, '.echoLinkedList (soap_box_structure (''varString'', ''', string_value1, ''', ''varInt'', ', int_value, ',''varFloat'', cast(', float_value, ' as float)))');

	res := EXEC_STMT (stmt, 0);
	if (res[0] = 0) return res[1];
	GET_REQ_RESP (res, request, responce);
        res := INTEROP_XML_RESULT (responce);

	res_string_value1 := cast (xpath_eval ('//varString', res, 1) as varchar);
	res_int_value := cast (xpath_eval ('//varInt', res, 1) as varchar);
	temp := cast (xpath_eval ('//varInt', res, 2) as varchar);
--	dbg_obj_print ('res_int_value = ', res_int_value);

	return test_all_results (test_type, int_value, res_int_value, float_value, float_value,
				 string_value1, res_string_value1, string_value2, string_value2);
     }

    return concat ('Internal client error Missing Test ', test_type);
}
;
