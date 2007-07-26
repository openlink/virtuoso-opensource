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

create function ATOM_PUB_VHOST_DEFINE(in _cluster varchar)
{
  declare login varchar;
  login := WV.WIKI.CLUSTERPARAM (_cluster, 'creator', 'dav');
  DB.DBA.VHOST_REMOVE (lpath=>WV.WIKI.ATOM_BASE (login, _cluster));
  DB.DBA.VHOST_DEFINE (lpath=>WV.WIKI.ATOM_BASE (login, _cluster), ppath=>'/SOAP/Http/gdata', soap_user=>'Wiki', opts=>vector ('atom-pub', 1));
  WV.WIKI.SETCLUSTERPARAM (_cluster, 'atom-pub', WV.WIKI.ATOM_BASE (login, _cluster));
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


create function WV.WIKI.ATOM_BASE (in _user varchar, in _cluster varchar)
{
   return sprintf ('/dataspace/%U/wiki/%U/atom-pub', _user, _cluster);
}
;

create function WV.WIKI.ATOM_PUBLISH (in _cluster varchar)
{
   declare _res varchar;
   _res := '';
   if (_cluster is null)
     {
       for select WAI_NAME from DB.DBA.WA_INSTANCE where WAI_TYPE_NAME = 'oWiki' do
         {
           _res := _res || WV.WIKI.ATOM_PUBLISH (WAI_NAME);
         }
     }
   else
     {
        _res := sprintf ('<collection title="%s" href="http://%s/wiki/Atom/%s/"><accept>entry</accept></collection>', _cluster, WV.WIKI.GET_HOST(), _cluster);
     }
   return _res;
}
;

create function WV.WIKI.ATOM_ENTRY (inout _topic WV.WIKI.TOPICINFO)
{
  declare ss any; 
  ss := string_output ();
  
  http ('<entry xmlns="http://www.w3.org/2005/Atom">', ss);

  http (sprintf('<title>%s</title>', _topic.ti_cluster_name || '.' || _topic.ti_local_name), ss);
  http (sprintf('<id>%s</id>', WV.WIKI.RESOURCE_CANONICAL (_topic.ti_res_id)), ss);
  http (sprintf('<updated>%s</updated>', WV.WIKI.DATEFORMAT (_topic.ti_mod_time, 'iso8601')), ss);
  http (sprintf('<published>%s</published>', WV.WIKI.DATEFORMAT ((select RES_CR_TIME from WS.WS.SYS_DAV_RES where RES_ID = _topic.ti_res_id), 'iso8601')), ss);
  http (sprintf('<author><name>%s</name></author>', WV.WIKI.USER_WIKI_NAME_2(_topic.ti_author_id)), ss);
  http ('<content type="text/plain">%s</content>', ss);
  http_value (_topic.ti_text, null, ss);
  http ('</content>', ss);
  http (sprintf ('<link rel="edit" href="http://%s/wiki/Atom/%s/%s" />', WV.WIKI.GET_HOST(), _topic.ti_cluster_name, _topic.ti_local_name), ss);

  http ('</entry>', ss);
  return string_output_string (ss);
}
;
  

create function WV.WIKI.ATOM_COLLECTION (in _cluster varchar)
{
  declare _res any;

  _res := string_output ();
  http (sprintf ('<feed xmlns="http://www.w3.org/2005/Atom"><id>%s</id>', WV.WIKI.CLUSTER_CANONICAL (_cluster)), _res);
  for select LOCALNAME, RESID, RES_MOD_TIME, RES_OWNER
        from WV.WIKI.TOPIC t
               inner join WV.WIKI.CLUSTERS c on (c.CLUSTERID = t.CLUSTERID)
	inner join WS.WS.SYS_DAV_RES on (RESID = RES_ID)
    where CLUSTERNAME = _cluster do
    {
      declare _topic WV.WIKI.TOPICINFO;
      _topic := WV.WIKI.TOPICINFO();
      _topic.ti_local_name := LOCALNAME;
      _topic.ti_cluster_name := _cluster;
      _topic.ti_res_id := RESID;
      _topic.ti_mod_time := RES_MOD_TIME;
      _topic.ti_author_id := RES_OWNER;
      _topic.ti_text := '';
      http (WV.WIKI.ATOM_ENTRY (_topic), _res);
   }
  http ('</feed>', _res);
  return string_output_string (_res);
}
;

create procedure WV.WIKI.gdata (
	 in q varchar := null,
	 in author varchar := null,
	 in alt varchar := 'atom',
	 in "updated-min" datetime := null,
	 in "updated-max" datetime := null,
	 in "start-index" int := 1,
	 in "max-results" int := 10
) __SOAP_HTTP 'text/xml'
{
  --dbg_obj_princ ('WV.WIKI.gdata - header', http_request_header ());
  --dbg_obj_princ ('WV.WIKI.gdata - body', string_output_string (http_body_read ()));

  declare _user varchar;
  declare _auth any;

  _auth := DB.DBA.vsp_auth_vec (http_request_header());
  if (_auth = 0)
    {
       http_body_read ();
       http_request_status ('HTTP/1.1 401 Unauthorized');
      return null;
    }
  else
    {
      if ((get_keyword ('authtype', _auth) <> 'basic') or WV.WIKI.AUTHENTICATE (get_keyword ('username', _auth), get_keyword ('pass', _auth)) = 0)
        {
          http_body_read ();
          http_request_status ('HTTP/1.1 401 Unauthorized');
          return NULL;
        }
      _user := get_keyword ('username', _auth);
      connection_set ('HTTP_CLI_UID', _user);
    }

  declare lpath, ppath, cont, rc, xt any;
  declare meth, ct varchar;
  declare title, content, hstat, h varchar;
  declare _page, _cluster, gdata_url varchar;
  declare "atom-pub", i int;
  declare _topicid int;

  meth := http_request_get ('REQUEST_METHOD');
  ct := http_request_header (http_request_header (), 'Content-Type');
  lpath := http_map_get ('domain');

  h := DB.DBA.WA_GET_HOST ();

  WV.WIKI.ATOMDECODEWIKIPATH (_topicid, _cluster);
  declare _topic WV.WIKI.TOPICINFO;
  _topic := WV.WIKI.TOPICINFO();
  _topic.ti_id := _topicid;
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
  if (
      ct = 'application/atom+xml'
      or ct = 'application/x.atom+xml'
      or ct = 'text/xml'
      or ct = 'application/xml'
     )
    {
      cont := string_output_string (http_body_read ());
      if (length (cont))
	{
        xt := xml_tree_doc (xml_tree (cont));
	  xml_tree_doc_encoding (xt, 'utf-8');
	}
    }
  --dbg_obj_print ( 'meth', meth);
  hstat := 'HTTP/1.1 200 OK';
  if (meth = 'GET' and _cluster is null)
    {
      http_header ('Content-Type: application/atomserv+xml\r\n');
      http ('<?xml version="1.0" encoding=\'utf-8\'?><service xmlns="http://purl.org/atom/app#">');
      http('<workspace title="Wiki">');
      http(WV.WIKI.ATOM_PUBLISH(NULL));
      http('</workspace>');
      http('</service>');
    }
  else if (meth = 'GET' and _cluster is not null and _topicid = 0)
    {
      http_header ('Content-Type: application/atom+xml\r\n');
      http('<?xml version="1.0" encoding=\'utf-8\'?>');
      http(WV.WIKI.ATOM_COLLECTION(_cluster));
    }      
  else if (meth = 'GET' and _cluster is not null  and _topicid <> 0)
    {
      http_header ('Content-Type: application/atom+xml\r\n');
      http('<?xml version="1.0" encoding=\'utf-8\'?>');
      http(WV.WIKI.ATOM_ENTRY(_topic));
    }
  else if (meth = 'PUT')
    {
          declare title2, content2 varchar;
      declare _newtopic WV.WIKI.TOPICINFO;

          title2 := xpath_eval ('/entry/title/text()', xt);
          content2 := cast (xpath_eval ('/entry/content/text()', xt) as varchar);
        
          _newtopic := WV.WIKI.TOPICINFO();
	  _newtopic.ti_default_cluster := coalesce (_cluster, 'Main');
	  _newtopic.ti_raw_name := cast (xpath_eval ('/entry/title/text()', xt) as varchar);
	  _newtopic.ti_parse_raw_name ();
	  _newtopic.ti_fill_cluster_by_name ();
          _newtopic.ti_find_id_by_local_name ();
	  if (_newtopic.ti_id <> 0)
	    {
        WV.WIKI.UPLOADPAGE (_newtopic.ti_col_id, _newtopic.ti_local_name || '.txt', content2, _user);
        }
	   else
	     hstat := 'HTTP/1.1 404 Not Found';
    }
  else if (meth = 'POST')
    {
      declare _newtopic WV.WIKI.TOPICINFO;

      content := cast (xpath_eval ('/entry/content/text()', xt) as varchar);
      _newtopic := WV.WIKI.TOPICINFO();
      _newtopic.ti_default_cluster := coalesce (_cluster, 'Main');
      _newtopic.ti_raw_name := cast (xpath_eval ('/entry/title/text()', xt) as varchar);
      _newtopic.ti_parse_raw_name ();
      _newtopic.ti_fill_cluster_by_name ();
      WV.WIKI.UPLOADPAGE (_newtopic.ti_col_id, _newtopic.ti_local_name || '.txt', content, _user);
      hstat := 'HTTP/1.1 201 Created';
    }
  else if (meth = 'DELETE')
    {
          declare _newtopic WV.WIKI.TOPICINFO;
          _newtopic := WV.WIKI.TOPICINFO();
	  _newtopic.ti_default_cluster := coalesce (_cluster, 'Main');
	  _newtopic.ti_raw_name := cast (xpath_eval ('/entry/title/text()', xt) as varchar);
	  _newtopic.ti_parse_raw_name ();
	  _newtopic.ti_fill_cluster_by_name ();
          _newtopic.ti_find_id_by_local_name ();
	  if (_newtopic.ti_id <> 0)
        {
	       _newtopic.ti_find_metadata_by_id ();
        DB.DBA.DAV_DELETE_INT (DB.DBA.DAV_SEARCH_PATH (_newtopic.ti_res_id, 'R'), 1, null, null, 0);
	  hstat := 'HTTP/1.1 200 OK';
        }
	   else
	     hstat := 'HTTP/1.1 404 Not Found';
    }
  http_request_status (hstat);
  return NULL;
}
;

DB.DBA.VHOST_REMOVE (lpath=>'/wiki/Atom');
DB.DBA.VHOST_DEFINE (lpath=>'/wiki/Atom', ppath=>'/SOAP/Http/gdata', soap_user=>'Wiki', opts=>vector ('atom-pub', 1));

use DB
;
  

-- atom related xslt functions

create function WV.WIKI.ATOM_PUB_URI(in _cluster_name varchar)
{
  return '/dataspace/' || WV.WIKI.CLUSTERPARAM (_cluster_name, 'owner', 'dav') || '/wiki/' || _cluster_name || '/atom-pub';
}
;

grant execute on WV.WIKI.ATOM_PUB_URI to public
;


xpf_extension ('http://www.openlinksw.com/Virtuoso/WikiV/:atom_pub_uri', 'WV.WIKI.ATOM_PUB_URI')
;
