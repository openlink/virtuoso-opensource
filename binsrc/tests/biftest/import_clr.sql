--
--  $Id$
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2019 OpenLink Software
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

--create trigger event_delete_clr_create_library after delete on DB.DBA.CLR_VAC
--{
--  __remove_dll_from_hash (VAC_REAL_NAME);
--}
--;


--create trigger event_clr_create_library after update on DB.DBA.CLR_VAC referencing old as O, new as N
--{
--   __remove_dll_from_hash (O.VAC_REAL_NAME);
--}
--;

create procedure DB.DBA.CACHE_ASSEMBLY_TO_DISK (in _asm_name varchar, in server_exe varchar)
{
   declare _code varchar;

   SELECT blob_to_string (VAC_DATA) into _code from DB.DBA.CLR_VAC where VAC_REAL_NAME = _asm_name;

   string_to_file (server_exe || _asm_name || '.dll', _code, -2);
}
;

create procedure DB.DBA.CLR_CREATE_LIBRARY (in asm_name varchar, in internal_name varchar,
					    in auto_register integer, in perm_mode integer)
{

  declare full_name, short_name varchar;

  import_get_assem_names (asm_name, full_name, short_name);

  insert replacing DB.DBA.CLR_VAC (VAC_INTERNAL_NAME, VAC_REAL_NAME, VAC_FULL_NAME,
				   VAC_DATA, VAC_FULL_FILE_NAME, VAC_PERM_SET)
	 values (internal_name, short_name, full_name, file_to_string(asm_name), asm_name, perm_mode);

  commit work;

--  if (perm_mode = 1)
--    __add_assem_to_sec_hash (short_name);

  if (auto_register)
    {
      DB..import_clr (internal_name, NULL, unrestricted => perm_mode - 1);
    }
}
;

create procedure DB.DBA.CLR_CREATE_LIBRARY_UI (in asm_name varchar, in mtd_name varchar, in perm_mode integer)
{

  declare full_name, short_name varchar;

  import_get_assem_names (asm_name, full_name, short_name);

  insert replacing DB.DBA.CLR_VAC (VAC_INTERNAL_NAME, VAC_REAL_NAME, VAC_FULL_NAME,
				   VAC_DATA, VAC_FULL_FILE_NAME, VAC_PERM_SET)
	 values (short_name, short_name, full_name, file_to_string(asm_name), asm_name, perm_mode);

  commit work;

  DB..import_clr (short_name, mtd_name, unrestricted => perm_mode);
}
;


create procedure DB.DBA.CLR_CREATE_ASSEMBLY (in asm_name varchar, in internal_name varchar,
					     in auto_register integer, in perm_mode integer)
{
   DB.DBA.CLR_CREATE_LIBRARY (asm_name, internal_name, auto_register, perm_mode);
}
;


create procedure DB.DBA.CLR_DROP_LIBRARY (in internal_name varchar)
{
  if (exists (select 1 from DB.DBA.CLR_VAC where VAC_INTERNAL_NAME = internal_name))
    {
       unimport_clr (internal_name, NULL);
       delete from DB.DBA.CLR_VAC where VAC_INTERNAL_NAME = internal_name;
       commit work;
    }
}
;


create type Assembly language clr external name 'mscorlib/System.Reflection.Assembly'
as (FullName varchar external name 'FullName' external type 'String')
UNRESTRICTED TEMPORARY
       static method Load (name varchar external type 'String')
	      returns Assembly external name 'Load' external type 'System.Reflection.Assembly',
       static method LoadFrom (name varchar external type 'String')
	      returns Assembly external name 'LoadFrom' external type 'System.Reflection.Assembly',
       method GetTypes ()
	      returns any external name 'GetTypes' external type 'System.Type []'
;

create type _Type language clr external name 'mscorlib/System.Type'
as (BaseType varchar external name 'BaseType' external type 'System.Type')
UNRESTRICTED TEMPORARY
       method ToString ()
  	      returns varchar external name 'ToString' external type 'String',
       method GetMethods ()
  	      returns any external name 'GetMethods' external type 'System.MethodInfo []',
       method GetMembers ()
    	      returns any external name 'GetMembers' external type 'System.Reflection.MemberInfo []',
       method GetFields ()
    	      returns any external name 'GetFields' external type 'System.Reflection.FieldInfo []',
       method GetConstructors ()
  	      returns any external name 'GetConstructors' external type 'System.Reflection.ConstructorInfo []',
       method IsSubclassOf (xx _Type external type 'System.Type')
  	      returns smallint external name 'IsSubclassOf' external type 'Boolean',
       method Equals (xx _Type external type 'System.Type')
  	      returns smallint external name 'Equals' external type 'Boolean'
