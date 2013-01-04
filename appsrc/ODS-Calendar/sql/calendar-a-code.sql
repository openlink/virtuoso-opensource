--
--  $Id$
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2013 OpenLink Software
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
-- ACL Functions
--
-------------------------------------------------------------------------------
--
create procedure CAL.WA.acl_condition (
  in domain_id integer,
  in id integer := null)
{
  if (not is_https_ctx ())
    return 0;

  if (exists (select 1 from DB.DBA.WA_INSTANCE where WAI_ID = domain_id and WAI_ACL is not null))
    return 1;

  if (exists (select 1 from CAL.WA.EVENTS where E_ID = id and E_ACL is not null))
    return 1;

  return 0;
}
;

-------------------------------------------------------------------------------
--
create procedure CAL.WA.acl_check (
  in domain_id integer,
  in id integer := null)
{
  declare rc varchar;
  declare graph_iri, groups_iri, acl_iris any;

  rc := '';
  if (CAL.WA.acl_condition (domain_id, id))
  {
    acl_iris := vector (CAL.WA.forum_iri (domain_id));
    if (not isnull (id))
      acl_iris := vector (SIOC..calendar_event_iri (domain_id, id), CAL.WA.forum_iri (domain_id));

    graph_iri := CAL.WA.acl_graph (domain_id);
    groups_iri := SIOC..acl_groups_graph (CAL.WA.domain_owner_id (domain_id));
    rc := SIOC..acl_check (graph_iri, groups_iri, acl_iris);
  }
  return rc;
}
;

-------------------------------------------------------------------------------
--
create procedure CAL.WA.acl_list (
  in domain_id integer)
{
  declare graph_iri, groups_iri, iri any;

  iri := CAL.WA.forum_iri (domain_id);
  graph_iri := CAL.WA.acl_graph (domain_id);
  groups_iri := SIOC..acl_groups_graph (CAL.WA.domain_owner_id (domain_id));
  return SIOC..acl_list (graph_iri, groups_iri, iri);
}
;

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
  {
    domain_id := get_keyword ('domain', options);
  }
  if (is_empty_or_null (domain_id))
  {
    aPath := split_and_decode (trim (http_path (), '/'), 0, '\0\0/');
    domain_id := cast(aPath[1] as integer);
  }
  if (not exists (select 1 from DB.DBA.WA_INSTANCE where WAI_ID = domain_id and WAI_TYPE_NAME = 'Calendar'))
    domain_id := -1;

_end:;
  return cast (domain_id as integer);
}
;

-------------------------------------------------------------------------------
--
create procedure CAL.WA.session_restore (
  inout params any)
{
  declare domain_id, account_id, account_rights any;

  domain_id := CAL.WA.session_domain (params);
  account_id := -1;

  for (select U.U_ID,
              U.U_NAME,
              U.U_FULL_NAME
         from DB.DBA.VSPX_SESSION S,
              WS.WS.SYS_DAV_USER U
        where S.VS_REALM = get_keyword ('realm', params, 'wa')
          and S.VS_SID   = get_keyword ('sid', params, '')
          and S.VS_UID   = U.U_NAME) do
  {
    account_id := U_ID;
  }
  account_rights := CAL.WA.access_rights (domain_id, account_id);
  return vector (
                 'domain_id', domain_id,
                 'account_id',   account_id,
                 'account_rights', account_rights
               );
}
;

-------------------------------------------------------------------------------
--
-- Freeze Functions
--
-------------------------------------------------------------------------------
create procedure CAL.WA.frozen_check (
  in domain_id integer)
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
create procedure CAL.WA.frozen_page (
  in domain_id integer)
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
  in user_id integer)
{
  declare group_id integer;

  if ((user_id = 0) or (user_id = http_dav_uid ()))
    return 1;

  group_id := (select U_GROUP from SYS_USERS where U_ID = user_id);
  if ((group_id = 0) or (group_id = http_dav_uid ()) or (group_id = http_dav_uid()+1))
    return 1;

  return 0;
}
;

-------------------------------------------------------------------------------
--
create procedure CAL.WA.check_grants (
  in role_name varchar,
  in page_name varchar)
{
  return case when isnull (role_name) then 0 else 1 end;
}
;

-------------------------------------------------------------------------------
--
create procedure CAL.WA.access_rights (
  in domain_id integer,
  in account_id integer)
{
  declare rc varchar;

  if (domain_id <= 0)
    return null;

  if (CAL.WA.check_admin (account_id))
    return 'W';

  if (exists (select 1
               from SYS_USERS A,
                    WA_MEMBER B,
                    WA_INSTANCE C
               where A.U_ID = account_id
                and B.WAM_USER = A.U_ID
                 and B.WAM_MEMBER_TYPE = 1
                and B.WAM_INST = C.WAI_NAME
                 and C.WAI_ID = domain_id))
    return 'W';

  if (exists (select 1
                from SYS_USERS A,
                     WA_MEMBER B,
                     WA_INSTANCE C
               where A.U_ID = account_id
                 and B.WAM_USER = A.U_ID
                 and B.WAM_MEMBER_TYPE = 2
                 and B.WAM_INST = C.WAI_NAME
                 and C.WAI_ID = domain_id))
    return 'W';

  if (is_https_ctx ())
  {
    rc := CAL.WA.acl_check (domain_id);
    if (rc <> '')
      return rc;
  }

  if (exists (select 1
                from SYS_USERS A,
                     WA_MEMBER B,
                     WA_INSTANCE C
               where A.U_ID = account_id
                 and B.WAM_USER = A.U_ID
                 and B.WAM_INST = C.WAI_NAME
                 and C.WAI_ID = domain_id))
    return 'R';

  if (exists (select 1
                from DB.DBA.WA_INSTANCE
               where WAI_ID = domain_id
                 and WAI_IS_PUBLIC = 1))
    return 'R';

  if (is_https_ctx () and exists (select 1 from CAL.WA.acl_list (id)(iri varchar) x where x.id = domain_id))
    return '';

  return null;
}
;

-------------------------------------------------------------------------------
--
create procedure CAL.WA.access_is_write (
  in access_role varchar)
{
  if (access_role = 'W')
  return 1;

  return 0;
}
;

-------------------------------------------------------------------------------
--
create procedure CAL.WA.wa_home_link ()
{
  return case when cast (registry_get ('wa_home_link') as varchar) = '0' then '/ods/' else registry_get ('wa_home_link') end;
}
;

