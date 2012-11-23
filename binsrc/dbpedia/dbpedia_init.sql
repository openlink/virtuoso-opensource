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
--

DB.DBA.VHOST_REMOVE ( lhost=>registry_get ('dbp_lhost'), vhost=>registry_get ('dbp_vhost'), lpath=>'/');
DB.DBA.VHOST_REMOVE ( lhost=>registry_get ('dbp_lhost'), vhost=>registry_get ('dbp_vhost'), lpath=>registry_get('_dbpedia_path_'));
DB.DBA.VHOST_REMOVE ( lhost=>registry_get ('dbp_lhost'), vhost=>registry_get ('dbp_vhost'), lpath=>'/class');
DB.DBA.VHOST_REMOVE ( lhost=>registry_get ('dbp_lhost'), vhost=>registry_get ('dbp_vhost'), lpath=>'/ontology');
DB.DBA.VHOST_REMOVE ( lhost=>registry_get ('dbp_lhost'), vhost=>registry_get ('dbp_vhost'), lpath=>'/data');
DB.DBA.VHOST_REMOVE ( lhost=>registry_get ('dbp_lhost'), vhost=>registry_get ('dbp_vhost'), lpath=>'/data2');
DB.DBA.VHOST_REMOVE ( lhost=>registry_get ('dbp_lhost'), vhost=>registry_get ('dbp_vhost'), lpath=>'/data3');
DB.DBA.VHOST_REMOVE ( lhost=>registry_get ('dbp_lhost'), vhost=>registry_get ('dbp_vhost'), lpath=>'/page');
DB.DBA.VHOST_REMOVE ( lhost=>registry_get ('dbp_lhost'), vhost=>registry_get ('dbp_vhost'), lpath=>'/resource');
DB.DBA.VHOST_REMOVE ( lhost=>registry_get ('dbp_lhost'), vhost=>registry_get ('dbp_vhost'), lpath=>'/category');
DB.DBA.VHOST_REMOVE ( lhost=>registry_get ('dbp_lhost'), vhost=>registry_get ('dbp_vhost'), lpath=>'/statics');
DB.DBA.VHOST_REMOVE ( lhost=>registry_get ('dbp_lhost'), vhost=>registry_get ('dbp_vhost'), lpath=>'/wikicompany/resource');
DB.DBA.VHOST_REMOVE ( lhost=>registry_get ('dbp_lhost'), vhost=>registry_get ('dbp_vhost'), lpath=>'/sparql');
DB.DBA.VHOST_REMOVE ( lhost=>registry_get ('dbp_lhost'), vhost=>registry_get ('dbp_vhost'), lpath=>'/property');
DB.DBA.VHOST_REMOVE ( lhost=>registry_get ('dbp_lhost'), vhost=>registry_get ('dbp_vhost'), lpath=>'/data4');
DB.DBA.VHOST_REMOVE ( lhost=>registry_get ('dbp_lhost'), vhost=>registry_get ('dbp_vhost'), lpath=>'/about');
DB.DBA.VHOST_REMOVE ( lhost=>registry_get ('dbp_lhost'), vhost=>registry_get ('dbp_vhost'), lpath=>'/snorql');
DB.DBA.VHOST_REMOVE ( lhost=>registry_get ('dbp_lhost'), vhost=>registry_get ('dbp_vhost'), lpath=>'/sparql-auth');


--# root proxy to dbpedia wiki
DB.DBA.VHOST_DEFINE ( lhost=>registry_get ('dbp_lhost'), vhost=>registry_get ('dbp_vhost'), lpath=>'/',
	 ppath=>registry_get ('dbp_website'),
	 is_dav=>0,
	 def_page=>''
);

DB.DBA.VHOST_DEFINE ( lhost=>registry_get ('dbp_lhost'), vhost=>registry_get ('dbp_vhost'), lpath=>rtrim (registry_get('_dbpedia_path_'), '/'),
	 ppath=>registry_get('_dbpedia_path_'),
	 is_dav=>atoi (registry_get('_dbpedia_dav_')),
	 vsp_user=>'dba'
);

--# class
DB.DBA.VHOST_DEFINE ( lhost=>registry_get ('dbp_lhost'), vhost=>registry_get ('dbp_vhost'), lpath=>'/class',
	 ppath=>'/',
	 is_dav=>0,
	 def_page=>'',
	 opts=>vector ('url_rewrite', 'dbp_rule_list_3')
);

DB.DBA.URLREWRITE_CREATE_RULELIST ( 'dbp_rule_list_3', 1, vector ('dbp_rule_6', 'dbp_rule_7', 'dbp_rule_18', 'dbp_rule_19'));

DB.DBA.URLREWRITE_CREATE_REGEX_RULE ( 'dbp_rule_6', 1, '(/[^#]*)', vector ('par_1'), 1,
registry_get('_dbpedia_path_')||'description.vsp?res=%U', vector ('par_1'), NULL, NULL, 2, 0, '');

DB.DBA.URLREWRITE_CREATE_REGEX_RULE ( 'dbp_rule_7', 1, '/class/(.*)\x24', vector ('par_1'), 1,
'/data2/%s.rdf', vector ('par_1'), NULL, 'application/rdf.xml', 2, 303, 'Content-Type: application/rdf+xml');

DB.DBA.URLREWRITE_CREATE_REGEX_RULE ( 'dbp_rule_18', 1, '/class/(.*)\x24', vector ('par_1'), 1,
'/data2/%s.n3', vector ('par_1'), NULL, 'text/rdf.n3', 2, 303, 'Content-Type: text/rdf+n3');

DB.DBA.URLREWRITE_CREATE_REGEX_RULE ( 'dbp_rule_19', 1, '/class/(.*)\x24', vector ('par_1'), 1,
'/data2/%s.n3', vector ('par_1'), NULL, 'application/x-turtle', 2, 303, 'Content-Type: application/x-turtle');

--# ontology
DB.DBA.VHOST_DEFINE ( lhost=>registry_get ('dbp_lhost'), vhost=>registry_get ('dbp_vhost'), lpath=>'/ontology',
	 ppath=>'/',
	 is_dav=>0,
	 def_page=>'',
	 opts=>vector ('url_rewrite', 'dbp_rule_list_owl')
);


DB.DBA.URLREWRITE_CREATE_RULELIST ( 'dbp_rule_list_owl', 1, vector ('owl_rule_6', 'owl_rule_7', 'owl_rule_18', 'owl_rule_19'));
DB.DBA.URLREWRITE_CREATE_REGEX_RULE ( 'owl_rule_6', 1, '(/[^#]*)', vector ('par_1'), 1,
registry_get('_dbpedia_path_')||'description.vsp?res=%U', vector ('par_1'), NULL, NULL, 2, 0, '');

DB.DBA.URLREWRITE_CREATE_REGEX_RULE ( 'owl_rule_7', 1, '/ontology/(.*)\x24', vector ('par_1'), 1,
'/data3/%s.rdf', vector ('par_1'), NULL, 'application/rdf.xml', 2, 303, 'Content-Type: application/rdf+xml');

