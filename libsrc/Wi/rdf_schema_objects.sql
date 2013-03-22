--
--  $Id$
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  RDF Schema objects, generator of RDF Views
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
--


--
--TODO: use string session
--

create procedure rdf_view_tbl_opts (in tbls any, in cols any)
{
  declare res any;
  declare inx, len int;
  len := length (tbls);
  if (not isarray (cols) or length (cols) <> len)
    cols := make_array (len, 'any');
  res := make_array (len * 2, 'any');
  inx := 0;
  foreach (varchar t in tbls) do
    {
      declare col_cnt int;
      col_cnt := (select count(*) from TABLE_COLS where "TABLE" = t and "COLUMN" <> '_IDN');
      res [inx * 2] := t;
      if (isarray (cols[inx]) and length (cols[inx]) = 2 and isarray (cols[inx][1]) and length (cols[inx][1]) = col_cnt)
        res [(inx * 2) + 1] := cols [inx];
      else
	{
	  declare newcols, i any;
	  newcols := make_array (col_cnt, 'any');
          i := 0;
	  for select "COLUMN", COL_DTP from TABLE_COLS where "TABLE" = t and "COLUMN" <> '_IDN' order by COL_ID do
	    {
	      if (COL_DTP <> 131)
	        newcols [i] := vector (0, null);
              else
		newcols [i] := vector ('application/octet-stream', null);
	      i := i + 1;
	    }
          res [(inx * 2) + 1] := vector (null, newcols);
	}
      inx := inx + 1;
    }
  return res;
}
;

create procedure rdf_view_tbl_pk_cols (inout tbls any, out pkcols any)
{
  declare i, l, mixed int;
  i := 0;
  mixed := 0;
  l := length (tbls);
  if (mod (l, 2) = 0)
    {
      for (i := 0; i < l; i := i + 2)
        {
	  if (__tag (tbls[i+1]) = 193)
	    mixed := 1;
	}
    }
  if (mixed)
    {
      declare newtb any;
      newtb := make_array (l/2, 'any');
      pkcols := make_array (l, 'any');
      for (i := 0; i < l; i := i + 2)
         {
	   declare cols any;
	   declare j int;
	   newtb[i/2] := tbls[i];
	   if (__tag (tbls [i + 1]) = 193)
	     {
	       cols := make_array (length (tbls [i + 1]), 'any');
	       j := 0;
	       foreach (varchar c in tbls [i + 1]) do
		 {
		   cols[j] := (select vector (sc."COLUMN", sc."COL_DTP", sc."COL_SCALE", sc."COL_PREC")
		    from DB.DBA.TABLE_COLS sc where upper (sc."COLUMN") = upper (c) and upper ("TABLE") = upper (tbls[i]) and "COLUMN" <> '_IDN');
		   if (length (cols[j]) = 0)
		     signal ('22023', sprintf ('Non existing column %s for table %s', c, tbls[i]));
		   j := j + 1;
		 }
	     }
	   else
	     {
	       cols := rdf_view_get_primary_key (tbls[i]);
	     }
	   pkcols[i] := tbls[i];
	   pkcols[i+1] := cols;
	 }
      tbls := newtb;
    }
  else
    {
      pkcols := make_array (l*2, 'any');
      for (i := 0; i < l; i := i + 1)
        {
	  pkcols[i*2] := tbls[i];
	  pkcols[(i*2)+1] := rdf_view_get_primary_key (tbls[i]);
	}
    }
  foreach (varchar t in tbls) do
    {
      if (not exists (select 1 from SYS_KEYS where KEY_TABLE = t))
	signal ('22023', sprintf ('Non existing table %s', t));
    }
}
;

create procedure rdf_view_ns_get (in cols any, in f int)
{
  declare ses, dict, nss any;
  declare i int;
  ses := string_output ();
  dict := dict_new ();
  for (i := 0; i < length (cols); i := i + 2)
    rdf_view_ns_get_1 (cols[i+1], dict);
  nss := dict_to_vector (dict, 1);
  for (declare i int, i := 0; i < length (nss); i := i + 2)
    {
      if (nss [i] not in ('rdf', 'rdfs', 'scovo', 'sioc', 'aowl', 'xsd', 'virtrdf'))
	{
	  if (f)
	    http (sprintf ('@prefix %s: <%s> . \n', nss[i], nss[i+1]), ses);
	  else
	    http (sprintf ('prefix %s: <%s>  \n', nss[i], nss[i+1]), ses);
	}
    }
  return string_output_string (ses);
}
;

create procedure rdf_view_ns_get_1 (in cols any, inout dict any)
{
  declare class any;
  declare ns, uri any;

--  dbg_obj_print (cols);
  class := cols[0];
  cols := cols[1];
  ns := rdf_view_get_ns (class, uri);
  if (length (ns))
    dict_put (dict, ns, uri);
  foreach (any p in cols) do
    {
      ns := null;
--      dbg_obj_print (p);
      if (length (p[1]))
        ns := rdf_view_get_ns (p[1], uri);
      if (length (ns))
	dict_put (dict, ns, uri);
    }
}
;

create procedure
RDF_VIEW_DROP_STMT_BY_GRAPH (in gr varchar)
{
   declare drop_map any;

   drop_map := '';
   for select "s" from (sparql define input:storage ""
   select ?s from virtrdf:
   {
     ?s virtrdf:qmGraphRange-rvrFixedValue `iri(?:gr)` ; virtrdf:qmUserSubMaps ?t
   }) x do
   {
     drop_map := drop_map || sprintf ('SPARQL drop silent quad map <%s> .;\n', "s");
   }
 return drop_map;
}
;

create procedure
RDF_VIEW_DROP_STMT (in qualifier varchar)
{
   declare drop_map any;
   declare gr varchar;

   drop_map := '';
   gr := sprintf ('http://%s/%s#', virtuoso_ini_item_value ('URIQA','DefaultHost'), qualifier);
   return RDF_VIEW_DROP_STMT_BY_GRAPH (gr);
}
;

