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

use VAD
;

--!AWK PUBLIC
create procedure
DB.DBA.DAV_RES_GET (in path varchar,
    inout data any,
    in auth_uid varchar,
    in auth_pwd varchar
     )
{
  declare id, ouid, ogid, rc integer;
  declare st char;
  declare tmp any;

  if (0 > (id := DB.DBA.DAV_SEARCH_ID (path, 'r')))
    return id;
  st := 'r';

  -- do authenticate & try locks
  if (0 > (rc := DB.DBA.DAV_AUTHENTICATE (id, st, '1__', auth_uid, auth_pwd)))
    return rc;
  if (0 <> (rc := DB.DBA.DAV_IS_LOCKED (id , st)))
    return rc;

  select RES_CONTENT into tmp from WS.WS.SYS_DAV_RES where RES_ID = id;
  if (length (tmp) > 10000000)
    {
      data := string_output ();
      http (tmp, data);
    }
  else
    data := blob_to_string (tmp);

  return 1;
}
;


create table "VAD"."DBA"."VAD_HELP" (
  "name" varchar,
  "dflt" varchar,
  "short_help" varchar,
  "full_help" long varchar,
  primary key("name")
)
;



create procedure "VAD"."DBA"."HTML_FOOTER_OUT" ( in arr any )
{
  http('</form></td></tr>');
  declare s varchar;
  s := "PUMP"."DBA"."__GET_KEYWORD" ('debug_in_footer',arr,'');
  if (s is not null and equ(s,'on'))
    {
      http('<TR CLASS="AdmBorders"><TD COLSPAN="2"><IMG SRC="images/1x1.gif" WIDTH="1" HEIGHT="2" ALT=""></TD></TR>\n');
      http('<TR CLASS="CtrlMain"><TD COLSPAN="2" ALIGN="middle">');
      "PUMP"."DBA"."DUMP_DEBUG_INFO" (arr);
      http('</TD></TR>');
    }
  http ('<TR CLASS="CopyrightBorder"><TD COLSPAN="2"><IMG SRC="/admin/images/1x1.gif" WIDTH="1" HEIGHT="2" ALT=""></TD></TR>');
  http ('<TR><TD ALIGN="right" COLSPAN="2"><P CLASS="Copyright">Virtuoso Server ');
  http (sys_stat('st_dbms_ver'));
  http (sprintf (' VAD Interface (%s) - Copyright&copy; 1998-2017 OpenLink Software.</P></TD></TR>',"VAD"."DBA"."VAD_VERSION" ()));
  http ('</TABLE>\n</BODY>');
}
;

create procedure "VAD"."DBA"."OUT_CHK_DFLT_PARS" ( in req varchar )
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
      select "dflt" into sh from "VAD"."DBA"."VAD_HELP" where "name"=_name;

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

create procedure "VAD"."DBA"."VAD_STRIP_RN" ( in str varchar )
{
  declare ret any;
  declare s varchar;
  s := ' ';
  ret := string_output();
  declare i, n, c integer;
  i := 0;
  n := length (str);
  while (i<n)
    {
      c := aref (str, i);
      if (c<>10 and c <> 13)
  {
    aset (s, 0, c);
    http (s, ret);
  }
      i := i + 1;
    }
  return string_output_string(ret);
}
;


create procedure "VAD"."DBA"."__VAD_TREE_OUT" ( inout arr any, inout ses any, in level integer, in mask varchar, in islast integer, inout sz integer, in cd integer) returns any
{
  declare nmask varchar;
  declare i, n, l, curid integer;
  declare t any;
  if (arr is null)
    return arr;
  n:= length (arr);
  if (n = 0)
    return arr;
  if (n < 3)
    "VAD"."DBA"."VAD_FAIL_CHECK" ('Corrupted tree structure');
  i := 3;
  declare gif varchar;
  declare color varchar;
  declare anchor varchar;
  gif := '';
  anchor := '';
  curid := aref (arr, 0);
  color := 'blue';
  if (cd = curid)
    color := 'green';

  t := aref (arr, 3);
  if (t is not null and length(t)>0)
    {
      if (aref (arr, 2))
    gif := 'minus.gif';
      else
      gif := 'plus.gif';
      gif := sprintf ('<img src="%s" onclick="document.forms[0].tree_node_clicked.value=\'%d\';document.forms[0].submit();">', gif, curid);
    }
  anchor := sprintf ('<a href="id=%d" onclick="document.forms[0].tree_node_clicked.value=0;document.forms[0].reg_curdir.value=%d;document.forms[0].submit();return false;"><font color="%s">%s</font></a>', aref (arr,0), aref (arr,0), color, aref (arr,1));
  http (sprintf ('%s%s%s\n', mask, gif, anchor), ses); -- <\n == br>
  sz := sz + 1;
  if (aref (arr, 2))
    {
      if (level)
      {
      if (islast)
      {
        aset (mask, level*2-2, 32); -- ' '
          aset (mask, level*2-1, 32); -- ' '
      }
      else
      {
        aset (mask, level*2-2, 58); -- ':'
        aset (mask, level*2-1, 32); -- '.'
      }
    }
    while (i<n)
    {
      nmask := concat (mask, ':.');
      if (i<n-1)
      l := 0;
      else
      l := 1;
      aset (arr, i, "VAD"."DBA"."__VAD_TREE_OUT" (aref (arr,i), ses, level + 1, nmask, l, sz, cd));
      i := i + 1;
    }
  }
  return arr;
}
;


