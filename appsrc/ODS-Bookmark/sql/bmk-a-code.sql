--
--  $Id$
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2012 OpenLink Software
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
create procedure BMK.WA.acl_condition (
  in domain_id integer,
  in id integer := null)
{
  if (not is_https_ctx ())
    return 0;

  if (exists (select 1 from DB.DBA.WA_INSTANCE where WAI_ID = domain_id and WAI_ACL is not null))
    return 1;

  if (exists (select 1 from BMK.WA.BOOKMARK_DOMAIN where BD_ID = id and BD_ACL is not null))
    return 1;

  return 0;
}
;

-------------------------------------------------------------------------------
--
create procedure BMK.WA.acl_check (
  in domain_id integer,
  in id integer := null)
{
  declare rc varchar;
  declare graph_iri, groups_iri, acl_iris any;

  rc := '';
  if (BMK.WA.acl_condition (domain_id, id))
  {
    acl_iris := vector (BMK.WA.forum_iri (domain_id));
    if (not isnull (id))
      acl_iris := vector (SIOC..bmk_post_iri (domain_id, id), BMK.WA.forum_iri (domain_id));

    graph_iri := BMK.WA.acl_graph (domain_id);
    groups_iri := SIOC..acl_groups_graph (BMK.WA.domain_owner_id (domain_id));
    rc := SIOC..acl_check (graph_iri, groups_iri, acl_iris);
  }
  return rc;
}
;

-------------------------------------------------------------------------------
--
create procedure BMK.WA.acl_list (
  in domain_id integer)
{
  declare graph_iri, groups_iri, iri any;

  iri := BMK.WA.forum_iri (domain_id);
  graph_iri := BMK.WA.acl_graph (domain_id);
  groups_iri := SIOC..acl_groups_graph (BMK.WA.domain_owner_id (domain_id));
  return SIOC..acl_list (graph_iri, groups_iri, iri);
}
;

-------------------------------------------------------------------------------
--
-- Session Functions
--
-------------------------------------------------------------------------------
create procedure BMK.WA.session_domain (
  inout params any)
{
  declare aPath, domain_id, options any;
  declare exit handler for sqlstate '*'
  {
    domain_id := -2;
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
    if ((length (aPath) = 1) or ((length (aPath) = 2) and (aPath[1] like '%.vsp%')))
    {
      domain_id := -1;
      goto _end;
    }
    domain_id := cast(aPath[1] as integer);
  }
  if (not exists (select 1 from DB.DBA.WA_INSTANCE where WAI_ID = domain_id and WAI_TYPE_NAME = 'Bookmark'))
    domain_id := -2;

_end:;
  return cast (domain_id as integer);
}
;

