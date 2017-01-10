--
--  $Id$
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2017 OpenLink Software
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

-----------------------------------------------------------------------------
--
create procedure ODRIVE.WA.rdf_n3_list_properties (
  inout schemaN3 any,
  in classname varchar)
{
  if (not isentity(schemaN3))
    schemaN3 := xml_tree_doc(schemaN3);
  if (classname is null)
    {
      return xpath_eval ('
let ("excl",
  distinct (
    for ("dom",
      /N3
      [@N3P="http://www.openlinksw.com/schemas/virtrdf#domain"],
      string (\044dom/@N3S) ) ),
  /N3
  [@N3P="http://www.w3.org/1999/02/22-rdf-syntax-ns#type"]
  [@N3O="http://www.w3.org/1999/02/22-rdf-syntax-ns#Property"]
  [not (@N3S = \044excl)]
  /@N3S )',
        schemaN3, 1 );
    }
  return xpath_eval ('
let ("incl",
  distinct (
    for ("dom",
      /N3
      [@N3P="http://www.openlinksw.com/schemas/virtrdf#domain"]
      [@N3O=\044classname],
      string (\044dom/@N3S) ) ),
  /N3
  [@N3P="http://www.w3.org/1999/02/22-rdf-syntax-ns#type"]
  [@N3O="http://www.w3.org/1999/02/22-rdf-syntax-ns#Property"]
  [@N3S=\044incl]
  /@N3S )',
        schemaN3, 1, vector ('classname', classname) );
}
;

-----------------------------------------------------------------------------
--
create procedure ODRIVE.WA.rdf_n3_get_object (
  inout schemaN3 any,
  in subj varchar,
  in pred varchar,
  in ret_list any,
  inout langs any) returns any
{
  declare hits, best_hit any;
  declare minpos integer;
  declare obj any;

  if (not isentity(schemaN3))
    schemaN3 := xml_tree_doc(schemaN3);
  hits := xpath_eval ('/N3[@N3S=\044subj][@N3P=\044pred]', schemaN3, 0, vector (UNAME'subj', subj, UNAME'pred', pred));
  if (length (hits) = 0)
    return null;
  if (ret_list)
  {
    declare ctr, len integer;
    len := length (hits);
    for (ctr := 0; ctr < len; ctr := ctr + 1)
    {
      obj := xpath_eval ('@N3O', hits[ctr]);
      if (obj is null)
        obj := xpath_eval ('node()', hits[ctr]);
      hits[ctr] := obj;
    }
    return hits;
  }
  best_hit := hits[0]; -- to have something if everything else fails
  minpos := 1000000;
  foreach (any hit in hits) do
  {
    declare lang varchar;
    declare lang_pos integer;
    lang := xpath_eval ('@xml:lang', hit);
    if (lang is null)
    {
      if (minpos = 1000000)
        best_hit := hit;
    } else {
      lang_pos := position (cast (lang as varchar), langs);
      if ((lang_pos > 0) and (lang_pos < minpos)) {
        best_hit := hit;
        minpos := lang_pos;
      }
    }
  }
  obj := xpath_eval ('@N3O', best_hit);
  if (obj is null)
    obj := xpath_eval ('node()', best_hit);
  return obj;
}
;

-----------------------------------------------------------------------------
--
create procedure ODRIVE.WA.rdf_n3_base_remove (
  in res varchar) returns varchar
{
  declare delim integer;

  delim := strrchr (res, ':');
  if (delim is not null)
    res := subseq (res, delim + 1);

  delim := strrchr (res, '/');
  if (delim is not null)
    res := subseq (res, delim + 1);

  delim := strrchr (res, '#');
  if (delim is not null)
    res := subseq (res, delim + 1);

  return res;
}
;

-----------------------------------------------------------------------------
--
create procedure ODRIVE.WA.rdf_n3_get_property (
  inout schemaN3 any,
  in subj varchar,
  in prop varchar,
  in langs any,
  in mode integer := 1, -- 1 remove base
  in defValue varchar := null) returns varchar
{
  if (subj is null)
    return 'Resource';

  declare value varchar;

  value := cast (ODRIVE.WA.rdf_n3_get_object (schemaN3, subj, prop, 0, langs) as varchar);
  if (isnull(value))
    value := defValue;
  if (isnull(value) and mode)
    value := ODRIVE.WA.rdf_n3_base_remove(subj);
  return value;
}
;

