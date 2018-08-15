--  
--  $Id$
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--  
--  Copyright (C) 1998-2018 OpenLink Software
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

USE DB;

create function WA_SEARCH_WIKI_GET_EXCERPT_HTML (in _current_user_id integer, in _RES_ID integer,
	in words any, in _RES_CONTENT varchar, in _RES_FULL_PATH varchar, in _RES_OWNER integer) returns varchar
{
  declare _COL_PATH, _WIKI_PATH, _WIKI_INSTANCE_PATH varchar;
  declare _COL_PATH_ARRAY varchar;
  declare _TitleText nvarchar;
  declare _ClusterName, _LocalName varchar;
  declare res varchar;
  declare _WAUI_FULL_NAME varchar;
  declare _U_NAME, home_path varchar;
  declare _content, _ClusterId any;

  _COL_PATH := DB.DBA.DAV_CONCAT_PATH (WS.WS.PARENT_PATH (WS.WS.HREF_TO_PATH_ARRAY (_RES_FULL_PATH)), null);

  _TitleText := null; _ClusterName := null; _LocalName := null;
  select coalesce (TitleText, cast (LocalName as nvarchar)), ClusterName, LocalName, C.ClusterId
    into _TitleText, _ClusterName, _LocalName, _ClusterId
    from WV.WIKI.TOPIC T, WV.WIKI.CLUSTERS C
    where
      T.ClusterId = C.ClusterId
      and ResId = _RES_ID;

  _WAUI_FULL_NAME := null;
  select WAUI_FULL_NAME
    into _WAUI_FULL_NAME
    from DB.DBA.WA_USER_INFO where WAUI_U_ID = _RES_OWNER;

  _U_NAME := null;
  select U_NAME into _U_NAME from DB.DBA.SYS_USERS where U_ID = _RES_OWNER;

  home_path := WV.WIKI.CLUSTERPARAM (_ClusterId, 'home', '/wiki/main');

  _WIKI_PATH := sprintf ('%s/%s/%s', home_path, _ClusterName, _LocalName);
  _WIKI_INSTANCE_PATH := sprintf ('%s/%s', home_path, _ClusterName);
  res := sprintf ('<span><img src="%s" />Wiki <a href="%s">%s</a> <a href="%s">%s</a> <a href="%s">%s</a>',
           WA_SEARCH_ADD_APATH ('images/icons/wiki_16.png'),
	   WA_SEARCH_ADD_APATH (WA_SEARCH_ADD_SID_IF_AVAILABLE (coalesce (_WIKI_PATH, '#'), _current_user_id)),
		coalesce (_TitleText, N'#No Title#'),
	   WA_SEARCH_ADD_APATH (WA_SEARCH_ADD_SID_IF_AVAILABLE (coalesce (_WIKI_INSTANCE_PATH, '#'), _current_user_id)),
		coalesce (_ClusterName, '#No Title#'),
           WA_SEARCH_ADD_APATH (
             WA_SEARCH_ADD_SID_IF_AVAILABLE ( sprintf ('uhome.vspx?ufname=%U', _U_NAME), _current_user_id, '&')),
           coalesce (_WAUI_FULL_NAME, '#No Name#'));

  _content := WV.WIKI.DELETE_SYSINFO_FOR (coalesce (_RES_CONTENT, ''));
  if (not isblob (_content))
    _content := cast (_content as varchar);
  _content := subseq (_content, 0, 200000);
  res := res || '<br />' || left (search_excerpt (words, _content), 900) || '</span>';

  return res;
}
;

