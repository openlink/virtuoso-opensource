--
--  $Id$
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

-----------------------------------------------------------------------------
--
-- Working procedures
--
-----------------------------------------------------------------------------
create procedure ODRIVE.WA.dc_xml ()
{
  return '<?xml version="1.0" encoding="UTF-8"?><dc><base/><criteria/></dc>';
}
;

-----------------------------------------------------------------------------
--
create procedure ODRIVE.WA.dc_xml_doc (
  in search varchar)
{
  declare exit handler for SQLSTATE '*'
{
    return xtree_doc (ODRIVE.WA.dc_xml ());
  };
  return xtree_doc (search);
}
;

-----------------------------------------------------------------------------
--
create procedure ODRIVE.WA.dc_set_base (
  inout search varchar,
  in id varchar,
  in value varchar)
{
  return ODRIVE.WA.dc_set(search, 'base', id, sprintf('<entry ID="%s">%V</entry>', id, cast(coalesce(value, '') as varchar)));
}
;

-----------------------------------------------------------------------------
--
create procedure ODRIVE.WA.dc_set_criteria (
  inout search varchar,
  in id varchar,
  in fField any,
  in fCriteria any,
  in fValue any,
  in fSchema any := null,
  in fProperty any := null)
{
  declare S varchar;

  S := '';
  if (not isnull (fField))
    S := sprintf ('%s field="%V"', S, fField);
  if (not isnull (fSchema))
    S := sprintf ('%s schema="%V"', S, fSchema);
  if (not isnull (fProperty))
    S := sprintf ('%s property="%V"', S, fProperty);
  if (not isnull (fCriteria))
    S := sprintf ('%s criteria="%V"', S, fCriteria);
  return ODRIVE.WA.dc_set (search, 'criteria', id, sprintf('<entry ID="%s" %s>%V</entry>', id, S, coalesce (fValue, '')));
}
;

-----------------------------------------------------------------------------
--
create procedure ODRIVE.WA.dc_set(
  inout search varchar,
  in tag varchar,
  in id varchar,
  in value varchar)
{
  declare aXml, aEntity any;

  aXml := ODRIVE.WA.dc_xml_doc (search);
  aEntity := xpath_eval(sprintf('/dc/%s/entry[@ID = "%s"]', tag, id), aXml);
  if (not isnull(aEntity))
    aXml := XMLUpdate(aXml, sprintf('/dc/%s/entry[@ID = "%s"]', tag, id), null);

  aEntity := xpath_eval(sprintf('/dc/%s', tag), aXml);
  XMLAppendChildren(aEntity, xtree_doc(value));
  search := ODRIVE.WA.dc_restore_ns (ODRIVE.WA.xml2string (aXml));
  return search;
}
;

-----------------------------------------------------------------------------
--
create procedure ODRIVE.WA.dc_cut (
  inout search varchar,
  in tag varchar,
  in id varchar)
{
  declare aXml any;

  aXml := ODRIVE.WA.dc_xml_doc (search);
  if (not isnull(xpath_eval(sprintf('/dc/%s/entry[@ID = "%s"]', tag, id), aXml)))
    aXml := XMLUpdate(aXml, sprintf('/dc/%s/entry[@ID = "%s"]', tag, id), null);

  search := ODRIVE.WA.xml2string(aXml);
  return search;
}
;

-----------------------------------------------------------------------------
--
create procedure ODRIVE.WA.dc_get(
  inout search varchar,
  in tag varchar,
  in id varchar,
  in defaultValue any := '')
{
  declare aXml any;
  declare value any;

  aXml := ODRIVE.WA.dc_xml_doc (search);
  value := cast(xpath_eval(sprintf('/dc/%s/entry[@ID = "%s"]/.', tag, id), aXml) as varchar);
  if (is_empty_or_null(value))
    return defaultValue;

  return value;
}
;

