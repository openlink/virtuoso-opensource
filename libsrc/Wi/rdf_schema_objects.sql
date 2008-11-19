--
--  $Id$
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  RDF Schema objects, generator of RDF Views
--
--  Copyright (C) 1998-2008 OpenLink Software
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

create procedure
RDF_VIEW_FROM_TBL (in qualifier varchar, in _tbls any)
{
   declare create_class_stmt, create_view_stmt, sparql_pref, ns, uriqa_str, ret, drop_map any;
   ret := make_array (2, 'any');
   sparql_pref := 'SPARQL\n';
   uriqa_str := '^{URIQADefaultHost}^';
   drop_map := 'SPARQL drop quad map virtrdf:'|| qualifier ||'\n;\n\n';
   ns := sprintf ('prefix %s: <http://%s/%s#>\n', qualifier, cfg_item_value(virtuoso_ini_path(), 'URIQA','DefaultHost'), qualifier);
   create_class_stmt := '';

   for (declare xx any, xx := 0; xx < length (_tbls) ; xx := xx + 1)
     create_class_stmt := create_class_stmt || rdf_view_create_class (_tbls[xx], uriqa_str, qualifier);

   create_class_stmt := sparql_pref || ns || create_class_stmt || '\n;\n\n';
   create_view_stmt := rdf_view_create_view (qualifier, _tbls);
   create_view_stmt := sparql_pref || ns || create_view_stmt || '\n;\n\n';
   return drop_map || create_class_stmt || create_view_stmt;
}
;

create procedure
rdf_view_sp (in i int)
{
  return repeat (' ', i);
}
;

create procedure
rdf_view_create_view (in qualifier varchar, in _tbls any)
{
   declare ret, qual, qual_l, tbl_name, tbl_name_l, pks, pk_text, uriqa_str any;
   declare suffix, tname, tbl any;

   uriqa_str := '^{URIQADefaultHost}^';
   qual := name_part (_tbls[0], 0);
   qual_l := lcase (qual);

   ret := 'alter quad storage virtrdf:DefaultQuadStorage \n';
   suffix := '_s';

   for (declare xx any, xx := 0; xx < length (_tbls) ; xx := xx + 1)
      ret := ret || ' from ' || _tbls[xx] || ' as ' || lcase (name_part (_tbls[xx], 3) || suffix) || '\n';

   ret := ret || rdf_view_get_relations (_tbls, suffix);

   ret := ret || ' { \n   create virtrdf:' || qual ||
   ' as graph iri ("http://' || uriqa_str || '/' || qual_l || '") option (exclusive) \n    { \n';

   for (declare xx any, xx := 0; xx < length (_tbls) ; xx := xx + 1)
      {
	   tbl := _tbls[xx];
	   tbl_name := name_part (tbl, 2);
	   tbl_name_l := lcase (tbl_name);
	   tname := tbl_name_l || suffix;

	   ret := ret || rdf_view_sp (6) || '# Maps from columns of ' || tbl || '\n';
	   ret := ret || rdf_view_sp (6) || rdf_view_get_pk_rel (qualifier, suffix, tbl, 0);
	   ret := ret || sprintf (' a %s:%s ;\n', qualifier, tbl_name);

	   for select "COLUMN" from SYS_COLS where "TABLE" = tbl order by COL_ID do
	     {
	       ret := ret || rdf_view_sp (6) || sprintf ('%s:%s %s.%s as virtrdf:%s-%s ;\n',
				qualifier, lcase("COLUMN"), tname, "COLUMN", tbl_name_l, lcase("COLUMN") );
	     }
	   if (exists (select top 1 1 from SYS_FOREIGN_KEYS where PK_TABLE = tbl and 0 < position (FK_TABLE, _tbls))
	       or
	       exists (select top 1 1 from SYS_FOREIGN_KEYS where FK_TABLE = tbl and 0 < position (PK_TABLE, _tbls)))
	   ret := ret || rdf_view_sp (6) || '# Maps from foreign-key relations of ' || tbl || '\n';
	   ret := ret || rdf_view_get_fk_pk_rel (qualifier, suffix, tbl, _tbls);
	   ret := ret || rdf_view_get_pk_fk_rel (qualifier, suffix, tbl, _tbls);

   	    ret := trim (ret, '\n');
   	    ret := trim (ret, ';');
   	    ret := ret || '.\n\n';
      }

   ret := ret || '    }\n }';
   return ret;
}
;

