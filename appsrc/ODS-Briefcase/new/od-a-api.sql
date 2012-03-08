--
--  $Id$
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2012 OpenLink Software
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
create procedure ODS.ODS_API.briefcase_setting_set (
  inout settings any,
  inout options any,
  in settingName varchar)
{
	declare aValue any;

  aValue := get_keyword (settingName, options, get_keyword (settingName, settings));
  ODRIVE.WA.set_keyword (settingName, settings, aValue);
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API.briefcase_setting_xml (
  in settings any,
  in settingName varchar)
{
  return sprintf ('<%s>%s</%s>', settingName, cast (get_keyword (settingName, settings) as varchar), settingName);
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API.briefcase_instance (
  in path varchar)
{
  declare uname, arr varchar;
  declare inst_id integer;

  path := ODRIVE.WA.path_normalize (path);
  if (chr (path[0]) = '~')
  {
    arr := sprintf_inverse (path, '~%s/%s', 1);
  } else {
    arr := sprintf_inverse (path, '/DAV/home/%s/%s', 1);
  }
  if (length (arr) <> 2)
    return 0;
  uname := arr[0];
  inst_id := 0;
  whenever not found goto ret;
  select WAI_ID
    into inst_id
    from DB.DBA.WA_INSTANCE, DB.DBA.WA_MEMBER, DB.DBA.SYS_USERS
   where WAM_USER = U_ID and U_NAME = uname and WAI_TYPE_NAME = 'oDrive' and WAM_INST = WAI_NAME and WAM_MEMBER_TYPE = 1;
ret:
  return inst_id;
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API.permissions2array (
  in perms any)
{
  declare N, retValue any;

  if (regexp_match ('^[r\\-][w\\-][x\\-]\044', perms) is null)
    signal ('22023', 'Not valid permissions string');

  retValue := vector (0, 0, 0);
  for (N := 0; N < length (perms); N := N + 1)
  {
    if (perms[N] <> ascii ('-'))
      retValue[N] := 1;
  }
  return retValue;
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API.permissions2string (
  in perms integer)
{
  return case when bit_and (perms, 4) then 'r' else '-' end || case when bit_and (perms, 2) then 'w' else '-' end || case when bit_and (perms, 1) then 'x' else '-' end;
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API.inheritance2int (
  in "inheritance" varchar)
{
  return get_keyword ("inheritance", vector ('object', 0, 'all', 1, 'children', 2), 1);
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API.inheritance2string (
  in "inheritance" any)
{
  return get_keyword ("inheritance", vector (0, 'object', 1, 'all', 2, 'children'), 'all');
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API."briefcase.list" (
  in path varchar) __soap_http 'text/xml'
{
  declare uname, upassword, instance_iri varchar;
  declare inst_id, id integer;
  declare N integer;
  declare sql, params, state, msg, meta, items any;

  path := ODRIVE.WA.path_normalize (path, 'C');

  inst_id := ODS.ODS_API.briefcase_instance (path);
  if (not ods_check_auth (uname, inst_id))
    return ods_auth_failed ();

  instance_iri := SIOC..briefcase_iri (ODRIVE.WA.domain_name (inst_id));
  upassword := ODRIVE.WA.account_password (ODRIVE.WA.account_id (uname));

  sql := 'select TOP 100 rs.* from ODRIVE.WA.odrive_proc (rs0, rs1, rs2, rs3, rs4, rs5)(c0 varchar, c1 varchar, c2 integer, c3 varchar, c4 varchar, c5 varchar, c6 varchar, c7 varchar, c8 varchar, c9 varchar) rs where rs0 = ? and rs1 = ? and rs2 = ? and rs3 = ? and rs4 = ? and rs5 = ? order by c9, c3, c1';
  params := vector (path, 0, null, null, uname, upassword);

  set_user_id('dba');
  state := '00000';
  exec (sql, state, msg, params, 0, meta, items);
  if (state <> '00000')
    signal (state, msg);

  http ('<?xml version="1.0"?>\n');
  http ('<items>\n');
  foreach (any item in items) do
  {
    http (sprintf ('<item path="%V">\n', ODRIVE.WA.utf2wide(item[8])));
      http (sprintf ('<uri>%V</uri>\n', SIOC..post_iri_ex (instance_iri, DB.DBA.DAV_SEARCH_ID (item[8], item[1]))));
      http (sprintf ('<name>%V</name>\n', ODRIVE.WA.utf2wide (item[0])));
      http (sprintf ('<mimeType>%V</mimeType>\n', item[4]));
      http (sprintf ('<size>%V</size>\n', cast(item[2] as varchar)));
      http (sprintf ('<owner>%V</owner>\n', item[5]));
      http (sprintf ('<group>%V</group>\n', item[6]));
      http (sprintf ('<permissions>%V</permissions>\n', item[7]));
      http (sprintf ('<modification>%V</modification>\n', item[3]));
    http ('</item>\n');
  }
  http ('</items>\n');

  return '';
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API."briefcase.info" (
  in path varchar,
  in "type" varchar) __soap_http 'text/xml'
{
  declare uname, upassword varchar;
  declare rc integer;
  declare inst_id integer;
  declare item, tmp any;

  declare exit handler for sqlstate '*'
  {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };
  path := ODRIVE.WA.path_normalize (path, "type");

  inst_id := ODS.ODS_API.briefcase_instance (path);
  if (not ods_check_auth (uname, inst_id))
    return ods_auth_failed ();

  upassword := ODRIVE.WA.account_password (ODRIVE.WA.account_id (uname));
  item := ODRIVE.WA.DAV_INIT (path, uname, upassword);
  if (ODRIVE.WA.dav_error (item))
    return ods_serialize_int_res (item);

  http (sprintf ('<item path="%s">\n', path));
  http (sprintf ('  <name>%s</name>\n', ODRIVE.WA.DAV_GET (item, 'name')));
  http (sprintf ('  <mimeType>%s</mimeType>\n', ODRIVE.WA.DAV_GET (item, 'mimeType')));
  if (ODRIVE.WA.DAV_GET (item, 'type') = 'R')
  http (sprintf ('  <size>%d</size>\n', ODRIVE.WA.DAV_GET (item, 'length')));
  http (sprintf ('  <owner>%s</owner>\n', ODRIVE.WA.DAV_GET (item, 'ownerName')));
  http (sprintf ('  <group>%s</group>\n', ODRIVE.WA.DAV_GET (item, 'groupName')));
  http (sprintf ('  <permissions>%s</permissions>\n', ODRIVE.WA.DAV_GET (item, 'permissionsName')));
  http (sprintf ('  <modification>%s</modification>\n', left (cast (ODRIVE.WA.DAV_GET (item, 'modificationTime') as varchar), 10)));
  http (sprintf ('  <creation>%s</creation>\n', left (cast (ODRIVE.WA.DAV_GET (item, 'creationTime') as varchar), 10)));
  tmp := ODS.ODS_API."briefcase.property.list.internal" (path, '%', uname, upassword);
  if (not ODRIVE.WA.dav_error (tmp))
  http (tmp);
  tmp := ODS.ODS_API."briefcase.share.list.internal" (path, uname, upassword);
  if (not ODRIVE.WA.dav_error (tmp))
  http (tmp);
  tmp := ODS.ODS_API."briefcase.resource.vc.info.internal" (path, uname, upassword);
  if (not ODRIVE.WA.dav_error (tmp))
  http (tmp);
  tmp := ODS.ODS_API."briefcase.resource.vc.versions.internal" (path, uname, upassword);
  if (not ODRIVE.WA.dav_error (tmp))
  http (tmp);
  http (         '</item>');

  return '';
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API."briefcase.resource.info" (
  in path varchar) __soap_http 'text/xml'
{
  return ODS.ODS_API."briefcase.info" (path, 'R');
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API."briefcase.resource.vc.set" (
  in path varchar,
  in state varchar := 'on') __soap_http 'text/xml'
{
  declare uname, upassword varchar;
  declare inst_id integer;
  declare retValue, item any;

  declare exit handler for sqlstate '*'
  {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };
  path := ODRIVE.WA.path_normalize (path, 'P');

  inst_id := ODS.ODS_API.briefcase_instance (path);
  if (not ods_check_auth (uname, inst_id))
    return ods_auth_failed ();
  if (state <> 'on' and state <> 'off')
    signal ('22023', 'Bad input parameter value');

  upassword := ODRIVE.WA.account_password (ODRIVE.WA.account_id (uname));
  item := ODRIVE.WA.DAV_INIT (path, uname, upassword);
  if (ODRIVE.WA.dav_error (item))
    return item;
  if (ODRIVE.WA.DAV_GET_INFO (path, 'vc', uname, upassword) = 'ON')
  {
    if (state = 'on')
      signal ('22023', 'The resource is under version control');
    retValue := ODRIVE.WA.DAV_REMOVE_VERSION_CONTROL (path, uname, upassword);
  } else {
    if (state = 'off')
      signal ('22023', 'The resource is not under version control');
    retValue := ODRIVE.WA.DAV_VERSION_CONTROL (path, uname, upassword);
  }
  if (ODRIVE.WA.dav_error (item))
    return ods_serialize_int_res (retValue);
  return ods_serialize_int_res (1);
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API."briefcase.resource.vc.get" (
  in path varchar,
  in version varchar := 'last') __soap_http 'text/xml'
{
  declare uname, upassword varchar;
  declare inst_id integer;
  declare retValue, content, contentType any;

  declare exit handler for sqlstate '*'
  {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };
  path := ODRIVE.WA.path_normalize (path, 'P');

  inst_id := ODS.ODS_API.briefcase_instance (path);
  if (not ods_check_auth (uname, inst_id))
    return ods_auth_failed ();

  upassword := ODRIVE.WA.account_password (ODRIVE.WA.account_id (uname));
  if (ODRIVE.WA.DAV_GET_INFO (path, 'vc', uname, upassword) = 'OFF')
    signal ('22023', 'The resource is not under version control');

  retValue := DB.DBA.DAV_RES_CONTENT (ODRIVE.WA.DAV_GET_VERSION_PATH (path) || version, content, contentType, uname, upassword);
  if (ODRIVE.WA.dav_error (retValue))
    return ods_serialize_int_res (retValue);

  http_header (sprintf ('Content-Type: %s\r\n', contentType));
  http (content);

  return '';
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API."briefcase.resource.vc.checkin" (
  in path varchar) __soap_http 'text/xml'
{
  declare uname, upassword varchar;
  declare inst_id integer;
  declare retValue, content, contentType any;

  declare exit handler for sqlstate '*'
  {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };
  path := ODRIVE.WA.path_normalize (path, 'R');

  inst_id := ODS.ODS_API.briefcase_instance (path);
  if (not ods_check_auth (uname, inst_id))
    return ods_auth_failed ();

  upassword := ODRIVE.WA.account_password (ODRIVE.WA.account_id (uname));
  if (ODRIVE.WA.DAV_GET_INFO (path, 'vc', uname, upassword) = 'OFF')
    signal ('22023', 'The resource is not under version control');

  retValue := ODRIVE.WA.DAV_CHECKIN (path, uname, upassword);
  if (ODRIVE.WA.DAV_ERROR(retValue))
    return ods_serialize_int_res (retValue);

  return ods_serialize_int_res (1);
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API."briefcase.resource.vc.checkout" (
  in path varchar) __soap_http 'text/xml'
{
  declare uname, upassword varchar;
  declare inst_id integer;
  declare retValue, content, contentType any;

  declare exit handler for sqlstate '*'
  {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };
  path := ODRIVE.WA.path_normalize (path, 'R');

  inst_id := ODS.ODS_API.briefcase_instance (path);
  if (not ods_check_auth (uname, inst_id))
    return ods_auth_failed ();

  upassword := ODRIVE.WA.account_password (ODRIVE.WA.account_id (uname));
  if (ODRIVE.WA.DAV_GET_INFO (path, 'vc', uname, upassword) = 'OFF')
    signal ('22023', 'The resource is not under version control');

  retValue := ODRIVE.WA.DAV_CHECKOUT (path, uname, upassword);
  if (ODRIVE.WA.DAV_ERROR(retValue))
    return ods_serialize_int_res (retValue);

  return ods_serialize_int_res (1);
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API."briefcase.resource.vc.lock" (
  in path varchar,
  in state varchar := 'on') __soap_http 'text/xml'
{
  declare uname, upassword varchar;
  declare inst_id integer;
  declare retValue, content, contentType any;

  declare exit handler for sqlstate '*'
  {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };
  path := ODRIVE.WA.path_normalize (path, 'R');

  inst_id := ODS.ODS_API.briefcase_instance (path);
  if (not ods_check_auth (uname, inst_id))
    return ods_auth_failed ();

  upassword := ODRIVE.WA.account_password (ODRIVE.WA.account_id (uname));
  if (ODRIVE.WA.DAV_GET_INFO (path, 'vc', uname, upassword) = 'OFF')
    signal ('22023', 'The resource is not under version control');

  if (state = 'on')
  {
    retValue := ODRIVE.WA.DAV_LOCK (path, 'R', uname, upassword);
  } else {
    retValue := ODRIVE.WA.DAV_UNLOCK (path, 'R', uname, upassword);
  }
  if (ODRIVE.WA.DAV_ERROR(retValue))
    return ods_serialize_int_res (retValue);

  return ods_serialize_int_res (1);
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API."briefcase.resource.vc.info.internal" (
  in path varchar,
  in uname varchar,
  in upassword varchar)
{
  declare N integer;
  declare item, tmp any;
  declare sStream any;

  item := ODRIVE.WA.DAV_INIT (path, uname, upassword);
  if (ODRIVE.WA.dav_error (item))
    return item;

  if (ODRIVE.WA.DAV_GET (item, 'type') <> 'R')
    return '';

  sStream := string_output();
  tmp := ODRIVE.WA.DAV_GET_INFO (path, 'vc', uname, upassword);
  if (tmp = 'ON')
  {
  	http ('<versionControl>', sStream);
  	http (sprintf ('<enabled>%s</enabled>', tmp), sStream);
  	http (sprintf ('<autoVersioning>%s</autoVersioning>', ODRIVE.WA.DAV_GET_INFO (path, 'avcState', uname, upassword)), sStream);
  	http (sprintf ('<state>%s</state>', ODRIVE.WA.DAV_GET_INFO (path, 'vcState', uname, upassword)), sStream);
  	http (sprintf ('<lock>%s</lock>', ODRIVE.WA.DAV_GET_INFO (path, 'lockState', uname, upassword)), sStream);
  	http ('</versionControl>', sStream);
  }
  return string_output_string(sStream);
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API."briefcase.resource.vc.info" (
  in path varchar) __soap_http 'text/xml'
{
  declare uname, upassword varchar;
  declare inst_id integer;
  declare retValue any;

  declare exit handler for sqlstate '*'
  {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };
  path := ODRIVE.WA.path_normalize (path, 'P');

  inst_id := ODS.ODS_API.briefcase_instance (path);
  if (not ods_check_auth (uname, inst_id))
    return ods_auth_failed ();

  upassword := ODRIVE.WA.account_password (ODRIVE.WA.account_id (uname));
  retValue := ODS.ODS_API."briefcase.resource.vc.info.internal" (path, uname, upassword);
  if (ODRIVE.WA.dav_error (retValue))
    return ods_serialize_int_res (retValue);

	http (sprintf ('<item path="%s">', path));
	http (retValue);
	http ('</item>');

  return '';
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API."briefcase.resource.vc.versions.internal" (
  in path varchar,
  in uname varchar,
  in upassword varchar)
{
  declare N integer;
  declare item, tmp any;
  declare sStream any;

  item := ODRIVE.WA.DAV_INIT (path, uname, upassword);
  if (ODRIVE.WA.dav_error (item))
    return item;

  sStream := string_output();
  if (ODRIVE.WA.DAV_GET (item, 'type') = 'R')
  {
    tmp := ODRIVE.WA.DAV_GET_INFO (path, 'vc', uname, upassword);
    if (tmp = 'ON')
    {
    	http ('<versions>', sStream);
    	for (select rs.* from ODRIVE.WA.DAV_GET_VERSION_SET(rs0, rs1, rs2)(c0 varchar, c1 integer) rs where rs0 = path and rs1 = uname and rs2 = upassword) do
    	{
        item := ODRIVE.WA.DAV_INIT (c0, uname, upassword);
        if (not ODRIVE.WA.dav_error (item))
    	    http (sprintf ('<version path="%s" number="%s" size="%d" modification="%s" />', c0, ODRIVE.WA.path_name(c0), ODRIVE.WA.DAV_GET (item, 'length'), left (cast (ODRIVE.WA.DAV_GET (item, 'modificationTime') as varchar), 10)), sStream);
    	}
    	http ('</versions>', sStream);
    }
  }
  return string_output_string(sStream);
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API."briefcase.resource.vc.versions" (
  in path varchar) __soap_http 'text/xml'
{
  declare uname, upassword varchar;
  declare inst_id integer;
  declare retValue any;

  declare exit handler for sqlstate '*'
  {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };
  path := ODRIVE.WA.path_normalize (path, 'P');

  inst_id := ODS.ODS_API.briefcase_instance (path);
  if (not ods_check_auth (uname, inst_id))
    return ods_auth_failed ();

  upassword := ODRIVE.WA.account_password (ODRIVE.WA.account_id (uname));
  retValue := ODS.ODS_API."briefcase.resource.vc.versions.internal" (path, uname, upassword);
  if (ODRIVE.WA.dav_error (retValue))
    return ods_serialize_int_res (retValue);

	http (sprintf ('<item path="%s">', path));
	http (retValue);
	http ('</item>');

  return '';
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API."briefcase.resource.get" (
  in path varchar) __soap_http 'text/xml'
{
  declare uname, upassword varchar;
  declare rc integer;
  declare content, contentType any;
  declare inst_id integer;

  declare exit handler for sqlstate '*'
  {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };
  path := ODRIVE.WA.path_normalize (path, 'R');

  inst_id := ODS.ODS_API.briefcase_instance (path);
  if (not ods_check_auth (uname, inst_id))
    return ods_auth_failed ();

  upassword := ODRIVE.WA.account_password (ODRIVE.WA.account_id (uname));
  rc := DB.DBA.DAV_RES_CONTENT (path, content, contentType, uname, upassword);
  if (ODRIVE.WA.dav_error (rc))
    return ods_serialize_int_res (rc);

  http_header (sprintf ('Content-Type: %s\r\n', contentType));
  http (content);

  return '';
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API."briefcase.resource.store" (
	in path varchar,
	in content varchar,
	in "type" varchar := null,
	in permissions varchar := '110100100RM') __soap_http 'text/xml'
{
  declare uname varchar;
  declare rc integer;
  declare uid, gid integer;
  declare inst_id integer;

  declare exit handler for sqlstate '*'
  {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };
  path := ODRIVE.WA.path_normalize (path, 'R');

  inst_id := ODS.ODS_API.briefcase_instance (path);
  if (not ods_check_auth (uname, inst_id))
    return ods_auth_failed ();

  whenever not found goto ret;
  select U_ID, U_GROUP into uid, gid from DB.DBA.SYS_USERS where U_NAME = uname;
  rc := DB.DBA.DAV_RES_UPLOAD_STRSES_INT (path, content, "type", permissions, uid, gid, uname, null, 0, null, null, null, null, null, 1);
ret:
  return ods_serialize_int_res (rc);
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API."briefcase.resource.delete" (
  in path varchar) __soap_http 'text/xml'
{
  declare uname, upassword varchar;
  declare rc integer;
  declare inst_id integer;

  declare exit handler for sqlstate '*'
  {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };
  path := ODRIVE.WA.path_normalize (path, 'R');

  inst_id := ODS.ODS_API.briefcase_instance (path);
  if (not ods_check_auth (uname, inst_id))
    return ods_auth_failed ();

  upassword := ODRIVE.WA.account_password (ODRIVE.WA.account_id (uname));
  rc := DB.DBA.DAV_DELETE (path, 0, uname, upassword);
  return ods_serialize_int_res (rc);
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API."briefcase.collection.info" (
  in path varchar) __soap_http 'text/xml'
{
  return ODS.ODS_API."briefcase.info" (path, 'C');
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API."briefcase.collection.create" (
  in path varchar,
  in permissions varchar := '110100100RM') __soap_http 'text/xml'
{
  declare uname varchar;
  declare rc integer;
  declare uid, gid integer;
  declare inst_id integer;

  declare exit handler for sqlstate '*'
  {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };
  path := ODRIVE.WA.path_normalize (path, 'C');

  inst_id := ODS.ODS_API.briefcase_instance (path);
  if (not ods_check_auth (uname, inst_id))
    return ods_auth_failed ();

  whenever not found goto ret;
  select U_ID, U_GROUP into uid, gid from DB.DBA.SYS_USERS where U_NAME = uname;
  rc := DB.DBA.DAV_COL_CREATE_INT (path, permissions, uid, gid, uname, null, 1, 0, 1, null, null);
ret:
  return ods_serialize_int_res (rc);
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API."briefcase.collection.delete" (
  in path varchar) __soap_http 'text/xml'
{
  declare uname, upassword varchar;
  declare rc integer;
  declare inst_id integer;

  declare exit handler for sqlstate '*'
  {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };
  path := ODRIVE.WA.path_normalize (path, 'C');

  inst_id := ODS.ODS_API.briefcase_instance (path);
  if (not ods_check_auth (uname, inst_id))
    return ods_auth_failed ();

  upassword := ODRIVE.WA.account_password (ODRIVE.WA.account_id (uname));
  rc := DB.DBA.DAV_DELETE (path, 0, uname, upassword);
  return ods_serialize_int_res (rc);
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API."briefcase.copy" (
  in from_path varchar,
  in to_path varchar,
  in overwrite integer := 1,
  in permissions varchar := '110100000RR') __soap_http 'text/xml'
{
  declare uname, upassword, targetPath varchar;
  declare rc integer;
  declare uid, gid integer;
  declare inst_id, inst_id2 integer;
  declare from_item, to_item any;

  declare exit handler for sqlstate '*'
  {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };
  from_path := ODRIVE.WA.path_normalize (from_path);
  to_path := ODRIVE.WA.path_normalize (to_path, 'C');

  inst_id := ODS.ODS_API.briefcase_instance (from_path);
  inst_id2 := ODS.ODS_API.briefcase_instance (to_path);
  if (inst_id <> inst_id2)
    inst_id := 0;
  if (not ods_check_auth (uname, inst_id))
    return ods_auth_failed ();

  whenever not found goto ret;
  rc := -1;
  select U_ID, U_GROUP into uid, gid from DB.DBA.SYS_USERS where U_NAME = uname;
  upassword := ODRIVE.WA.account_password (ODRIVE.WA.account_id (uname));
  from_item := ODRIVE.WA.DAV_INIT (from_path, uname, upassword);
  if (ODRIVE.WA.dav_error (from_item))
    return ods_serialize_int_res (from_item);
  to_item := ODRIVE.WA.DAV_INIT (to_path, uname, upassword);
  if (ODRIVE.WA.dav_error (to_item))
    return ods_serialize_int_res (to_item);
  targetPath := to_path || ODRIVE.WA.DAV_GET (from_item, 'name');
  if (ODRIVE.WA.DAV_GET (from_item, 'type') = 'C')
    targetPath := targetPath || '/';

  rc := DB.DBA.DAV_COPY (from_path, targetPath, overwrite, permissions, uid, gid, uname, upassword);
ret:
  return ods_serialize_int_res (rc);
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API."briefcase.move" (
  in from_path varchar,
  in to_path varchar,
  in overwrite integer := 1) __soap_http 'text/xml'
{
  declare uname, upassword, targetPath varchar;
  declare rc integer;
  declare inst_id, inst_id2 integer;
  declare from_item, to_item any;

  declare exit handler for sqlstate '*'
  {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };
  from_path := ODRIVE.WA.path_normalize (from_path);
  to_path := ODRIVE.WA.path_normalize (to_path, 'C');

  inst_id := ODS.ODS_API.briefcase_instance (from_path);
  inst_id2 := ODS.ODS_API.briefcase_instance (to_path);
  if (inst_id <> inst_id2)
    inst_id := 0;
  if (not ods_check_auth (uname, inst_id))
    return ods_auth_failed ();

  upassword := ODRIVE.WA.account_password (ODRIVE.WA.account_id (uname));
  from_item := ODRIVE.WA.DAV_INIT (from_path, uname, upassword);
  if (ODRIVE.WA.dav_error (from_item))
    return ods_serialize_int_res (from_item);
  to_item := ODRIVE.WA.DAV_INIT (to_path, uname, upassword);
  if (ODRIVE.WA.dav_error (to_item))
    return ods_serialize_int_res (to_item);
  targetPath := to_path || ODRIVE.WA.DAV_GET (from_item, 'name');
  if (ODRIVE.WA.DAV_GET (from_item, 'type') = 'C')
    targetPath := targetPath || '/';

  rc := DB.DBA.DAV_MOVE (from_path, targetPath, overwrite, uname, upassword);
  return ods_serialize_int_res (rc);
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API."briefcase.property.list.internal" (
  in path varchar,
  in mask varchar,
  in uname varchar,
  in upassword varchar)
{
  declare N integer;
  declare props any;
  declare sStream any;

  props := DB.DBA.DAV_PROP_LIST (path, mask, uname, upassword);
  if (ODRIVE.WA.dav_error (props))
    return props;

  sStream := string_output();
	http ('<properties>', sStream);
	for (N := 0; N < length (props); N := N + 1)
	{
    http (sprintf ('<property name="%s">%V</property>', props[N][0], props[N][1]), sStream);
  }
	http ('</properties>', sStream);

  return string_output_string(sStream);
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API."briefcase.property.list" (
  in path varchar,
  in mask varchar := '%') __soap_http 'text/xml'
{
  declare uname, upassword varchar;
  declare inst_id integer;
  declare props any;

  declare exit handler for sqlstate '*'
  {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };
  path := ODRIVE.WA.path_normalize (path, 'P');

  inst_id := ODS.ODS_API.briefcase_instance (path);
  if (not ods_check_auth (uname, inst_id))
    return ods_auth_failed ();

  upassword := ODRIVE.WA.account_password (ODRIVE.WA.account_id (uname));
  props := ODS.ODS_API."briefcase.property.list.internal" (path, mask, uname, upassword);
  if (ODRIVE.WA.dav_error (props))
    return ods_serialize_int_res (props);

	http (sprintf ('<item path="%s">', path));
	http (props);
	http ('</item>');

  return '';
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API."briefcase.property.set" (
  in path varchar,
  in "name" varchar,
  in "value" varchar) __soap_http 'text/xml'
{
  declare uname, upassword varchar;
  declare rc integer;
  declare inst_id integer;

  declare exit handler for sqlstate '*'
  {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };
  path := ODRIVE.WA.path_normalize (path, 'P');

  inst_id := ODS.ODS_API.briefcase_instance (path);
  if (not ods_check_auth (uname, inst_id))
    return ods_auth_failed ();

  upassword := ODRIVE.WA.account_password (ODRIVE.WA.account_id (uname));
  rc := DB.DBA.DAV_PROP_SET (path, "name", "value", uname, upassword);
  if (ODRIVE.WA.dav_error (rc))
    return ods_serialize_int_res (rc);
  return ods_serialize_int_res (1);
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API."briefcase.property.remove" (
  in path varchar,
  in "name" varchar) __soap_http 'text/xml'
{
  declare uname, upassword varchar;
  declare rc integer;
  declare inst_id integer;

  declare exit handler for sqlstate '*'
  {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };
  path := ODRIVE.WA.path_normalize (path, 'P');

  inst_id := ODS.ODS_API.briefcase_instance (path);
  if (not ods_check_auth (uname, inst_id))
    return ods_auth_failed ();

  upassword := ODRIVE.WA.account_password (ODRIVE.WA.account_id (uname));
  rc := DB.DBA.DAV_PROP_REMOVE (path, "name", uname, upassword);
  if (ODRIVE.WA.dav_error (rc))
    return ods_serialize_int_res (rc);
  return ods_serialize_int_res (1);
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API."briefcase.property.get" (
  in path varchar,
  in name varchar := null) __soap_http 'text/xml'
{
  declare uname, upassword varchar;
  declare rc integer;
  declare inst_id integer;

  declare exit handler for sqlstate '*'
  {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };
  path := ODRIVE.WA.path_normalize (path, 'P');

  inst_id := ODS.ODS_API.briefcase_instance (path);
  if (not ods_check_auth (uname, inst_id))
    return ods_auth_failed ();

  upassword := ODRIVE.WA.account_password (ODRIVE.WA.account_id (uname));
  rc := DB.DBA.DAV_PROP_GET (path, "name", uname, upassword);
  if (ODRIVE.WA.dav_error (rc))
    return ods_serialize_int_res (rc);
  return rc;
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API."briefcase.share.add" (
  in path varchar,
  in "user" varchar,
  in "inheritance" varchar := 'all',
  in "allow" varchar := 'rw-',
  in "deny" varchar := '---') __soap_http 'text/xml'
{
  declare uname, upassword varchar;
  declare rc, inst_id, user_id integer;
  declare ACLs, newACLs, perms any;

  declare exit handler for sqlstate '*'
  {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };
  path := ODRIVE.WA.path_normalize (path, 'P');

  inst_id := ODS.ODS_API.briefcase_instance (path);
  if (not ods_check_auth (uname, inst_id))
    return ods_auth_failed ();

  user_id := ODRIVE.WA.account_id ("user");
  if (user_id = -1)
    signal ('22023', 'The user name does not exist');

  "allow" := ODS.ODS_API.permissions2array ("allow");
  "deny" := ODS.ODS_API.permissions2array ("deny");
  if (
      ("allow"[0] = 1 and "allow"[0] = "deny"[0]) or
      ("allow"[1] = 1 and "allow"[1] = "deny"[1]) or
      ("allow"[2] = 1 and "allow"[2] = "deny"[2])
     )
    signal ('22023', 'Not valid permissions string');

  upassword := ODRIVE.WA.account_password (ODRIVE.WA.account_id (uname));
  ACLs := DB.DBA.DAV_PROP_GET (path, ':virtacl', uname, upassword);
  if (ODRIVE.WA.dav_error (ACLs))
    ods_serialize_int_res (ACLs);

  ACLs := ODRIVE.WA.acl_vector (ACLs);
  newACLs := WS.WS.ACL_CREATE();
  foreach (any ACL in ACLs) do
  {
    if ((ACL[0] <> user_id) or (ACL[1] <> ODS.ODS_API.inheritance2int ("inheritance")))
    {
      WS.WS.ACL_ADD_ENTRY (newACLs, ACL[0], ACL[2], 1, ACL[1]);
      WS.WS.ACL_ADD_ENTRY (newACLs, ACL[0], ACL[3], 0, ACL[1]);
    }
  }
  WS.WS.ACL_ADD_ENTRY (newACLs, user_id,
                                bit_shift ("allow"[0], 2) + bit_shift ("allow"[1], 1) + "allow"[2],
                                1,
                                ODS.ODS_API.inheritance2int ("inheritance"));
  WS.WS.ACL_ADD_ENTRY (newACLs, user_id,
                                bit_shift ("deny"[0], 2) + bit_shift ("deny"[1], 1) + "deny"[2],
                                0,
                                ODS.ODS_API.inheritance2int ("inheritance"));

  rc := DB.DBA.DAV_PROP_SET (path, ':virtacl', newACLs, uname, upassword);
  if (ODRIVE.WA.dav_error (rc))
    return ods_serialize_int_res (rc);
  return ods_serialize_int_res (1);
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API."briefcase.share.remove" (
  in path varchar,
  in "user" varchar,
  in "inheritance" varchar := 'all') __soap_http 'text/xml'
{
  declare uname, upassword varchar;
  declare rc, inst_id, user_id integer;
  declare ACLs, newACLs any;

  declare exit handler for sqlstate '*'
  {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };
  path := ODRIVE.WA.path_normalize (path, 'P');

  inst_id := ODS.ODS_API.briefcase_instance (path);
  if (not ods_check_auth (uname, inst_id))
    return ods_auth_failed ();

  user_id := ODRIVE.WA.account_id ("user");
  if (user_id = -1)
    signal ('22023', 'The user name does not exist');

  upassword := ODRIVE.WA.account_password (ODRIVE.WA.account_id (uname));
  ACLs := DB.DBA.DAV_PROP_GET (path, ':virtacl', uname, upassword);
  if (ODRIVE.WA.dav_error (ACLs))
    ods_serialize_int_res (ACLs);

  ACLs := ODRIVE.WA.acl_vector (ACLs);
  newACLs := WS.WS.ACL_CREATE();
  foreach (any ACL in ACLs) do
  {
    if ((ACL[0] <> user_id) or (ACL[1] <> ODS.ODS_API.inheritance2int ("inheritance")))
    {
      WS.WS.ACL_ADD_ENTRY (newACLs, ACL[0], ACL[2], 1, ACL[1]);
      WS.WS.ACL_ADD_ENTRY (newACLs, ACL[0], ACL[3], 0, ACL[1]);
    }
  }
  rc := DB.DBA.DAV_PROP_SET (path, ':virtacl', newACLs, uname, upassword);
  if (ODRIVE.WA.dav_error (rc))
    return ods_serialize_int_res (rc);
  return ods_serialize_int_res (1);
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API."briefcase.share.list.internal" (
  in path varchar,
  in uname varchar,
  in upassword varchar)
{
  declare N integer;
  declare ACLs any;
  declare sStream any;

  ACLs := DB.DBA.DAV_PROP_GET (path, ':virtacl', uname, upassword);
  if (ODRIVE.WA.dav_error (ACLs))
    return ACLs;

  ACLs := ODRIVE.WA.acl_vector (ACLs);
  sStream := string_output();
  http ('<shares>', sStream);
  foreach (any ACL in ACLs) do
  {
    http (sprintf ('<share user="%s" inheritance="%s" allow="%s" deny="%s" />', ODRIVE.WA.account_name (ACL[0]), ODS.ODS_API.inheritance2string (ACL[1]), ODS.ODS_API.permissions2string (ACL[2]), ODS.ODS_API.permissions2string (ACL[3])), sStream);
  }
  http ('</shares>', sStream);

  return string_output_string(sStream);
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API."briefcase.share.list" (
  in path varchar) __soap_http 'text/xml'
{
  declare uname, upassword varchar;
  declare inst_id integer;
  declare ACLs any;

  declare exit handler for sqlstate '*'
  {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };
  path := ODRIVE.WA.path_normalize (path, 'P');

  inst_id := ODS.ODS_API.briefcase_instance (path);
  if (not ods_check_auth (uname, inst_id))
    return ods_auth_failed ();

  upassword := ODRIVE.WA.account_password (ODRIVE.WA.account_id (uname));
  ACLs := ODS.ODS_API."briefcase.share.list.internal" (path, uname, upassword);
  if (ODRIVE.WA.dav_error (ACLs))
    ods_serialize_int_res (ACLs);

  http (sprintf ('<item path="%s">', path));
  http (ACLs);
  http ('</item>');

  return '';
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API."briefcase.options.set" (
	in inst_id integer := null,
	in options any) __soap_http 'text/xml'
{
	declare exit handler for sqlstate '*'
	{
		rollback work;
		return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
	};

	declare rc, account_id integer;
  declare conv, f_conv, f_conv_init any;
	declare uname varchar;
	declare optionsParams, settings any;
  declare st, msg any;

	if (not ods_check_auth2 (uname, inst_id, 'owner'))
		return ods_auth_failed ();

  if (not exists (select 1 from DB.DBA.WA_INSTANCE where WAI_ID = inst_id and WAI_TYPE_NAME = 'oDrive'))
    return ods_serialize_sql_error ('37000', 'The instance is not found');

	account_id := ODRIVE.WA.account_id (uname);
	optionsParams := split_and_decode (options, 0, '%\0,='); -- XXX: FIXME

	settings := ODRIVE.WA.settings (account_id);
	ODRIVE.WA.settings_init (settings);
  conv := cast (get_keyword ('conv', settings, '0') as integer);

  ODS.ODS_API.briefcase_setting_set (settings, optionsParams, 'chars');
  ODS.ODS_API.briefcase_setting_set (settings, optionsParams, 'rows');
  ODS.ODS_API.briefcase_setting_set (settings, optionsParams, 'tbLabels');
  ODS.ODS_API.briefcase_setting_set (settings, optionsParams, 'hiddens');
  ODS.ODS_API.briefcase_setting_set (settings, optionsParams, 'atomVersion');
  set_user_id ('dba');
  exec ('insert replacing ODRIVE.WA.SETTINGS (USER_ID, USER_SETTINGS) values(?, serialize (?))', st, msg, vector (account_id, settings));

	return ods_serialize_int_res (1);
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API."briefcase.options.get" (
	in inst_id integer := null) __soap_http 'text/xml'
{
	declare exit handler for sqlstate '*'
	{
		rollback work;
		return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
	};

	declare rc, account_id integer;
	declare uname varchar;
	declare settings any;

	if (not ods_check_auth2 (uname, inst_id, 'owner'))
		return ods_auth_failed ();

  if (not exists (select 1 from DB.DBA.WA_INSTANCE where WAI_ID = inst_id and WAI_TYPE_NAME = 'oDrive'))
    return ods_serialize_sql_error ('37000', 'The instance is not found');

	account_id := ODRIVE.WA.account_id (uname);
	settings := ODRIVE.WA.settings (account_id);
	ODRIVE.WA.settings_init (settings);

	http ('<settings>');
  http (ODS.ODS_API.briefcase_setting_xml (settings, 'chars'));
  http (ODS.ODS_API.briefcase_setting_xml (settings, 'rows'));
  http (ODS.ODS_API.briefcase_setting_xml (settings, 'tbLabels'));
  http (ODS.ODS_API.briefcase_setting_xml (settings, 'hiddens'));
  http (ODS.ODS_API.briefcase_setting_xml (settings, 'atomVersion'));
	http ('</settings>');

	return '';
}
;

grant select on WS.WS.SYS_DAV_RES to ODS_API;

grant execute on ODS.ODS_API."briefcase.list" to ODS_API;
grant execute on ODS.ODS_API."briefcase.resource.info" to ODS_API;
grant execute on ODS.ODS_API."briefcase.resource.get" to ODS_API;
grant execute on ODS.ODS_API."briefcase.resource.store" to ODS_API;
grant execute on ODS.ODS_API."briefcase.resource.delete" to ODS_API;
grant execute on ODS.ODS_API."briefcase.resource.vc.set" to ODS_API;
grant execute on ODS.ODS_API."briefcase.resource.vc.get" to ODS_API;
grant execute on ODS.ODS_API."briefcase.resource.vc.checkin" to ODS_API;
grant execute on ODS.ODS_API."briefcase.resource.vc.checkout" to ODS_API;
grant execute on ODS.ODS_API."briefcase.resource.vc.lock" to ODS_API;
grant execute on ODS.ODS_API."briefcase.resource.vc.info" to ODS_API;
grant execute on ODS.ODS_API."briefcase.resource.vc.versions" to ODS_API;
grant execute on ODS.ODS_API."briefcase.collection.info" to ODS_API;
grant execute on ODS.ODS_API."briefcase.collection.create" to ODS_API;
grant execute on ODS.ODS_API."briefcase.collection.delete" to ODS_API;
grant execute on ODS.ODS_API."briefcase.copy" to ODS_API;
grant execute on ODS.ODS_API."briefcase.move" to ODS_API;
grant execute on ODS.ODS_API."briefcase.property.list" to ODS_API;
grant execute on ODS.ODS_API."briefcase.property.set" to ODS_API;
grant execute on ODS.ODS_API."briefcase.property.remove" to ODS_API;
grant execute on ODS.ODS_API."briefcase.property.get" to ODS_API;
grant execute on ODS.ODS_API."briefcase.share.add" to ODS_API;
grant execute on ODS.ODS_API."briefcase.share.remove" to ODS_API;
grant execute on ODS.ODS_API."briefcase.share.list" to ODS_API;
grant execute on ODS.ODS_API."briefcase.options.set" to ODS_API;
grant execute on ODS.ODS_API."briefcase.options.get" to ODS_API;

use DB;
