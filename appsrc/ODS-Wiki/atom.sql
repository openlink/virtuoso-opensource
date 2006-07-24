--
--  atom.sql
--
--  $Id$
--
--  Atom publishing protocol support.
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

use WV;

create function _set (inout object any, in propname varchar, in value any)
{
  object := vector_concat (object, vector (propname, value));
  return object;
}
;

create function _get (inout object any, in propname varchar)
{
  return get_keyword (object, propname);
}
;

create function atom_parse (inout xt any)
{
  declare _post any;
  _post := vector();
  _set(_post, 'title', xpath_eval ('string (/entry/title)', xt));
  _set(_post, 'excerpt', xpath_eval ('string (/entry/subtitle)', xt, 1));
  _set(_post, 'summary', xpath_eval ('string (/entry/summary)', xt, 1));
  _set(_post, 'author', xpath_eval ('string (/entry/author/name)', xt, 1));
  declare tims varchar;
  tims := cast(xpath_eval ('/entry/issued/text()', xt, 1) as varchar);
  if (tims is not null)
    _set (_post, 'date_created', cast (tims as datetime));
  if (xpath_eval ('/entry/content[@type="text" or @type="html" or @mode="escaped"]', xt, 1) is not null)
    {
       _set (_post, 'description', xpath_eval ('string (/entry/content)', xt));
    }
  else
    {
       declare ss any; ss := string_output_string ();
       http_value (xpath_eval ('/entry/content/*', xt, 1), null, ss);
       _set (_post, 'description', string_output_string (ss));
    }
  return _post;
}
;

