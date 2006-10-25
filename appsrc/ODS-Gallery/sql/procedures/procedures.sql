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



--------------------------------------------------------------------------------

create procedure PHOTO.WA.fix_dav_list(in dirlist any){

  declare ctr integer;
  ctr := 0;
  while (ctr < length(dirlist))
  {
    if(dirlist[ctr][6] = 0){
      dirlist[ctr][6] := 0;
    }
    ctr := ctr + 1;

  }

  return dirlist;
}
;

--------------------------------------------------------------------------------
create procedure PHOTO.WA.photo_init_user_data(
  in wai_name varchar,
  in auth_uid varchar)
{
  declare result integer;
  declare current_user photo_user;
  declare col_id,next_ind integer;

  declare iIsDav integer;
  declare sHost,app_path varchar;

  current_user := new photo_user(auth_uid);
  declare gallery_id integer;
  declare home_url,home_path varchar;

  sHost := registry_get('_oGallery_path_');

  if (cast(sHost as varchar) = '0')
    sHost := '/apps/oGallery/';

  iIsDav := 1;

  if (isnull(strstr(sHost, '/DAV')))
    iIsDav := 0;

  gallery_id := sequence_next('PHOTO.WA.gallery_id');
  home_url   := connection_get('ogallery_customendpoint');

  -- TODO - to check for bakslash

  --if(strrchr(home_url,'/') <> length(home_url)){
  --  home_url   := home_url || '/';
  --}

  next_ind   := (SELECT COUNT(*) FROM PHOTO.WA.SYS_INFO WHERE OWNER_ID = current_user.user_id);
  if(next_ind > 0){
    next_ind := next_ind + 1;
    next_ind   := cast(next_ind as varchar);
    next_ind := '-' || next_ind;
  }else{
    next_ind   := '';
  }

  home_path  := sprintf('/DAV/home/%s/gallery%s/',auth_uid,next_ind);
  app_path   := concat(sHost, 'www-root/portal/index.vsp');

  if(home_url is null){
    home_url:= concat('/photos/',auth_uid);
  }

  INSERT INTO PHOTO.WA.SYS_INFO(GALLERY_ID,OWNER_ID,WAI_NAME,HOME_URL,HOME_PATH) VALUES(gallery_id,current_user.user_id,wai_name,home_url,home_path);

  VHOST_REMOVE(lpath      => home_url);
  VHOST_DEFINE(lpath      => home_url,
               ppath      => app_path,
               opts       => vector('noinherit', 1),
               vsp_user   => 'dba',
               def_page   => 'index.vsp',
               is_dav     => iIsDav,
               ses_vars   => 1
              );

  result := PHOTO.WA.check_exist_gallery(current_user,home_path);
  col_id := PHOTO.WA.DAV_COL_CREATE(current_user,concat(home_path,'my_photos','/'),'110100100R');

  if(col_id > 0){
    DAV_PROP_SET(DAV_SEARCH_PATH (col_id,'C'),'pub_date',cast(now() as varchar),current_user.auth_uid,current_user.auth_pwd);
    DAV_PROP_SET(DAV_SEARCH_PATH (col_id,'C'),'description','Demo album',current_user.auth_uid,current_user.auth_pwd);
  }

  -- Fixing bug with files owner
  --PHOTO.WA._fix1(col_id,current_user);
}
;

--------------------------------------------------------------------------------
create procedure PHOTO.WA.photo_delete_user_data(in auth_uid varchar){
  declare current_user photo_user;

  DELETE FROM PHOTO.WA.comments WHERE USER_ID = auth_uid;

  declare home_url varchar;
  home_url := (select HOME_URL from PHOTO.WA.SYS_INFO where OWNER_ID = auth_uid);

  VHOST_REMOVE(lpath      => home_url);
  DELETE FROM PHOTO.WA.SYS_INFO where OWNER_ID = auth_uid;

}
;

