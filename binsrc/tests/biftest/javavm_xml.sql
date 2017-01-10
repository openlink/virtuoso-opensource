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

create procedure jvm_ref_print (in xx any, inout ses any)
{
  http (xx, ses);
}
;

create procedure jvm_type_to_pl_type (in java_type varchar, in is_primitive int, in is_array int, inout escape_it integer) returns varchar
{
  escape_it := 0;
  java_type := cast (java_type as varchar);
  if (is_array)
    return 'any';
  if (is_primitive)
    {
      if (java_type = 'byte') return 'smallint';
      if (java_type = 'char') return 'smallint';
      if (java_type = 'double') return 'double precision';
      if (java_type = 'float') return 'real';
      if (java_type = 'int') return 'integer';
      if (java_type = 'long') return 'integer';
      if (java_type = 'short') return 'smallint';
      if (java_type = 'boolean') return 'smallint';
      if (java_type = 'void') return 'any';
    }
  else
    {
      if (java_type = 'java.lang.String') return 'nvarchar';
      if (java_type = 'java.lang.Date') return 'datetime';
      escape_it := 1;
      return replace (cast (java_type as varchar), '.', '_');
    }
}
;


create procedure jvm_type_to_signature (in java_type varchar, in is_primitive int, in is_array int) returns varchar
{
  java_type := cast (java_type as varchar);
  if (is_array)
    return replace (java_type, '.', '/');
  if (java_type = 'void') return 'V';
  if (is_primitive)
    {
      if (java_type = 'byte') return 'B';
      if (java_type = 'char') return 'C';
      if (java_type = 'double') return 'D';
      if (java_type = 'float') return 'F';
      if (java_type = 'int') return 'I';
      if (java_type = 'long') return 'J';
      if (java_type = 'short') return 'S';
      if (java_type = 'boolean') return 'B';
    }
  else
    return concat ('L', replace (cast (java_type as varchar), '.', '/'), ';');
}
;

create procedure jvm_type_to_schema_type (in java_type varchar, in is_primitive int, in is_array int) returns varchar
{
  java_type := cast (java_type as varchar);
  if (is_array)
    return '';
  if (is_primitive)
    {
      if (java_type = 'byte') return 'http://www.w3.org/2001/XMLSchema:byte';
      if (java_type = 'char') return 'http://www.w3.org/2001/XMLSchema:unsignedShort';
      if (java_type = 'double') return 'http://www.w3.org/2001/XMLSchema:double';
      if (java_type = 'float') return 'http://www.w3.org/2001/XMLSchema:float';
      if (java_type = 'int') return 'http://www.w3.org/2001/XMLSchema:int';
      if (java_type = 'long') return 'http://www.w3.org/2001/XMLSchema:long';
      if (java_type = 'short') return 'http://www.w3.org/2001/XMLSchema:short';
      if (java_type = 'boolean') return 'http://www.w3.org/2001/XMLSchema:boolelan';
      return '';
    }
  else
    {
      if (java_type = 'java.lang.String') return 'http://www.w3.org/2001/XMLSchema:string';
      if (java_type = 'java.lang.Date') return 'http://www.w3.org/2001/XMLSchema:timeInstant';
      return '';
    }
}
;


