--
--  $Id$
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2014 OpenLink Software
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

-- Each summary is initially an array of 29 with s_rank, o_fill, o1, p1, sc1, o2, p2, sc2
-- and so on.  After so many entries, more are not added.


create procedure s_sum_init (inout env any)
{
  env := make_array (30, 'any');
}
;

create procedure s_sum_acc (inout env any, in s_rank double precision, in p iri_id, in o any, in sc int)
{
  declare fill int;
  fill := env[1];
  if (fill = 0)
    env[0] := s_rank;
  else if (fill >= 25)
    return;
  env[2] := env[2] + sc;
  env[fill + 3] := o;
  env[fill + 4] := p;
  env[fill + 5] := sc;
  env[1] := fill + 3;
}
;


create procedure s_sum_fin (inout env any)
{
  return env;
}
;


create aggregate DB.DBA.S_SUM (in s_rank double precision, in p iri_id, in o any, in sc int) returns any from
  s_sum_init, s_sum_acc, s_sum_fin;

grant execute on DB.DBA.S_SUM_INIT to "SPARQL";
grant execute on DB.DBA.S_SUM_ACC to "SPARQL";
grant execute on DB.DBA.S_SUM_FIN to "SPARQL";
grant execute on DB.DBA.S_SUM to "SPARQL";

create procedure sum_rank (inout arr any)
{
  if (not isvector (arr) or length (arr) < 3)
    return 0; 
  return  rnk_scale (arr[0]) + cast (arr[2] as real) / (arr[1] / 3);
}
;

grant execute on DB.DBA.SUM_RANK to "SPARQL";

create procedure sum_o_p_score (inout o any, inout p any)
{
  declare p_weight any;
  declare lng_m, pm int;
  declare lng_pref any;
  lng_pref := connection_get ('lang');
  p_weight := connection_get ('p_weight');
  if (lng_pref is not null and is_rdf_box (o) and rdf_box_lang (o) = lng_pref)
    lng_m := 3;
  else
    lng_m := 0;
  if (p_weight is null)
    return lng_m;
  pm := dict_get (p_weight, p);
  if (pm)
    return lng_m + pm;
  return lng_m;
}
;

create procedure sum_result (inout final any, 
                             inout res any, 
			     inout text_exp any, 
			     inout s varchar, 
			     inout start_inx int, 
			     inout end_inx int, 
			     inout s_rank real, 
			     inout lbl any,
			     inout g any)
{
  declare sorted, inx, tot, exc, elt, tsum any;
 tsum := 0;
 tot := '';
 sorted := subseq (res, start_inx, end_inx);
  for (inx := 0; inx < length (sorted); inx := inx + 3)
    {
      tsum := tsum + sorted[inx + 2];
      sorted[inx + 2] := sum_o_p_score (sorted[inx], sorted[inx + 1]);
    }
  --dbg_obj_print ('sorted = ', sorted);
  gvector_sort (sorted, 3, 2, 0);
  for (inx := 0; inx < length (sorted); inx := inx + 3)
  tot	 := tot || cast (rdf_box_data (sorted[inx]) as varchar);
 exc := fct_bold_tags (search_excerpt (text_exp, tot));
-- dbg_obj_print (' summaries of ', tot, ' ', lbl, ' ', exc);
 elt := xmlelement ('row',
		    xmlelement ('column', xmlattributes ('trank' as "datatype"), cast (cast (tsum as real) / ((end_inx - start_inx) / 3) as varchar)),
		    xmlelement ('column', xmlattributes ('erank' as "datatype"), cast (s_rank as varchar)),
 		    xmlelement ('column', xmlattributes ('url' as "datatype", fct_short_form (s) as "shortform"), s),
		    xmlelement ('column', lbl),
		    xmlelement ('column', xmlattributes ('url' as "datatype", fct_short_form (g) as "shortform"), g),
 		    xmlelement ('column', exc)
		    );
  xte_nodebld_xmlagg_acc (final, elt);
}
;


create procedure sum_final (inout x any)
{
  return xml_tree_doc (xte_nodebld_final_root (x));
}
;

