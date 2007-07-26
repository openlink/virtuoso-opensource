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

create function WV.WIKI.GET_COMMAND (in params any)
{
  return coalesce (get_keyword ('xmlraw', params), get_keyword ('command', params), 'wiki');
}
;

create function WV.WIKI.VSPTOPICCREATE (
  inout path any, 
  inout lines any,
  in _cluster varchar,
  in _title varchar,
  in params any)
  returns varchar
{
  declare _uid integer;
  declare _base_adjust varchar;
  _uid := get_keyword ('uid', params);
  _base_adjust := get_keyword ('baseadjust', params);
  declare _topic WV.WIKI.TOPICINFO;  
  _topic := WV.WIKI.TOPICINFO();
  _topic.ti_cluster_name := _cluster;
  _topic.ti_default_cluster := _cluster;
  _topic.ti_raw_name := _title;
  _topic.ti_parse_raw_name ();
  _topic.ti_raw_title := _title;
  _topic.ti_find_id_by_raw_title();
  _topic.ti_fill_cluster_by_name();
  WV.WIKI.CHECKWRITEACCESS (_uid, _topic.ti_res_id, _topic.ti_cluster_id, _topic.ti_col_id, 'Owner of this cluster does not allow you to create new topics');

--  _topic.ti_http_debug_print('VspTopicCreate: info about current topic');
--  if (0 = WS.WS.CHECK_READ_ACCESS (_uid, _topic.ti_res_id))
--    {
--      VspReportFailedReadAccess (path, params, lines, _topic.ti_cluster_name, _topic.ti_local_name, '');
--      return;
--    }
  declare _ext_params any;
  declare _template varhar;
  if (_topic.ti_local_name like 'Category%')
    _template := WV.WIKI.CLUSTERPARAM (_topic.ti_cluster_id, 'new-category-template', '');
  else
    _template := WV.WIKI.CLUSTERPARAM (_topic.ti_cluster_id, 'new-topic-template', '');
  if (get_keyword ('parent', params) is not null)
    {
      _template := '%META:TOPICPARENT{name="' || get_keyword('parent', params) || '"}%\n' || _template;
    }
  WV.WIKI.SET_TEMP_TEXT (_topic.ti_cluster_name, _topic.ti_local_name, 
	coalesce (get_keyword ('temp-text', params), _template),
	params);

  _ext_params := _topic.ti_xslt_vector (vector_concat (params,
	 vector ('is_new', '1'))); 

  declare _artiles any;
  
  _artiles := (select XMLELEMENT('div', XMLATTRIBUTES('simpages' as "id"),
  		XMLAGG (
		    XMLELEMENT ('a', 
			XMLATTRIBUTES('wikiword' as "style", LocalName as "href"),
			LocalName)))
		  from WV.WIKI.TOPIC where ClusterId = _topic.ti_cluster_id and LocalName like cast ('%' || _topic.ti_local_name || '%' as varchar)); 

		  

	 
  http_value (
    WV.WIKI.VSPXSLT ( 'VspTopicCreate.xslt',
      _artiles,
       _ext_params));
}
;

create function WV.WIKI.VSPTOPICVIEW (
  inout path any, inout lines any,
  inout _topic WV.WIKI.TOPICINFO,
  in params any)
  returns varchar
{
--  dbg_obj_print (_topic);
  declare _uid int;
  declare _base_adjust, _command varchar;
  _uid := get_keyword ('uid', params);
  _base_adjust := get_keyword ('baseadjust', params);
  _command := WV.WIKI.GET_COMMAND(params);
  declare _text, _is_hist varchar;  
  declare exit handler for sqlstate '42WV9' {
    --dbg_obj_princ ('WV.WIKI.VSPTOPICVIEW ', params);
    if (get_keyword ('lastop', params) is not null 
        or (get_keyword ('lastop', params) = 'Logout'))
      {
        declare _main_topic WV.WIKI.TOPICINFO;
	_main_topic := WV.WIKI.GET_MAINTOPIC ('Main');
	if (_topic.ti_id = _main_topic.ti_id) -- already index page of Main cluster
	  resignal;
	WV.WIKI.VSPTOPICVIEW (
	      path, lines,
	      _main_topic,
	      params);
      }
    else
      resignal;
  }
  ;
  whenever sqlstate '22005' goto wrong_rev;
  _topic.ti_rev_id := cast (get_keyword ('rev', params, 0) as integer);
  --dbg_obj_print ('{{{{', _topic.ti_rev_id);
  if (0)
    {
      wrong_rev: 
 	--dbg_obj_print (200);
        _topic.ti_rev_id := 0;
    }
  _topic.ti_find_metadata_by_id ();
  _topic.ti_base_adjust := _base_adjust;
  --dbg_obj_print (_topic.ti_rev_id);
  
  _is_hist := '';
  if (0 < DB.DBA.DAV_SEARCH_ID ( DB.DBA.DAV_SEARCH_PATH (_topic.ti_col_id, 'C') ||
  	'VVC/' || _topic.ti_local_name || '.txt/', 'C' ))
    _is_hist := 't';
  --dbg_obj_print ( 101 );
    
--  _topic.ti_http_debug_print('VspTopicView: info about current topic');
  _topic.ti_curuser_wikiname := coalesce ((select UserName from WV.WIKI.USERS where UserId=_uid), '?');
  _topic.ti_curuser_username := coalesce ((select U_NAME from DB.DBA.SYS_USERS where U_ID=_uid), '?');
  _topic.ti_base_adjust := _base_adjust;
  --dbg_obj_print (params);
  --dbg_obj_print (_topic);
  declare _xhtml varchar;
  WV.WIKI.CHECKREADACCESS (_uid, _topic.ti_res_id, _topic.ti_cluster_id, _topic.ti_col_id);
  
  declare _cnt int;
  declare cr cursor for select Cnt from WV.WIKI.HITCOUNTER
    where TopicId = _topic.ti_id for update;
  whenever not found goto ins;
  open cr (prefetch 1);
  fetch cr into _cnt;
  update WV.WIKI.HITCOUNTER set Cnt = _cnt + 1
  	where current of cr;
  close cr;
  if (0)
    {
ins:
  	insert into WV.WIKI.HITCOUNTER (TopicId, Cnt) 
  		values (_topic.ti_id, 1);
    }
  whenever not found default;
  --dbg_obj_princ (_topic.ti_get_entity (null,1));
  if (get_keyword ('selected', params, 'main') = 'talks')
    _topic.ti_text := '%COMMENTS%\n';

  declare _ext_params any;
  _ext_params := vector_concat (_topic.ti_xslt_vector (params), 
  	vector ('is_hist', _is_hist, 'revision', _topic.ti_rev_id));
  if (WV.WIKI.CLUSTERPARAM (_topic.ti_cluster_id, 'qwiki', 2) = 1)
    _ext_params := vector_concat (_ext_params, vector ('qwikidisabled', '1'));
  _xhtml := _topic.ti_get_entity(null, 1);
--  dbg_obj_princ ('>>>>>>' ,_xhtml);
--  dbg_obj_princ ('[[[', _ext_params);
  if (_command not in ('docbook'))
  _xhtml := 
    WV.WIKI.VSPXSLT ( 'VspTopicView.xslt', _xhtml,
      _ext_params);
  if (_command = 'xmlraw')
    {
      http_rewrite ();
      http_value (_xhtml); 
      return 0;
    }
  else if (_command = 'docbook')
	{
	  _xhtml:= '<html xmlns="http://www.w3.org/1999/xhtml">
		<head>
	  <title>' || _topic.ti_local_name || '</title>
	</head>
	<body>' || serialize_to_UTF8_xml (_topic.ti_get_entity(null, 0)) || '</body>
   </html>';
	  http_rewrite ();
	  http_header ('Content-Type: text/xml; charset=UTF-8\r\n');
	  http_value (WV.WIKI.VSPXSLT ('html2docbook.xsl', xtree_doc (_xhtml), _ext_params));

	  return 0;
    }
  declare _skin varchar;
  _skin := coalesce (get_keyword  ('skin2', params), get_keyword ('skin', params), 'default');

  declare _creator varchar;
  _creator := WV.WIKI.CLUSTERPARAM (_topic.ti_cluster_id, 'creator', 'dav');  
  _ext_params := WV.WIKI.USER_PARAMS (_ext_params, _creator, _topic); 


  http_rewrite ();
  if (get_keyword  ('skin2', params) is not null)
    ODS.BAR._EXEC(null,vector_concat (params, vector ('explicit-host', 1)), lines);
  else
    ODS.BAR._EXEC(null,params, lines);
  declare _ods_bar any;
  _ods_bar := http_get_string_output();
  _ods_bar := xtree_doc(_ods_bar, 2);
  _ext_params := vector_concat (_ext_params, vector ('ods-bar', _ods_bar));
  http_rewrite ();
  http_header ('Content-Type: text/html; charset=UTF-8\r\n');
--  dbg_obj_princ ('> ', _base_adjust); 
  _xhtml :=
    WV.WIKI.VSPXSLT ( 'PostProcess.xslt', _xhtml,
      vector_concat (_ext_params),
      _skin );
  http_header ('Content-Type: text/html; charset=UTF-8\r\n');
  if (WV.WIKI.CLUSTERPARAM (_topic.ti_cluster_id, 'email-obfuscate') is not null)
  http_value (_xhtml);
  else
    {
       declare _content any;
       _content := string_output ();
       http_value (_xhtml, 0, _content);
       _content := string_output_string (_content);
       http (_content);
    }
  return 0;
}
;

create function WV.WIKI.VSPTOPICVIEW_TEMP (
  inout path any, inout lines any,
  inout _topic WV.WIKI.TOPICINFO,
  in params any,
  in cmd varchar)
  returns varchar
{
  declare _uid int;
  declare _base_adjust varchar;
  _uid := get_keyword ('uid', params);
  _base_adjust := get_keyword ('baseadjust', params);
  declare _text varchar;  
  _text := WV.WIKI.GET_TEMP_TEXT (_topic.ti_cluster_name, _topic.ti_local_name);
  declare _ext_params any;
  _ext_params := _topic.ti_xslt_vector (params);
  http_rewrite();
  if (cmd = 'temp-text')
    {
      http_header ('Content-Type: text/plain; charset=UTF-8\r\n');
      http_value (_text);
    }
  else if (cmd = 'temp-html')
    {
      declare _xhtml any;
      _topic.ti_text := _text;

      http_header ('Content-Type: text/html; charset=UTF-8\r\n');
      declare _content any;
      _xhtml := XMLELEMENT ('html', 
		 XMLELEMENT ('body'));
      _content := xpath_eval ('//body', _xhtml);
            
      foreach (any elem in xpath_eval ('//div[@class="topic-text"]/*', WV.WIKI.VSPXSLT ('VspTopicView.xslt', _topic.ti_get_entity(null, 0), _ext_params), 0)) do 
       {
	 XMLAppendChildren (_content, elem);
       }
      http_value (_xhtml);
    }
  else 
    signal ('WV701', 'unknown type of temp text, can be [text, html]');
}
;

create function WV.WIKI.VSPTOPICVIEW_PLAIN (
  inout path any, inout lines any,
  inout _topic WV.WIKI.TOPICINFO,
  in params any)
  returns varchar
{
  declare _uid int;
  declare _base_adjust varchar;
  _uid := get_keyword ('uid', params);
  _base_adjust := get_keyword ('baseadjust', params);
  declare _text varchar;  
  _topic.ti_find_metadata_by_id ();
  _topic.ti_curuser_wikiname := coalesce ((select UserName from WV.WIKI.USERS where UserId=_uid), '?');
  _topic.ti_curuser_username := coalesce ((select U_NAME from DB.DBA.SYS_USERS where U_ID=_uid), '?');
  _topic.ti_base_adjust := _base_adjust;
  declare _xhtml varchar;
  WV.WIKI.CHECKREADACCESS (_uid, _topic.ti_res_id, _topic.ti_cluster_id, _topic.ti_col_id);
  
  declare _ext_params any;
  _ext_params := _topic.ti_xslt_vector (params);
  http_rewrite();
  _xhtml := XMLELEMENT ('html', 
		XMLELEMENT ('body', 
		  xpath_eval ('//div[@class="topic-text"]', WV.WIKI.VSPXSLT ('VspTopicView.xslt', _topic.ti_get_entity (null,0),
			      _ext_params))));
  http_header ('Content-Type: text/html; charset=UTF-8\r\n');
  http_value (_xhtml);
}
;