create procedure
RDF_VIEW_FROM_TBL (in qualifier varchar, in _tbls any, in gen_stat int := 0, in cols any := null)
{
   declare create_count_count, create_class_stmt, create_view_stmt, sparql_pref, ns, sns, uriqa_str, ret, drop_map any;
   declare total_select, total_tb, total, qual, pkcols any;
   declare vname, mask varchar;

   ret := make_array (2, 'any');
   rdf_view_tbl_pk_cols (_tbls, pkcols);
   cols := rdf_view_tbl_opts (_tbls, cols);
   sparql_pref := 'SPARQL\n';
   uriqa_str := '^{URIQADefaultHost}^';
   sns := ns := sprintf ('prefix %s: <http://%s/schemas/%s/> \n', qualifier, virtuoso_ini_item_value ('URIQA','DefaultHost'), qualifier);

   --for (declare xx any, xx := 0; xx < length (_tbls) ; xx := xx + 1)
   --   drop_map := drop_map || sprintf ('SPARQL %s drop silent quad map %s:qm-%s\n;\n', ns, qualifier, rdf_view_tb (name_part (_tbls[xx], 2)));
   --if (gen_stat)
   --  drop_map := drop_map || sprintf ('SPARQL %s drop silent quad map %s:qm-VoidStatistics\n;\n', ns, qualifier);

   -- ## voID
   if (gen_stat)
     {
       ns := ns || sprintf ('prefix %s-stat: <http://%s/%s/stat#> \n', lcase (qualifier), virtuoso_ini_item_value ('URIQA','DefaultHost'),
			    qualifier);
       ns := ns || 'prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> \n';
       ns := ns || 'prefix void: <http://rdfs.org/ns/void#> \n';
       ns := ns || 'prefix scovo: <http://purl.org/NET/scovo#> \n';
     }
--   ns := ns || 'prefix sioc: <http://rdfs.org/sioc/ns#> \n';
   ns := ns || 'prefix aowl: <http://bblfish.net/work/atom-owl/2006-06-06/> \n';
   ns := ns || rdf_view_ns_get (cols, 0);
   create_class_stmt := '';

   for (declare xx any, xx := 0; xx < length (_tbls) ; xx := xx + 1)
     create_class_stmt := create_class_stmt || rdf_view_create_class (sparql_pref || sns, _tbls[xx], uriqa_str, qualifier, cols, pkcols);

   -- ## voID
   create_count_count := '';
   total_select := '';
   total_tb := '';
   for (declare xx any, xx := 0; gen_stat and xx < length (_tbls) ; xx := xx + 1)
     {
       vname := _tbls[xx]||'Count';
       total_select := total_select || sprintf ('(cnt%d*cnt%d)+', xx*2, (xx*2)+1);
       total_tb := total_tb ||
       	sprintf ('\n (select count(*) cnt%d from "%I"."%I"."%I") tb%d, \n (select count(*)+1 as cnt%d from DB.DBA.TABLE_COLS where "TABLE" = ''%S''  and "COLUMN" <> ''_IDN'') tb%d,',
		xx*2, name_part (_tbls[xx], 0), name_part (_tbls[xx], 1), name_part (_tbls[xx], 2), xx*2, (xx*2)+1, _tbls[xx], (xx*2)+1);
       if (not exists (select 1 from SYS_VIEWS where V_NAME = vname))
	 {
	   create_count_count := create_count_count || sprintf ('create view "%I"."%I"."%ICount" as select count (*) as cnt from "%I"."%I"."%I"; \n',
	      name_part (_tbls[xx], 0),
	      name_part (_tbls[xx], 1),
	      name_part (_tbls[xx], 2),
	      name_part (_tbls[xx], 0),
	      name_part (_tbls[xx], 1),
	      name_part (_tbls[xx], 2));
	   create_count_count := create_count_count || sprintf ('grant select on "%I"."%I"."%ICount" to SPARQL_SELECT; \n',
	      name_part (_tbls[xx], 0),
	      name_part (_tbls[xx], 1),
	      name_part (_tbls[xx], 2));
	 }
     }

   if (gen_stat and length (_tbls))
     {
       declare own any;
       own := name_part (_tbls[0], 1);
       qual := name_part (_tbls[0], 0);
       vname := qual||'.'||own||'.'||qualifier||'__Total';
       total_select := rtrim (total_select, '+') || ' AS cnt';
       total_tb := rtrim (total_tb, ',');
       total := sprintf ('drop view "%I"."%I"."%I__Total"; \n', qual, own, qualifier);

       total := total || sprintf ('create view "%I"."%I"."%I__Total" as select ' || total_select || ' from ' || total_tb || '\n',
		  qual, own, qualifier);
       create_count_count := create_count_count || total || '; \n';
       create_count_count := create_count_count || sprintf ('grant select on "%I"."%I"."%I__Total" to SPARQL_SELECT; \n',
		      qual, own, qualifier);

     }

   if (create_count_count <> '')
     create_count_count := create_count_count || '\n\n';

    create_view_stmt := '';
   for (declare inx int, inx := 0; inx < length (_tbls) ; inx := inx + 1)
      create_view_stmt := create_view_stmt || sparql_pref || ns || rdf_view_create_view (inx, qualifier, _tbls, gen_stat, cols, pkcols) || '\n;\n\n';

   if (gen_stat)
     create_view_stmt := create_view_stmt || sparql_pref || ns || rdf_view_create_void_view (qualifier, _tbls, gen_stat, cols, pkcols) || '\n;\n\n';

   return create_class_stmt || '\n\n' || create_count_count || create_view_stmt;
}
;

create procedure
rdf_view_sp (in i int)
{
  return repeat (' ', i);
}
;

create procedure rdf_view_sql_tb (in tb varchar)
{
  declare q, o, n varchar;
  q := name_part (tb, 0);
  o := name_part (tb, 1);
  n := name_part (tb, 2);
  return sprintf ('"%I"."%I"."%I"', q, o, n);
}
;

create procedure rdf_view_tb (in tb varchar)
{
  declare r varchar;
  r := DB.DBA.SYS_ALFANUM_NAME (tb);
  r := lower (r);
  return r;
}
;

create procedure rdf_view_sql_col (in col varchar)
{
  return sprintf ('"%I"', col);
}
;

create procedure rdf_view_col (in col varchar)
{
  declare r varchar;
  r := DB.DBA.SYS_ALFANUM_NAME (col);
  r := lower (r);
  return r;
}
;

create procedure rdf_view_cls_name (in nam varchar)
{
  -- in this case we take only alpha numeric chars
  return SYS_ALFANUM_NAME (nam);
}
;

create procedure rdf_view_get_ns (in uri varchar, out uriSearch varchar)
{
  declare delim integer;
  declare nsPrefix varchar;

  delim := -1;
  uriSearch := uri;
  nsPrefix := null;
  if (length (uri) = 0)
    return null;
  while (nsPrefix is null and delim <> 0)
    {
      delim := coalesce (strrchr (uriSearch, '/'), 0);
      delim := __max (delim, coalesce (strrchr (uriSearch, '#'), 0));
      delim := __max (delim, coalesce (strrchr (uriSearch, ':'), 0));
      nsPrefix := coalesce (__xml_get_ns_prefix (subseq (uriSearch, 0, delim + 1), 2),
      			    __xml_get_ns_prefix (subseq (uriSearch, 0, delim),     2));
      uriSearch := subseq (uriSearch, 0, delim + 1);
    }
  if (nsPrefix is null)
    {
      declare cnt int;
      uriSearch := uri;
      delim := -1;
      delim := coalesce (strrchr (uriSearch, '/'), 0);
      delim := __max (delim, coalesce (strrchr (uriSearch, '#'), 0));
      delim := __max (delim, coalesce (strrchr (uriSearch, ':'), 0));
      if (delim > 0)
	uriSearch := subseq (uriSearch, 0, delim + 1);
      cnt := 0;
      while (__xml_get_ns_uri (sprintf ('rv%d', cnt), 2) is not null)
	{
	  cnt := cnt + 1;
	}
      nsPrefix := sprintf ('rv%d', cnt);
      if (uri = '')
	signal ('.....', 'Empty IRI is not allowed here');
      DB.DBA.XML_SET_NS_DECL (nsPrefix, uriSearch, 2);
    }
  return nsPrefix;
}
;

create procedure rdf_view_uri_curie (in uri varchar)
{
  declare delim integer;
  declare uriSearch, nsPrefix varchar;

  delim := -1;
  uriSearch := uri;
  nsPrefix := null;
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
	return uri;
      else
	return nsPrefix || ':' || rhs;
    }
  return uri;
}
;

create procedure rdf_view_col_type (in qual varchar, in col varchar, in opts any)
{
  if (not length (opts))
    return sprintf ('%s:%s', qual, col);
  else
    return rdf_view_uri_curie (opts);
}
;

