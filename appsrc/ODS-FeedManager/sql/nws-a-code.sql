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

-------------------------------------------------------------------------------
--
-- Request Functions
--
-------------------------------------------------------------------------------
--
-- Returns 5-element "Request" array: Method,Host(name,port),Version(Major,Minor),(Path),(File,Extention)
--
-------------------------------------------------------------------------------
create procedure ENEWS.WA.validate_request(
  inout pLines any,
  in pMinVersion integer,
  in pType varchar := 'WWW')
{
  declare aResult   any;
  declare S,P,B     varchar;
  declare V         any;
  declare i,j,k,l   integer;

  -- Initialize variables
  i := strstr(pLines[0],' ');              -- Method/URI dividing space
  if (isnull(i)) ENEWS.WA.http_response(400);       -- Bad Request (can't happen!)
  l := length(pLines[0]) - 2;              -- total length.one for zero-based and one for ending LF!;
  k := strrchr(pLines[0],' ');             -- URI/Version dividing space ( k <- end of URL)
  if (isnull(k) or (k = i)) k := l;        -- if no version tag is presented k equals l
  j := strstr(pLines[0],'?');              -- search for parameters in URI and ignore them!
  if (isnull(j)) j := k;                   -- if no parameters j equals k (end of URI)
  B := subseq(pLines[0],i+1,j);            -- Buffer for resource path
  -- Initialize result structure;
  aResult := vector(subseq(pLines[0],0,i),vector('',''),vector(1,0),vector(),vector('default','vsp'), 0);
  -- Determine host
  S := http_request_header(pLines,'Host',null,'');
  if (S <> '') {
    i := strstr(S,':');
    if (isnull(i))
      aset(aResult,1,vector(S,''));
    else
      aset(aResult,1,vector(subseq(S,0,i),subseq(S,i+1)));
  }
  -- Determine request version
  if (k + 1 < l) {
    -- Check for version format
    S := subseq(pLines[0],k+1,l);
    i := strstr(S,'HTTP/');
    if (isnull(i) or (i > 0)) ENEWS.WA.http_response(400);                 -- Bad Request
    i := strstr(S,'.'); if (isnull(i)) ENEWS.WA.http_response(400);        -- Bad Request
    aset(aResult,2,vector(atoi(subseq(S,5,i)),atoi(subseq(S,i+1))));
  }
  if (aResult[2][0] <> 1) ENEWS.WA.http_response(505);                     -- HTTP Version Not Supported
  if (aResult[2][1] < pMinVersion) ENEWS.WA.http_response(505);            -- HTTP Version Not Supported
  if ((pMinVersion > 0) and aResult[1] = '') ENEWS.WA.http_response(400);  -- Host field required for HTTP/1.1

  --check "File or Directory";
  P := ENEWS.WA.mount_point();
  S := either(equ(P,''),B,subseq(B,length(P)));                   -- Remove mount point from path
  i := length(S) - 1;                                             -- S is now like 'path/file.ext
  if (i < 0)
    http_redirect2(concat(P,'/'),vector());                       -- S = ''. Redirect to '{Mount Point}/'
  if (chr(S[i]) = '/')
  {
    j := i - 1;
    while ((j >= 0) and (chr(S[j]) <> '/'))
    {
      if (chr(S[j]) = '.')
        ENEWS.WA.http_response(404);
      j := j - 1;
    }
    S := concat(S,'news.vspx');
  }
  else
  {
    j := i;
    while ((j >= 0) and (chr(S[j]) <> '.'))
    {
      if (chr(S[j]) = '/')
        http_redirect2(concat(P,S,'/'),vector());
      j := j - 1;
    }
  }

  -- Verify domain (only digits)
  V := split_and_decode(ltrim(P,'/'),0,'\0\0/');
  if (length(V) > 1) {
    P := aref(V,length(V)-1);
    regexp_match('^[0-9]+',P,1);
    if (P = '')
      aset(aResult,5,cast(aref(V,length(V)-1) as integer));
  };

  -- Verify path
  P := S;
  regexp_match('^[a-z_0-9/\.-]+',P,1);
  if (P <> '')
    ENEWS.WA.http_response(404);
  -- Put path and file into result structure
  V := split_and_decode(ltrim(S,'/'),0,'\0\0/');
  aset(aResult,4,split_and_decode(V[length(V)-1],0,'\0\0.'));
  if (length(V) > 1)
    aset(aResult,3,subseq(V,i,Length(V) - 1));
  else
    aset(aResult,3,vector(''));
  -- Return verified request information
  return aResult;
}
;

-------------------------------------------------------------------------------
--
create procedure ENEWS.WA.mount_point(
  in pURL varchar := null)
{
  declare
    sMPoint varchar;

  sMPoint := http_map_get('domain');
  if (sMPoint = '/')
    sMPoint := '';
  if (not isnull(pURL))
    sMPoint := concat(sMPoint,'/',pURL);
  return sMPoint;
}
;

-------------------------------------------------------------------------------
--
create procedure ENEWS.WA.http_response(in pError integer,in pParams varchar := '')
{
  signal('90001',sprintf('<Response Status="%d" MountPoint="%s">%s</Response>',pError,ENEWS.WA.mount_point(),pParams));
}
;

-------------------------------------------------------------------------------
--
-- Session Functions
--
-------------------------------------------------------------------------------
create procedure ENEWS.WA.session_restore(
  inout request any,
  inout params any)
{
  declare domain_id, user_id, user_name, user_role, sid, realm, options any;

  declare exit handler for sqlstate '*' {
    domain_id := -2;
    goto _end;
  };

  sid := get_keyword('sid', params, '');
  realm := get_keyword('realm', params, 'wa');

  options := http_map_get('options');
  if (not is_empty_or_null(options))
    domain_id := get_keyword('domain', options);
  if (is_empty_or_null(domain_id))
    domain_id := atoi(request[5]);
  if (not exists(select 1 from DB.DBA.WA_INSTANCE where WAI_ID = domain_id))
    domain_id := -1;

_end:
  domain_id := cast(domain_id as integer);
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
    user_name := ENEWS.WA.user_name(U_NAME, U_FULL_NAME);
    user_role := ENEWS.WA.access_role(domain_id, U_ID);
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
create procedure ENEWS.WA.frozen_check(in domain_id integer)
{
  declare exit handler for not found { return 1; };

  if (is_empty_or_null((select WAI_IS_FROZEN from DB.DBA.WA_INSTANCE where WAI_ID = domain_id)))
    return 0;

  declare user_id integer;

  user_id := (select U_ID from SYS_USERS where U_NAME = connection_get ('vspx_user'));
  if (ENEWS.WA.check_admin(user_id))
    return 0;

  user_id := (select U_ID from SYS_USERS where U_NAME = connection_get ('owner_user'));
  if (ENEWS.WA.check_admin(user_id))
    return 0;

  return 1;
}
;

-------------------------------------------------------------------------------
--
create procedure ENEWS.WA.frozen_page(in domain_id integer)
{
  return (select WAI_FREEZE_REDIRECT from DB.DBA.WA_INSTANCE where WAI_ID = domain_id);
}
;

-------------------------------------------------------------------------------
--
-- User Functions
--
-------------------------------------------------------------------------------
create procedure ENEWS.WA.check_admin(
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
create procedure ENEWS.WA.check_grants(in domain_id integer, in user_id integer, in role_name varchar)
{
  whenever not found goto _end;

  if (ENEWS.WA.check_admin(user_id))
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
create procedure ENEWS.WA.check_grants2(in role_name varchar, in page_name varchar)
{
  declare tree any;

  tree := xml_tree_doc (ENEWS.WA.menu_tree());
  if (isnull(xpath_eval (sprintf ('/menu_tree/node[.//*[(@url = "%s") and contains(@allowed, "%s")]]', page_name, role_name), tree, 1)))
    return 0;
  return 1;
}
;

-------------------------------------------------------------------------------
--
create procedure ENEWS.WA.access_role(in domain_id integer, in user_id integer)
{
  whenever not found goto _end;

  if (ENEWS.WA.check_admin(user_id))
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
create procedure ENEWS.WA.wa_home_link ()
{
	return case when registry_get ('wa_home_link') = 0 then '/ods/' else registry_get ('wa_home_link') end;
}
;

-------------------------------------------------------------------------------
--
create procedure ENEWS.WA.wa_home_title ()
{
	return case when registry_get ('wa_home_title') = 0 then 'ODS Home' else registry_get ('wa_home_title') end;
}
;

-------------------------------------------------------------------------------
--
create procedure ENEWS.WA.page_name ()
{
  declare path, url, pageName varchar;
  declare aPath any;

  path := http_path ();
  aPath := split_and_decode (path, 0, '\0\0/');
  pageName := aPath [length (aPath) - 1];
  if (pageName = 'error.vspx')
    return pageName;
  url := xpath_eval ('//*[@url = "'|| pageName ||'"]', xml_tree_doc (ENEWS.WA.menu_tree ()));
  if ((url is not null))
    return pageName;
  return '';
}
;

-------------------------------------------------------------------------------
--
create procedure ENEWS.WA.menu_tree (
  in access_role varchar := null)
{
  declare S, T varchar;

  S := sprintf (
'<?xml version="1.0" ?>
<menu_tree>
  <node name="Read" url="news.vspx?tab=feeds" id="1" allowed="public guest reader author owner admin">
    <node name="11" url="news.vspx" id="11" place="link" allowed="public guest reader author owner admin"/>
    <node name="12" url="search.vspx" id="12" place="link" allowed="public guest reader author owner admin"/>
    <node name="13" url="error.vspx" id="13" place="link" allowed="public guest reader author owner admin"/>
    <node name="14" url="blog.vspx" id="14" place="link" allowed="reader author owner admin"/>
    <node name="14" url="tags.vspx" id="14"  place="link" allowed="reader author owner admin"/>
    <node name="15" url="bookmark.vspx" id="15" place="link" allowed="reader author owner admin"/>
    <node name="16" url="settings.vspx" id="16" place="link" allowed="reader author owner admin"/>
  </node>
  <node name="Administration"  url="channels.vspx"        id="2"                allowed="author owner admin">
    <node name="Feeds" url="channels.vspx" id="21" allowed="author owner admin">
      <node name="211" url="channels_create.vspx" id="211" place="link" allowed="author owner admin"/>
      <node name="212" url="channels_update.vspx" id="212" place="link" allowed="author owner admin"/>
      <node name="213" url="export.vspx" id="213" place="link" allowed="reader author owner admin"/>
    </node>
    <node name="Folders"       url="folders.vspx" id="22"                       allowed="author owner admin"/>
    <node name="Smart Folders" url="sfolders.vspx" id="23"                      allowed="author owner admin">
      <node name="231"         url="sfolders_update.vspx" id="231" place="link" allowed="author owner admin"/>
  </node>
    <node name="Weblogs"       url="weblog.vspx"          id="24"               allowed="author owner admin"/>
    <Directories/>
  </node>
  <node name="%s" url="%s" id="5" allowed="public guest reader author owner admin"/>
</menu_tree>', ENEWS.WA.wa_home_title (), ENEWS.WA.wa_home_link ());

  T := '';
  if (isnull(access_role) or (access_role = 'admin'))
    T := '<node name="Directories"   url="directories.vspx"     id="25"               allowed="admin"/>';

  return replace(S, '<Directories/>', T);
}
;

-------------------------------------------------------------------------------
--
create procedure ENEWS.WA.navigation_root (
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
  access_role := ENEWS.WA.access_role(domain_id, user_id);
  return xpath_eval (sprintf('/menu_tree/*[contains(@allowed, "%s")]', access_role), xml_tree_doc (ENEWS.WA.menu_tree (access_role)), 0);

}
;

-------------------------------------------------------------------------------
--
create procedure ENEWS.WA.navigation_child (
  in path varchar,
  in node any)
{
  path := concat (path, '[not @place]');
  return xpath_eval (path, node, 0);
}
;

-------------------------------------------------------------------------------
--
create procedure ENEWS.WA.domain_owner_id (
  inout domain_id integer)
{
  return (select A.WAM_USER from WA_MEMBER A, WA_INSTANCE B where A.WAM_MEMBER_TYPE = 1 and A.WAM_INST = B.WAI_NAME and B.WAI_ID = domain_id);
}
;

-------------------------------------------------------------------------------
--
create procedure ENEWS.WA.domain_gems_create (
  inout domain_id integer,
  inout account_id integer)
{
  declare read_perm, exec_perm, content, home, path varchar;

  home := ENEWS.WA.dav_home(account_id);
  if (isnull(home))
    return;

  read_perm := '110100100N';
  exec_perm := '111101101N';
  home := home || ENEWS.WA.domain_gems_folder() || '/';
  DB.DBA.DAV_MAKE_DIR (home, account_id, null, read_perm);

  path := home || 'channels/';
  DB.DBA.DAV_MAKE_DIR (path, account_id, null, read_perm);
  update WS.WS.SYS_DAV_COL set COL_DET = 'News3' where COL_ID = DAV_SEARCH_ID (path, 'C');

  home := home || ENEWS.WA.domain_gems_name(domain_id) || '/';
  DB.DBA.DAV_MAKE_DIR (home, account_id, null, read_perm);

  -- RSS 2.0
  path := home || 'OFM.rss';
  DB.DBA.DAV_DELETE_INT (path, 1, null, null, 0);

  content := ENEWS.WA.export_rss_sqlx (domain_id, account_id);
  DB.DBA.DAV_RES_UPLOAD_STRSES_INT (path, content, 'text/xml', exec_perm, http_dav_uid (), http_dav_uid () + 1, null, null, 0);
  DB.DBA.DAV_PROP_SET_INT (path, 'xml-template', 'execute', 'dav', null, 0, 0, 1);
  DB.DBA.DAV_PROP_SET_INT (path, 'xml-sql-encoding', 'utf-8', 'dav', null, 0, 0, 1);
  DB.DBA.DAV_PROP_SET_INT (path, 'xml-sql-description', 'RSS based XML document generated by OpenLink Feed Manager', 'dav', null, 0, 0, 1);

  -- ATOM
  path := home || 'OFM.atom';
  DB.DBA.DAV_DELETE_INT (path, 1, null, null, 0);

  content := ENEWS.WA.export_atom_sqlx (domain_id, account_id);
  DB.DBA.DAV_RES_UPLOAD_STRSES_INT (path, content, 'text/xml', exec_perm, http_dav_uid (), http_dav_uid () + 1, null, null, 0);
  DB.DBA.DAV_PROP_SET_INT (path, 'xml-template', 'execute', 'dav', null, 0, 0, 1);
  DB.DBA.DAV_PROP_SET_INT (path, 'xml-sql-encoding', 'utf-8', 'dav', null, 0, 0, 1);
  DB.DBA.DAV_PROP_SET_INT (path, 'xml-sql-description', 'ATOM based XML document generated by OpenLink Feed Manager', 'dav', null, 0, 0, 1);

  -- RDF
  path := home || 'OFM.rdf';
  DB.DBA.DAV_DELETE_INT (path, 1, null, null, 0);

  content := ENEWS.WA.export_rdf_sqlx (domain_id, account_id);
  DB.DBA.DAV_RES_UPLOAD_STRSES_INT (path, content, 'text/xml', exec_perm, http_dav_uid (), http_dav_uid () + 1, null, null, 0);
  DB.DBA.DAV_PROP_SET_INT (path, 'xml-template', 'execute', 'dav', null, 0, 0, 1);
  DB.DBA.DAV_PROP_SET_INT (path, 'xml-sql-encoding', 'utf-8', 'dav', null, 0, 0, 1);
  DB.DBA.DAV_PROP_SET_INT (path, 'xml-sql-description', 'RDF based XML document generated by OpenLink Feed Manager', 'dav', null, 0, 0, 1);

  -- OCS
  path := home || 'OFM.ocs';
  DB.DBA.DAV_DELETE_INT (path, 1, null, null, 0);

  content := ENEWS.WA.export_ocs_sqlx (domain_id, account_id);
  DB.DBA.DAV_RES_UPLOAD_STRSES_INT (path, content, 'text/xml', exec_perm, http_dav_uid (), http_dav_uid () + 1, null, null, 0);
  DB.DBA.DAV_PROP_SET_INT (path, 'xml-template', 'execute', 'dav', null, 0, 0, 1);
  DB.DBA.DAV_PROP_SET_INT (path, 'xml-sql-encoding', 'utf-8', 'dav', null, 0, 0, 1);
  DB.DBA.DAV_PROP_SET_INT (path, 'xml-sql-description', 'OPML based XML document generated by OpenLink Feed Manager', 'dav', null, 0, 0, 1);

  -- OPML
  path := home || 'OFM.opml';
  DB.DBA.DAV_DELETE_INT (path, 1, null, null, 0);

  content := ENEWS.WA.export_opml_sqlx (domain_id, account_id);
  DB.DBA.DAV_RES_UPLOAD_STRSES_INT (path, content, 'text/xml', exec_perm, http_dav_uid (), http_dav_uid () + 1, null, null, 0);
  DB.DBA.DAV_PROP_SET_INT (path, 'xml-template', 'execute', 'dav', null, 0, 0, 1);
  DB.DBA.DAV_PROP_SET_INT (path, 'xml-sql-encoding', 'utf-8', 'dav', null, 0, 0, 1);
  DB.DBA.DAV_PROP_SET_INT (path, 'xml-sql-description', 'OPML based XML document generated by OpenLink Feed Manager', 'dav', null, 0, 0, 1);

  -- FOAF
  path := home || 'OFM.foaf';
  DB.DBA.DAV_DELETE_INT (path, 1, null, null, 0);

  content := ENEWS.WA.export_foaf_sqlx (domain_id, account_id);
  DB.DBA.DAV_RES_UPLOAD_STRSES_INT (path, content, 'text/xml', exec_perm, http_dav_uid (), http_dav_uid () + 1, null, null, 0);
  DB.DBA.DAV_PROP_SET_INT (path, 'xml-template', 'execute', 'dav', null, 0, 0, 1);
  DB.DBA.DAV_PROP_SET_INT (path, 'xml-sql-encoding', 'utf-8', 'dav', null, 0, 0, 1);
  DB.DBA.DAV_PROP_SET_INT (path, 'xml-sql-description', 'FOAF based XML document generated by OpenLink Feed Manager', 'dav', null, 0, 0, 1);

  -- PODCAST
  path := home || 'OFM.podcast';
  DB.DBA.DAV_DELETE_INT (path, 1, null, null, 0);

  content := ENEWS.WA.export_podcast_sqlx (domain_id, account_id);
  DB.DBA.DAV_RES_UPLOAD_STRSES_INT (path, content, 'text/xml', exec_perm, http_dav_uid (), http_dav_uid () + 1, null, null, 0);
  DB.DBA.DAV_PROP_SET_INT (path, 'xml-template', 'execute', 'dav', null, 0, 0, 1);
  DB.DBA.DAV_PROP_SET_INT (path, 'xml-sql-encoding', 'utf-8', 'dav', null, 0, 0, 1);
  DB.DBA.DAV_PROP_SET_INT (path, 'xml-sql-description', 'Podcasts based XML document generated by OpenLink Feed Manager', 'dav', null, 0, 0, 1);

  return;
}
;


-------------------------------------------------------------------------------
--
create procedure ENEWS.WA.domain_gems_delete(
  in domain_id integer,
  in account_id integer,
  in appName varchar := 'Feed Subscriptions',
  in appGems varchar := null)
{
  declare tmp, davHome, home, path varchar;

  davHome := ENEWS.WA.dav_home(account_id);
  if (isnull(davHome))
    return;

  if (isnull(appGems))
    appGems := ENEWS.WA.domain_gems_name(domain_id);
  home := davHome || appName || '/' || appGems || '/';

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
  path := home || appName || '.foaf';
  DB.DBA.DAV_DELETE_INT (path, 1, null, null, 0);

  declare auth_uid integrer;

  auth_uid := http_dav_uid();
  tmp := DB.DBA.DAV_DIR_LIST_INT (home, 0, '%', null, null, auth_uid);
  if (not isinteger(tmp) and not length(tmp))
    DB.DBA.DAV_DELETE_INT (home, 1, null, null, 0);

  home := davHome || appName || '/';
  tmp := DB.DBA.DAV_DIR_LIST_INT (home, 0, '%', null, null, auth_uid);
  if (not isinteger(tmp) and (length(tmp) = 1) and (tmp[0][10] = 'channels'))
    DB.DBA.DAV_DELETE_INT (home || 'channels/', 1, null, null, 0);

  tmp := DB.DBA.DAV_DIR_LIST_INT (home, 0, '%', null, null, auth_uid);
  if (not isinteger(tmp) and not length(tmp))
    DB.DBA.DAV_DELETE_INT (home, 1, null, null, 0);

  return 1;
}
;

-------------------------------------------------------------------------------
--
create procedure ENEWS.WA.domain_update (
  inout domain_id integer,
  inout account_id integer)
{
  ENEWS.WA.domain_gems_delete (domain_id, account_id, 'eNews');
  ENEWS.WA.domain_gems_delete (domain_id, account_id, 'eNews', cast(domain_id as varchar));
  ENEWS.WA.domain_gems_delete (domain_id, account_id, 'OFM');
  ENEWS.WA.domain_gems_delete (domain_id, account_id, 'OFM', cast(domain_id as varchar));
  ENEWS.WA.domain_gems_delete (domain_id, account_id, ENEWS.WA.domain_gems_folder());
  ENEWS.WA.domain_gems_create (domain_id, account_id);

  ENEWS.WA.sfolder_create(domain_id, 'New items', '<settings><entry ID="read">r-</entry></settings>', 1);
  ENEWS.WA.sfolder_create(domain_id, 'All items', '<settings/>', 1);

  return;
}
;

-------------------------------------------------------------------------------
--
create procedure ENEWS.WA.domain_delete (
  in domain_id integer)
{
  DECLARE CONTINUE HANDLER FOR SQLSTATE '*' {return 0; };

  ENEWS.WA.folder_delete_all(domain_id);
  DELETE FROM ENEWS.WA.SFOLDER     WHERE ESFO_DOMAIN_ID = domain_id;
  DELETE FROM ENEWS.WA.FEED_DOMAIN WHERE EFD_DOMAIN_ID = domain_id;
  DELETE FROM ENEWS.WA.WEBLOG      WHERE EW_DOMAIN_ID = domain_id;
  DELETE FROM ENEWS.WA.SETTINGS    WHERE ES_DOMAIN_ID = domain_id;

  for (select WAM_USER from DB.DBA.WA_MEMBER, DB.DBA.WA_INSTANCE where WAI_TYPE_NAME = 'eNews2' and WAI_ID = domain_id) do
    ENEWS.WA.account_delete (domain_id, WAM_USER);

  ENEWS.WA.nntp_update (domain_id, null, 1, 0);

  VHOST_REMOVE(lpath => concat('/enews2/', cast(domain_id as varchar)));
  return 1;
}
;

-------------------------------------------------------------------------------
--
create procedure ENEWS.WA.domain_name (
  in domain_id integer)
{
  return coalesce((select WAI_NAME from DB.DBA.WA_INSTANCE where WAI_ID = domain_id), 'OFM Instance');
}
;

create procedure ENEWS.WA.domain_description (
  in domain_id integer)
{
  return coalesce((select WAI_DESCRIPTION from DB.DBA.WA_INSTANCE where WAI_ID = domain_id), 'OFM Instance');
}
;

-------------------------------------------------------------------------------
--
create procedure ENEWS.WA.domain_gems_folder ()
{
  return 'Feed Subscriptions';
}
;

-------------------------------------------------------------------------------
--
create procedure ENEWS.WA.domain_gems_name (
  in domain_id integer)
{
  return concat(ENEWS.WA.domain_name(domain_id), '_Gems');
}
;

-------------------------------------------------------------------------------
--
create procedure ENEWS.WA.domain_description (
  in domain_id integer)
{
  return coalesce((select coalesce(WAI_DESCRIPTION, WAI_NAME) from DB.DBA.WA_INSTANCE where WAI_ID = domain_id), 'OFM Instance');
}
;

-------------------------------------------------------------------------------
--
-- Account Functions
--
-------------------------------------------------------------------------------
create procedure ENEWS.WA.account() returns varchar
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
create procedure ENEWS.WA.account_access (
	out auth_uid varchar,
	out auth_pwd varchar)
{
  auth_uid := ENEWS.WA.account();
  auth_pwd := coalesce((SELECT U_PWD FROM WS.WS.SYS_DAV_USER WHERE U_NAME = auth_uid), '');
  if (auth_pwd[0] = 0)
    auth_pwd := pwd_magic_calc(auth_uid, auth_pwd, 1);
  return 1;
}
;

-------------------------------------------------------------------------------
--
create procedure ENEWS.WA.account_delete(
  in domain_id integer,
  in account_id integer)
{
  DECLARE CONTINUE HANDLER FOR SQLSTATE '*' {return 0; };

  DELETE FROM ENEWS.WA.SETTINGS WHERE ES_DOMAIN_ID = domain_id  AND ES_ACCOUNT_ID = account_id;
  ENEWS.WA.domain_gems_delete(domain_id, account_id);

  return 1;
}
;

-------------------------------------------------------------------------------
--
create procedure ENEWS.WA.account_name(
  in account_id integer)
{
  return coalesce((select coalesce(U_FULL_NAME, U_NAME) from DB.DBA.SYS_USERS where U_ID = account_id), '');
}
;

-------------------------------------------------------------------------------
--
create procedure ENEWS.WA.account_mail(
  in account_id integer)
{
  return coalesce((select U_E_MAIL from DB.DBA.SYS_USERS where U_ID = account_id), '');
}
;

-------------------------------------------------------------------------------
--
create procedure ENEWS.WA.user_name(
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
create procedure ENEWS.WA.feeds_agregator (
  in rs int := 0)
{
  declare uri, tag varchar;
  declare id, days, rc, err integer;
  declare bm any;
  declare dt datetime;

  dt := now();
  declare cr static cursor for select EF_ID,
                                      EF_URI,
                                      EF_STORE_DAYS,
                                      EF_TAG
                                 from ENEWS.WA.FEED
                                where (EF_LAST_UPDATE is null or dateadd('minute', EF_UPDATE, EF_LAST_UPDATE) < dt)
                                  and EF_ERROR_LOG is null;

  if (rs)
    result_names(uri, rc);

  bm := null;
  err := 0;
  whenever not found goto enf;
  open cr (exclusive, prefetch 1);
  fetch cr first into id, uri, days, tag;
  while (1) {
    bm := bookmark(cr);
    err := 0;
    close cr;
    {
      declare exit handler for sqlstate '*'
      {
        rollback work;
        if (__SQL_STATE <> '40001') {
          update ENEWS.WA.FEED
             set EF_ERROR_LOG = __SQL_STATE || ' ' || __SQL_MESSAGE
           where EF_URI = uri;
          commit work;
        } else {
          resignal;
        }
        err := 1;
        goto next;
      };
      rc := ENEWS.WA.feed_refresh_int(id, uri, days, tag);
      if (rs)
        result (uri, rc);
    }
    update ENEWS.WA.FEED
       set EF_LAST_UPDATE = now(),
           EF_TAG = tag,
           EF_ERROR_LOG = null,
           EF_QUEUE_FLAG = 0
     where EF_URI = uri;
    commit work;

  next:
    open cr (exclusive, prefetch 1);
    fetch cr bookmark bm into id, uri, days, tag;
    if (err)
      fetch cr next into id, uri, days, tag;
  }
enf:
  close cr;
  return;
}
;

-------------------------------------------------------------------------------
--
create procedure ENEWS.WA.feeds_domain_agregator (
  in domain_id integer)
{
  declare id, uri, days, tag any;

  for (select EF_ID,
              EF_URI,
              EF_STORE_DAYS,
              EF_TAG
         from ENEWS.WA.FEED,
              ENEWS.WA.FEED_DOMAIN
        where EFD_FEED_ID = EF_ID
          and EFD_DOMAIN_ID = domain_id) do {
    id := EF_ID;
    uri := EF_URI;
    days := EF_STORE_DAYS;
    tag := EF_TAG;
    {
      declare exit handler for sqlstate '*' { return; };
     	commit work;
      ENEWS.WA.feed_refresh_int(id, uri, days, tag);
      update ENEWS.WA.FEED
         set EF_LAST_UPDATE = now(),
             EF_TAG = tag,
             EF_ERROR_LOG = null
       where EF_ID = id;
    }
  }
}
;

-------------------------------------------------------------------------------
--
create procedure ENEWS.WA.feeds_queue_add (
  in domain_id integer)
{
  for (select EF_ID id
         from ENEWS.WA.FEED,
              ENEWS.WA.FEED_DOMAIN
        where EFD_FEED_ID = EF_ID
          and coalesce(EF_QUEUE_FLAG, 0) = 0
          and (EF_LAST_UPDATE is null or dateadd('minute', 1, EF_LAST_UPDATE) < now())
          and EFD_DOMAIN_ID = domain_id)
  do {
    update ENEWS.WA.FEED
       set EF_QUEUE_FLAG = 1
     where EF_ID = id;
   	commit work;
  }
}
;

-------------------------------------------------------------------------------
--
create procedure ENEWS.WA.feeds_queue_agregator ()
{
  declare uri, tag varchar;
  declare id, days, err int;
  declare bm any;

  declare cr static cursor for select EF_ID,
                                      EF_URI,
                                      EF_STORE_DAYS,
                                      EF_TAG
                                 from ENEWS.WA.FEED
                                where coalesce(EF_QUEUE_FLAG, 0) = 1;

  err := 0;
  whenever not found goto enf;
  open cr (exclusive, prefetch 1);
  fetch cr first into id, uri, days, tag;
  while (1) {
    bm := bookmark(cr);
    err := 0;
    close cr;
    {
      declare exit handler for sqlstate '*'
      {
        rollback work;
        if (__SQL_STATE <> '40001') {
          update ENEWS.WA.FEED
             set EF_ERROR_LOG = __SQL_STATE || ' ' || __SQL_MESSAGE,
                 EF_QUEUE_FLAG = 0
           where EF_URI = uri;
          commit work;
        } else {
          resignal;
        }
        err := 1;
        goto next;
      };
     	commit work;
      ENEWS.WA.feed_refresh_int(id, uri, days, tag);
    }
    update ENEWS.WA.FEED
       set EF_LAST_UPDATE = now(),
           EF_TAG = tag,
           EF_ERROR_LOG = null,
           EF_QUEUE_FLAG = 0
     where EF_URI = uri;
    commit work;

  next:
    open cr (exclusive, prefetch 1);
    fetch cr bookmark bm into id, uri, days, tag;
    if (err)
      fetch cr next into id, uri, days, tag;
  }
enf:
  close cr;
  return;
}
;

-------------------------------------------------------------------------------
--
create procedure ENEWS.WA.feed_refresh (
  in id integer)
{
  declare exit handler for not found { return 0; };

  declare uri, days, tag any;
  select EF_URI, EF_STORE_DAYS, EF_TAG into uri, days, tag from ENEWS.WA.FEED where EF_ID = id;

 	commit work;
  return ENEWS.WA.feed_refresh_int(id, uri, days, tag);
}
;

-------------------------------------------------------------------------------
--
create procedure ENEWS.WA.feed_refresh_int(
  in id integer,
  in uri varchar,
  in days integer,
  inout tag varchar)
{
  declare content varchar;
  declare resHdr any;
  declare xt any;
  declare items any;
  declare N, L integer;
  declare new_tag, newUri, oldUri varchar;

  delete
    from ENEWS.WA.FEED_ITEM
   where EFI_FEED_ID = id
     and ((EFI_LAST_UPDATE is not null) and dateadd('day', days, EFI_LAST_UPDATE) < now());
  commit work;

  newUri := uri;
again:
  oldUri := newUri;
  content := http_get(newUri, resHdr);
  if (resHdr[0] not like 'HTTP/1._ 200 %') {
    if (resHdr[0] like 'HTTP/1._ 30_ %') {
	    newUri := http_request_header (resHdr, 'Location');
      if (newUri <> oldUri)
        goto again;
	  }
    signal('22023', trim(resHdr[0], '\r\n'), 'EN000');
    return 0;
  }
  new_tag := http_request_header(resHdr, 'ETag');
  if (not isstring(new_tag))
    new_tag := md5(content);

  if (new_tag = tag)
    return 0;
  tag := new_tag;

  xt := xml_tree_doc (xml_tree (content));
  if (xpath_eval ('/rss/channel/item|/rss/item|/RDF/item|/Channel/items/item', xt) is not null) {
    -- RSS formats
    items := xpath_eval ('/rss/channel/item|/rss/item|/RDF/item|/Channel/items/item', xt, 0);
    L := length (items);
    for (N := 0; N < L; N := N + 1)
      ENEWS.WA.process_rss_item(xml_cut(items[N]), id);

  } else if (xpath_eval ('/feed/entry', xt) is not null) {
    -- Atom format
    items := xpath_eval ('/feed/entry', xt, 0);
    L := length (items);
    for (N := 0; N < L; N := N + 1)
      ENEWS.WA.process_atom_item(xml_cut(items[N]), id);
  }

  return L;
}
;

-------------------------------------------------------------------------------
--
create procedure ENEWS.WA.process_rss_item(
  inout xt any,
  inout feed_id integer)
{
  declare
    title,
    description,
    link,
    guid,
    pubdate,
    comment_api,
    comment_rss,
    author varchar;

  title := serialize_to_UTF8_xml (xpath_eval ('string(/item/title)', xt, 1));
  description := xpath_eval ('[ xmlns:content="http://purl.org/rss/1.0/modules/content/" ] string(/item/content:encoded)', xt, 1);
  if (is_empty_or_null(description))
    description := xpath_eval ('string(/item/description)', xt, 1);
  description := ENEWS.WA.string2xml (serialize_to_UTF8_xml (description));
  link := cast (xpath_eval ('/item/link', xt, 1) as varchar);
  if (isnull(link)) {
    link := cast (xpath_eval ('[xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"] /item/@rdf:about', xt, 1) as varchar);
    if ((isnull(link)) and isnull(cast(xpath_eval ('/item/guid[@isPermaLink = "false"]', xt, 1) as varchar)))
      link := cast (xpath_eval ('/item/guid', xt, 1) as varchar);
  }
  guid := cast (xpath_eval ('/item/guid', xt, 1) as varchar);
  pubdate := ENEWS.WA.dt_convert(cast (xpath_eval ('[ xmlns:dc="http://purl.org/dc/elements/1.1/" ] /item/dc:date', xt, 1) as varchar));
  if (isnull(pubdate))
    pubdate := ENEWS.WA.dt_convert(cast(xpath_eval('/item/pubDate', xt, 1) as varchar), now());

  comment_api := cast (xpath_eval ('[ xmlns:wfw="http://wellformedweb.org/CommentAPI/" ] /item/wfw:comment', xt, 1) as varchar);
  comment_rss := cast (xpath_eval ('[ xmlns:wfw="http://wellformedweb.org/CommentAPI/" ] /item/wfw:commentRss', xt, 1) as varchar);
  author := cast (xpath_eval ('[ xmlns:dc="http://purl.org/dc/elements/1.1/" ] /item/dc:creator', xt, 1) as varchar);
  if (isnull(author))
    author := cast (xpath_eval ('/item/author', xt, 1) as varchar);

  ENEWS.WA.process_insert(feed_id, title, description, link, guid, pubDate, comment_api, comment_rss, author, xt);
}
;

-------------------------------------------------------------------------------
--
create procedure ENEWS.WA.process_atom_item(
  inout xt any,
  inout feed_id integer)
{
  declare
    title,
    description,
    link,
    guid,
    pubdate,
    comment_api,
    comment_rss,
    author varchar;
  declare
    content,
    contents any;

  title := serialize_to_UTF8_xml (xpath_eval ('string(/entry/title)', xt, 1));
  if (xpath_eval ('/entry/content[@type = "application/xhtml+xml" or @type="xhtml"]', xt) is not null) {
    contents := xpath_eval ('/entry/content/*', xt, 0);
    if (length(contents) = 1) {
      description := ENEWS.WA.xml2string(contents[0]);
    } else {
      description := '<div>';
      foreach (any content in contents) do
        description := concat(description, ENEWS.WA.xml2string(content));
      description := concat(description, '</div>');
    }
  } else {
    description := xpath_eval ('string(/entry/content)', xt, 1);
    if (is_empty_or_null(description))
      description := xpath_eval ('string(/entry/summary)', xt, 1);
    description := ENEWS.WA.string2xml (serialize_to_UTF8_xml (description));
  }
  link := cast (xpath_eval ('/entry/link[@rel="alternate"]/@href', xt, 1) as varchar);
  guid := cast (xpath_eval ('/entry/id', xt, 1) as varchar);
  pubdate := ENEWS.WA.dt_convert(cast(xpath_eval ('/entry/created', xt, 1) as varchar), null);
  if (isnull(pubDate)) {
    pubdate := ENEWS.WA.dt_convert(cast(xpath_eval ('/entry/modified', xt, 1) as varchar), null);
    if (isnull(pubDate)) {
    pubdate := ENEWS.WA.dt_convert(cast(xpath_eval ('/entry/updated', xt, 1) as varchar), null);
  if (isnull(pubDate))
    pubdate := now();
    }
  }

  comment_api := null;
  comment_rss := null;
  author := cast (xpath_eval ('/entry/author/name', xt, 1) as varchar);

  ENEWS.WA.process_insert(feed_id, title, description, link, guid, pubDate, comment_api, comment_rss, author, xt);
}
;

-------------------------------------------------------------------------------
--
create procedure ENEWS.WA.process_insert(
  inout feed_id integer,
  inout title varchar,
  inout description varchar,
  inout link varchar,
  inout guid varchar,
  inout pubdate datetime,
  inout comment_api varchar,
  inout comment_rss varchar,
  inout author varchar,
  inout data any)
{
  declare item_id, enclosure integer;
  declare tags varchar;

  if (isnull(guid) and not isnull(link))
    guid := link;
  if (isnull(guid) and not isnull(pubdate))
    guid := cast(pubdate as varchar) || ' ' || cast(title as varchar);
  if (isnull(guid))
    guid := title;

  if (exists (select EFI_FEED_ID from ENEWS.WA.FEED_ITEM where EFI_FEED_ID = feed_id and EFI_GUID = guid))
    return;

  enclosure := 0;
  if (not is_empty_or_null(cast (xpath_eval ('//enclosure/@url', data, 1) as varchar)))
    enclosure := 1;
  insert into ENEWS.WA.FEED_ITEM(EFI_FEED_ID, EFI_TITLE, EFI_DESCRIPTION, EFI_LINK, EFI_GUID, EFI_PUBLISH_DATE, EFI_COMMENT_API, EFI_COMMENT_RSS, EFI_AUTHOR, EFI_LAST_UPDATE, EFI_ENCLOSURE, EFI_DATA)
    values(feed_id, title, description, link, guid, pubDate, comment_api, comment_rss, author, now(), enclosure, data);

  item_id := (select EFI_ID from ENEWS.WA.FEED_ITEM where EFI_FEED_ID = feed_id and EFI_GUID = guid);

  -- post tags
  tags := ENEWS.WA.tags_item (item_id);

  -- domain tags
  for (select EFD_DOMAIN_ID, EFD_TAGS from ENEWS.WA.FEED_DOMAIN where EFD_FEED_ID = feed_id) do {
    if (ENEWS.WA.conversation_enable(EFD_DOMAIN_ID))
      ENEWS.WA.nntp_root (EFD_DOMAIN_ID, item_id);
    ENEWS.WA.tags_domain_item(EFD_DOMAIN_ID, item_id, EFD_TAGS, tags);
  }
}
;

-------------------------------------------------------------------------------
--
create procedure ENEWS.WA.process_authorEMail(
  inout data any)
{
  declare authorEMail varchar;

  authorEMail := '';
  if (xpath_eval ('/item', data) is not null) {
    authorEMail := cast (xpath_eval ('[ xmlns:dc="http://purl.org/dc/elements/1.1/" ] /item/dc:creator', data, 1) as varchar);
    if (isnull(authorEMail))
      authorEMail := cast (xpath_eval ('/item/author', data, 1) as varchar);
  }
  if (xpath_eval ('/entry', data) is not null)
    authorEMail := cast (xpath_eval ('/entry/author/email', data, 1) as varchar);
  return authorEMail;
}
;

-------------------------------------------------------------------------------
--
create procedure ENEWS.WA.channel_retrieve (
  inout uri varchar,
  inout xt varchar,
  in type integer := 0) returns integer
{
  declare cont varchar;
  declare hp any;

  declare exit handler for sqlstate '*' { return __SQL_MESSAGE;};

_retrieve:
  hp := WS.WS.PARSE_URI (uri);

  if (lower(hp[0]) <> 'http') {
    cont := DB.DBA.XML_URI_GET (uri, '');
  } else {
    declare N integer;
    declare oldUri, newUri, reqHdr, resHdr varchar;

    N := 0;
    newUri := uri;
    reqHdr := null;
    if (type = 2) {
      declare auth_uid, auth_pwd varchar;

      ENEWS.WA.account_access (auth_uid, auth_pwd);
      reqHdr := sprintf('Authorization: Basic %s', encode_base64(auth_uid || ':' || auth_pwd));
    }

  _again:
    N := N + 1;
    oldUri := newUri;
    if (type = 2)
      commit work;
    cont := http_get (newUri, resHdr, 'GET', reqHdr);
    if (resHdr[0] like 'HTTP/1._ 30_ %') {
      newUri := http_request_header (resHdr, 'Location');
      newUri := WS.WS.EXPAND_URL (oldUri, newUri);
      if (N > 15)
        return 'Too many redirects or redirect loops back, please specify the correct URL.';
      if (newUri <> oldUri)
        goto _again;
    }
    if (resHdr[0] like 'HTTP/1._ 4__ %' or resHdr[0] like 'HTTP/1._ 5__ %')
      return resHdr[0];
  }
  xt := ENEWS.WA.string2xml (cont);
  return '';
}
;

-------------------------------------------------------------------------------
--
create procedure ENEWS.WA.channel_add(
  inout channels any,
  inout uri any,
  inout links any,
  in format varchar)
{
  declare N, L integer;
  foreach (any link in links) do {
    if (isstring (link))
      link := xpath_eval ('/link', xtree_doc (link));
    L := length(channels);
    for (N := 1; N < L; N := N + 1)
      if (get_keyword('rss', channels[N]) = xpath_eval ('@href', link))
        goto _next;
    channels := vector_concat (channels, vector (vector ('title', xpath_eval ('@title', link), 'rss',  WS.WS.EXPAND_URL (uri, xpath_eval ('@href', link)), 'format', format)));
  _next:;
  }
}
;

-------------------------------------------------------------------------------
--
create procedure ENEWS.WA.channels_uri (
  inout uri varchar,
  in type integer := 0) returns any
{
  declare xt, channel any;

  channel := ENEWS.WA.channel_select (uri);
  if (length(channel))
    return vector_concat (vector ('channel'), vector(channel));
  if (ENEWS.WA.channel_retrieve (uri, xt, type) = '')
    return ENEWS.WA.channels_get(uri, xt);
  return vector ();
}
;

-------------------------------------------------------------------------------
--
create procedure ENEWS.WA.channels_content (
  inout cont varchar) returns any
{
  declare xt any;

  declare exit handler for sqlstate '*' { return __SQL_MESSAGE;};

  xt := ENEWS.WA.string2xml (cont);
  return ENEWS.WA.channels_get(null, xt);
}
;

-------------------------------------------------------------------------------
--
create procedure ENEWS.WA.channels_get (
  in uri varchar,
  inout xt any) returns any
{
  declare N, L int;
  declare title, home, email, rss, format, lang any;
  declare links, channels any;

  channels := vector ();
  declare exit handler for sqlstate '*' { goto _end; };

  if (xpath_eval ('/html', xt, 1) is not null)  {
    -- HTML, do auto discovery of the feeds
    declare aRss, aAtom, aOpml any;
    title := cast(xpath_eval('//title[1]/text()', xt, 1) as varchar);
    aRss := xpath_eval('//head/link[ @rel="alternate" and @type="application/rss+xml" ]/@href', xt, 0);
    aAtom := xpath_eval('//head/link[ @rel="alternate" and @type="application/atom+xml" ]/@href', xt, 0);
    aOpml := xpath_eval('//head/link[ @rel="subscriptions" and @type="text/x-opml" ]/@href', xt, 0);
    if (length(aRss) = 1 and length(aAtom) = 0 and length(aOpml) = 0) {
      rss := cast (aRss[0] as varchar);
      rss := WS.WS.EXPAND_URL (uri, rss);
      format := 'http://my.netscape.com/rdf/simple/0.9/';
      channels := vector_concat (channels, vector ('channel'));
      channels := vector_concat (channels, vector (vector ('title', title, 'blog', uri, 'rss', rss, 'format', format)));

    } else if (length(aRss) = 0 and length(aAtom) = 1 and length(aOpml) = 0) {
      rss := cast (aAtom[0] as varchar);
      rss := WS.WS.EXPAND_URL (uri, rss);
      format := 'http://purl.org/atom/ns#';
      channels := vector_concat (channels, vector ('channel'));
      channels := vector_concat (channels, vector (vector ('title', title, 'blog', uri, 'rss', rss, 'format', format)));

    } else if (length(aRss) <> 0 or length(aAtom) <> 0 or length(aOpml) <> 0) {
      channels := vector_concat (channels, vector ('links'));
      links := xpath_eval('//head/link[ @rel="alternate" and @type="application/rss+xml" ]', xt, 0);
      ENEWS.WA.channel_add(channels, uri, links, 'RSS');
      links := xpath_eval('//head/link[ @rel="alternate" and @type="application/atom+xml" ]', xt, 0);
      ENEWS.WA.channel_add(channels, uri, links, 'ATOM');
      links := xpath_eval('//head/link[ @rel="subscriptions" and @type="text/x-opml" ]', xt, 0);
      ENEWS.WA.channel_add(channels, uri, links, 'OPML');
    }

  } else if ((xpath_eval ('/rss|/RDF/channel', xt, 1) is not null) or
             (xpath_eval ('/Channel', xt, 1) is not null) or
             (xpath_eval ('/feed', xt, 1) is not null)) {
    -- RSS or Atom feed
    declare channel any;
    channel := ENEWS.WA.channel_get (uri, xt);
    if (length(channel)) {
      channels := vector_concat (channels, vector ('channel'));
      channels := vector_concat (channels, vector (channel));
    }

  } else if (xpath_eval ('[ xmlns:ocs="http://alchemy.openjava.org/ocs/directory#" xmlns:ocs1="http://InternetAlchemy.org/ocs/directory#" ] /RDF//ocs:format|/RDF//ocs1:format', xt, 1) is not null) {
    -- OCS directory
    channels := vector_concat (channels, vector ('OCS'));
    ENEWS.WA.channels_ocs (channels, xt);

  } else if (xpath_eval ('/opml', xt, 1) is not null) {
    -- OPML file
    declare outlines any;

    channels := vector_concat (channels, vector ('OPML'));
    title := cast(xpath_eval ('/opml/head/title/text()', xt, 1) as varchar);
    outlines := xpath_eval ('/opml/body/outline', xt, 0);
    L := length (outlines);
    for (N := 0; N < L; N := N + 1)
      ENEWS.WA.channels_opml (channels, xml_cut(outlines[N]), title);
  }
_end:
  return channels;
}
;

-------------------------------------------------------------------------------
--
create procedure ENEWS.WA.channels_ocs (
  inout channels any,
  inout xt any)
{
  declare i, j, k, l integer;
  declare title, home, email, rss, format, lang, upd_per, upd_freq any;
  declare links any;
  declare ns varchar;

  ns := '[ xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#" ' ||
        ' xmlns:ocs="http://alchemy.openjava.org/ocs/directory#" ' ||
        ' xmlns:ocs1="http://InternetAlchemy.org/ocs/directory#" ' ||
        ' xmlns:dc="http://purl.org/metadata/dublin_core#" ] ';
  links := xpath_eval (ns || '/rdf:RDF/rdf:description[1]/rdf:description', xt, 0);
  l := length(links);
  for (i := 0; i < l; i := i + 1) {
    declare formats any;
    title := xpath_eval (ns || '/rdf:description/dc:title/text()', xml_cut (links[i]), 1);
    home := xpath_eval (ns || '/rdf:description/@about', xml_cut (links[i]), 1);
    formats := xpath_eval (ns || '/rdf:description/rdf:description[ocs:format or ocs1:format]', xml_cut (links[i]), 0);
    k := length(formats);
    for (j := 0; j < k; j := j + 1) {
      xt := xml_cut(formats[j]);
      rss := cast(xpath_eval ('/description/@about', xt, 1) as varchar);
      format := cast(xpath_eval ('/description/format/text()', xt, 1) as varchar);
      lang := cast(xpath_eval ('/description/language/text()', xt, 1) as varchar);
      upd_per := cast(xpath_eval ('/description/updatePeriod/text()', xt, 1) as varchar);
      upd_freq := coalesce (xpath_eval ('/description/updateFrequency/text()', xt, 1), '1');
      upd_freq := atoi (cast (upd_freq as varchar));

      if (not is_empty_or_null(rss))
        channels := vector_concat (channels, vector (vector ('title', title, 'blog', home, 'rss', rss, 'format', format, 'lang', lang, 'updatePeriod', upd_per, 'updateFrequency', upd_freq)));
    }
  }
}
;

-------------------------------------------------------------------------------
--
create procedure ENEWS.WA.channels_opml (
  inout channels any,
  in xt any,
  in folder varchar)
{
  declare i, k integer;
  declare title, home, rss, format, lang varchar;
  declare outlines any;

  title := xpath_eval ('string(/outline/@text)', xt, 1);
  if (is_empty_or_null(title))
    title := xpath_eval ('string(/outline/@title)', xt, 1);
  if (is_empty_or_null(title))
    return;

  rss := cast(xpath_eval ('/outline/@xmlurl | /outline/@xmlUrl | /outline/@link', xt, 1) as varchar);
  if (not is_empty_or_null(rss)) {
    home := cast(xpath_eval ('/outline/@htmlUrl | /outline/@htmlurl', xt, 1) as varchar);
    lang := cast(xpath_eval ('/outline/@language', xt, 1) as varchar);
    format := 'http://my.netscape.com/rdf/simple/0.9/';
    channels := vector_concat (channels, vector (vector ('title', title, 'blog', home, 'rss', rss, 'format', format, 'lang', lang, 'folder', folder)));
  }
  folder := folder || '/' || title;
  outlines := xpath_eval ('/outline/outline', xt, 0);
  k := length(outlines);
  for (i := 0; i < k; i := i + 1)
    ENEWS.WA.channels_opml (channels, xml_cut(outlines[i]), folder);
}
;

-------------------------------------------------------------------------------
--
create procedure ENEWS.WA.channel_get (
  inout uri varchar,
  inout xt any) returns any
{
  declare title, home, format, version, lang, css, data, tmp, channel any;

  channel := vector ();
  data := null;
  declare exit handler for sqlstate '*' { goto _end; };

  if (xpath_eval ('/rss|/RDF/channel', xt, 1) is not null) {
    -- RSS feed
    css := ENEWS.WA.channel_css(xt);
    xt := xml_cut (xpath_eval ('/rss/channel[1]|/RDF/channel[1]', xt, 1));
    title := serialize_to_UTF8_xml(xpath_eval ('string(/channel/title/text())', xt, 1));
    home := cast (xpath_eval ('/channel/link/text()', xt, 1) as varchar);
    format := 'http://my.netscape.com/rdf/simple/0.9/';
    lang := cast (xpath_eval ('/channel/language/text()', xt, 1) as varchar);

    tmp := cast (xpath_eval ('/channel/image/url/text()', xt, 1) as varchar);
    if (not isnull(tmp))
      ENEWS.WA.xml_set('imageUrl', data, tmp);

    tmp := ENEWS.WA.channel_icon(home);
    if (not isnull(tmp))
      ENEWS.WA.xml_set('iconUrl', data, tmp);

    channel := vector ('type', 'long', 'title', title, 'blog', home, 'rss', uri, 'format', format, 'lang', lang, 'css', css, 'data', data);

  } else if (xpath_eval ('/Channel', xt, 1) is not null) {
    -- RSS feed v1.1
    css := ENEWS.WA.channel_css(xt);
    xt := xml_cut (xpath_eval ('/Channel[1]', xt, 1));
    title := serialize_to_UTF8_xml(xpath_eval ('string(/Channel/title/text())', xt, 1));
    home := cast (xpath_eval ('/Channel/link/text()', xt, 1) as varchar);
    format := 'http://purl.org/net/rss1.1#';
    lang := cast (xpath_eval ('/Channel/language/text()', xt, 1) as varchar);

    tmp := cast (xpath_eval ('/Channel/image/url/text()', xt, 1) as varchar);
    if (not isnull(tmp))
      ENEWS.WA.xml_set('imageUrl', data, tmp);

    tmp := ENEWS.WA.channel_icon(home);
    if (not isnull(tmp))
      ENEWS.WA.xml_set('iconUrl', data, tmp);

    channel := vector ('type', 'long', 'title', title, 'blog', home, 'rss', uri, 'format', format, 'lang', lang, 'css', css, 'data', data);

  } else if (xpath_eval ('/feed', xt, 1) is not null) {
    -- Atom feed
    css := ENEWS.WA.channel_css(xt);
    xt := xml_cut (xpath_eval ('/feed[1]', xt, 1));
    title := serialize_to_UTF8_xml(xpath_eval ('string(/feed/title/text()|/feed/author/name/text())', xt, 1));
    home := cast (xpath_eval ('/feed/link[@rel="service.post" and @type="application/atom+xml"]/@href', xt) as varchar);
    if (isnull(home))
      home := cast (xpath_eval ('/feed/link[@rel="alternate" and @type="application/xhtml+xml"]/@href', xt) as varchar);

    version := xpath_eval ('string(/feed/@version)', xt, 1);
    if (version = '1.0') {
      format := 'http://www.w3.org/2005/Atom';
    } else {
      format := 'http://purl.org/atom/ns#';
    }
    lang := cast (xpath_eval ('/feed/@lang', xt, 1) as varchar);

    tmp := cast (xpath_eval ('/Channel/image/url/text()', xt, 1) as varchar);
    if (not isnull(tmp))
      ENEWS.WA.xml_set('imageUrl', data, tmp);

    tmp := ENEWS.WA.channel_icon(home);
    if (not isnull(tmp))
      ENEWS.WA.xml_set('iconUrl', data, tmp);

    channel := vector ('type', 'long', 'title', title, 'blog', home, 'rss', uri, 'format', format, 'lang', lang, 'css', css, 'data', data);
  }
_end:
  return channel;
}
;

-------------------------------------------------------------------------------
--
create procedure ENEWS.WA.channel_icon(
  inout uri varchar) returns any
{
  declare iconUrl, xt any;

  iconUrl := null;

  declare exit handler for sqlstate '*' { goto _end; };

  if (ENEWS.WA.channel_retrieve (uri, xt) <> '')
    goto _end;

  if (xpath_eval ('/html', xt, 1) is not null)  {
    iconUrl := cast(xpath_eval('//head/link[ @rel="shortcut icon" and @type="image/x-icon" ]/@href', xt, 1) as varchar);
    if (iconUrl like 'http://%')
      goto _end;
    iconUrl := concat(trim(uri, '/'), '/', ltrim(iconUrl, '/'));
  }

_end:
  return iconUrl;
}
;

-------------------------------------------------------------------------------
--
create procedure ENEWS.WA.channel_css(
  inout xt any) returns any
{
  declare css varchar;
  declare parts any;

  css := cast(xpath_eval ('//processing-instruction(\'xml-stylesheet\')', xt, 1) as varchar);
  if (not isnull(css)) {
    parts := regexp_parse('href="([^"]+)"', css, 0);
    if (not isnull(parts))
      css := subseq (css, parts[2], parts[3]);
  }
  return css;
}
;

-------------------------------------------------------------------------------
--
create procedure ENEWS.WA.channel_create(
  inout channel any)
{
  declare uri varchar;

  uri := get_keyword('rss', channel);
  if (not exists(select 1 from ENEWS.WA.FEED where EF_URI = uri)) {
    declare data any;

    data := get_keyword('data', channel);
    if (get_keyword('type', channel, 'short') = 'short') {
      declare tmp any;

      tmp := ENEWS.WA.channels_uri (get_keyword('rss', channel, ''));
      if ((length(tmp) > 0) and (tmp[0] = 'channel'))
        data := get_keyword('data', tmp[1]);
    }

    insert into ENEWS.WA.FEED (
            EF_URI,
            EF_TITLE,
            EF_HOME_URI,
            EF_SOURCE_URI,
            EF_DESCRIPTION,
            EF_COPYRIGHT,
            EF_CSS,
            EF_FORMAT,
            EF_LANG,
            EF_UPDATE_PERIOD,
            EF_UPDATE_FREQ,
            EF_DATA)
    values (
            uri,
            ENEWS.WA.wide2utf(get_keyword('title', channel, '')),
            get_keyword('blog', channel, ''),
            get_keyword('source', channel, ''),
            get_keyword('description', channel, ''),
            get_keyword('copyright', channel, ''),
            get_keyword('css', channel, ''),
            get_keyword('format', channel, ''),
            get_keyword('lang', channel, 'us-en'),
            get_keyword('updatePeriod', channel, 'daily'),
            get_keyword('updateFrequency', channel, 4),
            data);
  }
  return (select EF_ID from ENEWS.WA.FEED where EF_URI = uri);
}
;

-------------------------------------------------------------------------------
--
create procedure ENEWS.WA.channel_select(
  inout feed_uri varchar)
{
  for (select EF_ID,
              EF_TITLE,
              EF_HOME_URI,
              EF_SOURCE_URI,
              EF_DESCRIPTION,
              EF_COPYRIGHT,
              EF_CSS,
              EF_FORMAT,
              EF_UPDATE_PERIOD,
              EF_UPDATE_FREQ,
              EF_STORE_DAYS,
              EF_LANG,
              EF_DATA
         from ENEWS.WA.FEED
        where EF_URI = feed_uri) do
    return vector ('type', 'long', 'id', EF_ID, 'title', EF_TITLE, 'blog', EF_HOME_URI, 'rss', feed_uri, 'source', EF_SOURCE_URI, 'description', EF_DESCRIPTION, 'copyright', EF_COPYRIGHT, 'css', EF_CSS, 'format', EF_FORMAT, 'lang', EF_LANG, 'updatePeriod', EF_UPDATE_PERIOD, 'updateFrequency', EF_UPDATE_FREQ, 'data', EF_DATA);
  return vector();
}
;


-------------------------------------------------------------------------------
--
create procedure ENEWS.WA.channel_delete(
  inout domain_id integer,
  inout feed_id varchar)
{
  delete from ENEWS.WA.FEED_DOMAIN where EFD_DOMAIN_ID = domain_id and EFD_FEED_ID = feed_id;
  ENEWS.WA.channel_reindex(feed_id);
  commit work;
  if (not exists (select 1 from ENEWS.WA.FEED_DIRECTORY where EFD_FEED_ID = feed_id))
    {
      declare exit handler for SQLSTATE '*' { return; };
      delete from ENEWS.WA.FEED where EF_ID = feed_id;
    }
}
;

-------------------------------------------------------------------------------
--
create procedure ENEWS.WA.channel_feeds(
  inout feed_id varchar)
{
  return (select count(*) from ENEWS.WA.FEED_ITEM where EFI_FEED_ID = feed_id and coalesce(EFI_DELETE_FLAG, 0) = 0);
}
;


-------------------------------------------------------------------------------
--
create procedure ENEWS.WA.channel_domain(
  inout domain_id varchar,
  inout feed_id varchar,
  in title any,
  in tags any,
  in folder_name any,
  in folder_id any)
{
  folder_name := trim(folder_name);
  if (folder_name <> '') {
    folder_id := ENEWS.WA.folder_id(domain_id, folder_name);
  } else {
    folder_id := cast(folder_id as integer);
  }
  if (folder_id = 0)
    folder_id := null;
  if (exists(select 1 from ENEWS.WA.FEED_DOMAIN where EFD_DOMAIN_ID = domain_id and EFD_FEED_ID = feed_id and coalesce(EFD_FOLDER_ID, 0) = coalesce(folder_id, 0))) {
    update ENEWS.WA.FEED_DOMAIN
       set EFD_TITLE = title,
           EFD_TAGS = tags,
           EFD_FOLDER_ID = folder_id
     where EFD_DOMAIN_ID = domain_id
       and EFD_FEED_ID = feed_id;
  } else {
    insert replacing ENEWS.WA.FEED_DOMAIN(EFD_DOMAIN_ID, EFD_FEED_ID, EFD_TITLE, EFD_TAGS, EFD_FOLDER_ID)
      values (domain_id, feed_id, title, tags, folder_id);
    ENEWS.WA.channel_reindex(feed_id);
  }
}
;

-------------------------------------------------------------------------------
--
create procedure ENEWS.WA.channel_reindex(
  in feed_id varchar)
{
  update ENEWS.WA.FEED
     set EF_ID = EF_ID
   where EF_ID = feed_id;
}
;

-------------------------------------------------------------------------------
--
create procedure ENEWS.WA.channel_directory(
  inout feed_id varchar,
  in directory_name any,
  in directory_id any)
{
  directory_name := trim(directory_name);
  if (is_empty_or_null(directory_name)) {
    directory_id := cast(directory_id as integer);
  } else {
    directory_id := ENEWS.WA.directory_id(directory_name);
  }
  delete from ENEWS.WA.FEED_DIRECTORY where EFD_FEED_ID = feed_id;
  if (not is_empty_or_null(directory_id))
    insert into ENEWS.WA.FEED_DIRECTORY(EFD_FEED_ID, EFD_DIRECTORY_ID)
      values (feed_id, directory_id);
}
;

-------------------------------------------------------------------------------
--
create procedure ENEWS.WA.channel_image(
  inout domain_id integer,
  inout account_id integer,
  inout data any,
  in defaultImage varchar)
{
  if (ENEWS.WA.settings_icons(domain_id, account_id))
    return ENEWS.WA.xml_get('imageUrl', data, defaultImage);
  return defaultImage;
}
;

-------------------------------------------------------------------------------
--
create procedure ENEWS.WA.folder_id(
  in domain_id integer,
  in folder_name varchar)
{
  declare N, L, folder_id integer;
  declare aPath any;

  folder_id := null;
  if (not is_empty_or_null(folder_name)) {
    aPath := split_and_decode(trim(folder_name, '/'),0,'\0\0/');
    L := length(aPath);
    for (N := 0; N < L; N := N + 1) {
      if (N = 0) {
        if (not exists (select 1 from ENEWS.WA.FOLDER where EFO_DOMAIN_ID = domain_id and EFO_NAME = aPath[N] and EFO_PARENT_ID is null))
          insert into ENEWS.WA.FOLDER (EFO_DOMAIN_ID, EFO_NAME) values (domain_id, aPath[N]);
        folder_id := (select EFO_ID from ENEWS.WA.FOLDER where EFO_DOMAIN_ID = domain_id and EFO_NAME = aPath[N] and EFO_PARENT_ID is null);
      } else {
        if (not exists (select 1 from ENEWS.WA.FOLDER where EFO_DOMAIN_ID = domain_id and EFO_NAME = aPath[N] and EFO_PARENT_ID = folder_id))
          insert into ENEWS.WA.FOLDER (EFO_DOMAIN_ID, EFO_PARENT_ID, EFO_NAME) values (domain_id, folder_id, aPath[N]);
        folder_id := (select EFO_ID from ENEWS.WA.FOLDER where EFO_DOMAIN_ID = domain_id and EFO_NAME = aPath[N] and EFO_PARENT_ID = folder_id);
      }
    }
  }
  return folder_id;
}
;

-------------------------------------------------------------------------------
--
create procedure ENEWS.WA.folder_tree_int(
  in domain_id integer,
  in id integer,
  inout retValue any)
{
  declare isFound integer;

  isFound := 0;
  for (select EFO_ID, EFO_NAME from ENEWS.WA.FOLDER where EFO_DOMAIN_ID = domain_id and EFO_ID = id) do {
    http (sprintf ('\n<node name="%V" id="%d">', EFO_NAME, EFO_ID), retValue);
    isFound := 1;
  }
  for (select EFO_ID from ENEWS.WA.FOLDER where EFO_DOMAIN_ID = domain_id and coalesce(EFO_PARENT_ID, 0) = coalesce(id, 0) order by EFO_NAME) do
    ENEWS.WA.folder_tree_int(domain_id, EFO_ID, retValue);
  if (isFound)
    http ('</node>\n', retValue);
 }
 ;

-------------------------------------------------------------------------------
--
create procedure ENEWS.WA.folder_tree(
  in domain_id integer)
{
  declare retValue any;

  retValue := string_output ();
  http ('<node>', retValue);
  ENEWS.WA.folder_tree_int(domain_id, null, retValue);
  http ('</node>', retValue);
  return string_output_string (retValue);
}
;

-------------------------------------------------------------------------------
--
create procedure ENEWS.WA.folder_root(
  in path varchar := '')
{
  return xpath_eval ('/node/*', xml_tree_doc (ENEWS.WA.folder_tree (cast(path as integer))), 0);
}
;

-------------------------------------------------------------------------------
--
create procedure ENEWS.WA.folder_child(
  in path varchar,
  in node varchar)
{
  return xpath_eval (path, node, 0);
}
;

-------------------------------------------------------------------------------
--
create procedure ENEWS.WA.folder_delete(
  in domain_id integer,
  in folder_id integer)
{
  declare parent_id integer;

  parent_id := (select EFO_PARENT_ID from ENEWS.WA.FOLDER where EFO_DOMAIN_ID = domain_id and EFO_ID = folder_id);
  update ENEWS.WA.FEED_DOMAIN
     set EFD_FOLDER_ID = parent_id
   where EFD_DOMAIN_ID = domain_id
     and EFD_FOLDER_ID = folder_id;

  for (select EFO_ID from ENEWS.WA.FOLDER where EFO_DOMAIN_ID = domain_id and EFO_PARENT_ID = folder_id) do
    ENEWS.WA.folder_delete(domain_id, EFO_ID);

  delete from ENEWS.WA.FOLDER where EFO_DOMAIN_ID = domain_id and EFO_ID = folder_id;
}
;

-------------------------------------------------------------------------------
--
create procedure ENEWS.WA.folder_delete_all(
  in domain_id integer)
{
  for (select EFO_ID from ENEWS.WA.FOLDER where EFO_DOMAIN_ID = domain_id and EFO_PARENT_ID is null) do
    ENEWS.WA.folder_delete(domain_id, EFO_ID);
}
;

-------------------------------------------------------------------------------
--
create procedure ENEWS.WA.folder_path(
  in domain_id integer,
  in folder_id integer)
{
  declare path, name varchar;
  declare parent_id integer;

  path := '/';
  whenever not found goto nf;
  while (folder_id > 0) {
    select EFO_NAME, EFO_PARENT_ID into name, parent_id from ENEWS.WA.FOLDER where EFO_DOMAIN_ID = domain_id and EFO_ID = folder_id;
    folder_id := parent_id;
    path := concat ('/', name, path);
  }
  return trim(path, '/');
nf:
  return NULL;
}
;

-------------------------------------------------------------------------------
--
create procedure ENEWS.WA.folder_path2(
  in domain_id integer,
  in folder_id integer)
{
  declare path varchar;
  declare aPath varchar;

  path := ENEWS.WA.folder_path(domain_id, folder_id);
  aPath := split_and_decode(path,0,'\0\0/');
  return concat(repeat('~', length(aPath)-1), aPath[length(aPath)-1]);
}
;

-------------------------------------------------------------------------------
--
create procedure ENEWS.WA.folder_level(
  in path varchar)
{
  return (length(split_and_decode(path,0,'\0\0/')) - 1);
}
;

-------------------------------------------------------------------------------
--
create procedure ENEWS.WA.folder_check_name(
  in folder_name varchar,
  in is_path integer := 0)
{
  if (is_path) {
    declare N, L integer;
    declare aPath any;

    aPath := split_and_decode(trim(folder_name, '/'),0,'\0\0/');
    L := length(aPath);
    for (N := 0; N < L; N := N + 1)
      if (not ENEWS.WA.validate('folder', aPath[N]))
        return 0;
    return 1;
  } else {
    return ENEWS.WA.validate('folder', folder_name);
  }
}
;

-------------------------------------------------------------------------------
--
create procedure ENEWS.WA.folder_check_unique(
  in domain_id integer,
  in parent_id integer,
  in name varchar,
  in folder_id integer := 0)
{
  declare retValue integer;

  retValue := coalesce((select EFO_ID from ENEWS.WA.FOLDER where EFO_DOMAIN_ID=domain_id and coalesce(EFO_PARENT_ID, 0)=coalesce(parent_id, 0) and EFO_NAME=name), 0);
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
create procedure ENEWS.WA.folder_check_parent(
  in domain_id integer,
  in parent_id integer,
  in folder_id integer)
{
  declare new_id integer;

  if (folder_id = parent_id)
    return 1;

  new_id := (select EFO_PARENT_ID from ENEWS.WA.FOLDER where EFO_DOMAIN_ID = domain_id and EFO_ID = folder_id);
  if (isnull(new_id)) {
    if (isnull(parent_id))
      return 1;
    return 0;
  }

  if (new_id = parent_id)
    return 1;

  return ENEWS.WA.folder_check_parent(domain_id, parent_id, new_id);
}
;

-------------------------------------------------------------------------------
--
create procedure ENEWS.WA.directory_id(
  in directory_name varchar)
{
  if (is_empty_or_null(directory_name))
    return null;
  if (not exists (select 1 from ENEWS.WA.DIRECTORY where ED_NAME = directory_name and ED_PARENT_ID is null))
    insert into ENEWS.WA.DIRECTORY (ED_NAME)
      values (directory_name);
  return (select ED_ID from ENEWS.WA.DIRECTORY where ED_NAME = directory_name);
}
;

-------------------------------------------------------------------------------
--
create procedure ENEWS.WA.directory_tree_int(
  in id integer,
  inout retValue any)
{
  declare isFound integer;

  isFound := 0;
  for (select ED_ID, ED_NAME from ENEWS.WA.DIRECTORY where ED_ID = id) do {
    http (sprintf ('\n<node name="%V" id="%d">', ED_NAME, ED_ID), retValue);
    isFound := 1;
  }
  for (select ED_ID from ENEWS.WA.DIRECTORY where coalesce(ED_PARENT_ID, 0) = coalesce(id, 0) order by ED_NAME) do
    ENEWS.WA.directory_tree_int(ED_ID, retValue);
  if (isFound)
    http ('</node>\n', retValue);
 }
 ;

-------------------------------------------------------------------------------
--
create procedure ENEWS.WA.directory_tree()
{
  declare retValue any;

  retValue := string_output ();
  http ('<node>', retValue);
  ENEWS.WA.directory_tree_int(null, retValue);
  http ('</node>', retValue);
  return string_output_string (retValue);
}
;

-------------------------------------------------------------------------------
--
create procedure ENEWS.WA.directory_root(
  in path varchar := '')
{
  return xpath_eval ('/node/*', xml_tree_doc (ENEWS.WA.directory_tree ()), 0);
}
;

-------------------------------------------------------------------------------
--
create procedure ENEWS.WA.directory_child(
  in path varchar,
  in node varchar)
{
  return xpath_eval (path, node, 0);
}
;

-------------------------------------------------------------------------------
--
create procedure ENEWS.WA.directory_insert(
  in parent_path varchar,
  in name varchar)
{
  declare parent_id integer;

  parent_id := null;
  if (not isnull(parent_path))
    parent_id := (select ED_ID from ENEWS.WA.DIRECTORY where ENEWS.WA.directory_path(ED_ID) = parent_path);
  if (not ENEWS.WA.directory_check_unique(parent_id, name))
    insert soft ENEWS.WA.DIRECTORY(ED_PARENT_ID, ED_NAME) values(parent_id, name);
}
;

-------------------------------------------------------------------------------
--
create procedure ENEWS.WA.directory_delete(
  in directory_id integer)
{
  declare parent_id integer;

  parent_id := (select ED_PARENT_ID from ENEWS.WA.DIRECTORY where ED_ID = directory_id);
  if (isnull(parent_id)) {
    delete from ENEWS.WA.FEED_DIRECTORY
     where EFD_DIRECTORY_ID = directory_id;
  } else {
    update ENEWS.WA.FEED_DIRECTORY
       set EFD_DIRECTORY_ID = parent_id
     where EFD_DIRECTORY_ID = directory_id;
  }

  for (select ED_ID from ENEWS.WA.DIRECTORY where ED_PARENT_ID = directory_id) do
    ENEWS.WA.directory_delete(ED_ID);

  delete from ENEWS.WA.DIRECTORY where ED_ID = directory_id;
}
;

-------------------------------------------------------------------------------
--
create procedure ENEWS.WA.directory_delete_all()
{
  for (select ED_ID from ENEWS.WA.DIRECTORY where ED_PARENT_ID is null) do
    ENEWS.WA.directory_delete(ED_ID);
}
;

-------------------------------------------------------------------------------
--
create procedure ENEWS.WA.directory_path(
  in directory_id integer)
{
  declare path, name varchar;
  declare parent_id integer;

  path := '/';
  whenever not found goto nf;
  while (directory_id > 0) {
    select ED_NAME, ED_PARENT_ID into name, parent_id from ENEWS.WA.DIRECTORY where ED_ID = directory_id;
    directory_id := parent_id;
    path := concat ('/', name, path);
  }
  return trim(path, '/');
nf:
  return NULL;
}
;

-------------------------------------------------------------------------------
--
create procedure ENEWS.WA.directory_path2(
  in directory_id integer)
{
  declare path varchar;
  declare aPath varchar;

  path := ENEWS.WA.directory_path(directory_id);
  aPath := split_and_decode(path,0,'\0\0/');
  return concat(repeat('~', length(aPath)-1), aPath[length(aPath)-1]);
}
;

-------------------------------------------------------------------------------
--
create procedure ENEWS.WA.directory_level(
  in path varchar)
{
  return (length(split_and_decode(path,0,'\0\0/')) - 1);
}
;

-------------------------------------------------------------------------------
--
create procedure ENEWS.WA.directory_check_name(
  in directory_name varchar,
  in is_path integer := 0)
{
  if (is_path) {
    declare i, l integer;
    declare aPath any;

    aPath := split_and_decode(trim(directory_name, '/'),0,'\0\0/');
    l := length(aPath);
    for (i := 0; i < l; i := i + 1)
      if (not ENEWS.WA.validate('folder', aPath[i]))
        return 0;
    return 1;
  } else {
    return ENEWS.WA.validate('folder', directory_name);
  }
}
;

-------------------------------------------------------------------------------
--
create procedure ENEWS.WA.directory_check_unique(
  in parent_id integer,
  in name varchar,
  in directory_id integer := 0)
{
  declare retValue integer;

  if (isnull(parent_id)) {
    retValue := coalesce((select ED_ID from ENEWS.WA.DIRECTORY where ED_PARENT_ID is null and ED_NAME=name), 0);
  } else {
    retValue := coalesce((select ED_ID from ENEWS.WA.DIRECTORY where ED_PARENT_ID=parent_id and ED_NAME=name), 0);
  }
  if (directory_id = 0)
    return retValue;
  if (retValue = 0)
    return retValue;
  if (retValue <> directory_id)
    return 1;
  return 0;
}
;

-------------------------------------------------------------------------------
--
create procedure ENEWS.WA.directory_check_parent(
  in parent_id integer,
  in directory_id integer)
{
  declare new_id integer;

  if (directory_id = parent_id)
    return 1;

  new_id := (select ED_PARENT_ID from ENEWS.WA.DIRECTORY where ED_ID = directory_id);
  if (isnull(new_id)) {
    if (isnull(parent_id))
      return 1;
    return 0;
  }

  if (new_id = parent_id)
    return 1;

  return ENEWS.WA.directory_check_parent(parent_id, new_id);
}
;

-------------------------------------------------------------------------------
--
-- Weblogs
--
-------------------------------------------------------------------------------
create procedure ENEWS.WA.weblog_tree(
  in path varchar)
{
  declare domain_id integer;
  declare retValue any;

  domain_id := cast(path as integer);

  retValue := string_output ();
  http ('<node>', retValue);
  for (select EW_ID, EW_NAME from ENEWS.WA.WEBLOG where EW_DOMAIN_ID = domain_id order by EW_NAME) do {
    http (sprintf ('<node name="%V" id="w#%d">', EW_NAME, EW_ID), retValue);
    for (select EB_ID, EB_NAME from ENEWS.WA.BLOG where EB_WEBLOG_ID = EW_ID order by EB_NAME) do {
      http (sprintf ('<node name="%V" id="b#%d"/>', EB_NAME, EB_ID), retValue);
    }
    http ('</node>', retValue);
  }
  http ('</node>', retValue);
  return string_output_string (retValue);
}
;

-------------------------------------------------------------------------------
--
create procedure ENEWS.WA.weblog_root(
  in path varchar)
{
  return xpath_eval ('/node/*', xml_tree_doc (ENEWS.WA.weblog_tree (path)), 0);
}
;

-------------------------------------------------------------------------------
--
create procedure ENEWS.WA.weblog_child(
  in path varchar,
  in node varchar)
{
  return xpath_eval (path, node, 0);
}
;

-------------------------------------------------------------------------------
--
create procedure ENEWS.WA.weblog_delete(
  in weblog_id integer)
{
  delete from ENEWS.WA.WEBLOG where EW_ID = weblog_id;
}
;

-------------------------------------------------------------------------------
--
create procedure ENEWS.WA.weblog_refresh(
  in weblog_id integer)
{
  declare exit handler for sqlstate '*' { return __SQL_STATE; };

  declare N, L integer;
  declare v_api, v_uri, v_port, v_endpoint, v_user, v_password varchar;
  declare blogs any;
  declare req BLOG..blogRequest;

	select EW_API,
         EW_URI,
         EW_PORT,
         EW_ENDPOINT,
         EW_USER,
         EW_PASSWORD
	  into v_api,
         v_uri,
         v_port,
         v_endpoint,
         v_user,
         v_password
    from ENEWS.WA.WEBLOG
	 where EW_ID = weblog_id;

  -- request
  req := new BLOG..blogRequest();
  req.appkey := 'appKey';
  req.user_name := v_user;
  req.passwd  := v_password;

  blogs := BLOG.blogger.get_Users_Blogs(ENEWS.WA.weblog_uri(v_uri, v_port, v_endpoint), req);

  L := length(blogs);
  for (N := 0; N < L; N :=  N + 1)
    ENEWS.WA.blog_create(weblog_id, get_keyword ('blogid', blogs[N]), get_keyword ('blogname', blogs[N]), get_keyword ('url', blogs[N]));
  return '';
}
;

-------------------------------------------------------------------------------
--
create procedure ENEWS.WA.weblog_uri(
  in uri varchar,
  in port varchar,
  in endpoint varchar)
{
  uri := rtrim(uri, '/');
  endpoint := ltrim(endpoint, '/');
  return concat(uri, ':', port, '/', endpoint);
}
;

-------------------------------------------------------------------------------
--
-- Blogs
--
-------------------------------------------------------------------------------
create procedure ENEWS.WA.blog_create(
  in weblog_id integer,
  in blogId varchar,
  in name varchar,
  in uri varchar)
{
  if (exists(select 1 from ENEWS.WA.BLOG where EB_WEBLOG_ID = weblog_id and EB_BLOGID = blogId)) {
    update ENEWS.WA.BLOG
       set EB_NAME = name,
           EB_URI = uri
     where EB_WEBLOG_ID = weblog_id
       and EB_BLOGID = blogId;
  } else {
    insert into ENEWS.WA.BLOG(EB_WEBLOG_ID, EB_BLOGID, EB_NAME, EB_URI)
      values(weblog_id, blogId, name, uri);
  }
}
;

-------------------------------------------------------------------------------
--
create procedure ENEWS.WA.blog_delete(
  in blog_id integer)
{
  delete from ENEWS.WA.BLOG where EB_ID = blog_id;
}
;

-------------------------------------------------------------------------------
--
create procedure ENEWS.WA.blog_post_new(
  in blog_id integer,
  in title varchar,
  in content varchar)
{
  declare v_api, v_uri, v_port, v_endpoint, v_user, v_password, v_blogId varchar;
  declare post_id any;

  declare req BLOG..blogRequest;
  declare post BLOG..MWeblogPost;

	select EW_API,
         EW_URI,
         EW_PORT,
         EW_ENDPOINT,
         EW_USER,
         EW_PASSWORD,
         EB_BLOGID
	  into v_api,
         v_uri,
         v_port,
         v_endpoint,
         v_user,
         v_password,
         v_blogId
    from ENEWS.WA.BLOG,
         ENEWS.WA.WEBLOG
	 where EB_ID = blog_id
	   and EB_WEBLOG_ID = EW_ID;

  -- post
  post := new BLOG..MWeblogPost ();
  post.description := content;
  post.userid := v_user;
  post.title := serialize_to_UTF8_xml (title);
  post.dateCreated := ENEWS.WA.dt_current_time();

  -- request
  req := new BLOG..blogRequest ();
  req.appkey := 'appKey';
  req.blogid := v_blogId;
  req.user_name := v_user;
  req.passwd  := v_password;
  req.struct := post;

  if (v_api = 'Blogger') {
    post_id := BLOG.blogger.new_Post (ENEWS.WA.weblog_uri(v_uri, v_port, v_endpoint), req, content);
  } else if (v_api = 'MetaWeblog') {
    post_id := BLOG.metaweblog.new_Post (ENEWS.WA.weblog_uri(v_uri, v_port, v_endpoint), req);
  } else if (v_api = 'MovableType') {
    post_id := BLOG.metaweblog.new_Post (ENEWS.WA.weblog_uri(v_uri, v_port, v_endpoint), req);
  }
  post.postid := post_id;
  ENEWS.WA.process_metaweblog_post(post, blog_id);

  return post_id;
}
;

-------------------------------------------------------------------------------
--
create procedure ENEWS.WA.blogs_queue_add (
  in domain_id integer)
{
  for (select EB_ID id
         from ENEWS.WA.BLOG,
              ENEWS.WA.WEBLOG
        where EB_WEBLOG_ID = EW_ID
          and coalesce(EB_QUEUE_FLAG, 0) = 0
          and (EB_LAST_UPDATE is null or dateadd('minute', 1, EB_LAST_UPDATE) < now())
          and EW_DOMAIN_ID = domain_id)
  do {
    update ENEWS.WA.BLOG
       set EB_QUEUE_FLAG = 1
     where EB_ID = id;
   	commit work;
  }
}
;

-------------------------------------------------------------------------------
--
create procedure ENEWS.WA.blogs_queue_agregator ()
{
  declare id, days, err int;
  declare bm any;

  declare cr static cursor for select EB_ID,
                                      EB_STORE_DAYS
                                 from ENEWS.WA.BLOG
                                where coalesce(EB_QUEUE_FLAG, 0) = 1;

  err := 0;
  whenever not found goto enf;
  open cr (exclusive, prefetch 1);
  fetch cr first into id, days;
  while (1) {
    bm := bookmark(cr);
    err := 0;
    close cr;
    {
      declare exit handler for sqlstate '*'
      {
        rollback work;
        if (__SQL_STATE <> '40001') {
          update ENEWS.WA.BLOG
             set EB_ERROR_LOG = __SQL_STATE || ' ' || __SQL_MESSAGE,
                 EB_QUEUE_FLAG = 0
           where EB_ID = id;
          commit work;
        } else {
          resignal;
        }
        err := 1;
        goto next;
      };
      ENEWS.WA.blog_refresh_int(id, days);
    }
    update ENEWS.WA.BLOG
       set EB_LAST_UPDATE = now(),
           EB_ERROR_LOG = null,
           EB_QUEUE_FLAG = 0
     where EB_ID = id;
    commit work;

  next:
    open cr (exclusive, prefetch 1);
    fetch cr bookmark bm into id, days;
    if (err)
      fetch cr next into id, days;
  }
enf:
  close cr;
  return;
}
;

-------------------------------------------------------------------------------
--
create procedure ENEWS.WA.blogs_agregator ()
{
  declare id, days, rc, err integer;
  declare bm any;
  declare dt datetime;

  dt := now();
  declare cr static cursor for select EB_ID,
                                      EB_STORE_DAYS
                                 from ENEWS.WA.BLOG
                                where (EB_LAST_UPDATE is null or dateadd('minute', EB_UPDATE, EB_LAST_UPDATE) < dt)
                                  and EB_ERROR_LOG is null;

  bm := null;
  err := 0;
  whenever not found goto enf;
  open cr (exclusive, prefetch 1);
  fetch cr first into id, days;
  while (1) {
    bm := bookmark(cr);
    err := 0;
    close cr;
    {
      declare exit handler for sqlstate '*'
      {
        rollback work;
        if (__SQL_STATE <> '40001') {
          update ENEWS.WA.BLOG
             set EB_ERROR_LOG = __SQL_STATE || ' ' || __SQL_MESSAGE
           where EB_ID = id;
          commit work;
        } else {
          resignal;
        }
        err := 1;
        goto next;
      };
      rc := ENEWS.WA.blog_refresh_int(id, days);
    }
    update ENEWS.WA.BLOG
       set EB_LAST_UPDATE = now(),
           EB_ERROR_LOG = null,
           EB_QUEUE_FLAG = 0
     where EB_ID = id;
    commit work;

  next:
    open cr (exclusive, prefetch 1);
    fetch cr bookmark bm into id, days;
    if (err)
      fetch cr next into id, days;
  }
enf:
  close cr;
  return;
}
;

-------------------------------------------------------------------------------
--
create procedure ENEWS.WA.blog_refresh_int(
  in blog_id integer,
  in days integer)
{
  delete
    from ENEWS.WA.BLOG_POST
   where EBP_BLOG_ID = blog_id
     and ((EBP_LAST_UPDATE is not null) and dateadd('day', days, EBP_LAST_UPDATE) < now());
  commit work;

  return ENEWS.WA.blog_refresh(blog_id);
}
;

-------------------------------------------------------------------------------
--
create procedure ENEWS.WA.blog_refresh(
  in blog_id integer)
{
  declare exit handler for sqlstate '*' { return __SQL_STATE; };

  declare N, v_limit integer;
  declare v_api, v_uri, v_port, v_endpoint, v_user, v_password, v_blogid varchar;
  declare posts any;
  declare req BLOG..blogRequest;
  declare mPost BLOG..MWeblogPost;;

	select EW_API,
         EW_URI,
         EW_PORT,
         EW_ENDPOINT,
         EW_USER,
         EW_PASSWORD,
         EB_BLOGID,
         EB_LIMIT
	  into v_api,
         v_uri,
         v_port,
         v_endpoint,
         v_user,
         v_password,
         v_blogid,
         v_limit
    from ENEWS.WA.BLOG,
         ENEWS.WA.WEBLOG
	 where EB_WEBLOG_ID = EW_ID
	   and EB_ID = blog_id;

  -- request
  req := new BLOG..blogRequest();
  req.appkey := 'appKey';
  req.blogid := v_blogid;
  req.user_name := v_user;
  req.passwd  := v_password;

  posts := BLOG.blogger.get_Recent_Posts(ENEWS.WA.weblog_uri(v_uri, v_port, v_endpoint), req, v_limit);

  for (N := 0; N < length(posts); N :=  N + 1) {
    if (v_api = 'Blogger') {
      ENEWS.WA.process_blogger_post(posts[N], blog_id);
    } else if (v_api = 'MetaWeblog') {
      req := new BLOG..blogRequest();
      req.appkey := 'appKey';
      req.postid := (posts[N] as BLOG..blogPost).postid;
      req.user_name := v_user;
      req.passwd  := v_password;

      mPost := BLOG.metaweblog.get_Post (ENEWS.WA.weblog_uri(v_uri, v_port, v_endpoint), req);
      ENEWS.WA.process_metaweblog_post(mPost, blog_id);
    } else if (v_api = 'MovableType') {
      req := new BLOG..blogRequest();
      req.appkey := 'appKey';
      req.postid := (posts[N] as BLOG..blogPost).postid;
      req.user_name := v_user;
      req.passwd  := v_password;

      mPost := BLOG.metaweblog.get_Post (ENEWS.WA.weblog_uri(v_uri, v_port, v_endpoint), req);
      ENEWS.WA.process_metaweblog_post(mPost, blog_id);
    }
  }
  return '';
}
;

-------------------------------------------------------------------------------
--
create procedure ENEWS.WA.process_blogger_post(
  inout post BLOG..blogPost,
  inout blog_id integer)
{
  declare post_id integer;
  post_id := (select EBP_ID from ENEWS.WA.BLOG_POST where EBP_BLOG_ID = blog_id and EBP_POSTID = post.postid);

  if (isnull(post_id)) {
    declare mPost BLOG..MWeblogPost;

    mPost := BLOG..MWeblogPost();
    mPost.postid := post.postid;
    mPost.userid := post.userid;
    mPost.description := post.content;
    mPost.dateCreated := post.dateCreated;
    insert into ENEWS.WA.BLOG_POST(EBP_BLOG_ID, EBP_POSTID, EBP_META, EBP_LAST_UPDATE)
      values(blog_id, mPost.postid, mPost, now());
  }
}
;

-------------------------------------------------------------------------------
--
create procedure ENEWS.WA.process_metaweblog_post(
  inout post BLOG..MWeblogPost,
  inout blog_id integer)
{
  declare post_id integer;
  post_id := (select EBP_ID from ENEWS.WA.BLOG_POST where EBP_BLOG_ID = blog_id and EBP_POSTID = post.postid);

  if (isnull(post_id)) {
    insert into ENEWS.WA.BLOG_POST(EBP_BLOG_ID, EBP_POSTID, EBP_META, EBP_LAST_UPDATE)
      values(blog_id, post.postid, post, now());
  }
}
;

-------------------------------------------------------------------------------
--
create procedure ENEWS.WA.blog_change_flag (
  inout post_id integer,
  inout domain_id integer,
  in flag varchar)
{
  declare fType, fValue any;

  fType := left(flag,1);
  fValue := atoi(right(flag,1));

  if (exists(select 1 from ENEWS.WA.BLOG_POST_DATA where EBPD_POST_ID = post_id and EBPD_DOMAIN_ID = domain_id)) {
    if (fType = 'r')
      update ENEWS.WA.BLOG_POST_DATA
         set EBPD_READ_FLAG = fValue
       where EBPD_POST_ID = post_id
         and EBPD_DOMAIN_ID = domain_id;
    if (fType = 'f')
      update ENEWS.WA.BLOG_POST_DATA
         set EBPD_KEEP_FLAG = fValue
       where EBPD_POST_ID = post_id
         and EBPD_DOMAIN_ID = domain_id;
  } else {
    if (fType = 'r')
      insert replacing ENEWS.WA.BLOG_POST_DATA(EBPD_POST_ID, EBPD_DOMAIN_ID, EBPD_READ_FLAG)
        values(post_id, domain_id, fValue);
    if (fType = 'f')
      insert replacing ENEWS.WA.BLOG_POST_DATA(EBPD_POST_ID, EBPD_DOMAIN_ID, EBPD_KEEP_FLAG)
        values(post_id, domain_id, fValue);
  }
}
;

-------------------------------------------------------------------------------
--
-- Smart folders
--
-------------------------------------------------------------------------------
create procedure ENEWS.WA.sfolder_sql(
  inout domain_id integer,
  inout account_id integer,
  inout data varchar,
  in mode varchar := 'text',
  in maxRows varchar := '')
{
  declare S, tmp, where2, delimiter2 varchar;

  where2 := ' \n ';
  delimiter2 := '\n and ';

  if (is_empty_or_null(ENEWS.WA.xml_get('tags', data))) {
    S :=
      'select \n' ||
      '  distinct <MAX> \n' ||
      '  fi.EFI_ID, \n' ||
      '  ENEWS.WA.show_title(fi.EFI_TITLE) EFI_TITLE, \n' ||
      '  ENEWS.WA.show_author(fi.EFI_AUTHOR) EFI_AUTHOR, \n' ||
      '  fi.EFI_PUBLISH_DATE, \n' ||
      '  fi.EFI_LINK, \n' ||
      '  fi.EFI_FEED_ID, \n' ||
      '  f.EF_ID, \n' ||
      '  f.EF_URI, \n' ||
      '  fd.EFD_TITLE, \n' ||
      '  fida.EFID_READ_FLAG, \n' ||
      '  fida.EFID_KEEP_FLAG  \n' ||
      'from ENEWS.WA.FEED_DOMAIN fd \n' ||
      '       join ENEWS.WA.FEED f on f.EF_ID = fd.EFD_FEED_ID \n' ||
      '         join ENEWS.WA.FEED_ITEM fi on fi.EFI_FEED_ID = fd.EFD_FEED_ID <ITEM_DESCRIPTION> \n' ||
      '           left join ENEWS.WA.FEED_ITEM_DATA fida on fida.EFID_ITEM_ID = fi.EFI_ID and fida.EFID_ACCOUNT_ID = <ACCOUNT_ID> \n' ||
      'where fd.EFD_DOMAIN_ID = <DOMAIN_ID> <WHERE> \n';
  } else {
    S :=
      'select \n' ||
      '  distinct <MAX> \n' ||
      '  fi.EFI_ID, \n' ||
      '  ENEWS.WA.show_title(fi.EFI_TITLE) EFI_TITLE, \n' ||
      '  ENEWS.WA.show_author(fi.EFI_AUTHOR) EFI_AUTHOR, \n' ||
      '  fi.EFI_PUBLISH_DATE, \n' ||
      '  fi.EFI_LINK, \n' ||
      '  fi.EFI_FEED_ID, \n' ||
      '  f.EF_ID, \n' ||
      '  f.EF_URI, \n' ||
      '  fd.EFD_TITLE, \n' ||
      '  fida.EFID_READ_FLAG, \n' ||
      '  fida.EFID_KEEP_FLAG \n' ||
      'from \n' ||
      '  (select \n' ||
      '    EFID_ITEM_ID \n' ||
      '  from \n' ||
      '    ENEWS.WA.FEED_ITEM_DATA \n' ||
      '  where contains(EFID_TAGS, \'[__lang "x-ViDoc"] <TAGS>\') \n' ||
      '  \n' ||
      '  EXCEPT \n' ||
      '  \n' ||
      '  select \n' ||
      '    EFID_ITEM_ID \n' ||
      '  from \n' ||
      '    ENEWS.WA.FEED_ITEM_DATA \n' ||
      '  where EFID_TAGS is not null \n' ||
      '    and (EFID_DOMAIN_ID = <DOMAIN_ID> or EFID_ACCOUNT_ID = <ACCOUNT_ID>) \n' ||
      '  \n' ||
      '  UNION \n' ||
      '  \n' ||
      '  select \n' ||
      '    EFID_ITEM_ID \n' ||
      '  from \n' ||
      '    ENEWS.WA.FEED_ITEM_DATA \n' ||
      '  where contains(EFID_TAGS, \'[__lang "x-ViDoc"] <DOMAIN_TAGS>\') \n' ||
      '  \n' ||
      '  EXCEPT \n' ||
      '  \n' ||
      '  select \n' ||
      '    EFID_ITEM_ID \n' ||
      '  from \n' ||
      '    ENEWS.WA.FEED_ITEM_DATA \n' ||
      '  where EFID_TAGS is not null \n' ||
      '    and EFID_ACCOUNT_ID = <ACCOUNT_ID> \n' ||
      '   \n' ||
      '  UNION \n' ||
      '   \n' ||
      '  select \n' ||
      '    EFID_ITEM_ID \n' ||
      '  from \n' ||
      '    ENEWS.WA.FEED_ITEM_DATA \n' ||
      '  where contains(EFID_TAGS, \'[__lang "x-ViDoc"] <ACCOUNT_TAGS>\')) x \n' ||
      '    join ENEWS.WA.FEED_ITEM fi on fi.EFI_ID = x.EFID_ITEM_ID <ITEM_DESCRIPTION> \n' ||
      '      left join ENEWS.WA.FEED_ITEM_DATA fida on fida.EFID_ITEM_ID = fi.EFI_ID and fida.EFID_ACCOUNT_ID = <ACCOUNT_ID> \n' ||
      '        join ENEWS.WA.FEED f on f.EF_ID = fi.EFI_FEED_ID \n' ||
      '          join ENEWS.WA.FEED_DOMAIN fd on fd.EFD_FEED_ID = f.EF_ID \n' ||
      'where fd.EFD_DOMAIN_ID = <DOMAIN_ID> <WHERE>\n';
  }

  tmp := ENEWS.WA.xml_get('keywords', data);
  if (not is_empty_or_null(tmp) and (mode = 'text')) {
    S := replace(S, '<ITEM_DESCRIPTION>', sprintf('and contains(fi.EFI_DESCRIPTION, \'[__lang "x-ViDoc"] %s\') \n', FTI_MAKE_SEARCH_STRING(tmp)));
  } else {
    tmp := ENEWS.WA.xml_get('expression', data);
    if (not is_empty_or_null(tmp))
      if (mode = 'text') {
        S := replace(S, '<ITEM_DESCRIPTION>', sprintf('and contains(fi.EFI_DESCRIPTION, \'[__lang "x-ViDoc"] %s\') \n', tmp));
      } else if (mode = 'xpath') {
        S := replace(S, '<ITEM_DESCRIPTION>', sprintf('and xpath_eval (\'%s\', fi.EFI_DESCRIPTION, 1) \n', replace(tmp, '''', '\\''')));
      } else if (mode = 'xquery') {
        S := replace(S, '<ITEM_DESCRIPTION>', sprintf('and xquery_eval (\'%s\', fi.EFI_DESCRIPTION) \n', replace(tmp, '''', '\\''')));
      }
  }

  tmp := ENEWS.WA.xml_get('tags', data);
  if (not is_empty_or_null(tmp)) {
    tmp := ENEWS.WA.tags2search(tmp);
    S := replace(S, '<TAGS>', tmp);
    S := replace(S, '<DOMAIN_TAGS>', sprintf('%s and "^R%s"', tmp, cast(domain_id as varchar)));
    S := replace(S, '<ACCOUNT_TAGS>', sprintf('%s and "^UID%s"', tmp, cast(account_id as varchar)));
  }

  tmp := ENEWS.WA.xml_get('beforeDate', data);
  if (not is_empty_or_null(tmp))
    ENEWS.WA.sfolder_sql_where(where2, delimiter2, sprintf('fi.EFI_PUBLISH_DATE <= stringdate(\'%s\') \n', ENEWS.WA.dt_reformat(tmp, 'D.M.Y', 'Y-M-D')));

  tmp := ENEWS.WA.xml_get('afterDate', data);
  if (not is_empty_or_null(tmp))
    ENEWS.WA.sfolder_sql_where(where2, delimiter2, sprintf('fi.EFI_PUBLISH_DATE >= stringdate(\'%s\') \n', ENEWS.WA.dt_reformat(tmp, 'D.M.Y', 'Y-M-D')));

  tmp := ENEWS.WA.xml_get('read', data);
  if (tmp = 'r+')
    ENEWS.WA.sfolder_sql_where(where2, delimiter2, 'coalesce(fida.EFID_READ_FLAG, 0) = 1');
  if (tmp = 'r-')
    ENEWS.WA.sfolder_sql_where(where2, delimiter2, 'coalesce(fida.EFID_READ_FLAG, 0) = 0');

  tmp := ENEWS.WA.xml_get('flag', data);
  if (tmp = 'f+')
    ENEWS.WA.sfolder_sql_where(where2, delimiter2, 'coalesce(fida.EFID_KEEP_FLAG, 0) = 1');
  if (tmp = 'f-')
    ENEWS.WA.sfolder_sql_where(where2, delimiter2, 'coalesce(fida.EFID_KEEP_FLAG, 0) = 0');

  if (maxRows <> '')
    maxRows := 'TOP ' || maxRows;
  S := replace(S, '<MAX>', maxRows);
  S := replace(S, '<DOMAIN_ID>', cast(domain_id as varchar));
  S := replace(S, '<ACCOUNT_ID>', cast(account_id as varchar));
  S := replace(S, '<TAGS>', '');
  S := replace(S, '<DOMAIN_TAGS>', '');
  S := replace(S, '<ACCOUNT_TAGS>', '');
  S := replace(S, '<ITEM_DESCRIPTION>', '');
  S := replace(S, '<WHERE>', where2);
  --dbg_obj_print(S);
  return S;
}
;

-------------------------------------------------------------------------------
--
create procedure ENEWS.WA.sfolder_sql_where(
  inout where2 varchar,
  inout delimiter varchar,
  in criteria varchar)
{
  if (criteria <> '') {
    if (where2 = '')
      where2 := 'where ';
    where2 := concat(where2, delimiter, criteria);
    delimiter := '\n and ';
  }
}
;
-------------------------------------------------------------------------------
--
create procedure ENEWS.WA.sfolder_create(
  in domain_id integer,
  in name varchar,
  in data varchar,
  in test integer := 0)
{
  declare id varchar;

  if (test) {
    id := coalesce((select ESFO_ID from ENEWS.WA.SFOLDER where ESFO_DOMAIN_ID = domain_id and ESFO_NAME = name), '');
    if (id <> '')
      return id;
  }
  id := cast(sequence_next ('sfolder') as varchar);
  insert into ENEWS.WA.SFOLDER(ESFO_ID, ESFO_DOMAIN_ID, ESFO_NAME, ESFO_DATA)
    values(id, domain_id, name, data);
  return id;
}
;

-------------------------------------------------------------------------------
--
create procedure ENEWS.WA.sfolder_update(
  in domain_id integer,
  in id varchar,
  in name varchar,
  in data varchar)
{
  update ENEWS.WA.SFOLDER
     set ESFO_NAME = name,
         ESFO_DATA = data
   where ESFO_ID = id
     and ESFO_DOMAIN_ID = domain_id;
}
;

-------------------------------------------------------------------------------
--
create procedure ENEWS.WA.sfolder_delete(
  in domain_id integer,
  in folder_id integer)
{
  delete from ENEWS.WA.SFOLDER where ESFO_DOMAIN_ID = domain_id and ESFO_ID = folder_id;
}
;

-------------------------------------------------------------------------------
--
create procedure ENEWS.WA.tag_prepare(
  in tag varchar)
{
  if (not is_empty_or_null(tag)) {
    tag := trim(tag);
    tag := trim(tag, '\n');
    tag := trim(tag, '\r');
    tag := replace(tag, '  ', ' ');
  }
  return tag;
}
;

-------------------------------------------------------------------------------
--
create procedure ENEWS.WA.tag_delete(
  inout tags varchar,
  inout T integer)
{
  declare N, L integer;
  declare tags2 any;

  tags := '';
  tags2 := ENEWS.WA.tags2vector(tags);
  L := length(tags2);
  for (N := 0; N < L; N := N + 1)
    if (N <> T)
      tags := concat(tags, ',', tags2[N]);
  return trim(tags, ',');
}
;

---------------------------------------------------------------------------------
--
create procedure ENEWS.WA.tags_join(
  inout tags varchar,
  inout tags2 varchar)
{
  declare resultTags any;

  if (is_empty_or_null(tags))
    tags := '';
  if (is_empty_or_null(tags2))
    tags2 := '';

  resultTags := concat(tags, ',', tags2);
  resultTags := ENEWS.WA.tags2vector(resultTags);
  resultTags := ENEWS.WA.tags2unique(resultTags);
  resultTags := ENEWS.WA.vector2tags(resultTags);
  return resultTags;
}
;

---------------------------------------------------------------------------------
--
create procedure ENEWS.WA.tags2vector(
  inout tags varchar)
{
  return split_and_decode(trim(tags, ','), 0, '\0\0,');
}
;

---------------------------------------------------------------------------------
--
create procedure ENEWS.WA.tags2search(
  in tags varchar)
{
  declare S varchar;
  declare V any;

  S := '';
  V := ENEWS.WA.tags2vector(tags);
  foreach (any tag in V) do
    S := concat(S, ' ', replace (replace (trim(lcase(tag)), ' ', '_'), '+', '_'));
  return FTI_MAKE_SEARCH_STRING(trim(S, ','));
}
;

-------------------------------------------------------------------------------
--
create procedure ENEWS.WA.vector2tags(
  inout aVector any)
{
  declare N, L integer;
  declare aResult any;

  aResult := '';
  L := length(aVector);
  for (N := 0; N < L; N := N + 1)
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
create procedure ENEWS.WA.tags2unique(
  inout aVector any)
{
  declare aResult any;
  declare N, L, M integer;

  aResult := vector();
  L := length(aVector);
  for (N := 0; N < L; N := N + 1) {
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
create procedure ENEWS.WA.tags_agregator ()
{
  for (select WAI_ID, WAM_USER from DB.DBA.WA_MEMBER, DB.DBA.WA_INSTANCE where WAI_NAME = WAM_INST and WAI_TYPE_NAME = 'eNews2') do
    ENEWS.WA.tags_refresh(WAI_ID, WAM_USER, 0);
}
;

-------------------------------------------------------------------------------
--
create procedure ENEWS.WA.tags_refresh (
  in domain_id integer,
  in account_id integer,
  in mode integer := 1)
{
  declare ts_count, ts_max, N integer;
  declare ts_last_update datetime;
  declare tags, tags_dict, tags_vector, tag_object any;

  declare exit handler for not found { goto _skip; };

  ts_last_update := null;
  ts_max := 1;
  if (mode)
    select ETS_LAST_UPDATE, ETS_COUNT into ts_last_update, ts_max from ENEWS.WA.TAGS where ETS_DOMAIN_ID = domain_id and ETS_ACCOUNT_ID = account_id and ETS_TAG = '';

_skip:
  tags_dict := dict_new();
  for (select
         x.EFID_TAGS
       from
         (select
            EFID_ITEM_ID,
            EFID_TAGS
          from
            ENEWS.WA.FEED_ITEM_DATA
              join ENEWS.WA.FEED_ITEM fi on fi.EFI_ID = EFID_ITEM_ID
                join ENEWS.WA.FEED_DOMAIN fd on fd.EFD_FEED_ID = fi.EFI_FEED_ID and fd.EFD_DOMAIN_ID = domain_id
          where EFID_TAGS is not null
            and (ts_last_update is null or EFID_LAST_UPDATE > ts_last_update)

          EXCEPT

          select
            EFID_ITEM_ID,
            EFID_TAGS
          from
            ENEWS.WA.FEED_ITEM_DATA
              join ENEWS.WA.FEED_ITEM fi on fi.EFI_ID = EFID_ITEM_ID
                join ENEWS.WA.FEED_DOMAIN fd on fd.EFD_FEED_ID = fi.EFI_FEED_ID and fd.EFD_DOMAIN_ID = domain_id
          where EFID_TAGS is not null
            and (EFID_DOMAIN_ID = domain_id or EFID_ACCOUNT_ID = account_id)
            and (ts_last_update is null or EFID_LAST_UPDATE > ts_last_update)

          UNION

          select
            EFID_ITEM_ID,
            EFID_TAGS
          from
            ENEWS.WA.FEED_ITEM_DATA
              join ENEWS.WA.FEED_ITEM fi on fi.EFI_ID = EFID_ITEM_ID
                join ENEWS.WA.FEED_DOMAIN fd on fd.EFD_FEED_ID = fi.EFI_FEED_ID and fd.EFD_DOMAIN_ID = domain_id
          where EFID_TAGS is not null
            and EFID_DOMAIN_ID = domain_id
            and (ts_last_update is null or EFID_LAST_UPDATE > ts_last_update)

          EXCEPT

          select
            EFID_ITEM_ID,
            EFID_TAGS
          from
            ENEWS.WA.FEED_ITEM_DATA
              join ENEWS.WA.FEED_ITEM fi on fi.EFI_ID = EFID_ITEM_ID
                join ENEWS.WA.FEED_DOMAIN fd on fd.EFD_FEED_ID = fi.EFI_FEED_ID and fd.EFD_DOMAIN_ID = domain_id
          where EFID_TAGS is not null
            and EFID_ACCOUNT_ID = account_id
            and (ts_last_update is null or EFID_LAST_UPDATE > ts_last_update)

          UNION

          select
            EFID_ITEM_ID,
            EFID_TAGS
          from
            ENEWS.WA.FEED_ITEM_DATA
              join ENEWS.WA.FEED_ITEM fi on fi.EFI_ID = EFID_ITEM_ID
                join ENEWS.WA.FEED_DOMAIN fd on fd.EFD_FEED_ID = fi.EFI_FEED_ID and fd.EFD_DOMAIN_ID = domain_id
          where EFID_TAGS is not null
            and EFID_ACCOUNT_ID = account_id
            and (ts_last_update is null or EFID_LAST_UPDATE > ts_last_update)) x) do
  {
    tags := split_and_decode (EFID_TAGS, 0, '\0\0,');
    foreach (any tag in tags) do {
      tag_object := dict_get(tags_dict, lcase(tag), vector(lcase(tag), 0));
      tag_object[1] := tag_object[1] + 1;
      dict_put(tags_dict, lcase(tag), tag_object);
    }
  }

  ts_last_update := now();
  tags_vector := dict_to_vector(tags_dict, 1);
  if (mode) {
    for (N := 1; N < length(tags_vector); N := N + 2) {
      ts_count := coalesce((select ETS_COUNT from ENEWS.WA.TAGS where ETS_DOMAIN_ID = domain_id and ETS_ACCOUNT_ID = account_id and ETS_TAG = tags_vector[N][0]), 0);
      insert replacing ENEWS.WA.TAGS(ETS_DOMAIN_ID, ETS_ACCOUNT_ID, ETS_LAST_UPDATE, ETS_TAG, ETS_COUNT)
        values(domain_id, account_id, ts_last_update, tags_vector[N][0], tags_vector[N][1]+ts_count);
      if (ts_max < tags_vector[N][1]+ts_count)
        ts_max := tags_vector[N][1] + ts_count;
    }
  } else {
    delete from ENEWS.WA.TAGS where ETS_DOMAIN_ID = domain_id and ETS_ACCOUNT_ID = account_id;
    for (N := 1; N < length(tags_vector); N := N + 2) {
      insert into ENEWS.WA.TAGS(ETS_DOMAIN_ID, ETS_ACCOUNT_ID, ETS_LAST_UPDATE, ETS_TAG, ETS_COUNT)
        values(domain_id, account_id, ts_last_update, tags_vector[N][0], tags_vector[N][1]);
      if (ts_max < tags_vector[N][1])
        ts_max := tags_vector[N][1];
    }
  }
  insert replacing ENEWS.WA.TAGS(ETS_DOMAIN_ID, ETS_ACCOUNT_ID, ETS_LAST_UPDATE, ETS_TAG, ETS_COUNT)
    values(domain_id, account_id, ts_last_update, '', ts_max);

  commit work;
}
;

---------------------------------------------------------------------------------
--
create procedure ENEWS.WA.tags_item_rules(
  inout item_id integer,
  inout account_id integer)
{
  declare exit handler for SQLSTATE '*' { goto _end;};

  declare N, L integer;
  declare content, rules, vectorTags, tags any;

  content := (select ENEWS.WA.xml2string(EFI_DESCRIPTION) from ENEWS.WA.FEED_ITEM where EFI_ID = item_id);
	rules := user_tag_rules (account_id);
	vectorTags := tag_document (content, 0, rules);
  tags := '';
  L := length(vectorTags);
  for (N := 0; N < L; N := N + 2)
    tags := concat (tags, ',', vectorTags[N]);
  tags := trim(tags, ',');

_end:
  return tags;
}
;

---------------------------------------------------------------------------------
----
create procedure ENEWS.WA.tags_item_content(
  inout item_id integer)
{
  declare exit handler for SQLSTATE '*' { goto _end;};

  declare content, links, tags any;

  tags := '';
  content := (select EFI_DESCRIPTION from ENEWS.WA.FEED_ITEM where EFI_ID = item_id);
  content := xml_tree_doc(content);
  links := xpath_eval ('//a[@rel="tag"]', content, 0);
  if (length(links)) {
    foreach (any link in links) do
      tags := ENEWS.WA.tags_join(tags, ENEWS.WA.tag_prepare(cast(link as varchar)));
  } else {
    content := (select EFI_DATA from ENEWS.WA.FEED_ITEM where EFI_ID = item_id);
    content := xml_tree_doc(content);
    tags := cast (xpath_eval ('[ xmlns:dc="http://purl.org/dc/elements/1.1/" ] //dc:subject', content, 1) as varchar);
    tags := replace(tags, ' ', ',');
    tags := replace(tags, ',,',',');
    tags := trim(tags, ',');
    if (is_empty_or_null(tags)) {
      links := xpath_eval ('//category', content, 0);
      foreach (any link in links) do
        tags := ENEWS.WA.tags_join(tags, ENEWS.WA.tag_prepare (cast (xpath_eval ('./@term', link, 1) as varchar)));
    } else {
      declare N, L integer;
      declare V any;

      tags := '';
      V := ENEWS.WA.tags2vector(tags);
      L := length(V);
      for (N := 0; N < L; N := N + 1)
        if (ENEWS.WA.validate_tag(V[N]))
          tags := ENEWS.WA.tags_join(tags, ENEWS.WA.tag_prepare (V[N]));
    }
  }

_end:
  return tags;
}
;

---------------------------------------------------------------------------------
----
create procedure ENEWS.WA.tags_item_domain(
  inout item_id integer,
  inout domain_id integer)
{
  declare exit handler for SQLSTATE '*' { goto _end;};

  declare tags any;

  tags := (select EFD_TAGS from ENEWS.WA.FEED_DOMAIN, ENEWS.WA.FEED_ITEM where EFD_DOMAIN_ID = domain_id and EFD_FEED_ID = EFI_FEED_ID and EFI_ID = item_id);

_end:
  return tags;
}
;

---------------------------------------------------------------------------------
----
create procedure ENEWS.WA.tags_item (
  inout item_id integer)
{
  declare exit handler for SQLSTATE '*' { return;};

  declare tags any;

  tags := ENEWS.WA.tags_item_content(item_id);

  if (exists(select 1 from ENEWS.WA.FEED_ITEM_DATA where EFID_ITEM_ID = item_id and EFID_DOMAIN_ID is null and EFID_ACCOUNT_ID is null)) {
    if (is_empty_or_null(tags)) {
      delete from ENEWS.WA.FEED_ITEM_DATA
       where EFID_ITEM_ID = item_id;
    } else {
      update ENEWS.WA.FEED_ITEM_DATA
         set EFID_TAGS = tags,
             EFID_LAST_UPDATE = now()
       where EFID_ITEM_ID = item_id;
    }
  } else {
    if (not is_empty_or_null(tags)) {
      insert into ENEWS.WA.FEED_ITEM_DATA(EFID_ITEM_ID, EFID_TAGS, EFID_LAST_UPDATE)
        values(item_id, tags, now());
    }
  }
}
;

---------------------------------------------------------------------------------
----
create procedure ENEWS.WA.tags_domain_item (
  inout domain_id integer,
  inout item_id integer,
  inout tags varchar,
  in tags2 varchar := null)
{
  declare owner_id integer;
  declare publicTags varchar;

  if (isnull(tags2))
    tags2 := (select EFID_TAGS from ENEWS.WA.FEED_ITEM_DATA where EFID_ITEM_ID = item_id and EFID_DOMAIN_ID is null and EFID_ACCOUNT_ID is null);
  tags := ENEWS.WA.tags_join(tags2, tags);
  if (exists(select 1 from ENEWS.WA.FEED_ITEM_DATA where EFID_ITEM_ID = item_id and EFID_DOMAIN_ID = domain_id)) {
    if (is_empty_or_null(tags) or (tags = tags2)) {
      delete from ENEWS.WA.FEED_ITEM_DATA
       where EFID_ITEM_ID = item_id
         and EFID_DOMAIN_ID = domain_id;
    } else {
      update ENEWS.WA.FEED_ITEM_DATA
         set EFID_TAGS = tags,
             EFID_LAST_UPDATE = now()
       where EFID_ITEM_ID = item_id
         and EFID_DOMAIN_ID = domain_id;
    }
  } else {
    if (not is_empty_or_null(tags) and (tags <> tags2)) {
      insert into ENEWS.WA.FEED_ITEM_DATA(EFID_ITEM_ID, EFID_DOMAIN_ID, EFID_TAGS, EFID_LAST_UPDATE)
        values(item_id, domain_id, tags, now());
    }
  }

  publicTags := tags;
  owner_id := ENEWS.WA.domain_owner_id(domain_id);
  tags2 := ENEWS.WA.tags_item_rules(item_id, owner_id);
  tags := ENEWS.WA.tags_join(tags, tags2);
  tags2 := (select EFID_TAGS from ENEWS.WA.FEED_ITEM_DATA where EFID_ITEM_ID = item_id and EFID_DOMAIN_ID is null and EFID_ACCOUNT_ID = owner_id);
  tags := ENEWS.WA.tags_join(tags, tags2);
  if (not is_empty_or_null(tags) and (publicTags <> tags))
    ENEWS.WA.tags_account_item(owner_id, item_id, tags);
}
;

---------------------------------------------------------------------------------
----
create procedure ENEWS.WA.tags_account_item(
  inout account_id integer,
  inout item_id integer,
  inout tags varchar)
{
  if (exists(select 1 from ENEWS.WA.FEED_ITEM_DATA where EFID_ITEM_ID = item_id and EFID_ACCOUNT_ID = account_id)) {
    update ENEWS.WA.FEED_ITEM_DATA
       set EFID_TAGS = tags,
           EFID_LAST_UPDATE = now()
     where EFID_ITEM_ID = item_id
       and EFID_ACCOUNT_ID = account_id;
  } else {
    insert replacing ENEWS.WA.FEED_ITEM_DATA(EFID_ITEM_ID, EFID_ACCOUNT_ID, EFID_TAGS, EFID_LAST_UPDATE)
      values(item_id, account_id, tags, now());
  }
}
;

---------------------------------------------------------------------------------
----
create procedure ENEWS.WA.tags_account_item_select(
  in domain_id integer,
  in account_id integer,
  in item_id integer)
{
  declare tags varchar;

  tags := (select EFID_TAGS from ENEWS.WA.FEED_ITEM_DATA where EFID_ITEM_ID = item_id and EFID_ACCOUNT_ID = account_id);
  if (isnull(tags))
    tags := (select EFID_TAGS from ENEWS.WA.FEED_ITEM_DATA where EFID_ITEM_ID = item_id and EFID_DOMAIN_ID = domain_id);
  if (isnull(tags))
    tags := (select EFID_TAGS from ENEWS.WA.FEED_ITEM_DATA where EFID_ITEM_ID = item_id and EFID_DOMAIN_ID is null and EFID_ACCOUNT_ID is null);
  return tags;
}
;


---------------------------------------------------------------------------------
--
create procedure ENEWS.WA.feed_enclosure(
  inout item_id integer)
{
  declare exit handler for SQLSTATE '*' { goto _end;};

  declare content, enclosureResult, enclosureUrl, enclosureLength, enclosureType any;

  enclosureResult := null;
  content := (select EFI_DATA from ENEWS.WA.FEED_ITEM where EFI_ID = item_id);
  content := xml_tree_doc(content);
  enclosureUrl := cast (xpath_eval ('//enclosure/@url', content, 1) as varchar);
  if (not is_empty_or_null(enclosureUrl)) {
    enclosureLength := cast (xpath_eval ('//enclosure/@length', content, 1) as varchar);
    enclosureType := cast (xpath_eval ('//enclosure/@type', content, 1) as varchar);
    enclosureResult := vector(enclosureUrl, enclosureLength, enclosureType);
  }

_end:
  return enclosureResult;
}
;

---------------------------------------------------------------------------------
----
create procedure ENEWS.WA.blog_enclosure(
  inout item_id integer)
{
  declare exit handler for SQLSTATE '*' { goto _end;};

  declare enclosureResult any;
  declare content BLOG..MWeblogPost;

  enclosureResult := null;
  content := (select EBP_META from ENEWS.WA.BLOG_POST where EBP_BLOG_ID  = item_id);
  if ((not isnull(content)) and (not isnull(content.enclosure)))
    enclosureResult := vector(content.enclosure.url, content.enclosure."length", content.enclosure."type");

_end:
  return enclosureResult;
}
;

-------------------------------------------------------------------------------
--
create procedure ENEWS.WA.feed_change_flag (
  inout item_id integer,
  inout account_id integer,
  in flag varchar)
{
  declare fType, fValue any;

  fType := left(flag,1);
  fValue := atoi(right(flag,1));

  if (exists(select 1 from ENEWS.WA.FEED_ITEM_DATA where EFID_ITEM_ID = item_id and EFID_ACCOUNT_ID = account_id)) {
    if (fType = 'r')
      update ENEWS.WA.FEED_ITEM_DATA
         set EFID_READ_FLAG = fValue
       where EFID_ITEM_ID = item_id
         and EFID_ACCOUNT_ID = account_id;
    if (fType = 'f')
      update ENEWS.WA.FEED_ITEM_DATA
         set EFID_KEEP_FLAG = fValue
       where EFID_ITEM_ID = item_id
         and EFID_ACCOUNT_ID = account_id;
  } else {
    if (fType = 'r')
      insert replacing ENEWS.WA.FEED_ITEM_DATA(EFID_ITEM_ID, EFID_ACCOUNT_ID, EFID_READ_FLAG)
        values(item_id, account_id, fValue);
    if (fType = 'f')
      insert replacing ENEWS.WA.FEED_ITEM_DATA(EFID_ITEM_ID, EFID_ACCOUNT_ID, EFID_KEEP_FLAG)
        values(item_id, account_id, fValue);
  }
}
;

-------------------------------------------------------------------------------
--
create procedure ENEWS.WA.feed_description (
  inout item_id integer)
{
  return coalesce((select EFI_DESCRIPTION from ENEWS.WA.FEED_ITEM where EFI_ID = item_id), '');
}
;

-------------------------------------------------------------------------------
--
create procedure ENEWS.WA.feed_guid (
  inout item_id integer)
{
  return coalesce((select EFI_GUID from ENEWS.WA.FEED_ITEM where EFI_ID = item_id), '');
}
;

-------------------------------------------------------------------------------
--
create procedure ENEWS.WA.feed_excerpt (
  inout item_id integer,
  inout words any,
  inout words2 any)
{
  declare S, W any;

  S := ENEWS.WA.feed_description(item_id);
  if (is_empty_or_null(words)) {
    FTI_MAKE_SEARCH_STRING_INNER (words2, W);
  } else {
    FTI_MAKE_SEARCH_STRING_INNER (words, W);
  }
  return ENEWS.WA.show_excerpt(S, W);
}
;

-------------------------------------------------------------------------------
--
create procedure ENEWS.WA.settings (
  in domain_id integer,
  in account_id integer)
{
  return coalesce((select deserialize(blob_to_string(ES_DATA))
                     from ENEWS.WA.SETTINGS
                    where ES_DOMAIN_ID = domain_id
                      and ES_ACCOUNT_ID = account_id), vector());
}
;

-------------------------------------------------------------------------------
--
create procedure ENEWS.WA.settings_rows (
  inout domain_id integer,
  inout account_id integer)
{
  declare settings any;

  settings := ENEWS.WA.settings(domain_id, account_id);
  return cast(get_keyword('rows', settings, '10') as integer);
}
;

-------------------------------------------------------------------------------
--
create procedure ENEWS.WA.settings_icons (
  inout domain_id integer,
  inout account_id integer)
{
  declare settings any;

  settings := ENEWS.WA.settings(domain_id, account_id);
  return cast(get_keyword('feedIcons', settings, '1') as integer);
}
;

-------------------------------------------------------------------------------
--
create procedure ENEWS.WA.settings_atomVersion (
  inout domain_id integer,
  inout account_id integer)
{
  declare settings any;

  settings := ENEWS.WA.settings(domain_id, account_id);
  return get_keyword('atomVersion', settings, '1.0');
}
;

-----------------------------------------------------------------------------
--
create procedure ENEWS.WA.make_dasboard_item (
  inout dash any,
  in tim datetime,
  in title varchar,
  in uname varchar,
  in data any,
  in url varchar,
  in id int := -1,
  in action varchar := 'insert')
{
  if (not __proc_exists ('DB.DBA.WA_NEW_NEWS_IN'))
    return null;

  declare ret any;
  declare ses any;
  declare i, j, l int;

  ses := string_output ();
  http ('<feed-db>', ses);

  i := 0;
  if (action = 'insert') {
    ret := sprintf (
      '<post id="%d">'||
        '<title><![CDATA[%s]]></title>'||
        '<dt>%s</dt>'||
        '<link>%V</link>'||
        '<from><![CDATA[%s]]></from>'||
        '<email><![CDATA[%s]]></email>'||
      '</post>', id, ENEWS.WA.show_title(title), ENEWS.WA.dt_iso8601 (tim), url, ENEWS.WA.show_author(uname), coalesce(ENEWS.WA.process_authorEMail(data), ''));
    http (ret, ses);
    i := i + 1;
  }

  if (dash is not null) {
    declare xt, xp any;

    xt := xtree_doc (dash);
    xp := xpath_eval ('/feed-db/*', xt, 0);
    l := length (xp);
    for (j := 0; j < l; j := j + 1) {
	    declare pid any;
	    pid := xpath_eval ('number(@id)', xp[j]);
	    if (pid is null)
	      pid := -2;
      if (action = 'insert' or pid <> id) {
	      http (serialize_to_UTF8_xml (xp[j]), ses);
	      i := i + 1;
	      if (i = 10)
	        goto _end;
	    }
    }
  }
_end:;
  http ('</feed-db>', ses);
  return string_output_string (ses);
}
;

-----------------------------------------------------------------------------
--
create procedure ENEWS.WA.dashboard_get(
  in _domain_id integer,
  in _user_id   integer)
{
  declare ret any;

  ret := string_output ();
  for (select EF_DASHBOARD from ENEWS.WA.FEED, ENEWS.WA.FEED_DOMAIN where EFD_FEED_ID = EF_ID and EFD_DOMAIN_ID = _domain_id) do
    if (EF_DASHBOARD is not null)
      http (replace(blob_to_string (EF_DASHBOARD), '/enews2/news.vspx?link', sprintf('/enews2/%d/news.vspx?link', _domain_id)), ret);
  return string_output_string (ret);
}
;

-----------------------------------------------------------------------------
--
create procedure ENEWS.WA.dav_home(
  inout account_id integer) returns varchar
{
  declare name, home any;
  declare cid integer;

  name := coalesce((select U_NAME from DB.DBA.SYS_USERS where U_ID = account_id), -1);
  if (isinteger(name))
    return null;
  home := ENEWS.WA.dav_home_create(name);
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
create procedure ENEWS.WA.dav_home_create(
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
create procedure ENEWS.WA.host_url ()
{
  declare ret varchar;

  --return '';
  if (is_http_ctx ()) {
    ret := http_request_header (http_request_header ( ) , 'Host' , null , sys_connected_server_address ());
    if (isstring (ret) and strchr (ret , ':') is null) {
      declare hp varchar;
      declare hpa any;

      hp := sys_connected_server_address ();
      hpa := split_and_decode ( hp , 0 , '\0\0:');
      ret := ret || ':' || hpa [1];
    }
  } else {
    ret := sys_connected_server_address ();
    if (ret is null)
      ret := sys_stat ('st_host_name') || ':' || server_http_port ();
  }
  return 'http://' || ret ;
}
;

-------------------------------------------------------------------------------
--
create procedure ENEWS.WA.enews_url (
  in domain_id integer)
{
  return concat(ENEWS.WA.host_url(), '/enews2/', cast(domain_id as varchar), '/');
}
;

-------------------------------------------------------------------------------
--
create procedure ENEWS.WA.dav_url (
  in domain_id integer,
  in account_id integer)
{
  declare home varchar;

  if (account_id < 0)
    account_id := ENEWS.WA.domain_owner_id (domain_id);
  home := ENEWS.WA.dav_home(account_id);
  if (isnull(home))
    return '';
  return concat(ENEWS.WA.host_url(), home, ENEWS.WA.domain_gems_folder(), '/', ENEWS.WA.domain_gems_name(domain_id), '/');
}
;

-------------------------------------------------------------------------------
--
create procedure ENEWS.WA.dav_url2 (
  in domain_id integer,
  in account_id integer)
{
  declare home varchar;

  home := ENEWS.WA.dav_home(account_id);
  if (isnull(home))
    return '';
  return replace(concat(home, ENEWS.WA.domain_gems_folder(), '/', ENEWS.WA.domain_gems_name(domain_id), '/'), ' ', '%20');
}
;

-------------------------------------------------------------------------------
--
create procedure ENEWS.WA.geo_url (
  in domain_id integer,
  in account_id integer)
{
  for (select WAUI_LAT, WAUI_LNG from WA_USER_INFO where WAUI_U_ID = account_id) do
    if ((not isnull(WAUI_LNG)) and (not isnull(WAUI_LAT)))
      return sprintf('\n    <meta name="ICBM" content="%.2f, %.2f"><meta name="DC.title" content="%s">', WAUI_LNG, WAUI_LAT, ENEWS.WA.domain_name (domain_id));
  return '';
}
;

-------------------------------------------------------------------------------
--
create procedure ENEWS.WA.xslt_root()
{
  declare sHost varchar;

  sHost := cast(registry_get('_enews2_path_') as varchar);
  if (sHost = '0')
    return 'file://apps/eNews2/xslt/';
  if (isnull(strstr(sHost, '/DAV/VAD')))
    return sprintf('file://%sxslt/', sHost);
  return sprintf('virt://WS.WS.SYS_DAV_RES.RES_FULL_PATH.RES_CONTENT:%sxslt/', sHost);
}
;

-------------------------------------------------------------------------------
--
create procedure ENEWS.WA.xslt_full(
  in xslt_file varchar)
{
  return concat(ENEWS.WA.xslt_root(), xslt_file);
}
;

-------------------------------------------------------------------------------
--
create procedure ENEWS.WA.enclosure_render_sqlx (
  inout content any)
{
  declare exit handler for SQLSTATE '*' { goto _end;};

  declare enclosureResult, enclosureUrl, enclosureLength, enclosureType any;

  enclosureResult := '';
  content := xml_tree_doc(content);
  enclosureUrl := cast (xpath_eval ('//enclosure/@url', content, 1) as varchar);
  if (not is_empty_or_null(enclosureUrl)) {
    enclosureLength := cast (xpath_eval ('//enclosure/@length', content, 1) as varchar);
    enclosureType := cast (xpath_eval ('//enclosure/@type', content, 1) as varchar);
    enclosureResult := xmlelement ('enclosure', xmlattributes (enclosureUrl as url, enclosureLength as "length", enclosureType as "type"));
  }

_end:
  return enclosureResult;
}
;

-------------------------------------------------------------------------------
--
create procedure ENEWS.WA.export_rss_sqlx_int(
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
  http('  XMLELEMENT(\'title\', ENEWS.WA.utf2wide(ENEWS.WA.domain_name(<DOMAIN_ID>))), \n', retValue);
  http('  XMLELEMENT(\'description\', ENEWS.WA.utf2wide(ENEWS.WA.domain_description(<DOMAIN_ID>))), \n', retValue);
  http('  XMLELEMENT(\'managingEditor\', U_E_MAIL), \n', retValue);
  http('  XMLELEMENT(\'pubDate\', ENEWS.WA.dt_rfc1123(now())), \n', retValue);
  http('  XMLELEMENT(\'generator\', \'Virtuoso Universal Server \' || sys_stat(\'st_dbms_ver\')), \n', retValue);
  http('  XMLELEMENT(\'webMaster\', U_E_MAIL), \n', retValue);
  http('  XMLELEMENT(\'link\', ENEWS.WA.enews_url(<DOMAIN_ID>)) \n', retValue);
  http('from DB.DBA.SYS_USERS where U_ID = <USER_ID> \n', retValue);
  http(']]></sql:sqlx>\n', retValue);

  http('<sql:sqlx xmlns:sql=\'urn:schemas-openlink-com:xml-sql\'><![CDATA[\n', retValue);
  http('select \n', retValue);
  http('  XMLAGG(XMLELEMENT(\'item\', \n', retValue);
  http('    XMLELEMENT(\'title\', ENEWS.WA.utf2wide(EFI_TITLE)), \n', retValue);
  http('    XMLELEMENT(\'description\', ENEWS.WA.utf2wide(ENEWS.WA.xml2string(EFI_DESCRIPTION))), \n', retValue);
  http('    XMLELEMENT(\'guid\', EFI_GUID), \n', retValue);
  http('    XMLELEMENT(\'link\', EFI_LINK), \n', retValue);
  http('    XMLELEMENT(\'pubDate\', ENEWS.WA.dt_rfc1123 (EFI_PUBLISH_DATE)),\n', retValue);
  http('    XMLELEMENT(\'http://www.openlinksw.com/weblog/:modified\', ENEWS.WA.dt_iso8601 (EFI_PUBLISH_DATE)),\n', retValue);
  http('    ENEWS.WA.enclosure_render_sqlx (EFI_DATA)))\n', retValue);
  http('from (select top 15  \n', retValue);
  http('        EFI_TITLE, \n', retValue);
  http('        EFI_DESCRIPTION, \n', retValue);
  http('        EFI_PUBLISH_DATE, \n', retValue);
  http('        EFI_GUID, \n', retValue);
  http('        EFI_LINK, \n', retValue);
  http('        EFI_DATA \n', retValue);
  http('      from \n', retValue);
  http('        ENEWS.WA.FEED_ITEM, \n', retValue);
  http('        ENEWS.WA.FEED_DOMAIN \n', retValue);
  http('      where EFD_FEED_ID = EFI_FEED_ID  \n', retValue);
  http('        and EFD_DOMAIN_ID = <DOMAIN_ID> \n', retValue);
  http('      order by EFI_PUBLISH_DATE desc) x \n', retValue);
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
create procedure ENEWS.WA.export_rss_sqlx(
  in domain_id integer,
  in account_id integer)
{
  declare retValue any;

  retValue := ENEWS.WA.export_rss_sqlx_int(domain_id, account_id);
  return replace (retValue, 'sql:xsl=""', '');
}
;

-------------------------------------------------------------------------------
--
create procedure ENEWS.WA.export_atom_sqlx(
  in domain_id integer,
  in account_id integer)
{
  declare retValue, xsltTemplate any;

  xsltTemplate := ENEWS.WA.xslt_full ('rss2atom03.xsl');
  if (ENEWS.WA.settings_atomVersion (domain_id, account_id) = '1.0')
    xsltTemplate := ENEWS.WA.xslt_full ('rss2atom.xsl');

  retValue := ENEWS.WA.export_rss_sqlx_int(domain_id, account_id);
  return replace (retValue, 'sql:xsl=""', sprintf('sql:xsl="%s"', xsltTemplate));
}
;

-------------------------------------------------------------------------------
--
create procedure ENEWS.WA.export_rdf_sqlx(
  in domain_id integer,
  in account_id integer)
{
  declare retValue any;

  retValue := ENEWS.WA.export_rss_sqlx_int(domain_id, account_id);
  return replace (retValue, 'sql:xsl=""', sprintf('sql:xsl="%s"', ENEWS.WA.xslt_full ('rss2rdf.xsl')));
}
;

-------------------------------------------------------------------------------
--
create procedure ENEWS.WA.export_podcast_sqlx(
  in domain_id integer,
  in account_id integer)
{
  declare retValue any;

  retValue := string_output ();

  http ('<?xml version ="1.0" encoding="UTF-8"?>\n', retValue);
  http  ('<rss version="2.0" xmlns:wfw="http://wellformedweb.org/CommentAPI/" xmlns:slash="http://purl.org/rss/1.0/modules/slash/" xmlns:sql="urn:schemas-openlink-com:xml-sql">\n', retValue);
  http ('<channel>\n', retValue);

  http ('<sql:sqlx><![CDATA[\n', retValue);
  http ('select \n', retValue);
  http ('  XMLELEMENT (\'title\', ENEWS.WA.utf2wide(ENEWS.WA.domain_name(<DOMAIN_ID>))), \n', retValue);
  http ('  XMLELEMENT (\'description\', ENEWS.WA.utf2wide(ENEWS.WA.domain_description(<DOMAIN_ID>))), \n', retValue);
  http ('  XMLELEMENT (\'managingEditor\', U_E_MAIL), \n', retValue);
  http ('  XMLELEMENT (\'pubDate\', ENEWS.WA.dt_rfc1123(now())), \n', retValue);
  http ('  XMLELEMENT (\'generator\', \'Virtuoso Universal Server \' || sys_stat(\'st_dbms_ver\')), \n', retValue);
  http ('  XMLELEMENT (\'webMaster\', U_E_MAIL), \n', retValue);
  http ('  XMLELEMENT (\'link\', ENEWS.WA.enews_url(<DOMAIN_ID>)), \n', retValue);
  http ('  XMLELEMENT (\'http://www.itunes.com/DTDs/Podcast-1.0.dtd:author\', ENEWS.WA.utf2wide (U_FULL_NAME)), \n', retValue);
  http ('  XMLELEMENT (\'http://www.itunes.com/DTDs/Podcast-1.0.dtd:owner\', \n', retValue);
  http ('    XMLELEMENT (\'http://www.itunes.com/DTDs/Podcast-1.0.dtd:name\', ENEWS.WA.utf2wide (U_FULL_NAME)),\n', retValue);
  http ('    XMLELEMENT (\'http://www.itunes.com/DTDs/Podcast-1.0.dtd:email\', U_E_MAIL) \n', retValue);
  http ('  ), \n', retValue);
  http ('  XMLELEMENT (\'language\', \'en-us\'), \n', retValue);
  http ('  XMLELEMENT (\'http://www.itunes.com/DTDs/Podcast-1.0.dtd:category\', XMLATTRIBUTES (\'News\' as \'text\')), \n', retValue);
  http ('  XMLELEMENT (\'http://www.itunes.com/DTDs/Podcast-1.0.dtd:explicit\', \'no\') \n', retValue);
  http ('from DB.DBA.SYS_USERS where U_ID = <USER_ID> \n', retValue);
  http (']]></sql:sqlx>\n', retValue);

  http ('<sql:sqlx><![CDATA[\n', retValue);
  http ('select \n', retValue);
  http ('  XMLAGG(XMLELEMENT(\'item\', \n', retValue);
  http ('    XMLELEMENT (\'title\', ENEWS.WA.utf2wide(EFI_TITLE)), \n', retValue);
  http ('    XMLELEMENT (\'description\', ENEWS.WA.utf2wide(ENEWS.WA.xml2string(EFI_DESCRIPTION))), \n', retValue);
  http ('    XMLELEMENT (\'guid\', EFI_GUID), \n', retValue);
  http ('    XMLELEMENT (\'link\', EFI_LINK), \n', retValue);
  http ('    XMLELEMENT (\'pubDate\', ENEWS.WA.dt_rfc1123 (EFI_PUBLISH_DATE)),\n', retValue);
  http ('    XMLELEMENT (\'http://www.itunes.com/DTDs/Podcast-1.0.dtd:author\', ENEWS.WA.utf2wide (EFI_AUTHOR)), \n', retValue);
  http ('    XMLELEMENT (\'http://www.itunes.com/DTDs/Podcast-1.0.dtd:explicit\', \'no\'), \n', retValue);
  http ('    XMLELEMENT (\'http://www.itunes.com/DTDs/Podcast-1.0.dtd:keywords\', ENEWS.WA.tags_account_item_select(<DOMAIN_ID>, <USER_ID>, EFI_ID)), \n', retValue);
  http ('    ENEWS.WA.enclosure_render_sqlx (EFI_DATA)))\n', retValue);
  http ('from (select top 15  \n', retValue);
  http ('        EFI_ID, \n', retValue);
  http ('        EFI_TITLE, \n', retValue);
  http ('        EFI_DESCRIPTION, \n', retValue);
  http ('        EFI_PUBLISH_DATE, \n', retValue);
  http ('        EFI_GUID, \n', retValue);
  http ('        EFI_LINK, \n', retValue);
  http ('        EFI_AUTHOR, \n', retValue);
  http ('        EFI_DATA \n', retValue);
  http ('      from \n', retValue);
  http ('        ENEWS.WA.FEED_ITEM, \n', retValue);
  http ('        ENEWS.WA.FEED_DOMAIN \n', retValue);
  http ('      where EFD_FEED_ID = EFI_FEED_ID  \n', retValue);
  http ('        and EFD_DOMAIN_ID = <DOMAIN_ID> \n', retValue);
  http ('        and EFI_ENCLOSURE = 1 \n', retValue);
  http ('      order by EFI_PUBLISH_DATE desc) x \n', retValue);
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
create procedure ENEWS.WA.export_ocs_sqlx(
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
  http('XMLELEMENT(\'http://purl.org/metadata/dublin_core#:title\', ENEWS.WA.utf2wide(ENEWS.WA.user_name(U_NAME, U_FULL_NAME))), \n', retValue);
  http('XMLELEMENT(\'http://purl.org/metadata/dublin_core#:creator\', U_E_MAIL), \n', retValue);
  http('XMLELEMENT(\'http://purl.org/metadata/dublin_core#:description\', \'\') \n', retValue);
  http('from WS.WS.SYS_DAV_USER where U_ID = <USER_ID>\n', retValue);
  http(']]></sql:sqlx>\n', retValue);

  http('<sql:sqlx><![CDATA[\n', retValue);
  http('select \n', retValue);
  http('XMLELEMENT(\'http://www.w3.org/1999/02/22-rdf-syntax-ns#:description\', \n', retValue);
  http('XMLATTRIBUTES(EF_URI as \'about\'), \n', retValue);
  http('XMLELEMENT(\'http://purl.org/metadata/dublin_core#:title\', ENEWS.WA.utf2wide(EFD_TITLE)), \n', retValue);
  http('XMLELEMENT(\'http://purl.org/metadata/dublin_core#:creator\', \'\'), \n', retValue);
  http('XMLELEMENT(\'http://purl.org/metadata/dublin_core#:description\', \'\'), \n', retValue);
  http('XMLELEMENT(\'http://purl.org/metadata/dublin_core#:subject\', \'\'), \n', retValue);
  http('XMLELEMENT(\'http://InternetAlchemy.org/ocs/directory#:image\', \'\'), \n', retValue);
  http('XMLELEMENT(\'http://www.w3.org/1999/02/22-rdf-syntax-ns#:description\', \n', retValue);
  http('XMLATTRIBUTES(EF_URI as \'about\'), \n', retValue);
  http('XMLELEMENT(\'http://purl.org/metadata/dublin_core#:language\', EF_LANG), \n', retValue);
  http('XMLELEMENT(\'http://InternetAlchemy.org/ocs/directory#:format\', EF_FORMAT), \n', retValue);
  http('XMLELEMENT(\'http://InternetAlchemy.org/ocs/directory#:updatePeriod\', EF_UPDATE_PERIOD), \n', retValue);
  http('XMLELEMENT(\'http://InternetAlchemy.org/ocs/directory#:updateFrequency\', EF_UPDATE_FREQ), \n', retValue);
  http('XMLELEMENT(\'http://InternetAlchemy.org/ocs/directory#:updateBase\', \'1999-05-30T00:00\'))) \n', retValue);
  http('from ENEWS.WA.FEED_DOMAIN, ENEWS.WA.FEED where EFD_FEED_ID = EF_ID and EFD_DOMAIN_ID = <DOMAIN_ID>\n', retValue);
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
create procedure ENEWS.WA.export_ocs_xml(
  in domain_id integer,
  in account_id integer)
{
  declare sql, state, message, meta, result any;

  sql := ENEWS.WA.export_ocs(domain_id, account_id);
  exec(sql, state, message, vector(), 0, meta, result);

  return result;
}
;

-------------------------------------------------------------------------------
--
create procedure ENEWS.WA.export_opml_xml(
  in domain_id integer,
  in account_id integer)
{
  declare aXML any;

  aXML := (select XMLELEMENT ('opml', XMLATTRIBUTES('1.0' as 'version'), XMLELEMENT ('head'), XMLELEMENT ('body', XMLAGG (XMLELEMENT ('outline', XMLATTRIBUTES(EFD_TITLE as 'title', EFD_TITLE as 'text', 'rss' as 'type', EF_HOME_URI as 'htmlUrl', EF_URI as 'xmlUrl')))))
             from ENEWS.WA.FEED_DOMAIN,
                  ENEWS.WA.FEED
            where EFD_FEED_ID = EF_ID and EFD_DOMAIN_ID = domain_id);
  return aXML;

}
;

-------------------------------------------------------------------------------
--
create procedure ENEWS.WA.export_opml_sqlx(
  in domain_id integer,
  in account_id integer)
{
  declare retValue any;

  retValue := string_output ();

  http ('<?xml version =\'1.0\' encoding=\'UTF-8\'?>\n', retValue);
  http ('<opml version="1.0">\n', retValue);

  http ('<head>\n', retValue);

  http ('<sql:sqlx xmlns:sql=\'urn:schemas-openlink-com:xml-sql\'><![CDATA[\n', retValue);
  http ('select XMLELEMENT (\'title\', ENEWS.WA.utf2wide(WAI_NAME)) from DB.DBA.WA_INSTANCE where WAI_ID = <DOMAIN_ID>\n', retValue);
  http (']]></sql:sqlx>\n', retValue);

  http ('</head>\n', retValue);

  http ('<body>\n', retValue);

  http ('<sql:sqlx xmlns:sql=\'urn:schemas-openlink-com:xml-sql\'><![CDATA[\n', retValue);
  http ('select \n', retValue);
  http ('XMLAGG(XMLELEMENT(\'outline\',\n', retValue);
  http ('XMLATTRIBUTES(ENEWS.WA.utf2wide(EFD_TITLE) as \'title\', ENEWS.WA.utf2wide(EFD_TITLE) as \'text\', \'rss\' as \'type\', EF_HOME_URI as \'htmlUrl\', EF_URI as \'xmlUrl\')))\n', retValue);
  http ('from ENEWS.WA.FEED_DOMAIN, ENEWS.WA.FEED where EFD_FEED_ID = EF_ID and EFD_DOMAIN_ID = <DOMAIN_ID>\n', retValue);
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
create procedure ENEWS.WA.export_foaf_sqlx(
  in domain_id integer,
  in account_id integer)
{
  declare retValue any;

  retValue := string_output ();

  http ('<?xml version="1.0" encoding="UTF-8"?>\n', retValue);
  http ('<rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#" xmlns:rdfs="http://www.w3.org/2000/01/rdf-schema#" xmlns:foaf="http://xmlns.com/foaf/0.1/" xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:plan="http://usefulinc.com/ns/scutter/0.1#">\n', retValue);
  http ('<foaf:Person rdf:about="">\n', retValue);

  http ('<sql:sqlx xmlns:sql="urn:schemas-openlink-com:xml-sql" sql:xsl=""><![CDATA[\n', retValue);
  http ('select\n', retValue);
  http ('XMLELEMENT(\'http://xmlns.com/foaf/0.1/:name\', ENEWS.WA.utf2wide(ENEWS.WA.user_name(U_NAME, U_FULL_NAME))), \n', retValue);
  http ('XMLELEMENT(\'http://xmlns.com/foaf/0.1/:nick\', U_NAME), \n', retValue);
  http ('XMLELEMENT(\'http://xmlns.com/foaf/0.1/:mbox\', \n', retValue);
  http ('XMLATTRIBUTES(\'mailto:\'||U_E_MAIL as \'http://www.w3.org/1999/02/22-rdf-syntax-ns#:resource\')), \n', retValue);
  http ('XMLELEMENT(\'http://xmlns.com/foaf/0.1/:seeAlso\', \n', retValue);
  http ('  XMLATTRIBUTES(ENEWS.WA.dav_url(<DOMAIN_ID>, <USER_ID>) || \'OFM.rdf\' as \'http://www.w3.org/1999/02/22-rdf-syntax-ns#:resource\')) \n', retValue);
  http ('from DB.DBA.SYS_USERS \n', retValue);
  http ('where U_ID = <USER_ID> \n', retValue);
  http (']]></sql:sqlx>\n', retValue);

  http ('<sql:sqlx xmlns:sql="urn:schemas-openlink-com:xml-sql"><![CDATA[\n', retValue);
  http ('select\n', retValue);
  http ('  XMLELEMENT(\'http://www.w3.org/2000/01/rdf-schema#:seeAlso\',\n', retValue);
  http ('  XMLELEMENT(\'http://purl.org/rss/1.0/:channel\',\n', retValue);
  http ('  XMLATTRIBUTES(EF_URI as \'http://www.w3.org/1999/02/22-rdf-syntax-ns#:about\'), \n', retValue);
  http ('  XMLELEMENT(\'http://purl.org/dc/elements/1.1/:title\', ENEWS.WA.utf2wide(EFD_TITLE)))) \n', retValue);
  --http ('  XMLELEMENT(\'http://purl.org/dc/elements/1.1/:home\', EF_HOME_URI))) \n', retValue);
  http ('from ENEWS.WA.FEED_DOMAIN, ENEWS.WA.FEED \n', retValue);
  http ('where EFD_FEED_ID = EF_ID and EFD_DOMAIN_ID = <DOMAIN_ID>\n', retValue);
  http (']]></sql:sqlx>\n', retValue);

  http ('</foaf:Person>\n', retValue);
  http ('</rdf:RDF>\n', retValue);

  retValue := string_output_string (retValue);
  retValue :=  replace(retValue, '<USER_ID>', cast(account_id as varchar));
  retValue :=  replace(retValue, '<DOMAIN_ID>', cast(domain_id as varchar));
  retValue := replace (retValue, 'sql:xsl=""', sprintf('sql:xsl="%s"', ENEWS.WA.xslt_full ('foaf.xsl')));
  --dbg_obj_print(account_id, domain_id, retValue);
  return retValue;
}
;

-----------------------------------------------------------------------------
--
create procedure ENEWS.WA.xml_set(
  in id varchar,
  inout pXml varchar,
  in value varchar)
{
  declare aEntity any;

  {
    declare exit handler for SQLSTATE '*' {
      pXml := xtree_doc('<?xml version="1.0" encoding="UTF-8"?><settings></settings>');
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
    XMLAppendChildren(aEntity, xtree_doc(sprintf('<entry ID="%s">%s</entry>', id, ENEWS.WA.xml2string(value))));
  }
  return pXml;
}
;

-----------------------------------------------------------------------------
--
create procedure ENEWS.WA.xml_get(
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

  return ENEWS.WA.wide2utf(value);
}
;

-------------------------------------------------------------------------------
--
create procedure ENEWS.WA.string2xml (
  in content varchar,
  in mode integer := 0) returns any
{
  if (not mode) {
    declare exit handler for sqlstate '*' { goto _html; };
    return xml_tree_doc (xml_tree (content, 0));
  }
_html:;
  return xml_tree_doc(xml_tree(content, 2, '', 'UTF-8'));
}
;

-------------------------------------------------------------------------------
--
create procedure ENEWS.WA.xml2string(
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
create procedure ENEWS.WA.normalize_space(
  in S varchar)
{
  return xpath_eval ('normalize-space (string(/a))', XMLELEMENT('a', S), 1);
}
;

-------------------------------------------------------------------------------
--
create procedure ENEWS.WA.utf2wide (
  inout S any)
{
  declare exit handler for sqlstate '*' { return S; };
  return charset_recode (S, 'UTF-8', '_WIDE_');
}
;

-------------------------------------------------------------------------------
--
create procedure ENEWS.WA.wide2utf (
  inout S any)
{
  if (iswidestring (S))
    return charset_recode (S, '_WIDE_', 'UTF-8' );
  return S;
}
;

-------------------------------------------------------------------------------
--
create procedure ENEWS.WA.vector_unique(
  inout aVector any,
  in minLength integer := 0)
{
  declare aResult any;
  declare N, L, M integer;

  aResult := vector();
  L := length(aVector);
  for (N := 0; N < L; N := N + 1) {
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
create procedure ENEWS.WA.vector_except(
  inout aVector any,
  inout aExcept any)
{
  declare aResult any;
  declare N, L, M integer;

  aResult := vector();
  L := length(aVector);
  for (N := 0; N < L; N := N + 1) {
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
create procedure ENEWS.WA.vector_contains(
  inout aVector any,
  in value varchar)
{
  declare N, L integer;

  L := length(aVector);
  for (N := 0; N < L; N := N + 1)
    if (value = aVector[N])
      return 1;
  return 0;
}
;

-------------------------------------------------------------------------------
--
create procedure ENEWS.WA.vector_cut(
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
create procedure ENEWS.WA.vector_search(
  inout aVector any,
  in value varchar,
  in condition varchar := 'AND')
{
  declare N, L integer;

  L := length(aVector);
  for (N := 0; N < L; N := N + 1)
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
create procedure ENEWS.WA.vector2str(
  inout aVector any,
  in delimiter varchar := ' ')
{
  declare tmp, aResult any;
  declare N, L integer;

  aResult := '';
  L := length(aVector);
  for (N := 0; N < L; N := N + 1) {
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
create procedure ENEWS.WA.vector2rs(
  inout aVector any)
{
  declare N, L integer;
  declare c0 varchar;

  result_names(c0);
  L := length(aVector);
  for (N := 0; N < L; N := N + 1)
    result(aVector[N]);
}
;

-------------------------------------------------------------------------------
--
create procedure ENEWS.WA.tagsDictionary2rs(
  inout aDictionary any)
{
  declare N, L integer;
  declare c0 varchar;
  declare c1 integer;
  declare V any;

  result_names(c0, c1);
  V := dict_to_vector(aDictionary, 1);
  L := length(V);
  for (N := 1; N < L; N := N + 2)
    result(V[N][0], V[N][1]);
}
;

-------------------------------------------------------------------------------
--
create procedure ENEWS.WA.vector2src(
  inout aVector any)
{
  declare N, L integer;
  declare aResult any;

  aResult := 'vector(';
  L := length(aVector);
  for (N := 0; N < L; N := N + 1) {
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
create procedure ENEWS.WA.ft2vector(
  in S any)
{
  declare w varchar;
  declare aResult any;

  aResult := vector();
  w := regexp_match ('["][^"]+["]|[''][^'']+['']|[^"'' ]+', S, 1);
  while (w is not null) {
    w := trim (w, '"'' ');
    if (upper(w) not in ('AND', 'NOT', 'NEAR', 'OR') and length (w) > 1 and not vt_is_noise (ENEWS.WA.wide2utf(w), 'utf-8', 'x-ViDoc'))
      aResult := vector_concat(aResult, vector(w));
    w := regexp_match ('["][^"]+["]|[''][^'']+['']|[^"'' ]+', S, 1);
  }
  return aResult;
}
;

-------------------------------------------------------------------------------
--
create procedure ENEWS.WA.set_keyword(
  in    name   varchar,
  inout params any,
  in    value  any)
{
  declare N, L integer;

  L := length(params);
  for (N := 0; N < L; N := N + 2)
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
create procedure ENEWS.WA.enews_path2_int(
  in domain_id integer,
  in node varchar,
  inout path varchar)
{
  declare node_type, node_id any;

  node_id := ENEWS.WA.node_id(node);
  node_type := ENEWS.WA.node_type(node);

  if ((node_type = 'f') and (node_id <> 0))
    for (select EFO_PARENT_ID from ENEWS.WA.FOLDER where EFO_DOMAIN_ID = domain_id and coalesce(EFO_ID, 0) = coalesce(node_id, 0)) do {
      path := sprintf('f#%d/%s', coalesce(EFO_PARENT_ID, 0), path);
      ENEWS.WA.enews_path2_int(domain_id, sprintf('f#%d', coalesce(EFO_PARENT_ID, 0)), path);
  }

  if (node_type = 'c')
    for (select EFD_FOLDER_ID from ENEWS.WA.FEED_DOMAIN where EFD_DOMAIN_ID = domain_id and EFD_ID = node_id) do {
      path := sprintf('f#%d/%s', coalesce(EFD_FOLDER_ID, 0), path);
      ENEWS.WA.enews_path2_int(domain_id, sprintf('f#%d', coalesce(EFD_FOLDER_ID, 0)), path);
}

  if ((node_type = 'p') and (node_id <> 0))
    path := sprintf('P#0/%s', path);

  if (node_type = 's')
    path := sprintf('S#0/%s', path);

  if ((node_type = 'w') and (node_id <> 0))
    path := sprintf('w#0/%s', path);

  if ((node_type = 'b') and (node_id <> 0))
    for (select EW_ID from ENEWS.WA.BLOG, ENEWS.WA.WEBLOG where EW_DOMAIN_ID = domain_id and EW_ID = node_id and EB_WEBLOG_ID = EW_ID) do {
      path := sprintf('w#%d/%s', coalesce(EW_ID, 0), path);
      ENEWS.WA.enews_path2_int(domain_id, sprintf('w#%d', coalesce(EW_ID, 0)), path);
  }
}
;

-------------------------------------------------------------------------------
--
create procedure ENEWS.WA.enews_path2(
  in domain_id integer,
  in node varchar)
{
  declare path any;

  path := node;
  ENEWS.WA.enews_path2_int(domain_id, node, path);
  return path;
}
;

-------------------------------------------------------------------------------
--
create procedure ENEWS.WA.enews_tree2(
  in domain_id integer,
  in node varchar,
  in path varchar)
{
  declare node_type, node_id any;

  node_id := ENEWS.WA.node_id(node);
  node_type := ENEWS.WA.node_type(node);
  if ((node_type = 'r') and (node_id = 0))
    return vector('Last Feeds', 'P#0', '');

  if ((node_type = 'r') and (node_id = 1))
    return vector('Feeds', 'f#0', path || '/f#0', 'Smart Folders', 'S#0', path || '/S#0', 'Weblogs', 'w#0', path || '/w#0');

  declare retValue any;
  retValue := vector ();

  if (node_type = 'P')
   for (select distinct top 10 EF_ID, EF_TITLE from ENEWS.WA.FEED order by EF_LAST_UPDATE desc) do
     retValue := vector_concat(retValue, vector(EF_TITLE, sprintf('p#%d', EF_ID), sprintf('%s/p#%d', path, EF_ID)));

  if (node_type = 'f') {
    for (select EFO_ID, EFO_NAME from ENEWS.WA.FOLDER where EFO_DOMAIN_ID = domain_id and coalesce(EFO_PARENT_ID, 0) = coalesce(node_id, 0) order by 2) do
      retValue := vector_concat(retValue, vector(EFO_NAME, sprintf('f#%d', EFO_ID), sprintf('%s/f#%d', path, EFO_ID)));
    for (select EFD_ID, coalesce(EFD_TITLE, EF_TITLE) EFD_TITLE from ENEWS.WA.FEED join ENEWS.WA.FEED_DOMAIN on EF_ID = EFD_FEED_ID where EFD_DOMAIN_ID = domain_id and coalesce(EFD_FOLDER_ID, 0) = node_id order by 2) do
      retValue := vector_concat(retValue, vector(EFD_TITLE, sprintf('c#%d', EFD_ID), sprintf('%s/c#%d', path, EFD_ID)));
  }

  if (node_type = 'S')
    for (select ESFO_ID, ESFO_NAME from ENEWS.WA.SFOLDER where ESFO_DOMAIN_ID = domain_id order by 2) do
      retValue := vector_concat(retValue, vector(ESFO_NAME, sprintf('s#%s', ESFO_ID), sprintf('%s/s#%s', path, ESFO_ID)));

  if ((node_type = 'w') and (node_id = 0))
    for (select EW_ID, EW_NAME from ENEWS.WA.WEBLOG where EW_DOMAIN_ID = domain_id order by 2) do
      retValue := vector_concat(retValue, vector(EW_NAME, sprintf('w#%d', EW_ID), sprintf('%s/w#%d', path, EW_ID)));

  if ((node_type = 'w') and (node_id <> 0))
    for (select EB_ID, EB_NAME from ENEWS.WA.BLOG, ENEWS.WA.WEBLOG where EW_DOMAIN_ID = domain_id and EW_ID = node_id and EB_WEBLOG_ID = EW_ID order by 2) do
      retValue := vector_concat(retValue, vector(EB_NAME, sprintf('b#%d', EB_ID), sprintf('%s/b#%d', path, EB_ID)));

  return retValue;
}
;

-------------------------------------------------------------------------------
--
create procedure ENEWS.WA.node_type(
  in code varchar)
{
  if (length(code) > 1)
    if (substring(code,2,1) = '#')
      return left(code, 1);
  return '';
}
;

-------------------------------------------------------------------------------
--
create procedure ENEWS.WA.node_prefix(
  in code varchar)
{
  if (length(code) > 1)
    if (substring(code,2,1) = '#')
      return left(code, 2);
  return '';
}
;

-------------------------------------------------------------------------------
--
create procedure ENEWS.WA.node_id(
  in code varchar)
{
  declare exit handler for sqlstate '*' { return 0; };

  if (length(code) > 2)
    if (substring(code,2,1) = '#')
      return cast(subseq(code, 2) as integer);
  return 0;
}
;

-------------------------------------------------------------------------------
--
create procedure ENEWS.WA.node_suffix(
  in code varchar)
{
  if (length(code) > 2)
    if (substring(code,2,1) = '#')
      return subseq(code, 2);
  return '';
}
;

-------------------------------------------------------------------------------
--
-- Show functions
--
-------------------------------------------------------------------------------
--
create procedure ENEWS.WA.show_text(
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
create procedure ENEWS.WA.show_title(
  in S any)
{
  return ENEWS.WA.show_text(S, 'title');
}
;

-------------------------------------------------------------------------------
--
create procedure ENEWS.WA.show_author(
  in S any)
{
  return ENEWS.WA.show_text(S, 'author');
}
;

-------------------------------------------------------------------------------
--
create procedure ENEWS.WA.show_description(
  in S any)
{
  return ENEWS.WA.show_text(S, 'description');
}
;

-------------------------------------------------------------------------------
--
create procedure ENEWS.WA.show_excerpt(
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
create procedure ENEWS.WA.dt_current_time()
{
  return dateadd('minute', - timezone(now()),now());
}
;

-------------------------------------------------------------------------------
--
-- convert from GMT date to user timezone;
--
create procedure ENEWS.WA.dt_gmt2user(
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
create procedure ENEWS.WA.dt_user2gmt(
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
create procedure ENEWS.WA.dt_value(
  in pDate datetime,
  in pDefault datetime := null,
  in pUser datetime := null)
{
  if (isnull(pDefault))
    pDefault := now();
  if (isnull(pDate))
    pDate := pDefault;
  pDate := ENEWS.WA.dt_gmt2user(pDate, pUser);
  if (ENEWS.WA.dt_format(pDate, 'D.M.Y') = ENEWS.WA.dt_format(now(), 'D.M.Y'))
    return concat('today ', ENEWS.WA.dt_format(pDate, 'H:N'));
  return ENEWS.WA.dt_format(pDate, 'D.M.Y H:N');
}
;

-----------------------------------------------------------------------------
--
create procedure ENEWS.WA.dt_format(
  in pDate datetime,
  in pFormat varchar := 'd.m.Y')
{
  declare
    N integer;
  declare
    ch,
    S varchar;

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
create procedure ENEWS.WA.dt_deformat(
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

  N := 1;
  I := 0;
  d := 0;
  m := 0;
  y := 0;
  while (N <= length(pFormat)) {
    ch := upper(substring(pFormat, N, 1));
    if (ch = 'M')
      m := ENEWS.WA.dt_deformat_tmp(pString, I);
    if (ch = 'D')
      d := ENEWS.WA.dt_deformat_tmp(pString, I);
    if (ch = 'Y') {
      y := ENEWS.WA.dt_deformat_tmp(pString, I);
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
create procedure ENEWS.WA.dt_deformat_tmp(
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
create procedure ENEWS.WA.dt_reformat(
  in pString varchar,
  in pInFormat varchar := 'd.m.Y',
  in pOutFormat varchar := 'm.d.Y')
{
  return ENEWS.WA.dt_format(ENEWS.WA.dt_deformat(pString, pInFormat), pOutFormat);
};

-----------------------------------------------------------------------------------------
--
create procedure ENEWS.WA.dt_convert(
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
create procedure ENEWS.WA.dt_rfc1123 (
  in dt datetime)
{
  return soap_print_box (dt, '', 1);
}
;

-----------------------------------------------------------------------------------------
--
create procedure ENEWS.WA.dt_iso8601 (
  in dt datetime)
{
  return soap_print_box (dt, '', 0);
}
;

-----------------------------------------------------------------------------------------
--
create procedure ENEWS.WA.data (
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
create procedure ENEWS.WA.test_clear (
  in S any)
{
  declare N integer;

  return substring(S, 1, coalesce(strstr(S, '<>'), length(S)));
}
;

-----------------------------------------------------------------------------------------
--
create procedure ENEWS.WA.test (
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
      if (valueType = 'free-text') {
        signal ('TEST', sprintf('Field ''%s'' contains invalid characters or noise words!<>', valueName));
      } else {
      signal ('TEST', sprintf('Field ''%s'' contains invalid characters!<>', valueName));
      }
    }
    if (__SQL_STATE = 'TYPE')
      signal ('TEST', sprintf('Field ''%s'' contains invalid characters for \'%s\'!<>', valueName, valueType));
    if (__SQL_STATE = 'MIN')
      signal ('TEST', sprintf('''%s'' value should be greater then %s!<>', valueName, cast(tmp as varchar)));
    if (__SQL_STATE = 'MAX')
      signal ('TEST', sprintf('''%s'' value should be less then %s!<>', valueName, cast(tmp as varchar)));
    if (__SQL_STATE = 'MINLENGTH')
      signal ('TEST', sprintf('The length of field ''%s'' should be greater then %s characters!<>', valueName, cast(tmp as varchar)));
    if (__SQL_STATE = 'MAXLENGTH')
      signal ('TEST', sprintf('The length of field ''%s'' should be less then %s characters!<>', valueName, cast(tmp as varchar)));
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

  value := ENEWS.WA.validate2 (valueClass, value);

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
    if (not isnull(tmp) and (length(value) < tmp))
      signal('MINLENGTH', cast(tmp as varchar));

    tmp := get_keyword('maxLength', params);
    if (not isnull(tmp) and (length(value) > tmp))
      signal('MAXLENGTH', cast(tmp as varchar));
  }
  return value;
}
;

-----------------------------------------------------------------------------------------
--
create procedure ENEWS.WA.validate2 (
  in propertyType varchar,
  in propertyValue varchar)
{
  declare exit handler for SQLSTATE '*' {
    if (__SQL_STATE = 'CLASS')
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
    return stringdate(ENEWS.WA.dt_reformat(propertyValue, 'd.m.Y', 'Y-M-D'));
  } else if (propertyType = 'time') {
    if (isnull(regexp_match('^([01]?[0-9]|[2][0-3])(:[0-5][0-9])?\$', propertyValue)))
      goto _error;
    return cast(propertyValue as time);
  } else if (propertyType = 'folder') {
    if (isnull(regexp_match('^[^\\\/\?\*\"\'\>\<\:\|]*\$', propertyValue)))
      goto _error;
  } else if ((propertyType = 'uri') or (propertyType = 'anyuri')) {
    if (isnull(regexp_match('^(ht|f)tp(s?)\:\/\/[0-9a-zA-Z]([-.\w]*[0-9a-zA-Z])*(:(0-9)*)*(\/?)([a-zA-Z0-9\-\.\?\,\'\/\\\+&amp;%\$#_]*)?\$', propertyValue)))
      goto _error;
  } else if (propertyType = 'email') {
    if (isnull(regexp_match('^([a-zA-Z0-9_\-])+(\.([a-zA-Z0-9_\-])+)*@((\[(((([0-1])?([0-9])?[0-9])|(2[0-4][0-9])|(2[0-5][0-5])))\.(((([0-1])?([0-9])?[0-9])|(2[0-4][0-9])|(2[0-5][0-5])))\.(((([0-1])?([0-9])?[0-9])|(2[0-4][0-9])|(2[0-5][0-5])))\.(((([0-1])?([0-9])?[0-9])|(2[0-4][0-9])|(2[0-5][0-5]))\]))|((([a-zA-Z0-9])+(([\-])+([a-zA-Z0-9])+)*\.)+([a-zA-Z])+(([\-])+([a-zA-Z0-9])+)*))\$', propertyValue)))
      goto _error;
  } else if (propertyType = 'free-text') {
    if (length(propertyValue))
      if (not ENEWS.WA.validate_freeTexts(propertyValue))
        goto _error;
  } else if (propertyType = 'free-text-expression') {
    if (length(propertyValue))
      if (not ENEWS.WA.validate_freeText(propertyValue))
        goto _error;
  } else if (propertyType = 'tags') {
    if (not ENEWS.WA.validate_tags(propertyValue))
      goto _error;
  }
  return propertyValue;

_error:
  signal('CLASS', propertyType);
}
;

-----------------------------------------------------------------------------------------
--
create procedure ENEWS.WA.validate (
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
create procedure ENEWS.WA.validate_freeText (
  in S varchar)
{
  declare st, msg varchar;

  if (upper(S) in ('AND', 'NOT', 'NEAR', 'OR'))
    return 0;
  if (length (S) < 2)
    return 0;
  if (vt_is_noise (ENEWS.WA.wide2utf(S), 'utf-8', 'x-ViDoc'))
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
create procedure ENEWS.WA.validate_freeTexts (
  in S any)
{
  declare w varchar;

  w := regexp_match ('["][^"]+["]|[''][^'']+['']|[^"'' ]+', S, 1);
  while (w is not null) {
    w := trim (w, '"'' ');
    if (not ENEWS.WA.validate_freeText(w))
      return 0;
    w := regexp_match ('["][^"]+["]|[''][^'']+['']|[^"'' ]+', S, 1);
  }
  return 1;
}
;

-----------------------------------------------------------------------------------------
--
create procedure ENEWS.WA.validate_tag (
  in S varchar)
{
  S := replace(trim(S), '+', '_');
  S := replace(trim(S), ' ', '_');
  if (not ENEWS.WA.validate_freeText(S))
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
create procedure ENEWS.WA.validate_tags (
  in S varchar)
{
  declare N, L integer;
  declare V any;

  V := ENEWS.WA.tags2vector(S);
  if (is_empty_or_null(V))
    return 0;
  if (length(V) <> length(ENEWS.WA.tags2unique(V)))
    return 0;
  L := length(V);
  for (N := 0; N < L; N := N + 1)
    if (not ENEWS.WA.validate_tag(V[N]))
      return 0;
  return 1;
}
;

-----------------------------------------------------------------------------------------
--
create procedure ENEWS.WA.oMail_check(
  in account_id integer)
{
  return coalesce((select top 1 WAI_ID from DB.DBA.WA_MEMBER, DB.DBA.WA_INSTANCE where WAM_INST = WAI_NAME and WAM_USER = account_id and WAI_TYPE_NAME = 'oMail' order by WAI_ID), 0);
}
;

-----------------------------------------------------------------------------------------
--
create procedure ENEWS.WA.blog_check(
  in domain_id integer)
{
  return coalesce((select TOP 1 EB_ID from ENEWS.WA.BLOG, ENEWS.WA.WEBLOG where EB_WEBLOG_ID = EW_ID and EW_DOMAIN_ID = domain_id), 0);
}
;

-----------------------------------------------------------------------------------------
--
create procedure ENEWS.WA.version_update()
{
  for (select WAI_ID, WAM_USER
         from DB.DBA.WA_MEMBER join DB.DBA.WA_INSTANCE on WAI_NAME = WAM_INST
        where WAI_TYPE_NAME = 'eNews2' and WAM_MEMBER_TYPE = 1) do {
    ENEWS.WA.domain_update(WAI_ID, WAM_USER);
  }

  -- Members (List of members feeds)
  ENEWS.WA.directory_insert(null, 'Members');

  -- Arts (Entertainment, Books, Music, Movies, TV)
  ENEWS.WA.directory_insert(null, 'Arts');
  ENEWS.WA.directory_insert('Arts', 'Entertainment');
  ENEWS.WA.directory_insert('Arts', 'Books');
  ENEWS.WA.directory_insert('Arts', 'Music');
  ENEWS.WA.directory_insert('Arts', 'Movies');
  ENEWS.WA.directory_insert('Arts', 'TV');

  -- Business (News, Investing, Venture Capital)
  ENEWS.WA.directory_insert(null, 'Business');
  ENEWS.WA.directory_insert('Business', 'News');
  ENEWS.WA.directory_insert('Business', 'Investing');
  ENEWS.WA.directory_insert('Business', 'Venture Capital');

  -- Computers (Internet, Software, Hardware, Games Console, Computer, Online)
  ENEWS.WA.directory_insert(null, 'Computers');
  ENEWS.WA.directory_insert('Computers', 'Internet');
  ENEWS.WA.directory_insert('Computers', 'Software');
  ENEWS.WA.directory_insert('Computers', 'Hardware');
  ENEWS.WA.directory_insert('Computers', 'Games Console');
  ENEWS.WA.directory_insert('Computers', 'Computer');
  ENEWS.WA.directory_insert('Computers', 'Online');

  -- Regional (North America, Asia, Europe)
  ENEWS.WA.directory_insert(null, 'Regional');
  ENEWS.WA.directory_insert('Regional', 'North America');
  ENEWS.WA.directory_insert('Regional', 'Asia');
  ENEWS.WA.directory_insert('Regional', 'Europe');

  -- Shopping (Electronics, Autos, Fashion)
  ENEWS.WA.directory_insert(null, 'Shopping');
  ENEWS.WA.directory_insert('Shopping', 'Electronics');
  ENEWS.WA.directory_insert('Shopping', 'Autos');
  ENEWS.WA.directory_insert('Shopping', 'Fashion');

  -- Society (Law, Politics, Religion)
  ENEWS.WA.directory_insert(null, 'Society');
  ENEWS.WA.directory_insert('Society', 'Law');
  ENEWS.WA.directory_insert('Society', 'Politics');
  ENEWS.WA.directory_insert('Society', 'Religion');

  -- Science (News, Technhology, Biology)
  ENEWS.WA.directory_insert(null, 'Science');
  ENEWS.WA.directory_insert('Science', 'News');
  ENEWS.WA.directory_insert('Science', 'Technhology');
  ENEWS.WA.directory_insert('Science', 'Biology');

  -- Sports  (News, US, World)
  ENEWS.WA.directory_insert(null, 'Sports');
  ENEWS.WA.directory_insert('Sports', 'News');
  ENEWS.WA.directory_insert('Sports', 'US');
  ENEWS.WA.directory_insert('Sports', 'World');

  -- Health (Fitness, Medicine, Alternative)
  ENEWS.WA.directory_insert(null, 'Health');
  ENEWS.WA.directory_insert('Health', 'Fitness');
  ENEWS.WA.directory_insert('Health', 'Medicine');
  ENEWS.WA.directory_insert('Health', 'Alternative');

  -- Home (Garden, Cooking, Real Estate, News Top Stories, Opinion, Newspapers, Recreation Travel, Food, Outdoors, Humor, Reference Maps, Education, Libraries)
  ENEWS.WA.directory_insert(null, 'Home');
  ENEWS.WA.directory_insert('Home', 'Garden');
  ENEWS.WA.directory_insert('Home', 'Cooking');
  ENEWS.WA.directory_insert('Home', 'Real Estate');
  ENEWS.WA.directory_insert('Home', 'News Top Stories');
  ENEWS.WA.directory_insert('Home', 'Opinion');
  ENEWS.WA.directory_insert('Home', 'Newspapers');
  ENEWS.WA.directory_insert('Home', 'Recreation Travel');
  ENEWS.WA.directory_insert('Home', 'Food');
  ENEWS.WA.directory_insert('Home', 'Outdoors');
  ENEWS.WA.directory_insert('Home', 'Humor');
  ENEWS.WA.directory_insert('Home', 'Reference Maps');
  ENEWS.WA.directory_insert('Home', 'Education');
  ENEWS.WA.directory_insert('Home', 'Libraries');

  declare channel, title any;
  declare channel_id, directory_id integer;

  channel := vector('type', 'long', 'title', 'The Art Weblog', 'blog', 'http://art.weblogsinc.com/', 'rss', 'http://art.weblogsinc.com/rss.xml', 'format', 'http://my.netscape.com/rdf/simple/0.9/', 'lang', 'en-us', 'updatePeriod', 'daily', 'updateFrequency', 4, 'data', '<settings><entry ID="imageUrl">http://art.weblogsinc.com/media/feedlogo.gif</entry><entry ID="iconUrl">http://art.weblogsinc.com/</entry></settings>');
  title := 'The Art Weblog';
  channel_id := ENEWS.WA.channel_create(channel);
  directory_id := (select ED_ID from ENEWS.WA.DIRECTORY where ENEWS.WA.directory_path(ED_ID) = 'Arts');
  ENEWS.WA.channel_directory(channel_id, null, directory_id);

  channel := vector('type', 'long', 'title', 'NYT -> Arts', 'blog', 'http://www.nytimes.com/pages/arts/index.html?partner=rssuserland', 'rss', 'http://partners.userland.com/nytrss/arts.xml', 'format', 'http://my.netscape.com/rdf/simple/0.9/', 'lang', 'en-us', 'updatePeriod', 'daily', 'updateFrequency', 4, 'data', '<settings><entry ID="imageUrl">http://graphics.nytimes.com/images/section/NytSectionHeader.gif</entry><entry ID="iconUrl">http://www.nytimes.com/pages/arts/index.html?partner=rssuserland/</entry></settings>');
  title := 'NYT -> Arts';
  channel_id := ENEWS.WA.channel_create(channel);
  directory_id := (select ED_ID from ENEWS.WA.DIRECTORY where ENEWS.WA.directory_path(ED_ID) = 'Arts');
  ENEWS.WA.channel_directory(channel_id, null, directory_id);

  channel := vector('type', 'long', 'title', 'The Digital Music Weblog', 'blog', 'http://digitalmusic.weblogsinc.com/', 'rss', 'http://digitalmusic.weblogsinc.com/rss.xml', 'format', 'http://my.netscape.com/rdf/simple/0.9/', 'lang', 'en-us', 'updatePeriod', 'daily', 'updateFrequency', 4, 'data', '<settings><entry ID="imageUrl">http://digitalmusic.weblogsinc.com/media/feedlogo.gif</entry><entry ID="iconUrl">http://digitalmusic.weblogsinc.com/</entry></settings>');
  title := 'The Digital Music Weblog';
  channel_id := ENEWS.WA.channel_create(channel);
  directory_id := (select ED_ID from ENEWS.WA.DIRECTORY where ENEWS.WA.directory_path(ED_ID) = 'Arts/Music');
  ENEWS.WA.channel_directory(channel_id, null, directory_id);

  channel := vector('type', 'long', 'title', 'MTVe.com', 'blog', 'http://www.mtve.com/', 'rss', 'http://mtve.com/feeds/rss.php', 'format', 'http://my.netscape.com/rdf/simple/0.9/', ' updatePeriod', 'daily', 'updateFrequency', 4, 'data', '<settings><entry ID="imageUrl">http://www.mtve.com/images/feeds/rss/mtvlogo.jpg</entry><entry ID="iconUrl">http://www.mtve.com/</entry></settings>');
  title := 'MTVe.com';
  channel_id := ENEWS.WA.channel_create(channel);
  directory_id := (select ED_ID from ENEWS.WA.DIRECTORY where ENEWS.WA.directory_path(ED_ID) = 'Arts/Music');
  ENEWS.WA.channel_directory(channel_id, null, directory_id);

  channel := vector('type', 'long', 'title', 'London Review of Books', 'blog', 'http://www.lrb.co.uk', 'rss', 'http://lrb.co.uk/homerss.xml', 'format', 'http://my.netscape.com/rdf/simple/0.9/', 'lang', 'en-gb', 'updatePeriod', 'daily', 'updateFrequency', 4, 'data', '<settings><entry ID="imageUrl">http://www.lrb.co.uk/assets/images/lrb_ad.gif</entry><entry ID="iconUrl">http://www.lrb.co.uk/</entry></settings>');
  title := 'London Review of Books';
  channel_id := ENEWS.WA.channel_create(channel);
  directory_id := (select ED_ID from ENEWS.WA.DIRECTORY where ENEWS.WA.directory_path(ED_ID) = 'Arts/Books');
  ENEWS.WA.channel_directory(channel_id, null, directory_id);

  channel := vector('type', 'long', 'title', 'NYT -> Books', 'blog', 'http://www.nytimes.com/pages/books/index.html?partner=rssuserland', 'rss', 'http://partners.userland.com/nytrss/books.xml', 'format', 'http://my.netscape.com/rdf/simple/0.9/', 'lang', 'en-us', 'updatePeriod', 'daily', 'updateFrequency', 4, 'data', '<settings><entry ID="imageUrl">http://graphics.nytimes.com/images/section/NytSectionHeader.gif</entry><entry ID="iconUrl">http://www.nytimes.com/pages/books/index.html?partner=rssuserland/</entry></settings>');
  title := 'NYT -> Books';
  channel_id := ENEWS.WA.channel_create(channel);
  directory_id := (select ED_ID from ENEWS.WA.DIRECTORY where ENEWS.WA.directory_path(ED_ID) = 'Arts/Books');
  ENEWS.WA.channel_directory(channel_id, null, directory_id);
}
;

-----------------------------------------------------------------------------------------
--
ENEWS.WA.version_update()
;

-----------------------------------------------------------------------------------------
--
-- NNTP Conversation
--
-----------------------------------------------------------------------------------------
create procedure ENEWS.WA.conversation_enable(
  in domain_id integer)
{
  return cast(get_keyword('conv', ENEWS.WA.settings(domain_id, -1), '0') as integer);
}
;

-----------------------------------------------------------------------------------------
--
create procedure ENEWS.WA.cm_root_node (
  in item_id varchar)
{
  declare root_id any;
  declare xt any;

  root_id := (select EFIC_ID from ENEWS.WA.FEED_ITEM_COMMENT where EFIC_ITEM_ID = item_id and EFIC_PARENT_ID is null);
  xt := (select xmlagg (xmlelement ('node', xmlattributes (EFIC_ID as id, EFIC_ID as name, EFIC_ITEM_ID as post)))
  	      from ENEWS.WA.FEED_ITEM_COMMENT
  	     where EFIC_ITEM_ID = item_id and EFIC_PARENT_ID = root_id order by EFIC_LAST_UPDATE);
  return xpath_eval ('//node', xt, 0);
}
;

-----------------------------------------------------------------------------------------
--
create procedure ENEWS.WA.cm_child_node (
  in item_id varchar,
  inout node any)
{
  declare parent_id int;
  declare xt any;

  parent_id := xpath_eval ('number (@id)', node);
  item_id := xpath_eval ('@post', node);

  xt := (select xmlagg (xmlelement ('node', xmlattributes (EFIC_ID as id, EFIC_ID as name, EFIC_ITEM_ID as post)))
  	       from ENEWS.WA.FEED_ITEM_COMMENT
  	      where EFIC_ITEM_ID = item_id and EFIC_PARENT_ID = parent_id order by EFIC_LAST_UPDATE);
  return xpath_eval ('//node', xt, 0);
}
;

-----------------------------------------------------------------------------------------
--
create procedure ENEWS.WA.make_rfc_id (
  in item_id integer,
  in comment_id integer := null)
{
  declare hashed, host any;

  hashed := md5 (uuid ());
  host := sys_stat ('st_host_name');
  if (isnull(comment_id))
    return sprintf ('<%d.%s@%s>', item_id, hashed, host);
  return sprintf ('<%d.%d.%s@%s>', item_id, comment_id, hashed, host);
}
;

-----------------------------------------------------------------------------------------
--
create procedure ENEWS.WA.make_mail_subject (
  in txt any,
  in id varchar := null)
{
  declare enc any;

  enc := encode_base64 (ENEWS.WA.wide2utf (txt));
  enc := replace (enc, '\r\n', '');
  txt := concat ('Subject: =?UTF-8?B?', enc, '?=\r\n');
  if (not isnull(id))
    txt := concat (txt, 'X-Virt-NewsID: ', uuid (), ';', id, '\r\n');
  return txt;
}
;

-----------------------------------------------------------------------------------------
--
create procedure ENEWS.WA.make_post_rfc_header (
  in mid varchar,
  in refs varchar,
  in gid varchar,
  in title varchar,
  in rec datetime,
  in author_mail varchar)
{
  declare ses any;

  ses := string_output ();
  http (ENEWS.WA.make_mail_subject (title), ses);
  http (sprintf ('Date: %s\r\n', DB.DBA.date_rfc1123 (rec)), ses);
  http (sprintf ('Message-Id: %s\r\n', mid), ses);
  if (not isnull(refs))
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
create procedure ENEWS.WA.make_post_rfc_msg (
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
create procedure ENEWS.WA.nntp_root (
  in domain_id integer,
  in item_id integer)
{
  declare owner_id integer;
  declare name, mail, title, comment any;

  owner_id := ENEWS.WA.domain_owner_id (domain_id);
  name := ENEWS.WA.account_name(owner_id);
  mail := ENEWS.WA.account_mail(owner_id);

  select EFI_TITLE, EFI_DESCRIPTION into title, comment from ENEWS.WA.FEED_ITEM where EFI_ID = item_id;
  insert into ENEWS.WA.FEED_ITEM_COMMENT (EFIC_PARENT_ID, EFIC_DOMAIN_ID, EFIC_ITEM_ID, EFIC_TITLE, EFIC_COMMENT, EFIC_U_NAME, EFIC_U_MAIL, EFIC_LAST_UPDATE)
    values (null, domain_id, item_id, title, comment, name, mail, now ());
  return identity_value ();
}
;

-----------------------------------------------------------------------------------------
--
create procedure ENEWS.WA.nntp_update_item (
  in domain_id integer,
  in item_id integer)
{
  declare grp, ngnext integer;
  declare domainName, rfc_id varchar;

  domainName := ENEWS.WA.domain_name(domain_id);
  select NG_GROUP, NG_NEXT_NUM into grp, ngnext from DB..NEWS_GROUPS where NG_NAME = domainName;
  select EFIC_RFC_ID into rfc_id from ENEWS.WA.FEED_ITEM_COMMENT where EFIC_DOMAIN_ID = domain_id and EFIC_ITEM_ID = item_id and EFIC_PARENT_ID is null;
  if (exists (select 1 from DB.DBA.NEWS_MULTI_MSG where NM_KEY_ID = rfc_id and NM_GROUP = grp))
    return;

  if (ngnext < 1)
    ngnext := 1;

  for (select EFIC_RFC_ID as rfc_id from ENEWS.WA.FEED_ITEM_COMMENT where EFIC_DOMAIN_ID = domain_id and EFIC_ITEM_ID = item_id) do {
	  insert soft DB.DBA.NEWS_MULTI_MSG (NM_KEY_ID, NM_GROUP, NM_NUM_GROUP) values (rfc_id, grp, ngnext);
	  ngnext := ngnext + 1;
  }

  set triggers off;
  update DB.DBA.NEWS_GROUPS set NG_NEXT_NUM = ngnext + 1 where NG_NAME = domainName;
  DB.DBA.ns_up_num (grp);
  set triggers on;
}
;

-----------------------------------------------------------------------------------------
--
create procedure ENEWS.WA.nntp_update (
  in domain_id integer,
  in oInstance varchar,
  in oConversation integer,
  in nConversation integer)
{
  declare nntpGroup integer;
  declare nInstance, nDescription varchar;

  if (isnull(nConversation))
    goto _update;

  if (nConversation = 0 and oConversation = 0)
    return;

  if (isnull(oInstance))
    oInstance := ENEWS.WA.domain_name(domain_id);
  nInstance := ENEWS.WA.domain_name(domain_id);

  if (oConversation = 1 and nConversation = 0) {
    nntpGroup := (select NG_GROUP from DB..NEWS_GROUPS where NG_NAME = oInstance);
    delete from DB.DBA.NEWS_MULTI_MSG where NM_GROUP = nntpGroup;
    delete from DB.DBA.NEWS_GROUPS where NG_NAME = oInstance;
    return;
  }

  nDescription := ENEWS.WA.domain_description(domain_id);
  if (oConversation = 0 and nConversation = 1) {
    declare exit handler for sqlstate '*' { return; };

    insert into DB.DBA.NEWS_GROUPS (NG_NEXT_NUM, NG_NAME, NG_DESC, NG_SERVER, NG_POST, NG_UP_TIME, NG_CREAT, NG_UP_INT, NG_PASS, NG_UP_MESS, NG_NUM, NG_FIRST, NG_LAST, NG_LAST_OUT, NG_CLEAR_INT, NG_TYPE)
      values (0, nInstance, nDescription, null, 1, now(), now(), 30, 0, 0, 0, 0, 0, 0, 120, 'OFM');
    return;
  }

_update:
  update DB.DBA.NEWS_GROUPS
     set NG_POST = 1,
         NG_NAME = nInstance,
         NG_DESC = nDescription
   where NG_NAME = oInstance;
}
;

-----------------------------------------------------------------------------------------
--
create procedure ENEWS.WA.nntp_fill (
  in domain_id integer)
{
  declare grp, ngnext integer;
  declare domainName varchar;

  for (select EFI_ID from ENEWS.WA.FEED_ITEM, ENEWS.WA.FEED_DOMAIN where EFI_FEED_ID = EFD_FEED_ID and EFD_DOMAIN_ID = domain_id) do
    if (not exists (select 1 from ENEWS.WA.FEED_ITEM_COMMENT where EFIC_DOMAIN_ID = domain_id and EFIC_ITEM_ID = EFI_ID and EFIC_PARENT_ID is null))
      ENEWS.WA.nntp_root (domain_id, EFI_ID);

  domainName := ENEWS.WA.domain_name(domain_id);
  select NG_GROUP, NG_NEXT_NUM into grp, ngnext from DB..NEWS_GROUPS where NG_NAME = domainName;
  if (ngnext < 1)
    ngnext := 1;

  for (select EFIC_RFC_ID as rfc_id from ENEWS.WA.FEED_ITEM_COMMENT where EFIC_DOMAIN_ID = domain_id) do {
	  insert soft DB.DBA.NEWS_MULTI_MSG (NM_KEY_ID, NM_GROUP, NM_NUM_GROUP) values (rfc_id, grp, ngnext);
	  ngnext := ngnext + 1;
  }

  set triggers off;
  update DB.DBA.NEWS_GROUPS set NG_NEXT_NUM = ngnext + 1 where NG_NAME = domainName;
  DB.DBA.ns_up_num (grp);
  set triggers on;
}
;

-----------------------------------------------------------------------------------------
--
create procedure ENEWS.WA.mail_address_split (
  in author any,
  out person any,
  out email any)
{
  declare pos int;

  person := '';
  pos := strchr (author, '<');
  if (pos is not NULL) {
    person := "LEFT" (author, pos);
    email := subseq (author, pos, length (author));
    email := replace (email, '<', '');
    email := replace (email, '>', '');
    person := trim (replace (person, '"', ''));
  } else {
    pos := strchr (author, '(');
    if (pos is not NULL) {
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
create procedure ENEWS.WA.nntp_decode_subject (
  inout str varchar)
{
  declare match varchar;
  declare inx int;

  inx := 50;

  str := replace (str, '\t', '');

  match := regexp_match ('=\\?[^\\?]+\\?[A-Z]\\?[^\\?]+\\?=', str);
  while (match is not null and inx > 0) {
    declare enc, ty, dat, tmp, cp, dec any;

    cp := match;
    tmp := regexp_match ('^=\\?[^\\?]+\\?[A-Z]\\?', match);

    match := substring (match, length (tmp)+1, length (match) - length (tmp) - 2);

    enc := regexp_match ('=\\?[^\\?]+\\?', tmp);

    tmp := replace (tmp, enc, '');

    enc := trim (enc, '?=');
    ty := trim (tmp, '?');

    if (ty = 'B') {
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
create procedure ENEWS.WA.nntp_process_parts (
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
      ENEWS.WA.nntp_process_parts (parts[2][i], body, amime, result, any_part);

  return 0;
}
;

-----------------------------------------------------------------------------------------
--
DB.DBA.NNTP_NEWS_MSG_ADD (
'OFM',
'select
   \'OFM\',
   EFIC_RFC_ID,
   EFIC_RFC_REFERENCES,
   0,    -- NM_READ
   null,
   EFIC_LAST_UPDATE,
   0,    -- NM_STAT
   null, -- NM_TRY_POST
   0,    -- NM_DELETED
   ENEWS.WA.make_post_rfc_msg (EFIC_RFC_HEADER, EFIC_COMMENT, 1), -- NM_HEAD
   ENEWS.WA.make_post_rfc_msg (EFIC_RFC_HEADER, EFIC_COMMENT),
   EFIC_ID
 from ENEWS.WA.FEED_ITEM_COMMENT'
)
;

-----------------------------------------------------------------------------------------
--
create procedure DB.DBA.OFM_NEWS_MSG_I (
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
  if (isnull(N_NM_REF) and isnull(uid))
    signal ('CONVA', 'The post cannot be done via news client, this requires authentication.');


  tree := deserialize (N_NM_HEAD);
  head := tree [0];
  contentType := get_keyword_ucase ('Content-Type', head, 'text/plain');
  cset  := upper (get_keyword_ucase ('charset', head));
  author :=  get_keyword_ucase ('From', head, 'nobody@unknown');
  subject :=  get_keyword_ucase ('Subject', head);

  if (not isnull(subject))
    ENEWS.WA.nntp_decode_subject (subject);

  if (contentType like 'text/%') {
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
    if (cset is not null and cset <> 'UTF-8')	{
	    declare exit handler for sqlstate '2C000' { goto next_1;};
	    content := charset_recode (content, cset, 'UTF-8');
	  }
  next_1:;
    if (contentType = 'text/plain')
	    content := '<pre>' || content || '</pre>';
  } else if (contentType like 'multipart/%') {
    declare res, best_cnt any;

    declare exit handler for sqlstate '*' {	signal ('CONVX', __SQL_MESSAGE);};

    ENEWS.WA.nntp_process_parts (tree, N_NM_BODY, vector ('text/%'), res, 1);

    best_cnt := null;
    content := null;
    foreach (any elm in res) do {
	    if (elm[1] = 'text/html' and (content is null or best_cnt = 'text/plain')) {
	      best_cnt := 'text/html';
	      content := elm[2];
	      if (elm[4] = 'quoted-printable') {
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
    if (length (cset) and cset <> 'UTF-8') {
	    declare exit handler for sqlstate '2C000' { goto next_2;};
	    content := charset_recode (content, cset, 'UTF-8');
	  }
  next_2:;
  } else
    signal ('CONVX', sprintf ('The content type [%s] is not supported', contentType));

  rfc_header := '';
  for (declare i int, i := 0; i < length (head); i := i + 2) {
    if (lower (head[i]) <> 'content-type' and lower (head[i]) <> 'mime-version' and lower (head[i]) <> 'boundary'  and lower (head[i]) <> 'subject')
	    rfc_header := rfc_header || head[i] ||': ' || head[i + 1]||'\r\n';
  }
  rfc_header := ENEWS.WA.make_mail_subject (subject) || rfc_header || 'Content-Type: text/html; charset=UTF-8\r\n\r\n';

  rfc_references := N_NM_REF;

  if (not isnull(N_NM_REF)) {
    declare exit handler for not found { signal ('CONV1', 'No such article.');};

    parent_id := null;
    refs := split_and_decode (N_NM_REF, 0, '\0\0 ');
    if (length (refs))
	    N_NM_REF := refs[length (refs) - 1];

    select EFIC_ID, EFIC_DOMAIN_ID, EFIC_ITEM_ID, EFIC_TITLE
      into parent_id, domain_id, item_id, title
      from ENEWS.WA.FEED_ITEM_COMMENT
     where EFIC_RFC_ID = N_NM_REF;

    if (isnull(subject))
	    subject := 'Re: '|| title;

    ENEWS.WA.mail_address_split (author, name, mail);

    insert into ENEWS.WA.FEED_ITEM_COMMENT (EFIC_PARENT_ID, EFIC_DOMAIN_ID, EFIC_ITEM_ID, EFIC_TITLE, EFIC_COMMENT, EFIC_U_NAME, EFIC_U_MAIL, EFIC_LAST_UPDATE, EFIC_RFC_ID, EFIC_RFC_HEADER, EFIC_RFC_REFERENCES)
       values (parent_id, domain_id, item_id, subject, content, name, mail, N_NM_REC_DATE, N_NM_ID, rfc_header, rfc_references);
  }
}
;

-----------------------------------------------------------------------------------------
--
create procedure DB.DBA.OFM_NEWS_MSG_U (
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
create procedure DB.DBA.OFM_NEWS_MSG_D (
  inout O_NM_ID any)
{
  signal ('CONV3', 'Delete of a OFM comment is not allowed');
}
;

-----------------------------------------------------------------------------------------
--
grant execute on ENEWS.WA.host_url to public;

xpf_extension ('http://www.openlinksw.com/feeds/:getHost', 'ENEWS.WA.host_url');