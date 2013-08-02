--  
--  $Id$
--  
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--  
--  Copyright (C) 1998-2013 OpenLink Software
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
create procedure "Getconst_pi" () returns double precision
    __soap_type 'http://www.w3.org/2001/XMLSchema:double'
{
  declare ret double precision;
  ret := java_get_property ('java_server', NULL, 'const_pi', 'D');
  java_vm_detach();
  return ret;
};

create procedure "Getlong_val" () returns integer
    __soap_type 'http://www.w3.org/2001/XMLSchema:long'
{
  declare ret integer;
  ret := java_get_property ( 'java_server', NULL, 'long_val', 'J');
  java_vm_detach();
  return ret;
};

create procedure "Setlong_val" (in val integer __soap_type 'http://www.w3.org/2001/XMLSchema:long')
    __soap_type '__VOID__'
{
      java_set_property ( 'java_server', NULL, 'long_val', 'J', val);
      java_vm_detach();
};

create procedure "echoString" (in p1 nvarchar __soap_type 'http://www.w3.org/2001/XMLSchema:string' )
    returns nvarchar __soap_type 'http://www.w3.org/2001/XMLSchema:string'
{
  declare ret nvarchar;
  ret := java_call_method ( 'java_server', NULL, 'echoString', 'Ljava/lang/String;' ,
		       vector ('Ljava/lang/String;', p1));
  java_vm_detach();
  return ret;
};

create procedure "echoInt" (in p1 integer __soap_type 'http://www.w3.org/2001/XMLSchema:int')
       returns integer __soap_type 'http://www.w3.org/2001/XMLSchema:int'
{
  declare ret integer;
  ret := java_call_method ( 'java_server', NULL, 'echoInt', 'I' , vector ('I', p1));
  java_vm_detach();
  return ret;
};

create procedure java_properties ()
{
  declare java_util_properties any;
  declare object any;
  declare java_util_enumeration any;
  declare prop_name, prop_value varchar;
  declare res any;
  java_util_properties := java_call_method ('java.lang.System', NULL, 'getProperties', 'Ljava/util/Properties;');
  java_util_enumeration := java_call_method ('java.util.Properties', java_util_properties, 'propertyNames', 'Ljava/util/Enumeration;');
  whenever sqlstate '*' goto done;
  res := vector ();
  while (1)
    {
      declare prop_name_obj, xx any;
      prop_name_obj := java_call_method ('java.util.Enumeration', java_util_enumeration, 'nextElement', 'Ljava/lang/Object;');
      prop_name := java_call_method ('java.lang.Object', prop_name_obj, 'toString', 'Ljava/lang/String;');
      prop_value := java_call_method ('java.util.Properties', java_util_properties, 'getProperty', 'Ljava/lang/String;', cast (prop_name as varchar));
      res := vector_concat (res, vector (vector (prop_name, sprintf ('{%s}', prop_value))));
      prop_name_obj := null;
    }
  done:
  java_util_properties := null;
  java_util_enumeration := null;
  java_vm_detach ();
  return res;
};

java_load_class ('java_server', XML_URI_GET ('', TUTORIAL_XSL_DIR()||'/tutorial/services/so_s_23/java_server.class'));

grant execute on "Getconst_pi" to SOAPDEMO;

grant execute on "Getlong_val" to SOAPDEMO;

grant execute on "Setlong_val" to SOAPDEMO;

grant execute on "echoString" to SOAPDEMO;

grant execute on "echoInt" to SOAPDEMO;

grant execute on java_properties to SOAPDEMO;

