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

create procedure AP_EXEC_NO_ERROR (in expr varchar)
{
  declare state, message, meta, result any;
  exec(expr, state, message, vector(), 0, meta, result);
}
;

create table DB.DBA.SYS_ANN_PHRASE_CLASS
(
  APC_ID integer not null primary key,
  APC_NAME varchar(255),		-- unique name for use in API/UI
  APC_OWNER_UID integer,		-- references SYS_USERS (U_ID), NULL if the record writeable for any reader
  APC_READER_GID integer,		-- references SYS_USERS (U_ID), NULL if the record is readable for public
  APC_CALLBACK varchar,
  APC_APP_ENV any
  )
alter index SYS_ANN_PHRASE_CLASS on DB.DBA.SYS_ANN_PHRASE_CLASS partition cluster replicated
create unique index SYS_ANN_PHRASE_CLASS_APC_NAME on DB.DBA.SYS_ANN_PHRASE_CLASS (APC_NAME) partition cluster replicated
;

create table DB.DBA.SYS_ANN_PHRASE_SET
(
  APS_ID integer not null primary key,
  APS_NAME varchar(255),		-- unique name for use in API/UI
  APS_OWNER_UID integer,		-- references SYS_USERS (U_ID), NULL if the record writeable for any reader
  APS_READER_GID integer,		-- references SYS_USERS (U_ID), NULL if the record is readable for public
  APS_APC_ID integer not null,		-- references SYS_ANN_PHRASE_CLASS (APC_ID)
  APS_LANG_NAME varchar not null,	-- name of language handler that is used to split texts of phrases
  APS_APP_ENV any,
  APS_SIZE any,				-- approximate number of phrases in set (actual or estimate for future)
  APS_LOAD_AT_BOOT integer not null	-- flags whether phrases should be loaded at boot time.
  )
alter index SYS_ANN_PHRASE_SET on DB.DBA.SYS_ANN_PHRASE_SET partition cluster replicated
create unique index SYS_ANN_PHRASE_SET_APS_NAME on DB.DBA.SYS_ANN_PHRASE_SET (APS_NAME) partition cluster replicated
;

--#IF VER=5
alter table DB.DBA.SYS_ANN_PHRASE_SET add APS_LOAD_AT_BOOT integer not null
;
--#ENDIF

create table DB.DBA.SYS_ANN_PHRASE
(
  AP_APS_ID integer not null,		-- references SYS_ANN_PHRASE_SET (APS_ID),
  AP_CHKSUM integer,			-- phrase checksum
  AP_TEXT varchar,			-- original text
  AP_LINK_DATA any,			-- Associated data about links etc.
  AP_LINK_DATA_LONG long varchar,	-- Same as AP_LINK_DATA but for long content, one of two is always NULL
  primary key (AP_APS_ID, AP_CHKSUM, AP_TEXT)
  )
alter index SYS_ANN_PHRASE on DB.DBA.SYS_ANN_PHRASE partition cluster replicated
;

--#IF VER=5
alter table DB.DBA.SYS_ANN_PHRASE add AP_LINK_DATA_LONG long varchar
;
--#ENDIF

create table DB.DBA.SYS_ANN_AD_ACCOUNT (
  AAA_ID integer not null primary key,
  AAA_NAME varchar(255),		-- unique name for use in API/UI
  AAA_OWNER_UID integer,		-- references SYS_USERS (U_ID), NULL if the record writeable for any reader
  AAA_READER_GID integer,		-- references SYS_USERS (U_ID), NULL if the record is readable for public
  AAA_DETAILS long xml,			-- any details, e.g., in RDF
  AAA_APP_ENV any
  )
alter index SYS_ANN_AD_ACCOUNT on DB.DBA.SYS_ANN_AD_ACCOUNT partition cluster replicated
create unique index SYS_ANN_AD_ACCOUNT_AAA_NAME on DB.DBA.SYS_ANN_AD_ACCOUNT (AAA_NAME) partition cluster replicated
;

