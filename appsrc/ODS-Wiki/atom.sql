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

use WV;

-------------------------------------------------------------------------------
--
create procedure _set (
  inout object any,
  in propname varchar,
  in value any)
{
  object := vector_concat (object, vector (propname, value));
  return object;
}
;

-------------------------------------------------------------------------------
--
create procedure _get (
  inout object any,
  in propname varchar)
{
  return get_keyword (object, propname);
}
;

-------------------------------------------------------------------------------
--
create procedure WV.WIKI.ATOM_BASE (
  in _user varchar,
  in _cluster varchar)
{
   return sprintf ('/dataspace/%U/wiki/%U/atom-pub', _user, _cluster);
}
;

--! decodes /wiki/Atom/<topicid>/..
create procedure WV.WIKI.ATOMDECODEWIKIPATH (
  out _topicid int,
  out _cluster varchar)
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

-------------------------------------------------------------------------------
--
create procedure WV.WIKI.ATOM_PUBLISH (
  in _cluster varchar)
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
    _res := sprintf ('<collection title="%s" href="http://%s/wiki/Atom/%s/"><accept>entry</accept></collection>\n', _cluster, WV.WIKI.GET_HOST(), _cluster);
     }
   return _res;
}
;

-------------------------------------------------------------------------------
--
create procedure WV.WIKI.ATOM_ENTRY (
  inout _topic WV.WIKI.TOPICINFO)
{
  declare ss any; 
  
  ss := string_output ();
  http ('<entry xmlns="http://www.w3.org/2005/Atom">\n', ss);

  http (sprintf('<title>%s</title>\n', _topic.ti_cluster_name || '.' || _topic.ti_local_name), ss);
  http (sprintf('<id>%s</id>\n', WV.WIKI.RESOURCE_CANONICAL (_topic.ti_res_id)), ss);
  http (sprintf('<updated>%s</updated>\n', WV.WIKI.DATEFORMAT (_topic.ti_mod_time, 'iso8601')), ss);
  http (sprintf('<published>%s</published>\n', WV.WIKI.DATEFORMAT ((select RES_CR_TIME from WS.WS.SYS_DAV_RES where RES_ID = _topic.ti_res_id), 'iso8601')), ss);
  http (sprintf('<author><name>%s</name></author>\n', WV.WIKI.USER_WIKI_NAME_2(_topic.ti_author_id)), ss);
  http ('<content type="text/plain">%s</content>\n', ss);
  http_value (_topic.ti_text, null, ss);
  http ('</content>\n', ss);
  http (sprintf ('<link rel="edit" href="http://%s/wiki/Atom/%s/%s" />\n', WV.WIKI.GET_HOST(), _topic.ti_cluster_name, _topic.ti_local_name), ss);

  http ('</entry>\n', ss);
  return string_output_string (ss);
}
;
  
-------------------------------------------------------------------------------
--
create procedure WV.WIKI.ATOM_COLLECTION (
  in _cluster varchar)
{
  declare ss any;

  ss := string_output ();
  http (sprintf ('<feed xmlns="http://www.w3.org/2005/Atom">\n<id>%s</id>\n', WV.WIKI.CLUSTER_CANONICAL (_cluster)), ss);
  for (select LOCALNAME, RESID, RES_MOD_TIME, RES_OWNER
        from WV.WIKI.TOPIC t
               inner join WV.WIKI.CLUSTERS c on (c.CLUSTERID = t.CLUSTERID)
	inner join WS.WS.SYS_DAV_RES on (RESID = RES_ID)
        where CLUSTERNAME = _cluster) do
    {
    declare topic WV.WIKI.TOPICINFO;

    topic := WV.WIKI.TOPICINFO();
    topic.ti_local_name := LOCALNAME;
    topic.ti_cluster_name := _cluster;
    topic.ti_res_id := RESID;
    topic.ti_mod_time := RES_MOD_TIME;
    topic.ti_author_id := RES_OWNER;
    topic.ti_text := '';
    http (WV.WIKI.ATOM_ENTRY (topic), ss);
   }
  http ('</feed>', ss);
  return string_output_string (ss);
}
;

