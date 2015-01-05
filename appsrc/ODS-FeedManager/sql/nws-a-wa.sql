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

-- ---------------------------------------------------
-- eNews 'Users' code generation file.
-- ---------------------------------------------------

------------------------------------------------------------------------------
create procedure ENEWS.WA.exec_no_error (
  in expr varchar,
  in execType varchar := '',
  in execTable varchar := '',
  in execColumn varchar := '')
{
  declare
    state,
    message,
    meta,
    result any;

  log_enable(1);
  if (execType = 'C') {
    if (coalesce((select 1 from DB.DBA.SYS_COLS where (0=casemode_strcmp("COLUMN", execColumn)) and (0=casemode_strcmp ("TABLE", execTable))), 0))
      goto _end;
  }
  if (execType = 'D') {
    if (not coalesce((select 1 from DB.DBA.SYS_COLS where (0=casemode_strcmp("COLUMN", execColumn)) and (0=casemode_strcmp ("TABLE", execTable))), 0))
      goto _end;
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
_end:
  return;
}
;

------------------------------------------------------------------------------
--
create procedure ENEWS.WA.vhost()
{
  declare
    iIsDav integer;
  declare
    sHost varchar;

  -- Add a virtual directory for OFM - public www -------------------------
  sHost := registry_get('_enews2_path_');
  if (cast(sHost as varchar) = '0')
    sHost := '/apps/enews2/';
  iIsDav := 1;
  if (isnull(strstr(sHost, '/DAV')))
    iIsDav := 0;
  VHOST_REMOVE(lpath    => '/enews2');
  VHOST_REMOVE(lpath    => '/subscriptions');
  VHOST_DEFINE(lpath    => '/subscriptions',
               ppath    => concat(sHost, 'www/'),
               is_dav   => iIsDav,
               is_brws  => 0,
               vsp_user => 'dba',
               realm    => 'wa',
               def_page => 'news.vspx'
             );
}
;

ENEWS.WA.vhost();

-------------------------------------------------------------------------------
--
-- Insert data
--
-------------------------------------------------------------------------------
ENEWS.WA.exec_no_error ('insert replacing WA_TYPES(WAT_NAME, WAT_TYPE, WAT_REALM, WAT_DESCRIPTION) values (\'eNews2\', \'db.dba.wa_eNews2\', \'wa\', \'Feed Manager Application\')')
;
ENEWS.WA.exec_no_error ('insert replacing WA_MEMBER_TYPE (WMT_APP, WMT_NAME, WMT_ID, WMT_IS_DEFAULT) values (\'eNews2\', \'owner\', 1, 0)')
;
ENEWS.WA.exec_no_error ('insert replacing WA_MEMBER_TYPE (WMT_APP, WMT_NAME, WMT_ID, WMT_IS_DEFAULT) values (\'eNews2\', \'author\', 2, 0)')
;
ENEWS.WA.exec_no_error ('insert replacing WA_MEMBER_TYPE (WMT_APP, WMT_NAME, WMT_ID, WMT_IS_DEFAULT) values (\'eNews2\', \'reader\', 3, 0)')
;

-------------------------------------------------------------------------------
--
-- create new eNews application in WA
--
-- eNews class
--
ENEWS.WA.exec_no_error ('
  create type wa_eNews2 under web_app as (
      eNewsID varchar,
  	  owner integer
  	)
    constructor method wa_eNews2(stream any),
    overriding method wa_id_string() returns any,
    overriding method wa_new_inst(login varchar) returns any,
    overriding method wa_front_page(stream any) returns any,
    overriding method wa_state_edit_form(stream any) returns any,
    overriding method wa_home_url() returns varchar,
    overriding method wa_drop_instance() returns any,
    overriding method wa_notify_member_changed(account int, otype int, ntype int, odata any, ndata any, ostatus any, nstatus any) returns any,
    overriding method wa_class_details() returns varchar
'
)
;

ENEWS.WA.exec_no_error (
  'alter type wa_eNews2 drop method wa_membership_edit_form (stream any) returns any'
)
;

ENEWS.WA.exec_no_error (
  'alter type wa_eNews2 add overriding method wa_front_page_as_user(inout stream any, in user_name varchar) returns any'
)
;

ENEWS.WA.exec_no_error (
  'alter type wa_eNews2 add overriding method wa_size() returns int'
)
;

ENEWS.WA.exec_no_error (
  'alter type wa_eNews2 add method wa_vhost_options () returns any'
)
;

ENEWS.WA.exec_no_error (
  'alter type wa_eNews2 add method get_param (in param varchar) returns any'
)
;

ENEWS.WA.exec_no_error (
  'alter type wa_eNews2 add overriding method wa_dashboard () returns any'
)
;

ENEWS.WA.exec_no_error (
  'alter type wa_eNews2 add method wa_dashboard_last_item () returns any'
)
;

ENEWS.WA.exec_no_error (
  'alter type wa_eNews2 add overriding method wa_rdf_url (in vhost varchar, in lhost varchar) returns varchar'
)
;

ENEWS.WA.exec_no_error (
  'alter type wa_eNews2 add overriding method wa_addition_urls () returns any'
)
;

ENEWS.WA.exec_no_error (
  'alter type wa_eNews2 add overriding method wa_update_instance (in oldValues any, in newValues any) returns any'
)
;

-------------------------------------------------------------------------------
--
-- wa_eNews2 methods
--
-------------------------------------------------------------------------------
--
create constructor method wa_eNews2 (inout stream any) for wa_eNews2
{
  return;
}
;

-------------------------------------------------------------------------------
--
create method wa_id_string() for wa_eNews2
{
  return self.eNewsID;
}
;

-------------------------------------------------------------------------------
--
create method wa_drop_instance () for wa_eNews2
{
  for (select HP_LPATH as _lpath,
              HP_HOST as _vhost,
              HP_LISTEN_HOST as _lhost
         from DB.DBA.HTTP_PATH
        where HP_LPATH = '/enews2/' || self.eNewsID) do
  {
    VHOST_REMOVE (vhost=>_vhost, lhost=>_lhost, lpath=>_lpath);
  }
  ENEWS.WA.domain_delete(self.eNewsID);
  (self as web_app).wa_drop_instance();
}
;

-------------------------------------------------------------------------------
--
create method wa_notify_member_changed(in account int, in otype int, in ntype int, in odata any, in ndata any, in ostatus any, in nstatus any) for wa_eNews2
{
  if (isnull(ntype))
    ENEWS.WA.account_delete(self.eNewsID, account);
  return (self as web_app).wa_notify_member_changed(account, otype, ntype, odata, ndata, ostatus, nstatus);
}
;

-------------------------------------------------------------------------------
--
-- owner makes a new eNews
--
create method wa_new_inst (in login varchar) for wa_eNews2
{
  declare ownerID, domainID integer;

  ownerID := (select U_ID from DB.DBA.SYS_USERS where U_NAME = login);
  if (self.wa_member_model is null)
    self.wa_member_model := 0;

  self.owner := ownerID;

  insert into WA_INSTANCE (WAI_NAME, WAI_TYPE_NAME, WAI_INST, WAI_DESCRIPTION)
  	values (self.wa_name, 'eNews2', self, 'Description');

  select WAI_ID into domainID from WA_INSTANCE where WAI_NAME = self.wa_name;
  self.eNewsID := cast(domainID as varchar);
  update WA_INSTANCE set WAI_INST = self where WAI_ID = domainID;

  -- Add a virtual directory for eNews - public www -------------------------
  VHOST_REMOVE(lpath    => concat('/enews2/', self.eNewsID));
  VHOST_DEFINE(lpath    => concat('/enews2/', self.eNewsID),
               ppath    => concat(self.get_param('host'), 'www/'),
               ses_vars => 1,
               is_dav   => self.get_param('isDAV'),
               vsp_user => 'dba',
               realm    => 'wa',
               def_page => 'news.vsp',
               opts     => vector ('domain', self.eNewsID)
             );

  ENEWS.WA.domain_update (domainID, ownerID);

  return (self as web_app).wa_new_inst(login);
}
;

-------------------------------------------------------------------------------
--
create method wa_class_details() for wa_eNews2
{
	return 'The Virtuoso eNews Application allows you to run an online diary system. Like a diary it can be a private system, however in the spirit of weblog these are often public for outsides to pass comment.  Weblog supports community based operation to keep groups of weblogs together for collaboration of friends or fellow members of an organization department.';
}
;

-------------------------------------------------------------------------------
--
create method wa_front_page(inout stream any) for wa_eNews2
{
  declare sSid varchar;

  sSid := (select VS_SID from VSPX_SESSION where VS_REALM = 'wa' and VS_UID = connection_get('vspx_user'));
  http_request_status ('HTTP/1.1 302 Found');
  http_header(sprintf('Location: %s?sid=%s&realm=%s\r\n', self.wa_home_url(), sSid, 'wa'));
}
;

-------------------------------------------------------------------------------
--
create method wa_state_edit_form(inout stream any) for wa_eNews2
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
    http_header(sprintf('Location: %s?sid=%s&realm=%s\r\n', WS.WS.EXPAND_URL(self.wa_home_url(), 'settings.vspx'), sSid, 'wa'));
  } else {
    signal('42001', 'Not a owner');
  }
}
;

