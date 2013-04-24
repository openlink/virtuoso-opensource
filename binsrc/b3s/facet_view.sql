--
--  $Id$
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2013 OpenLink Software
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

--set ignore_params=on;
-- Facets web page

registry_set ('_fct_xslt_',
              case when registry_get('_fct_url_') = 0 then 'file://fct/' else registry_get('_fct_url_') end);


create procedure
fct_view_info (in tree any, in ctx int, in txt any)
{
  declare pos, lim, offs int;
  declare mode varchar;

  pos := 1 + fct_view_pos (tree);
  tree := xpath_eval ('//view', tree);

  mode := cast (xpath_eval ('./@type', tree, 1) as varchar);

  lim := atoi (cast (xpath_eval ('./@limit', tree, 1) as varchar));
  offs := atoi (cast (xpath_eval ('./@offset', tree, 1) as varchar));

  http ('<h3 id="view_info">', txt);
  if ('list' = mode)
    {
      http (sprintf ('List of %s%d', connection_get ('s_term'), pos), txt);
    }
  if ('list-count' = mode)
    {
      http ('Displaying List of Distinct Entity Names ordered by Count', txt);
    }
  if ('entities-list' = mode)
    {
      http ('Displaying matching entities', txt);
    }
  if ('geo' = mode)
    {
      http ('Displaying Places associated with Entities', txt);
    }
  if ('geo-list' = mode)
    {
      http ('Displaying Entities with Geographical location');
    }
  if ('properties' = mode)
    {
      http ('Displaying Attributes of Entities', txt);
    }
  if ('properties-in' = mode)
    {
      http ('Displaying Attributes with Entity Reference Values', txt);
    }
  if ('text-properties' = mode)
    {
      http (sprintf ('showing properties of %s%d containing "%s"',
		     connection_get ('s_term'),
		     pos,
	    	     cast (xpath_eval ('//text', tree) as varchar)),
            txt);
    }
  if ('classes' = mode)
    {
      http ('Displaying Entity Types', txt);
    }
  if ('text' = mode or 'text-d' = mode)
    {
      http ('Displaying Ranked Entity Names and Text summaries', txt);
    }
  if ('propval-list' = mode)
    {
      http ('Displaying property values', txt);
    }
--  if (offs)
--    http (sprintf ('  values %d - %d', 1 + offs, lim), txt);


  http (' where:</h3>', txt);
}
;

create procedure fct_s_term ()
{
  declare s_term varchar;
  s_term := connection_get ('s_term');
  if (s_term = 's') return 'Subject';
  return 'Entity';
}
;

create procedure fct_p_term ()
{
  declare s_term varchar;
  s_term := connection_get ('s_term');
  if (s_term = 's') return 'Property';
  return 'Attribute';
}
;

create procedure fct_o_term ()
{
  declare s_term varchar;
  s_term := connection_get ('s_term');
  if (s_term = 's') return 'Object';
  return 'Value';
}
;

create procedure fct_t_term ()
{
  declare s_term varchar;
  s_term := connection_get ('s_term');
  if (s_term = 's') return 'Class';
  return 'Type';
}
;

create procedure
fct_var_tag (in this_s int, in ctx int)
{
  declare cl varchar;

  if (this_s <> ctx)
    cl := '';
  else
    cl := 'focus';

  return sprintf ('<a class="%s" href="/fct/facet.vsp?cmd=set_focus&sid=%d&n=%d" title="Focus on %s%d">%s%d</a>',
                    cl,
                    connection_get ('sid'),
		    this_s,
		    fct_s_term (),
		    this_s,
		    fct_s_term (),
		    this_s);
}
;

create procedure
fct_space (in n int)
{
  declare i int;
  declare t varchar;

  t := '';

  for (i := 0; i < n; i := i + 1) {
    concat (t, '&nbsp;');
  }

  return t;
}
;

create procedure
fct_cond_name (in cond varchar)
{
  if ('eq' = cond)        return '==';
  if ('neq' = cond)       return '!=';
  if ('lt' = cond)        return '&lt;';
  if ('lte' = cond)       return '&lt;=';
  if ('gt' = cond)        return '&gt;';
  if ('gte' = cond)       return '&gt;=';
  if ('contains' = cond)  return 'contains';
}
;

create procedure
fct_li (in out_str varchar, in txt any) {
  http ('<li>', txt);
  http (out_str, txt);
  http ('</li>\n', txt);
}
;

create procedure
fct_val_fmt_enc (in val varchar, in lang varchar, in dtp varchar)
{
--  fct_dbg_msg (sprintf ('fct_val_fmt_enc: %s, %s, %s', val, lang, dtp));

  if (lang <> '')
    return sprintf ('"%V"@%V', val, lang);

  if (dtp <> '') {
    if (dtp <> 'uri')
      return sprintf ('"%V"^^%V', val, dtp);
    else
      return sprintf ('&lt;%V&gt;', val);
  }

  return sprintf ('"%V"', val);
}
;

create procedure
fct_query_info_1 (in tree any,
		  in this_s int,
		  inout max_s int,
		  in level int,
		  in ctx any,
		  in txt any,
		  inout cno int)
{
  declare c any;
  declare i, len int;
  c := xpath_eval ('./node()', tree, 0);

  http (sprintf ('<ul class="qry_nfo_lvl_%d">', level),txt);

  for (i := 0; i < length (c); i := i + 1)
    {
      fct_query_info (c[i], this_s, max_s, level + 1, ctx, txt, cno);
    }

  http ('</ul>', txt);
}
;

