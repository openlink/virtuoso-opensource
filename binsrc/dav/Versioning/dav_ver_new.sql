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
--
DROP TABLE WS.WS.SYS_DAV_BASELINE_RES;
DROP TABLE WS.WS.SYS_DAV_BASELINE;
DROP TABLE WS.WS.SYS_DAV_CONFOBJ;
DROP TABLE WS.WS.SYS_DAV_WORKSPACE;
DROP TABLE WS.WS.SYS_DAV_ACTIVITY;
DROP TABLE WS.WS.SYS_DAV_RES_MERGE;
DROP TABLE WS.WS.SYS_DAV_RES_DIFF;
DROP TABLE WS.WS.SYS_DAV_RES_VERSION;

ALTER TABLE WS.WS.SYS_DAV_COL ADD COL_AUTO_VERSIONING char(1);

ALTER TABLE WS.WS.SYS_DAV_COL ADD COL_FORK INTEGER NOT NULL DEFAULT 0;

-- ALTER TABLE WS.WS.SYS_DAV_COL ADD COL_VERSION_NAME_TEMPLATE NOT NULL DEFAULT 'WS.WS.VERSION_NAME_TEMPLATE_PLAIN';

ALTER TABLE WS.WS.SYS_DAV_RES ADD RES_STATUS VARCHAR;

ALTER TABLE WS.WS.SYS_DAV_RES ADD RES_VCR_ID INTEGER;

ALTER TABLE WS.WS.SYS_DAV_RES ADD RES_VCR_CO_VERSION INTEGER;

ALTER TABLE WS.WS.SYS_DAV_RES ADD RES_VCR_STATE INTEGER; -- 0 CIN, -- 1 COUT

CREATE TABLE WS.WS.SYS_DAV_RES_VERSION (
  RV_RES_ID INTEGER NOT NULL, -- This is equal to either existing resource ID or to an attic ID
  RV_ID INTEGER NOT NULL, -- Version ID
  RV_NODE_NAME VARCHAR, -- Version number string as it can be used for data export. NULL to generate automatically.
  RV_PREV_ID INTEGER, -- referenced by WS.WS.SYS_DAV_VERSION (RV_ID) when NOT NULL
  RV_ACT_ID INTEGER, -- referenced by WS.WS.SYS_DAV_ACTIVITY (ACT_ID) when NOT NULL
  RV_RES_TYPE VARCHAR, -- MIME content type as it was in WS.WS.SYS_DAV_RES.RES_TYPE, NULL if deleted in this version.
  RV_CR_TIME  DATETIME, -- Old creation time as it was in WS.WS.SYS_DAV_RES.RES_CR_TIME
  RV_MOD_TIME DATETIME, -- Old modification time as it was in WS.WS.SYS_DAV_RES.RES_MOD_TIME
  PRIMARY KEY (RV_RES_ID, RV_ID)
);

CREATE TABLE WS.WS.SYS_DAV_RES_DIFF (
  RD_RES_ID       INTEGER NOT NULL, -- referenced by WS.WS.SYS_DAV_RES_VERSION (RV_RES_ID),
  RD_TO_ID        INTEGER NOT NULL, -- referenced by WS.WS.SYS_DAV_RES_VERSION (RV_ID),
  RD_FROM_ID      INTEGER, -- referenced by WS.WS.SYS_DAV_VERSION (RV_ID) when NOT NULL,
  RD_PROPS    LONG XML, -- all dead properties from WS.WS.SYS_DAV_PROP, including RDF props.
  RD_DELTA    LONG VARBINARY, -- the content of the diff or a full content of the resource
  RD_MODE     CHAR(1), -- a char indicating algorithm.
  RD_ARGS     VARCHAR DEFAULT '', -- arguments for diff algorithm, somewhat like -k in CVS.
  PRIMARY KEY (RD_RES_ID, RD_TO_ID, RD_FROM_ID)
);

CREATE TABLE WS.WS.SYS_DAV_RES_MERGE (
  RM_RES_ID INTEGER NOT NULL, -- This is equal to either existing resource ID or to an attic ID
  RM_ID INTEGER NOT NULL, -- Version number after merge
  RM_BRANCH_PREV_ID INTEGER NOT NULL, -- referenced by WS.WS.SYS_DAV_VERSION (RV_ID)
  RM_ACT_ID INTEGER, -- referenced by WS.WS.SYS_DAV_ACTIVITY (ACT_ID) when NOT NULL
  PRIMARY KEY (RM_RES_ID, RM_ID, RM_BRANCH_PREV_ID)
);

