--
--  virtual_dir.sql
--
--  $Id$
--
--  Virtual Web directories support.
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
--  

-- XXX: nolonger needed, obsoleted
--create table SYS_HTTP_MAP
--(
--  HM_LPATH       varchar,  -- Logical path
--  HM_PPATH       varchar,  -- Physical path
--  primary key (HM_LPATH)
--)
--;

-- Mappings table
create table DB.DBA.HTTP_PATH (
    HP_HOST     varchar not null, -- mapping Host in HTTP header note: *ini*, *sslini*
    HP_LISTEN_HOST  varchar not null, -- IP address & port for mapping listening session
    HP_LPATH        varchar not null, -- logical path
    HP_PPATH    varchar not null, -- physical path
    HP_STORE_AS_DAV   integer not null, -- flag for webDAV storage
    HP_DIR_BROWSEABLE   integer not null, -- directory listing allowed
    HP_DEFAULT    varchar,    -- default page
    HP_SECURITY       varchar,          -- witch method allowed all/https/digest (0/1/2)
    HP_REALM          varchar,          -- authentication realm
    HP_AUTH_FUNC      varchar,          -- witch function authenticate this directory
    HP_POSTPROCESS_FUNC varchar,          -- function call after request
    HP_RUN_VSP_AS     varchar,          -- uid for VSPs REFERENCES SYS_USERS (U_NAME) ON DELETE SET NULL
    HP_RUN_SOAP_AS    varchar,          -- uid for SOAP REFERENCES SYS_USERS (U_NAME) ON DELETE SET NULL
    HP_PERSIST_SES_VARS integer not null, -- have a persistent session variables
    HP_SOAP_OPTIONS long varchar,   -- SOAP options
    HP_AUTH_OPTIONS varchar,    -- Authentication options
    HP_OPTIONS    any,      -- Global options
    HP_IS_DEFAULT_HOST  integer,    -- default host mapping
    primary key (HP_LISTEN_HOST, HP_HOST, HP_LPATH)
)
;

create table HTTP_ACL (
  HA_LIST   varchar not null,   -- ACL name (group)
  HA_ORDER  integer not null,   -- Order in the list
  HA_OBJECT integer not NULL default -1,  -- Object ID (applicable to news groups)
  HA_CLIENT_IP  varchar not NULL,   -- Client IP (*PATTERN*)
  HA_FLAG   integer not NULL default 1, -- Allow/Deny flag, 0 - allow, 1 - deny
  HA_RW   integer default 0,    -- Read/Write flag,  0 - read,  1 - post
  HA_DEST_IP  varchar default '*',    -- Destination IP/Host
  HA_RATE double precision,    -- Rate (hits/second)
  PRIMARY KEY (HA_LIST, HA_ORDER, HA_CLIENT_IP, HA_FLAG))
;

-- HTTP_ACL table upgrade
--!AFTER
alter table HTTP_ACL add HA_LIST varchar not null
;

--!AFTER
alter table HTTP_ACL add HA_ORDER integer not null
;

--!AFTER
alter table HTTP_ACL add HA_RATE double precision	   -- Rate (hits/second).
;

-- triggers to keep in sync in-memory represantation
--!AFTER_AND_BEFORE DB.DBA.HTTP_ACL HA_RATE !
create trigger HTTP_ACL_I after insert on DB.DBA.HTTP_ACL
{
  http_acl_set (HA_LIST, HA_ORDER, HA_CLIENT_IP, HA_FLAG, HA_DEST_IP, HA_OBJECT, HA_RW, coalesce (HA_RATE, 1));
}
;

-- triggers to keep in sync in-memory represantation
--!AFTER_AND_BEFORE DB.DBA.HTTP_ACL HA_RATE !
create trigger HTTP_ACL_U after update on DB.DBA.HTTP_ACL referencing old as O, new as N
{
  http_acl_remove (O.HA_LIST, O.HA_ORDER, O.HA_CLIENT_IP, O.HA_FLAG);
  http_acl_set (N.HA_LIST, N.HA_ORDER, N.HA_CLIENT_IP, N.HA_FLAG, N.HA_DEST_IP, N.HA_OBJECT, N.HA_RW,
	coalesce (N.HA_RATE, 0));
}
;