;

create type AssemFildInfo language clr external name 'mscorlib/System.Reflection.FieldInfo'
as (IsStatic integer external name 'IsStatic' external type 'Boolean',
    FieldType varchar external name 'FieldType' external type 'System.Type',
    Name varchar external name 'Name' external type 'String')
UNRESTRICTED TEMPORARY
    method ToString ()
      returns varchar external name 'ToString' external type 'String',
    method GetType ()
      returns _Type external name 'GetType' external type 'System.Type'
;

create type AssemblyMethod language clr external name 'mscorlib/System.Reflection.MethodInfo'
as (IsStatic integer external name 'IsStatic' external type 'Boolean',
    IsVirtual integer external name 'IsVirtual' external type 'Boolean',
    IsFinal integer external name 'IsFinal' external type 'Boolean',
    ReturnType varchar external name 'ReturnType' external type 'System.Type',
    DeclaringType varchar external name 'DeclaringType' external type 'System.Type')
UNRESTRICTED TEMPORARY

       method ToString ()
  	      returns varchar external name 'ToString' external type 'String',
       method GetParameters ()
  	      returns any external name 'GetParameters' external type 'System.Reflection.ParameterInfo []',
       method GetBaseDefinition ()
  	      returns AssemblyMethod external name 'GetBaseDefinition' external type
	'System.Reflection.MethodInfo'
;

create type ParameterInfo language clr external name 'mscorlib/System.Reflection.ParameterInfo'
as (IsIn smallint external name 'IsIn' external type 'Boolean',
    Name varchar external name 'Name' external type 'String',
    ParameterType varchar external name 'ParameterType' external type 'System.Type')
UNRESTRICTED TEMPORARY
    method GetType ()
      returns _Type external name 'GetType' external type 'System.Type'

;

create type ConstructorInfo language clr external name 'mscorlib/System.Reflection.ConstructorInfo'
as (IsStatic integer external name 'IsStatic' external type 'Boolean',
    DeclaringType varchar external name 'DeclaringType' external type 'System.Type')
UNRESTRICTED TEMPORARY
    method ToString ()
      returns varchar external name 'ToString' external type 'String',
    method GetType ()
      returns _Type external name 'GetType' external type 'System.Type',
    method GetParameters ()
       returns any external name 'GetParameters' external type 'System.Reflection.ParameterInfo []'

;

create procedure clr_ref_import (in assm_names varchar, in classes varchar, in unrestricted integer := 0,
				 in _is_add_virtual integer := 0)
{
   declare asm Assembly;
   declare types any;
   declare string, esc_string, _base_type_str, under_name, str_unrestricted varchar;
   declare _type, _base_type _Type;
   declare idx, len, inherited, fl integer;
   declare ses any;
   declare class_inx, asm_inx integer;

   ses := string_output ();

   if (isstring(classes))
     {
       classes := vector (classes);
     }

   if (isstring(assm_names))
     {
       assm_names:= vector (assm_names);
     }

   str_unrestricted := '';
   if (unrestricted)
     str_unrestricted := ' restiction="unrestricted"';

   asm_inx := 0;
   ses_print ('<classes>', ses);

   while (asm_inx < length (assm_names))
     {
	   declare assm_name varchar;

	   assm_name := assm_names [asm_inx];

	   assm_name := __get_dll_name (assm_name);

	   if (strstr (assm_name, '/') is not NULL)
	     asm := Assembly::LoadFrom(assm_name);
	   else
	     asm := Assembly::Load(assm_name);

       --dbg_obj_print ('clr_ref_import:Assembly=', assm_name);
       types := asm.GetTypes ();

       --dbg_obj_print ('clr_ref_import:types=', types);
       if (not isarray(types))
	types := vector (types);
       --dbg_obj_print ('clr_ref_import:types2=', types);

       len := length (types);
       idx := 0;

       if (classes is NULL)
	 {
	   classes := vector ();
	   while (idx < len)
	     {
		declare _ser any;
		_type := types[idx];

		string := cast (_type.ToString () as varchar);
		classes := vector_concat (classes, vector (string));
		idx := idx + 1;
	     }
	   idx := 0;
	 }

       while (idx < len)
	 {
	    _type := types[idx];
	    string := cast (_type.ToString () as varchar);
	    --dbg_obj_print ('clr_ref_import:doing type=', string);
	    esc_string := replace (string, '.', '_');

	    class_inx := 0;
	    fl := 0;

	    while (class_inx < length (classes))
	      {
		  if (classes[class_inx] = string)
		    {
		       fl := 1;
		       class_inx := length (classes);
		    }
		   class_inx := class_inx + 1;
	      }

	    if (fl = 0)
	      goto skip;

	    under_name := '';

	      {
		declare exit handler for SQLSTATE '*'
		{
		   _base_type_str := NULL;
		   goto next;
		};
		   _base_type := _type.BaseType;
		   _base_type_str := cast (_base_type.ToString () as varchar);
	      }

	     inherited := 1;
	     if (_base_type_str is not null)
	        {
		  class_inx := 0;
		  while (class_inx < length (classes))
		    {
		      if (classes[class_inx] = _base_type_str)
		        {
			  under_name := replace (cast (_base_type_str as varchar), '.', '_');
			  class_inx := length (classes);
			  inherited := 0;
		        }
		      else
		        class_inx := class_inx + 1;
		    }
	        }
next:
	      if (strstr (string, 'PrivateImplementationDetails') is NULL)
		  {
--		     dbg_obj_print (idx, '/', len);
		     ses_print (sprintf ('\n<class type="%s/%s" pl_lang="CLR" pl_type="%s" pl_under="%s" %s>',
			assm_name, string, esc_string, under_name, str_unrestricted ), ses);
		     clr_describe_class_type (ses, _type, _is_add_virtual, _base_type_str, under_name, _base_type);
		     ses_print ('\n</class>', ses);
		  }
skip:
	    idx := idx + 1;
	 }

        asm_inx := asm_inx + 1;
      }
   ses_print ('</classes>', ses);

   ses := string_output_string (ses);
-- dbg_obj_print (ses);

   return ses;
}
;