create table DB.DBA.SYS_ANN_LINK (
  AL_ID integer primary key,
  AL_OWNER_UID integer,			-- references SYS_USERS (U_ID), NULL if the record writeable for any reader; always readable for public
  AL_URI varchar,			-- URI template for A HREF
  AL_TEXT varchar,			-- text template for body of <A>
  AL_NOTE varchar,			-- taxt after the link (or around it)
  AL_TAGS any,				-- tags to add or remove
  AL_CALLBACK varchar,
  AL_APP_ENV any
  )
alter index SYS_ANN_LINK on DB.DBA.SYS_ANN_LINK partition cluster replicated
;

create table DB.DBA.SYS_ANN_AD_RULE (
  AAR_AAA_ID integer not null,		-- advertizer who pays for the ad
  AAR_APS_ID integer not null,		-- phrase set
  AAR_AP_CHKSUM integer not null,	-- phrase checksum
  AAR_TEXT varchar not null,		-- original text
  AAR_AL_ID integer not null,		-- references SYS_ANN_LINK (AL_ID)
  AAR_APP_ENV any,
  primary key (AAR_AAA_ID, AAR_APS_ID, AAR_AP_CHKSUM, AAR_TEXT, AAR_AL_ID)
  )
alter index SYS_ANN_AD_RULE on DB.DBA.SYS_ANN_AD_RULE partition cluster replicated
;

--#IF VER=5
delete from SYS_TRIGGERS where T_NAME in (
  fix_identifier_case ('DBA.SYS_ANN_PHRASE_CLASS_I'),
  fix_identifier_case ('DBA.SYS_ANN_PHRASE_CLASS_U'),
  fix_identifier_case ('DBA.SYS_ANN_PHRASE_CLASS_BD'),
  fix_identifier_case ('DBA.SYS_ANN_PHRASE_SET_I'),
  fix_identifier_case ('DBA.SYS_ANN_PHRASE_SET_U'),
  fix_identifier_case ('DBA.SYS_ANN_PHRASE_SET_BD') )
;

delete from SYS_PROCEDURES where P_NAME in (
  fix_identifier_case ('DB.DBA.AP_EXEC_NO_ERROR'),
  fix_identifier_case ('DB.DBA.ANN_BOOT'),
  fix_identifier_case ('DB.DBA.ANN_ZAP'),
  fix_identifier_case ('DB.DBA.ANN_AUTHENTICATE'),
  fix_identifier_case ('DB.DBA.ANN_GETID'),
  fix_identifier_case ('DB.DBA.ANN_PHRASE_CLASS_ADD'),
  fix_identifier_case ('DB.DBA.ANN_PHRASE_CLASS_ADD_INT'),
  fix_identifier_case ('DB.DBA.ANN_PHRASE_CLASS_DEL'),
  fix_identifier_case ('DB.DBA.ANN_PHRASE_SET_ADD'),
  fix_identifier_case ('DB.DBA.ANN_PHRASE_SET_ADD_INT'),
  fix_identifier_case ('DB.DBA.ANN_PHRASE_SET_DEL'),
  fix_identifier_case ('DB.DBA.ANN_LINK_ADD'),
  fix_identifier_case ('DB.DBA.ANN_LINK_MODIFY'),
  fix_identifier_case ('DB.DBA.ANN_LINK_DEL'),
  fix_identifier_case ('DB.DBA.ANN_AD_RULE_ADD'),
  fix_identifier_case ('DB.DBA.ANN_AD_RULE_DEL') )
;
--#ENDIF

create trigger SYS_ANN_PHRASE_CLASS_I after insert on DB.DBA.SYS_ANN_PHRASE_CLASS referencing new as N
{
  ap_class_status (N.APC_ID, 1, 1);
}
;

create trigger SYS_ANN_PHRASE_CLASS_U after update on DB.DBA.SYS_ANN_PHRASE_CLASS referencing new as N
{
  ap_class_status (N.APC_ID, 1, 1);
}
;

