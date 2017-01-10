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

-------------------------------------------------------------------------------
--
-- ACL Functions
--
-------------------------------------------------------------------------------
--
create procedure POLLS.WA.acl_condition (
  in domain_id integer,
  in id integer := null)
{
  if (not is_https_ctx ())
    return 0;

  if (exists (select 1 from DB.DBA.WA_INSTANCE where WAI_ID = domain_id and WAI_ACL is not null))
    return 1;

  if (exists (select 1 from POLLS.WA.POLL where P_ID = id and P_ACL is not null))
    return 1;

  return 0;
}
;

-------------------------------------------------------------------------------
--
create procedure POLLS.WA.acl_check (
  in domain_id integer,
  in id integer := null)
{
  declare rc varchar;
  declare graph_iri, groups_iri, acl_iris any;

  rc := '';
  if (POLLS.WA.acl_condition (domain_id, id))
  {
    acl_iris := vector (POLLS.WA.forum_iri (domain_id));
    if (not isnull (id))
      acl_iris := vector (SIOC..poll_post_iri (domain_id, id), POLLS.WA.forum_iri (domain_id));

    graph_iri := POLLS.WA.acl_graph (domain_id);
    groups_iri := SIOC..acl_groups_graph (POLLS.WA.domain_owner_id (domain_id));
    rc := SIOC..acl_check (graph_iri, groups_iri, acl_iris);
  }
  return rc;
}
;

-------------------------------------------------------------------------------
--
create procedure POLLS.WA.acl_list (
  in domain_id integer)
{
  declare graph_iri, groups_iri, iri any;

  iri := POLLS.WA.forum_iri (domain_id);
  graph_iri := POLLS.WA.acl_graph (domain_id);
  groups_iri := SIOC..acl_groups_graph (POLLS.WA.domain_owner_id (domain_id));
  return SIOC..acl_list (graph_iri, groups_iri, iri);
}
;

-------------------------------------------------------------------------------
--
-- Session Functions
--
-------------------------------------------------------------------------------
create procedure POLLS.WA.session_domain (
  inout params any)
{
  declare aPath, domain_id, options any;

  declare exit handler for sqlstate '*'
  {
    domain_id := -1;
    goto _end;
  };

  options := http_map_get('options');
  if (not DB.DBA.is_empty_or_null (options))
  {
    domain_id := get_keyword ('domain', options);
  }
  if (DB.DBA.is_empty_or_null (domain_id))
  {
    aPath := split_and_decode (trim (http_path (), '/'), 0, '\0\0/');
    domain_id := cast(aPath[1] as integer);
  }
  if (not exists (select 1 from DB.DBA.WA_INSTANCE where WAI_ID = domain_id and WAI_TYPE_NAME = 'Polls'))
    domain_id := -1;

_end:;
  return cast (domain_id as integer);
}
;