-----------------------------------------------------------------------------
--
create procedure ODRIVE.WA.dc_filter (
  inout search varchar)
{
  declare I, N integer;
  declare aXml, aEntity, aFilter any;

  aFilter := vector();
  aXml := ODRIVE.WA.dc_xml_doc (search);
  I := xpath_eval('count(/dc/criteria/entry)', aXml);
  for (N := 1; N <= I; N := N + 1)
{
    aEntity := xpath_eval('/dc/criteria/entry', aXml, N);
    ODRIVE.WA.dc_subfilter(aFilter, aEntity);
  }
  return aFilter;
}
;

-----------------------------------------------------------------------------
--
create procedure ODRIVE.WA.dc_subfilter (
  inout filter any,
  inout criteria any)
{
  declare V, fField, fSchema, fProperty, fCriteria, fValue, fValueType any;

  fField := cast (xpath_eval ('@field', criteria) as varchar);
  if (is_empty_or_null (fField))
    signal ('TEST', 'Field can not be empry!<>');

  fCriteria := cast (xpath_eval ('@criteria', criteria) as varchar);
  if (is_empty_or_null (fCriteria))
    signal ('TEST', 'Condition can not be empry!<>');

  fValue := cast (xpath_eval ('.', criteria) as varchar);
  if (is_empty_or_null (fCriteria))
    signal ('TEST', 'Value can not be empry!<>');
  fValueType := ODRIVE.WA.dc_valueType (fField);
  fValue := ODRIVE.WA.dc_cast (fValue, fValueType);
  if (is_empty_or_null (fValue))
    signal ('TEST', 'Value type is not appropriate!<>');

  if (fCriteria = 'like')
  {
    fValue := ODRIVE.WA.dc_search_like_fix (fValue);
  }
  else if (fCriteria in ('contains_text', 'may_contain_text'))
  {
    fValue := ODRIVE.WA.dc_search_string (fValue);
  }
  V := vector (fField, fCriteria, fValue);

  fSchema := cast (xpath_eval ('@schema', criteria) as varchar);
  if (not isnull (fSchema))
    V := vector_concat (V, vector ('http://local.virt/DAV-RDF'));

  fProperty := cast (xpath_eval ('@property', criteria) as varchar);
  if (not isnull (fProperty))
    V := vector_concat (V, vector (fProperty));

  filter := vector_concat (filter, vector(V));
}
;

-----------------------------------------------------------------------------
--
create procedure ODRIVE.WA.dc_restore_ns(inout pXml varchar)
{
  pXml := replace (pXml, 'n0:', 'vmd:');
  pXml := replace (pXml, 'xmlns:n0', 'xmlns:vmd');
  return pXml;
};

-----------------------------------------------------------------------------
--
create procedure ODRIVE.WA.dc_cast (
  in fValue any,
  in fValueType varchar := 'varchar')
{
  declare exit handler for SQLSTATE '*' {return null;};

  if (fValueType = 'varchar')
    return cast (fValue as varchar);
  if (fValueType = 'integer')
    return cast (fValue as integer);
  if (fValueType = 'datetime')
    return cast (fValue as datetime);
  return fValue;
}
;

-----------------------------------------------------------------------------
--
create procedure ODRIVE.WA.dc_valueType (
  in fField any)
{
	declare fPredicates, fPredicate any;

	ODRIVE.WA.dc_predicateMetas (fPredicates);
	fPredicate := get_keyword (fField, fPredicates);
	if (isnull (fPredicate))
	  return null;
  return fPredicate[4];
}
;

-----------------------------------------------------------------------------
--
create procedure ODRIVE.WA.dc_search_like_fix (
  in value varchar)
{
  if (is_empty_or_null (value))
  {
    value := '%';
  } else {
    if (isnull (strstr (value, '%')))
      value := value || '%';
  }
  return replace (value, '%%', '%');
}
;

