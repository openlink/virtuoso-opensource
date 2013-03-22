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

create procedure "VAD"."DBA"."DAV_DELETE_VAD" (
  in path varchar,
  in silent integer := 0,
  in extern integer := 1)
{
  declare id, rc integer;
  declare ty char;
  if (0 > (id := DB.DBA.DAV_SEARCH_ID (path, 'r')))
  {
    if (0 > (id := DB.DBA.DAV_SEARCH_ID (path, 'c')))
      return (case when silent then 1 else id end);
     else
      ty := 'c';
  }
  else
    ty := 'r';
  if (0 <> (rc := DB.DBA.DAV_IS_LOCKED (id , ty)))
    return rc;
  if (ty = 'r')
    delete from WS.WS.SYS_DAV_RES where RES_ID = id;
  else if (ty = 'c')
  {
    declare rrc integer;
    for select RES_FULL_PATH from WS.WS.SYS_DAV_RES where RES_COL = id do
    {
      rrc := "VAD"."DBA"."DAV_DELETE_VAD" (RES_FULL_PATH, silent, extern);
      if (rrc <> 1)
      {
        rollback work;
        return rrc;
      }
    }
    for select COL_ID from WS.WS.SYS_DAV_COL where COL_PARENT = id do
    {
      rrc := "VAD"."DBA"."DAV_DELETE_VAD" (WS.WS.COL_PATH(COL_ID), silent, extern);
      if (rrc <> 1)
      {
        rollback work;
        return rrc;
      }
    }
    delete from WS.WS.SYS_DAV_COL where COL_ID = id;
  }
  else if (not silent)
    return -1;
  return 1;
}
;

create procedure "VAD"."DBA"."BLOB_2_STRING_OUTPUT" (
  in fname varchar,
  in f1 integer,
  in f2 integer,
  inout ses any) returns integer
{
  declare _blob, _part, _to_get any;
  declare flen, offs, buf_sz integer;

  flen := f2 - f1;
  select RES_CONTENT into _blob from ws.ws.sys_dav_res where RES_FULL_PATH=fname;
  -- the common case to get all the blob into a string session
  if (f1 = 0 and length (_blob) = f2)
    {
  ses := string_output ();
      http (_blob, ses);
    }
  else if (flen < 10000000)
    {
      ses := string_output ();
      _part := subseq (_blob, f1, f2);
      http (_part, ses);
    }
  else
    {
      ses := string_output (http_strses_memory_size ());
      _to_get := flen;
      offs := f1;
      buf_sz := 5000000;
      while (1)
	{
	  --dbg_obj_print (offs, offs + buf_sz, _to_get);
	  _part := subseq (_blob, offs, offs + buf_sz);
	  http (_part, ses);
	  offs := offs + buf_sz;

	  if ((offs + buf_sz) > f2)
	     buf_sz := f2 - offs;

	  if (buf_sz <= 0)
	    goto endloop;
	}
      endloop:;
    }

  return 1;
}
;

create procedure "VAD"."DBA"."VAD_DAV_MKCOL" (
  inout ini any,
  in name varchar ) returns integer
{
  declare parr any;
  parr := null;
  if (ini is null or length (ini) = 0)
    ini := "VAD"."DBA"."VAD_READ_INI" (parr);
  declare usr, pwd varchar;
  declare ret integer;
  usr := 'dav';
  pwd := pwd_magic_calc('dav', (select U_PWD from WS.WS.SYS_DAV_USER where U_NAME='dav'), 1);
  ret := "DB"."DBA"."DAV_COL_CREATE" (name, '110100100N', usr, NULL, usr, pwd);
  return ret;
}
;

create procedure "VAD"."DBA"."VAD_DAV_MOVE" (
  in name varchar,
  in destination varchar,
  in overwrite int := 1) returns integer
{
  declare usr, pwd varchar;
  declare ret integer;
  usr := 'dav';
  pwd := pwd_magic_calc('dav', (select U_PWD from WS.WS.SYS_DAV_USER where U_NAME='dav'), 1);
  ret := "DB"."DBA"."DAV_MOVE" (name, destination, overwrite, usr, pwd);
  return ret;
}
;

create procedure "VAD"."DBA"."VAD_DAV_GET_RES" (
  inout ini any,
  in name varchar,
  inout data any ) returns integer
{
  declare parr any;
  parr := null;
  if (ini is null or length (ini) = 0)
    ini := "VAD"."DBA"."VAD_READ_INI" (parr);
  declare usr, pwd varchar;
  usr := 'dav';
  pwd := pwd_magic_calc('dav', (select U_PWD from WS.WS.SYS_DAV_USER where U_NAME='dav'), 1);
  declare ret integer;
  ret := "DB"."DBA"."DAV_RES_GET" (name, data, usr, pwd);
  return ret;
}
;

create procedure "VAD"."DBA"."VAD_DAV_UPLOAD_RES" (
  inout ini any,
  in name varchar,
  inout data any,
  in dav_owner varchar,
  in dav_grp varchar,
  in dav_perm varchar) returns integer
{
  declare parr any;
  parr := null;
  if (ini is null or length (ini) = 0)
    ini := "VAD"."DBA"."VAD_READ_INI" (parr);
  declare usr, pwd varchar;
  declare ret integer;
  usr := 'dav';
  pwd := pwd_magic_calc('dav', (select U_PWD from WS.WS.SYS_DAV_USER where U_NAME='dav'), 1);
  ret := "DB"."DBA"."DAV_RES_UPLOAD_STRSES" (name, data, '', dav_perm, dav_owner, dav_grp, usr, pwd);
  return ret;
}
;

create procedure "VAD"."DBA"."VAD_DAV_DELETE" (
  inout ini any,
  in name varchar ) returns integer
{
  declare parr any;
  parr := null;
  if (ini is null or length (ini) = 0)
    ini := "VAD"."DBA"."VAD_READ_INI" (parr);
  declare ret integer;
  ret := "VAD"."DBA"."DAV_DELETE_VAD" (name, 0);
  return ret;
}
;

create procedure "VAD"."DBA"."VAD_MD5_FILE" (
  in fname varchar,
  in is_dav integer)
{
  declare _len integer;
  declare i, j integer;
  declare ctx varchar;
  ctx := md5_init();
  if (is_dav = 0)
    _len := cast (file_stat (fname, 1) as integer);
  else
    _len := (select length (RES_CONTENT) from ws.ws.sys_dav_res where RES_FULL_PATH=fname);
  declare data varchar;
  i := 0;
  while (i < _len)
    {
    j := i + 4096;
    if (j > _len)
      j := _len;
    if (is_dav = 0)
      data := cast (file_to_string_output (fname, i, j) as varchar);
    else
    {
      select subseq (RES_CONTENT, i, j) into data from WS.WS.SYS_DAV_RES where RES_FULL_PATH = fname;
    }
      ctx := md5_update (ctx, data);
    i := i + 4096;
  }
  ctx := md5_final (ctx);
  return ctx;
}
;

create procedure "VAD"."DBA"."VAD_SPLIT_PATH" (
  in fpath varchar,
  inout path varchar,
  inout name varchar )
{
  declare idx, idx2 integer;
  idx := strrchr (fpath, '/');
  idx2 := strrchr (fpath, '\\');
  if (idx is not null or idx2 is not null)
  {
    if (idx is not null)
      {
      if (idx2 is not null)
        {
        if (idx < idx2)
          idx := idx2;
      }
    }
    else
      {
      if (idx2 is not null)
        idx := idx2;
    }
    path := subseq (fpath, 0, idx);
    name := subseq (fpath, idx + 1, length (fpath));
  }
}
;

create procedure "VAD"."DBA"."VAD_OUT_CHAR" (
  inout ses any,
  inout pos integer,
  in val integer,
  inout ctx varchar )
{
  declare s varchar;
  s := ' ';
  aset(s,0,val);
  string_to_file (ses, s, -1);
  ctx := md5_update (ctx, s);
  pos := pos + 1;
}
;

create procedure "VAD"."DBA"."VAD_GET_CHAR" (
  inout ses any,
  inout pos integer)
{
  declare s varchar;
  declare c integer;

  s := ses_read (ses, 1);
  pos := pos + 1;

  c := aref (s, 0);

  return c;
}
;

create procedure "VAD"."DBA"."VAD_OUT_LONG" (
  inout ses any,
  inout pos integer,
  in val integer,
  inout ctx varchar  )
{
  declare v1, v2, v3, v4 integer;

  v1 := mod (val, 256);
  if (v1 < 0)
    v1 := -v1;
  v2 := mod (val, 256 * 256);
  if (v2 < 0)
    v2 := -v2;
  v2 := v2 / 256;

  v3 := mod (val, 256 * 256 * 256);
  if (v3 < 0)
    v3 := -v3;
  v3 := v3 / (256 * 256);

  v4 := (((val) / 256) / 256) / 256;

  "VAD"."DBA"."VAD_OUT_CHAR" (ses, pos, v4, ctx);
  "VAD"."DBA"."VAD_OUT_CHAR" (ses, pos, v3, ctx);
  "VAD"."DBA"."VAD_OUT_CHAR" (ses, pos, v2, ctx);
  "VAD"."DBA"."VAD_OUT_CHAR" (ses, pos, v1, ctx);
}
;


create procedure "VAD"."DBA"."VAD_GET_LONG" (
  inout ses any,
  inout pos integer)
{
  declare v1, v2, v3, v4 integer;
  declare tmp, str varchar;

  str := cast (ses_read (ses, 4) as varchar);
  pos := pos + 4;

  v4 := str[0];
  v3 := str[1];
  v2 := str[2];
  v1 := str[3];

  return v1 + 256 * ( v2 + 256 * ( v3 + 256 * ( v4 )));
}
;

create procedure "VAD"."DBA"."VAD_OUT_ROW" (
  inout ses any,
  inout pos integer,
  in name varchar,
  inout data any,
  inout ctx varchar )
{
  "VAD"."DBA"."VAD_OUT_CHAR" (ses, pos, 182, ctx);
  declare _len integer;
  _len := length (name);
  "VAD"."DBA"."VAD_OUT_LONG" (ses, pos, _len, ctx);
  declare i integer;
  i:=0;
  while (i<_len)
  {
    "VAD"."DBA"."VAD_OUT_CHAR" (ses, pos, aref (name, i), ctx);
    i := i + 1;
  }
  "VAD"."DBA"."VAD_OUT_CHAR" (ses, pos, 223, ctx);
  _len := length (data);
  "VAD"."DBA"."VAD_OUT_LONG" (ses, pos, _len, ctx);
  ctx := md5_update (ctx, data);
  string_to_file (ses, data, -1);
}
;

create procedure "VAD"."DBA"."VAD_OUT_ROW_FILE" (
  inout ses any,
  inout pos integer,
  in name varchar,
  in fname varchar,
  inout ctx varchar )
{
  if (file_stat(fname, 3) = 0)
  {
    "VAD"."DBA"."VAD_FAIL_CHECK" (sprintf('Inexistent file resource (%s)', fname));
  }
  "VAD"."DBA"."VAD_OUT_CHAR" (ses, pos, 182, ctx);
  declare _len integer;
  _len := length (name);
  "VAD"."DBA"."VAD_OUT_LONG" (ses, pos, _len, ctx);
  declare i, j integer;
  i := 0;
  while (i<_len)
  {
    "VAD"."DBA"."VAD_OUT_CHAR" (ses, pos, aref (name, i), ctx);
    i := i + 1;
  }
  _len := cast (file_stat (fname, 1) as integer);
  "VAD"."DBA"."VAD_OUT_CHAR" (ses, pos, 223, ctx);
  "VAD"."DBA"."VAD_OUT_LONG" (ses, pos, _len, ctx);
  declare data varchar;
  i := 0;
  while (i<_len)
  {
    j := i + 4096;
    if (j > _len)
      j := _len;
    data := cast (file_to_string_output (fname, i, j) as varchar);
    ctx := md5_update (ctx, data);
    string_to_file (ses, data, -1);
    i := i + 4096;
  }
}
;