DB.DBA.URLREWRITE_CREATE_REGEX_RULE ( 'owl_rule_18', 1, '/ontology/(.*)\x24', vector ('par_1'), 1,
'/data3/%s.n3', vector ('par_1'), NULL, 'text/rdf.n3', 2, 303, 'Content-Type: text/rdf+n3');

DB.DBA.URLREWRITE_CREATE_REGEX_RULE ( 'owl_rule_19', 1, '/ontology/(.*)\x24', vector ('par_1'), 1,
'/data3/%s.n3', vector ('par_1'), NULL, 'application/x-turtle', 2, 303, 'Content-Type: application/x-turtle');


--# data
DB.DBA.VHOST_DEFINE ( lhost=>registry_get ('dbp_lhost'), vhost=>registry_get ('dbp_vhost'), lpath=>'/data',
	 ppath=>registry_get('_dbpedia_path_'),
	 is_dav=>atoi (registry_get('_dbpedia_dav_')),
	 vsp_user=>'dba',
	 opts=>vector ('url_rewrite', 'dbp_data_rule_list', 'url_rewrite_keep_lpath', 1)
);

create procedure DB.DBA.DBP_GRAPH_PARAM1 (in par varchar, in fmt varchar, in val varchar)
{
  declare tmp any;
  tmp := sprintf ('default-graph-uri=%U', registry_get ('dbp_graph'));
  if (par = 'gr')
    {
      val := trim (val, '/');
      if (length (val) = 0)
	val := '';
      if (val = 'en')
        val := '';  
      if (val <> '')
	{
          val := 'http://' || val || '.dbpedia.org';	
	  tmp := tmp || sprintf ('&named-graph-uri=%U', val);
	}
    }
  else
    tmp := val;
  return sprintf (fmt, tmp);
}
;

DB.DBA.URLREWRITE_CREATE_RULELIST ( 'dbp_data_rule_list', 1, vector ('dbp_data_rule0', 'dbp_data_rule1', 'dbp_data_rule2', 'dbp_data_rule3', 'dbp_data_rule3-1', 'dbp_data_rule3-2', 'dbp_data_rule4', 'dbp_data_rule5', 'dbp_data_rule6', 'dbp_data_rule7', 'dbp_data_rule8'));

DB.DBA.URLREWRITE_CREATE_REGEX_RULE ( 'dbp_data_rule0', 1, '/data/([a-z_\\-]*/)?(.*)', vector ('gr', 'par_1'), 1,
'/sparql?%s&query=define+sql:describe-mode+"DBPEDIA"+DESCRIBE+%%3Chttp%%3A%%2F%%2F'||replace(registry_get('dbp_domain'),'http://','')||'%%2Fresource%%2F%s%%3E&format=rdf',
vector ('gr', 'par_1'), 'DB.DBA.DBP_GRAPH_PARAM1', NULL, 2, null, '^{sql:DB.DBA.DBP_LINK_HDR}^');

DB.DBA.URLREWRITE_CREATE_REGEX_RULE ( 'dbp_data_rule1', 1, '/data/([a-z_\\-]*/)?(.*)', vector ('gr', 'par_1'), 1,
'/sparql?%s&query=define+sql:describe-mode+"DBPEDIA"+DESCRIBE+%%3Chttp%%3A%%2F%%2F'||replace(registry_get('dbp_domain'),'http://','')||'%%2Fresource%%2F%s%%3E&format=%U',
vector ('gr', 'par_1', '*accept*'), 'DB.DBA.DBP_GRAPH_PARAM1', '(application/rdf.xml)|(text/rdf.n3)', 2, null, '^{sql:DB.DBA.DBP_LINK_HDR}^');

DB.DBA.URLREWRITE_CREATE_REGEX_RULE ( 'dbp_data_rule2', 1, '/data/([a-z_\\-]*/)?(.*)\\.(xml)', vector ('gr', 'par_1', 'f'), 1,
'/sparql?%s&query=define+sql:describe-mode+"DBPEDIA"+DESCRIBE+%%3Chttp%%3A%%2F%%2F'||replace(registry_get('dbp_domain'),'http://','')||'%%2Fresource%%2F%s%%3E&format=rdf',
vector ('gr', 'par_1'), 'DB.DBA.DBP_GRAPH_PARAM1', NULL, 2, null, '^{sql:DB.DBA.DBP_LINK_HDR}^');

DB.DBA.URLREWRITE_CREATE_REGEX_RULE ( 'dbp_data_rule3', 1, '/data/([a-z_\\-]*/)?(.*)\\.(ttl)', vector ('gr', 'par_1', 'f'), 1,
'/sparql?%s&query=define+sql:describe-mode+"DBPEDIA"+DESCRIBE+%%3Chttp%%3A%%2F%%2F'||replace(registry_get('dbp_domain'),'http://','')||'%%2Fresource%%2F%s%%3E&format=n3',
vector ('gr', 'par_1'), 'DB.DBA.DBP_GRAPH_PARAM1', NULL, 2, null, '^{sql:DB.DBA.DBP_LINK_HDR}^');

DB.DBA.URLREWRITE_CREATE_REGEX_RULE ( 'dbp_data_rule3-1', 1, '/data/([a-z_\\-]*/)?(.*)\\.(nt)', vector ('gr', 'par_1', 'f'), 1,
'/sparql?%s&query=define+sql:describe-mode+"DBPEDIA"+DESCRIBE+%%3Chttp%%3A%%2F%%2F'||replace(registry_get('dbp_domain'),'http://','')||'%%2Fresource%%2F%s%%3E&format=n3',
vector ('gr', 'par_1'), 'DB.DBA.DBP_GRAPH_PARAM1', NULL, 2, null, '^{sql:DB.DBA.DBP_LINK_HDR}^');

DB.DBA.URLREWRITE_CREATE_REGEX_RULE ( 'dbp_data_rule3-2', 1, '/data/([a-z_\\-]*/)?(.*)\\.(n3)', vector ('gr', 'par_1', 'f'), 1,
'/sparql?%s&query=define+sql:describe-mode+"DBPEDIA"+DESCRIBE+%%3Chttp%%3A%%2F%%2F'||replace(registry_get('dbp_domain'),'http://','')||'%%2Fresource%%2F%s%%3E&format=text%%2Fn3',
vector ('gr', 'par_1'), 'DB.DBA.DBP_GRAPH_PARAM1', NULL, 2, null, '^{sql:DB.DBA.DBP_LINK_HDR}^');

