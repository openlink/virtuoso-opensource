--
--  $Id$
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2019 OpenLink Software
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
fct_dbg_msg (in str varchar, in lvl int := 666)
{
  declare d_lvl int;
  declare d_mode varchar;

  d_lvl := connection_get ('fct_dbg_lvl');
  d_mode := connection_get ('fct_dbg_mode');

  if (lvl < d_lvl) return;

  if (d_lvl)
    {
      if (d_mode = 'stderr')
        {
          dbg_printf ('%s', str);
	  return;
        }
      if (d_mode = 'page')
        {
          declare d_out_s any;
          d_out_s := connection_get ('__fct_dbg_out');
          if (d_out_s)
            http (str || '\n', d_out_s);
        }
    }
}
;

create procedure
fct_render_dbg_out ()
{
  declare d_lvl int;
  declare d_out varchar;

  d_lvl := connection_get ('fct_dbg_lvl');
  d_out := connection_get ('fct_dbg_out');

  if (not d_lvl) return;
  if (not d_out) { dbg_printf ('fct_render_dbg_out: no d_out'); return; }

  declare d_ses any;
  d_ses := connection_get ('__fct_dbg_out');

  if (d_ses)
    {
      http('<div id="dbg_output"><pre>');
      http_value (d_ses);
      http('</pre></div>');
    }
  else
    dbg_printf ('fct_render_dbg_out: no string session to write to!');
}
;

