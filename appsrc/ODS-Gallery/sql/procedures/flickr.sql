create procedure PHOTO.WA.flickr_sign(
  inout params any)
{
  declare secret,api_key,sign_txt,i,sign_arr,url any;

  if(isstring(params)){
    params := split_and_decode(params,0);
  }
  secret := PHOTO.WA.flickr_get_secret();
  api_key := PHOTO.WA.flickr_get_api_key();
  sign_arr := vector();
  params := vector_concat(vector('api_key',api_key),params);
  url := '';
  i:=0;
  while(i < length(params)){
    sign_arr := vector_concat(sign_arr,vector(concat(params[i],cast(params[i+1] as varchar))));
    url:= concat(url,params[i],'=',cast(params[i+1] as varchar),'&');
    i:=i+2;
  }
  sign_arr := __vector_sort(sign_arr);
  i:=0;
  sign_txt:=secret;
  while(i < length(sign_arr)){
    sign_txt := concat(sign_txt ,sign_arr[i]);
    i:=i+1;
  }
  sign_txt := md5(sign_txt);
  params := vector_concat(params,vector('api_sig',sign_txt));
  return concat(url,'api_sig=',sign_txt);
};

create procedure PHOTO.WA.flickr_get_secret(){
  return '510eb3a4c9552544';
};

create procedure PHOTO.WA.flickr_get_api_key(){
  return '90da220fa380ffca0256a9b3869a8445';
};

create procedure PHOTO.WA.flickr_get_login_url(){
  return 'http://flickr.com/services/auth/?';
};


create procedure PHOTO.WA.get_proxy(){
  return null;
  --return '127.0.0.1:8888';
};


create procedure PHOTO.WA.flickr_execure(
  in params varchar){
  declare data,body,error_num,error_msg any;
  body := PHOTO.WA.flickr_sign(params);
  data := http_get ('http://api.flickr.com/services/rest/',NULL, 'POST', '', body,PHOTO.WA.get_proxy());
  data := xml_tree_doc(data);

  if(not isnull(xpath_eval('rsp[@stat="fail"]',data))){
    error_num := cast(xpath_eval('rsp/err/@code',data) as varchar);
    error_msg := cast(xpath_eval('rsp/err/@msg',data) as varchar);
    signal(concat('FLICR-',error_num),concat('Flicker Service Error: ',error_msg));
  }
  return data;
};


create procedure PHOTO.WA.flickr_upload(
  in params varchar,
  in content any)
{
  declare page,body,boundary,i,headers,boundary_head any;

  PHOTO.WA.flickr_sign(params);
  boundary_head:= concat('a----',substring(md5(cast(now() as varchar)),1,12));
  boundary := concat('--',boundary_head);

  body := string_output();
  while(i < length(params)){
    PHOTO.WA.make_post(body,boundary,params[i],params[i+1]);
    i:=i+2;
  }
  PHOTO.WA.make_post(body,boundary,'photo',content,'; filename="az"\r\nContent-Type: image/jpeg');
  http(concat(boundary,'--'),body);

  body := string_output_string(body);

  headers := concat('Content-Type: multipart/form-data; boundary=',boundary_head,'\r\nPragma: no-cache');
  page := http_get ('http://www.flickr.com/services/upload/',NULL, 'POST', headers, body,PHOTO.WA.get_proxy());
  page := xml_tree_doc(page);
  return page;
};

create procedure PHOTO.WA.make_post(
  inout stream any,
  in boundary varchar,
  in param_name varchar,
  in param_value varchar,
  in param_extra  varchar := '')
{

  http(boundary,stream);
  http('\r\n',stream);
  http(sprintf('Content-Disposition: form-data; name="%s"%s',param_name,param_extra),stream);
  http('\r\n\r\n',stream);
  http(param_value ,stream);
  http('\r\n',stream);
};


