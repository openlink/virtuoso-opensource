--
--  $Id$
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2016 OpenLink Software
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

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.exec_no_error(in expr varchar, in execType varchar := '', in execTable varchar := '', in execColumn varchar := '')
{
  declare
    state,
    message,
    meta,
    result any;

  log_enable(1);
  if (execType = 'C') {
    if ((select 1 from DB.DBA.SYS_COLS where "TABLE" = execTable and "COLUMN" = execColumn) = 1)
      return;
  }
  if (execType = 'S') {
    declare S varchar;
    declare maxID integer;

    S := sprintf('select max(%s) from %s', execColumn, execTable);
    maxID := 1000;
    state := '00000';

    exec(S, state, message, vector(), 0, meta, result);
    if (state = '00000')
      if (not isnull(result[0][0]))
        maxID := result[0][0] + 1;

    expr := sprintf(expr, maxID);
  }
  exec(expr, state, message, vector(), 0, meta, result);
}
;

OMAIL.WA.exec_no_error(
  'insert replacing WA_TYPES(WAT_NAME, WAT_TYPE, WAT_REALM, WAT_DESCRIPTION) values (\'oMail\', \'db.dba.wa_mail\', \'wa\', \'Mail\')'
)
;

OMAIL.WA.exec_no_error(
  'insert soft WA_MEMBER_TYPE (WMT_APP, WMT_NAME, WMT_ID, WMT_IS_DEFAULT) values (\'oMail\', \'owner\', 1, 0)'
)
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.omail_install()
{
  declare
    iIsDav integer;
  declare
    sHost varchar;

  -- Add a virtual directory for oMail - public www -------------------------
  sHost := cast(registry_get('_oMail_path_') as varchar);
  if (sHost = '0')
    sHost := '/apps/oMail/';
  iIsDav := 1;
  if (isnull(strstr(sHost, '/DAV/VAD')))
    iIsDav := 0;

  -- Add a virtual directory for web mail -----------------------
  VHOST_REMOVE(lpath      => '/oMail');
  VHOST_DEFINE(lpath      => '/oMail',
               ppath      => concat(sHost, 'www-root/portal.vsp'),
               opts       => vector('noinherit', 1),
               vsp_user   => 'dba',
               realm      => 'wa',
               def_page   => 'index.vsp',
               is_dav     => iIsDav,
               ses_vars   => 1
              );

  VHOST_REMOVE(lpath      => '/oMail/i');
  VHOST_DEFINE(lpath      => '/oMail/i',
               ppath      => concat(sHost, 'www-root/mail/i/'),
               vsp_user   => 'dba',
               realm      => 'wa',
               def_page   => 'index.html',
               is_dav     => iIsDav,
               ses_vars   => 1
              );

  VHOST_REMOVE(lpath      => '/oMail/res');
  VHOST_DEFINE(lpath      => '/oMail/res',
               ppath      => concat(sHost, 'www-root/res/'),
               vsp_user   => 'dba',
               realm      => 'wa',
               def_page   => 'index.html',
               is_dav     => iIsDav,
               ses_vars   => 1
              );

  if ((select count(*) from DB.DBA.WA_DOMAINS) = 0)
  insert replacing DB.DBA.WA_DOMAINS(WD_DOMAIN) values('domain.com');
}
;


OMAIL.WA.exec_no_error(
'
  create type wa_mail under web_app as (
    wa_domain varchar
	)
  constructor method wa_mail(stream any),
  overriding method wa_new_inst(login varchar) returns any,
  overriding method wa_front_page (stream any) returns any,
  overriding method wa_state_edit_form(stream any) returns any,
  overriding method wa_home_url() returns varchar,
  overriding method wa_drop_instance() returns any,
  overriding method wa_domain_set (in domain varchar) returns any
'
)
;

OMAIL.WA.exec_no_error(
  'alter type wa_mail add overriding method wa_domain_set (in domain varchar) returns any'
)
;