create procedure
rdf_view_create_view (in nth int, in qualifier varchar, in _tbls any, in gen_stat int := 0, in cols any, in pkcols any)
{
   declare ret, qual, qual_l, tbl_name, tbl_name_l, pks, pk_text, uriqa_str any;
   declare suffix, tname, tbl, own, pref_l any;
   declare cols_arr, inx, col_name, owner, owner_l any;

   ret := 'alter quad storage virtrdf:DefaultQuadStorage \n';
   suffix := '_s';
   uriqa_str := '^{URIQADefaultHost}^';
   qual := name_part (_tbls[nth], 0);
   own := name_part (_tbls[nth], 1);
   qual_l := lcase (qual);
   pref_l := lcase (qualifier);
   tbl := _tbls[nth];
   cols_arr := get_keyword (tbl, cols);
   tbl_name := name_part (tbl, 2);
   owner := name_part (tbl, 1);
   tbl_name_l := rdf_view_tb (tbl_name);
   owner_l := rdf_view_tb (owner);
   tname := tbl_name_l || suffix;


   ret := ret || ' from ' || rdf_view_sql_tb (tbl) || ' as ' || rdf_view_tb (name_part (tbl, 3) || suffix) || '\n';

   ret := ret || rdf_view_get_relations (tbl, _tbls, suffix);

   ret := ret || sprintf (' { \n   create %s:qm-%s', qualifier, tbl_name_l) ||
   ' as graph iri ("http://' || uriqa_str || '/' || qualifier || '#") ';

   if (gen_stat = 0 and nth = (length (_tbls) - 1))
     ret := ret || 'option (exclusive)' ;
   ret := ret ||' \n    { \n';


   ret := ret || rdf_view_sp (6) || '# Maps from columns of "' || tbl || '"\n';
   ret := ret || rdf_view_sp (6) || rdf_view_get_pk_rel (qualifier, suffix, tbl, 0, pkcols);
   ret := ret || sprintf (' a %s:%s ;\n', qualifier, rdf_view_cls_name (tbl_name));
   if (length (cols_arr[0]))
     ret := ret || rdf_view_sp (6) || sprintf (' a %s ;\n', rdf_view_uri_curie (cols_arr[0]));

   inx := 0;
   for select "COLUMN" from TABLE_COLS where "TABLE" = tbl and "COLUMN" <> '_IDN' order by COL_ID do
     {
       col_name := lower ("COLUMN");
       if (cols_arr[1][inx][0] = 0 or cols_arr[1][inx][0] = 4)
	 {
	   ret := ret || rdf_view_sp (6) || sprintf ('%s %s.%s as %s:%s-%s-%s ;\n',
			rdf_view_col_type (qualifier, rdf_view_col("COLUMN"), cols_arr[1][inx][1]),
			tname, rdf_view_sql_col ("COLUMN"), qualifier, owner_l, tbl_name_l, rdf_view_col("COLUMN") );
	 }
       else if (isstring (cols_arr[1][inx][0])) -- binary object
	 {
	    ret := ret || rdf_view_sp (6) || sprintf ('%s %s as %s:%s-%s-%s ;\n',
	       rdf_view_col_type (qualifier, rdf_view_col("COLUMN"), cols_arr[1][inx][1]),
	       rdf_view_get_bin_rel (qualifier, suffix, tbl, col_name, pkcols),
	       qualifier, owner_l, tbl_name_l, rdf_view_col("COLUMN"));
	 }
       inx := inx + 1;
     }
   if (exists (select top 1 1 from SYS_FOREIGN_KEYS where PK_TABLE = tbl and FK_TABLE <> tbl and 0 < position (FK_TABLE, _tbls))
       or
       exists (select top 1 1 from SYS_FOREIGN_KEYS where FK_TABLE = tbl and PK_TABLE <> tbl and 0 < position (PK_TABLE, _tbls)))
     ret := ret || rdf_view_sp (6) || '# Maps from foreign-key relations of "' || tbl || '"\n';
   ret := ret || rdf_view_get_fk_pk_rel (qualifier, suffix, tbl, _tbls, pkcols);
   ret := ret || rdf_view_get_pk_fk_rel (qualifier, suffix, tbl, _tbls, pkcols);

    ret := trim (ret, '\n');
    ret := trim (ret, ';');
    ret := ret || '.\n';
   inx := 0;
   for select "COLUMN" from TABLE_COLS where "TABLE" = tbl and "COLUMN" <> '_IDN' order by COL_ID do
     {
       col_name := lower ("COLUMN");
       if (isstring (cols_arr[1][inx][0]))
	 {
	    ret := ret || rdf_view_sp (6) || sprintf ('%s a aowl:Content ; aowl:body %s.%s as %s:%s-%s-%s-content ; aowl:type "%s" .\n',
	       rdf_view_get_bin_rel (qualifier, suffix, tbl, col_name, pkcols),
	       tname, rdf_view_sql_col ("COLUMN"),
	       qualifier, owner_l, tbl_name_l, rdf_view_col("COLUMN"), cols_arr[1][inx][0]);
	 }
       inx := inx + 1;
     }
    ret := ret || '\n';

   ret := ret || '    }\n }\n';
   return ret;
}
;

create procedure
rdf_view_create_void_view (in qualifier varchar, in _tbls any, in gen_stat int := 0, in cols any, in pkcols any)
{
   declare ret, qual, qual_l, tbl_name, tbl_name_l, pks, pk_text, uriqa_str any;
   declare suffix, tname, tbl, own, pref_l any;

   uriqa_str := '^{URIQADefaultHost}^';
   qual := name_part (_tbls[0], 0);
   own := name_part (_tbls[0], 1);
   qual_l := lcase (qual);
   pref_l := lcase (qualifier);

   ret := 'alter quad storage virtrdf:DefaultQuadStorage \n';
   suffix := '_s';

   for (declare xx any, xx := 0; xx < length (_tbls) ; xx := xx + 1)
     {
       ret := ret || ' from ' || rdf_view_sql_tb (_tbls[xx]||'Count') || ' as ' || rdf_view_tb (name_part (_tbls[xx]||'Count', 3) || suffix) || '\n';
     }
   ret := ret || ' from ' || rdf_view_sql_tb (qual||'.'||own||'.'||qualifier||'__Total') || ' as ' ||
   	rdf_view_tb (qualifier||'__Total'||suffix) || '\n';

   ret := ret || sprintf (' { \n   create %s:qm-VoidStatistics', qualifier) ||
   ' as graph iri ("http://' || uriqa_str || '/' || qualifier || '#") option (exclusive) \n    { \n';

   ret := ret || rdf_view_sp (6) || '# voID Statistics \n';
   ret := ret || rdf_view_sp (6) || sprintf ('%s-stat: a void:Dataset as %s:dataset-%s ; \n', pref_l, qualifier, qual_l);
   ret := ret || rdf_view_sp (6) || sprintf (' void:sparqlEndpoint <http://%s/sparql> as %s:dataset-sparql-%s ; \n',
		    virtuoso_ini_item_value ('URIQA','DefaultHost'), qualifier, qual_l);

   ret := ret || rdf_view_sp (6) ||	sprintf ('void:statItem %s-stat:Stat . \n', pref_l);
   ret := ret || rdf_view_sp (6) || sprintf ('%s-stat:Stat a scovo:Item ; \n', pref_l);
   ret := ret || rdf_view_sp (6) || sprintf (' rdf:value %s.cnt as %s:stat-decl-%s ; \n', rdf_view_tb (qualifier||'__Total'||suffix), qualifier, qual_l);
   ret := ret || rdf_view_sp (6) || sprintf (' scovo:dimension void:numOfTriples . \n\n');

   for (declare xx any, xx := 0; xx < length (_tbls) ; xx := xx + 1)
      {
	   tbl := _tbls[xx];
	   tbl_name := name_part (tbl, 2);
	   tbl_name_l := rdf_view_tb (tbl_name);
	   tname := tbl_name_l || suffix;
	   ret := ret || rdf_view_sp (6) || sprintf ('%s-stat: void:statItem %s-stat:%sStat as %s:statitem-%s-%s . \n',
				    pref_l, pref_l, rdf_view_cls_name (tbl_name), qualifier, qual_l, tbl_name_l);
	   ret := ret || rdf_view_sp (6) || sprintf ('%s-stat:%sStat a scovo:Item as %s:statitem-decl-%s-%s ; \n',
				    pref_l, rdf_view_cls_name (tbl_name), qualifier, qual_l, tbl_name_l);
	   ret := ret || rdf_view_sp (6) || sprintf ('rdf:value %s.cnt as %s:statitem-cnt-%s-%s ; \n',
						    rdf_view_tb (tbl_name||'Count') || suffix, qualifier, qual_l, tbl_name_l);
	   ret := ret || rdf_view_sp (6) || sprintf ('scovo:dimension void:numberOfResources as %s:statitem-type-1-%s-%s ; \n',
						    qualifier, qual_l, tbl_name_l);
	   ret := ret || rdf_view_sp (6) || sprintf ('scovo:dimension %s:%s as %s:statitem-type-2-%s-%s .\n\n',
						    qualifier, rdf_view_cls_name (tbl_name), qualifier, qual_l, tbl_name_l);
      }

   ret := ret || '    }\n }';
   return ret;
}
;

