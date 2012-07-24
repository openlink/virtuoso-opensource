--
-- Converter from R2RML graph to SPARQL-BI declaration of RDF Views.
--
-- The implemented version of the spec is "Overview.html,v 1.59 2011/05/24 19:22:21 rcygania2 Exp"
--  
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--  
--  Copyright (C) 1998-2012 OpenLink Software
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



DB.DBA.XML_SET_NS_DECL (	'rr'	, 'http://www.w3.org/ns/r2rml#'		, 2)
;

DB.DBA.XML_SET_NS_DECL (	'exa'	, 'http://example.com/ns#'		, 1)
;

EXEC_STMT ('drop type DB.DBA.R2RML_MAP', 0)
;

create type DB.DBA.R2RML_MAP as (
    graph_iid IRI_ID,		--!< IRI_ID of a graph with R2RML description in question. Set by constructor, constant after that
    triplesmap_metas_cache any,	--!< Dictionary with rr:TriplesMap IRI_IDs as keys and metadata vectors of tables/SQLQueries as values
-- Metadata vector is (('TABLE'/'QUERY', schema, owner, text), (column_name, (NULL, column_name, column_metas), ...))
    declared_jsos any,		--!< Dictionary with IRI_IDs of all JSOs that have the 'create' source code written into codegen_ses
    declared_ns_prefixes any,	--!< Dictionary with namespace IRIs as keys and theird declared prefixes as values
    declared_tmap_aliases any,	--!< Dictionary with TripleMap IRI_IDs as keys and aliases of tables/queries as values
    used_fld_tmap_aliases any,	--!< Vector of vectors of table/query aliases used in G, S, P, O and WHERE of the current map.
    default_constg IRI_ID,	--!< Default constant graph of quad map, if not a variable and if single value
    prev_p_md5 varchar,		--!< Checksum of last printed predicate of QM declaration
    codegen_ses any		--!< String output for the generated SPARQL text
  ) self as ref
constructor method R2RML_MAP (in graph_iid IRI_ID),
method R2RML_DEST_IID_OF_THING (in src_iid IRI_ID, in depth_limit integer) returns IRI_ID,
method R2RML_ADD_NS_PREFIX_TO_CACHE (in iri varchar) returns integer,
method R2RML_FILL_NS_PREFIXES_CACHE () returns integer,
method R2RML_IRI_ID_AS_QNAME (in iid any) returns varchar,
method R2RML_FILL_TRIPLESMAP_METAS_CACHE () returns integer,
method R2RML_TRIPLESMAP_TABLE_REPORT_NAME (in triplesmap_iid IRI_ID) returns varchar,
method R2RML_GET_COL_DESC (in triplesmap_iid IRI_ID, in col_name varchar) returns any, --!< Returns vector (triplesmap_iid, triplesmap_metas[0], column_metas)
method R2RML_GEN_CONST_FLD (in constfld any, in termtype varchar, in dt IRI_ID, in lang varchar) returns integer,
method R2RML_RESET_USES_OF_TMAPS (in fld_idx integer) returns any,
method R2RML_REGISTER_USE_OF_TMAP (in fld_idx integer, in tmap IRI_ID) returns varchar,
method R2RML_GEN_CREATE_IOL_CLASS_OR_REF (in fld_idx integer, in mode integer, in triplesmap_iid IRI_ID, in src_template varchar, in termtype varchar, in dt IRI_ID, in lang varchar) returns IRI_ID,
method R2RML_GEN_FLD (in fld_idx integer, in constfld any, in triplesmap_iid IRI_ID, in col varchar, in src_template varchar, in termtype varchar, in dt IRI_ID, in lang varchar) returns integer,
method R2RML_VALIDATE () returns any,
method R2RML_MAKE_QM_IMPL_IOL_CLASSES () returns any,
method R2RML_MAKE_QM_IMPL_CHILDS (in needs_inner_g_field integer) returns any,
method R2RML_MAKE_QM_IMPL_REL_PO (in tmap IRI_ID, in tmap2 IRI_ID, in tmap2sfld IRI_ID, in pofld IRI_ID, in pconst IRI_ID, in pfld IRI_ID, in rofld IRI_ID) returns any,
method R2RML_MAKE_QM_IMPL_PLAIN_PO (in tmap IRI_ID, in pofld IRI_ID, in pconst IRI_ID, in pfld IRI_ID, in oconst any, in ofld IRI_ID) returns any,
method R2RML_MAKE_QM (in storage_iid IRI_ID, in rdfview_iid IRI_ID) returns any
;

create constructor method R2RML_MAP (in graph_iid IRI_ID) for DB.DBA.R2RML_MAP
{
  self.graph_iid := graph_iid;
  self.codegen_ses := null;
  self.declared_ns_prefixes := dict_new (31);

}
;

create function DB.DBA.R2RML_MD5_IRI (inout box any) returns varchar
{
  declare hex, md5, res varchar;
  declare i integer;
  -- return sprintf ('%U', serialize (box));
  md5 := md5_box (box);
  res := space (32);
  hex := '0123456789abcdef';
  for (i := 0; i < 16; i := i + 1)
    {
      res[i*2] := hex[md5[i]/16];
      res[i*2+1] := hex[mod(md5[i],16)];
    }
  return res;
}
;

create method R2RML_DEST_IID_OF_THING (in src_iid IRI_ID, in depth_limit integer := 10) for DB.DBA.R2RML_MAP
{
  declare parts_agg any;
  if (src_iid is null)
    return NULL;
  if (src_iid < min_bnode_iri_id())
    return src_iid;
  if (0 > depth_limit)
    signal ('R2RML', 'Cyclic dependency in R2RML data or an abnormal nesting depth');
  depth_limit := depth_limit - 1;
  vectorbld_init (parts_agg);
  for (sparql define input:storage "" define output:valmode "LONG"
    select ?p ?o where { graph `iri(?:self.graph_iid)` { `iri(?:src_iid)` ?p ?o } } ) do
    {
      if (isiri_id ("o"))
        vectorbld_agg (parts_agg, self.R2RML_DEST_IID_OF_THING ("o", depth_limit));
      else
        vectorbld_agg (parts_agg, md5_box ("o"));
    }
  vectorbld_final (parts_agg);
  gvector_sort (parts_agg, 1, 0, 0);
  return 'r2rml:virt01-' || DB.DBA.R2RML_MD5_IRI (parts_agg);
}
;

create function R2RML_NS_OF_IRI (in iri varchar) returns varchar
{
  declare irilen, patchedlen, taillen integer;
  declare patched varchar;
  if (iri = '')
    return null;
  if (subseq (iri, 0, 2) = '_:')
    return null;         -- 0123456789
  if (subseq (iri, 0, 9) = 'nodeID://')
    return null;
  patched := sprintf ('%U', iri);
  irilen := length (iri);
  patchedlen := length (patched);
  for (taillen := 0; taillen < irilen; taillen := taillen + 1)
    {
      if (iri[irilen-(1+taillen)] <> patched[patchedlen-(1+taillen)])
        goto found_diff;
    }
found_diff:
  if (taillen >= irilen)
    return NULL;
  return subseq (iri, 0, irilen-taillen);
}
;

