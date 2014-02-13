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
-- Sample content providing procedures for vdir browser.
-- 2 procedures should be supplied - for meta-information and for content.
-- Meta procedure: does not have parameters and returns a vector of string names of content columns.
-- Content-providing procedure:
-- Parameters:
-- path - path to get content for
-- filter - filter mask for content
-- Return value:
-- Vector of vectors each describes one content item.
-- Format of item vector:
-- [0] - integer = 1 if item is a container (node), 0 if item is a leaf;
-- [1] - varchar item name;
-- [2] - varchar item icon name (e.g. 'images/txtfile.gif' etc.),
--       if NULL, predefined icons for folder and document will be used according to [0] element
-- [3], [4] .... - optional !varchar! fields to show as item describing info,
--       each element will be placed in its own column in details view.
-- 3rd procedure is optional - it is used for folder creation
-- Parameters:
-- path - path to get content for
-- newfolder - name of the folder to create
-- Return value:
-- integer 1 on success, 0 on error.

create procedure db.dba.vdir_browse_proc_meta() returns any
{
  declare retval any;
  retval := vector('ITEM_IS_CONTAINER','ITEM_NAME','ICON_NAME','Description');
  return retval;
}
;

create procedure db.dba.vdir_browse_proc( in path varchar, in filter varchar := '' ) returns any
{
  declare level, is_node integer;
  declare cat, sch, tbl, descr varchar;
  declare retval any;

  retval := vector();
  --retval := vector_concat(retval, vector(vector('ITEM_IS_CONTAINER','ITEM_NAME','ICON_NAME','Description')));

  path := trim(path,'.');

  if( isnull(filter) or filter = '' )
    filter := '%.%.%';
  replace(filter, '*', '%');

  --dbg_obj_print('path',path);
  cat := left( path, coalesce(strchr(path,'.'),length(path)) );
  path := ltrim(subseq( path, length(cat)), '.');
  cat := trim(cat,'"');
  --dbg_obj_print('path',path);

  sch := left( path, coalesce(strchr(path,'.'), length(path)) );
  path := ltrim(subseq( path, length(sch) ), '.');
  sch := trim(sch,'"');
  --dbg_obj_print('path',path);
  tbl := trim(left( path, coalesce(strchr(path,'.'), length(path)) ),'"');
  --if(tbl<>'') level := 3;
  if(sch<>'') level := 2;
  else if(cat<>'') level := 1;
  else level := 0;
  cat := case when cat <> '' then cat else '%' end;
  sch := case when sch <> '' then sch else '%' end;
  -- dbg_obj_print('cat',cat,'sch',sch,'tbl',tbl,'level',level);

  is_node := case when level < 2 then 1 else 0 end;
  descr := case level when 0 then 'Catalog' when 1 then 'Schema' else 'Table' end;

  for( select distinct name_part (KEY_TABLE, level) as ITEM from DB.DBA.SYS_KEYS
       where name_part (KEY_TABLE, 0) like cat
         and name_part (KEY_TABLE, 1) like sch
         AND KEY_TABLE LIKE filter
     ) do {
   --dbg_obj_print('item',ITEM);
     retval := vector_concat(retval, vector(vector(is_node, ITEM, NULL,descr)));
  }
  return retval;
}
;


create procedure db.dba.dav_browse_proc_meta() returns any
{
  declare retval any;
  retval := vector('ITEM_IS_CONTAINER', 'ITEM_NAME', 'ICON_NAME', 'Size', 'Created', 'Description');
  return retval;
}
;

create procedure db.dba.dav_browse_proc( in path varchar, in filter varchar := '' ) returns any
{
  declare i, len integer;
  declare dirlist, retval any;

  path := replace(path, '"', '');
  if( length(path)=0 ) {
    retval := vector( vector( 1, 'DAV', NULL, '0', '', 'Root' ) );
    return retval;
  }
  if( path[length(path)-1] <> ascii('/') )
    path := concat (path, '/');
  if( path[0] <> ascii('/') )
    path := concat ('/', path);

  if( isnull(filter) or filter = '' )
    filter := '%';
  replace(filter, '*', '%');

  --dbg_obj_print('path after=', path);

  retval := vector();

  dirlist := DAV_DIR_LIST( path, 0, 'dav', 'dav');
  --dbg_obj_print('dirlist', dirlist);

  if(not isarray(dirlist))
    return retval;

  len:=length(dirlist);

  i:=0;
  while( i < len ) {
    if( dirlist[i][1] = 'c' /* and dirlist[i][10] like filter */ ) -- let's not filter out catalogs!
      retval := vector_concat(retval, vector(vector( 1, dirlist[i][10], NULL, sprintf('%d', dirlist[i][2]), left(cast(dirlist[i][3] as varchar), 19), 'Collection' )));
    i := i+1;
  }
  i:=0;
  while( i < len ) {
    if( dirlist[i][1] <> 'c' and dirlist[i][10] like filter )
    retval := vector_concat(retval, vector(vector( 0, dirlist[i][10], NULL, sprintf('%d', dirlist[i][2]), left(cast(dirlist[i][3] as varchar), 19), 'Document' )));
    i := i+1;
  }
  --dbg_obj_print('retval', retval);
  return retval;
}
;

