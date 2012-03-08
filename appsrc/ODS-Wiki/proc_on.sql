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


create method ti_http_debug_print (in _caption varchar) returns any for WV.WIKI.TOPICINFO
{
  http(sprintf('<table><caption>%V</caption>', cast (_caption as varchar)));
  http(sprintf('<tr><th>default cluster</th><td>%V</td></tr>', cast (self.ti_default_cluster as varchar)));
  http(sprintf('<tr><th>raw name</th><td>%V</td></tr>', cast (self.ti_raw_name as varchar)));
  http(sprintf('<tr><th>raw title</th><td>%V</td></tr>', cast (self.ti_raw_title as varchar)));
  http(sprintf('<tr><th>wiki name</th><td>%V</td></tr>', cast (self.ti_wiki_name as varchar)));
  http(sprintf('<tr><th>cluster name</th><td>%V</td></tr>', cast (self.ti_cluster_name as varchar)));
  http(sprintf('<tr><th>local name</th><td>%V</td></tr>', cast (self.ti_local_name as varchar)));
  http(sprintf('<tr><th>id</th><td>%V</td></tr>', cast (self.ti_id as varchar)));
  http(sprintf('<tr><th>cluster id</th><td>%V</td></tr>', cast (self.ti_cluster_id as varchar)));
  http(sprintf('<tr><th>res id</th><td>%V</td></tr>', cast (self.ti_res_id as varchar)));
  http(sprintf('<tr><th>col id</th><td>%V</td></tr>', cast (self.ti_col_id as varchar)));
  http(sprintf('<tr><th>author id</th><td>%V</td></tr>', cast (self.ti_author_id as varchar)));
  http('</table>');
}
;

create method ti_complete_env () returns any for WV.WIKI.TOPICINFO
{
  if (get_keyword ('BASECLUSTER', self.ti_env) is null)
    self.ti_env := vector_concat ( vector ('BASECLUSTER', self.ti_cluster_name), self.ti_env);
  if (get_keyword ('INCLUDINGCLUSTER', self.ti_env) is null)
    self.ti_env := vector_concat ( vector ('INCLUDINGCLUSTER', self.ti_cluster_name), self.ti_env);
  if (get_keyword ('BASETOPIC', self.ti_env) is null)
    self.ti_env := vector_concat ( vector ('BASETOPIC', self.ti_local_name), self.ti_env);
  if (get_keyword ('INCLUDINGTOPIC', self.ti_env) is null)
    self.ti_env := vector_concat ( vector ('INCLUDINGTOPIC', self.ti_local_name), self.ti_env);
  if (get_keyword ('ATTACHURL', self.ti_env) is null)
    self.ti_env := vector_concat ( vector ('ATTACHURL', concat (self.ti_base_adjust, self.ti_cluster_name, '/', self.ti_local_name)), self.ti_env);
}
;

create method ti_xslt_vector () returns any for WV.WIKI.TOPICINFO
{
  return self.ti_xslt_vector (NULL);
}
;

create method ti_xslt_vector (in params any) returns any for WV.WIKI.TOPICINFO
{
  declare _res any;
  _res := vector (
    'ti_default_cluster'	, cast (self.ti_default_cluster as varchar),
    'ti_raw_name'		, cast (self.ti_raw_name as varchar),
    'ti_raw_title'		, cast (self.ti_raw_title as varchar),
    'ti_wiki_name'		, cast (self.ti_wiki_name as varchar),
    'ti_cluster_name'		, cast (self.ti_cluster_name as varchar),
    'ti_local_name'		, cast (self.ti_local_name as varchar),
    'ti_id'			, cast (self.ti_id as varchar),
    'ti_cluster_id'		, cast (self.ti_cluster_id as varchar),
    'ti_res_id'			, cast (self.ti_res_id as varchar),
    'ti_col_id'			, cast (self.ti_col_id as varchar),
    'ti_abstract'		, cast (self.ti_abstract as varchar),
    'ti_text'			, WV.WIKI.DELETE_SYSINFO_FOR (cast (self.ti_text as varchar), NULL),
    'ti_author_id'		, cast (self.ti_author_id as varchar),
    'ti_author'			, cast (self.ti_author as varchar),
    'ti_curuser_wikiname'	, cast (self.ti_curuser_wikiname as varchar),
    'ti_curuser_username'	, cast (self.ti_curuser_username as varchar),
    'ti_attach_col_id'		, cast (self.ti_attach_col_id as varchar),
    'ti_attach_col_id_2'	, cast (self.ti_attach_col_id_2 as varchar),
    'ti_mod_time'		, cast (self.ti_mod_time as varchar),
    'ti_e_mail'			, cast (self.ti_e_mail as varchar),
    'ti_rev_id'      , cast (self.ti_rev_id as varchar)
  );
  _res := vector_concat (_res, self.ti_env);
  if (params is not null)
    _res := vector_concat (_res, params);
     
  return _res;
}
;

create method ti_parse_raw_name () returns any for WV.WIKI.TOPICINFO
{
  declare _colon, _dot integer;
  _colon := strchr (self.ti_raw_name, ':');
  if (_colon is not null)
    {
      self.ti_wiki_name := subseq (self.ti_raw_name, 0, _colon);
      self.ti_cluster_name := '';
      self.ti_local_name := subseq (self.ti_raw_name, _colon + 1);
      return;
    }
  self.ti_wiki_name := null;
  _dot := strchr (self.ti_raw_name, '.');
  if (_dot is null)
    {
      self.ti_cluster_name := self.ti_default_cluster;
      self.ti_local_name := self.ti_raw_name;
    }
  else
    {
      self.ti_cluster_name := subseq (self.ti_raw_name, 0, _dot);
      self.ti_local_name := subseq (self.ti_raw_name, _dot + 1);
    }
  return null;
}
;

create method ti_fill_cluster_by_name () returns any for WV.WIKI.TOPICINFO
{
  for select top 1 ClusterId, ColId, ColHistoryId, ColAttachId, ColXmlId, AdminId
  from WV.WIKI.CLUSTERS where ClusterName = self.ti_cluster_name do
    {
      self.ti_cluster_id := ClusterId;
      self.ti_col_id := ColId;
      self.ti_col_history_id := ColHistoryId;
      self.ti_col_attach_id := ColAttachId;
      self.ti_col_xml_id := ColXmlId;
      self.ti_cluster_admin_id := AdminId;
    }
  return null;
}
;

create method ti_fill_cluster_by_id () returns any for WV.WIKI.TOPICINFO
{
  for select top 1 ClusterName, ColId, ColHistoryId, ColAttachId, ColXmlId, AdminId
  from WV.WIKI.CLUSTERS where ClusterId = self.ti_cluster_id do
    {
      self.ti_cluster_name := ClusterName;
      self.ti_col_id := ColId;
      self.ti_col_history_id := ColHistoryId;
      self.ti_col_attach_id := ColAttachId;
      self.ti_col_xml_id := ColXmlId;
      self.ti_cluster_admin_id := AdminId;
    }
  return null;
}
;

create method ti_find_id_by_local_name () returns any for WV.WIKI.TOPICINFO
{
  self.ti_id := coalesce ((select TopicId from WV.WIKI.TOPIC where LocalName = self.ti_local_name and ClusterId = self.ti_cluster_id), 0 );
}
;

create method ti_find_id_by_raw_title () returns any for WV.WIKI.TOPICINFO
{
  declare _colon, _dot integer;
  declare _id integer;
  declare _test WV.WIKI.TOPICINFO;
  _test := WV.WIKI.TOPICINFO();
  _test.ti_raw_name := self.ti_raw_title;
  _test.ti_cluster_name := self.ti_default_cluster;
  _test.ti_default_cluster := self.ti_default_cluster;
  _test.ti_parse_raw_name();
  _test.ti_fill_cluster_by_name();
  _test.ti_find_id_by_local_name();
  if (_test.ti_id <> 0)
    self.ti_id := _test.ti_id;
  return null;
}
;

create method ti_find_metadata_by_id () returns any for WV.WIKI.TOPICINFO
{
  for (select top 1 ClusterId, ResId, ResXmlId, TopicTypeId, LocalName, TitleText, Abstract, MailBox, ParentId, AuthorId
         from WV.WIKI.TOPIC
        where TopicId = self.ti_id) do
  {
    self.ti_cluster_id := ClusterId;
    self.ti_res_id := ResId;
    self.ti_type_id := TopicTypeId;
    self.ti_local_name := LocalName;
    self.ti_local_name_2 := LocalName;
    self.ti_title_text := TitleText;
    self.ti_abstract := Abstract;
    self.ti_e_mail := MailBox;
    self.ti_parent_id := ParentId;
    self.ti_author_id := AuthorId;
  }
  self.ti_fill_cluster_by_id();
  if (self.ti_abstract is null)
    self.ti_abstract := (select WAI_DESCRIPTION from DB.DBA.WA_INSTANCE where WAI_TYPE_NAME = 'oWiki' and WAI_NAME = self.ti_cluster_name);

  declare _mod_time datetime;
  declare _author varchar; 
  declare _author_id integer;

  declare _dav_auth, _dav_pwd varchar;
  WV.WIKI.GETDAVAUTH (_dav_auth, _dav_pwd);

  if (self.ti_res_id <> 0)
    {
      declare content, type varchar;
      declare path varchar;
      declare author_id integer;
      if (self.ti_rev_id <> 0)
	{
	  path := DB.DBA.DAV_SEARCH_PATH (self.ti_col_id, 'C') || 'VVC/' || self.ti_local_name || '.txt/' ||
   	     cast (self.ti_rev_id as varchar);
	  self.ti_author_id := (select U_ID from WS.WS.SYS_DAV_RES_VERSION, DB.DBA.SYS_USERS where RV_WHO = U_NAME and RV_RES_ID = self.ti_res_id and RV_ID = self.ti_rev_id);	  
	  --dbg_obj_print ('xxx');	
	} 
      else
	{
          path := DB.DBA.DAV_SEARCH_PATH (self.ti_res_id, 'R');
	}
      if (self.ti_author_id is null)
	{
	  declare main_path varchar;
          main_path := DB.DBA.DAV_SEARCH_PATH (self.ti_res_id, 'R');
	  self.ti_author_id := DAV_HIDE_ERROR (DAV_PROP_GET (main_path, ':virtowneruid', _dav_auth, _dav_pwd));
	}
      if (0 < DB.DBA.DAV_RES_CONTENT (path, content, type, _dav_auth, _dav_pwd))
        { 
          self.ti_text := cast (content as varchar);
        }
      else
      {
        WV.WIKI.APPSIGNAL (11001, 'Can not get topic content (revision: ' || case when self.ti_rev_id = 0 then 'last' else cast (self.ti_rev_id as varchar) end || ')',  vector () );
      }
      self.ti_mod_time := DAV_HIDE_ERROR (DAV_PROP_GET (path, ':getlastmodified', _dav_auth, _dav_pwd));
      self.ti_author := coalesce ( 
	(select UserName from WV.WIKI.USERS where UserId = self.ti_author_id), 
	WV.WIKI.USER_WIKI_NAME_2(self.ti_author_id), 
	'Unknown');
      declare dav_path varchar;
      dav_path := DAV_HIDE_ERROR (DAV_SEARCH_PATH (self.ti_res_id, 'R'));
      if (dav_path is not null)
	{ 
	  dav_path := subseq (dav_path, 0, length(dav_path) - 4) || '/';
	  self.ti_attach_col_id := coalesce (DAV_HIDE_ERROR (DAV_SEARCH_ID (dav_path, 'C')), 0);
	}

    }
  return null;
}
;

create method ti_find_metadata_by_res_id () returns any for WV.WIKI.TOPICINFO
{
  declare _topic_id integer;

  _topic_id := (select TopicId from WV.WIKI.TOPIC where ResId = self.ti_res_id);
  if (_topic_id is null)
  {
    self.ti_id := 0;
  }
  else
    {
      self.ti_id := _topic_id;
      self.ti_find_metadata_by_id();
    }
}
;

create method ti_full_name () returns varchar for WV.WIKI.TOPICINFO
{
  return self.ti_cluster_name || '.' || self.ti_local_name;
}
;

create method ti_run_lexer (in _env any) returns varchar for WV.WIKI.TOPICINFO
{
  declare exit handler for sqlstate '*' {
    --dbg_obj_print ('lexer:', __SQL_STATE, __SQL_MESSAGE);
    --return '';
    resignal;
  }
  ;
  declare _text varchar;
  if (isstring (self.ti_text))
    _text := self.ti_text;
  else
    _text := cast (self.ti_text as varchar);
  declare _res, _lexer, _lexer_name varchar;
  WV.DBA.LEXER (coalesce ((select ClusterName from Wv.WIKI.CLUSTERS where ClusterId = self.ti_cluster_id), 'Main'), _lexer, _lexer_name);
  --WV..LEXER (self.ti_cluster_id, _lexer, _lexer_name);
  _lexer_name := cast (call (_lexer_name) () as varchar);
  if (_env is null) _env := vector();
--  dbg_obj_print (_lexer);
  _res := call (_lexer) (_text || '\r\n', 
  	coalesce (self.ti_cluster_name, 'Main'),
	coalesce (self.ti_local_name, 'WelcomeVisitors'),
	self.ti_curuser_wikiname, vector_concat (_env, vector ('SYNTAX', _lexer_name)));
--	dbg_obj_print (_res);
  return _res;
}
;

create method ti_get_entity (in _env any, in _ext integer) returns any for WV.WIKI.TOPICINFO
{

  --dbg_obj_print ('get_entity');
  declare _html varchar;
  declare _ent, _wide any;
  if (_env is null)
    {
  --dbg_obj_print ('get_entity 1');
      self.ti_complete_env();
  --dbg_obj_print ('get_entity 2');
      _env := self.ti_env;
  --dbg_obj_print ('get_entity 3');
    }  
  _html := self.ti_run_lexer (_env);
  --dbg_obj_print ('get_entity 4');

  _wide := charset_recode (_html, 'UTF-8', '_WIDE_');
  if (not iswidestring (_wide)) -- source is not utf-8, thus we will try to recover
    {
      _wide := charset_recode (_html, current_charset (), 'UTF-8');
      if (isstring (_wide))
	_html := _wide;
    }
  _ent := xtree_doc (_html, 2, '', 'UTF-8');


  --dbg_obj_print ('get_entity 5', _ent);
  if (_ext = 1) 
    {	
        --dbg_obj_print ('get_entity 6');
	XMLAppendChildren (_ent, self.ti_report_attachments());
        --dbg_obj_print ('get_entity 7');
	XMLAppendChildren (_ent, self.ti_wiki_path());
        --dbg_obj_print ('get_entity 8');
	XMLAppendChildren (_ent, self.ti_report_mails());
        --dbg_obj_print ('get_entity 9');
	XMLAppendChildren (_ent, self.ti_revisions(0, 7));
        --dbg_obj_print ('get_entity 10');
	XMLAppendChildren (_ent, self.ti_get_tags());
        --dbg_obj_print ('get_entity 11');
    }
  --dbg_obj_print (_ent);
  if (_ent is null)
    _ent := XMLELEMENT('xmp', _html);
  --dbg_obj_print ('get_entity 6', _ent);
  return _ent;
}
;

use WV
;

create method ti_compile_page () returns any for WV.WIKI.TOPICINFO
{
  declare exit handler for sqlstate '*' {
    --dbg_obj_print ('compile:', __SQL_STATE, __SQL_MESSAGE);
    resignal;
  }
  ;
  --dbg_obj_print ('ti_compile_page 1', self);
  declare _ent any;
  declare _abstract nvarchar;
  declare _diskdumpdir any; -- Name of directory to dump pages; for debugging purposes.
  declare dosioc integer;
  
  if (exists (select top 1 1 from DB.DBA.WA_INSTANCE
     where WAI_TYPE_NAME = 'oWiki' and WAI_NAME = self.ti_cluster_name and WAI_IS_PUBLIC = 1))
   dosioc := 1;
  else
   dosioc := 0;
 
  _diskdumpdir := registry_get ('WikiDiskDump');
  if (isstring (_diskdumpdir))
    {
      declare err any;
      file_mkdir (_diskdumpdir, err);
      file_mkdir (_diskdumpdir || '/' || self.ti_cluster_name, err);
      string_to_file (
        concat (_diskdumpdir, '/', self.ti_cluster_name, '/', self.ti_local_name, '.txt'),
        coalesce (self.ti_text, ''), -2);
    }
  if (self.ti_author_id is null or 0 = self.ti_author_id)
    self.ti_author_id := coalesce ((select U_ID from DB.DBA.SYS_USERS where U_NAME=connection_get ('vspx_user')), http_dav_uid());
  if (dosioc)
    sioc..wiki_sioc_post (self);

  self.ti_local_name_2 := self.ti_local_name;
  self.ti_curuser_wikiname := 'WikiGuest';
  self.ti_curuser_username := 'WikiGuest';
  self.ti_base_adjust := '';
  _ent := self.ti_get_entity (null,1);
  _abstract := xpath_eval ('string(//abstract)', _ent);
  if (_abstract = N'')
    _abstract := null;
  
  delete from WV.WIKI.TOPIC where TopicId = self.ti_id;
  insert into WV.WIKI.TOPIC (TopicId, ClusterId, ResId, LocalName, LocalName2, Abstract, MailBox)
  values (self.ti_id, self.ti_cluster_id, self.ti_res_id, self.ti_local_name, self.ti_local_name_2, _abstract, self.ti_e_mail);
  if (connection_get ('oWiki import') is not null)
    {
      declare _links, _qlinks, _flinks any;
      _links := xpath_eval ('//a[@style="wikiword"][@href]', _ent, 0);
      _qlinks := xpath_eval ('//a[@style="qwikiword"][@href]', _ent, 0);
      _flinks := xpath_eval ('//a[@style="forcedwikiword"][@href]', _ent, 0);

      -- make link with DestId NULL for later processing
      WV.WIKI.update_links (self, _links, 0);
      WV.WIKI.update_links (self, _qlinks, 1);
      WV.WIKI.update_links (self, _flinks, 2);
      return;
    }
-- Processing links
  delete from WV.WIKI.LINK where OrigId = self.ti_id and MadeByDest = 0;
  delete from WV.WIKI.LINK where DestId = self.ti_id and MadeByDest = 1;  
  delete from WV.WIKI.SEMANTIC_OBJ where SO_OBJECT_ID = self.ti_id;
  
  {
    declare _links any;
    declare _ctr, _count integer;
    _links := xpath_eval ('//a[@style="wikiword"][@href] | //a[@style="qwikiword"][@href] | //a[@style="forcedwikiword"][@href]', _ent, 0);
    _count := length (_links);
    _ctr := 0;
    declare _categories, _cat varchar;
    _categories := '';

	declare _a any;
	declare _href, _linktext varchar;
	declare _tgt WV.WIKI.TOPICINFO;
    while (_ctr < _count) {
	_a := aref (_links, _ctr);
	_href := xpath_eval ('@href', _a);
	_linktext := cast (_a as varchar);
	if (length (_linktext) > 200)
	  _linktext := concat (subseq (_linktext, 0, 100 + coalesce (strchr (subseq (_linktext, 100), ' '), 0)), ' ...');
      if (_href like '%.Category%')
        _href := subseq (strchr (_href));
      if (_href like 'Category%') {
	    _cat := lcase (subseq ( cast (_href as varchar), 8));
	    _categories := case when _categories = '' then _cat else _categories || ',' || _cat end;	
	  }
	_tgt := WV.WIKI.TOPICINFO ();
	_tgt.ti_raw_title := _href;
	_tgt.ti_default_cluster := self.ti_cluster_name;
	_tgt.ti_find_id_by_raw_title ();
	if (_tgt.ti_id <> 0)
          {
	    _tgt.ti_find_metadata_by_id ();
          }
	else
	  {
	    _tgt.ti_raw_name := _href;
	    _tgt.ti_cluster_name := self.ti_default_cluster;
	    _tgt.ti_default_cluster := self.ti_default_cluster;
	    _tgt.ti_parse_raw_name();
	  }
	if (not exists 
	  (select top 1 1 from WV.WIKI.LINK
	    where OrigId = self.ti_id and TypeId = 0 and MadeByDest = 0 and
	      DestClusterName = _tgt.ti_cluster_name and
	      DestLocalName = _tgt.ti_local_name ) )
	  {
	    insert into WV.WIKI.LINK (LinkId, TypeId, OrigId, DestId, DestClusterName, DestLocalName, MadeByDest, LinkText)
	    values (WV.WIKI.NEWPLAINLINKID(), 0, self.ti_id, _tgt.ti_id, _tgt.ti_cluster_name, _tgt.ti_local_name, 0, _linktext);
	    if (dosioc)
	      sioc..wiki_sioc_post_links_to (self, _tgt);
	  }
	declare _pred varchar;
	_pred := xpath_eval ('@predicate', _a);
	if (_pred is not null)
	  {
	    WV.WIKI.ADD_FACT (self, cast (_pred as varchar), _tgt.ti_local_name, ':TOPIC');
	  }
        _ctr := _ctr + 1;
      }
    declare _facts, _link any;
    _facts := xpath_eval ('//span[@style="semanticvalue"]', _ent, 0);
    _count := length (_facts);
    _ctr := 0;    
    while (_ctr < _count)
      {
        _link := _facts[_ctr];
        declare _pred varchar;
	declare _value varchar;
	 --dbg_obj_princ ('span=', _link);
	_pred := xpath_eval ('@predicate', _link);
	_value := xpath_eval ('@value', _link);
	if (_pred is not null and _value is not null)
	  {
	    WV.WIKI.ADD_FACT (self, cast (_pred as varchar), cast (_value as varchar), ':VALUE');
	  }
	_ctr := _ctr + 1;
      }
    update WV.WIKI.LINK
       set DestId = self.ti_id
     where DestId = 0
       and DestClusterName = self.ti_cluster_name
       and DestLocalName = self.ti_local_name;

    if ((_categories <> '') and
	(WV.WIKI.CLUSTERPARAM (self.ti_cluster_id, 'delicious_enabled', 2) = 1))
      WV.WIKI.DELICIOUSPUBLISH (self.ti_id, split_and_decode (_categories, 0, '\0\0,'));
    

    WV.WIKI.DELETE_INLINE_MACRO_FUNCS_1 (self);
    foreach (any _exec in xpath_eval ('//processing-instruction("inline")', _ent, 0)) do {
      declare _name, _proc varchar;
      _exec := cast (xpath_eval ('string(.)', _exec) as varchar);
      _name := WV.WIKI.INLINE_MACRO_NAME (self.ti_cluster_name, self.ti_local_name, md5(_exec));
      _proc := WV.WIKI.INLINE_MACRO_FUNCTION (_name, _exec);
     exec (_proc);
    }
    foreach (any _abs_link in xpath_eval ('//a[@style = "absuri"][@href]/@href', _ent, 0)) do {
      sioc..wiki_sioc_post_links_to_2 (self, _abs_link);
    }      
    foreach (any _att in xpath_eval ('//Attach/@Name', _ent, 0)) do {
      sioc..wiki_sioc_attachment (self, _att);
  }
    --sioc..ods_sioc_tags (sioc..get_graph(),
    --	sioc..wiki_post_iri (self.ti_cluster_name, self.ti_cluster_id, self.ti_local_name),
    --	_categories);
    if (xpath_eval('//processing-instruction("ping")', _ent, 0) is not null) {
      -- WIKTOLOGY..queue_ping(sprintf ('http://%s/wiki/main/%s/%s?command=ontology', sioc..get_cname(), self.ti_cluster_name, self.ti_local_name));
      ;
    }
}
}
;

use DB
;

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

create procedure WA_SEARCH_DAV_OR_WIKI_GET_EXCERPT_HTML (
   in current_user_id integer,
   in RES_ID integer,
	 in _WORDS_VECTOR any,
	 in RES_CONTENT any,
	 in RES_FULL_PATH varchar,
   in RES_OWNER integer,
   in RES_COL integer)
{
  if (exists (select 1 from WV.WIKI.CLUSTERS where ColId = RES_COL))
    return WA_SEARCH_WIKI_GET_EXCERPT_HTML (current_user_id, RES_ID, _WORDS_VECTOR, RES_CONTENT, RES_FULL_PATH, RES_OWNER);
  else
    return WA_SEARCH_DAV_GET_EXCERPT_HTML (current_user_id, RES_ID, _WORDS_VECTOR, RES_CONTENT, RES_FULL_PATH);
}
;


create procedure WV.WIKI.UPDATE_LINKS (
	in _topic WV.WIKI.TOPICINFO,
	in _links any,
  in _type integer) -- 0 - WikiWord, 1 - Qualified WW, 2 - forcedlink
{
  foreach (any _a in _links) do
    {
      WV.WIKI.UPDATE_LINK_1 (_topic, cast (xpath_eval ('@href', _a) as varchar), _type);
    }
}
;

  
create procedure WV.WIKI.UPDATE_LINK_1 (
	in _topic WV.WIKI.TOPICINFO,
	in _href varchar,
  in _type integer) -- 0 - WikiWord, 1 - Qualified WW, 2 - forcedlink
{
  declare _cluster varchar;
  declare _local_name varchar;
   --dbg_obj_princ ('link:{{ ', _topic.ti_local_name, ' ', _href, ' ', _type);
  

  if (_type = 0)
    {
      _cluster := _topic.ti_cluster_name;
      _local_name := _href;
    }
  else if (_type = 1)
    {
      declare _aux any;
      _aux := split_and_decode (_href, 0, '\0\0.');      
      _cluster := _aux[0];
      _local_name := _aux[1];
    }
  else if (_type = 2)
    {
      _cluster := _topic.ti_cluster_name;
      _local_name := trim (_href);
    }
  else
    return;
  if (not exists (select * from WV.WIKI.LINK where
	OrigId = _topic.ti_id
	and DestClusterName = _cluster
	and DestLocalName = _local_name))
    {
      --dbg_obj_princ ('}}done');
      insert into WV.WIKI.LINK (LinkId, TypeId, OrigId, DestId, DestClusterName, DestLocalName, MadeByDest, LinkText)
	values (WV.WIKI.NEWPLAINLINKID(), 0, _topic.ti_id, NULL, _cluster, _local_name, 0, NULL);
    }
  return;
}
;
  	
 
create function WV.WIKI.POSTPROCESS_LINKS (in _cluster_id integer)
{
  for select LinkId as _link_id, c.ClusterId as DestClusterId, 
  	DestLocalName, t.LocalName as FromLocalName,
	DestClusterName
   from WV.WIKI.LINK inner join WV.WIKI.TOPIC t
    on (t.TopicId = OrigId) inner join WV.WIKI.CLUSTERS c
    on (c.ClusterName = DestClusterName)
    where t.ClusterId = _cluster_id
     and DestId is null
  do {
    for select top 1 TopicId from WV.WIKI.TOPIC 
      where LocalName = DestLocalName
      and ClusterId = DestClusterId
    do {
      update WV.WIKI.LINK set DestId = TopicId
       where LinkId = _link_id;
       --dbg_obj_princ (_link_id, ' new link from ', FromLocalName, ' to ', DestClusterName, '.', DestLocalName);
    }
  }
  delete from WV.WIKI.LINK 
    where DestId is NULL or DestId = 0 
    and exists (select * from WV.WIKI.TOPIC where TopicId = OrigId and ClusterId = _cluster_id);
}
;