-------------------------------------------------------------------------------
--
create method wa_home_url () for wa_eNews2
{
  return concat('/enews2/', self.eNewsID, '/news.vsp');
}
;

-------------------------------------------------------------------------------
--
create method wa_front_page_as_user (inout stream any, in user_name varchar) for wa_eNews2
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
create method wa_size () for wa_eNews2
{
  return 0;
}
;


-------------------------------------------------------------------------------
--
create method wa_vhost_options () for wa_eNews2
{
  return vector (
           self.get_param('host') || 'www/', -- physical home
           'news.vsp',                       -- default page
           'dba',                            -- user for execution
           0,                                -- directory browsing enabled (flag 0/1)
           self.get_param('isDAV'),          -- WebDAV repository  (flag 0/1)
           vector ('domain', self.eNewsID),  -- virtual directory options, empty is not applicable
           null,                             -- post-processing function (null is not applicable)
           null                              -- pre-processing (authentication) function
         );
}
;

-------------------------------------------------------------------------------
--
create method get_param (in param varchar) for wa_eNews2
{
  declare retValue any;

  retValue := null;
  if (param = 'host') {
    retValue := registry_get('_enews2_path_');
    if (cast(retValue as varchar) = '0')
      retValue := '/apps/enews2/';
  } if (param = 'isDAV') {
    retValue := 1;
    if (isnull(strstr(self.get_param('host'), '/DAV')))
      retValue := 0;
  }
  return retValue;
}
;

