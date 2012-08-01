-- Weblog APIs
use ODS;

create procedure ODS.ODS_API."weblog.post.new" (
    in inst_id int,
    in categories any := null,
    in date_created datetime := null,
    in description varchar,
    in enclosure any := null,
    in source any := null,
    in title varchar,
    in link varchar := null,
    in author varchar := null,
    in comments varchar := null,
    in allow_comments smallint := 1,
    in allow_pings smallint := 1,
    in convert_breaks smallint := 0,
    in excerpt varchar := null,
    in tb_ping_urls any := null,
    in text_more varchar := null,
    in keywords varchar := null,
    in publish smallint := 1
    ) __soap_http 'text/xml'
{
  declare uname, passwd, blog_id varchar;
  declare rc int;
  declare struct BLOG.DBA."MTWeblogPost";

  declare exit handler for sqlstate '*' {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };
  if (not ods_check_auth (uname, inst_id, 'author'))
    return ods_auth_failed ();

  struct := new BLOG.DBA."MTWeblogPost" ();
  struct.categories := split_and_decode (categories, 0, '\0\0,');
  struct.dateCreated := date_created;
  struct.description := description;
  -- struct.enclosure := blog_deserialize_enclosure (enclosure);
  -- struct.source := blog_deserialize_source (source);
  struct.title := title;
  struct.link := link;
  struct.author := author;
  struct.comments := comments;
  struct.mt_allow_comments := allow_comments;
  struct.mt_allow_pings := allow_pings;
  struct.mt_convert_breaks := convert_breaks;
  struct.mt_excerpt := excerpt;
  struct.mt_tb_ping_urls := split_and_decode (tb_ping_urls, 0, '\0\0,');
  struct.mt_text_more := text_more;
  struct.mt_keywords := keywords;

  whenever not found goto ret;
  select BI_BLOG_ID into blog_id from BLOG.DBA.SYS_BLOG_INFO, DB.DBA.WA_INSTANCE where WAI_NAME = BI_WAI_NAME and WAI_ID = inst_id;
  passwd := __user_password (uname);
  rc := BLOG.DBA."metaWeblog.newPost" (blog_id, uname, passwd, struct, publish);

ret:
  return ods_serialize_int_res (rc);
}
;

create procedure ODS.ODS_API."weblog.post.edit" (
    in post_id int,
    in categories any := null,
    in date_created datetime := null,
    in description varchar,
    in enclosure any := null,
    in source any := null,
    in title varchar,
    in link varchar := null,
    in author varchar := null,
    in comments varchar := null,
    in allow_comments smallint := 1,
    in allow_pings smallint := 1,
    in convert_breaks smallint := 0,
    in excerpt varchar := null,
    in tb_ping_urls any := null,
    in text_more varchar := null,
    in keywords varchar := null,
    in publish smallint := 1
    ) __soap_http 'text/xml'
{
  declare uname, passwd, blog_id varchar;
  declare rc int;
  declare struct BLOG.DBA."MTWeblogPost";
  declare inst_id int;

  declare exit handler for sqlstate '*' {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };
  whenever not found goto ret;
  select WAI_ID into inst_id from DB.DBA.WA_INSTANCE, BLOG.DBA.SYS_BLOG_INFO, BLOG.DBA.SYS_BLOGS where
      BI_BLOG_ID = B_BLOG_ID and B_POST_ID = post_id and BI_WAI_NAME = WAI_NAME;

  if (not ods_check_auth (uname, inst_id, 'author'))
    return ods_auth_failed ();

  struct := new BLOG.DBA."MTWeblogPost" ();
  struct.categories := split_and_decode (categories, 0, '\0\0,');
  struct.dateCreated := date_created;
  struct.description := description;
  -- struct.enclosure := blog_deserialize_enclosure (enclosure);
  -- struct.source := blog_deserialize_source (source);
  struct.title := title;
  struct.link := link;
  struct.author := author;
  struct.comments := comments;
  struct.mt_allow_comments := allow_comments;
  struct.mt_allow_pings := allow_pings;
  struct.mt_convert_breaks := convert_breaks;
  struct.mt_excerpt := excerpt;
  struct.mt_tb_ping_urls := split_and_decode (tb_ping_urls, 0, '\0\0,');
  struct.mt_text_more := text_more;
  struct.mt_keywords := keywords;

  whenever not found goto ret;
  passwd := __user_password (uname);
  rc := BLOG.DBA."metaWeblog.editPost" (post_id, uname, passwd, struct, publish);
ret:
  return ods_serialize_int_res (rc);
}
;

