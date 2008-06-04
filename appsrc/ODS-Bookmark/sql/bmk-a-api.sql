--
--  $Id$
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2008 OpenLink Software
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
create procedure ODS.ODS_API."bookmark.get" (
  in bookmark_id integer) __soap_http 'text/xml'
{
  declare exit handler for sqlstate '*'
  {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };

  declare uname varchar;
  declare inst_id integer;
  declare q, iri varchar;

  inst_id := (select BD_DOMAIN_ID from BMK.WA.BOOKMARK_DOMAIN where BD_ID = bookmark_id);
  if (not ods_check_auth (uname, inst_id, 'author'))
    return ods_auth_failed ();
  iri := SIOC..bmk_post_iri (inst_id, bookmark_id);
  q := sprintf ('describe <%s> from <%s>', iri, SIOC..get_graph ());
  exec_sparql (q);
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API."bookmark.new" (
  in inst_id integer,
  in uri varchar,
  in name varchar,
  in description varchar := null,
  in tags varchar := null,
  in folder_id integer := null) __soap_http 'text/xml'
{
  declare exit handler for sqlstate '*'
  {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };

  declare rc integer;
  declare uname varchar;

  if (not ods_check_auth (uname, inst_id, 'author'))
    return ods_auth_failed ();

  rc := BMK.WA.bookmark_update (
          -1,
          inst_id,
          uri,
          name,
          description,
          tags,
          folder_id);

  return ods_serialize_int_res (rc);
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API."bookmark.edit" (
  in bookmark_id integer,
  in uri varchar,
  in name varchar,
  in description varchar := null,
  in tags varchar := null,
  in folder_id integer := null) __soap_http 'text/xml'
{
  declare exit handler for sqlstate '*'
  {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };

  declare rc integer;
  declare uname varchar;
  declare inst_id integer;

  inst_id := (select BD_DOMAIN_ID from BMK.WA.BOOKMARK_DOMAIN where BD_ID = bookmark_id);
  if (not ods_check_auth (uname, inst_id, 'author'))
    return ods_auth_failed ();

  rc := BMK.WA.bookmark_update (
          bookmark_id,
          inst_id,
          uri,
          name,
          description,
          tags,
          folder_id);

  return ods_serialize_int_res (rc);
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API."bookmark.delete" (
  in bookmark_id integer) __soap_http 'text/xml'
{
  declare rc integer;
  declare uname varchar;
  declare inst_id integer;

  inst_id := (select BD_DOMAIN_ID from BMK.WA.BOOKMARK_DOMAIN where BD_ID = bookmark_id);
  if (not ods_check_auth (uname, inst_id, 'author'))
    return ods_auth_failed ();

  delete from BMK.WA.BOOKMARK_DOMAIN where BD_ID = bookmark_id;
  rc := row_count ();

  return ods_serialize_int_res (rc);
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API."bookmark.folder.new" (
  in inst_id integer,
  in path varchar) __soap_http 'text/xml'
{
  declare exit handler for sqlstate '*'
  {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };

  declare rc integer;
  declare uname varchar;

  if (not ods_check_auth (uname, inst_id, 'author'))
    return ods_auth_failed ();

  rc := BMK.WA.folder_id (inst_id, path);

  return ods_serialize_int_res (rc);
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API."bookmark.folder.delete" (
  in inst_id integer,
  in path varchar) __soap_http 'text/xml'
{
  declare exit handler for sqlstate '*'
  {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };

  declare rc integer;
  declare uname varchar;

  if (not ods_check_auth (uname, inst_id, 'author'))
    return ods_auth_failed ();

  delete from BMK.WA.FOLDER where F_DOMAIN_ID = inst_id and F_PATH = path;
  rc := row_count ();

  return ods_serialize_int_res (rc);
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API."bookmark.import" (
  in inst_id integer,
  in source varchar,
  in sourceType varchar,
  in tags varchar := '')  __soap_http 'text/xml'
{
  declare exit handler for sqlstate '*'
  {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };

  declare uname, passwd varchar;
  declare content varchar;
  declare user_id integer;
  declare tmp any;

  if (not ods_check_auth (uname, inst_id, 'author'))
    return ods_auth_failed ();

  -- get content
  if (lcase (sourceType) = 'string')
  {
    content := source;
  }
  else if (lcase (sourceType) = 'webdav')
  {
    passwd := __user_password (uname);
    content := BMK.WA.dav_content (BMK.WA.host_url () || source, uname, passwd);
  }
  else if (lcase (sourceType) = 'url')
  {
    content := BMK.WA.dav_content (source);
  }
  else
  {
	  signal ('BMK04', 'The source type must be string, WebDAV or URL.');
  }

  tags := trim (tags);
  BMK.WA.test (tags, vector ('name', 'Tags', 'class', 'tags'));
  tmp := BMK.WA.tags2vector (tags);
  tmp := BMK.WA.vector_unique (tmp);
  tags := BMK.WA.vector2tags (tmp);

  -- import content
  if (is_empty_or_null (content))
    signal ('BMK04', 'Bad import source!');

  BMK.WA.bookmark_import (content, inst_id, user_id, null, tags, null);

  return ods_serialize_int_res (1);
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API."bookmark.export" (
  in inst_id integer,
  in contentType varchar := 'Netscape') __soap_http 'text/plain'
{
  declare exit handler for sqlstate '*'
  {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };

  declare uname varchar;

  if (not ods_check_auth (uname, inst_id, 'author'))
    return ods_auth_failed ();

  if (lcase (contentType) not in ('netscape', 'xbel'))
  	signal ('BMK05', 'The content type must be Netscape or XBEL.');

  if (lcase (contentType) = 'netscape')
  {
    contentType := 'Netscape';
  } else {
    contentType := 'XBEL';
  }
  http (BMK.WA.dav_content (sprintf('%s/bookmark/%d/export.vspx?did=%d&output=BMK&file=export&format=%s', BMK.WA.host_url (), inst_id, inst_id, contentType)));

  return '';
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API."bookmark.options.set" (
  in inst_id int, in options any) __soap_http 'text/xml'
{
  declare exit handler for sqlstate '*'
  {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };

  declare rc integer;
  declare uname varchar;

  if (not ods_check_auth (uname, inst_id, 'author'))
    return ods_auth_failed ();

  -- TODO: not implemented
  return ods_serialize_int_res (rc);
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API."bookmark.options.get" (
  in inst_id int) __soap_http 'text/xml'
{
  declare exit handler for sqlstate '*'
  {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };

  declare rc integer;
  declare uname varchar;

  if (not ods_check_auth (uname, inst_id, 'author'))
    return ods_auth_failed ();

  -- TODO: not implemented
  return ods_serialize_int_res (rc);
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API."bookmark.comment.get" (
  in comment_id integer) __soap_http 'text/xml'
{
  declare exit handler for sqlstate '*'
  {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };

  declare uname varchar;
  declare inst_id, bookmark_id integer;
  declare q, iri varchar;

  whenever not found goto _exit;

  select BC_DOMAIN_ID, BC_BOOKMARK_ID into inst_id, bookmark_id from BMK.WA.BOOKMARK_COMMENT where BC_ID = comment_id;

  if (not ods_check_auth (uname, inst_id, 'reader'))
    return ods_auth_failed ();

  iri := SIOC..bmk_comment_iri (inst_id, cast (bookmark_id as integer), comment_id);
  q := sprintf ('describe <%s> from <%s>', iri, SIOC..get_graph ());
  exec_sparql (q);

_exit:
  return '';
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API."bookmark.comment.new" (
  in bookmark_id integer,
  in parent_id integer := null,
  in title varchar,
  in text varchar,
  in name varchar,
  in email varchar,
  in url varchar) __soap_http 'text/xml'
{
  declare exit handler for sqlstate '*'
  {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };

  declare rc integer;
  declare uname varchar;
  declare inst_id integer;

  rc := -1;
  inst_id := (select BD_DOMAIN_ID from BMK.WA.BOOKMARK_DOMAIN where BD_ID = bookmark_id);

  if (not ods_check_auth (uname, inst_id, 'reader'))
    return ods_auth_failed ();

  if (not (BMK.WA.discussion_check () and BMK.WA.conversation_enable (inst_id)))
    return signal('API01', 'Discussions must be enabled for this instance');

  if (isnull (parent_id))
  {
    -- get root comment;
    parent_id := (select BC_ID from BMK.WA.BOOKMARK_COMMENT where BC_DOMAIN_ID = inst_id and BC_BOOKMARK_ID = bookmark_id and BC_PARENT_ID is null);
    if (isnull (parent_id))
    {
      BMK.WA.nntp_root (inst_id, bookmark_id);
      parent_id := (select BC_ID from BMK.WA.BOOKMARK_COMMENT where BC_DOMAIN_ID = inst_id and BC_BOOKMARK_ID = bookmark_id and BC_PARENT_ID is null);
    }
  }

  BMK.WA.nntp_update_item (inst_id, bookmark_id);
  insert into BMK.WA.BOOKMARK_COMMENT (BC_PARENT_ID, BC_DOMAIN_ID, BC_BOOKMARK_ID, BC_TITLE, BC_COMMENT, BC_U_NAME, BC_U_MAIL, BC_U_URL, BC_UPDATED)
    values (parent_id, inst_id, bookmark_id, title, text, name, email, url, now ());
  rc := row_count ();

  return ods_serialize_int_res (rc);
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API."bookmark.comment.delete" (
  in comment_id integer) __soap_http 'text/xml'
{
  declare exit handler for sqlstate '*'
  {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };

  declare rc integer;
  declare uname varchar;
  declare inst_id integer;

  rc := -1;
  inst_id := (select BC_DOMAIN_ID from BMK.WA.BOOKMARK_COMMENT where BC_ID = comment_id);
  if (not ods_check_auth (uname, inst_id, 'author'))
    return ods_auth_failed ();

  delete from BMK.WA.BOOKMARK_COMMENT where BC_ID = comment_id;
  rc := row_count ();

  return ods_serialize_int_res (rc);
}
;

grant execute on ODS.ODS_API."bookmark.get" to ODS_API;
grant execute on ODS.ODS_API."bookmark.new" to ODS_API;
grant execute on ODS.ODS_API."bookmark.edit" to ODS_API;
grant execute on ODS.ODS_API."bookmark.delete" to ODS_API;
grant execute on ODS.ODS_API."bookmark.folder.new" to ODS_API;
grant execute on ODS.ODS_API."bookmark.folder.delete" to ODS_API;
grant execute on ODS.ODS_API."bookmark.import" to ODS_API;
grant execute on ODS.ODS_API."bookmark.export" to ODS_API;
grant execute on ODS.ODS_API."bookmark.options.get" to ODS_API;
grant execute on ODS.ODS_API."bookmark.options.set" to ODS_API;
grant execute on ODS.ODS_API."bookmark.comment.get" to ODS_API;
grant execute on ODS.ODS_API."bookmark.comment.new" to ODS_API;
grant execute on ODS.ODS_API."bookmark.comment.delete" to ODS_API;

use DB;