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
create procedure AB.WA.acl_condition (
  in domain_id integer,
  in id integer := null)
{
  if (not is_https_ctx ())
    return 0;

  if (exists (select 1 from DB.DBA.WA_INSTANCE where WAI_ID = domain_id and WAI_ACL is not null))
    return 1;

  if (exists (select 1 from AB.WA.PERSONS where P_ID = id and P_ACL is not null))
    return 1;

  return 0;
}
;

-------------------------------------------------------------------------------
--
create procedure AB.WA.acl_check (
  in domain_id integer,
  in id integer := null)
{
  declare rc varchar;
  declare graph_iri, groups_iri, acl_iris any;

  rc := '';
  if (AB.WA.acl_condition (domain_id, id))
  {
    acl_iris := vector (AB.WA.forum_iri (domain_id));
    if (not isnull (id))
      acl_iris := vector (SIOC..addressbook_contact_iri (domain_id, id), AB.WA.forum_iri (domain_id));

    graph_iri := AB.WA.acl_graph (domain_id);
    groups_iri := SIOC..acl_groups_graph (AB.WA.domain_owner_id (domain_id));
    rc := SIOC..acl_check (graph_iri, groups_iri, acl_iris);
  }
  return rc;
}
;

-------------------------------------------------------------------------------
--
create procedure AB.WA.acl_list (
  in domain_id integer)
{
  declare graph_iri, groups_iri, iri any;

  iri := AB.WA.forum_iri (domain_id);
  graph_iri := AB.WA.acl_graph (domain_id);
  groups_iri := SIOC..acl_groups_graph (AB.WA.domain_owner_id (domain_id));
  return SIOC..acl_list (graph_iri, groups_iri, iri);
}
;

-------------------------------------------------------------------------------
--
-- Session Functions
--
-------------------------------------------------------------------------------
create procedure AB.WA.session_domain (
  inout params any)
{
  declare aPath, domain_id, options any;

  declare exit handler for sqlstate '*'
  {
    domain_id := -1;
    goto _end;
  };

  options := http_map_get('options');
  if (not is_empty_or_null (options))
  {
    domain_id := get_keyword ('domain', options);
  }
  if (is_empty_or_null (domain_id))
  {
    aPath := split_and_decode (trim (http_path (), '/'), 0, '\0\0/');
    domain_id := cast(aPath[1] as integer);
  }
  if (not exists (select 1 from DB.DBA.WA_INSTANCE where WAI_ID = domain_id and WAI_TYPE_NAME = 'AddressBook'))
    domain_id := -1;

_end:;
  return cast (domain_id as integer);
}
;

-------------------------------------------------------------------------------
--
create procedure AB.WA.session_restore(
  inout params any)
{
  declare domain_id, account_id any;

  domain_id := AB.WA.session_domain (params);
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
  return vector (
                 'domain_id', domain_id,
                 'account_id',   account_id,
                 'account_rights', AB.WA.account_rights (domain_id, account_id),
                 'person_rights', AB.WA.person_rights (domain_id, account_id)
               );
}
;

