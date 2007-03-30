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
create procedure POLLS.WA.validate_request(
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
  if (isnull(i)) POLLS.WA.http_response(400);       -- Bad Request (can't happen!)
  l := length(pLines[0]) - 2;              -- total length.one for zero-based and one for ending LF!;
  k := strrchr(pLines[0],' ');             -- URI/Version dividing space ( k <- end of URL)
  if (isnull(k) or (k = i)) k := l;        -- if no version tag is presented k equals l
  j := strstr(pLines[0],'?');              -- search for parameters in URI and ignore them!
  if (isnull(j)) j := k;                   -- if no parameters j equals k (end of URI)
  B := subseq(pLines[0],i+1,j);            -- Buffer for resource path
  -- Initialize result structure;
  aResult := vector(subseq(pLines[0],0,i),vector('',''),vector(1,0),vector(),vector('pollss','vspx'), -2);
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
    if (isnull(i) or (i > 0)) POLLS.WA.http_response(400);                 -- Bad Request
    i := strstr(S,'.'); if (isnull(i)) POLLS.WA.http_response(400);        -- Bad Request
    aset(aResult,2,vector(atoi(subseq(S,5,i)),atoi(subseq(S,i+1))));
  }
  if (aResult[2][0] <> 1) POLLS.WA.http_response(505);                     -- HTTP Version Not Supported
  if (aResult[2][1] < pMinVersion) POLLS.WA.http_response(505);            -- HTTP Version Not Supported
  if ((pMinVersion > 0) and aResult[1] = '') POLLS.WA.http_response(400);  -- Host field required for HTTP/1.1

  --check "File or Directory";
  P := POLLS.WA.mount_point();
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
        POLLS.WA.http_response(404);
      j := j - 1;
    }
    S := concat(S,'pollss.vspx');
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
    POLLS.WA.http_response(404);
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
create procedure POLLS.WA.mount_point(
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
create procedure POLLS.WA.http_response(in pError integer,in pParams varchar := '')
{
  signal ('90001', sprintf('<Response Status="%d" MountPoint="%s">%s</Response>', pError, POLLS.WA.mount_point(), pParams));
}
;

-------------------------------------------------------------------------------
--
-- Session Functions
--
-------------------------------------------------------------------------------
create procedure POLLS.WA.session_restore(
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
    domain_id := cast(request[5] as integer);
  if (not exists(select 1 from DB.DBA.WA_INSTANCE where WAI_ID = domain_id and domain_id <> -2))
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
    user_name := POLLS.WA.user_name(U_NAME, U_FULL_NAME);
    user_role := POLLS.WA.access_role(domain_id, U_ID);
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
create procedure POLLS.WA.frozen_check(in domain_id integer)
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
create procedure POLLS.WA.frozen_page(in domain_id integer)
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
create procedure POLLS.WA.check_grants(in domain_id integer, in user_id integer, in role_name varchar)
{
  whenever not found goto _end;

  if (POLLS.WA.check_admin(user_id))
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
create procedure POLLS.WA.check_grants2(in role_name varchar, in page_name varchar)
{
  return 1;
}
;

-------------------------------------------------------------------------------
--
create procedure POLLS.WA.access_role(in domain_id integer, in user_id integer)
{
  whenever not found goto _end;

  if (POLLS.WA.check_admin (user_id))
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
  http ('  XMLELEMENT(\'managingEditor\', U_E_MAIL), \n', retValue);
  http ('  XMLELEMENT(\'pubDate\', POLLS.WA.dt_rfc1123(now())), \n', retValue);
  http ('  XMLELEMENT(\'generator\', \'Virtuoso Universal Server \' || sys_stat(\'st_dbms_ver\')), \n', retValue);
  http ('  XMLELEMENT(\'webMaster\', U_E_MAIL), \n', retValue);
  http ('  XMLELEMENT(\'link\', POLLS.WA.polls_url (<DOMAIN_ID>)) \n', retValue);
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
  http ('    XMLELEMENT(\'http://www.openlinksw.com/weblog/:modified\', POLLS.WA.dt_iso8601 (P_UPDATED)))) \n', retValue);
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
  if (POLLS.WA.settings_atomVersion (account_id) = '1.0')
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
  home := home || 'Polls/';
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

  return;
}
;

-------------------------------------------------------------------------------
--
create procedure POLLS.WA.domain_gems_delete(
  in domain_id integer,
  in account_id integer,
  in appName varchar := 'Polls',
  in appGems varchar := null)
{
  declare tmp, home, path varchar;

  home := POLLS.WA.dav_home(account_id);
  if (isnull(home))
    return;

  if (isnull(appGems))
    appGems := POLLS.WA.domain_gems_name(domain_id);
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
    auth_pwd := pwd_magic_calc(auth_uid, auth_pwd, 1);

  tmp := DB.DBA.DAV_DIR_LIST (home, 0, auth_uid, auth_pwd);
  if (not isinteger(tmp) and not length(tmp))
    DB.DBA.DAV_DELETE_INT (home, 1, null, null, 0);

  return 1;
}
;

-------------------------------------------------------------------------------
--
create procedure POLLS.WA.domain_update (
  inout domain_id integer,
  inout account_id integer)
{
  POLLS.WA.domain_gems_delete (domain_id, account_id, 'Polls');
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
  VHOST_REMOVE(lpath => concat('/polls/', cast(domain_id as varchar)));
  return 1;
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
  return concat(POLLS.WA.domain_name(domain_id), '_Gems');
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
  for (select WAI_NAME, WAI_DESCRIPTION from DB.DBA.WA_INSTANCE where WAI_ID = domain_id and WAI_IS_PUBLIC = 1) do {
    ODS..APP_PING (WAI_NAME, coalesce (WAI_DESCRIPTION, WAI_NAME), POLLS.WA.sioc_url (domain_id));
  }
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
  declare iCount any;

  select count(WAM_USER) into iCount
    from WA_MEMBER,
         WA_INSTANCE
   where WAI_NAME = WAM_INST
     and WAI_TYPE_NAME = 'Polls'
     and WAM_USER = account_id;

  if (iCount = 0) {
    delete from POLLS.WA.SETTINGS where S_ACCOUNT_ID = account_id;
  }
  POLLS.WA.domain_gems_delete(domain_id, account_id);

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
create procedure POLLS.WA.account_fullName (
  in account_id integer)
{
  return coalesce((select coalesce(U_FULL_NAME, U_NAME) from DB.DBA.SYS_USERS where U_ID = account_id), '');
}
;

-------------------------------------------------------------------------------
--
create procedure POLLS.WA.user_name(
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
  inout account_id integer)
{
  return coalesce((select deserialize(blob_to_string(S_DATA))
                     from POLLS.WA.SETTINGS
                    where S_ACCOUNT_ID = account_id), vector());
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
  inout account_id integer)
{
  declare settings any;

  settings := POLLS.WA.settings(account_id);
  return cast(get_keyword('rows', settings, '10') as integer);
}
;

-------------------------------------------------------------------------------
--
create procedure POLLS.WA.settings_atomVersion (
  inout account_id integer)
{
  declare settings any;

  settings := POLLS.WA.settings(account_id);
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

-------------------------------------------------------------------------------
--
create procedure POLLS.WA.host_url ()
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
  return sprintf('%s/dataspace/%U/polls/%U/sioc.rdf', POLLS.WA.host_url (), POLLS.WA.account (), replace (POLLS.WA.domain_name (domain_id), '+', '%2B'));
}
;

-------------------------------------------------------------------------------
--
create procedure POLLS.WA.foaf_url (
  in account_id integer)
{
  return sprintf('%s/dataspace/%s/about.rdf', POLLS.WA.host_url (), POLLS.WA.account_name (account_id));
}
;

-------------------------------------------------------------------------------
--
create procedure POLLS.WA.poll_url (
  in domain_id integer,
  in poll_id integer)
{
  return concat(POLLS.WA.polls_url (domain_id), 'polls.vspx?poll=', cast(poll_id as varchar));
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
  return concat(POLLS.WA.host_url(), home, 'Polls/', POLLS.WA.domain_gems_name(domain_id), '/');
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

  if (not is_empty_or_null(value)) {
    aEntity := xpath_eval('/settings', pXml);
    XMLAppendChildren(aEntity, xtree_doc(sprintf ('<entry ID="%s">%s</entry>', id, POLLS.WA.xml2string(value))));
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
create procedure POLLS.WA.normalize_space(
  in S varchar)
{
  return xpath_eval ('normalize-space (string(/a))', XMLELEMENT('a', S), 1);
}
;

-------------------------------------------------------------------------------
--
create procedure POLLS.WA.utfClear(
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
create procedure POLLS.WA.utf2wide (
  inout S any)
{
  if (isstring (S))
    return charset_recode (S, 'UTF-8', '_WIDE_');
  return S;
}
;

-------------------------------------------------------------------------------
--
create procedure POLLS.WA.wide2utf (
  inout S any)
{
  if (iswidestring (S))
    return charset_recode (S, '_WIDE_', 'UTF-8' );
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
  pDate := POLLS.WA.dt_gmt2user(pDate, pUser);
  return POLLS.WA.dt_format(pDate, 'D.M.Y');
}
;

-----------------------------------------------------------------------------
--
create procedure POLLS.WA.dt_format(
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
create procedure POLLS.WA.dt_deformat(
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
};

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
  declare N integer;

  return substring(S, 1, coalesce(strstr(S, '<>'), length(S)));
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
    if (isnull(regexp_match('^(ht|f)tp(s?)\:\/\/[0-9a-zA-Z]([-.\w]*[0-9a-zA-Z])*(:(0-9)*)*(\/?)([a-zA-Z0-9\-\.\?\,\'\/\\\+&amp;%\$#_=:]*)?\$', propertyValue)))
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
  in S varchar)
{
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

-------------------------------------------------------------------------------
--
create procedure POLLS.WA.poll_delete (
  in id integer,
  in domain_id integer)
{
  delete from POLLS.WA.POLL where P_ID = id and P_DOMAIN_ID = domain_id;
}
;

-------------------------------------------------------------------------------
--
create procedure POLLS.WA.poll_active (
  in id integer,
  in domain_id integer)
{
  update POLLS.WA.POLL
     set P_STATE = 'AC'
   where P_ID = id and
         P_DOMAIN_ID = domain_id;
}
;

-------------------------------------------------------------------------------
--
create procedure POLLS.WA.poll_close (
  in id integer,
  in domain_id integer)
{
  update POLLS.WA.POLL
     set P_STATE = 'CL'
   where P_ID = id and
         P_DOMAIN_ID = domain_id;
}
;

-------------------------------------------------------------------------------
--
create procedure POLLS.WA.poll_clear (
  in id integer,
  in domain_id integer)
{
  update POLLS.WA.POLL
     set P_VOTES = 0,
         P_VOTED = null
   where P_ID = id and
         P_DOMAIN_ID = domain_id;
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
  if (is_empty_or_null (votes))
    return 0;
  return 1;
}
;

-------------------------------------------------------------------------------
--
create procedure POLLS.WA.poll_enable_edit (
  in domain_id integer,
  in user_role varchar,
  in poll_id integer)
{
  if (user_role in ('public', 'guest'))
    return 0;

  for (select * from POLLS.WA.POLL where P_ID = poll_id and P_DOMAIN_ID = domain_id) do
    if (POLLS.WA.poll_is_draft (P_STATE, P_DATE_START, P_DATE_END))
      return 1;

  return 0;
}
;

-------------------------------------------------------------------------------
--
create procedure POLLS.WA.poll_enable_delete (
  in domain_id integer,
  in user_role varchar,
  in poll_id integer)
{
  if (user_role in ('public', 'guest'))
    return 0;

  for (select * from POLLS.WA.POLL where P_ID = poll_id and P_DOMAIN_ID = domain_id) do
    return 1;

  return 0;
}
;

-------------------------------------------------------------------------------
--
create procedure POLLS.WA.poll_enable_activate (
  in domain_id integer,
  in user_role varchar,
  in poll_id integer)
{
  if (user_role in ('public', 'guest'))
    return 0;

  for (select * from POLLS.WA.POLL where P_ID = poll_id and P_DOMAIN_ID = domain_id) do
    if (POLLS.WA.poll_is_draft (P_STATE, P_DATE_START))
      return 1;

  return 0;
}
;

-------------------------------------------------------------------------------
--
create procedure POLLS.WA.poll_enable_close (
  in domain_id integer,
  in user_role varchar,
  in poll_id integer)
{
  if (user_role in ('public', 'guest'))
    return 0;

  for (select * from POLLS.WA.POLL where P_ID = poll_id and P_DOMAIN_ID = domain_id) do
    if (POLLS.WA.poll_is_active (P_STATE, P_DATE_START, P_DATE_END))
      return 1;

  return 0;
}
;

-------------------------------------------------------------------------------
--
create procedure POLLS.WA.poll_enable_clear (
  in domain_id integer,
  in user_role varchar,
  in poll_id integer)
{
  if (user_role in ('public', 'guest'))
    return 0;

  for (select * from POLLS.WA.POLL where P_ID = poll_id and P_DOMAIN_ID = domain_id) do
    if (P_VOTES > 0)
      if (POLLS.WA.poll_is_active (P_STATE, P_DATE_START, P_DATE_END))
        return 1;

  return 0;
}
;

-------------------------------------------------------------------------------
--
create procedure POLLS.WA.poll_enable_vote (
  in poll_id integer)
{
  declare client_id varchar;

  for (select * from POLLS.WA.POLL where P_ID = poll_id) do {
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
  in poll_id integer)
{
  declare client_id varchar;

  client_id := client_attr ('client_ip');
  for (select P.*, V.V_CLIENT_ID
         from POLLS.WA.POLL P
                left join POLLS.WA.VOTE V on V.V_POLL_ID = P.P_ID and V.V_CLIENT_ID = client_id
        where P.P_ID = poll_id) do {
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
  if (id <= 0) {
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
  inout data varchar,
  in maxRows varchar := '')
{
  declare S, tmp, where2, delimiter2 varchar;

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

  tmp := POLLS.WA.xml_get('keywords', data);
  if (not is_empty_or_null(tmp)) {
    S := replace(S, '<TEXT>', sprintf('and contains(p.P_NAME, \'[__lang "x-ViDoc"] %s\') \n', FTI_MAKE_SEARCH_STRING(tmp)));
  } else {
    tmp := POLLS.WA.xml_get('expression', data);
    if (not is_empty_or_null(tmp))
      S := replace(S, '<TEXT>', sprintf('and contains(p.P_NAME, \'[__lang "x-ViDoc"] %s\') \n', tmp));
  }

  tmp := POLLS.WA.xml_get('tags', data);
  if (not is_empty_or_null(tmp)) {
    tmp := POLLS.WA.tags2search (tmp);
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

-------------------------------------------------------------------------------
--
create procedure POLLS.WA.dashboard_get(
  in domain_id integer,
  in user_id integer)
{
  declare ses any;

  ses := string_output ();
  http ('<poll-db>', ses);
  for select top 10 *
        from (select a.P_NAME,
                     POLLS.WA.poll_url (domain_id, P_ID) P_URI,
                     a.P_UPDATED
                from POLLS.WA.POLL a,
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

    http ('<poll>', ses);
    http (sprintf ('<dt>%s</dt>', date_iso8601 (P_UPDATED)), ses);
    http (sprintf ('<title><![CDATA[%s]]></title>', P_NAME), ses);
    http (sprintf ('<link><![CDATA[%s]]></link>', P_URI), ses);
    http (sprintf ('<from><![CDATA[%s]]></from>', full_name), ses);
    http (sprintf ('<uid>%s</uid>', uname), ses);
    http ('</poll>', ses);
  }
  http ('</poll-db>', ses);
  return string_output_string (ses);
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