create trigger HTTP_ACL_D after delete on DB.DBA.HTTP_ACL referencing old as O
{
  http_acl_remove (O.HA_LIST, O.HA_ORDER, O.HA_CLIENT_IP, O.HA_FLAG);
}
;

create view HTTP_PROXY_ACL (HP_SRC, HP_DEST, HP_FLAG)
    as select HA_CLIENT_IP, HA_DEST_IP, HA_FLAG from DB.DBA.HTTP_ACL
    where upper (HA_LIST) = 'PROXY'
;

create view NEWS_ACL (NA_GROUP, NA_IP, NA_A_D, NA_RW)
    as select HA_OBJECT, HA_CLIENT_IP, HA_FLAG, HA_RW from DB.DBA.HTTP_ACL
    where upper (HA_LIST) = 'NEWS'
;


-- Default mapping for WebDAV repository
insert soft DB.DBA.HTTP_PATH
(
    HP_HOST, HP_LISTEN_HOST, HP_LPATH, HP_PPATH, HP_STORE_AS_DAV, HP_DIR_BROWSEABLE, HP_DEFAULT,
    HP_SECURITY, HP_REALM, HP_AUTH_FUNC, HP_POSTPROCESS_FUNC, HP_RUN_VSP_AS, HP_RUN_SOAP_AS, HP_PERSIST_SES_VARS)
    values ( '*ini*', '*ini*', '/DAV', '/DAV/', 1, 1, NULL, NULL, NULL, NULL, NULL, 'dba', NULL, 0
)
;

-- Default page for BLOGs
--insert soft DB.DBA.HTTP_PATH
--(
--    HP_HOST, HP_LISTEN_HOST, HP_LPATH, HP_PPATH, HP_STORE_AS_DAV, HP_DIR_BROWSEABLE, HP_DEFAULT,
--    HP_SECURITY, HP_REALM, HP_AUTH_FUNC, HP_POSTPROCESS_FUNC, HP_RUN_VSP_AS, HP_RUN_SOAP_AS, HP_PERSIST_SES_VARS,
--    HP_OPTIONS)
--    values ( '*ini*', '*ini*', '/blog', '/DAV/', 1, 0, 'index.vspx;index.vsp;index.html;index.xml',
--	     NULL, NULL, NULL, 'DB.DBA.BLOG_RSS2WML_PP', 'dba', NULL, 0, NULL
--)
--;

-- TrackBack URL
--insert soft DB.DBA.HTTP_PATH (HP_HOST, HP_LISTEN_HOST, HP_LPATH, HP_PPATH, HP_RUN_SOAP_AS, HP_PERSIST_SES_VARS,
--  HP_STORE_AS_DAV, HP_DIR_BROWSEABLE, HP_SOAP_OPTIONS)
--  values ('*ini*', '*ini*','/mt-tb','/SOAP','MT', 0, 0, 0, serialize (vector ('XML-RPC', 'yes')))
--;

--insert soft DB.DBA.HTTP_PATH (HP_HOST, HP_LISTEN_HOST, HP_LPATH, HP_PPATH, HP_RUN_SOAP_AS, HP_PERSIST_SES_VARS,
--  HP_STORE_AS_DAV, HP_DIR_BROWSEABLE, HP_SOAP_OPTIONS)
--  values ('*ini*', '*ini*','/Atom','/SOAP','MT', 0, 0, 0, null)
--;

insert soft DB.DBA.HTTP_PATH
(
    HP_HOST, HP_LISTEN_HOST, HP_LPATH, HP_PPATH, HP_STORE_AS_DAV, HP_DIR_BROWSEABLE, HP_DEFAULT,
    HP_SECURITY, HP_REALM, HP_AUTH_FUNC, HP_POSTPROCESS_FUNC, HP_RUN_VSP_AS, HP_RUN_SOAP_AS, HP_PERSIST_SES_VARS)
    values ( '*sslini*', '*sslini*', '/DAV', '/DAV/', 1, 1, NULL, NULL, NULL, NULL, NULL, 'dba', NULL, 0
)
;