create trigger SYS_ANN_PHRASE_CLASS_BD before delete on DB.DBA.SYS_ANN_PHRASE_CLASS referencing old as O
{
  if (exists (select top 1 1 from DB.DBA.SYS_ANN_PHRASE_SET where APS_APC_ID = O.APC_ID))
    signal ('42000', sprintf ('Integrity violation: can not delete annotation phrase class "%s" that is referenced by a phrase set', O.APC_NAME));
  ap_class_status (O.APC_ID, 0);
}
;

create trigger SYS_ANN_PHRASE_SET_I after insert on DB.DBA.SYS_ANN_PHRASE_SET referencing new as N
{
  ap_set_status (N.APS_ID, 1, 1);
}
;

create trigger SYS_ANN_PHRASE_SET_U after update on DB.DBA.SYS_ANN_PHRASE_SET referencing new as N
{
  ap_set_status (N.APS_ID, 1, 1);
}
;

create trigger SYS_ANN_PHRASE_SET_BD before delete on DB.DBA.SYS_ANN_PHRASE_SET referencing old as O
{
  ap_set_status (O.APS_ID, 0);
}
;

create procedure DB.DBA.ANN_BOOT()
{
  ap_global_init ();
  for select APC_ID from DB.DBA.SYS_ANN_PHRASE_CLASS do
    {
      ap_class_status (APC_ID, 1, 0);
    }
  for select APS_ID, APS_LOAD_AT_BOOT from DB.DBA.SYS_ANN_PHRASE_SET do
    {
      ap_set_status (APS_ID, case (APS_LOAD_AT_BOOT) when 0 then 1 else 2 end, 0);
    }
}
;

create function ANN_AUTHENTICATE (in id any, in what char (1), in access char, in auth_uname any, in auth_pwd varchar, inout auth_uid integer := null) returns integer
{
  declare uid, owner_uid, reader_gid, res_id integer;
  declare pwd varchar;
whenever not found goto obj_nf;
  if ('C' = what)
    {
      if (isinteger (id))
        select APC_ID, APC_OWNER_UID, APC_READER_GID into res_id, owner_uid, reader_gid from DB.DBA.SYS_ANN_PHRASE_CLASS where APC_ID = id;
      else
        select APC_ID, APC_OWNER_UID, APC_READER_GID into res_id, owner_uid, reader_gid from DB.DBA.SYS_ANN_PHRASE_CLASS where APC_NAME = id;
    }
  else if ('S' = what)
    {
      if (isinteger (id))
        select APS_ID, APS_OWNER_UID, APS_READER_GID into res_id, owner_uid, reader_gid from DB.DBA.SYS_ANN_PHRASE_SET where APS_ID = id;
      else
        select APS_ID, APS_OWNER_UID, APS_READER_GID into res_id, owner_uid, reader_gid from DB.DBA.SYS_ANN_PHRASE_SET where APS_NAME = id;
    }
  else if ('A' = what)
    {
      if (isinteger (id))
        select AAA_ID, AAA_OWNER_UID, AAA_READER_GID into res_id, owner_uid, reader_gid from DB.DBA.SYS_ANN_AD_ACCOUNT where AAA_ID = id;
      else
        select AAA_ID, AAA_OWNER_UID, AAA_READER_GID into res_id, owner_uid, reader_gid from DB.DBA.SYS_ANN_AD_ACCOUNT where AAA_NAME = id;
    }
  else if ('L' = what)
    {
      if (isinteger (id))
        select AL_ID, AL_OWNER_UID, null into res_id, owner_uid, reader_gid from DB.DBA.SYS_ANN_LINK where AL_ID = id;
      else
        return -7;
    }
  else return -14;
whenever not found goto user_nf;
  if (auth_uid is null)
    {
      if (isinteger (auth_uname))
        select U_PASSWORD, U_ID into pwd, uid from DB.DBA.SYS_USERS where U_ID = auth_uname and (0 = U_ACCOUNT_DISABLED) and U_SQL_ENABLE;
      else
        select U_PASSWORD, U_ID into pwd, uid from DB.DBA.SYS_USERS where U_NAME = auth_uname;
      if (isstring (pwd))
	{
	  if ((pwd[0] = 0 and not pwd_magic_calc (auth_uname, auth_pwd) = pwd) or (pwd[0] <> 0 and pwd <> auth_pwd))
	    {
	      -- dbg_obj_princ ('ANN_AUTHENTICATE: the password of ', auth_uname, ' is not ', auth_pwd);
	      return -12;
	    }
	}
      auth_uid := uid;
    }
  else
    uid := auth_uid;
  -- dbg_obj_princ ('ANN_AUTHENTICATE: res_id=', res_id, ', owner_uid=', owner_uid, ', reader_gid=', reader_gid, ' auth_uid=', auth_uid, ' access=', access);
  if (0 = uid)
    return res_id;
  if (owner_uid is not null)
    {
      if (owner_uid = uid)
        return res_id;
      if ('W' = access)
        return -12;
    }
  if (reader_gid is not null)
    {
      if (exists (select top 1 1 from DB.DBA.SYS_USER_GROUP where UG_UID = uid and UG_GID = reader_gid))
        return res_id;
      return -12;
    }
  return res_id;
obj_nf:
  return -1;
user_nf:
  -- dbg_obj_princ ('ANN_AUTHENTICATE: no user ', auth_uname);
  return -12;
}
;