-------------------------------------------------------------------------------
--
create procedure WV.WIKI.gdata (
	 in q varchar := null,
	 in author varchar := null,
	 in alt varchar := 'atom',
	 in "updated-min" datetime := null,
	 in "updated-max" datetime := null,
	 in "start-index" int := 1,
  in "max-results" int := 10) __SOAP_HTTP 'text/xml'
{
  declare _topic_id, _uid, _unauthorized integer;
  declare _user, _password, _role, _uid varchar;
  declare _http_path, _path, _action, _version varchar;
  declare _atomVersion, _auth, _session, _method, _content_type, _content_description, _options, _status, _content, _vCalendar, xt any;

  declare h, _cluster varchar;

  _http_path := http_path ();
  _path := split_and_decode (_http_path, 0, '\0\0/');

  _cluster := null;
  if (length (_path) > 0 and _path[1] = 'dataspace')
    {
    if (length (_path) > 5)
    {
      _cluster := atoi (_path [5]);
    }
    _action := null;
    if (length (_path) > 6 and _path [6] <> '')
    {
      _action := _path [6];
    }
    _version := null;
    if (length (_path) > 7 and atoi (_action) > 0)
        {
      _version := atoi (_path [7]);
    }
  }
  if (length (_path) > 0 and _path[1] = 'wiki')
  {
    if (length (_path) > 3)
    {
      _cluster := (select WAI_NAME from DB.DBA.WA_INSTANCE where WAI_ID = atoi (_path [3]));
    }
    _action := null;
    if (length (_path) > 4 and _path [4] <> '')
    {
      _action := _path [4];
    }
    _version := null;
    if (length (_path) > 5 and atoi (_action) > 0)
    {
      _version := atoi (_path [5]);
        }
    }

  if (_cluster is null)
  {
    _status := 'HTTP/1.1 404 Not Found';
    goto _exit;
  }
  _topic_id := 0;

  _method := http_request_get ('REQUEST_METHOD');
  _content_type := http_request_header (http_request_header (), 'Content-Type');
  _content_description := http_request_header (http_request_header (), 'Content-Description');
  _options := http_map_get ('options');

  _unauthorized := 0;
  _auth := DB.DBA.vsp_auth_vec (http_request_header());
  if (_auth = 0)
  {
    _unauthorized := 1;
  }
  else
  {
    if (get_keyword ('authtype', _auth) <> 'basic')
    {
      _unauthorized := 1;
    }
    else
    {
      _user := get_keyword ('username', _auth, '');
      _password := get_keyword ('pass', _auth, '');
      if (not DB.DBA.web_user_password_check (_user, _password))
      {
        _unauthorized := 1;
      }
      else
      {
        if (not WV.WIKI.AUTHENTICATE (_user, _password))
        {
          _unauthorized := 1;
        }
      }
    }
  }
  if (_method <> 'GET' and _unauthorized)
  {
    _status := 'HTTP/1.1 401 Unauthorized';
    goto _exit;
  }

  set_user_id ('dba');
  set http_charset='utf-8';

  h := sprintf ('http://%s%s', DB.DBA.WA_GET_HOST (), http_map_get ('domain'));
  connection_set ('HTTP_CLI_UID', _user);
  connection_set ('GData_URI', DB.DBA.WA_GET_HTTP_URL ());
  connection_set ('Atom_Self_URI', h);

  declare exit handler for not found
  {
    return null;
  };

  declare exit handler for sqlstate '*'
  {
    -- dbg_obj_print ('', __SQL_STATE, __SQL_MESSAGE);
    if (__SQL_STATE = 'BLOGV')
      http_request_status ('HTTP/1.1 409 Conflict');
    resignal;
    return null;
  };

  _status := 'HTTP/1.1 200 OK';
  if (_method = 'GET')
    {
    declare sStream any;

    sStream := string_output ();
    if (_action = 'intro')
	{
  	  http_header ('Content-Type: application/atomserv+xml; charset=UTF-8\r\n');

      http (         '<?xml version="1.0" encoding="utf-8"?>\n', sStream);
      http (         '<service xmlns="http://purl.org/atom/app#">\n', sStream);
      http (sprintf ('  <workspace title="%s" >\n', _cluster), sStream);
      http (sprintf ('    <collection title="%V Entries" href="%s" >\n', _cluster, 'http://'|| WV.WIKI.http_name ()|| WV.WIKI.atom_pub_uri (_cluster)), sStream);
      http (         '    <member-type>entry</member-type>\n', sStream);
      http (         '    </collection>\n', sStream);
      http (         '  </workspace>\n', sStream);
      http (         '</service>', sStream);
    }
    else
    {
      http (         '<?xml version="1.0" encoding="UTF-8" ?>\n', sStream);
      http (         '<atom:feed xmlns:atom="http://www.w3.org/2005/Atom">\n', sStream);
      http (sprintf ('<atom:title>%V</atom:title>\n', _cluster), sStream);
      http (sprintf ('<atom:link href="%s" type="text/html" rel="alternate" />\n', WV.WIKI.wiki_cluster_uri (_cluster)), sStream);
      http (sprintf ('<atom:link href="%s" type="application/atom+xml" rel="self" />\n', 'http://'|| WV.WIKI.http_name ()|| WV.WIKI.atom_pub_uri (_cluster)), sStream);
      http (         '  <atom:author>\n', sStream);
      http (sprintf ('    <atom:name>%V</atom:name>\n', WV.WIKI.CLUSTERPARAM (_cluster, 'creator', 'dav')), sStream);
    --http (sprintf ('    <atom:email>%V</atom:email>\n', CAL.WA.account_mail (CAL.WA.domain_owner_id (_domain_id))), sStream);
      http (         '  </atom:author>\n', sStream);
      http (sprintf ('<atom:updated>%s</atom:updated>\n', DB.DBA.date_rfc1123 (now ())), sStream);
      http (sprintf ('<atom:generator>%V</atom:generator>\n', 'Virtuoso Universal Server ' || sys_stat('st_dbms_ver')), sStream);
      http (         '</atom:feed>\n', sStream);
    }
    return string_output_string (sStream);
  }
  else
  {
    declare content varchar;
    declare topic WV.WIKI.TOPICINFO;

    xt := null;
    if (_content_description = 'WIKI-ATTACHMENT')
    {
      _status := 'HTTP/1.1 404 Not Found';
      _path := http_request_header (http_request_header (), 'Content-Disposition', 'filename');
      _path := split_and_decode (_path, 0, '\0\0/');
      if (length (_path) = 2)
      {
        topic := WV.WIKI.TOPICINFO();
        topic.ti_default_cluster := coalesce (_cluster, 'Main');
        topic.ti_raw_name := _path[0];
        topic.ti_parse_raw_name ();
        topic.ti_fill_cluster_by_name ();
        topic.ti_find_id_by_local_name ();
        if (topic.ti_id)
        {
          _status := 'HTTP/1.1 200 OK';
          _content := string_output_string (http_body_read ());
          WV.WIKI.ATTACH2 (_uid, _path[1], _content_type,  topic.ti_id,  _content,  ' -- ');
        }
      }
    }
    else if (_content_type in ('application/atom+xml', 'application/x.atom+xml', 'text/xml', 'application/xml'))
    {
      _content := string_output_string (http_body_read ());
      if (length (_content))
    {
        xt := xml_tree_doc (xml_tree (_content));
        xml_tree_doc_encoding (xt, 'utf-8');
    }      
    _atomVersion := cast (xpath_eval ('[ xmlns:wv="http://www.openlinksw.com/Virtuoso/WikiV/" ] /entry/wv:version', xt) as varchar);
      if (isnull (_atomVersion) or (_atomVersion not in ('2.0', '3.0')))
    {
      _status := 'HTTP/1.1 412 Precondition Failed';
    }
    else if (_method in ('PUT', 'POST', 'DELETE'))
    {
        topic := WV.WIKI.TOPICINFO();
        topic.ti_default_cluster := coalesce (_cluster, 'Main');
        topic.ti_raw_name := cast (xpath_eval ('/entry/title/text()', xt) as varchar);
        topic.ti_parse_raw_name ();
        topic.ti_fill_cluster_by_name ();
        topic.ti_find_id_by_local_name ();
        if (topic.ti_id)
          topic.ti_find_metadata_by_id ();

        if (_method in ('PUT', 'POST'))
        {
      content := cast (xpath_eval ('/entry/content/text()', xt) as varchar);
          WV.WIKI.UPLOADPAGE (topic.ti_col_id, topic.ti_local_name || '.txt', content, _user);
          if (topic.ti_id = 0)
      _status := 'HTTP/1.1 201 Created';

          -- update attachments
          declare N, attachmentsCount integer;
          declare attachments_path varchar;
          declare attachments_list, attachment_names, attachment_name, attachment_type, attachment_content any;

          _uid := (select U_ID from DB.DBA.SYS_USERS where U_NAME = _user);
          attachment_names := vector ();
          attachmentsCount := xpath_eval ('[ xmlns:wv="http://www.openlinksw.com/Virtuoso/WikiV/" ] count(/entry/wv:attachments/wv:attachment)', xt);
          for (N := 0; N < attachmentsCount; N := N + 1)
          {
            attachment_name := cast (xpath_eval (sprintf ('[ xmlns:wv="http://www.openlinksw.com/Virtuoso/WikiV/" ] /entry/wv:attachments/wv:attachment[%d]/wv:name', N+1), xt) as varchar);
            attachment_names := vector_concat (attachment_names, vector (attachment_name));
            if (_atomVersion = '2.0')
            {
              attachment_type := cast (xpath_eval (sprintf ('[ xmlns:wv="http://www.openlinksw.com/Virtuoso/WikiV/" ] /entry/wv:attachments/wv:attachment[%d]/wv:type', N+1), xt) as varchar);
              attachment_content := decode_base64 (cast (xpath_eval (sprintf ('[ xmlns:wv="http://www.openlinksw.com/Virtuoso/WikiV/" ] /entry/wv:attachments/wv:attachment[%d]/wv:content/text()', N+1), xt) as varchar));
              WV.WIKI.ATTACH2 (_uid, attachment_name, attachment_type,  topic.ti_id,  attachment_content,  ' -- ');
            }
          }
          attachments_path := DB.DBA.DAV_SEARCH_PATH (topic.ti_col_id, 'C') || topic.ti_local_name || '/';
          attachments_list := DB.DBA.DAV_DIR_LIST (attachments_path, 0, 'dav', (select pwd_magic_calc (U_NAME, U_PWD, 1) from WS.WS.SYS_DAV_USER where U_ID = http_dav_uid()));

          -- delete non listed attachments
          if (not isinteger (attachments_list) and length (attachments_list))
          {
            foreach (any attachment in attachments_list) do
            {
              for (N := 0; N < length (attachment_names); N := N + 1)
              {
                if (attachment_names[N] = attachment[10])
                  goto _skip;
              }
              DB.DBA.DAV_DELETE_INT (attachment[0], 0, null, null, 0);
            _skip:;
          }
        }
    }
    else if (_method = 'DELETE')
    {
          if (topic.ti_id <> 0)
          {
          declare attachment_path varchar;

          attachment_path := DB.DBA.DAV_SEARCH_PATH (topic.ti_col_id, 'C') || topic.ti_local_name || '/';
          DB.DBA.DAV_DELETE_INT (attachment_path, 1, null, null, 0);
          DB.DBA.DAV_DELETE_INT (DB.DBA.DAV_SEARCH_PATH (topic.ti_res_id, 'R'), 1, null, null, 0);
      }
        }
    }
  }
  }

_exit:;
  _content := http_body_read ();
  http_request_status (_status);
  return null;
}
;

