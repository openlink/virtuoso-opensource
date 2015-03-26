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

-- XXX: no longer needed, obsoleted
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

-- Default mappings to be created on all existing listeners
create table DB.DBA.HTTP_PATH_DEFAULT (
HPD_LPATH        varchar not null, -- logical path
HPD_PPATH    varchar not null, -- physical path
HPD_STORE_AS_DAV   integer not null, -- flag for webDAV storage
HPD_DIR_BROWSEABLE   integer not null, -- directory listing allowed
HPD_DEFAULT    varchar,    -- default page
HPD_REALM          varchar,          -- authentication realm
HPD_AUTH_FUNC      varchar,          -- witch function authenticate this directory
HPD_POSTPROCESS_FUNC varchar,          -- function call after request
HPD_RUN_VSP_AS     varchar,          -- uid for VSPs REFERENCES SYS_USERS (U_NAME) ON DELETE SET NULL
HPD_RUN_SOAP_AS    varchar,          -- uid for SOAP REFERENCES SYS_USERS (U_NAME) ON DELETE SET NULL
HPD_PERSIST_SES_VARS integer not null, -- have a persistent session variables
HPD_SOAP_OPTIONS long varchar,   -- SOAP options
HPD_AUTH_OPTIONS varchar,    -- Authentication options
HPD_OPTIONS    any,      -- Global options
HPD_IS_DEFAULT_HOST  integer,    -- default host mapping
primary key (HPD_LPATH)
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
HA_LIMIT  integer default 0,
PRIMARY KEY (HA_LIST, HA_ORDER, HA_CLIENT_IP, HA_FLAG))
;

--#IF VER=5
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

--#ENDIF
alter table HTTP_ACL add HA_LIMIT integer default 0
;

-- triggers to keep in sync in-memory representation
--#IF VER=5
--!AFTER_AND_BEFORE DB.DBA.HTTP_ACL HA_RATE !
--#ENDIF
create trigger HTTP_ACL_I after insert on DB.DBA.HTTP_ACL
{
  declare def_rate int;
  if (HA_LIST <> 'NEWS')
    def_rate := 0;
  else
    def_rate := 1;
  http_acl_set (HA_LIST, HA_ORDER, HA_CLIENT_IP, HA_FLAG, HA_DEST_IP, HA_OBJECT, HA_RW, coalesce (HA_RATE, def_rate), HA_LIMIT);
}
;

