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

TTLP ('@prefix foaf: <http://xmlns.com/foaf/0.1/>
@prefix dc: <http://purl.org/dc/elements/1.1/>
@prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#>
@prefix virtrdf: <http://www.openlinksw.com/schemas/virtrdf#>
@prefix fbase: <http://rdf.freebase.com/ns/>
rdfs:label rdfs:subPropertyOf virtrdf:label .
dc:title rdfs:subPropertyOf virtrdf:label .
fbase:type.object.name rdfs:subPropertyOf virtrdf:label .
foaf:name rdfs:subPropertyOf virtrdf:label .
<http://s.opencalais.com/1/pred/name> rdfs:subPropertyOf virtrdf:label .
foaf:nick rdfs:subPropertyOf virtrdf:label .', '', 'dbprdf-label');

rdfs_rule_set ('dbprdf-label', 'dbprdf-label');

create procedure dbp_ldd_set_ns_decl ()
{
  declare arr any;
  declare i, l int;
  arr := vector (
    registry_get('dbp_domain') || '/resource/', 'dbpedia',
    registry_get('dbp_domain') || '/resource/' || registry_get('dbp_category') || ':', 'category',
    'http://dbpedia.org/property/', 'p',
    'http://dbpedia.openlinksw.com/wikicompany/', 'wikicompany',
    'http://dbpedia.org/class/yago/', 'yago',
    'http://www.w3.org/2003/01/geo/wgs84_pos#', 'geo',
    'http://www.geonames.org/ontology#', 'geonames',
    'http://xmlns.com/foaf/0.1/', 'foaf',
    'http://www.w3.org/2004/02/skos/core#', 'skos',
    'http://www.w3.org/2002/07/owl#', 'owl',
    'http://www.w3.org/2000/01/rdf-schema#', 'rdfs',
    'http://www.w3.org/1999/02/22-rdf-syntax-ns#', 'rdf',
    'http://www.w3.org/2001/XMLSchema#', 'xsd',
    'http://purl.org/dc/elements/1.1/', 'dc',
    'http://purl.org/dc/terms/', 'dcterms',
    'http://dbpedia.org/units/', 'units',
    'http://umbel.org/umbel/sc/', 'umbel-sc',
    'http://umbel.org/umbel/ac/', 'umbel-ac',
    'http://www.georss.org/georss/', 'georss',
    'http://sw.opencyc.org/2008/06/10/concept/en/', 'opencyc',
    'http://sw.opencyc.org/2008/06/10/concept/', 'opencyc',
    'http://mpii.de/yago/resource/', 'yago-res',
    'http://rdf.freebase.com/ns/', 'freebase',
    'http://dbpedia.org/ontology/', 'dbpedia-owl');
   l := length (arr);
   for (i := 0; i < l; i := i + 2)
      {
	XML_REMOVE_NS_BY_PREFIX (arr[i+1], 2);
	XML_SET_NS_DECL (arr[i+1], arr[i], 2);
      }
}
;

dbp_ldd_set_ns_decl ();

create procedure dbp_ldd_get_lang_by_q (in accept varchar, in lang varchar)
{
  declare format, itm varchar;
  declare arr, q any;
  declare i, l int;

  arr := split_and_decode (accept, 0, '\0\0,;');
  q := 0;
  l := length (arr);
  format := null;
  for (i := 0; i < l; i := i + 2)
    {
      declare tmp any;
      itm := trim(arr[i]);
      if (itm = lang)
	{
	  q := arr[i+1];
	  if (q is null)
	    q := 1.0;
	  else
	    {
	      tmp := split_and_decode (q, 0, '\0\0=');
	      if (length (tmp) = 2)
		q := atof (tmp[1]);
	      else
		q := 1.0;
	    }
	  goto ret;
	}
    }
  ret:
  if (q = 0 and lang = 'en')
    q := 0.002;
  if (q = 0 and not length (lang))
    q := 0.001;
  return q;
}
;

create procedure dbp_ldd_label (in _S any, in _G varchar, in lines any := null)
{
  declare best_str, meta, data any;
  declare best_q, q float;
  declare lang, langs varchar;
  declare retr int;

  retr := 1;

  declare exit handler for sqlstate '42000'
    {
      if (retr and __SQL_MESSAGE like '%Inference context %')
	{
	  rdfs_load_schema ('dbprdf-label', 'dbprdf-label');
	  retr := 0;
	  goto again;
	}
      return _S;
    };

again:
  if (__tag of IRI_ID = __tag (_S))
    _S := id_to_iri (_S);
  if (__tag of IRI_ID = __tag (_G))
    _G := id_to_iri (_G);

  langs := 'en';
  if (lines is not null)
    {
      langs := http_request_header_full (lines, 'Accept-Language', 'en');
    }
  exec (sprintf ('sparql  '||
  'select ?o (lang(?o)) where { graph <%S> { <%S> rdfs:label ?o } }', _G, _S), null, null, vector (), 0, meta, data);
  best_str := '';
  best_q := 0;
  if (length (data))
    {
      for (declare i, l int, i := 0, l := length (data); i < l; i := i + 1)
	{
	  q := dbp_ldd_get_lang_by_q (langs, data[i][1]);
          if (q > best_q)
	    {
	      best_str := data[i][0];
	      best_q := q;
	    }
	}
    }
  if (__tag of rdf_box = __tag (best_str))
    {
      __rdf_box_make_complete (best_str);
      best_str := rdf_box_data (best_str);
    }
  if (best_str <> '')
    {
      return best_str;
    }
  exec (sprintf ('sparql define input:inference "dbprdf-label" '||
  'select ?o (lang(?o)) where { graph <%S> { <%S> virtrdf:label ?o } }', _G, _S), null, null, vector (), 0, meta, data);
  best_str := '';
  best_q := 0;
  if (length (data))
    {
      for (declare i, l int, i := 0, l := length (data); i < l; i := i + 1)
	{
	  q := dbp_ldd_get_lang_by_q (langs, data[i][1]);
          if (q > best_q)
	    {
	      best_str := data[i][0];
	      best_q := q;
	    }
	}
    }
  if (__tag of rdf_box = __tag (best_str))
    {
      __rdf_box_make_complete (best_str);
      best_str := rdf_box_data (best_str);
    }
  return best_str;
}
;

create procedure dbp_ldd_type (in gr varchar, in subj varchar, out url varchar, in lines any := null)
{
  declare meta, data, ll any;
  ll := 'Thing';
  url := 'javascript:void()';

  if (__tag of IRI_ID = __tag (subj))
    subj := id_to_iri (subj);
  if (__tag of IRI_ID = __tag (gr))
    gr := id_to_iri (gr);

  if (length (gr))
    {
      declare langs any;
      --if (isvector (lines))
      --  langs := http_request_header_full (lines, 'Accept-Language', 'en');
      --else
        langs := 'en';	
      exec (sprintf ('sparql select (sql:BEST_LANGMATCH (?l, \'%S\', \'\')) ?tp from <%S> from virtrdf:schemas { <%S> <http://dbpedia.org/ontology/type>  ?tp . optional { ?tp rdfs:label ?l } }', langs, gr, subj), null, null, vector (), 0, meta, data);
      if (not length (data))
        exec (sprintf ('sparql select (sql:BEST_LANGMATCH (?l, \'%S\', \'\')) ?tp from <%S> from virtrdf:schemas { <%S> a ?tp . optional { ?tp rdfs:label ?l } filter (?tp like <http://dbpedia.org/ontology/%%>) }', langs, gr, subj), 
	  null, null, vector (), 0, meta, data);
      if (not length (data))
        exec (sprintf ('sparql select (sql:BEST_LANGMATCH (?l, \'%S\', \'\')) ?tp from <%S> from virtrdf:schemas { <%S> a ?tp . optional { ?tp rdfs:label ?l } }', langs, gr, subj), 
	  null, null, vector (), 0, meta, data);
      if (length (data))
	{
	  if (data[0][0] is not null and data[0][0] <> 0)
  	    ll := data[0][0];
	  else  
	    ll := dbp_ldd_uri_local_part (data[0][1]);
	  url := dbp_ldd_get_proxy (data[0][1]);
	}
    }
  if (__tag of rdf_box = __tag (ll))
    {
      __rdf_box_make_complete (ll);
      ll := rdf_box_data (ll);
    }
  return ll;
}
;

create procedure dbp_ldd_uri_local_part (in uri varchar)
{
  declare delim integer;
  declare uriSearch varchar;
  delim := -1;
  uriSearch := uri;
  delim := coalesce (strrchr (uriSearch, '/'), 0);
  delim := __max (delim, coalesce (strrchr (uriSearch, '#'), 0));
  delim := __max (delim, coalesce (strrchr (uriSearch, ':'), 0));
  if (delim > 0)
    uriSearch := subseq (uri, delim + 1);
  return uriSearch;
}
;

create procedure dbp_ldd_subject (in _S any, in _G varchar, in lines any := null)
{
  declare best_str, meta, data any;
  declare best_q, q float;
  declare lang, langs varchar;

  if (__tag of IRI_ID = __tag (_S))
    _S := id_to_iri (_S);
  if (__tag of IRI_ID = __tag (_G))
    _G := id_to_iri (_G);

  langs := 'en';
  if (lines is not null)
    {
      langs := http_request_header_full (lines, 'Accept-Language', 'en');
    }
  if (langs is not null)
    {
      langs := replace (langs, 'en-us', 'en');
      langs := replace (langs, 'en-uk', 'en');
    }
  best_str := '';
  exec (sprintf ('sparql select (sql:BEST_LANGMATCH (?l, \'%S\', \'en\')) ?tp where { graph <%S> { <%S> dbpprop:comment_live ?l } }', 
	langs, _G, _S), null, null, vector (), 0, meta, data);
  if (length (data) and data[0][0] is not null and data[0][0] <> 0)
    best_str := data[0][0];
  else
    {
      exec (sprintf ('sparql select (sql:BEST_LANGMATCH (?l, \'%S\', \'en\')) ?tp where { graph <%S> { <%S> rdfs:comment ?l } }', 
	    langs, _G, _S), null, null, vector (), 0, meta, data);
      if (length (data) and data[0][0] is not null and data[0][0] <> 0)
	best_str := data[0][0];
    }
  return best_str;
}
;

create procedure
dbp_ldd_trunc_uri (in s varchar, in maxlen int := 80)
{
  declare _s varchar;
  declare _h int; 

  _s := trim(s);
  _s := charset_recode (_s, 'UTF-8', '_WIDE_');

  if (length(_s) <= maxlen) return charset_recode (_s, '_WIDE_', 'UTF-8');
  _h := floor ((maxlen-3) / 2);
  _s := concat ("LEFT"(_s, _h), N'...', "RIGHT"(_s, _h-1));

  return charset_recode (_s, '_WIDE_', 'UTF-8');
}
;

create procedure dbp_ldd_split_url (in uri varchar, out pref varchar, out res varchar, in label varchar := null)
{
  declare delim any;
  declare uriSearch, nsPrefix any;

  delim := -1;
  uriSearch := uri;
  nsPrefix := null;
  if (not length (label))
    label := null;
  while (nsPrefix is null and delim <> 0)
    {
      delim := coalesce (strrchr (uriSearch, '/'), 0);
      delim := __max (delim, coalesce (strrchr (uriSearch, '#'), 0));
      delim := __max (delim, coalesce (strrchr (uriSearch, ':'), 0));
      nsPrefix := coalesce (__xml_get_ns_prefix (subseq (uriSearch, 0, delim + 1), 2),
      			    __xml_get_ns_prefix (subseq (uriSearch, 0, delim),     2));
      uriSearch := subseq (uriSearch, 0, delim);
    }
  if (nsPrefix is not null)
    {
      declare rhs varchar;
      rhs := subseq(uri, length (uriSearch) + 1, null);
      if (length (rhs))
	{
	  pref := nsPrefix;
	  if (regexp_match ('(_percent_[0-9A-F][0-9A-F])', rhs))
	    {
	      rhs := regexp_replace (rhs, '(_percent_)', '%', 1, null);
	    }
	  if (regexp_match ('%[0-9A-F][0-9A-F]', rhs))
	    {
	      declare tmp any;
	      tmp := split_and_decode (rhs)[0];
	      if (charset_recode (tmp, 'UTF-8', null))
		rhs := tmp;
	    }
	  rhs := dbp_ldd_trunc_uri (rhs);
	  res := coalesce (label, rhs);
	  return;
	}
    }
  pref := uri;
  res := null;
}
;

create procedure dbp_ldd_get_proxy (in x varchar)
{
  if (x like 'nodeID://%')
    return '/about/html/' || x;
  if (x like 'http://dbpedia.org/%' and http_request_header (http_request_header (), 'Host') <> 'dbpedia.org')
    return regexp_replace (x, 'http://dbpedia.org', 'http://'||http_request_header (http_request_header (), 'Host'));
  if (x like registry_get('dbp_domain') || '/%' and http_request_header (http_request_header (), 'Host') <> replace(registry_get('dbp_domain'),'http://',''))
    return regexp_replace (x, registry_get('dbp_domain'), 'http://'||http_request_header (http_request_header (), 'Host'));

  if (connection_get ('mappers_installed') = 1 and (
      x like 'http://www.w3.org/2002/07/owl%' or
      x like 'http://www.w3.org/1999/02/22-rdf-syntax-ns%' or
      x like 'http://www.w3.org/2000/01/rdf-schema%'))
    return '/about/html/' || replace (x, '#', '%01');

  return x;
}
;

--
-- make a vector of languages and their quality 
--
create procedure dbp_ldd_get_lang_acc (in lines any)
{
  declare accept, itm varchar;
  declare i, l, q int;
  declare ret, arr any;

  accept := 'en';
  if (lines is not null)
    {
      accept := http_request_header_full (lines, 'Accept-Language', 'en');
    }
  arr := split_and_decode (accept, 0, '\0\0,;');
  q := 0;
  l := length (arr);
  ret := make_array (l, 'any');
  for (i := 0; i < l; i := i + 2)
    {
      declare tmp any;
      itm := trim(arr[i]);
      if (itm like '%-%')
	itm := subseq (itm, 0, strchr (itm, '-'));
      q := arr[i+1];
      if (q is null)
	q := 1.0;
      else
	{
	  tmp := split_and_decode (q, 0, '\0\0=');
	  if (length (tmp) = 2)
	    q := atof (tmp[1]);
	  else
	    q := 1.0;
	}
      ret[i] := itm;
      ret[i+1] := q;
    }
  return ret;
}
;

create procedure dbp_ldd_str_lang_check (in lang any, in acc any)
{
  if (lang like '%-%')
    lang := subseq (lang, 0, strchr (lang, '-'));
  if (not length (lang))
    return 1;
  else if (position (lang, acc) > 0)
    return 1;
  else if (position ('*', acc) > 0)
    return 1;
  return 0;
}
;

create procedure dbp_ldd_http_print_l (in p_text any, inout odd_position int, in rev int := 0)
{
   declare short_p, p_prefix, int_redirect, href, title any;

   odd_position :=  odd_position + 1;
   dbp_ldd_split_url (p_text, p_prefix, short_p);
   href := dbp_ldd_get_proxy (p_text);
   title := p_text;
   if (title = href)
     title := '';
   else   
     title := sprintf (' title="%V"', title);

   http (sprintf ('<tr class="%s"><td class="property">', either(mod (odd_position, 2), 'odd', 'even')));
   if (rev) http ('is ');
   if (short_p is not null)
      http (sprintf ('<a class="uri" href="%V"%s><small>%s:</small>%s</a>\n', href, title, p_prefix, short_p));
   else
      http (sprintf ('<a class="uri" href="%V"%s>%s</a>\n', href, title, p_prefix));
   if (rev) http (' of');
   http ('</td><td><ul>\n');
}
;

create procedure dbp_ldd_rel_print (in val any, in rel any, in obj any, in flag int := 0, in lang varchar := null)
{
  declare delim, delim1, delim2, delim3 integer;
  declare inx int;
  declare nss, loc, res, nspref, lang_def varchar;

  delim1 := coalesce (strrchr (val, '/'), -1);
  delim2 := coalesce (strrchr (val, '#'), -1);
  delim3 := coalesce (strrchr (val, ':'), -1);
  delim := __max (delim1, delim2, delim3);
  nss := '';
  loc := val;
  if (delim < 0) return loc;
  nss := subseq (val, 0, delim + 1);
  loc := subseq (val, delim + 1);
  res := '';

  nspref := __xml_get_ns_prefix (nss, 2);
  if (nspref is null)
    {
      inx := coalesce (connection_get ('ns_ctr'), 0);
      connection_set ('ns_ctr', inx + 1);
      nspref := sprintf ('ns%d', inx);
    }


  if (nspref is not null and nspref not in ('dbpprop', 'owl'))
    nss := sprintf (' xmlns:%s="%s"', nspref, nss);
  else  
    nss := '';
  if (flag)
    loc := sprintf ('property="%s:%s"', nspref, loc);
  else if (rel)
    loc := sprintf ('rel="%s:%s"', nspref, loc);
  else
    loc := sprintf ('rev="%s:%s"', nspref, loc);
  --if (obj is not null)
  --  res := sprintf (' resource="%V"', obj);  
  lang_def := '';
  if (isstring (lang) and lang <> '')
    lang_def := sprintf (' xml:lang="%s"', lang);
  return concat (loc, res, nss, lang_def);
}
;

create procedure dbp_ldd_http_print_r (in _object any, in org int := 0, in label varchar, in pred varchar, in rel int, inout acc any)
{
   declare lang, rdfs_type, rdfa, visible any;

   lang := DB.DBA.RDF_LANGUAGE_OF_OBJ (_object);
   visible := dbp_ldd_str_lang_check (lang, acc);
   rdfs_type := DB.DBA.RDF_DATATYPE_OF_OBJ (_object);
   rdfa := dbp_ldd_rel_print (id_to_iri (pred), rel, null, 1, lang);

   http (sprintf ('\t<li%s><span class="literal">', case visible when 0 then ' style="display:none;"' else '' end));

again:
   if (__tag (_object) = 246)
     {
       declare dat any;
       dat := __rdf_sqlval_of_obj (_object, 1);
       _object := dat;
       goto again;
     }
   else if (__tag (_object) = 189)
     {
       http (sprintf ('<span %s>%d</span>', rdfa, _object));
       lang := 'xsd:integer';
     }
   else if (__tag (_object) = 190)
     {
       http (sprintf ('<span %s>%f</span>', rdfa, _object));
       lang := 'xsd:float';
     }
   else if (__tag (_object) = 191)
     {
       http (sprintf ('<span %s>%f</span>', rdfa, _object));
       lang := 'xsd:double';
     }
   else if (__tag (_object) = 219)
     {
       http (sprintf ('<span %s>%s</span>', rdfa, cast (_object as varchar)));
       lang := 'xsd:double';
     }
   else if (__tag (_object) = 182)
     {
       string_type:
       http (sprintf ('<span %s>%s</span>', rdfa, _object));
       lang := '';
     }
   else if (__tag (_object) = 211)
     {
       http (sprintf ('<span %s>%s</span>', rdfa, datestring (_object)));
       lang := 'xsd:date';
     }
   else if (__tag (_object) = 243)
     {
       declare _url, p_t, s_t, _label any;

       _label := null;
       if (pred = rdf_sas_iri ())
	 _label := label;
       _url := id_to_iri (_object);
       if (_url is null)
	 {
	   _object := 'unknown IRI_ID';
	   goto string_type;
	 }
       if (_url like 'http://sw.opencyc.org/2008/06/10/concept/%')
	 {
	   declare h_url varchar;
	   declare stat, msg, data, meta any;
	   stat := '00000';
	   exec (sprintf ('sparql select * from <http://dbpedia.org/resource/classes/opencyc-readable#> where { ?x owl:sameAs <%s> } limit 1', _url),
	       stat, msg, vector (), 0, meta, data);
	   if (length (data))
	     h_url := data[0][0];
	   else
	     h_url := _url;
	   dbp_ldd_split_url (h_url, p_t, s_t);
	 }
       else
	 dbp_ldd_split_url (_url, p_t, s_t, _label);

       rdfa := dbp_ldd_rel_print (id_to_iri (pred), rel, _url, 0, lang);
       if (s_t is null)
	 {
	   http (sprintf ('<a class="uri" %s href="%s">%s</a>', 
		 rdfa, case when org then _url else dbp_ldd_get_proxy(_url) end, _url));
	 }
       else
	 {
	   http (sprintf ('<a class="uri" %s href="%s"><small>%s</small>:%s</a>',
		 rdfa, case when org then _url else dbp_ldd_get_proxy (_url) end, p_t, s_t));
	 }
     }
   else if (__tag (_object) = 238)
     {
       http (sprintf ('<span %s>', rdfa));
       http (st_astext (_object));
       http ('</span>');
     }
   else
     http (sprintf ('FIXME %i', __tag (_object)));

   if (lang is not NULL and lang <> '')
     {
       http (sprintf ('<small> (%s)</small>', lang));
     }

   http ('</span></li>\n');
   return visible;
}
;

create procedure dbp_virt_info ()
{
  http ('<a href="http://www.openlinksw.com/virtuoso/">OpenLink Virtuoso</a> version '); 
  http (sys_stat ('st_dbms_ver')); 
  http (', on ');
  http (sys_stat ('st_build_opsys_id')); http (','); 
  http (case when sys_stat ('cl_run_local_only') = 1 then 'Single' else 'Cluster' end); http (' Edition ');
  http (case when sys_stat ('cl_run_local_only') = 0 then sprintf ('(%d nodes)', sys_stat ('cl_n_hosts')) else '' end); 
}
;

create procedure dbp_wikipedia_cc_by_sa (in _S any, in _G any)
{
  declare meta, data any;
  declare wiki_link varchar;

  if (__tag of IRI_ID = __tag (_S))
    _S := id_to_iri (_S);
  if (__tag of IRI_ID = __tag (_G))
    _G := id_to_iri (_G);

  exec (sprintf ('sparql  '||
  'select ?o where { graph <%S> { <%S> foaf:page ?o } } LIMIT 1', _G, _S), null, null, vector (), 0, meta, data);

  if (length (data))
    wiki_link := data[0][0];
  else
    wiki_link := 'http://www.wikipedia.org/';
    
  http ('This content was extracted from ');
  http (sprintf ('<a href="%V">Wikipedia</a>', wiki_link));
  http (' and is licensed under the ');
  http ('<a href="http://creativecommons.org/licenses/by-sa/3.0/">Creative Commons Attribution-ShareAlike 3.0 Unported License</a>\n');
} 
;

create procedure 
dbp_check_if_modified (in lines any, in graph any)
{
  declare since, modified, pname any;
  declare exit handler for sqlstate '*' 
    {
      return 0;
    };
  since := http_request_header (lines, 'If-Modified-Since', null, null);
  if (since is null) return 0;
  since := http_string_date (since);
  pname := registry_get ('dbp_last_modification');
  if (isstring (pname) and __proc_exists (pname) is not null)
    modified := call (pname) (lines, graph);
  else  
    modified := (select max (LL_DONE) from LOAD_LIST where LL_GRAPH = graph);
  modified := dt_set_tz (modified, 0);  
  --dbg_obj_print_vars (since, modified, gt (since, modified), graph);
  if (modified is null) return 0;
  if (modified > since) return 0;
  http_rewrite ();
  http_status_set (304);
  return 1;
}
;