create procedure
fct_query_info (in tree any,
	        in this_s int,
		inout max_s int,
		in level int,
		in ctx any,
		in txt any,
		inout cno int)
{
  declare n varchar;

  n := cast (xpath_eval ('name ()', tree, 1) as varchar);

  fct_dbg_msg (sprintf ('fct_query_info: cno: %d, level: %d, n: %s, ctx: %d', cno, level, n, ctx));

  http (fct_space (2 * level), txt);

  if ('class' = n)
    {
      if (cast (xpath_eval ('./@exclude', tree) as varchar) = 'yes')
	{
	  fct_li (sprintf ('%s is not a <span class="iri">%s</span> . <a class="qry_nfo_cmd" href="/fct/facet.vsp?sid=%d&cmd=drop_cond&cno=%d">Drop</a>',
		           fct_var_tag (this_s, ctx),
		           fct_short_form (cast (xpath_eval ('./@iri', tree) as varchar)),
		           connection_get ('sid'),
		           cno),
	          txt);
	}
      else
	{
	  fct_li (sprintf ('%s is a <span class="iri">%s</span> . <a class="qry_nfo_cmd" href="/fct/facet.vsp?sid=%d&cmd=drop_cond&cno=%d">Drop</a>',
		           fct_var_tag (this_s, ctx),
		           fct_short_form (cast (xpath_eval ('./@iri', tree) as varchar)),
		           connection_get ('sid'),
		           cno),
	          txt);
	}
      cno := cno + 1;
    }
  else if ('query' = n)
    {
      max_s := 1;
      fct_view_info (tree, ctx, txt);
      fct_query_info_1 (tree, 1, max_s, 1, ctx, txt, cno);
    }
  else if (n = 'text' or n = 'text-d')
    {
      declare prop varchar;
      prop := cast (xpath_eval ('./@property', tree, 1) as varchar);

      if (prop is not null)
        fct_li (sprintf (' %s has <span class="iri"><a href="#"/fct/facet.vsp?sid=%d&cmd=drop_text_prop">%s</a></span> containing text <span class="value">"%s"</span>. ',
                         fct_var_tag (this_s, ctx),
                         connection_get ('sid'),
                         fct_short_form (prop),
                         charset_recode (xpath_eval ('string (.)', tree), '_WIDE_', 'UTF-8')),
                txt);
      else
        fct_li (sprintf (' %s has <a class="qry_info_cmd" href="/fct/facet.vsp?sid=%d&cmd=set_view&type=text-properties&limit=20&offset=0&cno=%d">any %s</a> with %s <span class="value">"%s"</span> <a href="/fct/facet.vsp?sid=%d&cmd=drop_text">Drop</a>. ',
                         fct_var_tag (this_s, ctx),
                         connection_get ('sid'),
                         cno,
		         fct_p_term (),
		         fct_o_term (),
		         charset_recode (xpath_eval ('string (.)', tree), '_WIDE_', 'UTF-8'),
                         connection_get ('sid')),
                 txt);

    }
  else if ('property' = n)
    {
      declare new_s int;
      max_s := max_s + 1;
      new_s := max_s;
      http ('<li>', txt);
      if (cast (xpath_eval ('./@exclude', tree) as varchar) = 'yes')
	{
	  http (sprintf (' %s does not have property <span class="iri">%s</span> %s . ',
                         fct_var_tag (this_s, ctx),
		         fct_short_form (cast (xpath_eval ('./@iri', tree, 1) as varchar)),
                         fct_var_tag (new_s, ctx)),
                txt);
	}
      else
	{
	  http (sprintf (' %s <span class="iri">%s</span> %s . ',
                         fct_var_tag (this_s, ctx),
		         fct_short_form (cast (xpath_eval ('./@iri', tree, 1) as varchar)),
                         fct_var_tag (new_s, ctx)),
                txt);
	}
      if (ctx)
	http (sprintf ('<a class="qry_nfo_cmd" href="/fct/facet.vsp?sid=%d&cmd=drop&n=%d">Drop %s%d</a> ',
	               connection_get ('sid'),
                       new_s,
                       fct_s_term (),
                       new_s),
              txt);

      fct_query_info_1 (tree, new_s, max_s, level, ctx, txt, cno);
      http ('</li>\n', txt);
    }
  else if ('property-of' = n)
    {
      declare new_s int;
      max_s := max_s + 1;
      new_s := max_s;

      http ('<li>', txt);
      http (sprintf (' %s <span class="iri">%s</span> %s . ',
                     fct_var_tag (new_s, ctx),
		     fct_short_form (cast (xpath_eval ('./@iri', tree, 1) as varchar), 1),
		     fct_var_tag (this_s, ctx)),
            txt);

      if (ctx)
	http (sprintf ('<a class="qry_nfo_cmd" href="/fct/facet.vsp?sid=%d&cmd=drop&n=%d">Drop %s%d</a> ',
	               connection_get ('sid'),
	               new_s,
                       fct_s_term (),
                       new_s), txt);

      fct_query_info_1 (tree, new_s, max_s, level, ctx, txt, cno);
      http ('</li>\n', txt);
    }
  if ('value' = n)
    {
      fct_li (sprintf (' %s %s %V . <a class="qry_nfo_cmd" href="/fct/facet.vsp?sid=%d&cmd=drop_cond&cno=%d">Drop</a>',
                       fct_var_tag (this_s, ctx),
		       cast (xpath_eval ('./@op', tree) as varchar),
		       fct_literal (tree),
		       connection_get ('sid'),
		       cno),
              txt);
      cno := cno + 1;
    }
  if ('cond-parm' = n)
    {
      fct_li (sprintf ('%V',
                       fct_literal (tree)),
              txt);
    }
  if ('cond' = n)
    {
      declare cond_t, lang, dtp, neg, val any;
      declare prop_qual varchar;

      cond_t := xpath_eval ('./@type',  tree);
      lang   := xpath_eval ('./@lang',    tree);
      dtp    := xpath_eval ('./@datatype',tree);
      val    := cast (xpath_eval ('.', tree) as varchar);

      if (0 = xpath_eval ('count (./ancestor::*[name()=''property''])+ count(./ancestor::*[name()=''property-of'']) + count(./preceding::*[name()=''class''])', tree, 1)) 
        prop_qual := ' (any property) ';
      else
        prop_qual := '';

      fct_dbg_msg (sprintf ('fct_qry_info: cond: type:%s dtp:%s lang:%s val:%s',
                            cast (cond_t as varchar),
                            cast (dtp as varchar),
                            cast (lang as varchar),
                            val));

      if (0 = lang) lang := '';
      if (0 = dtp)  dtp  := '';

      http ('<li>', txt);

      if (cond_t = 'eq' or
          cond_t = 'neq' or
          cond_t = 'lt' or
          cond_t = 'lte' or
          cond_t = 'gt' or
          cond_t = 'gte')
        {
 --val_fmt_enc (val, lang, dtp)),
          http (sprintf ('%s %s%s %V',
                          fct_var_tag (this_s, ctx),
                          prop_qual,
                          fct_cond_name (cond_t),
	                  fct_literal (xpath_eval ('.', tree))),
                txt);
        }
        else if ('contains' = cond_t)
          {
            http (sprintf (' %s %scontains "%s" .',
                           fct_var_tag (this_s, ctx),
                           prop_qual,
                           val),
                  txt);
          }
        else if ('in' = cond_t)
          {
            declare this_cno int;
            declare neg varchar;
            neg := case when (xpath_eval ('./@neg', tree) = '1') then 'NOT ' else '' end;
            this_cno := cno;
            http (sprintf ('%s %sis %sIN: ', fct_var_tag (this_s, ctx), prop_qual, neg), txt);
            fct_query_info_1 (tree, this_s, max_s, level, ctx, txt, cno);
            http (sprintf (' <a class="qry_nfo_cmd" href="/fct/facet.vsp?sid=%d&cmd=drop_cond&cno=%d">Drop</a>',
                           connection_get ('sid'),
                           this_cno),
                  txt);

            http ('</li>\n', txt);
            cno := cno + 1;
            return;
          }
        else if ('near' = cond_t)
          {
            declare lat, lon float;
            declare d integer;
            declare prop varchar;
            declare prop_info varchar;
            declare acq_l integer;

            lat   := xpath_eval ('./@lat', tree);
            lon   := xpath_eval ('./@lon', tree);
            d     := xpath_eval ('./@d', tree);
            acq_l := xpath_eval ('./@acquire', tree);
            prop  := xpath_eval ('./@location-prop', tree);

            prop_info := '.';

            if (prop <> '') {
              prop_info := sprintf (' by %s property.', prop);
            }

            if (acq_l is not null and (length(lat) = 0 or length(lon) = 0))
              {
	          fct_dbg_msg ('Triggering autolocation');
        	  http (sprintf ('<span class="acq_l_ind" id="acq_l_ind">Locating...</span><span class="acq_l_trig" id="acq_l_trig" style="display:none">%d</span>', cno), txt);
              }

            if (length(lat) and length(lon))
              {
                http (sprintf ('%s is within %s km radius of lat:<span class="loc_lat">%s</span>, lon:<span class="loc_lon">%s</span>%s',
                               fct_var_tag(this_s, ctx),
                               d,
                               lat,
                               lon,
                               prop_info),
                      txt);
                if (acq_l is not null)
                  http ('<span class="autoloc_ind">Location acquired.</span>', txt);
              }
          }
      http (sprintf (' <a class="qry_nfo_cmd" href="/fct/facet.vsp?sid=%d&cmd=drop_cond&cno=%d">Drop</a>',
                      connection_get ('sid'),
                      cno),
            txt);

      http ('</li>\n', txt);
      cno := cno + 1;
    }
  if ('cond-range' = n)
    {
      declare hi, lo, neg, cond_t any;

      cond_t := xpath_eval ('./@type', tree);
      hi     := xpath_eval ('./@hi', tree);
      lo     := xpath_eval ('./@lo', tree);
      neg    := xpath_eval ('./@neg', tree);

      http ('<li>', txt);

      if (neg = 'on' or 'neg_range' = cond_t)
        neg := ' not ';
      else
        neg := '';

      http (sprintf (' %s is %s between %V and %V .',
                     fct_var_tag (this_s, ctx),
                     neg,
                     cast (lo as varchar),
                     cast (hi as varchar)),
                txt);

      http (sprintf (' <a class="qry_nfo_cmd" href="/fct/facet.vsp?sid=%d&cmd=drop_cond&cno=%d">Drop</a>',
                      connection_get ('sid'),
                      cno),
            txt);
      http ('</li>\n', txt);
      cno := cno + 1;
    }
}
;

VHOST_REMOVE (lpath=>'/fct');
VHOST_DEFINE (lpath=>'/fct',
    	ppath=>case when registry_get('_fct_path_') = 0 then '/fct/' else registry_get('_fct_path_') end,
	is_dav=>atoi (case when registry_get('_fct_dav_') = 0 then '0' else registry_get('_fct_dav_') end),
    	vsp_user=>'SPARQL', def_page=>'facet.vsp');
VHOST_REMOVE (lpath=>'/b3s');
VHOST_DEFINE (lpath=>'/b3s',
    	ppath=>case when registry_get('_fct_path_') = 0 then '/fct/' else registry_get('_fct_path_') end || 'www/',
	is_dav=>atoi (case when registry_get('_fct_dav_') = 0 then '0' else registry_get('_fct_dav_') end),
    	vsp_user=>'dba', def_page=>'listall.vsp');


create procedure
fct_top (in tree any, in txt any)
{
  declare max_s int;
  max_s := 0;

  declare cno int;
  cno := 0;

  declare ctx int;
  ctx := fct_view_pos (tree)+1;
  fct_dbg_msg (sprintf ('fct_top: ctx: %d', ctx));

  fct_query_info (xpath_eval ('/query', tree), 1, max_s, 1, ctx, txt, cno);
}
;

create procedure
fct_view_link (in tp varchar, in msg varchar, in txt any, in tip any := null)
{
  if (tip is null)
    tip := msg;

  http (sprintf ('<li><a href="/fct/facet.vsp?cmd=set_view&sid=%d&type=%s&limit=20&offset=0" title="%V">%s</a></li>',
                 connection_get ('sid'), tp, tip, msg), txt);
}
;

create procedure
fct_ft_a (in txt any)
{
  http(sprintf ('<li><form><label for="ft_q">Text</label><input type="hidden" name="cmd" value="text"/><input type="hidden" name="sid" value="%d"/><input type="text" name="q"/><input type="submit" value="Set"/></li>',
                 connection_get('sid')),
                 txt);
}
;

create procedure
fct_set_conn_tlogy (in tree any)
{
  declare c_term, s_term varchar;

  c_term := cast (xpath_eval ('/query/@c-term', tree) as varchar);
  s_term := cast (xpath_eval ('/query/@s-term', tree) as varchar);
  connection_set ('c_term', c_term);
  connection_set ('s_term', s_term);
}
;

