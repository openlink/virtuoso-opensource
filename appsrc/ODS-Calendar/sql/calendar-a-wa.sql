--
--  $Id$
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2007 OpenLink Software
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
-- Calendar 'Users' code generation file.
-- ---------------------------------------------------

------------------------------------------------------------------------------
create procedure CAL.WA.exec_no_error(in expr varchar, in execType varchar := '', in execTable varchar := '', in execColumn varchar := '')
{
  declare
    state,
    message,
    meta,
    result any;

  log_enable(1);
  if (execType = 'C') {
    if (coalesce((select 1 from DB.DBA.SYS_COLS where (0=casemode_strcmp("COLUMN", execColumn)) and (0=casemode_strcmp ("TABLE", execTable))), 0))
      return;
  }
  if (execType = 'D') {
    if (not coalesce((select 1 from DB.DBA.SYS_COLS where (0=casemode_strcmp("COLUMN", execColumn)) and (0=casemode_strcmp ("TABLE", execTable))), 0))
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

------------------------------------------------------------------------------
--
create procedure CAL.WA.atom_lpath (
  in domain_id integer)
{
  return sprintf ('/calendar/%d/atom-pub', domain_id);
}
;

------------------------------------------------------------------------------
--
create procedure CAL.WA.atom_lpath2 (
  in domain_id integer)
{
  return CAL.WA.domain_sioc_url (domain_id) || '/atom-pub';
}
;

------------------------------------------------------------------------------
--
create procedure CAL.WA.vhost()
{
  declare
    iIsDav integer;
  declare
    sHost varchar;

  -- Add a virtual directory for Calendar - public www -------------------------
  sHost := registry_get('calendar_path');
  if (cast(sHost as varchar) = '0')
    sHost := '/apps/calendar/';
  iIsDav := 1;
  if (isnull(strstr(sHost, '/DAV')))
    iIsDav := 0;
  VHOST_REMOVE(lpath    => '/calendar');
  DB.DBA.URLREWRITE_CREATE_REGEX_RULE (
    'ods_rule_calendar',
    1,
    '/calendar',
    vector (),
    0,
    '/dataspace/all/calendar',
    vector (),
    NULL,
    NULL,
    2,
    303
  );
  DB.DBA.URLREWRITE_CREATE_RULELIST ('ods_rulelist_calendar', 1, vector ('ods_rule_calendar'));
  VHOST_DEFINE(lpath    => '/calendar',
               ppath    => '/DAV/VAD/wa/',
               is_dav   => 1,
               is_brws  => 0,
               vsp_user => 'dba',
               opts     => vector ('url_rewrite', 'ods_rulelist_calendar')
             );

  USER_CREATE ('SOAP_CALENDAR', md5 (cast (now() as varchar)), vector ('DISABLED', 1));
  USER_SET_QUALIFIER ('SOAP_CALENDAR', 'DBA');
  VHOST_REMOVE (lpath     => '/calendar/atom-pub');
  VHOST_DEFINE (lpath     => '/calendar/atom-pub',
                ppath     => '/SOAP/Http/gdata',
                soap_user => 'SOAP_CALENDAR',
                opts      => vector ('atom-pub', 1)
               );
}
;

CAL.WA.vhost();

-------------------------------------------------------------------------------
--
-- Insert data
--
-------------------------------------------------------------------------------
CAL.WA.exec_no_error('insert replacing WA_TYPES(WAT_NAME, WAT_TYPE, WAT_REALM, WAT_DESCRIPTION) values (\'Calendar\', \'db.dba.wa_Calendar\', \'wa\', \'Calendar Application\')')
;
CAL.WA.exec_no_error('insert replacing WA_MEMBER_TYPE (WMT_APP, WMT_NAME, WMT_ID, WMT_IS_DEFAULT) values (\'Calendar\', \'owner\', 1, 0)')
;
CAL.WA.exec_no_error('insert replacing WA_MEMBER_TYPE (WMT_APP, WMT_NAME, WMT_ID, WMT_IS_DEFAULT) values (\'Calendar\', \'author\', 2, 0)')
;
CAL.WA.exec_no_error('insert replacing WA_MEMBER_TYPE (WMT_APP, WMT_NAME, WMT_ID, WMT_IS_DEFAULT) values (\'Calendar\', \'reader\', 3, 0)')
;

-------------------------------------------------------------------------------
--
-- create new Calendar Application in WA
--
-- Calendar class
--
CAL.WA.exec_no_error('
  create type db.dba.wa_Calendar under web_app
    constructor method wa_Calendar (stream any),
    overriding method wa_id () returns any,
    overriding method wa_new_inst (login varchar) returns any,
    overriding method wa_front_page (stream any) returns any,
    overriding method wa_state_edit_form(stream any) returns any,
    overriding method wa_home_url () returns varchar,
    overriding method wa_drop_instance () returns any,
    overriding method wa_notify_member_changed(account int, otype int, ntype int, odata any, ndata any, ostatus any, nstatus any) returns any,
    overriding method wa_class_details () returns varchar,
    overriding method wa_front_page_as_user(inout stream any, in user_name varchar) returns any,
    overriding method wa_rdf_url (in vhost varchar, in lhost varchar) returns varchar,
    method wa_dashboard_last_item () returns any,
    method wa_vhost_options () returns any,
    method get_param (in param varchar) returns any
'
)
;

CAL.WA.exec_no_error (
  'alter type wa_Calendar add overriding method wa_addition_urls () returns any'
)
;

CAL.WA.exec_no_error (
  'alter type wa_Calendar add overriding method wa_update_instance (in oldValues any, in newValues any) returns any'
)
;

-------------------------------------------------------------------------------
--
-- wa_Calendar methods
--
-------------------------------------------------------------------------------
--
create constructor method wa_Calendar (inout stream any) for wa_Calendar
{
  return;
}
;

-------------------------------------------------------------------------------
--
create method wa_id () for wa_Calendar
{
  return (select WAI_ID from WA_INSTANCE where WAI_NAME = self.wa_name);
}
;

-------------------------------------------------------------------------------
--
create method wa_drop_instance () for wa_Calendar
{
  CAL.WA.domain_delete (self.wa_id ());
  (self as web_app).wa_drop_instance ();
}
;

-------------------------------------------------------------------------------
--
create method wa_notify_member_changed(in account int, in otype int, in ntype int, in odata any, in ndata any, in ostatus any, in nstatus any) for wa_Calendar
{
  if (isnull (ntype))
    CAL.WA.account_delete (self.wa_id (), account);

  return (self as web_app).wa_notify_member_changed (account, otype, ntype, odata, ndata, ostatus, nstatus);
}
;

-------------------------------------------------------------------------------
--
-- owner makes a new Calendar
--
create method wa_new_inst (in login varchar) for wa_Calendar
{
  declare iUserID, iWaiID integer;
  declare retValue any;

  iUserID := (select U_ID from DB.DBA.SYS_USERS where U_NAME = login);
  if (isnull (iUserID))
    signal('EN001', 'not a Virtuoso WA user');

  if (self.wa_member_model is null)
    self.wa_member_model := 0;

  insert into WA_INSTANCE (WAI_NAME, WAI_TYPE_NAME, WAI_INST, WAI_DESCRIPTION)
    values (self.wa_name, 'Calendar', self, 'Description');

  select WAI_ID into iWaiID from WA_INSTANCE where WAI_NAME = self.wa_name;
  iWaiID := self.wa_id ();

  -- Add a virtual directory for Calendar - public www -------------------------
  VHOST_REMOVE(lpath    => '/calendar/' || cast (iWaiID as varchar));
  VHOST_DEFINE(lpath    => '/calendar/' || cast (iWaiID as varchar),
               ppath    => self.get_param ('host') || 'www/',
               ses_vars => 1,
               is_dav   => self.get_param('isDAV'),
               is_brws  => 0,
               vsp_user => 'dba',
               realm    => 'wa',
               def_page => 'home.vspx',
               opts     => vector ('domain', iWaiID)
             );

  CAL.WA.domain_update (iWaiID, iUserID);
  retValue := (self as web_app).wa_new_inst(login);

  --  SIOC service
  declare  graph_iri, iri, c_iri varchar;

  graph_iri := SIOC..get_graph ();
	c_iri := SIOC..calendar_iri (self.wa_name);
  iri := sprintf ('http://%s%s/%U/calendar/%U/atom-pub', SIOC..get_cname(), SIOC..get_base_path (), login, self.wa_name);
  SIOC..ods_sioc_service (graph_iri, iri, c_iri, null, null, null, iri, 'Atom');

  return retValue;
}
;

-------------------------------------------------------------------------------
--
create method wa_class_details() for wa_Calendar
{
  return 'The Virtuoso Calendar Application allows you to create and maintain contacts.';
}
;

-------------------------------------------------------------------------------
--
create method wa_front_page (inout stream any) for wa_Calendar
{
  declare sid varchar;

  sid := (select VS_SID from VSPX_SESSION where VS_REALM = 'wa' and VS_UID = connection_get('vspx_user'));
  http_request_status ('HTTP/1.1 302 Found');
  http_header(sprintf('Location: %s?sid=%s&realm=%s\r\n', self.wa_home_url (), sid, 'wa'));
  return;
}
;

-------------------------------------------------------------------------------
--
create method wa_state_edit_form (inout stream any) for wa_Calendar
{
  declare sid varchar;

  if (exists(select 1
               from SYS_USERS A,
                    WA_MEMBER B
              where A.U_NAME = connection_get ('vspx_user')
                and B.WAM_USER = A.U_ID
                and B.WAM_INST= self.wa_name
                and B.WAM_MEMBER_TYPE = 1))
  {
    sid := (select VS_SID from VSPX_SESSION where VS_REALM = 'wa' and VS_UID = connection_get('vspx_user'));
    http_request_status ('HTTP/1.1 302 Found');
    http_header(sprintf('Location: %s?sid=%s&realm=%s&action=settings\r\n', self.wa_home_url(), sid, 'wa'));
  } else {
    signal('42001', 'Not a owner');
  }
  return;
}
;

-------------------------------------------------------------------------------
--
create method wa_home_url () for wa_Calendar
{
  return concat('/calendar/', cast (self.wa_id () as varchar), '/home.vspx');
}
;

-------------------------------------------------------------------------------
--
create method wa_front_page_as_user (inout stream any, in user_name varchar) for wa_Calendar
{
  declare sSid, sOwner varchar;

  sOwner := (select TOP 1 U_NAME from SYS_USERS A, WA_MEMBER B where B.WAM_USER = A.U_ID and B.WAM_INST= self.wa_name and B.WAM_MEMBER_TYPE = 1);
  sSid := md5 (concat (datestring (now ()), http_client_ip (), http_path ()));
  insert into DB.DBA.VSPX_SESSION (VS_REALM, VS_SID, VS_UID, VS_STATE, VS_EXPIRY)
    values ('wa', sSid, sOwner, serialize ( vector ('vspx_user', user_name, 'owner_user', sOwner)), now());
  http_request_status ('HTTP/1.1 302 Found');
  http_header(sprintf('Location: %s?sid=%s&realm=%s\r\n', self.wa_home_url (), sSid, 'wa'));
  return;
}
;

-------------------------------------------------------------------------------
--
create method wa_vhost_options () for wa_Calendar
{
  return vector (
           self.get_param('host') || 'www/', -- physical home
           'home.vspx',                      -- default page
           'dba',                            -- user for execution
           0,                                -- directory browsing enabled (flag 0/1)
           self.get_param('isDAV'),          -- WebDAV repository  (flag 0/1)
           vector ('domain', self.wa_id ()), -- virtual directory options, empty is not applicable
           null,                             -- post-processing function (null is not applicable)
           null                              -- pre-processing (authentication) function
         );
}
;

-------------------------------------------------------------------------------
--
create method get_param (in param varchar) for wa_Calendar
{
  declare retValue any;

  retValue := null;
  if (param = 'host')
  {
    retValue := registry_get('calendar_path');
    if (cast(retValue as varchar) = '0')
      retValue := '/apps/Calendar/';
  }
  if (param = 'isDAV')
  {
    retValue := 1;
    if (isnull(strstr(self.get_param('host'), '/DAV')))
      retValue := 0;
  }
  return retValue;
}
;

-------------------------------------------------------------------------------
--
create method wa_dashboard_last_item () for wa_Calendar
{
  declare domainID, userID integer;

  domainID := (select WAI_ID from DB.DBA.WA_INSTANCE where WAI_NAME = self.wa_name);
  userID := (select WAM_USER from WA_MEMBER B where WAM_INST = self.wa_name and WAM_MEMBER_TYPE = 1);
  return CAL.WA.dashboard_get (domainID, userID);
}
;

-------------------------------------------------------------------------------
--
create method wa_rdf_url (in vhost varchar, in lhost varchar) for wa_Calendar
{
  declare domainID, userID integer;

  domainID := (select WAI_ID from DB.DBA.WA_INSTANCE where WAI_NAME = self.wa_name);
  userID := (select WAM_USER from WA_MEMBER B where WAM_INST= self.wa_name and WAM_MEMBER_TYPE = 1);

  return concat(CAL.WA.dav_url2(domainID, userID), 'Calendar.rdf');
}
;

-------------------------------------------------------------------------------
--
create method wa_addition_urls () for wa_Calendar
{
  return vector (
    vector (null, null, '/calendar',          '/DAV/VAD/wa/',     1, 0, null, null, null, null, 'dba', null, null, 0, null, null, vector ('url_rewrite', 'ods_rulelist_calendar'), 0),
    vector (null, null, '/calendar/atom-pub', '/SOAP/Http/gdata', 0, 0, null, null, null, null,  null, 'SOAP_CALENDAR', null, 1, vector ('atom-pub', 1), null, null, 0)
  );
}
;

-------------------------------------------------------------------------------
--
create method wa_update_instance (in oldValues any, in newValues any) for wa_Calendar
{
  declare domainID, ownerID integer;

  domainID := (select WAI_ID from DB.DBA.WA_INSTANCE where WAI_NAME = newValues[0]);
  ownerID := (select WAM_USER from WA_MEMBER B where WAM_INST = oldValues[0] and WAM_MEMBER_TYPE = 1);

  CAL.WA.domain_gems_delete (domainID, ownerID, 'Calendar Gems', oldValues[0]);
  CAL.WA.domain_gems_create (domainID, ownerID);

  return (self as web_app).wa_update_instance (oldValues, newValues);
}
;
