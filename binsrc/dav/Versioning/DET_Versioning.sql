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
--#IF VER=5
ALTER TABLE WS.WS.SYS_DAV_COL ADD COL_AUTO_VERSIONING char(1)
;

ALTER TABLE WS.WS.SYS_DAV_COL ADD COL_FORK INTEGER DEFAULT 0
;

ALTER TABLE WS.WS.SYS_DAV_RES ADD RES_STATUS VARCHAR
;

ALTER TABLE WS.WS.SYS_DAV_RES ADD RES_VCR_ID INTEGER
;

ALTER TABLE WS.WS.SYS_DAV_RES ADD RES_VCR_CO_VERSION INTEGER
;

ALTER TABLE WS.WS.SYS_DAV_RES ADD RES_VCR_STATE INTEGER -- 0 CIN, -- 1 COUT
;
--#ENDIF

CREATE TABLE WS.WS.SYS_DAV_RES_VERSION (
  RV_RES_ID INTEGER NOT NULL, -- This is equal to either existing resource ID or to an attic ID
  RV_ID INTEGER NOT NULL, -- Version ID
  RV_NODE_NAME VARCHAR, -- Version number string as it can be used for data export. NULL to generate automatically.
  RV_PREV_ID INTEGER, -- referenced by WS.WS.SYS_DAV_VERSION (RV_ID) when NOT NULL
  RV_ACT_ID INTEGER, -- referenced by WS.WS.SYS_DAV_ACTIVITY (ACT_ID) when NOT NULL
  RV_RES_TYPE VARCHAR, -- MIME content type as it was in WS.WS.SYS_DAV_RES.RES_TYPE, NULL if deleted in this version.
  RV_CR_TIME  DATETIME, -- Old creation time as it was in WS.WS.SYS_DAV_RES.RES_CR_TIME
  RV_MOD_TIME DATETIME, -- Old modification time as it was in WS.WS.SYS_DAV_RES.RES_MOD_TIME
  RV_WHO VARCHAR,
  RV_SIZE INTEGER NOT NULL,
  PRIMARY KEY (RV_RES_ID, RV_ID)
)
alter index SYS_DAV_RES_VERSION on WS.WS.SYS_DAV_RES_VERSION partition (RV_RES_ID int)
;


--#IF VER=5
ALTER TABLE WS.WS.SYS_DAV_RES_VERSION ADD RV_WHO VARCHAR
;
--#ENDIF

CREATE TABLE WS.WS.SYS_DAV_RES_DIFF (
  RD_RES_ID       INTEGER NOT NULL, -- referenced by WS.WS.SYS_DAV_RES_VERSION (RV_RES_ID),
  RD_TO_ID        INTEGER NOT NULL, -- referenced by WS.WS.SYS_DAV_RES_VERSION (RV_ID),
  RD_FROM_ID      INTEGER, -- referenced by WS.WS.SYS_DAV_VERSION (RV_ID) when NOT NULL,
  RD_PROPS    LONG XML, -- all dead properties from WS.WS.SYS_DAV_PROP, including RDF props.
  RD_DELTA    LONG VARBINARY, -- the content of the diff or a full content of the resource
  RD_MODE     CHAR(1), -- a char indicating algorithm.
  RD_ARGS     VARCHAR DEFAULT '', -- arguments for diff algorithm, somewhat like -k in CVS.
  PRIMARY KEY (RD_RES_ID, RD_TO_ID, RD_FROM_ID)
)
alter index SYS_DAV_RES_DIFF on WS.WS.SYS_DAV_RES_DIFF partition (RD_RES_ID int)
;

CREATE TABLE WS.WS.SYS_DAV_RES_MERGE (
  RM_RES_ID INTEGER NOT NULL, -- This is equal to either existing resource ID or to an attic ID
  RM_ID INTEGER NOT NULL, -- Version number after merge
  RM_BRANCH_PREV_ID INTEGER NOT NULL, -- referenced by WS.WS.SYS_DAV_VERSION (RV_ID)
  RM_ACT_ID INTEGER, -- referenced by WS.WS.SYS_DAV_ACTIVITY (ACT_ID) when NOT NULL
  PRIMARY KEY (RM_RES_ID, RM_ID, RM_BRANCH_PREV_ID)
)
alter index SYS_DAV_RES_MERGE on WS.WS.SYS_DAV_RES_MERGE partition (RM_RES_ID int)
;

CREATE TABLE WS.WS.SYS_DAV_ACTIVITY (
  ACT_ID        INTEGER NOT NULL, -- Row identifier
  ACT_NAME      VARCHAR(256) NOT NULL, -- Readable name of the activity
  ACT_CR_TIME   DATETIME NOT NULL, -- Activity creation time
  ACT_CR_USER   VARCHAR NOT NULL, -- references DB.DBA.SYS_USERS (U_NAME), -- Activity creation user ID
  PRIMARY KEY (ACT_ID)
)
alter index SYS_DAV_ACTIVITY on WS.WS.SYS_DAV_ACTIVITY partition (ACT_ID int)
;

CREATE TABLE WS.WS.SYS_DAV_WORKSPACE (
  WS_COL_ID  INTEGER NOT NULL, -- references WS.WS.SYS_DAV_COL (COL_ID),
  WS_NAME    VARCHAR(256) NOT NULL, -- Readable name of the workspace
  WS_CR_TIME DATETIME NOT NULL,
  WS_CR_USER VARCHAR NOT NULL, -- references DB.DBA.SYS_USERS (U_NAME),
  PRIMARY KEY (WS_COL_ID)
)
alter index SYS_DAV_WORKSPACE on WS.WS.SYS_DAV_WORKSPACE partition (WS_COL_ID int)
;

CREATE TABLE WS.WS.SYS_DAV_CONFOBJ (
  CONFO_ID INTEGER NOT NULL, -- Configuration object ID
  CONFO_NAME VARCHAR(256) NOT NULL, -- Readable name of configuration object
  CONFO_CR_TIME DATETIME NOT NULL, -- Creation time
  CONFO_CR_USER VARCHAR NOT NULL, -- references DB.DBA.SYS_USERS (U_NAME),
  PRIMARY KEY (CONFO_ID)
)
alter index SYS_DAV_CONFOBJ on WS.WS.SYS_DAV_CONFOBJ partition (CONFO_ID int)
;

CREATE TABLE WS.WS.SYS_DAV_BASELINE (
  BL_CONFO_ID INTEGER NOT NULL UNIQUE, -- references WS.WS.SYS_DAV_CONFOBJ (CONFO_ID),
  BL_ID      INTEGER NOT NULL UNIQUE, -- Baseline object ID
  BL_NAME    VARCHAR(256) NOT NULL, -- Readable name of baseline object
  BL_CR_TIME DATETIME, -- Creation time
  BL_CR_USER VARCHAR, -- references DB.DBA.SYS_USERS (U_NAME),
  PRIMARY KEY (BL_CONFO_ID, BL_ID)
)
alter index SYS_DAV_BASELINE on WS.WS.SYS_DAV_BASELINE partition (BL_CONFO_ID int)
;

CREATE TABLE WS.WS.SYS_DAV_BASELINE_RES (
  BR_CONFO_ID     INTEGER NOT NULL, -- references WS.WS.SYS_DAV_BASELINE (BL_CONFO_ID),
  BR_BL_ID      INTEGER NOT NULL, -- references WS.WS.SYS_DAV_BASELINE (BL_ID),
  BR_RES_ID     INTEGER NOT NULL, -- TODO: references WS.WS.SYS_DAV_RES_VERSION (RV_RES_ID),
  BR_VERSION_ID INTEGER NOT NULL, -- TODO: references WS.WS.SYS_DAV_RES_VERSION (RV_ID),
  PRIMARY KEY (BR_CONFO_ID, BR_BL_ID, BR_RES_ID)
)
alter index SYS_DAV_BASELINE_RES on WS.WS.SYS_DAV_BASELINE_RES partition (BR_RES_ID int)
;

--#IF VER=5
ALTER TABLE WS.WS.SYS_DAV_RES_VERSION ADD RV_SIZE INTEGER NOT NULL
;

UPDATE WS.WS.SYS_DAV_RES_VERSION SET RV_SIZE = 0 WHERE RV_SIZE IS NULL
;
--#ENDIF

--| When DAV_DELETE_INT calls DET function, authentication and check for lock are passed.
CREATE TRIGGER "Versioning_DAV_DELETE" BEFORE DELETE ON WS.WS.SYS_DAV_RES REFERENCING OLD AS O
{
  --dbg_obj_princ ('Versioning_DAV_DELETE ()');

 -- TODO: add Attic check for permanent delete
  connection_set ('Versioning REM PROP', 1);
  delete from WS.WS.SYS_DAV_RES_VERSION where RV_RES_ID = O.RES_ID;
  delete from WS.WS.SYS_DAV_RES_DIFF where RD_RES_ID = O.RES_ID;
}
;

CREATE TRIGGER "Versioning_DAV_DELETE_AFT" AFTER DELETE ON WS.WS.SYS_DAV_RES REFERENCING OLD AS O
{
  --dbg_obj_princ ('Versioning_DAV_DELETE () after ');
  connection_set ('Versioning REM PROP', NULL);
}
;


CREATE TRIGGER "Versioning_PROP_DELETE" BEFORE DELETE ON WS.WS.SYS_DAV_PROP REFERENCING OLD AS O
{
  declare exit handler for sqlstate '*' {
    --dbg_obj_princ ('DP Error: ', __SQL_STATE, __SQL_MESSAGE);
    resignal;
  }
  ;
   --dbg_obj_princ ('Versioning_DAV_DELETE ()');

  --dbg_obj_print ('DELETE: ', O.PROP_NAME, ' ', connection_get ('Versioning REM PROP'));
  if (connection_get ('Versioning REM PROP') is null and O.PROP_NAME in ('DAV:checked-in', 'DAV:checked-out', 'DAV:version-history', 'DAV:author'))
    signal ('VR004', O.PROP_NAME || ' property belongs to Versioning control and it is read-only');
}
;

create procedure "Versioning_ADD_NEW_DIFF" (in _res_id int,
  in version_id int,
  in version_prev_id int,
  inout _curr_content any,
  in _type char(1),
  in _diff varchar:=NULL)
{
  declare _ver_id, _ver_prev_id int;
  if (version_id is null)
    _ver_id := 1;
  else
    _ver_id := version_id;
  if (version_prev_id is null)
    _ver_prev_id := 0;
  else
    _ver_prev_id := version_prev_id;
  --dbg_obj_print ('test2');
  if ('c' = _type) {
    update WS.WS.SYS_DAV_RES_DIFF
      set RD_FROM_ID = _ver_id
      where RD_RES_ID = _res_id
        and RD_TO_ID = _ver_prev_id;
  }
  else if ( ('D' = _type) and (_diff is not null) ) {
    update WS.WS.SYS_DAV_RES_DIFF
      set RD_FROM_ID = _ver_id,
          RD_DELTA = _diff,
          RD_MODE = _type
      where RD_RES_ID = _res_id
      and RD_TO_ID = _ver_prev_id;
    }
    else
      signal ('VR001', 'Unsupported delta algorithm: ' || _type );

--Collect all dead properties
  declare _props any;
  _props := (select XMLELEMENT ('Props',
    XMLAGG (
      XMLELEMENT ('property',
      XMLATTRIBUTES (PROP_NAME as "name"),
       PROP_VALUE)))
        from WS.WS.SYS_DAV_PROP
    where PROP_PARENT_ID = _res_id
    and PROP_NAME not like 'DAV:%'
    and PROP_NAME not like ':%'
    and PROP_NAME not like 'virt:');
  insert into WS.WS.SYS_DAV_RES_DIFF (
    RD_RES_ID, -- referenced by WS.WS.SYS_DAV_RES_VERSION (RV_RES_ID),
    RD_TO_ID, -- referenced by WS.WS.SYS_DAV_RES_VERSION (RV_ID),
    RD_FROM_ID, -- referenced by WS.WS.SYS_DAV_VERSION (RV_ID) when NOT NULL,
    RD_PROPS, -- all dead properties from WS.WS.SYS_DAV_PROP, including RDF props.
    RD_DELTA, -- the content of the diff or a full content of the resource
    RD_MODE ) -- a char indicating algorithm.
  values
    ( _res_id, _ver_id, 0, _props, _curr_content, 'c');
  --dbg_obj_print ('done');
}
;