create method R2RML_ADD_NS_PREFIX_TO_CACHE (in iri varchar) returns integer for DB.DBA.R2RML_MAP
{
  declare ns varchar;
  declare prefx varchar;
  ns := DB.DBA.R2RML_NS_OF_IRI (iri);
  if (ns is null)
    return 0;
  prefx := dict_get (self.declared_ns_prefixes, ns, null);
  if (prefx is not null)
    return 0;
  prefx := coalesce (__xml_get_ns_prefix (ns, 3), sprintf ('ns%d', dict_size (self.declared_ns_prefixes)));
  dict_put (self.declared_ns_prefixes, ns, prefx);
  http ('prefix ' || prefx || ': <' || ns || '>\n', self.codegen_ses);
}
;

create method R2RML_FILL_NS_PREFIXES_CACHE () returns integer for DB.DBA.R2RML_MAP
{
  for (sparql define input:storage ""
    select distinct ?i where { graph `iri(?:self.graph_iid)` {
              {
                ?s ?p ?i .
                filter (?p in (rr:graph, rr:subject, rr:predicate, rr:object))
              }
            union
              {
                ?i a ?t .
                filter (?t in (rr:GraphMap, rr:SubjectMap, rr:PredicateObjectMap, rr:PredicateMap, rr:ObjectMap))
              }
            filter (isIRI (?i)) } }
    order by asc (str (?i)) ) do
    {
      self.R2RML_ADD_NS_PREFIX_TO_CACHE ("i");
    }
  return dict_size (self.declared_ns_prefixes);
}
;

create method R2RML_IRI_ID_AS_QNAME (in iid any) returns varchar for DB.DBA.R2RML_MAP
{
  declare iri, ns varchar;
  if (isstring (iid))
    {
      iri := iid;
      if (subseq (iri, 0, 2) = '_:')
        return iri;          -- 0123456789
      if (subseq (iri, 0, 9) = 'nodeID://')
        return '_:' || subseq (iri, 9);
    }
  else
    {
      if (iid >= min_bnode_iri_id ())
        {
          if (iid >= min_named_bnode_iri_id ())
            return '<' || id_to_iri (iid) || '>';
          return '_:' || subseq (id_to_iri (iid), 9);
        }
      iri := id_to_iri (iid);
    }
  ns := DB.DBA.R2RML_NS_OF_IRI (iri);
  if (ns is not null)
    {
      declare prefx varchar;
      prefx := dict_get (self.declared_ns_prefixes, ns, null);
      if (prefx is not null)
        return prefx || ':' || subseq (iri, length (ns));
    }
  return '<' || iri || '>';
}
;

create function DB.DBA.R2RML_UNQUOTE_NAME (in name varchar) returns varchar
{
  if (name like '"%"')
    name := subseq (name, 1, length (name) - 1);
  if (strchr (name, '"') is not null)
    signal ('R2RML', 'Invalid or unsupported type of SQL name: "' || name || '"');
  return name;
}
;

create method R2RML_FILL_TRIPLESMAP_METAS_CACHE () returns integer for DB.DBA.R2RML_MAP
{
  self.triplesmap_metas_cache := dict_new (11);
  for (sparql define input:storage ""
    select distinct ?triplesmap ?q ?ts ?to ?tn where { graph `iri(?:self.graph_iid)` {
            ?triplesmap a rr:TriplesMap .
            optional { ?triplesmap rr:logicalTable ?ltbl }
              { ?lt rr:sqlQuery ?q }
            UNION
              { ?lt rr:tableName ?tn .
                OPTIONAL { ?lt rr:tableOwner ?to }
                OPTIONAL { ?lt rr:tableSchema ?ts } }
            filter (?lt in (?triplesmap, ?ltbl)) } } ) do
    {
      declare triplesmap_iid IRI_ID;
      declare text_to_prepare, stat, msg varchar;
      declare exec_metas, all_metas any;
      declare colctr, colcount integer;
      triplesmap_iid := iri_to_id ("triplesmap");
      if (dict_get (self.triplesmap_metas_cache, triplesmap_iid, NULL) is not null)
        signal ('R2RML', 'Multiple declaration of data source for <' || "triplesmap" || '>');
      all_metas := vector (null, null);
      if ("q" is not null)
        {
          while (("q" <> '') and strchr (' \t\r\n', chr ("q" [length ("q") - 1])) is not null)
            "q" := "LEFT" ("q", length ("q") - 1);
          if (("q" <> '') and ';' = chr ("q" [length ("q") - 1]))
            "q" := "LEFT" ("q", length ("q") - 1);
          all_metas[0] := vector ('QUERY', null, null, "q");
          text_to_prepare := "q";
        }
      else
        {
          all_metas[0] := vector ('TABLE', DB.DBA.R2RML_UNQUOTE_NAME (coalesce ("ts", 'DB')), DB.DBA.R2RML_UNQUOTE_NAME (coalesce ("to", 'DBA')), DB.DBA.R2RML_UNQUOTE_NAME ("tn"));
          text_to_prepare := sprintf ('select * from "%I"."%I"."%I"', all_metas[0][1], all_metas[0][2], all_metas[0][3]);
        }
      stat := '00000';
      exec_metadata (text_to_prepare, stat, msg, exec_metas);
      if (stat <> '00000')
        signal ('R2RML', 'Error ' || stat || ' in declaration of data source for <' || "triplesmap" || '>: ' || msg || '; failed test query is ' || text_to_prepare);
      if (exec_metas[1] <> 1)
        signal ('R2RML', 'The declaration of data source for <' || "triplesmap" || '> is a potentially dangerous DML');
      exec_metas := exec_metas[0];
      colcount := length (exec_metas);
      all_metas[1] := make_array (colcount*2, 'any');
      for (colctr := 0; colctr < colcount; colctr := colctr + 1)
        {
          all_metas[1][colctr*2] := exec_metas[colctr][0];
          all_metas[1][colctr*2+1] := exec_metas[colctr];
        }
      dict_put (self.triplesmap_metas_cache, triplesmap_iid, all_metas);
    }
  return dict_size (self.triplesmap_metas_cache);
}
;

create function DB.DBA.R2RML_MAIN_KEY_EXISTS (in q varchar, in u varchar, in n varchar, in case_prec integer := 0)
{
  if (case_prec)
    return (select top 1 KEY_TABLE from DB.DBA.SYS_KEYS
      where KEY_IS_MAIN and 0 = casemode_strcmp (sprintf ('%s.%s.%s', coalesce (q, 'DB'), coalesce (u, 'DBA'), n), KEY_TABLE) );
  return (select top 1 KEY_TABLE from DB.DBA.SYS_KEYS
    where KEY_IS_MAIN and sprintf ('%s.%s.%s', coalesce (q, 'DB'), coalesce (u, 'DBA'), n) = KEY_TABLE );
}
;

grant execute on DB.DBA.R2RML_MAIN_KEY_EXISTS to public
;

create function DB.DBA.R2RML_KEY_COLUMN_EXISTS (in q varchar, in u varchar, in n varchar, in c varchar, in case_prec integer := 0)
{
  if (case_prec)
    return (select top 1 "COLUMN" from DB.DBA.SYS_KEY_COLUMNS
      where 0 = casemode_strcmp (sprintf ('%s.%s.%s', coalesce (q, 'DB'), coalesce (u, 'DBA'), n), "TABLE")
      and 0 = casemode_strcmp (c, "COLUMN") );
  return (select top 1 "COLUMN" from DB.DBA.SYS_KEY_COLUMNS
    where sprintf ('%s.%s.%s', coalesce (q, 'DB'), coalesce (u, 'DBA'), n) = "TABLE"
    and c = "COLUMN" );
}
;