create procedure db.dba.dav_crfolder_proc( in path varchar, in folder varchar ) returns integer
{
  DECLARE ret INTEGER;
  path := replace(path, '"', '');
  if( length(path) = 0 )
    path := '.';
  if( path[length(path)-1] <> ascii('/') )
    path := concat (path, '/');
  if( folder[length(folder)-1] <> ascii('/') )
    folder := concat (folder, '/');

  ret := DB.DBA.DAV_COL_CREATE( path || folder, '110100000R', 'dav', 'dav', 'dav', 'dav');

  return CASE WHEN ret<>0 THEN 0 ELSE 1 END;
}
;


create procedure db.dba.fs_browse_proc_meta() returns any
{
  declare retval any;
  retval := vector('ITEM_IS_CONTAINER','ITEM_NAME','ICON_NAME', 'Size', 'Created', 'Description');
  return retval;
}
;

create procedure db.dba.fs_browse_proc( in path varchar, in filter varchar := '' ) returns any
{
  declare i, len integer;
  declare dirlist, retval any;

  path := replace(path, '"', '');
  if( length(path) = 0 )
    path := '.';
  if( path[length(path)-1] <> ascii('/') )
    path := concat (path, '/');

  if( isnull(filter) or filter = '' )
    filter := '%';
  replace(filter, '*', '%');

  --dbg_obj_print('path after=', path);

  retval := vector();

  dirlist := sys_dirlist( path, 0);
  --dbg_obj_print('dirlist', dirlist);

  if(not isarray(dirlist))
    return retval;

  len:=length(dirlist);

  i:=0;
  while( i < len ) {
    if( dirlist[i] <> '.' AND dirlist[i] <> '..' )
      retval := vector_concat(retval, vector(vector( 1, dirlist[i], NULL, '0', file_stat(path||dirlist[i],0), 'Folder' )));
    -- dbg_obj_print('file_stat(dirlist[i],3)',file_stat(path||dirlist[i],3));
    i := i+1;
  }
  dirlist := sys_dirlist( path, 1);
  --dbg_obj_print('dirlist', dirlist);

  if(not isarray(dirlist))
    return retval;

  len:=length(dirlist);

  i:=0;
  while( i < len ) {
    if( dirlist[i] like filter )  -- we filter out files only
      retval := vector_concat(retval, vector(vector( 0, dirlist[i], NULL, file_stat(path||dirlist[i],1), file_stat(path||dirlist[i],0), 'File' )));
    -- dbg_obj_print('file_stat(dirlist[i],1)',file_stat(path||dirlist[i],1));
    -- dbg_obj_print('file_stat(dirlist[i],0)',file_stat(path||dirlist[i],0));
    i := i+1;
  }
  --dbg_obj_print('retval', retval);
  return retval;
}
;

create procedure db.dba.fs_crfolder_proc( in path varchar, in folder varchar ) returns integer
{
  path := replace(path, '"', '');
  if( length(path) = 0 )
    path := '.';
  if( path[length(path)-1] <> ascii('/') )
    path := concat (path, '/');

  return sys_mkdir( path || folder );
}
;

create procedure db.dba.vproc_browse_proc_meta() returns any
{
  declare retval any;
  retval := vector('ITEM_IS_CONTAINER','ITEM_NAME','ICON_NAME','Description');
  return retval;
}
;

