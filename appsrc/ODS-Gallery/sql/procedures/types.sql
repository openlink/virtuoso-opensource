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

PHOTO.WA._exec_no_error('drop type DB.DBA.photo_user');
PHOTO.WA._exec_no_error('drop type DB.DBA.photo_comment');
PHOTO.WA._exec_no_error('drop type DB.DBA.photo_exif');
PHOTO.WA._exec_no_error('drop type DB.DBA.SOAP_album');
PHOTO.WA._exec_no_error('drop type DB.DBA.SOAP_external_album');
PHOTO.WA._exec_no_error('drop type DB.DBA.image_ids');
PHOTO.WA._exec_no_error('drop type DB.DBA.SOAP_gallery');
PHOTO.WA._exec_no_error('drop type DB.DBA.photo_instance');

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
  realm       varchar,
  ses_vars    any
  )
  constructor method photo_user(auth_uid varchar),
  constructor method photo_user(user_id integer),
  method photo_user_init(auth_uid varchar) returns any
;

--------------------------------------------------------------------------------
create constructor method photo_user(
  in auth_uid varchar
  )
  for photo_user
{
  self.photo_user_init(auth_uid);
  return;
}
;

--------------------------------------------------------------------------------
create constructor method photo_user(
  in user_id integer
  )
  for photo_user
{
  self.photo_user_init((SELECT U_NAME FROM DB.DBA.SYS_USERS WHERE U_ID = user_id));
  return;
}
;

--------------------------------------------------------------------------------
create method photo_user_init (
  in auth_uid varchar
  )
  for photo_user
{
  declare user_data,result any;

  if (auth_uid <> 'nobody')
  {
    PHOTO.WA._user_data(auth_uid,user_data);
    self.auth_uid := auth_uid;
    self.auth_pwd := user_data[1];

    self.home_dir := DAV_HOME_DIR(auth_uid);
    if (self.home_dir = -19)
    {
      result := DAV_MAKE_DIR (concat('/DAV/home/',auth_uid,'/'), user_data[3], null, '110100100R');
      self.home_dir := DAV_SEARCH_PATH (result,'C');
    }
    self.gallery_dir := concat(self.home_dir,PHOTO.WA.get_gallery_folder_name(),'/');
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

create procedure PHOTO.WA.get_gallery_folder_name()
{
  return 'Gallery';  
}
;

--------------------------------------------------------------------------------
create type SOAP_gallery as(
  is_own integer,
  owner_name varchar,
  albums SOAP_album array,
  settings any array
) __soap_type 'services.wsdl:dav_gallery'
constructor method SOAP_gallery(is_own integer,owner_name varchar,albums any,settings any array)
;


--------------------------------------------------------------------------------
create constructor method SOAP_gallery(
  in is_own integer,
  in owner_name varchar,
  in albums any,
  in settings any array
)
for SOAP_gallery
{
  self.is_own := is_own;
  self.albums := albums;
  self.settings   := settings;
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
  obsolete integer,
  visibility integer,
  group_id integer,
  owner_id integer,
  created datetime,
  mime_type varchar,
  name varchar,
--  pub_date datetime,
  start_date datetime,
  end_date datetime,
  description varchar,
  private_tags varchar array,
  public_tags varchar array,
  geolocation varchar array,
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
--pub_date datetime,
  start_date datetime,
  end_date datetime,
  description varchar
),
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
--  pub_date datetime,
  start_date datetime,
  end_date datetime,
  description varchar,
  geolocation varchar array,
  obsolete integer

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
-- in pub_date datetime,
 in start_date datetime,
 in end_date datetime,
 in description varchar
 ) for SOAP_album
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
--  self.pub_date     := pub_date;
  self.start_date   := start_date;
  self.end_date     := end_date;
  self.description  := description;
  self.obsolete     := 0;

 }
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
-- in pub_date datetime,
 in start_date datetime,
 in end_date datetime,
 in description varchar,
 in geolocation varchar array,
 in obsolete integer
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
--  self.pub_date     := pub_date;
  self.start_date   := start_date;
  self.end_date     := end_date;
  self.description  := description;
  self.geolocation  := geolocation;
  self.obsolete     := obsolete;

 }
