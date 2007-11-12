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

------------------------------------------------------------------------------
--
create procedure ODRIVE.WA.exec_no_error(in expr varchar, in execType varchar := '', in execTable varchar := '', in execColumn varchar := '')
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

------------------------------------------------------------------------------
--
create procedure ODRIVE.WA.odrive_vhost()
{
  declare
    iIsDav integer;
  declare
    sHost varchar;

  -- Add a virtual directory for oDrive - public www -------------------------
  sHost := registry_get('_oDrive_path_');
  if (cast(sHost as varchar) = '0')
    sHost := '/apps/Briefcase/';
  iIsDav := 1;
  if (isnull(strstr(sHost, '/DAV')))
    iIsDav := 0;

  VHOST_REMOVE(lpath    => '/odrive');

  USER_CREATE ('SOAPODrive', md5 (cast (now() as varchar)), vector ('DISABLED', 1));
  USER_SET_QUALIFIER ('SOAPODrive', 'DBA');

  VHOST_REMOVE (lpath => '/odrive/SOAP');
  VHOST_REMOVE (lpath => '/dataspace/services/briefcase');
  VHOST_DEFINE (lpath => '/dataspace/services/briefcase',
                ppath => '/SOAP/',
                soap_user => 'SOAPODrive',
                soap_opts => vector('Use', 'literal', 'XML-RPC', 'no' ));

  DB.DBA.URLREWRITE_CREATE_REGEX_RULE (
    'rdf_sink_rule1',
    1,
    '/DAV/home/([^/]*)/rdf_sink/(.*)',
    vector('user', 'resource'),
    2,
    '/sparql?default-graph-uri=http%%3A//local.virt/DAV/home/%U/rdf_sink/%U&query=CONSTRUCT%%20{%%3Fs%%20%%3Fp%%20%%3Fo}%%20WHERE%%20{%%3Fs%%20%%3Fp%%20%%3Fo}&format=%U',
    vector('user', 'resource', '*accept*'),
    null,
    '(application/rdf.xml)|(application/foaf.xml)|(text/rdf.n3)|(text/rdf.ttl)|(application/rdf.n3)|(application/rdf.turtle)|(application/turtle)|(application/x-turtle)',
    0,
    303
  );

  DB.DBA.URLREWRITE_CREATE_RULELIST (
    'rdf_sink_rule_list',
    1,
    vector ('rdf_sink_rule1')
  );

  VHOST_REMOVE (lpath=>'/DAV');
  VHOST_DEFINE (lpath=>'/DAV', ppath=>'/DAV/', is_dav=>1, vsp_user=>'dba', is_brws=>1, opts=>vector ('url_rewrite', 'rdf_sink_rule_list'));
}
;

ODRIVE.WA.odrive_vhost();

-------------------------------------------------------------------------------
--
-- Insert data
--
-------------------------------------------------------------------------------
ODRIVE.WA.exec_no_error ('insert replacing WA_TYPES(WAT_NAME, WAT_TYPE, WAT_REALM, WAT_DESCRIPTION, WAT_MAXINST) values (\'oDrive\', \'db.dba.wa_oDrive\', \'wa\', \'Briefcase Application\', 1)')
;
ODRIVE.WA.exec_no_error ('insert soft WA_MEMBER_TYPE (WMT_APP, WMT_NAME, WMT_ID, WMT_IS_DEFAULT) values (\'oDrive\', \'owner\', 1, 0)')
;
ODRIVE.WA.exec_no_error ('insert soft WA_MEMBER_TYPE (WMT_APP, WMT_NAME, WMT_ID, WMT_IS_DEFAULT) values (\'oDrive\', \'user\', 2, 0)')
;

-------------------------------------------------------------------------------
--
-- create new oDrive application in WA
--
-- oDrive class
--
ODRIVE.WA.exec_no_error('
  create type db.dba.wa_oDrive under web_app
    constructor method wa_oDrive(stream any),
    overriding method wa_new_inst(login varchar) returns any,
    overriding method wa_front_page(stream any) returns any,
    overriding method wa_state_edit_form(stream any) returns any,
    overriding method wa_home_url() returns varchar,
    overriding method wa_class_details() returns varchar
'
)
;

