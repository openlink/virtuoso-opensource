--
--  $Id$
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2009 OpenLink Software
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

create procedure b3s_page_get_type (in val any)
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

create procedure b3s_get_lang_by_q (in accept varchar, in lang varchar)
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

create procedure b3s_label_get (inout data any, in langs any)
{
  declare q, best_q, label any;
  label := '';
   if (length (data))
     {
       best_q := 0;
       for (declare i,l int, i := 0, l := length (data); i < l; i := i + 1)
         {
	  q := b3s_get_lang_by_q (langs, data[i][1]);
	  --dbg_obj_print (data[i][0], langs, data[i][1], q);
          if (q > best_q)
	    {
	      label := data[i][0];
	      best_q := q;
	    }
	 }
     }
   return label;
}
;

create procedure b3s_uri_curie (in uri varchar)
{
  declare delim integer;
  declare uriSearch, nsPrefix varchar;

  delim := -1;

  uriSearch := uri;
  nsPrefix := null;
  while (nsPrefix is null and delim <> 0) {

    delim := coalesce (strrchr (uriSearch, '/'), 0);
    delim := __max (delim, coalesce (strrchr (uriSearch, '#'), 0));
    delim := __max (delim, coalesce (strrchr (uriSearch, ':'), 0));

    nsPrefix := coalesce(__xml_get_ns_prefix(subseq(uriSearch, 0, delim + 1),2), __xml_get_ns_prefix(subseq(uriSearch, 0, delim),2));
    uriSearch := subseq(uriSearch, 0, delim);
--    dbg_obj_print(uriSearch);
  }

  if (nsPrefix is not null) {
	declare rhs varchar;
	rhs := subseq(uri, length(uriSearch) + 1, null);
	if (length(rhs) = 0) {
		return uri;
	} else {
		return nsPrefix || ':' || rhs;
	}
  }
  return uri;
}
;


create procedure 
b3s_http_url (in url varchar, in sid varchar := null)
{
  declare host, pref, more varchar;
  if (sid is not null)
    more := sprintf ('&sid=%s', sid);
  else
    more := '';
  return sprintf ('/about/?url=%U%s', url, more);
};

create procedure 
b3s_http_print_l (in p_text any, inout odd_position int, in r int := 0, in sid varchar := null)
{
   declare short_p, p_prefix, int_redirect, url any;

   odd_position :=  odd_position + 1;
   p_prefix := b3s_uri_curie (p_text);
   url := b3s_http_url (p_text, sid);

   http (sprintf ('<tr class="%s"><td class="property">', either(mod (odd_position, 2), 'odd', 'even')));
   if (r) http ('is ');
   http (sprintf ('<a class="uri" href="%s" title="%s">%s</a>\n', url, p_prefix, p_prefix));
   if (r) http (' of');

   http ('</td><td><ul class="obj">');
}
;

create procedure 
b3s_http_print_r (in _object any, in sid varchar := null)
{
   declare lang, rdfs_type any;

   if (_object is null) 
     return;

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
   else if (__tag (_object) = 243 or (isstring (_object) and (__box_flags (_object)= 1 or _object like 'nodeID://%' or _object like 'http://%')))
     {
       declare _url, p_t any;

       if (__tag of IRI_ID = __tag (_object))
	 _url := id_to_iri (_object);
       else
	 _url := _object;

	   http (sprintf ('<a class="uri" href="%s">%s</a>', b3s_http_url (_url, sid), b3s_uri_curie(_url)));

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

create procedure b3s_page_get_short (in val any)
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