create procedure "VAD"."DBA"."__EXPAND_PATH" ( inout arr any, in curdir integer, in clicked integer) returns integer
{
  declare i, n, t, tt, flag integer;
  declare tarr any;
  n:= length (arr);
  t := 0;
  if (n = 0)
    return arr;
  if (n < 3)
    "VAD"."DBA"."VAD_FAIL_CHECK" ('Corrupted tree structure');
  i := 3;
  declare curid integer;
  flag := 0;
  curid := aref (arr, 0);
  if (curid = clicked and aref (arr, 2))
    {
--    dbg_obj_print ('unclicked',clicked, curid, arr);
      aset (arr, 2, 0);
    flag := 1;
    }
  curid := aref (arr, 0);
  while (i<n)
  {
    tarr := aref (arr,i);
    tt := "VAD"."DBA"."__EXPAND_PATH" (tarr, curdir, clicked);
    aset (arr, i, tarr);
    if (tt)
      {
      t := 1;
        aset (arr, 2, 1);
    }
    i := i + 1;
  }
  if (not flag and curid = clicked and not aref (arr, 2))
    {
--    dbg_obj_print ('clicked',clicked);
      aset (arr, 2, 1);
  }

  if (curid = curdir)
    t := 1;
  return t;
}
;


create procedure "VAD"."DBA"."VAD_TREE_OUT" ( inout parr any, inout arr any, in clicked integer, inout sz integer ) returns varchar
{
  declare ses any;
  ses := string_output();
  declare s any;
  declare cd integer;

  s := "PUMP"."DBA"."__GET_KEYWORD"('reg_curdir', parr, '');
  if (s is null or 0 = length(s))
    s := '0';

  cd := cast (s as integer);
  "VAD"."DBA"."__EXPAND_PATH" (arr, cd, clicked);
  "VAD"."DBA"."__VAD_TREE_OUT" (arr, ses, 0, '', 1, sz, cd);
  return string_output_string(ses);
}
;


create procedure "VAD"."DBA"."VAD_LIST_FOLDER" (inout parr any, in id integer, in type varchar := 'file' )
{
  declare arr, tid integer;
  declare tname, tval varchar;
  arr := vector();

  whenever not found goto fin;
  declare cr cursor for select  "R_ID", "R_SHKEY", "R_VALUE" from "VAD"."DBA"."VAD_REGISTRY" where "R_PRNT"= id and "R_TYPE" <> 'FOLDER';
  open cr;
  while (1)
    {
      fetch cr into tid, tname, tval;
--    dbg_obj_print(tname, tval);
    arr := vector_concat (arr, vector (vector (tid, tname, tval, type))) ;
    }
fin:
  close cr;
  return arr;
}
;


create procedure "VAD"."DBA"."VAD_REG_DIR_OUT" (  inout arr any,
            in sz integer )
{
  declare curdir, fnd, tid integer;
  declare s, tname varchar;
  declare ses, tval any;
  ses := string_output();
  curdir := 0;
  s := "PUMP"."DBA"."__GET_KEYWORD"('reg_curdir', arr, '');
  if (s is not null and length (s) > 0)
    curdir := cast (s as integer);

  whenever not found goto fin;
  declare cr cursor for select  "R_ID", "R_SHKEY", "R_VALUE" from "VAD"."DBA"."VAD_REGISTRY" where "R_PRNT"=curdir and "R_TYPE" <> 'FOLDER';
  open cr;
  fnd := 0;
  while (1)
    {
      fetch cr into tid, tname, tval;
--    dbg_obj_print(tname, tval);
    if (fnd)
      http ('&', ses);
    s := sprintf ('%d=%s', tid, (sprintf ('%-20.20s = "%s"', tname, cast (tval as varchar))));
--    dbg_obj_print (s);
    http (s, ses);
    fnd := 1;
    }
fin:
  close cr;

  if (sz < 5)
    sz := 5;
  whenever not found goto fin2;
  s := '';
  s := "VAD"."DBA"."VAD_FULL_PATH" (arr, curdir);
fin2:
  "PUMP"."DBA"."HTML_SELECT_OUT" (arr, 'items_list', sprintf ('Current:%s', s ), string_output_string (ses), NULL, sprintf(' size=%d style=\'{width: 100%%}\'', sz), NULL, 40);
  return 0;
}
;


create procedure "VAD"."DBA"."VAD_REG_TREE_OUT" ( inout arr any, in rebuild integer := 0 )
{
  declare arr2, ses any;
  declare sz integer;

  arr2 := "PUMP"."DBA"."__GET_KEYWORD"('tree_ser', arr, '');
  if (arr2 is not null and length (arr2) > 0 and not rebuild)
    {
      ses := string_output();
      gz_uncompress (decode_base64(arr2), ses);
      arr2 := deserialize (string_output_string(ses));
    }
  else
    arr2 := "VAD"."DBA"."VAD_BUILD_TREE" ();
  declare s varchar;
  s := "PUMP"."DBA"."__GET_KEYWORD"('tree_node_clicked', arr, '0');

  sz := 0;
  s := "VAD"."DBA"."VAD_TREE_OUT" (arr, arr2, cast (s as integer), sz);

  http('<table width="100%"><tr><td class="genhead">Registry Tree</td></tr><tr><td class="statdata"><pre>');
  http(s);
  http('</pre></td></tr>');
  http('</table>');
  s := "VAD"."DBA"."VAD_STRIP_RN" (encode_base64 (gz_compress (serialize (arr2))));
  http (sprintf ('\n<script>document.forms[0].tree_ser.value="%s";</script>\n',s));
  return sz;
}
;


create procedure "VAD"."DBA"."VAD_OUT_PACKAGES_LIST" (inout arr any) returns integer
{
   declare s varchar;
   --declare exit handler for sqlstate '*' { goto do_smth_in_any_way; };
   declare parr, pitem, ses any;
   ses := string_output();
   parr := "VAD"."DBA"."VAD_GET_PACKAGES" ( );
--   dbg_obj_print(parr);
   declare i, n integer;
   s := '';

   n := length (parr);
   i := 0;
   while (i < n)
     {
      pitem := aref (parr, i);
    if (i)
      http ('&', ses);
    http (sprintf ('%d=%s: %s', aref (pitem, 0), aref (pitem, 1), aref (pitem, 2)), ses);
    i := i + 1;
   }

do_smth_in_any_way:
  "PUMP"."DBA"."HTML_SELECT_OUT" (arr, 'packages_list', 'Available packages', string_output_string (ses), NULL, ' size=10 style=\'{width: 100%}\'', NULL, 50);
  return 0;
}
;


