--  
--  $Id$
--  
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--  
--  Copyright (C) 1998-2015 OpenLink Software
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



--drop procedure html_select_type_out;
create procedure "PUMP"."DBA"."HTML_SELECT_TYPE_OUT" (	in arr any,
					in name varchar,
					in class varchar ,
					in dop varchar )
{
  "PUMP"."DBA"."HTML_SELECT_OUT" (arr, name, '', '0=-&1=CHAR&2=NUMERIC&3=DECIMAL&4=INTEGER&5=SMALLINT&6=FLOAT&7=REAL&8=DOUBLE PRECISION&9=DATE&10=TIME&11=TIMESTAMP&12=VARCHAR&13=BIT&14=BIT VARYING&15=LONG VARCHAR&16=BINARY&17=VARBINARY&18=LONG VARBINARY&19=BIGINT&20=TINYINT', class, dop, NULL);
}
;

--drop procedure html_select_datasources_out;
create procedure "PUMP"."DBA"."HTML_SELECT_DATASOURCES_OUT" ( inout arr any,
					in class varchar ,
					in dop varchar )
{
  declare str varchar;
  str := "PUMP"."DBA"."DBPUMP_RUN_COMPONENT" (arr,'select_datasources','*');
  http ('<table><tr><td>');
  if (length(str)>0)
    {
  "PUMP"."DBA"."HTML_SELECT_OUT" (arr, '_datasource', 'Available Datasources', str, class, ' size=5 ', NULL, 40, 'this.form.datasource.value=this.value;');
  http('</td></tr><tr><td align=center>');
  "PUMP"."DBA"."HTML_EDIT_OUT" (arr, 'datasource', 'Selected Datasource:', 'localhost', NULL, ' disabled ');
  http('</td></tr><tr><td align=center>');
  "PUMP"."DBA"."HTML_CHECKBOX_OUT" (arr, 'manual_datasource', 'Manual Datasource','', 'if (this.checked){this.form.datasource.disabled=false;this.form._datasource.disabled=true;}else{this.form._datasource.disabled=false;this.form.datasource.disabled=true;}', NULL, NULL);
    }
  else
    {
      "PUMP"."DBA"."HTML_EDIT_OUT" (arr, 'datasource', 'Selected Datasource:', 'localhost', NULL, NULL);
    }
  http ('</td></tr></table>');
}
;

--drop procedure oper_pars_retrieve;
create procedure "PUMP"."DBA"."OPER_PARS_RETRIEVE" ( inout pars any,
					in names varchar )
{
  declare n integer;
  declare str varchar;
  declare outarr any;

  set NO_CHAR_C_ESCAPE = 0;

--  dbg_obj_print(pars);
  str := "PUMP"."DBA"."DBPUMP_RUN_COMPONENT" (pars,'retrieve_oper_pars',names);
--  dbg_obj_print('after=',str);
--dbg_obj_print('split2');
  outarr := split_and_decode(str,0);
--  dbg_obj_print('decode=',outarr);
--  n := length(outarr);
  return outarr;
}
;

create procedure "PUMP"."DBA"."TRY_CONNECT_AND_PARS_RETRIEVE" ( inout pars any )
{
  declare n integer;
  declare str varchar;
  declare outarr any;

  set NO_CHAR_C_ESCAPE = 0;

--  dbg_obj_print(pars);
  str := "PUMP"."DBA"."DBPUMP_RUN_COMPONENT" (pars,'try_connect', '*');
--  dbg_obj_print('after=',str);
--dbg_obj_print('split2');
  outarr := split_and_decode(str,0);
--  dbg_obj_print('decode=',outarr);
--  n := length(outarr);
  return outarr;
}
;
