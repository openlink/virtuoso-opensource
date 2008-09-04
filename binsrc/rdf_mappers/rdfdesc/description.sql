


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

create procedure rdfdesc_http_url (in url varchar)
{
  declare host, pref varchar;
  host := http_request_header(http_request_header(), 'Host', null, null);
  --pref := 'http://'||host||'/proxy/rdf/';
  --if (url like pref || '%')
  --  url := subseq (url, length (pref));
  pref := 'http://'||host||'/proxy/html/';
  if (url not like pref || '%')
    url := pref || url;
  url := replace (url, '#', '%23');
  return url;
};

create procedure rdfdesc_http_print_l (in p_text any, inout odd_position int)
{
   declare short_p, p_prefix, int_redirect, url any;

   odd_position :=  odd_position + 1;
   short_p := rdfdesc_page_get_short (p_text);
   p_prefix := rdfdesc_page_get_type (p_text);
   url := rdfdesc_http_url (p_text);

   http (sprintf ('<tr class="%s"><td class="property">', either(mod (odd_position, 2), 'odd', 'even')));

   if (p_prefix = p_text)
     {
       http (sprintf ('<a class="uri" href="%s" title="%s">%s</a>\n', url, p_text, p_text));
     }
   else
     {
       http (sprintf ('<a class="uri" href="%s" title="%s"><small>%s:</small>%s</a>\n', url, p_text, p_prefix, short_p));
     }

   http ('</td><td><ul>');
}
;

create procedure rdfdesc_http_print_r (in _object any)
{
   declare lang, rdfs_type any;

   if (__tag (_object) = 230)
     {
       rdfs_type := 'XMLLiteral';
       lang := '';
     }
   else
     {
       lang := DB.DBA.RDF_LANGUAGE_OF_OBJ (_object);
       rdfs_type := DB.DBA.RDF_DATATYPE_OF_OBJ (_object);
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
   else if (__tag (_object) = 243 or (isstring (_object) and __box_flags (_object)= 1))
     {
       declare _url, p_t any;

       if (__tag of IRI_ID = __tag (_object))
	 _url := id_to_iri (_object);
       else
	 _url := _object;
       p_t  := rdfdesc_page_get_type (_url);
       if (p_t = _url)
	 {
	   http (sprintf ('<a class="uri" href="%s">%s</a>', rdfdesc_http_url (_url), _url));
	 }
       else
	 {
	   http (sprintf ('<a class="uri" href="%s"><small>%s</small>:%s</a>',
		 rdfdesc_http_url (_url), p_t, rdfdesc_page_get_short (_url)));
	 }

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
       http (sprintf ('<small> (%s)</small>', rdfs_type));
     }
   else
     http (sprintf ('FIXME %i', __tag (_object)));

   if (lang is not NULL and lang <> '')
     {
       http (sprintf ('<small> (%s)</small>', lang));
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