create procedure jvm_ref_describe_method (inout jvm_method any, inout ses any,
    in method_type varchar,
    in entity_name varchar,
    inout under_class any)
{
  declare method_name varchar;
  declare overriding integer;

  overriding := 0;

  declare modifiers, static_mask, private_mask, protected_mask any;
  modifiers := cast (java_call_method (method_type, jvm_method, 'getModifiers', 'I') as integer);
  static_mask := cast (java_get_property ('java.lang.reflect.Modifier', NULL, 'STATIC', 'I') as integer);
  private_mask := cast (java_get_property ('java.lang.reflect.Modifier', NULL, 'PRIVATE', 'I') as integer);
  protected_mask := cast (java_get_property ('java.lang.reflect.Modifier', NULL, 'PROTECTED', 'I') as integer);

  if (bit_and (modifiers, private_mask)	> 0 or bit_and (modifiers, protected_mask) > 0)
    return;

  method_name := java_call_method (method_type, jvm_method, 'getName', 'Ljava/lang/String;');
  if (under_class is not null)
    {
      declare method_params any;
      method_params := java_call_method (method_type, jvm_method, 'getParameterTypes', '[Ljava/lang/Class;');
       {
         declare exit handler for sqlstate '*';
	 java_call_method ('java.lang.Class', under_class, 'getMethod', 'Ljava/lang/reflect/Method;',
	     method_name, vector ('[Ljava/lang/Class;', method_params));
	 overriding := 1;
       }
    }

  if (entity_name = 'method')
    {
      jvm_ref_print (sprintf ('\n<%s name="%s" static="%d" overriding="%d">',
	    entity_name, method_name,
	    bit_and (modifiers, static_mask) / static_mask, overriding
	    ), ses);
    }
  else
      jvm_ref_print (sprintf ('\n<%s>', entity_name), ses);


  declare return_type, is_primitive, is_array any;
  if (entity_name = 'method')
    {
      declare return_type_cls, plescape any;
      return_type_cls := java_call_method (method_type, jvm_method, 'getReturnType', 'Ljava/lang/Class;');
      return_type := java_call_method ('java.lang.Class', return_type_cls, 'getName', 'Ljava/lang/String;');
      is_primitive := java_call_method ('java.lang.Class', return_type_cls, 'isPrimitive', 'Z');
      is_array := java_call_method ('java.lang.Class', return_type_cls, 'isArray', 'Z');
      return_type_cls := null;
      jvm_ref_print (sprintf ('\n<returnType type="%s" is_primitive="%d" is_array="%d" pltype="%s" signature="%s" soaptype="%s" plescape="%d"/>',
	 return_type, is_primitive, is_array,
	     jvm_type_to_pl_type (return_type, is_primitive, is_array, plescape),
	 jvm_type_to_signature (return_type, is_primitive, is_array),
	 jvm_type_to_schema_type (return_type, is_primitive, is_array),
	 plescape
	 ), ses);
    }
  else
    {
      return_type := 'void';
    }


  declare param_types any;
  declare param_inx integer;
  param_types := java_call_method (method_type, jvm_method, 'getParameterTypes', '[Ljava/lang/Class;');
  param_inx := 0;
  jvm_ref_print ('\n<parameters>', ses);
  while (param_inx < length (param_types))
    {
       declare param_type, ref_type,plescape any;
       declare param_type_obj any;

       param_type_obj := param_types[param_inx];
       param_type := java_call_method ('java.lang.Class', param_type_obj, 'getName', 'Ljava/lang/String;');
       is_primitive := java_call_method ('java.lang.Class', param_type_obj, 'isPrimitive', 'Z');
       is_array := java_call_method ('java.lang.Class', param_type_obj, 'isArray', 'Z');
       if (is_primitive = 1 and is_array = 0)
	 ref_type := 'in';
       else
	 ref_type := 'inout';
       jvm_ref_print (
	   sprintf (
	     '\n<param name="p%d" type="%s" is_primitive="%d" is_array="%d" pltype="%s" signature="%s" soaptype="%s" reftype="%s" plescape="%d"/>',
	     param_inx + 1, param_type, is_primitive, is_array,
	     jvm_type_to_pl_type (param_type, is_primitive, is_array, plescape),
	     jvm_type_to_signature (param_type, is_primitive, is_array),
	     jvm_type_to_schema_type (param_type, is_primitive, is_array),
             ref_type,
	     plescape
	     ), ses);
       param_inx := param_inx + 1;
       param_type_obj := null;
    }
  param_types := null;
  jvm_ref_print ('\n</parameters>', ses);
  jvm_ref_print (sprintf ('\n</%s>', entity_name), ses);
}
;