create function ANN_GETID (in what varchar )
{
  if ('C' = what)
    {
      return coalesce (
        (select top 1 (t.APC_ID-1) from DB.DBA.SYS_ANN_PHRASE_CLASS as t where t.APC_ID > 1 and not exists (select top 1 1 from DB.DBA.SYS_ANN_PHRASE_CLASS as i where i.APC_ID = t.APC_ID-1)),
        (select max (u.APC_ID+1) from DB.DBA.SYS_ANN_PHRASE_CLASS as u),
	1 );
    }
  if ('S' = what)
    {
      return coalesce (
        (select top 1 (t.APS_ID-1) from DB.DBA.SYS_ANN_PHRASE_SET as t where t.APS_ID > 1 and not exists (select top 1 1 from DB.DBA.SYS_ANN_PHRASE_SET as i where i.APS_ID = t.APS_ID-1)),
        (select max (u.APS_ID+1) from DB.DBA.SYS_ANN_PHRASE_SET as u),
	1 );
    }
  if ('A' = what)
    {
      return coalesce (
        (select top 1 (t.AAA_ID-1) from DB.DBA.SYS_ANN_AD_ACCOUNT as t where t.AAA_ID > 1 and not exists (select top 1 1 from DB.DBA.SYS_ANN_AD_ACCOUNT as i where i.AAA_ID = t.AAA_ID-1)),
        (select max (u.AAA_ID+1) from DB.DBA.SYS_ANN_AD_ACCOUNT as u),
	1 );
    }
  if ('L' = what)
    {
      return coalesce (
        (select top 1 (t.AL_ID-1) from DB.DBA.SYS_ANN_LINK as t where t.AL_ID > 1 and not exists (select top 1 1 from DB.DBA.SYS_ANN_LINK as i where i.AL_ID = t.AL_ID-1)),
        (select max (u.AL_ID+1) from DB.DBA.SYS_ANN_LINK as u),
	1 );
    }
  return -14;
}
;

--!AWK PUBLIC
create function ANN_PHRASE_CLASS_ADD (in _name varchar, in _owner_uid integer, in _reader_gid integer, in _callback varchar, in _app_env any, in mode varchar, in auth_uname varchar, in auth_pwd varchar) returns integer
{
  declare auth_uid, _id integer;
  mode := lower (mode);
  auth_uid := NULL;
  _id := ANN_AUTHENTICATE (_name, 'C', 'W', auth_uname, auth_pwd, auth_uid);
  if (_id < -1)
    return _id;
  if (_id = -1)
    _id := ANN_GETID ('C');
  else
    {
      if ('into' = mode)
        signal ('23000', sprintf ('Uniqueness violation: Annotation phrase class ''%s'' exists', _name));
      if ('soft' = mode)
        return _id;
    }
  return ANN_PHRASE_CLASS_ADD_INT (_id, _name, _owner_uid, _reader_gid, _callback, _app_env);
}
;

