--
--  $Id$
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2016 OpenLink Software
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

registry_set ('WikiV %BR%',	'<BR />')
;
registry_set ('WikiV %YELLOW%',	'<FONT COLOR="#ffff00">')
;
registry_set ('WikiV %ORANGE%',	'<FONT COLOR="#ff6600">')
;
registry_set ('WikiV %RED%',	'<FONT COLOR="#ff0000">')
;
registry_set ('WikiV %PINK%',	'<FONT COLOR="#ff00ff">')
;
registry_set ('WikiV %PURPLE%',	'<FONT COLOR="#800080">')
;
registry_set ('WikiV %TEAL%',	'<FONT COLOR="#008080">')
;
registry_set ('WikiV %NAVY%',	'<FONT COLOR="#000080">')
;
registry_set ('WikiV %BLUE%',	'<FONT COLOR="#0000ff">')
;
registry_set ('WikiV %AQUA%',	'<FONT COLOR="#00ffff">')
;
registry_set ('WikiV %LIME%',	'<FONT COLOR="#00ff00">')
;
registry_set ('WikiV %GREEN%',	'<FONT COLOR="#008000">')
;
registry_set ('WikiV %OLIVE%',	'<FONT COLOR="#808000">')
;
registry_set ('WikiV %MAROON%',	'<FONT COLOR="#800000">')
;
registry_set ('WikiV %BLACK%',	'<FONT COLOR="#000000">')
;
registry_set ('WikiV %GRAY%',	'<FONT COLOR="#808080">')
;
registry_set ('WikiV %SILVER%',	'<FONT COLOR="#c0c0c0">')
;
registry_set ('WikiV %WHITE%',	'<FONT COLOR="#ffffff">')
;
registry_set ('WikiV %ENDCOLOR%',	'</FONT>')
;

registry_set ('WikiV %H%',	'<IMG SRC="%TEXTICONS%/help.gif" border="0" alt=HELP width="16" height="16" />')
;
registry_set ('WikiV %I%',	'<IMG SRC="%TEXTICONS%/tip.gif" border="0" alt="IDEA!" width="16" height="16" />')
;
registry_set ('WikiV %M%',	'<IMG SRC="%TEXTICONS%/arrowright.gif" border="0" alt="MOVED TO..." width="16" height="16" />')
;
registry_set ('WikiV %N%',	'<IMG SRC="%TEXTICONS%/new.gif" border="0" alt=NEW width="28" height="8" />')
;
registry_set ('WikiV %P%',	'<IMG SRC="%TEXTICONS%/pencil.gif" border="0" alt=REFACTOR width="16" height="16" />')
;
registry_set ('WikiV %Q%',	'<IMG SRC="%TEXTICONS%/help.gif" border="0" alt="QUESTION?" width="16" height="16" />')
;
registry_set ('WikiV %S%',	'<IMG SRC="%TEXTICONS%/starred.gif" border="0" alt=PICK width="16" height="16" />')
;
registry_set ('WikiV %T%',	'<IMG SRC="%TEXTICONS%/tip.gif" border="0" alt=TIP width="16" height="16" />')
;
registry_set ('WikiV %U%',	'<IMG SRC="%TEXTICONS%/updated.gif" border="0" alt=UPDATED width="56" height="8" />')
;
registry_set ('WikiV %X%',	'<IMG SRC="%TEXTICONS%/warning.gif" border="0" alt="ALERT!" width="16" height="16" />')
;
registry_set ('WikiV %Y%',	'<IMG SRC="%TEXTICONS%/choice-yes.gif" border="0" alt=DONE width="16" height="16" />')
;

registry_set ('WikiV %HOMETOPIC%',		'WelcomeVisitors')
;
registry_set ('WikiV %NOTIFYTOPIC%',		'RecentChanges')
;
registry_set ('WikiV %WIKIUSERSTOPIC%',		'WikiCommunity')
;
registry_set ('WikiV %STATISTICSTOPIC%',	'WikiStatistics')
;
registry_set ('WikiV %MAILTHISTOPIC%',		'<A HREF="mailto:?subject=%BASETOPIC%&body=%TOPICURL%">%MAILTHISTOPICTEXT%</A>')
;
registry_set ('WikiV %MAILTHISTOPICTEXT%',	'Send a link to this page')
;
registry_set ('WikiV %MAINCLUSTER%',		'Main')
;
registry_set ('WikiV %WIKICLUSTER%',		'Doc')
;
registry_set ('WikiV %MAINWEB%',		'%MAINCLUSTER%')
;
registry_set ('WikiV %WIKIWEB%',		'%WIKICLUSTER%')
;
registry_set ('WikiV %TWIKIWEB%',		'%WIKICLUSTER%')
;
registry_set ('WikiV %PUBURL%',			'.')
;
registry_set ('WikiV %PUBURLPATH%',		'')
;
registry_set ('WikiV %ATTACHURLPATH%',		'%TOPIC%')
;
registry_set ('WikiV %WIKITOOLNAME%',		'WikiV')
;
registry_set ('WikiV %WIKIVERSION%',		'0.3')
;
registry_set ('WikiV %WIKIUSERNAME%',		'%MAINWEB%.%WIKINAME%')
;

registry_set ('WikiV %TEXTICONS%',		'%PUBURL%/%WIKICLUSTER%/TextIcons')
;
registry_set ('WikiV %WIKIWEBMASTER%',		'you@yourdomain.com')
;
registry_set ('WikiV %WEBCOPYRIGHT%',		'&copy; contributing authors.')
;
registry_set ('WikiV %CATEGORY%', 'Category')
;
create function WV.WIKI.MACRO_MAIN_ABSTRACT (inout _data varchar, inout _context any, inout _env any)
{
  return _data;
}
;

create function WV.WIKI.MACRO_MAIN_TABLEOFCLUSTERS (inout _data varchar, inout _context any, inout _env any)
{
  declare _report, _ent any;
  declare _uid int;
  _uid := cast (get_keyword ('uid', _env, '0') as integer);
  _report := XMLELEMENT ("MACRO_MAIN_TABLEOFCLUSTERS");
  _ent := xpath_eval ('//MACRO_MAIN_TABLEOFCLUSTERS', _report);
  for select WAI_NAME, WAI_INST from DB.DBA.WA_INSTANCE 
	where WAI_TYPE_NAME='oWiki' and WAI_IS_PUBLIC=1
  do {
     XMLAppendChildren (_ent, XMLELEMENT ('Cluster',
	 XMLATTRIBUTES (WAI_NAME as "CLUSTERNAME", 
	                coalesce (
           (select Abstract from WV.WIKI.TOPIC 
              where ClusterId = (WAI_INST as wa_wikiv).cluster_id 
              and LocalName = WV.WIKI.CLUSTERPARAM (WAI_NAME, 'index-page', 'WelcomeVisitors')), N'') as "ABSTRACT")));
  }
  return _report;
}
;

create function WV.WIKI.MACRO_MAIN_TABLEOFUSERS (inout _data varchar, inout _context any, inout _env any)
{
  declare _report any;
  _report := coalesce ((
      select XMLELEMENT ("MACRO_MAIN_TABLEOFUSERS",
        XMLAGG ( 
          XMLELEMENT ('User',
	    XMLATTRIBUTES (u.UserName) ) ) )
      from WV.WIKI.USERS as u ) );
  return _report;
}
;

create function WV.WIKI.META_TOPICMOVED (inout _data varchar, inout _context any, inout _env any)
{
  return '';
}
;

create function WV.WIKI.MACRO_META_FILEATTACHMENT (inout _data varchar, inout _context any, inout _env any)
{
  -- return XMLELEMENT('XMP', xtree_doc(concat ('<data ', _data, ' />')));
  return '';
}
;

create function WV.WIKI.MACRO_TOPIC (inout _data varchar, inout _context any, inout _env any)
{
  return get_keyword ('ti_local_name', _env, 'current');
}
;

create function WV.WIKI.MACRO_WEB (inout _data varchar, inout _context any, inout _env any)
{
  return get_keyword ('ti_cluster_name', _env, 'current');
}
;

create function WV.WIKI.MACRO_WIKIUSERNAME (inout _data varchar, inout _context any, inout _env any)
{
  declare _uid integer;
  _uid := cast (get_keyword ('uid', _env, '0') as integer);
  return coalesce ((select UserName from WV.WIKI.USERS where UserId = _uid), 'visitor');
  return _env;
}
;

create function WV.WIKI.MACRO_INCLUDE (inout _data varchar, inout _context any, inout _env any)
{
  --dbg_obj_princ ('WV.WIKI.MACRO_INCLUDE ', _data);
--  declare exit handler for  not found {
--    return '';
--  };
  declare _args any;
  _args := WV.WIKI.PARSEMACROARGS (_data);
  declare _topic_name varchar;
  _topic_name := WV.WIKI.GETMACROPARAM (_args, 'param', NULL);
  if (_topic_name is null)
    _topic_name := _data;
  _topic_name := WV.WIKI.EXPAND_SIMPLE_MACRO (trim(_topic_name));
  --dbg_obj_print (_topic_name, _data);
  declare _topic WV.WIKI.TOPICINFO;
  _topic := WV.WIKI.TOPICINFO ();
  _topic.ti_raw_title := _topic_name;
  _topic.ti_find_id_by_raw_title ();  
  if (_topic.ti_id = 0)
    return '';
  --dbg_obj_print (_topic);
  _topic.ti_find_metadata_by_id ();
  --dbg_obj_print ('3');
  declare exit handler for sqlstate '*' {
  --dbg_obj_print ('4');
    return NULL;
  }
  ;
  return (XMLELEMENT ('MACRO_INCLUDE',
   xpath_eval ('//div[@class=\'topic-text\']',
    WV.WIKI.VSPXSLT ( 'VspTopicView.xslt', _topic.ti_get_entity (null,1), 
	vector_concat (_env, _topic.ti_xslt_vector())))));
}
;

