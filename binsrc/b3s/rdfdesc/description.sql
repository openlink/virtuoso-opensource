--
--  $Id$
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2018 OpenLink Software
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

  if (pref is null)
    return val;
  res := __xml_get_ns_prefix (pref, 2);
  if (res is null)
    return val;
  return res;
}
;

--
-- make a vector of languages and their quality
--
create procedure b3s_get_lang_acc (in lines any)
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

create procedure b3s_str_lang_check (in lang any, in acc any)
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

create procedure
b3s_handle_ses (inout _path any, inout _lines any, inout _params any)
{
   declare sid, refr varchar;

   sid := get_keyword ('sid', _params);

   if (sid is null) {
     refr := http_request_header (http_request_header (), 'Referer', null, null);

     if (refr is not null)
       {
         declare ht, pars any;
         ht := WS.WS.PARSE_URI (refr);
         pars := ht[4];
         pars := split_and_decode (pars);
         if (pars is not null)
           sid := get_keyword ('sid', pars);
       }
   }

   if (sid is not null and (regexp_match ('[0-9]*', sid) = sid)) connection_set ('sid', sid);
}
;

-- XXX should probably find the most specific if more than one class and inference rule is set
create procedure 
b3s_e_type (in subj varchar)
{
  declare stat, msg any;
  declare meta, data, ll any;
  declare i int;

  ll := 'http://www.w3.org/2002/07/owl#Thing';

  if (length (subj))
    {
      declare q_txt any;
      stat := '00000';
      data := null;
      q_txt := string_output ();
      http ('sparql select ?tp where { ', q_txt);
      http_sparql_object (__box_flags_tweak (subj, 1), q_txt);
      http (' a ?tp }', q_txt);
      exec (string_output_string (q_txt), stat, msg, vector (), 100, meta, data);

      if (length (data))
	{
	  for (i := 0; i < length (data); i := i + 1) 
            {
              if (data[i][0] is not null and __box_flags (data[i][0]) = 1)
  	        return data[i][0];
            }
	}
    }
  return ll;
}
;

create procedure
b3s_type (in subj varchar,
          in _from varchar,
          out url varchar,
          out c_iri varchar)
{
  declare stat, msg any;
  declare meta, data, ll any;
  declare i int;

  ll := 'unknown';
  url := 'javascript:void()';
  c_iri := 'http://www.w3.org/2002/07/owl#Thing';

  if (length (subj))
    {
      declare q_txt any;
      q_txt := string_output ();
      http ('sparql select ?l ?tp ' || _from || ' where { ', q_txt);
      http_sparql_object (__box_flags_tweak (subj, 1), q_txt);
      http (' a ?tp optional { ?tp rdfs:label ?l } }', q_txt);
      exec (string_output_string (q_txt), stat, msg, vector (), 100, meta, data);
      if (length (data))
	{
	  for (i := 0; i < length (data); i := i + 1)
            {
              if (data[i][0] is not null)
  	        ll := data[i][0];
	      else
	        ll := b3s_uri_local_part (data[i][1]);

	      url := b3s_http_url (data[i][1]);

              c_iri := data[i][1];
            }
	}
    }
  return ll;
}
;

-- This is where we should have something smart... instead we return the last one...

create procedure b3s_choose_e_type (inout type_a any)
{
    if (not length(type_a))
      return vector ('http://www.w3.org/2002/07/owl#Thing', 'owl:Thing', 'A Thing');

--    dbg_printf ('type_a length: %d', length(type_a));
    return (type_a[length(type_a)-1]);
}
;

--
-- Detect if viewing an explicit or implicit class
--

create procedure b3s_find_class_type (in _s varchar, in _f varchar, inout types_a any) 
{
  declare i int;

  for (i := 0; i < length (types_a); i := i + 1) 
    {
      if (types_a[i][0] in ('http://www.w3.org/2002/07/owl#Class', 
                       'http://www.w3.org/2000/01/rdf-schema#Class')) 
	return 1;
    }

  declare st, msg varchar;
  declare meta,data any;
  declare q_txt any;
  data := null;
  st := '00000';
  msg:= '';
  q_txt := string_output ();
  http ('sparql select ?to ' || _f || ' where { quad map virtrdf:DefaultQuadMap { ?to a ', q_txt);
  http_sparql_object (__box_flags_tweak (_s, 1), q_txt);
  http (' }}', q_txt);
  exec (string_output_string (q_txt), st, msg, vector(), 1, meta, data);
  if (length (data)) return 1;
  q_txt := string_output ();
  http ('sparql select ?to ' || _f || ' where { graph ?g { ?to a ', q_txt);
  http_sparql_object (__box_flags_tweak (_s, 1), q_txt);
  http (' }}', q_txt);
  exec (string_output_string (q_txt), st, msg, vector(), 1, meta, data);
  if (length (data)) return 1;
  return 0;
}
;

create procedure b3s_uri_local_part (in uri varchar)
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


--
-- vector (vector (<type_iri>, <short_form>, <label or null>), vector (...), ...)
--

create function
b3s_get_types (in _s varchar,
               in _from varchar,
               in langs any) {
  declare stat, msg, meta, data any;
  declare t_a any;
  declare i, len integer;
  declare q_txt any;
  if (not length (_s))
    return vector ();

  vectorbld_init (t_a);
  data := null;
  q_txt := string_output ();
  http ('sparql select distinct ?tp ' || _from || ' where { quad map virtrdf:DefaultQuadMap { ', q_txt);
  http_sparql_object (__bft (_s, 1), q_txt);
  http (' a ?tp . filter (isIRI(?tp)) } }', q_txt);
  exec (string_output_string (q_txt), stat, msg, vector (), 100, meta, data);
  len := length(data);
  for (i := 0;i < length(data); i := i + 1) 
    {
      declare tp any;
      tp := data[i][0];
--    dbg_printf ('data[%d][0]: %s', i, tp);
      vectorbld_acc (t_a, vector (tp, b3s_uri_curie (tp), b3s_label (tp, langs)));
    }
  if (len)
    goto skip_virt_graphs;
  q_txt := string_output ();
  http ('sparql select distinct ?tp ' || _from || ' where { graph ?g { ', q_txt);
  http_sparql_object (__bft (_s, 1), q_txt);
  http (' a ?tp . filter (isIRI(?tp)) } }', q_txt);
  exec (string_output_string (q_txt), stat, msg, vector (), 100, meta, data);
  len := length(data);
  for (i := 0; i < length(data); i := i + 1)
    {
      declare tp any;
      tp := data[i][0];
--    dbg_printf ('data[%d][0]: %s', i, tp);
      vectorbld_acc (t_a, vector (tp, b3s_uri_curie (tp), b3s_label (tp, langs)));
    }
skip_virt_graphs:
  vectorbld_final (t_a);
  return (t_a);
}                 
;

