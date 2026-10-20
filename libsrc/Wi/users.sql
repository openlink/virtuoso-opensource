--
--  Unified user model
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2026 OpenLink Software
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

-- from ddlrun.c
--create table SYS_ROLE_GRANTS (
--      GI_SUPER 	integer, -- references SYS_DAV_GROUP (G_ID),
--    	GI_SUB 		integer, -- references SYS_DAV_GROUP (G_ID),
--	GI_DIRECT	integer default 1,
--	GI_GRANT	integer,
--	GI_ADMIN	integer default 0,
--	primary key 	(GI_SUPER, GI_SUB, GI_DIRECT))
--;

create view SYS_USER_GROUP (UG_UID, UG_GID) as select GI_SUPER, GI_SUB
 	from SYS_ROLE_GRANTS where GI_DIRECT = 1
;

create trigger SYS_ROLE_GRANTS_REVOKE after delete on SYS_ROLE_GRANTS referencing old as O
{
   declare super, sub, grantor integer;

   super := O.GI_SUPER;
   sub := O.GI_SUB;
   grantor := O.GI_GRANT;
   if (not exists (select 1 from SYS_ROLE_GRANTS
	 where GI_SUPER = super and GI_GRANT <> grantor and GI_SUB = sub))
     {
       if (exists (select 1 from SYS_USERS where U_ID = super and U_SQL_ENABLE)
          and
	  exists (select 1 from SYS_USERS where U_ID = sub and U_SQL_ENABLE))
         sec_revoke_user_role (super, sub);
     }
   delete from SYS_ROLE_GRANTS where GI_GRANT = super and GI_SUB = sub;

}
;

create trigger SYS_ROLE_GRANTS_GRANT after insert on SYS_ROLE_GRANTS referencing new as N
{
   -- if (N.GI_ADMIN = 0)
   --  return;
   for select GI_SUPER, GI_SUB, GI_GRANT, GI_DIRECT, GI_ADMIN from SYS_ROLE_GRANTS
       where GI_SUB = N.GI_SUPER do
        {
	  insert into SYS_ROLE_GRANTS (GI_SUPER, GI_SUB, GI_GRANT, GI_DIRECT, GI_ADMIN)
	      values (GI_SUPER, N.GI_SUB, GI_GRANT, 0, GI_ADMIN);
	  if (exists (select 1 from SYS_USERS where U_ID = N.GI_SUB and U_SQL_ENABLE)
	      and
	      exists (select 1 from SYS_USERS where U_ID = GI_SUPER and U_SQL_ENABLE))
	    sec_grant_user_role (GI_SUPER, N.GI_SUB);
	}
}
;

-- TODO: update memory representation
create trigger SYS_PRIMARY_GROUP_NULLIFY after delete on SYS_USERS referencing old as O
{
  declare gid integer;
  declare opts, keys any;
  declare i, l int;

  gid := O.U_ID;
  update SYS_USERS set U_GROUP = U_ID where U_GROUP = gid;
  delete from SYS_ROLE_GRANTS where GI_SUPER = gid or GI_SUB = gid or GI_GRANT = gid;

  -- User keys cleanup
  opts := O.U_OPTS;
  opts := deserialize (opts);
  if (not isarray (opts))
    return;

  keys := get_keyword_ucase ('KEYS', opts, NULL);
  if (keys is null)
    return;

  i := 0; l := length (keys);
  while (i < l)
    {
      if (keys[i] is not null and xenc_key_exists (keys[i]))
	xenc_key_remove (keys[i], 0);
      i := i + 2;
    }
}
;


-- The uniqueness rule is that names in U_NAME and G_NAME be globally
-- unique.  One name will not both designate a user and a group.
-- this is coming from the fact that all are in the SYS_USERS
-- A user or group(role) can be SQL enabled.
-- If so, there will be a row in SYS_USERS for it, whether it be a user or a group.
-- It being a group is seen by whether there is a row for it in SYS_DAV_GROUP view.
-- The identification is done by name.
--
-- PASSWORD 	- Depending on password mode, this can be
-- 		the pwd_magic_calc of the password with the user name or some other value
--		for use by the password mode hook.
-- PASSWORD_MODE - Function for checking a given password on SQL or DAV login.  See below.
-- PASSWORD_MODE_DATA - Application specific data for the Password Mode hook.
-- LOGIN_QUALIFIER - Default qualifier for SQL session
-- SQL_ENABLE - If set, there is an entry in SYS_USERS and a possible SQL login
-- DAV_ENABLE -
-- PRIMARY_GROUP - If this has the fixed dba role, this should appear as this primary group.
-- 		   Otherwise all group grants are insensitive to order.
--		   This is handled transparently by GRANT ROLE.
-- GET_PASSWORD  - Function that will retrieve the password.
--		   If not defined the password is assumed to be in the tables.
--		   This allows for custom encrypted storage of passwords etc.
--		   This is simpler to use than the check hook.
-- 		   Note that for schemes where the server never does know the passwords
--		   of user accounts, no digest based authentication schemes can be used,
--		   including the HTTP digest authentication, since the digests can't be
--		   checked without knowing the password.


-- for all below we need to call some sort of a BIFs in order to set-up the user hash
-- these are DBA only functions

create procedure
GET_SEC_OBJECT_ID (in _name varchar, out id integer, out is_sql integer, out opts any)
{
  if (0 = casemode_strcmp (_name, 'PUBLIC'))
    {
      id := 1;
      is_sql := 1;
      opts := vector ();
      return;
    }

  declare _u_full_name, _u_e_mail, _u_home, _u_perms, _pwd_mode, _pwd_mode_data,
          _login_qual, _sql_enable, _dav_enable, _get_pwd, _u_group, _is_role, _disabled any;
  declare inl_opts any;
  whenever not found goto nf;
  select U_ID, U_SQL_ENABLE, deserialize(blob_to_string (U_OPTS)), U_DAV_ENABLE, U_FULL_NAME, U_E_MAIL,
         U_GROUP, U_DEF_PERMS, U_PASSWORD_HOOK,
	 U_PASSWORD_HOOK_DATA, U_GET_PASSWORD, U_DEF_QUAL, U_HOME, U_IS_ROLE, U_ACCOUNT_DISABLED
      into id, is_sql, opts, _dav_enable, _u_full_name, _u_e_mail,
	 _u_group, _u_perms, _pwd_mode,
	 _pwd_mode_data, _get_pwd, _login_qual, _u_home, _is_role, _disabled
      from SYS_USERS where U_NAME = _name;

  if (not isarray(opts))
    opts := vector ();

  if (_login_qual like 'Q %')
    _login_qual := subseq (_login_qual, 2);
  inl_opts := vector (
		'PASSWORD_MODE', _pwd_mode,
		'PASSWORD_MODE_DATA', _pwd_mode_data,
		'GET_PASSWORD', _get_pwd,
		'SQL_ENABLE', is_sql,
		'DAV_ENABLE', _dav_enable,
		'LOGIN_QUALIFIER', _login_qual,
		'PRIMARY_GROUP', _u_group,
		'E-MAIL', _u_e_mail,
		'FULL_NAME', _u_full_name,
		'HOME', _u_home,
		'PERMISSIONS', _u_perms,
		'DISABLED', _disabled);

  opts := vector_concat (opts, inl_opts);

  return;
nf:
  signal ('42000', sprintf ('The object "%s" does not exist.', _name), 'U0002');
}
;

create procedure DB.DBA.SECURITY_CL_EXEC_AND_LOG (in txt varchar, in args any)
{
  if (user <> 'dba' ) set_user_id ('dba');
  cl_exec (txt, args);
  cl_exec ('log_text_array (?, ?)', vector (txt, args), 1);
}
;

create procedure DB.DBA.USER_CREATE (in _name varchar, in passwd varchar, in options any := NULL)
{
  declare _pwd, _pwd_mode, _pwd_mode_data, _login_qual varchar;
  declare _dav_enable, _sql_enable integer;
  declare _prim_group, _get_pwd varchar;
  declare _u_id, _prim_group_id, _disabled integer;
  declare _u_full_name, _u_e_mail, _u_home, _u_perms varchar;
  declare  _u_sys_name, _u_sys_pass, _u_sec_sys_name, _u_sec_sys_pass varchar;

  if (length (_name) < 1)
    signal ('22023', concat ('The user name cannot be empty'), 'U0003');

  -- XXX: signal if user exists

  if (options is null)
    options := vector ();

  {
    declare i, l integer;
    declare new_opts any;
    declare exit handler for sqlstate '2202*' {
      signal (__SQL_STATE, sprintf ('The options parameter must be an array of name/value pairs'), 'U0004');
    };
    _pwd_mode := get_keyword_ucase ('PASSWORD_MODE', options, NULL);
    _pwd_mode_data := get_keyword_ucase ('PASSWORD_MODE_DATA', options, NULL);
    _get_pwd := get_keyword_ucase ('GET_PASSWORD', options, NULL);
    _sql_enable := cast (get_keyword_ucase ('SQL_ENABLE', options, 1) as integer);
    _dav_enable := cast (get_keyword_ucase ('DAV_ENABLE', options, 0) as integer);
    _login_qual := get_keyword_ucase ('LOGIN_QUALIFIER', options, 'DB');
    _prim_group := get_keyword_ucase ('PRIMARY_GROUP', options, NULL);

    _u_e_mail := coalesce (get_keyword_ucase ('E-MAIL', options), get_keyword_ucase ('E_MAIL', options, ''));
    _u_full_name := get_keyword_ucase ('FULL_NAME', options, NULL);
    _u_home := get_keyword_ucase ('HOME', options, NULL);
    _u_perms := get_keyword_ucase ('PERMISSIONS', options, '110100000R');
    _disabled := get_keyword_ucase ('DISABLED', options, 0);

    _u_sec_sys_name := get_keyword_ucase ('SYSTEM_UNAME', options, NULL);
    _u_sec_sys_pass := get_keyword_ucase ('SYSTEM_UPASS', options, NULL);

    i := 0; l := length (options);
    new_opts := vector ();
    while (i < l)
      {
	if (upper(options[i]) not in ('PASSWORD_MODE', 'PASSWORD_MODE_DATA', 'GET_PASSWORD', 'SQL_ENABLE', 'DAV_ENABLE', 'LOGIN_QUALIFIER', 'PRIMARY_GROUP', 'E-MAIL', 'E_MAIL', 'FULL_NAME', 'HOME', 'PERMISSIONS', 'DISABLED'))
	  {
            new_opts := vector_concat (new_opts, vector (options[i], options[i+1]));
	  }
        i := i + 2;
      }
  }
  if (_login_qual = '')
    signal ('22023', 'Qualifier cannot be empty string');

  if (__tag of NVARCHAR = __tag (passwd))
    passwd := charset_recode (passwd, '_WIDE_', 'UTF-8');

  _pwd := pwd_magic_calc (_name, passwd, 0);
  _u_sys_name := pwd_magic_calc (_name, _u_sec_sys_name, 0);
  _u_sys_pass := pwd_magic_calc (_name, _u_sec_sys_pass, 0);

  _u_id := coalesce ((select U_ID from SYS_USERS where U_NAME = _name),
	     (select max(U_ID) from SYS_USERS) + 1);

  if (_u_id < 100)
    _u_id := 100;

  if (isstring (_prim_group))
    _prim_group_id := coalesce ((select U_ID from SYS_USERS where U_NAME = _prim_group), NULL);
  else if (isinteger (_prim_group))
    _prim_group_id := cast (_prim_group as integer);
  else
    _prim_group_id := _u_id;

  insert replacing SYS_USERS (U_ID, U_NAME, U_PASSWORD, U_GROUP, U_FULL_NAME, U_E_MAIL,
      			         U_ACCOUNT_DISABLED, U_DAV_ENABLE, U_SQL_ENABLE, U_DATA, U_OPTS,
				 U_PASSWORD_HOOK, U_PASSWORD_HOOK_DATA, U_GET_PASSWORD, U_DEF_QUAL,
				 U_HOME, U_DEF_PERMS)
  	 values (_u_id, _name, _pwd, _prim_group_id, _u_full_name, _u_e_mail, _disabled, _dav_enable, _sql_enable,
	         concat ('Q ', _login_qual), serialize (options),
		 _pwd_mode, _pwd_mode_data, _get_pwd, _login_qual,
		 _u_home, _u_perms);

  if (not _sql_enable) /* pure web accounts must be disabled for odbc/sql login */
    {
      _disabled := 1;
    }
      DB.DBA.SECURITY_CL_EXEC_AND_LOG ('sec_set_user_struct (?,?,?,?,?,?,?)', vector (
	  _name, passwd, _u_id, _prim_group_id, concat ('Q ', _login_qual), 0, _u_sys_name, _u_sys_pass ) );
      if (_disabled = 1)
        {
      DB.DBA.SECURITY_CL_EXEC_AND_LOG ('sec_user_enable (?, ?)', vector (_name, 0));
    }

  return _u_id;
}
;

