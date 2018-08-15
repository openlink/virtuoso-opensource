--
--  $Id$
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2018 OpenLink Software
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


--drop procedure html_choice_rpath;
create procedure "PUMP"."DBA"."HTML_CHOICE_RPATH" (	inout arr any )
{
  declare str varchar;
  str := "PUMP"."DBA"."DBPUMP_RUN_COMPONENT" (arr,'choice_rpath','./backup', 0);
  if (str is null)
    return '';
  return str;
}
;

--drop procedure html_choice_rdir;
create procedure "PUMP"."DBA"."HTML_CHOICE_RDIR" (	inout arr any )
{
  declare str varchar;
--  declare exstr varchar;
--  exstr := html_choice_tables(arr);
  str := "PUMP"."DBA"."DBPUMP_RUN_COMPONENT" (arr,'choice_rdir','./backup', 0);
  if (str is null)
    return '';
  return str;
}
;

create procedure "PUMP"."DBA"."HTML_CHOICE_RSCHEMA" (	inout arr any )
{
  declare str varchar;
  str := "PUMP"."DBA"."DBPUMP_RUN_COMPONENT" (arr,'choice_rschema','./backup', 0);

  if (str is null)
    return '';
  return str;
}
;



--drop procedure rpath_for_dump_schema_out;
create procedure "PUMP"."DBA"."RPATH_FOR_DUMP_SCHEMA_OUT" (inout arr any,
						in class varchar ,
						in dop varchar )
{
  http('<table><tr><td>');
  "PUMP"."DBA"."HTML_SELECT_OUT" (arr, 'rpath', 'Remote Path', "PUMP"."DBA"."HTML_CHOICE_RPATH" (arr), NULL, ' size=5 ondblclick=\'this.form.submit();\' ', NULL, 20, 'this.form.dump_name.value=this.value;');
  http('</td></tr><tr><td align=center>');
  "PUMP"."DBA"."HTML_EDIT_OUT"(arr, 'dump_name', 'Dump Name:', './backup', NULL, NULL);
  http('</td></tr></table>');
}
;


--drop procedure rpath_for_dump_tables_out;
create procedure "PUMP"."DBA"."RPATH_FOR_DUMP_TABLES_OUT" (inout arr any,
						in class varchar ,
						in dop varchar )
{
  http('<table CLASS="statdata" border=0 rules=none><tr><td>');
  "PUMP"."DBA"."HTML_SELECT_OUT" (arr, 'rpath', 'Remote Path', "PUMP"."DBA"."HTML_CHOICE_RPATH" (arr), NULL, ' size=5 ondblclick=\'if (ChoiceTablesSelect!=null) ChoiceTablesSelect();this.form.submit();\' ', NULL, 20, 'this.form.dump_name.value=this.form.rpath.options[this.form.rpath.options.selectedIndex].value;');
  http('</td><td>');
  http('&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;');
  http('</td><td>');
  "PUMP"."DBA"."HTML_SELECT_OUT" (arr, '_choice_sav', 'Dir Content', "PUMP"."DBA"."HTML_CHOICE_RDIR" (arr), NULL, ' MULTIPLE size=5 ', NULL);
  http('</td></tr><tr><td colspan=2 align=center><font size=3>');
  "PUMP"."DBA"."HTML_EDIT_OUT" (arr, 'dump_name', 'Current Folder:', './backup', NULL, NULL);
  http('</font></td></tr></table>');
}
;

--drop procedure rpath_for_restore_tables_out;
create procedure "PUMP"."DBA"."RPATH_FOR_RESTORE_TABLES_OUT" (	inout arr any,
						in class varchar ,
						in dop varchar )
{
  http('<table CLASS="statdata" border=0 rules=none><tr><td>');
  "PUMP"."DBA"."HTML_SELECT_OUT" (arr, 'rpath', 'Remote Path', "PUMP"."DBA"."HTML_CHOICE_RPATH" (arr), NULL, ' size=5 ondblclick=\'this.form.submit();\' ', NULL, 20, 'this.form.dump_name.value=this.form.rpath.options[this.form.rpath.options.selectedIndex].value');
  http('</td><td>');
  http('&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;');
  http('</td><td>');
  "PUMP"."DBA"."HTML_SELECT_OUT" (arr, 'choice_sav', 'Dir Content', "PUMP"."DBA"."HTML_CHOICE_RDIR" (arr), NULL, ' MULTIPLE size=5 ', NULL);
  http('</td></tr><tr><td colspan=2 align=center ><font size=3>');
  "PUMP"."DBA"."HTML_EDIT_OUT" (arr, 'dump_name', 'Current Folder:', './backup', NULL, NULL);
  http('</font></td></tr></table>');
}
;

