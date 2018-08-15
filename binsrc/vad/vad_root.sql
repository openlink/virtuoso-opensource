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
create procedure "VAD"."DBA"."VAD_VERSION" () returns varchar
{
  return '1.0.010601A';
}
;

registry_set ('VAD_atomic', '0')
;

-- sequence_set ('vad_id', 0, 0);

--drop table "VAD"."DBA"."VAD_REGISTRY";
create table  "VAD"."DBA"."VAD_REGISTRY" (
    "R_ID"  integer not null,
    "R_PRNT"  integer not null,
    "R_KEY" varchar not null,
    "R_SHKEY" varchar not null,
    "R_TYPE"  varchar not null,
    "R_VALUE" long varchar,
    primary key ("R_ID") )
create index VAD_REGISTRY_CHDIR on "VAD"."DBA"."VAD_REGISTRY" (R_PRNT,R_SHKEY,R_TYPE) partition cluster replicated
create index VAD_REGISTRY_KEY on "VAD"."DBA"."VAD_REGISTRY" (R_KEY) partition cluster replicated
alter index VAD_REGISTRY on "VAD"."DBA"."VAD_REGISTRY" partition cluster replicated
;

--drop table "VAD"."DBA"."VAD_LOG";
--create table "VAD"."DBA"."VAD_LOG" (
--    "L_KEY" varchar not null,
--    "L_TM"  datetime not null,
--    "L_ACT" varchar not null,
--    "L_OVAL"  long varchar,
--    "L_NVAL"  long varchar
--)
--;

create procedure "VAD"."DBA"."VAD_READ_INI" (inout parr any) returns any
{
  declare name, type, val varchar;
  declare ini, ret integer;
  declare aout any;
  aout := vector();
  ini := "VAD"."DBA"."VAD_CHDIR" (parr, 1, '/INI');
  ret := "VAD"."DBA"."VAD_NODE_INFO_BY_NAME" (ini, 'DOCS_ROOT', name, type, val);
  aout := vector_concat (aout, vector('doc', val));
  if (parr is not null)
    "PUMP"."DBA"."CHANGE_VAL" (parr, 'docs_root', val);
  ret := ret + "VAD"."DBA"."VAD_NODE_INFO_BY_NAME" (ini, 'HTTP_ROOT', name, type, val);
  aout := vector_concat (aout, vector('http', val));
  if (parr is not null)
    "PUMP"."DBA"."CHANGE_VAL" (parr, 'http_root', val);
  ret := ret + "VAD"."DBA"."VAD_NODE_INFO_BY_NAME" (ini, 'CODE_ROOT', name, type, val);
  aout := vector_concat (aout, vector('code', val));
  if (parr is not null)
    "PUMP"."DBA"."CHANGE_VAL" (parr, 'code_root', val);
  ret := ret + "VAD"."DBA"."VAD_NODE_INFO_BY_NAME" (ini, 'DATA_ROOT', name, type, val);
  aout := vector_concat (aout, vector('data', val));
  if (parr is not null)
    "PUMP"."DBA"."CHANGE_VAL" (parr, 'data_root', val);
  ret := ret + "VAD"."DBA"."VAD_NODE_INFO_BY_NAME" (ini, 'DAV_ROOT', name, type, val);
  aout := vector_concat (aout, vector('dav', val));
  if (parr is not null)
    "PUMP"."DBA"."CHANGE_VAL" (parr, 'dav_root', val);
  return aout;
}
;


create procedure "VAD"."DBA"."VAD_GET_ROOT" ( in name varchar ) returns varchar
{
  declare arr, arr2 any;
  arr := null;
  arr2 := "VAD"."DBA"."VAD_READ_INI" (arr);
  declare s varchar;
  s := get_keyword (name, arr2);
  if (s is null or length(s) = 0)
  "VAD"."DBA"."VAD_FAIL_CHECK" (sprintf ('Attempt to get unknown root path:%s', name));
  return s;
}
;