create procedure "VAD"."DBA"."VAD_GEN_PACKAGES_LIST" (inout arr any, in execstr varchar ) returns integer
{
   declare s varchar;
   --declare exit handler for sqlstate '*' { goto do_smth_in_any_way; };
   declare parr, pitem, ses any;
   ses := string_output();
   parr := "VAD"."DBA"."VAD_GET_PACKAGES" ( );
--   dbg_obj_print(parr);
   declare i, n integer;
   s := '';

   declare curp integer;
   curp := cast ("PUMP"."DBA"."__GET_KEYWORD"('packages_list', arr, '') as integer );

   http ('<table class="statdata" border="0" cellpadding="0">');
   http ('<tr><th CLASS="genhead" style="{width:2in}">Package</th><th CLASS="genhead" style="{width:2in}">Version</th></tr>');
   n := length (parr);
   i := 0;
   while (i < n)
     {
      pitem := aref (parr, i);
    declare onclick varchar;
    onclick := '<a href="" onclick="document.forms[0].packages_list.value=%d;document.forms[0].submit();return false;">%s</a>';
      http ('<tr><td CLASS="statlisthead">');
    http (sprintf (onclick, aref (pitem, 0), aref (pitem, 1)));
      http ('</td>');

      http ('<td CLASS="statlistdata">');
    http (sprintf (onclick, aref (pitem, 0), aref (pitem, 2)));
      http ('</td></tr>');
    if (curp = aref (pitem, 0))
      {

        http ('<tr><td CLASS="statlistdata" colspan=2>');
        exec (sprintf ('%s (\'%s\',\'%s\')',execstr,  aref (pitem, 1), aref (pitem, 2)));
        http ('</td></tr>');
      }
    i := i + 1;
   }

do_smth_in_any_way:
   http ('</table>');
  return 0;
}
;

create procedure "VAD"."DBA"."VAD_GEN_PACKAGE_DOCS" (in pkgname varchar , in pkgver varchar) returns integer
{
  declare tarr any;
  tarr := null;
  declare s varchar;
  http('<hr>');
  s := sprintf ('/DOCS/%s/%s', pkgname, pkgver);
  declare id integer;
  id := "VAD"."DBA"."VAD_CHDIR" (tarr, 1, s);
  if (not id)
    return 0;
  http ('<table class="statdata" border="0" cellpadding="0">');
  whenever not found goto fin;
  declare cr cursor for select  "R_VALUE" from "VAD"."DBA"."VAD_REGISTRY" where "R_PRNT"=id and "R_TYPE" <> 'FOLDER';
  open cr;
  while (1)
    {
      fetch cr into s;
    http ('<tr><td colspan=2>');
    http (s);
    http ('</td></tr>');
    }
fin:
  close cr;
  http ('</table>');
  http('<hr>');
}
;


create procedure "VAD"."DBA"."VAD_GEN_PACKAGE_HTTP" (in pkgname varchar , in pkgver varchar) returns integer
{
  declare tarr any;
  tarr := null;
  declare s varchar;
  http('<hr>');
  s := sprintf ('/VAD/%s/%s/resources/http', pkgname, pkgver);
  declare id integer;
  id := "VAD"."DBA"."VAD_CHDIR" (tarr, 1, s);
  if (not id)
    return 0;
  http ('<table class="statdata" border="0" cellpadding="0">');
  whenever not found goto fin;
  declare cr cursor for select  "R_VALUE" from "VAD"."DBA"."VAD_REGISTRY" where "R_PRNT"=id and "R_TYPE" <> 'FOLDER';
  open cr;
  while (1)
    {
      fetch cr into s;
    http ('<tr><td colspan=2>');
    http (sprintf ('<a href = "/VAD/%s">%s</a>', s, s));
    http ('</td></tr>');
    }
fin:
  close cr;
  http ('</table>');
  http('<hr>');
}
;


create procedure "VAD"."DBA"."VAD_TEST_PACKAGE_EQ" (inout parr any, in pkgname varchar , in pkgver varchar) returns integer
{
  declare s varchar;
  s := sprintf ('/VAD/%s', pkgname);
  declare id integer;
  id := "VAD"."DBA"."VAD_CHDIR" (parr, 1, s);
  if (not id)
    return 0;
  if (exists (
  select "R_ID" from "VAD"."DBA"."VAD_REGISTRY" where "R_PRNT" = id and "R_TYPE" = 'FOLDER' and "R_SHKEY" = pkgver
  ))
  return 1;
  return 0;
}
;


create procedure "VAD"."DBA"."VAD_TEST_PACKAGE_LT" (inout parr any, in pkgname varchar , in pkgver varchar) returns integer
{
  declare s varchar;
  s := sprintf ('/VAD/%s', pkgname);
  declare id integer;
  id := "VAD"."DBA"."VAD_CHDIR" (parr, 1, s);
  if (not id)
    return 0;

  if (exists (
  select "R_ID" 
    from "VAD"."DBA"."VAD_REGISTRY" 
    where "R_PRNT" = id and 
          "R_TYPE" = 'FOLDER' and 
          "VAD"."DBA"."VERSION_COMPARE" ("R_SHKEY", pkgver) = -1
  ))
  return 1;

  return 0;
}
;