create procedure ODS.ODS_API."weblog.post.delete" (in post_id varchar) __soap_http 'text/xml'
{
  declare uname, passwd varchar;
  declare rc int;
  declare inst_id int;

  declare exit handler for sqlstate '*' {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };
  whenever not found goto ret;
  select WAI_ID into inst_id from DB.DBA.WA_INSTANCE, BLOG.DBA.SYS_BLOG_INFO, BLOG.DBA.SYS_BLOGS where
      BI_BLOG_ID = B_BLOG_ID and B_POST_ID = post_id and BI_WAI_NAME = WAI_NAME;

  if (not ods_check_auth (uname, inst_id, 'author'))
    return ods_auth_failed ();

  passwd := __user_password (uname);
  rc := BLOG.DBA."blogger.deletePost" ('ODS-API', post_id, uname, passwd, 1);
ret:
  return ods_serialize_int_res (rc);
}
;

create procedure ODS.ODS_API."weblog.post.get" (in post_id varchar) __soap_http 'text/xml'
{
  declare uname varchar;
  declare rc int;
  declare q, iri, blog_id varchar;
  declare inst_id int;

  declare exit handler for sqlstate '*' {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };
  whenever not found goto ret;
  select WAI_ID, BI_BLOG_ID into inst_id, blog_id from DB.DBA.WA_INSTANCE, BLOG.DBA.SYS_BLOG_INFO, BLOG.DBA.SYS_BLOGS where
      BI_BLOG_ID = B_BLOG_ID and B_POST_ID = post_id and BI_WAI_NAME = WAI_NAME;

  if (not ods_check_auth (uname, inst_id, 'reader'))
    return ods_auth_failed ();

  ods_describe_iri (sioc..blog_post_iri (blog_id, post_id));
ret:
  return '';
}
;

create procedure ODS.ODS_API."weblog.comment.get" (in post_id varchar, in comment_id int := null) __soap_http 'text/xml'
{
  declare uname varchar;
  declare rc int;
  declare q, iri, blog_id varchar;
  declare inst_id int;

  declare exit handler for sqlstate '*' {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };
  whenever not found goto ret;
  select WAI_ID, BI_BLOG_ID into inst_id, blog_id from DB.DBA.WA_INSTANCE, BLOG.DBA.SYS_BLOG_INFO, BLOG.DBA.SYS_BLOGS where
      BI_BLOG_ID = B_BLOG_ID and B_POST_ID = post_id and BI_WAI_NAME = WAI_NAME;

  if (not ods_check_auth (uname, inst_id, 'reader'))
    return ods_auth_failed ();

  if (comment_id is null)
    {
      iri := sioc..fix_uri (sioc..blog_post_iri (blog_id, post_id));
      q := sprintf ('describe ?x from <%s> where { <%s> sioc:has_reply ?x }', ods_graph (), iri);
    }
  else
    {
      iri := sioc..fix_uri (sioc..blog_comment_iri (blog_id, post_id, comment_id));
      q := sprintf ('describe <%s> from <%s>', iri, ods_graph ());
    }
  exec_sparql (q);
ret:
  return '';
}
;

create procedure ODS.ODS_API."weblog.comment.approve" (in post_id int, in comment_id int, in flag smallint) __soap_http 'text/xml'
{
  declare uname, blog_id varchar;
  declare rc int;
  declare inst_id int;
  declare msg varchar;

  declare exit handler for sqlstate '*' {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };
  whenever not found goto ret;
  msg := 'No such post';
  rc := -1;
  select WAI_ID, BI_BLOG_ID into inst_id, blog_id from DB.DBA.WA_INSTANCE, BLOG.DBA.SYS_BLOG_INFO, BLOG.DBA.SYS_BLOGS where
      BI_BLOG_ID = B_BLOG_ID and B_POST_ID = post_id and BI_WAI_NAME = WAI_NAME;

  if (not ods_check_auth (uname, inst_id, 'author'))
    return ods_auth_failed ();

  if (flag not in (-1, 0, 1))
    {
      rc := -1;
      msg := 'Flag must be 0, 1 or -1.';
    }
  else
    {
      declare spam int;
      spam := 1;
      if (flag = 1 or flag = 0)
	spam := 0;
      update BLOG..BLOG_COMMENTS set BM_IS_PUB = abs(flag), BM_IS_SPAM = spam
	  where BM_BLOG_ID = blog_id and BM_POST_ID = post_id and BM_ID = comment_id;
      rc := row_count ();
      msg := '';
    }
ret:
  return ods_serialize_int_res (rc, msg);
}
;

