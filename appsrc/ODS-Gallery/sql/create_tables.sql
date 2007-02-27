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

PHOTO.WA._exec_no_error(
'
CREATE TABLE PHOTO.WA.comments(
  COMMENT_ID  INTEGER NOT NULL,
  GALLERY_ID  INTEGER NOT NULL,
  RES_ID      INTEGER NOT NULL,
  CREATE_DATE DATETIME NOT NULL,
  MODIFY_DATE DATETIME     NULL,
  USER_ID     INTEGER  NOT NULL,
  TEXT        varchar  NULL,

  PRIMARY KEY(COMMENT_ID))'
)
;

PHOTO.WA._exec_no_error(
'
CREATE TABLE PHOTO.WA.SYS_INFO(
  GALLERY_ID    INTEGER NOT NULL,
  OWNER_ID      INTEGER NOT NULL,
  WAI_NAME      VARCHAR NOT NULL,
  HOME_URL      VARCHAR NOT NULL,
  HOME_PATH     VARCHAR NOT NULL,

  PRIMARY KEY(GALLERY_ID))'
)
;

PHOTO.WA._exec_no_error(
'
CREATE TABLE PHOTO.WA.EXIF_DATA(
  RES_ID      INTEGER NOT NULL,
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
'ALTER TABLE PHOTO.WA.comments ADD COLUMN GALLERY_ID INTEGER NOT NULL','C','PHOTO.WA.comments','GALLERY_ID'
)
;

PHOTO.WA._exec_no_error(
'ALTER TABLE PHOTO.WA.comments ADD COLUMN MODIFY_DATE DATETIME','C','PHOTO.WA.comments','MODIFY_DATE'
)
;

PHOTO.WA._exec_no_error(
'CREATE UNIQUE INDEX WAI_NAME ON PHOTO.WA.SYS_INFO (WAI_NAME)'
)
;