-------------------------------------------------------------------------------
--
create procedure BMK.WA.session_restore(
  inout params any)
{
  declare domain_id, account_id, account_rights any;

  domain_id := BMK.WA.session_domain (params);
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
  account_rights := BMK.WA.access_rights (domain_id, account_id);
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
create procedure BMK.WA.frozen_check(in domain_id integer)
{
  declare exit handler for not found { return 1; };

  if (is_empty_or_null((select WAI_IS_FROZEN from DB.DBA.WA_INSTANCE where WAI_ID = domain_id)))
    return 0;

  declare user_id integer;

  user_id := (select U_ID from SYS_USERS where U_NAME = connection_get ('vspx_user'));
  if (BMK.WA.check_admin(user_id))
    return 0;

  user_id := (select U_ID from SYS_USERS where U_NAME = connection_get ('owner_user'));
  if (BMK.WA.check_admin(user_id))
    return 0;

  return 1;
}
;

-------------------------------------------------------------------------------
--
create procedure BMK.WA.frozen_page(in domain_id integer)
{
  return (select WAI_FREEZE_REDIRECT from DB.DBA.WA_INSTANCE where WAI_ID = domain_id);
}
;

-------------------------------------------------------------------------------
--
-- User Functions
--
-------------------------------------------------------------------------------
create procedure BMK.WA.check_admin(
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
create procedure BMK.WA.check_grants (in role_name varchar, in page_name varchar)
{
  declare tree any;

  tree := xml_tree_doc (BMK.WA.menu_tree ());
  if (isnull (xpath_eval (sprintf ('//node[(@url = "%s") and contains(@allowed, "%s")]', page_name, role_name), tree, 1)))
    return 0;
  return 1;
}
;

-------------------------------------------------------------------------------
--
create procedure BMK.WA.access_rights (
  in domain_id integer,
  in account_id integer)
{
  declare rc varchar;

  if (domain_id = -1)
    return 'R';

  if (domain_id = -2)
    return null;

  if (BMK.WA.check_admin (account_id))
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
    rc := BMK.WA.acl_check (domain_id);
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

  if (is_https_ctx () and exists (select 1 from BMK.WA.acl_list (id)(iri varchar) x where x.id = domain_id))
    return '';

  return null;
}
;

-------------------------------------------------------------------------------
--
create procedure BMK.WA.wa_home_link ()
{
	return case when registry_get ('wa_home_link') = 0 then '/ods/' else registry_get ('wa_home_link') end;
}
;

-------------------------------------------------------------------------------
--
create procedure BMK.WA.wa_home_title ()
{
	return case when registry_get ('wa_home_title') = 0 then 'ODS Home' else registry_get ('wa_home_title') end;
}
;

-------------------------------------------------------------------------------
--
create procedure BMK.WA.page_name ()
{
  declare path, url, pageName varchar;
  declare aPath any;

  path := http_path ();
  aPath := split_and_decode (path, 0, '\0\0/');
  pageName := aPath [length (aPath) - 1];
  if (pageName = 'error.vspx')
    return pageName;
  url := xpath_eval ('//*[@url = "'|| pageName ||'"]', xml_tree_doc (BMK.WA.menu_tree ()));
  if ((url is not null))
    return pageName;
  return '';
}
;

-------------------------------------------------------------------------------
--
create procedure BMK.WA.menu_tree (
  in access_role varchar := null)
{
  return
'<?xml version="1.0" ?>
<menu_tree>
  <node name="Bookmarks"       url="bookmarks.vspx"       id="1"                allowed="W R">
    <node name="11"            url="bookmarks.vspx"       id="11"  place="link" allowed="W R"/>
    <node name="12"            url="search.vspx"          id="12"  place="link" allowed="W R"/>
    <node name="13"            url="error.vspx"           id="13"  place="link" allowed="W R"/>
    <node name="14"            url="settings.vspx"        id="14"  place="link" allowed="W"/>
    <node name="15"            url="bookmark.vspx"        id="15"  place="link" allowed="W R"/>
  </node>
</menu_tree>';
}
;

-------------------------------------------------------------------------------
--
create procedure BMK.WA.navigation_root (
  in path varchar)
{
  declare domain_id, user_id integer;
  declare access_role varchar;
  declare aPath any;

  aPath := split_and_decode(path,0,'\0\0/');
  if (length(aPath) < 2)
    return vector();
  domain_id := cast(aPath[0] as integer);
  user_id := cast(aPath[1] as integer);
  access_role := BMK.WA.access_role(domain_id, user_id);
  return xpath_eval (sprintf('/menu_tree/*[contains(@allowed, "%s")]', access_role), xml_tree_doc (BMK.WA.menu_tree (access_role)), 0);

}
;

-------------------------------------------------------------------------------
--
create procedure BMK.WA.navigation_child (
  in path varchar,
  in node any)
{
  path := concat (path, '[not @place]');
  return xpath_eval (path, node, 0);
}
;

-------------------------------------------------------------------------------
--
create procedure BMK.WA.domain_owner_id (
  inout domain_id integer)
{
  return (select A.WAM_USER from WA_MEMBER A, WA_INSTANCE B where A.WAM_MEMBER_TYPE = 1 and A.WAM_INST = B.WAI_NAME and B.WAI_ID = domain_id);
}
;

-------------------------------------------------------------------------------
--
create procedure BMK.WA.domain_owner_name (
  inout domain_id integer)
{
  return (select C.U_NAME from WA_MEMBER A, WA_INSTANCE B, SYS_USERS C where A.WAM_MEMBER_TYPE = 1 and A.WAM_INST = B.WAI_NAME and B.WAI_ID = domain_id and C.U_ID = A.WAM_USER);
}
;

-------------------------------------------------------------------------------
--
create procedure BMK.WA.domain_gems_create (
  inout domain_id integer,
  inout account_id integer)
{
  declare read_perm, exec_perm, content, home, path varchar;

  home := BMK.WA.dav_home(account_id);
  if (isnull(home))
    return;

  read_perm := '110100100N';
  exec_perm := '111101101N';
  home := home || 'Gems/';
  DB.DBA.DAV_MAKE_DIR (home, account_id, null, read_perm);

  home := home || BMK.WA.domain_gems_name(domain_id) || '/';
  DB.DBA.DAV_MAKE_DIR (home, account_id, null, read_perm);

  -- RSS 2.0
  path := home || 'Bookmark.rss';
  DB.DBA.DAV_DELETE_INT (path, 1, null, null, 0);

  content := BMK.WA.export_rss_sqlx (domain_id, account_id);
  DB.DBA.DAV_RES_UPLOAD_STRSES_INT (path, content, 'text/xml', exec_perm, http_dav_uid (), http_dav_uid () + 1, null, null, 0);
  DB.DBA.DAV_PROP_SET_INT (path, 'xml-template', 'execute', 'dav', null, 0, 0, 1);
  DB.DBA.DAV_PROP_SET_INT (path, 'xml-sql-encoding', 'utf-8', 'dav', null, 0, 0, 1);
  DB.DBA.DAV_PROP_SET_INT (path, 'xml-sql-description', 'RSS based XML document generated by OpenLink Feed Manager', 'dav', null, 0, 0, 1);

  -- ATOM
  path := home || 'Bookmark.atom';
  DB.DBA.DAV_DELETE_INT (path, 1, null, null, 0);

  content := BMK.WA.export_atom_sqlx (domain_id, account_id);
  DB.DBA.DAV_RES_UPLOAD_STRSES_INT (path, content, 'text/xml', exec_perm, http_dav_uid (), http_dav_uid () + 1, null, null, 0);
  DB.DBA.DAV_PROP_SET_INT (path, 'xml-template', 'execute', 'dav', null, 0, 0, 1);
  DB.DBA.DAV_PROP_SET_INT (path, 'xml-sql-encoding', 'utf-8', 'dav', null, 0, 0, 1);
  DB.DBA.DAV_PROP_SET_INT (path, 'xml-sql-description', 'ATOM based XML document generated by OpenLink Feed Manager', 'dav', null, 0, 0, 1);

  -- RDF
  path := home || 'Bookmark.rdf';
  DB.DBA.DAV_DELETE_INT (path, 1, null, null, 0);

  content := BMK.WA.export_rdf_sqlx (domain_id, account_id);
  DB.DBA.DAV_RES_UPLOAD_STRSES_INT (path, content, 'text/xml', exec_perm, http_dav_uid (), http_dav_uid () + 1, null, null, 0);
  DB.DBA.DAV_PROP_SET_INT (path, 'xml-template', 'execute', 'dav', null, 0, 0, 1);
  DB.DBA.DAV_PROP_SET_INT (path, 'xml-sql-encoding', 'utf-8', 'dav', null, 0, 0, 1);
  DB.DBA.DAV_PROP_SET_INT (path, 'xml-sql-description', 'RDF based XML document generated by OpenLink Feed Manager', 'dav', null, 0, 0, 1);

  -- OCS
  path := home || 'Bookmark.ocs';
  DB.DBA.DAV_DELETE_INT (path, 1, null, null, 0);

  content := BMK.WA.export_ocs_sqlx (domain_id, account_id);
  DB.DBA.DAV_RES_UPLOAD_STRSES_INT (path, content, 'text/xml', exec_perm, http_dav_uid (), http_dav_uid () + 1, null, null, 0);
  DB.DBA.DAV_PROP_SET_INT (path, 'xml-template', 'execute', 'dav', null, 0, 0, 1);
  DB.DBA.DAV_PROP_SET_INT (path, 'xml-sql-encoding', 'utf-8', 'dav', null, 0, 0, 1);
  DB.DBA.DAV_PROP_SET_INT (path, 'xml-sql-description', 'OCS based XML document generated by OpenLink Feed Manager', 'dav', null, 0, 0, 1);

  -- OPML
  path := home || 'Bookmark.opml';
  DB.DBA.DAV_DELETE_INT (path, 1, null, null, 0);

  content := BMK.WA.export_opml_sqlx (domain_id, account_id);
  DB.DBA.DAV_RES_UPLOAD_STRSES_INT (path, content, 'text/xml', exec_perm, http_dav_uid (), http_dav_uid () + 1, null, null, 0);
  DB.DBA.DAV_PROP_SET_INT (path, 'xml-template', 'execute', 'dav', null, 0, 0, 1);
  DB.DBA.DAV_PROP_SET_INT (path, 'xml-sql-encoding', 'utf-8', 'dav', null, 0, 0, 1);
  DB.DBA.DAV_PROP_SET_INT (path, 'xml-sql-description', 'OPML based XML document generated by OpenLink Feed Manager', 'dav', null, 0, 0, 1);

  -- COMMENT
  path := home || 'Bookmark.comment';
  DB.DBA.DAV_DELETE_INT (path, 1, null, null, 0);

  content := BMK.WA.export_comment_sqlx (domain_id, account_id);
  DB.DBA.DAV_RES_UPLOAD_STRSES_INT (path, content, 'text/xml', exec_perm, http_dav_uid (), http_dav_uid () + 1, null, null, 0);
  DB.DBA.DAV_PROP_SET_INT (path, 'xml-template', 'execute', 'dav', null, 0, 0, 1);
  DB.DBA.DAV_PROP_SET_INT (path, 'xml-sql-encoding', 'utf-8', 'dav', null, 0, 0, 1);
  DB.DBA.DAV_PROP_SET_INT (path, 'xml-sql-description', 'RSS discussion based XML document generated by OpenLink Bookmarks', 'dav', null, 0, 0, 1);

  return;
}
;

-------------------------------------------------------------------------------
--
create procedure BMK.WA.domain_gems_delete(
  in domain_id integer,
  in account_id integer := null,
  in appName varchar := 'Gems',
  in appGems varchar := null,
  in fileName varchar := 'Bookmark')
{
  declare tmp, home, appHome, path varchar;

  if (isnull (account_id))
    account_id := BMK.WA.domain_owner_id (domain_id);

  home := BMK.WA.dav_home(account_id);
  if (isnull(home))
    return;

  if (isnull(appGems))
    appGems := BMK.WA.domain_gems_name(domain_id);
  appHome := home || appName || '/';
  home := appHome || appGems || '/';

  path := home || fileName || '.rss';
  DB.DBA.DAV_DELETE_INT (path, 1, null, null, 0);
  path := home || fileName || '.rdf';
  DB.DBA.DAV_DELETE_INT (path, 1, null, null, 0);
  path := home || fileName || '.atom';
  DB.DBA.DAV_DELETE_INT (path, 1, null, null, 0);
  path := home || fileName || '.ocs';
  DB.DBA.DAV_DELETE_INT (path, 1, null, null, 0);
  path := home || fileName || '.opml';
  DB.DBA.DAV_DELETE_INT (path, 1, null, null, 0);
  path := home || fileName || '.foaf';
  DB.DBA.DAV_DELETE_INT (path, 1, null, null, 0);
  path := home || fileName || '.comment';
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
  if (not isinteger (tmp) and not length(tmp))
    DB.DBA.DAV_DELETE_INT (appHome, 1, null, null, 0);

  return 1;
}
;

-------------------------------------------------------------------------------
--
create procedure BMK.WA.domain_update (
  inout domain_id integer,
  inout account_id integer)
{
  BMK.WA.domain_gems_delete (domain_id, account_id, 'BM', BMK.WA.domain_name (domain_id) || '_Gems', 'BM');
  BMK.WA.domain_gems_create (domain_id, account_id);

  BMK.WA.sfolder_create (domain_id, 'All bookmarks', '<settings/>');

  return;
}
;

-------------------------------------------------------------------------------
--
create procedure BMK.WA.domain_delete (
  in domain_id integer)
{
  declare continue handler for SQLSTATE '*' {return 0; };

  BMK.WA.folder_delete_all(domain_id);
  delete from BMK.WA.SFOLDER         where SF_DOMAIN_ID = domain_id;
  delete from BMK.WA.BOOKMARK_DOMAIN where BD_DOMAIN_ID = domain_id;
  delete from BMK.WA.TAGS            where T_DOMAIN_ID = domain_id;
  delete from BMK.WA.EXCHANGE        where EX_DOMAIN_ID = domain_id;
  delete from BMK.WA.SETTINGS        where S_DOMAIN_ID = domain_id;

  for (select WAM_USER from DB.DBA.WA_MEMBER, DB.DBA.WA_INSTANCE where WAI_TYPE_NAME = 'Bookmark' and WAI_ID = domain_id) do
  {
    BMK.WA.account_delete (domain_id, WAM_USER);
  }

  BMK.WA.domain_gems_delete (domain_id);
  BMK.WA.nntp_update (domain_id, null, null, 1, 0);

  VHOST_REMOVE(lpath => concat('/bookmark/', cast(domain_id as varchar)));
  return 1;
}
;

-------------------------------------------------------------------------------
--
create procedure BMK.WA.domain_id (
  in domain_name varchar)
{
  return (select WAI_ID from DB.DBA.WA_INSTANCE where WAI_NAME = domain_name);
}
;

-------------------------------------------------------------------------------
--
create procedure BMK.WA.domain_name (
  in domain_id integer)
{
  return coalesce((select WAI_NAME from DB.DBA.WA_INSTANCE where WAI_ID = domain_id), 'Bookmark Instance');
}
;

-------------------------------------------------------------------------------
--
create procedure BMK.WA.domain_nntp_name (
  in domain_id integer)
{
  return BMK.WA.domain_nntp_name2 (BMK.WA.domain_name (domain_id), BMK.WA.domain_owner_name (domain_id));
}
;

-------------------------------------------------------------------------------
--
create procedure BMK.WA.domain_nntp_name2 (
  in domain_name varchar,
  in owner_name varchar)
{
  return sprintf ('ods.bookmarks.%s.%U', owner_name, BMK.WA.string2nntp (domain_name));
}
;

-------------------------------------------------------------------------------
--
create procedure BMK.WA.domain_gems_name (
  in domain_id integer)
{
  return concat (BMK.WA.domain_name(domain_id), '');
}
;

-------------------------------------------------------------------------------
--
create procedure BMK.WA.domain_description (
  in domain_id integer)
{
  return coalesce((select coalesce(WAI_DESCRIPTION, WAI_NAME) from DB.DBA.WA_INSTANCE where WAI_ID = domain_id), 'Bookmark Instance');
}
;

-------------------------------------------------------------------------------
--
create procedure BMK.WA.domain_is_public (
  in domain_id integer)
{
  return coalesce((select WAI_IS_PUBLIC from DB.DBA.WA_INSTANCE where WAI_ID = domain_id), 0);
}
;

-------------------------------------------------------------------------------
--
create procedure BMK.WA.domain_ping (
  in domain_id integer)
{
  for (select WAI_NAME, WAI_DESCRIPTION from DB.DBA.WA_INSTANCE where WAI_ID = domain_id and WAI_IS_PUBLIC = 1) do
  {
    ODS..APP_PING (WAI_NAME, coalesce (WAI_DESCRIPTION, WAI_NAME), BMK.WA.forum_iri (domain_id), null, BMK.WA.gems_url (domain_id) || 'Bookmark.rss');
    ODS..APP_PING (WAI_NAME, coalesce (WAI_DESCRIPTION, WAI_NAME), BMK.WA.forum_iri (domain_id), null, BMK.WA.gems_url (domain_id) || 'Bookmark.atom');
  }
}
;

-------------------------------------------------------------------------------
--
create procedure BMK.WA.forum_iri (
  in domain_id integer)
{
  return SIOC..bmk_iri (BMK.WA.domain_name (domain_id));
}
;

-------------------------------------------------------------------------------
--
create procedure BMK.WA.acl_graph (
  in domain_id integer)
{
  return SIOC..acl_graph ('Bookmark', BMK.WA.domain_name (domain_id));
}
;

-------------------------------------------------------------------------------
--
create procedure BMK.WA.domain_sioc_url (
  in domain_id integer,
  in sid varchar := null,
  in realm varchar := null)
{
  declare S varchar;

  S := BMK.WA.iri_fix (BMK.WA.forum_iri (domain_id));
  return BMK.WA.url_fix (S, sid, realm);
}
;

-------------------------------------------------------------------------------
--
create procedure BMK.WA.sparql_url ()
{
  return sprintf ('http://%s/sparql?default-graph-uri=%U&query=%U&format=%U', SIOC..get_cname (), SIOC..get_graph (), 'DESCRIBE <_RDF_>', 'application/sparql-results+xml');
}
;

-------------------------------------------------------------------------------
--
create procedure BMK.WA.page_url (
  in domain_id integer,
  in page varchar := null,
  in sid varchar := null,
  in realm varchar := null)
{
  declare S varchar;

  S := BMK.WA.iri_fix (BMK.WA.forum_iri (domain_id));
  if (not isnull (page))
    S := S || '/' || page;
  return BMK.WA.url_fix (S, sid, realm);
}
;

-------------------------------------------------------------------------------
--
-- Account Functions
--
-------------------------------------------------------------------------------
create procedure BMK.WA.account()
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
create procedure BMK.WA.account_access (
  inout auth_uid varchar,
  inout auth_pwd varchar)
{
  if (isnull (auth_uid))
  auth_uid := BMK.WA.account();
  auth_pwd := coalesce((SELECT U_PWD FROM WS.WS.SYS_DAV_USER WHERE U_NAME = auth_uid), '');
  if (auth_pwd[0] = 0)
    auth_pwd := pwd_magic_calc(auth_uid, auth_pwd, 1);
  return 1;
}
;

-------------------------------------------------------------------------------
--
create procedure BMK.WA.account_delete(
  in domain_id integer,
  in account_id integer)
{
  declare iCount any;

  select count(WAM_USER) into iCount
    from WA_MEMBER,
         WA_INSTANCE
   where WAI_NAME = WAM_INST
     and WAI_TYPE_NAME = 'Bookmark'
     and WAM_USER = account_id;

  if (iCount = 0)
    delete from BMK.WA.GRANTS where G_GRANTER_ID = account_id or G_GRANTEE_ID = account_id;

  return 1;
}
;

-------------------------------------------------------------------------------
--
create procedure BMK.WA.account_id (
  in account_name varchar)
{
  return (select U_ID from DB.DBA.SYS_USERS where U_NAME = account_name);
}
;

-------------------------------------------------------------------------------
--
create procedure BMK.WA.account_name (
  in account_id integer)
{
  return coalesce((select U_NAME from DB.DBA.SYS_USERS where U_ID = account_id), '');
}
;

-------------------------------------------------------------------------------
--
create procedure BMK.WA.account_password (
  in account_id integer)
{
  return coalesce ((select pwd_magic_calc(U_NAME, U_PWD, 1) from WS.WS.SYS_DAV_USER where U_ID = account_id), '');
}
;

-------------------------------------------------------------------------------
--
create procedure BMK.WA.account_fullName (
  in account_id integer)
{
  return coalesce ((select BMK.WA.user_name (U_NAME, U_FULL_NAME) from DB.DBA.SYS_USERS where U_ID = account_id), '');
}
;

-------------------------------------------------------------------------------
--
create procedure BMK.WA.account_mail(
  in account_id integer)
{
  return coalesce((select U_E_MAIL from DB.DBA.SYS_USERS where U_ID = account_id), '');
}
;

-------------------------------------------------------------------------------
--
create procedure BMK.WA.account_sioc_url (
  in domain_id integer,
  in sid varchar := null,
  in realm varchar := null)
{
  declare S varchar;

  S := BMK.WA.iri_fix (SIOC..person_iri (SIOC..user_iri (BMK.WA.domain_owner_id (domain_id), null)));
  return BMK.WA.url_fix (S, sid, realm);
}
;

-------------------------------------------------------------------------------
--
create procedure BMK.WA.account_basicAuthorization (
  in account_id integer)
{
  declare account_name, account_password varchar;

  account_name := BMK.WA.account_name (account_id);
  account_password := BMK.WA.account_password (account_id);
  return sprintf ('Basic %s', encode_base64 (account_name || ':' || account_password));
}
;

-------------------------------------------------------------------------------
--
create procedure BMK.WA.user_name(
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
-- Bookmarks
--
-------------------------------------------------------------------------------
create procedure BMK.WA.bookmark_update (
  in id integer,
  in domain_id integer,
  in uri any,
  in name any,
  in description any,
  in tags any,
  in folder_id integer,
  in uid varchar := null,
  in acl any := null)
{
  declare bookmark_id integer;

  bookmark_id := (select B_ID from BMK.WA.BOOKMARK where B_URI = uri);
  if (is_empty_or_null (bookmark_id))
  {
    insert into BMK.WA.BOOKMARK (B_URI, B_NAME, B_DESCRIPTION, B_CREATED)
      values (uri, name, description, now());
    bookmark_id := identity_value ();
  }
  if (cast(folder_id as integer) <= 0)
    folder_id := null;
  if (id = -1)
    id := coalesce ((select BD_ID from BMK.WA.BOOKMARK_DOMAIN where BD_DOMAIN_ID = domain_id and BD_BOOKMARK_ID = bookmark_id and BD_UID = uid), -1);
  if (id = -1)
    id := coalesce((select BD_ID from BMK.WA.BOOKMARK_DOMAIN where BD_DOMAIN_ID = domain_id and coalesce(BD_FOLDER_ID, 0) = coalesce(folder_id, 0) and BD_BOOKMARK_ID = bookmark_id and BD_NAME = name), -1);
  if (id <= 0)
  {
    insert into BMK.WA.BOOKMARK_DOMAIN (BD_DOMAIN_ID, BD_BOOKMARK_ID, BD_NAME, BD_DESCRIPTION, BD_TAGS, BD_UPDATED, BD_CREATED, BD_FOLDER_ID, BD_UID, BD_ACL)
      values (domain_id, bookmark_id, name, description, tags, now(), now(), folder_id, uid, acl);
    id := coalesce((select BD_ID from BMK.WA.BOOKMARK_DOMAIN where BD_DOMAIN_ID = domain_id and coalesce(BD_FOLDER_ID, 0) = coalesce(folder_id, 0) and BD_BOOKMARK_ID = bookmark_id and BD_NAME = name), -1);
  } else {
    update BMK.WA.BOOKMARK_DOMAIN
       set BD_BOOKMARK_ID = bookmark_id,
           BD_NAME = name,
           BD_DESCRIPTION = description,
           BD_TAGS = tags,
           BD_UPDATED = now(),
           BD_FOLDER_ID = folder_id,
           BD_ACL = acl
     where BD_ID = id;
  }
  return id;
}
;

-------------------------------------------------------------------------------
--
create procedure BMK.WA.bookmark_delete(
  in domain_id integer,
  in id integer)
{
  declare bookmark_id integer;

  bookmark_id := (select BD_BOOKMARK_ID from BMK.WA.BOOKMARK_DOMAIN where BD_ID = id);
  delete from BMK.WA.BOOKMARK_DOMAIN where BD_ID = id;
  if (not exists(select 1 from BMK.WA.BOOKMARK_DOMAIN where BD_BOOKMARK_ID = bookmark_id))
    delete from BMK.WA.BOOKMARK where B_ID = bookmark_id;
  }
;

-------------------------------------------------------------------------------
--
create procedure BMK.WA.bookmark_description(
  in id integer)
{
  return coalesce((select BD_DESCRIPTION from BMK.WA.BOOKMARK_DOMAIN where BD_ID = id), '');
}
;

-------------------------------------------------------------------------------
--
create procedure BMK.WA.bookmark_parent(
  in id integer,
  in folder_id integer)
{
  if (is_empty_or_null(folder_id))
    folder_id := null;
  update BMK.WA.BOOKMARK_DOMAIN
     set BD_FOLDER_ID = folder_id
   where BD_ID = id;
}
;

-------------------------------------------------------------------------------
--
create procedure BMK.WA.bookmark_import(
  in S any,
  in domain_id integer,
  in folder_id integer := null,
  in tags varchar := '',
  in progress_id varchar := null)
{
  declare V, V2 any;

  -- check netscape format
  if (isnull(strcasestr(S, '<!doctype netscape-bookmark-file-1>')))
    goto _xbel;
  S := replace(S, '<p>', '');
  S := replace(S, '<HR>', '');
  S := replace(S, '<DD>', '');
  S := replace(S, 'FOLDED', '');
  S := replace(S, '  ', ' ');
  S := replace(S, '&', '&amp;');
  V := xtree_doc (S, 2);
  V := xpath_eval('//dl', V);
  if (isnull (V))
    goto _xbel;

  BMK..bookmark_import_netscape (domain_id, folder_id, tags, xml_cut(V), progress_id);
  goto _end;

_xbel:;
  -- check XBEL format
  --
  V := BMK.WA.string2xml (S);
  if (isnull (V))
    goto _end;
  V2 := xpath_eval('/xbel', V);
  if (isnull (V2))
    goto _rss;
  BMK..bookmark_import_xbel (domain_id, folder_id, tags, xml_cut(V2), progress_id, 'xbel');
  goto _end;

_rss:;
  -- check RSS format
  --
  V2 := xpath_eval ('/rss/channel/item|/rss/item|/RDF/item|/Channel/items/item', V);
  if (isnull (V2))
    goto _atom;
  BMK..bookmark_import_rss (domain_id, folder_id, tags, V2, progress_id);
  goto _end;

_atom:;
  -- check Atom format
  --
  V2 := xpath_eval ('/feed/entry', V);
  if (isnull (V2))
    goto _delicious;
  BMK..bookmark_import_atom (domain_id, folder_id, tags, V2, progress_id);
  goto _end;

_delicious:;
  V2 := xpath_eval('/posts', V);
  if (isnull (V2))
  {
    signal ('BMK01', 'The content being imported was not of a format ODS-Bookmarks understands!<>');
    goto _end;
  }
  BMK..bookmark_import_delicious (domain_id, folder_id, tags, xml_cut(V2), progress_id);

_end:
    return;
}
;

-----------------------------------------------------
--
create procedure BMK.WA.bookmark_import_netscape(
  in domain_id integer,
  in folder_id integer,
  in tags varchar,
  in V any,
  in progress_id varchar)
{
  declare tmp, T, Q any;
  declare N integer;

  if (V is null)
    return;
  N := 1;
  while (1)
  {
    --commit work;
    T := xpath_eval('/dl/dt/a/text()', V, N);
    if (T is null)
      goto _folder;
    Q := xpath_eval('/dl/dt/a/@href', V, N);

    BMK.WA.bookmark_import_update (domain_id, Q, T, null, tags, folder_id, progress_id);

    N := N + 1;
  }
_folder:
  N := 1;
  while (1)
  {
    T := xpath_eval('/dl/dt/h3', V, N);
    if (T is null)
      goto _exit;
    tmp := BMK.WA.folder_create2(domain_id, folder_id, cast(T as varchar));
    T := xpath_eval('/dl/dt/dl', V, N);
    if (not (T is null))
      BMK.WA.bookmark_import_netscape (domain_id, tmp, tags, xml_cut(T), progress_id);
    N := N + 1;
  }
_exit:
  return;
}
;

-----------------------------------------------------
--
create procedure BMK.WA.bookmark_import_xbel(
  in domain_id integer,
  in folder_id integer,
  in tags varchar,
  in V any,
  in progress_id varchar,
  in tag varchar)
{
  declare T, Q, D any;
  declare N integer;

  if (V is null)
    return;
  T := xpath_eval(sprintf('/%s/title/text()', tag), V, 1);
  if (T is null)
    return;
  folder_id := BMK.WA.folder_create2(domain_id, folder_id, cast(T as varchar));

  N := 1;
  while (1)
  {
    Q := xpath_eval(sprintf('/%s/bookmark[%d]/@href', tag, N), V, 1);
    if (Q is null)
      goto _folder;

    T := BMK.WA.wide2utf(xpath_eval(sprintf('string(/%s/bookmark[%d]/title/text())', tag, N), V, 1));
    D := BMK.WA.wide2utf(xpath_eval(sprintf('string(/%s/bookmark[%d]/desc/text())', tag, N), V, 1));

    BMK.WA.bookmark_import_update (domain_id, Q, T, D, tags, folder_id, progress_id);

    N := N + 1;
  }
_folder:
  N := 1;
  while (1)
  {
    T := xpath_eval(sprintf('/%s/folder[%d]', tag, N), V, 1);
    if (T is null)
      goto _exit;
    BMK.WA.bookmark_import_xbel (domain_id, folder_id, tags, xml_cut(T), progress_id, 'folder');
    N := N + 1;
  }
_exit:
  return;
}
;

-----------------------------------------------------
--
create procedure BMK.WA.bookmark_import_rss (
  in domain_id integer,
  in folder_id integer,
  in tags varchar,
  in V any,
  in progress_id varchar)
{
  declare items, item, T, Q, D any;
  declare N, L integer;

  items := xpath_eval ('/rss/channel/item|/rss/item|/RDF/item|/Channel/items/item', V, 0);
  L := length (items);
  for (N := 0; N < L; N := N + 1)
  {
    item := xml_cut(items[N]);
    T := serialize_to_UTF8_xml (xpath_eval ('string(/item/title)', item, 1));
    D := xpath_eval ('[ xmlns:content="http://purl.org/rss/1.0/modules/content/" ] string(/item/content:encoded)', item, 1);
    if (is_empty_or_null (D))
      D := xpath_eval ('string(/item/description)', item, 1);

    D := serialize_to_UTF8_xml (D);
    Q := cast (xpath_eval ('/item/link', item, 1) as varchar);
    if (isnull (Q))
    {
      Q := cast (xpath_eval ('[xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"] /item/@rdf:about', item, 1) as varchar);
      if ((isnull (Q)) and isnull (cast(xpath_eval ('/item/guid[@isPermaLink = "false"]', item, 1) as varchar)))
        Q := cast (xpath_eval ('/item/guid', item, 1) as varchar);
    }

    BMK.WA.bookmark_import_update (domain_id, Q, T, D, tags, folder_id, progress_id);
  }
}
;

-----------------------------------------------------
--
create procedure BMK.WA.bookmark_import_atom (
  in domain_id integer,
  in folder_id integer,
  in tags varchar,
  in V any,
  in progress_id varchar)
{
  declare items, item, contents, T, Q, D any;
  declare N, L integer;

  items := xpath_eval ('/feed/entry', V, 0);
  L := length (items);
  for (N := 0; N < L; N := N + 1)
  {
    item := xml_cut (items[N]);
    T := serialize_to_UTF8_xml (xpath_eval ('string(/entry/title)', item, 1));
    if (xpath_eval ('/entry/content[@type = "application/xhtml+xml" or @type="xhtml"]', item) is not null)
    {
      contents := xpath_eval ('/entry/content/*', item, 0);
      if (length (contents) = 1)
      {
        D := serialize_to_UTF8_xml (contents[0]);
      }
      else
      {
        D := '<div>';
        foreach (any content in contents) do
          D := concat(D, ENEWS.WA.xml2string(content));

        D := concat(D, '</div>');
      }
    }
    else
    {
      D := xpath_eval ('string(/entry/content)', item, 1);
      if (is_empty_or_null(D))
        D := xpath_eval ('string(/entry/summary)', item, 1);

      D := serialize_to_UTF8_xml (D);
    }
    Q := cast (xpath_eval ('/entry/link[@rel="alternate"]/@href', item, 1) as varchar);

    BMK.WA.bookmark_import_update (domain_id, Q, T, D, tags, folder_id, progress_id);
  }
}
;

-----------------------------------------------------
--
create procedure BMK.WA.bookmark_import_delicious(
  in domain_id integer,
  in folder_id integer,
  in tags varchar,
  in V any,
  in progress_id varchar)
{
  declare tmp, T, Q, D, H, nTags, TG, TGA any;
  declare N integer;

  if (V is null)
    return;

  N := 1;
  while (1)
  {
    Q := xpath_eval(sprintf('//post[%d]/@href',  N), V, 1);
    if (Q is null)
      goto _exit;
    T := BMK.WA.wide2utf(xpath_eval(sprintf('string(//post[%d]/@description)', N), V, 1));
    D := BMK.WA.wide2utf(xpath_eval(sprintf('string(//post[%d]/@extended)', N), V, 1));
    H := cast (xpath_eval(sprintf('//post[%d]/@hash',  N), V, 1) as varchar);
    commit work;

    nTags := '';
    TG := cast(xpath_eval(sprintf('string(//post[%d]/@tag)', N), V, 1) as varchar);
    if (TG <> 'system:unfiled')
    {
      TGA := split_and_decode(TG, 0, '\0\0 ');
      foreach (any tag in TGA) do
      {
        if (BMK.WA.validate_tag (tag))
          nTags := concat(nTags, tag, ',');
    }
    }
    nTags := trim(tags || ',' || nTags, ',');

    BMK.WA.bookmark_import_update (domain_id, Q, T, D, nTags, folder_id, progress_id);

    N := N + 1;
  }
_exit:
  return;
}
;

-------------------------------------------------------------------------------
--
create procedure BMK.WA.bookmark_import_update (
  in domain_id integer,
  in Q any,
  in T any,
  in D any,
  in tags varchar,
  in folder_id integer,
  in progress_id varchar)
{
  declare id, M integer;

  commit work;
    connection_set ('__bookmark_import', '1');
  id := BMK.WA.bookmark_update (-1, domain_id, cast (Q as varchar), cast (T as varchar), D, tags, folder_id);
    connection_set ('__bookmark_import', '0');

	  if (not is_empty_or_null (progress_id))
	  {
	    if  (cast(registry_get ('bookmark_action_' || progress_id) as varchar) = 'stop')
	      return;
	    M := cast (registry_get('bookmark_index_' || progress_id) as integer) + 1;
	    registry_set('bookmark_index_' || progress_id, cast (M as varchar));
    }
  return id;
}
;

-------------------------------------------------------------------------------
--
create procedure BMK.WA.bookmark_export (
  in domain_id integer,
  in folder_id integer := null,
  in options any := null)
{
  declare retValue any;
  declare tagsInclude, tagsExclude any;

  tagsInclude := null;
  tagsExclude := null;
  if (not isnull (options))
  {
    tagsInclude := get_keyword ('tagsInclude', options);
    tagsExclude := get_keyword ('tagsExclude', options);
  }

  retValue := string_output ();
  http('<?xml version ="1.0" encoding="UTF-8"?>\n', retValue);
  http(sprintf('<root name="Bookmarks" id="f#%d">', coalesce(folder_id, -1)), retValue);
  BMK.WA.bookmark_export_tmp (domain_id, folder_id, tagsInclude, tagsExclude, retValue);
  http('</root>', retValue);

  return string_output_string (retValue);
}
;

-------------------------------------------------------------------------------
--
create procedure BMK.WA.bookmark_export_tmp (
  in domain_id integer,
  in folder_id any,
  in tagsInclude any,
  in tagsExclude any,
  inout retValue any)
{
  declare id, type any;

  --  http (sprintf('<bookmark name="%V" desc="%V" uri="%V" id="f#%d" />', BD_NAME, coalesce(BD_DESCRIPTION, ''), B_URI, BD_ID), retValue);
  for (select a.*, b.B_URI from BMK.WA.BOOKMARK_DOMAIN a, BMK.WA.BOOKMARK b where a.BD_BOOKMARK_ID = b.B_ID and a.BD_DOMAIN_ID = domain_id and coalesce(a.BD_FOLDER_ID, -1) = coalesce(folder_id, -1) order by a.BD_NAME) do
  {
    if (BMK.WA.tags_exchangeTest (BD_TAGS, tagsInclude, tagsExclude))
    {
      http (sprintf('<bookmark name="%V" description="%V" uri="%V" id="%V" tags="%V">', BMK.WA.utf2wide (BD_NAME), BMK.WA.utf2wide (BD_DESCRIPTION), B_URI, BD_UID, BD_TAGS), retValue);
    if (coalesce(BD_DESCRIPTION, '') <> '')
      http (sprintf('<desc>%V</desc>', BD_DESCRIPTION), retValue);
    http ('</bookmark>', retValue);
  }
  }
  for (select F_ID, F_NAME from BMK.WA.FOLDER where F_DOMAIN_ID = domain_id and coalesce(F_PARENT_ID, -1) = coalesce(folder_id, -1) order by 2) do
  {
    http (sprintf('<folder name="%V" id="f#%d">', F_NAME, F_ID), retValue);
    BMK.WA.bookmark_export_tmp(domain_id, F_ID, tagsInclude, tagsExclude, retValue);
    http ('</folder>', retValue);
  }
}
;

-------------------------------------------------------------------------------
--
create procedure BMK.WA.bookmark_rights (
  in domain_id integer,
  in id integer,
  in access_role varchar)
{
  declare retValue varchar;

  retValue := '';
  if (exists (select 1 from BMK.WA.BOOKMARK_DOMAIN where BD_ID = id and BD_DOMAIN_ID = domain_id))
  {
    retValue := BMK.WA.acl_check (domain_id, id);
    if (retValue = '')
      retValue := access_role;
  }
  return retValue;
}
;

-------------------------------------------------------------------------------
--
-- Tags
--
-------------------------------------------------------------------------------
create procedure BMK.WA.bookmark_tags(
  inout domain_id integer,
  inout id integer,
  inout tags any)
{
  update BMK.WA.BOOKMARK_DOMAIN
       set BD_TAGS = tags,
         BD_UPDATED = now()
   where BD_DOMAIN_ID = domain_id
     and BD_ID = id;
}
;

-------------------------------------------------------------------------------
--
create procedure BMK.WA.tags_select(
  inout domain_id integer,
  inout id integer)
{
  return (select BD_TAGS from BMK.WA.BOOKMARK_DOMAIN where BD_DOMAIN_ID = domain_id and BD_ID = id);
}
;

-------------------------------------------------------------------------------
--
-- Last access
--
-------------------------------------------------------------------------------
create procedure BMK.WA.bookmark_visited (
  inout domain_id integer,
  inout id integer)
{
  return (select BD_VISITED from BMK.WA.BOOKMARK_DOMAIN where BD_DOMAIN_ID = domain_id and BD_ID = id);
}
;

-------------------------------------------------------------------------------
create procedure BMK.WA.bookmark_visited_set (
  inout domain_id integer,
  inout id integer,
  inout visited datetime := null)
{
  update BMK.WA.BOOKMARK_DOMAIN
     set BD_VISITED = visited
   where BD_DOMAIN_ID = domain_id
     and BD_ID = id;
}
;

-------------------------------------------------------------------------------
--
create procedure BMK.WA.folder_visited_set (
  inout domain_id integer,
  inout id integer,
  inout visited datetime := null)
{
  -- delete childs
  for (select F_ID from BMK.WA.FOLDER where F_PARENT_ID = id) do
    BMK.WA.folder_visited_set (domain_id, F_ID, visited);

  -- delete bookmarks
  for (select BD_ID from BMK.WA.BOOKMARK_DOMAIN where BD_FOLDER_ID = id) do
    BMK.WA.bookmark_visited_set (domain_id, BD_ID, visited);
}
;

-------------------------------------------------------------------------------
--
-- Folders
--
-------------------------------------------------------------------------------
create procedure BMK.WA.folder_id(
  in domain_id integer,
  in folder_name varchar)
{
  declare i, folder_id integer;
  declare aPath any;

  folder_id := null;
  if (not is_empty_or_null(folder_name))
  {
    aPath := split_and_decode(trim(folder_name, '/'),0,'\0\0/');
    for (i := 0; i < length(aPath); i := i + 1)
    {
      if (i = 0)
      {
        if (not exists (select 1 from BMK.WA.FOLDER where F_DOMAIN_ID = domain_id and F_NAME = aPath[i] and F_PARENT_ID is null))
          insert into BMK.WA.FOLDER (F_DOMAIN_ID, F_NAME, F_PATH) values (domain_id, aPath[i], '');
        folder_id := (select F_ID from BMK.WA.FOLDER where F_DOMAIN_ID = domain_id and F_NAME = aPath[i] and F_PARENT_ID is null);
      }
      else
      {
        if (not exists (select 1 from BMK.WA.FOLDER where F_DOMAIN_ID = domain_id and F_NAME = aPath[i] and F_PARENT_ID = folder_id))
          insert into BMK.WA.FOLDER (F_DOMAIN_ID, F_PARENT_ID, F_NAME, F_PATH) values (domain_id, folder_id, aPath[i], '');
        folder_id := (select F_ID from BMK.WA.FOLDER where F_DOMAIN_ID = domain_id and F_NAME = aPath[i] and F_PARENT_ID = folder_id);
      }
    }
  }
  return folder_id;
}
;

-------------------------------------------------------------------------------
--
create procedure BMK.WA.folder_create(
  inout domain_id varchar,
  in folder_name any,
  in folder_id any)
{
  folder_name := trim(folder_name);
  if (folder_name <> '')
  {
    folder_id := BMK.WA.folder_id(domain_id, folder_name);
  } else {
    folder_id := cast(folder_id as integer);
  }
  if (folder_id = 0)
    folder_id := null;

  return folder_id;
}
;

-------------------------------------------------------------------------------
--
create procedure BMK.WA.folder_create2(
  in domain_id varchar,
  in parent_id varchar,
  in folder_name any)
{
  declare folder_id integer;

  if (not exists (select 1 from BMK.WA.FOLDER where F_DOMAIN_ID = domain_id and F_NAME = folder_name and coalesce(F_PARENT_ID, -1) = coalesce(parent_id, -1)))
    insert into BMK.WA.FOLDER (F_DOMAIN_ID, F_PARENT_ID, F_NAME, F_PATH) values (domain_id, parent_id, folder_name, '');
  return (select F_ID from BMK.WA.FOLDER where F_DOMAIN_ID = domain_id and F_NAME = folder_name and coalesce(F_PARENT_ID, -1) = coalesce(parent_id, -1));
}
;

-------------------------------------------------------------------------------
--
create procedure BMK.WA.folder_parent(
  in folder_id integer,
  in parent_id integer)
{
  update BMK.WA.FOLDER set F_PARENT_ID = parent_id where F_ID = folder_id;
}
;

-------------------------------------------------------------------------------
--
create procedure BMK.WA.folder_delete(
  in domain_id integer,
  in folder_id integer)
{
  -- delete childs
  for (select F_ID from BMK.WA.FOLDER where F_DOMAIN_ID = domain_id and F_PARENT_ID = folder_id) do
    BMK.WA.folder_delete(domain_id, F_ID);

  -- delete bookmarks
  for (select BD_ID from BMK.WA.BOOKMARK_DOMAIN where BD_DOMAIN_ID = domain_id and BD_FOLDER_ID = folder_id) do
    BMK.WA.bookmark_delete(domain_id, BD_ID);

  -- delete folder at last
  delete from BMK.WA.FOLDER where F_DOMAIN_ID = domain_id and F_ID = folder_id;
  commit work;
}
;

-------------------------------------------------------------------------------
--
create procedure BMK.WA.folder_delete_all(
  in domain_id integer)
{
  for (select F_ID from BMK.WA.FOLDER where F_DOMAIN_ID = domain_id and coalesce(F_PARENT_ID, -1) = -1) do
    BMK.WA.folder_delete(domain_id, F_ID);
}
;

-------------------------------------------------------------------------------
--
create procedure BMK.WA.folder_name(
  in folder_id integer)
{
  return coalesce((select F_NAME from BMK.WA.FOLDER where F_ID = folder_id), '');
}
;

-------------------------------------------------------------------------------
--
create procedure BMK.WA.folder_path(
  in folder_id integer)
{
  return coalesce((select F_PATH from BMK.WA.FOLDER where F_ID = folder_id), '');
}
;

-------------------------------------------------------------------------------
--
create procedure BMK.WA.folder_path2(
  inout path varchar)
{
  declare aPath varchar;

  aPath := split_and_decode(path,0,'\0\0/');
  return concat(repeat('~', length(aPath)-1), aPath[length(aPath)-1]);
}
;

-------------------------------------------------------------------------------
--
create procedure BMK.WA.folder_path3(
  in folder_id integer,
  in grant_id integer)
{
  declare parent_id integer;
  declare path any;

  if (grant_id = -1)
  {
    path := coalesce(BMK.WA.folder_path (folder_id), '');
  } else {
    for (select G_OBJECT_TYPE, G_OBJECT_ID from BMK.WA.GRANTS where G_ID = grant_id) do
    {
      path := '';
      if (G_OBJECT_TYPE = 'F')
      {
        parent_id := (select F_PARENT_ID from BMK.WA.FOLDER where F_ID = G_OBJECT_ID);
        path := replace(coalesce(BMK.WA.folder_path (folder_id), ''), coalesce(BMK.WA.folder_path (parent_id), ''), '');
      }
    }
  }
  if (path <> '')
    return path;
  return '[Root Folder]';
}
;

-------------------------------------------------------------------------------
--
create procedure BMK.WA.folder_path4 (
  in folder_name varchar,
  in grant_id integer)
{
  declare parent_id integer;
  declare name any;

  if (grant_id = -1)
  {
    name := coalesce(folder_name, '');
  } else {
    for (select G_OBJECT_TYPE, G_OBJECT_ID from BMK.WA.GRANTS where G_ID = grant_id) do
    {
      name := case when G_OBJECT_TYPE = 'F' then coalesce(folder_name, '') else '' end;
    }
  }
  if (name <> '')
    return name;
  return '[Root Folder]';
}
;

-------------------------------------------------------------------------------
--
create procedure BMK.WA.folder_check_name(
  in folder_name varchar,
  in is_path integer := 0)
{
  if (is_path)
  {
    declare i integer;
    declare aPath any;

    aPath := split_and_decode(trim(folder_name, '/'),0,'\0\0/');
    for (i := 0; i < length(aPath); i := i + 1)
      if (not BMK.WA.validate('folder', aPath[i]))
        return 0;
    return 1;
  }
  return BMK.WA.validate('folder', folder_name);
}
;

-------------------------------------------------------------------------------
--
create procedure BMK.WA.folder_check_unique(
  in domain_id integer,
  in parent_id integer,
  in name varchar,
  in folder_id integer := 0)
{
  declare retValue integer;

  retValue := coalesce((select F_ID from BMK.WA.FOLDER where F_DOMAIN_ID=domain_id and coalesce(F_PARENT_ID, -1) = coalesce(parent_id, -1) and F_NAME=name), 0);
  if (folder_id = 0)
    return retValue;
  if (retValue = 0)
    return retValue;
  if (retValue <> folder_id)
    return 1;
  return 0;
}
;

-------------------------------------------------------------------------------
--
create procedure BMK.WA.folder_check_parent(
  in domain_id integer,
  in parent_id integer,
  in folder_id integer)
{
  declare new_id integer;

  if (folder_id = parent_id)
    return 1;

  new_id := (select F_PARENT_ID from BMK.WA.FOLDER where F_DOMAIN_ID = domain_id and F_ID = folder_id);
  if (isnull(new_id)) {
    if (isnull(parent_id))
      return 1;
    return 0;
  }

  if (new_id = parent_id)
    return 1;

  return BMK.WA.folder_check_parent(domain_id, parent_id, new_id);
}
;

-------------------------------------------------------------------------------
--
-- Smart folders
--
-------------------------------------------------------------------------------
create procedure BMK.WA.sfolder_sql(
  inout domain_id integer,
  inout account_id integer,
  inout account_rights varchar,
  in data varchar,
  in maxRows varchar := '',
  in nodeType varchar := 'b')
{
  declare S, T, tmp, where2, delimiter2 varchar;

  where2 := ' \n ';
  delimiter2 := '\n and ';

    S :=
      'select                              \n' ||
      '  distinct <MAX>                    \n' ||
      '  1                                                  _TYPE, \n' ||
      '  a.BD_ID                    _ID,   \n' ||
      '  BMK.WA.make_node (''<NODE_TYPE>'', a.BD_ID)        _NODE, \n' ||
      '  a.BD_NAME                  _NAME, \n' ||
      '  b.B_URI                    _URI,  \n' ||
    '  a.BD_VISITED                                       _VISITED, \n' ||
    '  a.BD_UPDATED                                       _UPDATED, \n' ||
      '  a.BD_CREATED                                       _CREATED, \n' ||
      '  a.BD_FOLDER_ID                                     _FOLDER_ID,   \n' ||
      '  d.F_NAME                                           _FOLDER_NAME,  \n' ||
      '  -1                                                 _GRANT_ID  \n' ||
      'from BMK.WA.BOOKMARK_DOMAIN a       \n' ||
      '       join BMK.WA.BOOKMARK b on b.B_ID = a.BD_BOOKMARK_ID \n' ||
      '        left join BMK.WA.FOLDER d on d.F_ID = a.BD_FOLDER_ID \n' ||
    'where a.BD_DOMAIN_ID = <DOMAIN_ID> <TEXT> <WHERE> \n';

  T := '';
  tmp := BMK.WA.xml_get('keywords', data);
  if (not is_empty_or_null(tmp)) {
    T := FTI_MAKE_SEARCH_STRING(tmp);
  } else {
    tmp := BMK.WA.xml_get('expression', data);
    if (not is_empty_or_null(tmp))
      T := tmp;
  }

  tmp := BMK.WA.xml_get('tags', data);
  if (not is_empty_or_null(tmp))
  {
    if (T = '') {
      T := BMK.WA.tags2search (tmp);
    } else {
      T := T || ' and ' || BMK.WA.tags2search (tmp);
    }
  }
  if (T <> '')
    S := replace(S, '<TEXT>', sprintf('and contains (a.BD_DESCRIPTION, \'[__lang "x-ViDoc"] %s\') \n', T));

  tmp := BMK.WA.xml_get('folder', data);
  if (not is_empty_or_null(tmp))
  {
    tmp := cast(tmp as integer);
    if (tmp > 0)
      BMK.WA.sfolder_sql_where (where2, delimiter2, sprintf('d.F_PATH like \'%s%s\'', BMK.WA.folder_path (tmp), '%'));
  }

  tmp := BMK.WA.xml_get('folderID', data);
  if (not is_empty_or_null(tmp))
  {
    tmp := cast (tmp as integer);
    BMK.WA.sfolder_sql_where (where2, delimiter2, sprintf ('coalesce(a.BD_FOLDER_ID, -1) = %d', tmp));
  }

  tmp := BMK.WA.xml_get('bookmark', data);
  if (not is_empty_or_null(tmp))
  {
    tmp := cast(tmp as integer);
    if (tmp > 0)
      BMK.WA.sfolder_sql_where (where2, delimiter2, sprintf('a.BD_ID = %d', tmp));
  }

  tmp := BMK.WA.xml_get('updatedAfter', data);
  if (not is_empty_or_null(tmp))
  {
    BMK.WA.sfolder_sql_where (where2, delimiter2, sprintf ('a.BD_UPDATED >= \'%s\'', tmp));
  }

  tmp := BMK.WA.xml_get('updatedBefore', data);
  if (not is_empty_or_null(tmp))
  {
    BMK.WA.sfolder_sql_where (where2, delimiter2, sprintf ('a.BD_UPDATED <= \'%s\'', tmp));
  }

  if (account_rights = '')
  {
    if (is_https_ctx ())
    {
      S := S || '   and SIOC..bmk_post_iri (a.BD_DOMAIN_ID, a.BD_ID) in (select s.iri from BMK.WA.acl_list (id)(iri varchar) s where s.id = a.BD_DOMAIN_ID)';
    } else {
      S := S || '   and 1=0';
    }
  }
  if (maxRows <> '')
    maxRows := 'TOP ' || maxRows;
  S := replace(S, '<MAX>', maxRows);
  S := replace(S, '<NODE_TYPE>', nodeType);
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
create procedure BMK.WA.shared_sql(
  inout domain_id integer,
  inout account_id integer,
  inout account_rights varchar,
  in data any,
  in maxRows varchar := '')
{
  declare N, gid, did, aid, fid, bid, own, shared integer;
  declare grants, newData any;
  declare c0 integer;
  declare c1 integer;
  declare c2 varchar;
  declare c3 varchar;
  declare c4 varchar;
  declare c5 datetime;
  declare c6 datetime;
  declare c7 datetime;
  declare c8 integer;
  declare c9 varchar;
  declare c10 integer;

  declare sql, state, msg, meta, rows any;

  result_names(c0, c1, c2, c3, c4, c5, c6, c7, c8, c9, c10);

  own := cast (BMK.WA.xml_get ('myBookmarks', data, '1') as integer);
  shared := cast (BMK.WA.xml_get ('mySharedBookmarks', data, '0') as integer);

  -- search in my own
  if (own = 1)
  {
    state := '00000';
    sql := BMK.WA.sfolder_sql (domain_id, account_id, account_rights, data, maxRows);
    exec(sql, state, msg, vector(), 0, meta, rows);
    if (state = '00000')
      foreach (any row in rows) do
      {
        result(row[0], row[1], row[2], row[3], row[4], row[5], row[6], row[7], row[8], row[9], row[10]);
  }
  }

  -- search in my shared
  if (shared = 1)
  {
    grants := BMK.WA.xml_get ('grants', data);
    grants := split_and_decode(trim(grants, ','), 0, '\0\0,');
    for (select G_ID as _GID from BMK..GRANTS_OBJECT_VIEW where GOW_TO = account_id) do
    {
      for (select G_ID, G_GRANTER_ID, G_OBJECT_TYPE, G_OBJECT_ID, U_NAME
             from BMK.WA.GRANTS, DB.DBA.SYS_USERS
            where G_ID = _GID) do
    {
      if (length(grants) and not BMK.WA.vector_contains(grants, U_NAME))
        goto _skip;

    newData := data;
    gid := G_ID;
    aid := G_GRANTER_ID;
      fid := -1;
    bid := 0;
      if (G_OBJECT_TYPE = 'F')
      {
      fid := G_OBJECT_ID;
      did := (select F_DOMAIN_ID from BMK.WA.FOLDER where F_ID = fid);
    } else {
      bid := G_OBJECT_ID;
      did := (select BD_DOMAIN_ID from BMK.WA.BOOKMARK_DOMAIN where BD_ID = bid);
    }
    BMK.WA.xml_set('folder', newData, fid);
    BMK.WA.xml_set('bookmark', newData, bid);

    state := '00000';
      sql := BMK.WA.sfolder_sql (did, aid, account_rights, newData, maxRows, 'B');
    exec(sql, state, msg, vector(), 0, meta, rows);
    if (state = '00000')
        foreach (any row in rows) do
        {
          fid := row[8];
        if (bid <> 0)
            fid := -1;
          result(row[0], row[1], row[2], row[3], row[4], row[5], row[6], row[7], fid, row[9], gid);
      }
    _skip:;
  }
}
}
}
;

-------------------------------------------------------------------------------
--
create procedure BMK.WA.shareNode (
  in account_id integer,
  in node varchar,
  in grants varchar,
  in override integer)
{
  declare N, pos, id integer;
  declare name, V any;

  grants := replace(grants, ' ', '');
  grants := replace(grants, ',,', ',');
  grants := trim (grants, ',', '');
  grants := grants || ',';
  for (select U_ID, U_NAME from BMK.WA.GRANTS, DB.DBA.SYS_USERS where G_GRANTER_ID = account_id and G_GRANTEE_ID = U_ID and lcase(G_OBJECT_TYPE) = lcase(BMK.WA.node_type (node)) and G_OBJECT_ID = BMK.WA.node_id (node)) do
  {
    name := U_NAME;
    id := U_ID;
    pos := strstr(grants, name || ',');
    if (isnull(pos))
    {
      if (override)
        delete from BMK.WA.GRANTS where G_GRANTER_ID = account_id and G_GRANTEE_ID = id and lcase(G_OBJECT_TYPE) = lcase(BMK.WA.node_type (node)) and G_OBJECT_ID = BMK.WA.node_id (node);
    } else {
      grants := replace(grants, name || ',', '');
    }
  }
  V := split_and_decode(trim (grants, ','), 0, '\0\0,');
  for (N := 0; N < length(V); N := N + 1)
  {
    id := (select U_ID from SYS_USERS where U_NAME = V[N]);
    if (not isnull(id))
      insert into BMK.WA.GRANTS (G_GRANTER_ID, G_GRANTEE_ID, G_TYPE, G_OBJECT_TYPE, G_OBJECT_ID)
        values(account_id, id, 'G', ucase(BMK.WA.node_type (node)), BMK.WA.node_id (node));
  }
}
;

-------------------------------------------------------------------------------
--
create procedure BMK.WA.sfolder_sql_where(
  inout where2 varchar,
  inout delimiter varchar,
  in criteria varchar)
{
  if (criteria <> '')
  {
    if (where2 = '')
      where2 := 'where ';
    where2 := concat(where2, delimiter, criteria);
    delimiter := '\n and ';
  }
}
;
-------------------------------------------------------------------------------
--
create procedure BMK.WA.sfolder_create(
  in domain_id integer,
  in name varchar,
  in data varchar)
{
  declare id varchar;

  id := coalesce((select SF_ID from BMK.WA.SFOLDER where SF_DOMAIN_ID = domain_id and SF_NAME = name), -1);
  if (id = -1)
  {
    insert into BMK.WA.SFOLDER (SF_DOMAIN_ID, SF_NAME, SF_DATA)
      values(domain_id, name, data);
  } else {
    update BMK.WA.SFOLDER
       set SF_DATA = data
     where SF_ID = id;
  }
  return (select SF_ID from BMK.WA.SFOLDER where SF_DOMAIN_ID = domain_id and SF_NAME = name);
}
;

-------------------------------------------------------------------------------
--
create procedure BMK.WA.sfolder_update(
  in domain_id integer,
  in id varchar,
  in name varchar,
  in data varchar)
{
  update BMK.WA.SFOLDER
     set SF_NAME = name,
         SF_DATA = data
   where SF_ID = id
     and SF_DOMAIN_ID = domain_id;
}
;

-------------------------------------------------------------------------------
--
create procedure BMK.WA.sfolder_delete(
  in domain_id integer,
  in folder_id integer)
{
  delete from BMK.WA.SFOLDER where SF_DOMAIN_ID = domain_id and SF_ID = folder_id;
}
;

-------------------------------------------------------------------------------
--
create procedure BMK.WA.sfolder_name (
  in sfolder_id integer)
{
  return coalesce((select SF_NAME from BMK.WA.SFOLDER where SF_ID = sfolder_id), '');
}
;

-------------------------------------------------------------------------------
--
create procedure BMK.WA.tag_prepare(
  inout tag varchar)
{
  if (not is_empty_or_null(tag))
  {
    tag := trim(tag);
    tag := replace(tag, '  ', ' ');
  }
  return tag;
}
;

-------------------------------------------------------------------------------
--
create procedure BMK.WA.tag_delete(
  inout tags varchar,
  inout T integer)
{
  declare N integer;
  declare tags2 any;

  tags2 := BMK.WA.tags2vector(tags);
  tags := '';
  for (N := 0; N < length(tags2); N := N + 1)
    if (N <> T)
      tags := concat(tags, ',', tags2[N]);
  return trim(tags, ',');
}
;

-------------------------------------------------------------------------------
--
create procedure BMK.WA.tag_id (
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
create procedure BMK.WA.tags_join(
  inout tags varchar,
  inout tags2 varchar)
{
  declare resultTags any;

  if (is_empty_or_null(tags))
    tags := '';
  if (is_empty_or_null(tags2))
    tags2 := '';

  resultTags := concat(tags, ',', tags2);
  resultTags := BMK.WA.tags2vector(resultTags);
  resultTags := BMK.WA.tags2unique(resultTags);
  resultTags := BMK.WA.vector2tags(resultTags);
  return resultTags;
}
;

---------------------------------------------------------------------------------
--
create procedure BMK.WA.tags2vector(
  inout tags varchar)
{
  return split_and_decode(trim(tags, ','), 0, '\0\0,');
}
;

---------------------------------------------------------------------------------
--
create procedure BMK.WA.tags2search(
  in tags varchar)
{
  declare S varchar;
  declare V any;

  S := '';
  V := BMK.WA.tags2vector(tags);
  foreach (any tag in V) do
    S := concat(S, ' ^T', replace (replace (trim(lcase(tag)), ' ', '_'), '+', '_'));
  return FTI_MAKE_SEARCH_STRING(trim(S, ','));
}
;

-------------------------------------------------------------------------------
--
create procedure BMK.WA.vector2tags(
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
create procedure BMK.WA.tags2unique(
  inout aVector any)
{
  declare aResult any;
  declare N, M integer;

  aResult := vector();
  for (N := 0; N < length(aVector); N := N + 1)
  {
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
create procedure BMK.WA.tags2delicious (
  inout tags varchar)
{
  declare aVector any;
  declare aResult varchar;
  declare N, M integer;

  aResult := '';
  aVector := BMK.WA.tags2vector(tags);
  for (N := 0; N < length(aVector); N := N + 1)
  {
    aResult := aResult || ' ' || replace(aVector[N], ' ', '_');
  }
  return aResult;
}
;

-------------------------------------------------------------------------------
--
create procedure BMK.WA.tags_exchangeTest (
  inout tagsEntry any,
  inout tagsInclude any := null,
  inout tagsExclude any := null)
{
  declare N integer;
  declare tags, testTags any;

  if (is_empty_or_null (tagsEntry) and not is_empty_or_null (tagsInclude))
    goto _false;

  -- test exclude tags
  if (is_empty_or_null (tagsExclude))
    goto _include;
  if (is_empty_or_null (tagsEntry))
    goto _include;
  tags := BMK.WA.tags2vector (tagsEntry);
  testTags := BMK.WA.tags2vector (tagsExclude);
  for (N := 0; N < length (tags); N := N + 1)
  {
    if (BMK.WA.vector_contains (testTags, tags [N]))
      goto _false;
  }

_include:;
  -- test include tags
  if (is_empty_or_null (tagsInclude))
    goto _true;
  tags := BMK.WA.tags2vector (tagsEntry);
  testTags := BMK.WA.tags2vector (tagsInclude);
  for (N := 0; N < length (tags); N := N + 1)
  {
    if (BMK.WA.vector_contains (testTags, tags [N]))
      goto _true;
  }

_false:;
  return 0;

_true:;
  return 1;
}
;

-------------------------------------------------------------------------------
--
create procedure BMK.WA.settings (
  inout domain_id integer)
{
  return coalesce((select deserialize (blob_to_string (S_DATA)) from BMK.WA.SETTINGS where S_DOMAIN_ID = domain_id), vector ());
}
;

-------------------------------------------------------------------------------
--
create procedure BMK.WA.settings_init (
  inout settings any)
{
  BMK.WA.set_keyword ('chars', settings, cast (get_keyword ('chars', settings, '60') as integer));
  BMK.WA.set_keyword ('rows', settings, cast (get_keyword ('rows', settings, '10') as integer));
  BMK.WA.set_keyword ('tbLabels', settings, cast (get_keyword ('tbLabels', settings, '1') as integer));
  BMK.WA.set_keyword ('atomVersion', settings, get_keyword ('atomVersion', settings, '1.0'));
  BMK.WA.set_keyword ('conv', settings, cast (get_keyword ('conv', settings, '0') as integer));
  BMK.WA.set_keyword ('conv_init', settings, cast (get_keyword ('conv_init', settings, '0') as integer));
  BMK.WA.set_keyword ('panes', settings, cast (get_keyword ('panes', settings, '0') as integer));
  BMK.WA.set_keyword ('bookmarkOpen', settings, cast (get_keyword ('bookmarkOpen', settings, '0') as integer));
}
;

-------------------------------------------------------------------------------
--
create procedure BMK.WA.settings_chars (
  inout settings any)
{
  return cast(get_keyword('chars', settings, '60') as integer);
}
;

-------------------------------------------------------------------------------
--
create procedure BMK.WA.settings_rows (
  inout settings any)
{
  return cast(get_keyword('rows', settings, '10') as integer);
}
;

-------------------------------------------------------------------------------
--
create procedure BMK.WA.settings_atomVersion (
  inout settings any)
{
  return get_keyword('atomVersion', settings, '1.0');
}
;

-----------------------------------------------------------------------------
--
create procedure BMK.WA.dav_home(
  inout account_id integer) returns varchar
{
  declare name, home any;
  declare cid integer;

  name := coalesce((select U_NAME from DB.DBA.SYS_USERS where U_ID = account_id), -1);
  if (isinteger(name))
    return null;
  home := BMK.WA.dav_home_create(name);
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
create procedure BMK.WA.dav_home_create(
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
create procedure BMK.WA.dav_logical_home (
  inout account_id integer) returns varchar
{
  declare home any;

  home := BMK.WA.dav_home (account_id);
  if (not isnull (home))
    home := replace (home, '/DAV', '');
  return home;
}
;

-------------------------------------------------------------------------------
--
create procedure BMK.WA.host_protocol ()
{
  return case when is_https_ctx () then 'https://' else 'http://' end;
}
;

-------------------------------------------------------------------------------
--
create procedure BMK.WA.host_url ()
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
  if (host not like BMK.WA.host_protocol () || '%')
    host := BMK.WA.host_protocol () || host;

  return host;
}
;

-------------------------------------------------------------------------------
--
create procedure BMK.WA.bookmarks_url (
  in domain_id integer)
{
  return concat(BMK.WA.host_url(), '/bookmark/', cast(domain_id as varchar), '/');
}
;

-------------------------------------------------------------------------------
--
create procedure BMK.WA.dav_url (
  in domain_id integer)
{
  declare home varchar;

  home := BMK.WA.dav_home (BMK.WA.domain_owner_id (domain_id));
  if (isnull(home))
    return '';
  return concat ('http://', DB.DBA.wa_cname (), home, 'BM/', BMK.WA.domain_gems_name(domain_id), '/');
}
;

-------------------------------------------------------------------------------
--
create procedure BMK.WA.dav_url2 (
  in domain_id integer,
  in account_id integer)
{
  declare home varchar;

  home := BMK.WA.dav_home(account_id);
  if (isnull(home))
    return '';
  return replace(concat(home, 'BM/', BMK.WA.domain_gems_name(domain_id), '/'), ' ', '%20');
}
;

-------------------------------------------------------------------------------
--
create procedure BMK.WA.sioc_url (
  in domain_id integer)
{
  return sprintf('http://%s/dataspace/%U/bookmark/%U/sioc.rdf', DB.DBA.wa_cname (), BMK.WA.domain_owner_name (domain_id), replace (BMK.WA.domain_name (domain_id), '+', '%2B'));
}
;

-------------------------------------------------------------------------------
--
create procedure BMK.WA.gems_url (
  in domain_id integer)
{
  return sprintf('http://%s/dataspace/%U/bookmark/%U/gems/', DB.DBA.wa_cname (), BMK.WA.domain_owner_name (domain_id), replace (BMK.WA.domain_name (domain_id), '+', '%2B'));
}
;

-------------------------------------------------------------------------------
--
create procedure BMK.WA.foaf_url (
  in domain_id integer)
{
  return SIOC..person_iri (sprintf('http://%s%s/%s#this', SIOC..get_cname (), SIOC..get_base_path (), BMK.WA.domain_owner_name (domain_id)), '/about.rdf');
}
;

-------------------------------------------------------------------------------
--
create procedure BMK.WA.geo_url (
  in domain_id integer,
  in account_id integer)
{
  for (select WAUI_LAT, WAUI_LNG from WA_USER_INFO where WAUI_U_ID = account_id) do
    if ((not isnull(WAUI_LNG)) and (not isnull(WAUI_LAT)))
      return sprintf('\n    <meta name="ICBM" content="%.2f, %.2f"><meta name="DC.title" content="%s">', WAUI_LNG, WAUI_LAT, BMK.WA.domain_name (domain_id));
  return '';
}
;

-------------------------------------------------------------------------------
--
create procedure BMK.WA.bookmark_url (
  in domain_id integer,
  in bookmark_id integer)
{
  return concat (BMK.WA.bookmarks_url (domain_id), 'bookmarks.vspx?id=', cast (bookmark_id as varchar));
}
;

-------------------------------------------------------------------------------
--
create procedure BMK.WA.banner_links (
  in domain_id integer,
  in sid varchar := null,
  in realm varchar := null)
{
  if (domain_id <= 0)
    return 'Public Bookmarks';

  return sprintf ('<a href="%s" title="%s" onclick="javascript: return myA(this);">%V</a> (<a href="%s" title="%s" onclick="javascript: return myA(this);">%V</a>)',
                  BMK.WA.domain_sioc_url (domain_id),
                  BMK.WA.domain_name (domain_id),
                  BMK.WA.domain_name (domain_id),
                  BMK.WA.account_sioc_url (domain_id),
                  BMK.WA.account_fullName (BMK.WA.domain_owner_id (domain_id)),
                  BMK.WA.account_fullName (BMK.WA.domain_owner_id (domain_id))
                 );
}
;

-------------------------------------------------------------------------------
--
create procedure BMK.WA.dav_content (
  in uri varchar,
  in auth_uid varchar := null,
  in auth_pwd varchar := null)
{
  declare content varchar;
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
  BMK.WA.account_access (auth_uid, auth_pwd);
  reqHdr := sprintf('Authorization: Basic %s', encode_base64(auth_uid || ':' || auth_pwd));

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

  return (content);
}
;

-------------------------------------------------------------------------------
--
create procedure BMK.WA.xslt_root()
{
  declare sHost varchar;

  sHost := cast(registry_get('_bookmark_path_') as varchar);
  if (sHost = '0')
    return 'file://apps/bookmark/xslt/';
  if (isnull(strstr(sHost, '/DAV/VAD')))
    return sprintf('file://%sxslt/', sHost);
  return sprintf('virt://WS.WS.SYS_DAV_RES.RES_FULL_PATH.RES_CONTENT:%sxslt/', sHost);
}
;

-------------------------------------------------------------------------------
--
create procedure BMK.WA.xslt_full(
  in xslt_file varchar)
{
  return concat(BMK.WA.xslt_root(), xslt_file);
}
;

-------------------------------------------------------------------------------
--
create procedure BMK.WA.iri_fix (
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
create procedure BMK.WA.url_fix (
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

-----------------------------------------------------------------------------------------
--
create procedure BMK.WA.uid ()
{
  return sprintf ('%s@%s', uuid (), sys_stat ('st_host_name'));
}
;

--------------------------------------------------------------------------------
--
create procedure BMK.WA.exchange_exec (
  in _id integer,
  in _mode integer := 0,
  in _exMode integer := null)
{
  declare retValue any;

  declare exit handler for SQLSTATE '*'
  {
    update BMK.WA.EXCHANGE
       set EX_EXEC_LOG = __SQL_STATE || ' ' || BMK.WA.test_clear (__SQL_MESSAGE)
     where EX_ID = _id;
    commit work;

    if (_mode)
      resignal;
  };

  retValue := BMK.WA.exchange_exec_internal (_id, _exMode);

  update BMK.WA.EXCHANGE
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
create procedure BMK.WA.exchange_entry_update (
  in _domain_id integer)
{
  for (select EX_ID as _id from BMK.WA.EXCHANGE where EX_DOMAIN_ID = _domain_id and EX_TYPE = 0 and EX_UPDATE_TYPE = 1) do
  {
    if (connection_get ('__bookmark_import') = '1')
    {
      update BMK.WA.EXCHANGE
         set EX_UPDATE_SUBTYPE = 1
       where EX_ID = _id;
    } else {
      BMK.WA.exchange_exec (_id);
    }
  }
}
;

--------------------------------------------------------------------------------
--
create procedure BMK.WA.exchange_exec_internal (
  in _id integer,
  in _exMode integer := null)
{
  for (select EX_DOMAIN_ID as _domain_id, EX_TYPE as _direction, deserialize (EX_OPTIONS) as _options from BMK.WA.EXCHANGE where EX_ID = _id) do
  {
    declare _type, _name, _pName, _user, _password, _tagsInclude, _tagsExclude, _tags, _folderPath, _folder_id any;
    declare _content any;

    _type := get_keyword ('type', _options);
    _name := get_keyword ('name', _options);
    _user := get_keyword ('user', _options);
    _password := get_keyword ('password', _options);
    _tagsInclude := get_keyword ('tagsInclude', _options);
    _tagsExclude := get_keyword ('tagsExclude', _options);
    _tags := get_keyword ('tags', _options);
    _folderPath := get_keyword ('folderPath', _options);
    _folder_id := BMK.WA.folder_create (_domain_id, _folderPath, null);

    -- publish
    if (_direction = 0)
    {
      if ((_type = 1) or (_type = 2))
      {
      _content := BMK.WA.export_netscape (_domain_id, _folder_id, _options);
      if (_type = 1)
      {
        declare retValue, permissions any;
        {
          declare exit handler for SQLSTATE '*'
          {
            signal ('BMK02', 'The export/publication did not pass successfully. Please verify the path and parameters values!<>');
          };
          permissions := BMK.WA.dav_permissions (_name, _user, _password);
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
          retValue := DB.DBA.DAV_RES_UPLOAD (_name, _content, 'text/html', permissions, _user, null, _user, _password);
          if (DB.DBA.DAV_HIDE_ERROR (retValue) is null)
          {
            signal ('BMK01', 'WebDAV: ' || DB.DBA.DAV_PERROR (retValue) || '.<>');
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
            signal ('BMK02', 'Connection Error in HTTP Client!<>');
          };
          retContent := http_get (_name, resHeader, 'PUT', reqHeader, _content);
          if (not (length (resHeader) > 0 and (resHeader[0] like 'HTTP/1._ 2__ %' or  resHeader[0] like 'HTTP/1._ 3__ %')))
          {
            signal ('BMK02', 'The export/publication did not pass successfully. Please verify the path and parameters values!<>');
          }
        }
      }
    }
      else if (_type = 3)
      {
        -- Delicious
        declare rc, path, tmp, xt, posts any;

        _name := 'https://api.del.icio.us/v1/posts/add?replace=yes';
        _content := BMK.WA.bookmark_export (_domain_id, _folder_id, _options);
        xt := xml_tree_doc (xml_tree (_content));
        posts := xpath_eval ('//bookmark', xt, 0);
        foreach (any post in posts) do
        {
          commit work;
          path := _name;
          tmp := cast (xpath_eval ('@uri', post) as varchar);
          if (not is_empty_or_null (tmp))
            path := sprintf ('%s&url=%U', path, tmp);
          tmp := cast (xpath_eval ('@name', post) as varchar);
          if (not is_empty_or_null (tmp))
            path := sprintf ('%s&description=%U', path, tmp);
          tmp := cast (xpath_eval ('@description', post) as varchar);
          if (not is_empty_or_null (tmp))
            path := sprintf ('%s&extended=%U', path, tmp);
          tmp := cast (xpath_eval ('@tags', post) as varchar);
          if (not is_empty_or_null (tmp))
            path := sprintf ('%s&tags=%U', path, BMK.WA.tags2delicious(tmp));

          rc := http_client (path, _user, _password, 'POST', null, null, null, null);
        }
      }
    }
    -- subscribe
    else if (_direction = 1)
    {
      if (_type = 1)
      {
        _name := BMK.WA.host_url () || _name;
        _content := BMK.WA.dav_content (_name, _user, _password);
      }
      else if (_type = 2)
      {
      _content := BMK.WA.dav_content (_name, _user, _password);
      }
      else if (_type = 3)
      {
        -- Delicious

        _name := 'https://api.del.icio.us/v1/posts/all';
        _content := http_client (_name, _user, _password, 'GET', null, null, null, null);
        if (not is_empty_or_null (xpath_eval('string(//title)', xml_tree_doc (xml_tree (_content, 2)))))
        {
          _content := null;
        }
      }
      if (isnull(_content))
      {
        signal ('BMK01', 'Bad import/subscription source!<>');
      }
      BMK.WA.bookmark_import (_content, _domain_id, _folder_id, _tags);
    }
  }
}
;

--------------------------------------------------------------------------------
--
create procedure BMK.WA.exchange_scheduler ()
{
  declare id, days, rc, err integer;
  declare bm any;

  declare _error integer;
  declare _bookmark any;
  declare _dt datetime;
  declare exID any;

  _dt := now ();
  declare cr static cursor for select EX_ID
                                 from BMK.WA.EXCHANGE
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
      BMK.WA.exchange_exec (exID, 1);
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
create procedure BMK.WA.dav_check_authenticate (
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
create procedure BMK.WA.dav_parent (
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
create procedure BMK.WA.dav_permissions (
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
    path := BMK.WA.dav_parent (path);
    if (path <> BMK.WA.dav_home (BMK.WA.account_id (auth_name)))
      permissions := DB.DBA.DAV_PROP_GET (path, ':virtpermissions', auth_name, auth_pwd);
    if (permissions < 0)
      permissions := USER_GET_OPTION (auth_name, 'PERMISSIONS');
  }
  return permissions;
}
;

-------------------------------------------------------------------------------
--
create procedure BMK.WA.export_netscape (
  in domain_id integer,
  in folder_id integer,
  in options any)
{
  declare retValue any;

  retValue := string_output ();
  http_value (xslt (BMK.WA.xslt_full ('Netscape.xsl'), xtree_doc (BMK.WA.bookmark_export (domain_id, folder_id, options))), null, retValue);
  return string_output_string (retValue);
}
;

-------------------------------------------------------------------------------
--
create procedure BMK.WA.export_xbel (
  in domain_id integer,
  in options any)
{
  declare retValue any;

  retValue := string_output ();
  http_value (xslt (BMK.WA.xslt_full ('XBEL.xsl'), xtree_doc (BMK.WA.bookmark_export (domain_id, null, options))), null, retValue);
  return string_output_string (retValue);
}
;

-------------------------------------------------------------------------------
--
create procedure BMK.WA.export_rss_sqlx_int(
  in domain_id integer,
  in account_id integer)
{
  declare retValue any;

  retValue := string_output ();

  http('<?xml version ="1.0" encoding="UTF-8"?>\n', retValue);
  http('<rss version="2.0">\n', retValue);
  http('<channel>\n', retValue);

  http('<sql:sqlx xmlns:sql="urn:schemas-openlink-com:xml-sql" sql:xsl=""><![CDATA[\n', retValue);
  http('select \n', retValue);
  http('  XMLELEMENT(\'title\', BMK.WA.utf2wide(BMK.WA.domain_name(<DOMAIN_ID>))), \n', retValue);
  http('  XMLELEMENT(\'description\', BMK.WA.utf2wide(BMK.WA.domain_description(<DOMAIN_ID>))), \n', retValue);
  http ('  XMLELEMENT(\'managingEditor\', BMK.WA.utf2wide (U_FULL_NAME || \' <\' || U_E_MAIL || \'>\')), \n', retValue);
  http('  XMLELEMENT(\'pubDate\', BMK.WA.dt_rfc1123(now())), \n', retValue);
  http('  XMLELEMENT(\'generator\', \'Virtuoso Universal Server \' || sys_stat(\'st_dbms_ver\')), \n', retValue);
  http('  XMLELEMENT(\'webMaster\', U_E_MAIL), \n', retValue);
  http ('  XMLELEMENT(\'link\', BMK.WA.bookmarks_url(<DOMAIN_ID>)), \n', retValue);
  http ('  (select XMLAGG (XMLELEMENT(\'http://www.w3.org/2005/Atom:link\', XMLATTRIBUTES (SH_URL as "href", \'hub\' as "rel", \'PubSubHub\' as "title"))) from ODS.DBA.SVC_HOST, ODS.DBA.APP_PING_REG where SH_PROTO = \'PubSubHub\' and SH_ID = AP_HOST_ID and AP_WAI_ID = <DOMAIN_ID>), \n', retValue);
  http ('  XMLELEMENT(\'language\', \'en-us\') \n', retValue);
  http('from DB.DBA.SYS_USERS where U_ID = <USER_ID> \n', retValue);
  http(']]></sql:sqlx>\n', retValue);

  http('<sql:sqlx xmlns:sql=\'urn:schemas-openlink-com:xml-sql\'><![CDATA[\n', retValue);
  http('select \n', retValue);
  http('  XMLAGG(XMLELEMENT(\'item\', \n', retValue);
  http('    XMLELEMENT(\'title\', BMK.WA.utf2wide(BD_NAME)), \n', retValue);
  http('    XMLELEMENT(\'description\', BMK.WA.utf2wide(BD_DESCRIPTION)), \n', retValue);
  http('    XMLELEMENT(\'guid\', B_ID), \n', retValue);
  http('    XMLELEMENT(\'link\', B_URI), \n', retValue);
  http ('    XMLELEMENT(\'pubDate\', BMK.WA.dt_rfc1123 (BD_UPDATED)), \n', retValue);
  http ('    (select XMLAGG (XMLELEMENT (\'category\', BTV_TAG)) from BMK..TAGS_VIEW where domain_id = <DOMAIN_ID> and account_id = <USER_ID> and item_id = B_ID), \n', retValue);
  http ('    XMLELEMENT(\'http://www.openlinksw.com/ods/:modified\', BMK.WA.dt_iso8601 (BD_UPDATED)))) \n', retValue);
  http('from (select top 15  \n', retValue);
  http('        BD_NAME, \n', retValue);
  http('        BD_DESCRIPTION, \n', retValue);
  http ('        BD_UPDATED, \n', retValue);
  http('        B_ID, \n', retValue);
  http('        B_URI \n', retValue);
  http('      from \n', retValue);
  http('        BMK.WA.BOOKMARK, \n', retValue);
  http('        BMK.WA.BOOKMARK_DOMAIN \n', retValue);
  http('      where BD_BOOKMARK_ID = B_ID  \n', retValue);
  http('        and BD_DOMAIN_ID = <DOMAIN_ID> \n', retValue);
  http ('      order by BD_UPDATED desc) x \n', retValue);
  http(']]></sql:sqlx>\n', retValue);

  http('</channel>\n', retValue);
  http('</rss>\n', retValue);

  retValue := string_output_string (retValue);
  retValue := replace(retValue, '<USER_ID>', cast(account_id as varchar));
  retValue := replace(retValue, '<DOMAIN_ID>', cast(domain_id as varchar));
  return retValue;
}
;

-------------------------------------------------------------------------------
--
create procedure BMK.WA.export_rss_sqlx(
  in domain_id integer,
  in account_id integer)
{
  declare retValue any;

  retValue := BMK.WA.export_rss_sqlx_int(domain_id, account_id);
  return replace (retValue, 'sql:xsl=""', '');
}
;

-------------------------------------------------------------------------------
--
create procedure BMK.WA.export_atom_sqlx(
  in domain_id integer,
  in account_id integer)
{
  declare retValue, xsltTemplate any;

  xsltTemplate := BMK.WA.xslt_full ('rss2atom03.xsl');
  if (BMK.WA.settings_atomVersion (BMK.WA.settings (domain_id)) = '1.0')
  {
    xsltTemplate := BMK.WA.xslt_full ('rss2atom.xsl');
  }
  retValue := BMK.WA.export_rss_sqlx_int(domain_id, account_id);
  return replace (retValue, 'sql:xsl=""', sprintf('sql:xsl="%s"', xsltTemplate));
}
;

-------------------------------------------------------------------------------
--
create procedure BMK.WA.export_rdf_sqlx(
  in domain_id integer,
  in account_id integer)
{
  declare retValue any;

  retValue := BMK.WA.export_rss_sqlx_int(domain_id, account_id);
  return replace (retValue, 'sql:xsl=""', sprintf('sql:xsl="%s"', BMK.WA.xslt_full ('rss2rdf.xsl')));
}
;

-------------------------------------------------------------------------------
--
create procedure BMK.WA.export_ocs_sqlx(
  in domain_id integer,
  in account_id integer)
{
  declare retValue any;

  retValue := string_output ();

  http('<?xml version =\'1.0\' encoding=\'UTF-8\'?>\n', retValue);
  http('<rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#" xmlns:ocs="http://InternetAlchemy.org/ocs/directory#" xmlns:dc="http://purl.org/metadata/dublin_core#" xmlns:sql=\'urn:schemas-openlink-com:xml-sql\'>\n', retValue);
  http('<rdf:description about="">', retValue);

  http('<sql:sqlx><![CDATA[\n', retValue);
  http('select \n', retValue);
  http('  XMLELEMENT(\'http://purl.org/metadata/dublin_core#:title\', BMK.WA.utf2wide(BMK.WA.user_name(U_NAME, U_FULL_NAME))), \n', retValue);
  http('  XMLELEMENT(\'http://purl.org/metadata/dublin_core#:creator\', U_E_MAIL), \n', retValue);
  http('  XMLELEMENT(\'http://purl.org/metadata/dublin_core#:description\', \'\') \n', retValue);
  http('from WS.WS.SYS_DAV_USER\n', retValue);
  http('where U_ID = <USER_ID>\n', retValue);
  http(']]></sql:sqlx>\n', retValue);

  http('<sql:sqlx><![CDATA[\n', retValue);
  http('select \n', retValue);
  http('  XMLELEMENT(\'http://www.w3.org/1999/02/22-rdf-syntax-ns#:description\', \n', retValue);
  http('  XMLATTRIBUTES(B_URI as \'about\'), \n', retValue);
  http('  XMLELEMENT(\'http://purl.org/metadata/dublin_core#:title\', BMK.WA.utf2wide(BD_NAME)), \n', retValue);
  http('  XMLELEMENT(\'http://purl.org/metadata/dublin_core#:description\', BMK.WA.utf2wide(BD_DESCRIPTION)), \n', retValue);
  http('  XMLELEMENT(\'http://www.w3.org/1999/02/22-rdf-syntax-ns#:description\', \n', retValue);
  http('  XMLATTRIBUTES(B_URI as \'about\'))) \n', retValue);
  http('from \n', retValue);
  http('  BMK.WA.BOOKMARK_DOMAIN, \n', retValue);
  http('  BMK.WA.BOOKMARK \n', retValue);
  http('where BD_BOOKMARK_ID = B_ID \n', retValue);
  http('  and BD_DOMAIN_ID = <DOMAIN_ID>\n', retValue);
  http(']]></sql:sqlx>\n', retValue);

  http('</rdf:description>\n', retValue);
  http('</rdf:RDF>\n', retValue);

  retValue := string_output_string (retValue);
  retValue := replace(retValue, '<USER_ID>', cast(account_id as varchar));
  retValue := replace(retValue, '<DOMAIN_ID>', cast(domain_id as varchar));
  return retValue;
}
;

-------------------------------------------------------------------------------
--
create procedure BMK.WA.export_opml_sqlx(
  in domain_id integer,
  in account_id integer)
{
  declare retValue any;

  retValue := string_output ();

  http ('<?xml version =\'1.0\' encoding=\'UTF-8\'?>\n', retValue);
  http ('<opml version="1.0">\n', retValue);

  http ('<head>\n', retValue);

  http ('<sql:sqlx xmlns:sql=\'urn:schemas-openlink-com:xml-sql\'><![CDATA[\n', retValue);
  http ('select XMLELEMENT (\'title\', BMK.WA.utf2wide(WAI_NAME)) from DB.DBA.WA_INSTANCE where WAI_ID = <DOMAIN_ID>\n', retValue);
  http (']]></sql:sqlx>\n', retValue);

  http ('</head>\n', retValue);

  http ('<body>\n', retValue);

  http ('<sql:sqlx xmlns:sql=\'urn:schemas-openlink-com:xml-sql\'><![CDATA[\n', retValue);
  http ('select \n', retValue);
  http ('XMLAGG(XMLELEMENT(\'outline\',\n', retValue);
  http ('XMLATTRIBUTES(BMK.WA.utf2wide(BD_NAME) as \'title\', BMK.WA.utf2wide(BD_DESCRIPTION) as \'text\', \'rss\' as \'type\', B_URI as \'htmlUrl\', B_URI as \'xmlUrl\')))\n', retValue);
  http ('from BMK.WA.BOOKMARK_DOMAIN, BMK.WA.BOOKMARK where BD_BOOKMARK_ID = B_ID and BD_DOMAIN_ID = <DOMAIN_ID>\n', retValue);
  http (']]></sql:sqlx>\n', retValue);

  http ('</body>\n', retValue);

  http ('</opml>\n', retValue);

  retValue := string_output_string (retValue);
  retValue := replace(retValue, '<USER_ID>', cast(account_id as varchar));
  retValue := replace(retValue, '<DOMAIN_ID>', cast(domain_id as varchar));
  return retValue;
}
;

-----------------------------------------------------------------------------
--
create procedure BMK.WA.export_comment_sqlx(
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
  http ('    XMLELEMENT (\'title\', BMK.WA.utf2wide (BD_NAME)), \n', retValue);
  http ('    XMLELEMENT (\'description\', BMK.WA.utf2wide (BMK.WA.xml2string (BD_DESCRIPTION))), \n', retValue);
  http ('    XMLELEMENT (\'link\', BMK.WA.bookmark_url (<DOMAIN_ID>, BD_ID)), \n', retValue);
  http ('    XMLELEMENT (\'pubDate\', BMK.WA.dt_rfc1123 (BD_CREATED)), \n', retValue);
  http ('    XMLELEMENT (\'generator\', \'Virtuoso Universal Server \' || sys_stat(\'st_dbms_ver\')), \n', retValue);
  http ('    XMLELEMENT (\'http://purl.org/dc/elements/1.1/:creator\', U_FULL_NAME) \n', retValue);
  http ('  from \n', retValue);
  http ('    BMK.WA.BOOKMARK_DOMAIN, DB.DBA.SYS_USERS, DB.DBA.WA_INSTANCE \n', retValue);
  http ('  where \n', retValue);
  http ('    BD_ID = :id and U_ID = <USER_ID> and BD_DOMAIN_ID = <DOMAIN_ID> and WAI_ID = BD_DOMAIN_ID and WAI_IS_PUBLIC = 1\n', retValue);
  http (']]></sql:sqlx>\n', retValue);

  http ('<sql:sqlx><![CDATA[\n', retValue);
  http ('  select \n', retValue);
  http ('    XMLAGG (XMLELEMENT(\'item\',\n', retValue);
  http ('    XMLELEMENT (\'title\', BMK.WA.utf2wide (BC_TITLE)),\n', retValue);
  http ('    XMLELEMENT (\'guid\', BMK.WA.bookmarks_url (<DOMAIN_ID>)||\'conversation.vspx\'||\'?id=\'||cast (BC_BOOKMARK_ID as varchar)||\'#\'||cast (BC_ID as varchar)),\n', retValue);
  http ('    XMLELEMENT (\'link\', BMK.WA.bookmarks_url (<DOMAIN_ID>)||\'conversation.vspx\'||\'?id=\'||cast (BC_BOOKMARK_ID as varchar)||\'#\'||cast (BC_ID as varchar)),\n', retValue);
  http ('    XMLELEMENT (\'http://purl.org/dc/elements/1.1/:creator\', BC_U_MAIL),\n', retValue);
  http ('    XMLELEMENT (\'pubDate\', DB.DBA.date_rfc1123 (BC_UPDATED)),\n', retValue);
  http ('    XMLELEMENT (\'description\', BMK.WA.utf2wide (blob_to_string (BC_COMMENT))))) \n', retValue);
  http ('  from \n', retValue);
  http ('    (select TOP 15 \n', retValue);
  http ('       BC_ID, \n', retValue);
  http ('       BC_BOOKMARK_ID, \n', retValue);
  http ('       BC_TITLE, \n', retValue);
  http ('       BC_COMMENT, \n', retValue);
  http ('       BC_U_MAIL, \n', retValue);
  http ('       BC_UPDATED \n', retValue);
  http ('     from \n', retValue);
  http ('       BMK.WA.BOOKMARK_COMMENT, DB.DBA.WA_INSTANCE \n', retValue);
  http ('     where \n', retValue);
  http ('       BC_BOOKMARK_ID = :id and WAI_ID = BC_DOMAIN_ID and WAI_IS_PUBLIC = 1\n', retValue);
  http ('     order by BC_UPDATED desc\n', retValue);
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
create procedure BMK.WA.export_opml_xml(
  in domain_id integer,
  in account_id integer)
{
  declare aXML any;

  aXML := (select XMLELEMENT ('opml', XMLATTRIBUTES('1.0' as 'version'), XMLELEMENT ('head'), XMLELEMENT ('body', XMLAGG (XMLELEMENT ('outline', XMLATTRIBUTES(BD_NAME as 'title', BD_NAME as 'text', 'rss' as 'type', B_URI as 'htmlUrl', B_URI as 'xmlUrl')))))
             from BMK.WA.BOOKMARK_DOMAIN,
                  BMK.WA.BOOKMARK
            where BD_BOOKMARK_ID = B_ID and BD_DOMAIN_ID = domain_id);
  return aXML;
}
;

-----------------------------------------------------------------------------
--
create procedure BMK.WA.xtree_doc (
  in xt varchar,
  in xtMode integer := 0)
{
  declare exit handler for SQLSTATE '*' {
    return null;
  };
  return xtree_doc (xt, xtMode);
}
;

-----------------------------------------------------------------------------
--
create procedure BMK.WA.xml_set(
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
  aEntity := xpath_eval(sprintf('/settings/entry[@ID = "%s"]', id), pXml);
  if (not isnull(aEntity))
    pXml := XMLUpdate(pXml, sprintf('/settings/entry[@ID = "%s"]', id), null);

  if (not is_empty_or_null(value)) {
    aEntity := xpath_eval('/settings', pXml);
    XMLAppendChildren(aEntity, xtree_doc(sprintf('<entry ID="%s">%s</entry>', id, BMK.WA.xml2string(value))));
  }
  return pXml;
}
;

-----------------------------------------------------------------------------
--
create procedure BMK.WA.xml_get(
  in id varchar,
  inout pXml varchar,
  in defaultValue any := '')
{
  declare value any;

  declare exit handler for SQLSTATE '*' {return defaultValue;};

  if (not isentity(pXml))
    pXml := xtree_doc(pXml);
  value := xpath_eval(sprintf('string(/settings/entry[@ID = "%s"]/.)', id), pXml);
  if (is_empty_or_null(value))
    return defaultValue;

  return BMK.WA.wide2utf(value);
}
;

-------------------------------------------------------------------------------
--
create procedure BMK.WA.string2xml (
  in content varchar,
  in mode integer := 0)
{
  if (mode = 0)
  {
    declare exit handler for sqlstate '*' {
      goto _html;
    };
    return xml_tree_doc (xml_tree (content, 0));
  }
_html:;
  return xml_tree_doc(xml_tree(content, 2, '', 'UTF-8'));
}
;

-------------------------------------------------------------------------------
--
create procedure BMK.WA.xml2string(
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
create procedure BMK.WA.string2nntp (
  in S varchar)
{
  S := replace (S, '.', '_');
  S := replace (S, '@', '_');
  return sprintf ('%U', S);
}
;

-------------------------------------------------------------------------------
--
create procedure BMK.WA.normalize_space(
  in S varchar)
{
  return xpath_eval ('normalize-space (string(/a))', XMLELEMENT('a', S), 1);
}
;

-------------------------------------------------------------------------------
--
create procedure BMK.WA.utfClear(
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
create procedure BMK.WA.utf2wide (
  inout S any)
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
create procedure BMK.WA.wide2utf (
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
create procedure BMK.WA.stringCut (
  in S varchar,
  in L integer := 60)
{
  declare tmp any;

  if (not L)
    return S;
  tmp := BMK.WA.utf2wide(S);
  if (not iswidestring(tmp))
    return S;
  if (length(tmp) > L)
    return BMK.WA.wide2utf(concat(subseq(tmp, 0, L-3), '...'));
  return BMK.WA.wide2utf(tmp);
}
;

-------------------------------------------------------------------------------
--
create procedure BMK.WA.vector_unique(
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
      aResult := vector_concat(aResult, vector(trim(aVector[N])));
    }
  _next:;
  }
  return aResult;
}
;

-------------------------------------------------------------------------------
--
create procedure BMK.WA.vector_except(
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
create procedure BMK.WA.vector_contains(
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
create procedure BMK.WA.vector_cut(
  inout aVector any,
  in value varchar)
{
  declare N integer;
  declare retValue any;

  retValue := vector();
  for (N := 0; N < length(aVector); N := N + 1)
    if (value <> aVector[N])
      retValue := vector_concat(retValue, vector(aVector[N]));
  return retValue;
}
;

-------------------------------------------------------------------------------
--
create procedure BMK.WA.vector_search(
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
create procedure BMK.WA.vector2str(
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
create procedure BMK.WA.vector2rs(
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
create procedure BMK.WA.tagsDictionary2rs(
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
create procedure BMK.WA.vector2src(
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
create procedure BMK.WA.ft2vector(
  in S any)
{
  declare w varchar;
  declare aResult any;

  aResult := vector();
  w := regexp_match ('["][^"]+["]|[''][^'']+['']|[^"'' ]+', S, 1);
  while (w is not null) {
    w := trim (w, '"'' ');
    if (upper(w) not in ('AND', 'NOT', 'NEAR', 'OR') and length (w) > 1 and not vt_is_noise (BMK.WA.wide2utf(w), 'utf-8', 'x-ViDoc'))
      aResult := vector_concat(aResult, vector(w));
    w := regexp_match ('["][^"]+["]|[''][^'']+['']|[^"'' ]+', S, 1);
  }
  return aResult;
}
;

-------------------------------------------------------------------------------
--
create procedure BMK.WA.set_keyword(
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
create procedure BMK.WA.bmk_tree (
  in domain_id integer,
  in user_id integer,
  in node varchar,
  in path varchar)
{
  declare node_type, node_id any;
  declare retValue any;

  retValue := vector ();

  node_id := BMK.WA.node_id(node);
  node_type := BMK.WA.node_type(node);
  if ((node_type = 'r') and (node_id = 0))
  {
    retValue := vector('Bookmarks', BMK.WA.make_node ('f', -1), BMK.WA.make_path('', 'f', -1));
  }
  else if ((node_type = 'r') and (node_id = 1))
  {
    retValue := vector('Bookmarks', BMK.WA.make_node ('f', -1), BMK.WA.make_path(path, 'f', -1), 'Smart Folders', BMK.WA.make_node ('s', -1), BMK.WA.make_path(path, 's', -1), 'Shared Bookmarks By', BMK.WA.make_node ('u', -1), BMK.WA.make_path(path, 'u', -1));
  }
  else if ((node_type = 'u') and (node_id = -1))
  {
    for (select distinct U_ID, U_NAME from BMK..GRANTS_VIEW where GW_ID = user_id order by 2) do
      retValue := vector_concat(retValue, vector(U_NAME, BMK.WA.make_node('u', U_ID), BMK.WA.make_path(path, 'u', U_ID)));
  }
  else if (node_type = 'f')
  {
    for (select F_ID, F_NAME from BMK.WA.FOLDER where F_DOMAIN_ID = domain_id and coalesce(F_PARENT_ID, -1) = coalesce(node_id, -1) order by 2) do
      retValue := vector_concat(retValue, vector(F_NAME, BMK.WA.make_node('f', F_ID), BMK.WA.make_path(path, 'f', F_ID)));
  }
  else if ((node_type = 's') and (node_id = -1))
  {
    for (select SF_ID, SF_NAME from BMK.WA.SFOLDER where SF_DOMAIN_ID = domain_id order by 2) do
      retValue := vector_concat(retValue, vector(SF_NAME, BMK.WA.make_node('s', SF_ID), BMK.WA.make_path(path, 's', SF_ID)));
  }
  else if ((node_type = 'u') and (node_id >= 0))
  {
    for (select distinct F_ID, F_NAME from BMK.WA.FOLDER, BMK..GRANTS_OBJECT_VIEW where GOW_TYPE = 'F' and F_ID = G_OBJECT_ID and GOW_TO = user_id and GOW_FROM = node_id order by 2) do
      retValue := vector_concat(retValue, vector(F_NAME, BMK.WA.make_node('F', F_ID), BMK.WA.make_path(path, 'F', F_ID)));
  }
  else if (node_type = 'F')
  {
    for (select F_ID, F_NAME from BMK.WA.FOLDER where F_PARENT_ID = node_id order by 2) do
      retValue := vector_concat(retValue, vector(F_NAME, BMK.WA.make_node('F', F_ID), BMK.WA.make_path(path, 'F', F_ID)));
  }
  return retValue;
    }
;

-------------------------------------------------------------------------------
--
create procedure BMK.WA.bmk_path2_int(
  in node varchar,
  in root_id integer,
  inout path varchar)
{
  declare node_type, node_id any;

  node_id := BMK.WA.node_id(node);
  node_type := BMK.WA.node_type(node);

  if ((lcase(node_type) = 'f') and (node_id <> 0))
    for (select F_PARENT_ID from BMK.WA.FOLDER where F_ID = node_id) do
    {
      path := sprintf('%s/%s', BMK.WA.make_node(node_type, coalesce(F_PARENT_ID, -1)), path);
      if (coalesce(F_PARENT_ID, 0) <> root_id)
        BMK.WA.bmk_path2_int(BMK.WA.make_node(node_type, coalesce(F_PARENT_ID, -1)), root_id, path);
  }

  if ((node_type = 's') and (node_id >= 0))
    path := sprintf('%s/%s', BMK.WA.make_node(node_type, -1), path);

  if ((node_type = 'u') and (node_id >= 0))
    path := sprintf('%s/%s', BMK.WA.make_node(node_type, -1), path);
}
;

-------------------------------------------------------------------------------
--
create procedure BMK.WA.bmk_path2(
  in node varchar,
  in grant_id integer := -1)
{
  declare user_id, root_id any;
  declare path any;

  path := node;
  root_id := 0;
  for (select G_GRANTER_ID, G_OBJECT_TYPE, G_OBJECT_ID from BMK.WA.GRANTS where G_ID = grant_id) do
  {
    if (G_OBJECT_TYPE = 'F')
      root_id := G_OBJECT_ID;
    user_id := G_GRANTER_ID;
  }
  BMK.WA.bmk_path2_int(node, root_id, path);
  if (root_id)
    path := BMK.WA.make_node('u', -1) || '/' || BMK.WA.make_node('u', user_id) || '/' || path;
  return '/' || path;
}
;

-------------------------------------------------------------------------------
--
create procedure BMK.WA.make_node (
  in node_type varchar,
  in node_id any)
{
  return node_type || '#' || cast(node_id as varchar);
}
;

-------------------------------------------------------------------------------
--
create procedure BMK.WA.make_path (
  in path varchar,
  in node_type varchar,
  in node_id any)
{
  return path || '/' || BMK.WA.make_node (node_type, node_id);
}
;

-------------------------------------------------------------------------------
--
create procedure BMK.WA.node_type(
  in code varchar)
{
  if ((length(code) > 1) and (substring(code,2,1) = '#'))
      return left(code, 1);
  return '';
}
;

-------------------------------------------------------------------------------
--
create procedure BMK.WA.node_id(
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
create procedure BMK.WA.node_suffix(
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
create procedure BMK.WA.show_text(
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
create procedure BMK.WA.show_title(
  in S any)
{
  return BMK.WA.show_text(S, 'title');
}
;

-------------------------------------------------------------------------------
--
create procedure BMK.WA.show_author(
  in S any)
{
  return BMK.WA.show_text(S, 'author');
}
;

-------------------------------------------------------------------------------
--
create procedure BMK.WA.show_description(
  in S any)
{
  return BMK.WA.show_text(S, 'description');
}
;

-------------------------------------------------------------------------------
--
create procedure BMK.WA.show_excerpt(
  in S varchar,
  in words varchar)
{
  return coalesce(search_excerpt (words, cast(S as varchar)), '');
}
;

-------------------------------------------------------------------------------
--
create procedure BMK.WA.dashboard_rs(
  in p0 integer)
{
  declare c0 integer;
  declare c1 varchar;
  declare c2 datetime;

  result_names(c0, c1, c2);
  for (select top 10 *
         from (select BD_ID,
                      BD_NAME,
                      BD_UPDATED
                 from BMK.WA.BOOKMARK_DOMAIN
                where BD_DOMAIN_ID = p0
                order by BD_UPDATED desc
              ) x) do
  {
    result (BD_ID, BD_NAME, coalesce (BD_UPDATED, now ()));
  }
}
;

-------------------------------------------------------------------------------
--
create procedure BMK.WA.dashboard_get(
  in domain_id integer)
{
  declare account_id integer;
  declare aStream any;

  account_id := BMK.WA.domain_owner_id (domain_id);
  aStream := string_output ();
  http ('<bookmark-db>', aStream);
  for (select x.* from BMK.WA.dashboard_rs(p0)(_id integer, _name varchar, _time datetime) x where p0 = domain_id) do
  {
    http ('<bookmark>', aStream);
    http (sprintf ('<dt>%s</dt>', date_iso8601 (_time)), aStream);
    http (sprintf ('<title><![CDATA[%s]]></title>', _name), aStream);
    http (sprintf ('<link>%V</link>', SIOC..bmk_post_iri (domain_id, _id)), aStream);
    http (sprintf ('<from><![CDATA[%s]]></from>', BMK.WA.account_fullName (account_id)), aStream);
    http (sprintf ('<uid>%s</uid>', BMK.WA.account_name (account_id)), aStream);
    http ('</bookmark>', aStream);
  }
  http ('</bookmark-db>', aStream);
  return string_output_string (aStream);
}
;

-------------------------------------------------------------------------------
--
-- Date / Time functions
--
-------------------------------------------------------------------------------
-- returns system time in GMT
--
create procedure BMK.WA.dt_current_time()
{
  return dateadd('minute', - timezone(now()),now());
}
;

-------------------------------------------------------------------------------
--
-- convert from GMT date to user timezone;
--
create procedure BMK.WA.dt_gmt2user(
  in pDate datetime,
  in pUser varchar := null)
{
  if (isnull(pDate))
    return null;
  if (isnull(pUser))
    pUser := connection_get('owner_user');
  if (isnull(pUser))
    pUser := connection_get('vspx_user');
  if (is_empty_or_null (pUser))
    return pDate;
  return dateadd('minute', coalesce (USER_GET_OPTION(pUser, 'TIMEZONE'), 0) * 60, pDate);
}
;

-------------------------------------------------------------------------------
--
-- convert from the user timezone to GMT date
--
create procedure BMK.WA.dt_user2gmt(
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
create procedure BMK.WA.dt_value(
  in pDate datetime,
  in pUser datetime := null)
{
  if (isnull(pDate))
    return pDate;
  pDate := BMK.WA.dt_gmt2user(pDate, pUser);
  if (BMK.WA.dt_format(pDate, 'D.M.Y') = BMK.WA.dt_format(now(), 'D.M.Y'))
    return concat('today ', BMK.WA.dt_format(pDate, 'H:N'));
  return BMK.WA.dt_format(pDate, 'D.M.Y H:N');
}
;

-----------------------------------------------------------------------------
--
create procedure BMK.WA.dt_format(
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
create procedure BMK.WA.dt_deformat(
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
      m := BMK.WA.dt_deformat_tmp(pString, I);
    if (ch = 'D')
      d := BMK.WA.dt_deformat_tmp(pString, I);
    if (ch = 'Y') {
      y := BMK.WA.dt_deformat_tmp(pString, I);
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
create procedure BMK.WA.dt_deformat_tmp(
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
create procedure BMK.WA.dt_reformat(
  in pString varchar,
  in pInFormat varchar := 'd.m.Y',
  in pOutFormat varchar := 'm.d.Y')
{
  return BMK.WA.dt_format(BMK.WA.dt_deformat(pString, pInFormat), pOutFormat);
};

-----------------------------------------------------------------------------------------
--
create procedure BMK.WA.dt_convert(
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
create procedure BMK.WA.dt_rfc1123 (
  in dt datetime)
{
  return soap_print_box (dt, '', 1);
}
;

-----------------------------------------------------------------------------------------
--
create procedure BMK.WA.dt_iso8601 (
  in dt datetime)
{
  return soap_print_box (dt, '', 0);
}
;

-----------------------------------------------------------------------------------------
--
create procedure BMK.WA.data (
  in data any)
{
  --data := deserialize(blob_to_string(data));
  --if (is_empty_or_null(data))
  --  return vector();
  return data;
}
;

-----------------------------------------------------------------------------------------
--
create procedure BMK.WA.test_clear (
  in S any)
{
  declare N integer;

  return substring(S, 1, coalesce(strstr(S, '<>'), length(S)));
}
;

-----------------------------------------------------------------------------------------
--
create procedure BMK.WA.test (
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
      signal ('TEST', sprintf('''%s'' value should be greater than %s!<>', valueName, cast (tmp as varchar)));
    if (__SQL_STATE = 'MAX')
      signal ('TEST', sprintf('''%s'' value should be less than %s!<>', valueName, cast (tmp as varchar)));
    if (__SQL_STATE = 'MINLENGTH')
      signal ('TEST', sprintf('The length of field ''%s'' should be greater than %s characters!<>', valueName, cast (tmp as varchar)));
    if (__SQL_STATE = 'MAXLENGTH')
      signal ('TEST', sprintf('The length of field ''%s'' should be less than %s characters!<>', valueName, cast (tmp as varchar)));
    if (__SQL_STATE = 'SPECIAL')
      signal ('TEST', __SQL_MESSAGE);
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
  if (isnull(tmp))
  {
    if (not isnull(get_keyword('minValue', params))) {
      tmp := 0;
    } else if (get_keyword('minLength', params, 0) <> 0) {
      tmp := 0;
    }
  }
  if (not isnull(tmp) and (tmp = 0) and is_empty_or_null(value))
  {
    signal('EMPTY', '');
  } else if (is_empty_or_null(value)) {
    return value;
  }

  value := OMAIL.WA.validate2 (valueClass, cast (value as varchar));
  if (valueType = 'integer')
  {
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
    if (not isnull(tmp) and (length(BMK.WA.utf2wide(value)) < tmp))
      signal('MINLENGTH', cast(tmp as varchar));

    tmp := get_keyword('maxLength', params);
    if (not isnull(tmp) and (length(BMK.WA.utf2wide(value)) > tmp))
      signal('MAXLENGTH', cast(tmp as varchar));
  }
  return value;
}
;

-----------------------------------------------------------------------------------------
--
create procedure BMK.WA.validate2 (
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
    return stringdate(BMK.WA.dt_reformat(propertyValue, 'd.m.Y', 'Y-M-D'));
  } else if (propertyType = 'time') {
    if (isnull(regexp_match('^([01]?[0-9]|[2][0-3])(:[0-5][0-9])?\$', propertyValue)))
      goto _error;
    return cast(propertyValue as time);
  } else if (propertyType = 'folder') {
    if (isnull(regexp_match('^[^\\\/\?\*\"\'\>\<\:\|]*\$', propertyValue)))
      goto _error;
  } else if ((propertyType = 'uri') or (propertyType = 'anyuri')) {
    if (isnull(regexp_match('^(ht|f)tp(s?)\:\/\/[0-9a-zA-Z]([-.\w]*[0-9a-zA-Z])*(:(0-9)*)*(\/?)([a-zA-Z0-9\-\.\?\,\'\/\\\+&amp;%\$#_=:~]*)?\$', propertyValue)))
      goto _error;
  } else if (propertyType = 'email') {
    if (isnull(regexp_match('^([a-zA-Z0-9_\-])+(\.([a-zA-Z0-9_\-])+)*@((\[(((([0-1])?([0-9])?[0-9])|(2[0-4][0-9])|(2[0-5][0-5])))\.(((([0-1])?([0-9])?[0-9])|(2[0-4][0-9])|(2[0-5][0-5])))\.(((([0-1])?([0-9])?[0-9])|(2[0-4][0-9])|(2[0-5][0-5])))\.(((([0-1])?([0-9])?[0-9])|(2[0-4][0-9])|(2[0-5][0-5]))\]))|((([a-zA-Z0-9])+(([\-])+([a-zA-Z0-9])+)*\.)+([a-zA-Z])+(([\-])+([a-zA-Z0-9])+)*))\$', propertyValue)))
      goto _error;
  } else if (propertyType = 'free-text') {
    if (length(propertyValue))
      if (not BMK.WA.validate_freeTexts(propertyValue))
        goto _error;
  } else if (propertyType = 'free-text-expression') {
    if (length(propertyValue))
      if (not BMK.WA.validate_freeText(propertyValue))
        goto _error;
  } else if (propertyType = 'tags') {
    if (not BMK.WA.validate_tags(propertyValue))
      goto _error;
  }
  return propertyValue;

_error:
  signal('CLASS', propertyType);
}
;

-----------------------------------------------------------------------------------------
--
create procedure BMK.WA.validate (
  in propertyType varchar,
  in propertyValue varchar,
  in propertyEmpty integer := 1)
{
  if (is_empty_or_null(propertyValue))
    return propertyEmpty;

  declare tmp any;
  declare exit handler for SQLSTATE '*' {return 0;};

  if (propertyType = 'boolean')
  {
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
create procedure BMK.WA.validate_freeText (
  in S varchar)
{
  declare st, msg varchar;

  if (upper(S) in ('AND', 'NOT', 'NEAR', 'OR'))
    return 0;
  if (length (S) < 2)
    return 0;
  if (vt_is_noise (BMK.WA.wide2utf(S), 'utf-8', 'x-ViDoc'))
    return 0;
  st := '00000';
  exec ('vt_parse (?)', st, msg, vector (S));
  if (st <> '00000')
    return 0;
  return 1;
}
;

-----------------------------------------------------------------------------------------
--
create procedure BMK.WA.validate_freeTexts (
  in S any)
{
  declare w varchar;

  w := regexp_match ('["][^"]+["]|[''][^'']+['']|[^"'' ]+', S, 1);
  while (w is not null) {
    w := trim (w, '"'' ');
    if (not BMK.WA.validate_freeText(w))
      return 0;
    w := regexp_match ('["][^"]+["]|[''][^'']+['']|[^"'' ]+', S, 1);
  }
  return 1;
}
;

-----------------------------------------------------------------------------------------
--
create procedure BMK.WA.validate_tag (
  in T varchar)
{
  declare S any;
  
  S := T;
  S := replace(trim(S), '+', '_');
  S := replace(trim(S), ' ', '_');
  if (not BMK.WA.validate_freeText(S))
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
create procedure BMK.WA.validate_tags (
  in S varchar)
{
  declare N integer;
  declare V any;

  if (is_empty_or_null(S))
    return 1;
  V := BMK.WA.tags2vector(S);
  if (is_empty_or_null(V))
    return 0;
  if (length(V) <> length(BMK.WA.tags2unique(V)))
    return 0;
  for (N := 0; N < length(V); N := N + 1)
    if (not BMK.WA.validate_tag(V[N]))
      return 0;
  return 1;
}
;

-----------------------------------------------------------------------------------------
--
create procedure BMK.WA.rdfa_value (
  in S varchar,
  in property varchar)
{
  if (isnull (S))
    return '';
  return sprintf ('<span property="%s">%s</span>', property, S);
}
;

-----------------------------------------------------------------------------------------
--
create procedure BMK.WA.discussion_check ()
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
create procedure BMK.WA.conversation_enable(
  in domain_id integer)
{
  return cast (get_keyword ('conv', BMK.WA.settings(domain_id), '0') as integer);
}
;

-----------------------------------------------------------------------------------------
--
create procedure BMK.WA.cm_root_node (
  in bookmark_id varchar)
{
  declare root_id any;
  declare xt any;

  root_id := (select BC_ID from BMK.WA.BOOKMARK_COMMENT where BC_BOOKMARK_ID = bookmark_id and BC_PARENT_ID is null);
  xt := (select xmlagg (xmlelement ('node', xmlattributes (BC_ID as id, BC_ID as name, BC_BOOKMARK_ID as post)))
           from BMK.WA.BOOKMARK_COMMENT
          where BC_BOOKMARK_ID = bookmark_id
            and BC_PARENT_ID = root_id
          order by BC_UPDATED);
  return xpath_eval ('//node', xt, 0);
}
;

-----------------------------------------------------------------------------------------
--
create procedure BMK.WA.cm_child_node (
  in bookmark_id varchar,
  inout node any)
{
  declare parent_id int;
  declare xt any;

  parent_id := xpath_eval ('number (@id)', node);
  bookmark_id := xpath_eval ('@post', node);

  xt := (select xmlagg (xmlelement ('node', xmlattributes (BC_ID as id, BC_ID as name, BC_BOOKMARK_ID as post)))
           from BMK.WA.BOOKMARK_COMMENT
          where BC_BOOKMARK_ID = bookmark_id and BC_PARENT_ID = parent_id order by BC_UPDATED);
  return xpath_eval ('//node', xt, 0);
}
;

-----------------------------------------------------------------------------------------
--
create procedure BMK.WA.make_rfc_id (
  in bookmark_id integer,
  in comment_id integer := null)
{
  declare hashed, host any;

  hashed := md5 (uuid ());
  host := sys_stat ('st_host_name');
  if (isnull (comment_id))
    return sprintf ('<%d.%s@%s>', bookmark_id, hashed, host);
  return sprintf ('<%d.%d.%s@%s>', bookmark_id, comment_id, hashed, host);
}
;

-----------------------------------------------------------------------------------------
--
create procedure BMK.WA.make_mail_subject (
  in txt any,
  in id varchar := null)
{
  declare enc any;

  enc := encode_base64 (BMK.WA.wide2utf (txt));
  enc := encode_base64 (txt);
  enc := replace (enc, '\r\n', '');
  txt := concat ('Subject: =?UTF-8?B?', enc, '?=\r\n');
  if (not isnull (id))
    txt := concat (txt, 'X-Virt-NewsID: ', uuid (), ';', id, '\r\n');
  return txt;
}
;

-----------------------------------------------------------------------------------------
--
create procedure BMK.WA.make_post_rfc_header (
  in mid varchar,
  in refs varchar,
  in gid varchar,
  in title varchar,
  in rec datetime,
  in author_mail varchar)
{
  declare ses any;

  ses := string_output ();
  http (BMK.WA.make_mail_subject (title), ses);
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
create procedure BMK.WA.make_post_rfc_msg (
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
create procedure BMK.WA.nntp_root (
  in domain_id integer,
  in bookmark_id integer)
{
  declare owner_id integer;
  declare name, mail, title, comment any;

  owner_id := BMK.WA.domain_owner_id (domain_id);
  name := BMK.WA.account_fullName (owner_id);
  mail := BMK.WA.account_mail (owner_id);

  select coalesce (BD_NAME, ''), coalesce (BD_DESCRIPTION, '') into title, comment from BMK.WA.BOOKMARK_DOMAIN where BD_ID = bookmark_id;
  insert into BMK.WA.BOOKMARK_COMMENT (BC_PARENT_ID, BC_DOMAIN_ID, BC_BOOKMARK_ID, BC_TITLE, BC_COMMENT, BC_U_NAME, BC_U_MAIL, BC_CREATED, BC_UPDATED)
    values (null, domain_id, bookmark_id, title, comment, name, mail, now (), now ());
}
;

-----------------------------------------------------------------------------------------
--
create procedure BMK.WA.nntp_update_item (
  in domain_id integer,
  in bookmark_id integer)
{
  declare grp, ngnext integer;
  declare nntpName, rfc_id varchar;

  nntpName := BMK.WA.domain_nntp_name (domain_id);
  select NG_GROUP, NG_NEXT_NUM into grp, ngnext from DB..NEWS_GROUPS where NG_NAME = nntpName;
  select BC_RFC_ID into rfc_id from BMK.WA.BOOKMARK_COMMENT where BC_DOMAIN_ID = domain_id and BC_BOOKMARK_ID = bookmark_id and BC_PARENT_ID is null;
  if (exists (select 1 from DB.DBA.NEWS_MULTI_MSG where NM_KEY_ID = rfc_id and NM_GROUP = grp))
    return;

  if (ngnext < 1)
    ngnext := 1;

  for (select BC_RFC_ID as rfc_id from BMK.WA.BOOKMARK_COMMENT where BC_DOMAIN_ID = domain_id and BC_BOOKMARK_ID = bookmark_id) do
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
create procedure BMK.WA.nntp_update (
  in domain_id integer,
  in oInstance varchar,
  in nInstance varchar,
  in oConversation integer := null,
  in nConversation integer := null)
{
  declare nntpGroup integer;
  declare nDescription varchar;

  if (isnull (oInstance))
    oInstance := BMK.WA.domain_nntp_name (domain_id);

  if (isnull (nInstance))
    nInstance := BMK.WA.domain_nntp_name (domain_id);

  nDescription := BMK.WA.domain_description (domain_id);

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
      values (0, nInstance, nDescription, null, 1, now(), now(), 30, 0, 0, 0, 0, 0, 0, 120, 'BOOKMARKS');
  }
}
;

-----------------------------------------------------------------------------------------
--
create procedure BMK.WA.nntp_fill (
  in domain_id integer)
{
  declare exit handler for SQLSTATE '*', not found {
    return;
  };

  declare grp, ngnext integer;
  declare nntpName varchar;

  for (select BD_ID from BMK.WA.BOOKMARK_DOMAIN where BD_DOMAIN_ID = domain_id) do
  {
    if (not exists (select 1 from BMK.WA.BOOKMARK_COMMENT where BC_DOMAIN_ID = domain_id and BC_BOOKMARK_ID = BD_ID and BC_PARENT_ID is null))
      BMK.WA.nntp_root (domain_id, BD_ID);
  }
  nntpName := BMK.WA.domain_nntp_name (domain_id);
  select NG_GROUP, NG_NEXT_NUM into grp, ngnext from DB..NEWS_GROUPS where NG_NAME = nntpName;
  if (ngnext < 1)
    ngnext := 1;

  for (select BC_RFC_ID as rfc_id from BMK.WA.BOOKMARK_COMMENT where BC_DOMAIN_ID = domain_id) do
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
create procedure BMK.WA.mail_address_split (
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
create procedure BMK.WA.nntp_decode_subject (
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
create procedure BMK.WA.nntp_process_parts (
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
      BMK.WA.nntp_process_parts (parts[2][i], body, amime, result, any_part);

  return 0;
}
;

-----------------------------------------------------------------------------------------
--
DB.DBA.NNTP_NEWS_MSG_ADD (
'BOOKMARKS',
'select
   \'BOOKMARKS\',
   BC_RFC_ID,
   BC_RFC_REFERENCES,
   0,    -- NM_READ
   null,
   BC_UPDATED,
   0,    -- NM_STAT
   null, -- NM_TRY_POST
   0,    -- NM_DELETED
   BMK.WA.make_post_rfc_msg (BC_RFC_HEADER, BC_COMMENT, 1), -- NM_HEAD
   BMK.WA.make_post_rfc_msg (BC_RFC_HEADER, BC_COMMENT),
   BC_ID
 from BMK.WA.BOOKMARK_COMMENT'
)
;

-----------------------------------------------------------------------------------------
--
create procedure DB.DBA.BOOKMARKS_NEWS_MSG_I (
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
    BMK.WA.nntp_decode_subject (subject);

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

    BMK.WA.nntp_process_parts (tree, N_NM_BODY, vector ('text/%'), res, 1);

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
  } else {
    signal ('CONVX', sprintf ('The content type [%s] is not supported', contentType));
  }

  rfc_header := '';
  for (declare i int, i := 0; i < length (head); i := i + 2)
  {
    if (lower (head[i]) <> 'content-type' and lower (head[i]) <> 'mime-version' and lower (head[i]) <> 'boundary'  and lower (head[i]) <> 'subject')
      rfc_header := rfc_header || head[i] ||': ' || head[i + 1]||'\r\n';
  }
  rfc_header := BMK.WA.make_mail_subject (subject) || rfc_header || 'Content-Type: text/html; charset=UTF-8\r\n\r\n';

  rfc_references := N_NM_REF;

  if (not isnull (N_NM_REF))
  {
    declare exit handler for not found { signal ('CONV1', 'No such article.');};

    parent_id := null;
    refs := split_and_decode (N_NM_REF, 0, '\0\0 ');
    if (length (refs))
      N_NM_REF := refs[length (refs) - 1];

    select BC_ID, BC_DOMAIN_ID, BC_BOOKMARK_ID, BC_TITLE
      into parent_id, domain_id, item_id, title
      from BMK.WA.BOOKMARK_COMMENT
     where BC_RFC_ID = N_NM_REF;

    if (isnull (subject))
      subject := 'Re: '|| title;

    BMK.WA.mail_address_split (author, name, mail);

    insert into BMK.WA.BOOKMARK_COMMENT (BC_PARENT_ID, BC_DOMAIN_ID, BC_BOOKMARK_ID, BC_TITLE, BC_COMMENT, BC_U_NAME, BC_U_MAIL, BC_UPDATED, BC_RFC_ID, BC_RFC_HEADER, BC_RFC_REFERENCES)
      values (parent_id, domain_id, item_id, subject, content, name, mail, N_NM_REC_DATE, N_NM_ID, rfc_header, rfc_references);
  }
}
;

-----------------------------------------------------------------------------------------
--
create procedure DB.DBA.BOOKMARKS_NEWS_MSG_U (
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
create procedure DB.DBA.BOOKMARKS_NEWS_MSG_D (
  inout O_NM_ID any)
{
  signal ('CONV3', 'Delete of a Bookmarks comment is not allowed');
}
;

-----------------------------------------------------------------------------------------
--
create procedure BMK.WA.news_comment_get_mess_attachments (inout _data any, in get_uuparts integer)
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
create procedure BMK.WA.news_comment_get_cn_type (in f_name varchar)
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

-------------------------------------------------------------------------------
--
create procedure BMK.WA.obj2json (
  in o any,
  in d integer := 2)
{
  declare N, Nn, M, Mm integer;
  declare R, T any;
  declare retValue any;

	if (d = 0)
	  return '[maximum depth achieved]';

  T := vector ('\b', '\\b', '\t', '\\t', '\n', '\\n', '\f', '\\f',	'\r', '\\r', '"', '\\"', '\\', '\\\\');
	retValue := '';
	if (isnumeric (o))
	{
		retValue := cast (o as varchar);
	}
	else if (isstring (o))
	{
		Nn := length(o);
		for (N := 0; N < Nn; N := N + 1)
		{
			R := chr (o[N]);
		  Mm := length(T);
		  for (M := 0; M < Mm; M := M + 2)
		  {
				if (R = T[M])
				  R := T[M+1];
			}
			retValue := retValue || R;
		}
		retValue := '"' || retValue || '"';
	}
	else if (isarray (o))
	{
		retValue := '[';
		Nn := length(o);
		for (N := 0; N < Nn; N := N + 1)
		{
		  retValue := retValue || BMK.WA.obj2json (o[N], d-1);
		  if (N <> length(o)-1)
			  retValue := retValue || ',';
		}
		retValue := retValue || ']';
	}
	return retValue;
}
;

-------------------------------------------------------------------------------
--
create procedure BMK.WA.json2obj (
  in o any)
{
  return json_parse (o);
}
;
