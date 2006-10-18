--
--  $Id$
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

create procedure WA_GET_EMAIL_TEMPLATE(in name varchar) {

  declare ret any;
  if (http_map_get ('is_dav') = 0)
    {
      ret := file_to_string (http_root () || '/wa/tmpl/' || name);
    }
  else
    {
      ret := (select
             coalesce(blob_to_string(RES_CONTENT), 'Not found...')
           from
             WS.WS.SYS_DAV_RES
           where
             RES_FULL_PATH = '/DAV/VAD/wa/tmpl/' || name );
    }
  return ret;
}
;

create procedure WA_SET_EMAIL_TEMPLATE(in name varchar, in value varchar) {
  update
    WS.WS.SYS_DAV_RES
  set
    RES_CONTENT = value
  where
    RES_FULL_PATH = '/DAV/VAD/wa/tmpl/' || name;
}
;

create procedure wa_exec_no_error_log(in expr varchar) {
  declare state, message, meta, result any;
  log_enable (1);
  exec(expr, state, message, vector(), 0, meta, result);
}
;


create procedure wa_exec_no_error(in expr varchar) {
  declare state, message, meta, result any;
  exec(expr, state, message, vector(), 0, meta, result);
}
;

create procedure wa_add_col(in tbl varchar, in col varchar, in coltype varchar,in postexec varchar := '') {
 if(exists(
           select
             top 1 1
           from
             DB.DBA.SYS_COLS
           where
             upper("TABLE") = upper(tbl) and
             upper("COLUMN") = upper(col)
          )
    ) return;
  exec (sprintf ('alter table %s add column %s %s', tbl, col, coltype));
  if (postexec <> '' and not(isnull(postexec)))
    exec (postexec);
}
;

wa_exec_no_error_log('CREATE INDEX VSPX_SESSION_VS_UID ON VSPX_SESSION (VS_UID)');

wa_exec_no_error(
  'create type web_app as
  (
    wa_name varchar,  -- ie. blog
    wa_member_model int -- how registration can be made
  )
  method wa_id_string () returns any,         -- string in memberships list
  method wa_new_inst (login varchar) returns any,   -- registering
  method wa_join_request (login varchar) returns any,   -- registering
  method wa_leave_notify (login varchar) returns any,   -- cancel join
  method wa_state_edit_form (stream any) returns any,   -- emit a state edit form into the stream present this to owner for setting the state
  method wa_membership_edit_form (stream any) returns any,  -- emit a membership edit form into the stream present this to owner for setting the state
  method wa_front_page (stream any) returns any,  -- emit a front page into the stream present this to owner for setting the state
  method wa_state_posted (post any, stream any) returns any, -- process a post, updating state and writing a reply into the stream for web interface
  method wa_periodic_activity () returns any,   -- send reminders, invoices, refresh content whatever is regularly done.
  method wa_drop_instance () returns any,
  method wa_private_url () returns any,
  method wa_notify_member_changed (account int, otype int, ntype int, odata any, ndata any) returns any,
  method wa_member_data (u_id int, stream any) returns any, -- application specific membership attributes
  method wa_member_data_edit_form (u_id int, stream any) returns any, -- application specific membership attributes edit form
  method wa_class_details () returns varchar, -- returns details about the nature of the instance class
  method wa_https_supported () returns int,
  method wa_dashboard () returns any
  '
)
;

wa_exec_no_error('alter type web_app add method wa_home_url () returns varchar');
wa_exec_no_error('alter type web_app add method wa_dashboard () returns any');
wa_exec_no_error('alter type web_app add method wa_addition_urls () returns any');
wa_exec_no_error('alter type web_app add method wa_addition_instance_urls () returns any');
wa_exec_no_error('alter type web_app add method wa_addition_instance_urls (in lpath any) returns any');
wa_exec_no_error('alter type web_app add method wa_domain_set (in domain varchar) returns any');
wa_exec_no_error('alter type web_app add method wa_size () returns int');
wa_exec_no_error('alter type web_app add method wa_front_page_as_user (in stream any, in user_name varchar) returns any');
wa_exec_no_error('alter type web_app add method wa_rdf_url (in vhost varchar, in lhost varchar) returns varchar');
wa_exec_no_error('alter type web_app add method wa_post_url (in vhost varchar, in lhost varchar, in inst_name varchar, in post any) returns varchar');

wa_exec_no_error_log(
  'CREATE TABLE WA_INDUSTRY
    (
    WI_NAME varchar not null primary key
    )'
)
;

wa_exec_no_error_log(
  'CREATE TABLE WA_COUNTRY
    (
    WC_NAME varchar not null primary key,
    WC_CODE varchar,
    WC_LAT  real,
    WC_LNG  real
    )'
)
;

wa_add_col('DB.DBA.WA_COUNTRY', 'WC_LAT', 'real');
wa_add_col('DB.DBA.WA_COUNTRY', 'WC_LNG', 'real');
wa_add_col('DB.DBA.WA_COUNTRY', 'WC_CODE', 'varchar');


wa_exec_no_error_log (
    'create table WA_PROVINCE (
      WP_COUNTRY varchar,
      WP_PROVINCE varchar,
      primary key (WP_COUNTRY, WP_PROVINCE))'
);


/* Domains that can be used in WA */

wa_exec_no_error_log(
  'CREATE TABLE WA_DOMAINS
    (
      WD_DOMAIN varchar,    -- domain name
      WD_HOST varchar,      -- this and rest are the endpoint to access wa via that domain
      WD_LISTEN_HOST varchar,
      WD_LPATH varchar,
      WD_MODEL int,
      primary key (WD_DOMAIN)
    )'
)
;

/*
   TODO: rename the table and put the data back and then drop, this is for non-nullable cols which are
   WD_HOST,WD_LISTEN_HOST
*/

wa_add_col ('DB.DBA.WA_DOMAINS', 'WD_LPATH', 'varchar');
wa_add_col ('DB.DBA.WA_DOMAINS', 'WD_DOMAIN', 'varchar');
wa_add_col ('DB.DBA.WA_DOMAINS', 'WD_MODEL', 'int');

wa_exec_no_error_log(
    'create table WA_MAP_HOSTS
    (
      WMH_HOST varchar,
      WMH_SVC  varchar,
      WMH_KEY  varchar,
      WMH_ID integer identity,
      primary key (WMH_HOST, WMH_SVC)
    )'
);


create procedure MIGRATE_WA_DOMAINS ()
{
  if (exists (select 1 from DB.DBA.SYS_COLS where upper("TABLE") = 'DB.DBA.WA_DOMAINS'
  and upper("COLUMN") = 'WD_HOST' and COL_NULLABLE is null))
    return;

  for select WD_HOST as vhost from WA_DOMAINS where WD_DOMAIN is null
    do
      {
  declare arr any;
  arr := split_and_decode (vhost, 0, '\0\0:');
  if (isarray(arr) and length (arr))
    update WA_DOMAINS set WD_DOMAIN = arr[0] where WD_HOST = vhost;
      }

  wa_exec_no_error ('alter table DB.DBA.WA_DOMAINS modify primary key (WD_DOMAIN)');
  update DB.DBA.SYS_COLS set COL_NULLABLE = null
      where upper("TABLE") = 'DB.DBA.WA_DOMAINS' and upper("COLUMN") in ('WD_LISTEN_HOST', 'WD_HOST');
  __ddl_changed ('DB.DBA.WA_DOMAINS');
}
;

MIGRATE_WA_DOMAINS ();

drop procedure MIGRATE_WA_DOMAINS;


wa_exec_no_error_log(
  'CREATE TABLE WA_USERS
  (
    WAU_U_ID int,
    WAU_QUESTION varchar,
    WAU_ANSWER varchar,
    WAU_LAST_IP varchar,
    WAU_TEMPLATE varchar,
    primary key (WAU_U_ID)
  )'
)
;

wa_exec_no_error_log(
  'CREATE TABLE WA_USER_SETTINGS
  (
    WAUS_U_ID int,
    WAUS_KEY varchar(50),
    WAUS_DATA long varbinary,
    primary key (WAUS_U_ID,WAUS_KEY)
  )'
)
;

wa_exec_no_error_log(
  'ALTER TABLE WA_USER_SETTINGS ADD FOREIGN KEY (WAUS_U_ID) REFERENCES SYS_USERS (U_ID) ON DELETE CASCADE'
)
;

-- put for versions upgrade
wa_exec_no_error_log(
  'ALTER TABLE WA_USERS DROP FOREIGN KEY (WAU_U_ID) REFERENCES SYS_USERS (U_ID)'
)
;

wa_add_col('DB.DBA.WA_USERS', 'WAU_LOGON_DISABLE_UNTIL', 'datetime')
;

wa_add_col('DB.DBA.WA_USERS', 'WAU_LAST_IP', 'varchar')
;

wa_add_col('DB.DBA.WA_USERS', 'WAU_TEMPLATE', 'varchar')
;

wa_exec_no_error(
  'CREATE TABLE WA_BLOCKED_IP
  (
    WAB_IP varchar,
    WAB_DISABLE_UNTIL datetime,
    primary key (WAB_IP)
  )'
)
;

wa_add_col('DB.DBA.WA_USERS', 'WAU_PWD_RECOVER_DISABLE_UNTIL', 'datetime')
;

wa_exec_no_error(
  'CREATE TABLE WA_TYPES (
    WAT_NAME varchar,
    WAT_TYPE varchar,
    WAT_REALM varchar,
    WAT_DESCRIPTION varchar,
      primary key (WAT_NAME)
    )'
)
;

wa_exec_no_error(
  'CREATE TABLE WA_MEMBER_MODEL
    (
    WMM_ID int primary key,
    WMM_NAME varchar not null
    )'
)
;

wa_exec_no_error(
  'CREATE TABLE WA_MEMBER_TYPE (
  WMT_APP varchar,
  WMT_NAME varchar,
  WMT_ID int,
  WMT_IS_DEFAULT int,
  primary key (WMT_APP, WMT_ID))'
)
;

wa_exec_no_error(
  'CREATE TABLE WA_INSTANCE
    (
    WAI_ID   int identity,
    WAI_TYPE_NAME varchar references WA_TYPES on delete cascade,
    WAI_NAME varchar,
    WAI_INST web_app,
    WAI_MEMBER_MODEL int references WA_MEMBER_MODEL,
    WAI_IS_PUBLIC int default 1,
    WAI_MEMBERS_VISIBLE int default 1,
    WAI_DESCRIPTION varchar,
    WAI_MODIFIED timestamp,
    WAI_IS_FROZEN int,
    WAI_FREEZE_REDIRECT varchar,
    primary key (WAI_NAME)
    )'
)
;

wa_add_col('DB.DBA.WA_INSTANCE', 'WAI_IS_FROZEN', 'int')
;

wa_add_col('DB.DBA.WA_INSTANCE', 'WAI_FREEZE_REDIRECT', 'varchar')
;

wa_add_col('DB.DBA.WA_INSTANCE', 'WAI_MODIFIED', 'timestamp')
;

--wa_exec_no_error(
--  'CREATE UNIQUE INDEX WAI_NAME ON WA_INSTANCE (WAI_NAME)'
--)
--;

wa_exec_no_error_log(
  'CREATE TABLE WA_VIRTUAL_HOSTS
    (
      VH_INST integer references WA_INSTANCE (WAI_ID) on delete cascade,
      VH_HOST varchar,  	-- this and rest are the endpoint to access wa via that domain
      VH_LISTEN_HOST varchar,
      VH_LPATH varchar,
      VH_PAGE varchar,
      primary key (VH_INST,VH_HOST,VH_LISTEN_HOST,VH_LPATH)
    )'
)
;


create trigger HTTP_PATH_U_WA after update on DB.DBA.HTTP_PATH referencing old as O, new as N
{
  update WA_DOMAINS set WD_HOST = N.HP_HOST, WD_LISTEN_HOST = N.HP_LISTEN_HOST,
   WD_LPATH = N.HP_LPATH where WD_HOST = O.HP_HOST and WD_LISTEN_HOST = O.HP_LISTEN_HOST and WD_LPATH = O.HP_LPATH;

  update WA_VIRTUAL_HOSTS set VH_HOST = N.HP_HOST, VH_LISTEN_HOST = N.HP_LISTEN_HOST, VH_LPATH = N.HP_LPATH
      where VH_HOST = O.HP_HOST and VH_LISTEN_HOST = O.HP_LISTEN_HOST and VH_LPATH = O.HP_LPATH;

}
;

create trigger HTTP_PATH_D_WA after delete on DB.DBA.HTTP_PATH referencing old as O
{
  delete from WA_DOMAINS where WD_HOST = O.HP_HOST and WD_LISTEN_HOST = O.HP_LISTEN_HOST and WD_LPATH = O.HP_LPATH;
  delete from WA_VIRTUAL_HOSTS where VH_HOST = O.HP_HOST and VH_LISTEN_HOST = O.HP_LISTEN_HOST and VH_LPATH = O.HP_LPATH;
}
;


wa_exec_no_error(
  'CREATE TABLE WA_MEMBER
    (
     WAM_USER int,
     WAM_INST varchar references WA_INSTANCE on delete cascade on update cascade,
     WAM_MEMBER_TYPE int, -- 1= owner 2= admin 3=regular, -1=waiting approval etc.
     WAM_MEMBER_SINCE datetime,
     WAM_EXPIRES datetime,
     WAM_IS_PUBLIC int default 1,  -- zdravko -- Dublicate WAI_IS_PUBLIC
     WAM_MEMBERS_VISIBLE int default 1,  -- Dublicate WAI_MEMBERS_VISIBLE
     WAM_HOME_PAGE varchar,
     WAM_APP_TYPE varchar,-- zdravko
     WAM_DATA any, -- app dependent, e.g. last payment info, other.
       primary key (WAM_USER, WAM_INST, WAM_MEMBER_TYPE)
    )'
)
;

wa_exec_no_error_log(
    'create index WA_MEMBER_WAM_INST on WA_MEMBER (WAM_INST)'
    );

-- put for versions upgrade
wa_exec_no_error_log(
  'ALTER TABLE WA_MEMBER DROP FOREIGN KEY (WAM_USER) REFERENCES SYS_USERS (U_ID)'
)
;


wa_add_col('DB.DBA.WA_MEMBER', 'WAM_STATUS', 'int')
;

--zdravko
wa_add_col('DB.DBA.WA_MEMBER', 'WAM_APP_TYPE', 'varchar')
;

wa_add_col('DB.DBA.WA_MEMBER', 'WAM_IS_PUBLIC', 'int default 1')
;

wa_add_col('DB.DBA.WA_MEMBER', 'WAM_MEMBERS_VISIBLE', 'int default 1')
;

wa_add_col('DB.DBA.WA_MEMBER', 'WAM_HOME_PAGE', 'varchar')
;

 --wa_add_col('DB.DBA.WA_MEMBER', 'WAM_REQUESTED_MEMBER_TYPE', 'int')
 --;

--zdravko

create procedure wa_member_upgrade() {

  if (registry_get ('__wa_member_upgrade') = 'done')
    return;

  set triggers off;
  update DB.DBA.WA_MEMBER set WAM_STATUS = 2;
  update DB.DBA.WA_MEMBER set WAM_STATUS = 1 where WAM_MEMBER_TYPE = 1;
  set triggers on;
  registry_set ('__wa_member_upgrade', 'done');
}
;

wa_member_upgrade()
;

drop procedure wa_member_upgrade
;

wa_exec_no_error_log(
'create table WA_INVITATIONS (
    WI_U_ID     int,		-- U_ID
    WI_TO_MAIL  varchar,	-- email
    WI_INSTANCE varchar,	-- WAI_NAME
    WI_SID      varchar,	-- VS_SID
    WI_STATUS   varchar,	-- pending, or rejected
    primary key (WI_U_ID, WI_TO_MAIL, WI_INSTANCE))');

wa_exec_no_error_log(
'create unique index WA_INVITATIONS_SID on WA_INVITATIONS (WI_SID)'
    );


wa_exec_no_error(
  'create table WA_SETTINGS
  (
  WS_ID integer identity primary key,
  WS_REGISTER int,
  WS_MAIL_VERIFY int,
  WS_VERIFY_TIP int,
  WS_REGISTRATION_EMAIL_EXPIRY int default 24,
  WS_JOIN_EXPIRY int default 72,
  WS_DOMAINS varchar,
  WS_SMTP varchar,
  WS_USE_DEFAULT_SMTP integer,
  WS_BRAND_NAME varchar,
  WS_WEB_BANNER varchar,
  WS_WEB_TITLE varchar,
  WS_WEB_DESCRIPTION varchar,
  WS_WELCOME_MESSAGE varchar,
  WS_COPYRIGHT varchar,
  WS_DISCLAIMER varchar,
  WS_DEFAULT_MAIL_DOMAIN varchar
  )'
)
;

wa_add_col('DB.DBA.WA_SETTINGS', 'WS_SHOW_SYSTEM_ERRORS', 'integer')
;

wa_add_col('DB.DBA.WA_SETTINGS', 'WS_MEMBER_MODEL', 'integer')
;

wa_add_col('DB.DBA.WA_SETTINGS', 'WS_REGISTRATION_XML', 'long xml')
;

wa_add_col('DB.DBA.WA_SETTINGS', 'WS_BRAND_NAME', 'varchar')
;

wa_add_col('DB.DBA.WA_SETTINGS', 'WS_WEB_BANNER', 'varchar')
;

wa_add_col('DB.DBA.WA_SETTINGS', 'WS_WEB_TITLE', 'varchar')
;

wa_add_col('DB.DBA.WA_SETTINGS', 'WS_WEB_DESCRIPTION', 'varchar')
;

wa_add_col('DB.DBA.WA_SETTINGS', 'WS_WELCOME_MESSAGE', 'varchar')
;

wa_add_col('DB.DBA.WA_SETTINGS', 'WS_COPYRIGHT', 'varchar')
;

wa_add_col('DB.DBA.WA_SETTINGS', 'WS_DISCLAIMER', 'varchar')
;

wa_add_col('DB.DBA.WA_SETTINGS', 'WS_GENERAL_AGREEMENT', 'varchar')
;

wa_add_col('DB.DBA.WA_SETTINGS', 'WS_MEMBER_AGREEMENT', 'varchar')
;

wa_add_col('DB.DBA.WA_SETTINGS', 'WS_DEFAULT_MAIL_DOMAIN', 'varchar')
;

wa_add_col('DB.DBA.WA_SETTINGS', 'WS_VERIFY_TIP', 'int')
;


wa_exec_no_error(
  'alter type web_app drop method wa_notify_member_changed(account int, otype int, ntype int, odata any, ndata any) returns any'
)
;

wa_exec_no_error(
  'alter type web_app add method wa_notify_member_changed(account int, otype int, ntype int, odata any, ndata any, ostatus any, nstatus any) returns any'
)
;

wa_exec_no_error(
  'alter type web_app add drop method wa_new_instace_url(in ws_type varchar) returns any'
)
;

wa_exec_no_error(
  'alter type web_app add method wa_new_instance_url() returns any'
)
;

wa_exec_no_error(
  'alter type web_app add method wa_edit_instance_url() returns any'
)
;

create method wa_id_string () for web_app
{
  return '';
}
;

create method wa_dashboard () for web_app
{
  return '';
}
;

create method wa_member_data (in u_id int, inout stream any) for web_app
{
  return 'N/A';
}
;

create method wa_member_data_edit_form (in u_id int, inout stream any) for web_app
{
  return;
}
;

create method wa_membership_edit_form (inout stream any) for web_app
{
  return;
}
;

create method wa_front_page (inout stream any) for web_app
{
  return;
}
;

create method wa_front_page_as_user (inout stream any, in user_name varchar) for web_app
{
  return;
}
;

create method wa_size () for web_app
{
  return 0;
}
;

create method wa_join_request (in login varchar) for web_app
{
  return;
}
;

create method wa_class_details() for web_app
{
  return null;
}
;

create method wa_state_edit_form (inout stream any) for web_app
{
  return;
}
;

create method wa_state_posted (in post any, inout stream any) for web_app
{
  return;
}
;

create method wa_home_url () for web_app
{
  return null;
}
;

create method wa_rdf_url (in vhost varchar, in lhost varchar) for web_app
{
  return null;
}
;

create method wa_post_url (in vhost varchar, in lhost varchar, in inst_name varchar, in post any) for web_app
{
  return null;
}
;


create method wa_addition_urls () for web_app
{
  return null;
}
;

create method wa_addition_instance_urls () for web_app
{
  return null;
}
;

create method wa_addition_instance_urls (in lpath any) for web_app
{
  return null;
}
;

wa_exec_no_error(
  'alter type web_app add method wa_domain_set(in domain varchar) returns any'
)
;

create method wa_domain_set (in domain varchar) for web_app
{
  return self;
}
;

create method wa_private_url () for web_app
{
  return null;
}
;

create method wa_https_supported () for web_app
{
  return;
}
;

create method wa_drop_instance () for web_app {

/* XXX: old query
  for (
select
    HP_HOST as _host, HP_LISTEN_HOST as _lhost, HP_LPATH as _path, WAI_INST as _inst
  from
    WA_INSTANCE WA_INSTANCE,
    HTTP_PATH
  where
    WA_INSTANCE.WAI_NAME = self.wa_name and
    HP_PPATH = (select HP_PPATH from HTTP_PATH where HP_LPATH=rtrim(WA_INSTANCE.WAI_INST.wa_home_url(), '/') and HP_HOST='*ini*' and HP_LISTEN_HOST='*ini*') and
    HP_HOST not like '%ini%'and HP_HOST not like '*sslini*')
  do
*/
for select VH_HOST as _host, VH_LISTEN_HOST as _lhost, VH_LPATH as _path, WAI_INST as _inst
  from WA_INSTANCE, WA_VIRTUAL_HOSTS where WAI_NAME = self.wa_name and WAI_ID = VH_INST and VH_HOST not like '%ini%'
  do
  {
    declare inst web_app;
    inst := _inst;
    -- Application additional URL
    declare len, i, ssl_port integer;
    declare cur_add_url, addons any;

    addons := inst.wa_addition_urls();
    len := length(addons);
    i := 0;
    while (i < len)
    {
      cur_add_url := addons [i];
      VHOST_REMOVE(
        vhost=>_host,
        lhost=>_lhost,
        lpath=>cur_add_url[2]);
      i := i + 1;
    }
    -- Instance additional URL
    addons := inst.wa_addition_instance_urls(_path);
    len := length(addons);
    i := 0;
    while (i < len)
    {
      cur_add_url := addons[i];
      VHOST_REMOVE(
        vhost=>_host,
        lhost=>_lhost,
        lpath=>cur_add_url[2]);
      i := i + 1;
    }
    -- Home URL
    VHOST_REMOVE(vhost=>_host, lhost=>_lhost, lpath=>_path);
  }
  delete from WA_MEMBER where WAM_INST = self.wa_name;
  delete from WA_INSTANCE where WAI_NAME = self.wa_name;
}
;

create method wa_periodic_activity () for web_app
{
  return;
}
;