-----------------------------------------------------------------------------
--
create procedure ODRIVE.WA.rdf_schema_get_property (
  inout schemaN3 any,
  in subject varchar,
  in property varchar,
  in defaultValue varchar := '')
{
  declare exit handler for SQLSTATE '*' {return '';};

  if (property = 'label')
    return ODRIVE.WA.rdf_n3_get_property(schemaN3, subject, 'http://www.w3.org/2000/01/rdf-schema#label', vector(), 0, defaultValue);
  if (property = 'comment')
    return ODRIVE.WA.rdf_n3_get_property(schemaN3, subject, 'http://www.w3.org/2000/01/rdf-schema#comment', vector(), 0, defaultValue);
  if (property = 'version')
    return ODRIVE.WA.rdf_n3_get_property(schemaN3, subject, 'http://www.openlinksw.com/schemas/virtrdf#version', vector(), 0, defaultValue);
  if (property = 'catName')
    return ODRIVE.WA.rdf_n3_get_property(schemaN3, subject, 'http://www.openlinksw.com/schemas/virtrdf#catName', vector(), 0, defaultValue);
  return '';
}
;

-----------------------------------------------------------------------------
--
create procedure ODRIVE.WA.rdf_schema_set_property (
  inout schemaN3 any,
  in subject varchar,
  in property varchar,
  in value varchar := '')
{
  declare S varchar;

  S := '<N3 N3S="%V" N3P="%V">%V</N3>';
  if (property = 'schema') {
    property := 'http://www.w3.org/1999/02/22-rdf-syntax-ns#type';
    value := '/Ontology';
    S := '<N3 N3S="%V" N3P="%V" N3O="%V" />';
  } if (property = 'label') {
    property := 'http://www.w3.org/2000/01/rdf-schema#label';
  } else if (property = 'comment') {
    property := 'http://www.w3.org/2000/01/rdf-schema#comment';
  } else if (property = 'version') {
    property := 'http://www.openlinksw.com/schemas/virtrdf#version';
  } else if (property = 'catName') {
    property := 'http://www.openlinksw.com/schemas/virtrdf#catName';
  } else
    return;

  S := sprintf(S, subject, property, value);
  ODRIVE.WA.rdf_merge (schemaN3, S);
}
;

-----------------------------------------------------------------------------
--
create procedure ODRIVE.WA.rdf_get_property (
  inout schemaN3 any,
  in subject varchar,
  in property varchar,
  in defaultValue varchar := '')
{
  declare langs any;

  langs := vector();
  if (property = 'value')
    return ODRIVE.WA.rdf_n3_get_property(schemaN3, 'http://local.virt/this', subject, langs, 0, defaultValue);
  if (property = 'range')
    return ODRIVE.WA.rdf_n3_get_property(schemaN3, subject, 'http://www.w3.org/2000/01/rdf-schema#Range', langs, 0, defaultValue);
  if (property = 'label')
    return ODRIVE.WA.rdf_n3_get_property(schemaN3, subject, 'http://www.openlinksw.com/schemas/virtrdf#label', langs, 0, defaultValue);
  if (property = 'defaultValue')
    return ODRIVE.WA.rdf_n3_get_property(schemaN3, subject, 'http://www.openlinksw.com/schemas/virtrdf#defaultValue', langs, 0, defaultValue);
  if (property = 'displayOrder')
    return ODRIVE.WA.rdf_n3_get_property(schemaN3, subject, 'http://www.openlinksw.com/schemas/virtrdf#displayOrder', langs, 0, defaultValue);
  if (property = 'access')
    return ODRIVE.WA.rdf_n3_get_property(schemaN3, subject, 'http://www.openlinksw.com/schemas/virtrdf#access', langs, 0, defaultValue);
  return ODRIVE.WA.rdf_n3_get_property(schemaN3, subject, property, langs, 0, defaultValue);
}
;

-----------------------------------------------------------------------------
--
create procedure ODRIVE.WA.rdf_get_property_title (
  in schemaURI any,
  in property varchar,
  in defaultValue varchar := '')
{
  declare N integer;
  declare properties any;

  properties := ODRIVE.WA.dav_rdf_schema_properties_short(schemaURI);
  for (N := 0; N < length(properties); N := N + 6)
    if (property = properties[N])
      return properties[N+1];
  return defaultValue;
}
;

