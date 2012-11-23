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

create procedure dbp_setup ()
{
--# if utf-8 iri's are used
  if (not isstring(registry_get ('dbp_decode_iri')))
    registry_set ('dbp_decode_iri','off');

--# the resource domain e.g. http://(xx.)dbpedia.org/resource/...
  if (not isstring(registry_get('dbp_domain')))
    registry_set('dbp_domain','http://dbpedia.org');

--# the default graph
  if (not isstring(registry_get ('dbp_graph')))
    registry_set ('dbp_graph', 'http://dbpedia.org');

--#
  if (not isstring(registry_get ('dbp_lang')))
    registry_set ('dbp_lang', 'en');

--# fix for dbp_replace
  if (not isstring(registry_get ('dbp_DynamicLocal')))
    registry_set ('dbp_DynamicLocal', 'on');

--# to create the prefix category:
  if (not isstring(registry_get ('dbp_category')))
    registry_set('dbp_category', 'Category');

  if (not isstring(registry_get ('dbp_imprint')))
    registry_set ('dbp_imprint', 'http://wiki.dbpedia.org/Imprint');

--# in order to remove and set the rules automatically
  if (not isstring(registry_get ('dbp_website') ))
    registry_set('dbp_website','http://wiki.dbpedia.org/');

  if (not isstring(registry_get ('dbp_lhost') ))
    registry_set ('dbp_lhost', ':80');

  if (not isstring(registry_get ('dbp_vhost') ))
    registry_set ('dbp_vhost', 'dbpedia.org');
};

dbp_setup ();

create procedure dbp_replace (in o any)
{
--# changed 'http://dbpedia.org to dbp domain since local: works with server domain
  declare ret any;
  if (isiri_id (o))
   {
     if (registry_get('dbp_DynamicLocal') = 'off')
       return  iri_to_id(o);
     else
       return  iri_to_id  (replace (id_to_iri (o), registry_get('dbp_domain'), 'local:'));
   }
  else if (__box_flags (o) = 1)
    {

      if (registry_get('dbp_DynamicLocal') = 'off')
        ret:= o;
      else
        ret  := replace (o, registry_get('dbp_domain'), 'local:');

      __box_flags_set (ret, 1);
      return ret;
    }
  return o;
}
;

grant execute on dbp_replace to SPARQL_SELECT;

create procedure DB.DBA.SPARQL_DESC_DICT_DBPEDIA_ODATA_PHYSICAL 
(in subj_dict any, in consts any, in good_graphs any, in bad_graphs any, in storage_name any, in options any)
{
  declare res, arr, ret any;
  res := DB.DBA.SPARQL_DESC_DICT_CBD_PHYSICAL (subj_dict, consts, good_graphs, bad_graphs, storage_name, options);
  ret := dict_new ();
  arr := dict_to_vector (res, 1);
  for (declare i int, i := 0; i < length (arr); i := i + 2) 
    {
      dict_put (ret, vector (dbp_replace (arr[i][0]), dbp_replace (arr[i][1]), dbp_replace (arr[i][2])), 0); 
    }
  return ret;
}
;

grant execute on DB.DBA.SPARQL_DESC_DICT_DBPEDIA_ODATA_PHYSICAL to "SPARQL_SELECT";

create procedure dbp_gen_describe (in path varchar)
{
  declare qr varchar;
  qr :=
	'prefix owl: <http://www.w3.org/2002/07/owl#> CONSTRUCT { <local:/IRI/PH> `sql:dbp_replace (?p1)` `sql:dbp_replace (?o1)` . '||
  	'`sql:dbp_replace (?s2)` `sql:dbp_replace (?p2)` <local:/IRI/PH> . <local:/IRI/PH> owl:sameAs <http://dbpedia.org/IRI/PH> . } '||
  	'WHERE { { <http://dbpedia.org/IRI/PH> ?p1 ?o1 } UNION { ?s2 ?p2 <http://dbpedia.org/IRI/PH> } }';
  if (registry_get('dbp_DynamicLocal') = 'off')
    {
      qr := replace (qr, 'local:', registry_get('dbp_domain'));
    }
  qr := replace (qr, 'IRI', path);
  qr := sprintf ('%U', qr);
  qr := replace (qr, '%', '%%');
  qr := replace (qr, 'PH', '%U');
  return qr;
}
;

-- XXX : to be removed
--registry_set('_dbpedia_path_', '/dbpedia/');
--registry_set('_dbpedia_dav_', '0');

-- Base

DB.DBA.VHOST_REMOVE (lpath=>registry_get('_dbpedia_path_'));
DB.DBA.VHOST_DEFINE (lpath=>rtrim (registry_get('_dbpedia_path_'), '/'), ppath=>registry_get('_dbpedia_path_'),
    is_dav=>atoi (registry_get('_dbpedia_dav_')), vsp_user=>'dba');

