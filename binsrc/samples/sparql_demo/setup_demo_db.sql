--
--  $Id$
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
--

--load 'sparql_dawg/manifest-rdf-list.sql';
--load 'sparql_dawg/rdf-list.sql';
--load 'sparql_dawg/rq-list.sql';
--load 'sparql_dawg/ttl-list.sql';
--set banner on;
--set blobs on;
--set echo on;
--set types on;
--set verbose on;

--DAV_COL_CREATE ('/DAV/sparql_demo/data/', '110110110RR', 'dav', 'dav', 'dav', 'dav');

create function SPARQL_DAV_DATA_PATH() returns varchar
{
  return '/DAV/VAD/sparql_demo/data/';
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
  return 'sparql_dawg/';
}
;

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

"RQ"."RQ"."sparql_exec_no_error"('drop table DB.DBA.SPARQL_DAWG_STATUS');

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
  if (isstring (registry_get ('URIQADefaultHost')))
    rqtext := replace (rqtext, '^{URIQADefaultHost}^', registry_get ('URIQADefaultHost'));
  rqtext := 'define input:storage ""\n' || rqtext;
  lexems := sparql_lex_analyze (rqtext);
  --dbg_obj_princ (lexems);
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
      SPARQL_REPORT ('ERROR/lex: ' || cast (lexems[lcount][2] as varchar));
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
  DAV_COL_CREATE (path, '110110110RR', 'dav', 'dav', 'dav', (SELECT pwd_magic_calc (U_NAME, U_PASSWORD, 1) FROM DB.DBA.SYS_USERS WHERE U_NAME = 'dav'));
}
;

create procedure SPARQL_DAWG_LOAD_MANIFESTS ()
{
  declare mflst any;
  declare REPORT,content_type varchar;
  result_names (REPORT);
  mflst := SPARQL_DAWG_MANIFEST_RDF_LIST();
  mflst := subseq (mflst, 0, length (mflst) - 1);
  foreach (varchar mfname in mflst) do
    {
      if (mfname is not null)
        {
	  declare filefullname, davpath, davuri varchar;
	  declare id integer;
	  --filefullname := SPARQL_FILE_DATA_ROOT() || mfname;
	  --davpath := SPARQL_DAV_DATA_PATH() || mfname;
	  davuri := SPARQL_DAV_DATA_URI() || mfname;
	  --SPARQL_MKPATH (davpath);
	  --DB.DBA.DAV_DELETE (davpath, 1, 'dav', 'dav');
    --delete from RDF_QUAD where G = DB.DBA.RDF_MAKE_IID_OF_QNAME (davuri);
    --if (davpath like '%.ttl')
    --  content_type := 'application/x-turtle';
    --else
    --  content_type := 'application/rdf+xml';
	  --id := DB.DBA.DAV_RES_UPLOAD (davpath,
	  --  file_to_string (filefullname),
	  --  content_type,
	  --  '110110110RR',
	  --  'dav', 'dav', 'dav', 'dav' );
	  --SPARQL_REPORT (sprintf ('Uploading %s to %s: %s',
	  --    filefullname, davpath,
	  --    case (gt (id, 0)) when 1 then 'PASSED' else 'FAILED' || DAV_PERROR (id) end ));
          delete from RDF_QUAD where G = DB.DBA.RDF_MAKE_IID_OF_QNAME (davuri);
          DB.DBA.RDF_LOAD_RDFXML (XML_URI_GET ('', davuri), davuri, davuri);
	}
    }
}
;

