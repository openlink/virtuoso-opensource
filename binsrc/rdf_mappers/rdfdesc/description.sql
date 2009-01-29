
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
foaf:nick rdfs:subPropertyOf virtrdf:label .', '', 'virtrdf-label');

rdfs_rule_set ('virtrdf-label', 'virtrdf-label');

create procedure rdfdesc_get_lang_by_q (in accept varchar, in lang varchar)
{
  declare format, itm, q varchar;
  declare arr any;
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

create procedure rdfdesc_label (in _S any, in _G varchar, in lines any := null)
{
  declare best_str, meta, data any;
  declare best_q, q float;
  declare lang, langs varchar;

  langs := 'en';
  if (lines is not null)
    {
      langs := http_request_header_full (lines, 'Accept-Language', 'en');
    }
  exec (sprintf ('sparql define input:inference "virtrdf-label" '||
  'select ?o (lang(?o)) where { graph <%S> { <%S> virtrdf:label ?o } }', _G, _S), null, null, vector (), 0, meta, data);
  best_str := '';
  best_q := 0;
  if (length (data))
    {
      for (declare i, l int, i := 0, l := length (data); i < l; i := i + 1)
	{
	  q := rdfdesc_get_lang_by_q (langs, data[i][1]);
	  --dbg_obj_print (data[i][0], langs, data[i][1], q);
          if (q > best_q)
	    {
	      best_str := data[i][0];
	      best_q := q;
	    }
	}
    }
  return best_str;
}
;

create procedure rdfdesc_page_get_type (in val any)
{

  declare delim, delim1, delim2, delim3 integer;
  declare pref, res varchar;

  delim1 := coalesce (strrchr (val, '/'), -1);
  delim2 := coalesce (strrchr (val, '#'), -1);
  delim3 := coalesce (strrchr (val, ':'), -1);
  delim := __max (delim1, delim2, delim3);

  if (delim < 0)
    return val;

  pref := subseq (val, 0, delim+1);

  if (pref = val)
    return val;

  if (strstr (val, 'http://dbpedia.org/resource/') = 0 ) return 'dbpedia';
  if (strstr (val, 'http://dbpedia.org/property/') = 0 ) return 'p';
  if (strstr (val, 'http://dbpedia.openlinksw.com/wikicompany/') = 0 ) return 'wikicompany';
  if (strstr (val, 'http://dbpedia.org/class/yago/') = 0 ) return 'yago';
  if (strstr (val, 'http://www.w3.org/2003/01/geo/wgs84_pos#') = 0 ) return 'geo';
  if (strstr (val, 'http://www.geonames.org/ontology#') = 0 ) return 'geonames';
  if (strstr (val, 'http://xmlns.com/foaf/0.1/') = 0 ) return 'foaf';
  if (strstr (val, 'http://www.w3.org/2004/02/skos/core#') = 0 ) return 'skos';
  if (strstr (val, 'http://www.w3.org/2002/07/owl#') = 0 ) return 'owl';
  if (strstr (val, 'http://www.w3.org/2000/01/rdf-schema#') = 0 ) return 'rdfs';
  if (strstr (val, 'http://www.w3.org/1999/02/22-rdf-syntax-ns#') = 0 ) return 'rdf';
  if (strstr (val, 'http://www.w3.org/2001/XMLSchema#') = 0 ) return 'xsd';
  if (strstr (val, 'http://purl.org/dc/elements/1.1/') = 0 ) return 'dc';
  if (strstr (val, 'http://purl.org/dc/terms/') = 0 ) return 'dcterms';
  if (strstr (val, 'http://dbpedia.org/units/') = 0 ) return 'units';
  if (strstr (val, 'http://www.w3.org/1999/xhtml/vocab#') = 0 ) return 'xhv';
  if (strstr (val, 'http://rdfs.org/sioc/ns#') = 0 ) return 'sioc';
  if (strstr (val, 'http://purl.org/ontology/bibo/') = 0 ) return 'bibo';

  res := __xml_get_ns_prefix (pref, 2);
  if (res is null)
    return val;
  return res;
}
;

--! used to return curie or prefix:label for sameAs properties
create procedure rdfdesc_uri_curie (in uri varchar, in label varchar := null)
{
  declare delim integer;
  declare uriSearch, nsPrefix varchar;

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
      if (not length (rhs))
		return uri;
      else
	return nsPrefix || ':' || coalesce (label, rhs);
  }
  return uri;
}
;


create procedure rdfdesc_http_url (in url varchar)
{
  declare host, pref varchar;
  host := http_request_header(http_request_header(), 'Host', null, null);
  pref := 'http://'||host||'/about/html/';
  if (url not like pref || '%')
    url := pref || url;
  url := replace (url, '#', '%23');
  return url;
};

create procedure rdfdesc_http_print_l (in p_text any, inout odd_position int, in r int := 0)
{
   declare short_p, p_prefix, int_redirect, url any;

   odd_position :=  odd_position + 1;
   p_prefix := rdfdesc_uri_curie (p_text);
   url := rdfdesc_http_url (p_text);

   http (sprintf ('<tr class="%s"><td class="property">', either(mod (odd_position, 2), 'odd', 'even')));
   if (r) http ('is ');
   http (sprintf ('<a class="uri" href="%s" title="%s">%s</a>\n', url, p_prefix, p_prefix));
   if (r) http (' of');

   http ('</td><td><ul class="obj">');
}
;