create procedure "VAD"."DBA"."VAD_OUT_ROW_DAV" (
  inout ses any,
  inout pos integer,
  in name varchar,
  in fname varchar,
  inout ctx varchar,
  inout ini any )
{
  "VAD"."DBA"."VAD_OUT_CHAR" (ses, pos, 182, ctx);
  declare _len integer;
  _len := length (name);
  "VAD"."DBA"."VAD_OUT_LONG" (ses, pos, _len, ctx);
  declare i, j integer;
  i := 0;
  while (i < _len)
  {
    "VAD"."DBA"."VAD_OUT_CHAR" (ses, pos, aref (name, i), ctx);
    i := i + 1;
  }
  declare data varchar;
  declare tmp any;
  declare search_id integer;
  search_id := DB.DBA.DAV_SEARCH_ID (fname, 'R');
  if (search_id < 0)
    "VAD"."DBA"."VAD_FAIL_CHECK" (sprintf('Inexistent DAV resource (%s)', name));
  select RES_CONTENT into tmp from WS.WS.SYS_DAV_RES
    where RES_ID = search_id;
  if (length (tmp) > 10000000)
    {
      data := string_output ();
      http (tmp, data);
    }
  else
    data := blob_to_string (tmp);
  _len := length (data);
  "VAD"."DBA"."VAD_OUT_CHAR" (ses, pos, 223, ctx);
  "VAD"."DBA"."VAD_OUT_LONG" (ses, pos, _len, ctx);
   ctx := md5_update (ctx, data);
   string_to_file (ses, data, -1);
}
;


create procedure "VAD"."DBA"."VAD_GET_ROW" (
  inout ses any,
  inout pos integer,
  inout name varchar,
  inout data any)
{
  declare val integer;
  declare _len integer;

  val := "VAD"."DBA"."VAD_GET_CHAR" (ses, pos);
  if (val <> 182)
    "VAD"."DBA"."VAD_FAIL_CHECK" (sprintf('VAD file corrupt (pos=%d)', pos));
  _len := "VAD"."DBA"."VAD_GET_LONG" (ses, pos);
  name := cast (ses_read (ses, _len) as varchar);
  pos := pos + _len;

  val := "VAD"."DBA"."VAD_GET_CHAR" (ses, pos);
  if (val <> 223)
    "VAD"."DBA"."VAD_FAIL_CHECK" (sprintf('VAD file corrupt (pos=%d)', pos));
  _len := "VAD"."DBA"."VAD_GET_LONG" (ses, pos);
  if (0 <> _len) 
    data := ses_read (ses, _len);
  else
    data := '';
  pos := pos + _len;

  if (equ (name, 'MD5'))
    return 0;

  return 1;
}
;


create procedure "VAD"."DBA"."VAD_GET_ROW_FILE" (
  inout ses any,
  inout pos integer,
  inout name varchar,
  inout resources any,
  inout iniarr any,
  in is_dav integer )
{
  declare val integer;
  declare _len integer;
  declare data any;

  val := "VAD"."DBA"."VAD_GET_CHAR" (ses, pos);
  if (val <> 182)
    "VAD"."DBA"."VAD_FAIL_CHECK" (sprintf('VAD file corrupt (pos=%d)', pos));
  _len := "VAD"."DBA"."VAD_GET_LONG" (ses, pos);
  name := cast (ses_read (ses, _len) as varchar);
  pos := pos + _len;

  val := "VAD"."DBA"."VAD_GET_CHAR" (ses, pos);
  if (val <> 223)
    "VAD"."DBA"."VAD_FAIL_CHECK" (sprintf('VAD file corrupt (pos=%d)', pos));
  _len := "VAD"."DBA"."VAD_GET_LONG" (ses, pos);
  if (0 <> _len) 
    data := ses_read (ses, _len, 1);
  else
    data := '';
  pos := pos + _len;

  if (equ (name, 'MD5'))
    return 0;

  declare s, s2, s3, s4, s5, s6, s7, s8, s9 varchar;
  declare tarr any;

  tarr := get_keyword (name, resources);

  if (tarr is null or length (tarr) = 0)
    "VAD"."DBA"."VAD_FAIL_CHECK" (sprintf ('Illegal item(%s) in package ', name));

  s4 := aref (tarr, 0);
  s5 := aref (tarr, 1);
  s6 := aref (tarr, 2);
  s3 := get_keyword (s4, iniarr);
  s7 := aref (tarr, 3);
  s8 := aref (tarr, 4);
  s9 := aref (tarr, 5);

  if (s3 is null or not length (s3))
    "VAD"."DBA"."VAD_FAIL_CHECK" (sprintf ('Item(%s) has illegal type', s4));

  declare i, j, k integer;

  if (s4 <> 'dav')
  {
    s4 := sprintf ('%s/%s', s3, name);
    declare continue handler for sqlstate '39000' { goto error_nofile; };
    declare continue handler for sqlstate '42000' { goto error_nofile; };
    val := cast (file_stat (s4, 1) as integer);
    goto file_ok;
    if (0)
    {
      error_nofile:;
      "VAD"."DBA"."VAD_FAIL_CHECK" (sprintf('Inexistent file resource (%s).', s4));
      return 0;
    }
    val := null;
    file_ok:;
    declare server_root varchar;
    server_root := http_root();
    s4 := concat(server_root, '/', s4);
    "VAD"."DBA"."VAD_SPLIT_PATH" (s4, s2, s3);
    if (s5 is null or length(s5)=0)
      s5 := 'equal';
    if (equ (s5, 'yes'))
    {
      goto do_it;
    }
    else if (equ (s5, 'no'))
    {
      if (val is null)
        goto do_it;
    }
    else if (equ (s5, 'equal'))
    {
      if (val is null or val <> _len)
        goto do_it;
      declare md5_txt, nctx varchar;
      nctx := md5_init();
        nctx := md5_update (nctx, data);
      if (neq ("VAD"."DBA"."VAD_MD5_FILE" (s4, is_dav), md5_final (nctx)))
        goto do_it;
    }
    else if (equ (s5, 'abort'))
    {
      if (val is not null)
        "VAD"."DBA"."VAD_FAIL_CHECK" (sprintf ('package registry item (%s) exists & overwrite=abort', s2));
      goto do_it;
    }
    else if (equ (s5, 'expected'))
    {
      ;
    }
    return 1;
    do_it:;
    "DB"."DBA"."VAD_CREATE_PATH"(s2);
    --if (not sys_mkpath (s2, 1))
    --  goto do_it_again;
    if (s6 is null or length(s6)=0)
      s6 := 'abort';
    if (equ (s6, 'yes'))
    {
      goto do_it_again;
    }
    else if (equ (s6, 'abort') or equ (s6, 'no'))
    {
      if (s2 is not null or length(s2))
        "VAD"."DBA"."VAD_FAIL_CHECK" (sprintf ('mkpath forbidden (%s)', s2));
    }
    do_it_again:;
    -- sys_mkpath (s2);
    "DB"."DBA"."VAD_CREATE_PATH"(s2);
    string_to_file (s4, '', -2);
      string_to_file (s4, data, -1);
    return 1;
  }
  else
  {
    declare vdata varchar;
    declare id, gd integer;
    id := 0;
    gd := 0;
    s4 := sprintf ('%s/%s', s3, name);
    "VAD"."DBA"."VAD_SPLIT_PATH" (s4, s2, s3);
    if ("VAD"."DBA"."VAD_DAV_GET_RES" (iniarr, s4, vdata) < 0)
      goto do_itII;
    val := length (vdata);
    if (s5 is null or length(s5)=0)
      s5 := 'equal';
    if (equ (s5, 'yes'))
    {
      goto do_itII;
    }
    else if (equ (s5, 'no'))
    {
      if (val is null)
        goto do_itII;
    }
    else if (equ (s5, 'equal'))
    {
      if (val is null or val <> _len)
        goto do_itII;
      if (neq ("VAD"."DBA"."VAD_MD5_FILE" (s4, is_dav), md5 (vdata)))
        goto do_itII;
    }
    else if (equ (s5, 'abort'))
    {
      if (val is not null)
        "VAD"."DBA"."VAD_FAIL_CHECK" (sprintf ('package registry item (%s) exists & overwrite=abort', s2));
      goto do_itII;
    }
    else if (equ (s5, 'expected'))
    {
      ;
    }
    return 1;
    do_itII:;
    "VAD"."DBA"."VAD_MKDAV" (id, gd, s2, iniarr, 1);
    if (k < 0)
      goto do_it_againII;
    if (s6 is null or length(s6)=0)
      s6 := 'abort';
    if (equ (s6, 'yes'))
    {
      goto do_it_againII;
    }
    else if (equ (s6, 'abort') or equ (s6, 'no'))
    {
      if (s2 is not null or length(s2))
        "VAD"."DBA"."VAD_FAIL_CHECK" (sprintf ('mkpath forbidden (%s)', s2));
    }
    do_it_againII:;
    k := "VAD"."DBA"."VAD_MKDAV" (id, gd, s2, iniarr);
    if (k < 1)
      "VAD"."DBA"."VAD_FAIL_CHECK" (sprintf ('Can\'t create collection (%s)', s2));
    if (val is not null and val > 0)
      "VAD"."DBA"."VAD_DAV_UPLOAD_RES" (iniarr, s4, data, s7, s8, s9);
    return 1;
  }
}
;

create procedure "VAD"."DBA"."VAD_TEST_CREATE" (
  in arr any,
  in fname varchar,
  in sticker varchar,
  in iniarr any := null )
{
  declare ctx varchar;
  ctx := md5_init();
  declare ses any;
  ses := string_output ();
  declare pos integer;
  pos := 0;
  if (iniarr is null)
    iniarr := "VAD"."DBA"."VAD_READ_INI" (arr);
  declare data any;
  declare continue handler for sqlstate '39000' { goto error_nofile; };
  declare continue handler for sqlstate '42000' { goto error_nofile; };
  string_to_file (fname, '', -2);
  error_nofile:;
  declare _err_code, _err_message varchar;
  declare exit handler for sqlstate '39000' { _err_code := __SQL_STATE; _err_message := __SQL_MESSAGE; goto error_fin; };
  declare exit handler for sqlstate '42000' { _err_code := __SQL_STATE; _err_message := __SQL_MESSAGE; goto error_fin; };
  data := 'This file consists of binary data and should not be touched by hands!';
  "VAD"."DBA"."VAD_OUT_ROW" (fname, pos, 'VAD', data, ctx);
  "VAD"."DBA"."VAD_OUT_ROW" (fname, pos, 'STICKER', sticker, ctx);
  declare i,r integer;
  data := string_output ();
  r := rnd(100);
  while (i < 1000)
  {
    http (sprintf('%09d ',i+r), data);
    i := i + 1;
  }
  declare tree, doc, items any;
  tree := xml_tree (sticker);
  doc := xml_tree_doc (tree);
  declare j, n integer;
  declare s2, s3, s4, s5, s6 varchar;
  items := xpath_eval ('/sticker/resources/file', doc, 0);
  n := length (items);
  j := 0;
  while (j<n)
  {
    s2 := cast (xpath_eval ('@type', aref (items, j)) as varchar);
    s6 := cast (xpath_eval ('@source', aref (items, j)) as varchar);
    s5 := cast (xpath_eval ('@source_uri', aref (items, j)) as varchar);
    s3 := cast (xpath_eval ('@target_uri', aref (items, j)) as varchar);
    s4 := get_keyword (s6, iniarr);
    if (s4 is null or length(s4)=0)
    {
      _err_message := sprintf ('Illegal resource type:%s for %s', s2,s3);
      goto error_fin;
    }
    if (s5 is null or length(s5)=0)
    {
      s5 := sprintf ('%s/%s', s4, s3);
    }
    if (neq (s6, 'dav'))
      "VAD"."DBA"."VAD_OUT_ROW_FILE" (fname, pos, s3, s5, ctx);
    else
      "VAD"."DBA"."VAD_OUT_ROW_DAV" (fname, pos, s3, s5, ctx, iniarr);
    j := j + 1;
  }
  data := md5_final (ctx);
  "VAD"."DBA"."VAD_OUT_ROW" (fname, pos, 'MD5', data, ctx);
  return 1;
  error_fin:
  "VAD"."DBA"."VAD_FAIL_CHECK" (_err_message);
  return 0;
}
;