-- CSS, images etc.
DB.DBA.VHOST_REMOVE (lpath=>'/statics');
DB.DBA.VHOST_DEFINE (lpath=>'/statics', ppath=>registry_get('_dbpedia_path_')||'statics/',
    is_dav=>atoi (registry_get('_dbpedia_dav_')));

-- Classes
DB.DBA.VHOST_REMOVE (lpath=>'/class');
DB.DBA.VHOST_DEFINE (lpath=>'/class',
	 ppath=>'/',
	 is_dav=>0,
	 def_page=>'',
	 opts=>vector ('url_rewrite', 'dbpl_class_rule_list')
);

DB.DBA.URLREWRITE_CREATE_RULELIST ( 'dbpl_class_rule_list', 1, vector ('dbpl_class_rule_1', 'dbpl_class_rule_2', 'dbpl_class_rule_3', 'dbpl_class_rule_4'));

DB.DBA.URLREWRITE_CREATE_REGEX_RULE ( 'dbpl_class_rule_1', 1, '(/[^#]*)', vector ('par_1'), 1,
registry_get('_dbpedia_path_')||'description.vsp?res=%U', vector ('par_1'), NULL, NULL, 0, 0, '');

DB.DBA.URLREWRITE_CREATE_REGEX_RULE ( 'dbpl_class_rule_2', 1, '/class/(.*)\x24', vector ('par_1'), 1,
'/data2/%s.rdf', vector ('par_1'), NULL, 'application/rdf.xml', 2, 303, 'Content-Type: application/rdf+xml');

DB.DBA.URLREWRITE_CREATE_REGEX_RULE ( 'dbpl_class_rule_3', 1, '/class/(.*)\x24', vector ('par_1'), 1,
'/data2/%s.n3', vector ('par_1'), NULL, 'text/rdf.n3', 1, 303, 'Content-Type: text/rdf+n3');

DB.DBA.URLREWRITE_CREATE_REGEX_RULE ( 'dbpl_class_rule_4', 1, '/class/(.*)\x24', vector ('par_1'), 1,
'/data2/%s.n3', vector ('par_1'), NULL, 'application/x-turtle', 2, 303, 'Content-Type: application/x-turtle');


-- OWL
DB.DBA.VHOST_REMOVE (lpath=>'/ontology');
DB.DBA.VHOST_DEFINE (lpath=>'/ontology', ppath=>'/', is_dav=>0, def_page=>'', opts=>vector ('url_rewrite', 'dbpl_owl_rule_list'));

DB.DBA.URLREWRITE_CREATE_RULELIST ( 'dbpl_owl_rule_list', 1, vector ('dbpl_owl_rule_1', 'dbpl_owl_rule_2', 'dbpl_owl_rule_3', 'dbpl_owl_rule_4'));
DB.DBA.URLREWRITE_CREATE_REGEX_RULE ( 'dbpl_owl_rule_1', 1, '(/[^#]*)', vector ('par_1'), 1,
registry_get('_dbpedia_path_')||'description.vsp?res=%U', vector ('par_1'), NULL, NULL, 0, 0, '');

DB.DBA.URLREWRITE_CREATE_REGEX_RULE ( 'dbpl_owl_rule_2', 1, '/ontology/(.*)\x24', vector ('par_1'), 1,
'/data3/%s.rdf', vector ('par_1'), NULL, 'application/rdf.xml', 2, 303, 'Content-Type: application/rdf+xml');

DB.DBA.URLREWRITE_CREATE_REGEX_RULE ( 'dbpl_owl_rule_3', 1, '/ontology/(.*)\x24', vector ('par_1'), 1,
'/data3/%s.n3', vector ('par_1'), NULL, 'text/rdf.n3', 1, 303, 'Content-Type: text/rdf+n3');

DB.DBA.URLREWRITE_CREATE_REGEX_RULE ( 'dbpl_owl_rule_4', 1, '/ontology/(.*)\x24', vector ('par_1'), 1,
'/data3/%s.n3', vector ('par_1'), NULL, 'application/x-turtle', 2, 303, 'Content-Type: application/x-turtle');

-- RDF link
create procedure DB.DBA.DBP_GRAPH_PARAM (in par varchar, in fmt varchar, in val varchar)
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

create procedure DB.DBA.DBP_CHECK_304 (in lines any, in opts any)
{
  declare graph any;
  graph := get_keyword ('graph', opts);
  return dbp_check_if_modified (lines, graph);
}
;

DB.DBA.VHOST_REMOVE (lpath=>'/data');
DB.DBA.VHOST_DEFINE (lpath=>'/data', ppath=>registry_get('_dbpedia_path_'), is_dav=>atoi (registry_get('_dbpedia_dav_')),
	 vsp_user=>'dba', opts=>vector ('url_rewrite', 'dbpl_data_rule_list', 'expiration_function', 'DB.DBA.DBP_CHECK_304', 'graph', registry_get ('dbp_graph')));

