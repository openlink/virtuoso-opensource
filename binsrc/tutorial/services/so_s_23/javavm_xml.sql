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
};


create procedure jvm_type_to_pl_type (in java_type varchar, in is_primitive int, in is_array int) returns varchar
{
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
    }
  else
    {
      if (java_type = 'java.lang.String') return 'nvarchar';
      if (java_type = 'java.lang.Date') return 'datetime';
      return 'any';
    }
};


create procedure jvm_type_to_signature (in java_type varchar, in is_primitive int, in is_array int) returns varchar
{
  java_type := cast (java_type as varchar);
  if (is_array)
    return java_type;
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
    return concat ('L', replace (java_type, '.', '/'), ';');
};

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
    }
  else
    {
      if (java_type = 'java.lang.String') return 'http://www.w3.org/2001/XMLSchema:string';
      if (java_type = 'java.lang.Date') return 'http://www.w3.org/2001/XMLSchema:timeInstant';
      return '';
    }
};


create procedure jvm_ref_describe_method (inout jvm_method any, inout ses any,
    in method_type varchar := 'java.lang.reflect.Method',
    in entity_name varchar := 'method')
{
  declare method_name varchar;

  method_name := java_call_method (method_type, jvm_method, 'getName', 'Ljava/lang/String;');

  if (entity_name = 'method')
    {
      declare modifiers, static_mask any;
      modifiers := cast (java_call_method (method_type, jvm_method, 'getModifiers', 'I') as integer);
      static_mask := cast (java_get_property ('java.lang.reflect.Modifier', NULL, 'STATIC', 'I') as integer);

      jvm_ref_print (sprintf ('\n<%s name="%s" static="%d">',
	    entity_name, method_name,
	    bit_and (modifiers, static_mask) / static_mask
	    ), ses);
    }
  else
      jvm_ref_print (sprintf ('\n<%s>', entity_name), ses);


  declare return_type, is_primitive, is_array any;
  if (entity_name = 'method')
    {
      declare return_type_cls any;
      return_type_cls := java_call_method (method_type, jvm_method, 'getReturnType', 'Ljava/lang/Class;');
      return_type := java_call_method ('java.lang.Class', return_type_cls, 'getName', 'Ljava/lang/String;');
      is_primitive := java_call_method ('java.lang.Class', return_type_cls, 'isPrimitive', 'Z');
      is_array := java_call_method ('java.lang.Class', return_type_cls, 'isArray', 'Z');
      return_type_cls := null;
    }
  else
    {
      return_type := 'void';
    }
  if (return_type <> 'void')
    jvm_ref_print (sprintf ('\n<returnType type="%s" is_primitive="%d" is_array="%d" pltype="%s" signature="%s" soaptype="%s"/>',
	 return_type, is_primitive, is_array,
	 jvm_type_to_pl_type (return_type, is_primitive, is_array),
	 jvm_type_to_signature (return_type, is_primitive, is_array),
	 jvm_type_to_schema_type (return_type, is_primitive, is_array)
	 ), ses);


  declare param_types any;
  declare param_inx integer;
  param_types := java_call_method (method_type, jvm_method, 'getParameterTypes', '[Ljava/lang/Class;');
  param_inx := 0;
  jvm_ref_print ('\n<parameters>', ses);
  while (param_inx < length (param_types))
    {
       declare param_type, ref_type any;
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
	     '\n<param name="p%d" type="%s" is_primitive="%d" is_array="%d" pltype="%s" signature="%s" soaptype="%s" reftype="%s" />',
	     param_inx + 1, param_type, is_primitive, is_array,
	     jvm_type_to_pl_type (param_type, is_primitive, is_array),
	     jvm_type_to_signature (param_type, is_primitive, is_array),
	     jvm_type_to_schema_type (param_type, is_primitive, is_array),
             ref_type
	     ), ses);
       param_inx := param_inx + 1;
       param_type_obj := null;
    }
  param_types := null;
  jvm_ref_print ('\n</parameters>', ses);
  jvm_ref_print (sprintf ('\n</%s>', entity_name), ses);
};


create procedure jvm_ref_describe_class (in jvm varchar, in inherited integer := 0)
{
  declare inx integer;

  declare ses any;
  ses := string_output ();

  jvm_ref_print (sprintf ('\n<class type="%s">', jvm), ses);

  declare jvm_class any;
  jvm_class := java_call_method ('java.lang.Class', NULL, 'forName', 'Ljava/lang/Class;', jvm);


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
      declare fld_name, fld_type, fld_type_obj, is_primitive, is_array varchar;
      declare modifiers, static_mask, final_mask any;
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
      jvm_ref_print (
	  sprintf (
	    '\n<field name="%s" type="%s" static="%d" final="%d" is_primitive="%d" is_array="%d" pltype="%s" signature="%s" soaptype="%s" />',
	    fld_name, fld_type,
	    bit_and (modifiers, static_mask) / static_mask,
	    bit_and (modifiers, final_mask) / final_mask,
	    is_primitive,
	    is_array,
	    jvm_type_to_pl_type (fld_type, is_primitive, is_array),
	    jvm_type_to_signature (fld_type, is_primitive, is_array),
	    jvm_type_to_schema_type (fld_type, is_primitive, is_array)
	    ), ses);
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
      declare jvm_constructor any;
      jvm_constructor := jvm_constructors[inx];
      jvm_ref_describe_method (jvm_constructor, ses, 'java.lang.reflect.Constructor', 'constructor');
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
      jvm_ref_describe_method (jvm_method, ses);
      inx := inx + 1;
      jvm_method := null;
    }
  jvm_methods := null;
  jvm_class := null;

  jvm_ref_print ('\n</class>', ses);
  java_vm_detach();

  return string_output_string (ses);
};

create procedure jvm_java_map (in class_name varchar, in bytecode any)
{
  java_load_class (class_name, bytecode);
  return jvm_ref_describe_class (class_name);
};

checkpoint;