--------------------------------------------------------------------------------
create procedure PHOTO.WA.check_exist_gallery(in current_user photo_user,in home_path varchar){
  declare result integer;
  declare home_dir varchar;

  result := DAV_SEARCH_ID(home_path,'C');

  if(result = -1){
    result := PHOTO.WA.DAV_COL_CREATE(current_user,home_path,'110100100R');
  }
}
;

--------------------------------------------------------------------------------
create procedure PHOTO.WA.DAV_COL_CREATE(in current_user photo_user, in path varchar,in rights varchar){
  declare result any;

  result := DAV_COL_CREATE(path,rights,current_user.auth_uid,null,current_user.auth_uid,current_user.auth_pwd);
  return result;
}
;

--------------------------------------------------------------------------------
create procedure PHOTO.WA.DAV_SUBCOL_CREATE(in current_user photo_user, in path varchar){
  declare result any;
  --path := concat(current_user.home_dir,path,'/');
  path := concat(path,'/');
  result := DAV_COL_CREATE(path,'110100100R',current_user.auth_uid,null,current_user.auth_uid,current_user.auth_pwd);
  return result;
}
;
--------------------------------------------------------------------------------
create procedure PHOTO.WA.DAV_MOVE(in current_user photo_user, in old_path varchar,in new_path varchar){
  declare result any;
  result := DAV_MOVE(old_path,new_path,0,current_user.auth_uid,current_user.auth_pwd);
  return result;
}
;

--------------------------------------------------------------------------------
create procedure PHOTO.WA._session_user(
  inout params any,
  inout current_user photo_user)
{
  declare auth_uid varchar;

  auth_uid := coalesce((select U.U_NAME
                     from DB.DBA.VSPX_SESSION S,
                          WS.WS.SYS_DAV_USER U
                    where S.VS_REALM = get_keyword('realm', params, '')
                      and S.VS_SID   = get_keyword('sid', params, '')
                      and S.VS_UID   = U.U_NAME), '');

  if(auth_uid <> ''){
    current_user := new photo_user(auth_uid);
    current_user.sid := get_keyword('sid', params, '');
    current_user.realm := get_keyword('realm', params, '');
  }else{
    current_user := new photo_user('nobody');
  }
  return auth_uid;
}
;


--------------------------------------------------------------------------------
create procedure PHOTO.WA._user_pwd(in auth_uid varchar){
  declare auth_pwd varchar;

  auth_pwd := coalesce((SELECT U_PWD FROM WS.WS.SYS_DAV_USER WHERE U_NAME = auth_uid), '');

  if (auth_pwd[0] = 0){
    auth_pwd := pwd_magic_calc(auth_uid, auth_pwd, 1);
  }
  return auth_pwd;
}
;

--------------------------------------------------------------------------------
create procedure PHOTO.WA.get_lastest_users(
  in current_user photo_user)
{
  -- Join с DAV_RES за да се извадят само тези които имат нещо шернато !
  -- да се извади и 1 шерната картинка на случаен принцип
  declare q varchar;
  q := 'SELECT TOP 10 U_ID user_id,U_NAME user_name,U_FULL_NAME full_name,WAM_INST name
          FROM WS.WS.SYS_DAV_USER newest_user
         INNER JOIN DB.DBA.WA_MEMBER gallery ON U_ID =  WAM_USER
         INNER JOIN DB.DBA.WA_INSTANCE ON WAI_NAME =  WAM_INST
         WHERE U_ID > 99 AND U_ID <> ? AND WAI_TYPE_NAME = ?
         ORDER BY U_ID DESC
           FOR XML AUTO';

  declare st any;
  st := string_output ();
  xml_auto (q, vector (current_user.user_id,'oGallery'), st);
  --result_names (q);
  return string_output_string (st);

}
;

