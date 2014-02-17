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

use ODS;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API.dav_error (
  in code any)
{
  if (isinteger(code) and (code < 0))
    return 1;
  return 0;
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API.validate (
  in "test" varchar,
  in "value" any)
{
  if ("test" = 'wikiWord')
    if (isnull (regexp_match('^[A-Z][A-Za-z0-9]*\$', "value")))
      signal ('22023', 'Index page must be WikiWord');

  return 1;
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API.check2string (
  in "value" integer)
{
  if ("value" = 1)
    return 'on';
  return 'off';
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API.check2integer (
  in "value" varchar)
{
  if ("value" = 'on')
    return 1;
  return 2;
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API.topicRevisionsPath (
  in topic WV.WIKI.TOPICINFO)
{
  declare path, parent, name varchar;

  path := DB.DBA.DAV_SEARCH_PATH (topic.ti_res_id, 'R');
  name := trim(path, '/');
  if (not isnull (strrchr (name, '/')))
    name := right (name, length (name)-strrchr(name, '/')-1);
  parent := trim(path, '/');
  if (isnull (strrchr(parent, '/')))
  {
    parent := '';
  } else {
    parent := left(trim(parent, '/'), strrchr(trim(parent, '/'), '/'));
  }
  return concat('/', parent, '/VVC/', name, '/');
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API.wiki_ods_check_auth (
  out uname varchar,
  out inst_id integer,
  in "cluster" varchar,
  in mode char := 'owner')
{
  inst_id := (select WAI_ID from DB.DBA.WA_INSTANCE where WAI_NAME = "cluster" and WAI_TYPE_NAME = 'oWiki');
  if (isnull (inst_id))
    signal ('37000', 'The instance is not found');
  return ods_check_auth2 (uname, inst_id, mode);
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API."wiki.topic.internal" (
	in inst_id integer,
	in name varchar)
{
	declare clusterName varchar;
  declare topic WV.WIKI.TOPICINFO;

  clusterName := (select WAI_NAME from DB.DBA.WA_INSTANCE where WAI_ID = inst_id and WAI_TYPE_NAME = 'oWiki');
  if (isnull (clusterName))
    return ods_serialize_sql_error ('37000', 'The instance is not found');
  ODS.ODS_API.validate ('wikiWord', name);

  topic := WV.WIKI.TOPICINFO();
  topic.ti_default_cluster := clusterName;
  topic.ti_raw_name := name;
  topic.ti_parse_raw_name ();
  topic.ti_fill_cluster_by_name ();
  topic.ti_find_id_by_local_name ();
  if (topic.ti_id)
    topic.ti_find_metadata_by_id ();

  return topic;
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API."wiki.topic.new" (
	in "cluster" varchar,
	in name varchar,
	in content varchar) __soap_http 'text/xml'
{
	declare exit handler for sqlstate '*'
	{
		rollback work;
		return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
	};

  declare inst_id integer;
	declare uname varchar;
  declare newTopic WV.WIKI.TOPICINFO;

	if (not ODS.ODS_API.wiki_ods_check_auth (uname, inst_id, "cluster", 'author'))
		return ods_auth_failed ();

  newTopic := ODS.ODS_API."wiki.topic.internal" (inst_id, name);
  if (newTopic.ti_id)
    signal ('37000', 'The topic already exists');
  connection_set('WikiUser', uname);
  WV.WIKI.UPLOADPAGE (newTopic.ti_col_id, newTopic.ti_local_name || '.txt', content, uname, 0, uname);

	return ods_serialize_int_res (1);
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API."wiki.topic.get" (
	in "cluster" varchar,
	in name varchar) __soap_http 'text/xml'
{
	declare exit handler for sqlstate '*'
	{
		rollback work;
		return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
	};

  declare inst_id integer;
	declare uname varchar;
  declare topic WV.WIKI.TOPICINFO;

	if (not ODS.ODS_API.wiki_ods_check_auth (uname, inst_id, "cluster", 'reader'))
		return ods_auth_failed ();

  topic := ODS.ODS_API."wiki.topic.internal" (inst_id, name);
  if (not topic.ti_id)
    signal ('37000', 'The topic does not exist');
  connection_set('WikiUser', uname);

  http_header ('Content-Type: text/plain\r\n');
  http (topic.ti_text);
	return '';
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API."wiki.topic.versions" (
	in "cluster" varchar := null,
	in name varchar) __soap_http 'text/xml'
{
	declare exit handler for sqlstate '*'
	{
		rollback work;
		return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
	};

  declare inst_id integer;
	declare uname, upassword varchar;
	declare rc any;
	declare content, contentType any;
	declare versions any;
  declare topic WV.WIKI.TOPICINFO;

	if (not ODS.ODS_API.wiki_ods_check_auth (uname, inst_id, "cluster", 'reader'))
		return ods_auth_failed ();
  upassword := (select pwd_magic_calc (U_NAME, U_PASSWORD, 1) from DB.DBA.SYS_USERS where U_NAME = uname);

  topic := ODS.ODS_API."wiki.topic.internal" (inst_id, name);
  if (not topic.ti_id)
    signal ('37000', 'The topic does not exist');
  connection_set('WikiUser', uname);

  http (sprintf ('<topic name="%s" cluster="%s">', topic.ti_raw_name, topic.ti_default_cluster));
  http ('<versions>');
  rc := DB.DBA.DAV_RES_CONTENT (ODS.ODS_API.topicRevisionsPath(topic) || 'history.xml', content, contentType, uname, upassword);
  if (isstring (content))
  {
    versions := xpath_eval ('/history/version', xtree_doc (content), 0);
    foreach (any version in versions) do
    {
      http (sprintf ('<version number="%s" modified="%s" owner="%s" />', xpath_eval ('string (./@Number)', version), xpath_eval ('string (./@ModDate)', version), xpath_eval ('string (./@Who)', version)));
    }
  }
  http ('</versions>');
  http ('</topic>');

	return '';
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API."wiki.topic.versions.get" (
	in "cluster" varchar,
	in name varchar,
	in version varchar) __soap_http 'text/xml'
{
	declare exit handler for sqlstate '*'
	{
		rollback work;
		return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
	};

  declare inst_id integer;
	declare uname, upassword varchar;
	declare rc any;
	declare content, contentType any;
  declare topic WV.WIKI.TOPICINFO;

	if (not ODS.ODS_API.wiki_ods_check_auth (uname, inst_id, "cluster", 'reader'))
		return ods_auth_failed ();
  upassword := (select pwd_magic_calc (U_NAME, U_PASSWORD, 1) from DB.DBA.SYS_USERS where U_NAME = uname);

  topic := ODS.ODS_API."wiki.topic.internal" (inst_id, name);
  if (not topic.ti_id)
    signal ('37000', 'The topic does not exist');
  connection_set('WikiUser', uname);

  rc := DB.DBA.DAV_RES_CONTENT (ODS.ODS_API.topicRevisionsPath(topic) || version, content, contentType, uname, upassword);
  if (ODS.ODS_API.dav_error (rc))
    return ods_serialize_int_res (rc);

  http_header (sprintf ('Content-Type: %s\r\n', contentType));
  http (content);

	return '';
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API."wiki.topic.versions.diff" (
	in "cluster" varchar,
	in name varchar,
	in version varchar) __soap_http 'text/xml'
{
	declare exit handler for sqlstate '*'
	{
		rollback work;
		return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
	};

  declare inst_id integer;
	declare uname, upassword varchar;
	declare rc any;
	declare content, contentType any;
  declare topic WV.WIKI.TOPICINFO;

	if (not ODS.ODS_API.wiki_ods_check_auth (uname, inst_id, "cluster", 'reader'))
		return ods_auth_failed ();
  upassword := (select pwd_magic_calc (U_NAME, U_PASSWORD, 1) from DB.DBA.SYS_USERS where U_NAME = uname);

  topic := ODS.ODS_API."wiki.topic.internal" (inst_id, name);
  if (not topic.ti_id)
    signal ('37000', 'The topic does not exist');
  connection_set('WikiUser', uname);

  rc := DB.DBA.DAV_RES_CONTENT (ODS.ODS_API.topicRevisionsPath(topic) || version || '.diff', content, contentType, uname, upassword);
  if (ODS.ODS_API.dav_error (rc))
    return ods_serialize_int_res (rc);

  http_header (sprintf ('Content-Type: %s\r\n', contentType));
  http (content);

	return '';
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API."wiki.topic.edit" (
	in "cluster" varchar,
	in name varchar,
	in content varchar) __soap_http 'text/xml'
{
	declare exit handler for sqlstate '*'
	{
		rollback work;
		return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
	};

  declare inst_id integer;
	declare uname varchar;
	declare clusterName varchar;
  declare topic WV.WIKI.TOPICINFO;

	if (not ODS.ODS_API.wiki_ods_check_auth (uname, inst_id, "cluster", 'author'))
		return ods_auth_failed ();

  topic := ODS.ODS_API."wiki.topic.internal" (inst_id, name);
  if (not topic.ti_id)
    signal ('22023', 'The topic does not exists');
  connection_set('WikiUser', uname);
  topic.ti_update_text (content, uname);

	return ods_serialize_int_res (1);
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API."wiki.topic.delete" (
	in "cluster" varchar := null,
	in name varchar) __soap_http 'text/xml'
{
	declare exit handler for sqlstate '*'
	{
		rollback work;
		return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
	};

  declare inst_id integer;
	declare uname, upassword varchar;
	declare rc any;
  declare topic WV.WIKI.TOPICINFO;

	if (not ODS.ODS_API.wiki_ods_check_auth (uname, inst_id, "cluster", 'author'))
		return ods_auth_failed ();

  upassword := (select pwd_magic_calc (U_NAME, U_PASSWORD, 1) from DB.DBA.SYS_USERS where U_NAME = uname);
  topic := ODS.ODS_API."wiki.topic.internal" (inst_id, name);
  if (not topic.ti_id)
    signal ('22023', 'The topic does not exists');
  connection_set('WikiUser', uname);
  rc := DB.DBA.DAV_DELETE (DB.DBA.DAV_SEARCH_PATH (topic.ti_res_id, 'R'), 0, uname, upassword);
  if (ODS.ODS_API.dav_error (rc))
    return ods_serialize_int_res (rc);

	return ods_serialize_int_res (1);
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API."wiki.topic.sync" (
	in "cluster" varchar,
	in name varchar) __soap_http 'text/xml'
{
	declare exit handler for sqlstate '*'
	{
		rollback work;
		return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
	};

  declare inst_id integer;
	declare uname, upassword varchar;
  declare topic WV.WIKI.TOPICINFO;

	if (not ODS.ODS_API.wiki_ods_check_auth (uname, inst_id, "cluster", 'author'))
		return ods_auth_failed ();

  upassword := (select pwd_magic_calc (U_NAME, U_PASSWORD, 1) from DB.DBA.SYS_USERS where U_NAME = uname);
  topic := ODS.ODS_API."wiki.topic.internal" (inst_id, name);
  if (not topic.ti_id)
    signal ('22023', 'The topic does not exists');
  if (0 = WV.WIKI.GETLOCK (DB.DBA.DAV_SEARCH_PATH (topic.ti_res_id, 'R'), uname))
  {
    connection_set('WikiUser', uname);
    WV.WIKI.UPSTREAM_TOPIC_NOW (topic.ti_id);
  }

	return ods_serialize_int_res (1);
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API."wiki.upstream.new" (
	in "cluster" varchar,
	in name varchar,
	in url varchar,
	in "user" varchar,
	in "password" varchar) __soap_http 'text/xml'
{
	declare exit handler for sqlstate '*'
	{
		rollback work;
		return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
	};

  declare inst_id integer;
  declare upstreamID, clusterID integer;
	declare uname varchar;

	if (not ODS.ODS_API.wiki_ods_check_auth (uname, inst_id, "cluster", 'author'))
		return ods_auth_failed ();

  clusterID := (select CLUSTERID from WV..CLUSTERS where CLUSTERNAME = "cluster");
  upstreamID := (select UP_ID from WV..UPSTREAM where UP_CLUSTER_ID = clusterID and UP_NAME = name);
  if (upstreamID is not null)
    signal ('22023', 'The upstream already exists');

  insert into WV..UPSTREAM (UP_CLUSTER_ID, UP_NAME, UP_URI, UP_USER, UP_PASSWD)
    values (clusterID, name, url, "user", "password");
	return ods_serialize_int_res (1);
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API."wiki.upstream.edit" (
	in "cluster" varchar,
	in name varchar,
	in url varchar,
	in "user" varchar,
	in "password" varchar) __soap_http 'text/xml'
{
	declare exit handler for sqlstate '*'
	{
		rollback work;
		return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
	};

  declare inst_id integer;
  declare upstreamID, clusterID integer;
	declare uname varchar;

	if (not ODS.ODS_API.wiki_ods_check_auth (uname, inst_id, "cluster", 'author'))
		return ods_auth_failed ();

  clusterID := (select CLUSTERID from WV..CLUSTERS where CLUSTERNAME = "cluster");
  upstreamID := (select UP_ID from WV..UPSTREAM where UP_CLUSTER_ID = clusterID and UP_NAME = name);
  if (upstreamID is null)
    signal ('22023', 'The upstream does not exist');

  update WV..UPSTREAM
     set UP_NAME = name,
         UP_URI = url,
         UP_USER = "user",
         UP_PASSWD = "password"
    where UP_ID = upstreamID;
	return ods_serialize_int_res (1);
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API."wiki.upstream.delete" (
	in "cluster" varchar,
	in name varchar) __soap_http 'text/xml'
{
	declare exit handler for sqlstate '*'
	{
		rollback work;
		return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
	};

  declare inst_id integer;
  declare upstreamID, clusterID integer;
	declare uname varchar;
	declare clusterName varchar;

	if (not ODS.ODS_API.wiki_ods_check_auth (uname, inst_id, "cluster", 'author'))
		return ods_auth_failed ();

  clusterID := (select CLUSTERID from WV..CLUSTERS where CLUSTERNAME = "cluster");
  upstreamID := (select UP_ID from WV..UPSTREAM where UP_CLUSTER_ID = clusterID and UP_NAME = name);
  if (upstreamID is null)
    signal ('22023', 'The upstream does not exist');

  delete from WV..UPSTREAM where UP_ID = upstreamID;
	return ods_serialize_int_res (1);
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API."wiki.upstream.sync" (
	in "cluster" varchar,
	in name varchar) __soap_http 'text/xml'
{
	declare exit handler for sqlstate '*'
	{
		rollback work;
		return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
	};

  declare inst_id integer;
  declare upstreamID, clusterID integer;
	declare uname varchar;
	declare clusterName varchar;

	if (not ODS.ODS_API.wiki_ods_check_auth (uname, inst_id, "cluster", 'author'))
		return ods_auth_failed ();

  clusterID := (select CLUSTERID from WV..CLUSTERS where CLUSTERNAME = "cluster");
  upstreamID := (select UP_ID from WV..UPSTREAM where UP_CLUSTER_ID = clusterID and UP_NAME = name);
  if (upstreamID is null)
    signal ('22023', 'The upstream does not exist');

  WV..UPSTREAM_ALL (upstreamID);
	return ods_serialize_int_res (1);
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API."wiki.comment.get" (
	in comment_id integer) __soap_http 'text/xml'
{
	declare exit handler for sqlstate '*'
	{
		rollback work;
		return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
	};

	declare uname varchar;
	declare inst_id integer;
	declare clusterName, topicName varchar;
	declare q, iri varchar;
  declare topic WV.WIKI.TOPICINFO;

	whenever not found goto _exit;
	select c.ClusterName,
	       b.LocalName
	  into clusterName,
	       topicName
	  from WV.WIKI.COMMENT a
	         join WV.WIKI.TOPIC b on b.TopicId = a.C_TOPIC_ID
	           join WV.WIKI.CLUSTERS c on c.ClusterId = b.ClusterId
	 where a.C_ID = comment_id;
	if (not ODS.ODS_API.wiki_ods_check_auth (uname, inst_id, "clusterName", 'reader'))
		return ods_auth_failed ();

  topic := ODS.ODS_API."wiki.topic.internal" (inst_id, topicName);
  if (not topic.ti_id)
    signal ('37000', 'The topic does not exist');

	ods_describe_iri (SIOC..wiki_comment_iri (topic.ti_id, comment_id));

_exit:
	return '';
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API."wiki.comment.new" (
	in "cluster" varchar,
	in topic varchar,
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

  declare inst_id integer;
	declare uname varchar;
	declare rc integer;
  declare topicObj WV.WIKI.TOPICINFO;

	rc := -1;
	if (not ODS.ODS_API.wiki_ods_check_auth (uname, inst_id, "cluster", 'author'))
		return ods_auth_failed ();

  topicObj := ODS.ODS_API."wiki.topic.internal" (inst_id, topic);
  if (not topicObj.ti_id)
    signal ('37000', 'The topic does not exists');
  connection_set('WikiUser', uname);

  insert into WV.WIKI.COMMENT (C_TOPIC_ID, C_PARENT_ID, C_SUBJECT, C_TEXT, C_AUTHOR, C_EMAIL, C_DATE, C_HOME)
    values (topicObj.ti_id, parent_id, title, text, uname, email, now (), url);
	rc := (select max (C_ID) from WV.WIKI.COMMENT);

	return ods_serialize_int_res (rc);
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API."wiki.comment.delete" (
	in comment_id integer) __soap_http 'text/xml'
{
	declare exit handler for sqlstate '*'
	{
		rollback work;
		return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
	};

	declare uname varchar;
	declare rc, inst_id integer;
	declare clusterName, topicName varchar;
	declare q, iri varchar;
  declare topic WV.WIKI.TOPICINFO;

  rc := -1;
	whenever not found goto _exit;
	select c.ClusterName,
	       b.LocalName
	  into clusterName,
	       topicName
	  from WV.WIKI.COMMENT a
	         join WV.WIKI.TOPIC b on b.TopicId = a.C_TOPIC_ID
	           join WV.WIKI.CLUSTERS c on c.ClusterId = b.ClusterId
	 where a.C_ID = comment_id;
	if (not ODS.ODS_API.wiki_ods_check_auth (uname, inst_id, "clusterName", 'reader'))
		return ods_auth_failed ();

  topic := ODS.ODS_API."wiki.topic.internal" (inst_id, topicName);
  if (not topic.ti_id)
    signal ('37000', 'The topic does not exist');

	delete from WV.WIKI.COMMENT where C_ID = comment_id;
	rc := row_count ();

_exit:;
	return ods_serialize_int_res (rc);
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API."wiki.options.set" (
	in "cluster" varchar,
	in name varchar,
	in "value" varchar) __soap_http 'text/xml'
{
	declare exit handler for sqlstate '*'
	{
		rollback work;
		return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
	};

  declare inst_id integer;
	declare rc, account_id integer;
	declare uname varchar;
	declare clusterName varchar;

	if (not ODS.ODS_API.wiki_ods_check_auth (uname, inst_id, "cluster", 'author'))
		return ods_auth_failed ();

  clusterName := (select WAI_NAME from DB.DBA.WA_INSTANCE where WAI_ID = inst_id and WAI_TYPE_NAME = 'oWiki');
  if (name = 'indexPage')
  {
    ODS.ODS_API.validate ('wikiWord', "value");
    WV.WIKI.SETCLUSTERPARAM (clusterName, 'index-page', "value");
  }
  else if (name = 'newTopicTemplate')
  {
    WV.WIKI.SETCLUSTERPARAM (clusterName, 'new-topic-template', "value");
  }
  else if (name = 'skinSource')
  {
    WV.WIKI.SETCLUSTERPARAM (clusterName, 'skin-source', "value");
  }
  else if (name = 'primarySkin')
  {
    WV.WIKI.SETCLUSTERPARAM (clusterName, 'skin', "value");
  }
  else if (name = 'secondarySkin')
  {
    WV.WIKI.SETCLUSTERPARAM (clusterName, 'skin2', "value");
  }
  else if (name = 'wikiPlugin')
  {
    if ("value" not in ('oWiki', 'MediaWiki', 'CreoleWiki'))
      signal ('22023', 'Bad Wiki plugin');
    WV.WIKI.CLUSTERPARAM (clusterName, 'plugin', get_keyword ("value", vector ('oWiki', '0', 'MediaWiki', '1', 'CreoleWiki', '2'), '0'));
  }
  else if (name = 'newCategoryTempate')
  {
    WV.WIKI.SETCLUSTERPARAM (clusterName, 'new-category-template', "value");
  }
  else if (name = 'vhostRegularExpression')
  {
    WV.WIKI.SETCLUSTERPARAM (clusterName, 'skin2-vhost-regexp', "value");
  }
  else if (name = 'deliciousEnabled')
  {
    WV.WIKI.SETCLUSTERPARAM (clusterName, 'delicious_enabled', ODS.ODS_API.check2integer ("value"));
  }
  else if (name = 'webmailEnabled')
  {
    WV.WIKI.SETCLUSTERPARAM (clusterName, 'webmail_enabled', ODS.ODS_API.check2integer ("value"));
    if (ODS.ODS_API.check2integer ("value") = 1)
    {
      if (WV.WIKI.CLUSTERPARAM (clusterName, 'webmail_initialized') is null)
      {
        DB.DBA.VAD_LOAD_SQL_FILE('/DAV/VAD/wiki/webmail.sql', 1, 'report', 1);
        WV.WIKI.SETCLUSTERPARAM (clusterName, 'webmail_initialized', 1);
      }
    }
  }
  else if (name = 'antiSpam')
  {
    WV.WIKI.SETCLUSTERPARAM (clusterName, 'email-obfuscate', "value");
  }
  else if (name = 'technoratiApiKey')
  {
    if (isnull (regexp_match('^[a-z0-9]{32}\$|^[ ]*\$', "value")))
      signal ('22023', 'API key is expected');
    WV.WIKI.SETCLUSTERPARAM (clusterName, 'technorati_api_key', "value");
  }
  else if (name = 'conversationEnabled')
  {
    WV.WIKI.SETCLUSTERPARAM (clusterName, 'conv_enabled', ODS.ODS_API.check2integer ("value"));
    WV.WIKI.TOGGLE_CONVERSATION (clusterName, ODS.ODS_API.check2integer ("value"));
  }
  else if (name = 'inlineMacros')
  {
    WV.WIKI.SETCLUSTERPARAM (clusterName, 'syscalls', ODS.ODS_API.check2integer ("value"));
  }
  else if (name = 'interClusterAutolinks')
  {
    WV.WIKI.SETCLUSTERPARAM (clusterName, 'qwiki', ODS.ODS_API.check2integer ("value"));
  }
  else
  {
	  return ods_serialize_int_res (-1);
  }
	return ods_serialize_int_res (1);
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API."wiki.options.get" (
	in "cluster" varchar,
	in name varchar) __soap_http 'text/plain'
{
	declare exit handler for sqlstate '*'
	{
		rollback work;
		return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
	};

  declare inst_id integer;
	declare rc, account_id integer;
	declare uname varchar;
	declare clusterName varchar;
	declare "value" any;

	if (not ODS.ODS_API.wiki_ods_check_auth (uname, inst_id, "cluster", 'author'))
		return ods_auth_failed ();

  clusterName := (select WAI_NAME from DB.DBA.WA_INSTANCE where WAI_ID = inst_id and WAI_TYPE_NAME = 'oWiki');
  "value" := null;
  if (name = 'indexPage')
  {
    "value" := WV.WIKI.CLUSTERPARAM (clusterName, 'index-page', 'WelcomeVisitors');
  }
  else if (name = 'skinSource')
  {
    "value" := WV.WIKI.CLUSTERPARAM (clusterName, 'skin-source', 'Local');
  }
  else if (name = 'primarySkin')
  {
    "value" := WV.WIKI.CLUSTERPARAM (clusterName, 'skin', 'default');
  }
  else if (name = 'secondarySkin')
  {
    "value" := WV.WIKI.CLUSTERPARAM (clusterName, 'skin2', 'default');
  }
  else if (name = 'wikiPlugin')
  {
    "value" := get_keyword (WV.WIKI.CLUSTERPARAM (clusterName, 'plugin', '0'), vector ('0', 'oWiki', '1', 'MediaWiki', '2', 'CreoleWiki'), 'oWiki');
  }
  else if (name = 'newTopicTemplate')
  {
    "value" := WV.WIKI.CLUSTERPARAM (clusterName, 'new-topic-template', '');
  }
  else if (name = 'newCategoryTempate')
  {
    "value" := WV.WIKI.CLUSTERPARAM (clusterName, 'new-category-template', '');
  }
  else if (name = 'vhostRegularExpression')
  {
    "value" := WV.WIKI.CLUSTERPARAM (clusterName, 'skin2-vhost-regexp', '');
  }
  else if (name = 'deliciousEnabled')
  {
    "value" := ODS.ODS_API.check2string (WV.WIKI.CLUSTERPARAM (clusterName, 'delicious_enabled', 2));
  }
  else if (name = 'webmailEnabled')
  {
    "value" := ODS.ODS_API.check2string (WV.WIKI.CLUSTERPARAM (clusterName, 'webmail_enabled', 2));
  }
  else if (name = 'antiSpam')
  {
    "value" := WV.WIKI.SETCLUSTERPARAM (clusterName, 'email-obfuscate', 'NONE');
  }
  else if (name = 'technoratiApiKey')
  {
    "value" := WV.WIKI.CLUSTERPARAM (clusterName, 'technorati_api_key', '');
  }
  else if (name = 'conversationEnabled')
  {
    "value" := ODS.ODS_API.check2string (WV.WIKI.CLUSTERPARAM (clusterName, 'conv_enabled', 2));
  }
  else if (name = 'inlineMacros')
  {
    "value" := ODS.ODS_API.check2string (WV.WIKI.CLUSTERPARAM (clusterName, 'syscalls', 2));
  }
  else if (name = 'interClusterAutolinks')
  {
    "value" := ODS.ODS_API.check2string (WV.WIKI.CLUSTERPARAM (clusterName, 'qwiki', 2));
  }
  else
  {
	  return ods_serialize_int_res (-1);
  }

	return "value";
}
;

grant execute on ODS.ODS_API."wiki.topic.new" to ODS_API;
grant execute on ODS.ODS_API."wiki.topic.get" to ODS_API;
grant execute on ODS.ODS_API."wiki.topic.versions" to ODS_API;
grant execute on ODS.ODS_API."wiki.topic.versions.get" to ODS_API;
grant execute on ODS.ODS_API."wiki.topic.versions.diff" to ODS_API;
grant execute on ODS.ODS_API."wiki.topic.edit" to ODS_API;
grant execute on ODS.ODS_API."wiki.topic.delete" to ODS_API;
grant execute on ODS.ODS_API."wiki.topic.sync" to ODS_API;
grant execute on ODS.ODS_API."wiki.upstream.new" to ODS_API;
grant execute on ODS.ODS_API."wiki.upstream.edit" to ODS_API;
grant execute on ODS.ODS_API."wiki.upstream.delete" to ODS_API;
grant execute on ODS.ODS_API."wiki.upstream.sync" to ODS_API;
grant execute on ODS.ODS_API."wiki.comment.get" to ODS_API;
grant execute on ODS.ODS_API."wiki.comment.new" to ODS_API;
grant execute on ODS.ODS_API."wiki.comment.delete" to ODS_API;

grant execute on ODS.ODS_API."wiki.options.set" to ODS_API;
grant execute on ODS.ODS_API."wiki.options.get" to ODS_API;

use DB;