DB.DBA.URLREWRITE_CREATE_RULELIST ( 'dbpl_data_rule_list', 1, vector ('dbpl_data_rule_0', 'dbpl_data_rule_1', 'dbpl_data_rule_2', 'dbpl_data_rule_3', 'dbpl_data_rule_4', 'dbpl_data_rule_5', 'dbpl_data_rule_6', 'dbpl_data_rule_7', 'dbpl_data_rule_8', 'dbpl_data_rule_9', 'dbpl_data_rule_10'));

DB.DBA.URLREWRITE_CREATE_REGEX_RULE ( 'dbpl_data_rule_0', 1, '/data/([a-z_\\-]*/)?(.*)', vector ('gr', 'par_1'), 1,
'/sparql?%s&query='||dbp_gen_describe('resource')||'&format=rdf',
vector ('gr', 'par_1', 'par_1', 'par_1', 'par_1', 'par_1', 'par_1'), 'DB.DBA.DBP_GRAPH_PARAM', NULL, 2, null, '^{sql:DB.DBA.DBP_LINK_HDR}^');

DB.DBA.URLREWRITE_CREATE_REGEX_RULE ( 'dbpl_data_rule_1', 1, '/data/([a-z_\\-]*/)?(.*)', vector ('gr', 'par_1'), 1,
'/sparql?%s&query='||dbp_gen_describe('resource')||'&format=%U',
vector ('gr', 'par_1', 'par_1', 'par_1', 'par_1', 'par_1', 'par_1', '*accept*'), 'DB.DBA.DBP_GRAPH_PARAM', 
				'(application/rdf.xml)|(text/rdf.n3)', 2, null, '^{sql:DB.DBA.DBP_LINK_HDR}^');

DB.DBA.URLREWRITE_CREATE_REGEX_RULE ( 'dbpl_data_rule_2', 1, '/data/([a-z_\\-]*/)?(.*)\\.(ttl)', vector ('gr', 'par_1', 'fmt'), 1,
'/sparql?%s&query='||dbp_gen_describe('resource')||'&format=text%%2Fturtle',
vector ('gr', 'par_1', 'par_1', 'par_1', 'par_1', 'par_1', 'par_1'), 'DB.DBA.DBP_GRAPH_PARAM', NULL, 2, null, '^{sql:DB.DBA.DBP_LINK_HDR}^');

DB.DBA.URLREWRITE_CREATE_REGEX_RULE ( 'dbpl_data_rule_3', 1, '/data/([a-z_\\-]*/)?(.*)\\.(jrdf)', vector ('gr', 'par_1', 'fmt'), 1,
'/sparql?%s&query='||dbp_gen_describe('resource')||'&format=application%%2Frdf%%2Bjson',
vector ('gr', 'par_1', 'par_1', 'par_1', 'par_1', 'par_1', 'par_1'), 'DB.DBA.DBP_GRAPH_PARAM', NULL, 2, null, '^{sql:DB.DBA.DBP_LINK_HDR}^');

DB.DBA.URLREWRITE_CREATE_REGEX_RULE ( 'dbpl_data_rule_4', 1, '/data/([a-z_\\-]*/)?(.*)\\.(json)', vector ('gr', 'par_1', 'fmt'), 1,
'/sparql?%s&query='||dbp_gen_describe('resource')||'&format=application%%2Fjson',
vector ('gr', 'par_1', 'par_1', 'par_1', 'par_1', 'par_1', 'par_1'), 'DB.DBA.DBP_GRAPH_PARAM', NULL, 2, null, '^{sql:DB.DBA.DBP_LINK_HDR}^');

DB.DBA.URLREWRITE_CREATE_REGEX_RULE ( 'dbpl_data_rule_5', 1, '/data/([a-z_\\-]*/)?(.*)\\.(xml)', vector ('gr', 'par_1', 'fmt'), 1,
'/sparql?%s&query='||dbp_gen_describe('resource')||'&format=rdf',
vector ('gr', 'par_1', 'par_1', 'par_1', 'par_1', 'par_1', 'par_1'), 'DB.DBA.DBP_GRAPH_PARAM', NULL, 2, null, '^{sql:DB.DBA.DBP_LINK_HDR}^');