create procedure jvm_ref_describe_class (in jvm varchar, inout classes any, in unrestricted integer)
{
  declare inx integer;
  declare inherited integer;
  declare str_unrestricted varchar;

  inherited := 1;

  declare ses any;
  ses := string_output ();

  declare jvm_class, under_class any;
  jvm_class := jvm_load_class (cast (jvm as varchar));

  declare jvm_super_class any;
  jvm_super_class := java_call_method ('java.lang.Class', jvm_class, 'getSuperclass', 'Ljava/lang/Class;');
  declare jvm_super_class_name, under_name  varchar;
  under_name := '';
  under_class := null;

  str_unrestricted := '';
  if (unrestricted)
    str_unrestricted := ' restiction="unrestricted"';

  if (jvm_super_class is not null)
    {
      jvm_super_class_name := cast (java_call_method ('java.lang.Class', jvm_super_class, 'getName', 'Ljava/lang/String;') as varchar);
      declare class_inx integer;
      class_inx := 0;
      while (class_inx < length (classes))
	{
	  if (classes[class_inx] = jvm_super_class_name)
	    {
	      under_class := jvm_load_class (cast (jvm_super_class_name as varchar));
	      under_name := replace (cast (jvm_super_class_name as varchar), '.', '_');
	      class_inx := length (classes);
              inherited := 0;
	    }
	  else
	    class_inx := class_inx + 1;
	}
    }

  jvm_ref_print (
      sprintf (
	'\n<class type="%s" pl_lang="JAVA" pl_type="%s" pl_under="%s"%s>',
	jvm,
	replace (cast (jvm as varchar), '.', '_'),
	under_name, str_unrestricted),
      ses);

-- fields
  declare jvm_fields any;
  if (inherited <> 0)
      jvm_fields := java_call_method ('java.lang.Class', jvm_class,
			    'getFields', '[Ljava/lang/reflect/Field;');
  else
      jvm_fields := java_call_method ('java.lang.Class', jvm_class,
			    'getDeclaredFields', '[Ljava/lang/reflect/Field;');
  inx := 0;
  while (inx < length (jvm_fields))
    {
      declare fld_name, fld_type, fld_type_obj, is_primitive, is_array, plescape varchar;
      declare modifiers, static_mask, final_mask, private_mask, protected_mask any;
      declare jvm_field any;

      jvm_field := jvm_fields[inx];
      fld_name := java_call_method ('java.lang.reflect.Field', jvm_field,
		    'getName', 'Ljava/lang/String;');
      fld_type_obj := java_call_method ('java.lang.reflect.Field', jvm_field,
		    'getType', 'Ljava/lang/Class;');
      fld_type := java_call_method ('java.lang.Class', fld_type_obj,
		    'getName', 'Ljava/lang/String;');
      is_primitive := java_call_method ('java.lang.Class', fld_type_obj, 'isPrimitive', 'Z');
      is_array := java_call_method ('java.lang.Class', fld_type_obj, 'isArray', 'Z');
      modifiers := cast (java_call_method ('java.lang.reflect.Field', jvm_field,
		       'getModifiers', 'I') as integer);
      static_mask := cast (java_get_property ('java.lang.reflect.Modifier', NULL,
			 'STATIC', 'I') as integer);
      final_mask := cast (java_get_property ('java.lang.reflect.Modifier', NULL,
			 'FINAL', 'I') as integer);
      private_mask := cast (java_get_property ('java.lang.reflect.Modifier', NULL, 'PRIVATE', 'I') as integer);
      protected_mask := cast (java_get_property ('java.lang.reflect.Modifier', NULL, 'PROTECTED', 'I') as integer);
      if (bit_and (modifiers, private_mask) = 0 and bit_and (modifiers, protected_mask) = 0)
	{
	  jvm_ref_print (
	      sprintf (
		'\n<field name="%s" type="%s" static="%d" final="%d" is_primitive="%d" is_array="%d" pltype="%s" signature="%s" soaptype="%s" plescape="%d"/>',
		fld_name, fld_type,
		bit_and (modifiers, static_mask) / static_mask,
		bit_and (modifiers, final_mask) / final_mask,
		is_primitive,
		is_array,
		jvm_type_to_pl_type (fld_type, is_primitive, is_array, plescape),
		jvm_type_to_signature (fld_type, is_primitive, is_array),
		jvm_type_to_schema_type (fld_type, is_primitive, is_array),
		plescape
		), ses);
	}
      inx := inx + 1;
      fld_type_obj := null;
      jvm_field := null;
    }
  jvm_fields := null;

-- constructors
  declare jvm_constructors any;
  if (inherited <> 0)
      jvm_constructors := java_call_method ('java.lang.Class', jvm_class,
			    'getConstructors', '[Ljava/lang/reflect/Constructor;');
  else
      jvm_constructors := java_call_method ('java.lang.Class', jvm_class,
			    'getDeclaredConstructors', '[Ljava/lang/reflect/Constructor;');
  inx := 0;
  while (inx < length (jvm_constructors))
    {
      declare jvm_constructor, const_under_class any;
      const_under_class := null;
      jvm_constructor := jvm_constructors[inx];
      jvm_ref_describe_method (jvm_constructor, ses, 'java.lang.reflect.Constructor', 'constructor', const_under_class);
      inx := inx + 1;
      jvm_constructor := null;
    }
  jvm_constructors := null;

-- methods
  declare jvm_methods any;
  if (inherited <> 0)
      jvm_methods := java_call_method ('java.lang.Class', jvm_class,
		       'getMethods', '[Ljava/lang/reflect/Method;');
  else
      jvm_methods := java_call_method ('java.lang.Class', jvm_class,
		       'getDeclaredMethods', '[Ljava/lang/reflect/Method;');
  inx := 0;
  while (inx < length (jvm_methods))
    {
      declare jvm_method any;
      jvm_method := jvm_methods[inx];
      jvm_ref_describe_method (jvm_method, ses, 'java.lang.reflect.Method', 'method', under_class);
      inx := inx + 1;
      jvm_method := null;
    }
  jvm_methods := null;
  jvm_class := null;

  jvm_ref_print ('\n</class>', ses);
--java_vm_detach();

  return string_output_string (ses);
}
;

