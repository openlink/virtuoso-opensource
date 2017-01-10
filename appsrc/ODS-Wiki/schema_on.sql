--  
--  $Id$
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

create procedure wiki_exec_no_error (in text varchar)
{
  log_enable(1);
  declare exit handler for sqlstate  '*' {
	rollback work;
	return;
  };
  exec (text);
  commit work;
}
;

create procedure WV.Wiki.EXEC_41000_I (in _expn varchar)
{
  declare _state, _message varchar;
  declare _retries integer;
  _state := '';
  _retries := 0;
  while(1)
    {
      exec (_expn, _state, _message);
      if (_state <> '41000')
	return;
      if (_retries > 10)
	signal ('41000', concat ('Continuous deadlocks in\n', _expn, '\n'));
      _retries := _retries+1;
    }
}
;



-- Groups of Wiki users.
wiki_exec_no_error (
 'create table WV.WIKI.GROUPS (
    GroupId	integer not null, 	-- Id (cloned from DB.DBA.SYS_USERS."U_ID").
    GroupName	varchar(30) not null,	-- Name as it is shown on pages (WikiName is preferable).
    BbsTopicId	integer,		-- Unused for a while, will be ID of "personal page" of the group.
    SecurityCmt	long varchar,		-- Group description, esp. security policy for the group - for admins only.
--    constraint "Group_InSysGroup" foreign key (GroupId) references DB.DBA.SYS_USERS ("U_ID") on update set null on delete set null,
    primary key (GroupId)
  )')
;


-- System users who can use Wiki.
wiki_exec_no_error (
'create table WV.WIKI.USERS (
  UserId		integer not null,	-- Id (cloned from DB.DBA.SYS_USERS."U_ID").
  UserName		varchar(30) not null,	-- Name as it is shown on pages (WikiName is preferable).
  PersonalTopicId	integer,		-- Unused for a while, will be ID of "personal page" of the user.
  MainGroupId		integer not null,	-- Group Id to use as DAV owner group for pages created by the user.
  SecurityCmt		long varchar,		-- User description, esp. security policy for the group - for admins only.
  DefaultPermission	varchar,

  constraint "User_InGroup2" foreign key (MainGroupId) references WV.WIKI.GROUPS (GroupId) on update set null on delete set null,
  -- constraint "User_InSysUsers"  foreign key (UserId) references DB.DBA.SYS_USERS (U_ID) on update set null on delete cascade,
  primary key (UserId)
)')
;

wiki_exec_no_error (
  'alter table WV.WIKI.USERS drop constraint "User_InSysUsers"' )
;

-- Membership of Wiki users in Wiki groups
wiki_exec_no_error (
'create table WV.WIKI.MEMBERSHIP (
  GroupId		integer not null,
  UserId		integer not null,
  SecurityCmt		long varchar,		-- User description from groups perspective, esp. security policy - for admins only.
  constraint "Membership_InGroup2" foreign key (GroupId) references WV.WIKI.GROUPS (GroupId) on update set null on delete set null,
  constraint "Membership_InUser2" foreign key (UserId) references WV.WIKI.USERS (UserId) on update set null on delete set null,
  primary key (GroupId, UserId)
)')
;


wiki_exec_no_error (
'drop table "WV"."Wiki"."AppErrors"')
;
-- Application errors (unused for a while)
wiki_exec_no_error (
'create table WV.WIKI.APPERRORS (
  AppErrNo	integer not null identity, 
  AppErrText	long varchar,
  primary key (AppErrNo)
)')
;

wiki_exec_no_error (
'alter table WV.WIKI.APPERRORS add AppErrLanguage varchar (3)' )
;

-- Cluster of Wiki topics
wiki_exec_no_error (
'create table WV.WIKI.CLUSTERS (
  ClusterId		integer not null,	-- Positive randomized integer ID.
  ClusterName		varchar not null,	-- Visible name of the cluster.
  ColId		integer not null,	-- DAV_COL_ID of collection with raw texts of pages.
  ColHistoryId	integer not null,	-- DAV_COL_ID of collection with versioning data (unused).
  ColAttachId		integer not null,	-- DAV_COL_ID of collection with special attachments (unused).
  ColXmlId		integer not null,	-- DAV_COL_ID of collection with compiled pages.
  AdminId		integer not null,	-- Administrator; he should own the DAV collection with raw texts.
  primary key (ClusterId)
)')
;

