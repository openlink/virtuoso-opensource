--
--
--  $Id$
--
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

TTLP (
'@prefix foaf: <http://xmlns.com/foaf/0.1/> .
@prefix dc: <http://purl.org/dc/elements/1.1/> .
@prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .
@prefix virtrdf: <http://www.openlinksw.com/schemas/virtrdf#> .
@prefix fbase: <http://rdf.freebase.com/ns/type.object.> .
@prefix skos: <http://www.w3.org/2008/05/skos#> .
@prefix bibo: <http://purl.org/ontology/bibo/> .
@prefix gr: <http://purl.org/goodrelations/v1#> .
@prefix cb: <http://www.crunchbase.com/> .
@prefix dcterms: <http://purl.org/dc/terms/> .
@prefix owl: <http://www.w3.org/2002/07/owl#> .
@prefix geo: <http://www.w3.org/2003/01/geo/wgs84_pos#> .
@prefix og: <http://opengraphprotocol.org/schema/> .

dc:title rdfs:subPropertyOf virtrdf:label .
rdfs:label rdfs:subPropertyOf virtrdf:label .
fbase:name rdfs:subPropertyOf virtrdf:label .
foaf:name rdfs:subPropertyOf virtrdf:label .
<http://s.opencalais.com/1/pred/name> rdfs:subPropertyOf virtrdf:label .
foaf:nick rdfs:subPropertyOf virtrdf:label .
<http://www.w3.org/2004/02/skos/core#prefLabel> rdfs:subPropertyOf virtrdf:label .
skos:prefLabel rdfs:subPropertyOf virtrdf:label .
<http://www.geonames.org/ontology#name> rdfs:subPropertyOf virtrdf:label .
<http://purl.org/dc/terms/title> rdfs:subPropertyOf virtrdf:label .
foaf:accountName rdfs:subPropertyOf virtrdf:label .
bibo:shortTitle rdfs:subPropertyOf virtrdf:label .
<http://s.opencalais.com/1/pred/name> rdfs:subPropertyOf foaf:name .
cb:source_description rdfs:subPropertyOf foaf:name .
<http://s.opencalais.com/1/type/er/Company> rdfs:subClassOf gr:BusinessEntity .
gr:BusinessEntity rdfs:subClassOf foaf:Organization .
<http://dbpedia.org/ontology/Company> rdfs:subClassOf gr:BusinessEntity .
<http://purl.org/ontology/mo/MusicArtist> rdfs:subClassOf foaf:Person .
foaf:maker rdfs:subClassOf dc:creator .
<http://dbpedia.org/property/name> rdfs:subPropertyOf foaf:name .
<http://www.w3.org/2002/12/cal/ical#summary> rdfs:subPropertyOf rdfs:label .
<http://usefulinc.com/ns/doap#name> rdfs:subPropertyOf rdfs:label .
foaf:topic rdfs:subPropertyOf dcterms:references .
<http://opengraphprotocol.org/schema/title> owl:equivalentProperty <http://opengraphprotocol.org/schema/title#this> .
<http://rdfs.org/ns/void#vocabulary> owl:equivalentProperty <http://www.openlinksw.com/schema/attribution/isDescribedUsing> .
<http://aims.fao.org/aos/geopolitical.owl#nameListEN> rdfs:subPropertyOf rdfs:label .
<http://aims.fao.org/aos/geopolitical.owl#hasMinLatitude> rdfs:subPropertyOf geo:lat .
<http://aims.fao.org/aos/geopolitical.owl#hasMinLongitude> rdfs:subPropertyOf geo:long .
og:latitude rdfs:subPropertyOf geo:lat .
og:longitude rdfs:subPropertyOf geo:long .
<http://uberblic.org/ontology/latitude> rdfs:subPropertyOf geo:lat .
<http://uberblic.org/ontology/longitude> rdfs:subPropertyOf geo:long .
', '', 'virtrdf-label');

rdfs_rule_set ('virtrdf-label', 'virtrdf-label');

--
-- make a vector of languages and their quality
--
create procedure rdfdesc_get_lang_acc (in lines any)
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

create procedure rdfdesc_str_lang_check (in lang any, in acc any)
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

create procedure rdfdesc_get_lang_by_q (in accept varchar, in lang varchar)
{
  declare itm varchar;
  declare arr, q any;
  declare i, l int;

  arr := split_and_decode (accept, 0, '\0\0,;');
  q := 0;
  l := length (arr);
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

create procedure rdfdesc_buy_link (in _G varchar, in _S varchar)
{
  declare ret any;
  ret := (sparql 
  define input:storage "" 
  prefix gr: <http://purl.org/goodrelations/v1#>
  prefix owl: <http://www.w3.org/2002/07/owl#>
  select ?sas { graph `iri(?:_G)` { ?s a gr:Offering ; owl:sameAs ?sas }});
  return ret;
}
;

create procedure
rdfdesc_trunc_uri (in s varchar, in maxlen int := 80)
{
  declare _s varchar;
  declare _h int;

  _s := trim(s);

  if (length(_s) <= maxlen) return _s;
  _h := floor ((maxlen-3) / 2);
  _s := sprintf ('%s...%s', "LEFT"(_s, _h), "RIGHT"(_s, _h-1));

  return _s;
}
;

create procedure rdfdesc_rel_print (in val any, in rel any, in obj any, in flag int := 0, in lang varchar := '')
{
  declare delim, delim1, delim2, delim3 integer;
  declare inx int;
  declare nss, loc, res, nspref, lang_def varchar;

  delim1 := coalesce (strrchr (val, '/'), -1);
  delim2 := coalesce (strrchr (val, '#'), -1);
  delim3 := coalesce (strrchr (val, ':'), -1);
  delim := __max (delim1, delim2, delim3);
  nss := null;
  loc := val;
  if (delim < 0) return loc;
  nss := subseq (val, 0, delim + 1);
  loc := subseq (val, delim + 1);
  res := '';

  nspref := __xml_get_ns_prefix (nss, 2);
  if (nspref is null)
    {
      inx := connection_get ('ns_ctr');
      connection_set ('ns_ctr', inx + 1);
      nspref := sprintf ('ns%d', inx);
    }


  nss := sprintf ('xmlns:%s="%s"', nspref, nss);
  if (flag)
    loc := sprintf ('property="%s:%s"', nspref, loc);
  else if (rel)
    loc := sprintf ('rel="%s:%s"', nspref, loc);
  else
    loc := sprintf ('rev="%s:%s"', nspref, loc);
  if (obj is not null)
    res := sprintf (' resource="%V" ', obj);
  if (isstring (lang_def) and length (lang_def))
    lang_def := sprintf (' xml:lang="%s"', lang);
  else
    lang_def := '';
  return concat (loc, ' ', res, ' ', nss);
}
;

--! used to return curie or prefix:label for sameAs properties
create procedure rdfdesc_uri_curie (in uri varchar, in label varchar := null)
{
  declare delim integer;
  declare uriSearch, nsPrefix, ret varchar;

  delim := -1;
  uriSearch := uri;
  nsPrefix := null;
  if (not length (label))
    label := null;
  ret := uri;
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
	ret := uri;
      else
	ret := nsPrefix || ':' || coalesce (label, rhs);
    }
  return rdfdesc_trunc_uri (ret);
}
;

--! used to return local part of an iri
create procedure rdfdesc_uri_local_part (in uri varchar)
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


create procedure rdfdesc_http_url (in url varchar)
{
  declare host, pref, pref2, proxy_iri_fn, xhost varchar;
  declare url_sch varchar;
  declare ua, lines any;

  proxy_iri_fn := connection_get ('proxy_iri_fn'); -- set inside description.vsp to indicate local browsing of an 3-d party dataset
  if (proxy_iri_fn is not null)
    {
      declare ret varchar;
      -- if it's local browsing, then we call specific function
      ret := call (proxy_iri_fn || '_get_proxy_iri') (url);
      return ret;
    }
  lines := http_request_header();
  host := null;
  xhost := http_request_header(lines, 'X-Forwarded-For', null, null);
  if (xhost is not null)
    {
      declare ta any;
      ta := split_and_decode (xhost, 0, '\0\0\,');
      if (length (ta) > 1)
	{
	  host := trim (ta[1]);
	  host := tcpip_gethostbyaddr (host);
	}
    }
  if (host is null)
    host := http_request_header(lines, 'Host', null, null);
  pref := 'http://'||host||'/about/html/';
  pref2 := 'http://'||host||'/about/id/';
  if (url not like pref || '%' and url not like pref2 || '%')
    {
      ua := rfc1808_parse_uri (url);
      url_sch := ua[0];
      ua [0] := '';
      if (url_sch = 'nodeID')
	ua [2] := '';
      url := vspx_uri_compose (ua);
      url := ltrim (url, '/');
      url := pref || url_sch || '/' || url;
    }
  url := replace (url, '#', '%01');
  return url;
};

create procedure rdfdesc_http_print_l (in prop_iri any, inout odd_position int, in r int := 0)
{
   declare short_p, p_prefix, int_redirect, url any;

   odd_position :=  odd_position + 1;
   p_prefix := rdfdesc_uri_curie (prop_iri);
   url := rdfdesc_http_url (prop_iri);

   http (sprintf ('<tr class="%s"><td class="property">', either(mod (odd_position, 2), 'odd', 'even')));
   http (sprintf ('<a class="uri" href="%s" title="%s">%s</a>\n', url, p_prefix, rdfdesc_prop_label (prop_iri)));

   http ('</td><td><ul class="obj">');
}
;

create procedure rdfdesc_is_external (in url varchar, in prop varchar)
{
  if (prop = __id2in (rdf_sas_iri ()))
    return 1;
  if (prop = 'http://www.w3.org/2000/01/rdf-schema#seeAlso' and url not like 'http://%/about/id/%')
    return 1;
  return 0;
}
;

create procedure rdfdesc_http_print_r (in _object any, in prop any, in label any, in rel int := 1, inout acc any)
{
   declare lang, rdfs_type, rdfa, prop_l, prop_n  any;
   declare visible int;

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
   rdfa := rdfdesc_rel_print (prop, rel, null, 1, lang);
   visible := rdfdesc_str_lang_check (lang, acc);

   http (sprintf ('\t<li%s><span class="literal">', case visible when 0 then ' style="display:none;"' else '' end));
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

       -- label for curie local part disabled
       if (0 and prop = __id2in (rdf_sas_iri ()))
	 _label := label;
       else
	 _label := null;

       rdfa := rdfdesc_rel_print (prop, rel, _url, 0, null);
       if (prop = 'http://bblfish.net/work/atom-owl/2006-06-06/#content' and _object like '%#content%')
	 {
	   declare src any;
	   whenever not found goto usual_iri;
	   select id_to_iri (O) into src from DB.DBA.RDF_QUAD where
	   	S = iri_to_id (_object, 0) and P = iri_to_id ('http://bblfish.net/work/atom-owl/2006-06-06/#src', 0);
	   http (sprintf ('<div id="x_content" style="width:100%%; height:300px;margin-top:3px;margin-bottom:3px;"><iframe src="%s" width="100%%" height="100%% frameborder="0"><p>Your browser does not support iframes.</p></iframe></div><br/>', src));
	 }
       else if (http_mime_type (_url) like 'image/%' and _url not like 'http://%/about/id/%')
	 http (sprintf ('<a class="uri" %s href="%s"><img src="%s" height="160" border="0"/></a>', rdfa, rdfdesc_http_url (_url), _url));
       else if (_url like 'mailto:%')
	 {
	   http (sprintf ('<a class="uri" %s href="%s">%s&nbsp;<img src="images/mail.png" title="Send Mail" border="0"/></a>', rdfa, _url, rdfdesc_uri_curie(_url, _label)));
	 }
       else if (_url like 'tel:%')
	 {
	   http (sprintf ('<a class="uri" %s href="%s">%s&nbsp;<img src="images/phone.gif" title="Make Call" border="0"/></a>', rdfa, _url, rdfdesc_uri_curie(_url, _label)));
	 }
       else
	 {
	   usual_iri:
	   http (sprintf ('<a class="uri" %s href="%s">%s</a>', rdfa, rdfdesc_http_url (_url), rdfdesc_uri_curie(_url, _label)));
	   if (rdfdesc_is_external (_url, prop))
	     http (sprintf ('&nbsp;<a class="uri" href="%s"><img src="images/goout.gif" title="Open Actual (X)HTML page" border="0"/></a>', _url));
	 }

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
       http (sprintf ('<span %s>%d</span>', rdfa, _object));
       lang := 'xsd:double';
     }
   else if (__tag (_object) = 219)
     {
       http (sprintf ('<span %s>%s</span>', rdfa, cast (_object as varchar)));
       lang := 'xsd:double';
     }
   else if (__tag (_object) = 182)
     {
       -- CMSB
       declare _href, image_ext varchar;

       http (sprintf ('<span %s>', rdfa));
       if (isstring(_object) and _object like 'http://%')
       {
	 _href := rdfdesc_http_url (_object);
	 image_ext := subseq(lcase(_object), strrchr(_object, '.') + 1);
	 if (image_ext is not null)
	 {
	   _href := case
	    when (image_ext = 'bmp') then _object
	    when (image_ext = 'gif') then _object
	    when (image_ext = 'jpeg') then _object
	    when (image_ext = 'jpg') then _object
	    when (image_ext = 'png') then _object
	    when (image_ext = 'svg') then _object
	    when (image_ext = 'tiff') then _object
	    when (image_ext = 'tif') then _object
	    else
              rdfdesc_http_url (_object)
	    end;
	 }
         http (sprintf ('<a class="uri" href="%s">%s</a>', _href, _object));
       }
       else
       -- CMSB
         http (_object);
       http ('</span>');
       lang := '';
     }
   else if (__tag (_object) = 211)
     {
       http (sprintf ('<span %s>%s</span>', rdfa, datestring (_object)));
       lang := 'xsd:date';
     }
   else if (__tag (_object) = 230)
     {
       _object := serialize_to_UTF8_xml (_object);
       _object := replace (_object, '<xhtml:', '<');
       _object := replace (_object, '</xhtml:', '</');
       http (sprintf ('<span %s>', rdfa));
       http (_object);
       http ('</span>');
       if (isstring (rdfs_type) and length (rdfs_type))
	 http (sprintf ('(%s)', rdfs_type));
     }
   else if (__tag (_object) = 225)
     {
       http (sprintf ('<span %s>', rdfa));
       http (charset_recode (_object, '_WIDE_', 'UTF-8'));
       http ('</span>');
     }
   else if (__tag (_object) = 238)
     {
       http (sprintf ('<span %s>', rdfa));
       http (st_astext (_object));
       http ('</span>');
     }
   else
     http (sprintf ('FIXME %i', __tag (_object)));

   if (length (lang))
     {
       if (strstr (lang, 'xsd:') = 0)
         http (sprintf (' (<a href="http://www.w3.org/2001/XMLSchema#%s">%s</a>)', subseq(lang, 4), lang));
       else
         http (sprintf (' (%s)', lang));
     }

   http ('</span></li>\n');
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

create procedure rdfdesc_prop_label (in uri any)
{
  declare ll varchar;
  ll := (select __ro2sq (O) from DB.DBA.RDF_QUAD where G in
  	(DB.DBA.RDF_GRAPH_GROUP_LIST_GET ('http://www.openlinksw.com/schemas/virtrdf#schemas', NULL,  0,  NULL,  NULL,  1))
	and S = __i2idn (uri)
	and P = __i2idn ('http://www.w3.org/2000/01/rdf-schema#label') OPTION (QUIETCAST));
  if (length (ll) = 0)
    ll := rdfdesc_uri_curie (uri);
  if (isstring (ll) and ll like 'opl%:isDescribedUsing')
    ll := 'Described Using Terms From';
  return ll;
}
;

create procedure rdfdesc_type (in gr varchar, in subj varchar, out url varchar)
{
  declare meta, data, ll any;
  ll := 'unknown';
  url := 'javascript:void()';
  if (length (gr))
    {
      exec (sprintf ('sparql select ?l ?tp from <%S> from virtrdf:schemas { <%S> a ?tp . optional { ?tp rdfs:label ?l } }', gr, subj),
	  null, null, vector (), 0, meta, data);
      if (length (data))
	{
	  if (data[0][0] is not null)
  	    ll := data[0][0];
	  else
	    ll := rdfdesc_uri_local_part (data[0][1]);
	  url := rdfdesc_http_url (data[0][1]);
	}
    }
  return ll;
}
;

-- proxy rules change
DB.DBA.URLREWRITE_CREATE_REGEX_RULE ('ext_http_proxy_rule_2', 1,
      '/proxy/html/(.*)', vector ('g'), 1,
      '/rdfdesc/description.vsp?g=%U', vector ('g'), null, null, 2);

DB.DBA.URLREWRITE_CREATE_RULELIST ('ext_http_proxy_rule_list1', 1, vector ('ext_http_proxy_rule_1', 'ext_http_proxy_rule_2'));

DB.DBA.EXEC_STMT ('grant SPARQL_SPONGE to "SPARQL"', 0);

create procedure rdf_virt_proxy_ver ()
{
  return '1.5';
}
;

create procedure
DB.DBA.RDF_VIEW_GET_BINARY (in path varchar, in accept varchar) __SOAP_HTTP 'application/octet-stream'
{
  declare host, suff, qr varchar;
  declare arr, stat, msg, meta, data any;

  host := cfg_item_value(virtuoso_ini_path(), 'URIQA','DefaultHost');
  arr := split_and_decode (path, 0, '\0\0/');
  suff := arr[1];
  qr := sprintf ('sparql prefix aowl: <http://bblfish.net/work/atom-owl/2006-06-06/>'||
  ' select ?c ?t from <http://%s/%s#> { <http://%s%s> aowl:body ?c ; aowl:type ?t  }', host, suff, host, path);
  stat := '00000';
  set_user_id ('SPARQL');
  exec (qr, stat, msg, vector (), 0, meta, data);
  if (stat = '00000' and length (data) and length (data[0]))
    {
      http_header (sprintf ('Content-Type: %s\r\n', data[0][1]));
      http (data[0][0]);
    }
  return '';
}
;

grant execute on DB.DBA.RDF_VIEW_GET_BINARY to PROXY;


-- /* extended http proxy service */
create procedure virt_proxy_init_about ()
{
  if (0 and registry_get ('DB.DBA.virt_proxy_init_about_state') = rdf_virt_proxy_ver ())
    return;

  -- /about/rdf/<url>
  DB.DBA.URLREWRITE_CREATE_REGEX_RULE ('ext_about_http_proxy_rule_1', 1,
      '/about/([^/\?\&:]*)/(.*)', vector ('force', 'url'), 2,
      '/about?url=%U&force=%U', vector ('url', 'force'), null, null, 2);

  -- /about/rdf/urn/<urn-path>
  DB.DBA.URLREWRITE_CREATE_REGEX_RULE ('ext_about_http_proxy_rule_2', 1,
      '/about/([^/\?\&:]*)/([^/\?\&:]*)/(.*)', vector ('force', 'schema', 'url'), 3,
      '/about?url=%U:%U&force=%U', vector ('schema', 'url', 'force'), null, null, 2);

  -- /about/rdf/http/<domain+path>
  DB.DBA.URLREWRITE_CREATE_REGEX_RULE ('ext_about_http_proxy_rule_3', 1,
      '/about/([^/\?\&:]*)/(http|https|webcal|feed|nodeID)/(.*)', vector ('force', 'schema', 'url'), 3,
      '/about?url=%U://%U&force=%U', vector ('schema', 'url', 'force'), null, null, 2);

  -- same as above, but for html
  DB.DBA.URLREWRITE_CREATE_REGEX_RULE ('ext_about_http_proxy_rule_4', 1,
      '/about/html/(.*)', vector ('g'), 1,
      '/rdfdesc/description.vsp?g=%U', vector ('g'), null, null, 2);

  DB.DBA.URLREWRITE_CREATE_REGEX_RULE ('ext_about_http_proxy_rule_5', 1,
      '/about/html/([^/\?\&:]*)/(.*)', vector ('sch', 'g'), 2,
      '/rdfdesc/description.vsp?g=%U:%U', vector ('sch', 'g'), null, null, 2);

  DB.DBA.URLREWRITE_CREATE_REGEX_RULE ('ext_about_http_proxy_rule_6', 1,
      '/about/html/(http|https|webcal|feed|nodeID)/(.*)', vector ('sch', 'g'), 2,
      '/rdfdesc/description.vsp?g=%U://%U', vector ('sch', 'g'), null, null, 2);

  DB.DBA.URLREWRITE_CREATE_RULELIST ('ext_about_http_proxy_rule_list1', 1,
      	vector (
	  	'ext_about_http_proxy_rule_1',
	  	'ext_about_http_proxy_rule_2',
	  	'ext_about_http_proxy_rule_3',
	  	'ext_about_http_proxy_rule_4',
	  	'ext_about_http_proxy_rule_5',
	  	'ext_about_http_proxy_rule_6'
		));

  DB.DBA.VHOST_REMOVE (lpath=>'/about');
  DB.DBA.VHOST_DEFINE (lpath=>'/about', ppath=>'/SOAP/Http/ext_http_proxy', soap_user=>'PROXY',
      opts=>vector('url_rewrite', 'ext_about_http_proxy_rule_list1'));

  DB.DBA.VHOST_REMOVE (vhost=>'*sslini*', lhost=>'*sslini*', lpath=>'/about');
  DB.DBA.VHOST_DEFINE (vhost=>'*sslini*', lhost=>'*sslini*', lpath=>'/about', ppath=>'/SOAP/Http/ext_http_proxy', soap_user=>'PROXY',
      opts=>vector('url_rewrite', 'ext_about_http_proxy_rule_list1'));

  DB.DBA.VHOST_REMOVE (lpath=>'/services/rdf/object.binary');
  DB.DBA.VHOST_DEFINE (lpath=>'/services/rdf/object.binary', ppath=>'/SOAP/Http/RDF_VIEW_GET_BINARY', soap_user=>'PROXY');

  --# the new iris
  DB.DBA.URLREWRITE_CREATE_REGEX_RULE ('ext_ahp_rule_new_restrict', 1,
      '/about/id/(http|https|webcal|feed|nodeID)/(.*)', vector ('sch', 'g'), 2,
      '/about/html/%s/%s', vector ('sch', 'g'), null, null, 2, 406, null);

  --DB.DBA.URLREWRITE_CREATE_REGEX_RULE ('ext_ahp_rule_new_page', 1,
  --    '/about/id/(http|https|webcal|feed|nodeID)/(.*)', vector ('sch', 'g'), 2,
  --    '/about/html/%s/%s', vector ('sch', 'g'), null, '(text/html)|(application/xhtml.xml)|(\\*/\\*)', 2, 303, null);

  DB.DBA.URLREWRITE_CREATE_REGEX_RULE ('ext_ahp_rule_new_data', 1,
      '/about/id/(http|https|webcal|feed|nodeID)/(.*)', vector ('sch', 'g'), 2,
      '/about/data/%s/%s', vector ('sch', 'g'), null,
      '(application/rdf.xml)|(text/rdf.n3)|(application/x-turtle)|(text/n3)|(text/turtle)|'||
      '(application/rdf.json)|(application/json)|(text/html)|(text/plain)|(application/atom.xml)|(application/odata.json)|(\\*/\\*)', 
      2, 303, null);

  delete from DB.DBA.HTTP_VARIANT_MAP where VM_RULELIST = 'ext_ahp_rule_list_new';
  DB.DBA.HTTP_VARIANT_ADD ('ext_ahp_rule_list_new', '/about/data/(.*)', '/about/data/xml/\x241',    'application/rdf+xml', 0.95);
  DB.DBA.HTTP_VARIANT_ADD ('ext_ahp_rule_list_new', '/about/data/(.*)', '/about/data/nt/\x241',     'text/n3', 0.80);
  DB.DBA.HTTP_VARIANT_ADD ('ext_ahp_rule_list_new', '/about/data/(.*)', '/about/data/n3/\x241',     'text/rdf+n3', 0.80);
  DB.DBA.HTTP_VARIANT_ADD ('ext_ahp_rule_list_new', '/about/data/(.*)', '/about/data/ttl/\x241',    'application/x-turtle', 0.80);
  DB.DBA.HTTP_VARIANT_ADD ('ext_ahp_rule_list_new', '/about/data/(.*)', '/about/data/turtle/\x241', 'text/turtle', 0.80);
  DB.DBA.HTTP_VARIANT_ADD ('ext_ahp_rule_list_new', '/about/data/(.*)', '/about/data/json/\x241',    'application/json', 0.70);
  DB.DBA.HTTP_VARIANT_ADD ('ext_ahp_rule_list_new', '/about/data/(.*)', '/about/data/jrdf/\x241',    'application/rdf+json', 0.70);
  DB.DBA.HTTP_VARIANT_ADD ('ext_ahp_rule_list_new', '/about/data/(.*)', '/about/html/^{DynamicLocalFormat}^/about/id/\x241', 'text/html', 0.80);
  DB.DBA.HTTP_VARIANT_ADD ('ext_ahp_rule_list_new', '/about/data/(.*)', '/about/data/text/\x241',    'text/plain', 0.20);

  DB.DBA.URLREWRITE_CREATE_RULELIST ( 'ext_ahp_rule_list_new', 1,
      		vector (
		  	'ext_ahp_rule_new_restrict',
		  	--'ext_ahp_rule_new_page',
		  	'ext_ahp_rule_new_data')
	);

  DB.DBA.VHOST_REMOVE (lpath=>'/about/id');
  DB.DBA.VHOST_DEFINE (lpath=>'/about/id', ppath=>'/', is_dav=>0, def_page=>'', opts=>vector('url_rewrite', 'ext_ahp_rule_list_new'));

  --# /id/entity

  DB.DBA.URLREWRITE_CREATE_REGEX_RULE ('sp_entity_rl_restrict', 1,
      '/about/id/entity/(http|https|webcal|feed|nodeID)/(.*)', vector ('sch', 'g'), 2,
      '/dummy', vector (), null, null, 2, 406, null);

  DB.DBA.URLREWRITE_CREATE_REGEX_RULE ('sp_entity_rl_data', 1,
      '/about/id/entity/(http|https|webcal|feed|nodeID)/(.*)', vector ('sch', 'g'), 2,
      '/about/data/entity/%s/%s', vector ('sch', 'g'), null,
      '(application/rdf.xml)|(text/rdf.n3)|(application/x-turtle)|(text/n3)|(text/turtle)|'||
      '(application/rdf.json)|(application/json)|(text/html)|(text/plain)|(application/atom.xml)|(application/odata.json)|(\\*/\\*)', 
      2, 303, null);

  delete from DB.DBA.HTTP_VARIANT_MAP where VM_RULELIST = 'sp_entity_rll';
  DB.DBA.HTTP_VARIANT_ADD ('sp_entity_rll', '/about/data/entity/(.*)', '/about/data/entity/xml/\x241',    'application/rdf+xml', 0.95);
  DB.DBA.HTTP_VARIANT_ADD ('sp_entity_rll', '/about/data/entity/(.*)', '/about/data/entity/nt/\x241',     'text/n3', 0.80);
  DB.DBA.HTTP_VARIANT_ADD ('sp_entity_rll', '/about/data/entity/(.*)', '/about/data/entity/n3/\x241',     'text/rdf+n3', 0.80);
  DB.DBA.HTTP_VARIANT_ADD ('sp_entity_rll', '/about/data/entity/(.*)', '/about/data/entity/ttl/\x241',    'application/x-turtle', 0.80);
  DB.DBA.HTTP_VARIANT_ADD ('sp_entity_rll', '/about/data/entity/(.*)', '/about/data/entity/turtle/\x241', 'text/turtle', 0.80);
  DB.DBA.HTTP_VARIANT_ADD ('sp_entity_rll', '/about/data/entity/(.*)', '/about/data/entity/jrdf/\x241',    'application/rdf+json', 0.70);
  DB.DBA.HTTP_VARIANT_ADD ('sp_entity_rll', '/about/data/entity/(.*)', '/about/data/entity/json/\x241',    'application/json', 0.70);
  DB.DBA.HTTP_VARIANT_ADD ('sp_entity_rll', '/about/data/entity/(.*)', '/about/html/^{DynamicLocalFormat}^/about/id/entity/\x241', 'text/html', 0.80);
  DB.DBA.HTTP_VARIANT_ADD ('sp_entity_rll', '/about/data/entity/(.*)', '/about/data/entity/atom/\x241',    'application/atom+xml', 0.60);
  DB.DBA.HTTP_VARIANT_ADD ('sp_entity_rll', '/about/data/entity/(.*)', '/about/data/entity/jsod/\x241',    'application/odata+json', 0.60);
  DB.DBA.HTTP_VARIANT_ADD ('sp_entity_rll', '/about/data/entity/(.*)', '/about/data/entity/text/\x241',    'text/plain', 0.20);

  DB.DBA.URLREWRITE_CREATE_RULELIST ( 'sp_entity_rll', 1,
      		vector ( 'sp_entity_rl_restrict', 'sp_entity_rl_data'));

  DB.DBA.VHOST_REMOVE (lpath=>'/about/id/entity');
  DB.DBA.VHOST_DEFINE (lpath=>'/about/id/entity', ppath=>'/', is_dav=>0, def_page=>'', opts=>vector('url_rewrite', 'sp_entity_rll'));

  --# information resources for /about/id/x
  DB.DBA.URLREWRITE_CREATE_REGEX_RULE ('ext_ahp_rule_data_1', 1,
      '/about/data/(xml|n3|nt|ttl|text|turtle)/(http|https|webcal|feed|nodeID)/(.*)\0x24', vector ('fmt', 'sch', 'url'), 3,
      '/about?url=%s://%U&force=rdf&output-format=%U', vector ('sch', 'url', 'fmt'), null, null, 2, null, '^{sql:DB.DBA.RM_LINK_HDR}^');

  DB.DBA.URLREWRITE_CREATE_REGEX_RULE ('ext_ahp_rule_data_2', 1,
      '/about/data/turtle/(http|https|webcal|feed|nodeID)/(.*)\0x24', vector ('sch', 'url'), 2,
      '/about?url=%s://%U&force=rdf&output-format=text%%2Fturtle', vector ('sch', 'url'), null, null, 2, null, 
      'Content-Type: text/turtle\r\n^{sql:DB.DBA.RM_LINK_HDR}^');

  DB.DBA.URLREWRITE_CREATE_REGEX_RULE ('ext_ahp_rule_data_3', 1,
      '/about/data/ttl/(http|https|webcal|feed|nodeID)/(.*)\0x24', vector ('sch', 'url'), 2,
      '/about?url=%s://%U&force=rdf&output-format=application%%2Fx-turtle', vector ('sch', 'url'), null, null, 2, null, 
      'Content-Type: application/x-turtle\r\n^{sql:DB.DBA.RM_LINK_HDR}^');
  DB.DBA.URLREWRITE_CREATE_REGEX_RULE ('ext_ahp_rule_data_4', 1,
      '/about/data/jrdf/(http|https|webcal|feed|nodeID)/(.*)\0x24', vector ('sch', 'url'), 2,
      '/about?url=%s://%U&force=rdf&output-format=json', vector ('sch', 'url'), null, null, 2, null, 
      'Content-Type: application/rdf+json\r\n^{sql:DB.DBA.RM_LINK_HDR}^');

  DB.DBA.URLREWRITE_CREATE_REGEX_RULE ('ext_ahp_rule_data_5', 1,
      '/about/data/json/(http|https|webcal|feed|nodeID)/(.*)\0x24', vector ('sch', 'url'), 2,
      '/about?url=%s://%U&force=rdf&output-format=json', vector ('sch', 'url'), null, null, 2, null, 
      'Content-Type: application/json\r\n^{sql:DB.DBA.RM_LINK_HDR}^');

  DB.DBA.URLREWRITE_CREATE_REGEX_RULE ('ext_ahp_rule_data_6', 1,
      '/about/data/atom/(http|https|webcal|feed|nodeID)/(.*)\0x24', vector ('sch', 'url'), 2,
      '/about?url=%s://%U&force=rdf&output-format=application%%2Fatom%%2Bxml', vector ('sch', 'url'), null, null, 2, null, 
      'Content-Type: application/atom+xml\r\n^{sql:DB.DBA.RM_LINK_HDR}^');

  DB.DBA.URLREWRITE_CREATE_REGEX_RULE ('ext_ahp_rule_data_7', 1,
      '/about/data/jsod/(http|https|webcal|feed|nodeID)/(.*)\0x24', vector ('sch', 'url'), 2,
      '/about?url=%s://%U&force=rdf&output-format=application%%2Fodata%%2Bjson', vector ('sch', 'url'), null, null, 2, null, 
      'Content-Type: application/odata+json\r\n^{sql:DB.DBA.RM_LINK_HDR}^');

  DB.DBA.URLREWRITE_CREATE_RULELIST ( 'ext_ahp_rule_list_data', 1,
      	vector (
	  'ext_ahp_rule_data_1',
	  'ext_ahp_rule_data_2',
	  'ext_ahp_rule_data_3',
	  'ext_ahp_rule_data_4',
	  'ext_ahp_rule_data_5',
	  'ext_ahp_rule_data_6',
	  'ext_ahp_rule_data_7'
	  )
	);

  DB.DBA.VHOST_REMOVE (lpath=>'/about/data');
  DB.DBA.VHOST_DEFINE (lpath=>'/about/data', ppath=>'/', is_dav=>0, def_page=>'', opts=>vector('url_rewrite', 'ext_ahp_rule_list_data'));

  --# information resources for /about/id/entity/x
  DB.DBA.URLREWRITE_CREATE_REGEX_RULE ('sp_ent_data_rl_1', 1,
      '/about/data/entity/(xml|n3|nt|ttl|text|turtle|json)/(http|https|webcal|feed|nodeID)/(.*)\0x24', vector ('fmt', 'sch', 'url'), 3,
      '/about?url=%s://%U&force=rdf&output-format=%U', vector ('sch', 'url', 'fmt'), null, null, 2, null, 
      '^{sql:DB.DBA.RM_LINK_HDR}^');

  DB.DBA.URLREWRITE_CREATE_REGEX_RULE ('sp_ent_data_rl_2', 1,
      '/about/data/entity/turtle/(http|https|webcal|feed|nodeID)/(.*)\0x24', vector ('sch', 'url'), 2,
      '/about?url=%s://%U&force=rdf&output-format=text%%2Fturtle', vector ('sch', 'url'), null, null, 2, null, 
      'Content-Type: text/turtle\r\n^{sql:DB.DBA.RM_LINK_HDR}^');

  DB.DBA.URLREWRITE_CREATE_REGEX_RULE ('sp_ent_data_rl_3', 1,
      '/about/data/entity/ttl/(http|https|webcal|feed|nodeID)/(.*)\0x24', vector ('sch', 'url'), 2,
      '/about?url=%s://%U&force=rdf&output-format=application%%2Fx-turtle', vector ('sch', 'url'), null, null, 2, null, 
      'Content-Type: application/x-turtle\r\n^{sql:DB.DBA.RM_LINK_HDR}^');

  DB.DBA.URLREWRITE_CREATE_REGEX_RULE ('sp_ent_data_rl_4', 1,
      '/about/data/entity/json/(http|https|webcal|feed|nodeID)/(.*)\0x24', vector ('sch', 'url'), 2,
      '/about?url=%s://%U&force=rdf&output-format=json', vector ('sch', 'url'), null, null, 2, null, 
      'Content-Type: application/json\r\n^{sql:DB.DBA.RM_LINK_HDR}^');

  DB.DBA.URLREWRITE_CREATE_REGEX_RULE ('sp_ent_data_rl_5', 1,
      '/about/data/entity/jrdf/(http|https|webcal|feed|nodeID)/(.*)\0x24', vector ('sch', 'url'), 2,
      '/about?url=%s://%U&force=rdf&output-format=json', vector ('sch', 'url'), null, null, 2, null, 
      'Content-Type: application/rdf+json\r\n^{sql:DB.DBA.RM_LINK_HDR}^');

  DB.DBA.URLREWRITE_CREATE_REGEX_RULE ('sp_ent_data_rl_6', 1,
      '/about/data/entity/atom/(http|https|webcal|feed|nodeID)/(.*)\0x24', vector ('sch', 'url'), 2,
      '/about?url=%s://%U&force=rdf&output-format=application%%2Fatom%%2Bxml', vector ('sch', 'url'), null, null, 2, null, 
      'Content-Type: application/atom+xml\r\n^{sql:DB.DBA.RM_LINK_HDR}^');

  DB.DBA.URLREWRITE_CREATE_REGEX_RULE ('sp_ent_data_rl_7', 1,
      '/about/data/entity/jsod/(http|https|webcal|feed|nodeID)/(.*)\0x24', vector ('sch', 'url'), 2,
      '/about?url=%s://%U&force=rdf&output-format=application%%2Fodata%%2Bjson', vector ('sch', 'url'), null, null, 2, null, 
      'Content-Type: application/odata+json\r\n^{sql:DB.DBA.RM_LINK_HDR}^');

  DB.DBA.URLREWRITE_CREATE_RULELIST ( 'sp_ent_data_rll', 1,
      	vector (
	  'sp_ent_data_rl_1',
	  'sp_ent_data_rl_2',
	  'sp_ent_data_rl_3',
	  'sp_ent_data_rl_4',
	  'sp_ent_data_rl_5',
	  'sp_ent_data_rl_6',
	  'sp_ent_data_rl_7'
	  )
	);

  DB.DBA.VHOST_REMOVE (lpath=>'/about/data/entity');
  DB.DBA.VHOST_DEFINE (lpath=>'/about/data/entity', ppath=>'/', is_dav=>0, def_page=>'', opts=>vector('url_rewrite', 'sp_ent_data_rll'));

  --# grants
  EXEC_STMT ('grant execute on  DB.DBA.HTTP_RDF_ACCEPT to PROXY', 0);

  registry_set ('DB.DBA.virt_proxy_init_about_state', rdf_virt_proxy_ver ());
}
;

create procedure RM_LINK_HDR (in path varchar)
{
  declare exts, parts, lines any;
  declare ext, fmt, h, host varchar;

  exts := vector (
    vector ('xml',    	'application/rdf+xml',		'Structured Descriptor Document (RDF/XML format)'),
    vector ('nt',     	'text/n3',			'Structured Descriptor Document (N3 format)'),
    vector ('n3',     	'text/rdf+n3',			'Structured Descriptor Document (N3 format)'),
    vector ('ttl',   	'application/x-turtle',		'Structured Descriptor Document (Turtle format)'),
    vector ('turtle',   'text/turtle',			'Structured Descriptor Document (Turtle format)'),
    vector ('jrdf',    	'application/rdf+json',		'Structured Descriptor Document (JSON format)'),
    vector ('json', 	'application/json',		'Structured Descriptor Document (JSON format)'),
    vector ('atom',   	'application/atom+xml',		'OData (Atom+Feed format)'),
    vector ('jsod',   	'application/odata+json',	'OData (JSON format)')
    --vector ('text',   	'text/plain',			'Structured Descriptor Document (NTriples format)')
  );
  lines := http_request_header ();
  host := http_request_header(lines, 'Host', null, '');
  if (host is null or host = '')
    return '';
  if (path like '/about/data/entity/%')
    {
      parts := sprintf_inverse (path, '/about/data/entity/%s/%s', 0);
      fmt := '/about/data/entity/%s/' || parts[1];
    }
  else
    {
      parts := sprintf_inverse (path, '/about/data/%s/%s', 0);
      fmt := '/about/data/%s/' || parts[1];
    }
  ext := parts[0];
  h := 'Link:';
  for (declare i,l int, i := 0, l := length (exts); i < l; i := i + 1)
    {
      if (ext <> exts[i][0])
        h := h || sprintf (' <http://%s'||fmt||'>;\r\n rel="alternate"; type="%s"; title="%s",\r\n', host, exts[i][0], exts[i][1], exts[i][2]); 
    }
  h := rtrim (h, ',\r\n');
  return h;
}
;

virt_proxy_init_about ()
;

drop procedure virt_proxy_init_about;

create procedure rdfdesc_virt_info ()
{
  http ('<a href="http://www.openlinksw.com/virtuoso/">OpenLink Virtuoso</a> version '); 
  http (sys_stat ('st_dbms_ver')); 
  http (', on ');
  http (sys_stat ('st_build_opsys_id')); http (sprintf (' (%s), ', host_id ())); 
  http (case when sys_stat ('cl_run_local_only') = 1 then 'Single' else 'Cluster' end); http (' Edition ');
  http (case when sys_stat ('cl_run_local_only') = 0 then sprintf ('(%d server processes)', sys_stat ('cl_n_hosts')) else '' end); 
}
;