;

--------------------------------------------------------------------------------
create constructor method SOAP_album(
 in id integer,
 in name varchar
)
for SOAP_album
{
  self.id   := id;
  self.name := name;
  self.obsolete := 0;


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
  self.obsolete     := 0;

 }
;

--------------------------------------------------------------------------------
create type SOAP_external_album as (
  source varchar,
  type varchar,
  id integer,
  visibility integer,
  owner_id varchar,
  mime_type varchar,
  name varchar,
  private_tags varchar array,
  public_tags varchar array,
  secret varchar,
  server varchar,
  farm varchar
);


--------------------------------------------------------------------------------
create type image_ids as (
  image_id integer)
;

--------------------------------------------------------------------------------
create type photo_comment as (
  comment_id integer,
  res_id integer,
  create_date datetime,
  modify_date datetime,
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
  ) for photo_exif
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
  owner_id    integer,
  gallery_id  integer,
  owner_name  varchar,
  description varchar
)
  constructor method photo_instance(),
  constructor method photo_instance(home_url varchar),
  method photo_instance_create(home_url varchar) returns any
 ;


--------------------------------------------------------------------------------
create constructor method photo_instance()
for photo_instance
{
  declare home_url,url_last_part varchar;
  declare home_url_arr any;
  
  home_url:=http_path();
  home_url_arr:=split_and_decode(http_path(),0,'\0\0/');
  url_last_part:=home_url_arr[length(home_url_arr)-1];

  if(url_last_part<>'' and locate('.',url_last_part))
     home_url:=subseq(home_url,0,length(home_url)-length(url_last_part));

  self.photo_instance_create(home_url);
}
;

--------------------------------------------------------------------------------
create constructor method photo_instance(in home_url varchar)
for photo_instance
{
  self.photo_instance_create(home_url);
}
;

--------------------------------------------------------------------------------
create method photo_instance_create(in _home_url varchar)
for photo_instance
{

  declare _home_path,_name,_owner_name,_description varchar;
  declare _owner_id,_i,_gallery_id integer;
  declare path,_wai_id any;

  declare continue handler for NOT FOUND {
    _wai_id := (SELECT VH_INST FROM WA_VIRTUAL_HOSTS WHERE CONCAT(VH_LPATH,'/') = _home_url);
    if(_wai_id is null){
      PHOTO.WA.http_404();
      return;  
    }
    SELECT OWNER_ID,HOME_PATH,PHOTO.WA.SYS_INFO.WAI_NAME,GALLERY_ID,U_NAME,WAI_DESCRIPTION
      INTO _owner_id,_home_path,_name,_gallery_id,_owner_name,_description
      FROM PHOTO.WA.SYS_INFO
      JOIN DB.DBA.SYS_USERS ON U_ID = OWNER_ID
      JOIN WA_INSTANCE WAI ON WAI.WAI_NAME = PHOTO.WA.SYS_INFO.WAI_NAME
     WHERE WAI_ID = _wai_id;
  };

  if(strstr(_home_url,'index.vspx')){
      _home_url := substring(_home_url,1,strstr(_home_url,'index.vspx'));
  };

  path := PHOTO.WA.utl_parse_url(_home_url);

  SELECT OWNER_ID,HOME_PATH,PHOTO.WA.SYS_INFO.WAI_NAME,GALLERY_ID,U_NAME,WAI_DESCRIPTION
    INTO _owner_id,_home_path,_name,_gallery_id,_owner_name,_description
    FROM PHOTO.WA.SYS_INFO
    JOIN DB.DBA.SYS_USERS ON U_ID = OWNER_ID
    JOIN WA_INSTANCE WAI ON WAI.WAI_NAME = PHOTO.WA.SYS_INFO.WAI_NAME
   WHERE CONCAT(HOME_URL,'/') = _home_url;

  self.name      := _name;
  self.home_path := _home_path;
  self.home_url  := _home_url;
  self.owner_id  := _owner_id;
  self.gallery_id   := _gallery_id;
  self.owner_name   := _owner_name;
  self.description  := _description;
}
;