DB.DBA.URLREWRITE_CREATE_REGEX_RULE ( 'dbp_data_rule5', 1, '/data/([a-z_\\-]*/)?(.*)\\.(jrdf)', vector ('gr', 'par_1', 'f'), 1,
'/sparql?%s&query=define+sql:describe-mode+"DBPEDIA"+DESCRIBE+%%3Chttp%%3A%%2F%%2F'||replace(registry_get('dbp_domain'),'http://','')||'%%2Fresource%%2F%s%%3E&output=application%%2Frdf%%2Bjson',
vector ('gr', 'par_1'), 'DB.DBA.DBP_GRAPH_PARAM1', NULL, 2, null, 'Content-Type: application/rdf+json\r\n^{sql:DB.DBA.DBP_LINK_HDR}^');

DB.DBA.URLREWRITE_CREATE_REGEX_RULE ( 'dbp_data_rule6', 1, '/data/([a-z_\\-]*/)?(.*)\\.(json)', vector ('gr', 'par_1', 'f'), 1,
'/sparql?%s&query=define+sql:describe-mode+"DBPEDIA"+DESCRIBE+%%3Chttp%%3A%%2F%%2F'||replace(registry_get('dbp_domain'),'http://','')||'%%2Fresource%%2F%s%%3E&output=application%%2Fjson',
vector ('gr', 'par_1'), 'DB.DBA.DBP_GRAPH_PARAM1', NULL, 2, null, 'Content-Type: application/json\r\n^{sql:DB.DBA.DBP_LINK_HDR}^');

DB.DBA.URLREWRITE_CREATE_REGEX_RULE ( 'dbp_data_rule4', 1, '/data/([a-z_\\-]*/)?(.*)\\.(rdf)', vector ('gr', 'par_1', 'f'), 1,
'/sparql?%s&query=define+sql:describe-mode+"DBPEDIA"+DESCRIBE+%%3Chttp%%3A%%2F%%2F'||replace(registry_get('dbp_domain'),'http://','')||'%%2Fresource%%2F%s%%3E&format=%U',
vector ('gr', 'par_1', 'f'), 'DB.DBA.DBP_GRAPH_PARAM1', NULL, 2, null, '^{sql:DB.DBA.DBP_LINK_HDR}^');

DB.DBA.URLREWRITE_CREATE_REGEX_RULE ( 'dbp_data_rule7', 1, '/data/([a-z_\\-]*/)?(.*)\\.(atom)', vector ('gr', 'par_1', 'f'), 1,
'/sparql?%s&query=DESCRIBE+%%3Chttp%%3A%%2F%%2F'||replace(registry_get('dbp_domain'),'http://','')||'%%2Fresource%%2F%s%%3E&output=application%%2Fatom%%2Bxml',
vector ('gr', 'par_1'), 'DB.DBA.DBP_GRAPH_PARAM1', NULL, 2, null, 'Content-Type: application/atom+xml\r\n^{sql:DB.DBA.DBP_LINK_HDR}^');

DB.DBA.URLREWRITE_CREATE_REGEX_RULE ( 'dbp_data_rule7', 1, '/data/([a-z_\\-]*/)?(.*)\\.(jsod)', vector ('gr', 'par_1', 'f'), 1,
'/sparql?%s&query=DESCRIBE+%%3Chttp%%3A%%2F%%2F'||replace(registry_get('dbp_domain'),'http://','')||'%%2Fresource%%2F%s%%3E&output=application%%2Fodata%%2Bjson',
vector ('gr', 'par_1'), 'DB.DBA.DBP_GRAPH_PARAM1', NULL, 2, null, 'Content-Type: application/odata+json\r\n^{sql:DB.DBA.DBP_LINK_HDR}^');

--# data2
DB.DBA.VHOST_DEFINE ( lhost=>registry_get ('dbp_lhost'), vhost=>registry_get ('dbp_vhost'), lpath=>'/data2',
	 ppath=>registry_get('_dbpedia_path_'),
	 is_dav=>atoi (registry_get('_dbpedia_dav_')),
	 vsp_user=>'dba',
	 opts=>vector ('url_rewrite', 'pvsp_rule_list7')
);

DB.DBA.URLREWRITE_CREATE_RULELIST ( 'pvsp_rule_list7', 1, vector ('pvsp_data_rule7'));

DB.DBA.URLREWRITE_CREATE_REGEX_RULE ( 'pvsp_data_rule7', 1, '/data2/(.*)\\.(n3|rdf)', vector ('par_1','f'), 1,
'/sparql?default-graph-uri=http%%3A%%2F%%2F'||replace(registry_get('dbp_graph'),'http://','')||'&query=DESCRIBE+%%3Chttp%%3A%%2F%%2Fdbpedia.org%%2Fclass%%2F%U%%3E&format=%U',
vector ('par_1', 'f'), NULL, NULL, 2, null, '');

--# data3
DB.DBA.VHOST_DEFINE ( lhost=>registry_get ('dbp_lhost'), vhost=>registry_get ('dbp_vhost'), lpath=>'/data3',
	 ppath=>registry_get('_dbpedia_path_'),
	 is_dav=>atoi (registry_get('_dbpedia_dav_')),
	 vsp_user=>'dba',
	 opts=>vector ('url_rewrite', 'pvsp_rule_data3')
);

DB.DBA.URLREWRITE_CREATE_RULELIST ( 'pvsp_rule_data3', 1, vector ('pvsp_data3_rule', 'pvsp_data3_rule_2', 'pvsp_data3_rule_3'));

DB.DBA.URLREWRITE_CREATE_REGEX_RULE ( 'pvsp_data3_rule', 1, '/data3/(.*)\\.(n3|rdf|ttl)', vector ('par_1', 'f'), 1,
'/sparql?default-graph-uri=http%%3A%%2F%%2F'||replace(registry_get('dbp_graph'),'http://','')||'&query=DESCRIBE+%%3Chttp%%3A%%2F%%2Fdbpedia.org%%2Fontology%%2F%U%%3E&format=%U',
vector ('par_1', 'f'), NULL, NULL, 2, NULL, '');

DB.DBA.URLREWRITE_CREATE_REGEX_RULE ( 'pvsp_data3_rule_2', 1, '/data3/(.*)\\.(atom)', vector ('par_1', 'f'), 1,
'/sparql?default-graph-uri=http%%3A%%2F%%2F'||replace(registry_get('dbp_graph'),'http://','')||'&query=DESCRIBE+%%3Chttp%%3A%%2F%%2Fdbpedia.org%%2Fontology%%2F%U%%3E&format=application%%2Fatom%%2Bxml',
vector ('par_1'), NULL, NULL, 2, NULL, '');

DB.DBA.URLREWRITE_CREATE_REGEX_RULE ( 'pvsp_data3_rule', 1, '/data3/(.*)\\.(ntriples)', vector ('par_1', 'f'), 1,
'/sparql?default-graph-uri=http%%3A%%2F%%2F'||replace(registry_get('dbp_graph'),'http://','')||'&query=DESCRIBE+%%3Chttp%%3A%%2F%%2Fdbpedia.org%%2Fontology%%2F%U%%3E&format=text%%2Fplain',
vector ('par_1'), NULL, NULL, 2, NULL, '');