create method wa_notify_member_changed (in accounter int, in otype int, in ntype int, in odata any, in ndata any, in ostatus any, in nstatus any) for web_app
{
   -- check if this account already exists
  if (not exists (select 1 from DB.DBA.SYS_USERS where U_ID = accounter and U_DAV_ENABLE = 1 and U_IS_ROLE = 0))
  {
    signal('WA001', sprintf('%%User U_ID=%d is not found%%', accounter));
  }
  -- check if user is not member (only for insertion)
  if(otype is null and ostatus is null) {
    -- clear insertion
    declare _cnt any;
    _cnt := (select count(*) from WA_MEMBER where WAM_USER = accounter and WAM_INST = self.wa_name and WAM_STATUS < 3);
    if(_cnt > 1) {
      signal('WA001', '%%Entered user already is member.%%');
    }
  }
  declare _wai_id any;
  _wai_id := (select WAI_ID from WA_INSTANCE where WAI_NAME = self.wa_name);
  if(otype is null and ostatus is null and nstatus = 1) {
    -- new instance creation and user became owner
    -- do nothing
    return;
  }
  if(otype = ntype and ostatus = nstatus) {
    -- no real membership changing
    -- (probably others fields are updated)
    -- do nothing
    return;
  }
  -- get memeber model
  declare _member_model integer;
  _member_model := (select WAI_MEMBER_MODEL from WA_INSTANCE where WAI_NAME = self.wa_name);
  -- 0 Open
  -- 1 Closed
  -- 2 Invite Only
  -- 3 Approval Based
  -- 4 Notify owner via E-mail
   -- determine mail server
   declare _smtp_server, dat any;
   if((select max(WS_USE_DEFAULT_SMTP) from WA_SETTINGS) = 1) {
     _smtp_server := cfg_item_value(virtuoso_ini_path(), 'HTTPServer', 'DefaultMailServer');
   }
   else {
     _smtp_server := (select max(WS_SMTP) from WA_SETTINGS);
   }
  dat := sprintf ('Date: %s\r\n', date_rfc1123 (now ()));
  -- get user's and owner's e-mail addreses
  declare _owner_id, _owner_name, _owner_full_name, _owner_e_mail any;
  declare _user_id, _user_name, _user_full_name, _user_e_mail any;
  select
    U_ID, U_NAME, U_FULL_NAME, U_E_MAIL
  into
    _owner_id, _owner_name, _owner_full_name, _owner_e_mail
  from
    SYS_USERS
  where
    U_ID = (select max(WAM_USER) from WA_MEMBER where WAM_INST = self.wa_name and WAM_STATUS = 1);
  select
    U_ID, U_NAME, U_FULL_NAME, U_E_MAIL
  into
    _user_id, _user_name, _user_full_name, _user_e_mail
  from
    SYS_USERS
  where
    U_ID = accounter;
  if(otype is null and ostatus is null and nstatus = 4) {
    -- owner invite user join to application
    ;
  }
  if(otype is null and ostatus is null and nstatus = 3) {
    -- user wants to join application
    -- check if it possible
    if(_member_model = 1) {
      -- reject
      goto closed;
    }
    if(_member_model = 0 or _member_model = 2) {
      -- 0 Open
      -- approve immediately
      set triggers off;
      update
        WA_MEMBER
      set
        WAM_STATUS = 2 -- approved
      where
        WAM_USER = accounter and
        WAM_INST = self.wa_name;
      connection_set('join_result', 'approved');
      set triggers on;
      return;
    }
    if(_member_model = 3) {
      -- 3 Approval Based
      if(not _smtp_server or length(_smtp_server) = 0) {
        signal('WA002', '%%Mail Server is not defined. Mail verification impossible.%%');
      }
      -- notify owner by e-mail
      declare _mail_body any;
      _mail_body := WA_GET_EMAIL_TEMPLATE('WS_MEM_TEMPLATE');
      -- WA_MAIL_TEMPLATES(templ, web_app, user_name, app_action_url)
      _mail_body := WA_MAIL_TEMPLATES(_mail_body, self, _user_name, sprintf('%s/login.vspx?URL=%s/members.vspx?wai_id=%d', wa_link (1), wa_link (), _wai_id));
      _mail_body := dat || 'Subject: Application registration notification\r\nContent-Type: text/plain; charset=UTF-8\r\n' || _mail_body;
      smtp_send(_smtp_server, _user_e_mail, _owner_e_mail, _mail_body);
      -- place request on hold and wait owner approvement
      connection_set('join_result', 'ownerwait');
      return;
    }
    if(_member_model = 4) {
      -- 4 Notify owner via E-mail
      if(not _smtp_server or length(_smtp_server) = 0) {
        signal('WA002', '%%Mail Server is not defined. Mail verification impossible.%%');
      }
      -- notify owner by e-mail
      declare _mail_body any;
      _mail_body := WA_GET_EMAIL_TEMPLATE('WS_MEM_TEMPLATE');
      -- WA_MAIL_TEMPLATES(templ, web_app, user_name, app_action_url)
      _mail_body := WA_MAIL_TEMPLATES(_mail_body, self, _user_name, sprintf('%s/login.vspx?URL=%s/members.vspx?wai_id=%d', wa_link (1), wa_link (), _wai_id));
      _mail_body := dat || 'Subject: Application registration notification\r\nContent-Type: text/plain; charset=UTF-8\r\n' || _mail_body;
      smtp_send(_smtp_server, _user_e_mail, _owner_e_mail, _mail_body);

      -- became member immediately
      set triggers off;
      update
        WA_MEMBER
      set
        WAM_STATUS = 2 -- approved
      where
        WAM_USER = accounter and
        WAM_INST = self.wa_name;
      connection_set('join_result', 'approved');
      set triggers on;
      return;
    }
closed:
    signal('WA001', '%%Application is closed for join. Please ask owner.%%');
  }
  if(otype is null and ostatus is null and ntype is not null and nstatus = 4) {
    -- Invitation from owner
    if(not _smtp_server or length(_smtp_server) = 0) {
      signal('WA002', '%%Mail Server is not defined. Mail verification impossible.%%');
    }
    -- notify user by e-mail
    declare _mail_body, _url, _sid any;
    _sid := connection_get('__sid');
    _url := sprintf('%s/conf_app.vspx?app=%U&sid=%s&realm=wa',
                    wa_link (1),
                    self.wa_name,
                    _sid);
    _mail_body := WA_GET_EMAIL_TEMPLATE('WS_INV_TEMPLATE');
    -- WA_MAIL_TEMPLATES(templ, web_app, user_name, app_action_url)
    _mail_body := WA_MAIL_TEMPLATES(_mail_body, self, _user_name, _url);
    _mail_body := dat || 'Subject: Application registration notification\r\nContent-Type: text/plain; charset=UTF-8\r\n' || _mail_body;
    smtp_send(_smtp_server, _owner_e_mail, _user_e_mail, _mail_body);
    return;
  }
  if(ntype is not null and ostatus = 3 and nstatus = 2) {
    -- owner's approvement after user's join request
    if(not _smtp_server or length(_smtp_server) = 0) {
      signal('WA002', '%%Mail Server is not defined. Mail verification impossible.%%');
    }
    -- notify user by e-mail
    declare _mail_body any;
    _mail_body := WA_GET_EMAIL_TEMPLATE('WS_JOIN_APPROVE_TEMPLATE');
    -- WA_MAIL_TEMPLATES(templ, web_app, user_name, app_action_url)
    _mail_body := WA_MAIL_TEMPLATES(_mail_body, self, _user_name, sprintf('http://%s/%s', WA_CNAME(), self.wa_home_url()));
    _mail_body := dat || 'Subject: Application registration notification\r\nContent-Type: text/plain; charset=UTF-8\r\n' || _mail_body;
    smtp_send(_smtp_server, _owner_e_mail, _user_e_mail, _mail_body);
    return;
  }
  if(ntype is null and nstatus is null and ostatus = 3) {
    -- Join request rejection
    if(not _smtp_server or length(_smtp_server) = 0) {
      signal('WA002', '%%Mail Server is not defined. Mail verification impossible.%%');
    }
    -- notify user by e-mail
    declare _mail_body any;
    _mail_body := WA_GET_EMAIL_TEMPLATE('WS_JOIN_REJECT_TEMPLATE');
    -- WA_MAIL_TEMPLATES(templ, web_app, user_name, app_action_url)
    _mail_body := WA_MAIL_TEMPLATES(_mail_body, self, _user_name, '');
    _mail_body := dat || 'Subject: Application registration notification\r\nContent-Type: text/plain; charset=UTF-8\r\n' || _mail_body;
    smtp_send(_smtp_server, _owner_e_mail, _user_e_mail, _mail_body);
    return;
  }
  if(ntype is null and nstatus is null and ostatus = 2) {
    -- user was not owner and want to terminate his membership
    if(_member_model in (2, 3, 4)) {
      if(not _smtp_server or length(_smtp_server) = 0) {
        signal('WA002', '%%Mail Server is not defined. Mail verification impossible.%%');
      }
      declare _mail_body any;
      -- notify owner or user my e-mail
      if(connection_get('action_reason') = 'owner') {
        -- notify user by e-mail
        _mail_body := WA_GET_EMAIL_TEMPLATE('WS_TERM_BY_OWNER_TEMPLATE');
        -- WA_MAIL_TEMPLATES(templ, web_app, user_name, app_action_url)
        _mail_body := WA_MAIL_TEMPLATES(_mail_body, self, _user_name, '');
        _mail_body := dat || 'Subject: Application registration notification\r\nContent-Type: text/plain; charset=UTF-8\r\n' || _mail_body;
        smtp_send(_smtp_server, _owner_e_mail, _user_e_mail, _mail_body);
        return;
      }
      else {
        -- notify owner by e-mail
        _mail_body := WA_GET_EMAIL_TEMPLATE('WS_TERM_BY_USER_TEMPLATE');
        -- WA_MAIL_TEMPLATES(templ, web_app, user_name, app_action_url)
        _mail_body := WA_MAIL_TEMPLATES(_mail_body, self, _user_name, '');
        _mail_body := dat || 'Subject: Application registration notification\r\nContent-Type: text/plain; charset=UTF-8\r\n' || _mail_body;
        smtp_send(_smtp_server, _user_e_mail, _owner_e_mail, _mail_body);
        return;
      }
    }
    return;
  }
  if(ntype is null and nstatus is null and ostatus = 1) {
    -- user is owner and want to delete application
    return;
  }
  if(not ntype is null and not otype is null and otype <> ntype and nstatus = 2 and ostatus = 2) {
    -- owner change membership type
    if(_member_model in (2, 3, 4)) {
      if(not _smtp_server or length(_smtp_server) = 0) {
        signal('WA002', '%%Mail Server is not defined. Mail verification impossible.%%');
      }
      declare _mail_body any;
      -- notify user by e-mail
      _mail_body := WA_GET_EMAIL_TEMPLATE('WS_CHANGE_BY_OWNER_TEMPLATE');
      -- WA_MAIL_TEMPLATES(templ, web_app, user_name, app_action_url)
      _mail_body := WA_MAIL_TEMPLATES(_mail_body, self, _user_name, '');
      _mail_body := dat || 'Subject: Application registration notification\r\nContent-Type: text/plain; charset=UTF-8\r\n' || _mail_body;
      smtp_send(_smtp_server, _owner_e_mail, _user_e_mail, _mail_body);
      return;
    }
    return;
  }
  if(ntype is not null and nstatus = 2 and ostatus = 4) {
    -- user's approvement
    if(_member_model in (2, 3, 4)) {
      if(not _smtp_server or length(_smtp_server) = 0) {
        signal('WA002', '%%Mail Server is not defined. Mail verification impossible.%%');
      }
      declare _mail_body any;
      -- notify owner by e-mail
      _mail_body := WA_GET_EMAIL_TEMPLATE('WS_APPROVE_BY_USER_TEMPLATE');
      -- WA_MAIL_TEMPLATES(templ, web_app, user_name, app_action_url)
      _mail_body := WA_MAIL_TEMPLATES(_mail_body, self, _user_name, '');
      _mail_body := dat || 'Subject: Application registration notification\r\nContent-Type: text/plain; charset=UTF-8\r\n' || _mail_body;
      smtp_send(_smtp_server, _user_e_mail, _owner_e_mail, _mail_body);
      return;
    }
    return;
  }

  if(ntype is null and nstatus is null and ostatus = 4) {
    -- user's rejection
    if(_member_model in (2, 3, 4)) {
      if(not _smtp_server or length(_smtp_server) = 0) {
        signal('WA002', '%%Mail Server is not defined. Mail verification impossible.%%');
      }
      declare _mail_body any;
      -- notify owner by e-mail
      _mail_body := WA_GET_EMAIL_TEMPLATE('WS_REJECT_BY_USER_TEMPLATE');
      -- WA_MAIL_TEMPLATES(templ, web_app, user_name, app_action_url)
      _mail_body := WA_MAIL_TEMPLATES(_mail_body, self, _user_name, '');
      _mail_body := dat || 'Subject: Application registration notification\r\nContent-Type: text/plain; charset=UTF-8\r\n' || _mail_body;
      declare exit handler for sqlstate '08006'
	{
	  return;
	};
      commit work;
      smtp_send(_smtp_server, _user_e_mail, _owner_e_mail, _mail_body);
      return;
    }
    return;
  }

  if(otype is null and ostatus is null and nstatus = 2) {
    -- became member immediately without notificalion
    -- may be done by owner only
    return;
  }

  declare _message any;
  _message := sprintf('%%Unhandled wa_notify_member_changed arguments combination%%:\r\n<br/>
                      accounter=%s\r\n
                      otype=%s\r\n
                      ntype=%s\r\n
                      ostatus=%s\r\n
                      nstatus=%s\r\n',
                      coalesce(cast(accounter as varchar), 'null'),
                      coalesce(cast(otype as varchar), 'null'),
                      coalesce(cast(ntype as varchar), 'null'),
                      coalesce(cast(ostatus as varchar), 'null'),
                      coalesce(cast(nstatus as varchar), 'null')
                      );
  signal('WA001', _message);
}
;

create method wa_new_inst (in login varchar) for web_app
{
  declare uid, id, tn, is_pub, is_memb_visb any;

  uid := (select U_ID from SYS_USERS where U_NAME = login);
  select WAI_ID, WAI_TYPE_NAME, WAI_IS_PUBLIC, WAI_MEMBERS_VISIBLE
      into id, tn, is_pub, is_memb_visb from WA_INSTANCE where WAI_NAME = self.wa_name;
  -- WAM_STATUS = 1 means OWNER
  -- XXX: check this why is off
  --set triggers off;
  insert into WA_MEMBER
      (WAM_USER, WAM_INST, WAM_MEMBER_TYPE, WAM_STATUS, WAM_HOME_PAGE, WAM_APP_TYPE, WAM_IS_PUBLIC, WAM_MEMBERS_VISIBLE)
      values (uid, self.wa_name, 1, 1, wa_set_url_t (self), tn, is_pub, is_memb_visb);
  --set triggers on;
  return id;
}
;

create method wa_new_instance_url () for web_app{
  return 'new_inst.vspx';
}
;

create method wa_edit_instance_url () for web_app{
  return 'edit_inst.vspx';
}
;

create procedure WA_INSTANCE_WAI_DESCRIPTION_INDEX_HOOK(inout vtb any, inout d_id any) {
  declare _wai_type_name, _wai_name any;
  select
    WAI_TYPE_NAME,
    WAI_NAME
  into
    _wai_type_name,
    _wai_name
  from
    WA_INSTANCE
  where
    WAI_ID = d_id;
  vt_batch_feed(vtb, _wai_type_name, 0);
  vt_batch_feed(vtb, _wai_name, 0);

  declare _u_id, _u_name, _u_full_name any;
  _u_id := (select top 1 WAM_USER from WA_MEMBER where WAM_INST = _wai_name and WAM_STATUS = 1);
  if(_u_id) {
    select
      U_NAME,
      U_FULL_NAME
    into
      _u_name,
      _u_full_name
    from
      SYS_USERS
    where
      U_ID = _u_id;
    vt_batch_feed(vtb, _u_name, 0);
    vt_batch_feed(vtb, _u_full_name, 0);
    vt_batch_feed(vtb, 'computer science', 0);
  }
  declare _wat_type any;
  _wat_type := (select WAT_TYPE from WA_TYPES where WAT_NAME = _wai_type_name);
  vt_batch_feed(vtb, _wat_type, 0);

  return 0;
}
;

create procedure WA_INSTANCE_WAI_DESCRIPTION_UNINDEX_HOOK(inout vtb any, inout d_id any) {
  declare _wai_type_name, _wai_name any;
  select
    WAI_TYPE_NAME,
    WAI_NAME
  into
    _wai_type_name,
    _wai_name
  from
    WA_INSTANCE
  where
    WAI_ID = d_id;
  vt_batch_feed(vtb, _wai_type_name, 1);
  vt_batch_feed(vtb, _wai_name, 1);

  declare _u_id, _u_name, _u_full_name any;
  _u_id := (select top 1 WAM_USER from WA_MEMBER where WAM_INST = _wai_name and WAM_STATUS = 1);
  if(_u_id) {
    select
      U_NAME,
      U_FULL_NAME
    into
      _u_name,
      _u_full_name
    from
      SYS_USERS
    where
      U_ID = _u_id;
    vt_batch_feed(vtb, _u_name, 1);
    vt_batch_feed(vtb, _u_full_name, 1);
    vt_batch_feed(vtb, 'computer science', 1);
  }
  declare _wat_type any;
  _wat_type := (select WAT_TYPE from WA_TYPES where WAT_NAME = _wai_type_name);
  vt_batch_feed(vtb, _wat_type, 1);

  return 0;
}
;

wa_exec_no_error(
  'CREATE TEXT INDEX ON WA_INSTANCE (WAI_DESCRIPTION) WITH KEY WAI_ID USING FUNCTION'
)
;

wa_exec_no_error(
  'create index WAI_TYPE_NAME_IDX1 on WA_INSTANCE (WAI_TYPE_NAME)'
)
;

create trigger WA_MEMBER_I after insert on WA_MEMBER referencing new as N {
  declare wa web_app;
  declare tn any;

  if (N.WAM_MEMBER_TYPE = 1)
    return;

  select WAI_INST, WAI_TYPE_NAME into wa, tn from WA_INSTANCE where WAI_NAME = N.WAM_INST;

  if (N.WAM_APP_TYPE is null or N.WAM_HOME_PAGE is null)
    {
      set triggers off;
      update WA_MEMBER set
	  WAM_APP_TYPE = tn,
	  WAM_HOME_PAGE = wa_set_url_t (wa)
	  where WAM_USER = N.WAM_USER and  WAM_INST = N.WAM_INST and WAM_MEMBER_TYPE = N.WAM_MEMBER_TYPE;
      set triggers on;
    }

  wa.wa_notify_member_changed(N.WAM_USER, null, N.WAM_MEMBER_TYPE, null, N.WAM_DATA, null, N.WAM_STATUS);
  return;
}
;

-- zdravko
create trigger WA_INSTANCE_I after insert on WA_INSTANCE
{
  update DB.DBA.WA_MEMBER set WAM_IS_PUBLIC = WAI_IS_PUBLIC where WAM_INST = WAI_NAME;
  update DB.DBA.WA_MEMBER set WAM_MEMBERS_VISIBLE = WAI_MEMBERS_VISIBLE where WAM_INST = WAI_NAME;
  update WA_MEMBER set WAM_HOME_PAGE = wa_set_url_t (WAI_INST) where WAM_INST = WAI_NAME;
  update WA_MEMBER set WAM_APP_TYPE = wa_get_type_from_name (WAM_INST) where WAM_INST = WAI_NAME;
}
;
-- zdravko

create trigger WA_MEMBER_U after update on WA_MEMBER referencing old as O, new as N
{
  declare wa web_app;
  select WAI_INST into wa from WA_INSTANCE where WAI_NAME = N.WAM_INST;
  wa.wa_notify_member_changed (N.WAM_USER, O.WAM_MEMBER_TYPE, N.WAM_MEMBER_TYPE,
			  O.WAM_DATA, N.WAM_DATA, O.WAM_STATUS, N.WAM_STATUS);
  return;
}
;

-- zdravko
create trigger WA_INSTANCE_U after update on WA_INSTANCE referencing old as O, new as N
{
  declare wa web_app;

  update DB.DBA.WA_MEMBER set
      WAM_IS_PUBLIC = N.WAI_IS_PUBLIC,
      WAM_MEMBERS_VISIBLE = N.WAI_MEMBERS_VISIBLE,
      WAM_HOME_PAGE = wa_set_url_t (N.WAI_INST),
      WAM_APP_TYPE = wa_get_type_from_name (WAM_INST)
      where WAM_INST = N.WAI_NAME;

  if (O.WAI_NAME <> N.WAI_NAME)
    {
      wa := N.WAI_INST;
      wa.wa_name := N.WAI_NAME;
      --  dbg_obj_print (wa);
      set triggers off;
      update WA_INSTANCE set WAI_INST = wa where WAI_NAME = N.WAI_NAME;
      update WA_INVITATIONS set WI_INSTANCE = N.WAI_NAME where WI_INSTANCE = O.WAI_NAME;
      set triggers on;
    }
}
;
-- zdravko

create trigger WA_MEMBER_D after delete on WA_MEMBER
{
  declare wa web_app;
  declare exit handler for not found {
    return;
  };
  select WAI_INST into wa from WA_INSTANCE where WAI_NAME = WAM_INST;
  wa.wa_notify_member_changed(WAM_USER, WAM_MEMBER_TYPE, null, WAM_DATA, null, WAM_STATUS, null);
  return;
}
;

-- zdravko
create procedure wa_check_package (in pname varchar) -- dublicate conductor procedure
{

  if (wa_vad_check (pname) is null)
    return 0;
  return 1;
}
;


create procedure wa_vad_check (in pname varchar)
{
  declare nam varchar;
  nam := get_keyword (pname, vector ('blog2','Weblog','oDrive','Briefcase','enews2','Feed Manager',
  				      'oMail','Mail','bookmark','Bookmarks','oGallery','Gallery' ,
				      'wiki','Wiki', 'wa', 'Framework','nntpf','Discussion'), null);
  if (nam is null)
    return vad_check_version (pname);
  else
    return vad_check_version (nam);
}
;

-- zdravko

create trigger SYS_USERS_ON_DELETE_WA_FK before delete
 on "DB"."DBA"."SYS_USERS" order 66 referencing old as O {
 declare exit handler for SQLSTATE '*' { ROLLBACK WORK; RESIGNAL; };
  DECLARE _VAR_U_ID VARCHAR;
 _VAR_U_ID := O."U_ID";
   DELETE FROM "DB"."DBA"."WA_MEMBER"  WHERE "WAM_USER" = _VAR_U_ID;
  DELETE FROM "DB"."DBA"."WA_USERS"  WHERE "WAU_U_ID" = _VAR_U_ID;
  delete from sn_entity where sne_org_id = _VAR_U_ID;
};

insert soft WA_MEMBER_MODEL (WMM_ID, WMM_NAME) values (0, 'Open')
;

insert soft WA_MEMBER_MODEL (WMM_ID, WMM_NAME) values (1, 'Closed')
;

insert replacing WA_MEMBER_MODEL (WMM_ID, WMM_NAME) values (2, 'Invitation Only')
;

insert soft WA_MEMBER_MODEL (WMM_ID, WMM_NAME) values (3, 'Approval Based')
;

delete from WA_MEMBER_MODEL where WMM_NAME = 'Notify owner via E-mail'
;

-- zdravko

-- zdravko


--insert soft WA_MEMBER_MODEL (WMM_ID, WMM_NAME) values (4, 'Notify owner via E-mail')
--;

-- UI stuff
create procedure
web_user_password_check (in name varchar, in pass varchar)
{
  declare rc int;
  rc := 0;
  if (exists (select 1 from SYS_USERS where U_NAME = name and U_DAV_ENABLE = 1 and U_IS_ROLE = 0 and
        pwd_magic_calc (U_NAME, U_PASSWORD, 1) = pass and U_ACCOUNT_DISABLED = 0))
    {
      update WS.WS.SYS_DAV_USER set U_LOGIN_TIME = now () where U_NAME = name
	  and (U_LOGIN_TIME is null or U_LOGIN_TIME < dateadd ('minute', -2, now ()));
      rc := 1;
    }
  commit work;
  return rc;
}
;

create procedure inst_child_node (in path varchar, in node varchar)
{
  return xpath_eval (path, node, 0);
}
;

create procedure inst_root_node (in path varchar)
{
  return xpath_eval ('/*',inst_node (), 0);
}
;

create procedure inst_node ()
{
  declare ss any;
  ss := string_output ();
  xml_auto (
'select
  1 as tag,
  null as parent,
  WAT_NAME as [node!1!name],
  null as [node!2!name],
  null as [node!3!name]
  from WA_TYPES
union all
select
  2,
  1,
  WAT_NAME,
  WAI_NAME,
  null
  from WA_INSTANCE, WA_TYPES where WAI_TYPE_NAME = WAT_NAME
union all
select
  2,
  1,
  WAT_NAME,
  \'\',
  null
  from WA_TYPES
union all
select
  3,
  2,
  WAT_NAME,
  WAI_NAME,
  U_NAME
  from WA_INSTANCE, WA_TYPES, SYS_USERS, WA_MEMBER where WAM_STATUS <= 2 WAI_TYPE_NAME = WAT_NAME and
  WAM_USER = U_ID and WAM_INST = WAI_NAME
order by [node!1!name], [node!2!name], [node!3!name]
for xml explicit'
, vector (), ss);
  return xml_tree_doc (string_output_string (ss));
}
;

create procedure WA_CNAME ()
{
  declare default_host, ret varchar;
  default_host := cfg_item_value (virtuoso_ini_path (), 'URIQA', 'DefaultHost');
  if (default_host is not null)
    return default_host;
  ret := sys_stat ('st_host_name');
  if (server_http_port () <> '80')
    ret := ret ||':'|| server_http_port ();
  return ret;
};

create procedure WA_DEFAULT_DOMAIN ()
{
  declare cname, arr varchar;
  cname := WA_CNAME ();
  arr := split_and_decode (cname, 0, '\0\0:');
  if (length (arr) = 2)
    return arr[0];
  else if (length (arr) = 1)
    return arr[0];
  else
    return cname;
};

