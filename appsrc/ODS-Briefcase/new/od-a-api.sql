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
--!
-- \brief Get items list
--
-- Retrieve a list of items in a path.
--
-- \param path The path to the WebDAV folder to list.
--
-- \return An XML representation of the contents of the path. FIXME: link to the schema or a documentation of
-- the XML format.
--
-- \b Example:
-- \verbatim
-- $ curl -i "http://demo.openlinksw.com/ods/api/briefcase.list?path=/DAV/home/demo/Public&user_name=demo&password_hash=921q783d9e4cbdf5cvs343dafdfvrf6a4fh"
--
-- HTTP/1.1 200 OK
-- Server: Virtuoso/06.02.3129 (Solaris) x86_64-pc-solaris2.10-64  VDB
-- Connection: Keep-Alive
-- Date: Tue, 10 May 2011 11:32:52 GMT
-- Accept-Ranges: bytes
-- Content-Type: text/xml; charset="UTF-8"
-- Content-Length: 322
-- <items>
--   <item path="/DAV/home/demo/Public/demo.xml">
--     <name>demo.xml</name>
--     <mimeType>text/xml</mimeType>
--     <size>2277</size>
--     <owner>demo</owner>
--     <group>demo</group>
--     <permissions>rw-r-----</permissions>
--     <modification>2010-12-30</modification>
--   </item>
-- <items>
-- \endverbatim
--/
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
--!
-- \brief Get information about a resource.
--
-- Retrieve detailed information about a WebDAV resource.
--
-- \param path The path to the resource in question.
--
-- \return An XML document detailing the resource in question. FIXME: document schema.
--
-- \b Example:
-- \verbatim
-- $ curl -i "http://demo.openlinksw.com/ods/api/briefcase.resource.info?path=/DAV/home/demo/demo.xml&user_name=demo&password_hash=921q783d9e4cbdf5cvs343dafdfvrf6a4fh"
--
-- HTTP/1.1 200 OK
-- Server: Virtuoso/06.02.3129 (Solaris) x86_64-pc-solaris2.10-64  VDB
-- Connection: Keep-Alive
-- Date: Tue, 10 May 2011 11:32:52 GMT
-- Accept-Ranges: bytes
-- Content-Type: text/xml; charset="UTF-8"
-- Content-Length: 322
--
-- <item path="/DAV/home/demo/demo.xml">
--   <name>demo.xml</name>
--   <mimeType>text/xml</mimeType>
--   <size>2277</size>
--   <owner>demo</owner>
--   <group>demo</group>
--   <permissions>rw-r-----</permissions>
--   <modification>2010-12-30</modification>
--   <creation>2010-12-30</creation>
--   <properties></properties>
--   <shares></shares>
-- </item>
-- \endverbatim
--/
create procedure ODS.ODS_API."briefcase.resource.info" (
  in path varchar) __soap_http 'text/xml'
{
  return ODS.ODS_API."briefcase.info" (path, 'R');
}
;

