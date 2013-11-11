--
--  $Id$
--
--  Authenticate against names and passwords in SYS_USERS, using HP_SECURITY for level
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
--

create procedure
DB.DBA.HP_AUTH_SQL_USER (in realm varchar)
{
  declare r integer;
  r := DB.DBA.HTTP_AUTH_CHECK_USER (realm, 1, 1);

  if (r = 1)
  {
    if (http_map_get ('persist_ses_vars'))
    {
      declare vars any;
      declare sid varchar;
      vars := null;
      sid := http_param ('sid');
      vars := coalesce ((select deserialize (ASES_VARS) from DB.DBA.ADMIN_SESSION where ASES_ID = sid), null);
      if (sid is not null and vars is null or isarray (vars))
        connection_vars_set (vars);
      if (sid is not null and connection_get ('sid') is null)
        connection_set ('sid', sid);
    }
    return 1;
  }

  else
  {
    return 0;
  }
}
;

-- Authenticate against SYS_DAV_USER, using HP_SECURITY for level, in the context of DAV
-- administration pages accessed through regular HTTP
create procedure
DB.DBA.HP_AUTH_DAV_ADMIN (in realm varchar)
{
  declare r integer;
  r := DB.DBA.HTTP_AUTH_CHECK_USER (realm, 0, 1, '/admin/admin_dav');

  if (r = 1)
  {
    if (http_map_get ('persist_ses_vars'))
    {
      declare vars any;
      declare sid varchar;
      vars := null;
      sid := http_param ('sid');
      vars := coalesce ((select deserialize (ASES_VARS) from DB.DBA.ADMIN_SESSION where ASES_ID = sid), null);
      if (vars is null or isarray (vars))
        connection_vars_set (vars);
      if (connection_get ('sid') is null)
        connection_set ('sid', sid);
    }
    return r;
  }

  else
  {
    return 0;
  }
}
;