create function WV.WIKI.MACRO_CHANGELOG (inout _data varchar, inout _context any, inout _env any)
{
  declare _ent, params, _args any;
  declare _skip, _rows int;
  params := null;
  _args := WV.WIKI.PARSEMACROARGS (_data);
  --dbg_obj_print (_args);
  _skip := atoi (WV.WIKI.GETMACROPARAM (_args, 'skip', '0'));
  _rows := atoi (WV.WIKI.GETMACROPARAM (_args, 'rows', '20'));
  --dbg_obj_print (_skip, ' ', _rows);
  if (WV.WIKI.GETMACROPARAM (_args, 'local', '0') = '1')
    _ent := WV.WIKI.CHANGELOG(_skip, _rows, get_keyword ('ti_cluster_name', _env, ''));
  else
    _ent := WV.WIKI.CHANGELOG(_skip, _rows);
  return WV.WIKI.VSPXSLT ('VspChangeLog.xslt', 
				_ent,
				params);
}
;


-- categories macros

create function WV.WIKI.MACRO_CATEGORIES (inout _data varchar, inout _context any, inout _env any)
{
  declare _cl_id int;
  _cl_id := cast (get_keyword ('ti_cluster_id', _env, 'current') as int);
  declare _user varchar;
  _user := WV.WIKI.CLUSTERPARAM (_cl_id , 'delicious_user', '');
    
  return (select XMLELEMENT ("MACRO_CATEGORIES",
     XMLELEMENT("table",
       XMLAGG(XMLELEMENT("tr",
               XMLELEMENT("td",	
		WV.WIKI.A(c.ClusterName || '.' || t.LocalName, c.ClusterName || '.' || t.LocalName, 'wikiword'))))))
	from WV.WIKI.TOPIC t inner join WV.WIKI.CLUSTERS c on (c.ClusterId = t.ClusterId) 
	  where c.ClusterId = _cl_id and LocalName like 'Category%'
	  order by LocalName);
}
;

create function WV.WIKI.DELICIOUSMAKECONT (in _doc any, in _params any)
{
  return '';
}
;
  

create function WV.WIKI.MACRO_DELICIOUSCATEGORIES (inout _data varchar, inout _context any, inout _env any)
{
  return '';
}
;

-- dash board
create function WV.WIKI.MACRO_MAIN_DASHBOARD (inout _data varchar, inout _context any, inout _env any)
{
  declare _report, _ent any;
  _report := XMLELEMENT ('MACRO_MAIN_DASHBOARD');
  _ent := xpath_eval ('//MACRO_MAIN_DASHBOARD', _report); 


  declare _clusterid int;
  _clusterid := cast (get_keyword ('ti_cluster_id', _env, '0') as int);
  if (WV.WIKI.CLUSTERPARAM(_clusterid, 'qwiki', 2) = 1)
    {
      for select WAI_INST, WAI_NAME, WAI_DESCRIPTION from WA_INSTANCE, WV.WIKI.CLUSTERS
        where WAI_TYPE_NAME = 'oWiki' 
	 and WAI_NAME = CLUSTERNAME
	 and CLUSTERID = _clusterid
      do {
        XMLAppendChildren (_ent, XMLELEMENT ('Cluster',
                      XMLATTRIBUTES (WAI_NAME as "KEY"),
                      XMLELEMENT (Name, WAI_NAME),
                      XMLELEMENT ('Description', WAI_DESCRIPTION ) ) );
        return _report;
      }
    }  
  for select WAI_INST, WAI_NAME, WAI_DESCRIPTION from WA_INSTANCE where WAI_TYPE_NAME = 'oWiki'
  do
    {
      XMLAppendChildren (_ent, XMLELEMENT ('Cluster',
                      XMLATTRIBUTES (WAI_NAME as "KEY"),
                      XMLELEMENT (Name, WAI_NAME),
                      XMLELEMENT ('Description', WAI_DESCRIPTION ) ) );
    }
  return _report;
}
;

create function WV.WIKI.MACRO_CLUSTER_NAME (inout _data varchar, inout _context any, inout _env any)
{
  declare _cl_id int;
  _cl_id := cast (get_keyword ('ti_cluster_id', _env, 'current') as int);
  return coalesce ((select WAI_NAME from (select WAI_NAME, WAI_INST from WA_INSTANCE where WAI_TYPE_NAME = 'oWiki') a where (a.WAI_INST as wa_wikiv).cluster_id = _cl_id),
		   'default main area');
}
;

create function WV.WIKI.MACRO_CLUSTER_DESCRIPTION (inout _data varchar, inout _context any, inout _env any)
{
  declare _cl_id int;
  _cl_id := cast (get_keyword ('ti_cluster_id', _env, 'current') as int);
  return coalesce ((select WAI_DESCRIPTION from (select WAI_DESCRIPTION, WAI_INST from WA_INSTANCE where WAI_TYPE_NAME = 'oWiki') a where (a.WAI_INST as wa_wikiv).cluster_id = _cl_id),
		   'default main area');
}
;

create function WV.WIKI.MACRO_CLUSTER_OWNER (inout _data varchar, inout _context any, inout _env any)
{
  declare _col_id int;
  _col_id := cast (get_keyword ('ti_col_id', _env, 'current') as int);
  return (select concat (U_NAME, ' (', UserName, ')') from WS.WS.SYS_DAV_COL, WV.WIKI.USERS, DB.DBA.SYS_USERS
	  where COL_ID = _col_id
	  and COL_OWNER = U_ID
	  and COL_OWNER = UserId);
}
;

create function WV.WIKI.MACRO_CLUSTER_MEMBERS (inout _data varchar, inout _context any, inout _env any)
{
  declare _cl_id int;
  declare _inst_name varchar;
  _cl_id := cast (get_keyword ('ti_cluster_id', _env, 'current') as int);
  _inst_name := (select WAI_NAME  from (select WAI_NAME, WAI_INST from WA_INSTANCE where WAI_TYPE_NAME = 'oWiki') a where (a.WAI_INST as wa_wikiv).cluster_id = _cl_id);
  return (
      select XMLELEMENT ("MACRO_CLUSTER_MEMBERS",
	 XMLAGG(			
            XMLELEMENT ("div",
			U_NAME)))
      from  WA_MEMBER, DB.DBA.SYS_USERS
        where WAM_INST = _inst_name
      and U_ID = WAM_USER);
}
;

create function WV.WIKI.MACRO_RSS_FEED (inout _data varchar, inout _context any, inout _env any)
{
  return WV.WIKI.MACRO_FEED_RSS (_data, _context, _env);
}
;

create function WV.WIKI.MACRO_ATOM_FEED (inout _data varchar, inout _context any, inout _env any)
{
  return WV.WIKI.MACRO_FEED_ATOM (_data, _context, _env);
}
;


create function WV.WIKI.MACRO_FEED_RSS (inout _data varchar, inout _context any, inout _env any)
{
  return WV.WIKI.FEED (_env, _data, 'rss20', 'rss-icon-16.gif');
}
;

create function WV.WIKI.MACRO_FEED_ATOM (inout _data varchar, inout _context any, inout _env any)
{
  return WV.WIKI.FEED (_env, _data, 'atom', 'atom-icon-16.gif');
}
;


create function WV.WIKI.FEED (inout _env any, inout _data varchar, in _type varchar, in _icon varchar)
{
  declare cluster_name varchar;
  declare _home varchar;
  cluster_name := get_keyword ('ti_cluster_name', _env, 'current');
  declare _content, _search_area varchar;
  declare _args varchar;
  _args := WV.WIKI.PARSEMACROARGS (_data);
  _content := WV.WIKI.GETMACROPARAM (_args, 'content', _type || ' feed');
  _search_area := WV.WIKI.GETMACROPARAM (_args, 'area', 'cluster');

  declare _base_adjust varchar;
  _base_adjust := coalesce (connection_get ('WIKIV BaseAdjust'), '');
  _home :=  WV.WIKI.RESOURCEHREF ('',  _base_adjust);

  return XMLELEMENT ('div',
		     XMLATTRIBUTES ('MACRO_' || ucase (_type) || '_FEED_LINK' as "class"),
		     XMLELEMENT ('img',
			 	 XMLATTRIBUTES (_home || 'images/' || _icon as "src")),
		     XMLELEMENT ('a', 
				 XMLATTRIBUTES (_home || 'gems.vsp?type=' || _type || 
					case when _search_area = 'cluster' then '&cluster=' || cluster_name
					     else '' end
 				        as "href"),
				 _content));
}
;

create function WV.WIKI.MACRO_HIT_COUNTER (inout _data varchar, inout _context any, inout _env any)
{
  declare _topic_id int;
  _topic_id := cast (get_keyword ('ti_id', _env, -1) as int);
  return XMLELEMENT ('MACRO_HIT_COUNTER', 
    coalesce ( (select Cnt from WV.WIKI.HITCOUNTER where TopicId = _topic_id), 0 ));
}
;

