--
--  $Id$
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2017 OpenLink Software
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
-- AddressBook 'Users' code generation file.
-- ---------------------------------------------------

------------------------------------------------------------------------------
create procedure AB.WA.exec_no_error(in expr varchar, in execType varchar := '', in execTable varchar := '', in execColumn varchar := '')
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
      if (not isnull (result[0][0]))
        maxID := result[0][0] + 1;

    expr := sprintf(expr, maxID);
  }
  exec(expr, state, message, vector(), 0, meta, result);
}
;

------------------------------------------------------------------------------
--
create procedure AB.WA.vhost()
{
  declare
    iIsDav integer;
  declare
    sHost varchar;

  -- Add a virtual directory for AddressBook - public www -------------------------
  sHost := registry_get('ab_path');
  if (cast(sHost as varchar) = '0')
    sHost := '/apps/addressbook/';
  iIsDav := 1;
  if (isnull (strstr(sHost, '/DAV')))
    iIsDav := 0;

  DB.DBA.URLREWRITE_CREATE_REGEX_RULE (
    'ods_rule_addressbook',
    1,
    '/addressbook',
    vector (),
    0,
    '/dataspace/all/addressbook',
    vector (),
    NULL,
    NULL,
    2,
    303
  );
  DB.DBA.URLREWRITE_CREATE_RULELIST ('ods_rulelist_addressbook', 1, vector ('ods_rule_addressbook'));

  USER_CREATE ('SOAP_ADDRESSBOOK', md5 (cast (now() as varchar)), vector ('DISABLED', 1));
  USER_SET_QUALIFIER ('SOAP_ADDRESSBOOK', 'DBA');

  VHOST_REMOVE(lpath    => '/addressbook');
  VHOST_DEFINE(lpath    => '/addressbook',
               ppath    => '/DAV/VAD/wa/',
               is_dav   => 1,
               is_brws  => 0,
               vsp_user => 'dba',
               opts     => vector ('url_rewrite', 'ods_rulelist_addressbook')
             );
  VHOST_REMOVE (lpath     => '/ods/portablecontacts');
  VHOST_DEFINE (lpath     => '/ods/portablecontacts',
                ppath     => '/SOAP/Http/portablecontacts',
                soap_user => 'SOAP_ADDRESSBOOK',
                opts      => vector ('atom-pub', 1)
               );

  VHOST_REMOVE (lpath     => '/ods/livecontacts');
  VHOST_DEFINE (lpath     => '/ods/livecontacts',
                ppath     => '/SOAP/Http/livecontacts',
                soap_user => 'SOAP_ADDRESSBOOK',
                opts      => vector ('atom-pub', 1)
               );

  VHOST_REMOVE (lpath     => '/ods/yahoocontacts');
  VHOST_DEFINE (lpath     => '/ods/yahoocontacts',
                ppath     => '/SOAP/Http/yahoocontacts',
                soap_user => 'SOAP_ADDRESSBOOK',
                opts      => vector ('atom-pub', 1)
               );

  VHOST_REMOVE (lpath     => '/ods/google');
  VHOST_DEFINE (lpath     => '/ods/google',
                ppath     => '/SOAP/Http/googlecontacts',
                soap_user => 'SOAP_ADDRESSBOOK',
                opts      => vector ('atom-pub', 1)
               );

  -- old SOAP
  -- api url
  VHOST_REMOVE (lpath => '/dataspace/services/addressbook');
  -- procs
  AB.WA.exec_no_error ('DROP procedure DBA.DB.addressbook_import');
  AB.WA.exec_no_error ('DROP procedure DBA.DB.addressbook_export');
}
;

AB.WA.vhost();

-------------------------------------------------------------------------------
--
-- Insert data
--
-------------------------------------------------------------------------------
AB.WA.exec_no_error('insert replacing WA_TYPES(WAT_NAME, WAT_TYPE, WAT_REALM, WAT_DESCRIPTION) values (\'AddressBook\', \'db.dba.wa_AddressBook\', \'wa\', \'AddressBook Application\')')
;
AB.WA.exec_no_error('insert replacing WA_MEMBER_TYPE (WMT_APP, WMT_NAME, WMT_ID, WMT_IS_DEFAULT) values (\'AddressBook\', \'owner\', 1, 0)')
;
AB.WA.exec_no_error('insert replacing WA_MEMBER_TYPE (WMT_APP, WMT_NAME, WMT_ID, WMT_IS_DEFAULT) values (\'AddressBook\', \'author\', 2, 0)')
;
AB.WA.exec_no_error('insert replacing WA_MEMBER_TYPE (WMT_APP, WMT_NAME, WMT_ID, WMT_IS_DEFAULT) values (\'AddressBook\', \'reader\', 3, 0)')
;