-- Default mapping for admin pages
insert soft DB.DBA.HTTP_PATH
(
    HP_HOST, HP_LISTEN_HOST, HP_LPATH, HP_PPATH, HP_STORE_AS_DAV, HP_DIR_BROWSEABLE, HP_DEFAULT,
    HP_SECURITY, HP_REALM, HP_AUTH_FUNC, HP_POSTPROCESS_FUNC, HP_RUN_VSP_AS, HP_RUN_SOAP_AS, HP_PERSIST_SES_VARS)
    values ( '*ini*', '*ini*', '/admin', '/admin/', 0, 0, 'admin_main.vsp', NULL, NULL, NULL, NULL, 'dba', NULL, 0
)
;

insert soft DB.DBA.HTTP_PATH
(
    HP_HOST, HP_LISTEN_HOST, HP_LPATH, HP_PPATH, HP_STORE_AS_DAV, HP_DIR_BROWSEABLE, HP_DEFAULT,
    HP_SECURITY, HP_REALM, HP_AUTH_FUNC, HP_POSTPROCESS_FUNC, HP_RUN_VSP_AS, HP_RUN_SOAP_AS, HP_PERSIST_SES_VARS)
    values ( '*sslini*', '*sslini*', '/admin', '/admin/', 0, 0, 'admin_main.vsp', NULL, NULL, NULL, NULL, 'dba', NULL, 0
)
;

insert soft DB.DBA.HTTP_PATH
(
    HP_HOST, HP_LISTEN_HOST, HP_LPATH, HP_PPATH, HP_STORE_AS_DAV, HP_DIR_BROWSEABLE, HP_DEFAULT,
    HP_SECURITY, HP_REALM, HP_AUTH_FUNC, HP_POSTPROCESS_FUNC, HP_RUN_VSP_AS, HP_RUN_SOAP_AS, HP_PERSIST_SES_VARS)
    values ( '*ini*', '*ini*', '/mime', '/mime/', 0, 0, NULL, NULL, NULL, NULL, NULL, 'dba', NULL, 0
)
;

insert soft DB.DBA.HTTP_PATH
(
    HP_HOST, HP_LISTEN_HOST, HP_LPATH, HP_PPATH, HP_STORE_AS_DAV, HP_DIR_BROWSEABLE, HP_DEFAULT,
    HP_SECURITY, HP_REALM, HP_AUTH_FUNC, HP_POSTPROCESS_FUNC, HP_RUN_VSP_AS, HP_RUN_SOAP_AS, HP_PERSIST_SES_VARS)
    values ( '*ini*', '*ini*', '/images', '/images/', 0, 0, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0
)
;

insert soft DB.DBA.HTTP_PATH
(
    HP_HOST, HP_LISTEN_HOST, HP_LPATH, HP_PPATH, HP_STORE_AS_DAV, HP_DIR_BROWSEABLE, HP_DEFAULT,
    HP_SECURITY, HP_REALM, HP_AUTH_FUNC, HP_POSTPROCESS_FUNC, HP_RUN_VSP_AS, HP_RUN_SOAP_AS, HP_PERSIST_SES_VARS)
    values ( '*sslini*', '*sslini*', '/mime', '/mime/', 0, 0, NULL, NULL, NULL, NULL, NULL, 'dba', NULL, 0
)
;

-- Documentation directory
insert soft DB.DBA.HTTP_PATH
(
    HP_HOST, HP_LISTEN_HOST, HP_LPATH, HP_PPATH, HP_STORE_AS_DAV, HP_DIR_BROWSEABLE, HP_DEFAULT,
    HP_SECURITY, HP_REALM, HP_AUTH_FUNC, HP_POSTPROCESS_FUNC, HP_RUN_VSP_AS, HP_RUN_SOAP_AS, HP_PERSIST_SES_VARS)
    values ( '*ini*', '*ini*', '/doc', '/doc/', 0, 0, NULL, NULL, NULL, NULL, NULL, 'dba', NULL, 0
)
;