create procedure "VAD"."DBA"."VAD_SET_ROOT" ( in name varchar, in val varchar) returns integer
{
  declare arr any;
  arr := null;

  name := upper (name);
  if (  name is null or
       (neq (name, 'DOCS_ROOT')
  and neq (name, 'HTTP_ROOT')
  and neq (name, 'CODE_ROOT')
  and neq (name, 'DAV_ROOT')
  and neq (name, 'DATA_ROOT')))
    "VAD"."DBA"."VAD_FAIL_CHECK" (sprintf ('illegal root type:%s',cast (name as varchar)));

  declare ini, ret integer;
  declare lname, ltype, lval varchar;
  ini := "VAD"."DBA"."VAD_CHDIR" (arr, 1, '/INI');
  ret := "VAD"."DBA"."VAD_NODE_INFO_BY_NAME" (ini, name, lname, ltype, lval, 0);

  if (not ret)
    return "VAD"."DBA"."VAD_MKNODE" (arr, ini, name, 'STRING', val);
  return "VAD"."DBA"."VAD_UPDATE_NODE" (ret, val, lval);
}
;

create procedure "VAD"."DBA"."VAD_MKDAV" (inout id integer, inout gd integer, in path varchar, inout ini any, in istest integer := 0, in _usr varchar := NULL, in _pwd varchar := NULL) returns integer
{
  declare parr any;
  parr := NULL;
  if (ini is null or length (ini) = 0)
    ini := "VAD"."DBA"."VAD_READ_INI"(parr);
  declare usr, pwd, p varchar;
  if (_usr is not null)
    usr := _usr;
  declare curid, i, n integer;
  declare lname varchar;
  declare par any;
  par := split_and_decode(path, 0, '\0\0/');
  i := 0;
  n := length(par);
  curid := 0;
  p := '/';
  while (i < n)
  {
    lname := aref(par, i);
    if (lname is not null and length(lname))
    {
      p := concat (p, lname, '/');
      curid := DB.DBA.DAV_SEARCH_ID(p, 'c');
      if (curid < 0)
        goto do_smth;
      goto cont;
      do_smth:;
      if (istest)
        return -1;
      usr := 'dav';
      pwd := pwd_magic_calc('dav', (select U_PWD from WS.WS.SYS_DAV_USER where U_NAME='dav'), 1);
      curid := "DB"."DBA"."DAV_COL_CREATE" (p, '111101101N', usr, NULL, usr, pwd);
      if (curid < 0)
        return curid;
    }
    cont:
    i := i + 1;
  }
  return 1;
}
;

create procedure "VAD"."DBA"."VAD_ATOMIC" ( in mode integer )
{
  if (sys_stat ('cl_run_local_only') <> 1)
    return;
  if (mode)
    {
      if (registry_get ('VAD_atomic') = '1')
      "VAD"."DBA"."VAD_FAIL_CHECK" ('Redundant attempt to enter atomic mode');
      __atomic(1);
      registry_set ('VAD_atomic', '1');
    }
  else
    {
      if (registry_get ('VAD_atomic') = '1')
  {
          registry_set ('VAD_atomic', '0');
    __atomic(0);
  }
    }
}
;



create procedure "VAD"."DBA"."VAD_FAIL_CHECK" ( in msg varchar ) returns integer
{
  rollback work;

  "VAD"."DBA"."VAD_ATOMIC"(0);

  registry_set ('VAD_msg', msg);
  registry_set ('VAD_errcount', cast (1 + cast (registry_get ('VAD_errcount') as integer) as varchar));

  signal ('42VAD', msg);
}
;


create procedure "VAD"."DBA"."VAD_CHDIR" (inout parr any, in curdir integer, in dirname varchar) returns integer
{
  curdir := cast (curdir as integer);
  dirname := cast (dirname as varchar);
  if (dirname is not null and aref (dirname, 0) <> 47 and not exists ( select "R_ID" from "VAD"."DBA"."VAD_REGISTRY" where "R_ID" = curdir ))
    {
      if (parr is not null)
      "VAD"."DBA"."VAD_REGET_HANDLERS" (parr);
      "VAD"."DBA"."VAD_FAIL_CHECK" (sprintf ('Illegal handler:%d', curdir));
  }
  declare i, n integer;
  declare arr any;
  declare ltype, lkey, lval varchar;
  arr := split_and_decode (dirname, 0, '\0\0/');
  i := 0;
  n := length (arr);
  if (aref(dirname,0) = 47) --'/'
    {
      curdir := 1;
      i:= 1;
    }
  whenever not found goto notfound;
  while (i<n)
    {
      select "R_ID", "R_TYPE", "R_KEY", "R_VALUE" into curdir, ltype, lkey, lval from "VAD"."DBA"."VAD_REGISTRY" where "R_PRNT" = curdir and (R_TYPE = 'FOLDER' or R_TYPE = 'KEY') and "R_SHKEY" = aref (arr,i);
    if (equ (ltype, 'KEY'))
      {
      curdir := "VAD"."DBA"."VAD_CHDIR" (parr, 1, lval);
    }
    else if (neq (ltype, 'FOLDER'))
      {
      return 0;
    }
      i := i + 1;
    }
  return curdir;
notfound:
  return 0;
}
;


