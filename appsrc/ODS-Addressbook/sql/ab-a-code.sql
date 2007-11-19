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
-------------------------------------------------------------------------------
--
-- Session Functions
--
-------------------------------------------------------------------------------
create procedure AB.WA.session_restore(
  inout params any)
{
  declare aPath, domain_id, user_id, user_name, user_role, sid, realm, options any;

  declare exit handler for sqlstate '*' {
    domain_id := -2;
    goto _end;
  };

  sid := get_keyword('sid', params, '');
  realm := get_keyword('realm', params, '');

  options := http_map_get('options');
  if (not is_empty_or_null(options))
    domain_id := get_keyword('domain', options);
  if (is_empty_or_null (domain_id)) {
    aPath := split_and_decode (trim (http_path (), '/'), 0, '\0\0/');
    domain_id := cast(aPath[1] as integer);
  }
  if (not exists(select 1 from DB.DBA.WA_INSTANCE where WAI_ID = domain_id and domain_id <> -2))
    domain_id := -1;

_end:
  domain_id := cast (domain_id as integer);
  user_id := -1;
  for (select U.U_ID,
              U.U_NAME,
              U.U_FULL_NAME
         from DB.DBA.VSPX_SESSION S,
              WS.WS.SYS_DAV_USER U
        where S.VS_REALM = realm
          and S.VS_SID   = sid
          and S.VS_UID   = U.U_NAME) do
  {
    user_id   := U_ID;
    user_name := AB.WA.user_name(U_NAME, U_FULL_NAME);
    user_role := AB.WA.access_role(domain_id, U_ID);
  }
  if ((user_id = -1) and (domain_id >= 0) and (not exists(select 1 from DB.DBA.WA_INSTANCE where WAI_ID = domain_id and WAI_IS_PUBLIC = 1)))
    domain_id := -1;

  if (user_id = -1)
    if (domain_id = -1) {
      user_role := 'expire';
      user_name := 'Expire session';
    } else if (domain_id = -2) {
      user_role := 'public';
      user_name := 'Public User';
    } else {
      user_role := 'guest';
      user_name := 'Guest User';
    }

  return vector('domain_id', domain_id,
                'user_id',   user_id,
                'user_name', user_name,
                'user_role', user_role
               );
}
;

-------------------------------------------------------------------------------
--
-- Freeze Functions
--
-------------------------------------------------------------------------------
create procedure AB.WA.frozen_check(in domain_id integer)
{
  declare exit handler for not found { return 1; };

  if (is_empty_or_null((select WAI_IS_FROZEN from DB.DBA.WA_INSTANCE where WAI_ID = domain_id)))
    return 0;

  declare user_id integer;

  user_id := (select U_ID from SYS_USERS where U_NAME = connection_get ('vspx_user'));
  if (AB.WA.check_admin(user_id))
    return 0;

  user_id := (select U_ID from SYS_USERS where U_NAME = connection_get ('owner_user'));
  if (AB.WA.check_admin(user_id))
    return 0;

  return 1;
}
;

-------------------------------------------------------------------------------
--
create procedure AB.WA.frozen_page(in domain_id integer)
{
  return (select WAI_FREEZE_REDIRECT from DB.DBA.WA_INSTANCE where WAI_ID = domain_id);
}
;

-------------------------------------------------------------------------------
--
-- User Functions
--
-------------------------------------------------------------------------------
create procedure AB.WA.check_admin(
  in user_id integer) returns integer
{
  declare group_id integer;
  group_id := (select U_GROUP from SYS_USERS where U_ID = user_id);

  if (user_id = 0)
    return 1;
  if (user_id = http_dav_uid ())
    return 1;
  if (group_id = 0)
    return 1;
  if (group_id = http_dav_uid ())
    return 1;
  if(group_id = http_dav_uid()+1)
    return 1;
  return 0;
}
;

-------------------------------------------------------------------------------
--
create procedure AB.WA.check_grants(in domain_id integer, in user_id integer, in role_name varchar)
{
  whenever not found goto _end;

  if (AB.WA.check_admin(user_id))
    return 1;
  if (role_name is null or role_name = '')
    return 0;
  if (role_name = 'admin')
    return 0;
  if (role_name = 'guest') {
    if (exists(select 1
                 from SYS_USERS A,
                      WA_MEMBER B,
                      WA_INSTANCE C
                where A.U_ID = user_id
                  and B.WAM_USER = A.U_ID
                  and B.WAM_INST = C.WAI_NAME
                  and C.WAI_ID = domain_id))
      return 1;
  }
  if (role_name = 'owner')
    if (exists(select 1
                 from SYS_USERS A,
                      WA_MEMBER B,
                      WA_INSTANCE C
                where A.U_ID = user_id
                  and B.WAM_USER = A.U_ID
                  and B.WAM_MEMBER_TYPE = 1
                  and B.WAM_INST = C.WAI_NAME
                  and C.WAI_ID = domain_id))
      return 1;
_end:
  return 0;
}
;

-------------------------------------------------------------------------------
--
create procedure AB.WA.check_grants2(in role_name varchar, in page_name varchar)
{
  declare tree any;

  tree := xml_tree_doc (AB.WA.menu_tree ());
  if (isnull (xpath_eval (sprintf ('//node[(@url = "%s") and contains(@allowed, "%s")]', page_name, role_name), tree, 1)))
    return 0;
  return 1;
}
;

-------------------------------------------------------------------------------
--
create procedure AB.WA.access_role(in domain_id integer, in user_id integer)
{
  whenever not found goto _end;

  if (AB.WA.check_admin (user_id))
    return 'admin';

  if (exists(select 1
               from SYS_USERS A,
                    WA_MEMBER B,
                    WA_INSTANCE C
              where A.U_ID = user_id
                and B.WAM_USER = A.U_ID
                and B.WAM_MEMBER_TYPE = 1
                and B.WAM_INST = C.WAI_NAME
                and C.WAI_ID = domain_id))
    return 'owner';

  if (exists(select 1
               from SYS_USERS A,
                    WA_MEMBER B,
                    WA_INSTANCE C
              where A.U_ID = user_id
                and B.WAM_USER = A.U_ID
                and B.WAM_MEMBER_TYPE = 2
                and B.WAM_INST = C.WAI_NAME
                and C.WAI_ID = domain_id))
    return 'author';

  if (exists(select 1
               from SYS_USERS A,
                    WA_MEMBER B,
                    WA_INSTANCE C
              where A.U_ID = user_id
                and B.WAM_USER = A.U_ID
                and B.WAM_INST = C.WAI_NAME
                and C.WAI_ID = domain_id))
    return 'reader';

  if (exists(select 1
               from SYS_USERS A
              where A.U_ID = user_id))
    return 'guest';

_end:
  return 'public';
}
;

-------------------------------------------------------------------------------
--
create procedure AB.WA.wa_home_link ()
{
  return case when registry_get ('wa_home_link') = 0 then '/ods/' else registry_get ('wa_home_link') end;
}
;

-------------------------------------------------------------------------------
--
create procedure AB.WA.wa_home_title ()
{
  return case when registry_get ('wa_home_title') = 0 then 'ODS Home' else registry_get ('wa_home_title') end;
}
;

-------------------------------------------------------------------------------
--
create procedure AB.WA.page_name ()
{
  declare aPath any;

  aPath := http_path ();
  aPath := split_and_decode (aPath, 0, '\0\0/');
  return aPath [length (aPath) - 1];
}
;

-------------------------------------------------------------------------------
--
create procedure AB.WA.menu_tree ()
{
  declare S varchar;

  S :=
'<?xml version="1.0" ?>
<menu_tree>
  <node name="home" url="home.vspx"            id="1"   allowed="public guest reader author owner admin">
    <node name="11" url="home.vspx"            id="11"  allowed="public guest reader author owner admin"/>
    <node name="12" url="search.vspx"          id="12"  allowed="public guest reader author owner admin"/>
    <node name="13" url="error.vspx"           id="13"  allowed="public guest reader author owner admin"/>
    <node name="14" url="settings.vspx"        id="14"  allowed="reader author owner admin"/>
  </node>
</menu_tree>';

  return S;
}
;

-------------------------------------------------------------------------------
--
create procedure AB.WA.xslt_root()
{
  declare sHost varchar;

  sHost := cast (registry_get('ab_path') as varchar);
  if (sHost = '0')
    return 'file://apps/AddressBook/xslt/';
  if (isnull (strstr(sHost, '/DAV/VAD')))
    return sprintf ('file://%sxslt/', sHost);
  return sprintf ('virt://WS.WS.SYS_DAV_RES.RES_FULL_PATH.RES_CONTENT:%sxslt/', sHost);
}
;

-------------------------------------------------------------------------------
--
create procedure AB.WA.xslt_full(
  in xslt_file varchar)
{
  return concat(AB.WA.xslt_root(), xslt_file);
}
;

-------------------------------------------------------------------------------
--
create procedure AB.WA.export_rss_sqlx_int (
  in domain_id integer,
  in account_id integer)
{
  declare retValue any;

  retValue := string_output ();

  http ('<?xml version ="1.0" encoding="UTF-8"?>\n', retValue);
  http ('<rss version="2.0">\n', retValue);
  http ('<channel>\n', retValue);

  http ('<sql:sqlx xmlns:sql="urn:schemas-openlink-com:xml-sql" sql:xsl=""><![CDATA[\n', retValue);
  http ('select \n', retValue);
  http ('  XMLELEMENT(\'title\', AB.WA.utf2wide(AB.WA.domain_name (<DOMAIN_ID>))), \n', retValue);
  http ('  XMLELEMENT(\'description\', AB.WA.utf2wide(AB.WA.domain_description (<DOMAIN_ID>))), \n', retValue);
  http ('  XMLELEMENT(\'managingEditor\', U_E_MAIL), \n', retValue);
  http ('  XMLELEMENT(\'pubDate\', AB.WA.dt_rfc1123(now())), \n', retValue);
  http ('  XMLELEMENT(\'generator\', \'Virtuoso Universal Server \' || sys_stat(\'st_dbms_ver\')), \n', retValue);
  http ('  XMLELEMENT(\'webMaster\', U_E_MAIL), \n', retValue);
  http ('  XMLELEMENT(\'link\', AB.WA.ab_url (<DOMAIN_ID>)) \n', retValue);
  http ('from DB.DBA.SYS_USERS where U_ID = <USER_ID> \n', retValue);
  http (']]></sql:sqlx>\n', retValue);

  http ('<sql:sqlx xmlns:sql=\'urn:schemas-openlink-com:xml-sql\'><![CDATA[\n', retValue);
  http ('select \n', retValue);
  http ('  XMLAGG(XMLELEMENT(\'item\', \n', retValue);
  http ('    XMLELEMENT(\'title\', AB.WA.utf2wide (P_NAME)), \n', retValue);
  http ('    XMLELEMENT(\'description\', AB.WA.utf2wide (P_FULL_NAME)), \n', retValue);
  http ('    XMLELEMENT(\'guid\', P_ID), \n', retValue);
  http ('    XMLELEMENT(\'link\', AB.WA.contact_url (<DOMAIN_ID>, P_ID)), \n', retValue);
  http ('    XMLELEMENT(\'pubDate\', AB.WA.dt_rfc1123 (P_UPDATED)), \n', retValue);
  http ('    (select XMLAGG (XMLELEMENT (\'category\', TV_TAG)) from AB..TAGS_VIEW where tags = P_TAGS), \n', retValue);
  http ('    XMLELEMENT(\'http://www.openlinksw.com/weblog/:modified\', AB.WA.dt_iso8601 (P_UPDATED)))) \n', retValue);
  http ('from (select top 15  \n', retValue);
  http ('        P_NAME, \n', retValue);
  http ('        P_FULL_NAME, \n', retValue);
  http ('        P_UPDATED, \n', retValue);
  http ('        P_TAGS, \n', retValue);
  http ('        P_ID \n', retValue);
  http ('      from \n', retValue);
  http ('        AB.WA.PERSONS \n', retValue);
  http ('      where P_DOMAIN_ID = <DOMAIN_ID> \n', retValue);
  http ('      order by P_UPDATED desc) x \n', retValue);
  http (']]></sql:sqlx>\n', retValue);

  http ('</channel>\n', retValue);
  http ('</rss>\n', retValue);

  retValue := string_output_string (retValue);
  retValue := replace (retValue, '<USER_ID>', cast (account_id as varchar));
  retValue := replace (retValue, '<DOMAIN_ID>', cast (domain_id as varchar));
  return retValue;
}
;

-------------------------------------------------------------------------------
--
create procedure AB.WA.export_rss_sqlx (
  in domain_id integer,
  in account_id integer)
{
  declare retValue any;

  retValue := AB.WA.export_rss_sqlx_int (domain_id, account_id);
  return replace (retValue, 'sql:xsl=""', '');
}
;

-------------------------------------------------------------------------------
--
create procedure AB.WA.export_atom_sqlx(
  in domain_id integer,
  in account_id integer)
{
  declare retValue, xsltTemplate any;

  xsltTemplate := AB.WA.xslt_full ('rss2atom03.xsl');
  if (AB.WA.settings_atomVersion (AB.WA.settings (account_id)) = '1.0')
    xsltTemplate := AB.WA.xslt_full ('rss2atom.xsl');

  retValue := AB.WA.export_rss_sqlx_int (domain_id, account_id);
  return replace (retValue, 'sql:xsl=""', sprintf ('sql:xsl="%s"', xsltTemplate));
}
;

-------------------------------------------------------------------------------
--
create procedure AB.WA.export_rdf_sqlx (
  in domain_id integer,
  in account_id integer)
{
  declare retValue any;

  retValue := AB.WA.export_rss_sqlx_int (domain_id, account_id);
  return replace (retValue, 'sql:xsl=""', sprintf ('sql:xsl="%s"', AB.WA.xslt_full ('rss2rdf.xsl')));
}
;

-------------------------------------------------------------------------------
--
create procedure AB.WA.domain_gems_create (
  inout domain_id integer,
  inout account_id integer)
{
  declare read_perm, exec_perm, content, home, path varchar;

  home := AB.WA.dav_home (account_id);
  if (isnull (home))
    return;

  read_perm := '110100100N';
  exec_perm := '111101101N';
  home := home || 'AddressBook/';
  DB.DBA.DAV_MAKE_DIR (home, account_id, null, read_perm);

  home := home || AB.WA.domain_gems_name(domain_id) || '/';
  DB.DBA.DAV_MAKE_DIR (home, account_id, null, read_perm);

  -- RSS 2.0
  path := home || 'AddressBook.rss';
  DB.DBA.DAV_DELETE_INT (path, 1, null, null, 0);

  content := AB.WA.export_rss_sqlx (domain_id, account_id);
  DB.DBA.DAV_RES_UPLOAD_STRSES_INT (path, content, 'text/xml', exec_perm, http_dav_uid (), http_dav_uid () + 1, null, null, 0);
  DB.DBA.DAV_PROP_SET_INT (path, 'xml-template', 'execute', 'dav', null, 0, 0, 1);
  DB.DBA.DAV_PROP_SET_INT (path, 'xml-sql-encoding', 'utf-8', 'dav', null, 0, 0, 1);
  DB.DBA.DAV_PROP_SET_INT (path, 'xml-sql-description', 'RSS based XML document generated by OpenLink AddressBook', 'dav', null, 0, 0, 1);

  -- ATOM
  path := home || 'AddressBook.atom';
  DB.DBA.DAV_DELETE_INT (path, 1, null, null, 0);

  content := AB.WA.export_atom_sqlx (domain_id, account_id);
  DB.DBA.DAV_RES_UPLOAD_STRSES_INT (path, content, 'text/xml', exec_perm, http_dav_uid (), http_dav_uid () + 1, null, null, 0);
  DB.DBA.DAV_PROP_SET_INT (path, 'xml-template', 'execute', 'dav', null, 0, 0, 1);
  DB.DBA.DAV_PROP_SET_INT (path, 'xml-sql-encoding', 'utf-8', 'dav', null, 0, 0, 1);
  DB.DBA.DAV_PROP_SET_INT (path, 'xml-sql-description', 'ATOM based XML document generated by OpenLink AddressBook', 'dav', null, 0, 0, 1);

  -- RDF
  path := home || 'AddressBook.rdf';
  DB.DBA.DAV_DELETE_INT (path, 1, null, null, 0);

  content := AB.WA.export_rdf_sqlx (domain_id, account_id);
  DB.DBA.DAV_RES_UPLOAD_STRSES_INT (path, content, 'text/xml', exec_perm, http_dav_uid (), http_dav_uid () + 1, null, null, 0);
  DB.DBA.DAV_PROP_SET_INT (path, 'xml-template', 'execute', 'dav', null, 0, 0, 1);
  DB.DBA.DAV_PROP_SET_INT (path, 'xml-sql-encoding', 'utf-8', 'dav', null, 0, 0, 1);
  DB.DBA.DAV_PROP_SET_INT (path, 'xml-sql-description', 'RDF based XML document generated by OpenLink AddressBook', 'dav', null, 0, 0, 1);

  return;
}
;