-- Documentation directory
insert soft DB.DBA.HTTP_PATH
(
    HP_HOST, HP_LISTEN_HOST, HP_LPATH, HP_PPATH, HP_STORE_AS_DAV, HP_DIR_BROWSEABLE, HP_DEFAULT,
    HP_SECURITY, HP_REALM, HP_AUTH_FUNC, HP_POSTPROCESS_FUNC, HP_RUN_VSP_AS, HP_RUN_SOAP_AS, HP_PERSIST_SES_VARS)
    values ( '*sslini*', '*sslini*', '/doc', '/doc/', 0, 0, NULL, NULL, NULL, NULL, NULL, 'dba', NULL, 0
)
;

-- Default mapping for SOAP
insert soft DB.DBA.HTTP_PATH
(
    HP_HOST, HP_LISTEN_HOST, HP_LPATH, HP_PPATH, HP_STORE_AS_DAV, HP_DIR_BROWSEABLE, HP_DEFAULT,
    HP_SECURITY, HP_REALM, HP_AUTH_FUNC, HP_POSTPROCESS_FUNC, HP_RUN_VSP_AS, HP_RUN_SOAP_AS, HP_PERSIST_SES_VARS)
    values ( '*ini*', '*ini*', '/SOAP', '/SOAP/', 0, 0, NULL, NULL, NULL, NULL, NULL, NULL, 'SOAP', 0
)
;

-- Default mapping for SOAP
insert soft DB.DBA.HTTP_PATH
(
    HP_HOST, HP_LISTEN_HOST, HP_LPATH, HP_PPATH, HP_STORE_AS_DAV, HP_DIR_BROWSEABLE, HP_DEFAULT,
    HP_SECURITY, HP_REALM, HP_AUTH_FUNC, HP_POSTPROCESS_FUNC, HP_RUN_VSP_AS, HP_RUN_SOAP_AS, HP_PERSIST_SES_VARS)
    values ( '*sslini*', '*sslini*', '/SOAP', '/SOAP/', 0, 0, NULL, NULL, NULL, NULL, NULL, NULL, 'SOAP', 0
)
;

insert soft DB.DBA.HTTP_PATH
(
    HP_HOST, HP_LISTEN_HOST, HP_LPATH, HP_PPATH, HP_STORE_AS_DAV, HP_DIR_BROWSEABLE, HP_DEFAULT,
    HP_SECURITY, HP_REALM, HP_AUTH_FUNC, HP_POSTPROCESS_FUNC, HP_RUN_VSP_AS, HP_RUN_SOAP_AS, HP_PERSIST_SES_VARS)
    values ( '*ini*', '*ini*', '/vsmx', '/vsmx/', 0, 0, 'vsmx.vspx', NULL, NULL, NULL, NULL, 'dba', NULL, 0
)
;

insert soft DB.DBA.HTTP_PATH
(
    HP_HOST, HP_LISTEN_HOST, HP_LPATH, HP_PPATH, HP_STORE_AS_DAV, HP_DIR_BROWSEABLE, HP_DEFAULT,
    HP_SECURITY, HP_REALM, HP_AUTH_FUNC, HP_POSTPROCESS_FUNC, HP_RUN_VSP_AS, HP_RUN_SOAP_AS, HP_PERSIST_SES_VARS)
    values ( '*sslini*', '*sslini*', '/vsmx', '/vsmx/', 0, 0, 'vsmx.vspx', NULL, NULL, NULL, NULL, 'dba', NULL, 0
)
;

create procedure HTTP_PATH_UPGRADE ()
{
  declare arr, new_vhost any;
  if (registry_get ('__http_vd_upgrade') = 'done')
    return;
  for select HP_HOST vhost, HP_LISTEN_HOST lhost, HP_LPATH lpath from DB.DBA.HTTP_PATH where HP_HOST not in ('*ini*', '*sslini*') do
    {
      arr := split_and_decode (vhost, 0, ':=:');
      if (length (arr) > 1)
        {
	  new_vhost := arr[0];
	  if (exists (select 1 from DB.DBA.HTTP_PATH where HP_HOST = new_vhost and HP_LISTEN_HOST = lhost and HP_LPATH = lpath))
	    log_message (sprintf ('The virtual directory at host=[%s] path=[%s] conflict with an existing, and cannot be upgraded.', vhost, lpath));
	  else
	    update DB.DBA.HTTP_PATH set HP_HOST = new_vhost where HP_HOST = vhost and HP_LISTEN_HOST = lhost and HP_LPATH = lpath;
	}
    }
  registry_set ('__http_vd_upgrade', 'done');
}
;

