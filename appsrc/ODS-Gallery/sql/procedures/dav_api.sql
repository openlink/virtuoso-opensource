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

--------------------------------------------------------------------------------
create procedure PHOTO.WA.load_settings (
  in sid varchar,
  in p_gallery_id integer) returns varchar array
{
  declare _show_map, _show_timeline, _nntp, _nntp_init integer;
  declare _settings any;
  declare auth_uid, auth_pwd varchar;
  declare current_user photo_user;

  auth_uid := PHOTO.WA._session_user (vector ('realm', 'wa', 'sid', sid), current_user);
  declare exit handler for not found
  {
    _show_map := 0;
    _show_timeline := 0;
    _nntp := 0;
    _nntp_init := 0;
    _settings := vector ();
  };
  select coalesce (SHOW_MAP, 0),
         coalesce (SHOW_TIMELINE, 0),
         coalesce (NNTP, 0),
         coalesce (NNTP_INIT, 0),
         coalesce (deserialize(blob_to_string(SETTINGS)), vector())
    into _show_map,
         _show_timeline,
         _nntp,
         _nntp_init,
         _settings
    from PHOTO.WA.SYS_INFO
   where GALLERY_ID = p_gallery_id;

  return vector('show_map', cast (_show_map as varchar),
                'show_timeline', cast (_show_timeline as varchar),
                'nntp', cast (_nntp as varchar),
                'nntp_init', cast (_nntp_init as varchar),
                'albums_per_page', get_keyword ('albums_per_page', _settings, '10')
               );
}
;