--DB.DBA.URLREWRITE_CREATE_REGEX_RULE ( 'dbpl_data_rule_6', 1, '/data/([a-z_\\-]*/)?(.*)\\.(atom)', vector ('gr', 'par_1', 'fmt'), 1,
--'/sparql?%s&query='||dbp_gen_describe('resource')||'&format=application%%2Fatom%%2Bxml',
--vector ('gr', 'par_1', 'par_1', 'par_1', 'par_1', 'par_1', 'par_1'), 'DB.DBA.DBP_GRAPH_PARAM', NULL, 2, null, '^{sql:DB.DBA.DBP_LINK_HDR}^');
DB.DBA.URLREWRITE_CREATE_REGEX_RULE ( 'dbpl_data_rule_6', 1, '/data/([a-z_\\-]*/)?(.*)\\.(atom)', vector ('gr', 'par_1', 'f'), 1,
'/sparql?%s&query=define+sql:describe-mode+"DBPEDIA_ODATA"+DESCRIBE+%%3Chttp%%3A%%2F%%2Fdbpedia.org%%2Fresource%%2F%s%%3E&output=application%%2Fatom%%2Bxml',
vector ('gr', 'par_1'), 'DB.DBA.DBP_GRAPH_PARAM1', NULL, 2, null, '^{sql:DB.DBA.DBP_LINK_HDR}^');

DB.DBA.URLREWRITE_CREATE_REGEX_RULE ( 'dbpl_data_rule_7', 1, '/data/([a-z_\\-]*/)?(.*)\\.(n3)', vector ('gr', 'par_1', 'fmt'), 1,
'/sparql?%s&query='||dbp_gen_describe('resource')||'&format=text%%2Fn3',
vector ('gr', 'par_1', 'par_1', 'par_1', 'par_1', 'par_1', 'par_1'), 'DB.DBA.DBP_GRAPH_PARAM', NULL, 2, null, '^{sql:DB.DBA.DBP_LINK_HDR}^');

DB.DBA.URLREWRITE_CREATE_REGEX_RULE ( 'dbpl_data_rule_8', 1, '/data/([a-z_\\-]*/)?(.*)\\.(nt)', vector ('gr', 'par_1', 'fmt'), 1,
'/sparql?%s&query='||dbp_gen_describe('resource')||'&format=text%%2Frdf%%2Bn3',
vector ('gr', 'par_1', 'par_1', 'par_1', 'par_1', 'par_1', 'par_1'), 'DB.DBA.DBP_GRAPH_PARAM', NULL, 2, null, '^{sql:DB.DBA.DBP_LINK_HDR}^');

DB.DBA.URLREWRITE_CREATE_REGEX_RULE ( 'dbpl_data_rule_9', 1, '/data/([a-z_\\-]*/)?(.*)\\.(jsod)', vector ('gr', 'par_1', 'f'), 1,
'/sparql?%s&query=define+sql:describe-mode+"DBPEDIA_ODATA"+DESCRIBE+%%3Chttp%%3A%%2F%%2Fdbpedia.org%%2Fresource%%2F%U%%3E&output=application%%2Fodata%%2Bjson',
vector ('gr', 'par_1'), 'DB.DBA.DBP_GRAPH_PARAM1', NULL, 2, null, '^{sql:DB.DBA.DBP_LINK_HDR}^');

DB.DBA.URLREWRITE_CREATE_REGEX_RULE ( 'dbpl_data_rule_10', 1, '/data/([a-z_\\-]*/)?(.*)\\.(ntriples)', vector ('gr', 'par_1', 'f'), 1,
'/sparql?%s&query=define+sql:describe-mode+"DBPEDIA_ODATA"+DESCRIBE+%%3Chttp%%3A%%2F%%2Fdbpedia.org%%2Fresource%%2F%U%%3E&output=text%%2Fplain',
vector ('gr', 'par_1'), 'DB.DBA.DBP_GRAPH_PARAM1', NULL, 2, null, '^{sql:DB.DBA.DBP_LINK_HDR}^');


-- OWL link
DB.DBA.VHOST_REMOVE (lpath=>'/data2');
DB.DBA.VHOST_DEFINE (lpath=>'/data2', ppath=>registry_get('_dbpedia_path_'), is_dav=>atoi (registry_get('_dbpedia_dav_')),
	 vsp_user=>'dba', opts=>vector ('url_rewrite', 'dbpl_data2_rule_list', 'expiration_function', 'DB.DBA.DBP_CHECK_304', 'graph', registry_get ('dbp_graph')));

DB.DBA.URLREWRITE_CREATE_RULELIST ( 'dbpl_data2_rule_list', 1, vector ('dbpl_data2_rule_1'));
DB.DBA.URLREWRITE_CREATE_REGEX_RULE ( 'dbpl_data2_rule_1', 1, '/data2/(.*)\\.(n3|rdf|ttl)', vector ('par_1', 'fmt'), 1,
'/sparql?default-graph-uri=http%%3A%%2F%%2F'||replace(registry_get('dbp_graph'),'http://','')||'&query='||dbp_gen_describe('class')||'&format=%U',
vector ('par_1', 'par_1', 'par_1', 'par_1', 'par_1', 'par_1', 'fmt'), NULL, NULL, 2, null, '');