create procedure "VAD"."DBA"."VAD_FIND_SMTH_BY_NAME" (in curdir integer, in itemname varchar) returns integer
{
  curdir := cast (curdir as integer);
  declare i, n integer;
  declare arr any;
  arr := split_and_decode (itemname, 0, '\0\0/');
  i := 0;
  n := length (arr);
  if (aref(itemname,0) = 47) --'/'
    {
      curdir := 1;
      i:= 1;
    }
  whenever not found goto notfound;
  while (i<n)
    {
      select "R_ID" into curdir from "VAD"."DBA"."VAD_REGISTRY" where "R_PRNT" = curdir and R_TYPE = 'FOLDER' and "R_SHKEY" = aref (arr,i);
      i := i + 1;
    }
  return curdir;
notfound:
  return 0;
}
;

create procedure "VAD"."DBA"."VAD_REGET_HANDLERS" (inout arr any) returns integer
{
  if (arr is null or length(arr) = 0)
    return 0;
  declare arr2 any;
  arr2 := "VAD"."DBA"."VAD_BUILD_TREE" ();
  declare s varchar;
  s := "VAD"."DBA"."VAD_STRIP_RN" (encode_base64 (gz_compress (serialize (arr2))));
  "PUMP"."DBA"."CHANGE_VAL" (arr, 'tree_ser', s);
  http (sprintf ('\n<script>document.forms[0].tree_ser.value="%s";</script>\n',s));
  return 1;
}
;

create procedure "VAD"."DBA"."VAD_FULL_PATH" (inout parr any, in curdir integer) returns varchar
{
  curdir := cast (curdir as integer);
  declare i integer;
  declare arr any;
  declare ret varchar;
  arr := vector();

  declare parent integer;
  declare shkey varchar;
  parent := 0;
  shkey := '';

  whenever not found goto fin2;

  while (1)
  {
    select "R_PRNT", "R_SHKEY"  into parent, shkey from "VAD"."DBA"."VAD_REGISTRY" where "R_ID" = curdir;
    arr := vector_concat (arr, vector(shkey));
    if (curdir = 1)
      goto fin;
    curdir := parent;
  }
fin:
  i := length (arr) - 1;
  ret := '';
  while (i>=0)
    {
      declare t varchar;
      t := aref (arr, i);
      if (t is not null and length(t))
    ret := concat (ret, '/', t);
      i := i - 1;
    }
  if (length(ret)=0)
    ret := '/';
  return ret;
fin2:
  if (parr is not null)
    "VAD"."DBA"."VAD_REGET_HANDLERS" (parr);
  "VAD"."DBA"."VAD_FAIL_CHECK" (sprintf ('Illegal handler:%d', curdir));
}
;


create procedure "VAD"."DBA"."VAD_TEST_PARENT" (inout parr any, in curdir integer, in name varchar, inout rid int)
returns varchar
{
  curdir := cast (curdir as integer);
  rid := null;
  if (not exists (select "R_ID" from "VAD"."DBA"."VAD_REGISTRY" where "R_ID" = curdir))
    {
      if (parr is not null)
        "VAD"."DBA"."VAD_REGET_HANDLERS" (parr);
      "VAD"."DBA"."VAD_FAIL_CHECK" (sprintf ('Illegal current directory handler:%d', curdir));
  }
  whenever not found goto nfrid;
  select "R_ID" into rid from "VAD"."DBA"."VAD_REGISTRY" where "R_PRNT" = curdir and "R_SHKEY" = name;
  nfrid:
  --if (exists (select "R_ID" from "VAD"."DBA"."VAD_REGISTRY" where "R_PRNT" = curdir and "R_SHKEY" = name))
  --  "VAD"."DBA"."VAD_FAIL_CHECK" (sprintf ('registry path already exists:%s', name));
  declare nname varchar;
  nname := "VAD"."DBA"."VAD_FULL_PATH" (parr, curdir);
  if (not exists (select "R_ID" from "VAD"."DBA"."VAD_REGISTRY" where "R_ID" = curdir and "R_KEY" = nname))
    "VAD"."DBA"."VAD_FAIL_CHECK" (sprintf ('parent directory name mismatch:%s', nname));
  return nname;
}
;


