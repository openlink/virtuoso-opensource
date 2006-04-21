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

create function SPARQL_DAV_DATA_PATH() returns varchar
{
  return '/DAV/sparql_demo/data/';
}
;

create function SPARQL_DAV_USER_DATA_PATH()
{
  return SPARQL_DAV_DATA_PATH() || 'user_data/';
}
;

create function SPARQL_DAV_DATA_URI() returns varchar
{
  return 'http://local.virt' || SPARQL_DAV_DATA_PATH();
}
;

create function SPARQL_FILE_DATA_ROOT() returns varchar
{
  return TUTORIAL_ROOT_DIR() || '/tutorial/xml/rq_s_1/sparql_dawg/';
}
;

-- No need because this file is now built into the server executable
--create function DB.DBA.RDF_EXP_LOAD_RDFXML_XSL() returns varchar
--{
--  return 'http://local.virt/DAV/sparql_demo/rdf-exp-load.xsl';
--}
--;


create procedure SPARQL_REPORT(in strg varchar)
{
  if (__tag(strg) <> 182)
    strg := cast (strg as varchar) || sprintf (' -- not a string, tag=%d', __tag(strg));
  strg := replace (strg, SPARQL_DAV_DATA_URI(), '\044{SPARQL_DAV_DATA_URI()}');
  strg := replace (strg, SPARQL_DAV_DATA_PATH(), '\044{SPARQL_DAV_DATA_PATH()}');
  strg := replace (strg, SPARQL_FILE_DATA_ROOT(), '\044{SPARQL_FILE_DATA_ROOT()}');
  result (strg);
}
;

create table DB.DBA.SPARQL_DAWG_STATUS (
  TEST_URI	varchar not null,
  TEST_STATUS	varchar not null,
  TEST_STATE	varchar,
  TEST_MESSAGE	varchar,
  primary key (TEST_URI, TEST_STATUS)
);

create procedure SPARQL_DAWG_COMPILE (in rquri varchar, in in_result integer := 0)
{
  declare rqtext varchar;
  declare REPORT varchar;
  declare lexems any;
  declare ses any;
  declare prev_line, lctr, lcount integer;
  declare sqltext varchar;
  if (not in_result)
    result_names (REPORT);
  SPARQL_REPORT ('');
  SPARQL_REPORT ('SPARQL_DAWG_COMPILE on ' || rquri);
  rqtext := replace (cast (XML_URI_GET ('', rquri) as varchar), '# \044Id:', '# Id:');
  lexems := sparql_lex_analyze (rqtext);
  dbg_obj_princ (lexems);
  prev_line := lexems[1][0]; ses := string_output ();
  http (sprintf ('%3d | ', prev_line), ses);
  lcount := length (lexems) - 1;
  for (lctr := 1; lctr < lcount; lctr := lctr + 1)
    {
      declare lexem any;
      lexem := lexems[lctr];
      if (lexem[0] > prev_line)
        {
	  result (string_output_string (ses));
	  prev_line := lexem[0]; ses := string_output ();
	  http (sprintf ('%3d | ', prev_line), ses);
	  http (space (lexem[1] * 2), ses);
	}
      http (cast (lexem[2] as varchar), ses);
      http (' ', ses);
    }
  result (string_output_string (ses));
  if (length (lexems[lcount]) <> 4)
    {
      insert replacing SPARQL_DAWG_STATUS (
        TEST_URI, TEST_STATUS, TEST_STATE, TEST_MESSAGE)
      values (
        rquri, 'ERROR/lex', __SQL_STATE, lexems[lcount][2]);
      SPARQL_REPORT ('ERROR/lex: ' || lexems[lcount][2]);
--!      dump_large_text_impl (replace (rqtext, '\r\n', '\n'));
      return;
    }
  declare exit handler for sqlstate '*' {
    declare msg varchar;
    declare hit integer;
    msg := replace (__SQL_MESSAGE, '\r\n', '\n');
    hit := strstr (msg, 'sparql_explain:(BIF)');
    if (hit is not null)
      msg := subseq (msg, 0, hit - 4);
    insert replacing SPARQL_DAWG_STATUS (
      TEST_URI, TEST_STATUS, TEST_STATE, TEST_MESSAGE)
    values (
      rquri, 'ERROR/spart', __SQL_STATE, msg);
    SPARQL_REPORT ('ERROR/spart: ' || __SQL_STATE || ': ' || msg);
    return;
    };
--!  dump_large_text_impl (replace (string_output_string (sparql_explain (rqtext)), '\r\n', '\n'));
  declare exit handler for sqlstate '*' {
    declare msg varchar;
    declare hit integer;
    msg := replace (__SQL_MESSAGE, '\r\n', '\n');
    hit := strstr (msg, 'sparql_to_sql_text:(BIF)');
    if (hit is not null)
      msg := subseq (msg, 0, hit - 4);
    insert replacing SPARQL_DAWG_STATUS (
      TEST_URI, TEST_STATUS, TEST_STATE, TEST_MESSAGE)
    values (
      rquri, 'ERROR/sqlgen', __SQL_STATE, msg);
    SPARQL_REPORT ('ERROR/sqlgen: ' || __SQL_STATE || ': ' || msg);
    };
  sqltext := replace (string_output_string (sparql_to_sql_text (rqtext)), '\r\n', '\n');
--!  dump_large_text_impl (sqltext);
  {
    declare stat varchar;
    declare msg varchar;
    declare hit integer;
    declare params, rmeta, rrows any;
    stat := '00000';
    exec ('explain(?)', stat, msg, vector (sqltext), 10000, rmeta, rrows);
    if (stat <> '00000')
      {
        msg := replace (msg, '\r\n', '\n');
        hit := strstr (msg, 'explain:(BIF)');
        if (hit is not null)
          msg := subseq (msg, 0, hit - 4);
        insert replacing SPARQL_DAWG_STATUS (
          TEST_URI, TEST_STATUS, TEST_STATE, TEST_MESSAGE)
        values (
          rquri, 'ERROR/sqlcomp', __SQL_STATE, msg);
        SPARQL_REPORT ('ERROR/sqlcomp: ' || stat || ': ' || msg);
      }
  }
    insert replacing SPARQL_DAWG_STATUS (
      TEST_URI, TEST_STATUS, TEST_STATE, TEST_MESSAGE)
    values (
      rquri, 'COMPILED', '00000', '');
}
;

