


--------------------------------------------------------------------------------

create procedure PHOTO.WA.dav_browse(
  in sid varchar,
  in path varchar)
  returns SOAP_gallery
{

  declare dirlist any ;
  declare auth_uid,auth_pwd,current_gallery varchar;
  declare home_dir,_col_perms,_col_user_name varchar;
  declare current_user photo_user;
  declare params any;
  declare result SOAP_album array;
  declare album SOAP_album;
  declare visibility,_col_id,_col_owner,is_own integer;

  album := new SOAP_album();
  result := vector();


  auth_uid := PHOTO.WA._session_user(vector('realm','wa','sid',sid),current_user);

  --  path := get_dav_gallery(path);
  --}

  current_gallery := path;
  -- TODO - da se proveri roliata na user-a za tozi instance(viewr gleda, writer - pishe)
  _col_id := DAV_SEARCH_ID(path,'C');
  if(_col_id < 0){
    signal('E0001','Path is not valid');
  };
  SELECT COL_PERMS,COL_OWNER,U_NAME
    INTO _col_perms,_col_owner,_col_user_name
    FROM  WS.WS.SYS_DAV_COL
          LEFT JOIN WS.WS.SYS_DAV_USER ON U_ID = COL_OWNER
   WHERE COL_ID = _col_id;

  --select WAM_MEMBER_TYPE from DB.DBA.WA_MEMBER WHERE WAM_USER = current_user.user_id AND WAM_INST =
  if(_col_owner = current_user.user_id){  --substring(_col_perms,7,1) = '1'){
    is_own := 1;
  }else{
    is_own := 0;
  }

  dirlist := DAV_DIR_LIST (current_gallery , 0 , current_user.auth_uid , current_user.auth_pwd );

  if(__tag(dirlist) = 189){
    return result;
  }

  declare ctr integer;
  declare pub_date,description any;
  ctr := 0;
  while (ctr < length(dirlist))
  {
    if(dirlist[ctr][6] = 0){
      dirlist[ctr][6] := 0;
    }

    if((dirlist[ctr][7] = current_user.user_id or substring(dirlist[ctr][5],7,1) = '1') and dirlist[ctr][10] <> '.thumbnails'){

      if(substring(dirlist[ctr][5],7,1) = '1'){
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
      album.thumb_id := (select RES_ID from WS.WS.SYS_DAV_RES where RES_COL = dirlist[ctr][4]);

      pub_date := DAV_PROP_GET(album.fullpath,'pub_date',current_user.auth_uid,current_user.auth_pwd);
      if(__tag(pub_date ) <> 189){
        album.pub_date := cast(pub_date  as datetime);
      }

      description := DAV_PROP_GET(album.fullpath,'description',current_user.auth_uid,current_user.auth_pwd);
      if(__tag(description) <> 189){
        album.description := cast(description  as varchar);
      }
      --album.description := DAV_PROP_GET(album.fullpath,'description');

      result := vector_concat(result,vector(album));
    }
    ctr := ctr + 1;
  }
  return SOAP_gallery(cast(is_own as integer),_col_user_name,result);
}
;


--------------------------------------------------------------------------------

create procedure PHOTO.WA.create_new_album(
  in sid varchar,
  in home_path varchar,
  in name varchar,
  in visibility integer,
  in pub_date datetime,
  in description varchar
  )
  returns SOAP_album
  {

  declare current_user photo_user;
  declare auth_uid,rights varchar;
  declare result SOAP_album;
  declare col_id interger;
  declare current_instance photo_instance;

  auth_uid := PHOTO.WA._session_user(vector('realm','wa','sid',sid),current_user);

  if(auth_uid = ''){
    return vector();
  }

  if(visibility = 1){
    rights := '110100100R';
  }else{
    rights := '110000000R';
  }

  col_id := PHOTO.WA.DAV_COL_CREATE(current_user, concat(home_path,name,'/'),rights);

  if(col_id > 0){

    DAV_PROP_SET(DAV_SEARCH_PATH (col_id,'C'),'pub_date',cast(pub_date as varchar),current_user.auth_uid,current_user.auth_pwd);
    DAV_PROP_SET(DAV_SEARCH_PATH (col_id,'C'),'description',description,current_user.auth_uid,current_user.auth_pwd);

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
                             cast(pub_date as datetime),
                             description
                            );

  }else{
    result := new SOAP_album(cast(col_id as integer),name);

  }

  return result;
}
;

