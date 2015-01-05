--
--  $Id$
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2015 OpenLink Software
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
DB.DBA.VHOST_DEFINE (lpath=>'/sparql_demo/', ppath=>'/DAV/VAD/sparql_demo/', vsp_user=>'RQ', is_dav=>1, def_page => 'sparql_ajax.vsp')
;

-- The isparql endpoing is handeled by the new iSPARQL package
--DB.DBA.VHOST_REMOVE (lpath=>'/isparql/')
--;
--DB.DBA.VHOST_DEFINE (lpath=>'/isparql/', ppath=>'/DAV/VAD/iSPARQL/', vsp_user=>'RQ', is_dav=>1, def_page => 'sparql_ajax.vsp')
--;

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

select case (isstring (registry_get ('URIQADefaultHost'))) when 0 then
  signal ('URIQA', 'Default host name is not set in [URIQA] section of virtuoso configuration file')
  else 'OK' end
;

grant select on SYS_USERS to "SPARQL"; 
grant select on SYS_ROLE_GRANTS to "SPARQL"; 

TTLP ('
@prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .
@prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
@prefix owl: <http://www.w3.org/2002/07/owl#> .
@prefix xsd: <http://www.w3.org/2001/XMLSchema#> .
@prefix virtrdf: <http://www.openlinksw.com/schemas/virtrdf#> .
@prefix rdfdf: <http://www.openlinksw.com/virtrdf-data-formats#> .

virtrdf:DefaultQuadStorage
  rdf:type virtrdf:QuadStorage ;
  virtrdf:qsUserMaps virtrdf:DefaultQuadStorage-UserMaps ;
  virtrdf:qsDefaultMap virtrdf:DefaultQuadMap .
virtrdf:DefaultQuadStorage-UserMaps
      rdf:type virtrdf:array-of-QuadMap .
  ', '', 'http://www.openlinksw.com/schemas/virtrdf#' )
;

create procedure DB.DBA.SPARQL_QM_RUN (in txt varchar)
{
  declare REPORT, STUB, stat, msg, sqltext varchar;
  declare metas, rowset any;
  result_names (REPORT/*, STUB*/);
  sqltext := string_output_string (sparql_to_sql_text (txt));
--  dump_large_text_impl (sqltext);
  stat := '00000';
  msg := '';
  rowset := null;
  exec (sqltext, stat, msg, vector (), 1000, metas, rowset);
  result ('STATE=' || stat || ': ' || msg/*, ''*/);
  if (rowset is not null)
    {
      foreach (any r in rowset) do
        result (r[0] || ': ' || r[1]/*, ''*/);
    }
}
;

create function DB.DBA.RDF_DF_GRANTEE_ID_URI (in id integer)
{
  declare isrole integer;
  isrole := coalesce ((select top 1 U_IS_ROLE from DB.DBA.SYS_USERS where U_ID = id));
  if (isrole is null)
    return NULL;
  else if (isrole)
    return sprintf ('http://%s/sys/group?id=%d', registry_get ('URIQADefaultHost'), id);
  else
    return sprintf ('http://%s/sys/user?id=%d', registry_get ('URIQADefaultHost'), id);
}
;

grant execute on DB.DBA.RDF_DF_GRANTEE_ID_URI to SPARQL_SELECT
;

create function DB.DBA.RDF_DF_GRANTEE_ID_URI_INVERSE (in id_iri varchar)
{
  declare parts any;
  parts := sprintf_inverse (id_iri, sprintf ('http://%s/sys/user?id=%%d', registry_get ('URIQADefaultHost')), 1);
  if (parts is not null)
    {
      if (exists (select top 1 1 from DB.DBA.SYS_USERS where U_ID = parts[0] and not U_IS_ROLE))
        return parts[0];
    }
  parts := sprintf_inverse (id_iri, sprintf ('http://%s/sys/group?id=%%d', registry_get ('URIQADefaultHost')), 1);
  if (parts is not null)
    {
      if (exists (select top 1 1 from DB.DBA.SYS_USERS where U_ID = parts[0] and U_IS_ROLE))
        return parts[0];
    }
  return NULL;
}
;

grant execute on DB.DBA.RDF_DF_GRANTEE_ID_URI_INVERSE to SPARQL_SELECT
;

DB.DBA.SPARQL_QM_RUN ('drop silent quad map  virtrdf:SysUsers . ');

DB.DBA.RDF_QM_END_ALTER_QUAD_STORAGE ( UNAME'http://www.openlinksw.com/schemas/virtrdf#DefaultQuadStorage' )
;

DB.DBA.SPARQL_QM_RUN ('
prefix oplsioc: <http://www.openlinksw.com/schemas/oplsioc#>
prefix sioc: <http://rdfs.org/sioc/ns#>
drop quad map graph iri("http://^{URIQADefaultHost}^/sys") .
create iri class oplsioc:user_iri  "http://^{URIQADefaultHost}^/sys/user?id=%d" (in uid integer not null) .
create iri class oplsioc:group_iri "http://^{URIQADefaultHost}^/sys/group?id=%d" (in gid integer not null) .
create iri class oplsioc:membership_iri "http://^{URIQADefaultHost}^/sys/membersip?super=%d&sub=%d" (in super integer not null, in sub integer not null) .
create iri class oplsioc:dav_iri "http://^{URIQADefaultHost}^%s" (in path varchar) .
create iri class oplsioc:grantee_iri using
  function DB.DBA.RDF_DF_GRANTEE_ID_URI (in id integer) returns varchar ,
  function DB.DBA.RDF_DF_GRANTEE_ID_URI_INVERSE (in id_iri varchar) returns integer .
make oplsioc:user_iri subclass of oplsioc:grantee_iri .
make oplsioc:group_iri subclass of oplsioc:grantee_iri .
')
;

DB.DBA.SPARQL_QM_RUN ('
prefix oplsioc: <http://www.openlinksw.com/schemas/oplsioc#>
prefix sioc: <http://rdfs.org/sioc/ns#>
alter quad storage virtrdf:DefaultQuadStorage
  {
#    create virtrdf:DefaultQuadMap using storage virtrdf:DefaultQuadStorage .
    create virtrdf:SysUsers as graph iri ("http://^{URIQADefaultHost}^/sys") option (exclusive)
      {
        oplsioc:user_iri (DB.DBA.SYS_USERS.U_ID)
            a sioc:user where (^{alias}^.U_IS_ROLE = 0)
                    as virtrdf:SysUserType-User ;
            sioc:email DB.DBA.SYS_USERS.U_E_MAIL where (^{alias}^.U_IS_ROLE = 0)
                    as virtrdf:SysUsersEMail-User ;
            sioc:login DB.DBA.SYS_USERS.U_NAME where (^{alias}^.U_IS_ROLE = 0)
                    as virtrdf:SysUsersName-User ;
            oplsioc:login DB.DBA.SYS_USERS.U_NAME where (^{alias}^.U_IS_ROLE = 0)
                    as virtrdf:SysUsersName-User1 ;
            oplsioc:home oplsioc:dav_iri (DB.DBA.SYS_USERS.U_HOME) where ((^{alias}^.U_IS_ROLE = 0) and (^{alias}^.U_DAV_ENABLE = 1))
                    as virtrdf:SysUsersHome ;
            oplsioc:name DB.DBA.SYS_USERS.U_FULL_NAME where ((^{alias}^.U_IS_ROLE = 0) and (^{alias}^.U_NAME is not null))
                    as virtrdf:SysUsersFullName .
        oplsioc:group_iri (DB.DBA.SYS_USERS.U_ID)
            a sioc:role where (^{alias}^.U_IS_ROLE = 1)
                    as virtrdf:SysUserType-Role ;
            oplsioc:login DB.DBA.SYS_USERS.U_NAME where (^{alias}^.U_IS_ROLE = 1)
                    as virtrdf:SysUsersName-Role ;
            oplsioc:name DB.DBA.SYS_USERS.U_FULL_NAME where ((^{alias}^.U_IS_ROLE = 1) and (^{alias}^.U_NAME is not null))
                    as virtrdf:SysUsersFullName-Role .
        oplsioc:group_iri (DB.DBA.SYS_ROLE_GRANTS.GI_SUB)
            sioc:has_member oplsioc:grantee_iri (DB.DBA.SYS_ROLE_GRANTS.GI_SUPER)
                    as virtrdf:SysRoleGrantsHasMember ;
            oplsioc:group_of_membership
                oplsioc:membership_iri (DB.DBA.SYS_ROLE_GRANTS.GI_SUPER, DB.DBA.SYS_ROLE_GRANTS.GI_SUB)
                    as virtrdf:SysRoleGrantsGroupOfMembership .
        oplsioc:grantee_iri (DB.DBA.SYS_ROLE_GRANTS.GI_SUPER)
            sioc:has_function oplsioc:group_iri (DB.DBA.SYS_ROLE_GRANTS.GI_SUB)
                    as virtrdf:SysRoleGrantsHasFunction ;
            oplsioc:member_of
                oplsioc:membership_iri (DB.DBA.SYS_ROLE_GRANTS.GI_SUPER, DB.DBA.SYS_ROLE_GRANTS.GI_SUB)
                    as virtrdf:SysRoleGrantsMemberOfMembership .
        oplsioc:membership_iri (DB.DBA.SYS_ROLE_GRANTS.GI_SUPER, GI_SUB)
            oplsioc:is_direct GI_DIRECT
                    as virtrdf:SysRoleGrantsMembershipIsDirect ;
            rdf:type oplsioc:grant
                    as virtrdf:SysRoleGrantsTypeMembership .
      }
  }
')
;

