--  test_graph_security.sql
--
--  Graph analytics: graph-level security and preload-data hardening.
--  Test Group K.
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
--  WHY THIS FILE EXISTS
--
--  The graph analytics BIFs read DB.DBA.RDF_QUAD with their own SQL rather
--  than through the SPARQL compiler, so the __rgs_ack graph-permission
--  filter the compiler injects for every graph column does not apply to
--  them.  Without an explicit check in the BIF layer, any user who can
--  reach the BIFs -- including the anonymous SPARQL endpoint identity --
--  could read the structure of a graph they have no permission on, and
--  GRAPH_SHORTEST_PATH would hand back the node IRIs themselves.
--
--  Every assertion below therefore pairs a *control* (plain SPARQL, which
--  is known to enforce the permission) with the graph analytics call that
--  must now behave identically.
--
--  The tests run as dba and switch identity with set_user_id(<user>, 1),
--  which restores the caller's identity when the enclosing procedure
--  returns.  GRAPH_SEC_STATE() reports the SQLSTATE of a statement run
--  under a given identity; GRAPH_SEC_VALUE() reports its first value.

ECHO BOTH "STARTED: graph analytics security test suite\n";

-- ============================================================================
-- Fixture
-- ============================================================================

-- A three-node chain in its own graph.  alice -> bob -> carol, plus a second
-- edge into carol, so degrees and a two-hop path are both observable.
SPARQL
INSERT INTO <urn:graph:sec:private> {
  <urn:graph:sec:alice> <urn:graph:sec:reportsTo> <urn:graph:sec:bob> .
  <urn:graph:sec:bob>   <urn:graph:sec:reportsTo> <urn:graph:sec:carol> .
  <urn:graph:sec:dave>  <urn:graph:sec:reportsTo> <urn:graph:sec:carol> .
};

-- A low-privilege user that can reach SPARQL and therefore the bif: surface.
--
-- The name is quoted in the GRANT because it is an identifier there and a
-- string in USER_CREATE.  Under CaseMode 1 -- which is what the stock test
-- harness generates, whatever a hand-run server happens to use -- an
-- unquoted identifier folds to upper case, so the GRANT looked for GTEST,
-- the user it had just made was gtest, and three assertions below failed
-- with "The object GTEST does not exist".
DB.DBA.USER_CREATE ('gtest', 'gtest');
GRANT SPARQL_SELECT TO "gtest";

-- Deny by default for this user only.  Note that RDF_GRAPH_USER_PERMS_SET
-- alone cannot deny: rdf_graph_configured_perms() ORs permissions together
-- and falls back to RDF_GRAPH_PERM_DEFAULT when nothing is configured, so
-- the *default* perms of the user are what turn security on for them.
-- Scoped to 'gtest' so the rest of the suite is unaffected.
DB.DBA.RDF_DEFAULT_USER_PERMS_SET ('gtest', 0);
commit work;

create procedure GRAPH_SEC_STATE (in usr varchar, in txt varchar)
{
  declare st, msg varchar;
  declare mdta, rset any;
  st := '00000';
  msg := '';
  -- mode 1: cli_user is restored when this procedure returns
  set_user_id (usr, 1);
  exec (txt, st, msg, vector (), 0, mdta, rset);
  return st;
}
;

create procedure GRAPH_SEC_VALUE (in usr varchar, in txt varchar)
{
  declare st, msg varchar;
  declare mdta, rset any;
  st := '00000';
  msg := '';
  set_user_id (usr, 1);
  exec (txt, st, msg, vector (), 0, mdta, rset);
  if (st <> '00000')
    return 'STATE:' || st;
  if (isarray (rset) and length (rset) > 0 and isarray (rset[0]) and length (rset[0]) > 0)
    return cast (rset[0][0] as varchar);
  return 'NOROWS';
}
;

-- ============================================================================
-- Group K: graph-level READ permission is enforced on the BIF path
-- ============================================================================

-- K.1: sanity -- dba sees the fixture (degree of carol is 2 incoming)
select cast (GRAPH_DEGREE_CENTRALITY ('urn:graph:sec:carol', 'urn:graph:sec:private') as integer);
ECHO BOTH ": K1 dba degree(carol) = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";

-- K.2: control -- plain SPARQL correctly returns nothing for the denied user
select GRAPH_SEC_VALUE ('gtest',
  'SPARQL SELECT ?s FROM <urn:graph:sec:private> WHERE { ?s <urn:graph:sec:reportsTo> ?o }');
ECHO BOTH ": K2 gtest plain SPARQL = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] NOROWS "PASSED" "***FAILED";