--# page
DB.DBA.VHOST_DEFINE ( lhost=>registry_get ('dbp_lhost'), vhost=>registry_get ('dbp_vhost'), lpath=>'/page',
	 ppath=>registry_get('_dbpedia_path_'),
	 is_dav=>atoi (registry_get('_dbpedia_dav_')),
	 opts=>vector ('url_rewrite', 'dbp_rule_list_7')
);

DB.DBA.URLREWRITE_CREATE_RULELIST ( 'dbp_rule_list_7', 1, vector ('dbp_rule_13'));

DB.DBA.URLREWRITE_CREATE_REGEX_RULE ( 'dbp_rule_13', 1, '(/[^#\\?]*)', vector ('par_1'), 1,
registry_get('_dbpedia_path_')||'description.vsp?res=%U', vector ('par_1'), NULL, NULL, 0, 0, '');

--# resource
DB.DBA.VHOST_DEFINE ( lhost=>registry_get ('dbp_lhost'), vhost=>registry_get ('dbp_vhost'), lpath=>'/resource',
	 ppath=>'/',
	 is_dav=>0,
	 def_page=>'',
	 opts=>vector ('url_rewrite', 'dbp_rule_list_2')
);

create procedure DB.DBA.DBP_LINK_HDR (in in_path varchar)
{
  declare host, lines, accept, loc, alt, exp any;
  lines := http_request_header ();
--  dbg_obj_print ('in_path: ', in_path);
--  dbg_obj_print ('lines: ', lines);
  loc := ''; alt := ''; exp := '';
  host := http_request_header(lines, 'Host', null, '');
  if (regexp_match ('/data/([a-z_\\-]*/)?(.*)\\.(nt|n3|rdf|ttl|jrdf|xml|atom|json|jsod|ntriples)', in_path) is null and in_path like '/data/%')
    {
      declare tmp any;
      accept := http_request_header(lines, 'Accept', null, 'application/rdf+xml');
      accept := regexp_match ('(application/rdf.xml)|(text/rdf.n3)|(text/n3)', accept);
      tmp := split_and_decode (in_path, 0, '\0\0/');
      if (length (tmp) and strstr (http_header_get (), 'Content-Location') is null)
	{
	  tmp := tmp [ length (tmp) - 1 ];
	  if (accept is null)
	    accept := 'application/rdf+xml';
	  if (accept = 'application/rdf+xml')
	    loc := 'Content-Location: ' || tmp || '.xml\r\n';	
	  else if (accept = 'text/rdf+n3')
	    loc := 'Content-Location: ' || tmp || '.n3\r\n';	
	  else if (accept = 'text/n3')
	    loc := 'Content-Location: ' || tmp || '.n3\r\n';	
	}
    }
  if (in_path like '/data/%')
    {
      declare ext any;
      declare p varchar;
      ext := vector (vector ('xml', 'RDF/XML', 'application/rdf+xml'), vector ('n3', 'N3/Turtle', 'text/n3'), vector ('json', 'RDF/JSON', 'application/json'));
      foreach (any ss in ext) do
	{
	  declare s varchar;
	  s := ss[0];
	  if (in_path not like '/data/%.'||s)
	    {
	      p := regexp_replace (in_path, '\\.(nt|n3|rdf|ttl|jrdf|xml|json|atom|jsod|ntriples)\x24', '.'||s);
	      alt := alt || sprintf ('<http://%s%s>; rel="alternate"; type="%s"; title="Structured Descriptor Document (%s format)", ', host, p, ss[2], ss[1]);
	    }
	}
      if (in_path not like '/data/%.atom')
	{
	  p := regexp_replace (in_path, '\\.(nt|n3|rdf|ttl|jrdf|xml|json|atom)\x24', '.atom');
	  alt := alt || sprintf ('<http://%s%s>; rel="alternate"; type="application/atom+xml"; title="OData (Atom+Feed format)", ', host, p);
	}
      if (in_path not like '/data/%.jsod')
	{
	  p := regexp_replace (in_path, '\\.(nt|n3|rdf|ttl|jrdf|xml|json|atom)\x24', '.jsod');
	  alt := alt || sprintf ('<http://%s%s>; rel="alternate"; type="application/odata+json"; title="OData (JSON format)", ', host, p);
	}
      p := regexp_replace (in_path, '\\.(n3|nt|rdf|ttl|jrdf|xml|json|atom)\x24', '');
      p := replace (p, '/data/', '/page/');
      alt := alt || sprintf ('<http://%s%s>; rel="alternate"; type="text/html"; title="XHTML+RDFa", ', host, p);
      p := replace (p, '/page/', '/resource/');
      if (in_path not like '/data/%')
	{
	  alt := alt || sprintf ('<http://%s%s>; rel="http://xmlns.com/foaf/0.1/primaryTopic", ', host, p);
	  alt := alt || sprintf ('<http://%s%s>; rev="describedby", ', host, p);
	}
      else
	{
	  alt := alt || sprintf ('<http://%s%s>; rev="http://xmlns.com/foaf/0.1/primaryTopic", ', host, p);
	  alt := alt || sprintf ('<http://%s%s>; rel="describedby", ', host, p);
	}
      if (registry_get ('dbp_pshb_hub') <> 0)
	alt := alt || sprintf ('<%s>; rel="hub", ', registry_get ('dbp_pshb_hub'));
      exp := sprintf ('Expires: %s\r\n', date_rfc1123 (dateadd ('day', 7, now ())));
    }
  return sprintf ('%s%sLink: %s<http://mementoarchive.lanl.gov/dbpedia/timegate/http://%s%s>; rel="timegate"', exp, loc, alt, host, in_path);
}
;

DB.DBA.URLREWRITE_CREATE_RULELIST ( 'dbp_rule_list_2', 1, vector ('dbp_rule_14', 'dbp_rule_12'));

DB.DBA.URLREWRITE_CREATE_REGEX_RULE ( 'dbp_rule_14', 1, '/resource/(.*)\x24', vector ('par_1'), 1,
    '/page/%s', vector ('par_1'), NULL, NULL, 2, 303, '^{sql:DB.DBA.DBP_LINK_HDR}^');

create procedure DB.DBA.DBP_DATA_IRI1 (in par varchar, in fmt varchar, in val varchar)
{
  if (par = 'par_2' and length (val))
    {
      declare arr any;
      arr := split_and_decode (val);
      if (length (arr) > 1 and arr[1] <> 'en' and length (arr[1]))
	return sprintf (fmt, arr[1] || '/');
      val := '';
    }
  return sprintf (fmt, val);
}
;
DB.DBA.URLREWRITE_CREATE_REGEX_RULE ( 'dbp_rule_12', 1, '/resource/([^\\?]*)(\\?lang=.*)?\x24', vector ('par_1', 'par_2'), 1,
    '/data/@__@%s', vector ('par_1'), 'DB.DBA.DBP_DATA_IRI1', 
    '(application/rdf.xml)|(text/rdf.n3)|(text/n3)|(application/x-turtle)|(application/rdf.json)|(application/json)|(application/atom.xml)|(application/odata.json)', 2, 303, '^{sql:DB.DBA.DBP_LINK_HDR}^');

