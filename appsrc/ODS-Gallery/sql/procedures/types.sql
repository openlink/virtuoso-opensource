PHOTO.WA._exec_no_error('drop type photo_user');
PHOTO.WA._exec_no_error('drop type photo_comment');
PHOTO.WA._exec_no_error('drop type photo_exif');
PHOTO.WA._exec_no_error('drop type SOAP_album');
PHOTO.WA._exec_no_error('drop type image_ids');
PHOTO.WA._exec_no_error('drop type SOAP_gallery');
PHOTO.WA._exec_no_error('drop type photo_instance');


--------------------------------------------------------------------------------
create type photo_user as (
  auth_uid    varchar,
  auth_pwd    varchar,
  home_dir    varchar,
  gallery_dir varchar,
  user_id     integer,
  first_name  varchar,
  last_name   varchar,
  full_name   varchar,
  sid         varchar,
  realm       varchar
  )
  constructor method photo_user(auth_uid varchar),
  constructor method photo_user(auth_uid integer)
;


--------------------------------------------------------------------------------
--
create constructor method photo_user(
  in auth_uid varchar)
  for photo_user
{
  declare user_data,result any;

  if(auth_uid <> 'nobody'){
    PHOTO.WA._user_data(auth_uid,user_data);
    self.auth_uid := auth_uid;
    self.auth_pwd := user_data[1];

    self.home_dir := DAV_HOME_DIR(auth_uid);

    if(self.home_dir = -19){
      result := DAV_MAKE_DIR (concat('/DAV/home/',auth_uid,'/'), user_data[3], null, '110100100R');
      self.home_dir := DAV_SEARCH_PATH (result,'C');
    };

    self.gallery_dir := concat(self.home_dir,'gallery/');
    self.user_id    := user_data[3];
    self.full_name  := user_data[2];
    self.first_name  := user_data[4];
    self.last_name  := user_data[5];
  }else{
    self.gallery_dir := '';
    self.user_id    := -1;
    self.full_name  := 'Anonymous';
    self.first_name := 'Anonymous';
    self.last_name  := 'Anonymous';
  }
  return;
}
;

--------------------------------------------------------------------------------
--
create constructor method photo_user(
  in user_id integer)
  for photo_user
{

  declare auth_uid varchar;

  auth_uid := (SELECT U_NAME FROM DB.DBA.SYS_USERS WHERE U_ID = user_id);

  self.auth_uid := auth_uid;
  self.auth_pwd := PHOTO.WA._user_pwd(auth_uid);
  if(auth_uid = 'dav'){
    self.home_dir := '/DAV/';
  }else{
    self.home_dir := DAV_HOME_DIR(auth_uid);
  }

  if(__tag(self.home_dir) <> 189){
    self.gallery_dir := concat(self.home_dir,'gallery/');
  }else{
    self.gallery_dir := '';
  }
  self.user_id := user_id;
  return;
}
;


--------------------------------------------------------------------------------
create type SOAP_gallery as(
  is_own integer,
  owner_name varchar,
  albums SOAP_album array

) __soap_type 'services.wsdl:dav_gallery'
constructor method SOAP_gallery(is_own integer,owner_name varchar,albums any)
;


--------------------------------------------------------------------------------
create constructor method SOAP_gallery(
  in is_own integer,
  in owner_name varchar,
  in albums any)
for SOAP_gallery
{
  self.is_own := is_own;
  self.albums := albums;
  self.owner_name := owner_name;
}
;
--------------------------------------------------------------------------------
create type SOAP_album as (
  fullpath varchar,
  type varchar,
  length integer,
  modification datetime,
  id integer,
  visibility integer,
  group_id integer,
  owner_id integer,
  created datetime,
  mime_type varchar,
  name varchar,
  pub_date datetime,
  description varchar,
  thumb_id integer
) __soap_type 'services.wsdl:dav_album'

constructor method SOAP_album(col_id integer,name varchar),
constructor method SOAP_album(
  fullpath varchar,
  type varchar,
  length integer,
  modification datetime,
  id integer,
  visibility integer,
  group_id integer,
  owner_id integer,
  created datetime,
  mime_type varchar,
  name varchar,
  pub_date datetime,
  description varchar
),
constructor method SOAP_album(
  fullpath varchar,
  id integer,
  visibility integer,
  mime_type varchar,
  name varchar,
  description varchar
)
;