wiki_exec_no_error ('alter table "WV"."Wiki"."Cluster" drop foreign key ("AdminId") references "WV"."Wiki"."Cluster" ("UserId") on update set null on delete cascade')
;

wiki_exec_no_error ('alter table WV.WIKI.CLUSTERS add constraint "Cluster_InUser2" foreign key (AdminId) references WV.WIKI.CLUSTERS (UserId) on update set null on delete cascade')
;


wiki_exec_no_error('
create index ClusterByName on WV.WIKI.CLUSTERS (ClusterName)'
)
;
wiki_exec_no_error('
create index ClusterByColId on WV.WIKI.CLUSTERS (ColId)'
)
;

wiki_exec_no_error (
'alter table WV.WIKI.CLUSTERS add C_NEWS_ID varchar' 
)
;



-- Wiki topic.
-- Actual HTML page rendered by Wiki can be composed from more than one topic,
-- but even in this case what user edits is a topic.
wiki_exec_no_error (
'create table WV.WIKI.TOPIC (
  TopicId	integer not null,	-- Positive randomized integer ID.
  ParentId	integer default 0,	-- TopicId of parent topic
  ClusterId	integer not null,	-- Id of the cluster.
  ResId	integer,		-- DAV_RES_ID of the source (raw text) resource.
  ResXmlId	integer,		-- DAV_RES_ID of the preprocessed resource (internal HTML-like XML).
  TopicTypeId	integer,		-- Id of topic that describes the type of this topic (this is for colored semantic nets so its unused for a while).
  LocalName	varchar not null,	-- The part of the name that is local to the cluster as specified by author.
  LocalName2	varchar not null,	-- Additional singular or plural form of LocalName.
  TitleText	nvarchar,		-- Title of the page (can be filled by page compiler).
  Abstract	nvarchar,		-- Abstract of the page (can be filled by page compiler).
  LastEtrxId	integer not null,	-- The transaction that made the latest modification to the topic.
  CacheExp	datetime,		-- Expiration time for cached page (unused).
  MailBox	varchar,		-- WEBMail mail box
--    constraint "Topic_InTopic_ByTopicTypeId" foreign key (TopicTypeId) references WV.WIKI.TOPIC (TopicId) on update set null on delete set null,
  primary key (TopicId)
)')
;

