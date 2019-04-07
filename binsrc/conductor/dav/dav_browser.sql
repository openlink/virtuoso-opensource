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
-------------------------------------------------------------------------------
--
-- User Functions
--
-------------------------------------------------------------------------------
create procedure WEBDAV.DBA.check_admin (
  in usr any) returns integer
{
  declare grp integer;

  if (isstring(usr))
    usr := (select U_ID from SYS_USERS where U_NAME = usr);

  if ((usr = 0) or (usr = http_dav_uid ()))
    return 1;

  grp := (select U_GROUP from SYS_USERS where U_ID = usr);
  if ((grp = 0) or (grp = http_dav_uid ()) or (grp = http_dav_uid()+1))
    return 1;

  return 0;
}
;

-------------------------------------------------------------------------------
--
-- Show functions
--
-------------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.show_text(
  in S any,
  in S2 any)
{
  if (isstring(S))
    S := trim(S);
  if (is_empty_or_null(S))
    return sprintf('~ no %s ~', S2);
  return S;
}
;

-------------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.show_excerpt(
  in S varchar,
  in words varchar)
{
  return coalesce (search_excerpt (words, cast (S as varchar)), '');
}
;

-------------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.show_column_header (
  in columnLabel varchar,
  in columnName varchar,
  in sortOrder varchar,
  in sortDirection varchar := 'asc',
  in columnProperties varchar := '')
{
  declare class, image, onclick any;

  image := '';
  onclick := sprintf ('onclick="javascript: odsPost(this, [\'sortColumn\', \'%s\']);"', columnName);
  if (sortOrder = columnName)
  {
    if (sortDirection = 'desc')
    {
      image := '&nbsp;<img src="/ods/images/icons/orderdown_16.png" border="0" alt="Down"/>';
    }
    else if (sortDirection = 'asc')
    {
      image := '&nbsp;<img src="/ods/images/icons/orderup_16.png" border="0" alt="Up"/>';
    }
  }
  return sprintf ('<th %s %s>%s%s</th>', columnProperties, onclick, columnLabel, image);
}
;

-------------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.iri_fix (
  in S varchar)
{
  if (is_https_ctx ())
  {
    declare V any;

    V := rfc1808_parse_uri (cast (S as varchar));
    V [0] := 'https';
    V [1] := http_request_header (http_request_header(), 'Host', null, registry_get ('URIQADefaultHost'));
    S := DB.DBA.vspx_uri_compose (V);
  }
  return S;
}
;

-------------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.url_fix (
  in S varchar,
  in sid varchar := null,
  in realm varchar := null)
{
  declare T varchar;

  T := '&';
  if (isnull (strchr (S, '?')))
    T := '?';

  if (not is_empty_or_null (sid))
  {
    S := S || T || 'sid=' || sid;
    T := '&';
  }
  if (not is_empty_or_null (realm))
    if (__proc_exists ('ODS.DBA.url_encode') is not null)
      S := S || T || 'realm=' || ODS.DBA.url_encode (realm);
    else
      S := S || T || 'realm=' || realm;

  return S;
}
;

-------------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.exec (
  in S varchar,
  in P any := null)
{
  declare st, msg, meta, rows any;

  st := '00000';
  exec (S, st, msg, P, 0, meta, rows);
  if ('00000' = st)
    return rows;

  return vector ();
}
;

-----------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.jsonObject ()
{
  return subseq (soap_box_structure ('x', 1), 0, 2);
}
;

-----------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.obj2json (
  in o any,
  in d integer := 10,
  in nsArray any := null,
  in attributePrefix varchar := null)
{
  declare N, M integer;
  declare R, T any;
  declare S, retValue any;

  if (d = 0)
    return '[maximum depth achieved]';

  T := vector ('\b', '\\b', '\t', '\\t', '\n', '\\n', '\f', '\\f', '\r', '\\r', '"', '\\"', '\\', '\\\\');
  retValue := '';
  if (isnull (o))
  {
    retValue := 'null';
  }
  else if (isnumeric (o))
  {
    retValue := cast (o as varchar);
  }
  else if (isstring (o))
  {
    for (N := 0; N < length(o); N := N + 1)
    {
      R := chr (o[N]);
      for (M := 0; M < length(T); M := M + 2)
      {
        if (R = T[M])
          R := T[M+1];
      }
      retValue := retValue || R;
    }
    retValue := '"' || retValue || '"';
  }
  else if (isarray (o) and (length (o) > 1) and ((__tag (o[0]) = 255) or (o[0] is null and (o[1] = '<soap_box_structure>' or o[1] = 'structure'))))
  {
    retValue := '{';
    for (N := 2; N < length (o); N := N + 2)
    {
      S := o[N];
      if (chr (S[0]) = attributePrefix)
        S := subseq (S, length (attributePrefix));
      if (not isnull (nsArray))
      {
        for (M := 0; M < length (nsArray); M := M + 1)
        {
          if (S like nsArray[M]||':%')
            S := subseq (S, length (nsArray[M])+1);
        }
      }
      retValue := retValue || '"' || S || '":' || WEBDAV.DBA.obj2json (o[N+1], d-1, nsArray, attributePrefix);
      if (N <> length(o)-2)
        retValue := retValue || ', ';
    }
    retValue := retValue || '}';
  }
  else if (isarray (o))
  {
    retValue := '[';
    for (N := 0; N < length(o); N := N + 1)
    {
      retValue := retValue || WEBDAV.DBA.obj2json (o[N], d-1, nsArray, attributePrefix);
      if (N <> length(o)-1)
        retValue := retValue || ',\n';
    }
    retValue := retValue || ']';
  }
  return retValue;
}
;

-----------------------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.obj2xml (
  in o any,
  in d integer := 10,
  in tag varchar := null,
  in nsArray any := null,
  in attributePrefix varchar := '')
{
  declare N, M integer;
  declare R, T any;
  declare S, nsValue, retValue any;

  if (d = 0)
    return '[maximum depth achieved]';

  nsValue := '';
  if (not isnull (nsArray))
  {
    for (N := 0; N < length(nsArray); N := N + 2)
      nsValue := sprintf ('%s xmlns%s="%s"', nsValue, case when nsArray[N]='' then '' else ':'||nsArray[N] end, nsArray[N+1]);
  }
  retValue := '';
  if (isnumeric (o))
  {
    retValue := cast (o as varchar);
  }
  else if (isstring (o))
  {
    retValue := sprintf ('%V', o);
  }
  else if (__tag (o) = 211)
  {
    retValue := datestring (o);
  }
  else if (isJsonObject (o))
  {
    for (N := 2; N < length(o); N := N + 2)
    {
      if (not isJsonObject (o[N+1]) and isarray (o[N+1]) and not isstring (o[N+1]))
      {
        retValue := retValue || obj2xml (o[N+1], d-1, o[N], nsArray, attributePrefix);
      } else {
        if (chr (o[N][0]) <> attributePrefix)
        {
          nsArray := null;
          S := '';
          if ((attributePrefix <> '') and isJsonObject (o[N+1]))
          {
            for (M := 2; M < length(o[N+1]); M := M + 2)
            {
              if (chr (o[N+1][M][0]) = attributePrefix)
                S := sprintf ('%s %s="%s"', S, subseq (o[N+1][M], length (attributePrefix)), obj2xml (o[N+1][M+1]));
            }
          }
          retValue := retValue || sprintf ('<%s%s%s>%s</%s>\n', o[N], S, nsValue, obj2xml (o[N+1], d-1, null, nsArray, attributePrefix), o[N]);
        }
      }
    }
  }
  else if (isarray (o))
  {
    for (N := 0; N < length(o); N := N + 1)
    {
      if (isnull (tag))
      {
        retValue := retValue || obj2xml (o[N], d-1, tag, nsArray, attributePrefix);
      } else {
        nsArray := null;
        S := '';
        if (not isnull (attributePrefix) and isJsonObject (o[N]))
        {
          for (M := 2; M < length(o[N]); M := M + 2)
          {
            if (chr (o[N][M][0]) = attributePrefix)
              S := sprintf ('%s %s="%s"', S, subseq (o[N][M], length (attributePrefix)), obj2xml (o[N][M+1]));
          }
        }
        retValue := retValue || sprintf ('<%s%s%s>%s</%s>\n', tag, S, nsValue, obj2xml (o[N], d-1, null, nsArray, attributePrefix), tag);
      }
    }
  }
  return retValue;
}
;


-----------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.json2obj (
  in o any)
{
  return json_parse (o);
}
;

-----------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.dc_xml ()
{
  return '<?xml version="1.0" encoding="UTF-8"?><dc><base/><criteria/></dc>';
}
;

-----------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.dc_xml_doc (
  in search varchar)
{
  declare exit handler for SQLSTATE '*' {goto _error;};

  if (not is_empty_or_null (search))
    return xtree_doc (search);

_error:
  return xtree_doc (WEBDAV.DBA.dc_xml ());
}
;

-----------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.dc_set_base (
  inout search varchar,
  in id varchar,
  in value varchar)
{
  return WEBDAV.DBA.dc_set(search, 'base', id, sprintf('<entry ID="%s">%V</entry>', id, WEBDAV.DBA.utf2wide (cast(coalesce(value, '') as varchar))));
}
;

-----------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.dc_set_criteria (
  inout search varchar,
  in id varchar,
  in fField any,
  in fCriteria any,
  in fValue any,
  in fSchema any := null,
  in fProperty any := null)
{
  declare S varchar;
  declare aXml any;

  if (is_empty_or_null (id))
  {
    aXml := WEBDAV.DBA.dc_xml_doc (search);
    id := cast (xpath_eval ('count (/dc/criteria/entry)', aXml) as varchar);
    if (is_empty_or_null (id))
    {
      id := '0';
    }
  }
  S := '';
  if (not isnull (fField))
    S := sprintf ('%s field="%V"', S, fField);

  if (not isnull (fSchema))
    S := sprintf ('%s schema="%V"', S, fSchema);

  if (not isnull (fProperty))
    S := sprintf ('%s property="%V"', S, fProperty);

  if (not isnull (fCriteria))
    S := sprintf ('%s criteria="%V"', S, fCriteria);

  return WEBDAV.DBA.dc_set (search, 'criteria', id, sprintf('<entry ID="%s" %s>%V</entry>', id, S, coalesce (fValue, '')));
}
;

-----------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.dc_set(
  inout search varchar,
  in tag varchar,
  in id varchar,
  in value varchar)
{
  declare aXml, aEntity any;

  aXml := WEBDAV.DBA.dc_xml_doc (search);
  aEntity := xpath_eval(sprintf('/dc/%s/entry[@ID = "%s"]', tag, id), aXml);
  if (not isnull(aEntity))
    aXml := XMLUpdate(aXml, sprintf('/dc/%s/entry[@ID = "%s"]', tag, id), null);

  aEntity := xpath_eval(sprintf('/dc/%s', tag), aXml);
  XMLAppendChildren (aEntity, xtree_doc(value));
  search := WEBDAV.DBA.dc_restore_ns (WEBDAV.DBA.xml2string (aXml));
  return search;
}
;

-----------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.dc_cut (
  inout search varchar,
  in tag varchar,
  in id varchar)
{
  declare aXml any;

  aXml := WEBDAV.DBA.dc_xml_doc (search);
  if (not isnull(xpath_eval(sprintf('/dc/%s/entry[@ID = "%s"]', tag, id), aXml)))
  {
    aXml := XMLUpdate(aXml, sprintf('/dc/%s/entry[@ID = "%s"]', tag, id), null);
  }
  search := WEBDAV.DBA.xml2string (aXml);
  return search;
}
;

-----------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.dc_get (
  inout search varchar,
  in tag varchar,
  in id varchar,
  in defaultValue any := '')
{
  declare aXml any;
  declare retValue any;

  aXml := WEBDAV.DBA.dc_xml_doc (search);
  retValue := cast(xpath_eval(sprintf('/dc/%s/entry[@ID = "%s"]/.', tag, id), aXml) as varchar);
  if (is_empty_or_null(retValue))
    return defaultValue;

  return retValue;
}
;

-----------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.dc_get_criteria (
  inout search varchar,
  in id varchar,
  in fField any,
  in fCriteria any,
  in getValue varchar := '.',
  in defaultValue any := '')
{
  declare aXml any;
  declare S, retValue any;

  S := '';
  if (not isnull (id))
  {
    S := S || case when S = '' then '' else ' and ' end || sprintf('@ID = "%s"', id);
  }
  if (not isnull (fField))
  {
    S := S || case when S = '' then '' else ' and ' end || sprintf('@field = "%s"', fField);
  }
  if (not isnull (fCriteria))
  {
    S := S || case when S = '' then '' else ' and ' end || sprintf('@criteria = "%s"', fCriteria);
  }
  aXml := WEBDAV.DBA.dc_xml_doc (search);
  retValue := cast (xpath_eval (sprintf('/dc/criteria/entry[%s]/%s', S, getValue), aXml) as varchar);
  if (is_empty_or_null(retValue))
    return defaultValue;

  return retValue;
}
;

-----------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.dc_filter (
  inout search varchar)
{
  declare entries, filter any;

  filter := vector();
  entries := xpath_eval('/dc/criteria/entry', WEBDAV.DBA.dc_xml_doc (search), 0);
  foreach (any entry in entries) do
    WEBDAV.DBA.dc_subfilter(filter, entry);

  return filter;
}
;

-----------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.dc_subfilter (
  inout filter any,
  in criteria any)
{
  declare V, fField, fSchema, fProperty, fCriteria, fValue, fValueType any;

  fField := cast (xpath_eval ('@field', criteria) as varchar);
  if (is_empty_or_null (fField))
    signal ('TEST', 'Field can not be empty!<>');

  fCriteria := cast (xpath_eval ('@criteria', criteria) as varchar);
  if (is_empty_or_null (fCriteria))
  {
    signal ('TEST', 'Condition can not be empty!<>');
  }
  fValue := cast (xpath_eval ('.', criteria) as varchar);
  if (is_empty_or_null (fCriteria))
  {
    signal ('TEST', 'Value can not be empty!<>');
  }
  fValueType := WEBDAV.DBA.dc_valueType (fField);
  fValue := WEBDAV.DBA.dc_cast (fValue, fValueType);
  if (is_empty_or_null (fValue))
    signal ('TEST', 'Value type is not appropriate!<>');

  if (fCriteria = 'like')
  {
    fValue := WEBDAV.DBA.dc_search_like_fix (fValue);
  }
  else if (fCriteria in ('contains_text', 'may_contain_text'))
  {
    fValue := WEBDAV.DBA.dc_search_string (fValue);
  }
  V := vector (fField, fCriteria, fValue);

  fSchema := cast (xpath_eval ('@schema', criteria) as varchar);
  if (not isnull (fSchema))
  {
    V := vector_concat (V, vector ('http://local.virt/DAV-RDF'));
  }

  fProperty := cast (xpath_eval ('@property', criteria) as varchar);
  if (not isnull (fProperty))
  {
    V := vector_concat (V, vector (fProperty));
  }
  filter := vector_concat (filter, vector(V));
}
;

-----------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.dc_restore_ns(inout pXml varchar)
{
  pXml := replace (pXml, 'n0:', 'vmd:');
  pXml := replace (pXml, 'xmlns:n0', 'xmlns:vmd');
  return pXml;
};

-----------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.dc_cast (
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
create procedure WEBDAV.DBA.dc_valueType (
  in fField any)
{
  declare fPredicates, fPredicate any;

  WEBDAV.DBA.dc_predicateMetas (fPredicates);
  fPredicate := get_keyword (fField, fPredicates);
  if (isnull (fPredicate))
  {
    return null;
  }
  return fPredicate[4];
}
;

-----------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.dc_search_like_fix (
  in value varchar)
{
  if (is_empty_or_null (value))
  {
    value := '%';
  }
  else
  {
    value := trim (value);
    if (chr (value[0]) <> '%')
      value := '%' || value;

    if (chr (value[length (value)-1]) <> '%')
      value := value || '%';
  }
  return value;
}
;

-----------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.dc_search_string (
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
    }
    else
    {
      if ((n = 0) or (upper(words[n-1]) in ('AND', 'OR'))) {
        exp := concat (exp, sprintf ('"%s"', w));
      }
      else
      {
        exp := concat (exp, sprintf (' AND "%s"', w));
      }
    }
  }
  return exp;
}
;

-----------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.dc_filter_check (
  inout search varchar,
  inout user_id integer)
{
  declare exit handler for SQLSTATE '*'
  {
    return WEBDAV.DBA.test_clear (__SQL_MESSAGE);
  };
  declare aValue, aFilter any;

  aFilter := WEBDAV.DBA.dc_filter (search);
  DB.DBA.DAV_FC_PRINT_WHERE (aFilter, user_id);

  return null;
}
;