-- Property link
DB.DBA.VHOST_REMOVE (lpath=>'/data3');
DB.DBA.VHOST_DEFINE (lpath=>'/data3', ppath=>registry_get('_dbpedia_path_'), is_dav=>atoi (registry_get('_dbpedia_dav_')),
	 vsp_user=>'dba', opts=>vector ('url_rewrite', 'dbpl_data3_rule_list', 'expiration_function', 'DB.DBA.DBP_CHECK_304', 'graph', registry_get ('dbp_graph')));

DB.DBA.URLREWRITE_CREATE_RULELIST ( 'dbpl_data3_rule_list', 1, vector ('dbpl_data3_rule_1', 'dbpl_data3_rule_2', 'dbpl_data3_rule_3', 'dbpl_data3_rule_4', 'dbpl_data3_rule_5'));
DB.DBA.URLREWRITE_CREATE_REGEX_RULE ( 'dbpl_data3_rule_1', 1, '/data3/(.*)\\.(n3|rdf|ttl)', vector ('par_1', 'fmt'), 1,
'/sparql?default-graph-uri=http%%3A%%2F%%2F'||replace(registry_get('dbp_graph'),'http://','')||'%%2Fresource%%2Fclasses%%23&query='||dbp_gen_describe ('ontology')||'&format=%U',
vector ('par_1', 'par_1', 'par_1', 'par_1', 'par_1', 'par_1', 'fmt'), NULL, NULL, 2, null, '');

DB.DBA.URLREWRITE_CREATE_REGEX_RULE ( 'dbpl_data3_rule_2', 1, '/data3/(.*)\\.atom', vector ('par_1'), 1,
'/sparql?default-graph-uri=http%%3A%%2F%%2F'||replace(registry_get('dbp_graph'),'http://','')||'%%2Fresource%%2Fclasses%%23&query='||dbp_gen_describe ('ontology')||'&format=application%%2Fatom%%2Bxml',
vector ('par_1', 'par_1', 'par_1', 'par_1', 'par_1', 'par_1'), NULL, NULL, 2, null, '');

DB.DBA.URLREWRITE_CREATE_REGEX_RULE ( 'dbpl_data3_rule_3', 1, '/data3/(.*)\\.ntriples', vector ('par_1'), 1,
'/sparql?default-graph-uri=http%%3A%%2F%%2F'||replace(registry_get('dbp_graph'),'http://','')||'%%2Fresource%%2Fclasses%%23&query='||dbp_gen_describe ('ontology')||'&format=text%%2Fplain',
vector ('par_1', 'par_1', 'par_1', 'par_1', 'par_1', 'par_1'), NULL, NULL, 2, null, '');

DB.DBA.URLREWRITE_CREATE_REGEX_RULE ( 'dbpl_data3_rule_4', 1, '/data3/(.*)\\.json', vector ('par_1'), 1,
'/sparql?default-graph-uri=http%%3A%%2F%%2F'||replace(registry_get('dbp_graph'),'http://','')||'%%2Fresource%%2Fclasses%%23&query='||dbp_gen_describe ('ontology')||'&format=application%%2Fjson',
vector ('par_1', 'par_1', 'par_1', 'par_1', 'par_1', 'par_1'), NULL, NULL, 2, null, '');

DB.DBA.URLREWRITE_CREATE_REGEX_RULE ( 'dbpl_data3_rule_5', 1, '/data3/(.*)\\.jsod', vector ('par_1'), 1,
'/sparql?default-graph-uri=http%%3A%%2F%%2F'||replace(registry_get('dbp_graph'),'http://','')||'%%2Fresource%%2Fclasses%%23&query='||dbp_gen_describe ('ontology')||'&format=application%%2Fodata%%2Bjson',
vector ('par_1', 'par_1', 'par_1', 'par_1', 'par_1', 'par_1'), NULL, NULL, 2, null, '');


-- HTML
DB.DBA.VHOST_REMOVE (lpath=>'/page');
DB.DBA.VHOST_DEFINE (lpath=>'/page', ppath=>registry_get('_dbpedia_path_'), is_dav=>atoi (registry_get('_dbpedia_dav_')),
	 opts=>vector ('url_rewrite', 'dbpl_page_rule_list'));

DB.DBA.URLREWRITE_CREATE_RULELIST ( 'dbpl_page_rule_list', 1, vector ('dbpl_page_rule_1'));
DB.DBA.URLREWRITE_CREATE_REGEX_RULE ( 'dbpl_page_rule_1', 1, '(/[^#\\?]*)', vector ('par_1'), 1,
registry_get('_dbpedia_path_')||'description.vsp?res=%U', vector ('par_1'), NULL, NULL, 0, 0, '');