create procedure db.dba.vproc_browse_proc( in path varchar, in filter varchar := '' ) returns any
{
  declare level, is_node integer;
  declare cat, sch, tbl, descr varchar;
  declare retval any;

  retval := vector();
  --retval := vector_concat(retval, vector(vector('ITEM_IS_CONTAINER','ITEM_NAME','ICON_NAME','Description')));

  if( isnull(filter) or filter = '' )
    filter := '%.%.%';
  replace(filter, '*', '%');

  path := trim(path,'.');
  --dbg_obj_print('path',path);
  cat := left( path, coalesce(strchr(path,'.'),length(path)) );
  path := ltrim(subseq( path, length(cat)), '.');
  cat := trim(cat,'"');
  --dbg_obj_print('path',path);

  sch := left( path, coalesce(strchr(path,'.'), length(path)) );
  path := ltrim(subseq( path, length(sch) ), '.');
  sch := trim(sch,'"');
  --dbg_obj_print('path',path);
  tbl := trim(left( path, coalesce(strchr(path,'.'), length(path)) ),'"');
  --if(tbl<>'') level := 3;
  if(sch<>'') level := 2;
  else if(cat<>'') level := 1;
  else level := 0;
  cat := case when cat <> '' then cat else '%' end;
  sch := case when sch <> '' then sch else '%' end;
--  dbg_obj_print('cat',cat,'sch',sch,'tbl',tbl,'level',level,'filter',filter);

  is_node := case when level < 2 then 1 else 0 end;
  descr := case level when 0 then 'Catalog' when 1 then 'Schema' else 'Procedure' end;

  if (cat = 'DB' AND sch = 'DBA') {
       retval := vector_concat(retval, vector(vector(is_node, 'HP_AUTH_SQL_USER', NULL, 'Built-in')));
       retval := vector_concat(retval, vector(vector(is_node, 'HP_AUTH_DAV_ADMIN', NULL, 'Built-in')));
       retval := vector_concat(retval, vector(vector(is_node, 'HP_AUTH_DAV_PROTOCOL', NULL, 'Built-in')));
  }
  if (cat = 'WS' AND sch = 'WS') {
       retval := vector_concat(retval, vector(vector(is_node, 'DIGEST_AUTH', NULL, 'Built-in')));
  }

  for( select DISTINCT name_part (P_NAME, level) AS ITEM from SYS_PROCEDURES
       where name_part(P_NAME, 0) LIKE cat
       and name_part (P_NAME, 1) like sch
       AND P_NAME not like '%.%./%'
       AND P_NAME like filter
       order by P_NAME
     ) do {
   --dbg_obj_print('item',ITEM);
     retval := vector_concat(retval, vector(vector(is_node, ITEM, NULL,descr)));
  }
  return retval;
}
;

create procedure db.dba.vview_browse_proc_meta() returns any
{
  declare retval any;
  retval := vector('ITEM_IS_CONTAINER','ITEM_NAME','ICON_NAME','Description');
  return retval;
}
;

create procedure db.dba.vview_browse_proc( in path varchar, in filter varchar := '' ) returns any
{
  declare level, is_node integer;
  declare cat, sch, tbl, descr varchar;
  declare retval any;

  retval := vector();
  --retval := vector_concat(retval, vector(vector('ITEM_IS_CONTAINER','ITEM_NAME','ICON_NAME','Description')));

  if( isnull(filter) or filter = '' )
    filter := '%.%.%';
  replace(filter, '*', '%');

  path := trim(path,'.');
  --dbg_obj_print('path',path);
  cat := left( path, coalesce(strchr(path,'.'),length(path)) );
  path := ltrim(subseq( path, length(cat)), '.');
  cat := trim(cat,'"');
  --dbg_obj_print('path',path);

  sch := left( path, coalesce(strchr(path,'.'), length(path)) );
  path := ltrim(subseq( path, length(sch) ), '.');
  sch := trim(sch,'"');
  --dbg_obj_print('path',path);
  tbl := trim(left( path, coalesce(strchr(path,'.'), length(path)) ),'"');
  --if(tbl<>'') level := 3;
  if(sch<>'') level := 2;
  else if(cat<>'') level := 1;
  else level := 0;
  cat := case when cat <> '' then cat else '%' end;
  sch := case when sch <> '' then sch else '%' end;
  -- dbg_obj_print('cat',cat,'sch',sch,'tbl',tbl,'level',level);

  is_node := case when level < 2 then 1 else 0 end;
  descr := case level when 0 then 'Catalog' when 1 then 'Schema' else 'View' end;

  for( select distinct name_part (KEY_TABLE, level) as ITEM from DB.DBA.SYS_KEYS
       where name_part (KEY_TABLE, 0) like cat
         and name_part (KEY_TABLE, 1) like sch
         and table_type (KEY_TABLE) = 'VIEW'
         and KEY_IS_MAIN = 1 and KEY_MIGRATE_TO is NULL
         AND KEY_TABLE like filter
     ) do {
   --dbg_obj_print('item',ITEM);
     retval := vector_concat(retval, vector(vector(is_node, ITEM, NULL,descr)));
  }
  return retval;
}
;