CREATE TRIGGER "Versioning_DAV_RES_INSERT" AFTER INSERT ON WS.WS.SYS_DAV_RES ORDER 10 REFERENCING NEW AS N
{
  declare exit handler for sqlstate '*' {
    rollback work;
    --dbg_obj_princ ('I Error: ', __SQL_STATE, __SQL_MESSAGE);
    resignal;
  }
  ;
  if (exists (select 1 from WS.WS.SYS_DAV_COL where COL_ID = N.RES_COL and COL_AUTO_VERSIONING is not null)) {
  --dbg_obj_princ ('Versioning_DAV_RES_INSERT (', N.RES_COL, ' ', N.RES_NAME, ' ', N.RES_FULL_PATH,')');
  --dbg_obj_princ (3, WS.WS.ACL_PARSE (dav_prop_get ('/DAV/home/dav/wiki/Main/BlogFAQ.txt', ':virtacl', 'dav','dav')));
    declare exit handler for sqlstate '*' {
      rollback work;
      --dbg_obj_princ (__SQL_STATE, ' ', __SQL_MESSAGE);
      resignal;
    }
    ;
    declare dt datetime;
    dt := now();
    set triggers off;
    update WS.WS.SYS_DAV_RES set RES_STATUS = 'AV' where RES_ID = N.RES_ID;
    set triggers on;
    delete from WS.WS.SYS_DAV_RES_VERSION where RV_RES_ID = N.RES_ID;
    delete from WS.WS.SYS_DAV_RES_DIFF where RD_RES_ID = N.RES_ID;
    insert replacing WS.WS.SYS_DAV_RES_VERSION (RV_RES_ID , -- This is equal to either existing resource ID or to an attic ID
      RV_ID, -- Version ID
      RV_NODE_NAME, -- Version number string as it can be used for data export. NULL to generate automatically.
      RV_PREV_ID, -- referenced by WS.WS.SYS_DAV_VERSION (RV_ID) when NOT NULL
      RV_ACT_ID, -- referenced by WS.WS.SYS_DAV_ACTIVITY (ACT_ID) when NOT NULL
      RV_RES_TYPE, -- MIME content type as it was in WS.WS.SYS_DAV_RES.RES_TYPE, NULL if deleted in this version.
      RV_CR_TIME, -- Old creation time as it was in WS.WS.SYS_DAV_RES.RES_CR_TIME
      RV_MOD_TIME, -- Old modification time as it was in WS.WS.SYS_DAV_RES.RES_MOD_TIME
      RV_WHO,
      RV_SIZE)
    values (N.RES_ID, 1, NULL, NULL, NULL, N.RES_TYPE, dt, dt, connection_get ('HTTP_CLI_UID'), length(N.RES_CONTENT));
    "Versioning_ADD_NEW_DIFF" (N.RES_ID, NULL, NULL, N.RES_CONTENT, 'c');
    --dbg_obj_princ (4, WS.WS.ACL_PARSE (dav_prop_get ('/DAV/home/dav/wiki/Main/BlogFAQ.txt', ':virtacl', 'dav','dav')));

    declare _hist_col varchar;
    declare _props any;
    _props := vector ('DAV:auto-version',
      (select "Versioning_AUTO_VERSION_PROP" (COL_AUTO_VERSIONING)
        from WS.WS.SYS_DAV_COL where COL_ID = N.RES_COL),
        'DAV:author',
        (select U_NAME from DB.DBA.SYS_USERS where U_ID = N.RES_OWNER));
    _hist_col := DAV_PROP_GET_INT (N.RES_COL, 'C','virt:Versioning-History', 0);
    --dbg_obj_princ (5, WS.WS.ACL_PARSE (dav_prop_get ('/DAV/home/dav/wiki/Main/BlogFAQ.txt', ':virtacl', 'dav','dav')));

    if (not isinteger (_hist_col))
      _props := vector_concat (_props, vector ('DAV:checked-in', _hist_col || N.RES_NAME || '/last', 'DAV:version-history', _hist_col || N.RES_NAME || '/history.xml'));
    DAV_SET_VERSIONING_PROPERTIES (N.RES_FULL_PATH, _props);
    --dbg_obj_princ (6, WS.WS.ACL_PARSE (dav_prop_get ('/DAV/home/dav/wiki/Main/BlogFAQ.txt', ':virtacl', 'dav','dav')));
  }
}
;

CREATE TRIGGER "Versioning_DAV_RES_UPDATE" BEFORE UPDATE ON WS.WS.SYS_DAV_RES ORDER 10 REFERENCING NEW AS N, OLD AS O
{
  declare _diff, _diff_type varchar;
  _diff := NULL;
  _diff_type := 'c';

  declare exit handler for sqlstate '*' {
    if (__SQL_STATE like 'DF*')
      goto _next;
    resignal;
  }
  ;

  declare _auto_version_type varchar;
  _auto_version_type := coalesce (
    "Versioning_AUTO_VERSION_PROP" ((select COL_AUTO_VERSIONING from WS.WS.SYS_DAV_COL where COL_ID = N.RES_COL and COL_AUTO_VERSIONING is not null)),
    DAV_HIDE_ERROR(DAV_PROP_GET_INT (N.RES_ID, 'R', 'DAV:auto-version', 0)));

  if (DAV_HIDE_ERROR (DAV_PROP_GET_INT (N.RES_ID,'R','DAV:checked-out')) is null and _auto_version_type is not null) {
    if ((length (N.RES_CONTENT) < 10000000) and (length (O.RES_CONTENT) < 10000000)) {
      if (cast (N.RES_CONTENT as varchar) = cast (O.RES_CONTENT as varchar)) {
        if (N.RES_NAME <> O.RES_NAME) { -- move
          declare _hist_col varchar;
          _hist_col := DAV_PROP_GET_INT (N.RES_COL, 'C','virt:Versioning-History', 0);
          if (not isinteger (_hist_col))
            DAV_SET_VERSIONING_PROPERTIES (N.RES_FULL_PATH,
              vector ('DAV:checked-in', _hist_col || N.RES_NAME || '/last',
             'DAV:version-history', _hist_col || N.RES_NAME || '/history.xml'));
        }
        return;
      };
      if ( (N.RES_TYPE = O.RES_TYPE) and (N.RES_TYPE like 'text/%') ) {
      -- whenever sqlstate '22*' goto full_copy;
      _diff := diff (cast (N.RES_CONTENT as varchar), cast (O.RES_CONTENT as varchar), '--normal');
      _diff_type := 'D';
      --dbg_obj_print ('_diff: ', _diff);
      }
    };
  _next:
    --dbg_obj_princ ('SQL ERR: ', __SQL_STATE, __SQL_MESSAGE);
    declare dt datetime;
    dt:=now();
    declare _ver_id, _ver_prev_id int;
    _ver_prev_id := coalesce ((select max (RV_ID) from WS.WS.SYS_DAV_RES_VERSION where RV_RES_ID = N.RES_ID),0);
    _ver_id := _ver_prev_id + 1;

    declare _id int;
    declare _type varchar;
    _id := N.RES_ID;
    _type := 'R';
    -- dbg_obj_princ ('lock state of ', _id, ': ', DAV_IS_LOCKED_INT (_id, _type));
    if (_auto_version_type = 'DAV:checkout-checkin' -- checkout-checkin
      or (_auto_version_type = 'DAV:checkout-unlocked-checkin'))
    {
      insert replacing WS.WS.SYS_DAV_RES_VERSION (RV_RES_ID , -- This is equal to either existing resource ID or to an attic ID
        RV_ID, -- Version ID
        RV_NODE_NAME, -- Version number string as it can be used for data export. NULL to generate automatically.
        RV_PREV_ID, -- referenced by WS.WS.SYS_DAV_VERSION (RV_ID) when NOT NULL
        RV_ACT_ID, -- referenced by WS.WS.SYS_DAV_ACTIVITY (ACT_ID) when NOT NULL
        RV_RES_TYPE, -- MIME content type as it was in WS.WS.SYS_DAV_RES.RES_TYPE, NULL if deleted in this version.
        RV_CR_TIME, -- Old creation time as it was in WS.WS.SYS_DAV_RES.RES_CR_TIME
        RV_MOD_TIME, -- Old modification time as it was in WS.WS.SYS_DAV_RES.RES_MOD_TIME
        RV_WHO,
        RV_SIZE)
      values (N.RES_ID, _ver_id, NULL, _ver_prev_id, NULL, N.RES_TYPE, dt, dt, connection_get ('HTTP_CLI_UID'), length (N.RES_CONTENT));
      --dbg_obj_print ('>', N.RES_ID, _ver_id, _ver_prev_id, N.RES_CONTENT, _diff_type, _diff);
      "Versioning_ADD_NEW_DIFF" (N.RES_ID, _ver_id, _ver_prev_id, N.RES_CONTENT, _diff_type, _diff);
    }
  }
  else if (DAV_HIDE_ERROR(DAV_PROP_GET_INT (N.RES_ID, 'R', 'DAV:checked-in', 0)) is not null)
    signal ('VR003', 'Resource can not be updated when it has been checked-in');
}
;

