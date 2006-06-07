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

use DB;

create procedure WA_GDATA_INIT ()
{
  if (exists (select 1 from "DB"."DBA"."SYS_USERS" where U_NAME = 'GDATA_ODS'))
    return;
  DB.DBA.USER_CREATE ('GDATA_ODS', uuid(), vector ('DISABLED', 1, 'LOGIN_QUALIFIER', 'ODS'));
  -- delete old dirs
}
;

DB.DBA.VHOST_REMOVE (lpath=>'/dataspace');
DB.DBA.VHOST_DEFINE (lpath=>'/dataspace', ppath=>'/SOAP/Http/redirect', soap_user=>'GDATA_ODS');

DB.DBA.VHOST_REMOVE (lpath=>'/dataspaces/GData');
DB.DBA.VHOST_DEFINE (lpath=>'/dataspaces/GData', ppath=>'/SOAP/Http/gdata', soap_user=>'GDATA_ODS');

WA_GDATA_INIT ()
;

create procedure wa_app_to_type (in app varchar)
{
  return get_keyword (lower (app), vector (
	'weblog','WEBLOG2',
	'feeds','eNews2',
	'wiki','oWiki',
	'briefcase','oDrive',
	'mail','oMail',
	'photos','oGallery',
	'community','community',
	'bookmark','bookmark',
	'new','nntpf'
	), app);
};

create procedure wa_type_to_app (in app varchar)
{
  return get_keyword (app, vector (
	'WEBLOG2', 'weblog',
	'eNews2',  'feeds',
	'oWiki',   'wiki',
	'oDrive',  'briefcase',
	'oMail',   'mail',
	'oGallery','photos',
	'Community','community',
	'Bookmark','bookmark',
	'nntpf',    'new'
	), app);
};


use ODS;

create procedure ODS.ODS.redirect ()  __SOAP_HTTP 'text/html'
{
  declare ppath varchar;
  declare path, pars, lines any;
  declare app, uname, inst, url, appn varchar;
  declare vhost, lhost, p_path_str, full_path, p_full_path, l_path_str, gdata_url varchar;
  declare id int;

  lines := http_request_header ();
  ppath := http_physical_path ();
  path := split_and_decode (ppath, 0, '\0\0/');

  vhost := http_map_get ('vhost');
  lhost := http_map_get ('lhost');

  app := null;
  uname := null;
  inst := null;


  if (length (path) > 4)
    uname := path [4];

  if (length (path) > 5)
    app := path [5];

  if (length (path) > 7 and path[5] = 'data' and path[6] = 'public' and path[7] = 'about.rdf')
    app := 'users';

  if (length (app) and app not in ('feeds','weblog','wiki','briefcase','mail','bookmark', 'photos', 'community', 'news', 'users'))
   {
     signal ('22023', sprintf ('Invalid application domain [%s].', app));
   }

  if (length (uname) = 0)
    signal ('22023', 'Account is not specified.');

  if (app = 'users')
   {
      uname := path[4];
      select sne_id into id from DB.DBA.sn_entity where sne_name = uname;
      pars := vector (':sne', cast (id as varchar));

      p_path_str := '/DAV/VAD/wa';
      l_path_str := (select top 1 HP_LPATH from DB.DBA.HTTP_PATH where HP_PPATH = p_path_str
      and HP_HOST = vhost and HP_LISTEN_HOST = lhost);

      if (l_path_str is not null)
	full_path := concat (l_path_str, '/ufoaf.xml');
      else
	full_path := '/DAV/VAD/wa/ufoaf.xml';

      p_full_path := http_physical_path_resolve (full_path, 1);
      http_internal_redirect (full_path, p_full_path);
      set_user_id ('dba');
      set http_charset='utf-8';
      http_header ('Content-Type: text/xml; charset=UTF-8\r\n');
      WS.WS.GET (path, pars, lines);
      return null;
   }

  appn := DB.DBA.wa_app_to_type (app);


  if (length (path) > 6)
    inst := path [6];
  if (length (app) = 0)
    {
      url := DB.DBA.wa_link (0,  sprintf ('uhome.vspx?page=1&ufname=%U', uname));
    }
  else if (length (inst) = 0)
    {
      url := DB.DBA.wa_link (0, sprintf ('app_inst.vspx?app=%U&ufname=%U', appn, uname));
    }
  else
    {
      declare exit handler for not found
	{
	  signal ('22023', 'No such application instance');
	};
      select WAM_HOME_PAGE into url from DB.DBA.WA_MEMBER, DB.DBA.SYS_USERS where
	  U_NAME = uname and WAM_USER = U_ID and WAM_INST = inst;
    }
redir:
  http_request_status ('HTTP/1.1 302 Found');
  http_header (sprintf ('Location: %s\n', url));
  return null;
};