create procedure "DB"."DBA"."VAD_CHECK_INSTALLABILITY" (
  in fname varchar,
  in is_dav integer) returns varchar
{
  declare name, vers, fullname, pkg_date any;
  "VAD"."DBA"."VAD_TEST_READ" (fname, name, vers, fullname, pkg_date, is_dav);
  return 'OK';
}
;

create procedure "VAD"."DBA"."VAD_CHECK_STICKER_DETAILS" (
  inout parr any,
  in doc any,
  inout pkg_name varchar,
  inout pkg_vers varchar,
  inout pkg_fullname varchar,
  inout pkg_date varchar,
  in need_action integer := 0 )
{
  declare ddl_install_check_code, proc_install_check_code, s2, s3 varchar;
  declare n, j, tid, tid2, pkgid integer;
  declare items any;

  ddl_install_check_code := NULL;
  proc_install_check_code := NULL;
  items := xpath_eval ('/sticker/caption/name/@package', doc, 0);
  n := length (items);
  if (n = 0)
    "VAD"."DBA"."VAD_FAIL_CHECK" ('VAD sticker should have name in "/sticker/caption/name/@package"');
  pkg_name := cast (aref (items, 0) as varchar);
  items := xpath_eval ('/sticker/caption/version/@package', doc, 0);
  n := length (items);
  if (n = 0)
    "VAD"."DBA"."VAD_FAIL_CHECK" ('VAD sticker should have version in "/sticker/caption/version/@package"');
  pkg_vers := cast (aref (items, 0) as varchar);

  s3 := concat(pkg_name, '/', pkg_vers);
  s2 := "VAD"."DBA"."VAD_CHECK_FOR_HIGH_VERSION"(s3);
  if (s2 <> '0' and s2 <> '-1')
    "VAD"."DBA"."VAD_FAIL_CHECK" (sprintf ('The package "%s" with higher version %s is already installed. Current installing package version is %s.', pkg_name, s2, pkg_vers));
  if (s2 = '-1')
    "VAD"."DBA"."VAD_FAIL_CHECK" (sprintf ('The package "%s" has incorrect name or version', s3));
  items := xpath_eval ('/sticker/caption/name/prop[@name=\'Title\']', doc, 0);
  n := length (items);
  if (n = 0)
    "VAD"."DBA"."VAD_FAIL_CHECK" ('VAD sticker should mention the title in /sticker/caption/name/prop[@name=\'Title\']');
  s2 := cast (xpath_eval ('@value', aref (items, 0)) as varchar);
  pkg_fullname := s2;
  pkgid := "VAD"."DBA"."VAD_GET_PKG_ID" (parr, pkg_name, pkg_vers);
  --if (pkgid)
  --  "VAD"."DBA"."VAD_FAIL_CHECK" (sprintf ('There exists such package: %s/%s', pkg_name, pkg_vers));
  if (not pkgid and need_action)
    pkgid := "VAD"."DBA"."VAD_NEW_PACKAGE"(parr, pkg_name, pkg_vers);
  items := xpath_eval ('/sticker/caption/name/prop[@name=\'Title\']', doc, 0);
  n := length (items);
  if (n = 0)
    "VAD"."DBA"."VAD_FAIL_CHECK" ('VAD sticker should mention the title in /sticker/caption/name/prop[@name=\'Title\']');
  s2 := cast (xpath_eval ('@value', aref (items, 0)) as varchar);
  pkg_fullname := s2;
  if (need_action)
    "VAD"."DBA"."VAD_MKNODE" (parr, pkgid, 'Title', 'STRING', s2);
  items := xpath_eval ('/sticker/caption/name/prop[@name=\'Developer\']', doc, 0);
  n := length (items);
  if (n = 0)
    "VAD"."DBA"."VAD_FAIL_CHECK" ('VAD sticker should mention the developer in /sticker/caption/name/prop[@name=\'Developer\']');
  s2 := cast (xpath_eval ('@value', aref (items, 0)) as varchar);
  if (need_action)
    "VAD"."DBA"."VAD_MKNODE" (parr, pkgid, 'Developer', 'STRING', s2);
  items := xpath_eval ('/sticker/caption/name/prop[@name=\'Copyright\']', doc, 0);
  n := length (items);
  if (n = 0)
    "VAD"."DBA"."VAD_FAIL_CHECK" ('VAD sticker should mention the Copyright in /sticker/caption/name/prop[@name=\'Copyright\']');
  s2 := cast (xpath_eval ('@value', aref (items, 0)) as varchar);
  if (need_action)
    "VAD"."DBA"."VAD_MKNODE" (parr, pkgid, 'Copyright', 'STRING', s2);
  items := xpath_eval ('/sticker/caption/version/prop[@name=\'Release Date\']', doc, 0);
  n := length (items);
  if (n = 0)
    "VAD"."DBA"."VAD_FAIL_CHECK" ('VAD sticker should mention the Release Date in /sticker/caption/version/prop[@name=\'Release Date\']');
  s2 := cast (xpath_eval ('@value', aref (items, 0)) as varchar);
  pkg_date := s2;
  if (need_action)
    {
      "VAD"."DBA"."VAD_MKNODE" (parr, pkgid, 'Release Date', 'STRING', s2);
      "VAD"."DBA"."VAD_MKNODE" (parr, pkgid, 'Install Date', 'STRING',
    substring (cast (now () as varchar), 1, 16));
    }
  items := xpath_eval ('/sticker/caption/version/prop[@name=\'Build\']', doc, 0);
  n := length (items);
  if (n = 0)
    "VAD"."DBA"."VAD_FAIL_CHECK" ('VAD sticker should mention the Build in /sticker/caption/version/prop[@name=\'Build\']');
  s2 := cast (xpath_eval ('@value', aref (items, 0)) as varchar);
  if (need_action)
    "VAD"."DBA"."VAD_MKNODE" (parr, pkgid, 'Build', 'STRING', s2);
  if (need_action)
    tid := "VAD"."DBA"."VAD_MKDIR" (parr, pkgid, 'Download');
  items := xpath_eval ('/sticker/caption/name/prop[@name=\'Download\']', doc, 0);
  n := length (items);
  if (n = 0)
    "VAD"."DBA"."VAD_FAIL_CHECK" ('VAD sticker should mention the Download places in /sticker/caption/name/prop[@name=\'Download\']');
  if (need_action)
  {
    j := 0;
    while (j<n)
    {
      s2 := cast (xpath_eval ('@value', aref (items, j)) as varchar);
      "VAD"."DBA"."VAD_MKNODE" (parr, tid, cast (j + 1 as varchar), 'STRING', s2);
      j := j + 1;
    }
  }
  if (need_action)
  {
    tid2 := "VAD"."DBA"."VAD_MKDIR" (parr, pkgid, 'require');
    tid := "VAD"."DBA"."VAD_MKDIR" (parr, tid2, 'lt');
    tid := "VAD"."DBA"."VAD_MKDIR" (parr, tid2, 'eq');
    tid := "VAD"."DBA"."VAD_MKDIR" (parr, tid2, 'gt');
  }
  items := xpath_eval ('/sticker/dependencies/require', doc, 0);
  n := length (items);
  j := 0;
  while (j<n)
  {
    s2 := cast (xpath_eval ('name/@package', aref (items, j)) as varchar);
    s3 := cast (xpath_eval ('versions_earlier/@package', aref (items, j)) as varchar);
    if (s2 is not null and length(s3))
    {
      if (need_action)
      {
        tid := "VAD"."DBA"."VAD_CHDIR" (parr, tid2, 'lt');
        tid := "VAD"."DBA"."VAD_MKNODE" (parr, tid, s2, 'STRING', s3);
      }
      if (not "VAD"."DBA"."VAD_TEST_PACKAGE_LT" (parr, s2, s3))
        "VAD"."DBA"."VAD_FAIL_CHECK" (sprintf ('This package requires %s version less than %s', s2, s3));
    }
    s3 := cast (xpath_eval ('version/@package', aref (items, j)) as varchar);
    if (s2 is not null and length(s3))
    {
      if (need_action)
      {
        tid := "VAD"."DBA"."VAD_CHDIR" (parr, tid2, 'eq');
        tid := "VAD"."DBA"."VAD_MKNODE" (parr, tid, s2, 'STRING', s3);
      }
      if (not "VAD"."DBA"."VAD_TEST_PACKAGE_EQ" (parr, s2, s3))
        "VAD"."DBA"."VAD_FAIL_CHECK" (sprintf ('This package requires %s version %s', s2, s3));
    }
    s3 := cast (xpath_eval ('versions_later/@package', aref (items, j)) as varchar);
    if (s2 is not null and length(s3))
    {
      if (need_action)
      {
        tid := "VAD"."DBA"."VAD_CHDIR" (parr, tid2, 'gt');
        tid := "VAD"."DBA"."VAD_MKNODE" (parr, tid, s2, 'STRING', s3);
      }
      if (not "VAD"."DBA"."VAD_TEST_PACKAGE_GT" (parr, s2, s3))
        "VAD"."DBA"."VAD_FAIL_CHECK" (sprintf ('This package requires %s version greater than %s', s2, s3));
    }
    j := j + 1;
  }
  if (need_action)
  {
    tid2 := "VAD"."DBA"."VAD_MKDIR" (parr, pkgid, 'conflicts');
    tid := "VAD"."DBA"."VAD_MKDIR" (parr, tid2, 'lt');
    tid := "VAD"."DBA"."VAD_MKDIR" (parr, tid2, 'eq');
    tid := "VAD"."DBA"."VAD_MKDIR" (parr, tid2, 'gt');
  }
  items := xpath_eval ('/sticker/dependencies/conflict', doc, 0);
  n := length (items);
  j := 0;
  while (j<n)
  {
    s2 := cast (xpath_eval ('name/@package', aref (items, j)) as varchar);
    s3 := cast (xpath_eval ('versions_earlier/@package', aref (items, j)) as varchar);
    if (s2 is not null and length(s3))
    {
      if (need_action)
      {
          tid := "VAD"."DBA"."VAD_CHDIR" (parr, tid2, 'lt');
        tid := "VAD"."DBA"."VAD_MKNODE" (parr, tid, s2, 'STRING', s3);
      }
      if ("VAD"."DBA"."VAD_TEST_PACKAGE_LT" (parr, s2, s3))
      {
        "VAD"."DBA"."VAD_FAIL_CHECK" (sprintf ('package conflicts with %s lt(%s) ', s2, s3));
          rollback work;
      }
    }
    s3 := cast (xpath_eval ('version/@package', aref (items, j)) as varchar);
    if (s2 is not null and length(s3))
    {
      if (need_action)
      {
        tid := "VAD"."DBA"."VAD_CHDIR" (parr, tid2, 'eq');
        tid := "VAD"."DBA"."VAD_MKNODE" (parr, tid, s2, 'STRING', s3);
      }
      if ("VAD"."DBA"."VAD_TEST_PACKAGE_EQ" (parr, s2, s3))
        "VAD"."DBA"."VAD_FAIL_CHECK" (sprintf ('package conflicts with %s eq(%s) ', s2, s3));
    }
    s3 := cast (xpath_eval ('versions_later/@package', aref (items, j)) as varchar);
    if (s2 is not null and length(s3))
    {
      if (need_action)
      {
          tid := "VAD"."DBA"."VAD_CHDIR" (parr, tid2, 'gt');
        tid := "VAD"."DBA"."VAD_MKNODE" (parr, tid, s2, 'STRING', s3);
      }
      if ("VAD"."DBA"."VAD_TEST_PACKAGE_GT" (parr, s2, s3))
        "VAD"."DBA"."VAD_FAIL_CHECK" (sprintf ('package conflicts with %s gt(%s) ', s2, s3));
    }
    j := j + 1;
  }
  items := xpath_eval ('/sticker/ddls/sql[@purpose=\'install-check\']', doc, 0);
  n := length (items);
  if (n<>0)
  {
    ddl_install_check_code := cast (xpath_eval ('node()', aref (items, 0)) as varchar);
    if (need_action)
    "VAD"."DBA"."VAD_MKNODE" (parr, pkgid, 'ddl-install-check', 'STRING', ddl_install_check_code);
  }
  items := xpath_eval ('/sticker/ddls/sql[@purpose=\'install-check\']', doc, 0);
  n := length (items);
  if (n<>0)
  {
    proc_install_check_code := cast (xpath_eval ('node()', aref (items, 0)) as varchar);
    if (need_action)
        "VAD"."DBA"."VAD_MKNODE" (parr, pkgid, 'proc-install-check', 'STRING', proc_install_check_code);
  }
  if (need_action)
    "VAD"."DBA"."VAD_EXEC" (ddl_install_check_code);
  if (need_action)
    "VAD"."DBA"."VAD_EXEC" (proc_install_check_code);
  return 1;
}
;