wiki_exec_no_error('
create index TopicByResId on WV.WIKI.TOPIC (ResId)')
;
wiki_exec_no_error('
create index TopicByClusterId on WV.WIKI.TOPIC (ClusterId)')
;
wiki_exec_no_error('
create index TopicByResXmlId on WV.WIKI.TOPIC (ResXmlId)')
;
wiki_exec_no_error('
create index TopicByLocalName on WV.WIKI.TOPIC (LocalName, ClusterId)')
;
wiki_exec_no_error('
create index TopicByLocalName2 on WV.WIKI.TOPIC (LocalName2, ClusterId)')
;

wiki_exec_no_error('
alter table "WV"."Wiki"."Topic" drop foreign key ("LastEtrxId") references "WV"."Wiki"."EditTrx" ("EtrxId")')
;

wiki_exec_no_error('
alter table WV.WIKI.TOPIC drop LastEtrxId')
;


wiki_exec_no_error (
'alter table WV.WIKI.TOPIC add T_RFC_ID varchar' 
)
;

wiki_exec_no_error (
'alter table WV.WIKI.TOPIC add T_OWNER_ID int' 
)
;

wiki_exec_no_error (
'alter table WV.WIKI.TOPIC add T_CREATE_TIME datetime' 
)
;

wiki_exec_no_error (
'alter table WV.WIKI.TOPIC add T_RFC_HEADER varchar' 
)
;

wiki_exec_no_error (
'alter table WV.WIKI.TOPIC add T_NEWS_ID varchar' 
)
;

wiki_exec_no_error (
'alter table WV.WIKI.TOPIC add T_PUBLISHED int default 0' 
)
;


-- Links from page to page.
wiki_exec_no_error (
'create table WV.WIKI.LINK (
  LinkId	integer not null,	-- Positive randomized integer ID.
  TypeId	integer not null,	-- Type of the link (this is for colored semantic nets so its unused for a while).
  OrigId	integer not null,	-- Id of the page where the link comes from.
  DestId	integer,		-- Id of the page where the link points to (it can be NULL for dangling links).
  DestClusterName	varchar,	-- Cluster name of destination page, especially useful for dangling links.
  DestLocalName	varchar,	-- Local part of the name of destination page, especially useful for dangling links.
  MadeByDest	integer not null,	-- 0 for plain links, 1 for links that are built by compiler during processing of the destination page.
  LinkText	varchar,		-- Highlighted text of the link for Google-like ("vox populi") link processing.
--  constraint "Link_InTopic_ByLinkTypeId" foreign key (LinkTypeId) references WV.WIKI.TOPIC (TopicId) on update set null on delete set null,
  primary key (LinkId)
)')
;

wiki_exec_no_error('
create index "Link_ByTypeId" on WV.WIKI.LINK (TypeId asc, OrigId asc, DestId asc, MadeByDest asc)')
;
wiki_exec_no_error('
create index "Link_ByOrigId" on WV.WIKI.LINK (OrigId asc, TypeId asc, DestId asc, MadeByDest asc)')
;
wiki_exec_no_error('
create index "Link_ByDestId" on WV.WIKI.LINK (DestId asc, TypeId asc, OrigId asc, MadeByDest asc)')
;
wiki_exec_no_error('
create index "Link_ByDestClusterName" on WV.WIKI.LINK (DestClusterName asc)')
;
wiki_exec_no_error('
create index "Link_ByDestLocalName" on WV.WIKI.LINK (DestLocalName asc)')
;
wiki_exec_no_error('
create index "Link_ByOrigIdDestClusterLocalName" on WV.WIKI.LINK (OrigId, DestClusterName, DestLocalName)')
;
wiki_exec_no_error('
create text index on WV.WIKI.LINK (LinkText) with key LinkId')
;

-- Various fignya and erunda for session data, to prevent side effects of multiple submits of a page.
wiki_exec_no_error (
'create table WV.WIKI.TMP (
  TmpId	integer not null,	-- Id to be passed from page to page.
  TmpData	varchar,		-- The state value to confirm the validity of the post.
  TmpExp	datetime,		-- Expiration time to collect obsolete garbage.
  primary key (TmpId)
)')
;

wiki_exec_no_error (
'create table WV.WIKI.DASHBOARD (
  WD_TIME	timestamp,
  WD_TITLE	varchar,
  WD_UNAME	varchar,
  WD_UID        varchar,
  WD_URL	varchar
)')
;
wiki_exec_no_error('
create index WV_WIKI_DASHBOARD_TIME on WV.WIKI.DASHBOARD (WD_TIME)
')
;


-- history (needed for RSS feeds, Change Log)
wiki_exec_no_error (
'create table WV.WIKI.HISTORY (
  HistID	integer identity,
  TopicName	varchar not null,	-- varchar since the topic can be deleted
  Action	varchar not null,	-- what they did with topic
  Context	varchar,		-- some terms from diff
  HistDate	datetime not null,
  ClusterName varchar not null,
  primary key (HistID)
)')
;

wiki_exec_no_error (
'alter table WV.WIKI.HISTORY add UserName varchar default \'\''
)
;

wiki_exec_no_error('
create index HistoryClusterName on WV.WIKI.HISTORY (ClusterName)')
;


-- locks
wiki_exec_no_error (
'create table WV.WIKI.LOCK (
	TopicId	integer not null,
	UserId	integer not null,
	Created	datetime not null, -- date of lock creation
	primary key (TopicId, UserId)
)')
;

-- categories
wiki_exec_no_error (
'create table WV.WIKI.CATEGORY (
	CategoryId	integer not null, -- randomized id, can be used in the mix with TopicId
	ClusterId	integer not null,
	IsDelIcioUsPub	integer not null default 0, -- is published to del.icio.us
	CategoryName	varchar not null,
	ShortName	varchar not null,
	primary key (CategoryId)
)')
;

wiki_exec_no_error('
create index CategoryByShortName on WV.WIKI.CATEGORY (ShortName)')
;

wiki_exec_no_error('
create index CategoryByName on WV.WIKI.CATEGORY (CategoryName)')
;



-- settings
wiki_exec_no_error (
'create table WV.WIKI.USERSETTINGS (
	UserId	integer not null,
	ParamName	varchar not null,
	Value		any,
	primary key (UserId, ParamName)
)')
;

wiki_exec_no_error (
'create table WV.WIKI.CLUSTERSETTINGS (
	ClusterId	integer not null,
	ParamName	varchar not null,
	Value		any,
	primary key (ClusterId, ParamName)
)')
;

wiki_exec_no_error (
'create table WV.WIKI.ATTACHMENTINFONEW (
	Name		varchar,
	ResPath	varchar,
	Description	varchar,
	primary key (ResPath)
)')
;

wiki_exec_no_error (
'insert into WV.WIKI.ATTACHMENTINFONEW (Name, ResPath, Description)
	select Name, DB.DBA.DAV_SEARCH_PATH (ColId, \'C\') || Name, Description 
		from WV.WIKI.ATTACHMENTINFO'
)
;

wiki_exec_no_error (
'insert into WV.WIKI.ATTACHMENTINFONEW (Name, ResPath, Description)
	select Name, ResPath, Description 
		from WV.WIKI.ATTACHMENTINFO'
)
;

wiki_exec_no_error (
'drop table "WV"."Wiki"."AttachmentInfo"'
)
;

wiki_exec_no_error (
'create table WV.WIKI.HITCOUNTER (
	TopicId		integer,
	Cnt		integer not null,
  	constraint "HitCounter_TopicId2" foreign key (TopicId) references WV.WIKI.TOPIC (TopicId) on update set null on delete cascade,
	primary key (TopicId) 
)')
;

wiki_exec_no_error (
'create table WV.WIKI.COMMITCOUNTER (
	AuthorId	integer primary key,
	Cnt		integer default 0,
  	constraint COMMITCOUNTER_USERS foreign key (AuthorId) references DB.DBA.SYS_USERS (U_ID) on update set null on delete cascade
)')
;

wiki_exec_no_error (
'drop table WV.WIKI.LOCKTOKEN'
)
;

wiki_exec_no_error (
'create table WV.WIKI.LOCKTOKEN (
	ResPath		varchar not null,
	UserName	varchar references DB.DBA.SYS_USERS (U_NAME),
	Token		varchar not null,
	primary key (ResPath))'
)
;



wiki_exec_no_error (
'create procedure update_auto_versioning ()
{
  for select COLID from WV.WIKI.CLUSTERS do 
    {
      update WS.WS.SYS_DAV_COL set COL_AUTO_VERSIONING = \'A\' where COL_AUTO_VERSIONING = \'C\' and COL_ID = COLID;
    }
}')
;

wiki_exec_no_error (
'update_auto_versioning ()'
)
;

wiki_exec_no_error (
'alter table WV.WIKI.TOPIC drop column AuthorId'
)
;

wiki_exec_no_error (
'alter table WV.WIKI.TOPIC add AuthorName varchar'
)
;
wiki_exec_no_error (
'alter table WV.WIKI.TOPIC add AuthorId int'
)
;
wiki_exec_no_error('
create index TopicByLocalNameAndAuthor on WV.WIKI.TOPIC (LocalName, ClusterId, AuthorName)')
;

wiki_exec_no_error('
create table WV.WIKI.PREDICATE (
	PRED_ID		int unique,
	PRED_CLUSTER_ID	int,
	PRED_DESCR	varchar not null unique,
	primary key (PRED_CLUSTER_ID, PRED_ID))
')
;

wiki_exec_no_error('
create table WV.WIKI.SEMANTIC_OBJ (
	SO_CLUSTER_ID	int, 
	SO_ID		int,
	SO_OBJECT_ID	int references WV.WIKI.TOPIC (TopicId),
	SO_PRED		int references WV.WIKI.PREDICATE (PRED_ID),
	SO_SUBJECT	varchar not null,
	SO_TYPE		varchar default \':TOPIC\',
	primary key (SO_CLUSTER_ID, SO_ID))
')
;

wiki_exec_no_error('
alter table WV.WIKI.SEMANTIC_OBJ add SO_TYPE varchar default \':TOPIC\'')
;
wiki_exec_no_error('
alter table WV.WIKI.SEMANTIC_OBJ add SO_SUBJECT_SYN varchar default NULL')
;

wiki_exec_no_error('
create table WV.WIKI.COMMENT (
	C_ID		int identity,
	C_TOPIC_ID	int references WV.WIKI.TOPIC (TopicId),
	C_AUTHOR	varchar,
	C_EMAIL		varchar,
	C_TEXT		long nvarchar,
	C_DATE		datetime,
	primary key (C_ID))
')	
;

wiki_exec_no_error (
'alter table WV.WIKI.COMMENT add C_RFC_ID varchar' 
)
;

wiki_exec_no_error (
'alter table WV.WIKI.COMMENT add C_OWNER_ID int' 
)
;

wiki_exec_no_error (
'alter table WV.WIKI.COMMENT add C_CREATE_TIME datetime' 
)
;

wiki_exec_no_error (
'alter table WV.WIKI.COMMENT add C_RFC_HEADER varchar' 
)
;

wiki_exec_no_error (
'alter table WV.WIKI.COMMENT add C_NEWS_ID varchar' 
)
;

wiki_exec_no_error (
'alter table WV.WIKI.COMMENT add C_SUBJECT varchar' 
)
;

wiki_exec_no_error (
'alter table WV.WIKI.COMMENT add C_PUBLISHED int default 0' 
)
;

wiki_exec_no_error (
'alter table WV.WIKI.COMMENT add C_PARENT_ID int'
)
;

wiki_exec_no_error (
'alter table WV.WIKI.COMMENT add C_REFS varchar'
)
;
wiki_exec_no_error (
'alter table WV.WIKI.COMMENT add C_HOME varchar'
)
;
wiki_exec_no_error (
'alter table WV.WIKI.COMMENT add C_OPENID_SIG varchar'
)
;

wiki_exec_no_error('
create table WV.WIKI.EDIT_TEMP_STORAGE (
	ETS_CLUSTER	varchar not null,
	ETS_LOCAL_NAME  varchar not null,
	ETS_TEXT	long nvarchar,
	ETS_DATE	datetime,
	primary key (ETS_CLUSTER, ETS_LOCAL_NAME))
')	
;


wiki_exec_no_error('create table WV.WIKI.DOMAIN_PATTERN_1 (
	DP_HOST		varchar,
	DP_PATTERN	varchar,
	DP_CLUSTER	int references WV.WIKI.CLUSTERS (ClusterId) on delete cascade,
	primary key (DP_HOST, DP_PATTERN))
')
;

wiki_exec_no_error ('select case when (not isstring (registry_get(\'wiki_schema\'))) then exec (\'alter table WV.WIKI.DOMAIN_PATTERN_1 drop constraint "DOMAIN_PATTERN_1_CLUSTERS_DP_CLUSTER_ClusterId"\') end');
wiki_exec_no_error ('select case when (not isstring (registry_get(\'wiki_schema\'))) then exec (\'alter table WV.WIKI.DOMAIN_PATTERN_1 add constraint "DOMAIN_PATTERN_1_CLUSTERS_DP_CLUSTER_ClusterId" foreign key (DP_CLUSTER) references WV.WIKI.CLUSTERS(ClusterId) on delete cascade\') end');

registry_set('wiki_schema', '2');

wiki_exec_no_error('create table WV.WIKI.DOCBOOK_IDS (	
	DP_CLUSTER_ID int references WV.WIKI.CLUSTERS (ClusterId) on delete cascade,
	DP_ID varchar,
	DP_TOPIC_ID int references WV.WIKI.TOPIC (TopicId) on delete cascade,
	primary key (DP_CLUSTER_ID, DP_ID))
')
;

wiki_exec_no_error('drop type WV.WIKI.CATEGORYINFO')
;
wiki_exec_no_error('drop type WV.WIKI.TOPICINFO')
;

create type WV.WIKI.TOPICINFO
as (
-- User input and usage context
    ti_default_cluster	varchar default null,	-- Default cluster name guessed by some context
    ti_raw_name		varchar default null,	-- Name of topic as provided by user
    ti_raw_title	varchar default null,	-- Title of topic as provided by user
-- Parsed name
    ti_wiki_name	varchar default null,	-- InterWiki name
    ti_cluster_name	varchar default null,	-- Cluster name
    ti_local_name	varchar default null,	-- Name in cluster
    ti_local_name_2	varchar default null,	-- Second form of ti_local_name (singular/plural)
-- Metadata collected from Topic and Cluster
    ti_id		integer default 0,	-- Topic.TopicId
    ti_res_id		integer default 0,	-- Topic.ResId
    ti_rev_id		integer default 0,	-- revision
    ti_type_id		integer default 0,	-- Topic.TopicTypeId
    ti_cluster_id	integer default 0,	-- Cluster.ClusterId
    ti_col_id		integer default 0,	-- Cluster.ColId
    ti_col_history_id	integer default 0,	-- Cluster.ColHistoryId
    ti_col_attach_id	integer default 0,	-- Cluster.ColAttachId
    ti_col_xml_id	integer default 0,	-- Cluster.ColXmlId
    ti_cluster_admin_id	integer default 0,	-- Cluster.AdminId
-- Content
    ti_title_text	varchar default null,	-- Topic.TitleText
    ti_abstract		varchar default null,	-- Topic.Abstract
    ti_text		varchar default null,	-- Text in the TWiki syntax
    ti_author_id	integer default 0,	-- Author of current changes
    ti_author		varchar default '',	-- Author of current changes
    ti_curuser_wikiname varchar default '',	-- User.UserName
    ti_curuser_username varchar default '',	-- DB.DBA.U_NAME
    ti_base_adjust	varchar default '',	-- Relative path from current page to the root of the Wiki, to adjust relative URIs.
    ti_attach_col_id	integer default 0,	-- Id of collection of attachments that has name equal to ti_local_name
    ti_attach_col_id_2	integer default 0,	-- Id of collection of attachments that has name equal to ti_local_name_2
    ti_env		any,			-- Environment parameters to be passed to the stylesheet that converts wiki page from XML to HTML or whatever
    ti_e_mail		varchar default '',
    ti_url		varchar default '', -- Full URL for publishing
    ti_parent_id	integer default null, -- TopicId of parent topic
    ti_mod_time		datetime default null -- modification time of current revision
   ) self as ref
  method ti_http_debug_print (_caption varchar) returns any, -- Dumps \c self to http session as an HTTP readable table.
  method ti_complete_env () returns any, -- Extends ti_env by default values for predefined parameters.
  method ti_xslt_vector (in params any) returns any, -- Returns vector of parameters to pass to xslt in self.ti_compile_page.
  method ti_xslt_vector () returns any, -- Returns vector of parameters to pass to xslt in self.ti_compile_page.
  method ti_parse_raw_name () returns any, -- Parses ti_raw_name and fills ti_wiki_name, ti_cluster_name and ti_local_name; ti_default_cluster can be mentioned for local names.
  method ti_fill_cluster_by_name () returns any, -- Fetches Cluster row by ti_cluster_name.
  method ti_fill_cluster_by_id () returns any, -- Fetches Cluster row by ti_cluster_id.
  method ti_find_id_by_local_name () returns any, -- Fills ti_id by ti_local_name and ti_cluster_id.
  method ti_find_id_by_raw_title () returns any, -- Fills ti_id by ti_raw_title and ti_default_cluster.
  method ti_find_metadata_by_id () returns any, -- Fills cluster data, page metadata and ti_text by ti_id.
  method ti_run_lexer (_env any) returns varchar, -- Converts ti_text to internal HTML with specified environment (names of cluster, topic and user plus _env).
  method ti_get_entity (_env any, _ext int) returns any, -- Similar to ti_run_lexer() but returns an entity, not a text in HTML syntax.
  method ti_compile_page () returns any, -- Compiles the page, updates Topic, Link etc., makes the debugging dump of the page if needed.
  method ti_report_attachments () returns any, -- Composes an XML that lists directory of attachments of the page.
  method ti_revisions (_res_is_vect int, _total int) returns any, -- Composes an XML that lists directory of attachments of the page.
  method ti_wiki_path () returns any, -- Returns XML doc representing parent->child hierarchy.
  method ti_report_mails () returns any, -- Returns XML doc representing parent->child hierarchy.
  method ti_fill_url() returns any, -- fills URL for topic
  method ti_update_text(in _new_text varchar, in _auth varchar) returns any, -- update the text
  method ti_res_name () returns varchar, -- return resource name RES_NAME
  method ti_get_tags () returns any, -- returns all tags associated to topic
  method ti_full_path () returns any, -- returns DAV full path
  method ti_find_metadata_by_res_id () returns any, -- returns DAV full path
  method ti_full_name () returns varchar, -- returns full name of the topic, can be used as ti_raw_name
  constructor method TOPICINFO ()
;

wiki_exec_no_error ('
  alter type WV.WIKI.TOPICINFO add method ti_register_for_upstream (in optype varchar(1)) returns any'
)
;

wiki_exec_no_error ('
create table WV..UPSTREAM (
       UP_ID int identity,
       UP_CLUSTER_ID int references WV.WIKI.CLUSTERS(CLUSTERID),
       UP_NAME varchar,
       UP_URI varchar,
       UP_USER varchar,
       UP_PASSWD varchar,
       UP_WIKIWORD_CONV_METHOD varchar,
       UP_WIKIWORD_CONV_CONTEXT varchar,
       primary key (UP_ID)
)')
;

wiki_exec_no_error ('
  alter table WV..UPSTREAM add UP_RCLUSTER varchar
')
;

wiki_exec_no_error ('
create table WV..UPSTREAM_ENTRY (
       UE_ID int identity,
       UE_STREAM_ID int references WV..UPSTREAM (UP_ID),
       UE_TOPIC_ID int,
       UE_CLUSTER_NAME varchar,
       UE_LOCAL_NAME varchar,
       UE_OP varchar(1), -- U - update, D - delete
       UE_STATUS int, -- 1 - sent
       UE_LAST_TRY datetime,
       primary key (UE_ID)
)')
;

wiki_exec_no_error ('
create table WV..UPSTREAM_LOG (
	UL_UPSTREAM_ID	int,
	UL_ID int,
	UL_DT datetime not null,
	UL_MESSAGE varchar not null,
	constraint UPSTREAM_LOG_UPSTREAM foreign key (UL_UPSTREAM_ID) references WV..UPSTREAM (UP_ID) on update set null on delete cascade
)')
;

wiki_exec_no_error('
create index UPSTREAM_LOG_UPSTREAM on WV..UPSTREAM_LOG (UL_UPSTREAM_ID)')
;

wiki_exec_no_error('
create table WV..HIST (
	H_ID int identity,
	H_OP varchar(1) not null,
	H_CLUSTER varchar not null,
	H_TOPIC varchar not null,
	H_DT datetime not null,
	H_WHO varchar not null,
	H_VER varchar not null,
	primary key (H_ID)
)')
;

wiki_exec_no_error('
alter table WV..HIST add H_IS_PUBLIC int default 0')
;

wiki_exec_no_error('
create index WIKI_HIST_CLUSTER on WV..HIST (H_CLUSTER)')
;

wiki_exec_no_error ('
create table WV..ERRORS (
	E_ID varchar,
	E_DT datetime not null,
	E_CODE varchar not null,
	E_MESSAGE varchar not null, 
	primary key (E_ID)
)')
;

create procedure WV.WIKI.deletetopic_update ()
{
  if (registry_get ('wv_deletetopic_update') <> '1') {
    delete from DB.DBA.wa_new_wiki where not exists (select 1 from WV.WIKI.TOPIC where TopicId = wnw_topic_id);
  }
}
;

WV.WIKI.deletetopic_update ();
registry_set ('wv_deletetopic_update', '1');