grant execute on DB.DBA.R2RML_KEY_COLUMN_EXISTS to public
;

create method R2RML_TRIPLESMAP_TABLE_REPORT_NAME (in triplesmap_iid IRI_ID) returns varchar for DB.DBA.R2RML_MAP
{
  declare all_metas any;
  all_metas := dict_get (self.triplesmap_metas_cache, triplesmap_iid, null);
  if (dict_get (self.triplesmap_metas_cache, triplesmap_iid, NULL) is null)
    return '(Undeclared data source <' || id_to_iri (triplesmap_iid) || '>)';
  for (sparql define input:storage ""
    select ?q ?tn ?to where { graph `iri(?:self.graph_iid)` {
            ?triplesmap a rr:TriplesMap .
            filter (?triplesmap = iri(?:triplesmap_iid))
            optional { ?triplesmap rr:logicalTable ?ltbl }
              { ?lt rr:sqlQuery ?q }
            UNION
              { ?lt rr:tableName ?tn .
                OPTIONAL { ?lt rr:tableOwner ?to }
                OPTIONAL { ?lt rr:tableSchema ?ts } }
            filter (?lt in (?triplesmap, ?ltbl)) } } ) do
    {
      if ("q" is not null)
        return 'query in TriplesMap <' || id_to_iri (triplesmap_iid) || '>';
      if ("to" is null)
        return 'table ' || "tn";
      else
        return 'table DB.' || "to" || '.' || "tn";
    }
}
;

create method R2RML_GET_COL_DESC (in triplesmap_iid IRI_ID, in col_name varchar) returns any for DB.DBA.R2RML_MAP
{
  declare all_metas, res any;
  all_metas := dict_get (self.triplesmap_metas_cache, triplesmap_iid, null);
  if (dict_get (self.triplesmap_metas_cache, triplesmap_iid, NULL) is null)
    signal ('R2RML', 'Undeclared data source <' || id_to_iri (triplesmap_iid) || '>');
  res := get_keyword (col_name, all_metas[1], null);
  if (res is null)
    signal ('R2RML', 'Data source <' || id_to_iri (triplesmap_iid) || '> does not produce column "' || col_name || '"');
  res := vector (triplesmap_iid, all_metas[0], res);
  -- dbg_obj_princ ('R2RML_GET_COL_DESC (', triplesmap_iid, col_name, ') returns ', res);
  return res;
}
;

create function DB.DBA.R2RML_SPLIT_TEMPLATE (in strg varchar) returns any
{
  declare splitlbra, parts any;
  declare ctr, len, rbra_idx integer;
  splitlbra := split_and_decode (strg, 0, '\0\0{');
  len := length (splitlbra);
  parts := make_array ((len * 2) - 1, 'any');
  if (strchr (splitlbra[0], '}') is not null)
    signal ('R2RML', 'Syntax error in template: first "}" is before first "{"');
  parts[0] := splitlbra[0];
  for (ctr := 1; ctr < len; ctr := ctr + 1)
    {
      rbra_idx := strchr (splitlbra[ctr], '}');
      if (rbra_idx is null)
        signal ('R2RML', 'Syntax error in template: "{" without matching "}"');
      parts[ctr*2-1] := DB.DBA.R2RML_UNQUOTE_NAME (subseq (splitlbra[ctr], 0, rbra_idx));
      parts[ctr*2] := subseq (splitlbra[ctr], rbra_idx+1);
    }
  return parts;
}
;

create method R2RML_GEN_CONST_FLD (in constfld any, in termtype varchar, in dt IRI_ID, in lang varchar) returns integer for DB.DBA.R2RML_MAP
{
  if ((termtype in ('http://www.w3.org/ns/r2rml#IRI', 'http://www.w3.org/ns/r2rml#BlankNode'))
    or (__tag (constfld) = __tag of IRI_ID)
    or (isstring (constfld) and bit_and (__box_flags (constfld), 1)) )
    {
      http (self.R2RML_IRI_ID_AS_QNAME (constfld), self.codegen_ses);
      return 0;
    }
  if (__tag (constfld) = __tag of RDF_BOX)
    {
      http ('"', self.codegen_ses);
      http_escape (__rdf_strsqlval (constfld), 11, self.codegen_ses, 1, 1);
      http ('"', self.codegen_ses);
      if (dt is null)
        {
          declare dt_twobytes integer;
          dt_twobytes := rdf_box_type (constfld);
          if (257 <> dt_twobytes)
            dt := iri_to_id ((select RDT_QNAME from DB.DBA.RDF_DATATYPE where RDT_TWOBYTE = dt_twobytes));
        }
      if (lang is null)
        {
          declare lang_twobytes integer;
          lang_twobytes := rdf_box_lang (constfld);
          if (257 <> lang_twobytes)
            lang := (select RL_ID from DB.DBA.RDF_LANGUAGE where RL_TWOBYTE = lang_twobytes);
        }
    }
  else if (__tag of XML = __tag (constfld))
    {
      http ('"', self.codegen_ses);
      http_escape (serialize_to_UTF8_xml (constfld), 11, self.codegen_ses, 1, 1);
      http ('"', self.codegen_ses);
    }
  else if (isstring (constfld) or (__tag of XML = __tag (constfld)))
    {
      http ('"', self.codegen_ses);
      http_escape (constfld, 11, self.codegen_ses, 1, 1);
      http ('"', self.codegen_ses);
    }
  else
    {
      http ('"', self.codegen_ses);
      http_escape (cast (constfld as varchar), 11, self.codegen_ses, 1, 1);
      http ('"', self.codegen_ses);
      if (dt is null)
        dt := iri_to_id (__xsd_type (constfld, null));
    }
  if (dt is not null)
    {
      http ('^^', self.codegen_ses);
      self.R2RML_IRI_ID_AS_QNAME (dt);
    }
  else if (isstring (lang))
    {
      http ('@', self.codegen_ses);
      http (lang, self.codegen_ses);
    }
  return 0;
}
;

create function DB.DBA.R2RML_XSD_TYPE_OF_DTP (in dtp integer)
{
  if (__tag of datetime = dtp) return 'http://www.w3.org/2001/XMLSchema#dateTime';
  if (__tag of date = dtp) return 'http://www.w3.org/2001/XMLSchema#date';
  if (__tag of time = dtp) return 'http://www.w3.org/2001/XMLSchema#time';
  if (dtp in (__tag of varchar, __tag of nvarchar, __tag of long varchar, __tag of long nvarchar)) return NULL;
  if (__tag of integer = dtp) return 'http://www.w3.org/2001/XMLSchema#integer';
  if (__tag of double precision = dtp) return 'http://www.w3.org/2001/XMLSchema#double';
  if (__tag of numeric = dtp) return 'http://www.w3.org/2001/XMLSchema#double';
  if (__tag of real = dtp) return 'http://www.w3.org/2001/XMLSchema#float';
  if (230) return 'http://www.w3.org/2001/XMLSchema#XMLLiteral';
  if (238) return 'http://www.openlinksw.com/schemas/virtrdf#Geometry';
  return 'http://www.w3.org/2001/XMLSchema#any';
}
;