create procedure jvm_ref_archive_handler (in name varchar, in class_name varchar := null)
{
  declare jar any;

  if (lower (name) like '%jar')
    jar := java_new_object ('java.util.jar.JarFile', name);
  else if (lower (name) like '%zip')
    jar := java_new_object ('java.util.zip.ZipFile', name);
  else
    signal ('xxxx', 'unknown file type');


  declare entries any;

  entries := java_call_method ('java.util.zip.ZipFile', jar, 'entries', 'Ljava/util/Enumeration;');

  declare entry_name varchar;
  declare entry_size integer;

  if (class_name is null)
    result_names (entry_size, entry_name);
  while (java_call_method ('java.util.Enumeration', entries, 'hasMoreElements', 'Z') > 0)
    {
      declare entry any;
      entry := null;
      entry := java_call_method ('java.util.Enumeration', entries, 'nextElement', 'Ljava/lang/Object;');

      entry_name := null;
      entry_size := null;

      entry_name := java_call_method ('java.util.zip.ZipEntry', entry, 'getName', 'Ljava/lang/String;');
      entry_size := java_call_method ('java.util.zip.ZipEntry', entry, 'getSize', 'J');

      entry_name := cast (entry_name as varchar);

      if (class_name is not null)
        {
	  if (class_name = entry_name)
	    {
	      if (entry_size >= 1000000)
		signal ('xxxxx', 'Max 1M can be read from the zip file');
	      declare chunk_size integer;
	      declare bytecode_buffer varbinary;
	      declare bytecode varbinary;
	      declare readed integer;

	      bytecode := '';
	      chunk_size := 0;
	      declare datas any;
              datas := java_call_method ('java.util.zip.ZipFile', jar, 'getInputStream', 'Ljava/io/InputStream;',
			vector ('Ljava/util/zip/ZipEntry;', entry));
              readed := 0;

	      while (readed < entry_size)
		{
		  chunk_size := entry_size - readed;
		  bytecode_buffer := cast (repeat (' ', chunk_size) as varbinary);
		  chunk_size := java_call_method ('java.io.InputStream', datas, 'read', 'I', bytecode_buffer);
		  if (chunk_size <> -1)
		    {
		      bytecode := concat (bytecode, left (cast (bytecode_buffer as varchar), chunk_size));
		      readed := readed - chunk_size;
		    }
		  else
		    readed := entry_size;
		}
	      if (readed = entry_size)
		return bytecode;
	      else
		signal ('xxxxx', 'can''t read the data from the archive');
	    }
	}
      else
	{
	  result (entry_size, entry_name);
	}
    }
  if (class_name is not null)
    {
    return null;
    }
}
;