create procedure PHOTO.WA.flickr_method_getFrob(){
  declare data any;
  data := PHOTO.WA.flickr_execure('method=flickr.auth.getFrob');
  data := xpath_eval('rsp/frob',data);
  data := cast(data as varchar);
  return data;
};


create procedure PHOTO.WA.flickr_method_getToken (
  in frob varchar
){
  declare data,token,user_data,result any;
  data := PHOTO.WA.flickr_execure(vector('method','flickr.auth.getToken','frob',frob));
  user_data := xpath_eval('rsp/auth/user/@nsid',data);
  token := xpath_eval('rsp/auth/token',data);

  result := vector(cast(token as varchar),cast(user_data as varchar));
  return result;
};

create procedure PHOTO.WA.flickr_save_token(
  in current_user photo_user,
  in data any
){
  PHOTO.WA._session_var_set(current_user,'gallery_flickr_token',data[0]);
  PHOTO.WA._session_var_set(current_user,'gallery_flickr_user',data[1]);
  PHOTO.WA._session_var_unset(current_user,'gallery_flickr_frob');
  PHOTO.WA._session_var_save(current_user);
};

create procedure PHOTO.WA.flickr_method_photos_getInfo(
  in photo_id varchar,
  in secret varchar
){
  declare data any;
  data := PHOTO.WA.flickr_execure(vector('method','flickr.photos.getInfo','photo_id',photo_id,'secret',secret));
  data := xpath_eval('rsp/photo',data);
  return data;
};


create procedure PHOTO.WA.flickr_method_photos_getSizes(
  in photo_id varchar
){
  declare data any;
  data := PHOTO.WA.flickr_execure(vector('method','flickr.photos.getSizes','photo_id',photo_id));
  data := xpath_eval('rsp/sizes',data);
  return data;
};


create procedure PHOTO.WA.flickr_method_auth_checkToken(
  in token varchar
){
  declare data,user_data any;
  data := PHOTO.WA.flickr_execure(vector('method','flickr.auth.checkToken','auth_token',token));
  user_data := xpath_eval('rsp/auth/user/@nsid',data);
  token := xpath_eval('rsp/auth/token',data);
  return vector(token,user_data);
};


create procedure PHOTO.WA.flickr_method_photos_addTags(
  in token varchar,
  in photo_id varchar,
  in tags varchar
){
  declare data any;
  data := PHOTO.WA.flickr_execure(vector('method','flickr.photos.addTags','auth_token',token,'photo_id',photo_id,'tags',tags));
  data := xpath_eval('rsp/photo',data);
  return data;
};

create procedure PHOTO.WA.flickr_method_search(
  in user_id varchar
){
  declare data any;
  data := PHOTO.WA.flickr_execure(vector('method','flickr.photos.search','user_id',user_id));
  data := xpath_eval('rsp/photos/photo',data,0);
  return data;
};


create procedure PHOTO.WA.flickr_session(
  in current_user photo_user,
  inout token_data any
){

  declare token,frob any;
  token := PHOTO.WA._session_var_get(current_user,'gallery_flickr_token');
  if(isnull(token)){
    frob := PHOTO.WA._session_var_get(current_user,'gallery_flickr_frob');
    if(isnull(frob)){
      signal('Error','Missing FROB');
    }
    token_data := PHOTO.WA.flickr_method_getToken(frob);
    PHOTO.WA.flickr_save_token(current_user,token_data);
    token := token_data[0];
  }else{
    token_data := PHOTO.WA.flickr_method_auth_checkToken(token);
  }

  return token;
};



-- ==================================================================================
create procedure PHOTO.WA.flickr_login_link(
  in sid varchar)
  returns string array
{
  declare frob,params,url,result,current_user any;

  if(not PHOTO.WA._session_user(vector('realm','wa','sid',sid),current_user)){
    return vector();
  }
  frob := PHOTO.WA.flickr_method_getFrob();
  params := PHOTO.WA.flickr_sign(vector('frob',frob,'perms','delete'));
  url := PHOTO.WA.flickr_get_login_url();
  result := vector(concat(url,params));

  PHOTO.WA._session_var_set(current_user,'gallery_flickr_frob',frob);
frob := PHOTO.WA._session_var_get(current_user,'gallery_flickr_frob');
  
  PHOTO.WA._session_var_unset(current_user,'gallery_flickr_token');
  PHOTO.WA._session_var_unset(current_user,'gallery_flickr_user');
  PHOTO.WA._session_var_save(current_user);
  return result;
};

