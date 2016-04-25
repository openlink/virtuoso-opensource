--
--  $Id$
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2016 OpenLink Software
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

use ODS;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API.photo_setting_xml (
  in settings any,
  in settingName varchar)
{
  return sprintf ('  <%s>%s</%s>\n', settingName, cast (get_keyword (settingName, settings) as varchar), settingName);
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API.photo_image_new (
  in inst_id integer,
  in album varchar,
  in name varchar,
  in description varchar := null,
  in visibility integer := 1,
  in image long varchar)
{
  declare uname varchar;
  declare rc integer;
  declare path, permissions varchar;
  declare g_id, gid, uid integer;

  declare exit handler for sqlstate '*'
  {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };
  if (not ods_check_auth (uname, inst_id, 'author'))
    return ods_auth_failed ();

  if (not length (image))
    return ods_serialize_int_res (-1, 'Invalid image data');

  declare exit handler for not found
  {
    return ods_serialize_int_res (-1, 'The home folder does not exists');
  };

  if (__tag (image) = 185)
    image := string_output_string (image);
  "IM GetImageBlobFormat" (image, length (image));
  rc := -1;
  select p.HOME_PATH, p.GALLERY_ID into path, g_id from PHOTO.WA.SYS_INFO p, DB.DBA.WA_INSTANCE i where i.WAI_NAME = p.WAI_NAME and i.WAI_ID = inst_id;
  path := path || album || '/' || name;
  whenever not found goto ret;
  select U_ID, U_GROUP into uid, gid from DB.DBA.SYS_USERS where U_NAME = uname;
  permissions :=  case when (visibility) then '110100100RM' else '110100000RM' end;
  rc := DB.DBA.DAV_RES_UPLOAD_STRSES_INT (path, image, '', permissions, uid, gid, uname, null, 0, null, null, null, null, null, 1);
  if ((rc > 0) and (description is not null))
    DB.DBA.DAV_PROP_SET_INT (path, 'description', description, uname, null, 0, 1, 0);
ret:
  return ods_serialize_int_res (rc);
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API."photo.album.new" (
  in inst_id integer,
    		in name varchar,
  in description varchar := null,
  in startDate datetime := null,
  in endDate datetime := null,
  in visibility integer := 1,
  in geoLocation varchar := '') __soap_http 'text/xml'
{
  declare uname varchar;
  declare rc integer;
  declare res DB.DBA.SOAP_album;
  declare sid, path varchar;
  declare g_id integer;

  declare exit handler for sqlstate '*'
  {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };
  if (not ods_check_auth (uname, inst_id, 'author'))
    return ods_auth_failed ();

  declare exit handler for not found
  {
    return ods_serialize_int_res (-1, 'The home folder does not exists');
  };
  select p.HOME_PATH, p.GALLERY_ID into path, g_id from PHOTO.WA.SYS_INFO p, DB.DBA.WA_INSTANCE i where i.WAI_NAME = p.WAI_NAME and i.WAI_ID = inst_id;
  if (startDate is null)
    startDate := now ();
  if (endDate is null)
    endDate := now ();
  sid := get_ses (uname);
  res := PHOTO.WA.create_new_album (sid, g_id, path, name, visibility, startDate, endDate, description, geolocation);
  close_ses (sid);
  rc := case when (not isarray (res)) then res.id else -1 end;
  return ods_serialize_int_res (rc, 'Created');
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API."photo.album.edit" (
  in inst_id integer,
  in name varchar,
  in new_name varchar := null,
  in description varchar := null,
  in startDate datetime := null,
  in endDate datetime := null,
  in visibility integer := 1,
		in geolocation varchar := '',
  in obsolete integer := 0) __soap_http 'text/xml'
{
  declare uname varchar;
  declare rc integer;
  declare res DB.DBA.SOAP_album;
  declare sid, path varchar;
  declare g_id integer;

  declare exit handler for sqlstate '*'
  {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };
  if (not ods_check_auth (uname, inst_id, 'author'))
    return ods_auth_failed ();

  declare exit handler for not found
  {
    return ods_serialize_int_res (-1, 'The home folder does not exists');
  };
  select p.HOME_PATH, p.GALLERY_ID into path, g_id from PHOTO.WA.SYS_INFO p, DB.DBA.WA_INSTANCE i where i.WAI_NAME = p.WAI_NAME and i.WAI_ID = inst_id;
  if (new_name is null)
    new_name := name;
  if (startDate is null)
    startDate := now ();
  if (endDate is null)
    endDate := now ();
  sid := get_ses (uname);
  res := PHOTO.WA.edit_album (sid, g_id, path, name, new_name, visibility, startDate, endDate, description, geolocation, obsolete);
  close_ses (sid);
  rc := case when (not isarray (res)) then res.id else -1 end;
  return ods_serialize_int_res (rc, 'Updated');
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API."photo.album.delete" (
  in inst_id integer,
  in name varchar) __soap_http 'text/xml'
{
  declare uname varchar;
  declare rc integer;
  declare path varchar;

  declare exit handler for sqlstate '*'
  {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };
  if (not ods_check_auth (uname, inst_id, 'author'))
    return ods_auth_failed ();

  declare exit handler for not found
  {
    return ods_serialize_int_res (-1, 'The home folder does not exists');
  };
  select p.HOME_PATH into path from PHOTO.WA.SYS_INFO p, DB.DBA.WA_INSTANCE i where i.WAI_NAME = p.WAI_NAME and i.WAI_ID = inst_id;
  path := path || name || '/';
  rc := DB.DBA.DAV_DELETE_INT (path, 0, uname, null, 0);
  return ods_serialize_int_res (rc);
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API."photo.image.get" (
  in inst_id integer,
  in album varchar,
  in name varchar,
  in outputFormat varchar := '') __soap_http 'text/xml'
{
  declare uname varchar;
  declare rc integer;
  declare content, tp any;
  declare sid, path varchar;

  declare exit handler for sqlstate '*'
  {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };
  if (not ods_check_auth (uname, inst_id, 'viewer'))
    return ods_auth_failed ();

  declare exit handler for not found
  {
    return ods_serialize_int_res (-1, 'The home folder does not exists');
  };
  select p.HOME_PATH into path from PHOTO.WA.SYS_INFO p, DB.DBA.WA_INSTANCE i where i.WAI_NAME = p.WAI_NAME and i.WAI_ID = inst_id;
  path := path || album || '/' || name;
  rc := DB.DBA.DAV_RES_CONTENT_INT (DB.DBA.DAV_SEARCH_ID (path, 'R'), content, tp, 0, 0, uname, null);
  if (rc < 0)
    return ods_serialize_int_res (rc);

  if (outputFormat = 'base64')
  {
    http_header ('Content-Type: text/plain\r\n');
    http (sprintf ('data:%s;base64,%s', tp, encode_base64 (blob_to_string (content))));
  } else {
    http_header (sprintf ('Content-Type: %s\r\n', tp));
    http (content);
  }
  return '';
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API."photo.image.new" (
  in inst_id integer,
    in album varchar,
  in name varchar,
  in description varchar := null,
  in visibility integer := 1) __soap_http 'text/xml'
{
  declare image varbinary;

  image := http_body_read ();
  return ODS.ODS_API.photo_image_new (inst_id, album, name, description, visibility, image);
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API."photo.image.newUrl" (
  in inst_id integer,
  in album varchar,
  in name varchar,
  in description varchar := null,
  in visibility integer := 1,
  in sourceUrl varchar) __soap_http 'text/xml'
  {
  declare image varbinary;

  image := PHOTE.WA.url_content (sourceUrl);
  return ODS.ODS_API.photo_image_new (inst_id, album, name, description, visibility, image);
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API."photo.image.edit" (
  in inst_id integer,
  in album varchar,
  in name varchar,
  in new_name varchar := null,
  in description varchar := null,
  in visibility integer := 1) __soap_http 'text/xml'
{
  declare uname varchar;
  declare rc integer;
  declare res DB.DBA.SOAP_album;
  declare sid, path varchar;
  declare g_id integer;

  declare exit handler for sqlstate '*'
  {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };
  if (not ods_check_auth (uname, inst_id, 'author'))
    return ods_auth_failed ();

  declare exit handler for not found
  {
    return ods_serialize_int_res (-1, 'The home folder does not exists');
  };
  select p.HOME_PATH, p.GALLERY_ID into path, g_id from PHOTO.WA.SYS_INFO p, DB.DBA.WA_INSTANCE i where i.WAI_NAME = p.WAI_NAME and i.WAI_ID = inst_id;
  path := path || album || '/';
  if (new_name is null)
    new_name := name;
  if (description is null)
    description := DB.DBA.DAV_PROP_GET_INT (DB.DBA.DAV_SEARCH_ID (path || name, 'R'), 'R', 'description', 0);
  sid := get_ses (uname);
  res := PHOTO.WA.edit_image (sid, g_id, path, name, new_name, description, visibility);
  close_ses (sid);
  rc := case when (not isinteger (res)) then res.id else -1 end;
  return ods_serialize_int_res (rc, 'Updated');
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API."photo.image.delete" (
  in inst_id integer,
	in album varchar,
  in name varchar) __soap_http 'text/xml'
{
  declare uname varchar;
  declare rc integer;
  declare path varchar;

  declare exit handler for sqlstate '*'
  {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };
  if (not ods_check_auth (uname, inst_id, 'author'))
    return ods_auth_failed ();

  declare exit handler for not found
  {
    return ods_serialize_int_res (-1, 'The home folder does not exists');
  };
  select p.HOME_PATH into path from PHOTO.WA.SYS_INFO p, DB.DBA.WA_INSTANCE i where i.WAI_NAME = p.WAI_NAME and i.WAI_ID = inst_id;
  path := path || album || '/' || name;
  rc := DB.DBA.DAV_DELETE_INT (path, 0, uname, null, 0);
  return ods_serialize_int_res (rc);
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API."photo.comment.get" (
	in comment_id integer) __soap_http 'text/xml'
{
	declare exit handler for sqlstate '*'
	{
		rollback work;
		return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
	};

	declare uname varchar;
	declare inst_id, image_id, id integer;
	declare post_iri varchar;

	whenever not found goto _exit;

  id := comment_id;
	select GALLERY_ID, RES_ID into inst_id, image_id from PHOTO.WA.COMMENTS where COMMENT_ID = id;

	if (not ods_check_auth (uname, inst_id, 'reader'))
		return ods_auth_failed ();

	if (not (PHOTO.WA.discussion_check () and PHOTO.WA.conversation_enable (inst_id)))
		return signal('PH001', 'Discussions must be enabled for this instance');

  post_iri := SIOC..post_iri_ex (SIOC..photo_iri (PHOTO.WA.domain_name ( inst_id)), image_id);
  ods_describe_iri (SIOC..gallery_comment_iri (post_iri, comment_id));
_exit:
	return '';
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API."photo.comment.new" (
  in inst_id integer,
  in album varchar,
  in image varchar,
	in text varchar) __soap_http 'text/xml'
{
	declare exit handler for sqlstate '*'
{
		rollback work;
		return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
	};

  declare sid, path varchar;
	declare rc integer;
	declare uname varchar;
  declare comment DB.DBA.photo_comment;

	rc := -1;
	if (not ods_check_auth (uname, inst_id, 'reader'))
		return ods_auth_failed ();

	if (not (PHOTO.WA.discussion_check () and PHOTO.WA.conversation_enable (inst_id)))
		return signal('PH001', 'Discussions must be enabled for this instance');

  declare exit handler for not found
  {
    return ods_serialize_int_res (-1, 'The home folder does not exists');
  };
  select p.HOME_PATH into path from PHOTO.WA.SYS_INFO p, DB.DBA.WA_INSTANCE i where i.WAI_NAME = p.WAI_NAME and i.WAI_ID = inst_id;
  path := path || album || '/' || image;
  sid := get_ses (uname);
	comment := PHOTO.WA.add_comment (sid, inst_id, DB.DBA.DAV_SEARCH_ID (path, 'R'), text);
	rc := comment.comment_id;
  close_ses (sid);
	return ods_serialize_int_res (rc);
}
  ;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API."photo.comment.delete" (
	in comment_id integer) __soap_http 'text/xml'
{
	declare exit handler for sqlstate '*'
	{
		rollback work;
		return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
	};

	declare rc, id integer;
	declare uname varchar;
	declare inst_id integer;

	rc := -1;
	inst_id := (select GALLERY_ID from PHOTO.WA.COMMENTS where COMMENT_ID = comment_id);
	if (not ods_check_auth (uname, inst_id, 'author'))
		return ods_auth_failed ();

	if (not (PHOTO.WA.discussion_check () and PHOTO.WA.conversation_enable (inst_id)))
		return signal('PH001', 'Discussions must be enabled for this instance');

  id := comment_id;
	if (not exists (select 1 from PHOTO.WA.COMMENTS where COMMENT_ID = id))
		return ods_serialize_sql_error ('37000', 'The item is not found');
	delete from PHOTO.WA.COMMENTS where COMMENT_ID = id;
	rc := row_count ();

	return ods_serialize_int_res (rc);
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API."photo.options.set" (
  in inst_id integer,
  in show_map integer := null,
  in show_timeline integer := null,
  in discussion_enable integer := null,
  in discussion_init integer := null,
  in albums_per_page integer := null) __soap_http 'text/xml'
{
  declare uname varchar;
  declare rc integer;
  declare res DB.DBA.SOAP_album;
  declare sid, path varchar;
	declare settings, settings_array any;
  declare g_id integer;

  declare exit handler for sqlstate '*'
  {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, PHOTO.WA.test_clear (__SQL_MESSAGE));
  };
  if (not ods_check_auth (uname, inst_id, 'author'))
    return ods_auth_failed ();

  if (not exists (select 1 from DB.DBA.WA_INSTANCE where WAI_ID = inst_id and WAI_TYPE_NAME = 'oGallery'))
    return ods_serialize_sql_error ('37000', 'The instance is not found');

  declare exit handler for not found
  {
    return ods_serialize_int_res (-1, 'The home folder does not exists');
  };
  select p.HOME_PATH, p.GALLERY_ID into path, g_id from PHOTO.WA.SYS_INFO p, DB.DBA.WA_INSTANCE i where i.WAI_NAME = p.WAI_NAME and i.WAI_ID = inst_id;
  sid := get_ses (uname);
  settings := PHOTO.WA.load_settings (sid, inst_id);
  if (show_map is null)
    show_map := get_keyword ('show_map', settings);
  if (show_timeline is null)
    show_timeline := get_keyword ('show_timeline', settings);
  if (discussion_enable is null)
    discussion_enable := get_keyword ('nntp', settings);
  if (discussion_init is null)
    discussion_init := get_keyword ('nntp_init', settings);
  if (albums_per_page is null)
  {
    settings_array := vector ('albums_per_page', get_keyword ('albums_per_page', settings));
  } else {
    PHOTO.WA.test (cast (albums_per_page as varchar), vector ('name', 'Albums per page', 'class', 'integer', 'type', 'integer', 'minValue', 1, 'maxValue', 1000));
    settings_array := vector ('albums_per_page', albums_per_page);
    }
  res := PHOTO.WA.edit_album_settings (sid, g_id, path, show_map, show_timeline, discussion_enable, discussion_init, settings_array);
  close_ses (sid);
  rc := case when (res = 'true') then 1 else -1 end;
  return ods_serialize_int_res (rc, 'Updated');
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API."photo.options.get" (
  in inst_id int) __soap_http 'text/xml'
{
	declare exit handler for sqlstate '*'
{
		rollback work;
		return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
	};

	declare rc integer;
	declare uname, sid varchar;
	declare settings any;

	if (not ods_check_auth (uname, inst_id, 'author'))
		return ods_auth_failed ();

  if (not exists (select 1 from DB.DBA.WA_INSTANCE where WAI_ID = inst_id and WAI_TYPE_NAME = 'oGallery'))
    return ods_serialize_sql_error ('37000', 'The instance is not found');

  sid := get_ses (uname);
  settings := PHOTO.WA.load_settings (sid, inst_id);
  close_ses (sid);

	http ('<settings>\n');
  http (ODS.ODS_API.photo_setting_xml (settings, 'show_map'));
  http (ODS.ODS_API.photo_setting_xml (settings, 'show_timeline'));
  http (ODS.ODS_API.photo_setting_xml (settings, 'nntp'));
  http (ODS.ODS_API.photo_setting_xml (settings, 'nntp_init'));
  http (ODS.ODS_API.photo_setting_xml (settings, 'albums_per_page'));
	http ('</settings>');

	return '';
}
;

grant execute on ODS.ODS_API."photo.album.new" to ODS_API;
grant execute on ODS.ODS_API."photo.album.edit" to ODS_API;
grant execute on ODS.ODS_API."photo.album.delete" to ODS_API;

grant execute on ODS.ODS_API."photo.image.get" to ODS_API;
grant execute on ODS.ODS_API."photo.image.new" to ODS_API;
grant execute on ODS.ODS_API."photo.image.newUrl" to ODS_API;
grant execute on ODS.ODS_API."photo.image.delete" to ODS_API;
grant execute on ODS.ODS_API."photo.image.edit" to ODS_API;

grant execute on ODS.ODS_API."photo.comment.get" to ODS_API;
grant execute on ODS.ODS_API."photo.comment.new" to ODS_API;
grant execute on ODS.ODS_API."photo.comment.delete" to ODS_API;

grant execute on ODS.ODS_API."photo.options.set" to ODS_API;
grant execute on ODS.ODS_API."photo.options.get" to ODS_API;

use DB;