create trigger "HitCounter_Delete" after delete on WV.WIKI.TOPIC referencing old as O
{
  delete from WV.WIKI.HITCOUNTER where TopicId = O.TopicId;
}
;

create function WV.WIKI.STRJOIN (in _del varchar,
  in _words any)
{
  declare idx int;
  declare ss any;
  if (length (_words) = 0)
    return '';
  ss := string_output();
  for (idx :=0; idx < (length (_words) - 1); idx:=idx+1)
    {
      http (cast (_words[idx] as varchar), ss);
      http (cast (_del as varchar), ss);
    }
  http (cast (_words[idx] as varchar), ss);
  return string_output_string (ss);
}
;

create function WV.WIKI.ZIP (in _v1 any, in _v2 any)
{
  declare res any;
  vectorbld_init(res);
  declare i int;
  declare len int;
  if (isarray(_v1) and (not isstring (_v1)))
    {
      len := case when length (_v1) < length(_v2) then length (_v1) else length (_v2) end;
      for (i:=0; i < len; i:=i+1)
        vectorbld_acc (res, vector (_v1[i], _v2[i]));
    }
  else
    {
      len := length (_v2);
      for (i:=0;i < len; i:=i+1)
        vectorbld_acc (res, vector (_v1, _v2[i]));
    }	
  vectorbld_final (res);
  return res;
}
;

create function WV.WIKI.FLATTEN (in _v any)
{
  if (not isarray (_v))
    return _v;
  declare _res any;
  _res := vector();
  foreach (any item in _v) do 
    {
      if (isarray (item) and (not isstring (item)))
        _res := vector_concat (_res, WV.WIKI.FLATTEN (item));
      else
        _res := vector_concat (_res, vector (item));
    }
  return _res;
}
;

create function WV.WIKI.MAP (in funcname varchar, in v any, in result_type varchar:='vector')
{
  if (not isarray (v))
    signal ('WV700', 'WV.WIKI.MAP needs vector as first argument');
  if (not __proc_exists (funcname))
    signal ('WV701', 'WV.WIKI.MAP needs name of existing procedure as second argument');
  declare res any;
  if (result_type = 'vector')
  vectorbld_init(res);
  declare idx int;
  for (idx:=0; idx < length (v); idx:=idx+1)
    {
      if (result_type = 'vector')
	vectorbld_acc (res, call (funcname)(v[idx]));
      else
	call (funcname) (v[idx]);
    }
  vectorbld_final(res);
  return res;
}
;
  
      
create function WV.WIKI.DROP_PARAM(in params any, in drop_param varchar)
{
  declare _res any;
  vectorbld_init(_res);
  declare idx int;
  for (idx := 0; idx < length(params); idx:=idx+2)
    {
      if (drop_param <> params[idx])
 	{
	  vectorbld_acc (_res, params[idx]);
	  vectorbld_acc (_res, params[idx+1]);
	}
    }
  vectorbld_final(_res);
  return _res;
}
;

create function WV.WIKI.BUILD_PARAMS (in params any)
{
  declare _res any;
  vectorbld_init(_res);
  declare idx int;
  for (idx := 0; idx < length(params); idx:=idx+2)
    {
      if (isstring(params[idx+1]))
	vectorbld_acc (_res, params[idx] || '=' || sprintf ('%U',params[idx+1]));
    }

  vectorbld_final(_res);
  return WV.WIKI.STRJOIN ('&', _res);
}
;  


