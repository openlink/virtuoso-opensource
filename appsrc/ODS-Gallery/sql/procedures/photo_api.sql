use ODS;

create procedure ODS.ODS_API."photo.album.new" (
    		in inst_id int,
    		in name varchar,
		in startdate datetime := null,
		in enddate datetime := null,
    		in description varchar,
		in visibility int := 1,
		in geolocation varchar := ''
		) __soap_http 'text/xml'
{
  declare uname varchar;
  declare rc int;
  declare res DB.DBA.SOAP_album;
  declare sid, path varchar;
  declare g_id int;

  declare exit handler for sqlstate '*' {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };
  if (not ods_check_auth (uname, inst_id, 'author'))
    return ods_auth_failed ();

  sid := get_ses (uname);
  declare exit handler for not found {
    return ods_serialize_int_res (-1, 'The home folder does not exists');
  };
  select p.HOME_PATH, p.GALLERY_ID into path, g_id from PHOTO.WA.SYS_INFO p, DB.DBA.WA_INSTANCE i where i.WAI_NAME = p.WAI_NAME and i.WAI_ID = inst_id;
  if (startdate is null)
    startdate := now ();
  if (enddate is null)
    enddate := now ();
  res := PHOTO.WA.create_new_album (sid, g_id, path, name, visibility, startdate, enddate, description, geolocation);
  if (not isarray (res))
    rc := res.id;
  else
    rc := -1;
  close_ses (sid);
  return ods_serialize_int_res (rc, 'Created');
}
;

create procedure ODS.ODS_API."photo.album.update" (
    		in inst_id int,
		in old_name varchar,
    		in new_name varchar,
		in startdate datetime := null,
		in enddate datetime := null,
    		in description varchar,
		in visibility int := 1,
		in geolocation varchar := '',
		in obsolete int := 0
    ) __soap_http 'text/xml'
{
  declare uname varchar;
  declare rc int;
  declare res DB.DBA.SOAP_album;
  declare sid, path varchar;
  declare g_id int;

  declare exit handler for sqlstate '*' {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };
  if (not ods_check_auth (uname, inst_id, 'author'))
    return ods_auth_failed ();

  sid := get_ses (uname);
  declare exit handler for not found {
    return ods_serialize_int_res (-1, 'The home folder does not exists');
  };
  select p.HOME_PATH, p.GALLERY_ID into path, g_id from PHOTO.WA.SYS_INFO p, DB.DBA.WA_INSTANCE i where i.WAI_NAME = p.WAI_NAME and i.WAI_ID = inst_id;
  if (startdate is null)
    startdate := now ();
  if (enddate is null)
    enddate := now ();

  res := PHOTO.WA.edit_album (sid, g_id, path, old_name, new_name, visibility, startdate, enddate, description, geolocation, obsolete);

  if (not isarray (res))
    rc := res.id;
  else
    rc := -1;
  close_ses (sid);
  return ods_serialize_int_res (rc, 'Created');
}
;

create procedure ODS.ODS_API."photo.album.delete" (in inst_id int, in name varchar) __soap_http 'text/xml'
{
  declare uname varchar;
  declare rc int;
  declare path varchar;
  declare g_id int;

  declare exit handler for sqlstate '*' {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };
  if (not ods_check_auth (uname, inst_id, 'author'))
    return ods_auth_failed ();

  declare exit handler for not found {
    return ods_serialize_int_res (-1, 'The home folder does not exists');
  };
  select p.HOME_PATH, p.GALLERY_ID into path, g_id from PHOTO.WA.SYS_INFO p, DB.DBA.WA_INSTANCE i where i.WAI_NAME = p.WAI_NAME and i.WAI_ID = inst_id;
  path := path || name || '/';
  rc := DB.DBA.DAV_DELETE_INT (path, 0, uname, null, 0);
  return ods_serialize_int_res (rc);
}
;

create procedure ODS.ODS_API."photo.album.set_thumbnail" (in inst_id int, in name varchar, in thumbnail_id int) __soap_http 'text/xml'
{
  ;
}
;

