--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2006 OpenLink Software
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

-----------------------------------------------------------------------------
--
-- Working procedures
--
-----------------------------------------------------------------------------
create procedure ODRIVE.WA.dav_dc_xml()
{
  return '<?xml version="1.0" encoding="UTF-8"?><dc><base/><advanced/><property/><metadata/></dc>';
}
;

-----------------------------------------------------------------------------
--
create procedure ODRIVE.WA.dav_dc_set_base(
  inout search varchar,
  in id varchar,
  in value varchar)
{
  return ODRIVE.WA.dav_dc_set(search, 'base', id, sprintf('<entry ID="%s">%V</entry>', id, cast(coalesce(value, '') as varchar)));
}
;

-----------------------------------------------------------------------------
--
create procedure ODRIVE.WA.dav_dc_set_advanced(
  inout search varchar,
  in id varchar,
  in value varchar)
{
  return ODRIVE.WA.dav_dc_set(search, 'advanced', id, sprintf('<entry ID="%s">%V</entry>', id, cast(coalesce(value, '') as varchar)));
}
;

-----------------------------------------------------------------------------
--
create procedure ODRIVE.WA.dav_dc_set_property(
  inout search varchar,
  in id varchar,
  in property varchar,
  in condition varchar,
  in value varchar)
{
  return ODRIVE.WA.dav_dc_set(search, 'property', id, sprintf('<entry ID="%s" property="%V" condition="%V">%V</entry>', id, property, condition, cast(coalesce(value, '') as varchar)));
}
;

-----------------------------------------------------------------------------
--
create procedure ODRIVE.WA.dav_dc_set_metadata(
  inout search varchar,
  in id varchar,
  in type varchar,
  in schema_urn varchar,
  in property varchar,
  in condition varchar,
  in value varchar)
{
  return ODRIVE.WA.dav_dc_set(search, 'metadata', id, sprintf('<entry ID="%s" type="%s" schema="%V" property="%V" condition="%V">%V</entry>', id, type, schema_urn, property, condition, cast(coalesce(value, '') as varchar)));
}
;

-----------------------------------------------------------------------------
--
create procedure ODRIVE.WA.dav_dc_set(
  inout search varchar,
  in tag varchar,
  in id varchar,
  in value varchar)
{
  declare
    aXml,
    aEntity any;
  declare
    S varchar;

  {
    declare exit handler for SQLSTATE '*' {
      aXml := xtree_doc(ODRIVE.WA.dav_dc_xml());
      goto _skip;
    };
    aXml := xtree_doc(search);
  }
_skip:
  aEntity := xpath_eval(sprintf('/dc/%s/entry[@ID = "%s"]', tag, id), aXml);
  if (not isnull(aEntity))
    aXml := XMLUpdate(aXml, sprintf('/dc/%s/entry[@ID = "%s"]', tag, id), null);

  aEntity := xpath_eval(sprintf('/dc/%s', tag), aXml);
  XMLAppendChildren(aEntity, xtree_doc(value));
  search := ODRIVE.WA.dav_dc_restore_ns(ODRIVE.WA.xml2string(aXml));
  return search;
}
;

-----------------------------------------------------------------------------
--
create procedure ODRIVE.WA.dav_dc_cut(
  inout search varchar,
  in tag varchar,
  in id varchar)
{
  declare
    aXml,
    aEntity any;

  declare exit handler for SQLSTATE '*' {return search;};

  aXml := xtree_doc(search);
  aEntity := xpath_eval(sprintf('/dc/%s/entry[@ID = "%s"]', tag, id), aXml);
  if (not isnull(aEntity))
    aXml := XMLUpdate(aXml, sprintf('/dc/%s/entry[@ID = "%s"]', tag, id), null);

  search := ODRIVE.WA.xml2string(aXml);
  return search;
}
;

-----------------------------------------------------------------------------
--
create procedure ODRIVE.WA.dav_dc_get(
  inout search varchar,
  in tag varchar,
  in id varchar,
  in defaultValue any := '')
{
  declare
    aXml any;
  declare
    value any;

  declare exit handler for SQLSTATE '*' {return defaultValue;};

  aXml := xtree_doc(search);
  value := cast(xpath_eval(sprintf('/dc/%s/entry[@ID = "%s"]/.', tag, id), aXml) as varchar);
  if (is_empty_or_null(value))
    return defaultValue;

  return value;
}
;

