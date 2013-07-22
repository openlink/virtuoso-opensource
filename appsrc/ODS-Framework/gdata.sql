--
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

use DB;

create procedure WA_GDATA_INIT ()
{
  if (exists (select 1 from "DB"."DBA"."SYS_USERS" where U_NAME = 'GDATA_ODS'))
    return;
  DB.DBA.USER_CREATE ('GDATA_ODS', uuid(), vector ('DISABLED', 1, 'LOGIN_QUALIFIER', 'ODS'));
  -- delete old dirs
}
;


WA_GDATA_INIT ();

create procedure ODS_INIT_VHOST ()
{
  declare http_port, default_host, default_port, cname, inet, vhost varchar;
  declare arr, cnt_inet, ext_inet any;

  cname := cfg_item_value (virtuoso_ini_path (), 'URIQA', 'DefaultHost');
  http_port := server_http_port ();

  arr := split_and_decode (cname, 0, '\0\0:');
  cnt_inet := 0;
  if (length (arr) > 1)
    {
      default_host := arr[0];
      default_port := arr[1];
      vhost := default_host;
      inet := ':'||default_port;
    }
  else if (length (arr) = 1)
    {
      default_host := cname;
      default_port := '80';
      vhost := cname;
      inet := ':'||default_port;
    }
  else -- only happens in the testsuite with M2
    inet := ':';
  cnt_inet := (select count(distinct HP_LISTEN_HOST) from HTTP_PATH where HP_LISTEN_HOST like '%'||inet);
  if (cnt_inet = 1)
    {
      ext_inet := (select distinct HP_LISTEN_HOST from HTTP_PATH where HP_LISTEN_HOST like '%'||inet);
      inet := ext_inet;
    }

  DB.DBA.ods_define_common_vd ('*ini*', '*ini*');
  if (cname is not null and default_port <> http_port and cnt_inet < 2)
    {
      DB.DBA.ods_define_common_vd (vhost, inet);
      insert replacing WA_DOMAINS (WD_DOMAIN,WD_HOST,WD_LISTEN_HOST,WD_LPATH,WD_MODEL)
	  values (default_host, vhost, inet, '/ods', 0);
    }
  else if (cname is not null and default_port <> http_port and cnt_inet >= 2)
    {
      log_message ('The DefaultHost has defined two or more listeners, please define the default dataspace virtual directories.');
    }
};

ODS_INIT_VHOST ();

drop procedure ODS_INIT_VHOST;

