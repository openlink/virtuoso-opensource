--
--  $Id$
--
--  Atom publishing protocol support.
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2013 OpenLink Software
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

use BLOG;

create procedure GDATA_INIT ()
{
  if (exists (select 1 from "DB"."DBA"."SYS_USERS" where U_NAME = 'ATOM'))
    return;
  DB.DBA.USER_CREATE ('ATOM', uuid(), vector ('DISABLED', 1, 'LOGIN_QUALIFIER', 'ATOM'));
  -- delete old dirs
  DB.DBA.VHOST_REMOVE (lpath=>'/GData');
  DB.DBA.VHOST_REMOVE (lpath=>'/Atom');
}
;

GDATA_INIT ()
;



use ATOM;

create procedure ATOM.ATOM.intro (in b varchar)
__SOAP_HTTP 'text/xml'
  {
    declare s, h, title any;

    s := string_output ();
    h := BLOG..BLOG_GET_HOST ();

    h := 'http://'||h||'/Atom/'||b;

    title := coalesce ((select BI_TITLE from BLOG..SYS_BLOG_INFO where BI_BLOG_ID = b), 'My Blog');

    http ('<?xml version="1.0" encoding="utf-8"?>\n', s);
    http ('<service xmlns="http://purl.org/atom/app#">\n', s);
    http (sprintf ('  <workspace title="%s" >\n', title), s);
    http (sprintf ('    <collection title="%V Entries" href="%s" >\n', title, h), s);
    http ('      <member-type>entry</member-type>\n', s);
    http ('    </collection>\n', s);
    http ('  </workspace>\n', s);
    http ('</service>', s);

    return string_output_string (s);
  }
;


create procedure ATOM.ATOM.gdata
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

  h := BLOG..BLOG_GET_HOST ();