--drop procedure get_schema_comment_and_pars_retrieve;
create procedure "PUMP"."DBA"."GET_SCHEMA_COMMENT_AND_PARS_RETRIEVE" ( inout arr any )
{
  declare n integer;
  declare str varchar;
  declare outarr any;

--  checkpoint;

  outarr := "PUMP"."DBA"."TRY_CONNECT_AND_PARS_RETRIEVE" ( arr );
  if (outarr is null or neq (get_keyword ('connected_flag', outarr, ''), 'true'))
    http('<script>document.location.href="select_datasource.vsp";</script>');

  str := "PUMP"."DBA"."DBPUMP_RUN_COMPONENT" (arr,'get_schema_comment','*', 0);
  outarr := split_and_decode(str,0);
--  dbg_obj_print(outarr);
--  n := length(outarr);
  return outarr;
}
;

--drop procedure get_schema_comment_and_pars_retrieve;
create procedure "PUMP"."DBA"."GET_SCHEMA_COMMENT" ( inout arr any )
{
  declare n integer;
  declare str varchar;
  declare outarr any;

  str := "PUMP"."DBA"."DBPUMP_RUN_COMPONENT" (arr,'get_schema_comment','*', 0);
  outarr := split_and_decode(str,0);
--  dbg_obj_print(outarr);
--  n := length(outarr);
  return outarr;
}
;

create procedure "PUMP"."DBA"."COMMON_RPATH_FOR_DUMP_OUT" (	inout arr any,
						in class varchar ,
						in dop varchar )
{
  http ('<table><tr><td>');

  http('<table><tr><td colspan=2>');
  "PUMP"."DBA"."HTML_SELECT_OUT" (arr, 'rpath', 'Directory Listing', "PUMP"."DBA"."HTML_CHOICE_RPATH" (arr), NULL, ' size=5 ', NULL, 30, 'this.form.dump_path.value=this.value;');
  http('</td></tr>');

  http ('<tr><td align=center CLASS=\"statlisthead\">');
  "PUMP"."DBA"."__CHECK_HELP" ('dump_path', 'Current Directory:');
  http ('</td>');
  http ('<td CLASS=\"statlist\" align=center>');
  "PUMP"."DBA"."HTML_EDIT_OUT"(arr, 'dump_path', NULL, './backup', NULL, ' size=20');
  http('</td></tr>');

  http ('<tr><td align=center CLASS=\"statlist\" colspan=2>');
  "PUMP"."DBA"."HTML_BUTTON_OUT" (arr, '', 'Change Dir', 'this.form.submit();', NULL, ' style=\"width: 1in\"');
  http('</td></tr>');

  http('</table>');

  http ('</td><td>');

  http('<table><tr><td colspan=2>');
  "PUMP"."DBA"."HTML_SELECT_OUT" (arr, 'dump_dir', 'Dir Content', "PUMP"."DBA"."HTML_CHOICE_RSCHEMA" (arr), NULL, ' size=5 ', NULL, 30);
  http('</td></tr>');

  http ('<tr><td align=center CLASS=\"statlisthead\">');
  "PUMP"."DBA"."__CHECK_HELP" ('show_content', 'Directory Listing:');
  http ('</td>');
  http ('<td CLASS=\"statlist\" align=center>');
  "PUMP"."DBA"."HTML_SELECT_OUT" (arr,  'show_content', NULL, '4=Data&2=Schema&6=Both', NULL,  NULL, NULL, 10, 'this.form.submit();'); -- due to defines in components.c
  http('</td></tr>');

  http ('<tr><td align=center CLASS=\"statlist\" colspan=2>');
  "PUMP"."DBA"."HTML_BUTTON_OUT" (arr, '', 'Show Manifest', 'var w=window.open(\'manifest.vsp?dump_path=\'+this.form.dump_path.value+\'&dump_dir=\'+this.form.dump_dir_value.options[this.form.dump_dir_value.selectedIndex].value,\'helpWindow\',\'scrollbars=1, height=300, width=400, resizable=1`\');w.focus();', NULL, ' style=\"width: 1in\"');
  http('</td></tr>');

  http('</table>');
--  http('<script>
--	function select_all()
--	{
--		document.forms[0].dump_dir.value=\'\';
--		for (i=0;;i++)
--		{
--			if (document.forms[0].dump_dir.options[i]==null)
--				break;
--			document.forms[0].dump_dir.options[i].selected=true;
--			if (i)
--				document.forms[0].choice_sav.value += \'@\';
--			document.forms[0].choice_sav.value +=document.forms[0].dump_dir.options[i].value;
--		}
--	};
--	select_all();
--	</script>');
  http ('</td></tr></table>');

}
;

create procedure "PUMP"."DBA"."MANIFEST_OUT" (	in arr any, in xst varchar )
{
  declare str, r varchar;
  xslt_sheet (xst, xml_tree_doc (http_get (xst)));
  str := "PUMP"."DBA"."__GET_KEYWORD" ('comment',arr,'');
  if (str is null or length(str)=0)
    {
	http('<center>&lt;empty&gt;');
	return;
    }
--dbg_obj_print(str);
  r := xslt (xst, xml_tree_doc (xml_tree (str)), vector());
--dbg_obj_print(r);
  declare ses any;
  ses := string_output ();
  http_value (r, 0, ses);
  declare s varchar;
  s := string_output_string (ses);
  http (s);
}
;