create procedure ODS.ODS_API."weblog.comment.delete" (in post_id int, in comment_id int) __soap_http 'text/xml'
{
  declare uname, blog_id varchar;
  declare rc int;
  declare inst_id int;
  declare msg varchar;

  declare exit handler for sqlstate '*' {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };
  whenever not found goto ret;
  msg := 'No such post';
  rc := -1;
  select WAI_ID, BI_BLOG_ID into inst_id, blog_id from DB.DBA.WA_INSTANCE, BLOG.DBA.SYS_BLOG_INFO, BLOG.DBA.SYS_BLOGS where
      BI_BLOG_ID = B_BLOG_ID and B_POST_ID = post_id and BI_WAI_NAME = WAI_NAME;

  if (not ods_check_auth (uname, inst_id))
    return ods_auth_failed ();
  delete from BLOG..BLOG_COMMENTS
	  where BM_BLOG_ID = blog_id and BM_POST_ID = post_id and BM_ID = comment_id;
  rc := row_count ();
  msg := '';
ret:
  return ods_serialize_int_res (rc);
}
;

create procedure ODS.ODS_API."weblog.comment.new" (
	in post_id varchar,
	in name varchar,
	in title varchar,
	in email varchar,
	in url varchar,
	in text varchar
	) __soap_http 'text/xml'
{
  declare uname, blog_id varchar;
  declare rc, inst_id, auth_rc, comment_id int;
  declare msg varchar;

  rc := -1;
  declare exit handler for sqlstate '*' {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };
  whenever not found goto ret;
  select WAI_ID, BI_BLOG_ID into inst_id, blog_id from DB.DBA.WA_INSTANCE, BLOG.DBA.SYS_BLOG_INFO, BLOG.DBA.SYS_BLOGS where
      BI_BLOG_ID = B_BLOG_ID and B_POST_ID = post_id and BI_WAI_NAME = WAI_NAME;
  auth_rc := ods_check_auth (uname, inst_id, 'author');

  msg := MT.MT.comments (post_id, title, sprintf ('%s <%s>', name, email), url, text);
  if (auth_rc)
    {
      comment_id := identity_value ();
      update BLOG.DBA.BLOG_COMMENTS set BM_IS_PUB = 1 where BM_BLOG_ID = blog_id and BM_POST_ID = post_id and BM_ID = comment_id;
    }
  if (strstr (msg, 'success') is not null)
    rc := 1;
ret:
  return ods_serialize_int_res (rc, msg);
}
;

create procedure ODS.ODS_API."weblog.get" (in inst_id int) __soap_http 'text/xml'
{
  declare uname, inst_name, blog_id varchar;
  declare rc int;

  declare exit handler for sqlstate '*' {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };
  if (not ods_check_auth (uname, inst_id, 'reader'))
    return ods_auth_failed ();

  whenever not found goto ret;
  select WAI_NAME into inst_name from DB.DBA.WA_INSTANCE where WAI_ID = inst_id;

  ods_describe_iri (sioc..blog_iri (inst_name));
ret:
  return '';
}
;

create procedure ODS.ODS_API."weblog.options.set" (
  in inst_id int, in options any) __soap_http 'text/xml'
{
  declare uname varchar;
  declare rc int;
  declare msg varchar;

  declare exit handler for sqlstate '*' {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };
  if (not ods_check_auth (uname, inst_id, 'author'))
    return ods_auth_failed ();

  if (not exists (select 1 from DB.DBA.WA_INSTANCE where WAI_ID = inst_id and WAI_TYPE_NAME = 'WEBLOG2'))
    return ods_serialize_sql_error ('37000', 'The instance is not found');

  msg := '';

  -- TODO: not implemented
ret:
  return ods_serialize_int_res (rc);
}
;

create procedure ODS.ODS_API."weblog.options.get" (
  in inst_id int) __soap_http 'text/xml'
{
  declare uname varchar;
  declare rc int;

  declare exit handler for sqlstate '*' {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };
  if (not ods_check_auth (uname, inst_id, 'author'))
    return ods_auth_failed ();

  if (not exists (select 1 from DB.DBA.WA_INSTANCE where WAI_ID = inst_id and WAI_TYPE_NAME = 'WEBLOG2'))
    return ods_serialize_sql_error ('37000', 'The instance is not found');

  -- TODO: not implemented
ret:
  return ods_serialize_int_res (rc);
}
;