CREATE TABLE WS.WS.SYS_DAV_ACTIVITY (
  ACT_ID        INTEGER NOT NULL, -- Row identifier
  ACT_NAME      VARCHAR(256) NOT NULL, -- Readable name of the activity
  ACT_CR_TIME   DATETIME NOT NULL, -- Activity creation time
  ACT_CR_USER   VARCHAR NOT NULL references DB.DBA.SYS_USERS (U_NAME), -- Activity creation user ID
  PRIMARY KEY (ACT_ID)
);

CREATE TABLE WS.WS.SYS_DAV_WORKSPACE (
  WS_COL_ID  INTEGER NOT NULL references WS.WS.SYS_DAV_COL (COL_ID),
  WS_NAME    VARCHAR(256) NOT NULL, -- Readable name of the workspace
  WS_CR_TIME DATETIME NOT NULL,
  WS_CR_USER VARCHAR NOT NULL references DB.DBA.SYS_USERS (U_NAME),
  PRIMARY KEY (WS_COL_ID)
);

CREATE TABLE WS.WS.SYS_DAV_CONFOBJ (
  CONFO_ID INTEGER NOT NULL, -- Configuration object ID
  CONFO_NAME VARCHAR(256) NOT NULL, -- Readable name of configuration object
  CONFO_CR_TIME DATETIME NOT NULL, -- Creation time
  CONFO_CR_USER VARCHAR NOT NULL references DB.DBA.SYS_USERS (U_NAME),
  PRIMARY KEY (CONFO_ID)
);

CREATE TABLE WS.WS.SYS_DAV_BASELINE (
  BL_CONFO_ID INTEGER NOT NULL UNIQUE references WS.WS.SYS_DAV_CONFOBJ (CONFO_ID),
  BL_ID      INTEGER NOT NULL UNIQUE, -- Baseline object ID
  BL_NAME    VARCHAR(256) NOT NULL, -- Readable name of baseline object
  BL_CR_TIME DATETIME, -- Creation time
  BL_CR_USER VARCHAR references DB.DBA.SYS_USERS (U_NAME),
  PRIMARY KEY (BL_CONFO_ID, BL_ID)
);

CREATE TABLE WS.WS.SYS_DAV_BASELINE_RES (
  BR_CONFO_ID     INTEGER NOT NULL references WS.WS.SYS_DAV_BASELINE (BL_CONFO_ID),
  BR_BL_ID      INTEGER NOT NULL references WS.WS.SYS_DAV_BASELINE (BL_ID),
  BR_RES_ID     INTEGER NOT NULL, -- TODO: references WS.WS.SYS_DAV_RES_VERSION (RV_RES_ID),
  BR_VERSION_ID INTEGER NOT NULL, -- TODO: references WS.WS.SYS_DAV_RES_VERSION (RV_ID),
  PRIMARY KEY (BR_CONFO_ID, BR_BL_ID, BR_RES_ID)
);

use DB
;

--| When DAV_DELETE_INT calls DET function, authentication and check for lock are passed.
CREATE TRIGGER "Versioning_DAV_DELETE" BEFORE DELETE ON WS.WS.SYS_DAV_RES REFERENCING OLD AS O
{
  --dbg_obj_princ ('Versioning_DAV_DELETE ()');

 -- TODO: add Attic
  delete from WS.WS.SYS_DAV_RES_VERSION where RV_RES_ID = O.RES_ID;
  delete from WS.WS.SYS_DAV_RES_DIFF where RD_RES_ID = O.RES_ID;
}
;

create function "Versioning_NULL_VERSION" () returns integer
{
  return 0;
}
;
create function "Versioning_INITIAL_VERSION" () returns integer
{
  return 1;
}
;

