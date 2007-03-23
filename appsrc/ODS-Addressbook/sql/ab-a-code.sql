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
-- Request Functions
--
-------------------------------------------------------------------------------
create procedure AB.WA.validate_request(
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
  if (isnull (i))
    AB.WA.http_response(400);              -- Bad Request (can't happen!)
  l := length(pLines[0]) - 2;              -- total length.one for zero-based and one for ending LF!;
  k := strrchr(pLines[0],' ');             -- URI/Version dividing space ( k <- end of URL)
  if (isnull (k) or (k = i))
    k := l;                                -- if no version tag is presented k equals l
  j := strstr(pLines[0],'?');              -- search for parameters in URI and ignore them!
  if (isnull (j)) j := k;                  -- if no parameters j equals k (end of URI)
  B := subseq(pLines[0],i+1,j);            -- Buffer for resource path
  -- Initialize result structure;
  aResult := vector(subseq(pLines[0],0,i),vector('',''),vector(1,0),vector(),vector('sn','vspx'), -2);
  -- Determine host
  S := http_request_header(pLines,'Host',null,'');
  if (S <> '') {
    i := strstr(S,':');
    if (isnull (i))
      aset(aResult,1,vector(S,''));
    else
      aset(aResult,1,vector(subseq(S,0,i),subseq(S,i+1)));
  }
  -- Determine request version
  if (k + 1 < l) {
    -- Check for version format
    S := subseq(pLines[0],k+1,l);
    i := strstr(S,'HTTP/');
    if (isnull (i) or (i > 0)) AB.WA.http_response(400);                 -- Bad Request
    i := strstr(S,'.'); if (isnull (i)) AB.WA.http_response(400);        -- Bad Request
    aset(aResult,2,vector(atoi(subseq(S,5,i)),atoi(subseq(S,i+1))));
  }
  if (aResult[2][0] <> 1) AB.WA.http_response(505);                     -- HTTP Version Not Supported
  if (aResult[2][1] < pMinVersion) AB.WA.http_response(505);            -- HTTP Version Not Supported
  if ((pMinVersion > 0) and aResult[1] = '') AB.WA.http_response(400);  -- Host field required for HTTP/1.1

  --check "File or Directory";
  P := AB.WA.mount_point();
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
        AB.WA.http_response(404);
      j := j - 1;
    }
    S := concat(S,'sn.vspx');
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
      aset(aResult,5,cast (aref(V,length(V)-1) as integer));
  };

  -- Verify path
  P := S;
  regexp_match('^[a-z_0-9/\.-]+',P,1);
  if (P <> '')
    AB.WA.http_response(404);
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
create procedure AB.WA.mount_point(
  in pURL varchar := null)
{
  declare
    sMPoint varchar;

  sMPoint := http_map_get('domain');
  if (sMPoint = '/')
    sMPoint := '';
  if (not isnull (pURL))
    sMPoint := concat(sMPoint,'/',pURL);
  return sMPoint;
}
;

-------------------------------------------------------------------------------
--
create procedure AB.WA.http_response(in pError integer,in pParams varchar := '')
{
  signal ('90001', sprintf ('<Response Status="%d" MountPoint="%s">%s</Response>', pError, AB.WA.mount_point(), pParams));
}
;