create procedure "VAD"."DBA"."VAD_TEST_NODE_TYPE" (in type varchar) returns varchar
{
  type := upper (type);
  if (  type is null or
       (neq (type, 'FOLDER')
  and neq (type, 'STRING')
  and neq (type, 'INTEGER')
  and neq (type, 'KEY')
  and neq (type, 'URL')
  and neq (type, 'XML')))
    "VAD"."DBA"."VAD_FAIL_CHECK" (sprintf ('illegal node type:%s',cast (type as varchar)));
  return type;
}
;

create procedure "VAD"."DBA"."VAD_MKDIR" (inout parr any, in curdir integer, in name varchar ) returns integer
{
  curdir := cast (curdir as integer);
  declare nname varchar;
  declare _id integer;
  nname := "VAD"."DBA"."VAD_TEST_PARENT" (parr, curdir, name, _id);
  if (aref(nname, length (nname) - 1 ) <> 47) --'/'
    nname := concat (nname, '/');
  nname := concat (nname,  name);
  if (_id is null)
  _id := sequence_next('vad_id');
  insert replacing "VAD"."DBA"."VAD_REGISTRY" ("R_ID", "R_PRNT", "R_KEY", "R_SHKEY", "R_TYPE") values (_id, curdir, nname, name, 'FOLDER');
  --insert replacing "VAD"."DBA"."VAD_LOG" ("L_KEY", "L_TM", "L_ACT") values (nname, now(), 'MKDIR');
--  commit work;
  return _id;
}
;


create procedure "VAD"."DBA"."VAD_MKCD" (inout parr any, in curdir integer, in name varchar ) returns integer
{
  curdir := cast (curdir as integer);
  declare tid integer;
  tid := "VAD"."DBA"."VAD_CHDIR" (parr, curdir, name);
  if (tid)
    return tid;
  else
    return "VAD"."DBA"."VAD_MKDIR" (parr, curdir, name);
}
;


create procedure "VAD"."DBA"."VAD_RMDIR" (inout parr any, in curdir integer) returns integer
{
  curdir := cast (curdir as integer);
  declare name varchar;
  declare id integer;
  if (not exists (select "R_ID" from "VAD"."DBA"."VAD_REGISTRY" where "R_ID" = curdir and "R_TYPE" = 'FOLDER'))
    "VAD"."DBA"."VAD_FAIL_CHECK" (sprintf ('Directory been removed does not exist:%d', curdir));
  if (1 = curdir)
    "VAD"."DBA"."VAD_FAIL_CHECK" (sprintf ('You can\'t remove root directory'));

  select "R_KEY", "R_PRNT" into name, id from "VAD"."DBA"."VAD_REGISTRY" where "R_ID" = curdir;

  if (exists (select "R_KEY" from "VAD"."DBA"."VAD_REGISTRY" where "R_PRNT" = curdir))
    "VAD"."DBA"."VAD_FAIL_CHECK" (sprintf ('Directory is not empty:%s', name));
  delete from "VAD"."DBA"."VAD_REGISTRY" where blob_to_string ("R_VALUE") = name and "R_TYPE" = 'KEY';
  delete from "VAD"."DBA"."VAD_REGISTRY" where "R_ID" = curdir;
  --insert into "VAD"."DBA"."VAD_LOG" ("L_KEY", "L_TM", "L_ACT") values (name, now(), 'RMDIR');
  if (parr is not null)
    "PUMP"."DBA"."CHANGE_VAL" (parr, 'reg_curdir', cast (id as varchar));

--  commit work;
  return 1;
}
;