create procedure clr_describe_class_type (inout ses any, in class _Type, in _is_add_virtual integer,
					 in _base_type_str varchar, in under_name varchar, inout _base_type _Type)
{
  declare _name, _type, _pltype, _signature, _soaptype, c_name, field_name, _type_s varchar;
  declare _static, _is_final, _is_virtual, _is_primitive, _is_array integer;
  declare idx, len integer;
  declare methods any;
  declare members any;
  declare fields any;
  declare constructors any;
  declare to_string varchar;
  declare method AssemblyMethod;
  declare constructor ConstructorInfo;
  declare member AssemMemberInfo;
  declare field AssemFildInfo;
  declare _type _Type;

  methods := class.GetMethods ();
  members := class.GetMembers ();
  fields := class.GetFields ();
  constructors := class.GetConstructors ();

  if (not isarray(fields))
    fields := vector (fields);

  if (not isarray(members))
    members := vector (members);

  len := length (fields);
  idx := 0;

  while (idx < len)
    {
--     declare exit handler for SQLSTATE '*' {goto skip_this_mem;};
       declare _is_static, _is_primitive, _plescape smallint;
       declare _type_esc_s varchar;

       field := fields [idx];
       field_name := field.Name;
       _type := field.FieldType;
       _type_s := cast (_type.ToString() as varchar);
       _type_s := replace (_type_s, '&', '');
       _is_static := case field.IsStatic when 0 then 0 else 1 end;
       _is_primitive := clr_type_is_primitive (_type_s);
       _type_esc_s := clr_type_to_pl_type (_type_s, _is_primitive, _is_array, _plescape);
       _type_esc_s := replace (_type_esc_s, '.', '_');
       _type_esc_s := replace (_type_esc_s, '+', '_');
       _plescape := 0;
       _is_static := 0;

       ses_print (sprintf ('\n<field name="%s" type="%s" static="%d" final="0" is_primitive="%d" is_array="0" pltype="%s" signature="%s" soaptype="%s" plescape="%d"/>',
	  field_name, _type_s, _is_static, _is_primitive, _type_esc_s,  _type_s,
        cast (clr_type_to_schema_type (_type_s, _is_primitive, _is_array) as varchar),
          _plescape), ses);
       idx := idx + 1;
    }

skip_this_mem:

  if (not isarray(constructors))
    constructors := vector (constructors);

  len := length (constructors);
  idx := 0;

  ses_print ('\n<constructor>', ses);
  while (idx < len)
    {
       constructor := constructors[idx];
       declare temp_type _Type;
       temp_type := constructor.DeclaringType;
       if (temp_type.Equals (class))
	 clr_describe_parameters (ses, constructor.GetParameters ());
       idx := idx + 1;
    }
  ses_print ('\n</constructor>', ses);

  if (not isarray(methods))
    methods := vector (methods);

  len := length (methods);
  idx := 0;

   while (idx < len)
     {
        method := methods[idx];

        to_string := cast (method.ToString () as varchar);
        _name := '';
        _type := '';
        _pltype := '';
        _soaptype := '';

        if (strstr (to_string, '(') is not NULL);
          {
             declare pos integer;

             to_string := "LEFT" (to_string, strstr (to_string, '('));
             pos := strstr (to_string, ' ');

             if (pos is not NULL)
	       {
		  _name := subseq (to_string, pos + 1);
                  _type := "LEFT"  (to_string, pos);
	       }
          }

        _static := case method.IsStatic when 0 then 0 else 1 end;
        _is_final := case method.IsFinal when 0 then 0 else 1 end;
        _is_virtual := case method.IsVirtual when 0 then 0 else 1 end;

      declare overriding integer;
      overriding := 0;
      if (isstring (under_name))
        {
	   declare exit handler for SQLSTATE '*' {goto skip_this;};
           declare get_defs AssemblyMethod;
           declare _c_name, _dec_name varchar;
           declare _is_sub, _is_eq smallint;
           declare temp_type, dec_type _Type;

	  dec_type := method.DeclaringType;

          if (cast (dec_type.ToString() as varchar) <> cast (class.ToString() as varchar))
            goto next_mtd;

          _c_name := cast (class.ToString () as varchar);
          get_defs := method.GetBaseDefinition();
          _dec_name := cast ((get_defs.DeclaringType as _Type).ToString() as varchar);

          temp_type := get_defs.DeclaringType;

-- 	  _is_sub := _base_type.IsSubclassOf (temp_type);
-- 	  _is_sub := temp_type.IsSubclassOf (_base_type);
--        _is_eq  := _base_type.Equals (temp_type);
--        _is_eq  := temp_type.Equals (temp_type);

          if (_is_sub or _is_eq)
            overriding := 1;
          if (_dec_name = cast (_base_type.ToString() as varchar))
            overriding := 1;
       }
skip_this:;

	ses_print (sprintf ('\n<method name="%s" static="%d" overriding="%d">',
	    _name,  _static, overriding), ses);
	clr_describe_returns (ses, method.ReturnType);
	clr_describe_parameters (ses, method.GetParameters ());
	ses_print (sprintf ('\n</%s>', 'method'), ses);
next_mtd:
        idx := idx + 1;
     }
}
;