-----------------------------------------------------------------------------
--
create procedure ODRIVE.WA.rdf_get_object_property (
  inout schemaN3 any,
  in subject varchar,
  in object varchar,
  in property varchar,
  in defaultValue varchar := '')
{
  declare langs any;
  declare node varchar;

  if (object = 'displayMode-BrowseExpert')
  {
    node := ODRIVE.WA.rdf_get_property (schemaN3, subject, 'http://www.openlinksw.com/schemas/virtrdf#displayMode-BrowseExpert');
    return ODRIVE.WA.rdf_get_property(schemaN3, node, property, defaultValue);
  }
  return '';
}
;

-----------------------------------------------------------------------------
--
create procedure ODRIVE.WA.rdf_cut_property (
  inout oldN3 any,
  in subject varchar)
{
  declare params, newN3 any;

  if (not isentity(oldN3))
    oldN3 := xml_tree_doc(oldN3);
  xte_nodebld_init(newN3);
  foreach (any N3 in xpath_eval ('/N3', oldN3, 0)) do
  {
    params := xpath_eval('vector (string (@N3S), string (@N3P), string(@xml:lang))', N3);
    if (params[0] <> subject)
    	xte_nodebld_acc(newN3, N3);
  }
  xte_nodebld_final(newN3, xte_head(UNAME' root'));
  return xml_tree_doc(newN3);
}
;

-----------------------------------------------------------------------------
--
create procedure ODRIVE.WA.rdf_set_property (
  inout schemaN3 any,
  in subject varchar,
  in property varchar,
  in value varchar := '')
{
  declare S varchar;

  S := '<N3 N3S="%V" N3P="%V">%V</N3>';
  if (property = 'property') {
    property := 'http://www.w3.org/1999/02/22-rdf-syntax-ns#type';
    value := 'http://www.w3.org/1999/02/22-rdf-syntax-ns#Property';
    S := '<N3 N3S="%V" N3P="%V" N3O="%V" />';
  } else if (property = 'value') {
    subject := 'http://local.virt/this';
  } else if (property = 'range') {
    property := 'http://www.w3.org/2000/01/rdf-schema#Range';
    value := concat('http://www.w3.org/2001/XMLSchema#', value);
    S := '<N3 N3S="%V" N3P="%V" N3O="%V" />';
  } else if (property = 'label') {
    property := 'http://www.openlinksw.com/schemas/virtrdf#label';
  } else if (property = 'hint') {
    property := 'http://www.openlinksw.com/schemas/virtrdf#hint';
  } else if (property = 'defaultValue') {
    property := 'http://www.openlinksw.com/schemas/virtrdf#defaultValue';
  } else
    return;

  S := sprintf(S, subject, property, value);
  ODRIVE.WA.rdf_merge (schemaN3, S);
}
;

-----------------------------------------------------------------------------
--
create procedure ODRIVE.WA.rdf_set_object (
  inout schemaN3 any,
  in subject varchar,
  in object varchar,
  in properties any)
{
  declare N integer;
  declare S varchar;
  declare node any;

  if (object <> 'displayMode-BrowseExpert')
    return;

  object := 'http://www.openlinksw.com/schemas/virtrdf#displayMode-BrowseExpert';
  node := ODRIVE.WA.rdf_get_property (schemaN3, subject, object, concat('nodeID://X', cast(msec_time() as varchar)));
  S := sprintf('<N3 N3S="%V" N3P="%V" N3O="%V" />', subject, object, node);
  N := 0;
  while (N < length(properties))
  {
    S := sprintf('%s<N3 N3S="%V" N3P="%V">%V</N3>', S, node, concat('http://www.openlinksw.com/schemas/virtrdf#', properties[N]), properties[N+1]);
    N := N + 2;
  }
  ODRIVE.WA.rdf_merge (schemaN3, S);
}
;

-----------------------------------------------------------------------------
--
create procedure ODRIVE.WA.rdf_merge (
  inout schemaN3 any,
  in S varchar)
{
  if (isnull(schemaN3))
  {
    schemaN3 := xml_tree_doc(S);
    return;
  }
  declare patchN3 any;

  if (not isentity(schemaN3))
    schemaN3 := xml_tree_doc(schemaN3);
  patchN3 := xml_tree_doc(S);
  schemaN3 := DB.DBA.DAV_RDF_MERGE (schemaN3, patchN3, null, 0);
}
;

