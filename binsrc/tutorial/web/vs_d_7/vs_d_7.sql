--  
--  $Id$
--  
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--  
--  Copyright (C) 1998-2015 OpenLink Software
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
-- WebDAV Collections table
create table WS.WS.SYS_DAV_COL ( 
    COL_ID 		integer,	-- unique ID of the collection 
    COL_NAME 		char (256), 	-- name of the collection 
    COL_OWNER 		integer,	-- collection owner (references U_ID from SYS_DAV_USER table)
    COL_GROUP 		integer,	-- collection group ownership (references G_ID from SYS_DAV_GROUP table)
    COL_PARENT 		integer, 	-- the parent collection ID (references the COL_ID form the same table)
    COL_CR_TIME 	datetime, 	-- creation data and time
    COL_MOD_TIME 	datetime,	-- modification data and time
    COL_PERMS 		char (10),	-- collection security permissions
    primary key (COL_NAME, COL_PARENT) 
)
create index SYS_DAV_COL_PARENT_ID on WS.WS.SYS_DAV_COL (COL_PARENT)
create unique index SYS_DAV_COL_ID on WS.WS.SYS_DAV_COL (COL_ID)
;

-- WebDAV Resources table
create table WS.WS.SYS_DAV_RES ( 
    RES_ID 		integer,	-- unique ID of the resource
    RES_NAME 		char (256), 	-- name of the resource
    RES_OWNER 		integer,	-- resource owner (references U_ID from SYS_DAV_USER table)
    RES_GROUP 		integer, 	-- resource group membership (references G_ID from SYS_DAV_GROUP table)
    RES_COL 		integer,	-- parent collection ID (references the COL_ID from WS.WS.SYS_DAV_COL table)
    RES_CONTENT 	long varchar IDENTIFIED BY RES_FULL_PATH, -- content of the resource
    RES_TYPE 		varchar,	-- MIME type (file/content type) of the resource
    RES_CR_TIME 	datetime, 	-- creation data and time
    RES_MOD_TIME 	datetime,	-- modification data and time
    RES_PERMS 		char (10),	-- resource security permissions
    RES_FULL_PATH 	varchar,	-- the full path of the resource in WebDAV repository
    primary key (RES_COL, RES_NAME)
)
create index SYS_DAV_RES_COL_ID on WS.WS.SYS_DAV_RES (RES_COL)
create unique index SYS_DAV_RES_ID on WS.WS.SYS_DAV_RES (RES_ID)
;


-- Properties
create table WS.WS.SYS_DAV_PROP (
    PROP_ID 		integer,	-- unique ID of the property
    PROP_NAME 		char (256),	-- property name
    PROP_TYPE 		char (1),	-- the parent type ('R'esource or 'C'ollection)
    PROP_PARENT_ID 	integer,	-- id of the parent (references the WS.WS.SYS_DAV_RES or WS.WS.SYS_DAV_COL table)
    PROP_VALUE 		varchar, 	-- value of the resource
    primary key (PROP_NAME, PROP_TYPE, PROP_PARENT_ID)
)
create index SYS_DAV_PROP_PARENT on WS.WS.SYS_DAV_PROP (PROP_TYPE, PROP_PARENT_ID)
;

-- WebDAV Locks
create table WS.WS.SYS_DAV_LOCK (
    LOCK_TYPE 		char (1),	-- lock type 'R'ead or 'W'rite lock 
    LOCK_SCOPE 		char (1),	-- lock scope 'S'hared or e'X'clusive
    LOCK_TOKEN 		char (256),	-- opaque lock token
    LOCK_PARENT_TYPE 	char (1),	-- the parent type ('R'esource or 'C'ollection)
    LOCK_PARENT_ID 	integer,	-- id of the parent (references the WS.WS.SYS_DAV_RES or WS.WS.SYS_DAV_COL table)
    LOCK_TIME 		datetime, 	-- when the parent is locked : data and time
    LOCK_TIMEOUT 	integer, 	-- how many seconds lock is valid 
    LOCK_OWNER 		integer, 	-- WebDAV owner of the lock (references U_ID from SYS_DAV_USER table)
    LOCK_OWNER_INFO	varchar,	-- the human readable information of the lock owner (if user-agent supplied)
    primary key (LOCK_PARENT_TYPE, LOCK_PARENT_ID)
)
create unique index SYS_DAV_LOCKTOKEN on WS.WS.SYS_DAV_LOCK (LOCK_TOKEN)
;


-- WebDAV Users table
create table WS.WS.SYS_DAV_USER (
    U_ID 		integer,	-- unique ID of the user 
    U_NAME 		char (128),	-- unique name of the user 
    U_FULL_NAME 	char (128),	-- full name of the user
    U_E_MAIL 		char (128), 	-- electronic mail address of the user for contacts
    U_PWD 		char (128),	-- encrypted password of the user
    U_GROUP 		integer,	-- primary group membership (references G_ID from SYS_DAV_GROUP table)
    U_LOGIN_TIME 	datetime, 	-- last login date and time
    U_ACCOUNT_DISABLED 	integer,	-- 0/1 enabled/disabled
    U_METHODS 		integer,	-- reserved for future use
    U_DEF_PERMS 	char (10),	-- default 'umask' permissions
    U_HOME		varchar (128),	-- home collection of the user
    primary key (U_NAME)
)
create unique index SYS_DAV_USER_ID on WS.WS.SYS_DAV_USER (U_ID)
;


-- WebDAV Groups table
create table WS.WS.SYS_DAV_GROUP (
    G_ID 		integer,	-- unique ID of the group
    G_NAME 		char (128),	-- name of the group
    primary key (G_NAME)
)
create index SYS_DAV_GROUP_ID on WS.WS.SYS_DAV_GROUP (G_ID)
;

-- The granted groups to the WebDAV user table
create table WS.WS.SYS_DAV_USER_GROUP (
    UG_UID	integer,		-- ID of the grantee
    UG_GID	integer,		-- IG of the granted group
    primary key (UG_UID, UG_GID)
)
create index SYS_DAV_USER_GROUP_UID on WS.WS.SYS_DAV_USER_GROUP (UG_UID)
;


-- MIME file types (for mapping file extension to the content type) table
create table WS.WS.SYS_DAV_RES_TYPES (
    T_EXT		varchar,	-- file extension
    T_TYPE 		varchar,	-- MIME type
    T_DESCRIPTION	varchar,	-- optional description
    primary key (T_EXT)
)
;
