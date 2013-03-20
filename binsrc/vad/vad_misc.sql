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
  http (sprintf (' VAD Interface (%s) - Copyright&copy; 1998-2013 OpenLink Software.</P></TD></TR>',"VAD"."DBA"."VAD_VERSION" ()));
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

create procedure "VAD"."DBA"."VERSION_COMPARE"(in s1 varchar, in s2 varchar)
    {
  declare i, j any;
  declare k int;
  i := split_and_decode(s1, 1, '\0\0.');
  j := split_and_decode(s2, 1, '\0\0.');
  k := 0;
  declare a, b int;
  while (k < length(i) or k < length(j))
  {
    if (k < length(i))
      a := atoi(i[k]);
    else
      a := 0;
    if (k < length(j))
      b := atoi(j[k]);
    else
      b := 0;
    if (a < b)
    return -1;
    if (a > b)
    return 1;
  else
      k := k + 1;
  }
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