create method R2RML_RESET_USES_OF_TMAPS (in fld_idx integer) returns any for DB.DBA.R2RML_MAP
{
  declare all_aliases any;
  all_aliases := self.used_fld_tmap_aliases;
  all_aliases[fld_idx] := vector ();
  self.used_fld_tmap_aliases := all_aliases;
  -- dbg_obj_princ ('R2RML_RESET_USES_OF_TMAPS (', fld_idx, ') resulted in ', self.used_fld_tmap_aliases);
}
;

create method R2RML_REGISTER_USE_OF_TMAP (in fld_idx integer, in tmap IRI_ID) returns varchar for DB.DBA.R2RML_MAP
{
  declare alias varchar;
  declare all_aliases any;
  alias := dict_get (self.declared_tmap_aliases, tmap, null);
  if (alias is null)
    signal ('R2RML', sprintf ('The table source "%s" is used but not defined, maybe strange R2RML', tmap));
  all_aliases := self.used_fld_tmap_aliases;
  if (0 >= position (alias, all_aliases[fld_idx]))
    {
      all_aliases[fld_idx] := vector_concat (all_aliases[fld_idx], vector (alias));
      self.used_fld_tmap_aliases := all_aliases;
    }
  -- dbg_obj_princ ('R2RML_REGISTER_USE_OF_TMAP (', fld_idx, tmap, ') resulted in ', self.used_fld_tmap_aliases);
  return alias;
}
;

create method R2RML_GEN_CREATE_IOL_CLASS_OR_REF (in fld_idx integer, in mode integer, in triplesmap_iid IRI_ID, in src_template varchar, in termtype varchar, in dt IRI_ID, in lang varchar) returns IRI_ID for DB.DBA.R2RML_MAP
{
  declare format_string, class_iri varchar;
  declare format_ses, format_parts, col_descs, argtypes, class_digest any;
  declare argctr, argcount integer;
  -- dbg_obj_princ ('R2RML_GEN_CREATE_IOL_CLASS_OR_REF (', fld_idx, mode, triplesmap_iid, src_template, termtype, dt, lang, ')');
  if (termtype = 'http://www.w3.org/ns/r2rml#BlankNode')
    {
      src_template := '_:r2rml' || src_template;
      termtype := 'http://www.w3.org/ns/r2rml#IRI';
    }
  format_parts := DB.DBA.R2RML_SPLIT_TEMPLATE (src_template);
  argcount := (length (format_parts) - 1) / 2;
  if (0 = argcount) -- constant written as a template for some reason.
    {
      if (2 = mode) -- i.e., CREATE IRI CLASS or CREATE LITERAL CLASS statement
        self.R2RML_GEN_CONST_FLD (src_template, termtype, dt, lang);
      return null;
    }
  argtypes := make_array (argcount, 'any');
  col_descs := make_array (argcount, 'any');
  format_ses := string_output ();
  for (argctr := 0; argctr < argcount; argctr := argctr + 1)
    {
      declare col_name, coltype, col_fmt varchar;
      declare col_desc any;
      col_name := format_parts[argctr * 2 + 1];
      col_desc := self.R2RML_GET_COL_DESC (triplesmap_iid, col_name);
      col_descs[argctr] := col_desc;
      if (col_desc is null)
        signal ('R2RML', sprintf ('The column "%s" is used in template "%s" but not in result set of <%s>', col_name, src_template, id_to_iri (triplesmap_iid)));
      coltype := col_desc[2];
      argtypes[argctr] := vector (coltype[1], coltype[4]);
      col_fmt := case
        when (coltype[1] in (__tag of date, __tag of datetime, __tag of datetime)) then '%D'
        when (coltype[1] in (__tag of integer)) then '%d'
        when (coltype[1] in (__tag of real, __tag of double precision, __tag of numeric)) then '%g'
        when (coltype[1] in (__tag of varchar, __tag of nvarchar)) then
          case (termtype) when 'http://www.w3.org/ns/r2rml#Literal' then '%s' else '%U' end
        else
          signal ('R2RML',
            sprintf ('Unsupported column type %d, column %s of %s',
              coltype[1], col_desc[2][0], self.R2RML_TRIPLESMAP_TABLE_REPORT_NAME (triplesmap_iid) ) )
        end;
      http_escape (replace (format_parts[argctr * 2], '%', '%%'), 11, format_ses);
      http (col_fmt, format_ses);
    }
  http_escape (replace (format_parts[argcount * 2], '%', '%%'), 11, format_ses);
  format_string := string_output_string (format_ses);
  class_digest := vector (termtype, format_string, argtypes, dt, lang);
  class_iri := 'r2rml:virt02-' || DB.DBA.R2RML_MD5_IRI (class_digest);
  if (1 = mode) -- i.e., CREATE IRI CLASS or CREATE LITERAL CLASS statement
    goto create_iol_class;
  if (2 = mode) -- i.e., quad map value in form class_iri (args)
    goto print_field;
  signal ('R2RML', 'iternal error: bad mode');
create_iol_class:
  if (dict_get (self.declared_jsos, class_iri, null) is null)
    {
      http ('create ' || subseq (termtype, length ('http://www.w3.org/ns/r2rml#'))  || ' class <' || class_iri || '> "' || format_string || '" (', self.codegen_ses);
      for (argctr := 0; argctr < argcount; argctr := argctr + 1)
        {
          declare argdtp integer;
          declare argname varchar;
          argdtp := argtypes[argctr][0];
          argname := format_parts[argctr * 2 + 1];
          if (argname <> sprintf ('%U', argname))
            argname := sprintf ('%s_n%d', replace (replace (sprintf ('%U', argname), '+', '_'), '%', '__'), argctr);
          if (argctr > 0)
            http (', ', self.codegen_ses);
          http ('in ' || argname || ' ' ||
            case (argdtp)
              when __tag of date then 'date'
              when __tag of time then 'time'
              when __tag of datetime then 'datetime'
              when __tag of integer then 'integer'
              when __tag of real then 'real'
              when __tag of double precision then 'double precision'
              when __tag of numeric then 'numeric'
              when __tag of varchar then 'varchar'
              when __tag of nvarchar then 'nvarchar'
              else 'any' end ||
            case (argtypes[argctr][0]) when 0 then ' not null' else '' end,
            self.codegen_ses );
        }
      http (') ', self.codegen_ses);
      if (dt is not null or lang is not null)
        {
          http ('option (', self.codegen_ses);
          if (dt is not null)
            {
              http ('datatype ', self.codegen_ses);
              http (self.R2RML_IRI_ID_AS_QNAME (dt), self.codegen_ses);
            }
          if (lang is not null)
            {
              http ('lang "', self.codegen_ses);
              http_escape (lang, 11, self.codegen_ses);
              http ('"', self.codegen_ses);
            }
          http (') ', self.codegen_ses);
        }
      http ('.\n', self.codegen_ses);
      dict_put (self.declared_jsos, class_iri, class_digest);
    }
  return iri_to_id (class_iri);
print_field:
  http ('<' || class_iri || '> (', self.codegen_ses);
  for (argctr := 0; argctr < argcount; argctr := argctr + 1)
    {
      declare col_desc any;
      if (argctr > 0)
        http (', ', self.codegen_ses);
      col_desc := col_descs[argctr]; -- col_desc is a vector (triplesmap_iid, all_metas[0], (NULL, column_name, column_metas));
      -- dbg_obj_princ ('R2RML_GEN_CREATE_IOL_CLASS_OR_REF(): desc #', argctr, ' is ', col_desc);
      http (self.R2RML_REGISTER_USE_OF_TMAP (fld_idx, col_desc[0]), self.codegen_ses);
      http ('."', self.codegen_ses);
      http_escape (col_desc[2][0], 11, self.codegen_ses);
      http ('"', self.codegen_ses);
    }
  http (')', self.codegen_ses);
  return iri_to_id (class_iri);
}
;