--------------------------------------------------------------------------------
create procedure PHOTO.WA.dav_browse(
  in sid varchar,
  in p_gallery_id integer,
  in path varchar) returns SOAP_gallery
{
  declare dirlist any ;
  declare auth_uid,auth_pwd,current_gallery,private_tags varchar;
  declare home_dir,_col_perms,_col_user_name varchar;
  declare current_user photo_user;
  declare params,res_user any;
  declare result SOAP_album array;
  declare album SOAP_album;
  declare visibility,_col_id,_col_owner,is_own integer;

  album := new SOAP_album();
  result := vector();

  auth_uid := PHOTO.WA._session_user (vector ('realm', 'wa', 'sid', sid), current_user);

  current_gallery := path;
  -- TODO - da se proveri roliata na user-a za tozi instance(viewr gleda, writer - pishe)
  _col_id := DB.DBA.DAV_SEARCH_ID(path, 'C');
  if (_col_id < 0)
    signal('E0001','Path is not valid');

  SELECT COL_PERMS,COL_OWNER,U_NAME
    INTO _col_perms,_col_owner,_col_user_name
    FROM  WS.WS.SYS_DAV_COL
          LEFT JOIN WS.WS.SYS_DAV_USER ON U_ID = COL_OWNER
   WHERE COL_ID = _col_id;

  if (_col_owner = current_user.user_id)
  {
    is_own := 1;
  }else{
    is_own := 0;
  }

  dirlist := DB.DBA.DAV_DIR_LIST (current_gallery,
                           0, 
                           current_user.auth_uid, 
                           current_user.auth_pwd);
  if (__tag(dirlist) = 189)
    goto ret;

  declare ctr integer;
  declare pub_date,start_date,end_date, description,geolocation,default_thumbnail,obsolete any;

  ctr := 0;
  while (ctr < length(dirlist))
  {
    if (dirlist[ctr][6] = 0)
    {
      dirlist[ctr][6] := 0;
    }
    if ((dirlist[ctr][7] = current_user.user_id or substring(dirlist[ctr][5],7,1) = '1') and isnull(regexp_match('^\\.',dirlist[ctr][10])))
    {
      if (substring(dirlist[ctr][5],7,1) = '1')
      {
        visibility := 1; -- public
      }else{
        visibility := 0; -- private
      }

      album.fullpath := dirlist[ctr][0];
      album.type := dirlist[ctr][1];
      album.length := dirlist[ctr][2];
      album.modification := dirlist[ctr][3];
      album.id := dirlist[ctr][4];
      album.visibility := visibility;
      album.group_id := dirlist[ctr][6];
      album.owner_id := dirlist[ctr][7];
      album.created := dirlist[ctr][8];
      album.mime_type := dirlist[ctr][9];
      album.name := dirlist[ctr][10];

      res_user :=  PHOTO.WA._get_user_name(album.owner_id);

      album.thumb_id := (select RES_ID from WS.WS.SYS_DAV_RES where RES_COL = dirlist[ctr][4] AND regexp_match('^\\.',RES_NAME) IS NULL );
      default_thumbnail := DB.DBA.DAV_PROP_GET (album.fullpath,'default_thumbnail',res_user[0],res_user[1]);
      if (__tag(default_thumbnail) <> 189)
        album.thumb_id := cast(default_thumbnail  as integer);

      pub_date := DB.DBA.DAV_PROP_GET (album.fullpath, 'pub_date', res_user[0], res_user[1]);
--      if(__tag(pub_date ) <> 189){
--        album.pub_date := cast(pub_date  as datetime);
--      }

      start_date := DB.DBA.DAV_PROP_GET (album.fullpath,'start_date',res_user[0],res_user[1]);
      if(__tag(start_date ) <> 189)
      {
        album.start_date := cast(start_date  as datetime);
      } else if (__tag(pub_date ) <> 189) {
        album.start_date := cast(pub_date  as datetime);
      } else {
        album.start_date := cast(now() as datetime);
      }
        
      end_date := DB.DBA.DAV_PROP_GET (album.fullpath,'end_date',res_user[0],res_user[1]);
      if(__tag(end_date ) <> 189)
      {
        album.end_date := cast(end_date  as datetime);
      } else if (__tag(pub_date ) <> 189) {
        album.end_date :=  cast(pub_date  as datetime);
      } else {
        album.end_date := cast(now() as datetime);
      }

      description := DB.DBA.DAV_PROP_GET (album.fullpath,'description',res_user[0],res_user[1]);
      if (__tag(description) <> 189)
      {
        album.description := cast(description  as varchar);
      }

      geolocation := DB.DBA.DAV_PROP_GET (album.fullpath,'geolocation',res_user[0],res_user[1]);
      if(__tag(geolocation) <> 189)
      {
        album.geolocation := PHOTO.WA.string2vector(geolocation,';');
      }

      if(album.geolocation is null)
         album.geolocation:=(vector('0.0','0.0','false'));
      
      obsolete := coalesce( DB.DBA.DAV_PROP_GET (album.fullpath,'obsolete',res_user[0],res_user[1]),0);
      if (__tag(obsolete) <> 189)
      {
        album.obsolete := atoi(obsolete);
      } else {
        album.obsolete := 0;
      }

      private_tags := DB.DBA.DAV_PROP_GET (album.fullpath,':virtprivatetags',res_user[0],res_user[1]);
      if (__tag(private_tags) <> 189)
      {
        album.private_tags := PHOTO.WA.tags2vector(private_tags);
      }

      if(is_own=1 or album.obsolete=0)
      result := vector_concat(result,vector(album));
    }
    ctr := ctr + 1;
  }
  ret:
  return SOAP_gallery (cast (is_own as integer),
                       _col_user_name,
                       result,
                       vector ()
                      );
}
;


--------------------------------------------------------------------------------