-------------------------------------------------------------------------------
--
create procedure CAL.WA.wa_home_title ()
{
  return case when cast (registry_get ('wa_home_title') as varchar) = '0' then 'ODS Home' else registry_get ('wa_home_title') end;
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
create procedure CAL.WA.iri_fix (
  in S varchar)
{
  if (is_https_ctx ())
  {
    declare V any;

    V := rfc1808_parse_uri (cast (S as varchar));
    V [0] := 'https';
    V [1] := http_request_header (http_request_header(), 'Host', null, registry_get ('URIQADefaultHost'));
    S := DB.DBA.vspx_uri_compose (V);
  }
  return S;
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
create procedure CAL.WA.url_schema_fix (
  in S varchar)
{
  declare schemas any;

  schemas := vector ('feed://', 'webcal://');
  foreach (any aSchema in schemas) do
  {
    if (S like (aSchema || '%'))
      return 'http://' || subseq (S, length (aSchema));
  }
  return S;
}
;

-------------------------------------------------------------------------------
--
create procedure CAL.WA.exec (
  in S varchar,
  in P any := null)
{
  declare st, msg, meta, rows any;

  st := '00000';
  exec (S, st, msg, P, 0, meta, rows);
  if ('00000' = st)
    return rows;
  return vector ();
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
  http ('  XMLELEMENT(\'managingEditor\', CAL.WA.utf2wide (U_FULL_NAME || \' <\' || U_E_MAIL || \'>\')), \n', retValue);
  http ('  XMLELEMENT(\'pubDate\', CAL.WA.dt_rfc1123(now ())), \n', retValue);
  http ('  XMLELEMENT(\'generator\', \'Virtuoso Universal Server \' || sys_stat(\'st_dbms_ver\')), \n', retValue);
  http ('  XMLELEMENT(\'webMaster\', U_E_MAIL), \n', retValue);
  http ('  XMLELEMENT(\'link\', CAL.WA.calendar_url (<DOMAIN_ID>)), \n', retValue);
  http ('  (select XMLAGG (XMLELEMENT(\'http://www.w3.org/2005/Atom:link\', XMLATTRIBUTES (SH_URL as "href", \'hub\' as "rel", \'PubSubHub\' as "title"))) from ODS.DBA.SVC_HOST, ODS.DBA.APP_PING_REG where SH_PROTO = \'PubSubHub\' and SH_ID = AP_HOST_ID and AP_WAI_ID = <DOMAIN_ID>), \n', retValue);
  http ('  XMLELEMENT(\'language\', \'en-us\') \n', retValue);
  http ('from DB.DBA.SYS_USERS where U_ID = <USER_ID> \n', retValue);
  http (']]></sql:sqlx>\n', retValue);

  http ('<sql:sqlx xmlns:sql=\'urn:schemas-openlink-com:xml-sql\'><![CDATA[\n', retValue);
  http ('select \n', retValue);
  http ('  XMLAGG(XMLELEMENT(\'item\', \n', retValue);
  http ('    XMLELEMENT(\'title\', CAL.WA.utf2wide (E_SUBJECT)), \n', retValue);
  http ('    XMLELEMENT(\'description\', CAL.WA.utf2wide (E_DESCRIPTION)), \n', retValue);
  http ('    XMLELEMENT(\'guid\', E_ID), \n', retValue);
  http ('    XMLELEMENT(\'link\', CAL.WA.event_url (<DOMAIN_ID>, E_ID)), \n', retValue);
  http ('    XMLELEMENT(\'pubDate\', CAL.WA.dt_rfc1123 (E_CREATED)), \n', retValue);
  http ('    (select XMLAGG (XMLELEMENT (\'category\', TV_TAG)) from CAL..TAGS_VIEW where tags = E_TAGS), \n', retValue);
  http ('    XMLELEMENT(\'http://www.openlinksw.com/ods/:modified\', CAL.WA.dt_iso8601 (E_UPDATED)))) \n', retValue);
  http ('from (select top 15  \n', retValue);
  http ('        E_SUBJECT, \n', retValue);
  http ('        E_DESCRIPTION, \n', retValue);
  http ('        E_UPDATED, \n', retValue);
  http ('        E_CREATED, \n', retValue);
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
  home := home || 'Gems/';
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
  in appName varchar := 'Gems',
  in appGems varchar := null)
{
  declare tmp, home, appHome, path varchar;

  if (isnull (account_id))
    account_id := CAL.WA.domain_owner_id (domain_id);

  home := CAL.WA.dav_home (account_id);
  if (isnull (home))
    return;

  if (isnull (appGems))
    appGems := CAL.WA.domain_gems_name (domain_id);
  appHome := home || appName || '/';
  home := appHome || appGems || '/';

  path := home || 'Calendar.rss';
  DB.DBA.DAV_DELETE_INT (path, 1, null, null, 0);
  path := home || 'Calendar.rdf';
  DB.DBA.DAV_DELETE_INT (path, 1, null, null, 0);
  path := home || 'Calendar.atom';
  DB.DBA.DAV_DELETE_INT (path, 1, null, null, 0);
  path := home || 'Calendar.comment';
  DB.DBA.DAV_DELETE_INT (path, 1, null, null, 0);

  declare auth_username, auth_password varchar;

  auth_username := coalesce((SELECT U_NAME FROM WS.WS.SYS_DAV_USER WHERE U_ID = account_id), '');
  auth_password := coalesce((SELECT U_PWD FROM WS.WS.SYS_DAV_USER WHERE U_ID = account_id), '');
  if (auth_password[0] = 0)
    auth_password := pwd_magic_calc (auth_username, auth_password, 1);

  tmp := DB.DBA.DAV_DIR_LIST (home, 0, auth_username, auth_password);
  if (not isinteger(tmp) and not length (tmp))
    DB.DBA.DAV_DELETE_INT (home, 1, null, null, 0);

  tmp := DB.DBA.DAV_DIR_LIST (appHome, 0, auth_username, auth_password);
  if (not isinteger(tmp) and not length (tmp))
    DB.DBA.DAV_DELETE_INT (appHome, 1, null, null, 0);

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
  CAL.WA.domain_gems_delete (domain_id, account_id, 'Calendar Gems');
  CAL.WA.domain_gems_create (domain_id, account_id);

  declare home, path varchar;
  home := CAL.WA.dav_home (account_id);
  path := home || 'Calendar' || '/' || concat(CAL.WA.domain_name(domain_id), '_Gems') || '/';
  DB.DBA.DAV_DELETE_INT (path || 'Calendar.rss', 1, null, null, 0);
  DB.DBA.DAV_DELETE_INT (path || 'Calendar.atom', 1, null, null, 0);
  DB.DBA.DAV_DELETE_INT (path || 'Calendar.rdf', 1, null, null, 0);
  DB.DBA.DAV_DELETE_INT (path || 'Calendar.comment', 1, null, null, 0);

  declare auth_password varchar;
  auth_password := coalesce((SELECT U_PWD FROM WS.WS.SYS_DAV_USER WHERE U_NAME = 'dav'), '');
  if (auth_password[0] = 0)
    auth_password := pwd_magic_calc ('dav', auth_password, 1);
  DB.DBA.DAV_DELETE (path, 1, 'dav', auth_password);
  DB.DBA.DAV_DELETE (home || 'Calendar (DET)/', 1, 'dav', auth_password);
  DB.DBA.DAV_DELETE (home || 'Calendar/', 1, 'dav', auth_password);

  path := home || 'Calendar' || '/';
  DB.DBA.DAV_MAKE_DIR (path, account_id, null, '110100000N');
  update WS.WS.SYS_DAV_COL set COL_DET = 'Calendar' where COL_ID = DAV_SEARCH_ID (path, 'C');

  path := home || 'calendars' || '/';
  DB.DBA.DAV_MAKE_DIR (path, account_id, null, '110100000N');
  update WS.WS.SYS_DAV_COL set COL_DET = 'CalDAV' where COL_ID = DAV_SEARCH_ID (path, 'C');

  return 1;
}
;

-------------------------------------------------------------------------------
--
create procedure CAL.WA.domain_owner_id (
  in domain_id integer)
{
  return (select TOP 1 A.WAM_USER from WA_MEMBER A, WA_INSTANCE B where A.WAM_MEMBER_TYPE = 1 and A.WAM_INST = B.WAI_NAME and B.WAI_ID = domain_id);
}
;

-------------------------------------------------------------------------------
--
create procedure CAL.WA.domain_owner_name (
  in domain_id integer)
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
  delete from CAL.WA.EXCHANGE where EX_DOMAIN_ID = domain_id;
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
  for (select WAI_NAME, WAI_DESCRIPTION from DB.DBA.WA_INSTANCE where WAI_ID = domain_id and WAI_IS_PUBLIC = 1) do
  {
    ODS..APP_PING (WAI_NAME, coalesce (WAI_DESCRIPTION, WAI_NAME), CAL.WA.forum_iri (domain_id), null, CAL.WA.gems_url (domain_id) || 'Calendar.rss');
    ODS..APP_PING (WAI_NAME, coalesce (WAI_DESCRIPTION, WAI_NAME), CAL.WA.forum_iri (domain_id), null, CAL.WA.gems_url (domain_id) || 'Calendar.atom');
  }
}
;

-------------------------------------------------------------------------------
--
create procedure CAL.WA.forum_iri (
  in domain_id integer)
{
  return SIOC..calendar_iri (CAL.WA.domain_name (domain_id));
}
;

-------------------------------------------------------------------------------
--
create procedure CAL.WA.acl_graph (
  in domain_id integer)
{
  return SIOC..acl_graph ('Calendar', CAL.WA.domain_name (domain_id));
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

  S := CAL.WA.iri_fix (CAL.WA.forum_iri (domain_id));
  return CAL.WA.url_fix (S, sid, realm);
}
;

-------------------------------------------------------------------------------
--
create procedure CAL.WA.domain_calDav_url (
  in domain_id integer)
{
  return sprintf ('%s/DAV/home/%s/calendars/%s', CAL.WA.host_url (), CAL.WA.domain_owner_name (domain_id), DB.DBA.CalDAV__FIXNAME (CAL.WA.domain_name (domain_id)));
}
;

-------------------------------------------------------------------------------
--
create procedure CAL.WA.page_url (
  in domain_id integer,
  in page varchar := null,
  in sid varchar := null,
  in realm varchar := null)
{
  declare S varchar;

  S := CAL.WA.iri_fix (CAL.WA.forum_iri (domain_id));
  if (not isnull (page))
    S := S || '/' || page;
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
  out auth_username varchar,
  out auth_password varchar)
{
  auth_username := CAL.WA.account();
  auth_password := coalesce((SELECT U_PWD FROM WS.WS.SYS_DAV_USER WHERE U_NAME = auth_username), '');
  if (auth_password[0] = 0)
    auth_password := pwd_magic_calc(auth_username, auth_password, 1);
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
create procedure CAL.WA.account_id (
  in account_name varchar)
{
  return (select U_ID from DB.DBA.SYS_USERS where U_NAME = account_name);
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
create procedure CAL.WA.account_password (
  in account_id integer)
{
  return coalesce ((select pwd_magic_calc(U_NAME, U_PWD, 1) from WS.WS.SYS_DAV_USER where U_ID = account_id), '');
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

  S := CAL.WA.iri_fix (SIOC..person_iri (SIOC..user_iri (CAL.WA.domain_owner_id (domain_id), null)));
  return CAL.WA.url_fix (S, sid, realm);
}
;


-------------------------------------------------------------------------------
--
create procedure CAL.WA.account_basicAuthorization (
  in account_id integer)
{
  declare account_name, account_password varchar;

  account_name := CAL.WA.account_name (account_id);
  account_password := CAL.WA.account_password (account_id);
  return sprintf ('Basic %s', encode_base64 (account_name || ':' || account_password));
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
create procedure CAL.WA.tag_rule_exists (
  in user_id integer)
{
  if (exists (select 1 from TAG_RULE_SET, TAG_USER where TU_TRS = TRS_ID and TU_U_ID = user_id))
    return 1;

  return 0;
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
  declare cid any;

  name := (select U_NAME from DB.DBA.SYS_USERS where U_ID = account_id);
  if (isnull (name))
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

-----------------------------------------------------------------------------
--
create procedure CAL.WA.dav_logical_home (
  inout account_id integer) returns varchar
{
  declare home any;

  home := CAL.WA.dav_home (account_id);
  if (not isnull (home))
    home := replace (home, '/DAV', '');
  return home;
}
;

-------------------------------------------------------------------------------
--
create procedure CAL.WA.host_protocol ()
{
  return case when is_https_ctx () then 'https://' else 'http://' end;
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
  if (host is null)
  {
  host := sys_stat ('st_host_name');
  if (server_http_port () <> '80')
    host := host || ':' || server_http_port ();
  }

_exit:;
  if (host not like CAL.WA.host_protocol () || '%')
    host := CAL.WA.host_protocol () || host;

  return host;
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
create procedure CAL.WA.gems_url (
  in domain_id integer)
{
  return sprintf ('http://%s/dataspace/%U/calendar/%U/gems/', DB.DBA.wa_cname (), CAL.WA.domain_owner_name (domain_id), replace (CAL.WA.domain_name (domain_id), '+', '%2B'));
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

  return sprintf ('<a href="%s" title="%s" onclick="javascript: return myA(this);">%V</a> (<a href="%s" title="%s" onclick="javascript: return myA(this);">%V</a>)',
                  CAL.WA.domain_sioc_url (domain_id),
                  CAL.WA.domain_name (domain_id),
                  CAL.WA.domain_name (domain_id),
                  CAL.WA.account_sioc_url (domain_id),
                  CAL.WA.account_fullName (CAL.WA.domain_owner_id (domain_id)),
                  CAL.WA.account_fullName (CAL.WA.domain_owner_id (domain_id))
                 );
}
;

-------------------------------------------------------------------------------
--
create procedure CAL.WA.dav_content (
  in uri varchar,
  in auth_session varchar := 1,
  in auth_username varchar := null,
  in auth_password varchar := null)
{
  declare exit handler for sqlstate '*'
  {
    return null;
  };

  declare N integer;
  declare content, oldUri, newUri, reqHdr, resHdr varchar;
  declare xt any;

  uri := CAL.WA.url_schema_fix (uri);
  newUri := replace (uri, ' ', '%20');
  reqHdr := null;
  if (is_empty_or_null (auth_username))
  {
    auth_username := null;
    auth_password := null;
    if (auth_session = 1)
      CAL.WA.account_access (auth_username, auth_password);
  }
  if (not is_empty_or_null (auth_username))
    reqHdr := sprintf ('Authorization: Basic %s', encode_base64(auth_username || ':' || auth_password));

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
  return CAL.WA.dav_content (newUri, auth_session, auth_username, auth_password);
}
;

-------------------------------------------------------------------------------
--
create procedure CAL.WA.http_error (
  in _header any,
  in _silent integer := 0)
{
  if (_header[0] like 'HTTP/1._ 4__ %' or _header[0] like 'HTTP/1._ 5__ %')
  {
    if (not _silent)
      signal ('22023', trim (_header[0], '\r\n'));

    return 0;
  }
  return 1;
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
    declare exit handler for SQLSTATE '*'
    {
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

  if (not is_empty_or_null(value))
  {
    aEntity := xpath_eval('/settings', pXml);
    XMLAppendChildren(aEntity, xtree_doc(sprintf ('<entry ID="%s">%s</entry>', id, CAL.WA.xml2string(CAL.WA.utf2wide(value)))));
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

  if (isnull (pXml))
    return defaultValue;

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
  if (mode = 0)
  {
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
  in S varchar)
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
  in S any)
{
  declare retValue any;

  if (isstring (S))
  {
    retValue := charset_recode (S, 'UTF-8', '_WIDE_');
    if (iswidestring (retValue))
      return retValue;
  }
  return S;
}
;

-------------------------------------------------------------------------------
--
create procedure CAL.WA.wide2utf (
  in S any)
{
  declare retValue any;

  if (iswidestring (S))
  {
    retValue := charset_recode (S, '_WIDE_', 'UTF-8' );
    if (isstring (retValue))
      return retValue;
  }
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
create procedure CAL.WA.strDecode (
  in S varchar)
{
  declare N, L integer;
  declare T varchar;

  T := '';
  N := 0;
  L := length (S);
  while (N < L)
  {
    if ((chr (S[N]) = '\\') and (N < L-1))
    {
      if (chr (S[N+1]) = 'a')
      {
        T := T || '\a';
        N := N + 1;
      }
      else if (chr (S[N+1]) = 'b')
      {
        T := T || '\b';
        N := N + 1;
      }
      else if (chr (S[N+1]) = 't')
      {
        T := T || '\t';
        N := N + 1;
      }
      else if (chr (S[N+1]) = 'v')
      {
        T := T || '\v';
        N := N + 1;
      }
      else if (chr (S[N+1]) = 'f')
      {
        T := T || '\f';
        N := N + 1;
      }
      else if (chr (S[N+1]) = 'r')
      {
        T := T || '\r';
        N := N + 1;
      }
      else if (chr (S[N+1]) = '\\')
      {
        T := T || '\\';
        N := N + 1;
      }
      else if (chr (S[N+1]) = '"')
      {
        T := T || '"';
        N := N + 1;
      }
      else
      {
        T := T || chr (S[N]);
      }
    } else {
      T := T || chr (S[N]);
    }
    N := N + 1;
  }
  return T;
}
;

-------------------------------------------------------------------------------
--
create procedure CAL.WA.isVector (
  inout aVector any)
{
  if (isarray (aVector) and not isstring (aVector))
    return 1;

  return 0;
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
create procedure CAL.WA.remove_keyword (
  in    name   varchar,
  inout params any)
{
  declare N integer;
  declare V any;

  V := vector ();
  for (N := 0; N < length (params); N := N + 2)
    if (params[N] <> name)
      V := vector_concat (V, vector(params[N], params[N+1]));

  params := V;
  return V;
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
  declare N integer;
  declare ch, S varchar;
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
    }
    else if (ch = 'm')
      {
        S := concat(S, xslt_format_number(month(dt), '##'));
    }
    else if (ch = 'Y')
        {
          S := concat(S, xslt_format_number(year(dt), '0000'));
    }
    else if (ch = 'y')
          {
            S := concat(S, substring (xslt_format_number(year(dt), '0000'),3,2));
    }
    else if (ch = 'd')
            {
              S := concat(S, xslt_format_number(dayofmonth(dt), '##'));
    }
    else if (ch = 'D')
              {
                S := concat(S, xslt_format_number(dayofmonth(dt), '00'));
    }
    else if (ch = 'H')
                {
                  S := concat(S, xslt_format_number(hour(dt), '00'));
    }
    else if (ch = 'h')
                  {
                    S := concat(S, xslt_format_number(hour(dt), '##'));
    }
    else if (ch = 'N')
                    {
                      S := concat(S, xslt_format_number(minute(dt), '00'));
    }
    else if (ch = 'n')
                      {
                        S := concat(S, xslt_format_number(minute(dt), '##'));
    }
    else if (ch = 'S')
                        {
                          S := concat(S, xslt_format_number(second(dt), '00'));
    }
    else if (ch = 's')
                          {
                            S := concat(S, xslt_format_number(second(dt), '##'));
    }
    else
                          {
                            S := concat(S, ch);
    }
    N := N + 1;
  }
  return S;
}
;

-----------------------------------------------------------------------------------------
--
create procedure CAL.WA.dt_deformat (
  in pString varchar,
  in pFormat varchar := 'd.m.Y')
{
  declare y, m, d integer;
  declare N, I integer;
  declare ch varchar;

  pFormat := CAL.WA.dt_formatTemplate (pFormat);
  N := 1;
  I := 0;
  d := 0;
  m := 0;
  y := 0;
  while (N <= length (pFormat))
  {
    ch := upper (substring (pFormat, N, 1));
    if (ch = 'M')
      m := CAL.WA.dt_deformat_tmp (pString, I);
    if (ch = 'D')
      d := CAL.WA.dt_deformat_tmp (pString, I);
    if (ch = 'Y')
    {
      y := CAL.WA.dt_deformat_tmp (pString, I);
      if (y < 50)
        y := 2000 + y;
      if (y < 100)
        y := 1900 + y;
    }
    N := N + 1;
  }
  return stringdate(concat(cast (m as varchar), '.', cast (d as varchar), '.', cast (y as varchar)));
}
;

-----------------------------------------------------------------------------
--
create procedure CAL.WA.dt_deformat_tmp (
  in S varchar,
  inout N integer)
{
  declare V any;

  V := regexp_parse('[0-9]+', S, N);
  if (length (V) > 1)
  {
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

-----------------------------------------------------------------------------------------
--
create procedure CAL.WA.dt_convert (
  in pString varchar,
  in pDefault any := null)
{
  if (isnull (pString))
    goto _end;

  declare exit handler for sqlstate '*' { goto _next; };
  return stringdate (pString);
_next:
  declare exit handler for sqlstate '*' { goto _end; };
  return http_string_date (pString);

_end:
  return pDefault;
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
  inout pTime datetime,
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
  in pTime datetime,
  in pFormat varchar := 'e')
{
  declare exit handler for SQLSTATE '*' {
    return '';
  };
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
  if (not isnull (strstr (pString, 'am')))
  {
    am := 1;
    pString := replace (pString, 'am', '');
  }
  if (not isnull (strstr (pString, 'pm')))
  {
    pm := 1;
    pString := replace (pString, 'pm', '');
  }
  pTime := stringtime (trim (pString));
  if (am = 1)
  {
    if (hour (pTime) = 12)
      pTime := dateadd ('hour', 12, pTime);
  }
  if (pm = 1)
  {
    if (hour (pTime) = 12)
    {
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
  in pTime time,
  in pRound integer := 0)
{
  declare h, m integer;
  declare exit handler for SQLSTATE '*' {
    return pTime;
  };

  if (pRound)
  {
  CAL.WA.dt_timeDecode (pTime, h, m);
    if (mod (m, pRound))
      pTime := CAL.WA.dt_timeEncode (h, floor (cast (m as float) / pRound) * pRound);
  }
  return pTime;
}
;

-----------------------------------------------------------------------------------------
--
create procedure CAL.WA.dt_timeCeiling (
  in pTime datetime,
  in pRound integer := 0)
{
  declare h, m integer;
  declare exit handler for SQLSTATE '*' {
    return pTime;
  };

  if (pRound)
  {
    CAL.WA.dt_timeDecode (pTime, h, m);
    if (mod (m, pRound))
      pTime := CAL.WA.dt_timeFloor (dateadd ('minute', pRound, pTime), pRound);
  }
  return pTime;
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
  in S any)
{
  declare minutes integer;
  declare continue handler for SQLSTATE '*' {
    return 0;
  };

  minutes := atoi (substring (S, 2, 2)) * 60 + atoi (substring (S, 4, 2));
  if (substring (S, 1, 1) = '+')
    minutes := -minutes;

  return minutes;
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

----------------------------------------------------------------------
--
create procedure CAL.WA.tz_array ()
{
  return vector (
    'Pacific/Apia', -11*60+00,
    'Pacific/Midway', -11*60+00,
    'Pacific/Niue', -11*60+00,
    'Pacific/Pago_Pago', -11*60+00,
    'Pacific/Fakaofo', -10*60+00,
    'Pacific/Honolulu', -10*60+00,
    'Pacific/Johnston', -10*60+00,
    'Pacific/Rarotonga', -10*60+00,
    'Pacific/Tahiti', -10*60+00,
    'Pacific/Marquesas', -09*60+30,
    'America/Anchorage', -09*60+00,
    'Pacific/Gambier', -09*60+00,
    'America/Los_Angeles', -08*60+00,
    'America/Tijuana', -08*60+00,
    'America/Vancouver', -08*60+00,
    'America/Whitehorse', -08*60+00,
    'Pacific/Pitcairn', -08*60+00,
    'America/Dawson_Creek', -07*60+00,
    'America/Denver', -07*60+00,
    'America/Edmonton', -07*60+00,
    'America/Hermosillo', -07*60+00,
    'America/Mazatlan', -07*60+00,
    'America/Phoenix', -07*60+00,
    'America/Yellowknife', -07*60+00,
    'America/Belize', -06*60+00,
    'America/Chicago', -06*60+00,
    'America/Costa_Rica', -06*60+00,
    'America/El_Salvador', -06*60+00,
    'America/Guatemala', -06*60+00,
    'America/Managua', -06*60+00,
    'America/Mexico_City', -06*60+00,
    'America/Regina', -06*60+00,
    'America/Tegucigalpa', -06*60+00,
    'America/Winnipeg', -06*60+00,
    'Pacific/Easter', -06*60+00,
    'Pacific/Galapagos', -06*60+00,
    'America/Bogota', -05*60+00,
    'America/Cayman', -05*60+00,
    'America/Grand_Turk', -05*60+00,
    'America/Guayaquil', -05*60+00,
    'America/Havana', -05*60+00,
    'America/Iqaluit', -05*60+00,
    'America/Jamaica', -05*60+00,
    'America/Lima', -05*60+00,
    'America/Montreal', -05*60+00,
    'America/Nassau', -05*60+00,
    'America/New_York', -05*60+00,
    'America/Panama', -05*60+00,
    'America/Port-au-Prince', -05*60+00,
    'America/Toronto', -05*60+00,
    'America/Caracas', -04*60+30,
    'America/Anguilla', -04*60+00,
    'America/Antigua', -04*60+00,
    'America/Aruba', -04*60+00,
    'America/Asuncion', -04*60+00,
    'America/Barbados', -04*60+00,
    'America/Boa_Vista', -04*60+00,
    'America/Campo_Grande', -04*60+00,
    'America/Cuiaba', -04*60+00,
    'America/Curacao', -04*60+00,
    'America/Dominica', -04*60+00,
    'America/Grenada', -04*60+00,
    'America/Guadeloupe', -04*60+00,
    'America/Guyana', -04*60+00,
    'America/Halifax', -04*60+00,
    'America/La_Paz', -04*60+00,
    'America/Manaus', -04*60+00,
    'America/Martinique', -04*60+00,
    'America/Montserrat', -04*60+00,
    'America/Port_of_Spain', -04*60+00,
    'America/Porto_Velho', -04*60+00,
    'America/Puerto_Rico', -04*60+00,
    'America/Rio_Branco', -04*60+00,
    'America/Santiago', -04*60+00,
    'America/Santo_Domingo', -04*60+00,
    'America/St_Kitts', -04*60+00,
    'America/St_Lucia', -04*60+00,
    'America/St_Thomas', -04*60+00,
    'America/St_Vincent', -04*60+00,
    'America/Thule', -04*60+00,
    'America/Tortola', -04*60+00,
    'Antarctica/Palmer', -04*60+00,
    'Atlantic/Bermuda', -04*60+00,
    'Atlantic/Stanley', -04*60+00,
    'America/St_Johns', -03*60+30,
    'America/Araguaina', -03*60+00,
    'America/Argentina/Buenos_Aires', -03*60+00,
    'America/Bahia', -03*60+00,
    'America/Belem', -03*60+00,
    'America/Cayenne', -03*60+00,
    'America/Fortaleza', -03*60+00,
    'America/Godthab', -03*60+00,
    'America/Maceio', -03*60+00,
    'America/Miquelon', -03*60+00,
    'America/Montevideo', -03*60+00,
    'America/Paramaribo', -03*60+00,
    'America/Recife', -03*60+00,
    'America/Sao_Paulo', -03*60+00,
    'Antarctica/Rothera', -03*60+00,
    'America/Noronha', -02*60+00,
    'Atlantic/South_Georgia', -02*60+00,
    'America/Scoresbysund', -01*60+00,
    'Atlantic/Azores', -01*60+00,
    'Atlantic/Cape_Verde', -01*60+00,
    'Africa/Abidjan', +00*60+00,
    'Africa/Accra', +00*60+00,
    'Africa/Bamako', +00*60+00,
    'Africa/Banjul', +00*60+00,
    'Africa/Bissau', +00*60+00,
    'Africa/Casablanca', +00*60+00,
    'Africa/Conakry', +00*60+00,
    'Africa/Dakar', +00*60+00,
    'Africa/El_Aaiun', +00*60+00,
    'Africa/Freetown', +00*60+00,
    'Africa/Lome', +00*60+00,
    'Africa/Monrovia', +00*60+00,
    'Africa/Nouakchott', +00*60+00,
    'Africa/Ouagadougou', +00*60+00,
    'Africa/Sao_Tome', +00*60+00,
    'America/Danmarkshavn', +00*60+00,
    'Atlantic/Canary', +00*60+00,
    'Atlantic/Faroe', +00*60+00,
    'Atlantic/Reykjavik', +00*60+00,
    'Atlantic/St_Helena', +00*60+00,
    'Etc/GMT', +00*60+00,
    'Europe/Dublin', +00*60+00,
    'Europe/Lisbon', +00*60+00,
    'Europe/London', +00*60+00,
    'Africa/Algiers', +01*60+00,
    'Africa/Bangui', +01*60+00,
    'Africa/Brazzaville', +01*60+00,
    'Africa/Ceuta', +01*60+00,
    'Africa/Douala', +01*60+00,
    'Africa/Kinshasa', +01*60+00,
    'Africa/Lagos', +01*60+00,
    'Africa/Libreville', +01*60+00,
    'Africa/Luanda', +01*60+00,
    'Africa/Malabo', +01*60+00,
    'Africa/Ndjamena', +01*60+00,
    'Africa/Niamey', +01*60+00,
    'Africa/Porto-Novo', +01*60+00,
    'Africa/Tunis', +01*60+00,
    'Africa/Windhoek', +01*60+00,
    'Europe/Amsterdam', +01*60+00,
    'Europe/Andorra', +01*60+00,
    'Europe/Belgrade', +01*60+00,
    'Europe/Berlin', +01*60+00,
    'Europe/Brussels', +01*60+00,
    'Europe/Budapest', +01*60+00,
    'Europe/Copenhagen', +01*60+00,
    'Europe/Gibraltar', +01*60+00,
    'Europe/Luxembourg', +01*60+00,
    'Europe/Madrid', +01*60+00,
    'Europe/Malta', +01*60+00,
    'Europe/Monaco', +01*60+00,
    'Europe/Oslo', +01*60+00,
    'Europe/Paris', +01*60+00,
    'Europe/Prague', +01*60+00,
    'Europe/Rome', +01*60+00,
    'Europe/Stockholm', +01*60+00,
    'Europe/Tirane', +01*60+00,
    'Europe/Vaduz', +01*60+00,
    'Europe/Vienna', +01*60+00,
    'Europe/Warsaw', +01*60+00,
    'Europe/Zurich', +01*60+00,
    'Africa/Blantyre', +02*60+00,
    'Africa/Bujumbura', +02*60+00,
    'Africa/Cairo', +02*60+00,
    'Africa/Gaborone', +02*60+00,
    'Africa/Harare', +02*60+00,
    'Africa/Johannesburg', +02*60+00,
    'Africa/Kigali', +02*60+00,
    'Africa/Lubumbashi', +02*60+00,
    'Africa/Lusaka', +02*60+00,
    'Africa/Maputo', +02*60+00,
    'Africa/Maseru', +02*60+00,
    'Africa/Mbabane', +02*60+00,
    'Africa/Tripoli', +02*60+00,
    'Asia/Amman', +02*60+00,
    'Asia/Beirut', +02*60+00,
    'Asia/Damascus', +02*60+00,
    'Asia/Gaza', +02*60+00,
    'Asia/Jerusalem', +02*60+00,
    'Asia/Nicosia', +02*60+00,
    'Europe/Athens', +02*60+00,
    'Europe/Bucharest', +02*60+00,
    'Europe/Chisinau', +02*60+00,
    'Europe/Helsinki', +02*60+00,
    'Europe/Istanbul', +02*60+00,
    'Europe/Kaliningrad', +02*60+00,
    'Europe/Kiev', +02*60+00,
    'Europe/Minsk', +02*60+00,
    'Europe/Riga', +02*60+00,
    'Europe/Sofia', +02*60+00,
    'Europe/Tallinn', +02*60+00,
    'Europe/Vilnius', +02*60+00,
    'Africa/Addis_Ababa', +03*60+00,
    'Africa/Asmara', +03*60+00,
    'Africa/Dar_es_Salaam', +03*60+00,
    'Africa/Djibouti', +03*60+00,
    'Africa/Kampala', +03*60+00,
    'Africa/Khartoum', +03*60+00,
    'Africa/Mogadishu', +03*60+00,
    'Africa/Nairobi', +03*60+00,
    'Antarctica/Syowa', +03*60+00,
    'Asia/Aden', +03*60+00,
    'Asia/Baghdad', +03*60+00,
    'Asia/Bahrain', +03*60+00,
    'Asia/Kuwait', +03*60+00,
    'Asia/Qatar', +03*60+00,
    'Asia/Riyadh', +03*60+00,
    'Europe/Moscow', +03*60+00,
    'Indian/Antananarivo', +03*60+00,
    'Indian/Comoro', +03*60+00,
    'Indian/Mayotte', +03*60+00,
    'Asia/Tehran', +03*60+30,
    'Asia/Baku', +04*60+00,
    'Asia/Dubai', +04*60+00,
    'Asia/Muscat', +04*60+00,
    'Asia/Tbilisi', +04*60+00,
    'Asia/Yerevan', +04*60+00,
    'Europe/Samara', +04*60+00,
    'Indian/Mahe', +04*60+00,
    'Indian/Mauritius', +04*60+00,
    'Indian/Reunion', +04*60+00,
    'Asia/Kabul', +04*60+30,
    'Asia/Aqtau', +05*60+00,
    'Asia/Aqtobe', +05*60+00,
    'Asia/Ashgabat', +05*60+00,
    'Asia/Dushanbe', +05*60+00,
    'Asia/Karachi', +05*60+00,
    'Asia/Tashkent', +05*60+00,
    'Asia/Yekaterinburg', +05*60+00,
    'Indian/Kerguelen', +05*60+00,
    'Indian/Maldives', +05*60+00,
    'Asia/Calcutta', +05*60+30,
    'Asia/Colombo', +05*60+30,
    'Asia/Katmandu', +05*60+45,
    'Antarctica/Mawson', +06*60+00,
    'Antarctica/Vostok', +06*60+00,
    'Asia/Almaty', +06*60+00,
    'Asia/Bishkek', +06*60+00,
    'Asia/Dhaka', +06*60+00,
    'Asia/Omsk', +06*60+00,
    'Asia/Thimphu', +06*60+00,
    'Indian/Chagos', +06*60+00,
    'Asia/Rangoon', +06*60+30,
    'Indian/Cocos', +06*60+30,
    'Antarctica/Davis', +07*60+00,
    'Asia/Bangkok', +07*60+00,
    'Asia/Hovd', +07*60+00,
    'Asia/Jakarta', +07*60+00,
    'Asia/Krasnoyarsk', +07*60+00,
    'Asia/Phnom_Penh', +07*60+00,
    'Asia/Saigon', +07*60+00,
    'Asia/Vientiane', +07*60+00,
    'Indian/Christmas', +07*60+00,
    'Antarctica/Casey', +08*60+00,
    'Asia/Brunei', +08*60+00,
    'Asia/Choibalsan', +08*60+00,
    'Asia/Hong_Kong', +08*60+00,
    'Asia/Irkutsk', +08*60+00,
    'Asia/Kuala_Lumpur', +08*60+00,
    'Asia/Macau', +08*60+00,
    'Asia/Makassar', +08*60+00,
    'Asia/Manila', +08*60+00,
    'Asia/Shanghai', +08*60+00,
    'Asia/Singapore', +08*60+00,
    'Asia/Taipei', +08*60+00,
    'Asia/Ulaanbaatar', +08*60+00,
    'Australia/Perth', +08*60+00,
    'Asia/Dili', +09*60+00,
    'Asia/Jayapura', +09*60+00,
    'Asia/Pyongyang', +09*60+00,
    'Asia/Seoul', +09*60+00,
    'Asia/Tokyo', +09*60+00,
    'Asia/Yakutsk', +09*60+00,
    'Pacific/Palau', +09*60+00,
    'Australia/Adelaide', +09*60+30,
    'Australia/Darwin', +09*60+30,
    'Antarctica/DumontDUrville', +10*60+00,
    'Asia/Vladivostok', +10*60+00,
    'Australia/Brisbane', +10*60+00,
    'Australia/Hobart', +10*60+00,
    'Australia/Sydney', +10*60+00,
    'Pacific/Guam', +10*60+00,
    'Pacific/Port_Moresby', +10*60+00,
    'Pacific/Saipan', +10*60+00,
    'Pacific/Truk', +10*60+00,
    'Asia/Magadan', +11*60+00,
    'Pacific/Efate', +11*60+00,
    'Pacific/Guadalcanal', +11*60+00,
    'Pacific/Kosrae', +11*60+00,
    'Pacific/Noumea', +11*60+00,
    'Pacific/Ponape', +11*60+00,
    'Pacific/Norfolk', +11*60+30,
    'Asia/Kamchatka', +12*60+00,
    'Pacific/Auckland', +12*60+00,
    'Pacific/Fiji', +12*60+00,
    'Pacific/Funafuti', +12*60+00,
    'Pacific/Kwajalein', +12*60+00,
    'Pacific/Majuro', +12*60+00,
    'Pacific/Nauru', +12*60+00,
    'Pacific/Tarawa', +12*60+00,
    'Pacific/Wake', +12*60+00,
    'Pacific/Wallis', +12*60+00,
    'Pacific/Enderbury', +13*60+00,
    'Pacific/Tongatapu', +13*60+00,
    'Pacific/Kiritimati', +14*60+00
  );
}
;

----------------------------------------------------------------------
--
create procedure CAL.WA.tz_name (in tzValue integer)
{
  declare timezones, N any;

  timezones := CAL.WA.tz_array ();
  for (N := 0; N < length (timezones); N := N + 2)
    if (timezones[N+1] = tzValue)
      return timezones[N];
  return 'Etc/GMT';
}
;

----------------------------------------------------------------------
--
create procedure CAL.WA.tz_value (in tzName varchar)
{
  declare timezones, N any;

  timezones := CAL.WA.tz_array ();
  for (N := 0; N < length (timezones); N := N + 2)
    if (timezones[N] = tzName)
      return timezones[N+1];
  return 0;
}
;

create procedure CAL.WA.dt_daylightRRules (
  in pDaylight integer,
  inout pStartRRule any,
  inout pEndRRule any)
{
  if (pDaylight = 1)
  {
    pStartRRule := vector ('Y2', 5, 7,  3, null);
    pEndRRule := vector ('Y2', 5, 7, 10, null);
  }
  else if (pDaylight = 2)
  {
    pStartRRule := vector ('Y2', 2, 7,  3, null);
    pEndRRule := vector ('Y2', 1, 7, 11, null);
  }
  else
  {
    pStartRRule := null;
    pEndRRule := null;
  }
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
	  regexp := regexp_parse ('P([0-9]+D)?([0-9]+W)?', t_part, 0);
	  if (regexp is null)
	    return 0;
	  if (length (regexp) > 2 and regexp[2] <> -1)
	    secs := secs + 24 * 3600 * atoi (subseq (t_part, regexp[2], regexp[3]));
	  if (length (regexp) > 4 and regexp[4] <> -1)
	    secs := secs + 24 * 3600 * 7 * atoi (subseq (t_part, regexp[4], regexp[5]));
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
  S := substring (S, 1, coalesce (strstr (S, '<>'), length (S)));
  S := substring (S, 1, coalesce (strstr (S, '\nin'), length (S)));

  return S;
}
;

-----------------------------------------------------------------------------------------
--
create procedure CAL.WA.test (
  in value any,
  in params any := null) returns any
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
      signal ('TEST', sprintf ('''%s'' value should be greater than %s!<>', valueName, cast (tmp as varchar)));
    if (__SQL_STATE = 'MAX')
      signal ('TEST', sprintf ('''%s'' value should be less than %s!<>', valueName, cast (tmp as varchar)));
    if (__SQL_STATE = 'MINLENGTH')
      signal ('TEST', sprintf ('The length of field ''%s'' should be greater than %s characters!<>', valueName, cast (tmp as varchar)));
    if (__SQL_STATE = 'MAXLENGTH')
      signal ('TEST', sprintf ('The length of field ''%s'' should be less than %s characters!<>', valueName, cast (tmp as varchar)));
    if (__SQL_STATE = 'SPECIAL')
      signal ('TEST', __SQL_MESSAGE || '<>');
    signal ('TEST', 'Unknown validation error!<>');
    --resignal;
  };

  if (isstring (value))
  value := trim(value);
  if (is_empty_or_null(params))
    return value;

  valueClass := coalesce (get_keyword ('class', params), get_keyword ('type', params));
  valueType := coalesce (get_keyword ('type', params), get_keyword ('class', params));
  valueName := get_keyword ('name', params, 'Field');
  valueMessage := get_keyword ('message', params, '');

  tmp := get_keyword ('canEmpty', params);
  if (isnull (tmp))
  {
    if (not isnull (get_keyword ('minValue', params))) {
      tmp := 0;
    } else if (get_keyword ('minLength', params, 0) <> 0) {
      tmp := 0;
    }
  }
  if (not isnull (tmp) and (tmp = 0) and is_empty_or_null(value))
  {
    signal('EMPTY', '');
  } else if (is_empty_or_null(value)) {
    return value;
  }

  value := CAL.WA.validate2 (valueClass, cast (value as varchar));
  if (valueType = 'integer')
  {
    tmp := get_keyword ('minValue', params);
    if ((not isnull (tmp)) and (value < tmp))
      signal('MIN', cast (tmp as varchar));

    tmp := get_keyword ('maxValue', params);
    if (not isnull (tmp) and (value > tmp))
      signal('MAX', cast (tmp as varchar));
  }
  else if (valueType = 'float')
  {
    tmp := get_keyword ('minValue', params);
    if (not isnull (tmp) and (value < tmp))
      signal('MIN', cast (tmp as varchar));

    tmp := get_keyword ('maxValue', params);
    if (not isnull (tmp) and (value > tmp))
      signal('MAX', cast (tmp as varchar));
  }
  else if (valueType = 'varchar')
  {
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
    if (isnull (regexp_match('^(ht|f)tp(s?)\:\/\/[0-9a-zA-Z]([-.\w]*[0-9a-zA-Z])*(:(0-9)*)*(\/?)([a-zA-Z0-9\-\.\?\,\'\/\\\+&amp;%\$#_=:~]*)?\$', propertyValue)))
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
  in checkedValue any,
  in compareValue any := 1)
{
  if (checkedValue = compareValue)
    return 'checked="checked"';
  return '';
}
;

-------------------------------------------------------------------------------
--
create procedure CAL.WA.dashboard_rs (
  in p0 integer,
  in p1 integer := 0)
{
  declare c0 integer;
  declare c1 varchar;
  declare c2 datetime;

  result_names(c0, c1, c2);
  if (p1 = 1)
  {
    for (select top 10 *
           from (select E_ID,
                        E_SUBJECT,
                        E_UPDATED
                   from CAL.WA.EVENTS
                  where E_DOMAIN_ID = p0
                    and E_PRIVACY = p1
                  order by E_UPDATED desc
                ) x
        ) do
  {
      result (E_ID, E_SUBJECT, coalesce (E_UPDATED, now ()));
  }
  } else {
    for (select top 10 *
           from (select a.E_ID,
                        a.E_SUBJECT,
                        a.E_UPDATED
                   from CAL.WA.EVENTS a,
                        CAL..MY_CALENDARS b
                  where b.domain_id = p0
                    and b.privacy = p1
                    and a.E_DOMAIN_ID = b.CALENDAR_ID
                    and a.E_PRIVACY >= b.CALENDAR_PRIVACY
                  order by a.E_UPDATED desc
                ) x
        ) do
    {
      result (E_ID, E_SUBJECT, coalesce (E_UPDATED, now ()));
    }
    }
  }
;

-------------------------------------------------------------------------------
--
create procedure CAL.WA.dashboard_get (
  in domain_id integer,
  in privacy integer := 0)
{
  declare account_id integer;
  declare sStream any;

  account_id := CAL.WA.domain_owner_id (domain_id);
  sStream := string_output ();
  http ('<calendar-db>', sStream);
  for (select x.* from CAL.WA.dashboard_rs(p0, p1)(_id integer, _name varchar, _time datetime) x where p0 = domain_id and p1 = privacy) do
  {
    CAL.WA.dashboard_item (sStream, account_id, _name, SIOC..calendar_event_iri (domain_id, _id), _time);
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
create procedure CAL.WA.settings_init (
  inout settings any)
{
  declare tz integer;

  tz := cast (get_keyword ('timeZone', settings, '0') as integer);
  CAL.WA.set_keyword ('chars', settings, cast (get_keyword ('chars', settings, '60') as integer));
  CAL.WA.set_keyword ('rows', settings, cast (get_keyword ('rows', settings, '10') as integer));
  CAL.WA.set_keyword ('atomVersion', settings, get_keyword ('atomVersion', settings, '1.0'));

  CAL.WA.set_keyword ('defaultView', settings, get_keyword ('defaultView', settings, 'week'));
  CAL.WA.set_keyword ('weekStarts', settings, get_keyword ('weekStarts', settings, 'm'));
  CAL.WA.set_keyword ('timeFormat', settings, get_keyword ('timeFormat', settings, 'e'));
  CAL.WA.set_keyword ('dateFormat', settings, get_keyword ('dateFormat', settings, 'dd.MM.yyyy'));
  CAL.WA.set_keyword ('timeZone', settings, tz);
  CAL.WA.set_keyword ('timeZoneName', settings, get_keyword ('timeZoneName', settings, case when tz = 0 then 'Etc/GMT' else CAL.WA.tz_name (tz) end));
  CAL.WA.set_keyword ('daylight', settings, CAL.WA.settings_daylight (settings));
  CAL.WA.set_keyword ('showTasks', settings, cast (get_keyword ('showTasks', settings, '1') as integer));
  CAL.WA.set_keyword ('mailAttendees', settings, cast (get_keyword ('mailAttendees', settings, '1') as integer));

  CAL.WA.set_keyword ('conv', settings, cast (get_keyword ('conv', settings, '0') as integer));
  CAL.WA.set_keyword ('conv_init', settings, cast (get_keyword ('conv_init', settings, '0') as integer));

  CAL.WA.set_keyword ('event_E_UPDATED', settings, cast (get_keyword ('event_E_UPDATED', settings, '0') as integer));
  CAL.WA.set_keyword ('event_E_CREATED', settings, cast (get_keyword ('event_E_CREATED', settings, '0') as integer));
  CAL.WA.set_keyword ('event_E_LOCATION', settings, cast (get_keyword ('event_E_LOCATION', settings, '0') as integer));

  CAL.WA.set_keyword ('task_E_STATUS', settings, cast (get_keyword ('task_E_STATUS', settings, '0') as integer));
  CAL.WA.set_keyword ('task_E_PRIORITY', settings, cast (get_keyword ('task_E_PRIORITY', settings, '0') as integer));
  CAL.WA.set_keyword ('task_E_START', settings, cast (get_keyword ('task_E_START', settings, '0') as integer));
  CAL.WA.set_keyword ('task_E_END', settings, cast (get_keyword ('task_E_END', settings, '0') as integer));
  CAL.WA.set_keyword ('task_E_COMPLETED', settings, cast (get_keyword ('task_E_COMPLETED', settings, '0') as integer));
  CAL.WA.set_keyword ('task_E_UPDATED', settings, cast (get_keyword ('task_E_UPDATED', settings, '0') as integer));
  CAL.WA.set_keyword ('task_E_CREATED', settings, cast (get_keyword ('task_E_CREATED', settings, '0') as integer));
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
  CAL.WA.settings_weekStarts (CAL.WA.settings (domain_id));
}
;

-------------------------------------------------------------------------------
--
create procedure CAL.WA.settings_timeZone (
  in settings any,
  in tzSetting varchar := 'usedTimeZone',
  in defaultValue any := '0')
{
  return cast (get_keyword (tzSetting, settings, defaultValue) as integer);
}
;

-------------------------------------------------------------------------------
--
create procedure CAL.WA.settings_timeZone2 (
  in domain_id integer)
{
  return CAL.WA.settings_usedTimeZone (domain_id);
}
;

-------------------------------------------------------------------------------
--
create procedure CAL.WA.settings_usedTimeZone (
  in domain_id integer,
  in account_id integer := null)
{
  declare tmp any;

  tmp := CAL.WA.settings_timeZone (CAL.WA.settings (domain_id), 'timeZone', null);
  if (isnull (tmp))
  {
    if (isnull (account_id))
      account_id := CAL.WA.domain_owner_id (domain_id);
    tmp := (select WAUI_HTZONE from DB.DBA.WA_USER_INFO where WAUI_U_ID = account_id);
    if (isnull (tmp))
      tmp := (select WAUI_BTZONE from DB.DBA.WA_USER_INFO where WAUI_U_ID = account_id);
    if (isnull (tmp))
      tmp := 0;
    tmp := cast (tmp as integer) * 60;
  }
  return tmp;
}
;

-------------------------------------------------------------------------------
--
create procedure CAL.WA.settings_timeZoneName (
  in settings any,
  in defaultValue any := 'Etc/GMT')
{
  return get_keyword ('timeZoneName', settings, defaultValue);
}
;

-------------------------------------------------------------------------------
--
create procedure CAL.WA.settings_timeZoneName2 (
  in domain_id integer)
{
  declare tz integer;
  declare settings any;

  tz := CAL.WA.settings_timeZone2 (domain_id);
  settings := CAL.WA.settings (domain_id);
  return get_keyword ('timeZoneName', settings, case when tz = 0 then 'Etc/GMT' else CAL.WA.tz_name (tz) end);
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
  return CAL.WA.settings_dateFormat (CAL.WA.settings (domain_id));
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
  return CAL.WA.settings_timeFormat (CAL.WA.settings (domain_id));
}
;

-------------------------------------------------------------------------------
--
create procedure CAL.WA.settings_daylight (
  in settings any)
{
  return cast (get_keyword ('daylight', settings, '0') as integer);
}
;

-------------------------------------------------------------------------------
--
create procedure CAL.WA.settings_daylight2 (
  in domain_id integer)
{
  return CAL.WA.settings_daylight (CAL.WA.settings (domain_id));
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

-------------------------------------------------------------------------------
--
create procedure CAL.WA.settings_mailAttendees (
  in settings any)
{
  return cast (get_keyword ('mailAttendees', settings, '1') as integer);
}
;

-------------------------------------------------------------------------------
--
create procedure CAL.WA.settings_taskFilter (
  in settings any)
{
  return get_keyword ('taskFilter', settings, 'All');
}
;

-------------------------------------------------------------------------------
--
create procedure CAL.WA.settings_set (
  in domain_id integer,
  in _key varchar,
  in _value any)
{
  declare settings any;

  settings := CAL.WA.settings (domain_id);
  CAL.WA.set_keyword (_key, settings, _value);

  insert replacing CAL.WA.SETTINGS (S_DOMAIN_ID, S_DATA, S_ACCOUNT_ID)
    values(domain_id, serialize (settings), CAL.WA.domain_owner_id (domain_id));
}
;

-----------------------------------------------------------------------------------------
--
-- Events
--
-----------------------------------------------------------------------------------------
create procedure CAL.WA.event_sioc_iri (
  in domain_id integer,
  in event_id integer)
{
  return CAL.WA.iri_fix (SIOC..calendar_event_iri (domain_id, event_id));
}
;

-----------------------------------------------------------------------------------------
--
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
  if (id = -1)
  {
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
  }
  else
  {
    declare exit handler for SQLSTATE '*', not found {
      return -1;
    };

    declare _subject varchar;
    declare _description varchar;
    declare _location varchar;
    declare _privacy integer;
    declare _tags varchar;
    declare _event integer;
    declare _eEventStart datetime;
    declare _eEventEnd datetime;
    declare _eRepeat varchar;
    declare _eRepeatParam1 integer;
    declare _eRepeatParam2 integer;
    declare _eRepeatParam3 integer;
    declare _eRepeatUntil datetime;
    declare _eReminder integer;
    declare _notes varchar;

    select
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
           E_NOTES
      into _subject,
           _description,
           _location,
           _privacy,
           _tags,
           _event,
           _eEventStart,
           _eEventEnd,
           _eRepeat,
           _eRepeatParam1,
           _eRepeatParam2,
           _eRepeatParam3,
           _eRepeatUntil,
           _eReminder,
           _notes
      from CAL.WA.EVENTS
     where E_ID = id;

    if (
        (coalesce (subject       , ''    ) = coalesce (_subject       , ''    )) and
        (coalesce (description   , ''    ) = coalesce (_description   , ''    )) and
        (coalesce (location      , ''    ) = coalesce (_location      , ''    )) and
        (coalesce (privacy       , -1    ) = coalesce (_privacy       , -1    )) and
        (coalesce (tags          , ''    ) = coalesce (_tags          , ''    )) and
        (coalesce (event         , -1    ) = coalesce (_event         , -1    )) and
        (coalesce (eEventStart   , now ()) = coalesce (_eEventStart   , now ())) and
        (coalesce (eEventEnd     , now ()) = coalesce (_eEventEnd     , now ())) and
        (coalesce (eRepeat       , ''    ) = coalesce (_eRepeat       , ''    )) and
        (coalesce (eRepeatParam1 , -1    ) = coalesce (_eRepeatParam1 , -1    )) and
        (coalesce (eRepeatParam2 , -1    ) = coalesce (_eRepeatParam2 , -1    )) and
        (coalesce (eRepeatParam3 , -1    ) = coalesce (_eRepeatParam3 , -1    )) and
        (coalesce (eRepeatUntil  , now ()) = coalesce (_eRepeatUntil  , now ())) and
        (coalesce (eReminder     , -1    ) = coalesce (_eReminder     , -1    )) and
        (coalesce (notes         , ''    ) = coalesce (_notes         , ''    ))
       )
      goto _end;

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
_end:;
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
  return row_count ();
}
;

-------------------------------------------------------------------------------
--
create procedure CAL.WA.event_update_acl (
  in id integer,
  in acl any)
{
  update CAL.WA.EVENTS
     set E_ACL = acl
   where E_ID = id
     and E_PRIVACY = 2;
}
;

-------------------------------------------------------------------------------
--
create procedure CAL.WA.event_rights (
  in domain_id integer,
  in id integer,
  in access_role varchar)
{
  declare event_domain_id integer;
  declare retValue varchar;

  retValue := '';
  event_domain_id := (select E_DOMAIN_ID from CAL.WA.EVENTS where E_ID = id);
  if (not isnull (event_domain_id))
  {
    if (event_domain_id = domain_id)
    {
      retValue := CAL.WA.acl_check (domain_id, id);
      if (retValue = '')
        retValue := access_role;
  }
    else
    {
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
            retValue := 'R';
        }
        else if (G_ENABLE)
      {
        if (CAL.WA.access_is_write (access_role))
          {
            retValue := G_MODE;
          } else {
            retValue := access_role;
          }
      }
    }
  }
  }
  return retValue;
}
;

-------------------------------------------------------------------------------
--
create procedure CAL.WA.event_check_privacy (
  in my_domain_id integer,
  in my_account_id integer,
  in event_domain_id integer,
  in event_id integer,
  in event_privacy integer)
{
  -- my event
  if (my_domain_id = event_domain_id)
    return 1;

  -- public event
  if (event_privacy = 1)
    return 1;

  -- shared event
  if ((event_privacy = 2) and exists (select 1 from CAL..EVENT_GRANTS_VIEW a where a.EVENT_ID = event_id and a.TO_ID = my_account_id))
    return 1;

  return 0;
}
;

-------------------------------------------------------------------------------
--
create procedure CAL.WA.event_gmt2user (
  in pDate datetime,
  in pTimezone integer := 0,
  in pDaylight integer := 0)

{
  if (not isnull (pDate))
  {
    pDate := dateadd ('minute', pTimezone, pDate);
    if (pDaylight)
      pDate := CAL.WA.event_daylight (pDate, pDaylight, 1);
  }
    return pDate;
}
;

-------------------------------------------------------------------------------
--
create procedure CAL.WA.event_user2gmt (
  in pDate datetime,
  in pTimezone integer := 0,
  in pDaylight integer := 0)
{
  if (not isnull (pDate))
  {
    pDate := dateadd ('minute', -pTimezone, pDate);
    if (pDaylight)
      pDate := CAL.WA.event_daylight (pDate, pDaylight, -1);
  }
    return pDate;
}
;

-------------------------------------------------------------------------------
--
create procedure CAL.WA.event_daylight (
  in pDate datetime,
  in pDaylight integer,
  in pStep integer := 0)
{
  declare _day, _month integer;
  declare startRRule, endRRule any;

  CAL.WA.dt_daylightRRules (pDaylight, startRRule, endRRule);
  _month := month (pDate);
  if (_month < startRRule[3])
    return pDate;

  if (_month = startRRule[3])
  {
    _day := CAL.WA.event_findDay (pDate, startRRule[1], startRRule[2]);
    if (dayofmonth (pDate) < _day)
      return pDate;

    return dateadd ('hour', pStep, pDate);
  }

  if (_month < endRRule[3])
    return dateadd ('hour', pStep, pDate);

  if (_month = endRRule[3])
  {
    _day := CAL.WA.event_findDay (pDate, endRRule[1], endRRule[2]);
    if (dayofmonth (pDate) >= _day)
      return pDate;

    return dateadd ('hour', pStep, pDate);
  }
  return pDate;
}
;

-------------------------------------------------------------------------------
--
create procedure CAL.WA.event_daylightCheck (
  in pDate datetime,
  in pStartRRule any,
  in pEndRRule any)

{
  declare _day, _month integer;

  _month := month (pDate);
  if (_month < pStartRRule[3])
    return 0;

  if (_month = pStartRRule[3])
  {
    _day := CAL.WA.event_findDay (pDate, pStartRRule[1], pStartRRule[2]);
    if (dayofmonth (pDate) <= _day)
      return 0;

    return 1;
  }

  if (_month < pEndRRule[3])
    return 1;

  if (_month = pEndRRule[3])
  {
    _day := CAL.WA.event_findDay (pDate, pEndRRule[1], pEndRRule[2]);
    if (dayofmonth (pDate) > _day)
      return 0;

    return 1;
  }
  return 0;
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

  if (eRepeat = 'D1')
  {
  -- Every N-th day(s)
    if (mod (datediff ('day', eEventStart, dtEnd), eRepeatParam1) = 0)
      return 1;
  }
  else if (eRepeat = 'D2')
  {
  -- Every week day
    tmp := dayofweek (dt);
    if ((tmp > 1) and (tmp < 7))
      return 1;
  }
  else if (eRepeat = 'W1')
  {
  -- Every N-th week on ...
    if (eRepeatParam2 = 0)
      eRepeatParam2 := bit_or (eRepeatParam2, power (2, dayofweek (eEventStart)-1));
    if (mod (datediff ('day', eEventStart, dtEnd) / 7, eRepeatParam1) = 0)
      if (bit_and (eRepeatParam2, power (2, CAL.WA.dt_WeekDay (dt, weekStarts)-1)))
        return 1;
  }
  else if (eRepeat = 'M1')
  {
  -- Every N-th day of M-th month(s)
    if (mod (datediff ('month', eEventStart, dtEnd), eRepeatParam1) = 0)
      if (dayofmonth (dt) = eRepeatParam2)
        return 1;
  }
  else if (eRepeat = 'M2')
  {
  -- Every X day/weekday/weekend/... of Y-th month(s)
    if (mod (datediff ('month', eEventStart, dtEnd), eRepeatParam1) = 0)
      if (dayofmonth (dt) = CAL.WA.event_findDay (dt, eRepeatParam2, eRepeatParam3))
        return 1;
  }
  else if (eRepeat = 'Y1')
  {
    if (mod (datediff ('year', eEventStart, dtEnd), eRepeatParam1) = 0)
      if ((month (dt) = eRepeatParam2) and (dayofmonth (dt) = eRepeatParam3))
      return 1;
  }
  else if (eRepeat = 'Y2')
  {
  -- Every X day/weekday/weekend/... of Y-th month(s)
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

  if (eRepeat = 'D1')
  {
  -- Every N-th day(s)
    iInterval := eRepeatParam1;
    if (mod (datediff ('day', eEventStart, dtEnd), eRepeatParam1) = 0)
      return CAL.WA.event_checkNotDeletedOccurence (dt, eEventStart, eRepeatExceptions);
  }
  else if (eRepeat = 'D2')
  {
  -- Every week day
    iInterval := 1;
    tmp := dayofweek (dt);
    if ((tmp > 1) and (tmp < 7))
      return CAL.WA.event_checkNotDeletedOccurence (dt, eEventStart, eRepeatExceptions);
  }
  else if (eRepeat = 'W1')
  {
  -- Every N-th week on ...
    iInterval := 1;
    if (eRepeatParam2 = 0)
      eRepeatParam2 := bit_or (eRepeatParam2, power (2, dayofweek (eEventStart)-1));
    if (mod (datediff ('day', eEventStart, dtEnd) / 7, eRepeatParam1) = 0)
      if (bit_and (eRepeatParam2, power (2, CAL.WA.dt_WeekDay (dt, weekStarts)-1)))
        return CAL.WA.event_checkNotDeletedOccurence (dt, eEventStart, eRepeatExceptions);
  }
  else if (eRepeat = 'M1')
  {
  -- Every N-th day of M-th month(s)
    iInterval := eRepeatParam1;
    if (mod (datediff ('month', eEventStart, dtEnd), eRepeatParam1) = 0)
      if (dayofmonth (dt) = eRepeatParam2)
        return CAL.WA.event_checkNotDeletedOccurence (dt, eEventStart, eRepeatExceptions);
  }
  else if (eRepeat = 'M2')
  {
  -- Every X day/weekday/weekend/... of Y-th month(s)
    iInterval := eRepeatParam1;
    if (mod (datediff ('month', eEventStart, dtEnd), eRepeatParam1) = 0)
      if (dayofmonth (dt) = CAL.WA.event_findDay (dt, eRepeatParam2, eRepeatParam3))
        return CAL.WA.event_checkNotDeletedOccurence (dt, eEventStart, eRepeatExceptions);
  }
  else if (eRepeat = 'Y1')
  {
    iInterval := eRepeatParam1;
    if (mod (datediff ('year', eEventStart, dtEnd), eRepeatParam1) = 0)
      if ((month (dt) = eRepeatParam2) and (dayofmonth (dt) = eRepeatParam3))
        return CAL.WA.event_checkNotDeletedOccurence (dt, eEventStart, eRepeatExceptions);
  }
  else if (eRepeat = 'Y2')
  {
  -- Every X day/weekday/weekend/... of Y-th month(s)
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
  in pTaskMode integer := 0,
  in pRights varchar := '')
{
  declare dt_offset, dtTimezone, dtDaylight, account_id integer;
  declare dtWeekStarts varchar;
  declare dt, dtStart, dtEnd, tzDT, tzEventStart, tzRepeatUntil date;

  declare c0, c1, c6, c7, c8 integer;
  declare c2, c5 varchar;
  declare c3, c4 datetime;
  result_names (c0, c1, c2, c3, c4, c5, c6, c7);

  dtTimezone := CAL.WA.settings_timeZone2 (pDomainID);
  dtWeekStarts := CAL.WA.settings_weekStarts2 (pDomainID);
  dtDaylight := CAL.WA.settings_daylight2 (pDomainID);

  dtStart := CAL.WA.event_user2gmt (CAL.WA.dt_dateClear (pDateStart), dtTimezone, dtDaylight);
  dtEnd := CAL.WA.event_user2gmt (dateadd ('day', 1, CAL.WA.dt_dateClear (pDateEnd)), dtTimezone, dtDaylight);
  account_id := CAL.WA.domain_owner_id (pDomainID);

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
            and CAL.WA.event_check_privacy (pDomainID, account_id, a.E_DOMAIN_ID, a.E_ID, a.E_PRIVACY)
            and a.E_KIND = 1
            and a.E_EVENT_START <  dtEnd
            and a.E_EVENT_END   > dtStart
            and ((pRights <> '') or
                 (is_https_ctx () and
                  (SIOC..calendar_event_iri (pDomainID, a.E_ID) in (select x.iri from CAL.WA.acl_list (id)(iri varchar) x where x.id = pDomainID))
                  )
                )) do
    {
      result (E_ID,
              E_EVENT,
              E_SUBJECT,
              CAL.WA.event_gmt2user (E_EVENT_START, dtTimezone, dtDaylight),
              CAL.WA.event_gmt2user (E_EVENT_END, dtTimezone, dtDaylight),
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
          and CAL.WA.event_check_privacy (pDomainID, account_id, a.E_DOMAIN_ID, a.E_ID, a.E_PRIVACY)
          and a.E_KIND = 0
          and (a.E_REPEAT = '' or a.E_REPEAT is null)
          and a.E_EVENT_START < dtEnd
          and a.E_EVENT_END   > dtStart
          and ((pRights <> '') or
               (is_https_ctx () and
                (SIOC..calendar_event_iri (pDomainID, a.E_ID) in (select x.iri from CAL.WA.acl_list (id)(iri varchar) x where x.id = pDomainID))
               )
              )) do
  {
    result (E_ID,
            E_EVENT,
            E_SUBJECT,
            CAL.WA.event_gmt2user (E_EVENT_START, dtTimezone, dtDaylight),
            CAL.WA.event_gmt2user (E_EVENT_END, dtTimezone, dtDaylight),
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
          and CAL.WA.event_check_privacy (pDomainID, account_id, a.E_DOMAIN_ID, a.E_ID, a.E_PRIVACY)
          and a.E_KIND = 0
          and a.E_REPEAT <> ''
          and a.E_EVENT_START < dtEnd
          and ((a.E_REPEAT_UNTIL is null) or (a.E_REPEAT_UNTIL >= dtStart))
          and ((pRights <> '') or
               (is_https_ctx () and
                (SIOC..calendar_event_iri (pDomainID, a.E_ID) in (select x.iri from CAL.WA.acl_list (id)(iri varchar) x where x.id = pDomainID))
               )
              )) do
  {
    tzEventStart := CAL.WA.event_gmt2user (E_EVENT_START, dtTimezone, dtDaylight);
    tzRepeatUntil := CAL.WA.event_gmt2user (E_REPEAT_UNTIL, dtTimezone, dtDaylight);
    dt := dtStart;
      while (dt < dtEnd)
      {
      tzDT := CAL.WA.event_gmt2user (dt, dtTimezone, dtDaylight);
      if (CAL.WA.event_occurAtDate (dt,
                                    E_EVENT,
                                    E_EVENT_START,
                                    E_REPEAT,
                                    E_REPEAT_PARAM1,
                                    E_REPEAT_PARAM2,
                                    E_REPEAT_PARAM3,
                                    E_REPEAT_UNTIL,
                                    E_REPEAT_EXCEPTIONS,
                                      dtWeekStarts)) {
          if (E_EVENT = 1)
          {
          dt_offset := datediff ('hour', dateadd ('hour', -12, E_EVENT_START), dt);
        } else {
          dt_offset := datediff ('hour', E_EVENT_START, dateadd ('second', 86399, dt));
        }
        dt_offset := floor (dt_offset / 24);
        result (E_ID,
                E_EVENT,
                E_SUBJECT,
                CAL.WA.event_gmt2user (dateadd ('day', dt_offset, E_EVENT_START), dtTimezone, dtDaylight),
                CAL.WA.event_gmt2user (dateadd ('day', dt_offset, E_EVENT_END), dtTimezone, dtDaylight),
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
  if (id = -1)
  {
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
  }
  else
  {
    declare exit handler for SQLSTATE '*', not found {
      return -1;
    };
    declare _subject varchar;
    declare _description varchar;
    declare _privacy integer;
    declare _tags varchar;
    declare _eEventStart datetime;
    declare _eEventEnd datetime;
    declare _priority integer;
    declare _status varchar;
    declare _complete integer;
    declare _completed datetime;
    declare _notes varchar;

    select
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
           E_NOTES
      into _subject,
           _description,
           _privacy,
           _tags,
           _eEventStart,
           _eEventEnd,
           _priority,
           _status,
           _complete,
           _completed,
           _notes
      from CAL.WA.EVENTS
     where E_ID = id;

    if (
        (coalesce (subject,     '')     = coalesce (_subject,     ''))     and
        (coalesce (description, '')     = coalesce (_description, ''))     and
        (coalesce (privacy,     -1)     = coalesce (_privacy,     -1))     and
        (coalesce (tags,        '')     = coalesce (_tags,        ''))     and
        (coalesce (eEventStart, now ()) = coalesce (_eEventStart, now ())) and
        (coalesce (eEventEnd,   now ()) = coalesce (_eEventEnd,   now ())) and
        (coalesce (priority,    -1)     = coalesce (_priority,    -1))     and
        (coalesce (status,      '')     = coalesce (_status,      ''))     and
        (coalesce (complete,    -1)     = coalesce (_complete,    -1))     and
        (coalesce (completed,   now ()) = coalesce (_completed,   now ())) and
        (coalesce (notes,       '')     = coalesce (_notes,       ''))
       )
      goto _end;
      if (status is null)
	status := _status;
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
_end:;
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

  V := CAL.WA.string2mails (attendees);
  for (select AT_ID as _id, AT_MAIL as _mail from CAL.WA.ATTENDEES where AT_EVENT_ID = id) do
  {
    for (N := 0; N < length (V); N := N + 1)
    {
      if (V[N][1] = _mail)
      delete from CAL.WA.ATTENDEES where AT_ID = _id;
  }
  }
  for (N := 0; N < length (V); N := N + 1)
  {
    mail := V[N][1];
    if (not is_empty_or_null (mail))
    {
      attendees_id := (select AT_ID from CAL.WA.ATTENDEES where AT_EVENT_ID = id and AT_MAIL = mail);
      if (isnull (attendees_id))
      {
        insert into CAL.WA.ATTENDEES (AT_UID, AT_EVENT_ID, AT_ROLE, AT_NAME, AT_MAIL)
          values (CAL.WA.uid (), id, 'REQ-PARTICIPANT', V[N][0], V[N][1]);
      }
    }
  }
}
;

-------------------------------------------------------------------------------
--
create procedure CAL.WA.attendees_update2 (
  in id integer,
  in attendees any,
  in mailAttendees any := 2)
{
  declare N, attendees_id integer;
  declare mail, status varchar;

  for (N := 0; N < length (attendees); N := N + 1)
  {
    mail := attendees[N][1];
    if (not is_empty_or_null (mail))
    {
      attendees_id := (select AT_ID from CAL.WA.ATTENDEES where AT_EVENT_ID = id and AT_MAIL = mail);
      if (isnull (attendees_id))
      {
        status := attendees[N][3];
        if (mailAttendees = 1)
        {
          status := null;
        }
        else if ((mailAttendees = 2) and status is null)
        {
          status := 'N';
        }
        insert into CAL.WA.ATTENDEES (AT_UID, AT_EVENT_ID, AT_ROLE, AT_NAME, AT_MAIL, AT_STATUS)
          values (CAL.WA.uid (), id, attendees[N][0], attendees[N][1], attendees[N][2], status);
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
  for (select AT_NAME, AT_MAIL from CAL.WA.ATTENDEES where AT_EVENT_ID = id) do
  {
    attendees := attendees || ',' || CAL.WA.mail2string (AT_NAME, AT_MAIL);
  }
  return trim (attendees, ',');
}
;

-------------------------------------------------------------------------------
--
create procedure CAL.WA.attendees_select (
  in id integer,
  in status any := null)
{
  declare attendees any;

  vectorbld_init (attendees);
  for (select * from CAL.WA.ATTENDEES where AT_EVENT_ID = id and ((coalesce (AT_STATUS, 'N') = status) or (status is null)) order by AT_MAIL) do
  {
    vectorbld_acc (attendees, vector (AT_ROLE, AT_NAME, AT_MAIL, AT_STATUS, coalesce (AT_DATE_REQUEST, AT_DATE_RESPOND)));
  }
  vectorbld_final (attendees);
  return attendees;
}
;

-------------------------------------------------------------------------------
--
create procedure CAL.WA.attendees_mails ()
{
  declare save_id, account_id, domain_id, mailAttendees integer;
  declare T, H varchar;
  declare dateFormat, timeFormat varchar;
  declare url, domain, account_mail, subject, period, subject_mail, content_text, content_html, content_ical varchar;

  H := '<table cellspacing="0" cellpadding="0" border="0" width="600px"> ' ||
       '  <tr> ' ||
       '    <td><b>ODS Calendar</b></td> ' ||
       '    <td nowrap="nowrap">%V</td> ' ||
       '  </tr> ' ||
       '  <tr> ' ||
       '    <td><b>Reason</b></td> ' ||
       '    <td nowrap="nowrap">Meeting Request</td> ' ||
       '  </tr> ' ||
       '  <tr> ' ||
       '    <td colspan="2"><br /></td> ' ||
       '  </tr> ' ||
       '        <tr> ' ||
       '          <td><b>Subject</b></td>  ' ||
       '    <td>%V</td> ' ||
       '        </tr> ' ||
       '        <tr> ' ||
       '          <td><b>When</b></td> ' ||
       '    <td>%s<br /></td> ' ||
       '        </tr> ' ||
       '        <tr> ' ||
       '          <td><b>Please RSVP</b></td> ' ||
       '    <td><a href="%s&a=A" target="new"><b>Accept</b></a>&nbsp;<a href="%s&a=D" target="new"><b>Decline</b></a>&nbsp;<a href="%s&a=T" target="new"><b>Tentative</b></a></td> ' ||
       '        </tr> ' ||
       '  <tr> ' ||
       '    <td></td> ' ||
       '    <td><br /><a href="%s" target="new"><b>Details</b></a></td> ' ||
       '  </tr> ' ||
       '  <tr> ' ||
       '    <td colspan="2"><br /><font size="1"> ' ||
       '      <br />' ||
       '      If the link appears to be inactive, just cut and paste it into a browser location bar and click Enter ' ||
       '      <br />----------------------<br /> ' ||
       '      <a href="%s" target="new">%s</a> ' ||
       '      <br />----------------------<br /></font>' ||
       '	  </td> ' ||
       '  </tr> ' ||
       '</table> ';
  T := ' ODS Calendar: Meeting Request\n\n\n' ||
       ' Subject: %s\n' ||
       ' When: %s\n' ||
       ' Please RSVP: %s\n';

  save_id := -1;
  for (select AT_ID as id, AT_UID as uid, AT_EVENT_ID as event_id, AT_MAIL as mail
         from CAL.WA.ATTENDEES
        where AT_DATE_REQUEST is null
          and AT_STATUS is null
        order by AT_EVENT_ID) do
  {
    if (save_id <> event_id)
    {
      for (select * from CAL.WA.EVENTS where E_ID = event_id) do
      {
        domain_id := E_DOMAIN_ID;
        mailAttendees := CAL.WA.settings_mailAttendees (CAL.WA.settings (domain_id));
        if (not mailAttendees)
      	  goto _next;
      	if ((E_EVENT_END < now ()) and (E_REPEAT = '' or E_REPEAT is null))
      	  goto _next;
        if (E_REPEAT_UNTIL < now ())
      	  goto _next;
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
      save_id := event_id;
      domain := CAL.WA.domain_name (domain_id);
      account_id := CAL.WA.domain_owner_id (domain_id);
      account_mail := CAL.WA.account_mail (account_id);
    }

    declare exit handler for sqlstate '*'
    {
      update CAL.WA.ATTENDEES
         set AT_LOG = __SQL_MESSAGE
       where AT_ID = id;
      goto _next;
    };

    url := sprintf ('%sattendees.vspx?uid=%U', CAL.WA.calendar_url (domain_id), uid);
    content_html := sprintf (H, domain, subject, period, url, url, url, url, url, url);
    content_text := sprintf (T, subject, period, url);
    content_ical := CAL.WA.export_vcal (domain_id, vector (save_id));

    CAL.WA.send_mail (account_mail, mail, subject_mail, content_text, content_html, content_ical);
    update CAL.WA.ATTENDEES
       set AT_DATE_REQUEST = now (),
           AT_STATUS = 'N'
     where AT_ID = id;

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
  in _message_html any,
  in _message_ical any)
{
  declare _smtp_server, _mail_body, _mail_body_text, _mail_body_html, _mail_body_ical, _encoded, _date any;

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
  _mail_body_ical := mime_part ('application/ics; name="invite.ics"', 'attachment; filename="invite.ics"', 'base64', _message_ical);
  _mail_body := _date || _subject || mime_body (vector (_mail_body_html, _mail_body_text, _mail_body_ical));

  if(not _smtp_server or length(_smtp_server) = 0)
    signal('WA002', 'The Mail Server is not defined. Mail can not be sent.');

  smtp_send (_smtp_server, _from, _to, _mail_body);
}
;

-------------------------------------------------------------------------------
--
-- Searches
--
-------------------------------------------------------------------------------
create procedure CAL.WA.search_sql (
  in domain_id integer,
  in privacy integer,
  in data varchar,
  in account_rights varchar := '')
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
       '       a.E_LOCATION,                 \n' ||
       '       a.E_ATTENDEES,                \n' ||
       '       a.E_COMPLETED,                \n' ||
       '       a.E_STATUS,                   \n' ||
       '       a.E_PRIORITY,                 \n' ||
       '       a.E_CREATED,                  \n' ||
       '       a.E_UPDATED                   \n' ||
       ' from  CAL.WA.EVENTS a,              \n' ||
       '       CAL..MY_CALENDARS b           \n' ||
       ' where b.domain_id = <DOMAIN_ID>     \n' ||
       '   and b.privacy = <PRIVACY>         \n' ||
       '   and a.E_DOMAIN_ID = b.CALENDAR_ID \n' ||
       '   and CAL.WA.event_check_privacy (<DOMAIN_ID>, <ACCOUNT_ID>, a.E_DOMAIN_ID, a.E_ID, a.E_PRIVACY) <TEXT> <TAGS> <WHERE> \n';

  if (account_rights = '')
  {
    if (is_https_ctx ())
    {
      S := S || ' and SIOC..calendar_event_iri (<DOMAIN_ID>, a.E_ID) in (select x.iri from CAL.WA.acl_list (id)(iri varchar) x where x.id = <DOMAIN_ID>)';
    } else {
      S := S || ' and 1=0';
    }
  }
  if (not isnull (data))
  {
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
  }
  S := replace (S, '<DOMAIN_ID>', cast (domain_id as varchar));
  S := replace (S, '<ACCOUNT_ID>', cast (CAL.WA.domain_owner_id (domain_id) as varchar));
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
    S := cast (xquery_eval (xmlPath || sprintf ('/val[%d]', N), xmlItem, 1) as varchar);
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
  declare S, dt, tzID, tzObject, tzStartRRule, tzEndRRule, tzOffset any;

  S := CAL.WA.vcal_str (xmlItem, xmlPath);
  dt := CAL.WA.vcal_iso2date (S);
  if ((not isnull (dt)) and (not isnull (tzDict)) and (chr (S[length(S)-1]) <> 'Z'))
  {
    tzID := cast (xquery_eval (xmlPath || '/TZID', xmlItem, 1) as varchar);
    if (not isnull (tzID))
    {
      tzObject := dict_get (tzDict, tzID, null);
      if (isnull (tzObject))
        goto _exit;

      tzOffset := get_keyword ('standartFrom', tzObject);
      if (isnull (tzOffset))
        goto _exit;

      tzStartRRule := get_keyword ('daylightRRule', tzObject);
      if (isnull (tzStartRRule))
        goto _exit;

        tzEndRRule := get_keyword ('standartRRule', tzObject);
        if (CAL.WA.event_daylightCheck (dt, tzStartRRule, tzEndRRule))
          tzOffset := get_keyword ('daylightTo', tzObject);

        dt := dateadd ('minute', tzOffset, dt);
      }
    }
_exit:;
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
  declare S, V, W any;

  V := vector ('Not Started', 'In Progress', 'Completed', 'Waiting', 'Deferred');
  W := vector ('NEEDS-ACTION', 'IN-PROCESS', 'COMPLETED', 'DELEGATED', 'DECLINED');
  S := CAL.WA.vcal_str (xmlItem, xmlPath);
  for (N := 0; N < length (V); N := N + 1)
    if (lcase (S) = lcase (V[N]) or lcase (S) = lcase (W[N]))
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

  V := vector ('SHARED', 2, 'PUBLIC', 1, 'PRIVATE', 0);
  S := CAL.WA.vcal_str (xmlItem, xmlPath);
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
  return CAL.WA.dt_format (dt, 'YMDTHNSZ');
  --return CAL.WA.dt_format (dateadd ('minute', -timezone (now ()), dt), 'YMDTHNSZ');
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
  declare V, weekdays, ruleParams any;

  weekdays := vector ('MO', 'TU', 'WE', 'TH', 'FR', 'SA', 'SU');
  eRepeat := '';
  eRepeatParam1 := null;
  eRepeatParam2 := null;
  eRepeatParam3 := null;
  eRepeatUntil := null;

  V := vector ();
  ruleParams := xquery_eval (xmlPath || '/fld', xmlItem, 0);
  if (length (ruleParams) = 0)
    ruleParams := xquery_eval (xmlPath || '/val', xmlItem, 0);
  foreach (any ruleParam in ruleParams) do
  {
    S := cast (xpath_eval ('.', ruleParam) as varchar);
    V := vector_concat (V, split_and_decode (S, 1, '\0\0;='));
  }

  if (length (V) = 0)
    return;

  -- daily rule
  if (get_keyword ('FREQ', V) = 'DAILY')
  {
    T := get_keyword ('BYDAY', V);
    if (isnull (T))
    {
    eRepeat := 'D1';
    eRepeatParam1 := cast (get_keyword ('INTERVAL', V, '1') as integer);
    } else {
      eRepeat := 'D2';
      eRepeatParam1 := cast (get_keyword ('INTERVAL', V, '1') as integer);
      eRepeatParam2 := 0;
      {
        T := split_and_decode (T, 0, '\0\0,');
        for (N := 0; N < length (T); N := N + 1)
        {
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
  }
  else if (get_keyword ('FREQ', V) = 'WEEKLY')
  {
    eRepeat := 'W1';
    eRepeatParam1 := cast (get_keyword ('INTERVAL', V, '1') as integer);
    eRepeatParam2 := 0;
    T := get_keyword ('BYDAY', V);
    if (not isnull (T))
    {
      T := split_and_decode (T, 0, '\0\0,');
      for (N := 0; N < length (T); N := N + 1)
      {
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
  else if (get_keyword ('FREQ', V) = 'MONTHLY')
  {
    if (isnull (get_keyword ('BYDAY', V)))
    {
    eRepeat := 'M1';
    eRepeatParam1 := cast (get_keyword ('INTERVAL', V, '1') as integer);
    eRepeatParam2 := cast (get_keyword ('BYMONTHDAY', V, '1') as integer);
    } else {
      eRepeat := 'M2';
      eRepeatParam1 := cast (get_keyword ('INTERVAL', V, '1') as integer);
      S := get_keyword ('BYDAY', V);
      T := subseq (S, length (S)-2);
      eRepeatParam3 := CAL.WA.vector_indexOf(weekdays, T);
      if (isinteger (eRepeatParam3))
        eRepeatParam3 := eRepeatParam3 + 1;
      eRepeatParam2 := cast (subseq (S, 0, length (S)-2) as integer);
      if (eRepeatParam2 = -1)
        eRepeatParam2 := 5;
    }
  }
  else if (get_keyword ('FREQ', V) = 'YEARLY')
  {
    if (isnull (get_keyword ('BYDAY', V)))
    {
    eRepeat := 'Y1';
    eRepeatParam1 := cast (get_keyword ('INTERVAL', V, '1') as integer);
    eRepeatParam2 := cast (get_keyword ('BYMONTH', V, '1') as integer);
    eRepeatParam3 := cast (get_keyword ('BYMONTHDAY', V, '1') as integer);
    } else {
      eRepeat := 'Y2';
      eRepeatParam3 := cast (get_keyword ('BYMONTH', V, '1') as integer);
      S := get_keyword ('BYDAY', V);
      T := subseq (S, length (S)-2);
      eRepeatParam2 := CAL.WA.vector_indexOf(weekdays, T);
      if (isinteger (eRepeatParam2))
        eRepeatParam2 := eRepeatParam2 + 1;
      eRepeatParam1 := cast (subseq (S, 0, length (S)-2) as integer);
      if (eRepeatParam1 = -1)
        eRepeatParam1 := 5;
    }
  }
  eRepeatUntil := CAL.WA.vcal_iso2date (get_keyword ('UNTIL', V));
}
;

-------------------------------------------------------------------------------
--
create procedure CAL.WA.vcal_recurrenceByDay2str (
  in repeatValue integer)
{
  if (repeatValue = 5)
    return '-1';

  return '+' || cast (repeatValue as varchar);
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
  declare weekdays any;


  if (is_empty_or_null (eRepeat))
    return null;

  weekdays := vector ('MO', 'TU', 'WE', 'TH', 'FR', 'SA', 'SU');
  S := null;
  if (eRepeat = 'D1')
  {
    S := 'FREQ=DAILY'
      || ';INTERVAL=' || cast (eRepeatParam1 as varchar);
  }
  else if (eRepeat = 'D2')
  {
    S := 'FREQ=DAILY;BYDAY=MO,TU,WE,TH,FR';
  }
  else if (eRepeat = 'W1')
  {
    S := 'FREQ=WEEKLY';
    S := S || ';INTERVAL=' || cast (eRepeatParam1 as varchar);
    if (eRepeatParam2 <> 0)
    {
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
  }
  else if (eRepeat = 'M1')
  {
    S := 'FREQ=MONTHLY'
      || ';INTERVAL='   || cast (eRepeatParam1 as varchar)
      || ';BYMONTHDAY=' || cast (eRepeatParam2 as varchar);
  }
  else if (eRepeat = 'M2')
  {
    S := 'FREQ=MONTHLY'
      || ';INTERVAL='   || cast (eRepeatParam1 as varchar);
    if (eRepeatParam3 = 10)
    {
      S := S || ';BYMONTHDAY=' || CAL.WA.vcal_recurrenceByDay2str(eRepeatParam2);
  }
    else if ((eRepeatParam3 >= 1) and (eRepeatParam3 <= 7))
    {
      S := S || ';BYDAY=' || CAL.WA.vcal_recurrenceByDay2str(eRepeatParam2) || weekdays[eRepeatParam3-1];
  }
  }
  else if (eRepeat = 'Y1')
  {
    S := 'FREQ=YEARLY'
      || ';INTERVAL='   || cast (eRepeatParam1 as varchar)
      || ';BYMONTH='    || cast (eRepeatParam2 as varchar)
      || ';BYMONTHDAY=' || cast (eRepeatParam3 as varchar);
  }
  else if (eRepeat = 'Y2')
  {
    S := 'FREQ=YEARLY'
      || ';BYMONTH='    || cast (eRepeatParam3 as varchar);
    if (eRepeatParam2 = 10)
    {
      S := S || ';BYMONTHDAY=' || CAL.WA.vcal_recurrenceByDay2str(eRepeatParam1);
    }
    else if ((eRepeatParam2 >= 1) and (eRepeatParam2 <= 7))
    {
      S := S || ';BYDAY=' || CAL.WA.vcal_recurrenceByDay2str(eRepeatParam1) || weekdays[eRepeatParam2-1];
    }
  }
  if (not isnull (S) and not isnull (eRepeatUntil))
    S := S || ';UNTIL=' || CAL.WA.vcal_date2str (eRepeatUntil);

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
create procedure CAL.WA.vcal_tzDecode (
  in xmlItem any,
  in xmlPath varchar)
{
  declare S varchar;

  S := CAL.WA.vcal_str (xmlItem, xmlPath);
  return CAL.WA.tz_decode (S);
}
;

-------------------------------------------------------------------------------
--
create procedure CAL.WA.export_vcal_privacy (
  in privacy integer,
  inout sStream any)
{
  declare V any;

  if (is_empty_or_null (privacy))
    return;

  V := vector (2, 'SHARED', 1, 'PUBLIC', 0, 'PRIVATE');
  http (sprintf ('CLASS:%s\r\n', get_keyword (privacy, V)), sStream);
}
;

-------------------------------------------------------------------------------
--
create procedure CAL.WA.export_vcal_reminder (
  in eReminder integer,
  inout sStream any)
{
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
create procedure CAL.WA.export_vcal_attendees (
  in eID integer,
  in eDomainID integer,
  in eAttendees integer,
  inout sStream any)
{
  declare N, L, account_id, accountFounded integer;
  declare accountMail varchar;
  declare V any;

  if (is_empty_or_null (eAttendees))
    return;

  accountFounded := 0;
  account_id := CAL.WA.domain_owner_id (eDomainID);
  accountMail := CAL.WA.account_mail (account_id);
  V := CAL.WA.attendees_select (eID);
  L := length (V);
  for (N := 0; N < L; N := N + 1)
  {
    if (accountMail = V[N][1])
      accountFounded := 1;
    CAL.WA.export_vcal_attendees_line (V[N][0], V[N][1], V[N][2], V[N][3], sStream);
  }
  if (not accountFounded)
    CAL.WA.export_vcal_attendees_line ('REQ-PARTICIPANT', CAL.WA.account_fullName (account_id), accountMail, 'A', sStream);
}
;

-------------------------------------------------------------------------------
--
create procedure CAL.WA.export_vcal_attendees_line (
  in attendeeRole varchar,
  in attendeeName varchar,
  in attendeeMail varchar,
  in attendeeStatus varchar,
  inout sStream any)
{
  declare S, T varchar;
  declare X any;

  X := vector ('A', 'ACCEPTED', 'D', 'DECLINED', 'T', 'TENTATIVE');
  T := get_keyword (attendeeStatus, X, 'NEEDS-ACTION');
  S := case when (is_empty_or_null (attendeeName)) then '' else ';CN=' || attendeeName end;
  http (sprintf ('ATTENDEE;CUTYPE=INDIVIDUAL;ROLE=%s;PARTSTAT=%s%s:mailto:%s\r\n', attendeeRole, T, S, attendeeMail), sStream);
}
;

----------------------------------------------------------------------
--
create procedure CAL.WA.export_vcal_line (
  in property varchar,
  in value any,
  inout sStream any)
{
  declare prefix varchar;
  declare tmp any;

  if (is_empty_or_null (value))
    return;

  prefix := '';
  tmp := CAL.WA.utf2wide(sprintf ('%s:%s', property, replace(replace (cast (value as varchar), '\n', '\\n'), '\r', '')));
  while (length (tmp) > length (prefix))
  {
	http_escape(CAL.WA.wide2utf(subseq (tmp, 0, 60)) || '\r\n', 1, sStream, 1, 1);
    if (length (tmp) > 60)
    {
      tmp := prefix || subseq (tmp, 60);
    }
    else
    {
      tmp := '';
    }
    prefix := ' ';
  }
}
;

----------------------------------------------------------------------
--
create procedure CAL.WA.export_vcal (
  in domain_id integer,
  in entries any := null,
  in options any := null)
{
  declare tz, toTz, fromTz, daylight integer;
  declare oEvents, oTasks, oPeriodFrom, oPeriodTo, oTagsInclude, oTagsExclude any;
  declare S, url, tzID, tzName, tzName2 varchar;
  declare startRRule, endRRule any;
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
  daylight := CAL.WA.settings_daylight2 (domain_id);
  url := sprintf ('http://%s%s/%U/calendar/%U/', SIOC.DBA.get_cname(), SIOC.DBA.get_base_path (), CAL.WA.domain_owner_name (domain_id), CAL.WA.domain_name (domain_id));
  -- tzID := sprintf ('GMT%s%04d', case when cast (tz as integer) < 0 then '-' else '+' end,  tz);
  tzID := CAL.WA.settings_timeZoneName2 (domain_id);
  tzName := sprintf ('GMT %s%02d:00', case when cast (tz as integer) < 0 then '-' else '+' end,  abs(floor (tz / 60)));
  tzName2 := sprintf ('GMT %s%02d:00', case when cast ((tz+60) as integer) < 0 then '-' else '+' end,  abs(floor ((tz+60) / 60)));

  sStream := string_output();

  -- start
  http ('BEGIN:VCALENDAR\r\n', sStream);
  http (sprintf ('PRODID:-//OpenLink Software Ltd//ODS Calendar %s//EN\r\n', registry_get('calendar_version')), sStream);
  http ('VERSION:2.0\r\n', sStream);
  http (sprintf ('X-WR-CALNAME:%s\r\n', CAL.WA.domain_name (domain_id)), sStream);

  http ('BEGIN:VTIMEZONE\r\n', sStream);
  http (sprintf ('TZID:%s\r\n', tzID), sStream);
  CAL.WA.dt_daylightRRules(daylight, startRRule, endRRule);
  fromTz := tz;
  toTz := tz;
  if (startRRule)
  {
    fromTz := tz;
    toTz := tz + 60;
    http ('BEGIN:DAYLIGHT\r\n', sStream);
    http (sprintf ('TZOFFSETFROM:%s\r\n', CAL.WA.tz_string (fromTz)), sStream);
    http (sprintf ('TZOFFSETTO:%s\r\n', CAL.WA.tz_string (toTz)), sStream);
    http (sprintf ('TZNAME:%s\r\n', tzName2), sStream);
    http ('DTSTART:19700329T020000\r\n', sStream);
    CAL.WA.export_vcal_line ('RRULE', CAL.WA.vcal_recurrence2str (startRRule[0], startRRule[1], startRRule[2], startRRule[3], startRRule[4]), sStream);
    http ('END:DAYLIGHT\r\n', sStream);
    fromTz := tz + 60;
    toTz := tz;
  }
  http ('BEGIN:STANDARD\r\n', sStream);
  http (sprintf ('TZOFFSETFROM:%s\r\n', CAL.WA.tz_string (fromTz)), sStream);
  http (sprintf ('TZOFFSETTO:%s\r\n', CAL.WA.tz_string (toTz)), sStream);
  http (sprintf ('TZNAME:%s\r\n', tzName), sStream);
  if (endRRule)
  {
  http ('DTSTART:19700101T000000\r\n', sStream);
    CAL.WA.export_vcal_line ('RRULE', CAL.WA.vcal_recurrence2str (endRRule[0], endRRule[1], endRRule[2], endRRule[3], endRRule[4]), sStream);
  }
  http ('END:STANDARD\r\n', sStream);
  http ('END:VTIMEZONE\r\n', sStream);

  -- events
  if (oEvents)
  {
    for (select * from CAL.WA.EVENTS where E_DOMAIN_ID = domain_id and E_KIND = 0 and (entries is null or CAL.WA.vector_contains (entries, E_ID))) do
    {
      if (CAL.WA.dt_exchangeTest (oPeriodFrom, oPeriodTo, CAL.WA.event_gmt2user (E_EVENT_START, tz, daylight), CAL.WA.event_gmt2user (E_EVENT_END, tz, daylight), E_REPEAT_UNTIL) and CAL.WA.tags_exchangeTest (E_TAGS, oTagsInclude, oTagsExclude))
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
          CAL.WA.export_vcal_line ('DTSTART;VALUE=DATE', CAL.WA.vcal_date2str (CAL.WA.event_gmt2user (E_EVENT_START, tz, daylight)), sStream);
          CAL.WA.export_vcal_line ('DTEND;VALUE=DATE', CAL.WA.vcal_date2str (CAL.WA.event_gmt2user (E_EVENT_END, tz, daylight)), sStream);
        } else {
          CAL.WA.export_vcal_line (sprintf ('DTSTART;TZID=%s', tzID), CAL.WA.vcal_datetime2str (CAL.WA.event_gmt2user (E_EVENT_START, tz, daylight)), sStream);
          CAL.WA.export_vcal_line (sprintf ('DTEND;TZID=%s', tzID), CAL.WA.vcal_datetime2str (CAL.WA.event_gmt2user (E_EVENT_END, tz, daylight)), sStream);
        }
        CAL.WA.export_vcal_line ('RRULE', CAL.WA.vcal_recurrence2str (E_REPEAT, E_REPEAT_PARAM1, E_REPEAT_PARAM2, E_REPEAT_PARAM3, E_REPEAT_UNTIL), sStream);
        CAL.WA.export_vcal_reminder (E_REMINDER, sStream);
        CAL.WA.export_vcal_attendees (E_ID, E_DOMAIN_ID, E_ATTENDEES, sStream);
        CAL.WA.export_vcal_line ('X-OL-NOTES', E_NOTES, sStream);
        CAL.WA.export_vcal_privacy (E_PRIVACY, sStream);
        http ('END:VEVENT\r\n', sStream);
      }
    }
  }

  -- tasks
  if (oTasks)
  {
    for (select * from CAL.WA.EVENTS where E_DOMAIN_ID = domain_id and E_KIND = 1 and ((entries is null) or CAL.WA.vector_contains (entries, E_ID))) do
    {
      if (CAL.WA.dt_exchangeTest (oPeriodFrom, oPeriodTo, CAL.WA.event_gmt2user (E_EVENT_START, tz, daylight), CAL.WA.event_gmt2user (E_EVENT_END, tz, daylight)) and CAL.WA.tags_exchangeTest (E_TAGS, oTagsInclude, oTagsExclude))
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
        CAL.WA.export_vcal_line ('DTSTART;VALUE=DATE', CAL.WA.vcal_date2str (CAL.WA.dt_dateClear (CAL.WA.event_gmt2user (E_EVENT_START, tz, daylight))), sStream);
        CAL.WA.export_vcal_line ('DUE;VALUE=DATE', CAL.WA.vcal_date2str (CAL.WA.dt_dateClear (CAL.WA.event_gmt2user (E_EVENT_END, tz, daylight))), sStream);
        CAL.WA.export_vcal_line ('COMPLETED;VALUE=DATE', CAL.WA.vcal_date2str (CAL.WA.dt_dateClear (CAL.WA.event_gmt2user (E_COMPLETED, tz, daylight))), sStream);
        CAL.WA.export_vcal_line ('PERCENT-COMPLETE', E_COMPLETE, sStream);
        CAL.WA.export_vcal_line ('PRIORITY', E_PRIORITY, sStream);
        declare tmp_value varchar;
        if (E_STATUS = 'Not Started')
          tmp_value := 'NEEDS-ACTION';
        else if (E_STATUS = 'In Progress')
          tmp_value := 'IN-PROCESS';
        else if (E_STATUS = 'Completed')
          tmp_value := 'COMPLETED';
        else if (E_STATUS = 'Waiting')
          tmp_value := 'DELEGATED';
        else if (E_STATUS = 'Deferred')
          tmp_value := 'DECLINED';
      	else
      	  tmp_value := 'NEEDS-ACTION';
        CAL.WA.export_vcal_line ('STATUS', tmp_value, sStream);
        CAL.WA.export_vcal_attendees (E_ID, E_DOMAIN_ID, E_ATTENDEES, sStream);
        CAL.WA.export_vcal_line ('X-OL-NOTES', E_NOTES, sStream);
        CAL.WA.export_vcal_privacy (E_PRIVACY, sStream);
        http ('END:VTODO\r\n', sStream);
      }
    }
  }

  -- end
  http ('END:VCALENDAR\r\n', sStream);

  return string_output_string (sStream);
}
;

-------------------------------------------------------------------------------
--
create procedure CAL.WA.import_vcal (
  in domain_id integer,
  in content any,
  in options any := null,
  in exchange_id integer := null,
  in updatedBefore integer := null)
{
  declare N, nLength integer;
  declare oEvents, oTasks, oTags, oSync, oMailAttendees any;
  declare tmp, xmlData, xmlItems, xmlTimezones, xmlEvents, itemName, V any;
  declare id,
          recurenceId,
          uid,
          subject,
          description,
          location,
          attendees,
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
  declare vcalVersion, vcalImported any;
  declare tzDict, tzID, tzOffset any;

  if (not isstring (content))
    content := cast (content as varchar);

  if (strstr (content, '<?xml') = 0)
    return CAL.WA.import_feed (domain_id, content, options, exchange_id, updatedBefore);

  vcalImported := vector ();

  -- options
  oEvents := 1;
  oTasks := 1;
  oTags := '';
  oSync := 0;
  oMailAttendees := 2;
  if (not isnull (options))
  {
    oEvents := cast (get_keyword ('events', options, oEvents) as integer);
    oTasks := cast (get_keyword ('tasks', options, oTasks) as integer);
    oTags := get_keyword ('tags', options, '');
    oSync := cast (get_keyword ('sync', options, oSync) as integer);
    oMailAttendees := cast (get_keyword ('mailAttendees', options, oMailAttendees) as integer);
  }

  -- using DAV parser
  xmlData := xml_tree_doc (DB.DBA.IMC_TO_XML (content));
  xmlItems := xpath_eval ('/*', xmlData, 0);
  foreach (any xmlItem in xmlItems) do
  {
    itemName := xpath_eval ('name(.)', xmlItem);
    if (itemName = 'IMC-VCALENDAR')
    {
      -- vCalendar version
      vcalVersion := CAL.WA.vcal_str (xmlItem, 'VERSION');

      -- timezone
      declare tzObject any;

      tzDict := dict_new();
      xmlTimezones := xpath_eval ('./IMC-VTIMEZONE', xmlItem, 0);
      foreach (any xmlTimezone in xmlTimezones) do
      {
        tzID := CAL.WA.vcal_str (xmlTimezone, 'TZID');
        if (not isnull (tzID))
        {
          tzObject := vector ();
          tzOffset := CAL.WA.vcal_tzDecode (xmlTimezone, 'IMC-STANDARD/TZOFFSETFROM');
          if (not isnull (tzOffset))
            tzObject := vector_concat (tzObject, vector ('standartFrom', tzOffset));

          tzOffset := CAL.WA.vcal_tzDecode (xmlTimezone, 'IMC-STANDARD/TZOFFSETTO');
          if (not isnull (tzOffset))
            tzObject := vector_concat (tzObject, vector ('standartTo', tzOffset));

          CAL.WA.vcal_str2recurrence (xmlTimezone, 'IMC-STANDARD/RRULE', eRepeat, eRepeatParam1, eRepeatParam2, eRepeatParam3, eRepeatUntil);
          tzObject := vector_concat (tzObject, vector ('standartRRule', vector (eRepeat, eRepeatParam1, eRepeatParam2, eRepeatParam3, eRepeatUntil)));

          tzOffset := CAL.WA.vcal_tzDecode (xmlTimezone, 'IMC-DAYLIGHT/TZOFFSETFROM');
          if (not isnull (tzOffset))
            tzObject := vector_concat (tzObject, vector ('daylightFrom', tzOffset));

          tzOffset := CAL.WA.vcal_tzDecode (xmlTimezone, 'IMC-DAYLIGHT/TZOFFSETTO');
          if (not isnull (tzOffset))
            tzObject := vector_concat (tzObject, vector ('daylightTo', tzOffset));

          CAL.WA.vcal_str2recurrence (xmlTimezone, 'IMC-DAYLIGHT/RRULE', eRepeat, eRepeatParam1, eRepeatParam2, eRepeatParam3, eRepeatUntil);
          tzObject := vector_concat (tzObject, vector ('daylightRRule', vector (eRepeat, eRepeatParam1, eRepeatParam2, eRepeatParam3, eRepeatUntil)));

          dict_put (tzDict, tzID, tzObject);
      }
      }

      -- events
      if (oEvents)
      {
        xmlEvents := xpath_eval ('./IMC-VEVENT', xmlItem, 0);
        foreach (any xmlEvent in xmlEvents) do
      {
          uid := CAL.WA.vcal_str (xmlEvent, 'UID');
          recurenceId := CAL.WA.vcal_str (xmlEvent, 'RECURRENCE-ID');
        id := coalesce ((select E_ID from CAL.WA.EVENTS where E_DOMAIN_ID = domain_id and E_UID = uid), -1);
          if ((id <> -1) and not isnull (recurenceId))
              goto _skip;
          if ((id <> -1) and not isnull (updatedBefore) and exists (select 1 from CAL.WA.EVENTS where E_ID = id and E_UPDATED >= updatedBefore))
            goto _skip;
          subject := CAL.WA.strDecode (CAL.WA.vcal_str (xmlEvent, 'SUMMARY'));
          description := CAL.WA.strDecode (CAL.WA.vcal_str (xmlEvent, 'DESCRIPTION'));
          location := CAL.WA.vcal_str (xmlEvent, 'LOCATION');
          privacy := CAL.WA.vcal_str2privacy (xmlEvent, 'CLASS');
        if (isnull (privacy))
          privacy := CAL.WA.domain_is_public (domain_id);
          eventTags := CAL.WA.tags_join (CAL.WA.vcal_str (xmlEvent, 'CATEGORIES'), oTags);
          eEventStart := CAL.WA.vcal_str2date (xmlEvent, 'DTSTART', tzDict);
          eEventEnd := CAL.WA.vcal_str2date (xmlEvent, 'DTEND', tzDict);
        if (isnull (eEventEnd))
            eEventEnd := CAL.WA.p_dateadd (eEventStart, CAL.WA.vcal_str (xmlEvent, 'DURATION'));
          event := case when (isnull (xquery_eval ('DTSTART/VALUE', xmlEvent, 1))) then 0 else 1 end;
          CAL.WA.vcal_str2recurrence (xmlEvent, 'RRULE', eRepeat, eRepeatParam1, eRepeatParam2, eRepeatParam3, eRepeatUntil);
          tmp := CAL.WA.vcal_str (xmlEvent, 'DALARM');
          eReminder := CAL.WA.vcal_str2reminder (xmlEvent, 'IMC-VALARM/TRIGGER');
          updated := case when isnull (updatedBefore) then CAL.WA.vcal_str2date (xmlEvent, 'DTSTAMP', tzDict) else null end;
          notes := CAL.WA.vcal_str (xmlEvent, 'X-OL-NOTES');
          connection_set ('__calendar_import', '1');
          id := CAL.WA.event_update
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
          if (not isnull (exchange_id))
            update CAL.WA.EVENTS set E_EXCHANGE_ID = exchange_id where E_ID = id;
          attendees := CAL.WA.import_vcal_attendees (xmlEvent, 'ATTENDEE');
          if (length (attendees))
            CAL.WA.attendees_update2 (id, attendees, oMailAttendees);
          connection_set ('__calendar_import', '0');
          vcalImported := vector_concat (vcalImported, vector (id));

        _skip:;
          commit work;
      }
      }

      if (oTasks)
      {
      -- tasks (todo)
        xmlEvents := xpath_eval ('./IMC-VTODO', xmlItem, 0);
        foreach (any xmlEvent in xmlEvents) do
      {
          uid := CAL.WA.vcal_str (xmlEvent, 'UID');
        id := coalesce ((select E_ID from CAL.WA.EVENTS where E_DOMAIN_ID = domain_id and E_UID = uid), -1);
          if ((id <> -1) and not isnull (updatedBefore) and exists (select 1 from CAL.WA.EVENTS where E_ID = id and E_UPDATED >= updatedBefore))
              goto _skip2;
          subject := CAL.WA.strDecode (CAL.WA.vcal_str (xmlEvent, 'SUMMARY'));
          description := CAL.WA.strDecode (CAL.WA.vcal_str (xmlEvent, 'DESCRIPTION'));
          privacy := CAL.WA.vcal_str2privacy (xmlEvent, 'CLASS');
        if (isnull (privacy))
          privacy := CAL.WA.domain_is_public (domain_id);
          eventTags := CAL.WA.tags_join (CAL.WA.vcal_str (xmlEvent, 'CATEGORIES'), oTags);
          eEventStart := CAL.WA.vcal_str2date (xmlEvent, 'DTSTART');
        eEventStart := CAL.WA.dt_join (eEventStart, CAL.WA.dt_timeEncode (12, 0));
          eEventEnd := CAL.WA.vcal_str2date (xmlEvent, 'DUE');
        eEventEnd := CAL.WA.dt_join (eEventEnd, CAL.WA.dt_timeEncode (12, 0));
          priority := CAL.WA.vcal_str (xmlEvent, 'PRIORITY');
        if (isnull (priority))
          priority := '3';
          status := CAL.WA.vcal_str2status (xmlEvent, 'STATUS');
          complete := CAL.WA.vcal_str (xmlEvent, 'PERCENT-COMPLETE');
          completed := CAL.WA.vcal_str2date (xmlEvent, 'COMPLETED');
        completed := CAL.WA.dt_join (completed, CAL.WA.dt_timeEncode (12, 0));
          updated := CAL.WA.vcal_str2date (xmlEvent, 'DTSTAMP', tzDict);
          notes := CAL.WA.vcal_str (xmlEvent, 'X-OL-NOTES');
          attendees := CAL.WA.import_vcal_attendees (xmlEvent, 'ATTENDEE');
          id := CAL.WA.import_task_update
          (
                  id,              -- id
                  uid,             -- uid
                  domain_id,       -- domain_id
                  subject,         -- subject
                  description,     -- description
                  null,            -- attendees
                  privacy,         -- privacy
                  eventTags,       -- tags
                  eEventStart,     -- eEventStart
                  eEventEnd,       -- eEventEnd
                  priority,        -- priority
                  status,          -- status
                  complete,        -- complete
                  completed,       -- completed
                  notes,           -- notes
                  updated,         -- updated
                  exchange_id,     -- exchange_id
                  updatedBefore,   -- updatedBefore
                  attendees,       -- attendees
                  oMailAttendees   -- mailAttendees
          );
          vcalImported := vector_concat (vcalImported, vector (id));

        _skip2:;
          commit work;
      }
    }
  }
}
  -- sync calendars
  if (oSync)
  {
    for (select EX_ID from CAL.WA.EXCHANGE where EX_DOMAIN_ID = domain_id and EX_TYPE = 0) do
    {
      CAL.WA.exchange_exec (EX_ID);
      commit work;
    }
  }
  return vcalImported;
}
;

--------------------------------------------------------------------------------
--
create procedure CAL.WA.import_vcal_attendees (
  in xmlItem any,
  in attendeePath varchar)
    {
  declare N, L integer;
  declare attendeeRole, attendeeName, attendeeMail, attendeeStatus varchar;
  declare retValue any;

  vectorbld_init (retValue);
  L := xpath_eval(sprintf ('count (%s)', attendeePath), xmlItem);
  for (N := 1; N <= L; N := N + 1)
  {
    attendeeRole := cast (xquery_eval (sprintf ('//ATTENDEE[%d]/ROLE', N), xmlItem) as varchar);
    attendeeName := cast (xquery_eval (sprintf ('%s[%d]/CN', attendeePath, N), xmlItem) as varchar);
    attendeeMail := cast (xquery_eval (sprintf ('//ATTENDEE[%d]/val', N), xmlItem) as varchar);
    attendeeStatus := cast (xquery_eval (sprintf ('//ATTENDEE[%d]/PARTSTAT', N), xmlItem) as varchar);
    if (not is_empty_or_null (attendeeMail))
      attendeeMail := replace (attendeeMail, 'mailto:', '');
    attendeeStatus := case when length (attendeeStatus) then left (attendeeStatus, 1) end;
    vectorbld_acc (retValue, vector (attendeeRole, attendeeName, attendeeMail, attendeeStatus));
    }
  vectorbld_final (retValue);
  return retValue;
}
;

--------------------------------------------------------------------------------
--
create procedure CAL.WA.import_CalDAV (
  in _domain_id integer,
  in _name any,
  in _options any := null)
{
  declare _user, _password varchar;
  declare _page, _body, _bodyTemplate, _resHeader, _reqHeader any;
  declare _xml, _items, _data any;

  _user := get_keyword ('user', _options);
  _password := get_keyword ('password', _options);
  _bodyTemplate :=
   '<?xml version="1.0" encoding="utf-8" ?>
    <C:calendar-multiget xmlns:D="DAV:" xmlns:C="urn:ietf:params:xml:ns:caldav">
      <D:prop>
        <D:getetag/>
        <C:calendar-data/>
      </D:prop>
      <D:href>%s</D:href>
    </C:calendar-multiget>';

  -- check CalDAV
  _reqHeader := 'Accept: text/xml\r\nContent-Type: text/xml; charset=utf-8';
  if (not is_empty_or_null (_user))
    _reqHeader := _reqHeader || sprintf ('\r\nAuthorization: Basic %s', encode_base64 (_user || ':' || _password));

  _page := http_client_ext (url=>_name, http_method=>'OPTIONS', http_headers=>_reqHeader, headers =>_resHeader, n_redirects=>15);
  CAL.WA.http_error (_resHeader);
  if (not (http_request_header (_resHeader, 'DAV') like '%calendar-access%'))
    signal ('CAL01', 'Bad import/subscription source!<>');

  _body := null;
  _reqHeader := _reqHeader || '\r\nDepth: 1';
  _page := http_client_ext (url=>_name, http_method=>'PROPFIND', http_headers=>_reqHeader, headers =>_resHeader, body=>_body, n_redirects=>15);
  CAL.WA.http_error (_resHeader);
  {
    declare exit handler for sqlstate '*'
    {
      signal ('CAL01', 'Bad import/subscription source!<>');
    };
    _xml := xml_tree_doc (xml_expand_refs (xml_tree (_page)));
		_items := xpath_eval ('[xmlns:D="DAV:" xmlns="urn:ietf:params:xml:ns:caldav:"] /D:multistatus/D:response/D:href/text()', _xml, 0);
		foreach (any _item in _items) do
		{
		  commit work;
      _body := sprintf (_bodyTemplate, cast (_item as varchar));
      _page := http_client_ext (url=>_name, http_method=>'REPORT', http_headers=>_reqHeader, headers =>_resHeader, body=>_body, n_redirects=>15);
      CAL.WA.http_error (_resHeader);
      _xml := xml_tree_doc (xml_expand_refs (xml_tree (_page)));
		  if (not isnull (xpath_eval ('[xmlns:D="DAV:" xmlns="urn:ietf:params:xml:ns:caldav:"] /D:multistatus/D:response/D:href/text()', _xml, 1)))
		  {
		    _data := cast (xpath_eval ('[xmlns:D="DAV:" xmlns="urn:ietf:params:xml:ns:caldav:"] /D:multistatus/D:response/D:propstat/D:prop/calendar-data/text()', _xml, 1) as varchar);
		    CAL.WA.import_vcal (_domain_id, _data, _options);
      }
	  }
  }
  return 1;
}
;

--------------------------------------------------------------------------------
--
create procedure CAL.WA.import_CalDAV_check (
  in _name any,
  in _options any,
  in _silent integer := 0)
{
  declare _user, _password varchar;
  declare _page, _body, _resHeader, _reqHeader any;
  declare exit handler for sqlstate '*'
  {
    return 0;
  };

  _user := get_keyword ('user', _options);
  _password := get_keyword ('password', _options);

  -- check CalDAV
  _reqHeader := 'Accept: text/xml\r\nContent-Type: text/xml; charset=utf-8';
  if (not is_empty_or_null (_user))
    _reqHeader := _reqHeader || sprintf ('\r\nAuthorization: Basic %s', encode_base64 (_user || ':' || _password));

  _page := http_client_ext (url=>_name, http_method=>'OPTIONS', http_headers=>_reqHeader, headers =>_resHeader, n_redirects=>15);
  if (not CAL.WA.http_error (_resHeader, _silent))
    return 0;

  if (not (http_request_header (_resHeader, 'DAV') like '%calendar-access%'))
    return 0;

  return 1;
}
;

-------------------------------------------------------------------------------
--
create procedure CAL.WA.import_feed (
  in domain_id integer,
  in content any,
  in options any := null,
  in exchange_id integer := null,
  in updatedBefore integer := null)
{
  declare id integer;
  declare tags any;
  declare xt, items any;
  declare vcalImported any;

  vcalImported := vector ();

  -- options
  tags := '';
  if (not isnull (options))
    tags := get_keyword ('tags', options, '');

  xt := CAL.WA.string2xml (content);
  if (xpath_eval ('/rss/channel/item|/rss/item|/RDF/item|/Channel/items/item', xt) is not null)
  {
    -- RSS formats
    items := xpath_eval ('/rss/channel/item|/rss/item|/RDF/item|/Channel/items/item', xt, 0);
    foreach (any item in items) do
    {
      id := CAL.WA.import_feed_rss_item (domain_id, exchange_id, updatedBefore, tags, xml_cut (item));
      vcalImported := vector_concat (vcalImported, vector (id));
    }
  }
  else if (xpath_eval ('/feed/entry', xt) is not null)
  {
    -- Atom format
    items := xpath_eval ('/feed/entry', xt, 0);
    foreach (any item in items) do
    {
      id := CAL.WA.import_feed_atom_item (domain_id, exchange_id, updatedBefore, tags, xml_cut (item));
      vcalImported := vector_concat (vcalImported, vector (id));
    }
  }

  return vcalImported;
}
;

-------------------------------------------------------------------------------
--
create procedure CAL.WA.import_feed_rss_item (
  in domain_id integer,
  in exchange_id integer,
  in updatedBefore integer,
  in tags varchar,
  inout xt any)
{
  declare id integer;
  declare subject, description, link, uid, pubDate varchar;

  subject := serialize_to_UTF8_xml (xpath_eval ('string(/item/title)', xt, 1));
  description := xpath_eval ('[ xmlns:content="http://purl.org/rss/1.0/modules/content/" ] string(/item/content:encoded)', xt, 1);
  if (is_empty_or_null (description))
    description := xpath_eval ('string(/item/description)', xt, 1);
  description := serialize_to_UTF8_xml (description);

  link := cast (xpath_eval ('/item/link', xt, 1) as varchar);
  if (isnull (link))
  {
    link := cast (xpath_eval ('[xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"] /item/@rdf:about', xt, 1) as varchar);
    if ((isnull (link)) and isnull (cast(xpath_eval ('/item/guid[@isPermaLink = "false"]', xt, 1) as varchar)))
      link := cast (xpath_eval ('/item/guid', xt, 1) as varchar);
  }
  uid := cast (xpath_eval ('/item/guid', xt, 1) as varchar);
  pubDate := CAL.WA.dt_convert(cast (xpath_eval ('[ xmlns:dc="http://purl.org/dc/elements/1.1/" ] /item/dc:date', xt, 1) as varchar));
  if (isnull (pubDate))
    pubDate := CAL.WA.dt_convert(cast(xpath_eval('/item/pubDate', xt, 1) as varchar), now());

  id := CAL.WA.import_task_update
        (
          id,                                   -- id
          uid,                                  -- uid
          domain_id,                            -- domain_id
          subject,                              -- subject
          description,                          -- description
          null,                                 -- attendees
          CAL.WA.domain_is_public (domain_id),  -- privacy
          tags,                                 -- tags
          pubDate,                              -- eEventStart
          pubDate,                              -- eEventEnd
          3,                                    -- priority
          null,                                 -- status
          null,                                 -- complete
          null,                                 -- completed
          null,                                 -- notes
          null,                                 -- updated
          exchange_id,                          -- exchange_id
          updatedBefore                         -- updatedBefore
        );
  return id;
}
;

-------------------------------------------------------------------------------
--
create procedure CAL.WA.import_feed_atom_item(
  in domain_id integer,
  in exchange_id integer,
  in updatedBefore integer,
  in tags varchar,
  inout xt any)
{
  declare id integer;
  declare subject, description, link, uid, pubDate varchar;
  declare contents any;

  subject := serialize_to_UTF8_xml (xpath_eval ('string(/entry/title)', xt, 1));
  if (xpath_eval ('/entry/content[@type = "application/xhtml+xml" or @type="xhtml"]', xt) is not null)
  {
    contents := xpath_eval ('/entry/content/*', xt, 0);
    if (length (contents) = 1)
    {
      description := CAL.WA.xml2string(contents[0]);
    }
    else
    {
      description := '<div>';
      foreach (any content in contents) do
      {
        description := concat(description, CAL.WA.xml2string(content));
    }
      description := description || '</div>';
    }
  }
  else
  {
    description := xpath_eval ('string(/entry/content)', xt, 1);
    if (is_empty_or_null(description))
      description := xpath_eval ('string(/entry/summary)', xt, 1);

    description := serialize_to_UTF8_xml (description);
  }

  link := cast (xpath_eval ('/entry/link[@rel="alternate"]/@href', xt, 1) as varchar);

  uid := cast (xpath_eval ('/entry/id', xt, 1) as varchar);

  pubDate := CAL.WA.dt_convert(cast(xpath_eval ('/entry/created', xt, 1) as varchar));
  if (isnull (pubDate))
  {
    pubdate := CAL.WA.dt_convert (cast(xpath_eval ('/entry/modified', xt, 1) as varchar));
    if (isnull (pubDate))
    {
      pubdate := CAL.WA.dt_convert (cast(xpath_eval ('/entry/updated', xt, 1) as varchar), now ());
    }
  }

  id := CAL.WA.import_task_update
        (
          id,                                   -- id
          uid,                                  -- uid
          domain_id,                            -- domain_id
          subject,                              -- subject
          description,                          -- description
          null,                                 -- attendees
          CAL.WA.domain_is_public (domain_id),  -- privacy
          tags,                                 -- tags
          pubDate,                              -- eEventStart
          pubDate,                              -- eEventEnd
          3,                                    -- priority
          null,                                 -- status
          null,                                 -- complete
          null,                                 -- completed
          null,                                 -- notes
          null,                                 -- updated
          exchange_id,                          -- exchange_id
          updatedBefore                         -- updatedBefore
        );
  return id;
}
;

-------------------------------------------------------------------------------
--
create procedure CAL.WA.import_task_update (
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
  in updated datetime := null,
  in exchange_id integer := null,
  in updatedBefore integer := null,
  in attendees any := null,
  in mailAttendees any := null)
{
  id := coalesce ((select E_ID from CAL.WA.EVENTS where E_DOMAIN_ID = domain_id and E_UID = uid), -1);
  if ((id <> -1) and not isnull (updatedBefore))
  {
    if (exists (select 1 from CAL.WA.EVENTS where E_ID = id and E_UPDATED >= updatedBefore))
      goto _exit;
  }
  connection_set ('__calendar_import', '1');
  id := CAL.WA.task_update
        (
          id,
          uid,
          domain_id,
          subject,
          description,
          null,
          privacy,
          tags,
          eEventStart,
          eEventEnd,
          priority,
          status,
          complete,
          completed,
          notes,
          updated
        );
  if (not isnull (exchange_id))
    update CAL.WA.EVENTS set E_EXCHANGE_ID = exchange_id where E_ID = id;
  if (length (attendees))
    CAL.WA.attendees_update2 (id, attendees, mailAttendees);
  connection_set ('__calendar_import', '0');

_exit:;
  return id;
}
;

--------------------------------------------------------------------------------
--
create procedure CAL.WA.exchange_name (
  in id integer)
{
  return (select EX_NAME from CAL.WA.EXCHANGE where EX_ID = id);
}
;

--------------------------------------------------------------------------------
--
create procedure CAL.WA.exchange_exec (
  in _id integer,
  in _mode integer := 0,
  in _exMode integer := null)
{
  declare retValue any;

  declare exit handler for SQLSTATE '*'
  {
    rollback work;
    update CAL.WA.EXCHANGE
       set EX_EXEC_LOG = __SQL_STATE || ' ' ||  CAL.WA.test_clear (__SQL_MESSAGE)
     where EX_ID = _id;
    commit work;

    if (_mode)
      resignal;
  };

  retValue := CAL.WA.exchange_exec_internal (_id, _exMode);

  update CAL.WA.EXCHANGE
     set EX_EXEC_TIME = now (),
         EX_EXEC_LOG = null,
         EX_UPDATE_SUBTYPE = null
   where EX_ID = _id;
  commit work;

  return retValue;
}
;

--------------------------------------------------------------------------------
--
create procedure CAL.WA.exchange_exec_internal (
  in _id integer,
  in _exMode integer := null)
{
  for (select EX_DOMAIN_ID as _domain_id, EX_TYPE as _direction, deserialize (EX_OPTIONS) as _options from CAL.WA.EXCHANGE where EX_ID = _id) do
  {
    declare _type, _name, _pName, _user, _password, _mode, _events, _tasks any;
    declare _content any;

    _type := get_keyword ('type', _options);
    _name := get_keyword ('name', _options);
    _user := get_keyword ('user', _options);
    _password := get_keyword ('password', _options);
    _mode := cast (get_keyword ('mode', _options) as integer);
    _events := get_keyword ('events', _options, 0);
    _tasks := get_keyword ('tasks', _options, 0);

    -- publish
    if (_direction = 0)
    {
      _content := CAL.WA.export_vcal (_domain_id, null, _options);
      if (_type = 1)
      {
        declare retValue, permissions any;
        {
          declare exit handler for SQLSTATE '*'
          {
            signal ('CAL02', 'The export/publication did not pass successfully. Please verify the path and parameters values!<>');
          };
          permissions := CAL.WA.dav_permissions (_name, _user, _password);
          _pName := replace (_name, ' ', '%20');
          _name := http_physical_path_resolve (_name);
          if (_name is null)
          {
            _name := _pName;
          }
          else if (_name not like '/DAV/%')
          {
            _name := '/DAV' || _name;
          }
          retValue := DB.DBA.DAV_RES_UPLOAD (_name, _content, 'text/calendar', permissions, _user, null, _user, _password);
          if (DB.DBA.DAV_HIDE_ERROR (retValue) is null)
          {
            signal ('CAL01', 'WebDAV: ' || DB.DBA.DAV_PERROR (retValue) || '.<>');
          }
        }
      }
      else if (_type = 2)
      {
        declare retContent, resHeader, reqHeader any;

        reqHeader := null;
        if (_user <> '')
        {
          reqHeader := sprintf ('Authorization: Basic %s', encode_base64 (_user || ':' || _password));
        }
        commit work;
        {
          declare exit handler for SQLSTATE '*'
          {
            signal ('CAL02', 'Connection Error in HTTP Client!<>');
          };
          retContent := http_get (_name, resHeader, 'PUT', reqHeader, _content);
          if (not (length (resHeader) > 0 and (resHeader[0] like 'HTTP/1._ 2__ %' or  resHeader[0] like 'HTTP/1._ 3__ %')))
            signal ('cal02', 'The export/publication did not pass successfully. Please verify the path and parameters values!<>');
          }
        }
      }
    else if (_direction = 1)
    {
      -- subscribe

      if (_type = 3)
        return CAL.WA.exchange_CalDAV (_id);

      if (_type = 1)
        _name := CAL.WA.host_url () || _name;

      _content := CAL.WA.dav_content (_name, 0, _user, _password);
      if (isnull(_content))
        signal ('CAL01', 'Bad import/subscription source!<>');

      CAL.WA.import_vcal (_domain_id, _content, _options, _id);
    }
    else if (_direction = 2)
    {
      -- syncml

      declare data, _pathID any;
      declare N, _in, _out, _tmp, _rlog_res_id integer;
      declare _path varchar;

      _in := vector (0, 0);
      _out := vector (0, 0);
      if (not isnull (_exMode))
      {
        _mode := _exMode;
      }
      if ((_mode >= 0) and CAL.WA.dav_check_authenticate (_name, _user, _password, '1__'))
      {
      data := CAL.WA.exec ('select distinct RLOG_RES_ID from DB.DBA.SYNC_RPLOG where RLOG_RES_COL = ? and DMLTYPE <> \'D\'', vector (DB.DBA.DAV_SEARCH_ID (_name, 'C')));
      for (N := 0; N < length (data); N := N + 1)
      {
        _rlog_res_id := data[N][0];
   	    for (select RES_CONTENT, RES_NAME, RES_MOD_TIME from WS.WS.SYS_DAV_RES where RES_ID = _rlog_res_id) do
   	    {
          connection_set ('__sync_dav_upl', '1');
            _tmp := CAL.WA.syncml2entry_internal (_domain_id, _name, _user, _password, RES_CONTENT, RES_NAME, RES_MOD_TIME, 1);
            aset(_in, 0, _in[0]+_tmp[0]);
            aset(_in, 1, _in[1]+_tmp[1]);
          connection_set ('__sync_dav_upl', '0');
   	    }
   	  }
     	}
      if ((_mode <= 0) and CAL.WA.dav_check_authenticate (_name, _user, _password, '11_'))
      {
        if (_events <> 0)
        {
          for (select E_ID, E_UID, E_KIND, E_UPDATED from CAL.WA.events where E_DOMAIN_ID = _domain_id and E_KIND = 0) do
      {
        _path := _name || E_UID;
        _pathID := DB.DBA.DAV_SEARCH_ID (_path, 'R');
        if (not (isinteger(_pathID) and (_pathID > 0)))
        {
          CAL.WA.syncml_entry_update_internal (_domain_id, E_ID, _path, _user, _password, 'I');
              aset(_out, 0, _out[0]+1);
            }
          }
        }
        if (_tasks <> 0)
        {
          for (select E_ID, E_UID, E_KIND, E_UPDATED from CAL.WA.events where E_DOMAIN_ID = _domain_id and E_KIND = 1) do
          {
            _path := _name || E_UID;
            _pathID := DB.DBA.DAV_SEARCH_ID (_path, 'R');
            if (not (isinteger(_pathID) and (_pathID > 0)))
            {
              CAL.WA.syncml_entry_update_internal (_domain_id, E_ID, _path, _user, _password, 'I');
              aset(_out, 1, _out[1]+1);
            }
        }
      }
    }
      return vector (_in, _out);
    }
  }
}
;

--------------------------------------------------------------------------------
--
create procedure CAL.WA.exchange_CalDAV (
  in _id integer)
{
  for (select EX_DOMAIN_ID as _domain_id, EX_TYPE as _direction, deserialize (EX_OPTIONS) as _options from CAL.WA.EXCHANGE where EX_ID = _id) do
  {
    if (get_keyword ('type', _options) <> 3)
       return;

    CAL.WA.import_CalDAV (_domain_id, get_keyword ('name', _options), _options);
  }
  return 1;
}
;

--------------------------------------------------------------------------------
--
create procedure CAL.WA.exchange_event_update (
  in _domain_id integer)
{
  for (select EX_ID as _id from CAL.WA.EXCHANGE where EX_DOMAIN_ID = _domain_id and EX_TYPE = 0 and EX_UPDATE_TYPE = 1) do
  {
    if (connection_get ('__calendar_import') = '1')
  {
      update CAL.WA.EXCHANGE
         set EX_UPDATE_SUBTYPE = 1
       where EX_ID = _id;
    } else {
      CAL.WA.exchange_exec (_id);
    }
  }
}
;

--------------------------------------------------------------------------------
--
create procedure CAL.WA.exchange_scheduler ()
{
  declare id, days, rc, err integer;
  declare bm any;

  declare _error integer;
  declare _bookmark any;
  declare _dt datetime;
  declare exID any;

  _dt := now ();
  declare cr static cursor for select EX_ID
                                 from CAL.WA.EXCHANGE
                                where (EX_UPDATE_TYPE = 2 and (EX_EXEC_TIME is null or dateadd ('minute', EX_UPDATE_INTERVAL, EX_EXEC_TIME) < _dt))
                                   or (EX_UPDATE_TYPE = 1 and EX_UPDATE_SUBTYPE is not null);

  whenever not found goto _done;
  open cr (exclusive, prefetch 1);
  fetch cr into exID;
  while (1)
  {
    _bookmark := bookmark(cr);
    _error := 0;
    close cr;
    {
      declare exit handler for sqlstate '*'
      {
        _error := 1;

        goto _next;
      };
      CAL.WA.exchange_exec (exID, 1);
      commit work;
    }

  _next:
    open cr (exclusive, prefetch 1);
    fetch cr bookmark _bookmark into exID;
    if (_error)
      fetch cr next into exID;
  }
_done:;
  close cr;
}
;

-----------------------------------------------------------------------------------------
--
create procedure CAL.WA.dav_check_authenticate (
  in _path varchar,
  in _user varchar,
  in _password varchar,
  in _permissions varchar)
{
  declare _type varchar;

  _type := case when (strrchr (_path, '/') = length (_path) - 1) then 'C' else 'R' end;
  if (DB.DBA.DAV_AUTHENTICATE (DB.DBA.DAV_SEARCH_ID (_path, _type), _type, _permissions, _user, _password) < 0)
    return 0;
  return 1;
}
;

-------------------------------------------------------------------------------
--
create procedure CAL.WA.dav_parent (
  in path varchar)
{
  declare pos integer;

  path := trim (path, '/');
  pos := strrchr (path, '/');
  if (not isnull (pos))
    path := substring (path, 1, pos);
  return '/' || path || '/';
}
;

-------------------------------------------------------------------------------
--
create procedure CAL.WA.dav_permissions (
  in path varchar,
  in auth_name varchar := null,
  in auth_password varchar := null)
{
  declare uid, gid integer;
  declare permissions varchar;

  permissions := -1;
  permissions := DB.DBA.DAV_PROP_GET (path, ':virtpermissions', auth_name, auth_password);
  if (permissions < 0)
  {
    path := CAL.WA.dav_parent (path);
    if (path <> CAL.WA.dav_home (CAL.WA.account_id (auth_name)))
      permissions := DB.DBA.DAV_PROP_GET (path, ':virtpermissions', auth_name, auth_password);
    if (permissions < 0)
      permissions := USER_GET_OPTION (auth_name, 'PERMISSIONS');
  }
  return permissions;
}
;

-----------------------------------------------------------------------------------------
--
create procedure CAL.WA.syncml_check (
  in syncmlPath varchar := null)
{
  declare syncmlVersion varchar;

  syncmlVersion := DB.DBA.vad_check_version ('SyncML');
  if (not isstring (syncmlVersion))
    return 0;
  if (VAD.DBA.version_compare (syncmlVersion, '1.05.75') < 0)
    return 0;
  if (__proc_exists ('DB.DBA.yac_syncml_version_get') is null)
    return 0;
  if (__proc_exists ('DB.DBA.yac_syncml_type_get') is null)
    return 0;
  if (isnull (syncmlPath))
    return 1;
  if (DB.DBA.yac_syncml_version_get (syncmlPath) = 'N')
    return 0;
  if (DB.DBA.yac_syncml_type_get (syncmlPath) not in ('vcalendar_11', 'vcalendar_12'))
    return 0;
  return 1;
}
;

-----------------------------------------------------------------------------------------
--
create procedure CAL.WA.syncml_entry_update (
  in _domain_id integer,
  in _event_id integer,
  in _event_gid varchar,
  in _event_kind integer,
  in _action varchar)
{
  declare _syncmlPath, _path, _user, _password, _events, _tasks varchar;

  if (connection_get ('__sync_dav_upl') = '1')
    return;

  for (select deserialize (EX_OPTIONS) as _options from CAL.WA.EXCHANGE where EX_DOMAIN_ID = _domain_id and EX_TYPE = 2) do
  {
    _syncmlPath := get_keyword ('name', _options);
    if (not CAL.WA.syncml_check (_syncmlPath))
      goto _skip;
    if ((_event_kind = 0) and (get_keyword ('events', _options, 0) = 0))
      goto _skip;
    if ((_event_kind = 1) and (get_keyword ('tasks', _options, 0) = 0))
      goto _skip;

    _user := get_keyword ('user', _options);
    _password := get_keyword ('password', _options);
    _path := _syncmlPath || _event_gid;

    CAL.WA.syncml_entry_update_internal (_domain_id, _event_id, _path, _user, _password, _action);

  _skip:;
  }
}
;

-----------------------------------------------------------------------------------------
--
create procedure CAL.WA.syncml_entry_update_internal (
  in _domain_id integer,
  in _event_id integer,
  in _path varchar,
  in _user varchar,
  in _password varchar,
  in _action varchar)
{
  if ((_action = 'I') or (_action = 'U'))
  {
    declare _content, _permissions varchar;

    _content := CAL.WA.entry2syncml (_domain_id, _event_id);
    _permissions := USER_GET_OPTION (_user, 'PERMISSIONS');
    if (isnull (_permissions))
      _permissions := '110100000RR';

    connection_set ('__sync_dav_upl', '1');
    connection_set ('__sync_ods', '1');
    DB.DBA.DAV_RES_UPLOAD_STRSES_INT (_path, _content, 'text/x-vcalendar', _permissions, _user, _user, null, null, 0);
    connection_set ('__sync_ods', '0');
    connection_set ('__sync_dav_upl', '0');
  }
  else if (_action = 'D')
  {
    declare _id integer;

    _id := DB.DBA.DAV_SEARCH_ID (_path, 'R');
    if (isinteger(_id) and (_id > 0))
    {
      connection_set ('__sync_ods', '1');
      DB.DBA.DAV_DELETE_INT (_path, 1, _user, _password, 0);
      connection_set ('__sync_ods', '0');
    }
  }
}
;

----------------------------------------------------------------------
--
create procedure CAL.WA.entry2syncml (
  in domain_id integer,
  in event_id integer)
{
  declare url varchar;
  declare sStream any;

  url := sprintf ('http://%s%s/%U/calendar/%U/', SIOC.DBA.get_cname(), SIOC.DBA.get_base_path (), CAL.WA.domain_owner_name (domain_id), CAL.WA.domain_name (domain_id));
  sStream := string_output();

  for (select * from CAL.WA.EVENTS where E_ID = event_id) do
  {
    if (E_KIND = 0)
    {
      CAL.WA.entry2syncml_line ('BEGIN', 'VCALENDAR', sStream);
      CAL.WA.entry2syncml_line ('VERSION', '1.0', sStream);
      CAL.WA.entry2syncml_line ('BEGIN', 'VEVENT', sStream);
      CAL.WA.entry2syncml_line ('UID', E_UID, sStream);
      CAL.WA.entry2syncml_line ('URL', url || cast (E_ID as varchar), sStream);
      CAL.WA.entry2syncml_line ('DTSTAMP', CAL.WA.vcal_date2utc (now ()), sStream);
      CAL.WA.entry2syncml_line ('CREATED', CAL.WA.vcal_date2utc (E_CREATED), sStream);
      CAL.WA.entry2syncml_line ('LAST-MODIFIED', CAL.WA.vcal_date2utc (E_UPDATED), sStream);
      CAL.WA.entry2syncml_line ('SUMMARY', E_SUBJECT, sStream);
      CAL.WA.entry2syncml_line ('DESCRIPTION', E_DESCRIPTION, sStream);
      CAL.WA.entry2syncml_line ('LOCATION', E_LOCATION, sStream);
      CAL.WA.entry2syncml_line ('CATEGORIES', E_TAGS, sStream);
      CAL.WA.entry2syncml_line ('DTSTART', CAL.WA.vcal_date2str (E_EVENT_START), sStream);
      CAL.WA.entry2syncml_line ('DTEND', CAL.WA.vcal_date2str (E_EVENT_END), sStream);
      CAL.WA.entry2syncml_line ('RRULE', CAL.WA.vcal_recurrence2str (E_REPEAT, E_REPEAT_PARAM1, E_REPEAT_PARAM2, E_REPEAT_PARAM3, E_REPEAT_UNTIL), sStream);
      CAL.WA.entry2syncml_line ('NOTES', E_NOTES, sStream);
      CAL.WA.entry2syncml_line ('CLASS', case when E_PRIVACY = 1 then 'PUBLIC' else 'PRIVATE' end, sStream);
      CAL.WA.entry2syncml_line ('END', 'VEVENT', sStream);
      CAL.WA.entry2syncml_line ('END', 'VCALENDAR', sStream);
    }
    else if (E_KIND = 1)
    {
      CAL.WA.entry2syncml_line ('BEGIN', 'VCALENDAR', sStream);
      CAL.WA.entry2syncml_line ('VERSION', '1.0', sStream);
      CAL.WA.entry2syncml_line ('BEGIN', 'VTODO', sStream);
      CAL.WA.entry2syncml_line ('UID', E_UID, sStream);
      CAL.WA.entry2syncml_line ('URL', url || cast (E_ID as varchar), sStream);
      CAL.WA.entry2syncml_line ('DTSTAMP', CAL.WA.vcal_date2utc (now ()), sStream);
      CAL.WA.entry2syncml_line ('CREATED', CAL.WA.vcal_date2utc (E_CREATED), sStream);
      CAL.WA.entry2syncml_line ('LAST-MODIFIED', CAL.WA.vcal_date2utc (E_UPDATED), sStream);
      CAL.WA.entry2syncml_line ('SUMMARY', E_SUBJECT, sStream);
      CAL.WA.entry2syncml_line ('DESCRIPTION', E_DESCRIPTION, sStream);
      CAL.WA.entry2syncml_line ('CATEGORIES', E_TAGS, sStream);
      CAL.WA.entry2syncml_line ('DTSTART', CAL.WA.vcal_date2str (CAL.WA.dt_dateClear (E_EVENT_START)), sStream);
      CAL.WA.entry2syncml_line ('DUE', CAL.WA.vcal_date2str (CAL.WA.dt_dateClear (E_EVENT_END)), sStream);
      CAL.WA.entry2syncml_line ('COMPLETED', CAL.WA.vcal_date2str (CAL.WA.dt_dateClear (E_COMPLETED)), sStream);
      CAL.WA.entry2syncml_line ('PRIORITY', E_PRIORITY, sStream);
      CAL.WA.entry2syncml_line ('STATUS', E_STATUS, sStream);
      CAL.WA.entry2syncml_line ('NOTES', E_NOTES, sStream);
      CAL.WA.entry2syncml_line ('CLASS', case when E_PRIVACY = 1 then 'PUBLIC' else 'PRIVATE' end, sStream);
      CAL.WA.entry2syncml_line ('END', 'VTODO', sStream);
      CAL.WA.entry2syncml_line ('END', 'VCALENDAR', sStream);
    }
  }

  return string_output_string (sStream);
}
;

----------------------------------------------------------------------
--
create procedure CAL.WA.entry2syncml_line (
  in property varchar,
  in value any,
  inout sStream any)
{
  if (isnull (value))
    return;
  http (sprintf ('<%s><![CDATA[%s]]></%s>\r\n', property, cast (value as varchar), property), sStream);
}
;

----------------------------------------------------------------------
--
create procedure CAL.WA.syncml2entry (
  in res_content varchar,
  in res_name varchar,
  in res_col varchar,
  in res_mod_time datetime := null)
{
  declare exit handler for sqlstate '*'
  {
    return;
  };

  declare _syncmlPath, _path, _user, _password varchar;

  for (select EX_DOMAIN_ID, deserialize (EX_OPTIONS) as _options from CAL.WA.EXCHANGE where EX_TYPE = 2) do
  {
    _path := WS.WS.COL_PATH (res_col);
    _syncmlPath := get_keyword ('name', _options);
    _user := get_keyword ('user', _options);
    _password := get_keyword ('password', _options);
    if (_path = _syncmlPath)
    {
      if (CAL.WA.dav_check_authenticate (_path, _user, _password, '11_'))
      CAL.WA.syncml2entry_internal (EX_DOMAIN_ID, _path, _user, _password, res_content, res_name, res_mod_time);
    }
  }
}
;

----------------------------------------------------------------------
--
create procedure CAL.WA.syncml2entry_internal (
  in _domain_id integer,
  in _path varchar,
  in _user varchar,
  in _password varchar,
  in _res_content varchar,
  in _res_name varchar,
  in _res_mod_time datetime := null,
  in _internal integer := 0)
{
  declare exit handler for sqlstate '*'
  {
    return;
  };

  declare N integer;
  declare _data  varchar;
  declare IDs, _pathID any;

  if (not xslt_is_sheet ('http://local.virt/sync_out_xsl'))
    DB.DBA.sync_define_xsl ();

	_data := xtree_doc (_res_content, 0, '', 'utf-8');
	_data := xslt ('http://local.virt/sync_out_xsl', _data);
  _data := serialize_to_UTF8_xml (_data);
  _data := charset_recode (_data, 'UTF-8', '_WIDE_');

	if (not isinteger (_data))
	{
	  declare _in any;

	  _in := vector (0, 0);
    IDs := CAL.WA.import_vcal (_domain_id, _data, null, null, _res_mod_time);
    for (N := 0; N < length (IDs); N := N + 1)
    {
      for (select E_KIND, E_UID from CAL.WA.EVENTS where E_ID = IDs[N]) do
      {
        aset(_in, E_KIND, _in[E_KIND]+1);
        if (E_UID <> _res_name)
      {
        _pathID := DB.DBA.DAV_SEARCH_ID (_path || _res_name, 'R');
        if (isinteger(_pathID) and (_pathID > 0))
        {
          if (_internal)
            set triggers off;

          update WS.WS.SYS_DAV_RES
               set RES_NAME = E_UID,
                   RES_FULL_PATH = _path || E_UID
           where RES_ID = _pathID;

          if (_internal)
            set triggers on;
        }
      }
    }
    }
    return _in;
  }
}
;

--------------------------------------------------------------------------------
--
create procedure CAL.WA.alarm_scheduler ()
{
  declare dt, nextReminderDate date;
  declare eID, eDomainID, eEvent, eEventStart, eEventEnd, eRepeat, eRepeatParam1, eRepeatParam2, eRepeatParam3, eRepeatUntil, eRepeatExceptions, eReminder, eReminderDate any;

  dt := now ();
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

    nextReminderDate := CAL.WA.event_addReminder (CAL.WA.event_user2gmt (dt, CAL.WA.settings_timeZone2 (eDomainID), CAL.WA.settings_daylight2 (eDomainID)),
                                                  eID,
                                                  eDomainID,
                                                  eEvent,
                                                 eEventStart,
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
  if ((length (_path) > 6) and (atoi ('0' || _action) > 0))
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
  if (cast (_content_type as varchar) in ('application/atom+xml', 'application/x.atom+xml', 'text/xml', 'application/xml'))
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
    }
    else
    {
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
-- Mails
--
-----------------------------------------------------------------------------------------
create procedure CAL.WA.string2mails (
  in S varchar)
{
  declare mailName, mailAddress varchar;
  declare retValue, mails, mailParts any;

  retValue := vector ();
  S := replace (S, '"', '');
  mails := split_and_decode (S, 0, '\0\0,');
  foreach (varchar mail in mails) do
  {
    mailName := '';
    mailAddress := '';
    mail := replace (mail, '<', '');
    mail := replace (mail, '>', '');
    mail := replace (mail, '\t', ' ');
    mailParts := split_and_decode (trim (mail), 0, '\0\0 ');
    foreach (varchar part in mailParts) do
    {
      if (isnull (strchr (part, '@')) = 0)
      {
        mailAddress := part;
      } else {
        mailName := mailName || ' ' || part;
      }
    }
    retValue := vector_concat (retValue, vector (vector (trim (mailName), trim (mailAddress))));
  }
  return retValue;
}
;

-----------------------------------------------------------------------------------------
create procedure CAL.WA.mail2string (
  in mailName varchar,
  in mailAddress varchar)
{
  if (is_empty_or_null (mailName) and is_empty_or_null (mailAddress))
    return '';

  if (is_empty_or_null (mailName))
    return mailAddress;

  if (is_empty_or_null (mailAddress))
    return mailName;

  return sprintf ('%s <%s>', mailName, mailAddress);
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
  http (coalesce (head, ''), ses);
  http (coalesce (body, ''), ses);
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
  signal ('CONV3', 'Delete of a event/task comment is not allowed');
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
