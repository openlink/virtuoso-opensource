--
--  $Id$
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2006 OpenLink Software
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

create table DB.DBA.SYS_CACHED_RESOURCES
(
  CRES_URI		varchar not null,
  CRES_PUBLIC_ID	varchar,
  CRES_CONTENT		long varchar,
  CRES_LOADING_DATE	datetime,
  CRES_COMMENT		long varchar,
  primary key (CRES_URI)
)
;

create procedure DB.DBA.SYS_CACHED_RESOURCE_ADD (
  in _uri varchar, in _public_id varchar,
  in _content varchar, in _loading_date datetime, in _comment varchar)
{
  if (exists (
      select top 1 1 from DB.DBA.SYS_CACHED_RESOURCES
      where CRES_URI = _uri and CRES_PUBLIC_ID = _public_id and
        blob_to_string (CRES_CONTENT) = _content and
        CRES_LOADING_DATE = _loading_date and
        blob_to_string (CRES_COMMENT) = _comment ) )
    return;
  insert replacing DB.DBA.SYS_CACHED_RESOURCES
    (CRES_URI, CRES_PUBLIC_ID, CRES_CONTENT, CRES_LOADING_DATE, CRES_COMMENT)
  values (_uri, _public_id, _content, _loading_date, _comment);
  commit work;
}
;

-- Cleanup WebDAV DB
use WS
;

-- WebDAV Collection
create table WS.WS.SYS_DAV_COL (
    COL_ID 		integer,
    COL_NAME 		varchar (256),
    COL_OWNER 		integer,
    COL_GROUP 		integer,
    COL_PARENT 		integer,
    COL_CR_TIME 	datetime,
    COL_MOD_TIME 	datetime,
    COL_PERMS 		char (11),
    COL_DET		varchar,
    COL_ACL		long varbinary,
    COL_IID 		IRI_ID,
    COL_AUTO_VERSIONING char(1),
    COL_FORK 		integer not null default 0,
    primary key (COL_NAME, COL_PARENT)
)
alter index SYS_DAV_COL on WS.WS.SYS_DAV_COL partition (COL_PARENT int)
create index SYS_DAV_COL_PARENT_ID on WS.WS.SYS_DAV_COL (COL_PARENT) partition (COL_PARENT int)
create unique index SYS_DAV_COL_ID on WS.WS.SYS_DAV_COL (COL_ID) partition (COL_ID int)
;

--#IF VER=5
alter table WS.WS.SYS_DAV_COL add COL_DET varchar
;

alter table WS.WS.SYS_DAV_COL add COL_ACL long varbinary
;

alter table WS.WS.SYS_DAV_COL modify COL_PERMS char (11)
;

alter table WS.WS.SYS_DAV_COL add COL_IID IRI_ID
;
--#ENDIF

-- WebDAV Resource
create table WS.WS.SYS_DAV_RES (
    RES_ID 		integer,
    RES_NAME 		varchar (256),
    RES_OWNER 		integer,
    RES_GROUP 		integer,
    RES_COL 		integer,
    RES_CONTENT 	long varbinary IDENTIFIED BY RES_FULL_PATH,
    RES_TYPE 		varchar,
    RES_CR_TIME 	datetime,
    RES_MOD_TIME 	datetime,
    RES_PERMS 		char (11),
    RES_FULL_PATH 	varchar,
    ROWGUID		varchar,
    RES_ACL		long varbinary,
    RES_IID 		IRI_ID,
    RES_STATUS 		varchar,
    RES_VCR_ID 		integer,
    RES_VCR_CO_VERSION 	integer,
    RES_VCR_STATE 	integer,
    primary key (RES_ID)
)
create unique index SYS_DAV_RES_COL on WS.WS.SYS_DAV_RES (RES_COL, RES_NAME) partition (RES_COL int)
create index SYS_DAV_RES_FULL_PATH on WS.WS.SYS_DAV_RES (RES_FULL_PATH) partition (RES_FULL_PATH varchar (-10, 0hexffff))
alter index SYS_DAV_RES on WS.WS.SYS_DAV_RES partition (RES_ID int)
;

--#IF VER=5
alter table WS.WS.SYS_DAV_RES add ROWGUID varchar
;

alter table WS.WS.SYS_DAV_RES add RES_ACL long varbinary
;

alter table WS.WS.SYS_DAV_RES modify RES_PERMS char (11)
;

alter table WS.WS.SYS_DAV_RES add RES_IID IRI_ID
;
--#ENDIF

--__ddl_changed ('WS.WS.SYS_DAV_RES')
--;

create procedure
WS.WS.SYS_DAV_RES_RES_CONTENT_INDEX_HOOK (inout vtb any, inout d_id integer)
{
  return 0;
}
;

create procedure
WS.WS.SYS_DAV_RES_RES_CONTENT_UNINDEX_HOOK (inout vtb any, inout d_id integer)
{
  return 0;
}
;

--!AFTER __PROCEDURE__ DB.DBA.VT_CREATE_TEXT_INDEX !
DB.DBA.vt_create_text_index ('WS.WS.SYS_DAV_RES', 'RES_CONTENT', 'RES_ID', 2, 0, vector ('RES_FULL_PATH', 'RES_OWNER', 'RES_MOD_TIME', 'RES_TYPE'), 1, '*ini*', '*ini*')
;

--!AFTER
DB.DBA.vt_create_ftt ('WS.WS.SYS_DAV_RES', 'RES_ID', 'RES_CONTENT', 2)
;


-- Properties
create table WS.WS.SYS_DAV_PROP (
    PROP_ID 		integer,
    PROP_NAME 		char (256),
    PROP_TYPE 		char (1),
    PROP_PARENT_ID 	integer,
    PROP_VALUE 		long varchar,
    primary key (PROP_PARENT_ID, PROP_TYPE, PROP_NAME)
)
alter index SYS_DAV_PROP on WS.WS.SYS_DAV_PROP partition (PROP_PARENT_ID int)
--create index SYS_DAV_PROP_PARENT on WS.WS.SYS_DAV_PROP (PROP_TYPE, PROP_PARENT_ID) partition (PROP_PARENT_ID int)
create unique index SYS_DAV_PROP_ID on WS.WS.SYS_DAV_PROP (PROP_ID) partition (PROP_ID int)
;

--#IF VER=5
update DB.DBA.SYS_COLS set COL_DTP = 125 where "TABLE" = 'WS.WS.SYS_DAV_PROP' and "COLUMN" = 'PROP_VALUE'
;
__ddl_changed ('WS.WS.SYS_DAV_PROP')
;
--#ENDIF


-- WebDAV Locks
create table WS.WS.SYS_DAV_LOCK (
    LOCK_TYPE 		char (1),
    LOCK_SCOPE 		char (1),
    LOCK_TOKEN 		char (256),
    LOCK_PARENT_TYPE 	char (1),
    LOCK_PARENT_ID 	integer,
    LOCK_TIME 		datetime not null,
    LOCK_TIMEOUT 	integer not null,
    LOCK_OWNER 		integer,
    LOCK_OWNER_INFO	varchar,
    primary key (LOCK_PARENT_ID, LOCK_PARENT_TYPE, LOCK_TOKEN)
)
alter index SYS_DAV_LOCK on WS.WS.SYS_DAV_LOCK partition (LOCK_PARENT_ID int)
create unique index SYS_DAV_LOCKTOKEN on WS.WS.SYS_DAV_LOCK (LOCK_TOKEN) partition (LOCK_TOKEN varchar)
;

-- The WebDAV security info is located under DB.DBA
-- WebDAV Users
create view WS.WS.SYS_DAV_USER (U_ID, U_NAME, U_FULL_NAME, U_E_MAIL, U_PWD,
    U_GROUP, U_LOGIN_TIME, U_ACCOUNT_DISABLED, U_METHODS, U_DEF_PERMS, U_HOME)
  as select U_ID, U_NAME, U_FULL_NAME, U_E_MAIL, U_PASSWORD as U_PWD,
    U_GROUP, U_LOGIN_TIME, U_ACCOUNT_DISABLED, U_METHODS, U_DEF_PERMS, U_HOME
	from DB.DBA.SYS_USERS where U_IS_ROLE = 0 and U_DAV_ENABLE = 1
;

-- WebDAV Groups
create view WS.WS.SYS_DAV_GROUP (G_ID, G_NAME)
    as select U_ID as G_ID, U_NAME as G_NAME
    	from DB.DBA.SYS_USERS where U_IS_ROLE = 1 and U_DAV_ENABLE = 1
;

-- The granted groups to the WebDAV user
create view WS.WS.SYS_DAV_USER_GROUP (UG_UID, UG_GID) as select GI_SUPER, GI_SUB from DB.DBA.SYS_ROLE_GRANTS
;
--       where GI_DIRECT = 1


-- Resource extensions. These are to guess MIME by file extension.
-- To guess extension by MIME, use coalesce (select MT_DEFAULT_EXT from WS.WS.SYS_MIME_TYPES ..., select T_EXT from WS.WS.SYS_DAV_RES_TYPES)
-- because 1) default ext may way from box to box and 2) there may be variety of T_EXTs for one T_TYPE.
create table WS.WS.SYS_DAV_RES_TYPES (
    T_EXT		varchar not null,	-- File extension
    T_TYPE 		varchar not null,	-- MIME type 'x/y' identifier, may be listed in WS.WS.SYS_MIME_TYPES maybe not
    T_DESCRIPTION	varchar,		-- NULL or a single-line text description of an extension if differs from generic MT_DESCRIPTION.
    primary key (T_EXT)
)
alter index SYS_DAV_RES_TYPES on WS.WS.SYS_DAV_RES_TYPES partition cluster replicated
;

-- Known MIME types.
create table WS.WS.SYS_MIME_TYPES (
  MT_IDENT		varchar not null,	-- MIME type 'x/y' identifier, may be listed in WS.WS.SYS_DAV_RES_TYPES maybe not.
  MT_DESCRIPTION	varchar not null,	-- Single-line text description of an extension, if differs from generic MT_DESCRIPTION.
  MT_DEFAULT_EXT	varchar not null,	-- Default file extension for resources.
  MT_BADMAGIC_IDENT	varchar,		-- MIME type that should be used if the content does not match magic data of the proclaimed MIME or NULL to use magic as best guess.
  primary key (MT_IDENT)
)
alter index SYS_MIME_TYPES on WS.WS.SYS_MIME_TYPES partition cluster replicated
;