-----------------------------------------------------------------------------
--
create procedure ODRIVE.WA.rdf_validate_property (
  in schemaURI varchar,
  in property varchar,
  in propertyValue varchar)
{
  declare exit handler for SQLSTATE '*' {return 0;};

  if (is_empty_or_null(propertyValue))
    return 1;

  declare schemaN3 any;
  declare propertyType any;

  schemaN3 := DB.DBA.DAV_GET_RDF_SCHEMA_N3(schemaURI);
  propertyType := ODRIVE.WA.rdf_n3_base_remove(ODRIVE.WA.rdf_get_property(schemaN3, property, 'range'));
  ODRIVE.WA.validate2(propertyType, propertyValue);
  return 1;
}
;

-----------------------------------------------------------------------------
--
create procedure ODRIVE.WA.rdf_validate_property2 (
  in type varchar,
  in schemaURI varchar,
  in property varchar,
  in propertyValue varchar)
{
  if (type <> 'RDF')
    return 1;

  return ODRIVE.WA.rdf_validate_property (schemaURI, property, propertyValue);
}
;

-----------------------------------------------------------------------------
--
create procedure ODRIVE.WA.dav_rdf_notDeprecated(
  in schemaURI varchar) returns integer
{
  if (cast((select RS_DEPRECATED from WS.WS.SYS_RDF_SCHEMAS where RS_URI = schemaURI) as integer) = 0)
    return 1;
  return 0;
}
;

-----------------------------------------------------------------------------
--
create procedure ODRIVE.WA.dav_mime_notDeprecated(
  in mimeID varchar,
  in schemaURI varchar) returns integer
{
  if (cast((select MR_DEPRECATED from WS.WS.SYS_MIME_RDFS where MR_MIME_IDENT = mimeID and MR_RDF_URI = schemaURI) as integer) = 0)
    return 1;
  return 0;
}
;

-----------------------------------------------------------------------------
--
create procedure ODRIVE.WA.dav_rdf_has_metadata (
  in path varchar) returns any
{
  if ((select count(*) from WS.WS.SYS_MIME_RDFS where MR_MIME_IDENT = ODRIVE.WA.DAV_PROP_GET(path, ':getcontenttype') and MR_DEPRECATED = 0))
    return 1;
  return 0;
}
;

-----------------------------------------------------------------------------
--
create procedure ODRIVE.WA.dav_rdf_get_metadata (
  in path varchar) returns any
{
  declare metadata any;

  if (ODRIVE.WA.dav_rdf_has_metadata (path))
  {
  metadata := ODRIVE.WA.DAV_RDF_PROP_GET(path, 'http://local.virt/DAV-RDF');
  if (not ODRIVE.WA.DAV_ERROR(metadata))
    return xml_tree_doc(xslt('http://local.virt/davxml2n3xml', metadata));
  }
  return null;
}
;

-----------------------------------------------------------------------------
--
create procedure ODRIVE.WA.dav_rdf_set_metadata (
  in path varchar,
  inout metadata varchar) returns any
{
  if (not isnull(metadata))
    return ODRIVE.WA.DAV_RDF_PROP_SET(path, 'http://local.virt/DAV-RDF', xslt('http://local.virt/davxml2rdfxml', metadata));
  return 0;
}
;

-----------------------------------------------------------------------------
--
create procedure ODRIVE.WA.dav_rdf_schema_rs(
  in mimeType varchar,
  in schemaN3 varchar) returns any
{
  declare N, L, pos integer;
  declare c0 varchar;
  declare N3, P any;

  result_names(c0);
  --declare exit handler for SQLSTATE '*' {return;};

  for (select MR_RDF_URI from WS.WS.SYS_MIME_RDFS where MR_MIME_IDENT = mimeType) do
    result (MR_RDF_URI);
  if (not isentity(schemaN3))
    schemaN3 := xml_tree_doc(schemaN3);
  mimeType := ODRIVE.WA.rdf_get_property (schemaN3, 'http://local.virt/this', 'http://www.openlinksw.com/virtdav#dynRdfExtractor', '');
  if (mimeType <> '')
  {
    for (select MR_RDF_URI from WS.WS.SYS_MIME_RDFS where MR_MIME_IDENT = mimeType) do
      result (MR_RDF_URI);
  } else {
    N3 := xpath_eval('/N3', schemaN3, 0);
    N := length (N3);
    for (N := 0; N < length (N3); N := N + 1)
    {
      P := xpath_eval ('@N3P', N3[N]);
      if (not isnull(P))
      {
        pos := strchr(P, '#');
        if (not isnull(pos))
          P := subseq (P, 0, pos+1);
        for (select RS_URI from WS.WS.SYS_RDF_SCHEMAS where RS_URI = P) do
          result (RS_URI);
      }
    }
  }
  return;
}
;

