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
-- get id of currently logged-on user

create procedure
adm_dav_br_get_uid (in lines any)
{
  return 0;
}
;

-- return null if the user has no read privileges on the collection

create procedure
adm_dav_user_can_read_col_p (in uid integer, in col_id integer)
{
  --dbg_printf ('WARNING: adm_dav_user_can_read_col_p is a stub procedure');

  return col_id;
}
;

-- return null if the user has no read privileges on the resource

create procedure
adm_dav_user_can_read_res_p (in uid integer, in res_id integer)
{
  --dbg_printf ('WARNING: adm_dav_user_can_read_res_p is a stub procedure');

  return res_id;
}
;

create procedure
adm_dav_br_uid_to_user (in uid integer)
{

  declare _u_name varchar;

  if (uid is null)
    return ('DB NULL');

  if (not exists (select 1 from "WS"."WS"."SYS_DAV_USER" where U_ID = uid))
    {
      dbg_printf ('A collection/resource with non-existing owner, strange!\n');
      return (sprintf ('%d', uid));
    }

  select coalesce (U_NAME, '')
    into _u_name
    from WS.WS.SYS_DAV_USER
    where U_ID = uid;

  if (isnull (_u_name))
    {
      return (sprintf ('%d', uid));
    }

  return _u_name;
}
;

create procedure
adm_dav_br_uid_to_group (in uid integer)
{

  declare _u_name varchar;

  if (uid is null)
    return ('none');

  if (not exists (select 1 from "WS"."WS"."SYS_DAV_GROUP" where G_ID = uid))
    {
      --dbg_printf ('A collection/resource with non-existing owner, strange!\n');
      return (sprintf ('%d', uid));
    }

  select coalesce (G_NAME, '')
    into _u_name
    from WS.WS.SYS_DAV_GROUP
    where G_ID = uid;

  if (isnull (_u_name))
    {
      return (sprintf ('%d', uid));
    }

  return _u_name;
}
;

create procedure
adm_dav_br_fmt_perm (in obj_perm varchar)
{
  --dbg_printf ('WARNING: adm_dav_br_fmt_priv is a stub procedure');

  return (obj_perm);
}
;

create procedure
adm_dav_br_list_error (in message varchar,
           in cur_col integer,
           in new_col integer,
           in uid integer)
{
  http ('');
  http ('Error: te');
}
;

-- Map mime type to file icon href

create procedure
adm_dav_br_map_icon (in type varchar)
{
  if ('folder' = type)
    return ('images/16x16/folder.gif');
  if ('application/pdf' = type)
    return ('images/16x16/pdf.gif');
  if ('application/ms-word' = type or 'application/msword' = type)
    return ('images/16x16/msword.gif');
  if ('application/zip' = type)
    return ('images/16x16/zip.gif');
  if ('text/html' = type)
    return ('images/16x16/html.gif');
  if ('text' = "LEFT" (type, 4))
    return ('images/16x16/text.gif');
  if ('image' = "LEFT" (type, 5))
    return ('images/16x16/image.gif');
  if ('audio' = "LEFT" (type, 5))
    return ('images/16x16/wave.gif');
  if ('video' = "LEFT" (type, 5))
    return ('images/16x16/video.gif');

  return ('images/16x16/generic_file.gif');
}
;

--
-- format a collection row in the list
--