-------------------------------------------------------------------------------
--
--!
-- \brief Change the state of version control on a resource.
--
-- ODS supports version control for files as discussed in \ref ods_briefcase_version_control. This
-- method allows to enable or disable version control on single resources.
--
-- \param path The path to the resource in question.
-- \param state Value indicating whether version control should be enabled ("on") or disabled ("off").
--
-- \return An error code stating the success of the command execution as detailed in \ref ods_response_format_result_code.
--
-- \b Example:
-- \verbatim
-- $  curl -i "http://demo.openlinksw.com/ods/api/briefcase.resource.vc.set?path=/DAV/home/demo/demo.xml&state=on&user_name=demo&password_hash=921q783d9e4cbdf5cvs343dafdfvrf6a4fh"
--
-- HTTP/1.1 200 OK
-- Server: Virtuoso/06.02.3129 (Solaris) x86_64-pc-solaris2.10-64  VDB
-- Connection: Keep-Alive
-- Date: Tue, 10 May 2011 11:51:49 GMT
-- Accept-Ranges: bytes
-- Content-Type: text/xml; charset="UTF-8"
-- Content-Length: 57
--
-- <result>
--   <code>1</code>
--   <message>Success</message>
-- </result>
-- \endverbatim
--/
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
--!
-- \brief Get a specific version of a version controlled resource.
--
-- If a resource has version control enabled this method allows to retrieve all versions that have
-- been checked in.
--
-- \param path The path of the resource to get.
-- \param version The version to get. This can either be an exact numerical version to get or the special version 'last'
--                which will fetch the last version that has been checked in. FIXME: is this correct?
--
-- \return The content of the resource at the time it was checked in with the requested version.
--
-- \sa briefcase.resource.vc.set, briefcase.resource.vc.checkin
--
-- \b Example:
-- \verbatim
-- $ curl -i "http://demo.openlinksw.com/ods/api/briefcase.resource.vc.get?path=/DAV/home/demo/demo.xml&version=last&user_name=demo&password_hash=921q783d9e4cbdf5cvs343dafdfvrf6a4fh"
--
-- HTTP/1.1 200 OK
-- Server: Virtuoso/06.02.3129 (Solaris) x86_64-pc-solaris2.10-64  VDB
-- Connection: Keep-Alive
-- Date: Tue, 10 May 2011 12:01:38 GMT
-- Accept-Ranges: bytes
-- Content-Type: text/xml
-- Content-Length: 2277
--
-- <?xml version="1.0" ?>
-- <?xml-stylesheet type="text/xsl" href="/DAV/JS/xslt/formview.xsl"?>
-- <form showajax="1" >
--         <ds name="new datasource" type="1" pagesize="30">
--                 <connection type="1" endpoint="/XMLA" dsn="DSN=ora10ma-hr" nocred="0" uid="0"/>
--                 <options table="" limit="30" cursortype="0"/>
--                 <query><![CDATA[]]></query>
--                 <outputFields>
--                 </outputFields>
--                 <inputFields>
--                 </inputFields>
--                 <selfFields>
--                 </selfFields>
--                 <masterFields>
--                 </masterFields>
--                 <masterDSs>
--                 </masterDSs>
--                 <types>
--                 </types>
--         </ds>
-- [...]
-- </form>
-- \endverbatim
--/
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
--!
-- \brief Check-in resource.
--
-- FIXME: what does this do?
--
-- \param path The path to the resource to check in.
--
-- \return An error code stating the success of the command execution as detailed in \ref ods_response_format_result_code.
--
-- \b Example:
-- \verbatim
-- $ curl -i "http://demo.openlinksw.com/ods/api/briefcase.resource.vc.checkin?path=/DAV/home/demo/demo.xml&user_name=demo&password_hash=921q783d9e4cbdf5cvs343dafdfvrf6a4fh"
--
-- HTTP/1.1 200 OK
-- Server: Virtuoso/06.02.3129 (Solaris) x86_64-pc-solaris2.10-64  VDB
-- Connection: Keep-Alive
-- Date: Tue, 10 May 2011 11:57:47 GMT
-- Accept-Ranges: bytes
-- Content-Type: text/xml; charset="UTF-8"
-- Content-Length: 57
--
-- <result>
--   <code>1</code>
--   <message>Success</message>
-- </result>
-- \endverbatim
--/
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
--!
-- \brief Check-out a resource.
--
-- FIXME: What does this do?
--
-- \param path The path to the resource to check out.
--
-- \return An error code stating the success of the command execution as detailed in \ref ods_response_format_result_code.
--
-- \b Example:
-- \verbatim
-- $ curl -i "http://demo.openlinksw.com/ods/api/briefcase.resource.vc.checkout?path=/DAV/home/demo/demo.xml&user_name=demo&password_hash=921q783d9e4cbdf5cvs343dafdfvrf6a4fh"
--
-- HTTP/1.1 200 OK
-- Server: Virtuoso/06.02.3129 (Solaris) x86_64-pc-solaris2.10-64  VDB
-- Connection: Keep-Alive
-- Date: Tue, 10 May 2011 11:56:28 GMT
-- Accept-Ranges: bytes
-- Content-Type: text/xml; charset="UTF-8"
-- Content-Length: 57
--
-- <result>
--   <code>1</code>
--   <message>Success</message>
-- </result>
-- \endverbatim
--/
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
--!
-- \brief Lock a resource.
--
-- FIXME: explain what locking is.
--
-- \param path The path to the resource to lock or unlock.
-- \param state Can be 'on' or 'off' to either lock or unlock the resource.
--
-- \return An error code stating the success of the command execution as detailed in \ref ods_response_format_result_code.
--
-- \b Example:
-- \verbatim
-- $ curl -i "http://demo.openlinksw.com/ods/api/briefcase.resource.vc.lock?path=/DAV/home/demo/demo.xml&user_name=demo&password_hash=921q783d9e4cbdf5cvs343dafdfvrf6a4fh"
--
-- HTTP/1.1 200 OK
-- Server: Virtuoso/06.02.3129 (Solaris) x86_64-pc-solaris2.10-64  VDB
-- Connection: Keep-Alive
-- Date: Tue, 10 May 2011 11:58:44 GMT
-- Accept-Ranges: bytes
-- Content-Type: text/xml; charset="UTF-8"
-- Content-Length: 57
--
-- <result>
--   <code>1</code>
--   <message>Success</message>
-- </result>\endverbatim
--/
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
--!
-- \brief Get resource version control details
--
-- ODS supports version control for files as discussed in \ref ods_briefcase_version_control. This method
-- allows to retrieve information about the version control status of a resource.
--
-- \param path Path to the resource in question.
--
-- \return The state of version control for the given file. FIXME: document the XML schema that is used.
--
-- \b Example:
-- \verbatim
-- $ curl -i "http://demo.openlinksw.com/ods/api/briefcase.resource.vc.info?path=/DAV/home/demo/demo.xml&user_name=demo&password_hash=921q783d9e4cbdf5cvs343dafdfvrf6a4fh"
--
-- HTTP/1.1 200 OK
-- Server: Virtuoso/06.02.3129 (Solaris) x86_64-pc-solaris2.10-64  VDB
-- Connection: Keep-Alive
-- Date: Tue, 10 May 2011 11:53:56 GMT
-- Accept-Ranges: bytes
-- Content-Type: text/xml; charset="UTF-8"
-- Content-Length: 173
--
-- <item path="/DAV/home/demo/demo.xml">
--   <versionControl>
--     <enabled>ON</enabled>
--     <autoVersioning>OFF</autoVersioning>
--     <state>Check-In</state>
--     <lock>OFF</lock>
--   </versionControl>
-- </item>
-- \endverbatim
--/
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
--!
-- \brief Get information on the available versions of a resource.
--
-- Retrieve details on the available versions of a resource in the WebDAV. The resource
-- must be version controlled.
--
-- \param path The path to the versioned resource.
--
-- \return A listing of all available versions encoded as XML. FIXME: describe the scheme
--
-- \sa briefcase.resource.vc.set
--
-- \b Example:
-- \verbatim
-- $ curl -i "http://demo.openlinksw.com/ods/api/briefcase.resource.vc.versions?path=/DAV/home/demo/demo.xml&user_name=demo&password_hash=921q783d9e4cbdf5cvs343dafdfvrf6a4fh"
--
-- HTTP/1.1 200 OK
-- Server: Virtuoso/06.02.3129 (Solaris) x86_64-pc-solaris2.10-64  VDB
-- Connection: Keep-Alive
-- Date: Tue, 10 May 2011 11:59:49 GMT
-- Accept-Ranges: bytes
-- Content-Type: text/xml; charset="UTF-8"
-- Content-Length: 259
--
-- <item path="/DAV/home/demo/demo.xml">
--   <versions>
--     <version path="/DAV/home/demo/VVC/demo.xml/1" number="1" size="2277" modification="2011-05-10" />
--     <version path="/DAV/home/demo/VVC/demo.xml/2" number="2" size="2277" modification="2011-05-10" />
--   </versions>
-- </item>
-- \endverbatim
--/
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
--!
-- \brief Get the contents of a resource.
--
-- Retrieve the actual resource from WebDAV, ie. download the file.
--
-- \param path The path to the resource to retrieve.
--
-- \return The contents of the file.
--
-- \b Example:
-- \verbatim
-- $ curl -i "http://demo.openlinksw.com/ods/api/briefcase.resource.get?path=/DAV/home/demo/demo.xml&user_name=demo&password_hash=921q783d9e4cbdf5cvs343dafdfvrf6a4fh"
--
-- HTTP/1.1 200 OK
-- Server: Virtuoso/06.02.3129 (Solaris) x86_64-pc-solaris2.10-64  VDB
-- Connection: Keep-Alive
-- Date: Tue, 10 May 2011 11:45:08 GMT
-- Accept-Ranges: bytes
-- Content-Type: text/xml
-- Content-Length: 2277
--
-- <?xml version="1.0" ?>
-- <?xml-stylesheet type="text/xsl" href="/DAV/JS/xslt/formview.xsl"?>
-- <form showajax="1" >
--         <ds name="new datasource" type="1" pagesize="30">
--                 <connection type="1" endpoint="/XMLA" dsn="DSN=ora10ma-hr" nocred="0" uid="0"/>
--                 <options table="" limit="30" cursortype="0"/>
--                 <query><![CDATA[]]></query>
--                 <outputFields>
--                 </outputFields>
--
-- [...]
--
-- </form>
-- \endverbatim
--/
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
--!
-- \brief Store/upload a resource.
--
-- Store a resource/file in the WebDAV system.
--
-- FIXME: I suppose using magic folders we can also upload RDF content and maybe more. This should be detailed here.
--
-- \param path The target path of the newly created resource.
-- \param content The content of the resource. FIXME: byte64 encoded for binary files?
-- \param type The type of the resource. FIXME: what does this mean? mimetype?
-- \param permissions The permissions of the newly created resource as detailed in \ref ods_briefcase_resource_permissions.
--
-- \return An error code stating the success of the command execution as detailed in \ref ods_response_format_result_code.
--
-- \b Example:
-- \verbatim
-- $ curl -i "http://demo.openlinksw.com/ods/api/briefcase.resource.store?path=/DAV/home/demo/mysimpletext.xml&content=test&type=xml&user_name=demo&password_hash=921q783d9e4cbdf5cvs343dafdfvrf6a4fh"
--
-- HTTP/1.1 200 OK
-- Server: Virtuoso/06.02.3129 (Solaris) x86_64-pc-solaris2.10-64  VDB
-- Connection: Keep-Alive
-- Date: Tue, 10 May 2011 11:47:16 GMT
-- Accept-Ranges: bytes
-- Content-Type: text/xml; charset="UTF-8"
-- Content-Length: 61
--
-- <result>
--   <code>16795</code>
--   <message>Success</message>
-- </result>
-- \endverbatim
--/
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
--!
-- \brief Delete a WebDAV resource.
--
-- \param path The path to the resource to be deleted.
--
-- \return An error code stating the success of the command execution as detailed in \ref ods_response_format_result_code.
--
-- \b Example:
-- \verbatim
-- $ curl -i "http://demo.openlinksw.com/ods/api/briefcase.resource.delete?path=/DAV/home/demo/mysimpletext.xml&user_name=demo&password_hash=921q783d9e4cbdf5cvs343dafdfvrf6a4fh"
--
-- HTTP/1.1 200 OK
-- Server: Virtuoso/06.02.3129 (Solaris) x86_64-pc-solaris2.10-64  VDB
-- Connection: Keep-Alive
-- Date: Tue, 10 May 2011 11:48:52 GMT
-- Accept-Ranges: bytes
-- Content-Type: text/xml; charset="UTF-8"
-- Content-Length: 57
--
-- <result>
--   <code>1</code>
--   <message>Success</message>
-- </result>
-- \endverbatim
--/
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
--!
-- \brief Get details about a WebDAV collection.
--
-- \param path The path to the collection.
--
-- \return The details of the collection encoded as XML.
--
-- \b Example:
-- \verbatim
-- $ curl -i "http://demo.openlinksw.com/ods/api/briefcase.collection.info?path=/DAV/home/demo/mytest&user_name=demo&password_hash=921q783d9e4cbdf5cvs343dafdfvrf6a4fh"
--
-- HTTP/1.1 200 OK
-- Server: Virtuoso/06.02.3129 (Solaris) x86_64-pc-solaris2.10-64  VDB
-- Connection: Keep-Alive
-- Date: Tue, 10 May 2011 12:08:13 GMT
-- Accept-Ranges: bytes
-- Content-Type: text/xml; charset="UTF-8"
-- Content-Length: 309
--
-- <item path="/DAV/home/demo/mytest/">
--   <name>mytest</name>
--   <mimeType>dav/unix-directory</mimeType>
--   <owner>demo</owner>
--   <group>demo</group>
--   <permissions>rw-r--r--</permissions>
--   <modification>2011-05-10</modification>
--   <creation>2011-05-10</creation>
--   <properties></properties>
--   <shares></shares>
-- </item>
-- \endverbatim
--/
create procedure ODS.ODS_API."briefcase.collection.info" (
  in path varchar) __soap_http 'text/xml'
{
  return ODS.ODS_API."briefcase.info" (path, 'C');
}
;