-- _res_is_vect means result in vector
-- _total - number of version in report, 0 means not such constraint
create method ti_revisions(in _res_is_vect integer, in _total integer) returns any for WV.WIKI.TOPICINFO
{
  declare exit handler for NOT FOUND
  {
    return null;
  };
  declare exit handler for sqlstate '*'
  {
    --dbg_obj_print (__SQL_STATE, __SQL_MESSAGE);
    resignal;
  };

  declare _res, _ent any;
  declare path, revs varchar;
  if (_res_is_vect)
    vectorbld_init (_res);
  else
    _res := XMLELEMENT ('Versions');
  path := DB.DBA.DAV_SEARCH_PATH (self.ti_col_id, 'C') || 'VVC/' || self.ti_local_name || '.txt/';
  revs := DB.DBA.DAV_DIR_LIST (path, 0, 'dav', (select pwd_magic_calc (U_NAME, U_PWD, 1) from WS.WS.SYS_DAV_USER where U_ID = http_dav_uid()));
  declare _max, _min integer;
  _max := 0;
  _min := -1;
  if (isarray (revs))
    {
      if (not _res_is_vect)
        _ent := xpath_eval ('/Versions', _res);
      declare idx integer;
      for (idx := length (revs) - 1 ; idx >= 0; idx:=idx - 1)
        {	
	  declare _file any;
	  _file := aref (revs, idx);
	  if ( (aref (_file, 1) = 'R') or (aref (_file, 1) = 'r') )
	    {
	      if ( ( aref (_file, 10) <> 'history.xml' ) and
	      	   ( aref (_file, 10) <> 'last' ) and
		   ( aref (_file, 10) not like '%.diff') )
	        {
      declare _num integer;
		  _num := atoi (aref (_file, 10));
		  if (_min < 0)
		    _min := _num;
		  if (_num > _max)
		    _max := _num;
		  if (_num < _min)
		    _min := _num;
	 	}
	    }
	}
      --dbg_obj_print (_max, _min);
      if (_total and (_max - _min > WV.WIKI.MAX_REVS_IN_REPORT()))
	{
	  _min := _max - WV.WIKI.MAX_REVS_IN_REPORT();
	  XMLAppendChildren (_ent, XMLELEMENT ('RevCont'));
        }
      if (_min > 0)
  	{
	  for (idx := _min; idx <= _max; idx := idx + 1)
	    {
        declare _i integer;
	      _i := idx;
	      if (_res_is_vect)
	        vectorbld_acc (_res, cast (_i as varchar));
	      else
	  	XMLAppendChildren (_ent, XMLELEMENT ('Rev', 
		 	XMLATTRIBUTES (idx as Number)));
	    }
	}
    }  
  if (_res_is_vect)
    vectorbld_final (_res);
  return _res;
}
;

create function WV.WIKI.MAX_REVS_IN_REPORT ()
{ 
  return 2;
}
;
--  xtree_doc ('<Versions><Rev Number="1"/><Diff/><Rev Number="2"/></Versions>'), self.ti_report_mails());

create method ti_report_attachments () returns any for WV.WIKI.TOPICINFO
{
  declare _dav_path varchar;
  _dav_path := DB.DBA.DAV_SEARCH_PATH (self.ti_col_id, 'C') || self.ti_local_name || '/';

  declare _dir_list, _res, _ent, _attachment any;
  _dir_list := DAV_DIR_LIST (_dav_path, 0, 'dav', (select pwd_magic_calc (U_NAME, U_PWD, 1) from WS.WS.SYS_DAV_USER where U_ID = http_dav_uid()));

  _res := XMLELEMENT ('ATTACHMENTS');
  _ent := xpath_eval ('/ATTACHMENTS', _res);

  if (_dir_list is null)
	return _res;
  if (not isarray (_dir_list))
	return _res;
  foreach (any _file in _dir_list) do {
	if ( (aref (_file, 1) = 'R') or (aref (_file, 1) = 'r') ) {
		_attachment := XMLELEMENT ('Attach',
				XMLATTRIBUTES (
         self.ti_cluster_name as "Cluster",
				 self.ti_local_name as Topic,
				 aref (_file, 10) as Name,
				 aref (_file, 0) as Path,
				 WV.WIKI.DATEFORMAT (aref (_file, 3)) as "ModTime",
				 WV.WIKI.PRINTLENGTH (aref (_file, 2)) as "Size",
				 WV.WIKI.DATEFORMAT (aref (_file, 8)) as "Date",
				 aref (_file, 9) as Type,
				 aref (_file, 5) as Permissions,
				 (select UserName from WV.WIKI.USERS where UserId = aref (_file, 7)) as Owner),
				XMLELEMENT ('Comment', coalesce ((select Description from WV.WIKI.ATTACHMENTINFONEW where ResPath = aref (_file, 0)), '')));
		XMLAppendChildren (_ent, _attachment);
   	}
  }
  return _res;
}
;

create method ti_report_mails () returns any for WV.WIKI.TOPICINFO
{
  connection_set ('WIKIV Cluster', self.ti_cluster_name);
  return WV.WIKI.MAILBOXLIST (self.ti_id);
}
;

create procedure WV.WIKI.DOTREEPARENT (in _topic_id integer, in _ent any, in depth integer)
{
  if (depth > WV.WIKI.MAXPARENTDEPTH())
    return _ent;
  for select top 1 ParentId, LocalName, ClusterName 
	       from WV.WIKI.TOPIC t, WV.WIKI.CLUSTERS c
	       where TopicId = _topic_id 
	       and c.ClusterId = t.ClusterId
	       
  do {	       
    XMLAppendChildren (_ent, 
       XMLELEMENT ('Parent',
	   XMLATTRIBUTES (ClusterName as CLUSTERNAME,
			  LocalName as LOCALNAME,
			  depth as DEPTH)));
    if (ParentId > 0) {
      WV.WIKI.DOTREEPARENT (ParentId, _ent, depth + 1);
    } else {
      XMLAppendChildren (_ent, 
			 XMLELEMENT ('Parent',
				     XMLATTRIBUTES (ClusterName as CLUSTERNAME,
						    '' as LOCALNAME,
						    (depth + 1) as DEPTH)));
      XMLAppendChildren (_ent, 
			 XMLELEMENT ('Parent',
				     XMLATTRIBUTES ('Main' as CLUSTERNAME,
						    WV.WIKI.DASHBOARD() as LOCALNAME,
						    (depth + 2) as DEPTH)));
    }
  }
}
;
					  
create method ti_wiki_path () returns any for WV.WIKI.TOPICINFO
{
  if (self.ti_local_name = WV.WIKI.DASHBOARD() and self.ti_cluster_name = 'Main')
    return xtree_doc ('<WikiPath><Parent CLUSTERNAME="Main" LOCALNAME="Dashboard"/></WikiPath>');
  declare _doc any;
  _doc := xtree_doc ('<WikiPath></WikiPath>');
  WV.WIKI.DOTREEPARENT (self.ti_id, xpath_eval ('/WikiPath', _doc), 0);
  return _doc;
  
}
;


create constructor method TOPICINFO () for WV.WIKI.TOPICINFO
{
  -- These assignments are there due to bugs in assigning default values
  -- to instance. Briefly speaking, '...default XXX' in member declaration may
  -- be ignored by server. Weird bug.
  self.ti_id := 0;
  self.ti_res_id := 0;
  self.ti_type_id := 0;
  self.ti_cluster_id := 0;
  self.ti_col_id := 0;
  self.ti_col_history_id := 0;
  self.ti_col_attach_id := 0;
  self.ti_col_xml_id := 0;
  self.ti_cluster_admin_id := 0;
  self.ti_author_id := 0;
  self.ti_curuser_wikiname := 'WikiEngineAdmin';
  self.ti_curuser_username := 'Wiki';
  self.ti_base_adjust := '';
  self.ti_attach_col_id := 0;
  self.ti_attach_col_id_2 := 0;
  self.ti_env := vector();
}
;

create method ti_res_name () for WV.WIKI.TOPICINFO
{
  return self.ti_local_name || '.txt';
}
;

create method ti_update_text (in _text varchar, in _auth varchar) for WV.WIKI.TOPICINFO
{
  declare _owner varchar;
  select U_NAME into _owner from WS.WS.SYS_DAV_RES, DB.DBA.SYS_USERS 
	where RES_ID = self.ti_res_id
	and U_ID = RES_OWNER;
  
  WV.WIKI.UPLOADPAGE (
     self.ti_col_id,
     self.ti_res_name(),
     _text,
     _owner,
     self.ti_cluster_id,
     _auth);
  return NULL;
}
;

create method ti_full_path () for WV.WIKI.TOPICINFO
{
  declare _full_path varchar;
  _full_path := (select RES_FULL_PATH from WS.WS.SYS_DAV_RES where RES_ID = self.ti_res_id);
  if (_full_path is null)
    return DB.DBA.DAV_SEARCH_PATH (self.ti_col_id, 'C') || self.ti_local_name || '.txt';
  return _full_path;
}
;

create method ti_get_tags () for WV.WIKI.TOPICINFO
{
  --dbg_obj_print ('get_tags');
  
  declare exit handler for sqlstate '*' {
    --dbg_obj_print (__SQL_STATE, __SQL_MESSAGE);
    resignal;
  }
  ;
  declare _tags any;
  declare _nobody_uid, _curr_uid integer;
  --dbg_obj_print ('get_tags 1');
  _nobody_uid := (select U_ID from DB.DBA.SYS_USERS where U_NAME = 'nobody');
  --dbg_obj_print ('get_tags 2');
  _curr_uid := (select U_ID from DB.DBA.SYS_USERS where U_NAME = self.ti_curuser_username);
  --dbg_obj_print ('get_tags 3');
  
  
  _tags := DAV_HIDE_ERROR (DAV_TAG_LIST (self.ti_res_id, 'R', vector (_curr_uid, _nobody_uid)));
  --dbg_obj_print (_tags);
  if (_tags is not null)
    {
      declare _public_tags, _pub_ent any;
      declare _private_tags, _priv_ent any;
      _public_tags := XMLELEMENT ('tagset', XMLATTRIBUTES ('public' as "type"));
      _private_tags := XMLELEMENT ('tagset', XMLATTRIBUTES ('private' as "type"));
      _pub_ent := xpath_eval ('/tagset', _public_tags);
      _priv_ent := xpath_eval ('/tagset', _private_tags);
      foreach (any taginfo in _tags) do
        {
	  foreach (varchar tag in split_and_decode (taginfo[1], 0, '\0\0,')) do
	    {
	      if (taginfo[0] = _nobody_uid) -- public tags
	        XMLAppendChildren (_pub_ent, XMLELEMENT ('tag', XMLATTRIBUTES (tag as "name")));
	      else
	        XMLAppendChildren (_priv_ent, XMLELEMENT ('tag', XMLATTRIBUTES (tag as "name")));
	    }
	}
      return XMLELEMENT ('tags', _public_tags, _private_tags);
    }
  return NULL;
}
;

-- Triggers
create trigger "Wiki_ClusterDeleteContent" before delete on WV.WIKI.CLUSTERS referencing old as O
{
  declare exit handler for sqlstate '*'
{
 	resignal;
  }; 
  DB.DBA.DAV_DELETE (WS.WS.COL_PATH(O.ColId), 1, 'dav', (select pwd_magic_calc (U_NAME, U_PWD, 1) from WS.WS.SYS_DAV_USER where U_ID = http_dav_uid()));
  delete from WA_INSTANCE where WAI_TYPE_NAME = 'oWiki' and (WAI_INST as wa_wikiv).cluster_id = O.ClusterId;
  delete from WV.WIKI.CLUSTERSETTINGS where ClusterId = O.ClusterId;
  delete from WA_MEMBER where WAM_APP_TYPE = 'oWiki' and WAM_INST = O.ClusterName;
  WV.WIKI.USERROLE_DROP(O.ClusterName || 'Readers');
  WV.WIKI.USERROLE_DROP(O.ClusterName || 'Writers');
  DB.DBA.VHOST_REMOVE(lpath=>'/wiki/' || O.ClusterName);
}
;

create procedure WV.WIKI.SIOC_ADD_ATTACHMENT (inout _topic WV.WIKI.TOPICINFO, in att varchar)
    {
   sioc..wiki_sioc_attachment (_topic, att);
}
;

wiki_exec_no_error ('drop trigger WS.WS.Wiki_ClusterInsert')
;
wiki_exec_no_error ('drop trigger WS.WS.Wiki_ClusterUpdate')
;
wiki_exec_no_error ('drop trigger WS.WS.Wiki_ClusterDelete')
;

-- new triggers
wiki_exec_no_error ('drop trigger WS.WS.WIKI_SYS_DAV_PROP_AI')
;
create trigger "WIKI_SYS_DAV_PROP_AI" after insert on WS.WS.SYS_DAV_PROP order 100 referencing new as N
{
  declare exit handler for sqlstate '*' {
 	resignal;
  }; 

  if ((N.PROP_NAME <> 'WikiCluster') or (N.PROP_TYPE <> 'C'))
    return;

  for (select COL_OWNER, COL_GROUP from WS.WS.SYS_DAV_COL where COL_ID = N.PROP_PARENT_ID) do
    WV.WIKI.CREATECLUSTER (N.PROP_VALUE, N.PROP_PARENT_ID, COL_OWNER, coalesce (COL_GROUP, WV.WIKI.WIKIADMINGID()));
}
;

wiki_exec_no_error ('drop trigger WS.WS.WIKI_SYS_DAV_PROP_BU')
;
create trigger "WIKI_SYS_DAV_PROP_BU" before update on WS.WS.SYS_DAV_PROP order 100 referencing old as O, new as N
{
  if ((O.PROP_NAME = 'WikiCluster' or N.PROP_NAME = 'WikiCluster') and (N.PROP_TYPE = 'C'))
    WV.WIKI.APPSIGNAL (11001, 'Cluster "&ClusterName;" can not be changed by updating DAV property WikiCluster', vector ('ClusterName', O.PROP_VALUE));
}
;

wiki_exec_no_error ('drop trigger WS.WS.WIKI_SYS_DAV_PROP_BD')
;
create trigger "WIKI_SYS_DAV_PROP_BD" before delete on WS.WS.SYS_DAV_PROP order 100 referencing old as O
{
  declare exit handler for sqlstate '*'
    {
    resignal;
  };

  if ((O.PROP_NAME <> 'WikiCluster') or (O.PROP_TYPE <> 'C'))
    return;

  for (select ClusterId from WV.WIKI.CLUSTERS where ClusterName = O.PROP_VALUE or ColId = O.PROP_PARENT_ID) do
    DeleteCluster (ClusterId);
}
;

wiki_exec_no_error ('drop trigger WS.WS.Wiki_TopicTextInsertMeta')
;
wiki_exec_no_error ('drop trigger WS.WS.Wiki_TopicTextInsert')
;
wiki_exec_no_error ('drop trigger WS.WS.Wiki_TopicTextInsertPerms')
;
wiki_exec_no_error ('drop trigger WS.WS.Wiki_TopicTextAttachment')
;
wiki_exec_no_error ('drop trigger WS.WS.Wiki_TopicTextSparql_AI')
;
wiki_exec_no_error ('drop trigger WS.WS.Wiki_TopicTextUpdate')
;
wiki_exec_no_error ('drop trigger WS.WS.Wiki_TopicTextUpdatePerms')
;
wiki_exec_no_error ('drop trigger WS.WS.Wiki_TopicTextSparql_AU')
;
wiki_exec_no_error ('drop trigger WS.WS.Wiki_TopicTextDelete')
;
wiki_exec_no_error ('drop trigger WS.WS.Wiki_TopicTextAttachment_D')
;
wiki_exec_no_error ('drop trigger WS.WS.Wiki_AttachmentDelete')
;

-- new triggers
wiki_exec_no_error ('drop trigger WS.WS.WIKI_SYS_DAV_RES_AI')
;
create trigger "WIKI_SYS_DAV_RES_AI" after insert on WS.WS.SYS_DAV_RES order 1 referencing new as N
{
  declare _id any;
  declare _cluster_name varchar;
  declare _topic WV.WIKI.TOPICINFO;
  declare exit handler for sqlstate '*'
  {
    -- dbg_obj_princ (__SQL_STATE, __SQL_MESSAGE);
    rollback work;
   return;
  };

  _cluster_name := (select ClusterName from WV.WIKI.CLUSTERS where ColId = N.RES_COL);
  if (not isnull (_cluster_name))
  {
    if (N.RES_NAME like '%.txt')
    {
      -- Topic Insert
      _topic := WV.WIKI.TOPICINFO ();
      _topic.ti_cluster_name := _cluster_name;
      _topic.ti_fill_cluster_by_name ();
      _topic.ti_id := WV.WIKI.NEWPLAINTOPICID ();
      _topic.ti_res_id := N.RES_ID;
      _topic.ti_default_cluster := _cluster_name;
      _topic.ti_local_name := WV.WIKI.FILENAMETOWIKINAME (cast (N.RES_NAME as varchar));
      _topic.ti_text := cast (N.RES_CONTENT as varchar);
      _topic.ti_e_mail := WV.WIKI.MAILBOXFORTOPICNEW (_topic.ti_id, _cluster_name, _topic.ti_local_name);
      _topic.ti_compile_page ();
      _topic.ti_register_for_upstream('I');
      WV..ADD_HIST_ENTRY (_topic.ti_cluster_name, _topic.ti_local_name, 'N', '1.0');

      if (exists (select * from DB.DBA.WA_MEMBER where WAM_INST = _topic.ti_cluster_name and WAM_APP_TYPE = 'oWiki' and WAM_IS_PUBLIC = 1) and __proc_exists ('DB.DBA.WA_NEW_WIKI_IN'))
      {
        for (select U_FULL_NAME, U_NAME from DB.DBA.SYS_USERS where U_ID = N.RES_OWNER) do
        {
          _topic.ti_fill_url();
          DB.DBA.WA_NEW_WIKI_IN (WV.WIKI.NORMALIZEWIKIWORDLINK (_topic.ti_cluster_name, _topic.ti_local_name), _topic.ti_url || '?', _topic.ti_id);
          insert into WV.WIKI.DASHBOARD (WD_TIME, WD_TITLE, WD_UNAME, WD_UID, WD_URL)
            values (now(), subseq (_topic.ti_text, 0, 200), U_FULL_NAME, U_NAME, _topic.ti_url || '?');
        }
      }

      -- Topic Update Permissions
  SET TRIGGERS OFF;
  WV.WIKI.UPDATEGRANTS_FOR_RES_OR_COL ( _cluster_name, N.RES_ID, 'R');
  SET TRIGGERS ON;

      -- Topic Sparql
      if (N.RES_TYPE = 'application/sparql-query')
        WV.WIKI.TopicTextSparql (N.RES_COL, N.RES_FULL_PATH, N.RES_OWNER);
    }
  }

  -- attachment
  _id :=  DB.DBA.DAV_HIDE_ERROR (DB.DBA.DAV_PROP_GET_INT(N.RES_COL, 'C', 'oWiki:topic-id', 0));
  if (not isnull(_id))
    {
      declare _topic WV.WIKI.TOPICINFO;

      _topic := WV.WIKI.TOPICINFO();
    _topic.ti_id := deserialize (_id);
      _topic.ti_find_metadata_by_id ();
    if (_topic.ti_res_id)
    {
        WV.WIKI.SIOC_ADD_ATTACHMENT (_topic, N.RES_NAME);
        WV..ADD_HIST_ENTRY(_topic.ti_cluster_name, _topic.ti_local_name, 'A', N.RES_NAME);
      }
    }
}
;

wiki_exec_no_error ('drop trigger WS.WS.WIKI_SYS_DAV_RES_AU')
;
create trigger "WIKI_SYS_DAV_RES_AU" after update on WS.WS.SYS_DAV_RES order 1 referencing old as O, new as N
{
  declare _id integer;
  declare _cluster_name, _local_name varchar;
  declare _topic WV.WIKI.TOPICINFO;
  declare exit handler for sqlstate '*'
  {
    --dbg_obj_princ (__SQL_STATE, __SQL_MESSAGE);
    resignal;
  };
  if (N.RES_NAME like '%.txt')
  {
    _id := coalesce ((select TopicId from WV.WIKI.TOPIC where ResId = O.RES_ID), 0);
    if (((O.RES_ID <> N.RES_ID) or (O.RES_COL <> N.RES_COL)) and (_id <> 0))
      WV.WIKI.DELETETOPIC (_id);

    _cluster_name := (select ClusterName from WV.WIKI.CLUSTERS where ColId = N.RES_COL);
    if (not isnull (_cluster_name))
{
      if (O.RES_CONTENT <> N.RES_CONTENT)
    {
      _topic := WV.WIKI.TOPICINFO();
        _topic.ti_cluster_name := _cluster_name;
        _topic.ti_fill_cluster_by_name ();
        _local_name := WV.WIKI.FILENAMETOWIKINAME (cast (N.RES_NAME as varchar));
        if (_id = 0)
	{
          _id := WV.WIKI.NEWPLAINTOPICID ();
          _topic.ti_e_mail := WV.WIKI.MAILBOXFORTOPICNEW (_id, _cluster_name, _local_name);
          WV..ADD_HIST_ENTRY(_cluster_name, _local_name, 'N', '');
	}
        else
        {
          _topic.ti_e_mail := (select MailBox from WV.WIKI.TOPIC where TopicId = _id);
          WV..ADD_HIST_ENTRY(_cluster_name, _local_name, 'U', sprintf ('1.%d', coalesce((select max(RV_ID) from ws.ws.sys_dav_res_version where RV_RES_ID = N.RES_ID), 1)));
    }
        _topic.ti_id := _id;
        _topic.ti_res_id := N.RES_ID;
        _topic.ti_default_cluster := _cluster_name;
        _topic.ti_local_name := _local_name;
        _topic.ti_text := cast (N.RES_CONTENT as varchar);
        _topic.ti_compile_page ();
        _topic.ti_register_for_upstream ('U');
}

      -- Topic Update Permissions
  SET TRIGGERS OFF;
  WV.WIKI.UPDATEGRANTS_FOR_RES_OR_COL ( _cluster_name, N.RES_ID, 'R');
  SET TRIGGERS ON;

      -- Topic Sparql
      if (N.RES_TYPE = 'application/sparql-query')
        WV.WIKI.TopicTextSparql (N.RES_COL, N.RES_FULL_PATH, N.RES_OWNER);
    }
  }
}
;

wiki_exec_no_error ('drop trigger WS.WS.WIKI_SYS_DAV_RES_BD')
;
create trigger "WIKI_SYS_DAV_RES_BD" before delete on WS.WS.SYS_DAV_RES order 1 referencing old as O
{
  declare _id integer;
  declare _cluster_name varchar;
  declare _topic WV.WIKI.TOPICINFO;
  declare exit handler for sqlstate '*'
{
    --dbg_obj_princ (__SQL_STATE, __SQL_MESSAGE);
    resignal;
  };
  if (O.RES_NAME like '%.txt')
  {
    _id := (select TopicId from WV.WIKI.TOPIC where ResId = O.RES_ID);
    if (not isnull (_id))
{
  _topic := WV.WIKI.TOPICINFO();
  _topic.ti_id := _id;
  _topic.ti_find_metadata_by_id ();
  _topic.ti_register_for_upstream ('D');
  sioc..wiki_sioc_post_delete (_topic);
  WV..ADD_HIST_ENTRY(_topic.ti_cluster_name, _topic.ti_local_name, 'D', '');
  delete from WV.WIKI.SEMANTIC_OBJ where SO_OBJECT_ID = _id;
  WV.WIKI.DELETETOPIC (_id);
  WV.WIKI.DELETE_INLINE_MACRO_FUNCS_1 (_topic);
      for (select P_NAME from DB.DBA.SYS_PROCEDURES where P_NAME like WV.WIKI.INLINE_MACRO_NAME (_topic.ti_cluster_name, _topic.ti_local_name, null)) do
      {
    exec ('drop procedure ' || P_NAME);
  }
}
    }
  _id := DB.DBA.DAV_HIDE_ERROR (DB.DBA.DAV_PROP_GET_INT (O.RES_COL, 'C', 'oWiki:topic-id', 0));
  if (not isnull (_id))
    {
    _topic := WV.WIKI.TOPICINFO();
    _topic.ti_id := deserialize (_id);
    _topic.ti_find_metadata_by_id ();
    if (_topic.ti_res_id)
    {
      sioc..wiki_sioc_attachment_delete (_topic, O.RES_NAME);
      WV..ADD_HIST_ENTRY(_topic.ti_cluster_name, _topic.ti_local_name, 'a', O.RES_NAME);
    }
}
	delete from WV.WIKI.ATTACHMENTINFONEW where ResPath = O.RES_FULL_PATH;
}
;

-- Rendering routines
create function WV.WIKI.NORMALIZEWIKIWORDLINK (
  inout _default_cluster varchar,
  inout _href varchar) returns varchar
{
  -- Converts dirty WikiLink to a proper normalized qualified WikiLink.
  declare _topic WV.WIKI.TOPICINFO;

  _topic := WV.WIKI.TOPICINFO ();
  _topic.ti_raw_name := _href;
  _topic.ti_default_cluster := _default_cluster;
  _topic.ti_parse_raw_name ();
  return concat (_topic.ti_cluster_name, '.', _topic.ti_local_name);
}
;

grant execute on WV.WIKI.NORMALIZEWIKIWORDLINK to public
;

create function WV.WIKI.READONLYWIKIWORDLINK (
  in _default_cluster varchar,
  in _href varchar) returns varchar
{
  -- Converts dirty WikiLink into link in form Cluster/LocalName
  declare _topic WV.WIKI.TOPICINFO;

  _topic := WV.WIKI.TOPICINFO ();
  _topic.ti_raw_name := _href;
  _topic.ti_default_cluster := _default_cluster;
  _topic.ti_parse_raw_name ();
  if (_topic.ti_cluster_name = '')
    return '';

  return _topic.ti_cluster_name || '/' || _topic.ti_local_name;
}
;