-- Known and cached RDF schemas.
-- If RDF schema URI is not in this table then HTTP_URI_GET is used on some guessed URIs and SYS_CACHED_RESOURCES is not used.
-- If RDF schema URI is in this table then XML_URI_GET_AND_CACHE is used to read from RS_LOCATION.
create table WS.WS.SYS_RDF_SCHEMAS (
  RS_URI		varchar not null,	-- A URI of an RDF schema
  RS_LOCATION		varchar,		-- Location URI used to retrieve standard schema document (cache also uses this URI as a cache key)
  RS_LOCAL_ADDONS	varchar,		-- Location URI used to retrieve local metadata made by local applications (e.g., comments, helps, screen names etc.).
  RS_PRECOMPILED	long xml,		-- This contains a precompiled mix of data from both schema and local addons.
  RS_COMPILATION_DATE	datetime,		-- Date of the last compilation.
  RS_CATNAME		varchar,		-- A readable and unique label of an RDF schema that can act as collection name in category filter.
  RS_PROP_CATNAMES	long varchar,		-- The serialized vector of names and labels of all declared properties of top-level elements for category filter.
  RS_DEPRECATED		integer,		-- Flag if schema is deprecated.
  primary key (RS_URI)
)
alter index SYS_RDF_SCHEMAS on WS.WS.SYS_RDF_SCHEMAS partition cluster replicated
create unique index SYS_RDF_SCHEMAS_CATNAME on WS.WS.SYS_RDF_SCHEMAS (RS_CATNAME) partition cluster replicated
;

--#IF VER=5
alter table WS.WS.SYS_RDF_SCHEMAS add RS_COMPILATION_DATE datetime
;

alter table WS.WS.SYS_RDF_SCHEMAS add RS_CATNAME varchar
;

alter table WS.WS.SYS_RDF_SCHEMAS add RS_PROP_CATNAMES long varchar
;

alter table WS.WS.SYS_RDF_SCHEMAS add RS_DEPRECATED integer
;
--#ENDIF

-- Known uses of RDF schemas for particular MIME types
create table WS.WS.SYS_MIME_RDFS (
  MR_MIME_IDENT		varchar not null,	-- MIME type 'x/y' identifier, may be listed in WS.WS.SYS_MIME_TYPES maybe not
  MR_RDF_URI		varchar not null,	-- A URI of an RDF schema that can be used for this MIME, The URI may be listed in WS.WS.SYS_MIME_RDFS may be not.
  MR_DEPRECATED		integer,		-- Flags if UIs should display the RDF in the list of RDF schemas available for the type.
  primary key (MR_MIME_IDENT, MR_RDF_URI)
)
alter index SYS_MIME_RDFS on WS.WS.SYS_MIME_RDFS partition cluster replicated
;


-- Known property names in schemas
create table WS.WS.SYS_RDF_PROP_NAME (
   RPN_URI	varchar not null primary key,
   RPN_CATID	integer
)
alter index SYS_RDF_PROP_NAME on WS.WS.SYS_RDF_PROP_NAME partition cluster replicated
create unique index SYS_RDF_PROP_NAME_CATID on WS.WS.SYS_RDF_PROP_NAME (RPN_CATID) partition cluster replicated
;


-- Sources of Catfilters. A single CF_ID can be used by multiple
create table WS.WS.SYS_DAV_CATFILTER
(
  CF_ID integer not null primary key,
  CF_SEARCH_PATH varchar not null
)
alter index SYS_DAV_CATFILTER on WS.WS.SYS_DAV_CATFILTER partition cluster replicated
create unique index SYS_DAV_CATFILTER_SEARCH_PATH on WS.WS.SYS_DAV_CATFILTER (CF_SEARCH_PATH) partition cluster replicated
;


create table WS.WS.SYS_DAV_CATFILTER_DETS
(
  CFD_CF_ID integer not null,
  CFD_DET_SUBCOL_ID integer not null,
  CFD_DET varchar not null,
  primary key (CFD_CF_ID, CFD_DET_SUBCOL_ID)
)
alter index SYS_DAV_CATFILTER_DETS on WS.WS.SYS_DAV_CATFILTER_DETS partition (CFD_CF_ID int)
;


-- Known property values
create table WS.WS.SYS_DAV_RDF_INVERSE
(
  DRI_CATF_ID integer not null,
  DRI_PROP_CATID integer not null,
  DRI_CATVALUE varchar not null,
  DRI_RES_ID integer not null,
  primary key (DRI_CATF_ID, DRI_PROP_CATID, DRI_CATVALUE, DRI_RES_ID)
)
alter index SYS_DAV_RDF_INVERSE on WS.WS.SYS_DAV_RDF_INVERSE partition (DRI_CATF_ID int)
;


-- ACL
create table WS.WS.SYS_DAV_ACL_INVERSE (
  AI_FLAG        char(1) not null,
  AI_PARENT_ID   integer not null,
  AI_PARENT_TYPE char(1) not null,
  AI_GRANTEE_ID  integer not null,

  primary key (AI_FLAG, AI_PARENT_ID, AI_PARENT_TYPE, AI_GRANTEE_ID)
)
alter index SYS_DAV_ACL_INVERSE on WS.WS.SYS_DAV_ACL_INVERSE partition (AI_PARENT_ID int)
;

create view WS.WS.SYS_DAV_ACL_GRANTS (GI_SUPER, GI_SUB)
as
  select U_ID as GI_SUPER, U_ID as GI_SUB from WS.WS.SYS_DAV_USER
union
  select GI_SUPER, GI_SUB from DB.DBA.SYS_ROLE_GRANTS
;

create table WS.WS.SYS_DAV_SPACE_QUOTA
(
  DSQ_HOME_PATH		varchar not null primary key,
  DSQ_U_ID		integer,
  DSQ_DAV_USE		numeric not null,
  DSQ_APP_USE		numeric not null,
  DSQ_TOTAL_USE		numeric not null,
  DSQ_MAX_DAV_USE	numeric not null,
  DSQ_MAX_APP_USE	numeric not null,
  DSQ_MAX_TOTAL_USE	numeric not null,
  DSQ_QUOTA		numeric not null,
  DSQ_ABOVE_HI_YELLOW	datetime,
  DSQ_LAST_WARNING	datetime
)
alter index SYS_DAV_SPACE_QUOTA on WS.WS.SYS_DAV_SPACE_QUOTA partition (DSQ_HOME_PATH varchar (-10, 0hexffff))
create index SYS_DAV_SPACE_QUOTA_U_ID on WS.WS.SYS_DAV_SPACE_QUOTA (DSQ_U_ID) partition (DSQ_U_ID int)
;

create table WS.WS.SYS_DAV_TAG (
  DT_RES_ID	integer not null,
  DT_U_ID	integer not null,
  DT_FT_ID	integer not null,
  DT_TAGS	varchar not null,
--  constraint SYS_DAV_TAG_01 foreign key (DT_RES_ID) references WS.WS.SYS_DAV_RES (RES_ID) on delete cascade,
--  constraint SYS_DAV_TAG_02 foreign key (DT_U_ID) references DB.DBA.SYS_USERS (U_ID) on delete cascade,
  primary key (DT_RES_ID, DT_U_ID)
)
alter index SYS_DAV_TAG on WS.WS.SYS_DAV_TAG partition (DT_RES_ID int)
create unique index SYS_DAV_TAG_FT_ID on WS.WS.SYS_DAV_TAG (DT_FT_ID) partition (DT_FT_ID int)
create index SYS_DAV_TAG_U_ID on WS.WS.SYS_DAV_TAG (DT_U_ID) partition (DT_U_ID int)
;