create function WV.WIKI.VSPTOPICEDIT (
  inout path any, inout lines any,
  inout _topic WV.WIKI.TOPICINFO,
  in params any)
  returns varchar
{
  declare _text varchar;
  declare _uid int;
  declare _base_adjust varchar;
  _uid := get_keyword ('uid', params);
  _base_adjust := get_keyword ('baseadjust', params);
       
--  _topic.ti_http_debug_print('VspTopicView: info about current topic');
  WV.WIKI.CHECKWRITEACCESS (_uid, _topic.ti_res_id, _topic.ti_cluster_id, _topic.ti_col_id);
  WV.WIKI.CHECKREADACCESS (_uid, _topic.ti_res_id, _topic.ti_cluster_id, _topic.ti_col_id);
  _topic.ti_curuser_wikiname := coalesce ((select UserName from WV.WIKI.USERS where UserId=_uid), '?');
  _topic.ti_curuser_username := coalesce ((select U_NAME from DB.DBA.SYS_USERS where U_ID=_uid), '?');
  _topic.ti_base_adjust := _base_adjust;
  declare _xhtml any;

  declare _ext_params any;
   --dbg_obj_print (_topic);
  _topic.ti_find_metadata_by_id();
  _ext_params := _topic.ti_xslt_vector(params);


  WV.WIKI.SET_TEMP_TEXT (_topic.ti_cluster_name, _topic.ti_local_name, 
	WV.WIKI.DELETE_SYSINFO_FOR (coalesce (get_keyword ('temp-text', params), _topic.ti_text), NULL),
	params);

  _xhtml := WV.WIKI.VSPXSLT ( 'VspTopicEdit.xslt', _topic.ti_get_entity (null,1),
     _ext_params);
  http_value (_xhtml);
}
;

create function WV.WIKI.VSPTOPICPREVIEW (
  inout path any, inout lines any,
  in _topic_id int,
  in _topic_raw_title varchar,
  in _topic_text varchar,
  in is_new varchar, 
  in params any,
  in _cluster varchar)
  returns varchar
{
  declare _uid integer;
  declare _base_adjust varchar;
  _uid := get_keyword ('uid', params);
  _base_adjust := get_keyword ('baseadjust', params);
  declare _topic WV.WIKI.TOPICINFO;
  declare _text varchar;
  _topic := WV.WIKI.TOPICINFO ();
  _topic.ti_id := _topic_id;
  _topic.ti_raw_title := _topic_raw_title;
  if (is_new is null)
    is_new := '0';
  if (_topic.ti_id <> 0)
    {
      _topic.ti_find_metadata_by_id ();
    }
  else
    {
      _topic.ti_default_cluster := _cluster;
      _topic.ti_raw_name := _topic_raw_title;
      _topic.ti_parse_raw_name ();
      _topic.ti_fill_cluster_by_name ();
    }
  if (get_keyword ('fix-html', params) is not null)
    {
      _topic_text := WV.WIKI.HTML_TO_WIKI (_topic_text);
    }
  
  _topic.ti_text := _topic_text;
   
--  if (0 = WS.WS.CHECK_READ_ACCESS (_uid, _topic.ti_res_id))
--    {
--      VspReportFailedReadAccess (path, params, lines, _topic.ti_cluster_name, _topic.ti_local_name, '');
--      return;
--    }
  _topic.ti_curuser_wikiname := coalesce ((select UserName from WV.WIKI.USERS where UserId=_uid), '?');
  _topic.ti_curuser_username := coalesce ((select U_NAME from DB.DBA.SYS_USERS where U_ID=_uid), '?');
  _topic.ti_base_adjust := _base_adjust;
  WV.WIKI.CHECKWRITEACCESS (_uid, _topic.ti_res_id, _topic.ti_cluster_id, _topic.ti_col_id);
  WV.WIKI.CHECKREADACCESS (_uid, _topic.ti_res_id, _topic.ti_cluster_id, _topic.ti_col_id);
  declare _ext_params any;
  _ext_params := _topic.ti_xslt_vector(
	vector_concat(params, vector ('preview_mode', 1)));
  http_value (
    	 WV.WIKI.VSPXSLT ( 'VspTopicView.xslt', _topic.ti_get_entity (null,1),
	    _ext_params));
}
;

create function WV.WIKI.VSPTOPICREFERERS (
  inout path any, inout lines any,
  inout _topic WV.WIKI.TOPICINFO,
  in params any )
{
  declare _uid integer;
  declare _base_adjust varchar;
  _uid := get_keyword ('uid', params);
  _base_adjust := get_keyword ('baseadjust', params);
  declare _report any;
  declare _text varchar;
  -- _topic.ti_http_debug_print('VspTopicReferers: info about current topic');
  if (get_keyword ('command', params) = 'refby') 
    {
      _report := (select XMLELEMENT ('Referers',
				     XMLAGG ( 
					     XMLELEMENT ('Link',
							 XMLATTRIBUTES (c.ClusterName as "CLUSTERNAME",
									n.LocalName as "LOCALNAME",
									n.Abstract as "ABSTRACT") ) ) )
		  from (
			select distinct n2.LocalName, n2.Abstract, n2.ClusterId
			from WV.WIKI.LINK as l inner join WV.WIKI.TOPIC as n2 on (l.OrigId = n2.TopicId)
			 where l.DestId = _topic.ti_id
			 and n2.ClusterId = _topic.ti_cluster_id
			) as n
		  inner join WV.WIKI.CLUSTERS as c on (c.ClusterId = n.ClusterId) );
    }
  else
    {
      _report := (select XMLELEMENT ('Referers',
				     XMLAGG ( 
					     XMLELEMENT ('Link',
							 XMLATTRIBUTES (c.ClusterName as "CLUSTERNAME",
									n.LocalName as "LOCALNAME",
									n.Abstract as "ABSTRACT") ) ) )
		  from (
			select distinct n2.LocalName, n2.Abstract, n2.ClusterId
			from WV.WIKI.LINK as l inner join WV.WIKI.TOPIC as n2 on (l.OrigId = n2.TopicId)
			 where l.DestId = _topic.ti_id 
			) as n
		  inner join WV.WIKI.CLUSTERS as c on (c.ClusterId = n.ClusterId) );
    }
  declare _ext_params any;
  _ext_params := vector_concat (_topic.ti_xslt_vector(params),
  	vector ('donotresolve', 1));
  http_value (WV.WIKI.VSPXSLT ( 'PostProcess.xslt', 
    WV.WIKI.VSPXSLT ( 'VspTopicReports.xslt', _report,
      _ext_params),
   _ext_params,
   WV.WIKI.CLUSTERPARAM ( _topic.ti_cluster_id , 'skin', 'default' )));
}
;

create function WV.WIKI.VSPCLUSTERINDEX (
  inout path any, inout lines any,
  inout _topic WV.WIKI.TOPICINFO,
  in params any )
{
  declare _uid integer;
  declare _base_adjust varchar;
  _uid := get_keyword ('uid', params);
  _base_adjust := get_keyword ('baseadjust', params);
  declare _report any;
  declare _text varchar;
--  _topic.ti_http_debug_print('VspClusterIndex: info about current topic');
  _report := coalesce ((
      select XMLELEMENT ('ClusterIndex',
        XMLAGG ( 
          XMLELEMENT ('Link',
	    XMLATTRIBUTES (_topic.ti_cluster_name as CLUSTERNAME, n.LocalName as LOCALNAME, n.Abstract ABSTRACT) ) ) )
      from WV.WIKI.TOPIC n where n.ClusterId = _topic.ti_cluster_id ) );
  declare _ext_params any;
  _ext_params := vector_concat (_topic.ti_xslt_vector(params),
  	vector ('donotresolve', 1));

--  dbg_obj_print (_report);
  http_value (
    WV.WIKI.VSPXSLT ('PostProcess.xslt', 
	   WV.WIKI.VSPXSLT ( 'VspTopicReports.xslt', _report,
	   _ext_params),
	 _ext_params,
	 WV.WIKI.CLUSTERPARAM ( _topic.ti_cluster_id , 'skin', 'default' )));

}
;