create function
b3s_get_all_types (in _s varchar,
               in _from varchar,
               in langs any)
        {
  return b3s_get_types (_s, _from, langs);
}                 
;

create procedure
b3s_render_iri_select (inout types_a any, 
                       in ins_str varchar := '',
                       in sel int := -1)
{
  declare i int;

  if (length (types_a) and isvector (types_a))
    {
      if (sel = -1) sel := length(types_a)-1;

      http (sprintf ('<select %s>', ins_str));

      for (i := 0; i < length(types_a); i := i + 1) 
        { 
          http (sprintf ('<option value="%s" title="%s" %s>%s</option>', 
                         types_a[i][0],
                         types_a[i][0],
                         case when i = sel then 'selected="selected"' else '' end,
                         case when types_a[i][2] <> '' then types_a[i][2] else types_a[i][1] end));
        } 
      http ('</select>');
    }
  return i;
}
;

create procedure
b3s_render_fct_link ()
{
  declare sid varchar;
  sid := connection_get ('sid');

  if (sid is not null)
    return ('/fct/facet.vsp?sid='||sid||'&cmd=refresh');
  else
    return '';
}
;

create procedure
b3s_render_inf_opts ()
{
  declare inf varchar;
  declare f int;
  f := 0;
  inf := connection_get ('inf');

  for select distinct RS_NAME as RS_NAME from SYS_RDF_SCHEMA do
    {
      if (RS_NAME = inf)
        {
          http (sprintf ('<option value="%s" selected="selected">%s</option>', RS_NAME, RS_NAME));
          f := 1;
        }
      else
        http (sprintf ('<option value="%s">%s</option>', RS_NAME, RS_NAME));
    }

  if (f = 0)
    http ('<option value="**none**" selected="selected">None</option>');
  else
    http ('<option value="**none**">None</option>');
}
;

create procedure
b3s_sas_selected ()
{
  if (connection_get ('sas') = 'yes')
    return ' checked="selected" ';
  else
    return '';
}
;

create procedure
b3s_parse_inf (in sid varchar, inout params any)
{
  declare _sas, _inf varchar;
  declare grs any;

  _sas := _inf := null;

  if (sid is not null)
    {
      for select fct_state from fct_state where fct_sid = sid do
        {
	  declare i varchar;
          connection_set('inf', fct_inf_val (fct_state));
          connection_set('sas', fct_sas_val (fct_state));
	  i := cast (xpath_eval ('/query/@s-term', fct_state) as varchar);
	  if (length (i))
            connection_set('s_term', i);
        }
    }

-- URL params override

  _inf := get_keyword ('inf', params);

  if (_inf is not null)
    {
      if (exists (select 1 from SYS_RDF_SCHEMA where rs_name = _inf))
        connection_set ('inf', _inf);
      else connection_set ('inf', null);
    }

  _sas := get_keyword ('sas', params);

  if (_sas is not null)
    {
      if (_sas = '1' or _sas = 'yes')
        connection_set ('sas', 'yes');
      else
        connection_set ('sas', null);
    }
  vectorbld_init (grs);
  for (declare i int, i := 0; i < length (params); i := i + 2)
    {
      if (params[i] = 'graph' and not position (params[i+1], grs))
	vectorbld_acc (grs, params[i+1]);
    }
  vectorbld_final (grs);
  if (length (grs) = 0 and sid is not null and get_keyword ('set_graphs', params) is null)
    {
      declare xt, xp, inx any;
      xt := (select fct_state from fct_state where fct_sid = sid);
      inx := 1;
      vectorbld_init (grs);
      while (xt is not null and (xp := xpath_eval (sprintf ('//query/@graph%d', inx), xt)) is not null)
	{
	  vectorbld_acc (grs, cast (xp as varchar));
	  inx := inx + 1;
	}
      vectorbld_final (grs);
    }
  if (get_keyword ('clear_graphs', params) is not null)
    grs := vector ();
  connection_set ('graphs', grs);
}
;

create procedure
b3s_render_inf_clause ()
{
  declare _inf, _sas varchar;

  _inf := connection_get ('inf');
  _sas := connection_get ('sas');

  if (_inf is not null)
    _inf := sprintf ('define input:inference ''%s'' ', _inf);
  else
    _inf := '';

  if (_sas is not null)
    _sas := sprintf ('define input:same-as "yes" ');
  else
    _sas := '';

  return (_inf || _sas);
}
;

create procedure
b3s_render_ses_params (in with_graph int := 1) 
{
  declare i,s,ifp,sid varchar;
  declare grs any;
  declare ses any;
  ses := string_output ();
  i := connection_get ('inf');
  s := connection_get ('sas');
  sid := connection_get ('sid');
  grs := connection_get ('graphs', null);

  if (i is not null) http (sprintf ('&inf=%U', i), ses);
  if (s is not null) http (sprintf ('&sas=%V', s), ses);
  if (sid is not null) http (sprintf ('&sid=%V', sid), ses);
  if (grs is not null and with_graph)
    {
      foreach (any x in grs) do
        http (sprintf ('&graph=%U', x), ses);
	}
  return string_output_string (ses);
}
;

create procedure
b3s_dbg_out (inout ses any, in str any)
{
  if (connection_get ('b3s_dbg'))
    http (str || '\n', ses);
}
;