create procedure SPARQL_DAWG_COMPILE_ALL ()
{
  declare rqlst any;
  declare REPORT varchar;
  result_names (REPORT);
  rqlst := SPARQL_DAWG_RQ_LIST();
  rqlst := subseq (rqlst, 0, length (rqlst) - 1);
  foreach (varchar rq in rqlst) do
    {
      SPARQL_DAWG_COMPILE (SPARQL_DAV_DATA_URI() || rq, 1);
    }
}
;

create procedure SPARQL_DAWG_LOAD_QUERIES ()
{
  declare rqlst any;
  declare REPORT varchar;
  result_names (REPORT);
  rqlst := SPARQL_DAWG_RQ_LIST();
  rqlst := subseq (rqlst, 0, length (rqlst) - 1);
  foreach (varchar rq in rqlst) do
    {
      SPARQL_DAWG_LOAD_DATFILE (rq, 1);
    }
}
;


create procedure SPARQL_MKPATH (in path varchar)
{
  declare rslash integer;
  rslash := strrchr (path, '/');
  if (rslash is null)
    signal ('OBLOM', sprinf ('SPARQL_MKPATH (%s)', path));
  path := subseq (path, 0, rslash+1);
  if (length (path) <= length (SPARQL_DAV_DATA_PATH()))
    return;
  if (DAV_HIDE_ERROR (DAV_SEARCH_ID (path, 'C')) is not null)
    return;
  SPARQL_MKPATH (subseq (path, 0, length (path) - 1));
  DAV_COL_CREATE (path, '110110110RR', http_dav_uid(), http_dav_uid() + 1, 'dav', (SELECT pwd_magic_calc (U_NAME, U_PASSWORD, 1) FROM DB.DBA.SYS_USERS WHERE U_NAME = 'dav'));
}
;