create procedure DB.DBA.DBP_TCN_LOC (in id any, in var any)
{
  return var;
}
;


delete from DB.DBA.HTTP_VARIANT_MAP where VM_RULELIST = 'dbp_rule_list_2';
DB.DBA.HTTP_VARIANT_ADD ('dbp_rule_list_2', '/data/@__@(.*)', '/data/\x241.xml',  'application/rdf+xml', 0.95, location_hook=>null);
DB.DBA.HTTP_VARIANT_ADD ('dbp_rule_list_2', '/data/@__@(.*)', '/data/\x241.n3',   'text/n3', 0.80, location_hook=>null);
DB.DBA.HTTP_VARIANT_ADD ('dbp_rule_list_2', '/data/@__@(.*)', '/data/\x241.nt',   'text/rdf+n3', 0.80, location_hook=>null);
DB.DBA.HTTP_VARIANT_ADD ('dbp_rule_list_2', '/data/@__@(.*)', '/data/\x241.ttl',  'application/x-turtle', 0.70, location_hook=>null);
DB.DBA.HTTP_VARIANT_ADD ('dbp_rule_list_2', '/data/@__@(.*)', '/data/\x241.json', 'application/json', 0.60, location_hook=>null);
DB.DBA.HTTP_VARIANT_ADD ('dbp_rule_list_2', '/data/@__@(.*)', '/data/\x241.jrdf', 'application/rdf+json', 0.60, location_hook=>null);
DB.DBA.HTTP_VARIANT_ADD ('dbp_rule_list_2', '/data/@__@(.*)', '/data/\x241.atom', 'application/atom+xml', 0.50, location_hook=>null);
DB.DBA.HTTP_VARIANT_ADD ('dbp_rule_list_2', '/data/@__@(.*)', '/data/\x241.jsod', 'application/odata+json', 0.50, location_hook=>null);

--# category
DB.DBA.VHOST_DEFINE ( lhost=>registry_get ('dbp_lhost'), vhost=>registry_get ('dbp_vhost'), lpath=>'/category',
	 ppath=>'/',
	 is_dav=>0,
	 def_page=>'',
	 opts=>vector ('url_rewrite', 'dbp_rule_list_category')
);

DB.DBA.URLREWRITE_CREATE_RULELIST ( 'dbp_rule_list_category', 1, vector ('dbp_rule_category14', 'dbp_rule_category12'));

DB.DBA.URLREWRITE_CREATE_REGEX_RULE ( 'dbp_rule_category14', 1, '/category/(.*)\x24', vector ('par_1'), 1,
    '/page/%s', vector ('par_1'), NULL, NULL, 2, 303, NULL);

DB.DBA.URLREWRITE_CREATE_REGEX_RULE ( 'dbp_rule_category12', 1, '/category/(.*)\x24', vector ('par_1'), 1,
    '/data/__%U', vector ('par_1'), NULL, '(application/rdf.xml)|(text/rdf.n3)|(application/x-turtle)|(application/rdf.json)|(application/json)', 2, 303);

delete from DB.DBA.HTTP_VARIANT_MAP where VM_RULELIST = 'dbp_rule_list_category';
DB.DBA.HTTP_VARIANT_ADD ('dbp_rule_list_category', '__(.*)', '\x241.xml', 'application/rdf+xml', 0.95, location_hook=>null);
DB.DBA.HTTP_VARIANT_ADD ('dbp_rule_list_category', '__(.*)', '\x241.n3',  'text/rdf+n3', 0.80, location_hook=>null);
DB.DBA.HTTP_VARIANT_ADD ('dbp_rule_list_category', '__(.*)', '\x241.ttl',  'application/x-turtle', 0.70, location_hook=>null);
DB.DBA.HTTP_VARIANT_ADD ('dbp_rule_list_category', '__(.*)', '\x241.json',  'application/json', 0.60, location_hook=>null);
DB.DBA.HTTP_VARIANT_ADD ('dbp_rule_list_category', '__(.*)', '\x241.jrdf',  'application/rdf+json', 0.60, location_hook=>null);


--# statics
DB.DBA.VHOST_DEFINE ( lhost=>registry_get ('dbp_lhost'), vhost=>registry_get ('dbp_vhost'), lpath=>'/statics',
	 ppath=>'/DAV/VAD/dbpedia/statics/',
	 is_dav=>1,
	 def_page=>'index.html'
);

--# wikicompany
DB.DBA.VHOST_DEFINE ( lhost=>registry_get ('dbp_lhost'), vhost=>registry_get ('dbp_vhost'), lpath=>'/wikicompany/resource',
	 ppath=>'/DAV/wikicompany/resource/',
	 is_dav=>1,
	 vsp_user=>'dba',
	 opts=>vector ('url_rewrite', 'dbp_wc_rule_list1')
);

DB.DBA.URLREWRITE_CREATE_RULELIST ( 'dbp_wc_rule_list1', 1, vector ('dbp_wc_rule1', 'dbp_wc_rule2'));

DB.DBA.URLREWRITE_CREATE_REGEX_RULE ( 'dbp_wc_rule1', 1, '(/[^#]*)', vector ('par_1'), 1,
registry_get('_dbpedia_path_')||'description_white.vsp?res=%s', vector ('par_1'), NULL, NULL, 2, 0, '');

DB.DBA.URLREWRITE_CREATE_REGEX_RULE ( 'dbp_wc_rule2', 1, '(/[^#]*)', vector ('par_1'), 1,
'/sparql?query=describe%%20%%3Chttp%%3A%%2F%%2Fdbpedia.openlinksw.com%s%%3E%%20from%%20%%3Chttp%%3A%%2F%%2Fdbpedia.openlinksw.com%%2Fwikicompany%%3E&format=%U',
vector ('par_1', '*accept*'), NULL, '(application/rdf.xml)|(text/rdf.n3)', 2, 303, '');

--# sparql
DB.DBA.VHOST_DEFINE ( lhost=>registry_get ('dbp_lhost'), vhost=>registry_get ('dbp_vhost'), lpath=>'/sparql',
	ppath=>'/!sparql/',
	is_dav=>1,
	def_page=>'',
	vsp_user=>'dba',
	opts=>vector ('noinherit', 'yes')
);

--# property
DB.DBA.VHOST_DEFINE ( lhost=>registry_get ('dbp_lhost'), vhost=>registry_get ('dbp_vhost'), lpath=>'/property',
	 ppath=>'/',
	 is_dav=>0,
	 def_page=>'',
	 opts=>vector ('url_rewrite', 'dbp_rule_list_prop')
);