-----------------------------------------------------------------------------
--
create procedure ODRIVE.WA.dav_rdf_schema_properties_rs(
  in schemaN3 varchar) returns any
{
  declare c0, c1, c2, c3, c4 varchar;

  result_names(c0, c1, c2, c3, c4);

  declare exit handler for SQLSTATE '*' {return;};

  if (not isentity(schemaN3))
    schemaN3 := xml_tree_doc(schemaN3);
  foreach (varchar property in ODRIVE.WA.rdf_n3_list_properties (schemaN3, NULL)) do
  {
    result(property,
           ODRIVE.WA.rdf_get_property(schemaN3, property, 'label'),
           ODRIVE.WA.rdf_get_property(schemaN3, property, 'range'),
           ODRIVE.WA.rdf_get_property(schemaN3, property, 'defaultValue'),
           ODRIVE.WA.rdf_get_object_property(schemaN3, property, 'displayOrder', 'displayOrder', '99'),
           ODRIVE.WA.rdf_get_object_property(schemaN3, property, 'displayMode-BrowseExpert', 'access', 'read/write')
          );
        }
  return;
}
;

-----------------------------------------------------------------------------
--
create procedure ODRIVE.WA.dav_rdf_schema_properties_short(
  in schemaURI varchar) returns any
{
  declare exit handler for SQLSTATE '*' {return vector();};

  return (select deserialize (blob_to_string(RS_PROP_CATNAMES)) from WS.WS.SYS_RDF_SCHEMAS where RS_URI = schemaURI);
}
;

-----------------------------------------------------------------------------
--
create procedure ODRIVE.WA.dav_rdf_schema_properties_short_rs(
  in schemaURI varchar) returns any
{
  declare N integer;
  declare c0, c1 varchar;
  declare properties any;

  result_names(c0, c1);

  properties := ODRIVE.WA.dav_rdf_schema_properties_short(schemaURI);
  for(N := 0; N < length(properties); N := N + 6)
    result(properties[N], properties[N+1]);
  return;
}
;

------------------------------------------------------------------------------
--
create procedure ODRIVE.WA.dav_rdf_schema_property(
  in schemaURI varchar,
  in property varchar) returns any
{
  declare schemaN3 any;

  schemaN3 := DB.DBA.DAV_GET_RDF_SCHEMA_N3(schemaURI);
  return ODRIVE.WA.rdf_get_property(schemaN3, property, 'label');
}
;

-----------------------------------------------------------------------------
--
create procedure ODRIVE.WA.dav_rdf_get_property (
  inout metadata varchar,
  in property varchar,
  in defaultValue varchar := '')
{
  if (not isentity(metadata))
    metadata := xml_tree_doc(metadata);
  return ODRIVE.WA.rdf_get_property(metadata, property, 'value', defaultValue);
}
;

-----------------------------------------------------------------------------
--
create procedure ODRIVE.WA.dav_rdf_set_property (
  inout metadata varchar,
  in property varchar,
  in value varchar)
{
  declare aN3 any;

  if (isnull(metadata)) {
    metadata := xml_tree_doc(sprintf('<N3 N3S="http://local.virt/this" N3P="%V">%V</N3>', property, value));
    return;
  }
  if (not isentity(metadata))
    metadata := xml_tree_doc(metadata);
  aN3 := xml_tree_doc(sprintf('<N3 N3S="http://local.virt/this" N3P="%V">%V</N3>', property, value));
  metadata := DB.DBA.DAV_RDF_MERGE (metadata, aN3, null, 0);
}
;