create procedure SPARQL_DAWG_LOAD_MANIFESTS ()
{
  declare mflst any;
  declare REPORT varchar;
  result_names (REPORT);
  mflst := SPARQL_DAWG_MANIFEST_RDF_LIST();
  mflst := subseq (mflst, 0, length (mflst) - 1);
  foreach (varchar mfname in mflst) do
    {
      if (mfname is not null)
        {
	  declare filefullname, davpath, davuri varchar;
	  declare id integer;
	  filefullname := SPARQL_FILE_DATA_ROOT() || mfname;
	  davpath := SPARQL_DAV_DATA_PATH() || mfname;
	  davuri := SPARQL_DAV_DATA_URI() || mfname;
	  SPARQL_MKPATH (davpath);
	  DB.DBA.DAV_DELETE (davpath, 1, 'dav', (SELECT pwd_magic_calc (U_NAME, U_PASSWORD, 1) FROM DB.DBA.SYS_USERS WHERE U_NAME = 'dav'));
	  delete from RDF_QUAD where G = DB.DBA.RDF_MAKE_IID_OF_QNAME (davuri);
	  id := DB.DBA.DAV_RES_UPLOAD (davpath,
	    t_file_to_string (filefullname,TUTORIAL_IS_DAV()),
	    'application/rdf+xml',
	    '110110110RR',
	    http_dav_uid(), http_dav_uid() + 1, 'dav', (SELECT pwd_magic_calc (U_NAME, U_PASSWORD, 1) FROM DB.DBA.SYS_USERS WHERE U_NAME = 'dav'));
	  SPARQL_REPORT (sprintf ('Uploading %s to %s: %s',
	      filefullname, davpath,
	      case (gt (id, 0)) when 1 then 'PASSED' else 'FAILED' end ));
          DB.DBA.RDF_EXP_LOAD_RDFXML (davuri,
	    xtree_doc (XML_URI_GET ('', davuri), 0, davuri),
              0, null );
	}
    }
}
;

create procedure SPARQL_DAWG_LOAD_DATFILE (in rel_path varchar, in in_resultset integer := 0)
{
  declare REPORT varchar;
  declare filefullname, davpath, davuri varchar;
  declare id integer;
  declare graph_uri, dattext varchar;
  declare app_env any;
  app_env := null;
  if (not in_resultset)
    result_names (REPORT);
  filefullname := SPARQL_FILE_DATA_ROOT() || rel_path;
  davpath := SPARQL_DAV_DATA_PATH() || rel_path;
  davuri := SPARQL_DAV_DATA_URI() || rel_path;
  SPARQL_MKPATH (davpath);
  DB.DBA.DAV_DELETE (davpath, 1, 'dav', (SELECT pwd_magic_calc (U_NAME, U_PASSWORD, 1) FROM DB.DBA.SYS_USERS WHERE U_NAME = 'dav'));
  id := DB.DBA.DAV_RES_UPLOAD (davpath,
    t_file_to_string (filefullname,TUTORIAL_IS_DAV()),
    'application/rdf+xml',
    '110110110RR',
    http_dav_uid(), http_dav_uid() + 1, 'dav', (SELECT pwd_magic_calc (U_NAME, U_PASSWORD, 1) FROM DB.DBA.SYS_USERS WHERE U_NAME = 'dav') );
  SPARQL_REPORT (sprintf ('Uploading %s to %s: %s',
      filefullname, davpath,
      case (gt (id, 0)) when 1 then 'PASSED' else 'FAILED' end ));
  dattext := replace (cast (XML_URI_GET ('', davuri) as varchar), '# \044Id:', '# Id:');
  graph_uri := davuri;
  delete from RDF_QUAD where G = DB.DBA.RDF_MAKE_IID_OF_QNAME (graph_uri);
  if (rel_path like '%.ttl')
    DB.DBA.TTLP (dattext, davuri, graph_uri);
  else if (rel_path like '%.rdf')
    DB.DBA.RDF_EXP_LOAD_RDFXML (
      DB.DBA.RDF_MAKE_IID_OF_QNAME (graph_uri),
      xtree_doc (dattext, 0, davuri),
      0, app_env );
  return graph_uri;
}
;