-- triggers to keep in sync in-memory representation
--#IF VER=5
--!AFTER_AND_BEFORE DB.DBA.HTTP_ACL HA_RATE !
--#ENDIF
create trigger HTTP_ACL_U after update on DB.DBA.HTTP_ACL referencing old as O, new as N
{
  http_acl_remove (O.HA_LIST, O.HA_ORDER, O.HA_CLIENT_IP, O.HA_FLAG);
  http_acl_set (N.HA_LIST, N.HA_ORDER, N.HA_CLIENT_IP, N.HA_FLAG, N.HA_DEST_IP, N.HA_OBJECT, N.HA_RW,
      coalesce (N.HA_RATE, 0), N.HA_LIMIT);
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
values ( '*ini*', '*ini*', '/install', '/install/', 0, 0, 'install.vspx', NULL, NULL, NULL, NULL, 'dba', NULL, 0
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

--#IF VER=5
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
--#ENDIF

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
--#IF VER=5
--!AFTER_AND_BEFORE DB.DBA.HTTP_PATH HP_IS_DEFAULT_HOST !
--#ENDIF
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
if (isstring (sec) and upper (sec) = 'SSL' and
  not exists (select 1 from DB.DBA.HTTP_PATH where HP_LISTEN_HOST = lhost))
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

create procedure VHOST_MAP_RELOAD (in vhost varchar := '*ini*', in lhost varchar := '*ini*', in lpath varchar)
{
declare ssl_port, varr varchar;
declare ret int;

if (DB.DBA.IS_EMPTY_OR_NULL (lpath) or DB.DBA.IS_EMPTY_OR_NULL (lhost))
return NULL;
http_map_del (lpath, vhost, lhost);
ret := 0;
for select
      HP_LPATH,
      HP_PPATH,
      HP_HOST,
      HP_LISTEN_HOST,
      HP_STORE_AS_DAV,
      HP_DIR_BROWSEABLE,
      HP_DEFAULT,
      HP_SECURITY,
      HP_REALM,
      HP_AUTH_FUNC,
      HP_POSTPROCESS_FUNC,
      HP_RUN_VSP_AS,
      HP_RUN_SOAP_AS,
      HP_PERSIST_SES_VARS,
      HP_SOAP_OPTIONS,
      HP_AUTH_OPTIONS,
      HP_OPTIONS,
      HP_IS_DEFAULT_HOST
from DB.DBA.HTTP_PATH where
HP_LPATH = lpath and HP_HOST = vhost and HP_LISTEN_HOST = lhost
do
  {
    http_map_table (
      HP_LPATH,
      HP_PPATH,
      HP_HOST,
      HP_LISTEN_HOST,
      HP_STORE_AS_DAV,
      HP_DIR_BROWSEABLE,
      HP_DEFAULT,
      HP_SECURITY,
      HP_REALM,
      HP_AUTH_FUNC,
      HP_POSTPROCESS_FUNC,
      HP_RUN_VSP_AS,
      HP_RUN_SOAP_AS,
      HP_PERSIST_SES_VARS,
      deserialize (HP_SOAP_OPTIONS),
      deserialize (HP_AUTH_OPTIONS),
      deserialize (HP_OPTIONS),
      HP_IS_DEFAULT_HOST);
    ret := ret + 1;
  }
return ret;
}
;

-- Remove entry from virtual hosts / directories
create procedure VHOST_REMOVE (in vhost varchar := '*ini*',
	 in lhost varchar := '*ini*',
	 in lpath varchar,
	 in del_vsps integer := 0)
{
declare ssl_port, varr, lport varchar;
declare ppath, vsp_user, stat, msg varchar;
declare cr cursor for select HP_PPATH, HP_RUN_VSP_AS from DB.DBA.HTTP_PATH
  where HP_LISTEN_HOST = lhost and HP_HOST = vhost and HP_LPATH = lpath;
if (DB.DBA.IS_EMPTY_OR_NULL (lpath) or DB.DBA.IS_EMPTY_OR_NULL (lhost))
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

--!AFTER
WS.WS.SPARQL_VHOST_RESET()
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

-- Requester address
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
--  port := virtuoso_ini_item_value ('HTTPServer', 'SSLPort');
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
declare inv, rc, cnt, tag, charset, url, qstr, sch any;
inv := null;

if (is_https_ctx ())
sch := 'https://';
else
sch := 'http://';

qstr := http_request_get ('QUERY_STRING');
url := sch || http_request_header(lines, 'Host', null, '') || path;
if (length (qstr))
url := url || '?' || qstr;
rc := call (check_fn) (url, lines, inv);
--dbg_obj_print ('HTTP_CACHE_CHECK: ', url, check_fn, inv, rc);
if (rc)
{
  whenever not found goto nf;
  select RC_DATA, RC_TAG, RC_CHARSET into cnt, tag, charset from WS.WS.SYS_RC_CACHE where RC_URI = url;
  commit work;
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
	  http_header (concat (http_header_get (), sprintf ('ETag: "%s"\r\n', tag)));
	  http (cnt);
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
  insert into WS.WS.SYS_RC_CACHE (RC_URI, RC_INVALIDATE, RC_DT) values (url, inv, now ());
  commit work;
  --dbg_obj_print ('new entry is done');
  return 2;
}
return 0;
}
;

create procedure WS.WS.HTTP_CACHE_STORE (inout path any, inout store int)
{
declare tag, cnt any;
declare url, qstr, sch any;

if (is_https_ctx ())
sch := 'https://';
else
sch := 'http://';

qstr := http_request_get ('QUERY_STRING');
url := sch || http_request_header(http_request_header (), 'Host', null, '') || path;
if (length (qstr))
url := url || '?' || qstr;

--dbg_obj_print ('to store', path, url, store);
--
-- There is an error or stream is flushed or chunked state is set
--
if (not store)
{
  delete from WS.WS.SYS_RC_CACHE where RC_URI = url;
  return;
}

tag := uuid ();
update WS.WS.SYS_RC_CACHE set RC_DATA = http_get_string_output (1000000),
  RC_TAG = tag,
  RC_CHARSET = http_current_charset ()
  where RC_URI = url;
if (row_count ())
{
  http_header (concat (http_header_get (), 'ETag: "', tag, '"\r\n'));
}
}
;

-- /* extended http proxy service */
create procedure virt_proxy_init ()
{
  if (not exists (select 1 from "DB"."DBA"."SYS_USERS" where U_NAME = 'PROXY'))
    DB.DBA.USER_CREATE ('PROXY', uuid(), vector ('DISABLED', 1));
  if (registry_get ('DB.DBA.virt_proxy_init_state') = '1.1')
    return;
  DB.DBA.URLREWRITE_CREATE_REGEX_RULE ('ext_http_proxy_rule_1', 1,
      '/proxy/([^/\?\&]*)?/?([^/\?\&:]*)/(.*)', vector ('force', 'login', 'url'), 2,
      '/proxy?url=%U&force=%U&login=%U', vector ('url', 'force', 'login'), null, null, 2);
  DB.DBA.URLREWRITE_CREATE_RULELIST ('ext_http_proxy_rule_list1', 1, vector ('ext_http_proxy_rule_1'));
  DB.DBA.VHOST_REMOVE (lpath=>'/proxy');
  DB.DBA.VHOST_DEFINE (lpath=>'/proxy', ppath=>'/SOAP/Http/ext_http_proxy', soap_user=>'PROXY',
      opts=>vector('url_rewrite', 'ext_http_proxy_rule_list1'));
  registry_set ('DB.DBA.virt_proxy_init_state', '1.1');
}
;

create procedure
proxy_sp_html_error_page (in title varchar, in hd varchar, in message varchar)
{
  http ('<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01//EN" "http://www.w3.org/TR/html4/strict.dtd">');
  http ('<html>');
  http ('<head>');
  http ('  <title>' || title || '</title>');
  http ('  <style type="text/css">');
  http ('  </style>');
  http ('</head>');
  http ('<body>');
  http ('  <h1>' || hd || '</h1>');
  http ('  <p>' || message || '</p>');
  http ('</body>');
  http ('</html>');
}
;


--
-- Python-style format - takes a format string and an array of params.
-- It''s handier for templating, etc.
--

create procedure
str_fmt (in fmt_str varchar, in parm_arr any)
{
  declare f_l,l,p,st,cnt integer;
  declare s varchar;

  s := '';
  st := 1;
  l := length (parm_arr);
  f_l := length (fmt_str);

  while (1)
    {
      p := locate ('%', fmt_str, st);

      if (p = 0)
        {
	  if (cnt < l)
	    signal ('42000','Too many values in parm_arr in str_fmt');

	  if (cnt > l)
	    signal ('42000', 'Too few values in parm_arr in str_fmt');

          if (st < f_l)
            s := s || subseq (fmt_str, st-1, f_l);
	  return s;
        }

-- XXX should make special case for %{XXX}U and any other multiple char parms to generalise further

      p := p + 1;

      s := s || sprintf (subseq (fmt_str, st-1, p), parm_arr[cnt]);
      cnt := cnt + 1;
      st := p + 1;
    }
}
;

-- Run a canned query with supplied param values
-- XXX XXX check for potential SQL injection vuln !

create table DB.DBA.PROXY_SP_QRY (
  pspq_id integer identity,
  pspq_qry varchar,
  pspq_n_parms integer,
  pspq_def_values any,
  pspq_descr varchar,
  pspq_expln varchar,
  pspq_isparql_path varchar,
  primary key (pspq_id)
)
;

create procedure
ext_http_proxy_exec_qry (in exec varchar, in params any)
{
  declare qt, stat, msg, accept varchar;
  declare metas, rset, triples, ses any;
  declare parm_arr any;

  stat := '00000';

  set_user_id ('SPARQL');

  declare exit handler for not found
    {
      http_request_status ('HTTP/1.1 400 Bad request');
      proxy_sp_html_error_page ('Error: invalid query id', 'Invalid Query ID', 'The query id was invalid.');
    };

  declare _qry varchar;
  declare _n_parms integer;

  select pspq_qry, pspq_n_parms
    into _qry, _n_parms
    from proxy_sp_qry
    where pspq_id = exec;

  parm_arr := make_array (_n_parms, 'any');

  declare parm_cnt integer;
  parm_cnt := 0;

  for (declare i, l int, i := 0, l := length (params); i < l; i := i + 2)
    {
      if (params[i] like 'p%')
        {
          aset (parm_arr, atoi ("RIGHT" (params[i], length (params[i]) - 1)) - 1, params[i+1]);
	  parm_cnt := parm_cnt + 1;
        }
    }

  if (parm_cnt < _n_parms)
    {
      http_rewrite();
      http_request_status ('HTTP/1.1 400 Bad request');
      proxy_sp_html_error_page ('Error: insufficient no of params',
        		        'Insufficient number of parameters',
                                'This query takes exactly ' || cast (_n_parms as varchar) || ' parameters');
      return;
    }

  declare xec_str varchar;
  xec_str := str_fmt (_qry, parm_arr);
  exec (xec_str, stat, msg, vector (), 0, metas, rset);

  accept := 'application/rdf+xml';

  if (stat <> '00000')
    signal (stat, msg);

  ses := string_output (1000000);
  commit work;

  http_rewrite();

  if (rset is not null)
    DB.DBA.SPARQL_RESULTS_WRITE (ses, metas, rset, accept, 1);

  http (ses);
}
;

-- XXX now REALLY check for that SQL injection!

create procedure
ext_http_proxy (in url varchar := null,
                in exec varchar := null,
                in header varchar := null,
                in force varchar := null,
                in "output-format" varchar := null,
                in get varchar := 'add',
                in login varchar := '') __SOAP_HTTP 'text/html'
{
  declare hdr, content, req_hdr any;
  declare ct, in_hdr, new_hdr varchar;
  declare stat, msg, metas, accept, rset, triples, ses, arr any;
  declare local_qry integer;
  declare params, ids any;

  local_qry := 0;
  params := http_param ();

  -- removal of any existing content type as sparql will add it
  in_hdr := http_header_get ();
  new_hdr := '';
  if (in_hdr is not null)
    new_hdr := regexp_replace (in_hdr, 'Content-Type:[^\r\n]+\r\n', '');
  http_header (new_hdr);

  if (exec is not null)
    {
      ext_http_proxy_exec_qry (exec, params);
      return '';
    }

  req_hdr := null;

  if (header is not null)
    req_hdr := header;

  if (0 = length (url))
    {
      http_rewrite();
      http_request_status ('HTTP/1.1 400 Bad request');
      proxy_sp_html_error_page ('Error: insufficient no of params',
        		        'Insufficient number of parameters',
                                'This service expects "url" input argument which is not supplied.');
      return '';
    }

  arr := rfc1808_parse_uri (url);
  arr[5] := '';

  if (arr[0] = 'nodeID')
    arr[2] := '';

  url := DB.DBA.vspx_uri_compose (arr);

  if (force is not null)
    {
      if (lower (force) = 'rdf')
	{
	  declare defs, host, pref, sponge any;
	  defs := '';
	  for (declare i,l int, i := 0, l := length (params); i < l; i := i + 2)
	    {
	      if (params[i] like 'sparql_%')
		{
		  declare nam varchar;
		  nam := subseq (params[i], 7);
		  if (nam in ('local')) {
		    local_qry := 1; -- special dirty hack case for b3s queries
		    defs := '';
		    goto end_loop;
		  }
		  if (nam in ('input:grab-depth', 'input:grab-limit', 'sql:log-enable', 'sql:signal-void-variables'))
		    defs := defs || ' define '||nam||' '||params[i+1]||' ';
		  else
		    defs := defs || ' define '||nam||' "'||params[i+1]||'" ';
		}
	    }
end_loop:;
	  set http_charset='utf-8';
          accept := '';
	  if (header is not null and length (header))
	    accept := http_request_header (split_and_decode (header, 0, '\0\0\r\n'), 'Accept', null, null);
	  else
	    {
	      accept := http_request_header_full (http_request_header(), 'Accept', '*/*');
	      accept := HTTP_RDF_GET_ACCEPT_BY_Q (accept);
	      if (accept is null or accept = '*/*')
	        accept := 'application/rdf+xml';
	    }
	  if ("output-format" is not null)
	    {
	      if ("output-format" = 'rdf' or "output-format" = 'rdf+xml' or "output-format" = 'xml')
		accept := 'application/rdf+xml';
	      else if ("output-format" = 'ttl' or "output-format" = 'turtle')
		accept := 'text/turtle';
	      else if ("output-format" = 'n3')
		accept := 'text/rdf+n3';
              else if ("output-format" = 'nt' or "output-format" = 'txt')
                accept := 'text/n3';
              else if ("output-format" = 'json')
                accept := 'application/json';
              else
                accept := "output-format";
	    }
          stat := '00000';
	  if (get not in ('soft', 'replacing', 'add', 'none'))
	    get := 'add';
	  if (length (login))
	    login := concat ('define get:login "', login, '" ');
	  else
	    login := '';
	  host := http_request_header(http_request_header(), 'Host', null, null);
	  ids := vector ('rdf', 'id/entity', 'id');
	  if (not exists (select 1 from RDF_QUAD where G = iri_to_id (url, 0)))
	    {
	  foreach (varchar idn in ids) do
	    {
	      pref := 'http://' || host || http_map_get ('domain') || '/' || idn || '/';
	  if (url like pref || '%')
		{
	    url := subseq (url, length (pref));
		  if (url like 'http/%')
		    url := 'http:/' || subseq (url, 4);
		  else if (url like 'https/%')
		    url := 'https:/' || subseq (url, 5);
		  else if (url like 'nodeID/%')
		    url := 'nodeID:/' || subseq (url, 6);
		}
	    }
	    }
	  -- escape chars which are not allowed
	  url := replace (url, '''', '%27');
	  url := replace (url, '<', '%3C');
	  url := replace (url, '>', '%3E');
	  url := replace (url, ' ', '%20');

	  if (get = 'none')
	    sponge := '';
          else
	  sponge := sprintf ('define get:soft "%s"', get);

	  set_user_id ('SPARQL');

	  if (local_qry)
            {
	      exec (sprintf ('sparql %s DESCRIBE <%S>', defs, url), stat, msg, vector (), 0, metas, rset);
            }

          else
            if (url not like 'nodeID://%')
	      {
	        exec (sprintf ('sparql %s %s %s CONSTRUCT { ?s ?p ?o } FROM <%S> WHERE { ?s ?p ?o }',
	              defs, login, sponge, url), stat, msg, vector (), 0, metas, rset);
              }
	    else
	      {
	        exec (sprintf ('sparql %s DESCRIBE <%S>', defs, url), stat, msg, vector (), 0, metas, rset);
	      }

	  if (stat <> '00000')
	    signal (stat, msg);

	  ses := string_output (1000000);
	  commit work;
	  DB.DBA.SPARQL_RESULTS_WRITE (ses, metas, rset, accept, 1);

	  for select HS_EXPIRATION, HS_LAST_MODIFIED, HS_LAST_ETAG
	    from DB.DBA.SYS_HTTP_SPONGE where HS_LOCAL_IRI = url and HS_PARSER = 'DB.DBA.RDF_LOAD_HTTP_RESPONSE' do
	  {
	    if (HS_LAST_MODIFIED is not null)
	      http_header (http_header_get () || sprintf ('Last-Modified: %s\r\n', date_rfc1123 (HS_LAST_MODIFIED)));
	    if (HS_LAST_ETAG is not null)
	      http_header (http_header_get () || sprintf ('ETag: %s\r\n', HS_LAST_ETAG));
	    if (HS_EXPIRATION is not null)
	      http_header (http_header_get () || sprintf ('Expires: %s\r\n', date_rfc1123 (HS_EXPIRATION)));
	  }
	  -- not true: http_header (http_header_get () || sprintf ('Content-Location: %s\r\n', url));
	  http (ses);
          return '';
	}
      else
        signal ('22023', 'The "force" parameter supports "rdf"');
    }
  {
    declare meth varchar;
    declare body varchar;
    declare pars, head any;
    pars := http_param ();
    head := http_request_header ();
    meth := http_request_get ('REQUEST_METHOD');
    body := '';
    for (declare i, l int, i := 0, l := length (pars); i < l; i := i + 2)
      {
	if (pars[i] <> 'url' and pars[i] <> 'header')
  	  body := body || sprintf ('%U=%U&', pars[i], pars[i + 1]);
      }
    if (length (body))
      body := rtrim (body, '&');
    else
      body := null;
    if (body is null and meth = 'POST')
      meth := 'GET';
    if (req_hdr is null)
      {
	req_hdr := '';
	for (declare i, l int, i := 1, l := length (head); i < l; i := i + 1)
	  {
	    if (lower (head[i]) not like 'host:%' and
	      	lower (head[i]) not like 'keep-alive:%' and
	      	lower (head[i]) not like 'content-length:%' and
	      	lower (head[i]) not like 'connection:%')
	      req_hdr := req_hdr || head[i];
	  }
	req_hdr := rtrim (req_hdr, '\n');
	req_hdr := rtrim (req_hdr, '\r');
	req_hdr := rtrim (req_hdr, '\n');
	if (length (req_hdr) = 0)
	  req_hdr := null;
      }
    content := DB.DBA.RDF_HTTP_URL_GET (url, '', hdr, meth, req_hdr, body);
  }
  ct := http_request_header (hdr, 'Content-Type');
  if (ct is not null)
    http_header (sprintf ('Content-Type: %s\r\n', ct));

  foreach (any hd in hdr) do
    {
      if (regexp_match ('(etag:)|(expires:)|(last-modified:)|(pragma:)|(cache-control:)', lower (hd)) is not null)
	http_header (http_header_get () || hd);
    }

  http (content);
  return '';
}
;

create procedure
DB.DBA.VHOST_DUMP_SQL (in lpath varchar, in vhost varchar := '*ini*', in lhost varchar := '*ini*')
{
  declare ses any;
  ses := string_output ();
  for select
    HP_PPATH,
    HP_STORE_AS_DAV,
    HP_DIR_BROWSEABLE,
    HP_DEFAULT,
    HP_SECURITY,
    HP_REALM,
    HP_AUTH_FUNC,
    HP_POSTPROCESS_FUNC,
    HP_RUN_VSP_AS,
    HP_RUN_SOAP_AS,
    HP_PERSIST_SES_VARS,
    HP_SOAP_OPTIONS,
    HP_AUTH_OPTIONS,
    HP_OPTIONS,
    HP_IS_DEFAULT_HOST
    from
    DB.DBA.HTTP_PATH
    where HP_HOST = vhost and HP_LISTEN_HOST = lhost and HP_LPATH = lpath
    do
      {
	http ('DB.DBA.VHOST_REMOVE (\n', ses);
        http (concat ('\t lhost=>', SYS_SQL_VAL_PRINT (lhost), ',\n'), ses);
        http (concat ('\t vhost=>', SYS_SQL_VAL_PRINT (vhost), ',\n'), ses);
        http (concat ('\t lpath=>', SYS_SQL_VAL_PRINT (lpath), '\n'), ses);
        http (');\n\n', ses);
	http ('DB.DBA.VHOST_DEFINE (\n', ses);
        http (concat ('\t lhost=>', SYS_SQL_VAL_PRINT (lhost), ',\n'), ses);
        http (concat ('\t vhost=>', SYS_SQL_VAL_PRINT (vhost), ',\n'), ses);
        http (concat ('\t lpath=>', SYS_SQL_VAL_PRINT (lpath), ',\n'), ses);
        http (concat ('\t ppath=>', SYS_SQL_VAL_PRINT (HP_PPATH), ',\n'), ses);
        http (concat ('\t is_dav=>', SYS_SQL_VAL_PRINT (HP_STORE_AS_DAV), ',\n'), ses);
        http (concat ('\t is_brws=>', SYS_SQL_VAL_PRINT (HP_DIR_BROWSEABLE), ',\n'), ses);
	if (HP_DEFAULT is not null)
        http (concat ('\t def_page=>', SYS_SQL_VAL_PRINT (HP_DEFAULT), ',\n'), ses);
	if (HP_SECURITY is not null)
        http (concat ('\t sec=>', SYS_SQL_VAL_PRINT (HP_SECURITY), ',\n'), ses);
	if (HP_REALM is not null)
        http (concat ('\t realm=>', SYS_SQL_VAL_PRINT (HP_REALM), ',\n'), ses);
	if (HP_AUTH_FUNC is not null)
        http (concat ('\t auth_fn=>', SYS_SQL_VAL_PRINT (HP_AUTH_FUNC), ',\n'), ses);
	if (HP_POSTPROCESS_FUNC is not null)
        http (concat ('\t ppr_fn=>', SYS_SQL_VAL_PRINT (HP_POSTPROCESS_FUNC), ',\n'), ses);
	if (HP_RUN_VSP_AS is not null)
        http (concat ('\t vsp_user=>', SYS_SQL_VAL_PRINT (HP_RUN_VSP_AS), ',\n'), ses);
	if (HP_RUN_SOAP_AS is not null)
        http (concat ('\t soap_user=>', SYS_SQL_VAL_PRINT (HP_RUN_SOAP_AS), ',\n'), ses);
        http (concat ('\t ses_vars=>', SYS_SQL_VAL_PRINT (HP_PERSIST_SES_VARS), ',\n'), ses);
	if (HP_SOAP_OPTIONS is not null and deserialize (HP_SOAP_OPTIONS) is not null)
        http (concat ('\t soap_opts=>', SYS_SQL_VAL_PRINT (deserialize (HP_SOAP_OPTIONS)), ',\n'), ses);
	if (HP_AUTH_OPTIONS is not null and deserialize (HP_AUTH_OPTIONS) is not null)
        http (concat ('\t auth_opts=>', SYS_SQL_VAL_PRINT (deserialize (HP_AUTH_OPTIONS)), ',\n'), ses);
	if (HP_OPTIONS is not null and deserialize (HP_OPTIONS) is not null)
        http (concat ('\t opts=>', SYS_SQL_VAL_PRINT (deserialize (HP_OPTIONS)), ',\n'), ses);
        http (concat ('\t is_default_host=>', SYS_SQL_VAL_PRINT (HP_IS_DEFAULT_HOST), '\n'), ses);
        http (');\n\n', ses);
      }
   return string_output_string (ses);
}
;

-- /* get a header field based on max of quality value */
create procedure DB.DBA.HTTP_RDF_GET_ACCEPT_BY_Q (in accept varchar)
{
  declare format, itm varchar;
  declare arr any;
  declare i, l int;
  declare best_q, q double precision;

  arr := split_and_decode (accept, 0, '\0\0,;');
  best_q := 0;
  l := length (arr);
  format := null;
  for (i := 0; i < l; i := i + 2)
    {
      declare tmp any;
      itm := trim(arr[i]);
      q := arr[i+1];
      if (q is null)
	q := 1.0;
      else
	{
	  tmp := split_and_decode (q, 0, '\0\0=');
	  if (length (tmp) = 2)
	    q := atof (tmp[1]);
	  else
	    q := 1.0;
        }
      if (best_q < q)
        {
	  best_q := q;
	  format := itm;
	}
    }
  return format;
}
;

create procedure DB.DBA.HTTP_RDF_ACCEPT (in path varchar, in virtual_dir varchar, in lines any, in graph_mode int)
{
  declare host, stat, msg, qry, data, meta, accept, format, graph, url, ssl varchar;
  declare ses any;

  ses := 0;
  host := http_request_header(lines, 'Host', null, '');
  accept := http_request_header_full (lines, 'Accept', '*/*');
  qry := http_request_get ('QUERY_STRING');
  ssl := '';
  if (is_https_ctx ())
    ssl := 's';
  if (length (qry))
    path := path || '?' || qry;

  format := HTTP_RDF_GET_ACCEPT_BY_Q (accept);

  if (format is null)
    accept := http_request_header (lines, 'Accept', null, null);

  --dbg_printf ('DB.DBA.HTTP_RDF_ACCEPT: [%s] [%s] [%s] [%d]', path, virtual_dir, format, graph_mode);
  set_user_id ('SPARQL');
  stat := '00000';
  graph := sprintf ('FROM <http%s://%s%s>', ssl, host, virtual_dir);
  if (graph_mode = 2)
    graph := '';
  url := sprintf ('http%s://%s%s', ssl, host, path);
  if (strchr (url, '#') is null)
    qry := sprintf ('SPARQL DESCRIBE <%s> <%s#this> %s', url, url, graph);
  else
    qry := sprintf ('SPARQL DESCRIBE <%s> %s', url, graph);
  exec (qry, stat, msg, vector (), 0, meta, data);
  if (stat = '00000')
    {
      if (length (data) = 1 and length (dict_list_keys (data[0][0], 0)) > 0)
	{
	  http_status_set (200);
	  http_rewrite ();
	  DB.DBA.SPARQL_RESULTS_WRITE (ses, meta, data, format, 1);
	  return 1;
	}
    }
  else
    signal (stat, msg);
  return 0;
}
;

create procedure WS.WS.DIR_INDEX_MAKE_XML (inout _sheet varchar, in curdir varchar := null, in start_from varchar := null)
{
   declare dirarr, filearr, fsize, xte_path, xte_list, xte_entry any;
   declare dirname, root, modt varchar;
   declare ix, len, flen, rflen, mult integer;
   fsize := vector ('b','K','M','G','T');
   if (curdir is null)
     curdir := concat (http_root (), http_physical_path ());
   if (start_from is null)
     start_from := http_path ();
   root := http_root ();
   dirarr := sys_dirlist (curdir, 0, null, 1);
   filearr := sys_dirlist (curdir, 1, null, 1);
   if (curdir <> '\\' and aref (curdir, length (curdir) - 1) <> ascii ('/'))
     curdir := concat (curdir, '/');
   if (start_from <> '/' and aref (start_from, length (start_from) - 1) <> ascii ('/'))
     start_from := concat (start_from, '/');
   xte_nodebld_init (xte_path);
   xte_nodebld_acc (xte_path, xte_node (xte_head ('PATH', 'dir_name', start_from)));
   if (aref (root, length (root) - 1) <> ascii ('/'))
     root := concat (root, '/');
   if (aref (curdir, length (curdir) - 1) <> ascii ('/'))
     curdir := concat (curdir, '/');
   len := length (dirarr);
   ix := 0;
   xte_nodebld_init (xte_list);
   while (ix < len)
     {
       declare fst varchar;
       dirname := aref (dirarr, ix);
       fst := file_stat (concat (curdir, dirname));
       if (isstring (fst))
         modt := stringdate (fst);
       else
         modt := now();
       if (dirname <> '.')
         xte_nodebld_acc (xte_list, xte_node (xte_head ('SUBDIR', 'name', sprintf('%U',dirname),
               'modify', soap_print_box (modt, '', 2) ) ) );
       ix := ix + 1;
     }
   xte_nodebld_final (xte_list, xte_head ('DIRS'));
   xte_nodebld_acc (xte_path, xte_list);
   xte_nodebld_init (xte_list);
   len := length (filearr);
   ix := 0;
   while (ix < len)
     {
       dirname := aref (filearr, ix);
       modt := stringdate (file_stat (concat (curdir, dirname)));
       rflen := 0;
       rflen := file_stat (concat (curdir, dirname), 1);
       flen := atoi (rflen);
       mult := 0;
       if (lower (dirname) = 'folder.xsl')
	_sheet := concat (curdir, dirname);
       while ((flen / 1000) > 1)
	 {
	   mult := mult + 1;
	   flen := flen / 1000;
	 }
       xte_nodebld_acc (xte_list, xte_node (xte_head ('FILE', 'name', sprintf('%U',dirname),
             'modify', soap_print_box (modt, '', 2), 'rs', rflen,
             'hs', sprintf ('%d %s', flen, aref (fsize, mult)) ) ) );
       ix := ix + 1;
     }
   xte_nodebld_final (xte_list, xte_head ('FILES'));
   xte_nodebld_acc (xte_path, xte_list);
   xte_nodebld_final (xte_path, xte_head ('PATH'));
   return xml_tree_doc (xte_path);
}
;


xslt_sheet ('http://local.virt/dir_output', xml_tree_doc ('
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0">
    <xsl:output method="text" encoding="UTF-8" />

    <xsl:template match="PATH">
	<xsl:variable name="path"><xsl:value-of select="@dir_name"/></xsl:variable>
	&lt;!DOCTYPE HTML PUBLIC "-//IETF//DTD HTML 2.0//EN"&gt;
	&lt;html&gt;
	&lt;title&gt;Directory listing of <xsl:value-of select="\044path"/>&lt;/title&gt;
	&lt;body bgcolor="#FFFFFF" fgcolor="#000000"&gt;
	&lt;h4&gt;Index of <xsl:value-of select="\044path"/>&lt;/h4&gt;
	  &lt;table&gt;
	    &lt;tr&gt;&lt;td colspan="2" align="center"&gt;Name&lt;/td&gt;
	    &lt;td align="center"&gt;Last modified&lt;/td&gt;&lt;td align="center"&gt;Size&lt;/td&gt;&lt;/tr&gt;
	    &lt;tr&gt;&lt;td colspan="4"&gt;&lt;HR /&gt;&lt;/td&gt;&lt;/tr&gt;

	<xsl:apply-templates select="DIRS">
	  <xsl:with-param name="f_path" select="\044path"/>
	</xsl:apply-templates>

	<xsl:apply-templates select="FILES">
	  <xsl:with-param name="f_path" select="\044path"/>
	</xsl:apply-templates>

	     &lt;tr&gt;&lt;td colspan="4"&gt;&lt;HR /&gt;&lt;/td&gt;&lt;/tr&gt;
	  &lt;/table&gt;
	&lt;/body&gt;
	&lt;/html&gt;
    </xsl:template>

    <xsl:template match="SUBDIR">
	 <xsl:param name="f_path" />
    	&lt;tr&gt;
	   &lt;td&gt;&lt;img src="/conductor/dav/image/dav/foldr_16.png" alt="folder"&gt;&lt;/td&gt;
	   &lt;td&gt;&lt;a href="<xsl:value-of select="\044f_path"/><xsl:value-of select="@name"/>/"&gt;<xsl:value-of select="@name"/>&lt;/a&gt;&lt;/td&gt;
	   &lt;td&gt;<xsl:value-of select="@modify"/>&lt;/td&gt;&lt;td align="right"&gt;-&lt;/td&gt;
	&lt;/tr&gt;
    </xsl:template>

    <xsl:template match="FILE">
	 <xsl:param name="f_path" />
    	&lt;tr&gt;
	   &lt;td&gt;&lt;img src="/conductor/dav/image/dav/generic_file.png" alt="file"&gt;&lt;/td&gt;
	   &lt;td&gt;&lt;a href="<xsl:value-of select="\044f_path"/><xsl:value-of select="@name"/>"&gt;<xsl:value-of select="@name"/>&lt;/a&gt;&lt;/td&gt;
	   &lt;td&gt;<xsl:value-of select="@modify"/>&lt;/td&gt;&lt;td align="right"&gt;<xsl:value-of select="@hs"/>&lt;/td&gt;
	&lt;/tr&gt;
    </xsl:template>

</xsl:stylesheet>'))
;


create procedure WS.WS.DIR_INDEX_XML (in path any, in params any, in lines any)
{
  declare _html, _xml, _sheet varchar;
  declare _b_opt any;
  declare ssheet_name, ssheet_text varchar;

  _b_opt := NULL;

  if (exists (select 1 from HTTP_PATH
	where HP_LPATH = http_map_get ('domain') and HP_PPATH = http_map_get ('mounted')))
     select deserialize(HP_OPTIONS) into _b_opt from HTTP_PATH
	where HP_LPATH = http_map_get ('domain') and HP_PPATH = http_map_get ('mounted');

  _sheet := '';
  _xml := WS.WS.DIR_INDEX_MAKE_XML (_sheet);

  if (_b_opt is not NULL)
    _b_opt := get_keyword ('browse_sheet', _b_opt, '');

  if (_sheet <> '')
    {
      ssheet_name := 'http://local.virt/custom_dir_output/' || _sheet;
      ssheet_text := file_to_string (_sheet);
    }
  else if (_b_opt <> '')
    {
      _b_opt := concat (http_root(), '/', _b_opt);
      ssheet_name := 'http://local.virt/custom_dir_output/' ||  _b_opt;
      ssheet_text := file_to_string (_b_opt);
    }
  if (isstring (ssheet_name))
    xslt_sheet (ssheet_name, xtree_doc (ssheet_text));
  else
    ssheet_name := 'http://local.virt/dir_output';
  set http_charset='UTF-8';
  return http_value (xslt (ssheet_name, _xml));
}
;

create procedure DB.DBA.SERVICES_WSIL (in path any, in params any, in lines any)
{
  declare host, intf, requrl, proto, rhost varchar;
  declare arr any;
  host := http_map_get ('vhost');
  intf := http_map_get ('lhost');
  requrl := http_requested_url ();
  arr := rfc1808_parse_uri (requrl);
  proto := arr[0];
  rhost := arr[1];

  if (host = server_http_port () and intf = server_http_port ())
    {
      host := '*ini*';
      intf := '*ini*';
    }

  http_header ('Content-Type: text/xml\r\n');
  http('<?xml version="1.0" ?>');
  http('<inspection xmlns="http://schemas.xmlsoap.org/ws/2001/10/inspection">');
  for select HP_LPATH, deserialize (HP_SOAP_OPTIONS) as opts from DB.DBA.HTTP_PATH where HP_HOST = host and HP_LISTEN_HOST = intf and HP_PPATH = '/SOAP/' do
    {
      declare nam any;
      nam := trim (HP_LPATH, '/ ');
      if (isarray (opts))
	nam := get_keyword ('ServiceName', opts, nam);
      http ('<service>');
      http (sprintf ('<name>%V</name>', nam));
      http (sprintf ('<description referencedNamespace="http://schemas.xmlsoap.org/wsdl/" location="%s://%s%s/services.wsdl"/>', proto, rhost, HP_LPATH));
      http ('</service>');
    }
  http('</inspection>');
}
;

-- /* host-meta */

create table WS.WS.HTTP_HOST_META (
    HM_APP 	varchar primary key,
    HM_META	long varchar
    )
;

create procedure WS.WS.host_meta_add (in app varchar, in meta varchar)
{
  -- check if it is valid xml
  xtree_doc (meta);
  insert replacing WS.WS.HTTP_HOST_META (HM_APP, HM_META)
      values (app, meta);
}
;

create procedure WS.WS.host_meta_del (in app varchar)
{
  delete from WS.WS.HTTP_HOST_META where HM_APP = app;
}
;


create procedure WS.WS."host-meta" (in format varchar := 'xml') __SOAP_HTTP 'application/xrd+xml'
{
  declare ses, lines any;
  declare ret, accept varchar;
  ses := string_output ();
  http ('<?xml version="1.0" encoding="UTF-8"?>\n', ses);
  http ('<XRD xmlns="http://docs.oasis-open.org/ns/xri/xrd-1.0" xmlns:hm="http://host-meta.net/xrd/1.0" Id="host-meta">\n', ses);
  http (sprintf ('  <hm:Host>%{WSHost}s</hm:Host>\n'), ses);
  for select * from WS.WS.HTTP_HOST_META do
    {
      HM_META := sprintf (blob_to_string (HM_META));
      http ('  ', ses);
      http (HM_META, ses);
      http ('\n', ses);
    }
  http ('</XRD>\n', ses);
  ret := string_output_string (ses);
  if (xenc_key_exists ('id_rsa') and __proc_exists ('xml_sign', 2) is not null)
    {
      ret := xml_sign (ret, WS.WS.host_meta_dss (), 'http://docs.oasis-open.org/ns/xri/xrd-1.0:XRD');
    }
  lines := http_request_header ();
  accept := DB.DBA.HTTP_RDF_GET_ACCEPT_BY_Q (http_request_header_full (lines, 'Accept', '*/*'));
  if (format = 'json' or accept = 'application/json')
    {
      http_header ('Content-Type: application/json\r\n');
    http_xslt ('http://local.virt/xrd2json');
    }
  return ret;
}
;

create procedure WS.WS.host_meta_init ()
{
  if (not exists (select 1 from "DB"."DBA"."SYS_USERS" where U_NAME = 'WebMeta'))
    {
      DB.DBA.USER_CREATE ('WebMeta', uuid(), vector ('DISABLED', 1));
      EXEC_STMT ('grant execute on WS.WS."host-meta" to WebMeta', 0);
    }

  DB.DBA.VHOST_REMOVE (lpath=>'/.well-known');
  DB.DBA.VHOST_DEFINE (lpath=>'/.well-known', ppath=>'/SOAP/Http', soap_user=>'WebMeta');
}
;

WS.WS.host_meta_init ()
;

create procedure WS.WS.host_meta_dss ()
{
  declare ses any;
  ses := string_output ();
  http ('<?xml version="1.0" encoding="UTF-8"?>\n', ses);
  http ('<Signature \n', ses);
  http ('    xmlns="http://www.w3.org/2000/09/xmldsig#" \n', ses);
  http ('    xmlns:hm="http://host-meta.net/xrd/1.0"\n', ses);
  http ('    xmlns:xr="http://docs.oasis-open.org/ns/xri/xrd-1.0"\n', ses);
  http ('    >\n', ses);
  http ('    <SignedInfo>\n', ses);
  http ('	<CanonicalizationMethod Algorithm="http://www.w3.org/2001/10/xml-exc-c14n#" />\n', ses);
  http ('	<SignatureMethod Algorithm="http://www.w3.org/2000/09/xmldsig#rsa-sha1" />\n', ses);
  http ('	<Reference URI="#host-meta">\n', ses);
  http ('	    <Transforms>\n', ses);
  http ('		<Transform Algorithm="http://www.w3.org/2000/09/xmldsig#enveloped-signature" />\n', ses);
  http ('	    </Transforms>\n', ses);
  http ('	    <DigestMethod Algorithm="http://www.w3.org/2000/09/xmldsig#sha1" />\n', ses);
  http ('	    <DigestValue></DigestValue>\n', ses);
  http ('	</Reference>\n', ses);
  http ('    </SignedInfo>\n', ses);
  http ('    <SignatureValue></SignatureValue>\n', ses);
  http ('    <KeyInfo>\n', ses);
  http ('	<KeyName>id_rsa</KeyName>\n', ses);
  http ('	<KeyValue>\n', ses);
  http ('	    <X509Data></X509Data>\n', ses);
  http ('	</KeyValue>\n', ses);
  http ('    </KeyInfo>\n', ses);
  http ('</Signature>\n', ses);
  return string_output_string (ses);
}
;

--!
-- (Re-)Creates all default virtual dirs on the given listener.
--/
create procedure DB.DBA.CREATE_DEFAULT_VHOSTS (in vhost varchar := '*ini*', in lhost varchar := '*ini*')
{
  declare auth any;
  declare sec, cert, sslKey varchar;
  declare httpsVerify, httpsCvD int;

  -- Get security from the listener (needs to be the same for all vdirs)
  sec := (select top 1 HP_SECURITY from DB.DBA.HTTP_PATH where HP_LISTEN_HOST = lhost and HP_HOST = vhost);
  cert := (select top 1 get_keyword('https_cert', deserialize(HP_AUTH_OPTIONS)) from DB.DBA.HTTP_PATH where HP_LISTEN_HOST = lhost and HP_HOST = vhost);
  sslKey := (select top 1 get_keyword('https_key', deserialize(HP_AUTH_OPTIONS)) from DB.DBA.HTTP_PATH where HP_LISTEN_HOST = lhost and HP_HOST = vhost);
  httpsVerify := (select top 1 get_keyword('https_verify', deserialize(HP_AUTH_OPTIONS)) from DB.DBA.HTTP_PATH where HP_LISTEN_HOST = lhost and HP_HOST = vhost);
  httpsCvD := (select top 1 get_keyword('https_cv_depth', deserialize(HP_AUTH_OPTIONS)) from DB.DBA.HTTP_PATH where HP_LISTEN_HOST = lhost and HP_HOST = vhost);
  auth := vector ();
  if (sslKey is not null)
    {
      auth := vector ('https_key', sslKey, 'https_cert', cert, 'https_verify', httpsVerify, 'https_cv_depth', httpsCvD);
    }

  for (select
        HPD_LPATH,
        HPD_PPATH,
        HPD_STORE_AS_DAV,
        HPD_DIR_BROWSEABLE,
        HPD_DEFAULT,
        HPD_REALM,
        HPD_AUTH_FUNC,
        HPD_POSTPROCESS_FUNC,
        HPD_RUN_VSP_AS,
        HPD_RUN_SOAP_AS,
        HPD_PERSIST_SES_VARS,
        HPD_SOAP_OPTIONS,
        HPD_AUTH_OPTIONS,
        HPD_OPTIONS,
        HPD_IS_DEFAULT_HOST
      from DB.DBA.HTTP_PATH_DEFAULT) do
    {
      DB.DBA.VHOST_REMOVE (
        vhost=>vhost,
        lhost=>lhost,
        lpath=>HPD_LPATH);

      DB.DBA.VHOST_DEFINE (
        vhost=>vhost,
        lhost=>lhost,
        lpath=>HPD_LPATH,
        ppath=>HPD_PPATH,
        is_dav=>HPD_STORE_AS_DAV,
        is_brws=>HPD_DIR_BROWSEABLE,
        def_page=>HPD_DEFAULT,
        auth_fn=>HPD_AUTH_FUNC,
        realm=>HPD_REALM,
        ppr_fn=>HPD_POSTPROCESS_FUNC,
        vsp_user=>HPD_RUN_VSP_AS,
        soap_user=>HPD_RUN_SOAP_AS,
        sec=>sec,
        ses_vars=>HPD_PERSIST_SES_VARS,
        soap_opts=>deserialize (HPD_SOAP_OPTIONS),
        auth_opts=>vector_concat (deserialize (HPD_AUTH_OPTIONS), auth),
        opts=>deserialize (HPD_OPTIONS),
        is_default_host=>HPD_IS_DEFAULT_HOST);
    }
}
;

--!
-- Add a default host to be created for each new listener.
--/
create procedure DB.DBA.ADD_DEFAULT_VHOST (
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
  in ses_vars integer := 0,
  in soap_opts any := null,
  in auth_opts any := null,
  in opts any := null,
  in is_default_host integer := 0,
  in overwrite int := 0)
{
  if (overwrite)
    {
      delete from DB.DBA.HTTP_PATH_DEFAULT where HPD_LPATH = lpath;
    }

  insert into
    DB.DBA.HTTP_PATH_DEFAULT (
      HPD_LPATH,
      HPD_PPATH,
      HPD_STORE_AS_DAV,
      HPD_DIR_BROWSEABLE,
      HPD_DEFAULT,
      HPD_REALM,
      HPD_AUTH_FUNC,
      HPD_POSTPROCESS_FUNC,
      HPD_RUN_VSP_AS,
      HPD_RUN_SOAP_AS,
      HPD_PERSIST_SES_VARS,
      HPD_SOAP_OPTIONS,
      HPD_AUTH_OPTIONS,
      HPD_OPTIONS,
      HPD_IS_DEFAULT_HOST)
    values (
      lpath,
      ppath,
      is_dav,
      is_brws,
      def_page,
      realm,
      auth_fn,
      ppr_fn,
      vsp_user,
      soap_user,
      ses_vars,
      serialize (soap_opts),
      serialize (auth_opts),
      serialize (opts),
      is_default_host);
}
;

-- Trigger to create default vdirs on new listener
create trigger HTTP_PATH_ins_def after insert on DB.DBA.HTTP_PATH referencing new as N
{
  -- Check if this is the first entry for the listener
  if (not exists (select 1 from DB.DBA.HTTP_PATH where HP_HOST = N.HP_HOST and HP_LISTEN_HOST = N.HP_LISTEN_HOST and HP_LPATH <> N.HP_LPATH))
    {
      declare exit handler for sqlstate '*'
        {
          log_message (sprintf ('Failed to create default virtual hosts for %s %s (%s). Please fix the configuration.', N.HP_HOST, N.HP_LISTEN_HOST, __SQL_MESSAGE));
        };
      CREATE_DEFAULT_VHOSTS (vhost=>N.HP_HOST, lhost=>N.HP_LISTEN_HOST);
    }
}
;

-- Default WebDAV mapping for all future http listeners
insert soft DB.DBA.HTTP_PATH_DEFAULT
(
HPD_LPATH, HPD_PPATH, HPD_STORE_AS_DAV, HPD_DIR_BROWSEABLE, HPD_DEFAULT,
HPD_REALM, HPD_AUTH_FUNC, HPD_POSTPROCESS_FUNC, HPD_RUN_VSP_AS, HPD_RUN_SOAP_AS, HPD_PERSIST_SES_VARS)
values ( '/DAV', '/DAV/', 1, 1, NULL, NULL, NULL, NULL, 'dba', NULL, 0
)
;