HTTP_PATH_UPGRADE ()
;

create procedure HTTP_SET_DBA_ADMIN (in realm varchar)
{
  declare auth, _user varchar;
  auth := vsp_auth_vec (http_request_header());
  if (isarray (auth) and http_path () like '/admin/%' and http_path () not like '/admin/admin_dav/%'
      and http_path () not like 'admin/admin_news/%')
    {
      _user := get_keyword ('username', auth, '');
      if (exists (select 1 from DB.DBA.SYS_USERS where U_NAME = _user and U_GROUP = 0))
  {
    __set_user_id (_user, 0);
    set_qualifier ('DB');
  }
    }
  return 1;
}
;


create procedure
DB.DBA.IS_EMPTY_OR_NULL (in x any)
{
  if (x is null or '' = x or 0 = x)
    return 1;
  return 0;
}
;


-- Inserts new entry in map table
create procedure INS_VIRTUAL_DIR (in lpath varchar, in ppath varchar)
{
  declare is_dav integer;
  if (DB.DBA.IS_EMPTY_OR_NULL (lpath) or DB.DBA.IS_EMPTY_OR_NULL (ppath))
    return NULL;
  is_dav := 0;
  if (aref (lpath, length (lpath) - 1) = ascii ('/') and length (lpath) > 1)
    lpath := substring (lpath, 1, length (lpath) - 1);
  if (aref (ppath, length (ppath) - 1) <> ascii ('/'))
    ppath := concat (ppath, '/');
  if (ppath like '/DAV/%')
    is_dav := 1;
  insert into DB.DBA.HTTP_PATH (HP_LPATH, HP_PPATH, HP_HOST, HP_LISTEN_HOST,
      HP_STORE_AS_DAV, HP_DIR_BROWSEABLE, HP_PERSIST_SES_VARS)
      values (lpath, ppath, '*ini*', '*ini*', is_dav, 0, 0);
  return http_map_table (lpath, ppath, '*ini*', '*ini*', is_dav);
}
;

-- Remove entry from map table
create procedure DEL_VIRTUAL_DIR (in lpath varchar)
{
  if (DB.DBA.IS_EMPTY_OR_NULL (lpath))
    return NULL;
  delete from DB.DBA.HTTP_PATH where HP_LPATH = lpath and HP_HOST = '*ini*' and HP_LISTEN_HOST = '*ini*';
  return http_map_del (lpath, '*ini*', '*ini*');
}
;