create procedure "VAD"."DBA"."VAD_RMNODE" (in id integer) returns integer
{
  id := cast (id as integer);
  declare skey varchar;
  whenever not found goto err;
  select "R_KEY" into skey from "VAD"."DBA"."VAD_REGISTRY" where "R_ID" = id and "R_TYPE" <> 'FOLDER';

  delete from "VAD"."DBA"."VAD_REGISTRY" where blob_to_string ("R_VALUE") = skey and "R_TYPE" = 'KEY';
--  if (row_count())
--    {
--      dbg_obj_print ('skey=', skey, 'id=',id);
--      dbg_obj_print ('deleted:', row_count());
--    }
  delete from "VAD"."DBA"."VAD_REGISTRY" where "R_ID" = id;
  --insert into "VAD"."DBA"."VAD_LOG" ("L_KEY", "L_TM", "L_ACT") values (skey, now(), 'RMNODE');

--  commit work;
  return 1;
err:
  "VAD"."DBA"."VAD_FAIL_CHECK" (sprintf ('Item been removed does not exist:%d', id));
}
;


create procedure "VAD"."DBA"."VAD_MKNODE" (inout parr any, in curdir integer, in name varchar, in type varchar, in val varchar ) returns integer
{
  declare _id integer;
  curdir := cast (curdir as integer);
  type := "VAD"."DBA"."VAD_TEST_NODE_TYPE" (type);
  declare nname varchar;
  nname := "VAD"."DBA"."VAD_TEST_PARENT" (parr, curdir, name, _id);
  if (aref(nname, length (nname) - 1 ) <> 47) --'/'
    nname := concat (nname, '/');
  nname := concat (nname,  name);
  "VAD"."DBA"."VAD_TEST_VALUE" (type, val);
  if (_id is null)
  _id := sequence_next('vad_id');
  delete from "VAD"."DBA"."VAD_REGISTRY" where "R_ID" = _id;
  insert into "VAD"."DBA"."VAD_REGISTRY" ("R_ID", "R_PRNT", "R_KEY", "R_SHKEY", "R_TYPE", "R_VALUE") values (_id, curdir, nname, name, type, val);
  --insert replacing "VAD"."DBA"."VAD_LOG" ("L_KEY", "L_TM", "L_ACT", "L_NVAL") values (nname, now(), 'MKNODE', val);
--  commit work;
  return _id;
}
;


create procedure "VAD"."DBA"."VAD_UPDATE_NODE" (in curid integer, in val varchar, in oldval varchar ) returns integer
{
  curid := cast (curid as integer);
  declare name, oval, type, okey varchar;
  declare prnt integer;
  whenever not found goto err;

  select "R_SHKEY", "R_TYPE", "R_VALUE", "R_PRNT", "R_KEY" into name, type, oval, prnt, okey from "VAD"."DBA"."VAD_REGISTRY" where "R_ID" = curid and "R_TYPE" <> 'FOLDER';
  if (neq (oldval, oval))
    "VAD"."DBA"."VAD_FAIL_CHECK" (sprintf ('Value of item "%s" was changed from outside', name));

  "VAD"."DBA"."VAD_TEST_VALUE" (type, val);

  update "VAD"."DBA"."VAD_REGISTRY" set "R_PRNT"=prnt, "R_KEY"=okey, "R_SHKEY"=name, "R_TYPE"=type, "R_VALUE"=val where "R_ID"=curid;
--  insert into "VAD"."DBA"."VAD_LOG" ("L_KEY", "L_TM", "L_ACT", "L_OVAL", "L_NVAL") values (okey, now(), 'UPDNODE', oldval, val);
--dbg_obj_print (okey, now());
--insert into "VAD"."DBA"."VAD_LOG" ("L_KEY", "L_TM", "L_ACT") values (okey, now(), 'UPDNODE');
  return 1;

err:
  "VAD"."DBA"."VAD_FAIL_CHECK" (sprintf ('Attempt of getting info for non-existent node %d', curid));
}
;