-- IRIs
DB.DBA.VHOST_REMOVE (lpath=>'/category');
DB.DBA.VHOST_DEFINE (lpath=>'/category', ppath=>'/', is_dav=>0, def_page=>'', opts=>vector ('url_rewrite', 'dbpl_category_rule_list'));

DB.DBA.URLREWRITE_CREATE_RULELIST ( 'dbpl_category_rule_list', 1,
    vector ('dbpl_category_rule_1', 'dbpl_category_rule_2'));
DB.DBA.URLREWRITE_CREATE_REGEX_RULE ( 'dbpl_category_rule_1', 1, '/category/(.*)\x24', vector ('par_1'), 1,
    '/page/%s', vector ('par_1'), NULL, NULL, 2, 303, NULL);

create procedure DB.DBA.DBP_DATA_IRI (in par varchar, in fmt varchar, in val varchar)
{
  if (par = 'par_2' and length (val))
    {
      declare arr any;
      arr := split_and_decode (val);
      if (length (arr) > 1 and arr[1] <> 'en')
	return sprintf (fmt, arr[1] || '/');
      val := '';
    }
  return sprintf (fmt, val);
}
;

DB.DBA.URLREWRITE_CREATE_REGEX_RULE ( 'dbpl_category_rule_2', 1, '/category/([^\\?]*)(\\?lang=.*)?\x24', vector ('par_1', 'par_2'), 1,
    '/data/%s@__@%s', vector ('par_2', 'par_1'), 'DB.DBA.DBP_DATA_IRI', 
    '(application/rdf.xml)|(text/rdf.n3)|(application/x-turtle)|(application/rdf.json)|(application/json)', 2, 303, '^{sql:DB.DBA.DBP_LINK_HDR}^');

delete from DB.DBA.HTTP_VARIANT_MAP where VM_RULELIST = 'dbpl_category_rule_list';
DB.DBA.HTTP_VARIANT_ADD ('dbpl_category_rule_list', '@__@(.*)', '/data/\x241.xml', 'application/rdf+xml', 0.95, location_hook=>null);
DB.DBA.HTTP_VARIANT_ADD ('dbpl_category_rule_list', '@__@(.*)', '/data/\x241.n3',  'text/rdf+n3', 0.80, location_hook=>null);
DB.DBA.HTTP_VARIANT_ADD ('dbpl_category_rule_list', '@__@(.*)', '/data/\x241.ttl',  'application/x-turtle', 0.70, location_hook=>null);
DB.DBA.HTTP_VARIANT_ADD ('dbpl_category_rule_list', '@__@(.*)', '/data/\x241.json',  'application/json', 0.60, location_hook=>null);
DB.DBA.HTTP_VARIANT_ADD ('dbpl_category_rule_list', '@__@(.*)', '/data/\x241.jrdf',  'application/rdf+json', 0.60, location_hook=>null);

DB.DBA.VHOST_REMOVE (lpath=>'/resource');
DB.DBA.VHOST_DEFINE (lpath=>'/resource', ppath=>'/', is_dav=>0, def_page=>'', opts=>vector ('url_rewrite', 'dbpl_resource_rule_list'));

DB.DBA.URLREWRITE_CREATE_RULELIST ( 'dbpl_resource_rule_list', 1,
    vector ('dbpl_resource_rule_1', 'dbpl_resource_rule_2'));
DB.DBA.URLREWRITE_CREATE_REGEX_RULE ( 'dbpl_resource_rule_1', 1, '/resource/(.*)\x24', vector ('par_1'), 1,
    '/page/%s', vector ('par_1'), NULL, NULL, 2, 303, NULL);

create procedure DB.DBA.DBP_DATA_IRI (in par varchar, in fmt varchar, in val varchar)
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

DB.DBA.URLREWRITE_CREATE_REGEX_RULE ( 'dbpl_resource_rule_2', 1, '/resource/([^\\?]*)(\\?lang=.*)?\x24', vector ('par_1', 'par_2'), 1,
    '/data/%s@__@%s', vector ('par_2', 'par_1'), 'DB.DBA.DBP_DATA_IRI', 
    '(application/rdf.xml)|(text/rdf.n3)|(text/n3)|(text/turtle)|(application/rdf.json)|(application/json)|(application/atom.xml)|(application/odata.json)', 2, 303, '^{sql:DB.DBA.DBP_LINK_HDR}^');