create function WV.WIKI.READONLYWIKIWORDHREF2 (
  inout _cluster_name varchar,
  inout _topic_name varchar,
  in _sid varchar,
  in _realm varchar,
  in _params any := '') returns varchar
{
  declare url_params varchar;

  if (isstring (_params))
    url_params :=  WV.WIKI.URL_PARAMS (_params);

  if (url_params = '')
  {
    if (isstring(_sid) and _sid <> '')
      url_params := 'sid=' || _sid;
    if (isstring(_realm) and _realm <> '')
      if (url_params <> '')
      {
        url_params := url_params || '&realm=' || _realm;
      } else {
      url_params := 'realm=' || _realm;
    }
  }
  if (url_params <> '')
    return sprintf ('%s%s?%s', WV.WIKI.wiki_cluster_uri (_cluster_name), _topic_name, url_params);

  return sprintf ('%s%s', WV.WIKI.wiki_cluster_uri (_cluster_name), _topic_name);

}
;

create function WV.WIKI.READONLYWIKIIRI (
  in _cluster_name varchar,
  in _topic_name varchar) returns varchar
{
  return sprintf ('%s%s', WV.WIKI.wiki_cluster_uri (_cluster_name), _topic_name);
}
;

create procedure WV.WIKI.wiki_cluster_uri (in cluster_name varchar)
{
  cluster_name := cast (cluster_name as varchar);
  declare owner varchar;
  owner := WV.WIKI.CLUSTERPARAM (cluster_name, 'creator');
  return sprintf ('%s%s%s/%U/wiki/%U/', case when is_https_ctx () then 'https://' else 'http://' end, WV.WIKI.http_name (), SIOC..get_base_path (), owner, cluster_name);
}
;

create procedure WV.WIKI.wiki_post_uri (in cluster_name varchar, in cluster_id integer, in localname varchar)
{
  cluster_name := cast (cluster_name as varchar);
  declare owner varchar;
  owner := WV.WIKI.CLUSTERPARAM (cluster_id, 'creator');
  return sprintf ('http://%s%s/%U/wiki/%U/%U', WV.WIKI.http_name (), SIOC..get_base_path (), owner, cluster_name, localname);
}
;

create procedure WV.Wiki.WIKI_APLUSCALENDAR(
in user_id integer)
{
    declare S, T any;
    declare app integer;
    app := DB.DBA.WA_USER_APP_ENABLE (user_id);
    S :=
        '\n<link rel="stylesheet" href="/ods/winrect.css" type="text/css"></link>' ||
        '\n<script type="text/javascript">                                       ' ||
        '\n  // OAT                                                              ' ||
        '\n  var toolkitPath="/ods/oat";                                         ' ||
        '\n  var imagePath="/ods/images/oat/";                                   ' ||
        '\n  var featureList=["ajax","anchor"];                                 ' ||
        '\n</script>                                                             ' ||
        '\n<script type="text/javascript" src="/ods/oat/loader.js"></script>     ' ||
        '\n<script type="text/javascript" src="/ods/app.js"></script>            ' ||
        '\n<script type="text/javascript" src="js/CalendarPopup.js"></script>    ' ||
        '\n<script type="text/javascript">                                       ' ||
        '\n  // CalendarPopup                                                    ' ||
        '\n  var cPopup;                                                         ' ||
        '\n  function wikiInit()                                                 ' ||
        '\n  {                                                                   ' ||
        '\n    // CalendarPopup                                                  ' ||
        '\n    if (\$("cDiv"))                                                   ' ||
        '\n    {                                                                 ' ||
        '\n      cPopup = OAT.Browser.isWebKit? new CalendarPopup(): new CalendarPopup("cDiv");  ' ||
        '\n      cPopup.weekStartDay = <?V case when self.cWeekStarts = "s" then 0 else 1 end ?>;' ||
        '\n    }                                                                 ' ||
        '\n    OAT.Preferences.imagePath = "/ods/images/oat/";                   ' ||
        '\n    OAT.Anchor.imagePath = OAT.Preferences.imagePath;                 ' ||
        '\n    OAT.Anchor.zIndex = 1001;                                         ' ||
        '\n    if (%d > 0) {                                                     ' ||
        '\n      var e = \$("attachments_table");                                ' ||
        '\n      if (e)                                                          ' ||
        '\n      {                                                               ' ||
        '\n        var appLinks = e.getElementsByTagName("a");                   ' ||
        '\n        for (var i = 0; i < appLinks.length; i++)                     ' ||
        '\n        {                                                             ' ||
        '\n          var app = appLinks[i];                                      ' ||
        '\n          OAT.Dom.addClass (app, "noapp");                            ' ||
        '\n        }                                                             ' ||
        '\n      }                                                               ' ||
        '\n      var e = \$("content");                                          ' ||
        '\n      if (e)                                                          ' ||
        '\n      {                                                               ' ||
        '\n        var appLinks = e.getElementsByTagName("a");                   ' ||
        '\n        for (var i = 0; i < appLinks.length; i++)                     ' ||
        '\n        {                                                             ' ||
        '\n          var app = appLinks[i];                                      ' ||
        '\n          var search;                                                 ' ||
        '\n          if (!app.id)                                                ' ||
        '\n          {                                                           ' ||
        '\n            if ((app.childNodes.length == 1) && (app.childNodes[0].tagName == "IMG")) ' ||
        '\n            {                                                         ' ||
        '\n          	   search = app.childNodes[0].getAttribute("alt");         ' ||
        '\n            }                                                         ' ||
        '\n            else                                                      ' ||
        '\n            {                                                         ' ||
        '\n         	   search = app.innerHTML;                                 ' ||
        '\n            }                                                         ' ||
        '\n            if (search && (search.length > 1))                        ' ||
        '\n              app.id = "link_" + i;                                   ' ||
        '\n          }                                                           ' ||
        '\n        }                                                             ' ||
        '\n      generateAPP("content", {title:"Related links", appActivation: "%s", useRDFB: %s});     ' ||
        '\n      }                                                               ' ||
        '\n    }                                                                 ' ||
        '\n  }                                                                   ' ||
        '\n  OAT.MSG.attach(OAT, "OAT_LOAD", wikiInit);                    ' ||
        '\n</script>                                                             ';

  return sprintf (S, app, case when app = 2 then 'hover' else 'click' end, case when wa_check_package ('OAT') then 'true' else 'false' end);
}
;

create procedure WV.Wiki.WIKI_APLUSLINK(
in user_id integer)
{
    declare S, T any;
    declare app integer;
    app := DB.DBA.WA_USER_APP_ENABLE (user_id);
    S :=
        '\n<link rel="stylesheet" href="/ods/winrect.css" type="text/css"></link>' ||
        '\n<script type="text/javascript">                                       ' ||
        '\n  // OAT                                                              ' ||
        '\n  var toolkitPath="/ods/oat";                                         ' ||
        '\n  var imagePath="/ods/images/oat/";                                   ' ||
        '\n  var featureList=["ajax","anchor"];                                 ' ||
        '\n</script>                                                             ' ||
        '\n<script type="text/javascript" src="/ods/oat/loader.js"></script>     ' ||
        '\n<script type="text/javascript" src="/ods/app.js"></script>            ' ||
        '\n<script type="text/javascript"><![CDATA[                              ' ||
        '\n  function wikiInit()                                                 ' ||
        '\n  {                                                                   ' ||
        '\n    OAT.Preferences.imagePath = "/ods/images/oat/";                   ' ||
        '\n    OAT.Anchor.imagePath = OAT.Preferences.imagePath;                 ' ||
        '\n    OAT.Anchor.zIndex = 1001;                                         ' ||
        '\n    if (%d > 0) {                                                     ' ||
        '\n      var e = \$("attachments_table");                                ' ||
        '\n      if (e)                                                          ' ||
        '\n      {                                                               ' ||
        '\n        var appLinks = e.getElementsByTagName("a");                   ' ||
        '\n        for (var i = 0; i < appLinks.length; i++)                     ' ||
        '\n        {                                                             ' ||
        '\n          var app = appLinks[i];                                      ' ||
        '\n          OAT.Dom.addClass (app, "noapp");                            ' ||
        '\n        }                                                             ' ||
        '\n      }                                                               ' ||
        '\n      var e = \$("content");                                          ' ||
        '\n      if (e)                                                          ' ||
        '\n      {                                                               ' ||
        '\n        var appLinks = e.getElementsByTagName("a");                   ' ||
        '\n        for (var i = 0; i < appLinks.length; i++)                     ' ||
        '\n        {                                                             ' ||
        '\n          var app = appLinks[i];                                      ' ||
        '\n          var search;                                                 ' ||
        '\n          if (!app.id)                                                ' ||
        '\n          {                                                           ' ||
        '\n            if ((app.childNodes.length == 1) && (app.childNodes[0].tagName == "IMG")) ' ||
        '\n            {                                                         ' ||
        '\n          	   search = app.childNodes[0].getAttribute("alt");         ' ||
        '\n            }                                                         ' ||
        '\n            else                                                      ' ||
        '\n            {                                                         ' ||
        '\n         	   search = app.innerHTML;                                 ' ||
        '\n            }                                                         ' ||
        '\n            if (search && (search.length > 1))                        ' ||
        '\n              app.id = "link_" + i;                                   ' ||
        '\n          }                                                           ' ||
        '\n        }                                                             ' ||
        '\n      generateAPP("content", {title:"Related links", appActivation: "%s", useRDFB: %s});     ' ||
        '\n      }                                                               ' ||
        '\n    }                                                                 ' ||
        '\n  }                                                                   ' ||
        '\n  OAT.MSG.attach(OAT, "OAT_LOAD", wikiInit);                    ' ||
        '\n]]></script>                                                             ';

  return sprintf (S, app, case when app = 2 then 'hover' else 'click' end, case when wa_check_package ('OAT') then 'true' else 'false' end);
}
;

grant execute on WV.WIKI.READONLYWIKIWORDLINK to public
;
grant execute on WV.WIKI.READONLYWIKIWORDHREF2 to public
;
grant execute on WV.WIKI.READONLYWIKIIRI to public
;
grant execute on WV.Wiki.WIKI_APLUSLINK to public
;
grant execute on WV.WIKI.wiki_cluster_uri to public
;

xpf_extension ('http://www.openlinksw.com/Virtuoso/WikiV/:ReadOnlyWikiWordLink', 'WV.WIKI.READONLYWIKIWORDLINK')
;
xpf_extension ('http://www.openlinksw.com/Virtuoso/WikiV/:ReadOnlyWikiWordHREF2', 'WV.WIKI.READONLYWIKIWORDHREF2')
;
xpf_extension ('http://www.openlinksw.com/Virtuoso/WikiV/:ReadOnlyWikiIRI', 'WV.WIKI.READONLYWIKIIRI')
;
xpf_extension ('http://www.openlinksw.com/Virtuoso/WikiV/:WikiAplusLink', 'WV.Wiki.WIKI_APLUSLINK')
;
xpf_extension ('http://www.openlinksw.com/Virtuoso/WikiV/:WikiClusterURI', 'WV.WIKI.wiki_cluster_uri')
;

create function WV.WIKI.QUERYWIKIWORDLINK (
  inout _default_cluster varchar, inout _href varchar) returns varchar
{ -- Parses dirty WikiLink and returns the TopicId of the most suitable page.
  declare _topic WV.WIKI.TOPICINFO;
  _topic := WV.WIKI.TOPICINFO ();
  _topic.ti_raw_title := _href;
  _topic.ti_default_cluster := _default_cluster;
  _topic.ti_find_id_by_raw_title ();
  return _topic.ti_id;
}
;

grant execute on WV.WIKI.QUERYWIKIWORDLINK to public
;

xpf_extension ('http://www.openlinksw.com/Virtuoso/WikiV/:QueryWikiWordLink', 'WV.WIKI.QUERYWIKIWORDLINK')
;

create function WV.WIKI.EXPANDMACRO (
  inout _name varchar,
  inout _data varchar,
  inout _context any,
  inout _env any) returns varchar
{ -- Calls the implementation of macro and returns the composed XML fragment.
  declare _funname varchar;
  declare _res any;
  declare exit handler for sqlstate '*' {
    if (__SQL_STATE = 'WVRLD')
      resignal;
    return XMLELEMENT (cast (_funname as varchar), xtree_doc (sprintf ('<div class="wiki-error"><h2>SQL STATE:</h2><h3><![CDATA[%s]]></h3><h2>SQL MESSAGE:</h2><h3><![CDATA[%s]]></h3></div>', __SQL_STATE, __SQL_MESSAGE)));
  }
  ;
  declare exit handler for not found {
    return XMLELEMENT (cast (_funname as varchar), xtree_doc (sprintf ('<div class="wiki-error"><h2>SQL STATE:</h2><h3><![CDATA[%s]]></h3></div>', 'nof found')));
  }
  ;   

  _funname := fix_identifier_case ('WV.Wiki.' || 'MACRO_' || replace (_name, ':', '_'));
  if (exists (select 1 from DB.DBA.SYS_PROCEDURES where P_NAME= _funname))
    _res := call (_funname) (_data, _context, _env);
  else
    _res := sprintf ('((The macro extension "%s" is not available on this server))', _name);
  if (not isentity (_res))
  {
    --dbg_obj_princ ('TEST!!!!!!! ', _res);
    declare _xml_doc any;
    declare _cluster_name, _lexer, _lexer_name varchar;
    _cluster_name := get_keyword ('ti_cluster_name', _env, 'Main');
    WV..LEXER (get_keyword ('ti_cluster_name', _env, 'Main'), _lexer, _lexer_name);
    _xml_doc :=  xtree_doc(call (_lexer) (_res || '\r\n',
            _cluster_name,
            get_keyword ('ti_local_name', _env, WV.WIKI.CLUSTERPARAM (_cluster_name, 'index-page', 'WelcomeVisitors')),
            get_keyword ('ti_curuser_wikiname', _env, 'WikiGuest'),
            null), 2);
    _res := _xml_doc;
  }
  if (not isentity (_res))
    _res := XMLELEMENT (cast (_funname as varchar), _res);
  return _res;
}
;

grant execute on WV.WIKI.EXPANDMACRO to public
;

xpf_extension ('http://www.openlinksw.com/Virtuoso/WikiV/:ExpandMacro', 'WV.WIKI.EXPANDMACRO')
;

create function WV.WIKI.GETENV (in _name varchar, inout _env any) returns varchar
{ -- Returns a string that is a value of WikiV environment variable from registry.
  declare _res any;
  _res := get_keyword (_name, _env);
  if (_res is not null)
    return _res;
  _res := registry_get (concat ('WikiV %', _name, '%'));
  if (_res is not null)
    return _res;
  return  sprintf ('?"%s"?', _name);
}
;

grant execute on WV.WIKI.GETENV to public
;

xpf_extension ('http://www.openlinksw.com/Virtuoso/WikiV/:GetEnv', 'WV.WIKI.GETENV')
;

-- Id allocators. They return new values of primary keys for their tables.

create function WV.WIKI.NEWCLUSTERID () returns integer
{
  declare _res integer;
  while (1)
    {
      _res := 10000000 + rand (89999999); -- exactly 8-digit integers
      if (not exists (select top 1 1 from WV.WIKI.CLUSTERS where ClusterId = _res))
	return _res;
    }
}
;

create function WV.WIKI.NEWPLAINTOPICID () returns integer
{
  declare _res integer;
  while (1)
    {
      _res := 100000000 + rand (899999999); -- exactly 9-digit integers
      if (not exists (select top 1 1 from WV.WIKI.TOPIC where TopicId = _res))
	  return _res;
    }
}
;

create function WV.WIKI.NEWPLAINLINKID () returns integer
{
  declare _res integer;
  while (1)
    {
      _res := 100000000 + rand (899999999); -- exactly 9-digit integers
      if (not exists (select top 1 1 from WV.WIKI.LINK where LinkId = _res))
	return _res;
    }
}
;

-- Administrative functions for DAV

create function WV.WIKI.WIKIUID () returns integer
{ -- Returns UID of 'Wiki' user
  return coalesce ((select U_ID from DB.DBA.SYS_USERS where U_NAME='Wiki' and U_IS_ROLE=0 and U_ACCOUNT_DISABLED=0 and U_DAV_ENABLE=1 and U_SQL_ENABLE=1), NULL);
}
;

create function WV.WIKI.WIKIADMINGID () returns integer
{ -- Returns UID of 'WikiAdmin' group
  return coalesce ((select U_ID from DB.DBA.SYS_USERS where U_NAME='WikiAdmin' and U_IS_ROLE=1 and U_DAV_ENABLE=1), NULL);
}
;

create function WV.WIKI.WIKIUSERGID () returns integer
{ -- Returns UID of 'WikiUser' group
  return coalesce ((select U_ID from DB.DBA.SYS_USERS where U_NAME='WikiUser' and U_IS_ROLE=1 and U_DAV_ENABLE=1), NULL);
}
;

create function WV.WIKI.CREATEDAVCOLLECTION (in _col_parent integer, in _col_name varchar, in _owner integer, in _group integer) returns integer
{ -- Creates _col_name collection in _col_parent.
-- Owner user and group can be NULL to indicate default,
-- default is 'Wiki' or (as the last resort) 'dav'.
  declare _res integer;
  if (_owner is null)
    _owner := coalesce (WV.WIKI.WIKIUID(), http_dav_uid());
  if (_group is null)
    _group := coalesce (WV.WIKI.WIKIADMINGID(), http_dav_uid() + 1);

 declare _res integer;
  _res := DB.DBA.DAV_SEARCH_ID (DB.DBA.DAV_SEARCH_PATH (_col_parent, 'C') || _col_name || '/', 'C');
  if (_res > 0)
	return _res;
  _res := DB.DBA.DAV_COL_CREATE (DB.DBA.DAV_SEARCH_PATH (_col_parent, 'C') || _col_name || '/',
	'111000000R', 
	(select U_NAME from DB.DBA.SYS_USERS where U_ID = _owner),
	(select U_NAME from DB.DBA.SYS_USERS where U_ID = _group),
	'dav',
	(select pwd_magic_calc (U_NAME, U_PWD, 1) from WS.WS.SYS_DAV_USER where U_ID = http_dav_uid()));
  return _res;
}
;

-- Administrative functions for Wiki

create procedure WV.WIKI.CREATEGROUP (in _sysname varchar, in _name varchar, in _seccmt varchar, in signal_err int:=1)
{
  declare _gid integer;
  declare _oldname varchar;
  if (exists (select 1 from WV.WIKI.GROUPS where GroupName = _name))
    {
      if (signal_err = 1)
	WV.WIKI.APPSIGNAL (11001, 'Wiki group "&GroupName;" already exists.',
			       vector ('GroupName', _name) );
      else
	return;
    }
  _gid := coalesce ((select U_ID from DB.DBA.SYS_USERS where U_NAME = _sysname and U_IS_ROLE = 1), NULL);
  if (_gid is null) 
    {
      if (signal_err = 1)
	WV.WIKI.APPSIGNAL (11001, 'System group "&GName;" does not exist; can not create Wiki group "&GroupName;"',
				 vector ('GName', _sysname, 'GroupName', _name) );
      else
	return;
    }
  _oldname := coalesce ((select GroupName from WV.WIKI.GROUPS where GroupId = _gid), NULL);
  if (_oldname is not null)
    {
      if (signal_err= 1)
	WV.WIKI.APPSIGNAL (11001, 'Wiki group "&GroupName;" is not created because account "&GName;" is already known as "&OldGroupName;".',
				 vector ('GName', _sysname, 'OldGroupName', _oldname, 'GroupName', _name) );
      else
	return;
    }
  if (exists (select 1 from DB.DBA.SYS_USERS where U_NAME = _name and U_ID <> _gid) or
    exists (select 1 from WV.WIKI.USERS where UserName = _name) )
    WV.WIKI.APPSIGNAL (11001, 'Can not create Wiki group "&GroupName;" because a very similar name is already in use',
      vector ('GroupName', _name) );
  insert into WV.WIKI.GROUPS (GroupId, GroupName, SecurityCmt)
  values (_gid, _name, _seccmt);
}
;

create procedure WV.WIKI.CREATEUSER (in _sysname varchar, in _name varchar, in _group varchar, in _seccmt varchar, in signal_err int:=1)
{
  declare exit handler for sqlstate '42WV9' {
	if (signal_err)
		resignal;
	return;
  };
  _name := WV.WIKI.USER_WIKI_NAME (_name);
  if (_name is null)
    _name := WV.WIKI.USER_WIKI_NAME (_sysname);
  declare _gid, _uid integer;
  declare _oldname varchar;
  _uid := coalesce ((select U_ID from DB.DBA.SYS_USERS where U_NAME = _sysname and U_IS_ROLE = 0 and U_ACCOUNT_DISABLED=0 and U_DAV_ENABLE=1), NULL);
  if (_uid is null)
    WV.WIKI.APPSIGNAL (11001, 'System user account "&UName;" does not exist or can not be used for Wiki purposes; can not register Wiki user "&UserName;"',
      vector ('UName', _sysname, 'UserName', _name) );
  if (not exists (select 1 from DB.DBA.SYS_USER_GROUP where UG_UID = _uid and UG_GID = WV.WIKI.WIKIUSERGID())
    and not exists (select 1 from DB.DBA.SYS_USERS where U_ID = _uid and U_GROUP = WV.WIKI.WIKIUSERGID()) )
    WV.WIKI.APPSIGNAL (11001, 'System user account "&UName;" is not a member of WikiUser group and can not be used for Wiki purposes',
      vector ('UName', _sysname) );
  if (exists (select 1 from WV.WIKI.USERS where UserId = _uid))
    return;
again:
  if (exists (select 1 from WV.WIKI.USERS where UserName = _name))
    {
      _name := sprintf ('%s%d', _name, _uid);
      goto again;
    }
--	WV.WIKI.APPSIGNAL (11001, 'Wiki user name "&UserName;" is already registered.',
--				 vector ('UserName', _name) );
  _gid := coalesce ((select GroupId from WV.WIKI.GROUPS where GroupName = _group), NULL);
  if (_gid is null)
    WV.WIKI.APPSIGNAL (11001, 'Group "&GroupName;" does not exist; can not register Wiki user "&UserName;"',
      vector ('GroupName', _group, 'UserName', _name) );
  _oldname := coalesce ((select UserName from WV.WIKI.USERS where UserId = _uid), NULL);
  if (_oldname is not null)
    {
      delete from WV.WIKI.USERS where UserId = _uid;
    }
  if (exists (select 1 from DB.DBA.SYS_USERS where U_NAME = _name and U_ID <> _uid) or
    exists (select 1 from WV.WIKI.GROUPS where GroupName = _name and GroupName <> _group) )
    WV.WIKI.APPSIGNAL (11001, 'Can not register Wiki user name "&UserName;" because a very similar name is already in use',
      vector ('UserName', _name) );
    
  insert into WV.WIKI.USERS (UserId, UserName, MainGroupId, SecurityCmt)
  values (_uid, _name, _gid, _seccmt);
}
;

create procedure WV.WIKI.CREATEROLES (in _cname varchar)
{
  declare st, msg any;
  set_user_id ('dba');
  EXEC ('DB.DBA.USER_ROLE_CREATE (''' || _cname || 'Readers'') ', st, msg);
  EXEC ('DB.DBA.USER_ROLE_CREATE (''' || _cname || 'Writers'') ', st, msg);
}
;

create procedure WV.WIKI.UPDATEACL (in _article varchar, in _gid integer, in _bitmask integer, in _auth_name varchar, in _auth_pwd varchar)
{
  --dbg_obj_princ ('UPDATEACL: ', _article, ' ', _gid, ' ', '_bitmask', ' ');
  declare _acl any;
  _acl := DB.DBA.DAV_PROP_GET(_article, ':virtacl', _auth_name, _auth_pwd);
  if (not isinteger (_acl))
    {
      declare _res integer;
      declare _new_acl, _old_acl any;
      _acl := cast (_acl as varbinary);
      _old_acl := _acl;
      _new_acl := WS.WS.ACL_ADD_ENTRY(_old_acl, _gid, _bitmask, 1);
      --dbg_obj_print (ws.ws.ACL_PARSE(_acl), ws.ws.acl_parse(_new_acl));
      if (1 or _acl <> _new_acl)
        {
	  _acl := _new_acl;
	  --dbg_obj_princ (_article, _gid, _auth_name, _auth_pwd, _acl);
      	  _res := DB.DBA.DAV_PROP_SET_INT(_article, ':virtacl',  _acl, null, null, 0, 0, 0, http_dav_uid ());
      	  if (_res < 0)
        	signal ('WIKI00', sprintf ('Can not update ACL: %d %d',_res,coalesce ((select top 1 RES_OWNER from WS.WS.SYS_DAV_RES where RES_ID = (select RES_ID from WS.WS.SYS_DAV_RES where RES_FULL_PATH = _article)), 0))); 
	}
    }
  else
    signal ('WIKI01', ':virtacl property retrieval failed: ' || DAV_PERROR (_acl));
}
;

create procedure WV.WIKI.UPDATEGRANTS (in _cname varchar, in signalerror int:=0)
{
  declare _readers, _writers integer;
  _readers := ( select U_ID from DB.DBA.SYS_USERS where U_NAME = _cname || 'Readers'
  			and U_IS_ROLE = 1 );
  _writers := ( select U_ID from DB.DBA.SYS_USERS where U_NAME = _cname || 'Writers'
  			and U_IS_ROLE = 1 );
  if ( (_readers is null) or (_writers is null) )
    {
      if (signalerror)
    signal ('WK002', 'No readers or writers group for ' || _cname);
      else
	 return;
    }
  for select DAV_HIDE_ERROR (DB.DBA.DAV_SEARCH_PATH (ResId, 'R')) as _path
    from WV.WIKI.TOPIC natural inner join WV.WIKI.CLUSTERS
    where clustername = _cname
  do {
    if (_path is not null) 
      {
    declare _owner, _pwd varchar;
        _owner := WV.WIKI.CLUSTERPARAM (_cname, 'creator', 'dav');
    select U_NAME, pwd_magic_calc (U_NAME, U_PASSWORD, 1) into _owner, _pwd
            from DB.DBA.SYS_USERS 
	    where U_NAME = _owner;

    WV.WIKI.UPDATEACL (_path, _writers, 6, _owner, _pwd);
    WV.WIKI.UPDATEACL (_path, _readers, 4, _owner, _pwd);
  }
  }
}
;

create procedure WV.WIKI.UPDATEGRANTS_FOR_RES_OR_COL (in _cname varchar, in _res_id integer, in _type varchar(1):='R')
{
  declare _readers, _writers integer;
  declare _path varchar;
  declare _owner, _pwd varchar;
  
  _readers := ( select U_ID from DB.DBA.SYS_USERS where U_NAME = _cname || 'Readers'
  			and U_IS_ROLE = 1 );
  _writers := ( select U_ID from DB.DBA.SYS_USERS where U_NAME = _cname || 'Writers'
  			and U_IS_ROLE = 1 );
  if ( (_readers is null) or (_writers is null) )
    signal ('XXXXX', 'No readers or writers group for ' || _cname);
  _path := DB.DBA.DAV_SEARCH_PATH (_res_id, _type);
  --dbg_obj_princ (':::' , _path);
  if (not isinteger (_path))
    {
      _owner := WV.WIKI.CLUSTERPARAM (_cname, 'creator', 'dav');
      select U_NAME, pwd_magic_calc (U_NAME, U_PASSWORD, 1) into _owner, _pwd
        from DB.DBA.SYS_USERS 
	where U_NAME = _owner;


--      declare _cluster_id integer;
--      _cluster_id := (select ClusterId from WV.WIKI.CLUSTERS where ClusterName = _cname);
--     update WS.WS.SYS_DAV_COL set COL_PERMS = WV.WIKI.GETDEFAULTPERMS (_cluster_id)
--      	where COL_ID = _res_id;
      WV.WIKI.UPDATEACL (_path, _writers, 6, _owner, _pwd);
      WV.WIKI.UPDATEACL (_path, _readers, 4, _owner, _pwd);
    }
  else
    signal ('XXXX', 'path is unknown');
}
;
  