create method R2RML_GEN_FLD (in fld_idx integer, in constfld any, in triplesmap_iid IRI_ID, in col varchar, in src_template varchar, in termtype varchar, in dt IRI_ID, in lang varchar) returns integer for DB.DBA.R2RML_MAP
{
  self.R2RML_RESET_USES_OF_TMAPS (fld_idx);
  if (src_template is not null)
    self.R2RML_GEN_CREATE_IOL_CLASS_OR_REF (fld_idx, 2, triplesmap_iid, src_template, termtype, dt, lang);
  else if (col is not null)
    {
      if ((termtype <> 'http://www.w3.org/ns/r2rml#Literal') or (dt is not null) or (lang is not null))
        self.R2RML_GEN_CREATE_IOL_CLASS_OR_REF (fld_idx, 2, triplesmap_iid, '{' || col || '}', termtype, dt, lang);
      else
        {
          declare col_desc any;
          col_desc := self.R2RML_GET_COL_DESC (triplesmap_iid, col);
          http (self.R2RML_REGISTER_USE_OF_TMAP (fld_idx, col_desc[0]), self.codegen_ses);
          http (sprintf ('."%I"', col), self.codegen_ses);
        }
    }
  else if (constfld is not null)
    return self.R2RML_GEN_CONST_FLD (constfld, termtype, dt, lang);
  else
    signal ('R2RML', 'FLD without const, col or src_template');
  return 0;
}
;

create method R2RML_MAKE_QM_IMPL_IOL_CLASSES () returns any for DB.DBA.R2RML_MAP
{
  foreach (varchar dflttt in vector ('http://www.w3.org/ns/r2rml#IRI', 'http://www.w3.org/ns/r2rml#Literal')) do
    {
      for (sparql define input:storage ""
        select ?triplesmap ?fldmap ?template ?termtype ?dt ?lang
        where { graph `iri(?:self.graph_iid)` {
                ?triplesmap a rr:TriplesMap .
                  { ?triplesmap rr:subjectMap [ rr:graphMap ?fldmap ] }
                union
                  { ?triplesmap rr:predicateObjectMap [ rr:graphMap ?fldmap ] }
                union
                  { ?triplesmap rr:subjectMap ?fldmap }
                union
                  { ?triplesmap rr:predicateObjectMap [ rr:predicateMap ?fldmap ] }
                union
                  { ?triplesmap rr:predicateObjectMap [ rr:objectMap ?fldmap ] }
                ?fldmap rr:template ?template .
                optional { ?fldmap rr:termType ?termtype . }
                optional { ?fldmap rr:datatype ?dt . }
                optional { ?fldmap rr:language ?lang . }
              } } ) do
        {
          self.R2RML_GEN_CREATE_IOL_CLASS_OR_REF (-1, 1, iri_to_id ("triplesmap"), "template", coalesce (cast ("termtype" as varchar), dflttt), iri_to_id ("dt"), "lang");
        }
    }
  for (sparql define input:storage ""
    select ?triplesmap ?fldmap ?col ?termtype
    where { graph `iri(?:self.graph_iid)` {
            ?triplesmap a rr:TriplesMap .
              { ?triplesmap rr:subjectMap [ rr:graphMap ?fldmap ] }
            union
              { ?triplesmap rr:predicateObjectMap [ rr:graphMap ?fldmap ] }
            union
              { ?triplesmap rr:subjectMap ?fldmap }
            union
              { ?triplesmap rr:predicateObjectMap [ rr:predicateMap ?fldmap ] }
            ?fldmap rr:column ?col .
            optional { ?fldmap rr:termType ?termtype . }
          } } ) do
    {
      self.R2RML_GEN_CREATE_IOL_CLASS_OR_REF (-1, 1, iri_to_id ("triplesmap"), '{' || DB.DBA.R2RML_UNQUOTE_NAME ("col") || '}', coalesce (cast ("termtype" as varchar), 'http://www.w3.org/ns/r2rml#IRI'), null, null);
    }
  for (sparql define input:storage ""
    select ?triplesmap ?fldmap ?col ?termtype ?dt ?lang
    where { graph `iri(?:self.graph_iid)` {
            ?triplesmap a rr:TriplesMap .
            ?triplesmap rr:predicateObjectMap [ rr:objectMap ?fldmap ] .
            ?fldmap rr:column ?col .
            optional { ?fldmap rr:termType ?termtype . }
            optional { ?fldmap rr:datatype ?dt . }
            optional { ?fldmap rr:language ?lang . } } } ) do
    {
      if ((("termtype" is not null) and ("termtype" <> 'http://www.w3.org/ns/r2rml#Literal')) or ("dt" is not null) or ("lang" is not null))
        self.R2RML_GEN_CREATE_IOL_CLASS_OR_REF (-1, 1, iri_to_id ("triplesmap"), '{' || DB.DBA.R2RML_UNQUOTE_NAME ("col") || '}', coalesce ("termtype", 'http://www.w3.org/ns/r2rml#Literal'), iri_to_id ("dt"), "lang");
    }
}
;