create procedure "VAD"."DBA"."VAD_TEST_PACKAGE_GT" (inout parr any, in pkgname varchar , in pkgver varchar) returns integer
{
  declare s varchar;
  s := sprintf ('/VAD/%s', pkgname);
  declare id integer;
  id := "VAD"."DBA"."VAD_CHDIR" (parr, 1, s);
  if (not id)
    return 0;
  if (exists (
  select "R_ID" 
    from "VAD"."DBA"."VAD_REGISTRY" 
    where "R_PRNT" = id and 
          "R_TYPE" = 'FOLDER' and 
          "VAD"."DBA"."VERSION_COMPARE" ("R_SHKEY", pkgver) = 1
  ))
  return 1;
  return 0;
}
;

create procedure "VAD"."DBA"."VAD_TEST_PACKAGE_AND_REMOVE" (inout parr any, in pkgname varchar , in pkgver varchar) returns integer
{
  declare s varchar;
  s := sprintf ('/VAD/%s/%s', pkgname, pkgver);
  declare id integer;
  id := "VAD"."DBA"."VAD_CHDIR" (parr, 1, s);
  if (not id)
    return 0;
  declare lname, ltype, lval varchar;
  "VAD"."DBA"."VAD_NODE_INFO_BY_NAME" (id, 'Status', lname, ltype, lval);
  if (lval <> 'Installed')
    "VAD"."DBA"."VAD_DEL_SUBTREE" (id);

  return 0;
}
;

create procedure "VAD"."DBA"."VAD_EXEC" (in prog varchar) returns integer
{
  if (prog is null or length (prog) = 0)
    return 0;
  declare pname varchar;
  pname := sprintf ('vad.dba.vad_%d_code', sequence_next('vad_tmp'));
-- dbg_obj_print (pname);
-- dbg_obj_print (cast(blob_to_string(prog) as varchar));
  exec (sprintf ('create procedure %s () { declare exit handler for not found { signal (\'42000\', \'No WHENEVER statement provided for SQLCODE 100\'); }; set_qualifier (\'DB\'); %s }',
	pname, cast(blob_to_string(prog) as varchar)));
  exec (sprintf ('%s ()', pname));
  exec (sprintf ('drop procedure %s', pname));
  return 0;
}
;

create procedure "VAD"."DBA"."VAD_LOAD_FILE" (in fname varchar) returns integer
{
  declare code varchar;
  declare s varchar;

  declare continue handler for sqlstate '39000' { goto error_nofile; };
  declare continue handler for sqlstate '42000' { goto error_nofile; };

  declare iniarr, tarr any;
  tarr := vector ();
  iniarr := "VAD"."DBA"."VAD_READ_INI" (tarr);

  s := sprintf ('%s/%s',get_keyword ('code', iniarr), fname);
--  dbg_obj_print (s);
  code := file_to_string (s);
  if (code is null)
    return 0;

  declare i, n integer;
  --dbg_obj_print(code);
  tarr := sql_split_text (code);
  n := length (tarr);
  i := 0;
  while (i < n)
    {
--    dbg_obj_print ('yep', i, n);
    s := aref (tarr, i);
      --dbg_obj_print (s);
      exec (s);
    i := i + 1;
  }

--  declare ses any;
--  ses := string_output ();
--  tarr := split_and_decode (code, 0, '\0\0\n');

--  n := length (tarr);
--  i := 0;
--  while (i < n)
--    {
--    dbg_obj_print ('yep', i, n);
--    s := trim (aref(tarr, i), ' \t\r');
--    if (aref (s,0) <> 59) --';'
--      {
--        dbg_obj_print (s, i);
--        http (concat (s, '\n'), ses);
--    }
--    else
--      {
--      s := string_output_string (ses);
--      if (length(s))
--        {
--          dbg_obj_print (s);
--            exec (s);
--        dbg_obj_print('done',i);
--        ses := string_output();
--      }
--    }
--    i := i + 1;
--  }
  return 1;
error_nofile:;
  "VAD"."DBA"."VAD_FAIL_CHECK" (sprintf ('Attempt to load inexistent file\n%s', __SQL_MESSAGE));
  return 0;
}
;


create procedure "VAD"."DBA"."VAD_VHOST_DEFINE" (in pkgname varchar, in pkgver varchar ) returns integer
{
  DB.DBA.VHOST_DEFINE(lpath=>sprintf ('/VAD/%s/%s/', pkgname, pkgver),ppath=>sprintf ('/%s/%s/%s/',"VAD"."DBA"."VAD_GET_ROOT" ('http'), pkgname, pkgver),vsp_user=>'DBA');
  return 0;
}
;

create procedure "VAD"."DBA"."VAD_VHOST_REMOVE" (in pkgname varchar, in pkgver varchar ) returns integer
{
  DB.DBA.VHOST_REMOVE(lpath=>sprintf ('/VAD/%s/%s/', pkgname, pkgver));
  return 0;
}
;

create procedure "VAD"."DBA"."VAD_EXEC_RETRYING" (in _expn varchar) returns varchar
{
  declare _state, _message varchar;
  declare _retries integer;
  _state := '';
  _retries := 0;
  while(1)
    {
      exec (_expn, _state, _message);
      if (_state <> '41000')
        return _state;
      if (_retries > 10)
    "VAD"."DBA"."VAD_FAIL_CHECK"  (concat ('Continuous deadlocks in\n', _expn, '\n'));
      _retries := _retries+1;
    }
}
;

create procedure "VAD"."DBA"."VAD_ASSERT2" (in _val integer, in _text varchar)
{
  if (not _val)
    "VAD"."DBA"."VAD_FAIL_CHECK" (_text);
}
;

create procedure "VAD"."DBA"."VAD_ASSERT" (in _expn varchar)
{
  "VAD"."DBA"."VAD_EXEC_RETRYING" (
    concat (
      '"DB"."DBA"."VAD_ASSERT2"((', _expn, '), concat (''Assertion failed: '', ',
      "WS"."WS"."STR_SQL_APOS"(_expn), '))' ) );
}
;

create procedure "VAD"."DBA"."VAD_SAFE_EXEC" (in _expn varchar) returns integer
{
  declare exit handler for sqlstate '*' { goto error_smth; };
  if (not length ("VAD"."DBA"."VAD_EXEC_RETRYING" (_expn)))
    {
      return 1;
    }
  error_smth:;
    return 0;
}
;