-------------------------------------------------------------------------------
--
create procedure AB.WA.domain_gems_delete (
  in domain_id integer,
  in account_id integer,
  in appName varchar := 'AddressBook',
  in appGems varchar := null)
{
  declare tmp, home, path varchar;

  home := AB.WA.dav_home (account_id);
  if (isnull (home))
    return;

  if (isnull (appGems))
    appGems := AB.WA.domain_gems_name (domain_id);
  home := home || appName || '/' || appGems || '/';

  path := home || appName || '.rss';
  DB.DBA.DAV_DELETE_INT (path, 1, null, null, 0);
  path := home || appName || '.rdf';
  DB.DBA.DAV_DELETE_INT (path, 1, null, null, 0);
  path := home || appName || '.atom';
  DB.DBA.DAV_DELETE_INT (path, 1, null, null, 0);
  path := home || appName || '.ocs';
  DB.DBA.DAV_DELETE_INT (path, 1, null, null, 0);
  path := home || appName || '.opml';
  DB.DBA.DAV_DELETE_INT (path, 1, null, null, 0);

  declare auth_uid, auth_pwd varchar;

  auth_uid := coalesce((SELECT U_NAME FROM WS.WS.SYS_DAV_USER WHERE U_ID = account_id), '');
  auth_pwd := coalesce((SELECT U_PWD FROM WS.WS.SYS_DAV_USER WHERE U_ID = account_id), '');
  if (auth_pwd[0] = 0)
    auth_pwd := pwd_magic_calc (auth_uid, auth_pwd, 1);

  tmp := DB.DBA.DAV_DIR_LIST (home, 0, auth_uid, auth_pwd);
  if (not isinteger(tmp) and not length(tmp))
    DB.DBA.DAV_DELETE_INT (home, 1, null, null, 0);

  return 1;
}
;

-------------------------------------------------------------------------------
--
create procedure AB.WA.domain_update (
  inout domain_id integer,
  inout account_id integer)
{
  AB.WA.domain_gems_delete (domain_id, account_id, 'AddressBook');
  AB.WA.domain_gems_create (domain_id, account_id);

  return 1;
}
;

-------------------------------------------------------------------------------
--
create procedure AB.WA.domain_owner_id (
  inout domain_id integer)
{
  return (select A.WAM_USER from WA_MEMBER A, WA_INSTANCE B where A.WAM_MEMBER_TYPE = 1 and A.WAM_INST = B.WAI_NAME and B.WAI_ID = domain_id);
}
;

-------------------------------------------------------------------------------
--
create procedure AB.WA.domain_owner_name (
  inout domain_id integer)
{
  return (select C.U_NAME from WA_MEMBER A, WA_INSTANCE B, SYS_USERS C where A.WAM_MEMBER_TYPE = 1 and A.WAM_INST = B.WAI_NAME and B.WAI_ID = domain_id and C.U_ID = A.WAM_USER);
}
;

-------------------------------------------------------------------------------
--
create procedure AB.WA.domain_delete (
  in domain_id integer)
{
  VHOST_REMOVE(lpath => concat('/addressbook/', cast (domain_id as varchar)));
  return 1;
}
;

-------------------------------------------------------------------------------
--
create procedure AB.WA.domain_id (
  in domain_name varchar)
{
  return (select WAI_ID from DB.DBA.WA_INSTANCE where WAI_NAME = domain_name);
}
;

-------------------------------------------------------------------------------
--
create procedure AB.WA.domain_name (
  in domain_id integer)
{
  return coalesce((select WAI_NAME from DB.DBA.WA_INSTANCE where WAI_ID = domain_id), 'AddressBook Instance');
}
;

-------------------------------------------------------------------------------
--
create procedure AB.WA.domain_gems_name (
  in domain_id integer)
{
  return concat(AB.WA.domain_name(domain_id), '_Gems');
}
;

-------------------------------------------------------------------------------
--
create procedure AB.WA.domain_description (
  in domain_id integer)
{
  return coalesce((select coalesce(WAI_DESCRIPTION, WAI_NAME) from DB.DBA.WA_INSTANCE where WAI_ID = domain_id), 'AddressBook Instance');
}
;

-------------------------------------------------------------------------------
--
create procedure AB.WA.domain_is_public (
  in domain_id integer)
{
  return coalesce((select WAI_IS_PUBLIC from DB.DBA.WA_INSTANCE where WAI_ID = domain_id), 0);
}
;

-------------------------------------------------------------------------------
--
create procedure AB.WA.domain_ping (
  in domain_id integer)
{
  for (select WAI_NAME, WAI_DESCRIPTION from DB.DBA.WA_INSTANCE where WAI_ID = domain_id and WAI_IS_PUBLIC = 1) do {
    ODS..APP_PING (WAI_NAME, coalesce (WAI_DESCRIPTION, WAI_NAME), AB.WA.sioc_url (domain_id));
  }
}
;

-------------------------------------------------------------------------------
--
-- Account Functions
--
-------------------------------------------------------------------------------
create procedure AB.WA.account()
{
  declare vspx_user varchar;

  vspx_user := connection_get('owner_user');
  if (isnull (vspx_user))
    vspx_user := connection_get('vspx_user');
  return vspx_user;
}
;

-------------------------------------------------------------------------------
--
create procedure AB.WA.account_access (
  out auth_uid varchar,
  out auth_pwd varchar)
{
  auth_uid := AB.WA.account();
  auth_pwd := coalesce((SELECT U_PWD FROM WS.WS.SYS_DAV_USER WHERE U_NAME = auth_uid), '');
  if (auth_pwd[0] = 0)
    auth_pwd := pwd_magic_calc(auth_uid, auth_pwd, 1);
  return 1;
}
;

-------------------------------------------------------------------------------
--
create procedure AB.WA.account_delete(
  in domain_id integer,
  in account_id integer)
{
  declare iCount any;

  select count(WAM_USER) into iCount
    from WA_MEMBER,
         WA_INSTANCE
   where WAI_NAME = WAM_INST
     and WAI_TYPE_NAME = 'AddressBook'
     and WAM_USER = account_id;

  if (iCount = 0) {
    delete from AB.WA.SETTINGS where S_ACCOUNT_ID = account_id;
    delete from AB.WA.GRANTS where G_GRANTER_ID = account_id or G_GRANTEE_ID = account_id;
  }
  AB.WA.domain_gems_delete (domain_id, account_id);

  return 1;
}
;

-------------------------------------------------------------------------------
--
create procedure AB.WA.account_name (
  in account_id integer)
{
  return coalesce((select U_NAME from DB.DBA.SYS_USERS where U_ID = account_id), '');
}
;

-------------------------------------------------------------------------------
--
create procedure AB.WA.account_fullName (
  in account_id integer)
{
  return coalesce((select coalesce(U_FULL_NAME, U_NAME) from DB.DBA.SYS_USERS where U_ID = account_id), '');
}
;

-------------------------------------------------------------------------------
--
create procedure AB.WA.account_mail(
  in account_id integer)
{
  return coalesce((select U_E_MAIL from DB.DBA.SYS_USERS where U_ID = account_id), '');
}
;

-------------------------------------------------------------------------------
--
create procedure AB.WA.user_name(
  in u_name any,
  in u_full_name any) returns varchar
{
  if (not is_empty_or_null(trim(u_full_name)))
    return u_full_name;
  return u_name;
}
;

-------------------------------------------------------------------------------
--
create procedure AB.WA.tag_prepare(
  inout tag varchar)
{
  if (not is_empty_or_null(tag)) {
    tag := trim(tag);
    tag := replace (tag, '  ', ' ');
  }
  return tag;
}
;

-------------------------------------------------------------------------------
--
create procedure AB.WA.tag_delete(
  inout tags varchar,
  inout T integer)
{
  declare N integer;
  declare tags2 any;

  tags2 := AB.WA.tags2vector(tags);
  tags := '';
  for (N := 0; N < length(tags2); N := N + 1)
    if (N <> T)
      tags := concat(tags, ',', tags2[N]);
  return trim(tags, ',');
}
;

-------------------------------------------------------------------------------
--
create procedure AB.WA.tag_id (
  in tag varchar)
{
  tag := trim(tag);
  tag := replace (tag, ' ', '_');
  tag := replace (tag, '+', '_');
  return tag;
}
;

---------------------------------------------------------------------------------
--
create procedure AB.WA.tags_join(
  inout tags varchar,
  inout tags2 varchar)
{
  declare resultTags any;

  if (is_empty_or_null(tags))
    tags := '';
  if (is_empty_or_null(tags2))
    tags2 := '';

  resultTags := concat(tags, ',', tags2);
  resultTags := AB.WA.tags2vector(resultTags);
  resultTags := AB.WA.tags2unique(resultTags);
  resultTags := AB.WA.vector2tags(resultTags);
  return resultTags;
}
;

---------------------------------------------------------------------------------
--
create procedure AB.WA.tags2vector(
  inout tags varchar)
{
  return split_and_decode(trim(tags, ','), 0, '\0\0,');
}
;

---------------------------------------------------------------------------------
--
create procedure AB.WA.tags2search(
  in tags varchar)
{
  declare S varchar;
  declare V any;

  S := '';
  V := AB.WA.tags2vector(tags);
  foreach (any tag in V) do
    S := concat(S, ' ^T', replace (replace (trim(lcase(tag)), ' ', '_'), '+', '_'));
  return FTI_MAKE_SEARCH_STRING(trim(S, ','));
}
;

-------------------------------------------------------------------------------
--
create procedure AB.WA.vector2tags(
  inout aVector any)
{
  declare N integer;
  declare aResult any;

  aResult := '';
  for (N := 0; N < length(aVector); N := N + 1)
    if (N = 0) {
      aResult := trim(aVector[N]);
    } else {
      aResult := concat(aResult, ',', trim(aVector[N]));
    }
  return aResult;
}
;

-------------------------------------------------------------------------------
--
create procedure AB.WA.tags2unique(
  inout aVector any)
{
  declare aResult any;
  declare N, M integer;

  aResult := vector();
  for (N := 0; N < length(aVector); N := N + 1) {
    for (M := 0; M < length(aResult); M := M + 1)
      if (trim(lcase(aResult[M])) = trim(lcase(aVector[N])))
        goto _next;
    aResult := vector_concat(aResult, vector(trim(aVector[N])));
  _next:;
  }
  return aResult;
}
;

-----------------------------------------------------------------------------
--
create procedure AB.WA.dav_home(
  inout account_id integer) returns varchar
{
  declare name, home any;
  declare cid integer;

  name := coalesce((select U_NAME from DB.DBA.SYS_USERS where U_ID = account_id), -1);
  if (isinteger(name))
    return null;
  home := AB.WA.dav_home_create(name);
  if (isinteger(home))
    return null;
  cid := DB.DBA.DAV_SEARCH_ID(home, 'C');
  if (isinteger(cid) and (cid > 0))
    return home;
  return null;
}
;

-----------------------------------------------------------------------------
--
create procedure AB.WA.dav_home_create(
  in user_name varchar) returns any
{
  declare user_id, cid integer;
  declare user_home varchar;

  whenever not found goto _error;

  if (is_empty_or_null(user_name))
    goto _error;
  user_home := DB.DBA.DAV_HOME_DIR(user_name);
  if (isstring(user_home))
    cid := DB.DBA.DAV_SEARCH_ID(user_home, 'C');
    if (isinteger(cid) and (cid > 0))
      return user_home;

  user_home := '/DAV/home/';
  DB.DBA.DAV_MAKE_DIR (user_home, http_dav_uid (), http_dav_uid () + 1, '110100100R');

  user_home := user_home || user_name || '/';
  user_id := (select U_ID from DB.DBA.SYS_USERS where U_NAME = user_name);
  DB.DBA.DAV_MAKE_DIR (user_home, user_id, null, '110100000R');
  USER_SET_OPTION(user_name, 'HOME', user_home);

  return user_home;

_error:
  return -18;
}
;

-------------------------------------------------------------------------------
--
create procedure AB.WA.host_url ()
{
  declare host varchar;

  declare exit handler for sqlstate '*' { goto _default; };

  if (is_http_ctx ()) {
    host := http_request_header (http_request_header ( ) , 'Host' , null , sys_connected_server_address ());
    if (isstring (host) and strchr (host , ':') is null) {
      declare hp varchar;
      declare hpa any;

      hp := sys_connected_server_address ();
      hpa := split_and_decode ( hp , 0 , '\0\0:');
      host := host || ':' || hpa [1];
    }
    goto _exit;
  }

_default:;
  host := cfg_item_value (virtuoso_ini_path (), 'URIQA', 'DefaultHost');
  if (host is not null)
    return host;
  host := sys_stat ('st_host_name');
  if (server_http_port () <> '80')
    host := host || ':' || server_http_port ();

_exit:;
  return 'http://' || host ;
}
;

-------------------------------------------------------------------------------
--
create procedure AB.WA.ab_url (
  in domain_id integer)
{
  return concat(AB.WA.host_url(), '/addressbook/', cast (domain_id as varchar), '/');
}
;

-------------------------------------------------------------------------------
--
create procedure AB.WA.sioc_url (
  in domain_id integer)
{
  return sprintf ('http://%s/dataspace/%U/addressbook/%U/sioc.rdf', DB.DBA.wa_cname (), AB.WA.domain_owner_name (domain_id), replace (AB.WA.domain_name (domain_id), '+', '%2B'));
}
;

-------------------------------------------------------------------------------
--
create procedure AB.WA.foaf_url (
  in domain_id integer)
{
  return SIOC..person_iri (sprintf('http://%s%s/%s#this', SIOC..get_cname (), SIOC..get_base_path (), AB.WA.domain_owner_name (domain_id)), '/about.rdf');
}
;

-------------------------------------------------------------------------------
--
create procedure AB.WA.contact_url (
  in domain_id integer,
  in person_id integer)
{
  return concat(AB.WA.ab_url (domain_id), 'home.vspx?id=', cast (person_id as varchar));
}
;

-------------------------------------------------------------------------------
--
create procedure AB.WA.dav_url (
  in domain_id integer)
{
  declare home varchar;

  home := AB.WA.dav_home (AB.WA.domain_owner_id (domain_id));
  if (isnull (home))
    return '';
  return concat('http://', DB.DBA.wa_cname (), home, 'AddressBook/', AB.WA.domain_gems_name (domain_id), '/');
}
;

-------------------------------------------------------------------------------
--
create procedure AB.WA.dav_url2 (
  in domain_id integer,
  in account_id integer)
{
  declare home varchar;

  home := AB.WA.dav_home(account_id);
  if (isnull (home))
    return '';
  return replace (concat(home, 'AddressBook/', AB.WA.domain_gems_name(domain_id), '/'), ' ', '%20');
}
;