create procedure ODS.ODS_API."photo.album.set_options" (in inst_id int, in name varchar, in show_map int, in show_timeline int, in enable_discussion int, in init_discussion int, in settings any) __soap_http 'text/xml'
{
  declare uname varchar;
  declare rc int;
  declare res DB.DBA.SOAP_album;
  declare sid, path varchar;
  declare settings_array any;
  declare g_id int;

  declare exit handler for sqlstate '*' {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };
  if (not ods_check_auth (uname, inst_id, 'author'))
    return ods_auth_failed ();

  sid := get_ses (uname);
  declare exit handler for not found {
    return ods_serialize_int_res (-1, 'The home folder does not exists');
  };
  select p.HOME_PATH, p.GALLERY_ID into path, g_id from PHOTO.WA.SYS_INFO p, DB.DBA.WA_INSTANCE i where i.WAI_NAME = p.WAI_NAME and i.WAI_ID = inst_id;
  path := path || name;
  settings_array := split_and_decode (settings);
  res := PHOTO.WA.edit_album_settings (sid, g_id, path, show_map, show_timeline, enable_discussion, init_discussion, settings_array);

  if (res = 'true')
    rc := 1;
  else
    rc := -1;
  close_ses (sid);
  return ods_serialize_int_res (rc, 'Updated');
}
;

create procedure ODS.ODS_API."photo.image.add" (
    in inst_id int,
    in album varchar,
    in description varchar,
    in file_name varchar,
    in visibility int := 1
    )
__soap_http 'text/xml'
{
  declare uname varchar;
  declare rc int;
  declare path, permissions varchar;
  declare g_id, gid, uid int;
  declare image varbinary;

  image := http_body_read ();

  declare exit handler for sqlstate '*' {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };
  if (not ods_check_auth (uname, inst_id, 'author'))
    return ods_auth_failed ();

  if (not length (image))
    return ods_serialize_int_res (-1, 'Invalid image data');

  declare exit handler for not found {
    return ods_serialize_int_res (-1, 'The home folder does not exists');
  };

  if (__tag (image) = 185)
    image := string_output_string (image);
  "IM GetImageBlobFormat" (image, length (image));
  rc := -1;
  select p.HOME_PATH, p.GALLERY_ID into path, g_id from PHOTO.WA.SYS_INFO p, DB.DBA.WA_INSTANCE i where i.WAI_NAME = p.WAI_NAME and i.WAI_ID = inst_id;
  path := path || album || '/' || file_name;
  whenever not found goto ret;
  select U_ID, U_GROUP into uid, gid from DB.DBA.SYS_USERS where U_NAME = uname;
  if (visibility)
    permissions := '110100100RM';
  else
    permissions := '110100000RM';
  rc := DB.DBA.DAV_RES_UPLOAD_STRSES_INT (path, image, '', permissions, uid, gid, uname, null, 0, null, null, null, null, null, 1);
  if (rc > 0)
    DB.DBA.DAV_PROP_SET_INT (path, 'description', description, uname, null, 0, 1, 0);
ret:
  return ods_serialize_int_res (rc);
}
;

create procedure ODS.ODS_API."photo.image.delete" (in inst_id int, in album varchar, in file_name varchar) __soap_http 'text/xml'
{
  declare uname varchar;
  declare rc int;
  declare path varchar;
  declare g_id int;

  declare exit handler for sqlstate '*' {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };
  if (not ods_check_auth (uname, inst_id, 'author'))
    return ods_auth_failed ();

  declare exit handler for not found {
    return ods_serialize_int_res (-1, 'The home folder does not exists');
  };
  select p.HOME_PATH, p.GALLERY_ID into path, g_id from PHOTO.WA.SYS_INFO p, DB.DBA.WA_INSTANCE i where i.WAI_NAME = p.WAI_NAME and i.WAI_ID = inst_id;
  path := path || album || '/' || file_name;
  rc := DB.DBA.DAV_DELETE_INT (path, 0, uname, null, 0);
  return ods_serialize_int_res (rc);
}
;