create function ANN_PHRASE_CLASS_ADD_INT (in _id integer, in _name varchar, in _owner_uid integer, in _reader_gid integer, in _callback varchar, in _app_env any)
{
  insert replacing DB.DBA.SYS_ANN_PHRASE_CLASS (APC_ID, APC_NAME, APC_OWNER_UID, APC_READER_GID, APC_CALLBACK, APC_APP_ENV)
  values (_id, _name, _owner_uid, _reader_gid, _callback, _app_env);
  return _id;
}
;

--!AWK PUBLIC
create function ANN_PHRASE_CLASS_DEL (in _name varchar, in auth_uname varchar, in auth_pwd varchar) returns integer
{
  declare auth_uid, _id integer;
  auth_uid := NULL;
  _id := ANN_AUTHENTICATE (_name, 'C', 'W', auth_uname, auth_pwd, auth_uid);
  if (_id < 0)
    return _id;
  if (exists (select top 1 1 from DB.DBA.SYS_ANN_PHRASE_SET where APS_APC_ID = _id))
    {
      declare use_sample_name varchar;
      use_sample_name := coalesce ((select top 1 APS_NAME from DB.DBA.SYS_ANN_PHRASE_SET where ANN_AUTHENTICATE (APS_NAME, 'S', 'R', auth_uname, auth_pwd, auth_uid)));
      if (use_sample_name is null)
        signal ('23000', sprintf ('Integrity violation: annotation phrase class ''%s'' is used in definition of some annotation phrase set', _name));
      else
        signal ('23000', sprintf ('Integrity violation: annotation phrase class ''%s'' is used in definition of annotation phrase set ''%s''', _name, use_sample_name));
    }
  delete from DB.DBA.SYS_ANN_PHRASE_CLASS where APC_ID = _id;
  return _id;
}
;

--!AWK PUBLIC
create function ANN_PHRASE_SET_ADD (in _name varchar, in _owner_uid integer, in _reader_gid integer, in _apc_name varchar, in _lang_name varchar, in _app_env any, in _size integer, in _load_at_boot integer, in mode varchar, in auth_uname varchar, in auth_pwd varchar) returns integer
{
  declare auth_uid, _id, _apc_id integer;
  mode := lower (mode);
  auth_uid := NULL;
  _apc_id := ANN_AUTHENTICATE (_apc_name, 'C', 'R', auth_uname, auth_pwd, auth_uid);
  if (_apc_id < 0)
    return _apc_id;
  _id := ANN_AUTHENTICATE (_name, 'S', 'W', auth_uname, auth_pwd, auth_uid);
  if (_id < -1)
    return _id;
  if (_id = -1)
    _id := ANN_GETID ('S');
  else
    {
      declare old_lang_name varchar;
      if ('into' = mode)
        signal ('23000', sprintf ('Uniqueness violation: Annotation phrase set ''%s'' exists', _name));
      old_lang_name := coalesce ((select APS_LANG_NAME from DB.DBA.SYS_ANN_PHRASE_SET where APS_ID = _id));
      if (_lang_name <> old_lang_name)
        signal ('23000', sprintf ('Integrity violation: Annotation phrase set ''%s'' uses language ''%s'' that can not be replaced with ''%s''', _name, old_lang_name, _lang_name));
      if ('soft' = mode)
        return _id;
    }
  return ANN_PHRASE_SET_ADD_INT (_id, _name, _owner_uid, _reader_gid, _apc_id, _lang_name, _app_env, _size, _load_at_boot);
}
;

create function ANN_PHRASE_SET_ADD_INT (in _id integer, in _name varchar, in _owner_uid integer, in _reader_gid integer, in _apc_id integer, in _lang_name varchar, in _app_env any, in _size integer, in _load_at_boot integer)
{
  insert replacing DB.DBA.SYS_ANN_PHRASE_SET (APS_ID, APS_NAME, APS_OWNER_UID, APS_READER_GID, APS_APC_ID, APS_LANG_NAME, APS_APP_ENV, APS_SIZE, APS_LOAD_AT_BOOT)
  values (_id, _name, _owner_uid, _reader_gid, _apc_id, _lang_name, _app_env, _size, _load_at_boot);
  return _id;
}
;