-------------------------------------------------------------------------------
--
create procedure AB.WA.geo_url (
  in domain_id integer,
  in account_id integer)
{
  for (select WAUI_LAT, WAUI_LNG from WA_USER_INFO where WAUI_U_ID = account_id) do
    if ((not isnull (WAUI_LNG)) and (not isnull (WAUI_LAT)))
      return sprintf ('\n    <meta name="ICBM" content="%.2f, %.2f"><meta name="DC.title" content="%s">', WAUI_LNG, WAUI_LAT, AB.WA.domain_name (domain_id));
  return '';
}
;

-------------------------------------------------------------------------------
--
create procedure AB.WA.dav_content (
  inout uri varchar,
  in auth_uid varchar := null,
  in auth_pwd varchar := null)
{
  declare cont varchar;
  declare hp any;

  declare exit handler for sqlstate '*' {
    --dbg_obj_print (__SQL_STATE, __SQL_MESSAGE);
    return null;
  };

  declare N integer;
  declare oldUri, newUri, reqHdr, resHdr varchar;

  newUri := uri;
  reqHdr := null;
  if (isnull (auth_uid))
  AB.WA.account_access (auth_uid, auth_pwd);
  reqHdr := sprintf ('Authorization: Basic %s', encode_base64(auth_uid || ':' || auth_pwd));

_again:
  N := N + 1;
  oldUri := newUri;
  commit work;
  cont := http_get (newUri, resHdr, 'GET', reqHdr);
  if (resHdr[0] like 'HTTP/1._ 30_ %') {
    newUri := http_request_header (resHdr, 'Location');
    newUri := WS.WS.EXPAND_URL (oldUri, newUri);
    if (N > 15)
      return null;
    if (newUri <> oldUri)
      goto _again;
  }
  if (resHdr[0] like 'HTTP/1._ 4__ %' or resHdr[0] like 'HTTP/1._ 5__ %')
    return null;

  return (cont);
}
;

-----------------------------------------------------------------------------
--
create procedure AB.WA.xml_set(
  in id varchar,
  inout pXml varchar,
  in value varchar)
{
  declare aEntity any;

  {
    declare exit handler for SQLSTATE '*' {
      pXml := xtree_doc('<?xml version="1.0" encoding="UTF-8"?><settings />');
      goto _skip;
    };
    if (not isentity(pXml))
      pXml := xtree_doc(pXml);
  }
_skip:
  aEntity := xpath_eval(sprintf ('/settings/entry[@ID = "%s"]', id), pXml);
  if (not isnull (aEntity))
    pXml := XMLUpdate(pXml, sprintf ('/settings/entry[@ID = "%s"]', id), null);

  if (not is_empty_or_null(value)) {
    aEntity := xpath_eval('/settings', pXml);
    XMLAppendChildren(aEntity, xtree_doc(sprintf ('<entry ID="%s">%s</entry>', id, AB.WA.xml2string(value))));
  }
  return pXml;
}
;

-----------------------------------------------------------------------------
--
create procedure AB.WA.xml_get(
  in id varchar,
  inout pXml varchar,
  in defaultValue any := '')
{
  declare value any;

  declare exit handler for SQLSTATE '*' {return defaultValue;};

  if (not isentity(pXml))
    pXml := xtree_doc(pXml);
  value := xpath_eval (sprintf ('string(/settings/entry[@ID = "%s"]/.)', id), pXml);
  if (is_empty_or_null(value))
    return defaultValue;

  return AB.WA.wide2utf(value);
}
;

-------------------------------------------------------------------------------
--
create procedure AB.WA.string2xml (
  in content varchar,
  in mode integer := 0)
{
  if (mode = 0) {
    declare exit handler for sqlstate '*' { goto _html; };
    return xml_tree_doc (xml_tree (content, 0));
  }
_html:;
  return xml_tree_doc(xml_tree(content, 2, '', 'UTF-8'));
}
;

-------------------------------------------------------------------------------
--
create procedure AB.WA.xml2string(
  in pXml any)
{
  declare sStream any;

  sStream := string_output();
  http_value(pXml, null, sStream);
  return string_output_string(sStream);
}
;

-------------------------------------------------------------------------------
--
create procedure AB.WA.normalize_space(
  in S varchar)
{
  return xpath_eval ('normalize-space (string(/a))', XMLELEMENT('a', S), 1);
}
;

-------------------------------------------------------------------------------
--
create procedure AB.WA.utfClear(
  inout S varchar)
{
  declare N integer;
  declare retValue varchar;

  retValue := '';
  for (N := 0; N < length(S); N := N + 1) {
    if (S[N] <= 31) {
      retValue := concat(retValue, '?');
    } else {
      retValue := concat(retValue, chr(S[N]));
    }
  }
  return retValue;
}
;

-------------------------------------------------------------------------------
--
create procedure AB.WA.utf2wide (
  inout S any)
{
  if (isstring (S))
    return charset_recode (S, 'UTF-8', '_WIDE_');
  return S;
}
;

-------------------------------------------------------------------------------
--
create procedure AB.WA.wide2utf (
  inout S any)
{
  if (iswidestring (S))
    return charset_recode (S, '_WIDE_', 'UTF-8' );
  return charset_recode (S, null, 'UTF-8' );
}
;

-------------------------------------------------------------------------------
--
create procedure AB.WA.stringCut (
  in S varchar,
  in L integer := 60)
{
  declare tmp any;

  if (not L)
    return S;
  tmp := AB.WA.utf2wide(S);
  if (not iswidestring(tmp))
    return S;
  if (length(tmp) > L)
    return AB.WA.wide2utf(concat(subseq(tmp, 0, L-3), '...'));
  return AB.WA.wide2utf(tmp);
}
;

-------------------------------------------------------------------------------
--
create procedure AB.WA.vector_unique(
  inout aVector any,
  in minLength integer := 0)
{
  declare aResult any;
  declare N, M integer;

  aResult := vector();
  for (N := 0; N < length(aVector); N := N + 1) {
    if ((minLength = 0) or (length(aVector[N]) >= minLength)) {
      for (M := 0; M < length(aResult); M := M + 1)
        if (trim(aResult[M]) = trim(aVector[N]))
          goto _next;
      aResult := vector_concat(aResult, vector(aVector[N]));
    }
  _next:;
  }
  return aResult;
}
;

-------------------------------------------------------------------------------
--
create procedure AB.WA.vector_except(
  inout aVector any,
  inout aExcept any)
{
  declare aResult any;
  declare N, M integer;

  aResult := vector();
  for (N := 0; N < length(aVector); N := N + 1) {
    for (M := 0; M < length(aExcept); M := M + 1)
      if (aExcept[M] = aVector[N])
        goto _next;
    aResult := vector_concat(aResult, vector(trim(aVector[N])));
  _next:;
  }
  return aResult;
}
;

-------------------------------------------------------------------------------
--
create procedure AB.WA.vector_contains(
  inout aVector any,
  in value varchar)
{
  declare N integer;

  for (N := 0; N < length(aVector); N := N + 1)
    if (value = aVector[N])
      return 1;
  return 0;
}
;

-------------------------------------------------------------------------------
--
create procedure AB.WA.vector_index (
  inout aVector any,
  in value varchar)
{
  declare N integer;

  for (N := 0; N < length(aVector); N := N + 1)
    if (value = aVector[N])
      return N;
  return null;
}
;

-------------------------------------------------------------------------------
--
create procedure AB.WA.vector_cut(
  inout aVector any,
  in value varchar)
{
  declare N integer;
  declare retValue any;

  retValue := vector();
  for (N := 0; N < length(aVector); N := N + 1)
    if (value <> aVector[N])
      retValue := vector_concat (retValue, vector(aVector[N]));
  return retValue;
}
;

-------------------------------------------------------------------------------
--
create procedure AB.WA.vector_set (
  inout aVector any,
  in aIndex any,
  in aValue varchar)
{
  declare N integer;
  declare retValue any;

  retValue := vector();
  for (N := 0; N < length(aVector); N := N + 1)
    if (aIndex = N) {
      retValue := vector_concat (retValue, vector(aValue));
    } else {
      retValue := vector_concat (retValue, vector(aVector[N]));
    }
  return retValue;
}
;

-------------------------------------------------------------------------------
--
create procedure AB.WA.vector_search(
  in aVector any,
  in value varchar,
  in condition vrchar := 'AND')
{
  declare N integer;

  for (N := 0; N < length(aVector); N := N + 1)
    if (value like concat('%', aVector[N], '%')) {
      if (condition = 'OR')
        return 1;
    } else {
      if (condition = 'AND')
        return 0;
    }
  return 0;
}
;