DB.DBA.URLREWRITE_CREATE_RULELIST ( 'dbp_rule_list_prop', 1, vector ('prop_rule_6', 'prop_rule_7', 'prop_rule_18', 'prop_rule_19'));
DB.DBA.URLREWRITE_CREATE_REGEX_RULE ( 'prop_rule_6', 1, '(/[^#\\?]*)', vector ('par_1'), 1,
registry_get('_dbpedia_path_')||'description.vsp?res=%U', vector ('par_1'), NULL, NULL, 0, 0, '');

DB.DBA.URLREWRITE_CREATE_REGEX_RULE ( 'prop_rule_7', 1, '/property/(.*)\x24', vector ('par_1'), 1,
'/data4/%s.rdf', vector ('par_1'), NULL, 'application/rdf.xml', 2, 303, 'Content-Type: application/rdf+xml');

DB.DBA.URLREWRITE_CREATE_REGEX_RULE ( 'prop_rule_18', 1, '/property/(.*)\x24', vector ('par_1'), 1,
'/data4/%s.n3', vector ('par_1'), NULL, 'text/rdf.n3', 1, 303, 'Content-Type: text/rdf+n3');

DB.DBA.URLREWRITE_CREATE_REGEX_RULE ( 'prop_rule_19', 1, '/property/(.*)\x24', vector ('par_1'), 1,
'/data4/%s.n3', vector ('par_1'), NULL, 'application/x-turtle', 2, 303, 'Content-Type: application/x-turtle');

--# data4
DB.DBA.VHOST_DEFINE ( lhost=>registry_get ('dbp_lhost'), vhost=>registry_get ('dbp_vhost'), lpath=>'/data4',
	 ppath=>registry_get('_dbpedia_path_'),
	 is_dav=>atoi (registry_get('_dbpedia_dav_')),
	 vsp_user=>'dba',
	 opts=>vector ('url_rewrite', 'pvsp_rule_data4')
);

DB.DBA.URLREWRITE_CREATE_RULELIST ( 'pvsp_rule_data4', 1, vector ('pvsp_data4_rule'));

DB.DBA.URLREWRITE_CREATE_REGEX_RULE ( 'pvsp_data4_rule', 1, '/data4/(.*)\\.(n3|rdf)', vector ('par_1', 'f'), 1,
'/sparql?default-graph-uri=http%%3A%%2F%%2F'||replace(registry_get('dbp_graph'),'http://','')||'&query=DESCRIBE+%%3Chttp%%3A%%2F%%2Fdbpedia.org%%2Fproperty%%2F%U%%3E&format=%U',
vector ('par_1', 'f'), NULL, NULL, 2, null, '');

--# about 
DB.DBA.VHOST_DEFINE (
	 lhost=>registry_get ('dbp_lhost'),
	 vhost=>registry_get ('dbp_vhost'),
	 lpath=>'/about',
	 ppath=>'/SOAP/Http/ext_http_proxy',
	 is_dav=>0,
	 soap_user=>'PROXY',
	 ses_vars=>0,
	 opts=>vector ('url_rewrite', 'ext_about_http_proxy_rule_list1'),
	 is_default_host=>0
);

DB.DBA.URLREWRITE_CREATE_RULELIST ( 
    'ext_about_http_proxy_rule_list1', 1, 
      vector ('dbp_about_rule_1'));

DB.DBA.URLREWRITE_CREATE_REGEX_RULE ( 
    'dbp_about_rule_1', 1, 
      '/about/html/(.*)\x24', 
      vector ('par_1'), 
      1, 
      '/DAV/VAD/dbpedia/description.vsp?res=%U', 
      vector ('par_1'), 
      NULL, 
      NULL, 
      2, 
      0, 
      '' 
      );

DB.DBA.VHOST_REMOVE (
	 lhost=>registry_get ('dbp_lhost'),
	 vhost=>registry_get ('dbp_vhost'),
	 lpath=>'/rdfdesc');
DB.DBA.VHOST_DEFINE (
	 lhost=>registry_get ('dbp_lhost'),
	 vhost=>registry_get ('dbp_vhost'),
	 lpath=>'/rdfdesc',
	 ppath=>'/DAV/VAD/rdf_mappers/rdfdesc/',
	 is_dav=>1,
	 vsp_user=>'dba',
	 ses_vars=>0,
	 is_default_host=>0
);

--# snorql
DB.DBA.VHOST_DEFINE (
	 lhost=>registry_get ('dbp_lhost'),
	 vhost=>registry_get ('dbp_vhost'),
	 lpath=>'/snorql',
	 ppath=>'/snorql/',
	 is_dav=>0,
	 def_page=>'index.html',
	 vsp_user=>'dba',
	 ses_vars=>0,
	 opts=>vector ('browse_sheet', 0),
	 is_default_host=>0
);

--# sparql-auth
DB.DBA.VHOST_DEFINE (
	 lhost=>registry_get ('dbp_lhost'),
	 vhost=>registry_get ('dbp_vhost'),
	 lpath=>'/sparql-auth',
	 ppath => '/!sparql/',
	 is_dav => 1,
	 vsp_user => 'dba',
	 opts => vector('noinherit', 1),
	 auth_fn=>'DB.DBA.HP_AUTH_SPARQL_USER',
	 realm=>'SPARQL',
	 sec=>'digest');

--# other init code

create procedure ensure_demo_user ()
{
    if (exists (select 1 from SYS_USERS where U_NAME = 'demo'))
	return;
	exec ('create user "demo"');
	DB.DBA.user_set_qualifier ('demo', 'Demo');
};

ensure_demo_user ();

drop procedure ensure_demo_user;

create procedure create_demo_home ()
{
  declare pwd any;
  pwd := (select pwd_magic_calc (U_NAME, U_PASSWORD, 1) from SYS_USERS where U_NAME = 'dav');
  DAV_COL_CREATE ('/DAV/home/', '110100100', http_dav_uid(), http_dav_uid() + 1, 'dav', pwd);
  DAV_COL_CREATE ('/DAV/home/demo/', '110100100', http_dav_uid(), http_dav_uid() + 1, 'dav', pwd);
  DAV_COL_CREATE ('/DAV/home/demo/dbpedia/', '110100100', http_dav_uid(), http_dav_uid() + 1, 'dav', pwd);
};

create_demo_home ();
drop procedure create_demo_home;

create procedure upload_isparql ()
{
  declare base varchar;
  declare pwd any;
  pwd := (select pwd_magic_calc (U_NAME, U_PASSWORD, 1) from SYS_USERS where U_NAME = 'dav');
  base := registry_get('_dbpedia_path_');
  if (base like '/DAV/%')
    {
      for select RES_FULL_PATH from WS..SYS_DAV_RES where RES_FULL_PATH like base||'%.isparql' do
	{
	  DAV_COPY (RES_FULL_PATH, '/DAV/home/demo/dbpedia/', 0, '111101101NN', 'dav', 'administrators', 'dav', pwd);
	}
    }
  else
    {
      declare arr any;
      arr := sys_dirlist (base);
      foreach (varchar f in arr) do
	{
	  if (f like '%.isparql')
	    DAV_RES_UPLOAD ('/DAV/home/demo/dbpedia/'||f, file_to_string (base||f), '', '110100100R', http_dav_uid(), http_dav_gid(), 'dav', pwd);
	}
    }
  -- the current trigger of isparql have bug
  update WS..SYS_DAV_RES set RES_PERMS = '110100100NN' where RES_FULL_PATH like '/DAV/home/demo/dbpedia/%';
}
;

