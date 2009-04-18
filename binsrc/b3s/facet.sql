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

-- Facet web service

create procedure
fct_uri_curie (in uri varchar)
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

    nsPrefix := coalesce (__xml_get_ns_prefix (subseq (uriSearch, 0, delim + 1), 2),
                          __xml_get_ns_prefix (subseq (uriSearch, 0, delim), 2));

    uriSearch := subseq (uriSearch, 0, delim);
--    dbg_obj_print(uriSearch);
  }

  if (nsPrefix is not null)
    {
      declare rhs varchar;
      rhs := subseq (uri, length (uriSearch) + 1, null);

      if (length (rhs) = 0)
        {
          return null;
        }
      else
        {
          return nsPrefix || ':' || rhs;
        }
    }
  return null;
}
;

create procedure
fct_short_uri (in x any)
{
  declare loc, pref, sh varchar;

  if (not isstring (x))
    return x;

  pref := iri_split (x, loc);

  sh := __xml_get_ns_prefix (pref, 2);

  if (sh is not null)
    return sh || ':' || loc;
  return x;
}
;

create procedure
fct_trunc_uri (in s varchar, in maxlen int := 40)
{
  declare _s varchar;
  declare _h int;

  _s := trim(s);

  if (length(_s) <= maxlen) return _s;
  _h := floor (maxlen / 2);
  return sprintf ('%s...%s', "LEFT"(_s, _h), "RIGHT"(_s, _h-1));
}
;

create procedure
fct_short_form (in x any, in ltgt int := 0)
{
  declare loc, pref, sh varchar;

  if (not isstring (x))
    return null;

  sh := fct_uri_curie(x);

  if (x like 'NodeID%')
    return 'Blank' || x;

  if (sh is not null)
    return (fct_trunc_uri(sh));
  else return (case when ltgt then '&lt;' || fct_trunc_uri (x) || '&gt;' else fct_trunc_uri (x) end);
}
;

create procedure
fct_long_uri (in x any)
{
  declare loc, pref, sh varchar;
  if (not isstring (x))
    return x;
 pref := iri_split (x, loc);
  if ('' = pref or ':' <> subseq (pref, length (pref) - 1))
    return x;
 sh := __xml_get_ns_uri (subseq (pref, 0, length (pref) - 1), 2);
  if (sh is not null)
    return sh || loc;
  return x;
}
;

cl_exec ('registry_set (''fct_label_iri'', ?)',
         vector (cast (iri_id_num (__i2id ('http://www.openlinksw.com/schemas/virtrdf#label')) as varchar)));

cl_exec ('registry_set (''fct_timeout_min'',''2000'')');
cl_exec ('registry_set (''fct_timeout_max'',''40000'')');

create procedure
FCT_LABEL (in x any, in g_id iri_id_8, in ctx varchar)
{
  declare best_str any;
  declare best_l, l int;
  declare label_iri iri_id_8;
  if (not isiri_id (x))
    return null;
  rdf_check_init ();
  label_iri := iri_id_from_num (atoi (registry_get ('fct_label_iri')));
  best_str := null;
  best_l := 0;
  for select o, p from rdf_quad  where s = x and p in (rdf_super_sub_list (ctx, label_iri, 3)) do
    {
      if (is_rdf_box (o) or isstring (o))
	{
	  if (is_rdf_box (o) and not rdf_box_is_complete (o))
	    L := 20;
	  else
	    l := length (o);
	  if (l > best_l)
	    {
	    best_str := o;
	    best_l := l;
	    }
	}
    }
  return __ro2sq(best_str);
}
;

create procedure
FCT_LABEL_DP (in x any, in g_id iri_id_8, in ctx varchar)
{
  declare best_str any;
  declare best_l, l int;
  declare label_iri iri_id_8;
  if (not isiri_id (x))
    return vector (null, 1);
  rdf_check_init ();
  label_iri := iri_id_from_num (atoi (registry_get ('fct_label_iri')));
  best_str := null;
  best_l := 0;
  for select o, p
        from rdf_quad table option (no cluster)
        where s = x and p in (rdf_super_sub_list (ctx, label_iri, 3)) do
    {
      if (is_rdf_box (o) or isstring (o))
	{
	  if (is_rdf_box (o) and not rdf_box_is_complete (o))
	    L := 20;
	  else
	    l := length (o);
	  if (l > best_l)
	    {
	    best_str := o;
	    best_l := l;
	    }
	}
    }
  if (is_rdf_box (best_str) and not rdf_box_is_complete (best_str))
    return vector (0, 0, vector ('LBL_O_VALUE', vector (rdf_box_ro_id (best_str))));
  return vector (best_str, 1);
}
;