ODRIVE.WA.exec_no_error (
  'alter type wa_oDrive add overriding method wa_front_page_as_user(inout stream any, in user_name varchar) returns any'
)
;

ODRIVE.WA.exec_no_error (
  'alter type wa_oDrive add overriding method wa_size () returns integer'
)
;

ODRIVE.WA.exec_no_error (
  'alter type wa_oDrive add method wa_vhost_options () returns any'
)
;

ODRIVE.WA.exec_no_error (
  'alter type wa_oDrive add method get_param (in param varchar) returns any'
)
;

ODRIVE.WA.exec_no_error (
  'alter type wa_oDrive add method wa_dashboard_last_item () returns any'
)
;

ODRIVE.WA.exec_no_error (
  'alter type wa_oDrive add overriding method wa_rdf_url (in vhost varchar, in lhost varchar) returns varchar'
)
;

ODRIVE.WA.exec_no_error (
  'alter type wa_oDrive add method wa_id () returns integer'
)
;

ODRIVE.WA.exec_no_error (
  'alter type wa_oDrive add overriding method wa_drop_instance () returns any'
)
;

-------------------------------------------------------------------------------
--
-- OPS methods
--
-------------------------------------------------------------------------------
--
create constructor method wa_oDrive (inout stream any) for wa_oDrive
{
  return;
}
;

-------------------------------------------------------------------------------
--
create method wa_id () for wa_oDrive
{
  return (select WAI_ID from WA_INSTANCE where WAI_NAME = self.wa_name);
}
;

-------------------------------------------------------------------------------
--
-- owner makes a new oDrive
--
create method wa_new_inst (in login varchar) for wa_oDrive
{
  declare iUserID, iWaiID integer;
  declare retValue any;

  iUserID := (select U_ID from DB.DBA.SYS_USERS where U_NAME = login);
  if (isnull(iUserID))
    signal('OD001', 'Not an ODS user');

  if (self.wa_member_model is null)
    self.wa_member_model := 0;

  insert into WA_INSTANCE (WAI_NAME, WAI_TYPE_NAME, WAI_INST, WAI_DESCRIPTION, WAI_IS_PUBLIC, WAI_MEMBERS_VISIBLE)
    values (self.wa_name, 'oDrive', self, '', 0, 0);

  iWaiID := self.wa_id ();

  -- Add a virtual directory for BM - public www -------------------------
  VHOST_REMOVE(lpath    => '/odrive/' || cast (iWaiID as varchar));
  VHOST_DEFINE(lpath    => '/odrive/' || cast (iWaiID as varchar),
               ppath    => self.get_param('host') || 'www/',
               ses_vars => 1,
               is_dav   => self.get_param('isDAV'),
               is_brws  => 0,
               vsp_user => 'dba',
               realm    => 'wa',
               def_page => 'home.vspx',
               opts     => vector ('domain', iWaiID)
             );

  ODRIVE.WA.odrive_user_initialize(login);
  retValue := (self as web_app).wa_new_inst(login);

  --  SIOC service
  declare  graph_iri, iri, c_iri varchar;

  graph_iri := SIOC..get_graph ();
  iri := sprintf ('http://%s%s/services/briefcase', SIOC..get_cname(), SIOC..get_base_path ());
  c_iri := SIOC..briefcase_iri (self.wa_name);
  SIOC..ods_sioc_service (graph_iri, iri, c_iri, null, null, null, iri, 'SOAP');

  return retValue;
}
;

-------------------------------------------------------------------------------
--
create method wa_drop_instance () for wa_oDrive
{
  declare iWaiID integer;

  iWaiID := self.wa_id ();
  VHOST_REMOVE(lpath => concat('/odrive/', cast (iWaiID as varchar)));
  (self as web_app).wa_drop_instance ();
}
;

-------------------------------------------------------------------------------
--
create method wa_class_details() for wa_oDrive
{
  return 'The Virtuoso oDrive Application allows you to run an online diary system. Like a diary it can be a private system, however in the spirit of weblog these are often public for outsides to pass comment.  Weblog supports community based operation to keep groups of weblogs together for collaboration of friends or fellow members of an organization department.';
}
;