create procedure "VAD"."DBA"."VAD_GET_NAME_AND_VERSION"(
  in name_and_version varchar,
  inout name varchar,
  inout version varchar) returns integer
{
  declare dot_pos integer;
  dot_pos := strchr(name_and_version, '/');
  if (dot_pos)
  {
    name := subseq(name_and_version, 0, dot_pos);
    if (name = '' or name is null)
      return 0;
    version := subseq(name_and_version, dot_pos + 1);
    if (version = '' or version is null)
      return 0;
    return 1;
  }
  else
    return 0;
}
;

--!
-- \brief Compare two version strings.
--
-- An arbitrary number of version components are supported in addition to an
-- optional suffix like "_xxxNN" where "xxx" is a word and "NN" is the suffix
-- number.
--
-- \b Examples:
-- \code
-- 1.0
-- 1.0.0
-- 1.0.2
-- 2.3_git12
-- \endcode
--
-- \return \p 1 if \p x is larger than \p y, \p -1 if \p x is smaller, \p 0 if they are equal.
--/
create procedure "VAD"."DBA"."VERSION_COMPARE"(in x varchar, in y varchar)
    {
  declare xx, yy any;
  declare xsuff, ysuff varchar;
  declare xi, yi int;

  if (x is null)
    return 0;
  if (length (x) = 0 and length (y) > 0)
    return 1;

  -- strip optional suffix from versions (suffix separator is '_')
  xsuff := '';
  xx := sprintf_inverse (x, '%s_%s', 0);
  if (not xx is null)
  {
    xsuff := xx[1];
    x := xx[0];
  }
  ysuff := '';
  yy := sprintf_inverse (y, '%s_%s', 0);
  if (not yy is null)
  {
    ysuff := yy[1];
    y := yy[0];
  }

  -- split version strings into components
  xx := split_and_decode (x, 0, '\0\0.');
  yy := split_and_decode (y, 0, '\0\0.');

  -- pad vectors to equal length
  while (length (xx) < length (yy))
    xx := vector_concat (xx, vector ('0'));
  while (length (yy) < length (xx))
    yy := vector_concat (yy, vector ('0'));

  -- compare component by component
  for (declare i, l int, i := 0, l := length (xx); i < l; i := i + 1)
    {
      xi := atoi (xx[i]);
      yi := atoi (yy[i]);

      if (xi < yi)
    return -1;
      if (xi > yi)
    return 1;
  }

  -- at this point both base versions are the same
  -- which means that the suffix makes all the difference
  -- the suffix always starts with at least one letter
  -- followed by a number
  xx := regexp_parse('([a-zA-Z]*)([0-9]*)', xsuff, 0);
  xi := atoi (substring (xsuff, xx[4]+1, xx[5]-xx[4]));

  yy := regexp_parse('([a-zA-Z]*)([0-9]*)', ysuff, 0);
  yi := atoi (substring (ysuff, yy[4]+1, yy[5]-yy[4]));

  if (xi < yi)
    return -1;
  else if (xi > yi)
    return 1;
  else
    return 0;
}
;

create procedure "VAD"."DBA"."VAD_CHECK_FOR_HIGH_VERSION" (in name varchar) returns varchar
{
  declare version, prod varchar;
  if ("VAD"."DBA"."VAD_GET_NAME_AND_VERSION"(name, prod, version) = 0)
    return '-1';
  declare parr, pitem any;
  parr := "VAD"."DBA"."VAD_GET_PACKAGES"();
  declare i, n integer;
  n := length (parr);
  i := 0;
  declare cur_name, cur_version varchar;
  while (i < n)
  {
    pitem := aref(parr, i);
    cur_name := aref(pitem, 1);
    if (prod = cur_name)
    {
      cur_version := aref(pitem, 2);
      if ("VAD"."DBA"."VERSION_COMPARE"(cur_version, version) = 1)
        return cur_version;
    }
    i := i + 1;
  }
  return '0';
}
;

create procedure "VAD"."DBA"."VAD_REMOVE_PREVIOUS_VERSION" (in prod varchar, in version varchar) returns integer
{
  declare dot_pos, ver1, ver2 integer;
  declare ss varchar;
  dot_pos := strchr(version, '.');
  if (dot_pos)
  {
    ss := subseq(version, 0, dot_pos);
    if (ss = '' or ss is null)
      ver1 := 0;
    else
      ver1 := atoi(ss);

    ss := subseq(version, dot_pos + 1);
    if (ss = '' or ss is null)
      ver2 := 0;
    else
      ver2 := atoi(ss);

  }
  else
  {
    ver1 := atoi(version);
    ver2 := 0;
  }


  declare parr, pitem, verarr any;
  parr := "VAD"."DBA"."VAD_GET_PACKAGES"();
  declare i, n integer;
  n := length (parr);
  i := 0;
  declare cur_name, cur_version varchar;
  declare dot_pos1, v1, v2 integer;
  declare curdir, tid integer;
  declare parr1 any;
  while (i < n)
  {
    pitem := aref(parr, i);
    cur_name := aref(pitem, 1);
    if (prod = cur_name)
    {
      cur_version := aref(pitem, 2);
      dot_pos1 := strchr(cur_version, '.');
      if (dot_pos)
      {
        ss := subseq(cur_version, 0, dot_pos1);
        if (ss = '' or ss is null)
          v1 := 0;
        else
          v1 := atoi(ss);
        ss := subseq(cur_version, dot_pos1 + 1);
        if (ss = '' or ss is null)
          v2 := 0;
        else
          v2 := atoi(ss);
        if ((v1 < ver1) or ((v1 = ver1) and (v2 < ver2)))
        {
          parr1 := null;
          curdir := "VAD"."DBA"."VAD_CHDIR"(parr1, 0, '/VAD');
          tid := "VAD"."DBA"."VAD_CHDIR"(parr1, curdir, concat(prod, '/', cast(cur_version as varchar)));
          if (tid)
            "VAD"."DBA"."VAD_DEL_SUBTREE"(tid);
          -- "DB"."DBA"."VAD_UNINSTALL"(concat(prod, '/', cur_version));
        }
        if ((v1 > ver1) or ((v1 = ver1) and (v2 > ver2)))
        {
          "VAD"."DBA"."VAD_FAIL_CHECK"(sprintf ('Package "%s" with higher version "%s" already exists', prod, cur_version));
        }
      }
      else
      {
        v1 := atoi(cur_version);
        v2 := 0;
        if ((v1 < ver1) or ((v1 = ver1) and (v2 < ver2)))
        {
          parr1 := null;
          curdir := "VAD"."DBA"."VAD_CHDIR"(parr1, 0, '/VAD');
          tid := "VAD"."DBA"."VAD_CHDIR"(parr1, curdir, concat(prod, '/', cast(cur_version as varchar)));
          if (tid)
            "VAD"."DBA"."VAD_DEL_SUBTREE"(tid);
          -- "DB"."DBA"."VAD_UNINSTALL"(concat(prod, '/', cur_version));
        }
        if ((v1 > ver1) or ((v1 = ver1) and (v2 > ver2)))
        {
          "VAD"."DBA"."VAD_FAIL_CHECK"(sprintf ('Package "%s" with higher version "%s" already exists', prod, cur_version));
        }
      }
    }
    i := i + 1;
  }
  return 0;
}
;

