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
use PUMP
;


--drop procedure html_retrieve_tables;
create procedure "PUMP"."DBA"."HTML_RETRIEVE_TABLES" (	inout arr any )
{
  declare str varchar;
  str := "PUMP"."DBA"."DBPUMP_RUN_COMPONENT" (arr,'retrieve_tables','*');
  if (str is null)
    return '';
  return str;
}
;


create procedure "PUMP"."DBA"."HTML_RETRIEVE_QUALIFIERS_VIA_PLSQL" ( in arr any )
{
  declare str, s varchar;
  str := '%=None&custom=Advanced';
whenever not found goto fin;

  for (select distinct name_part (KEY_TABLE, 0, 'DB') as qual from DB.DBA.SYS_KEYS) do
    {
      str := concat (str, '&', qual, '=', qual);
    }
fin:
--  dbg_obj_print(str);
  return str;
}
;


create procedure "PUMP"."DBA"."HTML_RETRIEVE_TABLES_VIA_PLSQL" ( in arr any, in out_type integer := 1 )
{

  declare qual, qm, om, tm varchar;
  qual := "PUMP"."DBA"."__GET_KEYWORD" ('selected_qualifier',arr,'');
  qm := "PUMP"."DBA"."__GET_KEYWORD" ('qualifier_mask',arr,'');
  om := "PUMP"."DBA"."__GET_KEYWORD" ('owner_mask',arr,'');
  tm := "PUMP"."DBA"."__GET_KEYWORD" ('tabname',arr,'');
  declare custom_flag varchar;
  custom_flag := "PUMP"."DBA"."__GET_KEYWORD" ('custom_qual',arr,'');


  declare str, s varchar;
  declare first integer;

  first := 1;
  str := '';
--  dbg_obj_print(qual, qm, om, tm, custom_flag);
whenever not found goto fin;
  if (equ(custom_flag,'1'))
  for (select 
	name_part("KEY_TABLE",0) as t_qualifier,
	name_part("KEY_TABLE",1) as t_owner,
	name_part("KEY_TABLE",2) as t_name,
	table_type("KEY_TABLE")  as t_type
	  from DB.DBA.SYS_KEYS 
	where
	  __any_grants ("KEY_TABLE") and 
	  name_part("KEY_TABLE",0) like qm and
	  name_part("KEY_TABLE",1) like om and
	  name_part("KEY_TABLE",2) like tm and
	  table_type("KEY_TABLE") = 'TABLE' and
	  KEY_IS_MAIN = 1 and
	  KEY_MIGRATE_TO is NULL 
	  order by "KEY_TABLE")
        do
	{
	  if (not first)
	    {
	      if (out_type = 1)
 	        str := concat (str, '&');
	      else if (out_type = 2)
 	        str := concat (str, '@');
	    }
	  s := concat (t_qualifier, '.', t_owner, '.', t_name);
	  if (out_type = 1)
	    str := concat (str, s, '=', s);
	  else if (out_type = 2)
	    str := concat (str, s);
	  first := 0;
	}
  else
  for (select 
	name_part("KEY_TABLE",0) as t_qualifier,
	name_part("KEY_TABLE",1) as t_owner,
	name_part("KEY_TABLE",2) as t_name,
	table_type("KEY_TABLE")  as t_type
	  from DB.DBA.SYS_KEYS 
	where
	  __any_grants ("KEY_TABLE") and 
	  name_part("KEY_TABLE",0) like qual and
	  table_type("KEY_TABLE") = 'TABLE' and
	  KEY_IS_MAIN = 1 and
	  KEY_MIGRATE_TO is NULL 
	  order by "KEY_TABLE")
        do
	{
	  if (not first)
	    {
	      if (out_type = 1)
 	        str := concat (str, '&');
	      else if (out_type = 2)
 	        str := concat (str, '@');
	    }
	  s := concat (t_qualifier, '.', t_owner, '.', t_name);
	  if (out_type = 1)
	    str := concat (str, s, '=', s);
	  else if (out_type = 2)
	    str := concat (str, s);
	  first := 0;
	}
fin:
  return str;
}
;

