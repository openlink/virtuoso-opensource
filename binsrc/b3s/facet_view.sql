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

--set ignore_params=on;
-- Facets web page

registry_set ('_fct_xslt_', case when registry_get('_fct_url_') = 0 then 'file://fct/' else registry_get('_fct_url_') end);

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
  return null;
}
;

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
      http (sprintf ('List of distinct %s%d with counts', connection_get ('s_term'), pos), txt);
    }
  if ('properties' = mode)
    {
      http (sprintf ('Properties of %s%d', connection_get ('s_term'), pos), txt);
    }
  if ('properties-in' = mode)
    {
      http (sprintf ('showing %s where %s%d is the value',
      	   	     connection_get ('c_term'),
                     connection_get ('s_term'),
		     pos), txt);
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
      http (sprintf ('Displaying types of %s%d', connection_get ('s_term'), pos), txt);
    }
  if ('text' = mode or 'text-d' = mode)
    {
      http (sprintf ('Displaying values and text summaries associated with pattern %s%d', 
	             connection_get ('s_term'), pos), txt);
    }
--  if (offs)
--    http (sprintf ('  values %d - %d', 1 + offs, lim), txt);
  http (' where:</h3>', txt);
}
;

create procedure
fct_var_tag (in this_s int, in ctx int)
{
  if (ctx)
    return sprintf ('<a href="/fct/facet.vsp?cmd=set_focus&sid=%d&n=%d" title="Focus on %s%d">%s%d</a>',
                    connection_get ('sid'),
		    this_s,
		    connection_get ('s_term'),
		    this_s,
		    connection_get ('s_term'),
		    this_s);
  else
    return sprintf ('%s%d', connection_get ('s_term'), this_s);
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
  for (i := 0; i < length (c); i := i + 1)
    {
      fct_query_info (c[i], this_s, max_s, level + 1, ctx, txt, cno);
    }
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

  http (fct_space (2 * level), txt);

  if ('class' = n)
    {
      if (cast (xpath_eval ('./@exclude', tree) as varchar) = 'yes')
	{
	  http (sprintf ('%s  is not a <span class="iri">%s</span> . <a class="qry_nfo_cmd" href="/fct/facet.vsp?sid=%d&cmd=drop_cond&cno=%d">Drop</a>',
		fct_var_tag (this_s, ctx),
		fct_short_form (cast (xpath_eval ('./@iri', tree) as varchar)),
		connection_get ('sid'),
		cno),
	      txt);
	}
      else
	{
	  http (sprintf ('%s is a <span class="iri">%s</span> . <a class="qry_nfo_cmd" href="/fct/facet.vsp?sid=%d&cmd=drop_cond&cno=%d">Drop</a>',
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
        http (sprintf (' %s has <span class="iri"><a href="/fct/facet.vsp?sid=%d&cmd=drop_text_prop">%s</a></span> containing text <span class="value">"%s"</span>. ', 
                     fct_var_tag (this_s, ctx),
                       connection_get ('sid'),
                       fct_short_form (prop),
                       cast (tree as varchar)), txt);
      else
        http(sprintf (' %s has <a class="qry_info_cmd" href="/fct/facet.vsp?sid=%d&cmd=set_view&type=text-properties&limit=20&offset=0&cno=%d">any property</a> containing text <span class="value">"%s"</span>. ', 
                      fct_var_tag (this_s, ctx), 
                      connection_get('sid'), 
                      cno,
                      cast (tree as varchar)), txt);

    }
  else if ('property' = n)
    {
      declare new_s int;
      max_s := max_s + 1;
      new_s := max_s;
      if (cast (xpath_eval ('./@exclude', tree) as varchar) = 'yes')
	{
	  http (sprintf (' %s does not have property <span class="iri">%s</span> %s . ',
                     fct_var_tag (this_s, ctx),
		     fct_short_form (cast (xpath_eval ('./@iri', tree, 1) as varchar)), 
                     fct_var_tag (new_s, ctx)), txt);
	}
      else
	{
	  http (sprintf (' %s <span class="iri">%s</span> %s . ',
                     fct_var_tag (this_s, ctx),
		     fct_short_form (cast (xpath_eval ('./@iri', tree, 1) as varchar)), 
                     fct_var_tag (new_s, ctx)), txt);
	}
      if (ctx)
	http (sprintf ('<a class="qry_nfo_cmd" href="/fct/facet.vsp?sid=%d&cmd=drop&n=%d">Drop %s%d</a> ',
	               connection_get ('sid'), new_s, connection_get('s_term'), new_s), txt);
      fct_query_info_1 (tree, new_s, max_s, level, ctx, txt, cno);
    }
  else if ('property-of' = n)
    {
      declare new_s int;
      max_s := max_s + 1;
      new_s := max_s;
      http (sprintf (' %s <span class="iri">%s</span> %s . ',
                     fct_var_tag (new_s, ctx),
		     fct_short_form (cast (xpath_eval ('./@iri', tree, 1) as varchar), 1),
		     fct_var_tag (this_s, ctx)),
            txt);

      if (ctx)
	http (sprintf ('<a class="qry_nfo_cmd" href="/fct/facet.vsp?sid=%d&cmd=drop&n=%d">Drop %s%d</a> ',
	connection_get ('sid'),
	new_s, connection_get ('s_term'), new_s), txt);
      fct_query_info_1 (tree, new_s, max_s, ctx, level, txt, cno);
    }
  if ('value' = n)
    {
      http (sprintf (' %s %s %V . <a class="qry_nfo_cmd" href="/fct/facet.vsp?sid=%d&cmd=drop_cond&cno=%d">Drop</a>',
                     fct_var_tag (this_s, ctx),
		     cast (xpath_eval ('./@op', tree) as varchar),
		     fct_literal (tree),
		     connection_get ('sid'),
		     cno),
            txt);
    }
  if (ctx)
    http ('<br/>', txt);
  else
    http ('\n', txt);
}
;

VHOST_REMOVE (lpath=>'/fct');
VHOST_DEFINE (lpath=>'/fct',
    	ppath=>case when registry_get('_fct_path_') = 0 then '/fct/' else registry_get('_fct_path_') end, 
	is_dav=>atoi (case when registry_get('_fct_dav_') = 0 then '0' else registry_get('_fct_dav_') end),
    	vsp_user=>'dba', def_page=>'facet.vsp');
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

  fct_query_info (xpath_eval ('/query', tree), 1, max_s, 1, 1, txt, cno);

}
;

create procedure
fct_view_link (in tp varchar, in msg varchar, in txt any)
{
  http (sprintf ('<li><a href="/fct/facet.vsp?cmd=set_view&sid=%d&type=%s&limit=20&offset=0">%s</a></li>',
                 connection_get ('sid'), tp, msg),
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
  http ('<h3>Navigation</h3>', txt);
  http ('<ul class="n1">', txt);

  if ('text-properties' = tp)
    {
      fct_view_link ('text', 'Return to text match list', txt);
      return;
    }

  if ('properties' <> tp)
    fct_view_link ('properties', 'Properties', txt);

  if ('text' = tp and pos = 0)
    fct_view_link ('text-properties', 'Properties containing the text', txt);

  if ('properties-in' <> tp)
    fct_view_link ('properties-in', 'Referencing properties', txt);

  if ('text' <> tp and tp <> 'text-d')
    {
      if (tp <> 'list-count')
	fct_view_link ('list-count', 'Distinct values with counts', txt);
      if (tp <> 'list')
	fct_view_link ('list', 'Show values', txt);
    }

  if ('classes' <> tp)
    if (connection_get('c_term') = 'class') 
	fct_view_link ('classes', 'Classes', txt);
    else 
	fct_view_link ('classes', 'Types', txt);

  if ('geo' <> tp)
    {
      --fct_view_link ('geo', 'Map', txt);
      http (sprintf ('<li><a id="map_link" href="/fct/facet.vsp?cmd=set_view&sid=%d&type=%s&limit=20&offset=0">%s</a>&nbsp;'||
	    		'<select name="map_of" onchange="javascript:link_change(this.value)">'||
	    		'<option value="">Shown items</option>'||
	    		'<option value="any">Any location</option>'||
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
                 connection_get ('sid'), 'geo', 'Map'), txt);
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
  if (vt in ('properties', 'classes', 'properties-in', 'text-properties', 'list', 'list-count'))
    return vt;
-- return 'properties';
  if (vt = 'geo')
    return 'geo';

  return 'default';
}
;

create procedure
fct_view_cmd (in tp varchar)
{
  if ('text-properties' = tp)
    return 'set_text_property';

  if ('properties' = tp)
    return 'open_property';

  if ('properties-in' = tp)
    return 'open_property_of';

  if ('classes' = tp)
    return 'set_class';

  return 'select_value';
}
;

cl_exec ('registry_set (''fct_timeout'', ''0'')');
cl_exec ('registry_set (''fct_timeout_max'', ''20000'')');

create procedure
fct_web (in tree any)
{
  declare sqls, msg, tp varchar;
  declare start_time int;
  declare reply, md, res, qr, qr2, txt any;
  declare timeout int;
 
  timeout := connection_get ('timeout');

  if (not isinteger(timeout)) 
    timeout := atoi(timeout);

  reply := fct_exec (tree, timeout);

  txt := string_output ();

  http ('<div id="top_ctr">', txt);

  fct_top (tree, txt);

  http('<div id="sparql_a_ctr"></div>', txt);

  http ('</div>', txt);

  tp := cast (xpath_eval ('//view/@type', tree) as varchar);

  http_value (xslt (registry_get ('_fct_xslt_') || 'fct_vsp.xsl',
                    reply,
		    vector ('sid',
		            connection_get ('sid'),
     			    'cmd',
			    fct_view_cmd (tp),
			    'type',
			    fct_view_type (tp),
			    'timeout',
			    _min (timeout*2, atoi (registry_get ('fct_timeout_max'))),
			    'query',
			    tree
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
  new_tree := xslt (registry_get ('_fct_xslt_') || 'fct_set_text.xsl', tree, vector ('text', txt, 'prop', iri));
  new_tree := xslt (registry_get ('_fct_xslt_') || 'fct_set_view.xsl', new_tree, vector ('pos', 0, 'type', 'text-d', 'limit', 20, 'op', 'view'));

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
  tree := xslt (registry_get ('_fct_xslt_') || 'fct_set_view.xsl', tree, vector ('pos', pos - 1, 'op', 'close'));

  if (xpath_eval ('//view', tree) is null)
    tree := xslt (registry_get ('_fct_xslt_') || 'fct_set_view.xsl', tree, vector ('pos', 0, 'op', 'view', 'type', 'list', 'limit', 20, 'offset', 0));

  update fct_state set fct_state = tree where fct_sid = sid;
  commit work;

  fct_web (tree);
}
;

create procedure
fct_drop_cond (in tree any, in sid int, in cno int)
{
  tree := xslt (registry_get ('_fct_xslt_') || 'fct_drop_cond.xsl', tree, vector ('cno', cno));

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
fct_next (in tree any, in sid int)
{
  declare tp varchar;
  declare lim, offs int;

  tp   := cast       (xpath_eval ('//view/@type',  tree) as varchar);
  lim  := atoi (cast (xpath_eval ('//view/@limit', tree) as varchar));
  offs := atoi (cast (xpath_eval ('//view/@offset',tree) as varchar));

  fct_set_view  (tree, sid, tp, lim, offs + 20);
}
;

create procedure
fct_prev (in tree any, in sid int)
{
  declare tp varchar;
  declare lim, offs int;

  tp   := cast       (xpath_eval ('//view/@type',  tree) as varchar);
  lim  := atoi (cast (xpath_eval ('//view/@limit', tree) as varchar));
  offs := atoi (cast (xpath_eval ('//view/@offset',tree) as varchar));

  offs := offs - 20;
  if (offs < 0) offs := 0;

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
    tree := xslt (registry_get ('_fct_xslt_') || 'fct_set_view.xsl', tree, 
                  vector ('pos', pos, 
                  'op', 'view', 
                  'type', 'properties', 
                  'limit', 20, 
                  'offset', 0));

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

  tree := xslt (registry_get ('_fct_xslt_') || 'fct_set_view.xsl',
                tree,
                vector ('pos'   , pos,
		        'op'    , 'class',
			'iri'   , iri,
			'type'  , 'list',
			'limit' , 20,
			'offset', 0,
			'exclude', exclude));

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
fct_new ()
{
  declare sid int;
  sid := http_param ('sid');

  if (0 = sid)
    {
      no_ses:
      sid := sequence_next ('fct_seq');
      insert into fct_state (fct_sid, fct_state)
        values (sid, '<query inference="" same-as="" view3="" s-term="" c-term=""/>');
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
      <div class="tab" id="TAB_URILBL">URI Lookup (by Label)</div>
      <div class="tab" id="TAB_URI">URI Lookup</div>
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
      <h2>Entity Search, Find, and Explore</h2>
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
                 name="q"/>
          <input type=submit  value="Search"><br/>
        </div>
      </form>
    </div> <!-- #TAB_PAGE_TXT -->
    <div id="TAB_PAGE_URILBL" class="tab_page" style="display: none">
      <h2>Entity Search, Find, and Explore</h2>
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
      <h2>Entity Search, Find, and Explore</h2>
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
                 <input type="checkbox" 
                        name="view3" 
                        value="yes" 
                        id="view3" '); http_value ( case when selected_view3 = 'yes' then 'checked="true"' end  ); http ('> 
                 <label class="rt_ckb" for="view3">Show Values, Types, Properties simultaneously</label><br>
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
fct_bold_tags (in s varchar)
{
  declare ret any;

  declare exit handler for sqlstate '*'
    {
      return s;
    };

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
		  in op varchar)
{
  declare pos int;

  if (op is null or op = '' or op = 0)
    op := '=';

  pos := fct_view_pos (tree);

  tree := xslt (registry_get ('_fct_xslt_') || 'fct_set_view.xsl',
                tree,
		vector ('pos', pos, 'op', 'value', 'iri', val, 'lang', lang, 'datatype', dtp, 'cmp', op));

  if (op = '=')
    {
    tree := xslt (registry_get ('_fct_xslt_') || 'fct_set_view.xsl',
                  tree,
		  vector ('pos', 0, 'op', 'view', 'type', 'list', 'limit', 20, 'offset', 0));
    }

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

  cmd := http_param ('cmd');
  s_for := http_param ('q');

  if (s_for = 0 or trim (s_for) = '') s_for := null;

  if (0 = cmd and s_for is null)
    {
      fct_new ();
      return;
    }

  sid := http_param ('sid');

  if (0 <> sid) { sid := atoi (sid); }

  _to := http_param ('timeout');

  if (_to = 0) _to := atoi (registry_get ('fct_timeout_min'));
  else _to := _min (atoi (registry_get ('fct_timeout_max')), atoi(_to));

  connection_set ('timeout', _to);

  whenever not found goto no_ses;

  select fct_state into tree from fct_state where fct_sid = sid;
  goto exec;

  no_ses:
  if (s_for is not null) {
    sid := sequence_next ('fct_seq');
      tree := xtree_doc ('<query inference="" same-as="" view3="" s-term="" c-term=""/>');


    insert into fct_state (fct_sid, fct_state)
      values (sid, tree);

    cmd := 'text';
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

  insert into fct_log (fl_sid, fl_cli_ip, fl_where, fl_state, fl_cmd)
         values (sid, http_client_ip(), 'DISPATCH', tree, cmd);
  commit work;

  start_time := msec_time ();

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
    fct_next (tree, sid);
  else if ('prev' = cmd)
    fct_prev (tree, sid);
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
  else if ('select_value' = cmd)
    fct_select_value (tree,
    		      sid,
		      http_param ('iri'),
		      http_param ('lang'),
		      http_param ('datatype'),
		      http_param ('op'));
  else if ('save' = cmd)
    fct_save (tree, 
	      sid,
              http_param ('title'),
              http_param ('desc'));
  else if ('save_init' = cmd)
    fct_save_init (tree, sid);
  else if ('featured' = cmd)
    fct_featured (tree, sid);
  else
    {
      http ('Unrecognized command');
      return;
    }

  declare _state any;

  select fct_state into _state from fct_state where fct_sid = sid;

  insert into fct_log (fl_sid, fl_cli_ip, fl_where, fl_state, fl_cmd, fl_msec)
         values (sid, http_client_ip(), 'RETURN', _state, cmd, msec_time () - start_time);
  commit work;

  return;

  do_new_ses:
  http (sprintf ('<div class="ses_info">Session id %d lost. New search started</div>', sid));
  fct_new ();
}
;
