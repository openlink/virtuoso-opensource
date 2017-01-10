--
--  replddk.sql
--
--  $Id$
--
--  TRX replication support tables definition
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

-- Publications table (for transactional replication)
create table SYS_TP_ITEM (
       TI_SERVER 	varchar, 	-- publisher server name (local for publications, remote for subcr)
       TI_ACCT 		varchar,        -- account name
       TI_TYPE 		integer,	-- type of item 2 - table, 3 - proc, 1 - DAV collection
       TI_ITEM 		varchar,	-- qualifier of item (full path)
       TI_OPTIONS 	any,		-- 1 - proc is logged 2 - proc definition is logged
       TI_IS_COPY 	integer,	-- delete local if on publisher deleted or sync procs (1/0)
       TI_DAV_USER	varchar,	-- default DAV user if not null
       TI_DAV_GROUP	varchar,	-- default DAV group if not null
       primary key (TI_SERVER, TI_ACCT, TI_TYPE, TI_ITEM)
       )
;

create view TP_ITEM as select * from SYS_TP_ITEM where TI_SERVER = repl_this_server ()
;

exec ('grant select on TP_ITEM to PUBLIC')
;

--#IF VER=5
alter table SYS_REPL_ACCOUNTS add IS_UPDATEABLE integer
;

alter table SYS_REPL_ACCOUNTS add SYNC_USER varchar
;

alter table SYS_REPL_ACCOUNTS add P_MONTH integer
;

alter table SYS_REPL_ACCOUNTS add P_DAY integer
;

alter table SYS_REPL_ACCOUNTS add P_WDAY integer
;

alter table SYS_REPL_ACCOUNTS add P_TIME time
;
--#ENDIF

create view REPL_ACCOUNTS as select SERVER, ACCOUNT from SYS_REPL_ACCOUNTS
       where SERVER = repl_this_server () and ACCOUNT <> repl_this_server ()
;

exec ('grant select on REPL_ACCOUNTS to PUBLIC')
;

create table SYS_TP_GRANT (
       TPG_ACCT 	varchar, 				--  account
       TPG_GRANTEE 	varchar, --- references SYS_USERS (U_NAME), 	 -- user
       primary key (TPG_ACCT, TPG_GRANTEE)
       )
;

create table SYS_REPL_CR (
  CR_ID         integer,
  CR_TABLE_NAME varchar,    -- table
  CR_TYPE       char,       -- CR type ('I', 'U' or 'D')
  CR_PROC       varchar,    -- procedure to execute
  CR_ORDER      integer,    -- order

  primary key (CR_ID)
)
;

exec ('grant select on SYS_REPL_CR to PUBLIC')
;