create procedure clr_describe_parameters (inout ses any, in parameters any)
{
  declare _name, _type_s, _type_esc_s, _pltype, _soaptype, _reftype varchar;
  declare _is_primitive, _is_array, _plescape integer;
  declare idx, len integer;
  declare line_param ParameterInfo;
  declare _type _Type;
  declare to_string varchar;
  declare string varchar;

  if (not isarray(parameters))
    parameters := vector (parameters);

  len := length (parameters);
  idx := 0;

  ses_print ('\n<parameters>', ses);

  while (idx < len)
    {
        declare _isin smallint;
        line_param := parameters[idx];
        _type := '';
        _pltype := '';
        _soaptype := '';
        _reftype := 'in';

        _isin := case line_param.IsIn when 0 then 0 else 1 end;
        _name := line_param.Name;
        _type := line_param.ParameterType;
        _type_s := cast (_type.ToString() as varchar);
        _type_s := replace (_type_s, '&', '');

        _is_primitive := clr_type_is_primitive (_type_s);
        _is_array := if_array (_type_s);
        _type_esc_s := clr_type_to_pl_type (_type_s, _is_primitive, _is_array, _plescape);
        _type_esc_s := replace (_type_esc_s, '.', '_');
        _type_esc_s := replace (_type_esc_s, '+', '_');

       ses_print (sprintf (
      '\n<param name="%s" type="%s" is_primitive="%d" is_array="%d" pltype="%s" signature="%s" soaptype="%s" reftype="%s" />',
	_name, _type_s, _is_primitive, _is_array,
        _type_esc_s,
        _type_s,
        cast (clr_type_to_schema_type (_type_s, _is_primitive, _is_array) as varchar), _reftype), ses);
       idx := idx + 1;
    }

  ses_print ('\n</parameters>', ses);
}
;

create procedure clr_describe_returns (inout ses any, in _type _Type)
{
  declare _type_s, _type_esc_s varchar;
  declare _is_primitive, _is_array, _plescape integer;

  _type_s := cast (_type.ToString () as varchar);
  _is_primitive := clr_type_is_primitive (_type_s);
  _is_array := if_array (_type_s);
  _type_esc_s := clr_type_to_pl_type (_type_s, _is_primitive, _is_array,  _plescape);
  _type_esc_s := replace (_type_esc_s, '.', '_');
  _type_esc_s := replace (_type_esc_s, '+', '_');

  ses_print (sprintf ('\n<returnType type="%s" is_primitive="%d" is_array="%d" pltype="%s" signature="%s" soaptype="%s" plescape="%d"/>',
     _type_s, _is_primitive, _is_array,
     _type_esc_s, _type_s,
     cast (clr_type_to_schema_type (_type_s, _is_primitive, _is_array) as varchar), _plescape), ses);
}
;