create procedure "VAD"."DBA"."VAD_LIST" (in dir varchar := null, in fs_type int := 0)
{
  declare vads, name, ver, arr any;
  declare pname, pver, pfull, pisdav, pdate any;
  declare vaddir any;
  declare nlist, ilist, alist, tmp any;
  declare pcols int;

  declare PKG_NAME, PKG_VER, PKG_DATE, PKG_INST, PKG_DESC, PKG_NVER, PKG_NDATE, PKG_FILE, PKG_DEST varchar;

  result_names (PKG_NAME, PKG_DESC, PKG_VER, PKG_DATE, PKG_INST, PKG_NVER, PKG_NDATE, PKG_FILE, PKG_DEST);
  pcols := length (procedure_cols ('VAD.DBA.VAD_TEST_READ'));

  nlist := vector ();
  vaddir := dir;
  if (vaddir is null and fs_type = 0)
    vaddir := cfg_item_value (virtuoso_ini_path (), 'Parameters', 'VADInstallDir');

  if (vaddir is null)
    return;

  declare exit handler for sqlstate '*'
  {
    goto merge;
  };

  if (vaddir not like '%/')
    vaddir := vaddir || '/';

  if (fs_type = 0)
    arr := sys_dirlist (vaddir, 1);
  else
    arr := (select vector_agg (RES_NAME) from WS.WS.SYS_DAV_RES where RES_FULL_PATH like vaddir || '%' and RES_FULL_PATH = vaddir||RES_NAME);

  foreach (any f in arr) do
    {
       if (f like '%.vad')
	 {

	   declare st, rc int;
	   declare exit handler for sqlstate '*' {
	     goto next_pkg;
	   };

	   pisdav := 0;
           if (f like '%_dav.vad')
             pisdav := 1;

	   st := msec_time ();
	   rc := 0;
	   pname := null;
	   if (pcols = 7)
	     rc := "VAD"."DBA"."VAD_TEST_READ" (vaddir||f, pname, pver, pfull, pdate, fs_type, 1);
	   else
	     rc := "VAD"."DBA"."VAD_TEST_READ" (vaddir||f, pname, pver, pfull, pdate, fs_type);
	   next_pkg:;
           if (pname is not null)
	     nlist := vector_concat (nlist, vector (pname, vector (pver, pdate, f)));
	 }
    }
  merge:
  declare exit handler for sqlstate '*'
  {
    resignal;
  };
  ilist := "VAD"."DBA"."VAD_GET_PACKAGES" ();
  tmp := make_array (length (ilist) * 2, 'any');

  for (declare i,l int, i := 0, l := length (ilist); i < l; i := i + 1)
    {
      declare isdav int;
      isdav := 0;
      if (exists (select top 1 1 from VAD.DBA.VAD_REGISTRY
	    where R_KEY like sprintf ('/VAD/%s/%s/resources/dav/%%', ilist[i][1], ilist[i][2])))
	isdav := 1;
      tmp[i*2] := ilist[i][1];
      tmp[(i*2)+1] := vector_concat (ilist[i], vector (null, null, null, isdav));
    }
  ilist := tmp;

  tmp := vector ();
  for (declare i,l int, i := 0, l := length (nlist); i < l; i := i + 2)
    {
      declare pos, nisdav int;
      nisdav := 0;
      if (nlist[i+1][2] like '%_dav.vad')
	nisdav := 1;
      if ((pos := position (nlist[i], ilist)))
	{
	  if ("VAD"."DBA"."VERSION_COMPARE" (ilist[pos][2], nlist[i+1][0]) = -1 and ilist[pos][9] = nisdav)
	    {
	      ilist[pos][6] := nlist[i+1][0];
	      ilist[pos][7] := nlist[i+1][1];
	      ilist[pos][8] := nlist[i+1][2];
	    }
	}
      else
	{
	  declare suf any;
	  suf := 0;
	  if (nlist[i+1][2] like '%_dav.vad')
	    suf := 1;
	  tmp := vector_concat (tmp,
	  	vector (nlist[i], vector (0, nlist[i], null, null, null, 'n/a', nlist[i+1][0], nlist[i+1][1], nlist[i+1][2], suf)));
	}
    }
  ilist := vector_concat (ilist, tmp);
  for (declare i,l int, i := 0, l := length (ilist); i < l; i := i + 2)
    {
      result
	  (
	      ilist[i+1][1],
	      ilist[i+1][5],
	      ilist[i+1][2],
	      ilist[i+1][3],
	      ilist[i+1][4],
	      ilist[i+1][6],
	      ilist[i+1][7],
	      ilist[i+1][8],
	      ilist[i+1][9]
	  );
    }
}
;

