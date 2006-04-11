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
create user "RQ"
;

DB.DBA.USER_SET_QUALIFIER ('RQ', 'RQ')
;

grant all privileges to RQ
;

DB.DBA.VHOST_REMOVE (lpath=>'/sparql_demo/')
;
DB.DBA.VHOST_REMOVE (lpath=>'/sparql_demo')
;
DB.DBA.VHOST_DEFINE (lpath=>'/sparql_demo/', ppath=>'/DAV/sparql_demo/', vsp_user=>'RQ', is_dav=>1, def_page => 'demo.vsp')
--DB.DBA.VHOST_DEFINE (lpath=>'/sparql_demo/', ppath=>'/sparql_demo/', vsp_user=>'RQ')
;

create procedure "RQ"."RQ"."LIST_MENU_ITEMS"() returns any
{
  declare manifests any;
  declare ctr integer;
  manifests := SPARQL_DAWG_MANIFEST_RDF_LIST();
  manifests := subseq (manifests, 0, length (manifests) - 1);
  for (ctr := length (manifests) - (1+6); ctr >= 0; ctr := ctr - 1)
    {
      declare m any;
      m := SPARQL_DAV_DATA_URI() || manifests[ctr];
      m := subseq (m, 0, strrchr (m, '/'));
      m := subseq (m, strrchr (m, '/')+1);
      manifests[ctr] := vector (10, m, manifests[ctr]);
    }
  return vector_concat (
    vector (
      vector (2, 'Home', 'demo.vsp'),
--      vector (2, 'FAQ', 'demo.vsp?desk=faq'),
      vector (2, 'Feedback', 'mailto:sparql@openlinksw.com'),
      vector (0, 'Specification'),
      vector (5, 'SPARQL Language', 'http://www.w3.org/TR/rdf-sparql-query/#modProjection'),
      vector (5, 'SPARQL Test Cases', 'http://www.w3.org/2001/sw/DataAccess/tests/'),
      vector (1),
      vector (0, 'Test Cases') ),
    manifests,
    vector (
      vector (1),
      vector (0, 'About...'),
      vector (5, 'Openlink Software', 'http://www.openlinksw.com'),
      vector (5, 'Virtuoso Server', 'http://www.openlinksw.com/virtuoso'),
      vector (1) ) );
}
;

create function "RQ"."RQ"."URI_GET" (in uri varchar) returns varchar
{
  return DB.DBA.XML_URI_GET ('', uri);
}
;