create procedure
fct_nav (in tree any,
         in reply any,
         in txt any)
{
  declare pos int;
  declare tp varchar;
  tp := cast (xpath_eval ('//view/@type', tree) as varchar);
  pos := fct_view_pos (tree);

  fct_set_conn_tlogy (tree);

  http ('<div id="fct_nav">', txt);
  http ('<h3>Entity Relations Navigation</h3>', txt);
  http ('<ul class="n1">', txt);

  if ('text-properties' = tp)
    {
      fct_view_link ('text', 'Return to text match list', txt);
      return;
    }

  if (xpath_eval ('//query/text', tree) is null)
    {
      fct_ft_a (txt);
    }

  if ('classes' <> tp)
    if (connection_get('c_term') = 'class')
	fct_view_link ('classes', 'Classes', txt);
    else
	fct_view_link ('classes', 'Types', txt, 'Entity Category or Class');

  if ('properties' <> tp)
    if (connection_get('s_term') = 's')
      fct_view_link ('properties', 'Properties', txt, 'Entity Characteristic or Property');
    else
      fct_view_link ('properties', 'Attributes', txt, 'Entity Characteristic or Property');

  if ('text' = tp and pos = 0)
    fct_view_link ('text-properties', 'Properties containing the text', txt);

  if ('properties-in' <> tp)
    if (connection_get('s_term') = 's')
      fct_view_link ('properties-in', 'Referencing Properties', txt, 'Characteristics or Properties with Entity References as values');
    else
      fct_view_link ('properties-in', 'Referencing Attributes', txt, 'Characteristics or Properties with Entity References as values');

  if ('text' <> tp and tp <> 'text-d')
    {
      if (tp <> 'list-count')
	if (connection_get('s_term') = 's')
	  fct_view_link ('list-count', 'Distinct objects (Aggregated)', txt, 'Displaying List of Distinct Entity Names ordered by Count');
	else
	  fct_view_link ('list-count', 'Distinct values (Aggregated)', txt, 'Displaying List of Distinct Entity Names ordered by Count');
      if (tp <> 'list')
	if (connection_get('s_term') = 's')
	  fct_view_link ('list', 'Show Matching Objects', txt, 'Displaying Ranked Enitity Names and Text summaries');
	else
	  fct_view_link ('list', 'Show Matching Values', txt, 'Displaying Ranked Enitity Names and Text summaries');
    }

  if ('full-text' <> tp and not xpath_eval ('//query/text', tree))
    {
      fct_view_link ('full-text', 'Text', txt,'Add full-text constraint');
    }

  if ('geo' <> tp)
    {
      --fct_view_link ('geo', 'Map', txt);
      http (sprintf ('<li><a id="map_link" href="/fct/facet.vsp?cmd=set_view&sid=%d&type=%s&limit=200&offset=0" title="%V">%s</a>&nbsp;'||
	    		'<select name="map_of" onchange="javascript:link_change(this.value)">'||
	    		'<option value="any">Any location</option>'||
	    		'<option value="">Shown items</option>'||
	    		'<option value="dbpprop:location">dbpedia:location</option>'||
	    		'<option value="dbpprop:place">dbpedia:place</option>'||
	    		'<option value="foaf:based_near">foaf:based_near</option>'||
	    		'<option value="geo:location">geo:location</option>'||
	    		'<option value="geo:Point">geo:Point</option>'||
	    		'<option value="dbpprop:birthPlace">dbpedia:birthPlace</option>'||
	    		'<option value="dbpprop:placeOfBirth">dbpedia:placeOfBirth</option>'||
	    		'<option value="dbpprop:birthplace">dbpedia:birthplace</option>'||
	    		'<option value="dbpprop:placeOfDeath">dbpedia:placeOfDeath</option>'||
	    		'<option value="dbpprop:deathPlace">dbpedia:deathPlace</option>'||
			'</select></li>',
                 connection_get ('sid'), 'geo', 'Geospatial Entities projected over Map overlays', 'Places'), txt);
    }

  http ('</ul><ul class="n2">', txt);
  http (sprintf ('<li><a href="/fct/facet.vsp?cmd=set_inf&sid=%d">Options</a></li>',
                 connection_get ('sid')), txt);
  http (sprintf ('<li><a href="/fct/facet.vsp?cmd=save_init&sid=%d">Save</a></li>',
                 connection_get ('sid')), txt);
  http (sprintf ('<li><a href="/fct/facet.vsp?cmd=featured&sid=%d">Featured Queries</a></li>',
                 connection_get ('sid')), txt);
  http (sprintf ('<li><a href="/fct/facet.vsp?sid=%d">New Search</a></li>',
                 connection_get ('sid')), txt);
  http ('</ul>', txt);
  http ('</div> <!-- #fct_nav -->', txt);
}
;

create procedure
fct_view_type (in vt varchar)
{
  if (vt in ('properties',
             'classes',
             'properties-in',
             'text-properties',
             'list',
             'list-count',
             'propval-list',
             'geo',
             'geo-list'))
    return vt;

  return 'default';
}
;

create procedure
fct_view_cmd (in tp varchar)
{
  fct_dbg_msg (sprintf ('fct_view_cmd: tp=%s', tp));

  if ('text-properties' = tp)
    return 'set_text_property';

  if ('properties' = tp)
    return 'open_property';

  if ('properties-in' = tp)
    return 'open_property_of';

  if ('classes' = tp)
    return 'set_class';

  if ('full-text' = tp)
    return 'set_text';

  if ('list-count' = tp or 'geo-list' = tp)
    return 'select_value';

  return 'cond';
}
;

cl_exec ('registry_set (''fct_timeout'', ''0'')');
cl_exec ('registry_set (''fct_timeout_max'', ''20000'')');

create procedure
fct_set_default_qry (inout tree any)
{

  tree := xslt (registry_get ('_fct_xslt_') || 'fct_set_default.xsl',
                tree,
		vector ('pos', 1, 'op', 'class', 'iri', 'http://www.w3.org/2000/01/rdf-schema#Class'));

}
;

create procedure
fct_print_space_1 (inout ses any, in n int)
{
  for (declare i int, i := 0; i < n;  i := i + 1)
    http (' ', ses);
}
;

create procedure
fct_pretty_sparql_1 (inout arr any, inout inx int, in len int, inout ses any, in lev int := 0)
{
  declare nbsp, was_open, was_close, num_open int;
  nbsp := 0;
  was_open := 0;
  was_close := 0;
  num_open := 0;
  for (;inx < len; inx := inx + 1)
    {
      declare elm varchar;
      elm := arr[inx];
      if (elm = 'sparql')
        goto skipit;

      if (elm = '(')
	num_open := num_open + 1;
      if (elm = ')')
	num_open := num_open - 1;

      if (num_open = 0)
        {
	  if (elm = '{')
	    {
	      nbsp := nbsp + 2;
	      http ('\n', ses);
	      fct_print_space_1 (ses, nbsp);
	      was_open := 1;
	      was_close := 0;
	    }
	  else if (was_open = 1)
	    {
	      was_open := 0;
	      was_close := 0;
	      http ('\n', ses);
	      fct_print_space_1 (ses, nbsp + 2);
	    }
	  else if (elm = '}')
	    {
	      if (not was_close)
		{
		  http ('\n', ses);
		  fct_print_space_1 (ses, nbsp);
		}
	    }
	  else
	    was_close := 0;
	}


      http (elm, ses);

      if (num_open = 0)
        {
	  if (elm = '}')
	    {
	      was_close := 1;
	      nbsp := nbsp - 2;
	      http ('\n', ses);
	      fct_print_space_1 (ses, nbsp);
	    }
	  else if (elm = '.')
	    {
	      http ('\n', ses);
	      fct_print_space_1 (ses, nbsp + 1);
	    }
	}

      if (elm = 'sparql')
	http ('\n');
      http (' ', ses);
      skipit:;
    }
}
;

create procedure
fct_pretty_sparql (in q varchar, in lev int := 0)
{
  declare ses, arr any;
  declare inx int;
  ses := string_output ();
  --q := sprintf ('%V', q);
  q := replace (q, '\n', ' ');
  q := replace (q, '}', ' } ');
  q := replace (q, '{', ' { ');
  q := replace (q, ')', ' ) ');
  q := replace (q, '(', ' ( ');
  q := regexp_replace (q, '\\s\\s+', ' ', 1, null);
  arr := split_and_decode (q, 0, '\0\0 ');
  inx := 0;
  fct_pretty_sparql_1 (arr, inx, length (arr), ses, lev);
  return string_output_string (ses);
}
;


create procedure
fct_web (in tree any)
{
  declare sqls, msg, tp, agg, agg_qr, agg_res varchar;
  declare start_time int;
  declare reply, md, res, qr, qr2, txt any;
  declare p_qry varchar;
  declare timeout int;

  timeout := connection_get ('timeout');

  if (not isinteger(timeout))
    timeout := atoi(timeout);

--
-- Empty query - get classes as default qry
--

  if (xpath_eval('/query/*[not(name()=''view'')]', tree) is null)
    {
      if (xpath_eval('/query/view[@type=''classes'']', tree) is null)
	fct_set_default_qry (tree);
    }

  reply := fct_exec (tree, timeout);

  p_qry := fct_query (tree, 1); -- get "plain" query text
  p_qry := fct_pretty_sparql (p_qry);
  agg := cast (xpath_eval('/query/@agg', tree) as varchar);

  agg_res := null;
  if (length (agg))
    {
      declare state, message, dta any;
      agg_qr := 'sparql ' || fct_agg_query (tree, agg);
      state := '00000';
      exec (agg_qr, state, message, vector (), 0, null, dta);
      dbg_obj_print (dta);
      if (state = '00000') agg_res := dta[0][0];
      else -- wrong query
        {
	  tree := xslt (registry_get ('_fct_xslt_') || 'fct_set_agg.xsl', tree, vector ('agg', ''));
	  update fct_state set fct_state = tree where fct_sid = connection_get ('sid');
	  commit work;
	}
    }

--  dbg_obj_print (reply);

  txt := string_output ();

  http ('<div id="top_ctr">', txt);

  fct_top (tree, txt);

  http('<div id="sparql_a_ctr"></div>', txt);

  if (DB.DBA.VAD_CHECK_VERSION('fct_pivot_bridge') is not NULL) {
      http('<div id="pivot_a_ctr"></div>', txt);
  }

  http ('</div>', txt);

  tp := cast (xpath_eval ('//view/@type', tree) as varchar);

  declare p_ses, r_ses any;
  declare p_xml varchar;
  declare p_xml_tree any;

  p_xml_tree := xslt (registry_get ('_fct_xslt_') || 'fct_strip_loc.xsl', tree, vector());

  p_ses := string_output();
  http_value (p_xml_tree, null, p_ses);

  p_xml := cast (p_ses as varchar);

  r_ses := string_output ();
  http_value (reply, null, r_ses);

  fct_dbg_msg (sprintf ('reply: %s', cast (r_ses as varchar)));

  declare _addthis_key varchar;
  _addthis_key := registry_get ('fct_addthis_key');
  if (not isstring(_addthis_key)) _addthis_key := null;
  if ('1' = _addthis_key) _addthis_key := 'xa-4ce13e0065cdadc0';

  --dbg_printf('addthis_key: %s', _addthis_key);

  http_value (xslt (registry_get ('_fct_xslt_') || 'fct_vsp.xsl',
                    reply,
		    vector ('sid',
		            connection_get ('sid'),
     			    'cmd',
			    fct_view_cmd (tp),
			    'type',
			    fct_view_type (tp),
			    'timeout',
			    __min (timeout*2, atoi (registry_get ('fct_timeout_max'))),
			    'query',
			    tree,
			    's_term',
			    fct_s_term (),
			    'p_term',
			    fct_p_term (),
			    'o_term',
			    fct_o_term (),
			    't_term',
			    fct_t_term (),
                            'p_qry',
                            p_qry,
                            'p_xml',
                            p_xml,
                            'addthis_key',
                            _addthis_key,
                            'tree',
                            tree,
			    'agg_res',
			    agg_res
			    )),
	      null, txt);

  fct_nav (tree, reply, txt);

  http (txt);
}
;