create procedure "VAD"."DBA"."VAD_GET_STICKER_DATA_LEN" (
  in fname varchar,
  in is_dav integer )
{
  declare flen, pos, i, n, statusid integer;
  declare s varchar;
  declare data any;
  declare val integer;
  declare _len integer;

  pos := 0;
  flen := 200; -- must be sufficient to get sticker len
  declare v1, v2, parr any;
  parr := null;
  declare continue handler for sqlstate '39000' { goto error_nofile; };
  declare continue handler for sqlstate '42000' { goto error_nofile; };

  if (is_dav = 0)
  {
    v1 := file_to_string_output (fname, 0, flen);
  }
  else
  {
    v1 := string_output();
    "VAD"."DBA"."BLOB_2_STRING_OUTPUT"(fname, 0, flen, v1);
  }

  "VAD"."DBA"."VAD_GET_ROW" (v1, pos, s, data);
  if (s <> 'VAD')
    "VAD"."DBA"."VAD_FAIL_CHECK" ('VAD file with illegal header');
  val := "VAD"."DBA"."VAD_GET_CHAR" (v1, pos);
  if (val <> 182)
    "VAD"."DBA"."VAD_FAIL_CHECK" (sprintf('VAD file corrupt (pos=%d)', pos));
  _len := "VAD"."DBA"."VAD_GET_LONG" (v1, pos);
  s := cast (ses_read (v1, _len) as varchar);
  pos := pos + _len;
  if (s <> 'STICKER')
    "VAD"."DBA"."VAD_FAIL_CHECK" ('VAD file with illegal sticker');
  val := "VAD"."DBA"."VAD_GET_CHAR" (v1, pos);
  if (val <> 223)
    "VAD"."DBA"."VAD_FAIL_CHECK" (sprintf('VAD file corrupt (pos=%d)', pos));
  _len := "VAD"."DBA"."VAD_GET_LONG" (v1, pos);
  return pos + _len;
  error_nofile:
  "VAD"."DBA"."VAD_FAIL_CHECK" (sprintf ('VAD file (%s) problems:\n%s', fname, __SQL_MESSAGE));
}
;

create procedure "VAD"."DBA"."VAD_TEST_READ" (
  in fname varchar,
  inout pkg_name varchar,
  inout pkg_vers varchar,
  inout pkg_fullname varchar,
  inout pkg_date varchar,
  in is_dav integer,
  in fast_no_md5 integer := 0)
{
  declare flen, pos, i, n, statusid integer;
  declare fstat integer;
  declare s varchar;
  declare data any;
  pos := 0;
  if (is_dav = 0)
  {
    fstat := file_stat (fname, 1);
    if (fstat is null or fstat = 0)
      "VAD"."DBA"."VAD_FAIL_CHECK" (concat ('Could not open filesystem resource ', fname, ' Reason: File not found'));
  }
  else
  {
    declare _i integer;
    _i := 0;
    fstat := 0;
    for select length (RES_CONTENT) as _temp_content from ws.ws.sys_dav_res where RES_FULL_PATH=fname do
    {
      _i := _i + 1;
      fstat := _temp_content;
    }
    if (_i = 0)
    {
      if (fstat is null or fstat = 0)
        "VAD"."DBA"."VAD_FAIL_CHECK" (concat ('Could not open DAV resource ', fname, ' Reason: File not found'));
    }
  }
  flen := cast (fstat as integer);
  declare v1, v2, parr any;
  parr := null;
  declare continue handler for sqlstate '39000' { goto error_nofile; };
  declare continue handler for sqlstate '42000' { goto error_nofile; };

  if (fast_no_md5)
    flen := "VAD"."DBA"."VAD_GET_STICKER_DATA_LEN" (fname, is_dav);

  if (is_dav = 0)
  {
    v1 := file_to_string_output (fname, 0, flen);
  }
  else
  {
    v1 := string_output();
    "VAD"."DBA"."BLOB_2_STRING_OUTPUT"(fname, 0, flen, v1);
  }

  if (fast_no_md5 = 0)
  {
    --  Get md5 checksum from package
    v2 := cast (subseq (v1, flen-32, flen) as varchar);

    -- Check MD5 sum before trying to install package
    declare md5package varchar;
    md5package := md5(subseq (v1, 0, flen-45));
    if (neq (md5package, v2))
      "VAD"."DBA"."VAD_FAIL_CHECK" ('VAD file checksum mismatch');
  }

  i := 0;
  while ("VAD"."DBA"."VAD_GET_ROW" (v1, pos, s, data) <> 0)
  {
    if (i = 0)
    {
      if (s <> 'VAD')
        "VAD"."DBA"."VAD_FAIL_CHECK" ('VAD file with illegal header');
    }
    else if (i = 1)
    {
      declare ddl_install_check_code, proc_install_check_code varchar;
      ddl_install_check_code := NULL;
      proc_install_check_code := NULL;
      declare s2, s3 varchar;
      if (s <> 'STICKER')
        "VAD"."DBA"."VAD_FAIL_CHECK" ('VAD file with illegal sticker');
      declare tree, doc any;
      tree := xml_tree (data);
      doc := xml_tree_doc (tree);
      "VAD"."DBA"."VAD_CHECK_STICKER_DETAILS" (parr, doc, pkg_name, pkg_vers, pkg_fullname, pkg_date);
      return 1;
    }
    i := i + 1;
  }
  return 0;
  error_nofile:
  "VAD"."DBA"."VAD_FAIL_CHECK" (sprintf ('VAD file (%s) problems:\n%s', fname, __SQL_MESSAGE));
}
;

create procedure "DB"."DBA"."VAD_INSTALL" (
  in fname varchar,
  in is_dav integer := 0,
  in no_exit integer := 0) returns varchar
{
  declare parr any;
  declare qual varchar;
  declare SQL_STATE, SQL_MESSAGE varchar;

  commit work;
  if (sys_stat ('cl_run_local_only') = 1)
    exec ('checkpoint');
  else
    {
      exec ('rdf_check_init()');
    cl_exec ('checkpoint');
    }

  qual := dbname ();
  parr := null;
  SQL_STATE := '00000';
  SQL_MESSAGE := '';

  "VAD"."DBA"."VAD_ATOMIC" (1);

  registry_set ('VAD_msg', '');
  registry_set ('VAD_errcount', '0');
  registry_set ('VAD_wet_run', '0');
  registry_set ('VAD_is_run', '1');
  connection_set ('vad_pkg_fullname', null);

  result_names (SQL_STATE, SQL_MESSAGE);
  {
    declare exit handler for sqlstate '*'
    {
      SQL_STATE := __SQL_STATE;
      SQL_MESSAGE := __SQL_MESSAGE;
      if ('' <> SQL_MESSAGE);
      {
	log_message (sprintf ('VAD_INSTALL: %s (%s)', SQL_MESSAGE, SQL_STATE));
	result (SQL_STATE, SQL_MESSAGE);
      }
      goto failure;
    };

    "VAD"."DBA"."VAD_READ" (parr, fname, is_dav);
    if ('0' = registry_get ('VAD_errcount'))
    {
      "VAD"."DBA"."VAD_ATOMIC" (0);

      result ('00000', 'No errors detected');
      result ('00000', sprintf ('Installation of "%s" is complete.', coalesce (connection_get ('vad_pkg_fullname'), fname)));

      result ('00000', 'Now making a final checkpoint.');

      if (sys_stat ('cl_run_local_only') = 1)
	exec ('checkpoint');
      else
	cl_exec ('checkpoint');

      result ('00000', 'Final checkpoint is made.');
      result ('00000', 'SUCCESS');
      result ('', '');
      registry_set ('VAD_is_run', '0');
      set_qualifier (qual);
      return 'OK';
    }
  }

failure:;
  result ('00000', 'Errors detected');
  result ('00000', sprintf ('Installation of "%s" was unsuccessful.', coalesce (connection_get ('vad_pkg_fullname'), fname)));

  log_message (sprintf ('Errors where detected during installation of "%s".',
  coalesce (connection_get ('vad_pkg_fullname'), fname)));

  if (registry_get ('VAD_wet_run') = '0')
  {
    -- Since the database was not changed, we do not need to restart the server
    -- from the checkpoint 

    "VAD"."DBA"."VAD_ATOMIC" (0);

    result ('00000', 'ERROR');
    result ('', '');

    registry_set ('VAD_is_run', '0');
    set_qualifier (qual);
    return 'ERROR';
  }
  else
  {
    -- Since the database was changed, we need to restart the server
    -- from the checkpoint 
    declare trx, folder varchar;
    declare pos integer;
    trx := coalesce (cfg_item_value(virtuoso_ini_path(), 'Database','TransactionFile'), '');
    folder := server_root ();
    trx := concat(rtrim(folder, '/'), '/', trx);

    log_message('The installation of this VAD package has failed.');
    log_message('Please delete the transaction file');
    log_message(trx);
    log_message('and then restart your database server.');
    log_message('Note: Your database will be in its pre VAD installation');
    log_message('state after you restart.');

    result ('', 'The installation of this VAD package has failed.');
    result ('', 'Please delete the transaction file '||trx);
    result ('', 'and then restart your database server.');
    result ('', 'Note: Your database will be in its pre VAD installation state after you restart.');

    result ('00000', 'FATAL');
    result ('', '');
    delay(3);
    if (no_exit = 0)
    {
      if (sys_stat ('cl_run_local_only') = 1)
      raw_exit(-1);
      else
	cl_exec ('raw_exit(-1)');
    }

    registry_set ('VAD_is_run', '0');
    set_qualifier (qual);
    return 'FATAL';
  }

  --  Not reached
  registry_set ('VAD_is_run', '0');
  return 'ERROR';
}
;

