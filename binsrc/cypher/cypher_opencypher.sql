--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2026 OpenLink Software
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
--  OpenCypher for Virtuoso - OPENCYPHER Keyword Execution Handler
--
--  This module provides the OPENCYPHER execution handler that integrates
--  with the Virtuoso SQL parser to enable:
--    OPENCYPHER <cypher_query>
--    OPENCYPHER DEFINE <key> <value> PREFIX <p>: <uri> <cypher_query>
--
--  Returns: tabular result sets compatible with isql/odbc/jdbc
--

-- OPENCYPHER execution handler - called by SQL parser when OPENCYPHER keyword is used
-- Parses DEFINE and PREFIX declarations, then executes the Cypher query
--
-- Syntax:
--   OPENCYPHER MATCH (n:Person) RETURN n.name
--   OPENCYPHER DEFINE timeout 30 PREFIX foaf: <http://xmlns.com/foaf/0.1/> MATCH (n:foaf:Person) RETURN n
--
create procedure DB.DBA.OPENCYPHER_EXEC (in _opencypher_text varchar, in _default_graph varchar := null)
{
  declare defines, prefixes any;
  declare query_text, remaining, value, uri, word varchar;
  declare pos, n, original_pos integer;
  declare result any;
  declare cypher_keywords any;
  declare key_start, key_end, value_start, string_char integer;
  declare prefix_start, prefix_end, uri_start integer;
  declare word_end, is_cypher_keyword, i integer;

  if (_default_graph is null)
    _default_graph := DB.DBA.OPENCYPHER_DEFAULT_GRAPH ();

  defines := vector ();
  prefixes := vector ();
  query_text := null;

  cypher_keywords := vector ('MATCH', 'OPTIONAL', 'CREATE', 'MERGE', 'DELETE',
                             'REMOVE', 'SET', 'RETURN', 'WITH', 'UNWIND', 'CALL',
                             'LOAD', 'FOREACH', 'START');

  pos := 0;
  n := length (_opencypher_text);

  while (pos < n)
    {
      while (pos < n and aref (_opencypher_text, pos) <= 32)
        pos := pos + 1;

      if (pos >= n)
        goto done_parsing;

      original_pos := pos;
      remaining := subseq (_opencypher_text, pos);

      if (length (remaining) >= 6 and upper (subseq (remaining, 0, 6)) = 'DEFINE')
        {
          pos := pos + 6;
          while (pos < n and aref (_opencypher_text, pos) <= 32)
            pos := pos + 1;
          key_start := pos;
          while (pos < n and aref (_opencypher_text, pos) > 32)
            pos := pos + 1;
          key_end := pos;
          while (pos < n and aref (_opencypher_text, pos) <= 32)
            pos := pos + 1;
          if (pos < n and (aref (_opencypher_text, pos) = 39 or aref (_opencypher_text, pos) = 34))
            {
              string_char := aref (_opencypher_text, pos);
              pos := pos + 1;
              value_start := pos;
              while (pos < n and aref (_opencypher_text, pos) <> string_char)
                pos := pos + 1;
              value := subseq (_opencypher_text, value_start, pos);
              if (pos < n)
                pos := pos + 1;
            }
          else
            {
              value_start := pos;
              while (pos < n and aref (_opencypher_text, pos) > 32)
                pos := pos + 1;
              value := subseq (_opencypher_text, value_start, pos);
            }
          defines := vector_concat (defines, vector (vector (subseq (_opencypher_text, key_start, key_end), value)));
          goto next_clause;
        }

      if (length (remaining) >= 6 and upper (subseq (remaining, 0, 6)) = 'PREFIX')
        {
          pos := pos + 6;
          while (pos < n and aref (_opencypher_text, pos) <= 32)
            pos := pos + 1;
          prefix_start := pos;
          while (pos < n and aref (_opencypher_text, pos) <> 58)
            pos := pos + 1;
          prefix_end := pos;
          if (pos < n)
            pos := pos + 1;
          while (pos < n and aref (_opencypher_text, pos) <= 32)
            pos := pos + 1;
          if (pos < n and aref (_opencypher_text, pos) = 60)
            {
              pos := pos + 1;
              uri_start := pos;
              while (pos < n and aref (_opencypher_text, pos) <> 62)
                pos := pos + 1;
              uri := subseq (_opencypher_text, uri_start, pos);
              if (pos < n)
                pos := pos + 1;
            }
          else if (pos < n and (aref (_opencypher_text, pos) = 39 or aref (_opencypher_text, pos) = 34))
            {
              string_char := aref (_opencypher_text, pos);
              pos := pos + 1;
              uri_start := pos;
              while (pos < n and aref (_opencypher_text, pos) <> string_char)
                pos := pos + 1;
              uri := subseq (_opencypher_text, uri_start, pos);
              if (pos < n)
                pos := pos + 1;
            }
          else
            {
              uri_start := pos;
              while (pos < n and aref (_opencypher_text, pos) > 32)
                pos := pos + 1;
              uri := subseq (_opencypher_text, uri_start, pos);
            }
          prefixes := vector_concat (prefixes, vector (vector (subseq (_opencypher_text, prefix_start, prefix_end), uri)));
          goto next_clause;
        }

      word_end := pos;
      -- Stop on whitespace OR the openCypher pattern openers '(' '{' '['
      -- so MERGE(...), MATCH(n), CREATE(n) tokenize the same as the spaced form.
      while (word_end < n and aref (_opencypher_text, word_end) > 32
             and aref (_opencypher_text, word_end) <> 40
             and aref (_opencypher_text, word_end) <> 123
             and aref (_opencypher_text, word_end) <> 91)
        word_end := word_end + 1;
      word := upper (subseq (_opencypher_text, pos, word_end));

      is_cypher_keyword := 0;
      for (i := 0; i < length (cypher_keywords); i := i + 1)
        {
          if (word = aref (cypher_keywords, i))
            {
              is_cypher_keyword := 1;
              goto found_keyword;
            }
        }
found_keyword:

      if (is_cypher_keyword)
        {
          query_text := trim (subseq (_opencypher_text, pos));
          goto done_parsing;
        }

      pos := word_end;

next_clause: ;
    }

done_parsing:

  if (query_text is null or length (trim (query_text)) = 0)
    signal ('37000', 'OPENCYPHER statement must contain a Cypher query (e.g., MATCH, CREATE, RETURN)');

  {
    declare tokens, ast any;
    declare sparql_str varchar;
    declare clauses any;
    declare has_return integer;
    declare state, msg varchar;
    declare meta, data any;
    declare j, nrows integer;
    declare prefix_preamble varchar;

    prefix_preamble := '';
    for (j := 0; j < length (prefixes); j := j + 1)
      prefix_preamble := concat (prefix_preamble, 'PREFIX ', aref (aref (prefixes, j), 0), ': <',
                                 aref (aref (prefixes, j), 1), '> ');
    if (length (prefix_preamble) > 0)
      query_text := concat (prefix_preamble, query_text);

    tokens := DB.DBA.CYP_TOKENIZE (query_text);
    ast := DB.DBA.CYP_PARSE (tokens);

    -- Check if query has RETURN clause (i.e., expects result set)
    has_return := 0;
    clauses := aref (ast, 1);
    for (j := 0; j < length (clauses); j := j + 1)
      {
        if (aref (aref (clauses, j), 0) = 'RETURN')
          has_return := 1;
      }

    -- DML queries (CREATE, DELETE, SET, MERGE without RETURN): execute silently
    if (has_return = 0)
      {
        DB.DBA.CYPHER (query_text, _default_graph);
        return;
      }

    -- SELECT queries (has RETURN): translate to SPARQL and emit result set
    sparql_str := DB.DBA.CYP_TO_SPARQL (ast, _default_graph);

    state := '00000';
    msg := '';
    exec (sparql_str, state, msg, vector (), 0, meta, data);
    if (state <> '00000')
      signal (state, msg);

    if (meta is not null and length (meta) > 0)
      {
        exec_result_names (meta[0]);
        if (data is not null)
          {
            nrows := length (data);
            for (j := 0; j < nrows; j := j + 1)
              exec_result (aref (data, j));
          }
      }
  }
}
;

-- OPENCYPHER_SELECT - returns result set directly
create procedure DB.DBA.OPENCYPHER_SELECT (in _query varchar, in _default_graph varchar := null)
{
  declare result any;
  result := DB.DBA.CYPHER (_query, _default_graph);
  if (result is null)
    return vector ();
  return result;
}
;

-- OPENCYPHER_INLINE - returns scalar value from first column of first row
create procedure DB.DBA.OPENCYPHER_INLINE (in _query varchar, in _default_graph varchar := null)
{
  declare result any;
  declare first_row any;
  result := DB.DBA.CYPHER (_query, _default_graph);
  if (result is null or length (result) = 0)
    return null;
  first_row := aref (result, 0);
  if (first_row is null or length (first_row) = 0)
    return null;
  return aref (first_row, 0);
}
;