-- create all parent collections
create procedure WV.WIKI.ENSURE_DIR_REC (in _paths any, in _last_index integer)
{
  --dbg_obj_princ ('WV.WIKI.ENSURE_DIR_REC ', _paths, _last_index);
  if (_last_index <= 2) -- /DAV
    return 1;
  declare _col_id integer;
  declare _full_path varchar;
  _full_path := WV.WIKI.STRJOIN ('/', subseq (_paths, 0, _last_index)) || '/';
  _col_id := DAV_SEARCH_ID (_full_path, 'C');
  --dbg_obj_princ ('col_id: ', _col_id, _full_path);
  if (DAV_HIDE_ERROR(_col_id) is null)
    {
      if (WV.WIKI.ENSURE_DIR_REC (_paths, _last_index - 1) < 0)
        return -1;
      return  DB.DBA.DAV_MAKE_DIR (_full_path, http_dav_uid(), http_dav_uid() + 1, '110000000R');
    }
  return _col_id;
}
;
      
  

create procedure WV.WIKI.DAV_HOME_CREATE(in user_name varchar) returns varchar
{
  declare user_id varchar;
  declare user_home varchar;

  whenever not found goto error;
  select U_HOME, U_ID into user_home, user_id  from DB.DBA.SYS_USERS where U_NAME = user_name;
  user_home := coalesce ( user_home, '/DAV/home/' || user_name || '/');
  
  declare _res_id integer;
  _res_id := DAV_SEARCH_ID (user_home, 'C');
  if (DAV_HIDE_ERROR (_res_id) is not null)
    goto create_wiki_home;
  -- create home
  declare _last integer;
  if (length(user_home) > 0)
    _last := user_home[length(user_home)-1];
  else
    _last := user_home[0];
  if (_last <> '/'[0])
    user_home := user_home || '/';
  
  declare _paths any;
  _paths := split_and_decode (user_home, 0, '\0\0/');  
  if (WV.WIKI.ENSURE_DIR_REC (_paths, length (_paths) - 1) < 0)
    return -18;
  _res_id := DB.DBA.DAV_MAKE_DIR (user_home, user_id, null, '110000000R');
  USER_SET_OPTION(user_name, 'HOME', user_home);

create_wiki_home:
  --create wiki home
  user_home := user_home || 'wiki/';
  _res_id := DAV_SEARCH_ID (user_home, 'C');
  if (DAV_HIDE_ERROR (_res_id) is not null)
    return _res_id;
  _res_id := DB.DBA.DAV_MAKE_DIR (user_home, user_id, null, '110000000R');

  return _res_id;
error:
  return -18;
}
;




create procedure WV.WIKI.CREATECLUSTER (in _cname varchar, in _src_col integer, in _owner integer, in _group integer, in signal_err int:=1)
{
  --dbg_obj_print ('1');
  declare exit handler for sqlstate '42WV9' {
  --dbg_obj_print ('1err');
	if (signal_err = 1)
	   resignal;
	return;
  };
  declare _uname, _gname, _home varchar;
  declare _wikiuname, _wikigname varchar;
  declare _parent, _main, _histcol, _xmlcol, _attachcol integer;
  declare _res integer;
-- Preparing user name
  _uname := coalesce ((select U_NAME from DB.DBA.SYS_USERS where U_ID = _owner and U_IS_ROLE = 0), NULL);
  if (_uname is null)
    WV.WIKI.APPSIGNAL (11001, 'User ID "&UId;" is invalid; can not create cluster "&ClusterName;"',
      vector ('UId', _owner, 'ClusterName', _cname) );
  --dbg_obj_print ('2');

  if (exists (select 1 from DB.DBA.SYS_USERS where U_ID = _owner and U_ACCOUNT_DISABLED <> 0))
    WV.WIKI.APPSIGNAL (11001, 'Account "&UName;" is disabled; can not create cluster "&ClusterName;"',
      vector ('UName', _uname, 'ClusterName', _cname) );
  --dbg_obj_print ('4');

  if (exists (select 1 from DB.DBA.SYS_USERS where U_ID = _owner and U_DAV_ENABLE = 0))
    WV.WIKI.APPSIGNAL (11001, 'Account "&UName;" has no right to use DAV; can not create cluster "&ClusterName;"',
      vector ('UName', _uname, 'ClusterName', _cname) );	
  _wikiuname := coalesce ((select UserName from WV.WIKI.USERS where UserId = _owner), NULL);
  if (_wikiuname is null)
    WV.WIKI.APPSIGNAL (11001, 'User "&UserName;" is not a registered Wiki user; can not create cluster "&ClusterName;"',
      vector ('UserName', _uname, 'ClusterName', _cname) );
-- Preparing group name
  _gname := coalesce ((select U_NAME from DB.DBA.SYS_USERS where U_ID = _group and U_IS_ROLE = 1), NULL);
  if (_gname is null)
    WV.WIKI.APPSIGNAL (11001, 'Group ID "&GId;" is invalid; can not create cluster "&ClusterName;"',
      vector ('GId', _group, 'ClusterName', _cname) );
  --dbg_obj_print ('5');

  _wikigname := coalesce ((select GroupName from WV.WIKI.GROUPS where GroupId = _group), NULL);
  if (_wikigname is null)
    WV.WIKI.APPSIGNAL (11001, 'Group "&UserName;" is not a valid Wiki group; can not create cluster "&ClusterName;"',
      vector ('GName', _gname, 'ClusterName', _cname) );
-- Preparing parent for internal files
  _home := (select U_HOME from DB.DBA.SYS_USERS where U_ID = _owner and U_IS_ROLE = 0);
  if (_home is not null)
    _parent := WV.WIKI.DAV_HOME_CREATE (_uname);  
  else
    {
      _home := '/DAV/VAD/wiki/';
      _parent := DAV_HIDE_ERROR (DB.DBA.DAV_SEARCH_ID(_home, 'C'));
    }

  if (_parent < 0)
    WV.WIKI.APPSIGNAL (11001, 'Unable to find existing or create a new DAV collection for internal Wiki files', null);
-- Check if a cluster is already registered.
  if (exists (select * from WV.WIKI.CLUSTERS where ClusterName = _cname))
    {
  --dbg_obj_print ('7');

      if (signal_err = 1)
	WV.WIKI.APPSIGNAL (11001, 'Cluster "&ClusterName;" already exists',
				 vector ('ClusterName', _cname) );
      else
	return;
    }
-- Preparing main collection
  if (_src_col <> 0)
    {
      if (DB.DBA.DAV_SEARCH_PATH (_src_col, 'C') < 0)
	WV.WIKI.APPSIGNAL (11001, 'Invalid DAV collection ID "&ColId;"; can not create cluster "&ClusterName;"',
	  vector ('ColId', _src_col, 'ClusterName', _cname) );
      _main := _src_col;
    }
  else
    {
      _main := WV.WIKI.CREATEDAVCOLLECTION (_parent, _cname, _owner, _group);
    }
  --dbg_obj_print ('8');

  if (__proc_exists('DB.DBA.Versioning_DAV_SEARCH_ID'))
    {
      _histcol := WV.WIKI.CREATEDAVCOLLECTION (_main, 'VVC', _owner, _group);
      DB.DBA.DAV_SET_VERSIONING_CONTROL (DAV_SEARCH_PATH (_main, 'C'), NULL, 'A', 'dav', (select pwd_magic_calc (U_NAME, U_PWD, 1) from WS.WS.SYS_DAV_USER where U_ID = http_dav_uid() ));
    }
next:
    --dbg_obj_print ('9');

  -- _xmlcol := WV.WIKI.CREATEDAVCOLLECTION (_main, 'xml', _owner, _group);
  -- _attachcol := WV.WIKI.CREATEDAVCOLLECTION (_main, 'attach', _owner, _group);
  declare _cluster_id integer;
  _cluster_id := WV.WIKI.NEWCLUSTERID();
  insert into WV.WIKI.CLUSTERS (ClusterId, ClusterName, ColId, ColHistoryId, ColXmlId, ColAttachId, AdminId, C_NEWS_ID)
    values (_cluster_id, _cname, _main, _histcol, _xmlcol, _attachcol, _owner, 'oWiki-' || _cname);
  for select RES_ID as _res_id, RES_FULL_PATH as _full_path,
    RES_CONTENT as _content,
    RES_COL as _col_id,
    RES_NAME as _name,
    RES_OWNER as _owner
    from WS.WS.SYS_DAV_RES 
    where RES_COL = _main and RES_NAME like '%.txt' and 
      not exists (select 1 from WV.WIKI.TOPIC where ResId = RES_ID)
  do {
    insert replacing WV.WIKI.TOPIC (TopicId, ClusterId, ResId, LocalName, LocalName2, Abstract, MailBox)
      values (WV.WIKI.NEWPLAINTOPICID(), _cluster_id, _res_id, 
      	subseq (_name, 0, length (_name) - 4), 
      	subseq (_name, 0, length (_name) - 4), 
	NULL,
	NULL);
    WV.WIKI.GETLOCK (_full_path, 'dav');
    _res := WV.WIKI.UPLOADPAGE (_col_id, _name, blob_to_string (_content) || ' ',
       _uname, _cluster_id, 'dav');
--    DB.DBA.DAV_CHECKIN_INT (_full_path, null, null, 0);
    WV.WIKI.RELEASELOCK (_full_path, 'dav');
  }
  WV.WIKI.CREATEROLES (_cname);
  --dbg_obj_print ('11');

  if ( (_cname <> 'Main') and
       (_cname <> 'Doc'))
    {
      WV.WIKI.UPDATEGRANTS_FOR_RES_OR_COL (_cname, _main, 'C');
      WV.WIKI.IMPORT(_cname, '/DAV/VAD/wiki/Template/', '/DAV/VAD/wiki/Template/', 'dav');
--      WV.WIKI.CREATEINITIALPAGE ('ClusterSummary.txt', _main, _owner, 'Template');
--      WV.WIKI.CREATEINITIALPAGE ('WelcomeVisitors.txt', _main, _owner, 'Template');
    }
  else
    {
     for select RES_NAME from WS.WS.SYS_DAV_RES where RES_FULL_PATH like '/DAV/VAD/wiki/' || _cname || '/%.txt' do 
       {
         WV.WIKI.CREATEINITIALPAGE (RES_NAME, _main, _owner, _cname);
       }
     WV.WIKI.UPDATEGRANTS(_cname);
    }
	  
  WV.WIKI.SETCLUSTERPARAM (_cname, 'creator', _uname);
  --dbg_obj_print ('12');

}
;


create procedure WV.WIKI.UPLOADPAGE (
  in _col_id integer,
	in _name varchar, 
	in _text any, 
	in _owner varchar, 
	in _cluster_id int:=0,
	in _user varchar:='dav',
	in _overwrite int :=1)
{
  --dbg_obj_princ ('WV.WIKI.UPLOADPAGE ',  _col_id,  _name, _text , _owner,  _cluster_id ,_user);
  declare _res_id integer;
  if (_cluster_id = 0)
    _cluster_id := (select ClusterId from WV.WIKI.CLUSTERS where ColId = _col_id);
  declare _perms, _path varchar;
  _path := WS.WS.COL_PATH(_col_id) || _name;
  if ((not _overwrite) and (DB.DBA.DAV_SEARCH_ID (_path,'R') > 0))
    return -03;
  _perms := WV.WIKI.GETDEFAULTPERMS (_cluster_id);
  connection_set ('HTTP_CLI_UID', _user);
  connection_set ('oWiki_cluster_id', _cluster_id);
  _res_id := DB.DBA.DAV_RES_UPLOAD (
     _path,
     _text,
     'text/plain',
     _perms, 
     _owner,
     'WikiUser', 
     'dav', 
     (select pwd_magic_calc (U_NAME, U_PWD, 1) from WS.WS.SYS_DAV_USER where U_ID = http_dav_uid()),
     coalesce ( (select Token from WV.WIKI.LOCKTOKEN where UserName = _user and ResPath = _path), 1));
  connection_set ('oWiki_cluster_id', null);
  declare wiki_user varchar;
  declare user_id integer;
  user_id := (select U_ID from DB.DBA.SYS_USERS where U_NAME = _user);
  wiki_user := WV.WIKI.USER_WIKI_NAME_2 (user_id);
  update WV.WIKI.TOPIC set AuthorName = 'Main.' || wiki_user 
  	, AuthorId = user_id
     where ResId = _res_id;
     
  if (_res_id < 0)
    WV.WIKI.APPSIGNAL (11001, 'Cannot upload content at &path;', vector ('path', _path));
   --dbg_obj_princ ('perms=', _perms, ' res= ', _res_id);
  return _res_id;
}
;

create procedure WV.WIKI.CREATEINITIALPAGE (in _page varchar, 
  in _main integer,
  in _owner_id integer,
	in _templ_root varchar:='Main',
	in _overwrite int:=1)
{
  whenever sqlstate '*' goto fin;
  declare _content, _type, _owner, _pwd varchar;
  select pwd_magic_calc (U_NAME, U_PASSWORD, 1), U_NAME into _pwd, _owner from DB.DBA.SYS_USERS where U_ID = _owner_id and U_IS_ROLE = 0;

  declare _template_collection varchar;
  _template_collection := '/DAV/VAD/wiki/' || _templ_root || '/';
  if (0 < DB.DBA.DAV_RES_CONTENT (_template_collection || _page, _content, _type, _owner, _pwd))
    {
      declare _fullpath varchar;
      _fullpath := DB.DBA.DAV_SEARCH_PATH (_main, 'C') || _page;
--      WV.WIKI.GETLOCK (_fullpath, 'dav');
      WV.WIKI.UPLOADPAGE (_main, _page, _content, _owner, 0, 'dav', _overwrite);
--      DB.DBA.DAV_CHECKIN_INT (_fullpath, null, null, 0);
--      WV.WIKI.RELEASELOCK (_fullpath, 'dav');
    }
fin:
	;
}
;

create procedure WV.WIKI.DELETETOPIC (in _id integer)
{
  --dbg_obj_princ ('DELETETOPIC: ', _id);
  delete from WV.WIKI.TOPIC where TopicId = _id;
  if (__proc_exists ('DB.DBA.WA_NEW_WIKI_RM'))
     WA_NEW_WIKI_RM (_id);
}
;

create procedure WV.WIKI.DROPCLUSTERUPSTREAM (in _cid integer)
{
  for select UP_ID from WV.DBA.UPSTREAM where UP_CLUSTER_ID = _cid do {
    delete from WV.DBA.UPSTREAM_LOG where UL_UPSTREAM_ID = UP_ID;
    delete from WV.DBA.UPSTREAM_ENTRY where UE_STREAM_ID = UP_ID;
  }
  delete from WV.DBA.UPSTREAM where UP_CLUSTER_ID = _cid;
}
;

create procedure WV.WIKI.DROPCLUSTERCONTENT (in _cid integer)
{
  declare _topic WV.WIKI.TOPICINFO;
  _topic := WV.WIKI.TOPICINFO ();
  _topic.ti_cluster_id := _cid;
  _topic.ti_fill_cluster_by_id ();

  declare _dir_list, _pwd any;
  _pwd :=  (select pwd_magic_calc (U_NAME, U_PWD, 1) from WS.WS.SYS_DAV_USER where U_ID = http_dav_uid());
  _dir_list := DAV_DIR_LIST (DB.DBA.DAV_SEARCH_PATH (_topic.ti_col_id, 'C'), 0, 'dav', _pwd);

  for select TOPICID from WV.WIKI.TOPIC where ClusterID = _cid do {
    delete from WV.WIKI.COMMENT where C_TOPIC_ID = TOPICID;
  }

  foreach (any _file in _dir_list) do {
	if ( (aref (_file, 1) = 'R') or (aref (_file, 1) = 'r') )
		DB.DBA.DAV_DELETE ( aref (_file, 0), 0, 'dav', _pwd);
  }
  delete from WV.WIKI.TOPIC where ClusterId = _cid;
}
;

create procedure WV.WIKI.DELETECLUSTER (in _cid varchar)
{
  if (exists (select 1 from WV.WIKI.TOPIC where ClusterId = _cid))
    WV.WIKI.APPSIGNAL (11001, 'Cluster "&ClusterName;" is not empty; delete all topics first',
      vector ('ClusterName', coalesce ((select ClusterName from WV.WIKI.CLUSTERS where ClusterId = _cid), cast (_cid as varchar))) );
  delete from WV.WIKI.CLUSTERS where ClusterId = _cid;
}
;

create procedure WV.WIKI.LOADCOLLECTIONFROMFILES (in _dirfullpath varchar, in _col_id integer, in _make_result_names integer default 1,  in _user varchar default 'Wiki', in _group varchar default 'WikiAdmin')
{
  declare _dirlist, _filelist any;
  declare _diridx, _fileidx integer;
  declare _fname varchar;
  declare Directory, "File Name" varchar;
  declare "Parent Id", "Res Id" integer;
  if (_make_result_names)
    result_names (Directory, "File Name", "Parent Id", "Res Id");
  _filelist := sys_dirlist (_dirfullpath, 1);
  _fileidx := 0;
  while (_fileidx < length (_filelist))
    {
      declare _filename varchar;
      declare _rid integer;
      declare _text any;
      _filename := aref (_filelist, _fileidx);
      _text := file_to_string_output (concat (_dirfullpath, '/', _filename));
      _rid := DB.DBA.DAV_RES_UPLOAD_STRSES (concat (WS.WS.COL_PATH(_col_id), _filename), _text, 'text/plain', '110000000R', _user, _group, 'Wiki', null);
      result (_dirfullpath, _filename, _col_id, _rid);
      _fileidx := _fileidx + 1;
      commit work;
    }
  _filelist := sys_dirlist (_dirfullpath, 0);
  _fileidx := 0;
  while (_fileidx < length (_filelist))
    {
      declare _filename varchar;
      _filename := aref (_filelist, _fileidx);
      WV.WIKI.LOADSUBDIRECTORY (_dirfullpath, _col_id, _filename, 0, _user, _group);
      result (_dirfullpath, _filename, _col_id, NULL);
      _fileidx := _fileidx + 1;
      commit work;
    }
}
;


create procedure WV.WIKI.LOADSUBDIRECTORY (in _parent_path varchar, in _parent_col_id integer, in _dirname varchar, in _make_result_names integer default 1, in _user varchar default 'Wiki', in _group varchar default 'WikiAdmin')
{
  declare _rid integer;
  if (('.' = _dirname) or ('..' = _dirname))
    return;
  declare Directory, "File Name" varchar;
  declare "Parent Id", "Res Id" integer;
  if (_make_result_names)
    result_names (Directory, "File Name", "Parent Id", "Res Id");
  _rid := DB.DBA.DAV_COL_CREATE(concat (WS.WS.COL_PATH(_parent_col_id), _dirname, '/'), '110000000R', _user, _group, 'Wiki', null);
  result (_parent_path, _dirname, _parent_col_id, _rid);
  if (_rid < 0)
    return;
  WV.WIKI.LOADCOLLECTIONFROMFILES (concat (_parent_path, '/', _dirname), _rid, 0, _user, _group);
}
;  


create procedure WV.WIKI.LOADCLUSTERFROMFILES (in _dirfullpath varchar, in _cluster varchar, in _user varchar default 'Wiki', in _group varchar default 'WikiAdmin')
{
  declare _topic WV.WIKI.TOPICINFO;
  _topic := WV.WIKI.TOPICINFO();
  _topic.ti_cluster_name := _cluster;
  _topic.ti_fill_cluster_by_name();
  WV.WIKI.LOADCOLLECTIONFROMFILES (_dirfullpath, _topic.ti_col_id, 1, _user, _group);
}
;


-- Utils


create function WV.WIKI.SINGULARPLURAL (in _src varchar)
{ -- Converts an English noun between singular and plural form.
  declare _src_len integer;
  declare _suf varchar;
  _src_len := length (_src);
  if (_src_len < 4)
    return _src;
  _suf := right (_src, 3);
  if (_suf = 'SES')
    return concat (left (_src, _src_len - 2), 'S');
  if (_suf = 'ses')
    return concat (left (_src, _src_len - 2), 'ses');
  _suf := right (_src, 2);
  if (_suf = 'SS')
    return concat (left (_src, _src_len - 2), 'SES');
  if (_suf = 'ss')
    return concat (left (_src, _src_len - 2), 'ses');
  _suf := right (_src, 1);
  if (_suf = 'S' or _suf = 's')
    return left (_src, _src_len - 1);
  if (upper(_suf) = _suf)
    return concat (_src, 'S');
  return concat (_src, 's');
}
;

create function WV.WIKI.FORCEDWIKIWORD (in _src varchar)
{
  -- converts "hello world" to "HelloWorld"
  return _src;
}
;

create function WV.WIKI.FILENAMETOWIKINAME (in _src varchar)
{ -- Converts file name to WikiName of the topic.
  declare _src_len integer;
  declare _suf varchar;
  _src_len := length (_src);
  if (_src_len < 4)
    return _src;
  _suf := right (_src, 4);
  if (_suf = '.txt')
    return left (_src, _src_len - 4);
  if (_suf = '.TXT')
    return left (_src, _src_len - 4);
  if (strchr (_src, '.'))
    WV.WIKI.APPSIGNAL (11001, 'Resource name "&ResName;" cannot be converted to Wiki page name (must have .txt extension or no extension at all)',
      vector ('ResName', _src) );
  return _src;
}
;

create procedure WV.WIKI.APPSIGNAL (in _errno integer, in _text varchar, in _data any)
{ -- Signals formatted error message.
-- _text may contain substrings like &ParameterName;
-- _data is a vector of parameter names and values.
  declare _val any;
  declare _res varchar;
  declare _ctr integer;
-- TODO: search in AppErrors.
  _res := _text;
  _ctr := length (_data);  
  while (_ctr > 1)
    {
      _ctr := _ctr - 2;
      _val := aref (_data, _ctr+1);
      if (_val is null)
        _val := '(unknown)';
      else
        _val := cast (_val as varchar);
      _res := replace (_res, concat ('&', aref (_data, _ctr), ';'), _val);
    }
  signal ('42WV9', sprintf ('[%ld] %s',_errno, _res));
}
;

create procedure WV.WIKI.GETATTCOLID (in _topic WV.WIKI.TOPICINFO)
{
  declare _col_path varchar;
  declare _attachment_col_id integer;
  _col_path := DB.DBA.DAV_SEARCH_PATH (_topic.ti_col_id, 'C');
  _attachment_col_id := DB.DBA.DAV_SEARCH_ID ( _col_path || _topic.ti_local_name || '/', 'C');

  return _attachment_col_id;
}
;

create procedure WV.WIKI.ATTACH2 (
  in _uid integer,
  in _filename varchar,
  in _type varchar,
  in id integer,
  inout _text any,
  in comment varchar)
{
  declare _attachment_col_id integer;
  declare _topic WV.WIKI.TOPICINFO;

  _topic := WV.WIKI.TOPICINFO ();
  _topic.ti_id := id;
  _topic.ti_find_metadata_by_id ();
  _topic.ti_register_for_upstream('U');

  _attachment_col_id := WV.WIKI.GETATTCOLID (_topic);
  if (_attachment_col_id < 0)
  {
    _attachment_col_id := WV.WIKI.CREATEDAVCOLLECTION (_topic.ti_col_id, _topic.ti_local_name, _uid,  WV.WIKI.WIKIUSERGID());
    if (_attachment_col_id < 0)
      return;
      DB.DBA.DAV_PROP_SET_INT(DB.DBA.DAV_SEARCH_PATH (_attachment_col_id, 'C'),
			      'oWiki:topic-id', serialize (_topic.ti_id),
			      null, null, 0, 1, 1);
    }
  declare _full_path varchar;
  _full_path := WS.WS.COL_PATH (_attachment_col_id) || _filename;
  
  declare _path, _user varchar;
  _path := DB.DBA.DAV_SEARCH_PATH (_topic.ti_res_id, 'R');
  _user := (select U_NAME from DB.DBA.SYS_USERS where U_ID = _uid);
  DB.DBA.DAV_RES_UPLOAD (_full_path, _text, _type, '110000000R', 
    _uid, 'WikiUser', 'dav', (select pwd_magic_calc (U_NAME, U_PWD, 1) from WS.WS.SYS_DAV_USER where U_ID = http_dav_uid()),
    coalesce ( (select Token from WV.WIKI.LOCKTOKEN where UserName = _user and ResPath = _path), 1));
  insert replacing WV.WIKI.ATTACHMENTINFONEW values (_filename, _full_path, comment);
  DB.DBA.DAV_PROP_SET_INT(_full_path, 'oWiki:belongs-to', _path, null, null, 0, 1, 1);
  DB.DBA.DAV_PROP_SET_INT(_full_path, 'oWiki:md5', md5(cast (_text as varbinary)), null, null, 0, 1, 1);
  commit work;
}
;

create procedure WV.WIKI.ATTACHMENTACTION (
  in _uid integer, 
  in _topic_id integer,
  in _attachment_name varchar,
  in _cmd varchar)
{
  declare _topic WV.WIKI.TOPICINFO;
  declare _text varchar;
  _topic := WV.WIKI.TOPICINFO ();
  _topic.ti_id := _topic_id;
  _topic.ti_find_metadata_by_id ();
  _topic.ti_register_for_upstream('U');

  declare _attachment_col_id integer;
  _attachment_col_id := WV.WIKI.GETATTCOLID (_topic);
  DB.DBA.DAV_DELETE (concat (WS.WS.COL_PATH(_attachment_col_id), _attachment_name), 1, 'dav', (select pwd_magic_calc (U_NAME, U_PWD, 1) from WS.WS.SYS_DAV_USER where U_ID = http_dav_uid()));
}
;

WV.Wiki.EXEC_41000_I('drop procedure "WV"."Wiki"."CheckReadAccess"')
;

create function WV.WIKI.MAXPARENTDEPTH ()
{
  return 25;
}
;

