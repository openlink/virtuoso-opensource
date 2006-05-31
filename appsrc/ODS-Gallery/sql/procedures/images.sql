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


create procedure PHOTO.WA.get_thumbnail(
  in sid varchar,
  in image_id varchar,
  in size     integer)
{

  declare _content,_parent_id,image_name,thumb_id any;
  declare _mime,_path,rights varchar;
  declare sizes any;
  declare current_user photo_user;
  declare owner_id integer;
  declare live integer;

  live := 0;

  PHOTO.WA._session_user(vector('realm','wa','sid',sid),current_user);

  sizes := PHOTO.WA.image_sizes();

  if(size = 0){
    -- Get small image 60x50
    select RES_COL,RES_NAME,RES_OWNER,RES_PERMS into _parent_id,image_name,owner_id,rights from WS.WS.SYS_DAV_RES where RES_ID= image_id;

    if(not(owner_id = current_user.user_id or substring(rights,7,1) = '1')){
      --dbg_obj_print('no permission');
      return '';
    }

    _path := DAV_SEARCH_PATH(_parent_id,'C');

    thumb_id := DAV_SEARCH_ID(concat(_path,'.thumbnails/',image_name),'R');

    if(thumb_id > 0 and live = 0){
      -- we have a cache image and will use it
  --dbg_obj_print('cache');

      select blob_to_string (RES_CONTENT), RES_TYPE into _content, _mime from WS.WS.SYS_DAV_RES where RES_ID= thumb_id;
      return _content;

    }else{
      -- we don't have cache image and will create it
  --dbg_obj_print('live');

      return PHOTO.WA.make_thumbnail(current_user,image_id,0);
    }
  }else{
    -- Get big image 500x370
    --dbg_obj_print('big');
  declare sizes_org,sizes_new,sizes,new_id any;
  declare   ratio,max_width,max_height,org_width,org_height,new_width,new_height any;

  sizes_new := PHOTO.WA.image_sizes();
  sizes_new := sizes_new[size];
  sizes_org := PHOTO.WA.get_image_sizes(image_id);

  max_width := cast(sizes_new[0] as real);
  max_height:= cast(sizes_new[1] as real);
  org_width := cast(sizes_org[0] as real);
  org_height := cast(sizes_org[1] as real);


    sizes := PHOTO.WA.image_ration(max_width,max_height,org_width,org_height);

    select blob_to_string (RES_CONTENT), RES_TYPE into _content, _mime from WS.WS.SYS_DAV_RES where RES_ID= image_id;

    return "IM ThumbnailImageBlob" (_content, length(_content), sizes[0], sizes[1],1);
  }

}
;
--------------------------------------------------------------------------------
create procedure PHOTO.WA.image_sizes(){
  return vector(vector(100,70),vector(500,370));
}
;

--------------------------------------------------------------------------------
create procedure PHOTO.WA.make_thumbnail(
  in current_user photo_user,
  in image_id integer,
  in size     integer)
{

  declare _content,_parent_id,image any;
  declare _mime,image_name,path varchar;
  declare image,path,result any;
  declare sizes_org,sizes_new,sizes,new_id any;
  declare   ratio,max_width,max_height,org_width,org_height,new_width,new_height any;

  sizes_new := PHOTO.WA.image_sizes();
  sizes_new := sizes_new[size];
  sizes_org := PHOTO.WA.get_image_sizes(image_id);

  max_width := cast(sizes_new[0] as real);
  max_height:= cast(sizes_new[1] as real);
  org_width := cast(sizes_org[0] as real);
  org_height := cast(sizes_org[1] as real);

  sizes := PHOTO.WA.image_ration(max_width,max_height,org_width,org_height);


  select blob_to_string (RES_CONTENT), RES_TYPE,RES_COL,RES_NAME into _content, _mime,_parent_id,image_name from WS.WS.SYS_DAV_RES where RES_ID= image_id;

  path := DAV_SEARCH_PATH(_parent_id,'C');

  result := DAV_SEARCH_ID(concat(path,'.thumbnails/'),'C');

  if(result = -1){
    -- check for existing thumbnails folder
    result := PHOTO.WA.DAV_SUBCOL_CREATE(current_user,concat(path,'.thumbnails'));
    --dbg_obj_print('make dir for thumb:',result);
  }
  -- params: content, length of content, number of columns, number of rows
  image := "IM ThumbnailImageBlob" (_content, length(_content), sizes[0], sizes[1],1);


  path := concat(path,'.thumbnails/',image_name);

  new_id := DAV_RES_UPLOAD(path,
                          image,
                          _mime,
                          '110100100R',
                          current_user.user_id,
                          current_user.user_id,
                          current_user.auth_uid,
                          current_user.auth_pwd);
  --dbg_obj_print('thumb OK:',new_id);
  return image;

}
;


--------------------------------------------------------------------------------
create procedure PHOTO.WA.image_ration(
 in max_width real,
 in max_height real,
 in org_width real,
 in org_height real)
{

  declare ratio,new_width,new_height any;

  if( org_width > max_width ){
    ratio := (max_width / org_width); --(real)
  }else{
    ratio := 1 ;
  }
  new_width := cast((org_width * ratio) as integer); --(int)
  new_height := cast((org_height * ratio) as integer); --(int)

  if( new_height > max_height ){
    ratio := (max_height / new_height); --(real)
  }else{
    ratio := 1 ;
  }

  new_width := cast((new_width * ratio) as integer); --(int)
  new_height := cast((new_height * ratio) as integer); --(int)

  return vector(new_width,new_height);
}
;
--------------------------------------------------------------------------------
--
create procedure PHOTO.WA.get_attributes(
  in sid varchar,
  in image_id varchar)
returns photo_exif array
{

  declare _content any;
  declare _mime varchar;
  declare result any;

  select blob_to_string (RES_CONTENT), RES_TYPE into _content, _mime from WS.WS.SYS_DAV_RES where RES_ID= image_id;

  declare attributes,res any;
  declare ind integer;
  declare exif photo_exif;

  ind := 0;
  result := vector();

  attributes := vector('Make','Model','Orientation','XResolution','YResolution','Software','Datetime','Exposuretime');

  while(ind < length(attributes)){
    res := "IM GetImageBlobAttribute" (_content, length(_content), concat('EXIF:',attributes[ind]));
    exif := photo_exif(attributes[ind],res);

    result := vector_concat(result,vector(exif));
    --dbg_obj_print(attributes[ind],':',res);

    ind := ind + 1;
  }
  -- params: content, length of content, number of columns, number of rows
  return result;
}
;

--------------------------------------------------------------------------------
--
create procedure PHOTO.WA.get_image_sizes(
  in image_id varchar)
{

  declare _content any;
  declare _mime varchar;
  declare width,height integer;

  select blob_to_string (RES_CONTENT), RES_TYPE into _content, _mime from WS.WS.SYS_DAV_RES where RES_ID= image_id;

  -- params: content, length of content, number of columns, number of rows
  width := "IM GetImageBlobWidth" (_content, length(_content));
  height := "IM GetImageBlobHeight" (_content, length(_content));

  return vector(width,height);
}
;


PHOTO.WA._exec_no_error('grant execute on PHOTO.WA.get_attributes TO SOAPGallery');