upload_isparql ();
drop procedure upload_isparql;


--# void & iSPARQL non-default VDs
DB.DBA.VHOST_REMOVE ( lhost=>registry_get ('dbp_lhost'), vhost=>registry_get ('dbp_vhost'), lpath=>'/void');
DB.DBA.VHOST_REMOVE ( lhost=>registry_get ('dbp_lhost'), vhost=>registry_get ('dbp_vhost'), lpath=>'/void/data');
DB.DBA.VHOST_REMOVE ( lhost=>registry_get ('dbp_lhost'), vhost=>registry_get ('dbp_vhost'), lpath=>'/void/page');
DB.DBA.VHOST_REMOVE ( lhost=>registry_get ('dbp_lhost'), vhost=>registry_get ('dbp_vhost'), lpath=>'/isparql');
DB.DBA.VHOST_REMOVE ( lhost=>registry_get ('dbp_lhost'), vhost=>registry_get ('dbp_vhost'), lpath=>'/isparql/view');
DB.DBA.VHOST_REMOVE ( lhost=>registry_get ('dbp_lhost'), vhost=>registry_get ('dbp_vhost'), lpath=>'/isparql/defaults');

DB.DBA.VHOST_DEFINE ( lhost=>registry_get ('dbp_lhost'), vhost=>registry_get ('dbp_vhost'), lpath=>'/void',
	 ppath=>'/',
	 is_dav=>0,
	 def_page=>'',
	 ses_vars=>0,
	 opts=>vector ('url_rewrite', 'dbpl_void_rule_list'),
	 is_default_host=>0
);

DB.DBA.VHOST_DEFINE ( lhost=>registry_get ('dbp_lhost'), vhost=>registry_get ('dbp_vhost'), lpath=>'/void/data',
	 ppath=>'/DAV/VAD/dbpedia/',
	 is_dav=>1,
	 vsp_user=>'dba',
	 ses_vars=>0,
	 opts=>vector ('url_rewrite', 'dbpl_void_data_rule_list'),
	 is_default_host=>0
);

DB.DBA.VHOST_DEFINE ( lhost=>registry_get ('dbp_lhost'), vhost=>registry_get ('dbp_vhost'), lpath=>'/void/page',
	 ppath=>'/DAV/VAD/dbpedia/',
	 is_dav=>1,
	 ses_vars=>0,
	 opts=>vector ('url_rewrite', 'dbpl_void_page_rule_list'),
	 is_default_host=>0
);
    
DB.DBA.VHOST_DEFINE ( lhost=>registry_get ('dbp_lhost'), vhost=>registry_get ('dbp_vhost'), lpath=>'/isparql',
	 ppath=>'/DAV/VAD/iSPARQL/',
	 is_dav=>1,
	 def_page=>'index.html',
	 vsp_user=>'dba',
	 ses_vars=>0,
	 is_default_host=>0
);
DB.DBA.VHOST_DEFINE ( lhost=>registry_get ('dbp_lhost'), vhost=>registry_get ('dbp_vhost'), lpath=>'/isparql/view',
	 ppath=>'/DAV/VAD/iSPARQL/',
	 is_dav=>1,
	 def_page=>'execute.html',
	 vsp_user=>'dba',
	 ses_vars=>0,
	 is_default_host=>0
);
DB.DBA.VHOST_DEFINE ( lhost=>registry_get ('dbp_lhost'), vhost=>registry_get ('dbp_vhost'), lpath=>'/isparql/defaults',
	 ppath=>'/DAV/VAD/iSPARQL/',
	 is_dav=>1,
	 def_page=>'defaults.vsp',
	 vsp_user=>'dba',
	 ses_vars=>0,
	 is_default_host=>0
);

create procedure DB.DBA.SPARQL_DESC_DICT_DBPEDIA_PHYSICAL 
(in subj_dict any, in consts any, in good_graphs any, in bad_graphs any, in storage_name any, in options any)
{
  declare res, subjs any;
  res := DB.DBA.SPARQL_DESC_DICT (subj_dict, consts, good_graphs, bad_graphs, storage_name, options);
  if (is_http_ctx ())
    {
      subjs := dict_to_vector (subj_dict, 0);
      for (declare i int, i := 0; i < length (subjs); i := i + 2) 
      {
	declare s any;
	s := subjs [i];
	dict_put (res, vector (iri_to_id (HTTP_URL_HANDLER ()), iri_to_id ('http://xmlns.com/foaf/0.1/primaryTopic'), s), 1);
	dict_put (res, vector (iri_to_id (HTTP_URL_HANDLER ()), iri_to_id ('http://www.w3.org/1999/02/22-rdf-syntax-ns#type'), iri_to_id ('http://xmlns.com/foaf/0.1/Document')), 1);
      }
    }
  return res;
}
;

grant execute on DB.DBA.SPARQL_DESC_DICT_DBPEDIA_PHYSICAL to "SPARQL_SELECT";

--# Facet browser on non-default vd
DB.DBA.VHOST_REMOVE ( lhost=>registry_get ('dbp_lhost'), vhost=>registry_get ('dbp_vhost'), lpath=>'/fct');
DB.DBA.VHOST_REMOVE ( lhost=>registry_get ('dbp_lhost'), vhost=>registry_get ('dbp_vhost'), lpath=>'/fct/service');
DB.DBA.VHOST_REMOVE ( lhost=>registry_get ('dbp_lhost'), vhost=>registry_get ('dbp_vhost'), lpath=>'/fct/soap');
DB.DBA.VHOST_REMOVE ( lhost=>registry_get ('dbp_lhost'), vhost=>registry_get ('dbp_vhost'), lpath=>'/services/rdf/iriautocomplete.get');
DB.DBA.VHOST_REMOVE ( lhost=>registry_get ('dbp_lhost'), vhost=>registry_get ('dbp_vhost'), lpath=>'/describe');

DB.DBA.VHOST_DEFINE (lhost=>registry_get ('dbp_lhost'), vhost=>registry_get ('dbp_vhost'), 
    lpath=>'/fct', ppath=>'/DAV/VAD/fct/', 
    is_dav=>1, def_page=>'facet.vsp', vsp_user=>'dba', ses_vars=>0, is_default_host=>0);


DB.DBA.VHOST_DEFINE (lhost=>registry_get ('dbp_lhost'), vhost=>registry_get ('dbp_vhost'),
	 lpath=>'/fct/service', ppath=>'/SOAP/Http/fct_svc',
	 is_dav=>0, soap_user=>'dba', ses_vars=>0, is_default_host=>0);
    