create procedure PHOTO.WA.create_new_album(
  in sid varchar,
  in p_gallery_id integer,
  in home_path varchar,
  in name varchar,
  in visibility integer,
--  in pub_date datetime,
  in start_date datetime,
  in end_date datetime,
  in description varchar,
  in geolocation varchar
  )
  returns SOAP_album
  {
  if ((p_gallery_id is null) or (p_gallery_id = 0))
    return vector();

  declare current_user photo_user;
  declare auth_uid,rights varchar;
  declare result SOAP_album;
  declare col_id           integer;
  declare current_instance photo_instance;

  auth_uid := PHOTO.WA._session_user(vector('realm','wa','sid',sid),current_user);

  declare owner_id integer;
  owner_id := PHOTO.WA.get_gallery_owner_id (p_gallery_id);

  if (PHOTO.WA._session_role (p_gallery_id, current_user.user_id) not in ('admin', 'owner', 'author'))
    return vector();

  if (owner_id <> current_user.user_id)
    current_user := new photo_user (owner_id);

  if(auth_uid = '')
    return vector();

  if (visibility = 1)
  {
    rights := '110100100R';
  }else{
    rights := '110000000R';
  }

  col_id := PHOTO.WA.DAV_COL_CREATE(current_user, concat(home_path,name,'/'),rights);

  if (col_id > 0)
  {
    DB.DBA.DAV_PROP_SET (DB.DBA.DAV_SEARCH_PATH (col_id,'C'),'start_date',cast(start_date as varchar),current_user.auth_uid,current_user.auth_pwd);
    DB.DBA.DAV_PROP_SET (DB.DBA.DAV_SEARCH_PATH (col_id,'C'),'end_date',cast(end_date as varchar),current_user.auth_uid,current_user.auth_pwd);
    DB.DBA.DAV_PROP_SET (DB.DBA.DAV_SEARCH_PATH (col_id,'C'),'description',description,current_user.auth_uid,current_user.auth_pwd);
    DB.DBA.DAV_PROP_SET (DB.DBA.DAV_SEARCH_PATH (col_id,'C'),'geolocation',geolocation,current_user.auth_uid,current_user.auth_pwd);

    result := new SOAP_album(concat(home_path,name,'/'),
                             'C',
                             0,
                             now(),
                             cast(col_id as integer),
                             1,
                             current_user.user_id,
                             current_user.user_id ,
                             now(),
                             'folder',
                             name,
--                             cast(pub_date as datetime),
                             cast(start_date as datetime),
                             cast(end_date as datetime),
                             description,
                             PHOTO.WA.string2vector(geolocation,';'),
                             0
                            );

  }else{
    result := new SOAP_album(cast(col_id as integer),name);

  }

  return result;
}
;