create method R2RML_MAKE_QM_IMPL_REL_PO (in tmap IRI_ID, in tmap2 IRI_ID, in tmap2sfld IRI_ID, in pofld IRI_ID, in pconst IRI_ID, in pfld IRI_ID, in rofld IRI_ID) returns any for DB.DBA.R2RML_MAP
{
  declare p_md5 varchar;
  declare where_is_opened integer;
  -- dbg_obj_princ ('R2RML_MAKE_QM: cross from ', "tmap", ' to ', "tmap2" );
  for (sparql define input:storage "" define output:valmode "LONG"
    select ?constp, ?consto, ?ocol, ?otmpl, ?ott
    where { graph `iri(?:self.graph_iid)` {
              { `iri(?:pofld)` rr:predicate ?constp . filter (?constp = iri(?:pconst)) }
            union
              { `iri(?:pfld)` rr:constant ?constp }
              { `iri(?:tmap2)` rr:subject ?consto }
            union
              { `iri(?:tmap2sfld)` rr:constant ?consto }
            union
              { `iri(?:tmap2sfld)` rr:column ?ocol }
            union
              { `iri(?:tmap2sfld)` rr:template ?otmpl }
            optional { `iri(?:tmap2sfld)` rr:termType ?ott }
          } }
    order by 1 2 3 4 5) do
    {
      p_md5 := md5_box (vector (__rdf_strsqlval ("constp"), null, null));
      if (self.prev_p_md5 is null or self.prev_p_md5 <> p_md5)
        {
          if (self.prev_p_md5 is not null)
            {
              http (' ;\n', self.codegen_ses);
              self.prev_p_md5 := null;
            }
          http ('                    ', self.codegen_ses);
          self.R2RML_GEN_FLD (2 /* for P */, "constp", tmap, NULL, NULL, 'http://www.w3.org/ns/r2rml#IRI', null, null);
          http (' ', self.codegen_ses);
          self.prev_p_md5 := p_md5;
        }
      else
          http (',\n                            ', self.codegen_ses);
      self.R2RML_GEN_FLD (3 /* for O */, "consto", tmap2, DB.DBA.R2RML_UNQUOTE_NAME (__rdf_strsqlval("ocol")), __rdf_strsqlval("otmpl"), coalesce (__rdf_strsqlval("ott"), 'http://www.w3.org/ns/r2rml#IRI'), NULL, NULL);
      where_is_opened := 0;
      self.R2RML_RESET_USES_OF_TMAPS (4 /* for WHERE condition */);
      for (sparql define input:storage ""
        select ?child ?parent
        where { graph `iri(?:self.graph_iid)` {
                `iri(?:rofld)` rr:joinCondition [ rr:child ?child ; rr:parent ?parent ] } }
        order by 1 2) do
        {
          self.R2RML_GET_COL_DESC (tmap, DB.DBA.R2RML_UNQUOTE_NAME ("child"));
          self.R2RML_GET_COL_DESC (tmap2, DB.DBA.R2RML_UNQUOTE_NAME ("parent"));
          http (case (where_is_opened) when 0 then ' where ((' else ') and (' end, self.codegen_ses);
          http (sprintf ('^{%s.}^."%I" = ^{%s.}^."%I"',
              self.R2RML_REGISTER_USE_OF_TMAP (4 /* for WHERE condition */, tmap), DB.DBA.R2RML_UNQUOTE_NAME ("child"),
              self.R2RML_REGISTER_USE_OF_TMAP (4 /* for WHERE condition */, tmap2), DB.DBA.R2RML_UNQUOTE_NAME ("parent") ),
            self.codegen_ses);
          where_is_opened := 1;
        }
      if (where_is_opened)
        {
          declare all_aliases, where_aliases, extra_aliases any;
          declare fld_idx, alias_ctr, alias_count integer;
          http ('))', self.codegen_ses);
          all_aliases := self.used_fld_tmap_aliases;
          where_aliases := all_aliases[4];
          extra_aliases := vector ();
          foreach (varchar wa in where_aliases) do
            {
              for (fld_idx := 0; fld_idx < 4; fld_idx := fld_idx + 1)
                {
                  if (0 < position (wa, all_aliases[fld_idx]))
                    goto wa_done;
                }
              extra_aliases := vector_concat (extra_aliases, vector (wa));
wa_done: ;
            }
          alias_count := length (extra_aliases);
          if (alias_count)
            {
              http (' OPTION (', self.codegen_ses);
              for (alias_ctr := 0; alias_ctr < alias_count; alias_ctr := alias_ctr + 1)
                {
                  if (alias_ctr)
                    http (', ', self.codegen_ses);
                  http ('USING ' || extra_aliases[alias_ctr], self.codegen_ses);
                }
              http (' )', self.codegen_ses);
            }
        }
    }
}
;

create method R2RML_MAKE_QM_IMPL_PLAIN_PO (in tmap IRI_ID, in pofld IRI_ID, in pconst IRI_ID, in pfld IRI_ID, in oconst any, in ofld IRI_ID) returns any  for DB.DBA.R2RML_MAP
{
  declare p_md5 varchar;
  for (sparql define input:storage "" define output:valmode "LONG"
    select ?constp, ?pcol, ?ptmpl, ?consto, ?ocol, ?otmpl, ?ott, ?odatatype, ?lang
    where { graph `iri(?:self.graph_iid)` {
              { `iri(?:pofld)` rr:predicate ?constp . filter (?constp = iri(?:pconst)) }
            union
              { `iri(?:pfld)` rr:constant ?constp }
            union
              { `iri(?:pfld)` rr:column ?pcol }
            union
              { `iri(?:pfld)` rr:template ?ptmpl }
              { `iri(?:pofld)` rr:object ?consto . filter (?consto = iri(?:oconst)) }
            union
              { `iri(?:ofld)` rr:constant ?consto }
            union
              { `iri(?:ofld)` rr:column ?ocol }
            union
              { `iri(?:ofld)` rr:template ?otmpl }
            optional { `iri(?:ofld)` rr:termType ?ott }
            optional { `iri(?:ofld)` rr:datatype ?odatatype }
            optional { `iri(?:ofld)` rr:language ?olang }
          } }
    order by 1 2 3 4 5 6 7 8 9) do
    {
      p_md5 := md5_box (vector (__rdf_strsqlval("constp"), DB.DBA.R2RML_UNQUOTE_NAME (__rdf_strsqlval("pcol")), __rdf_strsqlval("ptmpl")));
      if (self.prev_p_md5 is null or self.prev_p_md5 <> p_md5)
        {
          if (self.prev_p_md5 is not null)
            {
              http (' ;\n', self.codegen_ses);
              self.prev_p_md5 := null;
            }
          http ('                    ', self.codegen_ses);
          self.R2RML_GEN_FLD (2 /* for P */, "constp", tmap, DB.DBA.R2RML_UNQUOTE_NAME (__rdf_strsqlval("pcol")), __rdf_strsqlval("ptmpl"), 'http://www.w3.org/ns/r2rml#IRI', null, null);
          http (' ', self.codegen_ses);
          self.prev_p_md5 := p_md5;
        }
      else
          http (',\n                            ', self.codegen_ses);
      self.R2RML_GEN_FLD (3 /* for O */, "consto", tmap, DB.DBA.R2RML_UNQUOTE_NAME (__rdf_strsqlval("ocol")), __rdf_strsqlval("otmpl"), coalesce (__rdf_strsqlval("ott"), 'http://www.w3.org/ns/r2rml#Literal'), "odatatype", __rdf_strsqlval("lang"));
    }
}
;