-------------------------------------------------------------------------------
--
create procedure AB.WA.vector2str(
  inout aVector any,
  in delimiter varchar := ' ')
{
  declare tmp, aResult any;
  declare N integer;

  aResult := '';
  for (N := 0; N < length(aVector); N := N + 1) {
    tmp := trim(aVector[N]);
    if (strchr (tmp, ' ') is not null)
      tmp := concat('''', tmp, '''');
    if (N = 0) {
      aResult := tmp;
    } else {
      aResult := concat(aResult, delimiter, tmp);
    }
  }
  return aResult;
}
;

-------------------------------------------------------------------------------
--
create procedure AB.WA.vector2rs(
  inout aVector any)
{
  declare N integer;
  declare c0 varchar;

  result_names(c0);
  for (N := 0; N < length(aVector); N := N + 1)
    result(aVector[N]);
}
;

-------------------------------------------------------------------------------
--
create procedure AB.WA.tagsDictionary2rs(
  inout aDictionary any)
{
  declare N integer;
  declare c0 varchar;
  declare c1 integer;
  declare V any;

  V := dict_to_vector(aDictionary, 1);
  result_names(c0, c1);
  for (N := 1; N < length(V); N := N + 2)
    result(V[N][0], V[N][1]);
}
;

-------------------------------------------------------------------------------
--
create procedure AB.WA.vector2src(
  inout aVector any)
{
  declare N integer;
  declare aResult any;

  aResult := 'vector(';
  for (N := 0; N < length(aVector); N := N + 1) {
    if (N = 0)
      aResult := concat(aResult, '''', trim(aVector[N]), '''');
    if (N <> 0)
      aResult := concat(aResult, ', ''', trim(aVector[N]), '''');
  }
  return concat(aResult, ')');
}
;

-------------------------------------------------------------------------------
--
create procedure AB.WA.ft2vector(
  in S any)
{
  declare w varchar;
  declare aResult any;

  aResult := vector();
  w := regexp_match ('["][^"]+["]|[''][^'']+['']|[^"'' ]+', S, 1);
  while (w is not null) {
    w := trim (w, '"'' ');
    if (upper(w) not in ('AND', 'NOT', 'NEAR', 'OR') and length (w) > 1 and not vt_is_noise (AB.WA.wide2utf(w), 'utf-8', 'x-ViDoc'))
      aResult := vector_concat(aResult, vector(w));
    w := regexp_match ('["][^"]+["]|[''][^'']+['']|[^"'' ]+', S, 1);
  }
  return aResult;
}
;

-------------------------------------------------------------------------------
--
create procedure AB.WA.set_keyword (
  in    name   varchar,
  inout params any,
  in    value  any)
{
  declare N integer;

  for (N := 0; N < length(params); N := N + 2)
    if (params[N] = name) {
      aset(params, N + 1, value);
      goto _end;
    }

  params := vector_concat(params, vector(name, value));

_end:
  return params;
}
;

-------------------------------------------------------------------------------
--
create procedure AB.WA.ab_tree2(
  in domain_id integer,
  in user_id integer,
  in node varchar,
  in path varchar)
{
  declare node_type, node_id any;

  node_id := AB.WA.node_id(node);
  node_type := AB.WA.node_type(node);
  if (node_type = 'r') {
    if (node_id = 2)
      return vector('Shared Contacts By', AB.WA.make_node ('u', -1), AB.WA.make_path(path, 'u', -1));
  }

  declare retValue any;
  retValue := vector ();

  if ((node_type = 'u') and (node_id = -1))
    for (select distinct U_ID, U_NAME from AB.WA.GRANTS, DB.DBA.SYS_USERS where G_GRANTEE_ID = user_id and G_GRANTER_ID = U_ID order by 2) do
      retValue := vector_concat(retValue, vector(U_NAME, AB.WA.make_node ('u', U_ID), AB.WA.make_path(path, 'u', U_ID)));

  return retValue;
}
;

-------------------------------------------------------------------------------
--
create procedure AB.WA.ab_node_has_childs (
  in domain_id integer,
  in user_id integer,
  in node varchar,
  in path varchar)
{
  declare node_type, node_id any;

  node_id := AB.WA.node_id(node);
  node_type := AB.WA.node_type(node);

  if ((node_type = 'u') and (node_id = -1))
    if (exists (select 1 from AB.WA.GRANTS, DB.DBA.SYS_USERS where G_GRANTEE_ID = user_id and G_GRANTER_ID = U_ID))
      return 1;

  return 0;
}
;

-------------------------------------------------------------------------------
--
create procedure AB.WA.ab_path2_int(
  in node varchar,
  inout path varchar)
{
  declare node_type, node_id any;

  node_id := AB.WA.node_id(node);
  node_type := AB.WA.node_type(node);

  if ((node_type = 'u') and (node_id >= 0))
    path := sprintf('%s/%s', AB.WA.make_node (node_type, -1), path);
}
;

-------------------------------------------------------------------------------
--
create procedure AB.WA.ab_path2 (
  in node varchar,
  in grant_id integer)
{
  declare user_id, root_id any;
  declare path any;

  path := node;
  user_id := (select G_GRANTER_ID from AB.WA.GRANTS where G_ID = grant_id);
  AB.WA.ab_path2_int (node, root_id, path);
  return '/' || path;
}
;

-------------------------------------------------------------------------------
--
create procedure AB.WA.make_node (
  in node_type varchar,
  in node_id any)
{
  return node_type || '#' || cast(node_id as varchar);
}
;

-------------------------------------------------------------------------------
--
create procedure AB.WA.make_path (
  in path varchar,
  in node_type varchar,
  in node_id any)
{
  return path || '/' || AB.WA.make_node (node_type, node_id);
}
;

-------------------------------------------------------------------------------
--
create procedure AB.WA.node_type(
  in code varchar)
{
  if ((length(code) > 1) and (substring(code,2,1) = '#'))
    return left(code, 1);
  return '';
}
;

-------------------------------------------------------------------------------
--
create procedure AB.WA.node_id (
  in node varchar)
{
  declare exit handler for sqlstate '*' { return -1; };

  if ((length(node) > 2) and (substring(node,2,1) = '#'))
    return cast(subseq(node, 2) as integer);
  return 0;
}
;

-------------------------------------------------------------------------------
--
create procedure AB.WA.node_suffix (
  in node varchar)
{
  if ((length(node) > 2) and (substring(node,2,1) = '#'))
    return subseq(node, 2);
  return '';
}
;

-------------------------------------------------------------------------------
--
-- Show functions
--
-------------------------------------------------------------------------------
--
create procedure AB.WA.show_text(
  in S any,
  in S2 any)
{
  if (isstring(S))
    S := trim(S);
  if (is_empty_or_null(S))
    return sprintf ('~ no %s ~', S2);
  return S;
}
;

-------------------------------------------------------------------------------
--
create procedure AB.WA.show_title(
  in S any)
{
  return AB.WA.show_text(S, 'title');
}
;

-------------------------------------------------------------------------------
--
create procedure AB.WA.show_author(
  in S any)
{
  return AB.WA.show_text(S, 'author');
}
;

-------------------------------------------------------------------------------
--
create procedure AB.WA.show_description(
  in S any)
{
  return AB.WA.show_text(S, 'description');
}
;

-------------------------------------------------------------------------------
--
create procedure AB.WA.show_excerpt(
  in S varchar,
  in words varchar)
{
  return coalesce(search_excerpt (words, cast (S as varchar)), '');
}
;

-------------------------------------------------------------------------------
--
-- Date / Time functions
--
-------------------------------------------------------------------------------
-- returns system time in GMT
--
create procedure AB.WA.dt_current_time()
{
  return dateadd('minute', - timezone(now()), now());
}
;

-------------------------------------------------------------------------------
--
-- convert from GMT date to user timezone;
--
create procedure AB.WA.dt_gmt2user(
  in pDate datetime,
  in pUser varchar := null)
{
  declare tz integer;

  if (isnull (pDate))
    return null;
  if (isnull (pUser))
    pUser := connection_get('owner_user');
  if (isnull (pUser))
    pUser := connection_get('vspx_user');
  if (isnull (pUser))
    return pDate;
  tz := cast (coalesce(USER_GET_OPTION(pUser, 'TIMEZONE'), timezone(now())/60) as integer) * 60;
  return dateadd('minute', tz, pDate);
}
;

-------------------------------------------------------------------------------
--
-- convert from the user timezone to GMT date
--
create procedure AB.WA.dt_user2gmt(
  in pDate datetime,
  in pUser varchar := null)
{
  declare tz integer;

  if (isnull (pDate))
    return null;
  if (isnull (pUser))
    pUser := connection_get('owner_user');
  if (isnull (pUser))
    pUser := connection_get('vspx_user');
  if (isnull (pUser))
    return pDate;
  tz := cast (coalesce(USER_GET_OPTION(pUser, 'TIMEZONE'), 0) as integer) * 60;
  return dateadd('minute', -tz, pDate);
}
;

-----------------------------------------------------------------------------
--
create procedure AB.WA.dt_value (
  in pDate datetime,
  in pUser datetime := null)
{
  if (isnull (pDate))
    return pDate;
  pDate := AB.WA.dt_gmt2user(pDate, pUser);
  if (AB.WA.dt_format(pDate, 'D.M.Y') = AB.WA.dt_format(now(), 'D.M.Y'))
    return concat('today ', AB.WA.dt_format(pDate, 'H:N'));
  return AB.WA.dt_format(pDate, 'D.M.Y H:N');
}
;

-----------------------------------------------------------------------------
--
create procedure AB.WA.dt_date (
  in pDate datetime,
  in pUser datetime := null)
{
  if (isnull (pDate))
    return pDate;
  pDate := AB.WA.dt_gmt2user(pDate, pUser);
  return AB.WA.dt_format(pDate, 'D.M.Y');
}
;

-----------------------------------------------------------------------------
--
create procedure AB.WA.dt_format(
  in pDate datetime,
  in pFormat varchar := 'd.m.Y')
{
  declare N integer;
  declare ch, S varchar;

  declare exit handler for sqlstate '*' {
    return '';
  };

  S := '';
  N := 1;
  while (N <= length(pFormat))
  {
    ch := substring(pFormat, N, 1);
    if (ch = 'M')
    {
      S := concat(S, xslt_format_number(month(pDate), '00'));
    } else {
      if (ch = 'm')
      {
        S := concat(S, xslt_format_number(month(pDate), '##'));
      } else
      {
        if (ch = 'Y')
        {
          S := concat(S, xslt_format_number(year(pDate), '0000'));
        } else
        {
          if (ch = 'y')
          {
            S := concat(S, substring(xslt_format_number(year(pDate), '0000'),3,2));
          } else {
            if (ch = 'd')
            {
              S := concat(S, xslt_format_number(dayofmonth(pDate), '##'));
            } else
            {
              if (ch = 'D')
              {
                S := concat(S, xslt_format_number(dayofmonth(pDate), '00'));
              } else
              {
                if (ch = 'H')
                {
                  S := concat(S, xslt_format_number(hour(pDate), '00'));
                } else
                {
                  if (ch = 'h')
                  {
                    S := concat(S, xslt_format_number(hour(pDate), '##'));
                  } else
                  {
                    if (ch = 'N')
                    {
                      S := concat(S, xslt_format_number(minute(pDate), '00'));
                    } else
                    {
                      if (ch = 'n')
                      {
                        S := concat(S, xslt_format_number(minute(pDate), '##'));
                      } else
                      {
                        if (ch = 'S')
                        {
                          S := concat(S, xslt_format_number(second(pDate), '00'));
                        } else
                        {
                          if (ch = 's')
                          {
                            S := concat(S, xslt_format_number(second(pDate), '##'));
                          } else
                          {
                            S := concat(S, ch);
                          };
                        };
                      };
                    };
                  };
                };
              };
            };
          };
        };
      };
    };
    N := N + 1;
  };
  return S;
}
;

-----------------------------------------------------------------------------------------
--
create procedure AB.WA.dt_deformat(
  in pString varchar,
  in pFormat varchar := 'd.m.Y')
{
  declare y, m, d integer;
  declare N, I integer;
  declare ch varchar;

  N := 1;
  I := 0;
  d := 0;
  m := 0;
  y := 0;
  while (N <= length(pFormat)) {
    ch := upper(substring(pFormat, N, 1));
    if (ch = 'M')
      m := AB.WA.dt_deformat_tmp(pString, I);
    if (ch = 'D')
      d := AB.WA.dt_deformat_tmp(pString, I);
    if (ch = 'Y') {
      y := AB.WA.dt_deformat_tmp(pString, I);
      if (y < 50)
        y := 2000 + y;
      if (y < 100)
        y := 1900 + y;
    };
    N := N + 1;
  };
  return stringdate(concat(cast (m as varchar), '.', cast (d as varchar), '.', cast (y as varchar)));
}
;

-----------------------------------------------------------------------------
--
create procedure AB.WA.dt_deformat_tmp(
  in S varchar,
  inout N varchar)
{
  declare
    V any;

  V := regexp_parse('[0-9]+', S, N);
  if (length(V) > 1) {
    N := aref(V,1);
    return atoi(subseq(S, aref(V, 0), aref(V,1)));
  };
  N := N + 1;
  return 0;
}
;

-----------------------------------------------------------------------------
--
create procedure AB.WA.dt_reformat(
  in pString varchar,
  in pInFormat varchar := 'd.m.Y',
  in pOutFormat varchar := 'm.d.Y')
{
  return AB.WA.dt_format(AB.WA.dt_deformat(pString, pInFormat), pOutFormat);
};

-----------------------------------------------------------------------------------------
--
create procedure AB.WA.dt_convert(
  in pString varchar,
  in pDefault any := null)
{
  declare exit handler for sqlstate '*' { goto _next; };
  return stringdate(pString);
_next:
  declare exit handler for sqlstate '*' { goto _end; };
  return http_string_date(pString);

_end:
  return pDefault;
}
;

-----------------------------------------------------------------------------------------
--
create procedure AB.WA.dt_rfc1123 (
  in dt datetime)
{
  return soap_print_box (dt, '', 1);
}
;

-----------------------------------------------------------------------------------------
--
create procedure AB.WA.dt_iso8601 (
  in dt datetime)
{
  return soap_print_box (dt, '', 0);
}
;

-----------------------------------------------------------------------------------------
--
create procedure AB.WA.test_clear (
  in S any)
{
  declare N integer;

  return substring(S, 1, coalesce(strstr(S, '<>'), length(S)));
}
;

-----------------------------------------------------------------------------------------
--
create procedure AB.WA.test (
  in value any,
  in params any := null)
{
  declare valueType, valueClass, valueName, valueMessage, tmp any;

  declare exit handler for SQLSTATE '*' {
    if (not is_empty_or_null(valueMessage))
      signal ('TEST', valueMessage);
    if (__SQL_STATE = 'EMPTY')
      signal ('TEST', sprintf ('Field ''%s'' cannot be empty!<>', valueName));
    if (__SQL_STATE = 'CLASS') {
      if (valueType in ('free-text', 'tags')) {
        signal ('TEST', sprintf ('Field ''%s'' contains invalid characters or noise words!<>', valueName));
      } else {
        signal ('TEST', sprintf ('Field ''%s'' contains invalid characters!<>', valueName));
      }
    }
    if (__SQL_STATE = 'TYPE')
      signal ('TEST', sprintf ('Field ''%s'' contains invalid characters for \'%s\'!<>', valueName, valueType));
    if (__SQL_STATE = 'MIN')
      signal ('TEST', sprintf ('''%s'' value should be greater then %s!<>', valueName, cast (tmp as varchar)));
    if (__SQL_STATE = 'MAX')
      signal ('TEST', sprintf ('''%s'' value should be less then %s!<>', valueName, cast (tmp as varchar)));
    if (__SQL_STATE = 'MINLENGTH')
      signal ('TEST', sprintf ('The length of field ''%s'' should be greater then %s characters!<>', valueName, cast (tmp as varchar)));
    if (__SQL_STATE = 'MAXLENGTH')
      signal ('TEST', sprintf ('The length of field ''%s'' should be less then %s characters!<>', valueName, cast (tmp as varchar)));
    if (__SQL_STATE = 'SPECIAL')
      signal ('TEST', __SQL_MESSAGE || '<>');
    signal ('TEST', 'Unknown validation error!<>');
    --resignal;
  };

  value := trim(value);
  if (is_empty_or_null(params))
    return value;

  valueClass := coalesce(get_keyword('class', params), get_keyword('type', params));
  valueType := coalesce(get_keyword('type', params), get_keyword('class', params));
  valueName := get_keyword('name', params, 'Field');
  valueMessage := get_keyword('message', params, '');
  tmp := get_keyword('canEmpty', params);
  if (isnull (tmp)) {
    if (not isnull (get_keyword('minValue', params))) {
      tmp := 0;
    } else if (get_keyword('minLength', params, 0) <> 0) {
      tmp := 0;
    }
  }
  if (not isnull (tmp) and (tmp = 0) and is_empty_or_null (value)) {
    signal('EMPTY', '');
  } else if (is_empty_or_null(value)) {
    return value;
  }

  value := AB.WA.validate2 (valueClass, value);

  if (valueType = 'integer') {
    tmp := get_keyword('minValue', params);
    if ((not isnull (tmp)) and (value < tmp))
      signal('MIN', cast (tmp as varchar));

    tmp := get_keyword('maxValue', params);
    if (not isnull (tmp) and (value > tmp))
      signal('MAX', cast (tmp as varchar));

  } else if (valueType = 'float') {
    tmp := get_keyword('minValue', params);
    if (not isnull (tmp) and (value < tmp))
      signal('MIN', cast (tmp as varchar));

    tmp := get_keyword('maxValue', params);
    if (not isnull (tmp) and (value > tmp))
      signal('MAX', cast (tmp as varchar));

  } else if (valueType = 'varchar') {
    tmp := get_keyword('minLength', params);
    if (not isnull (tmp) and (length(AB.WA.utf2wide(value)) < tmp))
      signal('MINLENGTH', cast (tmp as varchar));

    tmp := get_keyword('maxLength', params);
    if (not isnull (tmp) and (length(AB.WA.utf2wide(value)) > tmp))
      signal('MAXLENGTH', cast (tmp as varchar));
  }
  return value;
}
;

-----------------------------------------------------------------------------------------
--
create procedure AB.WA.validate2 (
  in propertyType varchar,
  in propertyValue varchar)
{
  declare exit handler for SQLSTATE '*' {
    if (__SQL_STATE = 'CLASS')
      resignal;
    if (__SQL_STATE = 'SPECIAL')
      resignal;
    signal('TYPE', propertyType);
    return;
  };

  if (propertyType = 'boolean') {
    if (propertyValue not in ('Yes', 'No'))
      goto _error;
  } else if (propertyType = 'integer') {
    if (isnull (regexp_match('^[0-9]+\$', propertyValue)))
      goto _error;
    return cast (propertyValue as integer);
  } else if (propertyType = 'float') {
    if (isnull (regexp_match('^[-+]?([0-9]*\.)?[0-9]+([eE][-+]?[0-9]+)?\$', propertyValue)))
      goto _error;
    return cast (propertyValue as float);
  } else if (propertyType = 'dateTime') {
    if (isnull (regexp_match('^((?:19|20)[0-9][0-9])[- /.](0[1-9]|1[012])[- /.](0[1-9]|[12][0-9]|3[01]) ([01]?[0-9]|[2][0-3])(:[0-5][0-9])?\$', propertyValue)))
      goto _error;
    return cast (propertyValue as datetime);
  } else if (propertyType = 'dateTime2') {
    if (isnull (regexp_match('^((?:19|20)[0-9][0-9])[- /.](0[1-9]|1[012])[- /.](0[1-9]|[12][0-9]|3[01]) ([01]?[0-9]|[2][0-3])(:[0-5][0-9])?\$', propertyValue)))
      goto _error;
    return cast (propertyValue as datetime);
  } else if (propertyType = 'date') {
    if (isnull (regexp_match('^((?:19|20)[0-9][0-9])[- /.](0[1-9]|1[012])[- /.](0[1-9]|[12][0-9]|3[01])\$', propertyValue)))
      goto _error;
    return cast (propertyValue as datetime);
  } else if (propertyType = 'date2') {
    if (isnull (regexp_match('^(0[1-9]|[12][0-9]|3[01])[- /.](0[1-9]|1[012])[- /.]((?:19|20)[0-9][0-9])\$', propertyValue)))
      goto _error;
    return stringdate(AB.WA.dt_reformat(propertyValue, 'd.m.Y', 'Y-M-D'));
  } else if (propertyType = 'time') {
    if (isnull (regexp_match('^([01]?[0-9]|[2][0-3])(:[0-5][0-9])?\$', propertyValue)))
      goto _error;
    return cast (propertyValue as time);
  } else if (propertyType = 'folder') {
    if (isnull (regexp_match('^[^\\\/\?\*\"\'\>\<\:\|]*\$', propertyValue)))
      goto _error;
  } else if ((propertyType = 'uri') or (propertyType = 'anyuri')) {
    if (isnull (regexp_match('^(ht|f)tp(s?)\:\/\/[0-9a-zA-Z]([-.\w]*[0-9a-zA-Z])*(:(0-9)*)*(\/?)([a-zA-Z0-9\-\.\?\,\'\/\\\+&amp;%\$#_=:]*)?\$', propertyValue)))
      goto _error;
  } else if (propertyType = 'email') {
    if (isnull (regexp_match('^([a-zA-Z0-9_\-])+(\.([a-zA-Z0-9_\-])+)*@((\[(((([0-1])?([0-9])?[0-9])|(2[0-4][0-9])|(2[0-5][0-5])))\.(((([0-1])?([0-9])?[0-9])|(2[0-4][0-9])|(2[0-5][0-5])))\.(((([0-1])?([0-9])?[0-9])|(2[0-4][0-9])|(2[0-5][0-5])))\.(((([0-1])?([0-9])?[0-9])|(2[0-4][0-9])|(2[0-5][0-5]))\]))|((([a-zA-Z0-9])+(([\-])+([a-zA-Z0-9])+)*\.)+([a-zA-Z])+(([\-])+([a-zA-Z0-9])+)*))\$', propertyValue)))
      goto _error;
  } else if (propertyType = 'free-text') {
    if (length(propertyValue))
      if (not AB.WA.validate_freeTexts(propertyValue))
        goto _error;
  } else if (propertyType = 'free-text-expression') {
    if (length(propertyValue))
      if (not AB.WA.validate_freeText(propertyValue))
        goto _error;
  } else if (propertyType = 'tags') {
    if (not AB.WA.validate_tags(propertyValue))
      goto _error;
  }
  return propertyValue;

_error:
  signal('CLASS', propertyType);
}
;

-----------------------------------------------------------------------------------------
--
create procedure AB.WA.validate (
  in propertyType varchar,
  in propertyValue varchar,
  in propertyEmpty integer := 1)
{
  if (is_empty_or_null(propertyValue))
    return propertyEmpty;

  declare tmp any;
  declare exit handler for SQLSTATE '*' {return 0;};

  if (propertyType = 'boolean') {
    if (propertyValue not in ('Yes', 'No'))
      return 0;
  } else if (propertyType = 'integer') {
    if (isnull (regexp_match('^[0-9]+\$', propertyValue)))
      return 0;
    tmp := cast (propertyValue as integer);
  } else if (propertyType = 'float') {
    if (isnull (regexp_match('^[-+]?([0-9]*\.)?[0-9]+([eE][-+]?[0-9]+)?\$', propertyValue)))
      return 0;
    tmp := cast (propertyValue as float);
  } else if (propertyType = 'dateTime') {
    if (isnull (regexp_match('^((?:19|20)[0-9][0-9])[- /.](0[1-9]|1[012])[- /.](0[1-9]|[12][0-9]|3[01]) ([01]?[0-9]|[2][0-3])(:[0-5][0-9])?\$', propertyValue)))
      return 0;
  } else if (propertyType = 'dateTime2') {
    if (isnull (regexp_match('^((?:19|20)[0-9][0-9])[- /.](0[1-9]|1[012])[- /.](0[1-9]|[12][0-9]|3[01]) ([01]?[0-9]|[2][0-3])(:[0-5][0-9])?\$', propertyValue)))
      return 0;
  } else if (propertyType = 'date') {
    if (isnull (regexp_match('^((?:19|20)[0-9][0-9])[- /.](0[1-9]|1[012])[- /.](0[1-9]|[12][0-9]|3[01])\$', propertyValue)))
      return 0;
  } else if (propertyType = 'date2') {
    if (isnull (regexp_match('^(0[1-9]|[12][0-9]|3[01])[- /.](0[1-9]|1[012])[- /.]((?:19|20)[0-9][0-9])\$', propertyValue)))
      return 0;
  } else if (propertyType = 'time') {
    if (isnull (regexp_match('^([01]?[0-9]|[2][0-3])(:[0-5][0-9])?\$', propertyValue)))
      return 0;
  } else if (propertyType = 'folder') {
    if (isnull (regexp_match('^[^\\\/\?\*\"\'\>\<\:\|]*\$', propertyValue)))
      return 0;
  } else if (propertyType = 'uri') {
    if (isnull (regexp_match('^(ht|f)tp(s?)\:\/\/[0-9a-zA-Z]([-.\w]*[0-9a-zA-Z])*(:(0-9)*)*(\/?)([a-zA-Z0-9\-\.\?\,\'\/\\\+&amp;%\$#_]*)?\$', propertyValue)))
      return 0;
  }
  return 1;
}
;

-----------------------------------------------------------------------------------------
--
create procedure AB.WA.validate_freeText (
  in S varchar)
{
  declare st, msg varchar;

  if (upper(S) in ('AND', 'NOT', 'NEAR', 'OR'))
    return 0;
  if (length (S) < 2)
    return 0;
  if (vt_is_noise (AB.WA.wide2utf(S), 'utf-8', 'x-ViDoc'))
    return 0;
  st := '00000';
  exec (sprintf ('vt_parse (\'[__lang "x-ViDoc" __enc "utf-8"] %s\')', S), st, msg, vector ());
  if (st <> '00000')
    return 0;
  return 1;
}
;

-----------------------------------------------------------------------------------------
--
create procedure AB.WA.validate_freeTexts (
  in S any)
{
  declare w varchar;

  w := regexp_match ('["][^"]+["]|[''][^'']+['']|[^"'' ]+', S, 1);
  while (w is not null) {
    w := trim (w, '"'' ');
    if (not AB.WA.validate_freeText(w))
      return 0;
    w := regexp_match ('["][^"]+["]|[''][^'']+['']|[^"'' ]+', S, 1);
  }
  return 1;
}
;

-----------------------------------------------------------------------------------------
--
create procedure AB.WA.validate_tag (
  in T varchar)
{
  declare S any;
  
  S := T;
  S := replace (trim(S), '+', '_');
  S := replace (trim(S), ' ', '_');
  if (not AB.WA.validate_freeText(S))
    return 0;
  if (not isnull (strstr(S, '"')))
    return 0;
  if (not isnull (strstr(S, '''')))
    return 0;
  if (length(S) < 2)
    return 0;
  if (length(S) > 50)
    return 0;
  return 1;
}
;

-----------------------------------------------------------------------------------------
--
create procedure AB.WA.validate_tags (
  in S varchar)
{
  declare N integer;
  declare V any;

  V := AB.WA.tags2vector(S);
  if (is_empty_or_null(V))
    return 0;
  if (length(V) <> length(AB.WA.tags2unique(V)))
    return 0;
  for (N := 0; N < length(V); N := N + 1)
    if (not AB.WA.validate_tag(V[N]))
      return 0;
  return 1;
}
;

-------------------------------------------------------------------------------
--
create procedure AB.WA.ab_sparql (
  in sql varchar)
{
  declare st, msg, meta, rows any;

  st := '00000';
  exec (sql, st, msg, vector (), 0, meta, rows);
  if ('00000' = st)
    return rows;
  return vector ();
}
;

-------------------------------------------------------------------------------
--
create procedure AB.WA.dashboard_get(
  in domain_id integer,
  in user_id integer)
{
  declare ses any;

  ses := string_output ();
  http ('<ab-db>', ses);
  for select top 10 *
        from (select a.P_NAME,
                     SIOC..addressbook_contact_iri (domain_id, P_ID) P_URI,
                     coalesce (a.P_UPDATED, now ()) P_UPDATED
                from AB.WA.PERSONS a,
                     DB.DBA.WA_INSTANCE b,
                     DB.DBA.WA_MEMBER c
                where a.P_DOMAIN_ID = domain_id
                  and b.WAI_ID = a.P_DOMAIN_ID
                  and c.WAM_INST = b.WAI_NAME
                  and c.WAM_USER = user_id
                order by a.P_UPDATED desc
             ) x do {

    declare uname, full_name varchar;

    uname := (select coalesce (U_NAME, '') from DB.DBA.SYS_USERS where U_ID = user_id);
    full_name := (select coalesce (coalesce (U_FULL_NAME, U_NAME), '') from DB.DBA.SYS_USERS where U_ID = user_id);

    http ('<ab>', ses);
    http (sprintf ('<dt>%s</dt>', date_iso8601 (P_UPDATED)), ses);
    http (sprintf ('<title><![CDATA[%s]]></title>', P_NAME), ses);
    http (sprintf ('<link><![CDATA[%s]]></link>', P_URI), ses);
    http (sprintf ('<from><![CDATA[%s]]></from>', full_name), ses);
    http (sprintf ('<uid>%s</uid>', uname), ses);
    http ('</ab>', ses);
  }
  http ('</ab-db>', ses);
  return string_output_string (ses);
}
;

-------------------------------------------------------------------------------
--
create procedure AB.WA.settings (
  inout account_id integer)
{
  return coalesce((select deserialize(blob_to_string(S_DATA)) from AB.WA.SETTINGS where S_ACCOUNT_ID = account_id), vector());
}
;

-------------------------------------------------------------------------------
--
create procedure AB.WA.settings_rows (
  in settings any)
{
  return cast (get_keyword('rows', settings, '10') as integer);
}
;

-------------------------------------------------------------------------------
--
create procedure AB.WA.settings_atomVersion (
  in settings any)
{
  return get_keyword('atomVersion', settings, '1.0');
}
;

-----------------------------------------------------------------------------------------
--
-- Contacts
--
-----------------------------------------------------------------------------------------
create procedure AB.WA.contact_update (
  in id integer,
  in domain_id integer,
  in kind integer,
  in name varchar,
  in title varchar,
  in fName varchar,
  in mName varchar,
  in lName varchar,
  in fullName varchar,
  in gender varchar,
  in birthday datetime,
  in foaf varchar,
  in mail varchar,
  in web varchar,
  in icq varchar,
  in skype varchar,
  in aim varchar,
  in yahoo varchar,
  in msn varchar,
  in hCountry varchar,
  in hState varchar,
  in hCity varchar,
  in hCode varchar,
  in hAddress1 varchar,
  in hAddress2 varchar,
  in hTzone varchar,
  in hLat real,
  in hLng real,
  in hPhone varchar,
  in hMobile varchar,
  in hFax varchar,
  in hMail varchar,
  in hWeb varchar,
  in bCountry varchar,
  in bState varchar,
  in bCity varchar,
  in bCode varchar,
  in bAddress1 varchar,
  in bAddress2 varchar,
  in bTzone varchar,
  in bLat real,
  in bLng real,
  in bPhone varchar,
  in bMobile varchar,
  in bFax varchar,
  in bIndustry varchar,
  in bOrganization varchar,
  in bDepartment varchar,
  in bJob varchar,
  in bMail varchar,
  in bWeb varchar,
  in tags varchar)
{
  if (id = -1) {
    id := sequence_next ('AB.WA.contact_id');
    insert into AB.WA.PERSONS
      (
        P_ID,
        P_DOMAIN_ID,
        P_KIND,
        P_NAME,
        P_TITLE,
        P_FIRST_NAME,
        P_MIDDLE_NAME,
        P_LAST_NAME,
        P_FULL_NAME,
        P_GENDER,
        P_BIRTHDAY,
        P_FOAF,
        P_MAIL,
        P_WEB,
        P_ICQ,
        P_SKYPE,
        P_AIM,
        P_YAHOO,
        P_MSN,
        P_H_COUNTRY,
        P_H_STATE,
        P_H_CITY,
        P_H_CODE,
        P_H_ADDRESS1,
        P_H_ADDRESS2,
        P_H_TZONE,
        P_H_LAT,
        P_H_LNG,
        P_H_PHONE,
        P_H_MOBILE,
        P_H_FAX,
        P_H_MAIL,
        P_H_WEB,
        P_B_COUNTRY,
        P_B_STATE,
        P_B_CITY,
        P_B_CODE,
        P_B_ADDRESS1,
        P_B_ADDRESS2,
        P_B_TZONE,
        P_B_LAT,
        P_B_LNG,
        P_B_PHONE,
        P_B_MOBILE,
        P_B_FAX,
        P_B_INDUSTRY,
        P_B_ORGANIZATION,
        P_B_DEPARTMENT,
        P_B_JOB,
        P_B_MAIL,
        P_B_WEB,
        P_TAGS,
        P_CREATED,
        P_UPDATED
      )
      values (
        id,
        domain_id,
        kind,
        name,
        title,
        fName,
        mName,
        lName,
        fullName,
        gender,
        birthday,
        foaf,
        mail,
        web,
        icq,
        skype,
        aim,
        yahoo,
        msn,
        hCountry,
        hState,
        hCity,
        hCode,
        hAddress1,
        hAddress2,
        hTzone,
        hLat,
        hLng,
        hPhone,
        hMobile,
        hFax,
        hMail,
        hWeb,
        bCountry,
        bState,
        bCity,
        bCode,
        bAddress1,
        bAddress2,
        bTzone,
        bLat,
        bLng,
        bPhone,
        bMobile,
        bFax,
        bIndustry,
        bOrganization,
        bDepartment,
        bJob,
        bMail,
        bWeb,
        tags,
        now (),
        now ()
      );
  } else {
    update AB.WA.PERSONS
       set P_KIND = kind,
           P_NAME = name,
           P_TITLE = title,
           P_FIRST_NAME = fName,
           P_MIDDLE_NAME = mName,
           P_LAST_NAME = lName,
           P_FULL_NAME = fullName,
           P_GENDER = gender,
           P_BIRTHDAY = birthday,
           P_FOAF = foaf,
           P_MAIL = mail,
           P_WEB = web,
           P_ICQ = icq,
           P_SKYPE = skype,
           P_AIM = aim,
           P_YAHOO = yahoo,
           P_MSN = msn,
           P_H_ADDRESS1 = hAddress1,
           P_H_ADDRESS2 = hAddress2,
           P_H_CODE = hCode,
           P_H_CITY = hCity,
           P_H_STATE = hState,
           P_H_COUNTRY = hCountry,
           P_H_TZONE = hTzone,
           P_H_LAT = hLat,
           P_H_LNG = hLng,
           P_H_PHONE = hPhone,
           P_H_MOBILE = hMobile,
           P_H_FAX = hFax,
           P_H_MAIL = hMail,
           P_H_WEB = hWeb,
           P_B_ADDRESS1 = bAddress1,
           P_B_ADDRESS2 = bAddress2,
           P_B_CODE = bCode,
           P_B_CITY = bCity,
           P_B_STATE = bState,
           P_B_COUNTRY = bCountry,
           P_B_TZONE = bTzone,
           P_B_LAT = bLat,
           P_B_LNG = bLng,
           P_B_PHONE = bPhone,
           P_B_MOBILE = bMobile,
           P_B_FAX = bFax,
           P_B_INDUSTRY = bIndustry,
           P_B_ORGANIZATION = bOrganization,
           P_B_DEPARTMENT = bDepartment,
           P_B_JOB = bJob,
           P_B_MAIL = bMail,
           P_B_WEB = bWeb,
           P_TAGS = tags,
           P_UPDATED = now()
     where P_ID = id and
           P_DOMAIN_ID = domain_id;
  }
  return id;
}
;

-------------------------------------------------------------------------------
--
create procedure AB.WA.contact_update2 (
  in id integer,
  in domain_id integer,
  in pName varchar,
  in pValue any)
{
  if ((id = -1) and (pName = 'P_NAME')) {
    id := sequence_next ('AB.WA.contact_id');
    insert into AB.WA.PERSONS
      (
        P_ID,
        P_DOMAIN_ID,
        P_NAME,
        P_CREATED,
        P_UPDATED
      )
      values
      (
        id,
        domain_id,
        pValue,
        now (),
        now ()
      );
    return id;
  }
  if (id <> -1) {
    if (pName = 'P_KIND')
      update AB.WA.PERSONS set P_KIND = pValue where P_ID = id;
    if (pName = 'P_NAME')
      update AB.WA.PERSONS set P_NAME = pValue where P_ID = id;
    if (pName = 'P_TITLE')
      update AB.WA.PERSONS set P_TITLE = pValue where P_ID = id;
    if (pName = 'P_FIRST_NAME')
      update AB.WA.PERSONS set P_FIRST_NAME = pValue where P_ID = id;
    if (pName = 'P_MIDDLE_NAME')
      update AB.WA.PERSONS set P_MIDDLE_NAME = pValue where P_ID = id;
    if (pName = 'P_LAST_NAME')
      update AB.WA.PERSONS set P_LAST_NAME = pValue where P_ID = id;
    if (pName = 'P_FULL_NAME')
      update AB.WA.PERSONS set P_FULL_NAME = pValue where P_ID = id;
    if (pName = 'P_GENDER')
      update AB.WA.PERSONS set P_GENDER = pValue where P_ID = id;
    if (pName = 'P_BIRTHDAY')
      update AB.WA.PERSONS set P_BIRTHDAY = pValue where P_ID = id;
    if (pName = 'P_FOAF')
      update AB.WA.PERSONS set P_FOAF = pValue where P_ID = id;
    if (pName = 'P_MAIL')
      update AB.WA.PERSONS set P_MAIL = pValue where P_ID = id;
    if (pName = 'P_WEB')
      update AB.WA.PERSONS set P_WEB = pValue where P_ID = id;
    if (pName = 'P_ICQ')
      update AB.WA.PERSONS set P_ICQ = pValue where P_ID = id;
    if (pName = 'P_SKYPE')
      update AB.WA.PERSONS set P_SKYPE = pValue where P_ID = id;
    if (pName = 'P_AIM')
      update AB.WA.PERSONS set P_AIM = pValue where P_ID = id;
    if (pName = 'P_YAHOO')
      update AB.WA.PERSONS set P_YAHOO = pValue where P_ID = id;
    if (pName = 'P_MSN')
      update AB.WA.PERSONS set P_MSN = pValue where P_ID = id;

    if (pName = 'P_H_ADDRESS1')
      update AB.WA.PERSONS set P_H_ADDRESS1 = pValue where P_ID = id;
    if (pName = 'P_H_ADDRESS2')
      update AB.WA.PERSONS set P_H_ADDRESS2 = pValue where P_ID = id;
    if (pName = 'P_H_CODE')
      update AB.WA.PERSONS set P_H_CODE = pValue where P_ID = id;
    if (pName = 'P_H_CITY')
      update AB.WA.PERSONS set P_H_CITY = pValue where P_ID = id;
    if (pName = 'P_H_STATE')
      update AB.WA.PERSONS set P_H_STATE = pValue where P_ID = id;
    if (pName = 'P_H_COUNTRY')
      update AB.WA.PERSONS set P_H_COUNTRY = pValue where P_ID = id;
    if (pName = 'P_H_TZONE')
      update AB.WA.PERSONS set P_H_TZONE = pValue where P_ID = id;
    if (pName = 'P_H_LAT')
      update AB.WA.PERSONS set P_H_LAT = pValue where P_ID = id;
    if (pName = 'P_H_LNG')
      update AB.WA.PERSONS set P_H_LNG = pValue where P_ID = id;
    if (pName = 'P_H_PHONE')
      update AB.WA.PERSONS set P_H_PHONE = pValue where P_ID = id;
    if (pName = 'P_H_MOBILE')
      update AB.WA.PERSONS set P_H_MOBILE = pValue where P_ID = id;
    if (pName = 'P_H_FAX')
      update AB.WA.PERSONS set P_H_FAX = pValue where P_ID = id;
    if (pName = 'P_H_MAIL')
      update AB.WA.PERSONS set P_H_MAIL = pValue where P_ID = id;
    if (pName = 'P_H_WEB')
      update AB.WA.PERSONS set P_H_WEB = pValue where P_ID = id;

    if (pName = 'P_B_ADDRESS1')
      update AB.WA.PERSONS set P_B_ADDRESS1 = pValue where P_ID = id;
    if (pName = 'P_B_ADDRESS2')
      update AB.WA.PERSONS set P_B_ADDRESS2 = pValue where P_ID = id;
    if (pName = 'P_B_CODE')
      update AB.WA.PERSONS set P_B_CODE = pValue where P_ID = id;
    if (pName = 'P_B_CITY')
      update AB.WA.PERSONS set P_B_CITY = pValue where P_ID = id;
    if (pName = 'P_B_STATE')
      update AB.WA.PERSONS set P_B_STATE = pValue where P_ID = id;
    if (pName = 'P_B_COUNTRY')
      update AB.WA.PERSONS set P_B_COUNTRY = pValue where P_ID = id;
    if (pName = 'P_B_TZONE')
      update AB.WA.PERSONS set P_B_TZONE = pValue where P_ID = id;
    if (pName = 'P_B_LAT')
      update AB.WA.PERSONS set P_B_LAT = pValue where P_ID = id;
    if (pName = 'P_B_LNG')
      update AB.WA.PERSONS set P_B_LNG = pValue where P_ID = id;
    if (pName = 'P_B_PHONE')
      update AB.WA.PERSONS set P_B_PHONE = pValue where P_ID = id;
    if (pName = 'P_B_MOBILE')
      update AB.WA.PERSONS set P_B_MOBILE = pValue where P_ID = id;
    if (pName = 'P_B_FAX')
      update AB.WA.PERSONS set P_B_FAX = pValue where P_ID = id;
    if (pName = 'P_B_MAIL')
      update AB.WA.PERSONS set P_B_MAIL = pValue where P_ID = id;
    if (pName = 'P_B_WEB')
      update AB.WA.PERSONS set P_B_WEB = pValue where P_ID = id;
    if (pName = 'P_B_ORGANIZATION')
      update AB.WA.PERSONS set P_B_ORGANIZATION = pValue where P_ID = id;
    if (pName = 'P_B_DEPARTMENT')
      update AB.WA.PERSONS set P_B_DEPARTMENT = pValue where P_ID = id;
    if (pName = 'P_B_JOB')
      update AB.WA.PERSONS set P_B_JOB = pValue where P_ID = id;
    update AB.WA.PERSONS set P_UPDATED = now () where P_ID = id;
  }
  return id;
}
;

-------------------------------------------------------------------------------
--
create procedure AB.WA.contact_update3 (
  in id integer,
  in domain_id integer,
  in pFields any,
  in pValues any,
  in tags varchar)
{
  declare N varchar;
  declare S varchar;
  declare st, msg, meta, rows any;

  if (tags <> '') {
    pFields := vector_concat (pFields, vector ('P_TAGS'));
    pValues := vector_concat (pValues, vector (tags));
  }
  S := 'P_UPDATED = now () ';
  for (N := 0; N < length (pFields); N := N + 1)
    S := S || ', ' || pFields[N] || ' = ?';
  S := trim (S, ',');
  if (S <> '') {
    S := 'update AB.WA.PERSONS set ' || S || ' where P_ID = ' || cast (id as varchar);
    exec (S, st, msg, pValues, 0, meta, rows);
  }
}
;

-------------------------------------------------------------------------------
--
create procedure AB.WA.contact_update4 (
  in id integer,
  in domain_id integer,
  in pFields any,
  in pValues any,
  in tags varchar,
  in validation any)
{
  declare N, M varchar;
  declare S varchar;
  declare st, msg, meta, rows, F, V any;

  if (not isnull (validation) and length (validation)) {
    S := sprintf ('select P_ID from AB.WA.PERSONS where P_DOMAIN_ID = %d', domain_id);
    V := vector ();
    for (N := 0; N < length (validation); N := N + 1) {
      M := AB.WA.vector_index (pFields, validation [N]);
      if (not isnull (M)) {
        if (not is_empty_or_null (pValues [M])) {
          S := S || sprintf (' and %s = ?', pFields [M]);
          V := vector_concat (V, vector (pValues [M]));
        }
      }
    }
    if (length (V) = length (validation)) {
      st := '00000';
      exec (S, st, msg, V, 0, meta, rows);
      if ((st = '00000') and (length (rows) > 0)) {
        V := vector ();
        F := vector ();
        for (N := 0; N < length (pFields); N := N + 1) {
          if (not AB.WA.vector_contains (validation, pFields [N])) {
            F := vector_concat (F, vector (pFields [N]));
            V := vector_concat (V, vector (pValues [N]));
          }
        }
        pFields := F;
        pValues := V;

        id := vector ();
        for (N := 0; N < length (rows); N := N + 1)
          id := vector_concat (id, vector (rows [N][0]));
      }
    }
  }

  if (isinteger (id) and (id = -1)) {
    for (N := 0; N < length (pFields); N := N + 1)
      if (pFields [N] = 'P_NAME') {
        id := AB.WA.contact_update2 (id, domain_id, pFields [N], pValues [N]);
        goto _exit;
      }
  _exit:;
    if (isinteger (id) and (id = -1))
      return 0;

    V := vector ();
    F := vector ();
    for (N := 0; N < length (pFields); N := N + 1) {
      if ('P_NAME' <> pFields [N]) {
        F := vector_concat (F, vector (pFields [N]));
        V := vector_concat (V, vector (pValues [N]));
      }
    }
    pFields := F;
    pValues := V;

    id := vector (id);
  }

  for (N := 0; N < length (id); N := N + 1)
    AB.WA.contact_update3 (id[N], domain_id, pFields, pValues, tags);

  return length (id);
}
;

-------------------------------------------------------------------------------
--
create procedure AB.WA.contact_field (
  in id integer,
  in domain_id integer,
  in pName varchar)
{
  if (pName = 'P_NAME')
    return (select P_NAME from AB.WA.PERSONS where P_ID = id);
  if (pName = 'P_TITLE')
    return (select P_TITLE from AB.WA.PERSONS where P_ID = id);
  if (pName = 'P_FIRST_NAME')
    return (select P_FIRST_NAME from AB.WA.PERSONS where P_ID = id);
  if (pName = 'P_MIDDLE_NAME')
    return (select P_MIDDLE_NAME from AB.WA.PERSONS where P_ID = id);
  if (pName = 'P_LAST_NAME')
    return (select P_LAST_NAME from AB.WA.PERSONS where P_ID = id);
  if (pName = 'P_FULL_NAME')
    return (select P_FULL_NAME from AB.WA.PERSONS where P_ID = id);
  if (pName = 'P_GENDER')
    return (select P_GENDER from AB.WA.PERSONS where P_ID = id);
  if (pName = 'P_BIRTHDAY')
    return (select P_BIRTHDAY from AB.WA.PERSONS where P_ID = id);
  if (pName = 'P_FOAF')
    return (select P_FOAF from AB.WA.PERSONS where P_ID = id);

  if (pName = 'P_MAIL')
    return (select P_MAIL from AB.WA.PERSONS where P_ID = id);
  if (pName = 'P_WEB')
    return (select P_WEB from AB.WA.PERSONS where P_ID = id);
  if (pName = 'P_ICQ')
    return (select P_ICQ from AB.WA.PERSONS where P_ID = id);
  if (pName = 'P_SKYPE')
    return (select P_SKYPE from AB.WA.PERSONS where P_ID = id);
  if (pName = 'P_AIM')
    return (select P_AIM from AB.WA.PERSONS where P_ID = id);
  if (pName = 'P_YAHOO')
    return (select P_YAHOO from AB.WA.PERSONS where P_ID = id);
  if (pName = 'P_MSN')
    return (select P_MSN from AB.WA.PERSONS where P_ID = id);

  if (pName = 'P_H_ADDRESS1')
    return (select P_H_ADDRESS1 from AB.WA.PERSONS where P_ID = id);
  if (pName = 'P_H_ADDRESS2')
    return (select P_H_ADDRESS2 from AB.WA.PERSONS where P_ID = id);
  if (pName = 'P_H_CODE')
    return (select P_H_CODE from AB.WA.PERSONS where P_ID = id);
  if (pName = 'P_H_CITY')
    return (select P_H_CITY from AB.WA.PERSONS where P_ID = id);
  if (pName = 'P_H_STATE')
    return (select P_H_STATE from AB.WA.PERSONS where P_ID = id);
  if (pName = 'P_H_COUNTRY')
    return (select P_H_COUNTRY from AB.WA.PERSONS where P_ID = id);
  if (pName = 'P_H_TZONE')
    return (select P_H_TZONE from AB.WA.PERSONS where P_ID = id);
  if (pName = 'P_H_LAT')
    return (select P_H_LAT from AB.WA.PERSONS where P_ID = id);
  if (pName = 'P_H_LNG')
    return (select P_H_LNG from AB.WA.PERSONS where P_ID = id);
  if (pName = 'P_H_PHONE')
    return (select P_H_PHONE from AB.WA.PERSONS where P_ID = id);
  if (pName = 'P_H_MOBILE')
    return (select P_H_MOBILE from AB.WA.PERSONS where P_ID = id);
  if (pName = 'P_H_MAIL')
    return (select P_H_MAIL from AB.WA.PERSONS where P_ID = id);
  if (pName = 'P_H_WEB')
    return (select P_H_WEB from AB.WA.PERSONS where P_ID = id);

  if (pName = 'P_B_ADDRESS1')
    return (select P_B_ADDRESS1 from AB.WA.PERSONS where P_ID = id);
  if (pName = 'P_B_ADDRESS2')
    return (select P_B_ADDRESS2 from AB.WA.PERSONS where P_ID = id);
  if (pName = 'P_B_CODE')
    return (select P_B_CODE from AB.WA.PERSONS where P_ID = id);
  if (pName = 'P_B_CITY')
    return (select P_B_CITY from AB.WA.PERSONS where P_ID = id);
  if (pName = 'P_B_STATE')
    return (select P_B_STATE from AB.WA.PERSONS where P_ID = id);
  if (pName = 'P_B_COUNTRY')
    return (select P_B_COUNTRY from AB.WA.PERSONS where P_ID = id);
  if (pName = 'P_B_TZONE')
    return (select P_B_TZONE from AB.WA.PERSONS where P_ID = id);
  if (pName = 'P_B_LAT')
    return (select P_B_LAT from AB.WA.PERSONS where P_ID = id);
  if (pName = 'P_B_LNG')
    return (select P_B_LNG from AB.WA.PERSONS where P_ID = id);
  if (pName = 'P_B_PHONE')
    return (select P_B_PHONE from AB.WA.PERSONS where P_ID = id);
  if (pName = 'P_B_MOBILE')
    return (select P_B_MOBILE from AB.WA.PERSONS where P_ID = id);
  if (pName = 'P_B_MAIL')
    return (select P_B_MAIL from AB.WA.PERSONS where P_ID = id);
  if (pName = 'P_B_WEB')
    return (select P_B_WEB from AB.WA.PERSONS where P_ID = id);
  if (pName = 'P_B_ORGANIZATION')
    return (select P_B_ORGANIZATION from AB.WA.PERSONS where P_ID = id);
  if (pName = 'P_B_JOB')
    return (select P_B_JOB from AB.WA.PERSONS where P_ID = id);

  return null;
}
;

-------------------------------------------------------------------------------
--
create procedure AB.WA.contact_delete (
  in id integer,
  in domain_id integer)
{
  delete from AB.WA.PERSONS where P_ID = id and P_DOMAIN_ID = domain_id;
}
;

-------------------------------------------------------------------------------
--
create procedure AB.WA.contact_tags_select (
  in id integer,
  in domain_id integer)
{
  return coalesce((select P_TAGS from AB.WA.PERSONS where P_ID = id and P_DOMAIN_ID = domain_id), '');
}
;

-------------------------------------------------------------------------------
--
create procedure AB.WA.contact_tags_update (
  in id integer,
  in domain_id integer,
  in tags any)
{
  update AB.WA.PERSONS
     set P_TAGS = tags,
         P_UPDATED = now()
   where P_ID = id and
         P_DOMAIN_ID = domain_id;
}
;

-------------------------------------------------------------------------------
--
create procedure AB.WA.import_vcard (
  in domain_id integer,
  in content any,
  in tags any,
  in validation any)
{
  declare L, M, N, nLength, mLength, id integer;
  declare tmp, data, pFields, pValues, pField, pField2 any;
  declare xmlData, xmlItems, itemName, Meta, V any;

  Meta := vector
    (
      'P_NAME',           null, 'NICKNAME/val|N/fld[1]|N/fld[2]|N/val',
      'P_TITLE',          null, 'N/fld[4]',
      'P_FIRST_NAME',     null, 'N/fld[2]',
      'P_MIDDLE_NAME',    null, 'N/fld[3]',
      'P_LAST_NAME',      null, 'N/fld[1]|N/val',
      'P_FULL_NAME',      null, 'FN/val',
      'P_BIRTHDAY',       null, 'BDAY/val',
      'P_B_ORGANIZATION', null, 'ORG/val|ORG/fld[1]',
      'P_B_JOB',          null, 'TITLE/val',
      'P_H_ADDRESS1',     vector ('*', 'P_H_ADDRESS1', 'HOME',     'P_H_ADDRESS1', 'WORK',     'P_B_ADDRESS1'),                'for \044v in ADR/fld[3] return concat (\044v, for \044t in \044v/../TYPE return concat (" @TYPE_", \044t))',
      'P_H_ADDRESS2',     vector ('*', 'P_H_ADDRESS2', 'HOME',     'P_H_ADDRESS2', 'WORK',     'P_B_ADDRESS2'),                'for \044v in ADR/fld[2] return concat (\044v, for \044t in \044v/../TYPE return concat (" @TYPE_", \044t))',
      'P_H_CITY',         vector ('*', 'P_H_CITY',     'HOME',     'P_H_CITY',     'WORK',     'P_B_CITY'),                    'for \044v in ADR/fld[4] return concat (\044v, for \044t in \044v/../TYPE return concat (" @TYPE_", \044t))',
      'P_H_CODE',         vector ('*', 'P_H_CODE',     'HOME',     'P_H_CODE',     'WORK',     'P_B_CODE'),                    'for \044v in ADR/fld[6] return concat (\044v, for \044t in \044v/../TYPE return concat (" @TYPE_", \044t))',
      'P_H_STATE',        vector ('*', 'P_H_STATE',    'HOME',     'P_H_STATE',    'WORK',     'P_B_STATE'),                   'for \044v in ADR/fld[5] return concat (\044v, for \044t in \044v/../TYPE return concat (" @TYPE_", \044t))',
      'P_H_COUNTRY',      vector ('*', 'P_H_COUNTRY',  'HOME',     'P_H_COUNTRY',  'WORK',     'P_B_COUNTRY'),                 'for \044v in ADR/fld[7] return concat (\044v, for \044t in \044v/../TYPE return concat (" @TYPE_", \044t))',
      'P_MAIL',           vector ('*', 'P_MAIL',       'HOME',     'P_H_MAIL',     'WORK',     'P_B_MAIL',  'PREF', 'P_MAIL'), 'for \044v in EMAIL/val return concat (\044v, for \044t in \044v/../TYPE return concat (" @TYPE_", \044t))',
      'P_H_PHONE',        vector ('*', 'P_H_PHONE',    'HOME,FAX', 'P_H_FAX',      'WORK,FAX', 'P_B_FAX',   'FAX',  'P_H_FAX', 'HOME', 'P_H_PHONE', 'WORK', 'P_B_PHONE', 'CELL', 'P_H_MOBILE'), 'for \044v in TEL/val return concat (\044v, for \044t in \044v/../TYPE return concat (" @TYPE_", \044t))',
      'P_WEB',            vector ('*', 'P_WEB',        'HOME',     'P_H_WEB',      'WORK',     'P_B_WEB'),                     'for \044v in URL/val return concat (\044v, for \044t in \044v/../TYPE return concat (" @TYPE_", \044t))'
    );
  mLength := length (Meta);

  -- using DAV parser
  if (not isstring (content)) {
    xmlData := DB.DBA.IMC_TO_XML (cast (content as varchar));
  } else {
    xmlData := DB.DBA.IMC_TO_XML (content);
  }
  xmlData := xml_tree_doc (xmlData);
  xmlItems := xpath_eval ('/*', xmlData, 0);
  foreach (any xmlItem in xmlItems) do  {
    itemName := xpath_eval ('name(.)', xmlItem);
    if (itemName = 'IMC-VCARD') {
      id := -1;
      pFields := vector ();
      pValues := vector ();
      for (N := 0; N < mLength; N := N + 3) {
        pField := Meta [N];
        tmp := xquery_eval (Meta [N+2], xmlItem, 0);
        foreach (any T in tmp) do {
          T := cast (T as varchar);
          if (not is_empty_or_null (T)) {
            pField2 := pField;
            if (pField2 = 'P_BIRTHDAY') {
              {
                declare continue handler for sqlstate '*' {
                  T := '';
                };
                T := AB.WA.dt_reformat (T, 'YMD');
              }
            }
            if (not is_empty_or_null (T)) {
              if (not isnull (Meta [N+1])) {
                if (strstr (T, ' @TYPE_') <> 0) {
                  pField2 := '';
                  for (M := 0; M < length (Meta [N+1]); M := M + 2) {
                    if ((Meta [N+1][M] = '*') and isnull (strstr (T, ' @TYPE_'))) {
                      pField2 := Meta [N+1][M+1];
            } else {
                      V := split_and_decode (Meta [N+1][M], 0, '\0\0,');
                      for (L := 0; L < length (V); L := L + 1)
                        if (isnull (strstr (T, ' @TYPE_' || V[L])))
                          goto _exit;
                      pField2 := Meta [N+1][M+1];
                    _exit:;
                    }
                  }
                  M := strstr (T, ' @TYPE_');
                  if (not isnull (M))
                    T := subseq (T, 0, M);
                }
              }
                  pFields := vector_concat (pFields, vector (pField2));
              pValues := vector_concat (pValues, vector (T));
            }
          }
        }
      }
      AB.WA.contact_update4 (-1, domain_id, pFields, pValues, tags, validation);
    }
  }
}
;

-------------------------------------------------------------------------------
--
create procedure AB.WA.import_foaf (
  in domain_id integer,
  in content any,
  in tags any,
  in validation any,
  in contentType any := 0)
{
  declare N, M, nLength, mLength, id integer;
  declare tmp, tmp2, data, pFields, pValues any;
  declare Meta, Items, Item any;
  declare S, tmp_iri, name, fullName varchar;

  declare exit handler for sqlstate '*' {
    -- dbg_obj_print (__SQL_STATE, __SQL_MESSAGE);
    delete from DB.DBA.RDF_QUAD where G = DB.DBA.RDF_MAKE_IID_OF_QNAME (tmp_iri);
    signal ('TEST', 'Bad import source!<>');    
  };

  tmp_iri := 'http://local.virt/' || cast (rnd (1000) as varchar);
  Meta := vector
    (
      'P_NAME',
      'P_FULL_NAME',
      'P_FIRST_NAME',
      'P_LAST_NAME',
      'P_BIRTHDAY',
      'P_MAIL',
      'P_WEB',
      'P_ICQ',
      'P_MSN',
      'P_AIM',
      'P_YAHOO',
      'P_KIND'
    );
  mLength := length (Meta);

  if (contentType) {
    declare st, msg, meta any;
  
    st := '00000';
    exec (sprintf ('SPARQL define get:soft "soft" define get:uri "%s" SELECT * FROM <%s> WHERE { ?s ?p ?o }', content, tmp_iri), st, msg, vector (), 0, meta, items);
    if ('00000' <> st)
      signal (st, msg);
    
  } else {
  DB.DBA.RDF_LOAD_RDFXML (content, '', tmp_iri);
  }
  Items := AB.WA.ab_sparql (sprintf (' SPARQL ' ||
                                     ' PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> ' ||
                                     ' PREFIX foaf: <http://xmlns.com/foaf/0.1/> ' ||
                                     ' SELECT ?x ' ||
                                     '   FROM <%s> ' ||
                                     '  WHERE { ' ||
                                     '          {?x a foaf:Person .} ' ||
                                     '          UNION ' ||
                                     '          {?x a foaf:Organization .} ' ||
                                     '        }', tmp_iri));
  nLength := length (Items);
  for (N := 0; N < nLength; N := N + 1) {
    S := ' SPARQL ' ||
         ' PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> ' ||
         ' PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#> ' ||
         ' PREFIX foaf: <http://xmlns.com/foaf/0.1/> ' ||
         ' SELECT ?P_NAME, ?P_FULL_NAME, ?P_FIRST_NAME, ?P_LAST_NAME, ?P_BIRTHDAY, ?P_MAIL, ?P_WEB, ?P_ICQ, ?P_MSN, ?P_AIM, ?P_YAHOO, ?P_KIND ' ||
         ' FROM <%s> ' ||
         ' WHERE { ' ||
         '         <PERSON> rdf:type ?P_KIND .' ||
         '         OPTIONAL{ <PERSON>  foaf:nick ?P_NAME} . ' ||
         '         OPTIONAL{ <PERSON>  foaf:name ?P_FULL_NAME} . ' ||
         '         OPTIONAL{ <PERSON>  foaf:firstNname ?P_FIRST_NAME} . ' ||
         '         OPTIONAL{ <PERSON>  foaf:family_name ?P_LAST_NAME} . ' ||
         '         OPTIONAL{ <PERSON>  foaf:dateOfBirth ?P_BIRTHDAY} . ' ||
         '         OPTIONAL{ <PERSON>  foaf:mbox ?P_MAIL} . ' ||
         '         OPTIONAL{ <PERSON>  foaf:homepage ?P_WEB} . ' ||
         '         OPTIONAL{ <PERSON>  foaf:icqChatID ?P_ICQ } .' ||
         '         OPTIONAL{ <PERSON>  foaf:msnChatID ?P_MSN } .' ||
         '         OPTIONAL{ <PERSON>  foaf:aimChatID ?P_AIM } .' ||
         '         OPTIONAL{ <PERSON>  foaf:yahooChatID ?P_YAHOO } .' ||
         '       }';

    S := sprintf (S, tmp_iri);
    S := replace (S, '<PERSON>', '<' || Items [N][0] || '>');
    Item := AB.WA.ab_sparql (S);

    if (length (Item)) {
      fullName := null;
      if (not isnull (Item[0][1])) {
        fullName := Item[0][1];
      } else {
        if (not isnull (Item[0][2]) or not isnull (Item[0][3]))
          fullName := trim (Item[0][2] || ' ' || Item[0][3]);
      }
      if (not is_empty_or_null (coalesce (Item[0][0], fullName))) {
        pFields := vector ('P_NAME');
        pValues := vector (coalesce (Item[0][0], fullName));
	      if (Items [N][0] not like 'nodeID://%') {
          pFields := vector_concat (pFields, vector ('P_FOAF'));
          pValues := vector_concat (pValues, vector (Items [N][0]));
	      }
        for (M := 1; M < mLength; M := M + 1) {
          if (Meta[M] = 'P_FULL_NAME') {
            if (not isnull (fullName)) {
              pFields := vector_concat (pFields, vector (Meta[M]));
              pValues := vector_concat (pValues, vector (fullName));
            }
          } else {
            tmp := Meta[M];
            tmp2 := Item[0][M];
            if (tmp = 'P_BIRTHDAY') {
              {
                declare continue handler for sqlstate '*' {
                  tmp := '';
                };
                tmp2 := AB.WA.dt_reformat (tmp2, 'Y-M-D');
              }
            }
            if (tmp = 'P_KIND') {
              tmp2 := case when (tmp2 = 'http://xmlns.com/foaf/0.1/Person') then 0 else 1 end;
            }
            if (tmp <> '') {
              pFields := vector_concat (pFields, vector (tmp));
              pValues := vector_concat (pValues, vector (tmp2));
            }
          }
        }
        AB.WA.contact_update4 (-1, domain_id, pFields, pValues, tags, validation);
      }
    }
  }
_delete:;
  delete from DB.DBA.RDF_QUAD where G = DB.DBA.RDF_MAKE_IID_OF_QNAME (tmp_iri);
}
;

-------------------------------------------------------------------------------
--
create procedure AB.WA.import_csv (
  in domain_id integer,
  in content any,
  in tags any,
  in maps any,
  in validation any)
{
  declare N, M, nLength, mLength, id integer;
  declare tmp, tmp2, data, pFields, pValues any;
  declare nameIdx, firstNameIdx, lastNameIdx, fullNameIdx integer;
  declare name, fullName varchar;

  nameIdx := -1;
  firstNameIdx := -1;
  lastNameIdx := -1;
  fullNameIdx := -1;
  for (N := 0; N < length (maps); N := N + 2) {
    if (maps[N+1] = 'P_NAME')
      nameIdx := cast (maps[N] as integer);
    if (maps[N+1] = 'P_FIRST_NAME')
      firstNameIdx := cast (maps[N] as integer);
    if (maps[N+1] = 'P_LAST_NAME')
      lastNameIdx := cast (maps[N] as integer);
    if (maps[N+1] = 'P_FULL_NAME')
      fullNameIdx := cast (maps[N] as integer);
  }
  nLength := length (content);
  for (N := 1; N < nLength; N := N + 1) {
    data := split_and_decode (content [N], 0, '\0\0,');
    name := '';
    fullName := '';
    if ((nameIdx <> -1) and (nameIdx < length (data)))
      name := trim (trim (data[nameIdx], '"'));
    if ((fullNameIdx <> -1) and (fullNameIdx < length (data)))
      fullName := trim (trim (data[fullNameIdx], '"'));
    if (fullName = '') {
      if ((firstNameIdx <> -1) and (firstNameIdx < length (data)))
         fullName := trim (trim (data[firstNameIdx], '"'));
      if ((lastNameIdx <> -1) and (lastNameIdx < length (data)))
         fullName := fullName || ' ' || trim (trim (data[lastNameIdx], '"'));
       fullName := trim (fullName);
    }
    if (name = '')
      name := fullName;
    if (name <> '') {
      pFields := vector ('P_NAME');
      pValues := vector (name);
      mLength := length (data);
      for (M := 0; M < mLength; M := M + 1) {
        if (M <> nameIdx) {
          if (M = fullNameIdx) {
            if (fullName <> '') {
               pFields := vector_concat (pFields, vector ('P_FULL_NAME'));
               pValues := vector_concat (pValues, vector (fullName));
             }
           } else {
             tmp := get_keyword (cast (M as varchar), maps, '');
             if (tmp <> '') {
               tmp2 := trim (data[M], '"');
               if (tmp = 'P_BIRTHDAY') {
                 {
                   declare continue handler for sqlstate '*' {
                     tmp := '';
                   };
                   tmp2 := AB.WA.dt_reformat (tmp2);
                 }
               }
               if (tmp <> '') {
                 pFields := vector_concat (pFields, vector (tmp));
                 pValues := vector_concat (pValues, vector (tmp2));
               }
             }
           }
         }
      }
      AB.WA.contact_update4 (-1, domain_id, pFields, pValues, tags, validation);
    }
  }
}
;

-------------------------------------------------------------------------------
--
create procedure AB.WA.import_ldap (
  in domain_id integer,
  in content any,
  in tags any,
  in maps any,
  in validation any)
{
  declare N, M, nLength, mLength, id integer;
  declare data, pFields, pValues any;

  nLength := length (content);
  for (N := 0; N < nLength; N := N + 2) {
    if (content [N] = 'entry') {
      data := content [N+1];
      mLength := length (data);
        pFields := vector ();
        pValues := vector ();
        for (M := 0; M < mLength; M := M + 2) {
          if (get_keyword (data[M], maps, '') <> '') {
            pFields := vector_concat (pFields, vector (get_keyword (data[M], maps)));
            pValues := vector_concat (pValues, vector (case when isstring (data[M+1]) then data[M+1] else data[M+1][0] end));
          }
        }
      AB.WA.contact_update4 (-1, domain_id, pFields, pValues, tags, validation);
    }
  }
}
;

-------------------------------------------------------------------------------
--
create procedure AB.WA.export_vcard (
  in id integer,
  in domain_id integer)
{
  declare S varchar;
  declare sStream any;

  sStream := string_output();
  for (select * from AB.WA.PERSONS where P_ID = id and P_DOMAIN_ID = domain_id) do {
	  http ('BEGIN:VCARD\r\n', sStream);
	  http ('VERSION:2.1\r\n', sStream);

	  -- personal
	  http (sprintf ('NICKNAME:%s\r\n', P_NAME), sStream);
	  if (not is_empty_or_null (P_FULL_NAME))
  	  http (sprintf ('FN:%s\r\n', P_FULL_NAME), sStream);
    -- Home
	  S := coalesce (P_LAST_NAME, '');
	  S := S || ';' || coalesce (P_FIRST_NAME, '');
	  S := S || ';' || coalesce (P_MIDDLE_NAME, '');
	  S := S || ';' || coalesce (P_TITLE, '');
	  if (S <> ';;;')
  	  http (sprintf ('N:%s\r\n', S), sStream);
	  if (not is_empty_or_null (P_BIRTHDAY))
	    http (sprintf ('BDAY:%s\r\n', AB.WA.dt_format (P_BIRTHDAY, 'Y-M-D')), sStream);

	  -- mail
	  if (not is_empty_or_null (P_MAIL))
	    http (sprintf ('EMAIL;TYPE=PREF;TYPE=INTERNET:%s\r\n', P_MAIL), sStream);

	  -- web
	  if (not is_empty_or_null (P_WEB))
	    http (sprintf ('URL:%s\r\n', P_WEB), sStream);
	  if (not is_empty_or_null (P_H_WEB))
	    http (sprintf ('URL;TYPE=HOME:%s\r\n', P_H_WEB), sStream);
	  if (not is_empty_or_null (P_B_WEB))
	    http (sprintf ('URL;TYPE=WORK:%s\r\n', P_B_WEB), sStream);

    -- Home
	  S := ';';
	  S := S || ''  || coalesce (P_H_ADDRESS1, '');
	  S := S || ';' || coalesce (P_H_ADDRESS2, '');
	  S := S || ';' || coalesce (P_H_CITY, '');
	  S := S || ';' || coalesce (P_H_STATE, '');
	  S := S || ';' || coalesce (P_H_CODE, '');
	  S := S || ';' || coalesce (P_H_COUNTRY, '');
	  if (S <> ';;;;;;')
	    http (sprintf ('ADR;TYPE=HOME:%s\r\n', S), sStream);
	  if (not is_empty_or_null (P_H_TZONE))
	    http (sprintf ('TS:%s\r\n', P_H_TZONE), sStream);

	  if (not is_empty_or_null (P_H_PHONE))
	    http (sprintf ('TEL;TYPE=HOME:%s\r\n', P_H_PHONE), sStream);
	  if (not is_empty_or_null (P_H_MOBILE))
	    http (sprintf ('TEL;TYPE=HOME;TYPE=CELL:%s\r\n', P_H_MOBILE), sStream);

    -- Business
	  S := ';';
	  S := S || ''  || coalesce (P_B_ADDRESS1, '');
	  S := S || ';' || coalesce (P_B_ADDRESS2, '');
	  S := S || ';' || coalesce (P_B_CITY, '');
	  S := S || ';' || coalesce (P_B_STATE, '');
	  S := S || ';' || coalesce (P_B_CODE, '');
	  S := S || ';' || coalesce (P_B_COUNTRY, '');
	  if (S <> ';;;;;;')
  	  http (sprintf ('ADR;TYPE=WORK:%s\r\n', S), sStream);

	  if (not is_empty_or_null (P_B_PHONE))
	    http (sprintf ('TEL;TYPE=WORK:%s\r\n', P_B_PHONE), sStream);
	  if (not is_empty_or_null (P_B_MOBILE))
	    http (sprintf ('TEL;TYPE=WORK;TYPE=CELL:%s\r\n', P_B_MOBILE), sStream);

	  if (not is_empty_or_null (P_B_ORGANIZATION))
	    http (sprintf ('ORG:%s\r\n', P_B_ORGANIZATION), sStream);
	  if (not is_empty_or_null (P_B_JOB))
	    http (sprintf ('TITLE:%s\r\n', P_B_JOB), sStream);

	  http ('END:VCARD\r\n', sStream);
	}
  return string_output_string(sStream);
}
;

-------------------------------------------------------------------------------
--
create procedure AB.WA.export_csv_head ()
{
  return '"Name",' ||
         '"Title",' ||
         '"First Name",' ||
         '"Last Name",' ||
         '"Full Name",' ||
         '"Gender",' ||
         '"Birthday",' ||
         '"Mail",' ||
         '"Web Page",' ||
         '"Home Address",' ||
         '"Home Address 2",' ||
         '"Home City",' ||
         '"Home State",' ||
         '"Home Postal Code",' ||
         '"Home Country",' ||
         '"Home Timezone",' ||
         '"Home Phone",' ||
         '"Home Mobile",' ||
         '"Home Mail",' ||
         '"Home Web Page",' ||
         '"Business Address",' ||
         '"Business Address 2",' ||
         '"Business City",' ||
         '"Business State",' ||
         '"Business Postal Code",' ||
         '"Business Country",' ||
         '"Business Timezone",' ||
         '"Business Phone",' ||
         '"Business Mobile",' ||
         '"Business Mail",' ||
         '"Business Web Page",' ||
         '"Indistry",' ||
         '"Company",' ||
         '"Job Title",' ||
         '"Tags"\r\n';
}
;

-------------------------------------------------------------------------------
--
create procedure AB.WA.export_csv (
  in id integer,
  in domain_id integer)
{
  declare S varchar;

  S := '';
  for (select * from AB.WA.PERSONS where P_ID = id and P_DOMAIN_ID = domain_id) do {
    S := sprintf
           (
            '"%s","%s","%s","%s","%s","%s","%s","%s","%s","%s","%s","%s","%s","%s","%s","%s","%s","%s","%s","%s","%s","%s","%s","%s","%s","%s","%s","%s","%s","%s","%s","%s","%s","%s","%s"\r\n',
            coalesce (P_NAME, ''),
            coalesce (P_TITLE, ''),
            coalesce (P_FIRST_NAME, ''),
            coalesce (P_LAST_NAME, ''),
            coalesce (P_FULL_NAME, ''),
            coalesce (P_GENDER, ''),
            case when (isnull (P_BIRTHDAY)) then '' else AB.WA.dt_format (P_BIRTHDAY, 'Y-M-D') end,
            coalesce (P_MAIL, ''),
            coalesce (P_WEB, ''),
            coalesce (P_H_ADDRESS1, ''),
            coalesce (P_H_ADDRESS2, ''),
            coalesce (P_H_CITY, ''),
            coalesce (P_H_STATE, ''),
            coalesce (P_H_CODE, ''),
            coalesce (P_H_COUNTRY, ''),
            coalesce (P_H_TZONE, ''),
            coalesce (P_H_PHONE, ''),
            coalesce (P_H_MOBILE, ''),
            coalesce (P_H_MAIL, ''),
            coalesce (P_H_WEB, ''),
            coalesce (P_B_ADDRESS1, ''),
            coalesce (P_B_ADDRESS2, ''),
            coalesce (P_B_CITY, ''),
            coalesce (P_B_STATE, ''),
            coalesce (P_B_CODE, ''),
            coalesce (P_B_COUNTRY, ''),
            coalesce (P_B_TZONE, ''),
            coalesce (P_B_PHONE, ''),
            coalesce (P_B_MOBILE, ''),
            coalesce (P_B_MAIL, ''),
            coalesce (P_B_WEB, ''),
            coalesce (P_B_INDUSTRY, ''),
            coalesce (P_B_ORGANIZATION, ''),
            coalesce (P_B_JOB, ''),
            coalesce (P_TAGS, '')
           );
    ;
  }
  return S;
}
;

-------------------------------------------------------------------------------
--
create procedure AB.WA.export_foaf (
  in ids any,
  in domain_id integer)
{
  declare S, T varchar;
  declare sStream any;
  declare st, msg, meta, rows any;

  sStream := string_output();
  S := 'sparql
        PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
        PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
        PREFIX foaf: <http://xmlns.com/foaf/0.1/>
        PREFIX sioc: <http://rdfs.org/sioc/ns#>
        PREFIX dc: <http://purl.org/dc/elements/1.1/>
        PREFIX dct: <http://purl.org/dc/terms/>
        PREFIX atom: <http://atomowl.org/ontologies/atomrdf#>
        PREFIX vcard: <http://www.w3.org/2001/vcard-rdf/3.0#>
        PREFIX bio: <http://purl.org/vocab/bio/0.1/>
        CONSTRUCT {
	        ?person rdf:type ?rdfType .
	        ?person foaf:nick ?nick .
	        ?person foaf:name ?name .
	        ?person foaf:firstName ?firstName .
	        ?person foaf:family_name ?family_name .
	        ?person foaf:gender ?gender .
	        ?person foaf:mbox ?mbox .
	        ?person foaf:mbox_sha1sum ?mbox_sha1sum .
	        ?person foaf:icqChatID ?icqChatID .
	        ?person foaf:msnChatID ?msnChatID .
	        ?person foaf:aimChatID ?aimChatID .
	        ?person foaf:yahooChatID ?yahooChatID .
	        ?person foaf:birthday ?birthday .
	        ?person foaf:phone ?phone.
	        ?person foaf:based_near ?based_near .
	        ?based_near ?based_near_predicate ?based_near_subject .
	        ?person foaf:knows ?knows .
	        ?knows rdfs:seeAlso ?knows_seeAlso .
	        ?knows foaf:nick ?knows_nick .
	        ?person foaf:workplaceHomepage ?workplaceHomepage .
	        ?org foaf:homepage ?workplaceHomepage .
	        ?org rdf:type foaf:Organization .
	        ?org dc:title ?orgtit .
	        ?person foaf:homepage ?homepage .
	        ?person vcard:ADR ?adr .
	        ?adr vcard:Country ?country .
	        ?adr vcard:Region ?state .
          ?adr vcard:Locality ?city .
          ?adr vcard:Pcode ?pcode .
          ?adr vcard:Street ?street .
          ?adr vcard:Extadd ?extadd .
	        ?person bio:olb ?bio .
	        ?person bio:event ?event .
	        ?event rdf:type bio:Birth .
	        ?event dc:date ?bdate .
	      }
	      WHERE {
	        GRAPH <%s>
	        {
	          <FILTER>
	          ?person rdf:type ?rdfType .
	          OPTIONAL { ?person foaf:nick ?nick } .
	          OPTIONAL { ?person foaf:name ?name } .
	          OPTIONAL { ?person foaf:firstName ?firstName } .
	          OPTIONAL { ?person foaf:family_name ?family_name } .
	          OPTIONAL { ?person foaf:gender ?gender } .
	          OPTIONAL { ?person foaf:birthday ?birthday } .
	          OPTIONAL { ?person foaf:mbox ?mbox } .
	          OPTIONAL { ?person foaf:mbox_sha1sum ?mbox_sha1sum } .
	          OPTIONAL { ?person foaf:icqChatID ?icqChatID } .
	          OPTIONAL { ?person foaf:msnChatID ?msnChatID } .
	          OPTIONAL { ?person foaf:aimChatID ?aimChatID } .
	          OPTIONAL { ?person foaf:yahooChatID ?yahooChatID } .
	          OPTIONAL { ?person foaf:phone ?phone } .
	          OPTIONAL { ?person foaf:based_near ?based_near .
	                     ?based_near ?based_near_predicate ?based_near_subject .
	                   } .
	          OPTIONAL { ?person foaf:workplaceHomepage ?workplaceHomepage } .
	          OPTIONAL { ?org foaf:homepage ?workplaceHomepage .
	                     ?org a foaf:Organization ;
	                          dc:title ?orgtit .
	                   } .
	          OPTIONAL { ?person foaf:homepage ?homepage } .
	          OPTIONAL { ?person vcard:ADR ?adr .
	                     optional { ?adr vcard:Country ?country }.
		                   optional { ?adr vcard:Region ?state } .
		                   optional { ?adr vcard:Locality ?city } .
		                   optional { ?adr vcard:Pcode ?pcode  } .
		                   optional { ?adr vcard:Street ?street } .
		                   optional { ?adr vcard:Extadd ?extadd } .
		                 }
	          OPTIONAL { ?person bio:olb ?bio } .
            OPTIONAL { ?person bio:event ?event.
                       ?event a bio:Birth ; dc:date ?bdate
                     }.
	          OPTIONAL { ?person foaf:knows ?knows .
	                     ?knows rdfs:seeAlso ?knows_seeAlso .
	                     ?knows foaf:nick ?knows_nick .
                     } .
	        }
	      }';

	S := sprintf (S, SIOC..get_graph ());
  T := '';
	if (not isnull (ids)) {
	  foreach (any id in ids) do {
	    if (T = '') {
	      T := sprintf ('(?person = <%s>)', SIOC..socialnetwork_contact_iri (domain_id, cast (id as integer)));
	    } else {
	      T := T || ' || ' || sprintf ('(?person = <%s>)', SIOC..socialnetwork_contact_iri (domain_id, cast (id as integer)));
	    }
	  }
	  T := sprintf ('FILTER (%s) .', T);
	} else {
	  T := sprintf ('?person sioc:has_container <%s> .', SIOC..socialnetwork_iri (AB.WA.domain_name (domain_id)));
	}
  S := replace (S, '<FILTER>', T);
  st := '00000';
  exec (S, st, msg, vector (), 0, meta, rows);
  if ('00000' = st)
    DB.DBA.SPARQL_RESULTS_WRITE (sStream, meta, rows, '', 1);
  return string_output_string(sStream);
}
;


-------------------------------------------------------------------------------
--
create procedure AB.WA.search_sql (
  inout domain_id integer,
  inout account_id integer,
  inout data varchar,
  in maxRows varchar := '')
{
  declare S, T, tmp, where2, delimiter2 varchar;

  where2 := ' \n ';
  delimiter2 := '\n and ';

  S := '';
  if (not is_empty_or_null(AB.WA.xml_get('MyContacts', data))) {
    S := 'select                         \n' ||
         ' p.P_ID,                       \n' ||
         ' p.P_DOMAIN_ID,                \n' ||
         ' p.P_NAME,                     \n' ||
         ' p.P_TAGS,                     \n' ||
         ' p.P_CREATED,                  \n' ||
         ' p.P_UPDATED                   \n' ||
         'from                           \n' ||
         '  AB.WA.PERSONS p              \n' ||
         'where p.P_DOMAIN_ID = <DOMAIN_ID> <TEXT> <WHERE>';
  }
  if (not is_empty_or_null(AB.WA.xml_get('MySharedContacts', data))) {
    if (S <> '')
      S := S || '\n union \n';
    S := S ||
         'select                         \n' ||
         ' p.P_ID,                       \n' ||
         ' p.P_DOMAIN_ID,                \n' ||
         ' p.P_NAME,                     \n' ||
         ' p.P_TAGS,                     \n' ||
         ' p.P_CREATED,                  \n' ||
         ' p.P_UPDATED                   \n' ||
         'from                           \n' ||
         '  AB.WA.PERSONS p,             \n' ||
         '  AB.WA.GRANTS g               \n' ||
         'where p.P_ID = g.G_PERSON_ID   \n' ||
         '  and g.G_GRANTEE_ID = <ACCOUNT_ID> <TEXT> <WHERE>';
  }

  S := 'select <MAX> * from (' || S || ') x';

  T := '';
  tmp := AB.WA.xml_get('keywords', data);
  if (not is_empty_or_null(tmp)) {
    T := FTI_MAKE_SEARCH_STRING(tmp);
  } else {
    tmp := AB.WA.xml_get('expression', data);
    if (not is_empty_or_null(tmp))
      T := tmp;
  }

  tmp := AB.WA.xml_get('tags', data);
  if (not is_empty_or_null(tmp)) {
    if (T = '') {
      T := AB.WA.tags2search (tmp);
    } else {
      T := T || ' and ' || AB.WA.tags2search (tmp);
    }
  }
  if (T <> '')
    S := replace(S, '<TEXT>', sprintf('and contains(p.P_NAME, \'[__lang "x-ViDoc"] %s\') \n', T));

  if (maxRows <> '')
    maxRows := 'TOP ' || maxRows;

  S := replace(S, '<MAX>', maxRows);
  S := replace(S, '<DOMAIN_ID>', cast(domain_id as varchar));
  S := replace(S, '<ACCOUNT_ID>', cast(account_id as varchar));
  S := replace(S, '<TEXT>', '');
  S := replace(S, '<WHERE>', where2);

  --dbg_obj_print(S);
  return S;
}
;

-----------------------------------------------------------------------------------------
--
create procedure AB.WA.version_update ()
{
  for (select WAI_ID, WAM_USER
         from DB.DBA.WA_MEMBER
                join DB.DBA.WA_INSTANCE on WAI_NAME = WAM_INST
        where WAI_TYPE_NAME = 'AddressBook'
          and WAM_MEMBER_TYPE = 1) do {
    AB.WA.domain_update (WAI_ID, WAM_USER);
  }
}
;

-----------------------------------------------------------------------------------------
--
AB.WA.version_update ()
;