create procedure WA_SET_HOME_URLS (in do_res int := 0)
{
  declare _WAI_NAME, _HP_HOST, _HP_LPATH, _HP_LISTEN_HOST varchar;
  declare lpath, ppath, DEF_PAGE varchar;
  declare pos, IS_DEFAULT, _WAI_ID int;
  declare http_port, default_host, default_port, cname, inet, vhost varchar;
  declare arr, cnt_inet, ext_inet, h any;
  declare i db.dba.web_app;
  declare vd_pars any;
  declare vd_is_dav, vd_is_browse int;
  declare vd_opts any;
  declare vd_user, vd_pp, vd_auth, phys_path varchar;

  if (registry_get ('__wa_vd_upgrade') = 'done')
    return;

  cname := cfg_item_value (virtuoso_ini_path (), 'URIQA', 'DefaultHost');
  http_port := server_http_port ();

  arr := split_and_decode (cname, 0, '\0\0:');
  cnt_inet := 0;
  if (length (arr) > 1)
    {
      default_host := arr[0];
      default_port := arr[1];
      vhost := arr[0];
      inet := ':'||default_port;
    }
  else if (length (arr) = 1)
    {
      default_host := cname;
      default_port := '80';
      vhost := cname;
      inet := ':'||default_port;
    }
  else -- only happens in the testsuite with M2
    inet := ':';
  cnt_inet := (select count(distinct HP_LISTEN_HOST) from HTTP_PATH where HP_LISTEN_HOST like '%'||inet);
  if (cnt_inet = 1)
    {
      ext_inet := (select distinct HP_LISTEN_HOST from HTTP_PATH where HP_LISTEN_HOST like '%'||inet);
      inet := ext_inet;
    }


  if (do_res)
    result_names (_WAI_NAME, _HP_LPATH);

  if (cname is not null and default_port <> http_port and cnt_inet = 1)
    ;
  else
    {
      if (cname is not null and default_port <> http_port and cnt_inet > 1)
        log_message ('There is more than one listener defined for defaulthost, the upgrade can not be done');
      return;
    }

  for select WAM_HOME_PAGE, WAI_INST, WAM_INST, WAI_ID, WAM_APP_TYPE from WA_MEMBER, WA_INSTANCE
    where WAM_INST = WAI_NAME and WAM_MEMBER_TYPE = 1 and WAM_APP_TYPE <> 'oWiki' do
    {
      pos := strrchr (WAM_HOME_PAGE, '/');
      if (pos is not null)
	{
          lpath := subseq (WAM_HOME_PAGE, 0, pos);
	}
      else
        lpath := WAM_HOME_PAGE;

      if (length (lpath) > 1)
        lpath := rtrim (lpath, '/');

      i := WAI_INST;
      h := udt_implements_method (i, fix_identifier_case ('wa_vhost_options'));
      vd_pars := null;
      if (h)
        vd_pars := call (h) (i);
      if (vd_pars is not null)
        {
          phys_path := vd_pars[0];
          def_page :=  vd_pars[1];
          vd_user :=   vd_pars[2];
          vd_is_browse :=vd_pars[3];
          vd_is_dav := vd_pars[4];
          vd_opts :=   vd_pars[5];
          vd_pp :=     vd_pars[6];
          vd_auth :=   vd_pars[7];
        }

      if (vd_pars is not null and lpath[0] = ascii ('/') and
	  not exists (select 1 from HTTP_PATH where HP_HOST = vhost and HP_LISTEN_HOST = inet and HP_LPATH = lpath))
	{
	  VHOST_DEFINE (
	      vhost=>vhost,
	      lhost=>inet,
	      lpath=>lpath,
	      ppath=>phys_path,
	      def_page=>def_page,
	      vsp_user=>vd_user,
	      is_brws=>vd_is_browse,
	      is_dav=>vd_is_dav,
	      opts=>vd_opts,
	      ppr_fn=>vd_pp,
	      auth_fn=>vd_auth);
	  if (do_res)
	    result (WAM_INST, lpath);
	}
    }
  registry_set ('__wa_vd_upgrade', 'done');
};

WA_SET_HOME_URLS ();

create procedure wa_app_to_type (in app varchar)
{
  return get_keyword (lower (app), vector (
	'weblog',        'WEBLOG2',
	'subscriptions', 'eNews2',
	'wiki',          'oWiki',
	'briefcase',     'oDrive',
	'mail',          'oMail',
	'photos',        'oGallery',
	'community',     'Community',
	'bookmark',      'Bookmark',
	'discussion',    'nntpf',
	'polls',         'Polls',
	'addressbook',   'AddressBook',
	'socialnetwork', 'AddressBook',
	'calendar',      'Calendar'
	), app);
};

create procedure wa_type_to_app (in app varchar)
{
  return get_keyword (app, vector (
	'WEBLOG2',       'weblog',
	'eNews2',        'subscriptions',
	'oWiki',         'wiki',
	'oDrive',        'briefcase',
	'oMail',         'mail',
	'oGallery',      'photos',
	'Community',     'community',
	'Bookmark',      'bookmark',
	'nntpf',         'discussion',
	'Polls',         'polls',
	'AddressBook',   'addressbook',
	'SocialNetwork', 'socialnetwork',
	'Calendar',      'calendar'
	), app);
};