create procedure WV.WIKI.CHECKPARENT (in _topic_id integer, in _parent integer, in _depth integer)
{
  if (_parent = 0)
    return 0;
  if ((_depth > WV.WIKI.MAXPARENTDEPTH()) or (_parent = _topic_id))
    {
	return -1;
    }
  return WV.WIKI.CHECKPARENT (_topic_id, (select ParentId from  WV.WIKI.TOPIC where TopicId = _parent),  _depth + 1);
}
;

create procedure WV.WIKI.TOPICSETPARENT (in _topic_id integer, in _parent integer)
{
  if (WV.WIKI.CHECKPARENT (_topic_id, _parent, 0) = -1)
    {
	declare _topic WV.WIKI.TOPICINFO;
	_topic := WV.WIKI.TOPICINFO ();
	_topic.ti_id := _topic_id;
	_topic.ti_find_metadata_by_id ();
  	return 'This topic can not be set as parent of ' || _topic.ti_cluster_name || '.' || _topic.ti_local_name;
    }
  update WV.WIKI.TOPIC set ParentId = _parent where TopicId = _topic_id;
  return null;
}
;

create procedure WV.WIKI.ISWIKIWORD (in _nm varchar)
{
  declare _res varchar;
  _nm := trim (_nm);
  _res := regexp_match ('[A-Z]+[a-z]+[A-Z]+[A-Za-z0-9]*', _nm);
  if (_res is null) 
	return 0;
  if (_res <> _nm) 
	return 0;
  return 1;
}
;

create procedure WV.WIKI.RENAMETOPIC (in _topic WV.WIKI.TOPICINFO,
	in _user varchar, 
  in new_cluster integer,
	in new_name varchar)
{
  new_name := trim (new_name);
  if (new_name = '')
	signal ('XXXXX', 'Invalid topic name');
  if (WV.WIKI.ISWIKIWORD (new_name) <> 1)
	signal ('XXXXX', new_name || ' is not WikiWord');

  declare _from, _to varchar;
  _from := DB.DBA.DAV_SEARCH_PATH (_topic.ti_res_id, 'R');
  _to := DB.DBA.DAV_SEARCH_PATH ( (select ColId from WV.WIKI.CLUSTERS where ClusterId = new_cluster) , 'C') || new_name || '.txt';
 
  declare _res integer;
  _res := DB.DBA.DAV_MOVE_INT (_from, _to, 1, 
    'dav', (select pwd_magic_calc (U_NAME, U_PWD, 1) from WS.WS.SYS_DAV_USER where U_ID = http_dav_uid()), 1, 
    coalesce (WV.WIKI.GET_LOCKTOKEN (_topic.ti_res_id), 1));
  if (DAV_HIDE_ERROR (_res) is null)
    WV.WIKI.APPSIGNAL (11002, '&Topic; can not be moved to &NewTopic; due to DAV_MOVE fail: &Result;',
       vector ('Topic', _topic.ti_local_name, 'NewTopic', new_name, 'Result', _res));
  commit work;
}
;

create procedure WV.WIKI.COPYTOPIC (
  in new_topic_name varchar,
  in old_topic WV.WIKI.TOPICINFO,
	in vspx_user varchar)
{
  declare exit handler for sqlstate '*'
  {
    --dbg_obj_print (__SQL_STATE, __SQL_MESSAGE);
    goto fin;
  };

  new_topic_name := trim (new_topic_name);
  if (new_topic_name = '')
	  signal ('XXXXX', 'Invalid topic name');

	declare _content, _type  varchar;
  declare _owner_uid integer;
	_owner_uid := (select COL_OWNER from WS.WS.SYS_DAV_COL where COL_ID = old_topic.ti_col_id);
  if (0 < DB.DBA.DAV_RES_CONTENT_INT (old_topic.ti_res_id, _content, _type, 0, 0)) {
    if (new_topic_name like 'Category%')
	    if (old_topic.ti_local_name not like 'Category%')
	      _content := WV.WIKI.ADD_REFBY_MACRO (_content);
    WV.WIKI.UPLOADPAGE (old_topic.ti_col_id, new_topic_name ||'.txt', _content, _owner_uid, old_topic.ti_cluster_id, vspx_user, 1);
  }

  -- copy attachments

  -- declare _author_uid integer;
  -- _author_uid := (select U_ID from DB.DBA.SYS_USERS where U_NAME = vspx_user);
  declare attachments_path varchar;
  attachments_path := WS.WS.COL_PATH(old_topic.ti_col_id) || old_topic.ti_local_name || '/';
  if (DB.DBA.DAV_SEARCH_ID (attachments_path, 'C') > 0) {
    declare attachment_list any;
  	  --dbg_obj_princ ('dir list');
    attachment_list := WV..TOPIC_LIST (attachments_path);
    if (attachment_list is not null){
    	declare _topic WV.WIKI.TOPICINFO;
  	  _topic := WV.WIKI.TOPICINFO();
  	  _topic.ti_cluster_name := old_topic.ti_cluster_name;
  	  _topic.ti_fill_cluster_by_name();
  	  _topic.ti_local_name := new_topic_name;
  	  _topic.ti_find_id_by_local_name();
  	  if (_topic.ti_id is not null and _topic.ti_id > 0) {
  	    _topic.ti_find_metadata_by_id();
  	    foreach (any att_spec in attachment_list) do	{
          declare res_id integer;
    		  declare att_type varchar;
    		  declare att_content, att_content2 any;
    		  res_id := DB.DBA.DAV_RES_CONTENT_INT (DB.DBA.DAV_SEARCH_ID (attachments_path || att_spec, 'R'),
    		  	att_content,
    			  att_type,
    			  0, 0);
    		  if (att_type is null)
    		    att_type := 'application/octet-stream';
    		  if (1) {
    		    declare att_id any;
  		      att_id := DAV_SEARCH_ID (DAV_SEARCH_PATH (_topic.ti_attach_col_id, 'C') || att_spec, 'R');
  		      declare content, _type any;
    		    if (_topic.ti_attach_col_id = 0
    			    or (coalesce(DAV_HIDE_ERROR (DAV_PROP_GET_INT (att_id, 'R', 'oWiki:md5', null, null, 0)), '') <> md5 (cast (att_content as varbinary))))
    			  {
              declare _res integer;
  				    _res := WV.WIKI.ATTACH2 (_owner_uid, att_spec, att_type,	_topic.ti_id,	att_content,	' -- ');
  				    commit work;
  				    result (att_spec);
  				  }
  			  }
  		  }
  	  }
  	}
  }
;

fin:
	;
}
;
create procedure WV.WIKI.DELETETOPIC2 (
  in topic WV.WIKI.TOPICINFO,
	in vspx_user varchar)
{
  declare exit handler for sqlstate '*' {
    --dbg_obj_print (__SQL_STATE, __SQL_MESSAGE);
    goto fin;
  };

  DB.DBA.DAV_DELETE_INT (DB.DBA.DAV_SEARCH_PATH (topic.ti_res_id, 'R'), 1, null, null, 0);

  -- delete attachments
  declare _attachments_path varchar;
  _attachments_path := WS.WS.COL_PATH(topic.ti_col_id) || topic.ti_local_name || '/';
  if (DB.DBA.DAV_SEARCH_ID (_attachments_path, 'C') > 0)
    DB.DBA.DAV_DELETE_INT (_attachments_path, 1, null, null, 0);

fin:
	;
}
;

create procedure WV.WIKI.RENAMETOPIC2 (
  in _topic WV.WIKI.TOPICINFO,
	in _user varchar,
  in new_cluster integer,
	in new_name varchar)
{
  declare exit handler for sqlstate '*'
  {
    --dbg_obj_print (__SQL_STATE, __SQL_MESSAGE);
    rollback work;
    return;
  };

  new_name := trim (new_name);
  if (new_name = '')
	signal ('XXXXX', 'Invalid topic name');

  declare _res integer;
  declare old_cluster_name, old_name varchar;
  declare _from, _to varchar;
  declare wiki_user varchar;
  declare user_id integer;

  old_cluster_name := _topic.ti_cluster_name;
  old_name := _topic.ti_local_name;

  _topic.ti_register_for_upstream ('D');
  _from := DB.DBA.DAV_SEARCH_PATH (_topic.ti_res_id, 'R');
  _to := DB.DBA.DAV_SEARCH_PATH ( (select ColId from WV.WIKI.CLUSTERS where ClusterId = new_cluster) , 'C') || new_name || '.txt';
  _res := DB.DBA.DAV_MOVE_INT (_from,
                               _to,
                               1,
                               'dav',
                               WV.WIKI.user_password (http_dav_uid()),
                               1,
                               coalesce (WV.WIKI.GET_LOCKTOKEN (_topic.ti_res_id), 1)
                              );
  if (DAV_HIDE_ERROR (_res) is null)
  {
    WV.WIKI.APPSIGNAL (11002, '&Topic; can not be moved to &NewTopic; due to DAV_MOVE fail: &Result;',
       vector ('Topic', _topic.ti_local_name, 'NewTopic', new_name, 'Result', _res));
    return;
  }

  -- rename/move attachments' collection
  declare _attachments_path varchar;

  _attachments_path := WS.WS.COL_PATH(_topic.ti_col_id) || _topic.ti_local_name || '/';
  if (DB.DBA.DAV_SEARCH_ID (_attachments_path, 'C') > 0)
  {
    _from := _attachments_path;
    _to := WS.WS.COL_PATH(_topic.ti_col_id) || new_name || '/';
    _res := DB.DBA.DAV_MOVE_INT (_from,
                                 _to,
                                 1,
                                 'dav',
                                 WV.WIKI.user_password (http_dav_uid()),
                                 1,
                                 1
                                );
    if (DAV_HIDE_ERROR (_res) is null)
    {
      WV.WIKI.APPSIGNAL (11002,
                         'Attachments of &Topic; can not be moved to &NewTopic; due to DAV_MOVE fail: &Result;',
                         vector ('Topic', _topic.ti_local_name, 'NewTopic', new_name, 'Result', _res)
                        );
      return;
    }
  }
  user_id := (select U_ID from DB.DBA.SYS_USERS where U_NAME = _user);
  wiki_user := WV.WIKI.USER_WIKI_NAME_2 (user_id);
  update WV.WIKI.TOPIC
     set AuthorName = 'Main.' || wiki_user,
         AuthorId = user_id,
         LocalName = new_name,
         LocalName2 = WV.WIKI.SINGULARPLURAL (new_name)
     where ResId = _topic.ti_res_id;

  update WV.DBA.HIST
     set H_TOPIC = new_name
   where H_CLUSTER = old_cluster_name
     and H_TOPIC = old_name;

  _topic.ti_register_for_upstream ('I');

  commit work;
}
;


create procedure WV.WIKI.GETFULLDAVPATH (in col_id integer, in _res_id integer, in local_name varchar)
{
  declare _res_path varchar;
  _res_path := DB.DBA.DAV_SEARCH_PATH (_res_id, 'R');
  if (_res_path <> -1)
    return _res_path;
  return WS.WS.COL_PATH (col_id) || local_name || '.txt';
}
;

create function WV.WIKI.CHECKREADACCESS (in _u_id integer,
					       in res_id integer,
					       in res_cluster_id integer,
					       in res_col_id integer,
					       in error_message varchar := NULL) returns integer
{
  return WV.WIKI.CHECKACCESS (_u_id, res_id, res_cluster_id, res_col_id, 0, error_message);
}
;

create function WV.WIKI.CHECKWRITEACCESS (in _u_id integer,
					       in res_id integer,
					       in res_cluster_id integer,
					       in res_col_id integer,
					       in error_message varchar := NULL) returns integer
{
  return WV.WIKI.CHECKACCESS (_u_id, res_id, res_cluster_id, res_col_id, 1, error_message);
}
;

-- returns lock token, or null
create function WV.WIKI.GET_LOCKTOKEN (in res_id integer)
{
  declare res_path varchar;
  res_path := DB.DBA.DAV_SEARCH_PATH (res_id, 'R');
  if (isstring (res_path))
    return (select Token from WV.WIKI.LOCKTOKEN where ResPath = res_path);
  return NULL;
}
; 
      

create function WV.WIKI.GETLOCK (in _path varchar, in _uname varchar) returns integer
{
  -- while DAV_LOCK does not work...
  declare _token, op_token varchar;
  declare _res_id integer;
  _res_id := DAV_SEARCH_ID (_path, 'R');
  _token := (select Token from WV.WIKI.LOCKTOKEN
  	where ResPath = _path);
  declare _type varchar;
  declare _res integer;
  _type := 'R';
--  if (0 < (_res := DB.DBA.DAV_IS_LOCKED_INT (_res_id, _type, _token)))
--    {
--      dbg_printf ('locked by owner (OK)');
--      return _res;
--    }
  if (_token is not null)
    op_token := '(<opaquelocktoken:'||_token||'>)';
  else
    op_token := null;
  _token := DB.DBA.DAV_LOCK (_path, 'R', 'X', _token,
  	_uname, op_token, null, WV.WIKI.LOCKEXPIRATION() , _uname,
	(select pwd_magic_calc(U_NAME, U_PASSWORD, 1) from DB.DBA.SYS_USERS where U_NAME = _uname));
  if (isstring (_token))
    {
      --dbg_printf ('lock OK', _token);
      insert replacing WV.WIKI.LOCKTOKEN (UserName, ResPath, Token)
        values (_uname, _path, _token);
      return 0;
    }
  --dbg_printf ('lock FAILED');
  WV.WIKI.APPSIGNAL (11001, 'Cannot set lock on &path;', vector ('path', _path));
  return 1;
}
;

create procedure WV.WIKI.RELEASELOCK (in _path varchar, in _uname varchar)
{
  -- while DAV_LOCK does not work
  if (isstring (_path))
    {
      declare _token varchar;
      _token := (select Token from WV.WIKI.LOCKTOKEN 
      	where ResPath = _path);
      if (_token is not null)
        {
	  if (DAV_HIDE_ERROR (DB.DBA.DAV_UNLOCK (_path, _token, _uname, 
		(select pwd_magic_calc(U_NAME, U_PASSWORD, 1) from DB.DBA.SYS_USERS where U_NAME = _uname) )) is not null)
	   {
	     delete from WV.WIKI.LOCKTOKEN where ResPath = _path;
	   }
	}
    }
}
;

create function WV.WIKI.LOCKEXPIRATION ()
{
  return 60 * 60; -- 1 hour
}
;

create function WV.WIKI.PARAM (in _user any, in _param varchar, in _defval any:=null) returns any
{
  declare _uid integer;
  if (isstring (_user))
    _uid := (select U_ID from DB.DBA.SYS_USERS where U_NAME = _user);
  else
    _uid := _user;

  for select Value from WV.WIKI.USERSETTINGS 
	       where ParamName = _param 
	       and UserId = _uid do
    {
      return Value;
    }
  return _defval;
}
;


create function WV.WIKI.GETCLUSTERID (in _cluster any) returns int
{
  declare _cl_id integer;
  if (isstring (_cluster))
    _cl_id := (select ClusterId from WV.WIKI.CLUSTERS where ClusterName = _cluster);
  else
    _cl_id := _cluster;
  if (_cl_id is null)
    signal ('XXXX', 'Unknown cluster' || _cluster);
  return _cl_id;
}
;

create function WV.WIKI.GETCLUSTERNAME (in _cluster integer) returns varchar
{
  return (select ClusterName from WV.WIKI.CLUSTERS where ClusterId = _cluster);
}
;


create function WV.WIKI.CLUSTERPARAM (in _cluster any, in _param varchar, in _defval any:=null) returns any
{
  --dbg_obj_princ ('CLUSTERPARAM ', _cluster, ' ', _param, ' ', _defval);
  for select Value from WV.WIKI.CLUSTERSETTINGS 
	       where ParamName = _param 
	       and ClusterId = WV.WIKI.GETCLUSTERID (_cluster)
  do 
    {
      return Value;
    }
  return _defval;
}
;

grant execute on WV.WIKI.CLUSTERPARAM to public
;

xpf_extension ('http://www.openlinksw.com/Virtuoso/WikiV/:ClusterParam', 'WV.WIKI.CLUSTERPARAM')
;

create procedure WV.WIKI.SETPARAM (in _user any, in _param varchar, in _val any)
{
  declare _uid integer;
  if (isstring (_user))
    _uid := (select U_ID from DB.DBA.SYS_USERS where U_NAME = _user);
  else
    _uid := _user;

  insert replacing WV.WIKI.USERSETTINGS values (_uid, _param, _val);
}
;

create procedure WV.WIKI.SETCLUSTERPARAM (in _cluster any, in _param varchar, in _val any)
{
  insert replacing WV.WIKI.CLUSTERSETTINGS values ( WV.WIKI.GETCLUSTERID (_cluster), _param, _val);
}
;

create function WV.WIKI.MAKECATEGORYNAME (in _name varchar) returns varchar
{
  return ucase (subseq (_name, 0, 1)) || lcase (subseq (_name, 1));
}
;

create function WV.WIKI.MAKECATEGORYSHORTNAME (in _name varchar) returns varchar
{
  _name := lcase (_name);
  if (_name like 'category%')
    return subseq (_name, 8);
  return _name;
}
;


create function WV.WIKI.TOUCHCATEGORY (in _cluster_id integer, in fullname varchar, in is_pub integer) returns varchar
{
  declare _catname varchar;
  _catname := WV.WIKI.MAKECATEGORYSHORTNAME (fullname);
			       
  if (not exists (select 1 from WV.WIKI.CATEGORY where lcase (CategoryName) = lcase (fullname) 
	and _cluster_id = ClusterId))
    {
       insert into WV.WIKI.CATEGORY (CategoryId,
					  ClusterId,
					  IsDelIcioUsPub,
					  CategoryName,
					  ShortName)
	values (WV.WIKI.NEWPLAINTOPICID(),
		_cluster_id,
		is_pub,
		fullname,
		_catname);
    }
  else if (is_pub)
    WV.WIKI.DELICIOUSSYNCCATEGORY (fullname);
  return _catname;
}
;
  

create function WV.WIKI.DIUCATEGORYLINK (
  in _tag varchar) returns any
{ 
  -- creates local category if needed, returns wikiword				       
  declare _cat varchar;
  declare _c_id integer;
  declare _c_col_id, _owner integer;
  _c_id := connection_get ('ClusterId');
  _c_col_id := connection_get ('ColId');
  _owner := connection_get ('Owner');
  _cat := WV.WIKI.TAG_TO_CATEGORY (_tag, _c_id);
  if (not exists (select * from WV.WIKI.TOPIC where LocalName = _cat and ClusterId = _c_id))
    {
      WV.WIKI.UPLOADPAGE (_c_col_id, _cat || '.txt', 'Imported from del.icio.us\n', _owner);
--      DB.DBA.DAV_CHECKIN_INT (DB.DBA.DAV_SEARCH_PATH (_c_col_id, 'C') ||  _cat || '.txt', null, null, 0);
    }
  return _cat;
}
;

grant execute on WV.WIKI.DIUCATEGORYLINK to public
;

xpf_extension ('http://www.openlinksw.com/Virtuoso/WikiV/:DIUCategoryLink', 'WV.WIKI.DIUCATEGORYLINK')
;


-- should syncs all posts with del.icio.us in the category _category
-- but del.icio.us does not allow more frequent updates than 1 time per
-- second... so the implementation is still uncertain
create procedure WV.WIKI.DELICIOUSSYNCCATEGORY (in _category varchar)
{
  update WV.WIKI.CATEGORY set IsDelIcioUsPub = 1 where CategoryName = _category;
}
;


create procedure WV.WIKI.DELICIOUSSIGNAL (in _cluster any, in _err varchar)
{
  WV.WIKI.SETCLUSTERPARAM (_cluster, 'DelIcioUsLastError',
				 vector (now (),
					 _err));
  return xtree_doc ('<div class="wiki-error">' || _err || '</div>');
}
;
	
create function WV.WIKI.DELICIOUSUPDATEFUNCTION (in _is_full integer, in last_date datetime)
{
  ;
}
;