delete from DB.DBA.HTTP_VARIANT_MAP where VM_RULELIST = 'dbpl_resource_rule_list';
DB.DBA.HTTP_VARIANT_ADD ('dbpl_resource_rule_list', '/(.*)@__@(.*)', '/data/\x242.xml', 'application/rdf+xml', 0.95, location_hook=>null);
DB.DBA.HTTP_VARIANT_ADD ('dbpl_resource_rule_list', '/(.*)@__@(.*)', '/data/\x242.n3',  'text/n3', 0.80, location_hook=>null);
DB.DBA.HTTP_VARIANT_ADD ('dbpl_resource_rule_list', '/(.*)@__@(.*)', '/data/\x242.nt',  'text/rdf+n3', 0.80, location_hook=>null);
DB.DBA.HTTP_VARIANT_ADD ('dbpl_resource_rule_list', '/(.*)@__@(.*)', '/data/\x242.ttl',  'text/turtle', 0.70, location_hook=>null);
DB.DBA.HTTP_VARIANT_ADD ('dbpl_resource_rule_list', '/(.*)@__@(.*)', '/data/\x242.json',  'application/json', 0.60, location_hook=>null);
DB.DBA.HTTP_VARIANT_ADD ('dbpl_resource_rule_list', '/(.*)@__@(.*)', '/data/\x242.jrdf',  'application/rdf+json', 0.60, location_hook=>null);
DB.DBA.HTTP_VARIANT_ADD ('dbpl_resource_rule_list', '/(.*)@__@(.*)', '/data/\x242.atom',  'application/atom+xml', 0.50, location_hook=>null);
DB.DBA.HTTP_VARIANT_ADD ('dbpl_resource_rule_list', '/(.*)@__@(.*)', '/data/\x242.jsod',  'application/odata+json', 0.50, location_hook=>null);

-- Wikicompany
--DB.DBA.VHOST_REMOVE (lpath=>'/wikicompany/resource');
--DB.DBA.VHOST_DEFINE (lpath=>'/wikicompany/resource', ppath=>'/DAV/wikicompany/resource/', is_dav=>1, vsp_user=>'dba',
--	 opts=>vector ('url_rewrite', 'dbpl_wc_rule_list'));
--DB.DBA.URLREWRITE_CREATE_RULELIST ( 'dbpl_wc_rule_list', 1, vector ('dbpl_wc_rule1', 'dbpl_wc_rule2'));
--DB.DBA.URLREWRITE_CREATE_REGEX_RULE ( 'dbpl_wc_rule1', 1, '(/[^#]*)', vector ('par_1'), 1,
--registry_get('_dbpedia_path_')||'description_white.vsp?res=%s', vector ('par_1'), NULL, NULL, 2, 0, '');
--DB.DBA.URLREWRITE_CREATE_REGEX_RULE ( 'dbpl_wc_rule2', 1, '(/[^#]*)', vector ('par_1'), 1,
--'/sparql?query=DESCRIBE%%20%%3Chttp%%3A%%2F%%2Fdbpedia.openlinksw.com%s%%3E%%20from%%20%%3Chttp%%3A%%2F%%2Fdbpedia.openlinksw.com%%2Fwikicompany%%3E&format=%U',
--vector ('par_1', '*accept*'), NULL, '(application/rdf.xml)|(text/rdf.n3)', 2, 303, '');

-- Property
DB.DBA.VHOST_REMOVE (lpath=>'/property');
DB.DBA.VHOST_DEFINE (lpath=>'/property',
	 ppath=>'/',
	 is_dav=>0,
	 def_page=>'',
	 opts=>vector ('url_rewrite', 'dbpl_prop_rule_list')
);
DB.DBA.URLREWRITE_CREATE_RULELIST ( 'dbpl_prop_rule_list', 1, vector ('dbpl_prop_rule_1', 'dbpl_prop_rule_2', 'dbpl_prop_rule_3', 'dbpl_prop_rule_4'));
DB.DBA.URLREWRITE_CREATE_REGEX_RULE ( 'dbpl_prop_rule_1', 1, '(/[^#]*)', vector ('par_1'), 1,
registry_get('_dbpedia_path_')||'description.vsp?res=%U', vector ('par_1'), NULL, NULL, 0, 0, '');

DB.DBA.URLREWRITE_CREATE_REGEX_RULE ( 'dbpl_prop_rule_2', 1, '/property/(.*)\x24', vector ('par_1'), 1,
'/data4/%s.rdf', vector ('par_1'), NULL, 'application/rdf.xml', 2, 303, 'Content-Type: application/rdf+xml');

DB.DBA.URLREWRITE_CREATE_REGEX_RULE ( 'dbpl_prop_rule_3', 1, '/property/(.*)\x24', vector ('par_1'), 1,
'/data4/%s.n3', vector ('par_1'), NULL, 'text/rdf.n3', 1, 303, 'Content-Type: text/rdf+n3');

DB.DBA.URLREWRITE_CREATE_REGEX_RULE ( 'dbpl_prop_rule_4', 1, '/property/(.*)\x24', vector ('par_1'), 1,
'/data4/%s.n3', vector ('par_1'), NULL, 'application/x-turtle', 2, 303, 'Content-Type: application/x-turtle');