create procedure rdfdesc_http_print_r (in _object any, in prop any, in label any)
{
   declare lang, rdfs_type any;

   if (__tag (_object) = 230)
     {
       rdfs_type := 'XMLLiteral';
       lang := '';
     }
   else
     {
       declare exit handler for sqlstate '*' {
         lang := '';
	 rdfs_type := 'http://www.w3.org/2001/XMLSchema#string';
	 goto endg;
       };
       lang := DB.DBA.RDF_LANGUAGE_OF_OBJ (_object);
       rdfs_type := DB.DBA.RDF_DATATYPE_OF_OBJ (_object);
       endg:;
     }

   http ('<li><span class="literal">');
again:
   if (__tag (_object) = 246)
     {
       declare dat any;
       dat := __rdf_sqlval_of_obj (_object, 1);
       _object := dat;
       goto again;
     }
   else if (__tag (_object) = 243 or (isstring (_object) and (__box_flags (_object)= 1 or _object like 'nodeID://%')))
     {
       declare _url, _label any;

       if (__tag of IRI_ID = __tag (_object))
	 _url := id_to_iri (_object);
       else
	 _url := _object;

       if (prop = __id2in (rdf_sas_iri ()))
	 _label := label;
       else
	 _label := null;

       http (sprintf ('<a class="uri" href="%s">%s</a>', rdfdesc_http_url (_url), rdfdesc_uri_curie(_url, _label)));

     }
   else if (__tag (_object) = 189)
     {
       http (sprintf ('%d', _object));
       lang := 'xsd:integer';
     }
   else if (__tag (_object) = 190)
     {
       http (sprintf ('%f', _object));
       lang := 'xsd:float';
     }
   else if (__tag (_object) = 191)
     {
       http (sprintf ('%d', _object));
       lang := 'xsd:double';
     }
   else if (__tag (_object) = 219)
     {
       http (sprintf ('%s', cast (_object as varchar)));
       lang := 'xsd:double';
     }
   else if (__tag (_object) = 182)
     {
       http (_object);
       lang := '';
     }
   else if (__tag (_object) = 211)
     {
       http (sprintf ('%s', datestring (_object)));
       lang := 'xsd:date';
     }
   else if (__tag (_object) = 230)
     {
       _object := serialize_to_UTF8_xml (_object);
       _object := replace (_object, '<xhtml:', '<');
       _object := replace (_object, '</xhtml:', '</');
       http (_object);
       http (sprintf ('(%s)', rdfs_type));
     }
   else if (__tag (_object) = 225)
     http (charset_recode (_object, '_WIDE_', 'UTF-8'));
   else
     http (sprintf ('FIXME %i', __tag (_object)));

   if (lang is not NULL and lang <> '')
     {
       http (sprintf ('(%s)', lang));
     }

   http ('</span></li>');
}
;

create procedure rdfdesc_page_get_short (in val any)
{
  declare ret, pos any;
  declare delim1, delim2, delim3 integer;

  ret := split_and_decode (val, 0, '\0\0/');
  ret := ret[length(ret)-1];

  delim1 := coalesce (strrchr (val, '/'), -1);
  delim2 := coalesce (strrchr (val, '#'), -1);
  delim3 := coalesce (strrchr (val, ':'), -1);
  pos := __max (delim1, delim2, delim3);

  if (pos is not NULL)
    {
      ret := subseq (val, pos + 1);
    }

   return ret;
}
;

-- proxy rules change
DB.DBA.URLREWRITE_CREATE_REGEX_RULE ('ext_http_proxy_rule_2', 1,
      '/proxy/html/(.*)', vector ('g'), 1,
      '/rdfdesc/description.vsp?g=%U', vector ('g'), null, null, 2);

DB.DBA.URLREWRITE_CREATE_RULELIST ('ext_http_proxy_rule_list1', 1, vector ('ext_http_proxy_rule_1', 'ext_http_proxy_rule_2'));

DB.DBA.EXEC_STMT ('grant SPARQL_SPONGE to "SPARQL"', 0);

-- /* extended http proxy service */
create procedure virt_proxy_init_about ()
{
  if (registry_get ('DB.DBA.virt_proxy_init_about_state') = '1.0')
    return;

  DB.DBA.URLREWRITE_CREATE_REGEX_RULE ('ext_about_http_proxy_rule_1', 1,
      '/about/([^/\?\&]*)?/?([^/\?\&:]*)/(.*)', vector ('force', 'login', 'url'), 2,
      '/about?url=%U&force=%U&login=%U', vector ('url', 'force', 'login'), null, null, 2);

DB.DBA.URLREWRITE_CREATE_REGEX_RULE ('ext_about_http_proxy_rule_2', 1,
      '/about/html/(.*)', vector ('g'), 1,
      '/rdfdesc/description.vsp?g=%U', vector ('g'), null, null, 2);

  DB.DBA.URLREWRITE_CREATE_RULELIST ('ext_about_http_proxy_rule_list1', 1, vector ('ext_about_http_proxy_rule_1', 'ext_about_http_proxy_rule_2'));
  DB.DBA.VHOST_REMOVE (lpath=>'/about');
  DB.DBA.VHOST_DEFINE (lpath=>'/about', ppath=>'/SOAP/Http/ext_http_proxy', soap_user=>'PROXY',
      opts=>vector('url_rewrite', 'ext_about_http_proxy_rule_list1'));
  registry_set ('DB.DBA.virt_proxy_init_about_state', '1.1');
}
;

virt_proxy_init_about ()
;

drop procedure virt_proxy_init_about;
