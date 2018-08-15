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

      col := DAV_SEARCH_ID (path, 'C');
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


create procedure t_populate_sioc (in path varchar)
{
  declare graph varchar;
  declare data varchar;
  declare s,e integer;
  
  graph := cfg_item_value (virtuoso_ini_path(), 'URIQA', 'DefaultHost');
  if (graph is null)
    return;
  graph := 'http://' || ltrim(graph,'/') || '/tutorial';
  
  data := xml_uri_get(path,'');
  
  data := replace(blob_to_string(data),'<?V _path ?>',graph||'/');
  
  s := strstr(data,'<?vsp');
  e := strstr(data,'<rdf:RDF');
  
  if (s is not null)
  data := substring(data,1,s) || subseq(data,e);
  
  DELETE FROM DB.DBA.RDF_QUAD WHERE G = DB.DBA.RDF_MAKE_IID_OF_QNAME (graph);
  
  DB.DBA.RDF_LOAD_RDFXML(data,graph,graph);
    
};


create procedure tut_generate_tomcat_url (in tut_name any, in lines any)
{

   -- First get the tomcat HTTP port.

   declare path, ini_s, idx, pos, ini_f, port, temp, line, fhost any;

   declare exit handler for sqlstate '*'
     {
	connection_set ('TomcatStatus', 'BAD');
	return '';
     };

   idx := 1;
   ini_s := '';
   path := '';

   while (ini_s is not NULL)
    {
	ini_s := cfg_item_value(virtuoso_ini_path(), 'Parameters','JavaVMOption' || cast (idx as varchar));
	if (strstr (ini_s, 'catalina.home'))
	   {
		pos := strstr (ini_s, '=');
		path := "RIGHT" (ini_s, length (ini_s) - pos - 1);
		ini_s := NULL;
	   }
	idx := idx + 1;
    }

   if (path = '' and tut_name <> '')
	signal ('TUT01', 'Can''t get Catalina home dir.');

   ini_f := file_to_string (path || '/conf/server.xml');
   ini_f := xml_tree_doc (ini_f);
   port := xpath_eval ('//Service/Connector/@port', ini_f, 1);

   if (port is NULL and tut_name <> '')
	signal ('TUT02', 'Can''t get tomcat HTTP port.');

   port := cast (port as varchar);
   fhost := http_request_header (lines, 'Host', null, 'localhost');
   fhost := split_and_decode (fhost, 0, ':=:');
   fhost := fhost[0];

   -- Make list of samples

   declare exit handler for sqlstate '08001'
     {
	connection_set ('TomcatStatus', 'BAD');
	return '';
	signal ('TUT03', 'Tomcat is not started. Please Start it in order to continue whit sample.');
     };

   temp := http_get ('http://' || fhost || ':' || port || '/jsp-examples/');
   temp := xml_tree_doc (xml_tree (temp, 2));
   temp := xpath_eval ('//@href', temp, 0);

   if (not exists (select 1 from DB.DBA.HTTP_PATH where HP_LPATH = '/jsp_tutorial'))
     VHOST_DEFINE (lpath=>'/jsp_tutorial',ppath=>'http://' || fhost || ':' || port || '/jsp-examples/');

   for (declare x any, x := 0; x < length (temp); x := x + 1)
     {
	 line := cast (temp[x] as varchar);
	 if (strstr (line, tut_name))
  	   return 'http://' || fhost || ':' || server_http_port () || '/jsp_tutorial/' || line;
     }

  return '';
}
;

create procedure DB.DBA.rd_v_1_localize()
{
  declare file_text, uriqa varchar;
  uriqa := registry_get('URIQADefaultHost');
  file_text := (select blob_to_string (RES_CONTENT) from WS.WS.SYS_DAV_RES 
   where RES_FULL_PATH='/DAV/VAD/tutorial/rdfview/rd_v_1/rd_v_1.sql');
  file_text := replace(file_text, 'URIQA2_MACRO', uriqa);
  update WS.WS.SYS_DAV_RES set RES_CONTENT=file_text where RES_FULL_PATH='/DAV/VAD/tutorial/rdfview/rd_v_1/rd_v_1.sql';
  
  file_text := (select blob_to_string (RES_CONTENT) from WS.WS.SYS_DAV_RES 
    where RES_FULL_PATH='/DAV/VAD/tutorial/rdfview/rd_v_1/rd_v_1.owl');
  file_text := replace(file_text, 'URIQA_MACRO', uriqa);
  update WS.WS.SYS_DAV_RES set RES_CONTENT=file_text where RES_FULL_PATH='/DAV/VAD/tutorial/rdfview/rd_v_1/rd_v_1.owl';
}
;
			
DB.DBA.rd_v_1_localize()
;
			
drop procedure DB.DBA.rd_v_1_localize
;