--  dbg_printf ('meth=[%s] path=[%s]', meth, http_path ());
  path := split_and_decode (ppath, 0, '\0\0/');

  blogid := null;
  id := null;

  if (length (path) > 4)
    blogid := path [4];

  if (length (path) > 5 and path [5] <> '')
    id := path [5];

  ver := null;
  --if (length (path) > 6 and atoi (id) > 0)
  --  ver := atoi (path [6]);

  if (blogid is null)
    {
      cont := http_body_read ();
      signal ('22023', 'No such blog');
    }

  ppath_pref := '';
  for (i := 1; i < 5; i := i + 1)
    {
      ppath_pref := '/' || ppath_pref || path[i];
    }

  to_trim := length (ppath) - length (ppath_pref) - 1;
  lpath_strip := subseq (logical_path, 0, length (logical_path) - to_trim);

  lpath_strip := rtrim (lpath_strip, '/');

  h := sprintf ('http://%s%s', h, lpath_strip);

  gdata_url := BLOG.DBA.GET_HTTP_URL ();
  connection_set ('GData_URI', gdata_url);
  connection_set ('Atom_Self_URI', h);

  set_user_id ('dba');
  set http_charset='utf-8';

  declare exit handler for not found {
    -- XXX:
    return null;
  };

  declare exit handler for sqlstate '*' {
    -- XXX:
    if (__SQL_STATE = 'BLOGV')
      http_request_status ('HTTP/1.1 409 Conflict');
    resignal;
    return null;
  };

  select u.U_NAME, u.U_ID into u_name, u_id from DB.DBA.SYS_USERS u, BLOG..SYS_BLOG_INFO b
      where b.BI_OWNER = u.U_ID and b.BI_BLOG_ID = blogid;

  xt := null;
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

  req := new BLOG.DBA."blogRequest" ();
  req.appkey := 'GData';
  req.blogid := blogid;
  req.postId := id;

  if (meth <> 'GET' and not BLOG..atom_authenticate (req))
    {
      cont := http_body_read ();
      return '';
    }

  hstat := 'HTTP/1.1 200 OK';
  if (meth = 'GET' and q is null and id is null and "updated-min" is null and "updated-max" is null and author is null)
    {
      if ("atom-pub" = 1)
	http_header ('Content-Type: application/atom+xml\r\n');
      else
	http_header ('Content-Type: text/xml; charset=UTF-8\r\n');

      p_path_str := sprintf ('/DAV/home/%s/%s/', u_name, blogid);

      l_path_str := (select top 1 HP_LPATH from DB.DBA.HTTP_PATH where HP_PPATH = p_path_str
      and HP_HOST = vhost and HP_LISTEN_HOST = lhost);

      if (l_path_str is not null)
        full_path := concat (l_path_str, sprintf ('/gems/%s.xml', alt));
      else
	full_path := sprintf ('/DAV/home/%s/%s/gems/%s.xml', u_name, blogid, alt);

      --dbg_printf ('using [%s]', full_path);

      p_full_path := http_physical_path_resolve (full_path, 1);
      http_internal_redirect (full_path, p_full_path);
      --dbg_printf ('Atom_Self_URI=%s', connection_get ('Atom_Self_URI'));
      WS.WS.GET (path, pars, lines);
      return NULL;
    }
  else if (meth = 'GET')
    {
      declare search_pars, outp, d1, d2, cat any;
      if ("atom-pub" = 1)
	http_header ('Content-Type: application/atom+xml\r\n');
      else
	http_header ('Content-Type: text/xml; charset=UTF-8\r\n');

      -- seems the VDs are created w/o trailing slash
      p_path_str := '/DAV/VAD/blog2/public';
      l_path_str := (select top 1 HP_LPATH from DB.DBA.HTTP_PATH where HP_PPATH = p_path_str
      and HP_HOST = vhost and HP_LISTEN_HOST = lhost);

      if (l_path_str is not null)
	full_path := concat (l_path_str, '/search.vspx');
      else
	full_path := '/DAV/VAD/blog2/public/search.vspx';

      p_full_path := http_physical_path_resolve (full_path, 1);
      http_internal_redirect (full_path, p_full_path);

      outp := alt;
      if (alt = 'rss')
	outp := 'xml';

      cat := null;

      if (q is null)
        q := '';

      if (id = '-')
	{
	  -- categories follows
          id := null;
	  if (length (path) > 6)
	    {
	      declare inx, arr, inx1, len, tmp int;
	      len := length (path);
	      cat := '';
	      for (inx := 6; inx < len; inx := inx + 1)
	        {
		  tmp := path [inx];
		  if (length (tmp))
		    {
		      arr := split_and_decode (tmp, 0, '\0\0|');
		      if (length (arr) > 1)
			{
			  cat := cat || ' AND ( ';
			  foreach (any elm in arr) do
			    {
			      if (length (elm) > 1)
			        {
				  if (elm[0] = ascii ('-'))
				    elm := ' NOT ' || substring (elm, 2, length (elm)) || '';
				  cat := cat || ' ' ||  elm || ' OR ' ;
			        }
			    }
			  cat := substring (cat, 1, length (cat) - 4) || ' )';
			}
		      else if (length (tmp) > 1)
			{
			  if (tmp[0] = ascii ('-'))
			    tmp := ' NOT ' || substring (tmp, 2, length (tmp)) || '';
			  cat := cat || ' AND ' || tmp;
			}
		    }
		}
	      if (length (cat))
	        cat := substring (cat, 6, length (cat));
	    }
	  else
	    signal ('22023', 'Category is not specified');
	}
      else if (id = 'intro')
	{
	  http_header ('Content-Type: application/atomserv+xml; charset=UTF-8\r\n');
	  return ATOM.ATOM.intro (blogid);
	};


      search_pars := vector ('q', q, 'output', outp, 'blogid', blogid, 'postid', id,
      			     'cnt', "max-results", 'start-index', "start-index");

      if ("updated-min" is not null)
	{
	  --dbg_obj_print ('updated-min=', "updated-min");
	  search_pars := vector_concat (search_pars, vector ('from', datestring ("updated-min")));
	}
      if ("updated-max" is not null)
	{
	  --dbg_obj_print ('updated-max=', "updated-max");
	  search_pars := vector_concat (search_pars, vector ('to', datestring ("updated-max")));
	}

      if (cat is not null)
	{
	  --dbg_obj_print ('cat=', cat);
	  search_pars := vector_concat (search_pars, vector ('tags', cat, 'tag-is-qry', '1'));
	}

      --dbg_printf ('Atom_Self_URI=%s', connection_get ('Atom_Self_URI'));
      WS.WS.GET (path, search_pars, lines);
      if ("atom-pub" = 1)
	http_header ('Content-Type: application/atom+xml\r\n');
      return NULL;
    }
  else if (meth = 'POST') -- new post
    {
      struct := BLOG..atom_parse_entry (xt);
      id := BLOG..atom_new_entry (struct, req);
      req.postId := id;
      hstat := 'HTTP/1.1 201 Created';
      if ("atom-pub" = 1)
	{
	  http_header (sprintf ('Location: %s/%s/1\r\n', h, id));
	}
      rc := BLOG..atom_serialize_entry (req);
      http (rc);
    }
  else if (meth = 'PUT') -- edit post
    {
      struct := BLOG..atom_parse_entry (xt);
      struct.postid := req.postId;
      BLOG..atom_edit_entry (struct, req, ver);
      if ("atom-pub" <> 1)
	{
	  rc := BLOG..atom_serialize_entry (req);
	  http (rc);
	}
    }
  else if (meth = 'DELETE') -- delete post
    {
      rc := BLOG..atom_delete_entry (req, ver);
      if (rc = 0)
	hstat := 'HTTP/1.1 404 Not Found';
    }
  http_request_status (hstat);
  return NULL;
};

grant execute on gdata to ATOM;
grant execute on intro to ATOM;
grant execute on DB.DBA.XML_URI_GET_STRING_OR_ENT to ATOM;
grant select on WS.WS.SYS_DAV_RES to ATOM;

use BLOG;