create procedure "VAD"."DBA"."CREATE_VAD_LIST_VIEW" ()
{
    if (exists (select KEY_TABLE from "DB"."DBA"."SYS_KEYS" where "KEY_TABLE" = 'VAD.DBA.VAD_LIST'))
        "VAD"."DBA"."VAD_EXEC_RETRYING" ('drop table VAD.DBA.VAD_LIST');
    if (not exists (select "KEY_TABLE" from "DB"."DBA"."SYS_KEYS" where "KEY_TABLE" = 'VAD.DBA.VAD_LIST'))
        "VAD"."DBA"."VAD_EXEC_RETRYING" ('create procedure view VAD.DBA.VAD_LIST as VAD.DBA.VAD_LIST (dir, fs_type)(PKG_NAME varchar,  PKG_DESC varchar,  PKG_VER varchar,  PKG_DATE varchar,  PKG_INST varchar, PKG_NVER varchar,  PKG_NDATE  varchar,  PKG_FILE varchar, PKG_DEST int)');
}
;

"VAD"."DBA"."CREATE_VAD_LIST_VIEW" ()
;

--!
-- Get a list of installed and available vads.
--
-- \return A key/value vector where the key is a vad name and the value is a vad detail
-- vector. The latter consists of available version, installed version, vad filename, and vad dir type (\p 0 for fs and \p 1 for dav).
--/
create procedure "VAD"."DBA"."VAD_GET_AVAILABLE_VADS" (
  in vadDir varchar := null,
  in dirType int := 0)
{
  declare vads, vad any;

  vads := vector ();
  for (select PKG_NAME, PKG_FILE, PKG_VER as INSTALLED_VER, coalesce(PKG_NVER, PKG_VER) as AVAILABLE_VER from VAD.DBA.VAD_LIST where dir=vadDir and fs_type=dirType) do
  {
    vad := vector (AVAILABLE_VER, INSTALLED_VER, PKG_FILE, dirType);
    vads := vector_concat (vads, vector (PKG_NAME, vad));
  }
  return vads;
}
;