--!AWK PUBLIC
create function ANN_PHRASE_SET_DEL (in _name varchar, in auth_uname varchar, in auth_pwd varchar) returns integer
{
  declare auth_uid, _id integer;
  auth_uid := NULL;
  _id := ANN_AUTHENTICATE (_name, 'S', 'W', auth_uname, auth_pwd, auth_uid);
  if (_id < 0)
    return _id;
  if (exists (select top 1 1 from DB.DBA.SYS_ANN_AD_RULE where AAR_APS_ID = _id))
    {
      declare use_sample_name varchar;
      use_sample_name := coalesce ((select top 1 AAA_NAME from DB.DBA.SYS_ANN_AD_RULE join DB.DBA.SYS_ANN_AD_ACCOUNT on (AAR_AAA_ID = AAA_ID) where AAR_APS_ID = _id and ANN_AUTHENTICATE (AAA_ID, 'A', 'R', auth_uname, auth_pwd, auth_uid)));
      if (use_sample_name is null)
        signal ('23000', sprintf ('Integrity violation: annotation phrase set ''%s'' is used by some advertizer', _name));
      else
        signal ('23000', sprintf ('Integrity violation: annotation phrase set ''%s'' is used by advertizer ''%s''', _name, use_sample_name));
    }
  delete from DB.DBA.SYS_ANN_PHRASE where AP_APS_ID = _id;
  delete from DB.DBA.SYS_ANN_PHRASE_SET where APS_ID = _id;
  return _id;
}
;

--!AWK PUBLIC
create function ANN_LINK_ADD (in _owner_uid integer, in _uri varchar, in _text varchar, in _note varchar, in _tags any, in _callback varchar, in _app_env any) returns integer
{
  declare _id integer;
  _id := ANN_GETID ('L');
  insert into DB.DBA.SYS_ANN_LINK (AL_ID, AL_OWNER_UID, AL_URI, AL_TEXT, AL_NOTE, AL_TAGS, AL_CALLBACK, AL_APP_ENV)
  values (_id, _owner_uid, _uri, _text, _note, _tags, _callback, _app_env);
  return _id;
}
;

--!AWK PUBLIC
create function ANN_LINK_MODIFY (in _id integer, in _owner_uid integer, in _uri varchar, in _text varchar, in _note varchar, in _tags any, in _callback varchar, in _app_env any, in auth_uname varchar, in auth_pwd varchar) returns integer
{
  declare _res integer;
  declare auth_uid integer;
  auth_uid := NULL;
  _res := ANN_AUTHENTICATE (_id, 'L', 'W', auth_uname, auth_pwd, auth_uid);
  if (_res < 0)
    return _res;
  insert replacing DB.DBA.SYS_ANN_LINK (AL_ID, AL_OWNER_UID, AL_URI, AL_TEXT, AL_NOTE, AL_TAGS, AL_CALLBACK, AL_APP_ENV)
  values (_id, _owner_uid, _uri, _text, _note, _tags, _callback, _app_env);
  return _id;
}
;

--!AWK PUBLIC
create function ANN_LINK_DEL (in _id integer, in auth_uname varchar, in auth_pwd varchar) returns integer
{
  declare _res integer;
  declare auth_uid integer;
  auth_uid := NULL;
  _res := ANN_AUTHENTICATE (_id, 'L', 'W', auth_uname, auth_pwd, auth_uid);
  if (_res < 0)
    return _res;
  if (exists (select top 1 1 from DB.DBA.SYS_ANN_AD_RULE where AAR_AL_ID = _id))
    {
      declare use_sample_name varchar;
      use_sample_name := coalesce ((select top 1 AAA_NAME from DB.DBA.SYS_ANN_AD_RULE join DB.DBA.SYS_ANN_AD_ACCOUNT on (AAR_AAA_ID = AAA_ID) where AAR_AL_ID = _id and ANN_AUTHENTICATE (AAA_ID, 'A', 'R', auth_uname, auth_pwd, auth_uid)));
      if (use_sample_name is null)
        signal ('23000', sprintf ('Integrity violation: advertizing link %d is used by some advertizer', _id));
      else
        signal ('23000', sprintf ('Integrity violation: advertizing link %d is used by advertizer ''%s''', _id, use_sample_name));
    }
  delete from DB.DBA.SYS_ANN_LINK where AL_ID = _id;
  return _id;
}
;