OMAIL.WA.exec_no_error(
  'alter type wa_mail add overriding method wa_front_page_as_user(inout stream any, in user_name varchar) returns any'
)
;

OMAIL.WA.exec_no_error(
  'alter type wa_mail add overriding method wa_size() returns int'
)
;

OMAIL.WA.exec_no_error(
  'alter type wa_mail add method wa_vhost_options () returns any'
)
;

OMAIL.WA.exec_no_error(
  'alter type wa_mail add overriding method wa_addition_urls () returns any'
)
;

OMAIL.WA.exec_no_error(
  'alter type wa_mail add method get_param (in param varchar) returns any'
)
;

OMAIL.WA.exec_no_error(
  'alter type wa_mail add overriding method wa_dashboard () returns any'
)
;

OMAIL.WA.exec_no_error(
  'alter type wa_mail add method wa_dashboard_last_item () returns any'
)
;

OMAIL.WA.exec_no_error(
  'alter type wa_mail add overriding method wa_state_edit_form(stream any) returns any'
)
;

OMAIL.WA.exec_no_error(
  'alter type wa_mail add overriding method wa_rdf_url (in vhost varchar, in lhost varchar) returns varchar'
)
;

OMAIL.WA.exec_no_error(
  'alter type wa_mail add method wa_id () returns any'
)
;

-------------------------------------------------------------------------------
--
create constructor method wa_mail (inout stream any) for wa_mail
{
  return;
}
;

-------------------------------------------------------------------------------
--
create method wa_id () for wa_mail
{
  return (select WAI_ID from WA_INSTANCE where WAI_NAME = self.wa_name);
}
;

-------------------------------------------------------------------------------
--
create method wa_drop_instance () for wa_mail
{
  declare iUserID, iCount any;

  iUserID := (select WAM_USER from WA_MEMBER where WAM_INST = self.wa_name and WAM_MEMBER_TYPE = 1);

  select count(WAM_USER) into iCount
    from WA_MEMBER,
         WA_INSTANCE
   where WAI_NAME = WAM_INST
     and WAI_TYPE_NAME = 'oMail'
     and WAM_USER = iUserID;

  OMAIL.WA.omail_delete_user_data (self.wa_id (), iUserID);
  if (iCount = 1)
    OMAIL.WA.omail_delete_user_data (1, iUserID);

  declare path, login varchar;
	login := (select U_NAME from SYS_USERS where U_ID = iUserID);
	path := sprintf('/DAV/home/%s/%s/', login, self.wa_name);
	delete from WS.WS.SYS_DAV_COL where COL_ID = DAV_SEARCH_ID (path, 'C');

  (self as web_app).wa_drop_instance ();
}
;

-------------------------------------------------------------------------------
--
create method wa_new_inst (in login varchar) for wa_mail
{
  declare iUserID integer;
  declare retValue any;

  iUserID := (select U_ID from DB.DBA.SYS_USERS where U_NAME = login);
  if (isnull (iUserID))
    signal('EN001', 'not a Virtuoso WA user');

  if (self.wa_member_model is null)
    self.wa_member_model := 0;

  insert into WA_INSTANCE (WAI_NAME, WAI_TYPE_NAME, WAI_INST, WAI_DESCRIPTION)
  	values (self.wa_name, 'oMail', self, 'Description');

  OMAIL.WA.omail_init_user_data (1, iUserID, self.wa_name);

  retValue := (self as web_app).wa_new_inst (login);

  -- Create DET Folder
  declare path varchar;

	path := sprintf('/DAV/home/%s/%s/', login, self.wa_name);
  DB.DBA.DAV_MAKE_DIR (path, iUserID, null, '110100000N');
  DAV_PROP_SET_INT (path, 'virt:oMail-DomainId', '1', null, null, 0, 0, 1);
  DAV_PROP_SET_INT (path, 'virt:oMail-UserName', login, null, null, 0, 0, 1);
  DAV_PROP_SET_INT (path, 'virt:oMail-FolderName', 'NULL', null, null, 0, 0, 1);
  DAV_PROP_SET_INT (path, 'virt:oMail-NameFormat', '^from^ ^subject^', null, null, 0, 0, 1);
  update WS.WS.SYS_DAV_COL set COL_DET = 'oMail' where COL_ID = DAV_SEARCH_ID (path, 'C');

  return retValue;
}
;

