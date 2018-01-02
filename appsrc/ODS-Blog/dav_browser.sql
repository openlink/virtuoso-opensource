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

use "DB"
;

create procedure
sql_user_password (in name varchar)
{
  declare pass varchar;
  pass := NULL;
  whenever not found goto none;
  select pwd_magic_calc (U_NAME, U_PASSWORD, 1) into pass
      from DB.DBA.SYS_USERS where U_NAME = name;
none:
  return pass;
}
;

create procedure
sql_user_password_check (in name varchar, in pass varchar)
{
  if (exists (select 1 from DB.DBA.SYS_USERS where U_NAME = name and pwd_magic_calc (U_NAME, U_PASSWORD, 1) = pass))
    return 1;
  return 0;
}
;

create procedure
db.dba.dav_browse_proc1 (in path varchar,
                         in show_details integer := 0,
                         in dir_select integer := 0,
                         in filter varchar := '',
                         in search_type integer := -1,
                         in search_word varchar := '',
       			 in ord any := '',
       			 in ordseq varchar := 'asc'
       ) returns any
{
  declare i, j, len, len1 integer;
  declare dirlist, retval any;
  declare cur_user, cur_group, user_name, group_name, perms, perms_tmp, cur_file varchar;
  declare stat, msg, mdt, dta any;

  cur_user := connection_get ('vspx_user');
  path := replace (path, '"', '');
  if (length (path) = 0 and search_type = -1)
    {
      if (show_details = 0)
        retval := vector (vector (1, 'DAV', NULL, '0', '', 'Root', '', '', ''));
      else
        retval := vector (vector (1, 'DAV'));
      return retval;
    }
  else
    if (length(path) = 0 and search_type <> -1)
      path := 'DAV';

  if (path[length (path) - 1] <> ascii ('/'))
    path := concat (path, '/');

  if (path[0] <> ascii ('/'))
    path := concat ('/', path);

  if (isnull (filter) or filter = '')
    filter := '%';

  replace (filter, '*', '%');
  retval := vector ();
  if (search_type = 0 or search_type = -1)
    {
      if (ord = 'name')
        ord := 11;
      else if (ord = 'size')
        ord := 3;
      else if (ord = 'type')
  ord := 10;
      else if (ord = 'modified')
  ord := 4;
      else if (ord = 'owner')
  ord := 8;
      else if (ord = 'group')
  ord := 7;

      if (isinteger (ord))
  ord := sprintf (' order by %d %s', ord, ordseq);

      if (search_type = 0)
  {
    --dbg_obj_print ('case 1');
    exec (concat ('select * from Y_DAV_DIR where path = ? and recursive = ? and auth_uid = ? ', ord),
       stat, msg, vector (path, 1, cur_user), 0, mdt, dirlist);
    -- old behaviour
          --dirlist := YACUTIA_DAV_DIR_LIST (path, 1, cur_user);
  }
      else
  {
    --dbg_obj_print ('case 2');
    exec (concat ('select * from Y_DAV_DIR where path = ? and recursive = ? and auth_uid = ? ', ord),
       stat, msg, vector (path, 0, cur_user), 0, mdt, dirlist);
    --dbg_obj_print (dirlist);
    -- old behaviour
          -- dirlist := YACUTIA_DAV_DIR_LIST (path, 0, cur_user);
  }

      if (not isarray (dirlist))
        return retval;

      len := length (dirlist);
      i := 0;

      while (i < len)
        {
          if (lower (dirlist[i][1]) = 'c') --  and dirlist[i][10] like filter) -- lets not filter out collections!
            {
              cur_file := trim (dirlist[i][0], '/');
              cur_file := subseq (cur_file, strrchr (cur_file, '/') + 1);

              if (search_type = -1 or
                  (search_type = 0 and cur_file like search_word))
                {
                  if (show_details = 0)
                    {
                      if (dirlist[i][7] is not null)
                        user_name := dirlist[i][7];
                      else
                        user_name := 'none';

                      if (dirlist[i][6] is not null)
                        group_name := dirlist[i][6];
                      else
                        group_name := 'none';

                perms_tmp := dirlist[i][5];
                      if (length (perms_tmp) = 9)
                        perms_tmp := perms_tmp || 'N';
                      perms := DAV_PERM_D2U (perms_tmp);

                      if (search_type = 0)
                        retval :=
                          vector_concat(retval,
                                        vector (vector (1,
                                                        dirlist[i][0],
                                                        NULL,
                                                        'N/A',
                                                        yac_hum_datefmt (dirlist[i][3]),
                                                        'folder',
                                                        user_name,
                                                        group_name,
                                                        perms)));
                      else
                        retval :=
                          vector_concat(retval,
                                        vector (vector (1,
                                                        dirlist[i][10],
                                                        NULL,
                                                        'N/A',
                                                        yac_hum_datefmt (dirlist[i][3]),
                                                        'folder',
                                                        user_name,
                                                        group_name,
                                                        perms)));
                    }
                  else
                    {
                      if (search_type = 0)
                        retval := vector_concat(retval,
                                                vector (vector (1, dirlist[i][0])));
                      else
                        retval := vector_concat(retval,
                                                vector (vector (1, dirlist[i][10])));
                    }
                  }
                }
              i := i + 1;
            }
          if (dir_select = 0 or dir_select = 2)
            {
              i := 0;
              while (i < len)
                {
                  if (lower (dirlist[i][1]) <> 'c' and dirlist[i][10] like filter)
                    {
                      cur_file := trim (aref (aref (dirlist, i), 0), '/');
                      cur_file := subseq (cur_file, strrchr (cur_file, '/') + 1);

                      if (search_type = -1 or
                          (search_type = 0 and cur_file like search_word))
                        {
                          if (show_details = 0)
                            {
                              if (dirlist[i][7] is not null)
        user_name := dirlist[i][7];
                              else
                                user_name := 'none';

                              if (dirlist[i][6] is not null)
        group_name := dirlist[i][6];
                              else
                                group_name := 'none';

                        perms_tmp := dirlist[i][5];
                              if (length (perms_tmp) = 9)
                          perms_tmp := perms_tmp || 'N';
            perms := DAV_PERM_D2U (perms_tmp);

                              if (search_type = 0)
                                retval :=
                                  vector_concat(retval,
                                                vector (vector (0,
                                                                dirlist[i][0],
                                                                NULL,
                                                                yac_hum_fsize (dirlist[i][2]),
                                                                yac_hum_datefmt (dirlist[i][3]),
                                                                dirlist[i][9],
                                                                user_name,
                                                                group_name,
                                                                perms )));
                              else
                                retval :=
                                  vector_concat(retval,
                                                vector( vector (0,
                                                                dirlist[i][10],
                                                                NULL,
                                                                yac_hum_fsize (dirlist[i][2]),
                                                                yac_hum_datefmt (dirlist[i][3]),
                                                                dirlist[i][9],
                                                                user_name,
                                                                group_name,
                                                                perms )));
                            }
                          else
                            {
                              if (search_type = 0)
                                retval := vector_concat (retval,
                                                         vector(vector(0, dirlist[i][0])));
                              else
                                retval := vector_concat (retval,
                                                         vector(vector(0, dirlist[i][10])));
                            }
                        }
                    }
                    i := i + 1;
                  }
         }
            }
          else
            if (search_type = 1)
              {
                retval := vector();
                declare _u_name, _g_name varchar;
                declare _maxres integer;
                declare _qtype varchar;
                declare _out varchar;
                declare _style_sheet varchar;
                declare inx integer;
                declare _qfrom varchar;
                declare _root_elem varchar;
                declare _u_id, _cutat integer;
                declare _entity any;
                declare _res_name_sav varchar;
                declare _out_style_sheet, _no_matches, _trf, _disp_result varchar;
                declare _save_as, _own varchar;

    -- These parameters are needed for WebDAV browser

                declare _current_uri, _trf_doc, _q_scope, _sty_to_ent,
                _sid_id, _sys, _mod varchar;
                declare _dav_result any;
                declare _e_content any;
                declare err varchar;
                declare _no_match, _last_match, _prev_match, _cntr integer;

                err := ''; stat := '00000';
                _dav_result := null;

                declare exit handler for sqlstate '*'
                  {
                    stat := __SQL_STATE; err := __SQL_MESSAGE;
                  };

        if (ord = 'name')
    ord := 2;
        else if (ord = 'size')
    ord := 10;
        else if (ord = 'type')
    ord := 6;
        else if (ord = 'modified')
    ord := 7;
        else if (ord = 'owner')
    ord := 4;
        else if (ord = 'group')
    ord := 5;

        if (isinteger (ord))
    ord := sprintf (' order by %d %s', ord, ordseq);

                if (not is_empty_or_null (search_word))
                  {
        stat := '00000';
                    exec (concat ('select RES_ID, RES_NAME, RES_CONTENT, RES_OWNER, RES_GROUP, RES_TYPE, RES_MOD_TIME, RES_PERMS,
                                RES_FULL_PATH, length (RES_CONTENT)
                           from WS.WS.SYS_DAV_RES
                           where contains (RES_CONTENT, ?)', ord), stat, msg, vector (search_word), 0, mdt, dta);


        if (stat = '00000')
          {
      declare RES_ID, RES_NAME, RES_CONTENT, RES_OWNER, RES_GROUP, RES_TYPE,
        RES_MOD_TIME, RES_PERMS, RES_FULL_PATH any;

      foreach (any elm in dta) do
        {
          RES_ID := elm[0];
          RES_NAME := elm[1];
                RES_CONTENT := elm[2];
              RES_OWNER := elm[3];
                      RES_GROUP  := elm[4];
                      RES_TYPE  := elm[5];
                      RES_MOD_TIME  := elm[6];
                      RES_PERMS  := elm[7];
                      RES_FULL_PATH := elm[8];

          if (exists (select 1 from WS.WS.SYS_DAV_PROP
            where PROP_NAME = 'xper' and
            PROP_TYPE = 'R' and
            PROP_PARENT_ID = RES_ID))
            {
        _e_content := string_output ();
        http_value (xml_persistent (RES_CONTENT), null, _e_content);
        _e_content := string_output_string (_e_content);
            }
          else
            _e_content := RES_CONTENT;

          if (RES_GROUP is not null and RES_GROUP > 0)
            {
        _g_name := (select G_NAME from WS.WS.SYS_DAV_GROUP where G_ID = RES_GROUP);
            }
          else
            {
        _g_name := 'no group';
            }

          if (RES_OWNER is not null and RES_OWNER > 0)
            {
        _u_name := (select U_NAME from WS.WS.SYS_DAV_USER where U_ID = RES_OWNER);
            }
          else
            {
        _u_name := 'Public';
            }

          if (show_details = 0)
            {
        retval :=
          vector_concat (retval,
             vector (vector (0,
                 RES_FULL_PATH,
                 NULL,
                 yac_hum_fsize (length (RES_CONTENT)),
                 yac_hum_datefmt (RES_MOD_TIME),
                 RES_TYPE,
                 _u_name,
                 _g_name,
                 adm_dav_format_perms (RES_PERMS))));
            }
          else
            {
        retval := vector_concat(retval,
              vector (vector (0,
                  RES_FULL_PATH)));
            }
                inx := inx + 1;
                   }
          }
       }
    }
  return retval;
}
;

create procedure
dav_browse_proc_meta1(in show_details integer := 0) returns any
{
  declare retval any;
  if (show_details = 0)
    retval := vector('ITEM_IS_CONTAINER',
                     'ITEM_NAME',
                     'ICON_NAME',
                     'Size',
                     'Modified',
                     'Type',
                     'Owner',
                     'Group',
                     'Permissions');
  else
    retval := vector('ITEM_IS_CONTAINER', 'ITEM_NAME');
  return retval;
}
;

create procedure
YACUTIA_DAV_COPY (in path varchar,
                  in destination varchar,
                  in overwrite integer := 0,
                  in permissions varchar := '110100000R',
                  in uid any := NULL,
                  in gid any := NULL)
{
  declare rc integer;
  declare pwd1, cur_user any;
  cur_user := connection_get ('vspx_user');

  if (cur_user = 'dba')
    cur_user := 'dav';

  pwd1 := (select pwd_magic_calc (U_NAME, U_PASSWORD, 1) from DB.DBA.SYS_USERS where U_NAME = cur_user);

  rc := DB.DBA.DAV_COPY (path, destination, overwrite, permissions, uid, gid, cur_user, pwd1);
  return rc;
}
;

create procedure
YACUTIA_DAV_MOVE (in path varchar,
                  in destination varchar,
                  in overwrite varchar)
{
  declare rc integer;
  declare pwd1, cur_user any;
  cur_user := connection_get ('vspx_user');

  if (cur_user = 'dba')
    cur_user := 'dav';

  pwd1 := (select pwd_magic_calc (U_NAME, U_PASSWORD, 1) from DB.DBA.SYS_USERS where U_NAME = cur_user);

  rc := DB.DBA.DAV_MOVE (path, destination, overwrite, cur_user, pwd1);
  return rc;
}
;

create procedure
YACUTIA_DAV_STATUS (in status integer) returns varchar
{
  if (status = -1)
    return 'Invalid target path';

  if (status = -2)
    return 'Invalid destination path';

  if (status = -3)
    return 'Destination already exists and overwrite flag not set';

  if (status = -4)
    return 'Invalid target type (resource) in copy/move';

  if (status = -5)
    return 'Invalid permissions';

  if (status = -6)
    return 'Invalid uid';

  if (status = -7)
    return 'Invalid gid';

  if (status = -8)
    return 'Target is locked';

  if (status = -9)
    return 'Destination is locked';

  if (status = -10)
    return 'Property name is reserved (protected or private)';

  if (status = -11)
    return 'Property does not exists';

  if (status = -12)
    return 'Authentication failed';

  if (status = -13)
    return 'Insufficient privileges for operation';

  if (status = -14)
    return 'Invalid target type';

  if (status = -15)
    return 'Invalid umask';

  if (status = -16)
    return 'Property already exists';

  if (status = -17)
    return 'Invalid property value';

  if (status = -18)
    return 'No such user';

  if (status = -19)
    return 'No home directory';

  return sprintf ('Unknown error %d', status);
}
;

create procedure
YACUTIA_DAV_DELETE (in path varchar,
                    in silent integer := 0,
                    in extern integer := 1)
{
  declare rc integer;
  declare pwd1, cur_user any;
  cur_user := connection_get ('vspx_user');

  if (cur_user = 'dba')
    cur_user := 'dav';

  pwd1 := (select pwd_magic_calc (U_NAME, U_PASSWORD, 1) from DB.DBA.SYS_USERS where U_NAME = cur_user);

  rc := DB.DBA.DAV_DELETE_INT (path, silent, cur_user, pwd1, extern);
  return rc;
}
;

create procedure
YACUTIA_DAV_RES_UPLOAD (in path varchar,
                        inout content any,
                        in type varchar := '',
                        in permissions varchar := '110100000R',
                        in uid varchar := 'dav',
                        in gid varchar := 'dav',
                        in cr_time datetime := null,
                        in mod_time datetime := null,
                        in _rowguid varchar := null)
{
  declare rc integer;
  declare pwd1, cur_user any;
  cur_user := connection_get ('vspx_user');

  if (cur_user = 'dba')
    cur_user := 'dav';

  pwd1 := (select pwd_magic_calc (U_NAME, U_PASSWORD, 1) from DB.DBA.SYS_USERS where U_NAME = cur_user);

  rc := DB.DBA.DAV_RES_UPLOAD_STRSES (path, content, type, permissions, uid, gid, cur_user, pwd1);
  return rc;
}
;

create procedure
YACUTIA_DAV_COL_CREATE (in path varchar,
                        in permissions varchar,
                        in uid varchar,
                        in gid varchar)
{
  declare rc integer;
  declare pwd1, cur_user any;

  cur_user := connection_get ('vspx_user');

  if (cur_user = 'dba')
    cur_user := 'dav';

  pwd1 := (select pwd_magic_calc (U_NAME, U_PASSWORD, 1) from DB.DBA.SYS_USERS where U_NAME = cur_user);

  rc := DB.DBA.DAV_COL_CREATE (path, permissions, uid, gid, cur_user, pwd1);
  return rc;
}
;

create procedure
YACUTIA_DAV_DIR_LIST (in path varchar := '/DAV/',
                      in recursive integer := 0,
                      in auth_uid varchar := 'dav')
{
  declare res, pwd1 any;

  if (auth_uid = 'dba')
    auth_uid := 'dav';

  pwd1 := (select pwd_magic_calc (U_NAME, U_PASSWORD, 1) from DB.DBA.SYS_USERS where U_NAME = auth_uid);
  res := DB.DBA.DAV_DIR_LIST (path, recursive, auth_uid, pwd1);
  return res;
}
;

create procedure
db.dba.yac_hum_fsize (in sz integer) returns varchar
{
  if (sz = 0)
    return ('Zero');
  if (sz < 1024)
    return (sprintf ('%dB', cast (sz as integer)));
  if (sz < 102400)
    return (sprintf ('%.1fkB', sz/1024));
  if (sz < 1048576)
    return (sprintf ('%dkB', cast (sz/1024 as integer)));
  if (sz < 104857600)
    return (sprintf ('%.1fMB', sz/1048576));
  if (sz < 1073741824)
    return (sprintf ('%dMB', cast (sz/1048576 as integer)));
  return (sprintf ('%.1fGB', sz/1073741824));
}
;

create procedure
yac_hum_datefmt (in d datetime)
{

  declare date_part varchar;
  declare time_part varchar;
  declare min_diff integer;
  declare day_diff integer;

  if (isnull (d))
    {
      return ('Never');
    }

  day_diff := datediff ('day', d, now ());
  if (day_diff < 1)
    {
      min_diff := datediff ('minute', d, now ());
      if (min_diff = 1)
        {
          return ('A minute ago');
        }
      else if (min_diff < 1)
        {
          return ('Less than a minute ago');
        }
      else if (min_diff < 60)
        {
          return (sprintf ('%d minutes ago', min_diff));
        }
      else return (sprintf ('Today at %02d:%02d', hour (d), minute (d)));
    }
  if (day_diff < 2)
    {
      return (sprintf ('Yesterday at %02d:%02d', hour (d), minute (d)));
    }
  return (sprintf ('%02d/%02d/%02d %02d:%02d',
                   year (d),
                   month (d),
                   dayofmonth (d),
                   hour (d),
                   minute (d)));
}
;

create procedure
YACUTIA_DAV_DIR_LIST_P (in path varchar := '/DAV/', in recursive integer := 0, in auth_uid varchar := 'dav')
{
  declare arr, pwd1 any;
  declare i, l integer;
  declare FULL_PATH, PERMS, MIME_TYPE, NAME varchar;
  declare TYPE char(1);
  declare RLENGTH, ID, GRP, OWNER integer;
  declare MOD_TIME, CR_TIME datetime;
  result_names (FULL_PATH, TYPE, RLENGTH, MOD_TIME, ID, PERMS, GRP, OWNER, CR_TIME, MIME_TYPE, NAME);
  if (auth_uid = 'dba')
    auth_uid := 'dav';
  pwd1 := (select pwd_magic_calc (U_NAME, U_PASSWORD, 1) from DB.DBA.SYS_USERS where U_NAME = auth_uid);
  arr := DB.DBA.DAV_DIR_LIST (path, recursive, auth_uid, pwd1);
  i := 0; l := length (arr);
  while (i < l)
    {
      declare own, _grp any;
      own := 'none';
      _grp := 'none';
      if (arr[i][7] is not null)
        own := coalesce ((select U_NAME from DB.DBA.SYS_USERS where U_ID = arr[i][7]), 'none');
      if (arr[i][6] is not null)
        _grp := coalesce ((select U_NAME from DB.DBA.SYS_USERS where U_ID = arr[i][6]), 'none');
      result (arr[i][0],
    arr[i][1],
    arr[i][2],
    arr[i][3],
    case when isinteger (arr[i][4]) then arr[i][4] else -1 end,
    arr[i][5],
    _grp,
    own,
    arr[i][8],
    arr[i][9],
    arr[i][10]);
      i := i + 1;
    }
}
;

BLOG.DBA.blog2_exec_no_error('create procedure view Y_DAV_DIR as YACUTIA_DAV_DIR_LIST_P (path,recursive,auth_uid) (FULL_PATH varchar, TYPE varchar, RLENGTH integer, MOD_TIME datetime, ID integer, PERMS varchar, GRP varchar, OWNER varchar, CR_TIME datetime, MIME_TYPE varchar, NAME varchar)')
;