--------------------------------------------------------------------------------
create procedure PHOTO.WA._user_data(
in user_name varchar,
out user_data any)
{
  declare user_pwd,first_name,last_name,full_name varchar;
  declare user_id integer;
  user_data := vector();

  whenever not found goto err_exit;

  SELECT U_PASSWORD,U_ID,WAUI_FIRST_NAME, WAUI_LAST_NAME,WAUI_FULL_NAME
    INTO user_pwd,user_id,first_name,last_name,full_name
    FROM WA_USER_INFO, DB.DBA.SYS_USERS
   WHERE WAUI_U_ID = U_ID
     AND U_NAME = user_name;

  if (user_pwd[0] = 0){
    user_pwd := pwd_magic_calc(user_name, user_pwd, 1);
  }

  if(first_name is null or first_name = ''){
    first_name := user_name;
  }

  if(last_name is null or last_name = ''){
    last_name := '';
  }

  user_data := vector(user_name,user_pwd,full_name,user_id,first_name,last_name);
  return 1;

  err_exit:
  return 0;
}
;


-------------------------------------------------------------------------------
create procedure get_dav_gallery(
  in _path varchar
){
  -- Da vrashta obekt s instans ime
  declare _home_path varchar;
  declare _owner_id integer;

  declare exit handler for NOT FOUND {
    return '';
  };

  SELECT OWNER_ID,HOME_PATH
    INTO _owner_id,_home_path
    FROM PHOTO.WA.SYS_INFO
   WHERE CONCAT(HOME_URL,'/') = _path;

  return _home_path;
}
;


-------------------------------------------------------------------------------
--
-- Freeze Functions
--
-------------------------------------------------------------------------------
create procedure PHOTO.WA.frozen_check( in current_instance photo_instance,in current_user photo_user)
{

  if (PHOTO.WA.check_admin(current_user.user_id)){
    return 0;
  }
  return coalesce((select WAI_IS_FROZEN from DB.DBA.WA_INSTANCE where WAI_NAME = current_instance.name), 0);
}
;

-------------------------------------------------------------------------------
create procedure PHOTO.WA.frozen_page(in name varchar)
{
  return (select WAI_FREEZE_REDIRECT from DB.DBA.WA_INSTANCE where WAI_NAME = name);
}
;

-------------------------------------------------------------------------------
create procedure PHOTO.WA.check_admin(
  in user_id integer) returns integer
{
  declare group_id integer;
  group_id := (select U_GROUP from SYS_USERS where U_ID = user_id);

  if (user_id = 0)
    return 1;
  if (user_id = http_dav_uid ())
    return 1;
  if (group_id = 0)
    return 1;
  if (group_id = http_dav_uid ())
    return 1;
  if(group_id = http_dav_uid()+1)
    return 1;
  return 0;
}
;


--------------------------------------------------------------------------------
-- Fixes
--------------------------------------------------------------------------------
create procedure PHOTO.WA._fix2(in COL_ID integer,in current_user photo_user,in col varchar){

  DAV_PROP_SET(concat(current_user.gallery_dir,col,'/'),':virtowneruid',current_user.user_id,'dav','dav');

  for(select RES_NAME from WS.WS.SYS_DAV_RES WHERE RES_COL = COL_ID)
  do{
    DAV_PROP_SET(concat(current_user.gallery_dir,col,'/',RES_NAME),':virtowneruid',current_user.user_id,'dav','dav');
  }

}
;

--------------------------------------------------------------------------------
create procedure PHOTO.WA._fix1(in _COL_ID integer,in current_user photo_user){

  _COL_ID := DAV_SEARCH_ID(current_user.gallery_dir,'C');

  for(select COL_NAME,COL_ID from WS.WS.SYS_DAV_COL WHERE COL_PARENT = _COL_ID)
  do{
    PHOTO.WA._fix2(COL_ID,current_user,COL_NAME);
  }

}
;