create procedure WV.WIKI.gdata
	(
	 in q varchar := null,
	 in author varchar := null,
	 in alt varchar := 'atom',
	 in "updated-min" datetime := null,
	 in "updated-max" datetime := null,
	 in "start-index" int := 1,
	 in "max-results" int := 10
	 )
    __SOAP_HTTP 'text/xml'
{
  --dbg_obj_princ ('got it!: ', q, "updated-min", "updated-max", author);

  declare path, lpath, ppath, cont, xmlt, rc, opts any;
  declare pars, lines, xt any;
  declare meth, blogid, u_name, ppath_pref, lpath_strip, logical_path varchar;
  declare u_id, ver, to_trim int;
  declare full_path, p_full_path, ct, id varchar;
  declare title, content, author_name, author_mail, hstat, h varchar;
  declare struct BLOG.DBA."MTWeblogPost";
  declare req BLOG.DBA."blogRequest";
  declare "atom-pub", i int;
  declare vhost, lhost, p_path_str, l_path_str, gdata_url varchar;

  opts := http_map_get ('options');
  if (isarray (opts))
    "atom-pub" := get_keyword ('atom-pub', opts, 0);
  else
    "atom-pub" := 0;
  pars := http_param ();
  lines := http_request_header ();
  ppath := http_physical_path ();
  logical_path := http_path ();
  meth := http_request_get ('REQUEST_METHOD');
  ct := http_request_header (http_request_header (), 'Content-Type');
  lpath := http_map_get ('domain');

  vhost := http_map_get ('vhost');
  lhost := http_map_get ('lhost');

  h := DB.DBA.WA_GET_HOST ();
  --dbg_printf ('meth=[%s] path=[%s]', meth, http_path ());
  path := split_and_decode (ppath, 0, '\0\0/');

  blogid := null;
  id := null;

  declare _page, _cluster, _lname, _att, _badjust varchar;
  declare exit handler for sqlstate '*' {
	--dbg_obj_print (__SQL_STATE, __SQL_MESSAGE);
	resignal;
  };
  declare _topicid int;
  WV.WIKI.ATOMDECODEWIKIPATH (_topicid, _cluster);
  --dbg_obj_print (_topicid, _cluster);
  declare _topic WV.WIKI.TOPICINFO;
  _topic := WV.WIKI.TOPICINFO();
  _topic.ti_id := _topicid;
  if (_topic.ti_id = 0 and _cluster is null)
    {
      cont := http_body_read ();
      signal ('22023', 'No such blog');
    }
  if (_topic.ti_id <> 0)
    _topic.ti_find_metadata_by_id ();

  h := sprintf ('http://%s%s', h, lpath);

  set_user_id ('dba');
  set http_charset='utf-8';

  gdata_url := DB.DBA.WA_GET_HTTP_URL ();
  connection_set ('GData_URI', gdata_url);
  connection_set ('Atom_Self_URI', h);

  declare exit handler for not found {
    return null;
  };

  declare exit handler for sqlstate '*' {
    if (__SQL_STATE = 'BLOGV')
      http_request_status ('HTTP/1.1 409 Conflict');
    resignal;
    return null;
  };


  xt := null;
  --dbg_obj_print (ct);
  if (
      ct = 'application/atom+xml'
      or ct = 'application/x.atom+xml'
      or ct = 'text/xml'
      or ct = 'application/xml'
     )
    {
      cont := http_body_read ();
      xmlt := string_output_string (cont);
      if (length (xmlt))
	{
	  xt := xml_tree_doc (xml_tree (xmlt));
	  xml_tree_doc_encoding (xt, 'utf-8');
	}
    }
  --dbg_obj_print (xt);

  hstat := 'HTTP/1.1 200 OK';
  --dbg_obj_print (meth, q, id, "updated-min", "updated-max", author);
  if (meth = 'GET' and q is null and id is null and "updated-min" is null and "updated-max" is null and author is null)
    {
      if ("atom-pub" = 1)
	http_header ('Content-Type: application/x.atom+xml\r\n');
      else
	http_header ('Content-Type: text/xml; charset=UTF-8\r\n');

   --   full_path := sprintf ('/wiki/resources/gems.vsp?type=atom&cluster=%U', _cluster);
      full_path := '/wiki/resources/gems.vsp';

      --dbg_printf ('using [%s]', full_path);
      p_full_path := '/DAV/VAD/wiki/Root/gems.vsp';
      p_full_path := http_physical_path_resolve (full_path, 1);
      --dbg_obj_print (p_full_path, full_path);
      http_internal_redirect (full_path, p_full_path);
      --dbg_obj_print ('next:', path, pars, lines);
      --dbg_obj_print (http_physical_path());
      --dbg_printf ('Atom_Self_URI=%s', connection_get ('Atom_Self_URI'));
	--dbg_obj_print (path  , pars , lines );
      if (_topicid <> 0)
	pars := vector_concat (pars, vector ('topicid', cast (_topicid as varchar)));
      WS.WS.GET (path, vector_concat (pars, vector ('type', 'atom', 'cluster', _cluster, 'mode', 'list')), lines);
      return NULL;
    }
  else if (meth = 'PUT')
    {
      if (_topicid = 0)
	hstat := 'HTTP/1.1 404 Not Found';
      else 
        { 
          declare title2, content2 varchar;
          title2 := xpath_eval ('/entry/title/text()', xt);
          content2 := cast (xpath_eval ('/entry/content/text()', xt) as varchar);
        
          declare _newtopic WV.WIKI.TOPICINFO;
          _newtopic := WV.WIKI.TOPICINFO();
          _newtopic.ti_id := _topicid;
          _newtopic.ti_find_metadata_by_id();
          _newtopic.ti_update_text (content2, 'dav'); 
	  --dbg_obj_print (_newtopic);
          hstat := 'HTTP/1.1 201 Created';
        }
    }
  else if (meth = 'POST')
    {
      content := cast (xpath_eval ('/entry/content/text()', xt) as varchar);
      declare _newtopic WV.WIKI.TOPICINFO;
      _newtopic := WV.WIKI.TOPICINFO();
      _newtopic.ti_default_cluster := 'Main';
      _newtopic.ti_raw_name := cast (xpath_eval ('/entry/title/text()', xt) as varchar);
      _newtopic.ti_parse_raw_name ();
      _newtopic.ti_fill_cluster_by_name ();
      declare _res int;
      _res := WV.WIKI.UPLOADPAGE (_newtopic.ti_col_id, _newtopic.ti_local_name || '.txt',
	 content, 
	 (select u.U_NAME  from WS.WS.SYS_DAV_COL, DB.DBA.SYS_USERS u where COL_ID = _topic.ti_col_id and u.U_ID = COL_OWNER));
      --dbg_obj_print (_newtopic, _res);
 
      hstat := 'HTTP/1.1 201 Created';
    }
  else if (meth = 'DELETE')
    {
      if (_topicid = 0)
	hstat := 'HTTP/1.1 404 Not Found';
      else
        {
          DB.DBA.DAV_DELETE_INT (DB.DBA.DAV_SEARCH_PATH (_topic.ti_res_id, 'R'), 1, null, null, 0);
	  hstat := 'HTTP/1.1 200 OK';
        }
    }
  http_request_status (hstat);
  return NULL;
}
;

DB.DBA.VHOST_REMOVE (lpath=>'/wiki/Atom');
DB.DBA.VHOST_DEFINE (lpath=>'/wiki/Atom', ppath=>'/SOAP/Http/gdata', soap_user=>'Wiki', opts=>vector ('atom-pub', 1));

use DB
;
  