--!AWK PUBLIC
create function WS.WS.DAV_TAG_NORMALIZE (in strg varchar) returns varchar
{
  declare words any;
  declare norm varchar;
  words := split_and_decode (cast (strg as varchar), 0, '\0\0,');
  if (words is null)
    return '';
  norm := '';
  foreach (varchar word in words) do
    {
      declare nword varchar;
      -- dbg_obj_princ ('word=', word);
      word := trim (replace (replace (replace (replace (word, '\t', ' '), '''', ''), '"', ''), '\\', '')); --'
      if (word <> '')
        {
again:
          nword := replace (word, '  ', ' ');
          if (nword <> word)
            {
              word := nword;
              goto again;
            }
          nword := replace (nword, ' ', '_');
          if (norm <> '')
            norm := norm || ' ' || nword;
          else
            norm := nword;
        }
      -- dbg_obj_princ ('norm=', norm);
    }
  return norm;
}
;

create procedure
WS.WS.SYS_DAV_TAG_DT_TAGS_INDEX_HOOK (inout vtb any, inout d_id integer)
{
  for select DT_RES_ID, DT_U_ID, DT_TAGS from WS.WS.SYS_DAV_TAG where DT_FT_ID = d_id do
    {
      vt_batch_feed (vtb, WS.WS.DAV_TAG_NORMALIZE (DT_TAGS), 0, 0, 'x-ViDoc');
      vt_batch_feed (vtb, sprintf ('UID%d', DT_U_ID), 0, 0, 'x-ViDoc');
      return 1;
    }
  return 1;
}
;

create procedure
WS.WS.SYS_DAV_TAG_DT_TAGS_UNINDEX_HOOK (inout vtb any, inout d_id integer)
{
  for select DT_RES_ID, DT_U_ID, DT_TAGS from WS.WS.SYS_DAV_TAG where DT_FT_ID = d_id do
    {
      vt_batch_feed (vtb, WS.WS.DAV_TAG_NORMALIZE (DT_TAGS), 1, 0, 'x-ViDoc');
      vt_batch_feed (vtb, sprintf ('UID%d', DT_U_ID), 1, 0, 'x-ViDoc');
      return 1;
    }
  return 1;
}
;

--!AFTER __PROCEDURE__ DB.DBA.VT_CREATE_TEXT_INDEX !
DB.DBA.vt_create_text_index ('WS.WS.SYS_DAV_TAG', 'DT_TAGS', 'DT_FT_ID', 2, 0, vector ('DT_U_ID', 'DT_RES_ID'), 1, 'x-ViDoc', '*ini*')
;

-- Get next id for collections or resources or props or rdf prop names (C/R/P/RPN)
create procedure WS.WS.GETID (in type varchar)
{
  declare id, nid integer;
  declare c_cur cursor for select COL_ID from WS.WS.SYS_DAV_COL order by COL_ID desc;
  declare r_cur cursor for select RES_ID from WS.WS.SYS_DAV_RES order by RES_ID desc;
  declare p_cur cursor for select PROP_ID from WS.WS.SYS_DAV_PROP order by PROP_ID desc;
  declare rpn_cur cursor for select RPN_CATID from WS.WS.SYS_RDF_PROP_NAME order by RPN_CATID desc;
  declare cf_cur cursor for select CF_ID from WS.WS.SYS_DAV_CATFILTER order by CF_ID desc;
  declare t_cur cursor for select DT_FT_ID from WS.WS.SYS_DAV_TAG order by DT_FT_ID desc;

  type := upper (type);

  set isolation = 'serializable';

again:

  id := 1;
  whenever not found goto not_found;

  if (type = 'C')
    {
      open c_cur (exclusive, prefetch 1);
      fetch c_cur into id;
      if (not isnull(id))
        id := id + 1;
    }
  else if (type = 'R')
    {
      open r_cur (exclusive, prefetch 1);
      fetch r_cur into id;
      if (not isnull(id))
        id := id + 1;
    }
  else if (type = 'P')
    {
      open p_cur (exclusive, prefetch 1);
      fetch p_cur into id;
      if (not isnull(id))
        id := id + 1;
    }
  else if (type = 'RPN')
    {
      open rpn_cur (exclusive, prefetch 1);
      fetch rpn_cur into id;
      if (not isnull(id))
        id := id + 1;
    }
  else if (type = 'CF')
    {
      open cf_cur (exclusive, prefetch 1);
      fetch cf_cur into id;
      if (not isnull(id))
        id := id + 1;
    }
  else if (type = 'T')
    {
      open t_cur (exclusive, prefetch 1);
      fetch t_cur into id;
      if (not isnull(id))
        id := id + 1;
    }
  else
    id := 0;

not_found:
  if (isnull(id))
    id := 1;

whenever not found goto return_id;
  if (type = 'C')
    {
      close c_cur;
      select COL_ID into nid from WS.WS.SYS_DAV_COL where COL_ID = id;
      goto again;
    }
  else if (type = 'R')
    {
      close r_cur;
      select RES_ID into nid from WS.WS.SYS_DAV_RES where RES_ID = id;
      goto again;
    }
  else if (type = 'P')
    {
      close p_cur;
      select PROP_ID into nid from WS.WS.SYS_DAV_PROP where PROP_ID = id;
      goto again;
    }
  else if (type = 'RPN')
    {
      close rpn_cur;
      select RPN_CATID into nid from WS.WS.SYS_RDF_PROP_NAME where RPN_CATID = id;
      goto again;
    }
  else if (type = 'CF')
    {
      close cf_cur;
      select CF_ID into nid from WS.WS.SYS_DAV_CATFILTER where CF_ID = id;
      goto again;
    }
  else if (type = 'T')
    {
      close t_cur;
      select DT_FT_ID into nid from WS.WS.SYS_DAV_TAG where DT_FT_ID = id;
      goto again;
    }
return_id:
  return id;
}
;


create procedure WS.WS.COL_PATH (in _id any)
{
  declare _path, _name varchar;
  declare _p_id integer;
  _path := '/';
  if (isarray (_id))
    return call (cast (_id[0] as varchar) || '_DAV_SEARCH_PATH')(_id, 'C');
  whenever not found goto nf;
  while (_id > 0)
    {
      select COL_NAME, COL_PARENT into _name, _p_id from WS.WS.SYS_DAV_COL where COL_ID = _id;
      _id := _p_id;
      _path := concat ('/', _name, _path);
    }
  return _path;
nf:
  return NULL;
}
;


create function DB.DBA.DAV_CHANGED_FUNCTIONS () returns any
{
return vector (
'DAV_ADD_USER_INT',
'DAV_ADD_USER',
'DAV_DELETE_USER',
'DAV_PERM_D2U',
'DAV_PERM_U2D',
'DAV_CHECK_AUTH',
'DAV_HOME_DIR',
'DAV_ADD_GROUP_INT',
'DAV_ADD_GROUP',
'DAV_DELETE_GROUP',
'DAV_DIR_LIST',
'DAV_DIR_FILTER',
'DAV_GET_PARENT',
'DAV_DIR_SINGLE_INT',
'DAV_DIR_LIST_INT',
'DAV_DIR_FILTER_INT',
'DAV_SEARCH_PATH',
'DAV_SEARCH_ID',
'DAV_SEARCH_SOME_ID',
'DAV_HIDE_ERROR',
'DAV_SEARCH_SOME_ID_OR_DET',
'DAV_SEARCH_ID_OR_DET',
'DAV_OWNER_ID',
'DAV_IS_LOCKED',
'DAV_LIST_LOCKS',
'DAV_LIST_LOCKS_INT',
'DAV_REQ_CHARS_TO_BITMASK',
'DAV_AUTHENTICATE',
'DAV_AUTHENTICATE_HTTP',
'DAV_COL_CREATE',
'DAV_COL_CREATE_INT',
'DAV_RES_UPLOAD',
'DAV_RES_UPLOAD_STRSES',
'DAV_RES_UPLOAD_STRSES_INT',
'DAV_DELETE',
'DAV_DELETE_INT',
'DAV_COPY',
'DAV_COPY_INT',
'DAV_COPY_SUBTREE',
'DAV_MOVE',
'DAV_MOVE_INT',
'DAV_PROP_SET',
'DAV_PROP_SET_INT',
'DAV_PROP_SET_RAW',
'DAV_PROP_REMOVE',
'DAV_PROP_REMOVE_INT',
'DAV_PROP_GET',
'DAV_PROP_GET_INT',
'DAV_PROP_LIST',
'DAV_PROP_LIST_INT',
'DAV_DIR_P',
'DAV_MAKE_DIR',
'DAV_CHECK_PERM',
'DAV_CHECK_USER',
'DAV_RES_CONTENT',
'DAV_RES_CONTENT_STRSES',
'DAV_RES_CONTENT_INT',
'DAV_COL_IS_ANCESTOR_OF',
'DAV_COL_PATH_BOUNDARY',
'WS.WS.ACL_CONTAINS_GRANTEE_AND_FLAG',
'WS.WS.ACL_UPDATE',
'WS.WS.ACL_MAKE_INHERITED',
'WS.WS.ACL_IS_VALID',
'DAV_CAST_STRING_TO_INTEGER',
'DAV_CAST_STRING_TO_DATETIME',
'DAV_CAST_TEXT_TO_VARCHAR',
'DAV_CAST_TEXT_TO_INTEGER',
'DAV_CAST_TEXT_TO_DATETIME',
'DAV_FC_CONST_AS_SQL',
'DAV_FC_PRED_METAS',
'DAV_FC_CMP_METAS',
'DAV_FC_TABLE_METAS',
'DAV_FC_PRINT_COMPARISON',
'DAV_FC_PRINT_WHERE',
'DAV_FC_PRINT_WHERE_INT',
'DAV_REGISTER_RDF_SCHEMA',
'DAV_RDF_SCHEMA_N3_LIST_PROPERTIES',
'DAV_CROP_URI_TO_CATNAME',
'DAV_GET_RDF_SCHEMA_N3',
'DAV_DEPRECATE_RDF_SCHEMA',
'DAV_REGISTER_MIME_TYPE',
'DAV_REGISTER_MIME_RDF',
'DAV_DEPRECATE_MIME_RDF',
'DAV_RDF_PROP_SET',
'DAV_RDF_PROP_GET',
'DAV_RDF_PREPROCESS_RDFXML_SUB',
'DAV_RDF_PREPROCESS_RDFXML',
'DAV_RDF_PROP_SET_INT',
'DAV_RDF_PROP_GET_INT',
'DAV_RDF_MERGE',
'DAV_EXTRACT_AND_SAVE_RDF',
'DAV_EXTRACT_AND_SAVE_RDF_INT',
'DAV_GUESS_MIME_TYPE',
'DAV_EXTRACT_RDF_application/rss+xml',
'DAV_EXTRACT_RDF_application/atom+xml',
'DAV_EXTRACT_RDF_application/xbel+xml',
'DAV_EXTRACT_RDF_application/foaf+xml',
'DAV_EXTRACT_RDF_application/mods+xml',
'DAV_EXTRACT_RDF_application/opml+xml',
'DAV_EXTRACT_RDF_text/html',
'DAV_EXTRACT_RDF_application/x-openlinksw-vsp',
'DAV_EXTRACT_RDF_application/x-openlinksw-vspx+xml',
'DAV_EXTRACT_RDF_application/bpel+xml',
'DAV_EXTRACT_RDF_application/wsdl+xml',
'DAV_EXTRACT_RDF_application/x-openlinksw-vad',
'DAV_EXTRACT_RDF_application/msword+xml',
'IMC_TO_XML',
'DAV_EXTRACT_RDF_text/directory',
'DAV_EXTRACT_RDF_BY_METAS',
'UNIX_DATETIME_PARSER',
'UNIX_DATE_PARSER',
'BPEL_SPLIT_LIST',
'WS.WS.SYS_DAV_RES_RES_CONTENT_INDEX_HOOK',
'WS.WS.SYS_DAV_RES_RES_CONTENT_UNINDEX_HOOK',
'WS.WS.SYS_DAV_PROP_PROP_VALUE_INDEX_HOOK',
'WS.WS.SYS_DAV_PROP_PROP_VALUE_UNINDEX_HOOK',
'WS.WS.OPTIONS',
'WS.WS.PROPFIND',
'WS.WS.PROPFIND_RESPONSE',
'WS.WS.PROPFIND_RESPONSE_FORMAT',
'WS.WS.PROPNAMES',
'WS.WS.CUSTOM_PROP',
'WS.WS.PROPPATCH',
'WS.WS.FINDPARAM',
'WS.WS.MKCOL',
'WS.WS.FINDCOL',
'WS.WS.FINDRES',
'WS.WS.DELCHILDREN',
'WS.WS.DELETE',
'WS.WS.ISCOL',
'WS.WS.ISRES',
'WS.WS.ETAG',
'WS.WS.HEAD',
'WS.WS.PUT',
'WS.WS.HEX_TO_DEC',
'WS.WS.HEX_DIGIT',
'WS.WS.STR_TO_URI',
'WS.WS.STR_SQL_APOS',
'WS.WS.STR_FT_QUOT',
'WS.WS.PATHREF',
'WS.WS.IS_ACTIVE_CONTENT',
'WS.WS.GET_DAV_DEFAULT_PAGE',
'WS.WS.GET_DAV_CHUNKED_QUOTA',
'WS.WS.GET',
'WS.WS.POST',
'WS.WS.LOCK',
'WS.WS.UNLOCK',
'WS.WS.OPLOCKTOKEN',
'WS.WS.PARENT_PATH',
'WS.WS.HREF_TO_ARRAY',
'WS.WS.HREF_TO_PATH_ARRAY',
'WS.WS.DSTIS',
'WS.WS.MOVE',
'WS.WS.COPY',
'WS.WS.COPY_OR_MOVE',
'WS.WS.GETID',
'WS.WS.ISLOCKED',
'WS.WS.CHECK_AUTH',
'WS.WS.GET_IF_AUTH',
'WS.WS.GET_DAV_AUTH',
'WS.WS.PERM_COMP',
'WS.WS.CHECKPERM',
'WS.WS.ISPUBLIC',
'WS.WS.DAV_VSP_DEF_REMOVE',
'WS.WS.UPDCHILD',
'WS.WS.DAV_VSP_INCLUDES_CHANGED',
'WS.WS.EXPAND_INCLUDES',
'WS.WS.XML_VIEW_HEADER',
'WS.WS.XML_VIEW_EXTERNAL_META',
'WS.WS.XML_VIEW_UPDATE',
'WS.WS.FIXPATH',
'WS.WS.COL_PATH',
'WS.WS.ISPUBL',
'WS.WS.BODY_ARR',
'WS.WS.XML_AUTO_SCHED',
'WS.WS.DAV_LOGIN',
'WS.WS.HTTP_RESP',
'WS.WS.COPY_TO_OTHER',
'WS.WS.CHECK_READ_ACCESS',
'WS.WS.IS_REDIRECT_REF',
'WS.WS.DAV_DIR_LIST',
'WS.WS.DAV_CHECK_QUOTA',
'WS.WS.DAV_CHECK_ASMX',
'WS.WS.DAV_REMOVE_ASMX',
'WS.WS.XMLSQL_TO_STRSES',
'CatFilter_DAV_AUTHENTICATE',
'CatFilter_GET_CONDITION',
'CatFilter_ENCODE_CATVALUE',
'CatFilter_DECODE_CATVALUE',
'CatFilter_PATH_PARTS_TO_FILTER',
'CatFilter_ACC_FILTER_DATA',
'CatFilter_DAV_SEARCH_ID_IMPL',
'CatFilter_DAV_AUTHENTICATE_HTTP',
'CatFilter_DAV_GET_PARENT',
'CatFilter_DAV_COL_CREATE',
'CatFilter_DAV_COL_MOUNT',
'CatFilter_DAV_COL_MOUNT_HERE',
'CatFilter_DAV_DELETE',
'CatFilter_FILTER_TO_CONDITION',
'CatFilter_DAV_RES_UPLOAD',
'CatFilter_DAV_PROP_REMOVE',
'CatFilter_DAV_PROP_SET',
'CatFilter_DAV_PROP_GET',
'CatFilter_DAV_PROP_LIST',
'CatFilter_DAV_DIR_SINGLE',
'CatFilter_LIST_SCHEMAS',
'CatFilter_LIST_SCHEMA_PROPS',
'CatFilter_GET_RDF_INVERSE_HITS_DISTVALS',
'CatFilter_GET_RDF_INVERSE_HITS_RES_IDS',
'CatFilter_LIST_PROP_DISTVALS_AUX',
'CatFilter_LIST_PROP_DISTVALS',
'CatFilter_DAV_DIR_LIST',
'CatFilter_DAV_DIR_FILTER',
'CatFilter_DAV_SEARCH_ID',
'CatFilter_DAV_SEARCH_PATH',
'CatFilter_DAV_RES_UPLOAD_COPY',
'CatFilter_DAV_RES_UPLOAD_MOVE',
'CatFilter_DAV_RES_CONTENT',
'CatFilter_DAV_SYMLINK',
'CatFilter_DAV_LOCK',
'CatFilter_DAV_UNLOCK',
'CatFilter_DAV_IS_LOCKED',
'CatFilter_DAV_LIST_LOCKS',
'CatFilter_CONFIGURE',
'CatFilter_FEED_DAV_RDF_INVERSE',
'CatFilter_INIT_SYS_DAV_RDF_INVERSE',
'WS.WS.HOSTFS_RES_CACHE_RESC_DATA_INDEX_HOOK',
'WS.WS.HOSTFS_RES_CACHE_RESC_DATA_UNINDEX_HOOK',
'WS.WS.HOSTFS_FIND_COL',
'WS.WS.HOSTFS_COL_DISAPPEARS',
'WS.WS.HOSTFS_HANDLE_RES_SCAN',
'WS.WS.HOSTFS_RES_DISAPPEARS',
'WS.WS.HOSTFS_TOUCH_RES',
'WS.WS.HOSTFS_GLOBAL_RESET',
'WS.WS.HOSTFS_PATH_STAT',
'WS.WS.HOSTFS_READ_TYPEINFO',
'HostFs_DAV_AUTHENTICATE',
'HostFs_DAV_AUTHENTICATE_HTTP',
'HostFs_DAV_GET_PARENT',
'HostFs_DAV_COL_CREATE',
'HostFs_DAV_COL_MOUNT',
'HostFs_DAV_COL_MOUNT_HERE',
'HostFs_DAV_DELETE',
'createtableHostFs_DAV_RES_UPLOAD',
'HostFs_DAV_RES_UPLOAD',
'HostFs_DAV_PROP_REMOVE',
'HostFs_DAV_PROP_SET',
'HostFs_DAV_PROP_GET',
'HostFs_DAV_PROP_LIST',
'HostFs_ID_TO_OSPATH',
'HostFs_DAV_DIR_SINGLE',
'HostFs_DAV_DIR_LIST',
'HostFs_DAV_DIR_FILTER',
'HostFs_DAV_SEARCH_ID',
'HostFs_DAV_SEARCH_PATH',
'HostFs_DAV_RES_UPLOAD_COPY',
'HostFs_DAV_RES_UPLOAD_MOVE',
'HostFs_DAV_RES_CONTENT',
'HostFs_DAV_SYMLINK',
'HostFs_DAV_LOCK',
'HostFs_DAV_UNLOCK',
'HostFs_DAV_IS_LOCKED',
'HostFs_DAV_LIST_LOCKS',
'oMail_DAV_AUTHENTICATE',
'oMail_NORM',
'oMail_GET_CONFIG',
'oMail_FNMERGE',
'oMail_FNSPLIT',
'oMail_FIXNAME',
'oMail_COMPOSE_NAME',
'oMail_DAV_SEARCH_ID_IMPL',
'oMail_DAV_AUTHENTICATE_HTTP',
'oMail_DAV_GET_PARENT',
'oMail_DAV_COL_CREATE',
'oMail_DAV_COL_MOUNT',
'oMail_DAV_COL_MOUNT_HERE',
'oMail_DAV_DELETE',
'oMail_DAV_RES_UPLOAD',
'oMail_DAV_PROP_REMOVE',
'oMail_DAV_PROP_SET',
'oMail_DAV_PROP_GET',
'oMail_DAV_PROP_LIST',
'oMail_COLNAME_OF_FOLDER',
'oMail_RESNAME_OF_MAIL',
'oMail_DAV_DIR_SINGLE',
'oMail_DAV_DIR_LIST',
'oMail_DAV_DIR_FILTER',
'oMail_DAV_SEARCH_ID',
'oMail_DAV_SEARCH_PATH',
'oMail_DAV_RES_UPLOAD_COPY',
'oMail_DAV_RES_UPLOAD_MOVE',
'oMail_DAV_RES_CONTENT',
'oMail_DAV_SYMLINK',
'oMail_DAV_LOCK',
'oMail_DAV_UNLOCK',
'oMail_DAV_IS_LOCKED',
'oMail_DAV_LIST_LOCKS',
'PropFilter_DAV_AUTHENTICATE',
'PropFilter_NORM',
'PropFilter_GET_CONDITION',
'PropFilter_FIT_INTO_CONDITION',
'PropFilter_LEAVE_CONDITION',
'PropFilter_FNMERGE',
'PropFilter_FNSPLIT',
'PropFilter_DAV_SEARCH_ID_IMPL',
'PropFilter_DAV_AUTHENTICATE_HTTP',
'PropFilter_DAV_GET_PARENT',
'PropFilter_DAV_COL_CREATE',
'PropFilter_DAV_COL_MOUNT',
'PropFilter_DAV_COL_MOUNT_HERE',
'PropFilter_DAV_DELETE',
'PropFilter_DAV_RES_UPLOAD',
'PropFilter_DAV_PROP_REMOVE',
'PropFilter_DAV_PROP_SET',
'PropFilter_DAV_PROP_GET',
'PropFilter_DAV_PROP_LIST',
'PropFilter_DAV_DIR_SINGLE',
'PropFilter_DAV_DIR_LIST',
'PropFilter_DAV_DIR_FILTER',
'PropFilter_DAV_SEARCH_ID',
'PropFilter_DAV_SEARCH_PATH',
'PropFilter_DAV_RES_UPLOAD_COPY',
'PropFilter_DAV_RES_UPLOAD_MOVE',
'PropFilter_DAV_RES_CONTENT',
'PropFilter_DAV_SYMLINK',
'PropFilter_DAV_LOCK',
'PropFilter_DAV_UNLOCK',
'PropFilter_DAV_IS_LOCKED',
'PropFilter_DAV_LIST_LOCKS',
'ResFilter_DAV_AUTHENTICATE',
'ResFilter_NORM',
'ResFilter_ENCODE_FILTER',
'ResFilter_DECODE_FILTER',
'ResFilter_GET_CONDITION',
'ResFilter_FIT_INTO_CONDITION',
'ResFilter_MAKE_DEL_ACTION_FROM_CONDITION',
'ResFilter_LEAVE_CONDITION',
'ResFilter_FNMERGE',
'ResFilter_FNSPLIT',
'ResFilter_DAV_SEARCH_ID_IMPL',
'ResFilter_DAV_AUTHENTICATE_HTTP',
'ResFilter_DAV_GET_PARENT',
'ResFilter_DAV_COL_CREATE',
'ResFilter_DAV_COL_MOUNT',
'ResFilter_DAV_COL_MOUNT_HERE',
'ResFilter_DAV_DELETE',
'ResFilter_DAV_RES_UPLOAD',
'ResFilter_DAV_PROP_REMOVE',
'ResFilter_DAV_PROP_SET',
'ResFilter_DAV_PROP_GET',
'ResFilter_DAV_PROP_LIST',
'ResFilter_DAV_DIR_SINGLE',
'ResFilter_DAV_DIR_LIST',
'ResFilter_DAV_DIR_FILTER',
'ResFilter_DAV_SEARCH_ID',
'ResFilter_DAV_SEARCH_PATH',
'ResFilter_DAV_RES_UPLOAD_COPY',
'ResFilter_DAV_RES_UPLOAD_MOVE',
'ResFilter_DAV_RES_CONTENT',
'ResFilter_DAV_SYMLINK',
'ResFilter_DAV_LOCK',
'ResFilter_DAV_UNLOCK',
'ResFilter_DAV_IS_LOCKED',
'ResFilter_DAV_LIST_LOCKS',
'ResFilter_CONFIGURE',
'Stub_DAV_AUTHENTICATE',
'Stub_DAV_AUTHENTICATE_HTTP',
'Stub_DAV_GET_PARENT',
'Stub_DAV_COL_CREATE',
'Stub_DAV_COL_MOUNT',
'Stub_DAV_COL_MOUNT_HERE',
'Stub_DAV_DELETE',
'Stub_DAV_RES_UPLOAD',
'Stub_DAV_PROP_REMOVE',
'Stub_DAV_PROP_SET',
'Stub_DAV_PROP_GET',
'Stub_DAV_PROP_LIST',
'Stub_DAV_DIR_SINGLE',
'Stub_DAV_DIR_LIST',
'CatFilter_DAV_DIR_FILTER',
'Stub_DAV_SEARCH_ID',
'Stub_DAV_SEARCH_PATH',
'Stub_DAV_RES_UPLOAD_COPY',
'Stub_DAV_RES_UPLOAD_MOVE',
'Stub_DAV_RES_CONTENT',
'Stub_DAV_SYMLINK',
'Stub_DAV_DEREFERENCE_LIST',
'Stub_DAV_RESOLVE_PATH',
'Stub_DAV_LOCK',
'Stub_DAV_UNLOCK',
'Stub_DAV_IS_LOCKED',
'Stub_DAV_LIST_LOCKS',
'TEST_CATFILTER_MAKE_SCHEMA',
'TEST_CATFILTER_MAKE_SCHEMAS',
'TEST_CATFILTER_MAKE_USER',
'TEST_CATFILTER_SINGLE_FILE',
'TEST_CATFILTER_INIT',
'WebMail_DAV_AUTHENTICATE',
'WebMail_NORM',
'WebMail_GET_CONFIG',
'WebMail_FNMERGE',
'WebMail_FNSPLIT',
'WebMail_FIXNAME',
'WebMail_COMPOSE_NAME',
'WebMail_DAV_SEARCH_ID_IMPL',
'WebMail_DAV_AUTHENTICATE_HTTP',
'WebMail_DAV_COL_CREATE',
'WebMail_DAV_COL_MOUNT',
'WebMail_DAV_COL_MOUNT_HERE',
'WebMail_DAV_DELETE',
'WebMail_DAV_RES_UPLOAD',
'WebMail_DAV_PROP_REMOVE',
'WebMail_DAV_PROP_SET',
'WebMail_DAV_PROP_GET',
'WebMail_DAV_PROP_LIST',
'WebMail_COLNAME_OF_FOLDER',
'WebMail_RESNAME_OF_MAIL',
'WebMail_DAV_DIR_SINGLE',
'WebMail_DAV_DIR_LIST',
'WebMail_DAV_DIR_FILTER',
'WebMail_DAV_SEARCH_ID',
'WebMail_DAV_SEARCH_PATH',
'WebMail_DAV_RES_UPLOAD_COPY',
'WebMail_DAV_RES_UPLOAD_MOVE',
'WebMail_DAV_RES_CONTENT',
'WebMail_DAV_SYMLINK',
'WebMail_DAV_DIR_LIST_FT',
'WebMail_DAV_LOCK',
'WebMail_DAV_UNLOCK',
'WebMail_DAV_IS_LOCKED',
'WebMail_DAV_LIST_LOCKS',
'WS.WS.SYS_DAV_COL_INIT'
);
}
;


-- Initial Root Collection
create procedure WS.WS.SYS_DAV_INIT ()
{
  declare dav_status varchar;
  declare nobody_name varchar;
  __atomic (1);
  declare exit handler for sqlstate '*'
  {
    -- __atomic (0);
    result (__SQL_STATE, __SQL_MESSAGE);
    log_message ('The error occurred during execution of procedure WS.WS.SYS_DAV_INIT().');
    log_message ('This procedure has failed to upgrade WebDAV to Virtuoso 4.0 format.');
    log_message ('The content of data stored in DAV resources remain changed, but access');
    log_message ('permissions may become invalid. To guard your database installation from');
    log_message ('potential security problems, remove the transaction log before restarting');
    log_message ('the server.');
    log_message ('The following error has terminated the upgrade:');
    log_message(concat(cast(__SQL_STATE as varchar), ' ', cast(__SQL_MESSAGE as varchar)));
    raw_exit(-1);
    return;
  };
  set triggers off;
  insert soft WS.WS.SYS_DAV_COL (COL_ID, COL_NAME, COL_PARENT, COL_CR_TIME, COL_MOD_TIME, COL_OWNER, COL_GROUP, COL_PERMS) values (1, 'DAV', 0, now (), now (), http_dav_uid (), http_admin_gid (), '110100000R');
  nobody_name := coalesce ((select U_NAME from DB.DBA.SYS_USERS where U_ID = http_nobody_uid ()));
  if (nobody_name is null)
    {
      declare uid, gid, ctr integer;
      declare procnames any;
      whenever not found goto resources_done;
      declare resc cursor for select RES_OWNER, RES_GROUP from WS.WS.SYS_DAV_RES where RES_OWNER = 0 or RES_GROUP = 0 for update;
      declare colc cursor for select COL_OWNER, COL_GROUP from WS.WS.SYS_DAV_COL where COL_OWNER = 0 or COL_GROUP = 0 for update;
more_resources:
      ctr := 0;
      open resc;
      for (ctr := 0; ctr < 50000; ctr := ctr + 1)
        {
          fetch resc into uid, gid;
          update WS.WS.SYS_DAV_RES set
            RES_OWNER = case (uid) when 0 then http_nobody_uid () else uid end,
            RES_GROUP = case (gid) when 0 then http_nogroup_gid () else gid end
          where current of resc;
        }
      commit work;
      goto more_resources;
resources_done:
      commit work;
      whenever not found goto collections_done;
more_collections:
      ctr := 0;
      open colc;
      for (ctr := 0; ctr < 50000; ctr := ctr + 1)
        {
          fetch colc into uid, gid;
          update WS.WS.SYS_DAV_COL set
            COL_OWNER = case (uid) when 0 then http_nobody_uid () else uid end,
            COL_GROUP = case (gid) when 0 then http_nogroup_gid () else gid end
          where current of colc;
        }
      commit work;
      goto more_collections;
collections_done:
      commit work;
      procnames := DB.DBA.DAV_CHANGED_FUNCTIONS ();
      foreach (varchar procname in procnames) do
        {
	  if (strchr (procname, '.'))
	    delete from DB.DBA.SYS_PROCEDURES where upper (P_NAME) = upper (procname);
	  else
	    delete from DB.DBA.SYS_PROCEDURES where upper (P_NAME) = upper ('DB.DBA.' || procname);
	}
      commit work;
    }
  else if (nobody_name <> 'nobody')
    {
      log_message (sprintf ('The user ID %d is reserved for user "nobody" but used by "%s"', http_nobody_uid (), nobody_name));
      log_message ('The database can not be used with this version of server.');
      log_message ('To fix the problem, drop account "%s" using Virtuoso 3.x server.');
      raw_exit (-1);
    }
  if (exists (select top 1 1 from WS.WS.SYS_DAV_PROP where PROP_ID is null))
    {
      declare propid, ctr integer;
      whenever not found goto props_done;
      declare propc cursor for select PROP_ID from WS.WS.SYS_DAV_PROP for update;
more_props:
      ctr := 0;
      open propc;
      while (ctr < 50000)
        {
          fetch propc into propid;
          if (propid is null)
            {
              ctr := ctr + 1;
              propid := WS.WS.GETID ('P');
              update WS.WS.SYS_DAV_PROP set PROP_ID = propid where current of propc;
            }
        }
      commit work;
      goto more_props;
props_done:
      commit work;
    }
  dav_status := registry_get ('WS.WS.SYS_DAV_INIT-status');
  if (not isstring (dav_status))
    dav_status := '';
  -- dbg_obj_princ ('WS.WS.SYS_DAV_INIT-status is equal to "', dav_status, '"');
  if (strstr (dav_status, '(WS.WS.SYS_DAV_CATFILTER)') is null)
    {
      for (select COL_ID, COL_DET, WS.WS.COL_PATH (COL_ID) as _c_path from WS.WS.SYS_DAV_COL where COL_DET is not null and not (COL_DET like '%Filter')) do
        {
          for select CF_ID from WS.WS.SYS_DAV_CATFILTER where "LEFT" (_c_path, length (CF_SEARCH_PATH)) = CF_SEARCH_PATH do
	    {
              insert replacing WS.WS.SYS_DAV_CATFILTER_DETS (CFD_CF_ID, CFD_DET_SUBCOL_ID, CFD_DET)
	      values (CF_ID, COL_ID, COL_DET);
    	    }
	}
      dav_status := dav_status || ' (WS.WS.SYS_DAV_CATFILTER)';
      registry_set ('WS.WS.SYS_DAV_INIT-status', dav_status);
      -- dbg_obj_princ ('WS.WS.SYS_DAV_INIT-status is updated, now "', dav_status, '"');
      commit work;
    }
  set triggers on;
  insert soft DB.DBA.SYS_USERS (U_ID, U_NAME, U_FULL_NAME, U_E_MAIL, U_PASSWORD, U_GROUP, U_DEF_PERMS, U_ACCOUNT_DISABLED, U_SQL_ENABLE, U_DAV_ENABLE)
    values (http_dav_uid (), 'dav','WebDAV System Administrator','somebody@example.domain', pwd_magic_calc ('dav', 'dav'), http_admin_gid (), '110100000', 0, 0, 1);
  insert soft DB.DBA.SYS_USERS (U_ID, U_NAME, U_FULL_NAME, U_E_MAIL, U_PASSWORD, U_GROUP, U_DEF_PERMS, U_ACCOUNT_DISABLED, U_SQL_ENABLE, U_DAV_ENABLE, U_IS_ROLE)
    values (http_admin_gid (), 'administrators','WebDAV Administrators','admins@example.domain', '', NULL, '110100000', 0, 0, 1, 1);
  insert soft DB.DBA.SYS_USERS (U_ID, U_NAME, U_FULL_NAME, U_E_MAIL, U_PASSWORD, U_GROUP, U_DEF_PERMS, U_ACCOUNT_DISABLED, U_SQL_ENABLE, U_DAV_ENABLE)
    values (http_nobody_uid (), 'nobody','Special account', 'nobody@example.domain', pwd_magic_calc ('nobody', uuid()), http_admin_gid (), '110100000', 1, 0, 1);
  insert soft DB.DBA.SYS_USERS (U_ID, U_NAME, U_FULL_NAME, U_E_MAIL, U_PASSWORD, U_GROUP, U_DEF_PERMS, U_ACCOUNT_DISABLED, U_SQL_ENABLE, U_DAV_ENABLE, U_IS_ROLE)
    values (http_nogroup_gid (), 'nogroup','Special group', 'nobody@example.domain', '', NULL, '110100000', 0, 0, 1, 1);
  __atomic (0);
  return;
}
;

WS.WS.SYS_DAV_INIT ()
;

create procedure
WS.WS.SYS_DAV_PROP_PROP_VALUE_INDEX_HOOK (inout vtb any, inout d_id integer)
{
  for select PROP_NAME as pn, PROP_VALUE as pv from WS.WS.SYS_DAV_PROP where PROP_ID = d_id do
    {
      declare doc any;
      if (126 = __tag (pv))
        pv := blob_to_string (pv);
      if ((not isstring (pv)) or (pv = ''))
        return 1;
      if (193 <> pv[0])
        {
          vt_batch_feed (vtb, pv, 0, 0);
          return 1;
        }
      doc := deserialize (pv);
      if (0 = length (doc))
        return 1;
      doc := xml_tree_doc (doc);
      vt_batch_feed (vtb, doc, 0, 1);
      return 1;
    }
  return 1;
}
;

create procedure
WS.WS.SYS_DAV_PROP_PROP_VALUE_UNINDEX_HOOK (inout vtb any, inout d_id integer)
{
  for select PROP_NAME as pn, PROP_VALUE as pv from WS.WS.SYS_DAV_PROP where PROP_ID = d_id do
    {
      declare doc any;
      if (126 = __tag (pv))
        pv := blob_to_string (pv);
      if ((not isstring (pv)) or (pv = ''))
        return 1;
      if (193 <> pv[0])
        {
          vt_batch_feed (vtb, pv, 1, 0);
          return 1;
        }
      doc := deserialize (pv);
      if (0 = length (doc))
        return 1;
      doc := xml_tree_doc (doc);
      vt_batch_feed (vtb, doc, 1, 1);
      return 1;
    }
  return 1;
}
;

--!AFTER __PROCEDURE__ DB.DBA.VT_CREATE_TEXT_INDEX !
DB.DBA.vt_create_text_index ('WS.WS.SYS_DAV_PROP', 'PROP_VALUE', 'PROP_ID', 2, 0, vector (), 1, '*ini*', '*ini*')
;

-- Initial WebDAV resource mime types
insert soft WS.WS.SYS_DAV_RES_TYPES (T_TYPE,T_EXT) values ('application/andrew-inset','ez')
;
insert soft WS.WS.SYS_DAV_RES_TYPES (T_TYPE,T_EXT) values ('application/bpel+xml','bpel')
;
insert soft WS.WS.SYS_DAV_RES_TYPES (T_TYPE,T_EXT) values ('application/foaf+xml','foaf')
;
insert soft WS.WS.SYS_DAV_RES_TYPES (T_TYPE,T_EXT) values ('application/mac-binhex40','hqx')
;
insert soft WS.WS.SYS_DAV_RES_TYPES (T_TYPE,T_EXT) values ('application/mac-compactpro','cpt')
;
insert soft WS.WS.SYS_DAV_RES_TYPES (T_TYPE,T_EXT) values ('application/mods+xml','mods')
;
insert soft WS.WS.SYS_DAV_RES_TYPES (T_TYPE,T_EXT) values ('application/msexcel','xls')
;
insert soft WS.WS.SYS_DAV_RES_TYPES (T_TYPE,T_EXT) values ('application/msaccess','mdb')
;
insert soft WS.WS.SYS_DAV_RES_TYPES (T_TYPE,T_EXT) values ('application/msexcel','csv')
;
insert soft WS.WS.SYS_DAV_RES_TYPES (T_TYPE,T_EXT) values ('application/vnd.oasis.opendocument.text','odt')
;
insert replacing WS.WS.SYS_DAV_RES_TYPES (T_TYPE,T_EXT) values ('application/vnd.oasis.opendocument.database','odb')
;
insert soft WS.WS.SYS_DAV_RES_TYPES (T_TYPE,T_EXT) values ('application/vnd.oasis.opendocument.graphics', 'odg')
;
insert soft WS.WS.SYS_DAV_RES_TYPES (T_TYPE,T_EXT) values ('application/vnd.oasis.opendocument.presentation', 'odp')
;
insert soft WS.WS.SYS_DAV_RES_TYPES (T_TYPE,T_EXT) values ('application/vnd.oasis.opendocument.spreadsheet', 'ods')
;
insert soft WS.WS.SYS_DAV_RES_TYPES (T_TYPE,T_EXT) values ('application/vnd.oasis.opendocument.chart', 'odc')
;
insert soft WS.WS.SYS_DAV_RES_TYPES (T_TYPE,T_EXT) values ('application/vnd.oasis.opendocument.formula', 'odf')
;
insert soft WS.WS.SYS_DAV_RES_TYPES (T_TYPE,T_EXT) values ('application/vnd.oasis.opendocument.image', 'odi')
;
insert soft WS.WS.SYS_DAV_RES_TYPES (T_TYPE,T_EXT) values ('application/mspowerpoint','ppt')
;
insert soft WS.WS.SYS_DAV_RES_TYPES (T_TYPE,T_EXT) values ('application/msproject','mpp')
;
insert soft WS.WS.SYS_DAV_RES_TYPES (T_TYPE,T_EXT) values ('application/msword','doc')
;
insert soft WS.WS.SYS_DAV_RES_TYPES (T_TYPE,T_EXT) values ('application/octet-stream','bin')
;
insert soft WS.WS.SYS_DAV_RES_TYPES (T_TYPE,T_EXT) values ('application/xddl+xml','xddl')
;
insert soft WS.WS.SYS_DAV_RES_TYPES (T_TYPE,T_EXT) values ('application/octet-stream','dms')
;
insert soft WS.WS.SYS_DAV_RES_TYPES (T_TYPE,T_EXT) values ('application/octet-stream','lha')
;
insert soft WS.WS.SYS_DAV_RES_TYPES (T_TYPE,T_EXT) values ('application/octet-stream','lzh')
;
insert soft WS.WS.SYS_DAV_RES_TYPES (T_TYPE,T_EXT) values ('application/octet-stream','exe')
;
insert soft WS.WS.SYS_DAV_RES_TYPES (T_TYPE,T_EXT) values ('application/octet-stream','class')
;
insert soft WS.WS.SYS_DAV_RES_TYPES (T_TYPE,T_EXT) values ('application/oda','oda')
;
insert soft WS.WS.SYS_DAV_RES_TYPES (T_TYPE,T_EXT) values ('application/ogg','ogg')
;
insert soft WS.WS.SYS_DAV_RES_TYPES (T_TYPE,T_EXT) values ('application/opml+xml','opml')
;
insert soft WS.WS.SYS_DAV_RES_TYPES (T_TYPE,T_EXT) values ('application/rdf+xml','rdf')
;
insert soft WS.WS.SYS_DAV_RES_TYPES (T_TYPE,T_EXT) values ('application/annotea+xml','annotea')
;
update WS.WS.SYS_DAV_RES_TYPES set T_TYPE='application/rdf+xml' where T_TYPE <> 'application/rdf+xml' and T_EXT = 'rdf'
;
insert soft WS.WS.SYS_DAV_RES_TYPES (T_TYPE,T_EXT) values ('application/pdf','pdf')
;
insert soft WS.WS.SYS_DAV_RES_TYPES (T_TYPE,T_EXT) values ('application/postscript','ai')
;
insert soft WS.WS.SYS_DAV_RES_TYPES (T_TYPE,T_EXT) values ('application/postscript','eps')
;
insert soft WS.WS.SYS_DAV_RES_TYPES (T_TYPE,T_EXT) values ('application/postscript','ps')
;
insert soft WS.WS.SYS_DAV_RES_TYPES (T_TYPE,T_EXT) values ('application/rss+xml','rss')
;
insert soft WS.WS.SYS_DAV_RES_TYPES (T_TYPE,T_EXT) values ('application/smil','smil')
;
insert soft WS.WS.SYS_DAV_RES_TYPES (T_TYPE,T_EXT) values ('application/smil','smi')
;
insert soft WS.WS.SYS_DAV_RES_TYPES (T_TYPE,T_EXT) values ('application/wsdl+xml','wsdl')
;
insert soft WS.WS.SYS_DAV_RES_TYPES (T_TYPE,T_EXT) values ('application/xbel+xml','xbel')
;
insert soft WS.WS.SYS_DAV_RES_TYPES (T_TYPE,T_EXT) values ('application/x-bcpio','bcpio')
;
insert soft WS.WS.SYS_DAV_RES_TYPES (T_TYPE,T_EXT) values ('application/x-cdlink','vcd')
;
insert soft WS.WS.SYS_DAV_RES_TYPES (T_TYPE,T_EXT) values ('application/x-chess-pgn','pgn')
;
insert soft WS.WS.SYS_DAV_RES_TYPES (T_TYPE,T_EXT) values ('application/x-cpio','cpio')
;
insert soft WS.WS.SYS_DAV_RES_TYPES (T_TYPE,T_EXT) values ('application/x-csh','csh')
;
insert soft WS.WS.SYS_DAV_RES_TYPES (T_TYPE,T_EXT) values ('application/x-director','dcr')
;
insert soft WS.WS.SYS_DAV_RES_TYPES (T_TYPE,T_EXT) values ('application/x-director','dir')
;
insert soft WS.WS.SYS_DAV_RES_TYPES (T_TYPE,T_EXT) values ('application/x-director','dxr')
;
insert soft WS.WS.SYS_DAV_RES_TYPES (T_TYPE,T_EXT) values ('application/x-dvi','dvi')
;
insert soft WS.WS.SYS_DAV_RES_TYPES (T_TYPE,T_EXT) values ('application/x-futuresplash','spl')
;
insert soft WS.WS.SYS_DAV_RES_TYPES (T_TYPE,T_EXT) values ('application/x-gtar','gtar')
;
insert soft WS.WS.SYS_DAV_RES_TYPES (T_TYPE,T_EXT) values ('application/x-hdf','hdf')
;
insert soft WS.WS.SYS_DAV_RES_TYPES (T_TYPE,T_EXT) values ('application/x-javascript','js')
;
insert soft WS.WS.SYS_DAV_RES_TYPES (T_TYPE,T_EXT) values ('application/x-koan','skp')
;
insert soft WS.WS.SYS_DAV_RES_TYPES (T_TYPE,T_EXT) values ('application/x-koan','skd')
;
insert soft WS.WS.SYS_DAV_RES_TYPES (T_TYPE,T_EXT) values ('application/x-koan','skt')
;
insert soft WS.WS.SYS_DAV_RES_TYPES (T_TYPE,T_EXT) values ('application/x-koan','skm')
;
insert soft WS.WS.SYS_DAV_RES_TYPES (T_TYPE,T_EXT) values ('application/x-latex','latex')
;
insert soft WS.WS.SYS_DAV_RES_TYPES (T_TYPE,T_EXT) values ('application/x-netcdf','cdf')
;
insert soft WS.WS.SYS_DAV_RES_TYPES (T_TYPE,T_EXT) values ('application/x-netcdf','nc')
;
insert soft WS.WS.SYS_DAV_RES_TYPES (T_TYPE,T_EXT) values ('application/x-openlinksw-vspx+xml','vspx')
;
insert soft WS.WS.SYS_DAV_RES_TYPES (T_TYPE,T_EXT) values ('application/x-rpm','rpm')
;
insert soft WS.WS.SYS_DAV_RES_TYPES (T_TYPE,T_EXT) values ('application/x-sh','sh')
;
insert soft WS.WS.SYS_DAV_RES_TYPES (T_TYPE,T_EXT) values ('application/x-shar','shar')
;
insert soft WS.WS.SYS_DAV_RES_TYPES (T_TYPE,T_EXT) values ('application/x-shockwave-flash','swf')
;
insert soft WS.WS.SYS_DAV_RES_TYPES (T_TYPE,T_EXT) values ('application/x-stuffit','sit')
;
insert soft WS.WS.SYS_DAV_RES_TYPES (T_TYPE,T_EXT) values ('application/x-sv4cpio','sv4cpio')
;
insert soft WS.WS.SYS_DAV_RES_TYPES (T_TYPE,T_EXT) values ('application/x-sv4crc','sv4crc')
;
insert soft WS.WS.SYS_DAV_RES_TYPES (T_TYPE,T_EXT) values ('application/x-tar','tar')
;
insert soft WS.WS.SYS_DAV_RES_TYPES (T_TYPE,T_EXT) values ('application/x-tcl','tcl')
;
insert soft WS.WS.SYS_DAV_RES_TYPES (T_TYPE,T_EXT) values ('application/x-tex','tex')
;
insert soft WS.WS.SYS_DAV_RES_TYPES (T_TYPE,T_EXT) values ('application/x-texinfo','texinfo')
;
insert soft WS.WS.SYS_DAV_RES_TYPES (T_TYPE,T_EXT) values ('application/x-texinfo','texi')
;
insert soft WS.WS.SYS_DAV_RES_TYPES (T_TYPE,T_EXT) values ('application/x-troff','t')
;
insert soft WS.WS.SYS_DAV_RES_TYPES (T_TYPE,T_EXT) values ('application/x-troff','tr')
;
insert soft WS.WS.SYS_DAV_RES_TYPES (T_TYPE,T_EXT) values ('application/x-troff','roff')
;
insert soft WS.WS.SYS_DAV_RES_TYPES (T_TYPE,T_EXT) values ('application/x-troff-man','man')
;
insert soft WS.WS.SYS_DAV_RES_TYPES (T_TYPE,T_EXT) values ('application/x-troff-me','me')
;
insert soft WS.WS.SYS_DAV_RES_TYPES (T_TYPE,T_EXT) values ('application/x-troff-ms','ms')
;
insert soft WS.WS.SYS_DAV_RES_TYPES (T_TYPE,T_EXT) values ('application/x-ustar','ustar')
;
insert soft WS.WS.SYS_DAV_RES_TYPES (T_TYPE,T_EXT) values ('application/x-wais-source','src')
;
insert soft WS.WS.SYS_DAV_RES_TYPES (T_TYPE,T_EXT) values ('application/zip','zip')
;
insert soft WS.WS.SYS_DAV_RES_TYPES (T_TYPE,T_EXT) values ('audio/basic','au')
;
insert soft WS.WS.SYS_DAV_RES_TYPES (T_TYPE,T_EXT) values ('audio/basic','snd')
;
insert soft WS.WS.SYS_DAV_RES_TYPES (T_TYPE,T_EXT) values ('audio/midi','mid')
;
insert soft WS.WS.SYS_DAV_RES_TYPES (T_TYPE,T_EXT) values ('audio/midi','kar')
;
insert soft WS.WS.SYS_DAV_RES_TYPES (T_TYPE,T_EXT) values ('audio/midi','midi')
;
insert soft WS.WS.SYS_DAV_RES_TYPES (T_TYPE,T_EXT) values ('audio/mpeg','mpga')
;
insert soft WS.WS.SYS_DAV_RES_TYPES (T_TYPE,T_EXT) values ('audio/mpeg','mp2')
;
insert soft WS.WS.SYS_DAV_RES_TYPES (T_TYPE,T_EXT) values ('audio/mpeg','mp3')
;
insert soft WS.WS.SYS_DAV_RES_TYPES (T_TYPE,T_EXT) values ('audio/x-aiff','aif')
;
insert soft WS.WS.SYS_DAV_RES_TYPES (T_TYPE,T_EXT) values ('audio/x-aiff','aiff')
;
insert soft WS.WS.SYS_DAV_RES_TYPES (T_TYPE,T_EXT) values ('audio/x-aiff','aifc')
;
insert soft WS.WS.SYS_DAV_RES_TYPES (T_TYPE,T_EXT) values ('audio/x-flac','flac')
;
insert soft WS.WS.SYS_DAV_RES_TYPES (T_TYPE,T_EXT) values ('audio/x-mp3','mp3')
;
insert soft WS.WS.SYS_DAV_RES_TYPES (T_TYPE,T_EXT) values ('audio/x-m4a','m4a')
;
insert soft WS.WS.SYS_DAV_RES_TYPES (T_TYPE,T_EXT) values ('audio/x-m4p','m4p')
;
insert soft WS.WS.SYS_DAV_RES_TYPES (T_TYPE,T_EXT) values ('audio/x-pn-realaudio','ram')
;
insert soft WS.WS.SYS_DAV_RES_TYPES (T_TYPE,T_EXT) values ('audio/x-pn-realaudio','rm')
;
insert soft WS.WS.SYS_DAV_RES_TYPES (T_TYPE,T_EXT) values ('audio/x-realaudio','ra')
;
insert soft WS.WS.SYS_DAV_RES_TYPES (T_TYPE,T_EXT) values ('audio/x-wav','wav')
;
insert soft WS.WS.SYS_DAV_RES_TYPES (T_TYPE,T_EXT) values ('chemical/x-pdb','pdb')
;
insert soft WS.WS.SYS_DAV_RES_TYPES (T_TYPE,T_EXT) values ('chemical/x-pdb','xyz')
;
insert soft WS.WS.SYS_DAV_RES_TYPES (T_TYPE,T_EXT) values ('image/gif','gif')
;
insert soft WS.WS.SYS_DAV_RES_TYPES (T_TYPE,T_EXT) values ('image/ief','ief')
;
insert soft WS.WS.SYS_DAV_RES_TYPES (T_TYPE,T_EXT) values ('image/jpeg','jpeg')
;
insert soft WS.WS.SYS_DAV_RES_TYPES (T_TYPE,T_EXT) values ('image/jpeg','jpg')
;
insert soft WS.WS.SYS_DAV_RES_TYPES (T_TYPE,T_EXT) values ('image/jpeg','jpe')
;
insert soft WS.WS.SYS_DAV_RES_TYPES (T_TYPE,T_EXT) values ('image/png','png')
;
insert soft WS.WS.SYS_DAV_RES_TYPES (T_TYPE,T_EXT) values ('image/tiff','tif')
;
insert soft WS.WS.SYS_DAV_RES_TYPES (T_TYPE,T_EXT) values ('image/tiff','tiff')
;
insert soft WS.WS.SYS_DAV_RES_TYPES (T_TYPE,T_EXT) values ('image/x-cmu-raster','ras')
;
insert soft WS.WS.SYS_DAV_RES_TYPES (T_TYPE,T_EXT) values ('image/x-portable-anymap','pnm')
;
insert soft WS.WS.SYS_DAV_RES_TYPES (T_TYPE,T_EXT) values ('image/x-portable-bitmap','pbm')
;
insert soft WS.WS.SYS_DAV_RES_TYPES (T_TYPE,T_EXT) values ('image/x-portable-graymap','pgm')
;
insert soft WS.WS.SYS_DAV_RES_TYPES (T_TYPE,T_EXT) values ('image/x-portable-pixmap','ppm')
;
insert soft WS.WS.SYS_DAV_RES_TYPES (T_TYPE,T_EXT) values ('image/x-rgb','rgb')
;
insert soft WS.WS.SYS_DAV_RES_TYPES (T_TYPE,T_EXT) values ('image/x-xbitmap','xbm')
;
insert soft WS.WS.SYS_DAV_RES_TYPES (T_TYPE,T_EXT) values ('image/x-xpixmap','xpm')
;
insert soft WS.WS.SYS_DAV_RES_TYPES (T_TYPE,T_EXT) values ('image/x-xwindowdump','xwd')
;
insert soft WS.WS.SYS_DAV_RES_TYPES (T_TYPE,T_EXT) values ('model/iges','iges')
;
insert soft WS.WS.SYS_DAV_RES_TYPES (T_TYPE,T_EXT) values ('model/iges','igs')
;
insert soft WS.WS.SYS_DAV_RES_TYPES (T_TYPE,T_EXT) values ('model/mesh','silo')
;
insert soft WS.WS.SYS_DAV_RES_TYPES (T_TYPE,T_EXT) values ('model/mesh','mesh')
;
insert soft WS.WS.SYS_DAV_RES_TYPES (T_TYPE,T_EXT) values ('model/mesh','msh')
;
insert soft WS.WS.SYS_DAV_RES_TYPES (T_TYPE,T_EXT) values ('model/vrml','vrml')
;
insert soft WS.WS.SYS_DAV_RES_TYPES (T_TYPE,T_EXT) values ('model/vrml','wrl')
;
insert soft WS.WS.SYS_DAV_RES_TYPES (T_TYPE,T_EXT) values ('text/directory','ical')
;
insert replacing WS.WS.SYS_DAV_RES_TYPES (T_TYPE,T_EXT) values ('text/calendar','ics')
;
insert soft WS.WS.SYS_DAV_RES_TYPES (T_TYPE,T_EXT) values ('text/directory','vcard')
;
insert replacing WS.WS.SYS_DAV_RES_TYPES (T_TYPE,T_EXT) values ('text/x-vCard','vcf')
;
insert soft WS.WS.SYS_DAV_RES_TYPES (T_TYPE,T_EXT) values ('text/css','css')
;
insert soft WS.WS.SYS_DAV_RES_TYPES (T_TYPE,T_EXT) values ('text/plain','txt')
;
insert soft WS.WS.SYS_DAV_RES_TYPES (T_TYPE,T_EXT) values ('text/plain','asc')
;
insert soft WS.WS.SYS_DAV_RES_TYPES (T_TYPE,T_EXT) values ('text/richtext','rtx')
;
insert soft WS.WS.SYS_DAV_RES_TYPES (T_TYPE,T_EXT) values ('text/rtf','rtf')
;
insert soft WS.WS.SYS_DAV_RES_TYPES (T_TYPE,T_EXT) values ('text/sgml','sgm')
;
insert soft WS.WS.SYS_DAV_RES_TYPES (T_TYPE,T_EXT) values ('text/sgml','sgml')
;
insert soft WS.WS.SYS_DAV_RES_TYPES (T_TYPE,T_EXT) values ('text/tab-separated-values','tsv')
;
insert soft WS.WS.SYS_DAV_RES_TYPES (T_TYPE,T_EXT) values ('text/x-setext','etx')
;
insert soft WS.WS.SYS_DAV_RES_TYPES (T_TYPE,T_EXT) values ('text/xml','xml')
;
insert soft WS.WS.SYS_DAV_RES_TYPES (T_TYPE,T_EXT) values ('text/xml','xmltxt')
;
insert soft WS.WS.SYS_DAV_RES_TYPES (T_TYPE,T_EXT) values ('video/mpeg','mpe')
;
insert soft WS.WS.SYS_DAV_RES_TYPES (T_TYPE,T_EXT) values ('video/mpeg','mpeg')
;
insert soft WS.WS.SYS_DAV_RES_TYPES (T_TYPE,T_EXT) values ('video/mpeg','mpg')
;
insert soft WS.WS.SYS_DAV_RES_TYPES (T_TYPE,T_EXT) values ('video/quicktime','mov')
;
insert soft WS.WS.SYS_DAV_RES_TYPES (T_TYPE,T_EXT) values ('video/quicktime','qt')
;
insert soft WS.WS.SYS_DAV_RES_TYPES (T_TYPE,T_EXT) values ('video/x-msvideo','avi')
;
insert soft WS.WS.SYS_DAV_RES_TYPES (T_TYPE,T_EXT) values ('video/x-sgi-movie','movie')
;
insert soft WS.WS.SYS_DAV_RES_TYPES (T_TYPE,T_EXT) values ('x-conference/x-cooltalk','ice')
;
insert soft WS.WS.SYS_DAV_RES_TYPES (T_TYPE,T_EXT) values ('text/html','htm')
;
insert soft WS.WS.SYS_DAV_RES_TYPES (T_TYPE,T_EXT) values ('text/html','html')
;
insert soft WS.WS.SYS_DAV_RES_TYPES (T_TYPE,T_EXT) values ('text/xsl','xsl')
;
insert soft WS.WS.SYS_DAV_RES_TYPES (T_TYPE,T_EXT) values ('text/html','asp')
;
insert soft WS.WS.SYS_DAV_RES_TYPES (T_TYPE,T_EXT) values ('text/html','php')
;
insert soft WS.WS.SYS_DAV_RES_TYPES (T_TYPE,T_EXT) values ('text/html','php3')
;
insert soft WS.WS.SYS_DAV_RES_TYPES (T_TYPE,T_EXT) values ('text/plain','sql')
;
insert soft WS.WS.SYS_DAV_RES_TYPES (T_TYPE,T_EXT) values ('text/xml','xsd')
;
insert soft WS.WS.SYS_DAV_RES_TYPES (T_TYPE,T_EXT) values ('text/xml','dtd')
;
insert replacing WS.WS.SYS_DAV_RES_TYPES (T_TYPE,T_EXT) values ('application/ocs+xml','ocs')
;
insert replacing WS.WS.SYS_DAV_RES_TYPES (T_TYPE,T_EXT) values ('application/opml+xml','opml')
;
insert soft WS.WS.SYS_DAV_RES_TYPES (T_TYPE,T_EXT) values ('text/xml','rss')
;
insert soft WS.WS.SYS_DAV_RES_TYPES (T_TYPE,T_EXT) values ('image/bmp','bmp')
;
insert soft WS.WS.SYS_DAV_RES_TYPES (T_TYPE,T_EXT) values ('video/mp4','mp4')
;
insert soft WS.WS.SYS_DAV_RES_TYPES (T_TYPE,T_EXT) values ('video/3gpp','3gp')
;
insert soft WS.WS.SYS_DAV_RES_TYPES (T_TYPE,T_EXT) values ('audio/amr','amr')
;
insert soft WS.WS.SYS_DAV_RES_TYPES (T_TYPE,T_EXT) values ('text/rdf+ttl','ttl')
;
insert soft WS.WS.SYS_DAV_RES_TYPES (T_TYPE,T_EXT) values ('text/rdf+n3','n3')
;

select count(*) from WS.WS.SYS_DAV_RES_TYPES where http_mime_type_add (T_EXT, T_TYPE)
;

create procedure
DB.DBA.DAV_PLAIN_SUBCOLS_P (in root_id integer, in root_path varchar := null, in recursive integer := 1, in subcol_auth_uid varchar, in subcol_auth_pwd varchar)
{
  declare SUBCOL_FULL_PATH, SUBCOL_NAME, SUBCOL_DET varchar;
  declare SUBCOL_PARENT, SUBCOL_ID, SUBCOL_DEPTH integer;
  -- dbg_obj_princ ('DB.DBA.DAV_PLAIN_SUBCOLS_P(',root_id,root_path,recursive,subcol_auth_uid,subcol_auth_pwd,')');
  result_names (SUBCOL_FULL_PATH, SUBCOL_NAME, SUBCOL_PARENT, SUBCOL_ID, SUBCOL_DEPTH, SUBCOL_DET);
  if (root_id is null)
    root_id := DB.DBA.DAV_SEARCH_ID (root_path, 'C');
  if (not isinteger (root_id))
    return;
  if (root_id <= 0)
    return;
  if (root_path is null)
    root_path := DB.DBA.DAV_SEARCH_PATH (root_id, 'C');
  if (isinteger (root_path))
    return;
  for (select COL_NAME, COL_PARENT, COL_ID, COL_DET from WS.WS.SYS_DAV_COL where COL_ID = root_id) do
    {
      result (root_path, COL_NAME, COL_PARENT, COL_ID, 0, COL_DET);
      if (recursive and COL_DET is null)
        {
          DB.DBA.DAV_PLAIN_SUBCOLS_P_INT (root_id, root_path, 1, subcol_auth_uid, subcol_auth_pwd);
        }
    }
}
;

create procedure
DB.DBA.DAV_PLAIN_SUBCOLS_P_INT (in root_id integer, in root_path varchar, in depth integer, in subcol_auth_uid varchar, in subcol_auth_pwd varchar)
{
  for (select COL_NAME, COL_ID, root_path || COL_NAME || '/' as full_path, COL_DET from WS.WS.SYS_DAV_COL where COL_PARENT = root_id) do
    {
      result (full_path, COL_NAME, root_id, COL_ID, depth, COL_DET);
      if (COL_DET is null)
        DB.DBA.DAV_PLAIN_SUBCOLS_P_INT (COL_ID, full_path, depth + 1, subcol_auth_uid, subcol_auth_pwd);
    }
}
;


create procedure view DB.DBA.DAV_PLAIN_SUBCOLS as DB.DBA.DAV_PLAIN_SUBCOLS_P (root_id,root_path,recursive,subcol_auth_uid,subcol_auth_pwd) (SUBCOL_FULL_PATH varchar, SUBCOL_NAME varchar, SUBCOL_PARENT integer, SUBCOL_ID integer, SUBCOL_DEPTH integer, SUBCOL_DET varchar)
;


create procedure
DB.DBA.DAV_PLAIN_SUBMOUNTS_P (in root_id integer, in root_path varchar := null, in recursive integer := 1, in subcol_auth_uid varchar, in subcol_auth_pwd varchar)
{
  declare SUBCOL_FULL_PATH, SUBCOL_NAME, SUBCOL_DET varchar;
  declare SUBCOL_PARENT, SUBCOL_ID, SUBCOL_DEPTH integer;
  result_names (SUBCOL_FULL_PATH, SUBCOL_NAME, SUBCOL_PARENT, SUBCOL_ID, SUBCOL_DEPTH, SUBCOL_DET);
  if (root_id is null)
    root_id := DB.DBA.DAV_SEARCH_ID (root_path, 'C');
  if (not isinteger (root_id))
    return;
  if (root_id <= 0)
    return;
  if (root_path is null)
    root_path := DB.DBA.DAV_SEARCH_PATH (root_id, 'C');
  if (not isstring (root_path))
    return;
  for (select COL_NAME, COL_PARENT, COL_ID, COL_DET from WS.WS.SYS_DAV_COL where COL_ID = root_id) do
    {
      if (COL_DET is not null)
        result (root_path, COL_NAME, COL_PARENT, COL_ID, 0, COL_DET);
      if (recursive and COL_DET is null)
        {
          DB.DBA.DAV_PLAIN_SUBMOUNTS_P_INT (root_id, root_path, 1, subcol_auth_uid, subcol_auth_pwd);
        }
    }
}
;

create procedure
DB.DBA.DAV_PLAIN_SUBMOUNTS_P_INT (in root_id integer, in root_path varchar, in depth integer, in subcol_auth_uid varchar, in subcol_auth_pwd varchar)
{
  for (select COL_NAME, COL_ID, root_path || COL_NAME || '/' as full_path, COL_DET from WS.WS.SYS_DAV_COL where COL_PARENT = root_id) do
    {
      if (COL_DET is not null)
        result (full_path, COL_NAME, root_id, COL_ID, depth, COL_DET);
      if (COL_DET is null)
        DB.DBA.DAV_PLAIN_SUBMOUNTS_P_INT (COL_ID, full_path, depth + 1, subcol_auth_uid, subcol_auth_pwd);
    }
}
;


create procedure view DB.DBA.DAV_PLAIN_SUBMOUNTS as DB.DBA.DAV_PLAIN_SUBMOUNTS_P (root_id,root_path,recursive,subcol_auth_uid,subcol_auth_pwd) (SUBCOL_FULL_PATH varchar, SUBCOL_NAME varchar, SUBCOL_PARENT integer, SUBCOL_ID integer, SUBCOL_DEPTH integer, SUBCOL_DET varchar)
;


--!AWK PUBLIC
create procedure
DB.DBA.DAV_DIR_P (in path varchar := '/DAV/', in recursive integer := 0, in auth_uid varchar, in auth_pwd varchar)
{
  declare arr any;
  declare i, l integer;
  declare FULL_PATH, PERMS, MIME_TYPE, NAME varchar;
  declare TYPE char(1);
  declare RLENGTH, ID, GRP, OWNER integer;
  declare MOD_TIME, CR_TIME datetime;
  result_names (FULL_PATH, TYPE, RLENGTH, MOD_TIME, ID, PERMS, GRP, OWNER, CR_TIME, MIME_TYPE, NAME);
  arr := DB.DBA.DAV_DIR_LIST (path, recursive, auth_uid, auth_pwd);
  i := 0; l := length (arr);
  while (i < l)
    {
      result (arr[i][0],
	  arr[i][1],
	  arr[i][2],
	  arr[i][3],
	  arr[i][4],
	  arr[i][5],
	  arr[i][6],
	  arr[i][7],
	  arr[i][8],
	  arr[i][9],
	  arr[i][10]);
      i := i + 1;
    }
}
;

create procedure view DB.DBA.DAV_DIR as DB.DBA.DAV_DIR_P (path,recursive,auth_uid,auth_pwd) (FULL_PATH varchar, TYPE varchar, RLENGTH integer, MOD_TIME datetime, ID integer, PERMS varchar, GRP integer, OWNER integer, CR_TIME datetime, MIME_TYPE varchar, NAME varchar)
;

exec ('grant select on DB.DBA.DAV_DIR to PUBLIC')
;