-- K.3: SQL scalar form must be denied, not answered
select GRAPH_SEC_STATE ('gtest',
  'select GRAPH_DEGREE_CENTRALITY (''urn:graph:sec:carol'', ''urn:graph:sec:private'')');
ECHO BOTH ": K3 gtest GRAPH_DEGREE_CENTRALITY state = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] 42006 "PASSED" "***FAILED";

-- K.4: GRAPH_SHORTEST_PATH must not hand back the node IRIs of the graph
select GRAPH_SEC_STATE ('gtest',
  'select GRAPH_SHORTEST_PATH (''urn:graph:sec:alice'', ''urn:graph:sec:carol'', ''urn:graph:sec:private'')');
ECHO BOTH ": K4 gtest GRAPH_SHORTEST_PATH state = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] 42006 "PASSED" "***FAILED";

-- K.5: reachability must not leak either
select GRAPH_SEC_STATE ('gtest',
  'select GRAPH_SHORTEST_PATH_LENGTH (''urn:graph:sec:alice'', ''urn:graph:sec:carol'', ''urn:graph:sec:private'')');
ECHO BOTH ": K5 gtest GRAPH_SHORTEST_PATH_LENGTH state = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] 42006 "PASSED" "***FAILED";

-- K.6: whole-graph algorithms are denied as well
select GRAPH_SEC_STATE ('gtest',
  'select GRAPH_WCC (''urn:graph:sec:alice'', ''urn:graph:sec:private'')');
ECHO BOTH ": K6 gtest GRAPH_WCC state = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] 42006 "PASSED" "***FAILED";