create procedure
fct_uri_curie (in uri varchar)
{
  declare delim integer;
  declare uriSearch, nsPrefix varchar;

  delim := -1;

  if (uri is null)
    return uri;

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

  if (pref is null)
    return x;

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

cl_exec ('registry_set (''fct_timeout_min'',''8000'')');
cl_exec ('registry_set (''fct_timeout_max'',''40000'')');

create procedure
FCT_LABEL (in x any, in g_id iri_id_8, in ctx varchar)
{
  declare best_str any;
  declare best_l, l int;
  declare label_iri iri_id_8;
  if (not isiri_id (x))
    return null;
  if (__proc_exists ('rdf_resolve_labels_s') is not null)
    {
      declare ret any;
      ret := rdf_resolve_labels_s (adler32 ('en'), vector (x));
      ret := coalesce (ret[0], '');
      return __ro2sq (ret);
    }
  rdf_check_init ();
  label_iri := iri_id_from_num (atoi (registry_get ('fct_label_iri')));
  best_str := null;
  best_l := 0;
  for select o, p
    from rdf_quad table option (index primary key)
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
  return __ro2sq(best_str);
}
;

create procedure
FCT_LABEL_DP (in x any, in g_id iri_id_8, in ctx varchar)
{
  return FCT_LABEL_DP_L (x, g_id, ctx, null);
}
;

create procedure
FCT_LABEL_DP_L (in x any, in g_id iri_id_8, in ctx varchar, in lng varchar)
{
  declare best_str any;
  declare best_l, l int;
  declare label_iri iri_id_8;
  declare q, best_q, str_lang, lng_pref any;

  if (not isiri_id (x))
    return vector (null, 1);
  rdf_check_init ();
  label_iri := iri_id_from_num (atoi (registry_get ('fct_label_iri')));
  best_str := null;
  best_l := 0;
  best_q := 0;
  for select o, p
        from rdf_quad table option (no cluster, index rdf_quad)
        where s = x and p in (rdf_super_sub_list (ctx, label_iri, 3)) do
    {
      if (is_rdf_box (o))
	{
          lng_pref := rdf_box_lang (o);
	  str_lang := (select RL_ID from RDF_LANGUAGE where RL_TWOBYTE = lng_pref);
	}
      else
        str_lang := 'en';
      q := cmp_get_lang_by_q (lng, str_lang);

      if (is_rdf_box (o) or isstring (o))
	{
	  if (q > best_q)
	    {
	      best_str := o;
	      best_q := q;
	    }
	}

      if (0)
	{
	  if (is_rdf_box (o) and not rdf_box_is_complete (o))
	    l := 20;
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
FCT_LABEL_NP (in x any, in g_id iri_id_8, in ctx varchar, in lng varchar := 'en')
{
  declare best_str any;
  declare best_l, l int;
  declare label_iri iri_id_8;
  declare q, best_q, str_lang, lang_id any;

  if (not isiri_id (x))
    return null;
  if (__proc_exists ('rdf_resolve_labels_s') is not null)
    {
      declare ret any;
      ret := rdf_resolve_labels_s (adler32 (lng), vector (x));
      ret := coalesce (ret[0], '');
      return __ro2sq (ret);
    }
  rdf_check_init ();
  label_iri := iri_id_from_num (atoi (registry_get ('fct_label_iri')));
  best_str := '';
  best_l := 0;
  best_q := 0;
  for select o
        from rdf_quad table option (index rdf_quad)
        where s = x and p in (rdf_super_sub_list (ctx, label_iri, 3)) order by cast (b3s_lbl_order (P) as int) option (same_as) do
    {
      o := __ro2sq (o);
      lang_id := rdf_box_lang (o);
      if (lang_id > 257)
	str_lang := (select RL_ID from RDF_LANGUAGE where RL_TWOBYTE = lang_id);
      else
        str_lang := 'en';
      q := cmp_get_lang_by_q (lng, str_lang);
      if (is_rdf_box (o) or isstring (o))
	{
	  if (q > best_q)
	    {
	      best_str := o;
	      best_q := q;
	    }
	}
    }
  return best_str;
}
;


create procedure
FCT_LABEL_S (in x any, in g_id iri_id_8, in ctx varchar, in lng varchar)
{
  declare best_str any;
  declare best_l, l int;
  declare label_iri iri_id_8;
  declare q, best_q, str_lang, lng_pref any;

  if (not isiri_id (x))
    return null;
  if (__proc_exists ('rdf_resolve_labels_s') is not null)
    {
      declare ret any;
      ret := rdf_resolve_labels_s (adler32 (coalesce (lng, '')), vector (x));
      ret := coalesce (ret[0], '');
      return __ro2sq (ret);
    }
  rdf_check_init ();
  label_iri := iri_id_from_num (atoi (registry_get ('fct_label_iri')));
  best_str := null;
  best_l := 0;
  best_q := 0;
  for select o, p
        from rdf_quad table option (no cluster, index rdf_quad)
        where s = x and p in (rdf_super_sub_list (ctx, label_iri, 3)) do
    {
      if (is_rdf_box (o))
	{
          lng_pref := rdf_box_lang (o);
	  str_lang := (select RL_ID from RDF_LANGUAGE where RL_TWOBYTE = lng_pref);
	}
      else
        str_lang := 'en';
      q := cmp_get_lang_by_q (lng, str_lang);

      if (is_rdf_box (o) or isstring (o))
	{
	  if (q > best_q)
	    {
	      best_str := o;
	      best_q := q;
	    }
	}

      if (0)
	{
	  if (is_rdf_box (o) and not rdf_box_is_complete (o))
	    l := 20;
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
    {
      set isolation = 'committed';
      return (select case (isnull (RO_LONG)) when 0 then blob_to_string (RO_LONG) else RO_VAL end
		   from DB.DBA.RDF_OBJ table option (no cluster) where RO_ID = rdf_box_ro_id (best_str));
    }
  return best_str;
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

create procedure decl_dpipe_define ()
{
  if (sys_stat ('cl_run_local_only'))
    return;
  dpipe_define ('DB.DBA.FCT_LABEL', 'DB.DBA.RDF_QUAD', 'RDF_QUAD_SP', 'DB.DBA.FCT_LABEL_DP', 0);
  dpipe_define ('FCT_LABEL_L', 'DB.DBA.RDF_QUAD', 'RDF_QUAD_SP', 'DB.DBA.FCT_LABEL_DP_L', 0);
  dpipe_define ('FCT_LABEL', 'DB.DBA.RDF_QUAD', 'RDF_QUAD_SP', 'DB.DBA.FCT_LABEL_DP', 0); -- was OPGS
  dpipe_define ('LBL_O_VALUE', 'DB.DBA.RDF_OBJ', 'RDF_OBJ', 'DB.DBA.LBL_O_VALUE', 0);
}
;

decl_dpipe_define ();

TTLP ('@prefix foaf: <http://xmlns.com/foaf/0.1/> .
@prefix dc: <http://purl.org/dc/elements/1.1/> .
@prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .
@prefix virtrdf: <http://www.openlinksw.com/schemas/virtrdf#> .
@prefix fbase: <http://rdf.freebase.com/ns/type.object.> .
@prefix skos: <http://www.w3.org/2008/05/skos#> .
@prefix bibo: <http://purl.org/ontology/bibo/> .
@prefix gr: <http://purl.org/goodrelations/v1#> .
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
<http://s.opencalais.com/1/type/er/Company> rdfs:subClassOf gr:BusinessEntity .
gr:BusinessEntity rdfs:subClassOf foaf:Organization .
<http://dbpedia.org/ontology/Company> rdfs:subClassOf gr:BusinessEntity .
<http://www.w3.org/2002/12/cal/ical#summary> rdfs:subPropertyOf rdfs:label .
<http://usefulinc.com/ns/doap#name> rdfs:subPropertyOf rdfs:label .
<http://linkedopencommerce.com/schemas/icecat/v1/hasModelName> rdfs:subPropertyOf virtrdf:label .
<http://aims.fao.org/aos/geopolitical.owl#nameListEN> rdfs:subPropertyOf rdfs:label .
<http://aims.fao.org/aos/geopolitical.owl#hasMinLatitude> rdfs:subPropertyOf geo:lat .
<http://aims.fao.org/aos/geopolitical.owl#hasMinLongitude> rdfs:subPropertyOf geo:long .
og:latitude rdfs:subPropertyOf geo:lat .
og:longitude rdfs:subPropertyOf geo:long .
<http://uberblic.org/ontology/latitude> rdfs:subPropertyOf geo:lat .
<http://uberblic.org/ontology/longitude> rdfs:subPropertyOf geo:long .
<http://linkedopencommerce.com/schemas/icecat/v1/hasCategory> rdfs:subPropertyOf rdf:type .
<http://poolparty.punkt.at/demozone/ont#title> rdfs:subPropertyOf virtrdf:label .
<http://purl.uniprot.org/core/scientificName> rdfs:subPropertyOf virtrdf:label .
<http://www.openlinksw.com/schemas/googleplus#activity_title> rdfs:subPropertyOf virtrdf:label .
<http://linkedopencommerce.com/schemas/icecat/v1/hasShortSummaryDescription> rdfs:subPropertyOf virtrdf:label .
<http://yago-knowledge.org/resource/hasPreferredName> rdfs:subPropertyOf virtrdf:label .
', 'xx', 'facets');

rdfs_rule_set ('facets', 'facets');
rdfs_rule_set ('facets', 'virtrdf-label');


create procedure
fct_inf_val (in tree any)
{
  declare i varchar;

  i := cast (xpath_eval ('/query/@inference', tree) as varchar);

  if (i is null or '' = i)
    return null;
  return i;
}
;

create procedure
fct_inf_clause (in tree any)
{
  declare i varchar;

  i := fct_inf_val (tree);

  if (i is not null)
    return sprintf (' define input:inference "%s" ', i);
  return '';
}
;

create procedure
fct_sas_val (in tree any)
{
  declare i varchar;

  i := cast (xpath_eval ('/query/@same-as', tree) as varchar);

  if (i is null or '' = i)
    return null;
  return i;
}
;

create procedure
fct_sas_clause (in tree any)
{
  declare i varchar;

  i := fct_sas_val (tree);

  if (i is not null)
    return sprintf (' define input:same-as "%s" ', i);
  return '';
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
fct_named_graph_clause (in tree any)
{
  declare xt, xp, inx, s any;
  inx := 1;
  s := string_output ();
  while ((xp := xpath_eval (sprintf ('//query/@graph%d', inx), tree)) is not null)
    {
      inx := inx + 1;
      http (sprintf (' define input:default-graph-uri <%s> ', cast (xp as varchar)), s);
    }
  return string_output_string (s);
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
  if (isiri_id (x) or __box_flags (x) = 1)
    return 'uri';

  declare dtp any;

  dtp := rdf_datatype_of_long (x, UNAME'http://www.openlinksw.com/schemas/facets/dtp/plainstring');
  return (id_to_iri (dtp));
}
;

--
-- Handle any DTs which need special serialization in FILTER, etc.
--

create procedure
fct_sparql_ser (in x any)
{
  if (__TAG (x) = __TAG (getdate()))
    return date_iso8601(__ro2sq (x));

  return '';
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
fct_get_mode (in tree any, in xp any)
{
  declare view_type varchar;
  view_type := cast (xpath_eval (xp, tree, 1) as varchar);

  if (0 and sys_stat ('cl_run_local_only') and view_type = 'text-d')
    view_type := 'text';

  return view_type;
}
;

create procedure
fct_xml_wrap (in tree any, in txt any)
{
  declare view_type varchar;
  view_type := fct_get_mode (tree, '//view/@type');

  declare ntxt any; -- , texp any;
  ntxt := string_output ();

  declare n_cols int;
  n_cols := fct_n_cols(tree);

  fct_dbg_msg (sprintf ('fct_xml_wrap: view_type: %s', view_type));
  fct_dbg_msg (sprintf ('              n_cols   : %d', n_cols));

  if (n_cols = 2)
    {
      if (view_type = 'text')
	{
	  http (sprintf ('select xmlelement ("result", xmlattributes (''%s'' as "type"),
                              xmlagg (xmlelement ("row",
                                                  xmlelement ("column",
                                                              xmlattributes (''trank'' as "trank"),
                                                              "sc"),
                                                  xmlelement ("column",
                                                              xmlattributes (''erank'' as "erank"),
                                                              "rank"),
                                                  xmlelement ("column",
                                                              xmlattributes (''g'' as "graph"),
                                                              __ro2sq ("g")),
                                                  xmlelement ("column",
                                                              xmlattributes (fct_lang ("c1") as "xml:lang",
                                                                             fct_dtp ("c1") as "datatype",
                                                                             fct_short_form(__ro2sq("c1")) as "shortform"),
                                                              __ro2sq ("c1")),
                                                  xmlelement ("column",
                                                              fct_label_np ("c1", 0, ''facets'' )),
                                                  xmlelement ("column",
                                                              fct_bold_tags("c2")))))
             from (sparql define output:valmode "LONG" ', view_type), ntxt);
	}
      else if (view_type = 'text-d')
	{
--	  texp := cast (xpath_eval ('string (//query/text)', tree, 1) as varchar);
	  http ('select  xmlelement (\'result\',
	  			     xmlattributes (\'text-d\' as "type"),
				     "res")
				     from (sparql ', ntxt);
	}
      else if (view_type = 'entities-list' or view_type = 'list' or view_type = 'propval-list')
        {
	  http (sprintf ('select xmlelement ("result", xmlattributes (''%s'' as "type"),
                          xmlagg (xmlelement ("row",
                                              xmlelement ("column",
                                                          xmlattributes (fct_lang ("c1") as "xml:lang",
                                                                         fct_dtp ("c1") as "datatype",
                                                                         fct_short_form(__ro2sq("c1")) as "shortform"),
                                                          __ro2sq ("c1")),
                                              xmlelement ("column",
                                                          fct_label_np ("c1", 0, ''facets'' )))))
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
                                                              fct_label_np ("c1", 0, ''facets'' )),
                                                  xmlelement ("column",
                                                              fct_bold_tags("c2")))))
             from (sparql define output:valmode "LONG" ', view_type), ntxt);

	}
     }
  if (n_cols = 1)
    http (sprintf ('select xmlelement ("result", xmlattributes (''%s'' as "type"),
    			xmlagg (xmlelement ("row",
				xmlelement ("column",
						xmlattributes (fct_lang ("c1") as "xml:lang",
							       fct_dtp ("c1") as "datatype",
							       fct_short_form(__ro2sq("c1")) as "shortform",
                                                               fct_sparql_ser ("c1") as "sparql_ser"),
							       __ro2sq ("c1")),
				xmlelement ("column", fct_label_np ("c1", 0, ''facets'' )))))
	     from (sparql define output:valmode "LONG" ', view_type), ntxt);
  if (n_cols = 3)
    http (sprintf ('select xmlelement ("result", xmlattributes (''%s'' as "type"),
                              xmlagg (xmlelement ("row",
                                                  xmlelement ("column",
                                                              xmlattributes (fct_lang ("c1") as "xml:lang",
                                                                             fct_dtp ("c1") as "datatype",
                                                                             fct_short_form(__ro2sq("c1")) as "shortform"),
                                                              __ro2sq ("c1")),
                                                  xmlelement ("column",
                                                              fct_label_np ("c1", 0, ''facets'' )),
                                                  xmlelement ("column", __ro2sq ("c2")),
                                                  xmlelement ("column", __ro2sq ("c3"))
						  	)))
             from (sparql define output:valmode "LONG" ', view_type), ntxt);


  http (txt, ntxt);
  http (') xx option (quietcast)', ntxt);

  return string_output_string (ntxt);
}
;

create procedure
fct_n_cols (in tree any)
{
  declare tp varchar;
  tp := cast (xpath_eval ('//view/@type', tree, 1) as varchar);
--  fct_dbg_msg (sprintf ('fct_n_cols: tp: %s', tp));
  if ('list' = tp)
    return 1;
  else if ('geo' = tp or 'geo-list' = tp)
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
fct_view (in tree any, in this_s int, in txt any, in pre any, in post any, in full_tree any, in plain integer := 0)
{
  declare lim, offs int;
  declare mode varchar;

  offs := xpath_eval ('./@offset', tree, 1);
  lim  := xpath_eval ('./@limit', tree, 1);

  http (sprintf (' %s %s %s %s ', fct_graph_clause (tree), fct_named_graph_clause (tree), fct_inf_clause (tree), fct_sas_clause (tree)), pre);

  mode := fct_get_mode (tree, './@type');

-- geo-based conditionals force geo-list generation unless the old map mode is used

-- dbg_obj_print(full_tree);

  declare geo_conds any;
  geo_conds := xpath_eval ('//cond/@cond_t = ''near''', full_tree);

  if (0 <> geo_conds and mode <> 'geo')
    mode := 'geo-list';

  fct_dbg_msg (sprintf('fct_view: view mode: %s', mode));

  if ('list' = mode or 'propval-list' = mode)
    {
      http (sprintf ('select ?s%d as ?c1 ', this_s), pre);
      http (sprintf (' group by (?s%d) order by desc (<LONG::IRI_RANK> (?s%d)) ', this_s, this_s), post);
    }

  if ('list-count' = mode)
    {
      declare i int;
      http (sprintf ('select ?s%d as ?c1 count (*) as ?c2 where { select distinct ', this_s), pre);
      for (i := 1; i <= this_s; i := i + 1)
        http (sprintf ('?s%d ', i), pre);
      if (xpath_eval ('ancestor::query/text', tree)) http ('?g ', pre);
      http (sprintf (' } group by ?s%d order by desc 2', this_s), post);
    }

  if ('entities-list' = mode)
    {
      http (sprintf ('select ?s%d as ?c1 ', this_s), pre);
      http (sprintf (' group by (?s%d) order by desc (<LONG::IRI_RANK> (?s%d)) ', this_s, this_s), post);
    }

  if ('properties' = mode)
    {
      if (length (fct_inf_clause (tree)) > 0)
	http (sprintf ('select ?s%dp as ?c1 count (distinct (?s%d)) as ?c2 ', this_s, this_s), pre);
      else
  http (sprintf ('select ?s%dp as ?c1 count (distinct ?s%do) as ?c2 ', this_s, this_s), pre);

      http (sprintf (' ?s%d ?s%dp ?s%do .', this_s, this_s, this_s), txt);
      http (sprintf (' group by ?s%dp order by desc 2', this_s), post);
    }

  if ('properties-in' = mode)
    {
      http (sprintf ('select ?s%dip as ?c1 count (distinct ?s%d) as ?c2 ', this_s, this_s), pre);
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
  http (sprintf ('select ?s%dc as ?c1 count (distinct ?s%d) as ?c2 ', this_s, this_s), pre);
      http (sprintf (' ?s%d a ?s%dc .', this_s, this_s), txt);
      http (sprintf (' group by ?s%dc order by desc 2', this_s), post);
    }

  if ('text' = mode or ('text-d' = mode and plain = 1))
    {
      declare exp any;

      exp := cast (xpath_eval ('//text', tree) as varchar);

      http (sprintf ('select ?s%d as ?c1, (bif:search_excerpt (bif:vector (%s), ?o%d)) as ?c2, ?sc, ?rank, ?g where {{{ select ?s%d, (?sc * 3e-1) as ?sc, ?o%d, (sql:rnk_scale (<LONG::IRI_RANK> (?s%d))) as ?rank, ?g',
            this_s,
   	    element_split (exp),
		     this_s, this_s, this_s, this_s), pre);

      http (sprintf (' order by desc (?sc * 3e-1 + sql:rnk_scale (<LONG::IRI_RANK> (?s%d))) ', this_s), post);
      fct_post (tree, post, lim, offs);
      http ('}}}', post);
      return;
    }
  if ('text-d' = mode)
    {
      declare exp any;

      exp := charset_recode (xpath_eval ('string (//text)', tree), '_WIDE_', 'UTF-8');

--      dbg_obj_print (exp);
--      dbg_obj_print (element_split(exp));

      http (sprintf ('select
		  	(<sql:s_sum_page> (<sql:vector_agg> (<bif:vector> (?c1, ?sm, ?g1)), <bif:vector> (%s))) as ?res where { { 
      select (<SHORT_OR_LONG::>(?s%d)) as ?c1,  (<sql:S_SUM> ( <SHORT_OR_LONG::IRI_RANK> (?s%d), <SHORT_OR_LONG::>(?s%dtextp), <SHORT_OR_LONG::>(?o%d), ?sc ) ) as ?sm, <SHORT_OR_LONG::>(?g) as ?g1', element_split (exp), this_s, this_s, this_s, this_s), pre);

      http (sprintf ('order by desc (<sql:sum_rank> ((<sql:S_SUM> ( <SHORT_OR_LONG::IRI_RANK> (?s%d), <SHORT_OR_LONG::>(?s%dtextp), <SHORT_OR_LONG::>(?o%d), ?sc ) ) ) )', this_s, this_s, this_s), post);
      fct_post (tree, post, lim, offs);
      http ('}}', post);
      return;
    }
  if ('graphs' = mode)
    {
      http ('select ?g as ?c1, count(*) as ?c2 ', pre);
      http (' order by desc (2) ' , post);
    }
  if ('geo' = mode or 'geo-list' = mode)
    {
      declare loc any;
      loc := xpath_eval ('@location-prop', tree);

      if (loc = 'any')
	loc := '?anyloc';
      if (length (loc) > 1)	
	{
	  http (sprintf ('select distinct ?location as ?c1 ?lat%d as ?c2 ?lng%d as ?c3 ', 
                         this_s, this_s, this_s), pre);
	}
      else
        http (sprintf ('select distinct ?s%d as ?c1 ?lat%d as ?c2 ?lng%d as ?c3 ', 
                       this_s, this_s, this_s), pre);

      if (length (loc) < 2)
         http (sprintf (' ?s%d geo:lat ?lat%d ; geo:long ?lng%d .', 
                        this_s, this_s, this_s), txt);
      else
         http (sprintf (' ?s%d %s ?location . ?location geo:lat ?lat%d ; geo:long ?lng%d .', 
                        this_s, loc, this_s, this_s), txt);
    }

  fct_post (tree, post, lim, offs);
}
;

create procedure fct_esc_lit (in val any)
{
  --no_c_escapes+
  return replace (val, '"', '\"');
}
;

create procedure
fct_literal (in tree any)
{
  declare val, dtp, lang varchar;

  dtp := cast (xpath_eval ('./@datatype', tree) as varchar);
  lang := cast (xpath_eval ('./@lang', tree) as varchar);

  val := cast (xpath_eval ('./@val', tree) as varchar);
  if (0 = val or val is null) val := cast (tree as varchar);

  fct_dbg_msg (sprintf('fct_literal: val:%s, dtp:%s, lang:%s', val, dtp, lang));

  if (lang is not null and lang <> '')
    return sprintf ('"""%s"""@%s', fct_esc_lit (val), lang);

  if (dtp = 'http://www.openlinksw.com/schemas/facets/dtp/plainstring')
    return sprintf ('"""%s"""', fct_esc_lit (val));

  if (val like '"%"^^<uri>')
    {
      declare arr any;
      arr := sprintf_inverse (val, '"%s"^^<uri>', 0);
      if (length (arr) > 0)
	return sprintf ('<%s>', arr[0]);
    }

  if (dtp = '' or dtp is null or dtp like '%nteger' or dtp like '%ouble' or dtp like '%loat' or dtp like '%nt')
    return val;

  if ('uri' = dtp or 'url' = dtp or 'iri' = dtp) {
      return sprintf ('<%s>', val);
  }

  return sprintf ('"%s"^^<%s>', val, dtp);
}
;

create procedure
fct_cond (in tree any, in this_s int, in txt any)
{
  declare val, dtp, lang, neg, cond_t any;

  val := fct_literal (tree);
  cond_t := xpath_eval ('./@type', tree);

  fct_dbg_msg (sprintf ('fct_cond: type: %s', cond_t));

  if ('range' = cond_t or 'neg_range' = cond_t) {
    return fct_cond_range (tree, this_s, txt); -- ranges are handled elsewhere
  }

  if ('in' = cond_t or 'not_in' = cond_t) {
    return fct_cond_in (tree, this_s, txt); -- so is IN
  }

  if ('near' = cond_t) {
    return fct_cond_near (tree, this_s, txt); -- and NEAR
  }

  if ('contains' = cond_t) {
    return fct_cond_contains (tree, this_s, txt);
  }

  declare t_s varchar;
  t_s := sprintf ('?s%d', this_s);

  declare flt_inner varchar;
  flt_inner := sprintf (fct_cond_fmt(cond_t), t_s, val);

--  dbg_printf ('fct_cond: inner: %s', flt_inner);

  if (neg = 'on')
    http (sprintf (' filter (! (%s)) . ', flt_inner), txt);
  else
    http (sprintf (' filter (%s) . ', flt_inner), txt);

  return;
}
;

create procedure
fct_value (in tree any, in this_s int, in txt any)
{
  declare val, dtp, op any;

  val := fct_literal (tree);
  op := xpath_eval ('./@op', tree);

  if (0 = op or op is null)
    op := '=';

  declare t_s varchar;
  t_s := sprintf ('?s%d', this_s);

  http (sprintf (' filter (%s %s %s) .', t_s, op, val), txt);

  return;
}
;

-- side effect warning: unrecognized conds become eq

create procedure
fct_cond_fmt (in cond_t varchar)
{
  if (cond_t = 'eq')  return '%s = %s';
  if (cond_t = 'neq') return '%s != %s';
  if (cond_t = 'lt')  return '%s < %s';
  if (cond_t = 'gt')  return '%s > %s';
  if (cond_t = 'gte') return '%s >= %s';
  if (cond_t = 'lte') return '%s <= %s';
  return '%s = %s';
}
;

create procedure
fct_cond_range (in tree any, in this_s int, in txt any)
{
  declare cond_t, neg, lo, hi any;

  cond_t := xpath_eval ('./@type', tree);
  neg    := xpath_eval ('./@neg',    tree);
  lo     := xpath_eval ('./@lo',     tree);
  hi     := xpath_eval ('./@hi',     tree);

  declare flt_inner, flt_cl varchar;

--  fct_dbg_msg (sprintf ('fct_cond_range: got lo: %s, hi: %s, neg: %s', lo, hi, cast (neg as varchar)));

  if (lo <> '' and hi <> '') {
    flt_inner := sprintf ('(?s%d >= %s && ?s%d <= %s)', this_s, lo, this_s, hi);
  }

  if (neg = 'on')
    flt_cl := sprintf (' filter (! %s) .', flt_inner);
  else
    flt_cl := sprintf (' filter %s .', flt_inner);

  http (flt_cl, txt);

  return;
}
;

create procedure
fct_cond_contains (in tree any, in this_s int, in txt any)
{
  declare val, neg, cond_t, txs_qr varchar;
  declare wlimit int;
  declare txs_arr any;

  neg := xpath_eval ('./@neg', tree);

  val := cast (xpath_eval ('.', tree) as varchar);

  if (val <> '')
    {
      wlimit := registry_get ('fct_text_query_limit');

      if (isstring (wlimit))
        wlimit := atoi (wlimit);
      if (0 = wlimit)
        wlimit := 100;

      txs_qr := fti_make_search_string_inner (charset_recode (xpath_eval ('string (.)', tree), '_WIDE_', 'UTF-8'), txs_arr);

      if (length (txs_arr) > wlimit)
	signal ('22023', 'The request is too large');

      if ('no' <> neg)
        {
          http (sprintf (' ?s%d bif:contains ''%s'' .', this_s, txs_qr), txt);
        }
      else
        {
          http (sprintf (' filter (! bif:contains (?s%d, ''"%s"'')) .', this_s, val), txt);
        }
    }
}
;

create procedure
fct_cond_in (in tree any, in this_s int, in txt any) {

  declare v any;
  declare v_str varchar;
  declare i int;
  declare neg any;

  neg := xpath_eval ('./@neg', tree);

  v := xpath_eval ('./cond-parm', tree, 0);

  if (0 = length(v)) return;

  for (i := 0; i < length(v); i := i + 1) {
    fct_dbg_msg (sprintf ('val: %s\n', cast (xpath_eval ('./text()', v[i]) as varchar)));

    if (i = 0) {
     v_str := fct_literal (v[i]);
    }
    else
      v_str := v_str || ',' || fct_literal (v[i]);
  };

  fct_dbg_msg (sprintf ('fct_cond_in: v_str: %s', v_str));

  http (sprintf (' filter (%s?s%d in (%s)).', 
	case when neg = '1' then '! ' else '' end,
	this_s, 
	v_str), txt);
}
;

create procedure
fct_cond_near (in tree any, in this_s int, in txt any) {

  declare v any;
  declare v_str varchar;
  declare i int;
  declare lon, lat float;
  declare d int;
  declare prop varchar;

  fct_dbg_msg (sprintf ('fct_cond_near.', lon, lat, d));

  lon  := xpath_eval ('./@lon', tree, 0);
  lat  := xpath_eval ('./@lat', tree, 0);
  d    := xpath_eval ('./@d',   tree, 0);
  prop := xpath_eval ('./@location-prop', tree, 0);

  if (length(lon) = 0 or length(lat) = 0 or length (d) = 0) return;

  lon  := aref (lon, 0);
  lat  := aref (lat, 0);
  d    := cast (aref (d, 0) as int);
  prop := aref (prop, 0);

  if (lon = '' or lat = '') return;

  fct_dbg_msg (sprintf ('fct_cond_near: lon:%s, lat:%s, dist: %d', lon, lat, d));

  if (length (prop) < 2)
    http (sprintf (' ?s%d geo:lat ?lat%d ; geo:long ?lng%d .', this_s, this_s, this_s), txt);
  else
    http (sprintf (' ?s%d %s ?location . ?location geo:lat ?lat%d ; geo:long ?lng%d .', this_s, prop, this_s, this_s), txt);

  http (sprintf (' filter (bif:st_intersects (bif:st_point (xsd:float(?lng%d),xsd:float(?lat%d)), bif:st_point (%s,%s), %d)).',
                 this_s, this_s, lon, lat, d), txt);
}
;

create procedure
fct_curie_iri (in curie varchar)
{
  declare pos int;
  declare pref, ns, loc varchar;

  pos := strchr (curie, ':');
  if (pos is null)
    return null;
  pref := subseq (curie, 0, pos);
  loc := subseq (curie, pos + 1);
  ns := __xml_get_ns_uri (pref, 2);
  if (ns is null)
    return null;
  return ns || loc;
}
;

create procedure
fct_curie (in curie varchar)
{
  if (curie like '\\[%:%\\]')
    {
      declare tmp varchar;
      tmp := trim (curie, '[]');
      tmp := fct_curie_iri (tmp);
      if (tmp is not null)
	curie := tmp;
    }
  return curie;
}
;

create procedure
fct_text_1 (in tree any,
	    in this_s int,
	    inout max_s int,
	    in txt any,
	    in pre any,
	    in post any,
            in full_tree any,
            in plain integer := 0)
{
  declare c any;
  declare i, len int;

  c := xpath_eval ('./node()', tree, 0);

  for (i := 0; i < length (c); i := i + 1)
    {
      fct_text (c[i], this_s, max_s, txt, pre, post, full_tree, plain);
    }
}
;

create procedure
fct_text (in tree any,
	  in this_s int,
	  inout max_s int,
	  in txt any,
	  in pre any,
	  in post any,
          in full_tree any,
	  in plain integer := 0)
{
  declare n varchar;

  n := cast (xpath_eval ('name ()', tree, 1) as varchar);

--  fct_dbg_msg (sprintf('fct_text pre: %s, post: %s', string_output_string(pre), string_output_string(post)));
--  fct_dbg_msg (sprintf('           n: %s', n));
--  dbg_obj_print (tree);

  if ('class' = n)
    {
      declare ciri varchar;
      ciri := fct_curie (cast (xpath_eval ('./@iri', tree) as varchar));
      ciri := replace (ciri, ' ', '%20');

      fct_dbg_msg (sprintf ('class: %s', cast (ciri as varchar)));

      if (cast (xpath_eval ('./@exclude', tree) as varchar) = 'yes')
	{
	  http (sprintf (' filter not exists { ?s%d a <%s> } .', this_s, ciri), txt);
	}
      else if (ciri is null)
        {
	  http (sprintf ('?s%d a ?s%d .', this_s, this_s + 1), txt);
        }
      else
	{
	  http (sprintf ('?s%d a <%s> .', this_s, ciri), txt);
	}
      return;
    }

  if ('query' = n)
    {
      max_s := 1;
      fct_text_1 (tree, 1, max_s, txt, pre, post, full_tree, plain);
      return;
    }

  if (n = 'text')
    {
      declare prop, sc_opt, v, txs_qr varchar;
      declare txs_arr any;
      declare wlimit int;

      v := cast (xpath_eval ('//view/@type', tree) as varchar);
      prop := cast (xpath_eval ('./@property', tree, 1) as varchar);

--      fct_dbg_msg (printf ('prop: %s', coalesce(prop, 'NULL')));

      if ('text' = v or 'text-d' = v)
        sc_opt := ' option (score ?sc) ';
      else
        sc_opt := '';

      if (prop is not null)
	prop := '<' || prop || '>';
      else
	prop := sprintf ('?s%dtextp', this_s);

      wlimit := registry_get ('fct_text_query_limit');
      if (isstring (wlimit))
        wlimit := atoi (wlimit);
      if (0 = wlimit)
        wlimit := 100;
      txs_qr := fti_make_search_string_inner (charset_recode (xpath_eval ('string (.)', tree), '_WIDE_', 'UTF-8'), txs_arr);
      if (length (txs_arr) > wlimit)
	signal ('22023', 'The request is too large');
      http (' quad map virtrdf:DefaultQuadMap { graph ?g { ', txt);
      http (sprintf (' ?s%d %s ?o%d . ?o%d bif:contains  ''%s'' %s .', this_s, prop, this_s, this_s, txs_qr, sc_opt), txt);
      http (' } } ', txt);
    }

  if ('property' = n)
    {
      declare new_s int;
      declare piri varchar;
      declare flt_expr varchar;

      max_s := max_s + 1;
      new_s := max_s;

      piri := fct_curie (cast (xpath_eval ('./@iri', tree, 1) as varchar));
      piri := replace (piri, ' ', '%20');

--      fct_dbg_msg (sprintf ('property: <%s>', piri));

      if (cast (xpath_eval ('./@exclude', tree) as varchar) = 'yes')
	{
	  http (sprintf (' filter not exists { ?s%d <%s> ?v%d } .', this_s, piri, new_s), txt);
	  max_s := max_s - 1;
	  new_s := max_s;
	  fct_text_1 (tree, new_s, max_s, txt, pre, post, full_tree, plain);
	  return;
	}
      else
	{
	  http (sprintf (' ?s%d <%s> ?s%d .', this_s, piri, new_s), txt);
	  fct_text_1 (tree, new_s, max_s, txt, pre, post, full_tree, plain);
	}
    }

  if ('property-of' = n)
    {
      declare new_s int;
      declare piri any;
      max_s := max_s + 1;
      new_s := max_s;
      piri := fct_curie (cast (xpath_eval ('./@iri', tree, 1) as varchar));
      piri := replace (piri, ' ', '%20');
      http (sprintf (' ?s%d <%s> ?s%d .', new_s, piri, this_s), txt);
      fct_text_1 (tree, new_s, max_s, txt, pre, post, full_tree, plain);
    }

  if ('value' = n)
    {
      fct_value (tree, this_s, txt);
    }

  if ('cond' = n)
    {
      fct_chk_any_prop (tree, this_s, max_s, txt);
      fct_cond (tree, this_s, txt);
    }

  if ('cond-range' = n)
    {
      fct_chk_any_prop (tree, this_s, max_s, txt);
      fct_cond_range (tree, this_s, txt);
    }

  if ('view' = n)
    {
      fct_view (tree, this_s, txt, pre, post, full_tree, plain);
    }
}
;

create procedure
fct_chk_any_prop (in tree any, inout this_s int, inout max_s int, in txt any)
{
  if (0 = xpath_eval ('count (./ancestor::*[name()=''property''])+ count(./ancestor::*[name()=''property-of'']) + count(./preceding::*[name()=''class'']) ', tree, 1))
    {
      declare dtp varchar;
      dtp := xpath_eval ('./@dtp', tree, 1);

      declare new_s int;
      max_s := max_s + 1;
      new_s := max_s;

      http (sprintf ('?s%d ?s%dcondp ?s%d .', this_s, this_s, new_s), txt);
      this_s := max_s;
    }
}
;

create procedure
fct_query (in tree any, in plain integer := 0)
{
  declare s, add_graph int;
	  declare txt, pre, post any;

  txt := string_output ();
  pre := string_output ();
  post := string_output ();

  s := 0;
  add_graph := 0;

  if (xpath_eval ('//view[@type="graphs"]', tree) is not null or 
      xpath_eval ('//view[@type="text"]', tree) is not null or 
      xpath_eval ('//view[@type="text-d"]', tree) is not null)
    add_graph := 1;

  fct_text (xpath_eval ('//query', tree), 0, s, txt, pre, post, tree, plain);

  if (xpath_eval ('//view[@type="list-count"]', tree) is null)
    http (' where ', pre);
  http (' {', pre);
  http (txt, pre);
  http (' }', pre);
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

  return xslt (registry_get ('_fct_xslt_') || 'facet_text.xsl', reply);
}
;

create procedure
fct_view_pos (in tree any)
{
  declare c any;
  declare i int;
  c := xpath_eval ('//*[name() = "query" or
	           name () = "property" or
	           name () = "property-of"]', tree, 0);
  for (i := 0; i < length (c); i := i + 1)
    {
      if (xpath_eval ('./view', c[i]) is not null)
	return i;
    }
  return 0;
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

  set result_timeout = __min (timeout, atoi (registry_get ('fct_timeout_max')));

  offs := xpath_eval ('//view/@offset', tree);
  lim := xpath_eval ('//view/@limit', tree);

  results := vector (null, null, null);
  more := vector ();

  if (xpath_eval ('//query[@view3="yes"]//view[@type="text"]', tree) is not null)
    {
      more := vector ('classes', 'properties');
    }

  sqls := '00000';

  qr := fct_query (xpath_eval ('//query', tree, 1));

  query := qr;

  qr2 := fct_xml_wrap (tree, qr);

  start_time := msec_time ();

  connection_set ('sparql_query', qr2);

--  dbg_obj_print (qr2);

  set isolation = 'uncommitted';
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
      set result_timeout = __min (timeout, atoi (registry_get ('fct_timeout_max')));
--      dbg_printf ('qr2: %s', qr2);
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

  declare v_pos integer;
  v_pos := fct_view_pos(tree);
  if (sqls <> 'S1TAT' and n_rows = 0)
    connection_set ('noresult', 1);

  res := xmlelement ("facets", xmlelement ("sparql", query),
                               xmlelement ("time", msec_time () - start_time),
		               xmlelement ("complete", case when sqls = 'S1TAT' then 'no' else 'yes' end),
		               xmlelement ("timeout", __min (timeout * 2, atoi (registry_get ('fct_timeout_max')))),
		               xmlelement ("db-activity", act),
		               xmlelement ("processed", n_rows),
                               xmlelement ("view", xmlattributes (offs as "offset", lim as "limit", v_pos as "position")),
                               results[0], results[1], results[2]);

  --String_to_file ('ret.xml', serialize_to_UTF8_xml (res), -2);

--  dbg_obj_print (results[0]);

  return res;
}
;