-----------------------------------------------------------------------------
--
create procedure ODRIVE.WA.dc_search_string (
  in exp varchar)
{
  declare n int;
  declare tmp, w varchar;
  declare words any;

  exp := trim (exp, ' ');
  if (strchr (exp, ' ') is null)
    return concat ('"', trim (exp, '"'), '"');

  words := vector ();
  tmp := exp;
  w := regexp_match ('["][^"]+["]|[''][^'']+['']|[^"'' ]+', tmp, 1);
  while (w is not null)
  {
    w := trim (w, '"'' ');
    words := vector_concat (words, vector (w));
    w := regexp_match ('["][^"]+["]|[''][^'']+['']|[^"'' ]+', tmp, 1);
  }
  exp := '';
  for (n := 0; n < length(words); n := n + 1)
  {
    w := words[n];
    if (upper(w) in ('AND', 'OR'))
    {
      exp := concat (exp, sprintf (' %s ', upper(w)));
    } else {
      if ((n = 0) or (upper(words[n-1]) in ('AND', 'OR'))) {
        exp := concat (exp, sprintf ('"%s"', w));
      } else {
        exp := concat (exp, sprintf (' AND "%s"', w));
      }
    }
  }
  return exp;
}
;

-----------------------------------------------------------------------------
--
create procedure ODRIVE.WA.dc_filter_check (
  inout search varchar,
  inout user_id integer)
{
  declare exit handler for SQLSTATE '*'
  {
    return ODRIVE.WA.test_clear (__SQL_MESSAGE);
  };
  declare aValue, aFilter any;

  aFilter := ODRIVE.WA.dc_filter (search);
  DB.DBA.DAV_FC_PRINT_WHERE (aFilter, user_id);

  return null;
}
;

-----------------------------------------------------------------------------
--
create procedure ODRIVE.WA.dc_predicateMetas (inout pred_metas any)
{
  pred_metas := vector (
    'RES_NAME',                 vector (1, 'File Name',                      null,        null,            'varchar',  vector ()),
    'RES_FULL_PATH',            vector (0, 'RES_FULL_PATH',                  null,        null,            'varchar',  vector ()),
    'RES_TYPE',                 vector (1, 'FileType',                       null,        null,            'varchar',  vector ('button', '<img id="-FIELD-_select" border="0" src="image/select.gif" onclick="javascript: windowShow(\'mimes_select.vspx?params=-FIELD-:s1;\')" />')),
    'RES_OWNER_ID',             vector (0, 'RES_OWNER_ID',                   null,        null,            'integer',  vector ()),
    'RES_OWNER_NAME',           vector (1, 'Owner Name',                     null,        null,            'varchar',  vector ('button', '<img id="-FIELD-_select" border="0" src="image/select.gif" onclick="javascript: windowShow(\'users_select.vspx?mode=u&params=-FIELD-:s1;\')" />')),
    'RES_GROUP_ID',             vector (0, 'RES_GROUP_ID',                   null,        null,            'integer',  vector ()),
    'RES_GROUP_NAME',           vector (1, 'Group Name',                     null,        null,            'varchar',  vector ('button', '<img id="-FIELD-_select" border="0" src="image/select.gif" onclick="javascript: windowShow(\'users_select.vspx?mode=g&params=-FIELD-:s1;\')" />')),
    'RES_COL_FULL_PATH',        vector (0, 'RES_COL_FULL_PATH',              null,        null,            'varchar',  vector ()),
    'RES_COL_NAME',             vector (0, 'RES_COL_NAME',                   null,        null,            'varchar',  vector ()),
    'RES_CR_TIME',              vector (1, 'Creation Time',                  null,        null,            'datetime', vector ('size', '10', 'onclick', 'cPopup.select(\$(\'-FIELD-\'), \'-FIELD-_select\', \'yyyy-MM-dd\')', 'button', '<img id="-FIELD-_select" border="0" src="image/pick_calendar.gif" onclick="javascript: cPopup.select(\$(\'-FIELD-\'), \'-FIELD-_select\', \'yyyy-MM-dd\');" />')),
    'RES_MOD_TIME',             vector (1, 'Modification Time',              null,        null,            'datetime', vector ('size', '10', 'onclick', 'cPopup.select(\$(\'-FIELD-\'), \'-FIELD-_select\', \'yyyy-MM-dd\')', 'button', '<img id="-FIELD-_select" border="0" src="image/pick_calendar.gif" onclick="javascript: cPopup.select(\$(\'-FIELD-\'), \'-FIELD-_select\', \'yyyy-MM-dd\');" />')),
    'RES_PERMS',                vector (0, 'RES_PERMS',                      null,        null,            'varchar',  vector ()),
    'RES_CONTENT',              vector (1, 'File Content',                   null,        null,            'text',     vector ()),
    'PROP_NAME',                vector (0, 'PROP_NAME',                      null,        null,            'varchar',  vector ()),
    'RES_TAGS',                 vector (0, 'RES_TAGS',                       null,        null,            'varchar',  vector ()),
    'RES_PUBLIC_TAGS',          vector (1, 'Public Tags (comma separated)',  null,        null,            'text-tag', vector ()),
    'RES_PRIVATE_TAGS',         vector (1, 'Private Tags (comma separated)', null,        null,            'text-tag', vector ()),
    'PROP_VALUE',               vector (1, 'WebDAV Property',                null,        'davProperties', 'varchar',  vector ()),
    'RDF_PROP',                 vector (0, 'RDF_PROP',                       null,        null,            'varchar',  vector ()),
    'RDF_VALUE',                vector (1, 'RDF Property',                   'rdfSchema', 'rdfProperties', 'varchar',  vector ()),
    'RDF_OBJ_VALUE',            vector (0, 'RDF_OBJ_VALUE',                  null,        null,            'XML',      vector ())
  );
}
;