create procedure "RQ"."RQ"."PRINT_EXPECTED_RESULT" (in _graph_uri varchar)
{
  declare _vars, _distlines, _lines, _valdict any;
  -- dbg_obj_princ ('"RQ"."RQ"."PRINT_EXPECTED_RESULT" (', _graph_uri, ')');
  _vars := DB.DBA.SPARQL_EVAL_TO_ARRAY ('
PREFIX rs: <http://www.w3.org/2001/sw/DataAccess/tests/result-set#>
PREFIX tm: <http://www.w3.org/2001/sw/DataAccess/tests/test-manifest#>
PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
SELECT ?name
WHERE {
  [ rs:resultVariable ?name ]
  }', _graph_uri, 10000); 
  _distlines := DB.DBA.SPARQL_EVAL_TO_ARRAY ('
PREFIX rs: <http://www.w3.org/2001/sw/DataAccess/tests/result-set#>
SELECT ?sln
WHERE
{
  [ rs:solution ?sln ]
  }', _graph_uri, 10000); 
  _lines := DB.DBA.SPARQL_EVAL_TO_ARRAY ('
PREFIX rs: <http://www.w3.org/2001/sw/DataAccess/tests/result-set#>
SELECT ?sln ?name ?val
WHERE
{
  [ rs:solution ?sln ] .
  ?sln
       rs:binding
        [ rs:variable ?name ;
          rs:value ?val ]
  }', _graph_uri, 10000);
  _valdict := dict_new();
  foreach (any _cell in _lines) do
    {
      dict_put (_valdict, _cell[0] || '-' || _cell[1], _cell[2]);
    }
  http ('<TABLE BORDER=1><TR>');
  foreach (any _var in _vars) do
    {
      http ('<TH>'); http_value (_var[0]); http ('</TH>');
    }
  http ('</TR>');
  foreach (varchar _dl in _distlines) do
    {
      http ('<TR>');
      foreach (any _var in _vars) do
        {
          http ('<TD><PRE>'); http_value (dict_get (_valdict, _dl[0] || '-' || _var[0], '')); http ('</PRE></TD>');
        }
      http ('</TR>'); 
    }
  http ('</TABLE>');
}
;

create procedure "RQ"."RQ"."DESK_RUN" (in _service_uri varchar, in _text varchar, in _default_graph_uri varchar, in _compiletime integer, in _expected_text varchar, in _brief integer)
{
  declare _sqltext, _state, _msg varchar;
  declare _metas, _rset any;
  declare _ctr, _len integer;
  declare _res, _res_ses any;
  declare _sub_text, _actual_text varchar;
  if (_service_uri is null)
    {
      declare _ms1, _ms2 integer;
      _ms1 := msec_time();
      _sqltext := string_output_string (sparql_to_sql_text (_text));
      _state := '00000';
      _metas := null;
      _rset := null;
      connection_set (':default_graph', _default_graph_uri);
      exec (_sqltext, _state, _msg, vector(), 100, _metas, _rset);
      if (_state <> '00000')
        signal (_state, _msg);
      _ms2 := msec_time();
      http ('<B>Local query completed successfully.</B> ('); http_value ((_ms2 - _ms1) - _compiletime); http (' msec.)');
    }
  else
    {
      declare row_ctr, row_count, col_ctr, col_count integer;
      DB.DBA.SPARQL_REXEC_WITH_META (_service_uri, _text, _default_graph_uri, vector(), '', 100, null, _metas, _rset);
      -- dbg_obj_princ ('_rset(before conversion)=', _rset);
      row_count := length (_rset);
      if (row_count > 0)
        {
	  col_count := length (_rset[0]);
	  for (row_ctr := row_count - 1; row_ctr >= 0 ; row_ctr := row_ctr - 1)
	    {
              for (col_ctr := col_count - 1; col_ctr >= 0 ; col_ctr := col_ctr - 1)
	        {
		  declare val any;
		  val := _rset[row_ctr][col_ctr];
                  -- dbg_obj_princ ('val=', val);
		  _rset[row_ctr][col_ctr] := DB.DBA.RDF_SQLVAL_OF_LONG (val);
		}
	    }
	}
    }
  -- dbg_obj_princ ('_metas=', _metas, '_rset=', _rset);
  http ('<TABLE BORDER="1"><TR>');
  foreach (any _var in _metas[0]) do
    {
      http ('<TH>'); http_value (_var[0]); http ('</TH>');
    }
  http ('</TR>');
  foreach (any _row in _rset) do
    {
      http ('<TR>');
      foreach (any _var in _row) do
        {
          http ('<TD><PRE>');
	  if (214 = __tag (_var))
	    {
	      declare triples, ses any;
	      triples := dict_list_keys (_var, 1);
	      ses := string_output ();
--	      DB.DBA.RDF_TRIPLES_TO_RDF_XML_TEXT (triples, 1, ses);
	      DB.DBA.RDF_TRIPLES_TO_TTL (triples, ses);
	      http_value (string_output_string (ses));
	    }
	  else
	    {
	      http_value (_var);
              -- http (', tag ');
	      -- http_value (__tag (_var));
	    }
	  http ('</PRE></TD>');
        }
      http ('</TR>');
    }
  http ('</TABLE>');
return;
  
  _actual_text := '';
  _res_ses := string_output();
  if (isarray(_res) and not isstring(_res))
    {
      _len := length(_res);
      http(', ');
      http_value(_len);
      http(' result(s) fetched)');
      _ctr := 0;
      while (_ctr < _len)
	{
	  _sub_text := "XQ"."XQ"."INDENT_XML"(aref (_res, _ctr));
	  _actual_text := concat (_actual_text, _sub_text);
          http ('<BR><B>Result ', _res_ses); http_value(_ctr+1, 0, _res_ses);
	  http (' of ', _res_ses); http_value(_len, 0, _res_ses);
	  http (':</B>', _res_ses);
	  http (_sub_text, _res_ses);
	  _ctr := _ctr + 1;
	}
    }
  else
    {
      _sub_text := "XQ"."XQ"."INDENT_XML"(aref (_res, _ctr));
      _actual_text := concat (_actual_text, _sub_text);
      http (')', _res_ses);
      http (_sub_text, _res_ses);
    }
  _expected_text := replace (_expected_text, ' ', '');
  _expected_text := replace (_expected_text, '\n', '');
  _expected_text := replace (_expected_text, '\t', '');
  _actual_text := replace (_actual_text, ' ', '');
  _actual_text := replace (_actual_text, '\n', '');
  _actual_text := replace (_actual_text, '\t', '');
  if (_expected_text <> '')
    {
      if (_expected_text <> _actual_text)
	http ('<BR><B>The actual result differs from expected.</B>');
      else
	http ('<BR><B>The actual result is identical to expected.</B>');
    }
  if (_brief = 0 or not (_expected_text = '' or _expected_text = _actual_text))
    http (string_output_string(_res_ses));
};

-- These are stubs while there are no appropriate BIFs.
create function RQ.RQ.__and (in e1 any, in e2 any) returns integer
{
  if (e1 and e2)
    return 1;
  return 0;
}
;

create function RQ.RQ.__or (in e1 any, in e2 any) returns integer
{
  if (e1 or e2)
    return 1;
  return 0;
}
;

create function RQ.RQ.__not (in e1 any) returns integer
{
  if (e1)
    return 0;
  return 1;
}
;


checkpoint;