DB.DBA.VHOST_REMOVE (lpath=>'/wiki/Atom');
DB.DBA.VHOST_DEFINE (lpath=>'/wiki/Atom',
                     ppath=>'/SOAP/Http/gdata',
                     soap_user=>'Wiki',
                     opts=>vector ('atom-pub', 1));

-----------------------------------------------------------------------------------------
--

use DB
;

-- atom related xslt functions

-------------------------------------------------------------------------------
--
create procedure WV.WIKI.ATOM_PUB_URI (
  in _cluster_name varchar)
{
  return '/dataspace/' || WV.WIKI.CLUSTERPARAM (_cluster_name, 'creator', 'dav') || '/wiki/' || _cluster_name || '/atom-pub';
}
;

grant execute on WV.WIKI.ATOM_PUB_URI to public
;


xpf_extension ('http://www.openlinksw.com/Virtuoso/WikiV/:atom_pub_uri', 'WV.WIKI.ATOM_PUB_URI')
;

-----------------------------------------------------------------------------------------
--
create procedure WV.WIKI.tmp_atom_update ()
{
  if (registry_get ('wiki_atom_update') = '1')
    return;

  for (select ClusterId as _cluster_id, ClusterName from WV.WIKI.CLUSTERS) do
  {
    DB.DBA.VHOST_REMOVE (lpath => WV.WIKI.ATOM_PUB_URI (ClusterName));
    delete from WV.WIKI.CLUSTERSETTINGS where ClusterId = _cluster_id and ParamName = 'atom-pub';
  }
  registry_set ('wiki_atom_update', '1');
}
;

WV.WIKI.tmp_atom_update ()
;
