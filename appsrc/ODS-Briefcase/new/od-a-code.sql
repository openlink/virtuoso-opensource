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
-- Session Functions
--
-------------------------------------------------------------------------------
create procedure ODRIVE.WA.session_user(
  inout params any)
{
  return coalesce((select U.U_NAME
                     from DB.DBA.VSPX_SESSION S,
                          WS.WS.SYS_DAV_USER U
                    where S.VS_REALM = get_keyword('realm', params, '')
                      and S.VS_SID   = get_keyword('sid', params, '')
                      and S.VS_UID   = U.U_NAME), '');
}
;

-------------------------------------------------------------------------------
--
create procedure ODRIVE.WA.session_user_id(
  inout params any)
{
  return (select U.U_ID
            from DB.DBA.VSPX_SESSION S,
                 WS.WS.SYS_DAV_USER U
           where S.VS_REALM = get_keyword('realm', params, '')
             and S.VS_SID   = get_keyword('sid', params, '')
             and S.VS_UID   = U.U_NAME);
}
;

-------------------------------------------------------------------------------
--
create procedure ODRIVE.WA.session_user_description(
  inout params any)
{
  return coalesce((select coalesce(U.U_FULL_NAME, U.U_NAME)
                     from DB.DBA.VSPX_SESSION S,
                          WS.WS.SYS_DAV_USER U
                    where S.VS_REALM = get_keyword('realm', params, '')
                      and S.VS_SID   = get_keyword('sid', params, '')
                      and S.VS_UID   = U.U_NAME), '');
}
;

-------------------------------------------------------------------------------
--
-- Session Functions
--
-------------------------------------------------------------------------------
create procedure ODRIVE.WA.session_domain (
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
  if (is_empty_or_null (domain_id))
  {
    aPath := split_and_decode (trim (http_path (), '/'), 0, '\0\0/');
    domain_id := cast(aPath[1] as integer);
  }
  if (not exists (select 1 from DB.DBA.WA_INSTANCE where WAI_ID = domain_id and WAI_TYPE_NAME = 'oDrive'))
    domain_id := -1;

_end:;
  return cast (domain_id as integer);
}
;

-------------------------------------------------------------------------------
--
create procedure ODRIVE.WA.session_restore (
  inout params any)
{
  declare domain_id, user_id, user_name, user_role, sid, realm, options any;

  sid := get_keyword ('sid', params, '');
  realm := get_keyword ('realm', params, 'wa');
  domain_id := ODRIVE.WA.session_domain (params);
  user_id := -1;
        user_role := 'expire';
        user_name := 'Expire session';

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
    user_name := ODRIVE.WA.user_name (U_NAME, U_FULL_NAME);
  }
  user_role := ODRIVE.WA.access_role (domain_id, user_id);

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
create procedure ODRIVE.WA.frozen_check (
  in domain_id integer)
{
  if (is_empty_or_null ((select WAI_IS_FROZEN from DB.DBA.WA_INSTANCE where WAI_ID = domain_id)))
    return 0;

  if (ODRIVE.WA.check_admin(connection_get ('vspx_user')))
    return 0;

  if (ODRIVE.WA.check_admin(connection_get ('owner_user')))
    return 0;

  return 1;
}
;