-- ==================================================================================
create procedure PHOTO.WA.flickr_add_tags(
  in sid varchar,
  in photo_id varchar,
  in tags varchar)
  returns string array
{
  declare data,current_user,token,frob,token_data any;

  if(not PHOTO.WA._session_user(vector('realm','wa','sid',sid),current_user)){
    return vector();
  }
  token := PHOTO.WA._session_var_get(current_user,'gallery_flickr_token');
  if(isnull(token)){
    frob := PHOTO.WA._session_var_get(current_user,'gallery_flickr_frob');
    if(isnull(frob)){
      signal('Error','Missing FROB');
    }
    token_data := PHOTO.WA.flickr_method_getToken(frob);
    PHOTO.WA.flickr_save_token(current_user,token_data);
    token := token_data[0];
  }

  data := PHOTO.WA.flickr_method_photos_addTags(token,photo_id,tags);

  return data;
};

-- ==================================================================================
create procedure PHOTO.WA.flickr_get_photos_list(
  in sid varchar
  )
  returns SOAP_external_album array
{
  declare _photo SOAP_external_album;
  declare data,i,token_data any;
  declare result SOAP_external_album array;
  declare current_user photo_user;

  if(not PHOTO.WA._session_user(vector('realm','wa','sid',sid),current_user)){
    return vector();
  }

  PHOTO.WA.flickr_session(current_user,token_data);
  data := PHOTO.WA.flickr_method_search(token_data[1]);
  result := vector();
  _photo := new SOAP_external_album();
  i:= 0;
  while(i < length(data)){
    _photo.id :=  cast(xpath_eval('@id',data[i]) as integer);
    _photo.type := 'R';
    _photo.visibility := cast(xpath_eval('@ispublic',data[i]) as integer);
    _photo.owner_id := cast(xpath_eval('@owner',data[i]) as varchar);
    _photo.mime_type := 'image/jpeg';
    _photo.name := cast(xpath_eval('@title',data[i]) as varchar);
    _photo.private_tags := vector();
    _photo.public_tags := vector();
    _photo.secret := cast(xpath_eval('@secret',data[i]) as varchar);
    _photo.server := cast(xpath_eval('@server',data[i]) as varchar);
    _photo.farm   := cast(xpath_eval('@farm',data[i]) as varchar);
    _photo.source := sprintf('http://static.flickr.com/%s/%i_%s_t.jpg',_photo.server,_photo.id,_photo.secret);

    result := vector_concat(result,vector(_photo));

    i:=i+1;
  }
  return result;
};