create procedure ODS.ODS_API."weblog.upstreaming.set" (
    in inst_id int,
    in target_rpc_url varchar,
    in target_blog_id varchar,
    in target_protocol_id varchar,
    in target_uname varchar,
    in target_password varchar,
    in acl_allow any := '',
    in acl_deny any := '',
    in sync_interval int := 10,
    in keep_remote smallint := 1,
    in max_retries int := -1,
    in max_retransmits int := 5,
  in initialize_log int := 0) __soap_http 'text/xml'
{
  declare uname, blog_id varchar;
  declare rc int;
  declare jid int;
  declare msg varchar;

  declare exit handler for sqlstate '*' {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };
  if (not ods_check_auth (uname, inst_id, 'author'))
    return ods_auth_failed ();

  whenever not found goto ret;
  msg := 'No such blog';
  rc := -1;
  select BI_BLOG_ID into blog_id from BLOG.DBA.SYS_BLOG_INFO, DB.DBA.WA_INSTANCE where WAI_NAME = BI_WAI_NAME and WAI_ID = inst_id;

  jid := coalesce((select top 1 R_JOB_ID from BLOG.DBA.SYS_ROUTING order by R_JOB_ID desc), 0)+1;

  insert into BLOG.DBA.SYS_ROUTING (
                              R_JOB_ID,
                              R_DESTINATION,
                              R_AUTH_USER,
                              R_AUTH_PWD,
                              R_ITEM_ID,
                              R_TYPE_ID,
                              R_PROTOCOL_ID,
                              R_DESTINATION_ID,
                              R_FREQUENCY,
                              R_EXCEPTION_ID,
			      R_INCLUSION_ID,
			      R_KEEP_REMOTE,
			      R_MAX_ERRORS,
			      R_ITEM_MAX_RETRANSMITS
			      )
                            values (
                              jid,
                              target_rpc_url,
                              target_uname,
                              target_password,
                              blog_id,
                              1,
                              target_protocol_id,
                              target_blog_id,
                              sync_interval,
                              acl_deny,
			      acl_allow,
			      keep_remote,
			      max_retries,
			      max_retransmits
			      );
    if (row_count ())
      {
      rc := jid;
	msg := 'Created';
      }

    if (initialize_log)
      {
	for select B_POST_ID from BLOG.DBA.SYS_BLOGS where B_STATE = 2 and B_BLOG_ID = blog_id
	  do
	    {
	      insert soft BLOG.DBA.SYS_BLOGS_ROUTING_LOG (RL_JOB_ID, RL_POST_ID, RL_TYPE) values (jid, B_POST_ID, 'I');
	    }
      }
ret:
  return ods_serialize_int_res (rc);
}
;

create procedure ODS.ODS_API."weblog.upstreaming.get" (
    in job_id int := null
    ) __soap_http 'text/xml'
{
  declare uname varchar;
  declare rc, inst_id int;

  declare exit handler for sqlstate '*' {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };
  whenever not found goto ret;
  select WAI_ID into inst_id from DB.DBA.WA_INSTANCE, BLOG.DBA.SYS_BLOG_INFO, BLOG.DBA.SYS_ROUTING where
      R_JOB_ID = job_id and BI_WAI_NAME = WAI_NAME and R_ITEM_ID = BI_BLOG_ID;

  if (not ods_check_auth (uname, inst_id, 'author'))
    return ods_auth_failed ();

  -- TODO: not implemented
ret:
  return ods_serialize_int_res (rc);
}
;


create procedure ODS.ODS_API."weblog.upstreaming.remove" (
  in job_id int) __soap_http 'text/xml'
{
  declare uname varchar;
  declare rc int;
  declare inst_id int;
  declare msg varchar;

  declare exit handler for sqlstate '*' {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };
  whenever not found goto ret;
  msg := 'No such blog';
  rc := -1;
  select WAI_ID into inst_id from DB.DBA.WA_INSTANCE, BLOG.DBA.SYS_BLOG_INFO, BLOG.DBA.SYS_ROUTING where
      R_JOB_ID = job_id and BI_WAI_NAME = WAI_NAME and R_ITEM_ID = BI_BLOG_ID;

  if (not ods_check_auth (uname, inst_id, 'author'))
    return ods_auth_failed ();

  delete from BLOG.DBA.SYS_ROUTING where R_JOB_ID = job_id;
  rc := row_count ();
  msg := '';
ret:
  return ods_serialize_int_res (rc);
}
;