-- RDF for property
DB.DBA.VHOST_REMOVE (lpath=>'/data4');
DB.DBA.VHOST_DEFINE (lpath=>'/data4',
	 ppath=>registry_get('_dbpedia_path_'),
	 is_dav=>atoi (registry_get('_dbpedia_dav_')),
	 vsp_user=>'dba',
	 opts=>vector ('url_rewrite', 'dbpl_data4_rule_list', 'expiration_function', 'DB.DBA.DBP_CHECK_304', 'graph', registry_get ('dbp_graph'))
);

DB.DBA.URLREWRITE_CREATE_RULELIST ( 'dbpl_data4_rule_list', 1, vector ('dbpl_data4_rule_1'));
DB.DBA.URLREWRITE_CREATE_REGEX_RULE ( 'dbpl_data4_rule_1', 1, '/data4/(.*)\\.(n3|rdf|ttl)', vector ('par_1', 'fmt'), 1,
'/sparql?default-graph-uri=http%%3A%%2F%%2F'||replace(registry_get('dbp_graph'),'http://','')||'&query='||dbp_gen_describe ('property')||'&format=%U',
vector ('par_1', 'par_1', 'par_1', 'par_1', 'par_1', 'par_1', 'fmt'), NULL, NULL, 2, null, '');


-- Meta
DB.DBA.VHOST_REMOVE (lpath=>'/meta');
DB.DBA.VHOST_DEFINE (lpath=>'/meta',
	 ppath=>'/',
	 is_dav=>0,
	 def_page=>'',
	 opts=>vector ('url_rewrite', 'dbpl_meta_rule_list')
);
DB.DBA.URLREWRITE_CREATE_RULELIST ( 'dbpl_meta_rule_list', 1, vector ('dbpl_meta_rule_1', 'dbpl_meta_rule_2', 'dbpl_meta_rule_3', 'dbpl_meta_rule_4'));
DB.DBA.URLREWRITE_CREATE_REGEX_RULE ( 'dbpl_meta_rule_1', 1, '(/[^#]*)', vector ('par_1'), 1,
registry_get('_dbpedia_path_')||'description.vsp?res=%U', vector ('par_1'), NULL, NULL, 0, 0, '');

DB.DBA.URLREWRITE_CREATE_REGEX_RULE ( 'dbpl_meta_rule_2', 1, '/meta/(.*)\x24', vector ('par_1'), 1,
'/data5/%s.rdf', vector ('par_1'), NULL, 'application/rdf.xml', 2, 303, 'Content-Type: application/rdf+xml');

DB.DBA.URLREWRITE_CREATE_REGEX_RULE ( 'dbpl_meta_rule_3', 1, '/meta/(.*)\x24', vector ('par_1'), 1,
'/data5/%s.n3', vector ('par_1'), NULL, 'text/rdf.n3', 1, 303, 'Content-Type: text/rdf+n3');

DB.DBA.URLREWRITE_CREATE_REGEX_RULE ( 'dbpl_meta_rule_4', 1, '/meta/(.*)\x24', vector ('par_1'), 1,
'/data5/%s.n3', vector ('par_1'), NULL, 'application/x-turtle', 2, 303, 'Content-Type: application/x-turtle');

-- RDF for meta
DB.DBA.VHOST_REMOVE (lpath=>'/data5');
DB.DBA.VHOST_DEFINE (lpath=>'/data5',
	 ppath=>registry_get('_dbpedia_path_'),
	 is_dav=>atoi (registry_get('_dbpedia_dav_')),
	 vsp_user=>'dba',
	 opts=>vector ('url_rewrite', 'dbpl_data5_rule_list')
);

DB.DBA.URLREWRITE_CREATE_RULELIST ( 'dbpl_data5_rule_list', 1, vector ('dbpl_data5_rule_1'));
DB.DBA.URLREWRITE_CREATE_REGEX_RULE ( 'dbpl_data5_rule_1', 1, '/data5/(.*)\\.(n3|rdf|ttl)', vector ('par_1', 'fmt'), 1,
'/sparql?default-graph-uri=http%%3A%%2F%%2F'||replace(registry_get('dbp_graph'),'http://','')||'&query='||dbp_gen_describe ('meta')||'&format=%U',
vector ('par_1', 'par_1', 'par_1', 'par_1', 'par_1', 'par_1', 'fmt'), NULL, NULL, 2, null, '');


create procedure dbpl_robots ()
{
  if (not isstring (http_root () || '/robots.txt'))
    {
      declare exit handler for sqlstate '*' {
	return;
      };
      string_to_file (http_root () || '/robots.txt', 'User-agent: *\r\nDisallow: /\r\n', -2);
    }
}
;

dbpl_robots ()
;