create function WV.WIKI.VSPXSLT (in _xslt_name varchar, inout _src any, inout _params any, in _skin_name varchar:=null) returns any
{
  declare _xslt_folder varchar;
  if (_skin_name is null)
    _xslt_folder := '/DAV/VAD/wiki/Root/';
  else
    _xslt_folder := '/DAV/VAD/wiki/Root/Skins/' || _skin_name || '/';
  --dbg_obj_print (concat ('virt://WS.WS.SYS_DAV_RES.RES_FULL_PATH.RES_CONTENT:' || _xslt_folder, _xslt_name));
  return
--    xslt ( concat ('file://', _xslt_name), _src,
    
    xslt ( concat ('virt://WS.WS.SYS_DAV_RES.RES_FULL_PATH.RES_CONTENT:' || _xslt_folder, _xslt_name), _src,
      vector_concat (_params, vector ('env', _params))
    );
}
;  

create function WV.WIKI.VSPHTTPXSLT (in _xslt_name varchar, inout _params any) returns any
{
  return
    http_xslt ( concat ('virt://WS.WS.SYS_DAV_RES.RES_FULL_PATH.RES_CONTENT:/DAV/VAD/wiki/Root/', _xslt_name), 
      vector_concat (_params, vector ('env', _params))
    );
}
;  

create procedure WV.WIKI.VSPXGETUID (in web_login varchar, inout realm varchar, inout sid varchar)
{
  declare uid int;
  declare login varchar;
  
  if ( (login := web_login) is null)
    login := (select vs_uid from VSPX_SESSION where vs_sid = sid);
--  uid:= (select u.UserId  from DB.DBA.SYS_USERS as su inner join WV.WIKI.USERS as u on su.U_ID = u.UserId   where su.U_NAME = login and su.U_ACCOUNT_DISABLED = 0);
  uid:= (select U_ID from DB.DBA.SYS_USERS  where U_NAME = login and U_ACCOUNT_DISABLED = 0);
  if (uid is not null)
    return uid;
  realm := '';
  sid := '';
  return (select U_ID from DB.DBA.SYS_USERS where U_NAME = 'WikiGuest');
}
;
  

create function WV.WIKI.AUTHENTICATE (in _user varchar, in _pwd varchar)
{
   --dbg_obj_princ ('WV.WIKI.AUTHENTICATE ', _user, ' ', _pwd);
  declare _uid int;
  declare _e_mail varchar;
  whenever not found goto notf;
  select U_ID, U_E_MAIL into _uid, _e_mail from DB.DBA.SYS_USERS where U_NAME = _user;
  for select (wai_inst as wa_wikiv).cluster_id as cluster_id
    from WA_INSTANCE join WA_MEMBER 
  	on (WAM_INST = WAI_NAME) 
	where udt_instance_of (WAI_INST, fix_identifier_case ('DB.DBA.wa_wikiv')) 
	  and WAM_USER = _uid
  do {
        --dbg_obj_princ ('cluster: ', cluster_id);
    if (WV.WIKI.CLUSTERPARAM (cluster_id, 'ldap_enabled', 2) = 1)
      {
        declare ldap_user varchar;
	ldap_user :=  regexp_match ('[^@]+', coalesce (_e_mail, ''));
	if (ldap_user is null)
	  goto usual;
        return WV.WIKI.AUTH_BY_LDAP (cluster_id, ldap_user, _pwd);  
      }
  }
usual:  
  return DB.DBA.web_user_password_check (_user, _pwd);
notf:
   --dbg_obj_princ ('notf');
  return 0;
}
;

  
create procedure WV.WIKI.VSPCHECKWEBAUTH (
  inout path any, inout params any, inout lines any )
{
  declare _su_name, _su_password varchar;
  declare _su_id, _u_id integer;

  declare auth any;
  declare _username varchar;
  declare _reason varchar;
  declare rc integer;

  _username := '';
  _reason := '';
  --dbg_obj_print(lines);
  auth := DB.DBA.vsp_auth_vec (lines);
  if (0 = auth)
    {
      _reason := '. No authorization data are provided by your browser now';
      --dbg_obj_print ('auth', auth);
      goto auth_get;
    }

  _username := get_keyword ('username', auth, '');
  
  whenever not found goto badname;
  select su.U_NAME, su.U_PASSWORD, su.U_ID, u.UserId
  into _su_name, _su_password, _su_id, _u_id
  from DB.DBA.SYS_USERS as su inner join WV.WIKI.USERS as u on su.U_ID = u.UserId
  where su.U_NAME = _username and su.U_ACCOUNT_DISABLED = 0;
  
  rc := -1;
  if (sys_stat ('dbev_enable') and __proc_exists ('DB.DBA.DBEV_LOGIN'))
    {
      declare _pwd, _atype varchar;
      _atype := lower (get_keyword ('authtype', auth, 'unknown'));
      if (_atype = 'basic')
        _pwd := get_keyword ('pass', auth, '');
      else
    _pwd := auth;
      _atype := sprintf ('<http_%s>', _atype);
      rc := DB.DBA.DBEV_LOGIN (_su_name, _pwd, _atype);
    }
  if (rc = 0 or '' = _username) /* PLLH_INVALID, must reject */
    {
      _reason := '. PLLH_INVALID';
      goto auth_get;
    }
  if (rc = 1) /* PLLH_VALID, authentication is already done */
    {
      return _u_id;
    }
  /* rc = -1 PLLH_NO_AUTH, should check */
  if (1 = http_auth_verify (auth, _username,
       get_keyword ('realm', auth, ''),
       get_keyword ('uri', auth, ''),
       get_keyword ('nonce', auth, ''),
       get_keyword ('nc', auth, ''),
       get_keyword ('cnonce', auth, ''),
       get_keyword ('qop', auth, ''),
       _su_password))
    {
      return _u_id;
    }
  _reason := '. The password provided by your browser is not valid';
  goto auth_get;    
   --dbg_obj_print ('_su_name', _su_name);
badname: ;
   _reason := '. The name provided by your browser does not exists';
   --dbg_obj_print ('_username', _username);
auth_get: ;
  DB.DBA.vsp_auth_get ('wiki', concat('/', aref (path, 0)),
        md5 (datestring (now ())),
        md5 (sprintf('RunTogetherCapitalizedWordsToFormWikiWord %s', aref (path, 0))),
        'false', lines, 1);
  VspReportFailedAuth (path, params, lines);
  return 0;
}
;

create procedure WV.WIKI.VSPCHECKDAVAUTH (
  inout path any, inout params any, inout lines any,
  in all_dav_acct integer := 0 )
{
  declare _su_name, _su_password varchar;
  declare _su_id, _u_id integer;

  declare auth any;
  declare _username, domain varchar;
  declare ses_dta any;

  domain := http_path ();
  if (domain like '/DAV/wikiview/%')
    domain := '/DAV/wikiview';
  else if (domain like '/wikiview/%')
    domain := '/wikiview';
  else
    domain := '/DAV';

  auth := DB.DBA.vsp_auth_vec (lines);

  if (0 = auth)
    goto auth_get;

  _username := get_keyword ('username', auth, '');
  if ('' = _username)
    goto auth_get;

  whenever not found goto badname;
  select su.U_NAME, su.U_PASSWORD, su.U_ID, u.UserId
  into _su_name, _su_password, _su_id, _u_id
  from DB.DBA.SYS_USERS as su inner join WV.WIKI.USERS as u on su.U_ID = u.UserId
--  where (u.UserName = _username or su.U_NAME = _username) and su.U_ACCOUNT_DISABLED = 0 and U_DAV_ENABLE = 1;
  where u.UserName = _username and su.U_ACCOUNT_DISABLED = 0 and su.U_DAV_ENABLE = 1;

  if (1 = http_auth_verify (auth, _username,
                get_keyword ('realm', auth, ''),
                get_keyword ('uri', auth, ''),
                get_keyword ('nonce', auth, ''),
                get_keyword ('nc', auth, ''),
                get_keyword ('cnonce', auth, ''),
                get_keyword ('qop', auth, ''),
                _su_password))
    {
      connection_set ('DAVUserID', _u_id);
      return _u_id;
    }
 badname:
    --dbg_obj_print ('_usernam', _username); 
   ;
 auth_get:
  DB.DBA.vsp_auth_get ('wiki (use your WikiName or name WikiGuest with empty password)', '/DAV/wiki',
        md5 (datestring (now ())),
        md5 ('RunTogetherCapitalizedWordsToFormWikiWord /DAV/wiki'),
        'false', lines, 1);
  VspReportFailedAuth (path, params, lines);
  return 0;
}
;

create procedure WV.WIKI.VSPREPORTFAILEDAUTH (
  inout path any, inout params any, inout lines any )
{
  http_request_status ('HTTP/1.1 401 Unauthorized');
  WV.WIKI.VSPERRORBASE (path,params,lines, 'Authorization failed. To continue, please provide correct user name and password.',
  '<UL>
    <LI>Are you entering your login name? (Note that your WikiName will not work)</LI>
    <LI>Are there any typos in name or password?</LI>
    <LI>Is the "Caps Lock" switched on?</LI>
    <LI>If your keyboard is multilingual, is it in correct mode?</LI>
   </UL>'
  );
}
;

create procedure WV.WIKI.VSPREPORTBADCLUSTERNAME (
  inout path any, inout params any, inout lines any, in _cluster varchar )
{
  declare _page, _clu, _lname, _att, _badjust varchar;
  declare _main_ref varchar;
  WV.WIKI.VSPDECODEWIKIPATH (path, _page, _clu, _lname, _att, _badjust);
  http_request_status ('HTTP/1.1 404 Resource not found');
  _main_ref := concat (_page, '/', registry_get ('WikiV %MAINCLUSTER%'), '/', registry_get ('WikiV %HOMETOPIC%'));
  WV.WIKI.VSPERRORBASE (path,params,lines, concat ('There is no "', _cluster, '" cluster on this WikiV site.'),
    concat (
  '<UL>
    <LI>You can return to the topic you come from: press <B>Back</B> button of your browser.</LI>
    <LI>The <a href="', _main_ref, '">main starting page</a> may contain links to topics you need.</LI>
   </UL>'
  ) );
}
;

create procedure WV.WIKI.VSPREPORTBADTOPICNAME (
  inout path any, inout params any, inout lines any, in _cluster varchar, in _local_name varchar )
{
  declare _page, _clu, _lname, _att, _badjust varchar;
  declare _home_ref varchar;
  WV.WIKI.VSPDECODEWIKIPATH (path, _page, _clu, _lname, _att, _badjust);
  http_request_status ('HTTP/1.1 404 Resource not found');
  _home_ref := concat (_page, '/', _cluster, '/', registry_get ('WikiV %HOMETOPIC%'));
  WV.WIKI.VSPERRORBASE (path,params,lines, concat ('There is no "', _cluster, '.', _local_name, '" topic on this WikiV site.'),
    concat (
  '<UL>
    <LI>You can return to the page you come from: press <B>Back</B> button of your browser.</LI>
    <LI>The <a href="', _home_ref, '">starting page of the "', _cluster, '" cluster</a> may contain links to topics you need.</LI>
   </UL>'
  ) );
}
;

create procedure WV.WIKI.VSPREPORTFAILEDREADACCESS (
  inout path any, inout params any, inout lines any,
  in _cluster varchar, in _local_name varchar, in _attach varchar )
{
  declare _page, _clu, _lname, _att, _badjust varchar;
  declare _ref varchar;
  WV.WIKI.VSPDECODEWIKIPATH (path, _page, _clu, _lname, _att, _badjust);
  http_request_status ('HTTP/1.1 403 Forbidden');
  _ref := sprintf ('command=relogin&rnd=%d', rnd(1000000000));
  if ('' <> get_keyword ('topic_id', params, ''))
    _ref := concat ('topic_id=', get_keyword ('topic_id', params, ''), '&', _ref);
  if ('' <> get_keyword ('title', params, ''))
    _ref := concat ('title=', get_keyword ('title', params, ''), '&', _ref);
  _ref := concat (_page, '/', _cluster, '/', _local_name, _attach, '?', _ref);
  WV.WIKI.VSPERRORBASE (path,params,lines, 'Access to the resource is forbidden.',
  concat (
  '<UL>
    <LI>You can return to the topic you come from: press <B>Back</B> button of your browser</LI>
    <LI>You can <a href="', _ref, '">re-login</a> using more suitable user name</LI>
    <LI>You can ask the owner of the resource to grant you the right of read access and press <B>Reload</B> button of your browser when granted.</LI>
   </UL>'
  ) );
}
;

create procedure WV.WIKI.VSPNYI (
  inout path any, inout params any, inout lines any )
{
  http_request_status ('HTTP/1.1 500 Internal server error');
  WV.WIKI.VSPERRORBASE (path,params,lines, 'This feature is not yet implemented.','');
}
;

create procedure  WV.WIKI.GETCMDTITLE (inout params any)
{
  declare _cmd_title varchar;
  _cmd_title := get_keyword ('command', params);
  if (_cmd_title like '%attach')
   return ' | Attachments';
  else if (_cmd_title = 'mops')
   return ' | More Actions on Topic';
  else if (_cmd_title = 'edit')
   return ' | Edit';
  else if (_cmd_title = 'preview' and get_keyword ('Cancel', params) is null)
   return ' | Preview';
  else if (_cmd_title = 'refby')
   return ' | Ref-by';
  else if (_cmd_title = 'index')
   return ' | Index';
  return '';
}
;
  
create function WV.WIKI.HEADER_KUPU_PATH (in res varchar, in _base_adjust varchar)
{
  return  WV.WIKI.RESOURCEPATH ('kupu/common/' || res, _base_adjust);
}
;

create function WV.WIKI.HEADER_KUPU_SCRIPT (in script_name varchar)
{
  return '<script type="text/javascript" src="' || WV.WIKI.HEADER_KUPU_PATH (script_name, connection_get ('WIKIV BaseAdjust')) || '"></script>';
}
;

create procedure WV.WIKI.VSPHEADER (
  inout path any,
  inout params any,
  inout lines any,
  in topic_or_title any,
  in _base_adjust varchar := '')
{
  if (get_keyword ('xmlraw', params) is not null)
    return;

  declare add_kupu_headers int;
  declare _topic WV.WIKI.TOPICINFO;
  declare _skin, _topic_title varchar;
  if (get_keyword ('mode', params) = 'js')
    add_kupu_headers := 1;
  else
    add_kupu_headers := 0;
  if (isstring (topic_or_title))
    {      
      _skin := 'default';
      _topic_title := topic_or_title;
    }
  else
    {
      _topic := topic_or_title;
      _skin := WV.WIKI.CLUSTERPARAM ( _topic.ti_cluster_id , 'skin', 'default');
      _topic_title := _topic.ti_raw_title;
    }
--  http ('<!DOCTYPE HTML PUBLIC "-//IETF//DTD HTML 2.0//EN">');
--  http ('<html xmlns="http://www.w3.org/1999/xhtml" xmlns:i18n="http://xml.zope.org/namespaces/i18n" i18n:domain="kupu"><head>');
  http ('<html><head>');
  http ('<title>oWiki | ');
  http (_topic_title || WV.WIKI.GETCMDTITLE (params));
  http ('</title>');
  http ('<link rel="stylesheet" href="' || WV.WIKI.SKINCSS (_skin, _base_adjust) || '" type="text/css"></link>');

  if (add_kupu_headers)
    {
	http('<link rel="stylesheet" href="' || WV.WIKI.HEADER_KUPU_PATH ('kupustyles.css', _base_adjust) ||'" type="text/css"></link>');
	http('<link rel="stylesheet" href="' || WV.WIKI.HEADER_KUPU_PATH ('kupudrawerstyles.css', _base_adjust) ||'" type="text/css"></link>');
    }
  declare _server_base varchar;
  if (isstring (topic_or_title))
    {
      _server_base := '';
      http ('<link rel="alternate" type="application/rss+xml" title="Changelog (RSS 2.0)" href="' || _server_base || 'gems.vsp?&amp;type=rss20"></link>\n');
      http ('<link rel="alternate" type="application/rss+xml" title="Changelog (ATOM)" href="' || _server_base || 'gems.vsp?&amp;type=atom"></link>\n');
      http ('<link rel="alternate" type="application/rss+xml" title="Changelog (RDF)" href="' || _server_base || 'gems.vsp?&amp;type=rdf"></link>\n');
      http ('<link rel="alternate" type="application/rss+xml" title="Changelog (WIKI_PROFILE)" href="' || _server_base || 'gems.vsp?&amp;type=wiki_profile"></link>\n');
    }
  else if (_topic.ti_id > 0)
    {
      _server_base := _base_adjust || '../resources/';
      http ('<link rel="alternate" type="application/rss+xml" title="Changelog (RSS 2.0)" href="' || _server_base || 'gems.vsp?cluster=' || _topic.ti_cluster_name || '&amp;type=rss20"></link>\n');
      http ('<link rel="alternate" type="application/rss+xml" title="Changelog (ATOM)" href="' || _server_base || 'gems.vsp?cluster=' || _topic.ti_cluster_name || '&amp;type=atom"></link>\n');
      http ('<link rel="alternate" type="application/rss+xml" title="Changelog (RDF)" href="' || _server_base || 'gems.vsp?cluster=' || _topic.ti_cluster_name || '&amp;type=rdf"></link>\n');
      http ('<link rel="alternate" type="application/rss+xml" title="Changelog (WIKI_PROFILE)" href="' || _server_base || 'gems.vsp?cluster=' || _topic.ti_cluster_name || '&amp;type=wiki_profile"></link>\n');
    }
  if (topic_or_title = 'Settings') {
    http ('<script type="text/javascript">\n');
    http ('  // OAT\n');
    http ('  var toolkitPath="/ods/oat";\n');
    http ('  var featureList=["dialog"];\n');
    http ('</script>\n');
    http ('<script type="text/javascript" src="/ods/oat/loader.js"></script>\n');
    http ('<script type="text/javascript">\n');
    http (' 	var showInfo;\n');
    http (' 	function myInit ()\n');
    http (' 	{\n');
    http (' 	  showInfo = new OAT.Dialog("Secondary Skin", "infoDiv", {width:400, modal:1, buttons:0});\n');
    http (' 	}\n');
    http (' 	OAT.MSG.attach(OAT,OAT.MSG.OAT_LOAD,myInit);\n');
    http ('</script>\n');
  }
  if (add_kupu_headers)
    {
      declare scripts any;
      scripts := vector (
	'sarissa.js', 
	'sarissa_ieemu_xpath.js', 
	'kupuhelpers.js', 
	'kupueditor.js',
	'kupubasetools.js',
	'kupuloggers.js',
	'kupunoi18n.js',
	'../../i18n.js/i18n.js',
	'kupucleanupexpressions.js',
	'kupucontentfilters.js',
	'kuputoolcollapser.js',
	'kupucontextmenu.js',
	'kupuinit_form.js',
	'kupustart_form.js',
	'kupusourceedit.js',
	'kupuspellchecker.js',
	'kupudrawers.js');
      http (
	WV.WIKI.STRJOIN ('\n', WV.WIKI.MAP ('WV.WIKI.HEADER_KUPU_SCRIPT', scripts)));
      http ('</head>');
      http ('<body onload="kupu = startKupu()">');
    }
  else
    {
      http ('</head>');
      http ('<body>');
    }
}
;

create procedure WV.WIKI.VSPFOOTER (
  inout path any, inout params any, inout lines any)
{
  if (get_keyword ('xmlraw', params) is null)
    http ('</body></html>');
}
;

create function WV.WIKI.VSPERRORBASE (
  inout path any, inout params any, inout lines any,
  in _title varchar, in _details varchar ) returns varchar
{
  declare _case_id integer;
  declare _pageargs varchar;
  _case_id := sequence_next('WikiV_LogId');
  http_rewrite(0);
--  http (concat ('<XMP>', _title ,'</XMP>', _details));
--  return;
  WV.WIKI.VSPHEADER (path,params,lines, 'Error');
  http_value (_title,'H3');
  http (_details);
  http ( concat ('
<BR>
<FONT SIZE=-1>The technical data listed below are for administrator of your WikiV. If you will ask him for help, the <B>magic number ', cast (_case_id as varchar), '</B> can help him to identify your problem, please remember it.'));
  _pageargs := WV.WIKI.VSPREPORTPAGEARGS (path, params, lines);
  http (_pageargs);  
  http ('</FONT>');
  WV.WIKI.VSPFOOTER (path,params,lines);
  return _title;
}
;

create function WV.WIKI.VSPERROR (
  inout path any, inout params any, inout lines any,
  in _message varchar ) returns varchar
{
  return WV.WIKI.VSPERRORBASE (path,params,lines, _message, '');
}
;

create function WV.WIKI.VSPREPORTPAGEARGS (
  inout path any, inout params any, inout lines any )
  returns varchar
{
  declare _ses any;
  declare idx, _idx2, _pos1, _pos2 integer;
  declare _paramname, _val varchar;
  _ses := string_output ();
  http ('<BR>Path to page: { ', _ses);
  idx := 0;
  while (idx < length(path))
    {
      http ('[', _ses);
      http_value (aref (path, idx), 'CODE', _ses);
      http (']', _ses);
      idx := idx + 1;
      if (idx < length (path))
        http(' , ', _ses);
    }
  http (' }<BR>Parameters: { ', _ses);
  idx := 0;
  while (idx < length (params))
    {
      http ('[', _ses);
      _paramname := aref (params, idx);
      http_value (_paramname, 'CODE', _ses);
      idx := idx + 1;
      _val := aref (params, idx);
      if (idx < length (params))
        {
          http ('] = [', _ses);
	  if (_paramname <> 'password')
	    {
	      if (__tag (_val) = 193)
	        {
	          _idx2 := 0;
	          while (_idx2 < length (_val))
	            {
                      if (_idx2 > 0)
                        http (', ', _ses);
                      http_value (aref(_val, _idx2), 'CODE', _ses);
                      _idx2 := _idx2 + 1;
                    }
                }
	      else
	        {
	          if (raw_length (_val) > 160)
	            {
	              http_value (subseq (_val, 0, 160), 'CODE', _ses);
		      http (sprintf ('(%d characters were truncated)', length (_val) - 160), _ses);
	            }
	          else
		    http_value (_val, 'CODE', _ses);
                }
            }
	  else
	    http ('*******', _ses);
	}
      else
        http('] = ??? }');
      idx := idx + 1;
      if (idx < length (params))
        http('] , ', _ses);
      else
        http(']', _ses);
    }
  http (' }<BR>Lines of header:<BR>', _ses);
  idx := 0;
  while (idx < length(lines))
    {
      _val := aref (lines, idx);
      _pos1 := strstr (_val, '&password=');
      if (_pos1 is not null)
        {
	  _pos1 := _pos1+10;
	  _pos2 := strstr (subseq (_val, _pos1), '&');
	  if (_pos2 is null)
	    _pos2 := length (_val);
	  else
	    _pos2 := _pos1 + _pos2;
	  _val := concat (subseq (_val, 0, _pos1), '*******', subseq (_val, _pos2));
	}
      http_value (_val,'CODE', _ses);
      http ('<BR>', _ses);
      idx := idx + 1;
    }
  return string_output_string (_ses);
}
;

create procedure WV.WIKI.VSPTOPICHREFBYID (in _id integer)
{
  declare _topic WV.WIKI.TOPICINFO;
  _topic := WV.WIKI.TOPICINFO();
  _topic.ti_id := _id;
  _topic.ti_find_metadata_by_id();
  if (_topic.ti_local_name <> '')
    http (concat('<A HREF="main.vspx?id=', cast (_id as varchar), '">', _topic.ti_cluster_name, '.', _topic.ti_local_name, '</A>'));
  else
    http (concat('<A HREF="main.vspx?id=', cast (_id as varchar), '"><I>(lost page ', cast (_id as varchar), ')</I></A>'));
}
;

create procedure WV.WIKI.VSPUSERHREFBYID (in _uid integer)
{
  declare _name varchar;
  declare _ptopicid integer;
  whenever not found goto _nf;
  select UserName, PersonalTopicId into _name, _ptopicid from WV.WIKI.USERS where UserId = _uid;
  http (concat('<A HREF="../local/view.vsp?id=', cast (_ptopicid as varchar), '">', _name, '</A>'));
  return;
_nf:
  http (concat('<A HREF="../local/lostuser.vsp?uid=', cast (_uid as varchar), '"><I>(lost user ', cast (_uid as varchar), ')</I></A>'));
}
;

create procedure WV.WIKI.VSPGROUPHREFBYID (in _gid integer)
{
  declare _name varchar;
  declare _bbsid integer;
  whenever not found goto _nf;
  select GroupName, BbsTopicId into _name, _bbsid from WV.WIKI.GROUPS where GroupId = _gid;
  http (concat('<A HREF="../local/view.vsp?id=', cast (_bbsid as varchar), '">', _name, '</A>'));
  return;
_nf:
  http (concat('<A HREF="../local/lostgroup.vsp?gid=', cast (_gid as varchar), '"><I>(lost group ', cast (_gid as varchar), ')</I></A>'));
}
;

create procedure WV.WIKI.VSPUSERADMINHREF (in _uid integer)
{
  declare _name varchar;
  whenever not found goto _nf;
  select UserName into _name from WV.WIKI.USERS where UserId = _uid;
  http (concat('<A HREF="../admin/edituser.vsp?uid=', cast (_uid as varchar), '">', _name, ' (', cast (_uid as varchar), ')</A>'));
  return;
_nf:
  http (concat('<A HREF="../local/lostuser.vsp?uid=', cast (_uid as varchar), '"><I>(lost user ', cast (_uid as varchar), ')</I></A>'));
}
;

create procedure WV.WIKI.VSPGROUPADMINHREF (in _gid integer)
{
  declare _name varchar;
  whenever not found goto _nf;
  select GroupName into _name from WV.WIKI.GROUPS where GroupId = _gid;
  http (concat('<A HREF="../admin/editgroup.vsp?uid=', cast (_gid as varchar), '">', _name, ' (', cast (_gid as varchar), ')</A>'));
  return;
_nf:
  http (concat('<A HREF="../local/lostgroup.vsp?uid=', cast (_gid as varchar), '"><I>(lost group ', cast (_gid as varchar), ')</I></A>'));
}
;

create function WV.WIKI.REGEXP_FOR_LPATH (in lpath varchar)
{
  if (lpath <> '/')
    return '^' || lpath || '(/|\$)';
  else
    return '^/';
}
;

create function WV.WIKI.LPATH_OFFSET (in lpath varchar)
{
  if (lpath = '/')
    return 0;
  return length (split_and_decode (lpath, 0, '\0\0/')) - 1;
}
;
    

--! decodes /wiki/Atom/<topicid>/.. 
create procedure WV.WIKI.ATOMDECODEWIKIPATH (out _topicid int, out _cluster varchar)
{
  declare path any;
  path := http_path ();
  path := subseq(split_and_decode(aref (WS.WS.PARSE_URI(path), 2), 0, '\0\0/'), 1);
  if (path[0] = 'dataspace' and length (path) > 3)
    {
      _cluster := path[3];
      _topicid := 0;
      return 0;
    }
  declare _host varchar;
  _host := DB.DBA.WA_GET_HOST();
	  
  declare domain varchar;
  domain := http_map_get ('domain');
  declare full_path, pattern varchar;
  full_path := _host || '/' || WV.WIKI.STRJOIN ('/', path);
  
  declare _cluster_id int;
whenever not found goto nf;
  select DP_CLUSTER into _cluster_id from WV.WIKI.DOMAIN_PATTERN_1 where domain like DP_PATTERN and _host like DP_HOST;
  if (0)
    {
nf:
       path := subseq (path, 1);
         
    }
  else
    path := subseq (path, (length (split_and_decode (domain, 0, '\0\0/')) - 2));
  if (path[0] = 'Atom') 
    {
      _cluster := null;
      if (length (path) > 1)
        _cluster := path[1];       
      if (length (path) > 2)
        _topicid := coalesce ((select TOPICID from WV.WIKI.TOPIC natural join WV.WIKI.CLUSTERS where CLUSTERNAME = _cluster and LOCALNAME = path[2]), 0);
      return;
    }
  _topicid := 0;
  _cluster := null;
  return 0;

}
;

--! \return "details" vector - dictionary of additional parameters
create procedure WV.WIKI.VSPDECODEWIKIPATH (in path any, out _page varchar, out _cluster varchar, out _local_name varchar, out _attach varchar, out _base_adjust varchar, in lines any)
{
  declare _startofs integer;
  declare _idx integer;
  path := http_path ();
  path := split_and_decode(aref (WS.WS.PARSE_URI(path), 2), 0, '\0\0/');
  declare _host varchar;
  _host := DB.DBA.WA_GET_HOST();
	  
  _cluster := NULL;
  _attach := NULL;
  _local_name := NULL;
  declare default_cluster varchar;
  default_cluster := 'Main';

  declare domain varchar;
  domain := http_map_get ('domain');
  declare cluster_id int;
  declare full_path, pattern varchar;
  full_path := _host || '/' || WV.WIKI.STRJOIN ('/', path);
  _base_adjust := '';


whenever not found goto nf;

  select DP_CLUSTER, DP_PATTERN into cluster_id, pattern  from WV.WIKI.DOMAIN_PATTERN_1 where domain = DP_PATTERN and _host like DP_HOST;
      default_cluster := (select ClusterName from WV.WIKI.CLUSTERS where ClusterId = cluster_id);
  declare _domain_length int;
  if (domain = '/')
    _domain_length := 1;
  else
    _domain_length := length (split_and_decode (domain, 0, '\0\0/'));
  path := subseq (path, _domain_length);
  if (domain = '/')
    _base_adjust := '/';
  else
    _base_adjust := default_cluster || '/';
  if (0)
    {
nf:
      declare _jpath varchar;
      _jpath := WV.WIKI.STRJOIN ('/', path);
      if (_jpath = 'wiki/main')
         {
           _base_adjust := 'main/';
           _startofs := 2;
           goto next2;
         }
--      dbg_obj_princ (_jpath);
      if ( (_jpath not like 'wiki/main/%') and
	   (_jpath <>  'wiki/Atom/') )
        WV.WIKI.APPSIGNAL (11002, 'Path &url; to resource must start from "/wiki/main/"', vector('url', http_path()));
      path := subseq (path, 2);     
    }
whenever not found default;
  _startofs := 0;
  if (_startofs < length (path))
    {
      _base_adjust := '';
      _cluster := path[_startofs];
      _startofs := _startofs + 1;
    }
  if (_startofs < length (path))
    {
      _base_adjust := '../';
      _local_name := path[_startofs];
      _startofs := _startofs + 1;
    }
next2:
  if (_cluster is null or _cluster = '' or _cluster = 'main.vsp')
    _cluster := default_cluster;
  if ((WV.WIKI.CLUSTERPARAM(default_cluster, 'qwiki', 2) = 1) and _cluster <> default_cluster)
    _cluster := default_cluster;
      
  if ( (select 1 from WV..CLUSTERS where ClusterName = _cluster) is null) 
    {
      _cluster := default_cluster; _local_name := WV.WIKI.CLUSTERPARAM (_cluster, 'index-page', 'WelcomeVisitors');
      declare idx int; 
      for (idx:=length (path); idx > 2; idx:=idx-1)
	_base_adjust := _base_adjust || '../';
      goto cont;
    }
  if (_local_name is null or _local_name = '')
    _local_name := WV.WIKI.CLUSTERPARAM (_cluster, 'index-page', 'WelcomeVisitors');
  _idx := _startofs;
  while (_idx < length (path))
    {
      _attach := coalesce (_attach, '');
      _attach := concat (_attach, '/', aref (path, _idx));
      _idx := _idx + 1;
    }
  declare _primary_skin, _second_skin varchar;
cont:
  if (_cluster is not null)
    _primary_skin := WV.WIKI.CLUSTERPARAM ( _cluster , 'skin', 'default' );
  _second_skin := null;
  declare skin2_regexp varchar;
  skin2_regexp := WV.WIKI.CLUSTERPARAM ( _cluster, 'skin2-vhost-regexp', null);
whenever sqlstate '2201B' goto next;
  if (skin2_regexp is not null and
      regexp_match (skin2_regexp, _host) is not null)
    _second_skin := WV.WIKI.CLUSTERPARAM ( _cluster , 'skin2', 'default');  
next: 
  return vector ('skin', _primary_skin,
  	 	 'skin2', _second_skin);
}
;


--| fills appropriate arguments with normalised values from |params|
create procedure WV.WIKI.VSPDECODEWIKIPATH2 (
	inout params any, 
	out _cluster varchar, --| default cluster if not specified
	out _local_name varchar, --| default topic name if not specified
	out _attach varchar, --| name of attachment if specified
	in lines any)
{
  declare raw_name varchar;
  raw_name := get_keyword ('topic', params);
  _local_name := '';
  if (raw_name is null)
    {
      declare _host varchar;
      _host := http_request_header(lines, 'Host', null, '*ini*');
      --dbg_obj_print (_host, path);
      _cluster := 'Main';
      if (_host is not null)
	{
	  for select VH_INST, VH_LPATH from WA_VIRTUAL_HOSTS
		       where regexp_match (WV.WIKI.REGEXP_FOR_LPATH(VH_LPATH), http_path()) is not null
          do {
	    --dbg_obj_print ('checking inst:', VH_INST, VH_LPATH);
	    declare inst DB.DBA.web_app;
	    inst := (select WAI_INST from DB.DBA.WA_INSTANCE where WAI_ID = VH_INST and WAI_TYPE_NAME = 'oWiki');
	    if (inst is not null)
	      {
		_attach := null;
		_cluster := (select ClusterName from WV.WIKI.CLUSTERS where ClusterId = (inst as wa_wikiv).cluster_id);
	      }
	  }
	}
    }
  else
    {
      declare _topic WV.WIKI.TOPICINFO;
      _topic := WV.WIKI.TOPICINFO ();
      _topic.ti_raw_name := raw_name;
      _topic.ti_default_cluster := 'Main';
      _topic.ti_parse_raw_name ();
      _cluster := _topic.ti_cluster_name;
      _local_name := _topic.ti_local_name;
    }
  if (_local_name = '')
    _local_name := WV.WIKI.CLUSTERPARAM (_cluster, 'index-page', 'WelcomeVisitors');
  _attach := get_keyword ('att', params);
  if (_attach is not null and
      _attach[0] = 47) --| 47 == '/'
    _attach := subseq (_attach, 1);		      
}
;

create procedure WV.WIKI.TESTVSPDECODEWIKIPATH (in path any)
{
  declare _page, _cluster, _local_name, _attach, _base_adjust varchar;
  WV.WIKI.VSPDECODEWIKIPATH (path, _page, _cluster, _local_name, _attach, _base_adjust);
  result_names (_page, _cluster, _local_name, _attach, _base_adjust);
  result (_page, _cluster, _local_name, _attach, _base_adjust);
}
;

create function WV.WIKI.VSPTOPICATTACH (
  inout path any, inout lines any,
  inout _topic WV.WIKI.TOPICINFO,
  in params any)
  returns varchar
{
  declare _uid integer;
  declare _base_adjust varchar;
  _uid := get_keyword ('uid', params);
  _base_adjust := get_keyword ('baseadjust', params);
  declare _text varchar;
  WV.WIKI.CHECKWRITEACCESS (_uid, _topic.ti_res_id, _topic.ti_cluster_id, _topic.ti_col_id, 'Owner of this cluster does not allow you to attach any files');

  declare _ext_params any;
  _ext_params := _topic.ti_xslt_vector (params); 
  http_value (
     WV.WIKI.VSPXSLT ( 'VspTopicAttach.xslt',
      _topic.ti_report_attachments(),
      _ext_params));
}
;


create procedure WV.WIKI.VSPATTACHMENTVIEW (
  in _uid integer, 
  in _topic_id integer,
  in _attachment_name varchar)
{
  declare _topic WV.WIKI.TOPICINFO;
  declare _text varchar;
  _topic := WV.WIKI.TOPICINFO ();
  _topic.ti_id := _topic_id;
  _topic.ti_find_metadata_by_id ();

  declare _attachment_id, _attachment_id_2 int;

  _attachment_id := coalesce ((select COL_ID from WS.WS.SYS_DAV_COL where COL_PARENT = _topic.ti_col_id and COL_NAME = _topic.ti_local_name), 0);
  _attachment_id_2 := coalesce ((select COL_ID from WS.WS.SYS_DAV_COL where COL_PARENT = _topic.ti_col_id and COL_NAME = _topic.ti_local_name_2), _attachment_id);

  if (_attachment_name[0] = 47)
   _attachment_name := subseq (_attachment_name, 1);
  http_rewrite ();
  http_header ('Content-Type: ' 
	|| xml_uri_get ('virt://WS.WS.SYS_DAV_RES.RES_FULL_PATH.RES_TYPE:' || WS.WS.COL_PATH (_attachment_id_2),  _attachment_name) 
	|| '\r\n');
  http (xml_uri_get ('virt://WS.WS.SYS_DAV_RES.RES_FULL_PATH.RES_CONTENT:' || WS.WS.COL_PATH (_attachment_id_2),  _attachment_name));
}
;


create procedure WV.WIKI.VSPDELETECONFIRM(
  inout path any, inout lines any,
  in _topic WV.WIKI.TOPICINFO, 
  in _attachment varchar,
  in _xslt_params any)
{
  http_value (
     WV.WIKI.VSPXSLT ( 'VspAttachmentDeleteConfirm.xslt',                                                 xtree_doc ('<a/>'),
      vector_concat (_topic.ti_xslt_vector(_xslt_params), vector ('attachment', _attachment) )));
}
;

create procedure WV.WIKI.RAWTITLEFROMDAV (in davname varchar)
{
  declare vv any;
  declare idx int;
  declare name varchar;
  name := '';
  if (subseq (davname, length(davname)-4) = '.txt')
    davname:=subseq (davname, 0, length(davname)-4);
  vv := split_and_decode (davname, 0, '\0\0/');
  idx := 4;
  while (idx < length (vv)) {
    name := name || '.' || aref (vv, idx);
    idx := idx + 1;
  }
  return subseq (name, 1);
}
;

create procedure WV.WIKI.GETDAVAUTH (inout _auth varchar, inout _pwd varchar)
{
  select U_NAME, pwd_magic_calc(U_NAME, U_PASSWORD, 1) 
  	into _auth, _pwd
    from DB.DBA.SYS_USERS
    where U_ID = http_dav_uid ();
}
;

create procedure WV.WIKI.GETDOC (in _path varchar)
{
  declare content, type varchar;
  declare _auth, _pwd varchar;
  WV.WIKI.GETDAVAUTH (_auth, _pwd);  
  if (0 < DB.DBA.DAV_RES_CONTENT (_path, content, type, _auth, _pwd))
    {
      if (type = 'plain/xml')
        return xtree_doc (content);
      return content;
    }
  return NULL;
}
;
   
create procedure WV.WIKI.USER_WIKI_NAME_BY_NAME (in name varchar)
{
  declare _id int;
  select U_ID into _id from DB.DBA.SYS_USERS where U_NAME = name;
  return 'Main.' || WV.WIKI.USER_WIKI_NAME_2 (_id);
}
;
   
create procedure WV.WIKI.CHANGELOG (inout _skip integer, inout _rows integer, in _cluster_name varchar:= null)
{    
  return xtree_doc (WV..RSS(_cluster_name, 'rss20'));
}
;

create procedure WV.WIKI.DOCCHILDSANDPARENTS (in cluster_id int, in topic_id int)
{
  declare doc,ent any;
  doc := xtree_doc ('<DocChildAndParents><Childs/><PossibleParents/></DocChildAndParents>');
  ent := xpath_eval ('/DocChildAndParents/Childs', doc);
  
  for select DestClusterName, DestLocalName from WV.WIKI.LINK
	       where OrigId = topic_id
  do {
    XMLAppendChildren (ent, XMLELEMENT ('Child',
					XMLATTRIBUTES (DestClusterName as ClusterName,
						       DestLocalName as LocalName)));
  }
  ent := xpath_eval ('/DocChildAndParents/PossibleParents', doc);
  for select TopicId, LocalName as name, c.ClusterName as cl_name
	       from WV.WIKI.TOPIC t,
	         WV.WIKI.CLUSTERS c
	       where
	         c.ClusterId = t.ClusterId
		 and c.ClusterId = cluster_id
		 and LocalName <> 'ClusterSummary'
    
  do {
    XMLAppendChildren (ent, XMLELEMENT ('PossibleParent',
					XMLATTRIBUTES (name as LocalName,
						       cl_name as ClusterName,
						       TopicId as Id)));
  }
  return doc;
}
;

create procedure WV.WIKI.DOCCLUSTERS ()
{
  declare _doc, _ent any;
  _ent := xpath_eval ('/Clusters', _doc := xtree_doc ('<Clusters/>'));
  
  for select ClusterId, ClusterName from WV.WIKI.CLUSTERS
  do {
    XMLAppendChildren (_ent, XMLELEMENT ('Cluster',
					 XMLATTRIBUTES (ClusterId as Id,
							ClusterName as Name)));
  }
  return _doc;
}
;
  
create procedure WV.Wiki.check_grants (in user_name  varchar, in role_name varchar) {
  declare user_id, group_id, role_id, sql_enabled, dav_enabled integer;
  whenever not found goto nf;
  if (user_name='') return 0;
  select U_ID, U_GROUP into user_id, group_id from SYS_USERS where U_NAME=user_name;
  if (user_id = 0 OR group_id = 0)
    return 1;
  if (role_name is null or role_name = '')
    return 0;

  select U_ID into role_id from SYS_USERS where U_NAME=role_name;
  if (exists(select 1 from SYS_ROLE_GRANTS where GI_SUPER=user_id and GI_SUB=role_id))
      return 1;
nf:
  return 0;
}
;


create function WV.WIKI.DATEFORMAT (in dt datetime, in _type varchar:=NULL) returns varchar
{
  if (_type is null)
    return aref (split_and_decode (cast (dt as varchar), 0, '\0\0.'), 0);
  else if (_type = 'TWiki')
    {
      declare _months any;
      _months := vector ('Jav', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec');
      return sprintf ('%02ld %s %ld', dayofmonth (dt), _months[month (dt)-1], year(dt));
    }
  else if (_type = 'rfc1123')
    return soap_print_box (dt, '', 1);
  else if (_type = 'iso8601')
    return soap_print_box (dt, '', 0);
}
;

create function WV.WIKI.VSPMAILVIEW (
  inout path any, inout lines any,
  in _topic WV.WIKI.TOPICINFO,
  in _user_id integer,
  in _mail_id integer,
  in params any)
{
  declare _text varchar;
  declare _uid integer;
  declare _base_adjust varchar;
  _uid := get_keyword ('uid', params);
  _base_adjust := get_keyword ('baseadjust', params);

  declare message any;	
  message := OMAIL.WA.omail_get_message (1, _user_id, _mail_id, 1);

  declare _doc any;
  _doc := XMLELEMENT ('Mail', XMLATTRIBUTES (
					     get_keyword ('rcv_date', message) as "Date",
					     get_keyword ('subject', message) as "Subject"),
		      xtree_doc (serialize_to_UTF8_xml (get_keyword ('address', message))),
		      XMLELEMENT ('Header', 
				  get_keyword ('header', message)),
		      XMLELEMENT ('Message',
				  get_keyword ('message', message)));
  declare _ext_params any;
  _ext_params := _topic.ti_xslt_vector (params); 

  http_value (
    WV.WIKI.VSPXSLT ('PostProcess.xslt',
    WV.WIKI.VSPXSLT ( 'VspMail.xslt',
      _doc,
      _ext_params),
    _ext_params, WV.WIKI.CLUSTERPARAM ( _topic.ti_cluster_id , 'skin', 'default' )));

}
;

create function WV.WIKI.TOPICNAME (in res_id int) returns varchar
{
  declare _topic WV.WIKI.TOPICINFO;
  _topic := WV.WIKI.TOPICINFO ();
  _topic.ti_id := (select TopicId from WV.WIKI.TOPIC where ResId = res_id);
  _topic.ti_find_metadata_by_id ();
  return _topic.ti_cluster_name || '.' || _topic.ti_local_name;	
}
;

create function WV.WIKI.RSSMAKEPASTSIMPLE (in action varchar)
{
    return 'has ' || lcase (action) ;
}
;
create function WV.WIKI.RSSMAKEPASSPASTSIMPLE (in action varchar)
{
    return 'has been ' || lcase (action) ;
}
;
      

create function WV.WIKI.RSSMAKEHEADLINE (in cluster_name varchar, 
	in topic_name varchar, in action varchar, in who varchar, in context varchar, in rev_id int)
{
  return cluster_name || '.' || topic_name || ' ' ||  WV.WIKI.RSSMAKEPASSPASTSIMPLE (action) || ' by ' || who || ' (1.' || cast (rev_id as varchar) || ')';
}
;

create function WV.WIKI.RSSMAKECONTENT (in cluster_name varchar,
	in topic_name varchar, in action varchar, in who varchar, in context varchar, in rev_id int, in base varchar)
{
  declare rev, prevrev varchar;
  rev := cast (rev_id as varchar);
  prevrev := cast (case when rev_id = 0 then 0 else rev_id - 1 end as varchar);

  declare _res varchar;
  _res := '<p>' || who || ' ' ||  WV.WIKI.RSSMAKEPASTSIMPLE (action) || ' node ' || topic_name || ', now at revision 1.' || rev;
  if (rev <> '1')
    _res := _res || '<br/> View the <a href="' || base || 'wiki/main/' || WV.WIKI.READONLYWIKIWORDLINK (cluster_name, topic_name) || '?command=diff&rev=' || prevrev || '"> difference </a>';
  _res := _res || '</p>';
  declare ss any;
  ss := string_output ();
  http_value (_res, null, ss);
  return string_output_string (ss);
}
;


create function WV.WIKI.SIDURLPART (in sid varchar, in realm varchar)
{
  if (sid is not null)
    return sprintf ('sid=%s&realm=%s', sid, realm);
  else
    return '';
}
;


create function WV.WIKI.GET_QHOST (in hostname varchar, in portname varchar)
{
  if (portname <> '80')
    return hostname || ':' || portname;
  return hostname;
}
;

-- stolen from Blog2
create function WV.WIKI.GET_HOST ()
{
  declare ret varchar;
  if (is_http_ctx ())
    {
      ret := http_request_header (http_request_header (), 'Host', null, sys_connected_server_address ());
      if (isstring (ret) and strchr (ret, ':') is null)
        {
          declare hp varchar;
          declare hpa any;
          hp := sys_connected_server_address ();
          hpa := split_and_decode (hp, 0, '\0\0:');
          ret := WV.WIKI.GET_QHOST (ret, hpa[1]);
        }
    }
  else
   {
     ret := sys_connected_server_address ();
     if (ret is null)
       ret := WV.WIKI.GET_QHOST (sys_stat ('st_host_name'),server_http_port ());
   }

  return ret;
}
;


create function WV.WIKI.MAKEHREFFROMRES (in res_id int, in res_name varchar, in sid varchar, in realm varchar, in _base varchar := '/')
{
  declare _clusterPath varchar;
  declare _topic WV.WIKI.TOPICINFO;

  _topic := WV.WIKI.TOPICINFO ();
  _topic.ti_id := (select TopicId from WV.WIKI.TOPIC where ResId = res_id);
  if (_topic.ti_id is null)
    return null;
  _topic.ti_find_metadata_by_id ();
  _topic.ti_fill_cluster_by_id ();
  _clusterPath := WV.WIKI.CLUSTERPARAM (_topic.ti_cluster_name, 'home');
  return sprintf ('<a href="http://%s/%s/%U/%U?%s">%s.%s</a>', WV.WIKI.GET_HOST(), _clusterPath, _topic.ti_cluster_name, _topic.ti_local_name,  WV.WIKI.SIDURLPART (sid, realm), _topic.ti_cluster_name, _topic.ti_local_name);
}
;

create function WV.WIKI.MAKELINKFROMRES (in res_id int, in _base varchar)
{
  declare _topic WV.WIKI.TOPICINFO;
  _topic := WV.WIKI.TOPICINFO ();
  _topic.ti_id := (select TopicId from WV.WIKI.TOPIC where ResId = res_id);
  if (_topic.ti_id is null)
    return null;
  _topic.ti_find_metadata_by_id ();
  _topic.ti_fill_cluster_by_id ();
  return sprintf ('../main/%U/%U', _topic.ti_cluster_name, _topic.ti_local_name);
}
;


create procedure WV.Wiki.sql_user_password_check (in name varchar, in pass varchar)
{
  declare gid, uid int;
  whenever not found goto nf;
  select U_ID, U_GROUP into uid, gid from SYS_USERS
      where U_NAME = name and U_DAV_ENABLE = 1 and U_IS_ROLE = 0 and pwd_magic_calc(U_NAME, U_PASSWORD, 1) = pass;
  return 1;
  nf:
  return 0;
}
;

create procedure WV.WIKI.MAKE_PARAMS (
  in _user varchar, 
  in _uid int,
  in _params any, 
  in _base_adjust varchar)
{
   declare vv any;
   vv := vector (
   	'user', _user,
	'wikiuser', WV.WIKI.USER_WIKI_NAME_X(_user), 
   	'uid', _uid,
	'rnd', rand (999999999),
	'st_dbms_ver', sys_stat('st_dbms_ver'),
	'st_build_date', sys_stat('st_build_date'));
   if (_base_adjust is not null)
    vv := vector_concat (vv,  vector ('baseadjust', _base_adjust));
   if (_params is not null)
     vv := vector_concat (vv, _params);
   declare wa_home_title varchar;
   wa_home_title := registry_get ('wa_home_title');
   if (isinteger (wa_home_title))
     wa_home_title := 'OPS Home';
   vv := vector_concat (
	   vector ('wa_home_title', wa_home_title),
	   vector ('acs', '1',
		   'sort', '1',
		   'col', '-1'),
           vv);
   return vv;
	
}
;

create procedure WV.WIKI.SKINSCOLLECTION ()
{
  return '/DAV/VAD/wiki/Root/Skins/';
}
;

create procedure WV.WIKI.SKINSPATH (in _skin varchar, in _base_adjust varchar)
{
  return WV.WIKI.RESOURCEHREF('Skins/' || _skin || '/', _base_adjust);
}
;

create procedure WV.WIKI.SKINCSS (in _skin varchar, in  _base_adjust varchar)
{
  return WV.WIKI.SKINSPATH (_skin, _base_adjust) || 'default.css';
}
;

create procedure WV.WIKI.RESOURCEPATH (in _resource varchar, in _base_adjust varchar)
{
  return sprintf('http://%s/wiki/resources/%s', sioc..get_cname(), _resource);
}
;

grant execute on WV.WIKI.RESOURCEPATH to public
;

xpf_extension ('http://www.openlinksw.com/Virtuoso/WikiV/:ResourcePath', 'WV.WIKI.RESOURCEPATH')
;



create function WV.WIKI.TEXTFORMATTINGRULES (in _cluster_id int, in _base_adjust varchar)
{
   declare _lexer_name, _lexer varchar;
   WV..LEXER (_cluster_id, _lexer, _lexer_name);
  declare _topic WV.WIKI.TOPICINFO;
  _topic := WV.WIKI.TOPICINFO ();
  _topic.ti_raw_title := 'Doc.' || call (_lexer_name)() || 'RulesExcerpt';
  _topic.ti_find_id_by_raw_title ();  
  if (_topic.ti_id = 0)
    return sprintf ('{can not find help file: %s}', _topic.ti_raw_title);
  _topic.ti_find_metadata_by_id ();
  --dbg_obj_print ('3');
  declare exit handler for sqlstate '*' {
  --dbg_obj_print ('4');
    return '';
  }
  ;
  return  xpath_eval ('//div[@class="topic-text"]', WV.WIKI.VSPXSLT ('VspTopicView.xslt', _topic.ti_get_entity (null,1), 
	vector_concat (vector ('baseadjust', _base_adjust),_topic.ti_xslt_vector())));
}
;

grant execute on WV.WIKI.TEXTFORMATTINGRULES to public
;

xpf_extension ('http://www.openlinksw.com/Virtuoso/WikiV/:TextFormattingRules', 'WV.WIKI.TEXTFORMATTINGRULES')
;


create function WV.WIKI.REV_DAV_PATH (
  in _topic WV.WIKI.TOPICINFO,
  in _rev varchar)
{
  return DB.DBA.DAV_SEARCH_PATH (_topic.ti_col_id, 'C') || 'VVC/' || _topic.ti_local_name || '.txt/' || _rev ;
}
;

create function WV.WIKI.DIFF_DAV_PATH (
  in _topic WV.WIKI.TOPICINFO,
  in _rev varchar)
{
  return WV.WIKI.REV_DAV_PATH (_topic, _rev) || '.diff';
}
;

				       
create function WV.WIKI.VSPDIFF (
  inout path any, inout lines any,
  inout _topic WV.WIKI.TOPICINFO,
  in params any)
{
  declare _uid integer;
  declare _base_adjust varchar;
  _uid := get_keyword ('uid', params);
  _base_adjust := get_keyword ('baseadjust', params);
  declare _rev varchar;
  _rev := get_keyword ('rev', params, '1');
  if (atoi(_rev) < 1)
    _rev := '1';
  declare content, type varchar;
  
  WV.WIKI.CHECKREADACCESS (_uid, _topic.ti_res_id, _topic.ti_cluster_id, _topic.ti_col_id);
  
  declare _auth, _pwd varchar;
  WV.WIKI.GETDAVAUTH (_auth, _pwd);


  if (0 < DB.DBA.DAV_RES_CONTENT (WV.WIKI.DIFF_DAV_PATH (_topic, _rev), content, type, _auth, _pwd))
    {
      if (isblob (content))
        content := blob_to_string (content);
      declare _report, _xml_content any;
      _xml_content := xtree_doc ('<text><![CDATA[' || content || ']]></text>');
      _report := XMLELEMENT ('Diff',
			 XMLATTRIBUTES (_rev as "from",
					cast (_rev as int) + 1 as "to"),
			 _xml_content);
      declare _ext_params any;
      _ext_params := vector_concat (_topic.ti_xslt_vector (params), 
      	vector ('back_to_rev', 1));
      http_value (
	  WV.WIKI.VSPXSLT ( 'PostProcess.xslt', 
	    WV.WIKI.VSPXSLT ( 'VspTopicReports.xslt', _report,
	      _ext_params),
	    _ext_params,
	    WV.WIKI.CLUSTERPARAM ( _topic.ti_cluster_id , 'skin', 'default' )));
    }
  return NULL;
}
;
  
create function WV.WIKI.DIFFPRINT (
  in _text varchar) returns any
{ -- prints diff
  declare _line varchar;
  declare _idx, _end int;
  declare _out, _curr_out any;
  if (_text is null)
    return xtree_doc ('<div/>');
  _text := diff_reverse (_text);
  _out := string_output ();
  _idx := 0;
  http ('<div>', _out);
  declare div int;
  while (length (_text) and ((_end := strchr (_text, '\n')) is not null))
   {
     _line := subseq (_text, 0, _end);
     _text := subseq (_text, _end + 1);
     div := 0;
     if (_line[0] = 60)
       {
	 _line := subseq (_line, 1);
	 http ('<div class="diff-insert">&gt;', _out);
	 div := 1;
       }
     else if (_line[0] = 62)
       {
	 _line := subseq (_line, 1);
	 http ('<div class="diff-delete">&lt;', _out);
	 div := 2;
       }
     else if (_line[0] = 92) 	-- \\ sign
       {
	 http ('<div>',_out);
	 div := 3;
       }
     http_value (_line, NULL, _out);
     if (div)
       http ('</div>', _out);
--     else
--      http ('<br/>', _out);
     if (_text[0] = 13)
	_text := subseq (_text, 2);
   }
  http ('</div>', _out);
  return xtree_doc (string_output_string (_out));
}
;

grant execute on WV.WIKI.DIFFPRINT to public
;

xpf_extension ('http://www.openlinksw.com/Virtuoso/WikiV/:DiffPrint', 'WV.WIKI.DIFFPRINT')
;


create function WV.WIKI.FROZEN (in _topic WV.WIKI.TOPICINFO)
{
  declare exit handler for not found {
	return 0;
  };
  declare _is_frozen int;
  declare _redirect varchar;
  select WAI_IS_FROZEN, WAI_FREEZE_REDIRECT into _is_frozen, _redirect
    from (select * from DB.DBA.WA_INSTANCE where WAI_TYPE_NAME = 'oWiki') a 
		where (WAI_INST as wa_wikiv).cluster_id = _topic.ti_cluster_id;
  if (_is_frozen is null or (not _is_frozen))
    return 0;
  if (_redirect = 'default')
    {	
      http_rewrite ();
      http_request_status ('HTTP/1.1 404 Resource not found');
      http ( concat ('<!DOCTYPE HTML PUBLIC "-//IETF//DTD HTML 2.0//EN">',
        '<HTML><HEAD>',
        '<TITLE>404 Not Found</TITLE>',
        '</HEAD><BODY>', '<H1>Not Found</H1>',
        'Resource ', http_path (), ' not found.</BODY></HTML>'));
      return 1;
    }
  http_request_status ('HTTP/1.1 302 Found');
  http_header ('Location: ' || _redirect || '\r\n');
  return 1;
}
;


-- remove spaces in the very beginning and at the end
-- replace all cons. spaces to one space
-- if argument is array apply itself to each element
create procedure WV.WIKI.TRIM_EX (in str_or_array any, in delim_expr varchar := '\\s', in repl varchar:=' ')
{
  if (isstring (str_or_array))
    return regexp_replace (trim (str_or_array), delim_expr || '{2,}', repl, 1, NULL);
  else if (isarray (str_or_array))
    {
      declare _res any;
      _res := vectorbld_init (_res);      
      foreach (any elem in str_or_array) do
        {
	  vectorbld_acc (_res, WV.WIKI.TRIM_EX (elem));
	}
      vectorbld_final (_res);
      return _res;      
    }
  signal ('WV100', 'WV.WIKI.TRIM_EX accepts only string or array as the argument');
}
;

create procedure WV.WIKI.VECTOR_APPEND_UNIQ (inout v any, in elem any)
{
  if (not position (elem, v))
    v := vector_concat (v, vector (elem));
}
;

-- creates new vector of unique elements from v1 and v2
create function WV.WIKI.VECTOR_CONCAT_UNIQ (in v1 any, in v2 any)
{
  declare _res any;
  _res := vector();
  foreach (any elem in v1) do
    WV.WIKI.VECTOR_APPEND_UNIQ (_res, elem);
  foreach (any elem in v2) do
    WV.WIKI.VECTOR_APPEND_UNIQ (_res, elem);
  return _res;
}
;
  

-- fast version, assumes v2 does not contains duplicates 
create function WV.WIKI.VECTOR_CONCAT_UNIQ_FAST (in v1 any, in v2 any)
{
  declare _res any;
  vectorbld_init (_res);
  foreach (any el in v2) do 
    {
      if (position (el, v1) = 0)
        {
	  vectorbld_acc (_res, el);
	}
    }
  vectorbld_final (_res);
  return vector_concat(v1,_res);
}
;
      
create function WV.WIKI.VECTOR_DROP (in v any, in drop_elem any)
{
  declare _res any;
  vectorbld_init (_res);
  foreach (any el in v) do 
    {
      if (el <> drop_elem)
        vectorbld_acc (_res, el);
    }
  vectorbld_final (_res);
  return _res;
}
;
  
create function WV.WIKI.VECTOR_NREVERSE (inout v any)
{
  declare idx, len int;
  len := length(v);
  declare temp any;
  for (idx := len; idx > len/2; idx:=idx - 1)
    {
      temp := v[len - idx];
      v[len - idx] := v[idx - 1];
      v[idx - 1] := temp;
    }
  return len;
}
;

create function WV.WIKI.VECTOR_REVERSE (in v any)
{
  declare idx, len int;
  declare res any;
  len := length(v);
  vectorbld_init(res);
  for (idx := len - 1; idx >= 0; idx:=idx - 1)
    {
      vectorbld_acc (res, v[idx]);
    }
  vectorbld_final(res);
  return res;
}
;
   
create function WV.WIKI.VECTOR_DROP_NOISE_WORDS (in v any)
{
  declare _res any;
  vectorbld_init (_res);
  foreach (any el in v) do 
    {
      if (length (el) > 1)
        vectorbld_acc (_res, el);
    }
  vectorbld_final (_res);
  return _res;
}
;

create function WV.WIKI.VECTOR_DROP_KEYWORD (in v any, in keyword any)
{
  declare _res any;
  declare _flag int;
  _flag := 0;
  vectorbld_init (_res);
  foreach (any el in v) do 
    {
      if (_flag or el = keyword)
	{
	  if (not _flag)
	    _flag := 1;
	  else
	    _flag := 0;
	}
      else
        vectorbld_acc (_res, el);
    }
  vectorbld_final (_res);
  return _res;
}
;

  

create procedure WV.WIKI.ADDCATEGORY_PREFIX (in vect_of_words any)
{
  declare res any;
  vectorbld_init (res);
  foreach (varchar w in vect_of_words) do
    {
      vectorbld_acc (res, 'Category' || w);
    }
  vectorbld_final (res);
  return res;
}
;

create procedure WV.WIKI.PARSE_SEARCH_STR (in _str varchar)
{
  declare _str_arr any;
  _str_arr := split_and_decode (ucase (_str), 0, '\0\0 ');
  if (length (_str_arr) = 0)
    return _str;
  declare _keyword, idx int;
  _keyword := 0;
  declare res any;
  declare open_str_ch int;
  open_str_ch := 0;
  vectorbld_init (res);
  vectorbld_acc (res, _str_arr[0]);
  if (_str_arr[0][0] = 34)
    open_str_ch := 1;
  for (idx := 1; idx < length (_str_arr); idx := idx + 1)
    {
      declare last int;
      last := length (_str_arr[idx]) - 1;
      if (last < 0)
        last := 0;
      if (open_str_ch and _str_arr[idx][last] = 34) -- closing character
        {
	  vectorbld_acc (res, _str_arr[idx]);
	  open_str_ch := 0;
	  goto fin;
	}
      if (_str_arr[idx][0] = 34)
        {
	  vectorbld_acc (res, _str_arr[idx]);
	  open_str_ch := 1;
	  goto fin;
        } 
      if (open_str_ch)
        {
	  vectorbld_acc (res, _str_arr[idx]);
	  goto fin;
	} 
      if (_str_arr[idx] = 'AND' or
        _str_arr[idx] = 'OR' or
	_str_arr[idx] = 'NEAR')
	{
	  if (not _keyword)
	    {
	  _keyword := 1;
	  vectorbld_acc (res, _str_arr[idx]);
	}
	}
      else if (_keyword)
        {
	  vectorbld_acc (res, _str_arr[idx]);
	  _keyword := 0;
	}
      else
        {
	  vectorbld_acc (res, 'AND');
	  vectorbld_acc (res, _str_arr[idx]);
	}
fin:
	;
     }
  vectorbld_final (res);
  return WV.WIKI.STRJOIN(' ', res);
}
;
  


create function WV.WIKI.PARAMS (in _key varchar, in defval varchar)
{
  declare _params any;
  _params := connection_get ('WIKI params');
  if (_params is null)
    return defval;
  return get_keyword (_key, _params,  defval);  
}
;
  

grant execute on WV.WIKI.PARAMS to public
;

xpf_extension ('http://www.openlinksw.com/Virtuoso/WikiV/:params', 'WV.WIKI.PARAMS')
;

create function WV.WIKI.REGISTRY_GET (in _key varchar, in defval varchar)
{
  declare _res any;
  _res := registry_get (_key);
  if (not isstring (_res))
    return defval;
  return _res;
}
;
  

grant execute on WV.WIKI.REGISTRY_GET to public
;

xpf_extension ('http://www.openlinksw.com/Virtuoso/WikiV/:registry_get', 'WV.WIKI.REGISTRY_GET')
;


create function WV.WIKI.DASHBOARD()
{
  return 'Dashboard';
}
;

create function WV.WIKI.FUNCALL0(in procname varchar)
{
  procname := fix_identifier_case (procname);
  if (__proc_exists (procname) or position ('.', procname) = 0)
    return call (procname) ();
  return NULL;
}
;
create function WV.WIKI.FUNCALL1(in procname varchar, in v1 any)
{
  procname := fix_identifier_case (procname);
  if (__proc_exists (procname) or position ('.', procname) = 0)
    return call (procname) (v1);
  return NULL;
}
;
create function WV.WIKI.FUNCALL2(in procname varchar, in v1 any, in v2 any)
{
  procname := fix_identifier_case (procname);
  if (__proc_exists (procname) or position ('.', procname) = 0)
    return call (procname) (v1,v2);
  return NULL;
}
;
create function WV.WIKI.FUNCALL3(in procname varchar, in v1 any, in v2 any, in v3 any)
{
  procname := fix_identifier_case (procname);
  if (__proc_exists (procname) or position ('.', procname) = 0)
    return call (procname) (v1,v2,v3);
  return NULL;
}
;
create function WV.WIKI.FUNCALL4(in procname varchar, in v1 any, in v2 any, in v3 any, in v4 any)
{
  procname := fix_identifier_case (procname);
  if (__proc_exists (procname) or position ('.', procname) = 0)
    return call (procname) (v1,v2,v3, v4);
  return NULL;
}
;

	
grant execute on WV.WIKI.FUNCALL0 to public
;
grant execute on WV.WIKI.FUNCALL1 to public
;
grant execute on WV.WIKI.FUNCALL2 to public
;
grant execute on WV.WIKI.FUNCALL3 to public
;
grant execute on WV.WIKI.FUNCALL4 to public
;

xpf_extension ('http://www.openlinksw.com/Virtuoso/WikiV/:funcall0', 'WV.WIKI.FUNCALL0')
;
xpf_extension ('http://www.openlinksw.com/Virtuoso/WikiV/:funcall1', 'WV.WIKI.FUNCALL1')
;
xpf_extension ('http://www.openlinksw.com/Virtuoso/WikiV/:funcall2', 'WV.WIKI.FUNCALL2')
;
xpf_extension ('http://www.openlinksw.com/Virtuoso/WikiV/:funcall3', 'WV.WIKI.FUNCALL3')
;
xpf_extension ('http://www.openlinksw.com/Virtuoso/WikiV/:funcall4', 'WV.WIKI.FUNCALL4')
;

create function WV.WIKI.OWNER_OF_CLUSTER (in _user varchar, in _cluster_id int, in _cluster_name varchar)
{
  declare _uid int;
  _uid := (select U_ID from DB.DBA.SYS_USERS where U_NAME = _user);
  if (exists (select 1 from DB.DBA.WA_MEMBER, DB.DBA.SYS_USERS
	 where WAM_USER = U_ID
	  and U_NAME = _user
	  and WAM_MEMBER_TYPE = 1
	  and WAM_INST = _cluster_name))
    return 1;
  return 0;
}
;

create function WV.WIKI.DEFAULTENDPOINT (in _cluster_id int)
{
  return '';
}
;

create function WV.WIKI.TRANSLATE_COMMAND (in _cmd varchar)
{
  _cmd := lcase (_cmd);
  if (_cmd like 'save%')
    return 'save';
  return _cmd;
}
;

create function WV.WIKI.GET_TEMP_TEXT (in cluster_name varchar, in local_name varchar)
{
  return coalesce ( (select ETS_TEXT from WV.WIKI.EDIT_TEMP_STORAGE where 
	ETS_CLUSTER = cluster_name and
	ETS_LOCAL_NAME = local_name), '');
}
;

create function WV.WIKI.HTML_TO_WIKI (in _text varchar)
{
  declare _nodes any;
  declare _html any;
  declare xslt_params any;
  xslt_params := vector ();
   _html := WV.WIKI.VSPXSLT ('HTMLtoWiki.xslt', xtree_doc (_text,2), xslt_params);
  _nodes := xpath_eval ('node()', _html, 0);
  _text := '';
  foreach (any _xt in _nodes) do
    {
      _text := _text || replace (serialize_to_UTF8_xml (_xt), ' xmlns="http://www.w3.org/1999/xhtml"', '');
    }
  return _text;
}
;


create function WV.WIKI.SET_TEMP_TEXT (in cluster_name varchar, in local_name varchar, in _text varchar, in params any)
{
  if (get_keyword ('fix-html', params) is not null)
    {
      _text := WV.WIKI.HTML_TO_WIKI (_text);
    }
  insert replacing WV.WIKI.EDIT_TEMP_STORAGE (ETS_CLUSTER, ETS_LOCAL_NAME, ETS_TEXT, ETS_DATE)
	values (cluster_name, local_name, _text, now());
}
;

create function WV.WIKI.URL_PARAMS (in params varchar)
{
  if (isstring (params))
	  return params;
  declare v any;
  v := vector ();
  return WV.WIKI.URL_PARAMS_INT (params, v);
}
;

create function WV.WIKI.URL_PARAMS_INT (in params any, inout v any)
{
  --dbg_obj_princ ('WV.WIKI.URL_PARAMS_INT: ', params);
  declare url_params varchar;
  declare idx int;
  idx :=0;
  while (idx < length (params))
    {
      if (isarray(params[idx]) and not isstring(params[idx]))
	{
	  WV.WIKI.URL_PARAMS_INT (params[idx], v);
	  idx := idx + 1;
  	}
      else if ( ((idx+1) < length(params)) and
	(isstring (params[idx]) and (params[idx] <> '')) and
	  (isstring (params[idx+1]) and (params[idx+1] <> '')))
	{
	  v := vector_concat (v, vector (sprintf ('%U=%U', params[idx], params[idx+1])));
	  idx := idx + 2;
	}
      else
	idx := idx + 1;
    }
  url_params := '';
  if (length (v) > 0)
    url_params := url_params || WV.WIKI.STRJOIN ('&', v);
  return url_params;
}
;



create function WV.WIKI.RESOURCEHREF (in href varchar, in _base_adjust varchar)
{
  declare _resources varchar;
  _resources := registry_get('WIKI RESOURCES');
  if (isinteger(_resources) and is_http_ctx())
    {
      declare vh, lh, hf, lines any;
      lines := http_request_header ();
      vh := http_map_get ('vhost');
      lh := http_map_get ('lhost');
      hf := http_request_header (lines, 'Host');
      if (hf is not null and exists (select 1 from HTTP_PATH where HP_HOST = vh and HP_LISTEN_HOST = lh and HP_LPATH = '/wiki/resources'))
        return 'http://' || hf || '/wiki/resources/' || href;
      else
    return sprintf ('http://%s/wiki/resources/%s', sioc..get_cname(), href);
    }
  else if (isstring (_resources))
    return _resources || href;
  else
    return DB.DBA.WA_LINK (1, href);
}
;
create function WV.WIKI.RESOURCEHREF2 (in resource varchar, 
	in _base_adjust varchar,
	in _params any)
{
  declare url_params any;
  url_params := WV.WIKI.URL_PARAMS (_params);
  if (url_params <> '')
    return sprintf ('%s?%s', WV.WIKI.RESOURCEHREF(resource, _base_adjust), url_params);
  return WV.WIKI.RESOURCEHREF (resource, _base_adjust);
}
;
create function WV.WIKI.PAIR (in _key varchar, in value varchar)
{
  if (_key <> '' and value <> '')
    return _key || '=' || value;
  return '';
}
;

create function WV.WIKI.COLLECT_PAIRS (in _value varchar, in _rest varchar)
{
  if (_value <> '' and _rest <> '')
	return _value || '&' || _rest;
  return _value || _rest;
}
;


grant execute on WV.WIKI.RESOURCEHREF to public
;
grant execute on WV.WIKI.RESOURCEHREF2 to public
;
grant execute on WV.WIKI.PAIR to public
;
grant execute on WV.WIKI.COLLECT_PAIRS to public
;

xpf_extension ('http://www.openlinksw.com/Virtuoso/WikiV/:ResourceHREF', 'WV.WIKI.RESOURCEHREF')
;
xpf_extension ('http://www.openlinksw.com/Virtuoso/WikiV/:ResourceHREF2', 'WV.WIKI.RESOURCEHREF2')
;
xpf_extension ('http://www.openlinksw.com/Virtuoso/WikiV/:pair', 'WV.WIKI.PAIR')
;
xpf_extension ('http://www.openlinksw.com/Virtuoso/WikiV/:collect_pairs', 'WV.WIKI.COLLECT_PAIRS')
;


--* fixes DAV path name
create function WV.WIKI.FIX_PATH (
	in path varchar --* DAV path
--r returns path name with removed redundant symbols
)
{
  declare p, result_p any;
  p := split_and_decode (path, 0, '\0\0/');
  vectorbld_init(result_p);
  declare idx int;
  for (idx := 0; idx < length (p); idx := idx + 1)
    {
      if (idx = 0 or p[idx] <> '')
	{
	  vectorbld_acc (result_p, p[idx]);
	}
    }
  vectorbld_final(result_p);
  return WV.WIKI.STRJOIN ('/', result_p);
}
;
      
--* returns file name part of the path
create function WV.WIKI.FILE_NAME(
	in path varchar --* DAV path
)
{
  declare parts any;
  parts := split_and_decode (path, 0, '\0\0/');
  if (length (parts) < 2)
    return path;
  return parts [length (parts) - 1];
}
;

--* creates collection and all parent collections if needed
create function WV.WIKI.MKDIR (
	in path varchar, --* DAV collection to be created
	in auth varchar,
	in grp varchar,
	in passwd varchar
--r returns DAV code of result
)
{
  declare parts any;
  declare res int;
  parts := split_and_decode (WV.WIKI.FIX_PATH (path), 0, '\0\0/');
--  dbg_obj_princ ('>', path);
  declare idx int;
  for (idx:=3; idx<=length(parts); idx := idx+1)
    {
       path := WV.WIKI.STRJOIN ('/', subseq (parts, 0, idx)) || '/';
--	   dbg_obj_princ ('=>', path, DB.DBA.DAV_SEARCH_ID (path, 'C'));
	   if (DB.DBA.DAV_HIDE_ERROR (DB.DBA.DAV_SEARCH_ID (path, 'C')) is null)
       res := DB.DBA.DAV_COL_CREATE (path, '110100100NM', auth, grp, auth, passwd);
--       dbg_obj_princ (res);
    }
  return res;
}
;


create function WV.WIKI.GET_WAI_ID (in cluster_name int)
{
   return coalesce ((select WAI_ID from DB.DBA.WA_INSTANCE where WAI_NAME = cluster_name and WAI_TYPE_NAME = 'oWiki'), 0);
}
;

create function WV.WIKI.MOD_TIME (in _res_id int, in _rev_id int)
{
  _rev_id := cast (_rev_id as int);
  if (_rev_id is not null and _rev_id <> 0)
    return coalesce ( (select WV.WIKI.DATEFORMAT (RV_MOD_TIME, 'rfc1123') from WS.WS.SYS_DAV_RES_VERSION where RV_RES_ID = _res_id and RV_ID =_rev_id), '');
  return coalesce ( (select WV.WIKI.DATEFORMAT (RES_MOD_TIME, 'rfc1123') from WS.WS.SYS_DAV_RES where RES_ID = _res_id), '');
}
;


create function WV.WIKI.WA_PPATH_URL (in resource varchar)
{
   return 'virt://WS.WS.SYS_DAV_RES.RES_FULL_PATH.RES_CONTENT:/DAV/VAD/wa/comp/' || resource;
}
;


create function WV.WIKI.BUILD_URL_PART (in params any)
{
  declare idx int; 
  declare res any;
  vectorbld_init (res);
  for (idx := 0; idx < length (params); idx:=idx+2)
    {
       vectorbld_acc (res, sprintf ('%U', params[idx]) || '=' || sprintf ('%U', cast (params[idx+1] as varchar)));
    }
  vectorbld_final (res);
  return WV.WIKI.STRJOIN ('&', res);
}
;

--* returns various information about user
create function WV.WIKI.USER_DETAILS (in uid int, in field_name varchar)
{
   return get_keyword (field_name, (select 
	vector ('name', U_NAME, 
		'e-mail', U_E_MAIL,
		'homepage', sioc..get_graph() || '/' || U_NAME) from DB.DBA.SYS_USERS 
	where U_ID = uid));
}
;

create procedure WV.WIKI.UTF2WIDE (
  inout S any)
{
  declare exit handler for sqlstate '*' { return S; };
  return charset_recode (S, 'UTF-8', '_WIDE_');
}
;

create function WV.WIKI.EMAIL_OBFUSCATE (in clustername varchar, in mailto varchar)
{
  declare _type, _proc varchar;
  _type := WV.WIKI.CLUSTERPARAM (clustername , 'email-obfuscate', 'NONE');
  _proc := fix_identifier_case ('WV.WIKI.EMAIL_OBFUSCATE_' || _type);
  if ((mailto like 'mailto:%') or (mailto like 'MAILTO:%'))
    mailto := subseq (mailto, 7);
  if (__proc_exists (_proc))
    return call (_proc) (mailto);
  return mailto;
}
;


create function WV.WIKI.EMAIL_OBFUSCATE_MAILTO (in mailto varchar)
{
  return xtree_doc ('<a href="mailto:' || mailto || '">' || mailto || '</a>');
}
;

create function WV.WIKI.EMAIL_OBFUSCATE_NONE (in mailto varchar)
{
  return '<none>';
}
;

create function WV.WIKI.EMAIL_OBFUSCATE_HEX (in mailto varchar)
{
  return '<?replace ' || mailto || '?>';
}
;

create function WV.WIKI.EMAIL_OBFUSCATE_ALL_HEX (in mailto varchar)
{
  return mailto;
  declare ss any;
  ss := string_output ();
  declare idx int;
  for (idx:=0;idx<length(mailto);idx:=idx+1)
    {
      http (sprintf ('&#%02ld;', mailto[idx]), ss);
    }
  return xtree_doc ('<div><![CDATA[' || string_output_string (ss) || ']]></div>');
}
;


create function WV.WIKI.EMAIL_OBFUSCATE_NOSPAM (in mailto varchar)
{
  return replace(mailto, '@', ' NOSPAM ');
}
;

create function WV.WIKI.EMAIL_OBFUSCATE_AT (in mailto varchar)
{
  return replace (replace(mailto, '@', '{at}'), '.', '{dot}');
}
;




grant execute on WV.WIKI.EMAIL_OBFUSCATE to public
;

xpf_extension ('http://www.openlinksw.com/Virtuoso/WikiV/:email_obfuscate', 'WV.WIKI.EMAIL_OBFUSCATE')
;

create function WV.WIKI.LPATH_1(in _path varchar)
{
  declare parts any;
  parts := split_and_decode (_path, 0, '\0\0/');
  if (length (parts) < 1)
    return '/';
  else if (parts[length(parts) - 1] <> '')
    return WV.WIKI.STRJOIN ('/', subseq (parts, 0, length(parts)-1)) || '/';
  else
    return WV.WIKI.STRJOIN ('/', parts);
}
;

    
create function WV.WIKI.LPATH()
{
  return WV.WIKI.LPATH_1 (http_path());
}
;

create function WV.WIKI.USER_PARAMS (in _params any, in _user varchar, inout _topic WV.WIKI.TOPICINFO)
{
  for select WAUI_LAT, WAUI_LNG from DB.DBA.WA_USER_INFO, DB.DBA.SYS_USERS 
	where U_ID = WAUI_U_ID 
	and U_NAME = _user do 
    {
      if (WAUI_LNG is not null and WAUI_LAT is not null)
	{
	  declare inst_id int;
	  inst_id := (select WAI_ID from DB.DBA.WA_INSTANCE where WAI_TYPE_NAME = 'oWiki' and WAI_NAME = _topic.ti_cluster_name);
	  if (exists (select 1 from ODS..SVC_HOST, ODS..APP_PING_REG 
		where SH_NAME = 'GeoURL' 
		and AP_HOST_ID = SH_ID and AP_WAI_ID = inst_id))
 	    _params := vector_concat (_params, vector ('geo_link', sprintf ('http://geourl.org/near?p=%U',  DB.DBA.WA_LINK (1,'/wiki/main/' || get_keyword ('ti_cluster_name', _params)))));
	  return vector_concat (_params, vector ('geo_lat', sprintf ('%.06f', WAUI_LAT), 'geo_lng', sprintf ('%.06f', WAUI_LNG)));
 	}
    }
  return _params;
}
;

create function WV..CLUSTER_URL(in _cluster varchar)
{
  if (exists (select 1 from WV.WIKI.DOMAIN_PATTERN_1 where DP_HOST = '%' and DP_PATTERN = '/wiki/main'))
    return sprintf('http://%s/wiki/main/%U', sioc..get_cname(), _cluster);
  return sprintf('http://%s/wiki/%U', sioc..get_cname(), _cluster);
}
;
create function WV..TOPIC_URL(in _topic varchar)
{
  if (exists (select 1 from WV.WIKI.DOMAIN_PATTERN_1 where DP_HOST = '%' and DP_PATTERN = '/wiki/main'))
    return sprintf('http://%s/wiki/main/%s', sioc..get_cname(), _topic);
  return sprintf('http://%s/wiki/%s', sioc..get_cname(), _topic);
}
;

create function WV..ODS_LINK(inout lines any)
{
  declare vh, lh, hf any;
  if (not is_http_ctx())
    return WA_LINK(1, '/ods/');
  vh := http_map_get ('vhost');
  lh := http_map_get ('lhost');
  hf := http_request_header (lines, 'Host');
 
  if(strchr (hf, ':') is null)
    hf:=hf||':'|| server_http_port ();
  if (hf is not null and exists (select 1 from HTTP_PATH where HP_HOST = vh and HP_LISTEN_HOST = lh and HP_LPATH = '/ods'))
    return 'http://' || hf || '/ods/';
  else
    return WA_LINK(1, '/ods/');
}
;