-------------------------------------------------------------------------------
--
-- create new AddressBook Application in WA
--
-- AddressBook class
--
AB.WA.exec_no_error('
  create type db.dba.wa_AddressBook under web_app
    constructor method wa_AddressBook (stream any),
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

AB.WA.exec_no_error (
  'alter type wa_AddressBook add overriding method wa_addition_urls () returns any'
)
;

AB.WA.exec_no_error (
  'alter type wa_AddressBook add overriding method wa_update_instance (in oldValues any, in newValues any) returns any'
)
;

AB.WA.exec_no_error (
  'alter type wa_AddressBook add overriding method wa_dashboard () returns any'
)
;

-------------------------------------------------------------------------------
--
-- wa_AddressBook methods
--
-------------------------------------------------------------------------------
--
create constructor method wa_AddressBook (inout stream any) for wa_AddressBook
{
  return;
}
;

-------------------------------------------------------------------------------
--
create method wa_id () for wa_AddressBook
{
  return (select WAI_ID from WA_INSTANCE where WAI_NAME = self.wa_name);
}
;

-------------------------------------------------------------------------------
--
create method wa_drop_instance () for wa_AddressBook
{
  declare iWaiID integer;

  iWaiID := self.wa_id ();
  for (select HP_LPATH as _lpath,
              HP_HOST as _vhost,
              HP_LISTEN_HOST as _lhost
         from DB.DBA.HTTP_PATH
        where HP_LPATH = '/addressbook/' || cast (iWaiID as varchar)) do
  {
    VHOST_REMOVE (vhost=>_vhost, lhost=>_lhost, lpath=>_lpath);
  }
  AB.WA.domain_delete (iWaiID);
  (self as web_app).wa_drop_instance ();
}
;

-------------------------------------------------------------------------------
--
create method wa_notify_member_changed(in account int, in otype int, in ntype int, in odata any, in ndata any, in ostatus any, in nstatus any) for wa_AddressBook
{
  if (isnull (ntype))
    AB.WA.account_delete (self.wa_id (), account);

  return (self as web_app).wa_notify_member_changed (account, otype, ntype, odata, ndata, ostatus, nstatus);
}
;

-------------------------------------------------------------------------------
--
-- owner makes a new AddressBook
--
create method wa_new_inst (in login varchar) for wa_AddressBook
{
  declare iUserID, iWaiID integer;
  declare retValue any;


  iUserID := (select U_ID from DB.DBA.SYS_USERS where U_NAME = login);
  if (isnull (iUserID))
    signal('EN001', 'not a Virtuoso WA user');

  if (self.wa_member_model is null)
    self.wa_member_model := 0;

  insert into WA_INSTANCE (WAI_NAME, WAI_TYPE_NAME, WAI_INST, WAI_DESCRIPTION)
    values (self.wa_name, 'AddressBook', self, 'Description');
  iWaiID := self.wa_id ();

  -- Add a virtual directory for AddressBook - public www -------------------------
  VHOST_REMOVE(lpath    => '/addressbook/' || cast (iWaiID as varchar));
  VHOST_DEFINE(lpath    => '/addressbook/' || cast (iWaiID as varchar),
               ppath    => self.get_param ('host') || 'www/',
               ses_vars => 1,
               is_dav   => self.get_param('isDAV'),
               is_brws  => 0,
               vsp_user => 'dba',
               realm    => 'wa',
               def_page => 'home.vspx',
               opts     => vector ('domain', iWaiID)
             );

  AB.WA.domain_update (iWaiID, iUserID);
  retValue := (self as web_app).wa_new_inst(login);

  return retValue;
}
;

-------------------------------------------------------------------------------
--
create method wa_class_details() for wa_AddressBook
{
  return 'The Virtuoso AddressBook Application allows you to create and maintain contacts.';
}
;

-------------------------------------------------------------------------------
--
create method wa_front_page (inout stream any) for wa_AddressBook
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
create method wa_state_edit_form (inout stream any) for wa_AddressBook
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
    http_header(sprintf('Location: %s?action=settings&sid=%s&realm=%s\r\n', WS.WS.EXPAND_URL (self.wa_home_url(), 'home.vspx'), sid, 'wa'));
  } else {
    signal('42001', 'Not a owner');
  }
  return;
}
;

-------------------------------------------------------------------------------
--
create method wa_home_url () for wa_AddressBook
{
  return concat('/addressbook/', cast (self.wa_id () as varchar), '/home.vspx');
}
;