create procedure "Versioning_ADD_NEW_DIFF" (in _res_id int,
	in version_id int,
	in version_prev_id int,
	in _props int,
	in _curr_content any,
	in _type char(1))
{
  declare _ver_id, _ver_prev_id int;
  if (version_id is null)
    _ver_id := "Versioning_INITIAL_VERSION" ();
  else
    _ver_id := version_id;
  if (version_prev_id is null)
    _ver_prev_id := "Versioning_NULL_VERSION" ();
  else
    _ver_prev_id := version_prev_id;
  -- Now only COPY is supported...
  if ('c' = _type)
    {
      insert into WS.WS.SYS_DAV_RES_DIFF (
	  RD_RES_ID, -- referenced by WS.WS.SYS_DAV_RES_VERSION (RV_RES_ID),
	  RD_TO_ID, -- referenced by WS.WS.SYS_DAV_RES_VERSION (RV_ID),
	  RD_FROM_ID, -- referenced by WS.WS.SYS_DAV_VERSION (RV_ID) when NOT NULL,
	  RD_PROPS, -- all dead properties from WS.WS.SYS_DAV_PROP, including RDF props.
	  RD_DELTA, -- the content of the diff or a full content of the resource
	  RD_MODE ) -- a char indicating algorithm.
	values
	  ( _res_id, _ver_id, _ver_prev_id, _props, _curr_content, 'c' );
    }
}
;

CREATE TRIGGER "Versioning_DAV_COL_INSERT" AFTER INSERT ON WS.WS.SYS_DAV_COL REFERENCING NEW AS N
{
  update WS.WS.SYS_DAV_COL set COL_AUTO_VERSIONING = 'C' where COL_ID = N.COL_ID;
}
;

CREATE TRIGGER "Versioning_DAV_RES_INSERT" AFTER INSERT ON WS.WS.SYS_DAV_RES REFERENCING NEW AS N
{
  if (exists (select * from WS.WS.SYS_DAV_COL where COL_ID = N.RES_COL and COL_AUTO_VERSIONING is not null))
    {
      --dbg_obj_princ ('Versioning_DAV_RES_UPLOAD ()');
      declare dt datetime;
      dt := now();
      set triggers off;
      update WS.WS.SYS_DAV_RES set RES_STATUS = 'AV' where RES_ID = N.RES_ID;
      set triggers on;
      insert into WS.WS.SYS_DAV_RES_VERSION (RV_RES_ID , -- This is equal to either existing resource ID or to an attic ID
		  RV_ID, -- Version ID
		  RV_NODE_NAME, -- Version number string as it can be used for data export. NULL to generate automatically.
		  RV_PREV_ID, -- referenced by WS.WS.SYS_DAV_VERSION (RV_ID) when NOT NULL
		  RV_ACT_ID, -- referenced by WS.WS.SYS_DAV_ACTIVITY (ACT_ID) when NOT NULL
		  RV_RES_TYPE, -- MIME content type as it was in WS.WS.SYS_DAV_RES.RES_TYPE, NULL if deleted in this version.
		  RV_CR_TIME, -- Old creation time as it was in WS.WS.SYS_DAV_RES.RES_CR_TIME
		  RV_MOD_TIME) -- Old modification time as it was in WS.WS.SYS_DAV_RES.RES_MOD_TIME
	values (N.RES_ID, "Versioning_INITIAL_VERSION" (),
		NULL, NULL, NULL, N.RES_TYPE, dt, dt);
	"Versioning_ADD_NEW_DIFF" (N.RES_ID, NULL, NULL, NULL, N.RES_CONTENT, 'c');
    }
}
;
CREATE TRIGGER "Versioning_DAV_RES_UPDATE" AFTER UPDATE ON WS.WS.SYS_DAV_RES REFERENCING NEW AS N
{
  if (exists (select * from WS.WS.SYS_DAV_COL where COL_ID = N.RES_COL and COL_AUTO_VERSIONING is not null))
    {
      --dbg_obj_princ ('Versioning_DAV_RES_UPDATE ()');
      declare dt datetime;
      dt:=now();
      declare _ver_id, _ver_prev_id int;
      _ver_prev_id := (select max (RV_ID) from WS.WS.SYS_DAV_RES_VERSION
      			where RV_RES_ID = N.RES_ID);
      _ver_id := _ver_prev_id + 1;
      insert into WS.WS.SYS_DAV_RES_VERSION (RV_RES_ID , -- This is equal to either existing resource ID or to an attic ID
		  RV_ID, -- Version ID
		  RV_NODE_NAME, -- Version number string as it can be used for data export. NULL to generate automatically.
		  RV_PREV_ID, -- referenced by WS.WS.SYS_DAV_VERSION (RV_ID) when NOT NULL
		  RV_ACT_ID, -- referenced by WS.WS.SYS_DAV_ACTIVITY (ACT_ID) when NOT NULL
		  RV_RES_TYPE, -- MIME content type as it was in WS.WS.SYS_DAV_RES.RES_TYPE, NULL if deleted in this version.
		  RV_CR_TIME, -- Old creation time as it was in WS.WS.SYS_DAV_RES.RES_CR_TIME
		  RV_MOD_TIME) -- Old modification time as it was in WS.WS.SYS_DAV_RES.RES_MOD_TIME
	values (N.RES_ID, _ver_id,
		NULL, _ver_prev_id, NULL, N.RES_TYPE, dt, dt);
      "Versioning_ADD_NEW_DIFF" (N.RES_ID, _ver_id, _ver_prev_id, NULL, N.RES_CONTENT, 'c');
    }
}
;

