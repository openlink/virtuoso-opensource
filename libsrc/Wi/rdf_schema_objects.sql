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
	   tbl_name := name_part (tbl, 3);
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
	   if (
	       exists (select top 1 1 from SYS_FOREIGN_KEYS where PK_TABLE = tbl and 0 < position (FK_TABLE, _tbls))
	       or
	       exists (select top 1 1 from SYS_FOREIGN_KEYS where FK_TABLE = tbl and 0 < position (FK_TABLE, _tbls))
	       )
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
   else if (__tag of numeric = _dv) return '%f';
   signal ('42000', sprintf ('Unsupported data type %i in rdf_view_dv_to_printf_str_type', _dv));
}
;

create procedure
rdf_view_dv_to_sql_str_type (in _dv varchar)
{
   if (_dv = 189 or _dv = 188) return 'integer';
   else if (_dv = 182) return 'varchar';
   else if (__tag of float = _dv) return 'float';
   else if (__tag of numeric = _dv) return 'numeric';
   signal ('42000', sprintf ('Unsupported data type %i', _dv));
}
;

create procedure
rdf_view_create_class (in _tbl varchar, in _host varchar, in _f varchar)
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
		_f, tbl_name_l, _host, _f, tbl_name_l, sk_str, pk_text);
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
   declare ret, tbl any;

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

