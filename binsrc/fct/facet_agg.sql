--
--  $Id$
--
--  Aggregate support
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
--


create procedure
fct_agg_view (in tree any, in agg varchar, in this_s int, in txt any, in pre any, in post any, in full_tree any, in plain integer := 0)
{
  declare mode varchar;

  mode := fct_get_mode (tree, './@type');

  if ('list' = mode or 'propval-list' = mode)
    {
      http (sprintf ('select %s ( ?s%d ) as ?c1 ', agg, this_s), pre);
    }
  else if ('entities-list' = mode)
    {
      http (sprintf ('select %s ( ?s%d ) as ?c1 ', agg, this_s), pre);
    }
}
;

create procedure
fct_agg_text_1 (in tree any,
    	    in agg varchar,	
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
      fct_agg_text (c[i], agg, this_s, max_s, txt, pre, post, full_tree, plain);
    }
}
;

create procedure
fct_agg_text (in tree any,
	  in agg varchar,
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
   
  if ('class' = n)
    {
      declare ciri varchar;
      ciri := fct_curie (cast (xpath_eval ('./@iri', tree) as varchar));

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
      fct_agg_text_1 (tree, agg, 1, max_s, txt, pre, post, full_tree, plain);
      return;
    }

  if (n = 'text')
    {
      declare prop, sc_opt, v, txs_qr varchar;
      declare txs_arr any;
      declare wlimit int;

      v := cast (xpath_eval ('//view/@type', tree) as varchar);
      prop := cast (xpath_eval ('./@property', tree, 1) as varchar);

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
      http (sprintf (' ?s%d %s ?o%d . ?o%d bif:contains  ''%s'' %s .', this_s, prop, this_s, this_s, txs_qr, sc_opt), txt);
    }

  if ('property' = n)
    {
      declare new_s int;
      declare piri varchar;
      declare flt_expr varchar;

      max_s := max_s + 1;
      new_s := max_s;

      piri := fct_curie (cast (xpath_eval ('./@iri', tree, 1) as varchar));

      if (cast (xpath_eval ('./@exclude', tree) as varchar) = 'yes')
	{
	  http (sprintf (' filter not exists { ?s%d <%s> ?v%d } .', this_s, piri, new_s), txt);
	  max_s := max_s - 1;
	  new_s := max_s;
	  fct_agg_text_1 (tree, agg, new_s, max_s, txt, pre, post, full_tree, plain);
	  return;
	}
      else	
	{
	  http (sprintf (' ?s%d <%s> ?s%d .', this_s, piri, new_s), txt);
	  fct_agg_text_1 (tree, agg, new_s, max_s, txt, pre, post, full_tree, plain);
	}
    }

  if ('property-of' = n)
    {
      declare new_s int;
      max_s := max_s + 1;
      new_s := max_s;
      http (sprintf (' ?s%d <%s> ?s%d .', new_s, fct_curie (cast (xpath_eval ('./@iri', tree, 1) as varchar)), this_s), txt);
      fct_agg_text_1 (tree, agg, new_s, max_s, txt, pre, post, full_tree, plain);
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
      http (sprintf (' filter (datatype (?s%d) IN (xsd:double, xsd:int, xsd:numeric, xsd:float, xsd:integer, xsd:decimal)) . ', this_s), txt);
      fct_agg_view (tree, agg, this_s, txt, pre, post, full_tree, plain);
    }
}
;

create procedure
fct_agg_query (in tree any, in agg varchar := 'SUM', in plain integer := 0)
{
  declare s, add_graph int;
  declare txt, pre, post any;

  txt := string_output ();
  pre := string_output ();
  post := string_output ();

  s := 0;
  fct_agg_text (xpath_eval ('//query', tree), agg, 0, s, txt, pre, post, tree, plain);
  http (' where {', pre);
  http (txt, pre);
  http (' }', pre);
  http (post, pre);
  return string_output_string (pre);
}
;