-- Ibid but in the context of DAV protocol requests.
create procedure
DB.DBA.HP_AUTH_DAV_PROTOCOL (in realm varchar)
{
  declare _u_name, _u_password, _perms varchar;
  declare _u_id, _u_group, req_user, req_group, what integer;
  declare auth any;
  declare _user, lev varchar;
  declare our_auth_vec, lines, sec, path, req_perms, req_meth, cmp_perms, def_page varchar;
  declare _method, allow_basic, authenticated integer;

  declare c cursor for select 1, COL_OWNER, COL_GROUP, COL_PERMS
      from WS.WS.SYS_DAV_COL where WS.WS.COL_PATH (COL_ID) = path;
  declare r cursor for select 2, RES_OWNER, RES_GROUP, RES_PERMS
      from WS.WS.SYS_DAV_RES where RES_FULL_PATH = path;

  authenticated := 0;

  lines := http_request_header ();
  path := http_physical_path ();

  if (isarray (lines))
    {
      req_meth := aref (lines, 0);
      if (strchr (req_meth, ' ') is not null)
        req_meth := lower (substring (req_meth, 1, strchr (req_meth, ' ')));
    }


  if (req_meth = 'get' or
      req_meth = 'post' or
      req_meth = 'options' or
      req_meth = 'propfind' or
      req_meth = 'head' or
      req_meth = 'trace' or
      req_meth = 'copy')
    cmp_perms := '1__';
  else if (req_meth = 'mkcol' or req_meth = 'put')
    {
      if (length (path) > 1 and strrchr (substring (path, 1, length(path) - 1), '/') is not null)
        path := substring (path, 1, strrchr (substring (path, 1, length(path) - 1), '/') + 1);
      cmp_perms := '11_';
    }
  else
    cmp_perms := '11_';


  what := 0;
  whenever not found goto fr;
  open c (prefetch 1);
  fetch c into what, req_user, req_group, req_perms;
  def_page := http_map_get ('default_page');
  if (isstring (def_page))
    {
      path := concat (path, def_page);
      what := 0;
    }
fr:
  close c;

  if (not what)
    {
      whenever not found goto fe;
      open r (prefetch 1);
      fetch r into what, req_user, req_group, req_perms;
fe:
      close r;
    }


  sec := http_map_get ('security_level');
  if (isstring (sec))
    sec := ucase (sec);
  if (sec = 'DIGEST')
    allow_basic := 0;
  else
    allow_basic := 1;

  auth := DB.DBA.vsp_auth_vec (lines);

  if (0 <> auth)
    {
      lev := get_keyword ('authtype', auth, '');
      if (allow_basic = 0 and 'basic' = lev)
	goto nf;

      _user := get_keyword ('username', auth);

      if (_user = '' or isnull (_user))
	{
	  goto nf;
	}

      whenever not found goto nf;

      select U_NAME, pwd_magic_calc (U_NAME, U_PWD, 1), U_GROUP, U_ID, U_METHODS, U_DEF_PERMS
	into _u_name, _u_password, _u_group, _u_id, _method, _perms from WS.WS.SYS_DAV_USER
	where U_NAME = _user and U_ACCOUNT_DISABLED = 0 with (exclusive, prefetch 1);
      if (_u_password is null)
	goto nf;
      if (DB.DBA.vsp_auth_verify_pass (auth, _u_name,
				coalesce(get_keyword ('realm', auth), ''),
				coalesce(get_keyword ('uri', auth), ''),
				coalesce(get_keyword ('nonce', auth), ''),
				coalesce(get_keyword ('nc', auth),''),
				coalesce(get_keyword ('cnonce', auth), ''),
				coalesce(get_keyword ('qop', auth), ''),
				_u_password))
	{
	  update WS.WS.SYS_DAV_USER set U_LOGIN_TIME = now () where U_NAME = _user;
	  if (http_map_get ('persist_ses_vars'))
	    {
	      declare vars any;
	      declare sid varchar;
	      vars := null;
	      sid := http_param ('sid');
	      vars := coalesce ((select deserialize (ASES_VARS) from DB.DBA.ADMIN_SESSION where ASES_ID = sid),
			null);
	      if (vars is null or isarray (vars))
		connection_vars_set (vars);
	      if (connection_get ('sid') is null)
		{
		  connection_set ('sid', sid);
		}
	    }
	  if (connection_get ('DAVUserID') <> _u_id)
	    connection_set ('DAVUserID', _u_id);
          authenticated := 1;
	}
    }

-- Check permissions
  if (authenticated and _u_id = 1)
    return 1;
  else if (not authenticated and req_perms like concat ('______', cmp_perms, '%'))
    return -1;
  else if (authenticated and
          ((_u_id = req_user and req_perms like concat (cmp_perms, '%')) or
	   (req_group = _u_group and req_perms like concat ('___', cmp_perms, '%')) or
	   (req_perms like concat ('______', cmp_perms, '%'))))
    return (_u_id);
  else if (authenticated)
    {
      http_request_status ('HTTP/1.1 403 Forbidden');
      http ( concat ('<!DOCTYPE HTML PUBLIC "-//IETF//DTD HTML 2.0//EN">',
             '<HTML><HEAD>',
             '<TITLE>403 Forbidden</TITLE>',
             '</HEAD><BODY><H1>Forbidden</H1>',
             'Access to the resource is forbidden.</BODY></HTML>'));
      return 0;
    }
-- End check permissions

nf:
  DB.DBA.vsp_auth_get (realm, '/DAV',
      md5 (datestring(now())),
      md5 ('opaakki'),
      'false', lines, allow_basic);
  return 0;
}
;


create procedure
DB.DBA.HP_SES_VARS_STORE ()
{
  declare vars any;
  declare sid varchar;
  if (http_map_get ('persist_ses_vars') and connection_is_dirty ())
    {
      vars := connection_vars ();
      connection_vars_set (null);
      sid := get_keyword ('sid', vars, null);
      if (sid is not null)
	update DB.DBA.ADMIN_SESSION set ASES_VARS = serialize (vars) where ASES_ID = sid;
    }
}
;

grant execute on DB.DBA.HP_SES_VARS_STORE to public
;


create procedure WS.WS.VSP_DEFINE (in path varchar, in _uid varchar)
{
  declare x, y, stat, msg, st varchar;
  declare str varchar;
  if (strstr (path, '..'))
    signal ('22023', 'Path contains ..', 'HT051');
  str := string_output ();

  http ('create procedure WS.WS."', str);
  http (path, str);
  http ('" (in path varchar, in params varchar, in lines varchar) { ?>', str);
  st := NULL;
  DB.DBA.expand_includes (path, str, 0, NULL, st);

  http ('<?vsp }', str);
  stat := '00000';
  str := string_output_string (str);
  __set_user_id (_uid);
  exec (str, stat, msg, vector (), 0, x, y);
  if (stat <> '00000')
    signal (stat, msg);
  registry_set (path, file_stat (concat (http_root (), path)));
  __pop_user_id ();
  return 1;
}
;


