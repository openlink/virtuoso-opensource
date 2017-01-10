--
--  $Id$
--
--  Blogger API support.
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2017 OpenLink Software
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

--
-- BLOG SERVER API
--

-- USER DEFINED TYPES

--set MACRO_SUBSTITUTION off;
--set IGNORE_PARAMS on;

create procedure BLOG.DBA.blog2_exec_no_error(in expr varchar) {
  declare state, message, meta, result any;
  exec(expr, state, message, vector(), 0, meta, result);
}
;

create procedure BLOG.DBA.blog2_check_and_create(in old_type_name varchar, in new_type_name varchar, in expr varchar)
{
  declare state, message, meta, result any;

  state := '00000';

  exec(sprintf ('select new %s ()', old_type_name), state, message, vector(), 0, meta, result);

  if (state = '00000')
    expr := ('create type ' || new_type_name || ' under ' || old_type_name);

  exec(expr, state, message, vector(), 0, meta, result);

}
;

create procedure BLOG2_DAV_PROP_SET (
     in path varchar,
     in propname varchar,
     in propvalue any,
     in auth_uname varchar := null,
     in auth_pwd varchar := null,
     in extern integer := 1,
     in check_locks integer := 1,
     in overwrite integer := 1
    )
{
  declare st, id any;
  if ((path <> '') and (path[length(path)-1] = 47))
    st := 'C';
  else
    st := 'R';
  id := DAV_SEARCH_ID (path, st);
  if (id < 0)
    return id;
  DAV_PROP_SET_RAW (id, st, propname, propvalue, overwrite, http_dav_uid ());
}
;


create procedure
BLOG2_UPDATE_TABLES_NAMES ()
{
   if (registry_get ('__weblog2_tables_is_upgrated') = 'OK')
     return;

    BLOG.DBA.blog2_exec_no_error ('drop table DB.DBA.SYS_BLOGS_B_CONTENT_WORDS');

    BLOG.DBA.blog2_exec_no_error ('drop trigger DB_DBA_SYS_BLOG_ATTACHES_FK_CHECK_INSERT');
    BLOG.DBA.blog2_exec_no_error ('drop trigger DBA.SYS_SYS_BLOGS_IN_SYS_BLOG_ATTACHES');
    BLOG.DBA.blog2_exec_no_error ('drop trigger DBA.DB_DBA_SYS_BLOG_ATTACHES_FK_CHECK_INSERT');
    BLOG.DBA.blog2_exec_no_error ('drop trigger DBA.DB_DBA_SYS_BLOG_ATTACHES_FK_CHECK_UPDATE');
    BLOG.DBA.blog2_exec_no_error ('drop trigger DBA.DB_DBA_SYS_BLOG_INFO_PK_CHECK_DELETE');
    BLOG.DBA.blog2_exec_no_error ('drop trigger DBA.DB_DBA_SYS_BLOG_INFO_PK_CHECK_UPDATE');
    BLOG.DBA.blog2_exec_no_error ('drop trigger DBA.SYS_BLOG2_INFO_D');
    BLOG.DBA.blog2_exec_no_error ('drop trigger DBA.DB_DBA_SYS_BLOGS_VTD_log');
    BLOG.DBA.blog2_exec_no_error ('drop trigger DBA.SYS_BLOGS_FTT_D');
    BLOG.DBA.blog2_exec_no_error ('drop trigger DBA.SYS_SYS_BLOGS_RM_SYS_BLOG_ATTACHES');
    BLOG.DBA.blog2_exec_no_error ('drop trigger DBA.DB_DBA_SYS_BLOG_CHANNEL_FEEDS_FK_CHECK_INSERT');
    BLOG.DBA.blog2_exec_no_error ('drop trigger DBA.DB_DBA_SYS_BLOG_CHANNEL_FEEDS_FK_CHECK_UPDATE');
    BLOG.DBA.blog2_exec_no_error ('drop trigger DBA.DB_DBA_SYS_BLOG_CHANNEL_INFO_FK_DELETE');
    BLOG.DBA.blog2_exec_no_error ('drop trigger DBA.DB_DBA_SYS_BLOG_CHANNEL_INFO_PK_CHECK_UPDATE');
    BLOG.DBA.blog2_exec_no_error ('drop trigger DBA.DB_DBA_SYS_BLOG_SEARCH_ENGINE_FK_DELETE');
    BLOG.DBA.blog2_exec_no_error ('drop trigger DBA.DB_DBA_SYS_BLOG_SEARCH_ENGINE_FK_UPDATE');
    BLOG.DBA.blog2_exec_no_error ('drop trigger DBA.DB_DBA_SYS_BLOG_SEARCH_ENGINE_SETTINGS_FK_CHECK_INSERT');
    BLOG.DBA.blog2_exec_no_error ('drop trigger DBA.DB_DBA_SYS_BLOG_SEARCH_ENGINE_SETTINGS_FK_CHECK_UPDATE');
    BLOG.DBA.blog2_exec_no_error ('drop trigger DB_DBA_SYS_BLOG_WEBLOG_HOSTS_FK_DELETE');
    BLOG.DBA.blog2_exec_no_error ('drop trigger DBA.DB_DBA_SYS_BLOG_WEBLOG_HOSTS_FK_UPDATE');
    BLOG.DBA.blog2_exec_no_error ('drop trigger DBA.DB_DBA_SYS_BLOG_WEBLOG_PING_FK_CHECK_INSERT');
    BLOG.DBA.blog2_exec_no_error ('drop trigger DBA.DB_DBA_SYS_BLOG_WEBLOG_PING_FK_CHECK_UPDATE');
    BLOG.DBA.blog2_exec_no_error ('drop trigger DBA.DB_DBA_SYS_BLOGS_VTI_log');
    BLOG.DBA.blog2_exec_no_error ('drop trigger DBA.DB_DBA_SYS_BLOGS_VTUB_log');
    BLOG.DBA.blog2_exec_no_error ('drop trigger DBA.DB_DBA_SYS_BLOGS_VTU_log');
    BLOG.DBA.blog2_exec_no_error ('drop trigger DBA.SYS_SYS_BLOGS_UP_SYS_BLOG_ATTACHES');
    BLOG.DBA.blog2_exec_no_error ('drop trigger DBA.SYS_BLOGS_D1');
    BLOG.DBA.blog2_exec_no_error ('drop trigger DBA.SYS_BLOGS_I1');
    BLOG.DBA.blog2_exec_no_error ('drop trigger DBA.SYS_BLOGS_U1');

    BLOG.DBA.blog2_exec_no_error ('alter table DB.DBA.SYS_BLOGS rename BLOG.DBA.SYS_BLOGS');
    BLOG.DBA.blog2_exec_no_error ('alter table DB.DBA.SYS_BLOG_INFO rename BLOG.DBA.SYS_BLOG_INFO');
    BLOG.DBA.blog2_exec_no_error ('alter table DB.DBA.SYS_BLOG_REFFERALS rename BLOG.DBA.SYS_BLOG_REFFERALS');
    BLOG.DBA.blog2_exec_no_error ('alter table DB.DBA.SYS_BLOG_DOMAINS rename BLOG.DBA.SYS_BLOG_DOMAINS');
    BLOG.DBA.blog2_exec_no_error ('alter table DB.DBA.SYS_BLOG_VISITORS rename BLOG.DBA.SYS_BLOG_VISITORS');
    BLOG.DBA.blog2_exec_no_error ('alter table DB.DBA.SYS_BLOG_CLOUD_NOTIFICATION rename BLOG.DBA.SYS_BLOG_CLOUD_NOTIFICATION');
    BLOG.DBA.blog2_exec_no_error ('alter table DB.DBA.SYS_BLOG_CHANNELS rename BLOG.DBA.SYS_BLOG_CHANNELS');
    BLOG.DBA.blog2_exec_no_error ('alter table DB.DBA.SYS_BLOG_CHANNEL_CATEGORY rename BLOG.DBA.SYS_BLOG_CHANNEL_CATEGORY');
    BLOG.DBA.blog2_exec_no_error ('alter table DB.DBA.SYS_BLOG_CHANNEL_INFO rename BLOG.DBA.SYS_BLOG_CHANNEL_INFO');
    BLOG.DBA.blog2_exec_no_error ('alter table DB.DBA.SYS_BLOG_CHANNEL_FEEDS rename BLOG.DBA.SYS_BLOG_CHANNEL_FEEDS');
    BLOG.DBA.blog2_exec_no_error ('alter table DB.DBA.BLOG_COMMENTS rename BLOG.DBA.BLOG_COMMENTS');
    BLOG.DBA.blog2_exec_no_error ('alter table DB.DBA.MTYPE_CATEGORIES rename BLOG.DBA.MTYPE_CATEGORIES');
    BLOG.DBA.blog2_exec_no_error ('alter table DB.DBA.MTYPE_BLOG_CATEGORY rename BLOG.DBA.MTYPE_BLOG_CATEGORY');
    BLOG.DBA.blog2_exec_no_error ('alter table DB.DBA.MTYPE_TRACKBACK_PINGS rename BLOG.DBA.MTYPE_TRACKBACK_PINGS');
    BLOG.DBA.blog2_exec_no_error ('alter table DB.DBA.SYS_ROUTING rename BLOG.DBA.SYS_ROUTING');
    BLOG.DBA.blog2_exec_no_error ('alter table DB.DBA.SYS_BLOGS_ROUTING_LOG rename BLOG.DBA.SYS_BLOGS_ROUTING_LOG');
    BLOG.DBA.blog2_exec_no_error ('alter table DB.DBA.SYS_ROUTING_TYPE rename BLOG.DBA.SYS_ROUTING_TYPE');
    BLOG.DBA.blog2_exec_no_error ('alter table DB.DBA.SYS_ROUTING_PROTOCOL rename BLOG.DBA.SYS_ROUTING_PROTOCOL');
    BLOG.DBA.blog2_exec_no_error ('alter table DB.DBA.SYS_WEBLOG_UPDATES_PINGS rename BLOG.DBA.SYS_WEBLOG_UPDATES_PINGS');
    BLOG.DBA.blog2_exec_no_error ('alter table DB.DBA.SYS_BLOG_CONTACTS rename BLOG.DBA.SYS_BLOG_CONTACTS');
    BLOG.DBA.blog2_exec_no_error ('alter table DB.DBA.SYS_BLOG_WEBLOG_HOSTS rename BLOG.DBA.SYS_BLOG_WEBLOG_HOSTS');
    BLOG.DBA.blog2_exec_no_error ('alter table DB.DBA.SYS_BLOG_WEBLOG_PING rename BLOG.DBA.SYS_BLOG_WEBLOG_PING');
    BLOG.DBA.blog2_exec_no_error ('alter table DB.DBA.SYS_BLOG_SEARCH_ENGINE rename BLOG.DBA.SYS_BLOG_SEARCH_ENGINE');
    BLOG.DBA.blog2_exec_no_error ('alter table DB.DBA.SYS_BLOG_SEARCH_ENGINE_SETTINGS rename BLOG.DBA.SYS_BLOG_SEARCH_ENGINE_SETTINGS');

    BLOG.DBA.blog2_exec_no_error ('alter table SYS_BLOG_ATTACHES rename BLOG.DBA.SYS_BLOG_ATTACHES');
    BLOG.DBA.blog2_exec_no_error ('update BLOG.DBA.SYS_BLOGS set B_STATE=2');

    delete from "DB"."DBA"."SYS_SCHEDULED_EVENT" where SE_NAME = 'Weblog Ping notifications';
    delete from "DB"."DBA"."SYS_SCHEDULED_EVENT" where SE_NAME = 'Weblog News aggregator';
    delete from "DB"."DBA"."SYS_SCHEDULED_EVENT" where SE_NAME = 'Routing Jobs Queue';

    DB.DBA.vhost_remove (lpath=>'/RPC2');
    BLOG.DBA.blog2_exec_no_error ('drop user MT');

    BLOG.DBA.blog2_exec_no_error ('drop procedure BLOG.DBA.BLOG_SEND_PINGS');
    BLOG.DBA.blog2_exec_no_error ('drop procedure BLOG.DBA.BLOG_FEED_AGREGATOR');
    BLOG.DBA.blog2_exec_no_error ('drop procedure BLOG.DBA.ROUTING_PROCESS_JOBS');
    BLOG.DBA.blog2_exec_no_error (
  'update BLOG.DBA.SYS_BLOG_INFO set BI_HAVE_COMUNITY_BLOG = 1 where BI_BLOG_ID = ''dav-blog-1''');
    registry_set ('__weblog2_tables_is_upgrated', 'OK');
    commit work;
}
;

BLOG2_UPDATE_TABLES_NAMES ()
;

USE "BLOG"
;


create procedure blog2_add_col(in tbl varchar, in col varchar, in coltype varchar) {

 if(not exists(select 1 from DB.DBA.SYS_KEYS where KEY_TABLE = tbl))
   return;
 if(exists(
           select
             top 1 1
           from
             DB.DBA.SYS_COLS
           where
             upper("TABLE") = upper(tbl) and
             upper("COLUMN") = upper(col)
          )
    ) return;
  exec (sprintf ('alter table %s add column %s %s', tbl, col, coltype));
}
;

create procedure blog2_modify_pk_safe (in tablename varchar, in pks any, in id_col varchar)
{
  declare pks1 any;
  pks1 := vector ();
  for SELECT c."COLUMN" as COL
	from  DB.DBA.SYS_KEYS k, DB.DBA.SYS_KEY_PARTS kp, DB.DBA."SYS_COLS" c
	where
	name_part (k.KEY_TABLE, 0) =  name_part (tablename, 0) and
	name_part (k.KEY_TABLE, 1) =  name_part (tablename, 1) and
	name_part (k.KEY_TABLE, 2) =  name_part (tablename, 2)
	and __any_grants (k.KEY_TABLE)
	and c."COLUMN" <> '_IDN'
	and k.KEY_IS_MAIN = 1
	and k.KEY_MIGRATE_TO is null
	and kp.KP_KEY_ID = k.KEY_ID
        and kp.KP_NTH < k.KEY_DECL_PARTS
	and c.COL_ID = kp.KP_COL
	order by kp.KP_NTH do
	{
	  pks1 := vector_concat (pks1, vector (COL));
	}
  declare i, l int;
  i := 0; l := length (pks);
  if (length (pks1) = length (pks))
    {
      for (i := 0; i < l; i := i + 1)
	{
	  if (casemode_strcmp (pks[i], pks1[i]) <> 0)
	    goto alterst;
	}
      --dbg_obj_print ('already done.');
      return;
    }
 alterst:
    declare altersql any;
    altersql := sprintf ('alter table "%I"."%I"."%I" modify primary key (', name_part (tablename, 0), name_part (tablename, 1), name_part (tablename, 2));
    for (i := 0; i < l; i := i + 1)
       {
         altersql := altersql || pks[i] || ',';
       }
    altersql := rtrim (altersql, ',');
    altersql := altersql || ')';
    --dbg_obj_print ('DOING PK MODIFY!', altersql);
    if (id_col is not null)
      {
        --dbg_obj_print ('ID column unset');
        update DB.DBA.SYS_COLS set COL_CHECK = '' where \COLUMN = id_col and \TABLE = tablename;
	__ddl_changed (tablename);
      }
    --dbg_obj_print ('PK change');
    exec (altersql);
    if (id_col is not null)
      {
        --dbg_obj_print ('ID column set');
        update DB.DBA.SYS_COLS set COL_CHECK = 'I' where \COLUMN = id_col and \TABLE = tablename;
	__ddl_changed (tablename);
      }
   --dbg_obj_print ('done.');
}
;

blog2_exec_no_error ('create type "blogPost" as (
        content varchar,
        dateCreated datetime,
        "postid" varchar,
        userid any
      ) self as ref')
;

blog2_exec_no_error ('create type "blogRequest" under "blogPost"
      as
      (
        user_name varchar,
        passwd varchar,
        appkey varchar,
        blogid varchar default null,
        postId varchar default null,
        auth_userid integer,
        blog_lhome varchar,
        blog_phome varchar,
        blog_owner int,
        publish smallint,
        struct BLOG.DBA."MWeblogPost",
        header varchar default null
      ) self as ref
constructor method "blogRequest" (appkey varchar, blogid varchar, postId varchar, user_name varchar, passwd varchar)')
;

create constructor method
"blogRequest" (in appkey varchar, in blogid varchar, in postId varchar, in user_name varchar, in passwd varchar)
for "blogRequest"
{
  self.appkey := appkey;
  self.blogid := blogid;
  self.postId := postId;
  self.user_name := user_name;
  self.passwd := passwd;
}
;

grant execute on "blogPost" to public
;

grant execute on "blogRequest" to public
;

--
-- WEBLOG META API STRUCT
--

DB.DBA.SOAP_DT_DEFINE ('MWeblogPost:ArrayOfstring',
'<complexType name="ArrayOfstring" targetNamespace="MWeblogPost"
   xmlns:enc="http://schemas.xmlsoap.org/soap/encoding/"
   xmlns:wsdl="http://schemas.xmlsoap.org/wsdl/"
   xmlns="http://www.w3.org/2001/XMLSchema"
   xmlns:tns="http://soapinterop.org/xsd">
  <complexContent>
     <restriction base="enc:Array">
        <sequence>
           <element name="item" type="string" minOccurs="0" maxOccurs="unbounded" nillable="true"/>
        </sequence>
        <attributeGroup ref="enc:commonAttributes"/>
        <attribute ref="enc:arrayType" wsdl:arrayType="string[]"/>
     </restriction>
  </complexContent>
</complexType>')
;


blog2_exec_no_error ('create type
BLOG.DBA."MWeblogEnclosure" as
    (
      "length"  int,
      "type"    varchar,
       url    varchar
    )')
;

blog2_exec_no_error ('create type
BLOG.DBA."MWeblogSource" as
    (
      name varchar,
      url  varchar
    )')
;

-- Represents also the "item" element of RSS2
blog2_check_and_create ('DB.DBA.MWeblogPost', 'BLOG.DBA."MWeblogPost"',
'create type BLOG.DBA."MWeblogPost" as
    (
      categories any __soap_type ''MWeblogPost:ArrayOfstring'',
      dateCreated datetime,
      description varchar,
      enclosure BLOG.DBA."MWeblogEnclosure",
      permaLink varchar,
      postid any,
      source MWeblogSource,
      title varchar,
      userid any,
      link varchar,
      author varchar,
      comments varchar,
      guid varchar
    )')
;


blog2_exec_no_error ( --'DB.DBA.MTWeblogPost', 'BLOG.DBA."MTWeblogPost"',
'create type BLOG.DBA."MTWeblogPost" under BLOG.DBA."MWeblogPost" as
    (
    mt_allow_comments int,
    mt_allow_pings int,
    mt_convert_breaks varchar,
    mt_excerpt varchar,
    mt_tb_ping_urls any __soap_type ''MWeblogPost:ArrayOfstring'',
    mt_text_more varchar,
    mt_keywords varchar
    )')
;

grant execute on BLOG.DBA."MTWeblogPost" to public
;

grant execute on BLOG.DBA."MWeblogPost" to public
;

grant execute on BLOG.DBA."MWeblogSource" to public
;

grant execute on BLOG.DBA."MWeblogEnclosure" to public
;

-- TABLE SCHEMA

blog2_exec_no_error ('create table SYS_BLOGS (
      B_APPKEY varchar,
      B_BLOG_ID varchar,
      B_CONTENT long varchar,
      B_TITLE long varchar,
      B_POST_ID varchar,
      B_TS datetime,
      B_USER_ID integer,
      B_META BLOG.DBA."MWeblogPost",
      B_CONTENT_ID integer identity,
      B_COMMENTS_NO integer default 0,
      B_TRACKBACK_NO integer default 0,
      B_REF varchar default null,
      B_MODIFIED timestamp,
      B_STATE integer,
      B_IS_ACTIVE integer default 0,
      B_HAVE_ENCLOSURE integer default 0,
      B_ENCLOSURE_TYPE varchar default null,
      B_RFC_ID	varchar default null,
      B_RFC_HEADER long varchar,
      B_VER int default 1,
      primary key (B_BLOG_ID, B_TS, B_POST_ID)
)');

blog2_add_col('BLOG.DBA.SYS_BLOGS', 'B_STATE', 'integer');
blog2_add_col('BLOG.DBA.SYS_BLOGS', 'B_TITLE', 'varchar');
blog2_add_col('BLOG.DBA.SYS_BLOGS', 'B_IS_ACTIVE', 'integer default 0');
blog2_add_col('BLOG.DBA.SYS_BLOGS', 'B_HAVE_ENCLOSURE', 'integer default 0');
blog2_add_col('BLOG.DBA.SYS_BLOGS', 'B_ENCLOSURE_TYPE', 'varchar default null');
blog2_add_col('BLOG.DBA.SYS_BLOGS', 'B_RFC_ID', 'varchar');
blog2_add_col('BLOG.DBA.SYS_BLOGS', 'B_RFC_HEADER', 'long varchar');
blog2_add_col('BLOG.DBA.SYS_BLOGS', 'B_VER', 'int default 1');



blog2_exec_no_error ('create index SYS_BLOGS_CONTENT_ID on SYS_BLOGS (B_CONTENT_ID)');

blog2_exec_no_error ('create unique index SYS_BLOGS_POST_ID on SYS_BLOGS (B_POST_ID)');

blog2_exec_no_error ('create unique index SYS_BLOGS_B_BLOG_ID_B_POST_ID on SYS_BLOGS (B_BLOG_ID, B_POST_ID)');

blog2_exec_no_error ('create index SYS_BLOGS_RFC_ID on SYS_BLOGS (B_RFC_ID)');

--blog2_exec_no_error ('create index SYS_BLOGS_HAVE_ENCLOSURE on BLOG.DBA.SYS_BLOGS (B_HAVE_ENCLOSURE)')
--;

blog2_exec_no_error ('create table BLOG_POST_LINKS (
      PL_BLOG_ID varchar,
      PL_POST_ID varchar,
      PL_LINK varchar,
      PL_TITLE varchar,
      PL_PING int default 0,
      foreign key (PL_BLOG_ID, PL_POST_ID) references SYS_BLOGS (B_BLOG_ID, B_POST_ID) on delete cascade,
      primary key (PL_BLOG_ID, PL_POST_ID, PL_LINK)
      )');

blog2_add_col('BLOG.DBA.BLOG_POST_LINKS', 'PL_PING', 'int default 0');

blog2_exec_no_error ('create table BLOG_COMMENT_LINKS (
      CL_BLOG_ID varchar,
      CL_POST_ID varchar,
      CL_CID	int,
      CL_LINK varchar,
      CL_TITLE varchar,
      CL_PING int default 0,
      foreign key (CL_BLOG_ID, CL_POST_ID) references SYS_BLOGS (B_BLOG_ID, B_POST_ID) on delete cascade,
      primary key (CL_BLOG_ID, CL_POST_ID, CL_CID, CL_LINK)
      )');

blog2_exec_no_error ('create table BLOG_POST_ENCLOSURES (
      PE_BLOG_ID varchar,
      PE_POST_ID varchar,
      PE_URL varchar,
      PE_TYPE varchar,
      PE_LEN  int,
      foreign key (PE_BLOG_ID, PE_POST_ID) references SYS_BLOGS (B_BLOG_ID, B_POST_ID) on delete cascade,
      primary key (PE_BLOG_ID, PE_POST_ID, PE_URL)
      )');

blog2_exec_no_error ('create table SYS_BLOG_INFO
      (
      BI_BLOG_ID  varchar,
      BI_OWNER    integer,
      BI_HOME     varchar,
      BI_P_HOME     varchar,
      BI_DEFAULT_PAGE varchar,
      BI_TITLE    varchar,
      BI_COPYRIGHTS   varchar,
      BI_DISCLAIMER   varchar,
      BI_WRITERS    any,
      BI_READERS    any,
      BI_PINGS  any,
      BI_ABOUT    varchar,
      BI_E_MAIL     varchar,
      BI_TZ     int default null,
      BI_SHOW_CONTACT int default 1,
      BI_SHOW_REGIST  int default 1,
      BI_COMMENTS   int default 1,
      BI_QUOTA    int default null,
      BI_HOME_PAGE    varchar default '''',
      BI_FILTER   varchar default ''*default*'',
      BI_PHOTO    varchar,
      BI_KEYWORDS   varchar,
      BI_COMMENTS_NOTIFY int default 0,
      BI_ADD_YOUR_BLOG   int default 0,
      BI_RSS_VERSION     varchar default ''2.0'',
      BI_OPTIONS  long varbinary,
      BI_WAI_MEMBER_MODEL int,
      BI_TB_NOTIFY int default 0,
      BI_LAST_UPDATE datetime,
      BI_BLOG_SEQ integer identity,
      BI_DASHBOARD long varchar,
      BI_SHOW_AS_NEWS int default 0,
      BI_ICON varchar,
      BI_TEMPLATE varchar,
      BI_AUDIO varchar,
      BI_CSS varchar,
      BI_INCLUSION integer,
      BI_DEL_USER varchar,
      BI_DEL_PASS varchar,
      BI_WAI_NAME varchar,
      BI_HAVE_COMUNITY_BLOG int,
      BI_AUTO_TAGGING int default 1,
      primary key (BI_BLOG_ID)
)')
;


blog2_add_col('BLOG.DBA.SYS_BLOG_INFO', 'BI_WAI_MEMBER_MODEL', 'int');
blog2_add_col('BLOG.DBA.SYS_BLOG_INFO', 'BI_ICON', 'varchar');
blog2_add_col('BLOG.DBA.SYS_BLOG_INFO', 'BI_BLOG_SEQ', 'integer identity');
blog2_add_col('BLOG.DBA.SYS_BLOG_INFO', 'BI_DASHBOARD', 'long varchar');
blog2_add_col('BLOG.DBA.SYS_BLOG_INFO', 'BI_SHOW_AS_NEWS', 'int default 0');
blog2_add_col('BLOG.DBA.SYS_BLOG_INFO', 'BI_TEMPLATE', 'varchar');
blog2_add_col('BLOG.DBA.SYS_BLOG_INFO', 'BI_AUDIO', 'varchar');
blog2_add_col('BLOG.DBA.SYS_BLOG_INFO', 'BI_CSS', 'varchar');
blog2_add_col('BLOG.DBA.SYS_BLOG_INFO', 'BI_INCLUSION', 'integer');
blog2_add_col('BLOG.DBA.SYS_BLOG_INFO', 'BI_DEL_USER', 'varchar');
blog2_add_col('BLOG.DBA.SYS_BLOG_INFO', 'BI_DEL_PASS', 'varchar');
blog2_add_col('BLOG.DBA.SYS_BLOG_INFO', 'BI_WAI_NAME', 'varchar');
blog2_add_col('BLOG.DBA.SYS_BLOG_INFO', 'BI_HAVE_COMUNITY_BLOG', 'int');
blog2_add_col('BLOG.DBA.SYS_BLOG_INFO', 'BI_TB_NOTIFY', 'int');
blog2_add_col('BLOG.DBA.SYS_BLOG_INFO', 'BI_LAST_UPDATE', 'datetime');
blog2_add_col('BLOG.DBA.SYS_BLOG_INFO', 'BI_AUTO_TAGGING', 'int default 1');

blog2_exec_no_error ('create unique index SYS_BLOG_INFO_WAI on BLOG.DBA.SYS_BLOG_INFO (BI_WAI_NAME)');



blog2_exec_no_error ('create table SYS_BLOG_REFFERALS
      (
      BR_URI varchar,
      BR_TITLE varchar,
      BR_BLOG_ID varchar,
      BR_POST_ID varchar,
      primary key (BR_BLOG_ID, BR_POST_ID, BR_URI)
)')
;

blog2_exec_no_error ('create table SYS_BLOG_VISITORS
      (
      BV_ID varchar,
      BV_BLOG_ID varchar,
      BV_NAME varchar,
      BV_E_MAIL varchar,
      BV_IP varchar,
      BV_HOME varchar,
      BV_NOTIFY int default 0,
      BV_POST_ID varchar default '''',
      BV_VIA_DOMAIN varchar default null,
      primary key (BV_E_MAIL, BV_BLOG_ID, BV_POST_ID)
      )');

blog2_exec_no_error ('create index SYS_BLOG_VISITORS_E_MAIL on SYS_BLOG_VISITORS (BV_E_MAIL)');
blog2_exec_no_error ('create unique index SYS_BLOG_VISITORS_ID on SYS_BLOG_VISITORS (BV_ID)');

blog2_add_col('BLOG.DBA.SYS_BLOG_VISITORS', 'BV_VIA_DOMAIN', 'varchar')
;


blog2_exec_no_error ('create table SYS_BLOG_CLOUD_NOTIFICATION
      (
      BCN_URL varchar,
      BCN_BLOG_ID varchar,
      BCN_TS datetime,
      BCN_PROTO varchar,
      BCN_METHOD varchar,
      BCN_USER_DATA any,
      primary key (BCN_BLOG_ID, BCN_URL)
      )')
;

blog2_exec_no_error ('create table SYS_BLOG_CHANNELS (
  BC_BLOG_ID varchar,
  BC_CHANNEL_URI varchar,
  BC_AGGREGATE int,
  BC_LOCAL_RES varchar,
  BC_CATEGORY varchar,
  BC_CAT_ID int,
  BC_SHARED int,
  BC_REL varchar,
  primary key (BC_BLOG_ID, BC_CHANNEL_URI)
)')
;

blog2_add_col('BLOG.DBA.SYS_BLOG_CHANNELS', 'BC_SHARED', 'int')
;

blog2_add_col('BLOG.DBA.SYS_BLOG_CHANNELS', 'BC_REL', 'varchar')
;

blog2_exec_no_error ('create index SYS_BLOG_CHANNELS_I1 on SYS_BLOG_CHANNELS (BC_BLOG_ID, BC_CAT_ID)');


blog2_exec_no_error ('create table SYS_BLOG_CHANNEL_CATEGORY (
  BCC_ID integer identity,
  BCC_BLOG_ID varchar,
  BCC_NAME varchar,
  BCC_IS_BLOG int default 0,
  primary key (BCC_BLOG_ID, BCC_NAME)
)');
;

blog2_exec_no_error ('create table SYS_BLOG_CHANNEL_INFO
  (
    BCD_CHANNEL_URI varchar,
    BCD_HOME_URI varchar,
    BCD_TITLE varchar,
    BCD_FORMAT varchar,
    BCD_UPDATE_PERIOD varchar default ''hourly'',
    BCD_LANG varchar default ''us-en'',
    BCD_UPDATE_FREQ int default 1,
    BCD_LAST_UPDATE datetime,
    BCD_UPDATE integer,
    BCD_TAG varchar,
    BCD_ERROR_LOG long varchar default null,
    BCD_SOURCE_URI varchar default null,
    BCD_IS_BLOG integer default 1,
    BCD_AUTHOR_NAME varchar,
    BCD_AUTHOR_EMAIL varchar,
    primary key (BCD_CHANNEL_URI)
  )')
;


--blog2_add_col('BLOG.DBA.SYS_BLOG_CHANNEL_INFO', 'BCD_XFN_KEYWORDS', 'varchar')
--;

blog2_add_col('BLOG.DBA.SYS_BLOG_CHANNEL_INFO', 'BCD_AUTHOR_NAME', 'varchar')
;

blog2_add_col('BLOG.DBA.SYS_BLOG_CHANNEL_INFO', 'BCD_AUTHOR_EMAIL', 'varchar')
;

create trigger SYS_BLOG_CHANNEL_INFO_UPDATE after insert on SYS_BLOG_CHANNEL_INFO referencing new as N
{
  declare period, freq, uri any;
  declare upd int;
  uri := N.BCD_CHANNEL_URI;
  period := lower (coalesce (N.BCD_UPDATE_PERIOD, 'daily'));
  freq := coalesce (N.BCD_UPDATE_FREQ, 1);
  -- Hourly, Daily, Weekly, Monthly, Yearly
  upd := case period
  when 'hourly' then 60
  when 'daily' then 1440
  when 'weekly' then 10080
  when 'monthly' then 43200
  when 'yearly' then 525600
  else 1440 end;
  upd := upd / freq;
  set triggers off;
  update SYS_BLOG_CHANNEL_INFO set BCD_UPDATE = upd, BCD_UPDATE_FREQ = freq where BCD_CHANNEL_URI = uri;
  set triggers on;
}
;

blog2_exec_no_error ('create table SYS_BLOG_CHANNEL_FEEDS
  (
  CF_ID int,
  CF_CHANNEL_URI varchar references SYS_BLOG_CHANNEL_INFO (BCD_CHANNEL_URI) on delete cascade,
  CF_TITLE varchar,
  CF_DESCRIPTION long varchar,
  CF_LINK varchar,
  CF_GUID varchar,
  CF_PUBDATE datetime,
  CF_COMMENT_API varchar,
  CF_COMMENT_RSS varchar,
  CF_READ int,
  primary key (CF_CHANNEL_URI, CF_ID)
  )')
;

blog2_add_col('BLOG.DBA.SYS_BLOG_CHANNEL_FEEDS', 'CF_READ', 'int')
;

blog2_exec_no_error ('create view BLOG_CHANNELS (BC_BLOG_ID, BC_TITLE, BC_HOME_URI, BC_RSS_URI,
         BC_FORM, BC_UPD, BC_LANG, BC_FREQ, BC_SOURCE)
  as select BC_BLOG_ID, BCD_TITLE, BCD_HOME_URI, BCD_CHANNEL_URI,
      BCD_FORMAT, BCD_UPDATE_PERIOD, BCD_LANG , BCD_UPDATE_FREQ, BCD_SOURCE_URI
  from SYS_BLOG_CHANNELS, SYS_BLOG_CHANNEL_INFO where BC_CHANNEL_URI = BCD_CHANNEL_URI')
;

blog2_exec_no_error ('create table BLOG_COMMENTS
  (
  BM_BLOG_ID varchar,
  BM_POST_ID varchar,
  BM_ID      integer identity,
  BM_COMMENT long varchar,
  BM_NAME    varchar,
  BM_E_MAIL  varchar,
  BM_HOME_PAGE varchar,
  BM_ADDRESS  varchar,
  BM_TS      datetime,
  BM_IS_SPAM int,
  BM_IS_PUB  int,
  BM_POSTED_VIA varchar,
  BM_TITLE  varchar,
  BM_RFC_ID varchar,
  BM_RFC_HEADER long varchar,
  BM_REF_ID int default null,
  BM_RFC_REFERENCES varchar default null,
  BM_OPENID_SIG long varbinary default null,
  BM_OWN_COMMENT int default 0,
  primary key (BM_BLOG_ID, BM_POST_ID, BM_ID)
  )')
;

blog2_exec_no_error ('create index BLOG_COMMENTS_FK on BLOG_COMMENTS (BM_BLOG_ID, BM_POST_ID)')
;

blog2_exec_no_error ('create index BLOG_COMMENTS_POST on BLOG_COMMENTS (BM_POST_ID)')
;

blog2_exec_no_error ('create index BLOG_COMMENTS_POST_TS on BLOG_COMMENTS (BM_TS)');

blog2_add_col('BLOG.DBA.BLOG_COMMENTS', 'BM_IS_SPAM', 'int')
;

blog2_add_col('BLOG.DBA.BLOG_COMMENTS', 'BM_IS_PUB', 'int')
;

blog2_add_col('BLOG.DBA.BLOG_COMMENTS', 'BM_POSTED_VIA', 'varchar')
;

blog2_add_col('BLOG.DBA.BLOG_COMMENTS', 'BM_RFC_ID', 'varchar')
;

blog2_add_col('BLOG.DBA.BLOG_COMMENTS', 'BM_RFC_HEADER', 'long varchar')
;

blog2_add_col('BLOG.DBA.BLOG_COMMENTS', 'BM_TITLE', 'varchar')
;

blog2_add_col('BLOG.DBA.BLOG_COMMENTS', 'BM_REF_ID', 'int default null')
;

blog2_add_col('BLOG.DBA.BLOG_COMMENTS', 'BM_RFC_REFERENCES', 'varchar default null')
;

blog2_add_col('BLOG.DBA.BLOG_COMMENTS', 'BM_OPENID_SIG', 'long varbinary default null')
;

blog2_add_col('BLOG.DBA.BLOG_COMMENTS', 'BM_OWN_COMMENT', 'int default 0')
;

blog2_exec_no_error ('create index BLOG_COMMENTS_PUB on BLOG_COMMENTS (BM_BLOG_ID, BM_POST_ID, BM_IS_PUB)')
;


blog2_exec_no_error ('create table MTYPE_CATEGORIES (
  MTC_ID varchar,
  MTC_BLOG_ID varchar,
  MTC_NAME varchar,
  MTC_ROUTING int default 0,
  MTC_DEFAULT int default 0,
  MTC_KEYWORDS long varchar,
  MTC_SHARED  int,
  primary key (MTC_BLOG_ID, MTC_ID))')
;

blog2_add_col('BLOG.DBA.MTYPE_CATEGORIES', 'MTC_SHARED', 'int')
;

blog2_exec_no_error ('create table MTYPE_BLOG_CATEGORY (
  MTB_CID varchar,
  MTB_POST_ID varchar,
  MTB_BLOG_ID varchar,
  MTB_PRIMARY int,
  MTB_IS_AUTO int default 0,
  primary key (MTB_CID, MTB_POST_ID, MTB_BLOG_ID))')
;

blog2_exec_no_error ('create table MTYPE_TRACKBACK_PINGS
  (
  MP_POST_ID varchar not null,
  MP_URL varchar not null,
  MP_TITLE varchar,
  MP_EXCERPT varchar,
  MP_BLOG_NAME varchar,
  MP_IP varchar,
  MP_TS timestamp,
  MP_ID int identity,
  MP_IS_SPAM int,
  MP_IS_PUB  int,
  MP_VIA_DOMAIN varchar
  )')
;

blog2_add_col('BLOG.DBA.MTYPE_TRACKBACK_PINGS', 'MP_ID', 'int identity')
;

blog2_add_col('BLOG.DBA.MTYPE_TRACKBACK_PINGS', 'MP_IS_SPAM', 'int')
;

blog2_add_col('BLOG.DBA.MTYPE_TRACKBACK_PINGS', 'MP_IS_PUB', 'int')
;

blog2_add_col('BLOG.DBA.MTYPE_TRACKBACK_PINGS', 'MP_VIA_DOMAIN', 'varchar')
;

--   Routing Table Structure:
blog2_exec_no_error ('create table SYS_ROUTING
(
   R_JOB_ID  int primary key,
   R_U_ID  int,
   R_TYPE_ID   int,
   R_PROTOCOL_ID int,
   R_DESTINATION varchar,
   R_DESTINATION_ID any,
   R_AUTH_USER   varchar,
   R_AUTH_PWD    varchar,
   R_ITEM_ID     varchar,
   R_FREQUENCY   integer default 60,
   R_LAST_ROUND  datetime,
   R_EXCEPTION_TAG varchar,
   R_EXCEPTION_ID varchar,
   R_INCLUSION_ID varchar,
   R_KEEP_REMOTE int default 0,
   R_MAX_ERRORS int default -1,
   R_ITEM_MAX_RETRANSMITS int default 1
)')
;

blog2_add_col('BLOG.DBA.SYS_ROUTING', 'R_KEEP_REMOTE', 'int default 0')
;
blog2_add_col('BLOG.DBA.SYS_ROUTING', 'R_MAX_ERRORS', 'int default -1')
;
blog2_add_col('BLOG.DBA.SYS_ROUTING', 'R_ITEM_MAX_RETRANSMITS', 'int default 1')
;

update SYS_ROUTING set R_KEEP_REMOTE = 0 where R_KEEP_REMOTE is null
;
update SYS_ROUTING set R_MAX_ERRORS = -1, R_ITEM_MAX_RETRANSMITS = 1 where R_MAX_ERRORS is null
;

blog2_exec_no_error ('create index SYS_ROUTING_ITEM on SYS_ROUTING (R_ITEM_ID, R_DESTINATION_ID, R_TYPE_ID)');

blog2_exec_no_error ('create table SYS_BLOGS_ROUTING_LOG
(
  RL_JOB_ID int,
  RL_POST_ID varchar,
  RL_F_POST_ID varchar,
  RL_TYPE varchar,
  RL_PROCESSED int default 0,
  RL_COMMENT_ID integer default -1,
  RL_ERROR long varchar,
  RL_TS timestamp,
  RL_RETRANSMITS int default 1,
  primary key (RL_JOB_ID, RL_POST_ID, RL_COMMENT_ID)
)')
;

blog2_add_col('BLOG.DBA.SYS_BLOGS_ROUTING_LOG', 'RL_TS', 'timestamp')
;
blog2_add_col('BLOG.DBA.SYS_BLOGS_ROUTING_LOG', 'RL_RETRANSMITS', 'int default 1')
;

UPDATE SYS_BLOGS_ROUTING_LOG set RL_COMMENT_ID = -1 where RL_COMMENT_ID is NULL
;
UPDATE SYS_BLOGS_ROUTING_LOG set RL_RETRANSMITS = 1 where RL_RETRANSMITS is null and RL_PROCESSED <> 2
;
UPDATE SYS_BLOGS_ROUTING_LOG set RL_RETRANSMITS = 0 where RL_RETRANSMITS is null and RL_PROCESSED = 2
;


--   Routing Type Table Structure:
blog2_exec_no_error ('create table SYS_ROUTING_TYPE
(
   RT_ID int primary key,
   RT_NAME varchar,
   RT_TYPE_DESCRIPTION varchar
)')
;

insert soft SYS_ROUTING_TYPE (RT_ID, RT_NAME, RT_TYPE_DESCRIPTION) values (1, 'Upstream', 'Web Log Upstream')
;

insert soft SYS_ROUTING_TYPE (RT_ID, RT_NAME, RT_TYPE_DESCRIPTION) values (2, 'E-mail', 'E-mail notification')
;

insert soft SYS_ROUTING_TYPE (RT_ID, RT_NAME, RT_TYPE_DESCRIPTION) values (3, 'del.icio.us', 'del.icio.us notification')
;

insert soft SYS_ROUTING_TYPE (RT_ID, RT_NAME, RT_TYPE_DESCRIPTION) values (4, 'Ping', 'Weblog ping')
;

--   Routing Protocol Table Structure:
blog2_exec_no_error ('create table SYS_ROUTING_PROTOCOL
(
   RP_ID  int primary key,
   RP_NAME varchar,
   RP_INVOCATION_SIGNATURE varchar
)')
;

insert soft SYS_ROUTING_PROTOCOL (RP_ID, RP_NAME, RP_INVOCATION_SIGNATURE)
  values (1,'Blogger','')
;

insert soft SYS_ROUTING_PROTOCOL (RP_ID, RP_NAME, RP_INVOCATION_SIGNATURE)
  values (2,'MetaWeblog','')
;

insert soft SYS_ROUTING_PROTOCOL (RP_ID, RP_NAME, RP_INVOCATION_SIGNATURE)
  values (3,'MoveableType','')
;

insert soft SYS_ROUTING_PROTOCOL (RP_ID, RP_NAME, RP_INVOCATION_SIGNATURE)
  values (4,'SMTP','')
;

insert soft SYS_ROUTING_PROTOCOL (RP_ID, RP_NAME, RP_INVOCATION_SIGNATURE)
  values (5,'Atom','')
;

insert soft SYS_ROUTING_PROTOCOL (RP_ID, RP_NAME, RP_INVOCATION_SIGNATURE)
  values (6,'REST','')
;

insert soft SYS_ROUTING_PROTOCOL (RP_ID, RP_NAME, RP_INVOCATION_SIGNATURE)
  values (7,'XML-RPC','')
;

-- WEBLOG PING
blog2_exec_no_error ('create table SYS_WEBLOG_UPDATES_PINGS
  (
  WU_NAME varchar,
  WU_URL varchar,
  WU_TS  datetime,
  WU_IP  varchar,
  WU_CHANGES_URL varchar,
  WU_RSS varchar,
  primary key (WU_URL)
  )')
;

blog2_add_col('BLOG.DBA.SYS_WEBLOG_UPDATES_PINGS', 'WU_CHANGES_URL', 'varchar')
;

blog2_add_col('BLOG.DBA.SYS_WEBLOG_UPDATES_PINGS', 'WU_RSS', 'varchar')
;

blog2_exec_no_error ('create index SYS_WEBLOG_UPDATES_PINGS_TS on SYS_WEBLOG_UPDATES_PINGS (WU_TS)')
;



blog2_exec_no_error ('create table SYS_BLOG_CONTACTS
  (
   BF_ID integer identity,
   BF_BLOG_ID varchar,
   BF_NAME varchar,
   BF_FAMILY_NAME varchar,
   BF_PHONE varchar,
   BF_YAHOO_CHAT_ID varchar,
   BF_MSN_CHAT_ID varchar,
   BF_NICK varchar,
   BF_FIRST_NAME varchar,
   BF_TITLE varchar,
   BF_MBOX varchar,
   BF_WORKPLACE_HOMEPAGE varchar,
   BF_ICQ_CHAT_ID varchar,
   BF_SURNAME varchar,
   BF_HOMEPAGE varchar,
   BF_WEBLOG varchar,
   BF_RSS varchar,
   BF_WORKINFO_HOMEPAGE varchar,
   primary key (BF_BLOG_ID, BF_ID)
  )')
;

blog2_exec_no_error ('create table SYS_BLOG_WEBLOG_HOSTS
  (
  WH_URL varchar,
  WH_NAME varchar,
  WH_PROTO varchar,
  WH_ID integer identity,
  WH_METHOD varchar default \'weblogUpdates.ping\',
  primary key (WH_URL, WH_PROTO, WH_METHOD)
  )')
;

blog2_add_col('BLOG.DBA.SYS_BLOG_WEBLOG_HOSTS', 'WH_METHOD', 'varchar default \'weblogUpdates.ping\'');


blog2_exec_no_error ('create table SYS_BLOG_WEBLOG_PING
  (
  WP_URL varchar,
  WP_BLOG_ID varchar,
  WP_HOSTS_ID int references SYS_BLOG_WEBLOG_HOSTS (WH_ID) on update cascade on delete cascade,
  primary key (WP_BLOG_ID, WP_HOSTS_ID)
  )')
;

blog2_add_col('BLOG.DBA.SYS_BLOG_WEBLOG_PING', 'WP_HOSTS_ID', 'int');


blog2_exec_no_error ('
create table BLOG_WEBLOG_PING_LOG
  (
    WPL_JOB_ID int references SYS_ROUTING (R_JOB_ID) on delete cascade,
    WPL_HOSTS_ID int references SYS_BLOG_WEBLOG_HOSTS (WH_ID) on update cascade on delete cascade,
    WPL_STAT int default 0, -- 1 sent, 2 error, 0 pending
    WPL_TS timestamp,
    WPL_SENT datetime,
    WPL_ERROR long varchar,
    primary key (WPL_TS, WPL_JOB_ID, WPL_HOSTS_ID)
  )')
;

blog2_exec_no_error ('create index BLOG_WEBLOG_PING_LOG_STAT on BLOG_WEBLOG_PING_LOG (WPL_JOB_ID, WPL_HOSTS_ID, WPL_STAT)');


create procedure BLOG_WEBLOG_PING_UPGRADE ()
{
  declare jid int;
  declare last datetime;
  if (registry_get ('__BLOG_WEBLOG_PING_UPGRADE_done') = 'done2')
    return;
  last := registry_get ('blogger.last.ping');
  set triggers off;

  for select  WH_URL, WH_PROTO, WH_METHOD, WAI_ID, WAI_NAME
    from SYS_BLOG_WEBLOG_PING, SYS_BLOG_WEBLOG_HOSTS, SYS_BLOG_INFO, DB.DBA.WA_INSTANCE
    where WP_HOSTS_ID = WH_ID and WP_BLOG_ID = BI_BLOG_ID and WAI_NAME = BI_WAI_NAME do
	{
      declare s_id int;
      s_id := (select SH_ID from ODS..SVC_HOST where SH_URL = WH_URL and SH_PROTO = WH_PROTO and SH_METHOD = WH_METHOD);
      if (s_id is not null)
        insert soft ODS..APP_PING_REG (AP_HOST_ID, AP_WAI_ID) values (s_id, WAI_ID);
      else
	log_message (sprintf ('Can''t upgrade reference of %s to %s %s', WAI_NAME, WH_URL, WH_PROTO));
	}

  for select distinct BI_WAI_NAME from BLOG_WEBLOG_PING_LOG, SYS_BLOG_INFO, SYS_ROUTING, SYS_BLOG_WEBLOG_PING
    where WPL_STAT = 0 and WP_BLOG_ID = BI_BLOG_ID and WPL_JOB_ID = R_JOB_ID
	and WPL_HOSTS_ID = WP_HOSTS_ID and R_ITEM_ID = WP_BLOG_ID and R_TYPE_ID = 4
    do
      {
	ODS..APP_PING (BI_WAI_NAME);
    }

  delete from SYS_ROUTING where R_TYPE_ID = 4;
  delete from SYS_BLOG_WEBLOG_PING;
  delete from BLOG_WEBLOG_PING_LOG;

  blog2_exec_no_error ('drop trigger SYS_BLOG_WEBLOG_PING_I');
  blog2_exec_no_error ('drop trigger SYS_BLOG_WEBLOG_PING_D');

  set triggers on;
  registry_set ('__BLOG_WEBLOG_PING_UPGRADE_done', 'done2');
}
;

BLOG_WEBLOG_PING_UPGRADE ();

blog2_exec_no_error ('create unique index SYS_BLOG_WEBLOG_HOSTS_ID on SYS_BLOG_WEBLOG_HOSTS (WH_ID)');

insert soft SYS_BLOG_WEBLOG_HOSTS (WH_URL, WH_NAME, WH_PROTO) values ('', 'disabled', '');

insert soft SYS_BLOG_WEBLOG_HOSTS (WH_URL, WH_NAME, WH_PROTO) values ('http://rpc.weblogs.com/RPC2', 'Weblog.com', 'xml-rpc');

insert soft SYS_BLOG_WEBLOG_HOSTS (WH_URL, WH_NAME, WH_PROTO) values ('http://rpc.weblogs.com/weblogUpdates', 'Weblog.com', 'soap');

insert soft SYS_BLOG_WEBLOG_HOSTS (WH_URL, WH_NAME, WH_PROTO) values ('http://ping.blo.gs/', 'blo.gs', 'xml-rpc');

insert soft SYS_BLOG_WEBLOG_HOSTS (WH_URL, WH_NAME, WH_PROTO) values ('http://rpc.technorati.com/rpc/ping', 'technorati', 'xml-rpc');

insert soft SYS_BLOG_WEBLOG_HOSTS (WH_URL, WH_NAME, WH_PROTO) values ('http://ping.rootblog.com/rpc.php', 'RootBlog', 'xml-rpc');

insert soft SYS_BLOG_WEBLOG_HOSTS (WH_URL, WH_NAME, WH_PROTO) values ('http://rpc.blogrolling.com/pinger/', 'blogrolling', 'xml-rpc')
;

insert soft SYS_BLOG_WEBLOG_HOSTS (WH_URL, WH_NAME, WH_PROTO) values ('http://www.blogshares.com/rpc.php', 'blogshares', 'xml-rpc');

insert soft SYS_BLOG_WEBLOG_HOSTS (WH_URL, WH_NAME, WH_PROTO) values ('http://api.my.yahoo.com/RPC2', 'My Yahoo', 'xml-rpc');

insert soft SYS_BLOG_WEBLOG_HOSTS (WH_URL, WH_NAME, WH_PROTO) values ('http://api.moreover.com/RPC2', 'Moreover', 'xml-rpc');

insert soft SYS_BLOG_WEBLOG_HOSTS (WH_URL, WH_NAME, WH_PROTO, WH_METHOD) values ('http://rpc.weblogs.com/RPC2', 'Weblog.com (extended)', 'xml-rpc', 'weblogUpdates.extendedPing');

insert soft SYS_BLOG_WEBLOG_HOSTS (WH_URL, WH_NAME, WH_PROTO, WH_METHOD) values ('http://geourl.org/ping/?p=', 'GeoURL', 'REST', 'ping');


blog2_exec_no_error ('create table SYS_BLOG_SEARCH_ENGINE (
  SE_NAME varchar,
  SE_HOOK varchar,
  primary key (SE_NAME)
  )')
;

insert soft SYS_BLOG_SEARCH_ENGINE (SE_NAME, SE_HOOK) values ('Google', 'BLOG.DBA.BLOG_SEARCH_GOOGLE')
;

insert soft SYS_BLOG_SEARCH_ENGINE (SE_NAME, SE_HOOK) values ('Amazon', 'BLOG.DBA.BLOG_SEARCH_AMAZON')
;

blog2_exec_no_error ('create table SYS_BLOG_SEARCH_ENGINE_SETTINGS (
  SS_NAME varchar references SYS_BLOG_SEARCH_ENGINE on update cascade on delete cascade,
  SS_BLOG_ID varchar,
  SS_KEY varchar,
  SS_MAX_ROWS int,
  primary key (SS_NAME, SS_BLOG_ID)
  )');
;

blog2_exec_no_error ('create table BLOG_TAG (
      BT_BLOG_ID varchar,
  BT_POST_ID varchar,
  BT_ID integer identity,
  BT_TAGS varchar,
        primary key (BT_BLOG_ID, BT_POST_ID))');

blog2_exec_no_error ('create index BLOG_TAG_POST_ID on BLOG..BLOG_TAG (BT_POST_ID)');

create procedure BLOG.DBA.BLOG_TAG_BT_TAGS_INDEX_HOOK (inout vtb any, inout d_id integer)
{
  declare tags, blogid, postid, tarr, data any;
  declare exit handler for not found { return 0; };
  --dbg_printf ('BLOG.DBA.BLOG_TAG_BT_TAGS_INDEX_HOOK');
  select BT_TAGS, BT_BLOG_ID, BT_POST_ID into tags, blogid, postid from BLOG_TAG where BT_ID = d_id;
  tarr := split_and_decode (tags, 0, '\0\0,');
  foreach (any elm in tarr) do
    {
      elm := trim(elm);
      elm := replace (elm, ' ', '_');
      vt_batch_feed (vtb, elm, 0);
    }
  vt_batch_feed (vtb, 'b'||replace (blogid, '-','_'), 0);
  vt_batch_feed_offband (vtb, serialize (vector (blogid, postid)), 0);
  return 1;
}
;

create procedure BLOG.DBA.BLOG_TAG_BT_TAGS_UNINDEX_HOOK (inout vtb any, inout d_id integer)
{
  declare tags, blogid, postid, tarr, data any;
  declare exit handler for not found { return 0; };
  --dbg_printf ('BLOG.DBA.BLOG_TAG_BT_TAGS_UNINDEX_HOOK');
  select BT_TAGS, BT_BLOG_ID, BT_POST_ID into tags, blogid, postid from BLOG_TAG where BT_ID = d_id;
  tarr := split_and_decode (tags, 0, '\0\0,');
  foreach (any elm in tarr) do
    {
      elm := trim(elm);
      elm := replace (elm, ' ', '_');
      vt_batch_feed (vtb, elm, 1);
    }
  vt_batch_feed (vtb, 'b'||replace (blogid, '-','_'), 1);
  vt_batch_feed_offband (vtb, serialize (vector (blogid, postid)), 1);
  return 1;
}
;

blog2_exec_no_error ('CREATE TEXT INDEX ON BLOG_TAG (BT_TAGS) WITH KEY BT_ID
    CLUSTERED WITH (BT_BLOG_ID, BT_POST_ID) USING FUNCTION LANGUAGE \'x-ViDoc\'');


blog2_exec_no_error(
  'create table SYS_BLOG_ATTACHES (
   BA_M_BLOG_ID varchar references SYS_BLOG_INFO,
   BA_C_BLOG_ID varchar references SYS_BLOG_INFO,
   BA_FLAG varchar,
   primary key (BA_M_BLOG_ID, BA_C_BLOG_ID))'
)
;

blog2_add_col('BLOG.DBA.SYS_BLOG_ATTACHES', 'BA_LAST_UPDATE', 'timestamp')
;

create trigger SYS_BLOG_ATTACHES_D after delete on SYS_BLOG_ATTACHES referencing old as O
{
  if (not exists (select 1 from SYS_BLOG_ATTACHES where BA_M_BLOG_ID = O.BA_M_BLOG_ID))
    update SYS_BLOG_INFO set BI_HAVE_COMUNITY_BLOG = 0 where BI_BLOG_ID = O.BA_M_BLOG_ID;
}
;


create procedure BLOG_GET_TAGS (in blogid any, in postid any)
{
  declare ret any;
  ret := (select BT_TAGS from BLOG_TAG where BT_BLOG_ID = blogid and BT_POST_ID = postid);
  return coalesce (ret, '');
};

create procedure BLOG_TAGS_STAT (in blogid any)
{
  declare tag varchar;
  declare post_id int;
  declare arr any;
  result_names (post_id, tag);
  for select BT_TAGS, BT_POST_ID from BLOG_TAG where BT_BLOG_ID = blogid do
    {
      arr := split_and_decode (BT_TAGS, 0, '\0\0,');
      foreach (any elm in arr) do
      {
	declare tmp any;
	tmp := trim (elm, ' ,');
	if (length (tmp))
	result (BT_POST_ID, tmp);
      }
    }
}
;

grant execute on BLOG.DBA.BLOG_TAGS_STAT to SPARQL_SELECT
;

blog2_exec_no_error ('create procedure view BLOG_TAGS_STAT as BLOG.DBA.BLOG_TAGS_STAT (blogid) (BT_POST_ID varchar, BT_TAG varchar)');

create procedure BLOG_TAGS_STAT_EXT (in blogid any, in community int)
{
  declare tag varchar;
  declare post_id int;
  declare arr any;
  result_names (post_id, tag);
  if (community)
    {
      for select BT_TAGS, BT_POST_ID from BLOG_TAG, (select BI_BLOG_ID as BA_C_BLOG_ID, BI_BLOG_ID as BA_M_BLOG_ID from BLOG..SYS_BLOG_INFO where BI_BLOG_ID = blogid union all select * from (select BA_C_BLOG_ID, BA_M_BLOG_ID from BLOG.DBA.SYS_BLOG_ATTACHES where BA_M_BLOG_ID = blogid) name1) name2 where BT_BLOG_ID = BA_C_BLOG_ID do
	{
	  arr := split_and_decode (BT_TAGS, 0, '\0\0,');
	  foreach (any elm in arr) do
	    {
	      result (BT_POST_ID, trim (elm, ' ,\t'));
	    }
	}
    }
  else
    {
      for select BT_TAGS, BT_POST_ID from BLOG_TAG where BT_BLOG_ID = blogid do
	{
	  arr := split_and_decode (BT_TAGS, 0, '\0\0,');
	  foreach (any elm in arr) do
	    {
	      result (BT_POST_ID, trim (elm, ' ,\t'));
	    }
	}
    }
}
;

blog2_exec_no_error ('create procedure view BLOG_TAGS_STAT_EXT as BLOG.DBA.BLOG_TAGS_STAT_EXT (blogid, community) (BT_POST_ID varchar, BT_TAG varchar)');

create procedure BLOG_POST_TAGS_STAT (in postid any)
{
  declare tag varchar;
  declare post_id int;
  declare arr any;
  result_names (tag);
  for select BT_TAGS from BLOG_TAG where BT_POST_ID = postid do
    {
      arr := split_and_decode (BT_TAGS, 0, '\0\0,');
      foreach (any elm in arr) do
      {
	result (trim (elm, ' ,'));
      }
    }
}
;

blog2_exec_no_error ('create procedure view BLOG_POST_TAGS_STAT as BLOG.DBA.BLOG_POST_TAGS_STAT (postid) (BT_TAG varchar)');

create procedure BLOG_POST_TAGS_STAT_2 (in postid any, in blogid any)
{
  declare tag varchar;
  declare post_id int;
  declare arr any;
  result_names (tag);
  for select BT_TAGS from BLOG_TAG where BT_BLOG_ID = blogid and BT_POST_ID = postid do
    {
      arr := split_and_decode (BT_TAGS, 0, '\0\0,');
      foreach (any elm in arr) do
      {
	result (trim (elm, ' ,'));
      }
    }
}
;

blog2_exec_no_error ('create procedure view BLOG_POST_TAGS_STAT_2 as BLOG.DBA.BLOG_POST_TAGS_STAT_2 (postid, blogid) (BT_TAG varchar)');

-- NNTP support functions
create procedure blog_wide2utf (inout str any)
{
  if (iswidestring (str))
    return charset_recode (str, '_WIDE_', 'UTF-8' );
  return str;
}
;

create procedure blog_utf2wide (inout str any)
{
  if (isstring (str))
    return charset_recode (str, 'UTF-8', '_WIDE_');
  return str;
}
;


create procedure decode_nntp_subj (inout str varchar)
{
  declare match varchar;
  declare inx int;

  inx := 50;

  str := replace (str, '\t', '');

  match := regexp_match ('=\\?[^\\?]+\\?[A-Z]\\?[^\\?]+\\?=', str);
  while (match is not null and inx > 0)
    {
      declare enc, ty, dat, tmp, cp, dec any;

      cp := match;
      tmp := regexp_match ('^=\\?[^\\?]+\\?[A-Z]\\?', match);

      match := substring (match, length (tmp)+1, length (match) - length (tmp) - 2);

      enc := regexp_match ('=\\?[^\\?]+\\?', tmp);

      tmp := replace (tmp, enc, '');

      enc := trim (enc, '?=');
      ty := trim (tmp, '?');

      if (ty = 'B')
	{
	  dec := decode_base64 (match);
	}
      else if (ty = 'Q')
	{
	  dec := uudecode (match, 12);
	}
      else
	{
	  dec := '';
	}
      declare exit handler for sqlstate '2C000'
	{
	  return;
	};
      dec := charset_recode (dec, enc, 'UTF-8');

      str := replace (str, cp, dec);

      --dbg_printf ('encoded=[%s] enc=[%s] type=[%s] decoded=[%s]', match, enc, ty, dec);
      match := regexp_match ('=\\?[^\\?]+\\?[A-Z]\\?[^\\?]+\\?=', str);
      inx := inx - 1;
    }
};


create procedure SPLIT_MAIL_ADDR (in author any, out person any, out email any)
{
  declare pos int;
  person := '';
  pos := strchr (author, '<');
  if (pos is not NULL)
    {
      person := "LEFT" (author, pos);
      email := subseq (author, pos, length (author));
      email := replace (email, '<', '');
      email := replace (email, '>', '');
      person := trim (replace (person, '"', ''));
      --email := replace (email, '{at}', '@');
    }
  else
    {
      pos := strchr (author, '(');
      if (pos is not NULL)
	{
	  email := trim ("LEFT" (author, pos));
	  person :=  subseq (author, pos, length (author));
	  person := replace (person, '(', '');
	  person := replace (person, ')', '');
	}
    }
}
;


create procedure BLOG..MAKE_RFC_ID (in postid varchar, in commid int := null)
{
  declare ret, _hash, host any;

  _hash := md5(registry_get ('WeblogServerID'));
  host := sys_stat ('st_host_name');
  if (commid is null)
    ret := sprintf ('<%s.%s@%s>', postid, _hash, host);
  else
    ret := sprintf ('<%s.%d.%s@%s>', postid, commid, _hash, host);
  return ret;
}
;

create procedure BLOG_MAKE_MAIL_SUBJECT (in txt any, in id varchar := null)
{
  declare enc any;
  enc :=  encode_base64 (blog_wide2utf (txt));
  enc := replace (enc, '\r\n', '');
  txt := concat ('Subject: =?UTF-8?B?', enc, '?=\r\n');
  if (id is not null)
    txt := concat (txt, 'X-Virt-BlogID: ', registry_get ('WeblogServerID'), ';', id, '\r\n');
  return txt;
}
;



create procedure MAKE_POST_RFC_HEADER (in mid varchar, in refs varchar, in gid varchar,
    				       in title varchar, in rec datetime, in author_mail varchar)
{
  declare ses any;
  ses := string_output ();
--  dbg_obj_print ('mid=',mid,' refs=',refs,' gid=',gid, ' title=', title, ' rec=', rec, ' author_mail=', author_mail);
  http (BLOG_MAKE_MAIL_SUBJECT (title), ses);
  http (sprintf ('Date: %s\r\n', DB.DBA.date_rfc1123 (rec)), ses);
  http (sprintf ('Message-Id: %s\r\n', mid), ses);
  if (refs is not null)
    http (sprintf ('References: %s\r\n', refs), ses);
  http (sprintf ('From: %s\r\n', author_mail), ses);
  http ('Content-Type: text/html; charset=UTF-8\r\n', ses);
  http (sprintf ('Newsgroups: %s\r\n\r\n', gid), ses);
  ses := string_output_string (ses);
  return ses;
};

create procedure BLOG_NEWS_UPGRADE ()
{
  if (registry_get ('__BLOG_NEWS_UPGRADE_done') = 'done')
    return;

  declare mid, rfc_head any;

  for select B_BLOG_ID as bid, B_POST_ID as id, B_TITLE as title, B_TS as post_date, U_E_MAIL as author
    from SYS_BLOGS, DB.DBA.SYS_USERS
    where B_USER_ID = U_ID do
      {
	mid := BLOG..MAKE_RFC_ID (id);
	rfc_head := MAKE_POST_RFC_HEADER (mid, null, bid, title, post_date, author);
	set triggers off;
	update SYS_BLOGS set B_RFC_ID = mid, B_RFC_HEADER = rfc_head where B_BLOG_ID = bid and B_POST_ID = id;
	set triggers on;
      }

  update BLOG_COMMENTS set BM_BLOG_ID = (select B_BLOG_ID from SYS_BLOGS where B_POST_ID = BM_POST_ID)
      where not exists (select 1 from SYS_BLOGS where B_BLOG_ID = BM_BLOG_ID and B_POST_ID = BM_POST_ID);

  for select B_TITLE as title, B_POST_ID as pid, BM_ID as id, B_RFC_ID as refs,
    B_BLOG_ID as bid, BM_TS as post_date, BM_E_MAIL as author
    from BLOG_COMMENTS, SYS_BLOGS where B_BLOG_ID = BM_BLOG_ID and B_POST_ID = BM_POST_ID do
      {
	title := 'Re:' || title;
	mid := BLOG..MAKE_RFC_ID (pid, id);
	rfc_head := MAKE_POST_RFC_HEADER (mid, refs, bid, title, post_date, author);
	set triggers off;
	update BLOG_COMMENTS set BM_RFC_ID = mid, BM_RFC_HEADER = rfc_head, BM_TITLE = title
	    where BM_BLOG_ID = bid and BM_POST_ID = pid and BM_ID = id;
	set triggers on;
      }

  set triggers off;
  update SYS_BLOG_INFO set BI_SHOW_AS_NEWS = 0;
  set triggers on;

  registry_set ('__BLOG_NEWS_UPGRADE_done', 'done');
};

BLOG_NEWS_UPGRADE ()
;

create procedure BLOG_VER_UPGRADE ()
{
  if (registry_get ('__BLOG_VER_UPGRADE_done') = 'done')
    return;
  set triggers off;
  update SYS_BLOGS set B_VER = 1 where B_VER is null;
  set triggers on;
  registry_set ('__BLOG_VER_UPGRADE_done', 'done');
};

BLOG_VER_UPGRADE ();

create procedure BLOG_ADD_LINKS (in blogid varchar, in postid varchar, inout content any)
{
  declare xt, xp any;
  declare tit, href, cls any;
  declare me, blog_iri, _inst varchar;

  delete from BLOG_POST_LINKS where PL_BLOG_ID = blogid and PL_POST_ID = postid;
  if (content is null)
    return;
  else if (isentity (content))
    xt := content;
  else
    xt := xtree_doc (content, 2, '', 'UTF-8');
  xp := xpath_eval ('//a[starts-with (@href,"http") and not(img)]', xt, 0);
  foreach (any elm in xp) do
    {
      tit := cast (xpath_eval ('string()', elm) as varchar);
      href := cast (xpath_eval ('@href', elm) as varchar);
      cls := cast (xpath_eval ('@class', elm) as varchar);
      insert soft BLOG_POST_LINKS (PL_BLOG_ID,PL_POST_ID,PL_LINK,PL_TITLE, PL_PING) values (blogid,postid,href,tit, 
	  case when cls = 'auto-href' then 1 else 0 end);
    }
  xp := xpath_eval ('//a[starts-with (@href,"http") and not(img) and @class = "auto-href"]', xt, 0);
  me := sioc..blog_post_iri (blogid, postid);
  _inst := (select BI_WAI_NAME from BLOG..SYS_BLOG_INFO where BI_BLOG_ID = blogid);
  blog_iri := sioc..blog_iri (_inst);
  -- do this conditionally
  if (exists (select 1 from SEMPING..PING_RULES where PR_IRI = blog_iri))    
    {
      foreach (any elm in xp) do
	{
	  href := cast (xpath_eval ('@href', elm) as varchar);
	  SEMPING..CLI_PING (me, href);
	}
    }
};

create procedure BLOG_LINKS_UPGRADE ()
{
  if (registry_get ('__BLOG_LINK_UPGRADE_done') = 'done')
    return;
  for select B_BLOG_ID, B_POST_ID, B_CONTENT from BLOG..SYS_BLOGS do
    {
      BLOG_ADD_LINKS (B_BLOG_ID, B_POST_ID, B_CONTENT);
    }
  registry_set ('__BLOG_LINK_UPGRADE_done', 'done');
};

BLOG_LINKS_UPGRADE ();

create procedure BLOG_ADD_COMMENT_LINKS (in blogid varchar, in postid varchar, in cid int, inout content any)
{
  declare xt, xp any;
  declare tit, href, cls any;
  declare me, blog_iri, _inst varchar;

  delete from BLOG_COMMENT_LINKS where CL_BLOG_ID = blogid and CL_POST_ID = postid and CL_CID = cid;
  if (content is null)
    return;
  else if (isentity (content))
    xt := content;
  else
    xt := xtree_doc (content, 2, '', 'UTF-8');
  xp := xpath_eval ('//a[starts-with (@href,"http") and not(img)]', xt, 0);
  foreach (any elm in xp) do
    {
      tit := cast (xpath_eval ('string()', elm) as varchar);
      href := cast (xpath_eval ('@href', elm) as varchar);
      cls := cast (xpath_eval ('@class', elm) as varchar);
      insert soft BLOG_COMMENT_LINKS (CL_BLOG_ID,CL_POST_ID, CL_CID, CL_LINK,CL_TITLE, CL_PING) values (blogid,postid,cid,href,tit, 
	  case when cls = 'auto-href' then 1 else 0 end);
    }
  xp := xpath_eval ('//a[starts-with (@href,"http") and not(img) and @class = "auto-href"]', xt, 0);
  me := sioc..blog_comment_iri (blogid, postid, cid);
  _inst := (select BI_WAI_NAME from BLOG..SYS_BLOG_INFO where BI_BLOG_ID = blogid);
  blog_iri := sioc..blog_iri (_inst);
  -- do this conditionally
  if (0 and exists (select 1 from SEMPING..PING_RULES where PR_IRI = blog_iri))    
    {
      foreach (any elm in xp) do
	{
	  href := cast (xpath_eval ('@href', elm) as varchar);
	  SEMPING..CLI_PING (me, href);
	}
    }
};


create procedure BLOG_ENCL_UPGRADE ()
{
  if (registry_get ('__BLOG_ENCL_UPGRADE_done') = 'done')
    return;
  for select B_BLOG_ID, B_POST_ID, B_CONTENT, B_META, B_HAVE_ENCLOSURE from BLOG..SYS_BLOGS do
    {
      declare meta BLOG.DBA."MWeblogPost";
      declare enc BLOG.DBA."MWeblogEnclosure";
      if (B_HAVE_ENCLOSURE = 1)
	{
	  meta := B_META;
	  enc := meta.enclosure;
	  if (length (enc."url"))
	    {
	  insert into BLOG_POST_ENCLOSURES (PE_BLOG_ID, PE_POST_ID, PE_URL, PE_TYPE, PE_LEN)
	     values (B_BLOG_ID, B_POST_ID, enc."url", enc."type", enc."length");
        }
    }
    }
  registry_set ('__BLOG_ENCL_UPGRADE_done', 'done');
};

BLOG_ENCL_UPGRADE ();

-- TRIGGERS


create trigger BLOG_COMMENTS_I after insert on MTYPE_TRACKBACK_PINGS referencing new as N
{
  declare opts, appr, ratelim, rate, owner, id, postid, blogid any;
  declare is_spam, published int;

  postid := N.MP_POST_ID;
  id := N.MP_ID;

  select deserialize (blob_to_string (BI_OPTIONS)), BI_OWNER, BI_BLOG_ID into opts, owner, blogid
      from BLOG..SYS_BLOG_INFO, BLOG..SYS_BLOGS
      where BI_BLOG_ID = B_BLOG_ID and B_POST_ID = postid;

  if (not isarray (opts))
    opts := vector ();

  appr := get_keyword ('CommentApproval', opts, 0);
  ratelim := get_keyword ('SpamRateLimit', opts, '1.00');

  rate := DB.DBA.spam_filter_message (N.MP_TITLE||' '||N.MP_EXCERPT, owner);
  is_spam := gte (rate,ratelim);
  published := equ (appr, 0);

  if (is_spam or appr = 1)
    {
      published := 0;
      goto skip;
    }

  update SYS_BLOGS set B_TRACKBACK_NO = B_TRACKBACK_NO + 1 where B_POST_ID = N.MP_POST_ID;

skip:
  set triggers off;
  update BLOG..MTYPE_TRACKBACK_PINGS set MP_IS_PUB = published, MP_IS_SPAM = is_spam
      where MP_POST_ID = postid and MP_ID = id;
  set triggers on;
  return;
}
;

create trigger BLOG_COMMENTS_U after update on MTYPE_TRACKBACK_PINGS referencing old as O, new as N
{
  if (N.MP_IS_PUB = 1 and O.MP_IS_PUB = 0)
    update SYS_BLOGS set B_TRACKBACK_NO = B_TRACKBACK_NO + 1 where B_POST_ID = N.MP_POST_ID;
}
;

create trigger BLOG_COMMENTS_D after delete on MTYPE_TRACKBACK_PINGS
{
  if (MP_IS_PUB = 1)
    update SYS_BLOGS set B_TRACKBACK_NO = B_TRACKBACK_NO - 1 where B_POST_ID = MP_POST_ID;
}
;

create trigger BLOG_COMMENTS_NO_I after insert on BLOG_COMMENTS referencing new as N
{
  declare opts, appr, ratelim, rate, owner, id, postid, blogid, domain, home, title, orgblogid any;
  declare is_spam, published int;
  declare mid, rfc, refs, comment_title varchar;
  declare oid_sig, oid_is_valid int;
  declare post_iri, body varchar;

  blogid := N.BM_BLOG_ID;
  postid := N.BM_POST_ID;
  id := N.BM_ID;

  oid_is_valid := 0;

  if (N.BM_RFC_ID is null)
    mid := BLOG..MAKE_RFC_ID (N.BM_POST_ID, N.BM_ID);
  else
    mid := N.BM_RFC_ID;

  whenever not found goto ret;
  select deserialize (blob_to_string (BI_OPTIONS)), BI_OWNER, BI_HOME, B_TITLE, BI_BLOG_ID, B_RFC_ID
      into opts, owner, home, title, orgblogid, refs from BLOG..SYS_BLOG_INFO, BLOG..SYS_BLOGS
      where B_POST_ID = N.BM_POST_ID and B_BLOG_ID = BI_BLOG_ID;

  body := BLOG.DBA.CONTENT_ANNOTATE (owner, N.BM_COMMENT);
  BLOG_ADD_COMMENT_LINKS (orgblogid, postid, id, body);

  comment_title := 'Re:' || title;

  if (N.BM_REF_ID)
    {
      declare p_id, p_refs any;
      declare exit handler for not found;
      select BM_RFC_ID, BM_RFC_REFERENCES into p_id, p_refs from BLOG..BLOG_COMMENTS
	  where BM_BLOG_ID = orgblogid and BM_POST_ID = N.BM_POST_ID and BM_ID = N.BM_REF_ID;
      if (p_refs is null)
	p_refs := refs;
      refs :=  p_refs || ' ' || p_id;
    }

  if (N.BM_RFC_HEADER is null)
    rfc := MAKE_POST_RFC_HEADER (mid, refs, orgblogid, comment_title, N.BM_TS, N.BM_E_MAIL);
  else
    rfc := N.BM_RFC_HEADER;


  domain := null;
  whenever not found goto nfc;
  select top 1 BM_POSTED_VIA into domain from BLOG_COMMENTS where BM_BLOG_ID = orgblogid and BM_POST_ID = postid
      and BM_POSTED_VIA is not null order by BM_ID;
  nfc:

  if (domain is null and is_http_ctx ())
    {
       declare lines any;
       lines := http_request_header ();
       if (isarray (lines))
	 domain := http_request_header (lines, 'Host', null, null);
    }

  if (N.BM_OWN_COMMENT = 1)
    {
      is_spam := 0;
      published := 1;
      appr := 0;
      goto own_comm;
    }

  if (not isarray (opts))
    opts := vector ();

  appr := get_keyword ('CommentApproval', opts, 0);
  oid_sig := get_keyword ('OpenID', opts, 0);
  ratelim := get_keyword ('SpamRateLimit', opts, '1.00');

  if (oid_sig and length (N.BM_OPENID_SIG))
    oid_is_valid := OPENID..check_signature (N.BM_OPENID_SIG);

  if (not oid_is_valid)
    {
  rate := DB.DBA.spam_filter_message (N.BM_COMMENT, owner);
  is_spam := gte (rate,ratelim);
  published := equ (appr, 0);
    }
  else
    {
      is_spam := 0;
      published := 1;
      appr := 0;
    }


  if (is_spam or appr = 1)
    {
      published := 0;
      goto skip;
    }

own_comm:;
  set triggers off;
  update SYS_BLOGS set B_COMMENTS_NO = B_COMMENTS_NO + 1 where B_POST_ID = N.BM_POST_ID;
  post_iri := sioc..blog_comment_iri (orgblogid, postid, N.BM_ID);
  update BLOG.DBA.SYS_BLOG_INFO
  set BI_LAST_UPDATE = now (),
      BI_DASHBOARD = make_dasboard_item ('comment', N.BM_TS, title, N.BM_NAME, post_iri, N.BM_COMMENT, BI_DASHBOARD, N.BM_ID, 'insert', null, N.BM_E_MAIL)
  where BI_BLOG_ID = orgblogid;
  set triggers on;

  for select R_JOB_ID from SYS_ROUTING where R_ITEM_ID = orgblogid and R_TYPE_ID in (1,2) do
    {
      insert into SYS_BLOGS_ROUTING_LOG (RL_JOB_ID, RL_POST_ID, RL_TYPE, RL_COMMENT_ID)
         values (R_JOB_ID, N.BM_POST_ID, 'CI', N.BM_ID);
    }
skip:
  set triggers off;
  update BLOG..BLOG_COMMENTS set BM_IS_PUB = published, BM_IS_SPAM = is_spam, BM_POSTED_VIA = domain, BM_BLOG_ID = orgblogid,
	 BM_RFC_ID = mid, BM_RFC_HEADER = rfc, BM_TITLE = comment_title, BM_RFC_REFERENCES = refs, BM_COMMENT = body
      where BM_BLOG_ID = blogid and BM_POST_ID = postid and BM_ID = id;
  set triggers on;
ret:
  return;
}
;

create trigger BLOG_COMMENTS_NO_U after update on BLOG_COMMENTS referencing old as O, new as N
{
  declare home, title varchar;
  declare post_iri varchar;
  if (N.BM_IS_PUB = 1)
    {
      select BI_HOME, B_TITLE into home, title from BLOG..SYS_BLOG_INFO, BLOG..SYS_BLOGS where
	  B_BLOG_ID = BI_BLOG_ID and B_POST_ID = N.BM_POST_ID and BI_BLOG_ID = N.BM_BLOG_ID;

      set triggers off;
      if (O.BM_IS_PUB = 0)
	{
      update SYS_BLOGS set B_COMMENTS_NO = B_COMMENTS_NO + 1 where B_POST_ID = N.BM_POST_ID;
	}
      post_iri := sioc..blog_comment_iri (N.BM_BLOG_ID, N.BM_POST_ID, N.BM_ID);
      update BLOG.DBA.SYS_BLOG_INFO
	  set BI_LAST_UPDATE = now (),
	      BI_DASHBOARD = make_dasboard_item ('comment', N.BM_TS, title, N.BM_NAME, post_iri, N.BM_COMMENT, BI_DASHBOARD, N.BM_ID, 'insert', null, N.BM_E_MAIL)
	  where BI_BLOG_ID = N.BM_BLOG_ID;
      set triggers on;
      for select R_JOB_ID from SYS_ROUTING where R_ITEM_ID = N.BM_BLOG_ID and R_TYPE_ID in (1,2) do
	{
	  insert into SYS_BLOGS_ROUTING_LOG (RL_JOB_ID, RL_POST_ID, RL_TYPE, RL_COMMENT_ID)
	      values (R_JOB_ID, N.BM_POST_ID, 'CI', N.BM_ID);
	}
    }
}
;

create trigger BLOG_COMMENTS_NO_D after delete on BLOG_COMMENTS referencing old as O
{
  if (O.BM_IS_PUB = 1)
    {
      set triggers off;
      update SYS_BLOGS set B_COMMENTS_NO = B_COMMENTS_NO - 1 where B_POST_ID = O.BM_POST_ID and B_BLOG_ID = O.BM_BLOG_ID;
      set triggers on;
    }
  delete from SYS_BLOGS_ROUTING_LOG where  RL_COMMENT_ID = O.BM_ID;
  delete from BLOG_COMMENT_LINKS where CL_BLOG_ID = O.BM_BLOG_ID and CL_POST_ID = O.BM_POST_ID and CL_CID = O.BM_ID;

  set triggers off;
  update BLOG.DBA.SYS_BLOG_INFO
  set BI_DASHBOARD =
	  make_dasboard_item ('comment', null, null, null, null, '', BI_DASHBOARD, O.BM_ID, 'delete')
  where BI_BLOG_ID = O.BM_BLOG_ID;

  -- update all that have BM_REF_ID == O.BM_ID
  update BLOG..BLOG_COMMENTS set BM_REF_ID = O.BM_REF_ID where BM_BLOG_ID = O.BM_BLOG_ID and
    BM_POST_ID = O.BM_POST_ID and BM_REF_ID = O.BM_ID;

  set triggers on;
}
;

create trigger SYS_ROUTING_D after delete on SYS_ROUTING
{
  delete from SYS_BLOGS_ROUTING_LOG where RL_JOB_ID = R_JOB_ID;
}
;

create procedure BLOG_CHECK_QUOTA (in uid int)
{
  declare qn, qm int;
  declare opts any;

  if (uid = http_dav_uid ())
    return 1;

  whenever not found goto endf;
  select deserialize(blob_to_string(U_OPTS)) into opts from "DB"."DBA"."SYS_USERS" where U_ID = uid;
  if (not isarray(opts))
    opts := vector ();
  qn := get_keyword ('WeblogQuotaMaxPosts', opts, 'unlimited');
  qm := get_keyword ('WeblogQuotaMaxSize', opts, 'unlimited');

  if (isinteger (qn) and qn > 0)
    {
      declare tot int;
      select count (*) into tot from SYS_BLOGS where B_USER_ID = uid;
      if (tot > qn)
  {
          return 0;
        }
    }

  if (isinteger (qm) and qm > 0)
    {
      declare tot int;
      select sum (length (B_CONTENT)) into tot from SYS_BLOGS where B_USER_ID = uid;
      if (tot > qm)
  {
          return 0;
        }
    }

  endf:
  return 1;
}
;

create trigger SYS_BLOGS_I_Q after insert on SYS_BLOGS order 1
{
  if (not BLOG_CHECK_QUOTA (B_USER_ID))
    {
      rollback work;
      signal ('42000', 'Weblog quota exceeded.');
    }
}
;

create trigger SYS_BLOGS_U_Q after update on SYS_BLOGS order 1 referencing old as O, new as N
{
  if (not BLOG_CHECK_QUOTA (N.B_USER_ID))
    {
      rollback work;
      signal ('42000', 'Weblog quota exceeded.');
    }
}
;

create trigger SYS_BLOGS_I_L after insert on SYS_BLOGS order 10
{
  for select R_JOB_ID, R_TYPE_ID as tid, R_DESTINATION_ID, R_ITEM_MAX_RETRANSMITS from SYS_ROUTING
    where R_ITEM_ID = B_BLOG_ID and R_TYPE_ID in (1, 2, 3) do
      {
	-- insert a record in log
    insert soft SYS_BLOGS_ROUTING_LOG (RL_JOB_ID, RL_POST_ID, RL_TYPE, RL_RETRANSMITS)
    values (R_JOB_ID, B_POST_ID, 'I', R_ITEM_MAX_RETRANSMITS);
      }
}
;

create trigger SYS_BLOGS_U_L after update on SYS_BLOGS order 10 referencing old as O, new as N
{
  for select R_JOB_ID, R_TYPE_ID as tid, R_DESTINATION_ID, R_ITEM_MAX_RETRANSMITS from SYS_ROUTING
    where R_ITEM_ID = N.B_BLOG_ID and R_TYPE_ID in (1, 3) do
      {
	-- mark for update if it's already sent to target
    update SYS_BLOGS_ROUTING_LOG set RL_TYPE = 'U', RL_PROCESSED = 0, RL_RETRANSMITS = R_ITEM_MAX_RETRANSMITS
	where RL_JOB_ID = R_JOB_ID and RL_POST_ID = N.B_POST_ID and RL_TYPE in ('I', 'U')
	and RL_F_POST_ID is not null and RL_COMMENT_ID = -1;
	  if (row_count () = 0)
	    {
	  insert soft SYS_BLOGS_ROUTING_LOG (RL_JOB_ID, RL_POST_ID, RL_TYPE, RL_RETRANSMITS)
	      values (R_JOB_ID, N.B_POST_ID, 'I', R_ITEM_MAX_RETRANSMITS);
	    }
      }
}
;

create trigger SYS_BLOGS_D_L after delete on SYS_BLOGS order 10
{
  for select R_JOB_ID, R_ITEM_MAX_RETRANSMITS from SYS_ROUTING where R_ITEM_ID = B_BLOG_ID and R_TYPE_ID in (1, 3) do
  {
    -- mark for delete if already sent to target
    update SYS_BLOGS_ROUTING_LOG set RL_TYPE = 'D', RL_PROCESSED = 0, RL_RETRANSMITS = R_ITEM_MAX_RETRANSMITS
    where RL_JOB_ID = R_JOB_ID and RL_POST_ID = B_POST_ID and RL_F_POST_ID is not null
    and RL_COMMENT_ID = -1;
    -- delete if it's not already sent
    delete from SYS_BLOGS_ROUTING_LOG where RL_JOB_ID = R_JOB_ID and RL_POST_ID = B_POST_ID
    and RL_F_POST_ID is null;
  }
}
;


create trigger SYS_USERS_BLOG_D after delete on "DB"."DBA"."SYS_USERS" order 90
{
  delete from SYS_BLOG_INFO where BI_OWNER = U_ID;
}
;


create trigger SYS_BLOGS_D after delete on SYS_BLOGS
{
  delete from MTYPE_BLOG_CATEGORY where MTB_POST_ID = B_POST_ID and MTB_BLOG_ID = B_BLOG_ID;
  delete from BLOG_COMMENTS where BM_POST_ID = B_POST_ID and BM_BLOG_ID = B_BLOG_ID;
  delete from MTYPE_TRACKBACK_PINGS where MP_POST_ID = B_POST_ID;
  delete from SYS_BLOG_REFFERALS where BR_BLOG_ID = B_BLOG_ID and BR_POST_ID = B_POST_ID;
  delete from SYS_BLOG_VISITORS where BV_BLOG_ID = B_BLOG_ID and BV_POST_ID = B_POST_ID;
  delete from BLOG_TAG where BT_BLOG_ID = B_BLOG_ID and BT_POST_ID = B_POST_ID;
}
;

create trigger SYS_BLOG_INFO_D after delete on SYS_BLOG_INFO
{
  delete from SYS_BLOGS where B_BLOG_ID = BI_BLOG_ID;
  delete from SYS_BLOG_CHANNELS where BC_BLOG_ID = BI_BLOG_ID;
  delete from MTYPE_CATEGORIES where MTC_BLOG_ID = BI_BLOG_ID;
  delete from SYS_ROUTING where R_ITEM_ID = BI_BLOG_ID and R_TYPE_ID = 1;
  delete from SYS_BLOG_SEARCH_ENGINE_SETTINGS where SS_BLOG_ID = BI_BLOG_ID;
}
;

-- UPGRADE CODE

create procedure SYS_BLOGS_UPGRADE ()
{
  declare id, nid, ver any;
  declare cr cursor for select B_POST_ID from SYS_BLOGS where B_CONTENT_ID is null;
  whenever not found goto nf;


-- skip if upgrated
  if (registry_get ('Weblog_version') = '1.1')
    return;

  open cr;
  while (1)
    {
      fetch cr into id;
      update SYS_BLOGS set B_CONTENT_ID = atoi (id) where current of cr;
    }
  nf:
   close cr;

  if (not exists (select top 1 1 from SYS_BLOG_INFO))
    {
      for select cast (U_ID as varchar) as B_BLOG_ID, U_NAME, U_FULL_NAME, U_ID
  from WS.WS.SYS_DAV_USER
   where exists (select 1 from WS.WS.SYS_DAV_RES where RES_FULL_PATH = '/DAV/'||U_NAME||'/blog/rss.xml') do
  {
          declare owner, title, home, phome, uid, name any;
          owner := U_ID;
    title := U_FULL_NAME || '\'s Weblog';
          home := '/blog/' || U_NAME || '/blog/';
          phome := '/DAV/' || U_NAME || '/blog/';
          insert into SYS_BLOG_INFO (BI_BLOG_ID, BI_OWNER, BI_HOME, BI_TITLE, BI_DEFAULT_PAGE, BI_P_HOME)
    values (B_BLOG_ID, owner, home, title, 'index.vsp', phome);
  }
    }

  update SYS_BLOG_INFO set BI_P_HOME = '/DAV/' || substring (BI_HOME, 7, length (BI_HOME)) where BI_P_HOME is null and BI_HOME like '/blog/%';

  update SYS_BLOG_INFO set BI_SHOW_CONTACT = 1, BI_SHOW_REGIST = 1, BI_COMMENTS = 1, BI_HOME_PAGE = '' where BI_HOME_PAGE is null;

  set triggers off;
  update SYS_BLOGS set B_TRACKBACK_NO = 0 where B_TRACKBACK_NO is null;

  update SYS_BLOGS set B_TS = B_TS where B_MODIFIED is null;
  set triggers on;

  update SYS_BLOG_INFO set BI_FILTER = '*default*' where BI_FILTER is null;

  delete from SYS_BLOG_INFO where not exists (select 1 from "DB"."DBA"."SYS_USERS" where U_ID = BI_OWNER);

  update SYS_BLOG_CHANNEL_INFO set BCD_IS_BLOG = 1 where BCD_IS_BLOG is null and BCD_FORMAT not in ('OPML', 'OCS');

  update SYS_BLOG_INFO set BI_E_MAIL = (select U_E_MAIL from "DB"."DBA"."SYS_USERS" where U_ID = BI_OWNER) where BI_E_MAIL is null;

  declare f_cat_id int;

  for select BC_CHANNEL_URI url, BCD_IS_BLOG, BC_BLOG_ID bid from SYS_BLOG_CHANNELS, SYS_BLOG_CHANNEL_INFO
  where BC_CHANNEL_URI = BCD_CHANNEL_URI and BC_CAT_ID IS NULL and not BCD_FORMAT in ('OCS', 'OPML') do
    {
      if (BCD_IS_BLOG)
        {
           if (not exists (select 1 from SYS_BLOG_CHANNEL_CATEGORY
            where BCC_NAME = 'Blog Roll' and BCC_BLOG_ID = bid))
           {
             insert into SYS_BLOG_CHANNEL_CATEGORY (BCC_BLOG_ID, BCC_NAME) values (bid, 'Blog Roll');
           }
          f_cat_id := (select BCC_ID from SYS_BLOG_CHANNEL_CATEGORY
            where BCC_NAME = 'Blog Roll' and BCC_BLOG_ID = bid);
        }
      else
        {
           if (not exists (select 1 from SYS_BLOG_CHANNEL_CATEGORY
            where BCC_NAME = 'Channel Roll' and BCC_BLOG_ID = bid))
           {
             insert into SYS_BLOG_CHANNEL_CATEGORY (BCC_BLOG_ID, BCC_NAME) values (bid, 'Channel Roll');
           }
          f_cat_id := (select BCC_ID from SYS_BLOG_CHANNEL_CATEGORY
            where BCC_NAME = 'Channel Roll' and BCC_BLOG_ID = bid);
        }
      update SYS_BLOG_CHANNELS set BC_CAT_ID = f_cat_id where BC_CHANNEL_URI = url and BC_BLOG_ID = bid;
    }

  ver := '1.1';
  registry_set ('Weblog_version', ver);
  registry_set ('WeblogServerID', uuid ());
  return;
}
;

create procedure SYS_BLOGS_UPGRADE_1 ()
{
  declare id int;
  if (registry_get ('__SYS_BLOGS_UPGRADE_1_done') = 'done')
    return;
  if (exists (select 1 from SYS_BLOGS where B_IS_ACTIVE is null))
    {
      set triggers off;
      update SYS_BLOGS set B_IS_ACTIVE = 0 where B_IS_ACTIVE is null;
      update SYS_BLOGS set B_IS_ACTIVE = 1
      	where xpath_contains (B_CONTENT, '[__quiet BuildStandalone=ENABLE xmlns:sql="urn:schemas-openlink-com:xml-sql" ] //sql:*');
      --for select B_POST_ID as id, B_BLOG_ID as bid, B_CONTENT as cnt from SYS_BLOGS
      --where xpath_contains (B_CONTENT, '[__quiet BuildStandalone=ENABLE] //tr[not ancestor::table]|//td[not ancestor::table') do
      --  {
      --    update SYS_BLOGS set B_CONTENT = '<table>'||blob_to_string (cnt)||'</table>'
      --     where B_BLOG_ID = bid and B_POST_ID = id;
      --  }
      set triggers on;
    }
  if (not exists (select 1 from SYS_BLOG_INFO where BI_BLOG_SEQ is null))
    return;
  id := 1;
  set triggers off;
  for select BI_BLOG_ID as bid from SYS_BLOG_INFO where BI_BLOG_SEQ is null do
    {
      update SYS_BLOG_INFO set BI_BLOG_SEQ = id where BI_BLOG_ID = bid;
      id := id + 1;
    }
  DB.DBA.SET_IDENTITY_COLUMN ('BLOG.DBA.SYS_BLOG_INFO', 'BI_BLOG_SEQ', id);
  set triggers on;
  registry_set ('__SYS_BLOGS_UPGRADE_1_done', 'done');
}
;

SYS_BLOGS_UPGRADE ()
;

SYS_BLOGS_UPGRADE_1 ();

create procedure BLOG.DBA.SYS_BLOGS_B_CONTENT_INDEX_HOOK (inout vtb any, inout d_id integer)
{
  declare title, blogid varchar;
  declare wai_id int;
  select B_TITLE, B_BLOG_ID into title, blogid from SYS_BLOGS where B_CONTENT_ID = d_id;
  wai_id := (select WAI_ID from DB.DBA.WA_INSTANCE, BLOG.DBA.SYS_BLOG_INFO where BI_WAI_NAME = WAI_NAME and BI_BLOG_ID = blogid);
  --dbg_obj_print ('BLOG.DBA.SYS_BLOGS_B_CONTENT_INDEX_HOOK', title);
  if (length (title))
    vt_batch_feed (vtb, title, 0);
  if (wai_id is not null)
    vt_batch_feed (vtb, sprintf ('^B%d', wai_id), 0);
  return 0;
};

create procedure BLOG.DBA.SYS_BLOGS_B_CONTENT_UNINDEX_HOOK (inout vtb any, inout d_id integer)
{
  declare title, blogid varchar;
  declare wai_id int;
  select B_TITLE, B_BLOG_ID into title, blogid from SYS_BLOGS where B_CONTENT_ID = d_id;
  wai_id := (select WAI_ID from DB.DBA.WA_INSTANCE, BLOG.DBA.SYS_BLOG_INFO where BI_WAI_NAME = WAI_NAME and BI_BLOG_ID = blogid);
  --dbg_obj_print ('BLOG.DBA.SYS_BLOGS_B_CONTENT_UNINDEX_HOOK', title);
  if (length (title))
    vt_batch_feed (vtb, title, 1);
  if (wai_id is not null)
    vt_batch_feed (vtb, sprintf ('^B%d', wai_id), 1);
  return 0;
};

DB.DBA.vt_create_text_index ('BLOG.DBA.SYS_BLOGS', 'B_CONTENT', 'B_CONTENT_ID', 2, 0, vector ('B_BLOG_ID','B_POST_ID','B_TS'), 1, '*ini*', 'UTF-8')
;

DB.DBA.vt_create_ftt ('BLOG.DBA.SYS_BLOGS', 'B_CONTENT_ID', 'B_CONTENT', 2)
;

DB.DBA.vt_create_text_index ('BLOG.DBA.BLOG_COMMENTS', 'BM_COMMENT', 'BM_ID', 2, 0, null, null, '*ini*', 'UTF-8')
;

DB.DBA.vt_create_ftt ('BLOG.DBA.BLOG_COMMENTS', 'BM_ID', 'BM_COMMENT', 2)
;

create trigger SYS_BLOGS_I_C after insert on SYS_BLOGS_B_CONTENT_HIT
{
  declare blogid, postid, catid, did, qid varchar;
  whenever not found goto endf;
  did := TTH_D_ID;
  qid := TTH_T_ID;

  select top 1 B_POST_ID, B_BLOG_ID, TT_PREDICATE into postid, blogid, catid
  from SYS_BLOGS, SYS_BLOGS_B_CONTENT_QUERY
  where TT_ID = qid and TT_CD = B_BLOG_ID and B_CONTENT_ID = did;

    {
      insert soft MTYPE_BLOG_CATEGORY (MTB_CID, MTB_POST_ID, MTB_BLOG_ID, MTB_IS_AUTO)
	  values (catid, postid, blogid, 1);
    }
  endf:
  return;
}
;

create trigger MTYPE_CATEGORIES_D after delete on MTYPE_CATEGORIES referencing old as O
{
  delete from MTYPE_BLOG_CATEGORY where MTB_BLOG_ID = O.MTC_BLOG_ID and MTB_CID = O.MTC_ID;
  delete from SYS_BLOGS_B_CONTENT_QUERY where TT_CD = O.MTC_BLOG_ID and TT_PREDICATE = O.MTC_ID;
}
;


create procedure FTI_MAKE_OR_SEARCH_STRING (in exp varchar)
{
  declare exp1 varchar;
  declare war, vt any;
  declare m, n int;

  if (length (exp) < 2)
    return null;

  exp := trim (exp, ' ');

  if (strchr (exp, ' ') is null)
    return concat ('"', trim (exp, '"'), '"');


  exp1 := '';

  if (strchr (exp, '"') is not null or
      strchr (exp, '''') is not null)
   {
     declare tmp, w varchar;
     tmp := exp;
     w := regexp_match ('["][^"]+["]|[''][^'']+['']|[^"'' ]+', tmp, 1);
     while (w is not null)
       {
         w := trim (w, '"'' ');
         if (upper(w) not in ('AND', 'NOT', 'NEAR', 'OR')
       and length (w) > 1
             and not vt_is_noise (w, 'utf-8', 'x-any'))
           exp1 := concat (exp1, sprintf ('"%s" OR ', w));
         w := regexp_match ('["][^"]+["]|[''][^'']+['']|[^"'' ]+', tmp, 1);
       }
     if (length (exp1) > 5)
       {
         exp1 := substring (exp1, 1, length (exp1) - 4);
         goto end_parse;
       }
   }

 vt := vt_batch (100, 'x-any', 'UTF-8');
 vt_batch_feed (vt, exp, 0, 0);

 war := vt_batch_strings_array (vt);

 m := length (war);
 n := 0;
 exp1 := '(';
 while (n < m)
   {
     declare word1 varchar;
     if (war[n] not in ('AND', 'NOT', 'NEAR', 'OR')
	 and length (war[n]) > 1
	 and not vt_is_noise (war[n], 'utf-8', 'x-any'))
       {
         word1 := war[n];
         if (strchr (word1, '.') is not null or regexp_match ('[A-Za-z_][A-Za-z0-9_-]*', word1) is null)
	   word1 := concat ('"', word1, '"');
	 exp1 := concat (exp1, word1, ' OR ');
       }
     n := n + 2;
   }

 if (length (exp1) > 4)
   {
     exp1 := substring (exp1, 1, length (exp1) - 4);
     exp1 := concat (exp1, ')');
   }
 else
   exp1 := null;

end_parse:
  return exp1;
}
;



--
-- BLOGGER SERVER HANDLERS
--

-- XML-RPC interface

create
procedure "blogger_auth" (in req "blogRequest")
{
  declare authenticated int;
  authenticated := 0;
  if (__proc_exists ('authenticate_' || req.appkey))
    {
      call ('authenticate_' || req.appkey) (req);
      return;
    }
  else
    {
      declare hdr varchar;
      hdr := http_request_header (http_request_header (), 'X-Virt-BlogID');
      set isolation = 'committed';
      declare pwd varchar;
      declare id int;
      whenever not found goto nf;
      select U_PWD, U_ID into pwd, id from WS.WS.SYS_DAV_USER where U_NAME = req.user_name with (prefetch 1);
      if (isstring (pwd))
  {
    if ((pwd[0] = 0 and pwd_magic_calc (req.user_name, req.passwd) = pwd)
                              or (pwd[0] <> 0 and pwd = req.passwd))
            {
	      declare own, home, inst_name any;
        declare bid varchar;
        own := null; home := null; bid := null;
        if (isstring (req.blogid))
    {
		  select BI_HOME, BI_OWNER, BI_WAI_NAME into home, own, inst_name from SYS_BLOG_INFO where BI_BLOG_ID = req.blogid with (prefetch 1);
      bid := req.blogid;
    }
              else if (isstring (req.postId))
                {
      whenever not found goto nfpost;
		  select BI_HOME, BI_OWNER, BI_BLOG_ID, BI_WAI_NAME into home, own, bid, inst_name from SYS_BLOG_INFO, SYS_BLOGS
      where B_POST_ID = req.postId and BI_BLOG_ID = B_BLOG_ID with (prefetch 1);
		  req.blogid := bid;
      nfpost:;
    }
              if (own is not null)
    {
      req.blog_owner := own;
    }
        if (home is not null)
    {
      req.blog_lhome := home;
      req.blog_phome := http_physical_path_resolve (home);
    }
        if (own <> id and id <> http_dav_uid ())
    {
      declare dummy int;
		  if (not exists (select 1 from DB.DBA.WA_MEMBER where WAM_USER = id and WAM_INST = inst_name and WAM_MEMBER_TYPE = 2))
      select 1 into dummy from "DB"."DBA"."SYS_ROLE_GRANTS" where GI_SUPER = id and GI_SUB = own with (prefetch 1);
    }
              if (bid is not null and hdr = concat (registry_get ('WeblogServerID'), ';', bid))
    signal ('42000', 'Replica to same blog and server is not allowed');
        --update WS.WS.SYS_DAV_USER set U_LOGIN_TIME = now () where U_NAME = req.user_name;
              req.auth_userid := id;
              authenticated := 1;
            }
  }
      commit work;
    }
  if (authenticated)
    return;
nf:
  rollback work;
  signal ('42000', 'Access denied');
}
;


create
procedure "blogger.newPost" (
             in appkey varchar,
             in blogId varchar,
             in "username" varchar,
             in "password" varchar,
             in content nvarchar,
             in publish smallint,
             out postId varchar
            )
{
  declare req "blogRequest";
  req := new "blogRequest" ();

  req.appkey := appkey;
  req.user_name := "username";
  req.passwd := "password";
  req.blogId := blogId;
  req.content := blog_wide2utf (content);
  req.publish := publish;
  if (req.publish = 0)
    req.publish := 1;
  else if (req.publish = 1)
    req.publish := 2;
  "blogger_auth" (req);
  if (__proc_exists ('newPost_' || req.appkey))
    {
      call ('newPost_' || req.appkey) (req);
    }
  else
    {
      declare dummy, title any;
      if (length (trim (content)) = 0)
        signal ('22023', 'Empty posts are not allowed');
      req.postId := cast (sequence_next ('blogger.postid') as varchar);
      if (req.postId = '0') -- start from 1
        req.postId := cast (sequence_next ('blogger.postid') as varchar);
      dummy := null;
      title := BLOG_GET_TITLE (dummy, req.content);
      insert into SYS_BLOGS (B_APPKEY, B_BLOG_ID, B_CONTENT, B_POST_ID, B_USER_ID, B_TS, B_STATE, B_TITLE)
       values (req.appkey, req.blogid, req.content, req.postId, req.auth_userid, now (), req.publish, title);
    }
  postId := req.postId;
}
;

create
procedure "blogger.editPost" (
             in appkey varchar,
             in postId varchar,
             in "username" varchar,
             in "password" varchar,
             in content nvarchar,
             in publish smallint
            )
{
  declare req "blogRequest";
  req := new "blogRequest" ();

  req.appkey := appkey;
  req.user_name := "username";
  req.passwd := "password";
  req.postId := postId;
  req.content := blog_wide2utf (content);
  req.publish := publish;
  if (req.publish = 0)
    req.publish := 1;
  else if (req.publish = 1)
    req.publish := 2;
  "blogger_auth" (req);
  if (__proc_exists ('editPost_' || req.appkey))
    call ('editPost_' || req.appkey) (req);
  else
    {
      if (length (trim (content)) = 0)
        signal ('22023', 'Empty posts are not allowed');
      update SYS_BLOGS set B_CONTENT = req.content, B_STATE = req.publish where B_POST_ID = req.postId;
    }
  return soap_boolean (1);
}
;

create
procedure "blogger.deletePost" (
             in appkey varchar,
             in postId varchar,
             in "username" varchar,
             in "password" varchar,
             in publish smallint
            )
{
  declare req "blogRequest";
  req := new "blogRequest" ();

  req.appkey := appkey;
  req.user_name := "username";
  req.passwd := "password";
  req.postId := postId;
  req.publish := publish;

  "blogger_auth" (req);
  if (__proc_exists ('deletePost_' || req.appkey))
    call ('deletePost_' || req.appkey) (req);
  else
    delete from SYS_BLOGS where B_POST_ID = req.postId;
  return soap_boolean (1);
}
;

create
procedure "blogger.getPost" (
             in appkey varchar,
             in postId varchar,
             in "username" varchar,
             in "password" varchar
            )
{
  declare req "blogRequest";
  declare res "blogPost";
  req := new "blogRequest" ();

  req.appkey := appkey;
  req.user_name := "username";
  req.passwd := "password";
  req.postId := postId;

  "blogger_auth" (req);

  if (__proc_exists ('getPost_' || req.appkey))
    {
      res := call ('getPost_' || req.appkey) (req);
      return res;
    }
  else
    {
      set isolation = 'committed';
      declare content, datecreated, userid any;
      declare post "blogPost";

      whenever not found goto nf;
      select sprintf ('%s', blob_to_string (B_CONTENT)), B_TS, B_USER_ID into content, datecreated, userid
      from SYS_BLOGS where B_POST_ID = req.postId with (prefetch 1);

      post := new "blogPost" ();
      post.content := blog_utf2wide (content);
      post.dateCreated := datecreated;
      post."postid" := req.postId;
      post.userid := (select U_NAME from "DB"."DBA"."SYS_USERS" where U_ID = userid);
      return post;
nf:
      signal ('22023', 'Cannot find a post with Id = ' || req.postId);
    }
}
;

create
procedure "blogger.getRecentPosts" (
             in appkey varchar,
             in blogId varchar,
             in "username" varchar,
             in "password" varchar,
             in numberOfPosts int
            )
{
  declare req "blogRequest";
  declare res "blogPost";
  req := new "blogRequest" ();

  req.appkey := appkey;
  req.user_name := "username";
  req.passwd := "password";
  req.blogId := blogId;

  "blogger_auth" (req);
  if (__proc_exists ('getRecentPosts_' || req.appkey))
    {
      res := call ('getRecentPosts_' || req.appkey) (req, numberOfPosts);
      return res;
    }
  else
    {
      set isolation = 'committed';
      declare ret, elm any;
      declare post "blogPost";

      ret := vector ();
      for select B_CONTENT, B_TS, B_USER_ID, B_POST_ID
      from SYS_BLOGS where B_BLOG_ID = req.blogId order by B_TS desc do
       {
   post := new "blogPost" ();
   post.content := blog_utf2wide (sprintf ('%s', blob_to_string (B_CONTENT)));
   post.dateCreated := B_TS;
   post."postid" := B_POST_ID;
         post.userid := (select U_NAME from "DB"."DBA"."SYS_USERS" where U_ID = B_USER_ID);
   ret := vector_concat (ret, vector (post));
   numberOfPosts := numberOfPosts - 1;
   if (numberOfPosts <= 0)
     goto endg;
       }
    endg:
      return ret;
    }
}
;

--
-- blogger extensions
--
create
procedure "blogger.getUsersBlogs" (
             in appkey varchar,
             in "username" varchar,
             in "password" varchar
            )
{
  declare req "blogRequest";
  req := new "blogRequest" ();

  req.appkey := appkey;
  req.user_name := "username";
  req.passwd := "password";

  "blogger_auth" (req);
  if (__proc_exists ('getUsersBlogs_' || req.appkey))
    return call ('getUsersBlogs_' || req.appkey) (req);
  else
    {
      set isolation = 'committed';
      declare ret any;
      declare host, path, url varchar;
      ret := vector ();
      host := http_request_header (http_request_header (), 'Host', null);

      if (isstring (host) and strchr (host, ':') is null)
        {
          declare hp varchar;
          declare hpa any;
          hp := sys_connected_server_address ();
          hpa := split_and_decode (hp, 0, '\0\0:');
          host := host || ':' || hpa[1];
        }

      if (host is null)
        host := sys_connected_server_address ();

       -- own blogs
       for select BI_TITLE, BI_DEFAULT_PAGE, BI_HOME, BI_BLOG_ID from SYS_BLOG_INFO
  where BI_OWNER = req.auth_userid do
         {
           declare str any;
           url := 'http://' || host || BI_HOME;
           str := soap_box_structure ('url', url, 'blogid', BI_BLOG_ID, 'blogName', BI_TITLE);
           ret := vector_concat (ret, vector (str));
         }
  -- granted blogs
  for select BI_TITLE, BI_DEFAULT_PAGE, BI_HOME, BI_BLOG_ID from SYS_BLOG_INFO, "DB"."DBA"."SYS_ROLE_GRANTS"
    where BI_OWNER = GI_SUB and GI_SUPER = req.auth_userid do
   {
           declare str any;
           url := 'http://' || host || BI_HOME;
           str := soap_box_structure ('url', url, 'blogid', BI_BLOG_ID, 'blogName', BI_TITLE);
           ret := vector_concat (ret, vector (str));
   }

      return ret;
    }
}
;

create procedure
date_rfc1123 (in dt datetime)
{
  if (timezone (dt) is null)
    dt := dt_set_tz (dt, 0);
  return soap_print_box (dt, '', 1);
}
;

create procedure
date_iso8601 (in dt datetime)
{
  return soap_print_box (dt, '', 0);
}
;


create
procedure "blogger.getTemplate" (
             in appkey varchar,
         in blogId varchar,
             in "username" varchar,
             in "password" varchar,
         in templateType varchar
            )
{
  declare req "blogRequest";
  req := new "blogRequest" ();

  req.appkey := appkey;
  req.blogId := blogId;
  req.user_name := "username";
  req.passwd := "password";

  "blogger_auth" (req);

  if (__proc_exists ('getTemplate_' || req.appkey))
    return call ('getTemplate_' || req.appkey) (req);

  declare path, cont, nam varchar;
  if (lower (templateType) = 'main')
    nam := 'default.xsl';
  else
    nam := templateType || '_template.html';
  path := rtrim(req.blog_phome, '/') || '/' || nam;
  cont := (select blob_to_string (RES_CONTENT) from WS.WS.SYS_DAV_RES where RES_FULL_PATH = path);
  return cont;
}
;

create
procedure "blogger.setTemplate" (
             in appkey varchar,
         in blogId varchar,
             in "username" varchar,
             in "password" varchar,
         in template varchar,
         in templateType varchar
            )
{
  declare req "blogRequest";
  req := new "blogRequest" ();

  req.appkey := appkey;
  req.blogId := blogId;
  req.user_name := "username";
  req.passwd := "password";
  req.content := template;

  "blogger_auth" (req);

  if (__proc_exists ('setTemplate_' || req.appkey))
    return call ('setTemplate_' || req.appkey) (req);

  declare path, cont, perms, nam varchar;
  declare dav_uid, dav_grp varchar;

  if (req.blog_owner <> req.auth_userid)
    {
      dav_uid := http_dav_uid ();
      dav_grp := req.blog_owner;
      perms := '110110100N';
    }
  else
    {
      dav_uid := req.auth_userid;
      dav_grp := null;
      perms := '110100100N';
    }

  if (lower (templateType) = 'main')
    nam := 'default.xsl';
  else
    nam := templateType || '_template.html';
  path := rtrim(req.blog_phome, '/') || '/' || nam;
  DB.DBA.DAV_RES_UPLOAD (path, template, '', perms, dav_uid, dav_grp, req.user_name, req.passwd);
  return soap_boolean (1);
}
;

create
procedure "blogger.getUserInfo" (
             in appkey varchar,
             in "username" varchar,
             in "password" varchar
            )
{
  declare req "blogRequest";
  req := new "blogRequest" ();

  req.appkey := appkey;
  req.user_name := "username";
  req.passwd := "password";

  "blogger_auth" (req);
  if (__proc_exists ('getUserInfo_' || req.appkey))
    return call ('getUserInfo_' || req.appkey) (req);

  declare name, host, path, url, email varchar;
  host := http_request_header (http_request_header (), 'Host', null);
  path := coalesce (DB.DBA.USER_GET_OPTION (req.user_name, 'HOME'), '/DAV/');
  name := coalesce (DB.DBA.USER_GET_OPTION (req.user_name, 'FULL_NAME'), '');
  email := coalesce (DB.DBA.USER_GET_OPTION (req.user_name, 'E-MAIL'), '');
  url := 'http://' || host || path || 'blog';
  return soap_box_structure ('nickname',req.user_name,'userid',req.user_name,'url',url,'email',
                             email,'lastname',name,'firstname', '');
}
;


--
-- META WEBLOG
--

create procedure
"metaWeblog.newPost" (
    in blogid varchar,
    in "username" varchar,
    in "password" varchar,
    in struct BLOG.DBA."MTWeblogPost",
    in publish smallint)
returns varchar
{
  declare req "blogRequest";
  req := new "blogRequest" ();

  req.appkey := 'META_WEBLOG';
  req.user_name := "username";
  req.passwd := "password";
  req.blogId := blogid;
  req.struct := struct;
  req.publish := publish;
  if (req.publish = 0)
    req.publish := 1;
  else if (req.publish = 1)
    req.publish := 2;
  "blogger_auth" (req);
  if (__proc_exists ('newPost_' || req.appkey))
    call ('newPost_' || req.appkey) (req);
  else
    {
      declare cnt, title any;
      declare pings, cats any;
      req.postId := cast (sequence_next ('blogger.postid') as varchar);
      if (req.postId = '0') -- start from 1
        req.postId := cast (sequence_next ('blogger.postid') as varchar);

      if (struct.dateCreated is null)
        struct.dateCreated := now ();
      struct.postid := req.postId;
      struct.userid := req.user_name;
      cnt := blog_wide2utf (struct.description);
      pings := struct.mt_tb_ping_urls;
      cats := struct.categories;
      --struct.mt_tb_ping_urls := null;
      struct.description := null;

      if (length (trim (cnt)) = 0)
        signal ('22023', 'Empty posts are not allowed');

      foreach (varchar cat in cats) do
	{
	  declare category_id int;
	  whenever not found goto nextcat;
	  select MTC_ID into category_id from MTYPE_CATEGORIES where MTC_NAME = cat and MTC_BLOG_ID = req.blogid;
	  insert replacing MTYPE_BLOG_CATEGORY (MTB_CID , MTB_POST_ID, MTB_BLOG_ID, MTB_PRIMARY)
	      values (category_id, struct.postId, req.blogid, 0);
	  nextcat:;
	}

      title := BLOG_GET_TITLE (struct, cnt);
      insert into SYS_BLOGS (B_APPKEY, B_BLOG_ID, B_CONTENT, B_POST_ID, B_USER_ID, B_TS, B_META, B_STATE, B_TITLE)
      values (req.appkey, req.blogid,
        cnt, struct.postId, req.auth_userid, struct.dateCreated, struct, req.publish, title);
      struct.description := cnt;
      struct.mt_tb_ping_urls := pings;
      BLOG_SEND_TB_PINGS (struct);
    }
  return req.postId;
}
;

create procedure
"metaWeblog.editPost"
    (
    in postid varchar,
    in "username" varchar,
    in "password" varchar,
    in struct BLOG.DBA."MTWeblogPost",
    in publish smallint)
returns smallint
{
  declare req "blogRequest";
  req := new "blogRequest" ();
  req.appkey := 'META_WEBLOG';
  req.user_name := "username";
  req.passwd := "password";
  req.postId := postId;
  req.struct := struct;
  req.publish := publish;
  if (req.publish = 0)
    req.publish := 1;
  else if (req.publish = 1)
    req.publish := 2;
  "blogger_auth" (req);
  if (__proc_exists ('editPost_' || req.appkey))
    call ('editPost_' || req.appkey) (req);
  else
    {
      declare cnt, ts, userid, pings, cats, pub any;
      whenever not found goto nf;
      select B_TS, B_USER_ID, B_STATE into ts, userid, pub from SYS_BLOGS where B_POST_ID = req.postId;
      struct.postid := req.postId;
      struct.userid := (select U_NAME from "DB"."DBA"."SYS_USERS" where U_ID = userid);
      struct.dateCreated := ts;
      cnt := blog_wide2utf (struct.description);
      pings := struct.mt_tb_ping_urls;
      --struct.mt_tb_ping_urls := null;
      struct.description := null;
      if (length (trim (cnt)) = 0)
        signal ('22023', 'Empty posts are not allowed');
      cats := struct.categories;
      --dbg_obj_print (cats, req.publish);
      if (pub = 2 or req.publish = 1)
	{
      delete from MTYPE_BLOG_CATEGORY where MTB_BLOG_ID = req.blogid and MTB_POST_ID = req.postId;
	}
      foreach (varchar cat in cats) do
	{
	  declare category_id int;
	  whenever not found goto nextcat;
	  select MTC_ID into category_id from MTYPE_CATEGORIES where MTC_NAME = cat and MTC_BLOG_ID = req.blogid;
	  insert replacing MTYPE_BLOG_CATEGORY (MTB_CID , MTB_POST_ID, MTB_BLOG_ID, MTB_PRIMARY)
	      values (category_id, struct.postId, req.blogid, 0);
	  nextcat:;
	}
      update SYS_BLOGS
        set B_CONTENT = cnt, B_META = struct, B_STATE = req.publish
        where B_POST_ID = req.postId;
      struct.description := cnt;
      struct.mt_tb_ping_urls := pings;
      BLOG_SEND_TB_PINGS (struct);
      nf:;
    }
  return soap_boolean (1);
}
;

create procedure
BLOG_SEND_TB_PINGS (inout struct BLOG.DBA."MTWeblogPost")
{
  declare urls any;
  declare i, l int;
  declare post varchar;
  declare tit, url, exc, blog varchar;
  declare ss any;

  urls := struct.mt_tb_ping_urls;
  i := 0; l := length (urls);
  if (not l)
    goto ef;
  whenever not found goto ef;
  select 'http://' || BLOG_GET_HOST () || BI_HOME, BI_TITLE into url, blog from SYS_BLOG_INFO, SYS_BLOGS where BI_BLOG_ID = B_BLOG_ID and B_POST_ID = struct.postid;

  url := concat (url, '?id=', struct.postid);

  tit := struct.title;
  exc := case when struct.mt_excerpt is null or struct.mt_excerpt = '' then  substring (struct.description, 1, 125)  else struct.mt_excerpt end;

  commit work;

  ss := string_output ();
  http (sprintf ('url=%U&blog_name=%U', url, blog) ,ss);
  http ('&title=', ss);
  http_escape (tit, 8, ss);
  http ('&excerpt=', ss);
  http_escape (exc, 8, ss);

  --post := sprintf ('title=%U&url=%U&excerpt=%U&blog_name=%U', tit, url, exc, blog);
  post := string_output_string (ss);
  while (i < l)
    {
      {
        declare nuri, arr varchar;
        declare exit handler for sqlstate '*' { goto nexti; };
        arr := WS.WS.PARSE_URI (cast (urls[i] as varchar));
        if (lower(arr[0]) = 'http')
    {
            nuri := sprintf ('http://%s%s%s%s', arr[1], arr[2], case arr[4] when '' then '' else '?' end, arr[4]);
            http_get (nuri, null, 'POST', null, post);
          }
      }
      nexti:;
      i := i + 1;
    }
  ef:;
  return;
}
;

create procedure
BLOG_MAKE_TITLE (inout _content any)
{
  declare cont, tit, content varchar;
  declare xt any;

  content := blob_to_string (_content);
  cont := substring (content, 1, 50);

  xt := xml_tree_doc (xml_tree (content, 2, '', 'UTF-8'));
  tit := cast (xpath_eval ('//*[ text() != "" and not descendant::*[ text() != "" ] ]', xt, 1) as varchar);
  if (tit is null)
    {
      tit := regexp_match ('(<[^<])?+[^<]+(</?[^>]+>)?', content);
      if (tit is not null)
	tit := trim(regexp_replace (tit, '<[^>]+>', '', 1, null));
    }
  else
    {
      declare ss any;
      ss := string_output ();
      http_value (tit, null, ss);
      tit := string_output_string (ss);
    }
  if (tit is null)
    tit := regexp_match ('[^\\r\\n]+', content);
  if (tit is null)
    tit := cont;

  return substring (tit, 1, 512);
}
;

create procedure
BLOG_GET_TITLE (inout meta any, inout content any)
{
  declare m_title any;

  if (meta is not null and udt_instance_of (meta, 'BLOG.DBA.MTWeblogPost'))
    {
      declare _in BLOG.DBA."MTWeblogPost";
      _in := meta;
      m_title := _in.title;
    }
  else if (meta is not null and udt_instance_of (meta, 'DB.DBA.MTWeblogPost'))
    {
      declare _in DB.DBA."MTWeblogPost";
      _in := meta;
      m_title := _in.title;
    }

  if (meta is not null and length (m_title) > 0)
    return m_title;

  return BLOG_MAKE_TITLE (content);
}
;


create procedure
BLOG_GET_TEXT_TITLE (inout B_META any, inout B_CONTENT any)
{
  declare tit varchar;
  declare ntit nvarchar;
  tit := BLOG_GET_TITLE (B_META, B_CONTENT);
  if (iswidestring (tit))
    tit := blog_wide2utf (tit);
  ntit := xpath_eval ('string(//*)', xml_tree_doc (xml_tree (tit, 2, '', 'UTF-8')), 1);
  if (length (ntit))
    tit := blog_wide2utf(ntit);
  return tit;
}
;

create procedure
"metaWeblog.getPost"
    (
    in postid varchar,
    in "username" varchar,
    in "password" varchar
    )
returns any
{
  declare req "blogRequest";
  declare res "MWeblogPost";
  req := new "blogRequest" ();

  req.appkey := 'META_WEBLOG';
  req.user_name := "username";
  req.passwd := "password";
  req.postId := postId;

  "blogger_auth" (req);
  if (__proc_exists ('getPost_' || req.appkey))
    res := call ('getPost_' || req.appkey) (req);
  else
    {
      declare userid, content, dt any;
      whenever not found goto nf;
      select B_META, B_USER_ID, B_CONTENT, B_TS into res, userid, content, dt from SYS_BLOGS
             where B_POST_ID = req.postId;
      if (res is null)
        {
          res := new "MTWeblogPost" ();
          res.postid := req.postId;
          res.title := BLOG_MAKE_TITLE (content);
        }
      res.author := (select U_NAME from "DB"."DBA"."SYS_USERS" where U_ID = userid);
      res.userid := res.author;
      res.dateCreated := dt;
      res.title := blog_utf2wide (res.title);
      res.description := blog_utf2wide (blob_to_string (content));
      res.categories := (select DB..vector_agg(MTC_NAME) from MTYPE_BLOG_CATEGORY, MTYPE_CATEGORIES
      	where MTB_BLOG_ID = MTC_BLOG_ID and MTC_ID = MTB_CID and MTB_POST_ID = req.postId);
    }
  return res;
nf:
  signal ('22023', 'Cannot find a post with Id = ' || req.postId);
}
;

create
procedure "metaWeblog.getRecentPosts" (
             in blogId varchar,
             in "username" varchar,
             in "password" varchar,
             in numberOfPosts int
            )
{
  declare req "blogRequest";
  declare ret any;
  declare res "MTWeblogPost";
  req := new "blogRequest" ();

  req.appkey := 'META_WEBLOG';
  req.user_name := "username";
  req.passwd := "password";
  req.blogId := blogId;

  "blogger_auth" (req);
  if (__proc_exists ('getRecentPosts_' || req.appkey))
    {
      ret := call ('getRecentPosts_' || req.appkey) (req, numberOfPosts);
      return ret;
    }
  else
    {
      declare elm any;
      declare post "blogPost";

      ret := vector ();
      for select B_META, B_TS, B_USER_ID, B_POST_ID, B_CONTENT
      from SYS_BLOGS where B_BLOG_ID = req.blogId order by B_TS desc do
       {
         res := B_META;
         if (res is null)
           {
             res := new "MTWeblogPost" ();
             res.postid := B_POST_ID;
             res.title := BLOG_MAKE_TITLE (B_CONTENT);
           }
         res.userid := (select U_NAME from "DB"."DBA"."SYS_USERS" where U_ID = B_USER_ID);
         res.author := res.userid;
         res.dateCreated := B_TS;
         res.title := blog_utf2wide (res.title);
         res.description := blog_utf2wide (blob_to_string (B_CONTENT));
	 res.categories := (select DB..vector_agg(MTC_NAME) from MTYPE_BLOG_CATEGORY, MTYPE_CATEGORIES
	 where MTB_BLOG_ID = MTC_BLOG_ID and MTC_ID = MTB_CID and MTB_POST_ID = B_POST_ID);

	 -- kludge for enclosures
	 if (udt_is_available ('DB.DBA.MWeblogPost'))
	   {
	     res.enclosure := null;
	   }

         -- kludge for zempt
	 if (res.mt_convert_breaks = '')
	   res.mt_convert_breaks := null;
	 if (res.mt_excerpt = '')
	   res.mt_excerpt := null;
	 if (res.mt_text_more = '')
	   res.mt_text_more := null;
	 if (res.mt_keywords = '')
	   res.mt_keywords := null;
	 if (length (res.mt_tb_ping_urls) = 0)
	   res.mt_tb_ping_urls := null;

	 ret := vector_concat (ret, vector (res));
	   numberOfPosts := numberOfPosts - 1;
	 if (numberOfPosts <= 0)
	   goto endg;
       }
      endg:
      return ret;
    }
}
;

create procedure
"metaWeblog.getCategories"
    (
    in blogid varchar,
    in "username" varchar,
    in "password" varchar
    )
returns any
{
  declare req "blogRequest";
  declare res any;
  req := new "blogRequest" ();

  req.appkey := 'META_WEBLOG';
  req.user_name := "username";
  req.passwd := "password";
  req.blogId := blogid;

  "blogger_auth" (req);
  if (__proc_exists ('getCategories_' || req.appkey))
    return call ('getCategories_' || req.appkey) (req);
  else
    {
      res := vector ();
      for select MTC_ID, MTC_NAME from MTYPE_CATEGORIES where MTC_BLOG_ID = blogid do
         {
           declare url any;
           declare host varchar;
           host := BLOG_GET_HOST ();
           url := 'http://' || host || req.blog_phome;
           url := rtrim (url, '/');
           res := vector_concat (res,
    vector (soap_box_structure ('description',MTC_NAME,
    'htmlUrl', url || '/index.vsp?cat=' || cast (MTC_ID as varchar),
    'rssUrl', url || '/rss.xml?cat=' || cast (MTC_ID as varchar))));
         }
    }
  return res;
}
;

create procedure
"metaWeblog.newMediaObject"
    (
    in blogid varchar,
    in "username" varchar,
    in "password" varchar,
    in struct any
    )
returns any
{
  declare url, name, typ, cnt, host, rc, dav_grp, dav_uid any;
  declare req "blogRequest";
  declare res any;
  req := new "blogRequest" ();

  req.appkey := 'META_WEBLOG';
  req.user_name := "username";
  req.passwd := "password";
  req.blogId := blogid;

  "blogger_auth" (req);

  name := get_keyword ('name', struct);
  typ  := get_keyword ('type', struct);
  cnt  := get_keyword ('bits', struct);

  DB.DBA.DAV_MAKE_DIR (req.blog_phome || 'media/', req.blog_owner, null, '110100100R');
  dav_grp := http_nogroup_gid ();
  dav_uid := req.blog_owner;
  rc := DB.DBA.DAV_RES_UPLOAD (req.blog_phome || 'media/'||name, cnt, typ, '110100100R', dav_uid, dav_grp,
  	req.user_name, req.passwd);
  if (rc < 0)
    signal ('22023', DB.DBA.DAV_PERROR (rc));

  host := BLOG_GET_HOST ();
  url := 'http://' || host || req.blog_lhome || 'media/' || name;
  return soap_box_structure ('url', url);
}
;

--
-- BLOGGER CLIENT API
--

create procedure
blogger.new_Post (in uri varchar, in req "blogRequest", in content varchar)
{
  declare ret any;
  declare postid varchar;
  ret := DB.DBA.XMLRPC_CALL (uri, 'blogger.newPost',
         vector (req.appkey, req.blogid, req.user_name, req.passwd, content, soap_boolean (1))
   , req.header);
  ret := xml_tree_doc (ret);
  ret := xml_cut (xpath_eval ('//Param1', ret, 1));
  postid := soap_box_xml_entity_validating (ret, 'string');
  return postid;
}
;

create procedure
blogger.delete_Post (in uri varchar, in req "blogRequest")
{
  declare ret any;
  ret := DB.DBA.XMLRPC_CALL (uri, 'blogger.deletePost',
         vector (req.appkey, req.postId, req.user_name, req.passwd, soap_boolean (1))
   , req.header);
  return 1;
}
;

create procedure
blogger.edit_Post (in uri varchar, in req "blogRequest", in content varchar)
{
  declare ret any;
  ret := DB.DBA.XMLRPC_CALL (uri, 'blogger.editPost',
         vector (req.appkey, req.postId, req.user_name, req.passwd, content, soap_boolean (1))
   , req.header);
  return 1;
}
;

create procedure
blogger.get_Post (in uri varchar, in req "blogRequest")
{
  declare ret any;
  declare post any;
  ret := DB.DBA.XMLRPC_CALL (uri, 'blogger.getPost',
         vector (req.appkey, req.postId, req.user_name, req.passwd));
  ret := xml_tree_doc (ret);
  ret := xml_cut (xpath_eval ('//Param1', ret, 1));
  post := soap_box_xml_entity_validating (ret, '', 0, 'BLOG.DBA.blogPost');
  return post;
}
;

create procedure
blogger.get_Recent_Posts (in uri varchar, in req "blogRequest", in lim int)
{
  declare ret, xe, arr any;
  declare i, l int;
  declare post any;
  ret := DB.DBA.XMLRPC_CALL (uri, 'blogger.getRecentPosts',
         vector (req.appkey, req.blogid, req.user_name, req.passwd, lim));
  ret := xml_tree_doc (ret);
  xe := xpath_eval ('//Param1/item', ret, 0);
  arr := vector (); i := 0; l := length (xe);
  while (i < l)
    {
      ret := xml_cut (xe[i]);
      post := soap_box_xml_entity_validating (ret, '', 0, 'BLOG.DBA.blogPost');
      arr := vector_concat (arr, vector(post));
      i := i + 1;
    }
enf:
  return arr;
}
;

create procedure
blogger.get_Users_Blogs (in uri varchar, in req "blogRequest")
{
  declare ret, xe, arr any;
  declare i, l int;
  declare post any;
  commit work; -- VERY IMPORTANT TO AVOID DEADLOCK DURING SELF CALLING !!!
  ret := DB.DBA.XMLRPC_CALL (uri, 'blogger.getUsersBlogs',
         vector (req.appkey, req.user_name, req.passwd));
  ret := xml_tree_doc (ret);
  xe := xpath_eval ('//Param1/item', ret, 0);
  arr := vector (); i := 0; l := length (xe);
  while (i < l)
    {
      declare blogid, blogname, url varchar;
      ret := xml_cut (xe[i]);
      blogid := cast (xpath_eval ('//blogid/text()', ret, 1) as varchar);
      blogname := cast (xpath_eval ('//blogname/text()|//blogName/text()', ret, 1) as varchar);
      url := cast (xpath_eval ('//url/text()', ret, 1) as varchar);
      post := soap_box_structure ('blogid', blogid, 'blogname', blogname, 'url', url);
      arr := vector_concat (arr, vector(post));
      i := i + 1;
    }
enf:
  return arr;
}
;


create procedure
metaweblog.new_Post (in uri varchar, in req "blogRequest")
{
  declare ret any;
  declare postid varchar;
  ret := DB.DBA.XMLRPC_CALL (uri, 'metaWeblog.newPost',
         vector (req.blogid, req.user_name, req.passwd, req.struct, soap_boolean (1))
   , req.header);
  ret := xml_tree_doc (ret);
  ret := xml_cut (xpath_eval ('//Param1', ret, 1));
  postid := soap_box_xml_entity_validating (ret, 'string');
  return postid;
}
;

create procedure
metaweblog.edit_Post (in uri varchar, in req "blogRequest")
{
  declare ret any;
  ret := DB.DBA.XMLRPC_CALL (uri, 'metaWeblog.editPost',
         vector (req.postId, req.user_name, req.passwd, req.struct, soap_boolean (1))
   , req.header);
  return 1;
}
;

create procedure
metaweblog.get_Post (in uri varchar, in req "blogRequest")
{
  declare ret any;
  declare post any;
  ret := DB.DBA.XMLRPC_CALL (uri, 'metaWeblog.getPost',
         vector (req.postId, req.user_name, req.passwd));
  ret := xml_tree_doc (ret);
  ret := xml_cut (xpath_eval ('//Param1', ret, 1));
  post := soap_box_xml_entity_validating (ret, '', 0, 'BLOG.DBA.MWeblogPost');
  return post;
}
;

-- xmlStorageSystem API
create procedure
xmlStorageSystem.geterror (in code int)
{
  declare err any;
  declare ret varchar;
  err := vector (
    -1, 'The path (target of operation) is not valid',
    -2, 'The destination (path) is not valid',
    -3, 'Overwrite flag is not set and destination exists',
    -4, 'The target is resource, but source is collection (in copy move operations)',
    -5, 'Permissions are not valid',
    -6, 'uid is not valid',
    -7, 'gid is not valid',
    -8, 'Target is locked',
    -9, 'Destination is locked',
    -10, 'Property name is reserved (protected or private)',
    -11, 'Property does not exists',
    -12, 'Authentication failed',
    -13, 'Operation is forbidden (the authenticated user do not have a permissions for the action)',
    -14, 'the target type is not valid',
    -15, 'The umask is not valid',
    -16, 'The property already exists',
    -17, 'Invalid property value',
    -18, 'no such user',
    -19, 'no home directory'
    );
  ret := get_keyword (code, err, 'Misc.error');
  return ret;
}
;

create procedure
xmlStorageSystem.allextensions ()
{
  declare res any;
  res := vector ();
  for select T_EXT from WS.WS.SYS_DAV_RES_TYPES do
    {
      res := vector_concat (res, vector (T_EXT));
    }
  return res;
}
;

-- SOAP methods
create procedure
xmlStorageSystem."registerUser"
  (
  in email varchar,
  in name varchar,
  in "password" varchar,
  in clientPort integer,
  in userAgent varchar,
  in serialNumber varchar,
        out Result any
  )
{
  declare stat, msg, u_id any;
  if (not exists (select 1 from "DB"."DBA"."SYS_USERS" where U_NAME = email))
    {
      declare pwd, rc, rc1 any;
      declare exit handler for sqlstate '*'
        {
           rollback work;
           stat := 1;
           msg := __SQL_MESSAGE;
           goto errf;
        };
      u_id := DB.DBA.USER_CREATE (email, "password",
  vector ('E-MAIL', email, 'FULL_NAME', name, 'HOME', '/DAV/' || email || '/',
    'DAV_ENABLE' , 1, 'SQL_ENABLE', 0, 'clientPort', clientPort,
    'maxBytesPerUser', 41943040, 'maxFileSize', 1048576));
      pwd := (select pwd_magic_calc (U_NAME, U_PWD, 1) from WS.WS.SYS_DAV_USER where U_NAME = 'dav');
      rc := DB.DBA.DAV_COL_CREATE ('/DAV/' || email || '/', '110100000R', email, null, 'dav', pwd);
      rc1 := DB.DBA.DAV_COL_CREATE ('/DAV/' || email || '/blog/', '110100100R', email, null, 'dav', pwd);
      if (rc <= 0)
        signal ('.....', xmlStorageSystem.geterror (rc));
      if (rc1 <= 0)
        signal ('.....', xmlStorageSystem.geterror (rc1));
      stat := 0;
      msg := 'Welcome ' || name;
    }
  else
    {
      stat := 1;
      msg := 'Duplicate name for user.';
    }
errf:
  Result := soap_box_structure
  (
  'usernum', email,
  'flError', soap_boolean(stat),
  'message', msg
  );
}
;

create procedure xmlStorageSystem.authenticate (in name1 varchar, inout pwd1 varchar, out base varchar)
{
  declare pwd varchar;
  declare id int;
  whenever not found goto nf;
  select pwd_magic_calc (U_NAME, U_PWD, 1), U_ID into pwd, id from WS.WS.SYS_DAV_USER where U_NAME = name1;
  if (isstring (pwd))
    {
      if (md5 (pwd) = pwd1)
        {
          pwd1 := pwd;
          base := DB.DBA.USER_GET_OPTION (name1, 'HOME') || 'blog';
          return id;
        }
    }
  nf:
   return 0;
}
;

-- XXX: some parameters needed as max ....
create procedure
xmlStorageSystem."getServerCapabilities"
  (
  in email varchar,
  in "password" varchar,
        out Result any
  )
{
  declare base varchar;
  if (not xmlStorageSystem.authenticate (email, "password", base))
    {
      Result := soap_box_structure
      (
      'flError', soap_boolean(1),
      'message', 'Can\'t access because user does not exist or password is incorrect.'
      );
      return;
    }

  declare host varchar;
  declare quota, maxfs, maxt int;

  host := http_request_header (http_request_header (), 'Host', null);
  quota := coalesce ((select sum (length (RES_CONTENT)) from WS.WS.SYS_DAV_RES where
            RES_FULL_PATH like base || '%'), 0);

  maxfs := coalesce (DB.DBA.USER_GET_OPTION (email, 'maxFileSize'), 1048576);
  maxt := coalesce (DB.DBA.USER_GET_OPTION (email, 'maxBytesPerUser'), 41943040);

  Result := soap_box_structure
  (
        'community', vector (),
        'ctBytesInUse', quota,
  'flError', soap_boolean(0),
  'flSearchableCommunity', soap_boolean (0),
  'legalFileExtensions', xmlStorageSystem.allextensions (),
  'maxBytesPerUser', maxt,
  'maxFileSize', maxfs,
  'message', 'Nice to see you again',
  'minutesBetweenPings', 20,
  'staticUrls', vector (),
  'urlRankingsByPageReads', '',
  'weblogUpdates', null,
  'yourUpstreamFolderUrl', 'http://' || host || base || '/'
  );
}
;

create procedure
xmlStorageSystem."saveMultipleFiles"
  (
  in email varchar,
  in "password" varchar,
  in relativepathList any,
  in fileTextList any,
        out Result any
  )
{
  declare base varchar;
  declare own int;
  if (not (own := xmlStorageSystem.authenticate (email, "password", base)))
    {
      Result := soap_box_structure
      (
      'flError', soap_boolean(1),
      'message', 'Can\'t access because user does not exist or password is incorrect.'
      );
      return;
    }
  declare arr any;
  declare host, msg varchar;
  declare i, l, rc1 int;
  declare maxfs, maxt, quota int;

  host := http_request_header (http_request_header (), 'Host', null);
  arr := vector ();
  quota := (select sum (length (RES_CONTENT)) from WS.WS.SYS_DAV_RES where
            RES_FULL_PATH like base || '%');
  maxfs := coalesce (DB.DBA.USER_GET_OPTION (email, 'maxFileSize'), 1048576);
  maxt := coalesce (DB.DBA.USER_GET_OPTION (email, 'maxBytesPerUser'), 41943040);
  quota := maxt - quota;

  i := 0; l := length (relativepathList);
  rc1 := 0; msg := '';
  while (i < l)
    {
      declare rc int;
      declare pat any;
      declare rel, cont varchar;

      rel := relativepathList[i];
      if (rel not like '/%')
        rel := '/' || rel;

      cont := fileTextList[i];

      quota := quota - length (cont);
      if (length (cont) > maxfs or quota < 0)
        {
          rc1 := 1;
          msg := 'Storage limit exceeded.';
          arr := vector_concat (arr, vector (''));
          goto nextf;
        }

      -- TODO: make such thing in DAV API !
      pat := WS.WS.PARENT_PATH (WS.WS.HREF_TO_ARRAY (
           substring (base || rel, 5, length (base || rel)), ''
  ));
      WS.WS.MKPATH (pat, own, null, '110100100N');
      rc := DB.DBA.DAV_RES_UPLOAD (base || rel, cont, '', '110100100N',
    email, null, email, "password");
      if (rc < 0)
        {
          rc1 := 1;
          msg := xmlStorageSystem.geterror (rc);
        }
      else
        arr := vector_concat (arr, vector ('http://' || host || base || rel));
      nextf:
      i := i + 1;
    }

  Result := soap_box_structure
  (
  'flError', soap_boolean(rc1),
  'message', msg,
        'urllist', arr,
  'yourUpstreamFolderUrl', 'http://' || host || base || '/'
  );
}
;

create procedure
xmlStorageSystem."deleteMultipleFiles"
  (
  in email varchar,
  in "password" varchar,
  in relativepathList any,
        out Result any
  )
{
  declare base varchar;
  declare own int;
  if (not (own := xmlStorageSystem.authenticate (email, "password", base)))
    {
      Result := soap_box_structure
      (
      'flError', soap_boolean(1),
      'message', 'Can\'t access because user does not exist or password is incorrect.'
      );
      return;
    }

  declare arr any;
  declare host varchar;
  declare i, l int;

  arr := vector ();

  i := 0; l := length (relativepathList);
  while (i < l)
    {
      declare rc int;
      declare rel varchar;

      rel := relativepathList[i];
      if (rel not like '/%')
        rel := '/' || rel;

      rc := DB.DBA.DAV_DELETE (base || rel, 0, email, "password");
      if (rc <> 1)
        arr := vector_concat (arr, vector (sprintf ('%s: %s', rel, xmlStorageSystem.geterror (rc))));
      else
        arr := vector_concat (arr, vector (''));
      i := i + 1;
    }

  Result := soap_box_structure
  (
  'flError', soap_boolean(0),
  'message', '',
        'errorList', arr
  );
}
;

-- obsoleted
create procedure
xmlStorageSystem."getMyDirectory"
  (
  in email varchar,
  in "password" varchar,
        out Result any
  )
{
  declare base, host varchar;
  declare own int;
  declare arr any;
  declare i int;

  if (not (own := xmlStorageSystem.authenticate (email, "password", base)))
    {
      Result := soap_box_structure
      (
      'flError', soap_boolean(1),
      'message', 'Can\'t access because user does not exist or password is incorrect.'
      );
      return;
    }

  host := http_request_header (http_request_header (), 'Host', null);
  arr := vector (composite(), '<soap_box_structure>');
  for select RES_FULL_PATH, length (RES_CONTENT) as RES_LEN,
  RES_CR_TIME, RES_MOD_TIME from WS.WS.SYS_DAV_RES where RES_OWNER = own and RES_FULL_PATH like base || '%'
   do
    {
      declare elm any;
      declare rel, url varchar;
      url := 'http://' || host || RES_FULL_PATH;
      rel := substring (RES_FULL_PATH, length (base) + 1, length (RES_FULL_PATH));
      i := i + 1;
      elm := soap_box_structure ('relativePath', rel, 'size', RES_LEN, 'url', url, 'whenCreated', RES_CR_TIME, 'whenLastUploaded', RES_MOD_TIME);
      arr := vector_concat (arr, vector (sprintf ('file%05d',i), elm));
    }
  if (i = 0)
    arr := soap_box_structure ();
  Result := soap_box_structure
  (
        'directory', arr,
  'flError', soap_boolean(0),
  'message', '',
  'yourUpstreamFolderUrl', 'http://' || host || base || '/'
  );
}
;


create procedure
xmlStorageSystem."mailPasswordToUser"
  (
  in email varchar,
        out Result any
  )
{
  declare base, host, wmast, oeml varchar;
  declare own int;
  declare arr, pwd any;

  declare exit handler for sqlstate '*' {
     rollback work;
      Result := soap_box_structure
      (
      'flError', soap_boolean(1),
      'message', 'Mail service is not available on that server.'
      );
     return;
  };
  whenever not found goto ef;
  select pwd_magic_calc (U_NAME, U_PASSWORD, 1), U_E_MAIL into pwd, oeml from "DB"."DBA"."SYS_USERS"
  where U_NAME = email;
  wmast := coalesce ((select U_E_MAIL from "DB"."DBA"."SYS_USERS"
  where U_ID = http_dav_uid ()), 'webmaster@example.domain');
  smtp_send (null, wmast, oeml, 'The password for user '||email||' is ' ||pwd|| '.');
  ef:
  Result := soap_box_structure
  (
  'flError', soap_boolean(0),
  'message', ''
  );
}
;

create procedure
xmlStorageSystem."requestNotification"
  (
  in notifyProcedure varchar,
  in port integer,
  in path varchar,
  in protocol varchar,
  in urlList any,
  in userinfo any,
        out Result any
  )
{
  declare i, l, rc int;
  declare url, msg varchar;

  if (protocol not in ('soap', 'xml-rpc'))
    {
      rc := 1;
      msg := 'Not valid protocol identifier';
      goto endf;
    }

  i := 0; l := length (urlList); rc := 0;

  url := sprintf ('http://%s:%d%s', http_client_ip (), port, path);
  while (i < l)
    {
      declare hinfo, bid, pdir any;
      hinfo := WS.WS.PARSE_URI (urlList[i]);
      bid := (select top 1 BI_BLOG_ID from SYS_BLOG_INFO where
  BI_HOME = substring (hinfo[2], 1, length (BI_HOME)) order by length (BI_HOME) desc);
      if (bid is null)
  {
    rollback work;
    rc := 1;
    msg := 'Not valid url';
    goto endf;
  }
      insert replacing SYS_BLOG_CLOUD_NOTIFICATION
  (BCN_URL, BCN_BLOG_ID, BCN_TS, BCN_PROTO, BCN_METHOD, BCN_USER_DATA)
  values (url, bid, now (), protocol, notifyProcedure, userinfo);
      i := i + 1;
    }
endf:
  Result := soap_box_structure
  (
  'flError', soap_boolean(rc),
  'message', msg
  );
}
;

create procedure
xmlStorageSystem."ping"
  (
  in email varchar,
  in "password" varchar,
  in status integer,
  in clientPort integer,
  in userinfo any,
        out Result any
  )
{
  declare base varchar;
  declare own int;
  if (not (own := xmlStorageSystem.authenticate (email, "password", base)))
    {
      Result := soap_box_structure
      (
      'flError', soap_boolean(1),
      'message', 'Can\'t access because user does not exist or password is incorrect.'
      );
      return;
    }
  declare host varchar;
  host := http_request_header (http_request_header (), 'Host', null);
  Result := soap_box_structure
  (
  'flError', soap_boolean(0),
  'message', '',
  'yourUpstreamFolderUrl', 'http://' || host || base || '/'
  );
}
;

grant execute on xmlStorageSystem."registerUser" to DBA
;

grant execute on xmlStorageSystem."getServerCapabilities" to DBA
;

grant execute on xmlStorageSystem."saveMultipleFiles" to DBA
;

grant execute on xmlStorageSystem."deleteMultipleFiles" to DBA
;

grant execute on xmlStorageSystem."getMyDirectory" to DBA
;

grant execute on xmlStorageSystem."mailPasswordToUser" to DBA
;

grant execute on xmlStorageSystem."requestNotification" to DBA
;

grant execute on xmlStorageSystem."ping" to DBA
;

-- XXX: this is obsoleted
--struct xmlStorageSystem.rssPleaseNotify (notifyProcedure, port, path, protocol, urlList)

--
-- XML-RPC wrappers
-- they needed because in XML-RPC method contains the prefix, just like user owner
--
create procedure
BLOG.DBA."xmlStorageSystem.registerUser"
  (
  in email varchar,
  in name varchar,
  in "password" varchar,
  in clientPort integer,
  in userAgent varchar,
  in serialNumber varchar,
        out Result any
  )
{
  xmlStorageSystem."registerUser" (email, name, "password", clientPort, userAgent, serialNumber, Result);
}
;

create procedure
BLOG.DBA."xmlStorageSystem.getServerCapabilities"
  (
  in email varchar,
  in "password" varchar,
        out Result any
  )
{
  xmlStorageSystem."getServerCapabilities" (email, "password", Result);
}
;

create procedure
BLOG.DBA."xmlStorageSystem.saveMultipleFiles"
  (
  in email varchar,
  in "password" varchar,
  in relativepathList any,
  in fileTextList any,
        out Result any
  )
{
  xmlStorageSystem."saveMultipleFiles" (email, "password", relativepathList, fileTextList, Result);
}
;

create procedure
BLOG.DBA."xmlStorageSystem.deleteMultipleFiles"
  (
  in email varchar,
  in "password" varchar,
  in relativepathList any,
        out Result any
  )
{
  xmlStorageSystem."deleteMultipleFiles" (email, "password", relativepathList, Result);
}
;

create procedure
BLOG.DBA."xmlStorageSystem.mailPasswordToUser"
  (
  in email varchar,
        out Result any
  )
{
  xmlStorageSystem."mailPasswordToUser" (email, Result);
}
;

create procedure
BLOG.DBA."xmlStorageSystem.requestNotification"
  (
  in notifyProcedure varchar,
  in port integer,
  in path varchar,
  in protocol varchar,
  in urlList any,
  in userinfo any,
        out Result any
  )
{
  xmlStorageSystem."requestNotification" (notifyProcedure, port, path, protocol, urlList, userinfo, Result);
}
;

create procedure
BLOG.DBA."xmlStorageSystem.ping"
  (
  in email varchar,
  in "password" varchar,
  in status integer,
  in clientPort integer,
  in userinfo any,
        out Result any
  )
{
  xmlStorageSystem."ping" (email, "password", status, clientPort, userinfo, Result);
}
;

--
-- Movable Type API
--

create procedure
"mt.supportedMethods" ()
{
    return vector (
    'blogger.newPost',
    'blogger.editPost',
    'blogger.deletePost',
    'blogger.getPost',
    'blogger.getRecentPosts',
    'blogger.getUsersBlogs',
    'blogger.getTemplate',
    'blogger.setTemplate',
    'blogger.getUserInfo',

    'metaWeblog.newPost',
    'metaWeblog.editPost',
    'metaWeblog.getPost',
    'metaWeblog.getRecentPosts',
    'metaWeblog.getCategories',
    'metaWeblog.newMediaObject',

    'mt.getRecentPostTitles',
    'mt.getCategoryList',
    'mt.setPostCategories',
    'mt.getPostCategories',
    'mt.getTrackbackPings',
    'mt.publishPost',
    'mt.supportedMethods',
    'mt.supportedTextFilters',

    'subsHarmonizer.setup',
    'subsHarmonizer.startup',
    'subsHarmonizer.subscribe',
    'subsHarmonizer.unsubscribe',

    'xmlStorageSystem.getServerCapabilities',
    'xmlStorageSystem.saveMultipleFiles',
    'xmlStorageSystem.deleteMultipleFiles',
    'xmlStorageSystem.getMyDirectory',
    'xmlStorageSystem.mailPasswordToUser',
    'xmlStorageSystem.requestNotification',
    'xmlStorageSystem.ping'

    );
}
;

create procedure "mt.supportedTextFilters" ()
{
  return vector (soap_box_structure ('key', '0', 'label', 'default'));
}
;

create procedure
"mt.getRecentPostTitles" (in blogid varchar, in "username" varchar, in "password" varchar, in numberOfPosts int)
{
  declare req "blogRequest";
  req := new "blogRequest" ();

  req.user_name := "username";
  req.passwd := "password";
  req.blogId := blogid;

  "blogger_auth" (req);
  {
    declare ret, elm any;
    declare post, userid, tit any;

    ret := vector ();
    for select B_CONTENT, B_TS, B_USER_ID, B_POST_ID, B_META
          from SYS_BLOGS where B_BLOG_ID = req.blogId order by B_TS desc do
     {
       tit := BLOG_GET_TEXT_TITLE (B_META, B_CONTENT);
       userid := (select U_NAME from "DB"."DBA"."SYS_USERS" where U_ID = B_USER_ID);

       post := soap_box_structure ('dateCreated', B_TS,'userid', userid,'postid', B_POST_ID, 'title', tit);

       ret := vector_concat (ret, vector (post));

       numberOfPosts := numberOfPosts - 1;
       if (numberOfPosts <= 0)
         goto endg;
     }
  endg:
    return ret;
  }
}
;

create procedure
"mt.getCategoryList" (in blogid varchar, in "username" varchar, in "password" varchar)
{
  declare req "blogRequest";
  req := new "blogRequest" ();

  req.user_name := "username";
  req.passwd := "password";
  req.blogId := blogid;

  "blogger_auth" (req);
  declare ret, post any;
  ret := vector ();
  for select MTC_ID, MTC_NAME from MTYPE_CATEGORIES where MTC_BLOG_ID = req.blogId do
    {
      post := soap_box_structure ('categoryId', MTC_ID, 'categoryName', MTC_NAME);
      ret := vector_concat (ret, vector (post));
    }
  -- Zempt kludge
  if (length(ret) = 0)
    ret := vector (soap_box_structure ('categoryId', '0', 'categoryName', 'default'));
  return ret;
}
;

create procedure
"mt.setPostCategories" (in postid varchar, in "username" varchar, in "password" varchar, in categories any)
{
  declare req "blogRequest";
  req := new "blogRequest" ();

  req.user_name := "username";
  req.passwd := "password";
  req.postId := postid;

  "blogger_auth" (req);

  declare i, l int;
  declare blogId varchar;
  declare meta BLOG.DBA."MWeblogPost";
  declare cats, cat_name any;

  whenever not found goto error_end;

  select B_BLOG_ID, B_META into blogId, meta from SYS_BLOGS where B_POST_ID  = postid;
  delete from MTYPE_BLOG_CATEGORY where MTB_BLOG_ID = blogId and MTB_POST_ID = postid;

  i := 0; l := length (categories); cats := vector ();
  while (i < l)
    {
      declare cat any;
      declare categoryId varchar;
      declare isPrimary int;

      cat := categories[i];
      categoryId := get_keyword ('categoryId', cat);
      isPrimary := get_keyword ('isPrimary', cat);
      whenever not found goto nextcat;
      select MTC_NAME into cat_name from MTYPE_CATEGORIES where MTC_ID = categoryId and MTC_BLOG_ID = blogId;

      insert replacing MTYPE_BLOG_CATEGORY (MTB_CID , MTB_POST_ID, MTB_BLOG_ID, MTB_PRIMARY)
       values (categoryId, postid, blogId, isPrimary);
      cats := vector_concat (cats, vector (cat_name));
      nextcat:
      i := i + 1;
    }
  if (length (cats) > 0)
    {
      meta.categories := cats;
      update SYS_BLOGS set B_META = meta where B_POST_ID  = postid;
    }
  return soap_boolean (1);
error_end:
  signal ('22023', sprintf ('No post with #%s', postid));
}
;

create procedure
"mt.getPostCategories" (in postid varchar, in "username" varchar, in "password" varchar)
{
  declare req "blogRequest";
  req := new "blogRequest" ();

  req.user_name := "username";
  req.passwd := "password";
  req.postId := postid;

  "blogger_auth" (req);
  declare ret, post any;
  ret := vector ();
  for select MTB_CID, MTC_NAME, coalesce (MTB_PRIMARY, 0) as MTB_PRIMARY from BLOG..MTYPE_BLOG_CATEGORY,
    BLOG..MTYPE_CATEGORIES where
      MTB_POST_ID = postid and MTB_CID = MTC_ID and MTC_BLOG_ID = MTB_BLOG_ID  do {
        post := soap_box_structure ('categoryName', MTC_NAME, 'categoryId', MTB_CID,
                                    'isPrimary', soap_boolean (MTB_PRIMARY));
        ret := vector_concat (ret, vector (post));
      }
  -- Zempt kludge
  if (length(ret) = 0)
    ret := vector (soap_box_structure ('categoryName','default', 'categoryId','0','isPrimary',soap_boolean (0)));
  return ret;
}
;

create procedure
"mt.getTrackbackPings" (in postid varchar)
{
  declare ret any;
  ret := vector ();
  for select MP_TITLE, MP_URL, MP_IP from MTYPE_TRACKBACK_PINGS where MP_POST_ID = postid
    do
  {
          declare stru any;
          stru := soap_box_structure ('pingTitle', MP_TITLE, 'pingURL', MP_URL, 'pingIP' , MP_IP);
          ret := vector_concat (ret, vector (stru));
  }
  return ret;
}
;

create procedure
"mt.publishPost" (in postid varchar, in "username" varchar, in "password" varchar)
{
  return soap_boolean (1);
}
;

-- DEFAULT BLOG SITE

create procedure
BLOG_UPLOAD_FILE (in f varchar, in dir varchar, in pwd any)
{
  declare cnt varchar;
  declare rc any;
  if (isstring (file_stat (http_root () || f)))
    {
      cnt := file_to_string (http_root () || f);
      if (not exists (select 1 from WS.WS.SYS_DAV_RES
      where RES_FULL_PATH = dir || f and md5(blob_to_string (RES_CONTENT)) = md5(cnt)))
  {
    rc := DB.DBA.DAV_MAKE_DIR (dir||f, http_dav_uid (), null, '110100100N');
    rc := DB.DBA.DAV_RES_UPLOAD_STRSES_INT (dir || f, cnt, '', '110100100N', http_dav_uid (), null, 'dav', pwd, 0);
    return rc;
  }
    }
  return 0;
}
;

create procedure
BLOG_GET_HOST ()
{
  declare ret varchar;
  declare default_host varchar;
  if (is_http_ctx ())
    {
      ret := http_request_header (http_request_header (), 'Host', null, sys_connected_server_address ());
      if (isstring (ret) and strchr (ret, ':') is null)
        {
          declare hp varchar;
          declare hpa any;
          hp := sys_connected_server_address ();
          hpa := split_and_decode (hp, 0, '\0\0:');
	  if (hpa[1] <> '80')
            ret := ret || ':' || hpa[1];
        }
    }
  else
   {
     default_host := cfg_item_value (virtuoso_ini_path (), 'URIQA', 'DefaultHost');
     if (default_host is not null)
       return default_host;
     ret := sys_stat ('st_host_name');
     if (server_http_port () <> '80')
       ret := ret ||':'|| server_http_port ();
   }

  return ret;
}
;

create procedure
BLOG_GET_HOME_DIR (inout home varchar)
{
  if (is_http_ctx ())
    {
      declare p varchar;
      p := http_path ();
      if (concat (home , 'gems/rss.xml') = p)
  return home;
      if (p like '%/gems/rss.xml')
        return substring (p, 1, length (p) - 12);
      else
        return home;
    }
  else
    return home;
}
;

create procedure
BLOG_TIDY_HTML (inout cnt any, in filter varchar := null)
{
  return BLOG_POST_RENDER (cnt, filter);
}
;

create procedure
BLOG_POST_RENDER (inout cnt any, in filter varchar := null, in owner int := null)
{
  declare ss any;
  declare xt any;
  declare davacc any;
  declare add_table int;

  add_table := 0;
  davacc := connection_get ('DAVUserID');
  ss := string_output ();
  xt := xml_tree_doc (xml_tree (cnt, 2, '', 'UTF-8'));
  xml_tree_doc_encoding (xt, 'utf-8');
  if (filter = '*default*')
    xt := xslt (BLOG2_GET_PPATH_URL ('widgets/blog_tidy.xsl'), xt);
  else if (isstring (filter) and filter <> '' and xslt_is_sheet (filter))
    xt := xslt (filter, xt);

  if (xpath_eval ('//tr[not ancestor::table]|//td[not ancestor::table]', xt) is not null)
    add_table := 1;

  xml_tree_doc_set_output (xt, 'xhtml');
  if (owner is null or xpath_eval ('[ xmlns:sql="urn:schemas-openlink-com:xml-sql" ] //sql:*', xt, 1) is null)
    {
      http_value (xt, null, ss);
    }
  else
   {
     declare dummy int;
     declare exit handler for sqlexception, not found
       {
   http_value (xt, null, ss);
   goto endprint;
       };

     select set_user_id (U_NAME, 1) into dummy from "DB"."DBA"."SYS_USERS" where U_ID = owner;
     connection_set ('DAVUserID', owner);
     xml_template (xt, null, ss);
   }
endprint:
  connection_set ('DAVUserID', davacc);
  if (add_table)
    return '<table>'||string_output_string (ss)||'</table>';
  else
    return string_output_string (ss);
}
;

create procedure BLOG_META_KWD_NORMALIZE (in str varchar)
  {
    declare tmp, part varchar;
    declare res varchar;
    tmp := cast (str as varchar);
    res := ''; part := null;
    while (1)
      {
  part := regexp_match ('[^\ ,;]+([\ \t][0-9\.]*[,;]*)*', tmp, 1);
  if (part is null)
    return rtrim (res, ', ');
  res := concat (res, rtrim (part, ', '), ', ');
      }
    return res;
  }
;



create procedure
BLOG_FEED_AGREGATOR (in rs int := 0)
{
   declare uri, format, tag varchar;
   declare rc, err int;
   declare bm any;
   declare cr static cursor for select BCD_CHANNEL_URI, BCD_FORMAT, BCD_TAG
  from SYS_BLOG_CHANNEL_INFO where (BCD_LAST_UPDATE is null
  or dateadd ('minute', BCD_UPDATE, BCD_LAST_UPDATE) < now ()) and BCD_ERROR_LOG is null;

   -- no longer supported in blog2
   return;

   if (rs)
     result_names (uri, rc);
   bm := null; err := 0;
   whenever not found goto enf;
   open cr (exclusive, prefetch 1);
   fetch cr first into uri, format, tag;
   while (1)
     {
       bm := bookmark (cr);
       err := 0;
       close cr;

       if (format in ('OCS', 'OPML'))
   {
           err := 1;
           goto next;
         }

       {
         declare exit handler for sqlstate '*' {
    rollback work;
                if (__SQL_STATE <> '40001')
      {
        update SYS_BLOG_CHANNEL_INFO set BCD_ERROR_LOG = __SQL_STATE || ' ' || __SQL_MESSAGE
      where BCD_CHANNEL_URI = uri;
                    commit work;
                  }
    else
      resignal;
                err := 1;
    goto next;
   };
         rc := BLOG.DBA.BLOG_FEED_URI (uri, format, tag);
   if (rs)
           result (uri, rc);
       }
       update SYS_BLOG_CHANNEL_INFO set BCD_LAST_UPDATE = now (), BCD_TAG = tag, BCD_ERROR_LOG = null
    where BCD_CHANNEL_URI = uri;
       commit work;
       next:
       open cr (exclusive, prefetch 1);
       fetch cr bookmark bm into uri, format, tag;
       if (err)
         fetch cr next into uri, format, tag;
     }
 enf:
  close cr;
  return;
}
;

create procedure
BLOG_FEED_URI (in uri varchar, in format varchar, inout tag varchar)
{
  declare content varchar;
  declare hdr any;
  declare xt any;
  declare items any;
  declare i, l int;
  declare new_tag, typef, olduri varchar;

  olduri := uri;
again:
  content := http_get (uri, hdr);

  if (hdr[0] not like 'HTTP/1._ 200 %')
    {
      if (hdr[0] like 'HTTP/1._ 30_ %')
  {
    uri := http_request_header (hdr, 'Location');
          if (isstring (uri))
      goto again;
  }
      signal ('22023', trim(hdr[0], '\r\n'), 'BLOG0');
      return 0;
    }

  new_tag := http_request_header (hdr, 'ETag');

  typef := http_request_header (hdr, 'Content-Type', null, 'text/xml');

  if (not isstring (new_tag))
    new_tag := md5 (content);

  if (new_tag = tag)
    return 0;

  tag := new_tag;

  BLOG_STORE_CHANNEL_FEED (olduri, content, typef);

  --return 0;

  -- get content-type, response; handle redirect; handle not found; handle not modified
  xt := xml_tree_doc (xml_tree (content));
  -- RSS formats
  if (xpath_eval ('/rss/channel/item|/RDF/item', xt) is not null)
    {
      items := xpath_eval ('/rss/channel/item|/RDF/item', xt, 0);
      i := 0; l := length (items);
      while (i < l)
        {
          BLOG_PROCESS_RSS_ITEM (xml_cut (items[i]), olduri);
          i := i + 1;
        }
    }
  else if (xpath_eval ('/feed/entry', xt) is not null)
    {
      items := xpath_eval ('/feed/entry', xt, 0);
      i := 0; l := length (items);
      while (i < l)
        {
          BLOG_PROCESS_ATOM_ITEM (xml_cut (items[i]), olduri);
          i := i + 1;
        }
    }
  return i;
}
;

create procedure BLOG_STORE_CHANNEL_FEED (in uri varchar, inout content any, in typef varchar,
            in target_folder varchar := null)
{
  declare suff, qs varchar;
  declare nfo any;

  nfo := WS.WS.PARSE_URI (uri);
  suff := 'rss_feeds/' || nfo[1] || nfo[2];
  if (nfo[4] <> '')
  {
      --declare i, l int;
      --qs := split_and_decode (nfo[4]);
      --i := 0; l := length (qs);
      --while (i < l)
      --  {
      --    if (qs[i+1] is not null)
      --      suff := suff || '/' || qs[i+1];
      --    else
      --      suff := suff || '/' || qs[i];
      --    i := i + 2;
      --  }
      suff := suff || '/' || DB.DBA.SYS_ALFANUM_NAME (nfo[4]);
    }
  if (target_folder is not null)
    {
      declare arr any;
      arr := WS.WS.HREF_TO_ARRAY (nfo[2], '');
      suff := 'rss_feeds/' || target_folder || '/' || arr [length (arr)-1];
    }
  if (typef <> 'text/xml')
    typef := http_mime_type (nfo[2]);
  for select BC_BLOG_ID as _BC_BLOG_ID, BI_P_HOME, BI_OWNER, BCD_TITLE from SYS_BLOG_CHANNELS, SYS_BLOG_INFO, SYS_BLOG_CHANNEL_INFO where BCD_CHANNEL_URI = BC_CHANNEL_URI and BC_CHANNEL_URI = uri and BI_BLOG_ID = BC_BLOG_ID do
     {
        declare pat, bid varchar;
    declare rc int;

        bid := _BC_BLOG_ID;
        pat := BI_P_HOME || suff;
  rc := DB.DBA.DAV_MAKE_DIR (pat, BI_OWNER, null, '110100100R');
        rc := DB.DBA.DAV_RES_UPLOAD_STRSES_INT (pat, content, typef, '110100100R', BI_OWNER, null, null, null, 0);
  rc := DB.DBA.BLOG2_DAV_PROP_SET (pat, 'displayName', BCD_TITLE, null, null, 0);
  rc := DB.DBA.BLOG2_DAV_PROP_SET (pat, 'sourceURL', uri, null, null, 0);
        update SYS_BLOG_CHANNELS set BC_LOCAL_RES = pat where BC_BLOG_ID = bid and BC_CHANNEL_URI = uri;
     }
}
;

create procedure
BLOG_PROCESS_RSS_ITEM (inout xt any, inout uri varchar)
{
  declare title, description, link, guid, pubdate varchar;
  declare nid int;
  declare comment_api, comment_rss varchar;
  title := serialize_to_UTF8_xml(xpath_eval ('string(/item/title)', xt, 1));
  description := serialize_to_UTF8_xml(xpath_eval ('string(/item/description)', xt, 1));
  link := cast (xpath_eval ('/item/link', xt, 1) as varchar);
  guid := cast (xpath_eval ('/item/guid', xt, 1) as varchar);
  pubdate := cast (xpath_eval ('/item/pubDate', xt, 1) as varchar);

  comment_api := cast (xpath_eval ('[ xmlns:wfw="http://wellformedweb.org/CommentAPI/" ] /item/wfw:comment', xt, 1) as varchar);
  comment_rss := cast (xpath_eval ('[ xmlns:wfw="http://wellformedweb.org/CommentAPI/" ] /item/wfw:commentRss', xt, 1) as varchar);

  if (guid is null)
    guid := link;

  if (exists (select 1 from SYS_BLOG_CHANNEL_FEEDS where CF_CHANNEL_URI = uri and CF_GUID = guid))
    return;

  nid := 0;
  for select top 1 CF_ID from SYS_BLOG_CHANNEL_FEEDS where CF_CHANNEL_URI = uri order by CF_ID desc for update do
     {
       nid := CF_ID;
     }
  nid := nid + 1;
  insert into SYS_BLOG_CHANNEL_FEEDS
  (CF_ID, CF_CHANNEL_URI, CF_TITLE, CF_DESCRIPTION, CF_LINK, CF_GUID, CF_PUBDATE, CF_COMMENT_API, CF_COMMENT_RSS)
  values
  (nid, uri, title, description, link, guid, now (), comment_api, comment_rss);
}
;

create procedure
BLOG_PROCESS_ATOM_ITEM (inout xt any, inout uri varchar)
{
  declare title, description, link, guid, pubdate varchar;
  declare nid int;
  declare comment_api, comment_rss varchar;

  title := cast (xpath_eval ('/entry/title', xt, 1) as varchar);
  description := cast (xpath_eval ('/entry/content', xt, 1) as varchar);
  link := cast (xpath_eval ('/entry/link[@rel="alternate"]/@href', xt, 1) as varchar);
  guid := cast (xpath_eval ('/entry/id', xt, 1) as varchar);
  pubdate := cast (xpath_eval ('/entry/created', xt, 1) as varchar);

  comment_api := NULL;
  comment_rss := NULL;

  if (guid is null)
    guid := link;

  if (exists (select 1 from SYS_BLOG_CHANNEL_FEEDS where CF_CHANNEL_URI = uri and CF_GUID = guid))
    return;

  nid := 0;
  for select top 1 CF_ID from SYS_BLOG_CHANNEL_FEEDS where CF_CHANNEL_URI = uri order by CF_ID desc for update do
     {
       nid := CF_ID;
     }
  nid := nid + 1;
  insert into SYS_BLOG_CHANNEL_FEEDS
  (CF_ID, CF_CHANNEL_URI, CF_TITLE, CF_DESCRIPTION, CF_LINK, CF_GUID, CF_PUBDATE, CF_COMMENT_API, CF_COMMENT_RSS)
  values
  (nid, uri, title, description, link, guid, now (), comment_api, comment_rss);
}
;


--insert soft "DB"."DBA"."SYS_SCHEDULED_EVENT" (SE_NAME, SE_START, SE_SQL, SE_INTERVAL)
--     values ('Weblog News aggregator', now(), 'BLOG.DBA.BLOG_FEED_AGREGATOR (0)', 10)
--;

delete from "DB"."DBA"."SYS_SCHEDULED_EVENT" where SE_NAME = 'Weblog Ping notifications';

blog2_exec_no_error ('drop procedure BLOG.DBA.BLOG_SEND_PINGS');

insert soft "DB"."DBA"."SYS_SCHEDULED_EVENT" (SE_NAME, SE_START, SE_SQL, SE_INTERVAL)
     values ('Weblog notifications', now(), 'BLOG.DBA.BLOG_SEND_NOTIFICATIONS ()', 10)
;

-- MAIL NOTIFICATION AND POP3 retrieval

create procedure BLOG_SEND_NOTIFICATIONS ()
{
  declare nw, last datetime;
  declare opts any;
  declare mailgw varchar;
  declare start_blog varchar;
  declare _BI_HOME, _BI_OWNER, _BI_BLOG_ID, _BI_TITLE, _BI_PINGS, _BI_OPTIONS, _U_NAME any;

  set isolation='committed';

  mailgw := '';
  start_blog := '';
  nw := now ();
  last := registry_get ('blogger.last.ping');
  if (isstring (last))
    {
      last := stringdate (last);
    }
  else
   {
     last := stringdate ('1970-01-01');
   }

  declare wmast, replyto, repltext varchar;

  wmast := coalesce ((select U_E_MAIL from "DB"."DBA"."SYS_USERS" where U_ID = http_dav_uid ()), 'webmaster@example.domain');

  commit work;


  whenever not found goto enf;
  while (1)
     {
       --dbg_obj_print ('pinging current blog: ', _BI_BLOG_ID, _U_NAME);
       select top 1 BI_HOME, BI_OWNER, BI_BLOG_ID, BI_TITLE, BI_PINGS, BI_OPTIONS, U_NAME
	   into
	   _BI_HOME, _BI_OWNER, _BI_BLOG_ID, _BI_TITLE, _BI_PINGS, _BI_OPTIONS, _U_NAME
	   from SYS_BLOG_INFO, "DB"."DBA"."SYS_USERS"
	   where U_ID = BI_OWNER and BI_BLOG_ID > start_blog order by BI_BLOG_ID with (prefetch 1);

       start_blog := _BI_BLOG_ID;

       declare pop3s, pop3u, pop3p varchar;

       opts := deserialize (blob_to_string (_BI_OPTIONS));

       if (not isarray (opts) or isstring (opts))
         opts := vector ();

       pop3s := get_keyword ('POP3Server', opts, '');
       pop3u := get_keyword ('POP3Account', opts, '');
       pop3p := get_keyword ('POP3Passwd', opts, '');

       BLOG_GET_MAIL_VIA_POP3 (pop3s, pop3u, pop3p, _U_NAME);
       commit work;
     }
  enf:
  --dbg_obj_print ('done');

  -- check the mail for comment API gateway
  {
       declare pop3s, pop3u, pop3p, _u_name1 varchar;
       _u_name1 := registry_get ('blogger.commentAPI.email');
       if (isstring (_u_name1) and exists (select 1 from WS.WS.SYS_DAV_USER where U_NAME = _u_name1))
         {
	   pop3s := DB.DBA.USER_GET_OPTION (_u_name1, 'POP3Server');
	   pop3u := DB.DBA.USER_GET_OPTION (_u_name1, 'POP3Account');
	   pop3p := DB.DBA.USER_GET_OPTION (_u_name1, 'POP3Passwd');
	   mailgw := DB.DBA.USER_GET_OPTION (_u_name1, 'E-MAIL');
	   BLOG_GET_MAIL_VIA_POP3 (pop3s, pop3u, pop3p, _u_name1);
	   commit work;
         }
  }
  delete from SYS_BLOG_CLOUD_NOTIFICATION where dateadd ('hour', 25, BCN_TS) < now ();
  commit work;
  for select BCN_URL, BCN_BLOG_ID, BCN_TS, BCN_PROTO, BCN_METHOD, BCN_USER_DATA
  from SYS_BLOG_CLOUD_NOTIFICATION do
     {
       if (exists (select 1 from SYS_BLOGS where B_BLOG_ID = BCN_BLOG_ID and B_TS > last))
	 {
	   declare exit handler for sqlstate '*' { goto next1; };
	   if (BCN_PROTO = 'xml-rpc')
	     DB.DBA.XMLRPC_CALL (BCN_URL, BCN_METHOD, vector (BCN_USER_DATA));
	   else if (BCN_PROTO = 'soap')
	     DB.DBA.SOAP_CLIENT (url=>BCN_URL, operation=>BCN_METHOD, parameters=>vector (), soap_action=>'');
	 }
       next1:;
     }
  replyto := '';
  if (mailgw <> '')
    {
      replyto := 'Reply-To:'||mailgw||'\r\n';
    }

  BLOG_SEND_EMAIL_NOTIFICATIONS (last, wmast, replyto);

  registry_set ('blogger.last.ping', datestring (nw));
  BLOG_SEND_TB_NOTIFY (wmast);
  return;
}
;

create procedure BLOG_SEND_EMAIL_NOTIFICATIONS (in last any, in wmast varchar, in replyto varchar)
{
  declare opts any;
  declare def_host varchar;
  declare BI_E_MAIL, BI_HOME, U_FULL_NAME, BM_E_MAIL, BM_POST_ID, BM_COMMENT, BM_POSTED_VIA, BM_NAME,
	  B_CONTENT, B_META, BI_OPTIONS, B_BLOG_ID, BI_COMMENTS_NOTIFY, BM_IS_SPAM, BM_IS_PUB, BM_ID, BI_BLOG_ID, BM_TS any;
  declare own_comment int;

  set isolation='committed';

  whenever not found goto enf;

  def_host :=  BLOG_GET_HOST ();

  while (1)
  {
    select top 1 bi.BI_E_MAIL, bi.BI_HOME, u.U_FULL_NAME, bc.BM_E_MAIL, bc.BM_POST_ID, bc.BM_COMMENT, bc.BM_POSTED_VIA, bc.BM_NAME,
	   b.B_CONTENT, b.B_META, bi.BI_OPTIONS, b.B_BLOG_ID, bi.BI_COMMENTS_NOTIFY, bc.BM_IS_SPAM, bc.BM_IS_PUB, bc.BM_ID,
	   bi.BI_BLOG_ID, bc.BM_TS, bc.BM_OWN_COMMENT
	       into
	       BI_E_MAIL, BI_HOME, U_FULL_NAME, BM_E_MAIL, BM_POST_ID, BM_COMMENT, BM_POSTED_VIA, BM_NAME, B_CONTENT,
	       B_META, BI_OPTIONS, B_BLOG_ID, BI_COMMENTS_NOTIFY, BM_IS_SPAM, BM_IS_PUB, BM_ID, BI_BLOG_ID, BM_TS,
	       own_comment
	       from
	       BLOG_COMMENTS bc, SYS_BLOG_INFO bi, SYS_BLOGS b, "DB"."DBA"."SYS_USERS" u where
	       bi.BI_COMMENTS_NOTIFY > 0 and bc.BM_BLOG_ID = bi.BI_BLOG_ID and bi.BI_OWNER = u.U_ID
	       and b.B_POST_ID = bc.BM_POST_ID and b.B_BLOG_ID = bi.BI_BLOG_ID
	       and bc.BM_TS > last order by bc.BM_TS option (order) with (prefetch 1);

    last := BM_TS;

    if (own_comment = 1)
      {
        goto next2;
      }

    --dbg_obj_print ('sending comment mail:', BI_BLOG_ID, BM_ID, BM_E_MAIL, BI_E_MAIL);

    declare exit handler for sqlstate '*' {
      log_message ('BLOG NF: '|| __SQL_MESSAGE);
      goto next2;
    };

    declare tit any;
    declare msg, p1, p2, p3 any;
    declare _mime_parts any;
    declare post_url, comment_url, tp, host, appr_url varchar;

    opts := deserialize (blob_to_string (BI_OPTIONS));

    if (not isarray (opts) or isstring (opts))
      opts := vector ();
    tit := BLOG_GET_TEXT_TITLE (B_META, B_CONTENT);
    tit := cast (tit as varchar);

    host := def_host;

    commit work;

    post_url := sprintf ('http://%s%s?id=%s', host, BI_HOME, BM_POST_ID);
    comment_url := sprintf ('http://%s/mt-tb/Http/comments?id=%s', host, BM_POST_ID);
    appr_url := sprintf ('http://%s/weblog/public/c_confirm.vspx?blogid=%U&postid=%U&commentid=%d', host, BI_BLOG_ID,
    BM_POST_ID, BM_ID);

  if (BI_COMMENTS_NOTIFY = 1)
    {
      _mime_parts := DB.DBA.MIME_PART ('text/html; charset=UTF-8', 'inline', null,
      BLOG_COMMENT_NF_HTML_FORM (post_url, comment_url, tit, U_FULL_NAME, BI_E_MAIL, BM_NAME, BM_E_MAIL, blob_to_string (BM_COMMENT), B_BLOG_ID, BM_POST_ID, BM_IS_PUB, BM_IS_SPAM, appr_url));
    }
  else if (BI_COMMENTS_NOTIFY = 2)
    {
      _mime_parts := DB.DBA.MIME_PART ('text/html; charset=UTF-8', 'inline', null,
      BLOG_COMMENT_NF_HTML (post_url, comment_url, tit, U_FULL_NAME, BI_E_MAIL, BM_NAME, BM_E_MAIL, blob_to_string (BM_COMMENT), B_BLOG_ID, BM_POST_ID, BM_IS_PUB, BM_IS_SPAM, appr_url));
    }
  else if (BI_COMMENTS_NOTIFY = 4)
    {
      declare part_txt, part_html, part_form any;
      part_txt := DB.DBA.MIME_PART ('text/plain; charset=UTF-8', null, null, BLOG_COMMENT_NF_TEXT (post_url, comment_url, tit, U_FULL_NAME, BI_E_MAIL, BM_NAME, BM_E_MAIL, blob_to_string (BM_COMMENT), B_BLOG_ID, BM_POST_ID, BM_IS_PUB, BM_IS_SPAM, appr_url));
      part_html := DB.DBA.MIME_PART ('text/html; charset=UTF-8', null, null, BLOG_COMMENT_NF_HTML (post_url, comment_url, tit, U_FULL_NAME, BI_E_MAIL, BM_NAME, BM_E_MAIL, blob_to_string (BM_COMMENT), B_BLOG_ID, BM_POST_ID, BM_IS_PUB, BM_IS_SPAM, appr_url));
      part_form := DB.DBA.MIME_PART ('text/html; charset=UTF-8', 'attachment', 'base64', BLOG_COMMENT_NF_FORM (post_url, comment_url, tit, U_FULL_NAME, BI_E_MAIL, BM_NAME, BM_E_MAIL, blob_to_string (BM_COMMENT), B_BLOG_ID, BM_POST_ID, BM_IS_PUB, BM_IS_SPAM, appr_url));
      _mime_parts := vector (part_txt, part_html, part_form);
    }
  else
    {
      _mime_parts := BLOG_COMMENT_NF_TEXT (post_url, comment_url, tit, U_FULL_NAME, BI_E_MAIL, BM_NAME, BM_E_MAIL, blob_to_string (BM_COMMENT), B_BLOG_ID, BM_POST_ID, BM_IS_PUB, BM_IS_SPAM, appr_url);
      replyto := concat (replyto, 'Content-Type: text/plain; charset=UTF-8\r\n');
    }

   msg := concat (replyto, BLOG_MAKE_MAIL_SUBJECT ('[Weblog notification] '||tit), DB.DBA.MIME_BODY (_mime_parts));
          smtp_send (null, wmast, BI_E_MAIL, msg);
   next2:;
  }
  enf:;
  --dbg_obj_print ('done.');
}
;

create procedure BLOG_GET_MAIL_VIA_POP3 (in pop3s varchar, in pop3u varchar, in pop3p varchar, in _u_name varchar)
  {
    if (pop3s <> '' and pop3u <> '' and pop3p <> '')
      {
      declare res any;
      declare inx, len, cert int;
      declare mess, elm any;
      declare exit handler for sqlstate '*' { goto nextu; };

      commit work;
      if (pop3s like '%:995')
	cert := 1;
      else
        cert := 0;	
      res := pop3_get (pop3s, pop3u, pop3p, 999999999, '', null, cert);

      inx := 0; len := length (res);
      while (inx < len)
	  {
	    mess := aref (aref (res, inx), 1);
	    elm := mail_header (mess, 'Message-Id');
	    if (not exists (select 1 from "DB"."DBA"."MAIL_MESSAGE" where MM_MSG_ID = elm and MM_OWN = _u_name))
	      {
		DB.DBA.NEW_MAIL (_u_name, mess);
		commit work;
	      }
	    inx := inx + 1;
	  }
      }
    nextu:;
    return;
  }
;

create procedure BLOG_SEND_TB_NOTIFY (in wmast varchar)
{
  declare nw, last datetime;
  declare opts any;
  declare mailgw varchar;
  declare def_host varchar;

  declare BI_E_MAIL, BI_HOME, U_FULL_NAME, MP_POST_ID, MP_EXCERPT, MP_URL, MP_TITLE, MP_BLOG_NAME, MP_VIA_DOMAIN, B_CONTENT, B_TITLE, B_BLOG_ID, MP_IS_SPAM, MP_IS_PUB, MP_TS any;

  def_host :=  BLOG_GET_HOST ();
  mailgw := '';
  nw := now ();
  last := registry_get ('blogger.last.tb_notification');
  if (isstring (last))
    {
      last := stringdate (last);
    }
  else
   {
     last := stringdate ('1970-01-01');
   }

  declare replyto, repltext varchar;

  set isolation='committed';

  whenever not found goto enf;
  while (1)
  {
    select top 1 bi.BI_E_MAIL, bi.BI_HOME, u.U_FULL_NAME, tb.MP_POST_ID, tb.MP_EXCERPT, tb.MP_URL,
	   tb.MP_TITLE, tb.MP_BLOG_NAME, tb.MP_VIA_DOMAIN,
	   b.B_CONTENT, b.B_TITLE, b.B_BLOG_ID, tb.MP_IS_SPAM, tb.MP_IS_PUB, tb.MP_TS
	       into
	       BI_E_MAIL, BI_HOME, U_FULL_NAME, MP_POST_ID, MP_EXCERPT, MP_URL, MP_TITLE, MP_BLOG_NAME, MP_VIA_DOMAIN,
	       B_CONTENT, B_TITLE, B_BLOG_ID, MP_IS_SPAM, MP_IS_PUB, MP_TS
	       from
	       SYS_BLOG_INFO bi, "DB"."DBA"."SYS_USERS" u, MTYPE_TRACKBACK_PINGS tb, SYS_BLOGS b where
	       b.B_POST_ID = tb.MP_POST_ID and b.B_BLOG_ID = bi.BI_BLOG_ID and
	       bi.BI_TB_NOTIFY > 0 and bi.BI_OWNER = u.U_ID
	       and tb.MP_TS > last order by tb.MP_TS with (prefetch 1);

    last := MP_TS;

    --dbg_obj_print ('tb:', MP_POST_ID, MP_TITLE);

    declare exit handler for sqlstate '*' {
          log_message ('BLOG NF: '|| __SQL_MESSAGE);
	  goto next2;
    };

    declare tit any;
    declare msg, p1, p2, p3 any;
    declare _mime_parts any;
    declare post_url, tb_url, tp, host varchar;

    MP_EXCERPT := blob_to_string (MP_EXCERPT);
    commit work;

    tit := cast (B_TITLE as varchar);

    host := def_host;

    post_url := sprintf ('http://%s%s?id=%s', host, BI_HOME, MP_POST_ID);
    tb_url := sprintf ('http://%s//mt-tb/Http/trackback?id=%s', host, MP_POST_ID);

      _mime_parts := DB.DBA.MIME_PART ('text/plain; charset=UTF-8', null, null,
                BLOG_TB_NF_TEXT (post_url, tb_url, tit, U_FULL_NAME, BI_E_MAIL, MP_BLOG_NAME, MP_URL,
                MP_EXCERPT, B_BLOG_ID, MP_POST_ID, MP_TITLE, MP_IS_PUB, MP_IS_SPAM, ''));

   replyto := '';
   msg := concat (replyto, BLOG_MAKE_MAIL_SUBJECT ('[Weblog trackback/pingback notification] '||tit),
          DB.DBA.MIME_BODY (_mime_parts));
   smtp_send (null, wmast, BI_E_MAIL, msg);
   next2:;
  }
  enf:
  --dbg_obj_print ('done tb');
  registry_set ('blogger.last.tb_notification', datestring (nw));
  return;
}
;


-- end of MAIL notification and POP3 retrieval

create procedure
BLOG_COMMENT_NF_HTML (
in post_url varchar,
in comment_url varchar,
in title varchar,
in b_name varchar,
in b_mail varchar,
in v_name varchar,
in v_mail varchar,
in comment_body varchar,
in blogid varchar,
in postid varchar,
in pub int,
in spam int,
in appr_url varchar
)
{
  declare ses any;
  ses := string_output ();
  http ('<html>\n', ses);
  http ('  <p>Your blog post\n', ses);
  http (sprintf ('  <a href="%s#comments">"%s"</a> has just been updated with a post from\n',post_url,title), ses);
  http (sprintf ('  <a href="mailto:%s">%s</a>.</p>\n',v_mail,v_name), ses);
  if (not pub)
    http ('<p>The comment was moderated and needs your approval.</p>', ses);
  else
    http ('<p>The comment was published on your blog.</p>', ses);
  if (spam)
    http ('<p>The comment was rated as a SPAM.</p>', ses);

  if (spam or not pub)
    {
      http (sprintf ('<p>To accept the comment click on following link : <a href="%s&action=accept">%s</a></p>',
	    appr_url, appr_url), ses);
      http (sprintf ('<p>To reject the comment click on following link : <a href="%s&action=delete">%s</a></p>',
	    appr_url, appr_url), ses);
      http (sprintf ('<p>To read the comment before approval click on following link : <a href="%s">%s</a></p>',
	    appr_url, appr_url), ses);
    }

  if (not spam)
    {
  http ('  <p>Comment Post Contents:</p>\n', ses);
  http ('  <div>', ses);
  http (comment_body, ses);
  http ('  </div>\n', ses);
    }
  if (pub)
    {
  http ('  <p>You can use the reply to this mail to directly update the blog\n', ses);
  http ('     comment thread by including the following line anywhere in this mail\'s\n', ses);
  http ('     reply body:<br />\n', ses);
  http (sprintf ('     @blogId@=%s @postId@=%s</p>\n',blogid,postid), ses);
    }
  http ('</html>\n', ses);
  return string_output_string (ses);
}
;

create procedure
BLOG_COMMENT_NF_HTML_FORM (
in post_url varchar,
in comment_url varchar,
in title varchar,
in b_name varchar,
in b_mail varchar,
in v_name varchar,
in v_mail varchar,
in comment_body varchar,
in blogid varchar,
in postid varchar,
in pub int,
in spam int,
in appr_url varchar
)
{
  declare ses any;
  ses := string_output ();
  http ('<html>\n', ses);
  http ('  <div>\n', ses);
  http ('      <p>Your blog post\n', ses);
  http (sprintf ('      <a href="%s#comments">"%s"</a> has just been updated with a post from\n',post_url,title), ses);
  http (sprintf ('      <a href="mailto:%s">%s</a>.</p>\n',v_mail,v_name), ses);
  if (not pub)
    http ('<p>The comment was moderated and needs your approval.</p>', ses);
  else
    http ('<p>The comment was published on your blog.</p>', ses);
  if (spam)
    http ('<p>The comment was rated as a SPAM.</p>', ses);

  if (spam or not pub)
    {
      http (sprintf ('<p>To accept the comment click on following link : <a href="%s&action=accept">%s</a></p>',
	    appr_url, appr_url), ses);
      http (sprintf ('<p>To reject the comment click on following link : <a href="%s&action=delete">%s</a></p>',
	    appr_url, appr_url), ses);
      http (sprintf ('<p>To read the comment before approval click on following link : <a href="%s">%s</a></p>',
	    appr_url, appr_url), ses);
    }

  if (not spam)
    {
  http ('      <p>Comment Post Contents:</p>\n', ses);
  http ('  <div>', ses);
  http (comment_body, ses);
  http ('  </div>\n', ses);
    }
  if (pub)
    {
  http ('      <p>You can post a reply to this Comment using the form below:<br /></p>\n', ses);
  http (sprintf ('    <form method="get" action="%s">\n       <input type="hidden" name="id" value="%s" />\n',
  comment_url, postid), ses);
  http ('      <table border="0">\n', ses);
  http ('        <tr>\n', ses);
  http ('          <td>Title:</td>\n', ses);
  http ('          <td>\n', ses);
  http (sprintf ('            <input type="text" name="title" value="Re: %s" size="63" />\n',title), ses);
  http ('          </td>\n', ses);
  http ('        </tr>\n', ses);
  http ('        <tr>\n', ses);
  http ('          <td>Author:</td>\n', ses);
  http ('          <td>\n', ses);
  http (sprintf ('            <input type="text" name="author" value="%s (%s)" size="63" />\n',b_name,b_mail), ses);
  http ('          </td>\n', ses);
  http ('        </tr>\n', ses);
  http ('        <tr>\n', ses);
  http ('          <td>Link:</td>\n', ses);
  http ('          <td>\n', ses);
  http (sprintf ('            <input type="text" name="link" value="%s" size="63" />\n',post_url), ses);
  http ('          </td>\n', ses);
  http ('        </tr>\n', ses);
  http ('        <tr>\n', ses);
  http ('          <td colspan="2">Comment:</td>\n', ses);
  http ('        </tr>\n', ses);
  http ('        <tr>\n', ses);
  http ('          <td colspan="2">\n', ses);
  http ('       <textarea name="description" rows="10" cols="60" ></textarea>\n', ses);
  http ('          </td>\n', ses);
  http ('        </tr>\n', ses);
  http ('        <tr>\n', ses);
  http ('          <td colspan="2">\n', ses);
  http ('            <input type="submit" name="post" value="Post" />\n', ses);
  http ('          </td>\n', ses);
  http ('        </tr>\n', ses);
  http ('      </table>\n', ses);
  http ('    </form>\n', ses);
  http ('  </div>\n', ses);
    }
  http ('</html>\n', ses);
  return string_output_string (ses);
}
;

create procedure
BLOG_COMMENT_NF_FORM (
in post_url varchar,
in comment_url varchar,
in title varchar,
in b_name varchar,
in b_mail varchar,
in v_name varchar,
in v_mail varchar,
in comment_body varchar,
in blogid varchar,
in postid varchar,
in pub int,
in spam int,
in appr_url varchar

)
{
  declare ses any;
  ses := string_output ();
  http (sprintf ('    <form method="post" action="%s">\n', comment_url), ses);
  http ('      <table border="0">\n', ses);
  http ('        <tr>\n', ses);
  http ('          <td>Title:</td>\n', ses);
  http ('          <td>\n', ses);
  http (sprintf ('            <input type="text" name="title" value="Re: %s" size="63" />\n',title), ses);
  http ('          </td>\n', ses);
  http ('        </tr>\n', ses);
  http ('        <tr>\n', ses);
  http ('          <td>Author:</td>\n', ses);
  http ('          <td>\n', ses);
  http (sprintf ('            <input type="text" name="author" value="%s (%s)" size="63" />\n',b_name,b_mail), ses);
  http ('          </td>\n', ses);
  http ('        </tr>\n', ses);
  http ('        <tr>\n', ses);
  http ('          <td>Link:</td>\n', ses);
  http ('          <td>\n', ses);
  http (sprintf ('            <input type="text" name="link" value="%s" size="63" />\n',post_url), ses);
  http ('          </td>\n', ses);
  http ('        </tr>\n', ses);
  http ('        <tr>\n', ses);
  http ('          <td colspan="2">Comment:</td>\n', ses);
  http ('        </tr>\n', ses);
  http ('        <tr>\n', ses);
  http ('          <td colspan="2">\n', ses);
  http ('       <textarea name="description" rows="10" cols="60" ></textarea>\n', ses);
  http ('          </td>\n', ses);
  http ('        </tr>\n', ses);
  http ('        <tr>\n', ses);
  http ('          <td colspan="2">\n', ses);
  http ('            <input type="submit" name="post" value="Post" />\n', ses);
  http ('          </td>\n', ses);
  http ('        </tr>\n', ses);
  http ('      </table>\n', ses);
  http ('    </form>\n', ses);
  return string_output_string (ses);
}
;


create procedure
BLOG_COMMENT_NF_TEXT (
in post_url varchar,
in comment_url varchar,
in title varchar,
in b_name varchar,
in b_mail varchar,
in v_name varchar,
in v_mail varchar,
in comment_body varchar,
in blogid varchar,
in postid varchar,
in pub int,
in spam int,
in appr_url varchar

)
{
  declare ses any;
  ses := string_output ();
  http (sprintf ('Your blog post "%s" (%s) has just been updated with a post from %s (%s) .\n',title,post_url,v_name,v_mail), ses);
  if (not pub)
    http ('The comment was moderated and needs your approval.\n', ses);
  else
    http ('The comment was published on your blog.\n', ses);
  if (spam)
    http ('The comment was rated as a SPAM.\n', ses);

  if (spam or not pub)
    {
      http (sprintf ('To accept the comment click on following link : %s&action=accept\n',
	    appr_url), ses);
      http (sprintf ('To reject the comment click on following link : %s&action=delete\n',
	    appr_url), ses);
      http (sprintf ('To read the comment before approval click on following link : %s\n',
	    appr_url), ses);
    }

  if (not spam)
    {
  http ('\nComment Post Contents:\n', ses);
  http ('\n', ses);
  http (comment_body, ses);
  http ('\n', ses);
  http ('\n', ses);
    }
  if (pub)
    {
  http ('You can use the reply to this mail to directly update the blog\n', ses);
  http ('comment thread by including the following line anywhere in this mail\'s\n', ses);
  http ('reply body:\n', ses);
  http (sprintf ('@blogId=%s@ @postId=%s@\n',blogid,postid), ses);
    }
  return string_output_string (ses);
}
;


create procedure
BLOG_TB_NF_TEXT (
in post_url varchar,
in tb_url varchar,
in title varchar,
in b_name varchar,
in b_mail varchar,
in v_name varchar,
in v_url varchar,
in tb_body varchar,
in blogid varchar,
in postid varchar,
in tb_tit varchar,
in pub int,
in spam int,
in appr_url varchar
)
{
  declare ses any;
  ses := string_output ();
  http (sprintf ('Your blog post "%s" (%s) has just been updated\r\n with a trackback/pingback from %s (%s) .\r\n',title,post_url,v_name,v_url), ses);
  if (not pub)
    http ('The trackback/pingback was moderated and needs your approval.\n', ses);
  else
    http ('The trackback/pingback was published on your blog.\n', ses);
  if (spam)
    http ('The trackback/pingback was rated as a SPAM.\n', ses);
  else if (not spam)
    {
  http ('\r\nTrackback Contents:\r\n', ses);
  http (tb_tit || '\r\n', ses);
  http ('\r\n', ses);
  http (tb_body, ses);
    }
  return string_output_string (ses);
}
;


create procedure
BLOG_USERS_BLOGS_P (IN URI VARCHAR, IN NAME VARCHAR, IN PASSWD VARCHAR)
{
  declare i, l int;
  declare blogid, blogname, url varchar;
  declare arr any;
  arr := blogger.get_Users_Blogs (uri, blogRequest ('appKey', '', '', name, passwd));
  i := 0; l := length (arr);
  result_names (blogid, blogname, url);
  while (i < l)
    {
      blogid := get_keyword ('blogid', arr[i]);
      blogname := get_keyword ('blogname', arr[i]);
      url := get_keyword ('url', arr[i]);
      result (blogid, blogname, url);
      i := i + 1;
    }
}
;

blog2_exec_no_error ('create procedure view BLOG_USERS_BLOGS as
  BLOG.DBA.BLOG_USERS_BLOGS_P (URI, NAME, PASSWD) (BLOGID VARCHAR, BLOGNAME VARCHAR, URL VARCHAR)')
;

insert soft "DB"."DBA"."SYS_SCHEDULED_EVENT" (SE_NAME, SE_START, SE_SQL, SE_INTERVAL)
     values ('Routing Jobs Queue', now(), 'BLOG.DBA.ROUTING_PROCESS_JOBS ()', 10)
;

create procedure ROUTING_PROCESS_JOBS()
{
  declare bm any;
  declare rc, err int;
  declare job_id, type_id, proto_id, dst, dst_id, a_usr, a_pwd, item_id, tag, eid, iid, send_delete, max_err any;
  declare n datetime;
  declare cr static cursor for select R_JOB_ID, R_TYPE_ID, R_PROTOCOL_ID,
    R_DESTINATION, R_DESTINATION_ID, R_AUTH_USER, R_AUTH_PWD, R_ITEM_ID, R_EXCEPTION_TAG, R_EXCEPTION_ID,
    R_INCLUSION_ID, R_KEEP_REMOTE, R_MAX_ERRORS
    from SYS_ROUTING where R_LAST_ROUND is null or dateadd ('minute', R_FREQUENCY, R_LAST_ROUND) < n;
  n := now ();
  bm := null; err := 0;
  whenever not found goto enf;
  open cr (exclusive, prefetch 1);
  fetch cr first into job_id, type_id, proto_id, dst, dst_id, a_usr, a_pwd, item_id, tag, eid, iid, send_delete, max_err;
  while (1)
  {
    bm := bookmark (cr);
    err := 0;
    close cr;
    {
      declare exit handler for sqlstate '*'
      {
        rollback work;
        if (__SQL_STATE = '40001')
          resignal;
        if (1) log_message (__SQL_STATE || ':' || __SQL_MESSAGE );
          err := 1;
        goto next;
      };
      send_delete := equ (send_delete, 0);
      commit work;
      if (type_id in (1, 2, 3))
      {
        if (dst is null or dst = '')
        {
          if ((select max(WS_USE_DEFAULT_SMTP) from DB.DBA.WA_SETTINGS) = 1)
            dst := cfg_item_value(virtuoso_ini_path(), 'HTTPServer', 'DefaultMailServer');
          else
            dst := (select max(WS_SMTP) from DB.DBA.WA_SETTINGS);
        }
	-- do the work only if max error is not reached or it's unlimited
	if (max_err > 0 or max_err = -1)
	  {
            rc := ROUTING_PROCESS_BLOGS (job_id, proto_id, dst, dst_id, a_usr, a_pwd, item_id, tag, eid, iid, send_delete);
	    if (rc <> 0 and max_err > 0)
	      max_err := max_err - 1;
	  }
      }
    }
    update SYS_ROUTING set R_LAST_ROUND = now (), R_MAX_ERRORS = max_err where R_JOB_ID = job_id;
    commit work;
    next:
    open cr (exclusive, prefetch 1);
    fetch cr bookmark bm into job_id, type_id, proto_id, dst, dst_id, a_usr, a_pwd, item_id, tag, eid, iid, send_delete, max_err;
    if (err)
      fetch cr next into job_id, type_id, proto_id, dst, dst_id, a_usr, a_pwd, item_id, tag, eid, iid, send_delete, max_err;
  }
  enf:
  close cr;
  return;
}
;

create procedure BLOG_DELICIOUS_ADD (in post_id varchar, in base any, in uid any, in pwd any)
{
  declare t_url, d_url, t_tags, t_desc, tim, tmp any;
  declare host, url, hdr, fnd any;


  fnd := 0;
  t_tags := '';

  for select BT_TAGS from BLOG..BLOG_TAG where BT_POST_ID = post_id do
    {
       fnd := 1;
       -- replace the space with + and remove trailing and leading quotes
       t_tags := BT_TAGS;
    }

  if (not fnd)
    goto nf;

  t_tags := trim (t_tags, ', ');
  t_tags := replace (t_tags, ',', ' ');

  whenever not found goto nf;

  select B_TITLE, B_MODIFIED into t_desc, tim from SYS_BLOGS where B_POST_ID = post_id;

  t_url := base || '?id=' || post_id;

  tim := dt_set_tz(tim, 0);

  d_url := sprintf('https://api.del.icio.us/v1/posts/add?url=%U&description=%U&extended=%U&tags=%U&dt=%U',
    t_url, t_desc, '', t_tags, date_iso8601 (tim));

  DB.DBA.HTTP_CLIENT_EXT (url=>d_url, uid=>uid, pwd=>pwd, http_method=>'POST', headers=>hdr);

  if (isarray (hdr) and length (hdr))
    {
      tmp := trim (hdr[0], '\r\n ');
      if (tmp not like 'HTTP/1._ 20_%')
  signal ('42000', tmp);
    }

  return t_url;

  nf:

  return null;

}
;

create procedure BLOG_DELICIOUS_DEL (in url any, in uid any, in pwd any)
{
  declare d_url, hdr, tmp any;
  if (url is null)
    return;
  d_url := sprintf('https://api.del.icio.us/v1/posts/delete?url=%U', url);
  DB.DBA.HTTP_CLIENT_EXT (url=>d_url, uid=>uid, pwd=>pwd, http_method=>'POST', headers=>hdr);
  if (isarray (hdr) and length (hdr))
    {
      tmp := trim (hdr[0], '\r\n ');
      if (tmp not like 'HTTP/1._ 20_%')
  signal ('42000', tmp);
    }
  return null;
}
;

create procedure
BLOG_MESSAGE_OR_META_DATA (in meta any, in uid int,
  in content any, in postid varchar, in tms datetime)
{
  if (meta is not null)
    {
      return meta;
    }
  declare res BLOG.DBA."MTWeblogPost";
  res := new BLOG.DBA."MTWeblogPost" ();
  res.userid := (select U_NAME from "DB"."DBA"."SYS_USERS" where U_ID = uid);
  res.description := blob_to_string (content);
  res.author := (select U_E_MAIL from "DB"."DBA"."SYS_USERS" where U_ID = uid);
  res.dateCreated := tms;
  res.mt_allow_pings := 0;
  res.mt_allow_comments := 0;
  res.postid := postid;
  return res;
}
;


create procedure
cell_fmt (in v any, in a any, in today any := null, in cal any := null)
{
  declare tod, real_tod, ret varchar;
  tod := null;
  real_tod := null;
  if (year(now()) = year(cal) and month(now()) = month(cal))
  {
    if (cast(v as varchar) = cast(dayofmonth(now()) as varchar))
    {
      real_tod := 'caltoday';
    }
  }
  if (today is not null and cal is not null)
  {
    if (year (cal) = year (today) and month(today) = month (cal))
    {
      tod := cast (dayofmonth (today) as varchar);
    }
  }
  if (tod = v and position (v,a))
    ret := 'calactive calselected';
  else if (tod = v and not position (v,a))
    ret := 'calnotactive calselected';
  else if ((tod = v or position (v,a)) and length(a) > 0)
    ret := 'calactive';
  else
    ret := 'calnotactive';
  if (real_tod is not null)
    return concat(ret, ' caltoday');
  else
    return ret;
}
;

create procedure BLOG..blog_date_fmt (in d datetime, in n int := null)
{
  declare tz int;
  declare s varchar;
  --d := dt_set_tz (d, 0);
  tz := 0; s := '';
  if (n is not null)
  {
    --d := dateadd ('hour', n, d);
    tz := abs(n);
    s := case when n < 0 then '-' when n >= 0 then '+' else '' end;
  }
  if (tz <> 0)
    return sprintf ('%02d/%02d/%04d %02d:%02d GMT%s%02d00',
  month(d), dayofmonth(d), year(d), hour(d), minute(d), s, tz);
  return sprintf ('%02d/%02d/%04d %02d:%02d GMT',
  month(d), dayofmonth(d), year(d), hour(d), minute(d));

}
;

create procedure BLOG_RSS_FEEDS_P (in blogid varchar, in uri varchar)
{
  declare CF_ID int;
  declare CF_CHANNEL_URI, CF_TITLE, CF_DESCRIPTION, CF_LINK, CF_GUID varchar;
  declare CF_PUBDATE datetime;
  result_names (CF_ID, CF_CHANNEL_URI, CF_TITLE, CF_DESCRIPTION, CF_LINK, CF_GUID, CF_PUBDATE);
  for select RES_CONTENT from WS.WS.SYS_DAV_RES, SYS_BLOG_CHANNELS where
  BC_BLOG_ID = blogid and BC_CHANNEL_URI = uri and BC_LOCAL_RES = RES_FULL_PATH do
    {
      declare xt, pc any;
      declare i, l int;

      xt := xml_tree_doc (xml_tree (RES_CONTENT));
      pc := xpath_eval ('/rss/channel/item|/RDF/item', xt, 0);
      i := 0; l := length (pc);
      while (i < l)
  {
    declare elm any;
    elm := xml_cut (pc[i]);
    CF_CHANNEL_URI := uri;
    CF_TITLE := cast (xpath_eval ('/item/title', elm, 1) as varchar);
    CF_DESCRIPTION := cast (xpath_eval ('/item/description', elm, 1) as varchar);
    CF_LINK := cast (xpath_eval ('/item/link', elm, 1) as varchar);
    CF_GUID := cast (xpath_eval ('/item/guid', elm, 1) as varchar);
          if (CF_GUID is null)
      CF_GUID := CF_LINK;
    CF_PUBDATE := cast (xpath_eval ('/item/pubDate', elm, 1) as varchar);
          result (i, CF_CHANNEL_URI, CF_TITLE, CF_DESCRIPTION, CF_LINK, CF_GUID, CF_PUBDATE);
    i := i + 1;
  }
    }
}
;

blog2_exec_no_error ('create procedure view BLOG_RSS_FEEDS as BLOG_RSS_FEEDS_P (BLOGID, URI)
  (CF_ID int,
  CF_CHANNEL_URI varchar,
  CF_TITLE varchar,
  CF_DESCRIPTION varchar,
  CF_LINK varchar,
  CF_GUID varchar,
  CF_PUBDATE varchar)
');


create procedure
blog_user_password_check (in name varchar, in pass varchar)
{
  declare rc int;
  rc := 0;
  if (exists (select 1 from "DB"."DBA"."SYS_USERS" where U_NAME = name and U_DAV_ENABLE = 1
  and U_IS_ROLE = 0 and pwd_magic_calc (U_NAME, U_PASSWORD, 1) = pass))
    {
      rc := 1;
    }
  commit work;
  return rc;
}
;


create procedure
WEBLOGUPDATES_COUNT ()
{
  declare cnt int;
  select count (*) into cnt from SYS_WEBLOG_UPDATES_PINGS;
  return cnt;
}
;

create procedure
WEBLOGUPDATES_WHEN (in t datetime, in w int := 1)
{
  declare d datetime;
  d := coalesce ((select top 1 WU_TS from SYS_WEBLOG_UPDATES_PINGS order by WU_TS desc), now ());
  if (w)
    return datediff ('second', t, d);
  else
    return d;
}
;

create procedure
"weblogUpdates.ping" (
      in weblogname varchar,
      in weblogurl varchar,
      in changesurl varchar := null,
      out Result any
         )
{
  declare stat int;
  declare msg varchar;
  stat := 0;
  msg := '';
  if (exists (select 1 from SYS_WEBLOG_UPDATES_PINGS where
  WU_URL = weblogurl and datediff ('minute', WU_TS, now ()) < 5 ))
    {
      stat := 1;
      msg := 'Pings must be sent in 5 minutes interval or greater.';
    }
  else
    {
      declare dummy varchar;
      declare exit handler for sqlstate '*' {
    msg := __SQL_MESSAGE;
    goto enf;
  };
      dummy := http_get (weblogurl);
      insert replacing SYS_WEBLOG_UPDATES_PINGS (WU_NAME, WU_URL, WU_TS, WU_IP, WU_CHANGES_URL)
	  values (weblogname, weblogurl, now (), http_client_ip (), changesurl);
    }
enf:
  Result := soap_box_structure
  (
  'flError', soap_boolean(stat),
  'message', msg
  );
}
;

create procedure
"weblogUpdates.extendedPing" (
      in weblogname varchar,
      in weblogurl varchar,
      in changesurl varchar := null,
      in rssUrl varchar,
      out Result any
         )
{
  declare stat int;
  declare msg varchar;
  stat := 0;
  msg := '';
  if (exists (select 1 from SYS_WEBLOG_UPDATES_PINGS where
  WU_URL = weblogurl and datediff ('minute', WU_TS, now ()) < 5 ))
    {
      stat := 1;
      msg := 'Pings must be sent in 5 minutes interval or greater.';
    }
  else
    {
      declare dummy varchar;
      declare exit handler for sqlstate '*' {
    msg := __SQL_MESSAGE;
    goto enf;
  };
      dummy := http_get (weblogurl);
      insert replacing SYS_WEBLOG_UPDATES_PINGS (WU_NAME, WU_URL, WU_TS, WU_IP, WU_CHANGES_URL, WU_RSS)
	  values (weblogname, weblogurl, now (), http_client_ip (), changesurl, rssUrl);
    }
enf:
  Result := soap_box_structure
  (
  'flError', soap_boolean(stat),
  'message', msg
  );
}
;

create procedure
subsharmonizer_get_blog (inout req "blogRequest")
{
  declare id varchar;
  whenever not found goto nf;
  select BI_BLOG_ID into id from SYS_BLOG_INFO where BI_OWNER = req.auth_userid;
  return id;
  nf:
  signal ('42000', 'Fatal, the authenticated user have no blogs associated.');
}
;

create procedure
subsharmonizer_add_channel (in blogid varchar, in url varchar)
{
  if (not exists (select 1 from BLOG..SYS_BLOG_CHANNEL_INFO where BCD_CHANNEL_URI = url))
    {
      declare cont varchar;
      declare xt, ct any;
      declare hp, proto any;
      declare tit, home varchar;
      declare format, upd_per, lang, src_uri, src_tit, dir_uri, chan_cat varchar;
      declare upd_freq integer;

      hp := WS.WS.PARSE_URI (url);
      proto := lower(hp[0]);

      if (proto <> 'http')
        cont := XML_URI_GET (url, '');
      else
       {
   declare ur, ou, hdr varchar;
         ur := url; ou := ur;
       try_again:
         cont := http_get (ur, hdr);
   if (hdr[0] like 'HTTP/1._ 30_ %')
           {
             ur := http_request_header (hdr, 'Location');
       if (ur <> ou)
         {
     ou := ur;
                 goto try_again;
         }
     }
       }

      {
  declare exit handler for sqlstate '*' { goto htmlp; };
  xt := xml_tree_doc (xml_tree (cont, 0));
  goto donep;
      }


     xt := xml_tree_doc (xml_tree (cont, 2));

     donep:;

     if (xpath_eval ('/rss|/RDF/channel', xt, 1) is not null)
       {
          xt := xml_cut (xpath_eval ('/rss/channel[1]|/RDF/channel[1]', xt, 1));
          tit := cast (xpath_eval ('/channel/title/text()', xt, 1) as varchar);
          home := cast (xpath_eval ('/channel/link/text()', xt, 1) as varchar);
          format := 'http://my.netscape.com/rdf/simple/0.9/';
          lang := cast (xpath_eval ('/channel/language/text()', xt, 1) as varchar);
          upd_per := 'hourly';
          upd_freq := 1;
        insert soft BLOG..SYS_BLOG_CHANNEL_INFO
         (BCD_CHANNEL_URI,BCD_TITLE, BCD_HOME_URI,BCD_FORMAT, BCD_UPDATE_PERIOD, BCD_LANG, BCD_UPDATE_FREQ)
   values (url, tit, home, format, upd_per, lang, upd_freq);
       }
     htmlp:;
    }
  if (exists (select 1 from BLOG..SYS_BLOG_CHANNEL_INFO where BCD_CHANNEL_URI = url))
    insert soft SYS_BLOG_CHANNELS (BC_BLOG_ID, BC_CHANNEL_URI) values (blogid, url);
}
;

create procedure
BLOG.DBA."subsHarmonizer.setup" (in "username" varchar, in "password" varchar,
         in "array" any __soap_type 'MWeblogPost:ArrayOfstring')
{
  declare req "blogRequest";
  declare blogid varchar;
  req := new "blogRequest" ();
  req.user_name := "username";
  req.passwd := "password";
  "blogger_auth" (req);
  blogid := subsharmonizer_get_blog (req);

  declare i, l int;
  i := 0; l := length ("array");
  while (i < l)
    {
      declare exit handler for sqlstate '*' { goto nextc; };
      subsharmonizer_add_channel (blogid, cast("array"[i] as varchar));
      nextc:
      i := i + 1;
    }
  return soap_boolean (0);
}
;


create procedure
BLOG.DBA."subsHarmonizer.subscribe" (in "username" varchar, in "password" varchar,
             in "array" any __soap_type 'MWeblogPost:ArrayOfstring')
{
  declare req "blogRequest";
  declare blogid varchar;
  req := new "blogRequest" ();
  req.user_name := "username";
  req.passwd := "password";
  "blogger_auth" (req);
  blogid := subsharmonizer_get_blog (req);
  declare i, l int;
  i := 0; l := length ("array");
  while (i < l)
    {
      subsharmonizer_add_channel (blogid, cast ("array"[i] as varchar));
      i := i + 1;
    }
  return soap_boolean (0);
}
;


create procedure
BLOG.DBA."subsHarmonizer.unsubscribe" (in "username" varchar, in "password" varchar,
               in "array" any __soap_type 'MWeblogPost:ArrayOfstring')
{
  declare req "blogRequest";
  declare blogid varchar;
  req := new "blogRequest" ();
  req.user_name := "username";
  req.passwd := "password";
  "blogger_auth" (req);
  blogid := subsharmonizer_get_blog (req);
  declare i, l int;
  i := 0; l := length ("array");
  while (i < l)
    {
      delete from SYS_BLOG_CHANNELS where BC_BLOG_ID = blogid and BC_CHANNEL_URI = cast("array"[i] as varchar);
      i := i + 1;
    }
  return soap_boolean (0);
}
;

create procedure
BLOG.DBA."subsHarmonizer.startup" (in "username" varchar, in "password" varchar)
__soap_type 'MWeblogPost:ArrayOfstring'
{
  declare req "blogRequest";
  declare blogid varchar;
  declare res any;

  req := new "blogRequest" ();
  req.user_name := "username";
  req.passwd := "password";
  "blogger_auth" (req);
  blogid := subsharmonizer_get_blog (req);
  res := vector ();
  for select BC_CHANNEL_URI from SYS_BLOG_CHANNELS where BC_BLOG_ID = blogid do
    {
      res := vector_concat (res, vector (BC_CHANNEL_URI));
    }
  return res;
}
;

create procedure
BLOG_GET_SUBJECT (in postid varchar, in blogid varchar)
{
  declare subj varchar;
  subj := '';
  for select MTC_NAME from MTYPE_CATEGORIES, MTYPE_BLOG_CATEGORY
  where MTB_CID = MTC_ID and MTC_BLOG_ID = MTB_BLOG_ID and MTB_POST_ID = postid and MTB_BLOG_ID = blogid do
    {
      subj := subj || MTC_NAME || ' ';
    }
  return trim (subj);
}
;

create procedure
BLOG_TAGS_RENDER (in _postid varchar, in _blogid varchar)
{
  declare ses any;
  ses := string_output ();
  for select BT_TAG from BLOG..BLOG_POST_TAGS_STAT_2 where blogid = _blogid and postid = _postid
    do
      {
	http_value (BT_TAG, 'category', ses);
      }
  return string_output_string (ses);
};

create procedure
BLOG_ENCLOSURE_RENDER (inout meta any)
{
  declare mt BLOG.DBA."MWeblogPost";
  declare enc BLOG.DBA."MWeblogEnclosure";
  mt := meta;
  if (meta is null or mt.enclosure is null)
    return '';
  enc := mt.enclosure;

  if (enc."length" < 1)
    return '';

  return sprintf ('<enclosure url="%V" length="%d" type="%s" />',
  enc.url,
  enc."length",
  enc."type"
  );

}
;

create procedure BLOG_REFFERAL_REGISTER (in blogid varchar, in lines any, in params any)
{
  declare postid, url, title any;
  url := http_request_header (lines, 'Referer');
  postid := get_keyword ('id', params);
  if (isstring (url) and exists (select 1 from SYS_BLOGS where B_BLOG_ID = blogid and B_POST_ID = postid))
    {
      declare hinfo any;
      hinfo := WS.WS.PARSE_URI (url);
      if (hinfo[0] = 'http' and hinfo[1] <> '' and hinfo [2] <> '')
  {
    url := 'http://' || hinfo[1] || hinfo [2];
          insert soft SYS_BLOG_REFFERALS (BR_BLOG_ID,BR_POST_ID,BR_URI) values (blogid, postid, url);
  }
    }
}
;

create procedure
BLOG_SET_OPTION (in name varchar, inout opts any, in value any)
{
  if (__tag (opts) <> 193)
    opts := vector ();
  if (position (name, opts))
    aset (opts, position (name, opts), value);
  else
    opts := vector_concat (opts, vector (name, value));
}
;


create procedure
BLOG_HTMLIZE_TEXT (in txt varchar) returns varchar
{
  declare inx, txt_len integer;
  inx := 0;
  txt_len := length (txt);
  while (inx < txt_len)
    {
      if (inx < txt_len - 4 and
    subseq (txt, inx, inx + 4) = '\r\n\r\n')
  {
     txt := concat (subseq (txt, 0, inx), '\r\n<p>\r\n', subseq (txt, inx + 4, txt_len));
     inx := inx + length ('\r\n<p>\r\n') - 1;
     txt_len := length (txt);
  }
      else if (inx < txt_len - 2 and
    subseq (txt, inx, inx + 2) = '\n\n')
  {
     txt := concat (subseq (txt, 0, inx), '\n<p>\n', subseq (txt, inx + 2, txt_len));
     inx := inx + length ('\n<p>\n') - 1;
     txt_len := length (txt);
  }
      else if (inx < txt_len - 2 and
    subseq (txt, inx, inx + 2) = '\r\n')
  {
     txt := concat (subseq (txt, 0, inx), '<br />\r\n', subseq (txt, inx + 2, txt_len));
     inx := inx + length ('\n<br />\n') - 1;
     txt_len := length (txt);
  }
      else if (inx < txt_len - 1 and
    subseq (txt, inx, inx + 1) = '\n')
  {
     txt := concat (subseq (txt, 0, inx), '<br />\n', subseq (txt, inx + 1, txt_len));
     inx := inx + length ('\n<br />\n') - 1;
     txt_len := length (txt);
  }
      inx := inx + 1;
    }
  return txt;
}
;


create procedure MOBBLOGGING_DISPLAY_MIME (inout doc varchar, inout ses varchar, in params any,
            inout parsed_message varchar, in msg varchar, in path varchar,
            in call_page varchar, in part integer, in do_update integer,
            inout file_name varchar, in changed_name varchar)
{
--no_c_escapes-
  declare path_part, body, attrs, parts, entry_path varchar;
  declare inx integer;

  entry_path := path;

  if (not isarray(parsed_message))
    return;

  attrs := aref (parsed_message, 0);
  body := aref (parsed_message, 1);
  parts := aref (parsed_message, 2);

  if (isarray (body))
    {
      if (aref (body, 1) > aref (body, 0))
        {
    declare body_submsg varchar;
          body_submsg := aref (body, 2);
          if (not isarray (body_submsg))
          {
            declare body_type, body_enc, body_file varchar;

            if (isarray (attrs))
              {
                  body_type := lcase (get_keyword_ucase ('Content-Type', attrs));
                  body_enc := lcase (get_keyword_ucase ('Content-Transfer-Encoding', attrs));
                  body_file := get_keyword_ucase ('filename', attrs);
        file_name := body_file;
              }
            else
              {
                body_type := null;
                body_enc := null;
              }
        if (length (body_type) = 0)
    body_type := 'text/plain';
        if (length (body_enc) = 0)
    body_enc := null;
        if (length (body_file) = 0)
    body_file := null;
        if (isnull (body_type))
    body_type := 'text/plain';
        if (subseq (body_type, 0, 9) = 'multipart')
    body_type := 'text/plain';
        if ((subseq (body_type, 0, 5) = 'image' and
          (subseq (body_type, 6, 9) = 'gif' or subseq (body_type, 6, 10) = 'jpeg'))
          or body_type = 'application/octet-stream')
    {
      if (body_file is null)
        body_file := concat ('body.', subseq (body_type, 5, length (body_type)));
      http ('<IMG src=\"/INLINEFILE/');
      http_url (body_file);
      http ('?VSP=');
      http_url (sprintf ('%s' ,call_page));
      http ('&msg=');
      http_url (doc);
      http ('&downloadpath=');
      http_url (concat (entry_path, '/d/', body_file));
      http ('&page=1');
      http ('&subj2=');
      http_url (get_keyword ('subj', params, ''));
      http ('&part=');
      http (cast (part as varchar));
      http ('&do_update=');
      http (cast (do_update as varchar));
      http ('&changed_name=');
      http_url (changed_name);
      http ('"></IMG>');
    }
      }
        }
      if (isarray (aref (body, 3)))
        {
    http_value (subseq (msg, aref (aref (body, 3), 0), aref (aref (body, 3), 1)), null, ses);
        }
    }
  if (isarray (parts))
    {
      inx := 0;
      while (inx < length (parts))
       {
   if (inx = part)
         MOBBLOGGING_DISPLAY_MIME (doc, ses, params, aref (parts, inx), msg,
                 sprintf ('%s/%d', path, inx), call_page, part,
           do_update, file_name, changed_name);
         inx := inx + 1;
       }
    }
}
;

create procedure BLOG_UPDATE_IMAGES_TO_USER_DIR (in uid int, in image_body varchar, in image_name varchar)
{
  declare nam, folder, ret varchar;
  declare dav_pwd any;
  whenever not found goto ef;
  select U_NAME into nam from "DB"."DBA"."SYS_USERS" where U_ID = uid;
  folder := '/DAV/'||nam||'/blog/images/';
  DB.DBA.DAV_MAKE_DIR (folder, http_dav_uid (), uid, '110110100N');

  ret := folder || image_name;
  DB.DBA.DAV_RES_UPLOAD_STRSES_INT (ret, image_body, '', '110100100N', uid, null, null, null, 0);
  ef:;
  return ret ;
}
;

create procedure BLOG_INSERT_MESSAGE (in _uid integer, in params any, in img_path varchar,
              in mime varchar := 'image/any')
{

  declare postId varchar;
  declare blogId varchar;
  declare bcont varchar;

  postId := cast (sequence_next ('blogger.postid') as varchar);
  if (postId = '0')
    postId := cast (sequence_next ('blogger.postid') as varchar);
  blogId := (select BI_BLOG_ID from SYS_BLOG_INFO where BI_OWNER = _uid);

  declare res "MTWeblogPost";

  res := new "MTWeblogPost" ();

  res.postid := postId;
  res.title := get_keyword ('subj2', params, '');
  res.author := (select U_NAME from "DB"."DBA"."SYS_USERS" where U_ID = _uid);
  res.userid := res.author;
  res.dateCreated := now ();
  if (mime like 'image/%')
    {
      bcont := '<div><a href="http://'||BLOG_GET_HOST ()|| img_path || '">' ||
      '<img src="http://'||BLOG_GET_HOST () || img_path || '" width="200" border="0" /></a></div><div><pre>'
      || get_keyword ('changed_name', params, '') || ' </pre></div>';
    }
  else
    {
      bcont := '<div><a href="http://'||BLOG_GET_HOST ()|| img_path || '">' ||
      res.title ||'</a></div><div><pre>'
      || get_keyword ('changed_name', params, '') || ' </pre></div>';
    }

  insert into SYS_BLOGS (B_APPKEY, B_BLOG_ID, B_CONTENT, B_POST_ID, B_USER_ID, B_TS, B_META, B_TITLE)
   values  ('', blogId, bcont, postId, _uid, now (), res, res.title);

}
;


create procedure MOBBLOGGING_IS_MOB_MESSAGE (in _msg any)
{
  declare parsed_message, parts, line any;
  declare idx, len, ret integer;

  parsed_message := mime_tree (_msg);
  if (isarray(parsed_message) and length(parsed_message) > 2)
    parts := aref (parsed_message, 2);
  else
    return 0;

  if (not isarray (parts))
    return 0;

  len := length (parts);
  idx := 0;
  ret := 0;

  while (idx < len)
    {
      line := parts[idx][0];
      if (isarray (line))
        {
    if ((get_keyword_ucase ('filename', line, '') <> '')
    and (get_keyword_ucase ('Content-Disposition', line, '') = 'attachment')
    and ((get_keyword_ucase ('Content-Type', line, '') like 'image/%'))
    or ((get_keyword_ucase ('Content-Type', line, '') = 'application/octet-stream')))
    ret := 1;
        }
      idx := idx + 1;
    }

  return ret;
}
;

create procedure MOBBLOGGING_GET_MOB_MESSAGE
  (
  in _msg any,
  in opts any
  )
{
  declare parsed_message, amime, res any;
  declare rc integer;
  declare msg_header any;

  parsed_message := mime_tree (_msg);

  if (not isarray (opts))
    opts := vector ();

  amime := get_keyword ('MoblogMIMETypes', opts, 'image/%');
  amime := split_and_decode (amime, 0, '\0\0,');
  res := null;

  msg_header := NULL;
  BLOG_MOBLOG_PROCESS_PARTS (parsed_message, _msg, amime, res, msg_header);
  return res;
}
;

create procedure
BLOG_MOBLOG_PROCESS_PARTS (in parts any, inout body varchar, inout amime any, out result any, inout msg_header any)
{
  declare name1, mime1, name, mime, enc, content varchar;
  declare i, l, i1, l1, is_allowed int;
  declare part any;
  declare mailer varchar;

  if (not isarray (result))
    result := vector ();

  if (not isarray (parts) or not isarray (parts[0]))
    return 0;
  -- test if there is an moblog compliant image
  part := parts[0];

  if (msg_header is null)
    msg_header := part;

  name1 := get_keyword_ucase ('filename', part, '');
  if (name1 = '')
    name1 := get_keyword_ucase ('name', part, '');

  mime1 := get_keyword_ucase ('Content-Type', part, '');

  mailer := get_keyword_ucase ('X-Mailer', msg_header, '');

  if ((mime1 = 'application/octet-stream' and name1 <> '') or
      (mailer = 'Symbian OS Email Version 6.1' and mime1 = 'text/plain' and name1 <> ''))
    {
      mime1 := http_mime_type (name1);
    }

  is_allowed := 0;
  i1 := 0; l1 := length (amime);
  while (i1 < l1)
    {
      declare elm any;
      elm := trim(amime [i1]);
      if (mime1 like elm)
  {
    is_allowed := 1;
    i1 := l1;
  }
      i1 := i1 + 1;
    }

  if (
       is_allowed and
       name1 <> '' and
       get_keyword_ucase ('Content-Disposition', part, '') = 'attachment'
     )
    {
      name := name1;
      mime := mime1;
      enc := get_keyword_ucase ('Content-Transfer-Encoding', part, '');
      content := subseq (body, parts[1][0], parts[1][1]);
      if (enc = 'base64')
  content := decode_base64 (content);
      result := vector_concat (result, vector (vector (name, mime, content)));
      return 1;
    }
  -- process the parts
  if (not isarray (parts[2]))
    return 0;
  i := 0; l := length (parts[2]);
  while (i < l)
    {
      BLOG_MOBLOG_PROCESS_PARTS (parts[2][i], body, amime, result, msg_header);
      i := i + 1;
    }
  return 0;
}
;

create procedure
BLOG_MOBLOG_PROCESS_MSG (in own varchar, in id int, in fld varchar, in body any, in is_mb any)
  {
     -- Weblog2
     return DB.DBA.BLOG2_MOBLOG_PROCESS_MSG(own, id, fld, body, is_mb);
  }
;

create procedure MOBBLOGGING_MSG_GET_BODY (in _msg any)
{
  declare parsed_message, body any;
  declare _beg, _end integer;

  parsed_message := mime_tree (_msg);

  body := aref (parsed_message, 1);

  if (isarray (body))
    {
      return substring (_msg, body[0] + 1,  body[1] - body[0]);
    }

  return '';
}
;

create procedure MOBBLOGGING_MSG_GET_PART (in _msg any, in part integer)
{
  declare parsed_message, parts any;
  declare _beg, _end integer;

  parsed_message := mime_tree (_msg);

  parts := aref (parsed_message, 2);

  if (isarray (parts))
    {
      if (length (parts) <= part)
  return '';

      parts := parts [part];
      parts := parts [1];
      return substring (_msg, parts[0] + 1,  parts[1] - parts[0]);
    }

  return '';
}
;


-- SOAP API for subscriptions, pings etc.
create procedure
GET_URL_AND_REDIRECTS (inout url varchar, inout hdr any)
  {
    declare content varchar;
    declare olduri varchar;

    olduri := url;
    again:
    content := http_get (url, hdr);

    if (hdr[0] not like 'HTTP/1._ 200 %')
      {
  if (hdr[0] like 'HTTP/1._ 30_ %')
    {
	    declare base varchar;
	    base := url;
      url := http_request_header (hdr, 'Location');
      if (isstring (url))
	      {
		url := WS.WS.EXPAND_URL (base, url);
      goto again;
    }
	  }
  signal ('22023', trim(hdr[0], '\r\n'), 'BLOG1');
  return NULL;
      }
    url := olduri;
    return content;
  }
;

create procedure
GET_BLOG_POSTS (in uri varchar, in store_in_dav int := 1, in target_folder varchar := null)
  {
  declare content, url varchar;
  declare hdr any;
  declare xt any;
  declare items any;
  declare i, l int;
  declare typef varchar;

  url := uri;
  content := GET_URL_AND_REDIRECTS (url, hdr);

  typef := http_request_header (hdr, 'Content-Type', null, 'text/xml');

  if (store_in_dav)
    {
      BLOG_STORE_CHANNEL_FEED (url, content, typef, target_folder);
    }
  else
    {
      xt := xml_tree_doc (xml_tree (content));
      items := xpath_eval ('/rss/channel/item|/RDF/item', xt, 0);
      i := 0; l := length (items);
      while (i < l)
  {
    BLOG_PROCESS_RSS_ITEM (xml_cut (items[i]), url);
    i := i + 1;
  }
    }
}
;

create procedure
SUBSCRIBE_DATA_CHANNEL (
  in blogid varchar,
  in uid varchar,
  in pwd varchar,
  in title varchar,
  in home varchar,
  in rss varchar,
  in format varchar,
  in lang varchar,
  in update_period varchar,
  in update_frequency int,
  in is_blog int)
  {
    declare req "blogRequest";
    req := new "blogRequest" ();

    req.appkey := 'appKey';
    req.user_name := uid;
    req.passwd := pwd;
    req.blogId := blogid;

    "blogger_auth" (req);
    insert replacing SYS_BLOG_CHANNELS (BC_CHANNEL_URI, BC_BLOG_ID) values (rss, blogid);
    insert replacing SYS_BLOG_CHANNEL_INFO
      (BCD_TITLE, BCD_HOME_URI, BCD_CHANNEL_URI, BCD_FORMAT, BCD_UPDATE_PERIOD,
      BCD_LANG, BCD_UPDATE_FREQ, BCD_SOURCE_URI, BCD_IS_BLOG)
    values (title, home, rss, format,
    update_period, lang, update_frequency, NULL, is_blog);
  }
;


create procedure
BLOG_AUTO_DISCOVER (
  in uri varchar,
  out rss varchar,
  out commentapi varchar,
  out trackback varchar __soap_type 'MWeblogPost:ArrayOfstring',
  out pingback varchar,
  out foaf varchar,
  out suggested_links any __soap_type 'MWeblogPost:ArrayOfstring'
  )
  {
    declare content varchar;
    declare url varchar;
    declare hdr any;
    declare xt any;

    url := uri;
    suggested_links := vector ();

    content := GET_URL_AND_REDIRECTS (url, hdr);
    xt := xml_tree_doc (xml_tree (content, 2));

    rss := xpath_eval ('/html/head/link[@rel="alternate" and @type="application/rss+xml"]/@href', xt, 1);
    pingback := xpath_eval ('/html/head/link[@rel="pingback"]/@href', xt, 1);
    foaf := xpath_eval ('/html/head/link[@rel="meta" and @type="application/rdf+xml"]/@href', xt, 1);
    commentapi := xpath_eval ('/html/head/link[@rel="service.comment" and @type="text/xml"]/@href', xt, 1);
    trackback := GET_BLOG_TB_URLS (xt);

    if (rss is null)
      {
  declare hrefs any;
  declare urls, target any;
  declare i, l int;

  urls := vector ();
  xt := xml_tree_doc (xml_tree (content, 66, url, current_charset ()));
  hrefs := xpath_eval ('//a/@href[ . like "%.rss" or . like "%.rdf" or . like "%.xml" or . like "%rss.xml" ]', xt, 0);
  i := 0; l := length (hrefs);
  while (i < l)
   {
     declare elm any;
     elm := cast (hrefs[i] as varchar);
     target := WS.WS.EXPAND_URL (url, elm);
           if (not position (target, urls))
             urls := vector_concat (urls, vector (target));
     i := i + 1;
   }
        if (length (urls))
    suggested_links := urls;
      }
    -- syndic8 calls
    if (rss is null)
      {
  declare ids, resp, xp any;
  declare urls any;
  declare i, l int;
  urls := vector ();
  declare exit handler for sqlstate '*' { return; };
        resp := DB.DBA.XMLRPC_CALL ('http://www.syndic8.com/xmlrpc.php','syndic8.FindSites',vector (uri));
  xp := xpath_eval('/methodResponse/Param1', xml_tree_doc (resp), 1);
  ids := soap_box_xml_entity (xp, vector (), 11);
  i := 0; l := length (ids);
  while (i < l)
    {
      declare struct, dataurl, status varchar;
      resp := DB.DBA.XMLRPC_CALL ('http://www.syndic8.com/xmlrpc.php','syndic8.GetFeedInfo',vector (ids[i]));
      xp := xpath_eval('/methodResponse/Param1', xml_tree_doc (resp), 1);
      struct := soap_box_xml_entity (xp, vector (), 11);
      dataurl := get_keyword ('dataurl', struct);
      status := get_keyword ('status', struct);
      if (status = 'Syndicated' and not position (dataurl, suggested_links))
              urls := vector_concat (urls, vector (dataurl));
      i := i + 1;
    }
        if (length (urls))
    suggested_links := vector_concat (suggested_links, urls);
      }

  }
;

create procedure GET_BLOG_TB_URLS (inout xt any)
  {
    declare tb any;
    tb := vector ();
    if (not xslt_is_sheet ('--internal-blog-tb-urls-'))
      {
  xslt_sheet ('--internal-blog-tb-urls-',
  xml_tree_doc (
  '<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0" >'||
  '    <xsl:output method="text" />'||
  '    <xsl:template match="comment()" >'||
  ' <comment>'||
  '     <xsl:value-of select="."/>'||
  ' </comment>'||
  '    </xsl:template>'||
  '    <xsl:template match="text()" />'||
  '</xsl:stylesheet>')
  );
      }
    declare xp, ss any;

    xp := xslt ('--internal-blog-tb-urls-', xt);
    ss := string_output ();
    http_value (xp, null, ss);
    ss := string_output_string (ss);

    xp := xml_tree_doc (xml_tree(ss, 2));

    tb := xpath_eval ('[xmlns:tb="http://madskills.com/public/xml/rss/module/trackback/" xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"] /comment/rdf:rdf/rdf:description/@tb:ping', xp, 0);
    return tb;
  }
;


create procedure
BLOG_COMMENT_POST (
  in comment_uri varchar,
  in title varchar,
  in author varchar,
  in link varchar,
  in description varchar)
  {
    declare rss varchar;
    declare hdr any;

    rss := sprintf ('<?xml version="1.0" encoding="%s"?><item><title>%V</title><author>%V</author><link>%V</link><description>%V</description></item>', current_charset (), title, author, link, description);
      {
  declare exit handler for sqlstate '*' { return __SQL_MESSAGE; };
  http_get (comment_uri, hdr, 'POST', 'Content-Type: text/xml', rss);
      }
    if (length (hdr) > 0 and (hdr[0] like 'HTTP/1._ 200 %' or  hdr[0] like 'HTTP/1._ 3__ %'))
      {
  return 'Comment is posted successfully';
      }
    else
      return 'Comment is NOT posted successfully, please verify URL.';
  }
;

create procedure
BLOG_TRACKBACK_PING (
      in tb_uri varchar,
      in title varchar,
      in link varchar,
      in excerpt varchar,
      in blog_name varchar
        )
        returns integer
  {
    declare post, ret, xp, rc any;
    post := sprintf ('title=%U&url=%U&excerpt=%U&blog_name=%U', title, link, excerpt, blog_name);
    ret := http_get (tb_uri, null, 'POST', null, post);
    xp := xml_tree_doc (ret);
    rc := cast (xpath_eval ('/response/error', xp) as varchar);
    rc := atoi (rc);
    if (rc <> 0)
      {
        rc := cast (xpath_eval ('/response/message', xp) as varchar);
  signal ('22023', rc);
      }
    return rc;
  }
;

create procedure
BLOG_PINGBACK_PING (in pingback_uri varchar, in source_uri varchar, in target_uri varchar)
  {
    declare rc any;
    declare message any;
    message := '';
    rc := DB.DBA.XMLRPC_CALL (pingback_uri, 'pingback.ping', vector (source_uri, target_uri));
    if (isarray(rc))
      {
  declare xt any;
  xt := xml_tree_doc (rc);
  message := cast (xpath_eval ('string(//*)', xml_cut(xt), 1) as varchar);
      }
    return message;
  }
;

create procedure
BLOG_WEBLOG_PING (in blog_name varchar, in blog_uri varchar, out error varchar, out message varchar)
  {
    declare rc any;
    rc := DB.DBA.XMLRPC_CALL ('http://rpc.weblogs.com/RPC2', 'weblogUpdates.ping', vector (blog_name, blog_uri));
    if (isarray(rc))
      {
  declare xt any;
  xt := xml_tree_doc (rc);
  error := cast (xpath_eval ('//flerror/text()', xml_cut(xt), 1) as varchar);
  message := cast (xpath_eval ('//message/text()', xml_cut(xt), 1) as varchar);
      }
  }
;


insert soft "DB"."DBA"."SYS_SOAP_DATATYPES" (SDT_NAME, SDT_SCH, SDT_TYPE)
       values ('http://www.openlinksw.com/virtuoso/blog/api:ArrayOfRssFeed',
'<complexType name="ArrayOfRssFeed" targetNamespace="http://www.openlinksw.com/virtuoso/blog/api"
   xmlns:enc="http://schemas.xmlsoap.org/soap/encoding/"
   xmlns:wsdl="http://schemas.xmlsoap.org/wsdl/"
   xmlns="http://www.w3.org/2001/XMLSchema"
   xmlns:tns="http://www.openlinksw.com/virtuoso/blog/api">
  <complexContent>
     <restriction base="enc:Array">
        <sequence>
           <element name="item" type="tns:RssFeedStruct" minOccurs="0" maxOccurs="unbounded"/>
        </sequence>
        <attributeGroup ref="enc:commonAttributes"/>
        <attribute ref="enc:arrayType" wsdl:arrayType="tns:RssFeedStruct[]"/>
     </restriction>
  </complexContent>
</complexType>', 0)
;


insert soft "DB"."DBA"."SYS_SOAP_DATATYPES" (SDT_NAME, SDT_SCH, SDT_TYPE)
       values ('http://www.openlinksw.com/virtuoso/blog/api:RssFeedStruct',
'<complexType name="RssFeedStruct" targetNamespace="http://www.openlinksw.com/virtuoso/blog/api"
   xmlns:enc="http://schemas.xmlsoap.org/soap/encoding/"
   xmlns:wsdl="http://schemas.xmlsoap.org/wsdl/"
   xmlns="http://www.w3.org/2001/XMLSchema"
   xmlns:tns="http://www.openlinksw.com/virtuoso/blog/api">
    <all>
    <element name="title"           type="string" nillable="true" />
    <element name="blog"            type="string" nillable="true" />
    <element name="rss"             type="string" nillable="true" />
    <element name="format"          type="string" nillable="true" />
    <element name="lang"      type="string" nillable="true" />
    <element name="updatePeriod"    type="string" nillable="true" />
    <element name="updateFrequency" type="int" nillable="true" />
    </all>
</complexType>', 0)
;

insert soft "DB"."DBA"."SYS_SOAP_DATATYPES" (SDT_NAME, SDT_SCH, SDT_TYPE)
       values ('http://www.openlinksw.com/virtuoso/blog/api:ArrayOfUserBlogs',
'<complexType name="ArrayOfUserBlogs" targetNamespace="http://www.openlinksw.com/virtuoso/blog/api"
   xmlns:enc="http://schemas.xmlsoap.org/soap/encoding/"
   xmlns:wsdl="http://schemas.xmlsoap.org/wsdl/"
   xmlns="http://www.w3.org/2001/XMLSchema"
   xmlns:tns="http://www.openlinksw.com/virtuoso/blog/api">
  <complexContent>
     <restriction base="enc:Array">
        <sequence>
           <element name="item" type="tns:UserBlogsStruct" minOccurs="0" maxOccurs="unbounded"/>
        </sequence>
        <attributeGroup ref="enc:commonAttributes"/>
        <attribute ref="enc:arrayType" wsdl:arrayType="tns:UserBlogsStruct[]"/>
     </restriction>
  </complexContent>
</complexType>', 0)
;


insert soft "DB"."DBA"."SYS_SOAP_DATATYPES" (SDT_NAME, SDT_SCH, SDT_TYPE)
       values ('http://www.openlinksw.com/virtuoso/blog/api:UserBlogsStruct',
'<complexType name="UserBlogsStruct" targetNamespace="http://www.openlinksw.com/virtuoso/blog/api"
   xmlns:enc="http://schemas.xmlsoap.org/soap/encoding/"
   xmlns:wsdl="http://schemas.xmlsoap.org/wsdl/"
   xmlns="http://www.w3.org/2001/XMLSchema"
   xmlns:tns="http://www.openlinksw.com/virtuoso/blog/api">
    <all>
    <element name="url" type="string" nillable="true" />
    <element name="blogid" type="string" nillable="true" />
    <element name="blogName" type="string" nillable="true" />
    </all>
</complexType>', 0)
;

create procedure
GET_BLOG_FEED (in uri varchar)
returns any __SOAP_TYPE 'http://www.openlinksw.com/virtuoso/blog/api:ArrayOfRssFeed'
  {
    declare tit, rss, format, lang, upd_per, upd_freq, home, email, src_tit any;
    declare links, channels any;
    declare cont varchar;
    declare xt, ct any;
    declare hp, proto any;
    declare low int;
    declare newelm any;

    retr:
    low := 0;

    hp := WS.WS.PARSE_URI (uri);
    proto := lower(hp[0]);

    if (proto <> 'http')
      cont := XML_URI_GET (uri, '');
    else
      {
  declare ur, ou, hdr varchar;
  ur := uri; ou := ur;
  try_again:
  cont := http_get (ur, hdr);
  if (hdr[0] like 'HTTP/1._ 30_ %')
    {
      ur := http_request_header (hdr, 'Location');
      if (ur <> ou)
        {
    ou := ur;
    goto try_again;
        }
    }
      }

      {
  declare exit handler for sqlstate '*' { goto htmlp; };
  xt := xml_tree_doc (xml_tree (cont, 0));
  goto donep;
      }

    htmlp:;

    xt := xml_tree_doc (xml_tree (cont, 2));
    low := 1;

    donep:;

    -- HTML feed
    if (xpath_eval ('/html', xt, 1) is not null)
      {
  tit := cast (xpath_eval ('//title[1]/text()', xt, 1) as varchar);
  rss := cast (xpath_eval ('//head/link[ @rel="alternate" and @type="application/rss+xml" ]/@href', xt, 1) as varchar);
  home := uri;
  format := '';
  lang := '';
  upd_per := '';
  upd_freq := 1;
  if (rss is not null)
    {
      uri := rss;
      goto retr;
    }
        else
          signal ('.....', 'Unknown format');
      }
    -- RSS feed
    else if (xpath_eval ('/rss|/RDF/channel', xt, 1) is not null)
      {
  xt := xml_cut (xpath_eval ('/rss/channel[1]|/RDF/channel[1]', xt, 1));
  tit := cast (xpath_eval ('/channel/title/text()', xt, 1) as varchar);
  home := cast (xpath_eval ('/channel/link/text()', xt, 1) as varchar);
  email := cast (xpath_eval ('/channel/managingEditor/text()', xt, 1) as varchar);
  rss := uri;
  format := 'http://my.netscape.com/rdf/simple/0.9/';
  lang := cast (xpath_eval ('/channel/language/text()', xt, 1) as varchar);
  upd_per := 'hourly';
  upd_freq := 1;
  channels := vector (soap_box_structure ('title', tit, 'blog', home, 'rss', rss, 'format', format, 'lang', lang, 'updatePeriod', upd_per, 'updateFrequency', upd_freq));
      }
    -- OCS directory
    else if (xpath_eval ('[ xmlns:ocs="http://alchemy.openjava.org/ocs/directory#" xmlns:ocs1="http://InternetAlchemy.org/ocs/directory#" ] /RDF//ocs:format|/RDF//ocs1:format', xt, 1) is not null)
      {
  tit := '';
  declare cnls any;
  declare ns varchar;
  declare i, l int;
  ns := '[ xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#" ' ||
  ' xmlns:ocs="http://alchemy.openjava.org/ocs/directory#" ' ||
  ' xmlns:ocs1="http://InternetAlchemy.org/ocs/directory#" ' ||
  ' xmlns:dc="http://purl.org/metadata/dublin_core#" ] ';
  cnls := xpath_eval (ns || '/rdf:RDF/rdf:description[1]/rdf:description', xt, 0);
  src_tit := xpath_eval (ns || '/rdf:RDF/rdf:description[1]/dc:title/text()', xt, 1);
  i := 0; l := length (cnls);
  channels := vector ();
  while (i < l)
    {
      declare title, about varchar;
      declare formats any;

      tit := xpath_eval (ns||'/rdf:description/dc:title/text()', xml_cut (cnls[i]), 1);
      home := xpath_eval (ns||'/rdf:description/@about', xml_cut (cnls[i]), 1);
      formats := xpath_eval (ns||'/rdf:description/rdf:description[ocs:format or ocs1:format]',
      xml_cut (cnls[i]), 0);

      declare j,k int;

      j := 0; k := length(formats);

      while (j < k)
        {
    xt := xml_cut(formats[j]);
    rss := cast(xpath_eval ('/description/@about', xt, 1) as varchar);
    format := cast(xpath_eval ('/description/format/text()', xt, 1) as varchar);
    lang := cast(xpath_eval ('/description/language/text()', xt, 1) as varchar);
    upd_per := cast(xpath_eval ('/description/updatePeriod/text()', xt, 1) as varchar);
    upd_freq := coalesce (xpath_eval ('/description/updateFrequency/text()', xt, 1), '1');
    upd_freq := atoi (cast (upd_freq as varchar));

    newelm := soap_box_structure ('title', tit, 'blog', home, 'rss', rss, 'format', format, 'lang', lang,         'updatePeriod', upd_per, 'updateFrequency', upd_freq);

    channels := vector_concat (channels, vector (newelm));
    j := j + 1;
        }
      i := i + 1;
    }
      }
    -- OPML file
    else if (xpath_eval ('/opml', xt, 1) is not null)
      {
  channels := vector ();
  tit := xpath_eval ('/opml/head/title/text()', xt, 1);
  if (low)
    links := xpath_eval ('/opml/body/outline[ @htmlurl and @xmlurl ]', xt, 0);
  else
    links := xpath_eval ('/opml/body/outline[ @htmlUrl and @xmlUrl ]', xt, 0);

  declare i, l int;
  i := 0; l := length (links);
  while (i < l)
    {
      declare _xt any;
      _xt := xml_cut (links[i]);
      rss := xpath_eval ('/outline/@xmlUrl|/outline/@xmlurl', _xt, 1);
      home := xpath_eval ('/outline/@htmlUrl|/outline/@htmlurl', _xt, 1);
      lang := xpath_eval ('/outline/@language', _xt, 1);
      tit := xpath_eval ('/outline/@text|/outline/@title', _xt, 1);
      format := 'http://my.netscape.com/rdf/simple/0.9/';
      upd_per := 'daily';
      upd_freq := 1;
      i := i + 1;
      newelm := soap_box_structure ('title', tit, 'blog', home, 'rss', rss, 'format', format, 'lang', lang,         'updatePeriod', upd_per, 'updateFrequency', upd_freq);
      channels := vector_concat (channels, vector (newelm));
    }

      }
    else
      {
  signal ('.....', 'Unknown format');
      }
    return channels;
  }
;

create procedure
GET_USER_BLOGS (
             in "username" varchar,
             in "password" varchar
         )
  __soap_type 'http://www.openlinksw.com/virtuoso/blog/api:ArrayOfUserBlogs'
  {
    return "blogger.getUsersBlogs" ('appKey', "username", "password");
  }
;


create procedure BLOG_API_PROC_LIST (in q varchar := 'DB')
  {
    declare arr any;
    declare i, l int;
    declare P_NAME, P_LNAME, P_OWNER varchar;
    arr := BLOG.DBA."mt.supportedMethods" ();
    arr := vector_concat (arr, vector ('DAV_COL_CREATE','DAV_RES_UPLOAD','DAV_DELETE','DAV_COPY','DAV_MOVE'));
    i := 0; l := length (arr);
    result_names (P_NAME, P_OWNER, P_LNAME);
    while (i < l and q = 'DB')
      {
  result ('BLOG.DBA.'||arr[i], 'DBA', arr[i]);
  i := i + 1;
      }
  }
;

insert soft "DB"."DBA"."SYS_SOAP_DATATYPES" (SDT_NAME, SDT_SCH, SDT_TYPE) values (
'http://www.openlinksw.com/virtuoso/blog/api:ArrayOfWebDAVResource',
'<complexType name="ArrayOfWebDAVResource"
    targetNamespace="http://www.openlinksw.com/virtuoso/blog/api"
    xmlns:enc="http://schemas.xmlsoap.org/soap/encoding/"
    xmlns:wsdl="http://schemas.xmlsoap.org/wsdl/"
    xmlns="http://www.w3.org/2001/XMLSchema"
    xmlns:tns="http://www.openlinksw.com/virtuoso/blog/api">
    <complexContent>
  <restriction base="enc:Array">
      <sequence>
    <element name="item" type="tns:WebDAVResourceStruct" minOccurs="0" maxOccurs="unbounded"/>
      </sequence>
      <attributeGroup ref="enc:commonAttributes"/>
      <attribute ref="enc:arrayType" wsdl:arrayType="tns:WebDAVResourceStruct[]"/>
  </restriction>
    </complexContent>
</complexType>', 0)
;

insert soft "DB"."DBA"."SYS_SOAP_DATATYPES" (SDT_NAME, SDT_SCH, SDT_TYPE) values (
'http://www.openlinksw.com/virtuoso/blog/api:WebDAVResourceStruct',
'<complexType name="WebDAVResourceStruct"
    targetNamespace="http://www.openlinksw.com/virtuoso/blog/api"
    xmlns:enc="http://schemas.xmlsoap.org/soap/encoding/"
    xmlns:wsdl="http://schemas.xmlsoap.org/wsdl/"
    xmlns="http://www.w3.org/2001/XMLSchema"
    xmlns:tns="http://www.openlinksw.com/virtuoso/blog/api">
    <all>
  <element name="fullPath" type="string" />
  <element name="Name" type="string"  />
  <element name="type" type="string"  />
  <element name="length" type="int" nillable="true" />
  <element name="created" type="dateTime" nillable="true" />
  <element name="lastModified" type="dateTime" nillable="true" />
  <element name="permissions" type="string" nillable="true" />
  <element name="ownerName" type="string" nillable="true" />
  <element name="groupName" type="string" nillable="true" />
  <element name="contentType" type="string" nillable="true" />
  <element name="displayName" type="string" nillable="true" minOccurs="0" />
  <element name="sourceURL" type="string" nillable="true" minOccurs="0" />
    </all>
</complexType>', 0)
;


insert soft "DB"."DBA"."SYS_SOAP_DATATYPES" (SDT_NAME, SDT_SCH, SDT_TYPE) values (
'http://www.openlinksw.com/virtuoso/blog/api:ArrayOfRssFeedEntry',
'<complexType name="ArrayOfRssFeedEntry"
    targetNamespace="http://www.openlinksw.com/virtuoso/blog/api"
    xmlns:enc="http://schemas.xmlsoap.org/soap/encoding/"
    xmlns:wsdl="http://schemas.xmlsoap.org/wsdl/"
    xmlns="http://www.w3.org/2001/XMLSchema"
    xmlns:tns="http://www.openlinksw.com/virtuoso/blog/api">
    <complexContent>
  <restriction base="enc:Array">
      <sequence>
    <element name="item" type="tns:RssFeedEntry" minOccurs="0" maxOccurs="unbounded"/>
      </sequence>
      <attributeGroup ref="enc:commonAttributes"/>
      <attribute ref="enc:arrayType" wsdl:arrayType="tns:RssFeedEntry[]"/>
  </restriction>
    </complexContent>
</complexType>', 0)
;

insert soft "DB"."DBA"."SYS_SOAP_DATATYPES" (SDT_NAME, SDT_SCH, SDT_TYPE) values (
'http://www.openlinksw.com/virtuoso/blog/api:RssFeedEntry',
'<complexType name="RssFeedEntry"
    targetNamespace="http://www.openlinksw.com/virtuoso/blog/api"
    xmlns:enc="http://schemas.xmlsoap.org/soap/encoding/"
    xmlns:wsdl="http://schemas.xmlsoap.org/wsdl/"
    xmlns="http://www.w3.org/2001/XMLSchema"
    xmlns:tns="http://www.openlinksw.com/virtuoso/blog/api">
    <all>
  <element name="title" type="string" nillable="true" minOccurs="1" />
  <element name="URL" type="string" nillable="true" minOccurs="1" />
    </all>
</complexType>', 0)
;

create procedure
GET_RSS_URL_COLLECTION (in "username" varchar, in "password" varchar)
__soap_type 'http://www.openlinksw.com/virtuoso/blog/api:ArrayOfRssFeedEntry'
{
  declare ret any;
  declare req "blogRequest";
  req := new "blogRequest" ();

  req.appkey := 'appKey';
  req.user_name := "username";
  req.passwd := "password";

  "blogger_auth" (req);
  ret := vector ();
  for select BCD_TITLE, BCD_CHANNEL_URI
  from BLOG..SYS_BLOG_CHANNEL_INFO, SYS_BLOG_CHANNELS, SYS_BLOG_INFO
  where BC_CHANNEL_URI = BCD_CHANNEL_URI and BI_BLOG_ID = BC_BLOG_ID and BI_OWNER = req.auth_userid do
  {
    ret := vector_concat (ret, vector (soap_box_structure ('title', BCD_TITLE, 'URL', BCD_CHANNEL_URI)));
  }
  return ret;
}
;

create procedure
DELETE_RSS_FEED (in rssUrl varchar, in "username" varchar, in "password" varchar)
{
  declare ret any;
  declare req "blogRequest";
  req := new "blogRequest" ();

  req.appkey := 'appKey';
  req.user_name := "username";
  req.passwd := "password";

  "blogger_auth" (req);

  delete from SYS_BLOG_CHANNELS where BC_CHANNEL_URI = rssUrl and BC_BLOG_ID in
  (select BI_BLOG_ID from SYS_BLOG_INFO where BI_OWNER = req.auth_userid);

  return row_count();
}
;

create procedure
GET_DAV_DIRECTORY
  (
    in "location" varchar,
    in "username" varchar,
    in "password" varchar
  )
__soap_type 'http://www.openlinksw.com/virtuoso/blog/api:ArrayOfWebDAVResource'
  {
    declare res any;
    res := vector ();
    for select FULL_PATH, NAME, TYPE, RLENGTH, CR_TIME, MOD_TIME, PERMS, OWNER, GRP, MIME_TYPE, ID
     from "DB"."DBA"."DAV_DIR" where path = "location" and auth_uid = "username" and auth_pwd = "password" do
      {
  declare elm any;
        declare uname, gname, dname, src varchar;
  dname := NAME;
  src := '';
        uname := (select U_NAME from "DB"."DBA"."SYS_USERS" where U_ID = OWNER);
        gname := (select U_NAME from "DB"."DBA"."SYS_USERS" where U_ID = GRP);
  if (TYPE = 'r')
    {
      dname := coalesce ((select PROP_VALUE from WS.WS.SYS_DAV_PROP where PROP_PARENT_ID = ID and PROP_TYPE = 'R' and PROP_NAME = 'displayName'), NAME);
      src := coalesce ((select PROP_VALUE from WS.WS.SYS_DAV_PROP where PROP_PARENT_ID = ID and PROP_TYPE = 'R' and PROP_NAME = 'sourceURL'), '');
    }
  elm := soap_box_structure
         (
         'fullPath', FULL_PATH,
         'Name', NAME,
         'type', TYPE,
         'length', RLENGTH,
         'created', CR_TIME,
         'lastModified', MOD_TIME,
         'permissions', PERMS,
         'ownerName', uname,
         'groupName', gname,
         'contentType', MIME_TYPE,
         'displayName', dname,
         'sourceURL', src
         );
         res := vector_concat (res, vector (elm));
      }
    return res;
  }
;

create procedure
BLOG_GET_TIME_LINE ()
  {
    declare lines any;
    declare tim, ol varchar;
    ol := stringdate ('1970-01-01');

    if (not is_http_ctx ())
      return ol;

    lines := http_request_header ();
    tim := http_request_header(lines, 'X-Feed-Items-New-Than');

    if (isstring (tim))
      ol := http_string_date (tim);

    return ol;
  }
;



insert soft "DB"."DBA"."SYS_SOAP_DATATYPES" (SDT_NAME, SDT_SCH, SDT_TYPE) values
('urn:GoogleSearch:GoogleSearchResult','<complexType name="GoogleSearchResult"
 xmlns="http://www.w3.org/2001/XMLSchema" targetNamespace="urn:GoogleSearch" xmlns:typens="urn:GoogleSearch">
  <all>
    <element name="documentFiltering"           type="boolean"/>
    <element name="searchComments"              type="string"/>
    <element name="estimatedTotalResultsCount"  type="int"/>
    <element name="estimateIsExact"             type="boolean"/>
    <element name="resultElements"              type="typens:ResultElementArray"/>
    <element name="searchQuery"                 type="string"/>
    <element name="startIndex"                  type="int"/>
    <element name="endIndex"                    type="int"/>
    <element name="searchTips"                  type="string"/>
    <element name="directoryCategories"         type="typens:DirectoryCategoryArray"/>
    <element name="searchTime"                  type="double"/>
  </all>
</complexType>', 0)
;

insert soft "DB"."DBA"."SYS_SOAP_DATATYPES" (SDT_NAME, SDT_SCH, SDT_TYPE) values
('urn:GoogleSearch:ResultElement','<xsd:complexType name="ResultElement"
  targetNamespace="urn:GoogleSearch" xmlns:typens="urn:GoogleSearch" xmlns:xsd="http://www.w3.org/2001/XMLSchema">
  <xsd:all>
    <xsd:element name="summary" type="xsd:string"/>
    <xsd:element name="URL" type="xsd:string"/>
    <xsd:element name="snippet" type="xsd:string"/>
    <xsd:element name="title" type="xsd:string"/>
    <xsd:element name="cachedSize" type="xsd:string"/>
    <xsd:element name="relatedInformationPresent" type="xsd:boolean"/>
    <xsd:element name="hostName" type="xsd:string"/>
    <xsd:element name="directoryCategory" type="typens:DirectoryCategory"/>
    <xsd:element name="directoryTitle" type="xsd:string"/>
  </xsd:all>
</xsd:complexType>', 0)
;

insert soft "DB"."DBA"."SYS_SOAP_DATATYPES" (SDT_NAME, SDT_SCH, SDT_TYPE) values
('urn:GoogleSearch:ResultElementArray','<xsd:complexType name="ResultElementArray"
 targetNamespace="urn:GoogleSearch" xmlns:typens="urn:GoogleSearch" xmlns:soapenc="http://schemas.xmlsoap.org/soap/encoding/" xmlns:wsdl="http://schemas.xmlsoap.org/wsdl/" xmlns:xsd="http://www.w3.org/2001/XMLSchema">
  <xsd:complexContent>
    <xsd:restriction base="soapenc:Array">
       <xsd:attribute ref="soapenc:arrayType" wsdl:arrayType="typens:ResultElement[]"/>
    </xsd:restriction>
  </xsd:complexContent>
</xsd:complexType>', 0)
;

insert soft "DB"."DBA"."SYS_SOAP_DATATYPES" (SDT_NAME, SDT_SCH, SDT_TYPE) values
('urn:GoogleSearch:DirectoryCategoryArray','<xsd:complexType name="DirectoryCategoryArray"
       targetNamespace="urn:GoogleSearch"
       xmlns:soapenc="http://schemas.xmlsoap.org/soap/encoding/"
       xmlns:typens="urn:GoogleSearch"
       xmlns:wsdl="http://schemas.xmlsoap.org/wsdl/"
       xmlns:xsd="http://www.w3.org/2001/XMLSchema">
  <xsd:complexContent>
    <xsd:restriction base="soapenc:Array">
       <xsd:attribute ref="soapenc:arrayType" wsdl:arrayType="typens:DirectoryCategory[]"/>
    </xsd:restriction>
  </xsd:complexContent>
</xsd:complexType>', 0)
;

insert soft "DB"."DBA"."SYS_SOAP_DATATYPES" (SDT_NAME, SDT_SCH, SDT_TYPE) values
('urn:GoogleSearch:DirectoryCategory','<xsd:complexType name="DirectoryCategory"
       targetNamespace="urn:GoogleSearch"
       xmlns:typens="urn:GoogleSearch"
       xmlns:xsd="http://www.w3.org/2001/XMLSchema">
  <xsd:all>
    <xsd:element name="fullViewableName" type="xsd:string"/>
    <xsd:element name="specialEncoding" type="xsd:string"/>
  </xsd:all>
</xsd:complexType>', 0)
;


create procedure blog_search_google (in q any, in k any, in n int := 10)
{
  declare res, xt, arr, o any;
  declare i, l int;
  declare title, URL varchar;
  o := vector ();

  if (length (k) = 0 or length (q) = 0)
    return o;

  declare exit handler for sqlstate '*' { return vector (); };

  res := soap_call_new ('api.google.com', '/search/beta2', 'urn:GoogleSearch', 'doGoogleSearch',
    vector ('key', k,
      'q', q,
      vector ('start', 'int'), 0,
      'maxResults', n,
      'filter', soap_boolean (0),
      'restrict', '',
      'safeSearch', soap_boolean(0),
      'lr', '',
      'ie', '',
      'oe', ''),
     11, null, null, 'urn:GoogleSearchAction');
  xt := xml_tree_doc (res);
  xt := xpath_eval ('//return', xt, 1);
  res := soap_box_xml_entity_validating (xml_cut (xt), 'urn:GoogleSearch:GoogleSearchResult');

  arr := get_keyword ('resultElements', res, vector ());
  i := 0; l := length (arr);
  while (i < l)
    {
      declare elm any;
      elm := arr[i];
      title := get_keyword ('title', elm);
      URL := get_keyword ('URL', elm);
      o := vector_concat (o , vector (vector (title, URL)));
      i := i + 1;
    }
  return o;
}
;


insert soft "DB"."DBA"."SYS_SOAP_DATATYPES" (SDT_NAME, SDT_SCH, SDT_TYPE) values
('http://soap.amazon.com:KeywordRequest',
'<xs:complexType xmlns:xs="http://www.w3.org/2001/XMLSchema"
name="KeywordRequest" targetNamespace="http://soap.amazon.com">
<xs:complexContent>
<xs:restriction base="enc:Struct" xmlns:enc="http://schemas.xmlsoap.org/soap/encoding/">
<xs:sequence>
<xs:element name="keyword" type="xs:string" nillable="0" minOccurs="1" maxOccurs="1" />
<xs:element name="page" type="xs:string" nillable="0" minOccurs="1" maxOccurs="1" />
<xs:element name="mode" type="xs:string" nillable="0" minOccurs="1" maxOccurs="1" />
<xs:element name="tag" type="xs:string" nillable="0" minOccurs="1" maxOccurs="1" />
<xs:element name="type" type="xs:string" nillable="0" minOccurs="1" maxOccurs="1" />
<xs:element name="devtag" type="xs:string" nillable="0" minOccurs="1" maxOccurs="1" />
<xs:element name="sort" type="xs:string" nillable="0" minOccurs="0" maxOccurs="1" />
<xs:element name="locale" type="xs:string" nillable="0" minOccurs="0" maxOccurs="1" />
<xs:element name="price" type="xs:string" nillable="0" minOccurs="0" maxOccurs="1" />
</xs:sequence>
</xs:restriction>
</xs:complexContent>
</xs:complexType>', 0)
;


create procedure blog_search_amazon (in q any, in k any, in n int := 10)
{
  declare res, xt, arr, o, pars any;
  declare i, l int;
  declare title, URL varchar;
  o := vector ();

  if (length (k) = 0 or length (q) = 0)
    return o;

  declare exit handler for sqlstate '*' { return vector (); };

  pars := soap_box_structure (
    'keyword', q,
    'page', '1',
    'mode', 'books',
    'tag', 'webservices-20',
    'devtag', k,
    'type', 'heavy');

  res := soap_call_new ('soap.amazon.com','/onca/soap3', 'http://soap.amazon.com', 'KeywordSearchRequest',
      vector (vector('KeywordSearchRequest', 'http://soap.amazon.com:KeywordRequest'), pars), 11,
      NULL, NULL, '"http://soap.amazon.com"', 0);

  xt := xml_tree_doc (res);

  arr := xpath_eval ('//Details/Details[ProductName]', xt, 0);
  i := 0; l := __min (length (arr), n);
  while (i < l)
    {
      declare elm any;
      elm := xml_cut (arr[i]);
      title := cast(xpath_eval ('ProductName/text()', elm) as varchar);
      URL := cast (xpath_eval ('Url/text()', elm) as varchar);
      if (title is not null and URL is not null)
        o := vector_concat (o , vector (vector (title, URL)));
      i := i + 1;
    }
  return o;
}
;


create trigger SYS_BLOG_CHANNELS_D_C after delete on SYS_BLOG_CHANNELS referencing old as O
{
  if (not exists (select 1 from SYS_BLOG_CHANNELS where BC_BLOG_ID <> O.BC_BLOG_ID and BC_CHANNEL_URI = O.BC_CHANNEL_URI))
    {
      delete from SYS_BLOG_CHANNEL_INFO where BCD_CHANNEL_URI = O.BC_CHANNEL_URI;
    }
}
;


create procedure BLOG2_FEED_SUBSCRIBE
  (in blogid varchar,
   in feed_url any,
   in home_url any,
   in title any,
   in format any,
   in lang any,
   in upd_per any,
   in freq any,
   in cat any,
   in foaf varchar,
   in email varchar
   )
{
  declare cat_id int;
  declare f_is_blog int;
  if (lower(feed_url) not like 'http://%')
    {
      signal ('22023', 'Feed Url is not valid');
    }
 if (cat <> '' and not exists (select 1 from BLOG.DBA.SYS_BLOG_CHANNEL_CATEGORY where BCC_NAME = cat and BCC_BLOG_ID = blogid))
   {
     f_is_blog := 0;
     if (strstr (lower (cat), 'blog roll') is not null)
       f_is_blog := 1;
     insert into BLOG.DBA.SYS_BLOG_CHANNEL_CATEGORY (BCC_BLOG_ID, BCC_NAME, BCC_IS_BLOG)
   values (blogid,  cat, f_is_blog);
   }
 cat_id := (select BCC_ID from BLOG.DBA.SYS_BLOG_CHANNEL_CATEGORY where BCC_NAME = cat and BCC_BLOG_ID = blogid);
 insert replacing BLOG.DBA.SYS_BLOG_CHANNELS (BC_CHANNEL_URI, BC_BLOG_ID, BC_CAT_ID) values (feed_url, blogid, cat_id);
 insert replacing BLOG.DBA.SYS_BLOG_CHANNEL_INFO
     (BCD_TITLE, BCD_HOME_URI, BCD_CHANNEL_URI, BCD_IS_BLOG, BCD_SOURCE_URI,
      BCD_FORMAT, BCD_UPDATE_PERIOD, BCD_LANG, BCD_UPDATE_FREQ)
     values (title, home_url, feed_url, f_is_blog, null, format, upd_per, lang, freq);
 if (foaf = '1')
   {
     insert replacing SYS_BLOG_CONTACTS (BF_BLOG_ID, BF_NAME, BF_NICK, BF_MBOX, BF_HOMEPAGE, BF_WEBLOG, BF_RSS)
   values (blogid, title, '', email, home_url, home_url, feed_url);
   }
}
;


create procedure BLOG_GET_ATOM_URL_P (in url any)
{
  declare hdr, cnt, atomp, was_html, xt any;
  declare post_uri, blogname, blog_url varchar;

  result_names (post_uri, blogname, blog_url);

  if (not length (url))
    return;

  was_html := 0;
  declare exit handler for sqlstate '*'
  {
    rollback work;
    return null;
  }
  ;

again:
  --if (was_html)
  --  return null;
  commit work;
  cnt := GET_URL_AND_REDIRECTS (url, hdr);

  xt := xml_tree_doc(xml_tree(cnt, 2, '', 'UTF-8'));

  if (xpath_eval ('/html', xt) is not null)
    {
      -- try to get atom apis
      blog_url := url;
      url := cast (xpath_eval ('/html/head/link[@rel="alternate" and @type="application/atomserv+xml"]/@href', xt) as varchar);
      was_html := 1;
      goto again;
    }
  else if (xpath_eval ('/service', xt) is not null)
    {
      atomp := cast (xpath_eval ('/service/workspace/collection/@href', xt) as varchar);
      blogname := coalesce (xpath_eval ('string (/service/workspace/collection/@title)', xt), '');
      blogname := blog_wide2utf (blogname);
      result (atomp, blogname, blog_url);
    }
  else if (0 and xpath_eval ('/feed', xt) is not null) -- XXX: disabled
    {
      -- probably is atom
      atomp := cast (xpath_eval ('/feed/link[@rel="self" and @type="application/atom+xml"]/@href', xt) as varchar);
      blogname := coalesce (xpath_eval ('string (/feed/title)', xt), '');
      blogname := blog_wide2utf (blogname);
      blog_url := cast (xpath_eval ('/feed/link[@rel="alternate" and @type="text/html"]/@href', xt) as varchar);
      result (atomp, blogname, blog_url);
    }
  return atomp;
}
;

blog2_exec_no_error ('create procedure view BLOG_GET_ATOM_URL
as BLOG.DBA.BLOG_GET_ATOM_URL_P (URL) (post_uri varchar, blogname varchar, blog_url varchar)')
;



create procedure
ROUTING_PROCESS_BLOGS (in job_id int, in proto_id int, in dst varchar, in dst_id any,
                       in a_usr varchar, in a_pwd varchar, in  item_id any,
		       in  tag varchar, in eid varchar, in iid varchar, in send_delete int)
{
  declare eids, post_stat, post_err, iids any;
  declare _RL_POST_ID, _RL_F_POST_ID, _RL_TYPE, _RL_COMMENT_ID, _RL_RETRANSMITS any;
  declare tags any;
  declare rc int;

  while (1) {
  post_stat := 1;
  post_err := null;
      {
  whenever not found goto enf;
        select top 1 RL_POST_ID, RL_F_POST_ID, RL_TYPE, RL_COMMENT_ID, RL_RETRANSMITS
          into _RL_POST_ID, _RL_F_POST_ID, _RL_TYPE, _RL_COMMENT_ID, _RL_RETRANSMITS
  from SYS_BLOGS_ROUTING_LOG where RL_JOB_ID = job_id and RL_PROCESSED = 0;
      }

          declare post_id, typ, ntype, fpostid varchar;
          declare req BLOG.DBA."blogRequest";
          declare _B_USER_ID, _B_CONTENT, _B_POST_ID, _B_TS, _B_TITLE any;
    declare _B_META "MWeblogPost";
    declare _BM_COMMENT, _BM_NAME, _BM_E_MAIL, _BM_HOME_PAGE, _BM_ADDRESS any;

    _B_CONTENT := null;
    _BM_COMMENT := null;
    _BM_NAME := null;
    _BM_E_MAIL := null;
    _BM_HOME_PAGE := null;
    _BM_ADDRESS := null;
    {
      whenever not found goto nextstep;
      select B_META, B_USER_ID, B_CONTENT, B_POST_ID, B_TS, B_TITLE into
      _B_META, _B_USER_ID, _B_CONTENT, _B_POST_ID, _B_TS, _B_TITLE
      from SYS_BLOGS where B_BLOG_ID = item_id and B_POST_ID = _RL_POST_ID;

      tags := '';
      for select BT_TAG from BLOG_POST_TAGS_STAT where postid = _RL_POST_ID do
       {
         tags := tags || sprintf ('<a href="index.vspx?tag=%s" rel="tag" style="display:none;">%s</a>', BT_TAG, BT_TAG);
       }

      if (_B_CONTENT is not null)
	{
	  _B_CONTENT := blob_to_string (_B_CONTENT);
	  if (length (tags))
	    _B_CONTENT := _B_CONTENT || tags;
	  if (proto_id = 1 and length (_B_TITLE))
	    {
	      _B_CONTENT := '<div><div style="display:none;">'||_B_TITLE||'</div>'||_B_CONTENT||'</div>';
	    }
	}
      else
	_B_CONTENT := '';

      if (_B_META is not null)
	{
	  _B_META.description := blog_utf2wide (blob_to_string (_B_CONTENT));
	}
      nextstep:;
     }

          post_id := _RL_POST_ID;
          fpostid := _RL_F_POST_ID;


     {
	    declare exit handler for sqlstate '*' {
	      _RL_RETRANSMITS := _RL_RETRANSMITS - 1;
	      post_stat := 2;
	      if (1) log_message (__SQL_STATE || ':' || __SQL_MESSAGE );
	      post_err := __SQL_MESSAGE;
	      goto next_rec;
           };

    req := new "blogRequest" ();
    req.appkey := 'appKey';
    req.blogid := dst_id;
    req.postId := _RL_F_POST_ID;
    req.user_name := a_usr;
    req.passwd  := a_pwd;
    req.header := 'X-Virt-BlogID: ' || registry_get ('WeblogServerID') || ';' || item_id || '\r\n';

    eids := coalesce (split_and_decode (eid, 0, '\0\0;'), vector ());
    iid := trim (iid, '; ');
    iids := coalesce (split_and_decode (iid, 0, '\0\0;'), vector ());

    if (_RL_TYPE in ('I', 'U'))
      {
	if ((length (iids) and not exists
	      (select 1 from MTYPE_BLOG_CATEGORY where position (MTB_CID, iids)
	       and MTB_POST_ID = post_id and MTB_BLOG_ID = item_id))
	    or
	    exists (select 1 from MTYPE_BLOG_CATEGORY where position (MTB_CID, eids) and
	    MTB_POST_ID = post_id and MTB_BLOG_ID = item_id))
	{
	   if (0) log_message (sprintf ('Routing denied for post %s', post_id));

	   if (_RL_TYPE = 'U')
	     {
	       _RL_TYPE := 'D';
	       update SYS_BLOGS_ROUTING_LOG set RL_TYPE = 'D'
		where RL_JOB_ID = job_id and RL_POST_ID = post_id and RL_COMMENT_ID = _RL_COMMENT_ID;
	     }
	   else
	     {
	       update SYS_BLOGS_ROUTING_LOG set RL_TYPE = 'D', RL_PROCESSED = 1
		where RL_JOB_ID = job_id and RL_POST_ID = post_id and RL_COMMENT_ID = _RL_COMMENT_ID;
	       goto next;
	     }
	}
      doit:
      req.struct := BLOG_MESSAGE_OR_META_DATA (_B_META, _B_USER_ID, _B_CONTENT, _B_POST_ID, _B_TS);
    }

    if (_RL_COMMENT_ID <> -1)
      {
        declare exit handler for sqlstate '*'
    {
      if (0) log_message (__SQL_STATE || ':' || __SQL_MESSAGE );
    };
        select BM_COMMENT, BM_NAME, BM_E_MAIL, BM_HOME_PAGE, BM_ADDRESS into
          _BM_COMMENT, _BM_NAME, _BM_E_MAIL, _BM_HOME_PAGE, _BM_ADDRESS
    from BLOG_COMMENTS where BM_BLOG_ID = item_id and BM_POST_ID = _RL_POST_ID and BM_ID = _RL_COMMENT_ID;
        if (_BM_COMMENT is not null)
          _BM_COMMENT := blob_to_string (_BM_COMMENT);
              else
                _BM_COMMENT := '';
      }

    commit work;
    --dbg_printf ('upstream : [%s] proto=%d job=%d', dst, proto_id, job_id);
    if (proto_id = 1) -- Blogger
      {
	if (_RL_TYPE = 'I')
	  fpostid := blogger.new_Post (dst, req, blog_utf2wide (_B_CONTENT));
	else if (_RL_TYPE = 'U')
	  blogger.edit_Post (dst, req, blog_utf2wide (_B_CONTENT));
	else if (_RL_TYPE = 'D' and send_delete)
	  blogger.delete_Post (dst, req);
      }
    else if (proto_id = 2) -- MetaWeblog
      {
	if (_RL_TYPE = 'I')
	  fpostid := metaweblog.new_Post (dst, req);
	else if (_RL_TYPE = 'U')
	  metaweblog.edit_Post (dst, req);
	else if (_RL_TYPE = 'D' and send_delete)
	  blogger.delete_Post (dst, req);
      }
    else if (proto_id = 3) -- MoveableType
      {
	if (_RL_TYPE = 'I')
	  fpostid := metaweblog.new_Post (dst, req);
	else if (_RL_TYPE = 'U')
	  metaweblog.edit_Post (dst, req);
	else if (_RL_TYPE = 'D' and send_delete)
	  blogger.delete_Post (dst, req);
      }
    else if (proto_id = 5) -- Atom
      {
	if (_RL_TYPE = 'I')
	  fpostid := atom.new_Post (dst_id, req);
	else if (_RL_TYPE = 'U')
	  atom.edit_Post (req.postId, req);
	else if (_RL_TYPE = 'D' and send_delete)
	  atom.delete_Post (req.postId, req);
      }
    else if (proto_id = 4)
      {
        declare oemail, emails, hdrs, _bi_home, _bi_title, host varchar;
        declare mime_parts any;
        select BI_E_MAIL, BI_HOME, BI_TITLE into oemail, _bi_home, _bi_title from SYS_BLOG_INFO where BI_BLOG_ID = item_id;
	commit work;
        if (_RL_TYPE = 'I')
    {
      mime_parts := vector (0,
        DB.DBA.MIME_PART ('text/html; charset=UTF-8', null, null, _B_CONTENT));
        hdrs := BLOG_MAKE_MAIL_SUBJECT ('[Weblog post] '||_B_TITLE);

      for select BV_NAME, BV_E_MAIL, BV_POST_ID, BV_VIA_DOMAIN from SYS_BLOG_VISITORS
         where BV_NOTIFY = 1 and BV_BLOG_ID = item_id and length (BV_E_MAIL)
          and (BV_POST_ID = _RL_POST_ID or length (BV_POST_ID) = 0)
        do
          {

      host := BLOG_GET_HOST ();

      mime_parts[0] := DB.DBA.MIME_PART ('text/plain; charset=UTF-8', null, null,
      sprintf ('%s,\r\nThere\'s a new post %s (http://%s%s?id=%s)\r\n in %s (http://%s%s).\r\n\r\nTo stop receiving notifications click\r\nhttp://%s/weblog/public/r_unsubscribe.vspx?e=%U&b=%U&p=%U\r\n',

         coalesce (BV_NAME, 'Dear subscriber'),
         _B_TITLE,
         host, _bi_home, _RL_POST_ID,
         _bi_title,
         host, _bi_home,
         host,
         BV_E_MAIL, item_id, BV_POST_ID));
       smtp_send (dst, oemail, BV_E_MAIL, concat (hdrs, DB.DBA.MIME_BODY (mime_parts)));
          }

      update SYS_BLOGS_ROUTING_LOG set RL_TYPE = 'D'
        where RL_JOB_ID = job_id and RL_POST_ID = post_id and RL_COMMENT_ID = _RL_COMMENT_ID;
    }
        else if (_RL_TYPE = 'CI')
    {
      mime_parts := vector (0,
        DB.DBA.MIME_PART ('text/html; charset=UTF-8', null, null, _BM_COMMENT));
        hdrs := BLOG_MAKE_MAIL_SUBJECT ('[Weblog post comment] Re: '||_B_TITLE||' from '||coalesce (_BM_NAME, _BM_E_MAIL, '<unknown sender>'));

      for select BV_NAME, BV_E_MAIL,BV_POST_ID, BV_VIA_DOMAIN from SYS_BLOG_VISITORS
          where BV_NOTIFY = 1 and BV_BLOG_ID = item_id
             and (BV_POST_ID = _RL_POST_ID or length (BV_POST_ID) = 0)
        do
          {
	    if (BV_E_MAIL = _BM_E_MAIL)
	      goto next_mail;

      host := BLOG_GET_HOST ();

      mime_parts[0] := DB.DBA.MIME_PART ('text/plain; charset=UTF-8', null, null,
      sprintf ('%s,\r\nThere\'s a new comment Re. %s (http://%s%s?id=%s) in %s (http://%s%s).\r\n\r\nTo stop receiving notifications click \r\nhttp://%s/weblog/public/r_unsubscribe.vspx?e=%U&b=%U&p=%U\r\n',
      coalesce (BV_NAME, 'Dear subscriber'),
            _B_TITLE,
            host, _bi_home, _RL_POST_ID,
            _bi_title,
            host, _bi_home,
            host,
            BV_E_MAIL, item_id, BV_POST_ID));
            smtp_send (dst, oemail, BV_E_MAIL, concat (hdrs, DB.DBA.MIME_BODY (mime_parts)));
	    next_mail:;
          }

      update SYS_BLOGS_ROUTING_LOG set RL_TYPE = 'D'
        where RL_JOB_ID = job_id and RL_POST_ID = post_id and RL_COMMENT_ID = _RL_COMMENT_ID;
    }
      }
    else if (proto_id = 6)
      {
  if (_RL_TYPE = 'I')
    {
      fpostid := BLOG_DELICIOUS_ADD (post_id, dst_id, a_usr, a_pwd);
    }
  else if (_RL_TYPE = 'U')
    {
      BLOG_DELICIOUS_DEL (fpostid, a_usr, a_pwd);
      fpostid := BLOG_DELICIOUS_ADD (post_id, dst_id, a_usr, a_pwd);
    }
  else if (_RL_TYPE = 'D' and send_delete)
    {
      BLOG_DELICIOUS_DEL (fpostid, a_usr, a_pwd);
    }
      }
    }
          next_rec:;
            update SYS_BLOGS_ROUTING_LOG set RL_F_POST_ID = fpostid, RL_PROCESSED = post_stat, RL_ERROR = post_err,
		   RL_RETRANSMITS = _RL_RETRANSMITS
    where RL_JOB_ID = job_id and RL_POST_ID = post_id and RL_COMMENT_ID = _RL_COMMENT_ID;
          next:;
       }
enf:
   delete from SYS_BLOGS_ROUTING_LOG where RL_PROCESSED = 1 and RL_TYPE = 'D';
   update SYS_BLOGS_ROUTING_LOG set RL_PROCESSED = 0 where RL_JOB_ID = job_id and RL_RETRANSMITS > 0 and RL_PROCESSED = 2;
   rc := row_count ();
   return rc;
}
;

create procedure BLOG..not_same_day (inout d1 any, inout d2 any)
{
  if (dayofyear (d1) = dayofyear (d2) and year (d1) = year (d2))
    {
      return 0;
    }
  return 1;
}
;

create procedure BLOG..not_same_month (inout d1 any, inout d2 any)
{
  if (month (d1) = month (d2) and year (d1) = year (d2))
    {
      return 0;
    }
  return 1;
}
;

create procedure DB.DBA.BLOG_MAIL_VALIDATE (in login any)
{
  declare opts, dummy, bid, sec, U_NAME any;
  whenever not found goto noblog;

  if (regexp_match ('^[A-Za-z0-9 _@\.]+-blog-[0-9]+\.[A-Za-z0-9]+\$', login) is not null)
    {
      bid := regexp_match ('^[A-Za-z0-9 _@\.]+-blog-[0-9]+\.', login);
      sec := substring (login, length (bid) + 1, length (login));
      bid := rtrim (bid, '.');
      --dbg_obj_print (login, bid, sec);
      SELECT BI_OPTIONS into opts from BLOG..SYS_BLOG_INFO where BI_BLOG_ID = bid;
      opts := deserialize (blob_to_string (opts));
      if (isarray (opts) and get_keyword ('MoblogSecret', opts, '') = sec)
	{
	  result (bid);
	  return 1;
	}
    }

  noblog:
  return 0;
}
;


create procedure BLOG.DBA.MOBLOG_MAIL_VALIDATE (in login any)
{
  declare opts, dummy, bid, sec, U_NAME, rc any;

  result_names (U_NAME);

  whenever not found goto nouser;
  SELECT u.U_NAME into dummy FROM WS.WS.SYS_DAV_USER u WHERE u.U_NAME = login AND U_ACCOUNT_DISABLED=0;
  result (dummy);
  return 1;

  nouser:
  rc := DB.DBA.BLOG_MAIL_VALIDATE (login);
  return rc;
}
;


create procedure BLOG..ADD_CONTACT_FROM_FEED (in url1 any, in blogid any)
{
  declare res, url, hdr, home, tit  any;
  declare xt, xp, mail, author any;

  whenever not found goto nff;
  select BCD_HOME_URI, BCD_TITLE into home, tit from BLOG.DBA.SYS_BLOG_CHANNEL_INFO where BCD_CHANNEL_URI = url1;
  declare exit handler for sqlstate '*'
    {
      rollback work;
      return;
    };
  url := url1;
  commit work;
  res := GET_URL_AND_REDIRECTS (url, hdr);
  xt := xtree_doc (res, 2, '', 'UTF-8');
  if (xpath_eval ('/feed', xt) is not null)
    {
      mail := xpath_eval ('/feed/author/email/text()', xt);
      author := xpath_eval ('/feed/author/name/text()', xt);
    }
  else if (xpath_eval ('/rss', xt) is not null)
    {
      mail := xpath_eval ('/channel/managingEditor/text()', xt);
      author := tit;
    }
  else
    {
      return 0;
    }
  insert soft BLOG.DBA.SYS_BLOG_CONTACTS (BF_BLOG_ID, BF_NAME, BF_MBOX, BF_HOMEPAGE, BF_WEBLOG, BF_RSS) values
      (blogid, author, mail, home, home, url1);
  nff:;
}
;

create procedure BLOG..BLOG_TAGS_RESULT (in data any)
{
  declare tag varchar;
  declare n int;
  result_names (tag, n);
  foreach (any t in data) do
    {
      result (t[0], t[1]);
    }
}
;


create procedure BLOG..CHANNELS_UPGRADE ()
{
  if (not exists (select 1 from BLOG..SYS_BLOG_CHANNEL_INFO where BCD_AUTHOR_NAME is null))
    return;
  update BLOG..SYS_BLOG_CHANNEL_INFO set BCD_AUTHOR_NAME = BCD_TITLE, BCD_AUTHOR_EMAIL = '' where BCD_AUTHOR_NAME is null;
}
;

BLOG..CHANNELS_UPGRADE ()
;


create procedure BLOG..BLOG_MAKE_ENCLOSURE (in url any)
{
  declare enc BLOG.DBA."MWeblogEnclosure";
  declare h, ourl, len any;

  if (not length (url))
    return null;

  enc := new BLOG.DBA."MWeblogEnclosure" ();
  enc.url := url;
  h := null;
  again:
  ourl := url;

  http_get (url, h, 'HEAD');

  if (h[0] like 'HTTP/1._ 30_ %')
    {
      url := http_request_header (h, 'Location');
      if (isstring (url))
	goto again;
    }
  else if (h[0] not like 'HTTP/1._ 200 %')
    signal ('22023', trim(h[0], '\r\n'), 'BLOG2');

  len := http_request_header (h, 'Content-Length');
  if (not isstring (len))
    len := '0';
  enc."length" := atoi (len);
  enc."type" := http_request_header (h, 'Content-Type');

  if (enc."length" < 1)
    signal ('22023', 'The supplied URL do not reference any valid resource (content length is zero bytes)');

  return enc;
}
;

-- BlogAPI
create procedure BLOG_API_INIT ()
{
  if (not exists (select 1 from "DB"."DBA"."SYS_USERS" where U_NAME = 'BLOG_API'))
    {
      DB.DBA.USER_CREATE ('BLOG_API', uuid(), vector ('DISABLED', 1, 'LOGIN_QUALIFIER', 'BLOG'));
    }
}
;

BLOG_API_INIT ()
;


create procedure "Search"
	(
	 in blogId varchar,
	 in q nvarchar,
	 in maxResults int := 10,
	 in startDate datetime := null,
	 in endDate datetime := null,
	 in category varchar := null,
	 in tags varchar := null
	)
	returns DB.DBA.XMLType
{
  declare xt DB.DBA.XMLType;
  declare ses, xd any;
  declare home, host varchar;

  ses := string_output ();
  set http_charset='utf-8';
  set_user_id ('dba');

  q := blog_wide2utf (q);

  if (not isinteger (maxResults))
    maxResults := 10;
  if (maxResults < 0 or maxResults > 1000)
    signal ('22023', 'Invalid maxResults input, must be greater than 0 and less than 1000.');

  declare exit handler for not found
    {
      signal ('22023', 'No such blog');
    };
  select BI_HOME into home from SYS_BLOG_INFO where BI_BLOG_ID = blogId;
  host := BLOG_GET_HOST ();

  http ('<result>', ses);
  -- BEGIN
  {
          declare stat, msg, dta, mdta, h, pars, dexp, twhere, atb any;
	  declare qstr, qry varchar;

          qstr := DB.DBA.FTI_MAKE_SEARCH_STRING (q);
	  dexp := '';
	  pars := vector ('', blogId, blogId, qstr);

	  if (startDate is not null)
	    {
	      dexp := ' and B_TS >= ? ';
	      pars := vector_concat (pars, vector (startDate));
	    }
	  if (endDate is not null)
	    {
	      dexp := dexp || ' and B_TS <= ? ';
	      pars := vector_concat (pars, vector (endDate));
	    }

	  if (length (category))
	    {
	      dexp := dexp || ' and exists (select 1 from BLOG..MTYPE_BLOG_CATEGORY, BLOG..MTYPE_CATEGORIES
	      where MTB_CID = MTC_ID and MTC_BLOG_ID = MTB_BLOG_ID and MTB_POST_ID = B_POST_ID and
	      strcasestr (MTC_NAME, ?) is not null)';
	      pars := vector_concat (pars, vector (category));
	    }

	  atb := '';
	  twhere := '';

	  if (length (tags))
	    {
	      atb := ' BLOG..BLOG_TAG a, ';
	      twhere :=
	      sprintf (' contains (BT_TAGS,
		    ''[__lang "x-ViDoc"] %s and %s'', offband, BT_POST_ID) and BT_POST_ID = B_POST_ID and ',
	      DB.DBA.FTI_MAKE_SEARCH_STRING (tags), 'b'||replace(blogId, '-', '_'));
	    }

	  qry := 'select top ' || cast (maxResults as varchar) ||
	  	' NULL, concat (?,\'?id=\', B_POST_ID), B_TITLE,
	  	B_USER_ID, B_TS, B_MODIFIED, b.SCORE, B_POST_ID
	    from ' || atb || ' BLOG..SYS_BLOGS b,
	    (select BI_BLOG_ID as BA_C_BLOG_ID, BI_BLOG_ID as BA_M_BLOG_ID
	    	from BLOG..SYS_BLOG_INFO where BI_BLOG_ID = ? union all
		select * from (select BA_C_BLOG_ID, BA_M_BLOG_ID
		from BLOG.DBA.SYS_BLOG_ATTACHES where BA_M_BLOG_ID = ?) name1) name2
	    where ' || twhere || 'B_BLOG_ID = BA_C_BLOG_ID and contains (B_CONTENT, ?) ' || dexp || '
	    order by ';

	  qry := qry || ' b.SCORE desc';

	  stat := '00000';
	  exec (qry, stat, msg, pars, 0, null, null, h);
	  if (stat <> '00000')
	    signal (stat, msg);

	  while (0 = exec_next (h, null, null, dta))
            {
               --dbg_obj_print (dta);
	       http ('<entry>', ses);
	       http (sprintf ('<title><![CDATA[%s]]></title>', dta[2]), ses);
	       http (sprintf ('<link>http://%s%sindex.vspx%s</link>', host, home, dta[1]), ses);
	       http (sprintf ('<published>%s</published>', DB.DBA.date_iso8601 (dta[4])), ses);
	       http (sprintf ('<score>%d</score>', dta[6]), ses);
	       http (sprintf ('<id>%s</id>', dta[7]),ses);
	       http ('</entry>', ses);
            }
	  exec_close (h);
  }
  -- END

  http ('</result>', ses);
  ses := string_output_string (ses);
  xd := xtree_doc (ses, 0, '', 'UTF-8');
  xml_tree_doc_encoding (xd, 'UTF-8');
  xt := new DB.DBA.XMLType (xd);
  return xt;
};


grant execute on "Search" to BLOG_API;


create procedure BLOG_ARCH_DATE_POSTS (in blogid varchar, in sel varchar := null, in community int)
{
  declare dta, mdta, h, pars any;
  declare sqlstr, arch_str varchar;
  declare d1, d2 any;

  arch_str := '';
  sel := trim (sel);
  if (sel is not null and length (sel))
    {
      if (sel like '%-%-%')
	{
	  d1 := stringdate (sel);
	  d2 := dateadd ('day', 1, d1);
	}
      else if (sel like '%-%')
	{
	  d1 := stringdate (sel || '-01');
	  d2 := dateadd ('month', 1, d1);
	}
      else
	{
	  d1 := stringdate (sel || '-01-01');
	  d2 := dateadd ('year', 1, d1);
	}
      arch_str := sprintf (' and B_TS >= \'%s\' and B_TS < \'%s\' ',
      datestring (cast (d1 as date)), datestring (cast (d2 as date)));
    }


  if (community)
    {
      pars := vector (blogid, blogid);
      sqlstr := 'select B_TS, B_TITLE, B_POST_ID from BLOG..SYS_BLOGS, (select BI_BLOG_ID as BA_C_BLOG_ID, BI_BLOG_ID as BA_M_BLOG_ID from BLOG..SYS_BLOG_INFO where BI_BLOG_ID = ? union all select * from (select BA_C_BLOG_ID, BA_M_BLOG_ID from BLOG.DBA.SYS_BLOG_ATTACHES where BA_M_BLOG_ID = ?) name1) name2 where B_BLOG_ID = BA_C_BLOG_ID ';
    }
  else
    {
      pars := vector (blogid);
      sqlstr := 'select B_TS, B_TITLE, B_POST_ID from BLOG..SYS_BLOGS where B_BLOG_ID = ?';
    }
  sqlstr := sqlstr || arch_str;
  exec (sqlstr, null, null, pars, 0, mdta, null, h);
  exec_result_names (mdta[0]);
  while (0 = exec_next (h, null, null, dta))
    exec_result (dta);
  exec_close (h);
};


 blog2_exec_no_error ('create procedure view BLOG_ARCH_DATE_POSTS as BLOG.DBA.BLOG_ARCH_DATE_POSTS (blogid, sel, community)
    (B_TS datetime, B_TITLE varchar, B_POST_ID varchar)');


create procedure get_date_array (in dt date)
{
  declare i, l int;
  declare m, y, w, d int;
  declare dw, dm int;
  declare arr, res any;

  arr := vector ('','','','','','','');
  i := 0;
  m := month (dt);
  y := year (dt);
  dm := BLOG..GET_DAYS_IN_MONTH (dt);

  res := vector ();
  i := 1;
  while (i <= dm)
    {
      declare tmp date;
      whenever sqlstate '*' goto endd;
      tmp := stringdate (sprintf ('%d-%d-%d', y, m, i));
      if (i > 1 and dayofmonth (tmp) = 1)
        goto endd;
      dw := dayofweek(tmp);
      aset (arr, dw - 1, cast (i as varchar));
      if (0 = mod (dw, 7))
        {
          res := vector_concat (res, vector (arr));
          arr := vector ('','','','','','','');
        }
      i := i + 1;
    }
endd:
  res := vector_concat (res, vector (arr));
  return res;
}
;


create procedure make_dasboard_item
	(in what varchar, in tim datetime, in title varchar, in uname varchar, in url varchar, in comment varchar,
	in dash any, in id any := -1, in action varchar := 'insert', in u_name varchar := null, in mail varchar := null)
{
  declare ret any;
  declare ses, ses1 any;

  if (not __proc_exists ('DB.DBA.WA_NEW_BLOG_IN'))
    return null;

  --dbg_printf ('make_dasboard_item what=[%s] action=[%s] id=[%s]', what, action, cast(id as varchar));

  if (isinteger (mail))
    mail := '';

  ses := string_output ();
  ses1 := string_output ();

  http ('<blog-db>', ses);

  if (what = 'post' and isstring (id))
    id := atoi (id);

  if (dash is not null)
    {
      declare xt, xp any;
      declare i, l int;
      xt := xtree_doc (dash);
      xp := xpath_eval ('/blog-db/*', xt, 0);
      l := length (xp);
      if (l = 10 and action = 'insert')
        i := 1;
      else
        i := 0;

      if (l > 10)
        l := 10;

      for (;i < l; i := i + 1)
        {
	  declare pid, cwhat any;
	  pid := xpath_eval ('number(@id)', xp[i]);
	  cwhat := cast (xpath_eval ('local-name ()', xp[i]) as varchar);
	  if (pid is null)
	    pid := -2;
	  if (action = 'insert' or pid <> id or cwhat <> what)
	    http (serialize_to_UTF8_xml (xp[i]), ses1);
	  --else
	  --  dbg_printf ('skiping what=[%s] id=[%d]', cwhat, pid);
        }
    }

  if (action = 'insert' or action = 'update')
    {
      ret := null;
      if (what = 'post')
	{
	  ret := sprintf (
	  '<post id="%d">'||
	  '<title><![CDATA[%s]]></title>'||
	  '<dt>%s</dt>'||
	  '<link>%V</link>'||
	  '<from><![CDATA[%s]]></from>'||
	  '<uid><![CDATA[%s]]></uid>'||
	  '</post>'
	  , id, title, date_iso8601 (tim), url, uname, u_name);
	}
      else if (what = 'comment')
	{
	  ret := sprintf (
	  '<comment id="%d">'||
	  '<dt>%s</dt>'||
	  '<from><![CDATA[%s]]></from>'||
	  '<for><![CDATA[%s]]></for>'||
	  '<link>%V</link>'||
	  '<title><![CDATA[%s]]></title>'||
	  '<email><![CDATA[%s]]></email>'||
	  '</comment>',
	  id, date_iso8601 (tim), uname, title, url, trim(regexp_replace (blob_to_string (comment), '<[^>]+>', '', 1, null)), mail
	  );
	}
      http (ret, ses);
   }
  http (string_output_string (ses1), ses);
  http ('</blog-db>', ses);
  ret := string_output_string (ses);
  return ret;
};

create procedure SUGGEST_TB_URLS (in txt any)
{
  declare xt, xp, ret any;
  xt := xml_tree_doc (xml_tree (txt, 2));
  xp := xpath_eval ('//a[@href]/@href', xt, 0);
  commit work;
  ret := vector ();
  foreach (any link in xp) do
     {
       declare hdr, content, trackback any;
       hdr := null;
       declare exit handler for sqlstate '*'
	 {
	   goto nextl;
	 };
       content := GET_URL_AND_REDIRECTS (cast (link as varchar), hdr);
       xt := xml_tree_doc (xml_tree (content, 2));
       trackback := GET_BLOG_TB_URLS (xt);
       foreach (any tb in trackback) do
	 {
	   ret := vector_concat (ret, vector (vector(tb)));
         }
       nextl:;
     }
  return ret;
};


create procedure
metaweblog.get_Recent_Posts (in uri varchar, in req "blogRequest", in lim int)
{
  declare ret, xe, arr any;
  declare i, l int;
  declare post any;
  ret := DB.DBA.XMLRPC_CALL (uri, 'metaWeblog.getRecentPosts',
         vector (req.blogid, req.user_name, req.passwd, lim));
  ret := xml_tree_doc (ret);
  xe := xpath_eval ('//Param1/item', ret, 0);
  arr := vector (); i := 0; l := length (xe);
  while (i < l)
    {
      ret := xml_cut (xe[i]);
      post := soap_box_xml_entity_validating (ret, '', 0, 'BLOG.DBA.MTWeblogPost');
      arr := vector_concat (arr, vector(post));
      i := i + 1;
    }
enf:
  return arr;
}
;


create procedure IMPORT_PARSE_FEED (inout xt any)
    {
  declare title, content, published, postid, tmp, posts any;
      declare res "MTWeblogPost";
      declare i int;

  posts := null;

      if (xpath_eval ('/rss', xt) is not null)
        {
          tmp := xpath_eval ('/rss/channel/item', xt, 0);
	  posts := make_array (length (tmp), 'any');
	  i := 0;
	  foreach (any x in tmp) do
	    {
	      title := xpath_eval ('string(title)', x);
	      content := xpath_eval ('string(description)', x);
	      published := cast (xpath_eval ('string(pubDate)', x) as varchar);
	      postid := xpath_eval ('string(postid)', x);
	      res := new "MTWeblogPost" ();
	      res.title := title;
	      if (length (published))
	        res.dateCreated := http_string_date (published);
	      res.postid := postid;
	      res.description := content;
	      posts[i] := res;
	      i := i + 1;
	    }
	}
      else if (xpath_eval ('/feed', xt) is not null)
        {
          tmp := xpath_eval ('/feed/entry', xt, 0);
	  posts := make_array (length (tmp), 'any');
	  i := 0;
	  foreach (any x in tmp) do
	    {
	      title := xpath_eval ('string(title)', x);
	      content := xpath_eval ('string(content)', x);
	      published := cast (xpath_eval ('string(published)', x) as varchar);
	      postid := xpath_eval ('string(id)', x);
	      res := new "MTWeblogPost" ();
	      res.title := title;
	      if (length (published))
		res.dateCreated := stringdate (published);
	      res.postid := postid;
	      res.description := content;
	      posts[i] := res;
	      i := i + 1;
	    }
	}
      else if (xpath_eval ('/RDF', xt) is not null)
        {
          tmp := xpath_eval ('/RDF/item', xt, 0);
	  posts := make_array (length (tmp), 'any');
	  i := 0;
	  foreach (any x in tmp) do
	    {
	      title := xpath_eval ('string(title)', x);
	      content := xpath_eval ('string(description)', x);
	      published := cast (xpath_eval ('string(date)', x) as varchar);
	      postid := xpath_eval ('string(@about)', x);
	      res := new "MTWeblogPost" ();
	      res.title := title;
	      if (length (published))
		res.dateCreated := stringdate (published);
	      res.postid := postid;
	      res.description := content;
	      posts[i] := res;
	      i := i + 1;
	    }
	}
  return posts;
    }
;

create procedure IMPORT_INSERT_POSTS (inout posts any, in blogid any, in user_id any)
{
  foreach (any x in posts) do
    {
      declare title, content, pub, id any;
      declare meta "MTWeblogPost";
      id := cast (sequence_next ('blogger.postid') as varchar);
      if (udt_instance_of ('BLOG.DBA.MTWeblogPost', x))
	{
	  declare p "MTWeblogPost";
	  p := x;
	  title := blog_wide2utf (p.title);
	  content := blog_wide2utf (p.description);
	  pub := p.dateCreated;
	  meta := x;
	  meta.title := title;
	  meta.description := null;
	}
      else
	{
	  declare p "blogPost";
	  p := x;
	  title := null;
	  content := blog_wide2utf (p.content);
	  pub := p.dateCreated;
	  meta := null;
	}

      insert into BLOG.DBA.SYS_BLOGS (B_APPKEY, B_POST_ID, B_BLOG_ID, B_TS, B_CONTENT, B_USER_ID, B_META, B_STATE, B_TITLE)
	  values ('Import', id, blogid, pub, content, user_id, meta, 2, title);
    }
}
;

create procedure
IMPORT_BLOG (in blogid varchar, in user_id int, in url varchar, in api varchar, in bid varchar, in uid varchar, in pwd varchar, in hub varchar := null)
{
  declare tmp, xt, cnt, hdr, rc any;
  declare posts any;

  url := cast (url as varchar);
  api := cast (api as varchar);
  bid := cast (bid as varchar);
  uid := cast (uid as varchar);
  pwd := cast (pwd as varchar);

  rc := 0;
  if (length (bid) = 0) -- import from a feed
    {
      cnt := BLOG..GET_URL_AND_REDIRECTS (url, hdr);
      xt := xtree_doc (cnt);
      posts := IMPORT_PARSE_FEED (xt);
    }
  else -- import using an api
    {
      if (api = 'MetaWeblog' or api = 'MoveableType')
	{
	  posts := metaweblog.get_Recent_Posts (url, BLOG.DBA."blogRequest" ('appKey', bid, '', uid, pwd), 100);
	}
      else -- use blogger
	{
	  posts := blogger.get_Recent_Posts (url, BLOG.DBA."blogRequest" ('appKey', bid, '', uid, pwd), 100);
	}
    }
  IMPORT_INSERT_POSTS (posts, blogid, user_id);
  if (length (hub))
    {
      declare token, subsu, callback, head, ret varchar;
      declare inst int;

      inst := (select WAI_ID from BLOG.DBA.SYS_BLOG_INFO, DB.DBA.WA_INSTANCE where BI_WAI_NAME = WAI_NAME and BI_BLOG_ID = blogid);
      PSH.DBA.ods_cli_subscribe (inst, hub, 'subscribe', url);
    }
  return length (posts);
};

create procedure PSH.DBA.ods_weblog_psh_cbk (in url varchar, in content any, in inst any)
{
  declare xt, posts, blogid, user_id any;

  for select BI_BLOG_ID, BI_OWNER from BLOG.DBA.SYS_BLOG_INFO, DB.DBA.WA_INSTANCE where BI_WAI_NAME = WAI_NAME and WAI_ID = inst do
    {
      blogid := BI_BLOG_ID;
      user_id := BI_OWNER; 
    }
  xt := xtree_doc (content);
  posts := IMPORT_PARSE_FEED (xt);
  IMPORT_INSERT_POSTS (posts, blogid, user_id);
}
;

-- /* re-tagging */
create procedure blog_tag2str (inout tags any)
{
  declare s any;
  declare i int;

  s := string_output ();
  for (i := 0; i < length (tags); i := i + 2)
  {
    http (sprintf ('%s,', tags[i]), s);
  }
  return rtrim(string_output_string (s), ', ');
}
;

create procedure RE_TAG_POST (in blogid varchar, in post_id varchar, in user_id int, in inst_id int,
    inout content any, in keep_existing int, inout xt any, in job int := null, in rules any := null, in auto_tag int := 1)
{
  declare moat_tags, tags, tagstr, comp_tags, existing_tags any;
  declare flag varchar;
  if (rules is null)
    rules := DB.DBA.user_tag_rules (user_id);
  if (auto_tag)
    {
      tags := DB.DBA.tag_document_with_moat (content, 0, rules);
    }
  else
    tags := vector ();
  moat_tags := tags;
  tagstr := blog_tag2str (tags);
  if (keep_existing)
    {
      --dbg_obj_print ('>>>add tags');
      existing_tags := coalesce (
      (select BT_TAGS from BLOG..BLOG_TAG where BT_BLOG_ID = blogid and BT_POST_ID = post_id), '');
      existing_tags := split_and_decode (existing_tags, 0, '\0\0,');
      if (existing_tags is null)
	existing_tags := vector ();

	comp_tags := vector ();
	foreach (any t in existing_tags) do
	  {
	    t := trim(lower (cast (t as varchar)));
	    if (length(t) and not position (t, comp_tags))
	      comp_tags := vector_concat (comp_tags, vector (t));
	  }

	foreach (any t in comp_tags) do
	  {
	    t := trim(lower (cast (t as varchar)));
	    if (length (t) and not position (t, tags))
	      tagstr := tagstr || ', ' || t;
	  }
	  tags := vector_concat (tags, comp_tags);
    }
  --dbg_obj_print ('existing_tags', existing_tags);
  --dbg_obj_print ('tags', tags);
    {
      declare xp any;
      if (xt is null)
        xt := xtree_doc (content, 2, '', 'UTF-8');
      xp := xpath_eval ('//a[@rel="tag"]/text()', xt, 0);
      --dbg_obj_print  ('embedded', xp);
      foreach (any t in xp) do
	{
	  t := trim(lower (cast (t as varchar)));
	  if (length (t) and not position (t, tags))
	    tagstr := tagstr || ', ' || t;
	}
    }

    tagstr := trim (tagstr, ', ');

    --dbg_obj_print ('tagstr',tagstr);

    flag := null;
    if (length (tagstr))
      {
	delete from BLOG..BLOG_TAG where BT_BLOG_ID = blogid and BT_POST_ID = post_id;
	delete from moat.DBA.moat_meanings where m_inst = inst_id and m_id = post_id;
	for (declare i, l int, i := 0, l := length (moat_tags); i < l; i := i + 2)
	{
	  declare tag, arr any;
	  tag := moat_tags[i];
	  arr := moat_tags[i+1];
	  foreach (any turi in arr) do
	    {
	      insert replacing moat.DBA.moat_meanings (m_inst, m_id, m_tag, m_uri, m_iri)
		  values (inst_id, post_id, tag, turi,
		      iri_to_id (sioc..blog_post_iri (blogid, post_id)));
	    }
	}

	insert replacing BLOG..BLOG_TAG (BT_BLOG_ID, BT_POST_ID, BT_TAGS) values (blogid, post_id, tagstr);
	if (job is not null)
	  {
	    if (exists (select 1 from BLOG..SYS_BLOGS_ROUTING_LOG where RL_JOB_ID = job and RL_POST_ID = post_id))
	      flag := 'U';
	    else
	      flag := 'I';
	  }
      }
    else
      {
	if (job is not null and exists (select 1 from BLOG..SYS_BLOGS_ROUTING_LOG where RL_JOB_ID = job and RL_POST_ID = post_id))
	  flag := 'D';
	delete from BLOG..BLOG_TAG where BT_BLOG_ID = blogid and BT_POST_ID = post_id;
      }
   return flag;
}
;

CREATE FUNCTION BLOG..GET_DAYS_IN_MONTH (in pDate  DATETIME) RETURNS INT
{
    RETURN CASE WHEN MONTH(pDate) IN (1, 3, 5, 7, 8, 10, 12) THEN 31
                WHEN MONTH(pDate) IN (4, 6, 9, 11) THEN 30
                ELSE CASE WHEN (mod (YEAR(pDate), 4)    = 0 AND
                                mod (YEAR(pDate), 100)  <> 0) OR
                               (mod (YEAR(pDate), 400)  = 0)
                          THEN 29
                          ELSE 28
                     END
           END;

}
;

create procedure BLOG..BLOG_RESOLVE_REFS (in txt any)
{
  declare a any;
  a := regexp_replace (txt, '((http://|https://|mailto:|ftp:)[^ ]+)', '<a href="\\1">\\1</a>', 1, null);
  a := regexp_replace (a, '(@)([[:alnum:]]+)(:)', '\\1<a href="/dataspace/person/\\2">\\2</a>\\3', 1, null);
  a := regexp_replace (a, '([[:alnum:]]+)(@)([[:alnum:]]+\\.[[:alnum:]]+)', '<a href="mailto:\\1@\\3">\\1@\\3</a>', 1, null);
  return '<div>' || a || '</div>';
}
;