create procedure
rdf_view_get_pk_rel (in pref varchar, in suffix varchar, inout tbl varchar, in set_tb int, in  pkcols any)
{
  declare pks any;
  declare tbl_name, tbl_name_l, tname, pk_text, ret varchar;

  tbl_name := name_part (tbl, 3);
  tbl_name_l := lcase (tbl_name);
  pks := get_keyword (tbl, pkcols); --rdf_view_get_primary_key (tbl);
  tname := tbl_name_l || suffix;
  pk_text := '';

  for (declare i any, i := 0; i < length (pks) ; i := i + 1)
     pk_text := pk_text || rdf_view_tb (tname) || '.' || rdf_view_sql_col (pks[i][0]) || ',';
  pk_text := trim (pk_text, ',');
  ret := sprintf ('%s:%s (%s) ', pref, rdf_view_tb (tbl_name_l), pk_text);
  if (set_tb)
    tbl := tbl_name_l;
  return ret;
}
;

create procedure
rdf_view_get_bin_rel (in pref varchar, in suffix varchar, in tbl varchar, in col_name varchar, in pkcols any)
{
  declare pks any;
  declare tbl_name, tbl_name_l, tname, pk_text, ret varchar;

  tbl_name := name_part (tbl, 3);
  tbl_name_l := lcase (tbl_name);
  pks := get_keyword (tbl, pkcols); --rdf_view_get_primary_key (tbl);
  tname := tbl_name_l || suffix;
  pk_text := '';

  for (declare i any, i := 0; i < length (pks) ; i := i + 1)
     pk_text := pk_text || rdf_view_tb (tname) || '.' || rdf_view_sql_col (pks[i][0]) || ',';
  pk_text := trim (pk_text, ',');
  ret := sprintf ('%s:%s_%s (%s) ', pref, rdf_view_tb (tbl_name_l), col_name, pk_text);
  return ret;
}
;

create procedure
rdf_view_get_fk_pk_rel (in pref varchar, in suffix varchar, in tbl varchar, in tbls any, in pkcols any)
{
  declare ret any;
  declare tbl_name, tbl_name_l, tname, pk_text varchar;

  tbl_name := name_part (tbl, 3);
  tbl_name_l := rdf_view_tb (tbl_name);
  tname := tbl_name_l || suffix;

  ret := string_output ();
  for select distinct PK_TABLE as pkt from SYS_FOREIGN_KEYS where FK_TABLE = tbl and PK_TABLE <> tbl and 0 < position (PK_TABLE, tbls) do
    {
      declare fk_rel  any;
      pk_text := rdf_view_get_pk_rel (pref, suffix, pkt, 1, pkcols);
      fk_rel := rdf_view_sp (6) || sprintf ('%s:has_%s %s as %s:%s_has_%s ;\n', pref, rdf_view_tb (pkt), pk_text, pref, tbl_name_l, rdf_view_tb (pkt));
      http (fk_rel, ret);
    }
  return string_output_string (ret);
}
;

create procedure
rdf_view_get_pk_fk_rel (in pref varchar, in suffix varchar, in tbl varchar, in tbls any, in pkcols any)
{
  declare ret any;
  declare tbl_name, tbl_name_l, tname, pk_text varchar;

  tbl_name := name_part (tbl, 3);
  tbl_name_l := rdf_view_tb (tbl_name);
  tname := tbl_name_l || suffix;

  ret := string_output ();
  for select distinct FK_TABLE as pkt from SYS_FOREIGN_KEYS where PK_TABLE = tbl and FK_TABLE <> tbl and 0 < position (FK_TABLE, tbls) do
    {
      declare fk_rel  any;
      pk_text := rdf_view_get_pk_rel (pref, suffix, pkt, 1, pkcols);
      fk_rel := rdf_view_sp (6) || sprintf ('%s:%s_of %s as %s:%s_%s_of ;\n', pref, tbl_name_l, pk_text, pref, tbl_name_l, rdf_view_tb (pkt));
      http (fk_rel, ret);
    }
  return string_output_string (ret);
}
;

create procedure
rdf_view_dv_to_printf_str_type (in _dv varchar, in sc int)
{
   if (_dv = 189 or _dv = 188) return '%d';
   else if (_dv = 247) return '%ld';
   else if (_dv in (__tag of double precision, __tag of numeric) and sc = 0) return '%d';
   else if (_dv = 182 or _dv = 225) return '%U';
   else if (__tag of double precision = _dv) return '%g';
   else if (__tag of real = _dv) return '%f';
   else if (__tag of numeric = _dv) return '%g';
   else if (__tag of date = _dv) return '%1D';
   else if (__tag of time = _dv) return '%1D';
   else if (__tag of datetime = _dv or __tag of timestamp = _dv) return '%1D';
   signal ('42000', sprintf ('The current implementation do no supports data type %s (%i) for IRI classes', dv_type_title (_dv), _dv));
}
;

create procedure
rdf_view_dv_to_sql_str_type (in _dv varchar)
{
   if (_dv = 189 or _dv = 188 or _dv = 247) return 'integer';
   else if (_dv = 182 or _dv = 125 or _dv = 131) return 'varchar';
   else if (__tag of double precision = _dv) return 'numeric';
   else if (__tag of real = _dv) return 'float';
   else if (__tag of numeric = _dv) return 'numeric';
   else if (__tag of date = _dv) return 'date';
   else if (__tag of time = _dv) return 'time';
   else if (__tag of datetime = _dv) return 'datetime';
   else if (__tag of timestamp = _dv) return 'timestamp';
   else if (__tag of nvarchar = _dv) return 'nvarchar';
   signal ('42000', sprintf ('The current implementation do no supports data type %s (%i) for IRI classes', dv_type_title (_dv), _dv));
}
;

create procedure
rdf_view_dv_to_xsd_str_type (in _dv varchar)
{
   if (_dv = 189 or _dv = 188 or _dv = 247) return 'int';
   else if (_dv = 182 or _dv = 125 or _dv = 131 or _dv = 132) return 'string';
   else if (__tag of double precision = _dv) return 'numeric';
   else if (__tag of real = _dv) return 'float';
   else if (__tag of numeric = _dv) return 'numeric';
   else if (__tag of date = _dv) return 'date';
   else if (__tag of time = _dv) return 'time';
   else if (__tag of datetime = _dv) return 'dateTime';
   else if (__tag of timestamp = _dv) return 'dateTime';
   else if (__tag of nvarchar = _dv) return 'string';
   signal ('42000', sprintf ('The current implementation do no supports data type %s (%i) for IRI classes', dv_type_title (_dv), _dv));
}
;