-----------------------------------------------------------------------------
--
create procedure ODRIVE.WA.dav_dc_property_rs(
  inout search varchar)
{
  declare
    I,
    N integer;
  declare
    aXml,
    aEntity any;
  declare
    c0 integer;
  declare
    c1, c2, c3 varchar;

  result_names(c0, c1, c2, c3);

  declare exit handler for SQLSTATE '*' {return;};

  aXml := xtree_doc(search);
  I := xpath_eval('count(/dc/property/entry)', aXml);
  N := 1;
  while (N <= I) {
    aEntity := xpath_eval('/dc/property/entry', aXml, N);
    result(cast(xpath_eval('@ID', aEntity) as integer),
           cast(xpath_eval('@property', aEntity) as varchar),
           cast(xpath_eval('@condition', aEntity) as varchar),
           cast(xpath_eval('.', aEntity) as varchar)
          );
    N := N + 1;
  }
}
;

-----------------------------------------------------------------------------
--
create procedure ODRIVE.WA.dav_dc_metadata_rs(
  inout search varchar)
{
  declare
    I,
    N integer;
  declare
    aXml,
    aEntity,
    aType,
    aSchema,
    aCategory any;
  declare
    c0 integer;
  declare
    c1, c2, c3, c4, c5, c6 varchar;

  result_names(c0, c1, c2, c3, c4, c5, c6);

  declare exit handler for SQLSTATE '*' {return;};

  aXml := xtree_doc(search);
  I := xpath_eval('count(/dc/metadata/entry)', aXml);
  for (N := 1; N <= I; N := N + 1) {
    aEntity := xpath_eval('/dc/metadata/entry', aXml, N);
    aType := cast(xpath_eval('@type', aEntity) as varchar);
    if (isnull(aType))
      aType := 'RDF';
    aSchema := cast(xpath_eval('@schema', aEntity) as varchar);
    aCategory := 'WebDAV Properties';
    if (aType = 'RDF')
      aCategory := (select RS_CATNAME from WS.WS.SYS_RDF_SCHEMAS where RS_URI = aSchema);
    result(cast(xpath_eval('@ID', aEntity) as integer),
           aType,
           aSchema,
           cast(xpath_eval('@property', aEntity) as varchar),
           cast(xpath_eval('@condition', aEntity) as varchar),
           cast(xpath_eval('.', aEntity) as varchar),
           aCategory
          );
  }
}
;

-----------------------------------------------------------------------------
--
create procedure ODRIVE.WA.dav_dc_filter(
  inout search varchar)
{
  declare
    I,
    N integer;
  declare
    aXml,
    aEntity,
    aFilter any;

  aFilter := vector();
  if (isnull(search))
    return aFilter;

  aXml := xtree_doc(search);

  -- base
  --
  ODRIVE.WA.dav_dc_subfilter(aFilter, 'RES_NAME',    'like', ODRIVE.WA.dav_dc_get(search, 'base', 'name'));
  ODRIVE.WA.dav_dc_subfilter(aFilter, 'RES_CONTENT', 'contains_text', ODRIVE.WA.dav_dc_get(search, 'base', 'content'));

  -- advanced
  --
  ODRIVE.WA.dav_dc_subfilter(aFilter, 'RES_TYPE',     'like', ODRIVE.WA.dav_dc_get(search, 'advanced', 'mime'));
  ODRIVE.WA.dav_dc_subfilter(aFilter, 'RES_OWNER_ID', '=', ODRIVE.WA.dav_dc_get(search, 'advanced', 'owner', '-1'), 'integer', '-1');
  ODRIVE.WA.dav_dc_subfilter(aFilter, 'RES_GROUP_ID', '=', ODRIVE.WA.dav_dc_get(search, 'advanced', 'group', '-1'), 'integer', '-1');
  ODRIVE.WA.dav_dc_subfilter(aFilter, 'RES_CR_TIME',  ODRIVE.WA.dav_dc_get(search, 'advanced', 'createDate11'), ODRIVE.WA.dav_dc_get(search, 'advanced', 'createDate12'), 'datetime');
  ODRIVE.WA.dav_dc_subfilter(aFilter, 'RES_CR_TIME',  ODRIVE.WA.dav_dc_get(search, 'advanced', 'createDate21'), ODRIVE.WA.dav_dc_get(search, 'advanced', 'createDate22'), 'datetime');
  ODRIVE.WA.dav_dc_subfilter(aFilter, 'RES_MOD_TIME', ODRIVE.WA.dav_dc_get(search, 'advanced', 'modifyDate11'), ODRIVE.WA.dav_dc_get(search, 'advanced', 'modifyDate12'), 'datetime');
  ODRIVE.WA.dav_dc_subfilter(aFilter, 'RES_MOD_TIME', ODRIVE.WA.dav_dc_get(search, 'advanced', 'modifyDate21'), ODRIVE.WA.dav_dc_get(search, 'advanced', 'modifyDate22'), 'datetime');
  ODRIVE.WA.dav_dc_subfilter(aFilter, 'RES_PUBLIC_TAGS', ODRIVE.WA.dav_dc_get(search, 'advanced', 'publicTags11'), ODRIVE.WA.dav_dc_get(search, 'advanced', 'publicTags12'));
  ODRIVE.WA.dav_dc_subfilter(aFilter, 'RES_PRIVATE_TAGS', ODRIVE.WA.dav_dc_get(search, 'advanced', 'privateTags11'), ODRIVE.WA.dav_dc_get(search, 'advanced', 'privateTags12'));

  -- properties
  --
  I := xpath_eval('count(/dc/property/entry)', aXml);
  N := 1;
  while (N <= I)
  {
    aEntity := xpath_eval('/dc/property/entry', aXml, N);
    ODRIVE.WA.dav_dc_propSubfilter(aFilter, 'PROP_VALUE', cast(xpath_eval('@property', aEntity) as varchar), cast(xpath_eval('@condition', aEntity) as varchar), cast(xpath_eval('.', aEntity) as varchar));
    N := N + 1;
  }

  -- metadata
  --
  I := xpath_eval('count(/dc/metadata/entry)', aXml);
  N := 1;
  while (N <= I)
  {
    aEntity := xpath_eval('/dc/metadata/entry', aXml, N);
    if (cast(xpath_eval('@type', aEntity) as varchar) = 'RDF') {
      ODRIVE.WA.dav_dc_metaSubfilter(aFilter, 'RDF_VALUE', 'http://local.virt/DAV-RDF', cast(xpath_eval('@property', aEntity) as varchar), cast(xpath_eval('@condition', aEntity) as varchar), cast(xpath_eval('.', aEntity) as varchar));
    } else {
      ODRIVE.WA.dav_dc_propSubfilter(aFilter, 'PROP_VALUE', cast(xpath_eval('@property', aEntity) as varchar), cast(xpath_eval('@condition', aEntity) as varchar), cast(xpath_eval('.', aEntity) as varchar));
    }
    N := N + 1;
  }

  return aFilter;
}
;