create procedure "PUMP"."DBA"."HTML_SELECT_LOCAL_TABLES_OUT" (  in arr any )
{
  http('<table CLASS="statdata" border=0 rules=none><tr>');
  http('<td align=center>');
  "PUMP"."DBA"."HTML_SELECT_OUT" (arr, 'st', 'Available Tables', "PUMP"."DBA"."HTML_RETRIEVE_TABLES_VIA_PLSQL" (arr), NULL, 'size=10 multiple', NULL); 
  http('</td></tr>');
  http('<tr><td align=center CLASS="statlist">');
  "PUMP"."DBA"."HTML_BUTTON_OUT" (arr, '', 'Select All', 'select_all_local_tables();'
		, NULL, ' style=\"width: 1in\"');
  "PUMP"."DBA"."HTML_BUTTON_OUT" (arr, '', 'Deselect All', '
		for (i=0;;i++)
		{
			if (this.form.st_value.options[i]==null)
				break;
			if (this.form.st_value.options[i].selected)
				this.form.st_value.options[i].selected=false;
		}
		  ', NULL, ' style=\"width: 1in\"');
  http ('</td>');
  http ('</tr>');
  http ('</table>\n');
  http ('<script> 
	function pack_tables()
	{ 
		var out=\'\', j=0;
		for (i=0;;i++)
		{
			if (document.forms[0].st_value.options[i]==null)
				break;
			if (document.forms[0].st_value.options[i] && document.forms[0].st_value.options[i].selected)
			{
				if (j) out += \'@\';
				else j=1;
				out += document.forms[0].st_value.options[i].value;
			}
		}
		return out;
	}
	function select_all_local_tables ()
	{
		for (i=0;;i++)
		{
			if (document.forms[0].st_value.options[i]==null)
				break;
			if (!document.forms[0].st_value.options[i].selected)
				document.forms[0].st_value.options[i].selected=true;
		}
	}');
  declare qual varchar;
  qual := "PUMP"."DBA"."__GET_KEYWORD" ('selected_qualifier',arr,'');
  if (neq (qual , '%'))
    http ('select_all_local_tables ();');
  http ('</script>');
}
;


create procedure "PUMP"."DBA"."HTML_SELECT_QUALIFIER_FILTER_OUT" (  in arr any )
{
  http('<table class="genlist" border="0" cellpadding="0">');
  http('<tr><td class="genhead">');
  http('<table width=100% border=0><tr><td align=left  class="genhead">');
  "PUMP"."DBA"."__CHECK_HELP" ('qualifier_mask', sprintf('&nbsp;%s&nbsp;', 'Filter')); 
  http('</td><td align=right>');
  "PUMP"."DBA"."HTML_BUTTON_OUT" (arr, '', 'Advanced', '
	this.form.action=\'dump_advanced.vsp\';this.form.submit();
		  ', NULL, NULL);
  http('</td></tr></table>');
  http('</td></tr>');
  http('<tr><td CLASS="statdata">');


  "PUMP"."DBA"."HTML_SELECT_OUT" (arr, 'qualifier_mask', NULL, "PUMP"."DBA"."HTML_RETRIEVE_QUALIFIERS_VIA_PLSQL" (arr), NULL, NULL, NULL, 20, 'this.form.submit();'); 
  http('</td><td align=center>');
  http('</td>');
  http('</tr>');
  http('</table>\n');
}
;


create procedure "PUMP"."DBA"."HTML_SELECT_DUMP_TYPE_OUT" (  in arr any )
{
  http('<table class="genlist" border="0" cellpadding="0">');
  http('<tr><td class="genhead">');
  "PUMP"."DBA"."__CHECK_HELP" ('text_flag', sprintf('&nbsp;%s&nbsp;', 'Dump Format')); 
  http('</td></tr>');
  http('<tr><td CLASS="statdata">');
  "PUMP"."DBA"."HTML_RADIO_OUT" (arr, 'text_flag', 'SQL=SQL&Binary=Binary', NULL, NULL, NULL); 
  http('</td></tr></table>');
}
;

--drop procedure html_choice_tables;
create procedure "PUMP"."DBA"."HTML_CHOICE_TABLES" (	inout arr any )
{
  declare str varchar;
  str := "PUMP"."DBA"."DBPUMP_RUN_COMPONENT" (arr,'choice_tables','*');
  if (str is null)
    return '';
--dbg_obj_print(str);
  return str;
}
;

--drop procedure html_select_tables_out;
create procedure "PUMP"."DBA"."HTML_SELECT_TABLES_OUT" (  in arr any )
{
--  __check_help ('choice_tables');
  http('<table CLASS="statdata" border=0 rules=none');
--  __check_title ('choice_tables');
  http('><tr>');
  http('<td rowspan=4  align=center>');
  declare exstr varchar;
  exstr := "PUMP"."DBA"."HTML_CHOICE_TABLES" (arr);
  "PUMP"."DBA"."HTML_SELECT_OUT" (arr, 'at', 'Available Tables', "PUMP"."DBA"."HTML_RETRIEVE_TABLES_VIA_PLSQL" (arr), NULL, 'size=10 multiple' ,exstr); 
  http('</td>');
  http('<td align=center><br>');
  "PUMP"."DBA"."HTML_BUTTON_OUT" (arr, '', ' > ', '
	var found=1;
	while (found)
	{
		found=0;
		for (i=0;;i++)
		{
			if (this.form.at.options[i]==null)
				break;
			if (this.form.at.options[i].selected)
			{
				var o=this.form.at.options[i];
				AddItemToSelect(this.form.choice_tables.options, o);
				this.form.at.options[i]=null;
				i--;
				found=1;
			}
		}
	}
		  ', NULL, NULL);
  http('</td>');
  http('<td rowspan=4  align=center>');
  "PUMP"."DBA"."HTML_SELECT_OUT" (arr, 'choice_tables', 'Selected Tables', exstr, NULL, 'size=10  multiple ',NULL ); 
  http('<script language=JavaScript>
		function ChoiceTablesSelect()
		{
			for (i=0;;i++)
			{
				if (document.forms[0].choice_tables.options[i]==null)
					break;
				document.forms[0].choice_tables.options[i].selected=true;
			}	
		}
		ChoiceTablesSelect();	
	</script>');
  http('</td>');
  http('</tr>');
  http('<tr>');
  http('<td align=center>');
  "PUMP"."DBA"."HTML_BUTTON_OUT" (arr, '', '>>', '
	for (;;)
	{
		var o=this.form.at.options[0];
		if (o==null)
		  break;
		AddItemToSelect(this.form.choice_tables.options, o);
		this.form.at.options[0]=null;
	}
  		  ', NULL, NULL);
  http('</td>');
  http('</tr>');
  http('<tr>');
  http('<td align=center>');
  "PUMP"."DBA"."HTML_BUTTON_OUT" (arr, '', '<<', '
	for (;;)
	{
		var o=this.form.choice_tables.options[0];
		if (o==null)
		  break;
		AddItemToSelect(this.form.at.options, o);
		this.form.choice_tables.options[0]=null;
	}
		  ', NULL, NULL);
  http('</td>');
  http('</tr>');
  http('<tr>');
  http('<td align=center>');
  "PUMP"."DBA"."HTML_BUTTON_OUT" (arr, '', ' < ', '
	var found=1;
	while (found)
	{
		found=0;
		for (i=0;;i++)
		{
			if (this.form.choice_tables.options[i]==null)
				break;
			if (this.form.choice_tables.options[i].selected)
			{
				var o=this.form.choice_tables.options[i];
				AddItemToSelect(this.form.at.options, o);
				this.form.choice_tables.options[i]=null;
				i--;
				found=1;
			}
		}
	}
		  ', NULL, NULL);
  http('</td>');
  http('</tr>');
  http('</table>\n');
}
;

--drop procedure dump_tables_and_pars_retrieve;
create procedure "PUMP"."DBA"."DUMP_TABLES_AND_PARS_RETRIEVE" ( inout pars any )
{
  declare n integer;
  declare str varchar;
  declare outarr any;

--  checkpoint;

--  dbg_obj_print(pars);
  str := "PUMP"."DBA"."DBPUMP_RUN_COMPONENT" (pars,'dump_tables','*');
  outarr := split_and_decode(str,0);
--  n := length(outarr);
  return outarr;
}
;

--drop procedure dump_schema_and_pars_retrieve;
create procedure "PUMP"."DBA"."DUMP_SCHEMA_AND_PARS_RETRIEVE" ( inout pars any )
{
  declare n integer;
  declare str varchar;
  declare outarr any;

--  checkpoint;

  str := "PUMP"."DBA"."DBPUMP_RUN_COMPONENT" (pars,'dump_schema','*');
  outarr := split_and_decode(str,0);
--  dbg_obj_print(outarr);
--  n := length(outarr);
  return outarr;
}
;


--drop procedure restore_tables_and_pars_retrieve;
create procedure "PUMP"."DBA"."RESTORE_TABLES_AND_PARS_RETRIEVE" ( inout pars any )
{
  declare n integer;
  declare str varchar;
  declare outarr any;

--  checkpoint;

  str := "PUMP"."DBA"."DBPUMP_RUN_COMPONENT" (pars,'restore_tables','*');
  outarr := split_and_decode(str,0);
--  dbg_obj_print(outarr);
--  n := length(outarr);
  return outarr;
}
;


--drop procedure restore_schema_and_pars_retrieve;
create procedure "PUMP"."DBA"."RESTORE_SCHEMA_AND_PARS_RETRIEVE" ( inout pars any )
{
  declare n integer;
  declare str varchar;
  declare outarr any;

--  checkpoint;

  str := "PUMP"."DBA"."DBPUMP_RUN_COMPONENT" (pars,'restore_schema','*');
  outarr := split_and_decode(str,0);
--  dbg_obj_print(outarr);
--  n := length(outarr);
  return outarr;
}
;


create procedure "PUMP"."DBA"."CHK_ST_VALUE" ( inout arr any, in pars any )
{
  declare s any ;
  s := string_output();
  declare name  varchar;
  declare i, n integer;
  n := length(pars);
  i := 0;
  while (i<n)
    {
      name := aref(pars,i);
      if (equ (name, 'st_value'))
	{
	  if (i)
	    http ('@', s);
	  http (aref (pars, i + 1), s);
	}
      i := i + 2;
    }
  "PUMP"."DBA"."CHANGE_VAL" (arr, 'choice_sav', string_output_string(s));
}
;

create procedure "DB"."DBA"."BACKUP_ALL_VIA_DBPUMP" (	
												in username varchar,
												in passwd varchar,
												in datasource varchar,
												in dump_path varchar,
												in dump_dir varchar  ) returns varchar
{
  declare pars, res any;
  pars:= null;

  "PUMP"."DBA"."CHANGE_VAL" (pars, 'user', username);
  "PUMP"."DBA"."CHANGE_VAL" (pars, 'password', passwd);
  "PUMP"."DBA"."CHANGE_VAL" (pars, 'datasource', datasource);
  "PUMP"."DBA"."CHANGE_VAL" (pars, 'dump_path', dump_path);
  "PUMP"."DBA"."CHANGE_VAL" (pars, 'dump_dir', dump_dir);
  "PUMP"."DBA"."CHANGE_VAL" (pars, 'choice_sav', '');

  "PUMP"."DBA"."CHANGE_VAL" (pars, 'table_defs', 'on');
  "PUMP"."DBA"."CHANGE_VAL" (pars, 'triggers', 'on');
  "PUMP"."DBA"."CHANGE_VAL" (pars, 'stored_procs', 'on');
  "PUMP"."DBA"."CHANGE_VAL" (pars, 'constraints', 'on');
  "PUMP"."DBA"."CHANGE_VAL" (pars, 'fkconstraints', 'on');
  "PUMP"."DBA"."CHANGE_VAL" (pars, 'views', 'on');
  "PUMP"."DBA"."CHANGE_VAL" (pars, 'users', 'on');
  "PUMP"."DBA"."CHANGE_VAL" (pars, 'grants', 'on');

  "PUMP"."DBA"."CHANGE_VAL" (pars, 'custom_qual', '1');
  "PUMP"."DBA"."CHANGE_VAL" (pars, 'qualifier_mask', '%');
  "PUMP"."DBA"."CHANGE_VAL" (pars, 'owner_mask', '%');
  "PUMP"."DBA"."CHANGE_VAL" (pars, 'tabname', '%');

  "PUMP"."DBA"."CHANGE_VAL" (pars, 'choice_sav',  "PUMP"."DBA"."HTML_RETRIEVE_TABLES_VIA_PLSQL" (pars, 2));
dbg_obj_print (pars);

  res := "PUMP"."DBA"."DUMP_TABLES_AND_PARS_RETRIEVE" (pars);
  return get_keyword ('result_txt', res, '');
}
;


create procedure "DB"."DBA"."BACKUP_SCHEMA_VIA_DBPUMP" (
												in username varchar,
												in passwd varchar,
												in datasource varchar,
												in qualifier varchar,
												in dump_path varchar,
												in dump_dir varchar  ) returns varchar
{
  declare pars, res any;
  pars:= null;

  "PUMP"."DBA"."CHANGE_VAL" (pars, 'user', username);
  "PUMP"."DBA"."CHANGE_VAL" (pars, 'password', passwd);
  "PUMP"."DBA"."CHANGE_VAL" (pars, 'datasource', datasource);
  "PUMP"."DBA"."CHANGE_VAL" (pars, 'dump_path', dump_path);
  "PUMP"."DBA"."CHANGE_VAL" (pars, 'dump_dir', dump_dir);
  "PUMP"."DBA"."CHANGE_VAL" (pars, 'choice_sav', '');
  "PUMP"."DBA"."CHANGE_VAL" (pars, 'selected_qualifier', qualifier);

  "PUMP"."DBA"."CHANGE_VAL" (pars, 'table_defs', 'on');
  "PUMP"."DBA"."CHANGE_VAL" (pars, 'triggers', 'on');
  "PUMP"."DBA"."CHANGE_VAL" (pars, 'stored_procs', 'on');
  "PUMP"."DBA"."CHANGE_VAL" (pars, 'constraints', 'on');
  "PUMP"."DBA"."CHANGE_VAL" (pars, 'fkconstraints', 'on');
  "PUMP"."DBA"."CHANGE_VAL" (pars, 'views', 'on');
  "PUMP"."DBA"."CHANGE_VAL" (pars, 'users', 'on');
  "PUMP"."DBA"."CHANGE_VAL" (pars, 'grants', 'on');

  "PUMP"."DBA"."CHANGE_VAL" (pars, 'choice_sav',  "PUMP"."DBA"."HTML_RETRIEVE_TABLES_VIA_PLSQL" (pars, 2));
dbg_obj_print (pars);
  res := "PUMP"."DBA"."DUMP_TABLES_AND_PARS_RETRIEVE" (pars);
  return get_keyword ('result_txt', res, '');
}
;


create procedure "DB"."DBA"."RESTORE_DBPUMP'S_FOLDER" (
												in username varchar,
												in passwd varchar,
												in datasource varchar,
												in dump_path varchar,
												in dump_dir varchar  ) returns varchar
{
  declare pars, res any;
  pars:= null;

  "PUMP"."DBA"."CHANGE_VAL" (pars, 'user', username);
  "PUMP"."DBA"."CHANGE_VAL" (pars, 'password', passwd);
  "PUMP"."DBA"."CHANGE_VAL" (pars, 'datasource', datasource);
  "PUMP"."DBA"."CHANGE_VAL" (pars, 'dump_path', dump_path);
  "PUMP"."DBA"."CHANGE_VAL" (pars, 'dump_dir', dump_dir);

  res := "PUMP"."DBA"."RESTORE_TABLES_AND_PARS_RETRIEVE" (pars);
  return get_keyword ('result_txt', res, '');
}
;