create method R2RML_MAKE_QM_IMPL_CHILDS (in needs_inner_g_field integer) returns any for DB.DBA.R2RML_MAP
{
  declare prev_g_md5, prev_s_md5 any;
  -- For each combination of mapclasses and graph
  prev_g_md5 := prev_s_md5 := null;
  self.prev_p_md5 := null;
  for (sparql define input:storage "" define output:valmode "LONG"
    select ?constg, ?gcol, ?gtmpl, ?tmap, ?sfld, ?consts, ?scol, ?stmpl, ?stt, ?sclass, ?pofld, ?pconst, ?pfld, ?oconst, ?ofld, ?tmap2, ?tmap2sfld
    where { graph `iri(?:self.graph_iid)` {
            ?tmap a rr:TriplesMap .
              { ?tmap rr:subject ?consts }
            union
              {
                ?tmap rr:subjectMap ?sfld .
                  { ?sfld rr:constant ?consts }
                union
                  { ?sfld rr:column ?scol }
                union
                  { ?sfld rr:template ?stmpl }
                optional { ?sfld rr:termType ?stt }
              }
              {
                ?sfld rr:class ?sclass .
              }
            union
              {
                ?tmap rr:predicateObjectMap ?pofld .
                  { ?pofld rr:predicate ?pconst }
                union
                  { ?pofld rr:predicateMap ?pfld }
                  { ?pofld rr:object ?oconst }
                union
                  { ?pofld rr:objectMap ?ofld
                    optional {
                        ?ofld rr:parentTriplesMap ?tmap2 .
                        ?tmap2 a rr:TriplesMap ;
                          rr:subjectMap ?tmap2sfld . }
                  }
              }
            optional {
                  { ?gcontainer rr:graph ?constg . }
                union
                  {
                    ?gcontainer rr:graphMap ?gfld .
                      { ?gfld rr:constant ?constg }
                    union
                      { ?gfld rr:column ?gcol }
                    union
                      { ?gfld rr:template ?gtmpl } }
                filter (?gcontainer in (?sfld, ?pofld)) }
          } }
    order by 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16) do
    {
      declare s_md5, p_md5 varchar;
      -- dbg_obj_princ ('R2RML_MAKE_QM: g is ', "constg", "gcol", "gtmpl", '; tmap is ', "tmap", '; s is ', "sfld", "consts", "scol", "stmpl", "stt", "sclass", '; po is ', "pconst", "pfld", ' and ', "oconst", "ofld");
      if (needs_inner_g_field)
        {
          declare g_md5 any;
          g_md5 := md5_box (vector (coalesce ("constg", self.default_constg), DB.DBA.R2RML_UNQUOTE_NAME (__rdf_strsqlval("gcol")), __rdf_strsqlval("gtmpl")));
          if (prev_g_md5 is null or prev_g_md5 <> g_md5)
            {
              if (prev_g_md5 is not null)
                {
                  http (' . }\n', self.codegen_ses);
                  prev_g_md5 := prev_s_md5:= null;
                  self.prev_p_md5 := null;
                  self.R2RML_RESET_USES_OF_TMAPS (1 /* S is reset */);
                  self.R2RML_RESET_USES_OF_TMAPS (2 /* P is reset */);
                  self.R2RML_RESET_USES_OF_TMAPS (3 /* O is reset */);
                }
              http ('        graph ', self.codegen_ses);
              self.R2RML_GEN_FLD (0 /* for G */, coalesce ("constg", self.default_constg), "tmap", DB.DBA.R2RML_UNQUOTE_NAME (__rdf_strsqlval("gcol")), __rdf_strsqlval("gtmpl"), 'http://www.w3.org/ns/r2rml#IRI', null, null);
              http (' {\n', self.codegen_ses);
              prev_g_md5 := g_md5;
            }
        }
      s_md5 := md5_box (vector (__rdf_strsqlval("consts"), DB.DBA.R2RML_UNQUOTE_NAME (__rdf_strsqlval("scol")), __rdf_strsqlval("stmpl"), __rdf_strsqlval("stt")));
      if (prev_s_md5 is null or prev_s_md5 <> s_md5)
        {
          if (prev_s_md5 is not null)
            {
              http (' .\n', self.codegen_ses);
              prev_s_md5 := null;
              self.prev_p_md5 := null;
              self.R2RML_RESET_USES_OF_TMAPS (2 /* P is reset */);
              self.R2RML_RESET_USES_OF_TMAPS (3 /* O is reset */);
           }
          http ('            ', self.codegen_ses);
          self.R2RML_GEN_FLD (1 /* for S */, __rdf_strsqlval("consts"), "tmap", DB.DBA.R2RML_UNQUOTE_NAME (__rdf_strsqlval("scol")), __rdf_strsqlval("stmpl"), coalesce (__rdf_strsqlval("stt"), 'http://www.w3.org/ns/r2rml#IRI'), null, null);
          http ('\n', self.codegen_ses);
          prev_s_md5 := s_md5;
        }
      if ("sclass" is not null)
        {
          p_md5 := 'rdf:type';
          if (self.prev_p_md5 is null or self.prev_p_md5 <> p_md5)
            {
              if (self.prev_p_md5 is not null)
                {
                  http (' ;\n', self.codegen_ses);
                  self.prev_p_md5 := null;
                }
              self.R2RML_RESET_USES_OF_TMAPS (2 /* for P that is printed here as "a" bypassing R2RML_GEN_FLD */);
              http ('                    a ', self.codegen_ses);
              self.prev_p_md5 := p_md5;
            }
          else
              http (',\n                            ', self.codegen_ses);
          self.R2RML_GEN_FLD (3 /* for O */, "sclass", "tmap", null, null, 'http://www.w3.org/ns/r2rml#IRI', null, null);
        }
      else if ("tmap2" is not null)
        {
          self.R2RML_MAKE_QM_IMPL_REL_PO ("tmap", "tmap2", "tmap2sfld", "pofld", "pconst", "pfld", "ofld");
        }
      else
        {
          self.R2RML_MAKE_QM_IMPL_PLAIN_PO ("tmap", "pofld", "pconst", "pfld", "oconst", "ofld");
        }
      self.R2RML_RESET_USES_OF_TMAPS (4 /* for WHERE that is printed already and cannot be reused */);
skip_the_quad_map: ;
    }
  if (needs_inner_g_field)
    {
      if (prev_g_md5 is not null)
        {
          http (' . }\n', self.codegen_ses);
          prev_s_md5 := self.prev_p_md5 := null;
        }
    }
  else
    http (' }\n', self.codegen_ses);
}
;