--# text view set
create procedure
fct_set_text (in tree any, in sid int, in txt varchar)
{
  declare new_tree any;

  new_tree := xslt (registry_get ('_fct_xslt_') || 'fct_set_text.xsl', tree, vector ('text', txt, 'prop', 'none'));

  if (xpath_eval ('//view', new_tree) is null)
    {
      new_tree := xslt (registry_get ('_fct_xslt_') || 'fct_set_view.xsl',
                        new_tree,
		        vector ('pos', 0, 'type', 'text-d', 'limit', 20, 'op', 'view'));
    }

  update fct_state set fct_state = new_tree where fct_sid = sid;
  commit work;

  fct_web (new_tree);
}
;

--# text view set
create procedure
fct_set_text_property (in tree any, in sid int, in iri varchar)
{
  declare new_tree, txt any;

  txt := cast (xpath_eval ('//text', tree) as varchar);
  new_tree := xslt (registry_get ('_fct_xslt_') || 'fct_set_text.xsl',
                    tree, vector ('text', txt, 'prop', iri));
  new_tree := xslt (registry_get ('_fct_xslt_') || 'fct_set_view.xsl',
                    new_tree, vector ('pos', 0, 'type', 'text-d', 'limit', 20, 'op', 'view'));

  update fct_state set fct_state = new_tree where fct_sid = sid;
  commit work;

  fct_web (new_tree);
}
;

create procedure
fct_set_focus (in tree any, in sid int, in pos int)
{
  tree := xslt (registry_get ('_fct_xslt_') || 'fct_set_view.xsl',
                tree,
		vector ('pos', pos - 1, 'op', 'view', 'type', 'list', 'limit', 20, 'offset', 0));
  update fct_state set fct_state = tree where fct_sid = sid;
  commit work;

  fct_web (tree);
}
;

create procedure
fct_drop (in tree any, in sid int, in pos int)
{
  tree := xslt (registry_get ('_fct_xslt_') || 'fct_set_view.xsl',
                tree, vector ('pos', pos - 1, 'op', 'close'));

  if (xpath_eval ('//view', tree) is null)
    tree := xslt (registry_get ('_fct_xslt_') || 'fct_set_view.xsl',
                  tree, vector ('pos', 0, 'op', 'view', 'type', 'list', 'limit', 20, 'offset', 0));

  update fct_state set fct_state = tree where fct_sid = sid;
  commit work;

  fct_web (tree);
}
;

create procedure
fct_drop_cond (in tree any, in sid int, in cno int)
{
  fct_dbg_msg (sprintf ('fct_drop_cond: cno: %d', cno));
  tree := xslt (registry_get ('_fct_xslt_') || 'fct_drop_cond.xsl', tree, vector ('cno', cno));

  update fct_state set fct_state = tree where fct_sid = sid;
  commit work;

  fct_web (tree);
}
;

create procedure
fct_drop_text (in tree any, in sid int)
{
  declare txt varchar;
  txt := xpath_eval ('//text', tree);

  tree := xslt (registry_get ('_fct_xslt_') || 'fct_drop_text.xsl', tree, vector ('text', txt, 'prop', 'none'));

  update fct_state set fct_state = tree where fct_sid = sid;
  commit work;

  fct_web (tree);
}
;

create procedure
fct_drop_text_prop (in tree any, in sid int)
{
  declare txt varchar;
  txt := xpath_eval ('//text', tree);

  tree := xslt (registry_get ('_fct_xslt_') || 'fct_set_text.xsl', tree, vector ('text', txt, 'prop', 'none'));

  update fct_state set fct_state = tree where fct_sid = sid;
  commit work;

  fct_web (tree);
}
;

create procedure
fct_set_view (in tree     any,
              in sid      int,
              in tp       varchar,
              in lim      int,
              in offs     int,
              in loc_prop varchar := null)
{

  declare pos int;
  pos := fct_view_pos (tree);

  if ('text-properties' = tp)
    {
      declare txt varchar;

      txt := cast (xpath_eval ('//text', tree) as varchar);
      tree := xslt (registry_get ('_fct_xslt_') || 'fct_set_text.xsl',
                    tree,
		    vector ('text', txt, 'prop', 'none'));
    }

  tree := xslt (registry_get ('_fct_xslt_') || 'fct_set_view.xsl',
                tree,
		vector ('pos', pos,
		        'op', 'view',
			'type', tp,
			'limit', lim,
			'offset', offs,
			'location-prop', loc_prop));

  update fct_state set fct_state = tree where fct_sid = sid;
  commit work;

  fct_web (tree);
}
;

create procedure
fct_next (in tree any, in sid int, in offset varchar, in limit varchar)
{
  declare tp varchar;
  declare lim, offs int;

  tp := cast (xpath_eval ('//view/@type',  tree) as varchar);

  if (isstring (limit) and limit <> '')
    lim := atoi (limit);
  else
    lim  := atoi (cast (xpath_eval ('//view/@limit', tree) as varchar));

  if (isstring (offset) and offset <> '')
    offs := atoi (offset);
  else
    offs := atoi (cast (xpath_eval ('//view/@offset',tree) as varchar));

  fct_set_view  (tree, sid, tp, lim, offs + lim);
}
;

create procedure
fct_prev (in tree any, in sid int, in offset varchar, in limit varchar)
{
  declare tp varchar;
  declare lim, offs int;

  tp := cast (xpath_eval ('//view/@type',  tree) as varchar);

  if (isstring (limit) and limit <> '')
    lim := atoi (limit);
  else
    lim := atoi (cast (xpath_eval ('//view/@limit', tree) as varchar));

  if (isstring (offset) and offset <> '')
    offs := atoi (offset);
  else {
    offs := atoi (cast (xpath_eval ('//view/@offset',tree) as varchar));
    offs := offs - lim;
    if (offs < 0) offs := 0;
  }
  fct_set_view  (tree, sid, tp, lim, offs);
}
;

create procedure
fct_go_to (in tree any, in sid int, in _offs varchar, in _lim varchar)
{
  declare tp varchar;
  declare offs, lim int;

  if (isstring (_offs) and _offs <> '')
    offs := atoi (_offs);

  if (isstring (_lim) and _lim <> '')
    lim  := atoi (_lim);
  else
    lim := atoi (cast (xpath_eval ('//view/@limit', tree) as varchar));

  if (offs is null) offs := 0;

  fct_dbg_msg (sprintf ('fct_go_to offs: %d, lim: %d', offs, lim));

  tp := cast (xpath_eval ('//view/@type',  tree) as varchar);

  fct_set_view  (tree, sid, tp, lim, offs);
}
;

create procedure
fct_open_property  (in tree any,
                    in sid int,
                    in iri varchar,
                    in name varchar,
                    in exclude varchar := null)
{
  declare pos int;
  pos := fct_view_pos (tree);

  tree := xslt (registry_get ('_fct_xslt_') || 'fct_set_view.xsl',
                tree,
		vector ('pos', pos,
		        'op', 'prop',
			'name', name,
			'iri', iri,
			'type', 'list',
			'limit', 20,
			'offset', 0,
			'exclude', exclude));

  if (xpath_eval ('//view', tree) is null)
    {

      tree := xslt (registry_get ('_fct_xslt_') || 'fct_set_view.xsl', tree,
                    vector ('pos', pos,
                    'op', 'view',
                    'type', 'properties',
                    'limit', 20,
                    'offset', 0));
    }

  update fct_state
    set fct_state = tree
    where fct_sid = sid;

  commit work;
  fct_web (tree);
}
;

create procedure
fct_set_class (in tree any,
	       in sid int,
	       in iri varchar,
	       in exclude varchar := null)
{
  declare pos int;

  pos := fct_view_pos (tree);

  fct_dbg_msg (sprintf ('fct_set_class: sid: %d, iri: %s, pos: %d', sid, iri, pos));

  tree := xslt (registry_get ('_fct_xslt_') || 'fct_set_view.xsl',
                tree,
                vector ('pos',     pos,
		        'op',      'class',
			'iri',     iri,
			'type',    'list',
			'limit',   20,
			'offset',  0,
			'exclude', exclude));

  tree := xslt (registry_get ('_fct_xslt_') || 'fct_set_view.xsl',
                tree,
                vector ('pos', 0, 'op', 'view', 'type', 'list', 'limit', 20, 'offset', 0));

  update fct_state
    set fct_state = tree
    where fct_sid = sid;

  commit work;
  fct_web (tree);
}
;