-------------------------------------------------------------------------------
--
create method wa_front_page(inout stream any) for wa_oDrive
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
create method wa_state_edit_form(inout stream any) for wa_oDrive
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
    http_header(sprintf('Location: %s?sid=%s&realm=%s\r\n', WS.WS.EXPAND_URL (self.wa_home_url(), 'settings.vspx'), sSid, 'wa'));
  } else {
    signal('42001', 'Not a owner');
  }
  return;
}
;

-------------------------------------------------------------------------------
--
create method wa_home_url () for wa_oDrive
{
  return concat('/odrive/', cast (self.wa_id () as varchar), '/home.vspx');
}
;

-------------------------------------------------------------------------------
--
create method wa_front_page_as_user (inout stream any, in user_name varchar) for wa_oDrive
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
create method wa_size () for wa_oDrive
{
  return 0;
}
;

-------------------------------------------------------------------------------
--
create method wa_vhost_options () for wa_oDrive
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
create method get_param (in param varchar) for wa_oDrive
{
  declare retValue any;

  retValue := null;
  if (param = 'host') {
    retValue := registry_get('_oDrive_path_');
    if (cast(retValue as varchar) = '0')
      retValue := '/apps/Briefcase/';
  } if (param = 'isDAV') {
    retValue := 1;
    if (isnull(strstr(self.get_param('host'), '/DAV')))
      retValue := 0;
  }
  return retValue;
}
;

create method wa_dashboard_last_item () for wa_oDrive
{
  declare ses, vspxUser, c_iri any;
  declare iUserID integer;

  c_iri := SIOC..briefcase_iri (self.wa_name);
  vspxUser := connection_get ('vspx_user');
  iUserID := (select top 1 U_ID from SYS_USERS A, WA_MEMBER B where B.WAM_USER = A.U_ID and B.WAM_INST = self.wa_name and B.WAM_MEMBER_TYPE = 1);
  ses := string_output ();

  http ('<dav-db>', ses);
  if (isnull (vspxUser)) {
    for (select top 10 RES_ID,
                RES_FULL_PATH,
                RES_MOD_TIME,
                RES_NAME,
                RES_OWNER
           from WS.WS.SYS_DAV_RES
          where RES_FULL_PATH like '/DAV/home/%'
            and RES_OWNER = iUserID
            and substring (RES_PERMS, 7, 1) = '1'
          order by RES_MOD_TIME desc) do {

      declare uname, full_name varchar;

      uname := (select coalesce (U_NAME, '') from DB.DBA.SYS_USERS where U_ID = RES_OWNER);
      full_name := (select coalesce (coalesce (U_FULL_NAME, U_NAME), '') from DB.DBA.SYS_USERS where U_ID = RES_OWNER);

      http ('<resource>', ses);
      http (sprintf ('<dt>%s</dt>', date_iso8601 (RES_MOD_TIME)), ses);
      http (sprintf ('<title><![CDATA[%s]]></title>', RES_NAME), ses);
      http (sprintf ('<link><![CDATA[%s]]></link>', RES_FULL_PATH), ses);
      -- http (sprintf ('<link><![CDATA[%s]]></link>', SIOC..post_iri_ex (c_iri, RES_ID)), ses);
      http (sprintf ('<from><![CDATA[%s]]></from>', full_name), ses);
      http (sprintf ('<uid>%s</uid>', uname), ses);
      http ('</resource>', ses);
    }
  } else {
  for select top 10 *
        from (select *
              from (select top 10 RES_ID,
                           RES_FULL_PATH,
                           RES_MOD_TIME,
                           RES_NAME,
                           RES_OWNER
                        from WS.WS.SYS_DAV_RES
                               join WS.WS.SYS_DAV_ACL_INVERSE on AI_PARENT_ID = RES_ID
                                 join WS.WS.SYS_DAV_ACL_GRANTS on GI_SUB = AI_GRANTEE_ID
                     where RES_FULL_PATH like '/DAV/home/%'
                       and AI_PARENT_TYPE = 'R'
                           and GI_SUPER = iUserID
                         and AI_FLAG = 'G'
                       order by RES_MOD_TIME desc
                     ) acl
              union
                select *
                from (select top 10 RES_ID,
                             RES_FULL_PATH,
                             RES_MOD_TIME,
                             RES_NAME,
                             RES_OWNER
                          from WS.WS.SYS_DAV_RES
                       where RES_FULL_PATH like '/DAV/home/' || vspxUser || '%'
                         and RES_OWNER = iUserID
                           and RES_PERMS like '1%'
                         order by RES_MOD_TIME desc
                     ) own
             ) sub
       order by RES_MOD_TIME desc do {

      declare uname, full_name, wai_name, link varchar;

    uname := (select coalesce (U_NAME, '') from DB.DBA.SYS_USERS where U_ID = RES_OWNER);
    full_name := (select coalesce (coalesce (U_FULL_NAME, U_NAME), '') from DB.DBA.SYS_USERS where U_ID = RES_OWNER);

      wai_name := (select top 1 WAI_NAME from DB.DBA.WA_INSTANCE, DB.DBA.WA_MEMBER where WAI_TYPE_NAME = 'oDrive' and WAI_NAME = WAM_INST and WAM_MEMBER_TYPE = 1 and WAM_USER = RES_OWNER);
      if (isnull (wai_name)) {
        link := RES_FULL_PATH;
      } else {
        link := SIOC..post_iri_ex (SIOC..briefcase_iri (wai_name), RES_ID);
      }

    http ('<resource>', ses);
    http (sprintf ('<dt>%s</dt>', date_iso8601 (RES_MOD_TIME)), ses);
      http (sprintf ('<title>%V</title>', RES_NAME), ses);
      http (sprintf ('<link>%V</link>', link), ses);
      -- http (sprintf ('<link><![CDATA[%s]]></link>', SIOC..post_iri_ex (c_iri, RES_ID)), ses);
      http (sprintf ('<from>%V</from>', full_name), ses);
    http (sprintf ('<uid>%s</uid>', uname), ses);
    http ('</resource>', ses);
  }
  }
  http ('</dav-db>', ses);
  return string_output_string (ses);
}
;