create procedure
rdf_view_create_class (in decl varchar, in _tbl varchar, in _host varchar, in qualifier varchar, in cols any, in pkcols any)
{
   declare ret, qual, tbl_name, tbl_name_l, pks, pk_text, sk_str any;
   declare cols_arr, inx, col_name any;

   qual := name_part (_tbl, 0);
   tbl_name := name_part (_tbl, 3);
   tbl_name_l := rdf_view_tb (tbl_name);
   pks := get_keyword (_tbl, pkcols); --rdf_view_get_primary_key (_tbl);
   pk_text := '';
   sk_str := '';

   if (length (pks) = 0)
     signal ('22023', sprintf ('This version do not support tables without primary key, please remove table %s from set', _tbl));

   for (declare i any, i := 0; i < length (pks) ; i := i + 1)
     {
       pk_text := pk_text || 'in ' || '_' || rdf_view_cls_name (pks[i][0]) || ' ' || rdf_view_dv_to_sql_str_type(pks[i][1]) || ' not null,';
       sk_str := sk_str || '/' || rdf_view_cls_name (pks[i][0]) || '/' || rdf_view_dv_to_printf_str_type (pks[i][1], pks[i][2]);
     }
   pk_text := trim (pk_text, ',');
   sk_str  := trim (sk_str , '/');
   ret := decl || sprintf ('create iri class %s:%s "http://%s/%s/%s/%s#this" (%s) . ;\n',
		qualifier, tbl_name_l, _host, qualifier, tbl_name_l, sk_str, pk_text);
   cols_arr := get_keyword (_tbl, cols);
   inx := 0;
   for select "COLUMN" as col from TABLE_COLS where "TABLE" = _tbl and "COLUMN" <> '_IDN' order by COL_ID do
     {
       if (isstring (cols_arr[1][inx][0]))
	 {
	   declare ext varchar;
	   col_name := lower (col);
	   ext := (select top 1 T_EXT from WS.WS.SYS_DAV_RES_TYPES where T_TYPE = cols_arr[1][inx][0]);
	   if (length (ext) > 0)
	     ext := '.' || ext;
	   else
	     ext := '';
	   ret := ret || decl || sprintf ('create iri class %s:%s_%s "http://%s/%s/objects/%s/%s/%s%s" (%s) . ;\n',
		qualifier, tbl_name_l, col_name, _host, qualifier, tbl_name_l, sk_str, col, ext, pk_text);
	 }
       inx := inx + 1;
     }
   return ret;
}
;

create procedure
rdf_view_get_primary_key (in _tbl varchar)
{
   return DB.DBA.REPL_PK_COLS (_tbl);
}
;

create procedure
rdf_view_get_relations (in _tbl varchar, in _tbls varchar, in _suff varchar)
{
   declare ret, aliases any;

   ret := '';
   aliases := dict_new (10);
   dict_put (aliases, _tbl, 1);
   foreach (any tbl in _tbls) do
       for (SELECT name_part (PK_TABLE, 1) as PK_TABLE_SCHEMA,
	   PK_TABLE,
	   name_part (PK_TABLE, 2) as PK_TABLE_NAME,
	   PKCOLUMN_NAME as PK_COLUMN_NAME,
	   name_part (FK_TABLE, 1) as FK_TABLE_SCHEMA,
	   name_part (FK_TABLE, 2) as FK_TABLE_NAME,
	   FKCOLUMN_NAME AS FK_COLUMN_NAME,
	   KEY_SEQ, UPDATE_RULE, DELETE_RULE, FK_NAME
	   FROM DB.DBA.SYS_FOREIGN_KEYS WHERE FK_TABLE = tbl and PK_TABLE <> tbl) do

	 {
	   if (position (PK_TABLE, _tbls) <> 0 and (tbl = _tbl or PK_TABLE = _tbl))
	     {
	       declare alias any;
	       if (tbl = _tbl)
		 alias := PK_TABLE;
	       else
		 alias := tbl;

	       if (dict_get (aliases, alias) is null)
		 {
		   ret := ret || ' from ' || rdf_view_sql_tb (alias) || ' as ' || rdf_view_tb (name_part (alias, 3) || _suff) || '\n';
		   dict_put (aliases, alias, 1);
		 }
	       ret := ret || sprintf (' where (^{%s%s.}^."%I" = ^{%s%s.}^."%I") \n',
	       rdf_view_tb (FK_TABLE_NAME), _suff, FK_COLUMN_NAME,
	       rdf_view_tb (PK_TABLE_NAME), _suff, PK_COLUMN_NAME);
	     }
	 }
   return ret;
}
;

create procedure
RDF_OWL_FROM_TBL (in qual varchar, in _tbls any, in cols any := null)
{
  declare ses, cols_arr, pkcols any;
  declare ns varchar;
  declare inx int;

  rdf_view_tbl_pk_cols (_tbls, pkcols);
  cols := rdf_view_tbl_opts (_tbls, cols);
  ns := sprintf ('@prefix %s: <http://%s/schemas/%s/> .\n', qual, virtuoso_ini_item_value ('URIQA','DefaultHost'), qual);
  ses := string_output ();
  http ('@prefix owl: <http://www.w3.org/2002/07/owl#> .\n', ses);
  http ('@prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .\n', ses);
  http ('@prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .\n', ses);
  http ('@prefix xsd: <http://www.w3.org/2001/XMLSchema#> .\n', ses);
  http ('@prefix aowl: <http://bblfish.net/work/atom-owl/2006-06-06/> .\n', ses);
  http ('@prefix virtrdf: <http://www.openlinksw.com/schemas/virtrdf#> .\n', ses);
  http (ns, ses);
  http (rdf_view_ns_get (cols, 1), ses);
  http (sprintf ('\n%s: a owl:Ontology .\n', qual), ses);
  foreach (varchar tbl in _tbls) do
    {
      declare cls, ltb varchar;
      cls := rdf_view_cls_name (name_part (tbl, 2));
      ltb := rdf_view_tb (name_part (tbl, 2));

      http (sprintf ('\n# %s\n', tbl), ses);
      http (sprintf ('%s:%s a rdfs:Class .\n', qual, cls), ses);
      http (sprintf ('%s:%s rdfs:isDefinedBy %s: .\n', qual, cls, qual), ses);
      http (sprintf ('%s:%s rdfs:label "%s" .\n', qual, cls, tbl), ses);
      inx := 0;
      cols_arr := get_keyword (tbl, cols);
      if (length (cols_arr[0]))
	http (sprintf ('%s:%s rdfs:subClassOf %s .\n', qual, cls, rdf_view_uri_curie (cols_arr[0])), ses);
      for select "COLUMN" as col, COL_DTP as dtp from TABLE_COLS where "TABLE" = tbl and "COLUMN" <> '_IDN' order by COL_ID do
	{
	  declare xsd, label varchar;
	  label := col;
	  col := rdf_view_col (col);
	  xsd := rdf_view_dv_to_xsd_str_type (dtp);
	  if (cols_arr[1][inx][0] = 1 or length (cols_arr[1][inx][1]) > 0)
	    goto skip_this;
	  else if (isstring (cols_arr[1][inx][0]))
	    {
	      http (sprintf ('%s:%s a owl:ObjectProperty .\n', qual, col), ses);
	      --if (length (cols_arr[1][inx][1]))
	      --   http (sprintf ('%s:%s rdfs:subPropertyOf %s .\n', qual, col, rdf_view_uri_curie (cols_arr[1][inx][1])), ses);
	      http (sprintf ('%s:%s rdfs:range aowl:Content .\n', qual, col), ses);
	    }
	  else if (cols_arr[1][inx][0] = 4)
	    {
	      http (sprintf ('%s:%s rdfs:subPropertyOf virtrdf:label . \n', qual, col), ses);
	      http (sprintf ('%s:%s rdfs:range xsd:%s .\n', qual, col, xsd), ses);
	    }
	  else
	    {
	      http (sprintf ('%s:%s a owl:DatatypeProperty .\n', qual, col), ses);
	      http (sprintf ('%s:%s rdfs:range xsd:%s .\n', qual, col, xsd), ses);
	    }

	  http (sprintf ('%s:%s rdfs:domain %s:%s .\n', qual, col, qual, cls), ses);
	  http (sprintf ('%s:%s rdfs:isDefinedBy %s: .\n', qual, col, qual), ses);
	  http (sprintf ('%s:%s rdfs:label "%S" .\n', qual, col, label), ses);
skip_this:
	  inx := inx + 1;
	}
      for select distinct PK_TABLE as pkt from SYS_FOREIGN_KEYS where FK_TABLE = tbl and 0 < position (PK_TABLE, _tbls) do
	{
	  declare pkcls, lpkt varchar;
	  pkcls := rdf_view_cls_name (name_part (pkt, 2));
	  lpkt := rdf_view_tb (name_part (pkt, 2));

	  http (sprintf ('%s:has_%s a owl:ObjectProperty .\n', qual, lpkt), ses);
	  http (sprintf ('%s:has_%s rdfs:domain %s:%s .\n', qual, lpkt, qual, cls), ses);
	  http (sprintf ('%s:has_%s rdfs:range %s:%s .\n', qual, lpkt, qual, pkcls), ses);
	  http (sprintf ('%s:has_%s rdfs:label "Relation to %s" .\n', qual, lpkt, pkt), ses);
	  http (sprintf ('%s:has_%s rdfs:isDefinedBy %s: .\n', qual, lpkt, qual), ses);
	}
      for select distinct FK_TABLE as pkt from SYS_FOREIGN_KEYS where PK_TABLE = tbl and 0 < position (FK_TABLE, _tbls) do
	{
	  declare pkcls varchar;
	  pkcls := rdf_view_cls_name (name_part (pkt, 2));

	  http (sprintf ('%s:%s_of a owl:ObjectProperty .\n', qual, ltb), ses);
	  http (sprintf ('%s:%s_of rdfs:domain %s:%s .\n', qual, ltb, qual, cls), ses);
	  http (sprintf ('%s:%s_of rdfs:range %s:%s .\n', qual, ltb, qual, pkcls), ses);
	  http (sprintf ('%s:%s_of rdfs:label "Relation to %s" .\n', qual, ltb, pkt), ses);
	  http (sprintf ('%s:%s_of rdfs:isDefinedBy %s: .\n', qual, ltb, qual), ses);
	}
    }
  return string_output_string (ses);
}
;

