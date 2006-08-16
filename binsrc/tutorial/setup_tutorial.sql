--  
--  $Id$
--  
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--  
--  Copyright (C) 1998-2006 OpenLink Software
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

create procedure
sql_user_password (in name varchar)
{
  declare pass varchar;
  pass := NULL;
  whenever not found goto none;
  select pwd_magic_calc (U_NAME, U_PASSWORD, 1) into pass
      from SYS_USERS where U_NAME = name and U_SQL_ENABLE = 1 and U_IS_ROLE = 0;
none:
  return pass;
}
;

create procedure
sql_user_password_check (in name varchar, in pass varchar)
{
  if (exists (select 1 from SYS_USERS where U_NAME = name and U_SQL_ENABLE = 1 and U_IS_ROLE = 0 and
	pwd_magic_calc (U_NAME, U_PASSWORD, 1) = pass))
    return 1;
  return 0;
}
;

create procedure
demo_user_password (in name varchar)
{
	return pwd_magic_calc('demo','demo',1);
};

create procedure
demo_user_password_check (in name varchar, in pass varchar)
{
  return 1;
}
;

create procedure t_file_stat (in path varchar, in pdav int := null)
{
  declare ret any;
  ret := 0;

  if ( pdav is null) pdav := http_map_get ('is_dav');

  if (pdav)
    {
      ret := coalesce ((select cast (res_mod_time as varchar) from WS.WS.SYS_DAV_RES where RES_FULL_PATH = path), 0);
    }
  else
    {
      ret := file_stat (path);
    }
  return ret;
}
;

create procedure t_file_to_string (in path varchar, in pdav int := null)
{
  declare ret any;
  if ( pdav is null) pdav := http_map_get ('is_dav');

  if (pdav)
    {
      ret := (select blob_to_string (RES_CONTENT) from WS.WS.SYS_DAV_RES where RES_FULL_PATH = t_normalize_path(path));
    }
  else
    {
      ret := file_to_string (path);
    }
  return ret;
}
;

create procedure t_normalize_path (in path varchar)
{
  declare res varchar;
  res := path;
  
  while(regexp_match('\\.\\.',res)){
    res := regexp_replace(res,'/[^/.]*/\\.\\./','/');
  }
  return res;
}
;

create procedure t_sys_dirlist (in path varchar, in files int, in err any, in sorts int, in pdav int := null)
{
  declare ret any;
  ret := vector ();
  if ( pdav is null) pdav := http_map_get ('is_dav');

  if (pdav)
    {
      declare col any;
      if (path[length(path)-1] <> ascii ('/'))
	path := path || '/';
      col := (select COL_ID from WS.WS.SYS_DAV_COL where WS.WS.COL_PATH (COL_ID) = path);
      if (files)
	{
	  for select RES_NAME from WS.WS.SYS_DAV_RES where RES_COL = col do
	    {
	      ret := vector_concat (ret, vector (RES_NAME));
	    }
        }
      else
	{
	  for select COL_NAME from WS.WS.SYS_DAV_COL where COL_PARENT = col do
	    {
	      ret := vector_concat (ret, vector (COL_NAME));
	    }
	}
    }
  else
    {
      ret := sys_dirlist (path, files, err, sorts);
    }
  return ret;
}
;

create procedure t_get_pwd (in path varchar, in pdav int := null)
{
  if ( pdav is null) pdav := http_map_get ('is_dav');

  if (pdav)
    {
      return path;
    }
  else
    {
      return concat (http_root (), path);
    }
}
;


create procedure t_load_script (in path varchar, in pdav int := null)
{
  declare cnt, parts, errors any;
  cnt := t_file_to_string (path, pdav);
  parts := sql_split_text (cnt);
  errors := vector ();
  foreach (varchar s in parts) do
    {
      declare stat, msg any;
      stat := '00000';
      exec (s, stat, msg);
      if (stat <> '00000')
	{
	  --dbg_obj_print (stat, msg);
	  if (lower (trim (s, ' \r\n')) not like 'drop %')
	    {
	      errors := vector_concat (errors, vector (vector (stat, msg)));
	    }
	  rollback work;
	}
      else
	{
	  commit work;
	}
    }
  return errors;
}
;

create procedure tcheck_package (in pname varchar)
{
  declare aXML any;
  declare i integer;

  i := 0;
  aXML := VAD.DBA.VAD_GET_PACKAGES ();
  while(i<length(aXML))
  {
    if (aXML[i][1] = pname)
       return 1;
    i := i + 1;
  };
  return 0;
}
;

create procedure ensure_tutorial_demo_user ()
{
  declare id int;
  if (not exists (select 1 from SYS_USERS where U_NAME = 'tutorial_demo'))
    {
      id := DB.DBA.USER_CREATE ('tutorial_demo', 'secret',
	  vector ('SQL_ENABLE', 0, 'DAV_ENABLE', 1, 'DISABLED', 0, 'HOME', '/DAV/home/tutorial_demo/'));
      DB.DBA.DAV_MAKE_DIR ('/DAV/home/', http_dav_uid (), http_admin_gid (), '110100100R');
      DB.DBA.DAV_COL_CREATE_INT ('/DAV/home/tutorial_demo/', '110100100R',
	  id, http_admin_gid (), 'dav', null, 1, 0, 1, null, null);
    }
  else
  	{
      id := (select U_ID from SYS_USERS where U_NAME = 'tutorial_demo');
      DB.DBA.DAV_MAKE_DIR ('/DAV/home/', http_dav_uid (), http_admin_gid (), '110100100R');
      DB.DBA.DAV_COL_CREATE_INT ('/DAV/home/tutorial_demo/', '110100100R',
	  id, http_admin_gid (), 'dav', null, 1, 0, 1, null, null);
    };
  		
};

ensure_tutorial_demo_user ();