--------------------------------------------------------------------------------
--
create constructor method SOAP_album(
 in fullpath varchar,
 in type varchar,
 in length integer,
 in modification datetime,
 in id integer,
 in visibility integer,
 in group_id integer,
 in owner_id integer,
 in created datetime,
 in mime_type varchar,
 in name varchar,
 in pub_date datetime,
 in description varchar

)
for SOAP_album
{
  self.fullpath     := fullpath;
  self.type         := type;
  self.length       := length;
  self.modification := modification;
  self.id           := id;
  self.visibility   :=  visibility;
  self.group_id     := group_id;
  self.owner_id     := owner_id;
  self.created      := created;
  self.mime_type    := mime_type;
  self.name         := name;
  self.pub_date     := pub_date;
  self.description  := description;
 }
;

--------------------------------------------------------------------------------
--
create constructor method SOAP_album(
 in id integer,
 in name varchar
)
for SOAP_album
{
  self.id   := id;
  self.name := name;

}
;

--------------------------------------------------------------------------------
--
create constructor method SOAP_album(
 in fullpath varchar,
 in id integer,
 in visibility integer,
 in mime_type varchar,
 in name varchar,
 in description varchar

)
for SOAP_album
{
  self.fullpath     := fullpath;
  self.id           := id;
  self.visibility   :=  visibility;
  self.mime_type    := mime_type;
  self.name         := name;
  self.description  := description;
 }
;


--------------------------------------------------------------------------------

create type image_ids as (
  image_id integer
  )
;

--------------------------------------------------------------------------------
--

create type photo_comment as (
  comment_id integer,
  res_id integer,
  create_date datetime,
  user_id integer,
  text varchar,
  user_name varchar
  )
  constructor method photo_comment(comment_id integer,
                                   res_id integer,
                                   create_date datetime,
                                   user_id integer,
                                   text varchar,
                                   user_name varchar)
;

--------------------------------------------------------------------------------
create constructor method photo_comment(
 in comment_id integer,
 in res_id integer,
 in create_date datetime,
 in user_id integer,
 in text varchar,
 in user_name varchar
)
for photo_comment
{
  self.comment_id := comment_id;
  self.res_id := res_id;
  self.create_date := create_date;
  self.user_id := user_id;
  self.text:= text;
  self.user_name := user_name;
  return;
}
;

--------------------------------------------------------------------------------
create type photo_exif as (
  name varchar,
  value varchar
  )
  constructor method photo_exif(name varchar,value varchar)
;

--------------------------------------------------------------------------------
create constructor method photo_exif(
  in name varchar,
  in value varchar
)
for photo_exif
{
  self.name := name;
  self.value := value;
}
;

--------------------------------------------------------------------------------
create type photo_instance as (
  name      varchar,
  home_path varchar,
  home_url  varchar,
  owner_id  integer
)
  constructor method photo_instance();

--------------------------------------------------------------------------------
create constructor method photo_instance()
for photo_instance
{

  declare exit handler for NOT FOUND {
    return null;
  };

  declare _home_path,_name,_home_url varchar;
  declare _owner_id,_i integer;
  declare path any;

  path := PHOTO.WA.utl_parse_url(http_path());

  _home_url := '/';
  while(_i < length(path)){
    if(isnull(strstr(path[_i],'.'))){
      _home_url := concat(_home_url,path[_i],'/');
    }
    _i := _i + 1;
  }

  if(strstr(_home_url,'index.vspx')){
      _home_url := substring(_home_url,1,strstr(_home_url,'index.vspx'));
  };

  SELECT OWNER_ID,HOME_PATH,WAI_NAME
    INTO _owner_id,_home_path,_name
    FROM PHOTO.WA.SYS_INFO
   WHERE CONCAT(HOME_URL,'/') = _home_url;

  self.name      := _name;
  self.home_path := _home_path;
  self.home_url  := _home_url;
  self.owner_id  := _owner_id;
}
;


--------------------------------------------------------------------------------
  PHOTO.WA._exec_no_error('grant execute on image_ids TO SOAPGallery');
  PHOTO.WA._exec_no_error('grant execute on photo_exif TO SOAPGallery');
  PHOTO.WA._exec_no_error('grant execute on photo_comment TO SOAPGallery');
  PHOTO.WA._exec_no_error('grant execute on SOAP_album TO SOAPGallery');
  PHOTO.WA._exec_no_error('grant execute on SOAP_gallery TO SOAPGallery');
