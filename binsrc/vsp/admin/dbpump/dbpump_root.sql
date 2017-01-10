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
--// DON'T TOUCH!!!
--VHOST_DEFINE(lpath=>'/admin/dbpump/',ppath=>'/admin/dbpump/',vsp_user=>'DBA');

use PUMP
;

sequence_set ('dbpump_temp', 0, 0)
;

sequence_set ('dbpump_id', 1, 0)
;


-- it is NOT such a good idea to drop and recreate a table on EVERY startup
-- This can mess-up the backup/restore process (as it does actually).
--drop table DBPUMP_HELP
--;

--CREATE PROCEDURE dbpump_init()
--{
--   if(
--     exists(
--       select KEY_TABLE from DB.DBA.SYS_KEYS
--       where KEY_TABLE='PUMP.DBA.DBPUMP_HELP' ) )
--     {
--       exec('drop table "PUMP"."DBA"."DBPUMP_HELP"');
--     }
--}
--;

--dbpump_init()
--;


create table "PUMP"."DBA"."DBPUMP_HELP" (
	"name" varchar,
	"dflt" varchar,
	"short_help" varchar,
	"full_help" long varchar,
	primary key("name")
)
;

--load oper_pars.sql;


--drop procedure __check_title;
create procedure "PUMP"."DBA"."__CHECK_TITLE" ( in sname varchar )
{
  declare shelp any;
  declare cr cursor for select  "short_help" from "PUMP"."DBA"."DBPUMP_HELP" where "name"=sname;

  open cr;
  whenever not found goto fin;
  while (1)
    {
      fetch cr into shelp;
      if (shelp is not null and length(shelp)>0)
	{
	  http(' title=\"');
	  http(shelp);
	  http('\"');
	}
    }
fin:
  close cr;
}
;

--drop procedure __get_keyword;
create procedure "PUMP"."DBA"."__GET_KEYWORD" ( in name varchar, in arr any, in def varchar )
{
  if (arr is not null)
    return get_keyword(name,arr,def);
  return '';
}
;


create procedure "PUMP"."DBA"."__GET_DUMP_NAME" ( out pars any )
{
  declare s varchar;
  s := sprintf('backup_%d', sequence_next('dbpump_id'));
--  dbg_obj_print(s);
  s := "PUMP"."DBA"."CHANGE_VAL_IF_NOT_SET" (pars, 'dump_dir', s);
--  dbg_obj_print(s, __get_keyword('dump_dir',pars,''));
  return s;
}
;


--drop procedure __check_help;
create procedure "PUMP"."DBA"."__CHECK_HELP" ( in sname varchar , in text varchar )
{
  declare lhelp any;
  declare cr cursor for select  "full_help" from "PUMP"."DBA"."DBPUMP_HELP" where "name"=sname;
  declare fnd integer;
  fnd := 0;

  open cr;
  whenever not found goto fin;
  while (1)
    {
      fetch cr into lhelp;
      if (lhelp is not null and length(lhelp)>0)
	{
	  http('<a onclick=\"var w=window.open(\'dbhelp.vsp?topic=');
	  http(sname);
	  http(concat('\',\'helpWindow\',\'toolbar=no,status=no,resizable=no,titlebar=no,height=200,width=400\');w.focus();return false;\" href=\"',sname,'\">'));
	  if (text is not null and length(text)>0)
	    http(text);
	  else
	    http('?');
	  http('</a>');
	  fnd := 1;
	}
    }
fin:
  close cr;
  if (fnd = 0)
    "PUMP"."DBA"."HTML_STR_OUT" (text);
}
;


--drop procedure html_smth_out;
create procedure "PUMP"."DBA"."HTML_SMTH_OUT" ( in attr varchar, in val varchar)
{
  if (val is not null and length(val)>0)
    {
      http(sprintf(' %s="',attr));
      http("PUMP"."DBA"."PROTECT_STRING" (val));
      http('" ');
    }
}
;

--drop procedure html_str_out;
create procedure "PUMP"."DBA"."HTML_STR_OUT" (in val varchar)
{
  if (val is not null and length(val)>0)
      http("PUMP"."DBA"."PROTECT_STRING" (val));
}
;