-- XXX: check if exists
create procedure
USER_ROLE_CREATE (in _name varchar, in is_dav integer := 0)
{
  declare _g_id integer;
  declare _sql_enable integer;
  if (length (_name) < 1)
    signal ('22023', concat ('The role name cannot be empty'), 'U0005');
  if (exists (select 1 from SYS_USERS where U_NAME = _name))
    signal ('37000', concat ('The object ''', _name, ''' already exists'), 'U0006');
  _g_id := (select max(U_ID) from SYS_USERS) + 1;
  if (_g_id < 100)
    _g_id := 100;
  _sql_enable := 1;
  if (is_dav)
    _sql_enable := 0;
  insert into SYS_USERS (U_ID, U_NAME, U_GROUP, U_IS_ROLE, U_DAV_ENABLE, U_SQL_ENABLE) values (_g_id, _name, _g_id, 1, is_dav, _sql_enable);
  DB.DBA.SECURITY_CL_EXEC_AND_LOG ('sec_set_user_struct (?,?,?,?,?,?)', vector (_name, '', _g_id, _g_id, NULL, 1) );
  return _g_id;
}
;

create procedure
USER_ROLE_DROP (in _name varchar)
{
  declare _u_id, _u_is_sql integer;
  declare opts any;
  GET_SEC_OBJECT_ID (_name, _u_id, _u_is_sql, opts);
  delete from SYS_USERS where U_NAME = _name and U_IS_ROLE = 1;
  if (not row_count())
    signal ('37000', concat ('The role ''', _name, ''' does not exist'), 'U0007');
  -- remove all grants direct or indirect
  delete from SYS_ROLE_GRANTS where GI_SUPER = _u_id or GI_SUB = _u_id or GI_GRANT = _u_id;
  delete from SYS_GRANTS where G_USER = _u_id;
  if (_u_is_sql)
    DB.DBA.SECURITY_CL_EXEC_AND_LOG ('sec_remove_user_struct(?)', vector (_name));
}
;

create procedure
USER_CHANGE_PASSWORD (in _name varchar, in old_pwd varchar, in new_pwd varchar)
{
  if (__tag of NVARCHAR = __tag (old_pwd))
    old_pwd := charset_recode (old_pwd, '_WIDE_', 'UTF-8');
  if (__tag of NVARCHAR = __tag (new_pwd))
    new_pwd := charset_recode (new_pwd, '_WIDE_', 'UTF-8');
  if (exists (select 1 from SYS_USERS where U_NAME = _name and U_IS_ROLE = 0 and pwd_magic_calc (U_NAME, U_PASSWORD, 1) = old_pwd))
    {
      if (exists (select 1 from SYS_USERS where U_NAME = _name and U_SQL_ENABLE = 1))
      	USER_SET_PASSWORD (_name, new_pwd);
      else
	{
	  update SYS_USERS set U_PASSWORD = pwd_magic_calc (_name, new_pwd) where U_NAME = _name;
        }
    }
  else if (exists (select 1 from SYS_USERS where U_NAME = _name and U_IS_ROLE = 0))
    signal ('42000', concat ('The old password for ''', _name, ''' does not match'), 'U0008');
  else
    signal ('37000', concat ('The user ''', _name, ''' does not exist'), 'U0009');
}
;

create procedure USER_PASSWORD_SET (in name varchar, in passwd varchar)
{
  declare _u_id, _u_group integer;
  declare _u_data varchar;
  if (__tag of NVARCHAR = __tag (passwd))
    passwd := charset_recode (passwd, '_WIDE_', 'UTF-8');
  if (exists (select 1 from SYS_USERS where U_NAME = name and U_SQL_ENABLE = 1))
    {
      user_set_password (name, passwd);
      return 0;
    }
  select U_ID, U_GROUP into _u_id, _u_group from DB.DBA.SYS_USERS where U_NAME = USER;
  if (not (_u_id = 0 or _u_group = 0))
    signal ('42000', 'Function DB.DBA.USER_PASSWORD_SET() is restricted to DBA group', 'SR285:SECURITY');
  if (not exists (select 1 from DB.DBA.SYS_USERS where U_NAME = name and U_DAV_ENABLE = 1 and U_IS_ROLE = 0))
    signal ('42000', concat ('The user ''', name, ''' does not exist'), 'SR286');
  if (not isstring (passwd) or length (passwd) < 1)
    signal ('42000', concat ('The new password for ''', name, ''' cannot be empty'), 'SR287');
  update DB.DBA.SYS_USERS set U_PASSWORD = pwd_magic_calc (name, passwd) where U_NAME = name;
  return 0;
}
;

create procedure
USER_SET_QUALIFIER (in _name varchar, in qual varchar)
{
  if (exists (select 1 from SYS_USERS where U_NAME = _name and U_IS_ROLE = 0))
    {
      if (not length (qual))
	signal ('22023', 'Qualifier cannot be empty string');
      update DB.DBA.SYS_USERS set U_DATA = concatenate ('Q ', qual), U_DEF_QUAL = qual where U_NAME = _name;
      DB.DBA.SECURITY_CL_EXEC_AND_LOG ('sec_set_user_data(?,?)', vector (_name, concatenate ('Q ', qual)));
    }
  else
    {
      signal ('37000', concat ('The user ''', _name, ''' does not exist'), 'U0010');
    }
}
;

-- this is to set the role for current session
create procedure
USER_SET_ROLE (in _name varchar, in new_role varchar)
{
  signal ('42000', 'Not implemented.');
}
;

create procedure
GET_INHERITED_GRANTS (in g_id integer, in prim integer, inout inh any)
{
  for select GI_SUB from SYS_ROLE_GRANTS where GI_SUPER = g_id and GI_DIRECT = 1
    do
      {
	-- check to not have cycles
	if (GI_SUB <> prim)
	  {
	    if (not position (GI_SUB, inh))
	      inh := vector_concat (inh, vector (GI_SUB));
	    GET_INHERITED_GRANTS (GI_SUB, prim, inh);
	  }
	else
	  {
	    signal ('42000', sprintf ('Circular role grant detected'), 'U0011');
	  }
      }
}
;

-- check if already assigned and the role is role, not user
create procedure
USER_GRANT_ROLE (in _name varchar, in _role varchar, in grant_opt integer := 0)
{
  declare _u_id, _g_id, _u_is_sql, _g_is_sql, primary_group integer;
  declare opts, inh any;
  GET_SEC_OBJECT_ID (_name, _u_id, _u_is_sql, opts);
  GET_SEC_OBJECT_ID (_role, _g_id, _g_is_sql, opts);
  primary_group := USER_GET_OPTION (_name, 'PRIMARY_GROUP');
  if (_u_id = _g_id)
    {
      signal ('42000', sprintf ('Circular role grant detected'), 'U0011');
    }

  if (not exists (select 1 from SYS_USERS where U_NAME = _role and U_IS_ROLE = 1))
    {
	signal ('37000', sprintf ('Role "%s" does not exist', _role), 'U0012');
    }
  if (_g_id = http_nobody_uid () or _g_id = http_nogroup_gid ())
    {
	signal ('37000', sprintf ('System role "%s" cannot be granted to "%s"', _role, _name), 'U0013');
    }
  if (_u_id = http_nobody_uid () or _u_id = http_nogroup_gid ())
    {
	signal ('37000', sprintf ('Role "%s" cannot be granted to special account "%s"', _role, _name), 'U0014');
    }

    {
      declare i, l integer;
      declare exit handler for sqlstate '23000' {
	signal ('42000', sprintf ('The object "%s" already have role "%s" assigned', _name, _role), 'U0013');
      };
      inh := vector ();
      GET_INHERITED_GRANTS (_g_id, _g_id, inh);
      if (position (_u_id, inh))
	{
	  signal ('42000', sprintf ('Circular role grant detected'), 'U0011');
	}
      insert into SYS_ROLE_GRANTS (GI_SUPER, GI_SUB, GI_ADMIN, GI_DIRECT, GI_GRANT)
	  values (_u_id, _g_id, grant_opt, 1, _g_id);
      i := 0; l := length (inh);
      while (i < l)
        {
	  if (primary_group is null or inh[i] <> primary_group)
	    {
	      insert soft SYS_ROLE_GRANTS (GI_SUPER, GI_SUB, GI_ADMIN, GI_DIRECT, GI_GRANT)
		  values (_u_id, inh[i], grant_opt, 0, _g_id);
	    }
          i := i + 1;
	}
      if (_u_is_sql)
	{
	  for select distinct rg.GI_SUB as GI_SUB from SYS_ROLE_GRANTS as rg, SYS_USERS as u where
	    rg.GI_SUPER = _u_id and rg.GI_GRANT = _g_id and u.U_ID = GI_SUB and u.U_SQL_ENABLE
	    do
	      {
		DB.DBA.SECURITY_CL_EXEC_AND_LOG ('sec_grant_user_role (?,?)', vector (_u_id, GI_SUB));
	      }
	}
    }
}
;

create procedure
USER_REVOKE_ROLE (in _name varchar, in _role varchar)
{
  declare _u_id, _g_id, _u_is_sql, _g_is_sql integer;
  declare opts any;
  GET_SEC_OBJECT_ID (_name, _u_id, _u_is_sql, opts);
  GET_SEC_OBJECT_ID (_role, _g_id, _g_is_sql, opts);
  if ((_g_id = http_nogroup_gid () and _u_id = http_nobody_uid ()) or (_g_id = http_admin_gid() and _u_id = http_dav_uid()))
    {
      signal ('37000', sprintf ('Built-in role "%s" cannot be revoked from built-in user "%s"', _role, _name), 'U0015');
    }
  for select distinct GI_SUB as sub from SYS_ROLE_GRANTS where
    GI_SUPER = _u_id and GI_GRANT = _g_id
	do
	  {
	    declare gra integer;
            gra := _g_id;
            if (not exists (select 1 from SYS_ROLE_GRANTS
		  where GI_SUPER = _u_id and GI_GRANT <> gra and GI_SUB = sub))
	      {
		if (_u_is_sql and
		  exists (select 1 from SYS_USERS where U_ID = sub and U_SQL_ENABLE) )
		  DB.DBA.SECURITY_CL_EXEC_AND_LOG ('sec_revoke_user_role (?,?)', vector (_u_id, sub));
	      }
	  }


  delete from SYS_ROLE_GRANTS where GI_SUPER = _u_id and GI_GRANT = _g_id;
  if (not row_count ())
    signal ('42000', concat ('The user ''', _name, ''' does not have granted role "', _role, '".'), 'U0014');

  -- Keep integrity on other roles/users in separate trigger
  -- all that are granted by this should be revoked
}
;


create procedure
USER_DROP (in _name varchar, in _cascade integer := 0)
{
  if (_cascade)
    {
      declare _tables, _udts any;
      _tables := DB.DBA.__DDL_GET_DROP_USER_TABLES (_name);
      _udts := __ddl_udt_get_udt_list_by_user (_name);

      -- procedures/modules
      FOR select P_NAME, P_TYPE from DB.DBA.SYS_PROCEDURES where P_OWNER = _name do
	{
	  if (P_TYPE = 3)
	    {
	      exec (sprintf ('drop module "%I"."%I"."%I"',
		    name_part (P_NAME, 0), name_part (P_NAME, 1), name_part (P_NAME, 2)));
	    }
	  else
	    {
	      exec (sprintf ('drop procedure "%I"."%I"."%I"',
		    name_part (P_NAME, 0), name_part (P_NAME, 1), name_part (P_NAME, 2)));
	    }
	}
      declare _inx integer;
      -- tables
      _inx := 0;
      while (_inx < length (_tables))
        {
          exec (sprintf ('drop table "%I"."%I"."%I"',
               name_part (_tables[_inx], 0), name_part (_tables[_inx], 1), name_part (_tables[_inx], 2)));
	  _inx := _inx + 2;
	}

      -- udts
      _inx := 0;
      while (_inx < length (_udts))
        {
          exec (sprintf ('drop type "%I"."%I"."%I"',
               name_part (_udts[_inx], 0), name_part (_udts[_inx], 1), name_part (_udts[_inx], 2)));
	  _inx := _inx + 2;
	}
    }
  declare _u_id, _u_is_sql integer;
  declare opts any;
  GET_SEC_OBJECT_ID (_name, _u_id, _u_is_sql, opts);
  delete from SYS_USERS where U_NAME = _name and U_IS_ROLE = 0;
  if (not row_count ())
    signal ('37000', concat ('The user ''', _name, ''' does not exist'), 'U0015');
  delete from SYS_USER_GROUP where UG_UID = _u_id;
  delete from SYS_GRANTS where G_USER = _u_id;
  delete from DB.DBA.RDF_GRAPH_USER where RGU_USER_ID = _u_id;
  if (_u_is_sql)
    DB.DBA.SECURITY_CL_EXEC_AND_LOG ('sec_remove_user_struct(?)', vector (_name));
}
;

create procedure
USER_SET_OPTION (in _name varchar, in opt varchar, in value any)
{
  declare _u_id, _u_is_sql integer;
  declare opts, passwd any;

  declare _u_full_name, _u_e_mail, _u_home, _u_perms, _pwd_mode, _pwd_mode_data,
          _login_qual, _sql_enable, _dav_enable, _get_pwd, _u_group, _u_group_id, _disabled any;

  GET_SEC_OBJECT_ID (_name, _u_id, _u_is_sql, opts);
  if (position (opt, opts))
    {
      aset (opts, position (opt, opts), value);
    }
  else
    {
      opts := vector_concat (opts, vector (opt, value));
    }

  _pwd_mode := get_keyword_ucase ('PASSWORD_MODE', opts, NULL);
  _pwd_mode_data := get_keyword_ucase ('PASSWORD_MODE_DATA', opts, NULL);
  _get_pwd := get_keyword_ucase ('GET_PASSWORD', opts, NULL);
  _sql_enable := get_keyword_ucase ('SQL_ENABLE', opts, 1);
  _dav_enable := get_keyword_ucase ('DAV_ENABLE', opts, 0);
  _login_qual := get_keyword_ucase ('LOGIN_QUALIFIER', opts, 'DB');
  _u_group := get_keyword_ucase ('PRIMARY_GROUP', opts, NULL); -- this must be ID, not name
  _u_e_mail := get_keyword_ucase ('E-MAIL', opts, '');
  _u_full_name := get_keyword_ucase ('FULL_NAME', opts, NULL);
  _u_home := get_keyword_ucase ('HOME', opts, NULL);
  _u_perms := get_keyword_ucase ('PERMISSIONS', opts, '110100000R');
  _disabled := get_keyword_ucase ('DISABLED', opts, 0);

  if (isstring (_u_group))
    _u_group_id := coalesce ((select U_ID from SYS_USERS where U_NAME = _u_group), NULL);
  else if (isinteger (_u_group))
    _u_group_id := _u_group;
  else
    _u_group_id := _u_id;

  -- cleanup the predefined
  {
    declare i, l int;
    declare ret any;
    ret := vector ();
    i := 0; l := length (opts);
    while (i < l)
      {
	if (upper(opts[i]) not in ('PASSWORD_MODE', 'PASSWORD_MODE_DATA', 'GET_PASSWORD', 'SQL_ENABLE', 'DAV_ENABLE', 'LOGIN_QUALIFIER', 'PRIMARY_GROUP', 'E-MAIL', 'FULL_NAME', 'HOME', 'PERMISSIONS', 'DISABLED'))
	  {
            ret := vector_concat (ret, vector (opts[i], opts[i+1]));
	  }
        i := i + 2;
      }
    opts := ret;
  }

  _login_qual := case when length (_login_qual) then concat ('Q ', _login_qual) else NULL end;
  update SYS_USERS set U_OPTS = serialize (opts),
      U_PASSWORD_HOOK = _pwd_mode,
      U_PASSWORD_HOOK_DATA = _pwd_mode_data,
      U_GET_PASSWORD = _get_pwd,
      U_SQL_ENABLE = _sql_enable,
      U_DAV_ENABLE = _dav_enable,
      U_DEF_QUAL = _login_qual,
      U_DATA = _login_qual,
      U_GROUP = _u_group_id,
      U_E_MAIL = _u_e_mail,
      U_FULL_NAME = _u_full_name,
      U_HOME = _u_home,
      U_DEF_PERMS = _u_perms,
      U_ACCOUNT_DISABLED = _disabled
      where U_NAME = _name;

  if (not _sql_enable) /* pure web accounts must be disabled for odbc/sql login */
    {
      _disabled := 1;
    }
      select pwd_magic_calc (U_NAME, U_PASSWORD, 1) into passwd from SYS_USERS where U_NAME = _name;
      DB.DBA.SECURITY_CL_EXEC_AND_LOG ('sec_set_user_struct (?,?,?,?,?)',
      vector (_name, passwd, _u_id, _u_group_id,
	case when length (_login_qual) then concat ('Q ', _login_qual) else NULL end));
  DB.DBA.SECURITY_CL_EXEC_AND_LOG ('sec_user_enable (?, ?)', vector (_name, case when _disabled = 0 then 1 else 0 end));
}
;


create procedure
USER_GET_OPTION (in _name varchar, in opt varchar)
{
  declare _u_id, _u_is_sql integer;
  declare opts any;
  GET_SEC_OBJECT_ID (_name, _u_id, _u_is_sql, opts);
  return get_keyword_ucase (upper (opt), opts, NULL);
}
;

-- the _MGR_ functions are not clear ....
create procedure
USER_MGR_SET_OPTION (in opt varchar, in val varchar)
{
  signal ('42000', 'Not implemented.');
}
;


create procedure
USER_MGR_GET_OPTION (in opt varchar) returns varchar
{
  signal ('42000', 'Not implemented.');
}
;


-- this function is used to crate a user before login , if it's a
-- from LDAP server etc. Hence it's user-defined one
-- Here is a prototype
--create procedure
--USER_FIND (in _name varchar)
--{
--  signal ('42000', 'Not implemented.');
--}
--;

create procedure
LIST_USER_ROLE_GRANTS ()
{
  declare arr, rarr any;
  declare i, l integer;
  declare j, k integer;
  declare name, rolen varchar;
  arr := list_role_grants ();
  i := 0; l := length (arr);
  result_names (name, rolen);
  while (i < l)
    {
      name := arr[i];
      rarr := arr[i+1];
      j := 0; k := length (rarr);
      rolen := '';
      while (j < k)
        {
	  if (j > 0)
	    rolen := concat (rolen, ',');
          rolen := concat (rolen, ' ', rarr[j]);
          j := j + 1;
	}
      result (name, rolen);
      i := i + 2;
    }
}
;

create procedure
USER_KEY_IS_FILE (in f varchar, out path varchar)
{
  declare hinfo any;
  if (f is null)
    return 0;
  hinfo := rfc1808_parse_uri (f);
  if (lower(hinfo[0]) = 'file')
    {
      path := hinfo[2];
      return 1;
    }
  else
    return 0;
}
;

-- XXX: how about passwd encryption ?
create procedure
USER_KEY_STORE (in username varchar, in key_name varchar, in key_type varchar, in key_format varchar, in key_passwd varchar, in key_value varchar := NULL)
{
  declare keys, path any;
  declare inx int;

  if (USER_KEY_IS_FILE (key_name, path)) -- XXX: rather we need the original content
    key_value := NULL;
  else if (key_value is null)
    {
      key_value := xenc_key_serialize (key_name);
      if (key_value is null)
	key_value := xenc_key_serialize (key_name, 1);
      if (key_value is null)
	signal ('22023', 'Cannot serialize the key');
    }

  keys := coalesce (USER_GET_OPTION (username, 'KEYS'), vector ());
  inx := position (key_name, keys);
  if (inx > 0)
    aset (keys, inx, vector (key_type, key_format, key_value, key_passwd));
  else
    keys := vector_concat (keys, vector (key_name, vector (key_type, key_format, key_value, key_passwd)));
  USER_SET_OPTION (username, 'KEYS', keys);
}
;

--!AWK PUBLIC
create procedure
USER_KEY_DELETE (in username varchar, in key_name varchar)
{
  declare keys any;
  declare inx int;
  if (lower(user) <> 'dba' and username <> user)
    signal ('42000', 'Cannot delete non own keys');
  keys := coalesce (USER_GET_OPTION (username, 'KEYS'), vector ());
  inx := position (key_name, keys);
  if (inx > 0)
    {
      -- we'll set to NULL for now
      aset (keys, inx, NULL);
      aset (keys, inx - 1, NULL);
      USER_SET_OPTION (username, 'KEYS', keys);
    }
}
;

-- the startup procedure
create procedure
USER_KEYS_INIT (in username varchar, in opts any)
{
  declare i, l, fmt, debug, u_id int;
  declare keys, path, key_value, key_type, key_passwd, key_pkey, os_u_name, os_u_pass any;
  declare certs any;

  debug := 0;

  opts := deserialize (blob_to_string (opts));

  __set_user_os_acount_int (username, NULL, NULL);

  if (not isarray (opts))
    return 0;

  keys := get_keyword_ucase ('KEYS', opts, NULL);
  certs := get_keyword_ucase ('LOGIN_CERTIFICATES', opts, NULL);
  os_u_name := get_keyword_ucase ('SYSTEM_UNAME', opts, NULL);
  os_u_pass := get_keyword_ucase ('SYSTEM_UPASS', opts, NULL);

  if (os_u_name is not NULL)
    {
      os_u_name := pwd_magic_calc (username, os_u_name, 0);
      os_u_pass := pwd_magic_calc (username, os_u_pass, 0);
      __set_user_os_acount_int (username, os_u_name, os_u_pass);
    }

  -- authentication certificates
  if (certs is not null)
    {
      l := length (certs); i := 0;
      while (i < l)
        {
          if (certs[i] is not null)
            sec_set_user_cert (username, certs [i]);
          i := i + 1;
        }
    }

  if (keys is null)
    return 0;

  if (debug) log_message ('XENC: Loading key for user : ' || username);

  l := length (keys); i := 0; key_pkey := null;
  while (i < l)
    {
      if (keys[i] is null)
	goto next;

      key_type := keys[i+1][0];
      fmt := keys[i+1][1];
      key_value := keys[i+1][2];
      key_passwd := keys[i+1][3];
      if (USER_KEY_IS_FILE (keys[i], path))
	{
	  if (isstring (file_stat (path)))
 	    key_value := file_to_string (path);
	  else
	    {
	      log_message (sprintf ('XENC: Cannot open key file: %s', path));
	      goto next;
	    }
	}

        {
	  declare exit handler for sqlstate '*' {
	    __pop_user_id ();
	    log_message ('XENC: ' || __SQL_MESSAGE);
	    goto next;
	  };
	  __set_user_id (username);
	  __USER_LOAD_KEY_BY_TYPE (keys[i], key_value, key_type, fmt, key_pkey, key_passwd);
	  __pop_user_id ();
	  if (debug) log_message ('XENC:   Loaded : ' || keys[i]);
        }
next:
      i := i + 2;
    }
 return 0;
}
;

create procedure
__USER_LOAD_KEY_BY_TYPE (inout key_name varchar, inout key_value any, inout key_type any, inout fmt int, inout key_pkey any, inout key_passwd any)
{
  if (key_type = '3DES')
    {
      -- the format is always DER, b64 encoded
      xenc_key_3DES_read (key_name, key_value);
    }
  else if (key_type = 'DSA')
    {
      xenc_key_DSA_read (key_name, key_value);
    }
  else if (key_type = 'RSA')
    {
      xenc_key_RSA_read (key_name, key_value);
    }
  else if (0 and key_type = 'AES') -- TODO: implement deserialization
    {
      ; -- xenc_key_AES_read
    }
  else if (key_type = 'X.509')
    {
      -- XXX: private key is in certificate
      xenc_key_create_cert (key_name, cast (key_value as varchar), key_type, fmt, NULL, key_passwd);
      xenc_set_primary_key (key_name);
    }
  else
    {
      signal ('22023', 'Unknown key type');
    }
}
;

--!AWK PUBLIC
create procedure
USER_KEY_LOAD (
    in key_name varchar,
    in key_value any,
    in key_type varchar,
    in key_format varchar,
    in key_passwd varchar := NULL,
    in key_pkey any := NULL,
    in store_pwd int := 0)
{
  declare path varchar;
  declare fmt any;
  declare cert varchar;

  if (USER_KEY_IS_FILE (key_name, path))
    key_value := file_to_string (path);

  fmt := case upper (key_format) when 'PEM' then 1 when 'PKCS12' then 2 when 'DER' then 3 else -1 end;

  key_type := upper (key_type);

  if (key_type = 'X.509')
    cert := key_value;
  else
    cert := NULL;

  __USER_LOAD_KEY_BY_TYPE (key_name, key_value, key_type, fmt, key_pkey, key_passwd);
  USER_KEY_STORE (user, key_name, key_type, fmt, case store_pwd when 1 then key_passwd else NULL end, cert);
}
;

create procedure
USER_CERT_REGISTER (in username varchar, in cert varchar, in pwd varchar := '', in coding varchar := 'PKCS12')
{
  declare certs, path, cfp, cfp_subject, cont any;
  declare inx, enc int;

  if (cert like '__:__:__:__:__:__:__:__:__:__:__:__:__:__:__:__%')
  {
    cfp := cert;
    cfp_subject := null;
  }
  else
  {
    if (USER_KEY_IS_FILE (cert, path))
    {
      cont := file_to_string (path);
    }
    else
    {
      cont := cert;
    }
    enc := case upper (coding) when 'PKCS12' then 2 when 'DER' then 1 when 'PEM' then 0 else 0 end;
    cfp := get_certificate_info (6, cont, enc, pwd);
    cfp_subject := get_certificate_info (2, cont, enc, pwd);
    if (cfp is null)
      signal ('22023', 'The certificate have been supplied is not valid or corrupted', 'U....');
  }

  -- add certificate
  certs := coalesce (USER_GET_OPTION (username, 'LOGIN_CERTIFICATES'), vector ());
  inx := position (cfp, certs);
  if (inx > 0)
    return;

  certs := vector_concat (certs, vector (cfp));
  USER_SET_OPTION (username, 'LOGIN_CERTIFICATES', certs);
  sec_set_user_cert (username, cfp);

  -- add certificate label
  if (isnull (cfp_subject))
    return;

  certs := coalesce (USER_GET_OPTION (username, 'LOGIN_CERTIFICATE_SUBJECTS'), vector ());
  if (get_keyword (cfp, certs) is not null)
    return;

  certs := vector_concat (certs, vector (cfp, cfp_subject));
  USER_SET_OPTION (username, 'LOGIN_CERTIFICATE_SUBJECTS', certs);
}
;

create procedure
USER_CERT_UNREGISTER (in username varchar, in cert varchar, in pwd varchar := '', in coding varchar := 'PKCS12')
{
  declare certs, new_certs, path, cfp, cont any;
  declare i, len, enc integer;

  if (cert like '__:__:__:__:__:__:__:__:__:__:__:__:__:__:__:__%')
  {
    cfp := cert;
  }
  else
  {
    if (USER_KEY_IS_FILE (cert, path))
    {
      cont := file_to_string (path);
    }
    else
    {
      cont := cert;
    }
    enc := case upper (coding) when 'PKCS12' then 2 when 'DER' then 1 when 'PEM' then 0 else 0 end;
    cfp := get_certificate_info (6, cont, enc, pwd);
    if (cfp is null)
      signal ('22023', 'The certificate have been supplied is not valid or corrupted', 'U....');
  }

  -- delete certificate
  new_certs := vector ();
  certs := coalesce (USER_GET_OPTION (username, 'LOGIN_CERTIFICATES'), vector ());
  len := length (certs);
  for (i := 0; i < len; i := i + 1)
  {
    if (cfp <> certs[i])
      new_certs := vector_concat (new_certs, vector (certs[i]));
  }
  USER_SET_OPTION (username, 'LOGIN_CERTIFICATES', new_certs);
  sec_remove_user_cert (username, cfp);

  -- delete certificate label
  certs := coalesce (USER_GET_OPTION (username, 'LOGIN_CERTIFICATE_SUBJECTS'), vector ());
  if (get_keyword (cfp, certs) is null)
    return;

  new_certs := vector ();
  len := length (certs);
  for (i := 0; i < len; i := i + 2)
  {
    if (cfp <> certs[i])
      new_certs := vector_concat (new_certs, vector (certs[i], certs[i+1]));
  }
  USER_SET_OPTION (username, 'LOGIN_CERTIFICATE_SUBJECTS', new_certs);
}
;

-- SQL login hook
create procedure
"DB"."DBA"."USER_CERT_LOGIN" (
    inout user_name varchar,
    in digest varchar,
    in session_random varchar)
{
  declare cn, fp, new_user, certs any;
  declare rc int;
  rc := -1;

  if (user_name = '' or user_name is null)
    {
      declare ext_oid varchar;
      declare exit handler for sqlstate '*' {
        goto cert_auth;
      };

      user_name := null;

	-- subject
	cn := get_certificate_info (2);
	-- fingerprint
	fp := get_certificate_info (6);

	if (fp is null)
	  goto cert_auth;

        ext_oid := virtuoso_ini_item_value ('Parameters', 'X509ExtensionOID');

        if (ext_oid is not null)
          new_user := get_certificate_info (7, null, null, null, ext_oid);
        else
          new_user := get_certificate_info (7);

        if (new_user is null)
	  new_user := sec_get_user_by_cert (fp);

	if (new_user is not null)
        certs := coalesce (USER_GET_OPTION (new_user, 'LOGIN_CERTIFICATES'), vector ());

	if (new_user is not null and position (fp, certs) > 0)
	  {
	    -- authenticated (name needs to be set)
	    user_name := new_user;
	    log_message (sprintf ('Certificate "%s" [%s] is used to identify user "%s"',
			 cn, fp, new_user));
	    rc := 1;
	  }
    }

  cert_auth:;


  -- normal verification (only if rc != 0 which means "no access")
normal_auth:
  if (rc <> 0)
    {
      if (__proc_exists ('DB.DBA.DBEV_LOGIN'))
	{
	  rc := "DB"."DBA"."DBEV_LOGIN" (user_name, digest, session_random);
	}
      else if (rc <= 0) -- only if not authenticated 
	{
	  rc := DB.DBA.FOAF_SSL_LOGIN (user_name, digest, session_random);
	  if (rc = 0)
	    rc := DB.DBA.LDAP_LOGIN (user_name, digest, session_random);
	}
    }
  if (user_name is null)
    user_name := '';
  return rc;
}
;

create procedure
SET_USER_OS_ACOUNT (in username varchar, in os_u_name varchar,
		    in os_u_pass varchar, in only_check_sys_user integer := 0)
{
  if (only_check_sys_user)
     return __set_user_os_acount_int (username, os_u_name, os_u_pass, only_check_sys_user);
  if (__set_user_os_acount_int (username, os_u_name, os_u_pass))
    {
	USER_SET_OPTION (username, 'SYSTEM_UNAME', pwd_magic_calc (username, os_u_name, 0));
	USER_SET_OPTION (username, 'SYSTEM_UPASS', pwd_magic_calc (username, os_u_pass, 0));
	return 1;
    }
  signal ('42000',
      concat ('Cannot login system user ', os_u_name, '. Logon failure: unknown user name or bad password.'),
      'SR359');
}
;

grant execute on "DB.DBA.SET_USER_OS_ACOUNT" to public
;

create procedure DB.DBA.__DDL_TABLE_FIND_DEPS (in tb varchar, inout deps any)
{
  declare tb_key_id integer;
  declare tb_owner varchar;

  if (get_keyword (tb, deps, 0) = 1)
    return;

  tb_owner := name_part (tb, 1);

  tb_key_id := NULL;
  select KEY_ID into tb_key_id from DB.DBA.SYS_KEYS
      where KEY_TABLE = tb and KEY_IS_MAIN = 1 and KEY_MIGRATE_TO is null;
  if (tb_key_id is NULL)
    signal ('42000',
	concat ('DB Schema inconsistency : Cannot find table "', tb, '" in DB.DBA.SYS_KEYS'),
	'SR355');

  for select SUB as _sub from DB.DBA.SYS_KEY_SUBKEY where SUPER = tb_key_id do
    {
      if (get_keyword (_sub, deps, 0) = 0)
	{
	  declare stb_name varchar;
	  declare new_deps any;

	  stb_name := NULL;
	  select KEY_TABLE into stb_name from DB.DBA.SYS_KEYS where KEY_ID = _sub;
	  if (stb_name is NULL)
	    signal ('42000',
		concat ('DB Schema inconsistency : Cannot key id "', _sub, '" in DB.DBA.SYS_KEYS'),
		'SR356');

	  if (name_part (stb_name, 1) <> tb_owner)
	    signal ('42000',
		concat ('cannot drop table "', tb, '" because table "', stb_name, '" references it'),
		'SR357');
	  if (stb_name <> tb)
	    {
	      DB.DBA.__DDL_TABLE_FIND_DEPS (stb_name, deps);
	    }
	}
    }

  for select FK_TABLE as _fk_table from DB.DBA.SYS_FOREIGN_KEYS
    where PK_TABLE = tb and FK_TABLE <> PK_TABLE do
    {
      if (get_keyword (_fk_table, deps, 0) = 0)
	{
	  if (name_part (_fk_table, 1) <> tb_owner)
	    signal ('42000',
		concat ('cannot drop table "', tb, '" because table "', _fk_table, '" references it'),
		'SR358');
          DB.DBA.__DDL_TABLE_FIND_DEPS (_fk_table, deps);
	}
    }
  if (get_keyword (tb, deps, 0) = 0)
    deps := vector_concat (deps, vector (tb, 1));
}
;


create procedure DB.DBA.__DDL_GET_DROP_USER_TABLES (in owner varchar)
{
  declare deps any;
  deps := vector ();

  for select distinct KEY_TABLE as tb from DB.DBA.SYS_KEYS where KEY_MIGRATE_TO is NULL
    and name_part (key_table, 1) = owner do
    {
      DB.DBA.__DDL_TABLE_FIND_DEPS (tb, deps);
    }

  return deps;
}
;


create procedure DB.DBA.__UPDATE_SOAP_USERS_ACCESS ()
{

   if (sequence_next ('DB.DBA.__UPDATE_SOAP_USERS_ACCESS') > 0)
     return;

   for (select U_NAME from SYS_USERS where U_NAME in ('Compound1', 'Compound2',
	'DocLit', 'DocPars', 'EmptySA', '_2PC', 'Import1', 'Import2', 'Import3', 'RpcEnc',
	'SOAP',	'XQ', 'interop4', 'BACKUP', 'interop4d', 'interop4h', 'interop4hcr',
	'interop4xsd', 'nterop4hcd', 'nterop4hsd', 'interop4hcd', 'interop4hsd', 'TestHeaders',
	'TestList') and U_NAME =  pwd_magic_calc (U_NAME, U_PASSWORD, 1) and U_ACCOUNT_DISABLED = 0) do
	   {
	     USER_SET_OPTION (U_NAME, 'DISABLED', 1);
	     log_message ('The login for account ' || U_NAME || ' is disabled.');
	   }

   for (select U_NAME from SYS_USERS where U_NAME in ('FORI', 'INTEROP') and U_ACCOUNT_DISABLED = 0) do
	   {
	     USER_SET_OPTION (U_NAME, 'DISABLED', 1);
	     log_message ('The login for account ' || U_NAME || ' is disabled.');
	   }

   if (exists (select 1 from DB.DBA.SYS_USERS where U_NAME = 'petshop'))
     {
       exec ('drop user petshop');
       log_message ('The user petshop is deleted.');
     }
}
;


DB.DBA.__UPDATE_SOAP_USERS_ACCESS ()
;

-- LDAP authentication

create table SYS_LDAP_SERVERS
(
  LS_ADDRESS varchar,
  LS_BASE varchar,
  LS_BIND_DN varchar,
  LS_ACCOUNT varchar,
  LS_PASSWORD varchar,
  LS_UID_FLD  varchar,
  LS_TRY_SSL int default 0,
  LS_LDAP_VERSION int default 2,
  primary key (LS_ADDRESS)
)
;

create procedure
DB.DBA.LDAP_LOGIN (inout user_name varchar, in digest varchar, in session_random varchar)
{
  declare result, uopt, pass, epwd any;

  WHENEVER SQLSTATE '28000' GOTO LDAP_VALIDATION_FAILURE;

  if (lcase(user_name) <> 'dba')
    {
      declare lserv, base, bind, lacc, lpwd, luid, ltry, lver, ltyp, upwd any;
      uopt := USER_GET_OPTION (user_name, 'LDAPServer');
      if (not isarray (uopt) or length (uopt) <> 2)
	return -1;

      lserv := uopt[0];
      ltyp := uopt[1];

      whenever not found goto LDAP_SERVER_REMOVED;
      select LS_BASE, LS_BIND_DN, LS_ACCOUNT, LS_PASSWORD, LS_UID_FLD, LS_TRY_SSL, LS_LDAP_VERSION
	  into base, bind, lacc, lpwd, luid, ltry, lver from SYS_LDAP_SERVERS where LS_ADDRESS = lserv;

      lpwd := pwd_magic_calc (lacc, lpwd, 1);

      if (is_http_ctx())
	{
          if (get_keyword ('authtype', session_random) = 'basic')
	    upwd := get_keyword ('pass', session_random);
	  else
	    return 0;
	}
      else
	{
	  epwd := sys_stat ('sql_encryption_on_password');
	  if (epwd = 0) -- the digest was supplied
	    return 0;
	  else if (epwd = 2) -- pwd magic calc
	    upwd := pwd_magic_calc(user_name, digest, 1);
	  else if (epwd = 1) -- clear text
	    upwd := digest;
	  else
	    return 0;
	}

      --dbg_printf ('Authentication via %s uid=[%s], pwd=[%s]', lserv, user_name, upwd);
      connection_set ('LDAP_VERSION', lver);

      if (ltyp = 0)
	{
          result := LDAP_SEARCH(lserv,
		ltry, base, sprintf ('(%s=%s)', luid, user_name),
		sprintf('%s=%s, %s', luid, user_name, bind),
                upwd);
          --dbg_obj_print(sprintf('ldap_search authenticates %s', user_name));
          return 1; -- verified
        }
      else if (ltyp = 1)
	{
	  declare ent any;
          result := LDAP_SEARCH(lserv,
		ltry, base, sprintf ('(%s=%s)', luid, user_name),
		sprintf('%s=%s, %s', luid, lacc, bind),
                lpwd);
          ent := get_keyword ('entry', result, vector ());
	  if (get_keyword (luid, ent) is not null)
	    {
	      --dbg_obj_print ('normal auth follow:', get_keyword (luid, ent));
	      return -1;
	    }
          return 0;
	}

    }

LDAP_SERVER_REMOVED:
  return -1;

LDAP_VALIDATION_FAILURE:
  return 0;
}
;

-- FOAF+SSL login
create table SYS_USER_WEBID (UW_U_NAME varchar, UW_WEBID varchar, primary key (UW_WEBID))
alter index SYS_USER_WEBID on SYS_USER_WEBID partition cluster replicated
create index SYS_USER_WEBID_NAME on SYS_USER_WEBID (UW_U_NAME) partition cluster replicated
;

create procedure FOAF_SSL_QRY (in gr varchar, in uri varchar)
{
    return sprintf ('sparql
    define input:storage ""
    define input:same-as "yes"
    prefix cert: <http://www.w3.org/ns/auth/cert#>
    prefix rsa: <http://www.w3.org/ns/auth/rsa#>
    select (str (?exp)) (str (?mod))
    from <%S>
    where
    {
      { ?id cert:identity <%S> ; rsa:public_exponent ?exp ; rsa:modulus ?mod .  }
      union
      { ?id cert:identity <%S> ; rsa:public_exponent ?exp1 ; rsa:modulus ?mod1 . ?exp1 cert:decimal ?exp . ?mod1 cert:hex ?mod . }
      union
      { <%S> cert:key ?key . ?key cert:exponent ?exp . ?key cert:modulus ?mod .  }
    }', gr, uri, uri, uri);
}
;

create procedure
DB.DBA.FOAF_SSL_LOGIN (inout user_name varchar, in digest varchar, in session_random varchar)
{
  declare stat, msg, meta, data, info, qr, hf, graph, gr, alts any;
  declare agent varchar;
  declare rc, vtype int;
  rc := 0;
  gr := null;

  declare exit handler for sqlstate '*'
    {
      rollback work;
      goto err_ret;
    }
  ;

  if (client_attr ('client_ssl') = 0)
    return 0;

  if (__proc_exists ('DB.DBA.WEBID_AUTH_GEN_2') and DB.DBA.WEBID_AUTH_GEN_2 (null, 0, 'ODBC', 0, 0, agent, gr, 0, vtype))
    {
      user_name := connection_get ('SPARQLUserId');
      return 1;
    }

  info := get_certificate_info (9);
  agent := get_certificate_info (7, null, null, null, '2.5.29.17');

  if (not isarray (info) or agent is null)
    return 0;
  alts := regexp_replace (agent, ',[ ]*', ',', 1, null);
  alts := split_and_decode (alts, 0, '\0\0,:');
  if (alts is null)
    return 0;
  agent := get_keyword ('URI', alts);
  if (agent is null)
    return 0;

  hf := rfc1808_parse_uri (agent);
  hf[5] := '';
  gr := uuid ();
  graph := WS.WS.VFS_URI_COMPOSE (hf);
  qr := sprintf ('sparql load <%S> into graph <%S>', graph, gr);
  stat := '00000';
  --exec (qr, stat, msg);
  DB.DBA.SPARUL_LOAD (gr, graph, 0, 1, 0, vector ());
  commit work;
  qr := FOAF_SSL_QRY (gr, agent);
  stat := '00000';
  exec (qr, stat, msg, vector (), 0, meta, data);
  if (stat = '00000' and length (data))
    {
      foreach (any _row in data) do
	{
	  if (_row[0] = cast (info[1] as varchar) and
	      lower (regexp_replace (_row[1], '[^A-Z0-9a-f]', '', 1, null)) = bin2hex (info[2]))
    {
      declare uname varchar;
      uname := (select UW_U_NAME from SYS_USER_WEBID where UW_WEBID = agent);
      if (length (uname))
	{
	  user_name := uname;
          rc := 1;
	}
    }
	}
    }
  err_ret:
  if (gr is not null)
    DB.DBA.SPARUL_CLEAR (gr, 0, 0);
    --exec (sprintf ('sparql clear graph <%S>', gr), stat, msg);
  commit work;
  return rc;
}
;

create procedure
USERS_GET_DEF_QUAL (in dta varchar)
{
  if (not length (dta))
    {
      return ('DB');
    }
  dta := split_and_decode (dta, 0, '   ');
  return (get_keyword ('Q', dta, ''));
}
;

create procedure DB.DBA.VEC_SQL_QUEUE_INIT ()
{
  declare stat, msg any;
  --  Every row a DML trigger queues comes through here, so once the tables
  --  exist this has to cost a lookup and no more.  It used to try the three
  --  CREATE TABLEs below every time -- each compiled afresh, as exec () does
  --  not cache, and each failing -- which made 10,000 inserts into an indexed
  --  table take ~40 s against 36 ms without the index.  SYS_KEYS, because a
  --  static query on the queue tables themselves would not compile before
  --  they exist.
  if (exists (select 1 from DB.DBA.SYS_KEYS where KEY_TABLE = 'DB.DBA.VEC_SQL_QUEUE')
      and exists (select 1 from DB.DBA.SYS_KEYS where KEY_TABLE = 'DB.DBA.VEC_SQL_QUEUE_LOCK')
      and exists (select 1 from DB.DBA.SYS_KEYS where KEY_TABLE = 'DB.DBA.VEC_SQL_WORKER_STATE'))
    return 1;
  stat := '00000';
  exec ('create table DB.DBA.VEC_SQL_QUEUE (
    VQ_INDEX varchar not null,
    VQ_PK any not null,
    VQ_OP varchar not null,
    VQ_ENQ datetime,
    VQ_STATE varchar,
    VQ_TRIES integer,
    VQ_ERROR varchar,
    primary key (VQ_INDEX, VQ_PK))', stat, msg);
  stat := '00000';
  exec ('create table DB.DBA.VEC_SQL_QUEUE_LOCK (
    VL_INDEX varchar not null primary key,
    VL_TS datetime)', stat, msg);
  stat := '00000';
  exec ('create table DB.DBA.VEC_SQL_WORKER_STATE (
    VS_ID integer not null primary key,
    VS_LAST_RUN datetime,
    VS_LAST_COUNT integer,
    VS_LAST_ERROR varchar)', stat, msg);
  stat := '00000';
  exec ('insert soft DB.DBA.VEC_SQL_WORKER_STATE (VS_ID, VS_LAST_COUNT) values (1, 0)', stat, msg);
  return 1;
}
;

create function DB.DBA.VEC_SQL_INDEX_IS_RDF_BACKING (in _index varchar) returns integer
{
  -- True when _index is the backing native vector index of a SPARQL/RDF vector
  -- index. Those indexes are maintained directly by the RDF layer (refresh /
  -- SPARQL_VEC_QUEUE via __VEC_INDEX_INSERT_BATCH / __VEC_INDEX_DELETE_ROW) and
  -- their backing source column (RV_TEXT) is deliberately kept NULL, so they must
  -- never flow through the relational SQL queue: a drain would read NULL text and
  -- delete every HNSW node. Defensive against the SPARQL catalog not existing.
  if (not exists (select 1 from DB.DBA.SYS_KEYS where KEY_TABLE = 'DB.DBA.SPARQL_VEC_INDEX'))
    return 0;
  if (exists (select 1 from DB.DBA.SPARQL_VEC_INDEX where SVI_INTERNAL_NAME = _index))
    return 1;
  return 0;
}
;

create procedure DB.DBA.VEC_SQL_QUEUE_ENQUEUE (in _index varchar, in _pk any, in _op varchar)
{
  -- Never enqueue a SPARQL/RDF vector index's backing table into the relational
  -- SQL queue (see VEC_SQL_INDEX_IS_RDF_BACKING). The RDF layer owns its HNSW.
  if (DB.DBA.VEC_SQL_INDEX_IS_RDF_BACKING (_index))
    return 0;
  DB.DBA.VEC_SQL_QUEUE_INIT ();
  if (_op not in ('upsert', 'delete'))
    signal ('22023', 'VEC_SQL_QUEUE_ENQUEUE op must be upsert or delete');
  delete from DB.DBA.VEC_SQL_QUEUE where VQ_INDEX = _index and VQ_PK = _pk;
  insert into DB.DBA.VEC_SQL_QUEUE
    (VQ_INDEX, VQ_PK, VQ_OP, VQ_ENQ, VQ_STATE, VQ_TRIES, VQ_ERROR)
  values (_index, _pk, _op, now (), 'pending', 0, null);
  return 1;
}
;

create procedure DB.DBA.VEC_SQL_INDEX_OPT (in _opts any, in _name varchar)
{
  declare inx, jnx integer;
  if (not isvector (_opts))
    return null;
  -- Match key names case-insensitively.  Stored short-name keys (sc/pk/mid/...)
  -- are lower-case, but a WITH-clause option (e.g. source_kind) may be stored
  -- under its as-typed spelling/case, so callers pass a lower-case _name and we
  -- fold both sides.
  _name := lower (_name);
  inx := 0;
  while (inx + 1 < length (_opts))
    {
      if (isstring (_opts[inx]) and lower (cast (_opts[inx] as varchar)) = _name)
        return _opts[inx + 1];
      inx := inx + 2;
    }
  inx := 0;
  while (inx < length (_opts))
    {
      if (isvector (_opts[inx]))
        {
          jnx := 0;
          while (jnx + 1 < length (_opts[inx]))
            {
              if (isstring (_opts[inx][jnx]) and lower (cast (_opts[inx][jnx] as varchar)) = _name)
                return _opts[inx][jnx + 1];
              jnx := jnx + 2;
            }
        }
      inx := inx + 1;
    }
  return null;
}
;

create procedure DB.DBA.VEC_SQL_MODEL_REFRESH_BY_ID (in _model_id integer)
{
  declare _model_name, _model_type any;
  whenever not found goto done;
  select model_name, model_type into _model_name, _model_type
    from DB.DBA.ONNX_MODELS where model_id = _model_id;
  if (lower (cast (_model_type as varchar)) not in ('test_embedding', 'vvec_test_embedding', 'unavailable'))
    DB.DBA.ONNX_MODEL_REFRESH (cast (_model_name as varchar));
done:
  return 1;
}
;

create procedure DB.DBA.VEC_SQL_QUEUE_FAIL (in _index varchar, in _pk any, in _msg varchar)
{
  update DB.DBA.VEC_SQL_QUEUE
     set VQ_STATE = 'error',
         VQ_TRIES = coalesce (VQ_TRIES, 0) + 1,
         VQ_ERROR = substring (_msg, 1, 1000)
   where VQ_INDEX = _index and VQ_PK = _pk;
  update DB.DBA.VEC_SQL_WORKER_STATE
     set VS_LAST_RUN = now (), VS_LAST_ERROR = substring (_msg, 1, 1000)
   where VS_ID = 1;
  return 1;
}
;

create procedure DB.DBA.VEC_SQL_MAIN_KEY_NAME (in _tbl varchar)
{
  declare _main_key varchar;
  whenever not found goto done;
  select KEY_NAME into _main_key
    from DB.DBA.SYS_KEYS
   where KEY_TABLE = _tbl
     and KEY_IS_MAIN = 1
     and KEY_MIGRATE_TO is null;
  return _main_key;
done:
  return null;
}
;

-- One batch of the backfill: embed the texts, or take the vectors of a
-- 'vector' index as they are, and insert them -- or stage them, for a bulk
-- build.  The texts go with the vectors so every row keeps its SOURCE_HASH, as
-- a row embedded by the DML queue does.  A failure is raised again naming the
-- rows of the batch: the CREATE fails, and the index is removed.
create procedure DB.DBA.VEC_SQL_BACKFILL_BATCH (in _index varchar, in _ids any, in _srcs any,
    in _source_kind varchar, in _model_name varchar, in _model_handle integer, in _model_type varchar,
    in _per_call integer, in _stage integer)
{
  declare _vecs, _raw, _part any;
  declare _i, _j, _n, _k integer;
  declare exit handler for sqlstate '*'
    {
      signal ('42000', 'VECQ1', sprintf ('Vector index %s backfill failed in rows %s to %s: %s: %s',
          _index, cast (_ids[0] as varchar), cast (_ids[length (_ids) - 1] as varchar),
          __SQL_STATE, __SQL_MESSAGE));
    };
  _n := length (_ids);
  if (_source_kind = 'vector')
    {
      -- A stored serialize (vec) reads back as a string or blob; a native
      -- array is passed through, as VEC_SQL_QUEUE_PROCESS_ITEM does.
      _vecs := make_array (_n, 'any');
      for (_i := 0; _i < _n; _i := _i + 1)
        {
          _raw := _srcs[_i];
          aset (_vecs, _i, case when isstring (_raw) or isblob (_raw) then deserialize (_raw) else _raw end);
        }
      if (_stage)
        __VEC_INDEX_STAGE_BATCH (_index, _ids, _vecs);
      else
        __VEC_INDEX_INSERT_BATCH (_index, _ids, _vecs);
      return _n;
    }
  if (_per_call >= _n)
    _vecs := DB.DBA.VEC_INDEX_EMBED_TEXTS (_model_name, _model_handle, _srcs, _model_type);
  else
    {
      _vecs := make_array (_n, 'any');
      for (_i := 0; _i < _n; _i := _i + _per_call)
        {
          _k := case when _i + _per_call < _n then _i + _per_call else _n end;
          _part := DB.DBA.VEC_INDEX_EMBED_TEXTS (_model_name, _model_handle, subseq (_srcs, _i, _k), _model_type);
          for (_j := _i; _j < _k; _j := _j + 1)
            aset (_vecs, _j, _part[_j - _i]);
        }
    }
  if (_stage)
    __VEC_INDEX_STAGE_BATCH (_index, _ids, _vecs, _srcs);
  else
    __VEC_INDEX_INSERT_BATCH (_index, _ids, _vecs, _srcs);
  return _n;
}
;

-- Embed and index the rows of the table a vector index has just been created
-- on: the backfill of CREATE VECTOR INDEX.
--
-- The table is read in key order, a page of 1,000 rows at a time, and each
-- page is embedded and inserted in batches (VEC_INDEX_EMBED_BATCH_SIZE, 32
-- unless __vec_embed_batch_size says otherwise), with the model resolved once,
-- not for every row.  An HTTP provider gets the batch in one request, not one
-- per row.  A local model still gets one text per call: its helper runs a
-- request's rows together in sub-batches of up to 16, and on long texts that
-- halved its rate -- granite on FiQA passages, one thread: 20.8 a second one
-- at a time, 10.8 in calls of 32.  Its lever is threads (the model's
-- intra_threads), not batches.  It used to queue every row and embed them
-- one by one through VEC_SQL_QUEUE_PROCESS_ITEM, which also compiled two
-- statements and re-ran ONNX_MODEL_REFRESH per row.  A row whose source is
-- NULL gets no embedding.
create procedure DB.DBA.VEC_SQL_QUEUE_BACKFILL (in _index varchar)
{
  declare _tbl, _pk_col, _source_col, _main_key, _first, _next, _stat, _msg varchar;
  declare _source_kind, _source_expr, _model_name, _model_type varchar;
  declare _opts, _meta, _rows, _model, _ids, _srcs, _last any;
  declare _model_id, _model_handle, _n, _i, _cnt, _bs, _done, _stage, _per_call integer;
  DB.DBA.VEC_SQL_QUEUE_INIT ();
  -- VEC_SQL_QUEUE_ENQUEUE's rule: the backing table of a SPARQL/RDF vector
  -- index is maintained by the RDF layer, never through here.
  if (DB.DBA.VEC_SQL_INDEX_IS_RDF_BACKING (_index))
    return 0;
  _stat := '00000';
  exec ('select KEY_TABLE, KEY_OPTIONS from DB.DBA.SYS_KEYS where KEY_NAME = ? and KEY_MIGRATE_TO is null',
      _stat, _msg, vector (_index), 1, _meta, _rows);
  if (_stat <> '00000')
    signal (_stat, _msg);
  if (_rows is null or length (_rows) = 0)
    signal ('42S12', sprintf ('No vector index %s', _index));
  _tbl := cast (_rows[0][0] as varchar);
  _opts := _rows[0][1];
  _pk_col := cast (DB.DBA.VEC_SQL_INDEX_OPT (_opts, 'pk') as varchar);
  _source_col := cast (DB.DBA.VEC_SQL_INDEX_OPT (_opts, 'sc') as varchar);
  _main_key := DB.DBA.VEC_SQL_MAIN_KEY_NAME (_tbl);
  if (_pk_col is null or _source_col is null or _main_key is null)
    signal ('42000', 'Vector index metadata missing primary-key scan metadata');
  _source_kind := DB.DBA.VEC_SQL_SOURCE_KIND (_opts);
  _per_call := 1;
  -- build = 'bulk': stage every vector, then derive the graph in one pass at
  -- the end, where 'incremental' (the default; 'auto' means it too) links each
  -- row in as it is embedded.  Linking costs more the larger the graph, and
  -- writes one 8 KB page per node; the fast builder works in memory, in
  -- parallel, and writes packed pages.  It is not deterministic, which is why
  -- this is opt-in, as on the SPARQL side.  Stored as written: 'build',
  -- 'build_method' (SPARQL's other spelling) or 'bd'.
  _stage := case when lower (coalesce (cast (DB.DBA.VEC_SQL_INDEX_OPT (_opts, 'build') as varchar),
                                       cast (DB.DBA.VEC_SQL_INDEX_OPT (_opts, 'build_method') as varchar),
                                       cast (DB.DBA.VEC_SQL_INDEX_OPT (_opts, 'bd') as varchar), '')) = 'bulk'
            then 1 else 0 end;
  _bs := DB.DBA.VEC_INDEX_EMBED_BATCH_SIZE ();
  _model_name := null;
  _model_handle := 0;
  _model_type := '';
  if (_source_kind = 'vector')
    _source_expr := sprintf ('"%I"', _source_col);
  else
    {
      _source_expr := DB.DBA.VEC_SQL_SOURCE_EXPR (_tbl, _source_col, _pk_col, _source_kind);
      _model_id := cast (DB.DBA.VEC_SQL_INDEX_OPT (_opts, 'mid') as integer);
      _stat := '00000';
      exec ('select model_name from DB.DBA.ONNX_MODELS where model_id = ?',
          _stat, _msg, vector (_model_id), 1, _meta, _rows);
      if (_stat = '00000' and isvector (_rows) and length (_rows) > 0)
        _model_name := cast (_rows[0][0] as varchar);
      -- Once per backfill, not per row: reload the model if its handle has
      -- gone stale, and pick up the registry's current load options.
      DB.DBA.VEC_SQL_MODEL_REFRESH_BY_ID (_model_id);
      _model := DB.DBA.VEC_INDEX_RESOLVE_MODEL (_model_name);
      _model_handle := cast (_model[0] as integer);
      _model_type := cast (_model[2] as varchar);
      if (_model_type = '')
        signal ('42000', 'VEC52', sprintf ('Vector index %s: its model %s is not available', _index, coalesce (_model_name, '(none)')));
      if (_model_type in ('test_embedding', 'vvec_test_embedding', 'openai', 'ollama', 'lmstudio', 'openai_compatible'))
        _per_call := _bs;
    }
  _first := sprintf ('select top 1000 "%I", %s from "%I"."%I"."%I" table option (index "%I") order by "%I"',
      _pk_col, _source_expr, name_part (_tbl, 0), name_part (_tbl, 1), name_part (_tbl, 2), name_part (_main_key, 2), _pk_col);
  _next := sprintf ('select top 1000 "%I", %s from "%I"."%I"."%I" table option (index "%I") where "%I" > ? order by "%I"',
      _pk_col, _source_expr, name_part (_tbl, 0), name_part (_tbl, 1), name_part (_tbl, 2), name_part (_main_key, 2), _pk_col, _pk_col);
  _done := 0;
  _last := null;
  while (1)
    {
      _stat := '00000';
      _rows := null;
      if (_last is null)
        exec (_first, _stat, _msg, vector (), 0, _meta, _rows);
      else
        exec (_next, _stat, _msg, vector (_last), 0, _meta, _rows);
      if (_stat <> '00000')
        signal (_stat, _msg);
      if (not isvector (_rows) or length (_rows) = 0)
        goto pages_done;
      _n := length (_rows);
      _last := _rows[_n - 1][0];
      _ids := make_array (_n, 'any');
      _srcs := make_array (_n, 'any');
      _cnt := 0;
      for (_i := 0; _i < _n; _i := _i + 1)
        if (_rows[_i][1] is not null)
          {
            aset (_ids, _cnt, _rows[_i][0]);
            aset (_srcs, _cnt, _rows[_i][1]);
            _cnt := _cnt + 1;
          }
      for (_i := 0; _i < _cnt; _i := _i + _bs)
        _done := _done + DB.DBA.VEC_SQL_BACKFILL_BATCH (_index,
            subseq (_ids, _i, case when _i + _bs < _cnt then _i + _bs else _cnt end),
            subseq (_srcs, _i, case when _i + _bs < _cnt then _i + _bs else _cnt end),
            _source_kind, _model_name, _model_handle, _model_type, _per_call, _stage);
    }
pages_done:
  -- No method passed: __VEC_INDEX_REBUILD's own precedence applies, and its
  -- 'auto' falls back from the fast builder to replay when the estimated
  -- memory would not fit VVEC_FAST_REBUILD_MAX_BYTES.
  if (_stage and _done > 0)
    __VEC_INDEX_REBUILD (_index);
  return _done;
}
;

-- What a SQL vector index reads from its source column: 'text' (embedded by
-- the index's model), 'vector' (the column holds the embedding) or 'rdf_obj'.
-- 'sk' is the canonical short key; an index may also carry the as-typed long
-- spelling 'source_kind' (see vvec_opts_append_val in-place update).
-- VEC_SQL_INDEX_OPT is case-insensitive; try both spellings.
create function DB.DBA.VEC_SQL_SOURCE_KIND (in _opts any) returns varchar
{
  return lower (coalesce (
      cast (DB.DBA.VEC_SQL_INDEX_OPT (_opts, 'sk') as varchar),
      cast (DB.DBA.VEC_SQL_INDEX_OPT (_opts, 'source_kind') as varchar),
      'text'));
}
;

-- The select-list expression for the text a 'text' or 'rdf_obj' index embeds
-- for a row of its table.
create function DB.DBA.VEC_SQL_SOURCE_EXPR (in _tbl varchar, in _source_col varchar,
    in _pk_col varchar, in _source_kind varchar) returns varchar
{
  if (_source_kind = 'rdf_obj')
    return sprintf ('DB.DBA.VEC_INDEX_RO_TEXT ("%I")', _pk_col);
  if (exists (select 1 from DB.DBA.SYS_COLS
               where "TABLE" = _tbl
                 and "COLUMN" = _source_col
                 and (dv_type_title (COL_DTP) like 'LONG %' or COL_PREC >= 2147483647)))
    return sprintf ('blob_to_string ("%I")', _source_col);
  return sprintf ('cast ("%I" as varchar)', _source_col);
}
;

-- Apply one queue entry: embed and insert the row, or delete it, then remove
-- the entry; a failure marks the entry 'error' instead.  The caller chooses
-- the entry -- VEC_SQL_QUEUE_PROCESS_ONE the oldest pending one -- and has
-- called VEC_SQL_QUEUE_INIT.
create procedure DB.DBA.VEC_SQL_QUEUE_PROCESS_ITEM (in _index varchar, in _pk any, in _op varchar)
{
  declare _tbl, _source_col, _pk_col, _main_key, _source_expr, _sql, _stat, _msg varchar;
  declare _opts, _meta, _rows, _text_value any;
  declare _model_id integer;
  declare _locked integer;
  declare _source_kind varchar;
  declare _raw, _vec any;

  _locked := 0;

  declare exit handler for sqlstate '*'
  {
    declare _err varchar;
    _err := __SQL_STATE || ': ' || __SQL_MESSAGE;
    if (_locked)
      delete from DB.DBA.VEC_SQL_QUEUE_LOCK where VL_INDEX = _index;
    DB.DBA.VEC_SQL_QUEUE_FAIL (_index, _pk, _err);
    return 1;
  };

  -- Defensive: an entry belonging to a SPARQL/RDF vector index's backing table
  -- must never be applied here (it would delete HNSW nodes because RV_TEXT is
  -- NULL). Enqueue is now suppressed at the source, but drain any stragglers
  -- left by older builds harmlessly: dequeue without touching the graph.
  if (DB.DBA.VEC_SQL_INDEX_IS_RDF_BACKING (_index))
    {
      delete from DB.DBA.VEC_SQL_QUEUE where VQ_INDEX = _index and VQ_PK = _pk;
      return 1;
    }

  insert into DB.DBA.VEC_SQL_QUEUE_LOCK (VL_INDEX, VL_TS) values (_index, now ());
  _locked := 1;

  _stat := '00000';
  exec ('select KEY_TABLE, KEY_OPTIONS from DB.DBA.SYS_KEYS where KEY_NAME = ? and KEY_MIGRATE_TO is null',
      _stat, _msg, vector (_index), 1, _meta, _rows);
  if (_stat <> '00000')
    signal (_stat, _msg);
  if (_rows is null or length (_rows) = 0)
    signal ('42S12', sprintf ('No vector index %s', _index));
  _tbl := cast (_rows[0][0] as varchar);
  _opts := _rows[0][1];

  _source_col := cast (DB.DBA.VEC_SQL_INDEX_OPT (_opts, 'sc') as varchar);
  _pk_col := cast (DB.DBA.VEC_SQL_INDEX_OPT (_opts, 'pk') as varchar);
  _model_id := cast (DB.DBA.VEC_SQL_INDEX_OPT (_opts, 'mid') as integer);
  _main_key := DB.DBA.VEC_SQL_MAIN_KEY_NAME (_tbl);
  if (_source_col is null or _pk_col is null)
    signal ('42000', 'Vector index metadata missing source or primary-key column');
  if (_main_key is null)
    signal ('42000', 'Vector index metadata missing main table key');

  if (_op = 'delete')
    {
      __VEC_INDEX_DELETE_ROW (_index, _pk);
      delete from DB.DBA.VEC_SQL_QUEUE where VQ_INDEX = _index and VQ_PK = _pk;
    }
  else
    {
      -- Precomputed-vector passthrough (source_kind='vector'): the source column
      -- already holds the embedding, so there is no model.  Read the NATIVE
      -- column value (never blob_to_string / cast as varchar, which would corrupt
      -- a serialized or native vector), deserialize a stored blob/string, treat
      -- NULL as a delete, and hand it to the precomputed-vector insert BIF (which
      -- validates shape/dimension -- VEC30/VEC31 -- and reaches the hidden table
      -- through the DBA path).  The model/text branch below is left unchanged.
      _source_kind := DB.DBA.VEC_SQL_SOURCE_KIND (_opts);
      if (_source_kind = 'vector')
        {
          _sql := sprintf ('select "%I" from "%I"."%I"."%I" table option (index "%I") where "%I" = ?',
              _source_col, name_part (_tbl, 0), name_part (_tbl, 1), name_part (_tbl, 2), name_part (_main_key, 2), _pk_col);
          _stat := '00000';
          exec (_sql, _stat, _msg, vector (_pk), 1, _meta, _rows);
          if (_stat <> '00000')
            signal (_stat, _msg);
          if (_rows is null or length (_rows) = 0 or _rows[0][0] is null)
            __VEC_INDEX_DELETE_ROW (_index, _pk);   -- NULL column value == row absent
          else
            {
              _raw := _rows[0][0];
              -- A stored serialize(vec) reads back as a string/blob; deserialize
              -- it to the array the BIF requires.  A native array value
              -- (DV_ARRAY_OF_FLOAT or a vector(...)) is passed through unchanged.
              if (isstring (_raw) or isblob (_raw))
                _vec := deserialize (_raw);
              else
                _vec := _raw;
              __VEC_INDEX_INSERT_EMBEDDING (_index, _pk, _vec);
            }
          delete from DB.DBA.VEC_SQL_QUEUE where VQ_INDEX = _index and VQ_PK = _pk;
          goto _upsert_done;
        }
      _source_expr := DB.DBA.VEC_SQL_SOURCE_EXPR (_tbl, _source_col, _pk_col, _source_kind);
      _sql := sprintf ('select %s from "%I"."%I"."%I" table option (index "%I") where "%I" = ?',
          _source_expr, name_part (_tbl, 0), name_part (_tbl, 1), name_part (_tbl, 2), name_part (_main_key, 2), _pk_col);
      _stat := '00000';
      exec (_sql, _stat, _msg, vector (_pk), 1, _meta, _rows);
      if (_stat <> '00000')
        signal (_stat, _msg);
      if (_rows is null or length (_rows) = 0 or _rows[0][0] is null)
        __VEC_INDEX_DELETE_ROW (_index, _pk);
      else
        {
          _text_value := _rows[0][0];
          DB.DBA.VEC_SQL_MODEL_REFRESH_BY_ID (_model_id);
          __VEC_INDEX_EMBED_AND_INSERT (_index, _pk, cast (_text_value as varchar));
        }
      delete from DB.DBA.VEC_SQL_QUEUE where VQ_INDEX = _index and VQ_PK = _pk;
      _upsert_done:;
    }

  delete from DB.DBA.VEC_SQL_QUEUE_LOCK where VL_INDEX = _index;
  update DB.DBA.VEC_SQL_WORKER_STATE
     set VS_LAST_RUN = now (), VS_LAST_COUNT = coalesce (VS_LAST_COUNT, 0) + 1, VS_LAST_ERROR = null
   where VS_ID = 1;
  return 1;
}
;

-- Apply the oldest pending entry of any index.  0 when there is none.
create procedure DB.DBA.VEC_SQL_QUEUE_PROCESS_ONE ()
{
  declare _stat, _msg varchar;
  declare _meta, _rows any;

  DB.DBA.VEC_SQL_QUEUE_INIT ();

  _stat := '00000';
  exec ('select top 1 VQ_INDEX, VQ_PK, VQ_OP from DB.DBA.VEC_SQL_QUEUE
          where VQ_STATE = ''pending'' and coalesce (VQ_TRIES, 0) < 5
          order by VQ_ENQ', _stat, _msg, vector (), 0, _meta, _rows);
  if (_stat <> '00000' or _rows is null or length (_rows) = 0)
    return 0;

  return DB.DBA.VEC_SQL_QUEUE_PROCESS_ITEM (cast (_rows[0][0] as varchar), _rows[0][1], cast (_rows[0][2] as varchar));
}
;

create procedure DB.DBA.VEC_SQL_QUEUE_DRAIN (in _max_items integer := 100)
{
  declare done, cnt integer;
  DB.DBA.VEC_SQL_QUEUE_INIT ();
  cnt := 0;
  while (cnt < _max_items)
    {
      done := DB.DBA.VEC_SQL_QUEUE_PROCESS_ONE ();
      if (done = 0)
        return cnt;
      cnt := cnt + 1;
    }
  return cnt;
}
;

-- One worker pass: the SQL index queue, then new RDF literals for RDF_OBJ vector indexes.
create procedure DB.DBA.VEC_SQL_WORKER_TICK (in _max_items integer := 100)
{
  declare cnt integer;
  cnt := DB.DBA.VEC_SQL_QUEUE_DRAIN (_max_items);
  if (__proc_exists ('DB.DBA.RDF_OBJ_VEC_LOG_DRAIN'))
    cnt := cnt + call ('DB.DBA.RDF_OBJ_VEC_LOG_DRAIN') (_max_items * 10);
  return cnt;
}
;

create procedure DB.DBA.VEC_SQL_WORKER_RUN (in _interval_seconds integer := 1)
{
  DB.DBA.VEC_SQL_QUEUE_INIT ();
  while (exists (select 1 from DB.DBA.SYS_SCHEDULED_EVENT where SE_NAME = 'VEC_SQL_WORKER'))
    {
      DB.DBA.VEC_SQL_WORKER_TICK (100);
      delay (case when _interval_seconds > 0 then _interval_seconds else 1 end);
    }
  return 1;
}
;

create procedure DB.DBA.VEC_SQL_WORKER_START (in _interval_seconds integer := 1)
{
  DB.DBA.VEC_SQL_QUEUE_INIT ();
  if (_interval_seconds is null or _interval_seconds < 1)
    _interval_seconds := 1;
  delete from DB.DBA.SYS_SCHEDULED_EVENT where SE_NAME = 'VEC_SQL_WORKER';
  insert into DB.DBA.SYS_SCHEDULED_EVENT (SE_NAME, SE_START, SE_INTERVAL, SE_SQL)
    values ('VEC_SQL_WORKER', now (), _interval_seconds, 'DB.DBA.VEC_SQL_WORKER_TICK (100)');
  return 1;
}
;

create procedure DB.DBA.VEC_SQL_WORKER_STOP ()
{
  DB.DBA.VEC_SQL_QUEUE_INIT ();
  delete from DB.DBA.SYS_SCHEDULED_EVENT where SE_NAME = 'VEC_SQL_WORKER';
  return 1;
}
;

create procedure DB.DBA.VEC_SQL_WORKER_STATUS ()
{
  declare pending, errors, last_count integer;
  declare last_run, last_error any;
  DB.DBA.VEC_SQL_QUEUE_INIT ();
  pending := (select count (*) from DB.DBA.VEC_SQL_QUEUE where VQ_STATE = 'pending');
  errors := (select count (*) from DB.DBA.VEC_SQL_QUEUE where VQ_STATE = 'error');
  select VS_LAST_RUN, coalesce (VS_LAST_COUNT, 0), VS_LAST_ERROR
    into last_run, last_count, last_error
    from DB.DBA.VEC_SQL_WORKER_STATE where VS_ID = 1;
  return vector ('pending', pending, 'error', errors, 'last_run', last_run,
                 'last_count', last_count, 'last_error', last_error);
}
;

--
--  Vector-index durability catalog.
--
--  The HNSW graph lives in DPF_VEC pages that reach disk only at checkpoint;
--  they carry no transaction-log records, so an unclean shutdown loses every
--  graph mutation made since the last checkpoint while the logged embedding
--  rows survive.  VEC_INDEX_EPOCH is the transactional half of the pair that
--  makes that divergence detectable: the C layer bumps VVEC_META_EPOCH on the
--  root page and writes the same value here inside the mutating transaction.
--  At open time the two are compared (see vvec_epoch_reconcile in vvec.c).
--
--    VIE_KEY_ID    the dbe_key_t key id of the vector index
--    VIE_NAME      index name, for operator-facing diagnostics only
--    VIE_EPOCH     epoch as of the last committed mutation
--    VIE_STATE     'ok' | 'needs_rebuild'
--    VIE_DETAIL    why it needs a rebuild, when it does
--    VIE_CHECKED_AT  last time reconciliation ran for this index
--
create procedure DB.DBA.VEC_INDEX_EPOCH_INIT ()
{
  declare _stat, _msg varchar;
  _stat := '00000';
  exec ('create table DB.DBA.VEC_INDEX_EPOCH (
    VIE_KEY_ID integer not null,
    VIE_NAME varchar,
    VIE_EPOCH integer default 0,
    VIE_STATE varchar(16) default ''ok'',
    VIE_DETAIL varchar,
    VIE_CHECKED_AT datetime,
    primary key (VIE_KEY_ID))', _stat, _msg);
  return 1;
}
;

DB.DBA.VEC_INDEX_EPOCH_INIT ()
;