-- Add new virtual host / directory
--!AFTER_AND_BEFORE DB.DBA.HTTP_PATH HP_IS_DEFAULT_HOST !
create procedure VHOST_DEFINE (in vhost varchar := '*ini*',
                               in lhost varchar := '*ini*',
                               in lpath varchar,
             in ppath varchar,
             in is_dav integer := 0,
             in is_brws integer := 0,
             in def_page varchar := null,
             in auth_fn varchar := null,
             in realm varchar := null,
             in ppr_fn varchar := null,
             in vsp_user varchar := null,
             in soap_user varchar := null,
             in sec varchar := null,
             in ses_vars integer := 0,
             in soap_opts any := null,
             in auth_opts any := null,
             in opts any := null,
             in is_default_host integer := 0)
{
  declare ssl_port varchar;
  declare ssl_opts any;
  declare varr, lport any;
  if (length (lpath) > 1 and aref (lpath, length (lpath) - 1) = ascii ('/') )
    lpath := substring (lpath, 1, length (lpath) - 1);
--  if (aref (ppath, length (ppath) - 1) <> ascii ('/'))
--    ppath := concat (ppath, '/');
  if (lpath not like '/%' or (ppath not like '/%' and lower(ppath) not like 'http://%'))
    signal ('22023', 'Missing leading slash in lpath or ppath parameter.', 'HT058');

  if (ppath like '/DAV/%' and is_dav <> 1)
    signal ('22023', 'The physical path must points to the dav domain.', 'HT044');

  if (is_default_host and (lhost = '*ini*' or lhost = '*sslini*'))
    signal ('22023', 'The default directory for default web site can be changed only from the INI file.', 'HT060');

  lhost := replace (lhost, '0.0.0.0', '');

  ssl_port := coalesce (server_https_port (), '');
  if (isstring (server_http_port ()))
    {
      varr := split_and_decode (
         case
           when vhost = '*ini*' then server_http_port ()
           when vhost = '*sslini*' then ssl_port
           else vhost
         end
       , 0, ':=:');
      lport := split_and_decode (
         case
           when lhost = '*ini*' then server_http_port ()
           when lhost = '*sslini*' then ssl_port
           else lhost
         end
       , 0, ':=:');

      if (__tag (varr) = 193 and length (varr) > 1)
	vhost := varr[0];

      if (__tag (lport) = 193 and length (lport) > 1)
	lport := aref (lport, 1);
      else if (lhost = '*ini*')
	lport := server_http_port ();
      else if (lhost = '*sslini*')
	lport := ssl_port;
      else if (atoi (lhost))
	lport := lhost;
      else
	lport := '80';
    }
  else
    lport := null;

  if (lport = server_http_port () and lhost <> '*ini*')
    lhost := '*ini*';
  else if (lport = ssl_port and lhost <> '*sslini*')
    lhost := '*sslini*';

  ssl_opts := NULL;
  if (isstring (sec) and upper (sec) = 'SSL')
    {
      if (not isarray (auth_opts) or '' = get_keyword ('https_cert', auth_opts, '') or
    '' = get_keyword ('https_key', auth_opts, ''))
      signal ('22023', 'At least certificate and key files should be supplied for HTTPS listener.', 'HT046');
      ssl_opts := auth_opts;
    }

  if (opts is not null and mod(length (opts), 2) <> 0)
      signal ('22023', 'The global options should be an array with even length or NULL.', 'HT056');

  if (is_default_host = 1 and
      exists (select 1 from DB.DBA.HTTP_PATH where HP_LISTEN_HOST = lhost and HP_IS_DEFAULT_HOST = 1))
      signal ('22023', sprintf ('The default directory is already specified for interface %s.', lhost), 'HT058');

  if (is_default_host = 1 and
      exists (select 1 from DB.DBA.HTTP_PATH where HP_LISTEN_HOST = lhost and HP_HOST = lhost))
      signal ('22023', sprintf ('The default directory for interface %s conflicts with existing directory entry for host (%s) and interface (%s).', lhost, lhost, lhost), 'HT059');

  if (lhost[0] <> ascii ('*') and lport is not null and
      lhost not like ':%' and exists (select 1 from DB.DBA.HTTP_PATH where HP_LISTEN_HOST = ':'||lport))
    {
       signal ('22023', 'The specified port to listen is already occupied by another listener on all network interfaces', 'HT078');
    }
  if (lhost[0] <> ascii ('*') and lport is not null and
      lhost = ':'||lport and exists (select 1 from DB.DBA.HTTP_PATH where HP_LISTEN_HOST like '%_:'||lport))
    {
       signal ('22023', 'The specified port to listen on all interfaces is already occupied by another listener on a separate network interface', 'HT079');
    }

  if (isstring (server_http_port()) and isstring (lhost) and lhost <> '*ini*' and
      lhost <> server_http_port() and lhost <> '*sslini*' and lhost <> ssl_port and
      not exists (select 1 from DB.DBA.HTTP_PATH where HP_LISTEN_HOST = lhost))
    {
      http_listen_host (lhost, 0, ssl_opts);
    }

  insert into DB.DBA.HTTP_PATH (HP_LPATH, HP_PPATH, HP_HOST, HP_LISTEN_HOST,
      HP_STORE_AS_DAV, HP_DIR_BROWSEABLE, HP_PERSIST_SES_VARS,
      HP_DEFAULT, HP_SECURITY, HP_AUTH_FUNC, HP_REALM,
      HP_POSTPROCESS_FUNC, HP_RUN_VSP_AS, HP_RUN_SOAP_AS, HP_SOAP_OPTIONS, HP_AUTH_OPTIONS,
      HP_OPTIONS, HP_IS_DEFAULT_HOST)
      values (lpath, ppath, vhost, lhost, is_dav, is_brws, ses_vars,
      def_page, sec, auth_fn, realm, ppr_fn, vsp_user, soap_user, serialize (soap_opts), serialize (auth_opts),
      serialize (opts), is_default_host);

  if (isstring (server_http_port ()))
    {
      http_map_table (lpath, ppath, vhost, lhost, is_dav, is_brws, def_page,
    sec, realm, auth_fn, ppr_fn, vsp_user, soap_user, ses_vars, soap_opts, auth_opts, opts, is_default_host);
    }

}
;