create procedure PHOTO.WA.flickr_save_photos(
  in sid varchar,
  in current_album integer,
  in ids varchar array
){
  declare path varchar;
  declare i,result integer;
  declare res,data,new_id,hasLarge integer;
  declare auth_uid,image_type,rights,current_album_path,farm_no varchar;
  declare current_user photo_user;
  declare id integer;
  declare res_ids,url,image any;
  declare originalformat,originalsecret,server,title,description,visibility,tags,size_data any;

  auth_uid := PHOTO.WA._session_user(vector('realm','wa','sid',sid),current_user);

  if(auth_uid = ''){
    return vector();
  }
  i := 0;
  res_ids := vector();
  current_album_path := DAV_SEARCH_PATH(current_album,'C');

  while(i < length(ids)){

      res := split_and_decode(cast(ids[i] as varchar),0,'\0\0_');

      size_data:=PHOTO.WA.flickr_method_photos_getSizes(res[0]);

      hasLarge:=0;
      hasLarge:=xpath_eval('size/@label="Large"',size_data);

      data := PHOTO.WA.flickr_method_photos_getInfo(res[0],res[1]);

      originalsecret :=  coalesce (cast(xpath_eval('@originalsecret',data) as varchar), '');
      originalformat :=  coalesce (cast(xpath_eval('@originalformat',data) as varchar), 'jpg');
      farm_no := cast(xpath_eval('@farm',data) as varchar);
      server := cast(xpath_eval('@server',data) as varchar);
      title :=  cast(xpath_eval('title',data) as varchar);
      description :=  cast(xpath_eval('description',data) as varchar);
      visibility :=  cast(xpath_eval('visibility',data) as varchar);
      tags :=  cast(xpath_eval('tags',data) as varchar);


      if(length(originalsecret))
        url := sprintf('http://farm%s.static.flickr.com/%s/%s_%s_o.%s',farm_no,server,res[0],originalsecret,originalformat);
      else{
        if(hasLarge)
        {
           url := cast(xpath_eval('size[@label="Large"]/@source',size_data) as varchar);
           declare url_parts any;
           url_parts:=split_and_decode(url,0,'\0\0.');
           originalformat:=url_parts[length(url_parts)-1];
        }else
           url := sprintf('http://farm%s.static.flickr.com/%s/%s_%s.%s',farm_no,server,res[0],res[1],originalformat);
      }
    
      image := http_get(url,NULL, 'GET',NULL,NULL,PHOTO.WA.get_proxy());
      image_type := concat('image/',originalformat);
      rights := '110100100R';

      path:= concat(current_album_path ,title,'.',originalformat);

      new_id := DAV_RES_UPLOAD(path,
                               image,
                               image_type ,
                               rights,
                               current_user.user_id,
                               current_user.user_id,
                               current_user.auth_uid,
                               current_user.auth_pwd);

    i := i + 1;
  }
  return;
};


create procedure PHOTO.WA.flickr_send_photos(
  in sid varchar,
  in ids integer array
)
returns  integer array
{
  declare path varchar;
  declare i,result integer;
  declare res integer;
  declare auth_uid,title,description,tags,data,token_data,token,frob varchar;
  declare current_user photo_user;
  declare id integer;
  declare res_ids,_content,_mime,new_id any;

  if(not PHOTO.WA._session_user(vector('realm','wa','sid',sid),current_user)){
    return vector();
  }

  token := PHOTO.WA.flickr_session(current_user,token_data);

  i := 0;
  res_ids := vector();
  if(not isarray(ids)){
    ids := vector(ids);
  }
  while(i < length(ids)){
    path := DAV_SEARCH_PATH(ids[i],'R');
    if(cast(path as varchar) <> ''){
      select blob_to_string (RES_CONTENT), RES_TYPE,RES_NAME
        into _content, _mime,title
        from WS.WS.SYS_DAV_RES
       where RES_ID=ids[i]
         and RES_OWNER = current_user.user_id;
      description := DAV_PROP_GET(path,'description',current_user.auth_uid,current_user.auth_pwd);
      if(__tag(description) <> 189){
        description := cast(description  as varchar);
      }else{
        description := '';
      }
      tags := DAV_PROP_GET(path,':virtprivatetags',current_user.auth_uid,current_user.auth_pwd);
      if(not isnull(tags)){
        tags := cast(tags as varchar);
      }else{
        tags := '';
      }

      data := PHOTO.WA.flickr_upload(vector('auth_token',token,'title',title,'description',description,'tags',tags,'is_public','1','is_friend','0','is_family','0'),_content);
      --data := PHOTO.WA.flickr_upload(vector('auth_token',token),_content);
      new_id := cast(xpath_eval('rsp/photoid',data) as integer);
      res_ids := vector_concat(res_ids,vector(new_id));
    }
    i := i + 1;
  }
  return res_ids;
}
;