-- The HTTP sessions table
CREATE TABLE WS.WS.SESSION (
    S_ID 			varchar,      -- session id
    S_EXPIRE 			datetime,     -- when it expires
    S_VARS 			long varchar, -- serialized value of session variables
    S_REQUEST_UNDER_RELOGIN 	long varchar, -- serialized value of request status upon re-login detected
    S_REALM 			varchar,      -- authentication realm
    S_IS_DIGEST 		integer,      -- flag for digest authentication
    S_DOMAIN 			varchar,      -- authentication domain
    S_NONCE 			varchar,      -- nonce value
    S_OPAQUE 			varchar,      -- opaque value
    S_STALE 			varchar,      -- stale value
    S_QOP 			varchar,      -- qop value
    S_ALGORITHM 		varchar,      -- algorithm name
    S_NC 			integer,      -- nonce count
    primary key (S_REALM, S_ID)
)
;


-- post-processing function for web applications
-- checks if the session variables changed in the HTTP request
-- and is allowed persistent session variables
-- if the above is true then store session variables in the session table
--!AWK PUBLIC
CREATE PROCEDURE WS.WS.SESSION_SAVE ()
{
  declare sid varchar; -- session id
  declare vars any;    -- session variables array

  -- retrieve all session variables
  vars := connection_vars ();
  -- check is persistent storage
  if (http_map_get ('persist_ses_vars') and connection_is_dirty ())
    {
      -- retrieve session id from session variables
      sid := get_keyword ('sid', vars, null);
      -- store session variables in session table
      if (sid is not null)
        update WS.WS.SESSION set S_VARS = serialize (vars) where S_ID = sid;
    }
  -- reset the session variables to this connection, to avoid usage from another connection
  connection_vars_set (NULL);
}
;

-- terminate the session and redirect to a specified URI
--!AWK PUBLIC
CREATE PROCEDURE WS.WS.SESSION_TERMINATE (in url varchar)
{
  -- remove session entry from the session table
  delete from WS.WS.SESSION where S_ID = connection_get ('sid');
  -- do the redirect response and header line
  http_request_status ('HTTP/1.1 302 Found');
  http_header (sprintf ('Location: %s\r\n', url));
}
;


-- digest authentication hook
-- start a session and redirect to the default page
--!AWK PUBLIC
CREATE PROCEDURE WS.WS.DIGEST_AUTH (in realm varchar)
{
  declare auth_vec, lines, vars, server_nc any;
  declare passwd, sid, old_sid varchar;
  declare client_nc, nonce varchar;
  declare user_check varchar;
  declare opts, public_pages, req_path any;

  opts := http_map_get ('auth_opts');
  if (isarray (opts))
    {
      declare i, l integer;
      public_pages := split_and_decode (get_keyword ('public_pages', opts, ''), 0, ',=,');
      req_path := split_and_decode (http_path (), 0, '\0\0/');
      l := length (public_pages); i := 0;
      while (i < l)
	{
	  if (trim(public_pages[i]) = req_path [length (req_path) - 1] or req_path [length (req_path) - 1] = '')
	    return 1;
	  i := i + 1;
	}
    }

  lines := http_request_header();
  auth_vec := DB.DBA.vsp_auth_vec (lines);
  old_sid := null;
  if (0 <> auth_vec)
    {
      declare usp any;
      if ('digest' <> lower (get_keyword ('authtype' , auth_vec, ''))
	  or '' = get_keyword ('username' , auth_vec, ''))
	goto nf;

      sid := get_keyword ('opaque', auth_vec, '');
      if (sid = '')
        sid := get_keyword ('nonce', auth_vec, '');
      server_nc := coalesce ((select S_NC from WS.WS.SESSION where S_ID = sid), 0);
      server_nc := sprintf ('%08x', server_nc);
      client_nc := lower (get_keyword ('nc', auth_vec, '0'));
      usp := http_map_get ('auth_opts');
      if (not isarray(usp))
	signal ('22023', 'The authentication hook needs a authentication option "users_proc" to be set to the function for user account checking.', 'HT055');
      user_check := get_keyword ('users_proc', usp, null);
      if (user_check is null)
        goto nf;
      call (user_check) (get_keyword ('username' , auth_vec), passwd);
      if (passwd is null)
        goto nf;
      if (server_nc = client_nc and 1 = DB.DBA.vsp_auth_verify_pass (auth_vec,
	                               get_keyword ('username' , auth_vec),
				       get_keyword ('realm', auth_vec, ''),
				       get_keyword ('uri', auth_vec, ''),
				       get_keyword ('nonce', auth_vec, ''),
				       get_keyword ('nc', auth_vec, ''),
				       get_keyword ('cnonce', auth_vec, ''),
				       get_keyword ('qop', auth_vec, ''),
				       passwd))
	{
	  vars := coalesce ((select deserialize (S_VARS) from WS.WS.SESSION where S_ID = sid), NULL);
	  connection_vars_set (vars);
	  if (exists (select 1 from WS.WS.SESSION where S_ID = sid and S_EXPIRE <= now ()))
	    {
	      delete from WS.WS.SESSION where S_ID = sid and S_EXPIRE <= now ();
              old_sid := sid;
              goto nf;
	    }
	  update WS.WS.SESSION set S_EXPIRE = dateadd ('minute', 10, now ()), S_NC = S_NC + 1 where S_ID = sid;
	  return 1;
	}
    }
 nf:
  sid := md5 (concat (datestring (now ()), http_client_ip (), http_path ()));
  nonce := sid;
  vars := vector ('sid', sid);
  if (old_sid is not null)
    {
      connection_set ('sid', sid);
      vars := connection_vars ();
      connection_vars_set (NULL);
    }
  insert into WS.WS.SESSION (S_REALM, S_ID, S_EXPIRE, S_VARS,
                       S_DOMAIN, S_NC, S_OPAQUE, S_NONCE, S_STALE, S_ALGORITHM)
               values (http_path (), sid, dateadd ('minute', 10, now ()), serialize (vars),
                       http_path (), 1, sid, nonce, 'false', 'MD5');
  DB.DBA.vsp_auth_get (realm, http_map_get ('domain'), nonce, sid, 'false', lines, 0);
  http ('<HTML><BODY><p>Authorization failed (401)</p></BODY></HTML>');
  return 0;
}
;

