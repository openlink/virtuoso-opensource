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

OMAIL.WA.exec_no_error('
  CREATE TABLE OMAIL.WA.RES_MIME_TYPES (
    ID          INTEGER NOT NULL,
    MIME_TYPE   VARCHAR(30) NOT NULL,
    DESCRIPTION	VARCHAR(255),
    ICON16     	LONG VARBINARY,
    ICON32     	LONG VARBINARY,

    PRIMARY KEY (ID)
  )'
)
;

OMAIL.WA.exec_no_error('
  CREATE TABLE OMAIL.WA.RES_MIME_EXT (
    EXT_ID    INTEGER,
    MIME_ID   INTEGER,
    EXT_NAME  VARCHAR,

    PRIMARY KEY (EXT_ID)
  )'
)
;

OMAIL.WA.exec_no_error(
 'ALTER TABLE OMAIL.WA.RES_MIME_EXT ADD FOREIGN KEY (MIME_ID) REFERENCES OMAIL.WA.RES_MIME_TYPES(ID)'
)
;
