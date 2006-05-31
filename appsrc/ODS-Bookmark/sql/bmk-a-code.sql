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
create procedure BMK.WA.validate_request(
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
  if (isnull(i)) BMK.WA.http_response(400);       -- Bad Request (can't happen!)
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
    if (isnull(i) or (i > 0)) BMK.WA.http_response(400);                 -- Bad Request
    i := strstr(S,'.'); if (isnull(i)) BMK.WA.http_response(400);        -- Bad Request
    aset(aResult,2,vector(atoi(subseq(S,5,i)),atoi(subseq(S,i+1))));
  }
  if (aResult[2][0] <> 1) BMK.WA.http_response(505);                     -- HTTP Version Not Supported
  if (aResult[2][1] < pMinVersion) BMK.WA.http_response(505);            -- HTTP Version Not Supported
  if ((pMinVersion > 0) and aResult[1] = '') BMK.WA.http_response(400);  -- Host field required for HTTP/1.1

  --check "File or Directory";
  P := BMK.WA.mount_point();
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
        BMK.WA.http_response(404);
      j := j - 1;
    }
    S := concat(S,'bookmarks.vspx');
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
    BMK.WA.http_response(404);
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
create procedure BMK.WA.mount_point(
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
create procedure BMK.WA.http_response(in pError integer,in pParams varchar := '')
{
  signal('90001',sprintf('<Response Status="%d" MountPoint="%s">%s</Response>',pError,BMK.WA.mount_point(),pParams));
}
;

-------------------------------------------------------------------------------
--
-- Session Functions
--
-------------------------------------------------------------------------------
create procedure BMK.WA.session_restore(
  inout request any,
  inout params any,
  inout lines any)
{
  declare exit handler for sqlstate '*' { goto _end; };

  declare
    domain_id integer;
  declare
    sSid varchar;
  declare
    options any;


  options := http_map_get('options');
  if (not is_empty_or_null(options))
    domain_id := get_keyword('domain', options);
  if (is_empty_or_null(domain_id))
    domain_id := cast(request[5] as integer);
  if (is_empty_or_null(domain_id))
    goto _end;

  sSid := get_keyword('sid', params, '');
  for (select U.U_ID,
              U.U_NAME,
              U.U_FULL_NAME
         from DB.DBA.VSPX_SESSION S,
              WS.WS.SYS_DAV_USER U
        where S.VS_REALM = 'wa'
          and S.VS_SID   = sSid
          and S.VS_UID   = U.U_NAME) do
  {
    return vector('sid',        sSid,
                  'domain_id',  domain_id,
                  'user_id',    U_ID,
                  'user_name',  BMK.WA.user_name(U_NAME, U_FULL_NAME),
                  'user_role',  BMK.WA.access_role(domain_id, U_ID)
                 );
  };
_end:
  domain_id := -1;
  return vector('domain_id', domain_id,
                'user_id',   -1,
                'user_name', 'Public User',
                'user_role', 'public'
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
create procedure BMK.WA.check_grants(in domain_id integer, in user_id integer, in role_name varchar)
{
  whenever not found goto _end;

  if (BMK.WA.check_admin(user_id))
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
create procedure BMK.WA.check_grants2(in role_name varchar, in page_name varchar)
{
  return 1;
}
;

-------------------------------------------------------------------------------
--
create procedure BMK.WA.access_role(in domain_id integer, in user_id integer)
{
  whenever not found goto _end;

  if (BMK.WA.check_admin(user_id))
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
  declare path, aPath any;

  path := http_path ();
  aPath := split_and_decode (path, 0, '\0\0/');
  return aPath [length (aPath) - 1];
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
  home := home || 'BM/';
  DB.DBA.DAV_MAKE_DIR (home, account_id, null, read_perm);

  --path := home || 'channels/';
  --DB.DBA.DAV_MAKE_DIR (path, account_id, null, read_perm);
  --update WS.WS.SYS_DAV_COL set COL_DET = 'News3' where COL_ID = DAV_SEARCH_ID (path, 'C');

  home := home || BMK.WA.domain_gems_name(domain_id) || '/';
  DB.DBA.DAV_MAKE_DIR (home, account_id, null, read_perm);

  -- RSS 2.0
  path := home || 'BM.rss';
  DB.DBA.DAV_DELETE_INT (path, 1, null, null, 0);

  content := BMK.WA.export_rss_sqlx (domain_id, account_id);
  DB.DBA.DAV_RES_UPLOAD_STRSES_INT (path, content, 'text/xml', exec_perm, http_dav_uid (), http_dav_uid () + 1, null, null, 0);
  DB.DBA.DAV_PROP_SET_INT (path, 'xml-template', 'execute', 'dav', null, 0, 0, 1);
  DB.DBA.DAV_PROP_SET_INT (path, 'xml-sql-encoding', 'utf-8', 'dav', null, 0, 0, 1);
  DB.DBA.DAV_PROP_SET_INT (path, 'xml-sql-description', 'RSS based XML document generated by OpenLink Feed Manager', 'dav', null, 0, 0, 1);

  -- ATOM
  path := home || 'BM.atom';
  DB.DBA.DAV_DELETE_INT (path, 1, null, null, 0);

  content := BMK.WA.export_atom_sqlx (domain_id, account_id);
  DB.DBA.DAV_RES_UPLOAD_STRSES_INT (path, content, 'text/xml', exec_perm, http_dav_uid (), http_dav_uid () + 1, null, null, 0);
  DB.DBA.DAV_PROP_SET_INT (path, 'xml-template', 'execute', 'dav', null, 0, 0, 1);
  DB.DBA.DAV_PROP_SET_INT (path, 'xml-sql-encoding', 'utf-8', 'dav', null, 0, 0, 1);
  DB.DBA.DAV_PROP_SET_INT (path, 'xml-sql-description', 'ATOM based XML document generated by OpenLink Feed Manager', 'dav', null, 0, 0, 1);

  -- RDF
  path := home || 'BM.rdf';
  DB.DBA.DAV_DELETE_INT (path, 1, null, null, 0);

  content := BMK.WA.export_rdf_sqlx (domain_id, account_id);
  DB.DBA.DAV_RES_UPLOAD_STRSES_INT (path, content, 'text/xml', exec_perm, http_dav_uid (), http_dav_uid () + 1, null, null, 0);
  DB.DBA.DAV_PROP_SET_INT (path, 'xml-template', 'execute', 'dav', null, 0, 0, 1);
  DB.DBA.DAV_PROP_SET_INT (path, 'xml-sql-encoding', 'utf-8', 'dav', null, 0, 0, 1);
  DB.DBA.DAV_PROP_SET_INT (path, 'xml-sql-description', 'RDF based XML document generated by OpenLink Feed Manager', 'dav', null, 0, 0, 1);

  -- OCS
  path := home || 'BM.ocs';
  DB.DBA.DAV_DELETE_INT (path, 1, null, null, 0);

  content := BMK.WA.export_ocs_sqlx (domain_id, account_id);
  DB.DBA.DAV_RES_UPLOAD_STRSES_INT (path, content, 'text/xml', exec_perm, http_dav_uid (), http_dav_uid () + 1, null, null, 0);
  DB.DBA.DAV_PROP_SET_INT (path, 'xml-template', 'execute', 'dav', null, 0, 0, 1);
  DB.DBA.DAV_PROP_SET_INT (path, 'xml-sql-encoding', 'utf-8', 'dav', null, 0, 0, 1);
  DB.DBA.DAV_PROP_SET_INT (path, 'xml-sql-description', 'OPML based XML document generated by OpenLink Feed Manager', 'dav', null, 0, 0, 1);

  -- OPML
  path := home || 'BM.opml';
  DB.DBA.DAV_DELETE_INT (path, 1, null, null, 0);

  content := BMK.WA.export_opml_sqlx (domain_id, account_id);
  DB.DBA.DAV_RES_UPLOAD_STRSES_INT (path, content, 'text/xml', exec_perm, http_dav_uid (), http_dav_uid () + 1, null, null, 0);
  DB.DBA.DAV_PROP_SET_INT (path, 'xml-template', 'execute', 'dav', null, 0, 0, 1);
  DB.DBA.DAV_PROP_SET_INT (path, 'xml-sql-encoding', 'utf-8', 'dav', null, 0, 0, 1);
  DB.DBA.DAV_PROP_SET_INT (path, 'xml-sql-description', 'OPML based XML document generated by OpenLink Feed Manager', 'dav', null, 0, 0, 1);

  -- FOAF
  path := home || 'BM.foaf';
  DB.DBA.DAV_DELETE_INT (path, 1, null, null, 0);

  return;
}
;

-------------------------------------------------------------------------------
--
create procedure BMK.WA.domain_gems_delete(
  in domain_id integer,
  in account_id integer,
  in appName varchar := 'BM',
  in appGems varchar := null)
{
  declare tmp, home, path varchar;

  home := BMK.WA.dav_home(account_id);
  if (isnull(home))
    return;

  if (isnull(appGems))
    appGems := BMK.WA.domain_gems_name(domain_id);
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
  path := home || appName || '.foaf';
  DB.DBA.DAV_DELETE_INT (path, 1, null, null, 0);

  declare auth_uid, auth_pwd varchar;

  auth_uid := coalesce((SELECT U_NAME FROM WS.WS.SYS_DAV_USER WHERE U_ID = account_id), '');
  auth_pwd := coalesce((SELECT U_PWD FROM WS.WS.SYS_DAV_USER WHERE U_ID = account_id), '');
  if (auth_pwd[0] = 0)
    auth_pwd := pwd_magic_calc(auth_uid, auth_pwd, 1);

  tmp := DB.DBA.DAV_DIR_LIST (home, 0, auth_uid, auth_pwd);
  if (not isinteger(tmp) and not length(tmp))
    DB.DBA.DAV_DELETE_INT (home, 1, null, null, 0);

  return 1;
}
;

-------------------------------------------------------------------------------
--
create procedure BMK.WA.domain_update (
  inout domain_id integer,
  inout account_id integer)
{
  BMK.WA.domain_gems_delete (domain_id, account_id, 'BM');
  BMK.WA.domain_gems_delete (domain_id, account_id, 'BM', cast(domain_id as varchar));
  BMK.WA.domain_gems_create (domain_id, account_id);

  BMK.WA.sfolder_create(domain_id, 'All bookmarks', '<settings/>', 1);

  return;
}
;

-------------------------------------------------------------------------------
--
create procedure BMK.WA.domain_delete (
  in domain_id integer)
{
  DECLARE CONTINUE HANDLER FOR SQLSTATE '*' {return 0; };

  BMK.WA.folder_delete_all(domain_id);
  DELETE FROM BMK.WA.SFOLDER         WHERE SF_DOMAIN_ID = domain_id;
  DELETE FROM BMK.WA.BOOKMARK_DOMAIN WHERE BD_DOMAIN_ID = domain_id;

  for (select WAM_USER from DB.DBA.WA_MEMBER, DB.DBA.WA_INSTANCE where WAI_TYPE_NAME = 'Bookmark' and WAI_ID = domain_id) do
    BMK.WA.account_delete (domain_id, WAM_USER);

  VHOST_REMOVE(lpath => concat('/bookmark/', cast(domain_id as varchar)));
  return 1;
}
;

-------------------------------------------------------------------------------
--
create procedure BMK.WA.domain_name (
  in domain_id integer)
{
  return coalesce((select WAI_NAME from DB.DBA.WA_INSTANCE where WAI_ID = domain_id), 'OFM Instance');
}
;

-------------------------------------------------------------------------------
--
create procedure BMK.WA.domain_gems_name (
  in domain_id integer)
{
  return concat(BMK.WA.domain_name(domain_id), '_Gems');
}
;

-------------------------------------------------------------------------------
--
create procedure BMK.WA.domain_description (
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
	out auth_uid varchar,
	out auth_pwd varchar)
{
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
  DECLARE CONTINUE HANDLER FOR SQLSTATE '*' {return 0; };

  DELETE FROM BMK.WA.SETTINGS WHERE S_ACCOUNT_ID = account_id;
  BMK.WA.domain_gems_delete(domain_id, account_id);

  return 1;
}
;

-------------------------------------------------------------------------------
--
create procedure BMK.WA.user_name(
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
-- Bookmarks
--
-------------------------------------------------------------------------------
create procedure BMK.WA.bookmark_update
(
  in domain_id integer,
  in uri any,
  in name any,
  in description any)
{
  declare bookmark_id integer;

  bookmark_id := (select B_ID from BMK.WA.BOOKMARK where B_URI = uri);
  if (is_empty_or_null(bookmark_id)) {
    insert into BMK.WA.BOOKMARK (B_URI, B_NAME, B_DESCRIPTION)
      values (uri, name, description);
    bookmark_id := identity_value ();
  }
  if (not exists(select 1 from BMK.WA.BOOKMARK_DOMAIN where BD_DOMAIN_ID = domain_id and BD_BOOKMARK_ID = bookmark_id)) {
    insert into BMK.WA.BOOKMARK_DOMAIN (BD_DOMAIN_ID, BD_BOOKMARK_ID, BD_NAME, BD_DESCRIPTION, BD_LAST_UPDATE)
      values (domain_id, bookmark_id, name, description, now());
  } else {
    update BMK.WA.BOOKMARK_DOMAIN
       set BD_NAME = name,
           BD_DESCRIPTION = description,
           BD_LAST_UPDATE = now()
     where BD_DOMAIN_ID = domain_id
       and BD_BOOKMARK_ID = bookmark_id;
  }
  return bookmark_id;
}
;

-------------------------------------------------------------------------------
--
create procedure BMK.WA.bookmark_delete(
  in domain_id integer,
  in id integer)
{
  delete from BMK.WA.BOOKMARK_DOMAIN where BD_DOMAIN_ID = domain_id and BD_ID = id;
}
;

-------------------------------------------------------------------------------
--
create procedure BMK.WA.bookmark_description(
  in id integer)
{
  return '';
}
;

-------------------------------------------------------------------------------
--
create procedure BMK.WA.bookmark_parent(
  in domain_id integer,
  in bookmark_id integer,
  in folder_id integer)
{
  if (is_empty_or_null(folder_id))
    folder_id := null;
  update BMK.WA.BOOKMARK_DOMAIN
     set BD_FOLDER_ID = folder_id
   where BD_DOMAIN_ID = domain_id
     and BD_BOOKMARK_ID = bookmark_id;
}
;

-------------------------------------------------------------------------------
--
create procedure BMK.WA.bookmark_import(
  in domain_id integer,
  in folder_id integer,
  in S any)
{
  declare
    V any;

  if (isnull(strcasestr(S, '<!doctype netscape-bookmark-file-1>')))
    return;
  S := replace(S, '<p>', '');
  S := replace(S, '<HR>', '');
  S := replace(S, '<DD>', '');
  S := replace(S, 'FOLDED', '');
  S := replace(S, '  ', ' ');
  S := replace(S, '&', '&amp;');
  V := xtree_doc(S, 2);
  V := xpath_eval('//dl', V);
  if (V is null)
    return;
  --dbg_obj_print(V);
  BMK..bookmark_import_tmp(domain_id, folder_id, xml_cut(V));
}
;

-----------------------------------------------------
--
create procedure BMK.WA.bookmark_import_tmp(
  in domain_id integer,
  in folder_id integer,
  in V any)
{
  declare tmp, T, Q any;
  declare N integer;

  if (V is null)
    return;
  N := 1;
  while (1) {
    T := xpath_eval('/dl/dt/a/text()', V, N);
    if (T is null)
      goto _a;
    Q := xpath_eval('/dl/dt/a/@href', V, N);
    tmp := BMK.WA.bookmark_update(domain_id, cast(Q as VARCHAR), cast(T as VARCHAR), null);
    BMK.WA.bookmark_parent(domain_id, tmp, folder_id);
    N := N + 1;
  }
_a:
  N := 1;
  while (1) {
    T := xpath_eval('/dl/dt/h3', V, N);
    if (T is null)
      goto _h3;
    tmp := BMK.WA.folder_create2(domain_id, folder_id, cast(T as VARCHAR));
    T := xpath_eval('/dl/dt/dl', V, N);
    if (not (T is null))
      BMK.WA.bookmark_import_tmp(domain_id, tmp, xml_cut(T));
    N := N + 1;
  }
_h3:
  return;
};

-------------------------------------------------------------------------------
--
CREATE PROCEDURE BMK.WA.bookmark_export(
  in domain_id integer,
  in folder_id integer)
{
  declare retValue any;

  retValue := string_output ();
  http(sprintf('<root name="Bookmarks" id="f#%d">', coalesce(folder_id, 0)), retValue);
  BMK.WA.bookmark_export_tmp(domain_id, folder_id, retValue);
  http('</root>', retValue);

  return string_output_string (retValue);
};

-------------------------------------------------------------------------------
--
CREATE PROCEDURE BMK.WA.bookmark_export_tmp(
  in domain_id integer,
  in folder_id any,
  inout retValue any)
{
  declare id, type any;

  for (select a.*, b.B_URI from BMK.WA.BOOKMARK_DOMAIN a, BMK.WA.BOOKMARK b where a.BD_BOOKMARK_ID = b.B_ID and a.BD_DOMAIN_ID = domain_id and coalesce(a.BD_FOLDER_ID, 0) = coalesce(folder_id, 0) order by a.BD_NAME) do {
    http (sprintf('<bookmark name="%V" uri="%V" id="f#%d" />', BD_NAME, B_URI, BD_ID), retValue);
  }
  for (select F_ID, F_NAME from BMK.WA.FOLDER where F_DOMAIN_ID = domain_id and coalesce(F_PARENT_ID, 0) = coalesce(folder_id, 0) order by 2) do {
    http (sprintf('<folder name="%V" id="f#%d">', F_NAME, F_ID), retValue);
    BMK.WA.bookmark_export_tmp(domain_id, F_ID, retValue);
    http ('</folder>', retValue);
  }
};

-------------------------------------------------------------------------------
--
-- Tags
--
-------------------------------------------------------------------------------
create procedure BMK.WA.bookmark_tags(
  inout domain_id integer,
  inout account_id integer,
  inout bookmark_id integer,
  inout tags any)
{
  if (not exists (select 1 from BMK.WA.BOOKMARK_DATA where BD_MODE = 0 and BD_OBJECT_ID = domain_id and BD_BOOKMARK_ID = bookmark_id)) {
    insert into BMK.WA.BOOKMARK_DATA(BD_MODE, BD_OBJECT_ID, BD_BOOKMARK_ID, BD_TAGS, BD_LAST_UPDATE)
      values(0, domain_id, bookmark_id, tags, now());
  } else {
    if (BMK.WA.check_grants(domain_id, account_id, 'owner'))
      update BMK.WA.BOOKMARK_DATA
         set BD_TAGS = tags,
             BD_LAST_UPDATE = now()
       where BD_MODE = 0
         and BD_OBJECT_ID = domain_id
         and BD_BOOKMARK_ID = bookmark_id;
  }
  if (not exists (select 1 from BMK.WA.BOOKMARK_DATA where BD_MODE = 1 and BD_OBJECT_ID = account_id and BD_BOOKMARK_ID = bookmark_id)) {
    insert into BMK.WA.BOOKMARK_DATA(BD_MODE, BD_OBJECT_ID, BD_BOOKMARK_ID, BD_TAGS)
      values(1, account_id, bookmark_id, tags);
  } else {
    update BMK.WA.BOOKMARK_DATA
       set BD_TAGS = tags,
           BD_LAST_UPDATE = now()
     where BD_MODE = 1
       and BD_OBJECT_ID = account_id
       and BD_BOOKMARK_ID = bookmark_id;
  }
}
;

-------------------------------------------------------------------------------
--
create procedure BMK.WA.tags_select(
  inout domain_id integer,
  inout account_id integer,
  inout bookmark_id integer)
{
  declare tags varchar;

  tags := (select BD_TAGS from BMK.WA.BOOKMARK_DATA where BD_MODE = 1 and BD_OBJECT_ID = account_id and BD_BOOKMARK_ID = bookmark_id);
  if (isnull(tags))
    tags := (select BD_TAGS from BMK.WA.BOOKMARK_DATA where BD_MODE = 0 and BD_OBJECT_ID = domain_id and BD_BOOKMARK_ID = bookmark_id);
  return tags;
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
  if (not is_empty_or_null(folder_name)) {
    aPath := split_and_decode(trim(folder_name, '/'),0,'\0\0/');
    for (i := 0; i < length(aPath); i := i + 1) {
      if (i = 0) {
        if (not exists (select 1 from BMK.WA.FOLDER where F_DOMAIN_ID = domain_id and F_NAME = aPath[i] and F_PARENT_ID is null))
          insert into BMK.WA.FOLDER (F_DOMAIN_ID, F_NAME) values (domain_id, aPath[i]);
        folder_id := (select F_ID from BMK.WA.FOLDER where F_DOMAIN_ID = domain_id and F_NAME = aPath[i] and F_PARENT_ID is null);
      } else {
        if (not exists (select 1 from BMK.WA.FOLDER where F_DOMAIN_ID = domain_id and F_NAME = aPath[i] and F_PARENT_ID = folder_id))
          insert into BMK.WA.FOLDER (F_DOMAIN_ID, F_PARENT_ID, F_NAME) values (domain_id, folder_id, aPath[i]);
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
  if (folder_name <> '') {
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

  if (not exists (select 1 from BMK.WA.FOLDER where F_DOMAIN_ID = domain_id and F_NAME = folder_name and coalesce(F_PARENT_ID, 0) = coalesce(parent_id, 0)))
    insert into BMK.WA.FOLDER (F_DOMAIN_ID, F_PARENT_ID, F_NAME) values (domain_id, parent_id, folder_name);
  return (select F_ID from BMK.WA.FOLDER where F_DOMAIN_ID = domain_id and F_NAME = folder_name and coalesce(F_PARENT_ID, 0) = coalesce(parent_id, 0));
}
;

-------------------------------------------------------------------------------
--
create procedure BMK.WA.folder_parent(
  in domain_id integer,
  in folder_id integer,
  in parent_id integer)
{
  update BMK.WA.FOLDER set F_PARENT_ID = parent_id where F_DOMAIN_ID = domain_id and F_ID = folder_id;
}
;

-------------------------------------------------------------------------------
--
create procedure BMK.WA.folder_delete(
  in domain_id integer,
  in folder_id integer)
{
  for (select F_ID from BMK.WA.FOLDER where F_DOMAIN_ID = domain_id and F_PARENT_ID = folder_id) do
    BMK.WA.folder_delete(domain_id, F_ID);

  delete from BMK.WA.BOOKMARK_DOMAIN where BD_DOMAIN_ID = domain_id and BD_FOLDER_ID = folder_id;;
  delete from BMK.WA.FOLDER where F_DOMAIN_ID = domain_id and F_ID = folder_id;
}
;

-------------------------------------------------------------------------------
--
create procedure BMK.WA.folder_delete_all(
  in domain_id integer)
{
  for (select F_ID from BMK.WA.FOLDER where F_DOMAIN_ID = domain_id and F_PARENT_ID is null) do
    BMK.WA.folder_delete(domain_id, F_ID);
}
;

-------------------------------------------------------------------------------
--
create procedure BMK.WA.folder_path(
  in domain_id integer,
  in folder_id integer)
{
  declare path, name varchar;
  declare parent_id integer;

  path := '/';
  whenever not found goto nf;
  while (folder_id > 0) {
    select F_NAME, F_PARENT_ID into name, parent_id from BMK.WA.FOLDER where F_DOMAIN_ID = domain_id and F_ID = folder_id;
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
create procedure BMK.WA.folder_path2(
  in domain_id integer,
  in folder_id integer)
{
  declare path varchar;
  declare aPath varchar;

  path := BMK.WA.folder_path(domain_id, folder_id);
  aPath := split_and_decode(path,0,'\0\0/');
  return concat(repeat('~', length(aPath)-1), aPath[length(aPath)-1]);
}
;

-------------------------------------------------------------------------------
--
create procedure BMK.WA.folder_level(
  in path varchar)
{
  return (length(split_and_decode(path,0,'\0\0/')) - 1);
}
;

-------------------------------------------------------------------------------
--
create procedure BMK.WA.folder_check_name(
  in folder_name varchar,
  in is_path integer := 0)
{
  if (is_path) {
    declare i integer;
    declare aPath any;

    aPath := split_and_decode(trim(folder_name, '/'),0,'\0\0/');
    for (i := 0; i < length(aPath); i := i + 1)
      if (not BMK.WA.validate('folder', aPath[i]))
        return 0;
    return 1;
  } else {
    return BMK.WA.validate('folder', folder_name);
  }
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

  if (isnull(parent_id)) {
    retValue := coalesce((select F_ID from BMK.WA.FOLDER where F_DOMAIN_ID=domain_id and F_PARENT_ID is null and F_NAME=name), 0);
  } else {
    retValue := coalesce((select F_ID from BMK.WA.FOLDER where F_DOMAIN_ID=domain_id and F_PARENT_ID=parent_id and F_NAME=name), 0);
  }
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
  inout data varchar,
  in mode varchar := 'text',
  in maxRows varchar := '')
{
  declare S, tmp, where2, delimiter2 varchar;

  where2 := ' \n ';
  delimiter2 := '\n and ';

  if (is_empty_or_null(BMK.WA.xml_get('tags', data))) {
    S :=
      'select                              \n' ||
      '  distinct <MAX>                    \n' ||
      '  a.BD_ID                    _ID,   \n' ||
      '  sprintf(\'b#%d\', a.BD_ID) _NODE, \n' ||
      '  a.BD_NAME                  _NAME, \n' ||
      '  b.B_URI                    _URI,  \n' ||
      '  a.BD_LAST_UPDATE           _LAST_UPDATE \n' ||
      'from BMK.WA.BOOKMARK_DOMAIN a       \n' ||
      '       join BMK.WA.BOOKMARK b on b.B_ID = a.BD_BOOKMARK_ID \n' ||
      '         left join BMK.WA.BOOKMARK_DATA c on c.BD_MODE = 1 and c.BD_BOOKMARK_ID = b.B_ID and c.BD_OBJECT_ID = <ACCOUNT_ID> \n' ||
      'where a.BD_DOMAIN_ID = <DOMAIN_ID> <ITEM_DESCRIPTION> <WHERE> \n';
  } else {
    S :=
      'select                              \n' ||
      '  distinct <MAX>                    \n' ||
      '  a.BD_ID                    _ID,   \n' ||
      '  sprintf(\'b#%d\', a.BD_ID) _NODE, \n' ||
      '  a.BD_NAME                  _NAME, \n' ||
      '  b.B_URI                    _URI,  \n' ||
      '  a.BD_LAST_UPDATE           _LAST_UPDATE \n' ||
      'from                                \n' ||
      '  (select                           \n' ||
      '    BD_BOOKMARK_ID                  \n' ||
      '  from                              \n' ||
      '    BMK.WA.BOOKMARK_DATA            \n' ||
      '  where contains(BD_TAGS, \'[__lang "x-ViDoc"] <DOMAIN_TAGS>\') \n' ||
      '                                    \n' ||
      '  UNION                             \n' ||
      '                                    \n' ||
      '  select                            \n' ||
      '    BD_BOOKMARK_ID                  \n' ||
      '  from                              \n' ||
      '    BMK.WA.BOOKMARK_DATA            \n' ||
      '  where contains(BD_TAGS, \'[__lang "x-ViDoc"] <ACCOUNT_TAGS>\')) x \n' ||
      '    join BMK.WA.BOOKMARK_DOMAIN a on a.BD_BOOKMARK_ID = x.BD_BOOKMARK_ID <ITEM_DESCRIPTION> \n' ||
      '     join BMK.WA.BOOKMARK b on b.B_ID = a.BD_BOOKMARK_ID \n' ||
      'where a.BD_DOMAIN_ID = <DOMAIN_ID> <WHERE>\n';
  }

  tmp := BMK.WA.xml_get('keywords', data);
  if (not is_empty_or_null(tmp) and (mode = 'text')) {
    S := replace(S, '<ITEM_DESCRIPTION>', sprintf('and contains(a.BD_DESCRIPTION, \'[__lang "x-ViDoc"] %s\') \n', FTI_MAKE_SEARCH_STRING(tmp)));
  } else {
    tmp := BMK.WA.xml_get('expression', data);
    if (not is_empty_or_null(tmp))
      if (mode = 'text') {
        S := replace(S, '<ITEM_DESCRIPTION>', sprintf('and contains(a.BD_DESCRIPTION, \'[__lang "x-ViDoc"] %s\') \n', tmp));
      } else if (mode = 'xpath') {
        S := replace(S, '<ITEM_DESCRIPTION>', sprintf('and xpath_eval (\'%s\', a.BD_DESCRIPTION, 1) \n', replace(tmp, '''', '\\''')));
      } else if (mode = 'xquery') {
        S := replace(S, '<ITEM_DESCRIPTION>', sprintf('and xquery_eval (\'%s\', a.BD_DESCRIPTION) \n', replace(tmp, '''', '\\''')));
      }
  }

  tmp := BMK.WA.xml_get('tags', data);
  if (not is_empty_or_null(tmp)) {
    tmp := BMK.WA.tags2search(tmp);
    S := replace(S, '<TAGS>', tmp);
    S := replace(S, '<DOMAIN_TAGS>', sprintf('%s and "^R%s"', tmp, cast(domain_id as varchar)));
    S := replace(S, '<ACCOUNT_TAGS>', sprintf('%s and "^UID%s"', tmp, cast(account_id as varchar)));
  }

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
create procedure BMK.WA.sfolder_sql_where(
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
create procedure BMK.WA.sfolder_create(
  in domain_id integer,
  in name varchar,
  in data varchar,
  in test integer := 0)
{
  declare id varchar;

  if (test) {
    id := coalesce((select SF_ID from BMK.WA.SFOLDER where SF_DOMAIN_ID = domain_id and SF_NAME = name), '');
    if (id <> '')
      return id;
  }
  id := cast(sequence_next ('sfolder') as varchar);
  insert into BMK.WA.SFOLDER(SF_ID, SF_DOMAIN_ID, SF_NAME, SF_DATA)
    values(id, domain_id, name, data);
  return id;
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
create procedure BMK.WA.tag_prepare(
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
    S := concat(S, ' ', replace (replace (trim(lcase(tag)), ' ', '_'), '+', '_'));
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
create procedure BMK.WA.tags_agregator ()
{
  for (select WAI_ID, WAM_USER from DB.DBA.WA_MEMBER, DB.DBA.WA_INSTANCE where WAI_NAME = WAM_INST and WAI_TYPE_NAME = 'Bookmark') do
    BMK.WA.tags_refresh(WAI_ID, WAM_USER, 0);
}
;

-------------------------------------------------------------------------------
--
create procedure BMK.WA.tags_refresh (
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
    select T_LAST_UPDATE, T_COUNT into ts_last_update, ts_max from BMK.WA.TAGS where T_DOMAIN_ID = domain_id and T_ACCOUNT_ID = account_id and T_TAG = '';

_skip:
  tags_dict := dict_new();
  for (select
         x.BD_TAGS
       from
         (select
            coalesce(c.BD_TAGS, b.BD_TAGS) BD_TAGS
          from
            BMK.WA.BOOKMARK_DOMAIN a
              left join BMK.WA.BOOKMARK_DATA b on b.BD_BOOKMARK_ID = a.BD_BOOKMARK_ID and b.BD_MODE = 0 and b.BD_OBJECT_ID = domain_id
              left join BMK.WA.BOOKMARK_DATA c on c.BD_BOOKMARK_ID = a.BD_BOOKMARK_ID and c.BD_MODE = 1 and c.BD_OBJECT_ID = account_id
          where a.BD_DOMAIN_ID = domain_id
            and (ts_last_update is null or b.BD_LAST_UPDATE > ts_last_update)
            and (ts_last_update is null or c.BD_LAST_UPDATE > ts_last_update)) x) do
  {
    tags := split_and_decode (BD_TAGS, 0, '\0\0,');
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
      ts_count := coalesce((select T_COUNT from BMK.WA.TAGS where T_DOMAIN_ID = domain_id and T_ACCOUNT_ID = account_id and T_TAG = tags_vector[N][0]), 0);
      insert replacing BMK.WA.TAGS(T_DOMAIN_ID, T_ACCOUNT_ID, T_LAST_UPDATE, T_TAG, T_COUNT)
        values(domain_id, account_id, ts_last_update, tags_vector[N][0], tags_vector[N][1]+ts_count);
      if (ts_max < tags_vector[N][1]+ts_count)
        ts_max := tags_vector[N][1] + ts_count;
    }
  } else {
    delete from BMK.WA.TAGS where T_DOMAIN_ID = domain_id and T_ACCOUNT_ID = account_id;
    for (N := 1; N < length(tags_vector); N := N + 2) {
      insert into BMK.WA.TAGS(T_DOMAIN_ID, T_ACCOUNT_ID, T_LAST_UPDATE, T_TAG, T_COUNT)
        values(domain_id, account_id, ts_last_update, tags_vector[N][0], tags_vector[N][1]);
      if (ts_max < tags_vector[N][1])
        ts_max := tags_vector[N][1];
    }
  }
  insert replacing BMK.WA.TAGS(T_DOMAIN_ID, T_ACCOUNT_ID, T_LAST_UPDATE, T_TAG, T_COUNT)
    values(domain_id, account_id, ts_last_update, '', ts_max);

  return;
}
;

-------------------------------------------------------------------------------
--
create procedure BMK.WA.settings (
  inout account_id integer)
{
  return coalesce((select deserialize(blob_to_string(S_DATA))
                     from BMK.WA.SETTINGS
                    where S_ACCOUNT_ID = account_id), vector());
}
;

-------------------------------------------------------------------------------
--
create procedure BMK.WA.settings_chars (
  inout account_id integer)
{
  declare settings any;

  settings := BMK.WA.settings(account_id);
  return cast(get_keyword('chars', settings, '60') as integer);
}
;

-------------------------------------------------------------------------------
--
create procedure BMK.WA.settings_rows (
  inout account_id integer)
{
  declare settings any;

  settings := BMK.WA.settings(account_id);
  return cast(get_keyword('rows', settings, '10') as integer);
}
;

-------------------------------------------------------------------------------
--
create procedure BMK.WA.settings_atomVersion (
  inout account_id integer)
{
  declare settings any;

  settings := BMK.WA.settings(account_id);
  return get_keyword('atomVersion', settings, '0.3');
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

-------------------------------------------------------------------------------
--
create procedure BMK.WA.host_url ()
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
create procedure BMK.WA.bookmark_url (
  in domain_id integer)
{
  return concat(BMK.WA.host_url(), '/bookmark/', cast(domain_id as varchar), '/');
}
;

-------------------------------------------------------------------------------
--
create procedure BMK.WA.dav_url (
  in domain_id integer,
  in account_id integer)
{
  declare home varchar;

  home := BMK.WA.dav_home(account_id);
  if (isnull(home))
    return '';
  return concat(BMK.WA.host_url(), home, 'BM/', BMK.WA.domain_gems_name(domain_id), '/');
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
  http('  XMLELEMENT(\'managingEditor\', U_E_MAIL), \n', retValue);
  http('  XMLELEMENT(\'pubDate\', BMK.WA.dt_rfc1123(now())), \n', retValue);
  http('  XMLELEMENT(\'generator\', \'Virtuoso Universal Server \' || sys_stat(\'st_dbms_ver\')), \n', retValue);
  http('  XMLELEMENT(\'webMaster\', U_E_MAIL), \n', retValue);
  http('  XMLELEMENT(\'link\', BMK.WA.bookmark_url(<DOMAIN_ID>)) \n', retValue);
  http('from DB.DBA.SYS_USERS where U_ID = <USER_ID> \n', retValue);
  http(']]></sql:sqlx>\n', retValue);

  http('<sql:sqlx xmlns:sql=\'urn:schemas-openlink-com:xml-sql\'><![CDATA[\n', retValue);
  http('select \n', retValue);
  http('  XMLAGG(XMLELEMENT(\'item\', \n', retValue);
  http('    XMLELEMENT(\'title\', BMK.WA.utf2wide(BD_NAME)), \n', retValue);
  http('    XMLELEMENT(\'description\', BMK.WA.utf2wide(BD_DESCRIPTION)), \n', retValue);
  http('    XMLELEMENT(\'guid\', B_ID), \n', retValue);
  http('    XMLELEMENT(\'link\', B_URI), \n', retValue);
  http('    XMLELEMENT(\'pubDate\', BMK.WA.dt_rfc1123 (BD_LAST_UPDATE)), \n', retValue);
  http('    XMLELEMENT(\'http://www.openlinksw.com/weblog/:modified\', BMK.WA.dt_iso8601 (BD_LAST_UPDATE)))) \n', retValue);
  http('from (select top 15  \n', retValue);
  http('        BD_NAME, \n', retValue);
  http('        BD_DESCRIPTION, \n', retValue);
  http('        BD_LAST_UPDATE, \n', retValue);
  http('        B_ID, \n', retValue);
  http('        B_URI \n', retValue);
  http('      from \n', retValue);
  http('        BMK.WA.BOOKMARK, \n', retValue);
  http('        BMK.WA.BOOKMARK_DOMAIN \n', retValue);
  http('      where BD_BOOKMARK_ID = B_ID  \n', retValue);
  http('        and BD_DOMAIN_ID = <DOMAIN_ID> \n', retValue);
  http('      order by BD_LAST_UPDATE desc) x \n', retValue);
  http(']]></sql:sqlx>\n', retValue);

  http('</channel>\n', retValue);
  http('</rss>\n', retValue);

  retValue := string_output_string (retValue);
  retValue := replace(retValue, '<USER_ID>', cast(account_id as varchar));
  retValue := replace(retValue, '<DOMAIN_ID>', cast(domain_id as varchar));
  return retValue;
}
;

--  http('    XMLELEMENT(\'http://www.openlinksw.com/weblog/:modified\', BMK.WA.dt_iso8601 (EFI_PUBLISH_DATE)), \n', retValue);

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
  if (BMK.WA.settings_atomVersion (account_id) = '1.0')
    xsltTemplate := BMK.WA.xslt_full ('rss2atom.xsl');

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
create procedure BMK.WA.xml_set(
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
  in mode integer := 0) returns any
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
  declare exit handler for sqlstate '*' { return S; };
  return charset_recode (S, 'UTF-8', '_WIDE_');
}
;

-------------------------------------------------------------------------------
--
create procedure BMK.WA.wide2utf (
  inout S any)
{
  declare exit handler for sqlstate '*' { return S; };
  return charset_recode (S, '_WIDE_', 'UTF-8' );
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
  in aVector any,
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
create procedure BMK.WA.vector_search(
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
create procedure BMK.WA.bmk_tree_int(
  in domain_id integer,
  in node_id any,
  inout retValue any)
{
  declare id, type any;

  id := BMK.WA.node_id(node_id);
  type := BMK.WA.node_type(node_id);
  if (type = 'f') {
    for (select F_ID, F_NAME from BMK.WA.FOLDER where F_DOMAIN_ID = domain_id and coalesce(F_PARENT_ID, 0) = id order by 2) do {
      http (sprintf('<node name="%V" id="f#%d">', F_NAME, F_ID), retValue);
      BMK.WA.bmk_tree_int(domain_id, sprintf('f#%d', F_ID), retValue);
      http ('</node>', retValue);
    }
  }
  if (type = 's') {
    for (select SF_ID, SF_NAME from BMK.WA.SFOLDER where SF_DOMAIN_ID = domain_id order by 2) do {
      http (sprintf('<node name="%V" id="s#%d">', SF_NAME, SF_ID), retValue);
      http ('</node>', retValue);
    }
  }
}
;

-------------------------------------------------------------------------------
--
create procedure BMK.WA.bmk_tree(
  in domain_id integer)
{
  declare retValue any;

  retValue := string_output ();
  http ('<node>', retValue);
  if (domain_id = -1) {
    http ('<node name="Last Bookmarks" id="p#0">', retValue);
    http ('</node>', retValue);
  } else {
    http ('<node name="Bookmarks" id="f#0">', retValue);
    BMK.WA.bmk_tree_int(domain_id, 'f#0', retValue);
    http ('</node>', retValue);
    http ('<node name="Smart Folders" id="s#0">', retValue);
    BMK.WA.bmk_tree_int(domain_id, 's#0', retValue);
    http ('</node>', retValue);
  }
  http ('</node>', retValue);
  return string_output_string (retValue);
}
;

-------------------------------------------------------------------------------
--
create procedure BMK.WA.bmk_root(
  in path varchar := '')
{
  return xpath_eval ('/node/*', xml_tree_doc (BMK.WA.bmk_tree (cast(path as integer))), 0);
}
;

-------------------------------------------------------------------------------
--
create procedure BMK.WA.bmk_child(
  in path varchar,
  in node varchar)
{
  return xpath_eval (path, node, 0);
}
;

-------------------------------------------------------------------------------
--
create procedure BMK.WA.node_type(
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
create procedure BMK.WA.node_prefix(
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
create procedure BMK.WA.node_id(
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
create procedure BMK.WA.node_suffix(
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

create procedure BMK.WA.dashboard_get(
  in user_id integer)
{
  declare ses any;

  ses := string_output ();
  http ('<bookmark-db>', ses);
  for select top 10 *
        from (select a.BD_NAME,
                     b.B_URI,
                     a.BD_LAST_UPDATE
                from BMK.WA.BOOKMARK_DOMAIN a,
                     BMK.WA.BOOKMARK b,
                     DB.DBA.WA_INSTANCE c,
                     DB.DBA.WA_MEMBER d
                where a.BD_BOOKMARK_ID = b.B_ID
                  and d.WAM_USER = user_id
                  and d.WAM_INST = C.WAI_NAME
                  and c.WAI_ID = a.BD_DOMAIN_ID
                order by BD_LAST_UPDATE desc
             ) x do {

    declare uname, full_name varchar;

    uname := (select coalesce (U_NAME, '') from DB.DBA.SYS_USERS where U_ID = user_id);
    full_name := (select coalesce (coalesce (U_FULL_NAME, U_NAME), '') from DB.DBA.SYS_USERS where U_ID = user_id);

    http ('<bookmark>', ses);
    http (sprintf ('<dt>%s</dt>', date_iso8601 (BD_LAST_UPDATE)), ses);
    http (sprintf ('<title><![CDATA[%s]]></title>', BD_NAME), ses);
    http (sprintf ('<link><![CDATA[%s]]></link>', B_URI), ses);
    http (sprintf ('<from><![CDATA[%s]]></from>', full_name), ses);
    http (sprintf ('<uid>%s</uid>', uname), ses);
    http ('</bookmark>', ses);
  }
  http ('</bookmark-db>', ses);
  return string_output_string (ses);
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
  in pDefault datetime := null,
  in pUser datetime := null)
{
  if (isnull(pDefault))
    pDefault := now();
  if (isnull(pDate))
    pDate := pDefault;
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
create procedure BMK.WA.dt_deformat(
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
    if (__SQL_STATE = 'CLASS')
      signal ('TEST', sprintf('Field ''%s'' contains invalid characters!<>', valueName));
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

  value := BMK.WA.validate2 (valueClass, value);

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
create procedure BMK.WA.validate2 (
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
    return stringdate(BMK.WA.dt_reformat(propertyValue, 'd.m.Y', 'Y-M-D'));
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
  in S varchar)
{
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
create procedure BMK.WA.version_update()
{
  for (select WAI_ID, WAM_USER
         from DB.DBA.WA_MEMBER join DB.DBA.WA_INSTANCE on WAI_NAME = WAM_INST
        where WAI_TYPE_NAME = 'Bookmark' and WAM_MEMBER_TYPE = 1) do {
    BMK.WA.domain_update(WAI_ID, WAM_USER);
  }
}
;

-----------------------------------------------------------------------------------------
--
BMK.WA.version_update()
;
