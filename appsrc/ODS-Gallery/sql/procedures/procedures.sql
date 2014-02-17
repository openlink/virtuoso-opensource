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

-------------------------------------------------------------------------------
--
create procedure PHOTO.WA.host_protocol ()
{
  return case when is_https_ctx () then 'https://' else 'http://' end;
}
;

-------------------------------------------------------------------------------
--
create procedure PHOTO.WA.host_url ()
{
  declare host varchar;

  declare exit handler for sqlstate '*' { goto _default; };

  if (is_http_ctx ())
  {
    host := http_request_header (http_request_header ( ) , 'Host' , null , sys_connected_server_address ());
    if (isstring (host) and strchr (host , ':') is null)
    {
      declare hp varchar;
      declare hpa any;

      hp := sys_connected_server_address ();
      hpa := split_and_decode ( hp , 0 , '\0\0:');
      host := host || ':' || hpa [1];
    }
    goto _exit;
  }

_default:;
  host := cfg_item_value (virtuoso_ini_path (), 'URIQA', 'DefaultHost');
  if (host is null)
  {
    host := sys_stat ('st_host_name');
    if (server_http_port () <> '80')
      host := host || ':' || server_http_port ();
  }

_exit:;
  if (host not like PHOTO.WA.host_protocol () || '%')
    host := PHOTO.WA.host_protocol () || host;

  return host;
}
;

--------------------------------------------------------------------------------
--
create procedure PHOTO.WA.fix_dav_list(
  in dirlist any)
{
  declare ctr integer;

  for (ctr := 0; ctr < length(dirlist); ctr := ctr + 1)
  {
    if(dirlist[ctr][6] = 0)
  {
      dirlist[ctr][6] := 0;
    }
  }
  return dirlist;
}
;