create procedure "VAD"."DBA"."VAD_READ" (
  inout parr any,
  in fname varchar,
  in is_dav integer,
  in iniarr any := null)
{
  declare flen, pos, i, statusid integer;
  declare s any;
  declare data, resources any;
  declare ddl_pre_install_code,
  ddl_install_check_code,
  ddl_uninstall_check_code,
  ddl_post_install_code,
  ddl_pre_uninstall_code,
  ddl_post_uninstall_code varchar;
  declare proc_pre_install_code,
  proc_install_check_code,
  proc_uninstall_check_code,
  proc_post_install_code,
  proc_pre_uninstall_code,
  proc_post_uninstall_code varchar;
  declare pkg_name varchar;

  pos := 0;
  resources := vector();
  pkg_name := null;
  if (iniarr is null)
    iniarr := "VAD"."DBA"."VAD_READ_INI" (iniarr);
  declare continue handler for sqlstate '39000' { goto error_nofile; };
  declare continue handler for sqlstate '42000' { goto error_nofile; };
  if (is_dav = 0)
  {
    s := file_stat (fname, 1);
    if (s is null or s = 0)
      "VAD"."DBA"."VAD_FAIL_CHECK" (concat ('Could not open filesystem resource ', fname, ' Reason: File not found'));
  }
  else
  {
    declare _i integer;
    _i := 0;
    s := 0;
    for select length (RES_CONTENT) as _temp_content from ws.ws.sys_dav_res where RES_FULL_PATH = fname do
    {
      _i := _i + 1;
      s := cast(_temp_content as varchar);
    }
    if (_i = 0)
    {
      if (s is null or s = 0)
        "VAD"."DBA"."VAD_FAIL_CHECK" (concat ('Could not open DAV resource ', fname, ' Reason: File not found'));
    }
  }
  flen := cast (s as integer);
  declare v1,v2 any;

  if (is_dav = 0)
  {
    v1 := file_to_string_output (fname, 0, flen);
  }
  else
  {
    v1 := string_output();
    "VAD"."DBA"."BLOB_2_STRING_OUTPUT"(fname, 0, flen, v1);
  }

  --  Get md5 checksum from package
  v2 := cast (subseq (v1, flen-32, flen) as varchar);

  -- Check MD5 sum before trying to install package
  declare md5package varchar;
  md5package := md5(subseq (v1, 0, flen-45));
  if (neq (md5package, v2))
    "VAD"."DBA"."VAD_FAIL_CHECK" ('VAD file checksum mismatch');

  i := 0;
  declare flag integer;
  while (1)
  {
    if (i < 2)
      flag := "VAD"."DBA"."VAD_GET_ROW"(v1, pos, s, data);
    else
      flag := "VAD"."DBA"."VAD_GET_ROW_FILE"(v1, pos, s, resources, iniarr, is_dav);
    if (not flag)
      goto fin;
    if (i = 0)
    {
      if (s <> 'VAD')
        "VAD"."DBA"."VAD_FAIL_CHECK" ('VAD file with illegal header');
    }
    else if (i = 1)
    {
      ddl_pre_install_code := NULL;
      ddl_install_check_code := NULL;
      ddl_uninstall_check_code := NULL;
      ddl_post_install_code := NULL;
      ddl_pre_uninstall_code := NULL;
      ddl_post_uninstall_code := NULL;
      proc_pre_install_code := NULL;
      proc_install_check_code := NULL;
      proc_uninstall_check_code := NULL;
      proc_post_install_code := NULL;
      proc_pre_uninstall_code := NULL;
      proc_post_uninstall_code := NULL;
      declare pkg_vers, pkg_fullname, s2, s3, s4, s7, s8, s9, pkg_date varchar;
      declare pkgid, tid, tid2 integer;
      declare docsid, filesid, ddls, docsid2, filesid2, ddls2  integer;
      docsid := "VAD"."DBA"."VAD_CHDIR" (parr, 0, '/DOCS');
      filesid := "VAD"."DBA"."VAD_CHDIR" (parr, 0, '/FILES');
      ddls := "VAD"."DBA"."VAD_CHDIR" (parr, 0, '/SCHEMA');
      if (s <> 'STICKER')
        "VAD"."DBA"."VAD_FAIL_CHECK" ('VAD file with illegal sticker');
      declare tree, doc any;
      tree := xml_tree (data);
      doc := xml_tree_doc (tree);
      declare items any;
      declare j, n, ix integer;
      "VAD"."DBA"."VAD_CHECK_STICKER_DETAILS" (parr, doc, pkg_name, pkg_vers, pkg_fullname, pkg_date, 0);

      connection_set ('vad_pkg_fullname', pkg_fullname);

      items := xpath_eval ('/sticker/procedures/sql[@purpose=\'pre-install\']', doc, 0);
      n := length (items);
      if (n<>0)
        proc_pre_install_code := cast (xpath_eval ('node()', aref (items, 0)) as varchar);
      items := xpath_eval ('/sticker/ddls/sql[@purpose=\'pre-install\']', doc, 0);
      n := length (items);
      if (n<>0)
        ddl_pre_install_code := cast (xpath_eval ('node()', aref (items, 0)) as varchar);
      "VAD"."DBA"."VAD_EXEC" (ddl_pre_install_code);
      "VAD"."DBA"."VAD_EXEC" (proc_pre_install_code);
      registry_set ('VAD_wet_run', '1');
      "VAD"."DBA"."VAD_CHECK_STICKER_DETAILS" (parr, doc, pkg_name, pkg_vers, pkg_fullname, pkg_date, 1);
      pkgid := "VAD"."DBA"."VAD_GET_PKG_ID" (parr, pkg_name, pkg_vers);
      if (not pkgid)
        "VAD"."DBA"."VAD_FAIL_CHECK" (sprintf ('Illegal pkgID for : %s/%s', pkg_name, pkg_vers));
      docsid2 := "VAD"."DBA"."VAD_MKCD" (parr, docsid, pkg_name);
      filesid2 := "VAD"."DBA"."VAD_MKCD" (parr, filesid, pkg_name);
      ddls2 := "VAD"."DBA"."VAD_MKCD" (parr, ddls, pkg_name);
      "VAD"."DBA"."VAD_MKNODE" (parr, pkgid, 'sticker', 'XML', cast (data as varchar));
      statusid := "VAD"."DBA"."VAD_MKNODE" (parr, pkgid, 'Status', 'STRING', 'Broken');

      items := xpath_eval ('/sticker/procedures/sql[@purpose=\'pre-install\']', doc, 0);
      n := length (items);
      if (n<>0)
      {
        proc_pre_install_code := cast (xpath_eval ('node()', aref (items, 0)) as varchar);
        "VAD"."DBA"."VAD_MKNODE" (parr, pkgid, 'proc-pre-install', 'STRING', proc_pre_install_code);
      }
      items := xpath_eval ('/sticker/procedures/sql[@purpose=\'post-install\']', doc, 0);
      n := length (items);
      if (n<>0)
      {
        proc_post_install_code := cast (xpath_eval ('node()', aref (items, 0)) as varchar);
        "VAD"."DBA"."VAD_MKNODE" (parr, pkgid, 'proc-post-install', 'STRING', proc_post_install_code);
      }
      items := xpath_eval ('/sticker/procedures/sql[@purpose=\'pre-uninstall\']', doc, 0);
      n := length (items);
      if (n<>0)
      {
        proc_pre_uninstall_code := cast (xpath_eval ('node()', aref (items, 0)) as varchar);
        "VAD"."DBA"."VAD_MKNODE" (parr, pkgid, 'proc-pre-uninstall', 'STRING', proc_pre_uninstall_code);
      }
      items := xpath_eval ('/sticker/procedures/sql[@purpose=\'post-uninstall\']', doc, 0);
      n := length (items);
      if (n<>0)
      {
        proc_post_uninstall_code := cast (xpath_eval ('node()', aref (items, 0)) as varchar);
        "VAD"."DBA"."VAD_MKNODE" (parr, pkgid, 'proc-post-uninstall', 'STRING', proc_post_uninstall_code);
      }
      items := xpath_eval ('/sticker/procedures/sql[@purpose=\'uninstall-check\']', doc, 0);
      n := length (items);
      if (n<>0)
      {
        proc_uninstall_check_code := cast (xpath_eval ('node()', aref (items, 0)) as varchar);
        "VAD"."DBA"."VAD_MKNODE" (parr, pkgid, 'proc-uninstall-check', 'STRING', proc_uninstall_check_code);
      }
      items := xpath_eval ('/sticker/ddls/sql[@purpose=\'pre-install\']', doc, 0);
      n := length (items);
      if (n<>0)
      {
        ddl_pre_install_code := cast (xpath_eval ('node()', aref (items, 0)) as varchar);
        "VAD"."DBA"."VAD_MKNODE" (parr, pkgid, 'ddl-pre-install', 'STRING', ddl_pre_install_code);
      }
      items := xpath_eval ('/sticker/ddls/sql[@purpose=\'post-install\']', doc, 0);
      n := length (items);
      if (n<>0)
      {
        ddl_post_install_code := cast (xpath_eval ('node()', aref (items, 0)) as varchar);
        "VAD"."DBA"."VAD_MKNODE" (parr, pkgid, 'ddl-post-install', 'STRING', ddl_post_install_code);
      }
      items := xpath_eval ('/sticker/ddls/sql[@purpose=\'pre-uninstall\']', doc, 0);
      n := length (items);
      if (n<>0)
      {
        ddl_pre_uninstall_code := cast (xpath_eval ('node()', aref (items, 0)) as varchar);
        "VAD"."DBA"."VAD_MKNODE" (parr, pkgid, 'ddl-pre-uninstall', 'STRING', ddl_pre_uninstall_code);
      }
      items := xpath_eval ('/sticker/ddls/sql[@purpose=\'post-uninstall\']', doc, 0);
      n := length (items);
      if (n<>0)
      {
        ddl_post_uninstall_code := cast (xpath_eval ('node()', aref (items, 0)) as varchar);
        "VAD"."DBA"."VAD_MKNODE" (parr, pkgid, 'ddl-post-uninstall', 'STRING', ddl_post_uninstall_code);
      }
      items := xpath_eval ('/sticker/ddls/sql[@purpose=\'uninstall-check\']', doc, 0);
      n := length (items);
      if (n<>0)
      {
        ddl_uninstall_check_code := cast (xpath_eval ('node()', aref (items, 0)) as varchar);
        "VAD"."DBA"."VAD_MKNODE" (parr, pkgid, 'ddl-uninstall-check', 'STRING', ddl_uninstall_check_code);
      }
      tid2 := "VAD"."DBA"."VAD_MKDIR" (parr, pkgid, 'resources');
      "VAD"."DBA"."VAD_MKNODE" (parr, filesid2, pkg_vers, 'KEY', "VAD"."DBA"."VAD_FULL_PATH" (parr, tid2));
      tid := "VAD"."DBA"."VAD_MKDIR" (parr, tid2, 'doc');
      "VAD"."DBA"."VAD_MKNODE" (parr, docsid2, pkg_vers, 'KEY', "VAD"."DBA"."VAD_FULL_PATH" (parr, tid));
      tid := "VAD"."DBA"."VAD_MKDIR" (parr, tid2, 'dav');
      tid := "VAD"."DBA"."VAD_MKDIR" (parr, tid2, 'http');
      tid := "VAD"."DBA"."VAD_MKDIR" (parr, tid2, 'code');
      tid := "VAD"."DBA"."VAD_MKDIR" (parr, tid2, 'data');
      items := xpath_eval ('/sticker/resources/file', doc, 0);
      n := length (items);
      resources := make_array (n*2, 'any');
      j := 0;
      ix := 0;
      while (j<n)
      {
        s2 := cast (xpath_eval ('@type', aref (items, j)) as varchar);
        s3 := cast (xpath_eval ('@target_uri', aref (items, j)) as varchar);
        s7 := cast (xpath_eval ('@dav_owner', aref (items, j)) as varchar);
        s8 := cast (xpath_eval ('@dav_grp', aref (items, j)) as varchar);
        s9 := cast (xpath_eval ('@dav_perm', aref (items, j)) as varchar);
        s4 := get_keyword (s2, iniarr);
        if (s4 is null or length(s4)=0)
          "VAD"."DBA"."VAD_FAIL_CHECK" (sprintf ('resource file %s has unknown type %s', s3, s2));
        s4 := cast (xpath_eval ('@overwrite', aref (items, j)) as varchar);
        tid := "VAD"."DBA"."VAD_CHDIR" (parr, tid2, s2);
        if (0 = tid)
          "VAD"."DBA"."VAD_FAIL_CHECK" (sprintf ('resource file %s has unknown type %s', s3, s2));
        tid := "VAD"."DBA"."VAD_MKNODE" (parr, tid, cast (j + 1 as varchar), 'STRING', s3);
	resources [ix] := s3;
	resources [ix+1] := vector (s2, s4, cast (xpath_eval ('@makepath', aref (items, j)) as varchar), s7, s8, s9);
        j := j + 1;
	ix := ix + 2;
      }
      items := xpath_eval ('/sticker/registry/record', doc, 0);
      tid2 := "VAD"."DBA"."VAD_MKDIR" (parr, pkgid, 'records');
      n := length (items);
      j := 0;
      while (j<n)
      {
        s2 := cast (xpath_eval ('@key', aref (items, j)) as varchar);
        s3 := cast (xpath_eval ('@type', aref (items, j)) as varchar);
        s4 := cast (xpath_eval ('text()', aref (items, j)) as varchar);
        declare tpath, tname varchar;
        declare iname, itype, ival varchar;
        "VAD"."DBA"."VAD_SPLIT_PATH" (s2, tpath, tname);
        tid := "VAD"."DBA"."VAD_CHDIR" (parr, tid2, tpath);
        if (not tid)
          "VAD"."DBA"."VAD_FAIL_CHECK" ( sprintf ('package registry item (%s) refers to non-existing path', s2));
        tid2 := "VAD"."DBA"."VAD_NODE_INFO_BY_NAME" (tid, tname, iname, itype, ival, 0);
        s2 := cast (xpath_eval ('@overwrite', aref (items, j)) as varchar);
        if (s2 is null or length(s2)=0)
          s2 := 'equal';
        if (equ (s2, 'yes'))
        {
          if (tid2)
            "VAD"."DBA"."VAD_UPDATE_NODE" (tid2, s4, ival);
          else
            "VAD"."DBA"."VAD_MKNODE" (parr, tid, tname, s3, s4);
        }
        else if (equ (s2, 'no'))
        {
          if (not tid2)
            "VAD"."DBA"."VAD_MKNODE" (parr, tid, tname, s3, s4);
        }
        else if (equ (s2, 'equal'))
        {
          if (tid2)
          {
            if (neq (ival, s4))
              "VAD"."DBA"."VAD_UPDATE_NODE" (tid2, s4, ival);
          }
          else
            "VAD"."DBA"."VAD_MKNODE" (parr, tid, tname, s3, s4);
        }
        else if (equ (s2, 'abort'))
        {
          if (tid2)
            "VAD"."DBA"."VAD_FAIL_CHECK" (sprintf ('package registry item (%s) exists & overwrite=abort', s2));
          "VAD"."DBA"."VAD_MKNODE" (parr, tid, tname, s3, s4);
        }
        else if (equ (s2, 'expected'))
        {
          if (tid2)
            "VAD"."DBA"."VAD_UPDATE_NODE" (tid2, s4, ival);
          else
            "VAD"."DBA"."VAD_FAIL_CHECK" (sprintf ('package registry item (%s) does not exist & overwrite=expected', s2));
        }
        j := j + 1;
      }
--      "VAD"."DBA"."VAD_EXEC" (ddl_pre_install_code);
--      "VAD"."DBA"."VAD_EXEC" (proc_pre_install_code);
    }
    i := i + 1;
  }

fin:
  "VAD"."DBA"."VAD_EXEC" (ddl_post_install_code);
  "VAD"."DBA"."VAD_EXEC" (proc_post_install_code);
  "VAD"."DBA"."VAD_UPDATE_NODE" (statusid, 'Installed', 'Broken');
  "DB"."DBA"."VAD_CLEAN_OLD_VERSIONS" (pkg_name);
  return 1;

error_nofile:
  "VAD"."DBA"."VAD_FAIL_CHECK" (sprintf ('VAD file (%s) problems:\n%s', fname, __SQL_MESSAGE));
}
;