create function WV.WIKI.MACRO_SEARCH (inout _data varchar, inout _context any, inout _env any)
{
  declare _cluster, search_word varchar;
  declare _res varchar; 
  declare _args any;
  declare _cluster_col_id int;
  declare sid, realm, searchPath varchar;


  _data := WV.WIKI.EXPAND_SIMPLE_MACRO (_data);
  _args := WV.WIKI.PARSEMACROARGS (_data);
  search_word := WV.WIKI.GETMACROPARAM (_args, 'search', NULL);
  if (search_word is null)
    {
      search_word := WV.WIKI.GETMACROPARAM (_args, 'param', NULL);
      if (search_word is not null)
        {
	  declare swords any;
	  swords := split_and_decode (search_word, 0, '\0\0;');
	  search_word := WV.WIKI.STRJOIN (' OR ', swords);
	}
    }
  sid := get_keyword ('sid', _env);
  realm := get_keyword ('realm', _env);
  _cluster := WV.WIKI.GETMACROPARAM (_args, 'cluster');

  searchPath := WS.WS.COL_PATH (cast (get_keyword ('ti_col_id', _env, 0) as integer));
  if (_cluster is not null)
    {
      _cluster_col_id := (select ColId from WV.WIKI.CLUSTERS where ClusterId = _cluster);
      if (_cluster_col_id IS NULL)
        _cluster := NULL;
    }
  if (search_word <> '')
    {
      declare exp1,exp varchar;
      declare hit_words, vt, war any;
      declare n,m int;

      exp1 := trim (search_word);
      exp := exp1;
      hit_words := vector();
      vt := vt_batch ();
      vt_batch_feed (vt, exp, 0, 0, 'x-ViDoc');
      war := vt_batch_strings_array (vt);
      m := length (war);
    for (n := 0; n < m; n := n + 2)
        {
	  if (war[n] <> 'AND' and war[n] <> 'NOT' and war[n] <> 'NEAR' and war[n] <> 'OR' and length (war[n]) > 1 and not vt_is_noise (war[n], 'utf-8', 'x-ViDoc'))
        hit_words := vector_concat (hit_words, vector (war[n]));
	}
end_parse:
      declare site_cr cursor for select RES_ID, U_NAME, RES_NAME, length (RES_CONTENT) as RES_LEN, WV.WIKI.DATEFORMAT(RES_CR_TIME) as RES_CR_TIME_STR,RES_PERMS, RES_FULL_PATH
                            from WS.WS.SYS_DAV_RES, DB.DBA.SYS_USERS
                                where contains (RES_CONTENT, concat ('[__lang ''x-ViDoc''] ',exp1))
                             and RES_FULL_PATH like searchPath || '%.txt'
			     and U_ID = RES_OWNER;
      declare cluster_cr cursor for select RES_ID, U_NAME, RES_NAME, length (RES_CONTENT) as RES_LEN, WV.WIKI.DATEFORMAT(RES_CR_TIME) as RES_CR_TIME_STR,RES_PERMS, RES_FULL_PATH
                            from WS.WS.SYS_DAV_RES, DB.DBA.SYS_USERS
                                   where contains (RES_CONTENT, concat ('[__lang ''x-ViDoc''] ',exp1))
                             and RES_FULL_PATH like searchPath || '%.txt'
			     and U_ID = RES_OWNER
			     and RES_COL = _cluster_col_id;

whenever sqlstate '37000' goto failed;
	declare _ctx, _idx any;
	_ctx := string_output ();
	_idx := 0;
	declare _res_id, _u_name, _res_name, _res_len, _cr_time, _perms, _full_path any;
	declare _cluster_search int;
        _cluster_search := case when _cluster is not null then 1 else 0 end;
	if (_cluster_search = 1)
	  open cluster_cr;
	else
	  open site_cr;
	whenever not found goto endf;
	http ('<div><![CDATA[Search result for "' || exp1 || '":]]></div> <table class="wikitable"><tr>
			<th align="left" width="20%">Name</th>
			<th align="left" width="10%">Size</th>
			<th align="left" width="10%">Owner</th>
			<th align="left" width="10%">Date</th></tr>', _ctx);
    while (1) {
	  if (_cluster_search = 1)
		fetch cluster_cr into _res_id, _u_name, _res_name, _res_len, _cr_time, _perms, _full_path;
	  else
		fetch site_cr into _res_id, _u_name, _res_name, _res_len, _cr_time, _perms, _full_path;
	  _idx := _idx + 1;
	  http ('<tr>
			<td align="left" width="20%">' || WV.WIKI.MAKEHREFFROMRES (_res_id, _res_name, sid, realm) || '</td>
			<td align="left" width="10%">' || WV.WIKI.PRINTLENGTH(_res_len) || '</td>
			<td align="left" width="10%">' || _u_name || '</td>
			<td align="left" width="10%">' || _cr_time || '</td></tr>', _ctx);
	  http ('<tr><td colspan="4">', _ctx);
	  http (coalesce (search_excerpt (hit_words,  blob_to_string ( (select RES_CONTENT from WS.WS.SYS_DAV_RES where RES_ID = _res_id ) ), 200000, 90, 200, 'b', 1), ''), _ctx);
	  http ('</td></tr>', _ctx);

	}
endf:
	if (_cluster_search = 1)
	  close cluster_cr;
	else
	  close site_cr;
	http ('</table>', _ctx);
   	if (_idx = 0) {
	failed:
		_res := '<div class="error"><![CDATA[No articles found for "' || exp1 || '"]]></div>';
	}
	if (_idx <> 0)
		_res :=  string_output_string (_ctx);
   }
   return XMLELEMENT ('MACRO_SEARCH', xtree_doc (_res));
}
;


create function WV.WIKI.MACRO_TOC  (inout _data varchar, inout _context any, inout _env any)
{
  declare _xml_doc any;
  declare _cluster_name, _lexer, _lexer_name varchar;
  _cluster_name := get_keyword ('ti_cluster_name', _env, 'Main');
  WV..LEXER (get_keyword ('ti_cluster_name', _env, 'Main'), _lexer, _lexer_name);
  _xml_doc :=  xtree_doc(call (_lexer) (get_keyword ('ti_text', _env, '') || '\r\n', 
	_cluster_name,
	get_keyword ('ti_local_name', _env, WV.WIKI.CLUSTERPARAM (_cluster_name, 'index-page', 'WelcomeVisitors')),
	get_keyword ('ti_curuser_wikiname', _env, 'WikiGuest'),
	null), 2);

	
  declare _html, _txt varchar;
  declare hayches any;
  declare _out varchar; _out := '';
  declare n, p int;
  declare i, j integer; i := 0;
  declare _num_h1 integer;
  
  _num_h1 := length(xpath_eval('//h1', _xml_doc, 0, vector('baseadjust', connection_get ('WIKIV BaseAdjust'))));
  if (_num_h1 = 1) {
   	hayches := xpath_eval('//h2 | //h3 | //h4 | //h5 ', 
    	_xml_doc, 0, 
  		vector('baseadjust', connection_get ('WIKIV BaseAdjust'))); --dbg_obj_print(hayches);
  } else {
    hayches := xpath_eval('//h1 | //h2 | //h3 | //h4 ', 
  		_xml_doc, 0, 
  		vector('baseadjust', connection_get ('WIKIV BaseAdjust'))); --dbg_obj_print(hayches);
  }
  
  while (i < length(hayches)) {
  	_txt := WV.WIKI.TRIM(cast(xpath_eval('text()', hayches[i], 1) as varchar));
  	if (i = 0) {
  		_out := _out || sprintf('<li><a href="#%V">%V</a></li>\n', _txt, _txt);
	} else {
 		n := cast (subseq (cast(xpath_eval('local-name()', hayches[i], 1) as varchar), 1) as int);
 		p := cast (subseq (cast(xpath_eval('local-name()', hayches[i - 1], 1) as varchar), 1) as int);
 		--dbg_obj_print(hayches[i], n, p);
  		if (n = p) {
  			_out := _out || sprintf('<li><a href="#%V">%V</a></li>\n', _txt, _txt);
		} 
  		if (n > p) {
  			_out := _out || repeat('\n<ul>', n - p);
  			_out := _out || sprintf('<li><a href="#%V">%V</a></li>\n', _txt, _txt);
		} 
  		if (n < p) {
  			_out := _out || repeat('</ul>\n\n', p - n);
  			_out := _out || sprintf('<li><a href="#%V">%V</a></li>\n', _txt, _txt);
		} 
	}
  	i := i + 1;
  } 
  if (length(hayches) > 0) {                                                                                                                                                                                                                                           
  n := cast (subseq (cast(xpath_eval('local-name()', hayches[0], 1) as varchar), 1) as int);
  p := cast (subseq (cast(xpath_eval('local-name()', hayches[i-1], 1) as varchar), 1) as int);
  _out := _out || repeat('</ul>\n', p - n);
  }                                                                                                                                                                                                                                                                    
  return '
<div class="MACRO_TOC" xmlns:wv="http://www.openlinksw.com/Virtuoso/WikiV/">
 <div class="wikitoc">
  <ul>
' || _out || '
  </ul>
 </div>
</div>
';

}
;



create function WV.WIKI.NNBSPS (in header_class varchar)
{
  declare n, i int;
  n := cast (subseq (header_class, 1) as int);

  declare ss any;
  ss := string_output();
  http ('<x>',ss);
  for ( i:=2 ; i < 2*n ; i := i+1)
    {
      http ('<y/>', ss);
    }
  http ('</x>', ss);
  return xtree_doc (string_output_string (ss), 2);
}
;

grant execute on WV.WIKI.NNBSPS to public
;

xpf_extension ('http://www.openlinksw.com/Virtuoso/WikiV/:nnbsps', 'WV.WIKI.NNBSPS')
;


create function WV.WIKI.TRIM (in str varchar)
{
  return trim (str, ' \t\n\r');
}
;

grant execute on WV.WIKI.TRIM to public
;

xpf_extension ('http://www.openlinksw.com/Virtuoso/WikiV/:trim', 'WV.WIKI.TRIM')
;


create function WV.WIKI.MACRO_META_TOPICPARENT (inout _data varchar, inout _context any, inout _env any)
{
  if (get_keyword ('is_new', _env, NULL) is not null
     or get_keyword('command', _env, '') = 'Preview')
    return '((will be processed later))';
  declare _args any;
  declare _name, _signal varchar;
  _args := WV.WIKI.PARSEMACROARGS (_data);
  _name := WV.WIKI.GETMACROPARAM (_args, 'name', NULL);
  _signal := WV.WIKI.GETMACROPARAM (_args, 'signal', '0');
  declare _parent int;
  declare _cluster int;
  declare _topic int;

  _cluster := get_keyword ('ti_cluster_id', _env, NULL);
  _topic := get_keyword ('ti_id', _env, NULL);

  if (_name is null)
    {
      if (exists (select * from WV.WIKI.TOPIC where TopicId = _topic
			and ClusterId = _cluster
			and ParentId <> 0))
 	update WV.WIKI.TOPIC set ParentId = 0
		where TopicId = _topic
		and ClusterId = _cluster;
      return '';
    }
		

  _parent := (select TopicId from WV.WIKI.TOPIC where LocalName = _name and ClusterId = _cluster);
  if (_parent is null)
    {
      if (lcase (_signal) = 't')
        signal ('WV100', 'META:TOPICPARENT needs valid topic name as "name" argument');
      else
        return '';
    }
  if (exists (select * from WV.WIKI.TOPIC 
	where TopicId = _topic
	and ClusterId = _cluster
	and ParentId = _parent))
    return '';
  
  update WV.WIKI.TOPIC set ParentId = _parent 
	where TopicId = _topic
	and ClusterId = _cluster;
  signal('WVRLD' , '');
  return '';

}
;

create function WV.WIKI.MACRO_META_TOPICINFO (inout _data varchar, inout _context any, inout _env any)
{
  if (get_keyword ('import', _env, NULL) is null)
    return '';
  if (connection_get ('WikiV macro TOPICINFO') is not null)
    return '';
  connection_set ('WikiV macro TOPICINFO', 1);
  declare _args any;
  declare _name varchar;
  declare _crdt int;
  _args := WV.WIKI.PARSEMACROARGS (_data);
  _name := WV.WIKI.GETMACROPARAM (_args, 'author', NULL);
  _crdt := atoi (WV.WIKI.GETMACROPARAM (_args, 'date', '0'));
  declare _uid int;
  declare _cluster int;
  declare _topic, _res_id int;

  _cluster := get_keyword ('ti_cluster_id', _env, NULL);
  _topic := get_keyword ('ti_id', _env, NULL);
  _res_id := get_keyword ('ti_res_id', _env, NULL);

  if (_name is null)
    return '';
  _name := trim (_name);

  if (length (_name) = 0)
    signal ('WV100', 'META:TOPICINFO needs valid user name as "author" argument');

  update WV.WIKI.TOPIC set AuthorName = _name
	where TopicId = _topic
	and ClusterId = _cluster;
  set triggers off;
  update WS.WS.SYS_DAV_RES set RES_MOD_TIME = dateadd ('second', _crdt,  stringdate ('1970.01.01'))
  	where RES_ID = _res_id;
  set triggers on;
  
  return '';

}
;

create function WV.WIKI.MACRO_BLOGTABS (inout _data varchar, inout _context any, inout _env any) {
  return '<div id="blogtabs" style="width: 100%;background: #2CBCEF; color:  white; font-family: helvetica; font-size: 14pt;padding: 3px"><div  style="width: 100%; text-align: left; left; clear: none"> |  [[OdsWeblogProductTourWhat][1]] |[[OdsWeblogProductTourOverview][2]] |  [[OdsWeblogProductTourWhy][3]]  |  [[OdsWeblogProductTourHow][4]]  |  [[OdsWeblogProductTourBasic Features][5]] |  [[OdsWeblogProductTourAdvancedFeatures][6]]  |[[OdsWeblogProductTourStart][7]] | [[OdsWeblogProductTourLearn][8]]  |</div> </div>';
};

create function WV.WIKI.MACRO_BRIEFCASETABS (inout _data varchar, inout _context any, inout _env any) {
  return '<div id="blogtabs" style="width: 100%;background: #2CBCEF; color:  white; font-family: helvetica; font-size: 14pt;padding: 3px"><div  style="width: 100%; text-align: left; left; clear: none"> |  [[OdsBriefcaseProductTourWhat][1]]  |[[OdsBriefcaseProductTourOverview][2]] |  [[OdsBriefcaseProductTourWhy][3]]   | [[OdsBriefcaseProductTourHow][4]]  | [[OdsBriefcaseProductTourBasic Features][5]] |  [[OdsBriefcaseProductTourAdvancedFeatures][6]]  |[[OdsBriefcaseProductTourStart][7]] |  [[OdsBriefcaseProductTourLearn][8]] |</div> </div>';
};

create function WV.WIKI.MACRO_FEEDSTABS (inout _data varchar, inout _context any, inout _env any) {
  return '<div id="blogtabs" style="width: 100%;background: #2CBCEF; color:  white; font-family: helvetica; font-size: 14pt;padding: 3px"><div  style="width: 100%; text-align: left; left; clear: none"> |  [[OdsFeedsProductTourWhat][1]] |[[OdsFeedsProductTourOverview][2]] |  [[OdsFeedsProductTourWhy][3]]  |  [[OdsFeedsProductTourHow][4]]  |  [[OdsFeedsProductTourBasic Features][5]] |  [[OdsFeedsProductTourAdvancedFeatures][6]]  |[[OdsFeedsProductTourStart][7]] | [[OdsFeedsProductTourLearn][8]]  |</div> </div>';
};

create function WV.WIKI.MACRO_BOOKMARKTABS (inout _data varchar, inout _context any, inout _env any) {
  return '<div id="blogtabs" style="width: 100%;background: #2CBCEF; color:  white; font-family: helvetica; font-size: 14pt;padding: 3px"><div  style="width: 100%; text-align: left; left; clear: none"> |  [[OdsBookmarkProductTourWhat][1]] |[[OdsBookmarkProductTourOverview][2]]  | [[OdsBookmarkProductTourWhy][3]]  |  [[OdsBookmarkProductTourHow][4]]  | [[OdsBookmarkProductTourBasic Features][5]] |  [[OdsBookmarkProductTourAdvancedFeatures][6]]  |[[OdsBookmarkProductTourStart][7]] | [[OdsBookmarkProductTourLearn][8]]  |</div> </div>';
};

create function WV.WIKI.MACRO_WIKITABS (inout _data varchar, inout _context any, inout _env any) {
  return '<div id="blogtabs" style="width: 100%;background: #2CBCEF; color:  white; font-family: helvetica; font-size: 14pt;padding: 3px"><div  style="width: 100%; text-align: left; left; clear: none"> |  [[OdsWikiProductTourWhat][1]] |[[OdsWikiProductTourOverview][2]] |  [[OdsWikiProductTourWhy][3]]   | [[OdsWikiProductTourHow][4]]  |  [[OdsWikiProductTourBasic Features][5]] |  [[OdsWikiProductTourAdvancedFeatures][6]]  |[[OdsWikiProductTourStart][7]] | [[OdsWikiProductTourLearn][8]] |</div>  </div>';
};

create function WV.WIKI.MACRO_MAILTABS (inout _data varchar, inout _context any, inout _env any) {
  return '<div id="blogtabs" style="width: 100%;background: #2CBCEF; color:  white; font-family: helvetica; font-size: 14pt;padding: 3px"><div  style="width: 100%; text-align: left; left; clear: none"> |  [[OdsMailProductTourWhat][1]] |[[OdsMailProductTourOverview][2]] |  [[OdsMailProductTourWhy][3]]  | [[OdsMailProductTourHow][4]]  |  [[OdsMailProductTourBasic Features][5]] |  [[OdsMailProductTourAdvancedFeatures][6]]  |[[OdsMailProductTourStart][7]] | [[OdsMailProductTourLearn][8]] |</div>  </div>';
};

create function WV.WIKI.MACRO_GALLERYTABS (inout _data varchar, inout _context any, inout _env any) {
  return '<div id="blogtabs" style="width: 100%;background: #2CBCEF; color:  white; font-family: helvetica; font-size: 14pt;padding: 3px"><div  style="width: 100%; text-align: left; left; clear: none"> |  [[OdsGalleryProductTourWhat][1]] |[[OdsGalleryProductTourOverview][2]] |  [[OdsGalleryProductTourWhy][3]]   | [[OdsGalleryProductTourHow][4]]  |  [[OdsGalleryProductTourBasic Features][5]] |  [[OdsGalleryProductTourAdvancedFeatures][6]]  |[[OdsGalleryProductTourStart][7]] | [[OdsGalleryProductTourLearn][8]]  |</div> </div>';
};

create function WV.WIKI.MACRO_ODSTABS (inout _data varchar, inout _context any, inout _env any) {
  return '<div id="blogtabs" style="width: 100%;background: #2CBCEF; color:  white; font-family: helvetica; font-size: 14pt;padding: 3px"><div  style="width: 100%; text-align: left; left; clear: none"> |  [[OdsProductTourWhat][1]] |[[OdsProductTourOverview][2]] |  [[OdsProductTourWhy][3]]  | [[OdsProductTourHow][4]]  |  [[OdsProductTourBasic Features][5]] |  [[OdsProductTourAdvancedFeatures][6]]  |[[OdsProductTourStart][7]] |  [[OdsProductTourLearn][8]] |</div> </div>';
};

create function WV.WIKI.MACRO_DISCUSSIONTABS (inout _data varchar, inout _context any, inout _env any) {
  return '<div id="blogtabs" style="width: 100%;background: #2CBCEF; color:  white; font-family: helvetica; font-size: 14pt;padding: 3px"><div  style="width: 100%; text-align: left; left; clear: none"> |  [[OdsDiscussionProductTourWhat][1]]  |[[OdsDiscussionProductTourOverview][2]] |  [[OdsDiscussionProductTourWhy][3]]  |  [[OdsDiscussionProductTourHow][4]]  | [[OdsDiscussionProductTourBasic Features][5]] |  [[OdsDiscussionProductTourAdvancedFeatures][6]]  |[[OdsDiscussionProductTourStart][7]] |  [[OdsDiscussionProductTourLearn][8]] |</div> </div>';
};

create function WV.WIKI.MACRO_COMMUNITYTABS (inout _data varchar, inout _context any, inout _env any) {
  return '<div id="blogtabs" style="width: 100%;background: #2CBCEF; color:  white; font-family: helvetica; font-size: 14pt;padding: 3px"><div  style="width: 100%; text-align: left; left; clear: none"> |  [[OdsCommunityProductTourWhat][1]]  |[[OdsCommunityProductTourOverview][2]] |  [[OdsCommunityProductTourWhy][3]]  |  [[OdsCommunityProductTourHow][4]]  | [[OdsCommunityProductTourBasic Features][5]] |  [[OdsCommunityProductTourAdvancedFeatures][6]]  |[[OdsCommunityProductTourStart][7]] |  [[OdsCommunityProductTourLearn][8]] |</div> </div>';
};

create function WV.WIKI.MACRO_BLOGNAV (inout _data varchar, inout _context any, inout _env any) {
  return '<div style="width: 100%; clear: both; float: none; margin-top:  5em"><hr /></div><div id="blognav" style="width: 100%; padding: 3px;  background: #2CBCEF; color: white; font-family: helvetica; font-size:  10pt; text-align: left; float:none; clear:both">Copyright (C) 1998-2016 [[http://www.openlinksw.com/][OpenLink Software]]</div>';
};

create function WV.WIKI.MACRO_VSREALM (inout _data varchar, inout _context any, inout _env any) {
  return '<div id="vsrealm" style="width: 100%;background: #000066; color:  white; font-family: helvetica; font-size: 11pt;padding: 4px"><div  style="width: 90%; text-align: left; left; clear: none"> EXPLORE THE  VIRTUOSO REALMS [[VirtuosoProductWebDataManagement][Data Management &  Integration]]  [[VirtuosoProductWebSOAPlatform][SOA Platform]]  [[VirtuosoProductWebWeb20][Collaboration]] </div> <div style="float:  none; clear: both"> </div> </div>';
};

create function WV.WIKI.MACRO_ODSARRLG (inout _data varchar, inout _context
any, inout _env any) {
  return '<img src="%ATTACHURLPATH%/Arrow.png" alt="Arrow.png" width="40"  height="40" />';
};

create function WV.WIKI.MACRO_ODSARR (inout _data varchar, inout _context
any, inout _env any) {
  return '<img src="%ATTACHURLPATH%/Arrow-sm.jpg" alt="Arrow-sm.jpg"  width="30" height="30" />';
};

create function WV.WIKI.MACRO_ODSSTART (inout _data varchar, inout _context
any, inout _env any) {
  return '<img src="%ATTACHURLPATH%/getstarted-sm.jpg"  alt="getstarted-sm.jpg" width="147" height="35" />';
};

create function WV.WIKI.MACRO_ODSNEXT (inout _data varchar, inout _context
any, inout _env any) {
  return ' <img src="%ATTACHURLPATH%/next-sm.jpg" alt="next-sm.jpg"  width="93" height="36" />';
};

create function WV.WIKI.MACRO_ODSPREV (inout _data varchar, inout _context
any, inout _env any) {
  return ' <img src="%ATTACHURLPATH%/previous-sm.jpg" alt="previous-sm.jpg"  width="105" height="34" />';
};

create function WV.WIKI.MACRO_BULSQ (inout _data varchar, inout _context
any, inout _env any) {
  return '<img src="%ATTACHURLPATH%/BULSQ.jpg" alt="BULSQ.jpg" width="25"  height="24" />';
};

create function WV.WIKI.MACRO_BULCR (inout _data varchar, inout _context
any, inout _env any) {
  return '<img src="%ATTACHURLPATH%/BULCR.png" alt="BULCR.png" width="26"  height="27" />';
};

create function WV.WIKI.MACRO_GLOBE (inout _data varchar, inout _context
any, inout _env any) {
  return '<img src="%ATTACHURLPATH%/GLOBE.jpg" alt="GLOBE.jpg" width="67"  height="67" />';
};

create function WV.WIKI.MACRO_VSDRKBLUE (inout _data varchar, inout
_context any, inout _env any) {
  return '<font color="#000066"> ';
};

create function WV.WIKI.MACRO_VSLTBLUE (inout _data varchar, inout _context
any, inout _env any) {
  return '<font color="#6699CC"> ';
};

create function WV.WIKI.MACRO_ODSTURQ (inout _data varchar, inout _context
any, inout _env any) {
  return '<font color="#0085BF">';
};

create function WV.WIKI.EXPAND_SIMPLE_MACRO (in _str varchar)
{
  return "WikiV macroexpander" (_str, 'test', 'test2', 'test3', null);
}
;

create function WV.WIKI.MACRO_REFBY (inout _data varchar, inout _context any, inout _env any)
{
  declare _topic_id int;
  _topic_id := get_keyword ('ti_id', _env, null);
  if (_topic_id is null)
    return '';
  declare _ss any;

  _ss := string_output();
  http ('<ul>', _ss);
  for select ClusterName, LocalName 
		    from WV.WIKI.LINK inner join WV.WIKI.TOPIC 
		     on (OrigId = TopicId)
		     natural join WV.WIKI.CLUSTERS
      where DestId = _topic_id
      order by LocalName do {
    http('<li>',_ss);
    http ('<a style="wikiword" href="', _ss);
    http_value (ClusterName || '.' || LocalName, null, _ss);
    http ('">', _ss);
    http_value (ClusterName || '.' || LocalName, null, _ss);
    http ('</a>',_ss);
    http('</li>',_ss);
  }
  http('</ul>', _ss);
  return xtree_doc (string_output_string(_ss));
}
;

create function WV.WIKI.MACRO_CATEGORY (inout _data varchar, inout _context any, inout _env any)
{
  return 'Category';
}
;
  

create function WV.WIKI.EXPAND_WIKI_TEXT (in _text varchar, in _env any)
{
  declare _entity any;
  _entity := xtree_doc (
    "WikiV lexer" (_text || '\r\n',
      get_keyword ('ti_cluster_name', _env),
      get_keyword ('ti_local_name', _env),
      get_keyword ('ti_curuser_wikiname', _env),
      NULL), 2);
  return  xpath_eval ('//div[@class=\'topic-text\']',
    WV.WIKI.VSPXSLT ( 'VspTopicView.xslt',_entity, _env));
}
;

grant execute on WV.WIKI.EXPAND_WIKI_TEXT to public
;

xpf_extension ('http://www.openlinksw.com/Virtuoso/WikiV/:expandWikiText', 'WV.WIKI.EXPAND_WIKI_TEXT')
;

create function WV.WIKI.MACRO_COMMENTS (inout _data varchar, inout _context any, inout _env any)
{
 declare sid, realm varchar;
 sid := get_keyword ('sid', _env, '');
 realm := get_keyword ('realm', _env, '');
 declare _pwd varchar;
 select PWD_MAGIC_CALC (U_NAME, U_PASSWORD) into _pwd from DB.DBA.SYS_USERS 
   where U_NAME = get_keyword ('user', _env, 'WikiGuest');
 declare _write_is_allowed int;
 if (DAV_HIDE_ERROR (DAV_AUTHENTICATE (cast (get_keyword ('ti_res_id', _env) as int), 'R', '_1_', get_keyword ('user', _env), _pwd)) is not null)
   _write_is_allowed := 1;
 else
   _write_is_allowed := 0;
   
 declare params varchar;
 params := coalesce (connection_get ('WIKI params'), vector ()); 
 declare _comment, _op varchar;
 _comment := trim (get_keyword ('comment', params));  
 _op := trim (get_keyword ('CommentPost', params));
 
 declare _topic_id int;
 _topic_id := atoi (get_keyword ('ti_id', _env));
 if (_op = 'Post' and _comment is not null and _comment <> '')
   {
     insert into WV.WIKI.COMMENT (C_TOPIC_ID,C_AUTHOR,C_EMAIL,C_TEXT,C_DATE,C_SUBJECT)
       values (
         _topic_id,
	 get_keyword ('author', params),
	 get_keyword ('email', params),
	 _comment,
	 now(),
	 get_keyword ('subject', params));
     signal ('WVRLD', 'selected=talks'); 
    }
  else if (_op = 'Delete')
    {
      declare _id int;
      _id :=  trim (get_keyword ('CommentId', params));
      delete from WV.WIKI.COMMENT 
        where C_TOPIC_ID = _topic_id
	and C_ID = _id;
    }
  declare _user_comments any;
  _user_comments := (select XMLELEMENT ('COMMENTS',
    XMLAGG(
     XMLELEMENT('COMMENT',
      XMLATTRIBUTES(
        C_AUTHOR as "author",
	C_ID as "id",
	C_EMAIL as "email",
	C_SUBJECT as "subject",
	WV.WIKI.DATEFORMAT(C_DATE) as "date"),
      C_TEXT)))
    from WV.WIKI.COMMENT where C_TOPIC_ID = _topic_id order by C_DATE);
  declare _user, _email varchar;
  _user := get_keyword ('user', _env, 'WikiGuest');
  _email := coalesce ((select U_E_MAIL from DB.DBA.SYS_USERS where U_NAME = _user), '');
  
  declare _xquery_script varchar;
  _xquery_script := 
'<div xmlns:wv="http://www.openlinksw.com/Virtuoso/WikiV/">
  <table>   
  { 
    for \044comment in //COMMENT
    return 
      <tr>
       <td id="wiki{\044comment/@id/string()}">
         <table width="70%" class="wikitable">
	  <tr>
	   <td colspan="3">
	    { \044comment/@subject/string() } 
	   </td>
	  </tr>
	  <tr>
	   <td colspan="3">
	    { wv:expandWikiText(\044comment/text(), \044env) }
	   </td>
	  </tr>
	  <tr>
	   <th> <a href="{\044comment/@author/string()}" style="wikiword">{\044comment/@author/string()}</a></th>
	   <th> { \044comment/@email/string() } </th>
	   <th> { \044comment/@date/string() } </th>
	  </tr>
	  {
	    if (\044write_is_allowed) 
	    then
	      <tr> 
	        <th colspan="3">
		  <form method="POST">
		    <input name="sid" type="hidden" value="{\044sid}"/>
		    <input name="realm" type="hidden" value="{\044realm}"/>
		    <input name="topic" type="hidden" value="{\044ti_cluster_name}.{\044ti_local_name}"/>
		    <input name="CommentId" type="hidden" value="{\044comment/@id/string()}"/>
		    <input name="CommentPost" type="submit" value="Delete"/>
		  </form>
	        </th> 
	      </tr>
	    else
	      <tr/>
	  }
	</table>
       </td>
      </tr>
  }
  </table>
  Post your comment:
  <table class="discussion-table">
   <form method="POST" action="{concat (\044baseadjust, ''../main/'', wv:ReadOnlyWikiWordLink (\044ti_cluster_name, \044ti_local_name))}">
   <input name="sid" type="hidden" value="{\044sid}"/>
   <input name="realm" type="hidden" value="{\044realm}"/>
   <input name="selected" type="hidden" value="talks"/>
   <tr>
    <th>Author</th>
    <td><input name="author" type="text" value="{\044auth}" size="50%"/></td>
   </tr>
   <tr>
    <th>e-mail</th>
    <td><input name="email" type="text" value="{\044email}" size="50%"/></td>
   </tr>
   <tr>
    <td colspan="2">
     <input name="subject" type="text" value="Re: { wv:NormalizeWikiWordLink (\044ti_cluster_name, \044ti_local_name) }" size="50%"/>
    </td>
   </tr>
   <tr>
    <td colspan="2">
      <textarea name="comment" rows="6" cols="80"/>  
    </td>
   </tr>
   <tr>
    <td colspan="2">
     <input type="submit" name="CommentPost" value="Post"/>
    </td>
   </tr>
   </form>
  </table>
 </div>';
  
  return xquery_eval(_xquery_script, _user_comments, 1,
  vector_concat (_env,
   vector (
   	'write_is_allowed', _write_is_allowed,
    	'env', _env,
   	'auth', _user,
	'email', _email,
	-- when sid and realm are not specified
	'sid', sid,
	'realm', realm)));
}
;
   
create function WV.WIKI.MACRO_TECHNORATI_COSMOS (inout _data varchar, inout _context any, inout _env any)
{
  declare api_key varchar;
  api_key := WV.WIKI.CLUSTERPARAM (get_keyword ('ti_cluster_name', _env),
  	'technorati_api_key', NULL);

  if (api_key is null)
    return '((API Key is not set))';

  declare _args any;
  declare _params, api_url varchar;
  declare _idx int;

  _args := WV.WIKI.PARSEMACROARGS (_data);
  _params := '';
  for (_idx := 0; _idx < length (_args); _idx := _idx + 1)
    {
      _params := _params || sprintf('&%s=%V', _args[_idx][0], _args[_idx][1]);
    }

  api_url := sprintf ('http://api.technorati.com/cosmos?key=%V%s', api_key, _params);
  
  declare _doc varchar;
  _doc := http_get (api_url);

  return xquery_eval (
  '<div class="macro-technorati-cosmos">
   <table class="wikitable">
    { 
      for \044item in //item 
      return
        <tr>
	  <th> <a href="{\044item//url}">{ \044item//name/text() }</a> </th>
	  <td> { \044item//excerpt/text() } <br/>
	    { for \044link in \044item//nearestpermalink/text()
	        where \044link != ""
	        return <a href="{\044link}">Permanent Link</a>
	    }
	  </td>
	</tr>
    }
   </table>
   </div>'
   , xtree_doc (_doc, 2));
}
;

create function WV.WIKI.MACRO_TECHNORATI_TAG (inout _data varchar, inout _context any, inout _env any)
{
  declare api_key varchar;
  api_key := WV.WIKI.CLUSTERPARAM (get_keyword ('ti_cluster_name', _env),
  	'technorati_api_key', NULL);

  if (api_key is null)
    return '((API Key is not set))';

  declare _args any;
  declare _params, api_url varchar;
  declare _idx int;

  _args := WV.WIKI.PARSEMACROARGS (_data);
  _params := '';
  for (_idx := 0; _idx < length (_args); _idx := _idx + 1)
    {
      _params := _params || sprintf('&%s=%V', _args[_idx][0], _args[_idx][1]);
    }

  api_url := sprintf ('http://api.technorati.com/tag?key=%V%s', api_key, _params);
  
  declare _doc varchar;
  _doc := http_get (api_url);

  return xquery_eval (
  '<div class="macro-technorati-tag">
   <table class="wikitable">
    { 
      for \044item in //item 
      return
        <tr>
	  <th> 
	    {
	      for \044img in \044item//thumbnailpicture/text()
	        where \044img != ""
		return
		  <img src="{\044img}"/>
	    }	  
	    <a href="{\044item//url}">{ \044item//name/text() }</a></th>
	  <td> <b> { \044item//title/text() }. </b> 
	    { \044item//excerpt/text() } <br/>
	    { for \044link in \044item//permalink/text()
	        where \044link != ""
	        return <a href="{\044link}">Permanent Link</a>
	    }
	  </td>
	</tr>
    }
   </table>
   </div>'
   , xtree_doc (_doc, 2));
}
;


create function WV.WIKI.MACRO_UNUSEDPAGES (inout _data varchar, inout _context any, inout _env any)
{
  declare _args any;
  _args := WV.WIKI.PARSEMACROARGS (_data);
  declare _cluster_name varchar;
  _cluster_name := WV.WIKI.GETMACROPARAM (_args, 'param', get_keyword ('ti_cluster_name', _env));
  
  declare _index_page varchar;
  _index_page := WV.WIKI.CLUSTERPARAM (_cluster_name, 'index-page', 'WelcomeVisitors');

  return (select XMLELEMENT ("MACRO_UNUSEDPAGES",
    	   XMLELEMENT("ul",
	     XMLAGG(
	       XMLELEMENT("li",
		  WV.WIKI.A(t.LocalName, t.LocalName, 'wikiword')))))
	   from WV.WIKI.TOPIC t inner join WV.WIKI.CLUSTERS c
	    on (t.ClusterId = c.ClusterId)
	    where c.ClusterName = _cluster_name
	    and t.LocalName not in (_index_page, 'ClusterSummary', WV.WIKI.DASHBOARD (), 'NoWhere')
	    and not exists (select * from WV.WIKI.LINK where DestId = t.TopicId));
}
;

create function WV.WIKI.A(in _href varchar, in _content varchar, in _class varchar)
{
  return XMLELEMENT ("a", 
  	XMLATTRIBUTES (
	 _href as "href", 
	 _class as "style"), _content);
}
;

create function WV.WIKI.MACRO_STATISTICS_POPULARTOPICS (inout _data varchar, inout _context any, inout _env any)
{
  declare _cluster_id int;
  _cluster_id := atoi (get_keyword ('ti_cluster_id', _env));
  return (select XMLELEMENT("MACRO_STATISTICS_POPULARTOPICS",
  	 	  XMLELEMENT ("table", XMLATTRIBUTES ('wikitable' as "class"),
		   XMLAGG(
		    XMLELEMENT("tr",
		     XMLELEMENT("td", WV.WIKI.A(LocalName, LocalName, 'wikiword')),
		     XMLELEMENT("td", Cnt)))))
		 from (select top 10 * from WV.WIKI.HITCOUNTER natural join WV.WIKI.TOPIC
		 	where ClusterId = _cluster_id
			order by Cnt desc) a);
}
;

create function WV.WIKI.MACRO_STATISTICS_TOPAUTHORS (inout _data varchar, inout _context any, inout _env any)
{
  return (select XMLELEMENT("MACRO_STATISTICS_TOPAUTHORS",
  	 	  XMLELEMENT ("table", XMLATTRIBUTES ('wikitable' as "class"),
		   XMLAGG(
		    XMLELEMENT("tr",
		     XMLELEMENT("td", WV.WIKI.A(U_NAME, U_NAME, 'wikiword')),
		     XMLELEMENT("td", Cnt)))))
		 from (select top 10 * from WV.WIKI.COMMITCOUNTER inner join DB.DBA.SYS_USERS 
		 	on (AuthorId = U_ID)
			order by Cnt desc) a);
}
;

		      
create function WV.WIKI.MACRO_SEMANTIC_FACTS (inout _data varchar, inout _context any, inout _env any)
{
  declare _topic_id, _cluster_id int;
  declare _local_name varchar;
  declare _args any;
  _args := WV.WIKI.PARSEMACROARGS (_data);
  _local_name := trim (WV.WIKI.GETMACROPARAM (_args, 'param', get_keyword ('ti_local_name', _env)));
  _cluster_id := atoi (get_keyword ('ti_cluster_id', _env));	
  _topic_id := (select TopicId from WV.WIKI.TOPIC where LocalName = _local_name and ClusterId = _cluster_id);
  declare _res any;
  _res := (select XMLELEMENT ("MACRO_SEMANTIC_FACTS",
  	 	  XMLELEMENT ("table", XMLATTRIBUTES ('wikitable' as "class"),
		   XMLAGG(
		    XMLELEMENT("tr",
		     XMLELEMENT("td",
		      PRED_DESCR || ':'),
		     XMLELEMENT("td",
		      case when SO_TYPE = ':VALUE' then SO_SUBJECT else 
		        WV.WIKI.A (SO_SUBJECT, SO_SUBJECT, 'forcedwikiword') end)))))
	   from WV.WIKI.SEMANTIC_OBJ, WV.WIKI.PREDICATE
	     where PRED_ID = SO_PRED
	     and SO_OBJECT_ID = _topic_id);
  declare _ent any;
  _ent := xpath_eval ('//tr', _res);
  if (_res is not null and _ent is not null)	     
   XMLInsertBefore (_ent,
   	XMLELEMENT ('tr', 
	 XMLELEMENT ('th',
	  XMLATTRIBUTES(2 as "COLSPAN"),
	  'Facts about ', WV.WIKI.A (_local_name, _local_name, 'wikiword'))));
  else
    _res := '';
  return _res;	 
}
;


create function WV.WIKI.MACRO_NOW (inout _data varchar, inout _context any, inout _env any)
{
  return WV.WIKI.DATEFORMAT(now());
}
;

create function WV.WIKI.MACRO_USERPROP (inout _data varchar, inout _context any, inout _env any)
{
  declare _username varchar;
  _username := get_keyword ('ti_local_name', _env, NULL);
  declare _vec any;
  if (_username = 'TemplateUser')
    return '';
  whenever not found goto again;
  select vector ('FULLNAME', U_FULL_NAME, 'EMAIL', U_E_MAIL) into _vec from DB.DBA.SYS_USERS, WV.WIKI.USERS
	where U_ID = USERID
	and USERNAME = _username;
  if (0)
    {
again:
       whenever not found default;
       declare _uid int;
       declare parts any;
       parts := regexp_parse('^(.*[^0-9])([0-9]*)\$', _username, 0);
       if(parts is null or length(parts) <> 6)
         return ''; 
       _uid := atoi (subseq (_username, parts[4], parts[5]));
       _username := subseq (_username, parts[2], parts[3]);
  select vector ('FULLNAME', U_FULL_NAME, 'EMAIL', U_E_MAIL) into _vec from DB.DBA.SYS_USERS, WV.WIKI.USERS
	where U_ID = USERID
		and U_ID = _uid
	and USERNAME = _username;
    }
      
       
  declare _args any;
  _args := WV.WIKI.PARSEMACROARGS (_data);
  declare _prop varchar;
  _prop := WV.WIKI.GETMACROPARAM (_args, 'param', NULL);

  return get_keyword (_prop, _vec);
}
;
  
		      
create function WV.WIKI.MACRO_TOPPAGES (inout _data varchar, inout _context any, inout _env any)
{
  declare _args, _res any;
  _args := WV.WIKI.PARSEMACROARGS (_data);
  declare _cluster_id int;
  declare _regex varchar;
  _cluster_id := atoi (get_keyword ('ti_cluster_id', _env));	
  _regex := WV.WIKI.GETMACROPARAM (_args, 'param', '.*');
  _res := (select XMLELEMENT ('nodes', XMLAGG (XMLELEMENT ('node', 
       XMLELEMENT ('name', LOCALNAME),
       XMLELEMENT ('mitem', WV.WIKI.DATEFORMAT(RES_MOD_TIME)),
       XMLELEMENT ('title', coalesce (TITLETEXT, LOCALNAME)))))
    from (select top (5) * from WV.WIKI.TOPIC, WS.WS.SYS_DAV_RES where
    	     CLUSTERID = _cluster_id 
	     and RES_ID = RESID
	     and regexp_match (_regex, LOCALNAME) is not null
	         order by RES_MOD_TIME desc) a);
  return _res;
}
;

create function WV.WIKI.MACRO_USERS (inout _data varchar, inout _context any, inout _env any)
{
  declare _args, _res, _ent, _xml, _cluster any;
  _cluster := get_keyword ('ti_cluster_name', _env);
  _args := WV.WIKI.PARSEMACROARGS (_data);

  _res := (select VECTOR_AGG ( vector (ucase(UserName), XMLELEMENT ('li', 
	 WV.WIKI.A (UserName, UserName, 'wikiword'),
	 case when length(SecurityCmt) > 0 then ' -- ' || cast (SecurityCmt as varchar) else '' end)))
    from (select * from WV.WIKI.USERS order by UserName) a
    where exists (select 1 from DB.DBA.WA_MEMBER 
    		        where WAM_USER = USERID
      			 and WAM_INST = _cluster)
    );

  declare _last_char int;
  _last_char := 0;
  
  _xml := XMLELEMENT ('ul');
  _ent := xpath_eval ('/ul', _xml);

  foreach (any p in _res) do {
    if (_last_char <> p[0][0])
      XMLAppendChildren (_ent, XMLELEMENT ('li', XMLELEMENT ('A', XMLATTRIBUTES (subseq (p[0], 0, 1) as "name", 'noapp' as "class"), subseq (p[0],0,1))));
    _last_char := p[0][0];
    XMLAppendChildren (_ent, p[1]);
  }

  return _xml;
}
;



use WV
;

create function print (in x any)
{
  declare ss any;
  ss := connection_get('Wiki macro output');
  http ('<p>', ss);
  http_value (x, null, ss);
  http ('</p>', ss);
}
;

create function puts (in x any)
{
  declare ss any;
  ss := connection_get('Wiki macro output');
  http (cast (x as varchar), ss);
}  
;


create function WV.WIKI.INLINE_MACRO_NAME (in _cluster varchar, in _localname varchar, in _postfix varchar)
{
  declare _name varchar;
  _name := sprintf ('WV.Wiki.EXEC_FUNC_%s_%s_', _cluster, _localname);
  if (_postfix is null)
    _name := _name || '%';
  else
    _name := _name || _postfix;
  return _name;
--  return fix_identifier_case (_name);
}
;
  
create function WV.WIKI.MACRO_INLINE (inout _data varchar, inout _context any, inout _env any)
{
  if (WV.WIKI.CLUSTERPARAM (get_keyword ('ti_cluster_name', _env), 'syscalls', 2) = 2)
    return '{{{disabled}}}';
  declare _procname varchar; 
		      
  _procname := WV.WIKI.INLINE_MACRO_NAME (
  	    get_keyword ('ti_cluster_name', _env), 
     	    get_keyword ('ti_local_name', _env),
	    md5 (_data));
  if (get_keyword ('command', _env) = 'Preview')
    {
      declare _state, _message, _st1, _m1 varchar;
      _state := '00000';
      _message := '';
      exec (WV.WIKI.INLINE_MACRO_FUNCTION (_procname, _data), _state, _message);
      -- we do not need signals here
      exec ('drop procedure ' || _procname, _st1, _m1);
      if (_state = '00000')
        return '{{{Compilation successful}}}';
      else
        return '{{{Compilation error: '|| _state || ':' || _message || '}}}';
    }


  declare _res any;
  _res := call (_procname) (_env);
  return xtree_doc (_res, 2);
}
;
create function WV..PARSE_MACRONAME(in _name varchar)
{
  declare _parts any;
  _parts := regexp_parse ('WV\\.[^.]+\\.MACRO_([^_]+)_(.*)', _name, 0);
  if (_parts is null)
    return vector ('Standard', subseq (_name, 14));
  else
    return vector (subseq (_name, _parts[2], _parts[3]), subseq (_name, _parts[4], _parts[5]));
 }
 ;

create procedure WV.WIKI.MACRO_MACROS(inout _data varchar, inout _context any, inout _env any)
{
  declare _res, _ent, xmlMacros any;

  _res := xtree_doc('<div class="macro-list"/>');
  _ent := xpath_eval ('/div', _res);

  declare _args any;
  _args := WV.WIKI.PARSEMACROARGS (_data);
  declare _prop, _description varchar;
  _prop := WV.WIKI.GETMACROPARAM (_args, 'param', NULL);
  if (_prop = 'description') {
    declare sStream any;
    sStream := string_output();

    http ('<table>', sStream);
    http ('<tr><td><h2>Macro Name</h2></td><td><h2>Description</h2></td></tr>', sStream);

    xmlMacros := blob_to_string (DB.DBA.xml_uri_get ('virt://WS.WS.SYS_DAV_RES.RES_FULL_PATH.RES_CONTENT:/DAV/VAD/wiki/Root/', 'macros.xml'));
    xmlMacros := xml_tree_doc (xmlMacros);

    for select P_NAME, WV..PARSE_MACRONAME (P_NAME)[0] as _ns, WV..PARSE_MACRONAME (P_NAME)[1] as _name
      from DB.DBA.SYS_PROCEDURES where P_NAME like 'WV.%.MACRO_%'
      order by _ns, _name
    do {
      _description := xpath_eval (sprintf ('string (//macro[@id = "%s"]/description)', P_NAME), xmlMacros);
      if (_description = '') {
        _description := 'no description';
      }
      if (_ns <> 'Standard')
        _name := _ns ||':' || _name;
      http (sprintf ('<tr><td>%V</td><td>%V</td></tr>', _name, _description), sStream);
    }
    http ('</table>', sStream);
    XMLAppendChildren(_ent, xml_tree_doc (string_output_string(sStream)));

  } else {
  declare _ul, _ul_ent any;
  declare _currns varchar;
  _currns := '';
  _ul := null;

    xmlMacros := blob_to_string (DB.DBA.xml_uri_get ('virt://WS.WS.SYS_DAV_RES.RES_FULL_PATH.RES_CONTENT:/DAV/VAD/wiki/Root/', 'macros.xml'));
    --dbg_obj_print (xmlMacros);
    xmlMacros := xml_tree_doc (xmlMacros);

    for select P_NAME, WV..PARSE_MACRONAME (P_NAME)[0] as _ns, WV..PARSE_MACRONAME (P_NAME)[1] as _name
    from DB.DBA.SYS_PROCEDURES where P_NAME like 'WV.%.MACRO_%'
    order by _ns, _name
  do {
    if (_currns <> _ns) 
      {
        if (_ul is not null)
	  XMLAppendChildren(_ent, _ul);
        _ul := xtree_doc (sprintf('<div><h2>%V</h2><ul/></div>', _ns));
	_ul_ent := xpath_eval('//ul', _ul);
	_currns := _ns;
      }
      _description := xpath_eval (sprintf ('string (//macro[@id = "%s"]/description)', P_NAME), xmlMacros);
      if (_description = '') {
        _description := 'no description';
      }
      XMLAppendChildren (_ul_ent, xtree_doc (sprintf ('<li><div style="display:inline; width=200px;" title="%V">%V</div></li>', _description, _name)));
  }
  XMLAppendChildren(_ent, _ul);
  }
  return _res;
}
;
  
use DB
;
create function WV.WIKI.MACRO_VOSCOPY (inout _data varchar, inout _context any, inout _env any) { return ''; };
create function WV.WIKI.MACRO_META_TOPICMOVED (inout _data varchar, inout _context any, inout _env any) { return ''; };

create function WV.WIKI.MACRO_DOCINCLUDE (inout _data varchar, inout _context any, inout _env any)
{
  -- embeds the contents of another wiki page at the current point
  declare d varchar;
  declare ret varchar;

  d := _data;
  d := regexp_replace (d, '^param="', '');
  d := regexp_replace(d, '"\$', '');

  for (select top 1 blob_to_string (RES_CONTENT) as c from WS.WS.SYS_DAV_RES where RES_FULL_PATH like ('/DAV/%/' || d || '.txt')) do
    {
      ret := wv..render (c, 'owiki');
    }
  ret := tidy_html (ret, 'output-xml: yes\r\n');

  return xmlelement ('div',
                   xmlattributes ('included' as class, d as sourcepage),
                   xpath_eval ('//body', xtree_doc (ret), 0)[0]);
}
;

create function WV.WIKI.MACRO_FORTUNE (inout _data varchar, inout _context any, inout _env any)
{
  -- insert a random list item from another page at current point
  declare d, ret varchar;
  declare ls any;
  declare len integer;

  d := _data;
  d := regexp_replace(d, '^param="', '');
  d := regexp_replace(d, '"\$', '');

 for (select top 1 blob_to_string (RES_CONTENT) as c from WS.WS.SYS_DAV_RES where RES_FULL_PATH like ('/DAV/%/' || d || '.txt')) do
   {
     ret := wv..render (c, 'owiki');
   }
  ret := xtree_doc (tidy_html (ret, 'output-xml: yes\r\n'));

  ls := xpath_eval ('//ul[1]/li', ret, 0);
  len := length (ls);

 return xmlelement ('div',
                   xmlattributes ('fortune' as class, d as sourcepage),
                   ls[rnd (len)]);
}
;