--------------------------------------------------------------------------------
create procedure PHOTO.WA.photo_init_user_data(
  in wai_id   integer,
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

  --gallery_id := sequence_next('PHOTO.WA.gallery_id');
  gallery_id := wai_id;
  home_url   := connection_get('ogallery_customendpoint');

  -- TODO - to check for backslash

  --if(strrchr(home_url,'/') <> length(home_url)){
  --  home_url   := home_url || '/';
  --}

  next_ind   := (SELECT COUNT(*) FROM PHOTO.WA.SYS_INFO WHERE OWNER_ID = current_user.user_id);
  if(next_ind > 0)
  {
    next_ind := next_ind + 1;
    next_ind   := cast(next_ind as varchar);
    next_ind := '-' || next_ind;
  }else{
    next_ind   := '';
  }

  home_path  := sprintf('/DAV/home/%s/Gallery%s/',auth_uid,next_ind);
  app_path   := concat(sHost, 'www-root/portal/index.vsp');

  if (home_url is null)
  {
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

  if (col_id > 0)
  {
    DAV_PROP_SET(DAV_SEARCH_PATH (col_id,'C'),'pub_date',cast(now() as varchar),current_user.auth_uid,current_user.auth_pwd);
    DAV_PROP_SET(DAV_SEARCH_PATH (col_id,'C'),'description','Demo album',current_user.auth_uid,current_user.auth_pwd);
  }

  -- Fixing bug with files owner
  --PHOTO.WA._fix1(col_id,current_user);
}
;

--------------------------------------------------------------------------------
create procedure PHOTO.WA.photo_delete_user_data(
  in owner_id integer)
{
  declare current_user photo_user;

  DELETE FROM PHOTO.WA.COMMENTS WHERE USER_ID = owner_id;

  declare home_url varchar;
  home_url := (select HOME_URL from PHOTO.WA.SYS_INFO where OWNER_ID = owner_id);

  VHOST_REMOVE(lpath      => home_url);
  DELETE FROM PHOTO.WA.SYS_INFO where OWNER_ID = owner_id;
}
;

--------------------------------------------------------------------------------
create procedure PHOTO.WA.check_exist_gallery(in current_user photo_user,in home_path varchar)
{
  declare result integer;
  declare home_dir varchar;

  result := DAV_SEARCH_ID(home_path,'C');

  if(result = -1)
  {
    result := PHOTO.WA.DAV_COL_CREATE(current_user,home_path,'110100100R');
  }
}
;

--------------------------------------------------------------------------------
create procedure PHOTO.WA.DAV_COL_CREATE (
  in current_user photo_user,
  in path varchar,
  in rights varchar)
{
  declare result any;

  result := DAV_COL_CREATE(path,rights,current_user.auth_uid,null,current_user.auth_uid,current_user.auth_pwd);
  return result;
}
;

--------------------------------------------------------------------------------
create procedure PHOTO.WA.DAV_SUBCOL_CREATE (
  in current_user photo_user,
  in path varchar)
{
  declare result any;
  --path := concat(current_user.home_dir,path,'/');
  path := concat(path,'/');
  result := DAV_COL_CREATE(path,'110100100R',current_user.auth_uid,null,current_user.auth_uid,current_user.auth_pwd);
  return result;
}
;

--------------------------------------------------------------------------------
create procedure PHOTO.WA.DAV_MOVE (
  in current_user photo_user,
  in old_path varchar,
  in new_path varchar)
{
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
  declare auth_uid,_state varchar;
  whenever not found goto not_found;

  select U.U_NAME,VS_STATE
    into auth_uid,_state
   from DB.DBA.VSPX_SESSION S,WS.WS.SYS_DAV_USER U
                    where S.VS_REALM = get_keyword('realm', params, '')
                      and S.VS_SID   = get_keyword('sid', params, '')
    and S.VS_UID   = U.U_NAME;

    current_user := new photo_user(auth_uid);
    current_user.sid := get_keyword('sid', params, '');
    current_user.realm := get_keyword('realm', params, '');
  current_user.ses_vars := deserialize(blob_to_string(_state));
  return auth_uid;

  not_found:
  current_user := new photo_user('nobody');

  return null;
}
;

--------------------------------------------------------------------------------
create procedure PHOTO.WA._session_var_save(
  inout current_user photo_user)
{
  declare auth_uid,_state varchar;

  _state := serialize(current_user.ses_vars);

  update DB.DBA.VSPX_SESSION
    set VS_STATE = _state
  where VS_REALM = current_user.realm
    and VS_SID   = current_user.sid;
    --and VS_UID   = current_user.user_id;
  return;
}
;

--------------------------------------------------------------------------------
create procedure PHOTO.WA._session_var_set(
  inout current_user photo_user,
  in param any,
  in value any)
{
  declare ind any;
  ind := position(param,current_user.ses_vars);

  if (ind > 0)
  {
    declare tmp any;
    tmp := current_user.ses_vars;
    tmp[ind] := value;
    current_user.ses_vars := tmp;
  }else{
    current_user.ses_vars := vector_concat(current_user.ses_vars,vector(param,value));
  }
}
;

--------------------------------------------------------------------------------
create procedure PHOTO.WA._session_var_unset(
  inout current_user photo_user,
  in param any)
{
  declare ind,i,tmp any;
  ind := position(param,current_user.ses_vars);
  i:=0;
  tmp:= vector();
  if(ind > 0)
  {
    while(i < length(current_user.ses_vars))
    {
      if(i <> ind-1)
      {
        tmp := vector_concat(tmp,vector(current_user.ses_vars[i],current_user.ses_vars[i+1]));
      }
      i:=i+2;
    }
    current_user.ses_vars := tmp;
  }
}
;

--------------------------------------------------------------------------------
create procedure PHOTO.WA._session_var_get(
  inout current_user photo_user,
  in param any)
{
  return get_keyword(param,current_user.ses_vars,null);
}
;

-------------------------------------------------------------------------------
--
create procedure PHOTO.WA._session_role (
  in gallery_id integer,
  in user_id integer)
{
  whenever not found goto _end;

  if (PHOTO.WA._user_is_admin (user_id))
    return 'admin';

  if (exists (select 1
                from SYS_USERS A,
                     WA_MEMBER B,
                     WA_INSTANCE C
               where A.U_ID = user_id
                 and B.WAM_USER = A.U_ID
                 and B.WAM_MEMBER_TYPE = 1
                 and B.WAM_INST = C.WAI_NAME
                 and C.WAI_ID = gallery_id))
    return 'owner';

  if (exists (select 1
                from SYS_USERS A,
                     WA_MEMBER B,
                     WA_INSTANCE C
               where A.U_ID = user_id
                 and B.WAM_USER = A.U_ID
                 and B.WAM_MEMBER_TYPE = 2
                 and B.WAM_INST = C.WAI_NAME
                 and C.WAI_ID = gallery_id))
    return 'author';

  if (exists (select 1
                from SYS_USERS A,
                     WA_MEMBER B,
                     WA_INSTANCE C
               where A.U_ID = user_id
                 and B.WAM_USER = A.U_ID
                 and B.WAM_INST = C.WAI_NAME
                 and C.WAI_ID = gallery_id))
    return 'viewer';

  if (exists (select 1
                from SYS_USERS A
               where A.U_ID = user_id))
    return 'guest';

_end:
  return 'public';
}
;

--------------------------------------------------------------------------------
create procedure PHOTO.WA._user_is_admin (
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
create procedure PHOTO.WA._user_pwd(
  in auth_uid varchar)
{
  declare auth_pwd varchar;

  auth_pwd := coalesce((SELECT U_PWD FROM WS.WS.SYS_DAV_USER WHERE U_NAME = auth_uid), '');
  if (auth_pwd[0] = 0)
  {
    auth_pwd := pwd_magic_calc(auth_uid, auth_pwd, 1);
  }
  return auth_pwd;
}
;

--------------------------------------------------------------------------------
create procedure PHOTO.WA.get_gallery_owner_id(
  in _gallery_id integer)
{
  declare _owner_id integer;

  _owner_id := (select OWNER_ID from PHOTO.WA.SYS_INFO where GALLERY_ID = _gallery_id);
  return _owner_id;
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

  if (user_pwd[0] = 0)
  {
    user_pwd := pwd_magic_calc(user_name, user_pwd, 1);
  }
  first_name := PHOTO.WA.user_name (user_name, first_name);
  if (last_name is null or trim (last_name) = '')
  {
    last_name := '';
  }
  full_name := PHOTO.WA.user_name (user_name, full_name);
  user_data := vector(user_name,user_pwd,full_name,user_id,first_name,last_name);
  return 1;

  err_exit:
  return 0;
}
;

-------------------------------------------------------------------------------
create procedure PHOTO.WA._get_user_name(
  in user_id varchar)
{
  declare user_name,user_pwd varchar;

  declare exit handler for NOT FOUND
  {
    return vector();
  };

  SELECT U_NAME,U_PASSWORD
    into user_name,user_pwd
    FROM DB.DBA.SYS_USERS
   WHERE U_ID = user_id;

  user_pwd := pwd_magic_calc(user_name, user_pwd, 1);
  return vector(user_name,user_pwd);
}
;

-------------------------------------------------------------------------------
--
create procedure PHOTO.WA.user_fullName (
  in account_id integer)
{
  return coalesce((select PHOTO.WA.user_name (U_NAME, U_FULL_NAME) from DB.DBA.SYS_USERS where U_ID = account_id), '');
}
;

-------------------------------------------------------------------------------
--
create procedure PHOTO.WA.user_name (
  in u_name any,
  in u_full_name any) returns varchar
{
  if (not is_empty_or_null (trim (u_full_name)))
    return trim (u_full_name);
  return u_name;
}
;

-------------------------------------------------------------------------------
--
create procedure PHOTO.WA.account_name (
  in account_id integer)
{
  return coalesce((select U_NAME from DB.DBA.SYS_USERS where U_ID = account_id), '');
}
;

-------------------------------------------------------------------------------
--
create procedure PHOTO.WA.gallery_show_map (
  in gallery_id integer)
{
  return coalesce((select SHOW_MAP from PHOTO.WA.SYS_INFO where GALLERY_ID = gallery_id), 0);
}
;

-------------------------------------------------------------------------------
create procedure get_dav_gallery(
  in _path varchar)
{
  -- Da vrashta obekt s instans ime
  declare _home_path varchar;
  declare _owner_id integer;

  declare exit handler for NOT FOUND
  {
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
create procedure PHOTO.WA.frozen_check(
  in current_instance photo_instance,
  in current_user photo_user)
{
  if (PHOTO.WA.check_admin(current_user.user_id))
{
    return 0;
  }
  return coalesce((select WAI_IS_FROZEN from DB.DBA.WA_INSTANCE where WAI_NAME = current_instance.name), 0);
}
;

-------------------------------------------------------------------------------
create procedure PHOTO.WA.frozen_page (
  in name varchar)
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
create procedure PHOTO.WA._fix2(in COL_ID integer,in current_user photo_user,in col varchar)
{
  DAV_PROP_SET(concat(current_user.gallery_dir,col,'/'),':virtowneruid',current_user.user_id,'dav','dav');

  for(select RES_NAME from WS.WS.SYS_DAV_RES WHERE RES_COL = COL_ID)
  do{
    DAV_PROP_SET(concat(current_user.gallery_dir,col,'/',RES_NAME),':virtowneruid',current_user.user_id,'dav','dav');
  }

}
;

--------------------------------------------------------------------------------
create procedure PHOTO.WA._fix1(in _COL_ID integer,in current_user photo_user)
{
  _COL_ID := DAV_SEARCH_ID(current_user.gallery_dir,'C');

  for(select COL_NAME,COL_ID from WS.WS.SYS_DAV_COL WHERE COL_PARENT = _COL_ID) do
  {
    PHOTO.WA._fix2(COL_ID,current_user,COL_NAME);
  }
}
;

--------------------------------------------------------------------------------
create procedure PHOTO.WA.fix_old_versions()
{
  declare _user_name,_user_id,_gallery_id,_wai_name,_home_path,_home_url any;

  if (registry_get('_oGallery_old_version_') > '0.1.82')
  {
    return;
  }
  for(SELECT WAI_NAME FROM DB.DBA.WA_INSTANCE WHERE WAI_TYPE_NAME = 'oGallery') do
  {
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

    if (NOT((SELECT COUNT(GALLERY_ID) FROM PHOTO.WA.SYS_INFO WHERE WAI_NAME = _wai_name)))
    {
      INSERT INTO PHOTO.WA.SYS_INFO(GALLERY_ID,OWNER_ID,WAI_NAME,HOME_URL,HOME_PATH)
          VALUES(_gallery_id,_user_id,_wai_name,_home_url,_home_path);
    }
  }
}
;

-------------------------------------------------------------------------------
--
create procedure PHOTO.WA.resource_gallery_id (
  in _res_id integer)
{
  declare _parent_id integer;

  _parent_id := (select COL_PARENT
                   from WS.WS.SYS_DAV_COL, WS.WS.SYS_DAV_RES
                  where COL_ID = RES_COL and RES_ID = _res_id);
  if (isnull (_parent_id))
    return null;

  return (select GALLERY_ID from PHOTO.WA.SYS_INFO where HOME_PATH = DB.DBA.DAV_SEARCH_PATH (_parent_id, 'C'));
}
;

-------------------------------------------------------------------------------
--
create procedure PHOTO.WA.get_geo_info (
  in user_id integer)
{
  declare e_lat, e_lng any;

  if (user_id = -1)
  {
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
--
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
    if (N = 0)
    {
      aResult := trim(aVector[N]);
    } else {
      aResult := concat(aResult, ',', trim(aVector[N]));
    }
  return aResult;
}
;

-------------------------------------------------------------------------------
--
create procedure PHOTO.WA.string2vector(
  inout _str varchar,
  in separator varchar)
{
  return split_and_decode(_str, 0, '\0\0'||separator);
}
;

-------------------------------------------------------------------------------
--
create procedure PHOTO.WA.vector2string(
  inout aVector any,
  in separator varchar)
{
  declare N integer;
  declare aResult any;

  aResult := '';
  for (N := 0; N < length(aVector); N := N + 1)
    if (N = 0)
    {
      aResult := trim(aVector[N]);
    } else {
      aResult := concat(aResult, separator , trim(aVector[N]));
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
  for (N := 0; N < length(aVector); N := N + 1)
  {
    for (M := 0; M < length(aResult); M := M + 1)
      if (trim(lcase(aResult[M])) = trim(lcase(aVector[N])))
        goto _next;
    aResult := vector_concat(aResult, vector(trim(aVector[N])));
  _next:;
  }
  return aResult;
}
;

-----------------------------------------------------------------------------------------
--
create procedure PHOTO.WA.test_clear (
  in S any)
{
  declare N integer;

  return substring(S, 1, coalesce(strstr(S, '<>'), length(S)));
}
;

-----------------------------------------------------------------------------------------
--
create procedure PHOTO.WA.test (
  in value any,
  in params any := null)
{
  declare valueType, valueClass, valueName, valueMessage, tmp any;

  declare exit handler for SQLSTATE '*'
  {
    if (not is_empty_or_null(valueMessage))
      signal ('TEST', valueMessage);
    if (__SQL_STATE = 'EMPTY')
      signal ('TEST', sprintf ('Field ''%s'' cannot be empty!<>', valueName));
    if (__SQL_STATE = 'CLASS')
    {
      if (valueType in ('free-text', 'tags'))
      {
        signal ('TEST', sprintf ('Field ''%s'' contains invalid characters or noise words!<>', valueName));
      } else {
        signal ('TEST', sprintf ('Field ''%s'' contains invalid characters!<>', valueName));
      }
    }
    if (__SQL_STATE = 'TYPE')
      signal ('TEST', sprintf ('Field ''%s'' contains invalid characters for \'%s\'!<>', valueName, valueType));
    if (__SQL_STATE = 'MIN')
      signal ('TEST', sprintf ('''%s'' value should be greater than %s!<>', valueName, cast (tmp as varchar)));
    if (__SQL_STATE = 'MAX')
      signal ('TEST', sprintf ('''%s'' value should be less than %s!<>', valueName, cast (tmp as varchar)));
    if (__SQL_STATE = 'MINLENGTH')
      signal ('TEST', sprintf ('The length of field ''%s'' should be greater than %s characters!<>', valueName, cast (tmp as varchar)));
    if (__SQL_STATE = 'MAXLENGTH')
      signal ('TEST', sprintf ('The length of field ''%s'' should be less than %s characters!<>', valueName, cast (tmp as varchar)));
    if (__SQL_STATE = 'SPECIAL')
      signal ('TEST', __SQL_MESSAGE || '<>');
    signal ('TEST', 'Unknown validation error!<>');
    --resignal;
  };

  value := trim(value);
  if (is_empty_or_null(params))
    return value;

  valueClass := coalesce(get_keyword ('class', params), get_keyword ('type', params));
  valueType := coalesce(get_keyword ('type', params), get_keyword ('class', params));
  valueName := get_keyword ('name', params, 'Field');
  valueMessage := get_keyword ('message', params, '');
  tmp := get_keyword ('canEmpty', params);
  if (isnull (tmp))
  {
    if (not isnull (get_keyword ('minValue', params))) {
      tmp := 0;
    } else if (get_keyword ('minLength', params, 0) <> 0) {
      tmp := 0;
    }
  }
  if (not isnull (tmp) and (tmp = 0) and is_empty_or_null (value))
  {
    signal('EMPTY', '');
  }
  else if (is_empty_or_null(value))
  {
    return value;
  }

  value := PHOTO.WA.validate2 (valueClass, value);

  if (valueType = 'integer')
  {
    tmp := get_keyword ('minValue', params);
    if ((not isnull (tmp)) and (value < tmp))
      signal('MIN', cast (tmp as varchar));

    tmp := get_keyword ('maxValue', params);
    if (not isnull (tmp) and (value > tmp))
      signal('MAX', cast (tmp as varchar));

  }
  else if (valueType = 'float')
  {
    tmp := get_keyword ('minValue', params);
    if (not isnull (tmp) and (value < tmp))
      signal('MIN', cast (tmp as varchar));

    tmp := get_keyword ('maxValue', params);
    if (not isnull (tmp) and (value > tmp))
      signal('MAX', cast (tmp as varchar));
  }
  else if (valueType = 'varchar')
  {
    tmp := get_keyword ('minLength', params);
    if (not isnull (tmp) and (length(PHOTO.WA.utf2wide(value)) < tmp))
      signal('MINLENGTH', cast (tmp as varchar));

    tmp := get_keyword ('maxLength', params);
    if (not isnull (tmp) and (length(PHOTO.WA.utf2wide(value)) > tmp))
      signal('MAXLENGTH', cast (tmp as varchar));
  }
  return value;
}
;

-----------------------------------------------------------------------------------------
--
create procedure PHOTO.WA.validate2 (
  in propertyType varchar,
  in propertyValue varchar)
{
  declare exit handler for SQLSTATE '*'
  {
    if (__SQL_STATE = 'CLASS')
      resignal;
    if (__SQL_STATE = 'SPECIAL')
      resignal;
    signal('TYPE', propertyType);
    return;
  };

  if (propertyType = 'boolean')
  {
    if (propertyValue not in ('Yes', 'No'))
      goto _error;
  }
  else if (propertyType = 'integer')
  {
    if (isnull (regexp_match('^[0-9]+\$', propertyValue)))
      goto _error;
    return cast (propertyValue as integer);
  }
  else if (propertyType = 'float')
  {
    if (isnull (regexp_match('^[-+]?([0-9]*\.)?[0-9]+([eE][-+]?[0-9]+)?\$', propertyValue)))
      goto _error;
    return cast (propertyValue as float);
  }
  else if (propertyType = 'dateTime')
  {
    if (isnull (regexp_match('^((?:19|20)[0-9][0-9])[- /.](0[1-9]|1[012])[- /.](0[1-9]|[12][0-9]|3[01]) ([01]?[0-9]|[2][0-3])(:[0-5][0-9])?\$', propertyValue)))
      goto _error;
    return cast (propertyValue as datetime);
  }
  else if (propertyType = 'dateTime2')
  {
    if (isnull (regexp_match('^((?:19|20)[0-9][0-9])[- /.](0[1-9]|1[012])[- /.](0[1-9]|[12][0-9]|3[01]) ([01]?[0-9]|[2][0-3])(:[0-5][0-9])?\$', propertyValue)))
      goto _error;
    return cast (propertyValue as datetime);
  }
  else if (propertyType = 'date')
  {
    if (isnull (regexp_match('^((?:19|20)[0-9][0-9])[- /.](0[1-9]|1[012])[- /.](0[1-9]|[12][0-9]|3[01])\$', propertyValue)))
      goto _error;
    return cast (propertyValue as datetime);
  }
  else if (propertyType = 'date2')
  {
    if (isnull (regexp_match('^(0[1-9]|[12][0-9]|3[01])[- /.](0[1-9]|1[012])[- /.]((?:19|20)[0-9][0-9])\$', propertyValue)))
      goto _error;
    return stringdate(PHOTO.WA.dt_reformat(propertyValue, 'd.m.Y', 'Y-M-D'));
  }
  else if (propertyType = 'time')
  {
    if (isnull (regexp_match('^([01]?[0-9]|[2][0-3])(:[0-5][0-9])?\$', propertyValue)))
      goto _error;
    return cast (propertyValue as time);
  }
  else if (propertyType = 'folder')
  {
    if (isnull (regexp_match('^[^\\\/\?\*\"\'\>\<\:\|]*\$', propertyValue)))
      goto _error;
  }
  else if ((propertyType = 'uri') or (propertyType = 'anyuri'))
  {
    if (isnull (regexp_match('^(ht|f)tp(s?)\:\/\/[0-9a-zA-Z]([-.\w]*[0-9a-zA-Z])*(:(0-9)*)*(\/?)([a-zA-Z0-9\-\.\?\,\'\/\\\+&amp;%\$#_=:]*)?\$', propertyValue)))
      goto _error;
  }
  else if (propertyType = 'email')
  {
    if (isnull (regexp_match('^([a-zA-Z0-9_\-])+(\.([a-zA-Z0-9_\-])+)*@((\[(((([0-1])?([0-9])?[0-9])|(2[0-4][0-9])|(2[0-5][0-5])))\.(((([0-1])?([0-9])?[0-9])|(2[0-4][0-9])|(2[0-5][0-5])))\.(((([0-1])?([0-9])?[0-9])|(2[0-4][0-9])|(2[0-5][0-5])))\.(((([0-1])?([0-9])?[0-9])|(2[0-4][0-9])|(2[0-5][0-5]))\]))|((([a-zA-Z0-9])+(([\-])+([a-zA-Z0-9])+)*\.)+([a-zA-Z])+(([\-])+([a-zA-Z0-9])+)*))\$', propertyValue)))
      goto _error;
  }
  else if (propertyType = 'free-text')
  {
    if (length(propertyValue))
      if (not PHOTO.WA.validate_freeTexts(propertyValue))
        goto _error;
  }
  else if (propertyType = 'free-text-expression')
  {
    if (length(propertyValue))
      if (not PHOTO.WA.validate_freeText(propertyValue))
        goto _error;
  }
  else if (propertyType = 'tags')
  {
    if (not PHOTO.WA.validate_tags(propertyValue))
      goto _error;
  }
  return propertyValue;

_error:
  signal('CLASS', propertyType);
}
;

-----------------------------------------------------------------------------------------
--
create procedure PHOTO.WA.validate_freeText (
  in S varchar)
{
  declare st, msg varchar;

  if (upper(S) in ('AND', 'NOT', 'NEAR', 'OR'))
    return 0;
  if (length (S) < 2)
    return 0;
  if (vt_is_noise (S, 'utf-8', 'x-ViDoc'))
    return 0;
  st := '00000';
  exec (sprintf ('vt_parse (\'[__lang "x-ViDoc" __enc "utf-8"] %s\')', S), st, msg, vector ());
  if (st <> '00000')
    return 0;
  return 1;
}
;

-----------------------------------------------------------------------------------------
--
create procedure PHOTO.WA.validate_tag (
  in S varchar)
{
  S := replace (trim(S), '+', '_');
  S := replace (trim(S), ' ', '_');
  if (not PHOTO.WA.validate_freeText (S))
    return 0;
  if (not isnull (strstr(S, '"')))
    return 0;
  if (not isnull (strstr(S, '''')))
    return 0;
  if (length (S) < 2)
    return 0;
  if (length (S) > 50)
    return 0;
  return 1;
}
;

-----------------------------------------------------------------------------------------
--
create procedure PHOTO.WA.validate_tags (
  in S varchar)
{
  declare N integer;
  declare V any;

  V := PHOTO.WA.tags2vector(S);
  if (is_empty_or_null(V))
    return 0;
  if (length(V) <> length(PHOTO.WA.tags2unique(V)))
    return 0;
  for (N := 0; N < length(V); N := N + 1)
    if (not PHOTO.WA.validate_tag(V[N]))
      return 0;
  return 1;
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
  foreach (any new_tag in new_tags) do
  {
    if (isstring(T) and (new_tag <> T))
      tags := concat(tags, ',', new_tag);
    if (isinteger(T) and (N <> T))
      tags := concat(tags, ',', new_tag);
    N := N + 1;
  }
  return trim(tags, ',');
}
;

--------------------------------------------------------------------------------
create procedure PHOTO.WA.isDav()
{
  declare iIsDav integer;
  declare sHost varchar;

  sHost := registry_get('_oGallery_path_');
  if (cast(sHost as varchar) = '0')
    sHost := '/apps/oGallery/';

  iIsDav := 1;

  if (isnull(strstr(sHost, '/DAV')))
    iIsDav := 0;
    
  return iIsDav;  
}
;

--------------------------------------------------------------------------------
create procedure PHOTO.WA.update_gallery_foldername()
{
  declare gallery_foldername varchar;
  
  gallery_foldername:=coalesce (PHOTO.WA.get_gallery_folder_name (), 'Gallery');
  
  for select GALLERY_ID as _gallery_id,OWNER_ID,HOME_PATH from PHOTO.WA.SYS_INFO  do
  {
   if (not locate(gallery_foldername,HOME_PATH ))
   {
    declare auth_uname,auth_pwd,new_home_path varchar;
    declare res,arr_len integer;
    declare old_foldername_arr any;
  
    select U_NAME,pwd_magic_calc(U_NAME, coalesce(U_PWD,''), 1) into auth_uname,auth_pwd from WS.WS.SYS_DAV_USER where U_ID=OWNER_ID;
  
    old_foldername_arr:=split_and_decode(HOME_PATH,0,'\0\0-');
    arr_len:=length(old_foldername_arr);
    
    if(arr_len=1)
       new_home_path := '/DAV/home/' || auth_uname || '/' || gallery_foldername || '/';
    else if(arr_len>1)
       new_home_path := '/DAV/home/' || auth_uname || '/' || gallery_foldername || '-' || old_foldername_arr[arr_len-1];
   
    res := DAV_MOVE(HOME_PATH,new_home_path,0,auth_uname,auth_pwd);
  
    if(res>0)
       update PHOTO.WA.SYS_INFO set HOME_PATH=new_home_path where GALLERY_ID=_gallery_id;
   }
  }
}
;
--------------------------------------------------------------------------------
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

-------------------------------------------------------------------------------
--
create procedure PHOTO.WA.instance_delete (
  in instance_id integer)
{
  declare CONTINUE HANDLER FOR SQLSTATE '*' {return 0; };

-- tables
  for (select HOME_URL from PHOTO.WA.SYS_INFO where GALLERY_ID = instance_id) do
  {
    VHOST_REMOVE(lpath      => home_url);
    for (select distinct RES_ID as _res_id from PHOTO.WA.COMMENTS where GALLERY_ID = instance_id) do
    {
      delete from PHOTO.WA.EXIF_DATA where RES_ID = _res_id;
    }
  }
  PHOTO.WA.nntp_update (instance_id, null, null, 1, 0);
  delete from PHOTO.WA.COMMENTS where GALLERY_ID = instance_id;
  delete from PHOTO.WA.SYS_INFO where GALLERY_ID = instance_id;

  return 1;
}
;

-------------------------------------------------------------------------------
--
create procedure PHOTO.WA.utf2wide (
  inout S any) returns any
{
  if (isstring (S))
    return charset_recode (S, 'UTF-8', '_WIDE_');
  return S;
}
;

-------------------------------------------------------------------------------
--
create procedure PHOTO.WA.wide2utf (
  inout S any) returns any
{
  if (iswidestring (S))
    return charset_recode (S, '_WIDE_', 'UTF-8' );
  return S;
}
;

-------------------------------------------------------------------------------
--
create procedure PHOTO.WA.settings (
  in _gallery_id integer)
{
  return coalesce((select deserialize(blob_to_string(SETTINGS))
                     from PHOTO.WA.SYS_INFO
                    where GALLERY_ID = _gallery_id), vector());
}
;

-------------------------------------------------------------------------------
--
create procedure PHOTO.WA.settings_albums_per_page (
  inout settings any)
{
  return cast(get_keyword ('albums_per_page', settings, '0') as integer);
}
;

-------------------------------------------------------------------------------
--
create procedure PHOTE.WA.url_content (
  in uri varchar)
{
  declare cont varchar;
  declare hp any;

  declare exit handler for sqlstate '*'
  {
    --dbg_obj_print (__SQL_STATE, __SQL_MESSAGE);
    return null;
  };

  declare N integer;
  declare oldUri, newUri, reqHdr, resHdr varchar;

  newUri := replace (uri, ' ', '%20');
  reqHdr := null;

_again:
  N := N + 1;
  oldUri := newUri;
  commit work;
  cont := http_get (newUri, resHdr, 'GET', reqHdr);
  if (resHdr[0] like 'HTTP/1._ 30_ %')
  {
    newUri := http_request_header (resHdr, 'Location');
    newUri := WS.WS.EXPAND_URL (oldUri, newUri);
    if (N > 15)
      return null;
    if (newUri <> oldUri)
      goto _again;
  }
  if (resHdr[0] like 'HTTP/1._ 4__ %' or resHdr[0] like 'HTTP/1._ 5__ %')
    return null;

  return cont;
}
;