-----------------------------------------------------------------------------
--
create procedure ODRIVE.WA.dav_dc_subfilter(
  inout filter any,
  in name any,
  in cond any,
  in value any,
  in type varchar := 'varchar',
  in empty_value any := '') returns void
{
  if (is_empty_or_null(cond))
    return;
  value := ODRIVE.WA.dav_dc_cast(value, type);
  if (isnull(value))
    return;
  if ((cond = 'like') and (cast(value as varchar) <> ''))
    value := replace(concat(cast(value as varchar), '%'), '%%', '%');
  if (cast(value as varchar) = cast(empty_value as varchar))
    return;
  filter := vector_concat(filter, vector(vector(name, cond, value)));
}
;

-----------------------------------------------------------------------------
--
create procedure ODRIVE.WA.dav_dc_propSubfilter(
  inout filter any,
  in name any,
  in propName any,
  in cond any,
  in value any,
  in type varchar := 'varchar',
  in empty_value any := '') returns void
{
  if (is_empty_or_null(cond))
    return;
  if (is_empty_or_null(propName))
    return;
  value := ODRIVE.WA.dav_dc_cast(value, type);
  if (isnull(value))
    return;
  if (cast(value as varchar) = cast(empty_value as varchar))
    return;
  filter := vector_concat(filter, vector(vector(name, cond, value, propName)));
}
;

-----------------------------------------------------------------------------
--
create procedure ODRIVE.WA.dav_dc_metaSubfilter(
  inout filter any,
  in name any,
  in schemaName any,
  in propName any,
  in cond any,
  in value any,
  in type varchar := 'varchar',
  in empty_value any := '') returns void
{
  if (is_empty_or_null(cond))
    return;
  if (is_empty_or_null(schemaName))
    return;
  if (is_empty_or_null(propName))
    return;
  value := ODRIVE.WA.dav_dc_cast(value, type);
  if (isnull(value))
    return;
  if (cast(value as varchar) = cast(empty_value as varchar))
    return;
  filter := vector_concat(filter, vector(vector(name, cond, value, schemaName, propName)));
}
;

-----------------------------------------------------------------------------
--
create procedure ODRIVE.WA.dav_dc_cast(
  in value any,
  in type varchar := 'varchar') returns any
{
  declare exit handler for SQLSTATE '*' {return null;};

  if (type = 'varchar')
    return cast(value as varchar);
  if (type = 'integer')
    return cast(value as integer);
  if (type = 'datetime')
    return cast(value as datetime);
}
;

-----------------------------------------------------------------------------
--
create procedure ODRIVE.WA.dav_dc_restore_ns(inout pXml varchar)
{
  pXml := replace(pXml, 'n0:', 'vmd:');
  pXml := replace(pXml, 'xmlns:n0', 'xmlns:vmd');
  return pXml;
};
