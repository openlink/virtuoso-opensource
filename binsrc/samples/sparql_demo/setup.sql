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
--

create user "RQ"
;

DB.DBA.USER_SET_QUALIFIER ('RQ', 'RQ')
;

grant all privileges to RQ
;

DB.DBA.VHOST_REMOVE (lpath=>'/sparql_demo/')
;
DB.DBA.VHOST_DEFINE (lpath=>'/sparql_demo/', ppath=>'/DAV/VAD/iSPARQL/', vsp_user=>'RQ', is_dav=>1, def_page => 'sparql_ajax.vsp')
;

DB.DBA.VHOST_REMOVE (lpath=>'/isparql/')
;
DB.DBA.VHOST_DEFINE (lpath=>'/isparql/', ppath=>'/DAV/VAD/iSPARQL/', vsp_user=>'RQ', is_dav=>1, def_page => 'sparql_ajax.vsp')
;

select case (isstring (registry_get ('WS.WS.SPARQL_DEFAULT_REDIRECT')))
when equ(registry_get ('WS.WS.SPARQL_DEFAULT_REDIRECT'),'/sparql_demo/demo.vsp?case=custom_sparql')
  then registry_remove ('WS.WS.SPARQL_DEFAULT_REDIRECT')
when equ(registry_get ('WS.WS.SPARQL_DEFAULT_REDIRECT'),'/sparql_demo/sparql_ajax.vsp?goto=query_page')
  then registry_remove ('WS.WS.SPARQL_DEFAULT_REDIRECT')
else 1 end
;

create procedure "RQ"."RQ"."sparql_exec_no_error"(in expr varchar)
{
  declare state, message, meta, result any;
  exec(expr, state, message, vector(), 0, meta, result);
}
;

"RQ"."RQ"."sparql_exec_no_error"('
create table "RQ"."RQ"."SPARQL_USER_UPLOADS"(
  SU_ID integer IDENTITY,
  SU_DAV_FULL_PATH varchar not null,
  SU_GRAPH varchar not null,
  SU_UPLOAD_TIME datetime not null,
  SU_UPLOAD_IP   varchar(15) not null,
  SU_DELETED integer not null default 0,

  primary key(SU_ID)
)
')
;

"RQ"."RQ"."sparql_exec_no_error"('
create index SPARQL_USER_UPLOADS_SK01 on "RQ"."RQ"."SPARQL_USER_UPLOADS"(SU_DAV_FULL_PATH,SU_GRAPH,SU_DELETED);
')
;
"RQ"."RQ"."sparql_exec_no_error"('
create index SPARQL_USER_UPLOADS_SK02 on "RQ"."RQ"."SPARQL_USER_UPLOADS"(SU_UPLOAD_IP,SU_UPLOAD_TIME);
')
;
"RQ"."RQ"."sparql_exec_no_error"('
create index SPARQL_USER_UPLOADS_SK03 on "RQ"."RQ"."SPARQL_USER_UPLOADS"(SU_GRAPH,SU_DELETED);
')
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