create procedure jvm_load_class (in jvm varchar)
{
  declare class_loader any;

  return java_load_class (jvm);
--  class_loader := java_call_method ('java.lang.ClassLoader', NULL,
--		 'getSystemClassLoader', 'Ljava/lang/ClassLoader;');
--  return java_call_method ('java.lang.ClassLoader', class_loader,
--      'loadClass', 'Ljava/lang/Class;', vector('Ljava/lang/String;', jvm), vector ('Z', 1));
}
;


create procedure jvm_ref_import (in files any, in classes any, in unrestricted integer)
{
  declare ret any;
  declare add_to_classes_mask varchar;
  add_to_classes_mask := '';
  if (isstring (classes))
    {
      if (strstr (classes, '*') is not null)
	{
	  dbg_obj_print ('in star case');
          add_to_classes_mask := classes;
          classes := vector ();
	}
      else
        classes := vector (classes);
    }
  if (isstring (files))
    {
      files := vector (files);
    }

  if (isarray (files))
    {
      declare files_inx integer;
      files_inx := 0;

      while (files_inx < length (files))
	{
	  declare file_name varchar;
	  file_name := files[files_inx];
	  if (lower (file_name) like '%.class')
	    {
	      declare class_name varchar;
	      class_name := replace (cast (file_name as varchar), '.class', '');
--	      java_load_class (replace (file_name, '.class', ''), file_to_string (file_name));
	      jvm_load_class (class_name);
	      if (add_to_classes_mask <> '' and
		  class_name like add_to_classes_mask)
		classes := vector_concat (classes, vector (class_name));

	    }
	  else if (lower (file_name) like '%.jar' or lower (file_name) like '%.zip')
	    {
	      declare res any;
	      declare res_inx integer;
	      exec ('jvm_ref_archive_handler (?)', null, null, vector (file_name), 0, null, res);
	      res_inx := 0;
	      --dbg_obj_print ('xxx', res);
	      while (res_inx < length (res))
		{
		  declare jar_file_name varchar;
		  jar_file_name := res[res_inx][1];
		  --dbg_obj_print ('xxx2', res);
                  if (jar_file_name like '%.class')
		    {
		      declare ret any;
		      declare jar_class_name varchar;
		      jar_class_name := replace (cast (jar_file_name as varchar), '.class', '');
--	 	      ret := java_load_class (replace (jar_file_name, '.class', ''),
--			    jvm_ref_archive_handler (file_name, jar_file_name));
	 	      ret := jvm_load_class (jar_class_name);
		      --dbg_obj_print ('xxx3', replace (jar_file_name, '.class', ''), ret);
		      if (add_to_classes_mask <> '' and
			  jar_class_name like add_to_classes_mask)
			classes := vector_concat (classes, vector (replace (jar_class_name, '/', '.')));
		    }
		  res_inx := res_inx + 1;
		}
	    }
	  else
	    signal ('xxxxx', 'file name needs to be .class .zip or .jar');
	  files_inx := files_inx + 1;
	}
    }

  declare ses any;
  ses := string_output();
  if (isarray (classes))
    {
      declare class_inx integer;
      class_inx := 0;

      jvm_ref_print ('<classes>\n', ses);
      while (class_inx < length (classes))
	{
	  declare class_name varchar;
	  class_name := classes[class_inx];

          declare the_xml varchar;
	  jvm_ref_print (jvm_ref_describe_class (class_name, classes, unrestricted), ses);
	  jvm_ref_print ('\n', ses);
	  class_inx := class_inx + 1;
	}
      jvm_ref_print ('</classes>\n', ses);
    }
  return string_output_string (ses);
}
;