-------------------------------------------------------------------------------
--
create procedure POLLS.WA.session_restore(
  inout params any)
{
  declare domain_id, account_id, account_rights any;

  domain_id := POLLS.WA.session_domain (params);
  account_id := http_nobody_uid ();

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
  account_rights := POLLS.WA.access_rights (domain_id, account_id);
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
create procedure POLLS.WA.frozen_check (
  in domain_id integer)
{
  declare exit handler for not found { return 1; };

  if (is_empty_or_null((select WAI_IS_FROZEN from DB.DBA.WA_INSTANCE where WAI_ID = domain_id)))
    return 0;

  declare user_id integer;

  user_id := (select U_ID from SYS_USERS where U_NAME = connection_get ('vspx_user'));
  if (POLLS.WA.check_admin(user_id))
    return 0;

  user_id := (select U_ID from SYS_USERS where U_NAME = connection_get ('owner_user'));
  if (POLLS.WA.check_admin(user_id))
    return 0;

  return 1;
}
;

-------------------------------------------------------------------------------
--
create procedure POLLS.WA.frozen_page (
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
create procedure POLLS.WA.check_admin(
  in user_id integer) returns integer
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
create procedure POLLS.WA.check_grants (in role_name varchar, in page_name varchar)
{
  declare tree any;

  tree := xml_tree_doc (POLLS.WA.menu_tree ());
  if (isnull (xpath_eval (sprintf ('//node[(@url = "%s") and contains(@allowed, "%s")]', page_name, role_name), tree, 1)))
    return 0;
  return 1;
}
;

-------------------------------------------------------------------------------
--
create procedure POLLS.WA.access_rights (
  in domain_id integer,
  in account_id integer)
{
  declare rc varchar;

  if (domain_id <= 0)
    return null;

  if (POLLS.WA.check_admin (account_id))
    return 'W';

  if (exists(select 1
               from SYS_USERS A,
                    WA_MEMBER B,
                    WA_INSTANCE C
               where A.U_ID = account_id
                and B.WAM_USER = A.U_ID
                and B.WAM_MEMBER_TYPE = 1
                and B.WAM_INST = C.WAI_NAME
                and C.WAI_ID = domain_id))
    return 'W';

  if (exists(select 1
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
    rc := POLLS.WA.acl_check (domain_id);
    if (rc <> '')
      return rc;
  }

  if (exists(select 1
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

  if (is_https_ctx () and exists (select 1 from POLLS.WA.acl_list (id)(iri varchar) x where x.id = domain_id))
    return '';

  return null;
}
;

-------------------------------------------------------------------------------
--
create procedure POLLS.WA.wa_home_link ()
{
  return case when registry_get ('wa_home_link') = 0 then '/ods/' else registry_get ('wa_home_link') end;
}
;

-------------------------------------------------------------------------------
--
create procedure POLLS.WA.wa_home_title ()
{
  return case when registry_get ('wa_home_title') = 0 then 'ODS Home' else registry_get ('wa_home_title') end;
}
;

-------------------------------------------------------------------------------
--
create procedure POLLS.WA.page_name ()
{
  declare aPath any;

  aPath := http_path ();
  aPath := split_and_decode (aPath, 0, '\0\0/');
  return aPath [length (aPath) - 1];
}
;

-------------------------------------------------------------------------------
--
create procedure POLLS.WA.menu_tree ()
{
  declare S varchar;

  S :=
'<?xml version="1.0" ?>
<menu_tree>
  <node name="home" url="polls.vspx"           id="1"   allowed="W R">
    <node name="11" url="polls.vspx"           id="11"  allowed="W R"/>
    <node name="12" url="search.vspx"          id="12"  allowed="W R"/>
    <node name="13" url="error.vspx"           id="13"  allowed="W R"/>
    <node name="14" url="settings.vspx"        id="14"  allowed="W"/>
  </node>
</menu_tree>';

  return S;
}
;

-------------------------------------------------------------------------------
--
create procedure POLLS.WA.xslt_root()
{
  declare sHost varchar;

  sHost := cast(registry_get('_polls_path_') as varchar);
  if (sHost = '0')
    return 'file://apps/polls/xslt/';
  if (isnull(strstr(sHost, '/DAV/VAD')))
    return sprintf('file://%sxslt/', sHost);
  return sprintf('virt://WS.WS.SYS_DAV_RES.RES_FULL_PATH.RES_CONTENT:%sxslt/', sHost);
}
;

-------------------------------------------------------------------------------
--
create procedure POLLS.WA.xslt_full(
  in xslt_file varchar)
{
  return concat(POLLS.WA.xslt_root(), xslt_file);
}
;

-------------------------------------------------------------------------------
--
create procedure POLLS.WA.iri_fix (
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
create procedure POLLS.WA.url_fix (
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
create procedure POLLS.WA.export_rss_sqlx_int(
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
  http ('  XMLELEMENT(\'title\', POLLS.WA.utf2wide(POLLS.WA.domain_name (<DOMAIN_ID>))), \n', retValue);
  http ('  XMLELEMENT(\'description\', POLLS.WA.utf2wide(POLLS.WA.domain_description (<DOMAIN_ID>))), \n', retValue);
  http ('  XMLELEMENT(\'managingEditor\', POLLS.WA.utf2wide (U_FULL_NAME || \' <\' || U_E_MAIL || \'>\')), \n', retValue);
  http ('  XMLELEMENT(\'pubDate\', POLLS.WA.dt_rfc1123(now())), \n', retValue);
  http ('  XMLELEMENT(\'generator\', \'Virtuoso Universal Server \' || sys_stat(\'st_dbms_ver\')), \n', retValue);
  http ('  XMLELEMENT(\'webMaster\', U_E_MAIL), \n', retValue);
  http ('  XMLELEMENT(\'link\', POLLS.WA.polls_url (<DOMAIN_ID>)), \n', retValue);
  http ('  (select XMLAGG (XMLELEMENT(\'http://www.w3.org/2005/Atom:link\', XMLATTRIBUTES (SH_URL as "href", \'hub\' as "rel", \'PubSubHub\' as "title"))) from ODS.DBA.SVC_HOST, ODS.DBA.APP_PING_REG where SH_PROTO = \'PubSubHub\' and SH_ID = AP_HOST_ID and AP_WAI_ID = <DOMAIN_ID>), \n', retValue);
  http ('  XMLELEMENT(\'language\', \'en-us\') \n', retValue);
  http ('from DB.DBA.SYS_USERS where U_ID = <USER_ID> \n', retValue);
  http (']]></sql:sqlx>\n', retValue);

  http ('<sql:sqlx xmlns:sql=\'urn:schemas-openlink-com:xml-sql\'><![CDATA[\n', retValue);
  http ('select \n', retValue);
  http ('  XMLAGG(XMLELEMENT(\'item\', \n', retValue);
  http ('    XMLELEMENT(\'title\', POLLS.WA.utf2wide (P_NAME)), \n', retValue);
  http ('    XMLELEMENT(\'description\', POLLS.WA.utf2wide (P_DESCRIPTION)), \n', retValue);
  http ('    XMLELEMENT(\'guid\', P_ID), \n', retValue);
  http ('    XMLELEMENT(\'link\', POLLS.WA.poll_url (<DOMAIN_ID>, P_ID)), \n', retValue);
  http ('    XMLELEMENT(\'pubDate\', POLLS.WA.dt_rfc1123 (P_UPDATED)), \n', retValue);
  http ('    (select XMLAGG (XMLELEMENT (\'category\', TV_TAG)) from POLLS..TAGS_VIEW where tags = P_TAGS), \n', retValue);
  http ('    XMLELEMENT(\'http://www.openlinksw.com/ods/:modified\', POLLS.WA.dt_iso8601 (P_UPDATED)))) \n', retValue);
  http ('from (select top 15  \n', retValue);
  http ('        P_NAME, \n', retValue);
  http ('        P_DESCRIPTION, \n', retValue);
  http ('        P_UPDATED, \n', retValue);
  http ('        P_TAGS, \n', retValue);
  http ('        P_ID \n', retValue);
  http ('      from \n', retValue);
  http ('        POLLS.WA.POLL \n', retValue);
  http ('      where P_DOMAIN_ID = <DOMAIN_ID> \n', retValue);
  http ('      order by P_UPDATED desc) x \n', retValue);
  http (']]></sql:sqlx>\n', retValue);

  http ('</channel>\n', retValue);
  http ('</rss>\n', retValue);

  retValue := string_output_string (retValue);
  retValue := replace(retValue, '<USER_ID>', cast(account_id as varchar));
  retValue := replace(retValue, '<DOMAIN_ID>', cast(domain_id as varchar));
  return retValue;
}
;

-------------------------------------------------------------------------------
--
create procedure POLLS.WA.export_rss_sqlx(
  in domain_id integer,
  in account_id integer)
{
  declare retValue any;

  retValue := POLLS.WA.export_rss_sqlx_int (domain_id, account_id);
  return replace (retValue, 'sql:xsl=""', '');
}
;

-------------------------------------------------------------------------------
--
create procedure POLLS.WA.export_atom_sqlx(
  in domain_id integer,
  in account_id integer)
{
  declare retValue, xsltTemplate any;

  xsltTemplate := POLLS.WA.xslt_full ('rss2atom03.xsl');
  if (POLLS.WA.settings_atomVersion (domain_id) = '1.0')
    xsltTemplate := POLLS.WA.xslt_full ('rss2atom.xsl');

  retValue := POLLS.WA.export_rss_sqlx_int (domain_id, account_id);
  return replace (retValue, 'sql:xsl=""', sprintf ('sql:xsl="%s"', xsltTemplate));
}
;

-------------------------------------------------------------------------------
--
create procedure POLLS.WA.export_rdf_sqlx(
  in domain_id integer,
  in account_id integer)
{
  declare retValue any;

  retValue := POLLS.WA.export_rss_sqlx_int (domain_id, account_id);
  return replace (retValue, 'sql:xsl=""', sprintf ('sql:xsl="%s"', POLLS.WA.xslt_full ('rss2rdf.xsl')));
}
;

-----------------------------------------------------------------------------
--
create procedure POLLS.WA.export_comment_sqlx(
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
  http ('    XMLELEMENT (\'title\', POLLS.WA.utf2wide (P_NAME)), \n', retValue);
  http ('    XMLELEMENT (\'description\', POLLS.WA.utf2wide (POLLS.WA.xml2string(P_DESCRIPTION))), \n', retValue);
  http ('    XMLELEMENT (\'link\', POLLS.WA.poll_url (<DOMAIN_ID>, P_ID)), \n', retValue);
  http ('    XMLELEMENT (\'pubDate\', POLLS.WA.dt_rfc1123 (P_CREATED)), \n', retValue);
  http ('    XMLELEMENT (\'generator\', \'Virtuoso Universal Server \' || sys_stat(\'st_dbms_ver\')), \n', retValue);
  http ('    XMLELEMENT (\'http://purl.org/dc/elements/1.1/:creator\', U_FULL_NAME) \n', retValue);
  http ('  from \n', retValue);
  http ('    POLLS.WA.POLL, DB.DBA.SYS_USERS, DB.DBA.WA_INSTANCE \n', retValue);
  http ('  where \n', retValue);
  http ('    P_ID = :id and U_ID = <USER_ID> and P_DOMAIN_ID = <DOMAIN_ID> and WAI_ID = P_DOMAIN_ID and WAI_IS_PUBLIC = 1\n', retValue);
  http (']]></sql:sqlx>\n', retValue);

  http ('<sql:sqlx><![CDATA[\n', retValue);
  http ('  select \n', retValue);
  http ('    XMLAGG (XMLELEMENT(\'item\',\n', retValue);
  http ('    XMLELEMENT (\'title\', POLLS.WA.utf2wide (PC_TITLE)),\n', retValue);
  http ('    XMLELEMENT (\'guid\', POLLS.WA.polls_url (<DOMAIN_ID>)||\'conversation.vspx\'||\'?id=\'||cast (PC_POLL_ID as varchar)||\'#\'||cast (PC_ID as varchar)),\n', retValue);
  http ('    XMLELEMENT (\'link\', POLLS.WA.polls_url (<DOMAIN_ID>)||\'conversation.vspx\'||\'?id=\'||cast (PC_POLL_ID as varchar)||\'#\'||cast (PC_ID as varchar)),\n', retValue);
  http ('    XMLELEMENT (\'http://purl.org/dc/elements/1.1/:creator\', PC_U_MAIL),\n', retValue);
  http ('    XMLELEMENT (\'pubDate\', DB.DBA.date_rfc1123 (PC_UPDATED)),\n', retValue);
  http ('    XMLELEMENT (\'description\', POLLS.WA.utf2wide (blob_to_string (PC_COMMENT))))) \n', retValue);
  http ('  from \n', retValue);
  http ('    (select TOP 15 \n', retValue);
  http ('       PC_ID, \n', retValue);
  http ('       PC_POLL_ID, \n', retValue);
  http ('       PC_TITLE, \n', retValue);
  http ('       PC_COMMENT, \n', retValue);
  http ('       PC_U_MAIL, \n', retValue);
  http ('       PC_UPDATED \n', retValue);
  http ('     from \n', retValue);
  http ('       POLLS.WA.POLL_COMMENT, DB.DBA.WA_INSTANCE \n', retValue);
  http ('     where \n', retValue);
  http ('       PC_POLL_ID = :id and WAI_ID = PC_DOMAIN_ID and WAI_IS_PUBLIC = 1\n', retValue);
  http ('     order by PC_UPDATED desc\n', retValue);
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
create procedure POLLS.WA.domain_gems_create (
  inout domain_id integer,
  inout account_id integer)
{
  declare read_perm, exec_perm, content, home, path varchar;

  home := POLLS.WA.dav_home(account_id);
  if (isnull(home))
    return;

  read_perm := '110100100N';
  exec_perm := '111101101N';
  home := home || 'Gems/';
  DB.DBA.DAV_MAKE_DIR (home, account_id, null, read_perm);

  home := home || POLLS.WA.domain_gems_name(domain_id) || '/';
  DB.DBA.DAV_MAKE_DIR (home, account_id, null, read_perm);

  -- RSS 2.0
  path := home || 'Polls.rss';
  DB.DBA.DAV_DELETE_INT (path, 1, null, null, 0);

  content := POLLS.WA.export_rss_sqlx (domain_id, account_id);
  DB.DBA.DAV_RES_UPLOAD_STRSES_INT (path, content, 'text/xml', exec_perm, http_dav_uid (), http_dav_uid () + 1, null, null, 0);
  DB.DBA.DAV_PROP_SET_INT (path, 'xml-template', 'execute', 'dav', null, 0, 0, 1);
  DB.DBA.DAV_PROP_SET_INT (path, 'xml-sql-encoding', 'utf-8', 'dav', null, 0, 0, 1);
  DB.DBA.DAV_PROP_SET_INT (path, 'xml-sql-description', 'RSS based XML document generated by OpenLink Polls', 'dav', null, 0, 0, 1);

  -- ATOM
  path := home || 'Polls.atom';
  DB.DBA.DAV_DELETE_INT (path, 1, null, null, 0);

  content := POLLS.WA.export_atom_sqlx (domain_id, account_id);
  DB.DBA.DAV_RES_UPLOAD_STRSES_INT (path, content, 'text/xml', exec_perm, http_dav_uid (), http_dav_uid () + 1, null, null, 0);
  DB.DBA.DAV_PROP_SET_INT (path, 'xml-template', 'execute', 'dav', null, 0, 0, 1);
  DB.DBA.DAV_PROP_SET_INT (path, 'xml-sql-encoding', 'utf-8', 'dav', null, 0, 0, 1);
  DB.DBA.DAV_PROP_SET_INT (path, 'xml-sql-description', 'ATOM based XML document generated by OpenLink Polls', 'dav', null, 0, 0, 1);

  -- RDF
  path := home || 'Polls.rdf';
  DB.DBA.DAV_DELETE_INT (path, 1, null, null, 0);

  content := POLLS.WA.export_rdf_sqlx (domain_id, account_id);
  DB.DBA.DAV_RES_UPLOAD_STRSES_INT (path, content, 'text/xml', exec_perm, http_dav_uid (), http_dav_uid () + 1, null, null, 0);
  DB.DBA.DAV_PROP_SET_INT (path, 'xml-template', 'execute', 'dav', null, 0, 0, 1);
  DB.DBA.DAV_PROP_SET_INT (path, 'xml-sql-encoding', 'utf-8', 'dav', null, 0, 0, 1);
  DB.DBA.DAV_PROP_SET_INT (path, 'xml-sql-description', 'RDF based XML document generated by OpenLink Polls', 'dav', null, 0, 0, 1);

  -- COMMENT
  path := home || 'Polls.comment';
  DB.DBA.DAV_DELETE_INT (path, 1, null, null, 0);

  content := POLLS.WA.export_comment_sqlx (domain_id, account_id);
  DB.DBA.DAV_RES_UPLOAD_STRSES_INT (path, content, 'text/xml', exec_perm, http_dav_uid (), http_dav_uid () + 1, null, null, 0);
  DB.DBA.DAV_PROP_SET_INT (path, 'xml-template', 'execute', 'dav', null, 0, 0, 1);
  DB.DBA.DAV_PROP_SET_INT (path, 'xml-sql-encoding', 'utf-8', 'dav', null, 0, 0, 1);
  DB.DBA.DAV_PROP_SET_INT (path, 'xml-sql-description', 'RSS discussion based XML document generated by OpenLink Polls', 'dav', null, 0, 0, 1);

  return;
}
;

-------------------------------------------------------------------------------
--
create procedure POLLS.WA.domain_gems_delete(
  in domain_id integer,
  in account_id integer := null,
  in appName varchar := 'Gems',
  in appGems varchar := null)
{
  declare tmp, home, appHome, path varchar;

  if (isnull (account_id))
    account_id := POLLS.WA.domain_owner_id (domain_id);

  home := POLLS.WA.dav_home(account_id);
  if (isnull(home))
    return;

  if (isnull(appGems))
    appGems := POLLS.WA.domain_gems_name(domain_id);
  appHome := home || appName || '/';
  home := appHome || appGems || '/';

  path := home || 'Polls.rss';
  DB.DBA.DAV_DELETE_INT (path, 1, null, null, 0);
  path := home || 'Polls.rdf';
  DB.DBA.DAV_DELETE_INT (path, 1, null, null, 0);
  path := home || 'Polls.atom';
  DB.DBA.DAV_DELETE_INT (path, 1, null, null, 0);
  path := home || 'Polls.comment';
  DB.DBA.DAV_DELETE_INT (path, 1, null, null, 0);

  declare auth_uid, auth_pwd varchar;

  auth_uid := coalesce((SELECT U_NAME FROM WS.WS.SYS_DAV_USER WHERE U_ID = account_id), '');
  auth_pwd := coalesce((SELECT U_PWD FROM WS.WS.SYS_DAV_USER WHERE U_ID = account_id), '');
  if (auth_pwd[0] = 0)
    auth_pwd := pwd_magic_calc(auth_uid, auth_pwd, 1);

  tmp := DB.DBA.DAV_DIR_LIST (home, 0, auth_uid, auth_pwd);
  if (not isinteger(tmp) and not length(tmp))
    DB.DBA.DAV_DELETE_INT (home, 1, null, null, 0);

  tmp := DB.DBA.DAV_DIR_LIST (appHome, 0, auth_uid, auth_pwd);
  if (not isinteger(tmp) and not length(tmp))
    DB.DBA.DAV_DELETE_INT (appHome, 1, null, null, 0);

  return 1;
}
;

-------------------------------------------------------------------------------
--
create procedure POLLS.WA.domain_update (
  inout domain_id integer,
  inout account_id integer)
{
  POLLS.WA.domain_gems_delete (domain_id, account_id, 'Polls', POLLS.WA.domain_name (domain_id) || '_Gems');
  POLLS.WA.domain_gems_create (domain_id, account_id);

  return 1;
}
;

-------------------------------------------------------------------------------
--
create procedure POLLS.WA.domain_owner_id (
  inout domain_id integer)
{
  return (select A.WAM_USER from WA_MEMBER A, WA_INSTANCE B where A.WAM_MEMBER_TYPE = 1 and A.WAM_INST = B.WAI_NAME and B.WAI_ID = domain_id);
}
;

-------------------------------------------------------------------------------
--
create procedure POLLS.WA.domain_owner_name (
  inout domain_id integer)
{
  return (select C.U_NAME from WA_MEMBER A, WA_INSTANCE B, SYS_USERS C where A.WAM_MEMBER_TYPE = 1 and A.WAM_INST = B.WAI_NAME and B.WAI_ID = domain_id and C.U_ID = A.WAM_USER);
}
;

-------------------------------------------------------------------------------
--
create procedure POLLS.WA.domain_delete (
  in domain_id integer)
{
  delete from POLLS.WA.POLL where P_DOMAIN_ID = domain_id;
  delete from POLLS.WA.TAGS where T_DOMAIN_ID = domain_id;
  delete from POLLS.WA.SETTINGS where S_DOMAIN_ID = domain_id;

  POLLS.WA.domain_gems_delete (domain_id);
  POLLS.WA.nntp_update (domain_id, null, null, 1, 0);

  VHOST_REMOVE(lpath => concat('/polls/', cast(domain_id as varchar)));
  return 1;
}
;

-------------------------------------------------------------------------------
--
create procedure POLLS.WA.domain_id (
  in domain_name varchar)
{
  return (select WAI_ID from DB.DBA.WA_INSTANCE where WAI_NAME = domain_name);
}
;

-------------------------------------------------------------------------------
--
create procedure POLLS.WA.domain_name (
  in domain_id integer)
{
  return coalesce((select WAI_NAME from DB.DBA.WA_INSTANCE where WAI_ID = domain_id), 'Polls Instance');
}
;

-------------------------------------------------------------------------------
--
create procedure POLLS.WA.domain_gems_name (
  in domain_id integer)
{
  return concat(POLLS.WA.domain_name(domain_id), '');
}
;

-------------------------------------------------------------------------------
--
create procedure POLLS.WA.domain_nntp_name (
  in domain_id integer)
{
  return POLLS.WA.domain_nntp_name2 (POLLS.WA.domain_name (domain_id), POLLS.WA.domain_owner_name (domain_id));
}
;

-------------------------------------------------------------------------------
--
create procedure POLLS.WA.domain_nntp_name2 (
  in domain_name varchar,
  in owner_name varchar)
{
  return sprintf ('ods.polls.%s.%U', owner_name, POLLS.WA.string2nntp (domain_name));
}
;

-------------------------------------------------------------------------------
--
create procedure POLLS.WA.domain_description (
  in domain_id integer)
{
  return coalesce((select coalesce(WAI_DESCRIPTION, WAI_NAME) from DB.DBA.WA_INSTANCE where WAI_ID = domain_id), 'Polls Instance');
}
;

-------------------------------------------------------------------------------
--
create procedure POLLS.WA.domain_is_public (
  in domain_id integer)
{
  return coalesce((select WAI_IS_PUBLIC from DB.DBA.WA_INSTANCE where WAI_ID = domain_id), 0);
}
;

-------------------------------------------------------------------------------
--
create procedure POLLS.WA.domain_ping (
  in domain_id integer)
{
  for (select WAI_NAME, WAI_DESCRIPTION from DB.DBA.WA_INSTANCE where WAI_ID = domain_id and WAI_IS_PUBLIC = 1) do
  {
    ODS..APP_PING (WAI_NAME, coalesce (WAI_DESCRIPTION, WAI_NAME), POLLS.WA.forum_iri (domain_id), null, POLLS.WA.gems_url (domain_id) || 'Polls.rss');
    ODS..APP_PING (WAI_NAME, coalesce (WAI_DESCRIPTION, WAI_NAME), POLLS.WA.forum_iri (domain_id), null, POLLS.WA.gems_url (domain_id) || 'Polls.atom');
  }
}
;

-------------------------------------------------------------------------------
--
create procedure POLLS.WA.domain_sioc_url (
  in domain_id integer,
  in sid varchar := null,
  in realm varchar := null)
{
  declare S varchar;

  S := POLLS.WA.iri_fix (POLLS.WA.forum_iri (domain_id));
  return POLLS.WA.url_fix (S, sid, realm);
}
;

-------------------------------------------------------------------------------
--
create procedure POLLS.WA.forum_iri (
  in domain_id integer)
{
  return SIOC..polls_iri (POLLS.WA.domain_name (domain_id));
}
;

-------------------------------------------------------------------------------
--
create procedure POLLS.WA.acl_graph (
  in domain_id integer)
{
  return SIOC..acl_graph ('Polls', POLLS.WA.domain_name (domain_id));
}
;

-------------------------------------------------------------------------------
--
create procedure POLLS.WA.page_url (
  in domain_id integer,
  in page varchar := null,
  in sid varchar := null,
  in realm varchar := null)
{
  declare S varchar;

  S := POLLS.WA.iri_fix (POLLS.WA.forum_iri (domain_id));
  if (not isnull (page))
    S := S || '/' || page;
  return POLLS.WA.url_fix (S, sid, realm);
}
;

-------------------------------------------------------------------------------
--
-- Account Functions
--
-------------------------------------------------------------------------------
create procedure POLLS.WA.account()
{
  declare vspx_user varchar;

  vspx_user := connection_get('owner_user');
  if (isnull(vspx_user))
    vspx_user := connection_get('vspx_user');
  return vspx_user;
}
;

-------------------------------------------------------------------------------
--
create procedure POLLS.WA.account_access (
  out auth_uid varchar,
  out auth_pwd varchar)
{
  auth_uid := POLLS.WA.account();
  auth_pwd := coalesce((SELECT U_PWD FROM WS.WS.SYS_DAV_USER WHERE U_NAME = auth_uid), '');
  if (auth_pwd[0] = 0)
    auth_pwd := pwd_magic_calc(auth_uid, auth_pwd, 1);
  return 1;
}
;

-------------------------------------------------------------------------------
--
create procedure POLLS.WA.account_delete(
  in domain_id integer,
  in account_id integer)
{
  return 1;
}
;

-------------------------------------------------------------------------------
--
create procedure POLLS.WA.account_name (
  in account_id integer)
{
  return coalesce((select U_NAME from DB.DBA.SYS_USERS where U_ID = account_id), '');
}
;

-------------------------------------------------------------------------------
--
create procedure POLLS.WA.account_password (
  in account_id integer)
{
  return coalesce ((select pwd_magic_calc(U_NAME, U_PWD, 1) from WS.WS.SYS_DAV_USER where U_ID = account_id), '');
}
;

-------------------------------------------------------------------------------
--
create procedure POLLS.WA.account_fullName (
  in account_id integer)
{
  return coalesce ((select POLLS.WA.user_name (U_NAME, U_FULL_NAME) from DB.DBA.SYS_USERS where U_ID = account_id), '');
}
;

-------------------------------------------------------------------------------
--
create procedure POLLS.WA.account_mail(
  in account_id integer)
{
  return coalesce((select U_E_MAIL from DB.DBA.SYS_USERS where U_ID = account_id), '');
}
;

-------------------------------------------------------------------------------
--
create procedure POLLS.WA.account_sioc_url (
  in domain_id integer,
  in sid varchar := null,
  in realm varchar := null)
{
  declare S varchar;

  S := POLLS.WA.iri_fix (SIOC..person_iri (SIOC..user_iri (POLLS.WA.domain_owner_id (domain_id), null)));
  return POLLS.WA.url_fix (S, sid, realm);
}
;

-------------------------------------------------------------------------------
--
create procedure POLLS.WA.account_basicAuthorization (
  in account_id integer)
{
  declare account_name, account_password varchar;

  account_name := POLLS.WA.account_name (account_id);
  account_password := POLLS.WA.account_password (account_id);
  return sprintf ('Basic %s', encode_base64 (account_name || ':' || account_password));
}
;

-------------------------------------------------------------------------------
--
create procedure POLLS.WA.user_name(
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
create procedure POLLS.WA.tag_prepare(
  inout tag varchar)
{
  if (not is_empty_or_null(tag)) {
    tag := trim(tag);
    tag := replace(tag, '  ', ' ');
  }
  return tag;
}
;

-------------------------------------------------------------------------------
--
create procedure POLLS.WA.tag_delete(
  inout tags varchar,
  inout T integer)
{
  declare N integer;
  declare tags2 any;

  tags2 := POLLS.WA.tags2vector(tags);
  tags := '';
  for (N := 0; N < length(tags2); N := N + 1)
    if (N <> T)
      tags := concat(tags, ',', tags2[N]);
  return trim(tags, ',');
}
;

-------------------------------------------------------------------------------
--
create procedure POLLS.WA.tag_id (
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
create procedure POLLS.WA.tags_join(
  inout tags varchar,
  inout tags2 varchar)
{
  declare resultTags any;

  if (is_empty_or_null(tags))
    tags := '';
  if (is_empty_or_null(tags2))
    tags2 := '';

  resultTags := concat(tags, ',', tags2);
  resultTags := POLLS.WA.tags2vector(resultTags);
  resultTags := POLLS.WA.tags2unique(resultTags);
  resultTags := POLLS.WA.vector2tags(resultTags);
  return resultTags;
}
;

---------------------------------------------------------------------------------
--
create procedure POLLS.WA.tags2vector(
  inout tags varchar)
{
  return split_and_decode(trim(tags, ','), 0, '\0\0,');
}
;

---------------------------------------------------------------------------------
--
create procedure POLLS.WA.tags2search(
  in tags varchar)
{
  declare S varchar;
  declare V any;

  S := '';
  V := POLLS.WA.tags2vector(tags);
  foreach (any tag in V) do
    S := concat(S, ' ^T', replace (replace (trim(lcase(tag)), ' ', '_'), '+', '_'));
  return FTI_MAKE_SEARCH_STRING(trim(S, ','));
}
;

-------------------------------------------------------------------------------
--
create procedure POLLS.WA.vector2tags(
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
create procedure POLLS.WA.tags2unique(
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

-------------------------------------------------------------------------------
--
create procedure POLLS.WA.settings (
  inout domain_id integer)
{
  return coalesce ((select deserialize (blob_to_string (S_DATA)) from POLLS.WA.SETTINGS where S_DOMAIN_ID = domain_id), vector());
}
;

-------------------------------------------------------------------------------
--
create procedure POLLS.WA.settings_init (
  inout settings any)
{
  POLLS.WA.set_keyword ('chars', settings, cast (get_keyword ('chars', settings, '60') as integer));
  POLLS.WA.set_keyword ('rows', settings, cast (get_keyword ('rows', settings, '10') as integer));
  POLLS.WA.set_keyword ('tbLabels', settings, cast (get_keyword ('tbLabels', settings, '1') as integer));
  POLLS.WA.set_keyword ('atomVersion', settings, get_keyword ('atomVersion', settings, '1.0'));
  POLLS.WA.set_keyword ('conv', settings, cast (get_keyword ('conv', settings, '0') as integer));
  POLLS.WA.set_keyword ('conv_init', settings, cast (get_keyword ('conv_init', settings, '0') as integer));
}
;

-------------------------------------------------------------------------------
--
create procedure POLLS.WA.settings_chars (
  inout account_id integer)
{
  declare settings any;

  settings := POLLS.WA.settings(account_id);
  return cast(get_keyword('chars', settings, '60') as integer);
}
;

-------------------------------------------------------------------------------
--
create procedure POLLS.WA.settings_rows (
  inout settings any)
{
  return cast(get_keyword('rows', settings, '10') as integer);
}
;

-------------------------------------------------------------------------------
--
create procedure POLLS.WA.settings_atomVersion (
  inout domain_id integer)
{
  declare settings any;

  settings := POLLS.WA.settings (domain_id);
  return get_keyword('atomVersion', settings, '1.0');
}
;

-----------------------------------------------------------------------------
--
create procedure POLLS.WA.dav_home(
  inout account_id integer) returns varchar
{
  declare name, home any;
  declare cid integer;

  name := coalesce((select U_NAME from DB.DBA.SYS_USERS where U_ID = account_id), -1);
  if (isinteger(name))
    return null;
  home := POLLS.WA.dav_home_create(name);
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
create procedure POLLS.WA.dav_home_create(
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

-----------------------------------------------------------------------------
--
create procedure POLLS.WA.dav_logical_home (
  inout account_id integer) returns varchar
{
  declare home any;

  home := POLLS.WA.dav_home (account_id);
  if (not isnull (home))
    home := replace (home, '/DAV', '');
  return home;
}
;

-------------------------------------------------------------------------------
--
create procedure POLLS.WA.host_protocol ()
{
  return case when is_https_ctx () then 'https://' else 'http://' end;
}
;

-------------------------------------------------------------------------------
--
create procedure POLLS.WA.host_url ()
{
  declare host varchar;

  declare exit handler for sqlstate '*' { goto _default; };

  if (is_http_ctx ())
  {
    host := http_request_header (http_request_header ( ) , 'Host' , null , sys_connected_server_address ());
    if (isstring (host) and strchr (host , ':') is null)
    {
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
  if (host not like POLLS.WA.host_protocol () || '%')
    host := POLLS.WA.host_protocol () || host;

  return host;
}
;

-------------------------------------------------------------------------------
--
create procedure POLLS.WA.polls_url (
  in domain_id integer)
{
  return concat(POLLS.WA.host_url(), '/polls/', cast(domain_id as varchar), '/');
}
;

-------------------------------------------------------------------------------
--
create procedure POLLS.WA.sioc_url (
  in domain_id integer)
{
  return sprintf('http://%s/dataspace/%U/polls/%U/sioc.rdf', DB.DBA.wa_cname (), POLLS.WA.domain_owner_name (domain_id), replace (POLLS.WA.domain_name (domain_id), '+', '%2B'));
}
;

-------------------------------------------------------------------------------
--
create procedure POLLS.WA.gems_url (
  in domain_id integer)
{
  return sprintf('http://%s/dataspace/%U/polls/%U/gems/', DB.DBA.wa_cname (), POLLS.WA.domain_owner_name (domain_id), replace (POLLS.WA.domain_name (domain_id), '+', '%2B'));
}
;

-------------------------------------------------------------------------------
--
create procedure POLLS.WA.foaf_url (
  in domain_id integer)
{
  return SIOC..person_iri (sprintf('http://%s%s/%s#this', SIOC..get_cname (), SIOC..get_base_path (), POLLS.WA.domain_owner_name (domain_id)), '/about.rdf');
}
;

-------------------------------------------------------------------------------
--
create procedure POLLS.WA.poll_url (
  in domain_id integer,
  in poll_id integer)
{
  return concat(POLLS.WA.polls_url (domain_id), 'polls.vspx?id=', cast(poll_id as varchar));
}
;

-------------------------------------------------------------------------------
--
create procedure POLLS.WA.dav_url (
  in domain_id integer)
{
  declare home varchar;

  home := POLLS.WA.dav_home (POLLS.WA.domain_owner_id (domain_id));
  if (isnull(home))
    return '';
  return concat ('http://', DB.DBA.wa_cname (), home, 'Polls/', POLLS.WA.domain_gems_name (domain_id), '/');
}
;

-------------------------------------------------------------------------------
--
create procedure POLLS.WA.dav_url2 (
  in domain_id integer,
  in account_id integer)
{
  declare home varchar;

  home := POLLS.WA.dav_home(account_id);
  if (isnull(home))
    return '';
  return replace(concat(home, 'Polls/', POLLS.WA.domain_gems_name(domain_id), '/'), ' ', '%20');
}
;

-------------------------------------------------------------------------------
--
create procedure POLLS.WA.geo_url (
  in domain_id integer,
  in account_id integer)
{
  for (select WAUI_LAT, WAUI_LNG from WA_USER_INFO where WAUI_U_ID = account_id) do
    if ((not isnull(WAUI_LNG)) and (not isnull(WAUI_LAT)))
      return sprintf('\n    <meta name="ICBM" content="%.2f, %.2f"><meta name="DC.title" content="%s">', WAUI_LNG, WAUI_LAT, POLLS.WA.domain_name (domain_id));
  return '';
}
;

-------------------------------------------------------------------------------
--
create procedure POLLS.WA.banner_links (
  in domain_id integer,
  in sid varchar := null,
  in realm varchar := null)
{
  if (domain_id <= 0)
    return 'Public Polls';

  return sprintf ('<a href="%s" title="%s" onclick="javascript: return myA(this);">%V</a> (<a href="%s" title="%s" onclick="javascript: return myA(this);">%V</a>)',
                  POLLS.WA.domain_sioc_url (domain_id),
                  POLLS.WA.domain_name (domain_id),
                  POLLS.WA.domain_name (domain_id),
                  POLLS.WA.account_sioc_url (domain_id),
                  POLLS.WA.account_fullName (POLLS.WA.domain_owner_id (domain_id)),
                  POLLS.WA.account_fullName (POLLS.WA.domain_owner_id (domain_id))
                 );
}
;

-------------------------------------------------------------------------------
--
create procedure POLLS.WA.dav_content (
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
  POLLS.WA.account_access (auth_uid, auth_pwd);
  reqHdr := sprintf('Authorization: Basic %s', encode_base64(auth_uid || ':' || auth_pwd));

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
create procedure POLLS.WA.xslt_root()
{
  declare sHost varchar;

  sHost := cast(registry_get('_polls_path_') as varchar);
  if (sHost = '0')
    return 'file://apps/polls/xslt/';
  if (isnull(strstr(sHost, '/DAV/VAD')))
    return sprintf('file://%sxslt/', sHost);
  return sprintf('virt://WS.WS.SYS_DAV_RES.RES_FULL_PATH.RES_CONTENT:%sxslt/', sHost);
}
;

-------------------------------------------------------------------------------
--
create procedure POLLS.WA.xslt_full(
  in xslt_file varchar)
{
  return concat(POLLS.WA.xslt_root(), xslt_file);
}
;

-----------------------------------------------------------------------------
--
create procedure POLLS.WA.xml_set(
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
  if (not isnull(aEntity))
    pXml := XMLUpdate(pXml, sprintf ('/settings/entry[@ID = "%s"]', id), null);

  if (not is_empty_or_null(value))
  {
    aEntity := xpath_eval('/settings', pXml);
    XMLAppendChildren(aEntity, xtree_doc(sprintf ('<entry ID="%s">%s</entry>', id, POLLS.WA.xml2string(POLLS.WA.utf2wide(value)))));
  }
  return pXml;
}
;

-----------------------------------------------------------------------------
--
create procedure POLLS.WA.xml_get(
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

  return POLLS.WA.wide2utf(value);
}
;

-------------------------------------------------------------------------------
--
create procedure POLLS.WA.string2xml (
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
create procedure POLLS.WA.xml2string(
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
create procedure POLLS.WA.string2nntp (
  in S varchar)
{
  S := replace (S, '.', '_');
  S := replace (S, '@', '_');
  return sprintf ('%U', S);
}
;

-------------------------------------------------------------------------------
--
create procedure POLLS.WA.normalize_space(
  in S varchar)
{
  return xpath_eval ('normalize-space (string(/a))', XMLELEMENT('a', S), 1);
}
;

-------------------------------------------------------------------------------
--
create procedure POLLS.WA.utfClear(
  in S varchar)
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
create procedure POLLS.WA.utf2wide (
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
create procedure POLLS.WA.wide2utf (
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
create procedure POLLS.WA.stringCut (
  in S varchar,
  in L integer := 60)
{
  declare tmp any;

  if (not L)
    return S;
  tmp := POLLS.WA.utf2wide(S);
  if (not iswidestring(tmp))
    return S;
  if (length(tmp) > L)
    return POLLS.WA.wide2utf(concat(subseq(tmp, 0, L-3), '...'));
  return POLLS.WA.wide2utf(tmp);
}
;

-------------------------------------------------------------------------------
--
create procedure POLLS.WA.vector_unique(
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
create procedure POLLS.WA.vector_except(
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
create procedure POLLS.WA.vector_contains(
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
create procedure POLLS.WA.vector_cut(
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
create procedure POLLS.WA.vector_set (
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
create procedure POLLS.WA.vector_search(
  in aVector any,
  in value varchar,
  in condition varchar := 'AND')
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
create procedure POLLS.WA.vector2str(
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
create procedure POLLS.WA.vector2rs(
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
create procedure POLLS.WA.tagsDictionary2rs(
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
create procedure POLLS.WA.vector2src(
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
create procedure POLLS.WA.ft2vector(
  in S any)
{
  declare w varchar;
  declare aResult any;

  aResult := vector();
  w := regexp_match ('["][^"]+["]|[''][^'']+['']|[^"'' ]+', S, 1);
  while (w is not null) {
    w := trim (w, '"'' ');
    if (upper(w) not in ('AND', 'NOT', 'NEAR', 'OR') and length (w) > 1 and not vt_is_noise (POLLS.WA.wide2utf(w), 'utf-8', 'x-ViDoc'))
      aResult := vector_concat(aResult, vector(w));
    w := regexp_match ('["][^"]+["]|[''][^'']+['']|[^"'' ]+', S, 1);
  }
  return aResult;
}
;

-------------------------------------------------------------------------------
--
create procedure POLLS.WA.set_keyword (
  in    name   varchar,
  inout params any,
  in    value  any)
{
  declare N integer;

  for (N := 0; N < length(params); N := N + 2)
    if (params[N] = name)
    {
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
create procedure POLLS.WA.show_text(
  in S any,
  in S2 any)
{
  if (isstring(S))
    S := trim(S);
  if (is_empty_or_null(S))
    return sprintf('~ no %s ~', S2);
  return S;
}
;

-------------------------------------------------------------------------------
--
create procedure POLLS.WA.show_title(
  in S any)
{
  return POLLS.WA.show_text(S, 'title');
}
;

-------------------------------------------------------------------------------
--
create procedure POLLS.WA.show_author(
  in S any)
{
  return POLLS.WA.show_text(S, 'author');
}
;

-------------------------------------------------------------------------------
--
create procedure POLLS.WA.show_description(
  in S any)
{
  return POLLS.WA.show_text(S, 'description');
}
;

-------------------------------------------------------------------------------
--
create procedure POLLS.WA.show_excerpt(
  in S varchar,
  in words varchar)
{
  return coalesce(search_excerpt (words, cast(S as varchar)), '');
}
;

-------------------------------------------------------------------------------
--
-- Date / Time functions
--
-------------------------------------------------------------------------------
-- returns system time in GMT
--
create procedure POLLS.WA.dt_current_time()
{
  return dateadd('minute', - timezone(now()), now());
}
;

-------------------------------------------------------------------------------
--
-- convert from GMT date to user timezone;
--
create procedure POLLS.WA.dt_gmt2user(
  in pDate datetime,
  in pUser varchar := null)
{
  declare tz integer;

  if (isnull(pDate))
    return null;
  if (isnull(pUser))
    pUser := connection_get('owner_user');
  if (isnull(pUser))
    pUser := connection_get('vspx_user');
  if (isnull(pUser))
    return pDate;
  tz := cast(coalesce(USER_GET_OPTION(pUser, 'TIMEZONE'), timezone(now())/60) as integer) * 60;
  return dateadd('minute', tz, pDate);
}
;

-------------------------------------------------------------------------------
--
-- convert from the user timezone to GMT date
--
create procedure POLLS.WA.dt_user2gmt(
  in pDate datetime,
  in pUser varchar := null)
{
  declare tz integer;

  if (isnull(pDate))
    return null;
  if (isnull(pUser))
    pUser := connection_get('owner_user');
  if (isnull(pUser))
    pUser := connection_get('vspx_user');
  if (isnull(pUser))
    return pDate;
  tz := cast(coalesce(USER_GET_OPTION(pUser, 'TIMEZONE'), 0) as integer) * 60;
  return dateadd('minute', -tz, pDate);
}
;

-----------------------------------------------------------------------------
--
create procedure POLLS.WA.dt_value (
  in pDate datetime,
  in pUser datetime := null)
{
  if (isnull(pDate))
    return pDate;
  pDate := POLLS.WA.dt_gmt2user(pDate, pUser);
  if (POLLS.WA.dt_format(pDate, 'D.M.Y') = POLLS.WA.dt_format(now(), 'D.M.Y'))
    return concat('today ', POLLS.WA.dt_format(pDate, 'H:N'));
  return POLLS.WA.dt_format(pDate, 'D.M.Y H:N');
}
;

-----------------------------------------------------------------------------
--
create procedure POLLS.WA.dt_date (
  in pDate datetime,
  in pUser datetime := null)
{
  if (isnull(pDate))
    return pDate;
  return POLLS.WA.dt_format (pDate, 'Y-M-D');
}
;

-----------------------------------------------------------------------------
--
create procedure POLLS.WA.dt_format(
  in pDate datetime,
  in pFormat varchar := 'd.m.Y')
{
  declare N integer;
  declare ch, S varchar;

  declare exit handler for sqlstate '*' {
    return '';
  };

  S := '';
  for (N := 1; N <= length(pFormat); N := N + 1)
  {
    ch := substring(pFormat, N, 1);
    if (ch = 'M')
    {
      S := concat(S, xslt_format_number(month(pDate), '00'));
    }
    else if (ch = 'm')
      {
        S := concat(S, xslt_format_number(month(pDate), '##'));
    }
    else if (ch = 'Y')
        {
          S := concat(S, xslt_format_number(year(pDate), '0000'));
    }
    else if (ch = 'y')
          {
            S := concat(S, substring(xslt_format_number(year(pDate), '0000'),3,2));
    }
    else if (ch = 'd')
            {
              S := concat(S, xslt_format_number(dayofmonth(pDate), '##'));
    }
    else if (ch = 'D')
              {
                S := concat(S, xslt_format_number(dayofmonth(pDate), '00'));
    }
    else if (ch = 'H')
                {
                  S := concat(S, xslt_format_number(hour(pDate), '00'));
    }
    else if (ch = 'h')
                  {
                    S := concat(S, xslt_format_number(hour(pDate), '##'));
    }
    else if (ch = 'N')
                    {
                      S := concat(S, xslt_format_number(minute(pDate), '00'));
    }
    else if (ch = 'n')
                      {
                        S := concat(S, xslt_format_number(minute(pDate), '##'));
    }
    else if (ch = 'S')
                        {
                          S := concat(S, xslt_format_number(second(pDate), '00'));
    }
    else if (ch = 's')
                          {
                            S := concat(S, xslt_format_number(second(pDate), '##'));
    }
    else
                          {
                            S := concat(S, ch);
    }
  }
  return S;
}
;

-----------------------------------------------------------------------------------------
--
create procedure POLLS.WA.dt_deformat(
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
      m := POLLS.WA.dt_deformat_tmp(pString, I);
    if (ch = 'D')
      d := POLLS.WA.dt_deformat_tmp(pString, I);
    if (ch = 'Y') {
      y := POLLS.WA.dt_deformat_tmp(pString, I);
      if (y < 50)
        y := 2000 + y;
      if (y < 100)
        y := 1900 + y;
    };
    N := N + 1;
  };
  return stringdate(concat(cast(m as varchar), '.', cast(d as varchar), '.', cast(y as varchar)));
}
;

-----------------------------------------------------------------------------
--
create procedure POLLS.WA.dt_deformat_tmp(
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
create procedure POLLS.WA.dt_reformat(
  in pString varchar,
  in pInFormat varchar := 'd.m.Y',
  in pOutFormat varchar := 'm.d.Y')
{
  return POLLS.WA.dt_format(POLLS.WA.dt_deformat(pString, pInFormat), pOutFormat);
}
;

-----------------------------------------------------------------------------------------
--
create procedure POLLS.WA.dt_convert(
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
create procedure POLLS.WA.dt_rfc1123 (
  in dt datetime)
{
  return soap_print_box (dt, '', 1);
}
;

-----------------------------------------------------------------------------------------
--
create procedure POLLS.WA.dt_iso8601 (
  in dt datetime)
{
  return soap_print_box (dt, '', 0);
}
;

-----------------------------------------------------------------------------------------
--
create procedure POLLS.WA.test_clear (
  in S any)
{
  S := substring (S, 1, coalesce (strstr (S, '<>'), length (S)));
  S := substring (S, 1, coalesce (strstr (S, '\nin'), length (S)));

  return S;
}
;

-----------------------------------------------------------------------------------------
--
create procedure POLLS.WA.test (
  in value any,
  in params any := null)
{
  declare valueType, valueClass, valueName, valueMessage, tmp any;

  declare exit handler for SQLSTATE '*' {
    if (not is_empty_or_null(valueMessage))
      signal ('TEST', valueMessage);
    if (__SQL_STATE = 'EMPTY')
      signal ('TEST', sprintf('Field ''%s'' cannot be empty!<>', valueName));
    if (__SQL_STATE = 'CLASS') {
      if (valueType in ('free-text', 'tags')) {
        signal ('TEST', sprintf('Field ''%s'' contains invalid characters or noise words!<>', valueName));
      } else {
        signal ('TEST', sprintf('Field ''%s'' contains invalid characters!<>', valueName));
      }
    }
    if (__SQL_STATE = 'TYPE')
      signal ('TEST', sprintf('Field ''%s'' contains invalid characters for \'%s\'!<>', valueName, valueType));
    if (__SQL_STATE = 'MIN')
      signal ('TEST', sprintf('''%s'' value should be greater than %s!<>', valueName, cast(tmp as varchar)));
    if (__SQL_STATE = 'MAX')
      signal ('TEST', sprintf('''%s'' value should be less than %s!<>', valueName, cast(tmp as varchar)));
    if (__SQL_STATE = 'MINLENGTH')
      signal ('TEST', sprintf('The length of field ''%s'' should be greater than %s characters!<>', valueName, cast(tmp as varchar)));
    if (__SQL_STATE = 'MAXLENGTH')
      signal ('TEST', sprintf('The length of field ''%s'' should be less than %s characters!<>', valueName, cast(tmp as varchar)));
    if (__SQL_STATE = 'SPECIAL')
      signal ('TEST', __SQL_MESSAGE);
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
  if (isnull(tmp)) {
    if (not isnull(get_keyword('minValue', params))) {
      tmp := 0;
    } else if (get_keyword('minLength', params, 0) <> 0) {
      tmp := 0;
    }
  }
  if (not isnull(tmp) and (tmp = 0) and is_empty_or_null(value)) {
    signal('EMPTY', '');
  } else if (is_empty_or_null(value)) {
    return value;
  }

  value := POLLS.WA.validate2 (valueClass, value);

  if (valueType = 'integer') {
    tmp := get_keyword('minValue', params);
    if ((not isnull(tmp)) and (value < tmp))
      signal('MIN', cast(tmp as varchar));

    tmp := get_keyword('maxValue', params);
    if (not isnull(tmp) and (value > tmp))
      signal('MAX', cast(tmp as varchar));

  } else if (valueType = 'float') {
    tmp := get_keyword('minValue', params);
    if (not isnull(tmp) and (value < tmp))
      signal('MIN', cast(tmp as varchar));

    tmp := get_keyword('maxValue', params);
    if (not isnull(tmp) and (value > tmp))
      signal('MAX', cast(tmp as varchar));

  } else if (valueType = 'varchar') {
    tmp := get_keyword('minLength', params);
    if (not isnull(tmp) and (length(POLLS.WA.utf2wide(value)) < tmp))
      signal('MINLENGTH', cast(tmp as varchar));

    tmp := get_keyword('maxLength', params);
    if (not isnull(tmp) and (length(POLLS.WA.utf2wide(value)) > tmp))
      signal('MAXLENGTH', cast(tmp as varchar));
  }
  return value;
}
;

-----------------------------------------------------------------------------------------
--
create procedure POLLS.WA.validate2 (
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
    if (isnull(regexp_match('^[0-9]+\$', propertyValue)))
      goto _error;
    return cast(propertyValue as integer);
  } else if (propertyType = 'float') {
    if (isnull(regexp_match('^[-+]?([0-9]*\.)?[0-9]+([eE][-+]?[0-9]+)?\$', propertyValue)))
      goto _error;
    return cast(propertyValue as float);
  } else if (propertyType = 'dateTime') {
    if (isnull(regexp_match('^((?:19|20)[0-9][0-9])[- /.](0[1-9]|1[012])[- /.](0[1-9]|[12][0-9]|3[01]) ([01]?[0-9]|[2][0-3])(:[0-5][0-9])?\$', propertyValue)))
      goto _error;
    return cast(propertyValue as datetime);
  } else if (propertyType = 'dateTime2') {
    if (isnull(regexp_match('^((?:19|20)[0-9][0-9])[- /.](0[1-9]|1[012])[- /.](0[1-9]|[12][0-9]|3[01]) ([01]?[0-9]|[2][0-3])(:[0-5][0-9])?\$', propertyValue)))
      goto _error;
    return cast(propertyValue as datetime);
  } else if (propertyType = 'date') {
    if (isnull(regexp_match('^((?:19|20)[0-9][0-9])[- /.](0[1-9]|1[012])[- /.](0[1-9]|[12][0-9]|3[01])\$', propertyValue)))
      goto _error;
    return cast(propertyValue as datetime);
  } else if (propertyType = 'date2') {
    if (isnull(regexp_match('^(0[1-9]|[12][0-9]|3[01])[- /.](0[1-9]|1[012])[- /.]((?:19|20)[0-9][0-9])\$', propertyValue)))
      goto _error;
    return stringdate(POLLS.WA.dt_reformat(propertyValue, 'd.m.Y', 'Y-M-D'));
  } else if (propertyType = 'time') {
    if (isnull(regexp_match('^([01]?[0-9]|[2][0-3])(:[0-5][0-9])?\$', propertyValue)))
      goto _error;
    return cast(propertyValue as time);
  } else if (propertyType = 'folder') {
    if (isnull(regexp_match('^[^\\\/\?\*\"\'\>\<\:\|]*\$', propertyValue)))
      goto _error;
  } else if ((propertyType = 'uri') or (propertyType = 'anyuri')) {
    if (isnull (regexp_match ('^(ht|f)tp(s?)\:\/\/[0-9a-zA-Z]([-.\w]*[0-9a-zA-Z])*(:(0-9)*)*(\/?)([a-zA-Z0-9\-\.\?\,\'\/\\\+&amp;%\$#_=:~]*)?\$', propertyValue)))
      goto _error;
  } else if (propertyType = 'email') {
    if (isnull(regexp_match('^([a-zA-Z0-9_\-])+(\.([a-zA-Z0-9_\-])+)*@((\[(((([0-1])?([0-9])?[0-9])|(2[0-4][0-9])|(2[0-5][0-5])))\.(((([0-1])?([0-9])?[0-9])|(2[0-4][0-9])|(2[0-5][0-5])))\.(((([0-1])?([0-9])?[0-9])|(2[0-4][0-9])|(2[0-5][0-5])))\.(((([0-1])?([0-9])?[0-9])|(2[0-4][0-9])|(2[0-5][0-5]))\]))|((([a-zA-Z0-9])+(([\-])+([a-zA-Z0-9])+)*\.)+([a-zA-Z])+(([\-])+([a-zA-Z0-9])+)*))\$', propertyValue)))
      goto _error;
  } else if (propertyType = 'free-text') {
    if (length(propertyValue))
      if (not POLLS.WA.validate_freeTexts(propertyValue))
        goto _error;
  } else if (propertyType = 'free-text-expression') {
    if (length(propertyValue))
      if (not POLLS.WA.validate_freeText(propertyValue))
        goto _error;
  } else if (propertyType = 'tags') {
    if (not POLLS.WA.validate_tags(propertyValue))
      goto _error;
  }
  return propertyValue;

_error:
  signal('CLASS', propertyType);
}
;

-----------------------------------------------------------------------------------------
--
create procedure POLLS.WA.validate (
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
    if (isnull(regexp_match('^[0-9]+\$', propertyValue)))
      return 0;
    tmp := cast(propertyValue as integer);
  } else if (propertyType = 'float') {
    if (isnull(regexp_match('^[-+]?([0-9]*\.)?[0-9]+([eE][-+]?[0-9]+)?\$', propertyValue)))
      return 0;
    tmp := cast(propertyValue as float);
  } else if (propertyType = 'dateTime') {
    if (isnull(regexp_match('^((?:19|20)[0-9][0-9])[- /.](0[1-9]|1[012])[- /.](0[1-9]|[12][0-9]|3[01]) ([01]?[0-9]|[2][0-3])(:[0-5][0-9])?\$', propertyValue)))
      return 0;
  } else if (propertyType = 'dateTime2') {
    if (isnull(regexp_match('^((?:19|20)[0-9][0-9])[- /.](0[1-9]|1[012])[- /.](0[1-9]|[12][0-9]|3[01]) ([01]?[0-9]|[2][0-3])(:[0-5][0-9])?\$', propertyValue)))
      return 0;
  } else if (propertyType = 'date') {
    if (isnull(regexp_match('^((?:19|20)[0-9][0-9])[- /.](0[1-9]|1[012])[- /.](0[1-9]|[12][0-9]|3[01])\$', propertyValue)))
      return 0;
  } else if (propertyType = 'date2') {
    if (isnull(regexp_match('^(0[1-9]|[12][0-9]|3[01])[- /.](0[1-9]|1[012])[- /.]((?:19|20)[0-9][0-9])\$', propertyValue)))
      return 0;
  } else if (propertyType = 'time') {
    if (isnull(regexp_match('^([01]?[0-9]|[2][0-3])(:[0-5][0-9])?\$', propertyValue)))
      return 0;
  } else if (propertyType = 'folder') {
    if (isnull(regexp_match('^[^\\\/\?\*\"\'\>\<\:\|]*\$', propertyValue)))
      return 0;
  } else if (propertyType = 'uri') {
    if (isnull(regexp_match('^(ht|f)tp(s?)\:\/\/[0-9a-zA-Z]([-.\w]*[0-9a-zA-Z])*(:(0-9)*)*(\/?)([a-zA-Z0-9\-\.\?\,\'\/\\\+&amp;%\$#_]*)?\$', propertyValue)))
      return 0;
  }
  return 1;
}
;

-----------------------------------------------------------------------------------------
--
create procedure POLLS.WA.validate_freeText (
  in S varchar)
{
  declare st, msg varchar;

  if (upper(S) in ('AND', 'NOT', 'NEAR', 'OR'))
    return 0;
  if (length (S) < 2)
    return 0;
  if (vt_is_noise (POLLS.WA.wide2utf(S), 'utf-8', 'x-ViDoc'))
    return 0;
  st := '00000';
  exec (sprintf('vt_parse (\'[__lang "x-ViDoc" __enc "utf-8"] %s\')', S), st, msg, vector ());
  if (st <> '00000')
    return 0;
  return 1;
}
;

-----------------------------------------------------------------------------------------
--
create procedure POLLS.WA.validate_freeTexts (
  in S any)
{
  declare w varchar;

  w := regexp_match ('["][^"]+["]|[''][^'']+['']|[^"'' ]+', S, 1);
  while (w is not null) {
    w := trim (w, '"'' ');
    if (not POLLS.WA.validate_freeText(w))
      return 0;
    w := regexp_match ('["][^"]+["]|[''][^'']+['']|[^"'' ]+', S, 1);
  }
  return 1;
}
;

-----------------------------------------------------------------------------------------
--
create procedure POLLS.WA.validate_tag (
  in T varchar)
{
  declare S any;
  
  S := T;
  S := replace(trim(S), '+', '_');
  S := replace(trim(S), ' ', '_');
  if (not POLLS.WA.validate_freeText(S))
    return 0;
  if (not isnull(strstr(S, '"')))
    return 0;
  if (not isnull(strstr(S, '''')))
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
create procedure POLLS.WA.validate_tags (
  in S varchar)
{
  declare N integer;
  declare V any;

  V := POLLS.WA.tags2vector(S);
  if (is_empty_or_null(V))
    return 0;
  if (length(V) <> length(POLLS.WA.tags2unique(V)))
    return 0;
  for (N := 0; N < length(V); N := N + 1)
    if (not POLLS.WA.validate_tag(V[N]))
      return 0;
  return 1;
}
;

-----------------------------------------------------------------------------------------
--
create procedure POLLS.WA.checkedAttribute (
  in checkedValue integer,
  in compareValue integer := 1)
{
  if (checkedValue = compareValue)
    return 'checked="checked"';
  return '';
}
;

-----------------------------------------------------------------------------------------
--
-- Polls
--
-----------------------------------------------------------------------------------------
create procedure POLLS.WA.poll_update (
  in id integer,
  in domain_id integer,
  in name varchar,
  in description varchar,
  in tags varchar,
  in multi_vote integer,
  in vote_result integer,
  in vote_result_before integer,
  in vote_result_opened integer,
  in date_start any,
  in date_end any,
  in mode varchar := 'S')
{
  if (id = -1) {
    id := sequence_next ('POLLS.WA.poll_id');
    insert into POLLS.WA.POLL (P_ID, P_DOMAIN_ID, P_MODE, P_NAME, P_DESCRIPTION, P_TAGS, P_CREATED, P_UPDATED, P_MULTI_VOTE, P_VOTE_RESULT, P_VOTE_RESULT_BEFORE, P_VOTE_RESULT_OPENED, P_DATE_START, P_DATE_END)
      values (id, domain_id, mode, name, description, tags, now (), now (), multi_vote, vote_result, vote_result_before, vote_result_opened, date_start, date_end);
  } else {
    update POLLS.WA.POLL
       set P_NAME = name,
           P_DESCRIPTION = description,
           P_TAGS = tags,
           P_UPDATED = now(),
           P_MULTI_VOTE = multi_vote,
           P_VOTE_RESULT = vote_result,
           P_VOTE_RESULT_BEFORE = vote_result_before,
           P_VOTE_RESULT_OPENED = vote_result_opened,
           P_DATE_START = date_start,
           P_DATE_END = date_end
     where P_ID = id and
           P_DOMAIN_ID = domain_id;
  }
  return id;
}
;

create procedure POLLS.WA.poll_acl (
  in domain_id integer,
  in id integer,
  in acl any)
{
  update POLLS.WA.POLL
     set P_ACL = acl
   where P_DOMAIN_ID = domain_id
     and P_ID = id;
}
;

-------------------------------------------------------------------------------
--
create procedure POLLS.WA.poll_delete (
  in id integer)
{
  delete from POLLS.WA.POLL where P_ID = id;
}
;

-------------------------------------------------------------------------------
--
create procedure POLLS.WA.poll_active (
  in id integer)
{
  update POLLS.WA.POLL
     set P_STATE = 'AC'
   where P_ID = id;
}
;

-------------------------------------------------------------------------------
--
create procedure POLLS.WA.poll_close (
  in id integer)
{
  update POLLS.WA.POLL
     set P_STATE = 'CL'
   where P_ID = id;
}
;

-------------------------------------------------------------------------------
--
create procedure POLLS.WA.poll_clear (
  in id integer)
{
  update POLLS.WA.POLL
     set P_VOTES = 0,
         P_VOTED = null
   where P_ID = id;
  delete from POLLS.WA.VOTE where V_POLL_ID = id;
}
;

-------------------------------------------------------------------------------
--
create procedure POLLS.WA.poll_tags_select (
  in id integer,
  in domain_id integer)
{
  return coalesce((select P_TAGS from POLLS.WA.POLL where P_ID = id and P_DOMAIN_ID = domain_id), '');
}
;

-------------------------------------------------------------------------------
--
create procedure POLLS.WA.poll_tags_update (
  in id integer,
  in domain_id integer,
  in tags any)
{
  update POLLS.WA.POLL
     set P_TAGS = tags,
         P_UPDATED = now()
   where P_ID = id and
         P_DOMAIN_ID = domain_id;
}
;

-------------------------------------------------------------------------------
--
create procedure POLLS.WA.poll_description (
  in poll_id integer)
{
  return coalesce ((select coalesce (P_DESCRIPTION, P_NAME) from POLLS.WA.POLL where P_ID = poll_id), '');
}
;

-------------------------------------------------------------------------------
--
create procedure POLLS.WA.poll_rights (
  in domain_id integer,
  in id integer,
  in access_role varchar)
{
  declare retValue varchar;

  retValue := '';
  if (exists (select 1 from POLLS.WA.POLL where P_ID = id and P_DOMAIN_ID = domain_id))
  {
    retValue := POLLS.WA.acl_check (domain_id, id);
    if (retValue = '')
      retValue := access_role;
  }
  return retValue;
}
;

-------------------------------------------------------------------------------
--
create procedure POLLS.WA.poll_is_draft (
  in state any,
  in date_start any,
  in atDate any := null)
{
  if (state <> 'DR')
    return 0;
  if (isnull ( date_start))
    return 1;
  if (isnull (atDate))
    atDate := now ();
  if (atDate >= date_start)
    return 0;
  return 1;
}
;

-------------------------------------------------------------------------------
--
create procedure POLLS.WA.poll_is_active (
  in state any,
  in date_start any,
  in date_end any,
  in atDate any := null)
{
  if (state = 'CL')
    return 0;
  if (state = 'AC')
    return 1;
  if (isnull (date_start))
    return 0;
  if (isnull (atDate))
    atDate := now ();
  if (atDate < date_start)
    return 0;
  if (isnull ( date_end))
    return 1;
  if (atDate > date_end)
    return 0;
  return 1;
}
;

-------------------------------------------------------------------------------
--
create procedure POLLS.WA.poll_is_close (
  in state any,
  in date_end any,
  in atDate any := null)
{
  if (state = 'CL')
    return 1;
  if (isnull ( date_end))
    return 0;
  if (isnull (atDate))
    atDate := now ();
  if (atDate < date_end)
    return 0;
  return 1;
}
;

-------------------------------------------------------------------------------
--
create procedure POLLS.WA.poll_is_voted (
  in votes any)
{
  return case when (is_empty_or_null (votes)) then 0 else 1 end;
}
;

-------------------------------------------------------------------------------
--
create procedure POLLS.WA.poll_enable_edit (
  in domain_id integer,
  in poll_id integer,
  in permissions varchar := 'W')
{
  if (permissions = 'W')
  {
    for (select P_STATE, P_DATE_START from POLLS.WA.POLL where P_DOMAIN_ID = domain_id and P_ID = poll_id) do
    return POLLS.WA.poll_is_draft (P_STATE, P_DATE_START, now ());
  }
  return 0;
}
;

-------------------------------------------------------------------------------
--
create procedure POLLS.WA.poll_enable_delete (
  in domain_id integer,
  in poll_id integer,
  in permissions varchar := 'W')
{
  if ((permissions = 'W') and exists (select 1 from POLLS.WA.POLL where P_DOMAIN_ID = domain_id and P_ID = poll_id))
    return 1;

  return 0;
}
;

-------------------------------------------------------------------------------
--
create procedure POLLS.WA.poll_enable_activate (
  in domain_id integer,
  in poll_id integer,
  in permissions varchar := 'W')
{
  if (permissions = 'W')
  {
    for (select P_STATE, P_DATE_START from POLLS.WA.POLL where P_DOMAIN_ID = domain_id and P_ID = poll_id) do
    return POLLS.WA.poll_is_draft (P_STATE, P_DATE_START);
  }
  return 0;
}
;

-------------------------------------------------------------------------------
--
create procedure POLLS.WA.poll_is_activated (
  in domain_id integer,
  in poll_id integer,
  in permissions varchar := 'W')
{
  if (permissions <> '')
  {
    for (select P_STATE, P_DATE_START, P_DATE_END from POLLS.WA.POLL where P_DOMAIN_ID = domain_id and P_ID = poll_id) do
    return POLLS.WA.poll_is_active (P_STATE, P_DATE_START, P_DATE_END);
  }
  return 0;
}
;

-------------------------------------------------------------------------------
--
create procedure POLLS.WA.poll_enable_close (
  in domain_id integer,
  in poll_id integer,
  in permissions varchar := 'W')
{
  if (permissions = 'W')
  {
    for (select P_STATE, P_DATE_START, P_DATE_END from POLLS.WA.POLL where P_DOMAIN_ID = domain_id and P_ID = poll_id) do
    return POLLS.WA.poll_is_active (P_STATE, P_DATE_START, P_DATE_END);
  }
  return 0;
}
;

-------------------------------------------------------------------------------
--
create procedure POLLS.WA.poll_is_closed (
  in domain_id integer,
  in poll_id integer,
  in permissions varchar := 'W')
{
  if (permissions <> '')
  {
    for (select P_STATE, P_DATE_END from POLLS.WA.POLL where P_DOMAIN_ID = domain_id and P_ID = poll_id) do
    return POLLS.WA.poll_is_close (P_STATE, P_DATE_END);
  }
  return 0;
}
;

-------------------------------------------------------------------------------
--
create procedure POLLS.WA.poll_enable_clear (
  in domain_id integer,
  in poll_id integer,
  in permissions varchar := 'W')
{
  if (permissions = 'W')
  {
    for (select P_VOTES, P_STATE, P_DATE_START, P_DATE_END from POLLS.WA.POLL where P_DOMAIN_ID = domain_id and P_ID = poll_id) do
    if ((P_VOTES > 0) and (POLLS.WA.poll_is_active (P_STATE, P_DATE_START, P_DATE_END)))
        return 1;
  }
  return 0;
}
;

-------------------------------------------------------------------------------
--
create procedure POLLS.WA.poll_enable_vote (
  in domain_id integer,
  in poll_id integer)
{
  declare client_id varchar;

  for (select * from POLLS.WA.POLL where P_DOMAIN_ID = domain_id and P_ID = poll_id) do
  {
    if (not (POLLS.WA.poll_is_active (P_STATE, P_DATE_START, P_DATE_END)))
      return 0;
    if (P_MULTI_VOTE = 1)
      return 1;
    client_id := client_attr ('client_ip');
    for (select V_CLIENT_ID from POLLS.WA.VOTE where V_POLL_ID = poll_id and V_CLIENT_ID = client_id) do
      return 0;
    return 1;
  }
  return 0;
}
;

-------------------------------------------------------------------------------
--
--  0 - Not found
-- -1 - Poll is not activated and results can not be shown
-- -2 - Poll is closed, user is not voted and results can not be shown
-- -3 - Poll is not closed and results can not be shown
-- -4 - Poll is not voted and results can not be shown. Please vote first
-- -5 - Not voted yet
--
-------------------------------------------------------------------------------
create procedure POLLS.WA.poll_enable_result (
  in domain_id integer,
  in poll_id integer)
{
  declare client_id varchar;

  client_id := client_attr ('client_ip');
  for (select P.*, V.V_CLIENT_ID
         from POLLS.WA.POLL P
                left join POLLS.WA.VOTE V on V.V_POLL_ID = P.P_ID and V.V_CLIENT_ID = client_id
        where P.P_DOMAIN_ID = domain_id and P.P_ID = poll_id) do {
    if (P_VOTES = 0)
      return -5;
    if (POLLS.WA.poll_is_draft (P_STATE, P_DATE_START))
      return -1;
    if (POLLS.WA.poll_is_close (P_STATE, P_DATE_END)) {
      if (P_VOTE_RESULT = 1)
        return 1;
      if (not isnull (V_CLIENT_ID))
        return 1;
      return -2;
    }
    if (POLLS.WA.poll_is_active (P_STATE, P_DATE_START, P_DATE_END)) {
      if (P_VOTE_RESULT_OPENED = 0)
        return -3;
      if (not isnull (V_CLIENT_ID))
        return 1;
      if (P_VOTE_RESULT_BEFORE = 0)
        return -4;
    }
  }
  return 0;
}
;

-----------------------------------------------------------------------------------------
--
-- Questions
--
-----------------------------------------------------------------------------------------
create procedure POLLS.WA.question_update (
  in id integer,
  in poll_id integer,
  in seqNo integer,
  in text varchar,
  in description varchar,
  in required integer,
  in qType varchar,
  in answer any)
{
  if (id <= 0)
  {
    insert into POLLS.WA.QUESTION (Q_POLL_ID, Q_NUMBER, Q_TEXT, Q_DESCRIPTION, Q_REQUIRED, Q_TYPE, Q_ANSWER)
      values (poll_id, seqNo, text, description, required, qType, answer);
  } else {
    update POLLS.WA.QUESTION
       set Q_NUMBER = seqNo,
           Q_TEXT = text,
           Q_DESCRIPTION = description,
           Q_REQUIRED = required,
           Q_TYPE = qType,
           Q_ANSWER = answer
     where Q_ID = id;
  }
  return (select Q_ID from POLLS.WA.QUESTION where Q_POLL_ID = poll_id and Q_NUMBER = seqNo);
}
;

-----------------------------------------------------------------------------------------
--
create procedure POLLS.WA.question_delete (
  in id integer)
{
  delete from POLLS.WA.QUESTION where Q_ID = id;
}
;

-----------------------------------------------------------------------------------------
--
create procedure POLLS.WA.question_delete2 (
  in poll_id integer,
  in seqNo integer)
{
  delete from POLLS.WA.QUESTION where Q_POLL_ID = poll_id and Q_NUMBER = seqNo;
}
;

-----------------------------------------------------------------------------------------
--
-- Questions
--
-----------------------------------------------------------------------------------------
create procedure POLLS.WA.vote_insert (
  in poll_id integer,
  in client_id varchar)
{
  declare id integer;

  id := sequence_next ('POLLS.WA.vote_id');
  insert into POLLS.WA.VOTE (V_ID, V_POLL_ID, V_CLIENT_ID, V_CREATED)
    values (id, poll_id, client_id, now ());
  return id;
}
;

-------------------------------------------------------------------------------
--
create procedure POLLS.WA.answer_insert (
  in vote_id integer,
  in question_id integer,
  in aNumber integer,
  in aValue varchar)
{
  insert into POLLS.WA.ANSWER (A_VOTE_ID, A_QUESTION_ID, A_NUMBER, A_VALUE)
    values (vote_id, question_id, aNumber, aValue);
}
;

-------------------------------------------------------------------------------
--
create procedure POLLS.WA.search_sql (
  inout domain_id integer,
  inout account_id integer,
  in account_rights varchar,
  in data varchar,
  in maxRows varchar := '')
{
  declare S, T, tmp, where2, delimiter2 varchar;

  where2 := ' \n ';
  delimiter2 := '\n and ';

  S := '';
  if (not is_empty_or_null(POLLS.WA.xml_get('MyPolls', data))) {
    S := 'select                         \n' ||
         ' p.P_ID,                       \n' ||
         ' p.P_DOMAIN_ID,                \n' ||
         ' p.P_NAME,                     \n' ||
         ' p.P_TAGS,                     \n' ||
         ' p.P_CREATED,                  \n' ||
         ' p.P_UPDATED                   \n' ||
         'from                           \n' ||
         '  POLLS.WA.POLL p              \n' ||
         'where p.P_DOMAIN_ID = <DOMAIN_ID> <TEXT> <TAGS> <WHERE> \n';
  }
  if (not is_empty_or_null(POLLS.WA.xml_get('PublicPolls', data))) {
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
         '  POLLS.WA.POLL p,             \n' ||
         '  DB.DBA.WA_INSTANCE i         \n' ||
         'where i.WAI_ID = p.P_DOMAIN_ID \n' ||
         '  and i.WAI_IS_PUBLIC = 1    \n' ||
         '  and p.P_DOMAIN_ID <> <DOMAIN_ID> \n' ||
         '  and POLLS.WA.poll_is_draft (P_STATE, P_DATE_START) <> 1 <TEXT> <TAGS> <WHERE> \n';
  }
  S := 'select <MAX> * from (' || S || ') x';
  if (account_rights = '')
  {
    if (is_https_ctx ())
    {
      S := S || ' where SIOC..poll_post_iri (<DOMAIN_ID>, x.P_ID) in (select a.iri from POLLS.WA.acl_list (id)(iri varchar) a where a.id = <DOMAIN_ID>)';
    } else {
      S := S || ' where 1=0';
    }
  }
  T := '';
  tmp := POLLS.WA.xml_get('keywords', data);
  if (not is_empty_or_null(tmp)) {
    T := FTI_MAKE_SEARCH_STRING(tmp);
  } else {
    tmp := POLLS.WA.xml_get('expression', data);
    if (not is_empty_or_null(tmp))
      T := tmp;
  }

  tmp := POLLS.WA.xml_get('tags', data);
  if (not is_empty_or_null(tmp)) {
    if (T = '') {
      T := POLLS.WA.tags2search (tmp);
    } else {
      T := T || ' and ' || POLLS.WA.tags2search (tmp);
    }
  }
  if (T <> '')
    S := replace(S, '<TEXT>', sprintf('and contains(p.P_NAME, \'[__lang "x-ViDoc"] %s\') \n', T));

  if (maxRows <> '')
    maxRows := 'TOP ' || maxRows;

  S := replace(S, '<MAX>', maxRows);
  S := replace(S, '<DOMAIN_ID>', cast(domain_id as varchar));
  S := replace(S, '<ACCOUNT_ID>', cast(account_id as varchar));
  S := replace(S, '<TAGS>', '');
  S := replace(S, '<TEXT>', '');
  S := replace(S, '<WHERE>', where2);

  --dbg_obj_print(S);
  return S;
}
;

-------------------------------------------------------------------------------
--
create procedure POLLS.WA.dashboard_rs(
  in p0 integer)
{
  declare c0 integer;
  declare c1 varchar;
  declare c2 datetime;

  result_names(c0, c1, c2);
  for (select top 10 *
         from (select P_ID,
                      P_NAME,
                      P_UPDATED
                 from POLLS.WA.POLL
                where P_DOMAIN_ID = p0
                order by P_UPDATED desc
              ) x
      ) do
  {
    result (P_ID, P_NAME, coalesce (P_UPDATED, now ()));
  }
}
;

-------------------------------------------------------------------------------
--
create procedure POLLS.WA.dashboard_get(
  in domain_id integer)
{
  declare account_id integer;
  declare aStream any;

  account_id := POLLS.WA.domain_owner_id (domain_id);
  aStream := string_output ();
  http ('<poll-db>', aStream);
  for (select x.* from POLLS.WA.dashboard_rs(p0)(_id integer, _name varchar, _time datetime) x where p0 = domain_id) do
  {
    http ('<poll>', aStream);
    http (sprintf ('<dt>%s</dt>', date_iso8601 (_time)), aStream);
    http (sprintf ('<title><![CDATA[%s]]></title>', _name), aStream);
    http (sprintf ('<link>%V</link>', SIOC..poll_post_iri (domain_id, _id)), aStream);
    http (sprintf ('<from><![CDATA[%s]]></from>', POLLS.WA.account_fullName (account_id)), aStream);
    http (sprintf ('<uid>%s</uid>', POLLS.WA.account_name (account_id)), aStream);
    http ('</poll>', aStream);
  }
  http ('</poll-db>', aStream);
  return string_output_string (aStream);
}
;

-----------------------------------------------------------------------------------------
--
create procedure POLLS.WA.discussion_check ()
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
create procedure POLLS.WA.conversation_enable(
  in domain_id integer)
{
  return cast (get_keyword ('conv', POLLS.WA.settings(domain_id), '0') as integer);
}
;

-----------------------------------------------------------------------------------------
--
create procedure POLLS.WA.cm_root_node (
  in poll_id varchar)
{
  declare root_id any;
  declare xt any;

  root_id := (select PC_ID from POLLS.WA.POLL_COMMENT where PC_POLL_ID = poll_id and PC_PARENT_ID is null);
  xt := (select xmlagg (xmlelement ('node', xmlattributes (PC_ID as id, PC_ID as name, PC_POLL_ID as post)))
           from POLLS.WA.POLL_COMMENT
          where PC_POLL_ID = poll_id
            and PC_PARENT_ID = root_id
          order by PC_UPDATED);
  return xpath_eval ('//node', xt, 0);
}
;

-----------------------------------------------------------------------------------------
--
create procedure POLLS.WA.cm_child_node (
  in poll_id varchar,
  inout node any)
{
  declare parent_id int;
  declare xt any;

  parent_id := xpath_eval ('number (@id)', node);
  poll_id := xpath_eval ('@post', node);

  xt := (select xmlagg (xmlelement ('node', xmlattributes (PC_ID as id, PC_ID as name, PC_POLL_ID as post)))
           from POLLS.WA.POLL_COMMENT
          where PC_POLL_ID = poll_id and PC_PARENT_ID = parent_id order by PC_UPDATED);
  return xpath_eval ('//node', xt, 0);
}
;

-----------------------------------------------------------------------------------------
--
create procedure POLLS.WA.make_rfc_id (
  in poll_id integer,
  in comment_id integer := null)
{
  declare hashed, host any;

  hashed := md5 (uuid ());
  host := sys_stat ('st_host_name');
  if (isnull (comment_id))
    return sprintf ('<%d.%s@%s>', poll_id, hashed, host);
  return sprintf ('<%d.%d.%s@%s>', poll_id, comment_id, hashed, host);
}
;

-----------------------------------------------------------------------------------------
--
create procedure POLLS.WA.make_mail_subject (
  in txt any,
  in id varchar := null)
{
  declare enc any;

  enc := encode_base64 (POLLS.WA.wide2utf (txt));
  enc := replace (enc, '\r\n', '');
  txt := concat ('Subject: =?UTF-8?B?', enc, '?=\r\n');
  if (not isnull (id))
    txt := concat (txt, 'X-Virt-NewsID: ', uuid (), ';', id, '\r\n');
  return txt;
}
;

-----------------------------------------------------------------------------------------
--
create procedure POLLS.WA.make_post_rfc_header (
  in mid varchar,
  in refs varchar,
  in gid varchar,
  in title varchar,
  in rec datetime,
  in author_mail varchar)
{
  declare ses any;

  ses := string_output ();
  http (POLLS.WA.make_mail_subject (title), ses);
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
create procedure POLLS.WA.make_post_rfc_msg (
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
create procedure POLLS.WA.nntp_root (
  in domain_id integer,
  in poll_id integer)
{
  declare owner_id integer;
  declare name, mail, title, comment any;

  owner_id := POLLS.WA.domain_owner_id (domain_id);
  name := POLLS.WA.account_fullName (owner_id);
  mail := POLLS.WA.account_mail (owner_id);

  select coalesce (P_NAME, ''), coalesce (P_DESCRIPTION, '') into title, comment from POLLS.WA.POLL where P_ID = poll_id;
  insert into POLLS.WA.POLL_COMMENT (PC_PARENT_ID, PC_DOMAIN_ID, PC_POLL_ID, PC_TITLE, PC_COMMENT, PC_U_NAME, PC_U_MAIL, PC_CREATED, PC_UPDATED)
    values (null, domain_id, poll_id, title, comment, name, mail, now (), now ());
}
;

-----------------------------------------------------------------------------------------
--
create procedure POLLS.WA.nntp_update_item (
  in domain_id integer,
  in poll_id integer)
{
  declare grp, ngnext integer;
  declare nntpName, rfc_id varchar;

  nntpName := POLLS.WA.domain_nntp_name (domain_id);
  select NG_GROUP, NG_NEXT_NUM into grp, ngnext from DB..NEWS_GROUPS where NG_NAME = nntpName;
  select PC_RFC_ID into rfc_id from POLLS.WA.POLL_COMMENT where PC_DOMAIN_ID = domain_id and PC_POLL_ID = poll_id and PC_PARENT_ID is null;
  if (exists (select 1 from DB.DBA.NEWS_MULTI_MSG where NM_KEY_ID = rfc_id and NM_GROUP = grp))
    return;

  if (ngnext < 1)
    ngnext := 1;

  for (select PC_RFC_ID as rfc_id from POLLS.WA.POLL_COMMENT where PC_DOMAIN_ID = domain_id and PC_POLL_ID = poll_id) do
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
create procedure POLLS.WA.nntp_update (
  in domain_id integer,
  in oInstance varchar,
  in nInstance varchar,
  in oConversation integer := null,
  in nConversation integer := null)
{
  declare nntpGroup integer;
  declare nDescription varchar;

  if (isnull (oInstance))
    oInstance := POLLS.WA.domain_nntp_name (domain_id);

  if (isnull (nInstance))
    nInstance := POLLS.WA.domain_nntp_name (domain_id);

  nDescription := POLLS.WA.domain_description (domain_id);

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
      values (0, nInstance, nDescription, null, 1, now(), now(), 30, 0, 0, 0, 0, 0, 0, 120, 'POLLS');
  }
}
;

-----------------------------------------------------------------------------------------
--
create procedure POLLS.WA.nntp_fill (
  in domain_id integer)
{
  declare exit handler for SQLSTATE '*', not found {
    return;
  };

  declare grp, ngnext integer;
  declare nntpName varchar;

  for (select P_ID from POLLS.WA.POLL where P_DOMAIN_ID = domain_id) do
  {
    if (not exists (select 1 from POLLS.WA.POLL_COMMENT where PC_DOMAIN_ID = domain_id and PC_POLL_ID = P_ID and PC_PARENT_ID is null))
      POLLS.WA.nntp_root (domain_id, P_ID);
  }
  nntpName := POLLS.WA.domain_nntp_name (domain_id);
  select NG_GROUP, NG_NEXT_NUM into grp, ngnext from DB..NEWS_GROUPS where NG_NAME = nntpName;
  if (ngnext < 1)
    ngnext := 1;

  for (select PC_RFC_ID as rfc_id from POLLS.WA.POLL_COMMENT where PC_DOMAIN_ID = domain_id) do
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
create procedure POLLS.WA.mail_address_split (
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
create procedure POLLS.WA.nntp_decode_subject (
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
create procedure POLLS.WA.nntp_process_parts (
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
  while (i1 < l1) {
    declare elm any;
    elm := trim(amime[i1]);
    if (mime1 like elm) {
      is_allowed := 1;
      i1 := l1;
    }
    i1 := i1 + 1;
  }

  declare _cnt_disp any;
  _cnt_disp := get_keyword_ucase('Content-Disposition', part, '');

  if (is_allowed and (any_part or (name1 <> '' and _cnt_disp in ('attachment', 'inline')))) {
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
      POLLS.WA.nntp_process_parts (parts[2][i], body, amime, result, any_part);

  return 0;
}
;

-----------------------------------------------------------------------------------------
--
DB.DBA.NNTP_NEWS_MSG_ADD (
'POLLS',
'select
   \'POLLS\',
   PC_RFC_ID,
   PC_RFC_REFERENCES,
   0,    -- NM_READ
   null,
   PC_UPDATED,
   0,    -- NM_STAT
   null, -- NM_TRY_POST
   0,    -- NM_DELETED
   POLLS.WA.make_post_rfc_msg (PC_RFC_HEADER, PC_COMMENT, 1), -- NM_HEAD
   POLLS.WA.make_post_rfc_msg (PC_RFC_HEADER, PC_COMMENT),
   PC_ID
 from POLLS.WA.POLL_COMMENT'
)
;

-----------------------------------------------------------------------------------------
--
create procedure DB.DBA.POLLS_NEWS_MSG_I (
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
    POLLS.WA.nntp_decode_subject (subject);

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

    POLLS.WA.nntp_process_parts (tree, N_NM_BODY, vector ('text/%'), res, 1);

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
  rfc_header := POLLS.WA.make_mail_subject (subject) || rfc_header || 'Content-Type: text/html; charset=UTF-8\r\n\r\n';

  rfc_references := N_NM_REF;

  if (not isnull (N_NM_REF))
  {
    declare exit handler for not found { signal ('CONV1', 'No such article.');};

    parent_id := null;
    refs := split_and_decode (N_NM_REF, 0, '\0\0 ');
    if (length (refs))
      N_NM_REF := refs[length (refs) - 1];

    select PC_ID, PC_DOMAIN_ID, PC_POLL_ID, PC_TITLE
      into parent_id, domain_id, item_id, title
      from POLLS.WA.POLL_COMMENT
     where PC_RFC_ID = N_NM_REF;

    if (isnull (subject))
      subject := 'Re: '|| title;

    POLLS.WA.mail_address_split (author, name, mail);

    insert into POLLS.WA.POLL_COMMENT (PC_PARENT_ID, PC_DOMAIN_ID, PC_POLL_ID, PC_TITLE, PC_COMMENT, PC_U_NAME, PC_U_MAIL, PC_UPDATED, PC_RFC_ID, PC_RFC_HEADER, PC_RFC_REFERENCES)
      values (parent_id, domain_id, item_id, subject, content, name, mail, N_NM_REC_DATE, N_NM_ID, rfc_header, rfc_references);
  }
}
;

-----------------------------------------------------------------------------------------
--
create procedure DB.DBA.POLLS_NEWS_MSG_U (
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
create procedure DB.DBA.POLLS_NEWS_MSG_D (
  inout O_NM_ID any)
{
  signal ('CONV3', 'Delete of a Polls comment is not allowed');
}
;

-----------------------------------------------------------------------------------------
--
create procedure POLLS.WA.news_comment_get_mess_attachments (inout _data any, in get_uuparts integer)
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
create procedure POLLS.WA.news_comment_get_cn_type (in f_name varchar)
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


-----------------------------------------------------------------------------------------
--
create procedure POLLS.WA.version_update()
{
  for (select WAI_ID, WAM_USER
         from DB.DBA.WA_MEMBER
                join DB.DBA.WA_INSTANCE on WAI_NAME = WAM_INST
        where WAI_TYPE_NAME = 'Polls'
          and WAM_MEMBER_TYPE = 1) do {
    POLLS.WA.domain_update(WAI_ID, WAM_USER);
  }
}
;

-----------------------------------------------------------------------------------------
--
POLLS.WA.version_update()
;