create procedure ODS.ODS_API."weblog.tagging.set" (
    in inst_id int,
    in flag int
    ) __soap_http 'text/xml'
{
  declare uname, blog_id varchar;
  declare rc int;
  declare msg varchar;

  if (not ods_check_auth (uname, inst_id, 'author'))
    return ods_auth_failed ();

  whenever not found goto ret;
  msg := 'No such blog';
  rc := -1;
  select BI_BLOG_ID into blog_id from BLOG.DBA.SYS_BLOG_INFO, DB.DBA.WA_INSTANCE where WAI_NAME = BI_WAI_NAME and WAI_ID = inst_id;
  update BLOG.DBA.SYS_BLOG_INFO set BI_AUTO_TAGGING = flag where BI_BLOG_ID = blog_id;
  rc := row_count ();
  msg := '';
ret:
  return ods_serialize_int_res (rc);
}
;

create procedure ODS.ODS_API."weblog.tagging.retag" (
    in inst_id int,
    in keep_existing_tags int
    ) __soap_http 'text/xml'
{
  declare uname, blog_id varchar;
  declare rc, flag, job, user_id int;
  declare dummy, ruls any;
  declare msg varchar;

  declare exit handler for sqlstate '*' {
    rollback work;
    return ods_serialize_sql_error (__SQL_STATE, __SQL_MESSAGE);
  };
  if (not ods_check_auth (uname, inst_id, 'author'))
    return ods_auth_failed ();

  whenever not found goto ret;
  msg := 'No such blog';
  rc := -1;
  select BI_BLOG_ID into blog_id from BLOG.DBA.SYS_BLOG_INFO, DB.DBA.WA_INSTANCE where WAI_NAME = BI_WAI_NAME and WAI_ID = inst_id;
  job := (select top 1 R_JOB_ID from BLOG..SYS_ROUTING where R_ITEM_ID = blog_id and R_TYPE_ID = 3 and R_PROTOCOL_ID = 6);
  select U_ID into user_id from DB.DBA.SYS_USERS where U_NAME = uname;

  ruls := DB.DBA.user_tag_rules (user_id);
  for select B_TITLE, B_CONTENT, B_POST_ID from BLOG..SYS_BLOGS where B_BLOG_ID = blog_id do
    {
      flag := BLOG.DBA.RE_TAG_POST (blog_id, B_POST_ID, user_id, inst_id, B_CONTENT, keep_existing_tags, dummy, job, ruls, 1);
      if (job is not null and length (flag))
	{
	  insert replacing BLOG..SYS_BLOGS_ROUTING_LOG (RL_JOB_ID, RL_POST_ID, RL_TYPE) values (job, B_POST_ID, flag);
	}
    }
  rc := 1;
  msg := '';
ret:
  return ods_serialize_int_res (rc);
}
;

grant execute on ODS.ODS_API."weblog.post.new" to ODS_API;
grant execute on ODS.ODS_API."weblog.post.edit" to ODS_API;
grant execute on ODS.ODS_API."weblog.post.delete" to ODS_API;
grant execute on ODS.ODS_API."weblog.post.get" to ODS_API;
grant execute on ODS.ODS_API."weblog.comment.get" to ODS_API;
grant execute on ODS.ODS_API."weblog.comment.approve" to ODS_API;
grant execute on ODS.ODS_API."weblog.comment.delete" to ODS_API;
grant execute on ODS.ODS_API."weblog.comment.new" to ODS_API;
grant execute on ODS.ODS_API."weblog.get" to ODS_API;
grant execute on ODS.ODS_API."weblog.options.set" to ODS_API;
grant execute on ODS.ODS_API."weblog.options.get" to ODS_API;
grant execute on ODS.ODS_API."weblog.upstreaming.set" to ODS_API;
grant execute on ODS.ODS_API."weblog.upstreaming.get" to ODS_API;
grant execute on ODS.ODS_API."weblog.upstreaming.remove" to ODS_API;
grant execute on ODS.ODS_API."weblog.tagging.set" to ODS_API;
grant execute on ODS.ODS_API."weblog.tagging.retag" to ODS_API;
grant execute on DB.DBA.XML_URI_GET_STRING_OR_ENT to ODS_API;

use DB;