create procedure WA_GET_HOST()
{
  declare ret varchar;
  declare default_host varchar;
  if (is_http_ctx ())
    {
      ret := http_request_header (http_request_header (), 'Host', null, sys_connected_server_address ());
      if (isstring (ret) and strchr (ret, ':') is null)
        {
          declare hp varchar;
          declare hpa any;
          hp := sys_connected_server_address ();
          hpa := split_and_decode (hp, 0, '\0\0:');
	  if (hpa[1] <> '80')
            ret := ret || ':' || hpa[1];
        }
    }
  else
   {
     default_host := cfg_item_value (virtuoso_ini_path (), 'URIQA', 'DefaultHost');
     if (default_host is not null)
       return default_host;
     ret := sys_stat ('st_host_name');
     if (server_http_port () <> '80')
       ret := ret ||':'|| server_http_port ();
   }

  return ret;
}
;

create procedure WA_MAIL_TEMPLATES(in templ varchar,
                                   in app web_app default null,
                                   in user_name varchar default '',
                                   in app_action_url varchar default '') returns varchar
{

  declare service_name varchar;
  declare app_type, _u_name, full_name, e_mail, password1, descrip varchar;
  declare _u_id, join1, reg1 integer;


  if (templ = '' or templ is null)
    return '';

  select top 1 WS_WEB_TITLE into service_name from WA_SETTINGS;

  if (not length (service_name))
    service_name := sys_stat ('st_host_name');

  _u_name := '';
  full_name := '';
  if(app is not null) {
    select
      WAT_DESCRIPTION
    into
      app_type
    from
      DB.DBA.WA_TYPES,
      DB.DBA.WA_INSTANCE
    where
      WAI_NAME = app.wa_name and
      WAT_NAME = WAI_TYPE_NAME;
    templ := replace(templ, '%app%', app_type);
    -- get owner name
    _u_id := (select top 1 WAM_USER from WA_MEMBER where WAM_INST = app.wa_name and WAM_STATUS = 1);
    if(_u_id) {
      select U_NAME into _u_name from SYS_USERS where U_ID = _u_id;
    }
    templ := replace(templ, '%app_owner%', _u_name);
    templ := replace(templ, '%app_name%', app.wa_name);
    templ := replace(templ, '%app_url%', concat('http://', WA_CNAME(), app.wa_home_url()));
  }
  templ := replace(templ, '%wa_home%', wa_link (1));
  templ := replace(templ, '%service_url%', wa_link (1));
  templ := replace(templ, '%service%', service_name);
  templ := replace(templ, '%app_action_url%', app_action_url);

  if (user_name <> '' and user_name is not null) {
    select U_FULL_NAME, U_E_MAIL, pwd_magic_calc(U_NAME, U_PASSWORD, 1)
      into full_name, e_mail, password1 from SYS_USERS where u_name = user_name;
    templ := replace(templ, '%user%', coalesce (full_name, user_name));
    templ := replace(templ, '%username%', user_name);
    templ := replace(templ, '%password%', password1);
  }

  join1 := 0;
  reg1 := 0;
  select top 1 WS_JOIN_EXPIRY, WS_REGISTRATION_EMAIL_EXPIRY into join1, reg1 from WA_SETTINGS;
  templ := replace(templ, '%timeout_join%', cast(join1 as varchar));
  templ := replace(templ, '%timeout_reg%', cast(reg1 as varchar));
  descrip := '';
  for select WAT_NAME, WAT_DESCRIPTION from WA_TYPES order by 1 do {
    if (WAT_NAME is not null)
      descrip := concat(descrip, WAT_NAME, ' ');
    if (WAT_DESCRIPTION is not null)
      descrip := concat(descrip, WAT_DESCRIPTION, '\r\n');
  }
  templ := replace(templ, '%apps_available%', descrip);
  return templ;
}
;


create procedure INIT_SERVER_SETTINGS ()
{
  declare cnt int;
  cnt := (select count(*) from WA_SETTINGS);
  if (cnt = 1)
    return;
  else if (cnt > 1)
    {
      declare fr int;
      fr := (select top 1 WS_ID from WA_SETTINGS);
      delete from WA_SETTINGS where WS_ID > fr;
    }
  else
    {
      insert soft WA_SETTINGS
	  (WS_REGISTER,
	   WS_MAIL_VERIFY,
	   WS_REGISTRATION_EMAIL_EXPIRY,
	   WS_JOIN_EXPIRY,
	   WS_USE_DEFAULT_SMTP,
	   WS_MEMBER_MODEL,
	   WS_WEB_BANNER,
	   WS_WEB_TITLE,
	   WS_WEB_DESCRIPTION,
	   WS_WELCOME_MESSAGE,
	   WS_COPYRIGHT,
	   WS_DISCLAIMER,
	   WS_DEFAULT_MAIL_DOMAIN
	  )

	  values (
	      1,
	      0,
	      24,
	      72,
	      0,
	      0,
	      'default',
	      '',
	      'Enter your Account ID and Password',
	      '',
	      'Copyright &copy; 1999-2006 OpenLink Software',
	      '',
	      sys_stat ('st_host_name')
	      );
    }
};

INIT_SERVER_SETTINGS ();

create procedure WA_RETRIEVE_MESSAGE(in str any) {
  declare pos1, pos2 any;
  pos1 := locate('%%', str, 1);
  if(not pos1) return str;
  pos2 := locate('%%', str, pos1 + 1);
  if(not pos2) return str;
  return subseq(str, pos1 + 1, pos2 - 1);
}
;

create procedure WA_STATUS_NAME(in status int) {
  if(status = 1) {
    return 'Application owner';
  }
  else if(status = 2) {
    return 'Approved';
  }
  else if(status = 3) {
    return 'Owner approvement pending';
  }
  else if(status = 4) {
    return 'User approvement pending';
  }
  else {
    return 'Invalid status';
  }
}
;

create procedure WA_USER_GET_OPTION(in _name varchar,in _key varchar)
{
  declare _data,_uid any;
  whenever not found goto nf;
  SELECT U_ID INTO _uid FROM SYS_USERS WHERE U_NAME = _name;
  _data := (SELECT deserialize(WAUS_DATA) FROM WA_USER_SETTINGS WHERE WAUS_U_ID = _uid AND upper(WAUS_KEY) = upper(_key));
  return _data;

 nf:
   signal ('42000', sprintf ('The object "%s" does not exists.', _name), 'U0002');
}
;

create procedure WA_USER_SET_OPTION(in _name varchar,in _key varchar,in _data any)
{
  declare _uid any;
  whenever not found goto nf;
  SELECT U_ID INTO _uid FROM SYS_USERS WHERE U_NAME = _name;

  INSERT REPLACING WA_USER_SETTINGS (WAUS_U_ID,WAUS_KEY,WAUS_DATA)
    VALUES(_uid,upper(_key),serialize(_data));

  return;

 nf:
   signal ('42000', sprintf ('The object "%s" does not exists.', _name), 'U0002');
}
;

-- Countries

INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Afghanistan',33,65,'af');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Akrotiri',NULL,NULL,'ax');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Albania',41,20,'al');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Algeria',28,3,'ag');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('American Samoa',-14.33333301544189,-170,'aq');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Andorra',42.5,1.5,'an');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Angola',-12.5,18.5,'ao');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Anguilla',18.25,-63.16666793823242,'av');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Antarctica',-90,0,'ay');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Antigua and Barbuda',17.04999923706055,-61.79999923706055,'ac');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Arctic Ocean',90,0,'xq');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Argentina',-34,-64,'ar');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Armenia',40,45,'am');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Aruba',12.5,-69.96666717529297,'aa');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Ashmore and Cartier Islands',-12.23333358764648,123.0833358764648,'at');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Atlantic Ocean',0,-25,'zh');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Australia',-27,133,'as');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Austria',47.33333206176758,13.33333301544189,'au');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Azerbaijan',40.5,47.5,'aj');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Bahamas, The',24.25,-76,'bf');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Bahrain',26,50.54999923706055,'ba');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Baker Island',0.2166666686534882,-176.5166625976562,'fq');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Bangladesh',24,90,'bg');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Barbados',13.16666698455811,-59.53333282470703,'bb');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Bassas da India',-21.5,39.83333206176758,'bs');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Belarus',53,28,'bo');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Belgium',50.83333206176758,4,'be');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Belize',NULL,NULL,'bh');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Benin',9.5,2.25,'bn');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Bermuda',32.33333206176758,-64.75,'bd');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Bhutan',27.5,90.5,'bt');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Bolivia',-17,-65,'bl');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Bosnia and Herzegovina',44,18,'bk');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Botswana',-22,24,'bc');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Bouvet Island',-54.43333435058594,3.400000095367432,'bv');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Brazil',-10,-55,'br');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('British Indian Ocean Territory',-6,71.5,'io');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('British Virgin Islands',18.5,-64.5,'vi');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Brunei',4.5,114.6666641235352,'bx');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Bulgaria',43,25,'bu');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Burkina Faso',13,-2,'uv');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Burma',22,98,'bm');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Burundi',-3.5,30,'by');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Cambodia',13,105,'cb');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Cameroon',6,12,'cm');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Canada',60,-95,'ca');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Cape Verde',16,-24,'cv');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Cayman Islands',19.5,-80.5,'cj');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Central African Republic',7,21,'ct');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Chad',15,19,'cd');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Chile',-30,-71,'ci');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('China',35,105,'ch');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Christmas Island',-10.5,105.6666641235352,'kt');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Clipperton Island',10.28333377838135,-109.216667175293,'ip');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Cocos (Keeling) Islands',-12.5,96.83333587646484,'ck');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Colombia',4,-72,'co');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Comoros',-12.16666698455811,44.25,'cn');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Congo, Democratic Republic of the',0,25,'cg');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Congo, Republic of the',-1,15,'cf');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Cook Islands',-21.23333358764648,-159.7666625976562,'cw');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Coral Sea Islands',-18,152,'cr');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Costa Rica',10,-84,'cs');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Cote d\47Ivoire',NULL,NULL,'iv');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Croatia',45.16666793823242,15.5,'hr');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Cuba',21.5,-80,'cu');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Cyprus',35,33,'cy');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Czech Republic',49.75,15.5,'ez');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Denmark',56,10,'da');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Dhekelia',NULL,NULL,'dx');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Djibouti',11.5,43,'dj');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Dominica',15.41666698455811,-61.33333206176758,'do');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Dominican Republic',19,-70.66666412353516,'dr');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('East Timor',NULL,NULL,'tt');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Ecuador',-2,-77.5,'ec');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Egypt',27,30,'eg');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('El Salvador',13.83333301544189,-88.91666412353516,'es');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Equatorial Guinea',2,10,'ek');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Eritrea',15,39,'er');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Estonia',59,26,'en');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Ethiopia',8,38,'et');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Europa Island',-22.33333396911621,40.36666488647461,'eu');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('European Union',NULL,NULL,'ee');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Falkland Islands (Islas Malvinas)',-51.75,-59,'fk');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Faroe Islands',62,-7,'fo');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Fiji',-18,175,'fj');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Finland',64,26,'fi');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('France',46,2,'fr');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('French Guiana',4,-53,'fg');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('French Polynesia',-15,-140,'fp');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('French Southern and Antarctic Lands',-43,67,'fs');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Gabon',-1,11.75,'gb');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Gambia, The',13.46666622161865,-16.5666675567627,'ga');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Gaza Strip',31.41666603088379,34.33333206176758,'gz');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Georgia',42,43.5,'gg');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Germany',51,9,'gm');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Ghana',8,-2,'gh');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Gibraltar',36.18333435058594,-5.366666793823242,'gi');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Glorioso Islands',-11.5,47.33333206176758,'go');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Greece',39,22,'gr');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Greenland',72,-40,'gl');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Grenada',12.11666679382324,-61.66666793823242,'gj');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Guadeloupe',16.25,-61.58333206176758,'gp');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Guam',NULL,NULL,'gq');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Guatemala',15.5,-90.25,'gt');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Guernsey',49.46666717529297,-2.583333253860474,'gk');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Guinea',11,-10,'gv');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Guinea-Bissau',12,-15,'pu');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Guyana',5,-59,'gy');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Haiti',19,-72.41666412353516,'ha');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Heard Island and McDonald Islands',-53.09999847412109,72.51667022705078,'hm');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Holy See (Vatican City)',41.90000152587891,12.44999980926514,'vt');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Honduras',15,-86.5,'ho');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Hong Kong',22.25,114.1666641235352,'hk');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Howland Island',0.800000011920929,-176.6333312988281,'hq');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Hungary',47,20,'hu');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Iceland',65,-18,'ic');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('India',20,77,'in');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Indian Ocean',-20,80,'xo');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Indonesia',-5,120,'id');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Iran',32,53,'ir');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Iraq',33,44,'iz');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Ireland',53,-8,'ei');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Israel',31.5,34.75,'is');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Italy',42.83333206176758,12.83333301544189,'it');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Jamaica',18.25,-77.5,'jm');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Jan Mayen',71,-8,'jn');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Japan',36,138,'ja');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Jarvis Island',-0.3666666746139526,-160.0500030517578,'dq');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Jersey',49.25,-2.166666746139526,'je');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Johnston Atoll',16.75,-169.5166625976562,'jq');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Jordan',31,36,'jo');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Juan de Nova Island',-17.04999923706055,42.75,'ju');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Kazakhstan',48,68,'kz');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Kenya',1,38,'ke');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Kingman Reef',6.400000095367432,-162.3999938964844,'kq');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Kiribati',1.416666626930237,173,'kr');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Korea, North',40,127,'kn');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Korea, South',37,127.5,'ks');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Kuwait',29.5,45.75,'ku');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Kyrgyzstan',41,75,'kg');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Laos',18,105,'la');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Latvia',57,25,'lg');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Lebanon',33.83333206176758,35.83333206176758,'le');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Lesotho',-29.5,28.5,'lt');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Liberia',6.5,-9.5,'li');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Libya',25,17,'ly');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Liechtenstein',47.16666793823242,9.533333778381348,'ls');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Lithuania',56,24,'lh');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Luxembourg',49.75,6.166666507720947,'lu');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Macau',22.16666603088379,113.5500030517578,'mc');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Macedonia',NULL,NULL,'mk');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Madagascar',-20,47,'ma');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Malawi',-13.5,34,'mi');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Malaysia',2.5,112.5,'my');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Maldives',3.25,73,'mv');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Mali',17,-4,'ml');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Malta',35.83333206176758,14.58333301544189,'mt');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Man, Isle of',54.25,-4.5,'im');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Marshall Islands',9,168,'rm');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Martinique',14.66666698455811,-61,'mb');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Mauritania',20,-12,'mr');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Mauritius',-20.28333282470703,57.54999923706055,'mp');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Mayotte',-12.83333301544189,45.16666793823242,'mf');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Mexico',23,-102,'mx');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Micronesia, Federated States of',6.916666507720947,158.25,'fm');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Midway Islands',28.21666717529297,-177.3666687011719,'mq');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Moldova',47,29,'md');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Monaco',43.73333358764648,7.400000095367432,'mn');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Mongolia',46,105,'mg');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Montserrat',16.75,-62.20000076293945,'mh');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Morocco',32,-5,'mo');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Mozambique',-18.25,35,'mz');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Namibia',-22,17,'wa');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Nauru',-0.5333333611488342,166.9166717529297,'nr');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Navassa Island',18.41666603088379,-75.03333282470703,'bq');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Nepal',28,84,'np');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Netherlands',52.5,5.75,'nl');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Netherlands Antilles',12.25,-68.75,'nt');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('New Caledonia',-21.5,165.5,'nc');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('New Zealand',-41,174,'nz');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Nicaragua',13,-85,'nu');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Niger',16,8,'ng');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Nigeria',10,8,'ni');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Niue',-19.03333282470703,-169.8666687011719,'ne');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Norfolk Island',-29.03333282470703,167.9499969482422,'nf');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Northern Mariana Islands',15.19999980926514,145.75,'cq');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Norway',62,10,'no');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Oman',21,57,'mu');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Other',NULL,NULL,NULL);
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Pacific Ocean',0,-160,'zn');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Pakistan',30,70,'pk');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Palau',7.5,134.5,'ps');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Palmyra Atoll',5.866666793823242,-162.1000061035156,'lq');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Panama',9,-80,'pm');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Papua New Guinea',-6,147,'pp');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Paracel Islands',16.5,112,'pf');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Paraguay',-23,-58,'pa');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Peru',-10,-76,'pe');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Philippines',13,122,'rp');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Pitcairn Islands',-25.0666675567627,-130.1000061035156,'pc');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Poland',52,20,'pl');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Portugal',39.5,-8,'po');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Puerto Rico',18.25,-66.5,'rq');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Qatar',25.5,51.25,'qa');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Reunion',-21.10000038146973,55.59999847412109,'re');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Romania',46,25,'ro');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Russia',60,100,'rs');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Rwanda',-2,30,'rw');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Saint Helena',-15.93333339691162,-5.699999809265137,'sh');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Saint Kitts and Nevis',17.33333396911621,-62.75,'sc');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Saint Lucia',13.88333320617676,-61.13333511352539,'st');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Saint Pierre and Miquelon',46.83333206176758,-56.33333206176758,'sb');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Saint Vincent and the Grenadines',13.25,-61.20000076293945,'vc');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Samoa',-13.58333301544189,-172.3333282470703,'ws');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('San Marino',43.76666641235352,12.41666698455811,'sm');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Sao Tome and Principe',1,7,'tp');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Saudi Arabia',25,45,'sa');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Senegal',14,-14,'sg');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Serbia and Montenegro',NULL,NULL,'yi');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Seychelles',-4.583333492279053,55.66666793823242,'se');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Sierra Leone',8.5,-11.5,'sl');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Singapore',1.366666674613953,103.8000030517578,'sn');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Slovakia',48.66666793823242,19.5,'lo');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Slovenia',46,15,'si');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Solomon Islands',-8,159,'bp');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Somalia',10,49,'so');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('South Africa',-29,24,'sf');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('South Georgia and the South Sandwich Islands',-54.5,-37,'sx');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Southern Ocean',-65,0,'oo');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Spain',40,-4,'sp');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Spratly Islands',8.633333206176758,111.9166641235352,'pg');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Sri Lanka',7,81,'ce');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Sudan',15,30,'su');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Suriname',4,-56,'ns');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Svalbard',78,20,'sv');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Swaziland',-26.5,31.5,'wz');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Sweden',62,15,'sw');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Switzerland',47,8,'sz');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Syria',35,38,'sy');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Taiwan',23.5,121,'tw');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Tajikistan',39,71,'ti');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Tanzania',-6,35,'tz');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Thailand',15,100,'th');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Togo',8,1.166666626930237,'to');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Tokelau',-9,-172,'tl');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Tonga',-20,-175,'tn');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Trinidad and Tobago',11,-61,'td');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Tromelin Island',-15.86666679382324,54.41666793823242,'te');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Tunisia',34,9,'ts');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Turkey',39,35,'tu');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Turkmenistan',40,60,'tx');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Turks and Caicos Islands',21.75,-71.58333587646484,'tk');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Tuvalu',-8,178,'tv');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Uganda',1,32,'ug');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Ukraine',49,32,'up');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('United Arab Emirates',24,54,'ae');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('United Kingdom',54,-2,'uk');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('United States',38,-97,'us');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Uruguay',-33,-56,'uy');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Uzbekistan',41,64,'uz');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Vanuatu',-16,167,'nh');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Venezuela',8,-66,'ve');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Vietnam',16,106,'vm');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Virgin Islands',18.33333396911621,-64.83333587646484,'vq');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Wake Island',19.28333282470703,166.6000061035156,'wq');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Wallis and Futuna',-13.30000019073486,-176.1999969482422,'wf');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('West Bank',32,35.25,'we');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Western Sahara',24.5,-13,'wi');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Yemen',15,48,'ym');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Zambia',-15,30,'za');
INSERT SOFT DB.DBA.WA_COUNTRY(WC_NAME,WC_LAT,WC_LNG,WC_CODE) VALUES('Zimbabwe',-20,30,'zi');

insert soft WA_INDUSTRY values('Accounting/Finance');
insert soft WA_INDUSTRY values('Advertising/Public Relations');
insert soft WA_INDUSTRY values('Arts/Entertainment/Publishing');
insert soft WA_INDUSTRY values('Banking/Mortgage');
insert soft WA_INDUSTRY values('Clerical/Administrative');
insert soft WA_INDUSTRY values('Construction/Facilities');
insert soft WA_INDUSTRY values('Customer Service');
insert soft WA_INDUSTRY values('Education/Training');
insert soft WA_INDUSTRY values('Engineering/Architecture');
insert soft WA_INDUSTRY values('Government');
insert soft WA_INDUSTRY values('Healthcare');
insert soft WA_INDUSTRY values('Hospitality/Travel');
insert soft WA_INDUSTRY values('Human Resources');
insert soft WA_INDUSTRY values('Insurance');
insert soft WA_INDUSTRY values('Internet/New Media');
insert soft WA_INDUSTRY values('Law Enforcement/Security');
insert soft WA_INDUSTRY values('Legal');
insert soft WA_INDUSTRY values('Management Consulting');
insert soft WA_INDUSTRY values('Manufacturing/Operations');
insert soft WA_INDUSTRY values('Marketing');
insert soft WA_INDUSTRY values('Non-Profit/Volunteer');
insert soft WA_INDUSTRY values('Pharmaceutical/Biotech');
insert soft WA_INDUSTRY values('Real Estate');
insert soft WA_INDUSTRY values('Restaurant/Food Service');
insert soft WA_INDUSTRY values('Retail');
insert soft WA_INDUSTRY values('Sales');
insert soft WA_INDUSTRY values('Technology');
insert soft WA_INDUSTRY values('Telecommunications');
insert soft WA_INDUSTRY values('Transportation/Logistics');
insert soft WA_INDUSTRY values('Other');

delete from WA_TYPES where WAT_NAME = 'WA' and WAT_DESCRIPTION = 'wa' and WAT_TYPE = 'db.dba.web_app' and WAT_REALM = 'wa';
delete from WA_INSTANCE where WAI_NAME = 'WA' and WAI_TYPE_NAME = 'WA';


create procedure
sql_user_password (in name varchar)
{
  declare pass varchar;
  pass := NULL;
  whenever not found goto none;
  select pwd_magic_calc (U_NAME, U_PASSWORD, 1) into pass
      from DB.DBA.SYS_USERS where U_NAME = name;
none:
  return pass;
}
;

create procedure
sql_user_password_check (in name varchar, in pass varchar)
{
  if (exists (select 1 from DB.DBA.SYS_USERS where U_NAME = name and pwd_magic_calc (U_NAME, U_PASSWORD, 1) = pass))
    return 1;
  return 0;
}
;