--drop procedure html_str_encode_out;
create procedure "PUMP"."DBA"."HTML_STR_ENCODE_OUT" (in val varchar)
{
  declare i,n,c integer;

  if (val is not null and length(val)>0)
    {
      n := length(val);
      i := 0;
      while (i<n)
	{
	  c := aref(val,i);
	  if (c = 32)
	    http('&nbsp;');
	  else
	    http(sprintf('%c',c));
	  i := i + 1;
	}
    }
}
;


--drop procedure urlify_string;
create procedure "PUMP"."DBA"."URLIFY_STRING" (in val varchar)
{
  declare i,n,c integer;
  declare s varchar;
  s := '';

--dbg_obj_print('before=',val);
  if (val is not null and length(val)>0)
    {
      n := length(val);
      i := 0;
      while (i<n)
	{
	  c := aref(val,i);

	  if (c = 32)
	    s := concat(s,'+');
	  else
	    {
		if ((c>=48 and c<=57) or (c>=97 and c<=122) or (c>=65 and c<=90))
		  s := concat(s,sprintf('%c',c));
		else
		  s := concat(s,sprintf('%%%02X',c));
	    }
	  i := i + 1;
	}
    }
--dbg_obj_print('urlify=',s);
  return s;
}
;

--drop procedure "PUMP"."DBA"."PROTECT_STRING";
create procedure "PUMP"."DBA"."PROTECT_STRING" (in val varchar)
{
  declare i,n,c,l integer;
  declare s, ss varchar;
  s := '';

  if (val is not null and length(val)>0)
    {
      n := length(val);
      i := 0;
      while (val is not null and length(val)>0)
	{
	  l := strchr(val,'<');
	  if (l is null)
	    {
		s := concat(s, val);
		return s;
	    }
	  ss := subseq(val,0,l);
--	dbg_obj_print(ss);
	  s := concat(s,ss);
	  s := concat(s,'&lt;');
	  val := subseq(val,l+1);
	}
    }
  return s;
}
;

--drop procedure extract_host_from_lines;
create procedure "PUMP"."DBA"."EXTRACT_HOST_FROM_LINES" ( in pars any )
{
  declare host varchar;
  declare i,n integer;
  n:=length(pars);
  i:=0;
  while (i<n)
  {
    host:=aref(pars,i);
    if (host like 'Host: %')
      {
	host:=trim(subseq(host, 5),'\r\n \"\t');
	return host;
      }
    i:=i+1;
  }
}
;




create procedure "PUMP"."DBA"."EXTRACT_PORT_FROM_INI" ( )
{
  declare sect, item, item_value varchar;
  sect := 'Parameters';
  declare nitems, j integer;
  nitems := cfg_item_count(virtuoso_ini_path(), sect);

  j := 0;
  while (j < nitems)
    {
	item := cfg_item_name(virtuoso_ini_path(), sect, j);
	item_value := cfg_item_value(virtuoso_ini_path(), sect, item);
	if (equ(item,'ServerPort'))
	  return  item_value;
	j := j + 1;
    }
  return '1111';
}
;


create procedure "PUMP"."DBA"."CHANGE_VAL" ( out pars any, in name varchar, in val varchar )
{
  declare i,n integer;
  declare str,s,argsfile varchar;

  n := length(pars);
  i := n - 2;
  while (i>=0)
  {
    s := aref(pars,i);
    if (equ(s,name))
	{
	  aset (pars, i+1, val);
	  return;
	}
    i := i - 2;
  }
  pars := vector_concat (pars, vector (name, val));
  return;
}
;


create procedure "PUMP"."DBA"."CHANGE_VAL_IF_NOT_SET" ( out pars any, in name varchar, in val varchar )
{
  declare i,n integer;
  declare str,s,argsfile varchar;

  n := length(pars);
  i := n - 2;
  while (i>=0)
  {
    s := aref (pars,i);
    str := aref (pars,i+1);
    if (equ(s,name))
      if (str is not null and length (str))
	{
--	 dbg_obj_print('not set'str);
	  return str;
	}
      else aset (pars,i+1, val);
    i := i - 2;
  }
  vector_concat (pars, vector (name, val));
  return val;
}
;