-------------------------------------------------------------------------------
--
create procedure ODRIVE.WA.frozen_page (
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
create procedure ODRIVE.WA.check_admin(
  in usr any) returns integer
{
  declare grp integer;

  if (isstring(usr))
    usr := (select U_ID from SYS_USERS where U_NAME = usr);

  if ((usr = 0) or (usr = http_dav_uid ()))
    return 1;

  grp := (select U_GROUP from SYS_USERS where U_ID = usr);
  if ((grp = 0) or (grp = http_dav_uid ()) or (grp = http_dav_uid()+1))
    return 1;

  return 0;
}
;

-------------------------------------------------------------------------------
--
create procedure ODRIVE.WA.odrive_check_grants(
  in user_name varchar,
  in role_name varchar)
{
  declare user_id, group_id integer;

  whenever not found goto nf;

  if (user_name='')
    return 0;
  select U_ID, U_GROUP into user_id, group_id from DB.DBA.SYS_USERS where U_NAME=user_name;
  if (user_id = 0 or group_id = 0)
    return 1;
  return 1;

nf:
  return 0;
}
;

-------------------------------------------------------------------------------
--
create procedure ODRIVE.WA.check_grants2 (in role_name varchar, in page_name varchar)
{
  declare tree any;

  tree := xml_tree_doc (ODRIVE.WA.menu_tree ());
  if (isnull(xpath_eval (sprintf ('//node[(@url = "%s") and contains(@allowed, "%s")]', page_name, role_name), tree, 1)))
    return 0;
  return 1;
}
;

-------------------------------------------------------------------------------
--
create procedure ODRIVE.WA.access_role (in domain_id integer, in user_id integer)
{
  if (domain_id <= 0)
    return 'expire';

  if (ODRIVE.WA.check_admin (user_id))
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

  if (exists (select 1
                from DB.DBA.WA_INSTANCE
               where WAI_ID = domain_id
                 and WAI_IS_PUBLIC = 1))
  {
  return 'public';
}
  return 'expire';
}
;

-------------------------------------------------------------------------------
--
create procedure ODRIVE.WA.wa_home_link ()
{
	return case when registry_get ('wa_home_link') = 0 then '/ods/' else registry_get ('wa_home_link') end;
}
;

-------------------------------------------------------------------------------
--
create procedure ODRIVE.WA.wa_home_title ()
{
	return case when registry_get ('wa_home_title') = 0 then 'ODS Home' else registry_get ('wa_home_title') end;
}
;

-------------------------------------------------------------------------------
--
create procedure ODRIVE.WA.page_name ()
{
  declare path, url, elm varchar;
  declare arr any;

  path := http_path ();
  arr := split_and_decode (path, 0, '\0\0/');
  elm := arr [length (arr) - 1];
  url := xpath_eval ('//*[@url = "'|| elm ||'"]', xml_tree_doc (ODRIVE.WA.menu_tree ()));
  if ((url is not null) or (elm = 'error.vspx'))
    return elm;
  return '';
}
;

-------------------------------------------------------------------------------
--
create procedure ODRIVE.WA.menu_tree ()
{
  return
'<?xml version="1.0" ?>
<menu_tree>
  <node     name="Browse"         url="home.vspx"          id="1"   tip="DAV Browser"               allowed="public guest reader author owner admin">
    <node   name="Settings"       url="settings.vspx"      id="11"  place="link"                    allowed="admin owner"/>
  </node>
  <node     name="Metadata"       url="vmds.vspx"          id="3"   tip="Metadata Administration"  allowed="admin owner">
    <node   name="Schemas"        url="vmds.vspx"          id="31"  tip="Schema Administration"    allowed="admin owner"/>
    <node   name="Mime Types"     url="mimes.vspx"         id="32"  tip="Mime Type Administration" allowed="admin owner"/>
  </node>
  <node     name="Subscriptions"  url="subscriptions.vspx" id="4"   tip="Subscriptions"            allowed="admin owner"/>
</menu_tree>';
}
;

-------------------------------------------------------------------------------
--
create procedure ODRIVE.WA.navigation_root(
  in path varchar)
{
  return xpath_eval ('/menu_tree/*', xml_tree_doc (ODRIVE.WA.menu_tree ()), 0);
}
;

-------------------------------------------------------------------------------
--
create procedure ODRIVE.WA.navigation_child (
  in path varchar,
  in node any)
{
  path := concat (path, '[not @place]');
  return xpath_eval (path, node, 0);
}
;

-------------------------------------------------------------------------------
--
-- Show functions
--
-------------------------------------------------------------------------------
--
create procedure ODRIVE.WA.show_text(
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
create procedure ODRIVE.WA.show_excerpt(
  in S varchar,
  in words varchar)
{
  return coalesce(search_excerpt (words, cast(S as varchar)), '');
}
;

-------------------------------------------------------------------------------
--
create procedure ODRIVE.WA.dashboard_rs(
  in p0 integer)
{
  declare account_id, vspxUser any;
  declare waiName, link varchar;

  declare c0 integer;
  declare c1 varchar;
  declare c2 varchar;
  declare c3 datetime;
  declare c4 integer;

  result_names(c0, c1, c2, c3, c4);
  account_id := ODRIVE.WA.domain_owner_id (p0);
  vspxUser := connection_get ('vspx_user');
  if (isnull (vspxUser))
  {
    for (select top 10 RES_ID,
                RES_FULL_PATH,
                RES_MOD_TIME,
                RES_NAME,
                RES_OWNER
           from WS.WS.SYS_DAV_RES
          where RES_FULL_PATH like '/DAV/home/%'
            and RES_OWNER = account_id
            and substring (RES_PERMS, 7, 1) = '1'
          order by RES_MOD_TIME desc) do
    {
      waiName := (select top 1 WAI_NAME from DB.DBA.WA_INSTANCE, DB.DBA.WA_MEMBER where WAI_TYPE_NAME = 'oDrive' and WAI_NAME = WAM_INST and WAM_MEMBER_TYPE = 1 and WAM_USER = RES_OWNER);
      link := case when isnull (waiName) then RES_FULL_PATH else SIOC..post_iri_ex (SIOC..briefcase_iri (waiName), RES_ID) end;
      result (RES_ID, RES_NAME, link, RES_MOD_TIME, RES_OWNER);
    }
  }
  else
  {
    for (select top 10 *
           from (select *
                   from (select top 10 RES_ID,
                                RES_FULL_PATH,
                                RES_MOD_TIME,
                                RES_NAME,
                                RES_OWNER
                           from WS.WS.SYS_DAV_RES
                                  join WS.WS.SYS_DAV_ACL_INVERSE on AI_PARENT_ID = RES_ID
                                    join WS.WS.SYS_DAV_ACL_GRANTS on GI_SUB = AI_GRANTEE_ID
                          where RES_FULL_PATH like '/DAV/home/%'
                            and AI_PARENT_TYPE = 'R'
                            and GI_SUPER = account_id
                            and AI_FLAG = 'G'
                          order by RES_MOD_TIME desc
                        ) acl
                 union
                 select *
                   from (select top 10 RES_ID,
                                RES_FULL_PATH,
                                RES_MOD_TIME,
                                RES_NAME,
                                RES_OWNER
                           from WS.WS.SYS_DAV_RES
                          where RES_FULL_PATH like '/DAV/home/' || vspxUser || '%'
                            and RES_OWNER = account_id
                            and RES_PERMS like '1%'
                          order by RES_MOD_TIME desc
                        ) own
                ) sub
          order by RES_MOD_TIME desc) do
    {
      waiName := (select top 1 WAI_NAME from DB.DBA.WA_INSTANCE, DB.DBA.WA_MEMBER where WAI_TYPE_NAME = 'oDrive' and WAI_NAME = WAM_INST and WAM_MEMBER_TYPE = 1 and WAM_USER = RES_OWNER);
      link := case when isnull (waiName) then RES_FULL_PATH else SIOC..post_iri_ex (SIOC..briefcase_iri (waiName), RES_ID) end;
      result (RES_ID, RES_NAME, link, RES_MOD_TIME, RES_OWNER);
    }
  }
}
;

-------------------------------------------------------------------------------
--
create procedure ODRIVE.WA.show_column_header (
  in columnLabel varchar,
  in columnName varchar,
  in sortOrder varchar,
  in sortDirection varchar := 'asc',
  in columnProperties varchar := '')
{
  declare class, image, onclick any;

  image := '';
  onclick := sprintf ('onclick="javascript: odsPost(this, [\'sortColumn\', \'%s\']);"', columnName);
    if (sortOrder = columnName)
    {
      if (sortDirection = 'desc')
      {
      image := '&nbsp;<img src="/ods/images/icons/orderdown_16.png" border="0" alt="Down"/>';
      }
      else if (sortDirection = 'asc')
      {
      image := '&nbsp;<img src="/ods/images/icons/orderup_16.png" border="0" alt="Up"/>';
    }
  }
  return sprintf ('<th %s %s>%s%s</th>', columnProperties, onclick, columnLabel, image);
}
;

-------------------------------------------------------------------------------
--
create procedure ODRIVE.WA.xslt_root()
{
  declare sHost varchar;

  sHost := cast(registry_get('_oDrive_path_') as varchar);
  if (sHost = '0')
    return 'file://apps/oDrive/xslt/';
  if (isnull(strstr(sHost, '/DAV/VAD')))
    return sprintf('file://%sxslt/', sHost);
  return sprintf('virt://WS.WS.SYS_DAV_RES.RES_FULL_PATH.RES_CONTENT:%sxslt/', sHost);
}
;

-------------------------------------------------------------------------------
--
create procedure ODRIVE.WA.xslt_full(
  in xslt_file varchar)
{
  return concat(ODRIVE.WA.xslt_root(), xslt_file);
}
;

-------------------------------------------------------------------------------
--
create procedure ODRIVE.WA.iri_fix (
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
create procedure ODRIVE.WA.url_fix (
  in S varchar,
  in sid varchar := null,
  in realm varchar := null)
{
  declare T varchar;

  T := '&';
  if (isnull (strchr (S, '?')))
  T := '?';

  if (not is_empty_or_null (sid))
  {
    S := S || T || 'sid=' || sid;
    T := '&';
  }
  if (not is_empty_or_null (realm))
    S := S || T || 'realm=' || realm;

  return S;
}
;

-------------------------------------------------------------------------------
--
create procedure ODRIVE.WA.exec (
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
-- Date / Time functions
--
-------------------------------------------------------------------------------
-- returns system time in GMT
--
create procedure ODRIVE.WA.dt_current_time()
{
  return dateadd('minute', - timezone(now()),now());
}
;

-------------------------------------------------------------------------------
--
-- convert from GMT date to user timezone;
--
create procedure ODRIVE.WA.dt_gmt2user(
  in pDate datetime,
  in pUser varchar := null)
{
  declare tz integer;

  if (isnull(pDate))
    return null;
  if (isnull(pUser))
    pUser := ODRIVE.WA.account();
  if (isnull(pUser))
    return pDate;
  tz := cast(coalesce(USER_GET_OPTION(pUser, 'TIMEZONE'), 0) as integer) * 60 - timezone(now());
  return dateadd('minute', tz, pDate);
};

-------------------------------------------------------------------------------
--
-- convert from the user timezone to GMT date
--
create procedure ODRIVE.WA.dt_user2gmt(
  in pDate datetime,
  in pUser varchar := null)
{
  declare tz integer;

  if (isnull(pDate))
    return null;
  if (isnull(pUser))
    pUser := ODRIVE.WA.account();
  if (isnull(pUser))
    return pDate;
  tz := cast(coalesce(USER_GET_OPTION(pUser, 'TIMEZONE'), 0) as integer) * 60;
  return dateadd('minute', -tz, pDate);
};

-----------------------------------------------------------------------------
--
create procedure ODRIVE.WA.dt_value(
  in pDate datetime,
  in pUser varchar := null)
{
  if (isnull(pDate))
    return pDate;
  pDate := ODRIVE.WA.dt_gmt2user(pDate, pUser);
  if (ODRIVE.WA.dt_format(pDate, 'D.M.Y') = ODRIVE.WA.dt_format(now(), 'D.M.Y'))
    return concat('today ', ODRIVE.WA.dt_format(pDate, 'H:N'));
  return ODRIVE.WA.dt_format(pDate, 'D.M.Y H:N');
}
;

-------------------------------------------------------------------------------
--
create procedure ODRIVE.WA.dt_format(
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

-------------------------------------------------------------------------------
--
create procedure ODRIVE.WA.dt_deformat(
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
    ch := upper(chr(pFormat[N]));
    if (ch = 'M')
      m := ODRIVE.WA.dt_deformat_tmp(pString, I);
    if (ch = 'D')
      d := ODRIVE.WA.dt_deformat_tmp(pString, I);
    if (ch = 'Y') {
      y := ODRIVE.WA.dt_deformat_tmp(pString, I);
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

-------------------------------------------------------------------------------
--
create procedure ODRIVE.WA.dt_deformat_tmp(
  in S varchar,
  inout N integer)
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

-------------------------------------------------------------------------------
--
create procedure ODRIVE.WA.dt_reformat(
  in pString varchar,
  in pInFormat varchar := 'd.m.Y',
  in pOutFormat varchar := 'm.d.Y')
{
  return ODRIVE.WA.dt_format(ODRIVE.WA.dt_deformat(pString, pInFormat), pOutFormat);
}
;

-----------------------------------------------------------------------------------------
--
create procedure ODRIVE.WA.dt_rfc1123 (
  in dt datetime)
{
  return soap_print_box (dt, '', 1);
}
;

-----------------------------------------------------------------------------------------
--
create procedure ODRIVE.WA.dt_iso8601 (
  in dt datetime)
{
  return soap_print_box (dt, '', 0);
}
;

-------------------------------------------------------------------------------
--  Converts XML Entity to String
-------------------------------------------------------------------------------
create procedure ODRIVE.WA.xml2string(
  in pXmlEntry any)
{
  declare sStream any;

  sStream := string_output();
  http_value(pXmlEntry, null, sStream);
  return string_output_string(sStream);
}
;

-------------------------------------------------------------------------------
--
create procedure ODRIVE.WA.isVector (
  inout aVector any)
{
  if (isarray (aVector) and not isstring (aVector))
    return 1;

  return 0;
}
;

-------------------------------------------------------------------------------
--  Returns:
--    N -  if pAny is in pArray
--   -1 -  otherwise
-------------------------------------------------------------------------------
create procedure ODRIVE.WA.vector_contains (
  inout aVector any,
  in value any)
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
create procedure ODRIVE.WA.vector_index (
  inout aVector any,
  in value any)
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
create procedure ODRIVE.WA.vector_cut(
  inout pVector any,
  in pIndex integer)
{
  declare N integer;
  declare retValue any;

  retValue := vector();
  for (N := 0; N < length(pVector); N := N + 1)
    if (N <> pIndex)
      retValue := vector_concat(retValue, vector(pVector[N]));
  return retValue;
};

-------------------------------------------------------------------------------
--
create procedure ODRIVE.WA.vector_unique(
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
create procedure ODRIVE.WA.vector2str(
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
create procedure ODRIVE.WA.members2rs(
  inout aMembers any)
{
  declare N integer;
  declare c0, c1 varchar;

  result_names(c0, c1);

  if (isnull(aMembers))
    return;

  for (N := 0; N < length(aMembers); N := N + 1)
    result(aMembers[N][0], aMembers[N][1]);
}
;

-------------------------------------------------------------------------------
--
create procedure ODRIVE.WA.str2vector(
  in S any)
{
  declare aResult any;

  declare w varchar;
  aResult := vector();
  w := regexp_match ('["][^"]+["]|[''][^'']+['']|[^"'' ]+', S, 1);
  while (w is not null) {
    w := trim (w, '"'' ');
    if (upper(w) not in ('AND', 'NOT', 'NEAR', 'OR') and length (w) > 1 and not vt_is_noise (ODRIVE.WA.wide2utf(w), 'utf-8', 'x-ViDoc'))
      aResult := vector_concat(aResult, vector(w));
    w := regexp_match ('["][^"]+["]|[''][^'']+['']|[^"'' ]+', S, 1);
  }
  return aResult;
}
;

-------------------------------------------------------------------------------
--
create procedure ODRIVE.WA.utf2wide (
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
create procedure ODRIVE.WA.wide2utf (
  inout S any)
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
create procedure ODRIVE.WA.stringCut (
  in S varchar,
  in L integer := 60)
{
  declare tmp any;

  if (not L)
    return S;
  tmp := ODRIVE.WA.utf2wide(S);
  if (not iswidestring(tmp))
    return S;
  if (length(tmp) > L)
    return ODRIVE.WA.wide2utf(concat(subseq(tmp, 0, L-3), '...'));
  return ODRIVE.WA.wide2utf(tmp);
}
;

-------------------------------------------------------------------------------
--
create procedure ODRIVE.WA.http_escape (
  in S any,
  in mode integer := 0) returns varchar
{
  declare sStream any;
  sStream := string_output();
  http_escape (S, mode, sStream, 0, 0);
  return string_output_string(sStream);
}
;

-------------------------------------------------------------------------------
--
create procedure ODRIVE.WA.set_keyword (
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
create procedure ODRIVE.WA.tag_prepare(
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
create procedure ODRIVE.WA.tag_delete(
  inout tags varchar,
  inout T any)
{
  declare N integer;
  declare new_tags any;

  new_tags := ODRIVE.WA.tags2vector (tags);
  tags := '';
  N := 0;
  foreach (any new_tag in new_tags) do {
    if (isstring(T) and (new_tag <> T))
      tags := concat(tags, ',', new_tag);
    if (isinteger(T) and (N <> T))
      tags := concat(tags, ',', new_tag);
    N := N + 1;
  }
  return trim(tags, ',');
}
;

---------------------------------------------------------------------------------
--
create procedure ODRIVE.WA.tags_join(
  inout tags varchar,
  inout tags2 varchar)
{
  declare resultTags any;

  if (is_empty_or_null(tags))
    tags := '';
  if (is_empty_or_null(tags2))
    tags2 := '';

  resultTags := concat(tags, ',', tags2);
  resultTags := ODRIVE.WA.tags2vector(resultTags);
  resultTags := ODRIVE.WA.tags2unique(resultTags);
  resultTags := ODRIVE.WA.vector2tags(resultTags);
  return resultTags;
}
;

---------------------------------------------------------------------------------
--
create procedure ODRIVE.WA.tags2vector(
  inout tags varchar)
{
  return split_and_decode(trim(tags, ','), 0, '\0\0,');
}
;

-------------------------------------------------------------------------------
--
create procedure ODRIVE.WA.vector2tags(
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
create procedure ODRIVE.WA.tags2unique(
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
create procedure ODRIVE.WA.tagsDictionary2rs(
  inout aDictionary any)
{
  declare N integer;
  declare c0, c2 varchar;
  declare c1 integer;
  declare V any;

  V := dict_to_vector(aDictionary, 1);
  result_names(c0, c1, c2);
  for (N := 1; N < length(V); N := N + 2)
    result(V[N][0], V[N][1], V[N][2]);
}
;

-------------------------------------------------------------------------------
--
create procedure ODRIVE.WA.hiddens_prepare (
  inout hiddens any)
{
  declare exit handler for SQLSTATE '*'
  {
    return vector ();
  };

  declare V any;

  V := split_and_decode ( hiddens, 0 , '\0\0,');

  return V;
}
;

-------------------------------------------------------------------------------
--
create procedure ODRIVE.WA.hiddens_check (
  inout hiddens any,
  inout name varchar)
{
  if (length (name) = 0)
    return 0;
  if (length (hiddens) = 0)
    return 0;

  declare N integer;

  for (N := 0; N < length (hiddens); N := N + 1)
  {
    if (strstr (name, trim (hiddens[N])) = 0)
      return 1;
  }
  return 0;
}
;

-------------------------------------------------------------------------------
--
create procedure ODRIVE.WA.odrive_proc(
  in path varchar,
  in dir_mode integer := 0,
  in dir_params any := null,
  in dir_hiddens any := null,
  in dir_account any := null,
  in dir_password any := null) returns any
{
  declare i, pos integer;
  declare tmp, dirFilter, dirHiddens, dirList, sharedRoot, sharedFilter, sharedPath, sharedList any;
  declare vspx_user, user_name, group_name varchar;
  declare user_id, group_id integer;
  declare c2 integer;
  declare c0, c1, c3, c4, c5, c6, c7, c8, c9 varchar;

  result_names(c0, c1, c2, c3, c4, c5, c6, c7, c8, c9);

  if (is_empty_or_null(path))
  {
    dirList := ODRIVE.WA.odrive_shortcuts();
    for (i := 0; i < length(dirList); i := i + 2)
      result(dirList[i], 'C', 0, '', '', '', '', '', concat('/', dirList[i], '/'));
    return;
  }

  declare exit handler for SQLSTATE '*'
  {
  	-- dbg_obj_print ('', __SQL_STATE, __SQL_MESSAGE);
    result(__SQL_STATE, substring (__SQL_MESSAGE, 1, 255), 0, '', '', '', '', '', '');
    return;
  };

  dirList := vector();
  if (dir_mode = 0)
  {
    if (path = ODRIVE.WA.shared_name())
    {
      vspx_user := ODRIVE.WA.account();
      dirList := ODRIVE.WA.odrive_sharing_dir_list(vspx_user);
    } else {
      path := ODRIVE.WA.odrive_real_path(path);
      dirList := ODRIVE.WA.DAV_DIR_LIST(path, 0);
    }
    dirFilter := '%';
  }
  else if (dir_mode = 1)
  {
    path := ODRIVE.WA.odrive_real_path(path);
    dirList := ODRIVE.WA.DAV_DIR_LIST(path, 0);
    dirFilter := ODRIVE.WA.dc_search_like_fix (dir_params);
  }
  else if ((dir_mode = 2) or (dir_mode = 3))
  {
    if (dir_mode = 2)
    {
      path := ODRIVE.WA.odrive_real_path(path);
      dirFilter := vector (vector('RES_NAME', 'like', ODRIVE.WA.dc_search_like_fix (dir_params)));
    }
    else
    {
      path := ODRIVE.WA.odrive_real_path(ODRIVE.WA.dc_get (dir_params, 'base', 'path', '/DAV/'));
      dirFilter := ODRIVE.WA.dc_filter(dir_params);
    }
    if (trim(path, '/') = ODRIVE.WA.shared_name())
    {
      sharedRoot := ODRIVE.WA.odrive_sharing_dir_list ( coalesce (dir_account, ODRIVE.WA.account ()));
      foreach (any item in sharedRoot) do
      {
        if (item[1] = 'C')
        {
          sharedList := ODRIVE.WA.DAV_DIR_FILTER(item[0], 1, dirFilter);
        }
        else
        {
          pos := strrchr (item[0], '/');
          if (not isnull(pos))
          {
            sharedPath := subseq (item[0], 0, pos+1);
            sharedFilter := dirFilter;
            sharedFilter := vector_concat (sharedFilter, vector (vector ('RES_NAME', '=', item[10])));
            sharedList := ODRIVE.WA.DAV_DIR_FILTER (sharedPath, 0, sharedFilter, dir_account, dir_password);
          }
        }
        if (isarray(sharedList))
          dirList := vector_concat(dirList, sharedList);
      }
    }
    else
    {
      dirList := ODRIVE.WA.DAV_DIR_FILTER(path, 1, dirFilter);
    }
    dirFilter := '%';
  }
  else if (dir_mode = 10)
  {
    dirFilter := vector();
    ODRIVE.WA.dc_subfilter(dirFilter, 'RES_NAME', 'like', dir_params);
    dirList := DB.DBA.DAV_DIR_FILTER(path, 1, dirFilter, dir_account, ODRIVE.WA.DAV_API_PWD(dir_account));
    dirFilter := '%';
  }
  else if (dir_mode = 11)
  {
    path := ODRIVE.WA.odrive_real_path(ODRIVE.WA.dc_get(dir_params, 'base', 'path', '/DAV/'));
    dirFilter := ODRIVE.WA.dc_filter(dir_params);
    dirList := DB.DBA.DAV_DIR_FILTER(path, 1, dirFilter, dir_account, ODRIVE.WA.DAV_API_PWD(dir_account));
    dirFilter := '%';
  }
  else if (dir_mode = 20)
  {
    path := ODRIVE.WA.dc_get(dir_params, 'base', 'path', '/DAV/');
    dirFilter := ODRIVE.WA.dc_filter(dir_params);
    dirList := DB.DBA.DAV_DIR_FILTER(path, 1, dirFilter, dir_account, dir_password);
    dirFilter := '%';
  }
  if (isarray(dirList))
  {
    dirHiddens := ODRIVE.WA.hiddens_prepare (dir_hiddens);
    user_id := -1;
    group_id := -1;
    user_name := '';
    group_name := '';
    foreach (any item in dirList) do
    {
      if (isarray(item) and not isnull (item[0]))
      {
        if (((item[1] = 'C') or (item[10] like dirFilter)) and (ODRIVE.WA.hiddens_check (dirHiddens, item[10]) = 0))
        {
          if (user_id <> coalesce (item[7], -1))
          {
            user_id := coalesce (item[7], -1);
            user_name := ODRIVE.WA.odrive_user_name (user_id, '');
          }
          if (group_id <> coalesce (item[6], -1))
          {
            group_id := coalesce (item[6], -1);
            group_name := ODRIVE.WA.odrive_user_name (group_id, '');
          }
          tmp := coalesce((select RS_CATNAME from WS.WS.SYS_RDF_SCHEMAS, WS.WS.SYS_MIME_RDFS where RS_URI = MR_RDF_URI and MR_MIME_IDENT = item[9]), '~unknown~');
          result(item[either(gte(dir_mode,2),0,10)], item[1], item[2], left(cast(item[3] as varchar), 19), item[9], user_name, group_name, adm_dav_format_perms(item[5]), item[0], tmp);
        }
    }
  }
}
}
;

-----------------------------------------------------------------------------
--
create procedure ODRIVE.WA.odrive_effective_permissions (
  inout path varchar,
  in permission varchar := '1__')
{
  declare N, I, nPermission integer;
  declare rc, id, type, item any;
  declare lines, name, pwd, uid, gid, permissions any;
  declare auth_name varchar;

  if (isstring(permission))
    permission := vector(permission);

  name := null;
  uid := null;
  gid := null;
  id := ODRIVE.WA.DAV_SEARCH_ID (path, type);
  for (N := 0; N < length (permission); N := N + 1)
  {
    if (DB.DBA.DAV_AUTHENTICATE (id, type, permission[N], name, uid, gid))
      return 1;
  }
  
  item := ODRIVE.WA.DAV_INIT(path);
  if (isinteger(item))
    return 0;

  auth_name := ODRIVE.WA.account();
  uid := (select U_ID from DB.DBA.SYS_USERS where U_NAME = auth_name);
  gid := (select U_GROUP from DB.DBA.SYS_USERS where U_NAME = auth_name);

  if (isinteger(ODRIVE.WA.DAV_GET(item, 'id')))
  {
    if (ODRIVE.WA.DAV_GET(item, 'ownerID') = uid)
      return 1;
    if (uid = http_dav_uid())
      return 1;
    if (uid = 0)
      return 1;
    if (uid = 2)
      return 1;
    if (gid = 3)
      return 1;
    if (auth_name = 'dba')
      return 1;
  }

  for (N := 0; N < length (permission); N := N + 1)
  {
    if (DB.DBA.DAV_CHECK_PERM(ODRIVE.WA.DAV_GET(item, 'permissions'), permission[N], uid, gid, ODRIVE.WA.DAV_GET(item, 'groupID'), ODRIVE.WA.DAV_GET(item, 'ownerID')))
      return 1;

    nPermission := 0;
    for (I := 0; I < length(permission[N]); I := I + 1) {
      nPermission := 2*nPermission;
      if (permission[N][I] = ascii('1'))
        nPermission := nPermission + 1;
    }
    if (WS.WS.ACL_IS_GRANTED(ODRIVE.WA.DAV_GET(item, 'acl'), uid, nPermission))
      return 1;
  }
  return 0;
}
;

-----------------------------------------------------------------------------
--
create procedure ODRIVE.WA.odrive_permission (
  in path varchar)
{
  if ('/' = path)
    return '';
  path := ODRIVE.WA.odrive_real_resource(path);
  if (path = concat('/', ODRIVE.WA.shared_name(), '/'))
    return 'R';
  if (ODRIVE.WA.odrive_effective_permissions(path, '_1_'))
    return 'W';
  if (ODRIVE.WA.odrive_effective_permissions(path, vector('1__', '__1')))
    return 'R';
  return ('');
}
;

-----------------------------------------------------------------------------
--
create procedure ODRIVE.WA.odrive_read_permission (
  in path varchar)
{
  return ODRIVE.WA.odrive_effective_permissions(path, vector('1__', '__1'));
}
;

-----------------------------------------------------------------------------
--
create procedure ODRIVE.WA.odrive_write_permission (
  in path varchar)
{
  return ODRIVE.WA.odrive_effective_permissions(path, '_1_');
}
;

-----------------------------------------------------------------------------
--
create procedure ODRIVE.WA.odrive_exec_permission (
  inout path varchar)
{
  return ODRIVE.WA.odrive_effective_permissions(path, '__1');
}
;

-------------------------------------------------------------------------------
--
create procedure ODRIVE.WA.domain_owner_id (
  inout domain_id integer)
{
  return (select A.WAM_USER from WA_MEMBER A, WA_INSTANCE B where A.WAM_MEMBER_TYPE = 1 and A.WAM_INST = B.WAI_NAME and B.WAI_ID = domain_id);
}
;

-------------------------------------------------------------------------------
--
create procedure ODRIVE.WA.domain_owner_name (
  inout domain_id integer)
{
  return (select C.U_NAME from WA_MEMBER A, WA_INSTANCE B, SYS_USERS C where A.WAM_MEMBER_TYPE = 1 and A.WAM_INST = B.WAI_NAME and B.WAI_ID = domain_id and C.U_ID = A.WAM_USER);
}
;

-------------------------------------------------------------------------------
--
create procedure ODRIVE.WA.domain_id (
  in domain_name varchar)
{
  return (select WAI_ID from DB.DBA.WA_INSTANCE where WAI_NAME = domain_name);
}
;

-------------------------------------------------------------------------------
--
create procedure ODRIVE.WA.domain_name (
  in domain_id integer)
{
  return coalesce((select WAI_NAME from DB.DBA.WA_INSTANCE where WAI_ID = domain_id), 'Briefcase Instance');
}
;

-------------------------------------------------------------------------------
--
create procedure ODRIVE.WA.domain_description (
  in domain_id integer)
{
  return coalesce((select coalesce(WAI_DESCRIPTION, WAI_NAME) from DB.DBA.WA_INSTANCE where WAI_ID = domain_id), 'Briefcase Instance');
}
;

-------------------------------------------------------------------------------
--
create procedure ODRIVE.WA.domain_is_public (
  in domain_id integer)
{
  return coalesce((select WAI_IS_PUBLIC from DB.DBA.WA_INSTANCE where WAI_ID = domain_id), 0);
}
;

-------------------------------------------------------------------------------
--
create procedure ODRIVE.WA.domain_ping (
  in domain_id integer)
{
  for (select WAI_NAME, WAI_DESCRIPTION from DB.DBA.WA_INSTANCE where WAI_ID = domain_id and WAI_IS_PUBLIC = 1) do
  {
    ODS..APP_PING (WAI_NAME, coalesce (WAI_DESCRIPTION, WAI_NAME), ODRIVE.WA.sioc_url (domain_id));
  }
}
;

-------------------------------------------------------------------------------
--
create procedure ODRIVE.WA.forum_iri (
  in domain_id integer)
{
  return SIOC..briefcase_iri (ODRIVE.WA.domain_name (domain_id));
}
;

-------------------------------------------------------------------------------
--
create procedure ODRIVE.WA.domain_sioc_url (
  in domain_id integer,
  in sid varchar := null,
  in realm varchar := null)
{
  declare S varchar;

  S := ODRIVE.WA.iri_fix (ODRIVE.WA.forum_iri (domain_id));
  return ODRIVE.WA.url_fix (S, sid, realm);
}
;

-------------------------------------------------------------------------------
--
create procedure ODRIVE.WA.page_url (
  in domain_id integer,
  in page varchar := null,
  in sid varchar := null,
  in realm varchar := null)
{
  declare S varchar;

  S := ODRIVE.WA.iri_fix (ODRIVE.WA.forum_iri (domain_id));
  if (not isnull (page))
    S := S || '/' || page;
  return ODRIVE.WA.url_fix (S, sid, realm);
}
;

-----------------------------------------------------------------------------
--
create procedure ODRIVE.WA.account() returns varchar
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
create procedure ODRIVE.WA.account_id (
  in account_name varchar)
{
  return coalesce ((select U_ID from DB.DBA.SYS_USERS where U_NAME = account_name), -1);
}
;

-------------------------------------------------------------------------------
--
create procedure ODRIVE.WA.account_name (
  in account_id integer)
{
  return (select U_NAME from DB.DBA.SYS_USERS where U_ID = account_id);
}
;

-------------------------------------------------------------------------------
--
create procedure ODRIVE.WA.account_password (
  in account_id integer)
{
  return coalesce ((select pwd_magic_calc(U_NAME, U_PWD, 1) from WS.WS.SYS_DAV_USER where U_ID = account_id), '');
}
;

----------------------------------------------------------------------------------------------------------------
--
create procedure ODRIVE.WA.account_fullName (
  in account_id integer)
{
  return coalesce ((select ODRIVE.WA.user_name (U_NAME, U_FULL_NAME) from DB.DBA.SYS_USERS where U_ID = account_id), '');
}
;

-------------------------------------------------------------------------------
--
create procedure ODRIVE.WA.account_mail(
  in account_id integer)
{
  return coalesce((select U_E_MAIL from DB.DBA.SYS_USERS where U_ID = account_id), '');
}
;

-------------------------------------------------------------------------------
--
create procedure ODRIVE.WA.account_iri (
  in account_id integer)
{
  declare exit handler for sqlstate '*'
  {
    return ODRIVE.WA.account_name (account_id);
  };
  return SIOC..person_iri (SIOC..user_iri (account_id, null));
}
;

-------------------------------------------------------------------------------
--
create procedure ODRIVE.WA.account_inverse_iri (
  in account_iri varchar)
{
  declare params any;

  params := sprintf_inverse (account_iri, 'http://%s/dataspace/person/%s#this', 1);
  if (length (params) <> 2)
    return -1;

  return coalesce ((select U_ID from DB.DBA.SYS_USERS where U_NAME = params[1]), -1);
}
;

-------------------------------------------------------------------------------
--
create procedure ODRIVE.WA.account_sioc_url (
  in domain_id integer,
  in sid varchar := null,
  in realm varchar := null)
{
  declare S varchar;

  S := ODRIVE.WA.iri_fix (ODRIVE.WA.account_iri (ODRIVE.WA.domain_owner_id (domain_id)));
  return ODRIVE.WA.url_fix (S, sid, realm);
}
;

-------------------------------------------------------------------------------
--
create procedure ODRIVE.WA.account_basicAuthorization (
  in account_id integer)
{
  declare account_name, account_password varchar;

  account_name := ODRIVE.WA.account_name (account_id);
  account_password := ODRIVE.WA.account_password (account_id);
  return sprintf ('Basic %s', encode_base64 (account_name || ':' || account_password));
}
;

----------------------------------------------
--
create procedure ODRIVE.WA.user_name(
  in u_name any,
  in u_full_name any) returns varchar
{
  if (not is_empty_or_null(trim(u_full_name)))
    return trim (u_full_name);
  return u_name;
}
;

-----------------------------------------------------------------------------
--
create procedure ODRIVE.WA.odrive_user_name(
  in user_id integer,
  in unknown varchar := '~unknown~') returns varchar
{
  if (not isnull(user_id))
    return coalesce((select U_NAME from DB.DBA.SYS_USERS where U_ID = user_id), unknown);
  return '~none~';
}
;

-----------------------------------------------------------------------------
--
create procedure ODRIVE.WA.odrive_group_own(
  in group_name varchar,
  in user_name varchar := null) returns integer
{
  if (is_empty_or_null(group_name))
    return 1;
  if (group_name = 'dav')
    return 1;
  if (isnull(user_name))
    user_name := ODRIVE.WA.account();
  if (exists(select 1 from DB.DBA.SYS_USERS u1, DB.DBA.WA_GROUPS g, DB.DBA.SYS_USERS u2 where u1.U_NAME=group_name and u1.U_ID=g.WAG_GROUP_ID and u1.U_IS_ROLE=1 and g.WAG_USER_ID=u2.U_ID and u2.U_NAME=user_name))
    return 1;
  return 0;
}
;

-----------------------------------------------------------------------------
--
create procedure ODRIVE.WA.odrive_user_id(
  in user_name varchar) returns integer
{
  return coalesce((select U_ID from DB.DBA.SYS_USERS where U_NAME = user_name), -1);
}
;

-----------------------------------------------------------------------------
--
create procedure ODRIVE.WA.odrive_user_initialize(
  in user_name varchar) returns varchar
{
  declare user_home, new_folder varchar;
  declare uid, gid, cid integer;
  declare retCode any;

  user_home := ODRIVE.WA.dav_home_create(user_name);
  if (isinteger(user_home))
    signal ('BRF01', sprintf ('Home folder can not be created for user "%s".', user_name));

  DB.DBA.DAV_OWNER_ID(user_name, null, uid, gid);
  cid := DB.DBA.DAV_SEARCH_ID(user_home, 'C');
  if (not ODRIVE.WA.DAV_ERROR (cid))
  {
    if ((select count(*) from WS.WS.SYS_DAV_COL where COL_PARENT = cid and COL_DET = 'CatFilter') = 0)
    {
      new_folder := concat(user_home, 'Items/');
      cid := DB.DBA.DAV_SEARCH_ID(new_folder, 'C');
      if (ODRIVE.WA.DAV_ERROR(cid))
        cid := DB.DBA.DAV_MAKE_DIR (new_folder, uid, gid, '110100100R');
      if (ODRIVE.WA.DAV_ERROR(cid))
        signal ('BRF02', concat('User''s category folder ''Items'' can not be created. ', ODRIVE.WA.DAV_PERROR(cid)));
      retCode := ODRIVE.WA.CatFilter_CONFIGURE_INT(new_folder, user_home, vector());
    }
    new_folder := concat(user_home, 'Public/');
    cid := DB.DBA.DAV_SEARCH_ID(new_folder, 'C');
    if (ODRIVE.WA.DAV_ERROR(cid))
      cid := DB.DBA.DAV_MAKE_DIR (new_folder, uid, gid, '110100100R');
    if (ODRIVE.WA.DAV_ERROR(cid))
      signal ('BRF03', concat('User''s folder ''Public'' can not be created.', ODRIVE.WA.DAV_PERROR(cid)));
  }
}
;

-------------------------------------------------------------------------------
--
create procedure ODRIVE.WA.host_protocol ()
{
  return case when is_https_ctx () then 'https://' else 'http://' end;
}
;

-------------------------------------------------------------------------------
--
create procedure ODRIVE.WA.host_url ()
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
      if (hpa [1] <> '80')
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
  if (host not like ODRIVE.WA.host_protocol () || '%')
    host := ODRIVE.WA.host_protocol () || host;

  return host;
}
;

-------------------------------------------------------------------------------
--
create procedure ODRIVE.WA.odrive_url (
  in domain_id integer)
{
  return concat(ODRIVE.WA.host_url(), '/odrive/', cast (domain_id as varchar), '/');
}
;

-------------------------------------------------------------------------------
--
create procedure ODRIVE.WA.sioc_url (
  in domain_id integer)
{
  return sprintf('%s/dataspace/%U/briefcase/%U/sioc.rdf', ODRIVE.WA.host_url (), ODRIVE.WA.domain_owner_name (domain_id), replace (ODRIVE.WA.domain_name (domain_id), '+', '%2B'));
}
;

-------------------------------------------------------------------------------
--
create procedure ODRIVE.WA.geo_url (
  in domain_id integer,
  in account_id integer)
{
  for (select WAUI_LAT, WAUI_LNG from WA_USER_INFO where WAUI_U_ID = account_id) do
    if ((not isnull(WAUI_LNG)) and (not isnull(WAUI_LAT)))
      return sprintf('\n    <meta name="ICBM" content="%.2f, %.2f"><meta name="DC.title" content="%s">', WAUI_LNG, WAUI_LAT, ODRIVE.WA.domain_name (domain_id));
  return '';
}
;

-------------------------------------------------------------------------------
--
create procedure ODRIVE.WA.dav_url (
  in path varchar)
{
  if (path[length (path)-1] <> ascii('/'))
    path := subseq (path, 4);
  return ODRIVE.WA.host_url() || path;
}
;

-------------------------------------------------------------------------------
--
create procedure ODRIVE.WA.banner_links (
  in domain_id integer,
  in sid varchar := null,
  in realm varchar := null)
{
  if (domain_id <= 0)
    return 'Public Briefcase';

  return sprintf ('<a href="%s" title="%s" onclick="javascript: return myA(this);">%V</a> (<a href="%s" title="%s" onclick="javascript: return myA(this);">%V</a>)',
                  ODRIVE.WA.domain_sioc_url (domain_id),
                  ODRIVE.WA.domain_name (domain_id),
                  ODRIVE.WA.domain_name (domain_id),
                  ODRIVE.WA.account_sioc_url (domain_id),
                  ODRIVE.WA.account_fullName (ODRIVE.WA.domain_owner_id (domain_id)),
                  ODRIVE.WA.account_fullName (ODRIVE.WA.domain_owner_id (domain_id))
                 );
}
;

-----------------------------------------------------------------------------
--
create procedure ODRIVE.WA.dav_home (
  in user_name varchar := null) returns varchar
{
  declare user_home any;
  declare colID integer;

  if (isnull(user_name))
    user_name := ODRIVE.WA.account();
  user_home := ODRIVE.WA.dav_home_create(user_name);
  if (isinteger(user_home))
    return '/DAV/';
  colID := DB.DBA.DAV_SEARCH_ID(user_home, 'C');
  if (isinteger(colID) and (colID > 0))
    return user_home;
  return '/DAV/';
}
;

-----------------------------------------------------------------------------
--
create procedure ODRIVE.WA.dav_home2 (
  in user_id integer,
  in user_role varchar := 'public')
{
  declare user_name, user_home any;
  declare colID integer;

  user_name := (select U_NAME from DB.DBA.SYS_USERS where U_ID = user_id);
  user_home := ODRIVE.WA.dav_home_create (user_name);
  if (isinteger (user_home))
    return '/DAV/';
  colID := DB.DBA.DAV_SEARCH_ID (user_home, 'C');
  if (isinteger (colID) and (colID > 0))
  {
    if (user_role <> 'public')
      return user_home;
    return user_home || 'Public/';
  }
  return '/DAV/';
}
;

-----------------------------------------------------------------------------
--
create procedure ODRIVE.WA.dav_home_create(
  in user_name varchar) returns any
{
  declare user_id integer;
  declare user_home varchar;

  whenever not found goto _error;

  if (is_empty_or_null(user_name))
    goto _error;
  user_home := DB.DBA.DAV_HOME_DIR(user_name);
  if (isstring(user_home)) {
    if (not ODRIVE.WA.DAV_ERROR(DB.DBA.DAV_SEARCH_ID(user_home, 'C')))
      return user_home;
  }
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
create procedure ODRIVE.WA.dav_logical_home (
  inout account_id integer) returns varchar
{
  declare home any;

  home := ODRIVE.WA.dav_home2 (account_id);
  if (not isnull (home))
    home := replace (home, '/DAV', '');
  return home;
}
;

-----------------------------------------------------------------------------
--
create procedure ODRIVE.WA.odrive_refine_path(
  in path varchar) returns varchar
{
  path := replace(path, '\\', '/');
  path := replace(path, '//', '/');
  return trim(path, '/');
}
;

-----------------------------------------------------------------------------
--
create procedure ODRIVE.WA.odrive_real_path_int(
  in path varchar,
  in showType integer := 0,
  in pathType varchar := 'C') returns varchar
{
  declare N, id integer;
  declare part, clearPath varchar;
  declare parts, clearParts any;

  parts := split_and_decode (ODRIVE.WA.odrive_refine_path(path), 0, '\0\0/');
  clearParts := vector();
  for (N := 0; N < length (parts); N := N + 1)
  {
    part := trim (parts[N], '"');
    --part := parts[N];
    if (length(clearParts) = 0)
      part := ODRIVE.WA.odrive_shortcut_path(parts, N, showType, pathType);
    if (length(clearParts) = 1)
      ODRIVE.WA.odrive_name_restore(part, part, id);
    if (part = '..')
      clearParts := ODRIVE.WA.vector_cut(clearParts, length(clearParts)-1);
    else if (part <> '.')
      clearParts := vector_concat(clearParts, vector(part));
  }
  clearPath := '/';
  for (N := 0; N < length(clearParts); N := N + 1)
    clearPath := concat(clearPath, clearParts[N], '/');
  if (pathType = 'R')
    clearPath := rtrim(clearPath, '/');
  return clearPath;
}
;

-----------------------------------------------------------------------------
--
create procedure ODRIVE.WA.odrive_real_path(
  in path varchar,
  in showType integer := 1,
  in pathType varchar := 'C')
{
  return ODRIVE.WA.odrive_real_path_int (path, showType, pathType);
}
;

-----------------------------------------------------------------------------
--
create procedure ODRIVE.WA.path_show(
  in path varchar) returns varchar
{
  return trim(ODRIVE.WA.odrive_real_path_int(path), '/');
}
;

-----------------------------------------------------------------------------
--
create procedure ODRIVE.WA.odrive_real_resource(
  in path varchar) returns varchar
{
  return ODRIVE.WA.odrive_real_path_int(path, 1, either(equ(right(path, 1), '/'), 'C', 'R'));
}
;

-----------------------------------------------------------------------------
--
create procedure ODRIVE.WA.odrive_name_dav() returns varchar
{
  return 'DAV';
}
;

-----------------------------------------------------------------------------
--
create procedure ODRIVE.WA.odrive_name_home() returns varchar
{
  return 'Home';
}
;

-----------------------------------------------------------------------------
--
create procedure ODRIVE.WA.shared_name() returns varchar
{
  return 'Shared Resources';
}
;

-----------------------------------------------------------------------------
--
create procedure ODRIVE.WA.path_is_shortcut(
  in path varchar) returns integer
{
  return case when (get_keyword (ODRIVE.WA.odrive_refine_path (path), ODRIVE.WA.odrive_shortcuts ()) <> null) then 1 else 0 end;
}
;

-----------------------------------------------------------------------------
--
create procedure ODRIVE.WA.path_compare(
  in lPath varchar,
  in rPath varchar) returns integer
{
  if (trim(ODRIVE.WA.odrive_real_path_int(lPath), '/') = trim(ODRIVE.WA.odrive_real_path_int(rPath), '/'))
    return 1;
  return 0;
}
;

-----------------------------------------------------------------------------
--
create procedure ODRIVE.WA.odrive_shortcuts() returns any
{
  declare shortcuts any;
  declare exit handler for SQLSTATE '*' {return shortcuts;};

  shortcuts := vector (ODRIVE.WA.odrive_name_home(), vector(trim(ODRIVE.WA.dav_home (), '/'), 0), ODRIVE.WA.shared_name(), vector(ODRIVE.WA.shared_name(), 1));
  if (trim(ODRIVE.WA.dav_home (), '/') = 'DAV')
    return shortcuts;
  if (not ODRIVE.WA.odrive_read_permission('/DAV/'))
    return shortcuts;
  return vector_concat(vector(ODRIVE.WA.odrive_name_dav(), vector('DAV', 0)), shortcuts);
}
;

-----------------------------------------------------------------------------
--
create procedure ODRIVE.WA.odrive_all_shortcuts() returns any
{
  declare shortcuts any;
  declare exit handler for SQLSTATE '*' {return shortcuts;};

  shortcuts := vector(ODRIVE.WA.odrive_name_home(), vector(trim(ODRIVE.WA.dav_home (), '/'), 0), ODRIVE.WA.shared_name(), vector(ODRIVE.WA.shared_name(), 1));
  return vector_concat(vector(ODRIVE.WA.odrive_name_dav(), vector('DAV', 0)), shortcuts);
}
;

-----------------------------------------------------------------------------
--
create procedure ODRIVE.WA.odrive_shortcut_path(
  in parts varchar,
  in N integer,
  in showType integer,
  in pathType varchar) returns any
{
  declare shortcut varchar;

  shortcut := get_keyword(parts[N], ODRIVE.WA.odrive_all_shortcuts ());
  if (isnull(shortcut))
    return parts[N];
  if (not isinteger(shortcut[showType]))
    return shortcut[showType];
  if (shortcut[showType] = 0)
    return shortcut[0];
  if (shortcut[showType] = 1)
  {
    if (N+1 < length (parts))
    {
      declare name varchar;
      declare id integer;

      ODRIVE.WA.odrive_name_restore(parts[N+1], name, id);
      if (not isnull (id))
      {
        if (pathType = 'R')
        {
          for (select RES_FULL_PATH from WS.WS.SYS_DAV_RES where RES_ID = id) do
            return left(trim(RES_FULL_PATH, '/'), strrchr(trim(RES_FULL_PATH, '/'), '/'));
        }
        if (pathType = 'C')
        {
          for (select WS.WS.COL_PATH(COL_ID) as COL_FULL_PATH from WS.WS.SYS_DAV_COL where COL_ID = id) do
            return left(trim(COL_FULL_PATH, '/'), strrchr(trim(COL_FULL_PATH, '/'), '/'));
        }
      } else {
        declare path varchar;
        declare uid integer;
        declare gid integer;
        DB.DBA.DAV_OWNER_ID(ODRIVE.WA.account(), null, uid, gid);

        if (pathType = 'R')
        {
          for (select TOP 1 RES_FULL_PATH
                 from WS.WS.SYS_DAV_RES
                        join WS.WS.SYS_DAV_ACL_INVERSE on AI_PARENT_ID = RES_ID
                          join WS.WS.SYS_DAV_ACL_GRANTS on GI_SUPER = AI_GRANTEE_ID
                where AI_PARENT_TYPE = 'R'
                  and GI_SUB = uid
                  and AI_FLAG = 'G'
                  and RES_FULL_PATH like concat('%/', parts[N+1])
                order by RES_NAME, RES_ID
              ) do
          {
            return left(trim(RES_FULL_PATH, '/'), strrchr(trim(RES_FULL_PATH, '/'), '/'));
          }
        }
        else if (pathType = 'C')
        {
          for (select TOP 1 WS.WS.COL_PATH(COL_ID) as COL_FULL_PATH
                 from WS.WS.SYS_DAV_COL
                        join WS.WS.SYS_DAV_ACL_INVERSE on AI_PARENT_ID = COL_ID
                          join WS.WS.SYS_DAV_ACL_GRANTS on GI_SUPER = AI_GRANTEE_ID
                where AI_PARENT_TYPE = 'C'
                  and GI_SUB = uid
                  and AI_FLAG = 'G'
                  and WS.WS.COL_PATH(COL_ID) like concat('%/', parts[N+1], '/')
                order by COL_NAME, COL_ID
              ) do
          {
            return left(trim(COL_FULL_PATH, '/'), strrchr(trim(COL_FULL_PATH, '/'), '/'));
          }
        }
      }
    }
  }
  return parts[N];
}
;

-------------------------------------------------------------------------------
--
create procedure ODRIVE.WA.prop_right (
  in property any,
  in user_id any := null)
{
  if (ODRIVE.WA.check_admin (user_id))
    return 1;
  if (property like 'DAV:%')
    return 0;
  if (property like 'xml-%')
    return 0;
  if (property like 'xper-%')
    return 0;
  return 1;
}
;

-------------------------------------------------------------------------------
--
create procedure ODRIVE.WA.prop_params (
  inout params any,
  in user_id any := null)
{
  declare N integer;
  declare c_properties, c_seq, c_property, c_value, c_action any;

  c_properties := vector ();
  for (N := 0; N < length (params); N := N + 2)
  {
    if (params[N] like 'c_fld_1_%')
    {
      c_seq := replace (params[N], 'c_fld_1_', '');
      c_property := trim (params[N+1]);
      if ((c_property <> '') and (not ODRIVE.WA.prop_right (c_property, user_id)))
      {
        signal ('TEST', 'Property name is empty or prefix is not allowed!');
      }
      c_value := trim (get_keyword ('c_fld_2_' || c_seq, params, ''));
      {
        declare exit handler for sqlstate '*' { goto _error; };
        if (isarray (xml_tree (c_value, 0)))
          c_value := serialize (xml_tree (c_value));
      }
    _error:;
      c_action := get_keyword ('c_fld_3_' || c_seq, params, '');
      c_properties := vector_concat (c_properties, vector (vector (c_property, c_value, c_action)));
    }
  }
  return c_properties;
}
;

-------------------------------------------------------------------------------
--
create procedure ODRIVE.WA.acl_params (
  inout params any,
  in acl_dav any := null)
{
  declare I, N integer;
  declare acl_value, acl_seq, acl_users, acl_user, acl_inheritance any;

  acl_value := WS.WS.ACL_CREATE();
  if (not isnull (acl_dav))
  {
    acl_dav := WS.WS.ACL_PARSE (acl_dav, '3', 0);
    for (I := 0; I < length (acl_dav); I := I + 1)
    {
      WS.WS.ACL_ADD_ENTRY (acl_value, acl_dav[I][0], acl_dav[I][3], acl_dav[I][1], acl_dav[I][2]);
    }
  }
  for (I := 0; I < length (params); I := I + 2)
  {
    if (params[I] like 'f_fld_1_%')
    {
      acl_seq := replace (params[I], 'f_fld_1_', '');
      acl_users := split_and_decode (trim (params[I+1]), 0, '\0\0,');
      for (N := 0; N < length (acl_users); N := N + 1)
      {
        acl_user := ODRIVE.WA.account_inverse_iri (trim (acl_users[N]));
        if (acl_user = -1)
        acl_user := ODRIVE.WA.odrive_user_id (trim (acl_users[N]));
        if (acl_user <> -1)
        {
          acl_inheritance := atoi (get_keyword ('f_fld_2_' || acl_seq, params));
          if (acl_inheritance <> 3)
          {
          WS.WS.ACL_ADD_ENTRY (acl_value,
                               acl_user,
                                 bit_shift (atoi (get_keyword ('f_fld_3_' || acl_seq || '_r_grant', params, '0')), 2) +
                                 bit_shift (atoi (get_keyword ('f_fld_3_' || acl_seq || '_w_grant', params, '0')), 1) +
                                 atoi (get_keyword ('f_fld_3_' || acl_seq || '_x_grant', params, '0')),
                               1,
                               acl_inheritance);
          WS.WS.ACL_ADD_ENTRY (acl_value,
                               acl_user,
                                 bit_shift (atoi (get_keyword ('f_fld_4_' || acl_seq || '_r_deny', params, '0')), 2) +
                                 bit_shift (atoi (get_keyword ('f_fld_4_' || acl_seq || '_w_deny', params, '0')), 1) +
                                 atoi (get_keyword ('f_fld_4_' || acl_seq || '_x_deny', params, '0')),
                               0,
                               acl_inheritance);
        }
      }
    }
  }
  }
  return acl_value;
}
;

-----------------------------------------------------------------------------
--
create procedure ODRIVE.WA.acl_vector (
  in acl varbinary)
{
  declare N, I integer;
  declare aAcl, aTmp any;

  aAcl := WS.WS.ACL_PARSE(acl, '0123', 0);
  aTmp := vector();

  for (N := 0; N < length(aAcl); N := N + 1)
  {
    if (not aAcl[N][1])
    {
      aTmp := vector_concat(aTmp, vector(vector(aAcl[N][0], aAcl[N][2], 0, aAcl[N][3])));
    }
  }
  for (N := 0; N < length (aAcl); N := N + 1)
  {
    if (aAcl[N][1])
    {
      for (I := 0; I < length (aTmp); I := I + 1)
      {
        if ((aAcl[N][0] = aTmp[I][0]) and (aAcl[N][2] = aTmp[I][1]))
        {
          aset(aTmp, I, vector(aTmp[I][0], aTmp[I][1], aAcl[N][3], aTmp[I][3]));
          goto _exit;
        }
      }
    _exit:
      if (I = length(aTmp))
      {
        aTmp := vector_concat(aTmp, vector(vector(aAcl[N][0], aAcl[N][2], aAcl[N][3], 0)));
    }
  }
  }
  return aTmp;
}
;

-------------------------------------------------------------------------------
--
create procedure ODRIVE.WA.odrive_ace_grantee(
  in N integer) returns varchar
{
  if (isnull(N))
    return '~none~';

  declare S varchar;

  S := (select concat('Group: ', G_NAME) from WS.WS.SYS_DAV_GROUP where G_ID = N);
  if (isnull(S))
    S := coalesce((select concat('User: ', U_NAME) from DB.DBA.SYS_USERS where U_ID = N), '~unknown~');

  return S;
}
;

-------------------------------------------------------------------------------
--
create procedure ODRIVE.WA.odrive_ace_inheritance(
  in N integer) returns varchar
{
  if (N = 0)
    return 'This object only';
  if (N = 1)
    return 'This object, subfolders and files';
  if (N = 2)
    return 'Subfolders and files';
  if (N = 3)
    return 'Inherited';
  return '';
}
;

-------------------------------------------------------------------------------
--
create procedure ODRIVE.WA.odrive_ace_grant(
  in N integer) returns varchar
{
  if (N = 0)
    return 'Revoke';
  if (N = 1)
    return 'Grant';
}
;

-------------------------------------------------------------------------------
--
create procedure ODRIVE.WA.odrive_ace_permissions(
  in N integer) returns varchar
{
  declare S varchar;

  S := 'rwx';
  if (bit_and(N, 1) = 0)
    S := replace(S, 'x', '-');
  if (bit_and(N, 2) = 0)
    S := replace(S, 'w', '-');
  if (bit_and(N, 4) = 0)
    S := replace(S, 'r', '-');

  return S;
}
;

-------------------------------------------------------------------------------
--
create procedure ODRIVE.WA.odrive_sharing_dir_list (
  in auth_name varchar := 'dav')
{
  declare uid, gid integer;
  declare name varchar;
  declare aResult any;

  aResult := vector ();
  DB.DBA.DAV_OWNER_ID (auth_name, null, uid, gid);

  name := '';
  for (select distinct RES_ID,
              RES_FULL_PATH,
              length (RES_CONTENT) as len,
              RES_MOD_TIME,
              RES_PERMS,
              RES_GROUP,
              RES_OWNER,
              RES_CR_TIME,
              RES_TYPE,
              RES_NAME
         from WS.WS.SYS_DAV_RES
                join WS.WS.SYS_DAV_ACL_INVERSE on AI_PARENT_ID = RES_ID
                  join WS.WS.SYS_DAV_ACL_GRANTS on GI_SUB = AI_GRANTEE_ID
        where AI_PARENT_TYPE = 'R'
          and GI_SUPER = uid
          and AI_FLAG = 'G'
          and RES_OWNER <> uid
          and RES_GROUP <> uid
        order by RES_NAME, RES_ID
      ) do
  {
    aResult := vector_concat(aResult, vector(vector (RES_FULL_PATH, 'R', len, RES_MOD_TIME, RES_ID, RES_PERMS, RES_GROUP, RES_OWNER, RES_CR_TIME, RES_TYPE, ODRIVE.WA.odrive_name_compose(RES_NAME, RES_ID, either(equ(RES_NAME, name),1,0)))));
    name := RES_NAME;
  }

  if (is_https_ctx () and SIOC..foaf_check_ssl (null))
  {
    declare N integer;
    declare graph, baseGraph, foafIRI any;
    declare S, V, st, msg, data, meta any;

    foafIRI := trim (get_certificate_info (7, null, null, null, '2.5.29.17'));
	  V := regexp_replace (foafIRI, ',[ ]*', ',', 1, null);
	  V := split_and_decode (V, 0, '\0\0,:');
	  if (V is null)
	    V := vector ();
	  foafIRI := get_keyword ('URI', V);
    if (not isnull (foafIRI) and SIOC..foaf_check_ssl (null))
      {
      graph := 'http://' || SIOC.DBA.get_cname ();
      baseGraph := SIOC.DBA.get_graph ();
        S := sprintf (' sparql \n' ||
                      ' define input:storage "" \n' ||
                      ' prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> \n' ||
                      ' prefix foaf: <http://xmlns.com/foaf/0.1/> \n' ||
                      ' prefix acl: <http://www.w3.org/ns/auth/acl#> \n' ||
                    ' select distinct ?r \n' ||
                      '  where { \n' ||
                      '          { \n' ||
                    '            graph ?g0 \n' ||
                    '            { \n' ||
                      '              ?rule a acl:Authorization ; \n' ||
                      '                    acl:accessTo ?r ; \n' ||
                      '                    acl:agent <%s>. \n' ||
                    '              filter (?g0 like <%s/DAV/home/%%>). \n' ||
                    '            } \n' ||
                      '          } \n' ||
                      '          union \n' ||
                      '          { \n' ||
                    '            graph ?g0 \n' ||
                    '            { \n' ||
                      '              ?rule a acl:Authorization ; \n' ||
                      '                    acl:accessTo ?r ; \n' ||
                      '                    acl:agentClass foaf:Agent. \n' ||
                    '              filter (?g0 like <%s/DAV/home/%%>). \n' ||
                    '            } \n' ||
                      '          } \n' ||
                      '          union \n' ||
                      '          { \n' ||
                    '            graph ?g0 \n' ||
                    '            { \n' ||
                      '              ?rule a acl:Authorization ; \n' ||
                      '                    acl:accessTo ?r ; \n' ||
                      '                    acl:agentClass ?group. \n' ||
                    '              filter (?g0 like <%s/DAV/home/%%>). \n' ||
                    '            } \n' ||
                    '            graph ?g1 \n' ||
                    '            { \n' ||
                      '                    ?group rdf:type foaf:Group ; \n' ||
                      '                    foaf:member <%s>. \n' ||
                    '              filter (?g1 like <%s/private/%%>). \n' ||
                    '            } \n' ||
                      '          } \n' ||
                      '        }\n',
                      foafIRI,
                    graph,
                    graph,
                    graph,
                    foafIRI,
                    baseGraph);
        commit work;
        st := '00000';
        exec (S, st, msg, vector (), vector ('use_cache', 1), meta, data);
        if (st = '00000' and length (data))
        {
          for (N := 0; N < length (data); N := N + 1)
          {
            name := '';
            V := rfc1808_parse_uri (data[N][0]);
            for (select RES_ID,
                        RES_FULL_PATH,
                        length (RES_CONTENT) as len,
                        RES_MOD_TIME,
                        RES_PERMS,
                        RES_GROUP,
                        RES_OWNER,
                        RES_CR_TIME,
                        RES_TYPE,
                        RES_NAME
                   from WS.WS.SYS_DAV_RES
                  where RES_FULL_PATH = V[2]
                ) do
            {
              aResult := vector_concat(aResult, vector(vector (RES_FULL_PATH, 'R', len, RES_MOD_TIME, RES_ID, RES_PERMS, RES_GROUP, RES_OWNER, RES_CR_TIME, RES_TYPE, ODRIVE.WA.odrive_name_compose(RES_NAME, RES_ID, either (equ (RES_NAME, name),1,0)))));
            }
          }
        }
      }
    }

  name := '';
  for (select distinct COL_ID,
              WS.WS.COL_PATH (COL_ID) as COL_FULL_PATH,
              0 as len,
              COL_MOD_TIME,
              COL_PERMS,
              COL_GROUP,
              COL_OWNER,
              COL_CR_TIME,
              COL_NAME
         from WS.WS.SYS_DAV_COL
                join WS.WS.SYS_DAV_ACL_INVERSE on AI_PARENT_ID = COL_ID
                  join WS.WS.SYS_DAV_ACL_GRANTS on GI_SUB = AI_GRANTEE_ID
        where AI_PARENT_TYPE = 'C'
          and GI_SUPER = uid
          and AI_FLAG = 'G'
          and COL_OWNER <> uid
          and COL_GROUP <> uid
        order by COL_NAME, COL_ID
      ) do
  {
    aResult := vector_concat(aResult, vector(vector(COL_FULL_PATH, 'C', len, COL_MOD_TIME, COL_ID, COL_PERMS, COL_GROUP, COL_OWNER, COL_CR_TIME, 'folder', ODRIVE.WA.odrive_name_compose(COL_NAME, COL_ID, either(equ(COL_NAME, name),1,0)))));
    name := COL_NAME;
  }
  return aResult;
}
;

-------------------------------------------------------------------------------
--
create procedure ODRIVE.WA.odrive_name_compose(
  in name any,
  in id integer,
  in mode integer := 0)
{
  if (mode = 0)
    return name;

  declare pairs any;
  pairs := regexp_parse ('^(.*[/])?([^/][^./]*)([^/]*)\044', name, 0);
  if (pairs is null)
    signal ('.....', sprintf ('Internal error: failed "name_compose" (%s, %d)', name, id));
  return sprintf ('%s (\$id-%d)%s', subseq(name, 0, pairs[5]), id, subseq (name, pairs[6]));
}
;


-------------------------------------------------------------------------------
--
create procedure ODRIVE.WA.odrive_name_restore(
  in name any,
  out _name varchar,
  out _id integer)
{
  declare pairs any;
  pairs := regexp_parse ('^(.*[/])?([^/][^./]*)([^/]*)\044', name, 0);
  if (pairs is null)
    signal ('.....', sprintf ('Internal error: failed "odrive_name_restore" (%s)', name));

  declare fname, fext varchar;
  fname := subseq (name, 0, pairs[5]);
  fext := subseq (name, pairs[6], pairs[7]);

  pairs := regexp_parse ('^(.*) [(][\$]id-([1-9][0-9]*)[)]\044', fname, 0);
  if (pairs is null)
  {
    _name := fname || fext;
    _id := null;
  } else {
    _name := subseq (fname, pairs[2], pairs[3]) || fext;
    _id := cast (subseq (fname, pairs[4], pairs[5]) as integer);
  }
}
;

-------------------------------------------------------------------------------
--
create procedure ODRIVE.WA.settings (
  in account_id integer)
{
  declare V any;

  V := coalesce ((select deserialize (blob_to_string (USER_SETTINGS)) from ODRIVE.WA.SETTINGS where USER_ID = account_id), vector());
  return ODRIVE.WA.settings_init (V);
}
;

-------------------------------------------------------------------------------
--
create procedure ODRIVE.WA.settings_init (
  inout settings any)
{
  ODRIVE.WA.set_keyword ('chars', settings, ODRIVE.WA.settings_chars (settings));
  ODRIVE.WA.set_keyword ('rows', settings, ODRIVE.WA.settings_rows (settings));
  ODRIVE.WA.set_keyword ('tbLabels', settings, ODRIVE.WA.settings_tbLabels (settings));
  ODRIVE.WA.set_keyword ('hiddens', settings, ODRIVE.WA.settings_hiddens (settings));
  ODRIVE.WA.set_keyword ('atomVersion', settings, ODRIVE.WA.settings_atomVersion (settings));
  ODRIVE.WA.set_keyword ('column_#1', settings, ODRIVE.WA.settings_column (settings, 1));
  ODRIVE.WA.set_keyword ('column_#2', settings, ODRIVE.WA.settings_column (settings, 2));
  ODRIVE.WA.set_keyword ('column_#3', settings, ODRIVE.WA.settings_column (settings, 3));
  ODRIVE.WA.set_keyword ('column_#4', settings, ODRIVE.WA.settings_column (settings, 4));
  ODRIVE.WA.set_keyword ('column_#5', settings, ODRIVE.WA.settings_column (settings, 5));
  ODRIVE.WA.set_keyword ('column_#6', settings, ODRIVE.WA.settings_column (settings, 6));
  ODRIVE.WA.set_keyword ('column_#7', settings, ODRIVE.WA.settings_column (settings, 7));
  ODRIVE.WA.set_keyword ('column_#8', settings, ODRIVE.WA.settings_column (settings, 8));
  ODRIVE.WA.set_keyword ('column_#9', settings, ODRIVE.WA.settings_column (settings, 9));
  ODRIVE.WA.set_keyword ('mailShare', settings, ODRIVE.WA.settings_mailShare (settings));
  ODRIVE.WA.set_keyword ('mailUnshare', settings, ODRIVE.WA.settings_mailUnshare (settings));

  return settings;
}
;

-------------------------------------------------------------------------------
--
create procedure ODRIVE.WA.settings_chars (
  inout settings any)
{
  return cast (get_keyword ('chars', settings, '60') as integer);
}
;

-------------------------------------------------------------------------------
--
create procedure ODRIVE.WA.settings_rows (
  inout settings any)
{
  return cast(get_keyword('rows', settings, '10') as integer);
}
;

-------------------------------------------------------------------------------
--
create procedure ODRIVE.WA.settings_tbLabels (
  inout settings any)
{
  return cast (get_keyword ('tbLabels', settings, '1') as integer);
}
;

-------------------------------------------------------------------------------
--
create procedure ODRIVE.WA.settings_hiddens (
  inout settings any)
{
  return get_keyword ('hiddens', settings, '.');
}
;

-------------------------------------------------------------------------------
--
create procedure ODRIVE.WA.settings_atomVersion (
  inout settings any)
{
  return get_keyword('atomVersion', settings, '1.0');
}
;

-------------------------------------------------------------------------------
--
create procedure ODRIVE.WA.settings_column (
  inout settings any,
  in N integer)
{
  return cast (get_keyword ('column_#' || cast (N as varchar), settings, '1') as integer);
}
;

-------------------------------------------------------------------------------
--
create procedure ODRIVE.WA.settings_mailShare (
  inout settings any)
{
  return get_keyword ('mailShare', settings, 'Dear %user_name%,\n\nThe resource %resource_uri% has been shared with you by user %owner_uri% .\n\nRegards,\n%owner_name%');
}
;

-------------------------------------------------------------------------------
--
create procedure ODRIVE.WA.settings_mailUnshare (
  inout settings any)
{
  return get_keyword ('mailUnshare', settings, 'Dear %user_name%,\n\nThe resource %resource_uri% has been unshared by user %owner_uri% .\n\nRegards,\n%owner_name%');
}
;

-------------------------------------------------------------------------------
--
create procedure ODRIVE.WA.auto_version_full (
  in value varchar)
{
  if (value = 'A')
    return 'DAV:checkout-checkin';
  if (value = 'B')
    return 'DAV:checkout-unlocked-checkin';
  if (value = 'C')
    return 'DAV:checkout';
  if (value = 'D')
    return 'DAV:locked-checkout';
  return '';
}
;

create procedure ODRIVE.WA.auto_version_short (
  in value varchar)
{
  if (value = 'DAV:checkout-checkin')
    return 'A';
  if (value = 'DAV:checkout-unlocked-checkin')
    return 'B';
  if (value = 'DAV:checkout')
    return 'C';
  if (value = 'DAV:locked-checkout')
    return 'D';
  return '';
}
;

-------------------------------------------------------------------------------
--
create procedure ODRIVE.WA.det_type (
  in path varchar,
  in type varchar := 'C')
{
  declare id any;

  id := DB.DBA.DAV_SEARCH_ID (path, type);
  if (ODRIVE.WA.DAV_ERROR (id))
    return '';
  return cast (coalesce (DB.DBA.DAV_PROP_GET_INT (id, type, ':virtdet', 0), '') as varchar);
}
;

-------------------------------------------------------------------------------
--
create procedure ODRIVE.WA.det_class(
  in path varchar,
  in type varchar := 'C')
{
  declare id any;

  id := ODRIVE.WA.DAV_SEARCH_ID (path, type);
  if (not ODRIVE.WA.DAV_ERROR (id) and isarray (id))
      return cast (id[0] as varchar);
  return '';
}
;

-------------------------------------------------------------------------------
--
create procedure ODRIVE.WA.det_category(
  in path varchar,
  in type varchar := 'C')
{
  declare id any;

  id := DB.DBA.DAV_SEARCH_ID (path, type);
  if (ODRIVE.WA.DAV_ERROR (id))
    return '';
    if (isarray(id))
      return cast (id[0] as varchar);
    return DB.DBA.DAV_PROP_GET_INT (id, type, ':virtdet', 0);
  }
;

-------------------------------------------------------------------------------
--
create procedure ODRIVE.WA.DAV_GET_INFO(
  in path varchar,
  in info varchar,
  in auth_name varchar := null,
  in auth_pwd varchar := null)
{
  declare tmp any;

  if (info = 'vc')
  {
    if (ODRIVE.WA.DAV_GET_VERSION_CONTROL(path, auth_name, auth_pwd))
      return 'ON';
    return 'OFF';
  }
  if (info = 'avcState')
  {
    tmp := ODRIVE.WA.DAV_GET_AUTOVERSION(path, auth_name, auth_pwd);
    if (tmp <> '')
      return replace(ODRIVE.WA.auto_version_full(tmp), 'DAV:', '');
    return 'OFF';
  }
  if (info = 'vcState')
  {
    if (not is_empty_or_null(ODRIVE.WA.DAV_PROP_GET (path, 'DAV:checked-in', '', auth_name, auth_pwd)))
      return 'Check-In';
    if (not is_empty_or_null(ODRIVE.WA.DAV_PROP_GET (path, 'DAV:checked-out', '', auth_name, auth_pwd)))
      return 'Check-Out';
    return 'Standard';
  }
  if (info = 'lockState')
  {
    if (ODRIVE.WA.DAV_IS_LOCKED(path))
      return 'ON';
    return 'OFF';
  }
  return '';
}
;

-------------------------------------------------------------------------------
--
create procedure ODRIVE.WA.DAV_SET_VERSIONING_CONTROL(
  in path varchar,
  in autoVersion varchar,
  in auth_name varchar := null,
  in auth_pwd varchar := null)
{
  declare permissions, uname, gname varchar;
  declare retValue any;

  ODRIVE.WA.DAV_API_PARAMS (null, null, uname, gname, auth_name, auth_pwd);
  if (autoVersion = '')
  {
    update WS.WS.SYS_DAV_COL set COL_AUTO_VERSIONING = null where COL_ID = DAV_SEARCH_ID (path, 'C');
    return 0;
  }

    permissions := DB.DBA.DAV_PROP_GET(path, ':virtpermissions', auth_name, auth_pwd);
    uname := DB.DBA.DAV_PROP_GET(path, ':virtowneruid', auth_name, auth_pwd);
    gname := DB.DBA.DAV_PROP_GET(path, ':virtownergid', auth_name, auth_pwd);
    DB.DBA.DAV_COL_CREATE (concat(path, 'VVC/'), permissions, uname, gname, auth_name, auth_pwd);
    DB.DBA.DAV_COL_CREATE (concat(path, 'Attic/'), permissions, uname, gname, auth_name, auth_pwd);
    DB.DBA.DAV_PROP_SET (concat(path, 'VVC/'), 'virt:Versioning-Attic', concat(path, 'Attic/'), auth_name, auth_pwd);
  retValue := DB.DBA.DAV_SET_VERSIONING_CONTROL (path, concat(path, 'VVC/'), autoVersion, auth_name, auth_pwd);

  return retValue;
}
;

-------------------------------------------------------------------------------
--
create procedure ODRIVE.WA.DAV_VERSION_CONTROL (
  in path varchar,
  in auth_name varchar := null,
  in auth_pwd varchar := null)
{
  declare uname, gname varchar;

  ODRIVE.WA.DAV_API_PARAMS (null, null, uname, gname, auth_name, auth_pwd);
  return DB.DBA.DAV_VERSION_CONTROL (path, auth_name, auth_pwd);
}
;

-------------------------------------------------------------------------------
--
create procedure ODRIVE.WA.DAV_REMOVE_VERSION_CONTROL (
  in path varchar,
  in auth_name varchar := null,
  in auth_pwd varchar := null)
{
  declare uname, gname varchar;

  ODRIVE.WA.DAV_API_PARAMS (null, null, uname, gname, auth_name, auth_pwd);
  return DB.DBA.DAV_REMOVE_VERSION_CONTROL (path, auth_name, auth_pwd);
}
;

-------------------------------------------------------------------------------
--
create procedure ODRIVE.WA.DAV_CHECKIN (
  in path varchar,
  in auth_name varchar := null,
  in auth_pwd varchar := null)
{
  declare uname, gname varchar;

  ODRIVE.WA.DAV_API_PARAMS (null, null, uname, gname, auth_name, auth_pwd);
  return DB.DBA.DAV_CHECKIN (path, auth_name, auth_pwd);
}
;

-------------------------------------------------------------------------------
--
create procedure ODRIVE.WA.DAV_CHECKOUT (
  in path varchar,
  in auth_name varchar := null,
  in auth_pwd varchar := null)
{
  declare uname, gname varchar;

  ODRIVE.WA.DAV_API_PARAMS (null, null, uname, gname, auth_name, auth_pwd);
  return DB.DBA.DAV_CHECKOUT (path, auth_name, auth_pwd);
}
;

-------------------------------------------------------------------------------
--
create procedure ODRIVE.WA.DAV_UNCHECKOUT (
  in path varchar,
  in auth_name varchar := null,
  in auth_pwd varchar := null)
{
  declare uname, gname varchar;

  ODRIVE.WA.DAV_API_PARAMS (null, null, uname, gname, auth_name, auth_pwd);
  return DB.DBA.DAV_UNCHECKOUT (path, auth_name, auth_pwd);
}
;

-------------------------------------------------------------------------------
--
create procedure ODRIVE.WA.DAV_GET_AUTOVERSION (
  in path varchar,
  in auth_name varchar := null,
  in auth_pwd varchar := null)
{
  --declare exit handler for SQLSTATE '*' {return '';};

  if (ODRIVE.WA.DAV_ERROR(DB.DBA.DAV_SEARCH_ID (path, 'R'))) {
    declare id integer;

    id := DAV_SEARCH_ID (path, 'C');
    if (not isinteger(id))
      return '';
    return coalesce((select COL_AUTO_VERSIONING from WS.WS.SYS_DAV_COL where COL_ID = DAV_SEARCH_ID (path, 'C')), '');
  }
  return ODRIVE.WA.auto_version_short(ODRIVE.WA.DAV_PROP_GET (path, 'DAV:auto-version'));
}
;

-------------------------------------------------------------------------------
--
create procedure ODRIVE.WA.DAV_GET_VERSION_CONTROL (
  in path varchar,
  in auth_name varchar := null,
  in auth_pwd varchar := null)
{
  declare retValue any;

  if (ODRIVE.WA.DAV_ERROR(DB.DBA.DAV_SEARCH_ID (path, 'R')))
    return 0;
  if (ODRIVE.WA.DAV_PROP_GET (path, 'DAV:checked-in', '', auth_name, auth_pwd) <> '')
    return 1;
  if (ODRIVE.WA.DAV_PROP_GET (path, 'DAV:checked-out', '', auth_name, auth_pwd) <> '')
    return 1;
  return 0;
}
;

-------------------------------------------------------------------------------
--
create procedure ODRIVE.WA.path_parent (
  in path varchar)
{
  path := trim(path, '/');
  if (isnull(strrchr(path, '/')))
    return '';
  return left(trim(path, '/'), strrchr(trim(path, '/'), '/'));
}
;

-------------------------------------------------------------------------------
--
create procedure ODRIVE.WA.path_name (
  in path varchar)
{
  path := trim(path, '/');
  if (isnull(strrchr(path, '/')))
    return path;
  return right(path, length(path)-strrchr(path, '/')-1);
}
;

-------------------------------------------------------------------------------
--
create procedure ODRIVE.WA.DAV_GET_VERSION_PATH (
  in path varchar)
{
  declare parent, name varchar;

  name := ODRIVE.WA.path_name(path);
  parent := ODRIVE.WA.path_parent(path);

  return concat('/', parent, '/VVC/', name, '/');
}
;

-------------------------------------------------------------------------------
--
create procedure ODRIVE.WA.DAV_GET_VERSION_HISTORY_PATH (
  in path varchar)
{
  return ODRIVE.WA.DAV_GET_VERSION_PATH (path) || 'history.xml';
}
;

-------------------------------------------------------------------------------
--
create procedure ODRIVE.WA.DAV_GET_VERSION_HISTORY (
  in path varchar)
{
  declare exit handler for SQLSTATE '*' {return null;};

  return ODRIVE.WA.DAV_RES_CONTENT (ODRIVE.WA.DAV_GET_VERSION_HISTORY_PATH(path));
}
;

-------------------------------------------------------------------------------
--
create procedure ODRIVE.WA.DAV_GET_VERSION_COUNT (
  in path varchar)
{
  declare exit handler for SQLSTATE '*' {return 0;};

  return xpath_eval ('count (//version)', xtree_doc (ODRIVE.WA.DAV_GET_VERSION_HISTORY(path)));
}
;

-------------------------------------------------------------------------------
--
create procedure ODRIVE.WA.DAV_GET_VERSION_ROOT (
  in path varchar)
{
  declare exit handler for SQLSTATE '*' {return '';};

  declare retValue any;

  retValue := ODRIVE.WA.DAV_PROP_GET (ODRIVE.WA.DAV_GET_VERSION_HISTORY_PATH (path), 'DAV:root-version', '');
  if (ODRIVE.WA.DAV_ERROR (retValue)) {
    retValue := '';
  } else {
    retValue := cast (xpath_eval ('/href', xml_tree_doc(retValue)) as varchar);
  }
  return ODRIVE.WA.show_text(retValue, 'root');
}
;

-------------------------------------------------------------------------------
--
create procedure ODRIVE.WA.DAV_GET_VERSION_SET (
  in path varchar,
  in auth_name varchar := null,
  in auth_pwd varchar := null)
{
  declare N integer;
  declare c0 varchar;
  declare c1 integer;
  declare versionSet, hrefs any;

  result_names(c0, c1);

  declare exit handler for SQLSTATE '*' {return;};

  versionSet := ODRIVE.WA.DAV_PROP_GET (ODRIVE.WA.DAV_GET_VERSION_HISTORY_PATH(path), 'DAV:version-set', auth_name, auth_pwd);
  hrefs := xpath_eval ('/href', xtree_doc(versionSet), 0);
  for (N := 0; N < length(hrefs); N := N + 1)
    result(cast(hrefs[N] as varchar), either(equ(N+1,length(hrefs)),0,1));
}
;

-------------------------------------------------------------------------------
--
create procedure ODRIVE.WA.DAV_SET_AUTOVERSION (
  in path varchar,
  in value any)
{
  declare retValue any;

  retValue := 0;
  if (ODRIVE.WA.DAV_ERROR (DB.DBA.DAV_SEARCH_ID (path, 'R')))
  {
    retValue := ODRIVE.WA.DAV_SET_VERSIONING_CONTROL (path, value);
  } else {
    value := ODRIVE.WA.auto_version_full(value);
    if (value = '')
    {
      retValue := ODRIVE.WA.DAV_PROP_REMOVE(path, 'DAV:auto-version');
    } else {
      if (not ODRIVE.WA.DAV_GET_VERSION_CONTROL(path))
        ODRIVE.WA.DAV_VERSION_CONTROL(path);
      retValue := ODRIVE.WA.DAV_PROP_SET(path, 'DAV:auto-version', value);
    }
  }
  return retValue;
}
;

-------------------------------------------------------------------------------
--
create procedure ODRIVE.WA.DAV_PERROR (
  in x any)
{
  declare S any;

  if (x = -3)
    return 'Destination exists';
  S := DB.DBA.DAV_PERROR(x);
  if (not is_empty_or_null(S)) {
    S := replace(S, 'collection', 'folder');
    S := replace(S, 'Collection', 'Folder');
    S := replace(S, 'resource', 'file');
    S := replace(S, 'Resource', 'File');
    S := subseq(S, 6);
  }
  return S;
}
;

-------------------------------------------------------------------------------
--
create procedure ODRIVE.WA.DAV_INIT (
  in path varchar,
  in auth_name varchar := null,
  in auth_pwd varchar := null)
{
  declare resource any;

  resource := ODRIVE.WA.DAV_DIR_LIST (path, -1, auth_name, auth_pwd);
  if (ODRIVE.WA.DAV_ERROR(resource))
    return resource;
  if (length(resource) = 0)
    return -1;
  return resource[0];
}
;

-------------------------------------------------------------------------------
--
create procedure ODRIVE.WA.DAV_INIT_INT (
  in path varchar,
  in auth_name varchar := null,
  in auth_pwd varchar := null)
{
  declare uid, gid integer;
  declare uname, gname varchar;
  declare permissions any;

  DB.DBA.DAV_OWNER_ID(ODRIVE.WA.account (), null, uid, gid);
  ODRIVE.WA.DAV_API_PARAMS (uid, gid, uname, gname, auth_name, auth_pwd);
  uname := coalesce (auth_name, 'nobody');

  permissions := -1;
  path := replace (path || '/', '//', '/');
  if (path <> ODRIVE.WA.dav_home (uname))
  {
    permissions := DB.DBA.DAV_PROP_GET (path, ':virtpermissions', auth_name, auth_pwd);
  }
  if (permissions < 0)
    permissions := USER_GET_OPTION (uname, 'PERMISSIONS');

  return vector(null, '', 0, null, 0, permissions, gid, uid, null, '', null);
}
;

-------------------------------------------------------------------------------
--
create procedure ODRIVE.WA.DAV_INIT_RESOURCE (
  in path varchar)
{
  declare item any;

  item := ODRIVE.WA.DAV_INIT_INT (path);
  aset(item, 1, 'R');
  return item;
}
;

-------------------------------------------------------------------------------
--
create procedure ODRIVE.WA.DAV_INIT_COLLECTION (
  in path varchar)
{
  declare item any;

  item := ODRIVE.WA.DAV_INIT_INT (path);
  aset(item, 1, 'C');
  aset(item, 9, 'dav/unix-directory');
  return item;
}
;

-------------------------------------------------------------------------------
--
create procedure ODRIVE.WA.DAV_SEARCH_ID(
  in path varchar,
  out type varchar)
{
  declare id any;

  type := 'C';
  id := DB.DBA.DAV_SEARCH_ID (path, type);
  if (ODRIVE.WA.DAV_ERROR(id))
  {
    type := 'R';
    return DB.DBA.DAV_SEARCH_ID (path, type);
  }
  return id;
}
;

-------------------------------------------------------------------------------
--
create procedure ODRIVE.WA.DAV_GET (
  inout resource any,
  in property varchar)
{
  if (isinteger(resource))
    return;

  if (property = 'fullPath')
    return resource[0];

  if (property = 'type')
    return resource[1];

  if (property = 'length')
    return resource[2];

  if (property = 'modificationTime')
    return case when is_empty_or_null (resource[3]) then now () else resource[3] end;

  if (property = 'id')
    return resource[4];

  if (property = 'permissions')
    return resource[5];

  if (property = 'freeText') {
    if (length(resource[5]) < 10)
      return 'T';
    return chr(resource[5][9]);
  }

  if (property = 'metaGrab') {
    if (length(resource[5]) < 11)
      return 'M';
    return chr(resource[5][10]);
  }

  if (property = 'permissionsName')
    return adm_dav_format_perms(resource[5]);

  if (property = 'groupID')
    return resource[6];

  if (property = 'groupName')
    return ODRIVE.WA.odrive_user_name(resource[6]);

  if (property = 'ownerID')
    return resource[7];

  if (property = 'ownerName')
    return ODRIVE.WA.odrive_user_name(resource[7]);

  if (property = 'creationTime')
    return case when is_empty_or_null (resource[8]) then now () else resource[8] end;

  if (property = 'mimeType')
    return coalesce(resource[9], '');

  if (property = 'name')
    return resource[10];

  if (property = 'acl')
  {
    if (isnull(resource[0]))
      return WS.WS.ACL_CREATE();
    return cast(ODRIVE.WA.DAV_PROP_GET (resource[0], ':virtacl', WS.WS.ACL_CREATE()) as varbinary);
  }

  if ((property = 'detType') and (not isnull (resource[0])))
  {
    declare detType any;
    
    detType := ODRIVE.WA.DAV_PROP_GET (resource[0], ':virtdet');
    if (isnull (detType) and (ODRIVE.WA.DAV_GET (resource, 'type') = 'C'))
    {
      if (ODRIVE.WA.DAV_PROP_GET (resource[0], 'virt:rdf_graph', '') <> '')
        detType := 'rdfSink';
      else if (ODRIVE.WA.DAV_PROP_GET (resource[0], 'virt:Versioning-History', '') <> '')
        detType := 'UnderVersioning';
      else if (ODRIVE.WA.syncml_detect (resource[0]))
        detType := 'SyncML';
    }  
    return detType;
  }

  if ((property = 'privatetags') and (not isnull(resource[0])))
    return ODRIVE.WA.DAV_PROP_GET (resource[0], ':virtprivatetags', '');

  if ((property = 'publictags') and (not isnull(resource[0])))
    return ODRIVE.WA.DAV_PROP_GET (resource[0], ':virtpublictags', '');

  if (property = 'versionControl')
  {
    if (isnull(resource[0]))
      return null;
    return ODRIVE.WA.DAV_GET_VERSION_CONTROL (resource[0]);
  }
  if (property = 'autoversion')
  {
    if (isnull(resource[0]))
      return null;
    return ODRIVE.WA.DAV_GET_AUTOVERSION (resource[0]);
  }
  if (property = 'checked-in')
  {
    if (isnull(resource[0]))
      return null;
    return ODRIVE.WA.DAV_PROP_GET (resource[0], 'DAV:checked-in', '');
  }
  if (property = 'checked-out')
  {
    if (isnull(resource[0]))
      return null;
    return ODRIVE.WA.DAV_PROP_GET (resource[0], 'DAV:checked-out', '');
  }

  if (property = 'permissions-inheritance')
  {
    if (isnull (resource[0]) or (resource[1] = 'R') or ODRIVE.WA.isVector (resource[1]))
      return null;
    return (select COL_INHERIT from WS.WS.SYS_DAV_COL where COL_ID = resource[4]);
  }

  return '';
}
;

-------------------------------------------------------------------------------
--
create procedure ODRIVE.WA.DAV_ERROR (in code any)
{
  if (isinteger(code) and (code < 0))
    return 1;
  return 0;
}
;

-------------------------------------------------------------------------------
--
create procedure ODRIVE.WA.DAV_SET (
  in path varchar,
  in property varchar,
  in value varchar,
  in auth_name varchar := null,
  in auth_pwd varchar := null)
{
  declare tmp varchar;

  if (property = 'permissions')
    return ODRIVE.WA.DAV_PROP_SET (path, ':virtpermissions', value, auth_name, auth_pwd, 0);
  if (property = 'groupID')
    return ODRIVE.WA.DAV_PROP_SET (path, ':virtownergid', value, auth_name, auth_pwd, 0);
  if (property = 'ownerID')
    return ODRIVE.WA.DAV_PROP_SET (path, ':virtowneruid', value, auth_name, auth_pwd, 0);
  if (property = 'mimeType')
    return ODRIVE.WA.DAV_PROP_SET (path, ':getcontenttype', value, auth_name, auth_pwd, 0);
  if (property = 'name')
  {
    tmp := concat(left(path, strrchr(rtrim(path, '/'), '/')), '/', value, either(equ(right(path, 1), '/'), '/', ''));
    return ODRIVE.WA.DAV_MOVE(path, tmp, 0, auth_name, auth_pwd);
  }
  if (property = 'detType')
    return DAV_PROP_SET_INT (path, ':virtdet', value, null, null, 0, 0, 0, http_dav_uid ());
  if (property = 'acl')
    return ODRIVE.WA.DAV_PROP_SET (path, ':virtacl', value, auth_name, auth_pwd, 0);
  if (property = 'privatetags')
    return ODRIVE.WA.DAV_PROP_TAGS_SET (path, ':virtprivatetags', value, auth_name, auth_pwd);
  if (property = 'publictags')
    return ODRIVE.WA.DAV_PROP_TAGS_SET (path, ':virtpublictags', value, auth_name, auth_pwd);
  if (property = 'autoversion')
    return ODRIVE.WA.DAV_SET_AUTOVERSION (path, value);
  if (property = 'permissions-inheritance')
  {
    tmp := DB.DBA.DAV_SEARCH_ID (path, 'C');
    if (not isarray (tmp))
    {
    set triggers off;
      update WS.WS.SYS_DAV_COL set COL_INHERIT = value where COL_ID = tmp;
    set triggers on;
  }
  }
  return 0;
}
;

-------------------------------------------------------------------------------
--
create procedure ODRIVE.WA.DAV_SET_RECURSIVE (
  in path varchar,
  in dav_perms any,
  in dav_owner any,
  in dav_group any)
{
  declare items any;

  items := ODRIVE.WA.DAV_DIR_LIST (path, 0);
  foreach (any item in items) do
  {
    declare itemPath varchar;

    itemPath := item[0];
    ODRIVE.WA.DAV_SET(itemPath, 'permissions', dav_perms);
    if (dav_owner <> -1)
      ODRIVE.WA.DAV_SET(itemPath, 'ownerID', dav_owner);
    if (dav_group <> -1)
      ODRIVE.WA.DAV_SET(itemPath, 'groupID', dav_group);
    if (item[1] = 'C')
      ODRIVE.WA.DAV_SET_RECURSIVE (itemPath, dav_perms, dav_owner, dav_group);
  }
}
;

-------------------------------------------------------------------------------
--
create procedure ODRIVE.WA.DAV_API_PWD (
	in auth_name varchar)
{
  declare auth_pwd varchar;

  auth_pwd := coalesce((SELECT U_PWD FROM WS.WS.SYS_DAV_USER WHERE U_NAME = auth_name), '');
  if (auth_pwd[0] = 0)
    auth_pwd := pwd_magic_calc(auth_name, auth_pwd, 1);
  return auth_pwd;
}
;

-------------------------------------------------------------------------------
--
create procedure ODRIVE.WA.DAV_API_PARAMS (
  in uid integer,
  in gid integer,
  out uname varchar,
	out gname varchar,
	out auth_name varchar,
	out auth_pwd varchar)
{
  uname := null;
  if (not isnull(uid))
    uname := (select U_NAME from WS.WS.SYS_DAV_USER where U_ID = uid);

  gname := null;
  if (not isnull(gid))
    gname := (select G_NAME from WS.WS.SYS_DAV_GROUP where G_ID = gid);

  if (isnull(auth_name))
  {
    auth_name := ODRIVE.WA.account();
    if (auth_name = 'dba')
      auth_name := 'dav';
  }
  if (isnull(auth_pwd)) {
    auth_pwd := coalesce((SELECT U_PWD FROM WS.WS.SYS_DAV_USER WHERE U_NAME = auth_name), '');
    if (auth_pwd[0] = 0)
      auth_pwd := pwd_magic_calc(auth_name, auth_pwd, 1);
  }
  return 1;
}
;

-------------------------------------------------------------------------------
--
create procedure ODRIVE.WA.DAV_DIR_LIST (
  in path varchar := '/DAV/',
  in recursive integer := 0,
  in auth_name varchar := null,
  in auth_pwd varchar := null)
{
  declare uname, gname varchar;

  ODRIVE.WA.DAV_API_PARAMS (null, null, uname, gname, auth_name, auth_pwd);
  return DB.DBA.DAV_DIR_LIST(path, recursive, auth_name, auth_pwd);
}
;

-------------------------------------------------------------------------------
--
create procedure ODRIVE.WA.DAV_DIR_FILTER (
  in path varchar := '/DAV/',
  in recursive integer := 0,
  in filter any,
  in auth_name varchar := null,
  in auth_pwd varchar := null)
{
  declare uname, gname varchar;

  ODRIVE.WA.DAV_API_PARAMS (null, null, uname, gname, auth_name, auth_pwd);
  return DB.DBA.DAV_DIR_FILTER(path, recursive, filter, auth_name, auth_pwd);
}
;

-------------------------------------------------------------------------------
--
create procedure ODRIVE.WA.ResFilter_CONFIGURE (
  in path varchar := '/DAV/',
  in search_params varchar)
{
  declare search_path varchar;
  declare filter any;

  search_path := ODRIVE.WA.odrive_real_path(ODRIVE.WA.dc_get(search_params, 'base', 'path', '/DAV/'));
  filter := ODRIVE.WA.dc_filter(search_params);
  return ODRIVE.WA.ResFilter_CONFIGURE_INT(path, search_path, filter);
}
;

-------------------------------------------------------------------------------
--
create procedure ODRIVE.WA.ResFilter_CONFIGURE_INT (
  in path varchar,
  in search_path varchar,
  in filter any)
{
  declare cid integer;

  cid := DB.DBA.DAV_SEARCH_ID (path, 'C');
  if (ODRIVE.WA.DAV_ERROR(cid))
    return cid;
  return DB.DBA.ResFilter_CONFIGURE(cid, search_path, filter);
}
;

-------------------------------------------------------------------------------
--
create procedure ODRIVE.WA.CatFilter_CONFIGURE (
  in path varchar := '/DAV/',
  in search_params varchar)
{
  declare search_path varchar;
  declare filter any;

  search_path := ODRIVE.WA.odrive_real_path (ODRIVE.WA.dc_get (search_params, 'base', 'path', '/DAV/'));
  filter := ODRIVE.WA.dc_filter (search_params);
  return ODRIVE.WA.CatFilter_CONFIGURE_INT(path, search_path, filter);
}
;

-------------------------------------------------------------------------------
--
create procedure ODRIVE.WA.CatFilter_CONFIGURE_INT (
  in path varchar,
  in search_path varchar,
  in filter any,
  in auth_name varchar := null,
  in auth_pwd varchar := null)
{
  declare cid, uid integer;
  declare uname, gname varchar;

  cid := DB.DBA.DAV_SEARCH_ID (path, 'C');
  if (ODRIVE.WA.DAV_ERROR(cid))
    return cid;
  ODRIVE.WA.DAV_API_PARAMS (null, null, uname, gname, auth_name, auth_pwd);
  uid := ODRIVE.WA.odrive_user_id(auth_name);
  return DB.DBA.CatFilter_CONFIGURE(cid, search_path, filter, auth_name, auth_pwd, uid);
}
;

-------------------------------------------------------------------------------
--
create procedure ODRIVE.WA.DAV_COPY (
  in path varchar,
  in destination varchar,
  in overwrite integer := 0,
  in permissions varchar := '110100000R',
  in auth_name varchar := null,
  in auth_pwd varchar := null)
{
  declare uname, gname varchar;
  declare uid, gid integer;

  auth_name := ODRIVE.WA.account();
  uid := (select U_ID from WS.WS.SYS_DAV_USER where U_NAME = auth_name);
  gid := (select U_GROUP from WS.WS.SYS_DAV_USER where U_NAME = auth_name);
  ODRIVE.WA.DAV_API_PARAMS (uid, gid, uname, gname, auth_name, auth_pwd);
  return DB.DBA.DAV_COPY(path, destination, overwrite, permissions, uname, gname, auth_name, auth_pwd);
}
;

-------------------------------------------------------------------------------
--
create procedure ODRIVE.WA.DAV_MOVE (
  in path varchar,
  in destination varchar,
  in overwrite integer,
  in auth_name varchar := null,
  in auth_pwd varchar := null)
{
  declare uname, gname varchar;

  ODRIVE.WA.DAV_API_PARAMS (null, null, uname, gname, auth_name, auth_pwd);
  return DB.DBA.DAV_MOVE(path, destination, overwrite, auth_name, auth_pwd);
}
;

-------------------------------------------------------------------------------
--
create procedure ODRIVE.WA.DAV_DELETE (
  in path varchar,
  in silent integer := 0,
  in auth_name varchar := null,
  in auth_pwd varchar := null)
{
  declare id any;
  declare owner, uname, gname, detType varchar;

  ODRIVE.WA.DAV_API_PARAMS (null, null, uname, gname, auth_name, auth_pwd);
  if (path[length (path)-1] = ascii('/'))
  {
    detType := ODRIVE.WA.det_type (path, 'C');
    if (detType = 'SyncML')
    {
      ODRIVE.WA.exec ('delete from DB.DBA.SYNC_COLS_TYPES where CT_COL_ID = ?', vector (DB.DBA.DAV_SEARCH_ID (path, 'C')));
    }
    else if (detType = 'IMAP')
    {
      id := DB.DBA.DAV_SEARCH_ID (path, 'C');
      if (not ODRIVE.WA.DAV_ERROR (id) and not isarray(id))
      {
        owner := sprintf ('IMAP_%d', id);
        ODRIVE.WA.exec ('delete from DB.DBA.MAIL_FOLDER where MF_OWN = ?', vector (owner));
        ODRIVE.WA.exec ('delete from DB.DBA.MAIL_MESSAGE where MM_OWN = ?', vector (owner));
      }
    }
  }
  return DB.DBA.DAV_DELETE(path, silent, auth_name, auth_pwd);
}
;

-------------------------------------------------------------------------------
--
create procedure ODRIVE.WA.DAV_RES_UPLOAD (
  in path varchar,
  inout content any,
  in type varchar := '',
  in permissions varchar := '110100000R',
  in uid integer := null,
  in gid integer := null,
  in auth_name varchar := null,
  in auth_pwd varchar := null)
{
  declare uname, gname varchar;

  ODRIVE.WA.DAV_API_PARAMS (uid, gid, uname, gname, auth_name, auth_pwd);
  return DB.DBA.DAV_RES_UPLOAD_STRSES(path, content, type, permissions, uid, gid, auth_name, auth_pwd);
}
;

-------------------------------------------------------------------------------
--
create procedure ODRIVE.WA.DAV_RDF_UPLOAD (
  inout content any,
  in type varchar,
  in graph varchar)
{
  declare retValue integer;
  declare graph2 varchar;

  graph2 := 'http://local.virt/temp';
  retValue := DB.DBA.RDF_SINK_UPLOAD ('/temp', content, type, graph, 'on', '', '');
  SPARQL clear graph ?:graph2;

  return retValue;
}
;

-------------------------------------------------------------------------------
--
create procedure ODRIVE.WA.DAV_RES_CONTENT (
  in path varchar,
  in auth_name varchar := null,
  in auth_pwd varchar := null)
{
  declare uname, gname varchar;
  declare content, contentType any;

  declare retValue any;

  ODRIVE.WA.DAV_API_PARAMS (null, null, uname, gname, auth_name, auth_pwd);
  retValue := DB.DBA.DAV_RES_CONTENT (path, content, contentType, auth_name, auth_pwd);
  if (retValue >= 0)
    return content;
  return retValue;
}
;

-------------------------------------------------------------------------------
--
create procedure ODRIVE.WA.content_excerpt(
  in path varchar,
  in words any)
{
  declare S, W any;

  S := ODRIVE.WA.DAV_RES_CONTENT(path);
  if (ODRIVE.WA.DAV_ERROR(S))
    return '';
  FTI_MAKE_SEARCH_STRING_INNER (words, W);
  return ODRIVE.WA.show_excerpt(S, W);
}
;

-------------------------------------------------------------------------------
--
create procedure ODRIVE.WA.DAV_COL_CREATE (
  in path varchar,
  in permissions varchar := '110100000R',
  in uid integer,
  in gid integer,
  in auth_name varchar := null,
  in auth_pwd varchar := null)
{
  declare uname, gname varchar;

  ODRIVE.WA.DAV_API_PARAMS (uid, gid, uname, gname, auth_name, auth_pwd);
  return DB.DBA.DAV_COL_CREATE(path, permissions, uname, gname, auth_name, auth_pwd);
}
;

-------------------------------------------------------------------------------
--
create procedure ODRIVE.WA.DAV_PROP_LIST (
  in path varchar,
  in propmask varchar := '%',
  in skips varchar := null,
  in auth_name varchar := null,
  in auth_pwd varchar := null)
{
  declare uname, gname varchar;
  declare props any;

  ODRIVE.WA.DAV_API_PARAMS (null, null, uname, gname, auth_name, auth_pwd);
  props := DB.DBA.DAV_PROP_LIST(path, propmask, auth_name, auth_pwd);
  if (ODRIVE.WA.DAV_ERROR (props))
    return vector ();
  if (isnull(skips))
    return props;

  declare remains any;

  remains := vector();
  foreach(any prop in props) do
  {
    foreach(any skip in skips) do
      if (prop[0] like skip)
        goto _skip;
    remains := vector_concat(remains, vector(prop));
  _skip: ;
  }
  return remains;
}
;

-------------------------------------------------------------------------------
--
create procedure ODRIVE.WA.DAV_PROP_GET (
  in path varchar,
  in propName varchar,
  in propValue varchar := null,
  in auth_name varchar := null,
  in auth_pwd varchar := null)
{
  -- dbg_obj_princ ('ODRIVE.WA.DAV_PROP_GET (', path, propName, ')');
  declare exit handler for SQLSTATE '*' {return propValue;};

  declare uname, gname varchar;
  declare retValue any;

  ODRIVE.WA.DAV_API_PARAMS (null, null, uname, gname, auth_name, auth_pwd);
  retValue := DB.DBA.DAV_PROP_GET(path, propName, auth_name, auth_pwd);
  if (isinteger(retValue) and (retValue < 0) and (not isnull(propValue)))
    return propValue;
  return retValue;
}
;

-------------------------------------------------------------------------------
--
create procedure ODRIVE.WA.DAV_PROP_SET (
  in path varchar,
  in propName varchar,
  in propValue any,
  in auth_name varchar := null,
  in auth_pwd varchar := null,
  in removeBefore integer := 1)
{
  -- dbg_obj_princ ('ODRIVE.WA.DAV_PROP_SET (', path, propName, propValue, ')');
  declare uname, gname varchar;
  declare retValue any;

  ODRIVE.WA.DAV_API_PARAMS (null, null, uname, gname, auth_name, auth_pwd);
  if (removeBefore)
    retValue := DB.DBA.DAV_PROP_REMOVE (path, propName, auth_name, auth_pwd);

  return DB.DBA.DAV_PROP_SET (path, propName, propValue, auth_name, auth_pwd);
}
;

-------------------------------------------------------------------------------
--
create procedure ODRIVE.WA.DAV_PROP_TAGS_SET (
  in path varchar,
  in propname varchar,
  in propvalue any,
  in auth_name varchar := null,
  in auth_pwd varchar := null)
{
  declare uname, gname varchar;

  ODRIVE.WA.DAV_API_PARAMS (null, null, uname, gname, auth_name, auth_pwd);
  DB.DBA.DAV_PROP_REMOVE(path, propname, auth_name, auth_pwd);
  if (propvalue = '')
    return 1;
  return DB.DBA.DAV_PROP_SET(path, propname, propvalue, auth_name, auth_pwd);

}
;

-------------------------------------------------------------------------------
--
create procedure ODRIVE.WA.DAV_RDF_PROP_GET (
  in path varchar,			      -- Path to the resource or collection
  in single_schema varchar,   -- Name of single RDF schema to filter out redundant records or NULL to compose any number of properties.
  in auth_name varchar := null,
  in auth_pwd varchar := null)
{
  declare uname, gname varchar;

  ODRIVE.WA.DAV_API_PARAMS (null, null, uname, gname, auth_name, auth_pwd);
  return DB.DBA.DAV_RDF_PROP_GET(path, single_schema, auth_name, auth_pwd);
}
;

-------------------------------------------------------------------------------
--
create procedure ODRIVE.WA.DAV_RDF_PROP_SET (
  in path varchar,			      -- Path to the resource or collection
  in single_schema varchar,   -- Name of single RDF schema to filter out redundant records or NULL to compose any number of properties.
  in rdf any,				          -- RDF XML
  in auth_name varchar := null,
  in auth_pwd varchar := null)
{
  declare uname, gname varchar;

  ODRIVE.WA.DAV_API_PARAMS (null, null, uname, gname, auth_name, auth_pwd);
  return DB.DBA.DAV_RDF_PROP_SET_INT(path, single_schema, rdf, auth_name, auth_pwd, 1, 1, 1);
}
;

-------------------------------------------------------------------------------
--
create procedure ODRIVE.WA.DAV_PROP_REMOVE (
  in path varchar,
  in propname varchar,
  in auth_name varchar := null,
  in auth_pwd varchar := null)
{
  declare uname, gname varchar;

  -- dbg_obj_princ ('ODRIVE.WA.DAV_PROP_REMOVE (', path, propName, ')');
  ODRIVE.WA.DAV_API_PARAMS (null, null, uname, gname, auth_name, auth_pwd);
  return DB.DBA.DAV_PROP_REMOVE(path, propname, auth_name, auth_pwd);
}
;

-------------------------------------------------------------------------------
--
create procedure ODRIVE.WA.DAV_IS_LOCKED (
  in path varchar,
  in type varchar := 'R')
{
  declare id integer;

  id := DB.DBA.DAV_SEARCH_ID(path, type);
  return DB.DBA.DAV_IS_LOCKED(id, type);
}
;

-------------------------------------------------------------------------------
--
create procedure ODRIVE.WA.DAV_LOCK (
  in path varchar,
  in type varchar := 'R',
  in auth_name varchar := null,
  in auth_pwd varchar := null)
{
  declare retValue varchar;
  declare uname, gname varchar;

  ODRIVE.WA.DAV_API_PARAMS (null, null, uname, gname, auth_name, auth_pwd);
  retValue := DB.DBA.DAV_LOCK (path, type, '', '', auth_name, null, null, null, auth_name, auth_pwd);
  if (isstring (retValue))
    return 1;
	return retValue;
}
;

-------------------------------------------------------------------------------
--
create procedure ODRIVE.WA.DAV_UNLOCK (
  in path varchar,
  in type varchar := 'R',
  in auth_name varchar := null,
  in auth_pwd varchar := null)
{
  declare id integer;
  declare locks, retValue any;
  declare uname, gname varchar;

  ODRIVE.WA.DAV_API_PARAMS (null, null, uname, gname, auth_name, auth_pwd);
  id := DB.DBA.DAV_SEARCH_ID(path, type);
  locks := DB.DBA.DAV_LIST_LOCKS_INT (id, type);
  foreach (any lock in locks) do
  {
    retValue := DB.DBA.DAV_UNLOCK (path, lock[2], auth_name, auth_pwd);
    if (ODRIVE.WA.DAV_ERROR (retValue))
      return retValue;
  }
  return 1;
}
;

-------------------------------------------------------------------------------
--
create procedure ODRIVE.WA.get_rdf (
  in graphName varchar)
{
  declare sql, st, msg, meta, rows any;

  sql := sprintf('sparql define output:format ''RDF/XML'' construct { ?s ?p ?o } where { graph <%s> { ?s ?p ?o } }', graphName);
  st := '00000';
  exec (sql, st, msg, vector (), 0, meta, rows);
  if ('00000' = st)
    return rows[0][0];
  return '';
}
;

-----------------------------------------------------------------------------------------
--
create procedure ODRIVE.WA.test_clear (
  in S any)
{
  S := substring (S, 1, coalesce (strstr (S, '<>'), length (S)));
  S := substring (S, 1, coalesce (strstr (S, '\nin'), length (S)));

  return S;
}
;

-----------------------------------------------------------------------------------------
--
create procedure ODRIVE.WA.test (
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
  if (isnull (tmp))
  {
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

  value := ODRIVE.WA.validate2 (valueClass, value);

  if (valueType = 'integer') {
    tmp := get_keyword('minValue', params);
    if ((not isnull(tmp)) and (value < tmp))
      signal('MIN', cast(tmp as varchar));

    tmp := get_keyword('maxValue', params);
    if (not isnull(tmp) and (value > tmp))
      signal('MAX', cast(tmp as varchar));
  }
  else if (valueType = 'float')
  {
    tmp := get_keyword('minValue', params);
    if (not isnull(tmp) and (value < tmp))
      signal('MIN', cast(tmp as varchar));

    tmp := get_keyword('maxValue', params);
    if (not isnull(tmp) and (value > tmp))
      signal('MAX', cast(tmp as varchar));
  }
  else if (valueType = 'varchar')
  {
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
create procedure ODRIVE.WA.validate2 (
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
    if (isnull(regexp_match('^((?:19|20)[0-9][0-9])[- /.](0[1-9]|1[012])[- /.](0[1-9]|[12][0-9]|3[01])\$', propertyValue)))
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
    return cast(propertyValue as datetime);
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
      vt_parse(propertyValue);
  } else if (propertyType = 'tags') {
    if (not ODRIVE.WA.validate_tags(propertyValue))
      goto _error;
  }
  return propertyValue;

_error:
  signal('CLASS', propertyType);
}
;

-----------------------------------------------------------------------------------------
--
create procedure ODRIVE.WA.validate_ftext (
  in S varchar)
{
  declare st, msg varchar;

  st := '00000';
  exec ('vt_parse (?)', st, msg, vector (S));
  if ('00000' = st)
    return 1;
  return 0;
}
;

-----------------------------------------------------------------------------------------
--
create procedure ODRIVE.WA.validate_tag (
  in S varchar)
{
  S := replace(trim(S), '+', '_');
  S := replace(trim(S), ' ', '_');
  if (not ODRIVE.WA.validate_ftext(S))
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
create procedure ODRIVE.WA.validate_tags (
  in S varchar)
{
  declare N integer;
  declare V any;

  if (is_empty_or_null(S))
    return 1;
  V := ODRIVE.WA.tags2vector(S);
  if (is_empty_or_null(V))
    return 0;
  if (length(V) <> length(ODRIVE.WA.tags2unique(V)))
    return 0;
  for (N := 0; N < length(V); N := N + 1)
    if (not ODRIVE.WA.validate_tag(V[N]))
      return 0;
  return 1;
}
;

-----------------------------------------------------------------------------------------
--
create procedure ODRIVE.WA.oMail_check()
{
  declare account_id integer;

  account_id := (select U_ID from WS.WS.SYS_DAV_USER where U_NAME = ODRIVE.WA.account());
  return coalesce((select top 1 WAI_ID from DB.DBA.WA_MEMBER, DB.DBA.WA_INSTANCE where WAM_INST = WAI_NAME and WAM_USER = account_id and WAI_TYPE_NAME = 'oMail' order by WAI_ID), 0);
}
;

-----------------------------------------------------------------------------------------
--
create procedure ODRIVE.WA.check_app (
  in app_type varchar,
  in user_id integer)
{
  return coalesce((select top 1 WAI_ID from DB.DBA.WA_MEMBER, DB.DBA.WA_INSTANCE where WAM_INST = WAI_NAME and WAM_USER = user_id and WAI_TYPE_NAME = app_type order by WAI_ID), 0);
}
;

-----------------------------------------------------------------------------------------
--
create procedure ODRIVE.WA.version_update()
{
  declare uname, home, source, target varchar;

  for (select U_NAME
         from DB.DBA.WA_MEMBER,
              DB.DBA.WA_INSTANCE,
              DB.DBA.SYS_USERS
        where WAI_NAME = WAM_INST
          and WAI_TYPE_NAME = 'oDrive'
          and WAM_MEMBER_TYPE = 1
          and WAM_USER = U_ID) do
  {
    ODRIVE.WA.odrive_user_initialize(U_NAME);
    home := ODRIVE.WA.dav_home(U_NAME);
    if (not isnull(home)) {
      source := concat(home, 'My Items/');
      target := concat(home, 'Items/');
      DB.DBA.DAV_MOVE_INT(source, target, 1, null, null, 0);
    }
  }
  return;
}
;

-----------------------------------------------------------------------------------------
--
ODRIVE.WA.version_update()
;

-------------------------------------------------------------------------------
--
create procedure ODRIVE.WA.ui_image (
  in itemPath varchar,
  in itemType varchar,
  in itemMimeType varchar)
{
  if (itemType = 'C')
  {
    declare det_type varchar;

    det_type := ODRIVE.WA.det_type (itemPath, itemType);
    if (det_type = 'CatFilter')
      return 'image/dav/category_16.png';
    if (det_type = 'PropFilter')
      return 'image/dav/property_16.png';
    if (det_type = 'HostFs')
      return 'image/dav/hostfs_16.png';
    if (det_type = 'Versioning')
      return 'image/dav/versions_16.png';
    if (det_type = 'News3')
      return 'image/dav/enews_16.png';
    if (det_type = 'Blog')
      return 'image/dav/blog_16.png';
    if (det_type = 'oMail')
      return 'image/dav/omail_16.png';
    return 'image/dav/foldr_16.png';
  }
  if (itemPath like '%.txt')
    return 'image/dav/text.gif';
  if (itemPath like '%.pdf')
    return 'image/dav/pdf.gif';
  if (itemPath like '%.html')
    return 'image/dav/html.gif';
  if (itemPath like '%.htm')
    return 'image/dav/html.gif';
  if (itemPath like '%.wav')
    return 'image/dav/wave.gif';
  if (itemPath like '%.ogg')
    return 'image/dav/wave.gif';
  if (itemPath like '%.flac')
    return 'image/dav/wave.gif';
  if (itemPath like '%.wma')
    return 'image/dav/wave.gif';
  if (itemPath like '%.wmv')
    return 'image/dav/video.gif';
  if (itemPath like '%.doc')
    return 'image/dav/msword.gif';
  if (itemPath like '%.dot')
    return 'image/dav/msword.gif';
  if (itemPath like '%.xls')
    return 'image/dav/xls.gif';
  if (itemPath like '%.zip')
    return 'image/dav/zip.gif';
  if (itemMimeType like 'audio/%')
    return 'image/dav/wave.gif';
  if (itemMimeType like 'video/%')
    return 'image/dav/video.gif';
  if (itemMimeType like 'image/%')
    return 'image/dav/image.gif';
  return 'image/dav/generic_file.png';
}
;

-------------------------------------------------------------------------------
--
create procedure ODRIVE.WA.ui_alt (
  in itemPath varchar,
  in itemType varchar)
{
  return case when (itemType = 'C') then 'Folder: ' else 'File: ' end || itemPath ;
}
;

-------------------------------------------------------------------------------
--
create procedure ODRIVE.WA.ui_size (
  in itemSize integer,
  in itemType varchar := 'R')
{
  declare S varchar;

  if ((itemSize = 0) and (itemType = 'C'))
    return '';

  S := '%d<span style="font-family: Monospace;">&nbsp;%s</span>';
  if (itemSize < 1024)
    return sprintf (S, itemSize, 'B&nbsp;');
  if (itemSize < (1024 * 1024))
    return sprintf (S, floor(itemSize / 1024), 'KB');
  if (itemSize < (1024 * 1024 * 1024))
    return sprintf (S, floor(itemSize / (1024 * 1024)), 'MB');
  if (itemSize < (1024 * 1024 * 1024 * 1024))
    return sprintf (S, floor(itemSize / (1024 * 1024 * 1024)), 'GB');
  return sprintf (S, floor(itemSize / (1024 * 1024 * 1024 * 1024)), 'TB');
}
;

-------------------------------------------------------------------------------
--
create procedure ODRIVE.WA.ui_date (
  in itemDate datetime)
{
	itemDate := left (cast (itemDate as varchar), 19);
	return sprintf ('%s <font size="1">%s</font>', left(itemDate, 10), right(itemDate, 8));
}
;

-------------------------------------------------------------------------------
--
create procedure ODRIVE.WA.send_mail (
  in _instance integer,
  in _from integer,
  in _to integer,
  in _body varchar,
  in _path varchar)
{
  declare N, _id, _what, _iri any;
  declare _smtp_server, _from_address, _to_address, _toUsers, _toBody, _message any;

  if ((select max (WS_USE_DEFAULT_SMTP) from WA_SETTINGS) = 1 or (select length (max (WS_SMTP)) from WA_SETTINGS) = 0)
  {
    _smtp_server := cfg_item_value (virtuoso_ini_path (), 'HTTPServer', 'DefaultMailServer');
  } else {
    _smtp_server := (select max (WS_SMTP) from WA_SETTINGS);
  }
  if (_smtp_server <> 0)
  {
     _iri := SIOC..briefcase_iri (ODRIVE.WA.domain_name (_instance));
     _what := case when (_path[length (_path)-1] <> ascii('/')) then 'R' else 'C' end;
     if (_what = 'C')
       _iri := _iri || '/folder';
     _id := DB.DBA.DAV_SEARCH_ID (_path, _what);

    if (exists (select 1 from SYS_USERS where U_ID = _to and U_IS_ROLE = 1))
    {
      _toUsers := vector ();
      for (select UG_UID from DB.DBA.SYS_USER_GROUP, DB.DBA.SYS_USERS where UG_GID = _to and U_ID = UG_UID and U_IS_ROLE = 0 and U_ACCOUNT_DISABLED = 0) do
        _toUsers := vector_concat (_toUsers, vector (UG_UID));
    } else {
      _toUsers := vector (_to);
    }
    _toBody := _body;
    for (N := 0; N < length (_toUsers); N := N + 1)
    {
      _to := _toUsers[N];
      _body := _toBody;
    _body := replace (_body, '%resource_path%', _path);
    _body := replace (_body, '%resource_uri%', SIOC..post_iri_ex (_iri, _id));
    _body := replace (_body, '%owner_uri%', SIOC..person_iri (SIOC..user_iri (_from)));
    _body := replace (_body, '%owner_name%', ODRIVE.WA.account_name (_from));
    _body := replace (_body, '%user_uri%', SIOC..person_iri (SIOC..user_iri (_to)));
    _body := replace (_body, '%user_name%', ODRIVE.WA.account_name (_to));
    _message := 'Subject: Sharing notification\r\nContent-Type: text/plain\r\n' || _body;
    _from_address := (select U_E_MAIL from SYS_USERS where U_ID = _from);
    _to_address := (select U_E_MAIL from SYS_USERS where U_ID = _to);
    {
      declare exit handler for sqlstate '*'
      {
        return;
      };
        --dbg_obj_print (_from_address, _to_address);
      smtp_send (_smtp_server, _from_address, _to_address, _message);
    }
  }
}
}
;

-------------------------------------------------------------------------------
--
create procedure ODRIVE.WA.acl_send_mail (
  in _instance integer,
  in _from integer,
  in _path varchar,
  in _old_acl any,
  in _new_acl any)
{
  declare N, M integer;
  declare oACLs, oACL, nACLs, nACL, settings, text any;

  settings := ODRIVE.WA.settings (_from);
  text := ODRIVE.WA.settings_mailShare (settings);
  oACLs := ODRIVE.WA.acl_vector (_old_acl);
  nACLs := ODRIVE.WA.acl_vector (_new_acl);
  for (N := 0; N < length (nACLs); N := N + 1)
  {
    for (M := 0; M < length (oACLs); M := M + 1)
    {
      if (nACLs[N][0] = oACLs[M][0])
        goto _skip;
    }
    ODRIVE.WA.send_mail (_instance, _from, nACLs[N][0], text, _path);
  _skip:;
  }
  for (N := 0; N < length (oACLs); N := N + 1)
  {
    for (M := 0; M < length (nACLs); M := M + 1)
    {
      if (oACLs[N][0] = nACLs[M][0])
        goto _skip2;
    }
    ODRIVE.WA.send_mail (_instance, _from, oACLs[N][0], text, _path);
  _skip2:;
  }
}
;

-------------------------------------------------------------------------------
--
create procedure ODRIVE.WA.aci_parents (
  in path varchar)
{
  declare N integer;
  declare tmp, V, aPath any;

  tmp := '/';
  V := vector ();
  aPath := split_and_decode (trim (path, '/'), 0, '\0\0/');
  for (N := 0; N < length (aPath)-1; N := N + 1)
  {
    tmp := tmp || aPath[N] || '/';
    V := vector_concat (V, vector (tmp));
  }
  return V;
}
;

-------------------------------------------------------------------------------
--
create procedure ODRIVE.WA.aci_load (
  in path varchar)
{
  declare id, what, retValue, graph any;
  declare S, st, msg, meta, rows any;

  what := case when (path[length (path)-1] <> ascii('/')) then 'R' else 'C' end;
  id := ODRIVE.WA.DAV_SEARCH_ID (path, what);
  if (isarray (id))
  {
    retValue := ODRIVE.WA.DAV_PROP_GET (path, 'virt:aci_meta');
    if (ODRIVE.WA.DAV_ERROR (retValue))
      retValue := vector ();
  }
  else
  {
  retValue := vector ();
    graph := rtrim (WS.WS.DAV_IRI (path), '/') || '/';
  S := sprintf (' sparql \n' ||
                ' define input:storage "" \n' ||
                ' prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> \n' ||
                ' prefix foaf: <http://xmlns.com/foaf/0.1/> \n' ||
                ' prefix acl: <http://www.w3.org/ns/auth/acl#> \n' ||
                  ' prefix flt: <http://www.openlinksw.com/schemas/acl/filter#> \n' ||
                  ' select distinct ?rule ?agent ?mode ?filter ?criteria ?operand ?condition ?pattern ?statement \n' ||
                '   from <%s> \n' ||
                '  where { \n' ||
                '          { \n' ||
                '            ?rule rdf:type acl:Authorization ; \n' ||
                '            acl:accessTo <%s> ; \n' ||
                '            acl:mode ?mode ; \n' ||
                '            acl:agent ?agent. \n' ||
                '          } \n' ||
                '          union \n' ||
                '          { \n' ||
                '            ?rule rdf:type acl:Authorization ; \n' ||
                '            acl:accessTo <%s> ; \n' ||
                '            acl:mode ?mode ; \n' ||
                '            acl:agentClass ?agent. \n' ||
                '          } \n' ||
                  '          union \n' ||
                  '          { \n' ||
                  '            ?rule rdf:type acl:Authorization ; \n' ||
                  '                  acl:accessTo <%s> ; \n' ||
                  '                  acl:mode ?mode ; \n' ||
                  '                  flt:hasFilter ?filter . \n' ||
                  '            ?filter flt:hasCriteria ?criteria . \n' ||
                  '            ?criteria flt:operand ?operand ; \n' ||
                  '                      flt:condition ?condition ; \n' ||
                  '                      flt:value ?pattern . \n' ||
                  '            OPTIONAL { ?criteria flt:statement ?statement . } \n' ||
                  '          } \n' ||
                '        }\n' ||
                  '  order by ?rule ?filter ?criteria\n',
                  graph,
                graph,
                graph,
                graph);
  commit work;
  st := '00000';
    exec (S, st, msg, vector (), 0, meta, rows);
    if (st = '00000')
  {
      declare aclNo, aclRule, aclMode, aclCriteria, V, F any;

    aclNo := 0;
    aclRule := '';
      V := null;
      F := vector ();
      aclCriteria := '';
      foreach (any row in rows) do
    {
        if (aclRule <> row[0])
      {
        if (not isnull (V))
          retValue := vector_concat (retValue, vector (V));

        aclNo := aclNo + 1;
          aclRule := row[0];
          V := vector (aclNo, ODS.ODS_API."ontology.normalize" (row[1]), 'person', 0, 0, 0);
          F := vector ();
          aclCriteria := '';
      }
        if (ODS.ODS_API."ontology.normalize" (row[1]) = 'foaf:Agent')
        V[2] := 'public';
        if (row[1] like SIOC.DBA.get_graph () || '/%/group/%')
        V[2] := 'group';
        if (row[3] like (graph || 'filter_%'))
        {
          V[2] := 'advanced';
          if (aclCriteria <> row[4])
          {
            F := vector_concat (F, vector (vector (1, replace (row[5], 'flt:', ''), replace (row[6], 'flt:', ''), row[7], row[8])));
            aclCriteria := row[4];
            V[1] := F;
          }
        }
        aclMode := ODS.ODS_API."ontology.normalize" (row[2]);
      if (aclMode = 'acl:Read')
        V[3] := 1;
      if (aclMode = 'acl:Write')
        V[4] := 1;
      if (aclMode = 'acl:Execute')
        V[5] := 1;
    }
    if (not isnull (V))
      retValue := vector_concat (retValue, vector (V));
  }
  }
  return retValue;
}
;

-------------------------------------------------------------------------------
--
create procedure ODRIVE.WA.aci_save (
  in path varchar,
  inout aci any)
{
  declare id, what, retValue, tmp any;

  what := case when (path[length (path)-1] <> ascii('/')) then 'R' else 'C' end;
  id := ODRIVE.WA.DAV_SEARCH_ID (path, what);
  if (isarray (id))
    retValue := ODRIVE.WA.DAV_PROP_SET (path, 'virt:aci_meta', aci);

  if (not isarray (id))
    retValue := ODRIVE.WA.DAV_PROP_SET (path, 'virt:aci_meta_n3', ODRIVE.WA.aci_n3 (aci));

  return retValue;
}
;

-------------------------------------------------------------------------------
--
create procedure ODRIVE.WA.aci_n3 (
  in aciArray any)
{
  declare N, M integer;
  declare stream any;

  if (length (aciArray) = 0)
    return null;


  stream := string_output ();
  http ('@prefix acl: <http://www.w3.org/ns/auth/acl#> . \n', stream);
  http ('@prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> . \n', stream);
  http ('@prefix foaf: <http://xmlns.com/foaf/0.1/> . \n', stream);
  http ('@prefix flt: <http://www.openlinksw.com/schemas/acl/filter#> . ', stream);
  for (N := 0; N < length (aciArray); N := N + 1)
  {
    if (length (aciArray[N][1]))
    {
      http (sprintf ('\n<aci_%d> rdf:type acl:Authorization ;\n        acl:accessTo <>', aciArray[N][0]), stream);
      if (aciArray[N][2] = 'person')
      {
        http (sprintf ('; \n        acl:agent <%s>', aciArray[N][1]), stream);
      }
      else if (aciArray[N][2] = 'group')
      {
        http (sprintf ('; \n        acl:agentClass <%s>', aciArray[N][1]), stream);
      }
      else if (aciArray[N][2] = 'public')
      {
        http (         '; \n        acl:agentClass foaf:Agent', stream);
      }
      else if (aciArray[N][2] = 'advanced')
      {
        http (sprintf ('; \n        flt:hasFilter <filter_%d>', aciArray[N][0]), stream);
      }
      if (aciArray[N][3])
        http ('; \n        acl:mode acl:Read', stream);
      if (aciArray[N][4])
        http ('; \n        acl:mode acl:Write', stream);
      if (aciArray[N][5])
        http ('; \n        acl:mode acl:Execute', stream);

      http ('. ', stream);
      if (aciArray[N][2] = 'advanced')
      {
        http (sprintf ('\n<filter_%d> rdf:type flt:Filter .', aciArray[N][0]), stream);
        for (M := 0; M < length (aciArray[N][1]); M := M + 1)
        {
          http (sprintf ('\n<filter_%d> flt:hasCriteria <criteria_%d_%d> .', aciArray[N][0], aciArray[N][0], aciArray[N][1][M][0]), stream);
          http (sprintf ('\n<criteria_%d_%d> flt:operand <flt:%s> ;', aciArray[N][0], aciArray[N][1][M][0], aciArray[N][1][M][1]), stream);
          http (sprintf ('\n               flt:condition <flt:%s> ;', aciArray[N][1][M][2]), stream);
          http (         '\n               flt:value ', stream); http_nt_object (aciArray[N][1][M][3], stream);
          if ((length (aciArray[N][1][M]) > 3) and not DB.DBA.is_empty_or_null (aciArray[N][1][M][4]))
          {
          http (         '; \n             flt:statement ', stream); http_nt_object (aciArray[N][1][M][4], stream);
        }
          http ('. \n', stream);
      }
    }
  }
  }
  return string_output_string (stream);
}
;

-------------------------------------------------------------------------------
--
create procedure ODRIVE.WA.path_normalize (
  in path varchar,
  in path_type varchar := 'P')
{
  declare N integer;

  path := trim (path);
  N := length (path);
  if (N > 0)
  {
    if (chr (path[0]) <> '/')
    {
      path := '/' || path;
    }
    if ((path_type = 'C') and (chr (path[N-1]) <> '/'))
    {
      path := path || '/';
    }
    if (chr (path[1]) = '~')
    {
      path := replace (path, '/~', '/DAV/home/');
    }
    if (path not like '/DAV/%')
    {
      path := '/DAV' || path;
    }
  }
  return path;
}
;

-------------------------------------------------------------------------------
--
create procedure ODRIVE.WA.path2ssl (
  in path varchar)
{
  declare pos any;
  declare V, sslData, sslPort any;

  sslData := ODS.ODS_API."server.getInfo"('sslPort');
  if (not isnull (sslData))
  {
    sslPort := get_keyword ('sslPort', sslData, 443);
    V := rfc1808_parse_uri (path);
    V[0] := 'https';

    pos := strrchr (V[1], ':');
    if (pos is not null)
      V[1] := subseq (V[1], 0, pos);
    V[1] := V[1] || case when sslPort <> 443 then ':' || cast (sslPort as varchar) else '' end;
    path := DB.DBA.vspx_uri_compose (V);

  }
  return path;
}
;

-------------------------------------------------------------------------------
--
create procedure ODRIVE.WA.syncml_detect (
  in path varchar)
{
  if (__proc_exists ('DB.DBA.yac_syncml_detect') is not null)
    return DB.DBA.yac_syncml_detect (path);

  return 0;
}
;

-------------------------------------------------------------------------------
--
create procedure ODRIVE.WA.syncml_versions ()
{
  if (__proc_exists ('DB.DBA.yac_syncml_version') is not null)
    return DB.DBA.yac_syncml_version ();

  return vector ();
}
;

-------------------------------------------------------------------------------
--
create procedure ODRIVE.WA.syncml_version (
  in path varchar)
{
  if (__proc_exists ('DB.DBA.yac_syncml_version_get') is not null)
    return DB.DBA.yac_syncml_version_get (path);

  return 'N';
}
;

-------------------------------------------------------------------------------
--
create procedure ODRIVE.WA.syncml_types ()
{
  if (__proc_exists ('DB.DBA.yac_syncml_type') is not null)
    return DB.DBA.yac_syncml_type ();

  return vector ();
}
;

-------------------------------------------------------------------------------
--
create procedure ODRIVE.WA.syncml_type (
  in path varchar)
{
  if (__proc_exists ('DB.DBA.yac_syncml_type_get') is not null)
    return DB.DBA.yac_syncml_type_get (path);

  return 'N';
}
;

-------------------------------------------------------------------------------
--
create procedure ODRIVE.WA.cartridges_get ()
{
  declare retValue any;

  retValue := vector ();
  for (select RM_ID, RM_DESCRIPTION, ucase (cast (RM_DESCRIPTION as varchar (128))) as RM_SORT from DB.DBA.SYS_RDF_MAPPERS where RM_ENABLED = 1 order by 3) do
  {
    retValue := vector_concat (retValue, vector (vector (RM_ID, RM_DESCRIPTION)));
  }
  return retValue;
}
;

-------------------------------------------------------------------------------
--
create procedure ODRIVE.WA.metaCartridges_get ()
{
  declare items, retValue any;

  retValue := vector ();
  items := ODRIVE.WA.exec ('select MC_ID, MC_DESC, ucase (cast (MC_DESC as varchar (128))) as MC_SORT from DB.DBA.RDF_META_CARTRIDGES where MC_ENABLED = 1 order by 3');
  foreach (any item in items) do
  {
    retValue := vector_concat (retValue, vector (vector (item[0], item[1])));
  }
  return retValue;
}
;