create procedure clr_type_is_primitive (in clr_type varchar)
{
  clr_type := cast (clr_type as varchar);

  if (clr_type = 'System.String') return 1;
  if (clr_type = 'System.Double') return 1;
  if (clr_type = 'System.Single') return 1;
  if (clr_type = 'System.Int32') return 1;
  if (clr_type = 'System.Boolean') return 1;
--
--   SQL TYPES
--
  if (clr_type = 'System.Data.SqlTypes.SqlDouble') return 1;

  return 0;
}
;

create procedure clr_type_to_pl_type (in clr_type varchar, in is_primitive int,
				      in is_array int, inout _plescape int)
returns varchar
{
  clr_type := cast (clr_type as varchar);
  _plescape := 0;

  if (is_array)
    return 'any';

  if (is_primitive)
    {
      if (clr_type = 'System.String') return 'varchar';
      if (clr_type = 'System.Double') return 'double precision';
      if (clr_type = 'System.Single') return 'real';
      if (clr_type = 'System.Int32') return 'integer';
      if (clr_type = 'System.Boolean') return 'smallint';
    }

  _plescape := 1;
  return clr_type;
}
;

create procedure clr_type_to_schema_type (in clr_type varchar, in is_primitive int, in is_array int)
{
  clr_type := cast (clr_type as varchar);

  if (is_array)
    return '';

  if (clr_type = 'System.String') return 'http://www.w3.org/2001/XMLSchema:string';
  if (clr_type = 'System.Double') return 'http://www.w3.org/2001/XMLSchema:double';
  if (clr_type = 'System.Single') return 'http://www.w3.org/2001/XMLSchema:long';
  if (clr_type = 'System.Int32') return 'http://www.w3.org/2001/XMLSchema:long';
  if (clr_type = 'System.Boolean') return 'http://www.w3.org/2001/XMLSchema:boolelan';

  return clr_type;
}
;

create procedure if_array (in clr_type varchar)
{
   if (strstr (clr_type, '[')) return 1;
   return 0;
}
;

create procedure ses_print (in _in any, inout ses any)
{
  http (_in, ses);
}
;

create procedure import_clr (in files any, in classes any, in _is_write_output integer := 0,
			     in unrestricted integer := 0, in _is_return_sql integer := 0)
{
  declare _xml, _xmlv any;
  declare pl, all_pl varchar;
  _xml := xml_tree_doc (clr_ref_import (files, classes, unrestricted));

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
--	  dbg_obj_print (clr_make_human_read (pl));
          if (_is_write_output)
            {
	      string_to_file (sprintf ('result%i.sql', inx),  clr_make_human_read (pl), -2);
	      string_to_file (sprintf ('result%i.xml', inx), cast (_xmlv_frag as varchar), -2);
            }
	  if (_is_return_sql)
	    all_pl := all_pl || pl;
	  else
	    exec (pl);
          inx := inx + 1;
        }
    }

  if (_is_return_sql)
    return  clr_make_human_read (all_pl);
}
;