--------------------------------------------------------------------------------
create procedure PHOTO.WA.edit_album_settings(
  in sid varchar,
  in _gallery_id integer,
  in _home_path varchar,
  in _show_map integer,
  in _show_timeline integer,
  in _nntp integer,
  in _nntp_init integer,
  in _settings varchar array) returns varchar
{
  declare current_user photo_user;
  declare auth_uid varchar;

  auth_uid := PHOTO.WA._session_user(vector('realm','wa','sid',sid),current_user);
  if(auth_uid = '')
  {
    return 'false';
  }

  declare exit handler for sqlstate '*'
  {
    goto _err;
  };

  if (exists (select 1 from PHOTO.WA.SYS_INFO where OWNER_ID=current_user.user_id and HOME_PATH = _home_path))
  {
    declare oNNTP, oNNTP_INIT integer;
    select NNTP, NNTP_INIT into oNNTP, oNNTP_INIT from PHOTO.WA.SYS_INFO where OWNER_ID=current_user.user_id and HOME_PATH = _home_path;

    if (PHOTO.WA.discussion_check () = 0)
    {
      _nntp := 0;
      _nntp_init := 0;
    }

    if (_nntp = 0 and _nntp_init = 1)
      _nntp_init := 0;

    update PHOTO.WA.SYS_INFO
       set SHOW_MAP = _show_map,
           SHOW_TIMELINE =_show_timeline,
           NNTP = _nntp,
           NNTP_INIT = _nntp_init,
           SETTINGS = serialize (_settings)
     where HOME_PATH = _home_path;

    PHOTO.WA.nntp_update (_gallery_id, null, null, oNNTP, _nntp);

    if ((_nntp = 1) and (_nntp_init = 1))
    {
      PHOTO.WA.nntp_fill (_gallery_id);
    }
  } else {
    goto _err;
  }
   return 'true';

_err:
   return 'false';
}
;
--------------------------------------------------------------------------------
create procedure PHOTO.WA.edit_album(
  in sid varchar,
  in p_gallery_id integer,
  in home_path varchar,
  in old_name varchar,
  in new_name varchar,
  in visibility integer,
  in start_date datetime,
  in end_date datetime,
  in description varchar,
  in geolocation varchar,
  in obsolete integer) returns SOAP_album
  {
  declare current_user photo_user;
  declare auth_uid,rights varchar;
  declare result SOAP_album;

  auth_uid := PHOTO.WA._session_user(vector('realm','wa','sid',sid),current_user);
  if (auth_uid = '')
    return vector();

  if (visibility = 1)
  {
    rights := '110100100R';
  }else{
    rights := '110000000R';
    visibility := 0;
  }

  declare col_id integer;

  if (old_name <> new_name)
  {
    col_id := PHOTO.WA.DAV_MOVE(current_user, concat(home_path,old_name,'/'),concat(home_path,new_name,'/'));
  }else{
    col_id := DB.DBA.DAV_SEARCH_ID(concat(home_path,old_name,'/'),'C');
  }

  if(col_id > 0){
    declare res any;

    DB.DBA.DAV_PROP_REMOVE (DB.DBA.DAV_SEARCH_PATH (col_id,'C'),'start_date',current_user.auth_uid,current_user.auth_pwd);
    DB.DBA.DAV_PROP_REMOVE (DB.DBA.DAV_SEARCH_PATH (col_id,'C'),'end_date',current_user.auth_uid,current_user.auth_pwd);
    DB.DBA.DAV_PROP_REMOVE (DB.DBA.DAV_SEARCH_PATH (col_id,'C'),'description',current_user.auth_uid,current_user.auth_pwd);
    DB.DBA.DAV_PROP_REMOVE (DB.DBA.DAV_SEARCH_PATH (col_id,'C'),'geolocation',current_user.auth_uid,current_user.auth_pwd);
    DB.DBA.DAV_PROP_REMOVE (DB.DBA.DAV_SEARCH_PATH (col_id,'C'),'obsolete',current_user.auth_uid,current_user.auth_pwd);

    res := DB.DBA.DAV_PROP_SET (DB.DBA.DAV_SEARCH_PATH (col_id,'C'),'start_date',cast(start_date as varchar),current_user.auth_uid,current_user.auth_pwd);
    res := DB.DBA.DAV_PROP_SET (DB.DBA.DAV_SEARCH_PATH (col_id,'C'),'end_date',cast(end_date as varchar),current_user.auth_uid,current_user.auth_pwd);
    res := DB.DBA.DAV_PROP_SET (DB.DBA.DAV_SEARCH_PATH (col_id,'C'),'description',description,current_user.auth_uid,current_user.auth_pwd);
    res := DB.DBA.DAV_PROP_SET (DB.DBA.DAV_SEARCH_PATH (col_id,'C'),'geolocation',geolocation,current_user.auth_uid,current_user.auth_pwd);
    res := DB.DBA.DAV_PROP_SET (DB.DBA.DAV_SEARCH_PATH (col_id,'C'),'obsolete',cast(obsolete as varchar),current_user.auth_uid,current_user.auth_pwd);

    res := DB.DBA.DAV_PROP_SET (DB.DBA.DAV_SEARCH_PATH (col_id,'C'),':virtpermissions',rights,current_user.auth_uid,current_user.auth_pwd);

    result := new SOAP_album(concat(home_path,new_name,'/'),
                             'C',
                             0,
                             now(),
                             cast(col_id as integer),
                             visibility,
                             current_user.user_id,
                             current_user.user_id ,
                             now(),
                             'folder',
                             new_name,
--                             pub_date,
                             start_date,
                             end_date,
                             description,
                             PHOTO.WA.string2vector(geolocation,';'),
                             obsolete
                            );

  }else{
    result := new SOAP_album(cast(col_id as integer),new_name);

  }
  result.thumb_id := (select RES_ID from WS.WS.SYS_DAV_RES where RES_COL = col_id);

  return result;
}
;

--------------------------------------------------------------------------------
create procedure PHOTO.WA.thumbnail_album(
  in sid varchar,
  in p_gallery_id integer,
  in home_path varchar,
  in gallery_name varchar,
  in visibility integer,
  in thumb_id integer) returns integer
  {
  declare current_user photo_user;
  declare auth_uid,rights varchar;

  auth_uid := PHOTO.WA._session_user(vector('realm','wa','sid',sid),current_user);
  if(auth_uid = '')
    return 0;

  if (visibility = 1)
  {
    rights := '110100100R';
  }else{
    rights := '110000000R';
    visibility := 0;
  }

  declare col_id integer;

  col_id := DB.DBA.DAV_SEARCH_ID(concat(home_path,gallery_name,'/'),'C');

  if(col_id > 0)
  {
    declare res any;

    DB.DBA.DAV_PROP_REMOVE (DB.DBA.DAV_SEARCH_PATH (col_id,'C'),'default_thumbnail',current_user.auth_uid,current_user.auth_pwd);
    res := DB.DBA.DAV_PROP_SET (DB.DBA.DAV_SEARCH_PATH (col_id,'C'),'default_thumbnail',cast(thumb_id as varchar),current_user.auth_uid,current_user.auth_pwd);
  }else{
    return 0;
  }
  return 1;
}
;