create procedure
adm_dav_br_fmt_col (in obj_name varchar,
        in col_id any,
        in obj_size any,
        in owner_uid integer,
        in owner_gid integer,
        in mod_time datetime,
        in obj_perm varchar,
        in lst_mode any,
        in browse_mode any,
        in os varchar := 'dav')
{
  declare img_tag varchar;
  declare exec_anchor, sel_anchor varchar;
  declare quot varchar;

  --dbg_printf ('adm_dav_br_fmt_col\n');

--  dbg_printf ('obj_name (%d)\ncol_id (%d) \nobj_size (%d) \nowner_uid (%d) \nmod_time (%d) \nobj_perm (%d) \nlst_mode (%d) \nbrowse_mode (%d)\n', __TAG(obj_name), __TAG(col_id), __TAG(obj_size), __TAG(owner_uid), __TAG(owner_gid), __TAG(mod_time), __TAG(obj_perm), __TAG(lst_mode), __TAG(browse_mode));


  quot := '';

  if (os = 'os')
    quot := '\'';

  img_tag := sprintf ('<img class="davfilelisticon" src="%s" />',
           adm_dav_br_map_icon ('folder'));

  exec_anchor := sprintf ('<a class="imglink" href="javascript:%s_cd (%s%s%s)">', os,
       quot, cast (col_id as varchar), quot);
  if (browse_mode = 'COL' and obj_name <> '..' and obj_name <> '.')
    {
      declare curdir, pat varchar;
      if (os = 'os')
  {
          curdir := http_root ();
          pat := cast (col_id as varchar);
  }
      else
  {
    curdir := '';
          pat := WS.WS.COL_PATH (col_id);
  }

      sel_anchor :=
        sprintf ('<a class="imglink" href="javascript:dav_res_select (''%s'', %s%s%s, ''%s%s'')">',
                  obj_name, quot, cast (col_id as varchar), quot, curdir, pat);
    }
  else
    sel_anchor := exec_anchor;

  if (1 = lst_mode)
    {

      return concat ('<td width="16" class="davfilelisticon">',
         exec_anchor,
         img_tag,
         '</a></td>\n',

         '<td class="davfilelistname">',
         sel_anchor,
         obj_name,
         '</a></td>\n',

         '<td class="davfilelistsize">',
         cast (obj_size as varchar),
                     '</td>\n',

         '<td class="davfilelisttype">',
         'folder',
                     '</td>\n',

         '<td class="davfilelistuid">',
         case os when 'dav' then adm_dav_br_uid_to_user (owner_uid) else '' end,
                     '</td>\n',

         '<td class="davfilelistuid">',
         case os when 'dav' then adm_dav_br_uid_to_group (owner_gid) else '' end,
                     '</td>\n',

         '<td class="davfilelistmodtime">',
         "LEFT" (cast (mod_time as varchar), 19),
                     '</td>\n',

         '<td class="davfilelistpriv">',
         case os when 'dav' then adm_dav_format_perms (obj_perm) else '' end,
         '</td>\n');
    }
}
;


-- format a collection row in the list
--

create procedure
adm_dav_br_fmt_res (in res_type varchar,
        in res_name varchar,
        in res_full_path varchar,
        in res_id integer,
        in res_size integer,
        in res_owner integer,
        in res_group integer,
        in res_mod_time datetime,
        in res_perm varchar,
        in lst_mode any,
        in browse_mode any,
        in os varchar := 'dav')
{
  declare img_tag varchar;
  declare exec_anchor varchar;


  img_tag := sprintf ('<img class="davfilelisticon" src="%s" />',
           adm_dav_br_map_icon (res_type));

  res_full_path := replace (res_full_path, '\\', '/');

  if ('STANDALONE' = browse_mode) -- XXX for files
    {
      exec_anchor :=
        sprintf ('<a class="imglink" href="javascript:dav_res_view (''%s'')">',
            res_full_path);
    }
  else
    {
      exec_anchor :=
        sprintf ('<a class="imglink" href="javascript:dav_res_select (''%s'', %d, ''%s'')">',
                  res_name, res_id, res_full_path);
    }

  --dbg_printf ('adm_dav_br_fmt_res\n');
  --dbg_printf ('obj_name: %d', __TAG (res_name));

  if (1 = lst_mode)
    {

      return concat ('<td width="16" class="davfilelisticon">',
         exec_anchor,
         img_tag,
         '</a></td>\n',

         '<td class="davfilelistname">',
         exec_anchor,
         res_name,
         '</a></td>\n',

         '<td class="davfilelistsize">',
         cast (res_size as varchar),
                     '</td>\n',

         '<td class="davfilelisttype">',
         res_type,
                     '</td>\n',

         '<td class="davfilelistuid">',
         case os when 'dav' then adm_dav_br_uid_to_user (res_owner) else '' end,
                     '</td>\n',

         '<td class="davfilelistuid">',
         case os when 'dav' then adm_dav_br_uid_to_group (res_group) else '' end,
                     '</td>\n',

         '<td class="davfilelistmodtime">',
         "LEFT" (cast (res_mod_time as varchar), 19),
                     '</td>\n',

         '<td class="davfilelistpriv">',
         case os when 'dav' then adm_dav_format_perms (res_perm) else '' end,
         '</td>\n');
    }
}
;

