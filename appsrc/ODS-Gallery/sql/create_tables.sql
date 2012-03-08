--
--  $Id$
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2012 OpenLink Software
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

PHOTO.WA._exec_no_error(
'
create table PHOTO.WA.COMMENTS (
  COMMENT_ID  integer not null,
  PARENT_ID   integer,
  GALLERY_ID  integer not null,
  RES_ID      integer not null,
  CREATE_DATE DATETIME not null,
  MODIFY_DATE DATETIME,
  USER_ID     integer not null,
  TEXT        varchar,
  RFC_ID      varchar,
  RFC_HEADER  long varchar,
  RFC_REFERENCES varchar default null,

  PRIMARY KEY(COMMENT_ID))'
)
;
wa_add_col('PHOTO.WA.COMMENTS', 'PARENT_ID', 'integer')
;
wa_add_col('PHOTO.WA.COMMENTS', 'RFC_ID', 'varchar')
;
wa_add_col('PHOTO.WA.COMMENTS', 'RFC_HEADER', 'long varchar')
;
wa_add_col('PHOTO.WA.COMMENTS', 'RFC_REFERENCES', 'varchar default null')
;

PHOTO.WA._exec_no_error(
'
create table PHOTO.WA.SYS_INFO (
  GALLERY_ID    integer not null,
  OWNER_ID      integer not null,
  WAI_NAME      VARCHAR not null,
  HOME_URL      VARCHAR not null,
  HOME_PATH     VARCHAR not null,
  SHOW_MAP      integer default 0,
  SHOW_TIMELINE integer default 0,
  NNTP          integer default 0,
  NNTP_INIT     integer default 0,

  PRIMARY KEY(GALLERY_ID))'
)
;

wa_add_col('PHOTO.WA.SYS_INFO', 'SHOW_MAP', 'integer default 0')
;
wa_add_col('PHOTO.WA.SYS_INFO', 'SHOW_TIMELINE', 'integer default 0')
;
alter table PHOTO.WA.SYS_INFO modify column SHOW_MAP integer default 0;
alter table PHOTO.WA.SYS_INFO modify column SHOW_TIMELINE integer default 0;
wa_add_col('PHOTO.WA.SYS_INFO', 'NNTP', 'integer default 0');
wa_add_col('PHOTO.WA.SYS_INFO', 'NNTP_INIT', 'integer default 0');

update PHOTO.WA.SYS_INFO set SHOW_MAP = 0 where SHOW_MAP is null;
update PHOTO.WA.SYS_INFO set SHOW_TIMELINE = 0 where SHOW_TIMELINE is null;

update PHOTO.WA.SYS_INFO set NNTP = 0 where NNTP is null;
update PHOTO.WA.SYS_INFO set NNTP_INIT = 0 where NNTP_INIT is null;

wa_add_col('PHOTO.WA.SYS_INFO', 'SETTINGS', 'varchar');

PHOTO.WA._exec_no_error(
'
create table PHOTO.WA.EXIF_DATA(
  RES_ID      integer not null,
  EXIF_PROP   VARCHAR(255),
  EXIF_VALUE  VARCHAR(255),
  
  PRIMARY KEY(RES_ID,EXIF_PROP))'
)
;

PHOTO.WA._exec_no_error(
'CREATE INDEX HOME_PATH_INDEX ON PHOTO.WA.SYS_INFO (HOME_PATH)'
)
;

PHOTO.WA._exec_no_error(
'ALTER TABLE PHOTO.WA.COMMENTS ADD COLUMN GALLERY_ID integer not null','C','PHOTO.WA.comments','GALLERY_ID'
)
;

PHOTO.WA._exec_no_error(
'ALTER TABLE PHOTO.WA.COMMENTS ADD COLUMN MODIFY_DATE DATETIME','C','PHOTO.WA.comments','MODIFY_DATE'
)
;

PHOTO.WA._exec_no_error(
'CREATE UNIQUE INDEX WAI_NAME ON PHOTO.WA.SYS_INFO (WAI_NAME)'
)
;