create procedure SPARQL_DAWG_LOAD_ALL_DATFILES ()
{
  declare REPORT varchar;
  declare dat_list any;
  result_names (REPORT);
  dat_list := DB.DBA.SPARQL_EVAL_TO_ARRAY ('
PREFIX dawg: <http://www.w3.org/2001/sw/DataAccess/tests/test-query#>
SELECT DISTINCT ?d
WHERE {
    GRAPH ?g {
       [ dawg:data ?d ;
         dawg:query ?q ]
 }
  }', '', 10000);
  foreach (any dat in dat_list) do
    {
      SPARQL_DAWG_LOAD_DATFILE (
        subseq (dat[0], length (SPARQL_DAV_DATA_URI())),
	1 );
    }
}
;

create procedure SPARQL_DAWG_LOAD_ALL_RESULTS ()
{
  declare REPORT varchar;
  declare dat_list any;
  result_names (REPORT);
  dat_list := DB.DBA.SPARQL_EVAL_TO_ARRAY ('
PREFIX tm: <http://www.w3.org/2001/sw/DataAccess/tests/test-manifest#>
SELECT DISTINCT ?d
WHERE {
    GRAPH ?g {
       [ tm:result ?d ]
 }
  }', '', 10000);
  foreach (any dat in dat_list) do
    {
      SPARQL_DAWG_LOAD_DATFILE (
        subseq (dat[0], length (SPARQL_DAV_DATA_URI())),
	1 );
    }
}
;

create procedure SPARQL_DAWG_EVAL_ONE (in rquri varchar, in daturi varchar, in resuri varchar, in in_result integer := 0)
{
  declare REPORT varchar;
  declare ses any;
  declare rqtext, dattext, sqltext varchar;
  declare graph_uri varchar;  
  declare app_env any;
  declare rset, row any;
  declare etalon_vars, etalon_rowids, etalon_rows any;
  declare rctr, rcount integer;
  if (not in_result)
    result_names (REPORT);
  SPARQL_REPORT ('');
  declare exit handler for sqlstate '*' {
    declare msg varchar;
    declare hit integer;
    msg := replace (__SQL_MESSAGE, '\r\n', '\n');
    hit := strstr (msg, ':(BIF)');
    if (hit is not null)
      {
        msg := subseq (msg, 0, hit - 4);
	msg := subseq (msg, 0, strrchr (msg, '\n'));
	msg := subseq (msg, 0, strrchr (msg, '\n'));
      }
    insert replacing SPARQL_DAWG_STATUS (
      TEST_URI, TEST_STATUS, TEST_STATE, TEST_MESSAGE)
    values (
      rquri, 'ERROR/eval', __SQL_STATE, msg);
    SPARQL_REPORT ('ERROR/eval: ' || __SQL_STATE || ': ' || msg);
    return;
    };
  SPARQL_REPORT ('SPARQL_DAWG_EVAL_ONE of ' || rquri);
  SPARQL_REPORT ('  with data ' || daturi);
  rqtext := replace (cast (XML_URI_GET ('', rquri) as varchar), '# \044Id:', '# Id:');
--!  dump_large_text_impl (replace (rqtext, '\r\n', '\n'));
  dattext := replace (cast (XML_URI_GET ('', daturi) as varchar), '# \044Id:', '# Id:');
  SPARQL_REPORT ('Raw Data (' || daturi || '):');
--!  dump_large_text_impl (replace (dattext, '\r\n', '\n'));
--  graph_uri := subseq (daturi, strrchr (daturi, '/') + 1);
  graph_uri := daturi;
  app_env := null;
  rset := DB.DBA.SPARQL_EVAL_TO_ARRAY (rqtext, graph_uri, 50);
  SPARQL_REPORT ('Results of ' || rquri);
  SPARQL_REPORT ('  with data ' || daturi);
  rcount := length (rset);
  for (rctr := 0; rctr < rcount; rctr := rctr + 1)
    {
      row := rset [rctr];
      SPARQL_REPORT (sprintf ('row %d', rctr + 1));
      foreach (any col in row) do
        {
	  if (214 = __tag (col))
	    {
	      declare triples, ses any;
	      triples := dict_list_keys (col, 1);
	      ses := string_output ();
--	      DB.DBA.RDF_TRIPLES_TO_RDF_XML_TEXT (triples, 1, ses);
	      DB.DBA.RDF_TRIPLES_TO_TTL (triples, ses);
	      SPARQL_REPORT (string_output_string (ses));
	    }
	  else
            SPARQL_REPORT ('    ' || cast (col as varchar));
	}
    }
  if (resuri is null)
    {
      insert replacing SPARQL_DAWG_STATUS (
        TEST_URI, TEST_STATUS, TEST_STATE, TEST_MESSAGE)
      values (
        rquri, 'PASSED/no-etalon', '00000', sprintf ('%d rows', rcount));
      SPARQL_REPORT ('PASSED/no-etalon');
      return;
    }    
  etalon_vars := DB.DBA.SPARQL_EVAL_TO_ARRAY ('
PREFIX rs: <http://www.w3.org/2001/sw/DataAccess/tests/result-set#>
SELECT ?var
WHERE {
  [ rs:resultVariable ?var ]
  }', resuri, 10000);
  etalon_rowids := DB.DBA.SPARQL_EVAL_TO_ARRAY ('
PREFIX rs: <http://www.w3.org/2001/sw/DataAccess/tests/result-set#>
SELECT ?sln
WHERE {
  [ rs:solution ?sln ]
  }', resuri, 10000);
  if (0 = length (etalon_vars))
    {
      insert replacing SPARQL_DAWG_STATUS (
        TEST_URI, TEST_STATUS, TEST_STATE, TEST_MESSAGE)
      values (
        rquri, 'NO_ETA', '00000', sprintf ('No vars in etalon %s', resuri));
      SPARQL_REPORT (sprintf ('No vars in etalon %s', resuri));
      return;
    }
  if (length (etalon_rowids) <> rcount)
    {
      insert replacing SPARQL_DAWG_STATUS (
        TEST_URI, TEST_STATUS, TEST_STATE, TEST_MESSAGE)
      values (
        rquri, 'DIFF', '00000', sprintf ('%d rows, must be %d', rcount, length (etalon_rowids)));
      SPARQL_REPORT (sprintf ('%d rows, must be %d', rcount, length (etalon_rowids)));
      return;
    }
  if (1=2) --!
    {
      declare rexec_stat, rexec_msg varchar;
      declare bnode_dict, rexec_rmeta, rexec_rrows any;
      rexec_stat := '00000';
      rexec_msg := 'OK';
      bnode_dict := dict_new ();
      rexec_rrows := null;
      exec (
        'DB.DBA.SPARQL_REXEC (?, ?, ?, ?, ?, ?, ?)',
	rexec_stat, rexec_msg,
	vector (
	  WB_CFG_HTTP_URI() || '/sparql/',
	  rqtext,
	  graph_uri,
	  vector (),
	  '',
	  10000,
	  bnode_dict ),
	10000, rexec_rmeta, rexec_rrows );
      if (not isarray (rexec_rrows))
        rexec_rrows := null;
      SPARQL_REPORT (sprintf ('Remote exec of %s', rquri));
      SPARQL_REPORT (sprintf ('  with data %s', daturi));
--!      dump_large_text_impl (
--!        sprintf ('  completed with state %s msg %s and %d rows',
--!        rexec_stat, rexec_msg, length (rexec_rrows) ) );
    }    
  insert replacing SPARQL_DAWG_STATUS (
    TEST_URI, TEST_STATUS, TEST_STATE, TEST_MESSAGE)
  values (
    rquri, 'PASSED', '00000', sprintf ('%d rows', rcount));
  SPARQL_REPORT ('PASSED');
}
;

create procedure SPARQL_DAWG_EVAL_ALL ()
{
  declare REPORT varchar;
  declare test_list any;
  test_list := DB.DBA.SPARQL_EVAL_TO_ARRAY ('
PREFIX tq: <http://www.w3.org/2001/sw/DataAccess/tests/test-query#>
PREFIX tm: <http://www.w3.org/2001/sw/DataAccess/tests/test-manifest#>
SELECT ?queryuri ?datauri ?etalonuri
WHERE {
  GRAPH ?g {
    [ tm:result ?etalonuri ;
      tm:action
        [ tq:data ?datauri ;
          tq:query ?queryuri ]
      ]
#     ?t tm:action
#        [ tq:data ?datauri ;
#          tq:query ?queryuri ] .
#     OPTIONAL { ?t tm:result ?etalonuri }
    }
  }', '', 10000);
  result_names (REPORT);
  foreach (any test in test_list) do
    {
      SPARQL_DAWG_EVAL_ONE (test[0], test[1], test[2], 1);
    }
}
;

SPARQL_DAWG_LOAD_MANIFESTS ();
SPARQL_DAWG_LOAD_ALL_DATFILES ();
SPARQL_DAWG_LOAD_ALL_RESULTS ();
SPARQL_DAWG_LOAD_QUERIES ();
SPARQL_DAWG_COMPILE_ALL ();
SPARQL_DAWG_EVAL_ALL ();

-- select sprintf ('%-62s%-13s%s', regexp_match ('/[^/]+/[^/]+/[^/]+\044', TEST_URI), TEST_STATUS, TEST_MESSAGE) from SPARQL_DAWG_STATUS order by 1;

-- select TEST_STATUS, COUNT(*) from SPARQL_DAWG_STATUS group by TEST_STATUS order by 1;

-- binsrc/samples/sparql_demo/setup.sql

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
      vector (2, 'Browse loaded data','demo.vsp?desk=browse_data'),
      vector (2, 'Custom Query','demo.vsp?desk=desk&case=custom_sparql'),
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