create procedure ODS.ODS_API."photo.image.set_properties" (
    	in inst_id int,
	in album varchar,
	in old_name varchar,
	in new_name varchar,
	in description varchar,
	in visibility int := 1
	)
__soap_http 'text/xml'
{
  declare uname varchar;
  declare rc int;
  declare res DB.DBA.SOAP_album;
  declare sid, path varchar;
  declare g_id int;

  declare exit handler for sqlstate '*' {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };
  if (not ods_check_auth (uname, inst_id, 'author'))
    return ods_auth_failed ();

  sid := get_ses (uname);
  declare exit handler for not found {
    return ods_serialize_int_res (-1, 'The home folder does not exists');
  };
  select p.HOME_PATH, p.GALLERY_ID into path, g_id from PHOTO.WA.SYS_INFO p, DB.DBA.WA_INSTANCE i where i.WAI_NAME = p.WAI_NAME and i.WAI_ID = inst_id;
  path := path || album;
  res := PHOTO.WA.edit_image (sid, g_id, path, old_name, new_name, description, visibility);
  if (not isinteger (res))
    rc := res.id;
  else
    rc := -1;
  close_ses (sid);
  return ods_serialize_int_res (rc, 'Updated');
}
;

create procedure ODS.ODS_API."photo.image.get_properties" (in inst_id int, in album varchar, in file_name varchar) __soap_http 'text/xml'
{
  ;
}
;

create procedure ODS.ODS_API."photo.album.get" (in inst_id int, in album varchar) __soap_http 'text/xml'
{
  ;
}
;

create procedure ODS.ODS_API."photo.image.get" (in inst_id int, in album varchar, in file_name varchar) __soap_http 'text/xml'
{
  declare uname varchar;
  declare rc int;
  declare content, tp any;
  declare sid, path varchar;
  declare g_id int;

  declare exit handler for sqlstate '*' {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };
  if (not ods_check_auth (uname, inst_id, 'viewer'))
    return ods_auth_failed ();

  declare exit handler for not found {
    return ods_serialize_int_res (-1, 'The home folder does not exists');
  };
  select p.HOME_PATH, p.GALLERY_ID into path, g_id from PHOTO.WA.SYS_INFO p, DB.DBA.WA_INSTANCE i where i.WAI_NAME = p.WAI_NAME and i.WAI_ID = inst_id;
  path := path || album || '/' || file_name;
  rc := DB.DBA.DAV_RES_CONTENT_INT (DB.DBA.DAV_SEARCH_ID (path, 'R'), content, tp, 0, 0, uname, null);
  if (rc < 0)
    return ods_serialize_int_res (rc);
  else
    {
      http_header (sprintf ('Content-Type: %s\r\n', tp));
      http (content);
    }
  return '';
}
;

create procedure ODS.ODS_API."photo.album.import" (in inst_id int, in album varchar) __soap_http 'text/xml'
{
  ;
}
;

create procedure ODS.ODS_API."photo.album.export" (in inst_id int, in album varchar) __soap_http 'text/xml'
{
  ;
}
;

grant execute on ODS.ODS_API."photo.album.new" to ODS_API;
grant execute on ODS.ODS_API."photo.album.update" to ODS_API;
grant execute on ODS.ODS_API."photo.album.delete" to ODS_API;
grant execute on ODS.ODS_API."photo.album.set_thumbnail" to ODS_API;
grant execute on ODS.ODS_API."photo.album.set_options" to ODS_API;
grant execute on ODS.ODS_API."photo.image.add" to ODS_API;
grant execute on ODS.ODS_API."photo.image.delete" to ODS_API;
grant execute on ODS.ODS_API."photo.image.set_properties" to ODS_API;
grant execute on ODS.ODS_API."photo.image.get_properties" to ODS_API;
grant execute on ODS.ODS_API."photo.album.get" to ODS_API;
grant execute on ODS.ODS_API."photo.image.get" to ODS_API;
grant execute on ODS.ODS_API."photo.album.import" to ODS_API;
grant execute on ODS.ODS_API."photo.album.export" to ODS_API;

use DB;