create procedure wa_type_to_appg (in app varchar)
{
  return get_keyword (app, vector (
	'WEBLOG2',       'Weblogs',
	'eNews2',        'Subscriptions',
	'oWiki',         'Wikis',
	'oDrive',        'Briefcases',
	'oMail',         'Mailboxes',
	'oGallery',      'Galleries',
	'Community',     'Communities',
	'Bookmark',      'Bookmarks',
	'nntpf',         'Discussions',
	'addressbook',   'AddressBooks',
	'socialnetwork', 'AddressBooks',
	'calendar',      'Calendar'
	), app);
};


use ODS;

create procedure ODS.ODS.redirect (in p int := null)  __SOAP_HTTP 'text/html'
{
  declare ppath varchar;
  declare path, pars, lines any;
  declare app, uname, inst, url, appn, post varchar;
  declare vhost, lhost, p_path_str, full_path, p_full_path, l_path_str, gdata_url, accept varchar;
  declare id, do_rdf, do_sioc, is_foaf, has_accept int;
  declare sioc_fmt, ct, cn varchar;

  lines := http_request_header ();
  ppath := http_physical_path ();

  -- the ods person iri going to same place as user iri
  if (ppath like '/SOAP/Http/redirect/person/%')
    ppath := '/SOAP/Http/redirect/' || substring (ppath, 28, length (ppath));
  path := split_and_decode (ppath, 0, '\0\0/');

  accept := http_request_header (lines, 'Accept');
  if (not isstring (accept))
    accept := '';

  vhost := http_map_get ('vhost');
  lhost := http_map_get ('lhost');

  app := null;
  uname := null;
  inst := null;
  post := null;
  do_rdf := 0;
  is_foaf := 0;
  has_accept := 0;
  sioc_fmt := 'RDF/XML';
  ct := 'application/rdf+xml';
  cn := null;

  -- autodetection of the content
  if (length (path) > 3 and regexp_match ('(application|text)/rdf.(xml|n3|turtle|ttl)', accept) is not null)
    {
      declare len int;
      declare newres, pref varchar;

      if (length (path) > 6 or strrchr (ppath,'#') is not null)
	pref := 'sioc';  -- for apps the default is sioc
      else
        pref := 'about'; -- for user it's foaf file

      newres := pref || '.rdf';
      if (regexp_match ('application/rdf.xml', accept) is not null)
	{
	  has_accept := 1;
	  newres := pref || '.rdf';
	}
      else if (regexp_match ('text/rdf.n3', accept) is not null)
	{
	  has_accept := 1;
	  newres := pref || '.n3';
	}
      else if (
	    regexp_match ('application/rdf.turtle', accept) is not null or
	    regexp_match ('application/rdf.ttl', accept) is not null
	  )
	{
	  has_accept := 1;
	  newres := pref || '.ttl';
	}

      len := length (path);
      -- XXX: may be below we should have AND has_accept
      if (path[len-1] not like '%.rdf' and path[len-1] not like '%.ttl')
	{
	  cn := newres;
	  if (path[len-1] = '')
	    {
	      path[len-1] := newres;
	      ppath := ppath || newres;
	    }
	  else
	    {
	      path := vector_concat (path, vector (newres));
	      ppath := ppath || '/' || newres;
	    }
	}
    }

  -- set the format requested
  if (ppath like '%/%.ttl')
    {
      ct := 'application/rdf+turtle';
      sioc_fmt := 'TTL';
    }
  else if (ppath like '%/%.n3')
    {
      ct := 'text/rdf+n3';
      sioc_fmt := 'TTL';
    }

  if (not has_accept)
    ct := 'text/xml';

  if (not has_accept and (ppath like '%/%.ttl' or ppath like '%/%.n3'))
    ct := 'text/plain';

  if (ppath like '%/foaf.%')
    {
      is_foaf := 1;
      do_sioc := 1;
    }


  if (length (path) > 4)
    uname := path [4];
  else
    {
      url := '/ods/sfront.vspx';
      goto redir;
    }

  -- The FOAF for the whole ODS
  if (uname = 'about.rdf')
    {
      declare ses any;
      ses := sioc..sioc_compose_xml (null, null, null, null, p, sioc_fmt, is_foaf);
      http (ses);
      http_header (sprintf ('Content-Type: %s; charset=UTF-8\r\n', ct));
      return '';
    }

  if (length (path) > 5)
    app := path [5];

  if (length (path) > 6)
    inst := path [6];

-- obsolete
--  if (length (path) > 7 and path[5] = 'data' and path[6] = 'public' and path[7] = 'about.rdf')
--    app := 'users';

  -- Yadis document
  if (app = 'yadis.xrds' and inst is null)
    {
      http_header ('Content-Type: application/xrds+xml; charset=UTF-8\r\n');
      OPENID..yadis (uname);
      return '';
    }

  if (app like '%.rdf' or app like '%.ttl' or app like '%.n3') -- user's sioc/about file is requested
    {
      -- in both cases we do via sparql construct
      if (app like 'sioc.%' or app like 'about.%')
	do_sioc := 1;
      if (app like 'about.%')
        is_foaf := 1;
      app := 'users';
    }

  if (uname = 'feed' or uname = 'discussion')
    {
      post := inst;
      inst := app;
      app := uname;
      if (post like 'sioc.%')
	{
	  do_sioc := 1;
	  post := null;
	}
      uname := 'nobody';
    }

  -- here it goes for all sioc or accepts rdf
  -- the old code below for calling sioc..sioc_compose_xml or sioc..ods_rdf_describe
  -- also the sioc..sioc_compose_xml should be cleaned
  if ((has_accept or ppath like '%/sioc.%') and not is_foaf)
    {
	 declare ses, iri any;
	 iri := http_path ();
	 if (iri like '%/sioc.%')
	   {
	     iri := subseq (iri, 0, strrchr (iri, '/'));
	   }
	 iri := replace (iri, '''', '%27');
	 iri := replace (iri, '<', '%3C');
	 iri := replace (iri, '>', '%3E');
         ses := sioc..ods_rdf_describe (iri, sioc_fmt, is_foaf);
	 http_header (sprintf ('Content-Type: %s; charset=UTF-8\r\n', ct));
	 http (ses);
	 return '';
    }
  if (length (app) and app not in
      ('subscriptions','weblog','wiki','briefcase','mail','bookmark', 'photos', 'community', 'discussion', 'users', 'feed','feeds', 'sparql', 'polls', 'addressbook', 'socialnetwork', 'calendar','addressbook','im'))
   {
     if (has_accept)
       {
	 declare ses any;
         ses := sioc..ods_rdf_describe (http_path (), sioc_fmt, is_foaf);
	 http_header (sprintf ('Content-Type: %s; charset=UTF-8\r\n', ct));
	 http (ses);
	 return '';
       }
     else
       signal ('22023', sprintf ('Invalid application domain [%s].', app));
   }

  if (app = 'sparql' and length (inst) = 0)
    signal ('22023', sprintf ('Invalid application domain [%s].', app));

  if (length (uname) = 0)
    signal ('22023', 'Account is not specified.');

  -- if an instance name is detected, try to locate post and rdf resource which is requested
  if (app <> 'users' and length (inst) and length (path) > 7)
    {
      if (path[7] like 'about.%')
        do_rdf := 1;
      else if (path[7] like 'sioc.%')
	do_sioc := 1;
      else if (length (path) > 8 and path[8] like 'sioc.%')
	{
	  post := path[7];
	  do_sioc := 1;
	}
      else if (length (path) > 9 and path[9] like 'sioc.%')
	{
	  post := path[7]||'/'||path[8];
	  do_sioc := 1;
	}
      else
	 post := path[7];
    }

  -- some kludge for wiki
  if (not (do_rdf or do_sioc) and app = 'wiki' and length(path) > 7)
    post := path[6] || '/' || path[7];

  -- user's about/sioc.rdf
  if (app = 'users' or (app is not null and (inst like 'about.%' or inst like 'sioc.%')))
    {
      declare atype, foaf varchar;

      foaf := 'ufoaf.xml';
      uname := path[4];

      if (app is not null and inst = 'about.rdf')
	{
	  select sne_id into id from DB.DBA.sn_entity where sne_name = uname;
	  foaf := 'afoaf.xml';
	  pars := vector (':sne', cast (id as varchar), ':atype', DB.DBA.wa_app_to_type (app));
	}
      else if (do_sioc or (app is not null and inst like 'sioc.%'))
	{
	  declare ses any;
	  ses := sioc..sioc_compose_xml (uname, null, app, null, p, sioc_fmt, is_foaf);
          http (ses);
	  http_header (sprintf ('Content-Type: %s; charset=UTF-8\r\n', ct));
	  if (cn is not null)
	    http_header (http_header_get () || sprintf ('Content-Location: %s\r\n', cn));

	  return '';
	}
      else
	pars := vector (':sne', cast (id as varchar));

      -- old behaviour, should never come here
      signal ('22023', 'No such resource.');

      p_path_str := '/DAV/VAD/wa/';
      l_path_str := (select top 1 HP_LPATH from DB.DBA.HTTP_PATH where HP_PPATH = p_path_str
      and HP_HOST = vhost and HP_LISTEN_HOST = lhost);

      if (l_path_str is not null)
	full_path := concat (l_path_str, '/', foaf);
      else
	full_path := '/DAV/VAD/wa/' || foaf;

      p_full_path := http_physical_path_resolve (full_path, 1);
      http_internal_redirect (full_path, p_full_path);
      set_user_id ('dba');
      set http_charset='utf-8';
      http_header ('Content-Type: text/xml; charset=UTF-8\r\n');
      WS.WS.GET (path, pars, lines);
      return null;
    }

  pars := vector ();

  appn := DB.DBA.wa_app_to_type (app);

  -- user home page
  if (length (app) = 0)
    {
      -- old behaviour
      --url := DB.DBA.wa_link (1,  sprintf ('uhome.vspx?page=1&ufname=%U', uname));

      p_path_str := '/DAV/VAD/wa/';
      l_path_str := (select top 1 HP_LPATH from DB.DBA.HTTP_PATH where HP_PPATH = p_path_str
      and HP_HOST = vhost and HP_LISTEN_HOST = lhost);

      if (l_path_str is not null)
	full_path := concat (l_path_str, '/uhome.vspx');
      else
	full_path := '/DAV/VAD/wa/uhome.vspx';

      p_full_path := http_physical_path_resolve (full_path, 1);
      http_internal_redirect (full_path, p_full_path);
      set_user_id ('dba');
      set http_charset='utf-8';
      pars := vector_concat (http_param (), vector ('page', '1', 'ufname', uname));
      WS.WS.GET (path, pars, lines);
      http_header (http_header_get ()||sprintf ('X-XRDS-Location: %s\r\n', DB.DBA.wa_link (1, '/dataspace/'||uname||'/yadis.xrds')));
      return null;
    }
  else if (length (inst) = 0) -- app instance page
    {
      url := DB.DBA.wa_link (0, sprintf ('app_inst.vspx?app=%U&ufname=%U', appn, uname));
    }
  else
    {
      declare _inst DB.DBA.web_app;
      declare inst_type varchar;
      declare exit handler for not found
	{
	  if (has_accept and __SQL_STATE = 100)
	    {
	      declare ses any;
	      ses := sioc..ods_rdf_describe (http_path (), sioc_fmt, is_foaf);
	      http_header (sprintf ('Content-Type: %s; charset=UTF-8\r\n', ct));
	      http (ses);
	      return '';
	    }
	  else
	    signal ('22023', 'No such application instance');
	};
      inst := replace (inst, '+', ' ');
      _inst := null;
      url := null;

      if (app in ('discussion', 'feed') and do_sioc)
	{
	  inst_type := app;
	  goto nntpf;
	}
      if (app in ('discussion', 'feed') and post is not null)
	goto do_post;
      -- the stored SPARQL queries
      if (app = 'sparql')
	{
	  declare content, mime, rc, pwd, rid any;

	  declare exit handler for not found {
	    http_request_status ('HTTP/1.1 404 Not found');
	    return;
	  };
	  pwd := (select pwd_magic_calc (U_NAME, U_PASSWORD, 1) from DB.DBA.SYS_USERS where U_NAME = uname);
	  rid := DB.DBA.DAV_SEARCH_ID ('/DAV/home/' || uname || '/SPARQL/' || inst, 'R');
	  rc := DB.DBA.DAV_AUTHENTICATE (rid, 'R', '1__', uname, pwd);
	  if (rc < 0)
	    {
	      http_request_status ('HTTP/1.1 403 Prohibited');
	      signal ('22023', 'Access is not permitted');
	    }
	  select RES_CONTENT, RES_TYPE into content, mime from WS.WS.SYS_DAV_RES where RES_ID = rid;
	  http_header (sprintf ('Content-Type: %s\r\n', mime));
	  http (content);
	  return '';
	}

      select WAM_HOME_PAGE, WAI_INST, WAI_TYPE_NAME into url, _inst, inst_type
	  from DB.DBA.WA_MEMBER, DB.DBA.SYS_USERS, DB.DBA.WA_INSTANCE where
	  U_NAME = uname and WAM_USER = U_ID and WAI_NAME = WAM_INST and WAM_INST = inst;

      -- instance's about.rdf
      if (do_rdf)
	{
	  declare npars, hf any;
	  --dbg_obj_print ('RDF');
	  full_path := _inst.wa_rdf_url (vhost, lhost);
	  if (full_path is null)
	    {
	      if (has_accept)
		{
		  declare ses any;
		  ses := sioc..ods_rdf_describe (http_path (), sioc_fmt, is_foaf);
		  http_header (sprintf ('Content-Type: %s; charset=UTF-8\r\n', ct));
		  http (ses);
		  return '';
		}
	      signal ('22023', 'Not implemented');
	    }

	  hf := WS.WS.PARSE_URI (full_path);
	  full_path := hf[2];
	  npars := hf[4];

	  if (length (npars))
	    pars := split_and_decode (npars);

	  p_full_path := http_physical_path_resolve (full_path, 1);
	  http_internal_redirect (full_path, p_full_path);
	  set_user_id ('dba');
	  set http_charset='utf-8';
	  http_header ('Content-Type: text/xml; charset=UTF-8\r\n');
	  if (p_full_path like '/DAV/%')
	    WS.WS.GET (path, pars, lines);
	  else
	    WS.WS."DEFAULT" (path, pars, lines);
	  return null;
	}
      else if (do_sioc) -- instance or post's sioc.rdf
        {
	  nntpf:
	  declare ses any;
	  ses := sioc..sioc_compose_xml (uname, inst, inst_type, post, p, sioc_fmt, is_foaf);
          http (ses);
	  http_header (sprintf ('Content-Type: %s; charset=UTF-8\r\n', ct));
	  if (cn is not null)
	    http_header (http_header_get () || sprintf ('Content-Location: %s\r\n', cn));
	  return '';
        }
      else if (post is not null)
	{
	  do_post:
	  if (_inst is not null)
	    url := _inst.wa_post_url (vhost, lhost, inst, post);
	  else if (__proc_exists ('sioc..'||app||'_post_url'))
	    url := call ('sioc..'||app||'_post_url') (vhost, lhost, inst, post);
	  if (url is null)
	    {
	      if (has_accept)
		{
		  declare ses any;
		  ses := sioc..ods_rdf_describe (http_path (), sioc_fmt, is_foaf);
		  http_header (sprintf ('Content-Type: %s; charset=UTF-8\r\n', ct));
		  http (ses);
		  return '';
		}
	      signal ('22023', 'Not implemented');
	    }
	}
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

  h := DB.DBA.WA_CNAME ();
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
	  if (length (ap) and ap not in ('people','subscriptions','weblog','wiki','dav','mail','apps', 'users', 'bookmark', 'discussion','addressbook','polls','photos','calendar','im','feeds'))
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
			  if (strchr (tmp, '.') is not null)
			     tmp := '"'||tmp||'"';
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