--!
-- Tries hard to resolve the dependency tree of the given VAD file.
--
-- Throws a signal if any dependency could not be found or a loop was
-- detected. Any parameters but \p fname, \p is_dav, \p vadDir and \p vadDirType are internal
-- and need to be ignored.
--
-- \return A vector identifying the resolved dependency tree.
-- - Each package will only be added to the tree once, ie. the first time it is encountered.
-- - Only packages that are not yet installed will be added to the tree, meaning that the
--   tree will contain all packages that need to be installed.
-- - Each tree node represents a package in a key/value vector with the following keys:
--   \p name is the package name, \p path is the path to the vad, \p pathType is either \p 1 (DAV) or
--   \p 0 (FS) and refers to the type of the \p path, \p deps is a list of
--   dependencies, ie. package nodes.
--
-- \sa DB.DBA.VAD_INSTALL_FROM_DEPENDENCY_TREE, DB.DBA.VAD_FLATTEN_DEPENDENCY_TREE
--/
create procedure "VAD"."DBA"."VAD_RESOLVE_DEPENDENCY_TREE" (
  in fname varchar,
  in is_dav integer,
  in vadDir varchar := null,
  in vadDirType int := 0,
  in availableVads any := null,
  in checkedVads any := null,
  in parentPkgName varchar := null,
  in depName varchar := null,
  in requiredPkgVersion varchar := null,
  in versionCompVal int := null)
{
--dbg_obj_print('DB.DBA.VAD_RESOLVE_DEPENDENCY_TREE (', fname, is_dav, vadDir, vadDirType, availableVads, checkedVads, parentPkgName, depName, requiredPkgVersion, versionCompVal, ')');
  declare stickerData, s varchar;
  declare flen, pos integer;
  declare data any;
  declare stickerTree, stickerDoc, items, dep, parr any;
  declare pkgName, pkgTitle, pkgVersion, pkgDate, depVer varchar;
  declare depTree any;

  if (vadDir is null)
  {
    vadDir := cfg_item_value (virtuoso_ini_path (), 'Parameters', 'VADInstallDir');
  }
  vadDir := rtrim (vadDir, '/') || '/';

  if (availableVads is null)
  {
    availableVads := "VAD"."DBA"."VAD_GET_AVAILABLE_VADS" (vadDir, vadDirType);
  }
  if (checkedVads is null)
  {
    checkedVads := vector ();
  }


  if (parentPkgName is not null)
  {
    -- See if we have the package in any version
    dep := get_keyword (depName, availableVads);
    if (dep is null)
    {
      signal ('37000', sprintf ('Vad package %s depends on %s. Please install.', parentPkgName, depName));
    }
    fname := vadDir || dep[2];
    is_dav := dep[3];

    -- Check if the available version matches the requirements
    if("VAD"."DBA"."VERSION_COMPARE" (dep[0], requiredPkgVersion) <> versionCompVal)
    {
      signal ('37000', sprintf ('Vad package %s depends on %s version %s%s. Available version %s is not sufficient.', parentPkgName, depName, (case when versionCompVal = 1 then 'greater than ' when versionCompVal = -1 then 'smaller than ' end), requiredPkgVersion, dep[0]));
    }
  }

  -- we also support plain filenames which live in the vad dir
  if (position ('/', fname) = 0)
  {
    fname := vadDir || fname;
  }

  flen := "VAD"."DBA"."VAD_GET_STICKER_DATA_LEN" (fname, is_dav);
  if (is_dav = 0)
  {
    stickerData := file_to_string_output (fname, 0, flen);
  }
  else
  {
    stickerData := string_output();
    "VAD"."DBA"."BLOB_2_STRING_OUTPUT"(fname, 0, flen, stickerData);
  }

  -- Get header (already checked above)
  pos := 0;
  "VAD"."DBA"."VAD_GET_ROW" (stickerData, pos, s, data);

  -- Get the sticker itself
  "VAD"."DBA"."VAD_GET_ROW" (stickerData, pos, s, data);

  -- parse the sticker
  stickerTree := xml_tree (data);
  stickerDoc := xml_tree_doc (stickerTree);


  -- Extract package name
  pkgName := xpath_eval ('/sticker/caption/name/@package', stickerDoc, 0);
  if (length (pkgName) = 0) {
    signal ('37000', sprintf ('Sticker for %s does not contain a package name!', fname));
  }
  pkgName := cast (pkgName[0] as varchar);

  -- Extract package title
  pkgTitle := xpath_eval ('/sticker/caption/name/prop[@name=\'Title\']', stickerDoc, 0);
  if (length (pkgTitle) = 0) {
    signal ('37000', sprintf ('Sticker for %s does not contain a package title!', fname));
  }
  pkgTitle := cast (xpath_eval ('@value', pkgTitle[0]) as varchar);

  -- Extract package version
  pkgVersion := xpath_eval ('/sticker/caption/version/@package', stickerDoc, 0);
  if (length (pkgVersion) = 0) {
    signal ('37000', sprintf ('Sticker for %s does not contain a package version!', fname));
  }
  pkgVersion := cast (pkgVersion[0] as varchar);

  -- Extract package date
  pkgDate := xpath_eval ('/sticker/caption/version/prop[@name=\'Release Date\']', stickerDoc, 0);
  if (length (pkgDate) = 0) {
    signal ('37000', sprintf ('Sticker for %s does not contain a package date!', fname));
  }
  pkgDate := cast (xpath_eval ('@value', pkgDate[0]) as varchar);


  -- Prepare the result
  depTree := vector ();

  -- The vad code needs this parr object for something I do not undestand yet
  parr := null;

  items := xpath_eval ('/sticker/dependencies/require', stickerDoc, 0);
  for (declare i int, i := 0; i < length (items); i := i+1)
  {
    depName := cast (xpath_eval ('name/@package', items[i]) as varchar);

    depVer := cast (xpath_eval ('versions_earlier/@package', items[i]) as varchar);
    if (depName is not null and length(depVer))
    {
      if (not "VAD"."DBA"."VAD_TEST_PACKAGE_LT" (parr, depName, depVer))
      {
        -- Check if we need to recurse into the vads deps
        if (position (depName, checkedVads) = 0)
        {
          checkedVads := vector_concat (checkedVads, vector (depName));
          depTree := vector_concat (depTree, vector ("VAD"."DBA"."VAD_RESOLVE_DEPENDENCY_TREE" (null, 0, vadDir, vadDirType, availableVads, checkedVads, pkgName, depName, depVer, -1)));
        }
      }
    }

    depVer := cast (xpath_eval ('version/@package', items[i]) as varchar);
    if (depName is not null and length(depVer))
    {
      if (not "VAD"."DBA"."VAD_TEST_PACKAGE_EQ" (parr, depName, depVer))
      {
        -- Check if we need to recurse into the vads deps
        if (position (depName, checkedVads) = 0)
        {
          checkedVads := vector_concat (checkedVads, vector (depName));
          depTree := vector_concat (depTree, vector ("VAD"."DBA"."VAD_RESOLVE_DEPENDENCY_TREE" (null, 0, vadDir, vadDirType, availableVads, checkedVads, pkgName, depName, depVer, 0)));
        }
      }
    }

    depVer := cast (xpath_eval ('versions_later/@package', items[i]) as varchar);
    if (depName is not null and length(depVer))
    {
      --dbg_obj_print('Checking dep ', depName, depVer);
      if (not "VAD"."DBA"."VAD_TEST_PACKAGE_GT" (parr, depName, depVer))
      {
        -- Check if we need to recurse into the vads deps
        if (position (depName, checkedVads) = 0)
        {
          checkedVads := vector_concat (checkedVads, vector (depName));
          depTree := vector_concat (depTree, vector ("VAD"."DBA"."VAD_RESOLVE_DEPENDENCY_TREE" (null, 0, vadDir, vadDirType, availableVads, checkedVads, pkgName, depName, depVer, 1)));
        }
      }
    }
  }

  return vector (
    'name', pkgName,
    'title', pkgTitle,
    'version', pkgVersion,
    'date', pkgDate,
    'path', fname,
    'pathType', is_dav,
    'deps', depTree
  );
}
;

--!
-- Convert the dependency tree into a flat list of package nodes.
--
-- The tree will be traversed depth-first bottom-up. Thus, the list can be installed from first to last.
--/
create procedure "VAD"."DBA"."VAD_FLATTEN_DEPENDENCY_TREE" (
  in depTree any)
{
  declare r, stack, x, deps any;

  r := vector ();

  stack := vector (depTree);
  while (length (stack) > 0)
  {
    -- pop the first element
    x := stack[0];
    stack := subseq (stack, 1);

    -- remember the deps
    deps := get_keyword ('deps', x);

    -- Extract the plain package without deps
    x := vector (
      'name', get_keyword ('name', x),
      'title', get_keyword ('title', x),
      'version', get_keyword ('version', x),
      'date', get_keyword ('date', x),
      'path', get_keyword ('path', x),
      'pathType', get_keyword ('pathType', x)
    );

    -- We reached the bottom, add to our result
    if (length (deps) = 0)
    {
      r := vector_concat (r, vector (x));
    }

    -- Continue our depth traversal by stacking everything
    else
    {
      stack := vector_concat (deps, vector (x), stack);
    }
  }

  return r;
}
;