-------------------------------------------------------------------------------
--
create method wa_front_page (inout stream any) for wa_mail
{
  declare sSid varchar;

  sSid := (select VS_SID from VSPX_SESSION where VS_REALM = 'wa' and VS_UID = connection_get('vspx_user'));

  http_request_status ('HTTP/1.1 302 Found');
  http_header(sprintf('Location: %s?sid=%s&realm=%s\r\n', self.wa_home_url(), sSid, 'wa'));
  return;
}
;

-------------------------------------------------------------------------------
--
create method wa_state_edit_form(inout stream any) for wa_mail
{
  declare sSid varchar;

  if (exists(select 1
               from SYS_USERS A,
                    WA_MEMBER B
              where A.U_NAME = connection_get('vspx_user')
                and B.WAM_USER = A.U_ID
                and B.WAM_INST= self.wa_name
                and B.WAM_MEMBER_TYPE = 1))
  {
    sSid := (select VS_SID from VSPX_SESSION where VS_REALM = 'wa' and VS_UID = connection_get('vspx_user'));
    http_request_status ('HTTP/1.1 302 Found');
    http_header(sprintf('Location: %s?sid=%s&realm=%s\r\n', WS.WS.EXPAND_URL(self.wa_home_url(), 'set_mail.vsp'), sSid, 'wa'));
  return;
}
  signal('42001', 'Not a owner');
}
;

-------------------------------------------------------------------------------
--
create method wa_home_url () for wa_mail
{
  return sprintf ('/oMail/%d/box.vsp', self.wa_id ());
}
;

-------------------------------------------------------------------------------
--
create method wa_domain_set (in domain varchar) for wa_mail
{
  self.wa_domain := domain;
  return self;
}
;

-------------------------------------------------------------------------------
--
create method wa_front_page_as_user (inout stream any, in user_name varchar) for wa_mail
{
  declare sSid, sOwner varchar;

  sOwner := (select TOP 1 U_NAME from SYS_USERS A, WA_MEMBER B where B.WAM_USER = A.U_ID and B.WAM_INST= self.wa_name and B.WAM_MEMBER_TYPE = 1);
  sSid := md5 (concat (datestring (now ()), http_client_ip (), http_path ()));
  insert into DB.DBA.VSPX_SESSION (VS_REALM, VS_SID, VS_UID, VS_STATE, VS_EXPIRY)
    values ('wa', sSid, sOwner, serialize ( vector ('vspx_user', user_name, 'owner_user', sOwner)), now());
  http_request_status ('HTTP/1.1 302 Found');
  http_header(sprintf('Location: %s?sid=%s&realm=%s\r\n', self.wa_home_url(), sSid, 'wa'));
  return;
}
;

-------------------------------------------------------------------------------
--
create method wa_size () for wa_mail
{
  return 0;
}
;

-------------------------------------------------------------------------------
--
create method wa_vhost_options () for wa_mail
{
  return vector (
           concat(self.get_param('host'), 'www-root/portal.vsp'),  -- physical home
           'box.vsp',                                           -- default page
           'dba',                                                  -- user for execution
           0,                                                      -- directory browsing enabled (flag 0/1)
           self.get_param('isDAV'),                                -- WebDAV repository  (flag 0/1)
           vector ('noinherit', 1, 'domain', self.wa_id ()),       -- virtual directory options, empty is not applicable
           null,                                                   -- post-processing function (null is not applicable)
           null                                                    -- pre-processing (authentication) function
         );
}
;