create procedure s_sum_page_s (in rows any, in text_exp varchar)
{
--  dbg_obj_print (rows);
  /* fill the os and translate the iris and make sums */
  declare inx, s, g, prev_s, prev_fill, fill, inx2, n, s_rank, lbl any;
  declare dp, os, res, final any;
  declare lng_pref any;
  lng_pref := connection_get ('langs');
  xte_nodebld_init (final);
  n := 0;
  for (inx := 0; inx < length (rows); inx := inx + 1)
    {
      os := aref (rows, inx, 1);
      for (inx2 := 3; inx2 < os[1] + 3; inx2 := inx2 + 3)
        n := n + 1;
    }
  n := 3 * n;
  --dbg_obj_print ('result length ', n);
  res := make_array (n, 'any');
  fill := 0;
  for (inx := 0; inx < length (rows); inx := inx + 1)
    {
      os := aref (rows, inx, 1);
      s_rank := rnk_scale (os[0]);
      s := ID_TO_IRI (rows[inx][0]);
      lbl := FCT_LABEL_S (rows[inx][0], 0, 'facets', lng_pref);
      g := ID_TO_IRI (rows[inx][2]);
      prev_fill := fill;
      for (inx2 := 3; inx2 < os[1] + 3; inx2 := inx2 + 3)
        {
	  res[fill] := __RO2SQ (os[inx2]);
	  res[fill + 1] := os[inx2 + 1];
	  res[fill + 2] := os[inx2 + 2];
	  fill := fill + 3;
	}
      sum_result (final, res, text_exp, s, prev_fill, fill, s_rank, lbl, g);
    }
  return sum_final (final);
}
;

create procedure s_sum_page_c (in rows any, in text_exp varchar)
{
  /* fill the os and translate the iris and make sums */
  declare inx, s, g, prev_s, prev_fill, fill, inx2, n, s_rank, lbl any;
  declare dp, os, so, res, final any;
  declare lng_pref any;
  lng_pref := connection_get ('langs');
  dp := dpipe (1, 'ID_TO_IRI', '__RO2SQ', 'FCT_LABEL_L', 'ID_TO_IRI');
  xte_nodebld_init (final);
  for (inx := 0; inx < length (rows); inx := inx + 1)
    {
      os := aref (rows, inx, 1);
      for (inx2 := 3; inx2 < os[1] + 3; inx2 := inx2 + 3)
        dpipe_input (dp, aref (rows, inx, 0),os[inx2], vector (aref (rows, inx, 0), 0, 'facets', lng_pref), aref (rows, inx, 2));
    }
  n := 3 * dpipe_count (dp);
  --dbg_obj_print ('result length ', n);
  res := make_array (n, 'any');
  fill := 0;
  for (inx := 0; inx < length (rows); inx := inx + 1)
    {
      os := aref (rows, inx, 1);
      s_rank := rnk_scale (os[0]);
      prev_fill := fill;
      for (inx2 := 3; inx2 < os[1] + 3; inx2 := inx2 + 3)
        {
	  so := dpipe_next (dp, 0);
	  --dbg_obj_print ('res ', fill, so);
	  s := so[0];
	  g := so[3];
	  res[fill] := so[1];
	  res[fill + 1] := os[inx2 + 1];
	  res[fill + 2] := os[inx2 + 2];
	  lbl := so[2];
	  fill := fill + 3;
	}
      sum_result (final, res, text_exp, s, prev_fill, fill, s_rank, lbl, g);
    }
  dpipe_next (dp, 1);
  --sum_result (final, res, text_exp, s, prev_fill, fill, s_rank);
  return sum_final (final);
}
;

create procedure s_sum_page (in rows any, in text_exp varchar)
{
  declare i int;
  if (__tag (text_exp) = 193)
    foreach (any v in text_exp) do
      {
	if (iswidestring (v))
	  {
	    v := charset_recode (v, '_WIDE_', 'UTF-8');
	    text_exp [i] := v;
	  }
	i := i + 1;
      }

  if (sys_stat ('cl_run_local_only'))
    return s_sum_page_s (rows, text_exp);
  else
    return s_sum_page_c (rows, text_exp);
}
;

grant execute on s_sum_page to "SPARQL"
;