create procedure "VAD"."DBA"."VAD_PKG_UNINSTALL_CHECK" (
  inout parr any,
  in pkgid integer )
{
  declare lname, ltype, lval varchar;
  "VAD"."DBA"."VAD_NODE_INFO_BY_NAME" (pkgid, 'Status', lname, ltype, lval);
  declare install_check_code varchar;
  declare stat integer;
  stat := "VAD"."DBA"."VAD_NODE_INFO_BY_NAME" (pkgid, 'proc-uninstall-check', lname, ltype, lval, 0);
  if (stat)
    "VAD"."DBA"."VAD_EXEC" (lval);
  stat := "VAD"."DBA"."VAD_NODE_INFO_BY_NAME" (pkgid, 'ddl-uninstall-check', lname, ltype, lval, 0);
  if (stat)
    "VAD"."DBA"."VAD_EXEC" (lval);
  return 1;
}
;

create procedure "VAD"."DBA"."VAD_UNINSTALL_LIST_FOLDER" (
  inout parr any,
  in id integer,
  in root varchar,
  inout arrout any,
  in type varchar)
{
  declare tid, i, n integer;
  declare arr, item any;
  declare s varchar;
  arr := "VAD"."DBA"."VAD_LIST_FOLDER" (parr, id, type);
  n := length (arr);
  i := 0;
  while (i < n)
  {
    item := aref (arr, i);
    i := i + 1;
    s := concat (root, '/', aref (item, 2));
    arrout := vector_concat (arrout, vector (vector (s, aref(item, 3))));
  }
  return 0;
}
;

create procedure "VAD"."DBA"."VAD_DO_UNINSTALL" (
  inout parr any,
  in arr any )
{
  declare i, n, tid, id, gd integer;
  declare s, sn, sp varchar;
  declare item, ini any;
  ini := null;
  declare continue handler for sqlstate '39000' { goto error; };
  declare continue handler for sqlstate '42000' { goto error; };
  n := length (arr);
  i := 0;
  id := 0;
  gd := 0;
  while (i < n)
  {
    item := aref(arr, i);
    s := aref (item, 0);
    i := i + 1;
    if (aref (item, 1) = 'file')
    {
      declare server_root varchar;
      server_root := http_root();
      s := concat(server_root, '/', s);
      sys_unlink (s);
    }
    else if (aref (item, 1) = 'dav')
    {
      "VAD"."DBA"."VAD_SPLIT_PATH" (s, sp, sn);
      tid := "VAD"."DBA"."VAD_MKDAV" (id, gd, sp, ini, 1);
      if (tid > 0)
        "VAD"."DBA"."VAD_DAV_DELETE" (ini, s);
    }
    goto cont;
    error:;
    cont:;
  }
}
;

create procedure "VAD"."DBA"."VAD_UNINSTALL_LIST" (
  inout parr any,
  in pkgid integer )
{
  declare tid, curdir integer;
  declare iniarr, arr any;
  declare s varchar;
  arr := vector();
  iniarr := "VAD"."DBA"."VAD_READ_INI" (parr);

  for select R_SHKEY from "VAD"."DBA"."VAD_REGISTRY" where R_PRNT=pkgid and R_TYPE='FOLDER' do
  {
    curdir := "VAD"."DBA"."VAD_CHDIR"(parr, pkgid, R_SHKEY);
    s := "PUMP"."DBA"."__GET_KEYWORD"('code', iniarr, '');
    tid := "VAD"."DBA"."VAD_CHDIR"(parr, curdir, 'resources/code');
    "VAD"."DBA"."VAD_UNINSTALL_LIST_FOLDER"(parr, tid, s, arr, 'file');
    s := "PUMP"."DBA"."__GET_KEYWORD"('data', iniarr, '');
    tid := "VAD"."DBA"."VAD_CHDIR"(parr, curdir, 'resources/data');
    "VAD"."DBA"."VAD_UNINSTALL_LIST_FOLDER"(parr, tid, s, arr, 'file');
    s := "PUMP"."DBA"."__GET_KEYWORD"('http', iniarr, '');
    tid := "VAD"."DBA"."VAD_CHDIR"(parr, curdir, 'resources/http');
    "VAD"."DBA"."VAD_UNINSTALL_LIST_FOLDER"(parr, tid, s, arr, 'file');
    s := "PUMP"."DBA"."__GET_KEYWORD"('dav', iniarr, '');
    tid := "VAD"."DBA"."VAD_CHDIR"(parr, curdir, 'resources/dav');
    "VAD"."DBA"."VAD_UNINSTALL_LIST_FOLDER"(parr, tid, s, arr, 'dav');
  }
  return arr;
}
;

create procedure "VAD"."DBA"."VAD_PKG_UNINSTALL" (
  inout parr any,
  in pkgid integer,
  in cur_vers varchar)
{
  declare lname, ltype, lval, install_check_code varchar;
  declare stat, curdir integer;
  declare arr any;
  curdir := "VAD"."DBA"."VAD_CHDIR"(parr, pkgid, cur_vers);
  "VAD"."DBA"."VAD_NODE_INFO_BY_NAME"(curdir, 'Status', lname, ltype, lval);
  "VAD"."DBA"."VAD_PKG_UNINSTALL_CHECK"(parr, curdir);
  stat := "VAD"."DBA"."VAD_NODE_INFO_BY_NAME"(curdir, 'proc-pre-uninstall', lname, ltype, lval, 0);
  if (stat)
    "VAD"."DBA"."VAD_EXEC" (lval);
  stat := "VAD"."DBA"."VAD_NODE_INFO_BY_NAME"(curdir, 'ddl-pre-uninstall', lname, ltype, lval, 0);
  if (stat)
    "VAD"."DBA"."VAD_EXEC" (lval);

  arr := "VAD"."DBA"."VAD_UNINSTALL_LIST"(parr, pkgid);
  "VAD"."DBA"."VAD_DO_UNINSTALL"(parr, arr);


  stat := "VAD"."DBA"."VAD_NODE_INFO_BY_NAME"(curdir, 'ddl-post-uninstall', lname, ltype, lval, 0);
  if (stat)
    "VAD"."DBA"."VAD_EXEC" (lval);
  stat := "VAD"."DBA"."VAD_NODE_INFO_BY_NAME"(curdir, 'proc-post-uninstall', lname, ltype, lval, 0);
  if (stat)
    "VAD"."DBA"."VAD_EXEC" (lval);
  "VAD"."DBA"."VAD_DEL_SUBTREE"(pkgid);
  return 1;
}
;

-- uninstall check by package name (name="package_name")
create procedure "DB"."DBA"."VAD_CHECK_UNINSTALLABILITY_BY_NAME"(
  in name varchar) returns varchar
{
  declare parr any;
  declare curdir, tid, ret integer;
  declare prod, version, lname, ltype, lval varchar;
  parr := null;
  curdir := "VAD"."DBA"."VAD_CHDIR"(parr, 0, '/VAD');
  tid := "VAD"."DBA"."VAD_CHDIR"(parr, curdir, name);
  if (not tid)
    "VAD"."DBA"."VAD_FAIL_CHECK"(sprintf('The package "%s" does not exist', name));
  ret := "VAD"."DBA"."VAD_NODE_INFO_BY_NAME"(tid, 'CurrentVersion', lname, ltype, lval, 0);
  if (not ret)
    "VAD"."DBA"."VAD_FAIL_CHECK"(sprintf('The installation of "%s" does not exist or was corrupted. VAD cannot find its current version.', name));
  curdir := "VAD"."DBA"."VAD_CHDIR"(parr, tid, lval);
  DB.DBA.VAD_DEPS_CHECK (parr, name, lval);
  "VAD"."DBA"."VAD_PKG_UNINSTALL_CHECK"(parr, curdir);
  return 'OK';
}
;

