create procedure DB.DBA.URL_REW_ODS_ACCEPT ()
{
  declare accept, ret any;
  accept := http_request_header (http_request_header (), 'Accept');
  if (not isstring (accept))
    return null;
  ret := null;
  if (regexp_match ('(application|text)/rdf.(xml|n3|turtle|ttl)', accept) is not null)
    {
      if (regexp_match ('application/rdf.xml', accept) is not null)
	{
	  ret := 'rdf';
	}
      else if (regexp_match ('text/rdf.n3', accept) is not null)
	{
	  ret := 'n3';
	}
      else if (regexp_match ('application/rdf.turtle', accept) is not null or
	    regexp_match ('application/rdf.ttl', accept) is not null)
	{
	  ret := 'n3';
	}
    }
  return ret;
};

create procedure  DB.DBA.URL_REW_ODS_SPQ (in graph varchar, in iri varchar, in acc varchar)
{
  declare q, ret any;
  iri := replace (iri, '''', '%27');
  iri := replace (iri, '<', '%3C');
  iri := replace (iri, '>', '%3E');
  q := sprintf ('define input:inference <%s> DESCRIBE <%s> FROM <%s>', graph, iri, graph);
  ret := sprintf ('/sparql?query=%U&format=%U', q, acc);
  return ret;
};

create procedure DB.DBA.URL_REW_ODS_USER (in par varchar, in fmt varchar, in val varchar)
{
--  dbg_obj_print (current_proc_name ());
  declare acc, ret any;
  declare q, iri, graph any;

  acc := DB.DBA.URL_REW_ODS_ACCEPT ();
  if (acc is not null)
    {
      graph := sioc..get_graph ();
      iri := sprintf ('%s/%U', graph, val);
      if (val like 'person/%')
	{
	  val := substring (val, 8, length (val));
	  ret := sprintf ('/ods/foaf.vsp?uname=%U&fmt=%U', val, acc);
	}
      else
      ret := DB.DBA.URL_REW_ODS_SPQ (graph, iri, acc);
    }
  else
    {
      http_header (http_header_get ()||sprintf ('X-XRDS-Location: %s\r\n',
	    DB.DBA.wa_link (1, '/dataspace/'||val||'/yadis.xrds')));

      if (val like 'person/%')
	val := substring (val, 8, length (val));
      ret := sprintf ('/ods/uhome.vspx?page=1&ufname=%s', val);
    }
  return ret;
};

create procedure DB.DBA.URL_REW_ODS_USER_GEM (in par varchar, in fmt varchar, in val varchar)
{
--  dbg_obj_print (current_proc_name ());
  declare acc, ret any;
  declare q, iri, graph, path, is_person any;

  path := http_path ();
  if (path like '%.rdf')
    acc := 'rdf';
  else if (path like '%.n3')
    acc := 'n3';
  else if (path like '%.ttl')
    acc := 'n3';
  else if (path like '%/yadis.xrds')
    acc := 'yadis';
  else
    acc := 'rdf';

  if (acc <> 'yadis')
    {
      is_person := matches_like (path, '%/about.%');
      graph := sioc..get_graph ();
      if (is_person)
	{
          --iri := sprintf ('%s/person/%U', graph, val);
	  ret := sprintf ('/ods/foaf.vsp?uname=%U&fmt=%U', val, acc);
	}
      else
	{
        iri := sprintf ('%s/%U', graph, val);
      ret := DB.DBA.URL_REW_ODS_SPQ (graph, iri, acc);
    }
    }
  else
    {
      ret := sprintf ('/ods/yadis.vsp?uname=%U', val);
    }
  return ret;
};

create procedure DB.DBA.URL_REW_ODS_GEM (in par varchar, in fmt varchar, in val varchar)
{
--  dbg_obj_print (current_proc_name ());
  declare acc, ret any;
  declare q, iri, graph, path, pos any;

  path := http_path ();
  if (path like '%.rdf')
    acc := 'rdf';
  else if (path like '%.n3')
    acc := 'n3';
  else if (path like '%.ttl')
    acc := 'n3';
  else
    acc := 'rdf';
  graph := sioc..get_graph ();
  pos := strrchr (path, '/');
  path := subseq (path, 0, pos);

  if (val = 'person')
    {
      pos := strrchr (path, '/');
      val := subseq (path, pos+1, length (path));
      ret := sprintf ('/ods/foaf.vsp?uname=%U&fmt=%U', val, acc);
    }
  else
    {
  iri := sprintf ('http://%s%s', sioc..get_cname (), path);
  ret := DB.DBA.URL_REW_ODS_SPQ (graph, iri, acc);
    }
  return ret;
};


create procedure DB.DBA.URL_REW_ODS_APP (in par varchar, in fmt varchar, in val varchar)
{
--  dbg_obj_print (current_proc_name (), val);
  if (par = 'app')
    return sprintf (fmt, wa_app_to_type (val));
  return sprintf (fmt, val);
};

create procedure DB.DBA.URL_REW_ODS_BLOG (in par varchar, in fmt varchar, in val varchar)
{
--  dbg_obj_print (par, fmt, val);
--  dbg_obj_print (current_proc_name (), val);
  declare acc, ret any;

  acc := DB.DBA.URL_REW_ODS_ACCEPT ();
  if (acc is not null)
    {
      if (par = 'inst')
	{
          declare q, iri, graph any;
          graph := sioc..get_graph ();
          iri := 'http://' || sioc..get_cname () || http_path ();
          ret := DB.DBA.URL_REW_ODS_SPQ (graph, iri, acc);
          return ret;
	}
      else
	return '';
    }
  else if (par = 'inst')
    {
      declare url any;
      val := split_and_decode (val)[0];
      url := (select WAM_HOME_PAGE from WA_MEMBER where WAM_INST = val and WAM_MEMBER_TYPE = 1);
      if (url is not null)
        val := url;
      return sprintf (fmt, val);
    }
  else if (par = 'id' and val <> '')
    {
      if (atoi (val) = 0 and val <> '0')
	fmt := '%s';
      else
        fmt := '?id=%s';
      return sprintf (fmt, val);
    }
};

create procedure DB.DBA.URL_REW_ODS_NNTP (in par varchar, in fmt varchar, in val varchar)
{
--  dbg_obj_print (par, fmt, val);
--  dbg_obj_print (current_proc_name (), val);
  declare acc, ret any;

  acc := DB.DBA.URL_REW_ODS_ACCEPT ();
  if (acc is not null)
    {
       declare q, iri, graph any;
       graph := sioc..get_graph ();
       iri := 'http://' || sioc..get_cname () || http_path ();
--       dbg_obj_print (iri);
       ret := DB.DBA.URL_REW_ODS_SPQ (graph, iri, acc);
       return ret;
    }
  else if (par = 'grp')
    {
      declare gid int;
      val := split_and_decode (val)[0];
      gid := (select NG_GROUP from DB.DBA.NEWS_GROUPS where NG_NAME = val);
      ret := sprintf ('/nntpf/nntpf_nthread_view.vspx?group=%d', gid);
      return ret;
    }
  else if (par = 'post')
    {
      ret := sprintf ('/nntpf/nntpf_disp_article.vspx?id=%U', encode_base64 (val));
      return ret;
    }
}
;

create procedure DB.DBA.URL_REW_ODS_XD (in par varchar, in fmt varchar, in val varchar)
{
--  dbg_obj_print (par, fmt, val);
--  dbg_obj_print (current_proc_name (), val);
  declare acc, ret any;

  acc := DB.DBA.URL_REW_ODS_ACCEPT ();
  if (acc is not null)
    {
       declare q, iri, graph any;
       graph := sioc..get_graph ();
       iri := 'http://' || sioc..get_cname () || http_path ();
--       dbg_obj_print (iri);
       ret := DB.DBA.URL_REW_ODS_SPQ (graph, iri, acc);
       return ret;
    }
  else if (par = 'inst')
    {
      val := split_and_decode (val)[0];
      ret := (select WAM_HOME_PAGE from WA_MEMBER where WAM_INST = val and WAM_MEMBER_TYPE = 1);
      return ret;
    }
}
;

create procedure DB.DBA.URL_REW_ODS_WIKI (in par varchar, in fmt varchar, in val varchar)
{
--  dbg_obj_print (par, fmt, val);
--  dbg_obj_print (current_proc_name (), val);
  declare acc, ret any;

  acc := DB.DBA.URL_REW_ODS_ACCEPT ();
  if (acc is not null)
    {
       declare q, iri, graph any;
       graph := sioc..get_graph ();
       iri := 'http://' || sioc..get_cname () || http_path ();
--       dbg_obj_print (iri);
       ret := DB.DBA.URL_REW_ODS_SPQ (graph, iri, acc);
       return ret;
    }
  else if (par = 'inst')
    {
      declare _inst DB.DBA.web_app;
      _inst := (select WAI_INST from WA_INSTANCE where WAI_NAME = val);
      ret := _inst.wa_post_url (null, null, val, val);
--      dbg_obj_print ('ret', ret);
      return ret;
    }
  else if (par = 'post')
    {
      return '/'||val;
    }
}
;

create procedure DB.DBA.URL_REW_ODS_PHOTO (in par varchar, in fmt varchar, in val varchar)
{
--  dbg_obj_print (par, fmt, val);
--  dbg_obj_print (current_proc_name (), val);
  declare acc, ret any;

  acc := DB.DBA.URL_REW_ODS_ACCEPT ();
  if (acc is not null)
    {
       declare q, iri, graph any;
       graph := sioc..get_graph ();
       iri := 'http://' || sioc..get_cname () || http_path ();
--       dbg_obj_print (iri);
       ret := DB.DBA.URL_REW_ODS_SPQ (graph, iri, acc);
       return ret;
    }
  else if (par = 'inst')
    {
      val := split_and_decode (val)[0];
      ret := (select WAM_HOME_PAGE from WA_MEMBER where WAM_INST = val and WAM_MEMBER_TYPE = 1);
      return ret;
    }
  else if (par = 'post')
    {
      declare id int;
      declare col, nam varchar;
      declare exit handler for not found
	{
	  signal ('22023', sprintf ('The resource %d doesn''t exists', id));
	};
      id := atoi(ltrim(val, '/'));
      select RES_FULL_PATH into nam from WS.WS.SYS_DAV_RES where RES_ID = id;
      return nam;
    }
}
;

create procedure DB.DBA.URL_REW_ODS_ADDRESSBOOK (in par varchar, in fmt varchar, in val varchar)
{
  declare acc, ret any;

  acc := DB.DBA.URL_REW_ODS_ACCEPT ();
  if (acc is not null)
    {
      if (par = 'instance')
      	{
          declare q, iri, graph any;
          graph := sioc..get_graph ();
          iri := 'http://' || sioc..get_cname () || http_path ();
          ret := DB.DBA.URL_REW_ODS_SPQ (graph, iri, acc);
          return ret;
	      }
      else
	      return '';
    }
  else if (par = 'instance')
    {
      declare id, url any;
      val := split_and_decode (val)[0];
      id := AB.WA.domain_id (val);
      if (id is not null) {
        url := AB.WA.ab_url (id);
        if (url is not null)
          val := url;
      }
      return sprintf (fmt, val);
    }
  else if (par = 'params')
    {
      if (atoi (val) = 0 and val <> '0')
       	fmt := '%s';
      else
        fmt := '?id=%s';
      return sprintf (fmt, val);
    }
}
;

create procedure DB.DBA.URL_REW_ODS_BOOKMARK (in par varchar, in fmt varchar, in val varchar)
{
  declare acc, ret any;

  acc := DB.DBA.URL_REW_ODS_ACCEPT ();
  if (acc is not null)
    {
      if (par = 'instance')
      	{
          declare q, iri, graph any;
          graph := sioc..get_graph ();
          iri := 'http://' || sioc..get_cname () || http_path ();
          ret := DB.DBA.URL_REW_ODS_SPQ (graph, iri, acc);
          return ret;
	      }
      else
	      return '';
    }
  else if (par = 'instance')
    {
      declare id, url any;
      val := split_and_decode (val)[0];
      id := BMK.WA.domain_id (val);
      if (id is not null) {
        url := BMK.WA.bookmark_url (id);
        if (url is not null)
          val := url;
      }
      return sprintf (fmt, val);
    }
  else if (par = 'params')
    {
      if (atoi (val) = 0 and val <> '0')
       	fmt := '%s';
      else
        fmt := '?id=%s';
      return sprintf (fmt, val);
    }
}
;

create procedure DB.DBA.URL_REW_ODS_BRIEFCASE (in par varchar, in fmt varchar, in val varchar)
{
  declare acc, ret any;

  acc := DB.DBA.URL_REW_ODS_ACCEPT ();
  if (acc is not null)
    {
      if (par = 'instance')
      	{
          declare q, iri, graph any;
          graph := sioc..get_graph ();
          iri := 'http://' || sioc..get_cname () || http_path ();
          ret := DB.DBA.URL_REW_ODS_SPQ (graph, iri, acc);
          return ret;
	      }
      else
	      return '';
    }
  else if (par = 'instance')
    {
      declare id, url any;
      val := split_and_decode (val)[0];
      id := ODRIVE.WA.domain_id (val);
      if (id is not null) {
        url := ODRIVE.WA.odrive_url (id);
        if (url is not null)
          val := url;
      }
      return sprintf (fmt, val);
    }
  else if (par = 'params')
    {
      if (atoi (val) = 0 and val <> '0')
       	fmt := '%s';
      else
        fmt := '?id=%s';
      return sprintf (fmt, val);
    }
}
;

create procedure DB.DBA.URL_REW_ODS_CALENDAR (in par varchar, in fmt varchar, in val varchar)
{
  declare acc, ret any;

  acc := DB.DBA.URL_REW_ODS_ACCEPT ();
  if (acc is not null)
    {
      if (par = 'instance')
      	{
          declare q, iri, graph any;
          graph := sioc..get_graph ();
          iri := 'http://' || sioc..get_cname () || http_path ();
          ret := DB.DBA.URL_REW_ODS_SPQ (graph, iri, acc);
          return ret;
	      }
      else
	      return '';
    }
  else if (par = 'instance')
    {
      declare id, url any;
      val := split_and_decode (val)[0];
      id := CAL.WA.domain_id (val);
      if (id is not null) {
        url := CAL.WA.calendar_url (id);
        if (url is not null)
          val := url;
      }
      return sprintf (fmt, val);
    }
  else if (par = 'params')
    {
      if (atoi (val) = 0 and val <> '0')
       	fmt := '%s';
      else
        fmt := '?id=%s';
      return sprintf (fmt, val);
    }
}
;

create procedure DB.DBA.URL_REW_ODS_FEEDS (in par varchar, in fmt varchar, in val varchar)
{
  declare acc, ret any;

  acc := DB.DBA.URL_REW_ODS_ACCEPT ();
  if (acc is not null)
    {
      if (par = 'instance')
      	{
          declare q, iri, graph any;
          graph := sioc..get_graph ();
          iri := 'http://' || sioc..get_cname () || http_path ();
          ret := DB.DBA.URL_REW_ODS_SPQ (graph, iri, acc);
          return ret;
	      }
      else
	      return '';
    }
  else if (par = 'instance')
    {
      declare id, url any;
      val := split_and_decode (val)[0];
      id := ENEWS.WA.domain_id (val);
      if (id is not null) {
        url := ENEWS.WA.enews_url (id) || 'news.vspx';
        if (url is not null)
          val := url;
      }
      return sprintf (fmt, val);
    }
  else if (par = 'params')
    {
      if (atoi (val) = 0 and val <> '0')
       	fmt := '%s';
      else
        fmt := '?id=%s';
      return sprintf (fmt, val);
    }
}
;

create procedure DB.DBA.URL_REW_ODS_POLLS (in par varchar, in fmt varchar, in val varchar)
{
  declare acc, ret any;

  acc := DB.DBA.URL_REW_ODS_ACCEPT ();
  if (acc is not null)
    {
      if (par = 'instance')
      	{
          declare q, iri, graph any;
          graph := sioc..get_graph ();
          iri := 'http://' || sioc..get_cname () || http_path ();
          ret := DB.DBA.URL_REW_ODS_SPQ (graph, iri, acc);
          return ret;
	      }
      else
	      return '';
    }
  else if (par = 'instance')
    {
      declare id, url any;
      val := split_and_decode (val)[0];
      id := POLLS.WA.domain_id (val);
      if (id is not null) {
        url := POLLS.WA.polls_url (id);
        if (url is not null)
          val := url;
      }
      return sprintf (fmt, val);
    }
  else if (par = 'params')
    {
      if (atoi (val) = 0 and val <> '0')
       	fmt := '%s';
      else
        fmt := '?id=%s';
      return sprintf (fmt, val);
    }
}
;

create procedure DB.DBA.URL_REW_ODS_FOAF_EXT (in par varchar, in fmt varchar, in val varchar)
{
  if (par = '*accept*')
    {
      declare ext any;
      ext := 'rdf';
      if (val = 'text/rdf+n3')
	ext := 'n3';
      return sprintf (fmt, ext);
    }
  else
    return sprintf (fmt, val);
}
;

create procedure ur_ods_rdf_doc (in path varchar)
{
  declare r any;
  r := regexp_match ('[^/]*\x24', path);
  return r||'#this';
};

create procedure ur_ods_html_doc (in path varchar)
{
  declare pos, r any;
  if (path like '%/foaf.%')
    {
      pos := strrchr (path, '/');
    }
  else if (path like '%#%')
    {
      pos := strrchr (path, '#');
    }
  if (pos > 0)
    r := subseq (path, 0, pos);
  else
    r := '/';
  return r;
};
-- ODS Rules

-- http://cname/dataspace/uname
-- http://cname/dataspace/person/uname

DB.DBA.URLREWRITE_CREATE_REGEX_RULE ('ods_rule1', 1,
    '/dataspace/((person/)?[^/#]*)', vector('ufname'), 1,
    '%s', vector('ufname'),
    'DB.DBA.URL_REW_ODS_USER');

-- http://cname/dataspace/uname with Accept will do 303 to the /sparql
DB.DBA.URLREWRITE_CREATE_REGEX_RULE ('ods_rule2', 1,
    '/dataspace/([^/]*)', vector('ufname'), 1,
    '/sparql?query=define+input%%3Ainference+%%3Chttp%%3A//^{URIQADefaultHost}^/dataspace%%3E+DESCRIBE+%%3Chttp%%3A//^{URIQADefaultHost}^/dataspace/%U%%3E+FROM+%%3Chttp%%3A//^{URIQADefaultHost}^/dataspace%%3E&format=%U', vector('ufname', '*accept*'),
    null,
    '(application|text)/rdf.(xml|n3|turtle|ttl)',
    0,
    303);

-- http://cname/dataspace/uname/app_type
DB.DBA.URLREWRITE_CREATE_REGEX_RULE ('ods_rule3', 1,
    '/dataspace/((?!person)[^/]*)/([^\\./]*)', vector('ufname', 'app'), 2,
    '/ods/app_inst.vspx?app=%s&ufname=%s&l=1', vector('app', 'ufname'),
    'DB.DBA.URL_REW_ODS_APP');

DB.DBA.URLREWRITE_CREATE_REGEX_RULE ('ods_rule4', 1,
    '/dataspace/([^/]*)/(sioc|about|yadis)\\.(rdf|n3|ttl|xrds)', vector('ufname', 'file', 'fmt'), 3,
    '%s', vector('ufname'),
    'DB.DBA.URL_REW_ODS_USER_GEM');

-- Rules for FOAF profile

-- http://cname/dataspace/person/uname with Accept, do 303 to http://cname/dataspace/person/uname/foaf.ext
DB.DBA.URLREWRITE_CREATE_REGEX_RULE ('ods_rule5', 1,
    '/dataspace/person/([^/#]*)/?', vector('ufname'), 1,
    '/dataspace/person/%U/foaf.%s', vector('ufname', '*accept*'),
    'DB.DBA.URL_REW_ODS_FOAF_EXT',
    '(application|text)/rdf.(xml|n3|turtle|ttl)',
    2,
    303);

DB.DBA.URLREWRITE_CREATE_REGEX_RULE ('ods_rule6', 1,
    '/dataspace/person/([^/]*)/page/([^/]*)/?', vector('ufname', 'page'), 1,
    '/dataspace/person/%U/foaf.%s?page=%s', vector('ufname', '*accept*', 'page'),
    'DB.DBA.URL_REW_ODS_FOAF_EXT',
    '(application|text)/rdf.(xml|n3|turtle|ttl)',
    2,
    303);

-- http://cname/dataspace/person/uname/foaf.ext
DB.DBA.URLREWRITE_CREATE_REGEX_RULE ('ods_rule7', 1,
    '/dataspace/person/([^/]*)/foaf.(rdf|n3|ttl)', vector('ufname', 'fmt'), 1,
    '/ods/foaf.vsp?uname=%U&fmt=%U', vector('ufname', 'fmt'),
    null,
    null,
    2,
    null);

-- App Instance Gem

DB.DBA.URLREWRITE_CREATE_REGEX_RULE ('ods_post_gem_rule', 1,
    '/dataspace/([^/]*)/([^/]*)/([^/]*/)?([^/]*/)?(sioc|about)\\.(rdf|n3|ttl)', vector('ufname', 'app', 'inst'), 4,
    '%s', vector('ufname'),
    'DB.DBA.URL_REW_ODS_GEM');


-- Weblog Rules

DB.DBA.URLREWRITE_CREATE_REGEX_RULE ('ods_blog_rule1', 1,
    '/dataspace/([^/]*)/weblog/([^/]*)', vector('ufname', 'inst'), 2,
    '%s', vector('inst'),
    'DB.DBA.URL_REW_ODS_BLOG');

DB.DBA.URLREWRITE_CREATE_REGEX_RULE ('ods_blog_rule2', 1,
    '/dataspace/([^/]*)/weblog/([^/]*)/([^/]*)', vector('ufname', 'inst', 'id'), 3,
    '%s%s', vector('inst', 'id'),
    'DB.DBA.URL_REW_ODS_BLOG');

-- Discussion rules

DB.DBA.URLREWRITE_CREATE_REGEX_RULE ('ods_nntp_rule1', 1,
    '/dataspace/discussion/([^/]*)', vector('grp'), 1,
    '%s', vector('grp'),
    'DB.DBA.URL_REW_ODS_NNTP');

DB.DBA.URLREWRITE_CREATE_REGEX_RULE ('ods_nntp_rule2', 1,
    '/dataspace/discussion/([^/]*)/((?!sioc)(?!about)[^/]*)', vector('grp', 'post'), 2,
    '%s', vector('post'),
    'DB.DBA.URL_REW_ODS_NNTP');

-- Community

DB.DBA.URLREWRITE_CREATE_REGEX_RULE ('ods_xd_rule1', 1,
    '/dataspace/([^/]*)/community/([^/]*)', vector('ufname', 'inst'), 2,
    '%s', vector('inst'),
    'DB.DBA.URL_REW_ODS_XD');

-- Wiki

DB.DBA.URLREWRITE_CREATE_REGEX_RULE ('ods_wiki_rule1', 1,
    '/dataspace/([^/]*)/wiki/([^/]*)', vector('ufname', 'inst'), 2,
    '%s', vector('inst'),
    'DB.DBA.URL_REW_ODS_WIKI');

DB.DBA.URLREWRITE_CREATE_REGEX_RULE ('ods_wiki_rule2', 1,
    '/dataspace/([^/]*)/wiki/([^/]*)/([^/]*)', vector('ufname', 'inst', 'post'), 2,
    '%s%s', vector('inst', 'post'),
    'DB.DBA.URL_REW_ODS_WIKI');

-- Gallery

DB.DBA.URLREWRITE_CREATE_REGEX_RULE ('ods_photo_rule1', 1,
    '/dataspace/([^/]*)/photos/([^/]*)', vector('ufname', 'inst'), 2,
    '%s', vector('inst'),
    'DB.DBA.URL_REW_ODS_PHOTO');

DB.DBA.URLREWRITE_CREATE_REGEX_RULE ('ods_photo_rule2', 1,
    '/dataspace/([^/]*)/photos/([^/]*)/([^/]*)', vector('ufname', 'inst', 'post'), 2,
    '%s', vector('post'),
    'DB.DBA.URL_REW_ODS_PHOTO');


-- AddressBook

DB.DBA.URLREWRITE_CREATE_REGEX_RULE (
    'ods_addressbook_rule1',
    1,
    '/dataspace/([^/]*)/addressbook/([^/]*)',
    vector('uname', 'instance'),
    2,
    '%s', vector('instance'),
    'DB.DBA.URL_REW_ODS_ADDRESSBOOK');

DB.DBA.URLREWRITE_CREATE_REGEX_RULE (
    'ods_addressbook_rule2',
    1,
    '/dataspace/([^/]*)/addressbook/([^/]*)/(.*)',
    vector('uname', 'instance', 'params'),
    3,
    '%s%s',
    vector('instance', 'params'),
    'DB.DBA.URL_REW_ODS_ADDRESSBOOK');

-- Bookmark

DB.DBA.URLREWRITE_CREATE_REGEX_RULE (
    'ods_bookmark_rule1',
    1,
    '/dataspace/([^/]*)/bookmark/([^/]*)',
    vector('uname', 'instance'),
    2,
    '%s', vector('instance'),
    'DB.DBA.URL_REW_ODS_BOOKMARK');

DB.DBA.URLREWRITE_CREATE_REGEX_RULE (
    'ods_bookmark_rule2',
    1,
    '/dataspace/([^/]*)/bookmark/([^/]*)/(.*)',
    vector('uname', 'instance', 'params'),
    3,
    '%s%s',
    vector('instance', 'params'),
    'DB.DBA.URL_REW_ODS_BOOKMARK');

-- Briefcase

DB.DBA.URLREWRITE_CREATE_REGEX_RULE (
    'ods_briefcase_rule1',
    1,
    '/dataspace/([^/]*)/briefcase/([^/]*)',
    vector('uname', 'instance'),
    2,
    '%s', vector('instance'),
    'DB.DBA.URL_REW_ODS_BRIEFCASE');

DB.DBA.URLREWRITE_CREATE_REGEX_RULE (
    'ods_briefcase_rule2',
    1,
    '/dataspace/([^/]*)/briefcase/([^/]*)/(.*)',
    vector('uname', 'instance', 'params'),
    3,
    '%s%s',
    vector('instance', 'params'),
    'DB.DBA.URL_REW_ODS_BRIEFCASE');

-- Calendar

DB.DBA.URLREWRITE_CREATE_REGEX_RULE (
    'ods_calendar_rule1',
    1,
    '/dataspace/([^/]*)/calendar/([^/]*)',
    vector('uname', 'instance'),
    2,
    '%s', vector('instance'),
    'DB.DBA.URL_REW_ODS_CALENDAR');


DB.DBA.URLREWRITE_CREATE_REGEX_RULE (
    'ods_calendar_rule2',
    1,
    '/dataspace/([^/]*)/calendar/([^/]*)/(.*)',
    vector('uname', 'instance', 'params'),
    3,
    '%s%s',
    vector('instance', 'params'),
    'DB.DBA.URL_REW_ODS_CALENDAR');

-- Feeds

DB.DBA.URLREWRITE_CREATE_REGEX_RULE (
    'ods_feeds_rule1',
    1,
    '/dataspace/([^/]*)/feeds/([^/]*)',
    vector('uname', 'instance'),
    2,
    '%s', vector('instance'),
    'DB.DBA.URL_REW_ODS_FEEDS');

DB.DBA.URLREWRITE_CREATE_REGEX_RULE (
    'ods_feeds_rule2',
    1,
    '/dataspace/([^/]*)/feeds/([^/]*)/(.*)',
    vector('uname', 'instance', 'params'),
    3,
    '%s%s',
    vector('instance', 'params'),
    'DB.DBA.URL_REW_ODS_FEEDS');

-- Polls

DB.DBA.URLREWRITE_CREATE_REGEX_RULE (
    'ods_polls_rule1',
    1,
    '/dataspace/([^/]*)/polls/([^/]*)',
    vector('uname', 'instance'),
    2,
    '%s', vector('instance'),
    'DB.DBA.URL_REW_ODS_POLLS');

DB.DBA.URLREWRITE_CREATE_REGEX_RULE (
    'ods_polls_rule2',
    1,
    '/dataspace/([^/]*)/polls/([^/]*)/(.*)',
    vector('uname', 'instance', 'params'),
    3,
    '%s%s',
    vector('instance', 'params'),
    'DB.DBA.URL_REW_ODS_POLLS');

-- ODS Base rules
DB.DBA.URLREWRITE_CREATE_RULELIST ('ods_base_rule_list1', 1,
    	vector(
	        'ods_rule1', 'ods_rule2', 'ods_rule3', 'ods_rule4'
	      ));

DB.DBA.URLREWRITE_CREATE_RULELIST ('ods_foaf_rule_list1', 1,
    	vector(
	        'ods_rule5', 'ods_rule6', 'ods_rule7'
	      ));

DB.DBA.URLREWRITE_CREATE_RULELIST ('ods_gems_rule_list1', 1,
    	vector(
	        'ods_post_gem_rule'
	      ));

-- ODS Blog rules
DB.DBA.URLREWRITE_CREATE_RULELIST ('ods_blog_rule_list1', 1,
    	vector(
	   	'ods_blog_rule1', 'ods_blog_rule2'
	      ));

-- ODS Discussion rules
DB.DBA.URLREWRITE_CREATE_RULELIST ('ods_nntp_rule_list1', 1,
    	vector(
	   	'ods_nntp_rule1', 'ods_nntp_rule2'
	      ));

-- ODS Community rules
DB.DBA.URLREWRITE_CREATE_RULELIST ('ods_xd_rule_list1', 1,
    	vector(
	   	'ods_xd_rule1'
	      ));

-- ODS Wiki rules
DB.DBA.URLREWRITE_CREATE_RULELIST ('ods_wiki_rule_list1', 1,
    	vector(
	   	'ods_wiki_rule1', 'ods_wiki_rule2'
	      ));

-- ODS Gallery rules
DB.DBA.URLREWRITE_CREATE_RULELIST ('ods_photo_rule_list1', 1,
    	vector(
	   	'ods_photo_rule1', 'ods_photo_rule2'
	      ));

-- ODS AddressBook rules
DB.DBA.URLREWRITE_CREATE_RULELIST (
    'ods_addressbook_rule_list1',
    1,
    vector (
  	 	'ods_addressbook_rule1',
	    'ods_addressbook_rule2'
	  ));

-- ODS Bookmark rules
DB.DBA.URLREWRITE_CREATE_RULELIST (
    'ods_bookmark_rule_list1',
    1,
    vector (
  	 	'ods_bookmark_rule1',
	    'ods_bookmark_rule2'
	  ));

-- ODS Briefcase rules
DB.DBA.URLREWRITE_CREATE_RULELIST (
    'ods_briefcase_rule_list1',
    1,
    vector (
  	 	'ods_briefcase_rule1',
	    'ods_briefcase_rule2'
	  ));

-- ODS Calendar rules
DB.DBA.URLREWRITE_CREATE_RULELIST (
    'ods_calendar_rule_list1',
    1,
    vector (
  	 	'ods_calendar_rule1',
	    'ods_calendar_rule2'
	  ));

-- ODS Feeds rules
DB.DBA.URLREWRITE_CREATE_RULELIST (
    'ods_feeds_rule_list1',
    1,
    vector (
  	 	'ods_feeds_rule1',
	    'ods_feeds_rule2'
	  ));

-- ODS Polls rules
DB.DBA.URLREWRITE_CREATE_RULELIST (
    'ods_polls_rule_list1',
    1,
    vector (
  	 	'ods_polls_rule1',
	    'ods_polls_rule2'
	  ));

-- All ODS Rules
DB.DBA.URLREWRITE_CREATE_RULELIST ('ods_rule_list1', 1,
    	vector(
	    'ods_base_rule_list1',
	  'ods_foaf_rule_list1',
  		'ods_blog_rule_list1',
	  	'ods_nntp_rule_list1',
		  'ods_xd_rule_list1',
		  'ods_wiki_rule_list1',
		  'ods_photo_rule_list1',
      'ods_addressbook_rule_list1',
      'ods_bookmark_rule_list1',
      'ods_briefcase_rule_list1',
      'ods_calendar_rule_list1',
      'ods_feeds_rule_list1',
      'ods_polls_rule_list1',
		  'ods_gems_rule_list1'
	      ));

--VHOST_REMOVE (lpath=>'/dataspace');
--VHOST_DEFINE (lpath=>'/dataspace', ppath=>'/DAV/VAD/wa/', vsp_user=>'dba', is_dav=>1, def_page=>'sfront.vspx',
--    is_brws=>0, opts=>vector ('url_rewrite', 'ods_rule_list1'));