-------------------------------------------------------------------------------
--
create method wa_dashboard () for wa_eNews2
{
  declare iWaiID integer;

  iWaiID := cast (self.eNewsID as integer);
  return (select XMLAGG ( XMLELEMENT ( 'dash-row',
                                       XMLATTRIBUTES ( 'normal' as "class",
                                                       ENEWS.WA.dt_format(_time, 'Y/M/D H:N') as "time",
                                                       self.wa_name as "application"
                                                      ),
                                       XMLELEMENT ( 'dash-data',
	                                                  XMLATTRIBUTES ( concat (N'<a href="', cast (SIOC..feed_item_iri (_feed_id, _id) as nvarchar), N'">', ENEWS.WA.utf2wide (_title), N'</a>') as "content",
	                                                                  0 as "comments"
	                                                                )
                                          	      )
                                     )
                     	  )
            from ENEWS.WA.dashboard_rs(p0)(_feed_id integer, _id integer, _title varchar, _time datetime, _autor varchar, _mail varchar) x
           where p0 = iWaiID
         );
}
;

-------------------------------------------------------------------------------
--
create method wa_dashboard_last_item () for wa_eNews2
{
  return ENEWS.WA.dashboard_get (cast (self.eNewsID as integer));
}
;

-------------------------------------------------------------------------------
--
create method wa_rdf_url (in vhost varchar, in lhost varchar) for wa_eNews2
{
  declare domainID, ownerID integer;

  domainID := cast (self.eNewsID as integer);
  ownerID := ENEWS.WA.domain_owner_id (domainID);
  return concat(ENEWS.WA.dav_url2 (domainID, ownerID), 'OFM.rdf');
}
;


-------------------------------------------------------------------------------
--
create method wa_addition_urls () for wa_eNews2
{
  return vector (
    vector (null, null, '/subscriptions', self.get_param ('host')||'www/', self.get_param ('isDAV'), 0, 'news.vspx', null, 'wa', null, 'dba', null, null, 0, null, null, null, 0)
  );
}
;

-------------------------------------------------------------------------------
--
create method wa_update_instance (in oldValues any, in newValues any) for wa_eNews2
{
  declare domainID, ownerID integer;

  domainID := (select WAI_ID from DB.DBA.WA_INSTANCE where WAI_NAME = newValues[0]);
  ownerID := (select WAM_USER from WA_MEMBER B where WAM_INST = oldValues[0] and WAM_MEMBER_TYPE = 1);

  ENEWS.WA.domain_gems_delete (domainID, ownerID, oldValues[0] || '_Gems');
  ENEWS.WA.domain_gems_create (domainID, ownerID);
  ENEWS.WA.nntp_update (domainID, ENEWS.WA.domain_nntp_name2 (oldValues[0], ENEWS.WA.account_name (ownerID)), ENEWS.WA.domain_nntp_name2 (newValues[0], ENEWS.WA.account_name (ownerID)));

  return (self as web_app).wa_update_instance (oldValues, newValues);
}
;

-------------------------------------------------------------------------------
--
create procedure ENEWS.WA.path_upgrade ()
{
  declare _new_lpath varchar;

  if (registry_get ('news_path_upgrade2') = '1')
    return;

  for (select WAI_ID from DB.DBA.WA_INSTANCE where WAI_TYPE_NAME = 'eNews2') do
  {
    for (select HP_LPATH as _lpath,
                HP_HOST as _vhost,
                HP_LISTEN_HOST as _lhost
           from DB.DBA.HTTP_PATH
          where HP_LPATH = '/enews2/' || cast (WAI_ID as varchar) || '/news.vsp') do
    {
      _new_lpath := '/enews2/' || cast (WAI_ID as varchar);
      if (exists (select 1 from DB.DBA.HTTP_PATH where HP_LPATH = _new_lpath and HP_HOST  = _vhost and HP_LISTEN_HOST = _lhost))
      {
        VHOST_REMOVE (vhost=>_vhost, lhost=>_lhost, lpath=>_lpath);
      } else {
        update DB.DBA.HTTP_PATH
           set HP_LPATH = _new_lpath
         where HP_LPATH = _lpath
           and HP_HOST  = _vhost
           and HP_LISTEN_HOST = _lhost;
        http_map_del (_lpath, _vhost, _lhost);
        VHOST_MAP_RELOAD (vhost=>_vhost, lhost=>_lhost, lpath=>_new_lpath);
      }
    }
  }
  registry_set ('news_path_upgrade2', '1');
}
;
ENEWS.WA.path_upgrade ();
