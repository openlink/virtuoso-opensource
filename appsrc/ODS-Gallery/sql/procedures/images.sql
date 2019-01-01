--
--  $Id$
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2019 OpenLink Software
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
  in size     integer,
  out image_type varchar)
{

  declare _content,_parent_id,image_name,thumb_id any;
  declare _mime,_path,rights varchar;
  declare sizes any;
  declare current_user photo_user;
  declare owner_id integer;
  declare live integer;

  live := 0;
  image_type := '';

  PHOTO.WA._session_user(vector('realm','wa','sid',sid),current_user);

  sizes := PHOTO.WA.image_sizes();

  if(size = 0){
    -- Get small image 60x50
    select RES_COL,RES_NAME,RES_OWNER,RES_PERMS,RES_TYPE into _parent_id,image_name,owner_id,rights,image_type from WS.WS.SYS_DAV_RES where RES_ID= image_id;

    if(not(owner_id = current_user.user_id or substring(rights,7,1) = '1')){
      return '';
    }

    _path := DAV_SEARCH_PATH(_parent_id,'C');

    thumb_id := DAV_SEARCH_ID(concat(_path,'.thumbnails/',image_name),'R');

    if(thumb_id > 0 and live = 0){
      -- we have a cache image and will use it

      select blob_to_string (RES_CONTENT), RES_TYPE into _content, _mime from WS.WS.SYS_DAV_RES where RES_ID= thumb_id;
      return _content;

    }else{
      -- we don't have cache image and will create it

      return PHOTO.WA.make_thumbnail(current_user,image_id,0);
    }
  }else{
    -- Get big image 500x370
  declare sizes_org,sizes_new,sizes,new_id any;
    declare ratio,max_width,max_height,org_width,org_height,new_width,new_height,image any;

  sizes_new := PHOTO.WA.image_sizes();
  sizes_new := sizes_new[size];
  sizes_org := PHOTO.WA.get_image_sizes(image_id);

  max_width := cast(sizes_new[0] as real);
  max_height:= cast(sizes_new[1] as real);
  org_width := cast(sizes_org[0] as real);
  org_height := cast(sizes_org[1] as real);

    sizes := PHOTO.WA.image_ration(max_width,max_height,org_width,org_height);

    select blob_to_string (RES_CONTENT), RES_TYPE into _content,image_type from WS.WS.SYS_DAV_RES where RES_ID= image_id;

    declare exit handler for sqlstate '*'{image := _content;
                                          goto _skip_thumbnail;     
                                         };
    image := "IM ThumbnailImageBlob" (_content, length(_content), sizes[0], sizes[1],1);

_skip_thumbnail:;

    return image;
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

  select blob_to_string (RES_CONTENT), RES_TYPE,RES_COL,RES_NAME 
    into _content, _mime,_parent_id,image_name 
    from WS.WS.SYS_DAV_RES 
   where RES_ID= image_id;

  if(length(_content) = 0){
    return;  
  }

  sizes_new := PHOTO.WA.image_sizes();
  sizes_new := sizes_new[size];
  sizes_org := PHOTO.WA.get_image_sizes(image_id);

  max_width := cast(sizes_new[0] as real);
  max_height:= cast(sizes_new[1] as real);
  org_width := cast(sizes_org[0] as real);
  org_height := cast(sizes_org[1] as real);

  sizes := PHOTO.WA.image_ration(max_width,max_height,org_width,org_height);



  path := DAV_SEARCH_PATH(_parent_id,'C');

  result := DAV_SEARCH_ID(concat(path,'.thumbnails/'),'C');

  if(result = -1){
    -- check for existing thumbnails folder
    result := PHOTO.WA.DAV_SUBCOL_CREATE(current_user,concat(path,'.thumbnails'));
  }
  
  declare exit handler for sqlstate '*'{image := _content;
                                        goto _skip_thumbnail;     
                                       };
  -- params: content, length of content, number of columns, number of rows
  image := "IM ThumbnailImageBlob" (_content, length(_content), sizes[0], sizes[1],1);

_skip_thumbnail:;

  path := concat(path,'.thumbnails/',image_name);

  new_id := DAV_RES_UPLOAD(path,
                          image,
                          _mime,
                          '110100100R',
                          current_user.user_id,
                          current_user.user_id,
                          current_user.auth_uid,
                          current_user.auth_pwd);
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
  in p_gallery_id integer,
  in image_id varchar)
returns photo_exif array
{

  declare result_out,data,result any;
  result_out := vector();

  declare res any;
  declare exif photo_exif;
  declare ind integer;

  if (not PHOTO.WA.get_meta_data(image_id,result))
  {
    PHOTO.WA.save_meta_data_web(image_id,result);
  }
  ind := 0;
  while (ind < length(result))
  {
    if(length (result[ind]) and length (result[ind+1]))
    {
      exif := photo_exif(result[ind],result[ind+1]);
      result_out := vector_concat(result_out,vector(exif));
    }
    ind := ind + 2;
  }
  return result_out;
}
;

--------------------------------------------------------------------------------
create procedure PHOTO.WA.extact_meta(
  inout _content any,
  out result_values photo_exif array)
{
  declare res, attributes,parts,rowche,name,value any;
  declare ind integer;
  declare exif photo_exif;

  ind := 0;
  attributes := PHOTO.WA.get_meta_data_list();
  result_values := vector();

  declare exit handler for sqlstate '*'
  {
    res:=vector();
                                        goto _skip_im_action;     
                                       };

  res := "IM GetImageBlobIdentify" (_content, length(_content));
  res := split_and_decode(res,1,'\0\0\n');

_skip_im_action:;     

  while(ind < length(res))
  {
    rowche := res[ind];
    parts := split_and_decode(rowche,1,'\0\0:');
    if(isarray(parts) and length(parts) = 2)
    {
      name := replace(parts[0],' ','');
      value := trim(parts[1]);
      value := rtrim(value,'.');

      if(position(name,attributes) and not position(name,result_values))
      {
        result_values := vector_concat(result_values,vector(name,value));
      }
    }
    ind := ind + 1;
  }
}
;

--------------------------------------------------------------------------------
create procedure PHOTO.WA.get_meta_data_list(){
  declare attributes any;
  --attributes := vector('Make','Model','Orientation','XResolution','YResolution','Software','Datetime','Exposuretime');
  --attributes := vector('exifdata','tag_number','tagid','datatype','length','width','height','resolution','meter','mm','seconds','date','subseconds','geo','exifAttribute','dateAndOrTime','gpsInfo','ifdPointer','imageConfig','imageDataCharacter','imageDataStruct','interopInfo','pictTaking','pimInfo','recOffset','relatedFile','userInfo','versionInfo','imageWidth','imageLength','bitsPerSample','compression','photometricInterpretation','imageDescription','make','model','stripOffsets','orientation','samplesPerPixel','rowsPerStrip','stripByteCounts','xResolution','yResolution','planarConfiguration','resolutionUnit','transferFunction','software','dateTime','artist','whitePoint','primaryChromaticities','jpegInterchangeFormat','jpegInterchangeFormatLength','yCbCrCoefficients','yCbCrSubSampling','yCbCrPositioning','referenceBlackWhite','copyright','exif_IFD_Pointer','gpsInfo_IFD_Pointer','exposureTime','fNumber','exposureProgram','spectralSensitivity','isoSpeedRatings','oecf','exifVersion','dateTimeOriginal','dateTimeDigitized','componentsConfiguration','compressedBitsPerPixel','shutterSpeedValue','apertureValue','brightnessValue','exposureBiasValue','maxApertureValue','subjectDistance','meteringMode','lightSource','flash','focalLength','subjectArea','makerNote','userComment','subSecTime','subSecTimeOriginal','subSecTimeDigitized','flashpixVersion','colorSpace','pixelXDimension','pixelYDimension','relatedSoundFile','interoperability_IFD_Pointer','flashEnergy','spatialFrequencyResponse','focalPlaneXResolution','focalPlaneYResolution','focalPlaneResolutionUnit','subjectLocation','exposureIndex','sensingMethod','fileSource','sceneType','cfaPattern','customRendered','exposureMode','whiteBalance','digitalZoomRatio','focalLengthIn35mmFilm','sceneCaptureType','gainControl','contrast','saturation','sharpness','deviceSettingDescription','subjectDistanceRange','imageUniqueID','gpsVersionID','gpsLatitudeRef','gpsLatitude','gpsLongitudeRef','gpsLongitude','gpsAltitudeRef','gpsAltitude','gpsTimeStamp','gpsSatellites','gpsStatus','gpsMeasureMode','gpsDOP','gpsSpeedRef','gpsSpeed','gpsTrackRef','gpsTrack','gpsImgDirectionRef','gpsImgDirection','gpsMapDatum','gpsDestLatitudeRef','gpsDestLatitude','gpsDestLongitudeRef','gpsDestLongitude','gpsDestBearingRef','gpsDestBearing','gpsDestDistanceRef','gpsDestDistance','gpsProcessingMethod','gpsAreaInformation','gpsDateStamp','gpsDifferential','interoperabilityIndex','interoperabilityVersion','relatedImageFileFormat','relatedImageWidth','relatedImageLength','printImageMatching_IFD_Pointer','pimContrast','pimBrightness','pimColorBalance','pimSaturation','pimSharpness');
  attributes := vector('datatype','gpsInfo','imageWidth','imageLength','bitsPerSample','compression','photometricInterpretation','imageDescription','make','model','stripOffsets','orientation','samplesPerPixel','rowsPerStrip','stripByteCounts','xResolution','yResolution','planarConfiguration','resolutionUnit','transferFunction','software','dateTime','artist','whitePoint','primaryChromaticities','jpegInterchangeFormat','jpegInterchangeFormatLength','yCbCrCoefficients','yCbCrSubSampling','yCbCrPositioning','referenceBlackWhite','copyright','exposureTime','fNumber','exposureProgram','spectralSensitivity','isoSpeedRatings','exifVersion','dateTimeOriginal','dateTimeDigitized','componentsConfiguration','compressedBitsPerPixel','shutterSpeedValue','apertureValue','brightnessValue','exposureBiasValue','maxApertureValue','subjectDistance','meteringMode','lightSource','flash','focalLength','subjectArea','makerNote','userComment','subSecTime','subSecTimeOriginal','subSecTimeDigitized','flashpixVersion','colorSpace','relatedSoundFile','flashEnergy','spatialFrequencyResponse','focalPlaneXResolution','focalPlaneYResolution','focalPlaneResolutionUnit','subjectLocation','exposureIndex','sensingMethod','fileSource','sceneType','cfaPattern','customRendered','exposureMode','whiteBalance','digitalZoomRatio','focalLengthIn35mmFilm','sceneCaptureType','gainControl','contrast','saturation','sharpness','subjectDistanceRange','imageUniqueID','interoperabilityIndex','interoperabilityVersion','relatedImageFileFormat','relatedImageWidth','relatedImageLength');
  attributes := vector('DATATYPE','GPSINFO','IMAGEWIDTH','IMAGELENGTH','BITSPERSAMPLE','COMPRESSION','PHOTOMETRICINTERPRETATION','IMAGEDESCRIPTION','MAKE','MODEL','STRIPOFFSETS','ORIENTATION','SAMPLESPERPIXEL','ROWSPERSTRIP','STRIPBYTECOUNTS','XRESOLUTION','YRESOLUTION','PLANARCONFIGURATION','RESOLUTIONUNIT','TRANSFERFUNCTION','SOFTWARE','DATETIME','ARTIST','WHITEPOINT','PRIMARYCHROMATICITIES','JPEGINTERCHANGEFORMAT','JPEGINTERCHANGEFORMATLENGTH','YCBCRCOEFFICIENTS','YCBCRSUBSAMPLING','YCBCRPOSITIONING','REFERENCEBLACKWHITE','COPYRIGHT','EXPOSURETIME','FNUMBER','EXPOSUREPROGRAM','SPECTRALSENSITIVITY','ISOSPEEDRATINGS','EXIFVERSION','DATETIMEORIGINAL','DATETIMEDIGITIZED','COMPONENTSCONFIGURATION','COMPRESSEDBITSPERPIXEL','SHUTTERSPEEDVALUE','APERTUREVALUE','BRIGHTNESSVALUE','EXPOSUREBIASVALUE','MAXAPERTUREVALUE','SUBJECTDISTANCE','METERINGMODE','LIGHTSOURCE','FLASH','FOCALLENGTH','SUBJECTAREA','MAKERNOTE','USERCOMMENT','SUBSECTIME','SUBSECTIMEORIGINAL','SUBSECTIMEDIGITIZED','FLASHPIXVERSION','COLORSPACE','RELATEDSOUNDFILE','FLASHENERGY','SPATIALFREQUENCYRESPONSE','FOCALPLANEXRESOLUTION','FOCALPLANEYRESOLUTION','FOCALPLANERESOLUTIONUNIT','SUBJECTLOCATION','EXPOSUREINDEX','SENSINGMETHOD','FILESOURCE','SCENETYPE','CFAPATTERN','CUSTOMRENDERED','EXPOSUREMODE','WHITEBALANCE','DIGITALZOOMRATIO','FOCALLENGTHIN35MMFILM','SCENECAPTURETYPE','GAINCONTROL','CONTRAST','SATURATION','SHARPNESS','SUBJECTDISTANCERANGE','IMAGEUNIQUEID','INTEROPERABILITYINDEX','INTEROPERABILITYVERSION','RELATEDIMAGEFILEFORMAT','RELATEDIMAGEWIDTH','RELATEDIMAGELENGTH');

  --attributes := vector('Make','Model');

  return attributes;  
};

--------------------------------------------------------------------------------
create procedure PHOTO.WA.save_meta_data_general(
  in _res_id integer,
  inout _content any,
  out result photo_exif array
  ){
  declare _values,_sql,attributes,ind,_state,message any;
 
  PHOTO.WA.extact_meta(_content,result);

  --DELETE FROM PHOTO.WA.EXIF_DATA WHERE RES_ID = _res_id;
  while(ind < length(result)){
    if(result[ind] <> ''){
      INSERT REPLACING PHOTO.WA.EXIF_DATA (RES_ID,EXIF_PROP,EXIF_VALUE) VALUES(_res_id,result[ind],result[ind+1]);
    }
    ind := ind + 2;
  }
  return; 
};

--------------------------------------------------------------------------------
create procedure PHOTO.WA.save_meta_data_trigger(
  in _res_id integer,
  inout _content any
){
  declare result any;  
  _content := blob_to_string(_content);
  if(length(_content) = 0){
    return;  
  }  
  PHOTO.WA.save_meta_data_general(_res_id,_content,result);
}
;

--------------------------------------------------------------------------------
create procedure PHOTO.WA.save_meta_data_web(
  in _res_id integer,
  out result any)
{
  declare _content any;
  select blob_to_string (RES_CONTENT) into _content from WS.WS.SYS_DAV_RES where RES_ID= _res_id;
  PHOTO.WA.save_meta_data_general(_res_id,_content,result);
}
;

--------------------------------------------------------------------------------
create procedure PHOTO.WA.get_meta_data(
  in _res_id integer,
  out result photo_exif array
  ){
  declare ind,_state,message,rows,attributes any;
  declare res any;
  
  attributes := PHOTO.WA.get_meta_data_list();
  result := vector();
  if((SELECT COUNT(EXIF_VALUE) FROM PHOTO.WA.EXIF_DATA WHERE RES_ID = _res_id) = 0){
    return 0;  
  }
  
  while(ind < length(attributes)){
    res := (SELECT EXIF_VALUE FROM PHOTO.WA.EXIF_DATA WHERE RES_ID = _res_id AND EXIF_PROP = attributes[ind]);
    result := vector_concat(result,vector(attributes[ind],res));
    ind := ind + 1;
  }
  return 1;
};


--------------------------------------------------------------------------------
--
create procedure PHOTO.WA.get_image_sizes(
  in image_id varchar)
{

  declare _content any;
  declare width,height integer;

  declare exit handler for sqlstate '*' {
    return vector(0,0);
  };
  
  select blob_to_string (RES_CONTENT) into _content from WS.WS.SYS_DAV_RES where RES_ID= image_id;

  -- params: content, length of content, number of columns, number of rows
  width := "IM GetImageBlobWidth" (_content, length(_content));
  height := "IM GetImageBlobHeight" (_content, length(_content));

  return vector(width,height);
}
;

create procedure PHOTO.WA.fill_exif_data(){
  declare old_version,limit_version any;
  old_version := registry_get ('_oGallery_old_version_');
  old_version := cast(concat('1',replace(old_version,'.','')) as integer);
  limit_version := 10355;
  if(old_version >= limit_version){
    return;  
  }
  declare _col_id,_res_id integer;
  for(select HOME_PATH from PHOTO.WA.SYS_INFO)
  do{
    _col_id := DAV_SEARCH_ID(HOME_PATH,'C');
    for(select COL_ID,COL_NAME 
          from WS.WS.SYS_DAV_COL 
         where COL_PARENT = _col_id 
           and regexp_match('^\\.',COL_NAME) IS NULL)
    do{

      for(select RES_ID,RES_CONTENT,RES_NAME
            from WS.WS.SYS_DAV_RES 
           where RES_COL = COL_ID 
             and regexp_match('^\\.',RES_NAME) IS NULL 
             and regexp_match('^image',RES_TYPE) IS NOT NULL 
         )
      do{
        _res_id := RES_ID;
        if((SELECT COUNT(EXIF_VALUE) FROM PHOTO.WA.EXIF_DATA WHERE RES_ID = _res_id) = 0){
          PHOTO.WA.save_meta_data_trigger(RES_ID,RES_CONTENT); 
        }
      }  
    }
  }   
}
;

--------------------------------------------------------------------------------
create procedure PHOTO.WA.get_img_name (
  in _res_id integer)
{
  declare path varchar;
  declare parts any;

  path := DB.DBA.DAV_SEARCH_PATH (_res_id, 'R');
  if (isstring (path))
  {
    parts := split_and_decode (path, 0, '\0\0/');
    return parts[length (parts)-1];
  }
  return '';
}
;

--------------------------------------------------------------------------------
create procedure PHOTO.WA.get_image_name (
  in _res_id integer)
{
  declare path varchar;
  declare parts any;

  path := DB.DBA.DAV_SEARCH_PATH (_res_id, 'R');
  if (isstring (path))
  {
    parts := split_and_decode (path, 0, '\0\0/');
    return parts[length (parts)-2] || '.' || parts[length (parts)-1];
  }
  return '';
}
;
--------------------------------------------------------------------------------
create procedure PHOTO.WA.get_image_caption (
  in _res_id integer)
{
  declare _path, _description varchar;

  _path := DB.DBA.DAV_SEARCH_PATH (_res_id, 'R');
  if (isstring (_path))
  {
    declare _dav_auth, _dav_pwd varchar;
    PHOTO.WA.get_dav_auth (_dav_auth, _dav_pwd);
    _description := trim (cast (DAV_PROP_GET(_path, 'description', _dav_auth, _dav_pwd) as varchar));
    if ((_description = '-11') or (_description = ''))
      _description := PHOTO.WA.get_img_name (_res_id);
    return _description;
  }
  return 'no title';
}
;