create method R2RML_MAKE_QM (in storage_iid IRI_ID := null, in rdfview_iid IRI_ID := null) returns any for DB.DBA.R2RML_MAP
{
  declare const_graph_count, var_graph_count, needs_inner_g_field integer;
  declare iter, iter_tmap, iter_metas any;
  if (storage_iid is null)
    storage_iid := iri_to_id ('http://www.openlinksw.com/schemas/virtrdf#DefaultQuadStorage');
  if (rdfview_iid is null)
    rdfview_iid := self.graph_iid;
  if (self.codegen_ses is null)
    self.codegen_ses := string_output ();
  self.R2RML_ADD_NS_PREFIX_TO_CACHE (id_to_iri (storage_iid));
  self.R2RML_ADD_NS_PREFIX_TO_CACHE (id_to_iri (rdfview_iid));
  self.R2RML_FILL_NS_PREFIXES_CACHE ();
  self.declared_jsos := dict_new (31);
  self.declared_tmap_aliases := dict_new (11);
  for (sparql define input:storage "" define output:valmode "LONG"
    select ?triplesmap
    where { graph `iri(?:self.graph_iid)` {
            ?triplesmap a rr:TriplesMap } } ) do
    {
      dict_put (self.declared_tmap_aliases, "triplesmap", sprintf ('tbl%d', dict_size (self.declared_tmap_aliases)));
    }
  if (0 = self.R2RML_FILL_TRIPLESMAP_METAS_CACHE ())
    signal ('R2RML', 'No valid instances of TriplesMap, hence nothing to do');
  self.R2RML_MAKE_QM_IMPL_IOL_CLASSES ();
  const_graph_count := (sparql define input:storage ""
    select count(distinct ?constg)
    where { graph `iri(?:self.graph_iid)` {
            ?tmap a rr:TriplesMap .
            optional {
                { ?tmap rr:subjectMap ?smap }
              union
                { ?tmap rr:predicateObjectMap ?pomap } }
              { ?gcontainer rr:graph ?constg }
            union
              {
                ?gcontainer rr:graphMap ?gfld .
                ?gfld rr:constant ?constg }
            filter (?gcontainer in (?smap, ?pomap)) } } );
  var_graph_count := (sparql define input:storage ""
    select count(distinct bif:concat (str(?tmap), ' ', ?c, ' ', ?t))
    where { graph `iri(?:self.graph_iid)` {
            ?tmap a rr:TriplesMap .
            optional {
                { ?tmap rr:subjectMap ?smap }
              union
                { ?tmap rr:predicateObjectMap ?pomap } }
            ?gcontainer rr:graphMap ?gfld .
              { ?gfld rr:column ?c }
            union { ?gfld rr:template ?t }
            filter (?gcontainer in (?smap, ?pomap)) } } );
--  -- dbg_obj_princ ('const_graph_count = ', const_graph_count, ', var_graph_count = ', var_graph_count);
  http ('alter quad storage ' || self.R2RML_IRI_ID_AS_QNAME (storage_iid) || '\n', self.codegen_ses);
  iter := self.triplesmap_metas_cache;
  for (dict_iter_rewind (iter); dict_iter_next (iter, iter_tmap, iter_metas); )
    {
      declare tos_alias varchar;
      tos_alias := dict_get (self.declared_tmap_aliases, iter_tmap, null);
      if ('TABLE' = iter_metas[0][0])
        http ('from "' || iter_metas[0][1] || '"."' || iter_metas[0][2] || '"."' || iter_metas[0][3] || '" as ' || tos_alias || '\n', self.codegen_ses);
      else
        http ('from sqlquery (' || iter_metas[0][3] || ') as ' || tos_alias || '\n', self.codegen_ses);
    }
  http ('  {\n', self.codegen_ses);
  self.used_fld_tmap_aliases := vector (vector(), vector(), vector(), vector(), vector());
  http ('    create ' || self.R2RML_IRI_ID_AS_QNAME (rdfview_iid) || ' as', self.codegen_ses);
  if (self.default_constg is null) 
    self.default_constg := iri_to_id (sprintf ('http://example.com/r2rml?graph=%U', id_to_iri(self.graph_iid)));
  if ((const_graph_count + var_graph_count) <= 1)
    {
      http (' graph ', self.codegen_ses);
      if (0 = var_graph_count)
        {
          declare constg IRI_ID;
          constg := (sparql define input:storage "" define output:valmode "LONG"
            select ?constg
            where { graph `iri(?:self.graph_iid)` {
                    ?tmap a rr:TriplesMap .
                    optional {
                        { ?tmap rr:subjectMap ?smap }
                      union
                        { ?tmap rr:predicateObjectMap ?pomap } }
                      { ?gcontainer rr:graph ?constg }
                    union
                      {
                        ?gcontainer rr:graphMap ?gfld .
                        ?gfld rr:constant ?constg }
                    filter (?gcontainer in (?smap, ?pomap)) } } );
          if (constg is null)
            constg := self.default_constg;
          self.R2RML_GEN_FLD (0 /* for G */, constg, null, null, null, 'http://www.w3.org/ns/r2rml#IRI', null, null);
          http (' option (soft exclusive)', self.codegen_ses);
        }
      else
        {
          for (sparql define input:storage ""
            select ?tmap, ?c, ?t
            where { graph `iri(?:self.graph_iid)` {
            ?tmap a rr:TriplesMap .
            optional {
                { ?tmap rr:subjectMap ?smap }
              union
                { ?tmap rr:predicateObjectMap ?pomap } }
            ?gcontainer rr:graphMap ?gfld .
              { ?gfld rr:column ?c }
            union { ?gfld rr:template ?t }
            filter (?gcontainer in (?smap, ?pomap)) } } limit 1 ) do
            {
              self.R2RML_GEN_FLD (0 /* for G */, null, iri_to_id ("tmap"), DB.DBA.R2RML_UNQUOTE_NAME ("c"), "t", 'http://www.w3.org/ns/r2rml#IRI', null, null);
            }
        }
      needs_inner_g_field := 0;
    }
  else
    needs_inner_g_field := 1;
  http (' {\n', self.codegen_ses);
  self.R2RML_MAKE_QM_IMPL_CHILDS (needs_inner_g_field);
  http ('  }\n', self.codegen_ses);
}
;

create function R2RML_MAKE_QM_FROM_G (in g varchar, in tgt_graph varchar := null) returns varchar
{
  declare m R2RML_MAP;
  m := DB.DBA.R2RML_MAP (iri_to_id (g));
  m.default_constg := iri_to_id (tgt_graph);
  m.R2RML_MAKE_QM (null, null);
  return string_output_string (m.codegen_ses);
}
;

create function R2RML_TEST (in g varchar)
{
  declare m R2RML_MAP;
  m := DB.DBA.R2RML_MAP (iri_to_id (g));
  m.R2RML_MAKE_QM (null, null);
  -- return string_output_string (m.codegen_ses);
  declare _text varchar;
  declare _strings any;
  declare _slen, _sctr any;
  result_names (_text);
  _text := string_output_string (m.codegen_ses);
  _strings := split_and_decode (_text,0,'\0\0\n');
  _slen := length (_strings);
  _sctr := 0;
  while (_sctr < _slen)
    {
      result (aref (_strings, _sctr));
      _sctr := _sctr+1;
    }
}
;

create procedure R2RML_GENERATE_LINKED_VIEW (in source varchar, in destination_graph varchar, in graph_type int := 0, in clear_source_graph int := 1)
{
  declare str, vstr, mime, vgraph, get_url varchar;
  if (source like 'dav:%')
    get_url := 'virt://WS.WS.SYS_DAV_RES.RES_FULL_PATH.RES_CONTENT:' || subseq (source, 4);
  else
    get_url := source;
  str := XML_URI_GET ('', get_url);
  mime := DB.DBA.RDF_SPONGE_GUESS_CONTENT_TYPE (source, '', str);
  if (clear_source_graph)
    {
      sparql clear graph iri(?:source) ;
    }
  if (mime = 'application/rdf+xml')
    DB.DBA.RDF_LOAD_RDFXML (str, source, source);
  else 
    DB.DBA.TTLP (str, source, source);
  if (graph_type = 0)
    vgraph := destination_graph;
  else
    vgraph := sprintf ('http://example.com/r2rml?graph=%U', source);
  if (graph_type = 1)
    {
      if (exists (sparql define input:storage "" prefix rr: <http://www.w3.org/ns/r2rml#> ask { graph `iri(?:source)` { [] rr:graphMap ?m . ?m rr:template ?g }}))
	signal ('42000', 'Can not sync graph template to physical graph');
    }
  vstr := DB.DBA.R2RML_MAKE_QM_FROM_G (source, vgraph);
  exec ('sparql ' || vstr);
  if (graph_type = 1)
    {
      RDF_VIEW_SYNC_TO_PHYSICAL (vgraph, 1, destination_graph);
      for select "g" from (sparql define input:storage "" prefix rr: <http://www.w3.org/ns/r2rml#> 
      	select distinct ?g  { graph `iri(?:source)` {{ ?s rr:graph ?g } union { ?s rr:graphMap ?m . ?m rr:constant ?g }}}) x do
	{
	  RDF_VIEW_SYNC_TO_PHYSICAL ("g", 1, destination_graph);
	}
    }  
}
;