create procedure
rdf_view_get_pk_rel (in pref varchar, in suffix varchar, inout tbl varchar, in set_tb int := 0)
{
  declare pks any;
  declare tbl_name, tbl_name_l, tname, pk_text, ret varchar;

  pks := rdf_view_get_primary_key (tbl);
  tbl_name := name_part (tbl, 3);
  tbl_name_l := lcase (tbl_name);
  pks := rdf_view_get_primary_key (tbl);
  tname := tbl_name_l || suffix;
  pk_text := '';

  for (declare i any, i := 0; i < length (pks) ; i := i + 1)
     pk_text := pk_text || tname || '.' || pks[i][0] || ',';
  pk_text := trim (pk_text, ',');
  ret := sprintf ('%s:%s (%s) ', pref, tbl_name_l, pk_text);
  if (set_tb)
    tbl := tbl_name_l;
  return ret;
}
;

create procedure
rdf_view_get_fk_pk_rel (in pref varchar, in suffix varchar, in tbl varchar, in tbls any)
{
  declare ret any;
  declare tbl_name, tbl_name_l, tname, pk_text varchar;

  tbl_name := name_part (tbl, 3);
  tbl_name_l := lcase (tbl_name);
  tname := tbl_name_l || suffix;

  ret := string_output ();
  for select distinct PK_TABLE as pkt from SYS_FOREIGN_KEYS where FK_TABLE = tbl and 0 < position (PK_TABLE, tbls) do
    {
      declare fk_rel  any;
      pk_text := rdf_view_get_pk_rel (pref, suffix, pkt, 1);
      fk_rel := rdf_view_sp (6) || sprintf ('%s:has_%s %s as virtrdf:%s_has_%s ;\n', pref, pkt, pk_text, tbl_name_l, pkt);
      http (fk_rel, ret);
    }
  return string_output_string (ret);
}
;

create procedure
rdf_view_get_pk_fk_rel (in pref varchar, in suffix varchar, in tbl varchar, in tbls any)
{
  declare ret any;
  declare tbl_name, tbl_name_l, tname, pk_text varchar;

  tbl_name := name_part (tbl, 3);
  tbl_name_l := lcase (tbl_name);
  tname := tbl_name_l || suffix;

  ret := string_output ();
  for select distinct FK_TABLE as pkt from SYS_FOREIGN_KEYS where PK_TABLE = tbl and 0 < position (FK_TABLE, tbls) do
    {
      declare fk_rel  any;
      pk_text := rdf_view_get_pk_rel (pref, suffix, pkt, 1);
      fk_rel := rdf_view_sp (6) || sprintf ('%s:%s_of %s as virtrdf:%s_%s_of ;\n', pref, tbl_name_l, pk_text, tbl_name_l, pkt);
      http (fk_rel, ret);
    }
  return string_output_string (ret);
}
;

create procedure
rdf_view_dv_to_printf_str_type (in _dv varchar)
{
   if (_dv = 189 or _dv = 188) return '%d';
   else if (_dv = 182) return '%U';
   else if (__tag of float = _dv) return '%f';
   else if (__tag of real = _dv) return '%f';
   else if (__tag of numeric = _dv) return '%f';
   else if (__tag of date = _dv) return '%1D';
   else if (__tag of time = _dv) return '%1D';
   else if (__tag of datetime = _dv) return '%1D';
   signal ('42000', sprintf ('The current implementation do no supports data type %s (%i) for IRI classes', dv_type_title (_dv), _dv));
}
;

create procedure
rdf_view_dv_to_sql_str_type (in _dv varchar)
{
   if (_dv = 189 or _dv = 188) return 'integer';
   else if (_dv = 182 or _dv = 125 or _dv = 131) return 'varchar';
   else if (__tag of float = _dv) return 'float';
   else if (__tag of real = _dv) return 'float';
   else if (__tag of numeric = _dv) return 'numeric';
   else if (__tag of date = _dv) return 'date';
   else if (__tag of time = _dv) return 'time';
   else if (__tag of datetime = _dv) return 'datetime';
   signal ('42000', sprintf ('The current implementation do no supports data type %s (%i) for IRI classes', dv_type_title (_dv), _dv));
}
;