-------------------------------------------------------------------------------
--
create method wa_front_page_as_user (inout stream any, in user_name varchar) for wa_AddressBook
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
create method wa_vhost_options () for wa_AddressBook
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
create method get_param (in param varchar) for wa_AddressBook
{
  declare retValue any;

  retValue := null;
  if (param = 'host') {
    retValue := registry_get('ab_path');
    if (cast(retValue as varchar) = '0')
      retValue := '/apps/AddressBook/';
  }
  else if (param = 'isDAV')
  {
    retValue := 1;
    if (isnull (strstr (self.get_param ('host'), '/DAV')))
      retValue := 0;
  }
  return retValue;
}
;

-------------------------------------------------------------------------------
--
create method wa_dashboard () for wa_AddressBook
{
  declare iWaiID integer;

  iWaiID := self.wa_id ();
  return (select XMLAGG ( XMLELEMENT ( 'dash-row',
                                       XMLATTRIBUTES ( 'normal' as "class",
                                                       AB.WA.dt_format(_time, 'Y/M/D H:N') as "time",
                                                       self.wa_name as "application"
                                                      ),
                                       XMLELEMENT ( 'dash-data',
	                                                  XMLATTRIBUTES ( concat (N'<a href="', cast (SIOC..addressbook_contact_iri (iWaiID, _id) as nvarchar), N'">', AB.WA.utf2wide (_title), N'</a>') as "content",
	                                                                  0 as "comments"
	                                                                )
                                          	      )
                                     )
                     	  )
            from AB.WA.dashboard_rs(p0)(_id integer, _title varchar, _time datetime) x
           where p0 = iWaiID
         );
}
;

-------------------------------------------------------------------------------
--
create method wa_dashboard_last_item () for wa_AddressBook
{
  return AB.WA.dashboard_get (self.wa_id ());
}
;

-------------------------------------------------------------------------------
--
create method wa_rdf_url (in vhost varchar, in lhost varchar) for wa_AddressBook
{
  declare domainID, userID integer;

  domainID := self.wa_id ();
  userID := AB.WA.domain_owner_id (domainID);
  return concat(AB.WA.dav_url2(domainID, userID), 'AddressBook.rdf');
}
;

-------------------------------------------------------------------------------
--
create method wa_addition_urls () for wa_AddressBook
{
  return vector (
    vector (null, null, '/addressbook',                    '/DAV/VAD/wa/', 1, 0, null, null, null, null, 'dba', null, null, 0, null, null, vector ('url_rewrite', 'ods_rulelist_addressbook'), 0),
    vector (null, null, '/dataspace/services/addressbook', '/SOAP/',       0, 0, null, null, null, null,  null, 'SOAP_ADDRESSBOOK', null, 1, vector('Use', 'literal', 'XML-RPC', 'no' ), null, null, 0)
  );
}
;

-------------------------------------------------------------------------------
--
create method wa_update_instance (in oldValues any, in newValues any) for wa_AddressBook
{
  declare domainID, ownerID integer;

  domainID := (select WAI_ID from DB.DBA.WA_INSTANCE where WAI_NAME = newValues[0]);
  ownerID := (select WAM_USER from WA_MEMBER B where WAM_INST = oldValues[0] and WAM_MEMBER_TYPE = 1);

  AB.WA.domain_gems_delete (domainID, ownerID, 'AddressBook', oldValues[0] || '_Gems');
  AB.WA.domain_gems_create (domainID, ownerID);
  AB.WA.nntp_update (domainID, AB.WA.domain_nntp_name2 (oldValues[0], AB.WA.account_name (ownerID)), AB.WA.domain_nntp_name2 (newValues[0], AB.WA.account_name (ownerID)));

  return (self as web_app).wa_update_instance (oldValues, newValues);
}
;

-------------------------------------------------------------------------------
--
create procedure AB.WA.path_upgrade ()
{
  declare _new_lpath varchar;

  if (registry_get ('ab_path_upgrade2') = '1')
    return;

  for (select WAI_ID from DB.DBA.WA_INSTANCE where WAI_TYPE_NAME = 'AddressBook') do
  {
    for (select HP_LPATH as _lpath,
                HP_HOST as _vhost,
                HP_LISTEN_HOST as _lhost
           from DB.DBA.HTTP_PATH
          where HP_LPATH = '/addressbook/' || cast (WAI_ID as varchar) || '/home.vspx') do
    {
      _new_lpath := '/addressbook/' || cast (WAI_ID as varchar);
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
  registry_set ('ab_path_upgrade2', '1');
}
;
AB.WA.path_upgrade ();