--------------------------------------------------------------------------------
create procedure PHOTO.WA.dav_upload(
  in params any,
  in current_user photo_user) returns integer
{
  declare gallery_id integer;
  gallery_id := cast (get_keyword('gallery_id', params) as integer);

  if ((gallery_id is null) or (gallery_id = 0))
    return 0;

  declare owner_id integer;
  owner_id := PHOTO.WA.get_gallery_owner_id (gallery_id);

  if (PHOTO.WA._session_role (gallery_id, current_user.user_id) not in ('admin', 'owner', 'author'))
    return 0;

  if (owner_id <> current_user.user_id)
    current_user := new photo_user (owner_id);

  declare i,image_cnt integer;

  i := 1;
  image_cnt := 0;
  while (i <= 20)
  {
    if(get_keyword (concat('my_image_',cast(i as varchar)), params,'') <> '')
    {
      PHOTO.WA.dav_upload_file (params,current_user,i,'file');
      image_cnt:=image_cnt+1;
    }
    if(get_keyword (concat ('f_dav_',cast(i as varchar)), params,'') <> '')
    {
      PHOTO.WA.dav_upload_file (params,current_user,i,'dav');
      image_cnt:=image_cnt+1;
    }
    i:=i+1;
  }

  return image_cnt;
}
;

--------------------------------------------------------------------------------
create procedure PHOTO.WA.dav_upload_file(
  in params any,
  in current_user photo_user,
  in image_index integer,
  in source varchar) returns integer
{
  declare path,album,home_path varchar;
  declare image,image_attrs,image_fname,image_name,image_type any;
  declare new_id integer;
  declare replace_image,visibility,rights,description,ch varchar;

  image_index := cast(image_index as varchar);

  album       := get_keyword ('album', params, '', 1);
  visibility  := get_keyword('visibility',params,1);
  description := get_keyword(concat('description_',image_index),params,'');

  if(visibility = '1')
  {
    rights := '110100100R';
  }else{
    rights := '110000000R';
    visibility := '0';
  }

  if (source = 'file')
  {
    ch := '\\';

    image       := get_keyword (concat('my_image_',image_index), params, '', 1);
    image_attrs := get_keyword_ucase (concat('attr-my_image_',image_index), params);
    image_type  := get_keyword_ucase ('Content-Type', image_attrs);
    image_fname := trim(get_keyword_ucase ('filename', image_attrs));
    replace_image := get_keyword(concat('replace_image_',image_index), params, '', 1);
    if(replace_image <> '')
      image_name := replace_image;
  }

  if (source = 'dav')
  {
    ch := '/';
    image_fname := get_keyword (concat ('f_dav_', image_index), params,'');
    DB.DBA.DAV_RES_CONTENT_INT (DAV_SEARCH_ID (image_fname, 'R'), image, image_type, 0, 0);
  }

  image_name  := substring(image_fname,PHOTO.WA._locate_last(ch,image_fname)+1,length(image_fname));
  home_path   := get_keyword_ucase ('home_path', params);
  path := concat(home_path,album,'/',image_name);
  new_id := DB.DBA.DAV_RES_UPLOAD(path,
                           image,
                           image_type ,
                           rights,
                           current_user.user_id,
                           current_user.user_id,
                           current_user.auth_uid,
                           current_user.auth_pwd);
  if(new_id > 0)
  {
    DB.DBA.DAV_PROP_REMOVE (DB.DBA.DAV_SEARCH_PATH (new_id,'R'),'description',current_user.auth_uid,current_user.auth_pwd);
    DB.DBA.DAV_PROP_SET (DB.DBA.DAV_SEARCH_PATH (new_id,'R'),'description',cast(description as varchar),current_user.auth_uid,current_user.auth_pwd);
    PHOTO.WA.sioc_content(current_user,path,description);

    return new_id;
  }
  return null;
}
;