create procedure
rdf_view_create_class (in _tbl varchar, in _host varchar, in qualifier varchar)
{
   declare ret, qual, tbl_name, tbl_name_l, pks, pk_text, sk_str any;

   qual := name_part (_tbl, 0);
   tbl_name := name_part (_tbl, 3);
   tbl_name_l := lcase (tbl_name);
   pks := rdf_view_get_primary_key (_tbl);
   pk_text := '';
   sk_str := '';

   if (length (pks) = 0)
     signal ('22023', sprintf ('This version do not support tables without primary key, please remove table %s from set', _tbl));

   for (declare i any, i := 0; i < length (pks) ; i := i + 1)
     {
       pk_text := pk_text || 'in ' || pks[i][0] || ' ' || rdf_view_dv_to_sql_str_type(pks[i][1]) || ' not null,';
       sk_str := sk_str || '/' || pks[i][0] || '/' || rdf_view_dv_to_printf_str_type (pks[i][1]);
     }
   pk_text := trim (pk_text, ',');
   sk_str  := trim (sk_str , '/');
   ret := sprintf ('create iri class %s:%s "http://%s/%s/%s/%s#this" (%s) . \n',
		qualifier, tbl_name_l, _host, qualifier, tbl_name_l, sk_str, pk_text);
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
rdf_view_get_relations (in _tbls varchar, in _suff varchar)
{
   declare ret any;

   ret := '';
   foreach (any tbl in _tbls) do
       for (SELECT name_part (PK_TABLE, 1) as PK_TABLE_SCHEMA, PK_TABLE,
	   name_part (PK_TABLE, 2) as PK_TABLE_NAME, PKCOLUMN_NAME as PK_COLUMN_NAME,
	   name_part (FK_TABLE, 1) as FK_TABLE_SCHEMA,
	   name_part (FK_TABLE, 2) as FK_TABLE_NAME, FKCOLUMN_NAME AS FK_COLUMN_NAME,
	   KEY_SEQ, UPDATE_RULE, DELETE_RULE, FK_NAME
	   FROM DB.DBA.SYS_FOREIGN_KEYS WHERE FK_TABLE like tbl) do

	 {
	   if (position (PK_TABLE, _tbls) <> 0)
	     {
	       ret := ret || sprintf (' where (^{%s%s.}^."%s" = ^{%s%s.}^."%s") \n',
	       lcase (FK_TABLE_NAME), _suff, FK_COLUMN_NAME,
	       lcase (PK_TABLE_NAME), _suff, PK_COLUMN_NAME);
	     }
	 }
   return ret;
}
;

create procedure
RDF_OWL_FROM_TBL (in qual varchar, in _tbls any)
{
  declare ses any;
  declare ns varchar;
  ns := sprintf ('@prefix %s: <http://%s/%s#> .\n', qual, cfg_item_value(virtuoso_ini_path(), 'URIQA','DefaultHost'), qual);
  ses := string_output ();
  http ('@prefix owl: <http://www.w3.org/2002/07/owl#> .\n', ses);
  http ('@prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .\n', ses);
  http ('@prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .\n', ses);
  http ('@prefix xsd: <http://www.w3.org/2001/XMLSchema#> .\n', ses);
  http (ns, ses);
  http (sprintf ('\n%s: a owl:Ontology .\n', qual), ses);
  foreach (varchar tbl in _tbls) do
    {
      http (sprintf ('\n# %s\n', tbl), ses);
      http (sprintf ('%s:%s a rdfs:Class .\n', qual, name_part (tbl, 2)), ses);
      http (sprintf ('%s:%s rdfs:label "%s" .\n', qual, name_part (tbl, 2), tbl), ses);
      for select "COLUMN" as col, COL_DTP as dtp from SYS_COLS where "TABLE" = tbl order by COL_ID do
	{
	  declare xsd varchar;
	  col := lower (col);
	  http (sprintf ('%s:%s a rdf:Property .\n', qual, col), ses);
	  http (sprintf ('%s:%s rdfs:domain %s:%s .\n', qual, col, qual, name_part (tbl, 2)), ses);
	  xsd := rdf_view_dv_to_sql_str_type (dtp);
	  http (sprintf ('%s:%s rdfs:range xsd:%s .\n', qual, col, xsd), ses);
	  http (sprintf ('%s:%s rdfs:label "%s" .\n', qual, col, col), ses);
	}
      for select distinct PK_TABLE as pkt from SYS_FOREIGN_KEYS where FK_TABLE = tbl and 0 < position (PK_TABLE, _tbls) do
	{
	  http (sprintf ('%s:has_%s a rdf:Property .\n', qual, lcase (name_part (pkt, 2))), ses);
	  http (sprintf ('%s:has_%s rdfs:domain %s:%s .\n', qual, lcase (name_part (pkt, 2)), qual, name_part (tbl, 2)), ses);
	  http (sprintf ('%s:has_%s rdfs:range %s:%s .\n', qual, lcase (name_part (pkt, 2)), qual, name_part (pkt, 2)), ses);
	  http (sprintf ('%s:has_%s rdfs:label "Relation to %s" .\n', qual, lcase (name_part (pkt, 2)), pkt), ses);
	}
      for select distinct FK_TABLE as pkt from SYS_FOREIGN_KEYS where PK_TABLE = tbl and 0 < position (FK_TABLE, _tbls) do
	{
	  http (sprintf ('%s:%s_of a rdf:Property .\n', qual, lcase (name_part (tbl, 2))), ses);
	  http (sprintf ('%s:%s_of rdfs:domain %s:%s .\n', qual, lcase (name_part (tbl, 2)), qual, name_part (tbl, 2)), ses);
	  http (sprintf ('%s:%s_of rdfs:range %s:%s .\n', qual, lcase (name_part (tbl, 2)), qual, name_part (pkt, 2)), ses);
	  http (sprintf ('%s:has_%s rdfs:label "Relation to %s" .\n', qual, lcase (name_part (tbl, 2)), pkt), ses);
	}
    }
  return string_output_string (ses);
}
;

create procedure RDF_VIEW_GEN_VD (in qual varchar)
{
  declare ses, pref any;
  ses := string_output ();
  pref := lower (qual);

  if (
      exists (select 1 from URL_REWRITE_RULE where URR_RULE = pref || '_rule1') or
      exists (select 1 from URL_REWRITE_RULE where URR_RULE = pref || '_rule2') or
      exists (select 1 from URL_REWRITE_RULE where URR_RULE = pref || '_rule3') or
      exists (select 1 from URL_REWRITE_RULE_LIST where URRL_LIST = pref || '_rule_list1') or
      exists (select 1 from HTTP_PATH where HP_HOST = '*ini*' and HP_LISTEN_HOST = '*ini*' and HP_LPATH = '/'||qual)
      )
    return '\n-- WARNING: there are already created virtual directory "/'||qual||'", skipping virtual directory generation\n'||
    '-- WARNING: To avoid this message chose different base URL or drop existing virtual directory and its rewrite rules.\n';

  http (
  'DB.DBA.URLREWRITE_CREATE_REGEX_RULE (
    ''<pref>_rule2'',
    1,
    ''(/[^#]*)'',
    vector(''path''),
    1,
    ''/sparql?query=DESCRIBE+%%3Chttp%%3A//^{URIQADefaultHost}^%U%%23this%%3E+%%3Chttp%%3A//^{URIQADefaultHost}^%U%%3E+FROM+%%3Chttp%%3A//^{URIQADefaultHost}^/<pref>%%3E&format=%U'',
    vector(''path'', ''path'', ''*accept*''),
    null,
    ''(text/rdf.n3)|(application/rdf.xml)'',
    2,
    null
    );', ses);

  http ('\n', ses);

  http (
  'DB.DBA.URLREWRITE_CREATE_REGEX_RULE (
    ''<pref>_rule1'',
    1,
    ''([^#]*)'',
    vector(''path''),
    1,
    ''/about/html/http://^{URIQADefaultHost}^%s'',
    vector(''path''),
    null,
    null,
    2,
    303
    );', ses);
  http ('\n', ses);
  http('DB.DBA.URLREWRITE_CREATE_REGEX_RULE (
      ''<pref>_rule3'',
      1,
      ''/<qual>\x24'',
      vector(),
      1,
      ''/sparql?query=CONSTRUCT+{+%%3fs+%%3fp+%%3fo+}+FROM+%%3Chttp%%3A//^{URIQADefaultHost}^/schemas/<qual>%%23%%3E+WHERE{%%3fs+%%3fp+%%3fo}&format=%U'',
      vector(''*accept*''),
      null,
      ''(text/rdf.n3)|(application/rdf.xml)'',
      2,
      null
      );', ses);
  http ('\n', ses);
  http ('DB.DBA.URLREWRITE_CREATE_RULELIST ( ''<pref>_rule_list1'', 1, vector ( ''<pref>_rule1'', ''<pref>_rule2'', ''<pref>_rule3''));', ses);

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