-- Remove entry from virtual hosts / directories
create procedure VHOST_REMOVE (in vhost varchar := '*ini*',
             in lhost varchar := '*ini*',
             in lpath varchar,
             in del_vsps integer := 0)
{
  declare ssl_port, varr varchar;
  declare ppath, vsp_user, stat, msg varchar;
  declare cr cursor for select HP_PPATH, HP_RUN_VSP_AS from DB.DBA.HTTP_PATH
      where HP_LISTEN_HOST = lhost and HP_HOST = vhost and HP_LPATH = lpath;
  if (DB.DBA.IS_EMPTY_OR_NULL (lpath) or DB.DBA.IS_EMPTY_OR_NULL (vhost) or DB.DBA.IS_EMPTY_OR_NULL (vhost))
    return NULL;

  if (length (lpath) > 1 and aref (lpath, length (lpath) - 1) = ascii ('/') )
    lpath := substring (lpath, 1, length (lpath) - 1);

  lhost := replace (lhost, '0.0.0.0', '');

  ssl_port := coalesce (server_https_port (), '');
  if (isstring (server_http_port ()))
    {
      varr := split_and_decode (
         case
           when vhost = '*ini*' then server_http_port ()
           when vhost = '*sslini*' then ssl_port
           else vhost
         end
       , 0, ':=:');
      if (__tag (varr) = 193 and length (varr) > 1)
	vhost := varr[0];
    }

  whenever not found goto err_exit;
  open cr (exclusive, prefetch 1);
  fetch cr into ppath, vsp_user;
  delete from DB.DBA.HTTP_PATH where current of cr;
  http_map_del (lpath, vhost, lhost);

  if (lhost <> '*ini*' and lhost <> server_http_port() and
      lhost <> '*sslini*' and lhost <> ssl_port and
      not exists (select 1 from DB.DBA.HTTP_PATH where HP_LISTEN_HOST = lhost))
    {
      http_listen_host (lhost, 1);
    }
  for select P_NAME from DB.DBA.SYS_PROCEDURES where del_vsps and P_NAME like concat ('WS.WS.', ppath, '%')
    and P_OWNER = vsp_user do
      {
        stat := '00000'; msg := '';
        exec (sprintf ('DROP PROCEDURE "%I"', P_NAME), stat, msg);
      }
err_exit:
  close cr;
}
;


--!AFTER
WS.WS.URIQA_VHOST_RESET()
;


-- This is called internally via WS..DEFAULT, to check ACL on proxy service
create procedure
HTTP_PROXY_ACCESS (in dst varchar)
returns integer
{
  declare client varchar;
  declare host, ppath any;
  declare rc, rcc int;

  --** an virtual directory is mapped to proxy a host
  ppath := http_map_get ('mounted');
  if (lower (ppath) like 'http://%')
    return 1;

  -- Deny by default
  rc := 0;

  -- Requestor address
  client := http_client_ip ();
  host := split_and_decode (dst, 0, '\0\0:');
  -- Remove the port number if exists
  dst := host[0];

  rcc := http_acl_get ('PROXY', client, dst);
  if (0 = rcc)
    rc := 1;

  return rc;
}
;