--------------------------------------------------------------------------------
create procedure PHOTO.WA.dav_delete(
  in sid varchar,
  in p_gallery_id integer,
  in mode varchar,
  in ids integer array) returns integer array
{
  declare path varchar;
  declare i,result integer;
  declare res integer;
  declare auth_uid varchar;
  declare current_user photo_user;
  declare id integer;
  declare res_ids any;

  auth_uid := PHOTO.WA._session_user(vector('realm','wa','sid',sid),current_user);
  if (auth_uid = '')
    return vector();

  res_ids := vector();
  for (i := 0; i < length(ids); i := i + 1)
    {
    path := DB.DBA.DAV_SEARCH_PATH (ids[i], ucase (mode));
    if (cast(path as varchar) <> '')
      {   
      result := DB.DBA.DAV_DELETE (path, null, current_user.auth_uid, current_user.auth_pwd);
      if (result > 0)
        res_ids := vector_concat(res_ids,vector(ids[i]));
      }
    }
  return res_ids;
}
;

--------------------------------------------------------------------------------
create procedure PHOTO.WA.delete_image_thumbnail(
  in image_path varchar,
  in auth_uid integer,
  in auth_pwd varchar) returns  integer
{
  declare image_id,col_id,result integer;
  declare image_name,thumb_path varchar;
  
  image_id := DB.DBA.DAV_SEARCH_ID (image_path, 'R');
  if (image_id < 0)
    return -1;

  declare exit handler for sqlstate '*'
  {
    return -1;
  };
  select RES_NAME,RES_COL into image_name,col_id from WS.WS.SYS_DAV_RES where RES_ID= image_id;

  thumb_path := DB.DBA.DAV_SEARCH_PATH (col_id, 'C');
  thumb_path:=thumb_path||'.thumbnails/'||image_name;
  
  result := DB.DBA.DAV_DELETE (thumb_path, null, auth_uid, auth_pwd);
  return result;
}
;

--------------------------------------------------------------------------------
create procedure PHOTO.WA.get_dav_auth (inout _auth varchar, inout _pwd varchar)
{
  select U_NAME, pwd_magic_calc (U_NAME, U_PASSWORD, 1)
    into _auth, _pwd
    from DB.DBA.SYS_USERS
   where U_ID = http_dav_uid ();
}
;

--------------------------------------------------------------------------------
create procedure PHOTO.WA.get_image(
  in sid varchar,
  in p_gallery_id integer,
  in _res_id integer) returns SOAP_album
{
  declare _owner_id,path,_res_mod_time,_path,_res_perms,visibility,_res_group,_res_owner,_res_cr_time,_res_type,_res_name,visibility,description,auth_uid any;
  declare current_user photo_user;

  auth_uid := PHOTO.WA._session_user(vector('realm','wa','sid',sid),current_user);

  select RES_OWNER,RES_MOD_TIME,RES_PERMS,RES_GROUP,RES_OWNER,RES_CR_TIME,RES_TYPE,RES_NAME,RES_FULL_PATH
    into _owner_id,_res_mod_time,_res_perms,_res_group,_res_owner,_res_cr_time,_res_type,_res_name,_path
    from WS.WS.SYS_DAV_RES
    where RES_ID = _res_id;

  if (substring(_res_perms,7,1) = '1')
  {
    visibility := 1; -- public
  }else{
    visibility := 0; -- private
  }

  description := DB.DBA.DAV_PROP_GET (_path,'description',current_user.auth_uid,current_user.auth_pwd);
  if (__tag(description) <> 189)
  {
    description := cast(description  as varchar);
  }else{
    description := '';
  }



  return new SOAP_album(_path,'R',0,_res_mod_time,_res_id,visibility,_res_group,_res_owner,_res_cr_time,_res_type,_res_name,now(),now(),description);
}
;