create procedure
LBL_O_VALUE (in id int)
{
  set isolation = 'committed';
  return vector ((select case (isnull (RO_LONG)) when 0 then blob_to_string (RO_LONG) else RO_VAL end
		   from DB.DBA.RDF_OBJ table option (no cluster) where RO_ID = id), 1);
}
;

dpipe_define ('DB.DBA.FCT_LABEL', 'DB.DBA.RDF_QUAD', 'RDF_QUAD_OPGS', 'DB.DBA.FCT_LABEL_DP', 0);
dpipe_define ('FCT_LABEL', 'DB.DBA.RDF_QUAD', 'RDF_QUAD_OPGS', 'DB.DBA.FCT_LABEL_DP', 0);
dpipe_define ('LBL_O_VALUE', 'DB.DBA.RDF_OBJ', 'RDF_OBJ', 'DB.DBA.LBL_O_VALUE', 0);

ttlp ('
@prefix foaf: <http://xmlns.com/foaf/0.1/>
@prefix dc: <http://purl.org/dc/elements/1.1/>
@prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#>
@prefix virtrdf: <http://www.openlinksw.com/schemas/virtrdf#>

rdfs:label rdfs:subPropertyOf virtrdf:label .
dc:title rdfs:subPropertyOf virtrdf:label .
foaf:name rdfs:subPropertyOf virtrdf:label .
foaf:nick rdfs:subPropertyOf virtrdf:label .', 'xx', 'facets');

rdfs_rule_set ('facets', 'facets');

create procedure
fct_inf_clause (in tree any)
{
  declare i varchar;
 i := cast (xpath_eval ('/query/@inference', tree) as varchar);
  if (i is null or '' = i)
    return '';
  return sprintf (' define input:inference "%s" ', cast (i as varchar));
}
;

create procedure
fct_sas_clause (in tree any)
{
  declare i varchar;
 i := cast (xpath_eval ('/query/@same-as', tree) as varchar);
  if (i is null or '' = i)
    return '';
  return sprintf (' define input:same-as "%s" ', cast (i as varchar));
}
;

create procedure
fct_graph_clause (in tree any)
{
  declare i varchar;
 i := cast (xpath_eval ('/query/@graph', tree) as varchar);
  if (i is null or '' = i)
    return '';
  return sprintf (' define input:default-graph-uri <%s> ', cast (i as varchar));
}
;

create procedure
fct_post (in tree any, in post any, in lim int, in offs int)
{
  if (lim is not null)
    http (sprintf (' limit %d ', cast (lim as int)), post);
  if (offs is not null)
    http (sprintf (' offset %d ', cast (offs as int)), post);
}
;

create procedure
fct_dtp (in x any)
{
  if (isiri_id (x))
    return 'url';
  return id_to_iri (rdf_datatype_of_long (x));
}
;

create procedure
fct_lang (in x any)
{
  if (not is_rdf_box (x))
    return NULL;
  if (rdf_box_lang (x) = 257)
    return null;
  return (select rl_id from rdf_language where rl_twobyte = rdf_box_lang (x));
}
;

create procedure
fct_xml_wrap (in tree any, in txt any)
{
  declare view_type varchar;
  view_type := cast (xpath_eval ('//view/@type', tree, 1) as varchar);

  declare ntxt any;
  ntxt := string_output ();

  declare n_cols int;
  n_cols := fct_n_cols(tree);

  dbg_printf ('n_cols: %d', n_cols);

  if (n_cols = 2)
    {
      if (view_type = 'text')
	{
	  http (sprintf ('select xmlelement ("result", xmlattributes (''%s'' as "type"),
                              xmlagg (xmlelement ("row",
                                                  xmlelement ("column",
                                                              xmlattributes (''trank'' as "datatype"),
                                                              "sc"),
                                                  xmlelement ("column",
                                                              xmlattributes (''erank'' as "datatype"),
                                                              "rank"),
--                                                  xmlelement ("column",
--                                                              xmlattributes (''g'' as "datatype"),
--                                                              __ro2sq ("g")),
                                                  xmlelement ("column",
                                                              xmlattributes (fct_lang ("c1") as "xml:lang",
                                                                             fct_dtp ("c1") as "datatype",
                                                                             fct_short_form(__ro2sq("c1")) as "shortform"),
                                                              __ro2sq ("c1")),
                                                  xmlelement ("column",
                                                              fct_label ("c1", 0, ''facets'' )),
                                                  xmlelement ("column",
                                                              fct_bold_tags("c2")))))
             from (sparql define output:valmode "LONG" ', view_type), ntxt);
	}
      else
	{
	  http (sprintf ('select xmlelement ("result", xmlattributes (''%s'' as "type"),
                              xmlagg (xmlelement ("row",
                                                  xmlelement ("column",
                                                              xmlattributes (fct_lang ("c1") as "xml:lang",
                                                                             fct_dtp ("c1") as "datatype",
                                                                             fct_short_form(__ro2sq("c1")) as "shortform"),
                                                              __ro2sq ("c1")),
                                                  xmlelement ("column",
                                                              fct_label ("c1", 0, ''facets'' )),
                                                  xmlelement ("column",
                                                              fct_bold_tags("c2")))))
             from (sparql define output:valmode "LONG" ', view_type), ntxt);

	}
     }
  if (n_cols = 1)
    http ('select xmlelement ("result", xmlattributes ('''' as "type"),
    			xmlagg (xmlelement ("row",
				xmlelement ("column",
						xmlattributes (fct_lang ("c1") as "xml:lang",
							       fct_dtp ("c1") as "datatype",
							       fct_short_form(__ro2sq("c1")) as "shortform"),
							       __ro2sq ("c1")),
				xmlelement ("column", fct_label ("c1", 0, ''facets'' )))))
	     from (sparql define output:valmode "LONG"', ntxt);
  if (n_cols = 3)
    http ('select xmlelement ("result", xmlattributes ('''' as "type"),
                              xmlagg (xmlelement ("row",
                                                  xmlelement ("column",
                                                              xmlattributes (fct_lang ("c1") as "xml:lang",
                                                                             fct_dtp ("c1") as "datatype",
                                                                             fct_short_form(__ro2sq("c1")) as "shortform"),
                                                              __ro2sq ("c1")),
                                                  xmlelement ("column",
                                                              fct_label ("c1", 0, ''facets'' )),
                                                  xmlelement ("column", "c2"),
                                                  xmlelement ("column", "c3")
						  	)))
             from (sparql define output:valmode "LONG" ', ntxt);


  http (txt, ntxt);
  http (') xx option (quietcast)', ntxt);

  return string_output_string (ntxt);
}

create procedure
fct_n_cols (in tree any)
{
  declare tp varchar;
  tp := cast (xpath_eval ('//view/@type', tree, 1) as varchar);
  if ('list' = tp)
    return 1;
  else if ('geo' = tp)
    return 3;
  return 2;
  signal ('FCT00', 'Unknown facet view type');
}
;

create procedure
element_split (in val any)
{
  declare srch_split, el varchar;
  declare k integer;
  declare sall any;


  --srch_split := '';
  --k := 0;
  --sall := split_and_decode(val, 0, '\0\0 ');
  --for(k:=0;k<length(sall);k:=k+1)
  --{
  -- el := sall[k];
  -- if (el is not null and length(el) > 0) srch_split := concat (srch_split, ', ', '''',el,'''');
  --};
  --srch_split := trim(srch_split,',');
  --srch_split := trim(srch_split,' ');
  --return srch_split;

  declare words any;
  srch_split := '';
  val := trim (val, '"');
  FTI_MAKE_SEARCH_STRING_INNER (val,words);
  k := 0;
  for(k:=0;k<length(words);k:=k+1)
  {
    el := words[k];
    if (el is not null and length(el) > 0)
      srch_split := concat (srch_split, ', ', '''',el,'''');
  };
  srch_split := trim (srch_split,',');
  srch_split := trim (srch_split,' ');
  return srch_split;
}
;

create procedure
fct_view (in tree any, in this_s int, in txt any, in pre any, in post any)
{
  declare lim, offs int;
  declare mode varchar;

  offs := xpath_eval ('./@offset', tree, 1);
  lim  := xpath_eval ('./@limit', tree, 1);

  http (sprintf (' %s %s %s ', fct_graph_clause (tree), fct_inf_clause (tree), fct_sas_clause (tree)), pre);

  mode := cast (xpath_eval ('./@type', tree, 1) as varchar);

  if ('list' = mode)
    {
      http (sprintf ('select distinct ?s%d as ?c1 ', this_s), pre);
      http (sprintf (' order by desc (<LONG::IRI_RANK> (?s%d)) ', this_s), post);
    }

  if ('list-count' = mode)
    {
      http (sprintf ('select ?s%d as ?c1 count (*) as ?c2 ', this_s), pre);
      http (sprintf (' group by ?s%d order by desc 2', this_s), post);
    }

  if ('properties' = mode)
    {
      if (length (fct_inf_clause (tree)) > 0)
	http (sprintf ('select ?s%dp as ?c1 count (distinct (?s%d)) as ?c2 ', this_s, this_s), pre);
      else
	http (sprintf ('select ?s%dp as ?c1 count (*) as ?c2 ', this_s), pre);
      http (sprintf (' ?s%d ?s%dp ?s%do .', this_s, this_s, this_s), txt);
      http (sprintf (' group by ?s%dp order by desc 2', this_s), post);
    }

  if ('properties-in' = mode)
    {
      http (sprintf ('select ?s%dip as ?c1 count (*) as ?c2 ', this_s), pre);
      http (sprintf (' ?s%do ?s%dip ?s%d .', this_s, this_s, this_s), txt);
      http (sprintf (' group by ?s%dip order by desc 2', this_s), post);
    }

  if ('text-properties' = mode)
    {
      http (sprintf ('select  ?s%dtextp as ?c1 count (*) as ?c2 ', this_s), pre);
      http (sprintf (' group by ?s%dtextp order by desc 2', this_s), post);
    }

  if ('classes' = mode)
    {
      if (length (fct_inf_clause (tree)) > 0)
	http (sprintf ('select ?s%dc as ?c1 count (distinct (?s%d)) as ?c2 ', this_s, this_s), pre);
      else
	http (sprintf ('select ?s%dc as ?c1 count (*) as ?c2 ', this_s), pre);
      http (sprintf (' ?s%d a ?s%dc .', this_s, this_s), txt);
      http (sprintf (' group by ?s%dc order by desc 2', this_s), post);
    }

  if ('text' = mode)
    {
      declare exp any;

      exp := cast (xpath_eval ('//text', tree) as varchar);

      http (sprintf ('select ?s%d as ?c1, (bif:search_excerpt (bif:vector (%s), ?o%d)) as ?c2, ?sc, ?rank where {{{ select ?s%d, (?sc * 3e-1) as ?sc, ?o%d, (sql:rnk_scale (<LONG::IRI_RANK> (?s%d))) as ?rank ',
            this_s,
   	    element_split (exp),
		     this_s, this_s, this_s, this_s), pre);

      http (sprintf (' order by desc (?sc * 3e-1 + sql:rnk_scale (<LONG::IRI_RANK> (?s%d))) ', this_s), post);
      fct_post (tree, post, lim, offs);
      http ('}}}', post);
      return;
    }

  if ('graphs' = mode)
    {
      http ('select ?g as ?c1, count(*) as ?c2 ', pre);
      http (' order by desc (2) ' , post);
    }

  if ('geo' = mode)
    {
      declare loc any;
      loc := xpath_eval ('@location-prop', tree);
      if (loc = 'any')
	{
	  loc := '?anyloc';
	  http (sprintf ('select distinct ?location as ?c1 ?lat%d as ?c2 ?lng%d as ?c3 ', this_s, this_s, this_s), pre);
	}
      else
        http (sprintf ('select distinct ?s%d as ?c1 ?lat%d as ?c2 ?lng%d as ?c3 ', this_s, this_s, this_s), pre);
      if (length (loc) < 2)
         http (sprintf (' ?s%d geo:lat ?lat%d ; geo:long ?lng%d .', this_s, this_s, this_s), txt);
      else
         http (sprintf (' ?s%d %s ?location . ?location geo:lat ?lat%d ; geo:long ?lng%d .', this_s, loc, this_s, this_s), txt);

    }

--  dbg_printf ('Pre : %s', string_output_string (pre));
--  dbg_printf ('Post: %s', string_output_string(post));

  fct_post (tree, post, lim, offs);

}
;

create procedure
fct_literal (in tree any)
{
  declare lit, dtp, lang varchar;

  dtp := cast (xpath_eval ('./@datatype', tree) as varchar);
  lang := cast (xpath_eval ('./@xml:lang', tree) as varchar);

  if (lang is not null and lang <> '')
    lit := sprintf ('"""%s"""@%s', cast (tree as varchar), lang);
  else if ('uri' = dtp or 'url' = dtp or 'iri' = dtp)
    lit := sprintf ('<%s>', cast (tree as varchar));
  else if (dtp like '%tring')
    lit := sprintf ('"""%s"""', cast (tree as varchar));
  else if (dtp = '' or dtp is null or dtp like '%nteger' or dtp like '%ouble' or dtp like '%loat' or dtp like '%nt')
    lit := cast (tree as varchar);
  else
    lit := sprintf ('"%s"^^<%s>', cast (tree as varchar), dtp);
  return lit;
}
;

-- XXX (ghard) should ensure the literal is correctly quoted in the SPARQL statement

create procedure
fct_cond (in tree any, in this_s int, in txt any)
{
  declare lit, op varchar;

  lit := fct_literal (tree);

  op := coalesce (cast (xpath_eval ('./@op', tree) as varchar), '=');

  if (0 = op)
    op := '=';

  http (sprintf (' filter (?s%d %s %s) . ', this_s, op, lit), txt);
}
;

create procedure
fct_text_1 (in tree any,
	    in this_s int,
	    inout max_s int,
	    in txt any,
	    in pre any,
	    in post any)
{
  declare c any;
  declare i, len int;

  c := xpath_eval ('./node()', tree, 0);

  for (i := 0; i < length (c); i := i + 1)
    {
      fct_text (c[i], this_s, max_s, txt, pre, post);
    }
}
;

create procedure
fct_text (in tree any,
	  in this_s int,
	  inout max_s int,
	  in txt any,
	  in pre any,
	  in post any)
{
  declare n varchar;

  n := cast (xpath_eval ('name ()', tree, 1) as varchar);

  if ('class' = n)
    {
      http (sprintf ('?s%d a <%s> .', this_s, cast (xpath_eval ('./@iri', tree) as varchar)), txt);
      return;
    }

  if ('query' = n)
    {
      max_s := 1;
      fct_text_1 (tree, 1, max_s, txt, pre, post);
      return;
    }

  if (n = 'text')
    {
      declare prop, sc_opt, v varchar;
      v := cast (xpath_eval ('//view/@type', tree) as varchar);
      prop := cast (xpath_eval ('./@property', tree, 1) as varchar);
      if ('text' = v)
        sc_opt := ' option (score ?sc) ';
      else
        sc_opt := '';
      if (prop is not null)
      prop := '<' || prop || '>';
      else
      prop := sprintf ('?s%dtextp', this_s);
      http (sprintf (' ?s%d %s ?o%d . ?o%d bif:contains  ''%s'' %s .', this_s, prop, this_s, this_s,
		     fti_make_search_string (cast (tree as varchar)), sc_opt), txt);
    }

  if ('property' = n)
    {
      declare new_s int;
      max_s := max_s + 1;
      new_s := max_s;
      http (sprintf (' ?s%d <%s> ?s%d .', this_s, cast (xpath_eval ('./@iri', tree, 1) as varchar), new_s), txt);
      fct_text_1 (tree, new_s, max_s, txt, pre, post);
    }

  if ('property-of' = n)
    {
      declare new_s int;
      max_s := max_s + 1;
      new_s := max_s;
      http (sprintf (' ?s%d <%s> ?s%d .', new_s, cast (xpath_eval ('./@iri', tree, 1) as varchar), this_s), txt);
      fct_text_1 (tree, new_s, max_s, txt, pre, post);
    }

  if ('value' = n)
    {
      fct_cond (tree, this_s, txt);
    }

  if (n = 'view')
    {
      fct_view (tree, this_s, txt, pre, post);
    }
}
;

create procedure
fct_query (in tree any)
{
  declare s, add_graph int;
  declare txt, pre, post any;

  txt := string_output ();
  pre := string_output ();
  post := string_output ();

  s := 0;
  add_graph := 0;

  if (xpath_eval ('//view[@type="graphs"]', tree) is not null)
    add_graph := 1;

  fct_text (xpath_eval ('//query', tree), 0, s, txt, pre, post);

  http (' where {', pre);
  if (add_graph) http (' graph ?g { ', pre);
  http (txt, pre);
  http (' }', pre);
  if (add_graph) http (' }', pre);
  http (post, pre);

  return string_output_string (pre);
}
;

create procedure
fct_test (in str varchar, in timeout int := 0)
{
  declare sqls, msg varchar;
  declare start_time int;
  declare reply, tree, md, res, qr, qr2 any;
  declare cplete varchar;

  tree := xtree_doc (str);
  qr := fct_query (xpath_eval ('//query', tree, 1));
  qr2 := fct_xml_wrap (tree, qr);

  set result_timeout = timeout;

  sqls := '00000';
  start_time := msec_time ();

  exec (qr2, sqls, msg, vector (), 0, md, res);

  if (sqls <> '00000' and sqls <> 'S1TAT')
    signal (sqls, msg);


  if (sqls = 'S1TAT') {
    cplete := 'yes';
  }

  reply := xmlelement ("facets", xmlelement ("sparql", qr), xmlelement ("time", msec_time () - start_time),
		       xmlelement ("complete", cplete),
		       xmlelement ("db-activity", db_activity ()), res[0][0]);

--  dbg_obj_print (reply);

  return xslt ('file://facet_text.xsl', reply);
}
;

create procedure _min (in n1 int, in n2 int) {
  if (n1 < n2) return n1;
  else return n2;
}
;

create procedure
fct_exec (in tree any, 
          in timeout int)
{
  declare start_time, view3, inx, n_rows int;
  declare sqls, msg, qr, qr2, act, query varchar;
  declare md, res, results, more any;
  declare tmp any;
  declare offs, lim int;

  set result_timeout = _min (timeout, atoi (registry_get ('fct_timeout_max')));

  offs := xpath_eval ('//query/view/@offset', tree);
  lim := xpath_eval ('//query/view/@limit', tree);

  -- db_activity ();

  results := vector (null, null, null);
  more := vector ();

  if (xpath_eval ('//query[@view3="yes"]//view[@type="text"]', tree) is not null)
    {
      more := vector ('classes', 'properties');
    }

  sqls := '00000';
  qr := fct_query (xpath_eval ('//query', tree, 1));
  query := qr;
--  dbg_obj_print (qr);
  qr2 := fct_xml_wrap (tree, qr);
  start_time := msec_time ();

  dbg_printf('query: %s', qr2);

  exec (qr2, sqls, msg, vector (), 0, md, res);
  n_rows := row_count ();
  act := db_activity ();
  set result_timeout = 0;
  if (sqls <> '00000' and sqls <> 'S1TAT')
    signal (sqls, msg);
  if (not isarray (res) or 0 = length (res) or not isarray (res[0]) or 0 = length (res[0]))
    results[0] := xtree_doc ('<result/>');
  else
    results[0] := res[0][0];

  inx := 1;

  foreach (varchar tp in more) do
    {
      tree := XMLUpdate (tree, '/query/view/@type', tp, '/query/view/@limit', '40', '/query/view/@offset', '0');
      qr := fct_query (xpath_eval ('//query', tree, 1));
      qr2 := fct_xml_wrap (tree, qr);
      sqls := '00000';
      set result_timeout = _min (timeout, atoi (registry_get ('fct_timeout_max')));
      exec (qr2, sqls, msg, vector (), 0, md, res);
      n_rows := row_count ();
      act := db_activity ();
      set result_timeout = 0;
      if (sqls <> '00000' and sqls <> 'S1TAT')
	signal (sqls, msg);
      if (isarray (res) and length (res) and isarray (res[0]) and length (res[0]))
	{
	  tmp := res[0][0];
	  tmp := XMLUpdate (tmp, '/result/@type', tp);
	  results[inx] := tmp;
	}
      inx := inx + 1;
    }



  res := xmlelement ("facets", xmlelement ("sparql", query), 
                               xmlelement ("time", msec_time () - start_time),
		               xmlelement ("complete", case when sqls = 'S1TAT' then 'no' else 'yes' end),
		               xmlelement ("timeout", _min (timeout * 2, atoi (registry_get ('fct_timeout_max')))),
		               xmlelement ("db-activity", act),
		               xmlelement ("processed", n_rows), 
                               xmlelement ("view", xmlattributes (offs as "offset", lim as "limit")),
                               results[0], results[1], results[2]);

  string_to_file ('ret.xml', serialize_to_UTF8_xml (res), -2);

--  dbg_obj_print (res);
  return res;
}
;