create procedure clr_make_human_read (in _res varchar)
{
  _res := replace (_res, '    ', ' ');
  _res := replace (_res, '   ', ' ');
  _res := replace (_res, '  ', ' ');
  _res := replace (_res, '  ', ' ');
  _res := replace (_res, '  ', ' ');

  _res := replace (_res, '\t,', ',');
  _res := replace (_res, '\t ,', ',');
  _res := replace (_res, '\t(', '(');
  _res := replace (_res, '\t (', '(');
  _res := replace (_res, '\t)', '(');
  _res := replace (_res, '\t )', ')');
  _res := replace (_res, '\t)', '(');
  _res := replace (_res, '\t )', ')');
  _res := replace (_res, '\n,\n', ',\n');
  _res := replace (_res, '\n, \n', ',\n');
  _res := replace (_res, '\n,\n', ',\n');
  _res := replace (_res, '\n, \n', ',\n');
  _res := replace (_res, '\t ', '\t');
  _res := replace (_res, '\n ', '\n');
  _res := replace (_res, '\n,\n', ',\n');
  _res := replace (_res, '\n)\n', ')\n');
  _res := replace (_res, '\n)\n', ')\n');
  _res := replace (_res, '(\n', '(');
  _res := replace (_res, '\t)', '(');

  _res := replace (_res, '\n(', '(');
  _res := replace (_res, '\n)', ')');
  _res := replace (_res, '\t (', '(');

  _res := replace (_res, '\n\t\n', '\n');
  _res := replace (_res, '\n\t \n', '\n');
  _res := replace (_res, '\n\n', '\n');
  _res := replace (_res, '\n \n', '\n');

  _res := replace (_res, '(\t)', '()');
  _res := replace (_res, '(\n', '(');

  _res := replace (_res, 'METHOD\n\t', 'METHOD ');
  _res := replace (_res, ',STATIC', ',\n\tSTATIC ');
  _res := replace (_res, '\nexternal type', '\n\texternal type');
  _res := replace (_res, '\n\texternal name', ' external name');

  _res := replace (_res, '( \n', '(');
  _res := replace (_res, '(\n', '(');
  _res := replace (_res, '\n)', ')');
  _res := replace (_res, '\n,', ',');
  _res := replace (_res, ',\n"', ', "');
  _res := replace (_res, ',\n" ', ', "');
  _res := replace (_res, ',\n"\t', ', "');

  return _res;
}
;

--drop type "Virt_aspx_VirtHost";

create type "Virt_aspx_VirtHost"
language CLR external name 'virt_http/Virt_aspx.VirtHost'
UNRESTRICTED TEMPORARY
 STATIC METHOD
        "Call_aspx2" ("page" varchar external type 'System.String' ,
		      "physicalDir" varchar external type 'System.String',
		      "virtualDir" varchar external type 'System.String',
		      "Headers" varchar external type 'System.String',
		      "client_ip" varchar external type 'System.String',
		      "server_port" varchar external type 'System.String',
		      "localhost_name" varchar external type 'System.String',
		      "_req_line" varchar external type 'System.String',
		      "parameters" varchar external type 'System.String',
		      "http_root" varchar external type 'System.String',
		      "runtime_name" varchar external type 'System.String')
returns any
        external type 'System.String []'  external name 'Call_aspx2'

;

create procedure WS.WS.__http_handler_asmx (in full_name varchar, inout params any,
				      inout lines any, inout hdl_mode any)
{
   return WS.WS.__http_handler_aspx (full_name, params, lines, hdl_mode);
}
;

create procedure
aspx_get_host (in lines any)
{
  declare ret varchar;
  ret := http_request_header (lines, 'Host', null, sys_connected_server_address ());
  if (isstring (ret) and strchr (ret, ':') is null)
    {
      declare hp varchar;
      declare hpa any;
      hp := sys_connected_server_address ();
      hpa := split_and_decode (hp, 0, '\0\0:');
      ret := ret || ':' || hpa[1];
    }
  return ret;
}
;


