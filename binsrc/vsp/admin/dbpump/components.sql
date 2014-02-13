--  
--  $Id$
--  
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--  
--  Copyright (C) 1998-2014 OpenLink Software
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

--drop procedure __get_temporary;
create procedure "PUMP"."DBA"."__GET_TEMPORARY" (  )
{
  return  sprintf('./tmp/dbpump%d.tmp', sequence_next('dbpump_temp'));
}
;

create procedure "PUMP"."DBA"."DBPUMP_START_COMPONENT" ( 	in pars any,
							in name varchar,
							in arg varchar )
{
  declare i,n integer;
  declare str,allt,s,argsfile varchar;
  declare outarr any;

  allt := 'all_together_now';
  argsfile := sprintf('./tmp/%s.cmd-line',name);
  if (arg is null or length(arg)=0)
    arg := 'DUMMY';
  str := sprintf('%s %s ', name, arg);
  n := length(pars);
--dbg_obj_print(pars);
  str := concat (str, sprintf (' %s=%s ', allt,
	"PUMP"."DBA"."URLIFY_STRING" (
		"PUMP"."DBA"."__GET_KEYWORD" (allt,pars,''))));
  i := n - 2;
  while (i>=0)
  {
    s := aref(pars,i);
    if (neq (allt, s))
      str := concat (str, sprintf (' %s=%s ', s,"PUMP"."DBA"."URLIFY_STRING" (aref(pars,i+1))));
    i := i - 2;
  }
--dbg_obj_print(argsfile);
  string_to_file (argsfile,str,-2);
  str := sprintf ('@%s', argsfile);
--  str := concat (str, ' > ');
--  str := concat (str, tmp);
  commit work;
  run_executable ('dbpump', 1, str);
  return str;
}
;



--drop procedure dbpump_run_component;
create procedure "PUMP"."DBA"."DBPUMP_RUN_COMPONENT" ( 	inout pars any,
							in name varchar,
							in arg varchar,
							in outerr integer := 1 )
{
  declare i,n integer;
  declare str,allt,s,argsfile varchar;
  declare tmp,errstr varchar;
  declare outarr any;

  allt := 'all_together_now';
  tmp := "PUMP"."DBA"."__GET_TEMPORARY" ();
  argsfile := sprintf('./tmp/%s.cmd-line',name);
  if (arg is null or length(arg)=0)
    arg := 'DUMMY';
  str := sprintf('%s %s %s', name, arg, tmp);
  n := length(pars);
--dbg_obj_print(pars);
  str := concat (str, sprintf (' %s=%s ', allt,
	"PUMP"."DBA"."URLIFY_STRING" (
		"PUMP"."DBA"."__GET_KEYWORD" (allt,pars,''))));
  i := n - 2;
  while (i>=0)
  {
    s := aref(pars,i);
    if (neq (allt, s))
      str := concat (str, sprintf (' %s=%s ', s,"PUMP"."DBA"."URLIFY_STRING" (aref(pars,i+1))));
    i := i - 2;
  }

  declare exit handler for sqlstate '*' { errstr := sprintf ('Temporary file creation error:\n%s %s\nprobably permissions were revoked for temporary folder\nor it doesn\'t exist', __SQL_STATE, __SQL_MESSAGE); goto error_gen; };

  string_to_file(argsfile,str,-2);
  str := sprintf ('@%s', argsfile);
--  str := concat (str, ' > ');
--  str := concat (str, tmp);
  commit work;
  declare exit handler for sqlstate '*' { errstr := sprintf ('Dbpump running error:\n%s %s\nProbably the executable \'dbpump\' doesn\'t exist in \'bin\' folder', __SQL_STATE, __SQL_MESSAGE); goto error_gen; };
  run_executable('dbpump', 1, str);

  declare exit handler for sqlstate '*' { errstr := sprintf ('Results obtaining error:\n%s %s\nProbably the executable \'dbpump\' crashed during the work', __SQL_STATE, __SQL_MESSAGE); goto error_gen; };
  str := file_to_string(tmp);
  string_to_file(sprintf('./tmp/%s.cmd-out',name),str,-2);
--dbg_obj_print(str);
  "PUMP"."DBA"."DBPUMP_START_COMPONENT" (pars, 'remove_temporary', tmp);
--  run_executable('rm',0,'-f',tmp);
  return str;

error_gen:
  "PUMP"."DBA"."CHANGE_VAL" (pars, 'last_error', errstr);
  if (outerr)
    return sprintf ('last_error=%s', errstr);
  else
    return '';
}
;




--load comp_html.sql;
--load comp_tables.sql;
--load comp_rpath.sql;
--load comp_misc.sql;