-----------------------------------------------------------------------------
--
create procedure ODRIVE.WA.dc_compareMetas (inout cmp_metas any)
{
  cmp_metas := vector (
    '=',                      vector ('equal to'                 , vector ('integer', 'datetime', 'varchar')),
    '<',                      vector ('less than'                , vector ('integer', 'datetime', 'varchar')),
    '<=',                     vector ('less than or equal to'    , vector ('integer', 'datetime', 'varchar')),
    '>',                      vector ('greater than'             , vector ('integer', 'datetime', 'varchar')),
    '>=',                     vector ('greater than or equal to' , vector ('integer', 'datetime', 'varchar')),
    '<>',                     vector ('not equal to'             , vector ('integer', 'datetime', 'varchar')),
    '!=',                     vector ('!='                       , vector ()),
    'between',                vector ('between'                  , vector ()),
    'in',                     vector ('in'                       , vector ()),
    'member_of',              vector ('member of'                , vector ()),
    'like',                   vector ('like'                     , vector ('varchar')),
    'regexp_match',           vector ('regexp match'             , vector ()),
    'is_substring_of',        vector ('is substring of'          , vector ('varchar')),
    'contains_substring',     vector ('contains substring'       , vector ('varchar')),
    'not_contains_substring', vector ('not contains substring'   , vector ('varchar')),
    'starts_with',            vector ('starts with'              , vector ('varchar')),
    'not_starts_with',        vector ('not starts with'          , vector ('varchar')),
    'ends_with',              vector ('ends with'                , vector ('varchar')),
    'not_ends_with',          vector ('not ends with'            , vector ('varchar')),
    'is_null',                vector ('is null'                  , vector ()),
    'is_not_null',            vector ('is not null'              , vector ()),
    'contains_tags',          vector ('contains tags'            , vector ('text-tag')),
    'may_contain_tags',       vector ('may contain tags'         , vector ('text-tag')),
    'contains_text',          vector ('contains text'            , vector ('text')),
    'may_contain_text',       vector ('may_contain_text'         , vector ()),
    'xcontains',              vector ('xcontains'                , vector ('XML'))
  );
}
;