create function DAV_GET_VERSION_CONTENT (in res_id integer, in ver integer, inout content any, out type varchar, inout mode any)
{
  declare ver_path any;
  declare curr_ver, next_ver_copy, next_ver, prev_ver integer;
  next_ver := -1;
  -- The most popular case is retrieval of some 'key' version, e.g. the latest.
  --dbg_obj_princ ('DAV_GET_VERSION_CONTENT (', res_id, ',', ver, ', [content], [mode])');
  for select RV_RES_TYPE, RD_DELTA, RD_MODE, RD_ARGS from WS.WS.SYS_DAV_RES_DIFF
  	inner join WS.WS.SYS_DAV_RES_VERSION
	on (RV_RES_ID = RD_RES_ID and RV_ID = RD_TO_ID)
    where RD_RES_ID = res_id and RD_TO_ID = ver and RD_FROM_ID = "Versioning_NULL_VERSION" () do
    {
      -- unpack RD_DELTA if needed and place into \c content
      content := RD_DELTA;
      type := RV_RES_TYPE;
      return 0;
    }
  vectorbld_init (ver_path);
  next_ver_copy := ver;
  vectorbld_acc (ver_path, next_ver_copy);
  curr_ver := ver;

find_next_ver:
  for select RD_DELTA, RD_MODE, RD_ARGS from WS.WS.SYS_DAV_RES_DIFF
    where RD_RES_ID = res_id and RD_TO_ID = curr_ver and RD_FROM_ID = "Versioning_NULL_VERSION" () do
    {
      -- unpack RD_DELTA
      goto key_found;
    }
  next_ver_copy := null;
  next_ver := null;
  for select RD_FROM_ID from WS.WS.SYS_DAV_RES_DIFF
    where RD_RES_ID = res_id and RD_TO_ID = curr_ver and RD_FROM_ID <> "Versioning_NULL_VERSION" () do
  {
    next_ver_copy := rd_from_id;
    next_ver := rd_from_id;
  }
  if (next_ver is null)
    goto report_invalid_version_number;
  vectorbld_acc (ver_path, next_ver_copy);
  curr_ver := next_ver;
  goto find_next_ver;

key_found:
  vectorbld_final (ver_path);
  -- get text from version curr_ver;
  --dbg_obj_princ ('= ', ver_path);
  whenever not found goto report_invalid_version_number;
  declare ctr int;
  curr_ver := "Versioning_NULL_VERSION" ();
  for (ctr := length (ver_path)-1; ctr >= 0; ctr := ctr - 1)
    {
      declare curr_delta any;
      declare curr_mode, curr_args varchar;
      prev_ver := ver_path [ctr];
      --dbg_obj_print ('delta: ', prev_ver, curr_ver);
      select RD_DELTA, RD_MODE, RD_ARGS into curr_delta, curr_mode, curr_args from WS.WS.SYS_DAV_RES_DIFF
        where RD_RES_ID = res_id and RD_TO_ID = prev_ver and RD_FROM_ID = curr_ver;
      -- apply the patch
      --dbg_obj_print ('delta: ', curr_delta, curr_mode, curr_args);
      if (curr_mode = 'c')
        content := curr_delta;
      else
        signal ('XXXXX', 'Versioning: diff mode [' || curr_mode || '] is not supported');
      curr_ver := prev_ver;
    }
  -- put the resulting doc to \c content.
  type := (select RV_RES_TYPE from WS.WS.SYS_DAV_RES_VERSION V
  		where V.RV_RES_ID = res_id and V.RV_ID = ver);
  return 0;
report_invalid_version_number:
  return -1;
}