create procedure WS.WS.__http_handler_aspx (in full_name varchar, inout params any,
				      inout lines any, inout hdl_mode any)
{
   declare _page varchar; -- the logical page URL
   declare _physicalDir varchar; -- the physicalDir
   declare _virtualDir varchar; -- the virtual dir
   declare _headers varchar; -- the headers
   declare _client_ip varchar; -- the IP of the client
   declare _server_port varchar; -- the port of the server
   declare _server_host varchar; -- the host of the server
   declare _req_line varchar; -- the request line
   declare _parameters varchar; -- the request parameters
   declare _http_root varchar; -- the http_root
   declare _runtime_name varchar; -- the runtime_name

   declare ret any;
   declare headers_out varchar;
   declare _mounted varchar;

   declare __idx integer;
   declare __pos integer;
   declare __temp integer;
   declare __server_address varchar;
   declare __temp_dir varchar;

   __temp_dir := '';
   _page := http_path();
   _mounted := http_map_get ('mounted');
   _physicalDir := concat (http_root(), _mounted);
   _http_root := http_root ();
   _runtime_name := clr_runtime_name ();
   if (hdl_mode is not NULL)
     {
        declare aspx_dir, full_path varchar;
        -- FIXME: this should be deleted when virt dir problem in mono is fixed
        --if (_runtime_name = 'Mono')
	--  __temp_dir := 'temp';
        --else
	  __temp_dir := aspx_get_temp_directory ();
        full_path := concat (http_root (), '/', __temp_dir);
	_http_root := full_path;
        --dbg_obj_print ('hdl_mode=', hdl_mode);
        --dbg_obj_print ('full_path=', full_path);
        aspx_copy_dav_dir_to_file_system (hdl_mode, full_path, aspx_dir);
        --dbg_obj_print ('aspx_dir=', aspx_dir);
        _physicalDir := concat (full_path, substring (_mounted, 5, length (_mounted)));
     }
   __temp := _physicalDir[length (_physicalDir) - 1];
   if (__temp = ascii ('/') or __temp = ascii ('\\'))
     _physicalDir := subseq (_physicalDir, 0, length (_physicalDir) - 1);

   _physicalDir := replace (_physicalDir, '//', '/');

   _virtualDir := http_map_get ('domain');
--   _page := replace (_page, _virtualDir, ''); -- trim off the virtual dir part
--   if (_page[0] = ascii ('/') or _page[0] = ascii ('\\'))
--     _page := subseq (_page, 1);
   _client_ip := http_client_ip ();
   __server_address := aspx_get_host (lines);
   _server_host := subseq (__server_address, 0, strchr (__server_address, ':'));
   _server_port := subseq (__server_address, strchr (__server_address, ':') + 1);
   _req_line := lines[0];

   __idx := 2;
   _headers := lines[1];
   while (__idx < length (lines))
     {
        _headers := concat (_headers, ';;', lines[__idx]);
        __idx := __idx + 1;
     }
   _headers := replace (_headers, ' ', '');
   _headers := concat (_headers, ';;');

   _parameters := '';
   if (__tag (params) = 185)
     _parameters := string_output_string (params);

   --dbg_obj_print ('*************** REQ ****************');
   --dbg_obj_print ('_page=', _page);
   --dbg_obj_print ('_physicalDir=', _physicalDir);
   --dbg_obj_print ('_virtualDir=', _virtualDir);
   --dbg_obj_print ('_headers=', _headers);
   --dbg_obj_print ('_client_ip=', _client_ip);
   --dbg_obj_print ('_server_port=', _server_port);
   --dbg_obj_print ('_server_host=', _server_host);
   --dbg_obj_print ('_req_line=', _req_line);
   --dbg_obj_print ('_parameters=', _parameters);
   --dbg_obj_print ('*************** REQ END ************');
   --return '';

   -- FIXME: this should be deleted when virt dir problem in mono is fixed
   --if (_runtime_name = 'Mono')
   --  {
   --    _http_root := http_root ();
   --    if (__temp_dir <> '')
   --      {
   --        declare _new_page varchar;
   --        _new_page := '/' || __temp_dir || _page;
   --        _req_line := replace (_req_line, _page, _new_page);
   --        _page := _new_page;
   --      }
   --  }

   ret := "Virt_aspx_VirtHost"::Call_aspx2 (
              _page,
              _physicalDir,
              _virtualDir,
              _headers,
              _client_ip,
              _server_port,
              _server_host,
              _req_line,
              _parameters,
	      _http_root,
	      _runtime_name);

   headers_out := replace (cast (ret [1] as varchar), ';;', '\r\n');

   http_header (headers_out);
   http_request_status (concat ('HTTP/1.1 ', cast (ret [2] as varchar)));

   return cast (ret [0] as varchar);
}
;


create procedure
aspx_sys_mkdir (in path varchar)
{
  declare temp any;
  declare idx integer;

--  if (sys_stat('st_build_opsys_id') = 'Win32')
--    {
--       sys_mkdir (path);
--       return;
--    }

  path := subseq(path, length (http_root()));
  temp := split_and_decode (path, 0, '///');
  idx := 0;
  path := http_root();

  while (idx < length (temp) - 1)
    {
       path := concat (path, temp[idx], '/');
       sys_mkdir (path);
       idx := idx + 1;
    }
}
;


create procedure
aspx_copy_dav_dir_to_file_system (in dav_path varchar, in abs_path varchar, out path varchar)
{
  declare dir_name varchar;
  declare dav_rel_path  varchar;
  declare full_path varchar;
  declare create_dir_name varchar;
  declare pos integer;

  aspx_sys_mkdir (abs_path);

  pos := strstr (dav_path, '/DAV/');
  path := subseq (dav_path, pos + length ('/DAV/'));
  pos := strrchr (path, '/') + 1;
  dir_name := "LEFT" (path, pos);
  dav_rel_path := concat ('/DAV/', dir_name);

  for (select subseq (RES_FULL_PATH, length (dav_rel_path) + 1) as local_dav_path,
      RES_CONTENT, RES_NAME, RES_MOD_TIME from WS.WS.SYS_DAV_RES
      where RES_FULL_PATH like concat (dav_rel_path, '%')) do
    {
         full_path := concat (abs_path, '/', dir_name, '/', local_dav_path);
         create_dir_name := "LEFT" (full_path, length (full_path) - length (RES_NAME));
         --dbg_printf ('making dir %s\n', create_dir_name);
         aspx_sys_mkdir (create_dir_name);

	 declare x, y any;
	 x := cast (registry_get (full_path) as varchar);
	 y := cast (file_stat (full_path) as varchar);
         if (x <> y || cast (RES_MOD_TIME as varchar))
           {
--            dbg_printf ('copying %s to %s\n', local_dav_path, full_path);
              string_to_file (full_path, blob_to_string (RES_CONTENT), -2);
              registry_set (full_path, cast (file_stat (full_path) as varchar) || cast (RES_MOD_TIME as varchar));
           }
    }
}
;