create procedure
fct_featured (in tree xmltype, in sid int) {
http ('
  <div class="featured">
    <h2>Featured</h2>
    <div class="expln"><p>These are example facet views and SPARQL queries in the server.</p></div>
    <div class="fm_sect">
      <h3>Facet views</h3>
      <table id="featured_list">
');
	declare no_qry, cnt int;
	cnt := 0;
	no_qry := http_param ('no_qry');

        for (select fsq_id,
                    fsq_title,
                    fsq_expln
               from fct_stored_qry
               where fsq_featured is not null
               order by fsq_featured desc) do
          {
            cnt := cnt + 1;
http ('
            <tr>
              <td><a href="/fct/facet.vsp?cmd=load&fsq_id='); http_value ( fsq_id ); http ('">'); http_value (fsq_title); http ('</a></td>
              <td>'); http_value ( fsq_expln ); http ('</td>
            </tr>
');
          }
	if (0 = cnt)
          {
http ('
	    <tr><td>There are currently no featured views.</td></td>
');
          }
http ('
      </table>
    </div> <!-- .fm_sect -->
    <div class="fm_sect">
      <h3>SPARQL Queries</h3>
      <p>These queries will open in iSPARQL - a SPARQL query visualization and editing tool.</p>
      <table class="sparql_qry_list">
');

   declare uriqa_str varchar;
   declare dav_pwd varchar;
   declare demo_dav_path, demo_xsl_uri varchar;

   uriqa_str := cfg_item_value( virtuoso_ini_path(), 'URIQA','DefaultHost');

   if (uriqa_str is null)
     {
       if (server_http_port () <> '80')
         uriqa_str := 'localhost:'||server_http_port ();
       else
         uriqa_str := 'localhost';
     }

   demo_dav_path := registry_get ('sparql_demo_query_path');

   if (0 = demo_dav_path)
     demo_dav_path := '/DAV/home/dav/sparql_demo_queries/';

   demo_xsl_uri := registry_get ('sparql_demo_xsl_uri');

   if (0 = demo_xsl_uri) demo_xsl_uri := 'http://' || uriqa_str || '/fct/isparql_describe.xsl';

http('
<script type="text/javascript">
var featureList = ["","",""];

var sparql_ep = ''http://<?=uriqa_str?>/sparql'';
var isparql_ep = ''http://<?=uriqa_str?>/isparql'';

function init() {  }

function sparql_qry (q_elm) {

  document.location = sparql_ep + ''?query='' + get_and_encode_query (q_elm);
}

function isparql_qry (q_elm) {
  document.location = sparql_ep + ''?query='' + get_and_encode_query (q_elm);
}

function get_and_encode_query (q_elm)
{
  return encodeURIComponent (document.getElementById(q_elm).firstChild.data);
}

</script>
');

  declare ct_tree, xst any;
  declare ctr integer;

  ctr := 0;

  for select res_content, res_name, res_full_path
        from WS.WS.SYS_DAV_RES
        where RES_FULL_PATH like demo_dav_path || '%.isparql' do
    {
	ctr := ctr + 1;
	ct_tree := xml_tree_doc (xml_tree (res_content));
	http_value (xslt (demo_xsl_uri,
		    	  ct_tree,
                     	  vector ('name', res_name, 'full_path', 'http://' || uriqa_str || res_full_path)));

    }

http('</table>');

  if (0 = ctr)
    {
      http ('<p class="empty_indicator">There are currently no saved SPARQL queries.</p>');
    }
http('
    </div> <!-- .fm_sect -->
    <a href="/fct/facet.vsp?cmd=refresh&sid='); http_value ( case when no_qry then 0 else sid end ); http ('">Go Back</a>
  </div>
  </div> <!-- featured -->
');
}
;

create procedure
fct_save_init (in tree xmltype, in sid int)
{

http ('
  <div class="dlg" id="save_frm">
    <div class="title"><h2>Save</h2></div>
    <form method="post"
          action="/fct/facet.vsp?cmd=save&sid='); http_value ( sid ); http ('" >
      <div class="fm_sect">
        <h3>Information</h3>
        <div class="expln">
           <p>Please give this query a title and explanation and hit [Save] - then bookmark the permalink on next screen.</p>
        </div>
        <label class="left_txt"
               for="title">Title</label><input id="title" size="50" type="text" name="title"><br/>
        <label class="left_txt"
               for="desc">Description</label><input id="desc" size="80" type="text" name="desc"><br/>
      </div> <!-- fm_sect -->
      <div class="btn_bar">
        <input type="submit" value="Save"/>
        <button onclick="javascript:document.location=''/fct/facet.vsp?cmd=refresh&sid='); http_value ( sid ); http (''';return false;" >Cancel</button>
      </div>
    </form>
  </div>
');
}
;

create procedure
fct_save (in tree xmltype,
          in sid int,
          in title varchar,
          in _desc varchar)
{
  declare _fsq_id int;

  _fsq_id := sequence_next ('fsq_seq');

  insert into fct_stored_qry (fsq_id, fsq_title, fsq_expln, fsq_state)
    values (_fsq_id, title, _desc, tree);

  http ('

<div class="dlg" id="save_complete">
  <div class="title"><h2>Save Complete</h2></div>
  <div class="expln">
    <p><br/>
    Your query has been saved.<br/>
    Please bookmark this link: <a href="/fct/facet.vsp?cmd=load&fsq_id='); http_value ( _fsq_id ); http ('" title="'); http_value ( _desc ); http ('">'); http_value ( title ); http ('</a> to return to it.</p>
  </div>
  <div class="btn_bar"><button onclick="javascript:document.location=''/fct/facet.vsp?sid='); http_value ( sid ); http ('&cmd=refresh''">Continue</button></div>
</div>
  ');
}
;

create procedure
fct_load (in from_stored int)
{
  declare sid int;

  sid := sequence_next ('fct_seq');
  declare tree any;

  whenever not found goto no_ses;

  select fsq_state
    into tree
    from fct_stored_qry
    where fsq_id = from_stored;

  insert into fct_state (fct_sid, fct_state)
    values (sid, tree);

  return sid;

  no_ses:
    fct_new ();
    return null;
}
;

create procedure
fct_ses_from_xml (in xml_d varchar)
{
  declare tree any;
  declare sid int;

  sid := sequence_next ('fct_seq');

  tree := xtree_doc (xml_d);

  insert into fct_state (fct_sid, fct_state)
         values (sid, tree);

  return sid;
}
;

create procedure
fct_create_ses ()
{
  declare sid int;
  declare new_tree any;

  sid := sequence_next ('fct_seq');
  new_tree := xtree_doc('<?xml version="1.0" encoding="UTF-8"?>\n' ||
                        '<query inference="" same-as="" view3="" s-term="" c-term="" agg=""/>');

  insert into fct_state (fct_sid, fct_state)
         values (sid, new_tree);

  return vector (sid, new_tree);
}
;

create procedure
fct_new ()
{
  declare sid int;
  declare r_v any;

  sid := http_param ('sid');

  if (0 = sid)
    {
     no_ses:
      r_v := fct_create_ses ();
      sid := r_v[0];
    }
  else
    {
      declare tree any;

      whenever not found goto no_ses;

      select fct_state
        into tree
	from fct_state
	where fct_sid = sid;

      tree := XMLUpdate (tree, '/query/*', null);

      update fct_state
        set fct_state = tree
	where fct_sid = sid;
    }

  declare fct_demo_uri varchar;
  fct_demo_uri := registry_get ('fct_demo_uri');

  if (0 = fct_demo_uri)
    fct_demo_uri := '/fct/demo_queries.vsp';

  http ('
  <div id="main_srch" style="display: none">
    <div id="TAB_ROW">
      <div class="tab" id="TAB_TXT">Text Search</div>
      <div class="tab" id="TAB_URILBL">Entity Label Lookup</div>
      <div class="tab" id="TAB_URI">Entity URI Lookup</div>
      <div class="tab_act">
        <a href="/fct/facet.vsp?cmd=featured&sid='); http_value ( sid ); http ('&no_qry=1">Featured</a>
        &nbsp;|&nbsp;
        <a href="');
  http ( fct_demo_uri );
  http ('">Demo Queries</a>
        &nbsp;|&nbsp;
        <a href="facet_doc.html">About</a>
        <!--span id="opensearch_container" style="display:none">&nbsp;|&nbsp;
        <a href=""
           id="opensearch_link"
           title="Install OpenSearch Plugin">Search from browser</a></span-->
      </div>
    </div> <!-- #TAB_ROW -->
    <div id="TAB_CTR">
    </div> <!-- #TAB_CTR -->
    <div id="TAB_PAGE_TXT" class="tab_page" style="display: none">
      <h2>Precision Search &amp; Find</h2>
      <form method="post"
            action="/fct/facet.vsp?cmd=text&sid=');
  http_value ( sid );
  http ('" >
        <div id="new_srch">
          <label class="left_txt"
                 for="new_search_txt">Search Text</label>
          <input id=  "new_search_txt"
                 size="60"
                 type="text"
                 name="q"/>');
if (isstring (http_param ('dbg')))
  {
    http('<input type="hidden" name="dbg" value="');
    http_value (http_param('dbg'));
    http ('">');
  }
if (isstring (http_param ('dbg_out')))
  {
    http('<input type="hidden" name="dbg_out" value="');
    http_value (http_param('dbg_out'));
    http ('">');
  }
  http('<input type=submit  value="Search"><br/>
        </div>
      </form>
    </div> <!-- #TAB_PAGE_TXT -->
    <div id="TAB_PAGE_URILBL" class="tab_page" style="display: none">
      <h2>Precision Search &amp; Find</h2>
      <form method="get" action="/describe/" id="new_lbl_fm">
        <input type="hidden" name="url" id="new_lbl_val"/>
	<input type="hidden" name="sid" value="'); http_value ( sid ); http ('"/>
	<input type="hidden" name="urilookup" value="1"/>
      </form>
      <div id="new_uri">
        <label class="left_txt"
               for=  "new_lbl_txt">Label</label>

        <input id=  "new_lbl_txt"
               size="60"
               type="text"
               autocomplete="off"/>

        <button id="new_lbl_btn">Describe</button><br/>
      </div>
      '); if (registry_get ('urilbl_ac_init_status') <> '2') { http ('
      <div class="ac_info">
        <img class="txt_i" alt="info" src="/fct/images/info.png"/>
        <span class="ac_info">Lookup data (re)generation in progress. Results will be incomplete.</span>
      </div>
      '); } http ('
    </div>
    <div id="TAB_PAGE_URI" class="tab_page" style="display: none">
      <h2>Precision Search &amp; Find</h2>
      <form method="get" action="/describe/" id="new_uri_fm">
        <input type="hidden" name="url" id="new_uri_val"/>
	<input type="hidden" name="sid" value="'); http_value ( sid ); http ('"/>
	<input type="hidden" name="urilookup" value="1"/>
      </form>
      <div id="new_uri">
        <label class="left_txt"
               for=  "new_uri_txt">URI</label>

        <input id=  "new_uri_txt"
               size="60"
               type="text"
               autocomplete="off"/>
        <button id="new_uri_btn">Describe</button><br/>
      </div>
    </div> <!-- #TAB_PAGE_URI -->
  </div> <!-- #main_srch -->
  <div class="main_expln"><br/>
    Hint: <i>You can <a id="opensearch_link" href="#">add this engine</a> in search bar of an OpenSearch - capable browser</i><br/>
  </div>
 ');
}
;

-- /* options */
create procedure
fct_set_inf (in tree any, in sid int)
{
  declare inf, sas, view3, tlogy, s_term, c_term varchar;
  inf := http_param ('inference');
  sas := http_param ('same-as');
  if (sas = 0) sas := '';
  view3 := http_param ('view3');
  if (view3 = 0) view3 := '';
  tlogy := http_param ('tlogy');

  if (0 = sas or 0 = inf or 0 = tlogy)
    {
      declare selected_inf, selected_sas, selected_view3, sel_c_term, sel_s_term  varchar;

     again:

      selected_inf   := cast (xpath_eval ('/query/@inference', tree) as varchar);
      selected_sas   := cast (xpath_eval ('/query/@same-as',   tree) as varchar);
      selected_view3 := cast (xpath_eval ('/query/@view3',     tree) as varchar);
      sel_c_term     := cast (xpath_eval ('/query/@c-term',    tree) as varchar);
      sel_s_term     := cast (xpath_eval ('/query/@s-term',    tree) as varchar);

      http (' <div id="opts_ctr">
           <div id="opts" class="dlg">
             <div class="title"><h2>Options</h2></div>
             <form action="/fct/facet.vsp?cmd=set_inf&sid='); http_value ( sid ); http ('" method=post>
	       <div class="fm_sect">
                 <h3>Inference</h3>
                 <label class="left_txt" for="opt_inference">Rule</label>
                 <select name="inference">
	           <option value="">none</option>
	           '); for select RS_NAME from SYS_RDF_SCHEMA do { http ('
		     <option value="'); http_value ( RS_NAME ); http ('"
	                     '); http_value ( case when selected_inf = RS_NAME then 'selected' else '' end ); http ('>
                       '); http_value ( RS_NAME ); http ('
                     </option>
		   '); } http ('
	         </select>
                 <br>
                 <input type="checkbox"
                        name="same-as"
                        value="yes"
                        id="same-as" '); http_value ( case when selected_sas = 'yes' then 'checked="true"' end  ); http ('>
                 <label class="rt_ckb" for="same-as">Same As</label><br>
               </div>
               <div class="fm_sect">
	         <h3>User Interface</h3>
	         <label class="left_txt" for="tlogy">Terminology</label>
                 <select name="tlogy">
	           <option value="eav" '); http_value ( case when sel_s_term = 'e' then 'selected="true"' else '' end ); http ('>Entity-Attribute-Value</option>
	           <option value="spo" '); http_value ( case when sel_s_term = 's' then 'selected="true"' else '' end ); http ('>Subject-Predicate-Object</option>
	       	 </select><br/>
<!--
                 <input type="checkbox"
                        name="view3"
                        value="yes"
                        id="view3" '); http_value ( case when selected_view3 = 'yes' then 'checked="true"' end  ); http ('>
                 <label class="rt_ckb" for="view3">Show Values, Types, Properties simultaneously</label><br> -->
               </div>
<!--               <div class="fm_sect">
                 <h3>Limits</h3>
                 <label class="left_txt" for="to_val">Limit time used to</label>
                 <input type="text" class="num" name="to_val" id="to_val" size="8"/> ms<br/>
                 <div class="ctl_expln">Current server-wide limits are: XX soft, YY hard</div>
               </div> -->
               <div class="btn_bar"><button onclick="javascript:history.back();">Cancel</button><input type=submit value="Apply"></div>
             </form>
	   </div>
         </div>
       ');
     return;
    }

  if (isstring (sas) and isstring (inf) and isstring (tlogy))
    {

      if (inf <> '' and not exists (select 1 from sys_rdf_schema where rs_name = inf))
	{
	  http ('<div class="err">Incorrect inference context name</div>');
	  inf := 0;
	  goto again;
	}

      c_term := case when 'eav' = tlogy then 'type' else 'class' end;
      s_term := case when 'eav' = tlogy then 'e' else 's' end;

      tree := XMLUpdate (tree,
                         '/query/@inference', inf,
                         '/query/@same-as',   sas,
                         '/query/@view3',     view3,
                         '/query/@s-term',    s_term,
                         '/query/@c-term',    c_term);

      connection_set ('c_term', c_term);
      connection_set ('s_term', s_term);

      update fct_state set fct_state = tree where fct_sid = sid;

      commit work;

      fct_refresh (tree);
    }
}
;

create procedure
fct_open_iri (in tree any, in sid int, in iri varchar)
{
  declare txt, sqls, msg, md, res, res_tree any;

  http (sprintf ('Showing iri %s', iri));
  txt := string_output ();

  http ('select xmlelement ("result", xmlagg (xmlelement ("row", xmlelement ("column", __ro2sq ("c1")), xmlelement ("column", fct_label ("c1", 0, ''facets'')), xmlelement ("column", xmlattributes (fct_lang ("c2") as "xml:lang", fct_dtp ("c2") as "datatype"), __ro2sq ("c2"))))) from (sparql define output:valmode "LONG" ', txt);

  http (sprintf (' %s %s %s select ?c1 ?c2 where { <%s> ?c1 ?c2 } limit 10000) xx',
    	fct_graph_clause (tree),
	fct_inf_clause (tree),
	fct_sas_clause (tree),
	iri), txt);

  sqls:= '00000';

  exec (string_output_string (txt), sqls, msg, vector (), 0, md, res);

  if ('00000' <> sqls)
    signal (sqls, msg);

  txt := string_output ();
  res_tree := xslt (registry_get ('_fct_xslt_') || 'open.xsl', res[0][0], vector ('sid', sid));

  http_value (res_tree, null);
}
;

create procedure
fct_refresh (in tree any)
{
  fct_web (tree);
}
;

create procedure 
fct_set_agg (in tree any, in sid varchar)
{
  declare agg any;
  agg := http_param ('agg');
  tree := xslt (registry_get ('_fct_xslt_') || 'fct_set_agg.xsl', tree, vector ('agg', agg));
  update fct_state set fct_state = tree where fct_sid = sid;
  commit work;
  fct_web (tree);
}
;

create procedure
fct_bold_tags (in s varchar)
{
  declare ret any;

  declare exit handler for sqlstate '*'
    {
      return s;
    };

  if (not isstring (s))
    return s;
  ret := xtree_doc (sprintf ('<span class="srch_xerpt">%s</span>', s));

  return ret;
}
;

create procedure
fct_select_value (in tree any,
		  in sid int,
		  in val varchar,
		  in lang varchar,
		  in dtp varchar,
		  in cond_t varchar)
{
  declare pos int;

--  fct_dbg_msg (sprintf ('fct_select_value: val: %s, lang: %s, dtp: %s, op: %s',
--              cast (val as varchar),
--              cast (lang as varchar),
--              cast (dtp as varchar),
--              cast (cond_t as varchar)));

  pos := fct_view_pos (tree);

  tree := xslt (registry_get ('_fct_xslt_') || 'fct_set_view.xsl',
                tree,
		vector ('pos', pos, 'op', 'cond', 'val', val, 'lang', lang, 'datatype', dtp, 'cond_t', cond_t));

--  if (cond_t = 'eq')
--    {
      tree := xslt (registry_get ('_fct_xslt_') || 'fct_set_view.xsl',
                    tree,
	            vector ('pos', 0, 'op', 'view', 'type', 'list', 'limit', 20, 'offset', 0));
--    }

  update fct_state set fct_state = tree where fct_sid = sid;

  commit work;
  fct_web (tree);
}
;

create procedure
fct_validate_xsd_float (in str varchar)
{
  declare ret varchar;

  ret := regexp_match ('^[-+]?([0-9]+(\.[0-9]*)?|\.[0-9]+)([eE][-+]?[0-9]+)$', str); -- simple case

  if (ret is not null)
  {
    return ret;
  }
  ret := regexp_match ('^"([^\\\D"]|\\.|[-+]?([0-9]+(\.[0-9]*)?|\.[0-9]+)([eE][-+]?[0-9]+)?|INF|-INF|NaN)"\\^\\^(xsd\\:double|xsd\\:float)',str);
  return ret;

}
;

create procedure
fct_validate_xsd_decimal (in str varchar)
{
  return regexp_match ('^"([^\\"]|\\.|[-+]?([0-9]+(\.[0-9]*)?|\.[0-9]+)?)"\\^\\^xsd\\:decimal',str);
}
;

create procedure
fct_validate_xsd_int (in str varchar)
{
  declare ret varchar;

  ret := regexp_match ('^[-+]?[0-9]+$', str); -- simple integers
  if (ret is not null)
  {
    return ret;
  }
  ret := regexp_match ('^"([^\\"]|\\.|[-+]?([0-9]+))"\\^\\^(xsd:int|xsd:integer)$', str);
  return ret;

}
;

create procedure
fct_validate_xsd_date (in str varchar)
{
  return regexp_match ('^"-?[0-9][0-9][0-9][0-9]-[01][0-9]-[0-3][0-9](Z|[-+]?[0-2][0-9]\\:[0-5][0-9])?"\\^\\^xsd\\:date$', str);
}
;

create procedure
fct_validate_xsd_datetime (in str varchar)
{
  declare retval varchar;

  retval := regexp_match ('^"-?[0-9][0-9][0-9][0-9]-[01][0-9]-[0-3][0-9]T[0-2][0-9]\\:[0-5][0-9](Z|[-+]?[0-2][0-9]\\:[0-5][0-9])+"\\^\\^xsd\\:dateTime$', str);
  return retval;
}
;

create procedure
fct_validate_xsd_str (in str varchar) {
  declare retval varchar;

  retval := regexp_match ('^"([^\\"\\'']|.*)"(@([a-zA-Z0-9]+)?)(-[a-zA-Z0-9]+)*$', str);

--  if (retval is null) {
--    retval := sprintf ('''%s''', regexp_replace (str,'["'']','', 1, null));
--  }
  return retval;
}
;

create procedure
fct_validate_cond_input (in str varchar)
{
  declare retval varchar;

  retval := coalesce (fct_validate_xsd_int(str),
                      fct_validate_xsd_float (str),
                      fct_validate_xsd_decimal(str),
                      fct_validate_xsd_datetime(str),
                      fct_validate_xsd_date(str),
                      fct_validate_xsd_str (str));

  return retval;
}
;

create procedure
fct_validate_xsd_float (in str varchar) {
  declare ret varchar;

  ret := regexp_match ('^[-+]?([0-9]+(\.[0-9]*)?|\.[0-9]+)([eE][-+]?[0-9]+)$', str); -- simple case

  if (ret is not null)
  {
    return ret;
  }
  ret := regexp_match ('^"([^\\\D"]|\\.|[-+]?([0-9]+(\.[0-9]*)?|\.[0-9]+)([eE][-+]?[0-9]+)?|INF|-INF|NaN)"\\^\\^(xsd\\:double|xsd\\:float)',str);
  return ret;

}
;

create procedure
fct_validate_xsd_decimal (in str varchar) {
  return regexp_match ('^"([^\\"]|\\.|[-+]?([0-9]+(\.[0-9]*)?|\.[0-9]+)?)"\\^\\^xsd\\:decimal',str);
}
;

create procedure
fct_validate_xsd_int (in str varchar)
{
  declare ret varchar;

  ret := regexp_match ('^[-+]?[0-9]+$', str); -- simple integers
  if (ret is not null)
  {
    return ret;
  }
  ret := regexp_match ('^"([^\\"]|\\.|[-+]?([0-9]+))"\\^\\^(xsd:int|xsd:integer)$', str);
  return ret;

}
;

create procedure
fct_validate_xsd_date (in str varchar) {
  return regexp_match ('^"-?[0-9][0-9][0-9][0-9]-[01][0-9]-[0-3][0-9](Z|[-+]?[0-2][0-9]\\:[0-5][0-9])?"\\^\\^xsd\\:date$', str);
}
;

create procedure
fct_validate_xsd_datetime (in str varchar)
{
  declare retval varchar;

  retval := regexp_match ('^"-?[0-9][0-9][0-9][0-9]-[01][0-9]-[0-3][0-9]T[0-2][0-9]\\:[0-5][0-9](Z|[-+]?[0-2][0-9]\\:[0-5][0-9])+"\\^\\^xsd\\:dateTime$', str);
  return retval;
}
;

create procedure
fct_validate_xsd_str (in str varchar) {
  declare retval varchar;

  retval := regexp_match ('^"([^\\"\\'']|.*)"(@([a-zA-Z0-9]+)?)(-[a-zA-Z0-9]+)*$', str);

--  if (retval is null) {
--    retval := sprintf ('''%s''', regexp_replace (str,'["'']','', 1, null));
--  }
  return retval;
}
;

create procedure
fct_validate_cond_input (in str varchar)
{
  declare retval varchar;

  retval := coalesce (fct_validate_xsd_int(str),
                      fct_validate_xsd_float (str),
                      fct_validate_xsd_decimal(str),
                      fct_validate_xsd_datetime(str),
                      fct_validate_xsd_date(str),
                      fct_validate_xsd_str (str));

  return retval;
}
;

create procedure
fct_set_cond_range (in tree any,
                    in sid int,
                    in lang varchar,
                    in dtp varchar,
                    in lo varchar,
                    in hi varchar,
                    in neg varchar)
{
  declare pos int;

  pos := fct_view_pos (tree);

--  lo := fct_validate_cond_input (lo);
--  hi := fct_validate_cond_input (hi);

--  fct_dbg_msg (sprintf ('fct_set_cond_range: %s, %s', lo, hi));

  if (lo is null and hi is null)
  {
    fct_web (tree);
    return;
  }
  else
  {
  tree := xslt (registry_get ('_fct_xslt_') || 'fct_set_view.xsl',
                tree,
		vector ('pos', pos,
                        'op', 'cond-range',
                        'hi', hi,
                        'lo', lo,
                        'neg', neg,
                        'lang', lang,
                        'datatype', dtp));

  tree := xslt (registry_get ('_fct_xslt_') || 'fct_set_view.xsl',
                tree,
                vector ('pos', 0, 'op', 'view', 'type', 'list', 'limit', 20, 'offset', 0));

  update fct_state set fct_state = tree where fct_sid = sid;

  commit work;
  }

  fct_web (tree);
}
;

create procedure
fct_set_cond (in tree any,
              in sid int,
              in cond_t varchar,
              in lang varchar,
              in dtp varchar,
              in val varchar,
              in neg varchar)
{
  declare pos int;

  pos := fct_view_pos (tree);

  tree := xslt (registry_get ('_fct_xslt_') || 'fct_set_view.xsl',
                tree,
                vector ('pos', pos,
                        'op','cond',
                        'cond_t', cond_t,
                        'neg', neg,
                        'val', val,
                        'lang', lang,
                        'datatype', dtp));

  tree := xslt (registry_get ('_fct_xslt_') || 'fct_set_view.xsl',
                tree,
                vector ('pos', 0, 'op', 'view', 'type', 'list', 'limit', 20, 'offset', 0));

  update fct_state set fct_state = tree where fct_sid = sid;

  commit work;

  fct_web (tree);
}
;

create procedure
fct_set_cond_in (in tree any,
                 in sid int,
                 in neg varchar,
                 in parms varchar)
{
  if (0 = parms or '' = parms) {
    fct_dbg_msg ('fct_set_cond_in: no params');
    return;
  }

  fct_dbg_msg (sprintf ('fct_set_cond_in: got params: %s', parms));

  declare parm_tree any;
  parm_tree := xtree_doc (parms);

  declare pos int;
  pos := fct_view_pos (tree);

  tree := xslt (registry_get ('_fct_xslt_') || 'fct_set_view.xsl',
                tree,
                vector ('pos', pos,
                        'op','cond',
                        'cond_t', 'in',
                        'neg', neg,
                        'parms', parm_tree));

  tree := xslt (registry_get ('_fct_xslt_') || 'fct_set_view.xsl',
                tree,
                vector ('pos', 0, 'op', 'view', 'type', 'list', 'limit', 20, 'offset', 0));

  update fct_state set fct_state = tree where fct_sid = sid;

  commit work;

  fct_web (tree);
}
;

create procedure
fct_set_cond_near (in tree any,
                   in sid int,
                   in lat varchar,
                   in lon varchar,
                   in dist varchar,
                   in acquire varchar,
                   in prop varchar)
{
  fct_dbg_msg (sprintf ('fct_set_cond_near: lat:%s, lon:%s, d:%s, acquire:%s',
                        cast (lat as varchar),
                        cast (lon as varchar),
                        dist,
                        cast (acquire as varchar)));

  declare pos int;
  pos := fct_view_pos (tree);

  declare acq varchar;

  tree := xslt (registry_get ('_fct_xslt_') || 'fct_set_view.xsl',
                tree,
                vector ('pos', pos,
                        'op','cond',
                        'cond_t', 'near',
                        'lat', lat,
                        'lon', lon,
                        'loc_acq', acquire,
                        'd', dist));

  tree := xslt (registry_get ('_fct_xslt_') || 'fct_set_view.xsl',
                tree,
                vector ('pos', 0,
                        'op', 'view',
                        'type', 'geo',
                        'limit', 20,
                        'offset', 0,
                        'location-prop', prop));

  update fct_state set fct_state = tree where fct_sid = sid;

  commit work;

  fct_web (tree);
}
;

create procedure
fct_set_loc (in tree any,
             in sid int,
             in cno int)
{
  declare lon, lat float;
  declare acc int;

  lon := http_param ('lon');
  lat := http_param ('lat');

  fct_dbg_msg (sprintf ('fct_set_loc: cno:%d, lon:%s, lat:%s', cno, lon, lat));

  if (0 = lon or 0 = lat) {
    http_request_status ('HTTP/1.1 400 Bad request');
    http('FCT002: Missing location data\n');
    return;
  }

  tree := xslt (registry_get ('_fct_xslt_') || 'fct_set_loc.xsl',
                tree,
                vector ('cno', cno,
                        'lat', lat,
                        'lon', lon));

  tree := xslt (registry_get ('_fct_xslt_') || 'fct_set_view.xsl',
                tree,
                vector ('pos', 0,
                        'op', 'view',
                        'type', 'geo',
                        'limit', 20,
                        'offset', 0));

  update fct_state set fct_state = tree where fct_sid = sid;

  commit work;

  fct_web (tree);
}
;

create procedure
fct_gen_opensearch_link ()
{
  declare uriqa_str varchar;
  uriqa_str := cfg_item_value( virtuoso_ini_path(), 'URIQA','DefaultHost');

  if (uriqa_str is null)
    {
      if (server_http_port () <> '80')
        uriqa_str := 'localhost:'||server_http_port ();
      else
        uriqa_str := 'localhost';
    }

  http (sprintf ('<link rel="search" type="application/opensearchdescription+xml" href="opensearchdescription.vsp" title="Search &amp; Find (%s)" />', uriqa_str));
}
;

-- /* main */
create procedure
fct_vsp ()
{
  declare cmd varchar;
  declare tree any;
  declare sid, start_time int;
  declare _to int;
  declare s_for varchar;
  declare xml_d varchar;

  cmd := http_param ('cmd');
  s_for := http_param ('q');
  xml_d := http_param ('qxml');

  if (s_for = 0 or trim (s_for) = '') s_for := null;

  if (0 = cmd and s_for is null and 0 = xml_d)
    {
      fct_new ();
      return;
    }

  sid := http_param ('sid');

  if (0 <> sid) {
    sid := atoi (sid);
  }
  else {
    fct_dbg_msg ('fct_vsp: looking for xml');
    declare xml_d varchar;
    declare r_v any;

    xml_d := http_param ('qxml');
    fct_dbg_msg (sprintf ('fct_vsp: got %s', cast (xml_d as varchar)));

    if (0 <> xml_d) {
      sid := fct_ses_from_xml (xml_d);
      cmd := 'refresh';
    }
  }

  _to := http_param ('timeout');

  if (_to = 0) _to := atoi (registry_get ('fct_timeout_min'));
  else _to := __min (atoi (registry_get ('fct_timeout_max')), atoi(_to));

  connection_set ('timeout', _to);

  if ('new_with_class' = cmd) goto no_ses;

  whenever not found goto no_ses;

  fct_dbg_msg ('fct_vsp: select on sid');

  select fct_state into tree from fct_state where fct_sid = sid;
  fct_dbg_msg ('fct_vsp: got ses');
  goto exec;

 no_ses:
  fct_dbg_msg ('fct_vsp: no ses found');
  declare r_v any;

  if (s_for is not null)
    {
      r_v := fct_create_ses();
      sid := r_v[0];
      tree := r_v[1];

      cmd := 'text';
    }
  else if ('new_with_class' = cmd)
    {
      r_v := fct_create_ses();
      sid := r_v[0];
      tree := r_v[1];
      cmd := 'set_class';
    }
  else
    goto do_new_ses;

exec:;
  declare s_term varchar;

  connection_set ('sid', sid);

  s_term := cast (xpath_eval ('/query/@s-term', tree) as varchar);
  if ('' = s_term) s_term := 'e';
  connection_set ('s_term', s_term);

  declare c_term varchar;
  c_term := cast (xpath_eval ('/query/@c-term', tree) as varchar);
  if ('' = c_term) c_term := 'class';
  connection_set ('c_term', c_term);

  if (registry_get ('fct_log_enable') = 1)
    insert into fct_log (fl_sid, fl_cli_ip, fl_where, fl_state, fl_cmd)
         values (sid, http_client_ip(), 'DISPATCH', tree, cmd);

  commit work;

  start_time := msec_time ();

  fct_dbg_msg (sprintf ('fct_vsp: cmd: %s, sid: %d', cmd, sid));

  if ('text' = cmd)
    {
      if (s_for is null)
	{
	  http (sprintf ('<div class="ses_info">No search criteria</div>'));
	  fct_new ();
	  return;
	}
      fct_set_text (tree, sid, s_for);
    }
  else if ('set_focus' = cmd)
    fct_set_focus (tree, sid, atoi (http_param ('n')));
  else if ('set_view' = cmd)
    fct_set_view (tree,
    		  sid,
		  http_param ('type'),
                  atoi (http_param ('limit')),
		  atoi (http_param ('offset')),
		  http_param ('location-prop'));
  else if ('next' = cmd)
    fct_next (tree, sid, http_param ('offset'), http_param ('limit'));
  else if ('prev' = cmd)
    fct_prev (tree, sid, http_param ('offset'), http_param ('limit'));
  else if ('go_to' = cmd)
    fct_go_to (tree, sid, http_param ('offset'), http_param ('limit'));
  else if ('set_text_property' = cmd)
    fct_set_text_property (tree, sid, http_param ('iri'));
  else if ('open_property' = cmd)
    fct_open_property (tree, sid, http_param ('iri'), 'property', http_param ('exclude'));
  else if ('open_property_of' = cmd)
    fct_open_property (tree, sid, http_param ('iri'), 'property-of', http_param ('exclude'));
  else if ('drop' = cmd)
    fct_drop (tree, sid, atoi (http_param ('n')));
  else if ('drop_cond' = cmd)
    fct_drop_cond (tree, sid, atoi (http_param ('cno')));
  else if ('drop_text_prop' = cmd)
    fct_drop_text_prop (tree, sid);
  else if ('drop_text' = cmd)
    fct_drop_text (tree, sid);
  else if ('set_class' = cmd)
    fct_set_class (tree, sid, http_param ('iri'), http_param ('exclude'));
  else if ('open' = cmd)
    fct_open_iri (tree, sid, http_param ('iri'));
  else if ('refresh' = cmd)
    {
      if (xpath_eval ('/query/*', tree) is null)
        {
	  fct_new ();
	  return;
        }
      fct_refresh (tree);
    }
  else if ('set_inf' = cmd)
    fct_set_inf (tree, sid);
  else if ('set_agg' = cmd)
    fct_set_agg (tree, sid);
  else if ('select_value' = cmd) {
    fct_select_value (tree,
    		      sid,
		      http_param ('iri'),
		      http_param ('lang'),
		      http_param ('datatype'),
		      'eq' --http_param ('op')
		      );
    fct_dbg_msg (sprintf ('select_value: iri=%s, val=%s',
                          cast (http_param('iri') as varchar),
                          cast (http_param('val') as varchar)));
  }
  else if ('cond' = cmd) {
    declare cond_t varchar;
    cond_t := http_param ('cond_t');

    if ('range' = cond_t) {
      fct_set_cond_range (tree,
                          sid,
                          http_param('lang'),
                          http_param('datatype'),
                          http_param('lo'),
                          http_param('hi'),
                          '');
      fct_dbg_msg (sprintf ('range: %s-%s', http_param('lo'), http_param('hi')));
    } else if ('neg_range' = cond_t) {
      fct_set_cond_range (tree,
                          sid,
                          http_param('lang'),
                          http_param('datatype'),
                          http_param('lo'),
                          http_param('hi'),
                          'on');
      fct_dbg_msg (sprintf ('neg-range: %s-%s', http_param('lo'), http_param('hi')));
    } else if ('in' = cond_t) {
      fct_set_cond_in (tree,
                       sid,
                       http_param('neg'),
                       http_param('cond_parms'));
    } else if ('not_in' = cond_t) {
      fct_set_cond_in (tree,
                       sid,
                       1,
                       http_param('cond_parms'));
    } else if ('near' = cond_t) {
      declare i_lat, i_lon, i_loc_trig_sel varchar;

      i_lat := http_param ('lat');
      i_lon := http_param ('lon');
      i_loc_trig_sel := http_param ('loc_trig_sel');

      if (i_lat = 0) i_lat := null;
      if (i_lon = 0) i_lon := null;
      if (i_loc_trig_sel = 0) i_loc_trig_sel := null;

      fct_set_cond_near (tree,
                         sid,
                         i_lat,
                         i_lon,
                         http_param ('dist'),
                         i_loc_trig_sel,
                         http_param ('location-prop'));
    } else {
      declare iri,val any;
      fct_set_cond (tree,
                    sid,
                    cond_t,
                    http_param('lang'),
                    http_param('datatype'),
                    http_param('val'),
                    '');
--      fct_dbg_msg (sprintf ('set_cond: val=%s, cond_t=%s',
--                  cast (http_param('val') as varchar), cast (http_param('cond_t') as varchar)));
    }
  }
  else if ('save' = cmd)
    fct_save (tree,
	      sid,
              http_param ('title'),
              http_param ('desc'));
  else if ('save_init' = cmd)
    fct_save_init (tree, sid);
  else if ('featured' = cmd)
    fct_featured (tree, sid);
  else if ('set_loc' = cmd)
    fct_set_loc (tree, sid, cast (http_param('cno') as int));
  else
    {
      http_request_status ('HTTP/1.1 400 Bad request');
      http ('FCT001: Unrecognized command\n');
    }

  declare _state any;

  select fct_state into _state from fct_state where fct_sid = sid;

  if (registry_get ('fct_log_enable') = 1)
    insert into fct_log (fl_sid, fl_cli_ip, fl_where, fl_state, fl_cmd, fl_msec)
         values (sid, http_client_ip(), 'RETURN', _state, cmd, msec_time () - start_time);

  commit work;

  return;

 do_new_ses:
  http (sprintf ('<div class="ses_info">Session id %d lost. New search started</div>', sid));
  fct_new ();
}
;

create procedure fct_virt_info ()
{
  http ('<a href="http://www.openlinksw.com/virtuoso/">OpenLink Virtuoso</a> version ');
  http (sys_stat ('st_dbms_ver'));
  http (', on ');
  http (sys_stat ('st_build_opsys_id')); http (sprintf (' (%s), ', host_id ()));
  http (case when sys_stat ('cl_run_local_only') = 1 then 'Standard Edition' else 'Cluster Edition' end);
  http (case when sys_stat ('cl_run_local_only') = 0 then sprintf ('(%d server processes)', sys_stat ('cl_n_hosts')) else '' end);
}
;

--  page header

create procedure fct_page_head ()
{
  http ('<div id="hd_l">
    <h1 id="logo">
        <a href="/fct/facet.vsp">
	   <img src="/fct/images/openlink_site_logo.png" alt="OpenLink Software"/>
        </a>
    </h1>
    <div id="homelink"></div>
  </div> <!-- hd_l -->
  <div id="hd_r">
    <div class="addthis_toolbox addthis_default_style">
      <a class="addthis_button_compact"></a>
      <a class="addthis_button_preferred_1"></a>
      <a class="addthis_button_preferred_2"></a>
      <a class="addthis_button_preferred_3"></a>
      <a class="addthis_button_preferred_4"></a>
      <a class="addthis_button_google_plusone"></a>
    </div>
  </div> <!-- hd_r -->');
}
;

create procedure fct_desc_page_head ()
{
  http ('<div id="hd_l">
    <h1 id="logo">
        <a href="/fct/facet.vsp">
	   <img src="/fct/images/openlink_site_logo.png" alt="OpenLink Software"/>
        </a>
    </h1>
    <div id="homelink"></div>
  </div> <!-- hd_l -->
  <div id="hd_r"></div> <!-- hd_r -->');
}
;