--------------------------------------------------------------------------------
create procedure PHOTO.WA.fix_old_versions(){
  declare _user_name,_user_id,_gallery_id,_wai_name,_home_path,_home_url any;

  if(registry_get('_oGallery_old_version_') > '0.1.82'){
    return;
  }

  for(SELECT WAI_NAME FROM DB.DBA.WA_INSTANCE WHERE WAI_TYPE_NAME = 'oGallery')
  do{
      SELECT U_NAME,WAM_USER,WAI_NAME
        INTO _user_name,_user_id,_wai_name
        FROM DB.DBA.WA_MEMBER
        LEFT JOIN WS.WS.SYS_DAV_USER ON U_ID =  WAM_USER
       WHERE WAM_INST = WAI_NAME;

    _gallery_id := sequence_next('PHOTO.WA.gallery_id');
    _home_path := concat('/DAV/home/',_user_name,'/gallery/');
    _home_url := concat('/photos/',_user_name);

    UPDATE DB.DBA.WA_MEMBER
       SET WAM_HOME_PAGE = _home_url||'/'
     WHERE (WAM_HOME_PAGE = '/gallery/' or WAM_HOME_PAGE = '/photos/bdimitrov/')
       AND WAM_APP_TYPE = 'oGallery'
       AND WAM_USER = _user_id;

    if(NOT((SELECT COUNT(GALLERY_ID) FROM PHOTO.WA.SYS_INFO WHERE WAI_NAME = _wai_name))){
      INSERT INTO PHOTO.WA.SYS_INFO(GALLERY_ID,OWNER_ID,WAI_NAME,HOME_URL,HOME_PATH)
          VALUES(_gallery_id,_user_id,_wai_name,_home_url,_home_path);
    }
  }

}
;

-------------------------------------------------------------------------------
create procedure PHOTO.WA.get_geo_info(in user_id integer){
  declare e_lat, e_lng any;
  if(user_id = -1){
    return vector(0, 0);
  }
  select WAUI_LAT, WAUI_LNG
    into e_lat, e_lng
    from DB.DBA.WA_USER_INFO
   where WAUI_U_ID = user_id;
   return vector(e_lat, e_lng);
}
;

-------------------------------------------------------------------------------
create procedure PHOTO.WA.tags2vector(
  inout tags varchar)
{
  return split_and_decode(trim(tags, ','), 0, '\0\0,');
}
;

-------------------------------------------------------------------------------
--
create procedure PHOTO.WA.vector2tags(
  inout aVector any)
{
  declare N integer;
  declare aResult any;

  aResult := '';
  for (N := 0; N < length(aVector); N := N + 1)
    if (N = 0) {
      aResult := trim(aVector[N]);
    } else {
      aResult := concat(aResult, ',', trim(aVector[N]));
    }
  return aResult;
}
;

-------------------------------------------------------------------------------
--
create procedure PHOTO.WA.tags2unique(
  inout aVector any)
{
  declare aResult any;
  declare N, M integer;

  aResult := vector();
  for (N := 0; N < length(aVector); N := N + 1) {
    for (M := 0; M < length(aResult); M := M + 1)
      if (trim(lcase(aResult[M])) = trim(lcase(aVector[N])))
        goto _next;
    aResult := vector_concat(aResult, vector(trim(aVector[N])));
  _next:;
  }
  return aResult;
}
;

-------------------------------------------------------------------------------
--
create procedure PHOTO.WA.tag_delete(
  inout tags varchar,
  inout T any)
{
  declare N integer;
  declare new_tags any;

  new_tags := PHOTO.WA.tags2vector (tags);
  tags := '';
  N := 0;
  foreach (any new_tag in new_tags) do {
    if (isstring(T) and (new_tag <> T))
      tags := concat(tags, ',', new_tag);
    if (isinteger(T) and (N <> T))
      tags := concat(tags, ',', new_tag);
    N := N + 1;
  }
  return trim(tags, ',');
}
;

--
create procedure PHOTO.WA.GET_ODS_BAR (
  inout _params any,
  inout _lines any)
{
  return ODS.BAR._EXEC('Gallery', deserialize(_params), deserialize(_lines));
}
;

grant execute on PHOTO.WA.GET_ODS_BAR to public;
xpf_extension ('http://www.openlinksw.com/photos/:getODSBar', 'PHOTO.WA.GET_ODS_BAR');


-------------------------------------------------------------------------------
PHOTO.WA._exec_no_error(
  'PHOTO.WA.fix_old_versions()'
)
;

-------------------------------------------------------------------------------
PHOTO.WA._exec_no_error(
  'drop procedure dav_browse'
)
;