create procedure SPARQL_DAWG_LOAD_DATFILE (in rel_path varchar, in in_resultset integer := 0)
{
  declare REPORT varchar;
  declare filefullname, davpath, davuri varchar;
  declare id integer;
  declare graph_uri, dattext,content_type varchar;
  declare app_env any;
  app_env := null;
  if (rel_path like '%disable')
    return;
  whenever sqlstate '*' goto err_rep;
  if (not in_resultset)
    result_names (REPORT);
  --filefullname := SPARQL_FILE_DATA_ROOT() || rel_path;
  davpath := SPARQL_DAV_DATA_PATH() || rel_path;
  davuri := SPARQL_DAV_DATA_URI() || rel_path;
  --SPARQL_MKPATH (davpath);
  --DB.DBA.DAV_DELETE (davpath, 1, 'dav', 'dav');
  --if (rel_path like '%.ttl')
  --  content_type := 'application/x-turtle';
  --else
  --  content_type := 'application/rdf+xml';
  --id := DB.DBA.DAV_RES_UPLOAD (davpath,
  --  file_to_string (filefullname),
  --  content_type,
  --  '110110110RR',
  --  'dav', 'dav', 'dav', 'dav' );
  --SPARQL_REPORT (sprintf ('Uploading %s to %s: %s',
  --    filefullname, davpath,
  --    case (gt (id, 0)) when 1 then 'PASSED' else 'FAILED' || DAV_PERROR (id) end ));
  dattext := replace (cast (XML_URI_GET ('', davuri) as varchar), '# \044Id:', '# Id:');
  graph_uri := davuri;
  delete from RDF_QUAD where G = DB.DBA.RDF_MAKE_IID_OF_QNAME (graph_uri);
  if (rel_path like '%.ttl')
    DB.DBA.TTLP (dattext, davuri, graph_uri);
  else if (rel_path like '%.rdf')
    DB.DBA.RDF_LOAD_RDFXML (dattext, davuri, graph_uri);
  return graph_uri;
err_rep:
  result (sprintf ('%s: %s', __SQL_STATE, __SQL_MESSAGE));
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
  if (isstring (registry_get ('URIQADefaultHost')))
    rqtext := replace (rqtext, '^{URIQADefaultHost}^', registry_get ('URIQADefaultHost'));
--!  dump_large_text_impl (replace (rqtext, '\r\n', '\n'));
  if (daturi like '%disable')
    graph_uri := NULL;
  else
    {
  dattext := replace (cast (XML_URI_GET ('', daturi) as varchar), '# \044Id:', '# Id:');
  SPARQL_REPORT ('Raw Data (' || daturi || '):');
--!  dump_large_text_impl (replace (dattext, '\r\n', '\n'));
--  graph_uri := subseq (daturi, strrchr (daturi, '/') + 1);
  graph_uri := daturi;
    }
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
  if (daturi like '%disable')
    {
      insert replacing SPARQL_DAWG_STATUS (
        TEST_URI, TEST_STATUS, TEST_STATE, TEST_MESSAGE)
      values (
        rquri, 'PASSED/may-vary', '00000', sprintf ('%d rows', rcount));
      SPARQL_REPORT ('PASSED/may-vary');
      return;
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
#pragma prefix tq: <http://www.w3.org/2001/sw/DataAccess/tests/test-query#>
#pragma prefix tm: <http://www.w3.org/2001/sw/DataAccess/tests/test-manifest#>
  declare REPORT varchar;
  result_names (REPORT);
  for (sparql
SELECT ?queryuri ?datauri ?etalonuri
WHERE {
  GRAPH ?g {
#    [ tm:result ?etalonuri ;
#      tm:action
#        [ tq:data ?datauri ;
#          tq:query ?queryuri ]
#      ]
     ?t tm:action
        [ tq:data ?datauri ;
          tq:query ?queryuri ] .
     OPTIONAL { ?t tm:result ?etalonuri }
    }
  }
ORDER BY
  ASC [ bif:lower ( ?queryuri ) ]
  ASC [ bif:lower ( ?datauri ) ]
  ASC [ bif:lower ( ?etalonuri ) ]
  ) do
    {
    SPARQL_DAWG_EVAL_ONE ("queryuri", "datauri", "etalonuri", 1);
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