--!AWK PUBLIC
create function ANN_AD_RULE_ADD (in aaa_name varchar, in aps_name varchar, in _text varchar, in _al_id integer, in _app_env any, in _lang_name varchar, in auth_uname varchar, in auth_pwd varchar) returns integer
{
  declare _aaa_id, _aps_id, _ap_chksum integer;
  declare auth_uid integer;
  declare _aps_lang_name varchar;
  declare old_data, old_al any;
  declare old_al_idx integer;
  auth_uid := NULL;
  _aaa_id := ANN_AUTHENTICATE (aaa_name, 'A', 'W', auth_uname, auth_pwd, auth_uid); -- 'W' because we're going to charge the account.
  if (_aaa_id < 0)
    return _aaa_id;
  _aps_id := ANN_AUTHENTICATE (aps_name, 'S', 'W', auth_uname, auth_pwd, auth_uid);
  if (_aps_id < 0)
    return _aps_id;
  if (not exists (select top 1 1 from DB.DBA.SYS_ANN_LINK where AL_ID = _al_id))
    return -1;
  _aps_lang_name := coalesce ((select APS_LANG_NAME from DB.DBA.SYS_ANN_PHRASE_SET where APS_ID = _aps_id));
  if (_lang_name <> _aps_lang_name)
    signal ('23000', sprintf ('Integrity violation: language ''%s'' in advertizing rule conflicts with language ''%s'' of phrase set ''%s''', _lang_name, _aps_lang_name, aps_name));
  _ap_chksum := ap_phrase_chksum (_text, _lang_name);
  old_data := coalesce ((select AP_LINK_DATA from DB.DBA.SYS_ANN_PHRASE where AP_APS_ID = _aps_id and AP_CHKSUM=_ap_chksum and AP_TEXT = _text), vector ());
  if (not isarray (old_data))
    return -9;
  if (mod (length (old_data), 2))
    return -9;
  old_al_idx := position ('AL', old_data, 1, 2);
  if (0 = old_al_idx)
    old_data := vector_concat (vector ('AL', vector (_al_id, _aaa_id, _app_env)), old_data);
  else
    {
      old_al := aref_set_0 (old_data, old_al_idx);
      if (mod (length (old_al), 3))
	return -9;
      if (0 <> position (_al_id, old_al, 1, 3))
        {
          old_data [old_al_idx] := old_al;
          return -8;
        }
      old_data [old_al_idx] := vector_concat (old_al, vector (_al_id, _aaa_id, _app_env));
    }
  ap_add_phrases (_aps_id, vector (vector (_text, old_data)));
  insert replacing DB.DBA.SYS_ANN_AD_RULE (AAR_AAA_ID, AAR_APS_ID, AAR_AP_CHKSUM, AAR_TEXT, AAR_AL_ID, AAR_APP_ENV)
  values (_aaa_id, _aps_id, _ap_chksum, _text, _al_id, _app_env);
  commit work;
  return 0;
}
;