create procedure
b3s_render_dbg_out (inout ses any)
{
  if (connection_get ('b3s_dbg'))
    {
      http('<div id="dbg_output"><pre>');
      http_value (ses);
      http('</pre></div>');
    }
}
;

create procedure b3s_get_lang_by_q (in accept varchar, in lang varchar)
{
  declare format, itm, q varchar;
  declare arr any;
  declare i, l int;

  if (not length (lang))
    lang := 'en';
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
   if (not isstring (label))
     {
       if (__tag of rdf_box = __tag (label)  and rdf_box_is_complete (label))
	 label := rdf_box_data (label);
       else
	 label := __rdf_strsqlval (label);
     }
   if (not isstring (label))
     label := cast (label as varchar);
   --label := regexp_replace (label, '<[^>]+>', '', 1, null);
  if (label is null)
    label := ''; 
  if (0 and sys_stat ('cl_run_local_only'))
    {
      label := xpath_eval ('string(.)', xtree_doc (label, 2));
      label := charset_recode (label, '_WIDE_', 'UTF-8');
    }
  else
    label := cast (xtree_doc (label, 2) as varchar);
   return label;
}
;

create procedure 
b3s_rel_print (in val any, in rel any, in flag int := 0)
{
  declare delim, delim1, delim2, delim3 integer;
  declare inx int;
  declare nss, loc, nspref varchar;

  delim1 := coalesce (strrchr (val, '/'), -1);
  delim2 := coalesce (strrchr (val, '#'), -1);
  delim3 := coalesce (strrchr (val, ':'), -1);
  delim := __max (delim1, delim2, delim3);
  nss := null;
  loc := val;
  if (delim < 0) return loc;
  nss := subseq (val, 0, delim + 1);
  loc := subseq (val, delim + 1);

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
  return concat (loc, ' ', nss);
}
;


create procedure
b3s_uri_curie (in uri varchar)
{
  declare delim integer;
  declare uriSearch, nsPrefix varchar;

  delim := -1;

  if (uri is null)
    return '';
  if (iswidestring (uri))
    uri := charset_recode (uri, '_WIDE_', 'UTF-8');
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
		return __bft (nsPrefix || ':' || rhs, 2);
	}
  }
  return uri;
}
;

create procedure b3s_prop_label (in uri any)
{
  declare ll varchar;
  ll := (select top 1 __ro2sq (O) from DB.DBA.RDF_QUAD where S = __i2idn (uri) and P = __i2idn ('http://www.w3.org/2000/01/rdf-schema#label') OPTION (QUIETCAST));
  if (length (ll) = 0)
    ll := b3s_uri_curie (uri);
  if (isstring (ll) and ll like 'opl%:isDescribedUsing')
    ll := 'Described Using Terms From';
  return ll;
}
;

create procedure
b3s_trunc_uri (in s varchar, in maxlen int := 80)
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

create procedure
b3s_http_url (in url varchar, in sid varchar := null, in _from varchar := null, in with_graph int := 1)
{
  declare host, pref, more, i, wurl varchar;

--  more := '';

--  if (sid is not null)
--    more := sprintf ('&sid=%s', sid);
--  else
--    more := '';

  i := b3s_render_ses_params(with_graph);
  if (length (_from))
    i := sprintf ('%s&graph=%U', i, _from);
  wurl := charset_recode (url, 'UTF-8', '_WIDE_');
  return sprintf ('/describe/?url=%U%s', coalesce (wurl, url), i);
};

create procedure b3s_u2w (in u any)
{
  declare w any;
  w := charset_recode (u, 'UTF-8', '_WIDE_');
  return coalesce (w, u);
}
;

create procedure
b3s_http_print_l (in p_text any, inout odd_position int, in r int := 0, in sid varchar := null, in langs any := null)
{
   declare short_p, p_prefix, int_redirect, url any;

   odd_position := odd_position + 1;
   p_prefix := b3s_label (p_text, langs);
   if (not length (p_prefix))
     p_prefix := b3s_uri_curie (p_text);
   url := b3s_http_url (p_text, sid, null, 0);

   if (not length (p_text))
     return;

   http (sprintf ('<tr class="%s"><td class="property">', either (mod (odd_position, 2), 'odd', 'even')));

   if (r) http ('is ');

   http (sprintf ('<a class="uri" href="%s" title="%s">%s</a>\n',
                  url,
                  p_prefix,
                  b3s_trunc_uri (p_prefix, 40)));

   if (r) http (' of');

   http ('</td><td><ul class="obj">');
}
;