-----------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.dc_predicateMetas (inout pred_metas any)
{
  pred_metas := vector (
    'RES_NAME',                 vector (1, 'File Name',                      null,        null,            'varchar',  vector ()),
    'RES_FULL_PATH',            vector (0, 'RES_FULL_PATH',                  null,        null,            'varchar',  vector ()),
    'RES_TYPE',                 vector (1, 'FileType',                       null,        null,            'varchar',  vector ('button', '<img id="-FIELD-_select" border="0" src="dav/image/select.gif" onclick="javascript: windowShow(\'/ods/mimes_select.vspx?params=-FIELD-:s1;\')" />')),
    'RES_OWNER_ID',             vector (0, 'RES_OWNER_ID',                   null,        null,            'integer',  vector ()),
    'RES_OWNER_NAME',           vector (1, 'Owner Name',                     null,        null,            'varchar',  vector ('button', '<img id="-FIELD-_select" border="0" src="dav/image/select.gif" onclick="javascript: windowShow(\'/ods/users_select.vspx?mode=u&params=-FIELD-:s1;\')" />')),
    'RES_GROUP_ID',             vector (0, 'RES_GROUP_ID',                   null,        null,            'integer',  vector ()),
    'RES_GROUP_NAME',           vector (1, 'Group Name',                     null,        null,            'varchar',  vector ('button', '<img id="-FIELD-_select" border="0" src="dav/image/select.gif" onclick="javascript: windowShow(\'/ods/users_select.vspx?mode=g&params=-FIELD-:s1;\')" />')),
    'RES_COL_FULL_PATH',        vector (0, 'RES_COL_FULL_PATH',              null,        null,            'varchar',  vector ()),
    'RES_COL_NAME',             vector (0, 'RES_COL_NAME',                   null,        null,            'varchar',  vector ()),
    'RES_CR_TIME',              vector (1, 'Creation Time',                  null,        null,            'datetime', vector ('size', '10', 'onclick', 'datePopup(\'-FIELD-\')', 'button', '<img id="-FIELD-_select" border="0" src="dav/image/pick_calendar.gif" onclick="javascript: datePopup(\'-FIELD-\');" />')),
    'RES_MOD_TIME',             vector (1, 'Modification Time',              null,        null,            'datetime', vector ('size', '10', 'onclick', 'datePopup(\'-FIELD-\')', 'button', '<img id="-FIELD-_select" border="0" src="dav/image/pick_calendar.gif" onclick="javascript: datePopup(\'-FIELD-\');" />')),
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
create procedure WEBDAV.DBA.dc_compareMetas (inout cmp_metas any)
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

-------------------------------------------------------------------------------
--
-- Date / Time functions
--
-------------------------------------------------------------------------------
-- returns system time in GMT
--
create procedure WEBDAV.DBA.dt_current_time()
{
  return dateadd ('minute', - timezone (curdatetime_tz ()), curdatetime_tz ());
}
;

-------------------------------------------------------------------------------
--
-- convert from GMT date to user timezone;
--
create procedure WEBDAV.DBA.dt_gmt2user(
  in pDate datetime,
  in pUser varchar := null)
{
  declare tz integer;

  if (isnull (pDate))
    return null;

  if (isnull (pUser))
    pUser := WEBDAV.DBA.account ();

  if (isnull (pUser))
    return pDate;

  tz := cast (coalesce (USER_GET_OPTION(pUser, 'TIMEZONE'), 0) as integer) * 60 - timezone(curdatetime_tz());
  return dateadd('minute', tz, pDate);
};

-------------------------------------------------------------------------------
--
-- convert from the user timezone to GMT date
--
create procedure WEBDAV.DBA.dt_user2gmt(
  in pDate datetime,
  in pUser varchar := null)
{
  declare tz integer;

  if (isnull (pDate))
    return null;

  if (isnull (pUser))
    pUser := WEBDAV.DBA.account ();

  if (isnull (pUser))
    return pDate;

  tz := cast (coalesce (USER_GET_OPTION(pUser, 'TIMEZONE'), 0) as integer) * 60;
  return dateadd('minute', -tz, pDate);
};

-----------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.dt_value(
  in pDate datetime,
  in pUser varchar := null)
{
  if (isnull (pDate))
    return pDate;

  pDate := WEBDAV.DBA.dt_gmt2user(pDate, pUser);
  if (WEBDAV.DBA.dt_format(pDate, 'D.M.Y') = WEBDAV.DBA.dt_format(now(), 'D.M.Y'))
    return concat ('today ', WEBDAV.DBA.dt_format(pDate, 'H:N'));

  return WEBDAV.DBA.dt_format(pDate, 'D.M.Y H:N');
}
;

-------------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.dt_format(
  in pDate datetime,
  in pFormat varchar := 'd.m.Y')
{
  declare N integer;
  declare ch, S varchar;

  declare exit handler for sqlstate '*' {
    return '';
  };

  S := '';
  for (N := 1; N <= length(pFormat); N := N + 1)
  {
    ch := substring(pFormat, N, 1);
    if (ch = 'M')
    {
      S := concat (S, xslt_format_number(month(pDate), '00'));
    }
    else if (ch = 'm')
    {
      S := concat (S, xslt_format_number(month(pDate), '##'));
    }
    else if (ch = 'Y')
    {
      S := concat (S, xslt_format_number(year(pDate), '0000'));
    }
    else if (ch = 'y')
    {
      S := concat (S, substring(xslt_format_number(year(pDate), '0000'),3,2));
    }
    else if (ch = 'd')
    {
      S := concat (S, xslt_format_number(dayofmonth(pDate), '##'));
    }
    else if (ch = 'D')
    {
      S := concat (S, xslt_format_number(dayofmonth(pDate), '00'));
    }
    else if (ch = 'H')
    {
      S := concat (S, xslt_format_number(hour(pDate), '00'));
    }
    else if (ch = 'h')
    {
      S := concat (S, xslt_format_number(hour(pDate), '##'));
    }
    else if (ch = 'N')
    {
      S := concat (S, xslt_format_number(minute(pDate), '00'));
    }
    else if (ch = 'n')
    {
      S := concat (S, xslt_format_number(minute(pDate), '##'));
    }
    else if (ch = 'S')
    {
      S := concat (S, xslt_format_number(second(pDate), '00'));
    }
    else if (ch = 's')
    {
      S := concat (S, xslt_format_number(second(pDate), '##'));
    }
    else
    {
      S := concat (S, ch);
    }
  }
  return S;
}
;

-------------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.dt_deformat(
  in pString varchar,
  in pFormat varchar := 'd.m.Y')
{
  declare y, m, d integer;
  declare N, I integer;
  declare ch varchar;

  N := 1;
  I := 0;
  d := 0;
  m := 0;
  y := 0;
  while (N <= length (pFormat)) {
    ch := upper(chr(pFormat[N]));
    if (ch = 'M')
      m := WEBDAV.DBA.dt_deformat_tmp(pString, I);
    if (ch = 'D')
      d := WEBDAV.DBA.dt_deformat_tmp(pString, I);
    if (ch = 'Y') {
      y := WEBDAV.DBA.dt_deformat_tmp(pString, I);
      if (y < 50)
        y := 2000 + y;
      if (y < 100)
        y := 1900 + y;
    };
    N := N + 1;
  };
  return stringdate(concat (cast (m as varchar), '.', cast (d as varchar), '.', cast (y as varchar)));
}
;

-------------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.dt_deformat_tmp(
  in S varchar,
  inout N integer)
{
  declare V any;

  V := regexp_parse('[0-9]+', S, N);
  if (length (V) > 1)
  {
    N := aref(V,1);
    return atoi(subseq(S, aref(V, 0), aref(V,1)));
  };
  N := N + 1;
  return 0;
}
;

-------------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.dt_reformat(
  in pString varchar,
  in pInFormat varchar := 'd.m.Y',
  in pOutFormat varchar := 'm.d.Y')
{
  return WEBDAV.DBA.dt_format(WEBDAV.DBA.dt_deformat(pString, pInFormat), pOutFormat);
}
;

-----------------------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.dt_rfc1123 (
  in dt datetime)
{
  return soap_print_box (dt, '', 1);
}
;

-----------------------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.dt_iso8601 (
  in dt datetime)
{
  return soap_print_box (dt, '', 0);
}
;

-------------------------------------------------------------------------------
--  Converts XML Entity to String
-------------------------------------------------------------------------------
create procedure WEBDAV.DBA.xml2string (
  in pXmlEntry any)
{
  declare sStream any;

  sStream := string_output();
  http_value(pXmlEntry, null, sStream);
  return string_output_string(sStream);
}
;

-------------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.isVector (
  inout aVector any)
{
  return isvector (aVector);
}
;

-------------------------------------------------------------------------------
--  Returns:
--    N -  if pAny is in pArray
--   -1 -  otherwise
-------------------------------------------------------------------------------
create procedure WEBDAV.DBA.vector_contains (
  inout aVector any,
  in value any)
{
  return case when (isvector (aVector) and position (value, aVector)) then 1 else 0 end;
}
;

-------------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.vector_index (
  inout aVector any,
  in value any,
  in notFound integer := null)
{
  declare retValue integer;

  if (isnull (aVector))
    return notFound;

  retValue := position (value, aVector);
  return case when (retValue > 0) then retValue -1 else notFound end;
}
;

-------------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.vector_unique (
  inout aVector any,
  in minLength integer := 0)
{
  declare aResult any;
  declare N, M integer;

  aResult := vector ();
  for (N := 0; N < length (aVector); N := N + 1)
  {
    if ((minLength = 0) or (length (aVector[N]) >= minLength))
    {
      for (M := 0; M < length (aResult); M := M + 1)
        if (trim(aResult[M]) = trim(aVector[N]))
          goto _next;

      aResult := vector_concat (aResult, vector (trim(aVector[N])));
    }
  _next:;
  }
  return aResult;
}
;

-------------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.vector2str (
  inout aVector any,
  in delimiter varchar := ' ')
{
  declare tmp, aResult any;
  declare N integer;

  aResult := '';
  for (N := 0; N < length (aVector); N := N + 1)
  {
    tmp := trim (aVector[N]);
    if (strchr (tmp, ' ') is not null)
      tmp := concat ('''', tmp, '''');

    aResult := case when (N = 0) then tmp else concat (aResult, delimiter, tmp) end;
  }
  return aResult;
}
;

-------------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.members2rs(
  inout aMembers any)
{
  declare N integer;
  declare c0, c1 varchar;

  result_names(c0, c1);

  if (isnull (aMembers))
    return;

  for (N := 0; N < length (aMembers); N := N + 1)
    result(aMembers[N][0], aMembers[N][1]);
}
;

-------------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.str2vector (
  in S any)
{
  declare aResult any;

  declare w varchar;
  aResult := vector ();
  w := regexp_match ('["][^"]+["]|[''][^'']+['']|[^"'' ]+', S, 1);
  while (w is not null) {
    w := trim (w, '"'' ');
    if (upper(w) not in ('AND', 'NOT', 'NEAR', 'OR') and length (w) > 1 and not vt_is_noise (WEBDAV.DBA.wide2utf (w), 'utf-8', 'x-ViDoc'))
      aResult := vector_concat (aResult, vector (w));
    w := regexp_match ('["][^"]+["]|[''][^'']+['']|[^"'' ]+', S, 1);
  }
  return aResult;
}
;

-------------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.utf2wide (
  in S any)
{
  declare retValue any;

  if (isstring (S))
  {
    retValue := charset_recode (S, 'UTF-8', '_WIDE_');
    if (iswidestring (retValue))
      return retValue;
  }
  return S;
}
;

-------------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.wide2utf (
  in S any)
{
  declare retValue any;

  if (iswidestring (S))
  {
    retValue := charset_recode (S, '_WIDE_', 'UTF-8' );
    if (isstring (retValue))
      return retValue;
  }
  return charset_recode (S, null, 'UTF-8' );
}
;

-------------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.stringCut (
  in S varchar,
  in L integer := 60)
{
  declare tmp any;

  if (not L)
    return S;

  tmp := WEBDAV.DBA.utf2wide (S);
  if (not iswidestring(tmp))
    return S;

  if (length (tmp) > L)
    return WEBDAV.DBA.wide2utf (concat (subseq (tmp, 0, L-3), '...'));

  return WEBDAV.DBA.wide2utf (tmp);
}
;

-------------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.http_escape (
  in S any,
  in mode integer := 0) returns varchar
{
  declare sStream any;
  sStream := string_output();
  http_escape (S, mode, sStream, 0, 0);
  return string_output_string(sStream);
}
;

-------------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.path_escape (
  in path varchar,
  in delimiter varchar := '/')
{
  declare parts any;
  declare retValue varchar;

  if (DB.DBA.is_empty_or_null (path))
    return path;

  retValue := '';
  parts := split_and_decode (path, 0, '\0\0' || delimiter);
  foreach (varchar part in parts) do
  {
    retValue := retValue || case when (part = '') then '/' else sprintf ('%U/', part) end;
  }
  retValue := subseq (retValue, 0, length(retValue)-1);

  return retValue;
}
;

-------------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.path_unescape (
  in path varchar,
  in delimiter varchar := '/')
{
  declare parts any;
  declare retValue varchar;

  if (DB.DBA.is_empty_or_null (path))
    return path;

  retValue := '';
  parts := split_and_decode (path, 0, '\0\0' || delimiter);
  foreach (varchar part in parts) do
  {
    if (part <> '')
    {
      -- un!escape chars which are not allowed
      part := replace (part, '%27', '''');
      part := replace (part, '%3C', '<');
      part := replace (part, '%3E', '>');
      part := replace (part, '%20', ' ');
      retValue := retValue || part;
    }
    retValue := retValue || '/';
  }
  retValue := subseq (retValue, 0, length(retValue)-1);

  return retValue;
}
;

-------------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.set_keyword (
  in    name   varchar,
  inout params any,
  in    value  any)
{
  declare N integer;

  for (N := 0; N < length (params); N := N + 2)
  {
    if (params[N] = name)
    {
      aset(params, N + 1, value);
      goto _end;
    }
  }
  params := vector_concat (params, vector (name, value));

_end:
  return params;
}
;

-------------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.remove_keyword (
  in    name   varchar,
  inout params any)
{
  declare N integer;
  declare V any;

  V := vector ();
  for (N := 0; N < length (params); N := N + 2)
  {
    if (params[N] <> name)
    {
      V := vector_concat (V, vector(params[N], params[N+1]));
    }
  }
  params := V;
  return V;
}
;

-------------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.tag_prepare(
  inout tag varchar)
{
  if (not is_empty_or_null(tag))
  {
    tag := trim(tag);
    tag := replace (tag, '  ', ' ');
  }
  return tag;
}
;

-------------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.tag_delete(
  inout tags varchar,
  inout T any)
{
  declare N integer;
  declare new_tags any;

  new_tags := WEBDAV.DBA.tags2vector (tags);
  tags := '';
  N := 0;
  foreach (any new_tag in new_tags) do
  {
    if (isstring(T) and (new_tag <> T))
      tags := concat (tags, ',', new_tag);

    if (isinteger (T) and (N <> T))
      tags := concat (tags, ',', new_tag);

    N := N + 1;
  }
  return trim(tags, ',');
}
;

---------------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.tags_join(
  inout tags varchar,
  inout tags2 varchar)
{
  declare resultTags any;

  if (is_empty_or_null(tags))
    tags := '';

  if (is_empty_or_null(tags2))
    tags2 := '';

  resultTags := concat (tags, ',', tags2);
  resultTags := WEBDAV.DBA.tags2vector (resultTags);
  resultTags := WEBDAV.DBA.tags2unique(resultTags);
  resultTags := WEBDAV.DBA.vector2tags(resultTags);
  return resultTags;
}
;

---------------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.tags2vector (
  inout tags varchar)
{
  return split_and_decode(trim(tags, ','), 0, '\0\0,');
}
;

-------------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.vector2tags(
  inout aVector any)
{
  declare N integer;
  declare aResult any;

  aResult := '';
  for (N := 0; N < length (aVector); N := N + 1)
    if (N = 0) {
      aResult := trim(aVector[N]);
    } else {
      aResult := concat (aResult, ',', trim(aVector[N]));
    }
  return aResult;
}
;

-------------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.tags2unique(
  inout aVector any)
{
  declare aResult any;
  declare N, M integer;

  aResult := vector ();
  for (N := 0; N < length (aVector); N := N + 1) {
    for (M := 0; M < length (aResult); M := M + 1)
      if (trim(lcase(aResult[M])) = trim(lcase(aVector[N])))
        goto _next;
    aResult := vector_concat (aResult, vector (trim(aVector[N])));
  _next:;
  }
  return aResult;
}
;

-------------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.tagsDictionary2rs(
  inout aDictionary any)
{
  declare N integer;
  declare c0, c2 varchar;
  declare c1 integer;
  declare V any;

  V := dict_to_vector (aDictionary, 1);
  result_names(c0, c1, c2);
  for (N := 1; N < length (V); N := N + 2)
    result(V[N][0], V[N][1], V[N][2]);
}
;

-------------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.hiddens_prepare (
  inout hiddens any)
{
  declare V any;
  declare exit handler for SQLSTATE '*'
  {
    return vector ();
  };

  V := split_and_decode ( hiddens, 0 , '\0\0,');

  return V;
}
;

-------------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.hiddens_check (
  inout hiddens any,
  inout name varchar)
{
  if (length (name) = 0)
    return 0;

  if (length (hiddens) = 0)
    return 0;

  declare N integer;

  for (N := 0; N < length (hiddens); N := N + 1)
  {
    if (strstr (name, trim (hiddens[N])) = 0)
      return 1;
  }
  return 0;
}
;

-------------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.proc (
  in path varchar,
  in dir_mode integer := 0,
  in dir_params any := null,
  in dir_hiddens any := null,
  in dir_account any := null,
  in dir_password any := null) returns any
{
  -- dbg_obj_princ ('WEBDAV.DBA.proc (', path, dir_mode, dir_params, dir_hiddens, dir_account, dir_password, ')');
  declare dirListTmp, detCategory, dateAdded, dirFilter, dirHiddens, dirList any;
  declare dir_account_name, creator_iri, user_name, group_name varchar;
  declare path_parent varchar;
  declare creator_id, user_id, group_id integer;
  declare c2 any;
  declare c0, c1, c3, c4, c5, c6, c7, c8, c9, c10, c11, c12 varchar;
  declare exit handler for SQLSTATE '*'
  {
    -- dbg_obj_print ('', __SQL_STATE, __SQL_MESSAGE);
    result (__SQL_STATE, VALIDATE.DBA.clear (__SQL_MESSAGE), 0, '', '', '', '', '', '', '', '');
    return;
  };

  result_names (c0, c1, c2, c3, c4, c5, c6, c7, c8, c9, c10, c11, c12);
  if (is_empty_or_null (path))
    return;

  dirList := vector ();
  if (dir_mode = 0)
  {
    -- standard list
    path := WEBDAV.DBA.real_path (path);
    dirList := WEBDAV.DBA.DAV_DIR_LIST (path, 0, dir_account, dir_password);
    dirFilter := '%';
  }
  else if (dir_mode = 1)
  {
    -- standard list with filter
    path := WEBDAV.DBA.real_path (path);
    dirList := WEBDAV.DBA.DAV_DIR_LIST (path, 0, dir_account, dir_password);
    dirFilter := WEBDAV.DBA.dc_search_like_fix (dir_params);
  }
  else if (dir_mode = 2)
  {
    -- simple search
    path := WEBDAV.DBA.real_path (path);
    dirFilter := vector (vector ('RES_NAME', 'like', WEBDAV.DBA.dc_search_like_fix (dir_params)));
    dirList := WEBDAV.DBA.DAV_DIR_FILTER(path, 1, dirFilter);
    dirFilter := '%';
  }
  else if (dir_mode = 3)
  {
    -- advanced search
    path := WEBDAV.DBA.real_path (WEBDAV.DBA.dc_get (dir_params, 'base', 'path', '/DAV/'));
    dirFilter := WEBDAV.DBA.dc_filter (dir_params);
    dirList := WEBDAV.DBA.DAV_DIR_FILTER(path, 1, dirFilter);
    dirFilter := '%';
  }
  else if (dir_mode = 4)
  {
    -- directory selection
    path := WEBDAV.DBA.real_path (path);
    dirListTmp := WEBDAV.DBA.DAV_DIR_LIST (path, 0, dir_account, dir_password);
    if (WEBDAV.DBA.DAV_ERROR (dirListTmp))
    {
      dirList := dirListTmp;
    }
    else
    {
      foreach (any item in dirListTmp) do
      {
        if (item[1] = 'C')
          dirList := vector_concat (dirList, vector (item));
      }
    }
    dir_mode := 0;
    dirFilter := '%';
  }
  else if (dir_mode = 10)
  {
    dirFilter := vector ();
    WEBDAV.DBA.dc_subfilter(dirFilter, 'RES_NAME', 'like', dir_params);
    dirList := DB.DBA.DAV_DIR_FILTER (path, 1, dirFilter, dir_account, dir_password);
    dirFilter := '%';
  }
  else if (dir_mode = 11)
  {
    path := WEBDAV.DBA.real_path (WEBDAV.DBA.dc_get (dir_params, 'base', 'path', '/DAV/'));
    dirFilter := WEBDAV.DBA.dc_filter (dir_params);
    dirList := DB.DBA.DAV_DIR_FILTER (path, 1, dirFilter, dir_account, dir_password);
    dirFilter := '%';
  }
  else if (dir_mode = 20)
  {
    path := WEBDAV.DBA.dc_get(dir_params, 'base', 'path', '/DAV/');
    dirFilter := WEBDAV.DBA.dc_filter (dir_params);
    dirList := DB.DBA.DAV_DIR_FILTER (path, 1, dirFilter, dir_account, dir_password);
    dirFilter := '%';
  }

  -- Command error
  if (WEBDAV.DBA.DAV_ERROR (dirList))
  {
    result(cast (dirList as varchar), DB.DBA.DAV_PERROR (dirList), 0, '', '', '', '', '', '', '', '', '', '');
    return;
  }

  dirHiddens := WEBDAV.DBA.hiddens_prepare (dir_hiddens);
  creator_id := -1;
  user_id := -1;
  group_id := -1;
  user_name := '';
  group_name := '';
  if ((dir_mode = 0) or (dir_mode = 1))
  {
     declare item any;

     -- standard list & filter
     dir_account_name := WEBDAV.DBA.account_name (dir_account);
     path_parent := WEBDAV.DBA.path_parent (path, 1);
     item := WEBDAV.DBA.DAV_INIT (path, dir_account_name, dir_password);
     if (not WEBDAV.DBA.DAV_ERROR (item))
     {
       WEBDAV.DBA.proc_work (item, creator_id, creator_iri, user_id, user_name, group_id, group_name, detCategory, dateAdded);
       result ('.', item[1], item[2], left (cast (item[3] as varchar), 19), item[9], user_name, group_name, adm_dav_format_perms(item[5]), item[0], detCategory, left (cast (item[8] as varchar), 19), left (cast (dateAdded as varchar), 19), creator_iri);
     }
     path_parent := WEBDAV.DBA.dav_parentPath (path, dir_account);
     if (not isnull (path_parent))
     {
       item := WEBDAV.DBA.DAV_INIT (path_parent, dir_account_name, dir_password);
       if (not WEBDAV.DBA.DAV_ERROR (item))
       {
         WEBDAV.DBA.proc_work (item, creator_id, creator_iri, user_id, user_name, group_id, group_name, detCategory, dateAdded);
         result ('..', item[1], item[2], left (cast (item[3] as varchar), 19), item[9], user_name, group_name, adm_dav_format_perms(item[5]), item[0], detCategory, left (cast (item[8] as varchar), 19), left (cast (dateAdded as varchar), 19), creator_iri);
       }
    }
  }

  foreach (any item in dirList) do
  {
    if (isarray(item) and not isnull (item[0]))
    {
      if (((item[1] = 'C') or (item[10] like dirFilter)) and (WEBDAV.DBA.hiddens_check (dirHiddens, item[10]) = 0))
      {
        WEBDAV.DBA.proc_work (item, creator_id, creator_iri, user_id, user_name, group_id, group_name, detCategory, dateAdded);
        result (item[either (gte (dir_mode, 2),0,10)], item[1], item[2], left (cast (item[3] as varchar), 19), item[9], user_name, group_name, adm_dav_format_perms(item[5]), item[0], detCategory, left (cast (item[8] as varchar), 19), left (cast (dateAdded as varchar), 19), creator_iri);
      }
    }
  }
}
;

create procedure WEBDAV.DBA.proc_work (
  inout item any,
  inout creator_id integer,
  inout creator_iri varchar,
  inout user_id integer,
  inout user_name varchar,
  inout group_id integer,
  inout group_name varchar,
  inout detCategory varchar,
  inout dateAdded varchar)
{
  declare tmp any;

  tmp := coalesce (item[7], -1);
  if (user_id <> tmp)
  {
    user_id := tmp;
    user_name := WEBDAV.DBA.user_name (user_id, '');
  }
  tmp := coalesce (item[6], -1);
  if (group_id <> tmp)
  {
    group_id := tmp;
    group_name := WEBDAV.DBA.user_name (group_id, '');
  }
  tmp := coalesce (item[either (lte (length (item), 12),7,12)], coalesce (item[7], -1));
  if (creator_id <> tmp)
  {
    creator_id := tmp;
    if (isinteger (creator_id))
    {
      creator_iri := WEBDAV.DBA.user_iri (creator_id);
    }
    else if (isiri_id (creator_id))
    {
      creator_iri := id_to_iri (creator_id);
    }
    else
    {
      creator_iri := WEBDAV.DBA.user_iri (user_id);
    }
  }
  detCategory := WEBDAV.DBA.det_category (item[4], item[0], item[1], item[9]);
  dateAdded := item[either (lte (length (item), 11),8,11)];
}
;

-----------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.effective_permissions (
  inout path varchar,
  in permission varchar := '1__')
{
  -- dbg_obj_princ ('WEBDAV.DBA.effective_permissions (', path, permission, ')');
  declare N integer;
  declare id, what any;
  declare uid, gid any;
  declare auth_name varchar;

  what := WEBDAV.DBA.path_type (path);
  id := DB.DBA.DAV_SEARCH_ID (path, what);
  if (WEBDAV.DBA.DAV_ERROR (id))
    return 0;

  auth_name := coalesce (WEBDAV.DBA.account (), 'nobody');
  uid := (select U_ID from DB.DBA.SYS_USERS where U_NAME = auth_name);
  gid := (select U_GROUP from DB.DBA.SYS_USERS where U_NAME = auth_name);

  -- dba
  if (uid = 0)
    return 1;

  -- dav
  if (uid = 2)
    return 1;

  -- administrators
  if (gid = 3)
    return 1;

  if (isstring(permission))
    permission := vector (permission);

  for (N := 0; N < length (permission); N := N + 1)
  {
    if (not WEBDAV.DBA.DAV_ERROR (DB.DBA.DAV_AUTHENTICATE (id, what, permission[N], auth_name, uid, gid)))
      return 1;
  }
  return 0;
}
;

-----------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.permission (
  in path varchar)
{
  if ('/' = path)
    return '';

  path := WEBDAV.DBA.real_resource (path);
  if (WEBDAV.DBA.effective_permissions(path, '_1_'))
    return 'W';

  if (WEBDAV.DBA.effective_permissions(path, vector ('1__', '__1')))
    return 'R';

  return ('');
}
;

-----------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.read_permission (
  in path varchar)
{
  return WEBDAV.DBA.effective_permissions (path, vector ('1__', '__1'));
}
;

-----------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.write_permission (
  in path varchar)
{
  return WEBDAV.DBA.effective_permissions (path, '_1_');
}
;

-----------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.exec_permission (
  inout path varchar)
{
  return WEBDAV.DBA.effective_permissions (path, '__1');
}
;

-----------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.version_permission (
  inout path varchar)
{
  declare tmp varchar;

  if (is_empty_or_null (WEBDAV.DBA.DAV_PROP_GET (path, 'DAV:checked-in', '')))
     return 1;

  tmp := WEBDAV.DBA.DAV_PROP_GET (path, 'DAV:auto-version', '');
  if (tmp in ('DAV:checkout-checkin', 'DAV:checkout-unlocked-checkin'))
    return 1;

  return 0;
}
;

-----------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.account () returns varchar
{
  declare vspx_user varchar;

  vspx_user := connection_get('owner_user');
  if (isnull (vspx_user))
    vspx_user := connection_get('vspx_user');

  return vspx_user;
}
;

-------------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.account_id (
  in account any)
{
  if (isinteger (account))
    return account;

  return coalesce ((select U_ID from DB.DBA.SYS_USERS where U_NAME = account), -1);
}
;

-------------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.account_name (
  in account any)
{
  if (isstring (account))
    return account;

  return (select U_NAME from DB.DBA.SYS_USERS where U_ID = account);
}
;

-------------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.account_password (
  in account any)
{
  return coalesce ((select pwd_magic_calc(U_NAME, U_PWD, 1) from WS.WS.SYS_DAV_USER where U_ID = WEBDAV.DBA.account_id (account)), '');
}
;

----------------------------------------------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.account_fullName (
  in account any)
{
  return coalesce ((select WEBDAV.DBA.user_showName (U_NAME, U_FULL_NAME) from DB.DBA.SYS_USERS where U_ID = WEBDAV.DBA.account_id (account)), '');
}
;

-------------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.account_mail (
  in account any)
{
  return coalesce ((select U_E_MAIL from DB.DBA.SYS_USERS where U_ID = WEBDAV.DBA.account_id (account)), '');
}
;

-------------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.account_iri (
  in account_id integer)
{
  declare exit handler for sqlstate '*'
  {
    return WEBDAV.DBA.account_name (account_id);
  };
  return WEBDAV.DBA.user_iri (account_id);
}
;

-------------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.account_inverse_iri (
  in account_iri varchar)
{
  declare params any;

  params := sprintf_inverse (account_iri, 'http://%s/dataspace/person/%s#this', 1);
  if (length (params) <> 2)
    return -1;

  return coalesce ((select U_ID from DB.DBA.SYS_USERS where U_NAME = params[1]), -1);
}
;

-------------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.account_sioc_url (
  in domain_id integer,
  in sid varchar := null,
  in realm varchar := null)
{
  declare S varchar;

  S := WEBDAV.DBA.iri_fix (WEBDAV.DBA.account_iri (WEBDAV.DBA.domain_owner_id (domain_id)));
  return WEBDAV.DBA.url_fix (S, sid, realm);
}
;

-------------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.account_basicAuthorization (
  in account any)
{
  return sprintf ('Basic %s', encode_base64 (account || ':' || WEBDAV.DBA.account_password (account)));
}
;

----------------------------------------------
--
create procedure WEBDAV.DBA.user_showName (
  in u_name any,
  in u_full_name any) returns varchar
{
  if (not is_empty_or_null (trim (u_full_name)))
    return trim (u_full_name);

  return u_name;
}
;

-----------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.user_name (
  in user_id integer,
  in unknown varchar := '~unknown~') returns varchar
{
  if (not isnull (user_id))
    return coalesce ((select U_NAME from DB.DBA.SYS_USERS where U_ID = user_id), unknown);

  return '~unknown~';
}
;

-----------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.group_own (
  in group_name any,
  in user_name any := null) returns integer
{
  declare retValue any;

  if (isinteger (group_name))
    group_name := WEBDAV.DBA.account_name (group_name);

  if (is_empty_or_null (group_name))
    return 1;

  if (group_name = 'dav')
    return 1;

  if (group_name = 'dba')
    return 1;

  if (isnull (user_name))
    user_name := WEBDAV.DBA.account ();

  retValue := WEBDAV.DBA.exec ('select 1 from DB.DBA.SYS_USERS u1, DB.DBA.WA_GROUPS g, DB.DBA.SYS_USERS u2 where u1.U_NAME=? and u1.U_ID=g.WAG_GROUP_ID and u1.U_IS_ROLE=1 and g.WAG_USER_ID=u2.U_ID and u2.U_NAME=?', vector (group_name, user_name));

  if (WEBDAV.DBA.isVector (retValue) and (length (retValue) = 1))
    return 1;

  return 0;
}
;

-----------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.user_id (
  in user_name varchar) returns integer
{
  return coalesce ((select U_ID from DB.DBA.SYS_USERS where U_NAME = user_name), -1);
}
;

-----------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.user_iri (
  in user_id integer) returns varchar
{
  return sprintf ('http://%s/dataspace/person/%s#this',  WEBDAV.DBA.host_url (0), WEBDAV.DBA.user_name (user_id, ''));
}
;

-----------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.user_iri2name (
  in user_iri integer) returns varchar
{
  return WEBDAV.DBA.path_name (trim (rfc1808_parse_uri (trim (user_iri))[2], '/'));
}
;

-----------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.user_initialize (
  in user_name varchar) returns varchar
{
  -- dbg_obj_princ ('WEBDAV.DBA.user_initialize ()');
  declare user_home, new_folder varchar;
  declare uid, gid, cid integer;
  declare retCode any;

  cid := DB.DBA.DAV_HOME_DIR_CREATE (user_name);
  if (WEBDAV.DBA.DAV_ERROR (cid))
    signal ('BRF01', sprintf ('Home folder can not be created for user "%s".', user_name));

  WEBDAV.DBA.DAV_OWNER_ID (user_name, null, uid, gid);
  user_home := DB.DBA.DAV_SEARCH_PATH (cid, 'C');
  if (not exists (select 1 from WS.WS.SYS_DAV_COL where COL_PARENT = cid and COL_DET = 'CatFilter'))
  {
    new_folder := concat (user_home, 'Items/');
    cid := DB.DBA.DAV_SEARCH_ID (new_folder, 'C');
    if (WEBDAV.DBA.DAV_ERROR (cid))
      cid := DB.DBA.DAV_MAKE_DIR (new_folder, uid, gid, '110100100R');

    if (WEBDAV.DBA.DAV_ERROR (cid))
      signal ('BRF02', concat ('User''s category folder ''Items'' can not be created. ', WEBDAV.DBA.DAV_PERROR(cid)));

    {
      declare continue handler for sqlstate '*'
      {
        goto _skip;
      };
      WEBDAV.DBA.CatFilter_CONFIGURE (cid, vector ('path', user_home, 'filter', vector(), 'params', ''), WEBDAV.DBA.account_name (http_dav_uid ()), WEBDAV.DBA.account_password (http_dav_uid ()));
    }
  }
_skip:;
  new_folder := concat (user_home, 'Public/');
  cid := DB.DBA.DAV_SEARCH_ID (new_folder, 'C');
  if (WEBDAV.DBA.DAV_ERROR (cid))
    cid := DB.DBA.DAV_MAKE_DIR (new_folder, uid, gid, '110100100R');

  if (WEBDAV.DBA.DAV_ERROR (cid))
    signal ('BRF03', concat ('User''s folder ''Public'' can not be created.', WEBDAV.DBA.DAV_PERROR(cid)));

  -- create "Shared Resources" folder
  WEBDAV.DBA.acl_share_create (uid);
}
;

-------------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.host_protocol ()
{
  return case when is_https_ctx () then 'https://' else 'http://' end;
}
;

-------------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.host_url (
  in addProtocol integer := 1)
{
  declare host varchar;
  declare exit handler for sqlstate '*' { goto _default; };

  if (is_http_ctx ())
  {
    host := http_request_header (http_request_header ( ) , 'Host' , null , sys_connected_server_address ());
    if (isstring (host) and strchr (host , ':') is null)
    {
      declare hp varchar;
      declare hpa any;

      hp := sys_connected_server_address ();
      hpa := split_and_decode ( hp , 0 , '\0\0:');
      if (hpa [1] <> '80')
        host := host || ':' || hpa [1];
    }
    goto _exit;
  }

_default:;
  host := cfg_item_value (virtuoso_ini_path (), 'URIQA', 'DefaultHost');
  if (host is null)
  {
    host := sys_stat ('st_host_name');
    if (server_http_port () <> '80')
      host := host || ':' || server_http_port ();
  }

_exit:;
  if (addProtocol and (host not like WEBDAV.DBA.host_protocol () || '%'))
    host := WEBDAV.DBA.host_protocol () || host;

  return host;
}
;

-------------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.dav_lpath (
  in path varchar) returns varchar
{
  declare pref, ppref, lpath varchar;

  ppref := http_map_get ('mounted');
  if (ppref = '/DAV/VAD/conductor/')
    return path;

  if (path not like ppref || '%')
    return path;

  pref := http_map_get ('domain') || '/';
  lpath := subseq (path, length (ppref));
  lpath := pref || lpath;
  return lpath;
}
;

-------------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.dav_url (
  in path varchar) returns varchar
{
  declare lpath varchar;

  lpath := WEBDAV.DBA.dav_lpath (path);
  return WEBDAV.DBA.host_url () || WEBDAV.DBA.path_escape (lpath);
}
;

-----------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.dav_home (
  in user_name varchar := null) returns varchar
{
  declare cid integer;
  declare user_home varchar;

  if (isnull (user_name))
    user_name := WEBDAV.DBA.account ();

  user_home := '/DAV/home/' || user_name || '/';
  cid := DB.DBA.DAV_SEARCH_ID (user_home, 'C');
  if (not WEBDAV.DBA.DAV_ERROR (cid))
    return user_home;

  cid := DB.DBA.DAV_HOME_DIR_CREATE (user_name);
  if (WEBDAV.DBA.DAV_ERROR (cid))
    return '/DAV/';

  return DB.DBA.DAV_SEARCH_PATH (cid, 'C');
}
;

-----------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.dav_home2 (
  in user_id integer,
  in user_role varchar := 'public')
{
  declare cid integer;
  declare user_name, user_home any;

  user_name := WEBDAV.DBA.account_name (user_id);
  user_home := '/DAV/home/' || user_name || '/';
  cid := DB.DBA.DAV_SEARCH_ID (user_home, 'C');
  if (not WEBDAV.DBA.DAV_ERROR (cid))
    goto _skip;

  cid := DB.DBA.DAV_HOME_DIR_CREATE (user_name);
  if (WEBDAV.DBA.DAV_ERROR (cid))
    return '/DAV/';

  user_home := DB.DBA.DAV_SEARCH_PATH (cid, 'C');

_skip:;
  if (user_role <> 'public')
    return user_home;

  return user_home || 'Public/';
}
;

-----------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.dav_logical_home (
  in account_id integer) returns varchar
{
  declare home any;

  home := WEBDAV.DBA.dav_home2 (account_id);
  if (not isnull (home))
    home := replace (home, '/DAV', '');

  return home;
}
;

-----------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.dav_browsable ()
{
  if (http_map_get ('browseable') = 0)
    return 0;

  if (http_map_get ('mounted') like '/DAV/VAD/%')
    return 0;

  return 1;
}
;

-----------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.dav_parentPath (
  in path varchar,
  in account any)
{
  -- dbg_obj_princ ('WEBDAV.DBA.dav_parentPath (', path, account_id, ')');
  declare ppath, home varchar;

  if (path = '/DAV/')
    return null;

  if (WEBDAV.DBA.dav_browsable ())
  {
    ppath := http_map_get ('mounted');
    if (path not like ppath || '%')
      return null;

    if (length (path) = length (ppath))
      return null;

    return WEBDAV.DBA.path_parent (path, 1);
  }

  if (WEBDAV.DBA.check_admin (account))
    return WEBDAV.DBA.path_parent (path, 1);

  if (account = 'nobody')
    return WEBDAV.DBA.path_parent (path, 1);

  home := WEBDAV.DBA.dav_home2 (account, '');
  if ((path like home || '%') and (length (path) > length (home)))
    return WEBDAV.DBA.path_parent (path, 1);

  return null;
}
;

-----------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.refine_path(
  in path varchar) returns varchar
{
  path := replace (path, '\\', '/');
  path := replace (path, '//', '/');
  return trim (path, '/');
}
;

-----------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.real_path_int (
  in path varchar,
  in showType integer := 0,
  in pathType varchar := 'C') returns varchar
{
  declare N, id integer;
  declare part, clearPath varchar;
  declare parts, clearParts any;

  parts := split_and_decode (trim (path, '/'), 0, '\0\0/');
  clearParts := vector ();
  for (N := 0; N < length (parts); N := N + 1)
  {
    part := trim (parts[N], '"');
    part := parts[N];
    clearParts := vector_concat (clearParts, vector (part));
  }
  clearPath := '/';
  for (N := 0; N < length (clearParts); N := N + 1)
    clearPath := concat (clearPath, clearParts[N], '/');

  if (pathType = 'R')
    clearPath := rtrim (clearPath, '/');

  return clearPath;
}
;

-----------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.real_path (
  in path varchar,
  in showType integer := 1,
  in pathType varchar := 'C')
{
  return WEBDAV.DBA.real_path_int (path, showType, pathType);
}
;

-----------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.path_show (
  in path varchar) returns varchar
{
  return trim (WEBDAV.DBA.real_path_int (path), '/');
}
;

-----------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.real_resource(
  in path varchar) returns varchar
{
  return WEBDAV.DBA.real_path_int (path, 1, either (equ (right (path, 1), '/'), 'C', 'R'));
}
;

-----------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.path_compare (
  in lPath varchar,
  in rPath varchar) returns integer
{
  if (trim (WEBDAV.DBA.real_path_int(lPath), '/') = trim (WEBDAV.DBA.real_path_int(rPath), '/'))
    return 1;

  return 0;
}
;

-------------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.prop_right (
  in property any,
  in user_id any := null)
{
  if (WEBDAV.DBA.check_admin (user_id))
    return 1;

  if (property like 'DAV:%')
    return 0;

  if (property like 'virt:%')
    return 0;

  if (property like 'xml-%')
    return 0;

  if (property like 'xper-%')
    return 0;

  return 1;
}
;

-------------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.prop_params (
  inout params any,
  in user_id any := null)
{
  declare N integer;
  declare c_properties, c_seq, c_property, c_value, c_action any;

  c_properties := vector ();
  for (N := 0; N < length (params); N := N + 2)
  {
    if (params[N] like 'c_fld_1_%')
    {
      c_seq := replace (params[N], 'c_fld_1_', '');
      c_property := trim (params[N+1]);
      if ((c_property <> '') and (not WEBDAV.DBA.prop_right (c_property, user_id)))
      {
        signal ('TEST', 'Property name is empty or prefix is not allowed!');
      }
      c_value := trim (get_keyword ('c_fld_2_' || c_seq, params, ''));
      c_action := get_keyword ('c_fld_3_' || c_seq, params, '');
      c_properties := vector_concat (c_properties, vector (vector (c_property, c_value, c_action)));
    }
  }
  return c_properties;
}
;

-------------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.acl_params (
  inout params any,
  in acl_dav any := null,
  in tbl varchar := 'f',
  in mode varchar := 'full')
{
  declare I, N integer;
  declare acl_value, acl_seq, acl_users, acl_user, acl_inheritance any;

  acl_value := WS.WS.ACL_CREATE();
  if (not isnull (acl_dav))
  {
    acl_dav := WS.WS.ACL_PARSE (acl_dav, '3', 0);
    for (I := 0; I < length (acl_dav); I := I + 1)
    {
      WS.WS.ACL_ADD_ENTRY (acl_value, acl_dav[I][0], acl_dav[I][3], acl_dav[I][1], acl_dav[I][2]);
    }
  }
  for (I := 0; I < length (params); I := I + 2)
  {
    if (params[I] like (tbl || '_fld_1_%'))
    {
      acl_seq := replace (params[I], tbl || '_fld_1_', '');
      acl_users := split_and_decode (trim (params[I+1]), 0, '\0\0,');
      for (N := 0; N < length (acl_users); N := N + 1)
      {
        acl_user := WEBDAV.DBA.account_inverse_iri (trim (acl_users[N]));
        if (acl_user = -1)
          acl_user := WEBDAV.DBA.user_id (trim (acl_users[N]));
        if (acl_user <> -1)
        {
          if (mode = 'full')
          {
            acl_inheritance := atoi (get_keyword (tbl || '_fld_2_' || acl_seq, params));
            if (acl_inheritance <> 3)
            {
              WS.WS.ACL_ADD_ENTRY (acl_value,
                                   acl_user,
                                   bit_shift (atoi (get_keyword (tbl || '_fld_3_' || acl_seq || '_r_grant', params, '0')), 2) +
                                   bit_shift (atoi (get_keyword (tbl || '_fld_3_' || acl_seq || '_w_grant', params, '0')), 1) +
                                   atoi (get_keyword (tbl || '_fld_3_' || acl_seq || '_x_grant', params, '0')),
                                   1,
                                   acl_inheritance);
              WS.WS.ACL_ADD_ENTRY (acl_value,
                                   acl_user,
                                   bit_shift (atoi (get_keyword (tbl || '_fld_4_' || acl_seq || '_r_deny', params, '0')), 2) +
                                   bit_shift (atoi (get_keyword (tbl || '_fld_4_' || acl_seq || '_w_deny', params, '0')), 1) +
                                   atoi (get_keyword (tbl || '_fld_4_' || acl_seq || '_x_deny', params, '0')),
                                   0,
                                   acl_inheritance);
            }
          }
          else
          {
            WS.WS.ACL_ADD_ENTRY (acl_value,
                                 acl_user,
                                 bit_shift (atoi (get_keyword (tbl || '_fld_2_' || acl_seq || '_r_grant', params, '0')), 2) +
                                 bit_shift (atoi (get_keyword (tbl || '_fld_2_' || acl_seq || '_w_grant', params, '0')), 1) +
                                 atoi (get_keyword (tbl || '_fld_2_' || acl_seq || '_x_grant', params, '0')),
                                 1,
                                 0);
            WS.WS.ACL_ADD_ENTRY (acl_value,
                                 acl_user,
                                 bit_shift (atoi (get_keyword (tbl || '_fld_3_' || acl_seq || '_r_deny', params, '0')), 2) +
                                 bit_shift (atoi (get_keyword (tbl || '_fld_3_' || acl_seq || '_w_deny', params, '0')), 1) +
                                 atoi (get_keyword (tbl || '_fld_3_' || acl_seq || '_x_deny', params, '0')),
                                 0,
                                 0);
          }
        }
      }
    }
  }
  return acl_value;
}
;

-------------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.acl_lines (
  in _acl any,
  in _mode varchar := 'view',
  in _tbl varchar := 'f')
{
  declare N integer;
  declare V any;

  V := vector (0, 'This object only', 1, 'This object, subfolders and files', 2, 'Subfolders and files', 3, 'Inherited');
  for (N := 0; N < length (_acl); N := N + 1)
  {
    if (_mode <> 'view' and (_acl[N][1] <> 3))
    {
      http (sprintf ('OAT.MSG.attach(OAT, "PAGE_LOADED", function(){TBL.createRow("%s", null, {fld_1: {mode: 51, value: "%s", formMode: "u", nrows: %d, tdCssText: "white-space: nowrap;", className: "_validate_"}, fld_2: {mode: 42, value: [%d, %d, %d], suffix: "_grant", onclick: function(){TBL.clickCell42(this);}, tdCssText: "width: 1%%; text-align: center;"}, fld_3: {mode: 42, value: [%d, %d, %d], suffix: "_deny", onclick: function(){TBL.clickCell42(this);}, tdCssText: "width: 1%%; text-align: center;"}});});', _tbl, WEBDAV.DBA.account_iri (_acl[N][0]), 10, bit_and (_acl[N][2], 4), bit_and (_acl[N][2], 2), bit_and (_acl[N][2], 1), bit_and (_acl[N][3], 4), bit_and (_acl[N][3], 2), bit_and (_acl[N][3], 1)));
    }
    else
    {
      http (sprintf ('OAT.MSG.attach(OAT, "PAGE_LOADED", function(){TBL.createViewRow("%s", {fld_1: {value: "%s"}, fld_2: {mode: 42, value: [%d, %d, %d], tdCssText: "width: 1%%; text-align: center;"}, fld_3: {mode: 42, value: [%d, %d, %d], tdCssText: "width: 1%%; text-align: center;"}});});', _tbl, WEBDAV.DBA.account_iri (_acl[N][0]), bit_and (_acl[N][2], 4), bit_and (_acl[N][2], 2), bit_and (_acl[N][2], 1), bit_and (_acl[N][3], 4), bit_and (_acl[N][3], 2), bit_and (_acl[N][3], 1)));
    }
  }
}
;

-----------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.acl_vector (
  in acl varbinary)
{
  declare N, I integer;
  declare aAcl, aTmp any;

  aTmp := vector ();
  if (not DB.DBA.is_empty_or_null (acl))
  {
    aAcl := WS.WS.ACL_PARSE (acl, '0123', 0);
    for (N := 0; N < length (aAcl); N := N + 1)
    {
      if (not aAcl[N][1])
      {
        aTmp := vector_concat (aTmp, vector (vector (aAcl[N][0], aAcl[N][2], 0, aAcl[N][3])));
      }
    }
    for (N := 0; N < length (aAcl); N := N + 1)
    {
      if (aAcl[N][1])
      {
        for (I := 0; I < length (aTmp); I := I + 1)
        {
          if ((aAcl[N][0] = aTmp[I][0]) and (aAcl[N][2] = aTmp[I][1]))
          {
            aset(aTmp, I, vector (aTmp[I][0], aTmp[I][1], aAcl[N][3], aTmp[I][3]));
            goto _exit;
          }
        }
      _exit:
        if (I = length (aTmp))
        {
          aTmp := vector_concat (aTmp, vector (vector (aAcl[N][0], aAcl[N][2], aAcl[N][3], 0)));
        }
      }
    }
  }
  return aTmp;
}
;

-----------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.acl_vector_unique (
  in acl any)
{
  declare N integer;
  declare retValue any;

  retValue := vector ();
  for (N := 0; N < length (acl); N := N + 1)
  {
    if (exists (select 1 from DB.DBA.SYS_USERS where U_ID = acl[N][0] and U_IS_ROLE = 1))
    {
      for (select UG_UID from DB.DBA.SYS_USER_GROUP, DB.DBA.SYS_USERS where UG_GID = acl[N][0] and U_ID = UG_UID and U_IS_ROLE = 0 and U_ACCOUNT_DISABLED = 0) do
      {
        if (not WEBDAV.DBA.vector_contains (retValue, UG_UID))
          retValue := vector_concat (retValue, vector (UG_UID));
      }
    }
    else
    {
      if (not WEBDAV.DBA.vector_contains (retValue, acl[N][0]))
        retValue := vector_concat (retValue, vector (acl[N][0]));
    }
  }
  return retValue;
}
;

-------------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.settings (
  in account_id integer)
{
  declare retValue, V any;

  V := vector ();
  if (account_id <> http_nobody_uid ())
  {
    retValue := WEBDAV.DBA.exec ('select USER_SETTINGS from ODRIVE.WA.SETTINGS where USER_ID = ?', vector (account_id));
    if ((length (retValue) = 1) and not isnull (retValue[0][0]))
      V := deserialize (blob_to_string (retValue[0][0]));
  }
  return WEBDAV.DBA.settings_init (V);
}
;

-------------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.settings_save (
  in account_id integer,
  in settings any)
{
  if (account_id = http_nobody_uid ())
    return;

  WEBDAV.DBA.exec ('insert replacing ODRIVE.WA.SETTINGS (USER_ID, USER_SETTINGS) values (?, serialize (?))', vector (account_id, settings));
}
;

-------------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.settings_init (
  inout settings any)
{
  WEBDAV.DBA.set_keyword ('chars', settings, WEBDAV.DBA.settings_chars (settings));
  WEBDAV.DBA.set_keyword ('rows', settings, WEBDAV.DBA.settings_rows (settings));
  WEBDAV.DBA.set_keyword ('tbLabels', settings, WEBDAV.DBA.settings_tbLabels (settings));
  WEBDAV.DBA.set_keyword ('hiddens', settings, WEBDAV.DBA.settings_hiddens (settings));
  WEBDAV.DBA.set_keyword ('fileSize', settings, WEBDAV.DBA.settings_fileSize (settings));
  WEBDAV.DBA.set_keyword ('atomVersion', settings, WEBDAV.DBA.settings_atomVersion (settings));
  WEBDAV.DBA.set_keyword ('column_#1', settings, WEBDAV.DBA.settings_column (settings, 1));
  WEBDAV.DBA.set_keyword ('column_#2', settings, WEBDAV.DBA.settings_column (settings, 2));
  WEBDAV.DBA.set_keyword ('column_#3', settings, WEBDAV.DBA.settings_column (settings, 3));
  WEBDAV.DBA.set_keyword ('column_#4', settings, WEBDAV.DBA.settings_column (settings, 4));
  WEBDAV.DBA.set_keyword ('column_#5', settings, WEBDAV.DBA.settings_column (settings, 5));
  WEBDAV.DBA.set_keyword ('column_#6', settings, WEBDAV.DBA.settings_column (settings, 6));
  WEBDAV.DBA.set_keyword ('column_#7', settings, WEBDAV.DBA.settings_column (settings, 7));
  WEBDAV.DBA.set_keyword ('column_#8', settings, WEBDAV.DBA.settings_column (settings, 8));
  WEBDAV.DBA.set_keyword ('column_#9', settings, WEBDAV.DBA.settings_column (settings, 9));
  WEBDAV.DBA.set_keyword ('column_#10',settings, WEBDAV.DBA.settings_column (settings,10));
  WEBDAV.DBA.set_keyword ('column_#11',settings, WEBDAV.DBA.settings_column (settings,11));
  WEBDAV.DBA.set_keyword ('column_#12',settings, WEBDAV.DBA.settings_column (settings,12));
  WEBDAV.DBA.set_keyword ('orderBy', settings, WEBDAV.DBA.settings_orderBy (settings));
  WEBDAV.DBA.set_keyword ('orderDirection', settings, WEBDAV.DBA.settings_orderDirection (settings));
  WEBDAV.DBA.set_keyword ('mailShare', settings, WEBDAV.DBA.settings_mailShare (settings));
  WEBDAV.DBA.set_keyword ('mailUnshare', settings, WEBDAV.DBA.settings_mailUnshare (settings));

  return settings;
}
;

-------------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.settings_chars (
  inout settings any)
{
  return cast (get_keyword ('chars', settings, '60') as integer);
}
;

-------------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.settings_rows (
  inout settings any)
{
  return cast (get_keyword ('rows', settings, '10') as integer);
}
;

-------------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.settings_tbLabels (
  inout settings any)
{
  return cast (get_keyword ('tbLabels', settings, '1') as integer);
}
;

-------------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.settings_hiddens (
  inout settings any)
{
  return get_keyword ('hiddens', settings, '.,_');
}
;

-------------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.settings_fileSize (
  inout settings any)
{
  return get_keyword ('fileSize', settings, '1');
}
;

-------------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.settings_atomVersion (
  inout settings any)
{
  return get_keyword ('atomVersion', settings, '1.0');
}
;

-------------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.settings_column (
  inout settings any,
  in N integer)
{
  return cast (get_keyword ('column_#' || cast (N as varchar), settings, case when (N = 10) or (N = 11) or (N = 12) then '0' else '1' end) as integer);
}
;

-------------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.settings_orderBy (
  inout settings any)
{
  return get_keyword ('orderBy', settings, 'column_#4');
}
;

-------------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.settings_orderDirection (
  inout settings any)
{
  return get_keyword ('orderDirection', settings, case when (WEBDAV.DBA.settings_orderBy (settings) = 'column_#4') then 'desc' else 'asc' end);
}
;

-------------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.settings_mailShare (
  inout settings any)
{
  return get_keyword ('mailShare', settings, 'Dear %user_name%,\n\nThe resource %resource_uri% has been shared with you by user %owner_uri% .\n\nRegards,\n%owner_name%');
}
;

-------------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.settings_mailUnshare (
  inout settings any)
{
  return get_keyword ('mailUnshare', settings, 'Dear %user_name%,\n\nThe resource %resource_uri% has been unshared by user %owner_uri% .\n\nRegards,\n%owner_name%');
}
;

-------------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.auto_version_full (
  in value varchar)
{
  if (value = 'A')
    return 'DAV:checkout-checkin';

  if (value = 'B')
    return 'DAV:checkout-unlocked-checkin';

  if (value = 'C')
    return 'DAV:checkout';

  if (value = 'D')
    return 'DAV:locked-checkout';

  return '';
}
;

create procedure WEBDAV.DBA.auto_version_short (
  in value varchar)
{
  if (value = 'DAV:checkout-checkin')
    return 'A';

  if (value = 'DAV:checkout-unlocked-checkin')
    return 'B';

  if (value = 'DAV:checkout')
    return 'C';

  if (value = 'DAV:locked-checkout')
    return 'D';

  return '';
}
;

-------------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.det_type (
  in path varchar,
  in what varchar := 'C') returns varchar
{
  declare id any;
  declare detType varchar;

  id := DB.DBA.DAV_SEARCH_ID (path, what);
  if (WEBDAV.DBA.DAV_ERROR (id))
    return '';

  detType := cast (coalesce (DB.DBA.DAV_PROP_GET_INT (id, what, ':virtdet', 0), '') as varchar);
  if (detType = '')
  {
    if (what = 'R')
      path := WEBDAV.DBA.path_parent (path, 1);

    if (WEBDAV.DBA.path_name (path) = 'Attic')
      detType := 'Versioning';

    else if (WEBDAV.DBA.path_name (path) = 'VVC')
      detType := 'Versioning';

    else if (WEBDAV.DBA.DAV_PROP_GET (path, 'virt:rdfSink-rdf', '') <> '')
      detType := 'rdfSink';

    else if (WEBDAV.DBA.DAV_PROP_GET (path, 'virt:Versioning-History', '') <> '')
      detType := 'UnderVersioning';

    else if (WEBDAV.DBA.syncml_detect (path))
      detType := 'SyncML';
  }
  if ((detType = '') and isarray (id))
    detType := cast (id[0] as varchar);

  return detType;
}
;

-------------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.det_type_name (
  in det_type varchar) returns varchar
{
  declare det_names any;

  if (det_type = '')
    return '';

  det_names := vector (
    'Share',      'Shared Items',
    'ResFilter',  'Smart Folder',
    'CatFilter',  'Category Folder',
    'PropFilter', 'Property Filter',
    'HostFs',     'Host FS',
    'rdfSink',    'Linked Data Import',
    'LDP',        'Linked Data Protocol',
    'RDFData',    'RDF Data',
    'DynaRes',    'Dynamic Resources',
    'SyncML',     'SyncML',
    'Versioning', 'Version Control',
    'S3',         'Amazon S3',
    'GDrive',     'Google Drive',
    'Dropbox',    'Dropbox',
    'SkyDrive',   'OneDrive',
    'Box',        'Box Net',
    'WebDAV',     'WebDAV',
    'RACKSPACE',  'Rackspace Cloud',
    'nntp',       'Discussion',
    'CardDAV',    'CardDAV',
    'Blog',       'Blog',
    'Bookmark',   'Bookmark',
    'calendar',   'Calendar',
    'CalDAV',     'CalDAV',
    'News3',      'Feed Subscriptions',
    'oMail',      'WebMail',
    'IMAP',       'IMAP Mail Account',
    'FTP',        'FTP Client');

  return get_keyword_ucase (det_type, det_names, '');
}
;

-------------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.det_class (
  in path varchar,
  in what varchar := null) returns varchar
{
  declare id any;
  declare retValue varchar;

  if (isnull (what))
    what := WEBDAV.DBA.path_type (path);

  id := DB.DBA.DAV_SEARCH_ID (path, what);
  if (not WEBDAV.DBA.DAV_ERROR (id) and isarray (id))
    retValue := cast (id[0] as varchar);

  else if (WEBDAV.DBA.path_name (path) = 'Attic')
    retValue := 'Versioning';

  else
    retValue := '';

  return retValue;
}
;

-------------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.det_ownClass (
  in path varchar,
  in what varchar) returns varchar
{
  declare id any;
  declare retValue varchar;

  id := DB.DBA.DAV_SEARCH_ID (path, what);
  if (WEBDAV.DBA.DAV_ERROR (id))
    retValue := null;

  else if (isarray (id))
    retValue := cast (id[0] as varchar);


  else if (WEBDAV.DBA.path_name (path) = 'Attic')
    retValue := 'Versioning';

  else if (WEBDAV.DBA.path_name (path) = 'VVC')
    retValue := 'Versioning';

  else
    retValue := WEBDAV.DBA.det_subClass (WEBDAV.DBA.path_parent (path, 1), 'C');

  return retValue;
}
;

-------------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.det_subClass (
  in path varchar,
  in what varchar) returns varchar
{
  declare id any;
  declare retValue varchar;

  retValue := '';
  if (what = 'R')
    retValue := WEBDAV.DBA.det_ownClass (path, what);

  else
  {
    id := DB.DBA.DAV_SEARCH_ID (path, what);
    if (WEBDAV.DBA.DAV_ERROR (id))
      retValue := null;

    else if (WEBDAV.DBA.DAV_PROP_GET (path, 'DAV:version-history', '') <> '')
      retValue := 'UnderVersioning';

    else if (WEBDAV.DBA.DAV_PROP_GET (path, 'virt:Versioning-History', '') <> '')
      retValue := 'UnderVersioning';

    else if (WEBDAV.DBA.DAV_PROP_GET (path, 'virt:Versioning-Collection', '') <> '')
      retValue := 'Versioning';

    else if (WEBDAV.DBA.path_name (path) = 'Attic')
      retValue := 'Versioning';

    else if (WEBDAV.DBA.DAV_PROP_GET (path, 'virt:rdfSink-rdf', '') <> '')
      retValue := 'rdfSink';

    else if (WEBDAV.DBA.syncml_detect (path))
      retValue := 'SyncML';

    else
      retValue := cast (coalesce (DB.DBA.DAV_PROP_GET_INT (id, what, ':virtdet', 0), '') as varchar);
  }
  return retValue;
}
;

-------------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.det_category (
  in id any,
  in path varchar,
  in what varchar,
  in type varchar)
{
  declare retValue varchar;
  declare tmp any;

  retValue := null;
  if (isinteger (id) and (what = 'C'))
  {
    retValue := WEBDAV.DBA.det_type_name (WEBDAV.DBA.det_type (path, 'C'));
  }
  else if (what = 'R')
  {
    tmp := DB.DBA.DAV_PROP_GET_INT (id, what, 'redirectref', 0);
    if (not WEBDAV.DBA.DAV_ERROR (tmp) and (tmp not like 'http:/%'))
    {
      retValue := 'Link';
    }
    else if ((type = 'text/plain') and (path like '%.txt'))
    {
      retValue := 'Text Document';
    }
    else if ((type = 'text/plain') and (path like '%.log'))
    {
      retValue := 'Activity Logs';
    }
    else if ((type = 'text/turtle') and (path like '%,acl'))
    {
      retValue := 'Access Control Lists';
    }
    else if ((type = 'text/turtle') and (path like '%,meta'))
    {
      retValue := 'Metadata Files';
    }
    else if (type = 'text/turtle')
    {
      retValue := 'RDF Turtle';
    }
    else
    {
      retValue := (select RS_CATNAME from WS.WS.SYS_RDF_SCHEMAS, WS.WS.SYS_MIME_RDFS where RS_URI = MR_RDF_URI and MR_MIME_IDENT = type);
    }
  }
  if (isnull (retValue))
    retValue := ' ';

  return retValue;

}
;


-------------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.service_name (
  in _service varchar)
{
  return replace (replace (lcase (_service), ' ', ''), 'api', '');
}
;


-------------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.det_api_key (
  in name varchar)
{
  declare retValue any;

  retValue := WEBDAV.DBA.exec ('select a_key from OAUTH..APP_REG where WEBDAV.DBA.service_name (a_name) = WEBDAV.DBA.service_name (?) and a_owner = 0', vector (name));
  if (WEBDAV.DBA.isVector (retValue) and length (retValue))
    return retValue[0][0];

  return null;
}
;

-------------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.DAV_GET_INFO (
  in path varchar,
  in info varchar,
  in auth_name varchar := null,
  in auth_pwd varchar := null)
{
  declare tmp any;

  if (info = 'vc')
  {
    if (WEBDAV.DBA.DAV_GET_VERSION_CONTROL(path, auth_name, auth_pwd))
      return 'ON';
    return 'OFF';
  }
  if (info = 'avcState')
  {
    tmp := WEBDAV.DBA.DAV_GET_AUTOVERSION(path, auth_name, auth_pwd);
    if (tmp <> '')
      return replace (WEBDAV.DBA.auto_version_full(tmp), 'DAV:', '');
    return 'OFF';
  }
  if (info = 'vcState')
  {
    if (not is_empty_or_null(WEBDAV.DBA.DAV_PROP_GET (path, 'DAV:checked-in', '', auth_name, auth_pwd)))
      return 'Check-In';
    if (not is_empty_or_null(WEBDAV.DBA.DAV_PROP_GET (path, 'DAV:checked-out', '', auth_name, auth_pwd)))
      return 'Check-Out';
    return 'Standard';
  }
  if (info = 'lockState')
  {
    if (WEBDAV.DBA.DAV_IS_LOCKED (path))
      return 'ON';
    return 'OFF';
  }
  return '';
}
;

-------------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.DAV_SET_VERSIONING_CONTROL (
  in path varchar,
  in autoVersion varchar,
  in auth_name varchar := null,
  in auth_pwd varchar := null)
{
  declare permissions, uname, gname varchar;
  declare retValue any;

  WEBDAV.DBA.DAV_API_PARAMS (auth_name, auth_pwd);
  if (autoVersion = '')
  {
    update WS.WS.SYS_DAV_COL set COL_AUTO_VERSIONING = null where COL_ID = DAV_SEARCH_ID (path, 'C');
    return 0;
  }

  permissions := DB.DBA.DAV_PROP_GET (path, ':virtpermissions', auth_name, auth_pwd);
  uname := DB.DBA.DAV_PROP_GET (path, ':virtowneruid', auth_name, auth_pwd);
  gname := DB.DBA.DAV_PROP_GET (path, ':virtownergid', auth_name, auth_pwd);
  DB.DBA.DAV_COL_CREATE (concat (path, 'VVC/'), permissions, uname, gname, auth_name, auth_pwd);
  DB.DBA.DAV_COL_CREATE (concat (path, 'Attic/'), permissions, uname, gname, auth_name, auth_pwd);
  DB.DBA.DAV_PROP_SET (concat (path, 'VVC/'), 'virt:Versioning-Attic', concat (path, 'Attic/'), auth_name, auth_pwd);
  retValue := DB.DBA.DAV_SET_VERSIONING_CONTROL (path, concat (path, 'VVC/'), autoVersion, auth_name, auth_pwd);

  return retValue;
}
;

-------------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.DAV_VERSION_CONTROL (
  in path varchar,
  in auth_name varchar := null,
  in auth_pwd varchar := null)
{
  WEBDAV.DBA.DAV_API_PARAMS (auth_name, auth_pwd);
  return DB.DBA.DAV_VERSION_CONTROL (path, auth_name, auth_pwd);
}
;

-------------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.DAV_REMOVE_VERSION_CONTROL (
  in path varchar,
  in auth_name varchar := null,
  in auth_pwd varchar := null)
{
  WEBDAV.DBA.DAV_API_PARAMS (auth_name, auth_pwd);
  return DB.DBA.DAV_REMOVE_VERSION_CONTROL (path, auth_name, auth_pwd);
}
;

-------------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.DAV_CHECKIN (
  in path varchar,
  in auth_name varchar := null,
  in auth_pwd varchar := null)
{
  WEBDAV.DBA.DAV_API_PARAMS (auth_name, auth_pwd);
  return DB.DBA.DAV_CHECKIN (path, auth_name, auth_pwd);
}
;

-------------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.DAV_CHECKOUT (
  in path varchar,
  in auth_name varchar := null,
  in auth_pwd varchar := null)
{
  WEBDAV.DBA.DAV_API_PARAMS (auth_name, auth_pwd);
  return DB.DBA.DAV_CHECKOUT (path, auth_name, auth_pwd);
}
;

-------------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.DAV_UNCHECKOUT (
  in path varchar,
  in auth_name varchar := null,
  in auth_pwd varchar := null)
{
  WEBDAV.DBA.DAV_API_PARAMS (auth_name, auth_pwd);
  return DB.DBA.DAV_UNCHECKOUT (path, auth_name, auth_pwd);
}
;

-------------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.DAV_GET_AUTOVERSION (
  in path varchar,
  in auth_name varchar := null,
  in auth_pwd varchar := null)
{
  --declare exit handler for SQLSTATE '*' {return '';};

  if (WEBDAV.DBA.DAV_ERROR (DB.DBA.DAV_SEARCH_ID (path, 'R')))
  {
    declare id integer;

    id := DAV_SEARCH_ID (path, 'C');
    if (not isinteger (id))
      return '';
    return coalesce ((select COL_AUTO_VERSIONING from WS.WS.SYS_DAV_COL where COL_ID = DAV_SEARCH_ID (path, 'C')), '');
  }
  return WEBDAV.DBA.auto_version_short(WEBDAV.DBA.DAV_PROP_GET (path, 'DAV:auto-version'));
}
;

-------------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.DAV_GET_VERSION_CONTROL (
  in path varchar,
  in auth_name varchar := null,
  in auth_pwd varchar := null)
{
  declare retValue any;

  if (WEBDAV.DBA.DAV_ERROR (DB.DBA.DAV_SEARCH_ID (path, 'R')))
    return 0;
  if (WEBDAV.DBA.DAV_PROP_GET (path, 'DAV:checked-in', '', auth_name, auth_pwd) <> '')
    return 1;
  if (WEBDAV.DBA.DAV_PROP_GET (path, 'DAV:checked-out', '', auth_name, auth_pwd) <> '')
    return 1;
  return 0;
}
;

-------------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.path_parent (
  in path varchar,
  in mode integer := 0) returns varchar
{
  declare pos integer;

  path := trim (path, '/');
  pos := strrchr (path, '/');
  if (isnull (pos))
    return case when mode then '/' else '' end;

  path := left (path, pos);
  return case when mode then '/' || path || '/' else path end;
}
;

-------------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.path_name (
  in path varchar)
{
  declare pos integer;

  path := trim (path, '/');
  pos := strrchr (path, '/');
  if (isnull (pos))
    return path;

  return right (path, length (path)-pos-1);
}
;

-------------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.path_type (
  in path varchar)
{
  return case when (path[length (path)-1] <> ascii('/')) then 'R' else 'C' end;
}
;

-------------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.DAV_GET_VERSION_PATH (
  in path varchar)
{
  declare parent, name varchar;

  name := WEBDAV.DBA.path_name (path);
  parent := WEBDAV.DBA.path_parent (path);

  return concat ('/', parent, '/VVC/', name, '/');
}
;

-------------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.DAV_GET_VERSION_HISTORY_PATH (
  in path varchar)
{
  return WEBDAV.DBA.DAV_GET_VERSION_PATH (path) || 'history.xml';
}
;

-------------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.DAV_GET_VERSION_HISTORY (
  in path varchar)
{
  declare exit handler for SQLSTATE '*' {return null;};

  return WEBDAV.DBA.DAV_RES_CONTENT (WEBDAV.DBA.DAV_GET_VERSION_HISTORY_PATH(path));
}
;

-------------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.DAV_GET_VERSION_COUNT (
  in path varchar)
{
  declare exit handler for SQLSTATE '*' {return 0;};

  return xpath_eval ('count (//version)', xtree_doc (WEBDAV.DBA.DAV_GET_VERSION_HISTORY(path)));
}
;

-------------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.DAV_GET_VERSION_ROOT (
  in path varchar)
{
  declare exit handler for SQLSTATE '*' {return '';};

  declare retValue any;

  retValue := WEBDAV.DBA.DAV_PROP_GET (WEBDAV.DBA.DAV_GET_VERSION_HISTORY_PATH (path), 'DAV:root-version', '');
  if (WEBDAV.DBA.DAV_ERROR (retValue)) {
    retValue := '';
  } else {
    retValue := cast (xpath_eval ('/href', xml_tree_doc(retValue)) as varchar);
  }
  return WEBDAV.DBA.show_text (retValue, 'root');
}
;

-------------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.DAV_GET_VERSION_SET (
  in path varchar,
  in auth_name varchar := null,
  in auth_pwd varchar := null)
{
  declare N integer;
  declare c0 varchar;
  declare c1 integer;
  declare versionSet, hrefs any;

  result_names(c0, c1);

  declare exit handler for SQLSTATE '*' {return;};

  versionSet := WEBDAV.DBA.DAV_PROP_GET (WEBDAV.DBA.DAV_GET_VERSION_HISTORY_PATH (path), 'DAV:version-set', auth_name, auth_pwd);
  if (not WEBDAV.DBA.DAV_ERROR (versionSet))
  {
    hrefs := xpath_eval ('/href', xtree_doc (versionSet), 0);
    for (N := 0; N < length (hrefs); N := N + 1)
      result (cast (hrefs[N] as varchar), either (equ (N+1, length (hrefs)),0,1));
  }
}
;

-------------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.DAV_SET_AUTOVERSION (
  in path varchar,
  in value any)
{
  declare retValue any;

  retValue := 0;
  if (WEBDAV.DBA.DAV_ERROR (DB.DBA.DAV_SEARCH_ID (path, 'R')))
  {
    retValue := WEBDAV.DBA.DAV_SET_VERSIONING_CONTROL (path, value);
  }
  else
  {
    value := WEBDAV.DBA.auto_version_full (value);
    if (value = '')
    {
      retValue := WEBDAV.DBA.DAV_PROP_REMOVE (path, 'DAV:auto-version');
    }
    else
    {
      if (not WEBDAV.DBA.DAV_GET_VERSION_CONTROL (path))
        WEBDAV.DBA.DAV_VERSION_CONTROL (path);

      retValue := WEBDAV.DBA.DAV_PROP_SET (path, 'DAV:auto-version', value);
    }
  }
  return retValue;
}
;

-------------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.DAV_PERROR (
  in x any)
{
  declare S any;

  if (x = -3)
    return 'Destination exists';

  S := DB.DBA.DAV_PERROR(x);
  if (not is_empty_or_null (S))
  {
    S := replace (S, 'collection', 'folder');
    S := replace (S, 'Collection', 'Folder');
    S := replace (S, 'resource', 'file');
    S := replace (S, 'Resource', 'File');
    S := subseq (S, 6);
  }
  return S;
}
;

-------------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.DAV_INIT (
  in path varchar,
  in auth_name varchar := null,
  in auth_pwd varchar := null)
{
  declare resource any;

  resource := WEBDAV.DBA.DAV_DIR_LIST (path, -1, auth_name, auth_pwd);
  if (WEBDAV.DBA.DAV_ERROR (resource))
    return resource;

  if (length (resource) = 0)
    return -1;

  return resource[0];
}
;

-------------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.DAV_INIT_INT (
  in path varchar,
  in auth_name varchar := null,
  in auth_pwd varchar := null)
{
  declare uid, gid integer;
  declare uname, gname varchar;
  declare permissions any;

  WEBDAV.DBA.DAV_API_PARAMS (auth_name, auth_pwd);
  WEBDAV.DBA.DAV_OWNER_ID (auth_name, null, uid, gid);
  WEBDAV.DBA.DAV_API_PARAMS2 (uid, gid, uname, gname);
  uname := coalesce (auth_name, 'nobody');

  permissions := -1;
  path := replace ('/' || path || '/', '//', '/');
  if (path <> WEBDAV.DBA.dav_home (uname))
    permissions := DB.DBA.DAV_PROP_GET (path, ':virtpermissions', auth_name, auth_pwd);

  if (WEBDAV.DBA.DAV_ERROR (permissions))
    permissions := USER_GET_OPTION (uname, 'PERMISSIONS');

  return vector (null, '', 0, null, 0, permissions, gid, uid, null, '', null);
}
;

-------------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.DAV_INIT_RESOURCE (
  in path varchar,
  in auth_name varchar := null,
  in auth_pwd varchar := null)
{
  declare item any;

  item := WEBDAV.DBA.DAV_INIT_INT (path, auth_name, auth_pwd);
  item[1] := 'R';

  return item;
}
;

-------------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.DAV_INIT_COLLECTION (
  in path varchar,
  in auth_name varchar := null,
  in auth_pwd varchar := null)
{
  declare item any;

  item := WEBDAV.DBA.DAV_INIT_INT (path, auth_name, auth_pwd);
  item[1] := 'C';
  item[9] := 'dav/unix-directory';

  return item;
}
;

-------------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.DAV_GET (
  inout resource any,
  in property varchar)
{
  if (isinteger (resource))
    return;

  if (property = 'fullPath')
    return resource[0];

  if (property = 'type')
    return resource[1];

  if (property = 'length')
    return resource[2];

  if (property = 'modificationTime')
    return case when is_empty_or_null (resource[3]) then now () else resource[3] end;

  if (property = 'id')
    return resource[4];

  if (property = 'permissions')
    return resource[5];

  if (property = 'freeText') {
    if (length (resource[5]) < 10)
      return 'T';
    return chr(resource[5][9]);
  }

  if (property = 'metaGrab') {
    if (length (resource[5]) < 11)
      return 'M';
    return chr(resource[5][10]);
  }

  if (property = 'permissionsName')
    return adm_dav_format_perms (resource[5]);

  if (property = 'groupID')
    return resource[6];

  if (property = 'groupName')
    return WEBDAV.DBA.user_name (resource[6]);

  if (property = 'ownerID')
    return resource[7];

  if (property = 'ownerName')
    return WEBDAV.DBA.user_name (resource[7]);

  if (property = 'creationTime')
    return case when is_empty_or_null (resource[8]) then now () else resource[8] end;

  if (property = 'mimeType')
    return coalesce (resource[9], '');

  if (property = 'name')
    return resource[10];

  if (property = 'creator')
  {
    declare tmp any;

    tmp := coalesce (resource[either (lte (length (resource), 12),7,12)], resource[7]);
    if (isinteger (tmp))
      return WEBDAV.DBA.user_iri (tmp);

    if (isiri_id (tmp))
      return id_to_iri (tmp);

    return WEBDAV.DBA.user_iri (resource[6]);
  }

  if (property = 'acl')
  {
    declare path varchar;

    path := resource[0];
    if (isnull (path))
      return WS.WS.ACL_CREATE();

    if (isstring (path) and path like '%,acl')
      path := regexp_replace (path, ',acl\x24', '');

    else if (isstring (path) and path like '%,meta')
      path := regexp_replace (path, ',meta\x24', '');

    return cast (WEBDAV.DBA.DAV_PROP_GET (path, ':virtacl', cast (WS.WS.ACL_CREATE() as varchar)) as varbinary);
  }

  if ((property = 'detType') and (not isnull (resource[0])))
  {
    declare detType any;

    detType := WEBDAV.DBA.DAV_PROP_GET (resource[0], ':virtdet');
    if ((WEBDAV.DBA.DAV_ERROR (detType) or isnull (detType)))
    {
      declare path varchar;

      path := resource[0];
      if (WEBDAV.DBA.DAV_GET (resource, 'type') = 'R')
        path := WEBDAV.DBA.path_parent (path, 1);

      if (WEBDAV.DBA.DAV_PROP_GET (path, 'virt:rdfSink-rdf', '') <> '')
        detType := 'rdfSink';

      else if (WEBDAV.DBA.DAV_PROP_GET (path, 'virt:Versioning-History', '') <> '')
        detType := 'UnderVersioning';

      else if (WEBDAV.DBA.syncml_detect (path))
        detType := 'SyncML';
    }
    if (WEBDAV.DBA.DAV_ERROR (detType) and isarray (resource[4]))
      detType := cast (resource[4][0] as varchar);

    return detType;
  }

  if ((property = 'privatetags') and (not isnull (resource[0])))
    return WEBDAV.DBA.DAV_PROP_GET (resource[0], ':virtprivatetags', '');

  if ((property = 'publictags') and (not isnull (resource[0])))
    return WEBDAV.DBA.DAV_PROP_GET (resource[0], ':virtpublictags', '');

  if (property = 'versionControl')
  {
    if (isnull (resource[0]))
      return null;

    return WEBDAV.DBA.DAV_GET_VERSION_CONTROL (resource[0]);
  }

  if (property = 'autoversion')
  {
    if (isnull (resource[0]))
      return null;

    return WEBDAV.DBA.DAV_GET_AUTOVERSION (resource[0]);
  }

  if (property = 'checked-in')
  {
    if (isnull (resource[0]))
      return null;

    return WEBDAV.DBA.DAV_PROP_GET (resource[0], 'DAV:checked-in', '');
  }

  if (property = 'checked-out')
  {
    if (isnull (resource[0]))
      return null;

    return WEBDAV.DBA.DAV_PROP_GET (resource[0], 'DAV:checked-out', '');
  }

  if (property = 'permissions-inheritance')
  {
    if (isnull (resource[0]) or (resource[1] = 'R') or WEBDAV.DBA.isVector (resource[1]))
      return null;

    if (isinteger (resource[4]))
      return (select COL_INHERIT from WS.WS.SYS_DAV_COL where COL_ID = resource[4]);
  }

  return '';
}
;

-------------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.DAV_ERROR (in code any)
{
  if (isinteger (code) and (code < 0))
    return 1;
  return 0;
}
;

-------------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.DAV_SET (
  in path varchar,
  in property varchar,
  in value any,
  in auth_name varchar := null,
  in auth_pwd varchar := null)
{
  -- dbg_obj_princ ('WEBDAV.DBA.DAV_SET (', path, property, ')');
  declare tmp varchar;
  declare retValue any;

  if (property = 'permissions')
    return WEBDAV.DBA.DAV_PROP_SET (path, ':virtpermissions', value, auth_name, auth_pwd, 0);

  if (property = 'groupID')
    return WEBDAV.DBA.DAV_PROP_SET (path, ':virtownergid', value, auth_name, auth_pwd, 0);

  if (property = 'ownerID')
    return WEBDAV.DBA.DAV_PROP_SET (path, ':virtowneruid', value, auth_name, auth_pwd, 0);

  if (property = 'mimeType')
    return WEBDAV.DBA.DAV_PROP_SET (path, ':getcontenttype', value, auth_name, auth_pwd, 0);

  if (property = 'name')
  {
    tmp := concat (left(path, strrchr(rtrim(path, '/'), '/')), '/', value, either (equ (right (path, 1), '/'), '/', ''));
    retValue := WEBDAV.DBA.DAV_MOVE (path, tmp, 0, auth_name, auth_pwd);
    if (right (path, 1) = '/')
    {
      tmp := concat (left(path, strrchr(rtrim(path, '/'), '/')), '/', value, '_activity.log');
      path:= concat (left (path, length (path)-1), '_activity.log');
      WEBDAV.DBA.DAV_MOVE (path, tmp, 0, auth_name, auth_pwd);
    }

    return retValue;
  }

  if (property = 'detType')
    return DB.DBA.DAV_PROP_SET_INT (path, ':virtdet', value, null, null, 0, 0, 0, http_dav_uid ());

  if (property = 'acl')
    return DB.DBA.DAV_PROP_SET_INT (path, ':virtacl', value, null, null, 0, 0, 0, http_dav_uid ());

  if (property = 'privatetags')
    return WEBDAV.DBA.DAV_PROP_TAGS_SET (path, ':virtprivatetags', value, auth_name, auth_pwd);

  if (property = 'publictags')
    return WEBDAV.DBA.DAV_PROP_TAGS_SET (path, ':virtpublictags', value, auth_name, auth_pwd);

  if (property = 'autoversion')
    return WEBDAV.DBA.DAV_SET_AUTOVERSION (path, value);

  if (property = 'permissions-inheritance')
  {
    tmp := DB.DBA.DAV_SEARCH_ID (path, 'C');
    if (not isarray (tmp))
    {
      set triggers off;
      commit work;
      update WS.WS.SYS_DAV_COL set COL_INHERIT = value where COL_ID = tmp;
      set triggers on;
    }
  }
  return 0;
}
;

-------------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.DAV_SET_RECURSIVE (
  in path varchar,
  in dav_perms any,
  in dav_owner any,
  in dav_group any,
  in auth_name varchar := null,
  in auth_pwd varchar := null)
{
  declare items any;
  declare itemPath varchar;

  items := WEBDAV.DBA.DAV_DIR_LIST (path, 0, auth_name, auth_pwd);
  foreach (any item in items) do
  {
    itemPath := item[0];
    WEBDAV.DBA.DAV_SET (itemPath, 'permissions', dav_perms, auth_name, auth_pwd);
    if (dav_owner <> -1)
      WEBDAV.DBA.DAV_SET (itemPath, 'ownerID', dav_owner, auth_name, auth_pwd);

    if (dav_group <> -1)
      WEBDAV.DBA.DAV_SET (itemPath, 'groupID', dav_group, auth_name, auth_pwd);

    if (item[1] = 'C')
      WEBDAV.DBA.DAV_SET_RECURSIVE (itemPath, dav_perms, dav_owner, dav_group, auth_name, auth_pwd);
  }
}
;

-------------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.DAV_API_PWD (
  in auth_name varchar)
{
  declare auth_pwd varchar;

  auth_pwd := coalesce ((SELECT U_PWD FROM WS.WS.SYS_DAV_USER WHERE U_NAME = auth_name), '');
  if (auth_pwd[0] = 0)
    auth_pwd := pwd_magic_calc(auth_name, auth_pwd, 1);
  return auth_pwd;
}
;

-------------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.DAV_OWNER_ID (
  in uid any,
  in gid any,
  out _uid integer,
  out _gid integer)
{
  if (isstring (uid) and (uid = 'dba'))
    uid := WEBDAV.DBA.account_id (uid);

  DB.DBA.DAV_OWNER_ID (uid, gid, _uid, _gid);
}
;

-------------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.DAV_API_PARAMS (
  out auth_name varchar,
  out auth_pwd varchar)
{
  if (isnull (auth_name))
    auth_name := WEBDAV.DBA.account ();

  if (auth_name = 'dba')
  {
    auth_name := 'dav';
    auth_pwd := null;
  }
  if (isnull (auth_pwd))
  {
    auth_pwd := coalesce ((SELECT U_PWD FROM WS.WS.SYS_DAV_USER WHERE U_NAME = auth_name), '');
    if (auth_pwd[0] = 0)
      auth_pwd := pwd_magic_calc (auth_name, auth_pwd, 1);
  }
  return 1;
}
;

-------------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.DAV_API_PARAMS2 (
  in uid any,
  in gid any,
  out uname varchar,
  out gname varchar)
{
  uname := null;
  if (not isnull (uid))
    uname := (select U_NAME from WS.WS.SYS_DAV_USER where U_ID = uid);

  gname := null;
  if (not isnull (gid))
    gname := (select G_NAME from WS.WS.SYS_DAV_GROUP where G_ID = gid);
}
;

-------------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.DAV_DIR_LIST (
  in path varchar := '/DAV/',
  in recursive integer := 0,
  in auth_name varchar := null,
  in auth_pwd varchar := null)
{
  declare auth_uid integer;

  auth_uid := null;
  WEBDAV.DBA.DAV_API_PARAMS (auth_name, auth_pwd);
  return DB.DBA.DAV_DIR_LIST_INT (path, recursive, '%', auth_name, auth_pwd, auth_uid);
}
;

-------------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.DAV_DIR_FILTER (
  in path varchar := '/DAV/',
  in recursive integer := 0,
  in filter any,
  in auth_name varchar := null,
  in auth_pwd varchar := null)
{
  WEBDAV.DBA.DAV_API_PARAMS (auth_name, auth_pwd);
  return DB.DBA.DAV_DIR_FILTER (path, recursive, filter, auth_name, auth_pwd);
}
;

-------------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.ResFilter_CONFIGURE (
  in id integer,
  in params varchar,
  in auth_name varchar := null,
  in auth_pwd varchar := null)
{
  declare uid integer;

  WEBDAV.DBA.DAV_API_PARAMS (auth_name, auth_pwd);
  uid := WEBDAV.DBA.user_id (auth_name);
  return DB.DBA.ResFilter_CONFIGURE (id, get_keyword ('params', params), get_keyword ('path', params), get_keyword ('filter', params), auth_name, auth_pwd, uid);
}
;

-------------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.CatFilter_CONFIGURE (
  in id integer,
  in params varchar,
  in auth_name varchar := null,
  in auth_pwd varchar := null)
{
  declare uid integer;

  WEBDAV.DBA.DAV_API_PARAMS (auth_name, auth_pwd);
  uid := WEBDAV.DBA.user_id (auth_name);
  return DB.DBA.CatFilter_CONFIGURE (id, get_keyword ('params', params), get_keyword ('path', params), get_keyword ('filter', params), auth_name, auth_pwd, uid);
}
;

-----------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.rdfSink_CONFIGURE (
  in id integer,
  in params any,
  in auth_name varchar := null,
  in auth_pwd varchar := null)
{
  -- RDF Graph & Sponger params
  declare uid, gid integer;
  declare oldGraph, oldPath, oldContentType varchar;
  declare retValue, oldParams any;

  oldParams := DB.DBA.DAV_DET_RDF_PARAMS_GET ('rdfSink', id);
  DB.DBA.DAV_DET_PARAM_SET ('rdfSink', null, id, 'C', 'activity', get_keyword ('activity', params, 'off'), 0);
  retValue := DB.DBA.DAV_DET_RDF_PARAMS_SET ('rdfSink', id, params, vector ('sponger', 'cartridges', 'metaCartridges', 'base', 'graph', 'contentType', 'graphSecurity', 'graphSecurityACL', 'graphSecurityACI'));
  oldGraph := get_keyword ('graph', oldParams, '');
  if (oldGraph <> '')
  {
    oldContentType := get_keyword ('contentType', oldParams, '');
    if ((oldGraph <> get_keyword ('graph', params)) or (oldContentType <> get_keyword ('contentType', params, '')))
    {
      oldPath := WS.WS.COL_PATH (id) || replace (DB.DBA.DAV_RDF_RES_NAME (oldGraph), ' ', '_');
      if (not isnull (DAV_HIDE_ERROR (DAV_SEARCH_ID (oldPath, 'R'))))
      {
        WEBDAV.DBA.DAV_API_PARAMS (auth_name, auth_pwd);
        WEBDAV.DBA.DAV_DELETE (oldPath, 0, auth_name, auth_pwd);
        if (__proc_exists ('DB.DBA.RDF_SINK_REDIRECT') is not null)
        {
          WEBDAV.DBA.DAV_OWNER_ID (auth_name, null, uid, gid);
          DB.DBA.RDF_SINK_REDIRECT (id, get_keyword ('graph', params), params, uid, gid);
        }
      }
    }
  }

  return retValue;
}
;

-------------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.rdfSink_VERIFY (
  in path integer,
  in params any)
{
  -- dbg_obj_princ ('rdfSink_VERIFY (', path, params, ')');
  declare exit handler for sqlstate '*'
  {
    return __SQL_MESSAGE;
  };

  WEBDAV.DBA.test (get_keyword ('graph', params), vector ('name', 'RDF Graph', 'class', 'varchar', 'minLength', 1, 'maxLength', 255));
  WEBDAV.DBA.test (get_keyword ('base', params),  vector ('name', 'RDF Base URI', 'class', 'varchar', 'minLength', 0, 'maxLength', 255));

  return null;
}
;

-------------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.DAV_COPY (
  in path varchar,
  in destination varchar,
  in overwrite integer := 0,
  in permissions varchar := '110100000R',
  in auth_name varchar := null,
  in auth_pwd varchar := null)
{
  declare uid, gid integer;
  declare uname, gname varchar;

  WEBDAV.DBA.DAV_API_PARAMS (auth_name, auth_pwd);
  uid := (select U_ID from WS.WS.SYS_DAV_USER where U_NAME = auth_name);
  gid := (select U_GROUP from WS.WS.SYS_DAV_USER where U_NAME = auth_name);
  WEBDAV.DBA.DAV_API_PARAMS2 (uid, gid, uname, gname);
  return DB.DBA.DAV_COPY (path, destination, overwrite, permissions, uname, gname, auth_name, auth_pwd);
}
;

-------------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.DAV_MOVE (
  in path varchar,
  in destination varchar,
  in overwrite integer,
  in auth_name varchar := null,
  in auth_pwd varchar := null)
{
  WEBDAV.DBA.DAV_API_PARAMS (auth_name, auth_pwd);
  return DB.DBA.DAV_MOVE (path, destination, overwrite, auth_name, auth_pwd);
}
;

-------------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.DAV_DELETE (
  in path varchar,
  in silent integer := 0,
  in auth_name varchar := null,
  in auth_pwd varchar := null,
  in check_locks integer := 1)
{
  -- dbg_obj_princ ('WEBDAV.DBA.DAV_DELETE (', path, ')');

  WEBDAV.DBA.DAV_API_PARAMS (auth_name, auth_pwd);
  if ((WEBDAV.DBA.path_type (path) = 'C') and (WEBDAV.DBA.det_type (path, 'C') = 'SyncML'))
    WEBDAV.DBA.exec ('delete from DB.DBA.SYNC_COLS_TYPES where CT_COL_ID = ?', vector (DB.DBA.DAV_SEARCH_ID (path, 'C')));

  return DB.DBA.DAV_DELETE_INT (path, silent, auth_name, auth_pwd, check_locks=>check_locks);
}
;

-------------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.DAV_RES_UPLOAD (
  in path varchar,
  inout content any,
  in type varchar := '',
  in permissions varchar := '110100000R',
  in uid any := null,
  in gid any := null,
  in auth_name varchar := null,
  in auth_pwd varchar := null)
{
  WEBDAV.DBA.DAV_API_PARAMS (auth_name, auth_pwd);
  return DB.DBA.DAV_RES_UPLOAD_STRSES (path, content, type, permissions, uid, gid, auth_name, auth_pwd);
}
;

-------------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.DAV_RDF_UPLOAD (
  inout content any,
  in type varchar,
  in graph varchar)
{
  declare retValue integer;
  declare graph2 varchar;

  graph2 := 'http://local.virt/temp';
  retValue := DB.DBA.RDF_SINK_UPLOAD ('/temp', content, type, graph, null, 'on', '', '');
  SPARQL clear graph ?:graph2;

  return retValue;
}
;

-------------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.DAV_RES_CONTENT (
  in path varchar,
  in auth_name varchar := null,
  in auth_pwd varchar := null)
{
  declare content, contentType any;
  declare retValue any;

  WEBDAV.DBA.DAV_API_PARAMS (auth_name, auth_pwd);
  retValue := DB.DBA.DAV_RES_CONTENT (path, content, contentType, auth_name, auth_pwd);
  if (retValue >= 0)
    return content;

  return retValue;
}
;

-------------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.content_excerpt (
  in path varchar,
  in words any)
{
  declare S, W any;

  S := WEBDAV.DBA.DAV_RES_CONTENT (path);
  if (WEBDAV.DBA.DAV_ERROR (S))
    return '';

  FTI_MAKE_SEARCH_STRING_INNER (words, W);
  return WEBDAV.DBA.show_excerpt (S, W);
}
;

-------------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.DAV_COL_CREATE (
  in path varchar,
  in permissions varchar := '110100000R',
  in uid any,
  in gid any,
  in auth_name varchar := null,
  in auth_pwd varchar := null)
{
  declare uname, gname varchar;

  WEBDAV.DBA.DAV_API_PARAMS (auth_name, auth_pwd);
  WEBDAV.DBA.DAV_API_PARAMS2 (uid, gid, uname, gname);
  return DB.DBA.DAV_COL_CREATE (path, permissions, uname, gname, auth_name, auth_pwd);
}
;

-------------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.DAV_PROP_LIST (
  in path varchar,
  in propmask varchar := '%',
  in skips varchar := null,
  in auth_name varchar := null,
  in auth_pwd varchar := null,
  in error integer := 0)
{
  declare props any;
  declare remains any;

  remains := vector ();
  WEBDAV.DBA.DAV_API_PARAMS (auth_name, auth_pwd);
  props := DB.DBA.DAV_PROP_LIST (path, propmask, auth_name, auth_pwd);
  if (WEBDAV.DBA.DAV_ERROR (props))
    return case when error then props else remains end;

  if (isnull (skips))
    return props;

  foreach (any prop in props) do
  {
    foreach (any skip in skips) do
    {
      if (prop[0] like skip)
        goto _skip;
    }
    remains := vector_concat (remains, vector (prop));
  _skip: ;
  }
  return remains;
}
;

-------------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.DAV_PROP_GET (
  in path varchar,
  in propName varchar,
  in propValue varchar := null,
  in auth_name varchar := null,
  in auth_pwd varchar := null)
{
  -- dbg_obj_princ ('WEBDAV.DBA.DAV_PROP_GET (', path, propName, ')');
  declare retValue any;
  declare exit handler for SQLSTATE '*' {return propValue;};

  WEBDAV.DBA.DAV_API_PARAMS (auth_name, auth_pwd);
  retValue := DB.DBA.DAV_PROP_GET (path, propName, auth_name, auth_pwd);
  if (WEBDAV.DBA.DAV_ERROR (retValue) and not isnull (propValue))
    return propValue;

  return retValue;
}
;

-------------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.DAV_PROP_GET_CHAIN (
  in path varchar,
  in propName varchar,
  in propValue varchar := null,
  in auth_name varchar := null,
  in auth_pwd varchar := null)
{
  -- dbg_obj_princ ('WEBDAV.DBA.DAV_PROP_GET (', path, propName, ')');
  declare retValue any;
  declare exit handler for SQLSTATE '*' {goto _exit;};

  WEBDAV.DBA.DAV_API_PARAMS (auth_name, auth_pwd);
  while ((path <> '/'))
  {
    retValue := DB.DBA.DAV_PROP_GET (path, propName, auth_name, auth_pwd);
    if (not WEBDAV.DBA.DAV_ERROR (retValue))
      return retValue;

    path := WEBDAV.DBA.path_parent (path, 1);
  }
_exit:
  return propValue;
}
;

-------------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.DAV_PROP_SET (
  in path varchar,
  in propName varchar,
  in propValue any,
  in auth_name varchar := null,
  in auth_pwd varchar := null,
  in removeBefore integer := 1)
{
  -- dbg_obj_princ ('WEBDAV.DBA.DAV_PROP_SET (', path, propName, propValue, ')');
  WEBDAV.DBA.DAV_API_PARAMS (auth_name, auth_pwd);
  return DB.DBA.DAV_PROP_SET (path, propName, propValue, auth_name, auth_pwd, 1);
}
;

-------------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.DAV_PROP_TAGS_SET (
  in path varchar,
  in propname varchar,
  in propvalue any,
  in auth_name varchar := null,
  in auth_pwd varchar := null)
{
  WEBDAV.DBA.DAV_API_PARAMS (auth_name, auth_pwd);
  DB.DBA.DAV_PROP_REMOVE (path, propname, auth_name, auth_pwd);
  if (propvalue = '')
    return 1;

  return DB.DBA.DAV_PROP_SET (path, propname, propvalue, auth_name, auth_pwd);

}
;

-------------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.DAV_RDF_PROP_GET (
  in path varchar,            -- Path to the resource or collection
  in single_schema varchar,   -- Name of single RDF schema to filter out redundant records or NULL to compose any number of properties.
  in auth_name varchar := null,
  in auth_pwd varchar := null)
{
  WEBDAV.DBA.DAV_API_PARAMS (auth_name, auth_pwd);
  return DB.DBA.DAV_RDF_PROP_GET (path, single_schema, auth_name, auth_pwd);
}
;

-------------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.DAV_RDF_PROP_SET (
  in path varchar,            -- Path to the resource or collection
  in single_schema varchar,   -- Name of single RDF schema to filter out redundant records or NULL to compose any number of properties.
  in rdf any,                 -- RDF XML
  in auth_name varchar := null,
  in auth_pwd varchar := null)
{
  WEBDAV.DBA.DAV_API_PARAMS (auth_name, auth_pwd);
  return DB.DBA.DAV_RDF_PROP_SET_INT (path, single_schema, rdf, auth_name, auth_pwd, 1, 1, 1);
}
;

-------------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.DAV_PROP_REMOVE (
  in path varchar,
  in propname varchar,
  in auth_name varchar := null,
  in auth_pwd varchar := null)
{
  WEBDAV.DBA.DAV_API_PARAMS (auth_name, auth_pwd);
  return DB.DBA.DAV_PROP_REMOVE (path, propname, auth_name, auth_pwd);
}
;

-------------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.DAV_IS_LOCKED (
  in path varchar,
  in type varchar := 'R')
{
  declare id integer;

  id := DB.DBA.DAV_SEARCH_ID (path, type);
  return DB.DBA.DAV_IS_LOCKED (id, type);
}
;

-------------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.DAV_LOCK (
  in path varchar,
  in type varchar := 'R',
  in auth_name varchar := null,
  in auth_pwd varchar := null)
{
  declare retValue varchar;

  WEBDAV.DBA.DAV_API_PARAMS (auth_name, auth_pwd);
  retValue := DB.DBA.DAV_LOCK (path, type, '', '', auth_name, null, null, null, auth_name, auth_pwd);
  if (isstring (retValue))
    return 1;

  return retValue;
}
;

-------------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.DAV_UNLOCK (
  in path varchar,
  in type varchar := 'R',
  in auth_name varchar := null,
  in auth_pwd varchar := null)
{
  declare id integer;
  declare locks, retValue any;

  WEBDAV.DBA.DAV_API_PARAMS (auth_name, auth_pwd);
  id := DB.DBA.DAV_SEARCH_ID (path, type);
  locks := DB.DBA.DAV_LIST_LOCKS_INT (id, type);
  foreach (any lock in locks) do
  {
    retValue := DB.DBA.DAV_UNLOCK (path, lock[2], auth_name, auth_pwd);
    if (WEBDAV.DBA.DAV_ERROR (retValue))
      return retValue;
  }
  return 1;
}
;

-------------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.DAV_REQUIRE_VERSION (
  in req_version varchar)
{
  declare dav_version varchar;

  dav_version := '0.0';
  if (__proc_exists ('DB.DBA.DAV_VERSION') is not null)
    dav_version := DB.DBA.DAV_VERSION ();

  return case when VAD.DBA.VER_LT (req_version, dav_version) or (dav_version = req_version) then 1 else 0 end;
}
;

-------------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.get_rdf (
  in graphName varchar)
{
  declare sql, st, msg, meta, rows any;

  sql := sprintf('sparql define output:format ''RDF/XML'' construct { ?s ?p ?o } where { graph <%s> { ?s ?p ?o } }', graphName);
  st := '00000';
  exec (sql, st, msg, vector (), 0, meta, rows);
  if ('00000' = st)
    return rows[0][0];
  return '';
}
;

-----------------------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.test_clear (
  in S any)
{
  S := substring (S, 1, coalesce (strstr (S, '<>'), length (S)));
  S := substring (S, 1, coalesce (strstr (S, '\nin'), length (S)));

  return S;
}
;

-----------------------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.test (
  in value any,
  in params any := null)
{
  declare valueType, valueClass, valueName, valueMessage, tmp any;

  declare exit handler for SQLSTATE '*' {
    if (not is_empty_or_null(valueMessage))
      signal ('TEST', valueMessage);
    if (__SQL_STATE = 'EMPTY')
      signal ('TEST', sprintf('Field ''%s'' cannot be empty!<>', valueName));
    if (__SQL_STATE = 'CLASS') {
      if (valueType in ('free-text', 'tags')) {
        signal ('TEST', sprintf('Field ''%s'' contains invalid characters or noise words!<>', valueName));
      } else {
        signal ('TEST', sprintf('Field ''%s'' contains invalid characters!<>', valueName));
      }
    }
    if (__SQL_STATE = 'TYPE')
      signal ('TEST', sprintf('Field ''%s'' contains invalid characters for \'%s\'!<>', valueName, valueType));
    if (__SQL_STATE = 'MIN')
      signal ('TEST', sprintf('''%s'' value should be greater than %s!<>', valueName, cast (tmp as varchar)));
    if (__SQL_STATE = 'MAX')
      signal ('TEST', sprintf('''%s'' value should be less than %s!<>', valueName, cast (tmp as varchar)));
    if (__SQL_STATE = 'MINLENGTH')
      signal ('TEST', sprintf('The length of field ''%s'' should be greater than %s characters!<>', valueName, cast (tmp as varchar)));
    if (__SQL_STATE = 'MAXLENGTH')
      signal ('TEST', sprintf('The length of field ''%s'' should be less than %s characters!<>', valueName, cast (tmp as varchar)));
    signal ('TEST', 'Unknown validation error!<>');
    --resignal;
  };

  value := trim(value);
  if (is_empty_or_null(params))
    return value;

  valueClass := coalesce (get_keyword ('class', params), get_keyword ('type', params));
  valueType := coalesce (get_keyword ('type', params), get_keyword ('class', params));
  valueName := get_keyword ('name', params, 'Field');
  valueMessage := get_keyword ('message', params, '');
  tmp := get_keyword ('canEmpty', params);
  if (isnull (tmp))
  {
    if (not isnull (get_keyword ('minValue', params))) {
      tmp := 0;
    } else if (get_keyword ('minLength', params, 0) <> 0) {
      tmp := 0;
    }
  }
  if (not isnull (tmp) and (tmp = 0) and is_empty_or_null(value)) {
    signal('EMPTY', '');
  } else if (is_empty_or_null(value)) {
    return value;
  }

  value := WEBDAV.DBA.validate2 (valueClass, value);

  if (valueType = 'integer') {
    tmp := get_keyword ('minValue', params);
    if ((not isnull (tmp)) and (value < tmp))
      signal('MIN', cast (tmp as varchar));

    tmp := get_keyword ('maxValue', params);
    if (not isnull (tmp) and (value > tmp))
      signal('MAX', cast (tmp as varchar));
  }
  else if (valueType = 'float')
  {
    tmp := get_keyword ('minValue', params);
    if (not isnull (tmp) and (value < tmp))
      signal('MIN', cast (tmp as varchar));

    tmp := get_keyword ('maxValue', params);
    if (not isnull (tmp) and (value > tmp))
      signal('MAX', cast (tmp as varchar));
  }
  else if (valueType = 'varchar')
  {
    tmp := get_keyword ('minLength', params);
    if (not isnull (tmp) and (length (value) < tmp))
      signal('MINLENGTH', cast (tmp as varchar));

    tmp := get_keyword ('maxLength', params);
    if (not isnull (tmp) and (length (value) > tmp))
      signal('MAXLENGTH', cast (tmp as varchar));
  }
  return value;
}
;

-----------------------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.validate2 (
  in propertyType varchar,
  in propertyValue varchar)
{
  declare exit handler for SQLSTATE '*' {
    if (__SQL_STATE = 'CLASS')
      resignal;
    signal('TYPE', propertyType);
    return;
  };

  if (propertyType = 'boolean') {
    if (propertyValue not in ('Yes', 'No'))
      goto _error;
  } else if (propertyType = 'integer') {
    if (isnull (regexp_match('^[0-9]+\$', propertyValue)))
      goto _error;
    return cast (propertyValue as integer);
  } else if (propertyType = 'float') {
    if (isnull (regexp_match('^[-+]?([0-9]*\.)?[0-9]+([eE][-+]?[0-9]+)?\$', propertyValue)))
      goto _error;
    return cast (propertyValue as float);
  } else if (propertyType = 'dateTime') {
    if (isnull (regexp_match('^((?:19|20)[0-9][0-9])[- /.](0[1-9]|1[012])[- /.](0[1-9]|[12][0-9]|3[01])\$', propertyValue)))
      if (isnull (regexp_match('^((?:19|20)[0-9][0-9])[- /.](0[1-9]|1[012])[- /.](0[1-9]|[12][0-9]|3[01]) ([01]?[0-9]|[2][0-3])(:[0-5][0-9])?\$', propertyValue)))
        goto _error;
    return cast (propertyValue as datetime);
  } else if (propertyType = 'dateTime2') {
    if (isnull (regexp_match('^((?:19|20)[0-9][0-9])[- /.](0[1-9]|1[012])[- /.](0[1-9]|[12][0-9]|3[01]) ([01]?[0-9]|[2][0-3])(:[0-5][0-9])?\$', propertyValue)))
      goto _error;
    return cast (propertyValue as datetime);
  } else if (propertyType = 'date') {
    if (isnull (regexp_match('^((?:19|20)[0-9][0-9])[- /.](0[1-9]|1[012])[- /.](0[1-9]|[12][0-9]|3[01])\$', propertyValue)))
      goto _error;
    return cast (propertyValue as datetime);
  } else if (propertyType = 'date2') {
    if (isnull (regexp_match('^(0[1-9]|[12][0-9]|3[01])[- /.](0[1-9]|1[012])[- /.]((?:19|20)[0-9][0-9])\$', propertyValue)))
      goto _error;
    return cast (propertyValue as datetime);
  } else if (propertyType = 'time') {
    if (isnull (regexp_match('^([01]?[0-9]|[2][0-3])(:[0-5][0-9])?\$', propertyValue)))
      goto _error;
    return cast (propertyValue as time);
  } else if (propertyType = 'folder') {
    if (isnull (regexp_match('^[^\\\/\?\*\"\'\>\<\:\|]*\$', propertyValue)))
      goto _error;
  } else if ((propertyType = 'uri') or (propertyType = 'anyuri')) {
    if (isnull (regexp_match('^(ht|f)tp(s?)\:\/\/[0-9a-zA-Z]([-.\w]*[0-9a-zA-Z])*(:(0-9)*)*(\/?)([a-zA-Z0-9\-\.\?\,\'\/\\\+&amp;%\$#_=:]*)?\$', propertyValue)))
      goto _error;
  } else if (propertyType = 'email') {
    if (isnull (regexp_match('^([a-zA-Z0-9_\-])+(\.([a-zA-Z0-9_\-])+)*@((\[(((([0-1])?([0-9])?[0-9])|(2[0-4][0-9])|(2[0-5][0-5])))\.(((([0-1])?([0-9])?[0-9])|(2[0-4][0-9])|(2[0-5][0-5])))\.(((([0-1])?([0-9])?[0-9])|(2[0-4][0-9])|(2[0-5][0-5])))\.(((([0-1])?([0-9])?[0-9])|(2[0-4][0-9])|(2[0-5][0-5]))\]))|((([a-zA-Z0-9])+(([\-])+([a-zA-Z0-9])+)*\.)+([a-zA-Z])+(([\-])+([a-zA-Z0-9])+)*))\$', propertyValue)))
      goto _error;
  } else if (propertyType = 'free-text') {
    if (length (propertyValue))
      vt_parse(propertyValue);
  } else if (propertyType = 'tags') {
    if (not WEBDAV.DBA.validate_tags(propertyValue))
      goto _error;
  }
  return propertyValue;

_error:
  signal('CLASS', propertyType);
}
;

-----------------------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.validate_ftext (
  in S varchar)
{
  declare st, msg varchar;

  st := '00000';
  exec ('vt_parse (?)', st, msg, vector (S));
  if ('00000' = st)
    return 1;
  return 0;
}
;

-----------------------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.validate_tag (
  in S varchar)
{
  S := replace (trim(S), '+', '_');
  S := replace (trim(S), ' ', '_');
  if (not WEBDAV.DBA.validate_ftext(S))
    return 0;
  if (not isnull (strstr(S, '"')))
    return 0;
  if (not isnull (strstr(S, '''')))
    return 0;
  if (length (S) < 2)
    return 0;
  if (length (S) > 50)
    return 0;
  return 1;
}
;

-----------------------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.validate_tags (
  in S varchar)
{
  declare N integer;
  declare V any;

  if (is_empty_or_null(S))
    return 1;
  V := WEBDAV.DBA.tags2vector (S);
  if (is_empty_or_null(V))
    return 0;
  if (length(V) <> length(WEBDAV.DBA.tags2unique(V)))
    return 0;
  for (N := 0; N < length(V); N := N + 1)
    if (not WEBDAV.DBA.validate_tag(V[N]))
      return 0;
  return 1;
}
;

-------------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.ui_image (
  in itemPath varchar,
  in itemType varchar,
  in itemMimeType varchar) returns varchar
{
  if (itemType = 'C')
  {
    declare det_type varchar;

    det_type := WEBDAV.DBA.det_type (itemPath, itemType);
    if (det_type = 'CatFilter')
      return 'dav/image/dav/category_16.png';
    if (det_type = 'PropFilter')
      return 'dav/image/dav/property_16.png';
    if (det_type = 'HostFs')
      return 'dav/image/dav/hostfs_16.png';
    if (det_type = 'Versioning')
      return 'dav/image/dav/versions_16.png';
    if (det_type = 'News3')
      return 'dav/image/dav/enews_16.png';
    if (det_type = 'Blog')
      return 'dav/image/dav/blog_16.png';
    if (det_type = 'oMail')
      return 'dav/image/dav/omail_16.png';
    return 'dav/image/dav/foldr_16.png';
  }
  if (itemPath like '%.txt')
    return 'dav/image/dav/text.gif';
  if (itemPath like '%.pdf')
    return 'dav/image/dav/pdf.gif';
  if (itemPath like '%.html')
    return 'dav/image/dav/html.gif';
  if (itemPath like '%.htm')
    return 'dav/image/dav/html.gif';
  if (itemPath like '%.wav')
    return 'dav/image/dav/wave.gif';
  if (itemPath like '%.ogg')
    return 'dav/image/dav/wave.gif';
  if (itemPath like '%.flac')
    return 'dav/image/dav/wave.gif';
  if (itemPath like '%.wma')
    return 'dav/image/dav/wave.gif';
  if (itemPath like '%.wmv')
    return 'dav/image/dav/video.gif';
  if (itemPath like '%.doc')
    return 'dav/image/dav/msword.gif';
  if (itemPath like '%.dot')
    return 'dav/image/dav/msword.gif';
  if (itemPath like '%.xls')
    return 'dav/image/dav/xls.gif';
  if (itemPath like '%.zip')
    return 'dav/image/dav/zip.gif';
  if (itemMimeType like 'audio/%')
    return 'dav/image/dav/wave.gif';
  if (itemMimeType like 'video/%')
    return 'dav/image/dav/video.gif';
  if (itemMimeType like 'image/%')
    return 'dav/image/dav/image.gif';
  return 'dav/image/dav/generic_file.png';
}
;

-------------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.ui_alt (
  in itemPath varchar,
  in itemType varchar)
{
  return case when (itemType = 'C') then 'Folder: ' else 'File: ' end || itemPath ;
}
;

-------------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.ui_size (
  in itemSize integer,
  in itemType varchar := 'R',
  in sizeType varchar := '1',
  in sizeMode integer := 0)
{
  declare D integer;
  declare S varchar;

  if ((itemSize = 0) and (itemType = 'C'))
    return '';

  if (sizeType = '0')
    return cast (itemSize as varchar);

  D := case when (sizeType = '1') then 1000 else 1024 end;
  if (sizeMode)
    S := '<span title="%d Bytes">%d&nbsp;%s</span>';
  else
    S := '<span title="%d Bytes">%d<span style="font-family: Monospace;">&nbsp;%s</span></span>';

  if (itemSize < D)
    return sprintf (S, itemSize, itemSize, case when (sizeType = '1') then 'B&nbsp;' else 'B&nbsp;&nbsp;' end);

  if (itemSize < (D * D))
    return sprintf (S, itemSize, floor(itemSize / D), case when (sizeType = '1') then 'KB' else 'KiB' end);

  if (itemSize < (D * D * D))
    return sprintf (S, itemSize, floor(itemSize / (D * D)), case when (sizeType = '1') then 'MB' else 'MiB' end);

  if (itemSize < (D * D * D * D))
    return sprintf (S, itemSize, floor(itemSize / (D * D * D)), case when (sizeType = '1') then 'GB' else 'GiB' end);

  return sprintf (S, itemSize, floor(itemSize / (D * D * D * D)), case when (sizeType = '1') then 'TB' else 'TiB' end);
}
;

-------------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.ui_date (
  in dt any)
{
  dt := left (cast (dt as varchar), 19);
  return sprintf ('%s <font size="1">%s</font>', left(dt, 10), right(dt, 8));
}
;

-------------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.ui_creator (
  in creator_iri any)
{
  if (DB.DBA.is_empty_or_null (creator_iri))
    return '';

  return sprintf ('<a href="%s" target="_blank" title="Creator - %s">%s</a>', creator_iri, creator_iri, WEBDAV.DBA.user_iri2name (creator_iri));
}
;

-------------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.send_mail (
  in _path varchar,
  in _path_url varchar,
  in _from integer,
  in _to any,
  in _subject varchar,
  in _body varchar,
  in _mode integer := 1,
  in _encryption_state integer := 0)
{
  -- dbg_obj_princ ('WEBDAV.DBA.send_mail (', _path, _path_url, _from, _to, _mode, _encryption_state, ')');
  declare _data any;
  declare _certificate, _encrypt any;
  declare _from_address, _to_address varchar;

  _body := replace (_body, '%resource_path%', _path);
  _body := replace (_body, '%resource_uri%', _path_url);
  _body := replace (_body, '%owner_uri%', WEBDAV.DBA.account_iri (_from));
  _body := replace (_body, '%owner_name%', WEBDAV.DBA.account_name (_from));

  _encrypt := 0;
  _certificate := null;
  _from_address := WEBDAV.DBA.account_mail (_from);

  if (_mode)
  {
    if (_encryption_state)
      WS.WS.SSE_MAIL_CHECK (_to, _certificate, _encrypt, _to_address);

    if (not _encrypt)
      _to_address := WEBDAV.DBA.account_mail (_to);

    WEBDAV.DBA.send_mail_internal (_path, WEBDAV.DBA.account_iri (_to), WEBDAV.DBA.account_name (_to), _from_address, _to_address, _certificate, _subject, _body, _encrypt, _encryption_state);
  }
  else
  {
    _data := WEBDAV.DBA.send_mail_extract (_to, _encryption_state);
    _to_address := get_keyword ('mbox', _data);
    if (_encryption_state)
      _certificate := get_keyword ('certificate', _data);

    WEBDAV.DBA.send_mail_internal (_path, _to, get_keyword ('name', _data, get_keyword ('nick', _data)), _from_address, _to_address, _certificate, _subject, _body, _encrypt, _encryption_state);
  }
}
;

-------------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.send_mail_extract (
  in _uri varchar,
  in _encryption integer := 0)
{
  -- dbg_obj_princ ('WEBDAV.DBA.send_mail_extract (', _uri, ')');
  declare N, P integer;
  declare V, U any;
  declare S, st, msg, meta, rows, rows2, rows3 any;
  declare _graph, _getUri, _key, _publicKey, _digestURI varchar;
  declare _url, _header, _content any;
  declare retValue any;

  set_user_id ('dba');
  retValue := vector ();
  V := rfc1808_parse_uri (trim (_uri));
  V[5] := '';
  _getUri := DB.DBA.vspx_uri_compose (V);
  _graph := 'http://local.virt/dav/' || cast (rnd (1000) as varchar);

  S := sprintf (
       ' sparql ' ||
       ' define get:soft "soft" ' ||
       ' define get:uri <%s> ' ||
       ' prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> ' ||
       ' prefix foaf: <http://xmlns.com/foaf/0.1/> ' ||
       ' prefix cert: <http://www.w3.org/ns/auth/cert#> ' ||
       ' prefix oplcert: <http://www.openlinksw.com/schemas/cert#> ' ||
       ' select ?name ?nick ?mbox ?key ' ||
       '   from <%s> ' ||
       '  where ' ||
       '   { ' ||
       '     ?iri rdf:type foaf:Person . ' ||
       '     optional { ?iri foaf:name ?name } . ' ||
       '     optional { ?iri foaf:nick ?nick } . ' ||
       '     optional { ?iri foaf:mbox ?mbox } . ' ||
       '     optional { ?iri cert:key ?key } . ' ||
       '     optional { ?key rdf:type cert:RSAPublicKey } . ' ||
       '     filter (?iri = <%s>). ' ||
       '   } ',
       _getUri,
       _graph,
       _uri);

  st := '00000';
  exec (S, st, msg, vector (), 0, meta, rows);
  if ((st <> '00000') or (length (rows) = 0))
    goto _exit;

  SPARQL clear graph ?:_graph;
  retValue := vector ('name', cast (rows[0][0] as varchar), 'nick', cast (rows[0][1] as varchar), 'mbox', replace (cast (rows[0][2] as varchar), 'mailto:', ''));
  if (not _encryption)
    goto _exit;

  for (N := 0; N < length (rows); N := N + 1)
  {
    _key := cast (rows[N][3] as varchar);
    if (not isnull (_key))
    {
      S := sprintf (
           ' sparql ' ||
           ' define get:soft "soft" ' ||
           ' define get:uri <%s> ' ||
           ' prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> ' ||
           ' prefix foaf: <http://xmlns.com/foaf/0.1/> ' ||
           ' prefix cert: <http://www.w3.org/ns/auth/cert#> ' ||
           ' prefix oplcert: <http://www.openlinksw.com/schemas/cert#> ' ||
           ' select ?publicKey ' ||
           '   from <%s> ' ||
           '  where ' ||
           '  { ' ||
           '    ?publicKey oplcert:hasPublicKey ?key. ' ||
           '    filter (?key = <%s>). ' ||
           '  } ',
           _key,
           _graph,
           _key);

      st := '00000';
      exec (S, st, msg, vector (), 0, meta, rows2);
      SPARQL clear graph ?:_graph;
      if ((st <> '00000') or (length (rows2) = 0))
        goto _skip;

      _publicKey := cast (rows2[0][0] as varchar);
      U := V;
      U[2] := '';
      U[3] := '';
      U[4] := '';
      U[5] := '';
      _url := DB.DBA.vspx_uri_compose (U);
      _url := _url || sprintf ('/sparql/?query=%U&output=%U', sprintf ('define sql:describe-mode "LOD" DESCRIBE <%s>', _publicKey), 'text/plain');
      _header := null;
      _content := http_client_ext (url=>_url, http_method=>'GET', headers =>_header, n_redirects=>15);
      if ((_header[0] like 'HTTP/1._ 4__ %') or (_header[0] like 'HTTP/1._ 5__ %'))
        goto _skip;

      DB.DBA.TTLP (_content, _graph, _graph);
      S := sprintf (
           ' sparql ' ||
           ' prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> ' ||
           ' prefix foaf: <http://xmlns.com/foaf/0.1/> ' ||
           ' prefix cert: <http://www.w3.org/ns/auth/cert#> ' ||
           ' prefix oplcert: <http://www.openlinksw.com/schemas/cert#> ' ||
           ' select ?digestURI ' ||
           '   from <%s> ' ||
           '  where ' ||
           '  { ' ||
           '    <%s> oplcert:digestURI ?digestURI. ' ||
           '  } ',
           _graph,
           _publicKey);

      st := '00000';
      exec (S, st, msg, vector (), 0, meta, rows3);
      SPARQL clear graph ?:_graph;
      if ((st <> '00000') or (length (rows3) = 0))
        goto _skip;

      _digestURI := rows3[0][0];
      P := strstr (_digestURI, '&http=');
      if (isnull (P))
        goto _skip;

      _url := 'http://' || subseq (_digestURI, P + 6) || '/.well-known/' || replace (replace (subseq (_digestURI, 0, P), ':', '/'), ';', '/');
      _header := null;
      _content := http_client_ext (url=>_url, http_method=>'GET', headers =>_header, n_redirects=>15);
      if ((_header[0] like 'HTTP/1._ 4__ %') or (_header[0] like 'HTTP/1._ 5__ %'))
        goto _skip;

      retValue := vector_concat (retValue, vector ('certificate', _content));
      goto _exit;

    _skip:;
      SPARQL clear graph ?:_graph;
    }
  }

_exit:;
  SPARQL clear graph ?:_graph;
  return retValue;
}
;

-------------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.send_mail_internal (
  in _path varchar,
  in _user_uri varchar,
  in _user_name varchar,
  in _from_address varchar,
  in _to_address varchar,
  in _certificate any,
  in _subject varchar,
  in _body varchar,
  in _encrypt integer := 0,
  in _encryption_state integer := 0)
{
  -- dbg_obj_princ ('WEBDAV.DBA.send_mail_internal (', _from_address, _to_address, _encrypt, _encryption_state, ')');
  declare _message varchar;
  declare _smtp_server any;

  _smtp_server := cfg_item_value (virtuoso_ini_path (), 'HTTPServer', 'DefaultMailServer');
  if (_smtp_server = 0)
    return;

  if (is_empty_or_null (_from_address))
    return;

  if (is_empty_or_null (_to_address))
    return;

  _body := replace (_body, '%user_uri%', _user_uri);
  _body := replace (_body, '%user_name%', _user_name);
  if (_encrypt and not isnull (_certificate))
  {
    declare _what, _password varchar;

    _what := WEBDAV.DBA.path_type (_path);
    _password := WS.WS.SSE_PASSWORD_GET (DB.DBA.DAV_SEARCH_ID (_path, _what), _what);
    _body := _body || sprintf ('\r\n\r\nP.S. The file is encrypted with AES-256 encryption. The password is %s.', _password);
    _message := WEBDAV.DBA.send_mail_prepare (_subject, _body);
    _message := smime_encrypt (_message, vector (_certificate), 'AES256');
  }
  else if (_encryption_state)
  {
    _body := _body || '\r\n\r\nP.S. The file is encrypted with AES-256 encryption. Please, find secure way to get encryption password.';
    _message := WEBDAV.DBA.send_mail_prepare (_subject, _body);
  }
  else
  {
    _message := WEBDAV.DBA.send_mail_prepare (_subject, _body);
  }

  {
    declare exit handler for sqlstate '*' { return;};

    -- dbg_obj_print (_from_address, _to_address, _body);
    -- string_to_file ('test.eml', sprintf ('From: %s\r\nTo: %s\r\n', _from_address, _to_address) || _message, 2);
    smtp_send (_smtp_server, _from_address, _to_address, _message);
  }
}
;

-------------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.send_mail_prepare (
  in _subject varchar,
  in _body varchar)
{
  declare _stream any;

  _stream := string_output ();

  WS.WS.SSE_MAIL_LINE ('Content-Type: %s; charset=UTF-8;', 'text/plain', _stream);
  WS.WS.SSE_MAIL_LINE ('Subject: %s', _subject, _stream);
  http ('\r\n', _stream);
  http (_body, _stream);

  return string_output_string (_stream);
}
;

-------------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.acl_send_mail (
  in _from integer,
  in _path varchar,
  in _old_acl any,
  in _new_acl any,
  in _encryption_state integer := 0)
{
  declare aq any;
  declare _path_url varchar;

  _path_url := WEBDAV.DBA.ssl2iri (WEBDAV.DBA.dav_url (_path));
  _old_acl := WEBDAV.DBA.acl_vector_unique (WEBDAV.DBA.acl_vector (_old_acl));
  _new_acl := WEBDAV.DBA.acl_vector_unique (WEBDAV.DBA.acl_vector (_new_acl));
  aq := async_queue (1, 4);
  aq_request (aq, 'WEBDAV.DBA.acl_send_mail_aq', vector (_path, _path_url, _from, _old_acl, _new_acl, _encryption_state));
}
;

-------------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.acl_send_mail_aq (
  in _path varchar,
  in _path_url varchar,
  in _from integer,
  in _old_acl any,
  in _new_acl any,
  in _encryption_state integer := 0)
{
  -- dbg_obj_princ ('WEBDAV.DBA.acl_send_mail_aq (', _path, _path_url, _old_acl, _new_acl, _encryption_state, ')');
  declare N integer;
  declare settings, subject, text any;

  settings := WEBDAV.DBA.settings (_from);
  subject := 'Sharing notification';
  text := WEBDAV.DBA.settings_mailShare (settings);
  for (N := 0; N < length (_new_acl); N := N + 1)
  {
    if (not WEBDAV.DBA.vector_contains (_old_acl, _new_acl[N]) or (_encryption_state = 2))
    {
      WEBDAV.DBA.acl_share_create (_new_acl[N]);
      WEBDAV.DBA.send_mail (_path, _path_url, _from, _new_acl[N], subject, text, 1, _encryption_state);
    }
  }
  subject := 'Unsharing notification';
  text := WEBDAV.DBA.settings_mailUnshare (settings);
  for (N := 0; N < length (_old_acl); N := N + 1)
  {
    if (not WEBDAV.DBA.vector_contains (_new_acl, _old_acl[N]))
      WEBDAV.DBA.send_mail (_path, _path_url, _from, _old_acl[N], subject, text, 1, 0);
  }
}
;

-------------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.acl_share_create (
  in _user_id integer)
{
  declare _user_name, _permissions, _home varchar;
  declare _col_id integer;

  if (__proc_exists ('DB.DBA.Share_DAV_AUTHENTICATE') is null)
    return;

  _user_name := WEBDAV.DBA.account_name (_user_id);
  if (isnull (_user_name))
    return;

  _home := '/DAV/home/' || _user_name || '/';
  if (exists (select 1 from WS.WS.SYS_DAV_COL where COL_PARENT = DAV_SEARCH_ID (_home, 'C') and COL_DET = 'Share'))
    return;

  if (exists (select 1 from WS.WS.SYS_DAV_COL where WS.WS.COL_PATH (COL_ID) like (_home || '%') and COL_DET = 'Share'))
    return;

  for (select U_ID, U_PWD, U_GROUP, U_DEF_PERMS, U_HOME from WS.WS.SYS_DAV_USER where U_NAME = _user_name) do
  {
    DB.DBA.DAV_MAKE_DIR (_home || 'Shared Resources/', U_ID, U_GROUP, U_DEF_PERMS);
    WEBDAV.DBA.DAV_SET (_home || 'Shared Resources/', 'detType', 'Share');
  }
}
;

-----------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.aci_vector (
  in aci any)
{
  declare N, I integer;
  declare retValue, webIDs any;

  retValue := vector ();
  for (N := 0; N < length (aci); N := N + 1)
  {
    if      (aci[N][2] = 'person')
    {
      if (not WEBDAV.DBA.vector_contains (retValue, aci[N][1]))
        retValue := vector_concat (retValue, vector (aci[N][1]));
    }
    else if (aci[N][2] = 'group')
    {
      webIDs := WEBDAV.DBA.exec ('select WACL_WEBIDS from DB.DBA.WA_GROUPS_ACL where ? = SIOC..acl_group_iri (WACL_USER_ID, WACL_NAME)', vector (aci[N][1]));
      if (length (webIDs))
      {
        webIDs := split_and_decode (webIDs[0][0], 0, '\0\0\n');
        for (I := 0; I < length (webIDs); I := I + 1)
        {
          if (not WEBDAV.DBA.vector_contains (retValue, webIDs[I]))
            retValue := vector_concat (retValue, vector (webIDs[I]));
        }
      }
    }
  }
  return retValue;
}
;

-------------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.aci_parents (
  in path varchar,
  in pathMode integer := 1)
{
  declare N integer;
  declare tmp, V, aPath any;

  tmp := '/';
  V := vector ();
  aPath := split_and_decode (trim (path, '/'), 0, '\0\0/');
  for (N := 0; N < length (aPath)-pathMode; N := N + 1)
  {
    tmp := tmp || aPath[N] || '/';
    V := vector_concat (V, vector (tmp));
  }
  return V;
}
;

-------------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.aci_load (
  in path varchar,
  in auth_name varchar := null,
  in auth_pwd varchar := null)
{
  declare id, what, retValue, graph any;
  declare S, st, msg, meta, rows any;

  --return vector ();
  what := WEBDAV.DBA.path_type (path);
  id := DB.DBA.DAV_SEARCH_ID (path, what);
  DB.DBA.DAV_AUTHENTICATE_SSL_ITEM (id, what, path);
  if (isarray (id) and (cast (id[0] as varchar) not in ('DynaRes', 'IMAP', 'Share', 'S3', 'GDrive', 'Dropbox', 'SkyDrive', 'Box', 'WebDAV', 'RACKSPACE', 'LDP')))
  {
    retValue := WEBDAV.DBA.DAV_PROP_GET (path, 'virt:aci_meta', auth_name=>auth_name, auth_pwd=>auth_pwd);
    if (WEBDAV.DBA.DAV_ERROR (retValue))
      retValue := vector ();
  }
  else
  {
    retValue := vector ();
    if (isarray (id) and (cast (id[0] as varchar) = 'Share'))
    {
      graph := WS.WS.WAC_GRAPH (DB.DBA.Share__realPath (id, what));
    } else {
      graph := WS.WS.WAC_GRAPH (path);
    }
    S := sprintf (' sparql \n' ||
                  ' define input:storage "" \n' ||
                  ' prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> \n' ||
                  ' prefix foaf: <http://xmlns.com/foaf/0.1/> \n' ||
                  ' prefix acl: <http://www.w3.org/ns/auth/acl#> \n' ||
                  ' prefix flt: <http://www.openlinksw.com/schemas/acl/filter#> \n' ||
                  ' select distinct ?rule ?agent ?agentClass ?mode ?filter ?criteria ?operand ?condition ?pattern ?statement \n' ||
                  '   from <%s> \n' ||
                  '  where { \n' ||
                  '          { \n' ||
                  '            ?rule rdf:type acl:Authorization ; \n' ||
                  '                  acl:accessTo <%s> ; \n' ||
                  '                  acl:mode ?mode ; \n' ||
                  '                  acl:agent ?agent. \n' ||
                  '          } \n' ||
                  '          union \n' ||
                  '          { \n' ||
                  '            ?rule rdf:type acl:Authorization ; \n' ||
                  '                  acl:accessTo <%s> ; \n' ||
                  '                  acl:mode ?mode ; \n' ||
                  '                  acl:agentClass ?agentClass. \n' ||
                  '          } \n' ||
                  '          union \n' ||
                  '          { \n' ||
                  '            ?rule rdf:type acl:Authorization ; \n' ||
                  '                  acl:accessTo <%s> ; \n' ||
                  '                  acl:mode ?mode ; \n' ||
                  '                  flt:hasFilter ?filter . \n' ||
                  '            ?filter flt:hasCriteria ?criteria . \n' ||
                  '            ?criteria flt:operand ?operand ; \n' ||
                  '                      flt:condition ?condition ; \n' ||
                  '                      flt:value ?pattern . \n' ||
                  '            OPTIONAL { ?criteria flt:statement ?statement . } \n' ||
                  '          } \n' ||
                  '        }\n' ||
                  '  order by ?rule ?filter ?criteria\n',
                  graph,
                  graph,
                  graph,
                  graph);
    commit work;
    st := '00000';
    exec (S, st, msg, vector (), 0, meta, rows);
    if (st = '00000')
    {
      declare aclNo, aclRule, aclCriteria, V, F any;

      aclNo := 0;
      aclRule := '';
      V := null;
      F := vector ();
      aclCriteria := '';
      foreach (any row in rows) do
      {
        if (aclRule <> row[0])
        {
          if (not isnull (V))
            retValue := vector_concat (retValue, vector (V));

          aclNo := aclNo + 1;
          aclRule := row[0];
          V := vector (aclNo, null, null, 0, 0, 0);
          F := vector ();
          aclCriteria := '';
        }
        if      (not isnull (row[1]))
        {
          V[1] := row[1];
          V[2] := 'person';
        }
        else if (not isnull (row[2]))
        {
          if (row[2] = 'http://xmlns.com/foaf/0.1/Agent')
          {
            V[1] := 'foaf:Agent';
            V[2] := 'public';
          }
          else
          {
            V[1] := row[2];
            V[2] := 'group';
          }
        }
        else if (not isnull (row[4]))
        {
          V[2] := 'advanced';
          if (aclCriteria <> row[5])
          {
            F := vector_concat (F, vector (vector (1, replace (row[6], 'http://www.openlinksw.com/schemas/acl/filter#', ''), replace (row[7], 'http://www.openlinksw.com/schemas/acl/filter#', ''), cast (row[8] as varchar), cast (row[9] as varchar))));
            aclCriteria := row[5];
            V[1] := F;
          }
        }
        if      (row[3] = 'http://www.w3.org/ns/auth/acl#Read')
          V[3] := 1;

        else if (row[3] = 'http://www.w3.org/ns/auth/acl#Write')
          V[4] := 1;

        else if (row[3] = 'http://www.w3.org/ns/auth/acl#Execute')
          V[5] := 1;
      }
      if (not isnull (V) and not isnull (V[2]))
        retValue := vector_concat (retValue, vector (V));
    }
  }

  return retValue;
}
;

-------------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.aci_save (
  in path varchar,
  inout aci any,
  in auth_name varchar := null,
  in auth_pwd varchar := null)
{
  declare id, what, retValue, tmp any;

  what := WEBDAV.DBA.path_type (path);
  id := DB.DBA.DAV_SEARCH_ID (path, what);
  if (isarray (id) and (cast (id[0] as varchar) not in ('DynaRes', 'IMAP', 'S3', 'GDrive', 'Dropbox', 'SkyDrive', 'Box', 'WebDAV', 'RACKSPACE', 'LDP')))
  {
    retValue := WEBDAV.DBA.DAV_PROP_SET (path, 'virt:aci_meta', aci, auth_name=>auth_name, auth_pwd=>auth_pwd);
  }
  else
  {
    tmp := WEBDAV.DBA.aci_n3 (aci);
    if (isnull (tmp))
    {
      retValue := WEBDAV.DBA.DAV_PROP_REMOVE (path, 'virt:aci_meta_n3', auth_name=>auth_name, auth_pwd=>auth_pwd);
    }
    else
    {
      retValue := WEBDAV.DBA.DAV_PROP_SET (path, 'virt:aci_meta_n3', tmp, auth_name=>auth_name, auth_pwd=>auth_pwd);
    }
  }
  return retValue;
}
;

-------------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.aci_compare (
  inout aci_1 any,
  inout aci_2 any)
{
  declare N, M, L integer;
  declare length_1, length_2 integer;

  length_1 := length (aci_1);
  length_2 := length (aci_2);
  if (length_1 <> length_2)
    return 0;

  for (N := 0; N < length_1; N := N + 1)
  {
    for (M := 0; M < length_2; M := M + 1)
    {
      for (L := 0; L < length (aci_1[N]); L := L + 1)
      {
        if (aci_1[N][L] <> aci_2[M][L])
          goto _continue_2;
      }
      goto _continue_1;

    _continue_2:;
    }
    return 0;

  _continue_1:;
  }

  return 1;
}
;

-------------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.aci_n3 (
  in aci any)
{
  declare N, M integer;
  declare aci_iri, filter_iri, criteria_iri any;
  declare stream, dict, triples any;

  if (length (aci) = 0)
    return null;

  dict := dict_new();
  for (N := 0; N < length (aci); N := N + 1)
  {
    if (not length (aci[N][1]))
      goto _continue;

    aci_iri := iri_to_id (sprintf ('aci_%d', aci[N][0]));
    filter_iri := iri_to_id (sprintf ('filter_%d', aci[N][0]));
    dict_put (dict, vector (aci_iri, iri_to_id ('http://www.w3.org/1999/02/22-rdf-syntax-ns#type'), iri_to_id ('http://www.w3.org/ns/auth/acl#Authorization')), 0);
    dict_put (dict, vector (aci_iri, iri_to_id ('http://www.w3.org/ns/auth/acl#accessTo'), iri_to_id ('xxx')), 0);
    if      (aci[N][2] = 'person')
    {
      dict_put (dict, vector (aci_iri, iri_to_id ('http://www.w3.org/ns/auth/acl#agent'), iri_to_id (aci[N][1])), 0);
    }
    else if (aci[N][2] = 'group')
    {
      dict_put (dict, vector (aci_iri, iri_to_id ('http://www.w3.org/ns/auth/acl#agentClass'), iri_to_id (aci[N][1])), 0);
    }
    else if (aci[N][2] = 'public')
    {
      dict_put (dict, vector (aci_iri, iri_to_id ('http://www.w3.org/ns/auth/acl#agentClass'), iri_to_id ('http://xmlns.com/foaf/0.1/Agent')), 0);
    }
    else if (aci[N][2] = 'advanced')
    {
      dict_put (dict, vector (aci_iri, iri_to_id ('http://www.openlinksw.com/schemas/acl/filter#hasFilter'), filter_iri), 0);
    }
    if (aci[N][3])
      dict_put (dict, vector (aci_iri, iri_to_id ('http://www.w3.org/ns/auth/acl#mode'), iri_to_id ('http://www.w3.org/ns/auth/acl#Read')), 0);

    if (aci[N][4])
      dict_put (dict, vector (aci_iri, iri_to_id ('http://www.w3.org/ns/auth/acl#mode'), iri_to_id ('http://www.w3.org/ns/auth/acl#Write')), 0);

    if (aci[N][5])
      dict_put (dict, vector (aci_iri, iri_to_id ('http://www.w3.org/ns/auth/acl#mode'), iri_to_id ('http://www.w3.org/ns/auth/acl#Execute')), 0);

    if (aci[N][2] <> 'advanced')
      goto _continue;

    dict_put (dict, vector (filter_iri, iri_to_id ('http://www.w3.org/1999/02/22-rdf-syntax-ns#type'), iri_to_id ('http://www.openlinksw.com/schemas/acl/filter#Filter')), 0);
    for (M := 0; M < length (aci[N][1]); M := M + 1)
    {
      criteria_iri := iri_to_id (sprintf ('criteria_%d_%d', aci[N][0], aci[N][1][M][0]));
      dict_put (dict, vector (filter_iri, iri_to_id ('http://www.openlinksw.com/schemas/acl/filter#hasCriteria'), criteria_iri), 0);
      dict_put (dict, vector (criteria_iri, iri_to_id ('http://www.w3.org/1999/02/22-rdf-syntax-ns#type'), iri_to_id ('http://www.openlinksw.com/schemas/acl/filter#Criteria')), 0);
      dict_put (dict, vector (criteria_iri, iri_to_id ('http://www.openlinksw.com/schemas/acl/filter#operand'), iri_to_id ('http://www.openlinksw.com/schemas/acl/filter#' || aci[N][1][M][1])), 0);
      dict_put (dict, vector (criteria_iri, iri_to_id ('http://www.openlinksw.com/schemas/acl/filter#condition'), iri_to_id ('http://www.openlinksw.com/schemas/acl/filter#' || aci[N][1][M][2])), 0);
      dict_put (dict, vector (criteria_iri, iri_to_id ('http://www.openlinksw.com/schemas/acl/filter#value'), aci[N][1][M][3]), 0);
      if ((length (aci[N][1][M]) > 3) and not DB.DBA.is_empty_or_null (aci[N][1][M][4]))
      {
        dict_put (dict, vector (criteria_iri, iri_to_id ('http://www.openlinksw.com/schemas/acl/filter#statement'), aci[N][1][M][4]), 0);
      }
    }

  _continue:;
  }
  stream := string_output ();
   triples := dict_list_keys (dict, 0);
  if (length (triples))
    DB.DBA.RDF_TRIPLES_TO_NICE_TTL (triples, stream);

  return replace (string_output_string (stream), '<xxx>', '<>');
}
;

-------------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.aci_send_mail (
  in _from integer,
  in _path varchar,
  in _old_acl any,
  in _new_acl any,
  in _encryption_state integer := 0)
{
  declare aq any;
  declare _path_url varchar;

  _path_url := WEBDAV.DBA.iri2ssl (WEBDAV.DBA.dav_url (_path));
  _old_acl := WEBDAV.DBA.aci_vector (_old_acl);
  _new_acl := WEBDAV.DBA.aci_vector (_new_acl);
  aq := async_queue (1, 4);
  aq_request (aq, 'WEBDAV.DBA.aci_send_mail_aq', vector (_path, _path_url, _from, _old_acl, _new_acl, _encryption_state));
}
;

-------------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.aci_send_mail_aq (
  in _path varchar,
  in _path_url varchar,
  in _from integer,
  in _old_acl any,
  in _new_acl any,
  in _encryption_state integer := 0)
{
  -- dbg_obj_princ ('WEBDAV.DBA.aci_send_mail_aq (', _path, _path_url, _old_acl, _new_acl, ')');
  declare N integer;
  declare settings, subject, text any;

  settings := WEBDAV.DBA.settings (_from);
  subject := 'Sharing notification';
  text := WEBDAV.DBA.settings_mailShare (settings);
  for (N := 0; N < length (_new_acl); N := N + 1)
  {
    if (not WEBDAV.DBA.vector_contains (_old_acl, _new_acl[N]) or (_encryption_state = 2))
      WEBDAV.DBA.send_mail (_path, _path_url, _from, _new_acl[N], subject, text, 0, _encryption_state);
  }
  subject := 'Unsharing notification';
  text := WEBDAV.DBA.settings_mailUnshare (settings);
  for (N := 0; N < length (_old_acl); N := N + 1)
  {
    if (not WEBDAV.DBA.vector_contains (_new_acl, _old_acl[N]))
      WEBDAV.DBA.send_mail (_path, _path_url, _from, _old_acl[N], subject, text, 0, 0);
  }
}
;

-------------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.aci_params (
  in params any,
  in tbl varchar := 's')
{
  declare I, N, M, N2, M2 integer;
  declare aclNo, aclNo2, retValue, V, V2, T any;

  M := 1;
  retValue := vector ();
  for (N := 0; N < length (params); N := N + 2)
  {
    if (params[N] like (tbl || '_fld_2_%'))
    {
      aclNo := replace (params[N], tbl || '_fld_2_', '');
      if (aclNo = cast (atoi (replace (params[N], tbl || '_fld_2_', '')) as varchar))
      {
        if (get_keyword (tbl || '_fld_1_' || aclNo, params) = 'advanced')
        {
          M2 := 1;
          T := vector ();
          for (N2 := 0; N2 < length (params); N2 := N2 + 2)
          {
            if (params[N2] like (params[N] || '_fld_1_%'))
            {
              aclNo2 := replace (params[N2], params[N] || '_fld_1_', '');
              if (not DB.DBA.is_empty_or_null (get_keyword (params[N] || '_fld_1_' || aclNo2, params)))
              {
                V2 := vector (M2,
                              trim (get_keyword (params[N] || '_fld_1_' || aclNo2, params)),
                              trim (get_keyword (params[N] || '_fld_2_' || aclNo2, params)),
                              trim (get_keyword (params[N] || '_fld_3_' || aclNo2, params)),
                              trim (get_keyword (params[N] || '_fld_0_' || aclNo2, params, ''))
                             );
                T := vector_concat (T, vector (V2));
                M2 := M2 + 1;
              }
            }
          }
          if (length (T) = 0)
            goto _skip;
        }
        else
        {
          T := trim (params[N+1]);
        }
        V := vector (M,
                     T,
                     get_keyword (tbl || '_fld_1_' || aclNo, params),
                     atoi (get_keyword (tbl || '_fld_3_' || aclNo || '_r', params, '0')),
                     atoi (get_keyword (tbl || '_fld_3_' || aclNo || '_w', params, '0')),
                     atoi (get_keyword (tbl || '_fld_3_' || aclNo || '_x', params, '0'))
                    );
        if (V[2] <> 'advanced')
        {
          for (I := 0; I < length (retValue); I := i + 1)
          {
            if (V[1] = retValue[I][1])
            {
              if (V[3] = 1)
                retValue[I][3] := 1;

              if (V[4] = 1)
                retValue[I][4] := 1;

              if (V[5] = 1)
                retValue[I][5] := 1;

              goto _skip;
            }
          }
        }
        retValue := vector_concat (retValue, vector (V));
        M := M + 1;
      _skip:;
      }
    }
  }
  return retValue;
}
;

-------------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.aci_lines (
  in _acl any,
  in _mode varchar := 'view',
  in _execute varchar := 'false',
  in _advanced varchar := null,
  in _tbl varchar := 's')
{
  declare N integer;

  if (isnull (_advanced))
    _advanced := case when WEBDAV.DBA.VAD_CHECK ('Framework') and (sys_stat('st_has_vdb') = 1) then 'false' else 'true' end;

  for (N := 0; N < length (_acl); N := N + 1)
  {
    if (_mode = 'view')
    {
      http (sprintf ('OAT.MSG.attach(OAT, "PAGE_LOADED", function(){TBL.createViewRow("%s", {fld_1: {mode: 50, value: "%s"}, fld_2: {mode: 51, value: %s}, fld_3: {mode: 52, value: [%d, %d, %d], execute: \'%s\', tdCssText: "width: 1%%; white-space: nowrap; text-align: center;"}, fld_4: {value: "Inherited"}});});', _tbl, _acl[N][2], WEBDAV.DBA.obj2json (_acl[N][1]), _acl[N][3], _acl[N][4], _acl[N][5], _execute));
    }
    else if (_mode = 'disabled')
    {
      http (sprintf ('OAT.MSG.attach(OAT, "PAGE_LOADED", function(){TBL.createViewRow("%s", {fld_1: {mode: 50, value: "%s"}, fld_2: {mode: 51, value: %s}, fld_3: {mode: 52, value: [%d, %d, %d], execute: \'%s\', tdCssText: "width: 1%%; white-space: nowrap; text-align: center;"}, fld_4: {value: ""}});});', _tbl, _acl[N][2], WEBDAV.DBA.obj2json (_acl[N][1]), _acl[N][3], _acl[N][4], _acl[N][5], _execute));
    }
    else
    {
      http (sprintf ('OAT.MSG.attach(OAT, "PAGE_LOADED", function(){TBL.createRow("%s", null, {fld_1: {mode: 50, value: "%s", noAdvanced: %s, onchange: function(){TBL.changeCell50(this);}}, fld_2: {mode: 51, form: "F1", tdCssText: "white-space: nowrap;", className: "_validate_ _webid_", value: %s, readOnly: %s, imgCssText: "%s"}, fld_3: {mode: 52, value: [%d, %d, %d], execute: \'%s\', tdCssText: "width: 1%%; text-align: center;"}});});', _tbl, _acl[N][2], _advanced, WEBDAV.DBA.obj2json (_acl[N][1]), case when _acl[N][2] = 'public' then 'true' else 'false' end, case when _acl[N][2] = 'public' then 'display: none;' else '' end, _acl[N][3], _acl[N][4], _acl[N][5], _execute));
    }
  }
}
;

-------------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.path_normalize (
  in path varchar,
  in path_type varchar := 'P')
{
  path := trim (path);
  if (length (path) > 0)
  {
    if (chr (path[0]) <> '/')
    {
      path := '/' || path;
    }
    if ((path_type = 'C') and (chr (path[length (path)-1]) <> '/'))
    {
      path := path || '/';
    }
    if (chr (path[1]) = '~')
    {
      path := replace (path, '/~', '/DAV/home/');
    }
    if (path not like '/DAV/%')
    {
      path := '/DAV' || path;
    }
    path := replace (path, '//', '/');
  }
  return path;
}
;

-------------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.iri2ssl (
  in iri varchar)
{
  declare V, ssl any;

  if (__proc_exists ('ODS.ODS_API.getDefaultHttps') is null)
    return iri;

  if (iri not like 'https://%')
  {
    ssl := ODS.ODS_API.getDefaultHttps ();
    if (ssl is not null)
    {
      V := rfc1808_parse_uri (iri);
      V[0] := 'https';
      V[1] := ssl;
      iri := DB.DBA.vspx_uri_compose (V);
    }
  }
  return iri;
}
;

-------------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.ssl2iri (
  in iri varchar)
{
  declare V, noSsl any;

  if (iri not like 'http://%')
  {
    noSsl := cfg_item_value (virtuoso_ini_path (), 'URIQA', 'DefaultHost');
    if (noSsl is not null)
    {
      V := rfc1808_parse_uri (iri);
      V[0] := 'http';
      V[1] := noSsl;
      iri := DB.DBA.vspx_uri_compose (V);
    }
  }
  return iri;
}
;

-------------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.VAD_CHECK (
  in vad_name varchar)
{
  if (isnull (VAD_CHECK_VERSION (vad_name)))
    return 0;
  return 1;
}
;

-------------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.syncml_detect (
  in path varchar)
{
  if (__proc_exists ('DB.DBA.yac_syncml_detect') is not null)
    return DB.DBA.yac_syncml_detect (path);

  return 0;
}
;

-------------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.syncml_versions ()
{
  if (__proc_exists ('DB.DBA.yac_syncml_version') is not null)
    return DB.DBA.yac_syncml_version ();

  return vector ();
}
;

-------------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.syncml_version (
  in path varchar)
{
  if (__proc_exists ('DB.DBA.yac_syncml_version_get') is not null)
    return DB.DBA.yac_syncml_version_get (path);

  return 'N';
}
;

-------------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.syncml_types ()
{
  if (__proc_exists ('DB.DBA.yac_syncml_type') is not null)
    return DB.DBA.yac_syncml_type ();

  return vector ();
}
;

-------------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.syncml_type (
  in path varchar)
{
  if (__proc_exists ('DB.DBA.yac_syncml_type_get') is not null)
    return DB.DBA.yac_syncml_type_get (path);

  return 'N';
}
;

-------------------------------------------------------------------------------
--
-- DB.DBA.RDF_LOAD_HTML_RESPONSE
--
create procedure WEBDAV.DBA.cartridges_get ()
{
  declare selected integer;
  declare retValue any;

  retValue := vector ();
  for (select RM_ID, RM_DESCRIPTION, RM_HOOK, ucase (cast (RM_DESCRIPTION as varchar (128))) as RM_SORT from DB.DBA.SYS_RDF_MAPPERS where RM_ENABLED = 1 order by 4) do
  {
    if (RM_HOOK in ('DB.DBA.RDF_LOAD_HTML_RESPONSE'))
      selected := 1;
    else if (RM_HOOK in ('DB.DBA.RDF_LOAD_EML'))
      selected := 2;
    else
      selected := 0;

    retValue := vector_concat (retValue, vector (vector (RM_ID, RM_DESCRIPTION, selected)));
  }
  return retValue;
}
;

-------------------------------------------------------------------------------
--
-- DB.DBA.RDF_LOAD_CALAIS,
-- DB.DBA.RDF_LOAD_ZEMANTA
-- DB.DBA.RDF_LOAD_ALCHEMY_META
-- DB.DBA.RDF_LOAD_YAHOO_TERM_META
-- DB.DBA.RDF_LOAD_DBPEDIA_SPOTLIGHT_META
--
create procedure WEBDAV.DBA.metaCartridges_get ()
{
  declare selected integer;
  declare items, retValue any;

  retValue := vector ();
  items := WEBDAV.DBA.exec ('select MC_ID, MC_DESC, MC_HOOK, ucase (cast (MC_DESC as varchar (128))) as MC_SORT from DB.DBA.RDF_META_CARTRIDGES where MC_ENABLED = 1 order by 4');
  foreach (any item in items) do
  {
    selected := 0;
    if (item[2] in ('DB.DBA.RDF_LOAD_CALAIS', 'DB.DBA.RDF_LOAD_ZEMANTA', 'DB.DBA.RDF_LOAD_ALCHEMY_META', 'DB.DBA.RDF_LOAD_YAHOO_CONTENT_ANALYSIS_META', 'DB.DBA.RDF_LOAD_DBPEDIA_SPOTLIGHT_META'))
      selected := 1;

    retValue := vector_concat (retValue, vector (vector (item[0], item[1], selected)));
  }
  return retValue;
}
;

-------------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.ldp_recovery (
  in path varchar := null)
{
  declare aq any;
  declare exit handler for SQLSTATE '*'
  {
    return WEBDAV.DBA.ldp_recovery_aq (path);
  };

  aq := async_queue (1, 4);
  if (isnull (path))
    aq_request (aq, 'WEBDAV.DBA.ldp_recovery_all_aq', vector ());

  aq_request (aq, 'WEBDAV.DBA.ldp_recovery_aq', vector (path, 0));
}
;

-------------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.ldp_recovery_all_aq ()
{
  -- dbg_obj_princ ('WEBDAV.DBA.ldp_recovery_all_aq ()');
  declare id integer;
  declare uri, ruri any;

  for (select PROP_PARENT_ID, PROP_TYPE from WS.WS.SYS_DAV_PROP where PROP_NAME = 'LDP' and PROP_TYPE = 'C') do
  {
    WEBDAV.DBA.ldp_recovery_aq (DB.DBA.DAV_SEARCH_PATH (PROP_PARENT_ID, PROP_TYPE));
  }
}
;

-------------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.ldp_recovery_aq (
  in path varchar,
  in enabled integer := 0)
{
  -- dbg_obj_princ ('WEBDAV.DBA.ldp_recovery_aq (', path, ')');
  declare id, work_id any;
  declare det, uri, ruri varchar;

  id := DB.DBA.DAV_SEARCH_ID (path, 'C');
  if (isnull (DB.DBA.DAV_HIDE_ERROR (id)))
    return;

  if (isarray (id) and not DB.DBA.DAV_DET_IS_WEBDAV_BASED (DB.DBA.DAV_DET_NAME (id)))
    return;

  work_id := DB.DBA.DAV_DET_DAV_ID (id);
  if (not enabled)
    enabled := DB.DBA.LDP_ENABLED (work_id);

  for (select COL_NAME as _COL_NAME from WS.WS.SYS_DAV_COL where COL_ID = work_id) do
  {
    uri := WS.WS.DAV_IRI (path);
    if (enabled)
    {
      TTLP ('@prefix ldp: <http://www.w3.org/ns/ldp#> .  <> a ldp:BasicContainer, ldp:Container .', uri, uri);
    }
    else
    {
      DB.DBA.LDP_DELETE (path, 1);
    }
    for (select RES_CONTENT, RES_TYPE, RES_FULL_PATH from WS.WS.SYS_DAV_RES where RES_COL = work_id) do
    {
      if (enabled)
      {
        DB.DBA.LDP_CREATE_RES (RES_FULL_PATH);
        if (RES_TYPE in ('text/turtle', 'application/ld+json'))
        {
          ruri := WS.WS.DAV_IRI (RES_FULL_PATH);
          {
            declare continue handler for sqlstate '*';
            TTLP (cast (RES_CONTENT as varchar), ruri, ruri, 255);
          }
        }
      }
      else
      {
        DB.DBA.LDP_DELETE (RES_FULL_PATH);
      }
    }
    for (select COL_NAME from WS.WS.SYS_DAV_COL where COL_PARENT = work_id and (COL_DET is null or DB.DBA.DAV_DET_IS_WEBDAV_BASED (COL_DET))) do
    {
      ruri := WS.WS.DAV_IRI (path || COL_NAME || '/');
      TTLP (sprintf ('<%s> <http://www.w3.org/ns/ldp#contains> <%s> .', uri, ruri), uri, uri);
    }
  }

  for (select COL_NAME from WS.WS.SYS_DAV_COL where COL_PARENT = work_id and (COL_DET is null or DB.DBA.DAV_DET_IS_WEBDAV_BASED (COL_DET))) do
  {
    commit work;
    WEBDAV.DBA.ldp_recovery_aq (path || COL_NAME || '/', enabled);
  }
}
;

-----------------------------------------------------------------------------------------
--
-- Certificates
--
-----------------------------------------------------------------------------------------
create procedure WEBDAV.DBA.user_keys (
  in username varchar)
{
  declare xenc_name, xenc_type varchar;
  declare arr any;

  result_names (xenc_name, xenc_type);
  if (not exists (select 1 from SYS_USERS where U_NAME = username))
    return;

  arr := USER_GET_OPTION (username, 'KEYS');
  for (declare i, l int, i := 0, l := length (arr); i < l; i := i + 2)
  {
    if (length (arr[i]))
      result (arr[i], arr[i+1][0]);
  }
}
;

-----------------------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.keys_exist (
  in _user varchar)
{
  if (exists (select 1 from WEBDAV.DBA.user_keys (username) (xenc_key varchar) x where username = _user))
    return 1;

  return 0;
}
;

-----------------------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.keys_list (
  in _user varchar)
{
  declare retValue any;

  retValue := vector ();
  for (select x.xenc_key, x.xenc_type
         from WEBDAV.DBA.user_keys (username) (xenc_key varchar, xenc_type varchar) x
        where username = _user) do
  {
    retValue := vector_concat (retvalue, vector (xenc_key));
  }

  return retValue;
}
;

-----------------------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.oauth_exist ()
{
  declare retValue any;

  retValue := WEBDAV.DBA.exec ('select 1 from VAL.DBA.ODS_OAUTH_INSTANCES, OAUTH.DBA.APP_REG where A_NAME = OOI_NAME');
  if (WEBDAV.DBA.isVector (retValue) and (length (retValue) = 1))
    return 1;

  return 0;
}
;

-----------------------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.oauth_list ()
{
  declare retValue, items any;

  retValue := vector ();
  items := WEBDAV.DBA.exec ('select OOI_NAME, OOI_LABEL from VAL.DBA.ODS_OAUTH_INSTANCES, OAUTH.DBA.APP_REG where A_NAME = OOI_NAME');
  foreach (any item in items) do
  {
    retValue := vector_concat (retvalue, vector (vector (item[0], item[1])));
  }

  return retValue;
}
;

-----------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.dav_rdf_schema_properties_short (
  in schemaURI varchar) returns any
{
  declare exit handler for SQLSTATE '*' {return vector();};

  return (select deserialize (blob_to_string (RS_PROP_CATNAMES)) from WS.WS.SYS_RDF_SCHEMAS where RS_URI = schemaURI);
}
;

-----------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.dav_rdf_schema_properties_short_rs (
  in schemaURI varchar) returns any
{
  declare N integer;
  declare c0, c1 varchar;
  declare properties any;

  result_names(c0, c1);

  properties := WEBDAV.DBA.dav_rdf_schema_properties_short (schemaURI);
  for(N := 0; N < length (properties); N := N + 6)
    result(properties[N], properties[N+1]);
  return;
}
;

-----------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.xsl_upload_single (
  in isDAV integer,
  in fileName varchar)
{
  declare content, type varchar;

  if (isDAV)
  {
    registry_set ('__WebDAV_vspx__', 'yes');
    DAV_RES_CONTENT_INT (DAV_SEARCH_ID ('/DAV/VAD/conductor/dav/' || fileName, 'R'), content, type, 0, 0);
  }
  else
  {
    registry_set ('__WebDAV_vspx__', 'no');
    content := xml_uri_get('file://vad/vsp/conductor/dav/', fileName);
  }
  DB.DBA.DAV_RES_UPLOAD_STRSES_INT ('/DAV/.' || fileName, content, 'text/xsl', '110110100R', http_dav_uid (), http_dav_uid () + 1, null, null, 0);
}
;

-----------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.xsl_upload (
  in isDAV integer)
{
  WEBDAV.DBA.xsl_upload_single (isDAV, 'folder.xsl');
  WEBDAV.DBA.xsl_upload_single (isDAV, 'xml2rss.xsl');
  WEBDAV.DBA.xsl_upload_single (isDAV, 'rss2atom.xsl');
  WEBDAV.DBA.xsl_upload_single (isDAV, 'rss2rdf.xsl');
}
;

-----------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.progress_error (
  inout retValue varchar,
  inout actionValue varchar)
{
  if (not WEBDAV.DBA.DAV_ERROR (retValue))
    retValue := actionValue;

  -- dbg_obj_princ ('WEBDAV.DBA.WEBDAV.DBA.progress_error (', retValue, actionValue, ')');
}
;

-----------------------------------------------------------------------------
--
create procedure WEBDAV.DBA.progress_start (
  in progressID varchar,
  in command varchar,
  in params any)
{
  -- dbg_obj_princ ('WEBDAV.DBA.progress_start (', progressID, command, params, ')');
  declare account_id integer;
  declare N, M, L integer;
  declare itemPath, targetPath varchar;
  declare retValue, actionValue, item, results, tags any;
  declare target, overwrite, check_locks any;
  declare tagsPublic, tagsPrivate any;
  declare acl_value, aci_value, dav_acl, old_dav_acl any;
  declare prop_owner, prop_group any;
  declare prop_mime, prop_add_perms, prop_rem_perms, prop_perms, one, zero varchar;
  declare c_properties, c_property, c_value, c_action any;

  account_id := (select U_ID from DB.DBA.SYS_USERS where U_NAME = coalesce (WEBDAV.DBA.account (), 'nobody'));
  if      (command = 'delete')
  {
    check_locks := cast (get_keyword ('f_check_locks', params, 0) as integer);;
  }
  else if (command = 'tag')
  {
    tagsPublic := get_keyword ('f_tagsPublic', params);
    tagsPrivate := get_keyword ('f_tagsPrivate', params);
  }
  else if (command = 'properties')
  {
    prop_mime  := trim (get_keyword ('prop_mime', params, get_keyword ('prop_mime2', params, '')));
    prop_owner := WEBDAV.DBA.user_id (trim (get_keyword ('prop_owner', params, get_keyword ('prop_owner2', params, ''))));
    prop_group := WEBDAV.DBA.user_id (trim (get_keyword ('prop_group', params, get_keyword ('prop_group2', params, ''))));

    one := ascii('1');
    zero := ascii('0');
    prop_add_perms := '000000000NN';
    for (N := 0; N < 9; N := N + 1)
    {
      if (get_keyword (sprintf ('prop_add_perm%i', N), params, '0') <> '0')
        aset(prop_add_perms, N, one);
    }
    prop_rem_perms := '000000000NN';
    for (N := 0; N < 9; N := N + 1)
    {
      if (get_keyword (sprintf ('prop_rem_perm%i', N), params, '0') <> '0')
        aset(prop_rem_perms, N, one);
    }

    -- changing or adding properties
    c_properties := WEBDAV.DBA.prop_params (params, account_id);
  }
  else if (command = 'properties')
  {
    -- acl properties
    acl_value := WS.WS.ACL_PARSE (WEBDAV.DBA.acl_params (params));

    -- aci properties
    aci_value := WEBDAV.DBA.aci_n3 (WEBDAV.DBA.aci_params (params));
  }
  else if (command = 'share')
  {
    -- acl properties
    acl_value := WS.WS.ACL_PARSE (WEBDAV.DBA.acl_params (params));

    -- aci properties
    aci_value := WEBDAV.DBA.aci_n3 (WEBDAV.DBA.aci_params (params));
  }
  else if (command in ('copy', 'move'))
  {
    target := get_keyword ('f_folder', params);
    overwrite := cast (get_keyword ('f_overwrite', params, 0) as integer);
  }

  M := 0;
  results := vector ();
  for (N := 0; N < length (params); N := N + 2)
  {
    if (cast (registry_get ('progress_action_' || progressID) as varchar) = 'stop')
      return;

    if (params[N] = 'item')
    {
      results := vector_concat (results, vector ('Progress'));
      registry_set ('progress_data_'  || progressID, DB.DBA.obj2json (results));
      itemPath := params[N+1];
      item := WEBDAV.DBA.DAV_INIT (itemPath);
      if (not WEBDAV.DBA.DAV_ERROR (item))
      {
        actionValue := 0;
        retValue := 0;
        if (command = 'delete')
        {
          retValue := WEBDAV.DBA.DAV_DELETE (itemPath, check_locks=>check_locks);
        }
        else if (command = 'unmount')
        {
          if (get_keyword ('f_unmount', params) = 'D')
          {
            -- delete all
            retValue := WEBDAV.DBA.DAV_DELETE (itemPath);
          }
          else if (get_keyword ('f_unmount', params) = 'U')
          {
            -- unmount only
            declare _detType, _path varchar;
            declare _properties any;

            _detType := WEBDAV.DBA.DAV_GET (item, 'detType');
            WEBDAV.DBA.DAV_SET (itemPath, 'detType', null);
            for (select COL_ID from WS.WS.SYS_DAV_COL where DB.DBA.DAV_SEARCH_PATH (COL_ID, 'C') like (itemPath || '%')) do
            {
              _path := DB.DBA.DAV_SEARCH_PATH (COL_ID, 'C');
              _properties := WEBDAV.DBA.DAV_PROP_LIST (_path, sprintf ('virt:%s%%', _detType), vector ());
              for (L := 0; L < length (_properties); L := L + 1)
              {
                WEBDAV.DBA.DAV_PROP_REMOVE (_path, _properties[L][0]);
              }
            }
            for (select RES_FULL_PATH from WS.WS.SYS_DAV_RES where RES_FULL_PATH like (itemPath || '%')) do
            {
              _path := RES_FULL_PATH;
              _properties := WEBDAV.DBA.DAV_PROP_LIST (_path, sprintf ('virt:%s%%', _detType), vector ());
              for (L := 0; L < length (_properties); L := L + 1)
              {
                WEBDAV.DBA.DAV_PROP_REMOVE (_path, _properties[L][0]);
              }
            }
          }
        }
        else if (command = 'tag')
        {
          if (tagsPublic <> '')
          {
            tags := WEBDAV.DBA.DAV_PROP_GET (itemPath, ':virtpublictags', '');
            actionValue := WEBDAV.DBA.DAV_PROP_SET (itemPath, ':virtpublictags', WEBDAV.DBA.tags_join (tags, tagsPublic));
            WEBDAV.DBA.progress_error (retValue, actionValue);
          }
          if (tagsPrivate <> '')
          {
            tags := WEBDAV.DBA.DAV_PROP_GET (itemPath, ':virtprivatetags', '');
            actionValue := WEBDAV.DBA.DAV_PROP_SET (itemPath, ':virtprivatetags', WEBDAV.DBA.tags_join (tags, tagsPrivate));
            WEBDAV.DBA.progress_error (retValue, actionValue);
          }
        }
        else if (command = 'properties')
        {
          if (('' <> prop_mime) and ('Do not change' <> prop_mime) and (WEBDAV.DBA.DAV_GET (item, 'type') = 'R') and (WEBDAV.DBA.DAV_GET (item, 'mimeType') <> prop_mime))
          {
            actionValue := WEBDAV.DBA.DAV_SET (itemPath, 'mimeType', prop_mime);
            WEBDAV.DBA.progress_error (retValue, actionValue);
          }
          if ((prop_owner <> -1) and (isnull (WEBDAV.DBA.DAV_GET (item, 'ownerID')) or (WEBDAV.DBA.DAV_GET (item, 'ownerID') <> prop_owner)))
          {
            actionValue := WEBDAV.DBA.DAV_SET (itemPath, 'ownerID', prop_owner);
            WEBDAV.DBA.progress_error (retValue, actionValue);
          }
          if ((prop_group <> -1) and (isnull (WEBDAV.DBA.DAV_GET (item, 'groupID')) or (WEBDAV.DBA.DAV_GET (item, 'groupID') <> prop_group)))
          {
            actionValue := WEBDAV.DBA.DAV_SET (itemPath, 'groupID', prop_group);
            WEBDAV.DBA.progress_error (retValue, actionValue);
          }
          -- permissions
          prop_perms := WEBDAV.DBA.DAV_GET (item, 'permissions');
          for (L := 0; L < 10; L := L + 1)
          {
            if (prop_add_perms[L] = one)
              aset(prop_perms, L, one);
            if (prop_rem_perms[L] = one)
              aset (prop_perms, L, zero);
          }
          if (get_keyword ('prop_index', params, '*') <> '*')
          {
            aset (prop_perms, 9, ascii (get_keyword ('prop_index', params)));
          }
          if (get_keyword ('prop_metagrab', params, '*') <> '*')
          {
            if (length (prop_perms) < 11)
              prop_perms := concat (prop_perms, ' ');

            aset (prop_perms, 10, ascii (get_keyword ('prop_metagrab', params)));
          }
          actionValue := WEBDAV.DBA.DAV_SET (itemPath, 'permissions', prop_perms);
          WEBDAV.DBA.progress_error (retValue, actionValue);

          -- recursive
          if ((WEBDAV.DBA.DAV_GET (item, 'type') = 'C') and ('' <> get_keyword ('prop_recursive', params, '')))
          {
            WEBDAV.DBA.DAV_SET_RECURSIVE (itemPath, prop_perms, prop_owner, prop_group);
          }

          -- properties
          for (L := 0; L < length (c_properties); L := L + 1)
          {
            if (c_properties[L][0] <> '')
            {
              if (c_properties[L][2] = 'U')
              {
                actionValue := WEBDAV.DBA.DAV_PROP_SET (itemPath, c_properties[L][0], c_properties[L][1]);
                WEBDAV.DBA.progress_error (retValue, actionValue);
              }
              else if (c_properties[L][2] = 'R')
              {
                actionValue := WEBDAV.DBA.DAV_PROP_REMOVE (itemPath, c_properties[L][0]);
                WEBDAV.DBA.progress_error (retValue, actionValue);
              }
            }
          }
        }
        else if (command = 'share')
        {
          -- acl
          if (length (acl_value))
          {
            dav_acl := WEBDAV.DBA.DAV_GET (item, 'acl');
            old_dav_acl := dav_acl;
            foreach (any acl in acl_value) do
            {
              if ((WEBDAV.DBA.DAV_GET (item, 'type') = 'C') or (acl[2] = 0))
              {
                actionValue := WS.WS.ACL_ADD_ENTRY (dav_acl, acl[0], acl[3], acl[1], acl[2]);
                WEBDAV.DBA.progress_error (retValue, actionValue);
              }
            }
            if ((old_dav_acl <> dav_acl) and (not WEBDAV.DBA.DAV_ERROR (WEBDAV.DBA.DAV_SET (itemPath, 'acl', dav_acl))))
            {
              WEBDAV.DBA.acl_send_mail (account_id, itemPath, old_dav_acl, dav_acl);
            }
          }

          -- aci - WebAccess
          if (length (aci_value))
          {
            actionValue := WEBDAV.DBA.DAV_PROP_SET (itemPath, 'virt:aci_meta_n3', aci_value);
            WEBDAV.DBA.progress_error (retValue, actionValue);
          }
        }
        else
        {
          targetPath := WEBDAV.DBA.real_path (target) || WEBDAV.DBA.DAV_GET (item, 'name');
          if (WEBDAV.DBA.DAV_GET (item, 'type') = 'C')
            targetPath := targetPath || '/';

          if (command = 'copy')
          {
            retValue := WEBDAV.DBA.DAV_COPY (itemPath, targetPath, overwrite, WEBDAV.DBA.DAV_GET (item, 'permissions'));
          }
          else if (command = 'move')
          {
            retValue := WEBDAV.DBA.DAV_MOVE (itemPath, targetPath, overwrite);
          }
        }
      }
      else
      {
        retValue := item;
      }
      results[length(results)-1] := case when WEBDAV.DBA.DAV_ERROR (retValue) then VALIDATE.DBA.clear (WEBDAV.DBA.DAV_PERROR (retValue)) else 'OK' end;

      -- set registry data
      M := M + 1;
      registry_set ('progress_index_'  || progressID, cast (M as varchar));
      registry_set ('progress_data_'  || progressID, DB.DBA.obj2json (results));
      commit work;
    }
  }
  return results;
}
;