--------------------------------------------------------------------------------
create procedure PHOTO.WA.edit_album(
  in sid varchar,
  in home_path varchar,
  in old_name varchar,
  in new_name varchar,
  in visibility integer,
  in pub_date datetime,
  in description varchar
  )
  returns SOAP_album
  {

  declare current_user photo_user;
  declare auth_uid,rights varchar;
  declare result SOAP_album;

  auth_uid := PHOTO.WA._session_user(vector('realm','wa','sid',sid),current_user);

  if(auth_uid = ''){
    return vector();
  }

  if(visibility = 1){
    rights := '110100100R';
  }else{
    rights := '110000000R';
    visibility := 0;
  }

  declare col_id interger;

  if(old_name <> new_name){
    col_id := PHOTO.WA.DAV_MOVE(current_user, concat(home_path,old_name,'/'),concat(home_path,new_name,'/'));
  }else{
    col_id := DAV_SEARCH_ID(concat(home_path,old_name,'/'),'C');
  }
dbg_obj_print('>>',col_id);
  if(col_id > 0){
    declare res any;
    DAV_PROP_REMOVE(DAV_SEARCH_PATH (col_id,'C'),'pub_date',current_user.auth_uid,current_user.auth_pwd);
    DAV_PROP_REMOVE(DAV_SEARCH_PATH (col_id,'C'),'description',current_user.auth_uid,current_user.auth_pwd);
    res := DAV_PROP_SET(DAV_SEARCH_PATH (col_id,'C'),'pub_date',cast(pub_date as varchar),current_user.auth_uid,current_user.auth_pwd);
    res := DAV_PROP_SET(DAV_SEARCH_PATH (col_id,'C'),'description',description,current_user.auth_uid,current_user.auth_pwd);

    res := DAV_PROP_SET(DAV_SEARCH_PATH (col_id,'C'),':virtpermissions',rights,current_user.auth_uid,current_user.auth_pwd);

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
                             pub_date,
                             description
                            );
  }else{
    result := new SOAP_album(cast(col_id as integer),new_name);

  }

  return result;
}
;