create procedure b3s_label (in _S any, in langs any, in lbl_order_pref_id int := 0)
{
  declare best_str, meta, data any;
  declare best_q, q float;
  declare lang, stat, msg varchar;

  if (__proc_exists ('rdf_resolve_labels_s') is not null)
    {
      declare ret any;
      ret := rdf_resolve_labels_s (adler32 (langs), vector (__i2id (_S)));
      ret := coalesce (ret[0], '');
      ret := __ro2sq (ret); 
      if (__tag (ret) = 246)
	ret := __rdf_strsqlval (ret);
      if (isnumeric (ret)) 
        return (cast (ret as varchar));
      return ret;	
    }
  stat := '00000';
  --exec (sprintf ('sparql define input:inference "facets" '||
  --'select ?o (lang(?o)) where { <%s> virtrdf:label ?o }', _S), stat, msg, vector (), 0, meta, data);
  exec (sprintf ('select __ro2sq (O), DB.DBA.RDF_LANGUAGE_OF_OBJ (__ro2sq (O)) , cast (b3s_lbl_order (P, %d) as int) from RDF_QUAD table option (with ''facets'')
	where S = __i2id (?) and P = __i2id (''http://www.openlinksw.com/schemas/virtrdf#label'', 0) and not is_bnode_iri_id (O) order by 3 option (same_as)', lbl_order_pref_id), 
	stat, msg, vector (_S), 0, meta, data);
  if (stat <> '00000')
    return '';
  best_str := '';
  best_q := 0;
  if (length (data))
    {
      for (declare i, l int, i := 0, l := length (data); i < l; i := i + 1)
	{
	  q := b3s_get_lang_by_q (langs, data[i][1]);
	  --dbg_obj_print (data[i][0], langs, data[i][1], q);
          if (q > best_q)
	    {
	      best_str := data[i][0];
	      best_q := q;
	    }
	}
    }
  if (__tag (best_str) = 246)
    {
      best_str := __rdf_strsqlval (best_str);
    }

  if (isnumeric (best_str))
    return (cast (best_str as varchar));

  return best_str;
}
;

create procedure b3s_xsd_link (in t varchar)
{
  return sprintf ('<a href="http://www.w3.org/2001/XMLSchema#%s">xsd:%s</a>', t, t);
}
;

create procedure b3s_o_is_out (in x any)
{
  declare f, s, og any;
  f := 'http://xmlns.com/foaf/0.1/';
  s := 'http://schema.org/';
  og := 'http://opengraphprotocol.org/schema/';
  -- foaf:page, foaf:homePage, foaf:img, foaf:logo, foaf:depiction
  if (__ro2sq (x) in (f||'page', f||'homePage', f||'img', f||'logo', f||'depiction', 'http://schema.org/url', 'http://schema.org/downloadUrl', 'http://schema.org/potentialAction', s||'logo', s||'image', s || 'mainEntityOfPage', og || 'image', 'http://www.openlinksw.com/ontology/webservices#usageExample'))
    {
      return 1;
    }
  return 0;
}
;

create procedure b3s_o_is_img (in x any)
{
  declare f, s, og any;
  f := 'http://xmlns.com/foaf/0.1/';
  s := 'http://schema.org/';
  og := 'http://opengraphprotocol.org/schema/';
  if (__ro2sq (x) in (f||'img', f||'logo', f||'depiction', s||'logo', s||'image', og || 'image', 'http://ogp.me/ns#image'))
    {
      return 1;
    }
  return 0;
}
;

create procedure
b3s_http_print_r (in _object any, in sid varchar, in prop any, in langs any, in rel int := 1, in acc any := null, in _from varchar := null, in flag int := 0)
{
   declare lang, rdfs_type, rdfa, visible any;
   declare robotsrel varchar;

   if (_object is null)
     return;

   robotsrel := registry_get('fct_robots_rel');
   if(robotsrel is null or robotsrel='' or robotsrel=0) {
    robotsrel:=' rel="nofollow" ';
   }

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
   if (__tag of IRI_ID = __tag (rdfs_type))
     rdfs_type := id_to_iri (rdfs_type);

   rdfa := b3s_rel_print (prop, rel, 1);
   visible := b3s_str_lang_check (lang, acc);
   http (sprintf ('\t<li%s><span class="literal">', case visible when 0 then ' style="display:none;"' else '' end));
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

       if (not length (_url))
         return;

       http (sprintf ('<!-- %d -->', length (_url)));

       rdfa := b3s_rel_print (prop, rel, 0);
       if (prop = 'http://bblfish.net/work/atom-owl/2006-06-06/#content' and _url like '%#content%') {
          declare src, abody, mt any;
          -- whenever not found goto usual_iri;
           mt := null;
          mt := (select top 1 __ro2sq(o) from DB.DBA.RDF_QUAD where S = iri_to_id (_object, 0) and P = iri_to_id ('http://bblfish.net/work/atom-owl/2006-06-06/#type', 0) );
           if (rdf_box_data(mt) not like 'text/%') {
            goto usual_iri;
           }
           src := ( select top 1 coalesce(id_to_iri(O), NULL) from DB.DBA.RDF_QUAD where S = iri_to_id (_object, 0) and P = iri_to_id ('http://bblfish.net/work/atom-owl/2006-06-06/#src', 0) );
           abody:='';
           if(src is not NULL and length(src)>5) {
             abody := sprintf('<iframe src="%s" width="100%%" height="100%%" frameborder="0" sandbox="sandbox"><p>Your browser does not support iframes.</p></iframe></div><br/>', src);
           } else {
               if(mt like '%html%') {
                 abody := (select top 1 __rdf_sqlval_of_obj(O) from RDF_QUAD
                     where S=iri_to_id(_url)
                     and P=iri_to_id('http://bblfish.net/work/atom-owl/2006-06-06/#body'));
                }
            }
           if(abody is not null) {
             abody := cast(abody as varchar);
             if(length(abody)>5) {
		declare lbl, vlbl any;
		lbl := '';
		if ((registry_get ('fct_desc_value_labels') = '1' or registry_get ('fct_desc_value_labels') = 0) and (__tag (_object) = 243 or (isstring (_object) and __box_flags (_object) = 1)))
		  lbl := b3s_label (_url, langs, 1);
		if ((not isstring(lbl)) or length (lbl) = 0)
		  lbl := b3s_uri_curie(_url);
		http (sprintf ('<a %s class="uri" %s href="%s">', robotsrel, rdfa, b3s_http_url (_url, sid, _from)));
		vlbl := charset_recode (lbl, 'UTF-8', '_WIDE_');
		http_value (case when vlbl <> 0 then vlbl else lbl end);
		http (sprintf ('</a>'));
		if (b3s_o_is_out (prop))
		  http (sprintf ('&nbsp;<a href="%s"><img src="/fct/images/fct-linkout-16-blk.png" border="0"/></a>', _url));
                http(sprintf('<div id="x_content" class="content embedded">%s</div>', cast(abody as varchar)));
             }
           } else {
                goto usual_iri;
           }
	 }
       else if (http_mime_type (_url) like 'image/%' or http_mime_type (_url) = 'application/x-openlink-photo' or b3s_o_is_img (prop))
	 {
	   declare u any;
	   if (b3s_o_is_out (prop))
	     u := _url;
	   else
	     u := b3s_http_url (_url, sid, _from);
	   http (sprintf ('<a class="uri" %s href="%s"><img src="%s" height="160" style="border-width:0" alt="External Image" /></a>', rdfa, u, _url));
	 }
       else
	 {
	   usual_iri:;
	   declare lbl, vlbl any;
	   lbl := '';
	   if ((registry_get ('fct_desc_value_labels') = '1' or registry_get ('fct_desc_value_labels') = 0) and (__tag (_object) = 243 or (isstring (_object) and __box_flags (_object) = 1)))
	     lbl := b3s_label (_url, langs, 1);
	   if ((not isstring(lbl)) or length (lbl) = 0)
	     lbl := b3s_uri_curie(_url);
	   -- XXX: must encode as wide label to print correctly
	   --http (sprintf ('<a class="uri" %s href="%s">%V</a>', rdfa, b3s_http_url (_url, sid, _from), lbl));
	   http (sprintf ('<a %s class="uri" %s href="%s">', robotsrel, rdfa, b3s_http_url (_url, sid, _from)));
	   vlbl := charset_recode (lbl, 'UTF-8', '_WIDE_');
	   http_value (case when vlbl <> 0 then vlbl else lbl end);
	   http (sprintf ('</a>'));
	   if (b3s_o_is_out (prop))
	     http (sprintf ('&nbsp;<a href="%s"><img src="/fct/images/fct-linkout-16-blk.png" border="0"/></a>', _url));
	 }

     }
   else if (__tag (_object) = 189)
     {
       http (sprintf ('<span %s>%d</span>', rdfa, _object));
       lang := b3s_xsd_link ('integer');
     }
   else if (__tag (_object) = 190)
     {
       http (sprintf ('<span %s>%f</span>', rdfa, _object));
       lang := b3s_xsd_link ('float');
     }
   else if (__tag (_object) = 191)
     {
       http (sprintf ('<span %s>%d</span>', rdfa, _object));
       lang := b3s_xsd_link ('double');
     }
   else if (__tag (_object) = 219)
     {
       http (sprintf ('<span %s>%s</span>', rdfa, cast (_object as varchar)));
       lang := b3s_xsd_link ('double');
     }
   else if (__tag (_object) = 182)
     {
       declare vlbl any;
       if (b3s_o_is_img (prop))
	 {
	   __box_flags_set (_object, 1);
	   goto again;
	 }
       http (sprintf ('<span %s>', rdfa));
       if (strstr (_object, 'http://') is not null)
	 {
	   declare continue handler for sqlstate '*';
           _object := regexp_replace (_object, ' (http://[^ ]+) ', ' <a href="\\1">\\1</a> ', 1, null);
	 }
       vlbl := charset_recode (_object, 'UTF-8', '_WIDE_');
       if (vlbl = 0)
         vlbl := charset_recode (_object, current_charset (), '_WIDE_');
       if (vlbl = 0 or _object like '<object%' or _object like '<iframe%' or ltrim (_object) like '<%' or strstr (_object, '<a href') is not null)
         http (_object);
       else
         http_value (vlbl);
       http ('</span>');
       --lang := '';
     }
   else if (__tag (_object) = 211)
     {
       http (sprintf ('<span %s>%s</span>', rdfa, datestring (_object)));
       lang := b3s_xsd_link ('dateTime');
     }
   else if (__tag (_object) = 230)
     {
       _object := serialize_to_UTF8_xml (_object);
       _object := replace (_object, '<xhtml:', '<');
       _object := replace (_object, '</xhtml:', '</');
       http (sprintf ('<span %s>', rdfa));
       http (_object);
       http ('</span>');
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
       http (cast (_object as varchar));
       http ('</span>');
     }
   else if (__tag (_object) = 222)
     {
       http (sprintf ('<span %s>', rdfa));
       http (cast (_object as varchar));
       http ('</span>');
     }
   else if (__tag (_object) = 126)
     {
       http (sprintf ('<span %s>', rdfa));
       http ('&lt;binary object&gt;');
       http ('</span>');
     }
   else
     http (sprintf ('FIXME %i', __tag (_object)));

   if (lang is not NULL and lang <> '')
     {
       http (sprintf (' <small>(%s)</small>', lang));
     }

   http ('</span></li>');
   return visible;
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

create procedure fct_links_formats ()
{
  return vector (
  	   vector ('application/rdf+xml','RDF/XML'),
  	   vector ('text/n3','N3/Turtle'),
  	   vector ('application/rdf+json','RDF/JSON'),
  	   vector ('application/atom+xml','OData/Atom'),
  	   vector ('application/odata+json','OData/JSON'),
  	   vector ('text/cxml','CXML'),
  	   vector ('text/csv','CSV'),
  	   vector ('application/microdata+json','Microdata/JSON'),
  	   vector ('text/html','HTML+Microdata'),
  	   vector ('application/ld+json','JSON-LD')
  	);
}
;

create procedure fct_links_hdr (in subj any, in desc_link any)
{
  declare links varchar;
  declare vec any;
  desc_link := sprintf ('http://%{WSHost}s%s', desc_link);
  links := 'Link: ';
  vec := fct_links_formats ();
  foreach (any elm in vec) do
    {
      links := links ||
      sprintf ('<%s&output=%U>; rel="alternate"; type="%s"; title="Structured Descriptor Document (%s format)",', desc_link, elm[0], elm[0], elm[1]);
    }
  links := links || sprintf ('<%s>; rel="http://xmlns.com/foaf/0.1/primaryTopic",', subj);
  links := links || ' <?first>; rel="first", <?last>; rel="last", <?next>; rel="next", <?prev>; rel="prev", ';
  links := links || sprintf ('<%s>; rev="describedby"\r\n', subj);
  http_header (http_header_get () || links);
}
;


create procedure fct_links_mup (in subj any, in desc_link any)
{
  declare links varchar;
  declare vec any;
  desc_link := sprintf ('http://%{WSHost}s%s', desc_link);
  links := '';
  vec := fct_links_formats ();
  foreach (any elm in vec) do
    {
      links := links || repeat (' ', 5) ||
      sprintf ('<link href="%V&amp;output=%U" rel="alternate" type="%s"  title="Structured Descriptor Document (%s format)" />\n', desc_link, elm[0], elm[0], elm[1]);
    }
  links := links || repeat (' ', 5) || sprintf ('<link href="%V" rel="http://xmlns.com/foaf/0.1/primaryTopic" />\n', subj);
  links := links || repeat (' ', 5) || sprintf ('<link href="%V" rev="describedby" />\n', subj);
  http (links);
}
;

create procedure
fct_make_selector (in subj any, in sid integer)
{
  return null;
}
;

create procedure fct_make_curie (in url varchar, in lines any)
{
  declare curie, chost, dhost varchar;
  if (__proc_exists ('WS.CURI.curi_make_curi') is null)
    return url;
  curie := WS.CURI.curi_make_curi (url);
  dhost := registry_get ('URIQADefaultHost');
  chost := http_request_header(lines, 'Host', null, dhost);
  return sprintf ('http://%s/c/%s', chost, curie);
}
;


create procedure DB.DBA.SPARQL_DESC_DICT_LOD_PHYSICAL (in subj_dict any, in consts any, in good_graphs any, in bad_graphs any, in storage_name any, in options any)
{
  declare all_subj_descs, phys_subjects, sorted_good_graphs, sorted_bad_graphs, g_dict, res any;
  declare uid, graphs_listed, g_ctr, good_g_count, bad_g_count, s_ctr, all_s_count, phys_s_count integer;
  declare gs_app_callback, gs_app_uid varchar;

  if (isinteger (consts))
    goto normal;

  uid := get_keyword ('uid', options, http_nobody_uid());
  gs_app_callback := get_keyword ('gs-app-callback', options);
  if (gs_app_callback is not null)
    gs_app_uid := get_keyword ('gs-app-uid', options);

  phys_subjects := dict_list_keys (subj_dict, 0);
  phys_subjects := vector_concat (phys_subjects, consts);
  phys_s_count := length (phys_subjects);
  if (__tag of integer = __tag (good_graphs))
    {
      g_dict := dict_new ();
      vectorbld_init (sorted_bad_graphs);
      foreach (any g in bad_graphs) do
	{
	  if (isiri_id (g) and g < min_bnode_iri_id ())
	    vectorbld_acc (sorted_bad_graphs, g);
	}
      vectorbld_final (sorted_bad_graphs);
      for (s_ctr := phys_s_count - 1; s_ctr >= 0; s_ctr := s_ctr - 1)
	{
	  declare subj, graph any;
	  subj := phys_subjects [s_ctr];
	  graph := coalesce ((select top 1 G as g1 from DB.DBA.RDF_QUAD where O = subj and 0 = position (G, sorted_bad_graphs) and
	    __rgs_ack_cbk (G, uid, 1) and
	    (gs_app_callback is null or bit_and (1, call (gs_app_callback) (G, gs_app_uid))) ) );
	  if (graph is not null)
	    dict_put (g_dict, graph, 0);
	}
      sorted_good_graphs := dict_list_keys (g_dict, 0);
      if (0 = length (sorted_good_graphs))
	{
	  g_dict := dict_new ();
	  for (s_ctr := phys_s_count - 1; s_ctr >= 0; s_ctr := s_ctr - 1)
	    {
	      declare subj, graph any;
	      subj := phys_subjects [s_ctr];
	      graph := coalesce ((select top 1 G as g1 from DB.DBA.RDF_QUAD where S = subj and 0 = position (G, sorted_bad_graphs) and
		__rgs_ack_cbk (G, uid, 1) and
		(gs_app_callback is null or bit_and (1, call (gs_app_callback) (G, gs_app_uid))) ) );
	      if (graph is not null)
		dict_put (g_dict, graph, 0);
	    }
	  sorted_good_graphs := dict_list_keys (g_dict, 1);
	}
      if (0 < length (sorted_good_graphs))
	good_graphs := sorted_good_graphs;
    }
  normal:
  return DB.DBA.SPARQL_DESC_DICT (subj_dict, consts, good_graphs, bad_graphs, storage_name, options);
}
;

create procedure DB.DBA.SPARQL_DESC_DICT_LOD (in subj_dict any, in consts any, in good_graphs any, in bad_graphs any, in storage_name any, in options any)
{
  return DB.DBA.SPARQL_DESC_DICT (subj_dict, consts, good_graphs, bad_graphs, storage_name, options);
}
;

grant execute on DB.DBA.SPARQL_DESC_DICT_LOD_PHYSICAL to "SPARQL_SELECT";
grant execute on DB.DBA.SPARQL_DESC_DICT_LOD to "SPARQL_SELECT";

create procedure b3s_lbl_order (in p any, in lbl_order_pref_id int := 0)
{
  declare r int;
  r := vector (
  'http://www.w3.org/2000/01/rdf-schema#label',
  'http://xmlns.com/foaf/0.1/name',
  'http://purl.org/dc/elements/1.1/title',
  'http://purl.org/dc/terms/title',
  'http://xmlns.com/foaf/0.1/nick',
  'http://usefulinc.com/ns/doap#name',
  'http://rdf.data-vocabulary.org/name',
  'http://www.w3.org/2002/12/cal/ical#summary',
  'http://aims.fao.org/aos/geopolitical.owl#nameListEN',
  'http://s.opencalais.com/1/pred/name',
  'http://www.crunchbase.com/source_description',
  'http://dbpedia.org/property/name',
  'http://www.geonames.org/ontology#name',
  'http://purl.org/ontology/bibo/shortTitle',
  'http://www.w3.org/1999/02/22-rdf-syntax-ns#value',
  'http://xmlns.com/foaf/0.1/accountName',
  'http://www.w3.org/2004/02/skos/core#prefLabel',
  'http://rdf.freebase.com/ns/type.object.name',
  'http://s.opencalais.com/1/pred/name',
  'http://www.w3.org/2008/05/skos#prefLabel',
  'http://www.w3.org/2002/12/cal/icaltzd#summary',
  'http://rdf.data-vocabulary.org/name',
  'http://rdf.freebase.com/ns/common.topic.alias',
  'http://opengraphprotocol.org/schema/title',
  'http://rdf.alchemyapi.com/rdf/v1/s/aapi-schema.rdf#Name',
  'http://poolparty.punkt.at/demozone/ont#title',
  'http://linkedopencommerce.com/schemas/icecat/v1/hasShortSummaryDescription',
  'http://www.openlinksw.com/schemas/googleplus#displayName'
   );

  if (lbl_order_pref_id = 1)
    -- Give skos:prefLabel precedence
    -- NLP meta-cartridges use skos:prefLabel to include a prefix identifying the meta-cartridge which identified a named entity
    r := vector_concat (vector ('http://www.w3.org/2004/02/skos/core#prefLabel'), r);

  r := position (id_to_iri (p), r);
  if (r = 0)
    return 100;
  return r;
}
;


create function DB.DBA.FCT_GRAPH_USAGE_SUMMARY (in subj_iri any, in fld varchar, in lim integer := 20) returns any
{
  declare qr varchar;
  declare q_txt, tot_dict, phy_dict, quad_maps, rset, tmp_res, res any;
  declare tot_dict_size, ctr, len integer;
  quad_maps := case fld when 'S' then sparql_quad_maps_for_quad (NULL, uname(subj_iri), NULL, NULL) else sparql_quad_maps_for_quad (NULL, NULL, NULL, uname(subj_iri)) end;
  tot_dict_size := lim + length (quad_maps) * 2;
  tot_dict := dict_new (tot_dict_size);
  phy_dict := dict_new (lim);
  qr := 'sparql define input:storage ""
select str(?g) count (*)
where
  { graph ?g { ' || case fld when 'S' then '`iri(??)`' else '?s' end || ' ?p ' || case fld when 'O' then '`iri(??)`' else '?o' end || '
      } } group by ?g order by desc 2 limit ' || cast (tot_dict_size as varchar);
  rset := null;
  exec (qr, null, null, vector (subj_iri), vector ('max_rows', lim), null, rset);
  foreach (any g_and_cnt in rset) do
    {
      dict_put (phy_dict, g_and_cnt[0], g_and_cnt[1]);
      dict_inc_or_put (tot_dict, g_and_cnt[0], g_and_cnt[1]);
    }
  foreach (any qm_item in quad_maps) do
    {
      declare qm any;
      declare stat, msg varchar;
      declare inx, rset_len integer;
      qm := qm_item[0];
      if (qm = UNAME'http://www.openlinksw.com/schemas/virtrdf#DefaultQuadMap')
        goto done;
      q_txt := string_output();
      http ('sparql select str(?g) count (1) where { graph ?g { quad map ', q_txt);
      http_sparql_object (qm, q_txt);
      http (' { ', q_txt);
      if ('O' = fld) http ('?s ?p ', q_txt);
      http_sparql_object (__box_flags_tweak (subj_iri, 1), q_txt);
      if ('S' = fld) http (' ?p ?o', q_txt);
      http (' } } } limit ' || tot_dict_size, q_txt);
      stat := '00000';
      rset := null;
      exec (string_output_string (q_txt), stat, msg, vector(), vector ('use_cache', 1, 'max_rows', tot_dict_size), null, rset);
      rset_len := length (rset);
      --dbg_obj_princ (string_output_string (q_txt));
      --dbg_obj_princ (stat, msg, rset_len);
      for (inx := 0; inx < rset_len; inx := inx + 1)
        dict_inc_or_put (tot_dict, rset[inx][0], rset[inx][1]);
    }
done: ;
  tmp_res := dict_to_vector (tot_dict, 2);
  len := length (tmp_res) / 2;
  res := make_array (len, 'any');
  for (ctr := 0; ctr < len; ctr := ctr + 1)
    res[ctr] := vector (tmp_res[ctr*2], tmp_res[ctr*2+1], dict_get (phy_dict, tmp_res[ctr*2], 0));
  rowvector_digit_sort (res, 1, 0);
  if (len > lim)
  return subseq (res, 0, lim);
  return res;
}
;

create procedure b3s_gs_check_needed ()
{
  declare gs_user_id integer;
  gs_user_id := get_user_id (1);
  if ( bit_and (1,
      coalesce (
        dict_get (__rdf_graph_default_perms_of_user_dict(0), gs_user_id, null),
        dict_get (__rdf_graph_default_perms_of_user_dict(0), http_nobody_uid(), 1023) ) )
    and bit_and (1,
      coalesce (
        dict_get (__rdf_graph_default_perms_of_user_dict(1), gs_user_id, null),
        dict_get (__rdf_graph_default_perms_of_user_dict(1), http_nobody_uid(), 1023) ) ) )
  {
    -- dbg_obj_princ ('gs sec check not needed');
    return 0;
  }
  -- dbg_obj_princ ('gs sec check is needed');
  return 1;
}
;

--- Identifies the graph(s) containing the given entity
--- * For entity URIs of the form /about/id[/entity]/{data_source_uri}[#child_entity_id] or /proxy-iri/xxx
---   ensures that the correct data source URI is sponged
-- * Allows us the check the permissions on the graph before an attempted read or sponge and, if reading or
--   sponging is denied, provide some feedback in the /describe UI, rather than just display an empty result set.
-- * If we're not handling a sponge request and the given entity is present in multiple graphs:
--     * null is returned for the entity graph
--     * we then make no attempt to determine the user's permissions on these graphs prior to the select to
--       fetch the results for display. It's assumed that RDF_GRAPH_USER_PERMS_ACK() will filter the results
--       from any graphs for which the user doesn't have read permission.
create procedure b3s_get_entity_graph (in entity_uri varchar, in sponge_request int)
{
  declare arr, pa, sch, nhost, tmp, npath, entity_graph any;

  arr := rfc1808_parse_uri (entity_uri);
  if (arr[0] = 'nodeID')
    return rtrim (entity_uri, '/');

  if (not (arr[2] like '/about/id%' or arr[2] like '/proxy-iri/%'))
  {
    if (sponge_request)
      return entity_uri; -- the entity description is sponged to a graph with the same URI
    else
    {
      declare num_containing_graphs int;
      num_containing_graphs := (
	select count(distinct G) from DB.DBA.RDF_QUAD where 
          S = iri_to_id (entity_uri) and 
	  G not in (select RGGM_MEMBER_IID from DB.DBA.RDF_GRAPH_GROUP_MEMBER 
                    where RGGM_GROUP_IID = iri_to_id('http://www.openlinksw.com/schemas/virtrdf#PrivateGraphs')));
      if (num_containing_graphs > 1)
      {
	return null;
      }
      else
      {
	entity_graph := (select top 1 id_to_iri(G) from DB.DBA.RDF_QUAD where 
          S = iri_to_id (entity_uri) and 
	  G not in (select RGGM_MEMBER_IID from DB.DBA.RDF_GRAPH_GROUP_MEMBER 
                    where RGGM_GROUP_IID = iri_to_id('http://www.openlinksw.com/schemas/virtrdf#PrivateGraphs')));
	-- Assume client is attempting to view an empty graph
	if (entity_graph is not null)
	{
	  ;
	}
	else
	{
	  entity_graph := entity_uri;
	}
	return entity_graph;
      }
    }
  }

  -- Handle /about/id/* and /proxy-iri/* style entity URIs

  entity_graph := (select top 1 id_to_iri(G) from DB.DBA.RDF_QUAD where 
	  S = iri_to_id (entity_uri) and
	  G not in (select RGGM_MEMBER_IID from DB.DBA.RDF_GRAPH_GROUP_MEMBER 
                    where RGGM_GROUP_IID = iri_to_id('http://www.openlinksw.com/schemas/virtrdf#PrivateGraphs')));
  if (entity_graph is not null)
  {
    return entity_graph;
  }

  -- Assume the original containing graph has been cleared. Deduce it.

  if (arr[2] like '/proxy-iri/%')
    return RDF_SPONGE_PROXY_IRI_GET_GRAPH (entity_uri);

  entity_graph := entity_uri;
  -- Strip off fragment - entity_uri could be a child entity with a hash URI
  arr[5] := ''; 

  pa := split_and_decode (arr[2], 0, '\0\0/');
  if (length (pa) > 5 and pa[3] = 'entity' and pa[4] <> '' and pa [5] <> '')
{
    -- Set entity_graph to the URI following /about/id/entity/
    sch := pa[4];
    nhost := pa [5];
    tmp := '/about/id/entity/' || sch || '/' || nhost;
    npath := subseq (arr[2], length (tmp));    
    arr[0] := sch;
    arr[1] := nhost;
    arr[2] := npath;
    
    if (lower(arr[0]) in ('acct', 'mailto')) 
    {
      arr [2] := arr[1];
      arr [1] := '';
    }

    entity_graph := DB.DBA.vspx_uri_compose (arr);
  }
  else if (length (pa) > 4 and pa[3] <> '' and pa [4] <> '')
  {
    -- Set entity_graph to the URI following /about/id/
    sch := pa[3];
    nhost := pa [4];
    tmp := '/about/id/' || sch || '/' || nhost;
    npath := subseq (arr[2], length (tmp));    
    arr[0] := sch;
    arr[1] := nhost;
    arr[2] := npath;
    
    if (sch in ('acct', 'mailto'))
    {
      arr[2] := arr[1];
      arr[1] := '';
    }
	    
    entity_graph := DB.DBA.vspx_uri_compose (arr);
  }

  return entity_graph;
}
;

-- Checks a user's permissions on a single graph
create procedure b3s_get_user_graph_permissions (
  in graph varchar,
  in pageUrl varchar,
  in sponge_request int,
  in val_vad_present int,
  in val_serviceId varchar,
  in val_auth_method int,
  inout graph_perms_allow_sponge int,
  inout view_mode varchar
  )
{
  declare user_permissions int;

  view_mode := 'full';
  graph_perms_allow_sponge := 1;
  user_permissions := 15;

  -- graph == null indicates that the subject entity URI being viewed is contained in multiple graphs.
  -- Don't attempt to check permissions here if this is the case, as here we only check permissions
  -- on a single graph
  -- FIX ME: 
  -- See use of RDF_GRAPH_USER_PERMS_ACK [1] by dt1 and dt2 in description.vsp. 
  -- Filtering of results from multiple graphs should be done at this point [1]

  if (graph is not null)
    user_permissions := DB.DBA.RDF_GRAPH_USER_PERMS_GET (graph, http_nobody_uid());

  if (bit_and (user_permissions, 1) = 0)
  {
    -- User doesn't have read permission
    view_mode := 'none';
    graph_perms_allow_sponge := 0;
  }
  else if (bit_and (user_permissions, 4) = 0)
  {
    graph_perms_allow_sponge := 0;
    if (bit_and (user_permissions, 2))
      view_mode := 'read-write';
    else
      view_mode := 'read-only';
  }
}
;

grant execute on b3s_gs_check_needed to public;

create procedure fct_set_graphs (in sid any, in graphs any)
{
  declare xt, newx, s any;
  if (sid is null) return;
  xt := (select fct_state from fct_state where fct_sid = sid);
  s := string_output ();
  http ('<graphs>', s);
  foreach (any g in graphs) do
    {
      http (sprintf ('<graph name="%V" />', g), s);
    } 
  http ('</graphs>', s);
  newx := xslt (registry_get ('_fct_xslt_') || 'fct_set_graphs.xsl', xt, vector ('graphs', xtree_doc (s)));
  update fct_state set fct_state = newx where fct_sid = sid; 
  commit work;
}
;


create procedure FCT.DBA.build_page_url_on_current_host (
  in path varchar,
  in query varchar)
{
  declare protocol varchar;
  declare host any;

  host := http_request_header (http_request_header (), 'X-Forwarded-Host', null, null);
  if (host is null)
    host := http_request_header (http_request_header (), 'Host');

  protocol := 'http'; if (is_https_ctx()) protocol := 'https';

  return sprintf ('%s://%s%s?%s', protocol, host, path, query);
}
;

create procedure FCT.DBA.get_describe_request_params (
  in params any
  )
{
  declare desc_params varchar;

  desc_params := '';
  if (get_keyword ('sp', params) is not null)
    desc_params := desc_params || '&sp=' || get_keyword ('sp', params);
  if (get_keyword ('sponger:get', params) is not null)
    desc_params := desc_params || '&sponger:get=' || get_keyword ('sponger:get', params);
  if (get_keyword ('sr', params) is not null)
    desc_params := desc_params || '&sr=' || get_keyword ('sr', params);

  return desc_params;
}
;