-------------------------------------------------------------------------------
--
create method wa_rdf_url (in vhost varchar, in lhost varchar) for wa_oDrive
{
  declare domainID, userID integer;

  domainID := (select WAI_ID from DB.DBA.WA_INSTANCE where WAI_NAME = self.wa_name);
  userID := (select WAM_USER from WA_MEMBER B where WAM_INST= self.wa_name and WAM_MEMBER_TYPE = 1);
  return sprintf ('%sexport.vspx?output=about&did=%d&aid=%d', ODRIVE.WA.odrive_url (), domainID, userID);
}
;

-------------------------------------------------------------------------------
--
create procedure ODRIVE.WA.path_upgrade ()
{
  declare inst any;

  if (registry_get ('odrive_path_upgrade') = '1')
    return;

  for (select WAI_ID, WAI_NAME, WAI_INST from DB.DBA.WA_INSTANCE where WAI_TYPE_NAME = 'oDrive') do {
    VHOST_REMOVE(lpath    => '/odrive/' || cast (WAI_ID as varchar));
    VHOST_DEFINE(lpath    => '/odrive/' || cast (WAI_ID as varchar),
                 ppath    => (WAI_INST as wa_oDrive).get_param ('host') || 'www/',
                 ses_vars => 1,
                 is_dav   => (WAI_INST as wa_oDrive).get_param ('isDAV'),
                 is_brws  => 0,
                 vsp_user => 'dba',
                 realm    => 'wa',
                 def_page => 'home.vspx',
                 opts     => vector ('domain', WAI_ID)
               );
    update DB.DBA.WA_MEMBER
       set WAM_HOME_PAGE = '/odrive/' || cast (WAI_ID as varchar) || '/home.vspx'
     where WAM_INST = WAI_NAME;
  }
  VHOST_REMOVE (lpath    => '/odrive/');
}
;

ODRIVE.WA.path_upgrade ();

registry_set ('odrive_path_upgrade', '1');