-- K.7: SPARQL BIND form with an explicit graph argument
select GRAPH_SEC_STATE ('gtest',
  'SPARQL PREFIX bif: <http://www.openlinksw.com/schemas/bif#>
   SELECT (bif:degree_centrality (<urn:graph:sec:carol>, <urn:graph:sec:private>) AS ?d) WHERE { }');
ECHO BOTH ": K7 gtest bif: BIND form state = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] 42006 "PASSED" "***FAILED";

-- K.8: SPARQL predicate form with OPTION (graph ...) -- the scope override
-- must be checked like any other scope source
select GRAPH_SEC_STATE ('gtest',
  'SPARQL PREFIX bif: <http://www.openlinksw.com/schemas/bif#>
   SELECT ?d WHERE { <urn:graph:sec:carol> bif:degree_centrality ?d
                     OPTION (graph <urn:graph:sec:private>) }');
ECHO BOTH ": K8 gtest OPTION (graph) form state = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] 42006 "PASSED" "***FAILED";

-- K.9: the weighted variants open their own RDF_QUAD cursor and need the
-- same check
select GRAPH_SEC_STATE ('gtest',
  'select GRAPH_DEGREE_WEIGHTED (''urn:graph:sec:carol'', ''urn:graph:sec:private'', NULL, ''urn:graph:sec:w'')');
ECHO BOTH ": K9 gtest GRAPH_DEGREE_WEIGHTED state = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] 42006 "PASSED" "***FAILED";

-- K.10: the SPARQL endpoint identity is denied too (this is the anonymous
-- /sparql path: same user, no HTTP needed to exercise it)
DB.DBA.RDF_DEFAULT_USER_PERMS_SET ('SPARQL', 0);
commit work;
select GRAPH_SEC_STATE ('SPARQL',
  'select GRAPH_DEGREE_CENTRALITY (''urn:graph:sec:carol'', ''urn:graph:sec:private'')');
ECHO BOTH ": K10 SPARQL user state = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] 42006 "PASSED" "***FAILED";

-- K.11: the denial message must not distinguish "no permission" from
-- "no such graph", or it becomes an existence oracle
select GRAPH_SEC_STATE ('gtest',
  'select GRAPH_DEGREE_CENTRALITY (''urn:graph:sec:carol'', ''urn:graph:sec:no-such-graph-at-all'')');
ECHO BOTH ": K11 gtest nonexistent graph state = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] 42006 "PASSED" "***FAILED";

-- K.12: granting READ makes the same call succeed with the right value
DB.DBA.RDF_GRAPH_USER_PERMS_SET ('urn:graph:sec:private', 'gtest', 15);
commit work;
select GRAPH_SEC_VALUE ('gtest',
  'select cast (GRAPH_DEGREE_CENTRALITY (''urn:graph:sec:carol'', ''urn:graph:sec:private'') as integer)');
ECHO BOTH ": K12 gtest after grant = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";

-- K.13: revoking denies again even though the snapshot is now cached --
-- the check runs before the cache lookup, so a cached graph is never
-- served to a user who lost access
-- (RDF_GRAPH_USER_PERMS_SET with 0 is refused while the unauthenticated
-- user still has broader rights on the graph; dropping the specific grant
-- is the supported way to revoke, and falls back to the user's default
-- perms, which are 0 here.)
DB.DBA.RDF_GRAPH_USER_PERMS_DEL ('urn:graph:sec:private', 'gtest');
commit work;
select GRAPH_SEC_STATE ('gtest',
  'select GRAPH_DEGREE_CENTRALITY (''urn:graph:sec:carol'', ''urn:graph:sec:private'')');
ECHO BOTH ": K13 gtest after revoke state = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] 42006 "PASSED" "***FAILED";

-- K.14: dba is unaffected throughout
select cast (GRAPH_DEGREE_CENTRALITY ('urn:graph:sec:carol', 'urn:graph:sec:private') as integer);
ECHO BOTH ": K14 dba degree(carol) still = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";

-- K.15: a user with no graph-security configuration at all is unaffected,
-- so enabling graph analytics does not silently deny existing deployments
DB.DBA.USER_CREATE ('gtest2', 'gtest2');
GRANT SPARQL_SELECT TO "gtest2";
commit work;
select GRAPH_SEC_VALUE ('gtest2',
  'select cast (GRAPH_DEGREE_CENTRALITY (''urn:graph:sec:carol'', ''urn:graph:sec:private'') as integer)');
ECHO BOTH ": K15 unconfigured user = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";

-- ============================================================================
-- The preload-data back door is gone
--
-- GRAPH_SET_PRELOAD_DATA() used to park a *borrowed* pointer to a
-- caller-owned box in thread-local storage and never copy or clear it.  The
-- box was freed at the end of the statement, so every later graph BIF on
-- that pooled server thread dereferenced freed memory -- and because
-- Virtuoso pools threads across connections and users, a handful of
-- unprivileged one-statement connections disabled graph analytics for
-- everyone until the server was restarted.  The API was scaffolding for a
-- PL wrapper that the SPARQL predicate dispatch made unnecessary, so it is
-- removed rather than hardened.
-- ============================================================================

-- K.16: the BIF no longer exists, for dba or anyone else
select GRAPH_SEC_STATE ('dba',
  'select GRAPH_SET_PRELOAD_DATA (vector (vector (1, 2, 3)))');
ECHO BOTH ": K16 GRAPH_SET_PRELOAD_DATA state = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] 42001 "PASSED" "***FAILED";

-- K.17: ... and neither does its counterpart
select GRAPH_SEC_STATE ('dba', 'select GRAPH_CLEAR_PRELOAD_DATA ()');
ECHO BOTH ": K17 GRAPH_CLEAR_PRELOAD_DATA state = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] 42001 "PASSED" "***FAILED";

-- K.18: it is not reachable through the SPARQL bif: namespace either
select GRAPH_SEC_STATE ('SPARQL',
  'SPARQL SELECT (bif:GRAPH_SET_PRELOAD_DATA (bif:vector (bif:vector (1, 2, 3))) AS ?x) WHERE { }');
ECHO BOTH ": K18 bif:GRAPH_SET_PRELOAD_DATA state = " $LAST[1] "\n";
ECHO BOTH $IF $NEQ $LAST[1] 00000 "PASSED" "***FAILED";

-- K.19: the poisoning sequence that used to disable the feature server-wide
-- leaves the next graph query working
select GRAPH_SEC_STATE ('gtest2',
  'select GRAPH_SET_PRELOAD_DATA (vector (vector (1, 2, 3)))');
select cast (GRAPH_DEGREE_CENTRALITY ('urn:graph:sec:carol', 'urn:graph:sec:private') as integer);
ECHO BOTH ": K19 degree after poisoning attempt = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";

-- K.20 - K.22: a graph loaded from a SQL table is read with the caller's
-- own rights on that table.
--
-- GRAPH_LOAD_TABLE pastes a table name into a SELECT and runs it on the
-- calling connection.  That is the permission check: "may this user read
-- this table" is a question SQL already answers, and running the statement
-- under the caller's identity is what asks it.  Nothing about naming a
-- table in this call grants anything.
--
-- The re-read matters as much as the first load.  A table-sourced graph is
-- re-read whenever the cache does not hold it, and that re-read runs on
-- whoever took the miss -- so a user who may not read the table cannot get
-- at it by waiting for someone else's load to be evicted.  K22 is that:
-- dba loads the graph, then the denied user asks an algorithm about it.
create table DB.DBA.GSEC_TBL (S IRI_ID, O IRI_ID)
;
GRANT SELECT ON DB.DBA.GSEC_TBL TO SPARQL_SELECT;

create procedure GSEC_TBL_FILL ()
{
  delete from DB.DBA.GSEC_TBL;
  insert into DB.DBA.GSEC_TBL (S, O)
    values (iri_to_id ('urn:graph:sec:alice'), iri_to_id ('urn:graph:sec:bob'));
  insert into DB.DBA.GSEC_TBL (S, O)
    values (iri_to_id ('urn:graph:sec:bob'), iri_to_id ('urn:graph:sec:carol'));
  commit work;
  return 2;
}
;

select GSEC_TBL_FILL ();

-- K.20: dba can load it, and gets both edges
select cast (GRAPH_LOAD_TABLE ('urn:graph:sec:tbl', 'urn:graph:sec:tp',
                               'DB.DBA.GSEC_TBL') as integer);
ECHO BOTH ": K20 dba loads a graph from a table = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";

-- gtest3 holds no SPARQL_SELECT, so not the table's grant either; gtest
-- does, and the table is granted to SPARQL_SELECT as every source has to be.
DB.DBA.USER_CREATE ('gtest3', 'gtest3');

-- K.21: a user with no SELECT on the table cannot load it
select GRAPH_SEC_STATE ('gtest3',
  'select GRAPH_LOAD_TABLE (''urn:graph:sec:tbl2'', ''urn:graph:sec:tp'', ''DB.DBA.GSEC_TBL'')');
ECHO BOTH ": K21 denied user cannot load from the table = " $LAST[1] "\n";
ECHO BOTH $IF $NEQ $LAST[1] 00000 "PASSED" "***FAILED";

-- K.22: ... and cannot reach it through the graph dba already loaded, when
-- the reload lands on their connection
select GRAPH_SEC_STATE ('gtest3',
  'select GRAPH_LOAD_TABLE (''urn:graph:sec:tbl'', ''urn:graph:sec:tp'', ''DB.DBA.GSEC_TBL'')');
ECHO BOTH ": K22 denied user cannot reload someone else's table graph = " $LAST[1] "\n";
ECHO BOTH $IF $NEQ $LAST[1] 00000 "PASSED" "***FAILED";

-- K.23: a source not granted to SPARQL_SELECT is refused, even to dba: the
-- analytics readers it would serve are let in by that role
create table DB.DBA.GSEC_NOGRANT (S IRI_ID, O IRI_ID);
select GRAPH_SEC_STATE ('dba',
  'select GRAPH_LOAD_TABLE (''urn:graph:sec:ng'', ''urn:graph:sec:tp'', ''DB.DBA.GSEC_NOGRANT'')');
ECHO BOTH ": K23 a table not granted to SPARQL_SELECT = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] 42002 "PASSED" "***FAILED";

-- ============================================================================
-- Group Y: the cause of a load failure is configuration, not an answer
--
-- A failed graph load now carries the SQLSTATE and message of the internal
-- query that failed, so "I/O error" stops being a dead end.  For a
-- table-sourced graph that text names the backing table -- which is server
-- configuration, and nothing a caller who is not DBA should learn by
-- naming a graph.  They keep the unadorned reason.
-- ============================================================================

-- The reason text a statement fails with, under a given identity, reduced
-- the way test_graph.sql's GTEST_LOAD_ERR reduces it.
create procedure GSEC_LOAD_ERR (in usr varchar, in txt varchar)
{
  declare st, msg, tag varchar;
  declare mdta, rset any;
  declare pos int;
  st := '00000';
  msg := '';
  set_user_id (usr, 1);
  exec (txt, st, msg, vector (), 0, mdta, rset);
  if (st = '00000')
    return 'NOERROR';
  tag := 'failed to load graph: ';
  pos := strstr (msg, tag);
  if (pos is null)
    return 'OTHER:' || msg;
  return replace (subseq (msg, pos + length (tag)), ' ', '_');
}
;

-- gtest may read this graph, so that the load is what they reach and the
-- graph-level check is not what stops them.
DB.DBA.RDF_GRAPH_USER_PERMS_SET ('urn:graph:sec:tbl', 'gtest', 15);
commit work;

-- Pull the table out from under the graph dba loaded in K.20.
DROP TABLE DB.DBA.GSEC_TBL;

-- Y.1: dba is told which table went missing
select case when strstr (GSEC_LOAD_ERR ('dba',
    'select GRAPH_PAGERANK (''urn:graph:sec:alice'', ''urn:graph:sec:tbl'')'),
  'GSEC_TBL') is null then 'UNNAMED' else 'NAMED' end;
ECHO BOTH ": Y1 dba is told the backing table = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] NAMED "PASSED" "***FAILED";

-- Y.2: gtest, who may read the graph, is not told what backs it
select case when strstr (GSEC_LOAD_ERR ('gtest',
    'select GRAPH_PAGERANK (''urn:graph:sec:alice'', ''urn:graph:sec:tbl'')'),
  'GSEC_TBL') is null then 'WITHHELD' else 'LEAKED' end;
ECHO BOTH ": Y2 non-dba is not told the backing table = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] WITHHELD "PASSED" "***FAILED";

-- Y.3: ... and gets no SQLSTATE of the internal query either
select case when strstr (GSEC_LOAD_ERR ('gtest',
    'select GRAPH_PAGERANK (''urn:graph:sec:alice'', ''urn:graph:sec:tbl'')'),
  'SQ200') is null then 'WITHHELD' else 'LEAKED' end;
ECHO BOTH ": Y3 non-dba is not told the internal SQLSTATE = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] WITHHELD "PASSED" "***FAILED";

-- Y.4: what they do get is still the plain reason, not silence
select GSEC_LOAD_ERR ('gtest',
  'select GRAPH_PAGERANK (''urn:graph:sec:alice'', ''urn:graph:sec:tbl'')');
ECHO BOTH ": Y4 non-dba still gets the reason = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] I/O_error "PASSED" "***FAILED";

-- The registration is process-wide; forget it rather than leave it dead.
select cast (GRAPH_UNLOAD_TABLE ('urn:graph:sec:tbl') as integer);
ECHO BOTH ": Y5 table source forgotten = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";

-- ============================================================================
-- Group AA: a transient graph belongs to the session that made it
--
-- A table-sourced graph can be process-wide because the table's own
-- SELECT permission is re-checked on every reload -- the registry holds a
-- name, and reading it asks SQL the access question again.  An
-- edge-sourced graph holds the rows themselves, so there is no second
-- question to ask and ownership has to be the check.
--
-- Without it, one session's federated result would be readable by anyone
-- who guessed the IRI, and two sessions using the same obvious name
-- (<urn:tmp>) would overwrite each other's data.  Both are asserted
-- below; AA.2 is the leak and AA.3 is the collision.
-- (Group letters are unique suite-wide; Z is taken by test_graph.sql, so
-- this file continues at AA.)
-- ============================================================================

-- Run a statement as a given user and report its first value, so a read
-- that should find nothing is distinguishable from one that errors.
create procedure GSEC_AS (in usr varchar, in txt varchar)
{
  declare st, msg varchar;
  declare mdta, rset any;
  st := '00000';
  msg := '';
  set_user_id (usr, 1);
  exec (txt, st, msg, vector (), 0, mdta, rset);
  if (st <> '00000')
    return 'STATE:' || st;
  if (isarray (rset) and length (rset) > 0 and isarray (rset[0]) and length (rset[0]) > 0)
    return cast (rset[0][0] as varchar);
  return 'NOROWS';
}
;

-- dba loads a two-edge transient graph under a deliberately obvious name
select GRAPH_LOAD_EDGES ('urn:aa:tmp', 'urn:aa:e',
  vector (vector (iri_to_id ('urn:aa:x'), iri_to_id ('urn:aa:y')),
          vector (iri_to_id ('urn:aa:y'), iri_to_id ('urn:aa:z'))));
ECHO BOTH ": AA1 dba loads a transient graph = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";

-- AA.2: another user must not be able to read it by naming the IRI
select GSEC_AS ('gtest',
  'select GRAPH_PAGERANK (''urn:aa:x'', ''urn:aa:tmp'', ''urn:aa:e'')');
ECHO BOTH ": AA2 another user reading it = " $LAST[1] "\n";
ECHO BOTH $IF $NEQ $LAST[1] NOROWS "PASSED" "***FAILED";

-- AA.3: and may make their own under the same name without disturbing it
select GSEC_AS ('gtest',
  'select GRAPH_LOAD_EDGES (''urn:aa:tmp'', ''urn:aa:e'', vector (vector (iri_to_id (''urn:aa:p''), iri_to_id (''urn:aa:q''))))');
ECHO BOTH ": AA3 another user loads their own = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";

-- AA.4: dba's graph is still dba's, with dba's two edges
select cast (GRAPH_DEGREE_CENTRALITY ('urn:aa:y', 'urn:aa:tmp', 'urn:aa:e', 0) as integer);
ECHO BOTH ": AA4 dba's graph is undisturbed, degree(y) = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";

-- AA.5: a non-dba may create and use one -- it is their own data, so this
-- needs no DBA gate, only isolation
select GSEC_AS ('gtest',
  'select GRAPH_DEGREE_CENTRALITY (''urn:aa:p'', ''urn:aa:tmp'', ''urn:aa:e'', 2)');
ECHO BOTH ": AA5 non-dba uses their own transient graph = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";

select GRAPH_UNLOAD_EDGES ('urn:aa:tmp');
ECHO BOTH ": AA6 dba unloads their own = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";

-- AA.7: and a transient graph must not outlive an HTTP request.
--
-- This is the case the connection key does NOT cover on its own.  The
-- /sparql endpoint answers from a connection pool, and every
-- unauthenticated request runs as the same SPARQL user, so
-- (connection, user) is the same tuple for requests that have nothing to
-- do with each other.  Without a reset at the request boundary, one
-- caller's transient graph is readable by the next caller who names the
-- IRI -- and GRAPH_SHORTEST_PATH hands back node IRIs, so that is
-- disclosure of the data itself, not merely of its shape.
--
-- Two real requests against our own endpoint, because that is the only
-- way to reproduce the pooling.

create procedure GSEC_HTTP_SPARQL (in q varchar)
{
  declare url varchar;
  url := sprintf ('http://localhost:%s/sparql?query=%U&format=text%%2Fhtml',
                  server_http_port (), q);
  return http_get (url);
}
;

-- request one makes the graph
select case when GSEC_HTTP_SPARQL (
  'SELECT (bif:GRAPH_LOAD_EDGES(''urn:aa:http'', ''urn:aa:httpe'', ' ||
  'bif:vector(bif:vector(bif:iri_to_id(''urn:aa:h1''), bif:iri_to_id(''urn:aa:h2'')), ' ||
  'bif:vector(bif:iri_to_id(''urn:aa:h2''), bif:iri_to_id(''urn:aa:h3'')))) AS ?n) WHERE { }')
  like '%2%' then 'MADE' else 'NOTMADE' end;
ECHO BOTH ": AA7 request one makes a transient graph = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] MADE "PASSED" "***FAILED";

-- request two must not find it
select case when GSEC_HTTP_SPARQL (
  'SELECT (bif:GRAPH_DEGREE_CENTRALITY(''urn:aa:h2'', ''urn:aa:http'', ''urn:aa:httpe'', 0) AS ?d) WHERE { }')
  like '%Error%' then 'ISOLATED' else 'LEAKED' end;
ECHO BOTH ": AA8 a later request reading it = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] ISOLATED "PASSED" "***FAILED";

-- ============================================================================
-- Group AW: a graph answered from the cache still needs the right to read
-- the quad store
-- ============================================================================
--
-- The loader reads DB.DBA.RDF_QUAD with SQL compiled for the caller.  So a
-- user who may not read the quad store at all -- no SPARQL_SELECT, no grant
-- on the table -- is refused when it is the one that loads a graph.  But the
-- snapshot cache is shared, and a cached graph is not loaded.  Once dba had
-- read a graph, that user was answered from it: scores, and paths as
-- readable IRIs.  A graph read from a table has the same gap, filed
-- separately: cached-table-graph-skips-the-tables-select-permission.
--
-- gtest3 has no grants at all.  Like any unconfigured user (K.15) it may read
-- every graph IRI, so the quad store's own permissions are all that can
-- refuse it.  gtest2 holds SPARQL_SELECT and is the control: it must still be
-- answered from the cache.  gtest3 was made for K.21.
SPARQL PREFIX aw: <urn:aw:> PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
INSERT INTO GRAPH <urn:aw:g> {
  aw:a aw:p aw:b . aw:b aw:p aw:c . aw:d aw:p aw:c .
  [] rdf:subject aw:a ; rdf:predicate aw:p ; rdf:object aw:b ; aw:w 1.0 .
  [] rdf:subject aw:b ; rdf:predicate aw:p ; rdf:object aw:c ; aw:w 2.0 .
  [] rdf:subject aw:d ; rdf:predicate aw:p ; rdf:object aw:c ; aw:w 4.0 .
};
COMMIT WORK;

-- AW.1 - AW.3: controls.  The quad store refuses gtest3 in SQL and in SPARQL,
-- and so does the loader while gtest3 is the first to ask.
select GRAPH_SEC_VALUE ('gtest3', 'select count (*) from DB.DBA.RDF_QUAD');
ECHO BOTH ": AW1 gtest3 reads RDF_QUAD in SQL = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] STATE:42000 "PASSED" "***FAILED";

select GRAPH_SEC_VALUE ('gtest3', 'sparql select count (*) from <urn:aw:g> where { ?s ?p ?o }');
ECHO BOTH ": AW2 gtest3 reads the graph in SPARQL = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] STATE:42000 "PASSED" "***FAILED";

select GRAPH_SEC_VALUE ('gtest3',
  'select cast (GRAPH_DEGREE_CENTRALITY (''urn:aw:b'', ''urn:aw:g'', ''urn:aw:p'') as integer)');
ECHO BOTH ": AW3 gtest3, degree(b), not yet cached = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] STATE:42006 "PASSED" "***FAILED";

-- AW.4 - AW.6: dba asks, which leaves the graph and its weights in the cache
select GRAPH_SEC_VALUE ('dba',
  'select cast (GRAPH_DEGREE_CENTRALITY (''urn:aw:b'', ''urn:aw:g'', ''urn:aw:p'') as integer)');
ECHO BOTH ": AW4 dba, degree(b) = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";

select GRAPH_SEC_VALUE ('dba',
  'select aref (GRAPH_SHORTEST_PATH (''urn:aw:a'', ''urn:aw:c'', ''urn:aw:g'', ''urn:aw:p''), 0)');
ECHO BOTH ": AW5 dba, the path from a starts at = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] "urn:aw:a" "PASSED" "***FAILED";

-- one hop of 1 and one of 2
select GRAPH_SEC_VALUE ('dba',
  'select cast (GRAPH_SHORTEST_PATH_LENGTH_WEIGHTED (''urn:aw:a'', ''urn:aw:c'', ''urn:aw:g'', ''urn:aw:p'', iri_to_id (''urn:aw:w''), 0) as integer)');
ECHO BOTH ": AW6 dba, weighted a to c = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] 3 "PASSED" "***FAILED";

-- AW.7 - AW.9: the cached graph, its paths and its weights must refuse
-- gtest3, as the loader does
select GRAPH_SEC_VALUE ('gtest3',
  'select cast (GRAPH_DEGREE_CENTRALITY (''urn:aw:b'', ''urn:aw:g'', ''urn:aw:p'') as integer)');
ECHO BOTH ": AW7 gtest3, degree(b), cached = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] STATE:42006 "PASSED" "***FAILED";

select GRAPH_SEC_VALUE ('gtest3',
  'select aref (GRAPH_SHORTEST_PATH (''urn:aw:a'', ''urn:aw:c'', ''urn:aw:g'', ''urn:aw:p''), 0)');
ECHO BOTH ": AW8 gtest3, the path from a, cached = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] STATE:42006 "PASSED" "***FAILED";

select GRAPH_SEC_VALUE ('gtest3',
  'select cast (GRAPH_SHORTEST_PATH_LENGTH_WEIGHTED (''urn:aw:a'', ''urn:aw:c'', ''urn:aw:g'', ''urn:aw:p'', iri_to_id (''urn:aw:w''), 0) as integer)');
ECHO BOTH ": AW9 gtest3, weighted, cached = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] STATE:42006 "PASSED" "***FAILED";

-- AW.10 - AW.12: and must still answer gtest2, which may read the quad store
select GRAPH_SEC_VALUE ('gtest2',
  'select cast (GRAPH_DEGREE_CENTRALITY (''urn:aw:b'', ''urn:aw:g'', ''urn:aw:p'') as integer)');
ECHO BOTH ": AW10 gtest2, degree(b), cached = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";

select GRAPH_SEC_VALUE ('gtest2',
  'select aref (GRAPH_SHORTEST_PATH (''urn:aw:a'', ''urn:aw:c'', ''urn:aw:g'', ''urn:aw:p''), 0)');
ECHO BOTH ": AW11 gtest2, the path from a, cached = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] "urn:aw:a" "PASSED" "***FAILED";

select GRAPH_SEC_VALUE ('gtest2',
  'select cast (GRAPH_SHORTEST_PATH_LENGTH_WEIGHTED (''urn:aw:a'', ''urn:aw:c'', ''urn:aw:g'', ''urn:aw:p'', iri_to_id (''urn:aw:w''), 0) as integer)');
ECHO BOTH ": AW12 gtest2, weighted, cached = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] 3 "PASSED" "***FAILED";

-- ============================================================================
-- Group AT: a graph read from a SQL table needs SELECT on that table, cached
-- or not
-- ============================================================================
--
-- GRAPH_LOAD_TABLE reads the table as its caller, but a cached table graph is
-- not loaded again, so a user without SELECT on the table was answered once
-- dba had warmed the cache.  gtest3 has no grants, so no SPARQL_SELECT.
create table DB.DBA.GSEC_AT (S IRI_ID, O IRI_ID);
GRANT SELECT ON DB.DBA.GSEC_AT TO SPARQL_SELECT;
insert into DB.DBA.GSEC_AT (S, O) values (iri_to_id ('urn:at:a'), iri_to_id ('urn:at:b'));
insert into DB.DBA.GSEC_AT (S, O) values (iri_to_id ('urn:at:b'), iri_to_id ('urn:at:c'));
commit work;
GRAPH_LOAD_TABLE ('urn:at:g', 'urn:at:p', 'DB.DBA.GSEC_AT');

-- AT.1: control, and it puts the graph in the cache
select cast (GRAPH_DEGREE_CENTRALITY ('urn:at:b', 'urn:at:g', 'urn:at:p', 2) as integer);
ECHO BOTH ": AT1 dba out-degree(b) of the table graph = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";

-- AT.2 - AT.3: the cached graph and its paths refuse gtest3
select GRAPH_SEC_VALUE ('gtest3',
  'select cast (GRAPH_DEGREE_CENTRALITY (''urn:at:b'', ''urn:at:g'', ''urn:at:p'', 2) as integer)');
ECHO BOTH ": AT2 gtest3, out-degree(b), cached table graph = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] STATE:42006 "PASSED" "***FAILED";

select GRAPH_SEC_VALUE ('gtest3',
  'select aref (GRAPH_SHORTEST_PATH (''urn:at:a'', ''urn:at:c'', ''urn:at:g'', ''urn:at:p''), 0)');
ECHO BOTH ": AT3 gtest3, the path from a, cached table graph = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] STATE:42006 "PASSED" "***FAILED";

-- AT.4: with SPARQL_SELECT, which the table is granted to, gtest3 is
-- answered from the same entry
GRANT SPARQL_SELECT TO "gtest3";
select GRAPH_SEC_VALUE ('gtest3',
  'select cast (GRAPH_DEGREE_CENTRALITY (''urn:at:b'', ''urn:at:g'', ''urn:at:p'', 2) as integer)');
ECHO BOTH ": AT4 gtest3 with SPARQL_SELECT, out-degree(b) = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
REVOKE SPARQL_SELECT FROM "gtest3";

-- ============================================================================
-- Group AZ: registering a table as a graph's source is for DBA only
-- ============================================================================
--
-- The table registry is shared by every session: once a graph IRI is
-- registered against a table, every caller's analytics on that IRI read
-- the table instead of the quad store.  Registering and unregistering are
-- therefore administration, like GRAPH_SET_LIMIT, and must not be open to
-- an ordinary user or to the SPARQL endpoint.  gtest has SPARQL_SELECT and
-- the GSEC_AT table is granted to it, so only the missing DBA check let
-- these through.

-- AZ.1: gtest may not register a table under a graph IRI
select GRAPH_SEC_STATE ('gtest',
  'select GRAPH_LOAD_TABLE (''urn:az:g'', ''urn:at:p'', ''DB.DBA.GSEC_AT'')');
ECHO BOTH ": AZ1 gtest registers a table source, state = " $LAST[1] "\n";
ECHO BOTH $IF $NEQ $LAST[1] 00000 "PASSED" "***FAILED";

-- AZ.2: nor drop the registration dba made in Group AT
select GRAPH_SEC_STATE ('gtest', 'select GRAPH_UNLOAD_TABLE (''urn:at:g'')');
ECHO BOTH ": AZ2 gtest unregisters dba's table source, state = " $LAST[1] "\n";
ECHO BOTH $IF $NEQ $LAST[1] 00000 "PASSED" "***FAILED";

-- AZ.3: and dba's registration still answers afterwards
select cast (GRAPH_DEGREE_CENTRALITY ('urn:at:b', 'urn:at:g', 'urn:at:p', 2) as integer);
ECHO BOTH ": AZ3 dba out-degree(b) of the table graph afterwards = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";

-- AZ.4: SPARQL refuses both names at compile time, as it does other
-- functions that change server state
select GRAPH_SEC_STATE ('gtest',
  'SPARQL SELECT (bif:GRAPH_LOAD_TABLE (''urn:az:g2'', ''urn:at:p'', ''DB.DBA.GSEC_AT'') AS ?n) WHERE { }');
ECHO BOTH ": AZ4 bif:GRAPH_LOAD_TABLE from SPARQL, state = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] 37000 "PASSED" "***FAILED";

select GRAPH_SEC_STATE ('gtest',
  'SPARQL SELECT (bif:GRAPH_UNLOAD_TABLE (''urn:at:g'') AS ?n) WHERE { }');
ECHO BOTH ": AZ5 bif:GRAPH_UNLOAD_TABLE from SPARQL, state = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] 37000 "PASSED" "***FAILED";

-- AZ.6: dba still registers from SQL
select GRAPH_LOAD_TABLE ('urn:az:g3', 'urn:at:p', 'DB.DBA.GSEC_AT');
ECHO BOTH ": AZ6 dba registers a table source = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";
select GRAPH_UNLOAD_TABLE ('urn:az:g3');

ECHO BOTH "COMPLETED: graph analytics security test suite\n";