--!AWK PUBLIC
create function ANN_AD_RULE_DEL (in aaa_name varchar, in aps_name varchar, in _text varchar, in _al_id integer, in _lang_name varchar, in auth_uname varchar, in auth_pwd varchar) returns integer
{
  declare _aaa_id, _aps_id, _ap_chksum integer;
  declare auth_uid integer;
  declare _aps_lang_name varchar;
  declare old_data, old_al, pos_to_del any;
  declare old_al_idx, res integer;
  auth_uid := NULL;
  _aaa_id := ANN_AUTHENTICATE (aaa_name, 'A', 'W', auth_uname, auth_pwd, auth_uid); -- 'W' because we're going to remove an ad that can be worth.
  if (_aaa_id < 0)
    return _aaa_id;
  _aps_id := ANN_AUTHENTICATE (aps_name, 'S', 'W', auth_uname, auth_pwd, auth_uid);
  if (_aps_id < 0)
    return _aps_id;
  if (not exists (select top 1 1 from DB.DBA.SYS_ANN_LINK where AL_ID = _al_id))
    return -1;
  _aps_lang_name := coalesce ((select APS_LANG_NAME from DB.DBA.SYS_ANN_PHRASE_SET where APS_ID = _aps_id));
  if (_lang_name <> _aps_lang_name)
    signal ('23000', sprintf ('Integrity violation: language ''%s'' in advertizing rule conflicts with language ''%s'' of phrase set ''%s''', _lang_name, _aps_lang_name, aps_name));
  _ap_chksum := ap_phrase_chksum (_text, _lang_name);
whenever not found goto phrase_nf;
  select AP_LINK_DATA into old_data from DB.DBA.SYS_ANN_PHRASE where AP_APS_ID = _aps_id and AP_CHKSUM=_ap_chksum and AP_TEXT = _text;
  if (not isarray (old_data))
    {
      res := -9;
      goto phrase_done;
    }
  if (mod (length (old_data), 2))
    {
      res := -9;
      goto phrase_done;
    }
  old_al_idx := position ('AL', old_data, 1, 2);
  if (0 = old_al_idx)
    {
      res := -1;
      goto phrase_done;
    }
  old_al := aref_set_0 (old_data, old_al_idx);
  if (mod (length (old_al), 3))
    {
      res := -1;
      goto phrase_done;
    }
  pos_to_del := position (_al_id, old_al, 1, 3);
  if (0 = pos_to_del)
    {
      old_data [old_al_idx] := old_al;
      res := -1;
      goto phrase_done;
    }
  if (length (old_al) > 3)
    {
      old_al := vector_concat (subseq (old_al, 0, pos_to_del - 1), subseq (old_al, pos_to_del + 2));
      old_data [old_al_idx] := old_al;
    }
  else
    {
      if (length (old_data) > 2)
        old_data := vector_concat (subseq (old_data, 0, old_al_idx - 1), subseq (old_data, old_al_idx + 1));
      else
        {
	  ap_add_phrases (_aps_id, vector (vector (_text)));
	  res := 0;
	  goto phrase_done;
        }
    }
  ap_add_phrases (_aps_id, vector (vector (_text, old_data)));
  res := 0;
  goto phrase_done;

phrase_nf:
  res := -1;

phrase_done:
  delete from DB.DBA.SYS_ANN_AD_RULE where (AAR_AAA_ID = _aaa_id) and (AAR_APS_ID = _aps_id) and (AAR_AP_CHKSUM = _ap_chksum) and (AAR_TEXT = _text) and (AAR_AL_ID = _al_id);
  commit work;
  return res;
}
;

create procedure DB.DBA.ANN_ZAP ()
{
  declare _aps_id, _prev_aps_id integer;
  declare _text, _prev_text varchar;
  whenever not found goto phrase_nf;
  _prev_aps_id := -1;
  _prev_text := '';

next_phrase:
  select AP_APS_ID, AP_TEXT into _aps_id, _text from DB.DBA.SYS_ANN_PHRASE;
  if ((_aps_id = _prev_aps_id) and (_text = _prev_text))
    signal ('OBLOM', sprintf ('Unable to remove phrase ''%s'' of set %d', _text, _aps_id));
  ap_add_phrases (_aps_id, vector (vector (_text)));
  _prev_aps_id := _aps_id;
  _prev_text := _text;
  goto next_phrase;

phrase_nf:
  delete from DB.DBA.SYS_ANN_AD_RULE;
  delete from DB.DBA.SYS_ANN_LINK;
  delete from DB.DBA.SYS_ANN_AD_ACCOUNT;
  delete from DB.DBA.SYS_ANN_PHRASE_SET;
  delete from DB.DBA.SYS_ANN_PHRASE_CLASS;
  commit work;
}
;

AP_EXEC_NO_ERROR ('DB.DBA.ANN_BOOT()')
;