create procedure RDF_VIEW_GEN_VD (in qual varchar)
{
  declare ses, pref any;
  declare fct_installed int;
  ses := string_output ();
  pref := lower (qual);

  if (0 and (
      exists (select 1 from URL_REWRITE_RULE where URR_RULE = pref || '_rule1') or
      exists (select 1 from URL_REWRITE_RULE where URR_RULE = pref || '_rule2') or
      exists (select 1 from URL_REWRITE_RULE where URR_RULE = pref || '_rule3') or
      exists (select 1 from URL_REWRITE_RULE where URR_RULE = pref || '_rule4') or
      exists (select 1 from URL_REWRITE_RULE_LIST where URRL_LIST = pref || '_rule_list1') or
      exists (select 1 from HTTP_PATH where HP_HOST = '*ini*' and HP_LISTEN_HOST = '*ini*' and HP_LPATH = '/'||qual)
     ) )
    return '\n-- WARNING: there are already created virtual directory "/'||qual||'", skipping virtual directory generation\n'||
    '-- WARNING: To avoid this message chose different base URL or drop existing virtual directory and its rewrite rules.\n';

  if (exists (select 1 from VAD.DBA.VAD_REGISTRY where R_KEY like '/VAD/fct/%/resources/dav/%'))
    fct_installed := 1;

  http (
  'DB.DBA.URLREWRITE_CREATE_REGEX_RULE (
    ''<pref>_rule2'',
    1,
    ''(/[^#]*)'',
    vector(''path''),
    1,
    ''/sparql?query=DESCRIBE+%%3Chttp%%3A//^{URIQADefaultHost}^%U%%23this%%3E+FROM+%%3Chttp%%3A//^{URIQADefaultHost}^/<qual>%%23%%3E&format=%U'',
    vector(''path'', ''*accept*''),
    null,
    ''(text/rdf.n3)|(application/rdf.xml)|(text/n3)|(application/json)'',
    2,
    null
    );', ses);

  http ('\n', ses);

  http (
  'DB.DBA.URLREWRITE_CREATE_REGEX_RULE (
    ''<pref>_rule4'',
    1,
    ''/<qual>/stat([^#]*)'',
    vector(''path''),
    1,
    ''/sparql?query=DESCRIBE+%%3Chttp%%3A//^{URIQADefaultHost}^/<qual>/stat%%23%%3E+%%3Fo+FROM+%%3Chttp%%3A//^{URIQADefaultHost}^/<qual>%%23%%3E+WHERE+{+%%3Chttp%%3A//^{URIQADefaultHost}^/<qual>/stat%%23%%3E+%%3Fp+%%3Fo+}&format=%U'',
    vector(''*accept*''),
    null,
    ''(text/rdf.n3)|(application/rdf.xml)|(text/n3)|(application/json)'',
    2,
    null
    );', ses);

  http ('\n', ses);
  http (
  'DB.DBA.URLREWRITE_CREATE_REGEX_RULE (
    ''<pref>_rule6'',
    1,
    ''/<qual>/objects/([^#]*)'',
    vector(''path''),
    1,
    ''/sparql?query=DESCRIBE+%%3Chttp%%3A//^{URIQADefaultHost}^/<qual>/objects/%U%%3E+FROM+%%3Chttp%%3A//^{URIQADefaultHost}^/<qual>%%23%%3E&format=%U'',
    vector(''path'', ''*accept*''),
    null,
    ''(text/rdf.n3)|(application/rdf.xml)|(text/n3)|(application/json)'',
    2,
    null
    );', ses);

  http ('\n', ses);
  http (concat (
  'DB.DBA.URLREWRITE_CREATE_REGEX_RULE (
    ''<pref>_rule1'',
    1,
    ''([^#]*)'',
    vector(''path''),
    1,\n',

    case when fct_installed
    then
      '''/describe/?url=http%%3A//^{URIQADefaultHost}^%U%%23this&graph=http%%3A//^{URIQADefaultHost}^/<qual>%%23'','
    else
      '''/about/html/http://^{URIQADefaultHost}^%s'','
    end

    ,'\nvector(''path''),
    null,
    null,
    2,
    303
    );'), ses);
  http ('\n', ses);

  http (concat (
  'DB.DBA.URLREWRITE_CREATE_REGEX_RULE (
    ''<pref>_rule7'',
    1,
    ''/<qual>/stat([^#]*)'',
    vector(''path''),
    1,\n',

    case when fct_installed
    then
      '''/describe/?url=http%%3A//^{URIQADefaultHost}^/<qual>/stat%%23&graph=http%%3A//^{URIQADefaultHost}^/<qual>%%23'','
    else
      '''/about/html/http://^{URIQADefaultHost}^/<qual>/stat%%01'','
    end

    ,'\nvector(''path''),
    null,
    null,
    2,
    303
    );'), ses);
  http ('\n', ses);

  http (
  'DB.DBA.URLREWRITE_CREATE_REGEX_RULE (
    ''<pref>_rule5'',
    1,
    ''/<qual>/objects/(.*)'',
    vector(''path''),
    1,
    ''/services/rdf/object.binary?path=%%2F<qual>%%2Fobjects%%2F%U&accept=%U'',
    vector(''path'', ''*accept*''),
    null,
    null,
    2,
    null
    );', ses);

  http ('\n', ses);
  http ('DB.DBA.URLREWRITE_CREATE_RULELIST ( ''<pref>_rule_list1'', 1, vector ( ''<pref>_rule1'', ''<pref>_rule7'', ''<pref>_rule5'', ''<pref>_rule2'', ''<pref>_rule4'', ''<pref>_rule6''));', ses);

  http ('\n', ses);
  http ('DB.DBA.VHOST_REMOVE (lpath=>''/<qual>'');', ses);
  http ('\n', ses);
  http('DB.DBA.VHOST_DEFINE (lpath=>''/<qual>'', ppath=>''/'', vsp_user=>''dba'', is_dav=>0,
          is_brws=>0, opts=>vector (''url_rewrite'', ''<pref>_rule_list1'')
	  );',ses);
   ses := string_output_string (ses);
   ses := replace (ses, '<pref>', pref);
   ses := replace (ses, '<qual>', qual);
   return ses;
}
;

create procedure RDF_OWL_GEN_VD (in qual varchar)
{
  declare fct_installed int;
  declare ses, pref any;
  ses := string_output ();
  pref := lower (qual);

  if ( 0 and (
      exists (select 1 from URL_REWRITE_RULE where URR_RULE = pref || '_owl_rule1') or
      exists (select 1 from URL_REWRITE_RULE where URR_RULE = pref || '_owl_rule2') or
      exists (select 1 from URL_REWRITE_RULE_LIST where URRL_LIST = pref || '_owl_rule_list1') or
      exists (select 1 from HTTP_PATH where HP_HOST = '*ini*' and HP_LISTEN_HOST = '*ini*' and HP_LPATH = '/schemas/'||qual)
     ) )
    return '\n-- WARNING: there are already created virtual directory "/schemas/'||qual||'", skipping virtual directory generation\n'||
    '-- WARNING: To avoid this message chose different base URL or drop existing virtual directory and its rewrite rules.\n';

  if (exists (select 1 from VAD.DBA.VAD_REGISTRY where R_KEY like '/VAD/fct/%/resources/dav/%'))
    fct_installed := 1;

  http (
  'DB.DBA.URLREWRITE_CREATE_REGEX_RULE (
    ''<pref>_owl_rule2'',
    1,
    ''(/[^#]*)'',
    vector(''path''),
    1,
    ''/sparql?query=DESCRIBE+%%3Chttp%%3A//^{URIQADefaultHost}^%U%%3E+FROM+%%3Chttp%%3A//^{URIQADefaultHost}^/schemas/<qual>%%23%%3E&format=%U'',
    vector(''path'', ''*accept*''),
    null,
    ''(text/rdf.n3)|(application/rdf.xml)|(text/n3)|(application/json)'',
    2,
    null
    );', ses);

  http ('\n', ses);
  http (
  concat (
  'DB.DBA.URLREWRITE_CREATE_REGEX_RULE (
    ''<pref>_owl_rule1'',
    1,
    ''([^#]*)'',
    vector(''path''),
    1,\n',
    case when fct_installed
    then
    '''/describe/?url=http://^{URIQADefaultHost}^%U'','
    else
    '''/about/html/http://^{URIQADefaultHost}^%s'','
    end,
    '\nvector(''path''),
    null,
    null,
    2,
    303
    );'), ses);
  http ('\n', ses);
  http ('DB.DBA.URLREWRITE_CREATE_RULELIST ( ''<pref>_owl_rule_list1'', 1, vector ( ''<pref>_owl_rule1'', ''<pref>_owl_rule2''));', ses);

  http ('\n', ses);
  http ('DB.DBA.VHOST_REMOVE (lpath=>''/schemas/<qual>'');', ses);
  http ('\n', ses);
  http('DB.DBA.VHOST_DEFINE (lpath=>''/schemas/<qual>'', ppath=>''/'', vsp_user=>''dba'', is_dav=>0,
          is_brws=>0, opts=>vector (''url_rewrite'', ''<pref>_owl_rule_list1'')
	  );',ses);
   ses := string_output_string (ses);
   ses := replace (ses, '<pref>', pref);
   ses := replace (ses, '<qual>', qual);
   return ses;
}
;

create procedure
RDF_VIEW_CHECK_SYNC_TB (in tb varchar)
{
  declare tree, tbname any;
  tree := sql_parse (sprintf ('SELECT 1 from %s', tb));
  tbname := tree [4][1][0][1][1];
  tbname := complete_table_name (tbname, 1);
  if (exists (select 1 from SYS_VIEWS where V_NAME = tbname))
    return 0;
  return 1;
}
;

create procedure
RDF_VIEW_DO_SYNC (in qualifier varchar, in load_data int := 0, in pgraph varchar := null)
{
   declare gr varchar;
   gr := sprintf ('http://%s/%s#', virtuoso_ini_item_value ('URIQA','DefaultHost'), qualifier);
   return RDF_VIEW_SYNC_TO_PHYSICAL (gr, load_data, pgraph);
}
;

create procedure
RDF_VIEW_SYNC_TO_PHYSICAL (in vgraph varchar, in load_data int := 0, in pgraph varchar := null, in log_mode int := 1, in load_atomic int := 1)
{
   declare mask varchar;
   declare txt, tbls, err_ret, opt any;
   declare stat, msg, gr varchar;
   declare old_mode int;

   old_mode := log_enable (log_mode, 1);
   declare exit handler for sqlstate '*' {
     log_enable (old_mode, 1);
     if (load_atomic)
       __atomic (0);
   };

   if (load_atomic)
     __atomic (1);
   tbls := vector ();
   err_ret := vector ();
   opt := vector ();
   gr := vgraph;
   if (length (pgraph))
     opt := vector (gr, pgraph);
   for select "o" from
   (sparql define input:storage "" select ?o from virtrdf:
     {
       virtrdf:DefaultQuadStorage-UserMaps ?p ?o .
       ?o a virtrdf:QuadMap  .
       ?o virtrdf:qmGraphRange-rvrFixedValue `iri(?:gr)` .
     }
     order by asc (bif:sprintf_inverse (bif:concat (str(rdf:_), "%d"), str (?p), 1))) x do
   {
     declare qm varchar;
     if ("o" not like '%/qm-VoidStatistics')
       {
	 exec (sprintf ('sparql alter quad storage virtrdf:SyncToQuads { drop quad map <%s> }', "o"), stat, msg);
	 stat := '00000';
	 exec (sprintf ('sparql alter quad storage virtrdf:SyncToQuads { create <%s> using storage virtrdf:DefaultQuadStorage }', "o"), stat, msg);
	 if (stat <> '00000')
	   err_ret := vector_concat (err_ret, vector (vector (stat, msg)));

	 qm := "o";
	 for select "tb" from (sparql define input:storage ""
	    select distinct ?tb from virtrdf:
	    {
	      ?:qm virtrdf:qmUserSubMaps ?sm .
	      ?sm ?inx ?q .
	      ?q virtrdf:qmTableName ?tb  .
	    }) xx do
	   {
	     if (RDF_VIEW_CHECK_SYNC_TB ("tb"))
 	       tbls := vector_concat (tbls, vector ("tb"));
	     else
	       err_ret := vector_concat (err_ret, vector (vector ('42000', sprintf ('Reference to VIEW %s cannot be added automatically', "tb"))));
	   }
       }
   }
  foreach (varchar tb in tbls) do
    {
      for (declare ctr int, ctr := 1; ctr <= 4; ctr := ctr + 1)
        {
	  txt := sparql_rdb2rdf_codegen (tb, ctr, opt);
	  stat := '00000';
	  if (isvector (txt))
	    {
	      exec (cast (txt[0] as varchar), stat, msg);
	      if (stat <> '00000')
		{
		  err_ret := vector_concat (err_ret, vector (vector (stat, msg)));
		  stat := '00000';
		}
	      exec (cast (txt[1] as varchar), stat, msg);
	      if (stat <> '00000')
		err_ret := vector_concat (err_ret, vector (vector (stat, msg)));
	    }
	  else
	    {
	      exec (cast (txt as varchar), stat, msg);
	      if (stat <> '00000')
		err_ret := vector_concat (err_ret, vector (vector (stat, msg)));
	    }
	}
      if (load_data)
	{
	  declare pname varchar;
	  pname := sprintf ('DB.DBA."RDB2RDF_FILL__%s" ()', replace (replace (tb, '"', '`'), '.', '~'));
	  stat := '00000';
	  exec (pname, stat, msg);
	  if (stat <> '00000') err_ret := vector_concat (err_ret, vector (sprintf ('%s: %s', stat, msg)));
	}
    }
  log_enable (old_mode, 1);
  if (load_atomic)
    {
      __atomic (0);
      exec ('checkpoint');
    }
  return err_ret;
}
;

---------------------
-- R2RML generator
---------------------
create procedure
DB.DBA.R2RML_FROM_TBL (in qualifier varchar, in _tbls any, in gen_stat int := 0, in cols any := null, in qual_ns varchar := null)
{
   declare create_view_stmt, ns, sns any;
   declare total_select, total_tb, total, qual, pkcols any;
   declare vname, mask, graph, uriqa_str varchar;

   rdf_view_tbl_pk_cols (_tbls, pkcols);
   cols := rdf_view_tbl_opts (_tbls, cols);
   if (qual_ns is null)
     qual_ns := sprintf ('http://%s/schemas/%s/', virtuoso_ini_item_value ('URIQA','DefaultHost'), qualifier);
   sns := ns := sprintf ('@prefix rr: <http://www.w3.org/ns/r2rml#> .\n@prefix %s: <%s> .\n', qualifier, qual_ns);
   if (gen_stat)
     {
       ns := ns || sprintf ('@prefix %s-stat: <http://%s/%s/stat#> .\n', lcase (qualifier), virtuoso_ini_item_value ('URIQA','DefaultHost'),
			    qualifier);
       ns := ns || '@prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .\n';
       ns := ns || '@prefix void: <http://rdfs.org/ns/void#> .\n';
       ns := ns || '@prefix scovo: <http://purl.org/NET/scovo#> .\n';
     }
   ns := ns || '@prefix aowl: <http://bblfish.net/work/atom-owl/2006-06-06/> .\n';
   ns := ns || rdf_view_ns_get (cols, 1);
   ns := ns || '\n';

   uriqa_str := registry_get ('URIQADefaultHost');
   graph := 'http://' || uriqa_str || '/' || qualifier || '#';
   create_view_stmt := ns;
   for (declare inx int, inx := 0; inx < length (_tbls) ; inx := inx + 1)
      create_view_stmt := create_view_stmt || '\n' || DB.DBA.R2RML_CREATE_DATASET (inx, qualifier, qual_ns, _tbls, gen_stat, cols, pkcols, graph) || '';

   return create_view_stmt;
}
;

create procedure
DB.DBA.R2RML_QUAL_NOTATION (in qualifier varchar, in qual_ns varchar, in loc varchar)
{
  if (sprintf ('%U', loc) = loc)
    return concat (qualifier, ':', loc);
  return sprintf ('<%s:%U>', qual_ns, loc);
}
;

create procedure
DB.DBA.R2RML_CREATE_DATASET (in nth int, in qualifier varchar, in qual_ns varchar, in _tbls any, in gen_stat int := 0, in cols any, in pkcols any, in graph varchar := null)
{
   declare ret, qual, qual_l, tbl_name, tbl_name_l, pks, pk_text, uriqa_str, graph_def any;
   declare suffix, tname, tbl, own, pref_l any;
   declare cols_arr, inx, col_name, owner, owner_l any;

   ret := '';
   suffix := '_s';
   uriqa_str := registry_get ('URIQADefaultHost');
   qual := name_part (_tbls[nth], 0);
   own := name_part (_tbls[nth], 1);
   qual_l := lcase (qual);
   pref_l := lcase (qualifier);
   tbl := _tbls[nth];
   cols_arr := get_keyword (tbl, cols);
   tbl_name := name_part (tbl, 2);
   owner := name_part (tbl, 1);
   tbl_name_l := rdf_view_tb (tbl_name);
   owner_l := rdf_view_tb (owner);
   tname := tbl_name_l || suffix;
   pks := get_keyword (tbl, pkcols);

   pk_text := '';
   for (declare i any, i := 0; i < length (pks) ; i := i + 1)
      pk_text := pk_text || sprintf ('/%U={%s}', pks[i][0], pks[i][0]);

   if (graph is not null)
     graph_def := sprintf ('rr:graph <%s> ', graph);
    else
     graph_def := '';
   ret := ret || sprintf ('<#TriplesMap%U> a rr:TriplesMap; rr:logicalTable [ rr:tableSchema "%s" ; rr:tableOwner "%s" ; rr:tableName "%s" ]; \n',
     tbl_name, qual, own, tbl_name );
   ret := ret || sprintf ('rr:subjectMap [ rr:termtype "IRI"  ; rr:template "http://%s/%s/%s%s"; rr:class %s; %s];\n',
     uriqa_str, qual, tbl_name_l, pk_text, DB.DBA.R2RML_QUAL_NOTATION (qualifier, qual_ns, rdf_view_cls_name (tbl_name)), graph_def );

   inx := 0;
   for select "COLUMN", COL_DTP from TABLE_COLS where "TABLE" = tbl and "COLUMN" <> '_IDN' order by COL_ID do
     {
       col_name := "COLUMN";
       if (not exists (select 1 from SYS_FOREIGN_KEYS where FK_TABLE = tbl and FKCOLUMN_NAME = col_name))
         ret := ret || sprintf ('rr:predicateObjectMap [ rr:predicateMap [ rr:constant %s ] ; rr:objectMap [ rr:column "%s" ]; ] ;\n',
           DB.DBA.R2RML_QUAL_NOTATION (qualifier, qual_ns, lower (col_name)), col_name );
       inx := inx + 1;
     }
   for select distinct PK_TABLE as pkt from SYS_FOREIGN_KEYS where FK_TABLE = tbl and PK_TABLE <> tbl do
     {
       pk_text := '';
       for select FKCOLUMN_NAME from SYS_FOREIGN_KEYS where FK_TABLE = tbl and PK_TABLE = pkt order by KEY_SEQ do
         pk_text := pk_text || sprintf ('/%U={%s}', FKCOLUMN_NAME, FKCOLUMN_NAME);
       ret := ret || sprintf ('rr:predicateObjectMap [ rr:predicateMap [ rr:constant %s ] ; rr:objectMap [ rr:termtype "IRI" ; rr:template "http://%s/%s/%s%s" ]; ] ;\n',
         DB.DBA.R2RML_QUAL_NOTATION (qualifier, qual_ns, concat (tbl_name_l, '_has_', lower (name_part (pkt, 3)))),
         uriqa_str, qual, lower (name_part (pkt, 3)), pk_text );
	 }
   for select distinct FK_TABLE as fkt from SYS_FOREIGN_KEYS where PK_TABLE = tbl and position (FK_TABLE, _tbls)  do
     {
       declare jc varchar;
       jc := '';
       pk_text := '';
       for select FKCOLUMN_NAME, PKCOLUMN_NAME from SYS_FOREIGN_KEYS where FK_TABLE = fkt and PK_TABLE = tbl order by KEY_SEQ do
   	 {
   	   jc := jc || sprintf (' rr:joinCondition [ rr:child "%s" ; rr:parent "%s" ] ;', PKCOLUMN_NAME, FKCOLUMN_NAME);
           pk_text := pk_text || sprintf ('/%U={%s}', FKCOLUMN_NAME, FKCOLUMN_NAME);
   	 }
       if (tbl <> fkt)
	 {
           ret := ret || sprintf ('rr:predicateObjectMap [ rr:predicateMap [ rr:constant %s ] ; rr:objectMap [ rr:parentTriplesMap <#TriplesMap%U>; %s ]; ] ;\n',
             DB.DBA.R2RML_QUAL_NOTATION (qualifier, qual_ns, concat (tbl_name_l, '_of_', lower (name_part (fkt, 3)))),
             name_part (fkt, 3), jc );
	 }
       else
	 {
           ret := ret || sprintf ('rr:predicateObjectMap [ rr:predicateMap [ rr:constant %s ] ; rr:objectMap [ rr:termtype "IRI" ; rr:template "http://%s/%s/%s%s" ]; ] ;\n',
             DB.DBA.R2RML_QUAL_NOTATION (qualifier, qual_ns, concat (tbl_name_l, '_has_', lower (name_part (fkt, 3)))),
             uriqa_str, qual, lower (name_part (fkt, 3)), pk_text );
	 }
     }

   ret := rtrim (ret, ';\n') || '.\n';
   return ret;
}
;