create procedure import_jar (in files any, in classes any, in unrestricted integer := 0,
			     in _is_return_sql integer := 0)
{
  declare _xml, _xmlv any;
  declare pl, all_pl varchar;
  _xml := xml_tree_doc (jvm_ref_import (files, classes, unrestricted));

  _xmlv := xpath_eval ('/classes/class', _xml, 0);
--dbg_obj_print (_xmlv);

  if (isarray (_xmlv))
    {
      declare inx integer;
      inx := 0;
      all_pl := '';

      while (inx < length (_xmlv))
	{
	  declare _xmlv_frag any;
	  _xmlv_frag := xml_cut (_xmlv[inx]);
          pl := cast (xslt ('http://local.virt/javavm_type', _xmlv_frag) as varchar);
--        dbg_obj_print (_xmlv_frag);
--        dbg_obj_print (pl);
	  if (_is_return_sql)
	    all_pl := all_pl || pl;
	  else
            exec (pl);
	  inx := inx + 1;
	}
    }
  if (_is_return_sql)
    return all_pl;
}
;


create procedure unimport_jar (in files any, in classes any)
{
  declare _xml, _xmlv any;
  declare pl varchar;
  _xml := xml_tree_doc (jvm_ref_import (files, classes, 0));

  _xmlv := xpath_eval ('/classes/class/@pl_type', _xml, 0);

  if (isarray (_xmlv))
    {
      declare inx integer;
      inx := 0;

      foreach (any _xml in _xmlv) do
	{
	  declare _children any;
	  _children := udt_get_info (cast (_xml as varchar), 'children');
	  foreach (varchar _xml_child in _children) do
	    {
	      declare _found int;
	      _found := 0;
	      foreach (any _xml2 in _xmlv) do
	        {
		  if (cast (_xml2 as varchar) = _xml_child)
		    _found := 1;
		}
	      if (not _found)
		signal ('42000', sprintf (
	          'unimport_jar is to drop an user defined type %s that is a supertype of %s. Please drop the subtype(s) first.', _xml, _xml_child));
	    }
	}

      while (inx < length (_xmlv))
	{
          pl := sprintf ('DROP TYPE "%I"', cast (_xmlv[inx] as varchar));
          dbg_obj_print (pl);
          exec (pl);
	  inx := inx + 1;
	}
    }
}
;


create procedure import_get_types_int (in sel_name varchar)
{
  declare types, ret any;
  declare esc_string varchar;
  declare idx integer;

  ret := vector ();

  if (strstr (sel_name, '.class') is not NULL)
    {
       declare pos integer;
       sel_name := replace (sel_name, '\\', '/');
       pos := strrchr (sel_name , '/');
       sel_name := subseq (sel_name, pos + 1);
       return vector (replace (sel_name, '.class', ''));
    }
  else if ((strstr (sel_name, '.jar') is not NULL) or
           (strstr (sel_name, '.zip') is not NULL))
    {
      declare jar_list any;

      for ( select entry_name from jvm_ref_archive_handler (m) (sz integer, entry_name varchar) c where m = sel_name) do
         {
            if (strstr (entry_name, '.class') is not NULL)
              ret := vector_concat (ret, vector (entry_name));
     	 }

      return ret;
    }

  return vector ();
}
;

