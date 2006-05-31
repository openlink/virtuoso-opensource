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
-- Freeze Functions
--
-------------------------------------------------------------------------------
create procedure ODRIVE.WA.frozen_check()
{
  declare owner_id integer;

  declare exit handler for not found { return 1; };

  owner_id := (select U_ID from SYS_USERS where U_NAME = ODRIVE.WA.odrive_user());
  if (is_empty_or_null((select TOP 1 1 from DB.DBA.WA_MEMBER, DB.DBA.WA_INSTANCE where WAI_TYPE_NAME = 'oDrive' and  WAI_IS_FROZEN = 1 and WAI_NAME = WAM_INST and WAM_USER = owner_id)))
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
create procedure ODRIVE.WA.frozen_page(in domain_id integer)
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
  if (isstring(usr))
    usr := (select U_ID from SYS_USERS where U_NAME = usr);

  declare grp integer;
  grp := (select U_GROUP from SYS_USERS where U_ID = usr);

  if (usr = 0)
    return 1;
  if (usr = http_dav_uid ())
    return 1;
  if (grp = 0)
    return 1;
  if (grp = http_dav_uid ())
    return 1;
  if(grp = http_dav_uid()+1)
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
  declare
    user_id,
    group_id,
    role_id integer;

  whenever not found goto nf;

  if (user_name='')
    return 0;
  select U_ID, U_GROUP into user_id, group_id from DB.DBA.SYS_USERS where U_NAME=user_name;
  if (user_id = 0 OR group_id = 0)
    return 1;
  return 1;
  if (role_name is null or role_name = '')
    return 0;
  select U_ID into role_id from DB.DBA.SYS_USERS where U_NAME=role_name;
  if (exists(select 1 from DB.DBA.SYS_ROLE_GRANTS where GI_SUPER=user_id and GI_SUB=role_id))
    return 1;
nf:
  return 0;
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
create procedure ODRIVE.WA.odrive_get_page_name ()
{
  declare path, url, elm varchar;
  declare arr any;

  path := http_path ();
  arr := split_and_decode (path, 0, '\0\0/');
  elm := arr [length (arr) - 1];
  url := xpath_eval ('//*[@url = "'|| elm ||'"]', xml_tree_doc (ODRIVE.WA.odrive_menu_tree ()));
  if ((url is not null) or (elm = 'error.vspx'))
    return elm;
  return '';
}
;

-------------------------------------------------------------------------------
--
create procedure ODRIVE.WA.odrive_menu_tree ()
{
  return sprintf (
'<?xml version="1.0" ?>
<odrive_menu_tree>
  <node name="Browse" url="home.vspx" id="1" tip="DAV Browser" allowed="owner">
    <node name="11" url="settings.vspx" id="11" place="link" allowed="owner"/>
  </node>
  <node name="Groups" url="groups.vspx" id="2" tip="Groups" allowed="owner">
    <node name="21" url="groups_update.vspx" id="21" place="link" allowed="owner"/>
  </node>
  <node name="Metadata" url="vmds.vspx" id="3" tip="Metadata Addministration" allowed="owner">
    <node name="Schemas" url="vmds.vspx" id="31" tip="Schema Addministration" allowed="owner">
      <node name="211" url="vmds_update.vspx" id="311" place="link" allowed="owner"/>
    </node>
    <node name="Mime Types" url="mimes.vspx" id="32" tip="Mime Type Addministration" allowed="owner">
      <node name="221" url="mimes_update.vspx" id="321" place="link" allowed="owner"/>
    </node>
  </node>
  <node name="%s" url="%s" id="5" allowed="public guest member owner admin"/>
</odrive_menu_tree>', ODRIVE.WA.wa_home_title (), ODRIVE.WA.wa_home_link ());
}
;

-------------------------------------------------------------------------------
--
create procedure ODRIVE.WA.odrive_navigation_root(
  in path varchar)
{
  return xpath_eval ('/odrive_menu_tree/*', xml_tree_doc (ODRIVE.WA.odrive_menu_tree ()), 0);
}
;

-------------------------------------------------------------------------------
--
create procedure ODRIVE.WA.odrive_navigation_child (in path varchar, in node any)
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
    pUser := ODRIVE.WA.odrive_user();
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
    pUser := ODRIVE.WA.odrive_user();
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
  declare
    N integer;
  declare
    ch,
    S varchar;

  S := '';
  N := 1;
  while (N <= length(pFormat)) {
    ch := chr(pFormat[N]);
    if (ch = 'M') {
      S := concat(S, xslt_format_number(month(pDate), '00'));
    } else {
      if (ch = 'm') {
        S := concat(S, xslt_format_number(month(pDate), '##'));
      } else {
        if (ch = 'Y') {
          S := concat(S, xslt_format_number(year(pDate), '0000'));
        } else {
          if (ch = 'y') {
            S := concat(S, substring(xslt_format_number(year(pDate), '0000'),3,2));
          } else {
            if (ch = 'd') {
              S := concat(S, xslt_format_number(dayofmonth(pDate), '##'));
            } else {
              if (ch = 'D') {
                S := concat(S, xslt_format_number(dayofmonth(pDate), '00'));
              } else {
                if (ch = 'H') {
                  S := concat(S, xslt_format_number(hour(pDate), '00'));
                } else {
                  if (ch = 'h') {
                    S := concat(S, xslt_format_number(hour(pDate), '##'));
                  } else {
                    if (ch = 'N') {
                      S := concat(S, xslt_format_number(minute(pDate), '00'));
                    } else {
                      if (ch = 'n') {
                        S := concat(S, xslt_format_number(minute(pDate), '##'));
                      } else {
                        if (ch = 'S') {
                          S := concat(S, xslt_format_number(second(pDate), '00'));
                        } else {
                          if (ch = 's') {
                            S := concat(S, xslt_format_number(second(pDate), '##'));
                          } else {
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
};

-------------------------------------------------------------------------------
--
create procedure ODRIVE.WA.dt_deformat(
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
--  Returns:
--    N -  if pAny is in pArray
--   -1 -  otherwise
-------------------------------------------------------------------------------
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
  declare exit handler for sqlstate '*' { return S; };

  return charset_recode (S, 'UTF-8', '_WIDE_');
}
;

-------------------------------------------------------------------------------
--
create procedure ODRIVE.WA.wide2utf (
  inout S any)
{
  declare exit handler for sqlstate '*' { return S; };

  return charset_recode (S, '_WIDE_', 'UTF-8' );
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
create procedure ODRIVE.WA.odrive_proc(
  in path varchar,
  in dir_select integer := 0,
  in dir_mode integer := 0,
  in dir_params any := null,
  in dir_account any := null,
  in dir_psw any := null) returns any
{
  declare
    i, pos integer;
  declare
    tmp, dirFilter, dirList, sharedRoot, sharedFilter, sharedPath, sharedList any;
  declare
    vspx_user, user_name, group_name varchar;
  declare
    user_id, group_id integer;
  declare
    c2 integer;
  declare
    c0, c1, c3, c4, c5, c6, c7, c8, c9 varchar;

  result_names(c0, c1, c2, c3, c4, c5, c6, c7, c8, c9);

  path := trim(path);
  if (is_empty_or_null(path)) {
    dirList := ODRIVE.WA.odrive_shortcuts();
    for (i := 0; i < length(dirList); i := i + 2)
      result(dirList[i], 'C', 0, '', '', '', '', '', concat('/', dirList[i], '/'));
    return;
  }

  declare exit handler for SQLSTATE '*' {
    result(__SQL_STATE, __SQL_MESSAGE, 0, '', '', '', '', '', '');
    return;
  };

  dirList := vector();
  if ((dir_mode = 0) or (dir_select = 1)) {
    if (path = ODRIVE.WA.shared_name()) {
      vspx_user := ODRIVE.WA.odrive_user();
      dirList := ODRIVE.WA.odrive_sharing_dir_list(vspx_user);
    } else {
      path := ODRIVE.WA.odrive_real_path(path);
      dirList := ODRIVE.WA.DAV_DIR_LIST(path, 0);
    }
    dirFilter := '%';

  } else if (dir_mode = 1) {
    path := ODRIVE.WA.odrive_real_path(path);
    dirList := ODRIVE.WA.DAV_DIR_LIST(path, 0);
    dirFilter := dir_params;
    if (is_empty_or_null(dirFilter))
      dirFilter := '%';
    dirFilter := trim(dirFilter, '*');
    dirFilter := '%' || dirFilter || '%';
    dirFilter := replace(dirFilter, '%%', '%');

  } else if ((dir_mode = 2) or (dir_mode = 3)) {
    if (dir_mode = 2) {
      path := ODRIVE.WA.odrive_real_path(path);
      dirFilter := vector();
      ODRIVE.WA.dav_dc_subfilter(dirFilter, 'RES_NAME', 'like', dir_params);
    } else {
      path := ODRIVE.WA.odrive_real_path(ODRIVE.WA.dav_dc_get(dir_params, 'base', 'path', '/DAV/'));
      dirFilter := ODRIVE.WA.dav_dc_filter(dir_params);
    }
    --dbg_obj_print(dirFilter);
    if (trim(path, '/') = ODRIVE.WA.shared_name()) {
      sharedRoot := ODRIVE.WA.odrive_sharing_dir_list(ODRIVE.WA.odrive_user());
      foreach (any item in sharedRoot) do {
        if (item[1] = 'C') {
          sharedList := ODRIVE.WA.DAV_DIR_FILTER(item[0], 1, dirFilter);
        } else {
          pos := strrchr (item[0], '/');
          if (not isnull(pos)) {
            sharedPath := subseq (item[0], 0, pos+1);
            sharedFilter := dirFilter;
            ODRIVE.WA.dav_dc_subfilter(sharedFilter, 'RES_NAME', '=', item[10]);
            sharedList := ODRIVE.WA.DAV_DIR_FILTER(sharedPath, 0, sharedFilter);
          }
        }
        if (isarray(sharedList))
          dirList := vector_concat(dirList, sharedList);
      }
    } else {
      dirList := ODRIVE.WA.DAV_DIR_FILTER(path, 1, dirFilter);
    }
    dirFilter := '%';

  } else if (dir_mode = 10) {
    dirFilter := vector();
    ODRIVE.WA.dav_dc_subfilter(dirFilter, 'RES_NAME', 'like', dir_params);
    dirList := DB.DBA.DAV_DIR_FILTER(path, 1, dirFilter, dir_account, ODRIVE.WA.DAV_API_PWD(dir_account));
    dirFilter := '%';

  } else if (dir_mode = 11) {
    path := ODRIVE.WA.odrive_real_path(ODRIVE.WA.dav_dc_get(dir_params, 'base', 'path', '/DAV/'));
    dirFilter := ODRIVE.WA.dav_dc_filter(dir_params);
    dirList := DB.DBA.DAV_DIR_FILTER(path, 1, dirFilter, dir_account, ODRIVE.WA.DAV_API_PWD(dir_account));
    dirFilter := '%';

  } else if (dir_mode = 20) {
    path := ODRIVE.WA.odrive_real_path(ODRIVE.WA.dav_dc_get(dir_params, 'base', 'path', '/DAV/'));
    dirFilter := ODRIVE.WA.dav_dc_filter(dir_params);
    dirList := DB.DBA.DAV_DIR_FILTER(path, 1, dirFilter, dir_account, ODRIVE.WA.DAV_API_PWD(dir_account));
    dirFilter := '%';
  }

  if (isarray(dirList)) {
    user_id := -1;
    group_id := -1;
    user_name := '';
    group_name := '';
    foreach (any item in dirList) do {
      if (isarray(item))
        if ((item[1] = 'C') or ((dir_select = 0) and (item[10] like dirFilter))) {
          if (user_id <> item[7]) {
            user_id := item[7];
            user_name := ODRIVE.WA.odrive_user_name(user_id);
          }
          if (group_id <> item[6]) {
            group_id := item[6];
            group_name := ODRIVE.WA.odrive_user_name(group_id);
          }
          tmp := coalesce((select RS_CATNAME from WS.WS.SYS_RDF_SCHEMAS, WS.WS.SYS_MIME_RDFS where RS_URI = MR_RDF_URI and MR_MIME_IDENT = item[9]), '~unknown~');
          result(item[either(gte(dir_mode,2),0,10)], item[1], item[2], left(cast(item[3] as varchar), 19), item[9], user_name, group_name, adm_dav_format_perms(item[5]), item[0], tmp);
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
  declare item any;
  item := ODRIVE.WA.DAV_INIT(path);
  if (isinteger(item))
    return 0;

  declare uid, gid integer;
  declare auth_name varchar;

  auth_name := ODRIVE.WA.odrive_user();
  uid := (select U_ID from WS.WS.SYS_DAV_USER where U_NAME = auth_name);
  gid := (select U_GROUP from WS.WS.SYS_DAV_USER where U_NAME = auth_name);

  if (isinteger(ODRIVE.WA.DAV_GET(item, 'id'))) {
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

  declare N, I, nPermission integer;
  if (isstring(permission))
    permission := vector(permission);
  for (N := 0; N < length(permission); N := N + 1) {
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
  inout path varchar)
{
  return ODRIVE.WA.odrive_effective_permissions(path, vector('1__', '__1'));
}
;

-----------------------------------------------------------------------------
--
create procedure ODRIVE.WA.odrive_write_permission (
  inout path varchar)
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

-----------------------------------------------------------------------------
--
create procedure ODRIVE.WA.odrive_user() returns varchar
{
  declare vspx_user varchar;

  vspx_user := connection_get('owner_user');
  if (isnull(vspx_user))
    vspx_user := connection_get('vspx_user');
  return vspx_user;
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
    user_name := ODRIVE.WA.odrive_user();
  if (exists(select 1 from DB.DBA.SYS_USERS u1, ODRIVE.WA.GROUPS g, DB.DBA.SYS_USERS u2 where u1.U_NAME=group_name and u1.U_ID=g.GROUP_ID and u1.U_IS_ROLE=1 and g.USER_ID=u2.U_ID and u2.U_NAME=user_name))
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
  declare user_home, user_category varchar;
  declare uid, gid, cid integer;
  declare retCode any;

  user_home := ODRIVE.WA.dav_home_create(user_name);
  if (isinteger(user_home))
    signal ('HOME', sprintf ('Home folder can not be created for user "%s".', user_name));

  DB.DBA.DAV_OWNER_ID(user_name, null, uid, gid);
  cid := DB.DBA.DAV_SEARCH_ID(user_home, 'C');
  if (not ODRIVE.WA.DAV_ERROR(cid)) {
    if ((select count(*) from WS.WS.SYS_DAV_COL where COL_PARENT = cid and COL_DET = 'CatFilter') = 0) {
      user_category := concat(user_home, 'Items/');
      cid := DB.DBA.DAV_SEARCH_ID(user_category, 'C');
      if (ODRIVE.WA.DAV_ERROR(cid))
        cid := ODRIVE.WA.DAV_COL_CREATE(user_category, '110100100R', uid, gid);
      if (ODRIVE.WA.DAV_ERROR(cid))
        signal ('CATS', concat('User''s category folder ''Items'' can not be created. ', ODRIVE.WA.DAV_PERROR(cid)));
      retCode := ODRIVE.WA.CatFilter_CONFIGURE_INT(user_category, user_home, vector());
    }
  }
}
;

-------------------------------------------------------------------------------
--
create procedure ODRIVE.WA.odrive_host_url ()
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
create procedure ODRIVE.WA.odrive_url ()
{
  return concat(ODRIVE.WA.odrive_host_url(), '/odrive/');
}
;

-----------------------------------------------------------------------------
--
create procedure ODRIVE.WA.odrive_dav_home(
  in user_name varchar := null) returns varchar
{
  declare user_home any;
  declare colID integer;

  if (isnull(user_name))
    user_name := ODRIVE.WA.odrive_user();
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
create procedure ODRIVE.WA.odrive_refine_path(
  in path varchar) returns varchar
{
  path := replace(path, '"', '');
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
  for (N := 0; N < length(parts); N := N + 1) {
    part := trim(parts[N]);
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
  in path varchar) returns varchar
{
  return ODRIVE.WA.odrive_real_path_int(path, 1);
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
  return 'Shared Folders';
}
;

-----------------------------------------------------------------------------
--
create procedure ODRIVE.WA.path_is_shortcut(
  in path varchar) returns integer
{
  if (isnull(get_keyword(ODRIVE.WA.odrive_refine_path(path), ODRIVE.WA.odrive_shortcuts())))
    return 0;
  return 1;
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

  shortcuts := vector(ODRIVE.WA.odrive_name_home(), vector(trim(ODRIVE.WA.odrive_dav_home(), '/'), 0), ODRIVE.WA.shared_name(), vector(ODRIVE.WA.shared_name(), 1));
  if (trim(ODRIVE.WA.odrive_dav_home(), '/') = 'DAV')
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

  shortcuts := vector(ODRIVE.WA.odrive_name_home(), vector(trim(ODRIVE.WA.odrive_dav_home(), '/'), 0), ODRIVE.WA.shared_name(), vector(ODRIVE.WA.shared_name(), 1));
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
  if (shortcut[showType] = 1) {
    if (N+1 < length(parts)) {

      declare name varchar;
      declare id integer;

      ODRIVE.WA.odrive_name_restore(parts[N+1], name, id);
      if (not isnull(id)) {
        if (pathType = 'R') {
          for (select RES_FULL_PATH from WS.WS.SYS_DAV_RES where RES_ID = id) do
            return left(trim(RES_FULL_PATH, '/'), strrchr(trim(RES_FULL_PATH, '/'), '/'));
        }
        if (pathType = 'C') {
          for (select WS.WS.COL_PATH(COL_ID) as COL_FULL_PATH from WS.WS.SYS_DAV_COL where COL_ID = id) do
            return left(trim(COL_FULL_PATH, '/'), strrchr(trim(COL_FULL_PATH, '/'), '/'));
        }
      } else {
        declare path varchar;
        declare uid integer;
        declare gid integer;
        DB.DBA.DAV_OWNER_ID(ODRIVE.WA.odrive_user(), null, uid, gid);

        if (pathType = 'R') {
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
        if (pathType = 'C') {
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

-----------------------------------------------------------------------------
--
create procedure ODRIVE.WA.odrive_acl_proc(
  in acl varbinary) returns any
{
  declare
    N,
    I integer;
  declare
    aAcl,
    aTmp any;

  aAcl := WS.WS.ACL_PARSE(acl, '0123', 0);
  aTmp := vector();

  for (N := 0; N < length(aAcl); N := N + 1)
    if (not aAcl[N][1])
      aTmp := vector_concat(aTmp, vector(vector(aAcl[N][0], aAcl[N][2], 0, aAcl[N][3])));

  for (N := 0; N < length(aAcl); N := N + 1) {
    if (aAcl[N][1]) {
      I := 0;
      while (I < length(aTmp)) {
        if ((aAcl[N][0] = aTmp[I][0]) and (aAcl[N][2] = aTmp[I][1])) {
          aset(aTmp, I, vector(aTmp[I][0], aTmp[I][1], aAcl[N][3], aTmp[I][3]));
          goto _exit;
        }
        I := I + 1;
      }
    _exit:
      if (I = length(aTmp))
        aTmp := vector_concat(aTmp, vector(vector(aAcl[N][0], aAcl[N][2], aAcl[N][3], 0)));
    }
  }

  declare
    c0, c1, c2, c3 integer;

  result_names(c0, c1, c2, c3);
  for (N := 0; N < length(aTmp); N := N + 1)
    result(aTmp[N][0], aTmp[N][1], aTmp[N][2], aTmp[N][3]);

  return;
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
        order by RES_NAME, RES_ID
      ) do
  {
    aResult := vector_concat(aResult, vector(vector (RES_FULL_PATH, 'R', len, RES_MOD_TIME, RES_ID, RES_PERMS, RES_GROUP, RES_OWNER, RES_CR_TIME, RES_TYPE, ODRIVE.WA.odrive_name_compose(RES_NAME, RES_ID, either(equ(RES_NAME, name),1,0)))));
    name := RES_NAME;
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
  in mode integer := 0) returns varchar
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
  if (pairs is null) {
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
create procedure ODRIVE.WA.odrive_settings (
  inout params any)
{
  return coalesce((select deserialize(blob_to_string(a.USER_SETTINGS))
                     from ODRIVE.WA.SETTINGS a,
                          DB.DBA.SYS_USERS b
                    where b.U_ID = a.USER_ID
                      and b.U_NAME = ODRIVE.WA.session_user(params)), vector());
}
;

-------------------------------------------------------------------------------
--
create procedure ODRIVE.WA.odrive_settings_rows (
  inout params any)
{
  declare settings any;

  settings := ODRIVE.WA.odrive_settings(params);
  return cast(get_keyword('rows', settings, '10') as integer);
}
;

-------------------------------------------------------------------------------
--
create procedure ODRIVE.WA.odrive_settings_atomVersion (
  inout params any)
{
  declare settings any;

  settings := ODRIVE.WA.odrive_settings(params);
  return get_keyword('atomVersion', settings, '0.3');
}
;

-------------------------------------------------------------------------------
--
create procedure ODRIVE.WA.odrive_settings_chars (
  inout params any)
{
  declare settings any;

  settings := ODRIVE.WA.odrive_settings(params);
  return cast(get_keyword('chars', settings, '60') as integer);
}
;

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
create procedure ODRIVE.WA.det_class(
  in path varchar,
  in type varchar := 'C')
{
  declare id any;

  id := ODRIVE.WA.DAV_SEARCH_ID (path);
  if (not ODRIVE.WA.DAV_ERROR(id))
    if (isarray (id))
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
  if (not ODRIVE.WA.DAV_ERROR(id)) {
    if (isarray(id))
      return cast (id[0] as varchar);
    return DB.DBA.DAV_PROP_GET_INT (id, type, ':virtdet', 0);
  }
  return '';
}
;

-------------------------------------------------------------------------------
--
create procedure ODRIVE.WA.det_action_enable(
  in path varchar,
  in action varchar)
{
  declare retValue integer;
  declare det_class, det_category any;

  retValue := either(equ(ODRIVE.WA.odrive_permission (path), 'W'), 1, 0);
  if (retValue) {
    det_class := ODRIVE.WA.det_class (path);
    if (det_class = 'Versioning') {
      if (action = 'createContent') {
        retValue := 0;
      } else if (action = 'edit') {
        retValue := 0;
      } if (action = 'version') {
        retValue := 0;
      }
    } else if (det_class = '') {
      det_category := ODRIVE.WA.det_category(path, 'C');
      if (det_category = 'Versioning') {
        if (action = 'createContent')
          retValue := 0;
      } else if (det_category = 'News3') {
        if (action = 'createContent')
          retValue := 0;
      }
    }
  }
  --dbg_obj_print(path, action, det_class, det_category, ' -> ', retValue);
  return retValue;
}
;

-------------------------------------------------------------------------------
--
create procedure ODRIVE.WA.DAV_GET_INFO(
  in path varchar,
  in info varchar)
{
  declare tmp any;

  if (info = 'vc') {
    if (ODRIVE.WA.DAV_GET_VERSION_CONTROL(path))
      return 'ON';
    return 'OFF';
  }
  if (info = 'avcState') {
    tmp := ODRIVE.WA.DAV_GET_AUTOVERSION(path);
    if (tmp <> '')
      return replace(ODRIVE.WA.auto_version_full(tmp), 'DAV:', '');
    return 'OFF';
  }
  if (info = 'vcState') {
    if (not is_empty_or_null(ODRIVE.WA.DAV_PROP_GET (path, 'DAV:checked-in', '')))
      return 'Check-In';
    if (not is_empty_or_null(ODRIVE.WA.DAV_PROP_GET (path, 'DAV:checked-out', '')))
      return 'Check-Out';
    return 'Standard';
  }
  if (info = 'lockState') {
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
  in vvc varchar,
  in autoVersion varchar,
  in auth_name varchar := NULL,
  in auth_pwd varchar := NULL)
{
  declare retValue any;
  declare permissions, uname, gname varchar;

  ODRIVE.WA.DAV_API_PARAMS (null, null, uname, gname, auth_name, auth_pwd);
  if (autoVersion = '') {
    update WS.WS.SYS_DAV_COL set COL_AUTO_VERSIONING = null where COL_ID = DAV_SEARCH_ID (path, 'C');
    DB.DBA.DAV_PROP_REMOVE(path, 'virt:Versioning-History', auth_name, auth_pwd);
    return 0;
  } else {
    permissions := DB.DBA.DAV_PROP_GET(path, ':virtpermissions', auth_name, auth_pwd);
    uname := DB.DBA.DAV_PROP_GET(path, ':virtowneruid', auth_name, auth_pwd);
    gname := DB.DBA.DAV_PROP_GET(path, ':virtownergid', auth_name, auth_pwd);
    DB.DBA.DAV_COL_CREATE (concat(path, 'VVC/'), permissions, uname, gname, auth_name, auth_pwd);
    DB.DBA.DAV_COL_CREATE (concat(path, 'Attic/'), permissions, uname, gname, auth_name, auth_pwd);
    DB.DBA.DAV_PROP_SET (concat(path, 'VVC/'), 'virt:Versioning-Attic', concat(path, 'Attic/'), auth_name, auth_pwd);
    return DB.DBA.DAV_SET_VERSIONING_CONTROL (path, concat(path, 'VVC/'), autoVersion, auth_name, auth_pwd);
  }
}
;

-------------------------------------------------------------------------------
--
create procedure ODRIVE.WA.DAV_VERSION_CONTROL (
  in path varchar,
  in auth_name varchar := NULL,
  in auth_pwd varchar := NULL)
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
  in auth_name varchar := NULL,
  in auth_pwd varchar := NULL)
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
  in auth_name varchar := NULL,
  in auth_pwd varchar := NULL)
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
  in auth_name varchar := NULL,
  in auth_pwd varchar := NULL)
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
  in auth_name varchar := NULL,
  in auth_pwd varchar := NULL)
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
  in auth_name varchar := NULL,
  in auth_pwd varchar := NULL)
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
  in path varchar)
{
  declare retValue any;

  if (ODRIVE.WA.DAV_ERROR(DB.DBA.DAV_SEARCH_ID (path, 'R')))
    return 0;
  if (ODRIVE.WA.DAV_PROP_GET (path, 'DAV:checked-in', '') <> '')
    return 1;
  if (ODRIVE.WA.DAV_PROP_GET (path, 'DAV:checked-out', '') <> '')
    return 1;
  return 0;
}
;

-------------------------------------------------------------------------------
--
create procedure ODRIVE.WA.path_parent (
  in path value)
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
  in path value)
{
  path := trim(path, '/');
  if (isnull(strrchr(path, '/')))
    return path;
  return right(path, length(path)-strrchr(path, '/')-1);
}
;

-------------------------------------------------------------------------------
--
create procedure ODRIVE.WA.DAV_GET_VERSION_HISTORY_PATH (
  in path varchar)
{
  declare parent, name varchar;

  name := ODRIVE.WA.path_name(path);
  parent := ODRIVE.WA.path_parent(path);

  return concat('/', parent, '/VVC/', name, '/history.xml');
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
  in path varchar)
{
  declare N integer;
  declare c0 varchar;
  declare c1 integer;
  declare versionSet, hrefs any;

  result_names(c0, c1);

  declare exit handler for SQLSTATE '*' {return;};

  versionSet := ODRIVE.WA.DAV_PROP_GET (ODRIVE.WA.DAV_GET_VERSION_HISTORY_PATH(path), 'DAV:version-set');
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
  if (ODRIVE.WA.DAV_ERROR(DB.DBA.DAV_SEARCH_ID (path, 'R'))) {
    retValue := ODRIVE.WA.DAV_SET_VERSIONING_CONTROL(path, null, value);
  } else {
    value := ODRIVE.WA.auto_version_full(value);
    if (value = '') {
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
  in path varchar)
{
  declare resource any;

  resource := ODRIVE.WA.DAV_DIR_LIST(path, -1);
  if (ODRIVE.WA.DAV_ERROR(resource))
    return resource;
  if (length(resource) = 0)
    return -1;
  return resource[0];
}
;

-------------------------------------------------------------------------------
--
create procedure ODRIVE.WA.DAV_INIT_INT ()
{
  declare
    uid, gid integer;
  declare
    user_name varchar;

  user_name := coalesce(ODRIVE.WA.odrive_user(), 'nobody');
  DB.DBA.DAV_OWNER_ID(user_name, null, uid, gid);
  return vector(null, '', 0, null, 0, USER_GET_OPTION(user_name, 'PERMISSIONS'), gid, uid, null, '', null);
}
;

-------------------------------------------------------------------------------
--
create procedure ODRIVE.WA.DAV_INIT_RESOURCE()
{
  declare item any;

  item := ODRIVE.WA.DAV_INIT_INT();
  aset(item, 1, 'R');
  return item;
}
;

-------------------------------------------------------------------------------
--
create procedure ODRIVE.WA.DAV_INIT_COLLECTION()
{
  declare item any;

  item := ODRIVE.WA.DAV_INIT_INT();
  aset(item, 1, 'C');
  aset(item, 9, 'dav/unix-directory');
  return item;
}
;

-------------------------------------------------------------------------------
--
create procedure ODRIVE.WA.DAV_SEARCH_ID(
  in path varchar)
{
  declare id any;

  id := DB.DBA.DAV_SEARCH_ID (path, 'C');
  if (ODRIVE.WA.DAV_ERROR(id))
    return DB.DBA.DAV_SEARCH_ID (path, 'R');
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
    return resource[3];

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
    return resource[8];

  if (property = 'mimeType')
    return coalesce(resource[9], '');

  if (property = 'name')
    return resource[10];

  if (property = 'acl') {
    if (isnull(resource[0]))
      return WS.WS.ACL_CREATE();
    return cast(ODRIVE.WA.DAV_PROP_GET (resource[0], ':virtacl', WS.WS.ACL_CREATE()) as varbinary);
  }

  if ((property = 'detType') and (not isnull(resource[0])))
    return ODRIVE.WA.DAV_PROP_GET (resource[0], ':virtdet');

  if ((property = 'privatetags') and (not isnull(resource[0])))
    return coalesce(ODRIVE.WA.DAV_PROP_GET (resource[0], ':virtprivatetags'), '');

  if ((property = 'publictags') and (not isnull(resource[0])))
    return coalesce(ODRIVE.WA.DAV_PROP_GET (resource[0], ':virtpublictags'), '');

  if (property = 'versionControl') {
    if (isnull(resource[0]))
      return null;
    return ODRIVE.WA.DAV_GET_VERSION_CONTROL (resource[0]);
  }

  if (property = 'autoversion') {
    if (isnull(resource[0]))
      return null;
    return ODRIVE.WA.DAV_GET_AUTOVERSION (resource[0]);
  }

  if (property = 'checked-in') {
    if (isnull(resource[0]))
      return null;
    return ODRIVE.WA.DAV_PROP_GET (resource[0], 'DAV:checked-in', '');
  }

  if (property = 'checked-out') {
    if (isnull(resource[0]))
      return null;
    return ODRIVE.WA.DAV_PROP_GET (resource[0], 'DAV:checked-out', '');
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
  in auth_name varchar := NULL,
  in auth_pwd varchar := NULL)
{
  declare tmp varchar;

  if (property = 'permissions')
    return ODRIVE.WA.DAV_PROP_SET(path, ':virtpermissions', value);
  if (property = 'groupID')
    return ODRIVE.WA.DAV_PROP_SET(path, ':virtownergid', value);
  if (property = 'ownerID')
    return ODRIVE.WA.DAV_PROP_SET(path, ':virtowneruid', value);
  if (property = 'mimeType')
    return ODRIVE.WA.DAV_PROP_SET(path, ':getcontenttype', value);
  if (property = 'name') {
    tmp := concat(left(path, strrchr(rtrim(path, '/'), '/')), '/', value, either(equ(right(path, 1), '/'), '/', ''));
    return ODRIVE.WA.DAV_MOVE(path, tmp, 0, auth_name, auth_pwd);
  }
  if (property = 'detType')
    return DAV_PROP_SET_INT (path, ':virtdet', value, null, null, 0, 0, 0, http_dav_uid ());
  if (property = 'acl')
    return ODRIVE.WA.DAV_PROP_SET(path, ':virtacl', value);
  if (property = 'privatetags')
    return ODRIVE.WA.DAV_PROP_TAGS_SET(path, ':virtprivatetags', value);
  if (property = 'publictags')
    return ODRIVE.WA.DAV_PROP_TAGS_SET(path, ':virtpublictags', value);
  if (property = 'autoversion')
    return ODRIVE.WA.DAV_SET_AUTOVERSION (path, value);
  return 0;
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
    gname := (select U_NAME from WS.WS.SYS_DAV_USER where U_ID = gid);

  if (isnull(auth_name))
    auth_name := ODRIVE.WA.odrive_user();
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
  in auth_name varchar := NULL,
  in auth_pwd varchar := NULL)
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
  inout filter any,
  in auth_name varchar := NULL,
  in auth_pwd varchar := NULL)
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

  search_path := ODRIVE.WA.odrive_real_path(ODRIVE.WA.dav_dc_get(search_params, 'base', 'path', '/DAV/'));
  filter := ODRIVE.WA.dav_dc_filter(search_params);
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

  search_path := ODRIVE.WA.odrive_real_path(ODRIVE.WA.dav_dc_get(search_params, 'base', 'path', '/DAV/'));
  filter := ODRIVE.WA.dav_dc_filter(search_params);
  return ODRIVE.WA.CatFilter_CONFIGURE_INT(path, search_path, filter);
}
;

-------------------------------------------------------------------------------
--
create procedure ODRIVE.WA.CatFilter_CONFIGURE_INT (
  in path varchar,
  in search_path varchar,
  in filter any,
  in auth_name varchar := NULL,
  in auth_pwd varchar := NULL)
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
  in auth_name varchar := NULL,
  in auth_pwd varchar := NULL)
{
  declare uname, gname varchar;
  declare uid, gid integer;

  auth_name := ODRIVE.WA.odrive_user();
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
  in auth_name varchar := NULL,
  in auth_pwd varchar := NULL)
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
  in auth_name varchar := NULL,
  in auth_pwd varchar := NULL)
{
  declare uname, gname varchar;

  ODRIVE.WA.DAV_API_PARAMS (null, null, uname, gname, auth_name, auth_pwd);
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
  in uid integer := NULL,
  in gid integer := NULL,
  in auth_name varchar := NULL,
  in auth_pwd varchar := NULL)
{
  declare uname, gname varchar;

  ODRIVE.WA.DAV_API_PARAMS (uid, gid, uname, gname, auth_name, auth_pwd);
  return DB.DBA.DAV_RES_UPLOAD_STRSES(path, content, type, permissions, uid, gid, auth_name, auth_pwd);
}
;

-------------------------------------------------------------------------------
--
create procedure ODRIVE.WA.DAV_RES_CONTENT (
  in path varchar,
  in auth_name varchar := NULL,
  in auth_pwd varchar := NULL)
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
  in auth_name varchar := NULL,
  in auth_pwd varchar := NULL)
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
  in auth_name varchar := NULL,
  in auth_pwd varchar := NULL)
{
  declare uname, gname varchar;
  declare props any;

  ODRIVE.WA.DAV_API_PARAMS (null, null, uname, gname, auth_name, auth_pwd);
  props := DB.DBA.DAV_PROP_LIST(path, propmask, auth_name, auth_pwd);
  if (isnull(skips))
    return props;

  declare remains any;

  remains := vector();
  foreach(any prop in props) do {
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
  in auth_name varchar := NULL,
  in auth_pwd varchar := NULL)
{
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
  in propname varchar,
  in propvalue any,
  in auth_name varchar := NULL,
  in auth_pwd varchar := NULL)
{
  declare uname, gname varchar;

  ODRIVE.WA.DAV_API_PARAMS (null, null, uname, gname, auth_name, auth_pwd);
  DB.DBA.DAV_PROP_REMOVE(path, propname, auth_name, auth_pwd);
  return DB.DBA.DAV_PROP_SET(path, propname, propvalue, auth_name, auth_pwd);
}
;

-------------------------------------------------------------------------------
--
create procedure ODRIVE.WA.DAV_PROP_TAGS_SET (
  in path varchar,
  in propname varchar,
  in propvalue any,
  in auth_name varchar := NULL,
  in auth_pwd varchar := NULL)
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
  in single_schema varchar,		-- Name of single RDF schema to filter out redundand records or NULL to compose any number of properties.
  in auth_name varchar := NULL,
  in auth_pwd varchar := NULL)
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
  in single_schema varchar,		-- Name of single RDF schema to filter out redundand records or NULL to compose any number of properties.
  in rdf any,				          -- RDF XML
  in auth_name varchar := NULL,
  in auth_pwd varchar := NULL)
{
  declare uname, gname varchar;

  ODRIVE.WA.DAV_API_PARAMS (null, null, uname, gname, auth_name, auth_pwd);
  DB.DBA.DAV_PROP_REMOVE(path, single_schema, auth_name, auth_pwd);
  return DB.DBA.DAV_RDF_PROP_SET(path, single_schema, rdf, auth_name, auth_pwd);
}
;

-------------------------------------------------------------------------------
--
create procedure ODRIVE.WA.DAV_PROP_REMOVE (
  in path varchar,
  in propname varchar,
  in auth_name varchar := NULL,
  in auth_pwd varchar := NULL)
{
  declare uname, gname varchar;

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
  in auth_name varchar := NULL,
  in auth_pwd varchar := NULL)
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
  in auth_name varchar := NULL,
  in auth_pwd varchar := NULL)
{
  declare id integer;
  declare locks, retValue any;
  declare uname, gname varchar;

  ODRIVE.WA.DAV_API_PARAMS (null, null, uname, gname, auth_name, auth_pwd);
  id := DB.DBA.DAV_SEARCH_ID(path, type);
  locks := DB.DBA.DAV_LIST_LOCKS_INT (id, type);
  foreach (any lock in locks) do {
    retValue := DB.DBA.DAV_UNLOCK (path, lock[2], auth_name, auth_pwd);
    if (ODRIVE.WA.DAV_ERROR (retValue))
      return retValue;
  }
  return 1;
}
;

-----------------------------------------------------------------------------------------
--
create procedure ODRIVE.WA.test_clear (
  in S any)
{
  declare N integer;

  return substring(S, 1, coalesce(strstr(S, '<>'), length(S)));
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

  value := ODRIVE.WA.validate2 (valueClass, value);

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
    if (isnull(regexp_match('^(ht|f)tp(s?)\:\/\/[0-9a-zA-Z]([-.\w]*[0-9a-zA-Z])*(:(0-9)*)*(\/?)([a-zA-Z0-9\-\.\?\,\'\/\\\+&amp;%\$#_]*)?\$', propertyValue)))
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
create procedure ODRIVE.WA.version_update()
{
  declare home, source, target varchar;

  for (select WAI_ID, WAM_USER
         from DB.DBA.WA_MEMBER join DB.DBA.WA_INSTANCE on WAI_NAME = WAM_INST
        where WAI_TYPE_NAME = 'oDrive' and WAM_MEMBER_TYPE = 1) do {
    home := ODRIVE.WA.odrive_dav_home(ODRIVE.WA.odrive_user_name(WAM_USER));
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