--create procedure
--HP_SSL_DEFAULT ()
--{
--  declare port, nam varchar;
--  port := cfg_item_value (virtuoso_ini_path (), 'HTTPServer', 'SSLPort');
--  nam := port;
--  if (strrchr (port, ':') is null and atoi (port) <> 0)
--    {
--      nam := sys_stat ('st_host_name') || ':' || port;
--      port := ':' || port;
--    }
--  if (port is not null)
--    result (nam, port);
--}
--;
--
--create procedure view HP_HTTPS_DEFAULT as HP_SSL_DEFAULT () (HP_HOST varchar, HP_LISTEN_HOST varchar)
--;

create table WS.WS.SYS_RC_CACHE
	(RC_URI varchar,
	 RC_DATA long varchar,
    	 RC_INVALIDATE varchar,
	 RC_DT datetime,
	 RC_TAG varchar,
	 RC_CHARSET varchar,
	 primary key (RC_URI)
	 )
create index RC_IN on WS.WS.SYS_RC_CACHE (RC_INVALIDATE)
;

create table WS.WS.SYS_CACHEABLE (CA_URI varchar, CA_CHECK varchar, primary key (CA_URI))
;

create trigger SYS_CACHEABLE_I after insert on WS.WS.SYS_CACHEABLE
{
  http_url_cache_set (CA_URI, CA_CHECK);
}
;

create trigger SYS_CACHEABLE_U after update on WS.WS.SYS_CACHEABLE referencing old as O, new as N
{
  http_url_cache_set (N.CA_URI, N.CA_CHECK);
}
;

create trigger SYS_CACHEABLE_D after delete on WS.WS.SYS_CACHEABLE
{
  http_url_cache_remove (CA_URI);
  delete from WS.WS.SYS_RC_CACHE where RC_URI = CA_URI;
}
;

create procedure WS.WS.HTTP_CACHE_CHECK (inout path any, inout lines any, inout check_fn any)
{
  declare inv, rc, cnt, tag, charset any;
  inv := null;
  rc := call (check_fn) (path, lines, inv);
  --dbg_obj_print (path, lines, check_fn, inv, rc);
  if (rc)
    {
      whenever not found goto nf;
      select RC_DATA, RC_TAG, RC_CHARSET into cnt, tag, charset from WS.WS.SYS_RC_CACHE where RC_URI = path;
      if (cnt is not null)
	{
	  declare ses, ctag any;
	  ctag := http_request_header (lines, 'If-None-Match');
	  if (not isstring (ctag))
	    ctag := '';
	  if (ctag <> tag)
	    {
	      if (charset is not null)
		{
		  set http_charset=charset;
		}
	      http_header (concat (http_header_get (), 'ETag: "', tag,
		    sprintf ('"\r\nContent-Length: %d\r\n\r\n', length (cnt))));
	      http_flush (2);
	      ses_write (cnt);
	    }
	  else
	    {
	      http_request_status ('HTTP/1.1 304 Not Modified');
	    }
        }
      else
	{
	  http ('<HTML><HEAD><META HTTP-EQUIV="REFRESH" CONTENT="1" /></HEAD>');
	  http ('<BODY>');
	  http ('<P>if you see this for longer than 1 second, please <a href="">click here</a> or reload.</P>');
	  http ('</BODY>');
	  http ('</HTML>');
	}
      return 1;
      nf:
      insert into WS.WS.SYS_RC_CACHE (RC_URI, RC_INVALIDATE, RC_DT) values (path, inv, now ());
      --dbg_obj_print ('new entry is done');
      return 2;
    }
  return 0;
}
;

create procedure WS.WS.HTTP_CACHE_STORE (inout path any, inout store int)
{
  --dbg_obj_print ('to store', path, store);
  declare tag, cnt any;

  --
  -- There is an error or stream is flushed or chunked state is set
  --
  if (not store)
    {
      delete from WS.WS.SYS_RC_CACHE where RC_URI = path;
      return;
    }

  tag := uuid ();
  update WS.WS.SYS_RC_CACHE set RC_DATA = http_get_string_output (1000000),
      RC_TAG = tag,
      RC_CHARSET = http_current_charset ()
      where RC_URI = path;
  if (row_count ())
    {
      http_header (concat (http_header_get (), 'ETag: "', tag, '"\r\n'));
    }
}
;