create procedure unimport_clr (in files any, in classes any, in _is_write_output integer := 0)
{
  declare _xml, _xmlv any;
  declare pl varchar;
  _xml := xml_tree_doc (clr_ref_import (files, classes));

  _xmlv := xpath_eval ('/classes/class/@pl_type', _xml, 0);

  if (isarray (_xmlv))
    {
      declare inx integer;
      inx := 0;
      declare udts any;

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
	          'unimport_clr is to drop an user defined type %s that is a supertype of %s. Please drop the subtype(s) first.', _xml, _xml_child));
	    }
	}
      while (inx < length (_xmlv))
	{
          pl := sprintf ('DROP TYPE "%I"', cast (_xmlv[inx] as varchar));
          if (_is_write_output)
            {
	      string_to_file (sprintf ('result%i.sql', inx),  clr_make_human_read (pl), -2);
              if (_is_write_output = 2)
                return  clr_make_human_read (pl);
            }
          exec (pl);
	  inx := inx + 1;
	}
    }
}
;


create procedure import_get_types_int (in sel_name varchar)
{
  declare asm Assembly;
  declare _type _Type;
  declare types, ret any;
  declare esc_string varchar;
  declare idx integer;

  ret := vector ();

  if ((strstr (sel_name, '.dll') is not NULL) or
      (strstr (sel_name, '.exe') is not NULL))
    {

       if (strstr (sel_name, '/') is not NULL)
     asm := Assembly::LoadFrom(sel_name);
       else
     {
       sel_name := replace (sel_name, '.dll', '');
       sel_name := replace (sel_name, '.exe', '');
       asm := Assembly::Load(sel_name);
     }

       types := asm.GetTypes ();
       idx := 0;

       if (not isarray(types))
     types := vector (types);

       while (idx < length (types))
     {
        _type := types[idx];
        esc_string := _type.ToString ();
        esc_string := cast (esc_string as varchar);
        esc_string := replace (esc_string, '.', '_');
        ret := vector_concat (ret, vector (esc_string));
        idx := idx + 1;
     }

       return ret;
    }
  else if (strstr (sel_name, '.class') is not NULL)
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

--create procedure init_perm_on_start_up ()
--{
--   for (select VAC_REAL_NAME from DB.DBA.CLR_VAC where VAC_PERM_SET = 1) do
--      {
--	__add_assem_to_sec_hash (VAC_REAL_NAME);
--      }
--}
--;

--init_perm_on_start_up ()
--;


create procedure import_clr_grant_to_public (in files any, in classes any)
{
  declare _xml, _xmlv any;
  declare pl varchar;
  _xml := xml_tree_doc (clr_ref_import (files, classes));

  _xmlv := xpath_eval ('/classes/class/@pl_type', _xml, 0);

  if (isarray (_xmlv))
    {
      declare inx integer;
      inx := 0;

      while (inx < length (_xmlv))
	{
          pl := sprintf ('grant execute on "%I" to public', cast (_xmlv[inx] as varchar));
          exec (pl);
	  inx := inx + 1;
	}
    }
}
;

create procedure import_get_assem_names
(inout assem_name varchar, inout full_name varchar, inout short_name varchar)
{
  declare asm Assembly;
  declare load_name varchar;

  if (sys_stat('st_build_opsys_id') <> 'Win32')
    assem_name := replace (assem_name, '\\', '/');

  if ((strstr (assem_name, '\\') is not NULL) or (strstr (assem_name, '/') is not NULL))
     asm := Assembly::LoadFrom(assem_name);
  else
    {
-- XXX FIXME Assembly::Load must replace with signal !!! file_to_string will be fail.

	load_name := replace (assem_name, '.dll', '');
	load_name := replace (load_name, '.exe', '');
	asm := Assembly::Load(load_name);
    }

  full_name := cast (asm.FullName as varchar);

  if (strstr (full_name, ',') is not NULL)
    {
	short_name := "LEFT" (full_name, strstr (full_name, ','));
    }
}
;