create procedure ODS.ODS.gdata
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
  declare path, lpath, ppath, cont, rc, opts any;
  declare pars, lines any;
  declare meth, ppath_pref, lpath_strip, logical_path varchar;
  declare to_trim int;
  declare full_path, p_full_path, ct, id varchar;
  declare title, content, author_name, author_mail, hstat, h, ret_hdr varchar;
  declare i, tag_inx int;
  declare vhost, lhost, p_path_str, l_path_str, gdata_url varchar;
  declare app varchar;

  opts := http_map_get ('options');
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
--  dbg_printf ('meth=[%s] path=[%s]', meth, http_path ());
  path := split_and_decode (ppath, 0, '\0\0/');

  app := null;
  id := null;

  if (length (path) > 4 and path [4] <> '-')
    app := path [4];

  tag_inx := 6;
  if (length (path) > 5 and path [5] <> '')
    id := path [5];
  if (length (path) > 4 and path [4] = '-')
    {
      id := path [4];
      tag_inx := 5;
    }

  if (app is not null)
    {
      declare aarr any;
      aarr := split_and_decode (app, 0, '\0\0,');
      foreach (any ap in aarr) do
	{
	  if (length (ap) and ap not in ('people','feeds','weblog','wiki','dav','mail','apps', 'users', 'bookmark'))
	    {
	      http_header ('Content-Type: text/html\r\n');
              signal ('22023', 'Invalid application domain');
	    }
	}
    }

  ppath_pref := '';
  for (i := 1; i < 4; i := i + 1)
    {
      ppath_pref := '/' || ppath_pref || path[i];
    }

  to_trim := length (ppath) - length (ppath_pref) - 1;
  lpath_strip := subseq (logical_path, 0, length (logical_path) - to_trim);

  lpath_strip := rtrim (lpath_strip, '/');

  h := sprintf ('http://%s%s', h, lpath_strip);

  gdata_url := DB.DBA.WA_XPATH_GET_HTTP_URL ();
  connection_set ('GData_URI', gdata_url);
  connection_set ('Atom_Self_URI', h);

  set_user_id ('dba');
  set http_charset='utf-8';

  declare exit handler for not found {
    -- XXX:
    return null;
  };

  hstat := 'HTTP/1.1 200 OK';
  if (meth <> 'GET')
    {
      cont := http_body_read ();
      hstat := 'HTTP/1.1 403 Forbidden';
    }
  else if (meth = 'GET')
    {
      declare search_pars, outp, d1, d2, cat any;
      http_header ('Content-Type: text/xml; charset=UTF-8\r\n');

      -- seems the VDs are created w/o trailing slash
      p_path_str := '/DAV/VAD/wa';
      l_path_str := (select top 1 HP_LPATH from DB.DBA.HTTP_PATH where HP_PPATH = p_path_str
      and HP_HOST = vhost and HP_LISTEN_HOST = lhost);

      if (l_path_str is not null)
	full_path := concat (l_path_str, '/search.vspx');
      else
	full_path := '/DAV/VAD/wa/search.vspx';

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
	  if (length (path) > tag_inx)
	    {
	      declare inx, arr, inx1, len, tmp int;
	      len := length (path);
	      cat := '';
	      for (inx := tag_inx; inx < len; inx := inx + 1)
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

      if (app = 'users')
	search_pars := vector ('user_search', 'Search', 'page', '2', 'us_keywords', q, 'o', outp, 'us_max_rows', cast ("max-results" as varchar), 'start-index', "start-index", 'author', author);
      else
	search_pars := vector ('q', q, 'o', outp, 'apps', app, 'r', "max-results", 'start-index', "start-index", 'author', author);

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
	  search_pars := vector_concat (search_pars, vector ('q_tags', cat, 'tag-is-qry', '1'));
	}

      --dbg_printf ('Atom_Self_URI=%s', connection_get ('Atom_Self_URI'));
      WS.WS.GET (path, search_pars, lines);
    }
  ret_hdr := http_header_get ();
  if (strstr (ret_hdr, 'error.vspx') is not null)
    {
      declare tmp any;
      tmp := split_and_decode (ret_hdr);
      hstat := 'HTTP/1.1 500 Server Error';
      http_header ('Content-Type: text/plain\r\n');
      http (get_keyword ('__SQL_MESSAGE', tmp, ''));
    }
  http_request_status (hstat);
  return NULL;
};

grant execute on gdata to GDATA_ODS;
grant execute on redirect to GDATA_ODS;
grant execute on DB.DBA.XML_URI_GET_STRING_OR_ENT to GDATA_ODS;
grant select on WS.WS.SYS_DAV_RES to GDATA_ODS;

use DB;

create procedure WA_IS_REGULAR_FEED ()
{
  if (connection_get ('Atom_Self_URI') is null)
    return 1;
  return 0;
};

grant execute on WA_IS_REGULAR_FEED to public;

xpf_extension ('http://www.openlinksw.com/ods/:isRegularFeed', 'DB.DBA.WA_IS_REGULAR_FEED');