DB.DBA.VHOST_DEFINE (lhost=>registry_get ('dbp_lhost'), vhost=>registry_get ('dbp_vhost'),
	 lpath=>'/fct/soap', ppath=>'/SOAP/',
	 is_dav=>0, soap_user=>'dba', ses_vars=>0, is_default_host=>0);

DB.DBA.VHOST_DEFINE (lhost=>registry_get ('dbp_lhost'), vhost=>registry_get ('dbp_vhost'),
	 lpath=>'/services/rdf/iriautocomplete.get', ppath=>'/SOAP/Http/IRI_AUTOCOMPLETE',
	 is_dav=>0, soap_user=>'PROXY', ses_vars=>0, is_default_host=>0);

DB.DBA.VHOST_DEFINE (lhost=>registry_get ('dbp_lhost'), vhost=>registry_get ('dbp_vhost'),
	 lpath=>'/describe', ppath=>'/SOAP/Http/EXT_HTTP_PROXY_1',
	 is_dav=>0, soap_user=>'PROXY', ses_vars=>0,
	 opts=>vector ('url_rewrite', 'ext_fctabout_http_proxy_rule_list1'),
	 is_default_host=>0);

-- VoID VDs
DB.DBA.VHOST_REMOVE (lpath=>'/void/data');
DB.DBA.VHOST_DEFINE (lpath=>'/void/data', ppath=>registry_get('_dbpedia_path_'), is_dav=>atoi (registry_get('_dbpedia_dav_')),
	 vsp_user=>'dba', opts=>vector ('url_rewrite', 'dbpl_void_data_rule_list'));

DB.DBA.URLREWRITE_CREATE_RULELIST ( 'dbpl_void_data_rule_list', 1, vector ('dbpl_void_data_rule_1'));
DB.DBA.URLREWRITE_CREATE_REGEX_RULE ( 'dbpl_void_data_rule_1', 1, '/void/data/(.*)\\.(n3|rdf|ttl)', vector ('par_1', 'fmt'), 1,
'/sparql?default-graph-uri=http%%3A%%2F%%2F'||replace(registry_get('dbp_graph'),'http://','')||'%%2Fvoid%%2F&query='||dbp_gen_describe('void')||'&format=%U',
vector ('par_1', 'par_1', 'par_1', 'par_1', 'par_1', 'par_1', 'fmt'), NULL, NULL, 2, null, '');

-- HTML
DB.DBA.VHOST_REMOVE (lpath=>'/void/page');
DB.DBA.VHOST_DEFINE (lpath=>'/void/page', ppath=>registry_get('_dbpedia_path_'), is_dav=>atoi (registry_get('_dbpedia_dav_')),
	 opts=>vector ('url_rewrite', 'dbpl_void_page_rule_list'));

DB.DBA.URLREWRITE_CREATE_RULELIST ( 'dbpl_void_page_rule_list', 1, vector ('dbpl_void_page_rule_1'));
DB.DBA.URLREWRITE_CREATE_REGEX_RULE ( 'dbpl_void_page_rule_1', 1, '/void/page/(.*)', vector ('par_1'), 1,
registry_get('_dbpedia_path_')||'description.vsp?res=%%2Fvoid%%2F%U', vector ('par_1'), NULL, NULL, 0, 0, '');


-- IRIs
DB.DBA.VHOST_REMOVE (lpath=>'/void');
DB.DBA.VHOST_DEFINE (lpath=>'/void', ppath=>'/', is_dav=>0, def_page=>'', opts=>vector ('url_rewrite', 'dbpl_void_rule_list'));

DB.DBA.URLREWRITE_CREATE_RULELIST ( 'dbpl_void_rule_list', 1,
    vector ('dbpl_void_rule_1', 'dbpl_void_rule_2', 'dbpl_void_rule_3', 'dbpl_void_rule_4'));
DB.DBA.URLREWRITE_CREATE_REGEX_RULE ( 'dbpl_void_rule_1', 1, '/void/(.*)\x24', vector ('par_1'), 1,
    '/void/page/%s', vector ('par_1'), NULL, NULL, 2, 303, NULL);
DB.DBA.URLREWRITE_CREATE_REGEX_RULE ( 'dbpl_void_rule_2', 1, '/void/(.*)\x24', vector ('par_1'), 1,
    '/void/data/%s.rdf', vector ('par_1'), NULL, 'application/rdf.xml', 2, 303, 'Content-Type: application/rdf+xml');
DB.DBA.URLREWRITE_CREATE_REGEX_RULE ( 'dbpl_void_rule_3', 1, '/void/(.*)\x24', vector ('par_1'), 1,
    '/void/data/%s.n3', vector ('par_1'), NULL, 'text/rdf.n3', 2, 303, 'Content-Type: text/rdf+n3');
DB.DBA.URLREWRITE_CREATE_REGEX_RULE ( 'dbpl_void_rule_4', 1, '/void/(.*)\x24', vector ('par_1'), 1,
    '/void/data/%s.n3', vector ('par_1'), NULL, 'application/x-turtle', 2, 303, 'Content-Type: application/x-turtle');

TTLP (
'
@prefix owl: <http://www.w3.org/2002/07/owl#> .

<http://dbpedia.org/ontology/deathPlace> owl:equivalentProperty <http://dbpedia.org/property/deathPlace> .
<http://dbpedia.org/ontology/deathDate> owl:equivalentProperty <http://dbpedia.org/property/death> .
<http://dbpedia.org/ontology/birthPlace> owl:equivalentProperty <http://dbpedia.org/property/birthPlace> .
<http://dbpedia.org/ontology/birthDate> owl:equivalentProperty <http://dbpedia.org/property/birth> .
<http://xmlns.com/foaf/0.1/givenName> owl:equivalentProperty <http://xmlns.com/foaf/0.1/givenname> .
<http://purl.org/dc/terms/subject> owl:equivalentProperty <http://www.w3.org/2004/02/skos/core#subject> .
<http://dbpedia.org/ontology/wikiPageID> owl:equivalentProperty <http://dbpedia.org/property/pageId> .
<http://dbpedia.org/ontology/wikiPageRevisionID> owl:equivalentProperty <http://dbpedia.org/property/revisionId> .
<http://dbpedia.org/ontology/wikiPageWikiLink> owl:equivalentProperty <http://dbpedia.org/property/wikilink> .
<http://dbpedia.org/ontology/wikiPageExternalLink> owl:equivalentProperty <http://dbpedia.org/property/reference> .
<http://dbpedia.org/ontology/wikiPageRedirects> owl:equivalentProperty <http://dbpedia.org/property/redirect> .
<http://dbpedia.org/ontology/wikiPageDisambiguates> owl:equivalentProperty <http://dbpedia.org/property/disambiguates> .
', '', 'http://dbpedia.org/schema/property_rules#');

