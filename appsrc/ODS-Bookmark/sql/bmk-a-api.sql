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
  {
    return ods_auth_failed ();
  }
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

  if (not exists (select 1 from BMK.WA.BOOKMARK_DOMAIN where BD_ID = bookmark_id))
    return ods_serialize_sql_error ('37000', 'The item not found');
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
    return ods_serialize_sql_error ('37000', 'The item not found');
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

  if (not exists (select 1 from BMK.WA.FOLDER where F_DOMAIN_ID = inst_id and F_PATH = path))
    return ods_serialize_sql_error ('37000', 'The item not found');
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
  declare q, iri varchar;

  whenever not found goto _exit;

  select A_DOMAIN_ID, A_OBJECT_ID into inst_id, bookmark_id from BMK.WA.ANNOTATIONS where A_ID = annotation_id;

  if (not ods_check_auth (uname, inst_id, 'reader'))
    return ods_auth_failed ();

  iri := SIOC..bmk_annotation_iri (inst_id, bookmark_id, annotation_id);
  q := sprintf ('describe <%s> from <%s>', iri, SIOC..get_graph ());
  exec_sparql (q);

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
    return ods_serialize_sql_error ('37000', 'The item not found');
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
    return ods_serialize_sql_error ('37000', 'The item not found');
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

  if (not exists (select 1 from BMK.WA.BOOKMARK_COMMENT where BC_ID = comment_id))
    return ods_serialize_sql_error ('37000', 'The item not found');
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
  in destinationType varchar := 'WebDAV',
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

  if (lcase (destinationType) = 'webdav')
  {
    _type := 1;
  }
  else if (lcase (destinationType) = 'url')
  {
    _type := 2;
  }
  else
  {
	  signal ('CAL106', 'The source type must be WebDAV or URL.');
  }
  options := vector ('type', _type, 'name', destination, 'user', userName, 'password', userPassword, 'folderPath', folderPath, 'tagsInclude', tagsInclude, 'tagsExclude', tagsExclude);
  insert into BMK.WA.EXCHANGE (EX_DOMAIN_ID, EX_TYPE, EX_NAME, EX_UPDATE_TYPE, EX_UPDATE_PERIOD, EX_UPDATE_FREQ, EX_OPTIONS)
    values (inst_id, 0, name, updateType, updatePeriod, updateFreq, serialize (options));
  rc := (select max (EX_ID) from BMK.WA.EXCHANGE);

  return ods_serialize_int_res (rc);
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
  in destinationType varchar := 'WebDAV',
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

  if (not exists (select 1 from BMK.WA.EXCHANGE where EX_ID = publication_id))
    return ods_serialize_sql_error ('37000', 'The item not found');
  if (lcase (destinationType) = 'webdav')
  {
    _type := 1;
  }
  else if (lcase (destinationType) = 'url')
  {
    _type := 2;
  }
  else
  {
	  signal ('CAL106', 'The source type must be WebDAV or URL.');
  }
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

  if (not exists (select 1 from BMK.WA.EXCHANGE where EX_ID = publication_id))
    return ods_serialize_sql_error ('37000', 'The item not found');
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
  in updateType varchar := 1,
  in updatePeriod varchar := 'hourly',
  in updateFreq integr := 1,
  in sourceType varchar := 'WebDAV',
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

  if (lcase (sourceType) = 'webdav')
  {
    _type := 1;
  }
  else if (lcase (sourceType) = 'url')
  {
    _type := 2;
  }
  else
  {
	  signal ('CAL106', 'The source type must be WebDAV or URL.');
  }
  options := vector ('type', _type, 'name', source, 'user', userName, 'password', userPassword, 'folderPath', folderPath, 'tags', tags);
  insert into BMK.WA.EXCHANGE (EX_DOMAIN_ID, EX_TYPE, EX_NAME, EX_UPDATE_TYPE, EX_UPDATE_PERIOD, EX_UPDATE_FREQ, EX_OPTIONS)
    values (inst_id, 1, name, updateType, updatePeriod, updateFreq, serialize (options));
  rc := (select max (EX_ID) from BMK.WA.EXCHANGE);

  return ods_serialize_int_res (rc);
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API."bookmark.subscription.edit" (
  in subscription_id integer,
  in name varchar,
  in updateType varchar := 1,
  in updatePeriod varchar := 'hourly',
  in updateFreq integr := 1,
  in sourceType varchar := 'WebDAV',
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

  if (not exists (select 1 from BMK.WA.EXCHANGE where EX_ID = subscription_id))
    return ods_serialize_sql_error ('37000', 'The item not found');
  if (lcase (sourceType) = 'webdav')
  {
    _type := 1;
  }
  else if (lcase (sourceType) = 'url')
  {
    _type := 2;
  }
  else
  {
	  signal ('CAL106', 'The source type must be WebDAV or URL.');
  }
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

  if (not exists (select 1 from BMK.WA.EXCHANGE where EX_ID = subscription_id))
    return ods_serialize_sql_error ('37000', 'The item not found');
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
  declare uname varchar;
  declare optionsParams, settings any;

  if (not ods_check_auth (uname, inst_id, 'author'))
    return ods_auth_failed ();

  account_id := (select U_ID from WS.WS.SYS_DAV_USER where U_NAME = uname);
  optionsParams := split_and_decode (options, 0, '%\0,='); -- XXX: FIXME

  settings := BMK.WA.settings (inst_id);
  BMK.WA.settings_init (settings);
  settings := BMK.WA.set_keyword ('chars', settings, get_keyword('chars', optionsParams, get_keyword('chars', settings)));
  settings := BMK.WA.set_keyword ('rows', settings, get_keyword('rows', optionsParams, get_keyword('rows', settings)));
  settings := BMK.WA.set_keyword ('tbLabels', settings, get_keyword('tbLabels', optionsParams, get_keyword('tbLabels', settings)));
  settings := BMK.WA.set_keyword ('atomVersion', settings, get_keyword('tbLabels', optionsParams, get_keyword('tbLabels', settings)));
  settings := BMK.WA.set_keyword ('conv', settings, get_keyword('conv', optionsParams, get_keyword('conv', settings)));
  settings := BMK.WA.set_keyword ('conv_init', settings, get_keyword('conv_init', optionsParams, get_keyword('conv_init', settings)));
  settings := BMK.WA.set_keyword ('panes', settings, get_keyword('panes', optionsParams, get_keyword('panes', settings)));
  settings := BMK.WA.set_keyword ('bookmarkOpen', settings, get_keyword('bookmarkOpen', optionsParams, get_keyword('bookmarkOpen', settings)));
  insert replacing BMK.WA.SETTINGS (S_DOMAIN_ID, S_ACCOUNT_ID, S_DATA) values (inst_id, account_id, serialize (settings));

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

  settings := BMK.WA.settings (inst_id);
  BMK.WA.settings_init (settings);

  http ('<settings>');
  http (sprintf ('<chars>%d</chars>', get_keyword ('chars', settings)));
  http (sprintf ('<rows>%d</rows>', get_keyword ('rows', settings)));
  http (sprintf ('<tbLabels>%d</tbLabels>', get_keyword ('tbLabels', settings)));
  http (sprintf ('<atomVersion>%s</atomVersion>', get_keyword ('atomVersion', settings)));
  http (sprintf ('<conv>%d</conv>', get_keyword ('conv', settings)));
  http (sprintf ('<conv_init>%d</conv_init>', get_keyword ('conv_init', settings)));
  http (sprintf ('<panes>%d</panes>', get_keyword ('panes', settings)));
  http (sprintf ('<bookmarkOpen>%d</bookmarkOpen>', get_keyword ('bookmarkOpen', settings)));
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
grant execute on ODS.ODS_API."bookmark.publication.edit" to ODS_API;
grant execute on ODS.ODS_API."bookmark.publication.delete" to ODS_API;
grant execute on ODS.ODS_API."bookmark.subscription.new" to ODS_API;
grant execute on ODS.ODS_API."bookmark.subscription.edit" to ODS_API;
grant execute on ODS.ODS_API."bookmark.subscription.delete" to ODS_API;

grant execute on ODS.ODS_API."bookmark.options.get" to ODS_API;
grant execute on ODS.ODS_API."bookmark.options.set" to ODS_API;

use DB;