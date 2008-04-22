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
create procedure CAL.WA.session_domain (
  inout params any)
{
  declare aPath, domain_id, options any;

  declare exit handler for sqlstate '*'
  {
    domain_id := -1;
    goto _end;
  };

  options := http_map_get('options');
  if (not is_empty_or_null(options))
    domain_id := get_keyword ('domain', options);
  if (is_empty_or_null (domain_id)) {
    aPath := split_and_decode (trim (http_path (), '/'), 0, '\0\0/');
    domain_id := cast(aPath[1] as integer);
  }
  if (not exists (select 1 from DB.DBA.WA_INSTANCE where WAI_ID = domain_id))
    domain_id := -1;

_end:;
  return cast (domain_id as integer);
}
;

create procedure CAL.WA.session_restore (
  inout params any)
{
  declare domain_id, user_id, user_name, user_role, sid, realm any;

  sid := get_keyword ('sid', params, '');
  realm := get_keyword ('realm', params, '');

  domain_id := CAL.WA.session_domain (params);

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
    if (domain_id = -1)
    {
      user_role := 'expire';
      user_name := 'Expire User';
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
create procedure CAL.WA.check_grants (
  in domain_id integer,
  in user_id integer,
  in role_name varchar)
{
  whenever not found goto _end;

  if (CAL.WA.check_admin(user_id))
    return 1;
  if (role_name is null or role_name = '')
    return 0;
  if (role_name = 'admin')
    return 0;
  if (role_name = 'guest')
  {
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
  {
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
  }
_end:
  return 0;
}
;

-------------------------------------------------------------------------------
--
create procedure CAL.WA.check_grants2(in role_name varchar, in page_name varchar)
{
  if (role_name = 'expire')
    return 0;
  return 1;
}
;

-------------------------------------------------------------------------------
--
create procedure CAL.WA.access_role(in domain_id integer, in user_id integer)
{
  if (CAL.WA.check_admin (user_id))
    return 'admin';

  for (select B.WAM_MEMBER_TYPE
               from SYS_USERS A,
                    WA_MEMBER B,
                    WA_INSTANCE C
              where A.U_ID = user_id
                and B.WAM_USER = A.U_ID
                and B.WAM_INST = C.WAI_NAME
          and C.WAI_ID = domain_id) do
  {
    if (WAM_MEMBER_TYPE = 1)
    return 'owner';
    if (WAM_MEMBER_TYPE = 2)
    return 'author';
    return 'reader';
  }
  if (exists (select 1 from SYS_USERS A where A.U_ID = user_id))
    return 'guest';

  return 'public';
}
;

-------------------------------------------------------------------------------
--
create procedure CAL.WA.access_is_write (in access_role varchar)
{
  if (is_empty_or_null (access_role))
    return 0;
  if (access_role = 'guest')
    return 0;
  if (access_role = 'public')
    return 0;
  return 1;
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
create procedure CAL.WA.url_fix (
  in S varchar,
  in sid varchar := null,
  in realm varchar := null)
{
  declare T varchar;

  T := '&';
  if (isnull (strchr (S, '?')))
  {
    T := '?';
  }
  if (not is_empty_or_null (sid))
  {
    S := S || T || 'sid=' || sid;
    T := '&';
  }
  if (not is_empty_or_null (realm))
  {
    S := S || T || 'realm=' || realm;
  }
  return S;
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
  if (CAL.WA.settings_atomVersion (CAL.WA.settings (domain_id)) = '1.0')
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

-----------------------------------------------------------------------------
--
create procedure CAL.WA.export_comment_sqlx(
  in domain_id integer,
  in account_id integer)
{
  declare retValue any;

  retValue := string_output ();

  http ('<?xml version =\'1.0\' encoding=\'UTF-8\'?>\n', retValue);
  http ('<rss version="2.0" xmlns:sql=\'urn:schemas-openlink-com:xml-sql\'>\n', retValue);
  http ('<channel xmlns:wfw="http://wellformedweb.org/CommentAPI/" xmlns:dc="http://purl.org/dc/elements/1.1/">\n', retValue);

  http ('<sql:header><sql:param name=":id"> </sql:param></sql:header>\n', retValue);
  http ('<sql:sqlx><![CDATA[\n', retValue);
  http ('  select \n', retValue);
  http ('    XMLELEMENT (\'title\', CAL.WA.utf2wide (E_SUBJECT)), \n', retValue);
  http ('    XMLELEMENT (\'description\', CAL.WA.utf2wide (CAL.WA.xml2string(E_DESCRIPTION))), \n', retValue);
  http ('    XMLELEMENT (\'link\', CAL.WA.event_url (<DOMAIN_ID>, E_ID)), \n', retValue);
  http ('    XMLELEMENT (\'pubDate\', CAL.WA.dt_rfc1123 (E_CREATED)), \n', retValue);
  http ('    XMLELEMENT (\'generator\', \'Virtuoso Universal Server \' || sys_stat(\'st_dbms_ver\')), \n', retValue);
  http ('    XMLELEMENT (\'http://purl.org/dc/elements/1.1/:creator\', U_FULL_NAME) \n', retValue);
  http ('  from \n', retValue);
  http ('    CAL.WA.EVENTS, DB.DBA.SYS_USERS, DB.DBA.WA_INSTANCE \n', retValue);
  http ('  where \n', retValue);
  http ('    E_ID = :id and U_ID = <USER_ID> and E_DOMAIN_ID = <DOMAIN_ID> and WAI_ID = E_DOMAIN_ID and WAI_IS_PUBLIC = 1\n', retValue);
  http (']]></sql:sqlx>\n', retValue);

  http ('<sql:sqlx><![CDATA[\n', retValue);
  http ('  select \n', retValue);
  http ('    XMLAGG (XMLELEMENT(\'item\',\n', retValue);
  http ('    XMLELEMENT (\'title\', CAL.WA.utf2wide (EC_TITLE)),\n', retValue);
  http ('    XMLELEMENT (\'guid\', CAL.WA.calendar_url (<DOMAIN_ID>)||\'conversation.vspx\'||\'?id=\'||cast (EC_EVENT_ID as varchar)||\'#\'||cast (EC_ID as varchar)),\n', retValue);
  http ('    XMLELEMENT (\'link\', CAL.WA.calendar_url (<DOMAIN_ID>)||\'conversation.vspx\'||\'?id=\'||cast (EC_EVENT_ID as varchar)||\'#\'||cast (EC_ID as varchar)),\n', retValue);
  http ('    XMLELEMENT (\'http://purl.org/dc/elements/1.1/:creator\', EC_U_MAIL),\n', retValue);
  http ('    XMLELEMENT (\'pubDate\', DB.DBA.date_rfc1123 (EC_UPDATED)),\n', retValue);
  http ('    XMLELEMENT (\'description\', CAL.WA.utf2wide (blob_to_string (EC_COMMENT))))) \n', retValue);
  http ('  from \n', retValue);
  http ('    (select TOP 15 \n', retValue);
  http ('       EC_ID, \n', retValue);
  http ('       EC_EVENT_ID, \n', retValue);
  http ('       EC_TITLE, \n', retValue);
  http ('       EC_COMMENT, \n', retValue);
  http ('       EC_U_MAIL, \n', retValue);
  http ('       EC_UPDATED \n', retValue);
  http ('     from \n', retValue);
  http ('       CAL.WA.EVENT_COMMENTS, DB.DBA.WA_INSTANCE \n', retValue);
  http ('     where \n', retValue);
  http ('       EC_EVENT_ID = :id and WAI_ID = EC_DOMAIN_ID and WAI_IS_PUBLIC = 1\n', retValue);
  http ('     order by EC_UPDATED desc\n', retValue);
  http ('    ) sub \n', retValue);
  http (']]>\n', retValue);
  http ('</sql:sqlx>\n', retValue);

  http ('</channel>\n', retValue);
  http ('</rss>\n', retValue);

  retValue := string_output_string (retValue);
  retValue := replace (retValue, '<USER_ID>', cast(account_id as varchar));
  retValue := replace (retValue, '<DOMAIN_ID>', cast(domain_id as varchar));

  return retValue;
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
  home := home || 'Calendar Gems/';
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

  -- COMMENT
  path := home || 'Calendar.comment';
  DB.DBA.DAV_DELETE_INT (path, 1, null, null, 0);

  content := CAL.WA.export_comment_sqlx (domain_id, account_id);
  DB.DBA.DAV_RES_UPLOAD_STRSES_INT (path, content, 'text/xml', exec_perm, http_dav_uid (), http_dav_uid () + 1, null, null, 0);
  DB.DBA.DAV_PROP_SET_INT (path, 'xml-template', 'execute', 'dav', null, 0, 0, 1);
  DB.DBA.DAV_PROP_SET_INT (path, 'xml-sql-encoding', 'utf-8', 'dav', null, 0, 0, 1);
  DB.DBA.DAV_PROP_SET_INT (path, 'xml-sql-description', 'RSS discussion based XML document generated by OpenLink Calendar', 'dav', null, 0, 0, 1);

  return;
}
;

-------------------------------------------------------------------------------
--
create procedure CAL.WA.domain_gems_delete (
  in domain_id integer,
  in account_id integer := null,
  in appName varchar := 'Calendar Gems',
  in appGems varchar := null)
{
  declare tmp, home, path varchar;

  if (isnull (account_id))
    account_id := CAL.WA.domain_owner_id (domain_id);

  home := CAL.WA.dav_home (account_id);
  if (isnull (home))
    return;

  if (isnull (appGems))
    appGems := CAL.WA.domain_gems_name (domain_id);
  home := home || appName || '/' || appGems || '/';

  path := home || 'Calendar.rss';
  DB.DBA.DAV_DELETE_INT (path, 1, null, null, 0);
  path := home || 'Calendar.rdf';
  DB.DBA.DAV_DELETE_INT (path, 1, null, null, 0);
  path := home || 'Calendar.atom';
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

  declare home, path varchar;
  home := CAL.WA.dav_home (account_id);
  path := home || 'Calendar' || '/' || concat(CAL.WA.domain_name(domain_id), '_Gems') || '/';
  DB.DBA.DAV_DELETE_INT (path || 'Calendar.rss', 1, null, null, 0);
  DB.DBA.DAV_DELETE_INT (path || 'Calendar.atom', 1, null, null, 0);
  DB.DBA.DAV_DELETE_INT (path || 'Calendar.rdf', 1, null, null, 0);

  declare auth_pwd varchar;
  auth_pwd := coalesce((SELECT U_PWD FROM WS.WS.SYS_DAV_USER WHERE U_NAME = 'dav'), '');
  if (auth_pwd[0] = 0)
    auth_pwd := pwd_magic_calc ('dav', auth_pwd, 1);
  DB.DBA.DAV_DELETE (path, 1, 'dav', auth_pwd);
  DB.DBA.DAV_DELETE (home || 'Calendar (DET)/', 1, 'dav', auth_pwd);
  DB.DBA.DAV_DELETE (home || 'Calendar/', 1, 'dav', auth_pwd);

  path := home || 'Calendar' || '/';
  DB.DBA.DAV_MAKE_DIR (path, account_id, null, '110100000N');
  update WS.WS.SYS_DAV_COL set COL_DET = 'Calendar' where COL_ID = DAV_SEARCH_ID (path, 'C');
  return 1;
}
;

-------------------------------------------------------------------------------
--
create procedure CAL.WA.domain_owner_id (
  inout domain_id integer)
{
  return (select TOP 1 A.WAM_USER from WA_MEMBER A, WA_INSTANCE B where A.WAM_MEMBER_TYPE = 1 and A.WAM_INST = B.WAI_NAME and B.WAI_ID = domain_id);
}
;

-------------------------------------------------------------------------------
--
create procedure CAL.WA.domain_owner_name (
  inout domain_id integer)
{
  return (select TOP 1 C.U_NAME from WA_MEMBER A, WA_INSTANCE B, SYS_USERS C where A.WAM_MEMBER_TYPE = 1 and A.WAM_INST = B.WAI_NAME and B.WAI_ID = domain_id and C.U_ID = A.WAM_USER);
}
;

-------------------------------------------------------------------------------
--
create procedure CAL.WA.domain_delete (
  in domain_id integer)
{
  delete from CAL.WA.GRANTS where G_DOMAIN_ID = domain_id;
  delete from CAL.WA.SHARED where S_CALENDAR_ID = domain_id;
  delete from CAL.WA.EVENTS where E_DOMAIN_ID = domain_id;
  delete from CAL.WA.TAGS where T_DOMAIN_ID = domain_id;
  delete from CAL.WA.UPSTREAM where U_DOMAIN_ID = domain_id;
  delete from CAL.WA.SETTINGS where S_DOMAIN_ID = domain_id;

  CAL.WA.domain_gems_delete (domain_id);
  CAL.WA.nntp_update (domain_id, null, null, 1, 0);

  VHOST_REMOVE (lpath => sprintf ('/calendar/%d', domain_id));

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
create procedure CAL.WA.domain_nntp_name (
  in domain_id integer)
{
  return CAL.WA.domain_nntp_name2 (CAL.WA.domain_name (domain_id), CAL.WA.domain_owner_name (domain_id));
}
;

-------------------------------------------------------------------------------
--
create procedure CAL.WA.domain_nntp_name2 (
  in domain_name varchar,
  in owner_name varchar)
{
  return sprintf ('ods.calendar.%s.%U', owner_name, CAL.WA.string2nntp (domain_name));
}
;

-------------------------------------------------------------------------------
--
create procedure CAL.WA.domain_gems_name (
  in domain_id integer)
{
  return CAL.WA.domain_name (domain_id);
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
create procedure CAL.WA.domain_sioc_url (
  in domain_id integer,
  in sid varchar := null,
  in realm varchar := null)
{
  declare S varchar;

  S := sprintf ('http://%s/dataspace/%U/calendar/%U', DB.DBA.wa_cname (), CAL.WA.domain_owner_name (domain_id), CAL.WA.domain_name (domain_id));
  return CAL.WA.url_fix (S, sid, realm);
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
  return coalesce((select CAL.WA.user_name (U_NAME, U_FULL_NAME) from DB.DBA.SYS_USERS where U_ID = account_id), '');
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
create procedure CAL.WA.account_sioc_url (
  in domain_id integer,
  in sid varchar := null,
  in realm varchar := null)
{
  declare S varchar;

  S := sprintf ('http://%s/dataspace/%U', DB.DBA.wa_cname (), CAL.WA.domain_owner_name (domain_id));
  return CAL.WA.url_fix (S, sid, realm);
}
;

-------------------------------------------------------------------------------
--
create procedure CAL.WA.user_name(
  in u_name any,
  in u_full_name any) returns varchar
{
  if (not is_empty_or_null(trim(u_full_name)))
    return trim (u_full_name);
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

create procedure CAL.WA.instance_check (
  in account_id integer,
  in type_name varchar)
{
  return coalesce((select top 1 WAI_ID from DB.DBA.WA_MEMBER, DB.DBA.WA_INSTANCE where WAM_INST = WAI_NAME and WAM_USER = account_id and WAI_TYPE_NAME = type_name order by WAI_ID), 0);
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

-------------------------------------------------------------------------------
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

-------------------------------------------------------------------------------
--
create procedure CAL.WA.tags2vector(
  inout tags varchar)
{
  return split_and_decode(trim(tags, ','), 0, '\0\0,');
}
;

-------------------------------------------------------------------------------
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

-------------------------------------------------------------------------------
--
create procedure CAL.WA.tags_exchangeTest (
  inout tagsEvent any,
  inout tagsInclude any := null,
  inout tagsExclude any := null)
{
  declare N integer;
  declare tags, testTags any;

  if (is_empty_or_null (tagsEvent) and not is_empty_or_null (tagsInclude))
    goto _false;

  -- test exclude tags
  if (is_empty_or_null (tagsExclude))
    goto _include;
  if (is_empty_or_null (tagsEvent))
    goto _include;
  tags := CAL.WA.tags2vector (tagsEvent);
  testTags := CAL.WA.tags2vector (tagsExclude);
  for (N := 0; N < length (tags); N := N + 1)
  {
    if (CAL.WA.vector_contains (testTags, tags [N]))
      goto _false;
  }

_include:;
  -- test include tags
  if (is_empty_or_null (tagsInclude))
    goto _true;
  tags := CAL.WA.tags2vector (tagsEvent);
  testTags := CAL.WA.tags2vector (tagsInclude);
  for (N := 0; N < length (tags); N := N + 1)
  {
    if (CAL.WA.vector_contains (testTags, tags [N]))
      goto _true;
  }

_false:;
  return 0;

_true:;
  return 1;
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

  if (is_http_ctx ())
  {
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
  return concat('http://', DB.DBA.wa_cname (), home, 'Calendar Gems/', CAL.WA.domain_gems_name (domain_id), '/');
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
  return replace (concat(home, 'Calendar Gems/', CAL.WA.domain_gems_name (domain_id), '/'), ' ', '%20');
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
create procedure CAL.WA.banner_links (
  in domain_id integer,
  in sid varchar := null,
  in realm varchar := null)
{
  if (domain_id <= 0)
    return 'Public Calendar';

  return sprintf ('<a href="%s" title="%s">%V</a> (<a href="%s" title="%s">%V</a>)',
                  CAL.WA.domain_sioc_url (domain_id, sid, realm),
                  CAL.WA.domain_name (domain_id),
                  CAL.WA.domain_name (domain_id),
                  CAL.WA.account_sioc_url (domain_id, sid, realm),
                  CAL.WA.account_fullName (CAL.WA.domain_owner_id (domain_id)),
                  CAL.WA.account_fullName (CAL.WA.domain_owner_id (domain_id))
                 );
}
;

-------------------------------------------------------------------------------
--
create procedure CAL.WA.dav_content (
  inout uri varchar)
{
  declare exit handler for sqlstate '*'
  {
    return null;
  };

  declare N integer;
  declare content, oldUri, newUri, reqHdr, resHdr varchar;
  declare auth_uid, auth_pwd varchar;
  declare xt any;

  newUri := uri;
  reqHdr := null;
  CAL.WA.account_access (auth_uid, auth_pwd);
  reqHdr := sprintf ('Authorization: Basic %s', encode_base64(auth_uid || ':' || auth_pwd));

_again:
  N := N + 1;
  oldUri := newUri;
  commit work;
  content := http_get (newUri, resHdr, 'GET', reqHdr);
  if (resHdr[0] like 'HTTP/1._ 30_ %')
  {
    newUri := http_request_header (resHdr, 'Location');
    newUri := WS.WS.EXPAND_URL (oldUri, newUri);
    if (N > 15)
      return null;
    if (newUri <> oldUri)
      goto _again;
  }
  if (resHdr[0] like 'HTTP/1._ 4__ %' or resHdr[0] like 'HTTP/1._ 5__ %')
    return null;

  xt := CAL.WA.string2xml (content);
  if (xpath_eval ('/html', xt, 1) is null)
    return content;
  newUri := cast (xpath_eval ('/html/head/link[@rel="alternate" and @type="text/calendar"]/@href', xt, 1) as varchar);
  return CAL.WA.dav_content (newUri);
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
create procedure CAL.WA.string2nntp (
  in S varchar)
{
  S := replace (S, '.', '_');
  S := replace (S, '@', '_');
  return sprintf ('%U', S);
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
  in condition varchar := 'AND')
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

  if (isnull (pDate) or isnull (pTime))
    return pDate;
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
  if (isnull (pDate1) or isnull (pDate2))
    return 0;
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
  if (isnull (dt))
    return '';
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
    return 'M/D/Y';
  if (pFormat = 'yyyy/MM/dd')
    return 'Y/M/D';
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
  in nameLength integer := 0)
{
  declare N integer;
  declare names any;

  N := CAL.WA.dt_WeekDay (dt, weekStarts);
  names := CAL.WA.dt_WeekNames (weekStarts, nameLength);
  return names [N-1];
}
;

-----------------------------------------------------------------------------------------
--
create procedure CAL.WA.dt_WeekNames (
  in weekStarts varchar := 'm',
  in nameLength integer := 0)
{
  declare N integer;
  declare names any;

  if (weekStarts = 'm') {
    names := vector ('Monday', 'Tuesday', 'Wednesday', 'Thursday ', 'Friday', 'Saturday', 'Sunday');
  } else {
    names := vector ('Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday ', 'Friday', 'Saturday');
  }
  if (nameLength <> 0)
    for (N := 0; N < length (names); N := N + 1)
      aset (names, N, subseq (names[N], 0, nameLength));
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

-----------------------------------------------------------------------------------------
--
create procedure CAL.WA.dt_exchangeTest (
  in testFrom datetime,
  in testTo datetime,
  in eventFrom datetime,
  in eventTo datetime,
  in eventRepeatUntil datetime := null)
{
  if (is_empty_or_null (testFrom) and is_empty_or_null (testTo))
    goto _true;

  if (eventRepeatUntil < testFrom)
    goto _false;

  eventFrom := CAL.WA.dt_dateClear (eventFrom);
  -- test to period
  if (not is_empty_or_null (testTo))
  {
    if (eventFrom > testTo)
      goto _false;
  }

  eventTo := CAL.WA.dt_dateClear (eventTo);
  -- test from period
  if (not is_empty_or_null (testFrom))
  {
    if (eventTo < testFrom)
      goto _false;
  }

_true:;
  return 1;

_false:;
  return 0;
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
-- Durations
--
-----------------------------------------------------------------------------------------
create procedure CAL.WA.d_decode (
  in d varchar)
{
  declare t_index, t_sign, retValue integer;
  declare t_part varchar;
  declare secs integer;
  declare regexp any;

  retValue := 0;

  t_index := strchr (d, 'T');
  t_part := d;
  t_sign := 1;
  if (t_index is not null)
  {
	  declare t varchar;

	  t := subseq (d, t_index);
	  secs := 0;
	  regexp := regexp_parse ('T([0-9]+H)?([0-9]+M)?([0-9\.]+S)?', t, 0);
	  if (regexp is null)
	    return 0;
	  if (length (regexp) > 2 and regexp[2] <> -1)
	    secs := secs + 3600 * atoi (subseq (t, regexp[2], regexp[3]));
	  if (length (regexp) > 4 and regexp[4] <> -1)
	    secs := secs + 60 * atoi (subseq (t, regexp[4], regexp[5]));
	  if (length (regexp) > 6 and regexp[6] <> -1)
	    secs := secs + atoi (subseq (t, regexp[6], regexp[7]));
	  retValue := secs;
	  t_part := subseq (d, 0, t_index);
  }
  if (t_part like '-%')
  {
	  t_part := subseq (t_part, 1);
	  t_sign := -1;
  }
  if (length (t_part) > 1)
  {
	  secs := 0;
	  regexp := regexp_parse ('P([0-9]+D)?([0-9]+M)?', t_part, 0);
	  if (regexp is null)
	    return 0;
	  if (aref (regexp, 2) <> -1)
	    secs := secs + 24 * 3600 * atoi (subseq (t_part, regexp[2], regexp[3]));
	  if (aref (regexp, 4) <> -1)
	    secs := secs + 24 * 3600 * 30 * atoi (subseq (t_part, regexp[4], regexp[5]));
	  retValue := retValue + secs;
  }
  retValue := retValue * t_sign;

  return retValue;
}
;

-----------------------------------------------------------------------------------------
--
create procedure CAL.WA.d_encode (
  in d integer)
{
  return sprintf ('-PT%dS', d);
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

  if (propertyType = 'boolean')
  {
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
    if (isnull (regexp_match('^(0[1-9]|[1-9]|[12][0-9]|3[01])[- /.](0[1-9]|[1-9]|1[012])[- /.]((?:19|20)[0-9][0-9])\$', propertyValue)))
      goto _error;
    return CAL.WA.dt_stringdate (propertyValue, 'dd.MM.yyyy');
  } else if (propertyType = 'date-MM/dd/yyyy') {
    if (isnull (regexp_match('^(0[1-9]|[1-9]|1[012])[- /.](0[1-9]|[1-9]|[12][0-9]|3[01])[- /.]((?:19|20)[0-9][0-9])\$', propertyValue)))
      goto _error;
    return CAL.WA.dt_stringdate (propertyValue, 'MM/dd/yyyy');
  } else if (propertyType = 'date-yyyy/MM/dd') {
    if (isnull (regexp_match('^((?:19|20)[0-9][0-9])[- /.](0[1-9]|[1-9]|1[012])[- /.](0[1-9]|[1-9]|[12][0-9]|3[01])\$', propertyValue)))
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

-----------------------------------------------------------------------------------------
--
create procedure CAL.WA.checkedAttribute (
  in checkedValue integer,
  in compareValue any := 1)
{
  if (checkedValue = compareValue)
    return 'checked="checked"';
  return '';
}
;

-------------------------------------------------------------------------------
--
create procedure CAL.WA.dashboard_get(
  in _domain_id integer,
  in _account_id integer,
  in _privacy integer := 0)
{
  declare sStream any;

  sStream := string_output ();
  http ('<calendar-db>', sStream);
  if (_privacy = 1)
  {
    for (select top 10 *
        from (select a.E_SUBJECT,
                        SIOC..calendar_event_iri (_domain_id, E_ID) E_URI,
                     coalesce (a.E_UPDATED, now ()) E_UPDATED
                from CAL.WA.EVENTS a,
                     DB.DBA.WA_INSTANCE b,
                     DB.DBA.WA_MEMBER c
                  where a.E_DOMAIN_ID = _domain_id
                    and a.E_PRIVACY >= _privacy
                  and b.WAI_ID = a.E_DOMAIN_ID
                  and c.WAM_INST = b.WAI_NAME
                    and c.WAM_USER = _account_id
                order by a.E_UPDATED desc
                ) x
        ) do
  {
      CAL.WA.dashboard_item (sStream, _account_id, E_SUBJECT, E_URI, E_UPDATED);
  }
  } else {
    for (select top 10 *
           from (select a.E_SUBJECT,
                        SIOC..calendar_event_iri (_domain_id, a.E_ID) E_URI,
                        coalesce (a.E_UPDATED, now ()) E_UPDATED
                   from CAL.WA.EVENTS a,
                        CAL..MY_CALENDARS b,
                        DB.DBA.WA_INSTANCE c,
                        DB.DBA.WA_MEMBER d
                  where b.domain_id = _domain_id
                    and b.privacy = _privacy
                    and a.E_DOMAIN_ID = b.CALENDAR_ID
                    and a.E_PRIVACY >= b.CALENDAR_PRIVACY
                    and c.WAI_ID = _domain_id
                    and d.WAM_INST = c.WAI_NAME
                    and d.WAM_USER = _account_id
                  order by a.E_UPDATED desc
                ) x
        ) do
    {
      CAL.WA.dashboard_item (sStream, _account_id, E_SUBJECT, E_URI, E_UPDATED);
    }
  }
  http ('</calendar-db>', sStream);
  return string_output_string (sStream);
}
;

-------------------------------------------------------------------------------
--
create procedure CAL.WA.dashboard_item (
  inout sStream integer,
  in account_id integer,
  in subject varchar,
  in uri varchar,
  in updated datetime)
{
  http ('<event>', sStream);
  http (sprintf ('<dt>%s</dt>', date_iso8601 (updated)), sStream);
  http (sprintf ('<title><![CDATA[%s]]></title>', coalesce (subject, 'No subject')), sStream);
  http (sprintf ('<link>%V</link>', uri), sStream);
  http (sprintf ('<from><![CDATA[%s]]></from>', CAL.WA.account_fullName (account_id)), sStream);
  http (sprintf ('<uid>%s</uid>', CAL.WA.account_name (account_id)), sStream);
  http ('</event>', sStream);
}
;

-------------------------------------------------------------------------------
--
create procedure CAL.WA.settings (
  inout domain_id integer)
{
  return coalesce((select deserialize (blob_to_string(S_DATA)) from CAL.WA.SETTINGS where S_DOMAIN_ID = domain_id), vector());
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
  in domain_id integer)
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
  in domain_id integer)
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

create procedure CAL.WA.settings_dateFormat2 (
  in domain_id integer)
{
  return CAL.WA.settings_dateFormat (CAL.WA.settings (CAL.WA.domain_owner_id (domain_id)));
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
create procedure CAL.WA.settings_timeFormat2 (
  in domain_id integer)
{
  return CAL.WA.settings_timeFormat (CAL.WA.settings (CAL.WA.domain_owner_id (domain_id)));
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
  in uid varchar,
  in domain_id integer,
  in subject varchar,
  in description varchar,
  in location varchar,
  in attendees varchar,
  in privacy integer,
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
  in notes varchar := '',
  in updated datetime := null)
{
  if (isnull (updated))
    updated := now ();
  if (id = -1) {
    id := sequence_next ('CAL.WA.event_id');
    insert into CAL.WA.EVENTS
      (
        E_ID,
        E_UID,
        E_DOMAIN_ID,
        E_SUBJECT,
        E_DESCRIPTION,
        E_LOCATION,
        E_PRIVACY,
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
        uid,
        domain_id,
        subject,
        description,
        location,
        privacy,
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
        updated
      );
  } else {
    update CAL.WA.EVENTS
       set E_SUBJECT = subject,
           E_DESCRIPTION = description,
           E_LOCATION = location,
           E_PRIVACY = privacy,
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
           E_UPDATED = updated
     where E_ID = id;
  }
  CAL.WA.attendees_update (id, attendees);
  return id;
}
;

-------------------------------------------------------------------------------
--
create procedure CAL.WA.event_delete (
  in id integer,
  in onOffset varchar := null)
{
  if (isnull (onOffset))
  {
    delete from CAL.WA.EVENTS where E_ID = id;
  } else {
    declare eExceptions any;

    onOffset := '<' || cast (onOffset as varchar) || '>';
    eExceptions := (select E_REPEAT_EXCEPTIONS from CAL.WA.EVENTS where E_ID = id);
    if (isnull (strstr (eExceptions, onOffset)))
      update CAL.WA.EVENTS
         set E_REPEAT_EXCEPTIONS = eExceptions || ' ' || onOffset
       where E_ID = id;
  }
}
;

-------------------------------------------------------------------------------
--
create procedure CAL.WA.event_permissions (
  in id integer,
  in domain_id integer,
  in access_role varchar)
{
  declare event_domain_id integer;

  event_domain_id := (select E_DOMAIN_ID from CAL.WA.EVENTS where E_ID = id);
  if (isnull (event_domain_id))
    return '';
  if (event_domain_id = domain_id)
  {
    if (CAL.WA.access_is_write (access_role))
    return 'W';
    return 'R';
  }
  for (select a.WAI_IS_PUBLIC,
              b.*,
              c.G_ENABLE,
              c.G_MODE
         from DB.DBA.WA_INSTANCE a,
              CAL.WA.SHARED b
                left join CAL.WA.GRANTS c on c.G_ID = b.S_GRANT_ID
        where a.WAI_ID = b.S_CALENDAR_ID
          and b.S_DOMAIN_ID = domain_id
          and b.S_CALENDAR_ID = event_domain_id
          and b.S_VISIBLE = 1) do
  {
    if (isnull (S_GRANT_ID))
    {
      if (WAI_IS_PUBLIC = 1)
        return 'R';
    } else {
      if (G_ENABLE)
      {
        if (CAL.WA.access_is_write (access_role))
        return G_MODE;
        return 'R';
      }
    }
  }
  return '';
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

  -- deleted occurrence
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

  -- Every X day/weekday/weekend/... of Y-th month(s)
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

  -- Every X day/weekday/weekend/... of Y-th month(s)
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

  -- Every X day/weekday/weekend/... of Y-th month(s)
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

  -- Every X day/weekday/weekend/... of Y-th month(s)
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
  if (eRepeatParam1 = 5)
  {
    dt := CAL.WA.dt_EndOfMonth (dt);
    while (not CAL.WA.event_testDayKind (dt, eRepeatParam2))
      dt := dateadd ('day', -1, dt);
    return dayofmonth (dt);
  }

  dt := CAL.WA.dt_BeginOfMonth (dt);
  -- first|second|third|fourth (m|t|w|t|f|s|s)
  if (1 <= eRepeatParam2 and eRepeatParam2 <= 7)
  {
    while (not CAL.WA.event_testDayKind (dt, eRepeatParam2))
      dt := dateadd ('day', 1, dt);
    return dayofmonth (dateadd ('day', 7*(eRepeatParam1-1), dt));
  }

  -- first|second|third|fourth  (m|t|w|t|f|s|s) (day|weekday|weekend)
  if (1 <= eRepeatParam1 and eRepeatParam1 <= 4)
  {
    N := eRepeatParam1;
    while (pDay >= dayofmonth (dt))
    {
      if (CAL.WA.event_testDayKind (dt, eRepeatParam2))
      {
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

--------------------------------------------------------------------------------
--
create procedure CAL.WA.event_color (
  in id integer,
  in domain_id integer)
{
  declare event_domain_id integer;

  event_domain_id := (select E_DOMAIN_ID from CAL.WA.EVENTS where E_ID = id);
  if (event_domain_id <> domain_id)
  {
    for (select S_COLOR from CAL.WA.SHARED where S_DOMAIN_ID = domain_id and S_CALENDAR_ID = event_domain_id) do
      return S_COLOR;
  }
  return '#fafafa';
}
;

--------------------------------------------------------------------------------
--
create procedure CAL.WA.event_domain (
  in id integer)
{
  return (select E_DOMAIN_ID from CAL.WA.EVENTS where E_ID = id);
}
;

-------------------------------------------------------------------------------
--
create procedure CAL.WA.events_forPeriod (
  in pDomainID integer,
  in pDateStart date,
  in pDateEnd date,
  in pPrivacy integer := 0,
  in pTaskMode integer := 0)
{
  declare dt_offset, dtTimezone integer;
  declare dtWeekStarts varchar;
  declare dt, dtStart, dtEnd, tzDT, tzEventStart, tzRepeatUntil date;

  declare c0, c1, c6, c7, c8 integer;
  declare c2, c5 varchar;
  declare c3, c4 datetime;
  result_names (c0, c1, c2, c3, c4, c5, c6, c7);

  dtTimezone := CAL.WA.settings_timeZone2 (pDomainID);
  dtWeekStarts := CAL.WA.settings_weekStarts2 (pDomainID);
  dtStart := CAL.WA.event_user2gmt (CAL.WA.dt_dateClear (pDateStart), dtTimezone);
  dtEnd := CAL.WA.event_user2gmt (dateadd ('day', 1, CAL.WA.dt_dateClear (pDateEnd)), dtTimezone);

    if (pTaskMode)
    {
    -- tasks
    for (select a.E_ID,
                a.E_EVENT,
                a.E_SUBJECT,
                a.E_EVENT_START,
                a.E_EVENT_END,
                a.E_REPEAT,
                a.E_REMINDER,
                a.E_ATTENDEES
           from CAL.WA.EVENTS a,
                CAL..MY_CALENDARS b
          where b.domain_id = pDomainID
            and b.privacy = pPrivacy
            and a.E_DOMAIN_ID = b.CALENDAR_ID
            and a.E_PRIVACY >= b.CALENDAR_PRIVACY
            and a.E_KIND = 1
            and a.E_EVENT_START <  dtEnd
            and a.E_EVENT_END   >  dtStart) do
    {
      result (E_ID,
              E_EVENT,
              E_SUBJECT,
                CAL.WA.event_gmt2user (E_EVENT_START, dtTimezone),
                CAL.WA.event_gmt2user (E_EVENT_END, dtTimezone),
              E_REPEAT,
              null,
              E_REMINDER,
              E_ATTENDEES);
    }
  }

  -- regular events
  for (select a.E_ID,
              a.E_EVENT,
              a.E_SUBJECT,
              a.E_EVENT_START,
              a.E_EVENT_END,
              a.E_REPEAT,
              a.E_REMINDER,
              a.E_ATTENDEES
         from CAL.WA.EVENTS a,
              CAL..MY_CALENDARS b
        where b.domain_id = pDomainID
          and b.privacy = pPrivacy
          and a.E_DOMAIN_ID = b.CALENDAR_ID
          and a.E_PRIVACY >= b.CALENDAR_PRIVACY
          and a.E_KIND = 0
          and (a.E_REPEAT = '' or a.E_REPEAT is null)
          and (
                (a.E_EVENT = 0 and a.E_EVENT_START >= dtStart and a.E_EVENT_START <  dtEnd) or
                (a.E_EVENT = 1 and a.E_EVENT_START <  dtEnd   and a.E_EVENT_END   >  dtStart)
              )) do
  {
    result (E_ID,
            E_EVENT,
            E_SUBJECT,
              CAL.WA.event_gmt2user (E_EVENT_START, dtTimezone),
              CAL.WA.event_gmt2user (E_EVENT_END, dtTimezone),
            E_REPEAT,
            null,
            E_REMINDER,
            E_ATTENDEES);
  }

  -- repeatable events
  for (select a.E_ID,
              a.E_SUBJECT,
              a.E_EVENT,
              a.E_EVENT_START,
              a.E_EVENT_END,
              a.E_REPEAT,
              a.E_REPEAT_PARAM1,
              a.E_REPEAT_PARAM2,
              a.E_REPEAT_PARAM3,
              a.E_REPEAT_UNTIL,
              a.E_REPEAT_EXCEPTIONS,
              a.E_REMINDER,
              a.E_ATTENDEES
         from CAL.WA.EVENTS a,
              CAL..MY_CALENDARS b
        where b.domain_id = pDomainID
          and b.privacy = pPrivacy
          and a.E_DOMAIN_ID = b.CALENDAR_ID
          and a.E_PRIVACY >= b.CALENDAR_PRIVACY
          and a.E_KIND = 0
          and a.E_REPEAT <> ''
          and a.E_EVENT_START < dtEnd
          and ((a.E_REPEAT_UNTIL is null) or (a.E_REPEAT_UNTIL >= dtStart))) do
  {
      tzEventStart := CAL.WA.event_gmt2user (E_EVENT_START, dtTimezone);
      tzRepeatUntil := CAL.WA.event_gmt2user (E_REPEAT_UNTIL, dtTimezone);
    dt := dtStart;
      while (dt < dtEnd)
      {
        tzDT := CAL.WA.event_gmt2user (dt, dtTimezone);
      if (CAL.WA.event_occurAtDate (tzDT,
                                    E_EVENT,
                                    tzEventStart,
                                    E_REPEAT,
                                    E_REPEAT_PARAM1,
                                    E_REPEAT_PARAM2,
                                    E_REPEAT_PARAM3,
                                    tzRepeatUntil,
                                    E_REPEAT_EXCEPTIONS,
                                      dtWeekStarts)) {
          if (E_EVENT = 1)
          {
          dt_offset := datediff ('day', dateadd ('hour', -12, E_EVENT_START), dt);
        } else {
          dt_offset := datediff ('day', E_EVENT_START, dateadd ('second', 86399, dt));
        }
        result (E_ID,
                E_EVENT,
                E_SUBJECT,
                  CAL.WA.event_gmt2user (dateadd ('day', dt_offset, E_EVENT_START), dtTimezone),
                  CAL.WA.event_gmt2user (dateadd ('day', dt_offset, E_EVENT_END), dtTimezone),
                E_REPEAT,
                dt_offset,
                E_REMINDER,
                E_ATTENDEES);
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
  in uid varchar,
  in domain_id integer,
  in subject varchar,
  in description varchar,
  in attendees varchar,
  in privacy integer,
  in tags varchar,
  in eEventStart datetime,
  in eEventEnd datetime,
  in priority integer,
  in status varchar,
  in complete integer,
  in completed datetime,
  in notes varchar := null,
  in updated datetime := null)
{
  if (isnull (updated))
    updated := now ();
  if (id = -1) {
    id := sequence_next ('CAL.WA.event_id');
    insert into CAL.WA.EVENTS
      (
        E_ID,
        E_UID,
        E_DOMAIN_ID,
        E_KIND,
        E_SUBJECT,
        E_DESCRIPTION,
        E_PRIVACY,
        E_TAGS,
        E_EVENT_START,
        E_EVENT_END,
        E_PRIORITY,
        E_STATUS,
        E_COMPLETE,
        E_COMPLETED,
        E_NOTES,
        E_CREATED,
        E_UPDATED
      )
      values
      (
        id,
        uid,
        domain_id,
        1,
        subject,
        description,
        privacy,
        tags,
        eEventStart,
        eEventEnd,
        priority,
        status,
        complete,
        completed,
        notes,
        now (),
        updated
      );
  } else {
    update CAL.WA.EVENTS
       set E_SUBJECT = subject,
           E_DESCRIPTION = description,
           E_PRIVACY = privacy,
           E_TAGS = tags,
           E_EVENT_START = eEventStart,
           E_EVENT_END = eEventEnd,
           E_PRIORITY = priority,
           E_STATUS = status,
           E_COMPLETE = complete,
           E_COMPLETED = completed,
           E_NOTES = notes,
           E_UPDATED = updated
     where E_ID = id;
  }
  CAL.WA.attendees_update (id, attendees);
  return id;
}
;

-------------------------------------------------------------------------------
--
create procedure CAL.WA.calendar_tags_select (
  in id integer)
{
  return coalesce((select E_TAGS from CAL.WA.EVENTS where E_ID = id), '');
}
;

-------------------------------------------------------------------------------
--
create procedure CAL.WA.calendar_tags_update (
  in id integer,
  in domain_id integer,
  in tags any)
{
    update CAL.WA.EVENTS
     set E_TAGS = tags,
           E_UPDATED = now ()
   where E_ID = id;
  }
;

-------------------------------------------------------------------------------
--
create procedure CAL.WA.attendees_update (
  in id integer,
  in attendees varchar)
{
  declare N, attendees_id integer;
  declare mail varchar;
  declare V any;

  V := split_and_decode (attendees, 0, '\0\0,');
  for (N := 0; N < length (V); N := N + 1)
  {
    mail := trim (V[N]);
    if (not is_empty_or_null (mail))
    {
      attendees_id := (select AT_ID from CAL.WA.ATTENDEES where AT_EVENT_ID = id and AT_MAIL = mail);
      if (isnull (attendees_id))
      {
        insert into CAL.WA.ATTENDEES (AT_UID, AT_EVENT_ID, AT_MAIL)
          values (CAL.WA.uid (), id, mail);
      }
    }
  }
}
;

-------------------------------------------------------------------------------
--
create procedure CAL.WA.attendees_update_status (
  in uid varchar,
  in status varchar)
{
   update CAL.WA.ATTENDEES set AT_STATUS = status, AT_DATE_RESPOND = now (), AT_LOG = null where AT_UID = uid;
}
;

-------------------------------------------------------------------------------
--
create procedure CAL.WA.attendees_return (
  in id integer)
{
  declare attendees varchar;

  attendees := '';
  for (select AT_MAIL from CAL.WA.ATTENDEES where AT_EVENT_ID = id) do
  {
    attendees := attendees || ',' || AT_MAIL;
  }
  return trim (attendees, ',');
}
;

-------------------------------------------------------------------------------
--
create procedure CAL.WA.attendees_select (
  in id integer,
  in status any)
{
  declare attendees any;

  attendees := vector ();
  for (select * from CAL.WA.ATTENDEES where AT_EVENT_ID = id and coalesce (AT_STATUS, '') = status order by AT_MAIL) do
  {
    attendees := vector_concat (attendees, vector (vector (AT_MAIL, coalesce (AT_DATE_REQUEST, AT_DATE_RESPOND))));
  }
  return attendees;
}
;

-------------------------------------------------------------------------------
--
create procedure CAL.WA.attendees_mails ()
{
  declare save_id, account_id, domain_id integer;
  declare T, H varchar;
  declare dateFormat, timeFormat varchar;
  declare url, account_mail, subject, period, subject_mail, content_text, content_html varchar;

  H := '<table cellspacing="0" cellpadding="0" border="0" width="100%%"> ' ||
       '  <tr> ' ||
       '    <td nowrap="noswap"><b>ODS Calendar</b></td> ' ||
       '    <td align="right" valign="bottom" nowrap="nowrap"><b>Meeting Request</b></td> ' ||
       '  </tr> ' ||
       '  <tr> ' ||
       '    <td colspan="2" bgcolor="#800000" height="1"></td> ' ||
       '  </tr> ' ||
       '  <tr> ' ||
       '    <td valign="top" width="100%%" colspan="2" style="padding-top:10px;"> ' ||
       '      <br /><br /> ' ||
       '      <table width="600" border="0" cellspacing="0" cellpadding="5"> ' ||
       '        <tr> ' ||
       '          <td><b>Subject</b></td>  ' ||
       '          <td>%s</td> ' ||
       '        </tr> ' ||
       '        <tr> ' ||
       '          <td><b>When</b></td> ' ||
       '          <td>%s</td> ' ||
       '        </tr> ' ||
       '        <tr> ' ||
       '          <td><b>Please RSWP</b></td> ' ||
       '          <td><a href="%s" target="new"><b>Respond to Meeting Request</b></a></td> ' ||
       '        </tr> ' ||
       '      </table> ' ||
       '      <br /><br /> ' ||
       '    </td> ' ||
       '  </tr> ' ||
       '  <tr> ' ||
       '    <td colspan="2" width="100%%"><br><font size="1"> ' ||
       '      If the link appears to be inactive, just cut and paste it into a browser location bar and click Enter ' ||
       '      <br>----------------------<br> ' ||
       '      <a href="%s" target="new">%s</a> ' ||
       '      <br>----------------------<br> ' ||
       '	  </td> ' ||
       '  </tr> ' ||
       '</table> ';
  T := ' ODS Calendar: Meeteng Request\n\n\n' ||
       ' Subject: %s\n' ||
       ' When: %s\n' ||
       ' Please RSWP: %s\n';

  save_id := -1;
  for (select AT_ID as id, AT_UID as uid, AT_EVENT_ID as event_id, AT_MAIL as mail from CAL.WA.ATTENDEES where AT_DATE_REQUEST is null order by AT_EVENT_ID) do
  {
    if (save_id <> event_id)
    {
      save_id := event_id;
      for (select * from CAL.WA.EVENTS where E_ID = event_id) do
      {
        domain_id := E_DOMAIN_ID;
        dateFormat := CAL.WA.settings_dateFormat2 (domain_id);
        timeFormat := CAL.WA.settings_timeFormat2 (domain_id);
        subject := E_SUBJECT;
        subject_mail := 'Meeting Request: ' || subject;
        if (E_EVENT = 0)
        {
          period := sprintf ('%s - %s', CAL.WA.dt_datetimestring (E_EVENT_START, dateFormat, timeFormat), CAL.WA.dt_datetimestring (E_EVENT_END, dateFormat, timeFormat));
        } else {
          period := sprintf ('%s - %s', CAL.WA.dt_datestring (E_EVENT_START, dateFormat), CAL.WA.dt_datestring (E_EVENT_END, dateFormat));
        }
      }
      account_id := CAL.WA.domain_owner_id (domain_id);
      account_mail := CAL.WA.account_mail (account_id);
    }

    declare exit handler for sqlstate '*'
    {
      update CAL.WA.ATTENDEES set AT_LOG = __SQL_MESSAGE where AT_ID = id;
      goto _next;
    };

    url := sprintf ('http://%sattendees.vspx?uid=%U', CAL.WA.calendar_url (domain_id), uid);
    content_html := sprintf (H, subject, period, url, url, url);
    content_text := sprintf (T, subject, period, url);
    CAL.WA.send_mail (account_mail, mail, subject_mail, content_text, content_html);
    update CAL.WA.ATTENDEES set AT_DATE_REQUEST = now () where AT_ID = id;

  _next:;
  }
}
;

-------------------------------------------------------------------------------
--
create procedure CAL.WA.send_mail (
  in _from any,
  in _to any,
  in _subject any,
  in _message_text any,
  in _message_html any)
{
  declare _smtp_server, _mail_body, _mail_body_text, _mail_body_html, _encoded, _date any;

  if ((select max(WS_USE_DEFAULT_SMTP) from WA_SETTINGS) = 1)
  {
    _smtp_server := cfg_item_value(virtuoso_ini_path(), 'HTTPServer', 'DefaultMailServer');
  } else {
    _smtp_server := (select max(WS_SMTP) from WA_SETTINGS);
  }
  _encoded := encode_base64 (_subject);
  _encoded := replace (_encoded, '\r\n', '');
  _subject := concat ('Subject: =?UTF-8?B?', _encoded, '?=\r\n');
  _date := sprintf ('Date: %s\r\n', date_rfc1123 (now ()));
  _mail_body_text := mime_part ('text/plain; charset=UTF-8', null, null, _message_text);
  _mail_body_html := mime_part ('text/html; charset=UTF-8', null, null, _message_html);
  _mail_body := _date || _subject || mime_body (vector (_mail_body_html, _mail_body_text));

  if(not _smtp_server or length(_smtp_server) = 0)
  {
    signal('WA002', 'The Mail Server is not defined. Mail can not be sent.');
  }
  smtp_send (_smtp_server, _from, _to, _mail_body);
}
;

-------------------------------------------------------------------------------
--
-- Searches
--
-------------------------------------------------------------------------------
create procedure CAL.WA.search_sql (
  inout domain_id integer,
  inout privacy integer,
  inout data varchar)
{
  declare S, tmp, where2, delimiter2 varchar;

  where2 := ' \n ';
  delimiter2 := '\n and ';

  S := 'select a.E_ID,                       \n' ||
       '       a.E_DOMAIN_ID,                \n' ||
       '       a.E_KIND,                     \n' ||
       '       a.E_SUBJECT,                  \n' ||
       '       a.E_EVENT,                    \n' ||
       '       a.E_EVENT_START,              \n' ||
       '       a.E_EVENT_END,                \n' ||
       '       a.E_REPEAT,                   \n' ||
       '       a.E_REMINDER,                 \n' ||
       '       a.E_ATTENDEES,                \n' ||
       '       a.E_CREATED,                  \n' ||
       '       a.E_UPDATED                   \n' ||
       ' from  CAL.WA.EVENTS a,              \n' ||
       '       CAL..MY_CALENDARS b           \n' ||
       ' where b.domain_id = <DOMAIN_ID>     \n' ||
       '   and b.privacy = <PRIVACY>         \n' ||
       '   and a.E_DOMAIN_ID = b.CALENDAR_ID \n' ||
       '   and a.E_PRIVACY >= b.CALENDAR_PRIVACY <TEXT> <TAGS> <WHERE> \n';

  tmp := CAL.WA.xml_get ('keywords', data);
  if (not is_empty_or_null (tmp))
  {
    S := replace (S, '<TEXT>', sprintf('and contains (a.E_SUBJECT, \'[__lang "x-ViDoc"] %s\') \n', FTI_MAKE_SEARCH_STRING (tmp)));
  } else {
    tmp := CAL.WA.xml_get ('expression', data);
    if (not is_empty_or_null(tmp))
      S := replace (S, '<TEXT>', sprintf('and contains (a.E_SUBJECT, \'[__lang "x-ViDoc"] %s\') \n', tmp));
  }

  tmp := CAL.WA.xml_get ('tags', data);
  if (not is_empty_or_null (tmp))
  {
    tmp := CAL.WA.tags2search (tmp);
    S := replace (S, '<TAGS>', sprintf ('and contains (a.E_SUBJECT, \'[__lang "x-ViDoc"] %s\') \n', tmp));
  }

  S := replace (S, '<DOMAIN_ID>', cast (domain_id as varchar));
  S := replace (S, '<PRIVACY>', cast (privacy as varchar));;
  S := replace (S, '<TAGS>', '');
  S := replace (S, '<TEXT>', '');
  S := replace (S, '<WHERE>', where2);

  --dbg_obj_print(S);
  return S;
}
;

-------------------------------------------------------------------------------
--
create procedure CAL.WA.vcal_str (
  in xmlItem any,
  in xmlPath varchar)
{
  declare N integer;
  declare S, T varchar;

  N := 1;
  T := null;
  while (1)
  {
    S := cast (xquery_eval (xmlPath || sprintf ('val[%d]', N), xmlItem, 1) as varchar);
    if (is_empty_or_null (S))
      goto _exit;
    if (isnull (T))
    {
      T := S;
    } else {
      T := T || ',' || S;
    }
    N := N + 1;
  }

_exit:;
  return T;
}
;

-------------------------------------------------------------------------------
--
create procedure CAL.WA.vcal_str2date (
  in xmlItem any,
  in xmlPath varchar,
  in tzDict any := null)
{
  declare S, dt, tzID, tzOffset any;

  S := cast (xquery_eval (xmlPath || 'val', xmlItem, 1) as varchar);
  dt := CAL.WA.vcal_iso2date (S);
  if ((not isnull (dt)) and (not isnull (tzDict)) and (chr (S[length(S)-1]) <> 'Z'))
  {
      tzID := cast (xquery_eval (xmlPath || 'TZID', xmlItem, 1) as varchar);
    if (not isnull (tzID))
    {
        tzOffset := dict_get (tzDict, tzID, 0);
        dt := dateadd ('minute', tzOffset, dt);
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

  return null;
}
;

-------------------------------------------------------------------------------
--
create procedure CAL.WA.vcal_str2privacy (
  in xmlItem any,
  in xmlPath varchar)
{
  declare N integer;
  declare S, V any;

  V := vector ('PUBLIC', 1, 'PRIVATE', 0);
  S := cast (xquery_eval (xmlPath, xmlItem, 1) as varchar);
  for (N := 0; N < length (V); N := N + 2)
    if (lcase (S) = lcase (V[N]))
      return V[N+1];

  return null;
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
  if (length (V) < 10)
    return dt;

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
  if (isnull (dt))
    return null;
  return CAL.WA.dt_format (dt, 'YMD');
}
;

-----------------------------------------------------------------------------------------
--
create procedure CAL.WA.vcal_datetime2str (
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

  -- daily rule
  if (get_keyword ('FREQ', V) = 'DAILY') {
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
  -- daily rule
  if (eRepeat = 'D1') {
    S := 'FREQ=DAILY';
    S := S || ';INTERVAL=' || cast (eRepeatParam1 as varchar);
    if (not isnull (eRepeatUntil))
      S := S || ';UNTIL=' || CAL.WA.vcal_date2str (eRepeatUntil);
  }

  if (eRepeat = 'D2') {
    S := 'FREQ=DAILY';
    S := S || ';INTERVAL=1';
    S := S || ';BYDAY=MO,TU,WE,TH,FR';
    if (not isnull (eRepeatUntil))
      S := S || ';UNTIL=' || CAL.WA.vcal_date2str (eRepeatUntil);
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
      S := S || ';UNTIL=' || CAL.WA.vcal_date2str (eRepeatUntil);
  }

  if (eRepeat = 'M1') {
    S := 'FREQ=MONTHLY';
    S := S || ';INTERVAL=' || cast (eRepeatParam1 as varchar);
    S := S || ';BYMONTHDAY=' || cast (eRepeatParam2 as varchar);
    if (not isnull (eRepeatUntil))
      S := S || ';UNTIL=' || CAL.WA.vcal_date2str (eRepeatUntil);
  }

  if (eRepeat = 'M2') {
    S := 'FREQ=MONTHLY';
    S := S || ';INTERVAL=' || cast (eRepeatParam1 as varchar);
    if (eRepeatParam3 = 10)
      S := S || ';BYMONTHDAY=' || cast (eRepeatParam2 as varchar);
    if (not isnull (eRepeatUntil))
      S := S || ';UNTIL=' || CAL.WA.vcal_date2str (eRepeatUntil);
  }

  if (eRepeat = 'Y1') {
    S := 'FREQ=YEARLY';
    S := S || ';INTERVAL=' || cast (eRepeatParam1 as varchar);
    S := S || ';BYMONTH=' || cast (eRepeatParam2 as varchar);
    S := S || ';BYMONTHDAY=' || cast (eRepeatParam3 as varchar);
    if (not isnull (eRepeatUntil))
      S := S || ';UNTIL=' || CAL.WA.vcal_date2str (eRepeatUntil);
  }

  if (eRepeat = 'Y2') {
    S := 'FREQ=YEARLY';
    S := S || ';INTERVAL=1';
    S := S || ';BYMONTH=' || cast (eRepeatParam3 as varchar);
    if (eRepeatParam1 = 10)
      S := S || ';BYMONTHDAY=' || cast (eRepeatParam2 as varchar);
    if (not isnull (eRepeatUntil))
      S := S || ';UNTIL=' || CAL.WA.vcal_date2str (eRepeatUntil);
  }

  return S;
}
;

-------------------------------------------------------------------------------
--
create procedure CAL.WA.vcal_str2reminder (
  in xmlItem any,
  in xmlPath varchar)
{
  declare S varchar;

  S := CAL.WA.vcal_str (xmlItem, xmlPath);
  return abs (CAL.WA.d_decode (S));
}
;

-------------------------------------------------------------------------------
--
create procedure CAL.WA.export_vcal_reminder (
  in eReminder integer,
  inout sStream any)
{
  declare V any;

  if (is_empty_or_null (eReminder))
    return;

  http ('BEGIN:VALARM\r\n', sStream);
  http (sprintf ('TRIGGER:%s\r\n', CAL.WA.d_encode (eReminder)), sStream);
  http ('ACTION:DISPLAY\r\n', sStream);
  http ('END:VALARM\r\n', sStream);
}
;

-------------------------------------------------------------------------------
--
create procedure CAL.WA.import_vcal (
  in domain_id integer,
  in content any,
  in options any := null)
{
  declare N, nLength integer;
  declare oEvents, oTasks, oTags any;
  declare tmp, xmlData, xmlItems, itemName, V any;
  declare id,
          uid,
          subject,
          description,
          location,
          privacy,
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
          complete,
          completed,
          notes,
          updated any;
  declare vcalVersion any;
  declare tzDict, tzID, tzOffset any;

  -- options
  oEvents := 1;
  oTasks := 1;
  oTags := '';
  if (not isnull (options))
  {
    oEvents := cast (get_keyword ('events', options, '0') as integer);
    oTasks := cast (get_keyword ('tasks', options, '0') as integer);
    oTags := get_keyword ('tags', options, '');
  }

  -- using DAV parser
  if (not isstring (content))
  {
    xmlData := DB.DBA.IMC_TO_XML (cast (content as varchar));
  } else {
    xmlData := DB.DBA.IMC_TO_XML (content);
  }
  xmlData := xml_tree_doc (xmlData);
  xmlItems := xpath_eval ('/*', xmlData, 0);
  foreach (any xmlItem in xmlItems) do
  {
    itemName := xpath_eval ('name(.)', xmlItem);
    if (itemName = 'IMC-VCALENDAR')
    {
      -- vCalendar version
      vcalVersion := cast (xquery_eval ('VERSION/val', xmlItem, 1) as varchar);

      -- timezone
      tzDict := dict_new();
      nLength := xpath_eval('count (IMC-VTIMEZONE)', xmlItem);
      for (N := 1; N <= nLength; N := N + 1)
      {
        tzID := cast (xquery_eval (sprintf ('IMC-VTIMEZONE[%d]/TZID/val', N), xmlItem, 1) as varchar);
        if (not isnull (tzID))
        {
          tmp := cast (xquery_eval (sprintf ('IMC-VTIMEZONE[%d]/IMC-STANDARD/TZOFFSETTO/val', N), xmlItem, 1) as varchar);
          CAL.WA.tz_decode (tmp, tzOffset);
          if (not isnull (tzOffset))
            dict_put (tzDict, tzID, tzOffset);
        }
      }

      -- events
      if (oEvents)
      {
      nLength := xpath_eval('count (IMC-VEVENT)', xmlItem);
      for (N := 1; N <= nLength; N := N + 1)
      {
        uid := cast (xquery_eval (sprintf ('IMC-VEVENT[%d]/UID/val', N), xmlItem, 1) as varchar);
        id := coalesce ((select E_ID from CAL.WA.EVENTS where E_DOMAIN_ID = domain_id and E_UID = uid), -1);
        subject := cast (xquery_eval (sprintf ('IMC-VEVENT[%d]/SUMMARY/val', N), xmlItem, 1) as varchar);
        description := cast (xquery_eval (sprintf ('IMC-VEVENT[%d]/DESCRIPTION/val', N), xmlItem, 1) as varchar);
        location := cast (xquery_eval (sprintf ('IMC-VEVENT[%d]/LOCATION/val', N), xmlItem, 1) as varchar);
        privacy := CAL.WA.vcal_str2privacy (xmlItem, sprintf ('IMC-VEVENT[%d]/CLASS/val', N));
        if (isnull (privacy))
          privacy := CAL.WA.domain_is_public (domain_id);
          eventTags := CAL.WA.tags_join (CAL.WA.vcal_str (xmlItem, sprintf ('IMC-VEVENT[%d]/CATEGORIES/', N)), oTags);
        eEventStart := CAL.WA.vcal_str2date (xmlItem, sprintf ('IMC-VEVENT[%d]/DTSTART/', N), tzDict);
        eEventEnd := CAL.WA.vcal_str2date (xmlItem, sprintf ('IMC-VEVENT[%d]/DTEND/', N), tzDict);
        if (isnull (eEventEnd))
        {
          tmp := cast (xquery_eval (sprintf ('IMC-VEVENT[%d]/DURATION/val', N), xmlItem, 1) as varchar);
          eEventEnd := CAL.WA.p_dateadd (eEventStart, tmp);
        }
        event := case when (isnull (xquery_eval (sprintf ('IMC-VEVENT[%d]/DTSTART/VALUE', N), xmlItem, 1))) then 0 else 1 end;
        CAL.WA.vcal_str2recurrence (xmlItem, sprintf ('IMC-VEVENT[%d]/RRULE/fld', N), eRepeat, eRepeatParam1, eRepeatParam2, eRepeatParam3, eRepeatUntil);
        tmp := cast (xquery_eval (sprintf ('IMC-VEVENT[%d]/DALARM/val', N), xmlItem, 1) as varchar);
        eReminder := CAL.WA.vcal_str2reminder (xmlItem, sprintf ('IMC-VEVENT[%d]/IMC-VALARM/TRIGGER/', N));
        updated := CAL.WA.vcal_str2date (xmlItem, sprintf ('IMC-VEVENT[%d]/DTSTAMP/', N), tzDict);
        notes := cast (xquery_eval (sprintf ('IMC-VEVENT[%d]/NOTES/val', N), xmlItem, 1) as varchar);
        CAL.WA.event_update
          (
            id,
            uid,
            domain_id,
            subject,
            description,
            location,
            null,
            privacy,
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
            notes,
            updated
          );
      }
      }

      if (oTasks)
      {
      -- tasks (todo)
      nLength := xpath_eval('count (IMC-VTODO)', xmlItem);
      for (N := 1; N <= nLength; N := N + 1)
      {
        uid := cast (xquery_eval (sprintf ('IMC-VTODO[%d]/UID/val', N), xmlItem, 1) as varchar);
        id := coalesce ((select E_ID from CAL.WA.EVENTS where E_DOMAIN_ID = domain_id and E_UID = uid), -1);
        subject := cast (xquery_eval (sprintf ('IMC-VTODO[%d]/SUMMARY/val', N), xmlItem, 1) as varchar);
        description := cast (xquery_eval (sprintf ('IMC-VTODO[%d]/DESCRIPTION/val', N), xmlItem, 1) as varchar);
        privacy := CAL.WA.vcal_str2privacy (xmlItem, sprintf ('IMC-VTODO[%d]/CLASS/val', N));
        if (isnull (privacy))
          privacy := CAL.WA.domain_is_public (domain_id);
          eventTags := CAL.WA.tags_join (CAL.WA.vcal_str (xmlItem, sprintf ('IMC-VTODO[%d]/CATEGORIES/', N)), oTags);
        eEventStart := CAL.WA.vcal_str2date (xmlItem, sprintf ('IMC-VTODO[%d]/DTSTART/', N));
        eEventStart := CAL.WA.dt_join (eEventStart, CAL.WA.dt_timeEncode (12, 0));
        eEventEnd := CAL.WA.vcal_str2date (xmlItem, sprintf ('IMC-VTODO[%d]/DUE/', N));
        eEventEnd := CAL.WA.dt_join (eEventEnd, CAL.WA.dt_timeEncode (12, 0));
        priority := cast (xquery_eval (sprintf ('IMC-VTODO[%d]/PRIORITY/val', N), xmlItem, 1) as varchar);
        if (isnull (priority))
          priority := '3';
        status := CAL.WA.vcal_str2status (xmlItem, sprintf ('IMC-VTODO[%d]/STATUS/val', N));
        complete := cast (xquery_eval (sprintf ('IMC-VTODO[%d]/COMPLETE/val', N), xmlItem, 1) as varchar);
        completed := CAL.WA.vcal_str2date (xmlItem, sprintf ('IMC-VTODO[%d]/COMPLETED/', N));
        completed := CAL.WA.dt_join (completed, CAL.WA.dt_timeEncode (12, 0));
        updated := CAL.WA.vcal_str2date (xmlItem, sprintf ('IMC-VTODO[%d]/DTSTAMP/', N), tzDict);
        notes := cast (xquery_eval (sprintf ('IMC-VTODO[%d]/VOTES/val', N), xmlItem, 1) as varchar);
        CAL.WA.task_update
          (
            id,
            uid,
            domain_id,
            subject,
            description,
            null,
            privacy,
            eventTags,
            eEventStart,
            eEventEnd,
            priority,
            status,
            complete,
            completed,
            notes,
            updated
          );
      }
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
  in events any := null,
  in options any := null)
{
  declare tz integer;
  declare oEvents, oTasks, oPeriodFrom, oPeriodTo, oTagsInclude, oTagsExclude any;
  declare S, url, tzID, tzName varchar;
  declare sStream any;

  oEvents := 1;
  oTasks := 1;
  oPeriodFrom := null;
  oPeriodTo := null;
  oTagsInclude := null;
  oTagsExclude := null;
  if (not isnull (options))
  {
    oEvents := cast (get_keyword ('events', options, '0') as integer);
    oTasks := cast (get_keyword ('tasks', options, '0') as integer);
    oPeriodFrom := get_keyword ('periodFrom', options);
    oPeriodTo := get_keyword ('periodTo', options);
    oTagsInclude := get_keyword ('tagsInclude', options);
    oTagsExclude := get_keyword ('tagsExclude', options);
  }

  tz := CAL.WA.settings_timeZone2 (domain_id);
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
  if (oEvents)
  {
    for (select * from CAL.WA.EVENTS where E_DOMAIN_ID = domain_id and E_KIND = 0 and (events is null or CAL.WA.vector_contains (events, E_ID))) do
    {
      if (CAL.WA.dt_exchangeTest (oPeriodFrom, oPeriodTo, CAL.WA.event_gmt2user (E_EVENT_START, tz), CAL.WA.event_gmt2user (E_EVENT_END, tz), E_REPEAT_UNTIL) and CAL.WA.tags_exchangeTest (E_TAGS, oTagsInclude, oTagsExclude))
  {
	  http ('BEGIN:VEVENT\r\n', sStream);
    CAL.WA.export_vcal_line ('UID', E_UID, sStream);
    CAL.WA.export_vcal_line ('URL', url || cast (E_ID as varchar), sStream);
    CAL.WA.export_vcal_line ('DTSTAMP', CAL.WA.vcal_date2utc (now ()), sStream);
    CAL.WA.export_vcal_line ('CREATED', CAL.WA.vcal_date2utc (E_CREATED), sStream);
    CAL.WA.export_vcal_line ('LAST-MODIFIED', CAL.WA.vcal_date2utc (E_UPDATED), sStream);
    CAL.WA.export_vcal_line ('SUMMARY', E_SUBJECT, sStream);
    CAL.WA.export_vcal_line ('DESCRIPTION', E_DESCRIPTION, sStream);
    CAL.WA.export_vcal_line ('LOCATION', E_LOCATION, sStream);
    CAL.WA.export_vcal_line ('CATEGORIES', E_TAGS, sStream);
    if (E_EVENT)
    {
      CAL.WA.export_vcal_line ('DTSTART;VALUE=DATE', CAL.WA.vcal_date2str (CAL.WA.event_gmt2user (E_EVENT_START, tz)), sStream);
      CAL.WA.export_vcal_line ('DTEND;VALUE=DATE', CAL.WA.vcal_date2str (CAL.WA.event_gmt2user (E_EVENT_END, tz)), sStream);
    } else {
      CAL.WA.export_vcal_line (sprintf ('DTSTART;TZID=%s', tzID), CAL.WA.vcal_datetime2str (CAL.WA.event_gmt2user (E_EVENT_START, tz)), sStream);
      CAL.WA.export_vcal_line (sprintf ('DTEND;TZID=%s', tzID), CAL.WA.vcal_datetime2str (CAL.WA.event_gmt2user (E_EVENT_END, tz)), sStream);
    }
    CAL.WA.export_vcal_line ('RRULE', CAL.WA.vcal_recurrence2str (E_REPEAT, E_REPEAT_PARAM1, E_REPEAT_PARAM2, E_REPEAT_PARAM3, E_REPEAT_UNTIL), sStream);
    CAL.WA.export_vcal_reminder (E_REMINDER, sStream);
    CAL.WA.export_vcal_line ('NOTES', E_NOTES, sStream);
    CAL.WA.export_vcal_line ('CLASS', case when E_PRIVACY = 1 then 'PUBLIC' else 'PRIVATE' end, sStream);
	  http ('END:VEVENT\r\n', sStream);
	}
    }
  }

  -- tasks
  if (oTasks)
  {
    for (select * from CAL.WA.EVENTS where E_DOMAIN_ID = domain_id and E_KIND = 1 and ((events is null) or CAL.WA.vector_contains (events, E_ID))) do
    {
      if (CAL.WA.dt_exchangeTest (oPeriodFrom, oPeriodTo, CAL.WA.event_gmt2user (E_EVENT_START, tz), CAL.WA.event_gmt2user (E_EVENT_END, tz)) and CAL.WA.tags_exchangeTest (E_TAGS, oTagsInclude, oTagsExclude))
  {
	  http ('BEGIN:VTODO\r\n', sStream);
    CAL.WA.export_vcal_line ('UID', E_UID, sStream);
    CAL.WA.export_vcal_line ('URL', url || cast (E_ID as varchar), sStream);
    CAL.WA.export_vcal_line ('DTSTAMP', CAL.WA.vcal_date2utc (now ()), sStream);
    CAL.WA.export_vcal_line ('CREATED', CAL.WA.vcal_date2utc (E_CREATED), sStream);
    CAL.WA.export_vcal_line ('LAST-MODIFIED', CAL.WA.vcal_date2utc (E_UPDATED), sStream);
    CAL.WA.export_vcal_line ('SUMMARY', E_SUBJECT, sStream);
    CAL.WA.export_vcal_line ('DESCRIPTION', E_DESCRIPTION, sStream);
    CAL.WA.export_vcal_line ('CATEGORIES', E_TAGS, sStream);
    CAL.WA.export_vcal_line ('DTSTART;VALUE=DATE', CAL.WA.vcal_date2str (CAL.WA.dt_dateClear (CAL.WA.event_gmt2user (E_EVENT_START, tz))), sStream);
    CAL.WA.export_vcal_line ('DUE;VALUE=DATE', CAL.WA.vcal_date2str (CAL.WA.dt_dateClear (CAL.WA.event_gmt2user (E_EVENT_END, tz))), sStream);
    CAL.WA.export_vcal_line ('COMPLETED;VALUE=DATE', CAL.WA.vcal_date2str (CAL.WA.dt_dateClear (CAL.WA.event_gmt2user (E_COMPLETED, tz))), sStream);
    CAL.WA.export_vcal_line ('PRIORITY', E_PRIORITY, sStream);
    CAL.WA.export_vcal_line ('STATUS', E_STATUS, sStream);
    CAL.WA.export_vcal_line ('NOTES', E_NOTES, sStream);
    CAL.WA.export_vcal_line ('CLASS', case when E_PRIVACY = 1 then 'PUBLIC' else 'PRIVATE' end, sStream);
	  http ('END:VTODO\r\n', sStream);
	}
    }
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
  while (1)
  {
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
create procedure CAL.WA.upstream_scheduler ()
{
  declare cr static cursor for select UE_ID, UE_UPSTREAM_ID, UE_EVENT_ID, UE_EVENT_UID, UE_ACTION from CAL.WA.UPSTREAM_EVENT;

  declare id, upstream_id, enent_id, event_uid, action any;
  declare retValue, bm any;

  whenever not found goto _exit;

  open cr (exclusive);

  while (1)
  {
    fetch cr into id, upstream_id, enent_id, event_uid, action;
    retValue := CAL.WA.upstream_event_process (upstream_id, enent_id, event_uid, action);
    if (retValue = 1)
    {
      delete from CAL.WA.UPSTREAM_EVENT where UE_ID = id;
      commit work;
    }
  }

_exit:;
  close cr;
}
;

-----------------------------------------------------------------------------------------
--
create procedure CAL.WA.upstream_event_process (
  in upstream_id integer,
  in event_id integer,
  in event_uid varchar,
  in action varchar)
{
  declare exit handler for sqlstate '*'
  {
    CAL.WA.upstream_log_save (upstream_id, sprintf ('[%s] %s', __SQL_STATE, __SQL_MESSAGE));
    goto _exit;
  };

  for select U_URI, U_USER, U_PASSWORD from CAL.WA.UPSTREAM where U_ID = upstream_id do
  {
    declare retValue, rc, content, http_action any;

    content := CAL.WA.atom_entry (event_id, event_uid, action);
    http_action := 'PUT';
    if (action = 'U')
      http_action := 'POST';
    if (action = 'D')
      http_action := 'DELETE';

    commit work;
    http_get (U_URI, rc, http_action, CAL.WA.upstream_header (U_USER, U_PASSWORD), content);

    retValue := CAL.WA.upstream_response (rc);
    if ((action = 'D') and (retValue = 404))
      return 1;
    if ((retValue >= 200) and (retValue < 300))
      return 1;

    signal ('22023', trim (rc[0], '\r\n'), 'CA000');
  }

_exit:;
  return 0;
}
;

-----------------------------------------------------------------------------------------
--
create procedure CAL.WA.upstream_event_update (
  in domain_id integer,
  in event_id integer,
  in event_uid varchar,
  in event_tags varchar,
  in action varchar)
{
  declare id, upstream_id integer;

  for (select U_ID, U_INCLUDE, U_EXCLUDE from CAL.WA.UPSTREAM where U_DOMAIN_ID = domain_id) do
  {
    if (CAL.WA.tags_exchangeTest (event_tags, U_INCLUDE, U_EXCLUDE))
    {
    upstream_id := U_ID;
    id := (select UE_ID from CAL.WA.UPSTREAM_EVENT where UE_UPSTREAM_ID = upstream_id and UE_EVENT_ID = event_id and coalesce (UE_STATUS, 0) <> 1);
    if (isnull (id))
    {
      insert into CAL.WA.UPSTREAM_EVENT (UE_UPSTREAM_ID, UE_EVENT_ID, UE_EVENT_UID, UE_ACTION)
        values (upstream_id, event_id, event_uid, action);
    } else {
      update CAL.WA.UPSTREAM_EVENT
         set UE_ACTION = action
       where UE_ID = id;
    }
    }
  }
}
;

-----------------------------------------------------------------------------------------
--
create procedure CAL.WA.upstream_log_save (
  in upstream_id integer,
  in message varchar)
{
  declare logCount, id, N integer;

  insert into CAL.WA.UPSTREAM_LOG (UL_UPSTREAM_ID, UL_DT, UL_MESSAGE)
    values (upstream_id, now (), message);

  logCount := (select count(*) from CAL.WA.UPSTREAM_LOG where UL_UPSTREAM_ID = upstream_id) - 7;
  for (N := 0; N < logCount; N := N + 1)
  {
    id := (select TOP 1 UL_ID from CAL.WA.UPSTREAM_LOG where UL_UPSTREAM_ID = upstream_id order by UL_ID);
    delete from CAL.WA.UPSTREAM_LOG where UL_ID = id;
  }

  commit work;
}
;

-----------------------------------------------------------------------------------------
--
create procedure CAL.WA.uid ()
{
  return sprintf ('%s@%s', uuid (), sys_stat ('st_host_name'));
}
;

-----------------------------------------------------------------------------------------
--
create procedure CAL.WA.atom_uuid ()
{
  return 'urn:uuid:{' || uuid() || '}';
}
;

-----------------------------------------------------------------------------------------
--
create procedure CAL.WA.atom_entry (
  in event_id integer,
  in event_uid varchar,
  in action varchar)
{
   declare sStream any;

   sStream := string_output ();

   http ('<entry xmlns="http://www.w3.org/2005/Atom">', sStream);
   http (sprintf ('<id>%V</id>', CAL.WA.atom_uuid ()), sStream);
   http (sprintf ('<uid>%V</uid>', event_uid), sStream);
   if (action <> 'D')
   {
     for (select * from CAL.WA.EVENTS where E_ID = event_id) do
     {
       http (sprintf ('<title type="text">%V</title>', E_SUBJECT), sStream);
       http (sprintf ('<updated>%s</updated>', CAL.WA.dt_iso8601 (E_UPDATED)), sStream);
       http (sprintf ('<published>%s</published>', CAL.WA.dt_iso8601 (E_CREATED)), sStream);
       http (sprintf ('<content>%V</content>', CAL.WA.export_vcal (E_DOMAIN_ID, vector (event_id))), sStream);
     }
   }
   http ('</entry>', sStream);

   return string_output_string (sStream);
}
;

-----------------------------------------------------------------------------------------
--
create procedure CAL.WA.upstream_response (
  in hdr any)
{
  declare line, code varchar;

  if (hdr is null or __tag (hdr) <> 193)
    return (502);
  if (length (hdr) < 1)
    return (502);
  line := hdr [0];
  if (length (line) < 12)
    return (502);
  code := substring (line, strstr (line, 'HTTP/1.') + 9, length (line));
  while ((length (code) > 0) and (code[0] < ascii ('0') or code[0] > ascii ('9')))
  {
    code := substring (code, 2, length (code) - 1);
  }
  if (length (code) < 3)
    return (502);
  return atoi (substring (code, 1, 3));
}
;

-----------------------------------------------------------------------------------------
--
create procedure CAL.WA.upstream_header (
  in _user varchar,
  in _password varchar)
{
  return 'Authorization: Basic ' || encode_base64 (_user || ':' || _password) || '\r\nContent-Type: application/atom+xml';
}
;

-----------------------------------------------------------------------------------------
--
create procedure CAL.WA.gdata (
  in q varchar := null,
  in author varchar := null,
  in alt varchar := 'atom',
  in "updated-min" datetime := null,
  in "updated-max" datetime := null,
  in "start-index" int := 1,
  in "max-results" int := 10) __SOAP_HTTP 'text/xml'
{
  declare _domain_id, _user_id, _id, _unauthorized integer;
  declare _user, _password, _role, _uid varchar;
  declare _physical_path, _path, _action, _version varchar;
  declare _auth, _session, _method, _content_type, _options, _status, _content, _vCalendar, xt any;

  _physical_path := http_physical_path ();
  _path := split_and_decode (_physical_path, 0, '\0\0/');

  _domain_id := null;
  if (length (_path) > 4)
  {
    _domain_id := atoi (_path [4]);
  }
  _action := null;
  if (length (_path) > 5 and _path [5] <> '')
  {
    _action := _path [5];
  }
  _version := null;
  if (length (_path) > 6 and atoi (_action) > 0)
  {
    _version := atoi (_path [6]);
  }
  if (_domain_id is null)
  {
    _status := 'HTTP/1.1 404 Not Found';
    goto _exit;
  }

  _method := http_request_get ('REQUEST_METHOD');
  _content_type := http_request_header (http_request_header (), 'Content-Type');
  _options := http_map_get ('options');

  _auth := DB.DBA.vsp_auth_vec (http_request_header());
  _unauthorized := 0;
  if (_auth = 0)
  {
    _unauthorized := 1;
  } else {
  if (get_keyword ('authtype', _auth) <> 'basic')
    {
      _unauthorized := 1;
    } else {
  _user := get_keyword ('username', _auth, '');
  _password := get_keyword ('pass', _auth, '');
  if (not DB.DBA.web_user_password_check (_user, _password))
      {
        _unauthorized := 1;
      } else {
  _user_id := (select U_ID from DB.DBA.SYS_USERS where U_NAME = _user);
  _role := CAL.WA.access_role(_domain_id, _user_id);
  if (_role not in ('admin', 'owner'))
        {
          _unauthorized := 1;
        }
      }
    }
  }
  if (_method <> 'GET' and _unauthorized)
  {
    _status := 'HTTP/1.1 401 Unauthorized';
    goto _exit;
  }

  xt := null;
  if (_content_type in ('application/atom+xml', 'application/x.atom+xml', 'text/xml', 'application/xml'))
  {
    _content := string_output_string (http_body_read ());
    if (length (_content))
    {
      xt := xml_tree_doc (xml_tree (_content));
      xml_tree_doc_encoding (xt, 'utf-8');
    }
  }
    _status := 'HTTP/1.1 200 OK';
  if (_method = 'GET')
  {
    declare sStream any;

    sStream := string_output ();
    if (_action = 'intro')
    {
  	  http_header ('Content-Type: application/atomserv+xml; charset=UTF-8\r\n');

      http (         '<?xml version="1.0" encoding="utf-8"?>\n', sStream);
      http (         '<service xmlns="http://purl.org/atom/app#">\n', sStream);
      http (sprintf ('  <workspace title="%s" >\n', CAL.WA.domain_name (_domain_id)), sStream);
      http (sprintf ('    <collection title="%V Entries" href="%s" >\n', CAL.WA.domain_name (_domain_id), CAL.WA.atom_lpath2 (_domain_id)), sStream);
      http (         '    <member-type>entry</member-type>\n', sStream);
      http (         '    </collection>\n', sStream);
      http (         '  </workspace>\n', sStream);
      http (         '</service>', sStream);
    } else {
      http (         '<?xml version="1.0" encoding="UTF-8" ?>\n', sStream);
      http (         '<atom:feed xmlns:atom="http://www.w3.org/2005/Atom">\n', sStream);
      http (sprintf ('<atom:title>%V</atom:title>\n', CAL.WA.domain_name (_domain_id)), sStream);
      http (sprintf ('<atom:link href="%s" type="text/html" rel="alternate" />\n', CAL.WA.domain_sioc_url (_domain_id)), sStream);
      http (sprintf ('<atom:link href="%s" type="application/atom+xml" rel="self" />\n', CAL.WA.atom_lpath2 (_domain_id)), sStream);
      http (         '  <atom:author>\n', sStream);
      http (sprintf ('    <atom:name>%V</atom:name>\n', CAL.WA.account_name (CAL.WA.domain_owner_id (_domain_id))), sStream);
      http (sprintf ('    <atom:email>%V</atom:email>\n', CAL.WA.account_mail (CAL.WA.domain_owner_id (_domain_id))), sStream);
      http (         '  </atom:author>\n', sStream);
      http (sprintf ('<atom:updated>%s</atom:updated>\n', CAL.WA.dt_rfc1123(now ())), sStream);
      http (sprintf ('<atom:generator>%V</atom:generator>\n', 'Virtuoso Universal Server ' || sys_stat('st_dbms_ver')), sStream);
      http (         '</atom:feed>\n', sStream);
    }
    return string_output_string (sStream);
  }
  else
  {
    _uid := xpath_eval ('/entry/uid/text()', xt);
    _id := coalesce ((select E_ID from CAL.WA.EVENTS where E_DOMAIN_ID = _domain_id and E_UID = _uid), -1);

    if ((_method = 'PUT') or (_method = 'POST'))
    {
      _vCalendar := cast (xpath_eval ('/entry/content/text()', xt) as varchar);
      CAL.WA.import_vcal (_domain_id, _vCalendar);
    }
    if (_method = 'DELETE')
    {
      if (_id <> -1)
      {
        CAL.WA.event_delete (_id, _domain_id);
      } else {
        _status := 'HTTP/1.1 404 Not Found';
      }
    }
  }

_exit:;
  _content := http_body_read ();
  http_request_status (_status);
  return null;
}
;

grant execute on CAL.WA.gdata to SOAP_CALENDAR
;

-----------------------------------------------------------------------------------------
--
create procedure CAL.WA.discussion_check ()
{
  if (isnull (VAD_CHECK_VERSION ('Discussion')))
    return 0;
  return 1;
}
;

-----------------------------------------------------------------------------------------
--
-- NNTP Conversation
--
-----------------------------------------------------------------------------------------
create procedure CAL.WA.conversation_enable (
  in domain_id integer)
{
  return cast (get_keyword ('conv', CAL.WA.settings (domain_id), '0') as integer);
}
;

-----------------------------------------------------------------------------------------
--
create procedure CAL.WA.cm_root_node (
  in event_id varchar)
{
  declare root_id any;
  declare xt any;

  root_id := (select EC_ID from CAL.WA.EVENT_COMMENTS where EC_EVENT_ID = event_id and EC_PARENT_ID is null);
  xt := (select xmlagg (xmlelement ('node', xmlattributes (EC_ID as id, EC_ID as name, EC_EVENT_ID as post)))
           from CAL.WA.EVENT_COMMENTS
          where EC_EVENT_ID = event_id
            and EC_PARENT_ID = root_id
          order by EC_UPDATED);
  return xpath_eval ('//node', xt, 0);
}
;

-----------------------------------------------------------------------------------------
--
create procedure CAL.WA.cm_child_node (
  in event_id varchar,
  inout node any)
{
  declare parent_id int;
  declare xt any;

  parent_id := xpath_eval ('number (@id)', node);
  event_id := xpath_eval ('@post', node);

  xt := (select xmlagg (xmlelement ('node', xmlattributes (EC_ID as id, EC_ID as name, EC_EVENT_ID as post)))
           from CAL.WA.EVENT_COMMENTS
          where EC_EVENT_ID = event_id and EC_PARENT_ID = parent_id order by EC_UPDATED);
  return xpath_eval ('//node', xt, 0);
}
;

-----------------------------------------------------------------------------------------
--
create procedure CAL.WA.make_rfc_id (
  in event_id integer,
  in comment_id integer := null)
{
  declare hashed, host any;

  hashed := md5 (uuid ());
  host := sys_stat ('st_host_name');
  if (isnull (comment_id))
    return sprintf ('<%d.%s@%s>', event_id, hashed, host);
  return sprintf ('<%d.%d.%s@%s>', event_id, comment_id, hashed, host);
}
;

-----------------------------------------------------------------------------------------
--
create procedure CAL.WA.make_mail_subject (
  in txt any,
  in id varchar := null)
{
  declare enc any;

  enc := encode_base64 (CAL.WA.wide2utf (txt));
  enc := replace (enc, '\r\n', '');
  txt := concat ('Subject: =?UTF-8?B?', enc, '?=\r\n');
  if (not isnull (id))
    txt := concat (txt, 'X-Virt-NewsID: ', uuid (), ';', id, '\r\n');
  return txt;
}
;

-----------------------------------------------------------------------------------------
--
create procedure CAL.WA.make_post_rfc_header (
  in mid varchar,
  in refs varchar,
  in gid varchar,
  in title varchar,
  in rec datetime,
  in author_mail varchar)
{
  declare ses any;

  ses := string_output ();
  http (CAL.WA.make_mail_subject (title), ses);
  http (sprintf ('Date: %s\r\n', DB.DBA.date_rfc1123 (rec)), ses);
  http (sprintf ('Message-Id: %s\r\n', mid), ses);
  if (not isnull (refs))
    http (sprintf ('References: %s\r\n', refs), ses);
  http (sprintf ('From: %s\r\n', author_mail), ses);
  http ('Content-Type: text/html; charset=UTF-8\r\n', ses);
  http (sprintf ('Newsgroups: %s\r\n\r\n', gid), ses);
  ses := string_output_string (ses);
  return ses;
}
;

-----------------------------------------------------------------------------------------
--
create procedure CAL.WA.make_post_rfc_msg (
  inout head varchar,
  inout body varchar,
  in tree int := 0)
{
  declare ses any;

  ses := string_output ();
  http (head, ses);
  http (body, ses);
  http ('\r\n.\r\n', ses);
  ses := string_output_string (ses);
  if (tree)
    ses := serialize (mime_tree (ses));
  return ses;
}
;

-----------------------------------------------------------------------------------------
--
create procedure CAL.WA.nntp_root (
  in domain_id integer,
  in event_id integer)
{
  declare owner_id integer;
  declare name, mail, title, comment any;

  owner_id := CAL.WA.domain_owner_id (domain_id);
  name := CAL.WA.account_fullName (owner_id);
  mail := CAL.WA.account_mail (owner_id);

  select E_SUBJECT, E_DESCRIPTION into title, comment from CAL.WA.EVENTS where E_ID = event_id;
  insert into CAL.WA.EVENT_COMMENTS (EC_PARENT_ID, EC_DOMAIN_ID, EC_EVENT_ID, EC_TITLE, EC_COMMENT, EC_U_NAME, EC_U_MAIL, EC_CREATED, EC_UPDATED)
    values (null, domain_id, event_id, title, comment, name, mail, now (), now ());
}
;

-----------------------------------------------------------------------------------------
--
create procedure CAL.WA.nntp_update_item (
  in domain_id integer,
  in event_id integer)
{
  declare grp, ngnext integer;
  declare nntpName, rfc_id varchar;

  nntpName := CAL.WA.domain_nntp_name (domain_id);
  select NG_GROUP, NG_NEXT_NUM into grp, ngnext from DB..NEWS_GROUPS where NG_NAME = nntpName;
  select EC_RFC_ID into rfc_id from CAL.WA.EVENT_COMMENTS where EC_DOMAIN_ID = domain_id and EC_EVENT_ID = event_id and EC_PARENT_ID is null;
  if (exists (select 1 from DB.DBA.NEWS_MULTI_MSG where NM_KEY_ID = rfc_id and NM_GROUP = grp))
    return;

  if (ngnext < 1)
    ngnext := 1;

  for (select EC_RFC_ID as rfc_id from CAL.WA.EVENT_COMMENTS where EC_DOMAIN_ID = domain_id and EC_EVENT_ID = event_id) do
  {
    insert soft DB.DBA.NEWS_MULTI_MSG (NM_KEY_ID, NM_GROUP, NM_NUM_GROUP) values (rfc_id, grp, ngnext);
    ngnext := ngnext + 1;
  }

  set triggers off;
  update DB.DBA.NEWS_GROUPS set NG_NEXT_NUM = ngnext + 1 where NG_NAME = nntpName;
  DB.DBA.ns_up_num (grp);
  set triggers on;
}
;

-----------------------------------------------------------------------------------------
--
create procedure CAL.WA.nntp_update (
  in domain_id integer,
  in oInstance varchar,
  in nInstance varchar,
  in oConversation integer := null,
  in nConversation integer := null)
{
  declare nntpGroup integer;
  declare nDescription varchar;

  if (isnull (oInstance))
    oInstance := CAL.WA.domain_nntp_name (domain_id);

  if (isnull (nInstance))
    nInstance := CAL.WA.domain_nntp_name (domain_id);

  nDescription := CAL.WA.domain_description (domain_id);

  if (isnull (nConversation))
  {
    update DB.DBA.NEWS_GROUPS
      set NG_POST = 1,
          NG_NAME = nInstance,
          NG_DESC = nDescription
    where NG_NAME = oInstance;
    return;
  }

  if (oConversation = 1 and nConversation = 0)
  {
    nntpGroup := (select NG_GROUP from DB.DBA.NEWS_GROUPS where NG_NAME = oInstance);
    delete from DB.DBA.NEWS_MULTI_MSG where NM_GROUP = nntpGroup;
    delete from DB.DBA.NEWS_GROUPS where NG_NAME = oInstance;
  }
  else if (oConversation = 0 and nConversation = 1)
  {
    declare exit handler for sqlstate '*' { return; };

    insert into DB.DBA.NEWS_GROUPS (NG_NEXT_NUM, NG_NAME, NG_DESC, NG_SERVER, NG_POST, NG_UP_TIME, NG_CREAT, NG_UP_INT, NG_PASS, NG_UP_MESS, NG_NUM, NG_FIRST, NG_LAST, NG_LAST_OUT, NG_CLEAR_INT, NG_TYPE)
      values (0, nInstance, nDescription, null, 1, now(), now(), 30, 0, 0, 0, 0, 0, 0, 120, 'CALENDAR');
  }
}
;

-----------------------------------------------------------------------------------------
--
create procedure CAL.WA.nntp_fill (
  in domain_id integer)
{
  declare exit handler for SQLSTATE '*', not found {
    return;
  };

  declare grp, ngnext integer;
  declare nntpName varchar;

  for (select E_ID from CAL.WA.EVENTS where E_DOMAIN_ID = domain_id) do
  {
    if (not exists (select 1 from CAL.WA.EVENT_COMMENTS where EC_DOMAIN_ID = domain_id and EC_EVENT_ID = E_ID and EC_PARENT_ID is null))
      CAL.WA.nntp_root (domain_id, E_ID);
  }
  nntpName := CAL.WA.domain_nntp_name (domain_id);
  select NG_GROUP, NG_NEXT_NUM into grp, ngnext from DB..NEWS_GROUPS where NG_NAME = nntpName;
  if (ngnext < 1)
    ngnext := 1;

  for (select EC_RFC_ID as rfc_id from CAL.WA.EVENT_COMMENTS where EC_DOMAIN_ID = domain_id) do
  {
    insert soft DB.DBA.NEWS_MULTI_MSG (NM_KEY_ID, NM_GROUP, NM_NUM_GROUP) values (rfc_id, grp, ngnext);
    ngnext := ngnext + 1;
  }

  set triggers off;
  update DB.DBA.NEWS_GROUPS set NG_NEXT_NUM = ngnext + 1 where NG_NAME = nntpName;
  DB.DBA.ns_up_num (grp);
  set triggers on;
}
;

-----------------------------------------------------------------------------------------
--
create procedure CAL.WA.mail_address_split (
  in author any,
  out person any,
  out email any)
{
  declare pos int;

  person := '';
  pos := strchr (author, '<');
  if (pos is not NULL)
  {
    person := "LEFT" (author, pos);
    email := subseq (author, pos, length (author));
    email := replace (email, '<', '');
    email := replace (email, '>', '');
    person := trim (replace (person, '"', ''));
  } else {
    pos := strchr (author, '(');
    if (pos is not NULL)
    {
      email := trim ("LEFT" (author, pos));
      person :=  subseq (author, pos, length (author));
      person := replace (person, '(', '');
      person := replace (person, ')', '');
    }
  }
}
;

-----------------------------------------------------------------------------------------
--
create procedure CAL.WA.nntp_decode_subject (
  inout str varchar)
{
  declare match varchar;
  declare inx int;

  inx := 50;

  str := replace (str, '\t', '');

  match := regexp_match ('=\\?[^\\?]+\\?[A-Z]\\?[^\\?]+\\?=', str);
  while (match is not null and inx > 0)
  {
    declare enc, ty, dat, tmp, cp, dec any;

    cp := match;
    tmp := regexp_match ('^=\\?[^\\?]+\\?[A-Z]\\?', match);

    match := substring (match, length (tmp)+1, length (match) - length (tmp) - 2);

    enc := regexp_match ('=\\?[^\\?]+\\?', tmp);

    tmp := replace (tmp, enc, '');

    enc := trim (enc, '?=');
    ty := trim (tmp, '?');

    if (ty = 'B')
    {
      dec := decode_base64 (match);
    } else if (ty = 'Q') {
      dec := uudecode (match, 12);
    } else {
      dec := '';
    }
    declare exit handler for sqlstate '2C000' { return;};
    dec := charset_recode (dec, enc, 'UTF-8');

    str := replace (str, cp, dec);

    match := regexp_match ('=\\?[^\\?]+\\?[A-Z]\\?[^\\?]+\\?=', str);
    inx := inx - 1;
  }
}
;

-----------------------------------------------------------------------------------------
--
create procedure CAL.WA.nntp_process_parts (
  in parts any,
  inout body varchar,
  inout amime any,
  out result any,
  in any_part int)
{
  declare name1, mime1, name, mime, enc, content, charset varchar;
  declare i, i1, l1, is_allowed int;
  declare part any;

  if (not isarray (result))
    result := vector ();

  if (not isarray (parts) or not isarray (parts[0]))
    return 0;

  part := parts[0];

  name1 := get_keyword_ucase ('filename', part, '');
  if (name1 = '')
    name1 := get_keyword_ucase ('name', part, '');

  mime1 := get_keyword_ucase ('Content-Type', part, '');
  charset := get_keyword_ucase ('charset', part, '');

  if (mime1 = 'application/octet-stream' and name1 <> '')
    mime1 := http_mime_type (name1);

  is_allowed := 0;
  i1 := 0;
  l1 := length (amime);
  while (i1 < l1)
  {
    declare elm any;
    elm := trim(amime[i1]);
    if (mime1 like elm)
    {
      is_allowed := 1;
      i1 := l1;
    }
    i1 := i1 + 1;
  }

  declare _cnt_disp any;
  _cnt_disp := get_keyword_ucase('Content-Disposition', part, '');

  if (is_allowed and (any_part or (name1 <> '' and _cnt_disp in ('attachment', 'inline'))))
  {
    name := name1;
    mime := mime1;
    enc := get_keyword_ucase ('Content-Transfer-Encoding', part, '');
    content := subseq (body, parts[1][0], parts[1][1]);
    if (enc = 'base64')
      content := decode_base64 (content);
    result := vector_concat (result, vector (vector (name, mime, content, _cnt_disp, enc, charset)));
    return 1;
  }

  -- process the parts
  if (isarray (parts[2]))
    for (i := 0; i < length (parts[2]); i := i + 1)
      CAL.WA.nntp_process_parts (parts[2][i], body, amime, result, any_part);

  return 0;
}
;

-----------------------------------------------------------------------------------------
--
DB.DBA.NNTP_NEWS_MSG_ADD (
'CALENDAR',
'select
   \'CALENDAR\',
   EC_RFC_ID,
   EC_RFC_REFERENCES,
   0,    -- NM_READ
   null,
   EC_UPDATED,
   0,    -- NM_STAT
   null, -- NM_TRY_POST
   0,    -- NM_DELETED
   CAL.WA.make_post_rfc_msg (EC_RFC_HEADER, EC_COMMENT, 1), -- NM_HEAD
   CAL.WA.make_post_rfc_msg (EC_RFC_HEADER, EC_COMMENT),
   EC_ID
 from CAL.WA.EVENT_COMMENTS'
)
;

-----------------------------------------------------------------------------------------
--
create procedure DB.DBA.CALENDAR_NEWS_MSG_I (
  inout N_NM_ID any,
  inout N_NM_REF any,
  inout N_NM_READ any,
  inout N_NM_OWN any,
  inout N_NM_REC_DATE any,
  inout N_NM_STAT any,
  inout N_NM_TRY_POST any,
  inout N_NM_DELETED any,
  inout N_NM_HEAD any,
  inout N_NM_BODY any)
{
  declare uid, parent_id, domain_id, item_id any;
  declare author, name, mail, tree, head, contentType, content, subject, title, cset any;
  declare rfc_id, rfc_header, rfc_references, refs any;

  uid := connection_get ('nntp_uid');
  if (isnull (N_NM_REF) and isnull (uid))
    signal ('CONVA', 'The post cannot be done via news client, this requires authentication.');

  tree := deserialize (N_NM_HEAD);
  head := tree [0];
  contentType := get_keyword_ucase ('Content-Type', head, 'text/plain');
  cset  := upper (get_keyword_ucase ('charset', head));
  author :=  get_keyword_ucase ('From', head, 'nobody@unknown');
  subject :=  get_keyword_ucase ('Subject', head);

  if (not isnull (subject))
    CAL.WA.nntp_decode_subject (subject);

  if (contentType like 'text/%')
  {
    declare st, en int;
    declare last any;

    st := tree[1][0];
    en := tree[1][1];

    if (en > st + 5) {
      last := subseq (N_NM_BODY, en - 4, en);
      if (last = '\r\n.\r')
        en := en - 4;
    }
    content := subseq (N_NM_BODY, st, en);
    if (cset is not null and cset <> 'UTF-8')
    {
      declare exit handler for sqlstate '2C000' { goto next_1;};
      content := charset_recode (content, cset, 'UTF-8');
    }
  next_1:;
    if (contentType = 'text/plain')
      content := '<pre>' || content || '</pre>';
  }
  else if (contentType like 'multipart/%')
  {
    declare res, best_cnt any;

    declare exit handler for sqlstate '*' {  signal ('CONVX', __SQL_MESSAGE);};

    CAL.WA.nntp_process_parts (tree, N_NM_BODY, vector ('text/%'), res, 1);

    best_cnt := null;
    content := null;
    foreach (any elm in res) do
    {
      if (elm[1] = 'text/html' and (content is null or best_cnt = 'text/plain'))
      {
        best_cnt := 'text/html';
        content := elm[2];
        if (elm[4] = 'quoted-printable')
        {
          content := uudecode (content, 12);
        } else if (elm[4] = 'base64') {
          content := decode_base64 (content);
        }
        cset := elm[5];
      } else if (best_cnt is null and elm[1] = 'text/plain') {
        content := elm[2];
        best_cnt := 'text/plain';
        cset := elm[5];
      }
      if (elm[1] not like 'text/%')
        signal ('CONVX', sprintf ('The post contains parts of type [%s] which is prohibited.', elm[1]));
    }
    if (length (cset) and cset <> 'UTF-8')
    {
      declare exit handler for sqlstate '2C000' { goto next_2;};
      content := charset_recode (content, cset, 'UTF-8');
    }
  next_2:;
  } else
    signal ('CONVX', sprintf ('The content type [%s] is not supported', contentType));

  rfc_header := '';
  for (declare i int, i := 0; i < length (head); i := i + 2)
  {
    if (lower (head[i]) <> 'content-type' and lower (head[i]) <> 'mime-version' and lower (head[i]) <> 'boundary'  and lower (head[i]) <> 'subject')
      rfc_header := rfc_header || head[i] ||': ' || head[i + 1]||'\r\n';
  }
  rfc_header := CAL.WA.make_mail_subject (subject) || rfc_header || 'Content-Type: text/html; charset=UTF-8\r\n\r\n';

  rfc_references := N_NM_REF;

  if (not isnull (N_NM_REF))
  {
    declare exit handler for not found { signal ('CONV1', 'No such article.');};

    parent_id := null;
    refs := split_and_decode (N_NM_REF, 0, '\0\0 ');
    if (length (refs))
      N_NM_REF := refs[length (refs) - 1];

    select EC_ID, EC_DOMAIN_ID, EC_EVENT_ID, EC_TITLE
      into parent_id, domain_id, item_id, title
      from CAL.WA.EVENT_COMMENTS
     where EC_RFC_ID = N_NM_REF;

    if (isnull (subject))
      subject := 'Re: '|| title;

    CAL.WA.mail_address_split (author, name, mail);

    insert into CAL.WA.EVENT_COMMENTS (EC_PARENT_ID, EC_DOMAIN_ID, EC_EVENT_ID, EC_TITLE, EC_COMMENT, EC_U_NAME, EC_U_MAIL, EC_UPDATED, EC_RFC_ID, EC_RFC_HEADER, EC_RFC_REFERENCES)
      values (parent_id, domain_id, item_id, subject, content, name, mail, N_NM_REC_DATE, N_NM_ID, rfc_header, rfc_references);
  }
}
;

-----------------------------------------------------------------------------------------
--
create procedure DB.DBA.CALENDAR_NEWS_MSG_U (
  inout O_NM_ID any,
  inout N_NM_ID any,
  inout N_NM_REF any,
  inout N_NM_READ any,
  inout N_NM_OWN any,
  inout N_NM_REC_DATE any,
  inout N_NM_STAT any,
  inout N_NM_TRY_POST any,
  inout N_NM_DELETED any,
  inout N_NM_HEAD any,
  inout N_NM_BODY any)
{
  return;
}
;

-----------------------------------------------------------------------------------------
--
create procedure DB.DBA.CALENDAR_NEWS_MSG_D (
  inout O_NM_ID any)
{
  signal ('CONV3', 'Delete of a Person comment is not allowed');
}
;

-----------------------------------------------------------------------------------------
--
create procedure CAL.WA.news_comment_get_mess_attachments (inout _data any, in get_uuparts integer)
{
  declare data, outp, _all any;
  declare line varchar;
  declare in_UU, get_body integer;

  data := string_output (http_strses_memory_size ());
  http (_data, data);
  http ('\n', data);
  _all := vector ();

  outp := string_output (http_strses_memory_size ());

  in_UU := 0;
  get_body := 1;
  while (1 = 1)
  {
    line := ses_read_line (data, 0);

    if (line is null or isstring (line) = 0)
    {
      if (length (_all) = 0)
      {
        _all := vector_concat (_all, vector (string_output_string (outp)));
      }
      return _all;
    }
    if (in_UU = 0 and subseq (line, 0, 6) = 'begin ' and length (line) > 6)
    {
      in_UU := 1;
      if (get_body)
      {
        get_body := 0;
        _all := vector_concat (_all, vector (string_output_string (outp)));
        http_output_flush (outp);
      }
      _all := vector_concat (_all, vector (subseq (line, 10)));
    }
    else if (in_UU = 1 and subseq (line, 0, 3) = 'end')
    {
      in_UU := 0;
      if (get_uuparts)
      {
        _all := vector_concat (_all, vector (string_output_string (outp)));
        http_output_flush (outp);
      }
    }
    else if ((get_uuparts and in_UU = 1) or get_body)
    {
      http (line, outp);
      http ('\n', outp);
    }
  }
  return _all;
}
;

-----------------------------------------------------------------------------------------
--
create procedure CAL.WA.news_comment_get_cn_type (in f_name varchar)
{
  declare ext varchar;
  declare temp any;

  ext := 'text/html';
  temp := split_and_decode (f_name, 0, '\0\0.');

  if (length (temp) < 2)
    return ext;

  temp := temp[1];

  if (exists (select 1 from WS.WS.SYS_DAV_RES_TYPES where T_EXT = temp))
	  ext := ((select T_TYPE from WS.WS.SYS_DAV_RES_TYPES where T_EXT = temp));

  return ext;
}
;