-- uninstall check by package name and version (name="package_name/package_version")
create procedure "DB"."DBA"."VAD_CHECK_UNINSTALLABILITY"(
  in name varchar) returns varchar
{
  declare parr any;
  declare curdir, tid, ret integer;
  declare prod, version, lname, ltype, lval varchar;
  parr := null;
  if ("VAD"."DBA"."VAD_GET_NAME_AND_VERSION"(name, prod, version) = 0)
    "VAD"."DBA"."VAD_FAIL_CHECK"(sprintf ('The package "%s" has incorrect name or version', name));
  curdir := "VAD"."DBA"."VAD_CHDIR"(parr, 0, '/VAD');
  tid := "VAD"."DBA"."VAD_CHDIR"(parr, curdir, prod);
  if (not tid)
    "VAD"."DBA"."VAD_FAIL_CHECK"(sprintf('The package "%s" does not exist', prod));
  ret := "VAD"."DBA"."VAD_NODE_INFO_BY_NAME"(tid, 'CurrentVersion', lname, ltype, lval, 0);
  if (not ret)
    "VAD"."DBA"."VAD_FAIL_CHECK"(sprintf('The installation of "%s" does not exist or was corrupted. VAD cannot find its current version.', prod));
  if (neq(lval, version))
    "VAD"."DBA"."VAD_FAIL_CHECK"(sprintf('Attempt to remove non-current version of package "%s"', prod));
  curdir := "VAD"."DBA"."VAD_CHDIR"(parr, tid, version);
  DB.DBA.VAD_DEPS_CHECK (parr, prod, lval);
  "VAD"."DBA"."VAD_PKG_UNINSTALL_CHECK"(parr, curdir);
  return 'OK';
}
;

-- uninstall by package name without version (name="package_name")
create procedure "DB"."DBA"."VAD_UNINSTALL_BY_NAME"(
  in name varchar) returns varchar
{
  declare parr any;
  declare curdir, ret, tid integer;
  declare res, lname, ltype, lval varchar;
  parr := null;
  curdir := "VAD"."DBA"."VAD_CHDIR"(parr, 0, '/VAD');
  tid := "VAD"."DBA"."VAD_CHDIR"(parr, curdir, name);
  if (not tid)
    "VAD"."DBA"."VAD_FAIL_CHECK"(sprintf('The package "%s" does not exist', name));
  ret := "VAD"."DBA"."VAD_NODE_INFO_BY_NAME"(tid, 'CurrentVersion', lname, ltype, lval, 0);
  if (not ret)
    "VAD"."DBA"."VAD_FAIL_CHECK"(sprintf('The installation of "%s" does not exist or was corrupted. VAD cannot find its current version.', name));
  DB.DBA.VAD_DEPS_CHECK (parr, name, lval);
  "VAD"."DBA"."VAD_PKG_UNINSTALL"(parr, tid, lval);
  return 'OK';
}
;

-- get version of installed package by package name (name="package_name")
create procedure "DB"."DBA"."VAD_CHECK_VERSION"(
  in name varchar) returns varchar
{
  declare parr any;
  declare curdir, ret, tid integer;
  declare res, lname, ltype, lval varchar;
  parr := null;
  curdir := "VAD"."DBA"."VAD_CHDIR"(parr, 0, '/VAD');
  tid := "VAD"."DBA"."VAD_CHDIR"(parr, curdir, name);
  if (not tid)
    return null;
--    "VAD"."DBA"."VAD_FAIL_CHECK"(sprintf('The package "%s" does not exist', name));
  ret := "VAD"."DBA"."VAD_NODE_INFO_BY_NAME"(tid, 'CurrentVersion', lname, ltype, lval, 0);
  if (not ret)
    return null;
--    "VAD"."DBA"."VAD_FAIL_CHECK"(sprintf('The installation of "%s" does not exist or was corrupted. VAD cannot find its current version.', name));
  return lval;
}
;

create procedure "DB"."DBA"."VAD_CLEAN_OLD_VERSIONS" (in name varchar)
{
  declare parr any;
  declare curdir, ret, tid integer;
  declare res, lname, ltype, lval varchar;

  parr := null;
  curdir := "VAD"."DBA"."VAD_CHDIR"(parr, 0, '/VAD');
  tid := "VAD"."DBA"."VAD_CHDIR"(parr, curdir, name);
  if (not tid)
    return null;
  ret := "VAD"."DBA"."VAD_NODE_INFO_BY_NAME"(tid, 'CurrentVersion', lname, ltype, lval, 0);
  if (not ret)
    return null;
  for select R_SHKEY as old_ver from VAD.DBA.VAD_REGISTRY
    where R_TYPE = 'FOLDER' and R_KEY = '/VAD/'||name||'/' || R_SHKEY and R_SHKEY <> lval do
    {
      delete from VAD.DBA.VAD_REGISTRY where R_KEY like '/VAD/'||name||'/'||old_ver||'/%';
      delete from VAD.DBA.VAD_REGISTRY where R_KEY = '/VAD/'||name||'/'||old_ver;
      --curdir := "VAD"."DBA"."VAD_CHDIR" (parr, tid, old_ver);
      --"VAD"."DBA"."VAD_DEL_SUBTREE" (curdir);
    }
  return lval;
}
;

create procedure "DB"."DBA"."VAD_RENAME" (in name varchar, in new_name varchar)
{
  declare old_pkey, docs, files, ddls, ver varchar;

  ver := "DB"."DBA"."VAD_CLEAN_OLD_VERSIONS" (name);

  if (ver is null)
    return;

  old_pkey := '/VAD/'||name;
  docs := '/DOCS/' || name;
  files := '/FILES/' || name;
  ddls := '/SCHEMA/' || name;

  for select R_KEY as rkey, R_ID as rid from VAD.DBA.VAD_REGISTRY where R_KEY like old_pkey || '/%' or R_KEY = old_pkey
   do
     {
       declare new_key varchar;
       if (rkey <> old_pkey)
	 {
	   new_key := '/VAD/' || new_name || substring (rkey, length (old_pkey)+1, length (rkey));
	   update VAD.DBA.VAD_REGISTRY set R_KEY = new_key where R_ID = rid;
	 }
       else
	 {
           new_key := '/VAD/' || new_name;
           update VAD.DBA.VAD_REGISTRY set R_KEY = new_key, R_SHKEY = new_name where R_ID = rid;
	 }
     }

   for select R_KEY as rkey, R_ID as rid, blob_to_string (R_VALUE) as val, R_TYPE as tp from VAD.DBA.VAD_REGISTRY
     where
	 R_KEY = docs
	 or R_KEY = files
	 or R_KEY = ddls
	 or R_KEY = docs ||'/' || ver
	 or R_KEY = files || '/' || ver
	 or R_KEY = ddls ||'/' || ver
	 do
	   {
	     declare new_key varchar;
	     if (rkey like '/DOCS/%')
	       {
		 new_key := '/DOCS/'||new_name||substring (rkey, length (docs)+1, length (rkey));
	       }
	     else if (rkey like '/FILES/%')
	       {
		 new_key := '/FILES/'||new_name||substring (rkey, length (files)+1, length (rkey));
	       }
	     else if (rkey like '/SCHEMA/%')
	       {
		 new_key := '/SCHEMA/'||new_name||substring (rkey, length (ddls)+1, length (rkey));
	       }

             if (tp = 'FOLDER')
	       {
		 update VAD.DBA.VAD_REGISTRY set R_KEY = new_key, R_SHKEY = new_name where R_ID = rid;
	       }
             else if (tp = 'KEY' and val like old_pkey || '/%')
               {
		 declare new_value varchar;
		 new_value := '/VAD/'||new_name||substring (val, length (old_pkey)+1, length (val));
		 update VAD.DBA.VAD_REGISTRY set R_KEY = new_key, R_VALUE = new_value where R_ID = rid;
	       }
	   }
     for select R_KEY as rkey, R_ID as rid, R_SHKEY as shkey from VAD.DBA.VAD_REGISTRY where
        R_KEY like '%/require/__/' || name and R_SHKEY = name do
	  {
	    declare new_key varchar;
	    new_key := substring (rkey, 1, length (rkey) - length (name)) || new_name;
	    update VAD.DBA.VAD_REGISTRY set R_KEY = new_key, R_SHKEY = new_name where R_ID = rid;
	  }
}
;

create procedure DB.DBA.VAD_LIST_PACKAGES ()
{
  declare pkgs any;
  declare name, title, build_date, install_date, version varchar;

  result_names (name, title, version, build_date, install_date);
  pkgs := "VAD"."DBA"."VAD_GET_PACKAGES" ();
  foreach (any elm in pkgs) do
    {
      result (elm[1], elm[5], elm[2], elm[3], elm[4]);
    }

}
;

-- uninstall by package name and version (name="package_name/package_version")
create procedure "DB"."DBA"."VAD_UNINSTALL"(
  in name varchar) returns varchar
{
  declare parr any;
  declare curdir, ret, tid integer;
  declare prod, version, lname, ltype, lval varchar;
  parr := null;
  if ("VAD"."DBA"."VAD_GET_NAME_AND_VERSION"(name, prod, version) = 0)
    "VAD"."DBA"."VAD_FAIL_CHECK" (sprintf ('The package "%s" has incorrect name or version', name));
  curdir := "VAD"."DBA"."VAD_CHDIR"(parr, 0, '/VAD');
  tid := "VAD"."DBA"."VAD_CHDIR"(parr, curdir, prod);
  if (not tid)
    "VAD"."DBA"."VAD_FAIL_CHECK"(sprintf('The package "%s" does not exist', prod));
  ret := "VAD"."DBA"."VAD_NODE_INFO_BY_NAME"(tid, 'CurrentVersion', lname, ltype, lval, 0);
  if (not ret)
    "VAD"."DBA"."VAD_FAIL_CHECK"(sprintf('The installation of "%s" does not exist or was corrupted. VAD cannot find its current version.', prod));
  if (neq(lval, version))
    "VAD"."DBA"."VAD_FAIL_CHECK"(sprintf('Attempt to remove non-current version of package "%s"', prod));
  DB.DBA.VAD_DEPS_CHECK (parr, prod, lval);
  "VAD"."DBA"."VAD_PKG_UNINSTALL"(parr, tid, version);
  return 'OK';
}
;

create procedure "VAD"."DBA"."VAD_PKG_DIFF" (
  inout parr any,
  in pkgid integer )
{
  declare outarr any;
  outarr := vector();
--  "VAD"."DBA"."VAD_FULL_PATH" (parr, pkgid);
--  declare sname, lname, rname, oldval, newval varchar;
--  outarr := vector();
--  sname := concat ("VAD"."DBA"."VAD_FULL_PATH" (parr, pkgid), '%');
--  declare cr cursor for select distinct "L_KEY" from "VAD"."DBA"."VAD_LOG" where "L_KEY" like sname and ("L_ACT" = 'UPDNODE' or "L_ACT" = 'RMNODE') order by "L_TM";
--  open cr;
--  whenever not found goto fin;
--  while (1)
--  {
--    fetch cr into lname;
--    select "R_VALUE" into rname from "VAD"."DBA"."VAD_REGISTRY" where "R_KEY" = lname;
--    select top 1 "L_NVAL" into newval from "VAD"."DBA"."VAD_LOG" where "L_KEY" = lname and "L_ACT" = 'MKNODE' order by "L_TM";
--    outarr := vector_concat (outarr, vector (vector (lname, rname, newval)));
--    }
--  fin:
--  close cr;
  return outarr;
}
;

-- check that package is installed
create procedure "DB"."DBA"."VAD_CHECK_INSTALLED" (
  in name varchar ) returns integer
{
  declare parr any;
  declare curdir, ret, tid integer;
  declare prod, version, lname, ltype, lval varchar;
  parr := null;
  if ("VAD"."DBA"."VAD_GET_NAME_AND_VERSION"(name, prod, version) = 0)
    "VAD"."DBA"."VAD_FAIL_CHECK" (sprintf ('The package "%s" has incorrect name or version', name));
  curdir := "VAD"."DBA"."VAD_CHDIR"(parr, 0, '/VAD');
  tid := "VAD"."DBA"."VAD_CHDIR"(parr, curdir, prod);
  if (not tid)
    return 0;
  ret := "VAD"."DBA"."VAD_NODE_INFO_BY_NAME"(tid, 'CurrentVersion', lname, ltype, lval, 0);
  if (not ret)
    return 0;
  if (neq(lval, version))
    return 0;
  return 1;
}
;