create function DAV_GET_VERSION_CONTENT (in res_id integer, in ver integer, inout content any, out type varchar, inout mode any)
{
  declare ver_path any;
  declare curr_ver, next_ver_copy, next_ver, prev_ver integer;
  next_ver := -1;
  -- The most popular case is retrieval of some 'key' version, e.g. the latest.
   -- dbg_obj_princ ('DAV_GET_VERSION_CONTENT (', res_id, ',', ver, ', [content], [mode])');
  for select RV_RES_TYPE, RD_DELTA, RD_MODE, RD_ARGS from WS.WS.SYS_DAV_RES_DIFF
    inner join WS.WS.SYS_DAV_RES_VERSION
  on (RV_RES_ID = RD_RES_ID and RV_ID = RD_TO_ID)
    where RD_RES_ID = res_id and RD_TO_ID = ver and RD_FROM_ID = 0 do
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
    where RD_RES_ID = res_id and RD_TO_ID = curr_ver and RD_FROM_ID = 0 do {
    -- unpack RD_DELTA
    goto key_found;
  }
  next_ver_copy := null;
  next_ver := null;
  for select RD_FROM_ID from WS.WS.SYS_DAV_RES_DIFF
    where RD_RES_ID = res_id and RD_TO_ID = curr_ver and RD_FROM_ID <> 0 do {
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
  -- dbg_obj_princ ('= ', ver_path);
  whenever not found goto report_invalid_version_number;
  declare ctr int;
  curr_ver := 0;
  for (ctr := length (ver_path)-1; ctr >= 0; ctr := ctr - 1) {
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
    else if (curr_mode = 'D')
      content := diff_apply (cast (content as varchar), cast (curr_delta as varchar), '--virt2');
      else
        signal ('VR002', 'Versioning: diff mode [' || curr_mode || '] is not supported');
      curr_ver := prev_ver;
  }
  -- put the resulting doc to \c content.
  type := (select RV_RES_TYPE from WS.WS.SYS_DAV_RES_VERSION V where V.RV_RES_ID = res_id and V.RV_ID = ver);
  return 0;
report_invalid_version_number:
  return -1;
}
;

--| restores the resource from Attic.
create function DAV_RES_RESTORE (in VVCfolder varchar, in file varchar, in auth varchar, in pwd varchar)
{
  declare _attic, _base varchar;
  declare vvc_id int;
  vvc_id := DAV_SEARCH_ID (VVCfolder, 'C');
  _attic := "Versioning_GET_ATTIC_PATH" (vvc_id);
  _base := "Versioning_GET_BASE_PATH" (vvc_id);
  if ((_attic is null) or (_base is null))
    return -36;
  declare _base_id int;
  _base_id := DAV_SEARCH_ID (_base, 'C');
  if (_base_id < 0)
    return _base_id;
  declare _res_id int;
  _res_id := DAV_SEARCH_ID (_attic || file, 'R');
  if (_res_id < 0)
    return _res_id;
  declare new_res_id int;
  declare _content any;
  declare _type, _perms varchar;
  declare _owner, _group int;
  select RES_CONTENT, RES_TYPE, RES_PERMS, RES_OWNER, RES_GROUP
    into _content, _type, _perms, _owner, _group
    from WS.WS.SYS_DAV_RES where RES_ID = _res_id;
  new_res_id := DAV_RES_UPLOAD_STRSES_INT (_base || file, _content, _type, _perms, _owner, _group, auth, pwd, 1);
  if (new_res_id > 0) {
    DAV_VERSION_CONTROL (_base || file, auth, pwd);
    delete from WS.WS.SYS_DAV_RES_VERSION where RV_RES_ID = new_res_id;
    delete from WS.WS.SYS_DAV_RES_DIFF where RD_RES_ID = new_res_id;
    update WS.WS.SYS_DAV_RES_VERSION set RV_RES_ID = new_res_id
      where RV_RES_ID = _res_id;
    update WS.WS.SYS_DAV_RES_DIFF set RD_RES_ID = new_res_id
      where RD_RES_ID = _res_id;
    delete from WS.WS.SYS_DAV_RES where RES_ID = _res_id;
    return 1;
  }
  return -1;
}
;



--| This matches DAV_AUTHENTICATE (in id any, in what char(1), in req varchar, in a_uname varchar, in a_pwd varchar, in a_uid integer := null)
--| The difference is that the DET function should not check whether the pair of name and password is valid; the auth_uid is not a null already.
create function "Versioning_DAV_AUTHENTICATE" (in id any, in what char(1), in req varchar, in auth_uname varchar, in auth_pwd varchar, in auth_uid integer)
{
   -- dbg_obj_princ ('Versioning_DAV_AUTHENTICATE (', id, what, req, auth_uname, auth_pwd, auth_uid, ')');
  if (auth_uid >= 0)
    return auth_uid;
  return -12;
}
;

--| This exactly matches DAV_AUTHENTICATE_HTTP (in id any, in what char(1), in req varchar, in can_write_http integer, inout a_lines any, inout a_uname varchar, inout a_pwd varchar, inout a_uid integer, inout a_gid integer, inout _perms varchar) returns integer
--| The function should fully check access because DAV_AUTHENTICATE_HTTP do nothing with auth data either before or after calling this DET function.
--| Unlike DAV_AUTHENTICATE, user name passed to DAV_AUTHENTICATE_HTTP header may not match real DAV user.
--| If DET call is successful, DAV_AUTHENTICATE_HTTP checks whether the user have read permission on mount point collection.
--| Thus even if DET function allows anonymous access, the whole request may fail if mountpoint is not readable by public.
create function "Versioning_DAV_AUTHENTICATE_HTTP" (in id any, in what char(1), in req varchar, in can_write_http integer, inout a_lines any, inout a_uname varchar, inout a_pwd varchar, inout a_uid integer, inout a_gid integer, inout _perms varchar) returns integer
{
  declare rc integer;
  declare puid, pgid integer;
  declare u_password, pperms varchar;
  declare allow_anon integer;
  if (length (req) <> 3)
    return -15;

  whenever not found goto nf_col_or_res;
  puid := http_dav_uid();
  pgid := coalesce (
    ( select G_ID from WS.WS.SYS_DAV_GROUP
      where G_NAME = 'Versioning_' || coalesce ((select COL_NAME from WS.WS.SYS_DAV_COL where COL_ID=id[1] and COL_DET='HostFs'), '')
      ), puid+1);
  if ((what <> 'R') and (what <> 'C'))
    return -14;
  if ('R' = what and (length(id) > 2)) {
    select RES_PERMS, RES_OWNER, RES_GROUP into pperms, puid, pgid from WS.WS.SYS_DAV_RES where RES_ID = id[2]; -- Versioning permissions are original resource permissions
  }
  else {
    pperms := '110100100NN';
  }
  allow_anon := WS.WS.PERM_COMP (substring (cast (pperms as varchar), 7, 3), req);
  if (a_uid is null) {
    if ((not allow_anon) or ('' <> WS.WS.FINDPARAM (a_lines, 'Authorization:')))
    rc := WS.WS.GET_DAV_AUTH (a_lines, allow_anon, can_write_http, a_uname, u_password, a_uid, a_gid, _perms);
    if (rc < 0)
      return rc;
  }
  if (isinteger (a_uid)) {
    if (a_uid < 0)
      return a_uid;
    if (a_uid = 1) { -- Anonymous FTP
      a_uid := 0;
      a_gid := 0;
    }
  }
  if (DAV_CHECK_PERM (pperms, req, a_uid, a_gid, pgid, puid))
    return a_uid;
  return -13;

nf_col_or_res:
  return -1;
}
;


--| This matches DAV_GET_PARENT (in id any, in st char(1), in path varchar) returns any
create function "Versioning_DAV_GET_PARENT" (in id any, in st char(1), in path varchar) returns any
{
  -- dbg_obj_princ ('Versioning_DAV_GET_PARENT (', id, st, path, ')');
  if (st = 'R' and isarray (id) and length (id) = 4)
    return subseq (id, 0, length (id) - 1);
  return -20;
}
;

--| When DAV_COL_CREATE_INT calls DET function, authentication, check for lock and check for overwrite are passed, uid and gid are translated from strings to IDs.
--| Check for overwrite, but the deletion of previously existing collection should be made by DET function.
create function "Versioning_DAV_COL_CREATE" (in detcol_id any, in path_parts any, in permissions varchar, in uid integer, in gid integer, in auth_uid integer) returns any
{
   -- dbg_obj_princ ('Versioning_DAV_COL_CREATE (', detcol_id, path_parts, permissions, uid, gid, auth_uid, ')');
  return -20;
}
;

--| It looks like that this is redundant and should be removed at all.
create function "Versioning_DAV_COL_MOUNT" (in detcol_id any, in path_parts any, in full_mount_path varchar, in mount_det varchar, in permissions varchar, in uid integer, in gid integer, in auth_uid integer) returns any
{
   -- dbg_obj_princ ('Versioning_DAV_COL_MOUNT (', detcol_id, path_parts, full_mount_path, mount_det, permissions, uid, gid, auth_uid, ')');
  return -20;
}
;

--| It looks like that this is redundant and should be removed at all.
create function "Versioning_DAV_COL_MOUNT_HERE" (in parent_id any, in full_mount_path varchar, in permissions varchar, in uid integer, in gid integer, in auth_uid integer) returns any
{
   -- dbg_obj_princ ('Versioning_DAV_COL_MOUNT_HERE (', parent_id, full_mount_path, permissions, uid, gid, auth_uid, ')');
  return -20;
}
;


--| When DAV_DELETE_INT calls DET function, authentication and check for lock are passed.
create function "Versioning_DAV_DELETE" (in detcol_id any, in path_parts any, in what char(1), in silent integer, in auth_uid integer) returns integer
{
   -- dbg_obj_princ ('Versioning_DAV_DELETE (', detcol_id, path_parts, what, silent, auth_uid, ')');
  if ('R' = what) {
    if (length (path_parts) <> 2)
      return -20;

    declare _base_path varchar;
    _base_path := "Versioning_GET_BASE_PATH" (detcol_id);
    if (_base_path is null)
      return -20;
    declare _res_id int;
    _res_id := DAV_SEARCH_ID (_base_path || path_parts[0], 'R');
    if (_res_id < 0)
      return -1;
    if (path_parts[1] = 'last') {
      -- move to Attic
      declare _attic varchar;
      _attic := "Versioning_GET_ATTIC_PATH" (detcol_id);
      if (_attic is not null) {
        declare _attic_id int;
        _attic_id := DAV_SEARCH_ID (_attic, 'C');
        if (_attic_id >= 0) {
          declare new_res_id int;
          declare _content any;
          declare _type, _perms varchar;
          declare _owner, _group int;
          select RES_CONTENT, RES_TYPE, RES_PERMS, RES_OWNER, RES_GROUP
            into _content, _type, _perms, _owner, _group
            from WS.WS.SYS_DAV_RES where RES_ID = _res_id;
          new_res_id := DAV_RES_UPLOAD_STRSES_INT (_attic || path_parts[0], _content, _type, _perms, _owner, _group, null, null, 0);
          if (new_res_id > 0) {
            delete from WS.WS.SYS_DAV_RES_VERSION where RV_RES_ID = new_res_id;
            delete from WS.WS.SYS_DAV_RES_DIFF where RD_RES_ID = new_res_id;

            update WS.WS.SYS_DAV_RES_VERSION set RV_RES_ID = new_res_id
              where RV_RES_ID = _res_id;
            update WS.WS.SYS_DAV_RES_DIFF set RD_RES_ID = new_res_id
              where RD_RES_ID = _res_id;
            delete from WS.WS.SYS_DAV_RES where RES_ID = _res_id;
          }
          return 1;
        }
      }
      delete from WS.WS.SYS_DAV_RES where RES_ID = _res_id;
    }
    else {
      declare ver_id int;
      ver_id := atoi (path_parts[1]);
      if (cast (ver_id as varchar) = path_parts[1]) { -- syntax is ok
        -- delete old version
        declare cnt int;
        cnt := coalesce ((select count (*) from WS.WS.SYS_DAV_RES_VERSION where RV_RES_ID = _res_id and RV_ID > ver_id), 0);
        if (cnt = 0) -- can not delete all versions
          return -38;
        delete from WS.WS.SYS_DAV_RES_VERSION where RV_RES_ID = _res_id
          and RV_ID <= ver_id;
        delete from WS.WS.SYS_DAV_RES_DIFF where RD_RES_ID = _res_id
          and RD_TO_ID <= ver_id;
      }
    }
    return 1;
  }
  return -20;
}
;

--| When DAV_RES_UPLOAD_STRSES_INT calls DET function, authentication and check for locks are performed before the call.
--| There's a special problem, known as 'Transaction deadlock after reading from HTTP session'.
--| The DET function should do only one INSERT of the 'content' into the table and do it as late as possible.
--| The function should return -29 if deadlocked or otherwise broken after reading blob from HTTP.
create function "Versioning_DAV_RES_UPLOAD" (in detcol_id any, in path_parts any, inout content any, in type varchar, in permissions varchar, in uid integer, in gid integer, in auth_uid integer) returns any
{
   -- dbg_obj_princ ('Versioning_DAV_RES_UPLOAD (', detcol_id, path_parts, ', [content], ',  type, permissions, uid, gid, auth_uid, ')');
  return -20;
}
;


--| When DAV_PROP_REMOVE_INT calls DET function, authentication and check for locks are performed before the call.
--| The check whether it's a system name or not is _not_ permitted.
create function "Versioning_DAV_PROP_REMOVE" (in id any, in what char(0), in propname varchar, in silent integer, in auth_uid integer) returns integer
{
   -- dbg_obj_princ ('Versioning_DAV_PROP_REMOVE (', id, what, propname, silent, auth_uid, ')');
  return -20;
}
;

--| When DAV_PROP_SET_INT calls DET function, authentication and check for locks are performed before the call.
--| The check whether it's a system property or not is _not_ permitted and the function should return -16 for live system properties.
create function "Versioning_DAV_PROP_SET" (in id any, in what char(0), in propname varchar, in propvalue any, in overwrite integer, in auth_uid integer) returns any
{
  -- dbg_obj_princ ('Versioning_DAV_PROP_SET (', id, what, propname, propvalue, overwrite, auth_uid, ')');
  if (propname[0] = 58) {
    return -16;
  }
  return -20;
}
;

--| When DAV_PROP_GET_INT calls DET function, authentication and check whether it's a system property are performed before the call.
create function "Versioning_DAV_PROP_GET" (in id any, in what char(0), in propname varchar, in auth_uid integer)
{
  -- dbg_obj_princ ('Versioning_DAV_PROP_GET (', id, what, propname, auth_uid, ')');
  if (isarray (id) and length (id) = 4) {
    if (id[3] = -1) { -- history.xml
      declare _hist_col, _res_name varchar;
      if (propname = 'DAV:root-version') {
        declare _root_ver int;
        _res_name := (select RES_NAME from WS.WS.SYS_DAV_RES where RES_ID = id[2]);
        _hist_col := DAV_SEARCH_PATH (id[1], 'C');
        _root_ver := (select min (RV_ID) from ws.ws.sys_dav_res_version where RV_ID > 0 and RV_RES_ID = id[2]);
        return '<D:href>' || _hist_col || _res_name || '/' || cast (_root_ver as varchar) || '</D:href>';
      }
      else if (propname = 'DAV:version-set') {
        declare _res any;
        _res := string_output ();
        _hist_col := DAV_SEARCH_PATH (id[1], 'C');
        _res_name := (select RES_NAME from WS.WS.SYS_DAV_RES where RES_ID = id[2]);
        for select RV_ID from WS.WS.SYS_DAV_RES_VERSION where RV_RES_ID = id[2] and RV_ID <> 0 order by RV_ID
        do {
          http ('<D:href>', _res);
          http (_hist_col || _res_name || '/' ||  cast (RV_ID as varchar), _res);
          http ('</D:href>', _res);
        }
        return string_output_string (_res);
      }
    }
    else {
      declare exit handler for not found {
        return -1;
      };
      declare _props any;
      if (id[3] = -2) -- last version
        select RD_PROPS into _props from WS.WS.SYS_DAV_RES_DIFF where RD_RES_ID = id[2] and RD_FROM_ID = 0;
      else if (id[3] > 0) {
        if (propname = ':creationdate') {
          declare dt datetime;
          select RV_CR_TIME into dt from WS.WS.SYS_DAV_RES_VERSION
            where RV_RES_ID = id[2] and RV_ID = id[3];
          return dt;
        }
        else
          select RD_PROPS into _props from WS.WS.SYS_DAV_RES_DIFF
            where RD_RES_ID = id[2] and RD_TO_ID = id[3];
      }
      -- dbg_obj_princ ('props: ', _props);
      if (_props is not null)
        return coalesce (xpath_eval ('//property[@name="' || propname || '"]/text()', _props), -11);
    }
  }
  return -11;
}
;

create function "Versioning_root_version" (in _res_id int, in _hist_col varchar)
{
  declare ss any;
  ss := string_output();
  http ('<D:root-version><D:href>' || _hist_col, ss);
  http_value( (select min (RV_ID) from ws.ws.sys_dav_res_version where RV_ID > 0
      and RV_RES_ID = _res_id), NULL, ss);
  http ('</D:href></D:root-version>', ss);
  --dbg_obj_print (string_output_string(ss));
  return string_output_string (ss);
}
;

create function "Versioning_version_set" (in _res_id int, in _hist_col varchar)
{
  declare ss any;
  ss := string_output ();
  http ('<D:version-set>', ss);
  for select RV_ID, RES_NAME from WS.WS.SYS_DAV_RES_VERSION inner join WS.WS.SYS_DAV_RES
    on (RV_RES_ID = RES_ID)
    where RES_ID = _res_id
  do {
    http ('<D:href>', ss);
    http (_hist_col || RES_NAME || '/' ||  cast (RV_ID as varchar), ss);
    http ('</D:href>', ss);
  }
  http ('</D:version-set>',ss);
  return string_output_string (ss);
}
;

--| When DAV_PROP_LIST_INT calls DET function, authentication is performed before the call.
--| The returned list should contain only user properties.
create function "Versioning_DAV_PROP_LIST" (in id any, in what char(0), in propmask varchar, in auth_uid integer)
{
  -- dbg_obj_princ ('Versioning_DAV_PROP_LIST (', id, what, propmask, auth_uid, ')');
  if (isarray (id) and length (id) = 4 and id[3] = -1) {
    declare _hist_col varchar;
    _hist_col := DAV_SEARCH_PATH (id[1], 'C');
    return vector (
      vector ('DAV:version-set', "Versioning_version_set" (id[2], _hist_col)),
      vector ('DAV:root-version', "Versioning_root_version" (id[2], _hist_col)));
  }
  return vector ();
}
;

--| When DAV_PROP_GET_INT or DAV_DIR_LIST_INT calls DET function, authentication is performed before the call.
create function "Versioning_DAV_DIR_SINGLE" (in id any, in what char(0), in path any, in auth_uid integer) returns any
{
  -- dbg_obj_princ ('Versioning_DAV_DIR_SINGLE (', id, what, path, auth_uid, ')');
  if (what = 'C') {
    if (isarray (id) and length (id) = 3) {
      declare _res_name, _col_path varchar;
      declare dirlist any;
      _res_name := (select RES_NAME from WS.WS.SYS_DAV_RES where RES_ID = id[2]);
      _col_path := DAV_SEARCH_PATH (id[1], 'C') || _res_name || '/';
      for select RES_MOD_TIME, RES_PERMS, RES_GROUP, RES_OWNER, RES_CR_TIME, RES_NAME
        from WS.WS.SYS_DAV_RES where RES_ID = id[2]
      do {
        return
--        0          1  2    3
          vector (_col_path,        'C',  0,    RES_MOD_TIME,
--              4
            vector (UNAME'Versioning', id[1], id[2]),
--        5          6          7          8            9             10
            RES_PERMS, RES_GROUP, RES_OWNER, RES_CR_TIME,    'dav/unix-directory', RES_NAME);
      }
    }
  }
  else if (what = 'R') {
    if (not isarray(id))
      return -20;
    if (length (id) = 4 and isinteger(id[3]) and id[3] > 0) {
      declare res any;
      for select RV_ID, RES_NAME, RES_FULL_PATH, RV_SIZE as l,
        RES_PERMS, RV_CR_TIME, RV_MOD_TIME, RES_GROUP, RES_OWNER,
        RV_RES_TYPE, cast (RV_ID as VARCHAR) as ver_id
        from WS.WS.SYS_DAV_RES INNER JOIN WS.WS.SYS_DAV_RES_VERSION ON (RV_RES_ID = RES_ID)
        where RES_ID = id[2] and RV_ID = id[3]
      do {
        return vector (
--    0
          DAV_SEARCH_PATH (id[1], 'C') || RES_NAME || '/' || ver_id,
--    1     2    3    4
          'R',    l,    RV_CR_TIME,  vector (UNAME'Versioning', id[1], id[2], RV_ID),
--    5    6    7    8
          RES_PERMS,  RES_GROUP,  RES_OWNER,  RV_MOD_TIME,
--    9    10
          RV_RES_TYPE,  ver_id);
      }
    }
    if (length (id) = 4) { -- last, history.xml, diff
      if (isinteger (id[3]) and id[3] < 0) {
        declare _target varchar;
        declare _res_name, _type, _perms varchar;
        declare _cr_time, _mod_time datetime;
        declare _owner, _group int;
        select RES_NAME, RES_TYPE, RES_PERMS, RES_CR_TIME, RES_MOD_TIME, RES_OWNER, RES_GROUP
          into _res_name, _type, _perms, _cr_time, _mod_time, _owner, _group
          from WS.WS.SYS_DAV_RES where RES_ID = id[2];
        if (id[3] = -1) -- history.xml
          _target := 'history.xml';
        else if (id[3] = -2) -- last
          _target := 'last';
        else
          return -20;
        return vector (
    --    0
        DAV_SEARCH_PATH (id[1], 'C') || _res_name || '/' || _target,
    --    1     2    3    4
        'R',    1000,    _cr_time,  id,
    --    5    6    7    8
        _perms,  _group,    _owner,    _mod_time,
    --    9    10
        _type,    _target);
      }
    }
    else if (length(id) = 5 and isstring(id[4]) and id[4] = 'diff') {
      declare res any;
      for select RV_ID, RES_NAME, RES_FULL_PATH, RV_SIZE as l,
        RES_PERMS, RV_CR_TIME, RV_MOD_TIME, RES_GROUP, RES_OWNER,
        RV_RES_TYPE, cast (RV_ID as VARCHAR) as ver_id
        from WS.WS.SYS_DAV_RES INNER JOIN WS.WS.SYS_DAV_RES_VERSION
        ON (RV_RES_ID = RES_ID) inner join WS.WS.SYS_DAV_RES_DIFF
        on (RD_RES_ID = RES_ID)
        where RES_ID = id[2]
          and RV_ID = id[3]
      do {
        return vector (
--    0
          DAV_SEARCH_PATH (id[1], 'C') || RES_NAME || '/' || ver_id,
--    1     2    3    4
          'R',    l,    RV_CR_TIME,  vector (UNAME'Versioning', id[1], id[2], RV_ID),
--    5    6    7    8
            RES_PERMS,  RES_GROUP,  RES_OWNER,  RV_MOD_TIME,
--    9    10
            RV_RES_TYPE,  ver_id);
      }
  -- signal ('xxxx', 'dfdf');
    }
  }
  --dbg_obj_princ ('dir single: ', -20);
  return -20;
}
;

create function "Versioning_GET_BASE_PATH" (in detcol_id int)
{
  return (select PROP_VALUE from WS.WS.SYS_DAV_PROP where PROP_NAME = 'virt:Versioning-Collection' and PROP_PARENT_ID = detcol_id and PROP_TYPE = 'C');
}
;

create function "Versioning_GET_ATTIC_PATH" (in detcol_id int)
{
  return (select PROP_VALUE from WS.WS.SYS_DAV_PROP where PROP_NAME = 'virt:Versioning-Attic' and PROP_PARENT_ID = detcol_id and PROP_TYPE = 'C');
}
;



create function "Versioning_SET_LIST" (in detcol_id int, in _res_id int, in virt_base_path varchar, inout res any)
{
  declare max_ver int;
  max_ver := 0;
  for select RV_ID, RES_NAME, RES_FULL_PATH, RV_SIZE as l,
    RES_PERMS, RV_CR_TIME, RV_MOD_TIME, RES_GROUP, RES_OWNER,
    RV_RES_TYPE, cast (RV_ID as VARCHAR) as ver_id
    from WS.WS.SYS_DAV_RES INNER JOIN WS.WS.SYS_DAV_RES_VERSION ON (RV_RES_ID = RES_ID)
    where RES_ID = _res_id
    order by ver_id
  do {
    vectorbld_acc (res, vector (
--    0
      virt_base_path || RES_NAME || '/' || ver_id,
--    1     2    3    4
      'R',    l,    RV_CR_TIME,  vector (UNAME'Versioning', detcol_id, _res_id, RV_ID),
--    5    6    7    8
      RES_PERMS,  RES_GROUP,  RES_OWNER,  RV_MOD_TIME,
--    9    10
      RV_RES_TYPE,  ver_id ) );
    -- diff
      vectorbld_acc (res, vector (
--    0
      virt_base_path || RES_NAME || '/' || ver_id || '.diff',
--    1     2    3    4
      'R',    l,    RV_CR_TIME,  vector (UNAME'Versioning', detcol_id, _res_id, RV_ID, 'diff'),
--    5    6    7    8
      RES_PERMS,  RES_GROUP,  RES_OWNER,  RV_MOD_TIME,
--    9    10
      RV_RES_TYPE,  ver_id || '.diff' ) );
    max_ver := case when max_ver > ver_id then max_ver else ver_id end;
  }
  return max_ver;
}
;



--| When DAV_PROP_GET_INT or DAV_DIR_LIST_INT calls DET function, authentication is performed before the call.
create function "Versioning_DAV_DIR_LIST" (in detcol_id any, in path_parts any, in detcol_path varchar, in name_mask varchar, in recursive integer, in auth_uid integer) returns any
{
  declare base_path, virt_base_path varchar;
  base_path := "Versioning_GET_BASE_PATH" (detcol_id);
  if (base_path is null)
    return -20;
  virt_base_path := DAV_SEARCH_PATH (detcol_id, 'C');
  --dbg_obj_princ ('Versioning_DAV_DIR_LIST (', detcol_id, path_parts, detcol_path, name_mask, recursive, auth_uid, ')');
  declare res any;
  vectorbld_init (res);
  if (length (path_parts) = 1) {
    for select RES_ID, RES_NAME, RES_CONTENT, RES_FULL_PATH, RES_PERMS, RES_OWNER, RES_MOD_TIME, RES_TYPE, RES_GROUP, RES_CR_TIME
      from WS.WS.SYS_DAV_RES, WS.WS.SYS_DAV_PROP
      where RES_COL = DAV_SEARCH_ID (base_path, 'C')
        and PROP_PARENT_ID = RES_ID
        and (PROP_NAME = 'DAV:checked-in' or PROP_NAME = 'DAV:checked-out')
    do {
      vectorbld_acc (res, vector (virt_base_path || RES_NAME || '/', 'C', 0, RES_CR_TIME,
--       4
        vector (UNAME'Versioning', cast (detcol_id as integer), RES_ID),
--       5              6               7               8               9
        RES_PERMS,     RES_GROUP,      RES_OWNER,      RES_MOD_TIME,   'dav/unix-directory',
--       10
        RES_NAME ) );
    }
  }
  else if (length (path_parts) = 2) {
    declare _res_id int;
    _res_id := DAV_SEARCH_ID (base_path || aref (path_parts, 0), 'R');
    if (_res_id < 0)
      return -1;
    declare _res_name, _res_perms, _rv_res_type varchar;
    declare _rv_mod_time, _rv_cr_time datetime;
    declare _len, _res_group, _res_owner int;
    _res_name := null;

    declare _max_ver int;
    _max_ver := "Versioning_SET_LIST" (detcol_id, _res_id, virt_base_path, res);

     select RES_NAME, RES_PERMS, RES_GROUP, RES_OWNER, RV_RES_TYPE, RV_MOD_TIME, RV_CR_TIME, RV_SIZE
       into _res_name,
       _res_perms,
       _res_group,
       _res_owner,
       _rv_res_type,
       _rv_mod_time,
       _rv_cr_time,
       _len
       from WS.WS.SYS_DAV_RES inner join WS.WS.SYS_DAV_RES_VERSION on (RV_RES_ID = RES_ID)
       where RES_ID = _res_id and RV_ID = _max_ver;

     -- history.xml
     declare _owner, _group int;
     declare _name varchar;
     select RES_GROUP, RES_OWNER, RES_NAME into _group, _owner, _name from WS.WS.SYS_DAV_RES
       where RES_ID = _res_id;
     vectorbld_acc (res, vector (
--    0
       virt_base_path || _name || '/history.xml',
--    1     2    3    4
       'R',    1000,    now(),    vector (UNAME'Versioning', detcol_id, _res_id, -1),
--    5    6    7    8
       '100100100NN',  _group,    _owner,  now(),
--    9    10
       'plain/xml',  'history.xml' ) );
       -- "last"
     if (_res_name is not null)
       vectorbld_acc (res, vector (
--    0
         virt_base_path || _res_name || '/last',
--    1     2    3    4
         'R',    _len,    _rv_cr_time,  vector (UNAME'Versioning', detcol_id, _res_id, -2),
--    5    6    7    8
         _res_perms,  _res_group,  _res_owner,  _rv_mod_time,
--    9    10
         _rv_res_type,  'last' ) );
  }
  vectorbld_final (res);
  -- dbg_obj_princ ('res: ', res);
  return res;
}
;

--| When DAV_DIR_FILTER_INT calls DET function, authentication is performed before the call and compilation is initialized.
create function "Versioning_DAV_DIR_FILTER" (in detcol_id any, in path_parts any, in detcol_path varchar, inout compilation any, in recursive integer, in auth_uid integer) returns any
{
   -- dbg_obj_princ ('Versioning_DAV_DIR_FILTER (', detcol_id, path_parts, detcol_path, compilation, recursive, auth_uid, ')');
  return vector();
}
;

--| When DAV_PROP_GET_INT or DAV_DIR_LIST_INT calls DET function, authentication is performed before the call.
create function "Versioning_DAV_SEARCH_ID" (in detcol_id any, in path_parts any, in what char(1)) returns any
{
  declare base_path varchar;
  base_path := "Versioning_GET_BASE_PATH" (detcol_id);
  if (base_path is null)
    return -20;
   -- dbg_obj_princ ('Versioning_DAV_SEARCH_ID (', detcol_id, path_parts, what, ')');
  if ('C' = what) {
    if ( (length (path_parts) = 3) )
      return -1;
    declare base_id int;
    base_id := DAV_SEARCH_ID (base_path, 'C');
    if (base_id > 0) {
      declare _res_id int;
      _res_id :=  (select RES_ID from WS.WS.SYS_DAV_RES where RES_COL = base_id
          and RES_NAME = aref (path_parts, 0) );
       -- dbg_obj_princ ('Versioning_DAV_SEARCH_ID = ', _res_id);
      if (_res_id is not null) {
        if (DAV_HIDE_ERROR (DAV_PROP_GET_INT (_res_id, 'R', 'DAV:checked-in', 0)) is null
          and DAV_HIDE_ERROR (DAV_PROP_GET_INT (_res_id, 'R', 'DAV:checked-out', 0)) is null)
          return -1;
        return vector (UNAME'Versioning', cast (detcol_id as integer), _res_id);
      }
    }
    return -1;
  }
  else if ('R' = what) {
    if (length (path_parts) = 2) {
      declare _res_id, _ver_id, _id int;
      _res_id := DAV_SEARCH_ID (base_path || path_parts[0], 'R');
       -- dbg_obj_princ ('res id == ', _res_id);
      if (_res_id < 0)
        return -1;
      if (DAV_HIDE_ERROR (DAV_PROP_GET_INT (_res_id, 'R', 'DAV:checked-in', 0)) is null
            and DAV_HIDE_ERROR (DAV_PROP_GET_INT (_res_id, 'R', 'DAV:checked-out', 0)) is null)
        return -1;
      if (path_parts[1] = 'history.xml')
        _ver_id := -1;
      else if (path_parts[1] = 'last')
        _ver_id := -2;
      else if (path_parts[1] like '%.diff') {
        _ver_id := atoi (path_parts[1]);
        return vector (UNAME'Versioning', detcol_id, _res_id, _ver_id, 'diff');
      }
      else {
        _ver_id := cast (path_parts[1] as integer);
        if (not exists (select 1 from WS.WS.SYS_DAV_RES_VERSION where RV_RES_ID = _res_id and RV_ID = _ver_id))
          return -1;
      }
      return vector (UNAME'Versioning', detcol_id, _res_id, _ver_id);
    }
    return -1;
  }
  else
    return -1;
}
;

--| When DAV_SEARCH_PATH_INT calls DET function, authentication is performed before the call.
create function "Versioning_DAV_SEARCH_PATH" (in id any, in what char(1)) returns any
{
  -- dbg_obj_princ ('Versioning_DAV_SEARCH_PATH (', id, what, ')');
  if (what = 'C' and isarray (id) and length (id) = 3) {
    declare base_coll varchar;
    base_coll := DAV_PROP_GET_INT (id[1], 'C','virt:Versioning-Collection', 0);
    if (isinteger (base_coll))
      return -1;
    return base_coll || (select RES_NAME from WS.WS.SYS_DAV_RES where RES_ID = id[2]) || '/';
  }
  return -1;
}
;

--| When DAV_COPY_INT calls DET function, authentication and check for locks are performed before the call, but no check for existing/overwrite.
create function "Versioning_DAV_RES_UPLOAD_COPY" (
  in detcol_id any,
  in path_parts any,
  in source_id any,
  in what char(1),
  in overwrite_flags integer,
  in permissions varchar,
  in uid integer,
  in gid integer,
  in auth_uid integer,
  in auth_uname varchar := null,
  in auth_pwd varchar := null,
  in extern integer := 1,
  in check_locks any := 1) returns any
{
   -- dbg_obj_princ ('Versioning_DAV_RES_UPLOAD_COPY (', detcol_id, path_parts, source_id, what, overwrite_flags, permissions, uid, gid, auth_uid, ')');
  return -20;
}
;

--| When DAV_COPY_INT calls DET function, authentication and check for locks are performed before the call, but no check for existing/overwrite.
create function "Versioning_DAV_RES_UPLOAD_MOVE" (
  in detcol_id any,
  in path_parts any,
  in source_id any,
  in what char(1),
  in overwrite_flags integer,
  in auth_uid integer,
  in auth_uname varchar := null,
  in auth_pwd varchar := null,
  in extern integer := 1,
  in check_locks any := 1) returns any
{
  -- dbg_obj_princ ('Versioning_DAV_RES_UPLOAD_MOVE (', detcol_id, path_parts, source_id, what, overwrite_flags, auth_uid, ')');
  if (not isarray (source_id))
    return -20;
  if (source_id[0] <> UNAME'Versioning')
    return -20;
  if (source_id[3] <> -2)
    return -20;
  if (what <> 'R')
    return -20;
  declare _target_col varchar;
  _target_col := (select PROP_VALUE from WS.WS.SYS_DAV_PROP where
    PROP_NAME = 'virt:Versioning-Collection' and PROP_PARENT_ID = detcol_id);
  if (_target_col is null)
    return -1;
  declare _old_res_id, _target_col_id int;
  _target_col_id := DAV_SEARCH_ID (_target_col, 'C');
  if (_target_col_id > 0) {
    -- dbg_obj_princ ('tgt col: ', _target_col_id);
    _old_res_id := DAV_SEARCH_ID (_target_col || path_parts[0], 'R');
    if (_old_res_id > 0) {
      -- dbg_obj_princ ('res id: ', _old_res_id);
      delete from WS.WS.SYS_DAV_RES_VERSION where RV_RES_ID = _old_res_id;
      delete from WS.WS.SYS_DAV_RES_DIFF where RD_RES_ID = _old_res_id;
      delete from WS.WS.SYS_DAV_RES where RES_ID = _old_res_id;
    }
    declare _t_path varchar;
    declare _res_id int;
    _res_id := source_id[2];
    _t_path := DAV_SEARCH_PATH (_target_col_id, 'C');
    declare new_res_id int;
    declare _content any;
    declare _type, _perms varchar;
    declare _owner, _group int;
    select RES_CONTENT, RES_TYPE, RES_PERMS, RES_OWNER, RES_GROUP
      into _content, _type, _perms, _owner, _group
      from WS.WS.SYS_DAV_RES where RES_ID = _res_id;
    new_res_id := DAV_RES_UPLOAD_STRSES_INT (
      _t_path || path_parts[0],
      _content,
      _type,
      _perms,
      _owner,
      _group,
      null,
      null,
      0);
    if (new_res_id < 0)
      return new_res_id;
    delete from WS.WS.SYS_DAV_RES_VERSION where RV_RES_ID = new_res_id;
    delete from WS.WS.SYS_DAV_RES_DIFF where RD_RES_ID = new_res_id;
    update WS.WS.SYS_DAV_RES_VERSION set RV_RES_ID = new_res_id
      where RV_RES_ID = _res_id;
    update WS.WS.SYS_DAV_RES_DIFF set RD_RES_ID = new_res_id
      where RD_RES_ID = _res_id;
    update WS.WS.SYS_DAV_PROP
      set PROP_PARENT_ID = new_res_id
      where PROP_PARENT_ID = _res_id
      and PROP_NAME not in ('DAV:author', 'DAV:auto-version', 'DAV:checked-in', 'DAV:version-history', 'DAV:checked-out');
    delete from WS.WS.SYS_DAV_RES where RES_ID = _res_id;
  }
  return 1;
}
;

--| When DAV_RES_CONTENT or DAV_RES_COPY_INT or DAV_RES_MOVE_INT calls DET function, authentication is made.
--| If content_mode is 1 then content is a valid output stream before the call.
create function "Versioning_DAV_RES_CONTENT" (in id any, inout content any, out type varchar, in content_mode integer) returns integer
{
   -- dbg_obj_princ ('Versioning_DAV_RES_CONTENT (', id, ', [content], [type], ', content_mode, ')');
  declare _res int;
  if (aref (id, 3) = -1) { -- history
    declare _xml any;
    _xml := ( select XMLELEMENT ('history',
      XMLAGG ( XMLELEMENT ('version',
        XMLATTRIBUTES (RV_ID as "Number",
          RV_MOD_TIME as "ModDate",
          RES_NAME as "Name",
          coalesce (RV_WHO,'Unknown') as "Who") ) ) )
      from WS.WS.SYS_DAV_RES_VERSION inner join WS.WS.SYS_DAV_RES
        on (RV_RES_ID = RES_ID)
        inner join DB.DBA.SYS_USERS
        on (RES_OWNER = U_ID)
      where RES_ID = aref (id, 2));
    content := serialize_to_UTF8_xml(_xml);
    type := 'plain/xml';
    return 1;
  }
  else if (aref (id, 3) = -2) { -- "last" version
    select RD_DELTA, RES_TYPE into content, type from WS.WS.SYS_DAV_RES_DIFF inner join
      WS.WS.SYS_DAV_RES on (RD_RES_ID = RES_ID)
      where RD_RES_ID = aref (id, 2)
      and RD_FROM_ID = 0; -- last version
    return 1;
  }
  else if (length (id) = 5) {
    if (id[4] <> 'diff')
      return -1;
    content := (select RD_DELTA from WS.WS.SYS_DAV_RES_DIFF where
      RD_RES_ID = id[2]
      and RD_TO_ID = id[3]);
        type := 'application/gdiff';
        if (_res is not null)
    return 1;
  }
  else {
    _res := DAV_GET_VERSION_CONTENT (aref (id, 2), aref (id, 3), content, type, content_mode);
    if (_res >= 0)
      return 1;
  }
  return -1;
}
;

--| This adds an extra access path to the existing resource or collection.
create function "Versioning_DAV_SYMLINK" (in detcol_id any, in path_parts any, in source_id any, in what char(1), in overwrite integer, in uid integer, in gid integer, in auth_uid integer) returns any
{
   -- dbg_obj_princ ('Versioning_DAV_SYMLINK (', detcol_id, path_parts, source_id, overwrite, uid, gid, auth_uid, ')');
  return -20;
}
;

--| This gets a list of resources and/or collections as it is returned by DAV_DIR_LIST and and writes the list of quads (old_id, 'what', old_full_path, dereferenced_id, dereferenced_full_path).
create function "Versioning_DAV_DEREFERENCE_LIST" (in detcol_id any, inout report_array any) returns any
{
   -- dbg_obj_princ ('Versioning_DAV_DEREFERENCE_LIST (', detcol_id, report_array, ')');
  return -20;
}
;

--| This gets one of reference quads returned by ..._DAV_REREFERENCE_LIST() and returns a record (new_full_path, new_dereferenced_full_path, name_may_vary).
create function "Versioning_DAV_RESOLVE_PATH" (in detcol_id any, inout reference_item any, inout old_base varchar, inout new_base varchar) returns any
{
   -- dbg_obj_princ ('Versioning_DAV_RESOLVE_PATH (', detcol_id, reference_item, old_base, new_base, ')');
  return -20;
}
;

--| There's no API function to lock for a while (do we need such?) The "LOCK" DAV method checks that all parameters are valid but does not check for existing locks.
create function "Versioning_DAV_LOCK" (in path any, in id any, in type char(1), inout locktype varchar, inout scope varchar, in token varchar, inout owner_name varchar, inout owned_tokens varchar, in depth varchar, in timeout_sec integer, in auth_uid integer) returns any
{
   -- dbg_obj_princ ('Versioning_DAV_LOCK (', path, id, type, locktype, scope, token, owner_name, owned_tokens, depth, timeout_sec, auth_uid, ')');
  return -20;
}
;


--| There's no API function to unlock for a while (do we need such?) The "UNLOCK" DAV method checks that all parameters are valid but does not check for existing locks.
create function "Versioning_DAV_UNLOCK" (in id any, in type char(1), in token varchar, in auth_uid integer)
{
   -- dbg_obj_princ ('Versioning_DAV_UNLOCK (', id, type, token, auth_uid, ')');
  return -27;
}
;

--| The caller does not check if id is valid.
--| This returns -1 if id is not valid, 0 if all existing locks are listed in owned_tokens whitespace-delimited list, 1 for soft 2 for hard lock.
create function "Versioning_DAV_IS_LOCKED" (inout id any, inout type char(1), in owned_tokens varchar) returns integer
{
   -- dbg_obj_princ ('Versioning_DAV_IS_LOCKED (', id, type, owned_tokens, ')');
  return 0;
}
;


--| The caller does not check if id is valid.
--| This returns -1 if id is not valid, list of tuples (LOCK_TYPE, LOCK_SCOPE, LOCK_TOKEN, LOCK_TIMEOUT, LOCK_OWNER, LOCK_OWNER_INFO) otherwise.
create function "Versioning_DAV_LIST_LOCKS" (in id any, in type char(1), in recursive integer) returns any
{
   -- dbg_obj_princ ('Versioning_DAV_LIST_LOCKS" (', id, type, recursive);
  return vector ();
}
;

create function "Versioning_AUTO_VERSION_PROP" (in _auto_version varchar)
{
  if (_auto_version = 'A')
    return 'DAV:checkout-checkin';
  if (_auto_version = 'B')
    return 'DAV:checkout-unlocked-checkin';
  if (_auto_version = 'C')
    return 'DAV:checkout';
  if (_auto_version = 'D')
    return 'DAV:locked-checkout';
  if (_auto_version is null)
    return null;
  return -1;
}
;


--| internal API: set properties
create procedure DAV_SET_VERSIONING_PROPERTIES (in path varchar, in props any)
{
  declare idx, res int;
  for (idx := 0; idx < length (props) / 2; idx := idx + 1) {
    -- dbg_obj_princ ('set prop: ', props[idx*2], ' to: ', props[2*idx + 1]);
    res := DAV_PROP_SET_INT (path,
           props[2*idx],
           props[2*idx + 1], NULL, NULL, 0, 1, 1);
    --dbg_obj_print ('res=', res);
    if (res < 0)
    return res;
  }
  return 1;
}
;

create procedure "Versioning_REMOVE_V_PROPERTIES" (in _path varchar)
{
  connection_set ('Versioning REM PROP', 1);
  DAV_PROP_REMOVE_INT (_PATH, 'DAV:author', null, null, 0);
  DAV_PROP_REMOVE_INT (_PATH, 'DAV:version-history', null, null, 0);
  DAV_PROP_REMOVE_INT (_PATH, 'DAV:checked-in', null, null, 0);
  DAV_PROP_REMOVE_INT (_PATH, 'DAV:auto-version', null, null, 0);
  connection_set ('Versioning REM PROP', NULL);
}
;

--| API: remove the collection from version control
create function DAV_REMOVE_VERSIONING_CONTROL_INT (in _main varchar, in _auth varchar, in _pwd varchar) returns integer
{
  declare _vvc any;
  _vvc := DAV_PROP_GET (_main, 'virt:Versioning-History', 'dav', 'dav');
  if (DAV_HIDE_ERROR (_vvc) is null)
    return _vvc;
  declare _col_id int;
  _col_id := DAV_SEARCH_ID (_main, 'C');
  update WS.WS.SYS_DAV_COL set COL_AUTO_VERSIONING=NULL where COL_ID = DAV_SEARCH_ID (_main, 'C');
  for select RES_FULL_PATH from WS.WS.SYS_DAV_RES where RES_COL = _col_id
  do {
    "Versioning_REMOVE_V_PROPERTIES" (RES_FULL_PATH);
  }

  connection_set ('Versioning REM PROP', 1);
  DAV_PROP_REMOVE (_main, 'virt:Versioning-History', _auth, _pwd);
  DAV_PROP_REMOVE (_vvc, 'virt:Versioning-Collection', _auth, _pwd);
  DAV_PROP_REMOVE (_vvc, 'virt:Versioning-Attic', _auth, _pwd);
  connection_set ('Versioning REM PROP', NULL);
  return 1;
}
;

create function "Versioning_SETPROP" (in _resource varchar, in _propname varchar, in _value varchar,
  in _auth varchar,
  in _pwd varchar)
{
  declare res int;
  res := DAV_PROP_SET (_resource, _propname, _value, _auth, _pwd);
  if (DAV_HIDE_ERROR (res) is null) {
    if (res = -16 and (DAV_PROP_GET (_resource, _propname, _auth, _pwd) = _value))
      return _value;
  }
  return res;
}
;

--| API: set the collection under version control
create function DAV_SET_VERSIONING_CONTROL (in _main varchar, in _vvc varchar, in _auto_version varchar, in _auth varchar, in _pwd varchar)
{
  if (_vvc is null)
    _vvc := _main || 'VVC/';

  declare _auto_version_val varchar;
  _auto_version_val := "Versioning_AUTO_VERSION_PROP" (_auto_version);
  if (DAV_HIDE_ERROR (_auto_version) is null)
    return -17;
  declare _main_id, _vvc_id int;
  _main_id := DB.DBA.DAV_SEARCH_ID ( _main, 'C');
  -- dbg_obj_princ ('res=', _main_id);
  if (DAV_HIDE_ERROR (_main_id) is null)
    return _main_id;
  _vvc_id := DB.DBA.DAV_SEARCH_ID ( _vvc, 'C');
   -- dbg_obj_princ ('res=', _vvc_id);
  if (DAV_HIDE_ERROR (_vvc_id) is null)
    return _vvc_id;
  update WS.WS.SYS_DAV_COL set COL_AUTO_VERSIONING = _auto_version where COL_ID = _main_id;
  update WS.WS.SYS_DAV_COL set COL_DET = 'Versioning' where COL_ID = _vvc_id;
  declare res int;
  -- dbg_obj_princ ('set prop:', _vvc, _main, _auth, _pwd);
  res := "Versioning_SETPROP" (_vvc,
    'virt:Versioning-Collection',
    _main,
    _auth, _pwd);
  if (DAV_HIDE_ERROR (res) is null)
    goto err;
  -- dbg_obj_princ ('set prop:', _main, _vvc, _auth, _pwd);
  res := "Versioning_SETPROP" (_main,
    'virt:Versioning-History',
    _vvc,
     _auth, _pwd );
  if (DAV_HIDE_ERROR (res) is null)
    goto err;
  -- Versioning works only with non DET resource, so direct access to WS.WS.SYS_DAV_RES is used.
  for select RES_NAME, RES_FULL_PATH, U_NAME from WS.WS.SYS_DAV_RES inner join DB.DBA.SYS_USERS
         on U_ID = RES_OWNER
         where RES_COL = _main_id
  do {
    declare props_vect any;
    props_vect := vector ('DAV:checked-in',  _vvc || RES_NAME || '/last',
        'DAV:version-history', _vvc || RES_NAME || '/history.xml',
        'DAV:author', U_NAME );

    if (_auto_version_val is not null)
      props_vect := vector_concat ( props_vect,
            vector ('DAV:auto-version', _auto_version_val));
    res := DAV_SET_VERSIONING_PROPERTIES (RES_FULL_PATH,
            props_vect);
    if (DAV_HIDE_ERROR (res) is null)
      goto err;
  }
  return _vvc_id;
err:
  rollback work;
  -- dbg_obj_princ ('res=', res);
  return res;
}
;

--| MKWORKSPACE(path) creates workspace for later CHECKOUT
--| note: not working, check it later
create procedure DAV_MKWORKSPACE (in path varchar)
{
  declare _id any;
  _id := DAV_SEARCH_ID (path, 'R');
  if (DAV_HIDE_ERROR (_id) is null)
    return _id;
  if (not isinteger (_id))
    return -20;
  declare _parent int;
  declare _owner, _group int;
  declare _name, _type, _perms varchar;
  declare _res int;
  declare _owner_name, _group_name varchar;
  if (DAV_HIDE_ERROR (DAV_PROP_GET_INT (_id, 'R','DAV:workspace', 0)) is not null)
  return -3;
  select RES_COL, RES_OWNER, RES_GROUP, RES_NAME, RES_TYPE, RES_PERMS into
  _parent, _owner, _group, _name, _type, _perms
  from WS.WS.SYS_DAV_RES where RES_ID = _id;
  _owner_name := (select U_NAME from DB.DBA.SYS_USERS where U_ID = _owner);
  _group_name := (select U_NAME from DB.DBA.SYS_USERS where U_ID = _group);
  if (exists (select PROP_VALUE from WS.WS.SYS_DAV_PROP where
    PROP_NAME = 'virt:Versioning-History' and PROP_PARENT_ID = _parent)) {
    declare _parent_path, _copy_path varchar;
    _parent_path := DAV_SEARCH_PATH (_parent, 'C');
    _copy_path := _parent_path || 'workspace!/' || _name;
    if (0 > DAV_SEARCH_ID (_parent_path || 'workspace!/', 'C')) {
      -- dbg_obj_princ ('upload to ', _copy_path);
      _res := DAV_COL_CREATE_INT (_parent_path || 'workspace!/', '110000000--',
      _owner_name, _group_name,
      null, null, 1, 0, 1);
      if (_res < 0)
      return _res;
    }
    else if (0 < DAV_SEARCH_ID (_copy_path, 'R'))
      return -3;
    if (0 > (_res := DAV_PROP_SET_INT (path, 'DAV:workspace', _copy_path, NULL, NULL, 0, 0, 1)))
      return _res;
    return _copy_path;
  }
  else
    return -11;
}
;

create procedure DAV_CHECKOUT (in path varchar, in auth varchar, in pwd varchar)
{
  return DAV_CHECKOUT_INT (path, auth, pwd);
}
;

create procedure DAV_CHECKOUT_INT (in path_or_id any, in auth varchar, in pwd varchar, in extern int := 0)
{
  declare _id int;
  declare _checked_in varchar;
  declare path varchar;
  if (isstring (path_or_id)) {
    path := path_or_id;
    _id := DAV_SEARCH_ID (path, 'R');
    if (_id < 0)
    return _id;
  }
  else if (isinteger (path_or_id)) {
    _id := path_or_id;
    path := DAV_SEARCH_PATH (_id, 'R');
    if (DAV_HIDE_ERROR (path) is null)
    return path;
  }
  -- dbg_obj_princ ('DAV_CHECKOUT_INT ', path);
  if (DAV_HIDE_ERROR (_id) is null)
    return _id;
  if (extern and (DAV_HIDE_ERROR (DAV_AUTHENTICATE (_id, 'R', '_1_', auth, pwd)) is null))
    return -13;
  if (not isinteger (_id))
    return -20;
  _checked_in := DAV_PROP_GET_INT (_id, 'R', 'DAV:checked-in', 0);
  -- dbg_obj_princ ('DAV:checked-in: ', _checked_in);
  if (DAV_HIDE_ERROR (_checked_in) is null)
    return -1;
  if (DAV_HIDE_ERROR (DAV_PROP_GET_INT (_id, 'R', 'DAV:checked-out', 0)) is not null)
    return -11;

  declare _owner, _group int;
  declare _name, _type, _perms varchar;
  declare _rc int;
  declare _owner_name, _group_name varchar;
  select RES_OWNER, RES_GROUP, RES_NAME, RES_TYPE, RES_PERMS into
  _owner, _group, _name, _type, _perms
  from WS.WS.SYS_DAV_RES where RES_ID = _id;
   _rc := DAV_PROP_SET_INT (path, 'DAV:checked-out', _checked_in, NULL, NULL, 0, 0, 1);
  if (DAV_HIDE_ERROR (_rc) is null)
    return _rc;
  connection_set ('Versioning REM PROP', 1);
  DAV_PROP_REMOVE_INT (path, 'DAV:checked-in', null, null, 0, 0);
  connection_set ('Versioning REM PROP', NULL);
  return _id;
}
;

create procedure DAV_CHECKIN (in path varchar, in auth varchar, in pwd varchar)
{
  return DAV_CHECKIN_INT (path, auth, pwd);
}
;

create procedure DAV_CHECKIN_INT (in path varchar, in auth varchar, in pwd varchar, in extern int:=1)
{
  -- dbg_obj_princ ('DAV_CHECKIN: ', path);
  declare _id int;
  declare _checked_out varchar;
  if (auth is null)
    auth := connection_get ('HTTP_CLI_UID');
  _id := DAV_SEARCH_ID (path, 'R');
  if (DAV_HIDE_ERROR (_id) is null)
    return _id;

  if (extern and (DAV_HIDE_ERROR (DAV_AUTHENTICATE (_id, 'R', '_1_', auth, pwd)) is null))
    return -13;

  if (not isinteger (_id))
    return -20;
  _checked_out := DAV_PROP_GET_INT (_id, 'R', 'DAV:checked-out', 0);
  if (DAV_HIDE_ERROR (_checked_out) is null)
    return -38;
  if (DAV_HIDE_ERROR (DAV_PROP_GET_INT (_id, 'R', 'DAV:checked-in', 0)) is not null)
    return -11;

  declare _content any;
  declare _type varchar;
  declare _rc int;

  select RES_CONTENT, RES_TYPE into _content, _type from WS.WS.SYS_DAV_RES where RES_ID = _id;

  declare dt datetime;
  dt := now();

  declare _ver_id, _ver_next_id int;
  _ver_id := (select max (RV_ID) from WS.WS.SYS_DAV_RES_VERSION where
    RV_RES_ID = _id);
  if (_ver_id is null) {
    insert into WS.WS.SYS_DAV_RES_VERSION (RV_RES_ID , -- This is equal to either existing resource ID or to an attic ID
      RV_ID, -- Version ID
      RV_NODE_NAME, -- Version number string as it can be used for data export. NULL to generate automatically.
      RV_PREV_ID, -- referenced by WS.WS.SYS_DAV_VERSION (RV_ID) when NOT NULL
      RV_ACT_ID, -- referenced by WS.WS.SYS_DAV_ACTIVITY (ACT_ID) when NOT NULL
      RV_RES_TYPE, -- MIME content type as it was in WS.WS.SYS_DAV_RES.RES_TYPE, NULL if deleted in this version.
      RV_CR_TIME, -- Old creation time as it was in WS.WS.SYS_DAV_RES.RES_CR_TIME
      RV_MOD_TIME, -- Old modification time as it was in WS.WS.SYS_DAV_RES.RES_MOD_TIME
      RV_WHO,
      RV_SIZE)
    values (_id, 1,
      NULL, NULL, NULL, _type, dt, dt, auth, length (_content));
        "Versioning_ADD_NEW_DIFF" (_id, NULL, NULL, _content, 'c');
  }
  else {
    declare _old_content any;
    select RD_DELTA into _old_content from WS.WS.SYS_DAV_RES_DIFF
      where RD_FROM_ID = 0 and RD_RES_ID = _id;

    declare _diff, _diff_type varchar;
    if (_type like 'text/%') {
      whenever sqlstate 'DF*' goto full_copy;
      whenever sqlstate '22*' goto full_copy;
      _diff := diff (_content, _old_content, '--normal');
      _diff_type := 'D';
    }
    else {
full_copy:
      -- dbg_obj_princ ('SQL ERR: ', __SQL_STATE, __SQL_MESSAGE);
      _diff := NULL;
      _diff_type := 'c';
    }
    _ver_next_id := _ver_id + 1;
    insert into WS.WS.SYS_DAV_RES_VERSION (RV_RES_ID , -- This is equal to either existing resource ID or to an attic ID
      RV_ID, -- Version ID
      RV_NODE_NAME, -- Version number string as it can be used for data export. NULL to generate automatically.
      RV_PREV_ID, -- referenced by WS.WS.SYS_DAV_VERSION (RV_ID) when NOT NULL
      RV_ACT_ID, -- referenced by WS.WS.SYS_DAV_ACTIVITY (ACT_ID) when NOT NULL
      RV_RES_TYPE, -- MIME content type as it was in WS.WS.SYS_DAV_RES.RES_TYPE, NULL if deleted in this version.
      RV_CR_TIME, -- Old creation time as it was in WS.WS.SYS_DAV_RES.RES_CR_TIME
      RV_MOD_TIME, -- Old modification time as it was in WS.WS.SYS_DAV_RES.RES_MOD_TIME
      RV_WHO,
      RV_SIZE)
    values (_id, _ver_next_id,
      NULL, _ver_id, NULL, _type, dt, dt, auth, length (_content));
     "Versioning_ADD_NEW_DIFF" (_id, _ver_next_id, _ver_id, _content, _diff_type, _diff);
  }
  _rc := DAV_PROP_SET_INT (path, 'DAV:checked-in', _checked_out, NULL, NULL, 0, 0, 1);
  if (DAV_HIDE_ERROR (_rc) is null)
    return _rc;
  connection_set ('Versioning REM PROP', 1);
  DAV_PROP_REMOVE_INT (path, 'DAV:checked-out', null, null, 0, 0);
  connection_set ('Versioning REM PROP', NULL);
  return _id;
nf:
  -- dbg_obj_princ ('DAV_CHECKIN: not found');
  return -1;
}
;

create procedure "Versioning_CHECKOUT_INT" (
  in _id int,
  in _content any,
  in _type varchar,
  in _perms varchar,
  in _owner integer,
  in _group integer)
{
  declare _res int;
  declare _path varchar;
  _path := DAV_SEARCH_PATH (_id, 'R');
  --dbg_obj_princ ('Versioning_CHECKOUT_INT: ', _path);
  if (not isstring (_path))
    return _path;
  _res := DAV_CHECKOUT_INT (_path, null, null, 0);
  -- dbg_obj_princ ('checkout: ', _res);
  if (_res > 0)
    update WS.WS.SYS_DAV_RES set RES_CONTENT = _content where RES_ID = _id;
  else
    return _res;
  return _id;
}
;

CREATE TRIGGER "Versioning_UNLOCK" BEFORE DELETE ON WS.WS.SYS_DAV_LOCK REFERENCING OLD AS O
{
  declare exit handler for sqlstate '*' {
  --dbg_obj_princ ('UNLOCK Error: ', __SQL_STATE, __SQL_MESSAGE);
  --dbg_obj_princ ('Versioning_UNLOCK: ', __SQL_STATE, __SQL_MESSAGE);
    resignal;
  };
  -- dbg_obj_princ ('Versioning_UNLOCK ()');

  if (DAV_HIDE_ERROR (DAV_PROP_GET_INT (O.LOCK_PARENT_ID, 'R', 'DAV:checked-out', 0)) is null)
    return;
  if (DAV_HIDE_ERROR (DAV_PROP_GET_INT (O.LOCK_PARENT_ID, 'R', 'DAV:checked-in', 0)) is not null)
    return;
  if (DAV_HIDE_ERROR (DAV_PROP_GET_INT (O.LOCK_PARENT_ID, 'R', 'DAV:auto-version', 0)) <> 'DAV:locked-checkout')
    return;
  declare _rc int;
  _rc := DAV_CHECKIN_INT ( DAV_SEARCH_PATH (O.LOCK_PARENT_ID, 'R'), null, null, 0 );
  -- dbg_obj_princ ('Versioning_UNLOCK: ', _rc);
}
;


--| API: set the resource under version control
create function DAV_VERSION_CONTROL (in path varchar, in auth varchar, in pwd varchar)
{
  -- dbg_obj_princ ('DAV_VERSION_CONTROL ', path, ', ', auth, ', ', pwd);
  declare _id int;
  _id := DAV_SEARCH_ID (path, 'R');
  if (DAV_HIDE_ERROR (_id) is null)
    return _id;
  if (not isinteger (_id))
    return -37; -- not supported for DET controlled resources

  declare _attic_id, _vvc_id, _main_id, _rc, ouid, guid int;
  declare _attic, _vvc, _main, oname, gname, resource varchar;
  select RES_NAME, RES_COL, RES_OWNER, RES_GROUP into resource, _main_id, ouid, guid from WS.WS.SYS_DAV_RES where RES_FULL_PATH = path;
  _main := DAV_SEARCH_PATH (_main_id, 'C');
  _vvc := _main || 'VVC/';
  _vvc_id := DAV_SEARCH_ID (_vvc, 'C');
  oname := (select U_NAME from DB.DBA.SYS_USERS where U_ID = ouid);
  gname := (select U_NAME from DB.DBA.SYS_USERS where U_ID = guid);
  if (DAV_HIDE_ERROR (_vvc_id) is null)
  {
    -- no VVC exists
    _vvc_id := DB.DBA.DAV_COL_CREATE (_vvc, '110100000--', oname, gname, auth, pwd);
    if (_vvc_id < 0)
      return _vvc_id;

    _rc := DAV_PROP_GET_INT (_vvc_id, 'C', 'virt:Versioning-Collection', 0);
    if (DAV_HIDE_ERROR(_rc) is not null and (_rc <> _main))
      return -16;

    if (not (DAV_HIDE_ERROR(_rc) is not null and (_rc = _main)))
    {
      _rc := DAV_PROP_SET (_vvc, 'virt:Versioning-Collection', _main, auth, pwd );
      if (DAV_HIDE_ERROR(_rc) is null)
      return _rc;
    }

    _rc := DAV_PROP_GET_INT (_main_id, 'C', 'virt:Versioning-History', 0);
    if (DAV_HIDE_ERROR(_rc) is not null and (_rc <> _vvc))
      return -16;

    if (not (DAV_HIDE_ERROR(_rc) is not null and (_rc = _vvc)))
    {
      _rc := DAV_PROP_SET (_main, 'virt:Versioning-History', _vvc, auth, pwd );
      if (DAV_HIDE_ERROR(_rc) is null)
      return _rc;
    }
       update WS.WS.SYS_DAV_COL set COL_DET = 'Versioning' where COL_ID = _vvc_id;
  }
  _attic := _main || 'Attic/';
  _attic_id := DAV_SEARCH_ID (_attic, 'C');
  if (DAV_HIDE_ERROR (_attic_id) is null) -- no Attic
  {
    _attic_id := DB.DBA.DAV_COL_CREATE (_attic, '110100000--', oname, gname, auth, pwd);
    if (DAV_HIDE_ERROR (_attic_id) is null)
      return _attic_id;

    _rc := DAV_PROP_SET (_vvc, 'virt:Versioning-Attic', _attic, auth, pwd);
    if (DAV_HIDE_ERROR (_rc) is null)
      return _rc;
    }
  if (DAV_HIDE_ERROR(DAV_PROP_GET_INT (_id, 'R', 'DAV:checked-in', 0)) or (DAV_HIDE_ERROR(DAV_PROP_GET_INT(_id, 'R', 'DAV:checked-out', 0)))) -- already under version control
    return _id;

  declare props_vect any;
  props_vect := vector ('DAV:checked-in',  _vvc || resource || '/last', 'DAV:version-history', _vvc || resource || '/history.xml', 'DAV:author', oname );
  _rc := DAV_SET_VERSIONING_PROPERTIES (path, props_vect);
  if (DAV_HIDE_ERROR (_rc) is null)
    return _rc;

  declare dt datetime;
  declare _type varchar;
  declare _content any;

  dt := now();
  select RES_TYPE, RES_CONTENT into _type, _content from WS.WS.SYS_DAV_RES where RES_ID = _id;
  insert into WS.WS.SYS_DAV_RES_VERSION (RV_RES_ID , -- This is equal to either existing resource ID or to an attic ID
      RV_ID, -- Version ID
      RV_NODE_NAME, -- Version number string as it can be used for data export. NULL to generate automatically.
      RV_PREV_ID, -- referenced by WS.WS.SYS_DAV_VERSION (RV_ID) when NOT NULL
      RV_ACT_ID, -- referenced by WS.WS.SYS_DAV_ACTIVITY (ACT_ID) when NOT NULL
      RV_RES_TYPE, -- MIME content type as it was in WS.WS.SYS_DAV_RES.RES_TYPE, NULL if deleted in this version.
      RV_CR_TIME, -- Old creation time as it was in WS.WS.SYS_DAV_RES.RES_CR_TIME
      RV_MOD_TIME, -- Old modification time as it was in WS.WS.SYS_DAV_RES.RES_MOD_TIME
      RV_WHO,
      RV_SIZE)
  values (
    _id,
    1,
    NULL,
    NULL,
    NULL,
    _type,
    dt,
    dt,
    auth,
    length (_content));
  "Versioning_ADD_NEW_DIFF" (_id, NULL, NULL, _content, 'c');

  return _id;
}
;

--| API: uncheckout resource
create function DAV_UNCHECKOUT (in path varchar, in auth varchar, in pwd varchar)
{
  -- dbg_obj_princ ('DAV_UNCHECKOUT: ', path);
  declare _content, _props any;
  declare _id int;
  _id := DAV_SEARCH_ID (path, 'R');
  if (DAV_HIDE_ERROR (_id) is null)
    return _id;
  if (DAV_HIDE_ERROR (DAV_AUTHENTICATE (_id, 'R', '_1_', auth, pwd)) is null)
    return -13;
  if (DAV_HIDE_ERROR(DAV_PROP_GET_INT (_id, 'R', 'DAV:checked-out', 0)) is null
  or (DAV_HIDE_ERROR(DAV_PROP_GET_INT(_id, 'R', 'DAV:checked-in', 0))))
    return -38;
  whenever not found goto nf;
  select RD_DELTA,RD_PROPS into _content, _props from WS.WS.SYS_DAV_RES_DIFF
    inner join WS.WS.SYS_DAV_RES on (RD_RES_ID = RES_ID)
    where RES_FULL_PATH = path and RD_FROM_ID = 0;
  update WS.WS.SYS_DAV_RES set RES_CONTENT = _content where RES_ID = _id;
  declare _rc int;
  if (_props is not null and isentity (_props)) {
    declare idx int;
    declare _ent any;
    idx := 1;
    for select PROP_NAME from WS.WS.SYS_DAV_PROP
      where PROP_PARENT_ID = _id
      and PROP_NAME not like 'DAV:%'
      and PROP_NAME not like ':%'
      and PROP_NAME not like 'virt:'
    do {
      if ( 0 > (_rc := DAV_PROP_REMOVE_INT (path, PROP_NAME, null, null, 0, 0)))
      {
        rollback work;
        return _rc;
      }
    }
    while ( (_ent := xpath_eval ('//property', _props, idx)) is not null)
    {
      if ( 0 > (_rc := DAV_PROP_SET_INT (path,
        cast (xpath_eval ('@name', _ent) as varchar),
        cast (xpath_eval ('text()', _ent) as varchar),
        NULL, NULL, 0, 0, 1)))
      {
        rollback work;
        return _rc;
      }
      idx := idx + 1;
    }
  }
  declare _checked_out varchar;
  _checked_out := DAV_PROP_GET_INT (_id, 'R', 'DAV:checked-out', 0);
  if (DAV_HIDE_ERROR (_checked_out) is null) {
    rollback work;
    return _checked_out;
  }
   connection_set ('Versioning REM PROP', 1);
  _rc :=  DAV_PROP_REMOVE_INT (path, 'DAV:checked-out', null, null, 0, 0);
   connection_set ('Versioning REM PROP', NULL);
  if (DAV_HIDE_ERROR (_rc) is null) {
    rollback work;
    return _rc;
  }
  _rc := DAV_PROP_SET_INT (path, 'DAV:checked-in', _checked_out, NULL, NULL, 0, 0, 1);
  if (DAV_HIDE_ERROR (_rc) is null) {
    rollback work;
    return _rc;
  }
  return _id;
nf:
  --dbg_obj_print ('notf');
  return -1;
}
;


create procedure "Versioning_Attic" (in _resource varchar)
{
  declare _col int;
  _col := (select RES_COL from WS.WS.SYS_DAV_RES where RES_FULL_PATH = _resource);
  if (_col is null)
    return null;
  declare _hist_col varchar;
  _hist_col := DAV_PROP_GET_INT (_col, 'C', 'virt:Versioning-History', 0);
  if (DAV_HIDE_ERROR (_hist_col) is null)
    return NULL;
  _hist_col := DAV_SEARCH_ID (_hist_col, 'C');
  if (DAV_HIDE_ERROR (_hist_col) is null)
    return NULL;
  return DAV_HIDE_ERROR (DAV_PROP_GET_INT (_hist_col, 'C', 'virt:Versioning-Attic', 0));
}
;

create procedure "Versioning_OTHER_FILES_IN_VVC" (in _res varchar)
{
  -- TODO: add the check.
  return 1;
}
;

--!AWK PUBLIC
create procedure DAV_REMOVE_VERSION_CONTROL (in _resource varchar, in auth varchar, in pwd varchar, in tokens any := 1)
{
  declare _err int;
  if ((DAV_HIDE_ERROR ( (_err := DAV_PROP_GET (_resource, 'DAV:checked-out', auth, pwd))) is null) and
      (_err = -11))
  {
    declare checkin varchar;
    declare locked int;
    declare _id int;
    if (DAV_HIDE_ERROR ( (checkin := DAV_PROP_GET (_resource, 'DAV:checked-in', auth, pwd))) is null)
      return checkin;
    _id := DAV_SEARCH_ID (_resource, 'R');
    if (_id < 0)
      return _id;
    if(DAV_HIDE_ERROR ( (locked := DAV_IS_LOCKED (_id, 'R', tokens))) is null)
      return locked;
    if (locked)
      return -8;
    connection_set ('Versioning REM PROP', 1);
    _err := DAV_PROP_REMOVE (_resource, 'DAV:checked-in', auth, pwd);
    connection_set ('Versioning REM PROP', NULL);
    if (DAV_HIDE_ERROR (_err) is null)
      return _err;
    declare _attic varchar;
    _attic := "Versioning_Attic" (_resource);
    if (_attic is not null) {
      declare _name varchar;
      select RES_NAME into _name from WS.WS.SYS_DAV_RES where RES_FULL_PATH = _resource;
      DAV_DELETE (_attic || _name, 1, pwd, auth);
    }
    if (not "Versioning_OTHER_FILES_IN_VVC" (_resource)) {
      if (_attic is not null)
        DAV_DELETE (_attic, 1, pwd, auth);
    }
    -- authentication was checked implicitly before, no need to handle error code and check
    -- is the property exists or not:
    connection_set ('Versioning REM PROP', 1);
    DAV_PROP_REMOVE (_resource, 'DAV:auto-version', auth, pwd);
    DAV_PROP_REMOVE (_resource, 'DAV:author', auth, pwd);
    DAV_PROP_REMOVE (_resource, 'DAV:version-history', auth, pwd);
    connection_set ('Versioning REM PROP', NULL);
    delete from WS.WS.SYS_DAV_RES_VERSION where RV_RES_ID = _id;
    delete from WS.WS.SYS_DAV_RES_DIFF where RD_RES_ID = _id;
    return _id;
  }
  else {
    if (isinteger (_err))
      return _err;
    else
      return -37;
  }
}
;


--!AWK PUBLIC
create procedure DAV_VERSION_FOLD_INT (in path varchar, in target_version int, in auth varchar)
{
  if (target_version <= 0)
    return -17;
  declare id, res int;
  id := DAV_SEARCH_ID (path, 'R');
  if (DAV_HIDE_ERROR (id) is null)
    return id;
-- if (DAV_HIDE_ERROR (DAV_AUTHENTICATE (id, 'R', '_1_', auth, pwd)) is null)
--   return -13;
  declare _curr_content, _type varchar;
  declare _curr_cr_time, _curr_mod_time datetime;
  declare cr cursor for select RES_CONTENT, RES_TYPE, RES_CR_TIME, RES_MOD_TIME from WS.WS.SYS_DAV_RES
  where RES_ID = id;
  open cr (prefetch 1, exclusive);
  fetch cr into _curr_content, _type, _curr_cr_time, _curr_mod_time;
  close cr;

  declare _prev_version int;
  declare exit handler for not found {
    return -17;
  };
  select RV_PREV_ID into _prev_version from WS.WS.SYS_DAV_RES_VERSION where RV_RES_ID = id and RV_ID = target_version;
  if (_prev_version is null) {
    delete from WS.WS.SYS_DAV_RES_DIFF where RD_RES_ID = id and RD_TO_ID <> target_version;
    delete from WS.WS.SYS_DAV_RES_VERSION where RV_RES_ID = id and RV_ID <> target_version;
    update WS.WS.SYS_DAV_RES_DIFF set RD_DELTA = _curr_content where RD_RES_ID = id and RD_TO_ID = target_version;
    return id;
  }
  else {
    declare _prev_content, _prev_type, _prev_mode varchar;
    DAV_GET_VERSION_CONTENT (id, _prev_version, _prev_content, _prev_type, _prev_mode);
    whenever sqlstate 'DF*' goto full_copy;
    declare _diff, _diff_type varchar;
    if (_type like 'text/%') {
      _diff := diff (cast (_curr_content as varchar), cast (_prev_content as varchar), '--normal');
      _diff_type := 'D';
    }
    else {
full_copy:
      -- dbg_obj_princ ('SQL ERR: ', __SQL_STATE, __SQL_MESSAGE);
      _diff := NULL;
      _diff_type := 'c';
    }
    delete from WS.WS.SYS_DAV_RES_DIFF where RD_RES_ID = id and RD_TO_ID > _prev_version;
    delete from WS.WS.SYS_DAV_RES_VERSION where RV_RES_ID = id and RV_ID > _prev_version;
    insert replacing WS.WS.SYS_DAV_RES_VERSION (RV_RES_ID , -- This is equal to either existing resource ID or to an attic ID
      RV_ID, -- Version ID
      RV_NODE_NAME, -- Version number string as it can be used for data export. NULL to generate automatically.
      RV_PREV_ID, -- referenced by WS.WS.SYS_DAV_VERSION (RV_ID) when NOT NULL
      RV_ACT_ID, -- referenced by WS.WS.SYS_DAV_ACTIVITY (ACT_ID) when NOT NULL
      RV_RES_TYPE, -- MIME content type as it was in WS.WS.SYS_DAV_RES.RES_TYPE, NULL if deleted in this version.
      RV_CR_TIME, -- Old creation time as it was in WS.WS.SYS_DAV_RES.RES_CR_TIME
      RV_MOD_TIME, -- Old modification time as it was in WS.WS.SYS_DAV_RES.RES_MOD_TIME
      RV_WHO,
      RV_SIZE)
    values (id, target_version,
      NULL, _prev_version, NULL, _type, _curr_cr_time, _curr_mod_time, auth, length (_curr_content));
    "Versioning_ADD_NEW_DIFF" (id, target_version, _prev_version, _curr_content, _diff_type, _diff);
    return id;
  }
}
;

CREATE TRIGGER "Versioning_DELETE_COL_B" BEFORE DELETE ON WS.WS.SYS_DAV_COL ORDER 50 REFERENCING OLD AS O
{
  --dbg_obj_princ('Versioning_DELETE_COL_B: ', O.COL_ID);
  if (DAV_HIDE_ERROR (DAV_PROP_GET_INT (O.COL_ID, 'C', 'virt:Versioning-Collection', 0)) is not null)
  {
    declare _col_id int;
    declare _attic varchar;
    _col_id := DAV_SEARCH_ID (DAV_PROP_GET_INT (O.COL_ID, 'C', 'virt:Versioning-Collection', 0), 'C');
    _attic := DAV_HIDE_ERROR (DAV_PROP_GET_INT (O.COL_ID, 'C', 'virt:Versioning-Attic', 0));
    --dbg_obj_princ ('(col_id, attic):::', _col_id, _attic);

    connection_set ('Versioning REM PROP', 1);
    for select RES_FULL_PATH, RES_ID from WS.WS.SYS_DAV_RES
      where RES_COL = _col_id and exists (select 1 from WS.WS.SYS_DAV_RES_VERSION where RV_RES_ID = RES_ID)
    do {
      delete from WS.WS.SYS_DAV_RES_DIFF where RES_ID = RD_RES_ID;
      delete from WS.WS.SYS_DAV_RES_VERSION where  RES_ID = RV_RES_ID;
      "Versioning_REMOVE_V_PROPERTIES" (RES_FULL_PATH);
    }
    update WS.WS.SYS_DAV_COL set COL_AUTO_VERSIONING = NULL where COL_ID = _col_id;

    if (_attic is not null)
      DAV_DELETE_INT (_attic, 0, null, null, 0);
  }
}
;