create procedure
db.dba.dav_browse_proc1 (in path varchar,
                         in show_details integer := 0,
                         in dir_select integer := 0,
                         in filter varchar := '',
                         in search_type integer := -1,
                         in search_word varchar := '',
			 in ord any := '',
			 in ordseq varchar := 'asc'
			 ) returns any
{
  declare i, j, len, len1 integer;
  declare dirlist, retval any;
  declare cur_user, cur_group, user_name, group_name, perms, perms_tmp, cur_file varchar;
  declare stat, msg, mdt, dta any;

  cur_user := connection_get ('vspx_user');
  path := replace (path, '"', '');

  if (length (path) = 0 and search_type = -1)
    {
      if (show_details = 0)
        retval := vector (vector (1, 'DAV', NULL, '0', '', 'Root', '', '', ''));
      else
        retval := vector (vector (1, 'DAV'));
      return retval;
    }
  else
    if (length(path) = 0 and search_type <> -1)
      path := 'DAV';

  if (path[length (path) - 1] <> ascii ('/'))
    path := concat (path, '/');

  if (path[0] <> ascii ('/'))
    path := concat ('/', path);

  if (isnull (filter) or filter = '')
    filter := '%';

  replace (filter, '*', '%');
  retval := vector ();
  if (search_type = 0 or search_type = -1)
    {
      if (ord = 'name')
	ord := 11;
      else if (ord = 'size')
	ord := 3;
      else if (ord = 'type')
	ord := 10;
      else if (ord = 'modified')
	ord := 4;
      else if (ord = 'owner')
	ord := 8;
      else if (ord = 'group')
	ord := 7;

      if (isinteger (ord))
	ord := sprintf (' order by %d %s', ord, ordseq);

      if (search_type = 0)
	{
	  --dbg_obj_print ('case 1');
	  exec (concat ('select * from Y_DAV_DIR where path = ? and recursive = ? and auth_uid = ? ', ord),
	     stat, msg, vector (path, 1, cur_user), 0, mdt, dirlist);
	  -- old behaviour
          --dirlist := YACUTIA_DAV_DIR_LIST (path, 1, cur_user);
	}
      else
	{
	  --dbg_obj_print ('case 2');
	  exec (concat ('select * from Y_DAV_DIR where path = ? and recursive = ? and auth_uid = ? ', ord),
	     stat, msg, vector (path, 0, cur_user), 0, mdt, dirlist);
	  --dbg_obj_print (dirlist);
	  -- old behaviour
          -- dirlist := YACUTIA_DAV_DIR_LIST (path, 0, cur_user);
	}

      if (not isarray (dirlist))
        return retval;

      len := length (dirlist);
      i := 0;

      while (i < len)
        {
          if (lower (dirlist[i][1]) = 'c') --  and dirlist[i][10] like filter) -- lets not filter out collections!
            {
              cur_file := trim (dirlist[i][0], '/');
              cur_file := subseq (cur_file, strrchr (cur_file, '/') + 1);

              if (search_type = -1 or
                  (search_type = 0 and cur_file like search_word))
                {
                  if (show_details = 0)
                    {
                      if (dirlist[i][7] is not null)
                        user_name := dirlist[i][7];
                      else
                        user_name := 'none';

                      if (dirlist[i][6] is not null)
                        group_name := dirlist[i][6];
                      else
                        group_name := 'none';

	              perms_tmp := dirlist[i][5];
                      if (length (perms_tmp) = 9)
                        perms_tmp := perms_tmp || 'N';
                      perms := DAV_PERM_D2U (perms_tmp);

                      if (search_type = 0)
                        retval :=
                          vector_concat(retval,
                                        vector (vector (1,
                                                        dirlist[i][0],
                                                        NULL,
                                                        'N/A',
                                                        yac_hum_datefmt (dirlist[i][3]),
                                                        'folder',
                                                        user_name,
                                                        group_name,
                                                        perms)));
                      else
                        retval :=
                          vector_concat(retval,
                                        vector (vector (1,
                                                        dirlist[i][10],
                                                        NULL,
                                                        'N/A',
                                                        yac_hum_datefmt (dirlist[i][3]),
                                                        'folder',
                                                        user_name,
                                                        group_name,
                                                        perms)));
                    }
                  else
                    {
                      if (search_type = 0)
                        retval := vector_concat(retval,
                                                vector (vector (1, dirlist[i][0])));
                      else
                        retval := vector_concat(retval,
                                                vector (vector (1, dirlist[i][10])));
                    }
                  }
                }
              i := i + 1;
            }
          if (dir_select = 0 or dir_select = 2)
            {
              i := 0;
              while (i < len)
                {
                  if (lower (dirlist[i][1]) <> 'c' and dirlist[i][10] like filter)
                    {
                      cur_file := trim (aref (aref (dirlist, i), 0), '/');
                      cur_file := subseq (cur_file, strrchr (cur_file, '/') + 1);

                      if (search_type = -1 or
                          (search_type = 0 and cur_file like search_word))
                        {
                          if (show_details = 0)
                            {
                              if (dirlist[i][7] is not null)
				user_name := dirlist[i][7];
                              else
                                user_name := 'none';

                              if (dirlist[i][6] is not null)
				group_name := dirlist[i][6];
                              else
                                group_name := 'none';

	              	      perms_tmp := dirlist[i][5];
                      	      if (length (perms_tmp) = 9)
                        	perms_tmp := perms_tmp || 'N';
			      perms := DAV_PERM_D2U (perms_tmp);

                              if (search_type = 0)
                                retval :=
                                  vector_concat(retval,
                                                vector (vector (0,
                                                                dirlist[i][0],
                                                                NULL,
                                                                yac_hum_fsize (dirlist[i][2]),
                                                                yac_hum_datefmt (dirlist[i][3]),
                                                                dirlist[i][9],
                                                                user_name,
                                                                group_name,
                                                                perms )));
                              else
                                retval :=
                                  vector_concat(retval,
                                                vector( vector (0,
                                                                dirlist[i][10],
                                                                NULL,
                                                                yac_hum_fsize (dirlist[i][2]),
                                                                yac_hum_datefmt (dirlist[i][3]),
                                                                dirlist[i][9],
                                                                user_name,
                                                                group_name,
                                                                perms )));
                            }
                          else
                            {
                              if (search_type = 0)
                                retval := vector_concat (retval,
                                                         vector(vector(0, dirlist[i][0])));
                              else
                                retval := vector_concat (retval,
                                                         vector(vector(0, dirlist[i][10])));
                            }
                        }
                    }
                    i := i + 1;
                  }
         }
            }
          else
            if (search_type = 1)
              {
                retval := vector();
                declare _u_name, _g_name varchar;
                declare _maxres integer;
                declare _qtype varchar;
                declare _out varchar;
                declare _style_sheet varchar;
                declare inx integer;
                declare _qfrom varchar;
                declare _root_elem varchar;
                declare _u_id, _cutat integer;
                declare _entity any;
                declare _res_name_sav varchar;
                declare _out_style_sheet, _no_matches, _trf, _disp_result varchar;
                declare _save_as, _own varchar;

    -- These parameters are needed for WebDAV browser

                declare _current_uri, _trf_doc, _q_scope, _sty_to_ent,
                _sid_id, _sys, _mod varchar;
                declare _dav_result any;
                declare _e_content any;
                declare err varchar;
                declare _no_match, _last_match, _prev_match, _cntr integer;

                err := ''; stat := '00000';
                _dav_result := null;

                declare exit handler for sqlstate '*'
                  {
                    stat := __SQL_STATE; err := __SQL_MESSAGE;
                  };

	      if (ord = 'name')
		ord := 2;
	      else if (ord = 'size')
		ord := 10;
	      else if (ord = 'type')
		ord := 6;
	      else if (ord = 'modified')
		ord := 7;
	      else if (ord = 'owner')
		ord := 4;
	      else if (ord = 'group')
		ord := 5;

	      if (isinteger (ord))
		ord := sprintf (' order by %d %s', ord, ordseq);

                if (not is_empty_or_null (search_word))
                  {
		    stat := '00000';
                    exec (concat ('select RES_ID, RES_NAME, RES_CONTENT, RES_OWNER, RES_GROUP, RES_TYPE, RES_MOD_TIME, RES_PERMS,
                                RES_FULL_PATH, length (RES_CONTENT)
                           from WS.WS.SYS_DAV_RES
                           where contains (RES_CONTENT, ?)', ord), stat, msg, vector (search_word), 0, mdt, dta);


		    if (stat = '00000')
		      {
			declare RES_ID, RES_NAME, RES_CONTENT, RES_OWNER, RES_GROUP, RES_TYPE,
				RES_MOD_TIME, RES_PERMS, RES_FULL_PATH any;

			foreach (any elm in dta) do
			  {
			    RES_ID := elm[0];
			    RES_NAME := elm[1];
		            RES_CONTENT := elm[2];
	    		    RES_OWNER := elm[3];
	                    RES_GROUP  := elm[4];
	                    RES_TYPE  := elm[5];
	                    RES_MOD_TIME  := elm[6];
	                    RES_PERMS  := elm[7];
	                    RES_FULL_PATH := elm[8];

			    if (exists (select 1 from WS.WS.SYS_DAV_PROP
					  where PROP_NAME = 'xper' and
						PROP_TYPE = 'R' and
						PROP_PARENT_ID = RES_ID))
			      {
				_e_content := string_output ();
				http_value (xml_persistent (RES_CONTENT), null, _e_content);
				_e_content := string_output_string (_e_content);
			      }
			    else
			      _e_content := RES_CONTENT;

			    if (RES_GROUP is not null and RES_GROUP > 0)
			      {
				_g_name := (select G_NAME from WS.WS.SYS_DAV_GROUP where G_ID = RES_GROUP);
			      }
			    else
			      {
				_g_name := 'no group';
			      }

			    if (RES_OWNER is not null and RES_OWNER > 0)
			      {
				_u_name := (select U_NAME from WS.WS.SYS_DAV_USER where U_ID = RES_OWNER);
			      }
			    else
			      {
				_u_name := 'Public';
			      }

			    if (show_details = 0)
			      {
				retval :=
				  vector_concat (retval,
						 vector (vector (0,
								 RES_FULL_PATH,
								 NULL,
								 yac_hum_fsize (length (RES_CONTENT)),
								 yac_hum_datefmt (RES_MOD_TIME),
								 RES_TYPE,
								 _u_name,
								 _g_name,
								 adm_dav_format_perms (RES_PERMS))));
			      }
			    else
			      {
				retval := vector_concat(retval,
							vector (vector (0,
									RES_FULL_PATH)));
			      }
		            inx := inx + 1;
	                 }
		      }
       }
    }
  return retval;
}
;

create procedure
dav_browse_proc_meta1(in show_details integer := 0) returns any
{
  declare retval any;
  if (show_details = 0)
    retval := vector('ITEM_IS_CONTAINER',
                     'ITEM_NAME',
                     'ICON_NAME',
                     'Size',
                     'Modified',
                     'Type',
                     'Owner',
                     'Group',
                     'Permissions');
  else
    retval := vector('ITEM_IS_CONTAINER', 'ITEM_NAME');
  return retval;
}
;

create procedure
YACUTIA_DAV_COPY (in path varchar,
                  in destination varchar,
                  in overwrite integer := 0,
                  in permissions varchar := '110100000R',
                  in uid any := NULL,
                  in gid any := NULL)
{
  declare rc integer;
  declare pwd1, cur_user any;
  cur_user := connection_get ('vspx_user');

  if (cur_user = 'dba')
    cur_user := 'dav';

  pwd1 := (select pwd_magic_calc (U_NAME, U_PASSWORD, 1) from DB.DBA.SYS_USERS where U_NAME = cur_user);

  rc := DB.DBA.DAV_COPY (path, destination, overwrite, permissions, uid, gid, cur_user, pwd1);
  return rc;
}
;

create procedure
YACUTIA_DAV_MOVE (in path varchar,
                  in destination varchar,
                  in overwrite varchar)
{
  declare rc integer;
  declare pwd1, cur_user any;
  cur_user := connection_get ('vspx_user');

  if (cur_user = 'dba')
    cur_user := 'dav';

  pwd1 := (select pwd_magic_calc (U_NAME, U_PASSWORD, 1) from DB.DBA.SYS_USERS where U_NAME = cur_user);

  rc := DB.DBA.DAV_MOVE (path, destination, overwrite, cur_user, pwd1);
  return rc;
}
;

create procedure
YACUTIA_DAV_STATUS (in status integer) returns varchar
{
  if (status = -1)
    return 'Invalid target path';

  if (status = -2)
    return 'Invalid destination path';

  if (status = -3)
    return 'Destination already exists and overwrite flag not set';

  if (status = -4)
    return 'Invalid target type (resource) in copy/move';

  if (status = -5)
    return 'Invalid permissions';

  if (status = -6)
    return 'Invalid uid';

  if (status = -7)
    return 'Invalid gid';

  if (status = -8)
    return 'Target is locked';

  if (status = -9)
    return 'Destination is locked';

  if (status = -10)
    return 'Property name is reserved (protected or private)';

  if (status = -11)
    return 'Property does not exists';

  if (status = -12)
    return 'Authentication failed';

  if (status = -13)
    return 'Insufficient privileges for operation';

  if (status = -14)
    return 'Invalid target type';

  if (status = -15)
    return 'Invalid umask';

  if (status = -16)
    return 'Property already exists';

  if (status = -17)
    return 'Invalid property value';

  if (status = -18)
    return 'No such user';

  if (status = -19)
    return 'No home directory';

  return sprintf ('Unknown error %d', status);
}
;

create procedure
YACUTIA_DAV_DELETE (in path varchar,
                    in silent integer := 0,
                    in extern integer := 1)
{
  declare rc integer;
  declare pwd1, cur_user any;
  cur_user := connection_get ('vspx_user');

  if (cur_user = 'dba')
    cur_user := 'dav';

  pwd1 := (select pwd_magic_calc (U_NAME, U_PASSWORD, 1) from DB.DBA.SYS_USERS where U_NAME = cur_user);

  rc := DB.DBA.DAV_DELETE_INT (path, silent, cur_user, pwd1, extern);
  return rc;
}
;

create procedure
YACUTIA_DAV_RES_UPLOAD (in path varchar,
                        inout content any,
                        in type varchar := '',
                        in permissions varchar := '110100000R',
                        in uid varchar := 'dav',
                        in gid varchar := 'dav',
                        in cr_time datetime := null,
                        in mod_time datetime := null,
                        in _rowguid varchar := null)
{
  declare rc integer;
  declare pwd1, cur_user any;
  cur_user := connection_get ('vspx_user');

  if (cur_user = 'dba')
    cur_user := 'dav';

  pwd1 := (select pwd_magic_calc (U_NAME, U_PASSWORD, 1) from DB.DBA.SYS_USERS where U_NAME = cur_user);

  rc := DB.DBA.DAV_RES_UPLOAD_STRSES (path, content, type, permissions, uid, gid, cur_user, pwd1);
  return rc;
}
;

create procedure
YACUTIA_DAV_COL_CREATE (in path varchar,
                        in permissions varchar,
                        in uid varchar,
                        in gid varchar)
{
  declare rc integer;
  declare pwd1, cur_user any;

  cur_user := connection_get ('vspx_user');

  if (cur_user = 'dba')
    cur_user := 'dav';

  pwd1 := (select pwd_magic_calc (U_NAME, U_PASSWORD, 1) from DB.DBA.SYS_USERS where U_NAME = cur_user);

  rc := DB.DBA.DAV_COL_CREATE (path, permissions, uid, gid, cur_user, pwd1);
  return rc;
}
;

create procedure
YACUTIA_DAV_DIR_LIST (in path varchar := '/DAV/',
                      in recursive integer := 0,
                      in auth_uid varchar := 'dav')
{
  declare res, pwd1 any;

  if (auth_uid = 'dba')
    auth_uid := 'dav';

  pwd1 := (select pwd_magic_calc (U_NAME, U_PASSWORD, 1) from DB.DBA.SYS_USERS where U_NAME = auth_uid);
  res := DB.DBA.DAV_DIR_LIST (path, recursive, auth_uid, pwd1);
  return res;
}
;

create procedure
db.dba.yac_hum_fsize (in sz integer) returns varchar
{
  if (sz = 0)
    return ('Zero');
  if (sz < 1024)
    return (sprintf ('%dB', cast (sz as integer)));
  if (sz < 102400)
    return (sprintf ('%.1fkB', sz/1024));
  if (sz < 1048576)
    return (sprintf ('%dkB', cast (sz/1024 as integer)));
  if (sz < 104857600)
    return (sprintf ('%.1fMB', sz/1048576));
  if (sz < 1073741824)
    return (sprintf ('%dMB', cast (sz/1048576 as integer)));
  return (sprintf ('%.1fGB', sz/1073741824));
}
;

create procedure
yac_hum_datefmt (in d datetime)
{

  declare date_part varchar;
  declare time_part varchar;
  declare min_diff integer;
  declare day_diff integer;

  if (isnull (d))
    {
      return ('Never');
    }

  day_diff := datediff ('day', d, now ());
  if (day_diff < 1)
    {
      min_diff := datediff ('minute', d, now ());
      if (min_diff = 1)
        {
          return ('A minute ago');
        }
      else if (min_diff < 1)
        {
          return ('Less than a minute ago');
        }
      else if (min_diff < 60)
        {
          return (sprintf ('%d minutes ago', min_diff));
        }
      else return (sprintf ('Today at %02d:%02d', hour (d), minute (d)));
    }
  if (day_diff < 2)
    {
      return (sprintf ('Yesterday at %02d:%02d', hour (d), minute (d)));
    }
  return (sprintf ('%02d/%02d/%02d %02d:%02d',
                   year (d),
                   month (d),
                   dayofmonth (d),
                   hour (d),
                   minute (d)));
}
;

create procedure
YACUTIA_DAV_DIR_LIST_P (in path varchar := '/DAV/', in recursive integer := 0, in auth_uid varchar := 'dav')
{
  declare arr, pwd1 any;
  declare i, l integer;
  declare FULL_PATH, PERMS, MIME_TYPE, NAME varchar;
  declare TYPE char(1);
  declare RLENGTH, ID, GRP, OWNER integer;
  declare MOD_TIME, CR_TIME datetime;
  result_names (FULL_PATH, TYPE, RLENGTH, MOD_TIME, ID, PERMS, GRP, OWNER, CR_TIME, MIME_TYPE, NAME);

  if (auth_uid = 'dba')
    auth_uid := 'dav';

  pwd1 := (select pwd_magic_calc (U_NAME, U_PASSWORD, 1) from DB.DBA.SYS_USERS where U_NAME = auth_uid);
  arr := DB.DBA.DAV_DIR_LIST (path, recursive, auth_uid, pwd1);
  i := 0; l := length (arr);
  while (i < l)
    {
      declare own, _grp any;
      own := 'none';
      _grp := 'none';
      if (arr[i][7] is not null)
        own := coalesce ((select U_NAME from DB.DBA.SYS_USERS where U_ID = arr[i][7]), 'none');
      if (arr[i][6] is not null)
        _grp := coalesce ((select U_NAME from DB.DBA.SYS_USERS where U_ID = arr[i][6]), 'none');
      result (arr[i][0],
    arr[i][1],
    arr[i][2],
    arr[i][3],
    arr[i][4],
    arr[i][5],
    _grp,
    own,
    arr[i][8],
    arr[i][9],
    arr[i][10]);
      i := i + 1;
    }
}
;

wa_exec_no_error_log('create procedure view Y_DAV_DIR as YACUTIA_DAV_DIR_LIST_P (path,recursive,auth_uid) (FULL_PATH varchar, TYPE varchar, RLENGTH integer, MOD_TIME datetime, ID integer, PERMS varchar, GRP varchar, OWNER varchar, CR_TIME datetime, MIME_TYPE varchar, NAME varchar)')
;

/*
   conversion
*/

create procedure wa_utf8_to_wide (in s any, in _from int := 0, in _to int := 0)
{
  declare ret any;
  if (isblob (s))
    s := blob_to_string (s);
  if (isstring (s))
    ret := charset_recode (s, 'UTF-8', '_WIDE_');
  else
    ret := s;
  if (isinteger (ret))
    ret := s;
  if (_from >= 0 and _to > 0 and _to > _from)
    ret := substring (ret, _from, _to);
  return ret;
}
;

create procedure wa_wide_to_utf8 (inout str any)
{
    if (iswidestring (str))
          return charset_recode (str, '_WIDE_', 'UTF-8' );
      return str;
}
;


create procedure wa_trim (in s any)
{
  return trim (s);
}
;

/*
   mail routines
*/

create procedure WA_SEND_MAIL (in _from any, in _to any, in subj any, in msg any)
{
   declare _smtp_server, _mail_body, enc, dat any;
   if ((select max(WS_USE_DEFAULT_SMTP) from WA_SETTINGS) = 1)
     {
       _smtp_server := cfg_item_value(virtuoso_ini_path(), 'HTTPServer', 'DefaultMailServer');
     }
   else
     {
       _smtp_server := (select max(WS_SMTP) from WA_SETTINGS);
     }
  enc := encode_base64 (subj);
  enc := replace (enc, '\r\n', '');
  subj := concat ('Subject: =?UTF-8?B?', enc, '?=\r\n');
  dat := sprintf ('Date: %s\r\n', date_rfc1123 (now ()));
  _mail_body := dat || subj || 'Content-Type: text/plain; charset=UTF-8\r\n\r\n' || msg;
  --dbg_obj_print (_smtp_server);
  --dbg_obj_print (_mail_body);
  if(not _smtp_server or length(_smtp_server) = 0)
    {
      signal('WA002', 'The Mail Server is not defined. Mail can not be sent.');
    }
  --dbg_obj_print (_from, _to);
  smtp_send (_smtp_server, _from, _to, _mail_body);
}
;

wa_exec_no_error_log(
  'CREATE TABLE WA_USER_INFO
  (
    WAUI_U_ID int,
    WAUI_VISIBLE VARCHAR(50),-- concatenation of all fields flags. (be default each is 1: 11111111...) -1: public, -- 2: friend, --3: private
    WAUI_TITLE VARCHAR(3),         -- 0
    WAUI_FIRST_NAME VARCHAR(50),   -- 1
    WAUI_LAST_NAME VARCHAR(50),    -- 2
    WAUI_FULL_NAME VARCHAR(100),   -- 3
    WAUI_GENDER VARCHAR(10),       -- 5
    WAUI_BIRTHDAY DATETIME,        -- 6
    WAUI_WEBPAGE VARCHAR(50),      -- 7
    WAUI_FOAF VARCHAR(50),         -- 8
    WAUI_MSIGNATURE VARCHAR(255),  -- 9
    WAUI_ICQ VARCHAR(50),          -- 10
    WAUI_SKYPE VARCHAR(50),        -- 11
    WAUI_AIM VARCHAR(50),          -- 12
    WAUI_YAHOO VARCHAR(50),        -- 13
    WAUI_MSN VARCHAR(50),          -- 14
    WAUI_HADDRESS1 VARCHAR(50),    -- 15
    WAUI_HADDRESS2 VARCHAR(50),    -- 15
    WAUI_HCODE VARCHAR(50),        -- 15
    WAUI_HCITY VARCHAR(50),        -- 16
    WAUI_HSTATE VARCHAR(50),       -- 16
    WAUI_HCOUNTRY VARCHAR(50),     -- 16
    WAUI_HTZONE VARCHAR(50),       -- 17
    WAUI_HPHONE VARCHAR(50),       -- 18
    WAUI_HMOBILE VARCHAR(50),      -- 18
    WAUI_BINDUSTRY VARCHAR(50),    -- 19
    WAUI_BORG VARCHAR(50),         -- 20
    WAUI_BJOB VARCHAR(50),         -- 21
    WAUI_BADDRESS1 VARCHAR(50),    -- 22
    WAUI_BADDRESS2 VARCHAR(50),    -- 22
    WAUI_BCODE VARCHAR(50),        -- 22
    WAUI_BCITY VARCHAR(50),        -- 23
    WAUI_BSTATE VARCHAR(50),       -- 23
    WAUI_BCOUNTRY VARCHAR(50),     -- 23
    WAUI_BTZONE VARCHAR(50),       -- 24
    WAUI_BLAT REAL,                -- 47
    WAUI_BLNG REAL,                -- 48
    WAUI_BPHONE VARCHAR(50),       -- 25
    WAUI_BMOBILE VARCHAR(50),      -- 25
    WAUI_BREGNO VARCHAR(50),       -- 26
    WAUI_BCAREER VARCHAR(50),      -- 27
    WAUI_BEMPTOTAL VARCHAR(50),    -- 28
    WAUI_BVENDOR VARCHAR(50),      -- 29
    WAUI_BSERVICE VARCHAR(50),     -- 30
    WAUI_BOTHER VARCHAR(50),       -- 31
    WAUI_BNETWORK VARCHAR(50),     -- 32
    WAUI_SUMMARY LONG VARCHAR,     -- 33
    WAUI_RESUME LONG VARCHAR,      -- 34
    WAUI_SEC_QUESTION VARCHAR(20), -- 35
    WAUI_SEC_ANSWER VARCHAR(20),   -- 36
    WAUI_PHOTO_URL LONG VARCHAR,   -- 37
    WAUI_TEMPLATE VARCHAR(20),	   -- 38
    WAUI_LAT REAL,                 -- 39
    WAUI_LNG REAL,                 -- 40
    WAUI_LATLNG_VISIBLE SMALLINT,  -- 41
    WAUI_USER_SEARCHABLE SMALLINT, -- 42 - new fields
    WAUI_AUDIO_CLIP LONG VARCHAR,  -- 43
    WAUI_FAVORITE_BOOKS  LONG VARCHAR,  -- 44
    WAUI_FAVORITE_MUSIC  LONG VARCHAR,  -- 45
    WAUI_FAVORITE_MOVIES LONG VARCHAR,  -- 46
    WAUI_SEARCHABLE	 int default 1,
    WAUI_LATLNG_HBDEF SMALLINT default 0,
    WAUI_SITE_NAME long varchar,

    primary key (WAUI_U_ID)
  )'
)
;

wa_add_col('DB.DBA.WA_USER_INFO', 'WAUI_TEMPLATE', 'VARCHAR(20)');
wa_add_col('DB.DBA.WA_USER_INFO', 'WAUI_PHOTO_URL', 'LONG VARCHAR');
wa_add_col('DB.DBA.WA_USER_INFO', 'WAUI_LAT', 'REAL');
wa_add_col('DB.DBA.WA_USER_INFO', 'WAUI_LNG', 'REAL');
wa_add_col('DB.DBA.WA_USER_INFO', 'WAUI_LATLNG_VISIBLE', 'SMALLINT');

wa_add_col ('DB.DBA.WA_USER_INFO', 'WAUI_USER_SEARCHABLE', 'SMALLINT');
wa_add_col ('DB.DBA.WA_USER_INFO', 'WAUI_AUDIO_CLIP', 'LONG VARCHAR');
wa_add_col ('DB.DBA.WA_USER_INFO', 'WAUI_FAVORITE_BOOKS', 'LONG VARCHAR');
wa_add_col ('DB.DBA.WA_USER_INFO', 'WAUI_FAVORITE_MUSIC', 'LONG VARCHAR');
wa_add_col ('DB.DBA.WA_USER_INFO', 'WAUI_FAVORITE_MOVIES', 'LONG VARCHAR');

wa_add_col ('DB.DBA.WA_USER_INFO', 'WAUI_SEARCHABLE', 'int default 1');

wa_add_col('DB.DBA.WA_USER_INFO', 'WAUI_BLAT', 'REAL');
wa_add_col('DB.DBA.WA_USER_INFO', 'WAUI_BLNG', 'REAL');
wa_add_col ('DB.DBA.WA_USER_INFO', 'WAUI_LATLNG_HBDEF', 'SMALLINT default 0');

wa_add_col ('DB.DBA.WA_USER_INFO', 'WAUI_JOIN_DATE', 'DATETIME','UPDATE DB.DBA.WA_USER_INFO SET WAUI_JOIN_DATE = now()');

wa_add_col ('DB.DBA.WA_USER_INFO', 'WAUI_SITE_NAME', 'LONG VARCHAR');

create trigger WA_USER_INFO_I after insert on WA_USER_INFO referencing new as N {

  if (N.WAUI_JOIN_DATE is null)
  {
    set triggers off;
    update WA_USER_INFO set WAUI_JOIN_DATE = now() where WAUI_U_ID = N.WAUI_U_ID;
    set triggers on;
  }

  return;
}
;

wa_exec_no_error_log ('CREATE INDEX WA_GEO ON WA_USER_INFO (WAUI_LNG, WAUI_LAT, WAUI_LATLNG_VISIBLE)');

wa_exec_no_error_log(
  'CREATE TABLE WA_USER_TEXT
  (
    WAUT_U_ID int,
    WAUT_TEXT LONG VARCHAR,
    primary key (WAUT_U_ID)
  )'
)
;


wa_exec_no_error(
  'CREATE TEXT INDEX ON WA_USER_TEXT (WAUT_TEXT) WITH KEY WAUT_U_ID'
)
;

wa_exec_no_error_log(
  'CREATE TABLE WA_USER_TAG
  (
     WAUTG_U_ID	integer not null, -- the id of the user of whose tag it is
     WAUTG_TAG_ID	integer not null, -- the id of the user who gives the tags
     WAUTG_FT_ID	integer not null,
     WAUTG_TAGS	varchar not null,
     primary key (WAUTG_U_ID, WAUTG_TAG_ID)
  )'
)
;

wa_exec_no_error(
  'create unique index SYS_WA_USER_TAG_FT_ID on WA_USER_TAG (WAUTG_FT_ID)'
)
;

wa_exec_no_error(
  'create index WA_USER_TAG_TAG_ID on WA_USER_TAG (WAUTG_TAG_ID)'
)
;

create procedure WA_USER_TAG_WAUTG_TAGS_INDEX_HOOK (inout vtb any, inout d_id integer)
{
  for select WAUTG_U_ID, WAUTG_TAG_ID, WAUTG_TAGS from WA_USER_TAG where WAUTG_FT_ID = d_id do
    {
      vt_batch_feed (vtb, WS.WS.DAV_TAG_NORMALIZE (WAUTG_TAGS), 0, 0, 'x-ViDoc');
      vt_batch_feed (vtb, sprintf ('^TID%d', WAUTG_TAG_ID), 0, 0, 'x-ViDoc');
      vt_batch_feed (vtb, sprintf ('^UID%d', WAUTG_U_ID), 0, 0, 'x-ViDoc');
      if (WAUTG_U_ID = http_nobody_uid ())
        vt_batch_feed (vtb, '^PUBLIC', 0, 0, 'x-ViDoc');
      vt_batch_feed_offband (vtb, serialize (vector (WAUTG_TAG_ID, WAUTG_U_ID)), 0);
      return 1;
    }
  return 1;
}
;

create procedure WA_USER_TAG_WAUTG_TAGS_UNINDEX_HOOK (inout vtb any, inout d_id integer)
{
  for select WAUTG_U_ID, WAUTG_TAG_ID, WAUTG_TAGS from WA_USER_TAG where WAUTG_FT_ID = d_id do
    {
      vt_batch_feed (vtb, WS.WS.DAV_TAG_NORMALIZE (WAUTG_TAGS), 1, 0, 'x-ViDoc');
      vt_batch_feed (vtb, sprintf ('^TID%d', WAUTG_TAG_ID), 1, 0, 'x-ViDoc');
      vt_batch_feed (vtb, sprintf ('^UID%d', WAUTG_U_ID), 1, 0, 'x-ViDoc');
      if (WAUTG_U_ID = http_nobody_uid ())
        vt_batch_feed (vtb, '^PUBLIC', 1, 0, 'x-ViDoc');
      vt_batch_feed_offband (vtb, serialize (vector (WAUTG_TAG_ID, WAUTG_U_ID)), 1);
      return 1;
    }
  return 1;
}
;

DB.DBA.vt_create_text_index ('WA_USER_TAG', 'WAUTG_TAGS', 'WAUTG_FT_ID', 2, 0, vector ('WAUTG_TAG_ID', 'WAUTG_U_ID'), 1, 'x-ViDoc', 'UTF-8')
;


create procedure WA_USER_SET_INFO (in _name varchar,in _fname varchar,in _lname varchar)
{
  declare _uid any;
  declare i int;
  declare _visb, _uname varchar;
  whenever not found goto nf;
  SELECT U_ID, U_NAME INTO _uid, _uname FROM SYS_USERS WHERE U_NAME = _name;

  i := 1;
  _visb := '1';
  while (i < 50)
  {
    _visb := concat(_visb,'1');
    i := i + 1 ;
  };

  INSERT REPLACING WA_USER_INFO (WAUI_U_ID,WAUI_VISIBLE,WAUI_FIRST_NAME, WAUI_LAST_NAME, WAUI_FULL_NAME )
    VALUES(_uid, _visb, _fname, _lname, _uname  );

  return;

 nf:
   signal ('42000', sprintf ('The object "%s" does not exists.', _name), 'U0002');
}
;

create procedure WA_USER_EDIT (in _name varchar,in _key varchar,in _data any)
{
  declare _uid any;
  declare i int;
  declare _visb varchar;
  whenever not found goto nf;
  SELECT U_ID INTO _uid FROM SYS_USERS WHERE U_NAME = _name;

  if (_key = 'SEC_QUESTION')
    UPDATE WA_USER_INFO SET WAUI_SEC_QUESTION = _data WHERE WAUI_U_ID = _uid;
  else if (_key = 'SEC_ANSWER')
    UPDATE WA_USER_INFO SET WAUI_SEC_ANSWER = _data WHERE WAUI_U_ID = _uid;
  else if (_key = 'WAUI_ICQ')
    UPDATE WA_USER_INFO SET WAUI_ICQ = _data WHERE WAUI_U_ID = _uid;
  else if (_key = 'WAUI_SKYPE')
    UPDATE WA_USER_INFO SET WAUI_SKYPE = _data WHERE WAUI_U_ID = _uid;
  else if (_key = 'WAUI_AIM')
    UPDATE WA_USER_INFO SET WAUI_AIM = _data WHERE WAUI_U_ID = _uid;
  else if (_key = 'WAUI_YAHOO')
    UPDATE WA_USER_INFO SET WAUI_YAHOO = _data WHERE WAUI_U_ID = _uid;
  else if (_key = 'WAUI_MSN')
    UPDATE WA_USER_INFO SET WAUI_MSN = _data WHERE WAUI_U_ID = _uid;
  else if (_key = 'WAUI_BIRTHDAY' and (__tag (_data) = 211 or _data is null))
    UPDATE WA_USER_INFO SET WAUI_BIRTHDAY = _data WHERE WAUI_U_ID = _uid;
  else if (_key = 'WAUI_TITLE')
    UPDATE WA_USER_INFO SET WAUI_TITLE = _data WHERE WAUI_U_ID = _uid;
  else if (_key = 'WAUI_FIRST_NAME')
    UPDATE WA_USER_INFO SET WAUI_FIRST_NAME = _data WHERE WAUI_U_ID = _uid;
  else if (_key = 'WAUI_LAST_NAME')
    UPDATE WA_USER_INFO SET WAUI_LAST_NAME = _data WHERE WAUI_U_ID = _uid;
  else if (_key = 'WAUI_FULL_NAME')
    {
      UPDATE WA_USER_INFO SET WAUI_FULL_NAME = _data WHERE WAUI_U_ID = _uid;
      UPDATE SYS_USERS set U_FULL_NAME = _data where U_ID = _uid;
    }
  else if (_key = 'WAUI_GENDER')
    UPDATE WA_USER_INFO SET WAUI_GENDER = _data WHERE WAUI_U_ID = _uid;
  else if (_key = 'WAUI_FOAF')
    UPDATE WA_USER_INFO SET WAUI_FOAF = _data WHERE WAUI_U_ID = _uid;
  else if (_key = 'WAUI_MSIGNATURE')
    UPDATE WA_USER_INFO SET WAUI_MSIGNATURE = _data WHERE WAUI_U_ID = _uid;
  else if (_key = 'WAUI_SUMMARY')
    UPDATE WA_USER_INFO SET WAUI_SUMMARY = _data WHERE WAUI_U_ID = _uid;
  else if (_key = 'WAUI_WEBPAGE')
    UPDATE WA_USER_INFO SET WAUI_WEBPAGE = _data WHERE WAUI_U_ID = _uid;
  else if (_key = 'E_MAIL')
    UPDATE DB.DBA.SYS_USERS SET U_E_MAIL = _data WHERE U_ID = _uid;
--home tab
  else if (_key = 'WAUI_HADDRESS1')
    UPDATE WA_USER_INFO SET WAUI_HADDRESS1 = _data WHERE WAUI_U_ID = _uid;
  else if (_key = 'WAUI_HADDRESS2')
    UPDATE WA_USER_INFO SET WAUI_HADDRESS2 = _data WHERE WAUI_U_ID = _uid;
  else if (_key = 'WAUI_HCODE')
    UPDATE WA_USER_INFO SET WAUI_HCODE = _data WHERE WAUI_U_ID = _uid;
  else if (_key = 'WAUI_HCITY')
    UPDATE WA_USER_INFO SET WAUI_HCITY = _data WHERE WAUI_U_ID = _uid;
  else if (_key = 'WAUI_HSTATE')
    UPDATE WA_USER_INFO SET WAUI_HSTATE = _data WHERE WAUI_U_ID = _uid;
  else if (_key = 'WAUI_HCOUNTRY')
    UPDATE WA_USER_INFO SET WAUI_HCOUNTRY = _data WHERE WAUI_U_ID = _uid;
  else if (_key = 'WAUI_HTZONE')
    UPDATE WA_USER_INFO SET WAUI_HTZONE = _data WHERE WAUI_U_ID = _uid;
  else if (_key = 'WAUI_HPHONE')
    UPDATE WA_USER_INFO SET WAUI_HPHONE = _data WHERE WAUI_U_ID = _uid;
  else if (_key = 'WAUI_HMOBILE')
    UPDATE WA_USER_INFO SET WAUI_HMOBILE = _data WHERE WAUI_U_ID = _uid;

  else if (_key = 'WAUI_BADDRESS1')
    UPDATE WA_USER_INFO SET WAUI_BADDRESS1 = _data WHERE WAUI_U_ID = _uid;
  else if (_key = 'WAUI_BADDRESS2')
    UPDATE WA_USER_INFO SET WAUI_BADDRESS2 = _data WHERE WAUI_U_ID = _uid;
  else if (_key = 'WAUI_BCODE')
    UPDATE WA_USER_INFO SET WAUI_BCODE = _data WHERE WAUI_U_ID = _uid;
  else if (_key = 'WAUI_BCITY')
    UPDATE WA_USER_INFO SET WAUI_BCITY = _data WHERE WAUI_U_ID = _uid;
  else if (_key = 'WAUI_BSTATE')
   UPDATE WA_USER_INFO SET WAUI_BSTATE = _data WHERE WAUI_U_ID = _uid;
  else if (_key = 'WAUI_BCOUNTRY')
    UPDATE WA_USER_INFO SET WAUI_BCOUNTRY = _data WHERE WAUI_U_ID = _uid;
  else if (_key = 'WAUI_BTZONE')
    UPDATE WA_USER_INFO SET WAUI_BTZONE = _data WHERE WAUI_U_ID = _uid;
  else if (_key = 'WAUI_BLAT')
    UPDATE WA_USER_INFO SET WAUI_BLAT = _data WHERE WAUI_U_ID = _uid;
  else if (_key = 'WAUI_BLNG')
    UPDATE WA_USER_INFO SET WAUI_BLNG = _data WHERE WAUI_U_ID = _uid;
  else if (_key = 'WAUI_BPHONE')
    UPDATE WA_USER_INFO SET WAUI_BPHONE = _data WHERE WAUI_U_ID = _uid;
  else if (_key = 'WAUI_BMOBILE')
    UPDATE WA_USER_INFO SET WAUI_BMOBILE = _data WHERE WAUI_U_ID = _uid;
  else if (_key = 'WAUI_BREGNO')
    UPDATE WA_USER_INFO SET WAUI_BREGNO = _data WHERE WAUI_U_ID = _uid;
  else if (_key = 'WAUI_BCAREER')
    UPDATE WA_USER_INFO SET WAUI_BCAREER = _data WHERE WAUI_U_ID = _uid;
  else if (_key = 'WAUI_BEMPTOTAL')
    UPDATE WA_USER_INFO SET WAUI_BEMPTOTAL = _data WHERE WAUI_U_ID = _uid;

  else if (_key = 'WAUI_BVENDOR')
    UPDATE WA_USER_INFO SET WAUI_BVENDOR = _data WHERE WAUI_U_ID = _uid;
  else if (_key = 'WAUI_BSERVICE')
    UPDATE WA_USER_INFO SET WAUI_BSERVICE = _data WHERE WAUI_U_ID = _uid;
  else if (_key = 'WAUI_BOTHER')
    UPDATE WA_USER_INFO SET WAUI_BOTHER = _data WHERE WAUI_U_ID = _uid;
  else if (_key = 'WAUI_BNETWORK')
    UPDATE WA_USER_INFO SET WAUI_BNETWORK = _data WHERE WAUI_U_ID = _uid;
  else if (_key = 'WAUI_RESUME')
    UPDATE WA_USER_INFO SET WAUI_RESUME = _data WHERE WAUI_U_ID = _uid;
  else if (_key = 'WAUI_BJOB')
    UPDATE WA_USER_INFO SET WAUI_BJOB = _data WHERE WAUI_U_ID = _uid;
  else if (_key = 'WAUI_BORG')
    UPDATE WA_USER_INFO SET WAUI_BORG = _data WHERE WAUI_U_ID = _uid;
  else if (_key = 'WAUI_BINDUSTRY')
    UPDATE WA_USER_INFO SET WAUI_BINDUSTRY = _data WHERE WAUI_U_ID = _uid;
  else if (_key = 'WAUI_PHOTO_URL')
    UPDATE WA_USER_INFO SET WAUI_PHOTO_URL = _data WHERE WAUI_U_ID = _uid;
  else if (_key = 'WAUI_LAT')
    UPDATE WA_USER_INFO SET WAUI_LAT = _data WHERE WAUI_U_ID = _uid;
  else if (_key = 'WAUI_LNG')
    UPDATE WA_USER_INFO SET WAUI_LNG = _data WHERE WAUI_U_ID = _uid;
  else if (_key = 'WAUI_LATLNG_HBDEF')
    UPDATE WA_USER_INFO SET WAUI_LATLNG_HBDEF = _data WHERE WAUI_U_ID = _uid;
  else if (_key = 'WAUI_AUDIO_CLIP')
    UPDATE WA_USER_INFO SET WAUI_AUDIO_CLIP = _data WHERE WAUI_U_ID = _uid;
  else if (_key = 'WAUI_FAVORITE_BOOKS')
    UPDATE WA_USER_INFO SET WAUI_FAVORITE_BOOKS = _data WHERE WAUI_U_ID = _uid;
  else if (_key = 'WAUI_FAVORITE_MUSIC')
    UPDATE WA_USER_INFO SET WAUI_FAVORITE_MUSIC = _data WHERE WAUI_U_ID = _uid;
  else if (_key = 'WAUI_FAVORITE_MOVIES')
    UPDATE WA_USER_INFO SET WAUI_FAVORITE_MOVIES = _data WHERE WAUI_U_ID = _uid;
  else if (_key = 'WAUI_SEARCHABLE')
    UPDATE WA_USER_INFO SET WAUI_SEARCHABLE = _data WHERE WAUI_U_ID = _uid;

  return;

 nf:
   signal ('42000', sprintf ('The object "%s" does not exists.', _name), 'U0002');
}
;


create procedure WA_USER_VISIBILITY (in _name varchar, in _arr any default null, in _mode int default 1)
{
  declare _uid any;
  declare _visb, new_vis any;
  declare i, j integer;
  whenever not found goto nf;

  --dbg_obj_print(_name);
  _visb := '';
  SELECT U_ID INTO _uid FROM SYS_USERS WHERE U_NAME = _name;

  SELECT WAUI_VISIBLE into _visb FROM WA_USER_INFO WHERE WAUI_U_ID = _uid;

  --dbg_obj_print(_uid);
  _visb := replace(_visb,'1','1,');
  _visb := replace(_visb,'2','2,');
  _visb := replace(_visb,'3','3,');
  _visb := trim(_visb, ',');
  _visb:= split_and_decode (_visb,0,'\0\0,');

  if (length (_visb) < 50)
    {
      declare part, inx any;
      part := make_array (50-length (_visb), 'any');
      for (inx := 0; inx < length (part); inx := inx + 1)
        part [inx] := '3';
      _visb := vector_concat (_visb, part);
    }

  if (_mode = 1)
    {
      return _visb;
    }

  if (length(_arr) < 2)
    return;

  i := 0;
  while (i < length(_visb))
    {
      declare val any;
      val := get_keyword (sprintf ('%d', i), _arr);
      if (val is not null)
	_visb[i] := val;
      i := i + 1;
    };

  --dbg_obj_print(_visb);

  declare _new varchar;
  j := 0;
  _new := '';
  while (j < length(_visb))
  {
    _new := concat (_new, _visb[j]);
    j := j + 1;
  };

  UPDATE WA_USER_INFO SET WAUI_VISIBLE = _new WHERE WAUI_U_ID = _uid;
  --dbg_obj_print(_visb);
  return;

 nf:
   signal ('42000', sprintf ('The object "%s" does not exists.', _name), 'U0002');
}
;

create procedure WA_REPLACE_ARR ( inout _vector any, in _pos integer,in _val varchar )
{
  declare _ind integer;

  _ind := 0;
  while(_ind < length(_vector))
    {
      if (_ind = _pos)
	aset(_vector,_ind,_val);
	_ind := _ind + 1;
    };
  return;
}
;

create procedure WA_STR_PARAM (inout pArray any,in pName varchar,in pMode integer default 0)
{
    declare i, l, incr integer;
    declare aArrayNew any;

    aArrayNew := vector();
    i := 0;
    l := length(pArray);

    incr := 2;
    if (l >= 4 and mod (l, 4) = 0)
      {
	if (pArray[2] = 'attr-'||pArray[0])
	  incr := 4;
      }

    while (i < l)
      {
	if (locate (pName, pArray[i]) > 0)
	  {
	    if (not (pMode))
	      aArrayNew := vector_concat(aArrayNew, vector_concat(vector(trim(pArray[i],pName)),vector(pArray[i+1])));
	    else
	      aArrayNew := vector_concat(aArrayNew, vector_concat(vector(trim(pArray[i+1],pName))));
	  };
        i := i + incr;
      };
  return  aArrayNew;
}
;

create procedure WA_OPTION_SUBS (in opt varchar, inout opts any, in len int := 0)
{
  declare val any;
  val := get_keyword_ucase (upper (opt), opts, NULL);
  if (isstring (val) and len)
    return substring (val, 1, len);
  return val;
};


create procedure WA_USER_SEARCH_SET_UP ()
{
  if (registry_get ('__WA_USER_SEARCH_SET_UP') = 'done')
    return;
  update WA_USER_INFO set WAUI_SEARCHABLE = 1 where WAUI_SEARCHABLE is null;
  registry_set ('__WA_USER_SEARCH_SET_UP', 'done');
};

WA_USER_SEARCH_SET_UP ();

create procedure WA_USER_INFO_CHECK ()
{
   declare _uid, _id, _sql int;
   declare _uname, _wkey varchar;
   declare _wdata, opts any;
   declare _bdate any; /* datetime */

   if (registry_get ('__WA_USER_INFO_CHECK') = 'done')
     return;

   for select U_ID, U_NAME, U_FULL_NAME from SYS_USERS where U_DAV_ENABLE = 1 and U_IS_ROLE = 0 and U_NAME <> 'nobody' do
   {
      _uid := U_ID;
      _uname := U_NAME;

      if (not exists (select 1 from WA_USER_INFO where WAUI_U_ID = _uid))
      {
	 GET_SEC_OBJECT_ID (_uname, _id, _sql, opts);

         WA_USER_SET_INFO (_uname, '', '');

	 declare dummy int;
	 declare cr cursor for select 1 from WA_USER_INFO where WAUI_U_ID = _uid;

	 open cr (exclusive, prefetch 1);
	 fetch cr into dummy;

         _bdate := WA_OPTION_SUBS ('BIRTHDAY', opts);
         if (_bdate is not null and _bdate <> 0)
           UPDATE WA_USER_INFO SET WAUI_BIRTHDAY =  _bdate WHERE current of cr;

         UPDATE WA_USER_INFO SET WAUI_TITLE =  WA_OPTION_SUBS( 'TITLE', opts, 3) WHERE current of cr;
         UPDATE WA_USER_INFO SET WAUI_FIRST_NAME =  WA_OPTION_SUBS( 'FIRST_NAME', opts, 50) WHERE current of cr;
         UPDATE WA_USER_INFO SET WAUI_LAST_NAME =  WA_OPTION_SUBS( 'LAST_NAME', opts, 50) WHERE current of cr;
         UPDATE WA_USER_INFO SET WAUI_FULL_NAME = substring (coalesce (U_FULL_NAME, _uname), 1, 50) WHERE current of cr;
         UPDATE WA_USER_INFO SET WAUI_GENDER =  WA_OPTION_SUBS( 'GENDER', opts, 10) WHERE current of cr;


         UPDATE WA_USER_INFO SET WAUI_WEBPAGE =  WA_OPTION_SUBS( 'URL', opts, 50) WHERE current of cr;
         UPDATE WA_USER_INFO SET WAUI_ICQ =  WA_OPTION_SUBS( 'ICQ', opts, 50) WHERE current of cr;
         UPDATE WA_USER_INFO SET WAUI_SKYPE =  WA_OPTION_SUBS( 'SKYPE', opts, 50) WHERE current of cr;
         UPDATE WA_USER_INFO SET WAUI_AIM =  WA_OPTION_SUBS( 'AIM', opts, 50) WHERE current of cr;
         UPDATE WA_USER_INFO SET WAUI_YAHOO =  WA_OPTION_SUBS( 'YAHOO', opts, 50) WHERE current of cr;
         UPDATE WA_USER_INFO SET WAUI_MSN =  WA_OPTION_SUBS( 'MSN', opts, 50) WHERE current of cr;
         UPDATE WA_USER_INFO SET WAUI_HADDRESS1 =  WA_OPTION_SUBS( 'ADDR1', opts, 50) WHERE current of cr;
         UPDATE WA_USER_INFO SET WAUI_HADDRESS2 =  WA_OPTION_SUBS( 'ADDR2', opts, 50) WHERE current of cr;
         UPDATE WA_USER_INFO SET WAUI_HCODE =  WA_OPTION_SUBS( 'ZIP', opts, 50) WHERE current of cr;
         UPDATE WA_USER_INFO SET WAUI_HCITY =  WA_OPTION_SUBS( 'CITY', opts, 50) WHERE current of cr;
         UPDATE WA_USER_INFO SET WAUI_HSTATE =  WA_OPTION_SUBS( 'STATE', opts, 50) WHERE current of cr;
         UPDATE WA_USER_INFO SET WAUI_HCOUNTRY =  WA_OPTION_SUBS( 'COUNTRY', opts, 50) WHERE current of cr;
         UPDATE WA_USER_INFO SET WAUI_HTZONE =  WA_OPTION_SUBS( 'TIMEZONE', opts, 50) WHERE current of cr;
         UPDATE WA_USER_INFO SET WAUI_HPHONE =  WA_OPTION_SUBS( 'PHONE', opts, 50) WHERE current of cr;
         UPDATE WA_USER_INFO SET WAUI_HMOBILE =  WA_OPTION_SUBS( 'MPHONE', opts, 50) WHERE current of cr;
         UPDATE WA_USER_INFO SET WAUI_BINDUSTRY =  WA_OPTION_SUBS( 'INDUSTRY', opts, 50) WHERE current of cr;
         UPDATE WA_USER_INFO SET WAUI_BORG =  WA_OPTION_SUBS( 'ORGANIZATION', opts, 50) WHERE current of cr;
         UPDATE WA_USER_INFO SET WAUI_BJOB =  WA_OPTION_SUBS( 'JOB', opts, 50) WHERE current of cr;
         UPDATE WA_USER_INFO SET WAUI_BADDRESS1 =  WA_OPTION_SUBS( 'BADDR1', opts, 50) WHERE current of cr;
         UPDATE WA_USER_INFO SET WAUI_BADDRESS2 =  WA_OPTION_SUBS( 'BADDR2', opts, 50) WHERE current of cr;
         UPDATE WA_USER_INFO SET WAUI_BCODE =  WA_OPTION_SUBS( 'BZIP', opts, 50) WHERE current of cr;
         UPDATE WA_USER_INFO SET WAUI_BCITY =  WA_OPTION_SUBS( 'BCITY', opts, 50) WHERE current of cr;
         UPDATE WA_USER_INFO SET WAUI_BSTATE =  WA_OPTION_SUBS( 'BSTATE', opts, 50) WHERE current of cr;
         UPDATE WA_USER_INFO SET WAUI_BCOUNTRY =  WA_OPTION_SUBS( 'BCOUNTRY', opts, 50) WHERE current of cr;
         UPDATE WA_USER_INFO SET WAUI_BTZONE =  WA_OPTION_SUBS( 'BTIMEZONE', opts, 50) WHERE current of cr;
         UPDATE WA_USER_INFO SET WAUI_BPHONE =  WA_OPTION_SUBS( 'BPHONE', opts, 50) WHERE current of cr;
         UPDATE WA_USER_INFO SET WAUI_BMOBILE =  WA_OPTION_SUBS( 'BMPHONE', opts, 50) WHERE current of cr;

         UPDATE WA_USER_INFO SET WAUI_SEC_QUESTION =  WA_OPTION_SUBS( 'SEC_QUESTION', opts, 20) WHERE current of cr;
         UPDATE WA_USER_INFO SET WAUI_SEC_ANSWER =  WA_OPTION_SUBS( 'SEC_ANSWER', opts, 20) WHERE current of cr;

         if (exists (select 1 from WA_USER_SETTINGS where WAUS_U_ID = _uid))
         {
           for (select WAUS_KEY, WAUS_DATA from WA_USER_SETTINGS) do{
              _wkey := WAUS_KEY;
              _wdata :=  deserialize(WAUS_DATA);
             if (_wkey = 'CAREER_STATUS')
                UPDATE WA_USER_INFO SET WAUI_BCAREER = substring (_wdata, 1, 50) WHERE current of cr;
             else if (_wkey = 'EXT_FOAF_URL')
                UPDATE WA_USER_INFO SET WAUI_FOAF = substring (_wdata, 1, 50) WHERE current of cr;
             else if (_wkey = 'IS_VENDOR')
                UPDATE WA_USER_INFO SET WAUI_BVENDOR = substring (_wdata, 1, 50) WHERE current of cr;
             else if (_wkey = 'MAIL-SIGNATURE')
                UPDATE WA_USER_INFO SET WAUI_MSIGNATURE = substring (_wdata, 1, 255) WHERE current of cr;
             else if (_wkey = 'NO_EMPLOYEES')
                UPDATE WA_USER_INFO SET WAUI_BEMPTOTAL = substring (_wdata, 1, 50) WHERE current of cr;
             else if (_wkey = 'OPLNET_IMPORTANCE')
                UPDATE WA_USER_INFO SET WAUI_BNETWORK = substring (_wdata, 1, 50) WHERE current of cr;
             else if (_wkey = 'OTHER_TECH_SERVICE')
                UPDATE WA_USER_INFO SET WAUI_BOTHER = substring (_wdata, 1, 50) WHERE current of cr;
             else if (_wkey = 'TECH_SERVICE')
                UPDATE WA_USER_INFO SET WAUI_BSERVICE = substring (_wdata, 1, 50) WHERE current of cr;
             else if (_wkey = 'VAT_REG_NUMBER')
                UPDATE WA_USER_INFO SET WAUI_BREGNO = substring (_wdata, 1, 50) WHERE current of cr;
           };
         };
	 close cr;
      }
   };
   registry_set ('__WA_USER_INFO_CHECK', 'done');
}
;

create procedure WA_GET_FTID ()
{
  declare id, nid integer;
  declare t_cur cursor for select WAUTG_FT_ID from WA_USER_TAG order by WAUTG_FT_ID desc;

  set isolation = 'serializable';

again:

  id := 1;
  whenever not found goto not_found;
  open t_cur (exclusive, prefetch 1);
  fetch t_cur into id;
  if (not isnull(id))
    id := id + 1;

not_found:
  if (isnull(id))
    id := 1;

whenever not found goto return_id;
  close t_cur;
  --select DT_FT_ID into nid from WS.WS.SYS_DAV_TAG where DT_FT_ID = id;
  select WAUTG_FT_ID into nid from WA_USER_TAG where WAUTG_FT_ID = id;
  goto again;

return_id:
  return id;
}
;

create procedure WA_USER_TAG_SET (in owner_uid any, in tagee_uid integer, in tags varchar)
{
  if (not exists (select 1 from DB.DBA.SYS_USERS where U_ID = owner_uid))
    signal('WA001', sprintf('%%User U_ID=%d is not found%%', owner_uid));
  declare exit handler for not found {
      insert into WA_USER_TAG (WAUTG_U_ID, WAUTG_TAG_ID, WAUTG_FT_ID, WAUTG_TAGS)
      values (owner_uid, tagee_uid, WA_GET_FTID (), tags);
      return;
  };

  declare cr cursor for select 1 from WA_USER_TAG where WAUTG_U_ID = owner_uid and WAUTG_TAG_ID = tagee_uid;
  open cr (exclusive, prefetch 1);
  declare dummy integer;
  fetch cr into dummy;
  update WA_USER_TAG set WAUTG_TAGS = tags where current of cr;
  close cr;
  return;
}
;

create procedure WA_USER_TAG_GET (in uname varchar)
{
  declare _tags varchar;
  declare _uid integer;

  return coalesce ((select WAUTG_TAGS from DB.DBA.SYS_USERS, WA_USER_TAG where
    U_NAME = uname and WAUTG_U_ID = http_nobody_uid() and WAUTG_TAG_ID = U_ID option (order)), '');
}
;

create procedure WA_USER_TAGS_GET (in owner_uid integer, in tagee integer) returns varchar
{
  return coalesce ((select WAUTG_TAGS from WA_USER_TAG where WAUTG_U_ID = owner_uid and WAUTG_TAG_ID = tagee),'');
}
;

create procedure WA_USER_TAG_GET_P (in uname varchar)
{
  declare U_TAG varchar;
  declare arr any;
  result_names (U_TAG);
  U_TAG := WA_USER_TAG_GET (uname);
  arr := split_and_decode (U_TAG, 0, '\0\0,');
  foreach (any t in arr) do
    {
      t := trim (t);
      if (length (t))
	result (t);
    }

};

create procedure WA_GET_USER_TAGS_OR_QRY (in uid int)
{
  declare tagstr, tag varchar;
  tagstr := WA_USER_TAGS_GET (http_nobody_uid (), uid);
  declare _arr any;
  _arr := split_and_decode(trim(tagstr, ','), 0, '\0\0,');
  tag := '';
  foreach (any t in _arr) do
    {
      t := trim (t, '\'" ');
      t := replace(t, ' ', '_');
      t := replace(t, '.', '_');
      if (length (tag))
	tag := tag || ' or "' || t || '"';
      else
	tag := '"' || t || '"';
    }
  if (length (tag))
    return tag;
  else
    return '"nonsenseword"';
}
;

create procedure WA_TAG_PREPARE (inout tag varchar)
{
  if (length (tag))
    {
      tag := trim(tag);
      tag := replace(tag, '  ', ' ');
      tag := replace(tag, '\r', ',');
      tag := replace(tag, '\n', ' ');
      declare _arr any;
      _arr := split_and_decode(trim(tag, ','), 0, '\0\0,');
      tag := '';
      foreach (any t in _arr) do
	{
	  t := trim (t, '\'", ');
	  t := replace(t, ' ', '_');
	  t := replace(t, '.', '_');
	  if (length (t))
	  tag := tag || ', ' || t;
	}
      tag := trim (tag, ', ');
    }
  return tag;
}
;


create procedure WA_VALIDATE_TAGS (in tag varchar)
{
  declare i integer;
  declare _arr any;

  _arr := split_and_decode(trim(tag, ','), 0, '\0\0,');
  for (i := 0; i < length(_arr); i := i + 1)
    if (not WA_VALIDATE_TAG(_arr[i]))
      return 0;
  return 1;
}
;

create procedure WA_VALIDATE_TAG ( in tag varchar)
{
  tag := trim (tag, '\'" ');
  tag := replace(tag, ' ', '_');
  --dbg_printf ('validating tag: [%s]', tag);
  if (not WA_VALIDATE_FTEXT(tag))
    return 0;
  if (not isnull(strstr(tag, '"')))
    return 0;
  if (not isnull(strstr(tag, '''')))
    return 0;
  if (length(tag) < 2)
    return 0;
  if (length(tag) > 50)
    return 0;
  return 1;
}
;

create procedure WA_VALIDATE_FTEXT ( in tag varchar)
{
  declare st, msg varchar;

  st := '00000';
  exec ('vt_parse (?)', st, msg, vector (tag));
  if ('00000' = st)
    return 1;
  return 0;
}
;

create procedure WA_USER_IS_TAGGED (in uid integer, in tagee integer)
{
  declare tags varchar;

  tags := WA_USER_TAGS_GET (uid, tagee);
  if (tags <> '')
    return 1;

  return 0;

}
;

create procedure WA_GET_USER_INFO (in uid integer, in ufid integer, in visb any, in own integer, in umode integer default 0)
{
  declare _utitle, _fname, _lname, _fullname, _gender,_wpage,_efoaf, _email varchar;
  declare _bdate, is_search any;
  declare _msign, _sum long varchar;
  declare _haddress1, _haddress2, _hcode, _hcity, _hstate, _hcountry, _htzone, _hphone, _hmobile varchar;
  declare _uicq, _uskype, _uaim, _uyahoo, _umsn varchar;
  declare _bindustr, _borg, _bjob, _baddress1, _baddress2, _bcode, _bcity, _bstate, _bcountry, _btzone,
          _bphone, _bmobile, _bregno, _bcareer, _bempltotal, _bvendor, _bservice, _bother, _bnetwork varchar;
  declare _bresume, _audio, _fav_books, _fav_music, _fav_movie long varchar;
  declare _WAUI_PHOTO_URL varchar;
  declare _WAUI_LAT, _WAUI_LNG, _WAUI_BLAT, _WAUI_BLNG real;
  declare _WAUI_LATLNG_HBDEF integer;
  declare _arr15, _arr16, _arr18, _arr22, _arr23, _arr25, _arr any;


  _arr15 := make_array(3, 'any');
  _arr16 := make_array(3, 'any');
  _arr18 := make_array(2, 'any');
  _arr22 := make_array(3, 'any');
  _arr23 := make_array(3, 'any');
  _arr25 := make_array(2, 'any');
  _arr := make_array(50, 'any');

  declare i integer;
  for (i := 0; i < length(_arr); i := i + 1)
  {
    aset(_arr, i, '');
  };

  SELECT WAUI_TITLE, WAUI_FIRST_NAME, WAUI_LAST_NAME,WAUI_FULL_NAME, WAUI_GENDER, WAUI_BIRTHDAY,WAUI_WEBPAGE, WAUI_FOAF, WAUI_MSIGNATURE, WAUI_SUMMARY,
         WAUI_ICQ, WAUI_SKYPE, WAUI_AIM, WAUI_YAHOO, WAUI_MSN,
         WAUI_HADDRESS1, WAUI_HADDRESS2, WAUI_HCODE, WAUI_HCITY, WAUI_HSTATE,WAUI_HCOUNTRY, WAUI_HTZONE, WAUI_HPHONE, WAUI_HMOBILE,
         WAUI_BINDUSTRY, WAUI_BORG, WAUI_BJOB, WAUI_BADDRESS1, WAUI_BADDRESS2, WAUI_BCODE, WAUI_BCITY,
         WAUI_BSTATE, WAUI_BCOUNTRY, WAUI_BTZONE, WAUI_BPHONE, WAUI_BMOBILE, WAUI_BREGNO,
         WAUI_BCAREER, WAUI_BEMPTOTAL, WAUI_BVENDOR, WAUI_BSERVICE, WAUI_BOTHER, WAUI_BNETWORK, WAUI_RESUME,
         U_E_MAIL, WAUI_PHOTO_URL, WAUI_LAT, WAUI_LNG, WAUI_BLAT, WAUI_BLNG, WAUI_LATLNG_HBDEF,
	 WAUI_AUDIO_CLIP, WAUI_FAVORITE_BOOKS, WAUI_FAVORITE_MUSIC, WAUI_FAVORITE_MOVIES,
	 WAUI_SEARCHABLE
    INTO _utitle, _fname, _lname, _fullname, _gender, _bdate, _wpage, _efoaf, _msign, _sum,
         _uicq, _uskype, _uaim, _uyahoo, _umsn,
         _haddress1, _haddress2, _hcode, _hcity, _hstate, _hcountry, _htzone, _hphone, _hmobile,
         _bindustr, _borg, _bjob, _baddress1, _baddress2, _bcode, _bcity, _bstate, _bcountry, _btzone,
         _bphone, _bmobile, _bregno, _bcareer, _bempltotal, _bvendor, _bservice, _bother, _bnetwork, _bresume,
         _email, _WAUI_PHOTO_URL, _WAUI_LAT, _WAUI_LNG, _WAUI_BLAT, _WAUI_BLNG, _WAUI_LATLNG_HBDEF,
         _audio, _fav_books, _fav_music, _fav_movie,
	 is_search
    FROM WA_USER_INFO, DB.DBA.SYS_USERS  where WAUI_U_ID = U_ID  and  U_ID = ufid;

  declare is_friend integer;
  is_friend := 0;
  if (umode = 0) is_friend := WA_USER_IS_FRIEND (uid, ufid);

  declare _data long varchar;
  _data := '';

  if (not own)
  {
    -- personal
    if (atoi(visb[0]) = 3 or (atoi(visb[0]) = 2 and not(is_friend)))  _utitle := ''; -- or is not friend
      else if (atoi(visb[0]) = 1 and umode = 1) _data := concat(_data, ' ', _utitle);

    if (atoi(visb[1]) = 3 or (atoi(visb[1]) = 2 and not(is_friend)))  _fname := '';
      else if (atoi(visb[1]) = 1 and umode = 1) _data := concat(_data, ' ', _fname);

    if (atoi(visb[2]) = 3 or (atoi(visb[2]) = 2 and not(is_friend)))  _lname := '';
      else if (atoi(visb[2]) = 1 and umode = 1) _data := concat(_data, ' ', _lname);

    if (atoi(visb[3]) = 3 or (atoi(visb[3]) = 2 and not(is_friend)))  _fullname := '';
      else if (atoi(visb[3]) = 1 and umode = 1) _data := concat(_data, ' ', _fullname);

    if (atoi(visb[4]) = 3 or (atoi(visb[4]) = 2 and not(is_friend)))  _email := '';
      else if (atoi(visb[4]) = 1 and umode = 1) _data := concat(_data, ' ', _email);

    if (atoi(visb[5]) = 3 or (atoi(visb[5]) = 2 and not(is_friend)))  _gender := '';
      else if (atoi(visb[5]) = 1 and umode = 1) _data := concat(_data, ' ', _gender);

    if (atoi(visb[6]) = 3 or (atoi(visb[6]) = 2 and not(is_friend)))  _bdate := '';
      else if (atoi(visb[6]) = 1 and umode = 1) _data := concat(_data, ' ',  WA_DATE_GET(_bdate));

    if (atoi(visb[7]) = 3 or (atoi(visb[7]) = 2 and not(is_friend)))  _wpage := '';
      else if (atoi(visb[7]) = 1 and umode = 1) _data := concat(_data, ' ', _wpage);

    if (atoi(visb[8]) = 3 or (atoi(visb[8]) = 2 and not(is_friend)))  _efoaf := '';
      else if (atoi(visb[8]) = 1 and umode = 1) _data := concat(_data, ' ', _utitle);

    if (atoi(visb[9]) = 3 or (atoi(visb[9]) = 2 and not(is_friend)))  _msign := '';
      else if (atoi(visb[9]) = 1 and umode = 1) _data := concat(_data, ' ', _msign);

    -- contact
    if (atoi(visb[10]) = 3 or (atoi(visb[10]) = 2 and not(is_friend)))  _uicq := '';
      else if (atoi(visb[10]) = 1 and umode = 1) _data := concat(_data, ' ', _uicq);

    if (atoi(visb[11]) = 3 or (atoi(visb[11]) = 2 and not(is_friend)))  _uskype := '';
      else if (atoi(visb[11]) = 1 and umode = 1) _data := concat(_data, ' ', _uskype);

    if (atoi(visb[12]) = 3 or (atoi(visb[12]) = 2 and not(is_friend)))  _uaim := '';
      else if (atoi(visb[12]) = 1 and umode = 1) _data := concat(_data, ' ', _uaim);

    if (atoi(visb[13]) = 3 or (atoi(visb[13]) = 2 and not(is_friend)))  _uyahoo := '';
      else if (atoi(visb[13]) = 1 and umode = 1) _data := concat(_data, ' ', _uyahoo);

    if (atoi(visb[14]) = 3 or (atoi(visb[14]) = 2 and not(is_friend)))  _umsn := '';
      else if (atoi(visb[14]) = 1 and umode = 1) _data := concat(_data, ' ', _umsn);

    -- home
    if (atoi(visb[15]) = 3 or (atoi(visb[15]) = 2 and not(is_friend)))
    {
      _haddress1 := '';
      _haddress2 := '';
      _hcode := '';
    }else if (atoi(visb[15]) = 1 and umode = 1){
      _data := concat(_data, ' ',  _haddress1, ' ',  _haddress2, ' ',  _hcode);
    };

    if (atoi(visb[16]) = 3 or (atoi(visb[16]) = 2 and not(is_friend)))
    {
      _hcity := '';
      _hstate := '';
      _hcountry := '';
    }else if (atoi(visb[16]) = 1 and umode = 1){
      _data := concat(_data, ' ',  _hcity, ' ', _hstate, ' ',  _hcountry);
    };

    if (atoi(visb[17]) = 3 or (atoi(visb[17]) = 2 and not(is_friend)))  _htzone := '';
      else if (atoi(visb[17]) = 1 and umode = 1) _data := concat(_data, ' ', _htzone);

    if (atoi(visb[18]) = 3 or (atoi(visb[18]) = 2 and not(is_friend)))
    {
      _hphone := '';
      _hmobile := '';
    }else if (atoi(visb[18]) = 1 and umode = 1){
      _data := concat(_data, ' ',  _hphone, ' ', _hmobile);
    };

    -- business
    if (atoi(visb[19]) = 3 or (atoi(visb[19]) = 2 and not(is_friend)))  _bindustr := '';
      else if (atoi(visb[19]) = 1 and umode = 1) _data := concat(_data, ' ', _bindustr);

    if (atoi(visb[20]) = 3 or (atoi(visb[20]) = 2 and not(is_friend)))  _borg := '';
      else if (atoi(visb[20]) = 1 and umode = 1) _data := concat(_data, ' ', _borg);

    if (atoi(visb[21]) = 3 or (atoi(visb[21]) = 2 and not(is_friend)))  _bjob := '';
      else if (atoi(visb[21]) = 1 and umode = 1) _data := concat(_data, ' ',_bjob);

    if (atoi(visb[22]) = 3 or (atoi(visb[22]) = 2 and not(is_friend)))
    {
      _baddress1 := '';
      _baddress2 := '';
      _bcode := '';
    }else if (atoi(visb[22]) = 1 and umode = 1){
      _data := concat(_data, ' ',  _baddress1, ' ',  _baddress2, ' ',  _bcode);
    };

    if (atoi(visb[23]) = 3 or (atoi(visb[23]) = 2 and not(is_friend)))
    {
      _bcity := '';
      _bstate := '';
      _bcountry := '';
    }else if (atoi(visb[23]) = 1 and umode = 1){
      _data := concat(_data, ' ',  _bcity, ' ', _bstate, ' ',  _bcountry);
    };

    if (atoi(visb[24]) = 3 or (atoi(visb[24]) = 2 and not(is_friend)))  _btzone := '';
      else if (atoi(visb[24]) = 1 and umode = 1) _data := concat(_data, ' ', _btzone);

    if (atoi(visb[25]) = 3 or (atoi(visb[25]) = 2 and not(is_friend)))
    {
      _bphone := '';
      _bmobile := '';
    }else if (atoi(visb[25]) = 1 and umode = 1){
      _data := concat(_data, ' ',  _bphone, ' ', _bmobile);
    };

    if (atoi(visb[26]) = 3 or (atoi(visb[26]) = 2 and not(is_friend)))  _bregno := '';
      else if (atoi(visb[26]) = 1 and umode = 1) _data := concat(_data, ' ', _bregno);

    if (atoi(visb[27]) = 3 or (atoi(visb[27]) = 2 and not(is_friend)))  _bcareer := '';
      else if (atoi(visb[27]) = 1 and umode = 1) _data := concat(_data, ' ', _bcareer);

    if (atoi(visb[28]) = 3 or (atoi(visb[28]) = 2 and not(is_friend)))  _bempltotal := '';
      else if (atoi(visb[28]) = 1 and umode = 1) _data := concat(_data, ' ', _bempltotal);

    if (atoi(visb[29]) = 3 or (atoi(visb[29]) = 2 and not(is_friend)))  _bvendor := '';
      else if (atoi(visb[29]) = 1 and umode = 1) _data := concat(_data, ' ', _bvendor);

    if (atoi(visb[30]) = 3 or (atoi(visb[30]) = 2 and not(is_friend)))  _bservice := '';
      else if (atoi(visb[30]) = 1 and umode = 1) _data := concat(_data, ' ', _bservice);

    if (atoi(visb[31]) = 3 or (atoi(visb[31]) = 2 and not(is_friend)))  _bother := '';
      else if (atoi(visb[31]) = 1 and umode = 1) _data := concat(_data, ' ', _bother);

    if (atoi(visb[32]) = 3 or (atoi(visb[32]) = 2 and not(is_friend)))  _bnetwork := '';
      else if (atoi(visb[32]) = 1 and umode = 1) _data := concat(_data, ' ', _bnetwork);

    _sum := blob_to_string (_sum);
    if (atoi(visb[33]) = 3 or (atoi(visb[33]) = 2 and not(is_friend)))  _sum := '';
      else if (atoi(visb[33]) = 1 and umode = 1) _data := concat(_data, ' ', _sum);

    _bresume := blob_to_string (_bresume);
    if (atoi(visb[34]) = 3 or (atoi(visb[34]) = 2 and not(is_friend)))  _bresume := '';
      else if (atoi(visb[34]) = 1 and umode = 1) _data := concat(_data, ' ', _bresume);

    if (atoi(visb[37]) = 3 or (atoi(visb[37]) = 2 and not(is_friend)))  _WAUI_PHOTO_URL := '';
      else if (atoi(visb[37]) = 1 and umode = 1) _data := concat(_data, ' ', _WAUI_PHOTO_URL);

    if (atoi(visb[43]) = 3 or (atoi(visb[43]) = 2 and not(is_friend)))
      _audio := '';
    else if (atoi(visb[43]) = 1 and umode = 1)
      _data := concat(_data, ' ', blob_to_string (_audio));

    if (atoi(visb[44]) = 3 or (atoi(visb[44]) = 2 and not(is_friend)))
      {
        _fav_books := '';
        _fav_music := '';
        _fav_movie := '';
      }
    else if (atoi(visb[43]) = 1 and umode = 1)
      {
	_data := concat(_data, ' ', blob_to_string (_fav_books), ' ',
	  blob_to_string (_fav_music), ' ', blob_to_string (_fav_movie));
      }


    if (_WAUI_LATLNG_HBDEF=0)
    {
    if (atoi(visb[39]) = 3 or (atoi(visb[39]) = 2 and not(is_friend)))
      {
	  _WAUI_LAT := null;
	  _WAUI_LNG := null;
      }
    else if (atoi(visb[39]) = 1 and umode = 1)
      {
	  _data := concat(_data, ' ', cast (_WAUI_LAT as varchar));
	  _data := concat(_data, ' ', cast (_WAUI_LNG as varchar));
       };
       
    }else if(_WAUI_LATLNG_HBDEF=1)
    {  
       if (atoi(visb[47]) = 3 or (atoi(visb[47]) = 2 and not(is_friend)))
       {
         _WAUI_BLAT := null;
         _WAUI_BLNG := null;
       }
       else if (atoi(visb[47]) = 1 and umode = 1)
       {
         _data := concat(_data, ' ', cast (_WAUI_BLAT as varchar));
         _data := concat(_data, ' ', cast (_WAUI_BLNG as varchar));
      }
       
    };





  };

  aset(_arr15, 0, wa_utf8_to_wide (_haddress1));
  aset(_arr15, 1, wa_utf8_to_wide (_haddress2));
  aset(_arr15, 2, _hcode);
  aset(_arr16, 0, wa_utf8_to_wide (_hcity));
  aset(_arr16, 1, wa_utf8_to_wide (_hstate));
  aset(_arr16, 2, _hcountry);
  aset(_arr18, 0, _hphone);
  aset(_arr18, 1, _hmobile);
  aset(_arr22, 0, wa_utf8_to_wide (_baddress1));
  aset(_arr22, 1, wa_utf8_to_wide (_baddress2));
  aset(_arr22, 2, _bcode);
  aset(_arr23, 0, wa_utf8_to_wide (_bcity));
  aset(_arr23, 1, wa_utf8_to_wide (_bstate));
  aset(_arr23, 2, _bcountry);
  aset(_arr25, 0, _bphone);
  aset(_arr25, 1, _bmobile);


  aset(_arr,0, _utitle);
  aset(_arr,1, wa_utf8_to_wide (_fname));
  aset(_arr,2, wa_utf8_to_wide (_lname));
  aset(_arr,3, wa_utf8_to_wide (_fullname));
  aset(_arr,4, _email);
  aset(_arr,5, _gender);
  aset(_arr,6, WA_DATE_GET(_bdate));
  aset(_arr,7, _wpage);
  aset(_arr,8, _efoaf);
  aset(_arr,9, wa_utf8_to_wide (_msign));
  aset(_arr,10, _uicq);
  aset(_arr,11, _uskype);
  aset(_arr,12, _uaim);
  aset(_arr,13, _uyahoo);
  aset(_arr,14, _umsn);
  aset(_arr,15, _arr15);
  aset(_arr,16, _arr16);
  aset(_arr,17, _htzone);
  aset(_arr,18, _arr18);
  aset(_arr,19, _bindustr);
  aset(_arr,20, wa_utf8_to_wide (_borg));
  aset(_arr,21, wa_utf8_to_wide (_bjob));
  aset(_arr,22, _arr22);
  aset(_arr,23, _arr23);
  aset(_arr,24, _btzone);
  aset(_arr,25, _arr25);
  aset(_arr,26, _bregno);
  aset(_arr,27, _bcareer);
  aset(_arr,28, _bempltotal );
  aset(_arr,29, _bvendor);
  aset(_arr,30, _bservice);
  aset(_arr,31, _bother);
  aset(_arr,32, _bnetwork);
  aset(_arr,33, wa_utf8_to_wide (_sum));
  aset(_arr,34, wa_utf8_to_wide (_bresume));
  _arr [37] := _WAUI_PHOTO_URL;
  _arr [39] := _WAUI_LAT;
  _arr [40] := _WAUI_LNG;

  _arr [43] := _audio;
  _arr [44] := _fav_books;
  _arr [45] := _fav_music;
  _arr [46] := _fav_movie;

  if (is_search is not null and is_search = 0)
    _data := '';

  if (umode = 1)
    return trim(_data, ' ');
  else
    return _arr;

}
;


create procedure WA_DATE_GET (in udate datetime)
{
  declare d, m, y integer;
  if (udate is null or isinteger (udate) or isstring (udate))
     return '';
  d := dayofmonth(udate);
  m := month(udate);
  y := year(udate);
  return sprintf('%d-%d-%d',m,d,y);
}
;

WA_USER_INFO_CHECK ();

create procedure WA_USER_IS_FRIEND (in uid integer, in ufid integer)
{
  declare _sne_id, _sne_fid integer;

  _sne_id := coalesce((select sne_id from sn_entity where sne_org_id = uid),0);
  if (_sne_id = 0)
    return 0;

  _sne_fid := coalesce((select sne_id from sn_entity where sne_org_id = ufid),0);
  if (_sne_fid = 0)
    return 0;

  if (exists (select 1 from sn_related, sn_entity where snr_from = _sne_id and snr_to = _sne_fid))
    return 1;
  if (exists (select 1 from sn_related, sn_entity where snr_to = _sne_id and snr_from = _sne_fid))
    return 1;

  return 0;
}
;

create procedure WA_OPTION_IS_PUBLIC (in ufname varchar, in num integer)
{
  declare visb any;
  declare i integer;

  visb := WA_USER_VISIBILITY(ufname);
  if (not(isarray(visb))) return 0;
  for (i := 0; i < length(visb); i := i + 1)
  {
    if (i = num)
    {
      if (atoi(visb[i]) = 1)
        return 1;
      else
        return 0;
    };
  };
  return 0;
}
;

create procedure WA_USER_TEXT_SET (in uid integer, in udata any)
{
  if (uid = 0)
    return;

  if (not exists (select 1 from DB.DBA.SYS_USERS where U_ID = uid))
    signal('WA001', sprintf('%%User U_ID=%d is not found%%', uid));

  if (exists (select 1 from WA_USER_TEXT where WAUT_U_ID = uid))
    {
      update WA_USER_TEXT set WAUT_TEXT = udata where WAUT_U_ID = uid;
    }
  else
    {
      insert into WA_USER_TEXT (WAUT_U_ID, WAUT_TEXT) values (uid, udata);
    }

  return;
}
;

select
	WA_USER_TEXT_SET (
		U_ID,
		WA_GET_USER_INFO(
			0,
			u_id,
			WA_USER_VISIBILITY(u_name),
			0,
			1
		)
	)
  from
    DB.DBA.SYS_USERS
  where
    U_ID not in (select WAUT_U_ID from WA_USER_TEXT)
    and exists (select 1 from WA_USER_INFO where WAUI_U_ID = U_ID)
;

-- zdravko
create procedure wa_app_menu_fill_names (in asid varchar, in arealm varchar, in user_id integer, in app_type varchar, in fname varchar default null)
{
  declare item_name, url, ret varchar;
  declare i, user_fid integer;

  i := 0;
  --dbg_obj_print ('self =', realm);
  --dbg_obj_print ('self.user_id =', user_id);

  user_fid := coalesce((select U_ID from SYS_USERS where U_NAME = fname),null);
  --dbg_obj_print ('--------------------------');
  --dbg_obj_print (fname);
  --dbg_obj_print (app_type);
  --dbg_obj_print ('user_fid =', user_fid);
  --dbg_obj_print ('user_id =', user_id);

  ret := '[';
  if (user_id is not null and user_fid is not null) -- user_id views user_fid app instance menu
  {

   --dbg_obj_print ('--case1');
   for (select WAM_INST as winst, WAM_HOME_PAGE as wpage
          from WA_MEMBER
         where WAM_IS_PUBLIC = 1
           and WAM_APP_TYPE = app_type
           and WAM_USER = user_fid
           and WAM_MEMBER_TYPE = 1
        union all
        select WAM_INST as winst, WAM_HOME_PAGE as wpage
          from WA_MEMBER
          where WAM_USER = user_id
            and WAM_STATUS = 2
            and WAM_APP_TYPE = app_type
            and WAM_MEMBERS_VISIBLE = 1
            and WAM_INST NOT IN ( select WAM_INST, WAM_HOME_PAGE
                                    from WA_MEMBER
                                   where WAM_IS_PUBLIC = 1
                                     and WAM_APP_TYPE = app_type
                                     and WAM_USER = user_fid
                                     and WAM_MEMBER_TYPE = 1)
       order by winst
    )do
    {
      i := 1;
      --dbg_obj_print(winst);
      --dbg_obj_print(wpage);
      ret := ret || '"' || winst || '", "' || wa_inst_url (wpage, asid, arealm, app_type) || '",';
    };
   if (not(i))
    ret := ret || '"' || 'No Instances' || '", "' || '' || '",';
  }
  else if (user_id is not null and isnull(user_fid)) -- user_id views its own app instance menu
  {
    --dbg_obj_print ('--case2');
    for (select WAM_INST, WAM_HOME_PAGE from WA_MEMBER where WAM_USER = user_id and WAM_APP_TYPE = app_type order by WAM_INST) do
    {
      i := 1;
      ret := ret || '"' || WAM_INST || '", "' || wa_inst_url (WAM_HOME_PAGE, asid, arealm, app_type) || '",';
    };
    ret := ret || ' "Create New", "' || wa_get_new_url (app_type, asid, arealm) || '",';
  }
  else if (isnull(user_id) and user_fid is not null) -- nobody views user_fid app instance menu
  {
    --dbg_obj_print ('--case3');
    for (select WAM_INST, WAM_HOME_PAGE from WA_MEMBER where WAM_IS_PUBLIC = 1 and WAM_APP_TYPE = app_type and WAM_USER = user_fid order by WAM_INST) do
    {
     --dbg_obj_print (ret);
      i := 1;
      ret := ret || '"' || WAM_INST || '", "' || wa_inst_url (WAM_HOME_PAGE, '', '', app_type) || '",';
    };
   if (not(i))
    ret := ret || '"' || 'No Instances' || '", "' || '' || '",';
  }
  else
  {
    --dbg_obj_print ('--case4');
    -- XXX: when no user nor login just say New, list otherwise can be exaustive
    ret := ret || ' "Create New", "' || wa_get_new_url (app_type, asid, arealm) || '",';
    --for (select distinct WAM_INST, WAM_HOME_PAGE from WA_MEMBER where WAM_IS_PUBLIC = 1 and WAM_APP_TYPE = app_type order by WAM_INST) do
    --{
    --  i := 1;
    --  ret := ret || '"' || WAM_INST || '", "' || wa_inst_url (WAM_HOME_PAGE, '', '', app_type) || '",';
    --};
  };

  --if (not(i))
  --  ret := ret || '"' || 'No Instances' || '", "' || '' || '",';
  if ("RIGHT" (ret, 1) = ',')
    aset (ret, length (ret) -1, ascii (']'));
  else
    ret := ret || ']';
 -- dbg_obj_print ('- - - - - - - - -');
 -- dbg_obj_print (ret);
 -- dbg_obj_print ('- - - - - - - - -');


  http (ret);
  return;
}
;

create procedure WA_APP_INSTANCES (in user_id integer, in app_type varchar default '%', in fname varchar default null)
{
  declare item_name, url, ret varchar;
  declare i, user_fid integer;
  declare INST_NAME, INST_URL, INST_TYPE varchar;

  i := 0;

  if (app_type is null)
   app_type := '%';

  user_fid := coalesce((select U_ID from SYS_USERS where U_NAME = fname), user_id);

  result_names (INST_NAME, INST_URL, INST_TYPE);

  if (user_id is not null and user_id <> user_fid) -- user_id views user_fid app instance menu
  {

   --dbg_obj_print ('--case1');
   for select WAM_INST as winst, WAM_HOME_PAGE as wpage, WAM_APP_TYPE
          from WA_MEMBER
         where WAM_IS_PUBLIC = 1
           and WAM_APP_TYPE like app_type
           and WAM_USER = user_fid
           and WAM_MEMBER_TYPE = 1
        union all
        select WAM_INST as winst, WAM_HOME_PAGE as wpage, WAM_APP_TYPE as wpage
          from WA_MEMBER
          where WAM_USER = user_id
            and WAM_STATUS = 2
            and WAM_APP_TYPE like app_type
            and WAM_MEMBERS_VISIBLE = 1
            and WAM_INST NOT IN ( select WAM_INST, WAM_HOME_PAGE
                                    from WA_MEMBER
                                   where WAM_IS_PUBLIC = 1
                                     and WAM_APP_TYPE like app_type
                                     and WAM_USER = user_fid
                                     and WAM_MEMBER_TYPE = 1)
       order by winst
      do
    {
      result (winst, wpage, WAM_APP_TYPE);
    }
  }
  else if (user_id is not null and user_fid = user_id) -- user_id views its own app instance menu
  {
    for select WAM_INST, WAM_HOME_PAGE, WAM_APP_TYPE from WA_MEMBER where WAM_USER = user_id and WAM_APP_TYPE like app_type order by WAM_INST do
    {
      result (WAM_INST, WAM_HOME_PAGE, WAM_APP_TYPE);
    }
  }
  else if (user_id is null and user_fid is not null) -- nobody views user_fid app instance menu
  {
    for select WAM_INST, WAM_HOME_PAGE, WAM_APP_TYPE from WA_MEMBER where WAM_IS_PUBLIC = 1 and WAM_APP_TYPE like app_type and WAM_USER = user_fid order by WAM_INST do
    {
      result (WAM_INST, WAM_HOME_PAGE, WAM_APP_TYPE);
    };
  }

};

wa_exec_no_error_log ('drop view WA_USER_APP_INSTANCES');
wa_exec_no_error_log ('create procedure view WA_USER_APP_INSTANCES as
   WA_APP_INSTANCES (user_id, app_type, fname) (INST_NAME varchar, INST_URL varchar, INST_TYPE varchar)');

create procedure wa_set_url_t (in wai_inst any)
{
	declare url varchar;
	declare s web_app;
        declare h any;
        s := wai_inst;
        h := udt_implements_method (s, fix_identifier_case ('wa_home_url'));
	url := null;
	if (h)
          url := call (h) (s);
--	dbg_obj_print ('wa_set_url_t URL = ', url);
--	update WA_MEMBER set WAM_HOME_PAGE = url where WAM_INST = WAI_NAME;
	return url;
}
;


create procedure wa_set_url ()
{
  for (select WAI_ID, WAI_NAME, WAI_INST from WA_INSTANCE) do
     {
	declare url varchar;
        declare h any;
	declare s web_app;
        s := WAI_INST;

	if (s.wa_name <> WAI_NAME)
	  {
	    log_message (sprintf ('The application instance "%s" have different name in the type represantation, it should be deleted.', WAI_NAME));
	  }
	else
	  {
	    h := udt_implements_method (s, fix_identifier_case ('wa_home_url'));
	    url := null;
	    if (h)
	      url := call (h) (s);
	    --dbg_obj_print (WAI_NAME, url);
	    update WA_MEMBER set WAM_HOME_PAGE = url where WAM_INST = WAI_NAME;
	 }

     }
}
;

create procedure wa_wa_member_upgrade ()
{

   declare _id, _mt, _ip integer;
   declare _inst varchar;

   if (registry_get ('__wa_wa_member_upgrade') = 'done')
     return;

   set triggers off;

   for select WAI_NAME, WAI_IS_PUBLIC, WAI_MEMBERS_VISIBLE, WAI_TYPE_NAME, WAI_INST from WA_INSTANCE do
     {
       declare exit handler for sqlstate '*'
	 {
	   log_message (sprintf ('WA upgrade found a broken instance: [%s], must be deleted.', WAI_NAME));
	   goto nextu;
	 };
       update DB.DBA.WA_MEMBER set WAM_IS_PUBLIC = WAI_IS_PUBLIC,
	      WAM_MEMBERS_VISIBLE = WAI_MEMBERS_VISIBLE,
	      WAM_HOME_PAGE = wa_set_url_t (WAI_INST),
	      WAM_APP_TYPE = WAI_TYPE_NAME
		  where WAM_INST = WAI_NAME;
       nextu:;
     }

   set triggers on;

   registry_set ('__wa_wa_member_upgrade', 'done');
   return;

}
;



create procedure wa_get_new_url (in app_type varchar, in asid varchar, in arealm varchar)
{
  if (isnull(asid) or isnull(arealm) or asid = '' or arealm = '')
    return sprintf ('window.open(''index_inst.vspx?wa_name=%s'', ''_self'');', app_type);
  else
   return sprintf ('window.open(''new_inst.vspx?wa_name=%s&sid=%s&realm=%s'', ''_self'');', app_type, asid, arealm);
}
;


create procedure wa_inst_url (in app_base_url varchar, in sid varchar, in realm varchar, in app varchar)
{
  declare ret varchar;
  ret :=  sprintf ('window.open(''%s?sid=%s&realm=%s'', ''_self'');', app_base_url, sid, realm);
  return ret;
}
;


create procedure wa_set_type ()
{
   declare _id, _mt, _ip integer;
   declare _inst, _atype varchar;
   for (select WAM_INST as winst, WAM_USER as wid, WAM_MEMBER_TYPE as wtype
          from WA_INSTANCE, WA_MEMBER
         where WAI_NAME = WAM_INST and (isnull(WAM_APP_TYPE) or WAM_APP_TYPE = '')) do
   {
     _inst := winst;
     _atype := wa_get_type_from_name(_inst);
     _id := wid;
     _mt := wtype;
     update DB.DBA.WA_MEMBER
       set WAM_APP_TYPE = _atype
     where WAM_USER = _id
       and WAM_INST = _inst
       and WAM_MEMBER_TYPE = _mt;
   };

}
;


create procedure wa_get_type_from_name (in _name varchar)
{
  declare _wtype varchar;

  _wtype := '';
  for (select WAI_TYPE_NAME as wtype from WA_INSTANCE where WAI_NAME = _name) do
  {
    _wtype := wtype;
    return _wtype;
  };
  return '';


  if (strstr (_name, 'Wiki') is not NULL) return 1;
  else if (strstr (_name, 'eNews2')) return 2;
  else if (strstr (_name, 'oDrive')) return 3;
  else if (strstr (_name, 'oMail')) return 5;
  else if (strstr (_name, 'Blog') is not NULL) return 7;

  --else if (strstr (_name, 'oGallery')) return 4;

  return 0;
}
;

wa_wa_member_upgrade ();

create procedure wa_keywords_sift (inout pKW any, in pSiftList any,in pPrefix any,in pOut integer := 0)
{
  declare i,j integer;
  declare sKWName varchar;
  declare R any;
  --
  if (isstring(pSiftList)) pSiftList := vector(pSiftList);
  --
  R := vector();
  i := 0;
  while (i < (length(pKW))) {
    if (pPrefix = '' or locate(pPrefix,pKW[i]) = 1) sKWName := pKW[i]; else sKWName := concat(pPrefix,pKW[i]);
    -- Search current keyword in the sift list
    j := 0;
    while (j >= 0 and j < length(pSiftList)) if (sKWName like concat(pPrefix,pSiftList[j])) j := - 1; else j := j + 1;
    if (j = -1) {
      -- Keyword found. Put it into result if pOut is zero
      if (pOut = 0) R := vector_concat(R,vector(pKW[i],pKW[i + 1]));
    }
    else {
      -- Keyword is not found. Put it into result if pOut is not zero
      if (pOut <> 0) R := vector_concat(R,vector(pKW[i],pKW[i + 1]));
    }
    i := i + 2;
  }
  return R;
}
;

create procedure wa_str2words (in pString varchar)
{
  declare iOffSet integer;
  declare aRes, aRegExpVec any;

  aRes := vector();

  iOffSet := 0;
  while(iOffSet < length(pString)) {
    aRegExpVec := regexp_parse('[^\\W]*',pString, iOffSet);
    if (length(aRegExpVec) <> 2) signal('22023','Parse problem');
    if (aRegExpVec[0] <> aRegExpVec[1]) {
      aRes := vector_concat(aRes,vector(subseq(pString,aRegExpVec[0],aRegExpVec[1])));
      iOffset := aRegExpVec[1];
    } else iOffSet := iOffSet + 1;
  };
  return aRes;
}
;

create procedure wa_get_keywords (in pArray any,in pWord varchar){
  return wa_keywords_sift(pArray,vector(pWord),'',0);
}
;

create procedure wa_execute_search (in uid integer, in aquery any, in pClassSet any := null)
  {

    declare sCnd,sUnion varchar;
    declare sCharSet varchar;
    declare aClassSet, aWords,aRes any;

    aRes := '';
    sCnd := '';
    aWords := vector();
    aWords := wa_str2words(aquery);

    sUnion := ' and ';

    foreach(varchar sWord in aWords)do{
     sCnd := '"' || sWord || '"';
     --else sCnd := sCnd || sUnion || '"' || sWord || '"';
    };

    if  (length(pClassSet) = 0) aClassSet := vector_concat(vector('Person'),vector('Tags'));
    else aClassSet := pClassSet;

    --if (pScope = 1) sCnd := sprintf('( ORG%dID and OWNER%dID and (%s) )',pOrgID,pUserID,sCnd);
    --else sCnd := sprintf('( ORG%dID and (%s) )',pOrgID,sCnd);

    --XSYS_DBG.debug1('  ' || XSYS_DBG.benchmark('execute_search - where compiled ','n','search_exec'));

    foreach(varchar sClass in aClassSet)do
      execute_fetch(uid,sClass,aRes);

    return aRes;
}
;


create procedure wa_tags2vector (inout tags varchar)
{
  return split_and_decode(trim(tags, ','), 0, '\0\0,');
}
;

create procedure wa_tags2search (in tags varchar)
{
  declare S varchar;
  declare V any;

  S := '';
  V := wa_tags2vector(tags);
  foreach (any tag in V) do
    S := concat(S, ' ', replace (trim(tag), ' ', '_'));
  return FTI_MAKE_SEARCH_STRING(trim(S, ','));
}
;

-- user is dba checks
create procedure wa_user_is_dba (in uname varchar, in ugroup int) returns int
{
  if (ugroup is null)
    ugroup := -1;
  if (uname = 'dba' or uname = 'dav' or ugroup = 0)
    return 1;
  return 0;
}
;


create procedure
WA_TEMPLATE_COPY (in path varchar,
                  in destination varchar,
                  in uid2 any,
                  in overwrite integer,
		  in file_list any := null)
{
  declare pwd1 any;
  declare _res_id int;
  declare copy_list any;

  pwd1 := (select pwd_magic_calc (U_NAME, U_PASSWORD, 1) from DB.DBA.SYS_USERS where U_NAME = 'dav');
  DAV_MAKE_DIR (destination, uid2, http_admin_gid (), '111101100N');

  copy_list := DB.DBA.DAV_DIR_LIST (path, 0, 'dav', pwd1);
  foreach (any entry in copy_list) do
    {
      declare dest_file any;
      dest_file := entry[10];
      if (regexp_match (file_list, dest_file) is not null)
        {
          --dbg_obj_print ('path||dest_file', path||dest_file, ' to ', destination||dest_file);
          _res_id := DB.DBA.DAV_COPY(path||dest_file, destination||dest_file,
          		overwrite, '110101100N', uid2, 'administrators', 'dav', pwd1);
          if (_res_id < 0)
            signal ('42000', 'Internal error: Cannot copy WebDAV resource : ' || dest_file);
          --dbg_obj_print (_res_id);
        }
    }
}
;


create procedure WA_MEMBER_URLS (in uid int)
{
  declare _WAI_NAME, HP_HOST, HP_LPATH, HP_LISTEN_HOST varchar;
  declare lpath, ppath, DEF_PAGE varchar;
  declare pos, IS_DEFAULT, _WAI_ID int;

  result_names (_WAI_NAME, HP_HOST, HP_LPATH, HP_LISTEN_HOST, IS_DEFAULT, DEF_PAGE, _WAI_ID);

  for select WAM_HOME_PAGE, WAM_INST, WAI_ID, WAM_APP_TYPE from WA_MEMBER, WA_INSTANCE
    where WAM_INST = WAI_NAME and WAM_USER = uid and WAM_MEMBER_TYPE = 1 do
    {
      pos := strrchr (WAM_HOME_PAGE, '/');
      DEF_PAGE := null;
      if (pos is not null)
	{
          lpath := subseq (WAM_HOME_PAGE, 0, pos);
	  DEF_PAGE := subseq (WAM_HOME_PAGE, pos+1);
	}
      else
        lpath := WAM_HOME_PAGE;
      if (not length (DEF_PAGE) and (WAM_APP_TYPE <> 'oWiki'))
	DEF_PAGE := 'index.vspx';
      if (length (lpath) > 1)
        lpath := rtrim (lpath, '/');
      result (WAM_INST, '*ini*', lpath, '*ini*', 1, DEF_PAGE, WAI_ID);
    }
  for select WAI_ID, WAI_NAME, VH_HOST, VH_LPATH, VH_LISTEN_HOST, VH_PAGE, WAM_HOME_PAGE from WA_VIRTUAL_HOSTS, WA_INSTANCE, WA_MEMBER
    where WAI_ID = VH_INST and WAM_INST = WAI_NAME and WAM_USER = uid and WAM_MEMBER_TYPE = 1 do
      {
	if (rtrim (WAM_HOME_PAGE, '/') <> VH_LPATH or VH_HOST <> '*ini*' or VH_LISTEN_HOST <> '*ini*')
	  result (WAI_NAME, VH_HOST, VH_LPATH, VH_LISTEN_HOST, 0, VH_PAGE, WAI_ID);
      }
};

create procedure WA_HOSTS_INIT ()
{
  declare lpath, ppath, def_page varchar;
  declare pos int;

  if (registry_get ('wa_hosts_updated') = '1')
    return;

  for select WAM_HOME_PAGE, WAI_ID, WAM_APP_TYPE from WA_MEMBER, WA_INSTANCE where
    	WAM_INST = WAI_NAME and WAM_APP_TYPE = 'WEBLOG2' and WAM_MEMBER_TYPE = 1 do
    {
      pos := strrchr (WAM_HOME_PAGE, '/');
      def_page := 'index.vspx';
      if (pos is not null)
	{
	  lpath := subseq (WAM_HOME_PAGE, 0, pos);
	  def_page := subseq (WAM_HOME_PAGE, pos+1);
	}
      else
	lpath := WAM_HOME_PAGE;

      if (not length (def_page))
	def_page := 'index.vspx';
      ppath := (select HP_PPATH from HTTP_PATH where HP_LPATH= lpath and HP_HOST = '*ini*' and HP_LISTEN_HOST= '*ini*');
      for select HP_HOST as vhost, HP_LPATH as lpath1, HP_LISTEN_HOST as lhost from HTTP_PATH where HP_PPATH = ppath do
	{
	  if (not (vhost = '*ini*' and lhost = '*ini*' and lpath1 = lpath))
	    {
              insert replacing WA_VIRTUAL_HOSTS (VH_INST,VH_HOST,VH_LISTEN_HOST,VH_LPATH, VH_PAGE)
		  values (WAI_ID, vhost, lhost, lpath1, def_page);
	    }
	}
    }
--  registry_set ('wa_home_title', 'ODS Home');
  registry_set ('wa_hosts_updated', '1');
};

WA_HOSTS_INIT ();

create procedure WA_REG_INIT ()
{
  if (registry_get ('wa_reg_updated') = '1')
    return;

  if (not isstring (registry_get ('wa_home_title')))
    registry_set ('wa_home_title', 'ODS Home');
  registry_set ('wa_home_link', '/ods/');

  registry_set ('wa_reg_updated', '1');
};

WA_REG_INIT ();

create procedure WA_LINK (in add_host int := 0, in url varchar := null)
{
  declare wa_url, ret varchar;
  wa_url := registry_get ('wa_home_link');

  if (add_host)
    {
      declare hf any;
      hf := WS.WS.PARSE_URI (wa_url);
      if (hf[1] = '')
	{
	  hf[0] := 'http';
  	  hf[1] := wa_cname ();
	  wa_url := vspx_uri_compose (hf);
	}
    }

  if (length (url) = 0)
    {
      ret := wa_url;
    }
  else
    {
      ret := WS.WS.EXPAND_URL (wa_url, url);
    }
  return ret;
};

create procedure WA_SET_APP_URL
	(in app_id any,
    	in lpath any,
	in prefix any := null,
	in domain any := '\173Default Domain\175',
	in old_path any := null,
	in old_host any := null,
	in old_ip any := null,
	in silent int := 0
	)
{
   declare inst web_app;
   declare phys_path, def_lpath, def_page any;
   declare pos any;
   declare _lhost, _vhost any;
   declare arr, port any;
   declare len, i, ix integer;
   declare cur_add_url, add_url_arr any;
   declare vd_pars any;

   declare vd_is_dav, vd_is_browse int;
   declare vd_opts, h any;
   declare vd_user, vd_pp, vd_auth varchar;

--   dbg_obj_print ('WA_SET_APP_URL',app_id,lpath,prefix,domain,old_path,old_host,old_ip,silent);

   if (domain is null)
     domain := '{Default Domain}';

   if (length(lpath) = 0)
     lpath := '/';

   lpath := trim(lpath, '/\\. ');
   lpath := '/' || lpath;

   prefix := trim(prefix, '/\\. ');

   declare exit handler for not found {
     rollback work;
     signal ('22023', sprintf ('No such application instance id=%d', app_id));
   };
   select WAI_INST into inst from WA_INSTANCE where WAI_ID = app_id;

   vd_pars := null;
   h := udt_implements_method (inst, fix_identifier_case ('wa_vhost_options'));
   if (h)
     vd_pars := call (h) (inst);
   if (vd_pars is not null)
     {
       phys_path := vd_pars[0];
       def_page :=  vd_pars[1];
       vd_user :=   vd_pars[2];
       vd_is_browse :=vd_pars[3];
       vd_is_dav := vd_pars[4];
       vd_opts :=   vd_pars[5];
       vd_pp :=     vd_pars[6];
       vd_auth :=   vd_pars[7];
       goto do_the_dirs;
     }

   vd_user := 'dba';
   vd_is_browse := 0;
   vd_is_dav := 1;
   vd_opts := vector ();
   vd_pp := null;
   vd_auth := null;

   def_lpath := inst.wa_home_url();
   --dbg_obj_print ('inst.wa_home_url', def_lpath);
   pos := 0;

   if (def_lpath[length (def_lpath) - 1] <> ascii ('/'))
     pos := strrchr (def_lpath, '/');
   def_page := null;
   if (pos is not null and pos > 1)
     {
       def_page := subseq (def_lpath, pos+1);
       def_lpath := subseq (def_lpath, 0, pos);
     }
   if (length (def_lpath) > 1)
     def_lpath := rtrim (def_lpath, '/');
   if (length (def_page) = 0)
     def_page := 'index.vspx';

   phys_path := (select HP_PPATH from HTTP_PATH where HP_LPATH = def_lpath and HP_HOST = '*ini*' and HP_LISTEN_HOST = '*ini*');

   do_the_dirs:

   if (domain = '{Default Domain}')
     {
       _lhost := '*ini*';
       _vhost := '*ini*';
       if (length (prefix))
	 signal ('22023', 'Can not make a subdomain of the default domain');
       if (not length (lpath))
	 signal ('22023', 'The root of default domain is prohibited');
     }
   else if (domain = '{My Own Domain}')
     {
       declare port1, port2, tmp, c_host varchar;

       _vhost := prefix;
       _lhost := http_map_get ('lhost');

       port1 := null;
       port2 := null;

       c_host := HTTP_GET_HOST ();

       tmp := split_and_decode (_vhost, 0, '\0\0:');
       if (length (tmp) = 2)
	 port1 := tmp[1];

       if (not length (tmp))
         signal ('22023', 'No own domain was specified');

       if (_lhost = '*ini*')
	 {
	   tmp := split_and_decode (sys_connected_server_address (), 0, '\0\0:');
	 }
       else
         {
           tmp := split_and_decode (_lhost, 0, '\0\0:');
	 }

       if (length (tmp) = 2)
	 port2 := tmp[1];
       else
	 port2 := '80';

       if (port1 is not null and port1 <> port2)
         signal ('22023', 'The specified port must be same as one which is currently in use. If you are not sure which is it, just not specify the port number.');

       if (port1 is null)
	 _vhost := _vhost || ':' || port2;

       if (c_host = _vhost and lpath = '/')
         signal ('22023', 'The domain specified matches the host used to access the application configuration pages.');

     }
   else
     {
       if (length (prefix))
	 _vhost := concat (prefix, '.', domain);
       else
         _vhost := domain;
       declare exit handler for not found {
           if (silent)
             return;
	   rollback work;
	   signal ('22023', sprintf ('No such wa domain %s', domain));
	 };
       select WD_LISTEN_HOST into _lhost from WA_DOMAINS where
	   WD_DOMAIN = domain;
     }

   arr := split_and_decode (_lhost, 0, '\0\0:');
   port := '';
   if (length (arr) = 2)
     port := arr[1];
   else if (length (arr) = 1)
     ;
   else
     signal ('22023', 'Cannot get the port number');

   --if (length (port))
   --  _vhost := _vhost || ':' || port;

   --dbg_obj_print ('vhost=', _vhost);
   --dbg_obj_print ('lhost=', _lhost);
   --dbg_obj_print ('lpath=', lpath);
   --dbg_obj_print ('def_lpath=', def_lpath);
   --dbg_obj_print ('ppath=', phys_path);
   --dbg_obj_print ('def_page=', def_page);

   if (phys_path is null)
     {
       signal ('22023', 'System cannot find the physical location of your application');
     }

   -- No modifications are needed
   if (old_host = _vhost and old_path = lpath and old_ip = _lhost)
     return;

   if (exists(select 1 from HTTP_PATH where HP_HOST= _vhost and HP_LISTEN_HOST= _lhost and HP_LPATH = lpath))
     {
       if (silent)
	 return;
       signal ('42000', 'This site already exists');
     }

  --! dirty hack
  connection_set ('vhost', _vhost);
  connection_set ('port', port);

  -- Application additional URL
  add_url_arr := make_array (2, 'any');
  h := udt_implements_method (inst, fix_identifier_case ('wa_addition_urls'));
  if (h)
	add_url_arr [0] := call (h) (inst);
  h := udt_implements_method (inst, fix_identifier_case ('wa_addition_instance_urls'));
  if (h)
	add_url_arr [1] := call (h) (inst, lpath);

--  dbg_obj_print (inst, add_url_arr);
  ix := 0;

  foreach (any add_url in add_url_arr) do
    {
      len := length (add_url);
      i := 0;
      while (i < len and (ix = 1 or _lhost <> '*ini*'))
	{
	  cur_add_url := add_url[i];
	  if (ix = 1 and old_host is not null and old_ip is not null)
	    {
	      VHOST_REMOVE (lpath=>cur_add_url[2], vhost=>old_host, lhost=>old_ip);
	    }
	  if (not exists (select 1 from HTTP_PATH
		where HP_HOST = _vhost and HP_LISTEN_HOST = _lhost and HP_LPATH = cur_add_url[2]))
	    {
	      VHOST_DEFINE(
		  vhost=>_vhost,
		  lhost=>_lhost,
		  lpath=>cur_add_url[2],
		  ppath=>cur_add_url[3],
		  is_dav=>cur_add_url[4],
		  is_brws=>cur_add_url[5],
		  def_page=>cur_add_url[6],
		  auth_fn=>cur_add_url[7],
		  realm=>cur_add_url[8],
		  ppr_fn=>cur_add_url[9],
		  vsp_user=>cur_add_url[10],
		  soap_user=>cur_add_url[11],
		  sec=>cur_add_url[12],
		  ses_vars=>cur_add_url[13],
		  soap_opts=>cur_add_url[14],
		  auth_opts=>cur_add_url[15],
		  opts=>cur_add_url[16],
		  is_default_host=>cur_add_url[17]);
	    }
	    i := i + 1;
	}
      ix := ix + 1;
    }
  -- Home URL
  if (old_path is not null)
    {
      VHOST_REMOVE (lpath=>old_path, vhost=>old_host, lhost=>old_ip);
    }
  VHOST_DEFINE (
	  vhost=>_vhost,
	  lhost=>_lhost,
	  lpath=>lpath,
	  ppath=>phys_path,
	  is_dav=>vd_is_dav,
	  is_brws=>vd_is_browse,
	  vsp_user=>vd_user,
	  ppr_fn=>vd_pp,
	  auth_fn=>vd_auth,
	  opts=>vd_opts,
	  def_page=>def_page);
  pos := strrchr (_vhost, ':');
  -- no port info anymore in the vhost
  if (pos is not null)
    _vhost := subseq (_vhost, 0, pos);
  insert replacing WA_VIRTUAL_HOSTS (VH_INST,VH_HOST,VH_LISTEN_HOST,VH_LPATH, VH_PAGE)
      values (app_id, _vhost, _lhost, lpath, def_page);
};


create procedure WA_GET_APP_NAME (in app varchar)
{
  declare lab, arr varchar;
  lab := registry_get ('_wa_label_' || app);

  if (isstring (lab) and length (lab))
    return lab;

  if (app = 'WEBLOG2')
    return 'Weblog';
  else if (app = 'eNews2')
    return 'Feeds';
  else if (app = 'oWiki')
    return 'Wiki';
  else if (app = 'oDrive')
    return 'Briefcase';
  else if (app = 'oMail')
    return 'Mail';
  else if (app = 'oGallery')
    return 'Photos';
  else if (app = 'xDiaspora' or app = 'Community')
    return 'Community';
  else if (app = 'Bookmark')
    return 'Bookmarks';
  else if (app = 'nntpf')
    return 'Discussion';
  else
    return app;
};

create procedure WA_GET_MFORM_APP_NAME (in app varchar)
{
  declare lab, arr varchar;
  lab := registry_get ('_wa_mform_label_' || app);

  if (isstring (lab) and length (lab))
    return lab;

  if (app = 'WEBLOG2')
    return 'Weblogs';
  else if (app = 'eNews2')
    return 'Feeds';
  else if (app = 'oWiki')
    return 'Wikies';
  else if (app = 'oDrive')
    return 'Briefcases';
  else if (app = 'oMail')
    return 'Mails';
  else if (app = 'oGallery')
    return 'Photos';
  else if (app = 'xDiaspora' or app = 'Community')
    return 'Communities';
  else if (app = 'Bookmark')
    return 'Bookmarks';
  else if (app = 'nntpf')
    return 'Discussions';
  else
    return app;
};

create procedure wa_inst_type_icon (in app varchar)
{
  if (app = 'WEBLOG2')
    return 'blog';
  else if (app = 'eNews2')
    return 'enews';
  else if (app = 'oWiki')
    return 'wiki';
  else if (app = 'oDrive')
    return 'odrive';
  else if (app = 'oMail')
    return 'mail';
  else if (app = 'oGallery')
    return 'ogallery';
  else if (app = 'xDiaspora' or app = 'Community')
    return 'go';
  else if (app = 'bookmark')
    return 'go';
  else
    return 'go';
};

create function WA_MAKE_THUMBNAIL (inout image any, in width integer := 64, in height integer := 50)
returns any
{
  if (__proc_exists ('IM ThumbnailImageBlob', 2))
    return "IM ThumbnailImageBlob" (image, length (image), width, height, 1);
  else
    return NULL;
}
;

create procedure wa_get_users (in mask any := '%', in ord any := '', in seq any := 'asc', in what any := 'all')
{
  declare sql, dta, mdta, rc, h, tmp, pred any;

  declare U_NAME, U_FULL_NAME, U_LOGIN_TIME, U_EDIT_TIME, U_ACCOUNT_DISABLED, U_ID any;

  result_names (U_NAME, U_FULL_NAME, U_ACCOUNT_DISABLED, U_ID);
  if (not isstring (mask))
    mask := '%';
  pred := '';

  if (what = 'frozen')
    pred := ' and U_ACCOUNT_DISABLED = 1 ';
  if (what = 'active')
    pred := ' and U_ACCOUNT_DISABLED = 0 ';

  sql := 'select U_NAME, coalesce (U_FULL_NAME, \'\') as U_FULL_NAME, U_ACCOUNT_DISABLED, U_ID ' ||
         ' from SYS_USERS, WA_USER_INFO where U_ID = WAUI_U_ID and U_DAV_ENABLE = 1 and U_IS_ROLE = 0 ' ||
	 pred ||
	 'and (upper (U_NAME) like upper (?))';


  if (length (ord))
    {
      tmp := case ord when 'name' then 'U_NAME' when 'fullname' then 'U_FULL_NAME' else '' end;
      if (tmp <> '')
	{
	  ord := 'order by lower(' || tmp || ') ' || seq;
	  sql := sql || ord;
	}
    }
  rc := exec (sql, null, null, vector (mask), 0, null, null, h);
  while (0 = exec_next (h, null, null, dta))
    exec_result (dta);
  exec_close (h);
}
;

wa_exec_no_error('create procedure view WA_SYS_USERS as wa_get_users (mask, ord, seq, what) (U_NAME varchar, U_FULL_NAME varchar, U_ACCOUNT_DISABLED int, U_ID int)');


/* similar to the blog ones. when blog is installed these are replaced */
create procedure WA_XPATH_GET_HTTP_URL ()
{
  declare host, path, qstr, conn any;

  conn := connection_get ('Atom_Self_URI');

  if (conn is not null)
    return conn;

  host := HTTP_GET_HOST ();
  path := http_path ();
  qstr := http_request_get ('QUERY_STRING');
  if (length (qstr))
    qstr := '?' || qstr;
  return 'http://' || host || path || qstr;
};

create procedure WA_XPATH_EXPAND_URL (in url varchar)
{
  declare base, ret varchar;
  --dbg_obj_print ('url:',url);
  base := HTTP_URL_HANDLER ();
  ret := WS.WS.EXPAND_URL (base, url);
  return ret;
};

grant execute on WA_XPATH_GET_HTTP_URL to public;
grant execute on WA_XPATH_EXPAND_URL to public;
grant execute on WA_GET_HOST to public;

xpf_extension ('http://www.openlinksw.com/ods/:getHttpUrl', 'DB.DBA.WA_XPATH_GET_HTTP_URL');
xpf_extension ('http://www.openlinksw.com/ods/:getExpandUrl', 'DB.DBA.WA_XPATH_EXPAND_URL');
xpf_extension ('http://www.openlinksw.com/ods/:getHost', 'DB.DBA.WA_GET_HOST');


create procedure WA_RDF_ID (in str varchar)
{
  declare x any;
  x := regexp_replace (str, '[^[:alnum:]]', '_', 1, null);
  return x;
};

create procedure WA_APP_PREFIX (in app any)
{
  if (app = 'WEBLOG2')
    return 'BLOG';
  else if (app = 'eNews2')
    return 'ENEWS';
  else if (app = 'oWiki')
    return 'WIKI';
  else if (app = 'oDrive')
    return 'ODRIVE';
  else if (app = 'oMail')
    return 'MAIL';
  else if (app = 'oGallery')
    return 'OGALLERY';
  else if (app = 'xDiaspora' or app = 'Community')
    return 'COMMUNITY';
  else if (app = 'Bookmark')
    return 'BMK';
  else
    return app;

};

create procedure WA_APPS_INSTALLED ()
{
  declare ret any;
  ret := (select vector_agg (WA_APP_PREFIX (WAT_NAME)) from WA_TYPES);
  return vector_concat (ret, vector ('NNTPF'));
};


create procedure WA_MAIL_VALIDATE (in login any)
{
  declare U_NAME, dummy, rc, pkgs any;

  result_names (U_NAME);
  whenever not found goto nouser;
  SELECT u.U_NAME into dummy FROM WS.WS.SYS_DAV_USER u WHERE u.U_NAME = login AND U_ACCOUNT_DISABLED=0;
  result (dummy);
  return 1;

  nouser:

  pkgs := WA_APPS_INSTALLED ();

  foreach (any p in pkgs) do
    {
      declare p_name varchar;

      p_name := sprintf ('DB.DBA.%s_MAIL_VALIDATE', p);

      if (__proc_exists (p_name))
	{
	  rc := call (p_name) (login);
	  --dbg_printf ('Validated %s = %d', p_name, rc);
	  if (rc = 1)
	    return rc;
	}
    }
  return 0;
};

create procedure WA_NEW_MAIL (in _uid varchar, in _msg any, in _domain varchar := null)
{
  declare rc, pkgs any;
  pkgs := WA_APPS_INSTALLED ();

  foreach (any p in pkgs) do
    {
      declare p_name varchar;

      p_name := sprintf ('DB.DBA.%s_NEW_MAIL', p);

      if (__proc_exists (p_name))
	{
	  if (length (procedure_cols (p_name)) = 3)
	    rc := call (p_name) (_uid, _msg, _domain);
	  else
	  rc := call (p_name) (_uid, _msg);
	  --dbg_printf ('Storing %s = %d', p_name, rc);
	  if (rc = 1)
	    return rc;
	}
    }
  DB.DBA.NEW_MAIL (_uid, _msg);
  return 1;
};

-- NNTP procedures
--
create procedure NNTP_NEWS_MSG_ADD (in app varchar, in sql varchar)
{
  declare v any;
  declare x any;

-- potential unpredicted behaviour after VAD upgrade
--  x := registry_get ('__NNTP_NEWS_MSG_' || app);
--  if (isstring (x) and strstr (sql, x) is not null)
--    return;
  NNTP_NEWS_MSG_DEL (app);

  declare exit handler for not found return;

  select coalesce (V_TEXT, blob_to_string (V_EXT)) into v from SYS_VIEWS where V_NAME = 'DB.DBA.NEWS_MSG';
  v := v || ' union all ' || sql;

  declare state, message any;
  exec ('drop view DB.DBA.NEWS_MSG', state, message);
  exec (v, state, message);
  registry_set ('__NNTP_NEWS_MSG_' || app, sql);
};

create procedure NNTP_NEWS_MSG_DEL (in app varchar)
{
  declare v any;
  declare x any;

  x := registry_get ('__NNTP_NEWS_MSG_' || app);
  if (not isstring (x))
    return;

  declare exit handler for not found return;

  select coalesce (V_TEXT, blob_to_string (V_EXT)) into v from SYS_VIEWS where V_NAME = 'DB.DBA.NEWS_MSG';
  v := replace(v, ' union all ' || x, '');

  declare state, message any;
  exec ('drop view DB.DBA.NEWS_MSG', state, message);
  exec (v, state, message);
  registry_remove ('__NNTP_NEWS_MSG_' || app);
};



create procedure WA_GET_HTTP_URL ()
{
  declare host, path, qstr, conn any;

  conn := connection_get ('Atom_Self_URI');

  if (conn is not null)
    return conn;

  host := WA_GET_HOST ();
  path := http_path ();
  qstr := http_request_get ('QUERY_STRING');
  if (length (qstr))
    qstr := '?' || qstr;
  return 'http://' || host || path || qstr;
};


create procedure WS.WS.SYS_DAV_RES_RES_CONTENT_INDEX_HOOK (inout vtb any, inout r_id any)
{
-- so far hook function deals with wiki only
-- note, hook function can be called from batch mode so it must not rely on
-- trigger order
   declare exit handler for sqlstate '*' {
	--dbg_obj_princ (__SQL_STATE, ' ', __SQL_MESSAGE);
	resignal;
   };
   if(__proc_exists ('WS.WS.META_WIKI_HOOK'))
     {
         call ('WS.WS.META_WIKI_HOOK') (vtb, r_id);
     }
  return 0;
};

create procedure ODS.BAR._EXEC(in app_type varchar,in params any, in lines any){

  declare odshome_url,odsbar_filepath varchar;
  odshome_url:='';
  odsbar_filepath:='';

  odshome_url:=registry_get ('wa_home_link');
  odsbar_filepath:='';


  whenever not found goto nf;
  {
    select top 1 HP_PPATH into odsbar_filepath from DB.DBA.HTTP_PATH where HP_LPATH = rtrim(odshome_url, '/');
  }

  nf:
  if (length(odsbar_filepath)=0){
      odsbar_filepath:='./samples/wa/ods_bar.vspx';
   }else {
      odsbar_filepath:=odsbar_filepath||'ods_bar.vspx';
   }




         if(get_keyword('logout',params)='true' and length(get_keyword('sid',params))>0)
         {
                     delete from VSPX_SESSION where VS_SID = get_keyword('sid',params);

                     declare redirect_url varchar;
                     redirect_url:=odshome_url||'sfront.vspx';

                     http_rewrite ();
                     http_request_status ('HTTP/1.1 302 Found');
                     http_header (concat (http_header_get (), 'Location: ',redirect_url,'\r\n'));

                     return;
         };



  params := vector_concat(params, vector('app_type', app_type));
  DB.DBA.vspx_dispatch(odsbar_filepath, odshome_url, params, lines, null, 0, 'DB', 'DBA');
  return http_get_string_output();

};

create procedure wa_make_url_from_vd (in host varchar, in lhost varchar, in path varchar)
{
  declare pos, port any;
  pos := strrchr (host, ':');
  if (pos is not null)
    host := subseq (host, 0, pos);
  pos := strrchr (lhost, ':');
  if (pos is not null)
    port := subseq (lhost, pos, length (lhost));
  else if (lhost = '*ini*')
    port := ':'||server_http_port ();
  else
    port := '';
  if (path like 'http://%')
    return rtrim(path, '/');
  else
  return sprintf ('http://%s%s%s/', host, port, rtrim(path, '/'));
};