create procedure
adm_path_normalize (in path varchar)
{
  declare res any;
  declare arr any;
  path := replace (path, '\\', '/');
  if (path not like '%/..%')
    return path;
  arr := split_and_decode (path, 0, '\0\0/');
  declare i, l int;
  i := length (arr) - 1;
  res := '';
  while (i >= 0)
    {
      if (arr[i] = '..')
  i := i - 1;
      else if (arr [i] = '.')
  ;
      else if (arr [i] <> '' and arr[i] like '_:' and i = 0)
  res := concat (arr[i], res);
      else if (arr [i] <> '')
  res := concat ('/', arr[i], res);
      i := i - 1;
    }
  return res;
}
;

create procedure
adm_file_like (in name varchar, in pat varchar)
{
  declare patts any;
  if (pat = '') pat := '*';
  patts := split_and_decode (pat, 0, '\0\0,');
  declare i, l int;
  i := 0; l := length (patts);
  while (i < l)
    {
      if (patts[i] <> '' and name like patts[i])
  return 1;
      i := i + 1;
    }
  return 0;
}
;

create procedure
adm_os_br_gen_col_c_listing (in cur_path varchar,
            in uid integer,
            in flt_pat varchar,
            in lst_mode any,
            in browse_mode any,
            in xfer_mode varchar)
{
  declare parent_owner integer;
  declare parent_group integer;
  declare parent_mod_time datetime;
  declare parent_perms varchar;
  declare curdir varchar;
  declare dirarr, filearr any;
  declare i, l, flen int;
  declare fst varchar;
  declare modt datetime;
  declare server_root_path varchar;

  server_root_path := server_root ();

  if ("RIGHT" (server_root_path, 1) = '\\')
    server_root_path := "LEFT" (server_root_path, length (server_root_path) - 1);

  curdir := concat (server_root_path, cur_path);

  --dbg_printf ('\nadm_os_br_gen_col_c_listing:');
  --dbg_printf ('new_col: %s', cur_path);
  --dbg_printf ('flt_pat: %s', flt_pat);

  if (flt_pat = '') flt_pat := '%';

  declare exit handler for sqlstate '42000'
    {
       if (length (__SQL_message) > 5)
   {
     if ("LEFT" (__SQL_message, 5) = 'FA018')
       {
         http ('<H3>In order to use browser please uncomment DirsAllowed in virtuoso.ini file\n</H3>');
       }
   }
    };

  dirarr := sys_dirlist (curdir, 0, null, 1);
  filearr := sys_dirlist (curdir, 1, null, 1);

  http ('<table class="davbrfilelist">\n');
  i := 0; l := length (dirarr);
  while (i < l)
    {
      fst := file_stat (concat (curdir, '/', dirarr[i]));
      if (isstring (fst))
        modt := stringdate (fst);
      else
  modt := now ();
      if (dirarr[i] <> '.')
  {
    http ('  <tr class="davbrfilelistrow">\n');
    http (adm_dav_br_fmt_col (dirarr[i], concat (cur_path, '/', dirarr[i]), 'N/A',
           0, 0, modt,
           '000000000T', lst_mode, browse_mode, 'os'));
  }
      http ('  </tr>');
      i := i + 1;
    }

  i := 0; l := length (filearr);
  while (i < l)
    {
      if (adm_file_like (filearr[i], flt_pat))
  {
    fst := file_stat (concat (curdir, '/', filearr[i]));
    flen := atoi(file_stat (concat (curdir, '/', filearr[i]), 1));
    if (isstring (fst))
      modt := stringdate (fst);
    else
      modt := now ();
    http ('  <tr class="davbrfilelistrow">\n');
    http (adm_dav_br_fmt_res (http_mime_type (filearr[i]), filearr[i], concat (curdir, '/', filearr[i]),
            i, flen, 0, 0, modt,
           '000000000T', lst_mode, browse_mode, 'os'));
    http ('  </tr>');
  }
      i := i + 1;
    }

  http ('</table>\n');
  --dbg_printf ('\nadm_os_br_gen_col_c_listing: finished');
}
;

