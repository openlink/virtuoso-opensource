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

-- discussion.groups.get
-- discussion.group.add
-- discussion.group.get
-- discussion.group.remove
-- discussion.feed.new
-- discussion.feed.remove
-- discussion.message.new
-- discussion.message.get
-- discussion.comment.new
-- discussion.comment.get

use ODS;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API."discussion.groups.get" ()  __soap_http 'text/xml'
{
  declare exit handler for sqlstate '*'
  {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };

  declare rc integer;
  declare uname varchar;

  if (not ods_check_auth (uname, -1, 'reader'))
    return ods_auth_failed ();

  http ((select replace (serialize_to_UTF8_xml (XMLELEMENT ('groups', XMLAGG (XMLELEMENT ('group', XMLATTRIBUTES (NG_GROUP as "id"), NG_NAME)))), '><', '>\n  <') from DB.DBA.NEWS_GROUPS));
  return '';
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API."discussion.group.get" (
  in group_id integer)  __soap_http 'text/xml'
{
  declare exit handler for sqlstate '*'
  {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };
  declare rc integer;
  declare uname varchar;

  if (not ods_check_auth (uname, -1, 'reader'))
    return ods_auth_failed ();

  ods_describe_iri (SIOC..forum_iri ('nntpf', (select NG_NAME from DB.DBA.NEWS_GROUPS where NG_GROUP = group_id)));
  return '';
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API."discussion.group.new" (
  in name varchar,
  in description varchar)  __soap_http 'text/xml'
{
  declare exit handler for sqlstate '*'
  {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };

  declare rc integer;
  declare uname varchar;

  if (not ods_check_auth (uname, -1, 'owner'))
    return ods_auth_failed ();

  if (exists (select 1 from DB.DBA.NEWS_GROUPS where NG_NAME = name))
  {
 	  signal ('NNTP1', 'The group already exists.');
  } else {
		insert soft DB.DBA.NEWS_GROUPS (NG_NAME, NG_DESC, NG_SERVER, NG_POST, NG_STAT, NG_CREAT, NG_LAST, NG_FIRST, NG_NUM, NG_NEXT_NUM)
			values (name, description, NULL, 1, 1, now(), 0, 0, 0, 0);
		rc := (select max (NG_GROUP) from DB.DBA.NEWS_GROUPS);
	}
  return ods_serialize_int_res (rc);
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API."discussion.group.remove" (
  in group_id integer) __soap_http 'text/xml'
{
  declare exit handler for sqlstate '*'
  {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };

  declare rc integer;
  declare uname varchar;
  declare _nm_m_id varchar;

  if (not ods_check_auth (uname, -1, 'owner'))
    return ods_auth_failed ();

  if (not exists (select 1 from DB.DBA.NEWS_GROUPS where NG_GROUP = group_id))
    return ods_serialize_sql_error ('37000', 'The item not found');
  declare nmc cursor for select NM_KEY_ID from DB.DBA.NEWS_MULTI_MSG where NM_GROUP = group_id;
	whenever not found goto _exit;
	open nmc (exclusive, prefetch 1);
	while (1)
	{
	  fetch nmc into _nm_m_id;
	  delete from DB.DBA.NEWS_MULTI_MSG where current of nmc;
	  if (not exists (select 1 from DB.DBA.NEWS_MULTI_MSG where NM_KEY_ID = _nm_m_id))
	    delete from DB.DBA.NEWS_MSG where NM_ID = _nm_m_id;
	}
_exit:;
	delete from DB.DBA.NEWS_GROUPS where NG_GROUP = group_id;

  return ods_serialize_int_res (1);
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API."discussion.feed.new" (
  in group_id integer,
  in name varchar) __soap_http 'text/xml'
{
  declare exit handler for sqlstate '*'
  {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };

  declare rc, account_id integer;
  declare uname varchar;
  declare rss_id, rss_url, rss_parameters any;

  if (not ods_check_auth (uname, -1, 'owner'))
    return ods_auth_failed ();

  if (not exists (select 1 from DB.DBA.NEWS_GROUPS where NG_GROUP = group_id))
    return ods_serialize_sql_error ('37000', 'The item not found');

  account_id := (select U_ID from DB.DBA.SYS_USERS where U_NAME = uname);
  rss_id := uuid ();
  rss_url := '/nntpf/rss.vsp?rss=' || rss_id;
  rss_parameters := vector ('group', group_id);

  insert into DB.DBA.NNTPFE_USERRSSFEEDS (FEURF_ID, FEURF_USERID, FEURF_DESCR, FEURF_URL, FEURF_PARAM)
    values (rss_id, account_id, name, rss_url, serialize (rss_parameters));

  return rss_id;
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API."discussion.feed.remove" (
  in feed_id varchar) __soap_http 'text/xml'
{
  declare exit handler for sqlstate '*'
  {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };

  declare rc integer;
  declare uname varchar;

  if (not ods_check_auth (uname, -1, 'owner'))
    return ods_auth_failed ();

  DB.DBA.nntpf_delete_rss_feed (uname, feed_id);

  return ods_serialize_int_res (1);
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API."discussion.message.new" (
  in group_id integer,
  in subject varchar := '',
  in body varchar := '') __soap_http 'text/xml'
{
  declare rc any;

  declare exit handler for sqlstate '*'
  {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };

  declare rc integer;
  declare uname, post_from varchar;
  declare params any;

  if (not ods_check_auth (uname, -1, 'owner'))
    return ods_auth_failed ();

  if (not exists (select 1 from DB.DBA.NEWS_GROUPS where NG_GROUP = group_id))
    return ods_serialize_sql_error ('37000', 'The item not found');

  DB.DBA.nntpf_compose_post_from (uname, post_from);
  params := vector ();
  params := vector_concat (params, vector ('availble_groups', (select NG_NAME from DB.DBA.NEWS_GROUPS where NG_GROUP = group_id)));
  params := vector_concat (params, vector ('post_subj_n', subject));
  params := vector_concat (params, vector ('post_body_n', body));
  params := vector_concat (params, vector ('post_from_n', post_from));

  rc := DB.DBA.nntpf_post_message (params, uname);
  return rc;
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API."discussion.message.get" (
  in message_id varchar) __soap_http 'text/xml'
{
  declare exit handler for sqlstate '*'
  {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };
  declare rc integer;
  declare uname, group_name varchar;

  if (not ods_check_auth (uname, -1, 'reader'))
    return ods_auth_failed ();

  group_name := (select NG_NAME from DB.DBA.NEWS_GROUPS, DB.DBA.NEWS_MESSAGES where NM_ID = message_id and NG_GROUP = NM_GROUP);
  ods_describe_iri (SIOC..nntp_post_iri (group_name, message_id));
  return '';
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API."discussion.comment.new" (
  in parent_id varchar,
  in subject varchar := '',
  in body varchar := '') __soap_http 'text/xml'
{
  declare rc any;

  declare exit handler for sqlstate '*'
  {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };

  declare rc integer;
  declare uname, post_from varchar;
  declare params any;
  declare mess_parts, post_old_header any;

  if (not ods_check_auth (uname, -1, 'owner'))
    return ods_auth_failed ();

  if (not exists (select 1 from DB.DBA.NEWS_MSG where NM_ID = parent_id))
    return ods_serialize_sql_error ('37000', 'The item not found');

  mess_parts := DB.DBA.nntpf_post_get_message_parts (parent_id);
  post_old_header := mess_parts[2];

  DB.DBA.nntpf_compose_post_from (uname, post_from);

  params := vector ();
  params := vector_concat (params, vector ('post_subj_n', subject));
  params := vector_concat (params, vector ('post_body_n', body));
  params := vector_concat (params, vector ('post_from_n', post_from));
  params := vector_concat (params, vector ('post_old_hdr', post_old_header));

  rc := DB.DBA.nntpf_post_message (params, uname);
  return rc;
}
;

-------------------------------------------------------------------------------
--
create procedure ODS.ODS_API."discussion.comment.get" (
  in comment_id varchar) __soap_http 'text/xml'
{
  declare exit handler for sqlstate '*'
  {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };

  declare rc integer;
  declare uname, group_name varchar;
  declare q, iri varchar;

  if (not ods_check_auth (uname, -1, 'reader'))
    return ods_auth_failed ();

  group_name := (select NG_NAME from DB.DBA.NEWS_GROUPS, DB.DBA.NEWS_MESSAGES where NM_ID = comment_id and NG_GROUP = NM_GROUP);
  ods_describe_iri (SIOC..nntp_post_iri (group_name, comment_id));
  return '';
}
;

grant execute on ODS.ODS_API."discussion.groups.get" to ODS_API;
grant execute on ODS.ODS_API."discussion.group.get" to ODS_API;
grant execute on ODS.ODS_API."discussion.group.new" to ODS_API;
grant execute on ODS.ODS_API."discussion.group.remove" to ODS_API;
grant execute on ODS.ODS_API."discussion.feed.new" to ODS_API;
grant execute on ODS.ODS_API."discussion.feed.remove" to ODS_API;
grant execute on ODS.ODS_API."discussion.message.get" to ODS_API;
grant execute on ODS.ODS_API."discussion.message.new" to ODS_API;
grant execute on ODS.ODS_API."discussion.comment.get" to ODS_API;
grant execute on ODS.ODS_API."discussion.comment.new" to ODS_API;

use DB;