create procedure WV.WIKI.DELICIOUSSYNC (in _cluster integer, in _user varchar)
{
  --dbg_obj_princ ('WV.WIKI.DELICIOUSSYNC: ', _cluster, ' ', _user);
  declare _deluser, _delpassword varchar;
  _delpassword := WV.WIKI.CLUSTERPARAM (_cluster , 'delicious_password');
  if ((_delpassword is null) or (_delpassword = ''))
    return WV.WIKI.DELICIOUSSIGNAL (_cluster, 'del.icio.us integration is not configured');
  _deluser := WV.WIKI.CLUSTERPARAM (_cluster , 'delicious_user');
  declare _hdr, _doc, _res, _url any;

  _url := 'https://api.del.icio.us/v1/tags/get';
  _res := http_client(_url, _deluser, _delpassword, 'GET', null, null, null, null);
  _doc := xtree_doc (_res, 2);

  connection_set ('ClusterId', _cluster);
  connection_set ('ColId', (select ColId from WV.WIKI.CLUSTERS where ClusterId = _cluster));
  connection_set ('Auth', _user);
  connection_set ('Owner', (select U_ID from DB.DBA.SYS_USERS where U_NAME = _user));

  _res := xquery_eval ('
<div xmlns:wv="http://www.openlinksw.com/Virtuoso/WikiV/">
<div class="wiki_container">
  <ul>
  {
    for \$t in node()/tag[@tag != \'system:infiled\']
    order by \$t
    return 
	<li>{ wv:DIUCategoryLink (string(\$t/@tag)) }</li> 
  }
  </ul>
</div></div>', _doc);
  
  WV.WIKI.SETCLUSTERPARAM (_cluster, 'delicious_last_update', now());
  return _res;
}
;

create method ti_fill_url () for WV.WIKI.TOPICINFO
{
  declare _home varchar;
  _home := WV.WIKI.MAKE_CLUSTER_PATH(self.ti_cluster_name);
  if (_home is not null)
    self.ti_url := sprintf ('%s/%s', _home, WV.WIKI.READONLYWIKIWORDLINK (self.ti_cluster_name, self.ti_local_name));
  else
    self.ti_url := WV..TOPIC_URL (WV.WIKI.READONLYWIKIWORDLINK (self.ti_cluster_name, self.ti_local_name));
  return self.ti_url;
}
;

create procedure WV.WIKI.MAKECATEGORYNAMELIST (in _cluster integer, in _category_names any)
{
  declare _res, _fullname varchar;
  declare idx integer;

  _res := '';
  for (idx := 0; idx < length (_category_names); idx := idx + 1)
    {
      _fullname := _category_names[idx];
      WV.WIKI.TOUCHCATEGORY (_cluster, _fullname, 1);
      _res := _res || ' ' || WV.WIKI.MAKECATEGORYSHORTNAME (_fullname);
    }
  return trim (_res);
}
;

create function WV.WIKI.MAKEDELICIOUSDATESTAMP (in dt datetime)
{
  declare _parsed_dt any;
  _parsed_dt := split_and_decode (cast (dt as varchar), 0, '\0\0 ');
  if (length (_parsed_dt) > 1)
    {
      return 
	replace (aref (_parsed_dt, 0), '.', '-') 
	|| 'T' 
	|| subseq (aref (_parsed_dt, 1), 0, 8)
	|| 'Z';
    }
  return null;
}
;
	

create procedure WV.WIKI.DELICIOUSPUBLISH (in _topic_id integer, in _category_names any)
{
  declare _topic WV.WIKI.TOPICINFO;
  _topic := WV.WIKI.TOPICINFO ();
  _topic.ti_id := _topic_id;
  _topic.ti_find_metadata_by_id ();

  declare exit handler for sqlstate 'HT*', sqlstate '2E*' {
    --dbg_obj_print (__SQL_STATE, __SQL_MESSAGE);
    rollback work;
    return WV.WIKI.DELICIOUSSIGNAL (_topic.ti_cluster_id, 'del.icio.us connection error');
  };

  declare _deluser, _delpassword varchar;
  _delpassword := WV.WIKI.CLUSTERPARAM (_topic.ti_cluster_id , 'delicious_password');
  if ((_delpassword is null) or (_delpassword = ''))
    return WV.WIKI.DELICIOUSSIGNAL (_topic.ti_cluster_id, 'del.icio.us integration is not configured');
  _deluser := WV.WIKI.CLUSTERPARAM (_topic.ti_cluster_id , 'delicious_user');
  declare _func_post varchar;
  commit work;

  _func_post := sprintf ('https://api.del.icio.us/v1/posts/add?&url=%U&description=%U&extended=&tags=%U&dt=%U',
			 _topic.ti_fill_url (),
			 _topic.ti_local_name, -- temporary solution
			 WV.WIKI.MAKECATEGORYNAMELIST (_topic.ti_cluster_id, _category_names),
			 WV.WIKI.MAKEDELICIOUSDATESTAMP (now()));
  declare _hdr, _doc, _res any; 
  _res := http_client(_func_post, _deluser, _delpassword, 'POST', null, null, null, null);
  return _res;
}
;

create function WV.WIKI.PARSEPARAM (in arg varchar) returns any
{
  declare _res any;

  _res := split_and_decode (arg, 0, '\0\0=');
  aset (_res, 1, subseq (subseq (_res[1], 0, length (_res[1]) - 1), 1));
  return _res;
}
;
			  
create function WV.WIKI.PARSEMACROARGS (in args varchar, in flatten int := 0) returns any
{
  declare _args, _res any;
  vectorbld_init(_args);
  declare x varchar;
  x := regexp_substr ('[A-Za-z]*=\"[^"]*\"', args, 0);
  while (x is not null)
    {
      args := subseq (args, length (x));
      vectorbld_acc (_args, x);
      x := regexp_substr ('[A-Za-z]*=\"[^"]*\"', args, 0);
    }
  vectorbld_final (_args);
  --dbg_obj_print (_args);
  declare _len integer;
  
  _len := length (_args);
  _res := make_array (_len, 'any');
  declare idx integer;
  idx := 0;
  while (idx < length (_args))
    {
      aset (_res, idx, WV.WIKI.PARSEPARAM (aref (_args, idx)));
      idx := idx +1;
    }
  if (flatten)
    {
      declare _flatten_res any;
      _flatten_res := make_array (_len * 2, 'any');
      for (idx := 0; idx < _len ; idx:=idx+1)
	{
	  _flatten_res[idx*2] := _res[idx][0];
	  _flatten_res[idx*2+1] := _res[idx][1];
	}
      return _flatten_res;
    }
  return _res;
}
;

create function WV.WIKI.GETMACROPARAM (in params any, in name varchar, in defval varchar:='') returns varchar
{
  declare _idx integer;
  declare _name varchar;
  _idx := 0;
  _name := lcase (name);
  while (_idx < length (params))
    {
      if (_name = lcase (aref ( aref (params, _idx), 0)))
	return aref ( aref (params, _idx), 1);
    _idx := _idx + 1;
    }
  return defval;
}
;

create function WV.WIKI.CHECKACCESS (in _u_id integer,
					   in _res_id integer,
					   in res_cluster_id integer,
					   in _res_col_id integer,
             in is_write integer,
					   in error_message varchar:= NULL) returns integer
{
  declare acc_str varchar;
  acc_str := (case when (is_write) then '_1_' else '1__' end);

  declare rc integer;
  declare _pwd, _uname varchar;
  declare exit handler for not found {
    --dbg_obj_princ (__SQL_STATE, __SQL_MESSAGE);
    goto err;
  }
  ;
  select pwd_magic_calc (U_NAME, U_PASSWORD, 1), U_NAME into _pwd, _uname from DB.DBA.SYS_USERS where U_ID = _u_id and U_IS_ROLE = 0;
  --dbg_obj_princ ('DAV_AUTHENTICATE: ', _res_id, '/', _res_col_id, '  ', acc_str, ' ', _uname, ' ', _pwd);
  if (_res_id <> 0)
    rc := DAV_AUTHENTICATE (_res_id, 'R', acc_str, _uname, _pwd);
  else
    rc := DAV_AUTHENTICATE (_res_col_id, 'C', acc_str, _uname, _pwd);
  if (rc >= 0)
    return 1;
err:    
  if (is_write)
    WV.WIKI.APPSIGNAL (11003, coalesce (error_message, 'Write access to the resource has not been granted'), vector());
  else 
    WV.WIKI.APPSIGNAL (11004, coalesce (error_message, 'Read access to the resource has not been granted'), vector());
}
;


create function WV.WIKI.GETDEFAULTPERMS (in _cluster_id integer) returns varchar
{
  if (exists (select 1 from WV.WIKI.CLUSTERS
			where ClusterId = _cluster_id
			and ( ClusterName = 'Main'
			or ClusterName = 'Doc')))
    return '111101101RM';
  return '110000000RM';

  declare perms varchar;
  declare model integer;
  model := connection_get ('WikiMemberModel');
  if (model is null)
    model := coalesce ( (select WAI_MEMBER_MODEL  from WA_INSTANCE 
		       where WAI_TYPE_NAME = 'oWiki' 
		       and (WAI_INST as wa_wikiv).cluster_id = _cluster_id), 0);
  if (model = 0) -- Open
    return '110100100R'; -- everything else is solved by ACL
  -- Closed, Invitation Based, Approval Based
  -- all these model are managed by ACLs.
  return '110000000R';
}
;
  
create procedure WV.WIKI.ADDHISTORYITEM (
  in _topic WV.WIKI.ADDHISTORYITEM,
					       in _filename varchar, 
					       in _action varchar, 
					       in _context varchar,
					       in _user varchar)
{
  ;
}
;
					       
create procedure WV.WIKI.PRINTLENGTH (
  in sz integer)
{
  declare offs integer;

  offs := 0;

  while (sz > 9999) {
    sz :=  sz / 1024;
    offs := offs + 1;
  }   
  sz := floor (sz);

  return cast (sz as varchar) || aref (vector ('b','K','M','G','T'), offs);
}
;

create procedure WV.WIKI.ADDLINK (in _topic WV.WIKI.TOPICINFO, 
	in _type varchar,
	in _uid varchar,
	in _filename varchar,
	in _user varchar)
{
  declare _link varchar;
  if (_type not like 'image/%')
	  _link  := '<a href="%ATTACHURLPATH%/' || _filename || '" style="wikiautogen">' || _filename  || '</a>';
  else
	  _link  := '<img src="%ATTACHURLPATH%/' || _filename || '" style="wikiautogen"/>';
    
  declare _path, _user varchar;
  _path :=DB.DBA.DAV_SEARCH_PATH (_topic.ti_res_id, 'R');
  _user := (select U_NAME from DB.DBA.SYS_USERS where U_ID = _uid);
  WV.WIKI.GETLOCK (_path, _user);
  connection_set ('HTTP_CLI_UID', _user);
  DB.DBA.DAV_RES_UPLOAD (_path,
		cast (_topic.ti_text as varchar) || '\n   * ' || _link , 
		'text/plain', 
		'110000000R', 
		_uid, 
		'WikiUser', 
		'dav', (select pwd_magic_calc (U_NAME, U_PWD, 1) from WS.WS.SYS_DAV_USER where U_ID = http_dav_uid()),
		coalesce ( (select Token from WV.WIKI.LOCKTOKEN where UserName = _user and ResPath = _path), 1));
--  DB.DBA.DAV_CHECKIN_INT (_path, null, null, 0);
}
;  

create procedure WV.WIKI.NORMALIZETOWIKIWORD (
  in _name varchar)
{
  if (length (_name) = 0)
	return _name;
  if (length (_name) = 1)
	return ucase (_name);
  return ucase ( subseq (_name, 0, 1) ) || subseq (_name, 1);
}
;

create procedure WV.WIKI.CHECKWIKIWORD (in _name varchar)
{
  if (length (_name) = 0)
   WV.WIKI.APPSIGNAL (11001, '"&ResName;" is not WikiWord', vector ('ResName', _name) );
  return _name;
}
;

create procedure WV.WIKI.GETCOLLECTIONS (in _path varchar, in recursive int:= 0)
{
  declare _dir_list, _res any;
  _dir_list := DAV_DIR_LIST (_path, 0, 'dav', (select pwd_magic_calc (U_NAME, U_PWD, 1) from WS.WS.SYS_DAV_USER where U_ID = http_dav_uid())); 
  _res := vector ();
  if (isarray (_dir_list))
    {
      foreach (any _dir in _dir_list) do {
	if (ucase (aref (_dir, 1)) = 'C')
	  {
	    declare _paths any;
	    _paths := split_and_decode (aref (_dir, 0), 0, '\0\0/');
	    _res := vector_concat (_res, vector (aref (_paths, length (_paths) -2) ));
	  }
      }
      return _res;
    }
  else
    return vector ();
}
;

create procedure WV.WIKI.DELETEATTACHMENTLINKS (
	in _topic WV.WIKI.TOPICINFO,
  in _uid integer,
	in _attachment varchar)
{
  declare _path, _user varchar;
  _path := DB.DBA.DAV_SEARCH_PATH (_topic.ti_res_id, 'R');
  _user := (select U_NAME from DB.DBA.SYS_USERS where U_ID = _uid);
  DB.DBA.DAV_RES_UPLOAD (DB.DBA.DAV_SEARCH_PATH (_topic.ti_res_id, 'R'),
		WV.WIKI.DELETEATTACHMENTLINKS2 (_topic.ti_text, _attachment),
		'text/plain', 
		'110000000R', 
		_user, 
		'WikiUser', 
		'dav', (select pwd_magic_calc (U_NAME, U_PWD, 1) from WS.WS.SYS_DAV_USER where U_ID = http_dav_uid()),
		coalesce ( (select Token from WV.WIKI.LOCKTOKEN where UserName = _user and ResPath = _path), 1));
}
;

create procedure WV.WIKI.DELETEATTACHMENTLINKS2 (
	in _topic_text varchar,
	in _attachment varchar)
{
  declare _link, _link2 varchar;
  _link := '<[a|A]\\s+href="%ATTACHURLPATH%/' || _attachment || '"\\s+style="wikiautogen"[^>]*>.*</[a|A]>';
  _link2 := '<[i|I][m|M][g|G]\\s+src="%ATTACHURLPATH%/' || _attachment || '"\\s+style="wikiautogen"[^/>]*/>';
  return regexp_replace(
  	  regexp_replace (cast (_topic_text as varchar), _link, '', 1, null),
	  _link2,
	  '',
	  1,
	  null);
}
;


create procedure WV.WIKI.FIX_PERMISSIONS ()
{
  declare exit handler for sqlstate '*' {
    rollback work;
    return;
  };
  for select RES_ID as id, RES_PERMS as old_perms, RES_FULL_PATH from WV.WIKI.TOPIC, WS.WS.SYS_DAV_RES where RES_ID = ResId and RES_PERMS like '%N'
  do
   {
     --dbg_obj_princ ('update ', RES_FULL_PATH);
     set triggers off;
     update WS.WS.SYS_DAV_RES set RES_PERMS = replace (old_perms, 'N','R') where RES_ID = id;
     set triggers on;
   }
}
;


-- checks, is content differs from content of existing topic
create function WV.WIKI.DIFFS (in _cluster varchar, in file_name varchar, inout content varchar)
{
  declare exit handler for sqlstate 'DF001' {
    return 1;
  };
  if (not isstring (content))
    return 1;
  if (file_name not like '%.txt')
    return 1;
  declare _topic WV.WIKI.TOPICINFO;
  _topic := WV.WIKI.TOPICINFO();
  _topic.ti_cluster_name := _cluster;
  _topic.ti_fill_cluster_by_name ();
  _topic.ti_local_name := subseq (file_name, 0,length (file_name) - 4);
  _topic.ti_find_id_by_local_name ();
  if (_topic.ti_id = 0)
    return 1;
  _topic.ti_find_metadata_by_id();
  declare _text varchar;
  _text :=  WV.WIKI.DELETE_SYSINFO_FOR (cast (_topic.ti_text as varchar), NULL);
  while (_text[0] and 
  	(_text[length(_text)-1] = 10 or _text[length(_text) -1] = 32))
    _text := subseq (_text, 0, length(_text)-1);
  while (content[0] and 
  	(content[length(content)-1] = 10 or content[length(content)-1] = 32))
    content := subseq (content, 0, length(content)-1);
  if (_text <> content)
    return diff(_text, content);
  return 0;
}
;

-- import procedure 
-- needs existing cluster, and DAV repository where to get the stuff (can be HostFs DET)

create procedure WV..TOPIC_LIST(in _coll varchar)
{
  declare _cid integer;
  _cid := DB.DBA.DAV_SEARCH_ID (_coll, 'C');
  if (_cid < 0)
    return vector();
  declare _res any;
  vectorbld_init(_res);
  for select RES_NAME from WS.WS.SYS_DAV_RES where RES_COL = _cid do {
    vectorbld_acc(_res, RES_NAME);
  }
  vectorbld_final(_res);
  return _res;
}
;

create procedure WV..COLLECTION_LIST(in _coll varchar)
{
  declare _cid integer;
  _cid := DB.DBA.DAV_SEARCH_ID (_coll, 'C');
  if (_cid < 0)
    return vector();
  declare _res any;
  vectorbld_init(_res);
  for select COL_NAME from WS.WS.SYS_DAV_COL where COL_PARENT = _cid do {
    vectorbld_acc(_res, COL_NAME);
  }
  vectorbld_final(_res);
  return _res;
}
;

create procedure WV.WIKI.IMPORT (in _cluster varchar,
	in source_path varchar, 
	in attachments_path varchar, 
	in auth varchar, 
	-- when non zero makes checkpoint after importing 
	-- checkpoint_cnt topics
	in checkpoint_cnt int:=1000)	 
{
  declare cluster_path varchar;
  declare cluster_col_id, cluster_id integer;
  declare rc integer;
  declare checkpoint_idx integer;

  cluster_col_id := (select ColId from WV.WIKI.CLUSTERS where ClusterName = _cluster);
  if (cluster_col_id is null)
    signal ('WV004', 'Cluster ' || _cluster || ' does not exist');
  cluster_id := (select ClusterId from WV.WIKI.CLUSTERS where ClusterName = _cluster);
  cluster_path := DB.DBA.DAV_SEARCH_PATH (cluster_col_id, 'C');
  delete from WV.WIKI.LINK 
    where DestId is null or DestId = 0
    and exists (select 1 from WV.WIKI.TOPIC where ClusterId = cluster_id and TopicId = OrigId);

  declare dir_list any;
  dir_list :=  WV..TOPIC_LIST (source_path);
  if (dir_list is null)
    signal ('WV006', 'Can not get directory listing from ' || source_path);
  if(checkpoint_cnt > 0)
    checkpoint_idx := 1;

  declare owner integer;
  owner := (select U_ID from DB.DBA.SYS_USERS where U_NAME = auth);

  declare update_list any;
  vectorbld_init (update_list);

  foreach (any file_spec in dir_list) do
    {
      declare content, type varchar;
      if (file_spec like '%.txt')
        {
	  rc := DB.DBA.DAV_RES_CONTENT_INT (DAV_SEARCH_ID (source_path || file_spec, 'R'), 
	  	content, type, 0, 0);
	  if (rc < 0)
	    signal ('WV005', 'Can not get content from ' || file_spec || ' [' || DB.DBA.DAV_PERROR (rc) || ']');
	  --dbg_obj_princ ('got from ' || file_spec[10] || ': ', subseq (content, 0, 40));
	  if (file_spec like 'Category%')
	    content := WV.WIKI.ADD_REFBY_MACRO (content);
    if (WV.WIKI.DIFFS (_cluster, file_spec, content))
	    {
  	      declare _path varchar;
	      _path := DB.DBA.DAV_SEARCH_PATH (cluster_col_id, 'C') ||  file_spec;
  	      WV.WIKI.GETLOCK (_path, auth);
	      WV.WIKI.UPLOADPAGE (cluster_col_id, file_spec, content, owner, 0, auth);
    	      WV.WIKI.RELEASELOCK (_path, auth);
--              DB.DBA.DAV_CHECKIN_INT (DB.DBA.DAV_SEARCH_PATH (cluster_col_id, 'C') ||  file_spec, null, null, 0);
	      commit work;
	      result (file_spec);
	      vectorbld_acc (update_list, file_spec);
	      -- result (file_spec[10]);
	      --dbg_obj_princ ('import: ', file_spec[10]);
	      if(checkpoint_cnt > 0)
	        {
		  if (checkpoint_idx < checkpoint_cnt)
		    checkpoint_idx := checkpoint_idx + 1;
		  else
		    {
		      checkpoint_idx := 1;
		      exec ('checkpoint');
		    }
		}
	     }
	 }
     }
  vectorbld_final (update_list);
  WV.WIKI.POSTPROCESS_LINKS (cluster_id);

  if(checkpoint_cnt > 0)
    checkpoint_idx := 1;

  whenever sqlstate '40*' default;
  foreach (any file_spec in update_list) do
    {
      if (file_spec like '%.txt')
	{
	  declare _topic WV.WIKI.TOPICINFO;
	  _topic := WV.WIKI.TOPICINFO ();
    _topic.ti_cluster_name := _cluster;
	  _topic.ti_fill_cluster_by_name ();
	  _topic.ti_local_name := subseq (file_spec, 0, length (file_spec) - 4);
	  _topic.ti_find_id_by_local_name();
	  if (_topic.ti_id <> 0)
	    {
	      _topic.ti_find_metadata_by_id ();
      -- render page for set parents etc...      
--	dbg_obj_print ('CHECK TPC ', _topic.ti_local_name);
	       commit work;
	    }
	}
     }


  if (attachments_path is not null)
    dir_list := WV..COLLECTION_LIST (attachments_path);
  else
    dir_list := vector();


  whenever sqlstate '40*' goto fix_links;
  foreach (any file_spec in dir_list) do
    {
	  declare attachment_list any;
	  --dbg_obj_princ ('dir list');
      attachment_list := WV..TOPIC_LIST (attachments_path || file_spec || '/');
	  if (attachment_list is not null)
	    {
  	      declare _topic WV.WIKI.TOPICINFO;
	      _topic := WV.WIKI.TOPICINFO();
    _topic.ti_cluster_name := _cluster;
	      _topic.ti_fill_cluster_by_name();
	  _topic.ti_local_name := file_spec;
	      _topic.ti_find_id_by_local_name();
	      if (_topic.ti_id is not null 
		  and _topic.ti_id > 0)
		{
		  _topic.ti_find_metadata_by_id();
	--dbg_obj_princ (_topic);
		  foreach (any att_spec in attachment_list) do
		    {
      declare res_id integer;
		  declare att_type varchar;
		  declare att_content, att_content2 any;
--		  dbg_obj_princ ('get ', attachments_path || file_spec || '/' || att_spec);
		  res_id := DB.DBA.DAV_RES_CONTENT_INT(DB.DBA.DAV_SEARCH_ID (attachments_path || file_spec || '/' || att_spec, 'R'),
		  	att_content, 
			att_type,
			0, 0);
--		  att_content := string_output_string (att_content);
--		  att_type := DB.DBA.DAV_GUESS_MIME_TYPE_BY_NAME (att_spec);
		  if (att_type is null)
		    att_type := 'application/octet-stream';
		  if (1)
	 	         {
  			    declare att_id any;
		      att_id := DAV_SEARCH_ID (DAV_SEARCH_PATH (_topic.ti_attach_col_id, 'C') || att_spec, 'R');
			    declare content, _type any;
			    if (_topic.ti_attach_col_id = 0 
			     or (coalesce(DAV_HIDE_ERROR (DAV_PROP_GET_INT(
						  att_id, 'R',
						  'oWiki:md5', null, null, 0)), '') 
				  <> md5 (cast (att_content as varbinary))))
			      {
				  -- if (isblob(content) or isstring (content))
					 --dbg_obj_princ ('>', cast (content as varchar), '\n>',  cast (att_content as varchar));
			  	    --dbg_obj_princ ('attach ', att_spec[10], ' ', att_type);
            declare _res integer;
				    _res := WV.WIKI.ATTACH2 (owner,
					  	  att_spec,
			   		 att_type,
				    	_topic.ti_id,
				    	att_content,
				   	' -- ');
				    commit work;
				    result (att_spec);
				    --dbg_obj_princ ('done');
			  	    if(checkpoint_cnt > 0)
				      {
				        if (checkpoint_idx < checkpoint_cnt)
					    checkpoint_idx := checkpoint_idx + 1;
					else	
					  {
					    checkpoint_idx := 1;
					    exec ('checkpoint');
					  }
				      }
			      }
			   }
		    	}
		    }
	    	}
	}
    
 fix_links:
  return 'done';      
}
;

-- checks for <data ... tags, incorrect PARENT macros in topic text
create procedure WV.WIKI.CHECK_TOPIC (
  in _topic WV.WIKI.TOPICINFO,
  in auth varchar,
  in pwd varchar)
{
  if (_topic.ti_local_name is null)
    return NULL;
  declare exit handler for sqlstate '*' {
    --dbg_obj_princ (__SQL_STATE, __SQL_MESSAGE);
    return NULL;
  }
  ;
  connection_set ('WikiV macro TOPICINFO', NULL);
  connection_set ('WIKI params', vector());
  WV.WIKI.VSPXSLT ( 'VspTopicView.xslt', _topic.ti_get_entity (null,1),
    _topic.ti_xslt_vector(vector ('uid', 0,
		'user', auth, 
    		'baseadjust', '../',
		'rnd', 1,
		'attachments', _topic.ti_report_attachments(),
		'is_hist', 0,
		'revision', 0,
		'sid', '',
		'realm', '',
		-- we do not need pretty printing here
		-- anyway output is going to trash,
		-- we need side effect here
		'donotresolve', 1,
		-- tell macros to this is import procedure
		'import', 1)));
  return 1;
}
;

-- generates new password, login can be used, but it is not necessary
create procedure WV.WIKI.GENERATE_NEW_PASSWORD (in login varchar)
{
  declare idx integer;
  declare pwd varchar2;
  pwd := make_string (8);
  for (idx:=0; idx<6; idx:=idx+1)
    {
	  pwd[idx] :=  rnd(25) + 97;
	}
  for (idx:=6; idx<8; idx := idx + 1)
    {
	  pwd[idx] := rnd(10) + 48;
	}
  return pwd;
}
;
	  

-- importing users is allowed only to dba
-- usersinfo is a vector of login name, e-mail, and full name (usually WikiWord)
-- if login name already exists, the full name and e-mail are changed if and only 
-- if [rewrite] is not zero. For new logins passwords are generated.
-- Format of userinfo structure:
-- 1. login name
-- 2. e-mail
-- 3. fullname 
create procedure WV.WIKI.IMPORT_USERS (in usersinfo any, 
	in rewrite int := 0, 
	in clusters any := NULL, 
	in add_to_owners integer:= 0)
{
  declare idx integer;
  if (not isarray (usersinfo))
    signal ('WV200', 'Userinfo array is expected to be array of array of three elements');
  for (idx:=0; idx<length(usersinfo); idx:=idx+1)
    {
      declare login, e_mail, fullname varchar;
      declare secquestion, secanswer varchar;
      if (not isarray(usersinfo[idx]) or
	      not length(usersinfo[idx]) > 0)
	signal ('WV200', 'Userinfo array is expected to be array of array of three elements');
      login := trim (usersinfo[idx][0]);
      e_mail := usersinfo[idx][1];
      fullname := usersinfo[idx][2];
      secquestion := usersinfo[idx][3];
      secanswer := usersinfo[idx][4];

      declare uid integer;
      uid := (select U_ID from SYS_USERS where U_NAME = login);
      if (uid is null)
        {
	  uid := USER_CREATE (login, WV.WIKI.GENERATE_NEW_PASSWORD (login),
		     vector ('E-MAIL', e_mail,
 'FULL_NAME', fullname,
					 'HOME', '/DAV/home/' || login || '/',
					 'DAV_ENABLE' , 1,
					 'SQL_ENABLE', 0));
	  DB.DBA.USER_GRANT_ROLE (login, 'WikiUser', 0);					 
	  -- create new wiki user
	  WV.WIKI.CREATEUSER (login, fullname, 'WikiUser', '', 1);		  
	  USER_SET_OPTION (login, 'SEC_QUESTION', secquestion);
	  USER_SET_OPTION (login, 'SEC_ANSWER', secanswer);
	}
      else if (rewrite)
	{
	  -- update e-mail and full names
	  update SYS_USERS 
	  	set U_E_MAIL = e_mail,
		    U_FULL_NAME = fullname
		where
		    U_ID = uid;
	  if (exists (select * from WV.WIKI.USERS where UserId = uid))
	    {
	      update WV.WIKI.USERS
	  	set UserName = fullname
		where 
		  UserId = uid;
  	    }
	  else
	    {
	      -- create new wiki user
	      WV.WIKI.CREATEUSER (login, fullname, 'WikiUser', '', 1);		  
	    }
	  USER_SET_OPTION (login, 'SEC_QUESTION', secquestion);
	  USER_SET_OPTION (login, 'SEC_ANSWER', secanswer);
	 }
      foreach (varchar cl in clusters) do
        {
    declare membership_type integer;
	  if (add_to_owners)
	    membership_type := 1;
	  else
	    membership_type := 2;
	  if (exists (select * from WV.WIKI.CLUSTERS where ClusterName = cl))
	    {
	      insert into WA_MEMBER (WAM_USER, WAM_INST, WAM_MEMBER_TYPE, WAM_STATUS)
	         values (uid, cl, membership_type, 1);
	      commit work;
	      -- needed to launch trigger
	      update WA_MEMBER set WAM_STATUS = 1
	        where WAM_USER = uid
		  and WAM_INST = cl
		  and WAM_MEMBER_TYPE = membership_type;
 	    }
	}
	 
    }
}
;
			
create procedure WV.WIKI.ADD_TO_READERS (in _cluster_name varchar, in _login varchar)
{
  WV.WIKI.GRANT_CLUSTER_ROLE (_cluster_name || 'Readers', _login);
}
;

create procedure WV.WIKI.ADD_TO_WRITERS (in _cluster_name varchar, in _login varchar)
{
  WV.WIKI.GRANT_CLUSTER_ROLE (_cluster_name || 'Writers', _login);
}
;

create procedure WV.WIKI.GRANT_CLUSTER_ROLE (in _cluster_role varchar, in _login varchar)
{
  if (not exists (select 1 from  SYS_ROLE_GRANTS, SYS_USERS g, SYS_USERS l
	where g.U_NAME = _cluster_role 
	      and l.U_NAME = _login
	      and gi_super = l.U_ID
	      and gi_grant = g.u_id))
    DB.DBA.USER_GRANT_ROLE (_login, _cluster_role);
}
;
	

create procedure WV.WIKI.GET_MAINTOPIC (in _cluster_name varchar)
{
  declare _topic WV.WIKI.TOPICINFO;

  _topic := WV.WIKI.TOPICINFO ();
  _topic.ti_cluster_name := _cluster_name;
  _topic.ti_fill_cluster_by_name();
  _topic.ti_local_name := WV.WIKI.CLUSTERPARAM (_cluster_name, 'index-page', 'WelcomeVisitors');
  _topic.ti_find_id_by_local_name();
  _topic.ti_find_metadata_by_id ();

  if (_topic.ti_id = 0)
    WV.WIKI.APPSIGNAL (11001, 'Main index page does not exist. Please ask administrator to create new one',
      vector () );
  return _topic;
}
;
			  
-- it is nice to see REFBY macro in Category pages			  
create procedure WV.WIKI.ADD_REFBY_MACRO (in _text varchar)
{
  return WV.WIKI.ADD_MACRO (_text, '%REFBY%');
}
;
-- adds macro to topic if needed 			  
create procedure WV.WIKI.ADD_MACRO (in _text varchar, in _macro_call varchar)
{
  declare exit handler for sqlstate '*' {
    return _text;
  }
  ;
  if (not isstring (_text))
    return _text;
  -- check, is there the macro already
  declare _macro_name varchar;
  _macro_name := regexp_substr ('%(\\w*)', _macro_call, 1);
  if (length (_macro_name) = 0)
    return _text;    
  if (xpath_eval ('//*/processing-instruction() [name() = "' || _macro_name || '"]', 
  	xtree_doc ( "WikiV lexer" (_text || '\r\n', 'Main', 'DoesntMatter', 'wiki', null), 2)) is not null)
    return _text;
  return _text || '\n' || _macro_call || '\n';
}
;


-- adds macro to topic
-- if topic name contains '*' then adds to any topic which matches this pattern
-- example:
-- WV.WIKI.ADD_MACRO_TO_TOPIC ('Main', 'Category%', '%REFBY%', 'dav', 'dav');
create procedure WV.WIKI.ADD_MACRO_TO_TOPICS (
  in _cluster varchar,
  in _topics varchar,
  in _macro_call varchar,
  in auth varchar,
  in pwd varchar)
{
  
  if (strchr (_topics, '%') is not null)
    {
      for select LocalName
        from WV.WIKI.TOPIC natural join WV.WIKI.CLUSTERS
	where ClusterName = _cluster
	  and LocalName like _topics
        do {
	  WV.WIKI.ADD_MACRO_TO_TOPICS (_cluster, LocalName, _macro_call, auth, pwd);
	}
    }
  declare _topic WV.WIKI.TOPICINFO;
  _topic := WV.WIKI.TOPICINFO ();
  _topic.ti_cluster_name := _cluster;
  _topic.ti_fill_cluster_by_name();
  _topic.ti_local_name := _topics;
  _topic.ti_find_id_by_local_name();
  if (_topic.ti_id = 0)
    return;
  declare rc,owner integer;
  
  rc := DAV_AUTHENTICATE (_topic.ti_res_id, 'R', '_1_', auth, pwd);
  if (rc < 0)
    signal ('WV003', auth || ' has not enough credentials to write in ' || _topic.ti_local_name);
  owner := (select U_ID from DB.DBA.SYS_USERS where U_NAME = auth);
  _topic.ti_find_metadata_by_id ();
  declare _new_content varchar;
  _new_content := WV.WIKI.ADD_MACRO (_topic.ti_text, _macro_call);
  WV.WIKI.UPLOADPAGE (_topic.ti_col_id, _topics || '.txt', _new_content, owner, 0, auth);
--  DB.DBA.DAV_CHECKIN_INT (DB.DBA.DAV_SEARCH_PATH (_topic.ti_col_id, 'C') ||  _topics || '.txt', null, null, 0);
}
;

create function WV.WIKI.GETMAINTOPIC_NAME (in _cluster varchar)
{
  return WV.WIKI.CLUSTERPARAM (_cluster, 'index-page', 'WelcomeVisitors');
}
;

grant execute on WV.WIKI.GETMAINTOPIC_NAME to public
;

xpf_extension ('http://www.openlinksw.com/Virtuoso/WikiV/:GetMainTopicName', 'WV.WIKI.GETMAINTOPIC_NAME')
;


create procedure WV.WIKI.CHANGE_WORD_IN_CLUSTER (in _cluster varchar,
  in _word varchar,
  in _new_word varchar,
  in _auth varchar,
  out _topics any)
{
  declare _topic WV.WIKI.TOPICINFO;
  _topic := WV.WIKI.TOPICINFO();
  _topic.ti_cluster_name := _cluster;
  _topic.ti_fill_cluster_by_name();
  _topic.ti_local_name := _word;
  _topic.ti_find_id_by_local_name();
  if (_topic.ti_id = 0)
    return 0;
  _topic.ti_find_metadata_by_id();
  --dbg_obj_princ ('next: ', _topic.ti_local_name, _auth);
  
  _topics := vector ();
  declare cnt integer;
  cnt := 0;
  for select OrigId from WV.WIKI.LINK
  	where DestId = _topic.ti_id
  do { 
    --dbg_obj_princ ('next: ', OrigId);
    declare _r_topic WV.WIKI.TOPICINFO;
    declare _owner integer;
    _r_topic := WV.WIKI.TOPICINFO();
    _r_topic.ti_id := OrigId;
    _r_topic.ti_find_metadata_by_id();
    _owner := (select RES_OWNER from WS.WS.SYS_DAV_RES where RES_ID = _r_topic.ti_res_id);
    declare _new_res_content varchar;
    _new_res_content := WV.WIKI.CHANGE_LOCALNAME (_r_topic, _topic, _new_word);
    if (_new_res_content is not null)
    {
      --dbg_obj_princ ('updating ', _r_topic.ti_local_name);
      WV.WIKI.UPLOADPAGE (_r_topic.ti_col_id, _r_topic.ti_local_name || '.txt', _new_res_content,
      	_owner, 0, _auth);
--      DB.DBA.DAV_CHECKIN_INT (_r_topic.ti_full_path(), null, null, 0);
      _r_topic.ti_compile_page();
      cnt := cnt + 1;
      _topics := vector_concat (_topics, vector (_r_topic.ti_local_name));
    }

  }
  return cnt;
}
;

create function WV.WIKI.CHANGE_LOCALNAME (
  in _r_topic WV.WIKI.TOPICINFO,
  in _orig_topic WV.WIKI.TOPICINFO,
  in _new_word varchar)
{
  --dbg_obj_princ ('WV.WIKI.CHANGE_LOCALNAME ', _r_topic.ti_local_name, _orig_topic.ti_local_name, _new_word);
  declare _new_content varchar;
  declare _content varchar;
  
  _content := cast (_r_topic.ti_text as varchar);

  -- if topics belong to one cluster
  if (_r_topic.ti_cluster_name = _orig_topic.ti_cluster_name)
    {
    -- topic can contain non qualified word
    _content := WV.WIKI.REPLACE_WORD (_content, _orig_topic.ti_local_name, _new_word);
    }
  -- and replace fully qualified words 
  _new_word := WV.WIKI.QUALIFY_WORD (_orig_topic.ti_cluster_name, _new_word);
  _content := WV.WIKI.REPLACE_WORD (_content, _orig_topic.ti_cluster_name || '.' || _orig_topic.ti_local_name, _new_word);

  if (_content <> cast (_r_topic.ti_text as varchar))
    return _content;

  return NULL;
}
;

create function WV.WIKI.QUALIFY_WORD (
  in _def_cluster varchar,
  in _name varchar)
{
  if (strchr(_name, '.') is null)
    return _def_cluster || '.' || _name;
  else
    return _name;
}
;

create function WV.WIKI.REPLACE_WORD (
  in _text varchar,
  in _from varchar,
  in _to varchar)
{
  declare _content, _pattern varchar;
  declare _encoded_from varchar;
  _encoded_from := replace (_from, '.', '\\.');
  _pattern := '^(' || _encoded_from || ')[^0-9A-Za-z]|[^A-Za-z0-9\\.](' || _encoded_from || ')[^0-9A-Za-z]';
  --dbg_obj_print (_pattern);

  declare ss any;
  ss := string_output ();

  declare idx integer;
  idx := 0;
  while (idx < length (_text))
    {
      declare regs any;
      regs := regexp_parse (_pattern, _text, idx);
      --dbg_obj_print (regs);
      if (regs is not null)
        {	  
	  http (subseq (_text, idx, regs[0]), ss);
	  idx := regs[1];
	  declare _matched_str varchar;
	  _matched_str := subseq (_text, regs[0], regs[1]);
	  http (replace (_matched_str, _from, _to), ss);	  
	}
      else
        {
	  http (subseq (_text, idx), ss);
	  idx := length (_text);
	}
    }
  return string_output_string (ss);
}
;


create function WV.WIKI.CATEGORY_TO_TAG (in _cat varchar)
{
  if (_cat like 'Category%')
    return lcase (subseq (_cat, 8));
  return NULL;
}
;

-- looks for category in topics first
-- if failed, creates new category
create function WV.WIKI.TAG_TO_CATEGORY (in _tag varchar, in _cluster_id integer)
{
  declare _cat_name varchar;
  _cat_name := lcase ('Category' || _tag);
  for select LocalName from WV.WIKI.TOPIC
  	where
	  ClusterId = _cluster_id
	  and LocalName like 'Category%'
	  and lcase (LocalName) = _cat_name
  do {
    return LocalName;
  }
  return 'Category' || WV.WIKI.CAPITALIZE (_tag);
}
;


create function WV.WIKI.CAPITALIZE (in _tag varchar)
{  
  return ucase (subseq (_tag, 0, 1)) || lcase (subseq (_tag, 1));
}
;

create function WV.WIKI.AUTH_BY_LDAP (in _cluster any, in _user varchar, in _pwd varchar)
{
   --dbg_obj_princ ('AUTH_BY_LDAP ', _cluster, ' ', _user, ' ', _pwd);
  declare _address, _base, _bind, _uid_field, _port  varchar;  
  _address := WV.WIKI.CLUSTERPARAM (_cluster, 'ldap_address', '');
  _base := WV.WIKI.CLUSTERPARAM (_cluster, 'ldap_base', '');
  _bind := WV.WIKI.CLUSTERPARAM (_cluster, 'ldap_bind', '');
  _uid_field := WV.WIKI.CLUSTERPARAM (_cluster, 'ldap_uid', '');
  _port := WV.WIKI.CLUSTERPARAM (_cluster, 'ldap_port', '389');

  whenever sqlstate '28000' goto auth_validation_fail;
  connection_set ('LDAP_VERSION', WV.WIKI.CLUSTERPARAM (_cluster, 'ldap_version', 2));
  LDAP_SEARCH('ldap://' || _address || ':' || _port,
  	0, 
	_base, 
	sprintf ('(%s=%s)', _uid_field, _user),
	sprintf('%s=%s, %s', _uid_field, _user, _bind),
	_pwd);
   --dbg_obj_print ('success');
  return 1;
auth_validation_fail:
  return 0;
}
;
	 
create procedure WV.WIKI.INC_COMMITCOUNTER (in _uid integer)
{
  declare _cnt integer;
  whenever not found goto ins;
  declare cr cursor for select Cnt from WV.WIKI.COMMITCOUNTER where AuthorId = _uid for update;
  open cr;
  fetch cr into _cnt;
  update WV.WIKI.COMMITCOUNTER set Cnt = _cnt + 1
  	where current of cr;
  return;
ins:
  insert into WV.WIKI.COMMITCOUNTER (AuthorId, Cnt)
  	values (_uid, 1);
}
;
      
create procedure WV.WIKI.SYSINFO_PRED ()
{
  return 'DE3A857A5FFB11DA923AF0924C194AED';
}
;

create procedure WV.WIKI.XHTML_PREFIX ()
{
  return 'D001AF62737B11DA9C6DDEE3AE8897E7';
}
;


create function WV.WIKI.ENCODE_FT (in _term varchar, in _other_text varchar, in encode_ft int := 1)
{
  if (not encode_ft)
    return _term || '\n' ||_other_text;
  else if (_other_text is not null)
    return '"' || _term || '" AND ' || _other_text;
  else 
    return '"' || _term || '"';
}
;

create procedure WV.WIKI.ADD_SYSINFO (in _text varchar, in _predicate varchar, in _value varchar, in encode_ft int := 0)
{
  declare _pred varchar;
  _pred := WV.WIKI.SYSINFO_PRED() || ' ' || _predicate || ' ' || _value;
  if (strcasestr (_text, _pred) is null)
    return WV.WIKI.ENCODE_FT (_pred, _text, encode_ft);
  else
    return _text;
}
;

create procedure WV.WIKI.ADD_SYSINFO_VECT (in _text varchar,
	in _info any, in encode_ft int := 0)
{
  --dbg_obj_princ ('WV.WIKI.ADD_SYSINFO_VECT ', _text, ' ', _info);
  declare i integer;
  declare _sysinfo_text varchar;
  _sysinfo_text := null;
  for (i:=0; i<(length (_info)/2) ;i:=i+1)
    _sysinfo_text :=  WV.WIKI.ADD_SYSINFO (_sysinfo_text, _info[2*i], _info[2*i+1], encode_ft);
  if (_text is not null and encode_ft)
    return _sysinfo_text || ' AND ' || _text;
  return _sysinfo_text || _text;
}
;

create function WV.WIKI.DELETE_SYSINFO_FOR (in _text varchar, in _pred varchar := NULL)
{
  declare _lines any;
  declare _res any;
  declare _prefix varchar;
  declare i integer;
  if (not isstring(_text))
    _text := cast (_text as varchar);
  if (_pred is not null)
    _prefix := WV.WIKI.SYSINFO_PRED() || ' ' || _pred || ' %';
  else
    _prefix := WV.WIKI.SYSINFO_PRED() || ' %';
  
  _lines := split_and_decode (_text, 0, '\0\0\n');
  _res := string_output();
  for (i:=0; i<length(_lines); i:=i+1) {
    if (_lines[i]  not like _prefix) {
	    http (_lines[i], _res);
	    if (i<>length(_lines)-1)
	  http ('\n', _res);
	}
    }
  return string_output_string (_res);
}
;

create trigger "Wiki_Tagging" after insert on WS.WS.SYS_DAV_TAG referencing new as N
{  
  --dbg_obj_princ ('Wiki_Tagging trigger');
  if (exists (select 3 from WV.WIKI.TOPIC where ResId = N.DT_RES_ID))
    WV.WIKI.UPDATE_TAG_SYSINFO (N.DT_RES_ID, N.DT_TAGS);
}
;

create trigger "Wiki_TaggingUpdate" after update on WS.WS.SYS_DAV_TAG referencing new as N
{
  --dbg_obj_princ ('Wiki_TaggingUpdate trigger');
  if (exists (select 1 from WV.WIKI.TOPIC where ResId = N.DT_RES_ID))
    WV.WIKI.UPDATE_TAG_SYSINFO (N.DT_RES_ID, N.DT_TAGS);
}
;

create procedure WV.WIKI.UPDATE_TAG_SYSINFO (in _res_id integer, in _tags varchar)
{
  declare vtb any;
  vtb := vt_batch();
  vt_batch_d_id (vtb, _res_id);
  WS.WS.META_WIKI_HOOK (vtb, _res_id);
  WS.WS.VT_BATCH_PROCESS_WS_WS_SYS_DAV_RES (vtb);
  return;

  --dbg_obj_princ ('WV.WIKI.UPDATE_TAG_SYSINFO: ', _res_id, _tags);
      declare _col_id integer;
      declare _topic_file_name, _full_path varchar;
      declare _content varchar;
      declare _owner integer;
      declare _auth varchar;
      declare _nobody_uid integer;
      declare _all_tags any;

      _all_tags := (select vector_agg (WV.WIKI.ZIP ('tag', split_and_decode (DT_TAGS, 0, '\0\0,')))
      	from WS.WS.SYS_DAV_TAG where DT_RES_ID = _res_id);
      
      select RES_CONTENT, RES_OWNER, RES_COL, RES_NAME, RES_FULL_PATH
      	into _content, _owner, _col_id, _topic_file_name, _full_path from WS.WS.SYS_DAV_RES
	where RES_ID = _res_id;	
      _content := WV.WIKI.DELETE_SYSINFO_FOR (cast (_content as varchar), 'tag');	
            
      _auth := coalesce (connection_get ('vspx_user'), 'WikiGuest');     
       --dbg_obj_princ (_owner, _auth, _col_id, _topic_file_name, WV.WIKI.ADD_SYSINFO_VECT (_content, WV.WIKI.FLATTEN (_all_tags)));
      declare res integer;
      connection_set ('oWiki trigger', 1);

      declare _owner_login varchar;
      _owner_login := (select U_NAME from DB.DBA.SYS_USERS where U_ID = _owner);
      WV.WIKI.GETLOCK (_full_path, _owner_login);
      --dbg_obj_princ ('lock: ', DAV_PERROR (res));
      res := WV.WIKI.UPLOADPAGE (_col_id, _topic_file_name, 
      	WV.WIKI.ADD_SYSINFO_VECT (_content, 
		WV.WIKI.FLATTEN (_all_tags)),
      	 _owner_login, 0, _auth);
--      DAV_CHECKIN_INT (_full_path, null, null, 0);
      WV.WIKI.RELEASELOCK (_full_path, _owner_login);
      connection_set ('oWiki trigger', NULL);
      --dbg_obj_princ ('upload: ', DAV_PERROR (res));
}
;


create procedure WV.WIKI.SET_AUTOVERSION()
{
  for (select ColId from WV.WIKI.CLUSTERS, WS.WS.SYS_DAV_COL where COL_ID = ColId and COL_AUTO_VERSIONING is not null and COL_AUTO_VERSIONING <> 'A') do
    {
      declare _auth, _pwd varchar;

      WV.WIKI.GETDAVAUTH (_auth, _pwd);
    DAV_SET_VERSIONING_CONTROL (DAV_SEARCH_PATH(ColId, 'C'), NULL, 'A', _auth, _pwd);
    }
}
;


create procedure WV.WIKI.STALE (in _path varchar)
{
  xslt_stale (_path);
}
;

create procedure WV.WIKI.STALE_ALL_XSLTS()
{
  declare _prefix varchar;

  _prefix := 'virt://WS.WS.SYS_DAV_RES.RES_FULL_PATH.RES_CONTENT:/DAV/VAD/wiki/Root/';
  for (select COL_NAME from WS.WS.SYS_DAV_COL where COL_PARENT = DB.DBA.DAV_SEARCH_ID ('/DAV/VAD/wiki/Root/Skins/', 'C')) do
     {
       WV.WIKI.STALE (_prefix || 'Skins/' || COL_NAME || '/PostProcess.xslt');
     }
  for (select RES_NAME from WS.WS.SYS_DAV_RES where RES_COL = DB.DBA.DAV_SEARCH_ID ('/DAV/VAD/wiki/Root/', 'C') and RES_NAME like '%.xsl%') do
     {
       WV.WIKI.STALE (_prefix || RES_NAME);
     }
}
;


create trigger "Wiki_TopicDelete" before delete on WV.WIKI.TOPIC referencing old as O
{
  delete from WV.WIKI.COMMENT where C_TOPIC_ID = O.TopicId;
}
;

create procedure WV.WIKI.ADD_USER (in user_name varchar, in cluster_name varchar)
{
  declare membership_type, uid integer;
  membership_type := 1;
  uid := (select U_ID from DB.DBA.SYS_USERS where U_NAME = user_name);
  if (exists (select * from WV.WIKI.CLUSTERS where ClusterName = cluster_name))
    {
      insert into WA_MEMBER (WAM_USER, WAM_INST, WAM_MEMBER_TYPE, WAM_STATUS)
	         values (uid, cluster_name, membership_type, 1);
      commit work;
      -- needed to launch trigger
    update WA_MEMBER
       set WAM_STATUS = 1
        where WAM_USER = uid
	  and WAM_INST = cluster_name
	  and WAM_MEMBER_TYPE = membership_type;
    }
}
;

create procedure WV.WIKI.DROP_ALL_MEMBERS ()
{
  for (select WAI_NAME from DB.DBA.WA_INSTANCE where WAI_TYPE_NAME = 'oWiki') do
  {
    delete from DB.DBA.WA_MEMBER where WAM_INST = WAI_NAME;
  }
}
;
   
create procedure WV.WIKI.USER_WIKI_NAME(in user_name varchar)
{
  return cast (WV.WIKI.CONVERTTITLETOWIKIWORD( replace (user_name, '.', ' ')) as varchar);
}
;

create procedure WV.WIKI.USER_WIKI_NAME_2(in user_id integer)
{
  return cast (WV.WIKI.CONVERTTITLETOWIKIWORD( (select USERNAME from WV.WIKI.USERS where USERID = user_id) ) as varchar);
}
;

create procedure WV.WIKI.USER_WIKI_NAME_X (in _uid any)
{
  if (isstring (_uid))
    return 'Main.' || WV.WIKI.USER_WIKI_NAME ((select USERNAME from WV.WIKI.USERS, DB.DBA.SYS_USERS where U_ID = USERID and U_NAME =_uid));
  else if (isinteger (_uid))
    return 'Main.' || WV.WIKI.USER_WIKI_NAME_2 (_uid);
  else
    return 'Main.Unknown';
}
;

create procedure WV.WIKI.TEMPLATE_TOPIC(in template_name varchar)
{
  declare _topic_name varchar;
  _topic_name := WV.WIKI.CONVERTTITLETOWIKIWORD ('Template ' || template_name);
  declare _topic WV.WIKI.TOPICINFO;
  _topic := WV.WIKI.TOPICINFO ();
  _topic.ti_default_cluster := 'Main';
  _topic.ti_raw_title := _topic_name;
  _topic.ti_find_id_by_raw_title ();
  if (_topic.ti_id <> 0)
    _topic.ti_find_metadata_by_id ();

  return _topic;
}
;

create procedure WV.WIKI.REPLACE_BULK (in _text varchar, in _repls any)
{
  declare idx integer;
  for (idx:=0; idx<length(_repls); idx:=idx+2)
    {
      _text := replace (_text, _repls[idx], coalesce (_repls[idx+1], ''));
    }
  return _text;
}
;

create procedure WV.WIKI.CREATE_HOME_PAGE_TOPIC (
  inout _template WV.WIKI.TOPICINFO,
  	in home_page varchar,
  in user_id integer)
{
  for select U_NAME,USERNAME, U_E_MAIL, coalesce (U_FULL_NAME, U_NAME) as _full_name from DB.DBA.SYS_USERS, WV.WIKI.USERS where U_ID = user_id and U_ID = USERID do
  {
    declare _text varchar;
    _text := WV.WIKI.REPLACE_BULK (cast (_template.ti_text as varchar), 
	vector ('{SYSUSER}', U_NAME, '{USER}', USERNAME, '{FULLNAME}', _full_name, '{EMAIL}', U_E_MAIL, '{BASEURL}', DB.DBA.WA_LINK (1, '/dataspace')));
    WV.WIKI.UPLOADPAGE (_template.ti_col_id, home_page || '.txt' , _text, U_NAME);
    return;
  }
}
;

create procedure WV.WIKI.CREATE_USER_PAGE(in user_id varchar, in user_name varchar)
{
  declare home_page varchar;
  home_page := WV.WIKI.USER_WIKI_NAME (user_name);
  if (exists (select 1 from WV.WIKI.TOPIC natural join WV.WIKI.CLUSTERS
	where LocalName = home_page and ClusterName = 'Main'))
     return ;
  declare _template WV.WIKI.TOPICINFO;
  _template := WV.WIKI.TEMPLATE_TOPIC ('user');
  if (_template.ti_id = 0)
        WV.WIKI.APPSIGNAL (11001, 'Can not get template for creating home page', vector());
  _template.ti_text := cast (_template.ti_text as varchar);
  
  declare _text varchar;
  _text := WV.WIKI.CREATE_HOME_PAGE_TOPIC (_template, home_page, user_id);
}
;

create procedure WV.WIKI.CREATE_ALL_USERS_PAGES ()
{
  for select USERID, USERNAME from WV.WIKI.USERS do
    {
      WV.WIKI.CREATE_USER_PAGE(USERID, USERNAME);
    }
}
;


create trigger WIKI_USERS_I after insert on WV.WIKI.USERS order 100 referencing new as N
{
   WV.WIKI.CREATE_USER_PAGE (N.USERID, N.USERNAME);
}
;

create trigger WIKI_USERS_U after update on WV.WIKI.USERS order 100 referencing old as O, new as N
{
  if (N.USERNAME = O.USERNAME)
    return;
  declare _topic WV.WIKI.TOPICINFO;
  _topic := WV.WIKI.TOPICINFO();
  _topic.ti_raw_title := WV.WIKI.USER_WIKI_NAME(O.USERNAME);
  _topic.ti_default_cluster := 'Main';
  _topic.ti_find_id_by_raw_title();
  if (_topic.ti_id <> 0)
    {
      _topic.ti_fill_cluster_by_id();
      _topic.ti_find_metadata_by_id();
      WV.WIKI.RENAMETOPIC2 (_topic, N.USERNAME, _topic.ti_cluster_id, WV.WIKI.USER_WIKI_NAME (N.USERNAME));
    }
}
;

create trigger SYS_USERS_WIKI_USERS_U after update on DB.DBA.SYS_USERS order 100 referencing old as O, new as N
{
  if (N.U_FULL_NAME is null)
  {
    update WV.WIKI.USERS
         set USERNAME = WV.WIKI.USER_WIKI_NAME(N.U_NAME)
       where USERID = N.U_ID;
  }
  else if (O.U_FULL_NAME <> N.U_FULL_NAME)
  {
      update WV.WIKI.USERS 
	set USERNAME = WV.WIKI.USER_WIKI_NAME(N.U_FULL_NAME) 
	where USERID = N.U_ID;
    }
}
;

create procedure
WS.WS.META_WIKI_HOOK (inout vtb any, inout r_id any)
{
  declare exit handler for sqlstate '*' {
    return;
  };

  declare _cluster varchar;
  _cluster := (select ClusterName from WV.WIKI.TOPIC natural join WV.WIKI.CLUSTERS 
	where ResId = r_id);
  if (_cluster is null)
    _cluster := (select ClusterName from WV.WIKI.CLUSTERS where ClusterId = connection_get ('oWiki_cluster_id'));
  if (_cluster is not null)
    {
    foreach (varchar tag in (select split_and_decode (DT_TAGS, 0, '\0\0,') from WS.WS.SYS_DAV_TAG where DT_RES_ID = r_id)) do
        {
          vt_batch_feed (vtb, WV.WIKI.SYSINFO_PRED () || ' tag ' || tag, 0);
        }
      vt_batch_feed (vtb, WV.WIKI.SYSINFO_PRED () || ' cluster ', 0);
      vt_batch_feed (vtb, WV.WIKI.SYSINFO_PRED () || ' cluster ' || _cluster, 0);
    }
}
;

create procedure WV.WIKI.UPGRADE__UPDATE_AUTHOR_ID()
{
  for select ResId as _res_id from WV.WIKI.TOPIC where AuthorId is null do
  {
    declare _max_ver integer;
    _max_ver := (select max(RV_ID) from WS.WS.SYS_DAV_RES_VERSION where RV_RES_ID = _res_id);
    if (_max_ver is not null)
      {
      update WV.WIKI.TOPIC set AuthorId = (select U_ID from DB.DBA.SYS_USERS, WS.WS.SYS_DAV_RES_VERSION where RV_ID = _max_ver and RV_WHO = U_NAME and RV_RES_ID = _res_id) where ResId = _res_id;
      }
  }
}
;

create procedure WV.WIKI.SANITY_CHECK()
{
  set triggers off;
  for select DP_HOST as _host, DP_PATTERN as _pattern from WV.WIKI.DOMAIN_PATTERN_1 d where 
  	exists (select 1 from WV.WIKI.DOMAIN_PATTERN_1 d2 
		  where d2.DP_PATTERN = replace (d.DP_PATTERN, '%', 'main') 
		  	and d.DP_PATTERN <> d2.DP_PATTERN 
			and d.DP_HOST = d2.DP_HOST) 
  do {
    delete from WV.WIKI.DOMAIN_PATTERN_1 where DP_PATTERN = _pattern and DP_HOST = _host;
  }
  for select WAI_NAME  as _name from DB.DBA.WA_INSTANCE where WAI_TYPE_NAME = 'oWiki' and not exists (select * from WV.WIKI.CLUSTERS where CLUSTERNAME = WAI_NAME) 
  do 
     {
        delete from DB.DBA.WA_INSTANCE where WAI_NAME = _name and WAI_TYPE_NAME = 'oWiki';
     }

  declare wiki_guest_id integer;
  wiki_guest_id := coalesce ((select U_ID from SYS_USERS where U_NAME = 'WikiGuest'),0);

  for select WAI_NAME  as _name from DB.DBA.WA_INSTANCE where WAI_TYPE_NAME = 'oWiki' and WAI_IS_PUBLIC < 1
  do
  {
    if (exists (select 1 from  SYS_ROLE_GRANTS, SYS_USERS g
                         where g.U_NAME = _name || 'Readers' and gi_super = wiki_guest_id and gi_grant = g.u_id))
	    DB.DBA.USER_REVOKE_ROLE ('WikiGuest', _name || 'Readers');
  }
  for select WAM_INST as _name from DB.DBA.WA_MEMBER 
    where WAM_APP_TYPE = 'oWiki' 
    and not exists (select 1 from WV.WIKI.CLUSTERS where CLUSTERNAME = WAM_INST)
  do 
    {
       delete from DB.DBA.WA_MEMBER where WAM_INST = _name and WAM_APP_TYPE = 'oWiki';
    }
  if (1=1)
  {
    declare exit handler for sqlstate '*' {
		-- dbg_obj_princ (__SQL_STATE, __SQL_MESSAGE);
		goto _next3;
	  };

    for select WAI_NAME  as _cluster_name from DB.DBA.WA_INSTANCE where WAI_TYPE_NAME = 'oWiki'
    do
    {
      for select gi_super as _user from  SYS_ROLE_GRANTS, SYS_USERS g
                         where g.U_NAME = _cluster_name || 'Readers' and gi_grant = g.u_id
      do
      {
        if ((_user <> wiki_guest_id) and
            (not exists (select 1 from DB.DBA.WA_MEMBER
                                 where WAM_INST = _cluster_name and WAM_USER = _user and WAM_STATUS = 2 and WAM_MEMBER_TYPE = 3)) )
        {
          declare _user_name varchar;
          _user_name := (select U_NAME from DB.DBA.SYS_USERS where U_ID = _user);
          DB.DBA.USER_REVOKE_ROLE (_user_name, _cluster_name || 'Readers');
        }
      }
      for select gi_super as _user from  SYS_ROLE_GRANTS, SYS_USERS g
                         where g.U_NAME = _cluster_name || 'Writers' and gi_grant = g.u_id
      do
      {
        if (not exists (select 1 from DB.DBA.WA_MEMBER
                                 where WAM_INST = _cluster_name and WAM_USER = _user and WAM_STATUS <= 2 and WAM_MEMBER_TYPE in (1,2)))
        {
          declare _user_name varchar;
          _user_name := (select U_NAME from DB.DBA.SYS_USERS where U_ID = _user);
          DB.DBA.USER_REVOKE_ROLE (_user_name, _cluster_name || 'Writers');
        }
      }
      for select WAM_USER as _user, WAM_STATUS as _status, WAM_MEMBER_TYPE as _type
            from DB.DBA.WA_MEMBER where WAM_APP_TYPE = 'oWiki' and WAM_INST = _cluster_name
      do
      {
        declare _role, _role_revoke varchar;
        if (_type in (1,2) and _status <= 2) -- author
        {
          _role := _cluster_name || 'Writers';
          _role_revoke := _cluster_name || 'Readers';
        }
        else if (_type = 3 and _status = 2) -- reader
        {
          _role := _cluster_name || 'Readers';
          _role_revoke := _cluster_name || 'Writers';
        }
        else
          goto _next2;

        declare _user_name varchar;
        _user_name := (select U_NAME from DB.DBA.SYS_USERS where U_ID = _user);

        if (not exists (select 1 from  SYS_ROLE_GRANTS, SYS_USERS g
                         where g.U_NAME = _role and gi_super = _user and gi_grant = g.u_id))
        {
          DB.DBA.USER_GRANT_ROLE (_user_name, _role);
        }
        if (exists (select 1 from  SYS_ROLE_GRANTS, SYS_USERS g
                         where g.U_NAME = _role_revoke and gi_super = _user and gi_grant = g.u_id))
        {
          DB.DBA.USER_REVOKE_ROLE (_user_name, _role_revoke);
        }
        _next2:;
      }
    }
  }
  _next3:;
  set triggers on;
  declare vtb any;
  for select RES_ID, RES_FULL_PATH from WS.WS.SYS_DAV_RES 
    where contains (RES_CONTENT, '"DE3A857A5FFB11DA923AF0924C194AED cluster "') 
    and not exists (select 1 from WV.WIKI.TOPIC where RESID = RES_ID)
  do {
    vtb := vt_batch ();
    vt_batch_d_id (vtb, RES_ID);
    vt_batch_feed (vtb, '"DE3A857A5FFB11DA923AF0924C194AED cluster "', 1);
    vt_batch_feed (vtb, 'DE3A857A5FFB11DA923AF0924C194AED', 1);
    WS.WS.VT_BATCH_PROCESS_WS_WS_SYS_DAV_RES (vtb);
  }
  for select WAI_NAME from DB.DBA.WA_INSTANCE
    where WAI_TYPE_NAME = 'oWiki'
    and WAI_IS_PUBLIC = 1
  do {
    WV.WIKI.ENSURE_IS_PUBLIC (WAI_NAME);
  }
  for select CLUSTERID from WV.WIKI.CLUSTERS where not exists (select top 1 1 from DB.DBA.WA_INSTANCE where WAI_NAME = CLUSTERNAME AND WAI_TYPE_NAME = 'oWiki') do
    {
      WV..DROPCLUSTERCONTENT (CLUSTERID);
      WV..DELETECLUSTER (CLUSTERID);
    }
  delete from WV.WIKI.TOPIC t where not exists (select top 1 1 from WV.WIKI.CLUSTERS c where c.CLUSTERID = t.CLUSTERID);
  WV.WIKI.UPGRADE__UPDATE_AUTHOR_ID();
}
;


create procedure WV.WIKI.ENSURE_IS_PUBLIC (in _cluster varchar)
{
  whenever sqlstate '*' goto fin;
  DB.DBA.USER_GRANT_ROLE ('WikiGuest', _cluster || 'Readers');
fin:
  ;
}
;

create function WV.WIKI.RESOURCE_CANONICAL (in res_id integer)
{
  return DB.DBA.DAV_SEARCH_PATH (res_id, 'R');
}
;

create function WV.WIKI.CLUSTER_CANONICAL (in _clustername varchar)
{
  return (select DB.DBA.DAV_SEARCH_PATH (COLID, 'C') from WV.WIKI.CLUSTERS where CLUSTERNAME = _clustername);
}
;

create function WV.WIKI.DELETE_INLINE_MACRO_FUNCS_1 (inout _topic WV.WIKI.TOPICINFO)
{
  for select P_NAME from DB.DBA.SYS_PROCEDURES 
    where P_NAME like WV.WIKI.INLINE_MACRO_NAME (_topic.ti_cluster_name, _topic.ti_local_name, null) do {
    exec ('drop procedure ' || P_NAME);
  }
}
;

create function WV.WIKI.DELETE_INLINE_MACRO_FUNCS (in _topicid integer)
{
  declare _topic WV.WIKI.TOPICINFO;
  _topic := WV.WIKI.TOPICINFO();
  _topic.ti_id := _topicid;
  _topic.ti_find_metadata_by_id ();
  WV.WIKI.DELETE_INLINE_MACRO_FUNCS_1 (_topic);
}
;

create function WV.WIKI.INLINE_MACRO_FUNCTION (in _name varchar, in _exec varchar)
{
  return 'create function ' || _name || ' (in params any) {
     declare ss123456789 any;
     ss123456789 := string_output();
     connection_set (''Wiki macro output'', ss123456789); ' ||
     _exec || ' return string_output_string(ss123456789); } ';
}
;

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

create procedure WA_SEARCH_DAV_OR_WIKI_GET_EXCERPT_HTML (
  in current_user_id integer,
  in RES_ID integer,
	 in _WORDS_VECTOR any,
	 in RES_CONTENT any,
	 in RES_FULL_PATH varchar,
  in RES_OWNER integer,
  in RES_COL integer)
{
  if (exists (select 1 from WV.WIKI.CLUSTERS where ColId = RES_COL))
    return WA_SEARCH_WIKI_GET_EXCERPT_HTML (current_user_id, RES_ID, _WORDS_VECTOR, RES_CONTENT, RES_FULL_PATH, RES_OWNER);
  else
    return WA_SEARCH_DAV_GET_EXCERPT_HTML (current_user_id, RES_ID, _WORDS_VECTOR, RES_CONTENT, RES_FULL_PATH);
}
;

create procedure WV.WIKI.COMPILE_ALL ()
{
  for select TOPICID from WV.WIKI.TOPIC do {
    declare _topic WV.WIKI.TOPICINFO;
    _topic := WV.WIKI.TOPICINFO();
    _topic.ti_id := TOPICID;
    _topic.ti_find_metadata_by_id();
    _topic.ti_compile_page();
  }
}
;

create procedure WV.WIKI.CANONICAL_PATH(in _path varchar, in _collectionp int := 0)
{
  declare _parts, _recon_path any;
  _parts := split_and_decode (_path, 0, '\0\0/');
  if (not length (_parts))
    return _path;
  vectorbld_init(_recon_path);
  if (_path[0] = ascii('/'))
    vectorbld_acc (_recon_path, '');
  declare _st integer;
  foreach (varchar part in _parts) do {
    if (part <> '') 
      { 
        vectorbld_acc (_recon_path, part); 
      }
  }
  vectorbld_final (_recon_path);
  declare _last_part varchar;
  if (length(_parts) and _parts[length(_parts)-1] = '')
    _last_part := '/';
  else
    _last_part := '';
  
  if (_collectionp = 3) -- path is collection, always remove last /
   {
      if (_path = '/' or _path = '')
        return '/';
      return WV.WIKI.STRJOIN('/', _recon_path); 
   }
  else if (_collectionp = 2)
    {
      if (_last_part <> '/')
	return WV.WIKI.STRJOIN ('/', subseq (_recon_path, 0, length (_recon_path)-1)) || '/';
      else
        return WV.WIKI.STRJOIN('/', _recon_path) || '/'; 
    }
  else if (_collectionp = 1)
    {
      return WV.WIKI.STRJOIN('/', _recon_path) || '/'; 
    } 
  return WV.WIKI.STRJOIN('/', _recon_path) || _last_part;
}
;

create procedure WV.WIKI.MERGE_PATH(in resource varchar, in _path varchar)
{
  return WV.WIKI.CANONICAL_PATH (_path, 2) || resource;
}
;
create procedure WV.WIKI.MERGE_HTTP_PATH(in resource varchar, in _path varchar)
{
  return replace (WV.WIKI.MERGE_PATH (resource, _path), 'http:/', 'http://');
}
;

create procedure WV.WIKI.PUT_NEW_FILES(in _cname varchar, in _overwrite int:=0, in _pattern varchar := '%')
{
  declare _main integer;
  declare _owner varchar;
  _main := (select COLID from WV.WIKI.CLUSTERS where CLUSTERNAME = _cname);
  _owner := WV.WIKI.CLUSTERPARAM (_cname, 'creator', 'dav');
  for select RES_NAME from WS.WS.SYS_DAV_RES where RES_FULL_PATH like '/DAV/VAD/wiki/' || _cname || '/' || _pattern || '.txt' do 
    {
--      result (RES_NAME);
      WV.WIKI.CREATEINITIALPAGE (RES_NAME, _main, (select U_ID from DB.DBA.SYS_USERS where U_NAME = _owner), _cname, _overwrite);
    }
}
;

use WV
;

create function MAX_LOG_ENTRIES()
{
  return 10;
}
;

create procedure ADD_HIST_ENTRY (in _cluster varchar, 
	in _topic varchar, 
	in _op varchar(1),
	in _ver varchar)
{
  declare idx integer;
  idx := 0;
  -- maximum 10 entries allowed.
  for select H_ID as _id from HIST where H_CLUSTER = _cluster 
     order by H_DT desc do {
    idx := idx + 1;
    if (idx >= MAX_LOG_ENTRIES()) {
         delete from HIST where H_ID = _id;
    }
  }
  if (_cluster is not null and _topic is not null)
    {
  insert into HIST (H_CLUSTER, H_TOPIC, H_OP, H_VER, H_DT, H_WHO, H_IS_PUBLIC) 
  	values (_cluster, _topic, _op, _ver, now(), coalesce(connection_get('WikiUser'), '{system bot}'), (select WAI_IS_PUBLIC from DB.DBA.WA_INSTANCE where WAI_NAME = _cluster));
}
}
;

create procedure HIST_XML()
{
  return (select XMLELEMENT('history',
  	XMLAGG(
		XMLELEMENT('entry',
			XMLATTRIBUTES(H_OP as "operation", WV.WIKI.DATEFORMAT(H_DT) as "dt", H_VER as "version", H_CLUSTER as "cluster", H_TOPIC as "topic"))))
	from (select top (MAX_LOG_ENTRIES()) * from HIST order by H_DT desc) a);
}
;
create procedure HIST_ENTRIES(in _cluster varchar := null)
{
  declare vect_res any;
  vectorbld_init(vect_res);
  
  if (_cluster is null) {
    for select top (MAX_LOG_ENTRIES()) H_OP, H_VER, H_CLUSTER, H_TOPIC, H_WHO, H_DT
  from HIST, CLUSTERS
  where H_CLUSTER = ClusterName and H_IS_PUBLIC = 1
	order by H_DT desc do {
     vectorbld_acc (vect_res, vector (
      H_CLUSTER
      ,H_TOPIC
      ,H_WHO
      ,H_VER
      ,H_OP
      ,H_DT
      ) );
    }
  } else {
    for select H_OP, H_VER, H_CLUSTER, H_TOPIC, H_WHO, H_DT
  from HIST, CLUSTERS where H_CLUSTER = _cluster and H_CLUSTER = ClusterName order by H_DT desc do {
     vectorbld_acc (vect_res, vector (
      H_CLUSTER
      ,H_TOPIC
      ,H_WHO
      ,H_VER
      ,H_OP
      ,H_DT
      ) );
    }
  }
  vectorbld_final(vect_res);
  return vect_res;
}
;

create procedure CLUSTER_HIST_XML(in _cluster varchar)
{
  if (_cluster is not null)
    return (select XMLELEMENT('history',
  	XMLAGG(
		XMLELEMENT('entry',
			XMLATTRIBUTES(H_OP as "operation", WV.WIKI.DATEFORMAT(H_DT) as "dt", H_VER as "version", H_CLUSTER as "cluster", H_TOPIC as "topic"))))
	from wv..HIST where H_CLUSTER = _cluster order by H_DT desc); 
  else
    return (select XMLELEMENT('history',
  	XMLAGG(
		XMLELEMENT('entry',
			XMLATTRIBUTES(H_OP as "operation", WV.WIKI.DATEFORMAT(H_DT) as "dt", H_VER as "version", H_CLUSTER as "cluster", H_TOPIC as "topic"))))
	from (select top (WV..MAX_LOG_ENTRIES()) * from wv..HIST order by H_DT desc) a );
}
;

create function RSS_SUBJECT(in _op varchar, in _replacements any)
{
  if (_op = 'A') 
  	return WV.WIKI.REPLACE_BULK ('{WHO} attached {VER} to {CLUSTER}.{TOPIC}', _replacements);
  else if (_op = 'a') 
    return WV.WIKI.REPLACE_BULK ('{WHO} deleted attachment {VER} from {CLUSTER}.{TOPIC}', _replacements);
  else if (_op = 'N')
  	return WV.WIKI.REPLACE_BULK ('{WHO} created new article {CLUSTER}.{TOPIC}', _replacements); 
  else if (_op = 'D')
  	return WV.WIKI.REPLACE_BULK ('{WHO} deleted article {CLUSTER}.{TOPIC}', _replacements);
  else if (_op = 'U')
  	return WV.WIKI.REPLACE_BULK ('{WHO} updated article {CLUSTER}.{TOPIC} (now on version {VER}).', _replacements); 
  else 
  	return WV.WIKI.REPLACE_BULK ('{WHO} performed unknown action: ', _replacements) || _op;
}
;
create function RSS_CONTENT(in _op varchar, in _replacements any)
{
  if (_op = 'A') 
  	return WV.WIKI.REPLACE_BULK ('<a href="{ULINK}">{WHO}</a> attached {VER} to <a href="{LINK}">{CLUSTER}.{TOPIC}</a>', _replacements);
  else if (_op = 'a') 
    return WV.WIKI.REPLACE_BULK ('<a href="{ULINK}">{WHO}</a> deleted attachment {VER} from <a href="{LINK}">{CLUSTER}.{TOPIC}</a>', _replacements);
  else if (_op = 'N')
  	return WV.WIKI.REPLACE_BULK ('<a href="{ULINK}">{WHO}</a> created new article <a href="{LINK}">{CLUSTER}.{TOPIC}</a>', _replacements); 
  else if (_op = 'D')
  	return WV.WIKI.REPLACE_BULK ('<a href="{ULINK}">{WHO}</a> deleted article {CLUSTER}.{TOPIC}', _replacements);
  else if (_op = 'U')
  	return WV.WIKI.REPLACE_BULK ('<a href="{ULINK}">{WHO}</a> updated article <a href="{LINK}">{CLUSTER}.{TOPIC}</a> (now on version {VER}). Click to see the <a href="{LINK}?command=diff&rev={PREVVER}">difference</a>', _replacements); 
  else 
  	return WV.WIKI.REPLACE_BULK ('<a href="{ULINK}">{WHO}</a> performed unknown action: ', _replacements) || _op;
}
;

create procedure RSS(in _cluster varchar, in _type varchar)
{
  declare author, author_email varchar;
  author:=WV.WIKI.CLUSTERPARAM( coalesce(_cluster, 'Main'), 'creator');
  author_email:=(select U_E_MAIL from DB.DBA.SYS_USERS where U_NAME = author);
  declare _out any;
  _out := string_output();
  http ('<rss version="2.0" xmlns:openSearch="http://a9.com/-/spec/opensearchrss/1.0/" xmlns:vi="http://www.openlinksw.com/ods/">\r\n<channel>\r\n',_out);
  http ('<title>',_out);
  if (_cluster is null)
    http ('Site Changelog',_out);
  else
    http_value (_cluster || '\'s Changelog', null, _out);
  http ('</title>',_out);
  http ('<link><![CDATA[',_out);
  http ('http://',_out); http(sioc..get_cname(), _out); http_value (sprintf ('/wiki/resources/gems.vsp?type=%U', _type), null, _out);
  if (_cluster <> '')
    http (sprintf ('&cluster=%U', _cluster),_out);
  http ('&test=',_out);
  http (']]></link>',_out);
  http ('<pubDate>',_out);
  http_value (WV.WIKI.DATEFORMAT (now (), 'rfc1123'), null, _out);
  http ('</pubDate>',_out);
  http ('<managingEditor>',_out);
  http_value (charset_recode (author,'UTF-8', '_WIDE_'), null, _out);   
  http_value (sprintf ('<%s>', coalesce (author_email, '')), null, _out);
  http ('</managingEditor>',_out);
  http ('<description>About last changes</description>',_out);

  foreach(any _entry in HIST_ENTRIES(_cluster)) do {
    declare _cluster, _topic, _who,  _op, _ver varchar;
    declare _dt datetime;
    _cluster := _entry[0];
    _topic := _entry[1];
    _who := _entry[2];
    _ver := _entry[3];
    _op := _entry[4];
    _dt := _entry[5];

    declare _ulink varchar;
    if (regexp_match('^[[:alpha:]][[:alnum:]]*', _WHO) is null)
	_ulink := sprintf('http://%s/dataspace/%s', sioc..get_cname(), 'dav');
    else
	_ulink := sprintf('http://%s/dataspace/%s', sioc..get_cname(), _WHO);
    declare _prev_ver varchar;
    if (_OP = 'U')
       _prev_ver := cast ((atoi(regexp_match('[0-9]*\$', _VER)) - 1) as varchar);
    else
       _prev_ver := '0';

    declare _repl any;
    declare _mainp varchar;
    if (exists (select * from WV..DOMAIN_PATTERN_1 where DP_HOST = '%' and DP_PATTERN = '/wiki'))
      _mainp := '';
    else
      _mainp := 'main/';
    _repl := vector (
    	'{CLUSTER}', _CLUSTER
	,'{TOPIC}', _TOPIC
	,'{WHO}', _WHO
	,'{ULINK}', _ulink
	,'{DT}', cast (_DT as varchar)
	,'{VER}', _VER
	,'{PREVVER}', _prev_ver
	,'{LINK}', sprintf('http://%s/wiki/%s%s/%s', sioc..get_cname(), _mainp, _cluster, _topic)
	);

    http ('<item>',_out);
    http ('<title>',_out);
    http_value (RSS_SUBJECT(_op, _repl), null, _out);
    http ('</title>',_out);
    --http (sprintf ('<link>http://%s/wiki/%s%U/%U</link>', sioc..get_cname(), _mainp, _cluster, _topic),_out);
    http (sprintf ('<link>%s</link>', WV.WIKI.READONLYWIKIIRI (_cluster, _topic)), _out);
    http ('<pubDate>',_out);
    http_value (WV.WIKI.DATEFORMAT (_dt, 'rfc1123'), null, _out);
    http ('</pubDate>',_out);
    http ('<description>', _out);
    http_value (RSS_CONTENT (_op, _repl), null, _out);
    http('</description>', _out);
    http('</item>', _out);
  }
  http ('</channel>', _out);
  http ('</rss>', _out);
  return string_output_string(_out);
}
;

create procedure WIKI_LINK()
{
  return 'http://' || sioc..get_cname() || '/wiki';
}
;


create procedure RESOURCE_PATH()
{
  return WIKI_LINK() || '/resources';
}
;

create procedure WV..WIKI_PROFILE(in _cluster_name varchar, in _type varchar)
{
  declare author varchar;
  author:=WV.WIKI.CLUSTERPARAM( coalesce(_cluster_name, 'Main'), 'creator'); --dav
  declare _out any;
  _out := string_output();

  http ('<?xml version="1.0" encoding="utf-8"?>');
  http ('<rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#" xmlns:wiki="http://purl.org/wikirdf/wikiprofile#" xmlns:doap = "http://usefulinc.com/ns/doap#" xmlns:foaf = "http://xmlns.com/foaf/0.1">');
  http (sprintf ('<wiki:Wiki rdf:ID="%s">', _cluster_name));
  http (sprintf ('<wiki:name>%s</wiki:name>', _cluster_name));
  http (sprintf ('<wiki:description>%s</wiki:description>', (select coalesce(WAI_DESCRIPTION,'') from DB..WA_INSTANCE where WAI_IS_PUBLIC = 1 and WAI_MEMBERS_VISIBLE = 1 and WAI_NAME = _cluster_name )));
  http ('<wiki:creator>');
    http (sprintf ('<foaf:Person rdf:about="http://%s%s/%s">', sioc..get_cname (), sioc..get_base_path (), author));
      http (sprintf ('<foaf:name>%s</foaf:name>', (select coalesce(U_FULL_NAME, U_NAME) from DB.DBA.SYS_USERS where U_NAME = author) ));
      http (sprintf ('<foaf:homepage rdf:resource="http://%s%s/%s" />', sioc..get_cname (), sioc..get_base_path (), author));
    http ('</foaf:Person>');
  http ('</wiki:creator>');
  -- Crediting the Software

  -- Wiki Features
  http (sprintf ('<wiki:wikiURI rdf:resource="http://%s%s/%s/%s" />', sioc..get_cname(), WV.WIKI.CLUSTERPARAM (_cluster_name, 'home', '/wiki/main'), _cluster_name, WV.WIKI.CLUSTERPARAM (_cluster_name, 'index-page', 'WelcomeVisitors')));
--  <wiki:icon             rdf:resource="http://example.com/wiki_logo.gif"                 />
  http (sprintf ('<wiki:baseURI rdf:resource="%s?" />', WV..WIKI_LINK() ) );
  http (sprintf ('<wiki:allPagesURI rdf:resource="http://%s%s/%s/%s?command=index" />', sioc..get_cname(), WV.WIKI.CLUSTERPARAM (_cluster_name, 'home', '/wiki/main'), _cluster_name, WV.WIKI.CLUSTERPARAM (_cluster_name, 'index-page', 'WelcomeVisitors')));
  http (sprintf ('<wiki:recentChangesURI rdf:resource="%s/history.vspx?id=" />', RESOURCE_PATH()));
  http (sprintf ('<wiki:rssURI rdf:resource="%s/gems.vsp?type=rss20&amp;cluster=%s" />', RESOURCE_PATH(), _cluster_name) );
--  <wiki:lastDiffURI      rdf:resource="http://example.com/wiki?action=diff;id="          />
  http (sprintf ('<wiki:editPageURI      rdf:resource="http://%s%s/%s/%s?command=edit" />', sioc..get_cname(), WV.WIKI.CLUSTERPARAM (_cluster_name, 'home', '/wiki/main'), _cluster_name, WV.WIKI.CLUSTERPARAM (_cluster_name, 'index-page', 'WelcomeVisitors')));
--  <wiki:pageHistoryURI   rdf:resource="http://example.com/wiki?action=history;id="       />
  http (sprintf ('<wiki:searchURI        rdf:resource="%s/advanced_search.vspx?cluster=" />', RESOURCE_PATH()));
--  <wiki:searchTitlesURI  rdf:resource="http://example.com/wiki?action=titlesearch;term=" />

  http('</wiki:Wiki>');
  http('</rdf:RDF>');

  return string_output_string(_out);
}
;

create procedure WV.WIKI.TopicTextSparql (
  in _res_col integer,
  in _res_full_path varchar,
  in _res_owner integer)
{
  declare exit handler for sqlstate '*' {
  --dbg_obj_print ('TopicTextSparql:', __SQL_STATE, __SQL_MESSAGE);
  return '';
  };
  declare N, clusterId integer;
  declare st, msg, meta, data any;
  declare S, cname, gname, topicIRI, clusterIRI, topicName, clusterName, content varchar;

  cname := cfg_item_value (virtuoso_ini_path (), 'URIQA', 'DefaultHost');
  if (cname is null)
  {
    declare tmp any;
    tmp := sys_stat ('st_host_name');
    if (server_http_port () <> '80')
      tmp := tmp || ':'|| server_http_port ();
    cname := tmp;
  }
  gname := sprintf ('http://%s%U', cname, _res_full_path);
  select ClusterName, ClusterId into clusterName, clusterId from WV.WIKI.CLUSTERS where ColID = _res_col;
  clusterIRI := SIOC..wiki_cluster_iri (clusterName);

  S := 'sparql
        PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
        PREFIX sioc: <http://rdfs.org/sioc/ns#>
        SELECT ?post, ?content
        FROM <%s>
        WHERE {
                <%s> sioc:container_of ?post .
                ?post sioc:content ?content.
              }';

  S := sprintf (S, gname, clusterIRI);

  st := '00000';
  exec (S, st, msg, vector (), 0, meta, data);
  if (st = '00000')
  {
    if ( not exists (select 1 from DB.DBA.WA_MEMBER where WAM_USER = _res_owner and WAM_INST = clusterName))
      _res_owner := (select U_ID from DB.DBA.SYS_USERS where U_NAME = WV.WIKI.CLUSTERPARAM (clusterId, 'creator', 'dav'));
    for (N := 0; N < length (data); N := N + 1)
    {
      topicIRI := data[N][0];
      if (topicIRI like clusterIRI || '%')
      {
        topicName := trim (replace (topicIRI, clusterIRI, ''), '/') || '.txt';
        content := data[N][1];
        WV.WIKI.UPLOADPAGE (_res_col, topicName, content, WV.WIKI.CLUSTERPARAM (clusterId, 'creator', 'dav'), clusterId, (select U_NAME from WS.WS.SYS_DAV_USER where U_ID = _res_owner));
      }
    }
  }
}
;


create procedure WV.WIKI.user_password (
  in user_id integer)
{
  return coalesce ((select pwd_magic_calc(U_NAME, U_PWD, 1) from WS.WS.SYS_DAV_USER where U_ID = user_id), '');
}
;

use DB
;