create procedure "VAD"."DBA"."VAD_TEST_VALUE" ( in type varchar, inout val varchar ) returns integer
{
  if (equ (type, 'FOLDER'))
    return 1;
  else if (equ (type, 'STRING') or equ (type, 'URL'))
    {
    val := cast (val as varchar);
    return 1;
  }
  else if (equ (type, 'INTEGER'))
    {
    val := trim (val);
    if (val is null or 0=length(val))
      "VAD"."DBA"."VAD_FAIL_CHECK" ('Empty  string used as integer value');
    declare c integer;
    c := aref (val, 0);
    if (c<48 or c>57)
      "VAD"."DBA"."VAD_FAIL_CHECK" ('Non-numeric string used as integer value');
    val := cast (cast (val as integer) as varchar);
    return 1;
  }
  else if (equ (type, 'KEY'))
    {
      if (not exists (select "R_ID" from "VAD"."DBA"."VAD_REGISTRY" where "R_KEY" = val))
    "VAD"."DBA"."VAD_FAIL_CHECK" (sprintf ('Attempt to create key on non-existing item:%s', cast (val as varchar)));
    return 1;
  }
  else if (equ (type, 'XML'))
    {
--    declare tval varchar;
--      if (val is not null and __tag (val) = 185) -- strses
--      {
--      if (length(val) > 10000000)
--      signal ('42VAD', 'Attempt to create xml key greater 10M');
--      tval := string_output_string (val);
--    }
--    else tval := val;
    declare tree any;
    tree := xml_tree (val);
    return 1;
  }
  "VAD"."DBA"."VAD_FAIL_CHECK" (sprintf ('illegal node type:%s',cast (type as varchar)));
}
;


create procedure "VAD"."DBA"."VAD_NODE_INFO" (in nodeid integer, inout name varchar, inout type varchar, inout val varchar ) returns integer
{
  nodeid := cast (nodeid as integer);
  whenever not found goto err;
  select "R_SHKEY", "R_TYPE", "R_VALUE" into name, type, val from "VAD"."DBA"."VAD_REGISTRY" where "R_ID" = nodeid and "R_TYPE" <> 'FOLDER';
  return 1;

err:
  "VAD"."DBA"."VAD_FAIL_CHECK" (sprintf ('Attempt of getting info for inexistent node %d', nodeid));
}
;


create procedure "VAD"."DBA"."VAD_NODE_INFO_BY_NAME" (in curdir integer, in nodename varchar, inout name varchar, inout type varchar, inout val varchar, in ignite_error integer := 1 ) returns integer
{
  declare iid integer;
  curdir := cast (curdir as integer);
  whenever not found goto err;
  select "R_ID", "R_SHKEY", "R_TYPE", "R_VALUE" into iid, name, type, val from "VAD"."DBA"."VAD_REGISTRY" where "R_PRNT" = curdir and "R_TYPE" <> 'FOLDER' and "R_SHKEY" = nodename;
  return iid;

err:
  if (ignite_error)
    "VAD"."DBA"."VAD_FAIL_CHECK" (sprintf ('Attempt of getting info for inexistent node %d/%s', curdir, nodename));
  return 0;
}
;


create procedure "VAD"."DBA"."VAD_NEW_PACKAGE" (inout parr any, in name varchar, in version varchar ) returns integer
{
  declare curdir, tid, ret integer;
  declare ini any;
  declare s, lname, ltype, lval varchar;
  curdir := "VAD"."DBA"."VAD_CHDIR"(parr, 0, '/VAD');
  tid := "VAD"."DBA"."VAD_CHDIR"(parr, curdir, name);
  if (tid = 0)
    tid := "VAD"."DBA"."VAD_MKDIR"(parr, curdir, name);
  ret := "VAD"."DBA"."VAD_NODE_INFO_BY_NAME"(tid, 'CurrentVersion', lname, ltype, lval, 0);
  if (not ret)
    "VAD"."DBA"."VAD_MKNODE"(parr, tid, 'CurrentVersion', 'STRING', version);
  else
    "VAD"."DBA"."VAD_UPDATE_NODE"(ret, version, lval);
  curdir := "VAD"."DBA"."VAD_CHDIR"(parr, tid, version);
  if (curdir = 0)
    tid := "VAD"."DBA"."VAD_MKDIR"(parr, tid, version);
  else
    "VAD"."DBA"."VAD_FAIL_CHECK"(sprintf ('There exists such package:%s', name));
  ini := null;
  s := concat('/DAV/VAD/', name, '/');
  "VAD"."DBA"."VAD_DAV_MKCOL"(ini, s);
  s := concat(s, version, '/');
  "VAD"."DBA"."VAD_DAV_MKCOL"(ini, s);
  return tid;
}
;