--------------------------------------------------------------------------------
create procedure PHOTO.WA.edit_image(
  in sid varchar,
  in p_gallery_id integer,
  in path varchar,
  in old_name varchar,
  in new_name varchar,
  in description varchar,
  in visibility integer)
  returns SOAP_album
  {
  declare current_user photo_user;
  declare auth_uid,rights varchar;
  declare result SOAP_album;
  declare res integer;

  auth_uid := PHOTO.WA._session_user(vector('realm','wa','sid',sid),current_user);
  if(auth_uid = '')
  {
    return 0;
  }

  if (visibility = 1)
  {
    rights := '110100100R';
  }else{
    rights := '110000000R';
  }
  declare col_id integer;

  if(old_name <> new_name)
  {
    col_id := DB.DBA.DAV_MOVE (concat(path,old_name),concat(path,new_name),1,current_user.auth_uid,current_user.auth_pwd);
  }
  col_id := DB.DBA.DAV_SEARCH_ID (concat (path, new_name), 'R');
  if (col_id > 0)
  {
    DB.DBA.DAV_PROP_REMOVE (DB.DBA.DAV_SEARCH_PATH (col_id,'R'),'description',current_user.auth_uid,current_user.auth_pwd);
    DB.DBA.DAV_PROP_SET (DB.DBA.DAV_SEARCH_PATH (col_id,'R'),'description',description,current_user.auth_uid,current_user.auth_pwd);
    DB.DBA.DAV_PROP_SET (DB.DBA.DAV_SEARCH_PATH (col_id,'R'),':virtpermissions',rights,current_user.auth_uid,current_user.auth_pwd);

    return new SOAP_album(path,cast(col_id as integer),visibility,'',new_name,description);
  }else{
    result := 0;
  }

  return result;
}
;

--------------------------------------------------------------------------------
create procedure PHOTO.WA.tag_images(
  in sid varchar,
  in p_gallery_id integer,
  in home_url varchar,
  in ids integer array,
  in tags varchar)
returns  varchar
{
  declare path varchar;
  declare i,result integer;
  declare res integer;
  declare auth_uid varchar;
  declare current_user photo_user;
  declare id integer;
  declare res_ids any;
  declare current_instance photo_instance;

  auth_uid := PHOTO.WA._session_user(vector('realm','wa','sid',sid),current_user);

  if(auth_uid = '')
  {
    return vector();
  }
  current_instance := new photo_instance(home_url);

  for (i := 0; i < length(ids); i := i + 1)
  {
    path := DB.DBA.DAV_SEARCH_PATH(ids[i],'R');
    PHOTO.WA.tag_join(current_user,path,tags);
    PHOTO.WA.sioc_tag(current_user,current_instance,path,tags);
  }
  return tags;
}
;

--------------------------------------------------------------------------------
create procedure PHOTO.WA.tag_image(
  in sid varchar,
  in p_gallery_id integer,
  in home_url varchar,
  in id integer,
  in tag varchar) returns  varchar array
{
  declare allTags any;
  declare path varchar;
  declare auth_uid varchar;
  declare current_user photo_user;
  declare current_instance photo_instance;

  auth_uid := PHOTO.WA._session_user(vector('realm','wa','sid',sid),current_user);
  if(auth_uid = '')
  {
    return vector();
  }
  current_instance := new photo_instance(home_url);

  if (not PHOTO.WA.validate_tags (tag))
  {
    tag := '';
  }
  path := DB.DBA.DAV_SEARCH_PATH (id, 'R');
  allTags := PHOTO.WA.tag_join (current_user, path, tag);
  PHOTO.WA.sioc_tag (current_user, current_instance, path, tag);

  return allTags;
}
;

--------------------------------------------------------------------------------
create procedure PHOTO.WA.remove_tag_image(
  in sid varchar,
  in p_gallery_id integer,
  in id integer,
  in tag varchar)
returns  varchar array
{
  declare tags any;
  declare path varchar;
  declare auth_uid varchar;
  declare current_user photo_user;

  auth_uid := PHOTO.WA._session_user(vector('realm','wa','sid',sid),current_user);
  if(auth_uid = '')
  {
    return vector();
  }

  path := DB.DBA.DAV_SEARCH_PATH (id, 'R');
  tags := PHOTO.WA.tag_remove(current_user,path,tag);

  return tags;
}
;