create procedure "PUMP"."DBA"."OBTAIN_DSN" ( out pars any, in lines any )
{
  declare port varchar;
  port := "PUMP"."DBA"."EXTRACT_PORT_FROM_INI" ( );

  "PUMP"."DBA"."CHANGE_VAL" (pars, 'datasource', concat('localhost:',port));

  declare auth varchar;
  declare _user varchar;
  declare _pwd varchar;

  auth  := db.dba.vsp_auth_vec (lines);
--dbg_obj_print(auth);
  _user := get_keyword ('username', auth, '');
--  _pwd  := get_keyword ('pass', auth, '');

  "PUMP"."DBA"."CHANGE_VAL" (pars, 'user', _user);
--  "PUMP"."DBA"."CHANGE_VAL" (pars, 'password', _pwd);
}
;



create procedure "PUMP"."DBA"."__RETRIEVE_HTTP_PARS" ( in afrom any, out ato any, in name varchar, in dflt varchar )
{
  declare s varchar;
  s := get_keyword (name, afrom);
  if (s is null)
     s := dflt;
  declare s2 any;
  s2 := vector (name, s);
  ato := vector_concat (ato, s2);
}
;

create procedure "PUMP"."DBA"."OUT_HIDDEN_PARS" ( in arr any, in req varchar )
{
  declare vreq, treq any;
  vreq := split_and_decode (req,0,'\0\0@');
  declare s, name varchar;
  declare i, n integer;
  n := length(vreq);
  i := 0;
  treq := vector();
  while (i<n)
    {
      name := aref(vreq,i);
      treq := vector_concat (treq, vector (name, ''));
      i := i + 1;
    }
  n := length(arr);
  i := n - 2;
  while (i>=0)
  {
    s := aref (arr,i);
    if (get_keyword (s, treq) is null)
      {
	http (concat ('<input type=\'hidden\' name=\'',s,'\' value=\'',aref (arr,i+1),'\'>\n'));
      }
    i := i - 2;
  }

}
;

create procedure "PUMP"."DBA"."OUT_CHK_DFLT_PARS" ( in req varchar )
{
  declare vreq, treq any;
  vreq := split_and_decode (req,0,'\0\0@');
  declare s, _name varchar;
  declare i, n integer;
  if (vreq is null)
    return 0;
  n := length(vreq);
  i := 0;
  treq := vector();
  http ('<script> function chk_dflt () {var s=\'\';\n');
  while (i<n)
    {
      _name := aref(vreq,i);

      declare sh varchar;
whenever not found goto smth;
      select "dflt" into sh from "PUMP"."DBA"."DBPUMP_HELP" where "name"=_name;

--      http (sprintf('s+=document.forms[0].%s.value+\'(%s)<>%s \';\n',_name,_name,sh));
      http (sprintf('if (document.forms[0].%s.value != \'%s\')\n', _name, sh));
      http ('{return 0;}\n');
smth:
      i := i + 1;
    }
  http ('return 1;\n}</script>\n');
  return 0;
}
;


create procedure "PUMP"."DBA"."RESTORE_DEFAULT_PARS" ( in req varchar )
{
  declare vreq, treq any;
  vreq := split_and_decode (req,0,'\0\0@');
  declare s, _name varchar;
  declare i, n integer;
  if (vreq is null)
    return 0;
  n := length(vreq);
  i := 0;
  treq := vector();
  http ('<script> function restore_dflt () {\n');
  while (i<n)
    {
      _name := aref(vreq,i);

      declare sh varchar;
whenever not found goto smth;
      select "dflt" into sh from "PUMP"."DBA"."DBPUMP_HELP" where "name"=_name;

      http (sprintf('document.forms[0].%s.value=\'%s\';\n', _name, sh));
smth:
      i := i + 1;
    }
  http ('return 1;\n}</script>\n');
  return 0;
}
;



create procedure "PUMP"."DBA"."HIDDEN_VAL_OUT" (	inout arr any,  in name varchar )
{
  declare s varchar;
  s := cast("PUMP"."DBA"."__GET_KEYWORD" (name, arr, '0') as varchar);
  http ('<script language="JavaScript">');
  http (sprintf ('document.forms[0].%s.value="%s";', name, s));
  http ('</script>\n');
}
;
