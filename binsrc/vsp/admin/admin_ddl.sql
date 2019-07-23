--
--  $Id$
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2019 OpenLink Software
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
create table ADMIN_SESSION
(
  ASES_ID          varchar (32),
  ASES_LAST_ACCESS datetime,
  ASES_TREE        long varchar,
  ASES_VARS	   long varchar,
  primary key (ASES_ID)
)
;


create view ADM_XML_VIEWS as select V_NAME from SYS_VIEWS where V_TEXT like 'create xml%'
;

-- table required for auditing
create table WS.WS.AUDIT_LOG (
  EVTTIME timestamp,
  REFERER varchar,
  HOST varchar,
  COMMAND varchar,
  AUTHSTRING varchar,
  USERNAME varchar(200),
  REALM varchar(200),
  AUTHALGORITHM varchar(100),
  URI varchar,
  USERAGENT varchar,
  CLIENT varchar
)
;