--!
-- Check for digest HTTP AUTH parameters.
--
-- \return \p 1 if credentials were found in the request headers, \p 0 if no credentials were given,
-- \p -1 if invalid credentials were given.
--/
create procedure
DB.DBA.HTTP_AUTH_CHECK_USER (
  in realm varchar,
  in needSql integer := 0,
  in requestAuth integer := 0,
  in authDomain varchar := null)
{
  declare _u_name, _u_password varchar;
  declare sec, lev varchar;
  declare allow_basic integer;
  declare _user varchar;
  declare lines, auth any;

  lines := http_request_header ();
  sec := http_map_get ('security_level');
  if (isstring (sec))
    sec := lower (sec);
  if (sec = 'digest')
    allow_basic := 0;
  else
    allow_basic := 1;

  auth := DB.DBA.vsp_auth_vec (lines);
  if (0 <> auth)
  {
    lev := get_keyword ('authtype', auth, '');
    if (allow_basic = 0 and 'basic' = lev)
      return -1;
    _user := get_keyword ('username', auth, '');

    if ('' = _user)
      goto nf;

    whenever not found goto nf;

    select U_NAME, U_PASSWORD
      into _u_name, _u_password from DB.DBA.SYS_USERS
      where U_NAME = _user and U_ACCOUNT_DISABLED = 0 and U_IS_ROLE = 0 and (U_SQL_ENABLE = 1 or needSql = 0) with (prefetch 1);

    if (1 = DB.DBA.vsp_auth_verify_pass (auth, _u_name,
      get_keyword ('realm', auth, ''),
      get_keyword ('uri', auth, ''),
      get_keyword ('nonce', auth, ''),
      get_keyword ('nc', auth, ''),
      get_keyword ('cnonce', auth, ''),
      get_keyword ('qop', auth, ''),
      _u_password))
    {
      connection_set ('SPARQLUserId', _u_name);
      commit work;
      return 1;
    }
  }

nf:
  if (requestAuth = 1)
  {
    DB.DBA.vsp_auth_get (
      realm,
      coalesce (authDomain, http_path ()),
      md5 (datestring (now ())),
      md5 ('secret'),
      'false',
      lines,
      allow_basic);
    return 0;
  }

  return -1;
}
;

create procedure
DB.DBA.HP_AUTH_SPARQL_USER (in realm varchar)
{
  if (DB.DBA.HTTP_AUTH_CHECK_USER (realm, 1, 1) = 1)
    return 1;
  else
    return 0;
}
;