create procedure
adm_dav_br_gen_col_c_listing (in cur_col integer,
            in new_col integer,
            in cur_path varchar,
            in uid integer,
            in flt_pat varchar,
            in lst_mode varchar,
            in browse_mode varchar,
            in xfer_mode varchar)
{
  declare parent_owner integer;
  declare parent_group integer;
  declare _col_parent integer;
  declare parent_mod_time datetime;
  declare parent_perms varchar;

  --dbg_printf ('\nadm_dav_br_gen_col_c_listing:');
  --dbg_printf ('cur_col: %d', cur_col);
  --dbg_printf ('new_col: %d', new_col);
  --dbg_printf ('flt_pat: %s', flt_pat);

  if ('' = flt_pat) flt_pat := '%';

  if (null = adm_dav_user_can_read_col_p (uid, new_col))
    {
      --dbg_printf ('No privileges');
      adm_dav_br_list_error ('The user has no read access privileges for collection.',
           cur_col,
           new_col,
           uid);
      return 666;
    }

  http ('<table class="davbrfilelist">\n');

-- Process collections first. Insert extra entry for parent collection (cur_col);

  if (new_col <> 0)
  {

      http ('  <tr class="davbrfilelistrow">\n');
      select COL_OWNER, COL_GROUP, COL_MOD_TIME, COL_PERMS, COL_PARENT
  into parent_owner, parent_group, parent_mod_time, parent_perms, _col_parent
  from "WS"."WS"."SYS_DAV_COL"
  where COL_ID = new_col;
      http (adm_dav_br_fmt_col ('..', _col_parent, 'N/A',
             parent_owner, parent_group, parent_mod_time,
             parent_perms, lst_mode, browse_mode));
      http ('  </tr>\n');
  }

  for select COL_ID, COL_NAME, COL_OWNER, COL_GROUP, COL_MOD_TIME, COL_PERMS
         from "WS"."WS"."SYS_DAV_COL"
         where COL_PARENT = new_col and COL_NAME like flt_pat do
    {

      http ('  <tr class="davbrfilelistrow">\n');
      http (adm_dav_br_fmt_col (COL_NAME, COL_ID, 'N/A',
        COL_OWNER, COL_GROUP, COL_MOD_TIME,
        COL_PERMS, lst_mode, browse_mode));
      http ('  </tr>');
    }

-- Then produce list of resources

  for select RES_ID, RES_NAME, RES_CONTENT, RES_OWNER, RES_GROUP,
         RES_COL, RES_TYPE, RES_MOD_TIME, RES_PERMS, RES_FULL_PATH
    from "WS"."WS"."SYS_DAV_RES"
    where RES_COL=new_col and RES_NAME like flt_pat order by RES_NAME do
    {
      http ('  <tr class="davbrfilelistrow">\n');
      http (adm_dav_br_fmt_res (RES_TYPE, RES_NAME, RES_FULL_PATH,
        RES_ID, length (RES_CONTENT),
        RES_OWNER, RES_GROUP, RES_MOD_TIME,
        RES_PERMS, lst_mode, browse_mode));
      http ('  </tr>');

    }
  http ('</table>\n');
  --dbg_printf ('\nadm_dav_br_gen_col_c_listing: finished');
}
;