-------------------------------------------------------------------------------
--
-- Session Functions
--
-------------------------------------------------------------------------------
create procedure AB.WA.session_restore(
  inout request any,
  inout params any,
  inout lines any)
{
  declare domain_id, user_id, user_name, user_role, sid, realm, options any;

  declare exit handler for sqlstate '*' {
    domain_id := -2;
    goto _end;
  };

  sid := get_keyword('sid', params, '');
  realm := get_keyword('realm', params, '');

  options := http_map_get('options');
  if (not is_empty_or_null(options))
    domain_id := get_keyword('domain', options);
  if (is_empty_or_null(domain_id))
    domain_id := cast (request[5] as integer);
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
create procedure AB.WA.xslt_root()
{
  declare sHost varchar;

  sHost := cast (registry_get('sn_path') as varchar);
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
create procedure AB.WA.domain_delete (
  in domain_id integer)
{
  VHOST_REMOVE(lpath => concat('/addressbook/', cast (domain_id as varchar)));
  return 1;
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
  return sprintf ('%s/dataspace/%U/addressbook/%U/sioc.rdf', AB.WA.host_url (), AB.WA.account (), replace (AB.WA.domain_name (domain_id), '+', '%2B'));
}
;

-------------------------------------------------------------------------------
--
create procedure AB.WA.contact_url (
  in domain_id integer,
  in person_id integer)
{
  return concat(AB.WA.ab_url (domain_id), 'home.vspx?contact=', cast (person_id as varchar));
}
;

-------------------------------------------------------------------------------
--
create procedure AB.WA.dav_url (
  in domain_id integer,
  in account_id integer)
{
  declare home varchar;

  if (account_id < 0)
    account_id := AB.WA.domain_owner_id (domain_id);
  home := AB.WA.dav_home(account_id);
  if (isnull (home))
    return '';
  return concat(AB.WA.host_url(), home, 'AddressBook/', AB.WA.domain_gems_name(domain_id), '/');
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

-------------------------------------------------------------------------------
--
create procedure AB.WA.xslt_root()
{
  declare sHost varchar;

  sHost := cast (registry_get('_sn_path_') as varchar);
  if (sHost = '0')
    return 'file://apps/addressbook/xslt/';
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
create procedure AB.WA.dt_deformat(
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
  in S varchar)
{
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
                     AB.WA.contact_url (domain_id, P_ID) P_URI,
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

-------------------------------------------------------------------------------
--
create procedure AB.WA.ldap_default (
  in domain_id integer)
{
  return (select TOP 1 LS_NAME from AB.WA.LDAP_SERVERS where LS_DOMAIN_ID = domain_id and LS_DEFAULT = 1);
}
;

-------------------------------------------------------------------------------
--
create procedure AB.WA.ldap_maps (
  in domain_id integer,
  in ldapName varchar)
{
  return (select deserialize (LS_MAPS) from AB.WA.LDAP_SERVERS where LS_DOMAIN_ID = domain_id and LS_NAME = ldapName);
}
;

-------------------------------------------------------------------------------
--
create procedure AB.WA.ldap_search (
  in domain_id integer,
  in ldapName varchar,
  in ldapSearch varchar)
{
  declare ldapHost, retValue any;

  retValue := vector ();
  for (select LS_HOST, LS_PORT, LS_BASE_DN, LS_BIND_DN, LS_PASSWORD
         from AB.WA.LDAP_SERVERS
        where LS_DOMAIN_ID = domain_id and LS_NAME = ldapName) do {
  	declare exit handler for sqlstate '*'
  	{
  	  goto _end;
  	};
    connection_set ('LDAP_VERSION', 2);
  	ldapHost := 'ldap://' || LS_HOST || ':' || LS_PORT;
    return ldap_search (ldapHost, 0, LS_BASE_DN, ldapSearch, LS_BIND_DN, LS_PASSWORD);
  }
_end:
  return retValue;
}
;

-------------------------------------------------------------------------------
--
create procedure AB.WA.foaf_propName (
  in name varchar)
{
  -- name
  if (name = 'name')
    return name;
  -- nick
  if (name = 'nick')
    return name;
  -- first name
  if (name = 'firstName')
    return name;
  -- surname
  if (name = 'surname')
    return 'surname';
  -- famity
  if (name = 'familyName')
    return 'family_name';
  -- mbox
  if (name = 'mbox')
    return name;
  -- title
  if (name = 'title')
    return name;

  return null;
}
;

-----------------------------------------------------------------------------------------
--
-- Polls
--
-----------------------------------------------------------------------------------------
create procedure AB.WA.contact_update (
  in id integer,
  in domain_id integer,
  in name varchar,
  in title varchar,
  in fName varchar,
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
  in hCity varchar,
  in hState varchar,
  in hCode varchar,
  in hAddress1 varchar,
  in hAddress2 varchar,
  in hTzone varchar,
  in hLat real,
  in hLng real,
  in hPhone varchar,
  in hMobile varchar,
  in hMail varchar,
  in hWeb varchar,
  in bCountry varchar,
  in bCity varchar,
  in bState varchar,
  in bCode varchar,
  in bAddress1 varchar,
  in bAddress2 varchar,
  in bTzone varchar,
  in bLat real,
  in bLng real,
  in bPhone varchar,
  in bMobile varchar,
  in bIndustry varchar,
  in bOrganization varchar,
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
        P_NAME,
        P_TITLE,
        P_FIRST_NAME,
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
        P_H_CITY,
        P_H_STATE,
        P_H_CODE,
        P_H_ADDRESS1,
        P_H_ADDRESS2,
        P_H_TZONE,
        P_H_LAT,
        P_H_LNG,
        P_H_PHONE,
        P_H_MOBILE,
        P_H_MAIL,
        P_H_WEB,
        P_B_COUNTRY,
        P_B_CITY,
        P_B_STATE,
        P_B_CODE,
        P_B_ADDRESS1,
        P_B_ADDRESS2,
        P_B_TZONE,
        P_B_LAT,
        P_B_LNG,
        P_B_PHONE,
        P_B_MOBILE,
        P_B_INDUSTRY,
        P_B_ORGANIZATION,
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
        name,
        title,
        fName,
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
        hCity,
        hState,
        hCode,
        hAddress1,
        hAddress2,
        hTzone,
        hLat,
        hLng,
        hPhone,
        hMobile,
        hMail,
        hWeb,
        bCountry,
        bCity,
        bState,
        bCode,
        bAddress1,
        bAddress2,
        bTzone,
        bLat,
        bLng,
        bPhone,
        bMobile,
        bIndustry,
        bOrganization,
        bJob,
        bMail,
        bWeb,
        tags,
        now (),
        now ()
      );
  } else {
    update AB.WA.PERSONS
       set P_NAME = name,
           P_TITLE = title,
           P_FIRST_NAME = fName,
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
           P_B_INDUSTRY = bIndustry,
           P_B_ORGANIZATION = bOrganization,
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
    if (pName = 'P_NAME')
      update AB.WA.PERSONS set P_NAME = pValue where P_ID = id;
    if (pName = 'P_TITLE')
      update AB.WA.PERSONS set P_TITLE = pValue where P_ID = id;
    if (pName = 'P_FIRST_NAME')
      update AB.WA.PERSONS set P_FIRST_NAME = pValue where P_ID = id;
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
  }
  return id;
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
create procedure AB.WA.search_sql (
  inout domain_id integer,
  inout account_id integer,
  inout data varchar,
  in maxRows varchar := '')
{
  declare S, tmp, where2, delimiter2 varchar;

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
         'where p.P_DOMAIN_ID = <DOMAIN_ID> <TEXT> <TAGS> <WHERE> \n';
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
         '  and g.G_GRANTEE_ID = <ACCOUNT_ID> <TEXT> <TAGS> <WHERE> \n';
  }

  S := 'select <MAX> * from (' || S || ') x';

  tmp := AB.WA.xml_get('keywords', data);
  if (not is_empty_or_null(tmp)) {
    S := replace(S, '<TEXT>', sprintf('and contains(p.P_NAME, \'[__lang "x-ViDoc"] %s\') \n', FTI_MAKE_SEARCH_STRING(tmp)));
  } else {
    tmp := AB.WA.xml_get('expression', data);
    if (not is_empty_or_null(tmp))
      S := replace(S, '<TEXT>', sprintf('and contains(p.P_NAME, \'[__lang "x-ViDoc"] %s\') \n', tmp));
  }

  tmp := AB.WA.xml_get('tags', data);
  if (not is_empty_or_null(tmp)) {
    tmp := AB.WA.tags2search (tmp);
    S := replace(S, '<TAGS>', sprintf('and contains(p.P_NAME, \'[__lang "x-ViDoc"] %s\') \n', tmp));
  }

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