create procedure "VAD"."DBA"."__VAD_BUILD_TREE" ( in curdir integer, in name varchar, in ltype varchar, in lkey varchar ) returns any
{
  declare tname, ttype, tkey varchar;
  declare tid, fnd integer;
  declare arr, arr2, tarr any;
  declare lcurdir, sysf integer;
  lcurdir := curdir;
  sysf := 0;
  tarr := null;
  if (equ (ltype, 'KEY'))
    {
      lcurdir := "VAD"."DBA"."VAD_CHDIR" (tarr, 1, lkey);
  }
  if (lcurdir < 1000)
    sysf := 1;
  arr := vector(lcurdir, name, sysf);
  declare cr cursor for select  f1."R_ID", f1."R_SHKEY", f1."R_TYPE", f1."R_VALUE" from "VAD"."DBA"."VAD_REGISTRY" as f1 where "R_PRNT"=curdir and ("R_TYPE" = 'FOLDER' or
  ("R_TYPE" = 'KEY' and exists (select  "R_ID" from "VAD"."DBA"."VAD_REGISTRY" as f2 where f2."R_TYPE" = 'FOLDER' and blob_to_string (f1."R_VALUE") = f2."R_KEY")));
  open cr;
  whenever not found goto fin;
  fnd := 0;
  while (1)
    {
      fetch cr into tid, tname, ttype, tkey;
    if (tid <> curdir)
    {
        arr2 := "VAD"."DBA"."__VAD_BUILD_TREE" (tid, tname, ttype, tkey);
        arr := vector_concat (arr, vector(arr2));
      fnd := 1;
      }
    }
fin:
  close cr;
  if (fnd = 0)
    arr := vector_concat (arr, vector(NULL));
  return arr;
}
;


create procedure "VAD"."DBA"."VAD_BUILD_TREE" (  ) returns any
{
  declare arr any;
  arr := "VAD"."DBA"."__VAD_BUILD_TREE" (1, '/', 'FOLDER', '/');
  return arr;
}
;


create procedure "VAD"."DBA"."VAD_GET_PACKAGES" ( ) returns any
{
  declare retarr, tmparr any;
  retarr := vector();
  tmparr := null;

  declare curdir, tid, tid2 integer;
  declare tname, tname2 varchar;
  curdir := "VAD"."DBA"."VAD_CHDIR"(tmparr, 0, '/VAD');
  declare cr cursor for select  "R_ID", "R_SHKEY" from "VAD"."DBA"."VAD_REGISTRY" where "R_PRNT"=curdir and "R_TYPE" = 'FOLDER';
  open cr;
  while (1)
    {
      whenever not found goto fin;
      fetch cr into tid, tname;

      declare cr2 cursor for select  "R_VALUE" from "VAD"."DBA"."VAD_REGISTRY" where "R_PRNT"=tid and "R_TYPE" = 'STRING' and R_SHKEY='CurrentVersion';
      open cr2;
      while (1)
      {
	declare build, inst, title, verid any;
        whenever not found goto fin2;
        fetch cr2 into tname2;
	verid := "VAD"."DBA"."VAD_CHDIR"(tmparr, tid, tname2);
	build := (select  "R_VALUE" from "VAD"."DBA"."VAD_REGISTRY" where "R_PRNT"=verid and "R_TYPE" = 'STRING' and R_SHKEY='Release Date');
	inst := (select  "R_VALUE" from "VAD"."DBA"."VAD_REGISTRY" where "R_PRNT"=verid and "R_TYPE" = 'STRING' and R_SHKEY='Install Date');
	title := (select  "R_VALUE" from "VAD"."DBA"."VAD_REGISTRY" where "R_PRNT"=verid and "R_TYPE" = 'STRING' and R_SHKEY='Title');
        retarr := vector_concat (retarr, vector (vector (tid2, tname, tname2, build, inst, title)));
      }
fin2:;
  }
fin:
  close cr;

  return retarr;
}
;