-------------------------------------------------------------------------------
--
--!
-- \brief Create a new WebDAV collection/folder.
--
-- \param path The path of the collection to create.
-- \param permissions The permissions of the newly created collection as detailed in \ref ods_briefcase_resource_permissions
--
-- \return An error code stating the success of the command execution as detailed in \ref ods_response_format_result_code.
--
-- \sa briefcase.collection.delete
--
-- \b Example:
-- \verbatim
-- $  curl -i "http://demo.openlinksw.com/ods/api/briefcase.collection.create?path=/DAV/home/demo/mytest&user_name=demo&password_hash=921q783d9e4cbdf5cvs343dafdfvrf6a4fh"
--
-- HTTP/1.1 200 OK
-- Server: Virtuoso/06.02.3129 (Solaris) x86_64-pc-solaris2.10-64  VDB
-- Connection: Keep-Alive
-- Date: Tue, 10 May 2011 12:07:07 GMT
-- Accept-Ranges: bytes
-- Content-Type: text/xml; charset="UTF-8"
-- Content-Length: 60
--
-- <result>
--   <code>1317</code>
--   <message>Success</message>
-- </result>\endverbatim
--/
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
--!
-- \brief Delete a WebDAV collection.
--
-- \param path The path to the collection to be deleted.
--
-- \return An error code stating the success of the command execution as detailed in \ref ods_response_format_result_code.
--
-- \sa briefcase.collection.create
--
-- \b Example:
-- \verbatim
-- $ curl -i "http://demo.openlinksw.com/ods/api/briefcase.collection.delete?path=/DAV/home/demo/mytest&user_name=demo&password_hash=921q783d9e4cbdf5cvs343dafdfvrf6a4fh"
--
-- HTTP/1.1 200 OK
-- Server: Virtuoso/06.02.3129 (Solaris) x86_64-pc-solaris2.10-64  VDB
-- Connection: Keep-Alive
-- Date: Tue, 10 May 2011 12:09:31 GMT
-- Accept-Ranges: bytes
-- Content-Type: text/xml; charset="UTF-8"
-- Content-Length: 57
--
-- <result>
--   <code>1</code>
--   <message>Success</message>
-- </result>
-- \endverbatim
--/
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
--!
-- \brief Copy a WebDAV resource.
--
-- Copies a resource or a collection to a new path. Collections are copied recursively.
--
-- \param from_path The resource path.
-- \param to_path The target path. FIXME: is this like in UNIX shells or is this the new full path of the resource?
-- \param overwrite Flag to indicate if an already existing resource at \p to_path should be overwritten. If 0 then then
--                  call will fail in case that a resource exists.
-- \param permissions The permissions of the newly created resource as detailed in \ref ods_briefcase_resource_permissions.
--
-- \return An error code stating the success of the command execution as detailed in \ref ods_response_format_result_code.
--
-- \b Example:
-- \verbatim
-- $ curl -i "http://demo.openlinksw.com/ods/api/briefcase.copy?from_path=/DAV/home/demo/t1/&to_path=/DAV/home/demo/t2/&user_name=demo&password_hash=921q783d9e4cbdf5cvs343dafdfvrf6a4fh"
--
-- HTTP/1.1 200 OK
-- Server: Virtuoso/06.02.3129 (Solaris) x86_64-pc-solaris2.10-64  VDB
-- Connection: Keep-Alive
-- Date: Tue, 10 May 2011 12:13:41 GMT
-- Accept-Ranges: bytes
-- Content-Type: text/xml; charset="UTF-8"
-- Content-Length: 57
--
-- <result>
--   <code>1</code>
--   <message>Success</message>
-- </result>
-- \endverbatim
--/
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
--!
-- \brief Move a WebDAV resource.
--
-- Move a resource or collection within the WebDAV tree.
--
-- \param from_path The resource path.
-- \param to_path The target path. FIXME: is this like in UNIX shells or is this the new full path of the resource?
-- \param overwrite Flag to indicate if an already existing resource at \p to_path should be overwritten. If 0 then then
--                  call will fail in case that a resource exists.
--
-- \return An error code stating the success of the command execution as detailed in \ref ods_response_format_result_code.
--
-- \b Example:
-- \verbatim
-- $ curl -i "http://demo.openlinksw.com/ods/api/briefcase.move?from_path=/DAV/home/demo/t1/&to_path=/DAV/home/demo/t2/&user_name=demo&password_hash=921q783d9e4cbdf5cvs343dafdfvrf6a4fh"
--
-- HTTP/1.1 200 OK
-- Server: Virtuoso/06.02.3129 (Solaris) x86_64-pc-solaris2.10-64  VDB
-- Connection: Keep-Alive
-- Date: Tue, 10 May 2011 12:15:33 GMT
-- Accept-Ranges: bytes
-- Content-Type: text/xml; charset="UTF-8"
-- Content-Length: 57
--
-- <result>
--   <code>1</code>
--   <message>Success</message>
-- </result>
-- \endverbatim
--/
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
--!
-- \brief List all WebDAV properties of a resource.
--
-- \param path The path of the resource to list properties for.
-- \param mask FIXME: what is he mask?
--
-- \return All properties for the given resource path encoded as XML. FIXME: explain the schema
--
-- \sa briefcase.property.set, briefcase.property.get, briefcase.property.remove
--
-- \b Example:
-- \verbatim
-- $ curl -i "http://demo.openlinksw.com/ods/api/briefcase.property.list?path=/DAV/home/demo/tmp1/&user_name=demo&password_hash=921q783d9e4cbdf5cvs343dafdfvrf6a4fh"
--
-- HTTP/1.1 200 OK
-- Server: Virtuoso/06.02.3129 (Solaris) x86_64-pc-solaris2.10-64  VDB
-- Connection: Keep-Alive
-- Date: Tue, 10 May 2011 12:44:46 GMT
-- Accept-Ranges: bytes
-- Content-Type: text/xml; charset="UTF-8"
-- Content-Length: 100
--
-- <item path="/DAV/home/demo/tmp1/">
--   <properties>
--     <property name="test">1</property>
--   </prop
-- \endverbatim
--/
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
--!
-- \brief Create a new WebDAV property or update an existing one.
--
-- \param path The path of the resource which should be modified.
-- \param name The name of the property to change.
-- \param value The value of the property to change.
--
-- \return An error code stating the success of the command execution as detailed in \ref ods_response_format_result_code.
--
-- \sa briefcase.property.list, briefcase.property.get, briefcase.property.remove
--
-- \b Example:
-- \verbatim
-- $ curl -i "http://demo.openlinksw.com/ods/api/briefcase.property.set?path=/DAV/home/demo/tmp1/&name=test&value=1&user_name=demo&password_hash=921q783d9e4cbdf5cvs343dafdfvrf6a4fh"
--
-- HTTP/1.1 200 OK
-- Server: Virtuoso/06.02.3129 (Solaris) x86_64-pc-solaris2.10-64  VDB
-- Connection: Keep-Alive
-- Date: Tue, 10 May 2011 12:42:46 GMT
-- Accept-Ranges: bytes
-- Content-Type: text/xml; charset="UTF-8"
-- Content-Length: 57
--
-- <result>
--   <code>1</code>
--   <message>Success</message>
-- </result>
-- \endverbatim
--/
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
--!
-- \brief Remove a WebDAV property.
--
-- \param path The path of the resource.
-- \param name The name of the property to remove.
--
-- \return An error code stating the success of the command execution as detailed in \ref ods_response_format_result_code.
--
-- \sa briefcase.property.list, briefcase.property.get, briefcase.property.set
--
-- \b Example:
-- \verbatim
-- $ curl -i "http://demo.openlinksw.com/ods/api/briefcase.property.remove?path=/DAV/home/demo/tmp1/&name=test&user_name=demo&password_hash=921q783d9e4cbdf5cvs343dafdfvrf6a4fh"
--
-- HTTP/1.1 200 OK
-- Server: Virtuoso/06.02.3129 (Solaris) x86_64-pc-solaris2.10-64  VDB
-- Connection: Keep-Alive
-- Date: Tue, 10 May 2011 12:54:12 GMT
-- Accept-Ranges: bytes
-- Content-Type: text/xml; charset="UTF-8"
-- Content-Length: 57
--
-- <result>
--   <code>1</code>
--   <message>Success</message>
-- </result>
-- \endverbatim
--/
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
--!
-- \brief Get the value of a WebDAV property
--
-- \param path The path of the resource.
-- \param name The name of the property to return.
--
-- \return The value of the requested property.
--
-- \sa briefcase.property.list
--
-- \b Example:
-- \verbatim
-- $ curl -i "http://demo.openlinksw.com/ods/api/briefcase.property.get?path=/DAV/home/demo/tmp1/&name=test&user_name=demo&password_hash=921q783d9e4cbdf5cvs343dafdfvrf6a4fh"
--
-- HTTP/1.1 200 OK
-- Server: Virtuoso/06.02.3129 (Solaris) x86_64-pc-solaris2.10-64  VDB
-- Connection: Keep-Alive
-- Date: Tue, 10 May 2011 12:51:20 GMT
-- Accept-Ranges: bytes
-- Content-Type: text/xml; charset="UTF-8"
-- Content-Length: 1
--
-- 1
-- \endverbatim
--/
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
--!
-- \brief Share a WebDAV resource with a user.
--
-- \param path The path to the resource to share.
-- \param user The user to share the resource with.
-- \param inheritance The way the given rights should be propagated to children of the given path (in case of a collection).
--                    - \p 'object' will only change the permissions on the resource itself
--                    - \p 'all' will recursively update permissions on all children
--                    - \p 'children' will only update permissions on direct children. FIXME: is this correct?
-- \param allow The actions the \p user should be allowed to perform. This is a UNIX style permission mask string consisting
--              of three chars \p "rwx", referring to read, write, and execute permissions respectively. Each of these
--              permissions can be granted by writing the character or not granted by writing a dash \p - instead. Example:
--              \p "r--" would grant only read rights while it does not make any changes to the write and execute rights.
-- \param deny The permissions to deny the user. The value is the same as with \p allow except that the given rights are
--             revoked instead of granted. Thus, specifying \p "r--" would revoke read rights while leaving the write and
--             execute rights untouched.
--
-- \return An error code stating the success of the command execution as detailed in \ref ods_response_format_result_code.
--
-- \sa briefcase.share.remove, briefcase.share.list
--
-- \b Example:
-- \verbatim
-- $ curl -i "http://demo.openlinksw.com/ods/api/briefcase.share.add?path=/DAV/home/demo/tmp1/&user=test1&user_name=demo&password_hash=921q783d9e4cbdf5cvs343dafdfvrf6a4fh"
--
-- HTTP/1.1 200 OK
-- Server: Virtuoso/06.02.3129 (Solaris) x86_64-pc-solaris2.10-64  VDB
-- Connection: Keep-Alive
-- Date: Tue, 17 May 2011 11:49:52 GMT
-- Accept-Ranges: bytes
-- Content-Type: text/xml; charset="UTF-8"
-- Content-Length: 57
--
-- <result>
--   <code>1</code>
--   <message>Success</message>
-- </result>
-- \endverbatim
--/
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
--!
-- \brief Remove a share from a resource.
--
-- Remove a previously created share for a specific resource and user.
--
-- \param path The path to the resource to remove the share from.
-- \param user The user to revoke the share from.
-- \param inheritance The way the given rights should be propagated to children of the given path (in case of a collection).
--                    - \p 'object' will only change the permissions on the resource itself
--                    - \p 'all' will recursively update permissions on all children
--                    - \p 'children' will only update permissions on direct children. FIXME: is this correct?
--
-- \return An error code stating the success of the command execution as detailed in \ref ods_response_format_result_code.
--
-- \sa briefcase.share.add, briefcase.share.list
--
-- \b Example:
-- \verbatim
-- $ curl -i "http://demo.openlinksw.com/ods/api/briefcase.share.remove?path=/DAV/home/demo/tmp1/&user=demo&user_name=demo&password_hash=921q783d9e4cbdf5cvs343dafdfvrf6a4fh"
--
-- HTTP/1.1 200 OK
-- Server: Virtuoso/06.02.3129 (Solaris) x86_64-pc-solaris2.10-64  VDB
-- Connection: Keep-Alive
-- Date: Tue, 10 May 2011 13:07:45 GMT
-- Accept-Ranges: bytes
-- Content-Type: text/xml; charset="UTF-8"
-- Content-Length: 57
--
-- <result>
--   <code>1</code>
--   <message>Success</message>
-- </result>
-- \endverbatim
--/
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
--!
-- \brief List all the shares on a resource.
--
-- \param path The path to the resource for which shares should be listed.
--
-- \return The list of all shares created on the given resource encoded as XML.
--
-- \sa briefcase.share.add
--
-- \b Example:
-- \verbatim
-- $ curl -i "http://demo.openlinksw.com/ods/api/briefcase.share.list?path=/DAV/home/demo/tmp1/&user_name=demo&password_hash=921q783d9e4cbdf5cvs343dafdfvrf6a4fh"
--
-- HTTP/1.1 200 OK
-- Server: Virtuoso/06.02.3129 (Solaris) x86_64-pc-solaris2.10-64  VDB
-- Connection: Keep-Alive
-- Date: Tue, 17 May 2011 11:50:55 GMT
-- Accept-Ranges: bytes
-- Content-Type: text/xml; charset="UTF-8"
-- Content-Length: 121
--
-- <item path="/DAV/home/demo/tmp1/">
--   <shares>
--     <share user="test1" inheritance="all" allow="rw-" deny="---" />
--   </shares>
-- </item>
-- \endverbatim
--/
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
--!
-- \brief Set an option of an ODS Briefcase instance.
--
-- \param inst_id The id of the Briefcase instance. See \ref ods_instance_id for details.
-- \param options A comma-separated list of \p "key=value" pairs. Supported keys are:
-- - chars
-- - rows
-- - tbLabels
-- - hiddens
-- - atomVersion
-- FIXME: what are these options?
--
-- \return An error code stating the success of the command execution as detailed in \ref ods_response_format_result_code.
--
-- \sa briefcase.options.get
--
-- \b Example:
-- \verbatim
-- $ curl -i "http://demo.openlinksw.com/ods/api/briefcase.options.set?inst_id=6&options=rows%3D5&user_name=demo&password_hash=921q783d9e4cbdf5cvs343dafdfvrf6a4fh"
--
-- HTTP/1.1 200 OK
-- Server: Virtuoso/06.02.3129 (Solaris) x86_64-pc-solaris2.10-64  VDB
-- Connection: Keep-Alive
-- Date: Tue, 10 May 2011 13:14:10 GMT
-- Accept-Ranges: bytes
-- Content-Type: text/xml; charset="UTF-8"
-- Content-Length: 57
--
-- <result>
--   <code>1</code>
--   <message>Success</message>
-- </result>
-- \endverbatim
--/
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
--!
-- \brief Get The option values of a ODS Briefcase instance.
--
-- \param inst_id The id of the Briefcase instance. See \ref ods_instance_id for details.
--
-- \return A list of the option values encoded as XML.
--
-- \sa briefcase.options.set
--
-- \b Example:
-- \verbatim
-- $ curl -i "http://demo.openlinksw.com/ods/api/briefcase.options.get?inst_id=6&user_name=demo&password_hash=921q783d9e4cbdf5cvs343dafdfvrf6a4fh"
--
-- HTTP/1.1 200 OK
-- Server: Virtuoso/06.02.3129 (Solaris) x86_64-pc-solaris2.10-64  VDB
-- Connection: Keep-Alive
-- Date: Tue, 10 May 2011 13:11:48 GMT
-- Accept-Ranges: bytes
-- Content-Type: text/xml; charset="UTF-8"
-- Content-Length: 125
--
-- <settings>
--   <chars>60</chars>
--   <rows>10</rows>
--   <tbLabels>1</tbLabels>
--   <hiddens>.</hiddens>
--   <atomVersion>1.0</atomVersion>
-- </settings>
-- \endverbatim
--/
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