--------------------------------------------------------------------------------
create procedure PHOTO.WA.dav_upload(
  in params any,
  in current_user photo_user)
  returns integer
{
  declare i,image_cnt integer;

  i := 1;
  image_cnt := 0;
  while(i <= 20){
    if(get_keyword (concat('my_image_',cast(i as varchar)), params,'') <> ''){
      PHOTO.WA.dav_upload_file(params,current_user,i);
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
  in image_index integer)
  returns integer
{
  declare path,album,home_path varchar;
  declare image,image_attrs,image_fname,image_name,image_type any;
  declare new_id integer;
  declare replace_image,visibility,rights,description varchar;

  image_index := cast(image_index as varchar);

  album       := get_keyword ('album', params, '', 1);
  image       := get_keyword (concat('my_image_',image_index), params, '', 1);
  image_attrs := get_keyword_ucase (concat('attr-my_image_',image_index), params);
  image_fname := trim(get_keyword_ucase ('filename', image_attrs));
  replace_image := get_keyword(concat('replace_image_',image_index), params, '', 1);
  visibility  := get_keyword('visibility',params,1);
  description := get_keyword(concat('description_',image_index),params,'');

  image_name  := substring(image_fname,PHOTO.WA._locate_last('\\',image_fname)+1,length(image_fname));
  image_type  := get_keyword_ucase ('Content-Type', image_attrs);
  home_path   := get_keyword_ucase ('home_path', params);

  if(replace_image <> ''){
    image_name := replace_image;
  }

  if(visibility = '1'){
    rights := '110100100R';
  }else{
    rights := '110000000R';
    visibility := '0';
  }

  path := concat(home_path,album,'/',image_name);

  new_id := DAV_RES_UPLOAD(path,
                           image,
                           image_type ,
                           rights,
                           current_user.user_id,
                           current_user.user_id,
                           current_user.auth_uid,
                           current_user.auth_pwd);


  if(new_id > 0){
    DAV_PROP_REMOVE(DAV_SEARCH_PATH (new_id,'R'),'description',current_user.auth_uid,current_user.auth_pwd);
    DAV_PROP_SET(DAV_SEARCH_PATH (new_id,'R'),'description',cast(description as varchar),current_user.auth_uid,current_user.auth_pwd);

    return new_id;

  }else{
    return null;
  }
}
;

--------------------------------------------------------------------------------
create procedure PHOTO.WA.dav_delete(
  in sid varchar,
  in mode varchar,
  in ids integer array
)
returns  integer array
{
  declare path varchar;
  declare i,result integer;
  declare res integer;
  declare auth_uid varchar;
  declare current_user photo_user;
  declare id integer;
  declare res_ids any;

  auth_uid := PHOTO.WA._session_user(vector('realm','wa','sid',sid),current_user);

  if(auth_uid = ''){
    return vector();
  }
  i := 0;
  res_ids := vector();

  while(i < length(ids)){

    if(mode = 'r'){
      path := DAV_SEARCH_PATH(ids[i],'R');
    }else{
      path := DAV_SEARCH_PATH(ids[i],'C');
    };

    if(cast(path as varchar) <> ''){
      result := DAV_DELETE( path,
                            null,
                            current_user.auth_uid,
                            current_user.auth_pwd);

      if(result > 0){
        res_ids := vector_concat(res_ids,vector(ids[i]));
        -- TODO: Da trie i thumbcheta
      }

    }
    i := i + 1;
  }
  return res_ids;
}
;

--------------------------------------------------------------------------------
create procedure PHOTO.WA.get_image(
  in sid varchar,
  in _res_id integer)
  returns SOAP_album
{
  declare _owner_id,path,_res_mod_time,_path,_res_perms,visibility,_res_group,_res_owner,_res_cr_time,_res_type,_res_name,visibility,description,auth_uid any;
  declare current_user photo_user;

  auth_uid := PHOTO.WA._session_user(vector('realm','wa','sid',sid),current_user);

  select RES_OWNER,RES_MOD_TIME,RES_PERMS,RES_GROUP,RES_OWNER,RES_CR_TIME,RES_TYPE,RES_NAME,RES_FULL_PATH
    into _owner_id,_res_mod_time,_res_perms,_res_group,_res_owner,_res_cr_time,_res_type,_res_name,_path
    from WS.WS.SYS_DAV_RES
    where RES_ID = _res_id;


  if(substring(_res_perms,7,1) = '1'){
    visibility := 1; -- public
  }else{
    visibility := 0; -- private
  }

  description := DAV_PROP_GET(_path,'description',current_user.auth_uid,current_user.auth_pwd);
  if(__tag(description) <> 189){
    description := cast(description  as varchar);
  }else{
    description := '';
  }

  return new SOAP_album(_path,'R',0,_res_mod_time,_res_id,visibility,_res_group,_res_owner,_res_cr_time,_res_type,_res_name,now(),description);
}
;

--------------------------------------------------------------------------------
create procedure PHOTO.WA.edit_image(
  in sid varchar,
  in path varchar,
  in old_name varchar,
  in new_name varchar,
  in description varchar,
  in visibility integer
  )
  returns SOAP_album
  {

  declare current_user photo_user;
  declare auth_uid,rights varchar;
  declare result SOAP_album;
  declare res integer;

  auth_uid := PHOTO.WA._session_user(vector('realm','wa','sid',sid),current_user);

  if(auth_uid = ''){
    return 0;
  }

  if(visibility = 1){
    rights := '110100100R';
  }else{
    rights := '110000000R';
  }
  declare col_id interger;

  if(old_name <> new_name){
    col_id := DAV_MOVE(concat(path,old_name),concat(path,new_name),1,current_user.auth_uid,current_user.auth_pwd);
  }
  col_id := DAV_SEARCH_ID(concat(path,new_name),'R');


  if(col_id > 0){

    DAV_PROP_REMOVE(DAV_SEARCH_PATH (col_id,'R'),'description',current_user.auth_uid,current_user.auth_pwd);
    DAV_PROP_SET(DAV_SEARCH_PATH (col_id,'R'),'description',description,current_user.auth_uid,current_user.auth_pwd);
    DAV_PROP_SET(DAV_SEARCH_PATH (col_id,'R'),':virtpermissions',rights,current_user.auth_uid,current_user.auth_pwd);

    return new SOAP_album(path,cast(col_id as integer),visibility,'',new_name,description);

  }else{
    result := 0;
  }

  return result;
}
;

--------------------------------------------------------------------------------
create procedure PHOTO.WA.dav_share(
  in sid varchar,
  in mode varchar,
  in ids integer array
)
returns  integer array
{
  declare path varchar;
  declare i,result integer;
  declare res integer;
  declare auth_uid varchar;
  declare current_user photo_user;
  declare id integer;
  declare res_ids any;

  auth_uid := PHOTO.WA._session_user(vector('realm','wa','sid',sid),current_user);

  if(auth_uid = ''){
    return vector();
  }
  i := 0;
  res_ids := vector();

  while(i < length(ids)){

    if(mode = 'r'){
      path := DAV_SEARCH_PATH(ids[i],'R');
    }else{
      path := DAV_SEARCH_PATH(ids[i],'C');
    };

    if(cast(path as varchar) <> ''){
      result := DAV_DELETE( path,
                            null,
                            current_user.auth_uid,
                            current_user.auth_pwd);

      if(result > 0){
        res_ids := vector_concat(res_ids,vector(ids[i]));
        -- TODO: Da trie i thumbcheta
      }
    }
    i := i + 1;
  }
  return res_ids;
}
;

  PHOTO.WA._exec_no_error('grant execute on PHOTO.WA.dav_browse TO SOAPGallery');
  PHOTO.WA._exec_no_error('grant execute on PHOTO.WA.create_new_album TO SOAPGallery');
  PHOTO.WA._exec_no_error('grant execute on PHOTO.WA.edit_album TO SOAPGallery');
  PHOTO.WA._exec_no_error('grant execute on PHOTO.WA.edit_image TO SOAPGallery');
  PHOTO.WA._exec_no_error('grant execute on PHOTO.WA.dav_delete TO SOAPGallery');
  PHOTO.WA._exec_no_error('grant execute on PHOTO.WA.get_image TO SOAPGallery');