-------------------------------------------------------------------------------
--
create method wa_addition_urls () for wa_mail {
  return vector(
    vector(null, null, '/oMail/i',     self.get_param('host') || 'www-root/mail/i/', self.get_param('isDAV'), 0, null, null, null, null, 'dba', null, null, 1, null, null, null, 0),
    vector(null, null, '/oMail/i/res', self.get_param('host') || 'www-root/res/',    self.get_param('isDAV'), 0, null, null, null, null, 'dba', null, null, 1, null, null, null, 0)
  );
}
;

-------------------------------------------------------------------------------
--
create method get_param (in param varchar) for wa_mail
{
  declare retValue any;

  retValue := null;
  if (param = 'host')
  {
    retValue := registry_get('_oMail_path_');
    if (cast(retValue as varchar) = '0')
      retValue := '/apps/oMail/';
  }
  else if (param = 'isDAV')
  {
    retValue := 1;
    if (isnull(strstr(self.get_param('host'), '/DAV/VAD')))
      retValue := 0;
  }
  return retValue;
}
;

-------------------------------------------------------------------------------
--
create method wa_dashboard () for wa_mail
{
  declare domainID, userID integer;

  domainID := self.wa_id ();
  userID := OMAIL.WA.domain_owner_id (domainID);
  return (select XMLAGG ( XMLELEMENT ( 'dash-row',
                                       XMLATTRIBUTES ( 'normal' as "class",
                                                       OMAIL.WA.dt_format(_time, 'Y/M/D H:N') as "time",
                                                       self.wa_name as "application"
                                                      ),
                                       XMLELEMENT ( 'dash-data',
	                                                  XMLATTRIBUTES ( concat (N'<a href="', cast (SIOC..mail_post_iri (domainID, _id) as nvarchar), N'">', OMAIL.WA.utf2wide (_title), N'</a>') as "content",
	                                                                  0 as "comments"
	                                                                )
                                          	      )
                                     )
                     	  )
            from OMAIL.WA.dashboard_rs(p0, p1)(_id integer, _title varchar, _time datetime) x
           where p0 = 1
             and p1 = userID
         );
}
;

-------------------------------------------------------------------------------
--
create method wa_dashboard_last_item () for wa_mail
{
  declare waID, domainID, userID integer;

  domainID := self.wa_id ();
  userID := OMAIL.WA.domain_owner_id (domainID);
  waID := coalesce((select top 1 WAI_ID from DB.DBA.WA_MEMBER, DB.DBA.WA_INSTANCE where WAM_INST = WAI_NAME and WAM_USER = userID and WAI_TYPE_NAME = 'oMail' order by WAI_ID), 0);
  if (waID = domainID)
    domainID := 1;
  return OMAIL.WA.dashboard_get(domainID, userID);
}
;

-------------------------------------------------------------------------------
--
create method wa_rdf_url (in vhost varchar, in lhost varchar) for wa_mail
{
  declare domainID, userID integer;

  domainID := self.wa_id ();
  userID := OMAIL.WA.domain_owner_id (domainID);
  return sprintf('http://' || DB.DBA.http_get_host () || '/oMail/res/export.vsp?output=about&did=%d&uid=%d', domainID, userID);
}
;

-------------------------------------------------------------------------------
--
create procedure OMAIL.WA.path_upgrade ()
{
  if (registry_get ('omail_path_upgrade2') = '1')
    return;

  for (select WAI_ID from DB.DBA.WA_INSTANCE where WAI_TYPE_NAME = 'oMail') do
  {
    for (select HP_LPATH as _lpath,
                HP_HOST as _vhost,
                HP_LISTEN_HOST as _lhost
           from DB.DBA.HTTP_PATH
          where HP_LPATH = '/oMail/' || cast (WAI_ID as varchar) || '/box.vsp') do
    {
      VHOST_REMOVE (vhost=>_vhost, lhost=>_lhost, lpath=>_lpath);
    }
  }
  registry_set ('omail_path_upgrade2', '1');
}
;
OMAIL.WA.path_upgrade ();