create procedure sum_tst (in text_exp varchar, in text_words varchar := null)
{
  declare res any;
  if  (text_words is null)
    text_words := vector (text_exp);
  res := (sparql select (<sql:vector_agg> (<bif:vector> (?c1, ?sm))) as ?res
    where {
        { select (<SHORT_OR_LONG::>(?s1)) as ?c1,
          (<sql:S_SUM> (
            <SHORT_OR_LONG::IRI_RANK> (?s1),
            <SHORT_OR_LONG::>(?s1textp),
            <SHORT_OR_LONG::>(?o1),
            ?sc ) ) as ?sm
          where { ?s1 ?s1textp ?o1 . ?o1 bif:contains  "NEW AND YORK"  option (score ?sc) . }
          order by desc (<sql:sum_rank> ((<sql:S_SUM> (
            <SHORT_OR_LONG::IRI_RANK> (?s1),
            <SHORT_OR_LONG::>(?s1textp),
            <SHORT_OR_LONG::>(?o1),
            ?sc ) ) ) ) limit 20 } } );
  --dbg_obj_print (res);
  res := s_sum_page (res, text_words);
  return res;
}
;

create procedure sum_tst_1 (in text_exp varchar, in text_words varchar := null)
{
  declare res any;
  if  (text_words is null)
    text_words := vector (text_exp);
  res := (select vector_agg (vector ("c1", "sm")) from (
    sparql
    select (<SHORT_OR_LONG::>(?s1)) as ?c1, (<sql:S_SUM> (
	<SHORT_OR_LONG::IRI_RANK> (?s1),
	<SHORT_OR_LONG::>(?s1textp),
	<SHORT_OR_LONG::>(?o1),
	?sc ) ) as ?sm
    where { ?s1 ?s1textp ?o1 . ?o1 bif:contains  "NEW AND YORK"  option (score ?sc) }
    order by desc (<sql:sum_rank> ((<sql:S_SUM> (
	    <SHORT_OR_LONG::IRI_RANK> (?s1),
	    <SHORT_OR_LONG::>(?s1textp),
	    <SHORT_OR_LONG::>(?o1),
	    ?sc ) ) ) )
    limit 20 ) s option (quietcast)
    );
  --dbg_obj_print (res);
  res := s_sum_page (res, text_words);
  return res;
}
;

--create procedure sum_tst_2 (in text_exp varchar, in text_words varchar := null)
--{
--  declare res any;
--  if  (text_words is null)
--    text_words := vector (text_exp);
--  res := (select vector_agg (vector (s, sm)) from (
--   select top 20 s, s_sum (iri_rank (s), p, o, score)  as sm
--   from rdf_obj, rdf_ft, rdf_quad q1
--   where contains (ro_flags, text_exp) and rf_id = ro_id and q1.o = rf_o group by s
--   order by sum_rank (sm) option (quietcast) ) s option (quietcast)
--);
  --dbg_obj_print (res);
--  res := s_sum_page (res, text_words);
--  return res;
--}
--;

--  sum_tst ('oori');

--
-- sparql
-- select (<SHORT_OR_LONG::>(?s1)) as ?c1, (<sql:S_SUM> (
--    <SHORT_OR_LONG::IRI_RANK> (?s1),
--    <SHORT_OR_LONG::>(?s1textp),
--    <SHORT_OR_LONG::>(?o1),
--    ?sc ) ) as ?sm
-- where { ?s1 ?s1textp ?o1 . ?o1 bif:contains  "NEW AND YORK"  option (score ?sc)  . }
-- order by desc (<sql:sum_rank> ((<sql:S_SUM> (
--        <SHORT_OR_LONG::IRI_RANK> (?s1),
--        <SHORT_OR_LONG::>(?s1textp),
--        <SHORT_OR_LONG::>(?o1),
--        ?sc ) ) ) )
-- limit 20;

-- explain ('sparql     select ?s1 as ?c1, (<SHORT_OR_LONG::s_sum> (<SHORT_OR_LONG::IRI_RANK> (?s1), ?s1textp, ?o1, ?sc)) as ?sm where { ?s1 ?s1textp ?o1 . ?o1 bif:contains  ''NEW AND YORK''  option (score ?sc)  . } group by ?s1 order by desc (<SHORT_OR_LONG::sum_rank> (<SHORT_OR_LONG::s_sum> (<SHORT_OR_LONG::IRI_RANK> (?s1), ?s1textp, ?o1, ?sc)))  limit 20');

