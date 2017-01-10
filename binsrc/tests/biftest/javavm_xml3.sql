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

create procedure jvm_ref_describe_constructor (inout jvm_method java_lang_reflect_Constructor, inout ses any)
{
  declare method_name varchar;

  method_name := jvm_method.getName ();

  jvm_ref_print (sprintf ('\n<%s>', 'constructor'), ses);


  declare is_primitive, is_array smallint;
  declare return_type any;

  return_type := 'void';

  declare param_types any;
  declare param_inx integer;
  param_types := jvm_method.getParameterTypes ();
  param_inx := 0;
  jvm_ref_print ('\n<parameters>', ses);
  while (param_inx < length (param_types))
    {
       declare param_type, ref_type varchar;
       declare param_type_obj java_lang_Class;

       param_type_obj := param_types[param_inx];
       param_type := param_type_obj.getName ();
       is_primitive := param_type_obj.isPrimitive ();
       is_array := param_type_obj.isArray ();
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
  jvm_ref_print (sprintf ('\n</%s>', 'constructor'), ses);
}
;


create procedure jvm_ref_describe_method2 (inout jvm_method java_lang_reflect_Method, inout ses any)
{
  declare method_name varchar;

  method_name := jvm_method.getName();

  declare modifiers, static_mask any;
  modifiers := cast (jvm_method.getModifiers() as integer);
  static_mask := cast (java_lang_reflect_Modifier::getSTATIC() as integer);

  jvm_ref_print (sprintf ('\n<%s name="%s" static="%d">',
	'method', method_name,
	bit_and (modifiers, static_mask) / static_mask
	), ses);

  declare is_primitive, is_array smallint;
  declare return_type varchar;
  declare return_type_cls java_lang_Class;
  return_type_cls := jvm_method.getReturnType ();
  return_type := return_type_cls.getName ();
  is_primitive := return_type_cls.isPrimitive ();
  is_array := return_type_cls.isArray ();
  return_type_cls := null;
  if (return_type <> 'void')
    jvm_ref_print (sprintf ('\n<returnType type="%s" is_primitive="%d" is_array="%d" pltype="%s" signature="%s" soaptype="%s"/>',
	 return_type, is_primitive, is_array,
	 jvm_type_to_pl_type (return_type, is_primitive, is_array),
	 jvm_type_to_signature (return_type, is_primitive, is_array),
	 jvm_type_to_schema_type (return_type, is_primitive, is_array)
	 ), ses);


  declare param_types any;
  declare param_inx integer;
  param_types := jvm_method.getParameterTypes ();
  param_inx := 0;
  jvm_ref_print ('\n<parameters>', ses);
  while (param_inx < length (param_types))
    {
       declare ref_type varchar;
       declare param_type varchar;
       declare param_type_obj java_lang_Class;

       param_type_obj := param_types[param_inx];
       param_type := param_type_obj.getName ();
       is_primitive := param_type_obj.isPrimitive ();
       is_array := param_type_obj.isArray ();
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
  jvm_ref_print (sprintf ('\n</%s>', 'method'), ses);
}
;

create procedure jvm_ref_describe_class2 (in jvm varchar, in inherited integer := 0)
{
  declare inx integer;

  declare ses any;
  ses := string_output ();

  jvm_ref_print (sprintf ('\n<class type="%s">', jvm), ses);

  declare jvm_class java_lang_Class;
  jvm_class := java_lang_Class::forName(jvm);

-- fields
  declare jvm_fields any;
  if (inherited <> 0)
      jvm_fields := jvm_class.getFields();
  else
      jvm_fields := jvm_class.getDeclaredFields ();
  inx := 0;
  while (inx < length (jvm_fields))
    {
      declare fld_name, fld_type varchar;
      declare is_primitive, is_array smallint;
      declare modifiers, static_mask, final_mask integer;
      declare jvm_field java_lang_reflect_Field;
      declare fld_type_obj java_lang_Class;

      jvm_field := jvm_fields[inx];
      fld_name := jvm_field.getName();
      fld_type_obj := jvm_field.getType();
      fld_type := fld_type_obj.getName();
      is_primitive := fld_type_obj.isPrimitive();
      is_array := fld_type_obj.isArray();
      modifiers := cast (jvm_field.getModifiers() as integer);
      static_mask := cast (java_lang_reflect_Modifier::getSTATIC() as integer);
      final_mask := cast (java_lang_reflect_Modifier::getFINAL() as integer);
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
      jvm_constructors := jvm_class.getConstructors();
  else
      jvm_constructors := jvm_class.getDeclaredConstructors ();
  inx := 0;
  while (inx < length (jvm_constructors))
    {
      declare jvm_constructor java_lang_reflect_Constructor;
      jvm_constructor := jvm_constructors[inx];
      jvm_ref_describe_constructor (jvm_constructor, ses);
      inx := inx + 1;
      jvm_constructor := null;
    }
  jvm_constructors := null;

-- methods
  declare jvm_methods any;
  if (inherited <> 0)
      jvm_methods := jvm_class.getMethods ();
  else
      jvm_methods := jvm_class.getDeclaredMethods ();
  inx := 0;
  while (inx < length (jvm_methods))
    {
      declare jvm_method java_lang_reflect_Method;
      jvm_method := jvm_methods[inx];
      jvm_ref_describe_method2 (jvm_method, ses);
      inx := inx + 1;
      jvm_method := null;
    }
  jvm_methods := null;
  jvm_class := null;

  jvm_ref_print ('\n</class>', ses);
  java_vm_detach();

  return string_output_string (ses);
}
;


create procedure jvm_java_map2 (in class_name varchar, in bytecode any)
{
  java_load_class (class_name, bytecode);
  return jvm_ref_describe_class2 (class_name);
}
;
