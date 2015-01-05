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

create procedure child_node_fun (in node_name varchar, in node varchar)
{
  declare i, l int;
  declare ret, arr any;
  declare exit handler for sqlstate '*'
    {
      return vector ();
    };
  declare is_dav int;
  is_dav := http_map_get ('is_dav');
  ret := vector ();

  if (is_dav)
  {
    declare col any;
    if (node_name[length(node_name)-1] <> ascii ('/'))
	    node_name := node_name || '/';
    col := (select COL_ID from WS.WS.SYS_DAV_COL where WS.WS.COL_PATH (COL_ID) = node_name);

	  for select COL_NAME from WS.WS.SYS_DAV_COL where COL_PARENT = col do
	  {
	    ret := vector_concat (ret, vector (COL_NAME));
	  }
    for select RES_NAME from WS.WS.SYS_DAV_RES where RES_COL = col do
    {
      ret := vector_concat (ret, vector (RES_NAME));
    }
	}
  else
  {
    if (isstring (file_stat (node_name, 3)))
      return vector ();
    arr :=
      vector_concat (sys_dirlist (node_name, 0), sys_dirlist (node_name, 1));
    l := length (arr);
    while (i < l)
    {
      if (arr[i] <> '.' and arr[i] <> '..')
        ret := vector_concat (ret, vector (arr[i]));
      i := i + 1;
    }
  }
  return ret;
}
;

create procedure root_node_fun (in path varchar)
{
  declare i, l int;
  declare ret, arr any;
  declare is_dav int;
  is_dav := http_map_get ('is_dav');
  ret := vector ();

  if (is_dav)
  {
    declare col any;
    if (path[length(path)-1] <> ascii ('/'))
	    path := path || '/';
    col := (select COL_ID from WS.WS.SYS_DAV_COL where WS.WS.COL_PATH (COL_ID) = path);

	  for select COL_NAME from WS.WS.SYS_DAV_COL where COL_PARENT = col do
	  {
	    ret := vector_concat (ret, vector (COL_NAME));
	  }
    for select RES_NAME from WS.WS.SYS_DAV_RES where RES_COL = col do
    {
      ret := vector_concat (ret, vector (RES_NAME));
    }
	}
  else
  {
    arr := vector_concat (sys_dirlist (path, 0), sys_dirlist (path, 1));
    l := length (arr);
    while (i < l)
    {
      if (arr[i] <> '.' and arr[i] <> '..')
        ret := vector_concat (ret, vector (arr[i]));
      i := i + 1;
    }
  }
  return ret;
}
;