create procedure "VAD"."DBA"."__VAD_DEL_SUBTREE"(in curdir integer) returns any
{
  declare tname varchar;
  declare tid, fnd integer;
  declare cr cursor for select "R_ID" from "VAD"."DBA"."VAD_REGISTRY" where "R_PRNT"=curdir and "R_TYPE" = 'FOLDER';
  open cr;
  whenever not found goto fin;
  fnd := 0;
  while (1)
  {
    fetch cr into tid;
    if (tid <> curdir)
      "VAD"."DBA"."__VAD_DEL_SUBTREE" (tid);
  }
  close cr;
fin:
  for select "R_ID" as rid from "VAD"."DBA"."VAD_REGISTRY" where "R_PRNT" = curdir do
  {
    "VAD"."DBA"."VAD_RMNODE" (rid);
  }
  declare arr any;
  arr := vector();
  "VAD"."DBA"."VAD_RMDIR" (arr, curdir);
--  delete from "VAD"."DBA"."VAD_REGISTRY" where "R_VALUE" = skey and "R_TYPE" = 'KEY';
--  delete from "VAD"."DBA"."VAD_REGISTRY" where "R_ID" = curdir;
--  commit work;
  return 1;
}
;


create procedure "VAD"."DBA"."VAD_DEL_SUBTREE" ( in curdir integer ) returns any
{
  curdir := cast (curdir as integer);
  declare name varchar;
  declare id integer;
  if (not exists (select "R_ID" from "VAD"."DBA"."VAD_REGISTRY" where "R_ID" = curdir and "R_TYPE" = 'FOLDER'))
    "VAD"."DBA"."VAD_FAIL_CHECK" (sprintf ('Subtree been removed does not exist:%d', curdir));
  if (exists (select top 1 1 from "VAD"."DBA"."VAD_REGISTRY" where "R_ID" = curdir and "R_PRNT" = 1))
    "VAD"."DBA"."VAD_FAIL_CHECK" (sprintf ('You can\'t remove system subtree'));
  return "VAD"."DBA"."__VAD_DEL_SUBTREE" (curdir);
}
;


create procedure "VAD"."DBA"."VAD_GET_PKG_ID" (inout parr any, in name varchar, in version varchar ) returns integer
{
  declare curdir, tid integer;
  curdir := "VAD"."DBA"."VAD_CHDIR"(parr, 0, '/VAD');
  tid := "VAD"."DBA"."VAD_CHDIR"(parr, curdir, name);
  if (tid = 0)
    return 0;
  curdir := "VAD"."DBA"."VAD_CHDIR"(parr, tid, version);
  if (curdir = 0)
  return 0;
  else
  return curdir;
}
;


create procedure "VAD"."DBA"."__vad_init"()
{
  declare parr, ini any;
  parr := NULL;
  ini := NULL;
  if (not exists(select * from "VAD"."DBA"."VAD_REGISTRY" where "R_ID" = "R_PRNT"))
  {
    declare _ini_id integer;
    sequence_next('vad_id');
    sequence_next('vad_id');
    sequence_next('vad_id');
    insert replacing "VAD"."DBA"."VAD_REGISTRY" ("R_ID", "R_PRNT", "R_KEY", "R_SHKEY", "R_TYPE") values (1, 1, '/', '', 'FOLDER');
    _ini_id := "VAD"."DBA"."VAD_MKDIR" (parr, 1, 'INI');
    "VAD"."DBA"."VAD_SET_ROOT" ( 'DOCS_ROOT', './vad/doc');
    "VAD"."DBA"."VAD_SET_ROOT" ( 'HTTP_ROOT', './vad/vsp');
    "VAD"."DBA"."VAD_SET_ROOT" ( 'CODE_ROOT', './vad/code');
    "VAD"."DBA"."VAD_SET_ROOT" ( 'DATA_ROOT', './vad/data');
    "VAD"."DBA"."VAD_SET_ROOT" ( 'DAV_ROOT',  '/DAV/VAD');
    "VAD"."DBA"."VAD_MKDIR" (parr, 1, 'DOCS');
    "VAD"."DBA"."VAD_MKDIR" (parr, 1, 'FILES');
    "VAD"."DBA"."VAD_MKDIR" (parr, 1, 'SCHEMA');
    "VAD"."DBA"."VAD_MKDIR" (parr, 1, 'VAD');
    _ini_id := sequence_set ('vad_id', 0, 2);
    sequence_set ('__NEXT__vad_id', _ini_id + 1, 1);
--    sequence_set ('vad_id', 1000, 0);
  }
}
;

--!AFTER
"VAD"."DBA"."__vad_init"()
;
