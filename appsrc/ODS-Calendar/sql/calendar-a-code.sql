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
create procedure CAL.WA.session_restore(
  inout params any)
{
  declare aPath, domain_id, user_id, user_name, user_role, sid, realm, options any;

  declare exit handler for sqlstate '*' {
    domain_id := -2;
    goto _end;
  };

  sid := get_keyword ('sid', params, '');
  realm := get_keyword ('realm', params, '');

  options := http_map_get('options');
  if (not is_empty_or_null(options))
    domain_id := get_keyword ('domain', options);
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
    user_name := CAL.WA.user_name(U_NAME, U_FULL_NAME);
    user_role := CAL.WA.access_role(domain_id, U_ID);
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
create procedure CAL.WA.frozen_check(in domain_id integer)
{
  declare exit handler for not found { return 1; };

  if (is_empty_or_null((select WAI_IS_FROZEN from DB.DBA.WA_INSTANCE where WAI_ID = domain_id)))
    return 0;

  declare user_id integer;

  user_id := (select U_ID from SYS_USERS where U_NAME = connection_get ('vspx_user'));
  if (CAL.WA.check_admin(user_id))
    return 0;

  user_id := (select U_ID from SYS_USERS where U_NAME = connection_get ('owner_user'));
  if (CAL.WA.check_admin(user_id))
    return 0;

  return 1;
}
;

-------------------------------------------------------------------------------
--
create procedure CAL.WA.frozen_page(in domain_id integer)
{
  return (select WAI_FREEZE_REDIRECT from DB.DBA.WA_INSTANCE where WAI_ID = domain_id);
}
;

-------------------------------------------------------------------------------
--
-- User Functions
--
-------------------------------------------------------------------------------
create procedure CAL.WA.check_admin(
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
create procedure CAL.WA.check_grants(in domain_id integer, in user_id integer, in role_name varchar)
{
  whenever not found goto _end;

  if (CAL.WA.check_admin(user_id))
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
create procedure CAL.WA.check_grants2(in role_name varchar, in page_name varchar)
{
  return 1;
}
;

-------------------------------------------------------------------------------
--
create procedure CAL.WA.access_role(in domain_id integer, in user_id integer)
{
  whenever not found goto _end;

  if (CAL.WA.check_admin (user_id))
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
create procedure CAL.WA.wa_home_link ()
{
  return case when registry_get ('wa_home_link') = 0 then '/ods/' else registry_get ('wa_home_link') end;
}
;

-------------------------------------------------------------------------------
--
create procedure CAL.WA.wa_home_title ()
{
  return case when registry_get ('wa_home_title') = 0 then 'ODS Home' else registry_get ('wa_home_title') end;
}
;

-------------------------------------------------------------------------------
--
create procedure CAL.WA.page_name ()
{
  declare aPath any;

  aPath := http_path ();
  aPath := split_and_decode (aPath, 0, '\0\0/');
  return aPath [length (aPath) - 1];
}
;

-------------------------------------------------------------------------------
--
create procedure CAL.WA.xslt_root()
{
  declare sHost varchar;

  sHost := cast (registry_get('calendar_path') as varchar);
  if (sHost = '0')
    return 'file://apps/Calendar/xslt/';
  if (isnull (strstr(sHost, '/DAV/VAD')))
    return sprintf ('file://%sxslt/', sHost);
  return sprintf ('virt://WS.WS.SYS_DAV_RES.RES_FULL_PATH.RES_CONTENT:%sxslt/', sHost);
}
;

-------------------------------------------------------------------------------
--
create procedure CAL.WA.xslt_full(
  in xslt_file varchar)
{
  return concat(CAL.WA.xslt_root(), xslt_file);
}
;

-------------------------------------------------------------------------------
--
create procedure CAL.WA.export_rss_sqlx_int (
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
  http ('  XMLELEMENT(\'title\', CAL.WA.utf2wide(CAL.WA.domain_name (<DOMAIN_ID>))), \n', retValue);
  http ('  XMLELEMENT(\'description\', CAL.WA.utf2wide(CAL.WA.domain_description (<DOMAIN_ID>))), \n', retValue);
  http ('  XMLELEMENT(\'managingEditor\', U_E_MAIL), \n', retValue);
  http ('  XMLELEMENT(\'pubDate\', CAL.WA.dt_rfc1123(now ())), \n', retValue);
  http ('  XMLELEMENT(\'generator\', \'Virtuoso Universal Server \' || sys_stat(\'st_dbms_ver\')), \n', retValue);
  http ('  XMLELEMENT(\'webMaster\', U_E_MAIL), \n', retValue);
  http ('  XMLELEMENT(\'link\', CAL.WA.calendar_url (<DOMAIN_ID>)) \n', retValue);
  http ('from DB.DBA.SYS_USERS where U_ID = <USER_ID> \n', retValue);
  http (']]></sql:sqlx>\n', retValue);

  http ('<sql:sqlx xmlns:sql=\'urn:schemas-openlink-com:xml-sql\'><![CDATA[\n', retValue);
  http ('select \n', retValue);
  http ('  XMLAGG(XMLELEMENT(\'item\', \n', retValue);
  http ('    XMLELEMENT(\'title\', CAL.WA.utf2wide (E_SUBJECT)), \n', retValue);
  http ('    XMLELEMENT(\'description\', CAL.WA.utf2wide (E_DESCRIPTION)), \n', retValue);
  http ('    XMLELEMENT(\'guid\', E_ID), \n', retValue);
  http ('    XMLELEMENT(\'link\', CAL.WA.event_url (<DOMAIN_ID>, E_ID)), \n', retValue);
  http ('    XMLELEMENT(\'pubDate\', CAL.WA.dt_rfc1123 (E_UPDATED)), \n', retValue);
  http ('    (select XMLAGG (XMLELEMENT (\'category\', TV_TAG)) from CAL..TAGS_VIEW where tags = E_TAGS), \n', retValue);
  http ('    XMLELEMENT(\'http://www.openlinksw.com/weblog/:modified\', CAL.WA.dt_iso8601 (E_UPDATED)))) \n', retValue);
  http ('from (select top 15  \n', retValue);
  http ('        E_SUBJECT, \n', retValue);
  http ('        E_DESCRIPTION, \n', retValue);
  http ('        E_UPDATED, \n', retValue);
  http ('        E_TAGS, \n', retValue);
  http ('        E_ID \n', retValue);
  http ('      from \n', retValue);
  http ('        CAL.WA.EVENTS \n', retValue);
  http ('      where E_DOMAIN_ID = <DOMAIN_ID> \n', retValue);
  http ('      order by E_UPDATED desc) x \n', retValue);
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
create procedure CAL.WA.export_rss_sqlx (
  in domain_id integer,
  in account_id integer)
{
  declare retValue any;

  retValue := CAL.WA.export_rss_sqlx_int (domain_id, account_id);
  return replace (retValue, 'sql:xsl=""', '');
}
;

-------------------------------------------------------------------------------
--
create procedure CAL.WA.export_atom_sqlx(
  in domain_id integer,
  in account_id integer)
{
  declare retValue, xsltTemplate any;

  xsltTemplate := CAL.WA.xslt_full ('rss2atom03.xsl');
  if (CAL.WA.settings_atomVersion (CAL.WA.settings (account_id)) = '1.0')
    xsltTemplate := CAL.WA.xslt_full ('rss2atom.xsl');

  retValue := CAL.WA.export_rss_sqlx_int (domain_id, account_id);
  return replace (retValue, 'sql:xsl=""', sprintf ('sql:xsl="%s"', xsltTemplate));
}
;

-------------------------------------------------------------------------------
--
create procedure CAL.WA.export_rdf_sqlx (
  in domain_id integer,
  in account_id integer)
{
  declare retValue any;

  retValue := CAL.WA.export_rss_sqlx_int (domain_id, account_id);
  return replace (retValue, 'sql:xsl=""', sprintf ('sql:xsl="%s"', CAL.WA.xslt_full ('rss2rdf.xsl')));
}
;

-------------------------------------------------------------------------------
--
create procedure CAL.WA.domain_gems_create (
  inout domain_id integer,
  inout account_id integer)
{
  declare read_perm, exec_perm, content, home, path varchar;

  home := CAL.WA.dav_home(account_id);
  if (isnull (home))
    return;

  read_perm := '110100100N';
  exec_perm := '111101101N';
  home := home || 'Calendar/';
  DB.DBA.DAV_MAKE_DIR (home, account_id, null, read_perm);

  home := home || CAL.WA.domain_gems_name(domain_id) || '/';
  DB.DBA.DAV_MAKE_DIR (home, account_id, null, read_perm);

  -- RSS 2.0
  path := home || 'Calendar.rss';
  DB.DBA.DAV_DELETE_INT (path, 1, null, null, 0);

  content := CAL.WA.export_rss_sqlx (domain_id, account_id);
  DB.DBA.DAV_RES_UPLOAD_STRSES_INT (path, content, 'text/xml', exec_perm, http_dav_uid (), http_dav_uid () + 1, null, null, 0);
  DB.DBA.DAV_PROP_SET_INT (path, 'xml-template', 'execute', 'dav', null, 0, 0, 1);
  DB.DBA.DAV_PROP_SET_INT (path, 'xml-sql-encoding', 'utf-8', 'dav', null, 0, 0, 1);
  DB.DBA.DAV_PROP_SET_INT (path, 'xml-sql-description', 'RSS based XML document generated by OpenLink Calendar', 'dav', null, 0, 0, 1);

  -- ATOM
  path := home || 'Calendar.atom';
  DB.DBA.DAV_DELETE_INT (path, 1, null, null, 0);

  content := CAL.WA.export_atom_sqlx (domain_id, account_id);
  DB.DBA.DAV_RES_UPLOAD_STRSES_INT (path, content, 'text/xml', exec_perm, http_dav_uid (), http_dav_uid () + 1, null, null, 0);
  DB.DBA.DAV_PROP_SET_INT (path, 'xml-template', 'execute', 'dav', null, 0, 0, 1);
  DB.DBA.DAV_PROP_SET_INT (path, 'xml-sql-encoding', 'utf-8', 'dav', null, 0, 0, 1);
  DB.DBA.DAV_PROP_SET_INT (path, 'xml-sql-description', 'ATOM based XML document generated by OpenLink Calendar', 'dav', null, 0, 0, 1);

  -- RDF
  path := home || 'Calendar.rdf';
  DB.DBA.DAV_DELETE_INT (path, 1, null, null, 0);

  content := CAL.WA.export_rdf_sqlx (domain_id, account_id);
  DB.DBA.DAV_RES_UPLOAD_STRSES_INT (path, content, 'text/xml', exec_perm, http_dav_uid (), http_dav_uid () + 1, null, null, 0);
  DB.DBA.DAV_PROP_SET_INT (path, 'xml-template', 'execute', 'dav', null, 0, 0, 1);
  DB.DBA.DAV_PROP_SET_INT (path, 'xml-sql-encoding', 'utf-8', 'dav', null, 0, 0, 1);
  DB.DBA.DAV_PROP_SET_INT (path, 'xml-sql-description', 'RDF based XML document generated by OpenLink Calendar', 'dav', null, 0, 0, 1);

  return;
}
;

-------------------------------------------------------------------------------
--
create procedure CAL.WA.domain_gems_delete (
  in domain_id integer,
  in account_id integer,
  in appName varchar := 'Calendar',
  in appGems varchar := null)
{
  declare tmp, home, path varchar;

  home := CAL.WA.dav_home (account_id);
  if (isnull (home))
    return;

  if (isnull (appGems))
    appGems := CAL.WA.domain_gems_name (domain_id);
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
  if (not isinteger(tmp) and not length (tmp))
    DB.DBA.DAV_DELETE_INT (home, 1, null, null, 0);

  return 1;
}
;

-------------------------------------------------------------------------------
--
create procedure CAL.WA.domain_update (
  inout domain_id integer,
  inout account_id integer)
{
  CAL.WA.domain_gems_delete (domain_id, account_id, 'Calendar');
  CAL.WA.domain_gems_create (domain_id, account_id);

  return 1;
}
;

-------------------------------------------------------------------------------
--
create procedure CAL.WA.domain_owner_id (
  inout domain_id integer)
{
  return (select A.WAM_USER from WA_MEMBER A, WA_INSTANCE B where A.WAM_MEMBER_TYPE = 1 and A.WAM_INST = B.WAI_NAME and B.WAI_ID = domain_id);
}
;

-------------------------------------------------------------------------------
--
create procedure CAL.WA.domain_owner_name (
  inout domain_id integer)
{
  return (select C.U_NAME from WA_MEMBER A, WA_INSTANCE B, SYS_USERS C where A.WAM_MEMBER_TYPE = 1 and A.WAM_INST = B.WAI_NAME and B.WAI_ID = domain_id and C.U_ID = A.WAM_USER);
}
;

-------------------------------------------------------------------------------
--
create procedure CAL.WA.domain_delete (
  in domain_id integer)
{
  VHOST_REMOVE(lpath => concat('/calendar/', cast (domain_id as varchar)));
  return 1;
}
;

-------------------------------------------------------------------------------
--
create procedure CAL.WA.domain_id (
  in domain_name varchar)
{
  return (select WAI_ID from DB.DBA.WA_INSTANCE where WAI_NAME = domain_name);
}
;

-------------------------------------------------------------------------------
--
create procedure CAL.WA.domain_name (
  in domain_id integer)
{
  return coalesce((select WAI_NAME from DB.DBA.WA_INSTANCE where WAI_ID = domain_id), 'Calendar Instance');
}
;

-------------------------------------------------------------------------------
--
create procedure CAL.WA.domain_gems_name (
  in domain_id integer)
{
  return concat(CAL.WA.domain_name(domain_id), '_Gems');
}
;

-------------------------------------------------------------------------------
--
create procedure CAL.WA.domain_description (
  in domain_id integer)
{
  return coalesce((select coalesce(WAI_DESCRIPTION, WAI_NAME) from DB.DBA.WA_INSTANCE where WAI_ID = domain_id), 'Calendar Instance');
}
;

-------------------------------------------------------------------------------
--
create procedure CAL.WA.domain_is_public (
  in domain_id integer)
{
  return coalesce((select WAI_IS_PUBLIC from DB.DBA.WA_INSTANCE where WAI_ID = domain_id), 0);
}
;

-------------------------------------------------------------------------------
--
create procedure CAL.WA.domain_ping (
  in domain_id integer)
{
  for (select WAI_NAME, WAI_DESCRIPTION from DB.DBA.WA_INSTANCE where WAI_ID = domain_id and WAI_IS_PUBLIC = 1) do {
    ODS..APP_PING (WAI_NAME, coalesce (WAI_DESCRIPTION, WAI_NAME), CAL.WA.sioc_url (domain_id));
  }
}
;

-------------------------------------------------------------------------------
--
-- Account Functions
--
-------------------------------------------------------------------------------
create procedure CAL.WA.account()
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
create procedure CAL.WA.account_access (
  out auth_uid varchar,
  out auth_pwd varchar)
{
  auth_uid := CAL.WA.account();
  auth_pwd := coalesce((SELECT U_PWD FROM WS.WS.SYS_DAV_USER WHERE U_NAME = auth_uid), '');
  if (auth_pwd[0] = 0)
    auth_pwd := pwd_magic_calc(auth_uid, auth_pwd, 1);
  return 1;
}
;

-------------------------------------------------------------------------------
--
create procedure CAL.WA.account_delete(
  in domain_id integer,
  in account_id integer)
{
  declare iCount any;

  select count(WAM_USER) into iCount
    from WA_MEMBER,
         WA_INSTANCE
   where WAI_NAME = WAM_INST
     and WAI_TYPE_NAME = 'Calendar'
     and WAM_USER = account_id;

  if (iCount = 0) {
    delete from CAL.WA.SETTINGS where S_ACCOUNT_ID = account_id;
  }
  CAL.WA.domain_gems_delete (domain_id, account_id);

  return 1;
}
;

-------------------------------------------------------------------------------
--
create procedure CAL.WA.account_name (
  in account_id integer)
{
  return coalesce((select U_NAME from DB.DBA.SYS_USERS where U_ID = account_id), '');
}
;

-------------------------------------------------------------------------------
--
create procedure CAL.WA.account_fullName (
  in account_id integer)
{
  return coalesce((select coalesce(U_FULL_NAME, U_NAME) from DB.DBA.SYS_USERS where U_ID = account_id), '');
}
;

-------------------------------------------------------------------------------
--
create procedure CAL.WA.account_mail(
  in account_id integer)
{
  return coalesce((select U_E_MAIL from DB.DBA.SYS_USERS where U_ID = account_id), '');
}
;

-------------------------------------------------------------------------------
--
create procedure CAL.WA.user_name(
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
create procedure CAL.WA.tag_prepare(
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
create procedure CAL.WA.tag_delete(
  inout tags varchar,
  inout T integer)
{
  declare N integer;
  declare tags2 any;

  tags2 := CAL.WA.tags2vector(tags);
  tags := '';
  for (N := 0; N < length (tags2); N := N + 1)
    if (N <> T)
      tags := concat(tags, ',', tags2[N]);
  return trim(tags, ',');
}
;

---------------------------------------------------------------------------------
--
create procedure CAL.WA.tags_join(
  inout tags varchar,
  inout tags2 varchar)
{
  declare resultTags any;

  if (is_empty_or_null(tags))
    return tags2;
  if (is_empty_or_null(tags2))
    return tags;

  resultTags := concat(tags, ',', tags2);
  resultTags := CAL.WA.tags2vector(resultTags);
  resultTags := CAL.WA.tags2unique(resultTags);
  resultTags := CAL.WA.vector2tags(resultTags);
  return resultTags;
}
;

---------------------------------------------------------------------------------
--
create procedure CAL.WA.tags2vector(
  inout tags varchar)
{
  return split_and_decode(trim(tags, ','), 0, '\0\0,');
}
;

---------------------------------------------------------------------------------
--
create procedure CAL.WA.tags2search(
  in tags varchar)
{
  declare S varchar;
  declare V any;

  S := '';
  V := CAL.WA.tags2vector(tags);
  foreach (any tag in V) do
    S := concat(S, ' ^T', replace (replace (trim(lcase(tag)), ' ', '_'), '+', '_'));
  return FTI_MAKE_SEARCH_STRING(trim(S, ','));
}
;

-------------------------------------------------------------------------------
--
create procedure CAL.WA.vector2tags(
  inout aVector any)
{
  declare N integer;
  declare aResult any;

  aResult := '';
  for (N := 0; N < length (aVector); N := N + 1)
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
create procedure CAL.WA.tags2unique(
  inout aVector any)
{
  declare aResult any;
  declare N, M integer;

  aResult := vector();
  for (N := 0; N < length (aVector); N := N + 1) {
    for (M := 0; M < length (aResult); M := M + 1)
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
create procedure CAL.WA.dav_home(
  inout account_id integer) returns varchar
{
  declare name, home any;
  declare cid integer;

  name := coalesce((select U_NAME from DB.DBA.SYS_USERS where U_ID = account_id), -1);
  if (isinteger(name))
    return null;
  home := CAL.WA.dav_home_create(name);
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
create procedure CAL.WA.dav_home_create(
  in user_name varchar) returns any
{
  declare user_id, cid integer;
  declare user_home varchar;

  whenever not found goto _error;

  if (is_empty_or_null(user_name))
    goto _error;
  user_home := DB.DBA.DAV_HOME_DIR(user_name);
  if (isstring (user_home))
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
create procedure CAL.WA.host_url ()
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
create procedure CAL.WA.calendar_url (
  in domain_id integer)
{
  return concat(CAL.WA.host_url(), '/calendar/', cast (domain_id as varchar), '/');
}
;

-------------------------------------------------------------------------------
--
create procedure CAL.WA.sioc_url (
  in domain_id integer)
{
  return sprintf ('http://%s/dataspace/%U/calendar/%U/sioc.rdf', DB.DBA.wa_cname (), CAL.WA.domain_owner_name (domain_id), replace (CAL.WA.domain_name (domain_id), '+', '%2B'));
}
;

-------------------------------------------------------------------------------
--
create procedure CAL.WA.foaf_url (
  in domain_id integer)
{
  return SIOC..person_iri (sprintf('http://%s%s/%s#this', SIOC..get_cname (), SIOC..get_base_path (), CAL.WA.domain_owner_name (domain_id)), '/about.rdf');
}
;

-------------------------------------------------------------------------------
--
create procedure CAL.WA.event_url (
  in domain_id integer,
  in event_id integer)
{
  return concat(CAL.WA.calendar_url (domain_id), 'home.vspx?id=', cast (event_id as varchar));
}
;

-------------------------------------------------------------------------------
--
create procedure CAL.WA.dav_url (
  in domain_id integer)
{
  declare home varchar;

  home := CAL.WA.dav_home (CAL.WA.domain_owner_id (domain_id));
  if (isnull (home))
    return '';
  return concat('http://', DB.DBA.wa_cname (), home, 'Calendar/', CAL.WA.domain_gems_name (domain_id), '/');
}
;

-------------------------------------------------------------------------------
--
create procedure CAL.WA.dav_url2 (
  in domain_id integer,
  in account_id integer)
{
  declare home varchar;

  home := CAL.WA.dav_home(account_id);
  if (isnull (home))
    return '';
  return replace (concat(home, 'Calendar/', CAL.WA.domain_gems_name(domain_id), '/'), ' ', '%20');
}
;

-------------------------------------------------------------------------------
--
create procedure CAL.WA.geo_url (
  in domain_id integer,
  in account_id integer)
{
  for (select WAUI_LAT, WAUI_LNG from WA_USER_INFO where WAUI_U_ID = account_id) do
    if ((not isnull (WAUI_LNG)) and (not isnull (WAUI_LAT)))
      return sprintf ('\n    <meta name="ICBM" content="%.2f, %.2f"><meta name="DC.title" content="%s">', WAUI_LNG, WAUI_LAT, CAL.WA.domain_name (domain_id));
  return '';
}
;

-------------------------------------------------------------------------------
--
create procedure CAL.WA.dav_content (
  inout uri varchar)
{
  declare cont varchar;
  declare hp any;

  declare exit handler for sqlstate '*' { return null;};

  declare N integer;
  declare oldUri, newUri, reqHdr, resHdr varchar;
  declare auth_uid, auth_pwd varchar;

  newUri := uri;
  reqHdr := null;
  CAL.WA.account_access (auth_uid, auth_pwd);
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

-------------------------------------------------------------------------------
--
create procedure CAL.WA.xslt_root()
{
  declare sHost varchar;

  sHost := cast (registry_get('calendar_path') as varchar);
  if (sHost = '0')
    return 'file://apps/calendar/xslt/';
  if (isnull (strstr(sHost, '/DAV/VAD')))
    return sprintf ('file://%sxslt/', sHost);
  return sprintf ('virt://WS.WS.SYS_DAV_RES.RES_FULL_PATH.RES_CONTENT:%sxslt/', sHost);
}
;

-------------------------------------------------------------------------------
--
create procedure CAL.WA.xslt_full(
  in xslt_file varchar)
{
  return concat(CAL.WA.xslt_root(), xslt_file);
}
;

-----------------------------------------------------------------------------
--
create procedure CAL.WA.xml_set(
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
    XMLAppendChildren(aEntity, xtree_doc(sprintf ('<entry ID="%s">%s</entry>', id, CAL.WA.xml2string(value))));
  }
  return pXml;
}
;

-----------------------------------------------------------------------------
--
create procedure CAL.WA.xml_get(
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

  return CAL.WA.wide2utf(value);
}
;

-------------------------------------------------------------------------------
--
create procedure CAL.WA.string2xml (
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
create procedure CAL.WA.xml2string(
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
create procedure CAL.WA.normalize_space(
  in S varchar)
{
  return xpath_eval ('normalize-space (string(/a))', XMLELEMENT('a', S), 1);
}
;

-------------------------------------------------------------------------------
--
create procedure CAL.WA.utfClear(
  inout S varchar)
{
  declare N integer;
  declare retValue varchar;

  retValue := '';
  for (N := 0; N < length (S); N := N + 1) {
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
create procedure CAL.WA.utf2wide (
  inout S any)
{
  if (isstring (S))
    return charset_recode (S, 'UTF-8', '_WIDE_');
  return S;
}
;

-------------------------------------------------------------------------------
--
create procedure CAL.WA.wide2utf (
  inout S any)
{
  if (iswidestring (S))
    return charset_recode (S, '_WIDE_', 'UTF-8' );
  return charset_recode (S, null, 'UTF-8' );
}
;

-------------------------------------------------------------------------------
--
create procedure CAL.WA.stringCut (
  in S varchar,
  in L integer := 60)
{
  declare tmp any;

  if (not L)
    return S;
  tmp := CAL.WA.utf2wide(S);
  if (not iswidestring(tmp))
    return S;
  if (length (tmp) > L)
    return CAL.WA.wide2utf(concat(subseq(tmp, 0, L-3), '...'));
  return CAL.WA.wide2utf(tmp);
}
;

-------------------------------------------------------------------------------
--
create procedure CAL.WA.vector_unique(
  inout aVector any,
  in minLength integer := 0)
{
  declare aResult any;
  declare N, M integer;

  aResult := vector();
  for (N := 0; N < length (aVector); N := N + 1) {
    if ((minLength = 0) or (length (aVector[N]) >= minLength)) {
      for (M := 0; M < length (aResult); M := M + 1)
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
create procedure CAL.WA.vector_except(
  inout aVector any,
  inout aExcept any)
{
  declare aResult any;
  declare N, M integer;

  aResult := vector();
  for (N := 0; N < length (aVector); N := N + 1) {
    for (M := 0; M < length (aExcept); M := M + 1)
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
create procedure CAL.WA.vector_contains(
  inout aVector any,
  in value varchar)
{
  declare N integer;

  for (N := 0; N < length (aVector); N := N + 1)
    if (value = aVector[N])
      return 1;
  return 0;
}
;

-------------------------------------------------------------------------------
--
create procedure CAL.WA.vector_indexOf (
  inout aVector any,
  in value varchar,
  in notFoundIndex integer := null)
{
  declare N integer;

  for (N := 0; N < length (aVector); N := N + 1)
    if (value = aVector[N])
      return N;
  return notFoundIndex;
}
;

-------------------------------------------------------------------------------
--
create procedure CAL.WA.vector_cut(
  inout aVector any,
  in value varchar)
{
  declare N integer;
  declare retValue any;

  retValue := vector ();
  for (N := 0; N < length (aVector); N := N + 1)
    if (value <> aVector[N])
      retValue := vector_concat (retValue, vector(aVector[N]));
  return retValue;
}
;

-------------------------------------------------------------------------------
--
create procedure CAL.WA.vector_set (
  inout aVector any,
  in aIndex any,
  in aValue varchar)
{
  declare N integer;
  declare retValue any;

  retValue := vector();
  for (N := 0; N < length (aVector); N := N + 1)
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
create procedure CAL.WA.vector_search(
  in aVector any,
  in value varchar,
  in condition vrchar := 'AND')
{
  declare N integer;

  for (N := 0; N < length (aVector); N := N + 1)
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
create procedure CAL.WA.vector2str(
  inout aVector any,
  in delimiter varchar := ' ')
{
  declare tmp, aResult any;
  declare N integer;

  aResult := '';
  for (N := 0; N < length (aVector); N := N + 1) {
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
create procedure CAL.WA.vector2rs(
  inout aVector any)
{
  declare N integer;
  declare c0 varchar;

  result_names(c0);
  for (N := 0; N < length (aVector); N := N + 1)
    result(aVector[N]);
}
;

-------------------------------------------------------------------------------
--
create procedure CAL.WA.tagsDictionary2rs(
  inout aDictionary any)
{
  declare N integer;
  declare c0 varchar;
  declare c1 integer;
  declare V any;

  V := dict_to_vector(aDictionary, 1);
  result_names(c0, c1);
  for (N := 1; N < length (V); N := N + 2)
    result(V[N][0], V[N][1]);
}
;

-------------------------------------------------------------------------------
--
create procedure CAL.WA.vector2src(
  inout aVector any)
{
  declare N integer;
  declare aResult any;

  aResult := 'vector(';
  for (N := 0; N < length (aVector); N := N + 1) {
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
create procedure CAL.WA.ft2vector(
  in S any)
{
  declare w varchar;
  declare aResult any;

  aResult := vector();
  w := regexp_match ('["][^"]+["]|[''][^'']+['']|[^"'' ]+', S, 1);
  while (w is not null) {
    w := trim (w, '"'' ');
    if (upper(w) not in ('AND', 'NOT', 'NEAR', 'OR') and length (w) > 1 and not vt_is_noise (CAL.WA.wide2utf(w), 'utf-8', 'x-ViDoc'))
      aResult := vector_concat(aResult, vector(w));
    w := regexp_match ('["][^"]+["]|[''][^'']+['']|[^"'' ]+', S, 1);
  }
  return aResult;
}
;

-------------------------------------------------------------------------------
--
create procedure CAL.WA.set_keyword (
  in    name   varchar,
  inout params any,
  in    value  any)
{
  declare N integer;

  for (N := 0; N < length (params); N := N + 2)
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
-- Show functions
--
-------------------------------------------------------------------------------
--
create procedure CAL.WA.show_text (
  in S any,
  in S2 any)
{
  if (isstring (S))
    S := trim(S);
  if (is_empty_or_null(S))
    return sprintf ('No %s', S2);
  return S;
}
;

-------------------------------------------------------------------------------
--
create procedure CAL.WA.show_title(
  in S any)
{
  return CAL.WA.show_text(S, 'title');
}
;

-------------------------------------------------------------------------------
--
create procedure CAL.WA.show_subject (
  in S any)
{
  return CAL.WA.show_text(S, 'subject');
}
;

-------------------------------------------------------------------------------
--
create procedure CAL.WA.show_author(
  in S any)
{
  return CAL.WA.show_text(S, 'author');
}
;

-------------------------------------------------------------------------------
--
create procedure CAL.WA.show_description(
  in S any)
{
  return CAL.WA.show_text(S, 'description');
}
;

-------------------------------------------------------------------------------
--
create procedure CAL.WA.show_excerpt(
  in S varchar,
  in words varchar)
{
  return coalesce (search_excerpt (words, cast (S as varchar)), '');
}
;

-------------------------------------------------------------------------------
--
-- Date / Time functions
--
-------------------------------------------------------------------------------
--
-- returns user's now (based on timezone)
--
--------------------------------------------------------------------------------
create procedure CAL.WA.dt_now (
  in tz integer := null)
{
  if (isnull (tz))
    tz := timezone (now());
  return dateadd ('minute', tz - timezone (now()), now());
}
;

-----------------------------------------------------------------------------
--
create procedure CAL.WA.dt_decode (
  inout pDateTime datetime,
  inout pYear integer,
  inout pMonth integer,
  inout pDay integer,
  inout pHour integer,
  inout pMinute integer)
{
  pYear := year (pDateTime);
  pMonth := month (pDateTime);
  pDay := dayofmonth (pDateTime);
  pHour := hour (pDateTime);
  pMinute := minute (pDateTime);
}
;

-----------------------------------------------------------------------------
--
create procedure CAL.WA.dt_encode (
  in pYear integer,
  in pMonth integer,
  in pDay integer,
  in pHour integer,
  in pMinute integer,
  in pSeconds integer := 0)
{
  return stringdate (sprintf ('%d.%d.%d %d:%d:%d', pYear, pMonth, pDay, pHour, pMinute, pSeconds));
}
;

-----------------------------------------------------------------------------
--
create procedure CAL.WA.dt_join (
  in pDate date,
  in pTime time)
{
  declare pYear, pMonth, pDay, pHour, pMinute integer;

  CAL.WA.dt_dateDecode (pDate, pYear, pMonth, pDay);
  CAL.WA.dt_timeDecode (pTime, pHour, pMinute);
  return CAL.WA.dt_encode (pYear, pMonth, pDay, pHour, pMinute);
}
;

--------------------------------------------------------------------------------
--
-- compare two dates by yyyy.mm.dd components
--
--------------------------------------------------------------------------------
create procedure CAL.WA.dt_compare (
  in pDate1 datetime,
  in pDate2 datetime)
{
  if ((year (pDate1) = year (pDate2)) and (month (pDate1) = month (pDate2)) and (dayofmonth (pDate1) = dayofmonth (pDate2)))
    return 1;
  return 0;
}
;

--------------------------------------------------------------------------------
--
-- returns user's date (based on timezone)
--
--------------------------------------------------------------------------------
create procedure CAL.WA.dt_curdate (
  in tz integer := null)
{
  declare pYear, pMonth, pDay integer;
  declare dt date;

  if (isnull (tz))
    tz := timezone (now());
  return CAL.WA.dt_dateClear (dateadd ('minute', tz - timezone (now()), now()));
}
;

--------------------------------------------------------------------------------
--
-- returns date without time
--
--------------------------------------------------------------------------------
create procedure CAL.WA.dt_dateClear (
  in pDate date)
{
  declare pYear, pMonth, pDay integer;

  if (isnull (pDate))
    return pDate;
  CAL.WA.dt_dateDecode (pDate, pYear, pMonth, pDay);
  return CAL.WA.dt_dateEncode (pYear, pMonth, pDay);
}
;

--------------------------------------------------------------------------------
--
-- returns user's date (based on timezone)
--
--------------------------------------------------------------------------------
create procedure CAL.WA.dt_curtime (
  in tz integer := null)
{
  if (isnull (tz))
    tz := timezone (now());
  return cast (dateadd ('minute', tz - timezone (now()), now()) as time);
}
;

-----------------------------------------------------------------------------
--
create procedure CAL.WA.dt_datetimestring (
  in dt datetime,
  in pDateFormat varchar := 'd.m.Y',
  in pTimeFormat varchar := 'e')
{
  return CAL.WA.dt_datestring (dt, pDateFormat) || ' ' || CAL.WA.dt_timestring (dt, pTimeFormat);
}
;

-----------------------------------------------------------------------------
--
create procedure CAL.WA.dt_datestring (
  in dt datetime,
  in pFormat varchar := 'd.m.Y')
{
  return CAL.WA.dt_format (dt, pFormat);
}
;

-----------------------------------------------------------------------------
--
create procedure CAL.WA.dt_stringdate (
  in pString varchar,
  in pFormat varchar := 'd.m.Y')
{
  return CAL.WA.dt_deformat (pString, pFormat);
}
;

-----------------------------------------------------------------------------
--
create procedure CAL.WA.dt_dateDecode(
  inout pDate date,
  inout pYear integer,
  inout pMonth integer,
  inout pDay integer)
{
  pYear := year (pDate);
  pMonth := month (pDate);
  pDay := dayofmonth (pDate);
}
;

-----------------------------------------------------------------------------
--
create procedure CAL.WA.dt_dateEncode(
  in pYear integer,
  in pMonth integer,
  in pDay integer)
{
  return cast (stringdate (sprintf ('%d.%d.%d', pYear, pMonth, pDay)) as date);
}
;

-----------------------------------------------------------------------------
--
create procedure CAL.WA.dt_format (
  in dt datetime,
  in pFormat varchar := 'd.m.Y')
{
  declare
    N integer;
  declare
    ch,
    S varchar;

  declare exit handler for sqlstate '*' {
    return '';
  };

  pFormat := CAL.WA.dt_formatTemplate (pFormat);
  S := '';
  N := 1;
  while (N <= length (pFormat))
  {
    ch := substring (pFormat, N, 1);
    if (ch = 'M')
    {
      S := concat(S, xslt_format_number(month(dt), '00'));
    } else {
      if (ch = 'm')
      {
        S := concat(S, xslt_format_number(month(dt), '##'));
      } else
      {
        if (ch = 'Y')
        {
          S := concat(S, xslt_format_number(year(dt), '0000'));
        } else
        {
          if (ch = 'y')
          {
            S := concat(S, substring (xslt_format_number(year(dt), '0000'),3,2));
          } else {
            if (ch = 'd')
            {
              S := concat(S, xslt_format_number(dayofmonth(dt), '##'));
            } else
            {
              if (ch = 'D')
              {
                S := concat(S, xslt_format_number(dayofmonth(dt), '00'));
              } else
              {
                if (ch = 'H')
                {
                  S := concat(S, xslt_format_number(hour(dt), '00'));
                } else
                {
                  if (ch = 'h')
                  {
                    S := concat(S, xslt_format_number(hour(dt), '##'));
                  } else
                  {
                    if (ch = 'N')
                    {
                      S := concat(S, xslt_format_number(minute(dt), '00'));
                    } else
                    {
                      if (ch = 'n')
                      {
                        S := concat(S, xslt_format_number(minute(dt), '##'));
                      } else
                      {
                        if (ch = 'S')
                        {
                          S := concat(S, xslt_format_number(second(dt), '00'));
                        } else
                        {
                          if (ch = 's')
                          {
                            S := concat(S, xslt_format_number(second(dt), '##'));
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
create procedure CAL.WA.dt_deformat (
  in pString varchar,
  in pFormat varchar := 'd.m.Y')
{
  declare
    y,
    m,
    d integer;
  declare
    N,
    I integer;
  declare
    ch varchar;

  pFormat := CAL.WA.dt_formatTemplate (pFormat);
  N := 1;
  I := 0;
  d := 0;
  m := 0;
  y := 0;
  while (N <= length (pFormat)) {
    ch := upper (substring (pFormat, N, 1));
    if (ch = 'M')
      m := CAL.WA.dt_deformat_tmp (pString, I);
    if (ch = 'D')
      d := CAL.WA.dt_deformat_tmp (pString, I);
    if (ch = 'Y') {
      y := CAL.WA.dt_deformat_tmp (pString, I);
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
create procedure CAL.WA.dt_deformat_tmp (
  in S varchar,
  inout N varchar)
{
  declare V any;

  V := regexp_parse('[0-9]+', S, N);
  if (length (V) > 1) {
    N := V[1];
    return atoi (subseq (S, V[0], V[1]));
  }
  N := N + 1;
  return 0;
}
;

-----------------------------------------------------------------------------
--
create procedure CAL.WA.dt_reformat(
  in pString varchar,
  in pInFormat varchar := 'd.m.Y',
  in pOutFormat varchar := 'm.d.Y')
{
  pInFormat := CAL.WA.dt_formatTemplate (pInFormat);
  pOutFormat := CAL.WA.dt_formatTemplate (pOutFormat);
  return CAL.WA.dt_format(CAL.WA.dt_deformat(pString, pInFormat), pOutFormat);
}
;

-----------------------------------------------------------------------------
--
create procedure CAL.WA.dt_formatTemplate (
  in pFormat varchar := 'dd.MM.yyyy')
{
  if (pFormat = 'dd.MM.yyyy')
    return 'D.M.Y';
  if (pFormat = 'MM/dd/yyyy')
    return 'M/d/Y';
  if (pFormat = 'yyyy/MM/dd')
    return 'Y/M/d';
  return pFormat;
}
;

-----------------------------------------------------------------------------
--
create procedure CAL.WA.dt_timeDecode(
  inout pTime time,
  inout pHour integer,
  inout pMinute integer)
{
  pHour := hour (pTime);
  pMinute := minute (pTime);
}
;

-----------------------------------------------------------------------------
--
create procedure CAL.WA.dt_timeEncode(
  in pHour integer,
  in pMinute integer,
  in pSecond integer := 0)
{
  return stringtime (sprintf ('%d:%d:%d', pHour, pMinute, pSecond));
}
;

-----------------------------------------------------------------------------
--
create procedure CAL.WA.dt_timestring (
  in pTime integer,
  in pFormat varchar := 'e')
{
  declare h, m integer;

  CAL.WA.dt_timeDecode (pTime, h, m);
  if (pFormat = 'e')
    return sprintf ('%s:%s', xslt_format_number (h, '00'), xslt_format_number (m, '00'));
  if (h = 0)
    return '12:00 am';
  if (h < 12)
    return sprintf ('%s:%s am', xslt_format_number (h, '00'), xslt_format_number (m, '00'));
  if (h = 12)
    return '12:00 pm';
  if (h < 24)
    return sprintf ('%s:%s pm', xslt_format_number (h-12, '00'), xslt_format_number (m, '00'));
  return '';
}
;

-----------------------------------------------------------------------------
--
create procedure CAL.WA.dt_stringtime (
  in pString varchar)
{
  declare am, pm integer;
  declare pTime time;

  am := 0;
  pm := 0;
  pString := lcase (pString);
  if (not isnull (strstr (pString, 'am'))) {
    am := 1;
    pString := replace (pString, 'am', '');
  }
  if (not isnull (strstr (pString, 'pm'))) {
    pm := 1;
    pString := replace (pString, 'pm', '');
  }
  pTime := stringtime (trim (pString));
  if (am = 1) {
    if (hour (pTime) = 12)
      pTime := dateadd ('hour', 12, pTime);
  }
  if (pm = 1) {
    if (hour (pTime) = 12) {
      pTime := dateadd ('hour', -12, pTime);
    } else {
      pTime := dateadd ('hour', 12, pTime);
    }
  }
  return cast (pTime as time);
}
;

-----------------------------------------------------------------------------------------
--
create procedure CAL.WA.dt_timeFloor (
  in pTime integer,
  in pRound integer := 0)
{
  declare h, m integer;

  if (pRound = 0)
    return pTime;
  CAL.WA.dt_timeDecode (pTime, h, m);
  return CAL.WA.dt_timeEncode (h, floor (cast (m as float) / pRound) * pRound);
}
;

-----------------------------------------------------------------------------------------
--
create procedure CAL.WA.dt_timeCeiling (
  in pTime integer,
  in pRound integer := 0)
{
  declare h, m integer;

  if (pRound = 0)
    return pTime;
  CAL.WA.dt_timeDecode (pTime, h, m);
  return CAL.WA.dt_timeEncode (h, ceiling (cast (m as float) / pRound) * pRound);
}
;

-----------------------------------------------------------------------------------------
--
create procedure CAL.WA.dt_rfc1123 (
  in dt datetime)
{
  return soap_print_box (dt, '', 1);
}
;

-----------------------------------------------------------------------------------------
--
create procedure CAL.WA.dt_iso8601 (
  in dt datetime)
{
  return soap_print_box (dt, '', 0);
}
;

-----------------------------------------------------------------------------------------
--
-- the week kind: s - Sunday;
--                m - Monday
--
create procedure CAL.WA.dt_WeekDay (
  in dt datetime,
  in weekStarts varchar := 'm')
{
  declare dw integer;

  dw := dayofweek (dt);
  if (weekStarts = 'm') {
    if (dw = 1)
      return 7;
    return dw - 1;
  }
  return dw;
}
;

-----------------------------------------------------------------------------------------
--
create procedure CAL.WA.dt_isWeekDay (
  in dt datetime,
  in weekStarts varchar := 'm')
{
  declare dw integer;

  dw := CAL.WA.dt_WeekDay (dt, weekStarts);
  if ((weekStarts = 'm') and (dw <= 5))
    return 1;
  if ((weekStarts = 's') and ((dw >= 2) and (dw <= 6)))
    return 1;
  return 0;
}
;

-----------------------------------------------------------------------------------------
--
create procedure CAL.WA.dt_WeekName (
  in dt datetime,
  in weekStarts varchar := 'm',
  in nameLenght integer := 0)
{
  declare N integer;
  declare names any;

  N := CAL.WA.dt_WeekDay (dt, weekStarts);
  names := CAL.WA.dt_WeekNames (weekStarts, nameLenght);
  return names [N-1];
}
;

-----------------------------------------------------------------------------------------
--
create procedure CAL.WA.dt_WeekNames (
  in weekStarts varchar := 'm',
  in nameLenght integer := 0)
{
  declare N integer;
  declare names any;

  if (weekStarts = 'm') {
    names := vector ('Monday', 'Tuesday', 'Wednesday', 'Thursday ', 'Friday', 'Saturday', 'Sunday');
  } else {
    names := vector ('Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday ', 'Friday', 'Saturday');
  }
  if (nameLenght <> 0)
    for (N := 0; N < length (names); N := N + 1)
      aset (names, N, subseq (names[N], 0, nameLenght));
  return names;

}
;

-----------------------------------------------------------------------------------------
--
create procedure CAL.WA.dt_BeginOfWeek (
  in dt date,
  in weekStarts varchar := 'm')
{
  return CAL.WA.dt_dateClear (dateadd ('day', 1-CAL.WA.dt_WeekDay (dt, weekStarts), dt));
}
;

-----------------------------------------------------------------------------------------
--
create procedure CAL.WA.dt_EndOfWeek (
  in dt date,
  in weekStarts varchar := 'm')
{
  return CAL.WA.dt_dateClear (dateadd ('day', -1, dateadd ('day', 7, CAL.WA.dt_BeginOfWeek (dt, weekStarts))));
}
;

-----------------------------------------------------------------------------------------
--
create procedure CAL.WA.dt_BeginOfMonth (
  in dt datetime)
{
  return dateadd ('day', -(dayofmonth (dt)-1), dt);
}
;

-----------------------------------------------------------------------------------------
--
create procedure CAL.WA.dt_EndOfMonth (
  in dt datetime)
{
  return dateadd ('day', -1, dateadd ('month', 1, CAL.WA.dt_BeginOfMonth (dt)));
}
;

-----------------------------------------------------------------------------------------
--
create procedure CAL.WA.dt_LastDayOfMonth (
  in dt datetime)
{
  return dayofmonth (CAL.WA.dt_EndOfMonth (dt));
}
;

-----------------------------------------------------------------------------
--
create procedure CAL.WA.p_decode (
  inout pPeriod varchar,
  inout pYear integer,
  inout pMonth integer,
  inout pDay integer,
  inout pWeek integer,
  inout pHour integer,
  inout pMinute integer,
  inout pSecond integer)
{
  declare N, T integer;
  declare ch, pMode varchar;

  pYear := 0;
  pMonth := 0;
  pDay := 0;
  pWeek := 0;
  pHour := 0;
  pMinute := 0;
  pSecond := 0;

  T := 0;
  for (N := 0; N < length (pPeriod); N := N + 1) {
    ch := chr (pPeriod[N]);
    if ((ch >= '0') and (ch <= '9')) {
      T := T * 10 + cast (ch as integer);
    } else {
      if (ch = 'P')
        pMode := 'P';
      if (ch = 'T')
        pMode := 'T';
      if ((ch = 'Y') and (pMode = 'P'))
        pYear := T;
      if ((ch = 'M') and (pMode = 'P'))
        pMonth := T;
      if ((ch = 'D') and (pMode = 'P'))
        pDay := T;
      if ((ch = 'W') and (pMode = 'P'))
        pWeek := T;
      if ((ch = 'H') and (pMode = 'T'))
        pHour := T;
      if ((ch = 'M') and (pMode = 'T'))
        pMinute := T;
      if ((ch = 'S') and (pMode = 'T'))
        pSecond := T;
      T := 0;
    }
  }
}
;

-----------------------------------------------------------------------------------------
--
create procedure CAL.WA.p_dateadd (
  in dt datetime,
  in period varchar)
{
  declare pYear, pMonth, pDay, pWeek, pHour, pMinute, pSecond integer;

  if (isnull (dt))
    return null;
  if (isnull (period))
    return null;

  CAL.WA.p_decode (period, pYear, pMonth, pDay, pWeek, pHour, pMinute, pSecond);
  if (pYear <> 0)
    dt := dateadd ('year', pYear, dt);
  if (pMonth <> 0)
    dt := dateadd ('month', pMonth, dt);
  if (pDay <> 0)
    dt := dateadd ('day', pDay, dt);
  if (pWeek <> 0)
    dt := dateadd ('day', pWeek*7, dt);
  if (pHour <> 0)
    dt := dateadd ('hour', pHour, dt);
  if (pMinute <> 0)
    dt := dateadd ('minute', pMinute, dt);
  if (pSecond <> 0)
    dt := dateadd ('second', pSecond, dt);

  return dt;
}
;

-----------------------------------------------------------------------------------------
--
create procedure CAL.WA.tz_decode (
  in S any,
  inout pMinutes integer)
{
  declare continue handler for SQLSTATE '*' {
    pMinutes := 0;
    return;
  };

  pMinutes := atoi (substring (S, 2, 2)) * 60 + atoi (substring (S, 4, 2));
  if (substring (S, 1, 1) = '+')
    pMinutes := -pMinutes;
}
;

-----------------------------------------------------------------------------------------
--
create procedure CAL.WA.tz_string (
  inout tz integer)
{
  declare continue handler for SQLSTATE '*' {
    return '+0000';
  };

  return case when (tz < 0) then '-' else '+' end ||
         xslt_format_number(floor (abs (tz) / 60), '00') ||
         xslt_format_number(mod (abs (tz), 60), '00');
}
;

-----------------------------------------------------------------------------------------
--
create procedure CAL.WA.test_clear (
  in S any)
{
  declare N integer;

  return substring (S, 1, coalesce(strstr(S, '<>'), length (S)));
}
;

-----------------------------------------------------------------------------------------
--
create procedure CAL.WA.test (
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

  valueClass := coalesce (get_keyword ('class', params), get_keyword ('type', params));
  valueType := coalesce (get_keyword ('type', params), get_keyword ('class', params));
  valueName := get_keyword ('name', params, 'Field');
  valueMessage := get_keyword ('message', params, '');
  tmp := get_keyword ('canEmpty', params);
  if (isnull (tmp)) {
    if (not isnull (get_keyword ('minValue', params))) {
      tmp := 0;
    } else if (get_keyword ('minLength', params, 0) <> 0) {
      tmp := 0;
    }
  }
  if (not isnull (tmp) and (tmp = 0) and is_empty_or_null(value)) {
    signal('EMPTY', '');
  } else if (is_empty_or_null(value)) {
    return value;
  }

  value := CAL.WA.validate2 (valueClass, value);

  if (valueType = 'integer') {
    tmp := get_keyword ('minValue', params);
    if ((not isnull (tmp)) and (value < tmp))
      signal('MIN', cast (tmp as varchar));

    tmp := get_keyword ('maxValue', params);
    if (not isnull (tmp) and (value > tmp))
      signal('MAX', cast (tmp as varchar));

  } else if (valueType = 'float') {
    tmp := get_keyword ('minValue', params);
    if (not isnull (tmp) and (value < tmp))
      signal('MIN', cast (tmp as varchar));

    tmp := get_keyword ('maxValue', params);
    if (not isnull (tmp) and (value > tmp))
      signal('MAX', cast (tmp as varchar));

  } else if (valueType = 'varchar') {
    tmp := get_keyword ('minLength', params);
    if (not isnull (tmp) and (length (CAL.WA.utf2wide(value)) < tmp))
      signal('MINLENGTH', cast (tmp as varchar));

    tmp := get_keyword ('maxLength', params);
    if (not isnull (tmp) and (length (CAL.WA.utf2wide(value)) > tmp))
      signal('MAXLENGTH', cast (tmp as varchar));
  }
  return value;
}
;

-----------------------------------------------------------------------------------------
--
create procedure CAL.WA.validate2 (
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
    return stringdate(CAL.WA.dt_reformat(propertyValue, 'd.m.Y', 'Y-M-D'));
  } else if (propertyType = 'date-dd.MM.yyyy') {
    if (isnull (regexp_match('^(0[1-9]|[12][0-9]|3[01])[- /.](0[1-9]|1[012])[- /.]((?:19|20)[0-9][0-9])\$', propertyValue)))
      goto _error;
    return CAL.WA.dt_stringdate (propertyValue, 'dd.MM.yyyy');
  } else if (propertyType = 'date-MM/dd/yyyy') {
    if (isnull (regexp_match('^(0[1-9]|1[012])[- /.](0[1-9]|[12][0-9]|3[01])[- /.]((?:19|20)[0-9][0-9])\$', propertyValue)))
      goto _error;
    return CAL.WA.dt_stringdate (propertyValue, 'MM/dd/yyyy');
  } else if (propertyType = 'date-yyyy/MM/dd') {
    if (isnull (regexp_match('^((?:19|20)[0-9][0-9])[- /.](0[1-9]|1[012])[- /.](0[1-9]|[12][0-9]|3[01])\$', propertyValue)))
      goto _error;
    return CAL.WA.dt_stringdate (propertyValue, 'yyyy/MM/dd');
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
    if (length (propertyValue))
      if (not CAL.WA.validate_freeTexts(propertyValue))
        goto _error;
  } else if (propertyType = 'free-text-expression') {
    if (length (propertyValue))
      if (not CAL.WA.validate_freeText(propertyValue))
        goto _error;
  } else if (propertyType = 'tags') {
    if (not CAL.WA.validate_tags(propertyValue))
      goto _error;
  }
  return propertyValue;

_error:
  signal('CLASS', propertyType);
}
;

-----------------------------------------------------------------------------------------
--
create procedure CAL.WA.validate (
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
create procedure CAL.WA.validate_freeText (
  in S varchar)
{
  declare st, msg varchar;

  if (upper(S) in ('AND', 'NOT', 'NEAR', 'OR'))
    return 0;
  if (length (S) < 2)
    return 0;
  if (vt_is_noise (CAL.WA.wide2utf(S), 'utf-8', 'x-ViDoc'))
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
create procedure CAL.WA.validate_freeTexts (
  in S any)
{
  declare w varchar;

  w := regexp_match ('["][^"]+["]|[''][^'']+['']|[^"'' ]+', S, 1);
  while (w is not null) {
    w := trim (w, '"'' ');
    if (not CAL.WA.validate_freeText(w))
      return 0;
    w := regexp_match ('["][^"]+["]|[''][^'']+['']|[^"'' ]+', S, 1);
  }
  return 1;
}
;

-----------------------------------------------------------------------------------------
--
create procedure CAL.WA.validate_tag (
  in T varchar)
{
  declare S any;
  
  S := T;
  S := replace (trim(S), '+', '_');
  S := replace (trim(S), ' ', '_');
  if (not CAL.WA.validate_freeText(S))
    return 0;
  if (not isnull (strstr(S, '"')))
    return 0;
  if (not isnull (strstr(S, '''')))
    return 0;
  if (length (S) < 2)
    return 0;
  if (length (S) > 50)
    return 0;
  return 1;
}
;

-----------------------------------------------------------------------------------------
--
create procedure CAL.WA.validate_tags (
  in S varchar)
{
  declare N integer;
  declare V any;

  V := CAL.WA.tags2vector(S);
  if (is_empty_or_null(V))
    return 0;
  if (length (V) <> length (CAL.WA.tags2unique(V)))
    return 0;
  for (N := 0; N < length (V); N := N + 1)
    if (not CAL.WA.validate_tag(V[N]))
      return 0;
  return 1;
}
;

-------------------------------------------------------------------------------
--
create procedure CAL.WA.dashboard_get(
  in domain_id integer,
  in user_id integer)
{
  declare ses any;

  ses := string_output ();
  http ('<calendar-db>', ses);
  for select top 10 *
        from (select a.E_SUBJECT,
                     SIOC..calendar_event_iri (domain_id, E_ID) E_URI,
                     coalesce (a.E_UPDATED, now ()) E_UPDATED
                from CAL.WA.EVENTS a,
                     DB.DBA.WA_INSTANCE b,
                     DB.DBA.WA_MEMBER c
                where a.E_DOMAIN_ID = domain_id
                  and b.WAI_ID = a.E_DOMAIN_ID
                  and c.WAM_INST = b.WAI_NAME
                  and c.WAM_USER = user_id
                order by a.E_UPDATED desc
             ) x do {

    declare uname, full_name varchar;

    uname := (select coalesce (U_NAME, '') from DB.DBA.SYS_USERS where U_ID = user_id);
    full_name := (select coalesce (coalesce (U_FULL_NAME, U_NAME), '') from DB.DBA.SYS_USERS where U_ID = user_id);

    http ('<event>', ses);
    http (sprintf ('<dt>%s</dt>', date_iso8601 (E_UPDATED)), ses);
    http (sprintf ('<title><![CDATA[%s]]></title>', coalesce (E_SUBJECT, 'No subject')), ses);
    http (sprintf ('<link><![CDATA[%s]]></link>', E_URI), ses);
    http (sprintf ('<from><![CDATA[%s]]></from>', full_name), ses);
    http (sprintf ('<uid>%s</uid>', uname), ses);
    http ('</event>', ses);
  }
  http ('</calendar-db>', ses);
  return string_output_string (ses);
}
;

-------------------------------------------------------------------------------
--
create procedure CAL.WA.settings (
  inout account_id integer)
{
  return coalesce((select deserialize(blob_to_string(S_DATA)) from CAL.WA.SETTINGS where S_ACCOUNT_ID = account_id), vector());
}
;

-------------------------------------------------------------------------------
--
create procedure CAL.WA.settings_rows (
  in settings any)
{
  return cast (get_keyword ('rows', settings, '10') as integer);
}
;

-------------------------------------------------------------------------------
--
create procedure CAL.WA.settings_chars (
  in settings any)
{
  return cast (get_keyword ('chars', settings, '0') as integer);
}
;

-------------------------------------------------------------------------------
--
create procedure CAL.WA.settings_atomVersion (
  in settings any)
{
  return get_keyword ('atomVersion', settings, '1.0');
}
;

-------------------------------------------------------------------------------
--
create procedure CAL.WA.settings_defaultView (
  in settings any)
{
  return get_keyword ('defaultView', settings, 'week');
}
;

-------------------------------------------------------------------------------
--
create procedure CAL.WA.settings_weekStarts (
  in settings any)
{
  return get_keyword ('weekStarts', settings, 'm');
}
;

-------------------------------------------------------------------------------
--
create procedure CAL.WA.settings_weekStarts2 (
  in domain_id integeger)
{
  CAL.WA.settings_weekStarts (CAL.WA.settings (CAL.WA.domain_owner_id (domain_id)));
}
;

-------------------------------------------------------------------------------
--
create procedure CAL.WA.settings_timeZone (
  in settings any)
{
  return cast (get_keyword ('timeZone', settings, '0') as integer);
}
;

-------------------------------------------------------------------------------
--
create procedure CAL.WA.settings_timeZone2 (
  in domain_id integeger)
{
  return CAL.WA.settings_timeZone (CAL.WA.settings (CAL.WA.domain_owner_id (domain_id)));
}
;
-------------------------------------------------------------------------------
--
create procedure CAL.WA.settings_dateFormat (
  in settings any)
{
  return get_keyword ('dateFormat', settings, 'dd.MM.yyyy');
}
;

-------------------------------------------------------------------------------
--
create procedure CAL.WA.settings_timeFormat (
  in settings any)
{
  return get_keyword ('timeFormat', settings, 'e');
}
;

-------------------------------------------------------------------------------
--
create procedure CAL.WA.settings_showTasks (
  in settings any)
{
  return cast (get_keyword ('showTasks', settings, '1') as integer);
}
;

-----------------------------------------------------------------------------------------
--
-- Events
--
-----------------------------------------------------------------------------------------
create procedure CAL.WA.event_kind (
  in id integer)
{
  declare tmp integer;

  tmp := (select E_KIND from CAL.WA.EVENTS where E_ID = id);
  if (tmp = 0)
    return 'event';
  if (tmp = 1)
    return 'task';
  if (tmp = 2)
    return 'note';
  return null;
}
;

-----------------------------------------------------------------------------------------
--
create procedure CAL.WA.event_update (
  in id integer,
  in domain_id integer,
  in subject varchar,
  in description varchar,
  in location varchar,
  in tags varchar,
  in event integer,
  in eEventStart datetime,
  in eEventEnd datetime,
  in eRepeat varchar,
  in eRepeatParam1 integer,
  in eRepeatParam2 integer,
  in eRepeatParam3 integer,
  in eRepeatUntil datetime,
  in eReminder integer,
  in notes varchar := '')
{
  if (id = -1) {
    id := sequence_next ('CAL.WA.event_id');
    insert into CAL.WA.EVENTS
      (
        E_ID,
        E_DOMAIN_ID,
        E_SUBJECT,
        E_DESCRIPTION,
        E_LOCATION,
        E_TAGS,
        E_EVENT,
        E_EVENT_START,
        E_EVENT_END,
        E_REPEAT,
        E_REPEAT_PARAM1,
        E_REPEAT_PARAM2,
        E_REPEAT_PARAM3,
        E_REPEAT_UNTIL,
        E_REMINDER,
        E_NOTES,
        E_CREATED,
        E_UPDATED
      )
      values
      (
        id,
        domain_id,
        subject,
        description,
        location,
        tags,
        event,
        eEventStart,
        eEventEnd,
        eRepeat,
        eRepeatParam1,
        eRepeatParam2,
        eRepeatParam3,
        eRepeatUntil,
        eReminder,
        notes,
        now (),
        now ()
      );
  } else {
    update CAL.WA.EVENTS
       set E_SUBJECT = subject,
           E_DESCRIPTION = description,
           E_LOCATION = location,
           E_TAGS = tags,
           E_EVENT = event,
           E_EVENT_START = eEventStart,
           E_EVENT_END = eEventEnd,
           E_REPEAT = eRepeat,
           E_REPEAT_PARAM1 = eRepeatParam1,
           E_REPEAT_PARAM2 = eRepeatParam2,
           E_REPEAT_PARAM3 = eRepeatParam3,
           E_REPEAT_UNTIL = eRepeatUntil,
           E_REMINDER = eReminder,
           E_NOTES = notes,
           E_UPDATED = now ()
     where E_ID = id and
           E_DOMAIN_ID = domain_id;
  }
  return id;
}
;

-------------------------------------------------------------------------------
--
create procedure CAL.WA.event_delete (
  in id integer,
  in domain_id integer,
  in onOffset varchar := null)
{
  if (isnull (onOffset)) {
  delete from CAL.WA.EVENTS where E_ID = id and E_DOMAIN_ID = domain_id;
  } else {
    declare eExceptions any;

    onOffset := '<' || cast (onOffset as varchar) || '>';
    eExceptions := (select E_REPEAT_EXCEPTIONS from CAL.WA.EVENTS where E_ID = id and E_DOMAIN_ID = domain_id);
    if (isnull (strstr (eExceptions, onOffset)))
      update CAL.WA.EVENTS
         set E_REPEAT_EXCEPTIONS = eExceptions || ' ' || onOffset
       where E_ID = id and
             E_DOMAIN_ID = domain_id;
  }
}
;

-------------------------------------------------------------------------------
--
create procedure CAL.WA.event_gmt2user (
  in pDate datetime,
  in pTimezone integer := 0)

{
  if (isnull (pDate))
    return pDate;
  return dateadd ('minute', pTimezone, pDate);
}
;

-------------------------------------------------------------------------------
--
create procedure CAL.WA.event_user2gmt (
  in pDate datetime,
  in pTimezone integer := 0)
{
  if (isnull (pDate))
    return pDate;
  return dateadd ('minute', -pTimezone, pDate);
}
;

-------------------------------------------------------------------------------
--
create procedure CAL.WA.event_occurAtDate (
  in dt datetime,
  in event integer,
  in eEventStart datetime,
  in eRepeat varchar,
  in eRepeatParam1 integer,
  in eRepeatParam2 integer,
  in eRepeatParam3 integer,
  in eRepeatUntil datetime,
  in eRepeatExceptions varchar,
  in weekStarts varchar := 'm')
{
  declare tmp, dtEnd any;

  -- after until date
  if ((not isnull (eRepeatUntil)) and (dt > eRepeatUntil))
    return 0;

  if (event = 1)
    eEventStart := dateadd ('hour', -12, eEventStart);

  dtEnd := dateadd ('second',86399, dt);
  -- before start date
  if (dtEnd < eEventStart)
    return 0;

  -- deleted occurence
  if (not isnull (strstr (eRepeatExceptions, '<' || cast (datediff ('day', CAL.WA.dt_dateClear (eEventStart), dt) as varchar) || '>')))
    return 0;

  -- Every N-th day(s)
  if (eRepeat = 'D1') {
    if (mod (datediff ('day', eEventStart, dtEnd), eRepeatParam1) = 0)
      return 1;
  }

  -- Every week day
  if (eRepeat = 'D2') {
    tmp := dayofweek (dt);
    if ((tmp > 1) and (tmp < 7))
      return 1;
  }

  -- Every N-th week on ...
  if (eRepeat = 'W1') {
    if (mod (datediff ('day', eEventStart, dtEnd) / 7, eRepeatParam1) = 0)
      if (bit_and (eRepeatParam2, power (2, CAL.WA.dt_WeekDay (dt, weekStarts)-1)))
        return 1;
  }

  -- Every N-th day of M-th month(s)
  if (eRepeat = 'M1') {
    if (mod (datediff ('month', eEventStart, dtEnd), eRepeatParam1) = 0)
      if (dayofmonth (dt) = eRepeatParam2)
        return 1;
  }

  -- Every X day/weekday/wekkend/... of Y-th month(s)
  if (eRepeat = 'M2') {
    if (mod (datediff ('month', eEventStart, dtEnd), eRepeatParam1) = 0)
      if (dayofmonth (dt) = CAL.WA.event_findDay (dt, eRepeatParam2, eRepeatParam3))
        return 1;
  }

  if (eRepeat = 'Y1') {
    if (mod (datediff ('year', eEventStart, dtEnd), eRepeatParam1) = 0)
      if ((month (dt) = eRepeatParam2) and (dayofmonth (dt) = eRepeatParam3))
      return 1;
  }

  -- Every X day/weekday/wekkend/... of Y-th month(s)
  if (eRepeat = 'Y2') {
    if (month (dt) = eRepeatParam3)
      if (dayofmonth (dt) = CAL.WA.event_findDay (dt, eRepeatParam1, eRepeatParam2))
        return 1;
  }

  return 0;
}
;

-------------------------------------------------------------------------------
--
create procedure CAL.WA.event_checkDate (
  in dt datetime,
  in event integer,
  in eEventStart datetime,
  in eRepeat varchar,
  in eRepeatParam1 integer,
  in eRepeatParam2 integer,
  in eRepeatParam3 integer,
  in eRepeatUntil datetime,
  in eRepeatExceptions varchar,
  in weekStarts varchar := 'm',
  inout iInterval integer)
{
  declare tmp, dtEnd any;

  -- after until date
  if ((not isnull (eRepeatUntil)) and (dt > eRepeatUntil))
    return 0;

  if (event = 1)
    eEventStart := dateadd ('hour', -12, eEventStart);

  dtEnd := dateadd ('second', 86399, dt);
  -- before start date
  if (dtEnd < eEventStart)
    return 0;

  -- Every N-th day(s)
  if (eRepeat = 'D1') {
    iInterval := eRepeatParam1;
    if (mod (datediff ('day', eEventStart, dtEnd), eRepeatParam1) = 0)
      return CAL.WA.event_checkNotDeletedOccurence (dt, eEventStart, eRepeatExceptions);
  }

  -- Every week day
  if (eRepeat = 'D2') {
    iInterval := 1;
    tmp := dayofweek (dt);
    if ((tmp > 1) and (tmp < 7))
      return CAL.WA.event_checkNotDeletedOccurence (dt, eEventStart, eRepeatExceptions);
  }

  -- Every N-th week on ...
  if (eRepeat = 'W1') {
    iInterval := 1;
    if (mod (datediff ('day', eEventStart, dtEnd) / 7, eRepeatParam1) = 0)
      if (bit_and (eRepeatParam2, power (2, CAL.WA.dt_WeekDay (dt, weekStarts)-1)))
        return CAL.WA.event_checkNotDeletedOccurence (dt, eEventStart, eRepeatExceptions);
  }

  -- Every N-th day of M-th month(s)
  if (eRepeat = 'M1') {
    iInterval := eRepeatParam1;
    if (mod (datediff ('month', eEventStart, dtEnd), eRepeatParam1) = 0)
      if (dayofmonth (dt) = eRepeatParam2)
        return CAL.WA.event_checkNotDeletedOccurence (dt, eEventStart, eRepeatExceptions);
  }

  -- Every X day/weekday/wekkend/... of Y-th month(s)
  if (eRepeat = 'M2') {
    iInterval := eRepeatParam1;
    if (mod (datediff ('month', eEventStart, dtEnd), eRepeatParam1) = 0)
      if (dayofmonth (dt) = CAL.WA.event_findDay (dt, eRepeatParam2, eRepeatParam3))
        return CAL.WA.event_checkNotDeletedOccurence (dt, eEventStart, eRepeatExceptions);
  }

  if (eRepeat = 'Y1') {
    iInterval := eRepeatParam1;
    if (mod (datediff ('year', eEventStart, dtEnd), eRepeatParam1) = 0)
      if ((month (dt) = eRepeatParam2) and (dayofmonth (dt) = eRepeatParam3))
        return CAL.WA.event_checkNotDeletedOccurence (dt, eEventStart, eRepeatExceptions);
  }

  -- Every X day/weekday/wekkend/... of Y-th month(s)
  if (eRepeat = 'Y2') {
    iInterval := 365;
    if (month (dt) = eRepeatParam3)
      if (dayofmonth (dt) = CAL.WA.event_findDay (dt, eRepeatParam1, eRepeatParam2))
        return CAL.WA.event_checkNotDeletedOccurence (dt, eEventStart, eRepeatExceptions);
  }

  return 0;
}
;

-------------------------------------------------------------------------------
--
create procedure CAL.WA.event_checkNotDeletedOccurence (
  in dt date,
  in eEventStart datetime,
  in eRepeatExceptions varchar)
{
  if (isnull (strstr (eRepeatExceptions, '<' || cast (datediff ('day', eEventStart, dt) as varchar) || '>')))
    return 1;
  return 0;
}
;

-------------------------------------------------------------------------------
--
create procedure CAL.WA.event_nextOccur (
  in dt date,
  in event integer,
  in eEventStart datetime,
  in eRepeat varchar,
  in eRepeatParam1 integer,
  in eRepeatParam2 integer,
  in eRepeatParam3 integer,
  in eRepeatUntil datetime,
  in eRepeatExceptions varchar,
  in weekStarts varchar := 'm')
{
  if (is_empty_or_null (eRepeat)) {
    if (dt > eEventStart)
      return null;
    return eEventStart;
  }

  if (not isnull (eRepeatUntil) and dt > eRepeatUntil)
    return null;

  if (dt < eEventStart)
    dt := eEventStart;

  declare dtEnd date;
  declare iInterval integer;

  iInterval := 1;
  dtEnd := dateadd('day', 397, dt);
  while (dt <= dtEnd) {
    if (CAL.WA.event_checkDate (dt,
                                event,
                                eEventStart,
                                eRepeat,
                                eRepeatParam1,
                                eRepeatParam2,
                                eRepeatParam3,
                                eRepeatUntil,
                                eRepeatExceptions,
                                weekStarts,
                                iInterval)) {
      return dateadd ('day', datediff('day', eEventStart, dt), eEventStart);
    }
    dt := dateadd ('day', iInterval, dt);
  }

  return null;
}
;

-------------------------------------------------------------------------------
--
create procedure CAL.WA.event_nextReminder (
  in dt date,
  in eEvent integer,
  in eEventStart datetime,
  in eRepeat varchar,
  in eRepeatParam1 integer,
  in eRepeatParam2 integer,
  in eRepeatParam3 integer,
  in eRepeatUntil datetime,
  in eRepeatExceptions varchar,
  in weekStarts varchar := 'm',
  in eReminder integer,
  in eReminderDate datetime)
{
  declare nextOccur datetime;

  if (eReminder = 0)
    return null;
  if (eEvent)
    eEventStart := CAL.WA.dt_dateClear (eEventStart);
  nextOccur := CAL.WA.event_nextOccur (dateadd ('second', eReminder, dt),
                                       eEvent,
                                       eEventStart,
                                       eRepeat,
                                       eRepeatParam1,
                                       eRepeatParam2,
                                       eRepeatParam3,
                                       eRepeatUntil,
                                       eRepeatExceptions,
                                       weekStarts);
  if (isnull (nextOccur))
    return null;
  if ((eReminderDate is not null) and (eReminderDate >= dateadd ('second', -eReminder, nextOccur)))
    return null;
  return dateadd ('second', -eReminder, nextOccur);
}
;

-------------------------------------------------------------------------------
--
create procedure CAL.WA.event_addReminder (
  in dt date,
  in eID integer,
  in eDomainID integer,
  in event integer,
  in eEventStart datetime,
  in eEventEnd datetime,
  in eRepeat varchar,
  in eRepeatParam1 integer,
  in eRepeatParam2 integer,
  in eRepeatParam3 integer,
  in eRepeatUntil datetime,
  in eRepeatExceptions varchar,
  in weekStarts varchar := 'm',
  in eReminder integer,
  in eReminderDate datetime)
{
  declare nextReminderDate datetime;

  nextReminderDate := CAL.WA.event_nextReminder (dt,
                                                 event,
                                                 eEventStart,
                                                 eRepeat,
                                                 eRepeatParam1,
                                                 eRepeatParam2,
                                                 eRepeatParam3,
                                                 eRepeatUntil,
                                                 eRepeatExceptions,
                                                 CAL.WA.settings_weekStarts2 (eDomainID),
                                                 eReminder,
                                                 eReminderDate);
  if (nextReminderDate is not null) {
    insert into CAL.WA.ALARMS (A_DOMAIN_ID, A_EVENT_ID, A_EVENT_OFFSET, A_ACTION, A_TRIGGER)
      values (eDomainID, eID, 0, 0, nextReminderDate);
  }
  update CAl.WA.EVENTS
     set E_REMINDER_DATE = nextReminderDate
   where E_ID = eID
     and E_DOMAIN_ID = eDomainID;

  return nextReminderDate;
}
;

-------------------------------------------------------------------------------
--
-- return the day of the month defined with E_REPEAT_PARAM1 and E_REPEAT_PARAM2, when E_REPAEAT is 'M2' or 'Y2'
--
--------------------------------------------------------------------------------
create procedure CAL.WA.event_findDay (
  in dt   date,
  in eRepeatParam1 integer,
  in eRepeatParam2 integer)
{
  declare N, pDay integer;

  pDay := dayofmonth (dt);
  -- last (day|weekday|weekend|m|t|w|t|f|s|s)
  if (eRepeatParam1 = 5) {
    dt := CAL.WA.dt_EndOfMonth (dt);
    while (not CAL.WA.event_testDayKind (dt, eRepeatParam2))
      dt := dateadd ('day', -1, dt);
    return dayofmonth (dt);
  }

  dt := CAL.WA.dt_BeginOfMonth (dt);
  -- first|second|third|fourth (m|t|w|t|f|s|s)
  if (1 <= eRepeatParam2 and eRepeatParam2 <= 7) {
    while (not CAL.WA.event_testDayKind (dt, eRepeatParam2))
      dt := dateadd ('day', 1, dt);
    return dayofmonth (dateadd ('day', 7*(eRepeatParam1-1), dt));
  }

  -- first|second|third|fourth  (m|t|w|t|f|s|s) (day|weekday|weekend)
  if (1 <= eRepeatParam1 and eRepeatParam1 <= 4) {
    N := eRepeatParam1;
    while (pDay >= dayofmonth (dt)) {
      if (CAL.WA.event_testDayKind (dt, eRepeatParam2)) {
        N := N - 1;
        if (N = 0)
          return dayofmonth (dt);
      }
      dt := dateadd ('day', 1, dt);
    }
  }

  return 0;
}
;


--------------------------------------------------------------------------------
--
-- check if day on pDate is of the kind specified with E_REPEAT_PARAM2
--
--------------------------------------------------------------------------------
create procedure CAL.WA.event_testDayKind (
  in pDate date,
  in eRepeatParam integer)
{
  if (eRepeatParam = 10) -- any day
    return 1;

  declare weekDay integer;

  weekDay := CAL.WA.dt_WeekDay (pDate);
  -- weekday
  if (eRepeatParam = 11)
    return either (gte (weekDay,6), 0, 1);

  -- weekend
  if (eRepeatParam = 12)
    return either (gte (weekDay,6), 1, 0);

  return equ (weekDay, eRepeatParam);
}
;

-------------------------------------------------------------------------------
--
create procedure CAL.WA.events_forPeriod (
  in domain_id integer,
  in pDateStart date,
  in pDateEnd date,
  in pTimezone integer,
  in pTaskMode varchar := 0,
  in pWeekStarts varchar := 'm')
{
  declare dt, dtStart, dtEnd, tzDT, tzEventStart, tzRepeatUntil date;
  declare dt_offset integer;

  declare c0, c1, c6, c7 integer;
  declare c2, c5 varchar;
  declare c3, c4 datetime;
  result_names (c0, c1, c2, c3, c4, c5, c6, c7);

  dtStart := CAL.WA.event_user2gmt (CAL.WA.dt_dateClear (pDateStart), pTimezone);
  dtEnd := CAL.WA.event_user2gmt (dateadd ('day', 1, CAL.WA.dt_dateClear (pDateEnd)), pTimezone);

  if (pTaskMode) {
    -- tasks
    for (select E_ID,
                E_EVENT,
                E_SUBJECT,
                E_EVENT_START,
                E_EVENT_END,
                E_REPEAT,
                E_REMINDER
           from CAL.WA.EVENTS
          where E_DOMAIN_ID = domain_id
            and E_KIND = 1
            and E_EVENT_START <  dtEnd
            and E_EVENT_END   >  dtStart) do
    {
      result (E_ID,
              E_EVENT,
              E_SUBJECT,
              CAL.WA.event_gmt2user (E_EVENT_START, pTimezone),
              CAL.WA.event_gmt2user (E_EVENT_END, pTimezone),
              E_REPEAT,
              null,
              E_REMINDER);
    }
  }

  -- regular events
  for (select E_ID,
              E_EVENT,
              E_SUBJECT,
              E_EVENT_START,
              E_EVENT_END,
              E_REPEAT,
              E_REMINDER
         from CAL.WA.EVENTS
        where E_DOMAIN_ID = domain_id
          and E_KIND = 0
          and (E_REPEAT = '' or E_REPEAT is null)
          and (
                (E_EVENT = 0 and E_EVENT_START >= dtStart and E_EVENT_START <  dtEnd) or
                (E_EVENT = 1 and E_EVENT_START <  dtEnd   and E_EVENT_END   >  dtStart)
              )) do
  {
    result (E_ID,
            E_EVENT,
            E_SUBJECT,
            CAL.WA.event_gmt2user (E_EVENT_START, pTimezone),
            CAL.WA.event_gmt2user (E_EVENT_END, pTimezone),
            E_REPEAT,
            null,
            E_REMINDER);
  }

  -- repetable events
  for (select E_ID,
              E_SUBJECT,
              E_EVENT,
              E_EVENT_START,
              E_EVENT_END,
              E_REPEAT,
              E_REPEAT_PARAM1,
              E_REPEAT_PARAM2,
              E_REPEAT_PARAM3,
              E_REPEAT_UNTIL,
              E_REPEAT_EXCEPTIONS,
              E_REMINDER
         from CAL.WA.EVENTS
        where E_DOMAIN_ID = domain_id
          and E_KIND = 0
          and E_REPEAT <> ''
          and E_EVENT_START < dtEnd
          and ((E_REPEAT_UNTIL is null) or (E_REPEAT_UNTIL >= dtStart))) do
  {
    tzEventStart := CAL.WA.event_gmt2user (E_EVENT_START, pTimezone);
    tzRepeatUntil := CAL.WA.event_gmt2user (E_REPEAT_UNTIL, pTimezone);
    dt := dtStart;
    while (dt < dtEnd) {
      tzDT := CAL.WA.event_gmt2user (dt, pTimezone);
      if (CAL.WA.event_occurAtDate (tzDT,
                                    E_EVENT,
                                    tzEventStart,
                                    E_REPEAT,
                                    E_REPEAT_PARAM1,
                                    E_REPEAT_PARAM2,
                                    E_REPEAT_PARAM3,
                                    tzRepeatUntil,
                                    E_REPEAT_EXCEPTIONS,
                                    pWeekStarts)) {
        if (E_EVENT = 1) {
          dt_offset := datediff ('day', dateadd ('hour', -12, E_EVENT_START), dt);
        } else {
          dt_offset := datediff ('day', E_EVENT_START, dateadd ('second', 86399, dt));
        }
        result (E_ID,
                E_EVENT,
                E_SUBJECT,
                CAL.WA.event_gmt2user (dateadd ('day', dt_offset, E_EVENT_START), pTimezone),
                CAL.WA.event_gmt2user (dateadd ('day', dt_offset, E_EVENT_END), pTimezone),
                E_REPEAT,
                dt_offset,
                E_REMINDER);
      }
      dt := dateadd ('day', 1, dt);
    }
  }
}
;

-----------------------------------------------------------------------------------------
--
-- Tasks
--
-----------------------------------------------------------------------------------------
create procedure CAL.WA.task_update (
  in id integer,
  in domain_id integer,
  in subject varchar,
  in description varchar,
  in tags varchar,
  in eEventStart datetime,
  in eEventEnd datetime,
  in priority integer,
  in status varchar,
  in complete integer,
  in notes varchar := '')
{
  if (id = -1) {
    id := sequence_next ('CAL.WA.event_id');
    insert into CAL.WA.EVENTS
      (
        E_ID,
        E_DOMAIN_ID,
        E_KIND,
        E_SUBJECT,
        E_DESCRIPTION,
        E_TAGS,
        E_EVENT_START,
        E_EVENT_END,
        E_PRIORITY,
        E_STATUS,
        E_COMPLETE,
        E_NOTES,
        E_CREATED,
        E_UPDATED
      )
      values
      (
        id,
        domain_id,
        1,
        subject,
        description,
        tags,
        eEventStart,
        eEventEnd,
        priority,
        status,
        complete,
        notes,
        now (),
        now ()
      );
  } else {
    update CAL.WA.EVENTS
       set E_SUBJECT = subject,
           E_DESCRIPTION = description,
           E_TAGS = tags,
           E_EVENT_START = eEventStart,
           E_EVENT_END = eEventEnd,
           E_PRIORITY = priority,
           E_STATUS = status,
           E_COMPLETE = complete,
           E_NOTES = notes,
           E_UPDATED = now ()
     where E_ID = id and
           E_DOMAIN_ID = domain_id;
  }
  return id;
}
;

-----------------------------------------------------------------------------------------
--
-- Notes
--
-----------------------------------------------------------------------------------------
create procedure CAL.WA.note_update (
  in id integer,
  in domain_id integer,
  in subject varchar,
  in description varchar,
  in tags varchar)
{
  if (id = -1) {
    id := sequence_next ('CAL.WA.event_id');
    insert into CAL.WA.EVENTS
      (
        E_ID,
        E_DOMAIN_ID,
        E_KIND,
        E_SUBJECT,
        E_DESCRIPTION,
        E_TAGS,
        E_CREATED,
        E_UPDATED
      )
      values
      (
        id,
        domain_id,
        2,
        subject,
        description,
        tags,
        now (),
        now ()
      );
  } else {
    update CAL.WA.EVENTS
       set E_SUBJECT = subject,
           E_DESCRIPTION = description,
           E_TAGS = tags,
           E_UPDATED = now ()
     where E_ID = id and
           E_DOMAIN_ID = domain_id;
  }
  return id;
}
;

-------------------------------------------------------------------------------
--
-- Searches
--
-------------------------------------------------------------------------------
create procedure CAL.WA.search_sql (
  inout domain_id integer,
  inout account_id integer,
  inout data varchar)
{
  declare S, tmp, where2, delimiter2 varchar;

  where2 := ' \n ';
  delimiter2 := '\n and ';

  S := ' select          \n' ||
       ' E_ID,           \n' ||
       ' E_DOMAIN_ID,    \n' ||
       ' E_KIND,         \n' ||
       ' E_SUBJECT,      \n' ||
       ' E_EVENT,        \n' ||
       ' E_EVENT_START,  \n' ||
       ' E_EVENT_END,    \n' ||
       ' E_REPEAT,       \n' ||
       ' E_REMINDER,     \n' ||
       ' E_CREATED,      \n' ||
       ' E_UPDATED       \n' ||
       ' from            \n' ||
       '   CAL.WA.EVENTS \n' ||
       ' where E_DOMAIN_ID = <DOMAIN_ID> <TEXT> <TAGS> <WHERE> \n';

  tmp := CAL.WA.xml_get ('keywords', data);
  if (not is_empty_or_null (tmp)) {
    S := replace (S, '<TEXT>', sprintf('and contains (E_SUBJECT, \'[__lang "x-ViDoc"] %s\') \n', FTI_MAKE_SEARCH_STRING (tmp)));
  } else {
    tmp := CAL.WA.xml_get ('expression', data);
    if (not is_empty_or_null(tmp))
      S := replace (S, '<TEXT>', sprintf('and contains (E_SUBJECT, \'[__lang "x-ViDoc"] %s\') \n', tmp));
  }

  tmp := CAL.WA.xml_get ('tags', data);
  if (not is_empty_or_null (tmp)) {
    tmp := CAL.WA.tags2search (tmp);
    S := replace (S, '<TAGS>', sprintf ('and contains (E_SUBJECT, \'[__lang "x-ViDoc"] %s\') \n', tmp));
  }

  S := replace (S, '<DOMAIN_ID>', cast (domain_id as varchar));
  S := replace (S, '<ACCOUNT_ID>', cast (account_id as varchar));
  S := replace (S, '<TAGS>', '');
  S := replace (S, '<TEXT>', '');
  S := replace (S, '<WHERE>', where2);

  --dbg_obj_print(S);
  return S;
}
;

-------------------------------------------------------------------------------
--
create procedure CAL.WA.vcal_str2date (
  in xmlItem any,
  in xmlPath varchar,
  in tzDict any)
{
  declare S, dt, tzID, tzOffset any;

  S := cast (xquery_eval (xmlPath || 'val', xmlItem, 1) as varchar);
  dt := CAL.WA.vcal_iso2date (S);
  if (not isnull (dt)) {
    if (chr (S[length(S)-1]) <> 'Z') {
      tzID := cast (xquery_eval (xmlPath || 'TZID', xmlItem, 1) as varchar);
      if (not isnull (tzID)) {
        tzOffset := dict_get (tzDict, tzID, 0);
        dt := dateadd ('minute', tzOffset, dt);
      }
    }
  }
  return dt;
}
;

-------------------------------------------------------------------------------
--
create procedure CAL.WA.vcal_str2status (
  in xmlItem any,
  in xmlPath varchar)
{
  declare N integer;
  declare S, V any;

  V := vector ('Not Started', 'In Progress', 'Completed', 'Waiting', 'Deferred');
  S := cast (xquery_eval (xmlPath, xmlItem, 1) as varchar);
  for (N := 0; N < length (V); N := N + 1)
    if (lcase (S) = lcase (V[N]))
      return V[N];

  return S;
}
;

-----------------------------------------------------------------------------------------
--
create procedure CAL.WA.vcal_iso2date (
  in S varchar)
{
  declare hours, minutes, seconds integer;
  declare dt datetime;
  declare V any;

  V := regexp_parse ('^([0-9][0-9][0-9][0-9])(0[1-9]|1[012])(0[1-9]|[12][0-9]|3[01])T?([01][0-9]|[2][0-3])?([0-5][0-9])?([0-5][0-9])?(Z)?\$', S, 0);
  if (length (V) < 8)
    return null;
  dt := CAL.WA.dt_dateEncode (atoi (subseq (S, V[2], V[3])),
                           atoi (subseq (S, V[ 4], V[ 5])),
                              atoi (subseq (S, V[6], V[7])));
  hours := 0;
  if ((length (V) >= 10) and (V[8] <> -1) and (V[9] <> -1))
    hours := atoi (subseq (S, V[8], V[9]));
  minutes := 0;
  if ((length (V) >= 12) and (V[10] <> -1) and (V[11] <> -1))
    minutes := atoi (subseq (S, V[10], V[11]));
  seconds := 0;
  if ((length (V) >= 14) and (V[12] <> -1) and (V[13] <> -1))
    seconds := atoi (subseq (S, V[12], V[13]));

  return CAL.WA.dt_join (dt, CAL.WA.dt_timeEncode (hours, minutes, seconds));
}
;

-----------------------------------------------------------------------------------------
--
create procedure CAL.WA.vcal_date2str (
  in dt datetime)
{
  return CAL.WA.dt_format (dt, 'YMDTHNS');
}
;

-----------------------------------------------------------------------------------------
--
create procedure CAL.WA.vcal_date2utc (
  in dt datetime)
{
  return CAL.WA.dt_format (dateadd ('minute', -timezone (now ()), dt), 'YMDTHNSZ');
}
;

-------------------------------------------------------------------------------
--
create procedure CAL.WA.vcal_str2recurrence (
  in xmlItem any,
  in xmlPath varchar,
  inout eRepeat varchar,
  inout eRepeatParam1 integer,
  inout eRepeatParam2 integer,
  inout eRepeatParam3 integer,
  inout eRepeatUntil datetime)
{
  declare N integer;
  declare S, T varchar;
  declare V, ruleParams any;

  eRepeat := '';
  eRepeatParam1 := null;
  eRepeatParam2 := null;
  eRepeatParam3 := null;
  eRepeatUntil := null;

  V := vector ();
  ruleParams := xquery_eval (xmlPath, xmlItem, 0);
  foreach (any ruleParam in ruleParams) do  {
    S := cast (xpath_eval ('.', ruleParam) as varchar);
    V := vector_concat (V, split_and_decode (S, 1, '\0\0;='));
  }

  if (length (V) = 0)
    return;

  -- dayly rule
  if (get_keyword ('FREQ', V) = 'DAYLY') {
    eRepeat := 'D1';
    eRepeatParam1 := cast (get_keyword ('INTERVAL', V, '1') as integer);
  }

  if (get_keyword ('FREQ', V) = 'WEEKLY') {
    eRepeat := 'W1';
    eRepeatParam1 := cast (get_keyword ('INTERVAL', V, '1') as integer);
    eRepeatParam2 := 0;
    T := get_keyword ('BYDAY', V);
    if (not isnull (T)) {
      T := split_and_decode (T, 0, '\0\0,');
      for (N := 0; N < length (T); N := N + 1) {
        if        (T[N] = 'MO') {
          eRepeatParam2 := bit_or (eRepeatParam2, power (2, 0));
        } else if (T[N] = 'TU') {
          eRepeatParam2 := bit_or (eRepeatParam2, power (2, 1));
        } else if (T[N] = 'WE') {
          eRepeatParam2 := bit_or (eRepeatParam2, power (2, 2));
        } else if (T[N] = 'TH') {
          eRepeatParam2 := bit_or (eRepeatParam2, power (2, 3));
        } else if (T[N] = 'FR') {
          eRepeatParam2 := bit_or (eRepeatParam2, power (2, 4));
        } else if (T[N] = 'SA') {
          eRepeatParam2 := bit_or (eRepeatParam2, power (2, 5));
        } else if (T[N] = 'SU') {
          eRepeatParam2 := bit_or (eRepeatParam2, power (2, 6));
          }
        }
      }
  }

  if (get_keyword ('FREQ', V) = 'MONTHLY') {
    eRepeat := 'M1';
    eRepeatParam1 := cast (get_keyword ('INTERVAL', V, '1') as integer);
    eRepeatParam2 := cast (get_keyword ('BYMONTHDAY', V, '1') as integer);
  }
  if (get_keyword ('FREQ', V) = 'YEARLY') {
    eRepeat := 'Y1';
    eRepeatParam1 := cast (get_keyword ('INTERVAL', V, '1') as integer);
    eRepeatParam2 := cast (get_keyword ('BYMONTH', V, '1') as integer);
    eRepeatParam3 := cast (get_keyword ('BYMONTHDAY', V, '1') as integer);
  }

  eRepeatUntil := CAL.WA.vcal_iso2date (get_keyword ('UNTIL', V));
}
;

-------------------------------------------------------------------------------
--
create procedure CAL.WA.vcal_recurrence2str (
  inout eRepeat varchar,
  inout eRepeatParam1 integer,
  inout eRepeatParam2 integer,
  inout eRepeatParam3 integer,
  inout eRepeatUntil datetime)
{
  declare S varchar;

  if (is_empty_or_null (eRepeat))
    return null;

  S := null;
  -- dayly rule
  if (eRepeat = 'D1') {
    S := 'FREQ=DAYLY';
    S := S || ';INTERVAL=' || cast (eRepeatParam1 as varchar);
    if (not isnull (eRepeatUntil))
      S := S || ';UNTIL=' || CAL.WA.vcal_date2utc (eRepeatUntil);
  }

  if (eRepeat = 'D2') {
    S := 'FREQ=DAYLY';
    S := S || ';INTERVAL=1';
    S := S || ';BYDAY=MO,TU,WE,TH,FR';
    if (not isnull (eRepeatUntil))
      S := S || ';UNTIL=' || CAL.WA.vcal_date2utc (eRepeatUntil);
  }

  if (eRepeat = 'W1') {
    S := 'FREQ=WEEKLY';
    S := S || ';INTERVAL=' || cast (eRepeatParam1 as varchar);
    if (eRepeatParam2 <> 0) {
      S := S || ';BYDAY=';
      if (bit_and (eRepeatParam2, power (2, 0)))
        S := S || 'MO,';
      if (bit_and (eRepeatParam2, power (2, 1)))
        S := S || 'TU,';
      if (bit_and (eRepeatParam2, power (2, 2)))
        S := S || 'WE,';
      if (bit_and (eRepeatParam2, power (2, 3)))
        S := S || 'TH,';
      if (bit_and (eRepeatParam2, power (2, 4)))
        S := S || 'FR,';
      if (bit_and (eRepeatParam2, power (2, 5)))
        S := S || 'SA,';
      if (bit_and (eRepeatParam2, power (2, 6)))
        S := S || 'SU,';
      S := trim (S, ',');
    }
    if (not isnull (eRepeatUntil))
      S := S || ';UNTIL=' || CAL.WA.vcal_date2utc (eRepeatUntil);
  }

  if (eRepeat = 'M1') {
    S := 'FREQ=MONTHLY';
    S := S || ';INTERVAL=' || cast (eRepeatParam1 as varchar);
    S := S || ';BYMONTHDAY=' || cast (eRepeatParam2 as varchar);
    if (not isnull (eRepeatUntil))
      S := S || ';UNTIL=' || CAL.WA.vcal_date2utc (eRepeatUntil);
  }

  if (eRepeat = 'M2') {
    S := 'FREQ=MONTHLY';
    S := S || ';INTERVAL=' || cast (eRepeatParam1 as varchar);
    if (eRepeatParam3 = 10)
      S := S || ';BYMONTHDAY=' || cast (eRepeatParam2 as varchar);
    if (not isnull (eRepeatUntil))
      S := S || ';UNTIL=' || CAL.WA.vcal_date2utc (eRepeatUntil);
  }

  if (eRepeat = 'Y1') {
    S := 'FREQ=YEARLY';
    S := S || ';INTERVAL=' || cast (eRepeatParam1 as varchar);
    S := S || ';BYMONTH=' || cast (eRepeatParam2 as varchar);
    S := S || ';BYMONTHDAY=' || cast (eRepeatParam3 as varchar);
    if (not isnull (eRepeatUntil))
      S := S || ';UNTIL=' || CAL.WA.vcal_date2utc (eRepeatUntil);
  }

  if (eRepeat = 'Y2') {
    S := 'FREQ=YEARLY';
    S := S || ';INTERVAL=1';
    S := S || ';BYMONTH=' || cast (eRepeatParam3 as varchar);
    if (eRepeatParam1 = 10)
      S := S || ';BYMONTHDAY=' || cast (eRepeatParam2 as varchar);
    if (not isnull (eRepeatUntil))
      S := S || ';UNTIL=' || CAL.WA.vcal_date2utc (eRepeatUntil);
  }

  return S;
}
;

-------------------------------------------------------------------------------
--
create procedure CAL.WA.vcal_str2reminder (
  in S any,
  in eEventStart datetime,
  inout eReminder integer)
{
  declare V any;

  eReminder := null;
  if (isnull (S))
    return;
  if (isnull (eEventStart))
    return;

  V := split_and_decode (S, 0, '\0\0;');
  if (length (V) = 0)
    return;

  eReminder := datediff ('minute', CAL.WA.vcal_str2date (V[0]), eEventStart);
  return;
}
;

-------------------------------------------------------------------------------
--
create procedure CAL.WA.vcal_reminder2str (
  inout eEventStart datetime,
  inout eReminder integer)
{
  declare V any;

  eReminder := null;
  if (isnull (eReminder))
    return null;
  if (isnull (eEventStart))
    return null;

  return CAL.WA.vcal_date2str (datediff ('minute', eReminder, eEventStart));
}
;

-------------------------------------------------------------------------------
--
create procedure CAL.WA.import_vcal (
  in domain_id integer,
  in content any,
  in tags any)
{
  declare N, nLength integer;
  declare tmp, xmlData, xmlItems, itemName, V any;
  declare id,
          subject,
          description,
          location,
          eventTags,
          event,
          eEventStart,
          eEventEnd,
          eRepeat,
          eRepeatParam1,
          eRepeatParam2,
          eRepeatParam3,
          eRepeatUntil,
          eReminder,
          priority,
          status,
          complete any;
  declare vcalVersion any;
  declare tzDict, tzID, tzOffset any;

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
    if (itemName = 'IMC-VCALENDAR') {
      -- vCalendar version
      vcalVersion := cast (xquery_eval ('VERSION/val', xmlItem, 1) as varchar);

      -- timezone
      tzDict := dict_new();
      nLength := xpath_eval('count (IMC-VTIMEZONE)', xmlItem);
      for (N := 1; N <= nLength; N := N + 1) {
        tzID := cast (xquery_eval (sprintf ('IMC-VTIMEZONE[%d]/TZID/val', N), xmlItem, 1) as varchar);
        if (not isnull (tzID)) {
          tmp := cast (xquery_eval (sprintf ('IMC-VTIMEZONE[%d]/IMC-STANDARD/TZOFFSETTO/val', N), xmlItem, 1) as varchar);
          CAL.WA.tz_decode (tmp, tzOffset);
          if (not isnull (tzOffset))
            dict_put (tzDict, tzID, tzOffset);
        }
      }

      -- events
      nLength := xpath_eval('count (IMC-VEVENT)', xmlItem);
      for (N := 1; N <= nLength; N := N + 1) {
        id := -1;
        subject := cast (xquery_eval (sprintf ('IMC-VEVENT[%d]/SUMMARY/val', N), xmlItem, 1) as varchar);
        description := cast (xquery_eval (sprintf ('IMC-VEVENT[%d]/DESCRIPTION/val', N), xmlItem, 1) as varchar);
        location := cast (xquery_eval (sprintf ('IMC-VEVENT[%d]/LOCATION/val', N), xmlItem, 1) as varchar);
        eventTags := CAL.WA.tags_join (replace (cast (xquery_eval (sprintf ('IMC-VEVENT[%d]/CATEGORIES/val', N), xmlItem, 1) as varchar), ';', ','), tags);
        eEventStart := CAL.WA.vcal_str2date (xmlItem, sprintf ('IMC-VEVENT[%d]/DTSTART/', N), tzDict);
        eEventEnd := CAL.WA.vcal_str2date (xmlItem, sprintf ('IMC-VEVENT[%d]/DTEND/', N), tzDict);
        if (isnull (eEventEnd)) {
          tmp := cast (xquery_eval (sprintf ('IMC-VEVENT[%d]/DURATION/val', N), xmlItem, 1) as varchar);
          eEventEnd := CAL.WA.p_dateadd (eEventStart, tmp);
        }
        event := case when (isnull (eEventEnd)) then 1 else 0 end;
        CAL.WA.vcal_str2recurrence (xmlItem, sprintf ('IMC-VEVENT[%d]/RRULE/fld', N), eRepeat, eRepeatParam1, eRepeatParam2, eRepeatParam3, eRepeatUntil);
        tmp := cast (xquery_eval (sprintf ('IMC-VEVENT[%d]/DALARM/val', N), xmlItem, 1) as varchar);
        CAL.WA.vcal_str2reminder (tmp, eEventStart, eReminder);
        CAL.WA.event_update
          (
            id,
            domain_id,
            subject,
            description,
            location,
            tags,
            event,
            eEventStart,
            eEventEnd,
            eRepeat,
            eRepeatParam1,
            eRepeatParam2,
            eRepeatParam3,
            eRepeatUntil,
            eReminder
          );
      }

      -- tasks (todo)
      nLength := xpath_eval('count (IMC-VTODO)', xmlItem);
      for (N := 1; N <= nLength; N := N + 1) {
        id := -1;
        subject := cast (xquery_eval (sprintf ('IMC-VTODO[%d]/SUMMARY/val', N), xmlItem, 1) as varchar);
        description := cast (xquery_eval (sprintf ('IMC-VTODO[%d]/DESCRIPTION/val', N), xmlItem, 1) as varchar);
        eventTags := CAL.WA.tags_join (replace (cast (xquery_eval (sprintf ('IMC-VTODO[%d]/CATEGORIES/val', N), xmlItem, 1) as varchar), ';', ','), tags);
        eEventStart := CAL.WA.vcal_str2date (xmlItem, sprintf ('IMC-VTODO[%d]/DTSTART/', N), tzDict);
        eEventEnd := CAL.WA.vcal_str2date (xmlItem, sprintf ('IMC-VTODO[%d]/DUE/', N), tzDict);
        priority := cast (xquery_eval (sprintf ('IMC-VTODO[%d]/PRIORITY/val', N), xmlItem, 1) as varchar);
        if (isnull (priority))
          priority := '3';
        status := CAL.WA.vcal_str2complete (xmlItem, sprintf ('IMC-VTODO[%d]/STATUS/val', N));
        complete := cast (xquery_eval (sprintf ('IMC-VTODO[%d]/COMPLETE/val', N), xmlItem, 1) as varchar);
        CAL.WA.task_update
          (
            id,
            domain_id,
            subject,
            description,
            tags,
            eEventStart,
            eEventEnd,
            priority,
            status,
            complete
          );
      }
    }
  }
}
;

----------------------------------------------------------------------
--
create procedure CAL.WA.export_vcal_line (
  in property varchar,
  in value any,
  inout sStream any)
{
  if (isnull (value))
    return;
  http (sprintf ('%s:%s\r\n', property, cast (value as varchar)), sStream);
}
;
----------------------------------------------------------------------
--
create procedure CAL.WA.export_vcal (
  in domain_id integer,
  in tz integer)
{
  declare S, url, tzID, tzName varchar;
  declare sStream any;

  url := sprintf ('http://%s%s/%U/calendar/%U/', SIOC.DBA.get_cname(), SIOC.DBA.get_base_path (), CAL.WA.domain_owner_name (domain_id), CAL.WA.domain_name (domain_id));
  tzID := sprintf ('GMT%s%04d', case when cast (tz as integer) < 0 then '-' else '+' end,  tz);
  tzName := sprintf ('GMT %s%02d:00', case when cast (tz as integer) < 0 then '-' else '+' end,  abs(floor (tz / 60)));

  sStream := string_output();

  -- start
  http ('BEGIN:VCALENDAR\r\n', sStream);
  http ('VERSION:2.0\r\n', sStream);
  http ('BEGIN:VTIMEZONE\r\n', sStream);
  http (sprintf ('TZID:%s\r\n', tzID), sStream);
  http ('BEGIN:STANDARD\r\n', sStream);
  http (sprintf ('TZOFFSETTO:%s\r\n', CAL.WA.tz_string (tz)), sStream);
  http (sprintf ('TZNAME:%s\r\n', tzName), sStream);
  http ('END:STANDARD\r\n', sStream);
  http ('END:VTIMEZONE\r\n', sStream);

  -- events
  for (select * from CAL.WA.EVENTS where E_DOMAIN_ID = domain_id and E_KIND = 0) do {
	  http ('BEGIN:VEVENT\r\n', sStream);
    CAL.WA.export_vcal_line ('URL', url || cast (E_ID as varchar), sStream);
    CAL.WA.export_vcal_line ('DTSTAMP', CAL.WA.vcal_date2utc (now ()), sStream);
    CAL.WA.export_vcal_line ('CREATED', CAL.WA.vcal_date2utc (E_CREATED), sStream);
    CAL.WA.export_vcal_line ('LAST-MODIFIED', CAL.WA.vcal_date2utc (E_UPDATED), sStream);
    CAL.WA.export_vcal_line ('SUMMARY', E_SUBJECT, sStream);
    CAL.WA.export_vcal_line ('DESCRIPTION', E_DESCRIPTION, sStream);
    CAL.WA.export_vcal_line ('LOCATION', E_LOCATION, sStream);
    CAL.WA.export_vcal_line ('CATEGORIES', replace (E_TAGS, ',', ';'), sStream);
    CAL.WA.export_vcal_line (sprintf ('DTSTART;TZID=%s', tzID), CAL.WA.vcal_date2str (CAL.WA.event_gmt2user (E_EVENT_START, tz)), sStream);
    CAL.WA.export_vcal_line (sprintf ('DTEND;TZID=%s', tzID), CAL.WA.vcal_date2str (CAL.WA.event_gmt2user (E_EVENT_END, tz)), sStream);
    CAL.WA.export_vcal_line ('RRULE', CAL.WA.vcal_recurrence2str (E_REPEAT, E_REPEAT_PARAM1, E_REPEAT_PARAM2, E_REPEAT_PARAM3, E_REPEAT_UNTIL), sStream);
    --CAL.WA.export_vcal_line ('DALARM', CAL.WA.vcal_reminder2str (E_REMINDER), sStream);
	  http ('END:VEVENT\r\n', sStream);
	}

  -- tasks
  for (select * from CAL.WA.EVENTS where E_DOMAIN_ID = domain_id and E_KIND = 1) do {
	  http ('BEGIN:VTODO\r\n', sStream);
    CAL.WA.export_vcal_line ('URL', url || cast (E_ID as varchar), sStream);
    CAL.WA.export_vcal_line ('DTSTAMP', CAL.WA.vcal_date2utc (now ()), sStream);
    CAL.WA.export_vcal_line ('CREATED', CAL.WA.vcal_date2utc (E_CREATED), sStream);
    CAL.WA.export_vcal_line ('LAST-MODIFIED', CAL.WA.vcal_date2utc (E_UPDATED), sStream);
    CAL.WA.export_vcal_line ('SUMMARY', E_SUBJECT, sStream);
    CAL.WA.export_vcal_line ('DESCRIPTION', E_DESCRIPTION, sStream);
    CAL.WA.export_vcal_line ('CATEGORIES', replace (E_TAGS, ',', ';'), sStream);
    CAL.WA.export_vcal_line (sprintf ('DTSTART;TZID=%s', tzID), CAL.WA.vcal_date2str (CAL.WA.event_gmt2user (E_EVENT_START, tz)), sStream);
    CAL.WA.export_vcal_line (sprintf ('DTEND;TZID=%s', tzID), CAL.WA.vcal_date2str (CAL.WA.event_gmt2user (E_EVENT_END, tz)), sStream);
    CAL.WA.export_vcal_line ('PRIORITY', E_PRIORITY, sStream);
    CAL.WA.export_vcal_line ('STATUS', E_STATUS, sStream);
	  http ('END:VTODO\r\n', sStream);
	}

  -- end
  http ('END:VCALENDAR\r\n', sStream);

  return string_output_string(sStream);
}
;

--------------------------------------------------------------------------------
--
create procedure CAL.WA.alarm_scheduler ()
{
  declare dt, nextReminderDate date;
  declare eID, eDomainID, eEvent, eEventStart, eEventEnd, eRepeat, eRepeatParam1, eRepeatParam2, eRepeatParam3, eRepeatUntil, eRepeatExceptions, eReminder, eReminderDate any;

  dt := curdate ();
  declare cr cursor for select E_ID,
                               E_DOMAIN_ID,
                               E_EVENT,
                               E_EVENT_START,
                               E_EVENT_END,
                               E_REPEAT,
                               E_REPEAT_PARAM1,
                               E_REPEAT_PARAM2,
                               E_REPEAT_PARAM3,
                               E_REPEAT_UNTIL,
                               E_REPEAT_EXCEPTIONS,
                               E_REMINDER,
                               E_REMINDER_DATE
                          from CAL.WA.EVENTS
                         where E_KIND = 0
                           and E_REMINDER <> 0
                           and E_REMINDER_DATE <= dt;

  whenever not found goto _done;
  open cr;
  while (1) {
    fetch cr into eID, eDomainID, eEvent, eEventStart, eEventEnd, eRepeat, eRepeatParam1, eRepeatParam2, eRepeatParam3, eRepeatUntil, eRepeatExceptions, eReminder, eReminderDate;

    nextReminderDate := CAL.WA.event_addReminder (CAL.WA.event_user2gmt (dt, CAL.WA.settings_timeZone2 (eDomainID)),
                                                  eID,
                                                  eDomainID,
                                                  eEvent,
                                                 eEventStart,
                                                 eEventEnd,
                                                  eEventEnd,
                                                 eRepeat,
                                                 eRepeatParam1,
                                                 eRepeatParam2,
                                                 eRepeatParam3,
                                                 eRepeatUntil,
                                                 eRepeatExceptions,
                                                  CAL.WA.settings_weekStarts2 (eDomainID),
                                                 eReminder,
                                                 eReminderDate);
  }
_done:;
  close cr;
}
;

-----------------------------------------------------------------------------------------
--
create procedure CAL.WA.version_update ()
{
  for (select WAI_ID, WAM_USER
         from DB.DBA.WA_MEMBER
                join DB.DBA.WA_INSTANCE on WAI_NAME = WAM_INST
        where WAI_TYPE_NAME = 'Calendar'
          and WAM_MEMBER_TYPE = 1) do {
    CAL.WA.domain_update (WAI_ID, WAM_USER);
  }
}
;

-----------------------------------------------------------------------------------------
--
CAL.WA.version_update ()
;

-----------------------------------------------------------------------------------------
--
create procedure CAL.WA.version_update2 ()
{
  declare cTimezone integer;

  if (registry_get ('cal_tasks_version') = '1')
    return;

  for (select E_ID          _id,
              E_DOMAIN_ID   _domain_id,
              E_EVENT_START _start,
              E_EVENT_END   _end
         from CAL.WA.EVENTS
        where E_KIND = 1) do
  {
    cTimezone := CAL.WA.settings_timeZone2 (_domain_id);
    if (not isnull (_start)) {
      _start := CAL.WA.event_gmt2user (_start, cTimezone);
      _start := CAL.WA.dt_join (_start, CAL.WA.dt_timeEncode (12, 0));
    }
    if (not isnull (_end)) {
      _end := CAL.WA.event_gmt2user (_end, cTimezone);
      _end := CAL.WA.dt_join (_end, CAL.WA.dt_timeEncode (12, 0));
    }
    update CAL.WA.EVENTS
       set E_EVENT_START = CAL.WA.event_user2gmt (_start, cTimezone),
           E_EVENT_END = CAL.WA.event_user2gmt (_end, cTimezone)
     where E_ID = _id;
  }
  registry_set ('cal_tasks_version', '1');
}
;

-----------------------------------------------------------------------------------------
--
CAL.WA.version_update2 ()
;