create procedure "DB"."DBA"."VAD_CHECK" (
  in name varchar ) returns any
{
  declare parr any;
  declare curdir, ret, tid integer;
  declare prod, version, lname, ltype, lval varchar;
  parr := null;
  if ("VAD"."DBA"."VAD_GET_NAME_AND_VERSION"(name, prod, version) = 0)
    "VAD"."DBA"."VAD_FAIL_CHECK" (sprintf ('The package "%s" has incorrect name or version', name));
  curdir := "VAD"."DBA"."VAD_CHDIR"(parr, 0, '/VAD');
  tid := "VAD"."DBA"."VAD_CHDIR"(parr, curdir, prod);
  if (not tid)
    "VAD"."DBA"."VAD_FAIL_CHECK"(sprintf('The package "%s" does not exist', prod));
  ret := "VAD"."DBA"."VAD_NODE_INFO_BY_NAME"(tid, 'CurrentVersion', lname, ltype, lval, 0);
  if (not ret)
    "VAD"."DBA"."VAD_FAIL_CHECK"(sprintf('The installation of "%s" does not exist or was corrupted. VAD cannot find its current version.', prod));
  if (neq(lval, version))
    "VAD"."DBA"."VAD_FAIL_CHECK"(sprintf('Attempt to check non-current version of package "%s"', prod));
  tid := "VAD"."DBA"."VAD_CHDIR"(parr, tid, version);
  return "VAD"."DBA"."VAD_PKG_DIFF" (parr, tid);
}
;

create procedure "DB"."DBA"."VAD_PACK"(
  in sticker_uri varchar,
  in base_uri_of_resources varchar,
  in package_uri varchar) returns varchar
{
  declare parr any;
  parr := null;
  if (equ (subseq (package_uri, 0, 7), 'file://'))
    package_uri := subseq (package_uri, 7);
  declare sticker varchar;
  if (neq (subseq (sticker_uri, 0, 7), 'http://'))
    sticker := file_to_string (sticker_uri);
  else
    sticker := http_get (sticker_uri);
  "VAD"."DBA"."VAD_TEST_CREATE" (parr, package_uri, sticker);
  return 'OK';
}
;

create procedure "DB"."DBA"."VAD_LOAD_SQL_FILE" (
  in sql_file_name varchar,
  in _grouping integer,
  in _report_errors varchar,
  in is_dav integer,
  in already integer := 0)
{
  declare _file_ses any;
  declare _cmd any;
  declare _cmd_line, _cmd_line_rtrim varchar;
  declare _cmd_text, _sqlstate, _sqlmsg, SQL_STATE, SQL_MESSAGE varchar;
  declare _cmd_complete integer;
  declare server_root varchar;
  whenever not found goto fin1;
  if (is_dav = 0)
  {
    server_root := http_root();
    sql_file_name := concat(server_root, '/', sql_file_name);
    if (file_stat(sql_file_name, 0) = 0)
    {
      "VAD"."DBA"."VAD_FAIL_CHECK" (sprintf('Inexistent file resource (%s). Unable to load file.', sql_file_name));
    }
    _file_ses := file_to_string_output (sql_file_name);
  }
  else
  {
    select blob_to_string_output(RES_CONTENT) into _file_ses from WS.WS.SYS_DAV_RES where RES_FULL_PATH=sql_file_name;
    if ('STRING_SESSION' <> internal_type_name (__tag (_file_ses)) and _file_ses is not null)
      {
  declare _tmpval any;
  _tmpval := _file_ses;
  _file_ses := string_output ();
  http (_tmpval, _file_ses);
      }
  }
  if (0)
  {
    fin1:
    "VAD"."DBA"."VAD_FAIL_CHECK" (sprintf('Inexistent file resource (%s). Unable to load file.', sql_file_name));
    return 0;
  }

  commit work;
  declare parsed_text any;
  declare err_sqlstate, commit_err_sqlstate, err_msg, commit_err_msg, err_rep varchar;
  declare m_dta, result any;
  declare stmt_text varchar;
  declare _maxres integer;
  _maxres := 100;
  commit_err_sqlstate := '00000';
  parsed_text := sql_split_text (
    sprintf ('#pragma line 1 "%s"\n', sql_file_name) ||
    string_output_string(_file_ses)
    );
  declare i int;
  i := 0;
  while( i < length(parsed_text) )
  {
    if (193 = __tag (parsed_text[i]))
      {
        rollback work;
	err_rep := parsed_text[i][1];
        if (_report_errors = 'report')
          {
            if (registry_get ('VAD_wet_run') <> '0')
              log_message (err_rep);
            result ('37000', err_rep);
            registry_set ('VAD_errcount', cast (1 + cast (registry_get ('VAD_errcount') as integer) as varchar));
          }
        if (_report_errors = 'signal')
          signal ('37000', err_rep);
      }
    aset(parsed_text, i, concat ('--no_c_escapes-\r\n', trim(parsed_text[i], '\r\n ')));
    err_sqlstate := '00000';
    err_msg := '';
    exec ( parsed_text[i], err_sqlstate, err_msg, vector(), _maxres, m_dta, result);
    if( err_sqlstate <> '00000' )
    {
      rollback work;
      err_rep := concat (err_msg, '\nwhile executing the following statement:\n', parsed_text[i], '\nin file:\n', sql_file_name);
      if (_report_errors = 'report')
      {
        if (not (parsed_text[i] like 'drop %'))
        {
          if (registry_get ('VAD_wet_run') <> '0')
            log_message(err_rep);
          result (err_sqlstate, err_rep);
          registry_set ('VAD_errcount', cast (1 + cast (registry_get ('VAD_errcount') as integer) as varchar));
        }
      }
      if (_report_errors = 'signal')
      {
        if (not (parsed_text[i] like 'drop %'))
          signal (err_sqlstate, err_rep);
      }
    }
    i := i+1;
  }
end_of_file:  
  exec ('commit work', commit_err_sqlstate, commit_err_msg);
}
;

create procedure "DB"."DBA"."VAD_REMOVE_FILE"(
  in folder varchar )
{
  folder := concat(http_root(), '/', folder);
  folder := replace(folder, '\\', '/');
  folder := replace(folder, '//', '/');
  folder := replace(folder, '//', '/');
  file_delete(folder, 1);
}
;

create procedure "DB"."DBA"."VAD_CREATE_INSTALL_FOLDER_TREE" (
  )
{
  declare exit handler for sqlstate '*'
  {
    "VAD"."DBA"."VAD_FAIL_CHECK"(sprintf('VAD folder tree creation problems:\n%s', __SQL_MESSAGE));
  };
  file_mkdir(concat(http_root(), '/vad'));
  file_mkdir(concat(http_root(), '/vad/doc'));
  file_mkdir(concat(http_root(), '/vad/vsp'));
  file_mkdir(concat(http_root(), '/vad/code'));
  file_mkdir(concat(http_root(), '/vad/data'));
}
;

create procedure "DB"."DBA"."VAD_CREATE_PATH"(
  in full_path varchar )
{
  declare path_vec any;
  declare path, httproot varchar;
  declare i integer;
  httproot := replace(http_root(), '\\', '/');
  if (length(httproot) > 1)
    httproot := rtrim(httproot, '/');
  path := full_path;
  path_vec := vector();
  declare exit handler for sqlstate '*'
  {
    "VAD"."DBA"."VAD_FAIL_CHECK"(sprintf('VAD folder tree creation problems (%s):\n%s', path, __SQL_MESSAGE));
  };
  path := replace(path, '\\', '/');
  path_vec := split_and_decode(path, 0, '=//');
  i := 1;
  path := path_vec[0];
  while (i < length(path_vec))
  {
    if (path_vec[i] <> '.')
      path := concat(path, '/', path_vec[i]);
    if (length(httproot) < length(path))
    {
      if (file_stat(path) = 0)
      {
        file_mkdir(path);
      }
    }
    i := i + 1;
  }
}
;

create procedure DB.DBA.VAD_DEPS_CHECK (in parr any, in name varchar, in version varchar)
{
  declare pkgs, arr any;
  declare id int;
  declare val any;

  pkgs := VAD..VAD_GET_PACKAGES ();

  foreach (any pkg in pkgs) do
    {
      declare nam, ver varchar;
      declare did, iid int;
      declare nam1, val1, ty1 any;

      nam := pkg [1];
      ver := pkg [2];
      did := 0;
      id := 0;
      iid := 0;
      if (nam <> name)
  {
    id := "VAD"."DBA"."VAD_CHDIR"(parr, 0, sprintf ('/VAD/%s/%s/require', nam, ver));
    if (not iid and (did := "VAD"."DBA"."VAD_CHDIR"(parr, id, 'eq')) <> 0)
      {
        iid := "VAD"."DBA"."VAD_NODE_INFO_BY_NAME" (did, name, nam1, ty1, val1, 0);
      }
    if (not iid and (did := "VAD"."DBA"."VAD_CHDIR"(parr, id, 'gt')) <> 0)
      {
        iid := "VAD"."DBA"."VAD_NODE_INFO_BY_NAME" (did, name, nam1, ty1, val1, 0);
      }
    if (not iid and (did := "VAD"."DBA"."VAD_CHDIR"(parr, id, 'lt')) <> 0)
      {
        iid := "VAD"."DBA"."VAD_NODE_INFO_BY_NAME" (did, name, nam1, ty1, val1, 0);
      }
    if (iid)
      {
        "VAD"."DBA"."VAD_FAIL_CHECK"
      (sprintf ('Package "%s/%s" depends from "%s" version "%s"', nam, ver, name, val1));
      }
  }
    }

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
-- \return \p 1 if \p x is smaller than \p y, \p 0 otherwise.
--/
create procedure VAD.DBA.VER_LT (in x varchar, in y varchar)
{
  return (case when "VAD"."DBA"."VERSION_COMPARE" (x, y) = -1 then 1 else 0 end);
}
;

create procedure "VAD"."DBA"."VAD_AUTO_UPGRADE" ()
{
  declare vads, name, ver, arr, isdav any;
  declare pname, pver, pfull, pisdav, pdate any;
  declare vaddir any;

  vaddir := cfg_item_value (virtuoso_ini_path (), 'Parameters', 'VADInstallDir'); --'../vad/';

  if (vaddir is null)
    return;

  declare exit handler for sqlstate '*'
  {
    log_message ('Can\'t get list of vad packages in ' || vaddir);
    return;
  };

  if (vaddir not like '%/')
    vaddir := vaddir || '/';

  arr := sys_dirlist (vaddir, 1);

  if (isstring (file_stat (vaddir || 'ods_framework_dav.vad')))
    arr := vector_concat (vector ('ods_framework_dav.vad'), arr);

  foreach (any f in arr) do
    {
       if (f like '%.vad')
	 {
	   declare continue handler for sqlstate '*';
	   pisdav := 0;
           if (f like '%_dav.vad')
             pisdav := 1;

	   VAD.DBA.VAD_TEST_READ (vaddir||f, pname, pver, pfull, pdate, 0, 1);

	   ver := DB.DBA.VAD_CHECK_VERSION (pname);
	   if (ver is not null)
	     {
		if (exists (select top 1 1 from VAD.DBA.VAD_REGISTRY
			where R_KEY like sprintf ('/VAD/%s/%s/resources/dav/%%', pname, ver)))
		  isdav := 1;
		else
		  isdav := 0;
	     }

	   --  Only install Conductor DAV in empty database
	   if (ver is null and pname = 'conductor')
	     {
		  isdav := 1;
		ver := '0.0.0';
	     }

	   -- Only upgrade if package exists in database with older version
	   if (VAD.DBA.VER_LT (ver, pver) and isdav = pisdav)
	     {
	       log_message ('Installing '||pfull||' version '||pver|| ' '||case when isdav then '(DAV)' else '' end);
	       vad_install (vaddir||f);
	     }
	 }
    }
}
;