-------------------------------------------------------------------------------
--
-- Freeze Functions
--
-------------------------------------------------------------------------------
create procedure AB.WA.frozen_check (
  in domain_id integer)
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
create procedure AB.WA.frozen_page (
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
create procedure AB.WA.check_admin(
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
create procedure AB.WA.check_grants (
  in role_name varchar,
  in page_name varchar)
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
create procedure AB.WA.person_rights (
  in domain_id integer,
  in account_id integer)
{
  declare rc varchar;

  if (domain_id <= 0)
    return null;

  if (AB.WA.check_admin (account_id))
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
    rc := AB.WA.acl_check (domain_id);
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

  if (exists(select 1
                from DB.DBA.WA_INSTANCE
               where WAI_ID = domain_id
                 and WAI_IS_PUBLIC = 1))
    return 'R';

  if (is_https_ctx () and exists (select 1 from AB.WA.acl_list (id)(iri varchar) x where x.id = domain_id))
    return '';

  return null;
}
;

-------------------------------------------------------------------------------
--
create procedure AB.WA.account_rights (
  in domain_id integer,
  in account_id integer)
{
  declare rc varchar;

  if (domain_id <= 0)
    return null;

  if (AB.WA.check_admin (account_id))
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

  return null;
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
  <node name="home" url="home.vspx"            id="1"   allowed="W R">
    <node name="11" url="home.vspx"            id="11"  allowed="W R"/>
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
create procedure AB.WA.iri_fix (
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
create procedure AB.WA.url_fix (
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
create procedure AB.WA.exec (
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
  http ('  XMLELEMENT(\'managingEditor\', AB.WA.utf2wide (U_FULL_NAME || \' <\' || U_E_MAIL || \'>\')), \n', retValue);
  http ('  XMLELEMENT(\'pubDate\', AB.WA.dt_rfc1123(now())), \n', retValue);
  http ('  XMLELEMENT(\'generator\', \'Virtuoso Universal Server \' || sys_stat(\'st_dbms_ver\')), \n', retValue);
  http ('  XMLELEMENT(\'webMaster\', U_E_MAIL), \n', retValue);
  http ('  XMLELEMENT(\'link\', AB.WA.ab_url (<DOMAIN_ID>)), \n', retValue);
  http ('  (select XMLAGG (XMLELEMENT(\'http://www.w3.org/2005/Atom:link\', XMLATTRIBUTES (SH_URL as "href", \'hub\' as "rel", \'PubSubHub\' as "title"))) from ODS.DBA.SVC_HOST, ODS.DBA.APP_PING_REG where SH_PROTO = \'PubSubHub\' and SH_ID = AP_HOST_ID and AP_WAI_ID = <DOMAIN_ID>), \n', retValue);
  http ('  XMLELEMENT(\'language\', \'en-us\') \n', retValue);
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
  http ('    XMLELEMENT(\'http://www.openlinksw.com/ods/:modified\', AB.WA.dt_iso8601 (P_UPDATED)))) \n', retValue);
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

-----------------------------------------------------------------------------
--
create procedure AB.WA.export_comment_sqlx(
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
  http ('    XMLELEMENT (\'title\', AB.WA.utf2wide (P_NAME)), \n', retValue);
  http ('    XMLELEMENT (\'description\', AB.WA.utf2wide (AB.WA.xml2string(P_FULL_NAME))), \n', retValue);
  http ('    XMLELEMENT (\'link\', AB.WA.contact_url (<DOMAIN_ID>, P_ID)), \n', retValue);
  http ('    XMLELEMENT (\'pubDate\', AB.WA.dt_rfc1123 (P_CREATED)), \n', retValue);
  http ('    XMLELEMENT (\'generator\', \'Virtuoso Universal Server \' || sys_stat(\'st_dbms_ver\')), \n', retValue);
  http ('    XMLELEMENT (\'http://purl.org/dc/elements/1.1/:creator\', U_FULL_NAME) \n', retValue);
  http ('  from \n', retValue);
  http ('    AB.WA.PERSONS, DB.DBA.SYS_USERS, DB.DBA.WA_INSTANCE \n', retValue);
  http ('  where \n', retValue);
  http ('    P_ID = :id and U_ID = <USER_ID> and P_DOMAIN_ID = <DOMAIN_ID> and WAI_ID = P_DOMAIN_ID and WAI_IS_PUBLIC = 1\n', retValue);
  http (']]></sql:sqlx>\n', retValue);

  http ('<sql:sqlx><![CDATA[\n', retValue);
  http ('  select \n', retValue);
  http ('    XMLAGG (XMLELEMENT(\'item\',\n', retValue);
  http ('    XMLELEMENT (\'title\', AB.WA.utf2wide (PC_TITLE)),\n', retValue);
  http ('    XMLELEMENT (\'guid\', AB.WA.ab_url (<DOMAIN_ID>)||\'conversation.vspx\'||\'?id=\'||cast (PC_PERSON_ID as varchar)||\'#\'||cast (PC_ID as varchar)),\n', retValue);
  http ('    XMLELEMENT (\'link\', AB.WA.ab_url (<DOMAIN_ID>)||\'conversation.vspx\'||\'?id=\'||cast (PC_PERSON_ID as varchar)||\'#\'||cast (PC_ID as varchar)),\n', retValue);
  http ('    XMLELEMENT (\'http://purl.org/dc/elements/1.1/:creator\', PC_U_MAIL),\n', retValue);
  http ('    XMLELEMENT (\'pubDate\', DB.DBA.date_rfc1123 (PC_UPDATED)),\n', retValue);
  http ('    XMLELEMENT (\'description\', AB.WA.utf2wide (blob_to_string (PC_COMMENT))))) \n', retValue);
  http ('  from \n', retValue);
  http ('    (select TOP 15 \n', retValue);
  http ('       PC_ID, \n', retValue);
  http ('       PC_PERSON_ID, \n', retValue);
  http ('       PC_TITLE, \n', retValue);
  http ('       PC_COMMENT, \n', retValue);
  http ('       PC_U_MAIL, \n', retValue);
  http ('       PC_UPDATED \n', retValue);
  http ('     from \n', retValue);
  http ('       AB.WA.PERSON_COMMENTS, DB.DBA.WA_INSTANCE \n', retValue);
  http ('     where \n', retValue);
  http ('       PC_PERSON_ID = :id and WAI_ID = PC_DOMAIN_ID and WAI_IS_PUBLIC = 1\n', retValue);
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
  home := home || 'Gems/';
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

  -- COMMENT
  path := home || 'AddressBook.comment';
  DB.DBA.DAV_DELETE_INT (path, 1, null, null, 0);

  content := AB.WA.export_comment_sqlx (domain_id, account_id);
  DB.DBA.DAV_RES_UPLOAD_STRSES_INT (path, content, 'text/xml', exec_perm, http_dav_uid (), http_dav_uid () + 1, null, null, 0);
  DB.DBA.DAV_PROP_SET_INT (path, 'xml-template', 'execute', 'dav', null, 0, 0, 1);
  DB.DBA.DAV_PROP_SET_INT (path, 'xml-sql-encoding', 'utf-8', 'dav', null, 0, 0, 1);
  DB.DBA.DAV_PROP_SET_INT (path, 'xml-sql-description', 'RSS discussion based XML document generated by OpenLink AddressBook', 'dav', null, 0, 0, 1);

  return;
}
;

-------------------------------------------------------------------------------
--
create procedure AB.WA.domain_gems_delete (
  in domain_id integer,
  in account_id integer := null,
  in appName varchar := 'Gems',
  in appGems varchar := null)
{
  declare tmp, home, appHome, path varchar;

  if (isnull (account_id))
    account_id := AB.WA.domain_owner_id (domain_id);

  home := AB.WA.dav_home (account_id);
  if (isnull (home))
    return;
  appHome := home || appName || '/';

  if (isnull (appGems))
    appGems := AB.WA.domain_gems_name (domain_id);
  appHome := home || appName || '/';
  home := appHome || appGems || '/';

  path := home || 'AddressBook.rss';
  DB.DBA.DAV_DELETE_INT (path, 1, null, null, 0);
  path := home || 'AddressBook.rdf';
  DB.DBA.DAV_DELETE_INT (path, 1, null, null, 0);
  path := home || 'AddressBook.atom';
  DB.DBA.DAV_DELETE_INT (path, 1, null, null, 0);
  path := home || 'AddressBook.comment';
  DB.DBA.DAV_DELETE_INT (path, 1, null, null, 0);

  declare auth_uid, auth_pwd varchar;

  auth_uid := coalesce((SELECT U_NAME FROM WS.WS.SYS_DAV_USER WHERE U_ID = account_id), '');
  auth_pwd := coalesce((SELECT U_PWD FROM WS.WS.SYS_DAV_USER WHERE U_ID = account_id), '');
  if (auth_pwd[0] = 0)
    auth_pwd := pwd_magic_calc (auth_uid, auth_pwd, 1);

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
create procedure AB.WA.domain_update (
  inout domain_id integer,
  inout account_id integer)
{
  AB.WA.domain_gems_delete (domain_id, account_id, 'AddressBook', AB.WA.domain_gems_name (domain_id) || '_Gems');
  AB.WA.domain_gems_create (domain_id, account_id);

  declare home, path varchar;
  home := AB.WA.dav_home (account_id);
  path := home || 'addressbooks' || '/';
  DB.DBA.DAV_MAKE_DIR (path, account_id, null, '110100000N');
  update WS.WS.SYS_DAV_COL set COL_DET = 'CardDAV' where COL_ID = DAV_SEARCH_ID (path, 'C');

  return 1;
}
;

-------------------------------------------------------------------------------
--
create procedure AB.WA.domain_owner_id (
  in domain_id integer)
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
  delete from AB.WA.PERSONS where P_DOMAIN_ID = domain_id;
  delete from AB.WA.CATEGORIES where C_DOMAIN_ID = domain_id;
  delete from AB.WA.TAGS where T_DOMAIN_ID = domain_id;
  delete from AB.WA.EXCHANGE where EX_DOMAIN_ID = domain_id;
  delete from AB.WA.SETTINGS where S_DOMAIN_ID = domain_id;

  AB.WA.domain_gems_delete (domain_id);
  AB.WA.nntp_update (domain_id, null, null, 1, 0);

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
create procedure AB.WA.domain_nntp_name (
  in domain_id integer)
{
  return AB.WA.domain_nntp_name2 (AB.WA.domain_name (domain_id), AB.WA.domain_owner_name (domain_id));
}
;

-------------------------------------------------------------------------------
--
create procedure AB.WA.domain_nntp_name2 (
  in domain_name varchar,
  in owner_name varchar)
{
  return sprintf ('ods.addressbook.%s.%U', owner_name, AB.WA.string2nntp (domain_name));
}
;

-------------------------------------------------------------------------------
--
create procedure AB.WA.domain_gems_name (
  in domain_id integer)
{
  return concat(AB.WA.domain_name (domain_id), '');
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
  for (select WAI_NAME, WAI_DESCRIPTION from DB.DBA.WA_INSTANCE where WAI_ID = domain_id and WAI_IS_PUBLIC = 1) do
  {
    ODS..APP_PING (WAI_NAME, coalesce (WAI_DESCRIPTION, WAI_NAME), AB.WA.forum_iri (domain_id), null, AB.WA.gems_url (domain_id) || 'AddressBook.rss');
    ODS..APP_PING (WAI_NAME, coalesce (WAI_DESCRIPTION, WAI_NAME), AB.WA.forum_iri (domain_id), null, AB.WA.gems_url (domain_id) || 'AddressBook.atom');
  }
}
;

-------------------------------------------------------------------------------
--
create procedure AB.WA.forum_iri (
  in domain_id integer)
{
  return SIOC..addressbook_iri (AB.WA.domain_name (domain_id));
}
;

-------------------------------------------------------------------------------
--
create procedure AB.WA.acl_graph (
  in domain_id integer)
{
  return SIOC..acl_graph ('AddressBook', AB.WA.domain_name (domain_id));
}
;

-------------------------------------------------------------------------------
--
create procedure AB.WA.domain_sioc_url (
  in domain_id integer,
  in sid varchar := null,
  in realm varchar := null)
{
  return AB.WA.url_fix (AB.WA.iri_fix (AB.WA.forum_iri (domain_id)), sid, realm);
}
;

-------------------------------------------------------------------------------
--
create procedure AB.WA.page_url (
  in domain_id integer,
  in page varchar := null,
  in sid varchar := null,
  in realm varchar := null)
{
  declare S varchar;

  S := AB.WA.iri_fix (AB.WA.forum_iri (domain_id));
  if (not isnull (page))
    S := S || '/' || page;
  return AB.WA.url_fix (S, sid, realm);
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
  inout auth_uid varchar,
  inout auth_pwd varchar)
{
  if (isnull (auth_uid))
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

  if (iCount = 0)
  {
    delete from AB.WA.GRANTS where G_GRANTER_ID = account_id or G_GRANTEE_ID = account_id;
  }

  return 1;
}
;

-------------------------------------------------------------------------------
--
create procedure AB.WA.account_id (
  in account_name varchar)
{
  return (select U_ID from DB.DBA.SYS_USERS where U_NAME = account_name);
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
create procedure AB.WA.account_password (
  in account_id integer)
{
  return coalesce ((select pwd_magic_calc(U_NAME, U_PWD, 1) from WS.WS.SYS_DAV_USER where U_ID = account_id), '');
}
;

-------------------------------------------------------------------------------
--
create procedure AB.WA.account_fullName (
  in account_id integer)
{
  return coalesce ((select AB.WA.user_name (U_NAME, U_FULL_NAME) from DB.DBA.SYS_USERS where U_ID = account_id), '');
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
create procedure AB.WA.account_sioc_url (
  in domain_id integer,
  in sid varchar := null,
  in realm varchar := null)
{
  declare S varchar;

  S := AB.WA.iri_fix (SIOC..person_iri (SIOC..user_iri (AB.WA.domain_owner_id (domain_id), null)));
  return AB.WA.url_fix (S, sid, realm);
}
;

-------------------------------------------------------------------------------
--
create procedure AB.WA.account_basicAuthorization (
  in account_id integer)
{
  declare account_name, account_password varchar;

  account_name := AB.WA.account_name (account_id);
  account_password := AB.WA.account_password (account_id);
  return sprintf ('Basic %s', encode_base64 (account_name || ':' || account_password));
}
;

-------------------------------------------------------------------------------
--
create procedure AB.WA.user_name(
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
create procedure AB.WA.tag_prepare(
  inout tag varchar)
{
  if (not is_empty_or_null(tag))
  {
    tag := replace (trim (tag), '  ', ' ');
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

-------------------------------------------------------------------------------
--
create procedure AB.WA.tags_exchangeTest (
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
  tags := AB.WA.tags2vector (tagsEvent);
  testTags := AB.WA.tags2vector (tagsExclude);
  for (N := 0; N < length (tags); N := N + 1)
  {
    if (AB.WA.vector_contains (testTags, tags [N]))
      goto _false;
  }

_include:;
  -- test include tags
  if (is_empty_or_null (tagsInclude))
    goto _true;
  tags := AB.WA.tags2vector (tagsEvent);
  testTags := AB.WA.tags2vector (tagsInclude);
  for (N := 0; N < length (tags); N := N + 1)
  {
    if (AB.WA.vector_contains (testTags, tags [N]))
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
create procedure AB.WA.dav_home(
  inout account_id integer) returns varchar
{
  declare cid, name, home any;

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

-----------------------------------------------------------------------------
--
create procedure AB.WA.dav_logical_home (
  inout account_id integer) returns varchar
{
  declare home any;

  home := AB.WA.dav_home (account_id);
  if (not isnull (home))
    home := replace (home, '/DAV', '');
  return home;
}
;

-------------------------------------------------------------------------------
--
create procedure AB.WA.host_protocol ()
{
  return case when is_https_ctx () then 'https://' else 'http://' end;
}
;

-------------------------------------------------------------------------------
--
create procedure AB.WA.host_url ()
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
  if (host not like AB.WA.host_protocol () || '%')
    host := AB.WA.host_protocol () || host;

  return host;
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
create procedure AB.WA.gems_url (
  in domain_id integer)
{
  return sprintf ('http://%s/dataspace/%U/addressbook/%U/gems/', DB.DBA.wa_cname (), AB.WA.domain_owner_name (domain_id), replace (AB.WA.domain_name (domain_id), '+', '%2B'));
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
create procedure AB.WA.banner_links (
  in domain_id integer,
  in sid varchar := null,
  in realm varchar := null)
{
  if (domain_id <= 0)
    return 'Public AddressBook';

  return sprintf ('<a href="%s" title="%s" onclick="javascript: return myA(this);">%V</a> (<a href="%s" title="%s" onclick="javascript: return myA(this);">%V</a>)',
                  AB.WA.domain_sioc_url (domain_id),
                  AB.WA.domain_name (domain_id),
                  AB.WA.domain_name (domain_id),
                  AB.WA.utf2wide (AB.WA.account_sioc_url (domain_id)),
                  AB.WA.account_fullName (AB.WA.domain_owner_id (domain_id)),
                  AB.WA.account_fullName (AB.WA.domain_owner_id (domain_id))
                 );
}
;

-------------------------------------------------------------------------------
--
create procedure AB.WA.dav_content (
  in uri varchar,
  in auth_uid varchar := null,
  in auth_pwd varchar := null)
{
  declare cont varchar;
  declare hp any;

  declare exit handler for sqlstate '*'
  {
    --dbg_obj_print (__SQL_STATE, __SQL_MESSAGE);
    return null;
  };

  declare N integer;
  declare oldUri, newUri, reqHdr, resHdr varchar;

  newUri := replace (uri, ' ', '%20');
  reqHdr := null;
  if (isnull (auth_uid) or isnull (auth_pwd))
  AB.WA.account_access (auth_uid, auth_pwd);
  reqHdr := sprintf ('Authorization: Basic %s', encode_base64(auth_uid || ':' || auth_pwd));

_again:
  N := N + 1;
  oldUri := newUri;
  commit work;
  cont := http_get (newUri, resHdr, 'GET', reqHdr);
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

  return (cont);
}
;

-------------------------------------------------------------------------------
--
create procedure AB.WA.http_error (
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

-----------------------------------------------------------------------------
--
create procedure AB.WA.xml_set(
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
    XMLAppendChildren(aEntity, xtree_doc(sprintf ('<entry ID="%s">%s</entry>', id, AB.WA.xml2string(AB.WA.utf2wide(value)))));
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
create procedure AB.WA.string2nntp (
  in S varchar)
{
  S := replace (S, '.', '_');
  S := replace (S, '@', '_');
  return sprintf ('%U', S);
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
  in S varchar)
{
  declare N integer;
  declare retValue varchar;

  retValue := '';
  for (N := 0; N < length(S); N := N + 1)
  {
    if (S[N] <= 31)
    {
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
create procedure AB.WA.wide2utf (
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
create procedure AB.WA.isVector (
  inout aVector any)
{
  if (isarray (aVector) and not isstring (aVector))
    return 1;

  return 0;
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
  for (N := 0; N < length(aVector); N := N + 1)
  {
    if ((minLength = 0) or (length(aVector[N]) >= minLength))
    {
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
    if (aIndex = N)
    {
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
create procedure AB.WA.vector_reverse(
  in aVector any)
{
  declare aResult any;
  declare N integer;

  aResult := vector();
  for (N := length(aVector)-1; N >= 0; N := N - 1)
  {
    aResult := vector_concat (aResult, vector(aVector[N]));
  }
  return aResult;
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
  for (N := 0; N < length(aVector); N := N + 1)
  {
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
create procedure AB.WA.pop (
  inout aVector any)
{
  declare N integer;
  declare retValue, V any;

  retValue := null;

  V := vector();
  for (N := 0; N < length(aVector); N := N + 1)
  {
    retValue := aVector[N];
    if (N <> length(aVector)-1)
      V := vector_concat (V, vector (retValue));
  }
  aVector := V;

  return retValue;
}
;

-------------------------------------------------------------------------------
--
create procedure AB.WA.push (
  inout aVector any,
  in aValue any)
{
  aVector := vector_concat (aVector, vector (aValue));
  return aVector;
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
create procedure AB.WA.dictionary2rs(
  inout aDictionary any)
{
  declare N integer;
  declare tmp, c0, c1 varchar;
  declare V any;

  V := dict_to_vector(aDictionary, 1);
  result_names(c0, c1);
  for (N := 0; N < length (V); N := N + 2)
  {
    tmp := V[N+1];
    if (__tag (tmp) = 193)
      tmp := serialize (tmp);
    tmp := cast (tmp as varchar);
    result(V[N], tmp);
  }
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
  for (N := 0; N < length(aVector); N := N + 1)
  {
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
  {
    if (params[N] = name)
    {
      params[N+1] := value;
      goto _end;
    }
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
  if (node_type = 'r')
  {
    if (node_id = 2)
      return vector('Shared Contacts By', AB.WA.make_node ('u', -1), AB.WA.make_path(path, 'u', -1));
  }

  declare retValue any;
  retValue := vector ();

  if ((node_type = 'u') and (node_id = -1))
  {
    for (select distinct U_ID, U_NAME from AB..GRANTS_VIEW where id = user_id order by 2) do
    {
      retValue := vector_concat(retValue, vector(U_NAME, AB.WA.make_node ('u', U_ID), AB.WA.make_path(path, 'u', U_ID)));
    }
  }
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
  {
    if (exists (select 1 from AB..GRANTS_VIEW where id = user_id))
      return 1;
  }

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
  in node_id any) returns varchar
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
  return dateadd('minute', - timezone(curdatetime_tz()), curdatetime_tz());
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
  if (is_empty_or_null (pUser))
    return pDate;
  tz := cast (coalesce(USER_GET_OPTION(pUser, 'TIMEZONE'), timezone(curdatetime_tz())/60) as integer) * 60;
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
  if (timezone (dt) is null)
    dt := dt_set_tz (dt, 0);
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
  S := substring (S, 1, coalesce (strstr (S, '<>'), length (S)));
  S := substring (S, 1, coalesce (strstr (S, '\nin'), length (S)));

  return S;
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

  valueClass := coalesce(get_keyword('class', params), get_keyword('type', params));
  valueType := coalesce(get_keyword('type', params), get_keyword('class', params));
  valueName := get_keyword('name', params, 'Field');
  valueMessage := get_keyword('message', params, '');
  tmp := get_keyword('canEmpty', params);
  if (isnull (tmp))
  {
    if (not isnull (get_keyword ('minValue', params)))
    {
      tmp := 0;
    } else if (get_keyword('minLength', params, 0) <> 0) {
      tmp := 0;
    }
  }
  if (not isnull (tmp) and (tmp = 0) and is_empty_or_null (value))
  {
    signal('EMPTY', '');
  } else if (is_empty_or_null(value)) {
    return value;
  }

  value := AB.WA.validate2 (valueClass, cast (value as varchar));
  if (valueType = 'integer')
  {
    tmp := get_keyword('minValue', params);
    if ((not isnull (tmp)) and (value < tmp))
      signal('MIN', cast (tmp as varchar));

    tmp := get_keyword('maxValue', params);
    if (not isnull (tmp) and (value > tmp))
      signal('MAX', cast (tmp as varchar));
  }
  else if (valueType = 'float')
  {
    tmp := get_keyword('minValue', params);
    if (not isnull (tmp) and (value < tmp))
      signal('MIN', cast (tmp as varchar));

    tmp := get_keyword('maxValue', params);
    if (not isnull (tmp) and (value > tmp))
      signal('MAX', cast (tmp as varchar));
  }
  else if (valueType = 'varchar')
  {
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
    if (isnull (regexp_match('^(ht|f)tp(s?)\:\/\/[0-9a-zA-Z]([-.\w]*[0-9a-zA-Z])*(:(0-9)*)*(\/?)([a-zA-Z0-9\-\.\?\,\'\/\\\+&amp;%\$#_=:~]*)?\$', propertyValue)))
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
  in S varchar,
  in V any := null,
  in debug any := null)
{
  declare st, msg, meta, rows any;

  if (not isnull (V))
    V := vector ();

  st := '00000';
  exec (S, st, msg, V, vector ('use_cache', 1), meta, rows);
  if (not isnull (debug) and ('00000' <> st))
    dbg_obj_print ('', S, st, msg);
  if ('00000' = st)
    return rows;
  return vector ();
}
;

-------------------------------------------------------------------------------
--
create procedure AB.WA.ab_graph_delete (
  in graph varchar)
{
  if (is_empty_or_null (graph))
    return;

  SPARQL clear graph ?:graph;
}
;

-------------------------------------------------------------------------------
--
create procedure AB.WA.ab_graph_create ()
{
  return 'http://local.virt/addressbook/' || cast (rnd (1000) as varchar);
}
;

-------------------------------------------------------------------------------
--
create procedure AB.WA.dashboard_rs(
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
                 from AB.WA.PERSONS
                where P_DOMAIN_ID = p0
                order by P_UPDATED desc
              ) x) do
  {
    result (P_ID, P_NAME, P_UPDATED);
  }
}
;

-------------------------------------------------------------------------------
--
create procedure AB.WA.dashboard_get(
  in domain_id integer)
{
  declare account_id integer;
  declare aStream any;

  account_id := AB.WA.domain_owner_id (domain_id);
  aStream := string_output ();
  http ('<ab-db>', aStream);
  for (select x.* from AB.WA.dashboard_rs(p0)(_id integer, _name varchar, _time datetime) x where p0 = domain_id) do
  {
    http ('<ab>', aStream);
    http (sprintf ('<dt>%s</dt>', date_iso8601 (coalesce (_time, now ()))), aStream);
    http (sprintf ('<title><![CDATA[%s]]></title>', _name), aStream);
    http (sprintf ('<link>%V</link>', SIOC..addressbook_contact_iri (domain_id, _id)), aStream);
    http (sprintf ('<from><![CDATA[%s]]></from>', AB.WA.account_fullName (account_id)), aStream);
    http (sprintf ('<uid>%s</uid>', AB.WA.account_name (account_id)), aStream);
    http ('</ab>', aStream);
  }
  http ('</ab-db>', aStream);
  return string_output_string (aStream);
}
;

-------------------------------------------------------------------------------
--
create procedure AB.WA.settings (
  inout domain_id integer)
{
  return coalesce ((select deserialize (blob_to_string (S_DATA)) from AB.WA.SETTINGS where S_DOMAIN_ID = domain_id), vector());
}
;

-------------------------------------------------------------------------------
--
create procedure AB.WA.settings_init (
  inout settings any)
{
  AB.WA.set_keyword ('chars', settings, cast (get_keyword ('chars', settings, '60') as integer));
  AB.WA.set_keyword ('rows', settings, cast (get_keyword ('rows', settings, '10') as integer));
  AB.WA.set_keyword ('tbLabels', settings, cast (get_keyword ('tbLabels', settings, '1') as integer));
  AB.WA.set_keyword ('atomVersion', settings, get_keyword ('atomVersion', settings, '1.0'));
  AB.WA.set_keyword ('conv', settings, cast (get_keyword ('conv', settings, '0') as integer));
  AB.WA.set_keyword ('conv_init', settings, cast (get_keyword ('conv_init', settings, '0') as integer));
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
  in category_id integer,
  in kind integer,
  in name varchar,
  in title varchar,
  in fName varchar,
  in mName varchar,
  in lName varchar,
  in fullName varchar,
  in gender varchar,
  in birthday datetime,
  in iri varchar,
  in foaf varchar,
  in photo varchar,
  in interests varchar,
  in relationships varchar,
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
  if (id = -1)
  {
    id := sequence_next ('AB.WA.contact_id');
    insert into AB.WA.PERSONS
      (
        P_ID,
        P_DOMAIN_ID,
        P_CATEGORY_ID,
        P_KIND,
        P_NAME,
        P_TITLE,
        P_FIRST_NAME,
        P_MIDDLE_NAME,
        P_LAST_NAME,
        P_FULL_NAME,
        P_GENDER,
        P_BIRTHDAY,
        P_IRI,
        P_FOAF,
        P_PHOTO,
        P_INTERESTS,
        P_RELATIONSHIPS,
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
        category_id,
        kind,
        name,
        title,
        fName,
        mName,
        lName,
        fullName,
        gender,
        birthday,
        iri,
        foaf,
        photo,
        interests,
        relationships,
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
       set P_CATEGORY_ID = category_id,
           P_KIND = kind,
           P_NAME = name,
           P_TITLE = title,
           P_FIRST_NAME = fName,
           P_MIDDLE_NAME = mName,
           P_LAST_NAME = lName,
           P_FULL_NAME = fullName,
           P_GENDER = gender,
           P_BIRTHDAY = birthday,
           P_IRI = iri,
           P_FOAF = foaf,
           P_PHOTO = photo,
           P_INTERESTS = interests,
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
  if ((id = -1) and (pName = 'P_NAME'))
  {
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
  if (id = -1)
    return id;

  if (pName = 'P_UID')
    update AB.WA.PERSONS set P_UID = pValue where P_ID = id;
  if (pName = 'P_CATEGORY_ID')
    update AB.WA.PERSONS set P_CATEGORY_ID = pValue where P_ID = id;
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
    update AB.WA.PERSONS set P_GENDER = lcase (pValue) where P_ID = id;
  if (pName = 'P_BIRTHDAY')
    update AB.WA.PERSONS set P_BIRTHDAY = pValue where P_ID = id;
  if (pName = 'P_FOAF')
    update AB.WA.PERSONS set P_FOAF = pValue where P_ID = id;
  if (pName = 'P_INTERESTS')
    update AB.WA.PERSONS set P_INTERESTS = pValue where P_ID = id;
  if (pName = 'P_RELATIONSHIPS')
    update AB.WA.PERSONS set P_RELATIONSHIPS = pValue where P_ID = id;

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
  if (pName = 'P_B_INDUSTRY')
    update AB.WA.PERSONS set P_B_INDUSTRY = pValue where P_ID = id;
  if (pName = 'P_B_ORGANIZATION')
    update AB.WA.PERSONS set P_B_ORGANIZATION = pValue where P_ID = id;
  if (pName = 'P_B_DEPARTMENT')
    update AB.WA.PERSONS set P_B_DEPARTMENT = pValue where P_ID = id;
  if (pName = 'P_B_JOB')
    update AB.WA.PERSONS set P_B_JOB = pValue where P_ID = id;
  if (pName = 'P_ACL')
    update AB.WA.PERSONS set P_ACL = pValue where P_ID = id;
  if (pName = 'P_CERTIFICATE')
    update AB.WA.PERSONS set P_CERTIFICATE = pValue where P_ID = id;

  update AB.WA.PERSONS set P_UPDATED = now () where P_ID = id;

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
  declare N, L varchar;
  declare S varchar;
  declare st, msg, meta, rows any;

  S := '';
  L := length (pFields);
  for (N := 0; N < L; N := N + 1)
  {
    S := S || ', ' || pFields[N] || ' = ?';
  }
  if (trim (tags) <> '')
  {
    S := S || ', P_TAGS = ?';
    pValues := vector_concat (pValues, vector (trim (tags)));
  }
  if (S <> '')
  {
    S := 'update AB.WA.PERSONS set P_UPDATED = now ()' || S || ' where P_ID = ' || cast (id as varchar);
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
  in tags varchar := null,
  in options any := null,
  in validation any := null,
  in progress_id any := null)
{
  declare L, N, M varchar;
  declare S varchar;
  declare tmp, V, F any;

  tmp := AB.WA.contact_validation (domain_id, pFields, pValues, options, validation, progress_id);
  if (not isnull (tmp))
  {
    if (length (pFields) = 0)
      return vector ();

    id := tmp;
  }
  if (isinteger (id) and (id = -1))
  {
    L := length (pFields);
    for (N := 0; N < L; N := N + 1)
    {
      if (pFields [N] = 'P_NAME')
      {
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
            pValues [N],
            now (),
            now ()
          );
      }
      }

  _exit:;
    if (isinteger (id) and (id = -1))
      return 0;

    V := vector ();
    F := vector ();
    for (N := 0; N < L; N := N + 1)
    {
      if ('P_NAME' <> pFields [N])
      {
        F := vector_concat (F, vector (pFields [N]));
        V := vector_concat (V, vector (pValues [N]));
      }
    }
    pFields := F;
    pValues := V;
  }
  if (isinteger (id))
    id := vector (id);

  for (N := 0; N < length (id); N := N + 1)
    AB.WA.contact_update3 (id[N], domain_id, pFields, pValues, tags);

  return id;
}
;

-------------------------------------------------------------------------------
--
create procedure AB.WA.contact_field (
  in id integer,
  in pName varchar)
{
  declare st, msg, meta, rows any;

  st := '00000';
  exec (sprintf ('select %s from AB.WA.PERSONS where P_ID = ?', pName), st, msg, vector (id), 0, meta, rows);
  if ('00000' = st)
    return rows[0][0];
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
  return row_count ();
}
;

-------------------------------------------------------------------------------
--
create procedure AB.WA.contact_validation (
  in domain_id integer,
  inout pFields any,
  inout pValues any,
  in options any := null,
  in validation any := null,
  in progress_id any := null)
{
  declare N, M varchar;
  declare S varchar;
  declare id, st, msg, meta, rows, F, V, T any;

  id := null;
  if (isnull (validation) or (length (validation) = 0))
    goto _exit;

  S := 'select P_ID from AB.WA.PERSONS where P_DOMAIN_ID = ?';
  V := vector (domain_id);
    for (N := 0; N < length (validation); N := N + 1)
    {
      M := AB.WA.vector_index (pFields, validation [N]);
      if (not isnull (M))
      {
        S := S || sprintf (' and coalesce(%s, '''') = coalesce(?, '''')', pFields[M]);
          V := vector_concat (V, vector (pValues [M]));
        }
      }
  if (length (V) = 1)
    goto _exit;

      st := '00000';
    exec (S, st, msg, V, vector ('use_cache', 1), meta, rows);
  if ((st <> '00000') or (length (rows) <> 1))
    goto _exit;

      declare validationMode varchar;

      id := vector ();
      for (N := 0; N < length (rows); N := N + 1)
      {
        id := vector_concat (id, vector (rows [N][0]));
      }
      validationMode := get_keyword ('validationMode', options);
      if (validationMode = 'ask')
      {
        declare pollValue, pollTime varchar;

	      registry_set ('addressbook_poll_' || progress_id, 'ask');
        registry_set ('addressbook_poll_time_' || progress_id, cast (msec_time() as varchar));
        registry_set ('addressbook_poll_data_' || progress_id, (select P_NAME from AB.WA.PERSONS where P_ID = id[0]));
	      while (1)
	      {
          delay(2);

          -- has answer?
          pollValue := registry_get ('addressbook_poll_' || progress_id);
          if (pollValue like 'answer:%')
          {
            validationMode := replace (pollValue, 'answer:', '');
    	      registry_remove ('addressbook_poll_' || progress_id);
            registry_remove ('addressbook_poll_time_' || progress_id);
            registry_remove ('addressbook_poll_data_' || progress_id);

            goto _break;
          }

          -- no client interaction
          -- stopped?
          pollTime := cast (registry_get ('addressbook_poll_time_' || progress_id) as integer);
          if (((msec_time() - pollTime) > 10000) or not AB.WA.import_check_progress_id (progress_id))
          {
    	      registry_remove ('addressbook_poll_' || progress_id);
            registry_remove ('addressbook_poll_time_' || progress_id);
            registry_remove ('addressbook_poll_data_' || progress_id);
	          registry_set ('addressbook_action_' || progress_id, 'stop');
            validationMode := 'skip';

            goto _break;
          }
	      }
	    _break:;
      }
        F := vector ();
      V := vector ();
      if (validationMode = 'skip')
      {
        ;
      }
      else if (validationMode = 'merge')
      {
        for (N := 0; N < length (pFields); N := N + 1)
        {
          if (not AB.WA.vector_contains (validation, pFields [N]))
          {
            F := vector_concat (F, vector (pFields [N]));
            V := vector_concat (V, vector (pValues [N]));
          }
        }
      }
      else if (validationMode = 'override')
        {
        for (N := 0; N < length (pFields); N := N + 1)
        {
          if (not AB.WA.vector_contains (validation, pFields[N]))
          {
            F := vector_concat (F, vector (pFields[N]));
            V := vector_concat (V, vector (pValues[N]));
        }
      }
        T := LDAP..contact_fields ();
        for (N := 0; N < length (T); N := N + 2)
        {
          if ((T[N] <> 'P_NAME') and not AB.WA.vector_contains (pFields, T[N]))
          {
            F := vector_concat (F, vector (T[N]));
            V := vector_concat (V, vector (null));
          }
        }
      }
      pFields := F;
      pValues := V;

_exit:;
  return id;
}
;

-------------------------------------------------------------------------------
--
create procedure AB.WA.contact_rights (
  in domain_id integer,
  in id integer,
  in account_rights varchar,
  in person_rights varchar)
{
  declare retValue varchar;

  retValue := '';
  if (exists (select 1 from AB.WA.PERSONS where P_ID = id and P_DOMAIN_ID = domain_id))
  {
    if (isnull (person_rights) or (account_rights < person_rights))
  retValue := AB.WA.acl_check (domain_id, id);

    if (retValue = '')
      retValue := account_rights;
  }
    return retValue;
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
create procedure AB.WA.contact_share (
  in account_id integer,
  in person_id integer,
  in grants varchar,
  in override integer)
{
  declare N, pos, id integer;
  declare name, V any;

  grants := replace(grants, ' ', '');
  grants := replace(grants, ',,', ',');
  grants := trim(grants, ',', '');
  grants := grants || ',';
  for (select U_ID, U_NAME from AB.WA.GRANTS, DB.DBA.SYS_USERS where G_GRANTER_ID = account_id and G_PERSON_ID = person_id and G_GRANTEE_ID = U_ID) do
  {
    name := U_NAME;
    id := U_ID;
    pos := strstr (grants, name || ',');
    if (isnull (pos))
    {
      if (override)
        delete from AB.WA.GRANTS where G_GRANTER_ID = account_id and G_GRANTEE_ID = id and G_PERSON_ID = person_id;
    } else {
      grants := replace (grants, name || ',', '');
    }
  }
  V := split_and_decode (trim (grants, ','), 0, '\0\0,');
  for (N := 0; N < length (V); N := N + 1)
  {
    id := (select U_ID from SYS_USERS where U_NAME = V[N]);
    if (not isnull(id))
      insert into AB.WA.GRANTS (G_GRANTER_ID, G_GRANTEE_ID, G_PERSON_ID)
        values(account_id, id, person_id);
  }
}
;

-------------------------------------------------------------------------------
--
create procedure AB.WA.contact_certificate (
  in account_id integer,
  in mail varchar)
{
  return (select TOP 1 P_CERTIFICATE
            from AB.WA.PERSONS
           where P_MAIL = mail
             and length (P_CERTIFICATE) <> 0
             and P_DOMAIN_ID in (select WAI_ID
                                   from DB.DBA.WA_INSTANCE,
                                        DB.DBA.WA_MEMBER
                                  where WAM_USER = account_id
                                    and WAM_MEMBER_TYPE = 1
                                    and WAM_INST = WAI_NAME));
}
;

-------------------------------------------------------------------------------
--
create procedure AB.WA.value2str (
  in data any,
  in labels any,
  in defaults any)
{
  declare N, M integer;
  declare retValue varchar;

  retValue := '';
  for (N := 0; N < length (data); N := N + 1)
  {
    for (M := 0; M < length (labels); M := M + 1)
    {
      retValue := retValue || get_keyword (labels[M], data[N], defaults[M]) || ';';
    }
    retValue := retValue || '\n';
  }
  return retValue;
}
;

--------------------------------------------------------------------------------
--
create procedure AB.WA.import_CardDAV_check (
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

  -- check CardDAV
  _reqHeader := 'Accept: text/xml\r\nContent-Type: text/xml; charset=utf-8';
  if (not is_empty_or_null (_user))
    _reqHeader := _reqHeader || sprintf ('\r\nAuthorization: Basic %s', encode_base64 (_user || ':' || _password));

  _page := http_client_ext (url=>_name, http_method=>'OPTIONS', http_headers=>_reqHeader, headers =>_resHeader, n_redirects=>15);
  if (not AB.WA.http_error (_resHeader, _silent))
    return 0;

  if (not (http_request_header (_resHeader, 'DAV') like '%addressbook%'))
    return 0;

  return 1;
}
;

-------------------------------------------------------------------------------
--
create procedure AB.WA.import_count (
  in type integer,
  in data any)
{
  -- vCard
  if (type = 0)
    return AB.WA.import_vcard_count (data);

  -- FOAF
  if (type = 1)
    return AB.WA.import_foaf_count (data);

  -- CSV
  if (type = 2)
    return AB.WA.import_csv_count (data);

  -- LDAP
  if (type = 3)
    return AB.WA.import_ldap_count (data);

  -- LinkedIn
  if (type = 4)
    return AB.WA.import_linkedin_count (data);

  -- CardDAV
  if (type = 5)
    return AB.WA.import_CardDAV_count (data);
}
;

-------------------------------------------------------------------------------
--
create procedure AB.WA.import_vcard_count (
  in content any)
{
  declare xmlData, items any;
  declare retValue integer;

  if (not isstring (content))
    content := cast (content as varchar);

  xmlData := DB.DBA.IMC_TO_XML (content);
  xmlData := xml_tree_doc (xmlData);
  items := xpath_eval ('/*', xmlData, 0);
  retValue := 0;
  foreach (any item in items) do
  {
    if (xpath_eval ('name(.)', item) = 'IMC-VCARD')
      retValue := retValue + 1;
  }
  return retValue;
}
;

-------------------------------------------------------------------------------
--
create procedure AB.WA.import_foaf_count (
  in domain_id integer,
  in content any)
{
  return 10;
}
;

-------------------------------------------------------------------------------
--
create procedure AB.WA.import_csv_count (
  in content any)
{
  declare N, nLength integer;
  declare retValue integer;

  retValue := 0;
  nLength := length (content);
  for (N := 1; N < nLength; N := N + 1)
  {
    retValue := retValue + 1;
  }
  return retValue;
}
;

-------------------------------------------------------------------------------
--
create procedure AB.WA.import_ldap_count (
  in content any)
{
  declare N, nLength integer;
  declare retValue integer;

  retValue := 0;
  nLength := length (content);
  for (N := 0; N < nLength; N := N + 2)
  {
    if (content [N] = 'entry')
      retValue := retValue + 1;
  }
  return retValue;
}
;

-------------------------------------------------------------------------------
--
create procedure AB.WA.import_linkedin_count (
  in content any)
{
  declare items any;

  items := xml_tree_doc (content);
  items := xpath_eval('/connections/person', items, 0);

  return length (items);
}
;

-------------------------------------------------------------------------------
--
create procedure AB.WA.import_CardDav_count (
  in _name any,
  in _options any,
  in _silent integer := 0)
{
  declare _user, _password varchar;
  declare _page, _body, _resHeader, _reqHeader any;
  declare _xml, _items any;
  declare exit handler for sqlstate '*'
  {
    return 0;
  };

  _user := get_keyword ('user', _options);
  _password := get_keyword ('password', _options);

  -- check CardDAV
  _reqHeader := 'Accept: text/xml\r\nContent-Type: text/xml; charset=utf-8';
  if (not is_empty_or_null (_user))
    _reqHeader := _reqHeader || sprintf ('\r\nAuthorization: Basic %s', encode_base64 (_user || ':' || _password));

  _page := http_client_ext (url=>_name, http_method=>'OPTIONS', http_headers=>_reqHeader, headers =>_resHeader, n_redirects=>15);
  if (not AB.WA.http_error (_resHeader, _silent))
    return 0;

  if (not (http_request_header (_resHeader, 'DAV') like '%addressbook%'))
    return 0;

  _body := null;
  _reqHeader := _reqHeader || '\r\nDepth: 1';
  _page := http_client_ext (url=>_name, http_method=>'PROPFIND', http_headers=>_reqHeader, headers =>_resHeader, body=>_body, n_redirects=>15);
  if (not AB.WA.http_error (_resHeader, _silent))
    return 0;

  _xml := xml_tree_doc (xml_expand_refs (xml_tree (_page)));
  _items := xpath_eval ('[xmlns:D="DAV:" xmlns="urn:ietf:params:xml:ns:carddav:"] /D:multistatus/D:response/D:href/text()', _xml, 0);

  return length (_items)-1;
}
;

-------------------------------------------------------------------------------
--
create procedure AB.WA.import_check_progress_id (
  in progress_id any)
{
  if (is_empty_or_null (progress_id))
    return 1;

  if  (cast (registry_get ('addressbook_action_' || progress_id) as varchar) = 'stop')
    return 0;

  return 1;
}
;

-------------------------------------------------------------------------------
--
create procedure AB.WA.import_inc_progress_id (
  in progress_id any)
{
  declare tmp any;

  if (is_empty_or_null (progress_id))
    return;

  if  (cast (registry_get ('addressbook_action_' || progress_id) as varchar) = 'stop')
    return;

  tmp := cast (registry_get('addressbook_index_' || progress_id) as integer) + 1;
  registry_set ('addressbook_index_' || progress_id, cast (tmp as varchar));
}
;

-------------------------------------------------------------------------------
--
create procedure AB.WA.import (
  in domain_id integer,
  in type integer,
  in data any,
  in options any := null,
  in validation any := null,
  in progress_id varchar := null)
{
  if (type = 0)
  {
    -- vCard
    AB.WA.import_vcard (domain_id, data, options, validation, progress_id);
  }
  else if (type = 1)
  {
    -- FOAF
    AB.WA.import_foaf (domain_id, data, options, validation, progress_id);
  }
  else if (type = 2)
  {
    -- CSV
    AB.WA.import_csv (domain_id, data, options, validation, progress_id);
  }
  else if (type = 3)
  {
    -- LDAP
    AB.WA.import_ldap (domain_id, data, options, validation, progress_id);
  }
  else if (type = 4)
  {
    -- LinkedIn
    AB.WA.import_linkedin (domain_id, data, options, validation, progress_id);
  }
  else if (type = 5)
  {
    -- CardDAV
    AB.WA.import_CardDAV (domain_id, data, options, validation, progress_id);
  }
}
;

-------------------------------------------------------------------------------
--
create procedure AB.WA.import_vcard_decode (
  in S varchar)
{
  return replace (S, '\\:', ':');
}
;

-------------------------------------------------------------------------------
--
create procedure AB.WA.import_vcard (
  in domain_id integer,
  in content any,
  in options any := null,
  in validation any := null,
  in progress_id varchar := null)
{
  declare M, N, pos, mLength, mGroupLength, id integer;
  declare tmp, T, uid, data, pFields, pValues, pField any;
  declare xmlData, xmlItems, xmlSubItems, itemSubName, itemPrefix, itemName, Meta, MetaGroup any;
  declare mode, externalUID, updatedBefore, vcardImported any;

  vcardImported := vector ();

  if (isnull (options))
    options := vector ();

  mode := get_keyword ('mode', options, 0);
  if (mode = 2)
    return AB.WA.import_vcard2 (domain_id, data, options, validation);

  updatedBefore := get_keyword ('updatedBefore', options);
  externalUID := get_keyword ('externalUID', options);

  Meta := vector
    (
      'P_UID',            vector ('UID/val'),
      'P_NAME',           vector ('NICKNAME/val', 'N/fld[1]', 'N/fld[2]', 'N/val'),
      'P_TITLE',          vector ('N/fld[4]'),
      'P_FIRST_NAME',     vector ('N/fld[2]'),
      'P_MIDDLE_NAME',    vector ('N/fld[3]'),
      'P_LAST_NAME',      vector ('N/fld[1]', 'N/val'),
      'P_FULL_NAME',      vector ('FN/val'),
      'P_BIRTHDAY',       vector ('BDAY/val'),
      'P_GENDER',         vector ('X-GENDER/val'),
      'P_B_ORGANIZATION', vector ('ORG/val', 'ORG/fld[1]'),
      'P_B_JOB',          vector ('TITLE/val'),
      'P_ICQ',            vector ('X-ICQ/val'),
      'P_MSN',            vector ('X-MSN/val'),
      'P_AIM',            vector ('X-AIM/val'),
      'P_YAHOO',          vector ('X-YAHOO/val'),
      'P_SKYPE',          vector ('X-SKYPE/val'),
      'P_MAIL',           vector ('EMAIL[TYPE="PREF"]/val'),
      'P_WEB',            vector ('URL[TYPE="PREF"]/val'),
      'P_H_ADDRESS1',     vector ('ADR[TYPE="HOME" or TYPE!="WORK"]/fld[3]'),
      'P_H_ADDRESS2',     vector ('ADR[TYPE="HOME" or TYPE!="WORK"]/fld[2]'),
      'P_H_CITY',         vector ('ADR[TYPE="HOME" or TYPE!="WORK"]/fld[4]'),
      'P_H_CODE',         vector ('ADR[TYPE="HOME" or TYPE!="WORK"]/fld[6]'),
      'P_H_STATE',        vector ('ADR[TYPE="HOME" or TYPE!="WORK"]/fld[5]'),
      'P_H_COUNTRY',      vector ('ADR[TYPE="HOME" or TYPE!="WORK"]/fld[7]'),
      'P_H_PHONE',        vector ('TEL[TYPE="HOME" or TYPE!="WORK"]/val'),
      'P_H_FAX',          vector ('TEL[TYPE="HOME" and TYPE="FAX"]/val'),
      'P_H_MOBILE',       vector ('TEL[TYPE="MOBILE"]/val'),
      'P_H_MAIL',         vector ('EMAIL[TYPE="HOME"]/val'),
      'P_H_WEB',          vector ('URL[TYPE="HOME"]/val'),
      'P_H_ADDRESS1',     vector ('ADR[TYPE="WORK"]/fld[3]'),
      'P_H_ADDRESS2',     vector ('ADR[TYPE="WORK"]/fld[2]'),
      'P_H_CITY',         vector ('ADR[TYPE="WORK"]/fld[4]'),
      'P_H_CODE',         vector ('ADR[TYPE="WORK"]/fld[6]'),
      'P_H_STATE',        vector ('ADR[TYPE="WORK"]/fld[5]'),
      'P_H_COUNTRY',      vector ('ADR[TYPE="WORK"]/fld[7]'),
      'P_B_PHONE',        vector ('TEL[TYPE="WORK"]/val'),
      'P_B_FAX',          vector ('TEL[TYPE="WORK" and TYPE="FAX"]/val'),
      'P_B_MOBILE',       vector ('TEL[TYPE="WORK" and TYPE="MOBILE"]/val'),
      'P_B_MAIL',         vector ('EMAIL[TYPE="WORK"]/val'),
      'P_B_WEB',          vector ('URL[TYPE="WORK"]/val')
    );
  mLength := length (Meta);
  MetaGroup := vector
    (
      'P_IRI',            vector ('URL/val', 'X-ABLabel[val="PROFILE"]/val')
    );
  mGroupLength := length (MetaGroup);

  -- using DAV parser
  if (not isstring (content))
    content := cast (content as varchar);
    xmlData := DB.DBA.IMC_TO_XML (content);

  xmlData := xml_tree_doc (xmlData);
  xmlItems := xpath_eval ('/*', xmlData, 0);
  foreach (any xmlItem in xmlItems) do
  {
      if (not AB.WA.import_check_progress_id (progress_id))
        return;

    if (xpath_eval ('name(.)', xmlItem) <> 'IMC-VCARD')
      goto _skip;

    xmlItem := xml_cut (xmlItem);

      id := -1;
      uid := null;
      pFields := vector ();
      pValues := vector ();
    for (N := 0; N < mLength; N := N + 2)
      {
        pField := Meta [N];
      for (M := 0; M < length (Meta[N+1]); M := M + 1)
        {
        T := serialize_to_UTF8_xml (xpath_eval ('/IMC-VCARD/' || Meta[N+1][M] || '/text()', xmlItem, 1));
          if (not is_empty_or_null (T))
          {
          if (pField = 'P_UID')
              uid := T;

          if (not AB.WA.vector_contains (pFields, pField))
                    {
            pFields := vector_concat (pFields, vector (pField));
            pValues := vector_concat (pValues, vector (AB.WA.import_vcard_decode (T)));
                    }
                  }
                }
              }
    xmlSubItems := xpath_eval ('/IMC-VCARD/*', xmlItem, 0);
    foreach (any xmlSubItem in xmlSubItems) do
    {
      itemSubName := cast (xpath_eval ('name(.)', xmlSubItem) as varchar);
      pos := strchr (itemSubName, '.');
      if (pos is not NULL)
              {
        itemName := subseq (itemSubName, pos+1);
        itemPrefix := subseq (itemSubName, 0, pos);
        for (N := 0; N < mGroupLength; N := N + 2)
        {
          if (strstr (MetaGroup[N+1][0], itemName) = 0)
          {
            T := xpath_eval ('/IMC-VCARD/' || itemPrefix || '.' || MetaGroup[N+1][1] || '/text()', xmlItem, 1);
            if (not isnull (T))
            {
              pField := MetaGroup[N];
              T := serialize_to_UTF8_xml (xpath_eval ('./val/text()', xmlSubItem));
              if (not AB.WA.vector_contains (pFields, pField))
              {
                pFields := vector_concat (pFields, vector (pField));
                pValues := vector_concat (pValues, vector (AB.WA.import_vcard_decode (T)));
            }
              goto _1;
          }
        }
      }
      _1:;
      }
    }
      if (isnull (uid) and not isnull (externalUID))
      {
        N := strchr (externalUID, '_');
        if (isnull (N))
          N := 0;

        tmp := subseq (externalUID, N, length (externalUID));
        id := coalesce ((select P_ID from AB.WA.PERSONS where P_DOMAIN_ID = domain_id and P_UID = tmp), -1);
        if (id <> -1)
          uid := tmp;
        }
      id := coalesce ((select P_ID from AB.WA.PERSONS where P_DOMAIN_ID = domain_id and P_UID = uid), -1);
      if ((id <> -1) and not isnull (updatedBefore))
      {
        if (exists (select 1 from AB.WA.PERSONS where P_ID = id and P_UPDATED >= updatedBefore))
          goto _skip;
      }

      id := AB.WA.import_contact_update (id, domain_id, pFields, pValues, options, validation, progress_id);
      vcardImported := vector_concat (vcardImported, id);

    _skip:;
      AB.WA.import_inc_progress_id (progress_id);
    }
  return vcardImported;
}
;

-------------------------------------------------------------------------------
--
create procedure AB.WA.import_rdf_data (
  in domain_id integer,
  in data  any,
  in options varchar,
  in validation any := null,
  in progress_id any := null)
  {
  declare M integer;
  declare meta, tags, pValue, pField, pFields, pValues any;

  meta := vector
    (
      'iri',                     'P_IRI',
      'personalProfileDocument', 'P_FOAF',
      'nick',                    'P_NAME',
      'name',                    'P_FULL_NAME',
      'type',                    'P_KIND',
      'firstNname',              'P_FIRST_NAME',
      'family_name',             'P_LAST_NAME',
      'dateOfBirth',             'P_BIRTHDAY',
      'mbox',                    'P_MAIL',
      'workplaceHomepage',       'P_WEB',
      'icqChatID',               'P_ICQ',
      'msnChatID',               'P_MSN',
      'aimChatID',               'P_AIM',
      'yahooChatID',             'P_YAHOO',
      'title',                   'P_TITLE',
      'phone',                   'P_H_PHONE',
      'homepage',                'P_H_WEB',
      'workplaceHomepage',       'P_B_WEB',
      'lat',                     'P_H_LAT',
      'lng',                     'P_H_LNG',
      'depiction',               'P_PHOTO'
    );

  pFields := vector ();
  pValues := vector ();
  for (M := 0; M < length (meta); M := M + 2)
            {
    pValue := get_keyword (meta[M], data);
    if (not isnull(pValue))
              {
      pField := meta[M+1];
      pFields := vector_concat (pFields, vector (pField));
      pValues := vector_concat (pValues, vector (pValue));
            }
          }
  pValue := get_keyword ('keywords', data);
  if (not isnull(pValue))
          {
    tags := AB.WA.tags_join (get_keyword ('tags', options, ''), pValue);
    options := AB.WA.set_keyword ('tags', options, tags);
          }
  pValue := get_keyword ('interest', data);
  if (not isnull(pValue))
          {
    pValue := AB.WA.value2str(pValue, vector('value', 'label'), vector('', ''));
    pFields := vector_concat (pFields, vector ('P_INTERESTS'));
    pValues := vector_concat (pValues, vector (pValue));
          }
  pValue := get_keyword ('knows', data);
  if (not isnull(pValue))
          {
    pValue := AB.WA.value2str(pValue, vector('x', 'value'), vector('foaf:knows', ''));
    pFields := vector_concat (pFields, vector ('P_RELATIONSHIPS'));
    pValues := vector_concat (pValues, vector (pValue));
          }
  AB.WA.import_contact_update (-1, domain_id, pFields, pValues, options, validation, progress_id);
          }
;

-------------------------------------------------------------------------------
--
create procedure AB.WA.import_vcard2 (
  in domain_id integer,
  in content any,
  in options any := null,
  in validation any := null,
  in progress_id varchar := null)
          {
  declare items, data any;
  declare S, st, msg, meta any;
  declare contentType, contentIRI any;

  if (isnull (options))
    options := vector ();

  contentType := get_keyword ('contentType', options, 0);
  contentIRI := get_keyword ('contentIRI', options, AB.WA.ab_graph_create ());

  declare exit handler for sqlstate '*'
          {
    AB.WA.ab_graph_delete (contentIRI);
    signal ('TEST', 'Bad import source!<>');
  };

  if (contentType > 0)
  {
    S := sprintf ('sparql define get:soft "soft" define get:uri "%s" select * from <%s> where { ?s ?p ?o }', content, contentIRI);
    st := '00000';
        commit work;
    exec (S, st, msg, vector (), vector ('use_cache', 1), meta, Items);
    if ('00000' <> st)
      signal (st, msg);
      }
  else if (contentType = 0)
  {
    DB.DBA.RDF_LOAD_RDFXML (content, contentIRI, contentIRI);
    }

  S := sprintf ('sparql
                 define input:storage ""
                 prefix vcard: <http://www.w3.org/2001/vcard-rdf/3.0#>
                 select ?x
                   from <%s>
                  where { ?x a vcard:vCard . }', contentIRI);
  items := AB.WA.ab_sparql (S);
  foreach (any item in items) do
  {
    if (not AB.WA.import_check_progress_id (progress_id))
      return;

    data := AB.WA.import_vcard2_array (item[0], contentIRI);
    AB.WA.import_rdf_data (domain_id, data, options, validation, progress_id);
    AB.WA.import_inc_progress_id (progress_id);
  }

_delete:;
  AB.WA.ab_graph_delete (contentIRI);
}
;

-------------------------------------------------------------------------------
--
create procedure AB.WA.import_vcard2_array (
  in iri varchar,
  in graph varchar)
{
  declare N integer;
  declare S varchar;
  declare V, S, st, msg, rows, meta any;

  S := sprintf (' sparql
                  define input:storage ""
                  prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
                  prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#>
                  prefix foaf: <http://xmlns.com/foaf/0.1/>
                  prefix geo: <http://www.w3.org/2003/01/geo/wgs84_pos#>
                  prefix vcard: <http://www.w3.org/2001/vcard-rdf/3.0#>
                  prefix bio: <http://vocab.org/bio/0.1/>
                  select ?nick ?firstName ?family_name ?birthday ?title ?keywords
                    from <%s>
                   where {
                          ?iri a vcard:vCard .
                          optional { ?iri vcard:NICKNAME ?nick. }.
                          optional { ?iri vcard:N ?N.
                                     ?N vcard:Given ?firstName.
                                     ?N vcard:Family ?family_name.
                                     ?N vcard:Prefix ?title.
                                   }.
                          optional { ?iri vcard:BDAY ?birthday} .
                          optional { ?iri vcard:CATEGORIES ?keywords} .
                          filter (?iri = iri(?::0)).
                         }', graph);
  V := vector ();
  st := '00000';
  commit work;
  exec (S, st, msg, vector (iri), vector ('use_cache', 1), meta, rows);
  if (st = '00000')
  {
    meta := ODS.ODS_API.simplifyMeta(meta);
    foreach (any row in rows) do
  {
      N := 0;
      while (N < length(meta))
      {
        if (meta[N] like '%_array')
    {
          ODS.ODS_API.appendPropertyArray (V, N, meta[N], row[N], meta, row);
        } else {
          ODS.ODS_API.appendProperty (V, meta[N], row[N]);
    }
        N := N + 1;
  }
    }
  }
  return V;
}
;

-------------------------------------------------------------------------------
--
create procedure AB.WA.import_foaf (
  inout domain_id integer,
  inout content any,
  in options any := null,
  in validation any := null,
  in progress_id varchar := null)
{
  declare S, T varchar;
  declare st, msg, meta, items, data any;
  declare contentType, contentIRI, contentItems, contentPings, contentDepth, contentLimit, contentFollow any;

  if (isnull (options))
    options := vector ();

  contentType := get_keyword ('contentType', options, 0);
  contentIRI := get_keyword ('contentIRI', options, AB.WA.ab_graph_create ());
  contentItems := get_keyword ('contentItems', options);
  contentPings := get_keyword ('contentPings', options);

  declare exit handler for sqlstate '*'
  {
    -- dbg_obj_print ('', __SQL_MESSAGE);
    AB.WA.ab_graph_delete (contentIRI);
    signal ('TEST', 'Bad import source!<>');    
  };

  if (contentType > 0)
  {
    contentDepth := get_keyword ('contentDepth', options, 0);
    contentLimit := get_keyword ('contentLimit', options, 100);
    contentFollow := get_keyword ('contentFollow', options, 'foaf:knows');
  
    T := case when contentDepth then sprintf ('  define input:grab-depth %d\n  define input:grab-limit %d\n  define input:grab-seealso <%s>\n  define input:grab-destination <%s>\n', contentDepth, contentLimit, contentFollow, contentIRI) else '' end;
    S := sprintf ('SPARQL\n%s  define get:soft "soft"\n  define get:uri "%s"\nSELECT *\n  FROM <%s>\n WHERE { ?s ?p ?o }', T, content, contentIRI);
    st := '00000';
    commit work;
    exec (S, st, msg, vector (), 0, meta, Items);
    if ('00000' <> st)
      signal (st, msg);
  }
  else if (contentType = 0)
  {
    DB.DBA.RDF_LOAD_RDFXML (content, contentIRI, contentIRI);
  }

  if (isnull (contentItems))
  {
    Items := AB.WA.ab_sparql (sprintf (' SPARQL
                                         define input:storage ""
                                         PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
                                         PREFIX foaf: <http://xmlns.com/foaf/0.1/>
                                         SELECT ?x
                                           FROM <%s>
                                          WHERE {
                                                  {?x a foaf:Person .}
                                                  UNION
                                                  {?x a foaf:Organization .}
                                                }', contentIRI));
  } else {
    Items := contentItems;
  }
  foreach (any item in items) do
      {
    if (not AB.WA.import_check_progress_id (progress_id))
      return;

    data := ODS.ODS_API.extractFOAFDataArray (item[0], contentIRI);
    AB.WA.import_rdf_data (domain_id, data, options, validation, progress_id);
    AB.WA.import_inc_progress_id (progress_id);
  }

_delete:;
  AB.WA.ab_graph_delete (contentIRI);
}
;

-------------------------------------------------------------------------------
--
create procedure AB.WA.import_foaf_content (
  inout content any,
  in options any := null)
{
  declare N, M integer;
  declare tmp, Items, Persons any;
  declare st, msg, meta any;
  declare S, T, personIRI varchar;
  declare contentType, contentIRI, contentDepth, contentLimit, contentFollow any;

  if (isnull (options))
    options := vector ();

  contentType := get_keyword ('contentType', options, 0);
  contentIRI := get_keyword ('contentIRI', options, AB.WA.ab_graph_create ());

  declare exit handler for sqlstate '*'
  {
    Persons := vector ();
    AB.WA.ab_graph_delete (contentIRI);
    goto _exit;
  };

  Persons := vector ();
  AB.WA.ab_graph_delete (contentIRI);

  -- store in QUAD Store
  if (contentType > 0)
  {
    contentDepth := get_keyword ('contentDepth', options, 0);
    contentLimit := get_keyword ('contentLimit', options, 100);
    contentFollow := get_keyword ('contentFollow', options, 'foaf:knows');

    T := case when contentDepth then sprintf ('  define input:grab-depth %d\n  define input:grab-limit %d\n  define input:grab-seealso <%s>\n  define input:grab-destination <%s>\n', contentDepth, contentLimit, contentFollow, contentIRI) else '' end;
    S := sprintf ('sparql \n%s  define get:soft "soft"\n  define get:uri "%s"\nSELECT *\n  FROM <%s>\n WHERE { ?s ?p ?o }', T, content, contentIRI);
    st := '00000';
    exec (S, st, msg, vector (), 0, meta, Items);
    if (st <> '00000')
      signal (st, msg);
  }
  else
  {
    DB.DBA.RDF_LOAD_RDFXML (content, contentIRI, contentIRI);
  }
  Items := AB.WA.ab_sparql (sprintf (' sparql
                                       define input:storage ""
                                       prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
                                       prefix foaf: <http://xmlns.com/foaf/0.1/>
                                       select ?person, ?nick, ?name, ?mbox
                                         from <%s>
                                        where {
                                                [] a foaf:PersonalProfileDocument ;
                                                   foaf:primaryTopic ?person .
                                                optional { ?person foaf:nick ?nick } .
                                                optional { ?person foaf:name ?name } .
                                                optional { ?person foaf:mbox ?mbox } .
                                              }', contentIRI));
  if (length (Items))
  {
    personIRI := Items[0][0];
    Persons := vector_concat (Persons, vector (vector (1, personIRI,  coalesce (Items[0][2], Items[0][1]), replace (Items[0][3], 'mailto:', ''))));
    S := sprintf (' sparql
                    define input:storage ""
                    prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
                    prefix foaf: <http://xmlns.com/foaf/0.1/>
                    select ?person, ?nick, ?name, ?mbox
                      from <%s>
                     where {
                             <%s> foaf:knows ?person .
                             {?person a foaf:Person .}
                             UNION
                             {?person a foaf:Organization .}
                             optional { ?person foaf:nick ?nick } .
                             optional { ?person foaf:name ?name } .
                             optional { ?person foaf:mbox ?mbox } .
                           }', contentIRI, personIRI);
  } else {
    S := sprintf (' SPARQL
                    define input:storage ""
                    prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
                    prefix foaf: <http://xmlns.com/foaf/0.1/>
                    select ?person, ?nick, ?name, ?mbox
                      from <%s>
                     where {
                             {?person a foaf:Person .}
                             UNION
                             {?person a foaf:Organization .}
                             optional { ?person foaf:nick ?nick } .
                             optional { ?person foaf:name ?name } .
                             optional { ?person foaf:mbox ?mbox } .
                           }', contentIRI);
  }
  Items := AB.WA.ab_sparql (S);
  foreach (any Item in Items) do
    {
    if (isnull (coalesce (Item[2], Item[1])))
      goto _skip;

      for (M := 0; M < length (Persons); M := M + 1)
      {
      if (Persons[M][1] = Item[0])
          goto _skip;
      }
    Persons := vector_concat (Persons, vector (vector (0, Item[0], coalesce (Item[2], Item[1]), replace (Item[3], 'mailto:', ''))));

    _skip:;
    }
_exit:;
  return Persons;
}
;

-------------------------------------------------------------------------------
--
create procedure AB.WA.import_csv (
  in domain_id integer,
  in content any,
  in options any := null,
  in validation any := null,
  in progress_id varchar := null)
{
  declare N, M, nLength, mLength integer;
  declare tmp, data, pFields, pValues any;
  declare maps any;

  if (isnull (options))
    options := vector ();

  maps := get_keyword ('maps', options, vector());

  nLength := length (content);
  for (N := 1; N < nLength; N := N + 1)
  {
    if (not AB.WA.import_check_progress_id (progress_id))
      return;

    pFields := vector ();
    pValues := vector ();
    data := split_and_decode (content [N], 0, '\0\0,');
      mLength := length (data);
      for (M := 0; M < mLength; M := M + 1)
      {
             tmp := get_keyword (cast (M as varchar), maps, '');
            if (tmp <> '')
            {
                 pFields := vector_concat (pFields, vector (tmp));
        pValues := vector_concat (pValues, vector (trim (data[M], '"')));
         }
      }
    AB.WA.import_contact_update (-1, domain_id, pFields, pValues, options, validation, progress_id);
    AB.WA.import_inc_progress_id (progress_id);
  }
}
;

-------------------------------------------------------------------------------
--
create procedure AB.WA.import_ldap (
  in domain_id integer,
  in content any,
  in options any := null,
  in validation any := null,
  in progress_id varchar := null)
{
  declare N, M, nLength, mLength, id integer;
  declare data, pFields, pValues any;
  declare maps any;

  if (isnull (options))
    options := vector ();

  maps := get_keyword ('maps', options, vector());

  nLength := length (content);
  for (N := 0; N < nLength; N := N + 2)
  {
    if (content [N] = 'entry')
    {
      if (not AB.WA.import_check_progress_id (progress_id))
        return;

      data := content [N+1];
      mLength := length (data);
        pFields := vector ();
        pValues := vector ();
      for (M := 0; M < mLength; M := M + 2)
      {
        if (get_keyword (data[M], maps, '') <> '')
        {
            pFields := vector_concat (pFields, vector (get_keyword (data[M], maps)));
            pValues := vector_concat (pValues, vector (case when isstring (data[M+1]) then data[M+1] else data[M+1][0] end));
          }
        }
      AB.WA.import_contact_update (-1, domain_id, pFields, pValues, options, validation, progress_id);
      AB.WA.import_inc_progress_id (progress_id);
    }
  }
}
;

-------------------------------------------------------------------------------
--
create procedure AB.WA.import_linkedin (
  in domain_id integer,
  in content any,
  in options any := null,
  in validation any := null,
  in progress_id varchar := null)
{
  declare N, M, id integer;
  declare items, pFields, pValues any;
  declare tmp, meta, mLength any;

  if (isnull (options))
    options := vector ();

  Meta := vector
    (
      'P_NAME',           'string(./first-name)',
      'P_FIRST_NAME',     'string(./first-name)',
      'P_LAST_NAME',      'string(./last-name)',
      'P_H_COUNTRY',      'string(./location/name)',
      'P_B_INDUSTRY',     'string(./industry)'
    );
  mLength := length (Meta);

  items := xml_tree_doc (content);
  items := xpath_eval('/connections/person', items, 0);
  foreach (any item in items) do
  {
    if (not AB.WA.import_check_progress_id (progress_id))
      return;

    pFields := vector ();
    pValues := vector ();
    for (M := 0; M < mLength; M := M + 2)
    {
      tmp := serialize_to_UTF8_xml (xpath_eval (Meta[M+1], item, 1));
      if (not is_empty_or_null (tmp))
      {
        pFields := vector_concat (pFields, vector (Meta[M]));
        pValues := vector_concat (pValues, vector (tmp));
      }
    }
    AB.WA.import_contact_update (-1, domain_id, pFields, pValues, options, validation, progress_id);

    AB.WA.import_inc_progress_id (progress_id);
  }
}
;

--------------------------------------------------------------------------------
--
create procedure AB.WA.import_CardDAV (
  in domain_id integer,
  in name any,
  in options any := null,
  in validation any := null,
  in progress_id varchar := null)
{
  declare _user, _password any;
  declare _page, _body, _bodyTemplate, _resHeader, _reqHeader any;
  declare _xml, _xml2, _items, _data any;

  _user := get_keyword ('user', options);
  _password := get_keyword ('password', options);
  _bodyTemplate :=
   '<?xml version="1.0" encoding="utf-8" ?>
    <C:addressbook-multiget xmlns:D="DAV:" xmlns:C="urn:ietf:params:xml:ns:carddav">
      <D:prop>
        <D:getetag/>
        <C:address-data/>
      </D:prop>
      <D:href>%s</D:href>
    </C:addressbook-multiget>';

  -- check CardDAV
  _reqHeader := 'Accept: text/xml\r\nContent-Type: text/xml; charset=utf-8';
  if (not is_empty_or_null (_user))
    _reqHeader := _reqHeader || sprintf ('\r\nAuthorization: Basic %s', encode_base64 (_user || ':' || _password));

  _page := http_client_ext (url=>name, http_method=>'OPTIONS', http_headers=>_reqHeader, headers =>_resHeader, n_redirects=>15);
  AB.WA.http_error (_resHeader);
  if (not (http_request_header (_resHeader, 'DAV') like '%addressbook%'))
    signal ('AB001', 'Bad import/subscription source!<>');

  _body := null;
  _reqHeader := _reqHeader || '\r\nDepth: 1';
  _page := http_client_ext (url=>name, http_method=>'PROPFIND', http_headers=>_reqHeader, headers =>_resHeader, body=>_body, n_redirects=>15);
  AB.WA.http_error (_resHeader);
  {
    declare exit handler for sqlstate '*'
    {
      signal ('AB001', 'Bad import/subscription source!<>');
    };
    _xml := xml_tree_doc (xml_expand_refs (xml_tree (_page)));
		_items := xpath_eval ('[xmlns:D="DAV:" xmlns="urn:ietf:params:xml:ns:carddav:"] /D:multistatus/D:response/D:href/text()', _xml, 0);
		foreach (any _item in _items) do
		{
      if (not AB.WA.import_check_progress_id (progress_id))
        return;

      _body := sprintf (_bodyTemplate, cast (_item as varchar));

      commit work;
      _page := http_client_ext (url=>name, http_method=>'REPORT', http_headers=>_reqHeader, headers =>_resHeader, body=>_body, n_redirects=>15);
      AB.WA.http_error (_resHeader);
      _xml2 := xml_tree_doc (xml_expand_refs (xml_tree (_page)));
		  if (not isnull (xpath_eval ('[xmlns:D="DAV:" xmlns="urn:ietf:params:xml:ns:carddav:"] /D:multistatus/D:response/D:href/text()', _xml2, 1)))
		  {
		    _data := cast (xpath_eval ('[xmlns:D="DAV:" xmlns="urn:ietf:params:xml:ns:carddav:"] /D:multistatus/D:response/D:propstat/D:prop/address-data/text()', _xml2, 1) as varchar);
		    AB.WA.import_vcard (domain_id, _data, options, validation, progress_id);
      }
	  }
  }
  return 1;
}
;

-------------------------------------------------------------------------------
--
create procedure AB.WA.import_contact_update (
  in id integer,
  in domain_id integer,
  in pFields any,
  in pValues any,
  in options any,
  in validation any,
  in progress_id varchar)
{
  declare N, noRelations inteher;
  declare tmp, tags, name, firstName, lastName, fullName, iri varchar;

  name := '';
  firstName := '';
  lastName := '';
  fullName := '';
  iri := '';
  noRelations := 1;
  for (N := 0; N < length (pFields); N := N + 1)
  {
    if (pFields[N] = 'P_NAME')
    {
      name := pValues[N];
    }
    else if (pFields[N] = 'P_FIRST_NAME')
    {
      firstName := pValues[N];
    }
    else if (pFields[N] = 'P_LAST_NAME')
    {
      lastName := pValues[N];
    }
    else if (pFields[N] = 'P_FULL_NAME')
    {
      fullName := pValues[N];
    }
    else if (pFields[N] = 'P_IRI')
    {
      iri := pValues[N];
    }
    else if (pFields[N] = 'P_BIRTHDAY')
    {
      {
        declare continue handler for sqlstate '*'
        {
          pValues[N] := '';
        };
        pValues[N] := AB.WA.dt_reformat (pValues[N], 'Y-M-D');
      }
    }
    else if (pFields[N] = 'P_KIND')
    {
      pValues[N] := case when (pValues[N] = 'http://xmlns.com/foaf/0.1/Organization') then 1 else 0 end;
    }
    else if (pFields[N] = 'P_MAIL')
    {
      pValues[N] := replace (pValues[N], 'mailto:', '');
    }
    else if (pFields[N] = 'P_PHONE')
    {
      pValues[N] := replace (pValues[N], 'tel:', '');
    }
    else if (pFields[N] = 'P_TITLE')
    {
      pValues[N] := ODS.ODS_API.appendPropertyTitle (pValues[N]);
    }
    else if (pFields[N] = 'P_RELATIONSHIPS')
    {
      pValues[N] := pValues[N] || '\nfoaf:knows;' || AB.WA.account_sioc_url (domain_id);
      noRelations := 0;
    }
  }
  if (noRelations)
  {
    pFields := vector_concat (pFields, vector ('P_RELATIONSHIPS'));
    pValues := vector_concat (pValues, vector ('foaf:knows;' || AB.WA.account_sioc_url (domain_id)));
  }
  if (fullName = '')
  {
    fullName := trim (firstName || ' ' || lastName);
    pFields := vector_concat (pFields, vector ('P_FULL_NAME'));
    pValues := vector_concat (pValues, vector (fullName));
  }
  if (name = '')
  {
    pFields := vector_concat (pFields, vector ('P_NAME'));
    pValues := vector_concat (pValues, vector (fullName));
  }
  tags := get_keyword ('tags', options, '');

      commit work;
      connection_set ('__addressbook_import', '1');
  id := AB.WA.contact_update4 (id, domain_id, pFields, pValues, tags, options, validation, progress_id);
  if (length (id))
  {
    tmp := get_keyword ('grants', options, '');
    if (tmp <> '')
      AB.WA.contact_share (AB.WA.domain_owner_id (domain_id), id[0], tmp, 1);

    tmp := get_keyword ('acls', options, '');
    if (tmp <> '')
      AB.WA.contact_update2 (id[0], domain_id, 'P_ACL', tmp);

    tmp := get_keyword ('contentPings', options, vector());
    if (AB.WA.vector_contains (tmp, iri))
      SEMPING.DBA.CLI_PING (AB.WA.account_sioc_url (domain_id), iri);

  }
  connection_set ('__addressbook_import', '0');

  return id;
}
;

----------------------------------------------------------------------
--
create procedure AB.WA.export_vcard_encode (
  in S varchar)
{
  return replace (S, ':', '\\:');
}
;

----------------------------------------------------------------------
--
create procedure AB.WA.export_vcard_line (
  in property varchar,
  in value any,
  inout sStream any)
{
  if (not is_empty_or_null (value))
  {
    http (sprintf ('%s:%s\r\n', property, cast (value as varchar)), sStream);
  }
}
;

----------------------------------------------------------------------
--
create procedure AB.WA.export_vcard_group (
  in prefix varchar,
  in property varchar,
  in value any,
  in label varchar,
  in labelValue any,
  inout sStream any)
{
  if (not is_empty_or_null (value))
  {
    http (sprintf ('%s:%s\r\n', prefix || '.' || property, AB.WA.export_vcard_encode (cast (value as varchar))), sStream);
    http (sprintf ('%s:%s\r\n', prefix || '.' || label, cast (labelValue as varchar)), sStream);
  }
}
;

-------------------------------------------------------------------------------
--
create procedure AB.WA.export_vcard (
  in domain_id integer,
  in entries any := null,
  in options any := null)
{
  declare S varchar;
  declare oTagsInclude, oTagsExclude any;
  declare sStream any;

  oTagsInclude := null;
  oTagsExclude := null;
  if (not isnull (options))
  {
    oTagsInclude := get_keyword ('tagsInclude', options);
    oTagsExclude := get_keyword ('tagsExclude', options);
  }
  sStream := string_output();
  for (select * from AB.WA.PERSONS where P_DOMAIN_ID = domain_id  and (entries is null or AB.WA.vector_contains (entries, P_ID))) do
  {
    if (AB.WA.tags_exchangeTest (P_TAGS, oTagsInclude, oTagsExclude))
  {
	  http ('BEGIN:VCARD\r\n', sStream);
      http ('VERSION:3.0\r\n', sStream);

      AB.WA.export_vcard_line ('REV', AB.WA.dt_iso8601 (P_UPDATED), sStream);

	  -- personal
      AB.WA.export_vcard_line ('UID', P_UID, sStream);
      AB.WA.export_vcard_line ('NICKNAME', P_NAME, sStream);
      AB.WA.export_vcard_line ('FN', P_FULL_NAME, sStream);

    -- Home
	  S := coalesce (P_LAST_NAME, '');
	  S := S || ';' || coalesce (P_FIRST_NAME, '');
	  S := S || ';' || coalesce (P_MIDDLE_NAME, '');
	  S := S || ';' || coalesce (P_TITLE, '');
	  if (S <> ';;;')
  	  {
        AB.WA.export_vcard_line ('N', S, sStream);
      }
      AB.WA.export_vcard_line ('BDAY', AB.WA.dt_format (P_BIRTHDAY, 'Y-M-D'), sStream);
      AB.WA.export_vcard_line ('X-GENDER', initcap (P_GENDER), sStream);

	  -- mail
      AB.WA.export_vcard_line ('EMAIL;TYPE=PREF;TYPE=INTERNET', P_MAIL, sStream);
	  -- web
      AB.WA.export_vcard_line ('URL', P_WEB, sStream);
      AB.WA.export_vcard_line ('URL;TYPE=HOME', P_H_WEB, sStream);
      AB.WA.export_vcard_line ('URL;TYPE=WORK', P_B_WEB, sStream);
    -- Home
	  S := ';';
	  S := S || ''  || coalesce (P_H_ADDRESS1, '');
	  S := S || ';' || coalesce (P_H_ADDRESS2, '');
	  S := S || ';' || coalesce (P_H_CITY, '');
	  S := S || ';' || coalesce (P_H_STATE, '');
	  S := S || ';' || coalesce (P_H_CODE, '');
	  S := S || ';' || coalesce (P_H_COUNTRY, '');
	  if (S <> ';;;;;;')
  	  {
  	    AB.WA.export_vcard_line ('ADR;TYPE=HOME', S, sStream);
  	  }
      AB.WA.export_vcard_line ('TS', P_H_TZONE, sStream);
      AB.WA.export_vcard_line ('TEL;TYPE=HOME', P_H_PHONE, sStream);
      AB.WA.export_vcard_line ('TEL;TYPE=HOME;TYPE=CELL', P_H_MOBILE, sStream);

    -- Business
	  S := ';';
	  S := S || ''  || coalesce (P_B_ADDRESS1, '');
	  S := S || ';' || coalesce (P_B_ADDRESS2, '');
	  S := S || ';' || coalesce (P_B_CITY, '');
	  S := S || ';' || coalesce (P_B_STATE, '');
	  S := S || ';' || coalesce (P_B_CODE, '');
	  S := S || ';' || coalesce (P_B_COUNTRY, '');
	  if (S <> ';;;;;;')
  	  {
    	  AB.WA.export_vcard_line ('ADR;TYPE=WORK', S, sStream);
    	}
      AB.WA.export_vcard_line ('TEL;TYPE=WORK', P_B_PHONE, sStream);
      AB.WA.export_vcard_line ('TEL;TYPE=WORK;TYPE=CELL', P_B_MOBILE, sStream);

      AB.WA.export_vcard_line ('ORG', P_B_ORGANIZATION, sStream);
      AB.WA.export_vcard_line ('TITLE', P_B_JOB, sStream);

      AB.WA.export_vcard_line ('X-ICQ',   P_ICQ, sStream);
      AB.WA.export_vcard_line ('X-MSN',   P_MSN, sStream);
      AB.WA.export_vcard_line ('X-AIM',   P_AIM, sStream);
      AB.WA.export_vcard_line ('X-YAHOO', P_YAHOO, sStream);
      AB.WA.export_vcard_line ('X-SKYPE', P_SKYPE, sStream);

      AB.WA.export_vcard_group ('item1', 'URL', P_IRI, 'X-ABLabel', 'PROFILE', sStream);

	  http ('END:VCARD\r\n', sStream);
	}
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
         '"Industry",' ||
         '"Company",' ||
         '"Job Title",' ||
         '"Tags"\r\n';
}
;

-------------------------------------------------------------------------------
--
create procedure AB.WA.export_csv (
  in domain_id integer,
  in entries any := null)
{
  declare S varchar;

  S := '';
  for (select * from AB.WA.PERSONS where P_DOMAIN_ID = domain_id  and (entries is null or AB.WA.vector_contains (entries, P_ID))) do
  {
    S := S ||
         sprintf
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
  in domain_id integer,
  in entries any := null)
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
            optional { ?person foaf:nick ?nick } .
            optional { ?person foaf:name ?name } .
            optional { ?person foaf:firstName ?firstName } .
            optional { ?person foaf:family_name ?family_name } .
            optional { ?person foaf:gender ?gender } .
            optional { ?person foaf:birthday ?birthday } .
            optional { ?person foaf:mbox ?mbox } .
            optional { ?person foaf:mbox_sha1sum ?mbox_sha1sum } .
            optional { ?person foaf:icqChatID ?icqChatID } .
            optional { ?person foaf:msnChatID ?msnChatID } .
            optional { ?person foaf:aimChatID ?aimChatID } .
            optional { ?person foaf:yahooChatID ?yahooChatID } .
            optional { ?person foaf:phone ?phone } .
            optional { ?person foaf:based_near ?based_near .
	                     ?based_near ?based_near_predicate ?based_near_subject .
	                   } .
            optional { ?person foaf:workplaceHomepage ?workplaceHomepage } .
            optional { ?org foaf:homepage ?workplaceHomepage .
	                     ?org a foaf:Organization ;
	                          dc:title ?orgtit .
	                   } .
            optional { ?person foaf:homepage ?homepage } .
            optional { ?person vcard:ADR ?adr .
	                     optional { ?adr vcard:Country ?country }.
		                   optional { ?adr vcard:Region ?state } .
		                   optional { ?adr vcard:Locality ?city } .
		                   optional { ?adr vcard:Pcode ?pcode  } .
		                   optional { ?adr vcard:Street ?street } .
		                   optional { ?adr vcard:Extadd ?extadd } .
		                 }
            optional { ?person bio:olb ?bio } .
            optional { ?person bio:event ?event.
                       ?event a bio:Birth ; dc:date ?bdate
                     }.
            optional { ?person foaf:knows ?knows .
	                     ?knows rdfs:seeAlso ?knows_seeAlso .
	                     ?knows foaf:nick ?knows_nick .
                     } .
	        }
	      }';

	S := sprintf (S, SIOC..get_graph ());
  T := '';
	if (not isnull (entries))
	{
	  foreach (any id in entries) do
	  {
	    if (T = '')
	    {
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

-----------------------------------------------------------------------------------------
--
create procedure AB.WA.uid ()
{
  return sprintf ('%s@%s', uuid (), sys_stat ('st_host_name'));
}
;

--------------------------------------------------------------------------------
--
create procedure AB.WA.exchange_exec (
  in _id integer,
  in _mode integer := 0,
  in _exMode integer := null)
{
  declare retValue any;

  declare exit handler for SQLSTATE '*'
  {
    update AB.WA.EXCHANGE
       set EX_EXEC_LOG = __SQL_STATE || ' ' || AB.WA.test_clear (__SQL_MESSAGE)
     where EX_ID = _id;
    commit work;

    if (_mode)
      resignal;
  };

  retValue := AB.WA.exchange_exec_internal (_id, _exMode);

  update AB.WA.EXCHANGE
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
create procedure AB.WA.exchange_entry_update (
  in _domain_id integer)
{
  for (select EX_ID as _id from AB.WA.EXCHANGE where EX_DOMAIN_ID = _domain_id and EX_TYPE = 0 and EX_UPDATE_TYPE = 1) do
  {
    if (connection_get ('__addressbook_import') = '1')
  {
      update AB.WA.EXCHANGE
         set EX_UPDATE_SUBTYPE = 1
       where EX_ID = _id;
    } else {
      AB.WA.exchange_exec (_id);
    }
  }
}
;

--------------------------------------------------------------------------------
--
create procedure AB.WA.exchange_exec_internal (
  in _id integer,
  in _exMode integer := null)
{
  for (select EX_DOMAIN_ID as _domain_id, EX_TYPE as _direction, deserialize (EX_OPTIONS) as _options from AB.WA.EXCHANGE where EX_ID = _id) do
  {
    declare _type, _name, _pName, _user, _password, _mode, _tags, _tagsInclude, _tagsExclude any;
    declare _content any;

    _type := get_keyword ('type', _options);
    _name := get_keyword ('name', _options);
    _user := get_keyword ('user', _options);
    _password := get_keyword ('password', _options);
    _mode := cast (get_keyword ('mode', _options) as integer);
    _tags := get_keyword ('tags', _options);
    _tagsInclude := get_keyword ('tagsInclude', _options);
    _tagsExclude := get_keyword ('tagsExclude', _options);

    -- publish
    if (_direction = 0)
    {
      _content := AB.WA.export_vcard (_domain_id, null, _options);
      if (_type = 1)
      {
        declare retValue, permissions any;
        {
          declare exit handler for SQLSTATE '*'
          {
            signal ('AB002', 'The export/publication did not pass successfully. Please verify the path and parameters values!<>');
          };
          permissions := AB.WA.dav_permissions (_name, _user, _password);
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
          retValue := DB.DBA.DAV_RES_UPLOAD (_name, _content, 'text/text/x-vCard', permissions, _user, null, _user, _password);
          if (DB.DBA.DAV_HIDE_ERROR (retValue) is null)
          {
            signal ('AB001', 'WebDAV: ' || DB.DBA.DAV_PERROR (retValue) || '.<>');
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
            signal ('AB002', 'Connection Error in HTTP Client!<>');
          };
          retContent := http_get (_name, resHeader, 'PUT', reqHeader, _content);
          if (not (length (resHeader) > 0 and (resHeader[0] like 'HTTP/1._ 2__ %' or  resHeader[0] like 'HTTP/1._ 3__ %')))
          {
            signal ('AB002', 'The export/publication did not pass successfully. Please verify the path and parameters values!<>');
          }
        }
      }
    }
    -- subscribe
    else if (_direction = 1)
    {
      if (_type = 3)
        return AB.WA.exchange_CardDAV (_id);

      if (_type = 1)
        _name := AB.WA.host_url () || _name;

      _content := AB.WA.dav_content (_name, _user, _password);
      if (isnull(_content))
        signal ('AB001', 'Bad import/subscription source!<>');

      AB.WA.import_vcard (_domain_id, _content, _options);
    }
    -- syncml
    else if (_direction = 2)
    {
      declare data any;
      declare N, _in, _out, _rlog_res_id integer;
      declare _path, _pathID varchar;

      _in := 0;
      _out := 0;
      if (not isnull (_exMode))
      {
        _mode := _exMode;
      }
      if ((_mode >= 0) and AB.WA.dav_check_authenticate (_name, _user, _password, '1__'))
      {
      data := AB.WA.exec ('select distinct RLOG_RES_ID from DB.DBA.SYNC_RPLOG where RLOG_RES_COL = ? and DMLTYPE <> \'D\'', vector (DB.DBA.DAV_SEARCH_ID (_name, 'C')));
      for (N := 0; N < length (data); N := N + 1)
      {
        _rlog_res_id := data[N][0];
         for (select RES_CONTENT, RES_NAME, RES_MOD_TIME from WS.WS.SYS_DAV_RES where RES_ID = _rlog_res_id) do
        {
          connection_set ('__sync_dav_upl', '1');
            _in := _in + AB.WA.syncml2entry_internal (_domain_id, _name, _user, _password, _tags, RES_CONTENT, RES_NAME, RES_MOD_TIME, 1);
          connection_set ('__sync_dav_upl', '0');
        }
      }
      }

      if ((_mode <= 0) and AB.WA.dav_check_authenticate (_name, _user, _password, '11_'))
      {
      for (select P_ID, P_UID, P_TAGS from AB.WA.PERSONS where P_DOMAIN_ID = _domain_id) do
      {
          if (not AB.WA.tags_exchangeTest (P_TAGS, _tagsInclude, _tagsExclude))
          goto _skip;

        _path := _name || P_UID;
        _pathID := DB.DBA.DAV_SEARCH_ID (_path, 'R');
        if (not (isinteger(_pathID) and (_pathID > 0)))
        {
          AB.WA.syncml_entry_update_internal (_domain_id, P_ID, _path, _user, _password, 'I');
            _out := _out + 1;
        }

      _skip:;
      }
    }
      return vector (_in, _out);
    }
  }
}
;

--------------------------------------------------------------------------------
--
create procedure AB.WA.exchange_CardDAV (
  in _id integer)
{
  for (select EX_DOMAIN_ID as _domain_id, EX_TYPE as _direction, deserialize (EX_OPTIONS) as _options from AB.WA.EXCHANGE where EX_ID = _id) do
  {
    declare _type, _name, _pName, _user, _password any;
    declare _page, _body, _bodyTemplate, _resHeader, _reqHeader any;
    declare _xml, _items, _data any;

    _type := get_keyword ('type', _options);
    if (_type <> 3)
       return 0;

    AB.WA.import_CardDAV (_domain_id, get_keyword ('name', _options), _options);
  }
  return 1;
}
;

--------------------------------------------------------------------------------
--
create procedure AB.WA.exchange_scheduler ()
{
  declare id, days, rc, err integer;
  declare bm any;

  declare _error integer;
  declare _bookmark any;
  declare _dt datetime;
  declare exID any;

  _dt := now ();
  declare cr static cursor for select EX_ID
                                 from AB.WA.EXCHANGE
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
      AB.WA.exchange_exec (exID, 1);
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
create procedure AB.WA.dav_check_authenticate (
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
create procedure AB.WA.dav_parent (
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
create procedure AB.WA.dav_permissions (
  in path varchar,
  in auth_name varchar := null,
  in auth_pwd varchar := null)
{
  declare uid, gid integer;
  declare permissions varchar;

  permissions := -1;
  permissions := DB.DBA.DAV_PROP_GET (path, ':virtpermissions', auth_name, auth_pwd);
  if (permissions < 0)
  {
    path := AB.WA.dav_parent (path);
    if (path <> AB.WA.dav_home (AB.WA.account_id (auth_name)))
      permissions := DB.DBA.DAV_PROP_GET (path, ':virtpermissions', auth_name, auth_pwd);
    if (permissions < 0)
      permissions := USER_GET_OPTION (auth_name, 'PERMISSIONS');
  }
  return permissions;
}
;

-----------------------------------------------------------------------------------------
--
create procedure AB.WA.syncml_check (
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
  if (DB.DBA.yac_syncml_type_get (syncmlPath) not in ('vcard_11', 'vcard_12'))
    return 0;
  return 1;
}
;

-----------------------------------------------------------------------------------------
--
create procedure AB.WA.syncml_entry_update (
  in _domain_id integer,
  in _entry_id integer,
  in _entry_gid varchar,
  in _entry_tags varchar,
  in _action varchar)
{
  declare _syncmlPath, _path, _user, _password, oTagsInclude, oTagsExclude any;

  if (connection_get ('__sync_dav_upl') = '1')
    return;

  for (select deserialize (EX_OPTIONS) as _options from AB.WA.EXCHANGE where EX_DOMAIN_ID = _domain_id and EX_TYPE = 2) do
  {
    _syncmlPath := get_keyword ('name', _options);
    if (not AB.WA.syncml_check (_syncmlPath))
      goto _skip;

    oTagsInclude := null;
    oTagsExclude := null;
    if (not isnull (_options))
    {
      oTagsInclude := get_keyword ('tagsInclude', _options);
      oTagsExclude := get_keyword ('tagsExclude', _options);
    }
    if (not AB.WA.tags_exchangeTest (_entry_tags, oTagsInclude, oTagsExclude))
      goto _skip;

    _user := get_keyword ('user', _options);
    _password := get_keyword ('password', _options);
    _path := _syncmlPath || _entry_gid;

    AB.WA.syncml_entry_update_internal (_domain_id, _entry_id, _path, _user, _password, _action);

  _skip:;
  }
}
;

-----------------------------------------------------------------------------------------
--
create procedure AB.WA.syncml_entry_update_internal (
  in _domain_id integer,
  in _entry_id integer,
  in _path varchar,
  in _user varchar,
  in _password varchar,
  in _action varchar)
{
  if ((_action = 'I') or (_action = 'U'))
  {
    declare _content, _permissions varchar;

    _content := AB.WA.entry2syncml (_entry_id);
    _permissions := USER_GET_OPTION (_user, 'PERMISSIONS');
    if (isnull (_permissions))
      _permissions := '110100000RR';

    connection_set ('__sync_dav_upl', '1');
    connection_set ('__sync_ods', '1');
    DB.DBA.DAV_RES_UPLOAD_STRSES_INT (_path, _content, 'text/x-vcard', _permissions, _user, _user, null, null, 0);
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
create procedure AB.WA.entry2syncml (
  in entry_id integer)
{
  declare S varchar;
  declare sStream any;

  sStream := string_output();
  for (select * from AB.WA.PERSONS where P_ID = entry_id) do
  {
    AB.WA.entry2syncml_line ('BEGIN', null, 'VCARD', sStream);
    AB.WA.entry2syncml_line ('VERSION', null, '2.1', sStream);
    AB.WA.entry2syncml_line ('REV', null, AB.WA.dt_iso8601 (P_UPDATED), sStream);

    -- personal
    AB.WA.entry2syncml_line ('UID', null, P_UID, sStream);
    AB.WA.entry2syncml_line ('NICKNAME', null, P_NAME, sStream);
    AB.WA.entry2syncml_line ('FN', null, P_FULL_NAME, sStream);

    -- Home
    S := coalesce (P_LAST_NAME, '');
    S := S || ';' || coalesce (P_FIRST_NAME, '');
    S := S || ';' || coalesce (P_MIDDLE_NAME, '');
    S := S || ';' || coalesce (P_TITLE, '');
    if (S <> ';;;')
    {
      AB.WA.entry2syncml_line ('N', null, S, sStream);
    }
    AB.WA.entry2syncml_line ('BDAY', null, AB.WA.dt_format (P_BIRTHDAY, 'Y-M-D'), sStream);

    -- mail
    AB.WA.entry2syncml_line ('EMAIL', vector ('TYPE', 'PREF', 'TYPE', 'INTERNET'), P_MAIL, sStream);
    -- web
    AB.WA.entry2syncml_line ('URL', null, P_WEB, sStream);
    AB.WA.entry2syncml_line ('URL', vector ('TYPE', 'HOME'), P_H_WEB, sStream);
    AB.WA.entry2syncml_line ('URL', vector ('TYPE', 'WORK'), P_B_WEB, sStream);
    -- Home
    S := ';';
    S := S || ''  || coalesce (P_H_ADDRESS1, '');
    S := S || ';' || coalesce (P_H_ADDRESS2, '');
    S := S || ';' || coalesce (P_H_CITY, '');
    S := S || ';' || coalesce (P_H_STATE, '');
    S := S || ';' || coalesce (P_H_CODE, '');
    S := S || ';' || coalesce (P_H_COUNTRY, '');
    if (S <> ';;;;;;')
    {
      AB.WA.entry2syncml_line ('ADR', vector ('TYPE', 'HOME'), S, sStream);
    }
    AB.WA.entry2syncml_line ('TS', null, P_H_TZONE, sStream);
    AB.WA.entry2syncml_line ('TEL', vector ('TYPE', 'HOME'), P_H_PHONE, sStream);
    AB.WA.entry2syncml_line ('TEL', vector ('TYPE', 'HOME', 'TYPE', 'CELL'), P_H_MOBILE, sStream);

    -- Business
    S := ';';
    S := S || ''  || coalesce (P_B_ADDRESS1, '');
    S := S || ';' || coalesce (P_B_ADDRESS2, '');
    S := S || ';' || coalesce (P_B_CITY, '');
    S := S || ';' || coalesce (P_B_STATE, '');
    S := S || ';' || coalesce (P_B_CODE, '');
    S := S || ';' || coalesce (P_B_COUNTRY, '');
    if (S <> ';;;;;;')
    {
      AB.WA.entry2syncml_line ('ADR', vector ('TYPE', 'WORK'), S, sStream);
    }
    AB.WA.entry2syncml_line ('TEL', vector ('TYPE', 'WORK'), P_B_PHONE, sStream);
    AB.WA.entry2syncml_line ('TEL', vector ('TYPE', 'WORK', 'TYPE', 'CELL'), P_B_MOBILE, sStream);

    AB.WA.entry2syncml_line ('ORG', null, P_B_ORGANIZATION, sStream);
    AB.WA.entry2syncml_line ('TITLE', null, P_B_JOB, sStream);

    AB.WA.entry2syncml_line ('END', null, 'VCARD', sStream);
  }

  return string_output_string (sStream);
}
;

----------------------------------------------------------------------
--
create procedure AB.WA.entry2syncml_line (
  in property varchar,
  in attrinutes any,
  in value any,
  inout sStream any)
{
  declare N imteger;
  declare S varchar;

  if (is_empty_or_null(value))
    return;

  S := '';
  if (not isnull(attrinutes))
  {
    for (N := 0; N < length(attrinutes); N := N + 2)
    {
      S := S || sprintf (' %s="%s"', attrinutes[N], attrinutes[N+1]);
    }
  }
  http (sprintf ('<%s%s><![CDATA[%s]]></%s>\r\n', property, S, cast (value as varchar), property), sStream);
}
;

----------------------------------------------------------------------
--
create procedure AB.WA.syncml2entry (
  in res_content varchar,
  in res_name varchar,
  in res_col varchar,
  in res_mod_time datetime := null)
{
  declare exit handler for sqlstate '*'
  {
    return;
  };

  declare _syncmlPath, _path, _user, _password, _tags varchar;

  for (select EX_DOMAIN_ID, deserialize (EX_OPTIONS) as _options from AB.WA.EXCHANGE where EX_TYPE = 2) do
  {
    _path := WS.WS.COL_PATH (res_col);
    _syncmlPath := get_keyword ('name', _options);
    if (_path = _syncmlPath)
    {
      _user := get_keyword ('user', _options);
      _password := get_keyword ('password', _options);
      _tags := get_keyword ('tags', _options);
      if (AB.WA.dav_check_authenticate (_path, _user, _password, '11_'))
        AB.WA.syncml2entry_internal (EX_DOMAIN_ID, _path, _user, _password, _tags, res_content, res_name, res_mod_time);
    }
  }
}
;

----------------------------------------------------------------------
--
create procedure AB.WA.syncml2entry_internal (
  in _domain_id integer,
  in _path varchar,
  in _user varchar,
  in _password varchar,
  in _tags varchar,
  in _res_content varchar,
  in _res_name varchar,
  in _res_mod_time datetime := null,
  in _internal integer := 0)
{
  declare exit handler for sqlstate '*'
  {
    return;
  };

  declare N, _pathID integer;
  declare _data, _uid  varchar;
  declare IDs any;

  if (not xslt_is_sheet ('http://local.virt/sync_out_xsl'))
    DB.DBA.sync_define_xsl ();

  _data := xtree_doc (_res_content, 0, '', 'utf-8');
  _data := xslt ('http://local.virt/sync_out_xsl', _data);
  _data := serialize_to_UTF8_xml (_data);
  _data := charset_recode (_data, 'UTF-8', '_WIDE_');

  if (not isinteger (_data))
  {
    IDs := AB.WA.import_vcard (_domain_id, _data, vector ('tags', _tags, 'updatedBefore', _res_mod_time, 'externalUID', _res_name));
    for (N := 0; N < length (IDs); N := N + 1)
    {
      _uid := (select P_UID from AB.WA.PERSONS where P_ID = IDs[N]);
      if (_uid <> _res_name)
      {
        _pathID := DB.DBA.DAV_SEARCH_ID (_path || _res_name, 'R');
        if (isinteger(_pathID) and (_pathID > 0))
        {
          if (_internal)
            set triggers off;

          update WS.WS.SYS_DAV_RES
             set RES_NAME = _uid,
                 RES_FULL_PATH = _path || _uid,
                 RES_CONTENT = AB.WA.entry2syncml (IDs[N])
           where RES_ID = _pathID;

          if (_internal)
            set triggers on;
        }
      }
    }
    return length (IDs);
  }
}
;

-------------------------------------------------------------------------------
--
create procedure AB.WA.search_sql (
  in domain_id integer,
  in account_id integer,
  in account_rights varchar,
  inout data varchar,
  in maxRows varchar := '')
{
  declare S, T, tmp, where2, delimiter2 varchar;

  where2 := ' \n ';
  delimiter2 := '\n and ';

  S := '';
  if (not is_empty_or_null(AB.WA.xml_get('MyContacts', data)))
  {
    S := 'select                         \n' ||
         '  p.P_ID          P_ID,        \n' ||
         '  p.P_DOMAIN_ID   P_DOMAIN_ID, \n' ||
         '  p.P_NAME        P_NAME,      \n' ||
         '  p.P_TAGS        P_TAGS,      \n' ||
         '  p.P_CREATED     P_CREATED,   \n' ||
         '  p.P_UPDATED     P_UPDATED    \n' ||
         'from                           \n' ||
         '  AB.WA.PERSONS p              \n' ||
         'where p.P_DOMAIN_ID = <DOMAIN_ID> <TEXT> <WHERE>';
  }
  if (not is_empty_or_null(AB.WA.xml_get('MySharedContacts', data)))
  {
    if (S <> '')
      S := S || '\n union \n';
    S := S ||
         'select                         \n' ||
         '  p.P_ID          P_ID,        \n' ||
         '  p.P_DOMAIN_ID   P_DOMAIN_ID, \n' ||
         '  p.P_NAME        P_NAME,      \n' ||
         '  p.P_TAGS        P_TAGS,      \n' ||
         '  p.P_CREATED     P_CREATED,   \n' ||
         '  p.P_UPDATED     P_UPDATED    \n' ||
         'from                           \n' ||
         '  AB.WA.PERSONS p,             \n' ||
         '  AB..GRANTS_PERSON_VIEW g     \n' ||
         'where p.P_ID = g.G_PERSON_ID   \n' ||
         '  and g.TO_ID = <ACCOUNT_ID> <TEXT> <WHERE>';
  }
  S := 'select <MAX> * from (' || S || ') x';
  if (account_rights = '')
  {
    if (is_https_ctx ())
    {
      S := S || ' where SIOC..addressbook_contact_iri (<DOMAIN_ID>, x.P_ID) in (select a.iri from AB.WA.acl_list (id)(iri varchar) a where a.id = <DOMAIN_ID>)';
    } else {
      S := S || ' where 1=0';
    }
  }

  T := '';
  tmp := AB.WA.xml_get('keywords', data);
  if (not is_empty_or_null(tmp))
  {
    T := FTI_MAKE_SEARCH_STRING(tmp);
  } else {
    tmp := AB.WA.xml_get('expression', data);
    if (not is_empty_or_null(tmp))
      T := tmp;
  }

  tmp := AB.WA.xml_get('tags', data);
  if (not is_empty_or_null(tmp))
  {
    if (T = '')
    {
      T := AB.WA.tags2search (tmp);
    } else {
      T := T || ' and ' || AB.WA.tags2search (tmp);
    }
  }
  if (T <> '')
    S := replace(S, '<TEXT>', sprintf('and contains(p.P_NAME, \'[__lang "x-ViDoc"] %s\') \n', T));

  tmp := AB.WA.xml_get('category', data);
  if (not is_empty_or_null(tmp))
  {
    where2 := ' and P_CATEGORY_ID = ' || tmp;
  }

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
create procedure AB.WA.category_insert (
  in domain_id integer,
  in name varchar)
{
  declare id integer;

  name := trim (name);
  if (is_empty_or_null (name))
    return null;

  id := (select C_ID from AB.WA.CATEGORIES where C_DOMAIN_ID = domain_id and C_NAME = name);
  if (not is_empty_or_null (id))
    return null;

  id := sequence_next ('AB.WA.category_id');
  insert into AB.WA.CATEGORIES (C_ID, C_DOMAIN_ID, C_NAME, C_CREATED, C_UPDATED)
    values (id, domain_id, name, now (), now ());

  return id;
}
;

-----------------------------------------------------------------------------------------
--
create procedure AB.WA.category_update (
  in domain_id integer,
  in name varchar)
{
  declare id integer;

  name := trim (name);
  if (is_empty_or_null (name))
    return null;

  id := (select C_ID from AB.WA.CATEGORIES where C_DOMAIN_ID = domain_id and C_NAME = name);
  if (is_empty_or_null (id))
  {
    id := sequence_next ('AB.WA.category_id');
    insert into AB.WA.CATEGORIES (C_ID, C_DOMAIN_ID, C_NAME, C_CREATED, C_UPDATED)
      values (id, domain_id, name, now (), now ());
  }
  return id;
}
;

-----------------------------------------------------------------------------------------
--
create procedure AB.WA.discussion_check ()
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
create procedure AB.WA.conversation_enable(
  in domain_id integer)
{
  return cast (get_keyword ('conv', AB.WA.settings(domain_id), '0') as integer);
}
;

-----------------------------------------------------------------------------------------
--
create procedure AB.WA.cm_root_node (
  in person_id varchar)
{
  declare root_id any;
  declare xt any;

  root_id := (select PC_ID from AB.WA.PERSON_COMMENTS where PC_PERSON_ID = person_id and PC_PARENT_ID is null);
  xt := (select xmlagg (xmlelement ('node', xmlattributes (PC_ID as id, PC_ID as name, PC_PERSON_ID as post)))
           from AB.WA.PERSON_COMMENTS
          where PC_PERSON_ID = person_id
            and PC_PARENT_ID = root_id
          order by PC_UPDATED);
  return xpath_eval ('//node', xt, 0);
}
;

-----------------------------------------------------------------------------------------
--
create procedure AB.WA.cm_child_node (
  in person_id varchar,
  inout node any)
{
  declare parent_id int;
  declare xt any;

  parent_id := xpath_eval ('number (@id)', node);
  person_id := xpath_eval ('@post', node);

  xt := (select xmlagg (xmlelement ('node', xmlattributes (PC_ID as id, PC_ID as name, PC_PERSON_ID as post)))
           from AB.WA.PERSON_COMMENTS
          where PC_PERSON_ID = person_id and PC_PARENT_ID = parent_id order by PC_UPDATED);
  return xpath_eval ('//node', xt, 0);
}
;

-----------------------------------------------------------------------------------------
--
create procedure AB.WA.make_rfc_id (
  in person_id integer,
  in comment_id integer := null)
{
  declare hashed, host any;

  hashed := md5 (uuid ());
  host := sys_stat ('st_host_name');
  if (isnull (comment_id))
    return sprintf ('<%d.%s@%s>', person_id, hashed, host);
  return sprintf ('<%d.%d.%s@%s>', person_id, comment_id, hashed, host);
}
;

-----------------------------------------------------------------------------------------
--
create procedure AB.WA.make_mail_subject (
  in txt any,
  in id varchar := null)
{
  declare enc any;

  enc := encode_base64 (AB.WA.wide2utf (txt));
  enc := replace (enc, '\r\n', '');
  txt := concat ('Subject: =?UTF-8?B?', enc, '?=\r\n');
  if (not isnull (id))
    txt := concat (txt, 'X-Virt-NewsID: ', uuid (), ';', id, '\r\n');
  return txt;
}
;

-----------------------------------------------------------------------------------------
--
create procedure AB.WA.make_post_rfc_header (
  in mid varchar,
  in refs varchar,
  in gid varchar,
  in title varchar,
  in rec datetime,
  in author_mail varchar)
{
  declare ses any;

  ses := string_output ();
  http (AB.WA.make_mail_subject (title), ses);
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
create procedure AB.WA.make_post_rfc_msg (
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
create procedure AB.WA.nntp_root (
  in domain_id integer,
  in person_id integer)
{
  declare owner_id integer;
  declare name, mail, title, comment any;

  owner_id := AB.WA.domain_owner_id (domain_id);
  name := AB.WA.account_fullName (owner_id);
  mail := AB.WA.account_mail (owner_id);

  select coalesce (P_NAME, ''), coalesce (P_FULL_NAME, '') into title, comment from AB.WA.PERSONS where P_ID = person_id;
  insert into AB.WA.PERSON_COMMENTS (PC_PARENT_ID, PC_DOMAIN_ID, PC_PERSON_ID, PC_TITLE, PC_COMMENT, PC_U_NAME, PC_U_MAIL, PC_CREATED, PC_UPDATED)
    values (null, domain_id, person_id, title, comment, name, mail, now (), now ());
}
;

-----------------------------------------------------------------------------------------
--
create procedure AB.WA.nntp_update_item (
  in domain_id integer,
  in person_id integer)
{
  declare grp, ngnext integer;
  declare nntpName, rfc_id varchar;

  nntpName := AB.WA.domain_nntp_name (domain_id);
  select NG_GROUP, NG_NEXT_NUM into grp, ngnext from DB..NEWS_GROUPS where NG_NAME = nntpName;
  select PC_RFC_ID into rfc_id from AB.WA.PERSON_COMMENTS where PC_DOMAIN_ID = domain_id and PC_PERSON_ID = person_id and PC_PARENT_ID is null;
  if (exists (select 1 from DB.DBA.NEWS_MULTI_MSG where NM_KEY_ID = rfc_id and NM_GROUP = grp))
    return;

  if (ngnext < 1)
    ngnext := 1;

  for (select PC_RFC_ID as rfc_id from AB.WA.PERSON_COMMENTS where PC_DOMAIN_ID = domain_id and PC_PERSON_ID = person_id) do
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
create procedure AB.WA.nntp_update (
  in domain_id integer,
  in oInstance varchar,
  in nInstance varchar,
  in oConversation integer := null,
  in nConversation integer := null)
{
  declare nntpGroup integer;
  declare nDescription varchar;

  if (isnull (oInstance))
    oInstance := AB.WA.domain_nntp_name (domain_id);

  if (isnull (nInstance))
    nInstance := AB.WA.domain_nntp_name (domain_id);

  nDescription := AB.WA.domain_description (domain_id);

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
      values (0, nInstance, nDescription, null, 1, now(), now(), 30, 0, 0, 0, 0, 0, 0, 120, 'ADDRESSBOOK');
  }
}
;

-----------------------------------------------------------------------------------------
--
create procedure AB.WA.nntp_fill (
  in domain_id integer)
{
  declare exit handler for SQLSTATE '*', not found {
    return;
  };

  declare grp, ngnext integer;
  declare nntpName varchar;

  for (select P_ID from AB.WA.PERSONS where P_DOMAIN_ID = domain_id) do
  {
    if (not exists (select 1 from AB.WA.PERSON_COMMENTS where PC_DOMAIN_ID = domain_id and PC_PERSON_ID = P_ID and PC_PARENT_ID is null))
      AB.WA.nntp_root (domain_id, P_ID);
  }
  nntpName := AB.WA.domain_nntp_name (domain_id);
  select NG_GROUP, NG_NEXT_NUM into grp, ngnext from DB..NEWS_GROUPS where NG_NAME = nntpName;
  if (ngnext < 1)
    ngnext := 1;

  for (select PC_RFC_ID as rfc_id from AB.WA.PERSON_COMMENTS where PC_DOMAIN_ID = domain_id) do
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
create procedure AB.WA.mail_address_split (
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
create procedure AB.WA.nntp_decode_subject (
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
create procedure AB.WA.nntp_process_parts (
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
      AB.WA.nntp_process_parts (parts[2][i], body, amime, result, any_part);

  return 0;
}
;

-----------------------------------------------------------------------------------------
--
DB.DBA.NNTP_NEWS_MSG_ADD (
'ADDRESSBOOK',
'select
   \'ADDRESSBOOK\',
   PC_RFC_ID,
   PC_RFC_REFERENCES,
   0,    -- NM_READ
   null,
   PC_UPDATED,
   0,    -- NM_STAT
   null, -- NM_TRY_POST
   0,    -- NM_DELETED
   AB.WA.make_post_rfc_msg (PC_RFC_HEADER, PC_COMMENT, 1), -- NM_HEAD
   AB.WA.make_post_rfc_msg (PC_RFC_HEADER, PC_COMMENT),
   PC_ID
 from AB.WA.PERSON_COMMENTS'
)
;

-----------------------------------------------------------------------------------------
--
create procedure DB.DBA.ADDRESSBOOK_NEWS_MSG_I (
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
    AB.WA.nntp_decode_subject (subject);

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

    AB.WA.nntp_process_parts (tree, N_NM_BODY, vector ('text/%'), res, 1);

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
  rfc_header := AB.WA.make_mail_subject (subject) || rfc_header || 'Content-Type: text/html; charset=UTF-8\r\n\r\n';

  rfc_references := N_NM_REF;

  if (not isnull (N_NM_REF))
  {
    declare exit handler for not found { signal ('CONV1', 'No such article.');};

    parent_id := null;
    refs := split_and_decode (N_NM_REF, 0, '\0\0 ');
    if (length (refs))
      N_NM_REF := refs[length (refs) - 1];

    select PC_ID, PC_DOMAIN_ID, PC_PERSON_ID, PC_TITLE
      into parent_id, domain_id, item_id, title
      from AB.WA.PERSON_COMMENTS
     where PC_RFC_ID = N_NM_REF;

    if (isnull (subject))
      subject := 'Re: '|| title;

    AB.WA.mail_address_split (author, name, mail);

    insert into AB.WA.PERSON_COMMENTS (PC_PARENT_ID, PC_DOMAIN_ID, PC_PERSON_ID, PC_TITLE, PC_COMMENT, PC_U_NAME, PC_U_MAIL, PC_UPDATED, PC_RFC_ID, PC_RFC_HEADER, PC_RFC_REFERENCES)
      values (parent_id, domain_id, item_id, subject, content, name, mail, N_NM_REC_DATE, N_NM_ID, rfc_header, rfc_references);
  }
}
;

-----------------------------------------------------------------------------------------
--
create procedure DB.DBA.ADDRESSBOOK_NEWS_MSG_U (
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
create procedure DB.DBA.ADDRESSBOOK_NEWS_MSG_D (
  inout O_NM_ID any)
{
  signal ('CONV3', 'Delete of a Person comment is not allowed');
}
;

-----------------------------------------------------------------------------------------
--
create procedure AB.WA.news_comment_get_mess_attachments (inout _data any, in get_uuparts integer)
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
create procedure AB.WA.news_comment_get_cn_type (in f_name varchar)
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
-- API Lib Procedures
--
-----------------------------------------------------------------------------------------
create procedure AB.WA.owner2contactMap ()
{
  return vector (
    'U_ID'           , 'P_ID'            ,
    'U_NAME'         , 'P_NAME'          ,
    'U_E_MAIL'       , 'P_MAIL'          ,
    'WAUI_TITLE'     , 'P_TITLE'         ,
    'WAUI_BIRTHDAY'  , 'P_BIRTHDAY'      ,
    'WAUI_GENDER'    , 'P_GENDER'        ,
    'WAUI_FIRST_NAME', 'P_FIRST_NAME'    ,
    'WAUI_LAST_NAME' , 'P_LAST_NAME'     ,
    'WAUI_GENDER'    , 'P_GENDER'        ,
    'WAUI_ICQ'       , 'P_ICQ'           ,
    'WAUI_SKYPE'     , 'P_SKYPE'         ,
    'WAUI_YAHOO'     , 'P_YAHOO'         ,
    'WAUI_AIM'       , 'P_AIM'           ,
    'WAUI_MSN'       , 'P_MSN'           ,
    'WAUI_HCOUNTRY'  , 'P_H_COUNTRY'     ,
    'WAUI_HSTATE'    , 'P_H_STATE'       ,
    'WAUI_HCITY'     , 'P_H_CITY'        ,
    'WAUI_HCODE'     , 'P_H_CODE'        ,
    'WAUI_HADDRESS1' , 'P_H_ADDRESS1'    ,
    'WAUI_HADDRESS2' , 'P_H_ADDRESS2'    ,
    'WAUI_HTZONE'    , 'P_H_TZONE'       ,
    'WAUI_LAT'       , 'P_H_LAT'         ,
    'WAUI_LNG'       , 'P_H_LNG'         ,
    'WAUI_HPHONE'    , 'P_H_PHONE'       ,
    'WAUI_HMOBILE'   , 'P_H_MOBILE'      ,
    'WAUI_BCOUNTRY'  , 'P_B_COUNTRY'     ,
    'WAUI_BSTATE'    , 'P_B_STATE'       ,
    'WAUI_BCITY'     , 'P_B_CITY'        ,
    'WAUI_BCODE'     , 'P_B_CODE'        ,
    'WAUI_BADDRESS1' , 'P_B_ADDRESS1'    ,
    'WAUI_BADDRESS2' , 'P_B_ADDRESS2'    ,
    'WAUI_BTZONE'    , 'P_B_TZONE'       ,
    'WAUI_BLAT'      , 'P_B_LAT'         ,
    'WAUI_BLNG'      , 'P_B_LNG'         ,
    'WAUI_BPHONE'    , 'P_B_PHONE'       ,
    'WAUI_BMOBILE'   , 'P_B_MOBILE'      ,
    'WAUI_WEBPAGE'   , 'P_WEB'           ,
    'WAUI_BINDUSTRY' , 'P_B_INDUSTRY'    ,
    'WAUI_BORG'      , 'P_B_ORGANIZATION',
    'WAUI_BJOB'      , 'P_B_JOB'         ,
    'WAUI_TAGS'      , 'P_TAGS'          );
}
;

-----------------------------------------------------------------------------------------
--
create procedure AB.WA.apiHTTPError (
  in error varchar)
{
  declare S varchar;

  S := replace (error, 'HTTP/1.1 ', '');
  http_header ('Content-Type: text/html; charset=UTF-8\r\n');
  http_request_status (error);
  http (sprintf ('<!DOCTYPE HTML PUBLIC "-//IETF//DTD HTML 2.0//EN"><html><head><title>%s</title></head><body><h1>%s</h1></body></html>', S, S));
}
;

-----------------------------------------------------------------------------------------
--
create procedure AB.WA.apiObject ()
{
  return subseq (soap_box_structure ('x', 1), 0, 2);
}
;

-----------------------------------------------------------------------------------------
--
create procedure AB.WA.isApiObject (inout o any)
{
  if (isarray (o) and (length (o) > 1) and (__tag (o[0]) = 255))
    return 1;
  return 0;
}
;


-----------------------------------------------------------------------------------------
--
create procedure AB.WA.obj2xml (
  in o any,
  in d integer := 10,
  in tag varchar := null,
  in nsArray any := null,
  in attributePrefix varchar := null)
{
  declare N, M integer;
  declare R, T any;
  declare S, nsValue, retValue any;

  if (d = 0)
    return '[maximum depth achieved]';

  nsValue := '';
  if (not isnull (nsArray))
  {
    for (N := 0; N < length(nsArray); N := N + 2)
      nsValue := sprintf ('%s xmlns%s="%s"', nsValue, case when nsArray[N]='' then '' else ':'||nsArray[N] end, nsArray[N+1]);
  }
  retValue := '';
  if (isnumeric (o))
  {
    retValue := cast (o as varchar);
  }
  else if (isstring (o))
  {
    retValue := sprintf ('%V', o);
  }
  else if (AB.WA.isApiObject (o))
  {
    for (N := 2; N < length(o); N := N + 2)
    {
      if (not AB.WA.isApiObject (o[N+1]) and isarray (o[N+1]) and not isstring (o[N+1]))
      {
        retValue := retValue || AB.WA.obj2xml (o[N+1], d-1, o[N], nsArray, attributePrefix);
      } else {
    	  if (chr (o[N][0]) <> attributePrefix)
    	  {
          nsArray := null;
          S := '';
          if (not isnull (attributePrefix) and AB.WA.isApiObject (o[N+1]))
          {
            for (M := 2; M < length(o[N+1]); M := M + 2)
            {
          	  if (chr (o[N+1][M][0]) = attributePrefix)
          	    S := sprintf ('%s %s="%s"', S, subseq (o[N+1][M], length (attributePrefix)), AB.WA.obj2xml (o[N+1][M+1]));
            }
          }
          retValue := retValue || sprintf ('<%s%s%s>%s</%s>\n', o[N], S, nsValue, AB.WA.obj2xml (o[N+1], d-1, null, nsArray, attributePrefix), o[N]);
        }
      }
    }
  }
  else if (isarray (o))
  {
    for (N := 0; N < length(o); N := N + 1)
    {
      if (isnull (tag))
      {
        retValue := retValue || AB.WA.obj2xml (o[N], d-1, tag, nsArray, attributePrefix);
      } else {
        nsArray := null;
        S := '';
        if (not isnull (attributePrefix) and AB.WA.isApiObject (o[N]))
        {
          for (M := 2; M < length(o[N]); M := M + 2)
          {
        	  if (chr (o[N][M][0]) = attributePrefix)
        	    S := sprintf ('%s %s="%s"', S, subseq (o[N][M], length (attributePrefix)), AB.WA.obj2xml (o[N][M+1]));
          }
        }
        retValue := retValue || sprintf ('<%s%s%s>%s</%s>\n', tag, S, nsValue, AB.WA.obj2xml (o[N], d-1, null, nsArray, attributePrefix), tag);
      }
    }
  }
  return retValue;
}
;

-----------------------------------------------------------------------------------------
--
-- Portable Contacts
--
-----------------------------------------------------------------------------------------
create procedure AB.WA.pcMap ()
{
  return vector ('id',              vector ('field',    'P_ID'),
                 'nickname',        vector ('field',    'P_NAME'),
                 'gender',          vector ('field',    'P_GENDER'),
                 'name.givenName',  vector ('field',    'P_FIRST_NAME'),
                 'name.middleName', vector ('field',    'P_MIDDLE_NAME'),
                 'name.familyName', vector ('field',    'P_LAST_NAME'),
                 'published',       vector ('type',     'function',
                                            'field',    vector ('P_CREATED',   vector ('function', 'select AB.WA.dt_iso8601 (?)'))
                                           ),
                 'updated',         vector ('type',     'function',
                                            'field',    vector ('P_UPDATED',   vector ('function', 'select AB.WA.dt_iso8601 (?)'))
                                           ),
                 'birthday',        vector ('type',     'function',
                                            'field',    vector ('P_BIRTHDAY',  vector ('function', 'select subseq (AB.WA.dt_iso8601 (?), 0, 10)'))
                                           ),
                 'emails',          vector ('sort',     'P_MAIL',
                                            'filter',   vector ('P_MAIL', 'P_H_MAIL', 'P_B_MAIL'),
                                            'type',     'vector/object',
                                            'field',    vector ('P_MAIL',   vector ('template', vector_concat (AB.WA.apiObject (), vector ('primary', 'true'))),
                                                                'P_H_MAIL', vector ('template', vector_concat (AB.WA.apiObject (), vector ('type', 'home'))),
                                                                'P_B_MAIL', vector ('template', vector_concat (AB.WA.apiObject (), vector ('type', 'work')))
                                                               )
                                           ),
                 'phoneNumbers',    vector ('sort',     'P_PHONE',
                                            'filter',   vector ('P_PHONE', 'P_H_PHONE', 'P_B_PHONE'),
                                            'type',     'vector/object',
                                            'field',    vector ('P_PHONE',   vector ('template', vector_concat (AB.WA.apiObject (), vector ('primary', 'true'))),
                                                                'P_H_PHONE', vector ('template', vector_concat (AB.WA.apiObject (), vector ('type', 'home'))),
                                                                'P_B_PHONE', vector ('template', vector_concat (AB.WA.apiObject (), vector ('type', 'work')))
                                                               )
                                           ),
                 'urls',            vector ('sort',     'P_H_WEB',
                                            'filter',   vector ('P_WEB', 'P_H_WEB', 'P_B_WEB'),
                                            'type',     'vector/object',
                                            'field',    vector ('P_WEB',     vector ('template', vector_concat (AB.WA.apiObject (), vector ('primary', 'true'))),
                                                                'P_H_WEB',   vector ('template', vector_concat (AB.WA.apiObject (), vector ('type', 'home'))),
                                                                'P_B_WEB',   vector ('template', vector_concat (AB.WA.apiObject (), vector ('type', 'work')))
                                                               )
                                           ),
                 'ims',             vector ('sort',     'null',
                                            'filter',   'null',
                                            'type',     'vector/object',
                                            'field',    vector ('P_ICQ',   vector ('template', vector_concat (AB.WA.apiObject (), vector ('type', 'icq'))),
                                                                'P_SKYPE', vector ('template', vector_concat (AB.WA.apiObject (), vector ('type', 'skype'))),
                                                                'P_AIM',   vector ('template', vector_concat (AB.WA.apiObject (), vector ('type', 'aim'))),
                                                                'P_YAHOO', vector ('template', vector_concat (AB.WA.apiObject (), vector ('type', 'yahoo'))),
                                                                'P_MSN',   vector ('template', vector_concat (AB.WA.apiObject (), vector ('type', 'msn')))
                                                               )
                                           ),
                 'addresses',       vector ('sort',     'null',
                                            'filter',   'null',
                                            'type',     'vector/object2',
                                            'unique',   'type',
                                            'field',    vector ('P_H_COUNTRY', vector ('property', 'country',       'template', vector_concat (AB.WA.apiObject (), vector ('type', 'home'))),
                                                                'P_H_STATE',   vector ('property', 'region',        'template', vector_concat (AB.WA.apiObject (), vector ('type', 'home'))),
                                                                'P_H_CODE',    vector ('property', 'postalCode',    'template', vector_concat (AB.WA.apiObject (), vector ('type', 'home'))),
                                                                'P_H_CITY',    vector ('property', 'locality',      'template', vector_concat (AB.WA.apiObject (), vector ('type', 'home'))),
                                                                'P_H_ADDRESS1',vector ('property', 'streetAddress', 'template', vector_concat (AB.WA.apiObject (), vector ('type', 'home'))),
                                                                'P_B_COUNTRY', vector ('property', 'country',       'template', vector_concat (AB.WA.apiObject (), vector ('type', 'work'))),
                                                                'P_B_STATE',   vector ('property', 'region',        'template', vector_concat (AB.WA.apiObject (), vector ('type', 'work'))),
                                                                'P_B_CODE',    vector ('property', 'postalCode',    'template', vector_concat (AB.WA.apiObject (), vector ('type', 'work'))),
                                                                'P_B_CITY',    vector ('property', 'locality',      'template', vector_concat (AB.WA.apiObject (), vector ('type', 'work'))),
                                                                'P_B_ADDRESS1',vector ('property', 'streetAddress', 'template', vector_concat (AB.WA.apiObject (), vector ('type', 'work')))
                                                               )
                                           ),
                 'tags',            vector ('sort',     'null',
                                            'filter',   'null',
                                            'type',     'function',
                                            'field',    vector ('P_TAGS',   vector ('function', 'select AB.WA.tags2vector (?)'))
                                           )
                );
}
;

-----------------------------------------------------------------------------------------
--
create procedure AB.WA.pcSortField (
  in pcField varchar,
  in pcMap varchar)
{
  declare V, F any;

  V := get_keyword (pcField, pcMap);
  if (isnull (V))
    return V;

  F := get_keyword ('sort', V);
  if (isstring (F) and (F = 'null'))
    return null;
  if (isstring (F))
    return F;
  F := get_keyword ('field', V);
  if (isstring (F))
    return F;
  return null;
}
;

-----------------------------------------------------------------------------------------
--
create procedure AB.WA.pcFilterField (
  in pcField varchar,
  in pcMap varchar)
{
  declare V, F any;

  V := get_keyword (pcField, pcMap);
  if (isnull (V))
    return V;

  F := get_keyword ('filter', V);
  if (isstring (F) and (F = 'null'))
    return null;
  if (not isarray (F))
    F := get_keyword ('field', V);
  if (isstring (F))
    F := vector (F);
  if (isarray (F))
    return F;
  return null;
}
;

-----------------------------------------------------------------------------------------
--
create procedure AB.WA.pcContactField (
  in pcField varchar,
  in pcMap varchar,
  in pcFields any := null)
{
  if (not isnull (pcFields) and not AB.WA.vector_contains (pcFields, pcField))
    return null;

  return get_keyword (pcField, pcMap);
}
;

-----------------------------------------------------------------------------------------
--
create procedure AB.WA.simplifyMeta (
  in abMeta any)
{
  declare N integer;
  declare newMeta any;

  newMeta := vector ();
  for (N := 0; N < length (abMeta[0]); N := N + 1)
    newMeta := vector_concat (newMeta, vector (abMeta[0][N][0]));

  return newMeta;
}
;

-----------------------------------------------------------------------------------------
--
create procedure AB.WA.pcContactFieldIndex (
  in abField varchar,
  in abMeta any)
{
  declare N integer;

  for (N := 0; N < length (abMeta); N := N + 1)
    if (abField = abMeta[N])
      return N;

  return null;
}
;

-----------------------------------------------------------------------------------------
--
create procedure AB.WA.pcContactObject (
  in fields any,
  in data any,
  in meta any,
  in pcMap any)
{
  declare K, L, M, N integer;
  declare oEntry any;
  declare R, V, T, P, P1, aIndex any;
  declare tmp, pcField, pcFieldDef, pcUnique, pcUniqueValue, abValue, abFieldDef, abField, abFieldType, abFieldIndex any;

  oEntry := AB.WA.apiObject ();
  for (N := 0; N < length (fields); N := N + 1)
  {
    pcField := fields[N];
    pcFieldDef := AB.WA.pcContactField (pcField, pcMap);
    if (isnull (pcFieldDef))
      goto _skip;
    abField := get_keyword ('field', pcFieldDef);
    if (isnull (abField))
      goto _skip;
    abFieldType := get_keyword ('type', pcFieldDef);
    if (isstring (abField))
      abField := vector (abField, null);
    for (M := 0; M < length (abField); M := M + 2)
    {
      abFieldDef := abField[M+1];
      abFieldIndex := AB.WA.pcContactFieldIndex (abField[M], meta);
      if (isnull (abFieldIndex))
        goto _skip_field;
      abValue := data[abFieldIndex];
      if (is_empty_or_null (abValue))
        goto _skip_field;
      if (isnull (abFieldType))
      {
        if (isnull (strchr (pcField, '.')))
        {
          oEntry := vector_concat (oEntry, vector (pcField, abValue));
        }
        else
        {
          V := split_and_decode (pcField, 0, '\0\0.');
          if (length (V) <> 2)
            goto _skip_field;
          if (isnull (AB.WA.vector_index (oEntry, V[0])))
            oEntry := vector_concat (oEntry, vector (V[0], AB.WA.apiObject ()));
          T := get_keyword (V[0], oEntry);
          T := AB.WA.set_keyword (V[1], T, abValue);
          oEntry := AB.WA.set_keyword (V[0], oEntry, T);
        }
      }
      else if (abFieldType = 'function')
      {
        tmp := get_keyword ('function', abFieldDef);
        if (not isnull (tmp))
        {
          tmp := AB.WA.exec (tmp, vector (abValue));
          if (length (tmp))
            abValue := tmp[0][0];
        }
        oEntry := vector_concat (oEntry, vector (pcField, abValue));
      }
      else if (abFieldType = 'vector/object')
      {
        if (isnull (AB.WA.vector_index (oEntry, pcField)))
          oEntry := vector_concat (oEntry, vector (pcField, vector ()));
        P := get_keyword (pcField, oEntry);
        T := get_keyword ('template', abFieldDef, AB.WA.apiObject ());
        T := AB.WA.set_keyword (get_keyword ('property', abFieldDef, 'value'), T, abValue);
        P := vector_concat (P, vector (T));
        oEntry := AB.WA.set_keyword (pcField, oEntry, P);
      }
      else if (abFieldType = 'vector/object2')
      {
        if (isnull (AB.WA.vector_index (oEntry, pcField)))
          oEntry := vector_concat (oEntry, vector (pcField, vector ()));
        P := get_keyword (pcField, oEntry);
        T := get_keyword ('template', abFieldDef, AB.WA.apiObject ());
        pcUnique := get_keyword ('unique', pcFieldDef, 'type');
        pcUniqueValue := get_keyword (pcUnique, T);
        K := -1;
        for (L := 0; L < length (P); L := L + 1)
        {
          if (get_keyword (pcUnique, P[L]) = pcUniqueValue)
          {
            K := L;
            goto _exit_unique;
          }
        }
        P := vector_concat (P, vector (T));
        K := length (P) - 1;
      _exit_unique:;
        T := P[K];
        T := AB.WA.set_keyword (get_keyword ('property', abFieldDef, 'value'), T, abValue);
        P[K] := T;
        oEntry := AB.WA.set_keyword (pcField, oEntry, P);
      }
    _skip_field:;
    }
  _skip:;
  }
  if (length (oEntry) > 2)
    return oEntry;
  return null;
}
;

-----------------------------------------------------------------------------------------
--
create procedure AB.WA.pcPrepareOwner (
  inout data any,
  in dataValue any,
  inout meta any,
  in metaValue varchar)
{
  data := vector_concat (data, vector (dataValue));
  meta := vector_concat (meta, vector (metaValue));
}
;

-----------------------------------------------------------------------------------------
--
create procedure AB.WA.portablecontacts () __SOAP_HTTP 'text/html'
{
  declare exit handler for sqlstate '*'
  {
    if (__SQL_STATE = '__400')
    {
      AB.WA.apiHTTPError ('HTTP/1.1 400 Bad Request');
    }
    else if (__SQL_STATE = '__401')
    {
      AB.WA.apiHTTPError ('HTTP/1.1 401 Unauthorized');
    }
    else if (__SQL_STATE = '__404')
    {
      AB.WA.apiHTTPError ('HTTP/1.1 404 Not Found');
    }
    else if (__SQL_STATE = '__500')
    {
      AB.WA.apiHTTPError ('HTTP/1.1 500 Not Found');
    }
    else if (__SQL_STATE = '__503')
    {
      AB.WA.apiHTTPError ('HTTP/1.1 503 Service Unavailable');
    }
    else
    {
      dbg_obj_princ (__SQL_STATE, __SQL_MESSAGE);
    }
    return null;
  };
	declare uname varchar;
  declare N, M, L, domain_id, contact_id integer;
  declare filter, updatedSince, filterBy, filterOp, filterValue varchar;
  declare sort, sortBy, sortOrder varchar;
  declare startIndex, countItems varchar;
  declare fields, format varchar;
  declare tmp, pcMap, ocMap any;
  declare V, oResult, oEntries, oEntry, lines, path, params any;
  declare S, st, msg, meta, data any;

  lines := http_request_header ();
  path := http_path ();
  params := http_param ();

  domain_id := atoi (get_keyword_ucase ('inst_id', params));
	if (not ODS..ods_check_auth (uname, domain_id, 'reader'))
    signal ('__401', '');

  if (not exists (select 1 from DB.DBA.WA_INSTANCE where WAI_ID = domain_id and WAI_TYPE_NAME = 'AddressBook'))
    signal ('__401', '');

  if (path not like '/ods/portablecontacts%')
    signal ('__404', '');

    path := substring (path, length ('/ods/portablecontacts')+1, length (path));
  V := split_and_decode (trim (path, '/'), 0, '\0\0/');
  if ((length (V) < 2) or (V[0] <> '@me'))
    signal ('__404', '');

  if (V[1] not in ('@all', '@owner'))
    signal ('__404', '');

  -- output format
  format := ucase (get_keyword_ucase ('FORMAT', params, 'JSON'));
  if (format not in ('JSON', 'XML'))
    format:= 'JSON';

  -- filed mapping
  pcMap := AB.WA.pcMap ();
  -- Presentation
  fields := get_keyword_ucase ('fields', params);
  if (not isnull (fields))
  {
    fields := split_and_decode (fields, 0, '\0\0,');
  } else {
    fields := vector ();
    for (N := 0; N < length (pcMap); N := N + 2)
      fields := vector_concat (fields, vector (pcMap[N]));
  }
  set_user_id ('dba');
  oEntries := vector ();
  if (V[1] = '@owner')
  {
    st := '00000';
    S := 'select *, WA_USER_TAG_GET(U_NAME) WAUI_TAGS from DB.DBA.SYS_USERS, DB.DBA.WA_USER_INFO where WAUI_U_ID = U_ID and U_ID = ?';
    exec (S, st, msg, vector (AB.WA.domain_owner_id (domain_id)), 0, meta, data);
    if (('00000' = st) and (length (data) = 1))
    {
      data := data[0];
      meta := AB.WA.simplifyMeta (meta);
      ocMap := AB.WA.owner2contactMap();
      for (N := 0; N < length (meta); N := N + 1)
      {
        tmp := get_keyword (meta[N], ocMap);
        if (not isnull (tmp))
          meta[N] := tmp;
    }
    oEntry := AB.WA.pcContactObject (fields, data, meta, pcMap);
    if (not isnull (oEntry))
      oEntries := vector_concat (oEntries, vector (oEntry));
    }
  } else {
    contact_id := null;
    if (length (V) = 3)
    {
      contact_id := atoi (V[2]);
      if (contact_id = 0)
        signal ('__404', '');
    }

    -- filter
    filter := '';
    updatedSince := get_keyword_ucase ('UPDATEDSINCE', params);
    if (not is_empty_or_null (updatedSince))
    {
      filter := sprintf ('(cast (U_UPDATED as varchar) like ''%s%%'')', updatedSince);
    }
    filterBy := get_keyword_ucase ('FILTERBY', params);
    if (not is_empty_or_null (filterBy))
    {
      filterOp := get_keyword_ucase ('FILTEROP', params);
      if (is_empty_or_null (filterOp))
        signal ('__404', '');
      if (filterOp <> 'present')
      {
        filterValue := get_keyword_ucase ('FILTERVALUE', params);
        if (is_empty_or_null (filterValue))
          signal ('__404', '');
      }
      V := AB.WA.pcFilterField (filterBy, pcMap);
      if (not is_empty_or_null (V))
      {
        for (N := 0; N < length (V); N := N + 1)
        {
          S := '';
          if      (filterOp = 'equals')
          {
            S := sprintf ('(cast (%s as varchar) = ''%s'')', V[N], filterValue);
          }
          else if (filterOp = 'contains')
          {
            S := sprintf ('(cast (%s as varchar) like ''%%%s%%'')', V[N], filterValue);
          }
          else if (filterOp = 'startswith')
          {
            S := sprintf ('(cast (%s as varchar) like ''%s%%'')', V[N], filterValue);
          }
          else if (filterOp = 'present')
          {
            S := sprintf ('(cast (%s as varchar) <> '''')', V[N]);
          }
          if ((filter <> '') and (S <> ''))
            filter := filter || ' or ';
          filter := filter || S;
        }
      }
    }
    -- sort
    sort := '';
    sortBy := get_keyword_ucase ('SORTBY', params);
    if (not is_empty_or_null (sortBy))
    {
      sort := AB.WA.pcSortField (sortBy, pcMap);
      if (not is_empty_or_null (sort))
        sort := sort || ' ' || get_keyword_ucase ('SORTORDER', params, 'asc');
    }

    -- pagination
    startIndex := atoi (get_keyword_ucase ('STARTINDEX', params, '0'));
    countItems := atoi (get_keyword_ucase ('COUNT', params, '10'));

    st := '00000';
    S := sprintf ('select TOP %d, %d * from AB.WA.PERSONS where P_DOMAIN_ID = ?', startIndex, countItems);
    if (not is_empty_or_null (contact_id))
      S := S || ' and P_ID = ' || cast (contact_id as varchar);
    if (not is_empty_or_null (filter))
      S := S || ' and (' || filter || ')';
    if (not is_empty_or_null (sort))
      S := S || ' order by ' || sort;
    exec (S, st, msg, vector (domain_id), 0, meta, data);
    if ('00000' = st)
    {
      meta := AB.WA.simplifyMeta (meta);
      for (N := 0; N < length (data); N := N + 1)
      {
        oEntry := AB.WA.pcContactObject (fields, data[N], meta, pcMap);
        if (not isnull (oEntry))
          oEntries := vector_concat (oEntries, vector (oEntry));
      }
    }
  }
  oResult := AB.WA.apiObject ();
  oResult := vector_concat (oResult, vector ('startIndex', startIndex, 'countItems', countItems));
  if (length (oEntries))
    oResult := vector_concat (oResult, vector ('entry', oEntries));

  http_request_status ('HTTP/1.1 200 OK');
  if (format = 'JSON')
  {
    http (ODS..obj2json (oResult, 10));
  } else {
    http (AB.WA.obj2xml (oResult));
  }
  return '';
}
;

grant execute on AB.WA.portablecontacts to SOAP_ADDRESSBOOK
;

-----------------------------------------------------------------------------------------
--
-- Live Contacts (Microsoft)
--
-- ---------------------------------------------------------------------------------------
create procedure AB.WA.lcPredefinedFilters (
  in lcFilter varchar)
{
  lcFilter := ucase (lcFilter);
  if (lcFilter = 'HOTMAIL')
    return 'LiveContacts(Contact(ID,CID,WindowsLiveID,AutoUpdateEnabled,AutoUpdateStatus,Profiles,Email,Phone,Location,URI),Tag)';
  if (lcFilter = 'MESSENGERSERVER')
    return 'LiveContacts(Contact(ID,CID,WindowsLiveID,AutoUpdateEnabled,AutoUpdateStatus,Profiles(Personal),Email,Phone),Tag)';
  if (lcFilter = 'MESSENGERCLIENT')
    return 'LiveContacts(Contact(ID,CID,WindowsLiveID,AutoUpdateEnabled,AutoUpdateStatus,Profiles,Email,Phone),Tag)';
  if (lcFilter = 'PHONE')
    return 'LiveContacts(Contact(ID,CID,WindowsLiveID,AutoUpdateEnabled,AutoUpdateStatus,Profiles(Personal(FirstName,LastName)),Email,Phone,Location),Tag)';
  if (lcFilter = 'MINIMALPHONE')
    return 'LiveContacts(Contact(ID,WindowsLiveID,Profiles(Personal(NameToFileAs,FirstName,LastName)),Email,Phone),Tag)';
  if (lcFilter = 'MAPPOINT')
    return 'LiveContacts(Contact(ID,WindowsLiveID,Profiles(Personal(NameToFileAs,FirstName,LastName)),Location))';
  return null;
}
;

-----------------------------------------------------------------------------------------
--
create procedure AB.WA.lcFilterFields_Int (
  in lcFilter varchar,
  in apiPath varchar,
  inout lcFields any)
{
  declare L_Brace, R_Brace, L_Comma integer;

  L_Brace := strchr (lcFilter, '(');
  L_Comma := strchr (lcFilter, ',');
  while (not isnull (L_Brace) or not isnull (L_Comma))
  {
    if (not isnull (L_Comma) and (isnull (L_Brace) or (L_Comma < L_Brace)))
    {
      lcFields := vector_concat (lcFields, vector (apiPath || case when apiPath = '' then '' else '.' end || trim (subseq (lcFilter, 0, l_Comma))));
      lcFilter := trim (subseq (lcFilter, L_Comma+1, length (lcFilter)));
      goto _loop;
    }
    R_Brace := strrchr (lcFilter, ')');
    if (isnull (L_Brace) and not isnull (R_Brace))
      return;
    if (not isnull (L_Brace) and isnull (R_Brace))
      return;
    AB.WA.lcFilterFields_Int (trim (subseq (lcFilter, L_Brace+1, R_Brace)), apiPath || case when apiPath = '' then '' else '.' end || trim (subseq (lcFilter, 0, L_Brace)), lcFields);
    lcFilter := trim (subseq (lcFilter, R_Brace+1, length (lcFilter)));
  _loop:
    L_Brace := strchr (lcFilter, '(');
    L_Comma := strchr (lcFilter, ',');
  }
  if (lcFilter <> '')
    lcFields := vector_concat (lcFields, vector (apiPath || case when apiPath = '' then '' else '.' end || lcFilter));
}
;

-----------------------------------------------------------------------------------------
--
create procedure AB.WA.lcFilterFields (
  in lcFilter varchar)
{
  declare apiPath, lcFields any;

  apiPath := '';
  lcFields := Vector ();
  AB.WA.lcFilterFields_Int (lcFilter, apiPath, lcFields);

  return lcFields;
}
;

-----------------------------------------------------------------------------------------
--
create procedure AB.WA.lcMap ()
{
  return vector ('ID',                                  vector ('field', 'P_ID'),
                 'CID',                                 vector ('field', 'P_UID'),
                 'URI',                                 vector ('field', 'P_IRI'),
                 'Profiles.Personal.NickName',          vector ('field', 'P_NAME',      'xpath', vector ('Profiles.Personal.NickName', 'Profiles.Personal.LastName', 'Profiles.Personal.FirstName')),
                 'Profiles.Personal.FirstName',         vector ('field', 'P_FIRST_NAME'),
                 'Profiles.Personal.MiddleName',        vector ('field', 'P_MIDDLE_NAME'),
                 'Profiles.Personal.LastName',          vector ('field', 'P_LAST_NAME'),
                 'Profiles.Personal.Gender',            vector ('field', 'P_GENDER'),
                 'Profiles.Personal.Birthdate',         vector ('field', 'P_BIRTHDAY',  'function', 'select subseq (AB.WA.dt_iso8601 (?), 0, 10)'),
                 'Profiles.Professional.JobTitle',      vector ('field', 'P_B_JOB'),
                 'Locations.Location.CountryRegion',    vector ('field', 'P_H_COUNTRY', 'xpath', vector ('Locations.Location[LocationType="Personal"].CountryRegion'), 'unique', 'LocationType', 'template', vector_concat (AB.WA.apiObject (), vector ('LocationType', 'Personal', 'IsDefault', 'true'))),
                 'Locations.Location.SubDivision',      vector ('field', 'P_H_STATE',   'xpath', vector ('Locations.Location[LocationType="Personal"].SubDivision'),   'unique', 'LocationType', 'template', vector_concat (AB.WA.apiObject (), vector ('LocationType', 'Personal', 'IsDefault', 'true'))),
                 'Locations.Location.PostalCode',       vector ('field', 'P_H_CODE',    'xpath', vector ('Locations.Location[LocationType="Personal"].PostalCode'),    'unique', 'LocationType', 'template', vector_concat (AB.WA.apiObject (), vector ('LocationType', 'Personal', 'IsDefault', 'true'))),
                 'Locations.Location.PrimaryCity',      vector ('field', 'P_H_CITY',    'xpath', vector ('Locations.Location[LocationType="Personal"].PrimaryCity'),   'unique', 'LocationType', 'template', vector_concat (AB.WA.apiObject (), vector ('LocationType', 'Personal', 'IsDefault', 'true'))),
                 'Locations.Location.StreetLine',       vector ('field', 'P_H_ADDRESS1','xpath', vector ('Locations.Location[LocationType="Personal"].StreetLine'),    'unique', 'LocationType', 'template', vector_concat (AB.WA.apiObject (), vector ('LocationType', 'Personal', 'IsDefault', 'true'))),
                 'Locations.Location.StreetLine2',      vector ('field', 'P_H_ADDRESS2','xpath', vector ('Locations.Location[LocationType="Personal"].StreetLine2'),   'unique', 'LocationType', 'template', vector_concat (AB.WA.apiObject (), vector ('LocationType', 'Personal', 'IsDefault', 'true'))),
                 'Locations.Location.Latitude',         vector ('field', 'P_H_LAT',     'xpath', vector ('Locations.Location[LocationType="Personal"].Latitude'),      'unique', 'LocationType', 'template', vector_concat (AB.WA.apiObject (), vector ('LocationType', 'Personal', 'IsDefault', 'true'))),
                 'Locations.Location.Longitude',        vector ('field', 'P_H_LNG',     'xpath', vector ('Locations.Location[LocationType="Personal"].Longitude'),     'unique', 'LocationType', 'template', vector_concat (AB.WA.apiObject (), vector ('LocationType', 'Personal', 'IsDefault', 'true'))),
                 'Locations.Location.CountryRegion[2]', vector ('field', 'P_B_COUNTRY', 'xpath', vector ('Locations.Location[LocationType="Business"].CountryRegion'), 'unique', 'LocationType', 'template', vector_concat (AB.WA.apiObject (), vector ('LocationType', 'Business'))),
                 'Locations.Location.SubDivision[2]',   vector ('field', 'P_B_STATE',   'xpath', vector ('Locations.Location[LocationType="Business"].SubDivision'),   'unique', 'LocationType', 'template', vector_concat (AB.WA.apiObject (), vector ('LocationType', 'Business'))),
                 'Locations.Location.PostalCode[2]',    vector ('field', 'P_B_CODE',    'xpath', vector ('Locations.Location[LocationType="Business"].PostalCode'),    'unique', 'LocationType', 'template', vector_concat (AB.WA.apiObject (), vector ('LocationType', 'Business'))),
                 'Locations.Location.PrimaryCity[2]',   vector ('field', 'P_B_CITY',    'xpath', vector ('Locations.Location[LocationType="Business"].PrimaryCity'),   'unique', 'LocationType', 'template', vector_concat (AB.WA.apiObject (), vector ('LocationType', 'Business'))),
                 'Locations.Location.StreetLine[2]',    vector ('field', 'P_B_ADDRESS1','xpath', vector ('Locations.Location[LocationType="Business"].StreetLine'),    'unique', 'LocationType', 'template', vector_concat (AB.WA.apiObject (), vector ('LocationType', 'Business'))),
                 'Locations.Location.StreetLine2[2]',   vector ('field', 'P_B_ADDRESS2','xpath', vector ('Locations.Location[LocationType="Business"].StreetLine2'),   'unique', 'LocationType', 'template', vector_concat (AB.WA.apiObject (), vector ('LocationType', 'Business'))),
                 'Locations.Location.Latitude[2]',      vector ('field', 'P_B_LAT',     'xpath', vector ('Locations.Location[LocationType="Business"].Latitude'),      'unique', 'LocationType', 'template', vector_concat (AB.WA.apiObject (), vector ('LocationType', 'Business'))),
                 'Locations.Location.Longitude[2]',     vector ('field', 'P_B_LNG',     'xpath', vector ('Locations.Location[LocationType="Business"].Longitude'),     'unique', 'LocationType', 'template', vector_concat (AB.WA.apiObject (), vector ('LocationType', 'Business'))),
                 'Emails.Email.Address',                vector ('field', 'P_MAIL',      'xpath', vector ('Emails.Email[EmailType="Personal"].Address'), 'unique', 'EmailType', 'template', vector_concat (AB.WA.apiObject (), vector ('EmailType', 'Personal', 'IsDefault', 'true'))),
                 'Emails.Email.Address[2]',             vector ('field', 'P_B_MAIL',    'xpath', vector ('Emails.Email[EmailType="Business"].Address'), 'unique', 'EmailType', 'template', vector_concat (AB.WA.apiObject (), vector ('EmailType', 'Business'))),
                 'Phones.Phone.Number',                 vector ('field', 'P_PHONE',     'xpath', vector ('Phones.Phone[PhoneType="Personal"].Number'), 'unique', 'PhoneType', 'template', vector_concat (AB.WA.apiObject (), vector ('PhoneType', 'Personal', 'IsDefault', 'true'))),
                 'Phones.Phone.Number[2]',              vector ('field', 'P_B_PHONE',   'xpath', vector ('Phones.Phone[PhoneType="Business"].Number'), 'unique', 'PhoneType', 'template', vector_concat (AB.WA.apiObject (), vector ('PhoneType', 'Business'))),
                 'URIs.URI.Address',                    vector ('field', 'P_WEB',       'xpath', vector ('URIs.URI[URIType="Personal"].Address'), 'unique', 'URIType', 'template', vector_concat (AB.WA.apiObject (), vector ('URIType', 'Personal', 'IsDefault', 'true'))),
                 'URIs.URI.Address[2]',                 vector ('field', 'P_B_WEB',     'xpath', vector ('URIs.URI[URIType="Business"].Address'), 'unique', 'URIType', 'template', vector_concat (AB.WA.apiObject (), vector ('URIType', 'Business'))),
                 'Tag',                                 vector ('field', 'P_TAGS',      'type', 'tag')
                );
}
;

-----------------------------------------------------------------------------------------
--
create procedure AB.WA.lcFindObject (
  in lcObject any,
  in lcProperty varchar,
  in lcUnique varchar := null,
  in lcUniqueValue varchar := null)
{
  declare N integer;

  for (N := 2; N < length (lcObject); N := N + 2)
  {
    if (lcObject[N] = lcProperty)
    {
      if (isnull (lcUnique))
        return N+1;
      if (get_keyword (lcUnique, lcObject[N+1]) = lcUniqueValue)
        return N+1;
    }
  }
  return null;
}
;

-----------------------------------------------------------------------------------------
--
create procedure AB.WA.lcContactField (
  in lcField varchar,
  in lcMap varchar,
  in lcFields any := null)
{
  if (not isnull (lcFields) and not AB.WA.vector_contains (lcFields, lcField))
    return null;

  return get_keyword (lcField, lcMap);
}
;

-----------------------------------------------------------------------------------------
--
create procedure AB.WA.lcContactFieldIndex (
  in abField varchar,
  in abMeta any)
{
  declare N integer;

  for (N := 0; N < length (abMeta); N := N + 1)
    if (abField = abMeta[N])
      return N;

  return null;
}
;

-----------------------------------------------------------------------------------------
--
create procedure AB.WA.lcContactValue (
  in lcField varchar,
  inout data any,
  inout meta any,
  inout lcMap any)
{
  declare tmp, lcFieldDef any;
  declare abValue, abField, abFieldIndex any;

  abValue := null;
  lcFieldDef := AB.WA.lcContactField (lcField, lcMap);
  if (isnull (lcFieldDef))
    goto _skip;
  abField := get_keyword ('field', lcFieldDef);
  if (isnull (abField))
    goto _skip;
  abFieldIndex := AB.WA.lcContactFieldIndex (abField, meta);
  if (isnull (abFieldIndex))
    goto _skip;
  abValue := data[abFieldIndex];
  if (is_empty_or_null (abValue))
    goto _skip;
  if (not isnull (get_keyword ('function', lcFieldDef)))
  {
    tmp := get_keyword ('function', lcFieldDef);
    if (not isnull (tmp))
    {
      tmp := AB.WA.exec (tmp, vector (abValue));
      if (length (tmp))
        abValue := tmp[0][0];
    }
  }
_skip:;
  return abValue;
}
;

-----------------------------------------------------------------------------------------
--
create procedure AB.WA.lcContactObject (
  inout fields any,
  inout data any,
  inout meta any,
  inout lcMap any,
  inout lcTags any)
{
  declare L, M, N, pos integer;
  declare tmp, oEntry, oTag any;
  declare V, T, T1 any;
  declare abValue, abFieldDef, abField, abFieldType, abFieldIndex any;
  declare lcField, lcFieldDef, lcTemplate, lcUnique, lcUniqueValue any;

  oEntry := AB.WA.apiObject ();
  for (N := 0; N < length (fields); N := N + 1)
  {
    lcField := fields[N];
    abValue := AB.WA.lcContactValue (lcField, data, meta, lcMap);
    if (is_empty_or_null (abValue))
      goto _skip;
    lcFieldDef := AB.WA.lcContactField (lcField, lcMap);
    L := strchr (lcField, '[');
    if (not isnull (L))
      lcField := subseq (lcField, 0, L);
    abFieldType := get_keyword ('type', lcFieldDef);
    if (isnull (abFieldType))
    {
      if (isnull (strchr (lcField, '.')))
      {
        oEntry := vector_concat (oEntry, vector (lcField, abValue));
      }
      else
      {
        lcTemplate := get_keyword ('template', lcFieldDef, AB.WA.apiObject ());
        V := split_and_decode (lcField, 0, '\0\0.');
        if (length (V) < 2)
          goto _skip;
        if (isnull (get_keyword (V[0], oEntry)))
        {
          if (length (V) = 2)
            oEntry := vector_concat (oEntry, vector (V[0], lcTemplate));
          if (length (V) = 3)
            oEntry := vector_concat (oEntry, vector (V[0], AB.WA.apiObject ()));
        }
        T := get_keyword (V[0], oEntry);
        if (length (V) = 2)
        {
          T := AB.WA.set_keyword (V[1], T, abValue);
        }
        else if (length (V) = 3)
        {
          lcUnique := get_keyword ('unique', lcFieldDef);
          if (isnull (lcUnique))
          {
            if (isnull (get_keyword (V[1], T)))
              T := vector_concat (T, vector (V[1], lcTemplate));
            T1 := get_keyword (V[1], T);
            T1 := AB.WA.set_keyword (V[2], T1, abValue);
            T := AB.WA.set_keyword (V[1], T, T1);
          } else {
            if (not isnull (lcUnique))
              lcUniqueValue := get_keyword (lcUnique, lcTemplate);
            L := AB.WA.lcFindObject (T, V[1], lcUnique, lcUniqueValue);
            if (isnull (L))
              T := vector_concat (T, vector (V[1], lcTemplate));
            L := AB.WA.lcFindObject (T, V[1], lcUnique, lcUniqueValue);
            T[L] := AB.WA.set_keyword (V[2], T[L], abValue);
          }
        }
        oEntry := AB.WA.set_keyword (V[0], oEntry, T);
      }
    }
    else if (abFieldType = 'tag')
    {
      if (isnull (lcTags))
        lcTags := dict_new();
      tmp := AB.WA.tags2vector (abValue);
      foreach (any tag in tmp) do
      {
        tag := lcase (tag);
        oTag := dict_get(lcTags, tag, vector());
        oTag := vector_concat (oTag, vector (AB.WA.lcContactValue ('ID', data, meta, lcMap)));
        dict_put(lcTags, tag, oTag);
      }
    }
  _skip:;
  }
  if (length (oEntry) > 2)
    return oEntry;
  return null;
}
;

-----------------------------------------------------------------------------------------
--
create procedure AB.WA.lcPathAnalyze (
  in domainID integer,
  in apiPath varchar,
  in apiMethod varchar,
  inout objectType varchar,
  inout objectBodyXPath any,
  inout objectXPath varchar,
  inout objectID integer)
{
  declare I, N integer;
  declare tmp, V, A any;

  objectType := '*';
  objectXPath := '/LiveContacts';
  objectBodyXPath := vector ();
  objectID := null;

  V := split_and_decode (trim (apiPath, '/'), 0, '\0\0/');
  if ((length (V) <> 2) and (apiMethod = 'DELETE'))
    signal ('__400', '');
  if ((length (V) = 0) and (apiMethod in ('POST', 'PUT')))
    signal ('__400', '');
  if (length (V) = 0)
    return 1;
  if ((V[0] <> 'owner') and (V[0] <> 'contacts'))
    signal ('__400', '');
  if ((V[0] = 'owner') and (apiMethod = 'DELETE'))
    signal ('__400', '');
  if (V[0] = 'owner')
  {
    if (apiMethod in ('POST', 'DELETE'))
      signal ('__400', '');
    I := 1;
    objectType := 'o';
    objectXPath := objectXPath || '/Owner';
    objectBodyXPath := vector_concat (objectBodyXPath, vector ('Owner'));
  }
  else
  {
    I := 1;
    objectType := 'c';
    objectXPath := objectXPath || '/Contacts';
    objectBodyXPath := vector_concat (objectBodyXPath, vector ('Contact'));
    if ((length (V) >= 2) and (V[1] like 'contact%'))
    {
      I := 2;
      A := sprintf_inverse (V[1], 'contact(%d)', 1);
      if (length (A) <> 1)
        signal ('__404', '');
      objectID := A[0];
      if (apiMethod = 'POST')
        signal ('__400', '');
      if (not exists (select 1 from AB.WA.PERSONS where P_DOMAIN_ID = domainID and P_ID = objectID))
        signal ('__400', '');
      objectXPath := objectXPath || sprintf ('/Contact[ID=%d]', objectID);
    }
    if (isnull (ObjectID) and (apiMethod = 'PUT'))
      signal ('__400', '');
  }
  for (N := I; N < length (V); N := N + 1)
  {
    A := sprintf_inverse (V[N], '%s(%s)', 1);
    if (length (A) = 2)
    {
      tmp := get_keyword (A[0], vector ('Email', 'EmailType'));
      if (not isnull (tmp))
      {
        objectXPath := objectXPath || sprintf ('/%s[%s=\'%s\']', A[0], tmp, A[1]);
        objectBodyXPath := vector_concat (objectBodyXPath, vector (A[0]));
      goto _skip;
      }
    }
    objectXPath := objectXPath || '/' || V[N];
    objectBodyXPath := vector_concat (objectBodyXPath, vector (V[N]));
  _skip:;
  }
}
;

-- ---------------------------------------------------------------------------------------
--
create procedure AB.WA.livecontacts () __SOAP_HTTP 'text/xml'
{
  declare exit handler for sqlstate '*'
  {
    if (__SQL_STATE = '__201')
    {
      AB.WA.apiHTTPError ('HTTP/1.1 201 Creates');
    }
    else if (__SQL_STATE = '__204')
    {
      AB.WA.apiHTTPError ('HTTP/1.1 204 No Content');
    }
    else if (__SQL_STATE = '__400')
    {
      AB.WA.apiHTTPError ('HTTP/1.1 400 Bad Request');
    }
    else if (__SQL_STATE = '__401')
    {
      AB.WA.apiHTTPError ('HTTP/1.1 401 Unauthorized');
    }
    else if (__SQL_STATE = '__404')
    {
      AB.WA.apiHTTPError ('HTTP/1.1 404 Not Found');
    }
    else if (__SQL_STATE = '__500')
    {
      AB.WA.apiHTTPError ('HTTP/1.1 500 Not Found');
    }
    else if (__SQL_STATE = '__503')
{
      AB.WA.apiHTTPError ('HTTP/1.1 503 Service Unavailable');
    }
    else
    {
      dbg_obj_princ (__SQL_STATE, __SQL_MESSAGE);
    }
    return null;
  };
  declare L, N, M, domain_id integer;
  declare xt, objectError, objectType, objectBodyXPath, objectXPath, objectID any;
  declare tmp, uname, V, A, oResult, oContacts, oContact, oTag any;
  declare apiLines, apiPath, apiParams, apiMethod, apiBody any;
  declare ocMap, filter, lcFields, apiMap, lcTags, lcField, lcFieldDef, apiMapField, lcXPath any;
  declare S, st, msg, meta, data any;

  apiLines := http_request_header ();
  apiPath := http_path ();
  apiParams := http_param ();
  apiMethod := ucase (http_request_get ('REQUEST_METHOD'));
  apiBody := string_output_string (http_body_read ());

  -- domain_id := 2;
  domain_id := atoi (get_keyword_ucase ('inst_id', apiParams));
  if (not ODS..ods_check_auth (uname, domain_id, 'reader'))
    signal ('__401', '');

  if (not exists (select 1 from DB.DBA.WA_INSTANCE where WAI_ID = domain_id and WAI_TYPE_NAME = 'AddressBook'))
    signal ('__401', '');

  if (apiPath not like '/ods/livecontacts%')
    signal ('__404', '');

  apiPath := substring (apiPath, length ('/ods/livecontacts')+1, length (apiPath));
  apiMap := AB.WA.lcMap();
  AB.WA.lcPathAnalyze (domain_id, apiPath, apiMethod, objectType, objectBodyXPath, objectXPath, objectID);

  set_user_id ('dba');
  if (apiMethod = 'GET')
  {
    filter := get_keyword ('filter', apiParams);
    tmp := AB.WA.lcPredefinedFilters (filter);
    if (not isnull (tmp))
      filter := tmp;
    lcFields := vector ();
    if (isnull (filter))
    {
      for (N := 0; N < length (apiMap); N := N + 2)
        lcFields := vector_concat (lcFields, vector (apiMap[N]));
    } else {
      tmp := AB.WA.lcFilterFields(filter);
      for (M := 0; M < length (tmp); M := M + 1)
      {
        lcField := lcase (trim (tmp[M]));
        if (lcField like 'livecontacts.%')
          lcField := subseq (lcField, length ('LiveContacts.'));
        if (lcField like 'contact.%')
          lcField := subseq (lcField, length ('Contact.'));
        if (lcField = '')
          goto _next_filterField;
        for (N := 0; N < length (apiMap); N := N + 2)
        {
          apiMapField := lcase (apiMap[N]);
          L := strchr (apiMapField, '[');
          if (not isnull (L))
            apiMapField := subseq (apiMapField, 0, L);
          if (apiMapField like lcField || '%')
            lcFields := vector_concat (lcFields, vector (apiMap[N]));
        }
      _next_filterField:;
      }
    }
    oResult := AB.WA.apiObject();
    lcTags := null;
    if ((objectType = '*') or (objectType = 'o'))
    {
      st := '00000';
      S := 'select *, WA_USER_TAG_GET(U_NAME) WAUI_TAGS from DB.DBA.SYS_USERS, DB.DBA.WA_USER_INFO where WAUI_U_ID = U_ID and U_ID = ?';
      exec (S, st, msg, vector (AB.WA.domain_owner_id (domain_id)), 0, meta, data);
      if (('00000' = st) and (length (data) = 1))
      {
        data := data[0];
        meta := AB.WA.simplifyMeta (meta);
        ocMap := AB.WA.owner2contactMap();
        for (N := 0; N < length (meta); N := N + 1)
        {
          tmp := get_keyword (meta[N], ocMap);
          if (not isnull (tmp))
            meta[N] := tmp;
        }
        oContact := AB.WA.lcContactObject (lcFields, data, meta, apiMap, lcTags);
        if (not isnull (oContact))
          oResult := vector_concat (oResult, vector ('Owner', oContact));
      }
    }
    if ((objectType = '*') or (objectType = 'c'))
    {
      st := '00000';
      S := 'select * from AB.WA.PERSONS where P_DOMAIN_ID = ?';
      if (not isnull (objectID))
        S := S || ' and P_ID = ' || cast (objectID as varchar);
      exec (S, st, msg, vector (domain_id), 0, meta, data);
      if ('00000' = st)
      {
        oContacts := AB.WA.apiObject();
        meta := AB.WA.simplifyMeta (meta);
        for (N := 0; N < length (data); N := N + 1)
        {
          oContact := AB.WA.lcContactObject (lcFields, data[N], meta, apiMap, lcTags);
          if (not isnull (oContact))
            oContacts := vector_concat (oContacts, vector ('Contact', oContact));
        }
      }
      if (length (oContacts) > 2)
        oResult := vector_concat (oResult, vector ('Contacts', oContacts));
    }
    if (not isnull (lcTags))
    {
      tmp := AB.WA.apiObject ();
      for (select p.* from AB.WA.dictionary2rs(p0)(tag varchar, IDs varchar) p where p0 = lcTags order by tag) do
      {
        A := deserialize (IDs);
        V := AB.WA.apiObject ();
        for (N := 0; N < length (A); N := N + 1)
          V := vector_concat (V, vector ('ContactID', A[N]));
        tmp := vector_concat (tmp, vector ('Tag', vector_concat (AB.WA.apiObject (), vector ('Name', tag, 'ContactIDs', V))));
      }
      if (length (tmp) > 2)
        oResult := vector_concat (oResult, vector ('Tags', tmp));
    }
    if (length (oResult) > 2)
      oResult := vector_concat (AB.WA.apiObject (), vector ('LiveContacts', oResult));
    http (AB.WA.obj2xml (oResult));
  }
  else if (apiMethod = 'DELETE')
  {
    delete from AB.WA.PERSONS where P_DOMAIN_ID = domain_id and P_ID = objectID;
    signal ('__204', '');
  }
  else if ((apiMethod = 'POST') or (apiMethod = 'PUT'))
  {
    -- Insert Contact ('POST'), Update Contact/Owner ('PUT')
    declare abID, abPath, abCheckPath, abTmpPath, abNeedAdded, abField, abFields, abValue, abValues any;

    if (length (objectBodyXPath) = 1)
    {
      abNeedAdded := 1;
      abPath := '/' || objectBodyXPath[0];
    } else {
      abNeedAdded := 0;
      abPath := '';
      abCheckPath := '';
      for (N := 1; N < length (objectBodyXPath); N := N + 1)
      {
        if (N <> length (objectBodyXPath)-1)
          abPath := abPath || '/' || objectBodyXPath[N];
        abCheckPath := abCheckPath || '/' || objectBodyXPath[N];
      }
    }
    xt := xtree_doc (apiBody);
    abID := -1;
    abFields := vector ();
    abValues := vector ();
    for (N := 0; N < length (apiMap); N := N + 2)
    {
      lcField := apiMap[N];
      lcFieldDef := apiMap[N+1];
      if (isnull (lcFieldDef))
        goto _next;
      abValue := null;
      abField := get_keyword ('field', lcFieldDef);
      if (isnull (abField))
        goto _next;
      lcXPath := get_keyword ('xpath', lcFieldDef);
      if (isNull (lcXPath))
        lcXPath := vector (lcField);
      tmp := null;
      for (M := 0; M < length (lcXPath); M := M + 1)
      {
        abTmpPath := replace (lcXPath[M], '.', '/');
        if (abNeedAdded)
        {
          tmp := cast (xquery_eval (abPath || '/' || abTmpPath, xt, 1) as varchar);
        } else {
          if (abTmpPath like (trim (abCheckPath, '/') || '%'))
          {
            abTmpPath := subseq (abTmpPath, length (abPath), length (abTmpPath));
            tmp := cast (xquery_eval (abTmpPath, xt, 1) as varchar);
          }
        }
        if (not is_empty_or_null (tmp))
          goto _exit_xpath;
      }
    _exit_xpath:;
      if (is_empty_or_null (tmp))
        goto _next;
      if (abField = 'P_BIRTHDAY')
      {
        tmp := AB.WA.dt_reformat (tmp, 'YMD');
        if (is_empty_or_null (tmp))
          goto _next;
      }
      if (not AB.WA.vector_contains (abFields, abField))
      {
        abFields := vector_concat (abFields, vector (abField));
        abValues := vector_concat (abValues, vector (tmp));
      }
    _next:;
    }
    if (apiMethod = 'PUT')
    {
      if (objectType = 'c')
      {
        AB.WA.contact_update4 (objectID, domain_id, abFields, abValues);
      } else {
        uname := AB.WA.domain_owner_name (domain_id);
        ocMap := AB.WA.vector_reverse (AB.WA.owner2contactMap ());
        for (N := 0; N < length (abFields); N := N + 1)
        {
          tmp := get_keyword (abFields[N], ocMap);
          if (not isnull (tmp))
            WA_USER_EDIT (uname, tmp, abValues[N]);
        }
      }
      signal ('__204', '');
    } else {
      abID := AB.WA.contact_update4 (abID, domain_id, abFields, abValues);
      signal ('__201', '');
    }
  }
  http_request_status ('HTTP/1.1 200 OK');
  return '';

}
;

grant execute on AB.WA.livecontacts to SOAP_ADDRESSBOOK
;

-----------------------------------------------------------------------------------------
--
-- Yahoo Conatacts API
--
----------------------------------------------------------------------------------------
create procedure AB.WA.yahooOutput (
  in data any,
  in options any)
{
  if (get_keyword ('format', options, 'xml') = 'xml')
  {
    http (AB.WA.obj2xml (data, 10, null, vector ('', 'http://social.yahooapis.com/v1/schema.rng', 'yahoo', 'http://www.yahooapis.com/v1/base.rng', 'ns', 'http://social.yahooapis.com/v1/schema.rng'), '@'));
  } else {
    http (ODS..obj2json (data, 10, vector ('yahoo', 'ns'), '@'));
  }
}
;

-----------------------------------------------------------------------------------------
--
create procedure AB.WA.yahooMap ()
{
  return vector ('id',            vector ('field', 'P_ID'),
                 'guid',          vector ('field', 'P_UID'),
                 'nickName',      vector ('field', 'P_NAME'),
                 'name',          vector ('field', vector ('title', 'P_TITLE', 'givenName', 'P_FIRST_NAME', 'middleName', 'P_MIDDLE_NAME', 'familyName', 'P_LAST_NAME')),
                 'birthday',      vector ('field', 'P_BIRTHDAY',  'function', 'select AB.WA.yahooDate (?)'),
                 'email',         vector ('field', 'P_MAIL'),
                 'phone',         vector ('field', 'P_PHONE'),
                 'address',       vector ('field', vector ('street', 'P_H_ADDRESS1', 'city', 'P_H_CITY', 'stateOrProvince', 'P_H_STATE', 'postalCode', 'P_H_CODE', 'country', 'P_H_COUNTRY')),
                 'company',       vector ('field', 'P_B_ORGANIZATION'),
                 'jobTitle',      vector ('field', 'P_B_JOB')
                );
}
;

-----------------------------------------------------------------------------------------
--
create procedure AB.WA.yahooDate (
  in aValue any)
{
  if (isnull (aValue))
    return null;

  return vector_concat (AB.WA.apiObject (), vector ('day', dayofmonth (aValue), 'month', month (aValue), 'year', year (aValue)));
}
;

-----------------------------------------------------------------------------------------
--
create procedure AB.WA.yahooContactField (
  in field varchar,
  in map varchar,
  in fields any := null)
{
  if (not isnull (fields) and not AB.WA.vector_contains (fields, field))
    return null;

  return get_keyword (field, map);
}
;

-----------------------------------------------------------------------------------------
--
create procedure AB.WA.yahooContactFieldIndex (
  in field varchar,
  in meta any)
{
  declare N integer;

  for (N := 0; N < length (meta); N := N + 1)
    if (field = meta[N])
      return N;

  return null;
}
;

-----------------------------------------------------------------------------------------
--
create procedure AB.WA.yahooContactValue2 (
  in abField varchar,
  inout data any,
  inout meta any)
{
  declare abFieldIndex any;

  abFieldIndex := AB.WA.yahooContactFieldIndex (abField, meta);
  if (not isnull (abFieldIndex))
    return data[abFieldIndex];
  return null;
}
;

-----------------------------------------------------------------------------------------
--
create procedure AB.WA.yahooContactValue (
  in field varchar,
  inout data any,
  inout meta any,
  inout map any)
{
  declare N integer;
  declare tmp, fieldDef any;
  declare abValue, abField, abFieldIndex any;

  abValue := null;
  fieldDef := AB.WA.yahooContactField (field, map);
  if (isnull (fieldDef))
    goto _skip;
  abField := get_keyword ('field', fieldDef);
  if (isnull (abField))
    goto _skip;

  if (isarray (abField) and not isstring (abField))
  {
    abValue := AB.WA.apiObject ();
    for (N := 0; N < length (abField); N := N + 2)
    {
      tmp := AB.WA.yahooContactValue2 (abField[N+1], data, meta);
      if (length (tmp))
        abValue := vector_concat (abValue, vector (abField[N], tmp));
    }
    if (length (abValue) = 2)
      abValue := null;
  } else {
    abValue := AB.WA.yahooContactValue2 (abField, data, meta);
    if (isnull (abValue))
      goto _skip;
    if (not isnull (get_keyword ('function', fieldDef)))
    {
      tmp := get_keyword ('function', fieldDef);
      if (not isnull (tmp))
      {
        tmp := AB.WA.exec (tmp, vector (abValue));
        if (length (tmp))
          abValue := tmp[0][0];
      }
    }
  }
_skip:;
  return abValue;
}
;

-----------------------------------------------------------------------------------------
--
create procedure AB.WA.yahooContactObject (
  inout fields any,
  inout data any,
  inout meta any,
  inout map any)
{
  declare N integer;
  declare oEntry any;
  declare F, C any;
  declare abValue, field any;

  oEntry := AB.WA.apiObject ();
  abValue := AB.WA.yahooContactValue ('id', data, meta, map);
  oEntry := vector_concat (oEntry, vector ('id', abValue));
  abValue := AB.WA.yahooContactValue ('guid', data, meta, map);
  oEntry := vector_concat (oEntry, vector ('guid', abValue));
  abValue := AB.WA.yahooContactValue2 ('P_CREATED', data, meta);
  if (not isnull (abValue))
    oEntry := vector_concat (oEntry, vector ('@yahoo:uri', AB.WA.dt_iso8601 (abValue)));
  abValue := AB.WA.yahooContactValue2 ('P_CREATED', data, meta);
  if (not isnull (abValue))
    oEntry := vector_concat (oEntry, vector ('@yahoo:created', date_iso8601 (dt_set_tz (abValue, 0))));
  abValue := AB.WA.yahooContactValue2 ('P_UPDATED', data, meta);
  if (not isnull (abValue))
    oEntry := vector_concat (oEntry, vector ('@yahoo:updated', date_iso8601 (dt_set_tz (abValue, 0))));

  -- fields
  F := vector ();
  for (N := 0; N < length (fields); N := N + 1)
  {
    field := trim (fields[N]);
    abValue := AB.WA.yahooContactValue (field, data, meta, map);
    if (is_empty_or_null (abValue))
      goto _skip;
    F := vector_concat (F, vector (vector_concat (AB.WA.apiObject(), vector ('type', field, 'value', abValue, 'flags', vector()))));

  _skip:;
  }
  oEntry := vector_concat (oEntry, vector ('fields', F));

  -- categories
  abValue := AB.WA.yahooContactValue2 ('C_ID', data, meta);
  if (not isnull (abValue))
  {
    C := AB.WA.apiObject();
    C := vector_concat (C, vector ('id', abValue));
    abValue := AB.WA.yahooContactValue2 ('C_NAME', data, meta);
    if (not isnull (abValue))
      C := vector_concat (C, vector ('name', abValue));
    oEntry := vector_concat (oEntry, vector ('categories', vector (C)));
  }

  if (length (oEntry) > 2)
    return oEntry;
  return null;
}
;

-----------------------------------------------------------------------------------------
--
create procedure AB.WA.yahooSQL (
  in sql varchar,
  in params any,
  inout options any,
  inout data any,
  inout meta any)
{
  declare N integer;
  declare st, msg, _data, _meta, _start, _count, _total, _min any;

  st := '00000';
  if (get_keyword ('_sqlFilter', options) <> '')
  {
    sql := sql || ' and ' || get_keyword ('_sqlFilter', options);
    params := vector_concat (params, get_keyword ('_sqlParams', options));
  }
  _start := atoi (get_keyword ('start', options, '0'));
  _count := atoi (get_keyword ('count', options, '10'));
  if (_count = 0)
    _count := 10;
  _min := _start + _count;
  sql := replace (sql, '%TOP%', cast (_min as varchar));

  exec (sql, st, msg, params, 0, _meta, _data);
  if ('00000' <> st)
    return 0;

  _total := 0;
  data := vector ();
  if (_min > length (_data))
    _min := length (_data);
  for (N := _start; N < _min; N := N + 1)
  {
    data := vector_concat (data, vector (_data[N]));
    _total := _total + 1;
  }
  meta := AB.WA.simplifyMeta (_meta);
  options := vector_concat (options, vector ('_start', _start));
  options := vector_concat (options, vector ('_count', _count));
  options := vector_concat (options, vector ('_total', _total));

  return 1;
}
;

-----------------------------------------------------------------------------------------
--
create procedure AB.WA.yahooPathAnalyze (
  in apiParams varchar,
  in apiPath varchar,
  in apiMethod varchar,
  in apiMap varchar,
  inout apiCommand varchar,
  inout apiOptions varchar)
{
  declare N, M integer;
  declare tmp, tmp2, tmp3, V, matrix, query, inverse, field, expression, apiExpressions, apiAction, apiActions, leftPath, rightPath any;
  declare sqlFilter, sqlParams any;

  apiActions := vector (
                        'contacts',           vector ('methods', vector ('GET', 'POST', 'PUT'),
                                                      'regex', '^contacts',
                                                      'query', vector ('format', 'view', 'start', 'count', 'rev'),
                                                      'matrix', vector ('start', 'count', 'bucket', 'maxbucketsize', 'minbucketcount', 'sort-fields', 'sort'),
                                                      'filter', 1
                                                     ),
                        'contactField',       vector ('methods', vector ('GET', 'DELETE'),
                                                      'regex', '^contact/([0-9]*)/(address|anniversary|birthday|company|custom|email|guid|jobTitle|link|name|nickname|notes|otherid|phone|yahooid)\$',
                                                      'inverse', 'contact/%d/%s',
                                                      'query', vector ('format'),
                                                      'sqlFilter', 'p.P_ID = ?'
                                                     ),
                        'contactFields',      vector ('methods', vector ('GET', 'POST'),
                                                      'regex', '^contact/([0-9]*)/(addresses|anniversaries|birthdays|companies|customFields|emails|guids|jobTitles|links|names|nicknames|notesFields|otherids|phones|yahooids)\$',
                                                      'inverse', 'contact/%d/%s',
                                                      'query', vector ('format'),
                                                      'sqlFilter', 'p.P_ID = ?'
                                                     ),
                        'categoriesByContact',vector ('methods', vector ('GET', 'POST'),
                                                      'regex', '^contact/([0-9]*)/categories',
                                                      'inverse', 'contact/%d/categories',
                                                      'query', vector ('format'),
                                                      'sqlFilter', 'p.P_ID = ?'
                                                     ),
                        'contact',            vector ('methods', vector ('GET', 'DELETE'),
                                                      'regex', '^contact/([0-9]*)',
                                                      'inverse', 'contact/%d',
                                                      'query', vector ('format'),
                                                      'sqlFilter', 'p.P_ID = ?'
                                                     ),
                        'categories',         vector ('methods', vector ('GET', 'POST'),
                                                      'regex', '^categories',
                                                      'query', vector ('format'),
                                                      'matrix', vector ('start', 'count')
                                                     ),
                        'contactsByCategory', vector ('methods', vector ('GET'),
                                                      'regex', '^category/([^/]*)/contacts',
                                                      'inverse', 'category/%s/contacts',
                                                      'query', vector ('format', 'bucketinfo'),
                                                      'matrix', vector ('start', 'count', 'bucket', 'maxbucketsize', 'minbucketcount'),
                                                      'sqlFilter', 'c.C_NAME = ?'
                                                     )
                        );

  apiExpressions := vector (
                            'is', 'cast (%FIELD% as varchar) = ?',
                            'startswith', 'cast (%FIELD% as varchar) like ?',
                            'contains', 'cast (%FIELD% as varchar) like ?',
                            'cs-is', 'ucase (cast (%FIELD% as varchar)) = ?',
                            'cs-startswith', 'ucase (cast (%FIELD% as varchar)) like ?',
                            'cs-contains', 'ucase (cast (%FIELD% as varchar)) like ?',
                            'present', '%FIELD% is %VALUE% null'
                           );

  for (N := 0; N < length (apiActions); N := N + 2)
  {
    apiCommand := apiActions[N];
    apiAction := apiActions[N+1];
    if (regexp_match (get_keyword ('regex', apiAction), apiPath))
    {
      if (not AB.WA.vector_contains (get_keyword ('methods', apiAction), apiMethod))
        signal ('__400', '');
      goto _correct;
    }
  }
  signal ('__400', '');

_correct:;
  apiOptions := vector ();
  query := get_keyword ('query', apiAction);
  for (N := 0; N < length (query); N := N + 1)
  {
    if (get_keyword (query[N], apiParams, '') <> '')
      apiOptions := vector_concat (apiOptions, vector (query[N], get_keyword (query[N], apiParams)));
  }

  leftPath := apiPath;
  rightPath := '';
  N := strstr (apiPath, ';');
  if (not isnull (N))
  {
    leftPath := subseq (apiPath, 0, N);
    rightPath := subseq (apiPath, N+1);
  }

  inverse := vector ();
  tmp := get_keyword ('inverse', apiAction);
  if (not isnull (tmp))
    inverse := sprintf_inverse (leftPath, tmp, 0);

  matrix := get_keyword ('matrix', apiAction);
  if (isnull (matrix) and rightPath <> '')
    signal ('__400', '');

  sqlFilter := get_keyword ('sqlFilter', apiAction, '');
  sqlParams := vector ();
  if (sqlFilter <> '')
  {
    sqlParams := vector_concat (sqlParams, subseq (inverse, 0, 1));
  }
  if (rightPath <> '')
  {
    tmp := split_and_decode (rightPath, 0, '\0\0;');
    for (N := 0; N < length (tmp); N := N + 1)
    {
      tmp2 := split_and_decode (tmp[N], 0, '\0\0=');
      if (length (tmp2) <> 2)
        signal ('__400', '');
      for (M := 0; M < length (matrix); M := M + 1)
      {
        if (matrix[M] = tmp2[0])
        {
          apiOptions := vector_concat (apiOptions, vector (tmp2[0], tmp2[1]));
          goto _skip;
        }
      }
      if (get_keyword ('filter', apiAction, 0) = 0)
        signal ('__400', '');
      tmp3 := split_and_decode (tmp2[0], 0, '\0\0.');
      if (length (tmp3) <> 2)
        signal ('__400', '');

      field := get_keyword (tmp3[0], apiMap);
      if (isnull (field))
        signal ('__400', '');

      expression := get_keyword (tmp3[1], apiExpressions);
      if (isnull (expression))
        signal ('__400', '');

      if (tmp3[0] like 'cs-%')
        tmp3[1] := ucase (tmp3[1]);

      if (tmp3[0] = 'present')
        tmp3[1] := case when tmp3[1] = '1' then 'NOT' else '' end;

      expression := replace (expression, '%FIELD%', 'p.'||get_keyword ('field', field));
      expression := replace (expression, '%VALUE%', tmp3[1]);

      if (sqlFilter <> '')
        sqlFilter := sqlFilter || ' and ';
      sqlFilter := sqlFilter || expression;
      if (tmp3[0] <> 'present')
        sqlParams := vector_concat (sqlParams, vector (tmp2[1]));

    _skip:;
    }
  }
  apiOptions := vector_concat (apiOptions, vector ('_inverse', inverse));
  apiOptions := vector_concat (apiOptions, vector ('_sqlFilter', sqlFilter));
  apiOptions := vector_concat (apiOptions, vector ('_sqlParams', sqlParams));
}
;

-----------------------------------------------------------------------------------------
--
create procedure AB.WA.yahoocontacts () __SOAP_HTTP 'text/xml'
{
  declare exit handler for sqlstate '*'
  {
    if (__SQL_STATE = '__201')
    {
      AB.WA.apiHTTPError ('HTTP/1.1 201 Creates');
    }
    else if (__SQL_STATE = '__204')
    {
      AB.WA.apiHTTPError ('HTTP/1.1 204 No Content');
    }
    else if (__SQL_STATE = '__400')
    {
      AB.WA.apiHTTPError ('HTTP/1.1 400 Bad Request');
    }
    else if (__SQL_STATE = '__401')
    {
      AB.WA.apiHTTPError ('HTTP/1.1 401 Unauthorized');
    }
    else if (__SQL_STATE = '__404')
    {
      AB.WA.apiHTTPError ('HTTP/1.1 404 Not Found');
    }
    else if (__SQL_STATE = '__406')
    {
      AB.WA.apiHTTPError ('HTTP/1.1 406 Requested representation not available for the resource');
    }
    else if (__SQL_STATE = '__500')
    {
      AB.WA.apiHTTPError ('HTTP/1.1 500 Not Found');
    }
    else if (__SQL_STATE = '__503')
    {
      AB.WA.apiHTTPError ('HTTP/1.1 503 Service Unavailable');
    }
    else
    {
      dbg_obj_princ (__SQL_STATE, __SQL_MESSAGE);
    }
    return null;
  };
  declare N, M, domain_id integer;
  declare xt any;
  declare tmp, uname, V, A, oResult, oCategories, oCategory, oContacts, oContact, oTag any;
  declare apiLines, apiPath, apiParams, apiMethod, apiBody any;
  declare apiMap, apiCommand, apiOptions, apiFields any;
  declare sql, st, msg, params, meta, data any;

  apiLines := http_request_header ();
  apiPath := http_path ();
  apiParams := http_param ();
  apiMethod := ucase (http_request_get ('REQUEST_METHOD'));
  apiBody := string_output_string (http_body_read ());
  if (apiBody = '')
    apiBody := get_keyword ('content', apiParams);

  domain_id := 22;
  domain_id := atoi (get_keyword_ucase ('inst_id', apiParams));
  if (not ODS..ods_check_auth (uname, domain_id, 'reader'))
    signal ('__401', '');

  if (not exists (select 1 from DB.DBA.WA_INSTANCE where WAI_ID = domain_id and WAI_TYPE_NAME = 'AddressBook'))
    signal ('__401', '');

  if (apiPath not like '/ods/yahoocontacts/%')
    signal ('__404', '');

  apiPath := substring (apiPath, length ('/ods/yahoocontacts/')+1, length (apiPath));
  apiMap := AB.WA.yahooMap();
  AB.WA.yahooPathAnalyze (apiParams, apiPath, apiMethod, apiMap, apiCommand, apiOptions);

  if (get_keyword ('view', apiOptions, '') = 'rev')
    signal ('__406', '');

  if (get_keyword ('view', apiOptions, '') = 'sync')
    signal ('__406', '');

  if (get_keyword ('view', apiOptions, '') = 'tinyusercard')
  {
    apiFields := 'nickName,name';
  } else {
    apiFields := get_keyword ('out', apiOptions, 'all');
    if (apiFields = 'all')
      apiFields := 'guid,nickName,name,birthday,email,phone,address,company,jobTitle';
  }
  apiFields := split_and_decode (apiFields, 0, '\0\0,');

  set_user_id ('dba');
  if (apiCommand = 'contacts')
  {
    if (apiMethod = 'GET')
    {
      if (AB.WA.yahooSQL ('select TOP %TOP% p.*, c.C_ID, c.C_NAME from AB.WA.PERSONS p left join AB.WA.CATEGORIES c on c.C_ID = p.P_CATEGORY_ID where p.P_DOMAIN_ID = ?', vector (domain_id), apiOptions, data, meta))
      {
      _contacts:
        oResult := AB.WA.apiObject();
        oContacts := vector_concat (AB.WA.apiObject(),
                                    vector (
                                            '@yahoo:start', get_keyword ('_start', apiOptions),
                                            '@yahoo:count', get_keyword ('_count', apiOptions),
                                            '@yahoo:total', get_keyword ('_total', apiOptions)
                                           )
                                   );
        V := vector ();
        for (N := 0; N < length (data); N := N + 1)
        {
          oContact := AB.WA.yahooContactObject(apiFields, data[N], meta, apiMap);
          V := vector_concat (V, vector (oContact));
        }
        oContacts := vector_concat (oContacts, vector ('contact', V));
        oResult := vector_concat (oResult, vector ('contacts', oContacts));
        AB.WA.yahooOutput (oResult, apiOptions);
      }
    }
    if (apiMethod in ('PUT', 'POST'))
    {
      declare field, fieldDef, apiXPath, tmpXPath any;
      declare abID, abField, abFields, abValues any;

      V := apiBody;
      if (get_keyword ('format', apiOptions, 'xml') = 'json')
        V := AB.WA.obj2xml (json_parse (V));

      V := xml_tree_doc (xml_tree (V));

      abID := -1;
      abFields := vector ();
      abValues := vector ();
      for (N := 0; N < length (apiMap); N := N + 2)
      {
        field := apiMap[N];
        fieldDef := apiMap[N+1];

        abField := get_keyword ('field', fieldDef);
        if (isnull (abField))
          goto _next;

        apiXPath := get_keyword ('xpath', fieldDef);
        if (isNull (apiXPath))
          apiXPath := sprintf ('/contact/fields[type = "%s"]/value', field);

        if (not (isarray (abField) and not isstring (abField)))
          abField := vector (null, abField);

        for (M := 0; M < length (abField); M := M + 2)
        {
          tmpXPath := apiXPath;
          if (not isnull (abField[M]))
            tmpXPath := tmpXPath || '/' || abField[M];
          tmp := trim (cast (xquery_eval (tmpXPath, V, 1) as varchar));

          if (is_empty_or_null (tmp))
            goto _next_xpath;

          if (abField = 'P_BIRTHDAY')
          {
            {
              declare continue handler for sqlstate '*'
              {
                tmp := null;
              };
              tmp := stringdate (tmp);
            }
          }
          if (not AB.WA.vector_contains (abFields, abField))
          {
            abFields := vector_concat (abFields, vector (abField[M+1]));
            abValues := vector_concat (abValues, vector (tmp));
          }
          if (abField = 'P_ID')
            abID := tmp;
        _next_xpath:;
        }
      _next:;
      }
      if ((apiMethod = 'PUT') and not exists (select 1 from AB.WA.PERSONS where P_ID = abID and P_DOMAIN_ID = domain_id))
        signal ('__404', '');

      abID := AB.WA.contact_update4 (abID, domain_id, abFields, abValues);
    }
  }
  if (apiCommand = 'contact')
  {
    if (apiMethod = 'GET')
    {
      if (AB.WA.yahooSQL ('select TOP %TOP% p.*, c.C_ID, c.C_NAME from AB.WA.PERSONS p left join AB.WA.CATEGORIES c on c.C_ID = p.P_CATEGORY_ID where p.P_DOMAIN_ID = ?', vector (domain_id), apiOptions, data, meta))
      {
        if (length (data) = 0)
          signal ('__406', '');

        oResult := AB.WA.apiObject();
        oContact := AB.WA.yahooContactObject(apiFields, data[0], meta, apiMap);
        oResult := vector_concat (oResult, vector ('contact', oContact));
        AB.WA.yahooOutput (oResult, apiOptions);
      }
    }
    if (apiMethod = 'DELETE')
    {
      V := get_keyword ('_sqlParams', apiOptions);
      if (length (V) = 0)
        signal ('__404', '');

      AB.WA.contact_delete (V[0], domain_id);
    }
  }
  else if (apiCommand = 'contactField')
  {
    tmp := get_keyword ('_inverse', apiOptions)[1];
    if (apiMethod = 'GET')
    {
    _contactField:
      if (AB.WA.yahooSQL ('select TOP %TOP% p.* from AB.WA.PERSONS p where p.P_DOMAIN_ID = ?', vector (domain_id), apiOptions, data, meta))
      {
        declare abValue any;

        if (length (data) = 0)
          signal ('__406', '');

        oResult := AB.WA.apiObject();
        abValue := AB.WA.yahooContactValue (tmp, data[0], meta, apiMap);
        if (not is_empty_or_null (abValue))
          oResult := vector_concat (oResult, vector (tmp, vector_concat (AB.WA.apiObject(), vector ('type', tmp, 'value', abValue, 'flags', vector()))));
        AB.WA.yahooOutput (oResult, apiOptions);
      }
    }
    if (apiMethod = 'DELETE')
    {
      declare abID, abField, field, fieldDef any;

      abID := get_keyword ('_inverse', apiOptions)[0];
      field := get_keyword ('_inverse', apiOptions)[1];
      fieldDef := get_keyword (field, apiMap);
      if (not isnull (fieldDef))
      {
        abField := get_keyword ('field', fieldDef);
        if (not isnull (abField))
        {
          if (not (isarray (abField) and not isstring (abField)))
            abField := vector (null, abField);

          for (M := 0; M < length (abField); M := M + 2)
          {
            AB.WA.contact_update2 (abID, domain_id, abField[M+1], null);
          }
        }
      }
    }
  }
  else if (apiCommand = 'contactFields')
  {
    tmp := get_keyword ('_inverse', apiOptions)[1];
    V := vector (
                 'addresses',    'address',
                 'anniversaries','anniversary',
                 'birthdays',    'birthday',
                 'companies',    'company',
                 'customFields', 'custom',
                 'emails',       'email',
                 'guids',        'guid',
                 'jobTitles',    'jobTitle',
                 'links',        'link',
                 'names',        'name',
                 'nicknames',    'nickname',
                 'notesFields',  'notes',
                 'otherids',     'otherid',
                 'phones',       'phone',
                 'yahooids',     'yahooid'
                );
    tmp := get_keyword (tmp, V);
    if (apiMethod = 'GET')
    {
      goto _contactField;
    }
    if (apiMethod = 'POST')
    {
      ;
    }
  }
  else if (apiCommand = 'contactsByCategory')
  {
    -- GET only
    if (AB.WA.yahooSQL ('select TOP %TOP% p.*, c.C_ID, c.C_NAME from AB.WA.PERSONS p, AB.WA.CATEGORIES c where p.P_DOMAIN_ID = ? and c.C_ID = p.P_CATEGORY_ID', vector (domain_id), apiOptions, data, meta))
      goto _contacts;
  }
  else if (apiCommand = 'categories')
  {
    if (apiMethod = 'GET')
    {
      if (AB.WA.yahooSQL ('select TOP %TOP% c.C_ID, c.C_NAME from AB.WA.CATEGORIES c where c.C_DOMAIN_ID = ?', vector (domain_id), apiOptions, data, meta))
      {
      _categories:
        oResult := AB.WA.apiObject();
        oCategories := vector_concat (AB.WA.apiObject(),
                                      vector (
                                              '@yahoo:start', get_keyword ('_start', apiOptions),
                                              '@yahoo:count', get_keyword ('_count', apiOptions),
                                              '@yahoo:total', get_keyword ('_total', apiOptions)
                                             )
                                     );
        V := vector ();
        for (N := 0; N < length (data); N := N + 1)
        {
          oCategory := vector_concat (AB.WA.apiObject(), vector ('id', data[N][0], 'name', data[N][1]));
          V := vector_concat (V, vector (oCategory));
        }
        oCategories := vector_concat (oCategories, vector ('category', V));
        oResult := vector_concat (oResult, vector ('categories', oCategories));
        AB.WA.yahooOutput (oResult, apiOptions);
      }
    }
    if (apiMethod = 'POST')
    {
      declare name any;

      V := apiBody;
      if (get_keyword ('format', apiOptions, 'json') = 'json')
        V := AB.WA.obj2xml (json_parse (V));

      V := xml_tree_doc (xml_tree (V));
      name := cast (xpath_eval('//name', V) as varchar);
      AB.WA.category_update (domain_id, name);
    }
  }
  else if (apiCommand = 'categoriesByContact')
  {
    if (apiMethod = 'GET')
    {
      if (AB.WA.yahooSQL ('select TOP %TOP% c.C_ID, c.C_NAME from AB.WA.CATEGORIES c, AB.WA.PERSONS p where c.C_DOMAIN_ID = ? and c.C_ID = p.P_CATEGORY_ID', vector (domain_id), apiOptions, data, meta))
        goto _categories;
    }
    if (apiMethod = 'POST')
    {
      declare category_id, name any;

      V := apiBody;
      if (get_keyword ('format', apiOptions, 'json') = 'json')
        V := AB.WA.obj2xml (json_parse (V));

      V := xml_tree_doc (xml_tree (V));
      name := cast (xpath_eval('//name', V) as varchar);
      category_id := AB.WA.category_update (domain_id, name);

      V := get_keyword ('_sqlParams', apiOptions);
      if (length (V) = 0)
        signal ('__404', '');

      AB.WA.contact_update2 (V[0], domain_id, 'P_CATEGORY_ID', category_id);
    }
  }

  http_request_status ('HTTP/1.1 200 OK');
  return '';
}
;

grant execute on AB.WA.yahoocontacts to SOAP_ADDRESSBOOK
;

-----------------------------------------------------------------------------------------
--
-- Google Conatacts API
--
----------------------------------------------------------------------------------------
create procedure AB.WA.googleOutput (
  in data any,
  in options any)
{
  if (get_keyword ('out', options, 'atom') = 'atom')
  {
    http (AB.WA.obj2xml (
                         data,
                         10,
                         null,
                         vector ('',           'http://www.w3.org/2005/Atom',
                                 'openSearch', 'http://a9.com/-/spec/opensearch/1.1/',
                                 'gContact',   'http://schemas.google.com/contact/2008',
                                 'batch',      'http://schemas.google.com/gdata/batch',
                                 'gd',         'http://schemas.google.com/g/2005'
                                ),
                         '@')
                        );
  }
  else if (get_keyword ('out', options) = 'json')
  {
    http (ODS..obj2json (
                         data,
                         10,
                         vector ('openSearch', 'http://a9.com/-/spec/opensearch/1.1/',
                                 'gContact',   'http://schemas.google.com/contact/2008',
                                 'batch',      'http://schemas.google.com/gdata/batch',
                                 'gd',         'http://schemas.google.com/g/2005'
                                ),
                         '@')
                        );
  }
}
;

-----------------------------------------------------------------------------------------
--
create procedure AB.WA.googleMap ()
{
  return vector (
                 'id',                                        vector ('field', 'P_ID'),
                 '@gd:etag',                                  vector ('field', 'P_UID', 'xpath', '@gd:etag'),
                 'published',                                 vector ('field', 'P_CREATED', 'function', 'select date_iso8601 (dt_set_tz (?, 0))'),
                 'updated',                                   vector ('field', 'P_UPDATED', 'function', 'select date_iso8601 (dt_set_tz (?, 0))'),
                 'title',                                     vector ('field', 'P_NAME'),
                 'gd:name/gd:givenName',                      vector ('field', 'P_FIRST_NAME'),
                 'gd:name/gd:familyName',                     vector ('field', 'P_LAST_NAME'),
                 'gd:name/gd:fullName',                       vector ('field', 'P_FULL_NAME'),
                 'gd:email',                                  vector ('field', 'P_MAIL', 'xpath', 'gd:email[@rel = "http://schemas.google.com/g/2005#other"]/@address', 'template', vector_concat (AB.WA.apiObject (), vector ('@rel', 'http://schemas.google.com/g/2005#other', '@primary', 'true')), 'value', '@address'),
                 'gd:email[2]',                               vector ('field', 'P_H_MAIL', 'xpath', 'gd:email[@rel = "http://schemas.google.com/g/2005#home"]/@address', 'template', vector_concat (AB.WA.apiObject (), vector ('@rel', 'http://schemas.google.com/g/2005#home')), 'value', '@address'),
                 'gd:email[3]',                               vector ('field', 'P_B_MAIL', 'xpath', 'gd:email[@rel = "http://schemas.google.com/g/2005#work"]/@address', 'template', vector_concat (AB.WA.apiObject (), vector ('@rel', 'http://schemas.google.com/g/2005#work')), 'value', '@address'),
                 'gd:phoneNumber',                            vector ('field', 'P_PHONE', 'xpath', 'gd:phoneNumber[@rel = "http://schemas.google.com/g/2005#other"]', 'template', vector_concat (AB.WA.apiObject (), vector ('@rel', 'http://schemas.google.com/g/2005#other', '@primary', 'true'))),
                 'gd:phoneNumber[2]',                         vector ('field', 'P_H_PHONE', 'xpath', 'gd:phoneNumber[@rel = "http://schemas.google.com/g/2005#home"]', 'template', vector_concat (AB.WA.apiObject (), vector ('@rel', 'http://schemas.google.com/g/2005#home'))),
                 'gd:phoneNumber[3]',                         vector ('field', 'P_B_PHONE', 'xpath', 'gd:phoneNumber[@rel = "http://schemas.google.com/g/2005#work"]', 'template', vector_concat (AB.WA.apiObject (), vector ('@rel', 'http://schemas.google.com/g/2005#work'))),
                 'gd:im',                                     vector ('field', 'P_ICQ', 'xpath', 'gd:im[@protocol = "http://schemas.google.com/g/2005#ICQ" and @rel = "http://schemas.google.com/g/2005#home"]/@address', 'template', vector_concat (AB.WA.apiObject (), vector ('@rel', 'http://schemas.google.com/g/2005#home', '@protocol', 'http://schemas.google.com/g/2005#ICQ')), 'value', '@address'),
                 'gd:im[2]',                                  vector ('field', 'P_SKYPE', 'xpath', 'gd:im[@protocol = "http://schemas.google.com/g/2005#SKYPE" and @rel = "http://schemas.google.com/g/2005#home"]/@address', 'template', vector_concat (AB.WA.apiObject (), vector ('@rel', 'http://schemas.google.com/g/2005#home', '@protocol', 'http://schemas.google.com/g/2005#SKYPE')), 'value', '@address'),
                 'gd:im[3]',                                  vector ('field', 'P_AIM', 'xpath', 'gd:im[@protocol = "http://schemas.google.com/g/2005#AIM" and @rel = "http://schemas.google.com/g/2005#home"]/@address', 'template', vector_concat (AB.WA.apiObject (), vector ('@rel', 'http://schemas.google.com/g/2005#home', '@protocol', 'http://schemas.google.com/g/2005#AIM')), 'value', '@address'),
                 'gd:im[4]',                                  vector ('field', 'P_YAHOO', 'xpath', 'gd:im[@protocol = "http://schemas.google.com/g/2005#YAHOO" and @rel = "http://schemas.google.com/g/2005#home"]/@address', 'template', vector_concat (AB.WA.apiObject (), vector ('@rel', 'http://schemas.google.com/g/2005#home', '@protocol', 'http://schemas.google.com/g/2005#YAHOO')), 'value', '@address'),
                 'gd:im[5]',                                  vector ('field', 'P_MSN', 'xpath', 'gd:im[@protocol = "http://schemas.google.com/g/2005#MSN" and @rel = "http://schemas.google.com/g/2005#home"]/@address', 'template', vector_concat (AB.WA.apiObject (), vector ('@rel', 'http://schemas.google.com/g/2005#home', '@protocol', 'http://schemas.google.com/g/2005#MSN')), 'value', '@address'),
                 'gd:structuredPostalAddress/gd:city',        vector ('field', 'P_H_CITY', 'xpath', 'gd:structuredPostalAddress[@rel = "http://schemas.google.com/g/2005#home"]/gd:city', 'template', vector_concat (AB.WA.apiObject (), vector ('@rel', 'http://schemas.google.com/g/2005#home', '@primary', 'true'))),
                 'gd:structuredPostalAddress/gd:street',      vector ('field', 'P_H_ADDRESS1', 'xpath', 'gd:structuredPostalAddress[@rel = "http://schemas.google.com/g/2005#home"]/gd:street', 'template', vector_concat (AB.WA.apiObject (), vector ('@rel', 'http://schemas.google.com/g/2005#home', '@primary', 'true'))),
                 'gd:structuredPostalAddress/gd:region',      vector ('field', 'P_H_STATE', 'xpath', 'gd:structuredPostalAddress[@rel = "http://schemas.google.com/g/2005#home"]/gd:region', 'template', vector_concat (AB.WA.apiObject (), vector ('@rel', 'http://schemas.google.com/g/2005#home', '@primary', 'true'))),
                 'gd:structuredPostalAddress/gd:postcode',    vector ('field', 'P_H_CODE', 'xpath', 'gd:structuredPostalAddress[@rel = "http://schemas.google.com/g/2005#home"]/gd:postcode', 'template', vector_concat (AB.WA.apiObject (), vector ('@rel', 'http://schemas.google.com/g/2005#home', '@primary', 'true'))),
                 'gd:structuredPostalAddress/gd:country',     vector ('field', 'P_H_COUNTRY', 'xpath', 'gd:structuredPostalAddress[@rel = "http://schemas.google.com/g/2005#home"]/gd:country', 'template', vector_concat (AB.WA.apiObject (), vector ('@rel', 'http://schemas.google.com/g/2005#home', '@primary', 'true'))),
                 'gd:structuredPostalAddress/gd:city[2]',     vector ('field', 'P_B_CITY', 'xpath', 'gd:structuredPostalAddress[@rel = "http://schemas.google.com/g/2005#work"]/gd:city', 'template', vector_concat (AB.WA.apiObject (), vector ('@rel', 'http://schemas.google.com/g/2005#work'))),
                 'gd:structuredPostalAddress/gd:street[2]',   vector ('field', 'P_B_ADDRESS1', 'xpath', 'gd:structuredPostalAddress[@rel = "http://schemas.google.com/g/2005#work"]/gd:street', 'template', vector_concat (AB.WA.apiObject (), vector ('@rel', 'http://schemas.google.com/g/2005#work'))),
                 'gd:structuredPostalAddress/gd:region[2]',   vector ('field', 'P_B_STATE', 'xpath', 'gd:structuredPostalAddress[@rel = "http://schemas.google.com/g/2005#work"]/gd:region', 'template', vector_concat (AB.WA.apiObject (), vector ('@rel', 'http://schemas.google.com/g/2005#work'))),
                 'gd:structuredPostalAddress/gd:postcode[2]', vector ('field', 'P_B_CODE', 'xpath', 'gd:structuredPostalAddress[@rel = "http://schemas.google.com/g/2005#work"]/gd:postcode', 'template', vector_concat (AB.WA.apiObject (), vector ('@rel', 'http://schemas.google.com/g/2005#work'))),
                 'gd:structuredPostalAddress/gd:country[2]',  vector ('field', 'P_B_COUNTRY', 'xpath', 'gd:structuredPostalAddress[@rel = "http://schemas.google.com/g/2005#work"]/gd:country', 'template', vector_concat (AB.WA.apiObject (), vector ('@rel', 'http://schemas.google.com/g/2005#work'))),
                 'gd:organization/gd:orgName',                vector ('field', 'P_B_ORGANIZATION', 'template', vector_concat (AB.WA.apiObject (), vector ('@rel', 'http://schemas.google.com/g/2005#work', '@label', 'Work', '@primary', 'true')))
                );
}
;

-----------------------------------------------------------------------------------------
--
create procedure AB.WA.googleContactField (
  in field varchar,
  in map varchar,
  in fields any := null)
{
  if (not isnull (fields) and not AB.WA.vector_contains (fields, field))
    return null;

  return get_keyword (field, map);
}
;

-----------------------------------------------------------------------------------------
--
create procedure AB.WA.googleContactFieldIndex (
  in field varchar,
  in meta any)
{
  declare N integer;

  for (N := 0; N < length (meta); N := N + 1)
    if (field = meta[N])
      return N;

  return null;
}
;

-----------------------------------------------------------------------------------------
--
create procedure AB.WA.googleContactValue (
  in field varchar,
  inout data any,
  inout meta any,
  inout map any)
{
  declare N integer;
  declare tmp, fieldDef any;
  declare abValue, abField, abFieldIndex any;

  abValue := null;
  fieldDef := AB.WA.googleContactField (field, map);
  if (isnull (fieldDef))
    goto _skip;
  abField := get_keyword ('field', fieldDef);
  if (isnull (abField))
    goto _skip;

  abValue := AB.WA.googleContactValue2 (abField, data, meta);
  if (isnull (abValue))
    goto _skip;
  if (not isnull (get_keyword ('function', fieldDef)))
  {
    tmp := get_keyword ('function', fieldDef);
    if (not isnull (tmp))
    {
      tmp := AB.WA.exec (tmp, vector (abValue));
      if (length (tmp))
        abValue := tmp[0][0];
    }
  }

_skip:;
  return abValue;
}
;

-----------------------------------------------------------------------------------------
--
create procedure AB.WA.googleContactValue2 (
  in abField varchar,
  inout data any,
  inout meta any)
{
  declare abFieldIndex any;

  abFieldIndex := AB.WA.googleContactFieldIndex (abField, meta);
  if (not isnull (abFieldIndex))
    return data[abFieldIndex];
  return null;
}
;

-----------------------------------------------------------------------------------------
--
create procedure AB.WA.googleContactProperty (
  in property varchar,
  in oEntry any,
  in template any := null,
  in mode integer := 1)
{
  declare N, M integer;

  for (N := 0; N < length (oEntry); N := N + 2)
  {
    if (oEntry[N] = property)
    {
      if (not (isnull (template) or (isstring (oEntry[N+1]) and not isarray (oEntry[N+1]))))
      {
        for (M := 0; M < length (template); M := M + 2)
        {
          if (get_keyword (template[M], oEntry[N+1]) <> template[M+1])
            goto _skip;
        }
      }
      if (mode)
        return oEntry[N+1];
      return N+1;
    }
  _skip:;
  }
  return null;
}
;

-----------------------------------------------------------------------------------------
--
create procedure AB.WA.googleFeedObject (
  inout oFeed any,
  inout domain_id integer,
  inout options any)
{
  declare owner_id, V any;

  oFeed := vector_concat (oFeed, vector ('id', AB.WA.domain_name (domain_id)));
  oFeed := vector_concat (oFeed, vector ('title', AB.WA.domain_description (domain_id)));
  V := vector_concat (AB.WA.apiObject(), vector ('@scheme', 'http://schemas.google.com/g/2005#kind', '@term', 'http://schemas.google.com/contact/2008#group'));
  oFeed := vector_concat (oFeed, vector ('category', V));
  owner_id := AB.WA.domain_owner_id (domain_id);
  V := vector_concat (AB.WA.apiObject(), vector ('name', AB.WA.account_name (owner_id), 'email', AB.WA.account_mail (owner_id)));
  oFeed := vector_concat (oFeed, vector ('author', V));
  oFeed := vector_concat (oFeed, vector ('@openSearch:startIndex', get_keyword ('_start', options)));
  oFeed := vector_concat (oFeed, vector ('@openSearch:itemsPerPage', get_keyword ('_count', options)));
  oFeed := vector_concat (oFeed, vector ('@openSearch:totalResults', get_keyword ('_total', options)));
}
;

-----------------------------------------------------------------------------------------
--
create procedure AB.WA.googleContactObject (
  in fields any,
  inout data any,
  inout meta any,
  inout map any)
{
  declare N, L integer;
  declare oEntry any;
  declare V, T any;
  declare abValue, field, fieldDef, template any;

  oEntry := AB.WA.apiObject ();
  fields := split_and_decode (fields, 0, '\0\0,');
  for (N := 0; N < length (fields); N := N + 1)
  {
    field := fields[N];
    abValue := AB.WA.googleContactValue (field, data, meta, map);
    if (is_empty_or_null (abValue))
      goto _skip;

    fieldDef := AB.WA.googleContactField (field, map);
    L := strchr (field, '[');
    if (not isnull (L))
      field := subseq (field, 0, L);

    if (isnull (strchr (field, '/')))
    {
      template := get_keyword ('template', fieldDef);
      if (isnull (template))
      {
        oEntry := vector_concat (oEntry, vector (field, abValue));
      } else {
        V := get_keyword ('value', fieldDef, '@value');
        template := vector_concat (template, vector (V, abValue));
        oEntry := vector_concat (oEntry, vector (field, template));
      }
    }
    else
    {
      template := get_keyword ('template', fieldDef, AB.WA.apiObject ());
      V := split_and_decode (field, 0, '\0\0/');
      if (length (V) <> 2)
        goto _skip;

      if (isnull (AB.WA.googleContactProperty (V[0], oEntry, template)))
        oEntry := vector_concat (oEntry, vector (V[0], template));

      T := AB.WA.googleContactProperty (V[0], oEntry, template);
      T := AB.WA.set_keyword (V[1], T, abValue);
      L := AB.WA.googleContactProperty (V[0], oEntry, template, 0);
      oEntry[L] := T;
    }

  _skip:;
  }
  if (length (oEntry) > 2)
    return oEntry;
  return null;
}
;

-----------------------------------------------------------------------------------------
--
create procedure AB.WA.googleGroupObject (
  inout data any,
  inout meta any)
{
  declare N, tmp, oEntry any;

  oEntry := AB.WA.apiObject ();

  N := AB.WA.vector_index (meta, 'C_ID');
  if (not isnull (N) and not isnull (data[N]))
    oEntry := vector_concat (oEntry, vector ('id', data[N]));
  N := AB.WA.vector_index (meta, 'C_NAME');
  if (not isnull (N) and not isnull (data[N]))
    oEntry := vector_concat (oEntry, vector ('title', data[N]));
  N := AB.WA.vector_index (meta, 'C_NAME');
  if (not isnull (N) and not isnull (data[N]))
    oEntry := vector_concat (oEntry, vector ('content', data[N]));

  if (length (oEntry) > 2)
    return oEntry;
  return null;
}
;

-----------------------------------------------------------------------------------------
--
create procedure AB.WA.googleSQL (
  in sql varchar,
  in params any,
  inout options any,
  inout data any,
  inout meta any)
{
  declare N integer;
  declare st, msg, _data, _meta, _start, _count, _total, _min any;

  st := '00000';
  if (get_keyword ('updated-min', options) <> '')
  {
    sql := sql || ' and P_UPDATED > ?';
    params := vector_concat (params, get_keyword ('updated-min', options));
  }
  if (get_keyword ('orderby', options) <> '')
  {
    sql := sql || ' order by P_UPDATED';
    if (get_keyword ('sortorder', options) = 'descending')
      sql := sql || ' desc';
  }
  _start := atoi (get_keyword ('start-index', options, '0'));
  _count := atoi (get_keyword ('max-results', options, '25'));
  if (_count = 0)
    _count := 25;
  _min := _start + _count;
  sql := replace (sql, '%TOP%', cast (_min as varchar));

  exec (sql, st, msg, params, 0, _meta, _data);
  if ('00000' <> st)
    return 0;

  _total := 0;
  data := vector ();
  if (_min > length (_data))
    _min := length (_data);
  for (N := _start; N < _min; N := N + 1)
  {
    data := vector_concat (data, vector (_data[N]));
    _total := _total + 1;
  }
  meta := AB.WA.simplifyMeta (_meta);
  options := vector_concat (options, vector ('_start', _start));
  options := vector_concat (options, vector ('_count', _count));
  options := vector_concat (options, vector ('_total', _total));

  return 1;
}
;

-----------------------------------------------------------------------------------------
--
create procedure AB.WA.googlePathAnalyze (
  in apiParams varchar,
  in apiPath varchar,
  in apiMethod varchar,
  inout apiMap any,
  inout apiCommand varchar,
  inout apiOptions any)
{
  apiMap := AB.WA.googleMap ();
  apiOptions := vector ();
}
;

-----------------------------------------------------------------------------------------
--
create procedure AB.WA.googlecontacts () __SOAP_HTTP 'text/xml'
{
  declare exit handler for sqlstate '*'
  {
    if (__SQL_STATE = '__201')
    {
      AB.WA.apiHTTPError ('HTTP/1.1 201 Creates');
    }
    else if (__SQL_STATE = '__204')
    {
      AB.WA.apiHTTPError ('HTTP/1.1 204 No Content');
    }
    else if (__SQL_STATE = '__400')
    {
      AB.WA.apiHTTPError ('HTTP/1.1 400 Bad Request');
    }
    else if (__SQL_STATE = '__401')
    {
      AB.WA.apiHTTPError ('HTTP/1.1 401 Unauthorized');
    }
    else if (__SQL_STATE = '__404')
    {
      AB.WA.apiHTTPError ('HTTP/1.1 404 Not Found');
    }
    else if (__SQL_STATE = '__406')
    {
      AB.WA.apiHTTPError ('HTTP/1.1 406 Requested representation not available for the resource');
    }
    else if (__SQL_STATE = '__500')
    {
      AB.WA.apiHTTPError ('HTTP/1.1 500 Not Found');
    }
    else if (__SQL_STATE = '__503')
    {
      AB.WA.apiHTTPError ('HTTP/1.1 503 Service Unavailable');
    }
    else
    {
      dbg_obj_princ (__SQL_STATE, __SQL_MESSAGE);
    }
    return null;
  };
  declare N, M, domain_id integer;
  declare domain_mode, xt any;
  declare tmp, uname, V, A, oResult, oFeed, oGroups, oGroup, oContacts, oContact, oTag any;
  declare apiLines, apiPath, apiParams, apiMethod, apiBody any;
  declare apiMap, apiCommand, apiOptions, apiFields any;
  declare params, meta, data any;

  apiLines := http_request_header ();
  apiPath := http_path ();
  apiParams := http_param ();
  apiMethod := ucase (http_request_get ('REQUEST_METHOD'));
  --if (apiMethod <> 'application/atom+xml')
  --  signal ('__404', '');
  apiBody := string_output_string (http_body_read ());
  if (apiBody = '')
    apiBody := get_keyword ('content', apiParams);

  V := sprintf_inverse (apiPath, '/ods/google/%s/%d/full', 0);
  if (isnull (V) or (length (V) <> 2))
    signal ('__404', '');
  domain_mode := V[0];
  domain_id := V[1];

  if (not ODS..ods_check_auth (uname, domain_id, 'reader'))
    signal ('__401', '');

  if (not exists (select 1 from DB.DBA.WA_INSTANCE where WAI_ID = domain_id and WAI_TYPE_NAME = 'AddressBook'))
    signal ('__401', '');

  AB.WA.googlePathAnalyze (apiParams, apiPath, apiMethod, apiMap, apiCommand, apiOptions);
  if (domain_mode = 'contacts')
  {
    apiFields := '';
    for (N := 0; N < length (apiMap); N := N + 2)
      apiFields := apiFields || apiMap[N] || ',';
    apiFields := trim (apiFields, ',');

    set_user_id ('dba');
    if (apiMethod = 'GET')
    {
      -- retrieve

      oResult := AB.WA.apiObject();
      oFeed := AB.WA.apiObject();
      if (AB.WA.googleSQL ('select TOP %TOP% p.* from AB.WA.PERSONS p where p.P_DOMAIN_ID = ?', vector (domain_id), apiOptions, data, meta))
      {
        for (N := 0; N < length (data); N := N + 1)
        {
          oContact := AB.WA.googleContactObject(apiFields, data[N], meta, apiMap);
          oFeed := vector_concat (oFeed, vector ('entry', oContact));
        }
      }
      AB.WA.googleFeedObject (oFeed, domain_id, apiOptions);
      oResult := vector_concat (oResult, vector ('feed', oFeed));
      AB.WA.googleOutput (oResult, apiParams);
    }
    else if ((apiMethod = 'POST') or (apiMethod = 'PUT'))
    {
      -- Insert Contact ('POST'), Update Contact ('PUT')
      declare field, fieldDef, objectID, abPath, abField, abFields, abValue, abValues any;

      xt := xtree_doc (apiBody);
      objectID := -1;
      abFields := vector ();
      abValues := vector ();
      for (N := 0; N < length (apiMap); N := N + 2)
      {
        field := apiMap[N];
        fieldDef := apiMap[N+1];
        if (isnull (fieldDef))
          goto _next;

        abValue := null;
        abField := get_keyword ('field', fieldDef);
        if (isnull (abField))
          goto _next;

        abPath := get_keyword ('xpath', fieldDef);
        if (isNull (abPath))
          abPath := field;

        tmp := cast (xpath_eval ('[ xmlns:atom="http://www.w3.org/2005/Atom" xmlns:gd="http://schemas.google.com/g/2005" ] /atom:entry/' || abPath, xt, 1) as varchar);
        if (is_empty_or_null (tmp))
          goto _next;

        if (abField = 'P_BIRTHDAY')
        {
          tmp := AB.WA.dt_reformat (tmp, 'YMD');
          if (is_empty_or_null (tmp))
            goto _next;
        }
        if (not AB.WA.vector_contains (abFields, abField))
        {
          abFields := vector_concat (abFields, vector (abField));
          abValues := vector_concat (abValues, vector (tmp));
        }
      _next:;
      }
      M := AB.WA.vector_index (abFields, 'P_NAME');
      if (isnull (M))
      {
        V := vector ('P_TITLE', 'P_FULL_NAME', 'P_FIRST_NAME', 'P_MIDDLE_NAME', 'P_LAST_NAME');
        for (N := 0; N < length (V); N := N + 1)
        {
          M := AB.WA.vector_index (abFields, V[N]);
          if (not isnull (M))
          {
            abFields := vector_concat (abFields, vector ('P_NAME'));
            abValues := vector_concat (abValues, vector (abValues[M]));
            goto _exit;
          }
        }
      _exit:;
      }
      if (apiMethod = 'PUT')
      {
        M := AB.WA.vector_index (abFields, 'P_UID');
        if (isnull (M))
          signal ('__404', '');
        objectID := (select P_ID from AB.WA.PERSONS where P_UID = abValues[M] and P_DOMAIN_ID = domain_id);
        if (isnull (objectID))
          signal ('__404', '');
        AB.WA.contact_update4 (objectID, domain_id, abFields, abValues);
      } else {
        objectID := AB.WA.contact_update4 (objectID, domain_id, abFields, abValues);
        if (isarray (objectID) and length (objectID) = 1)
          objectID := objectID[0];
      }
      oFeed := AB.WA.apiObject();
      if (AB.WA.googleSQL ('select p.* from AB.WA.PERSONS p where p.P_DOMAIN_ID = ? and p.P_ID = ?', vector (domain_id, objectID), vector(), data, meta))
      {
        if (length (data) = 1)
        {
          oContact := AB.WA.googleContactObject(apiFields, data[0], meta, apiMap);
          oFeed := vector_concat (oFeed, vector ('entry', oContact));
        }
      }
      AB.WA.googleOutput (oFeed, apiParams);
    }
    else if (apiMethod = 'DELETE')
    {
      -- Delete Contact ('DELETE')
      declare field, fieldDef, objectID, abPath, abField, abValue any;

      xt := xtree_doc (apiBody);
      field := '@gd:etag';
      fieldDef := get_keyword (field, apiMap);
      if (isnull (fieldDef))
        signal ('__404', '');

      abValue := null;
      abField := get_keyword ('field', fieldDef);
      if (isnull (abField))
        signal ('__404', '');

      abPath := get_keyword ('xpath', fieldDef);
      if (isNull (abPath))
        abPath := field;

      tmp := cast (xpath_eval ('[ xmlns:atom="http://www.w3.org/2005/Atom" xmlns:gd="http://schemas.google.com/g/2005" ] /atom:entry/' || abPath, xt, 1) as varchar);
      if (is_empty_or_null (tmp))
        signal ('__404', '');

      objectID := (select P_ID from AB.WA.PERSONS where P_UID = tmp and P_DOMAIN_ID = domain_id);
      if (isnull (objectID))
        signal ('__404', '');

      AB.WA.contact_delete (objectID, domain_id);
    }
  }
  else if (domain_mode = 'groups')
  {
    set_user_id ('dba');
    if (apiMethod = 'GET')
    {
      -- retrieve Groups

      oResult := AB.WA.apiObject();
      oFeed := AB.WA.apiObject();
      if (AB.WA.googleSQL ('select TOP %TOP% c.* from AB.WA.CATEGORIES c where c.C_DOMAIN_ID = ?', vector (domain_id), apiOptions, data, meta))
      {
        for (N := 0; N < length (data); N := N + 1)
        {
          oGroup := AB.WA.googleGroupObject(data[N], meta);
          oFeed := vector_concat (oFeed, vector ('entry', oGroup));
        }
      }
      AB.WA.googleFeedObject (oFeed, domain_id, apiOptions);
      oResult := vector_concat (oResult, vector ('feed', oFeed));
      AB.WA.googleOutput (oResult, apiParams);
    }
    else if (apiMethod = 'POST')
    {
      -- Insert Group ('POST')
      declare gID, gName any;

      xt := xtree_doc (apiBody);
      gName := cast (xpath_eval ('[ xmlns:atom="http://www.w3.org/2005/Atom" xmlns:gd="http://schemas.google.com/g/2005" ] /atom:entry/atom:title', xt, 1) as varchar);
      if (isnull (gName))
        signal ('__400', '');

      gID := AB.WA.category_insert (domain_id, gName);
      if (isnull (gID))
        signal ('__400', '');

      oFeed := AB.WA.apiObject();
      if (AB.WA.googleSQL ('select c.* from AB.WA.CATEGORIES c where c.C_DOMAIN_ID = ? and c.C_ID = ?', vector (domain_id, gID), vector (), data, meta))
      {
        if (length (data) = 1)
        {
          oGroup := AB.WA.googleGroupObject(data[0], meta);
          oFeed := vector_concat (oFeed, vector ('entry', oGroup));
        }
      }
      AB.WA.googleOutput (oFeed, apiParams);
    }
    else if (apiMethod = 'PUT')
    {
      -- Update Group ('PUT')
      declare gID, gName any;

      xt := xtree_doc (apiBody);
      gID := cast (xpath_eval ('[ xmlns:atom="http://www.w3.org/2005/Atom" xmlns:gd="http://schemas.google.com/g/2005" ] /atom:entry/id', xt, 1) as varchar);
      if (isnull (gName))
        signal ('__400', '');
      if (not exists (select 1 from AB.WA.CATEGORIES where C_ID = gID and C_DOMAIN_ID = domain_id))
        signal ('__404', '');

      gName := cast (xpath_eval ('[ xmlns:atom="http://www.w3.org/2005/Atom" xmlns:gd="http://schemas.google.com/g/2005" ] /atom:entry/title', xt, 1) as varchar);
      if (isnull (gName))
        signal ('__400', '');

      update AB.WA.CATEGORIES
         set C_NAME = gName,
             C_UPDATED = now ()
       where C_ID = gID
         and C_DOMAIN_ID = domain_id;

      oFeed := AB.WA.apiObject();
      if (AB.WA.googleSQL ('select c.* from AB.WA.CATEGORIES c where c.C_DOMAIN_ID = ? and c.C_ID = ?', vector (domain_id, gID), vector (), data, meta))
      {
        if (length (data) = 1)
        {
          oGroup := AB.WA.googleGroupObject(data[0], meta);
          oFeed := vector_concat (oFeed, vector ('entry', oGroup));
        }
      }
      AB.WA.googleOutput (oFeed, apiParams);
    }
    else if (apiMethod = 'DELETE')
    {
      -- Delete Group ('DELETE')
      declare gID any;

      xt := xtree_doc (apiBody);
      gID := cast (xpath_eval ('[ xmlns:atom="http://www.w3.org/2005/Atom" xmlns:gd="http://schemas.google.com/g/2005" ] /atom:entry/id', xt, 1) as varchar);
      if (isnull (gID))
        signal ('__400', '');

      delete from AB.WA.CATEGORIES where C_ID = gID and C_DOMAIN_ID = domain_id;
    }
  }

  http_request_status ('HTTP/1.1 200 OK');
  return '';
}
;

grant execute on AB.WA.googlecontacts to SOAP_ADDRESSBOOK
;
