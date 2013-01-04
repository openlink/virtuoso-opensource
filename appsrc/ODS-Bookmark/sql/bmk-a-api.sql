--
--  $Id$
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2013 OpenLink Software
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
create procedure ODS.ODS_API.bookmark_setting_set (
  inout settings any,
  inout options any,
  in settingName varchar,
  in settingTest any := null)
{
	declare aValue any;

  aValue := get_keyword (settingName, options, get_keyword (settingName, settings));
  if (not isnull (settingTest))
    BMK.WA.test (cast (aValue as varchar), settingTest);
  BMK.WA.set_keyword (settingName, settings, aValue);
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API.bookmark_setting_xml (
  in settings any,
  in settingName varchar)
{
  return sprintf ('<%s>%s</%s>', settingName, cast (get_keyword (settingName, settings) as varchar), settingName);
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API.bookmark_type_check (
  in inType varchar,
  in inSource varchar)
{
  declare outType integer;

  if (isnull (inType))
    inType := case when (inSource like 'http://%') then 'url' else 'webdav' end;

	if (lcase (inType) = 'webdav')
	{
		outType := 1;
	}
	else if (lcase (inType) = 'url')
	{
		outType := 2;
	}
	else
	{
		signal ('BMK106', 'The source type must be WebDAV or URL.');
	}
	return outType;
}
;

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

  inst_id := (select BD_DOMAIN_ID from BMK.WA.BOOKMARK_DOMAIN where BD_ID = bookmark_id);
  if (not ods_check_auth (uname, inst_id, 'author'))
    return ods_auth_failed ();

  if (not exists (select 1 from DB.DBA.WA_INSTANCE where WAI_ID = inst_id and WAI_TYPE_NAME = 'Bookmark'))
    return ods_serialize_sql_error ('37000', 'The instance is not found');

  ods_describe_iri (SIOC..bmk_post_iri (inst_id, bookmark_id));
  return '';
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

  if (not exists (select 1 from DB.DBA.WA_INSTANCE where WAI_ID = inst_id and WAI_TYPE_NAME = 'Bookmark'))
    return ods_serialize_sql_error ('37000', 'The instance is not found');

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

  if (not exists (select 1 from BMK.WA.BOOKMARK_DOMAIN where BD_ID = bookmark_id))
    return ods_serialize_sql_error ('37000', 'The item is not found');
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

  if (not exists (select 1 from BMK.WA.BOOKMARK_DOMAIN where BD_ID = bookmark_id))
    return ods_serialize_sql_error ('37000', 'The item is not found');
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

  if (not exists (select 1 from DB.DBA.WA_INSTANCE where WAI_ID = inst_id and WAI_TYPE_NAME = 'Bookmark'))
    return ods_serialize_sql_error ('37000', 'The instance is not found');

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

  if (not exists (select 1 from DB.DBA.WA_INSTANCE where WAI_ID = inst_id and WAI_TYPE_NAME = 'Bookmark'))
    return ods_serialize_sql_error ('37000', 'The instance is not found');

  if (not exists (select 1 from BMK.WA.FOLDER where F_DOMAIN_ID = inst_id and F_PATH = path))
    return ods_serialize_sql_error ('37000', 'The item is not found');
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
  declare tmp any;

  if (not ods_check_auth (uname, inst_id, 'author'))
    return ods_auth_failed ();

  if (not exists (select 1 from DB.DBA.WA_INSTANCE where WAI_ID = inst_id and WAI_TYPE_NAME = 'Bookmark'))
    return ods_serialize_sql_error ('37000', 'The instance is not found');

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
  if (DB.DBA.is_empty_or_null (content))
    signal ('BMK04', 'Bad import source!');

  BMK.WA.bookmark_import (content, inst_id, null, tags, null);

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

  if (not exists (select 1 from DB.DBA.WA_INSTANCE where WAI_ID = inst_id and WAI_TYPE_NAME = 'Bookmark'))
    return ods_serialize_sql_error ('37000', 'The instance is not found');

  if (lcase (contentType) not in ('netscape', 'xbel'))
  	signal ('BMK05', 'The content type must be Netscape or XBEL.');

  if (lcase (contentType) = 'netscape')
  {
    contentType := 'Netscape';
  }
  else if (lcase (contentType) = 'xbel')
  {
    contentType := 'XBEL';
  }
  http (BMK.WA.dav_content (sprintf('%s/bookmark/%d/export.vspx?did=%d&output=BMK&file=export&format=%s', BMK.WA.host_url (), inst_id, inst_id, contentType)));

  return '';
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API."bookmark.annotation.get" (
  in annotation_id integer) __soap_http 'text/xml'
{
  declare exit handler for sqlstate '*'
  {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };

  declare inst_id, bookmark_id integer;
  declare uname varchar;

  whenever not found goto _exit;

  select A_DOMAIN_ID, A_OBJECT_ID into inst_id, bookmark_id from BMK.WA.ANNOTATIONS where A_ID = annotation_id;

  if (not ods_check_auth (uname, inst_id, 'reader'))
    return ods_auth_failed ();

  ods_describe_iri (SIOC..bmk_annotation_iri (inst_id, bookmark_id, annotation_id));
_exit:
  return '';
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API."bookmark.annotation.new" (
  in bookmark_id integer,
  in author varchar,
  in body varchar) __soap_http 'text/xml'
{
  declare exit handler for sqlstate '*'
  {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };

  declare rc, inst_id integer;
  declare uname varchar;

  rc := -1;
  inst_id := (select BD_DOMAIN_ID from BMK.WA.BOOKMARK_DOMAIN where BD_ID = bookmark_id);
  if (isnull (inst_id))
    return ods_serialize_sql_error ('37000', 'The item is not found');
  if (not ods_check_auth (uname, inst_id, 'reader'))
    return ods_auth_failed ();

  insert into BMK.WA.ANNOTATIONS (A_DOMAIN_ID, A_OBJECT_ID, A_BODY, A_AUTHOR, A_CREATED, A_UPDATED)
    values (inst_id, bookmark_id, body, author, now (), now ());
  rc := (select max (A_ID) from BMK.WA.ANNOTATIONS);

  return ods_serialize_int_res (rc);
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API."bookmark.annotation.claim" (
  in annotation_id integer,
  in claimIri varchar,
  in claimRelation varchar,
  in claimValue varchar) __soap_http 'text/xml'
{
  declare exit handler for sqlstate '*'
  {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };

  declare rc, inst_id integer;
  declare uname varchar;
  declare claims any;

  rc := -1;
  inst_id := (select A_DOMAIN_ID from BMK.WA.ANNOTATIONS where A_ID = annotation_id);
  if (not ods_check_auth (uname, inst_id, 'author'))
    return ods_auth_failed ();

  if (not exists (select 1 from BMK.WA.ANNOTATIONS where A_ID = annotation_id))
    return ods_serialize_sql_error ('37000', 'The item is not found');
  claims := (select deserialize (A_CLAIMS) from BMK.WA.ANNOTATIONS where A_ID = annotation_id);
  claims := vector_concat (claims, vector (vector (claimIri, claimRelation, claimValue)));
  update BMK.WA.ANNOTATIONS
     set A_CLAIMS = serialize (claims),
         A_UPDATED = now ()
   where A_ID = annotation_id;
  rc := row_count ();

  return ods_serialize_int_res (rc);
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API."bookmark.annotation.delete" (
  in annotation_id integer) __soap_http 'text/xml'
{
  declare exit handler for sqlstate '*'
  {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };

  declare rc, inst_id integer;
  declare uname varchar;

  rc := -1;
  inst_id := (select A_DOMAIN_ID from BMK.WA.ANNOTATIONS where A_ID = annotation_id);
  if (not ods_check_auth (uname, inst_id, 'author'))
    return ods_auth_failed ();

  if (not exists (select 1 from BMK.WA.ANNOTATIONS where A_ID = annotation_id))
    return ods_serialize_sql_error ('37000', 'The item is not found');
  delete from BMK.WA.ANNOTATIONS where A_ID = annotation_id;
  rc := row_count ();

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

  whenever not found goto _exit;

  select BC_DOMAIN_ID, BC_BOOKMARK_ID into inst_id, bookmark_id from BMK.WA.BOOKMARK_COMMENT where BC_ID = comment_id;

  if (not ods_check_auth (uname, inst_id, 'reader'))
    return ods_auth_failed ();

  ods_describe_iri (SIOC..bmk_comment_iri (inst_id, cast (bookmark_id as integer), comment_id));
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
  in url varchar := null) __soap_http 'text/xml'
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
  rc := (select max (BC_ID) from BMK.WA.BOOKMARK_COMMENT);

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

  if (not exists (select 1 from BMK.WA.BOOKMARK_COMMENT where BC_ID = comment_id))
    return ods_serialize_sql_error ('37000', 'The item is not found');
  delete from BMK.WA.BOOKMARK_COMMENT where BC_ID = comment_id;
  rc := row_count ();

  return ods_serialize_int_res (rc);
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API."bookmark.publication.new" (
  in inst_id integer,
  in name varchar,
  in updateType varchar := 1,
  in updatePeriod varchar := 'hourly',
  in updateFreq integr := 1,
  in destinationType varchar := null,
  in destination varchar,
  in userName varchar := null,
  in userPassword varchar := null,
  in folderPath varchar := '',
  in tagsInclude varchar := '',
  in tagsExclude varchar := '') __soap_http 'text/xml'
{
  declare exit handler for sqlstate '*'
  {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };

  declare rc integer;
  declare uname varchar;
  declare _type, options any;

  if (not ods_check_auth (uname, inst_id, 'author'))
    return ods_auth_failed ();

  if (not exists (select 1 from DB.DBA.WA_INSTANCE where WAI_ID = inst_id and WAI_TYPE_NAME = 'Bookmark'))
    return ods_serialize_sql_error ('37000', 'The instance is not found');

  _type := ODS.ODS_API.bookmark_type_check (destinationType, destination);
  options := vector ('type', _type, 'name', destination, 'user', userName, 'password', userPassword, 'folderPath', folderPath, 'tagsInclude', tagsInclude, 'tagsExclude', tagsExclude);
  insert into BMK.WA.EXCHANGE (EX_DOMAIN_ID, EX_TYPE, EX_NAME, EX_UPDATE_TYPE, EX_UPDATE_PERIOD, EX_UPDATE_FREQ, EX_OPTIONS)
    values (inst_id, 0, name, updateType, updatePeriod, updateFreq, serialize (options));
  rc := (select max (EX_ID) from BMK.WA.EXCHANGE);

  return ods_serialize_int_res (rc);
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API."bookmark.publication.get" (
  in publication_id integer) __soap_http 'text/xml'
  {
  declare exit handler for sqlstate '*'
  {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };

  declare rc, inst_id integer;
  declare uname varchar;
  declare options any;

  inst_id := (select EX_DOMAIN_ID from BMK.WA.EXCHANGE where EX_ID = publication_id);
  if (not ods_check_auth (uname, inst_id, 'author'))
    return ods_auth_failed ();

  if (not exists (select 1 from BMK.WA.EXCHANGE where EX_ID = publication_id and EX_TYPE = 0))
    return ods_serialize_sql_error ('37000', 'The item is not found');

  for (select * from BMK.WA.EXCHANGE where EX_ID = publication_id) do
  {
    options := deserialize (EX_OPTIONS);
    http (sprintf ('<publication id="%d">\r\n', publication_id));

    http (sprintf ('  <name>%V</name>\r\n', EX_NAME));
    if (EX_UPDATE_TYPE = 0)
    {
      http ('  <updateType>manually</updateType>\r\n');
  }
    else if (EX_UPDATE_TYPE = 1)
  {
      http ('  <updateType>after any entry is changed</updateType>\r\n');
  }
  else
  {
      http (sprintf ('  <updatePeriod>%s</updatePeriod>\r\n', EX_UPDATE_PERIOD));
      http (sprintf ('  <updateFreq>%s</updateFreq>\r\n', cast (EX_UPDATE_FREQ as varchar)));
  }
    http (sprintf ('  <destinationType>%V</destinationType>\r\n', get_keyword (get_keyword ('type', options, 1), vector (1, 'WebDAV', 2, 'URL'))));
    http (sprintf ('  <destination>%V</destination>\r\n', get_keyword ('name', options)));
    if (get_keyword ('user', options, '') <> '')
    {
      http (sprintf ('  <userName>%V</userName>\r\n', get_keyword ('user', options)));
      http ('  <userPassword>******</userName>\r\n');
    }
    http ('  <options>\r\n');
    if (get_keyword ('folderPath', options, '') <> '')
      http (sprintf ('    <folderPath>%s</folderPath>\r\n', cast (get_keyword ('folderPath', options) as varchar)));
    if (get_keyword ('tagsInclude', options, '') <> '')
      http (sprintf ('    <tagsInclude>%s</tagsInclude>\r\n', cast (get_keyword ('tagsInclude', options) as varchar)));
    if (get_keyword ('tagsExclude', options, '') <> '')
      http (sprintf ('    <tagsExclude>%s</tagsExclude>\r\n', cast (get_keyword ('tagsExclude', options) as varchar)));
    http ('  </options>\r\n');

    http ('</publication>');
  }
  return '';
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API."bookmark.publication.edit" (
  in publication_id integer,
  in name varchar,
  in updateType varchar := 1,
  in updatePeriod varchar := 'hourly',
  in updateFreq integr := 1,
  in destinationType varchar := null,
  in destination varchar,
  in userName varchar := null,
  in userPassword varchar := null,
  in folderPath varchar := '',
  in tagsInclude varchar := '',
  in tagsExclude varchar := '') __soap_http 'text/xml'
{
  declare exit handler for sqlstate '*'
  {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };

  declare rc integer;
  declare uname varchar;
  declare inst_id integer;
  declare _type, options any;

  inst_id := (select EX_DOMAIN_ID from BMK.WA.EXCHANGE where EX_ID = publication_id);
  if (not ods_check_auth (uname, inst_id, 'author'))
    return ods_auth_failed ();

  if (not exists (select 1 from BMK.WA.EXCHANGE where EX_ID = publication_id and EX_TYPE = 0))
    return ods_serialize_sql_error ('37000', 'The item is not found');

  _type := ODS.ODS_API.bookmark_type_check (destinationType, destination);
  options := vector ('type', _type, 'name', destination, 'user', userName, 'password', userPassword, 'folderPath', folderPath, 'tagsInclude', tagsInclude, 'tagsExclude', tagsExclude);
  update BMK.WA.EXCHANGE
     set EX_NAME = name,
         EX_UPDATE_TYPE = updateType,
         EX_UPDATE_PERIOD = updatePeriod,
         EX_UPDATE_FREQ = updateFreq,
         EX_OPTIONS = serialize (options)
   where EX_ID = publication_id;

  return ods_serialize_int_res (publication_id);
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API."bookmark.publication.sync" (
  in publication_id integer) __soap_http 'text/xml'
{
  declare exit handler for sqlstate '*'
  {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };

  declare uname, syncLog varchar;
  declare inst_id integer;

  inst_id := (select EX_DOMAIN_ID from BMK.WA.EXCHANGE where EX_ID = publication_id);
  if (not ods_check_auth (uname, inst_id, 'author'))
    return ods_auth_failed ();

  if (not exists (select 1 from BMK.WA.EXCHANGE where EX_ID = publication_id and EX_TYPE = 0))
    return ods_serialize_sql_error ('37000', 'The item is not found');

  BMK.WA.exchange_exec (publication_id);
  syncLog := (select EX_EXEC_LOG from BMK.WA.EXCHANGE where EX_ID = publication_id);
  if (not DB.DBA.is_empty_or_null (syncLog))
    return ods_serialize_sql_error ('ERROR', syncLog);

  return ods_serialize_int_res (1);
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API."bookmark.publication.delete" (
  in publication_id integer) __soap_http 'text/xml'
{
  declare exit handler for sqlstate '*'
  {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };

  declare rc integer;
  declare uname varchar;
  declare inst_id integer;

  inst_id := (select EX_DOMAIN_ID from BMK.WA.EXCHANGE where EX_ID = publication_id);
  if (not ods_check_auth (uname, inst_id, 'author'))
    return ods_auth_failed ();

  if (not exists (select 1 from BMK.WA.EXCHANGE where EX_ID = publication_id and EX_TYPE = 0))
    return ods_serialize_sql_error ('37000', 'The item is not found');

  delete from BMK.WA.EXCHANGE where EX_ID = publication_id;
  rc := row_count ();

  return ods_serialize_int_res (rc);
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API."bookmark.subscription.new" (
  in inst_id integer,
  in name varchar,
  in updateType varchar := 2,
  in updatePeriod varchar := 'daily',
  in updateFreq integr := 1,
  in sourceType varchar := null,
  in source varchar,
  in userName varchar := null,
  in userPassword varchar := null,
  in folderPath varchar := '',
  in tags varchar := '') __soap_http 'text/xml'
{
  declare exit handler for sqlstate '*'
  {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };

  declare rc integer;
  declare uname varchar;
  declare _type, options any;

  if (not ods_check_auth (uname, inst_id, 'author'))
    return ods_auth_failed ();

  if (not exists (select 1 from DB.DBA.WA_INSTANCE where WAI_ID = inst_id and WAI_TYPE_NAME = 'Bookmark'))
    return ods_serialize_sql_error ('37000', 'The instance is not found');

  _type := ODS.ODS_API.bookmark_type_check (sourceType, source);
  options := vector ('type', _type, 'name', source, 'user', userName, 'password', userPassword, 'folderPath', folderPath, 'tags', tags);
  insert into BMK.WA.EXCHANGE (EX_DOMAIN_ID, EX_TYPE, EX_NAME, EX_UPDATE_TYPE, EX_UPDATE_PERIOD, EX_UPDATE_FREQ, EX_OPTIONS)
    values (inst_id, 1, name, updateType, updatePeriod, updateFreq, serialize (options));
  rc := (select max (EX_ID) from BMK.WA.EXCHANGE);

  return ods_serialize_int_res (rc);
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API."bookmark.subscription.get" (
  in subscription_id integer) __soap_http 'text/xml'
{
  declare exit handler for sqlstate '*'
  {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };

  declare rc, inst_id integer;
  declare uname varchar;
  declare options any;

  inst_id := (select EX_DOMAIN_ID from BMK.WA.EXCHANGE where EX_ID = subscription_id);
  if (not ods_check_auth (uname, inst_id, 'author'))
    return ods_auth_failed ();

  if (not exists (select 1 from BMK.WA.EXCHANGE where EX_ID = subscription_id and EX_TYPE = 1))
    return ods_serialize_sql_error ('37000', 'The item is not found');

  for (select * from BMK.WA.EXCHANGE where EX_ID = subscription_id) do
  {
    options := deserialize (EX_OPTIONS);
    http (sprintf ('<publication id="%d">\r\n', subscription_id));

    http (sprintf ('  <name>%V</name>\r\n', EX_NAME));
    if (EX_UPDATE_TYPE = 0)
    {
      http ('  <updateType>manually</updateType>\r\n');
  }
    else if (EX_UPDATE_TYPE = 1)
  {
      http ('  <updateType>after any entry is changed</updateType>\r\n');
  }
  else
  {
      http (sprintf ('  <updatePeriod>%s</updatePeriod>\r\n', EX_UPDATE_PERIOD));
      http (sprintf ('  <updateFreq>%s</updateFreq>\r\n', cast (EX_UPDATE_FREQ as varchar)));
  }
    http (sprintf ('  <sourceType>%V</sourceType>\r\n', get_keyword (get_keyword ('type', options, 1), vector (1, 'WebDAV', 2, 'URL'))));
    http (sprintf ('  <source>%V</source>\r\n', get_keyword ('name', options)));
    if (get_keyword ('user', options, '') <> '')
    {
      http (sprintf ('  <userName>%V</userName>\r\n', get_keyword ('user', options)));
      http ('  <userPassword>******</userName>\r\n');
    }
    http ('  <options>\r\n');
    if (get_keyword ('folderPath', options, '') <> '')
      http (sprintf ('    <folderPath>%s</folderPath>\r\n', cast (get_keyword ('folderPath', options) as varchar)));
    if (get_keyword ('tags', options, '') <> '')
      http (sprintf ('    <tags>%s</tags>\r\n', cast (get_keyword ('tags', options) as varchar)));
    http ('  </options>\r\n');

    http ('</publication>');
  }
  return '';
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API."bookmark.subscription.edit" (
  in subscription_id integer,
  in name varchar,
  in updateType varchar := 2,
  in updatePeriod varchar := 'daily',
  in updateFreq integr := 1,
  in sourceType varchar := null,
  in source varchar,
  in userName varchar := null,
  in userPassword varchar := null,
  in folderPath varchar := '',
  in tags varchar := '') __soap_http 'text/xml'
{
  declare exit handler for sqlstate '*'
  {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };

  declare rc integer;
  declare uname varchar;
  declare inst_id integer;
  declare _type, options any;

  inst_id := (select EX_DOMAIN_ID from BMK.WA.EXCHANGE where EX_ID = subscription_id);
  if (not ods_check_auth (uname, inst_id, 'author'))
    return ods_auth_failed ();

  if (not exists (select 1 from BMK.WA.EXCHANGE where EX_ID = subscription_id and EX_TYPE = 1))
    return ods_serialize_sql_error ('37000', 'The item is not found');

  _type := ODS.ODS_API.bookmark_type_check (sourceType, source);
  options := vector ('type', _type, 'name', source, 'user', userName, 'password', userPassword, 'folderPath', folderPath, 'tags', tags);
  update BMK.WA.EXCHANGE
     set EX_NAME = name,
         EX_UPDATE_TYPE = updateType,
         EX_UPDATE_PERIOD = updatePeriod,
         EX_UPDATE_FREQ = updateFreq,
         EX_OPTIONS = serialize (options)
   where EX_ID = subscription_id;

  return ods_serialize_int_res (subscription_id);
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API."bookmark.subscription.sync" (
  in subscription_id integer) __soap_http 'text/xml'
{
  declare exit handler for sqlstate '*'
  {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };

  declare uname, syncLog varchar;
  declare inst_id integer;

  inst_id := (select EX_DOMAIN_ID from BMK.WA.EXCHANGE where EX_ID = subscription_id);
  if (not ods_check_auth (uname, inst_id, 'author'))
    return ods_auth_failed ();

  if (not exists (select 1 from BMK.WA.EXCHANGE where EX_ID = subscription_id and EX_TYPE = 1))
    return ods_serialize_sql_error ('37000', 'The item is not found');

  BMK.WA.exchange_exec (subscription_id);
  syncLog := (select EX_EXEC_LOG from BMK.WA.EXCHANGE where EX_ID = subscription_id);
  if (not DB.DBA.is_empty_or_null (syncLog))
    return ods_serialize_sql_error ('ERROR', syncLog);

  return ods_serialize_int_res (1);
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API."bookmark.subscription.delete" (
  in subscription_id integer) __soap_http 'text/xml'
{
  declare exit handler for sqlstate '*'
  {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };

  declare rc integer;
  declare uname varchar;
  declare inst_id integer;

  inst_id := (select EX_DOMAIN_ID from BMK.WA.EXCHANGE where EX_ID = subscription_id);
  if (not ods_check_auth (uname, inst_id, 'author'))
    return ods_auth_failed ();

  if (not exists (select 1 from BMK.WA.EXCHANGE where EX_ID = subscription_id and EX_TYPE = 1))
    return ods_serialize_sql_error ('37000', 'The item is not found');

  delete from BMK.WA.EXCHANGE where EX_ID = subscription_id;
  rc := row_count ();

  return ods_serialize_int_res (rc);
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API."bookmark.options.set" (
  in inst_id int,
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

  if (not ods_check_auth (uname, inst_id, 'author'))
    return ods_auth_failed ();

  if (not exists (select 1 from DB.DBA.WA_INSTANCE where WAI_ID = inst_id and WAI_TYPE_NAME = 'Bookmark'))
    return ods_serialize_sql_error ('37000', 'The instance is not found');

  account_id := (select U_ID from WS.WS.SYS_DAV_USER where U_NAME = uname);
  optionsParams := split_and_decode (options, 0, '%\0,=');

  settings := BMK.WA.settings (inst_id);
  BMK.WA.settings_init (settings);
  conv := cast (get_keyword ('conv', settings, '0') as integer);

  ODS.ODS_API.bookmark_setting_set (settings, optionsParams, 'chars');
  ODS.ODS_API.bookmark_setting_set (settings, optionsParams, 'rows', vector ('name', 'Rows per page', 'class', 'integer', 'type', 'integer', 'minValue', 1, 'maxValue', 1000));
  ODS.ODS_API.bookmark_setting_set (settings, optionsParams, 'tbLabels');
  ODS.ODS_API.bookmark_setting_set (settings, optionsParams, 'atomVersion');
  ODS.ODS_API.bookmark_setting_set (settings, optionsParams, 'panes');
  ODS.ODS_API.bookmark_setting_set (settings, optionsParams, 'bookmarkOpen');
	if (BMK.WA.discussion_check ())
	{
  ODS.ODS_API.bookmark_setting_set (settings, optionsParams, 'conv');
  ODS.ODS_API.bookmark_setting_set (settings, optionsParams, 'conv_init');
  }
  insert replacing BMK.WA.SETTINGS (S_DOMAIN_ID, S_ACCOUNT_ID, S_DATA)
    values (inst_id, account_id, serialize (settings));

  f_conv := cast (get_keyword ('conv', settings, '0') as integer);
  f_conv_init := cast (get_keyword ('conv_init', settings, '0') as integer);
	if (BMK.WA.discussion_check ())
	{
	  BMK.WA.nntp_update (inst_id, null, null, conv, f_conv);
		if (f_conv and f_conv_init)
	    BMK.WA.nntp_fill (inst_id);
	}

  return ods_serialize_int_res (1);
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
  declare settings any;

  if (not ods_check_auth (uname, inst_id, 'author'))
    return ods_auth_failed ();

  if (not exists (select 1 from DB.DBA.WA_INSTANCE where WAI_ID = inst_id and WAI_TYPE_NAME = 'Bookmark'))
    return ods_serialize_sql_error ('37000', 'The instance is not found');

  settings := BMK.WA.settings (inst_id);
  BMK.WA.settings_init (settings);

  http ('<settings>');
  http (ODS.ODS_API.bookmark_setting_xml (settings, 'chars'));
  http (ODS.ODS_API.bookmark_setting_xml (settings, 'rows'));
  http (ODS.ODS_API.bookmark_setting_xml (settings, 'tbLabels'));
  http (ODS.ODS_API.bookmark_setting_xml (settings, 'atomVersion'));
  http (ODS.ODS_API.bookmark_setting_xml (settings, 'conv'));
  http (ODS.ODS_API.bookmark_setting_xml (settings, 'conv_init'));
  http (ODS.ODS_API.bookmark_setting_xml (settings, 'panes'));
  http (ODS.ODS_API.bookmark_setting_xml (settings, 'bookmarkOpen'));
  http ('</settings>');

  return '';
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

grant execute on ODS.ODS_API."bookmark.annotation.get" to ODS_API;
grant execute on ODS.ODS_API."bookmark.annotation.new" to ODS_API;
grant execute on ODS.ODS_API."bookmark.annotation.claim" to ODS_API;
grant execute on ODS.ODS_API."bookmark.annotation.delete" to ODS_API;

grant execute on ODS.ODS_API."bookmark.comment.get" to ODS_API;
grant execute on ODS.ODS_API."bookmark.comment.new" to ODS_API;
grant execute on ODS.ODS_API."bookmark.comment.delete" to ODS_API;

grant execute on ODS.ODS_API."bookmark.publication.new" to ODS_API;
grant execute on ODS.ODS_API."bookmark.publication.get" to ODS_API;
grant execute on ODS.ODS_API."bookmark.publication.edit" to ODS_API;
grant execute on ODS.ODS_API."bookmark.publication.sync" to ODS_API;
grant execute on ODS.ODS_API."bookmark.publication.delete" to ODS_API;
grant execute on ODS.ODS_API."bookmark.subscription.new" to ODS_API;
grant execute on ODS.ODS_API."bookmark.subscription.get" to ODS_API;
grant execute on ODS.ODS_API."bookmark.subscription.edit" to ODS_API;
grant execute on ODS.ODS_API."bookmark.subscription.sync" to ODS_API;
grant execute on ODS.ODS_API."bookmark.subscription.delete" to ODS_API;

grant execute on ODS.ODS_API."bookmark.options.get" to ODS_API;
grant execute on ODS.ODS_API."bookmark.options.set" to ODS_API;

use DB;