--------------------------------------------------------------------------------
create procedure PHOTO.WA.tag_join(
  in current_user photo_user,
  in path varchar,
  in new_tags varchar)
returns varchar array
{
  declare current_tags,resultTags,result,allTags any;

  if (cast (path as varchar) <> '')
  {
    current_tags := DB.DBA.DAV_PROP_GET (path,':virtprivatetags',current_user.auth_uid,current_user.auth_pwd);
    resultTags := concat(current_tags, ',', new_tags);
    resultTags := PHOTO.WA.tags2vector(resultTags);
    resultTags := PHOTO.WA.tags2unique(resultTags);
    allTags := resultTags;
    resultTags := PHOTO.WA.vector2tags(resultTags);
    DB.DBA.DAV_PROP_REMOVE (path,':virtprivatetags',current_user.auth_uid,current_user.auth_pwd);
    result := DB.DBA.DAV_PROP_SET (path,':virtprivatetags',resultTags,current_user.auth_uid,current_user.auth_pwd);

    return allTags;
  }
  return vector();
}
;

--------------------------------------------------------------------------------
create procedure PHOTO.WA.tag_remove(
  in current_user photo_user,
  in path varchar,
  in tag varchar)
returns  varchar array
{
  declare current_tags,resultTags,result any;

  if (cast (path as varchar) <> '')
  {
    current_tags := DB.DBA.DAV_PROP_GET (path,':virtprivatetags',current_user.auth_uid,current_user.auth_pwd);
    resultTags := PHOTO.WA.tag_delete(current_tags,tag);
    DB.DBA.DAV_PROP_REMOVE (path,':virtprivatetags',current_user.auth_uid,current_user.auth_pwd);
    result := DB.DBA.DAV_PROP_SET (path,':virtprivatetags',resultTags,current_user.auth_uid,current_user.auth_pwd);
    resultTags := PHOTO.WA.tags2vector(resultTags);

    return resultTags;
  }
  return vector();
}
;

--------------------------------------------------------------------------------
create procedure PHOTO.WA.sioc_tag(
  in current_user photo_user,
  in current_instance photo_instance,
  in path varchar,
  in tags varchar)
{
  declare iri, creator_iri, tiri any;
  declare _ind integer;

  iri := sioc.DBA.dav_res_iri (path);
  creator_iri := sioc.DBA.user_iri (current_user.user_id);
  tags := PHOTO.WA.tags2vector(tags);
  for (_ind := 0; _ind < length(tags); _ind := _ind + 1)
  {
    tiri := sprintf ('http://%s%s?tag=%s', sioc.DBA.get_cname(), current_instance.home_url, tags[_ind]);
    DB.DBA.RDF_QUAD_URI (sioc.DBA.get_graph(), iri, sioc.DBA.sioc_iri ('topic'), tiri);
  }
}
;

--------------------------------------------------------------------------------
create procedure PHOTO.WA.sioc_content(
  in current_user photo_user,
  in path varchar,
  in content varchar)
{
  declare iri,creator_iri,tiri,creator_iri any;
  declare _ind integer;

  iri := sioc.DBA.dav_res_iri (path);
  creator_iri := sioc.DBA.user_iri (current_user.user_id);

  DB.DBA.RDF_QUAD_URI (sioc.DBA.get_graph(), iri, sioc.DBA.sioc_iri ('content'), content);
}
;
--------------------------------------------------------------------------------
create procedure PHOTO.WA.user_get_role(
  in sid varchar,
  in p_gallery_id integer)
  returns integer
{
  declare auth_uid,_owner_uid integer;

  whenever not found goto not_found;

  select U.U_ID
    into auth_uid
   from DB.DBA.VSPX_SESSION S,WS.WS.SYS_DAV_USER U
  where S.VS_REALM = 'wa'
    and S.VS_SID   = sid
    and S.VS_UID   = U.U_NAME;

  SELECT OWNER_ID
    INTO _owner_uid
    FROM PHOTO.WA.SYS_INFO
   WHERE GALLERY_ID = p_gallery_id;


  if(auth_uid=_owner_uid)
     return 1;

not_found:;
     return 0;
}
;
