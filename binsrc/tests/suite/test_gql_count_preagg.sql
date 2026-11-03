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
--  GQL for Virtuoso - count pre-aggregation (__gql_count_preagg)
--
--  With registry __gql_count_preagg 'on', a query that returns only
--  count(*) counts the parts of its pattern that hang off the rest at one
--  node first -- each in a GROUP BY sub-select -- and sums the products:
--
--    C  each shape the rule takes gives the same count with the flag off
--       and on, and with it on is translated with the sub-selects -- and
--       only the leaves the rule takes are counted first;
--    Z  a match with no rows still counts 0;
--    R  each shape the rule refuses translates byte for byte as with the
--       flag off;
--    K  the translation caches keep the two translations apart;
--    T  the count's result column is declared as count(*)'s is.
--
--  Run via isql: isql <host>:<port> dba dba test_gql_count_preagg.sql
--

ECHO "STARTED: GQL count pre-aggregation tests\n";

SET ARGV[0] 0;
SET ARGV[1] 0;

-- Five people; KNOWS stored once per pair: p1->p2, p2->p3, p3->p1 (a
-- triangle), p3->p4, p4->p5.  Interests: p1 t1; p3 t1, t2; p4 t3 and x9
-- (x9 is no Tag).  Messages: m1 (post, by p1, tags t1 t2, liked by p2 and
-- p3), m2 (comment on m1, by p2, tag t1, liked by p4), m3 (comment on m1,
-- by p3, tag t3), m4 (post, by p4, no tag, liked by p5).
sparql clear graph <urn:gql:cp>;
sparql prefix o: <http://localhost:8890/gql/ontology/>
insert data { graph <urn:gql:cp> {
  <urn:cp:p1> a o:Person . <urn:cp:p2> a o:Person . <urn:cp:p3> a o:Person .
  <urn:cp:p4> a o:Person . <urn:cp:p5> a o:Person .
  <urn:cp:p1> o:KNOWS <urn:cp:p2> . <urn:cp:p2> o:KNOWS <urn:cp:p3> .
  <urn:cp:p3> o:KNOWS <urn:cp:p1> . <urn:cp:p3> o:KNOWS <urn:cp:p4> .
  <urn:cp:p4> o:KNOWS <urn:cp:p5> .
  <urn:cp:t1> a o:Tag . <urn:cp:t2> a o:Tag . <urn:cp:t3> a o:Tag .
  <urn:cp:t1> o:name "one" .
  <urn:cp:p1> o:HAS_INTEREST <urn:cp:t1> .
  <urn:cp:p3> o:HAS_INTEREST <urn:cp:t1> . <urn:cp:p3> o:HAS_INTEREST <urn:cp:t2> .
  <urn:cp:p4> o:HAS_INTEREST <urn:cp:t3> . <urn:cp:p4> o:HAS_INTEREST <urn:cp:x9> .
  <urn:cp:m1> a o:Message , o:Post . <urn:cp:m2> a o:Message , o:Comment .
  <urn:cp:m3> a o:Message , o:Comment . <urn:cp:m4> a o:Message , o:Post .
  <urn:cp:m1> o:HAS_CREATOR <urn:cp:p1> . <urn:cp:m2> o:HAS_CREATOR <urn:cp:p2> .
  <urn:cp:m3> o:HAS_CREATOR <urn:cp:p3> . <urn:cp:m4> o:HAS_CREATOR <urn:cp:p4> .
  <urn:cp:m1> o:HAS_TAG <urn:cp:t1> . <urn:cp:m1> o:HAS_TAG <urn:cp:t2> .
  <urn:cp:m2> o:HAS_TAG <urn:cp:t1> . <urn:cp:m3> o:HAS_TAG <urn:cp:t3> .
  <urn:cp:m2> o:REPLY_OF <urn:cp:m1> . <urn:cp:m3> o:REPLY_OF <urn:cp:m1> .
  <urn:cp:p2> o:LIKES <urn:cp:m1> . <urn:cp:p3> o:LIKES <urn:cp:m1> .
  <urn:cp:p4> o:LIKES <urn:cp:m2> . <urn:cp:p5> o:LIKES <urn:cp:m4> .
} };

-- The count _q gives with the flag set to _flag, or -1 when it raises;
-- the flag is left off.
create procedure DB.DBA.GQL_CP_T_COUNT (in _q varchar, in _flag varchar) returns any
{
  declare _r any;
  declare exit handler for sqlstate '*' { registry_set ('__gql_count_preagg', 'off'); return -1; };
  registry_set ('__gql_count_preagg', _flag);
  _r := DB.DBA.GQL_RUN (_q, 'urn:gql:cp');
  registry_set ('__gql_count_preagg', 'off');
  if (not isarray (_r) or length (_r) <> 1)
    return -2;
  return aref (aref (_r, 0), 0);
}
;

-- The translation of _q with the flag set to _flag; the flag is left off.
create procedure DB.DBA.GQL_CP_T_SPARQL (in _q varchar, in _flag varchar) returns varchar
{
  declare _s varchar;
  declare exit handler for sqlstate '*' { registry_set ('__gql_count_preagg', 'off'); return __SQL_MESSAGE; };
  registry_set ('__gql_count_preagg', _flag);
  _s := cast (DB.DBA.GQL_TO_SPARQL (_q, 'urn:gql:cp') as varchar);
  registry_set ('__gql_count_preagg', 'off');
  return _s;
}
;

-- 1 when _q counts _n with the flag off and on, and with it on is
-- translated with count sub-selects.
create procedure DB.DBA.GQL_CP_T_REWRITTEN (in _q varchar, in _n integer) returns integer
{
  declare _s varchar;
  if (DB.DBA.GQL_CP_T_COUNT (_q, 'off') <> _n or DB.DBA.GQL_CP_T_COUNT (_q, 'on') <> _n)
    return 0;
  _s := DB.DBA.GQL_CP_T_SPARQL (_q, 'on');
  if (strstr (_s, 'GROUP BY') is null or strstr (_s, '?gql_cnt_') is null)
    return 0;
  return 1;
}
;

-- How many count sub-selects (GROUP BY) the translation of _q has with
-- the flag on.
create procedure DB.DBA.GQL_CP_T_LEAVES (in _q varchar) returns integer
{
  declare _s varchar;
  declare _n, _pos integer;
  _s := DB.DBA.GQL_CP_T_SPARQL (_q, 'on');
  _n := 0;
  _pos := 0;
  while (strstr (subseq (_s, _pos), 'GROUP BY') is not null)
    {
      _pos := _pos + strstr (subseq (_s, _pos), 'GROUP BY') + 8;
      _n := _n + 1;
    }
  return _n;
}
;

-- The type the result column of _q's translation is declared with, with
-- the flag set to _flag -- what a client is told, and gets the value as.
create procedure DB.DBA.GQL_CP_T_DTP (in _q varchar, in _flag varchar) returns integer
{
  declare _st, _msg, _s varchar;
  declare _meta, _data any;
  _s := DB.DBA.GQL_CP_T_SPARQL (_q, _flag);
  _st := '00000';
  _msg := '';
  exec (_s, _st, _msg, vector (), 0, _meta, _data);
  if (_st <> '00000')
    return -1;
  return aref (aref (aref (_meta, 0), 0), 1);
}
;

-- 1 when _q translates byte for byte the same with the flag off and on.
create procedure DB.DBA.GQL_CP_T_REFUSED (in _q varchar) returns integer
{
  if (DB.DBA.GQL_CP_T_SPARQL (_q, 'off') = DB.DBA.GQL_CP_T_SPARQL (_q, 'on'))
    return 1;
  return 0;
}
;

-- C1: a leaf beyond the last node the query refers to (q6): person c's
-- interests in a Tag.  By hand: 11.
select 99;
select DB.DBA.GQL_CP_T_REWRITTEN ('MATCH (a:Person)-[:KNOWS]-(b:Person)-[:KNOWS]-(c:Person)-[:HAS_INTEREST]->(t:Tag) WHERE a <> c RETURN count(*) AS n', 11);
ECHO $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": C1 a leaf beyond the last referenced node is counted first\n";

-- C2: the same with a negated pattern predicate on the core (q9).  By hand: 5.
select 99;
select DB.DBA.GQL_CP_T_REWRITTEN ('MATCH (a:Person)-[:KNOWS]-(b:Person)-[:KNOWS]-(c:Person)-[:HAS_INTEREST]->(t:Tag) WHERE NOT (a)-[:KNOWS]-(c) AND a <> c RETURN count(*) AS n', 5);
ECHO $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": C2 a leaf beside NOT on the core nodes\n";

-- C3: two comma patterns that meet the rest at one node (q4).  m1: 2 tags
-- x 1 creator x 2 likers x 2 replies.  By hand: 8.
select 99;
select DB.DBA.GQL_CP_T_REWRITTEN ('MATCH (:Tag)<-[:HAS_TAG]-(m:Message)-[:HAS_CREATOR]->(cr:Person), (m)<-[:LIKES]-(l:Person), (m)<-[:REPLY_OF]-(cm:Comment) RETURN count(*) AS n', 8);
ECHO $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": C3 comma patterns that meet the rest at one node are counted first\n";

-- C3b: only those two; the first pattern -- tag and creator -- is joined as
-- written (counting a cheap leaf over the whole graph made q7 2x slower).
select 99;
select DB.DBA.GQL_CP_T_LEAVES ('MATCH (:Tag)<-[:HAS_TAG]-(m:Message)-[:HAS_CREATOR]->(cr:Person), (m)<-[:LIKES]-(l:Person), (m)<-[:REPLY_OF]-(cm:Comment) RETURN count(*) AS n');
ECHO $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": C3b the first pattern is not split: count sub-selects " $LAST[1] "\n";

-- C4: OPTIONAL MATCH leaves (q7); a message with no likes or no replies
-- still counts once.  m1 8, m2 1, m3 1.  By hand: 10.
select 99;
select DB.DBA.GQL_CP_T_REWRITTEN ('MATCH (:Tag)<-[:HAS_TAG]-(m:Message)-[:HAS_CREATOR]->(cr:Person) OPTIONAL MATCH (m)<-[:LIKES]-(l:Person) OPTIONAL MATCH (m)<-[:REPLY_OF]-(cm:Comment) RETURN count(*) AS n', 10);
ECHO $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": C4 OPTIONAL MATCH leaves weigh a row with no match as 1\n";

select 99;
select DB.DBA.GQL_CP_T_LEAVES ('MATCH (:Tag)<-[:HAS_TAG]-(m:Message)-[:HAS_CREATOR]->(cr:Person) OPTIONAL MATCH (m)<-[:LIKES]-(l:Person) OPTIONAL MATCH (m)<-[:REPLY_OF]-(cm:Comment) RETURN count(*) AS n');
ECHO $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": C4b only the OPTIONAL leaves are counted first: count sub-selects " $LAST[1] "\n";

-- C5: an undirected edge inside the leaf.  Each stored edge a->c, times c's
-- neighbours: 2 + 3 + 2 + 2 + 1.  By hand: 10.
select 99;
select DB.DBA.GQL_CP_T_REWRITTEN ('MATCH (a:Person)-[:KNOWS]->(c:Person)-[:KNOWS]-(d:Person) WHERE a <> c RETURN count(*) AS n', 10);
ECHO $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": C5 an undirected edge inside a leaf\n";

-- Z1: no match at all still counts 0, not NULL.
select 99;
select DB.DBA.GQL_CP_T_COUNT ('MATCH (a:Nope)-[:KNOWS]-(b:Person)-[:KNOWS]-(c:Person)-[:HAS_INTEREST]->(t:Tag) WHERE a <> c RETURN count(*) AS n', 'on');
ECHO $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": Z1 a rewritten count over no rows is 0: " $LAST[1] "\n";

-- R1-R10: refused -- the leaf's node is used elsewhere, the leaf has a
-- quantified edge, an edge or path variable, the RETURN is more than
-- count(*), there is no leaf (a chain), or an OPTIONAL hangs off a node only
-- another OPTIONAL binds.
select 99;
select DB.DBA.GQL_CP_T_REFUSED ('MATCH (a:Person)-[:KNOWS]-(b:Person)-[:KNOWS]-(c:Person)-[:HAS_INTEREST]->(t:Tag) WHERE a <> c AND t.name = ''one'' RETURN count(*) AS n');
ECHO $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": R1 a leaf node used in WHERE is not counted first\n";

select 99;
select DB.DBA.GQL_CP_T_REFUSED ('MATCH (a:Person)-[:KNOWS]-(c:Person)-[:HAS_INTEREST]->(t:Tag) MATCH (t)<-[:HAS_TAG]-(m:Message)-[:HAS_CREATOR]->(a) WHERE a <> c RETURN count(*) AS n');
ECHO $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": R2 a leaf node used in another MATCH is not counted first\n";

select 99;
select DB.DBA.GQL_CP_T_REFUSED ('MATCH (a:Person)-[:KNOWS]-(c:Person)-[:HAS_INTEREST]->(t:Tag) WHERE a <> c AND EXISTS { MATCH (t)<-[:HAS_TAG]-(:Message) } RETURN count(*) AS n');
ECHO $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": R3 a leaf node used inside EXISTS is not counted first\n";

select 99;
select DB.DBA.GQL_CP_T_REFUSED ('MATCH (a:Person)-[:KNOWS]-(c:Person)-[:KNOWS*]->(d:Person) WHERE a <> c RETURN count(*) AS n');
ECHO $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": R4 a leaf with a quantified edge is not counted first\n";

select 99;
select DB.DBA.GQL_CP_T_REFUSED ('MATCH (a:Person)-[:KNOWS]-(c:Person)-[i:HAS_INTEREST]->(t:Tag) WHERE a <> c RETURN count(*) AS n');
ECHO $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": R5 a leaf with an edge variable is not counted first\n";

select 99;
select DB.DBA.GQL_CP_T_REFUSED ('MATCH p = (a:Person)-[:KNOWS]-(c:Person)-[:HAS_INTEREST]->(t:Tag) WHERE a <> c RETURN count(*) AS n');
ECHO $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": R6 a path with a path variable is not split\n";

select 99;
select DB.DBA.GQL_CP_T_REFUSED ('MATCH (a:Person)-[:KNOWS]-(c:Person)-[:HAS_INTEREST]->(t:Tag) WHERE a <> c RETURN a, count(*) AS n');
ECHO $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": R7 a RETURN with more than count(*) is not rewritten\n";

select 99;
select DB.DBA.GQL_CP_T_REFUSED ('MATCH (a:Person)-[:KNOWS]-(c:Person)-[:HAS_INTEREST]->(t:Tag) WHERE a <> c RETURN count(DISTINCT t) AS n');
ECHO $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": R8 count(DISTINCT x) is not rewritten\n";

select 99;
select DB.DBA.GQL_CP_T_REFUSED ('MATCH (:Person)-[:KNOWS]->(:Person)-[:HAS_INTEREST]->(:Tag) RETURN count(*) AS n');
ECHO $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": R9 a chain with no referenced node is not split\n";

select 99;
select DB.DBA.GQL_CP_T_REFUSED ('MATCH (a:Person) OPTIONAL MATCH (a)-[:KNOWS]->(b:Person) OPTIONAL MATCH (b)-[:HAS_INTEREST]->(t:Tag) RETURN count(*) AS n');
ECHO $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": R10 an OPTIONAL hanging off an OPTIONAL-only node is not counted first\n";

-- R11: a tail whose cut would leave a single node in the core -- its count
-- would run over the whole graph for a filtered core.
select 99;
select DB.DBA.GQL_CP_T_REFUSED ('MATCH (a:Person)-[:HAS_INTEREST]->(t:Tag) WHERE a <> iri(''urn:cp:p1'') RETURN count(*) AS n');
ECHO $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": R11 a cut that leaves one node is not made\n";

-- K1, K2: the flag is part of the translation-cache key, so turning it on
-- for a text already translated with it off gives the rewritten text, not
-- the cached one -- through the prepared path, which caches.
create procedure DB.DBA.GQL_CP_T_CACHE () returns integer
{
  declare _q, _s_off, _s_on varchar;
  declare _execv any;
  declare exit handler for sqlstate '*' { registry_set ('__gql_count_preagg', 'off'); return -1; };
  _q := 'MATCH (a:Person)-[:KNOWS]-(b:Person)-[:KNOWS]-(c:Person)-[:HAS_INTEREST]->(t:Tag) WHERE a <> c RETURN count(*) AS n';
  registry_set ('__gql_count_preagg', 'off');
  DB.DBA.GQL_PREPARED_PLAN (_q, 'urn:gql:cp', vector (), _s_off, _execv);
  registry_set ('__gql_count_preagg', 'on');
  DB.DBA.GQL_PREPARED_PLAN (_q, 'urn:gql:cp', vector (), _s_on, _execv);
  registry_set ('__gql_count_preagg', 'off');
  if (strstr (_s_off, '?gql_cnt_') is null and strstr (_s_on, '?gql_cnt_') is not null)
    return 1;
  return 0;
}
;

select 99;
select DB.DBA.GQL_CP_T_CACHE ();
ECHO $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": K1 toggling the flag does not reuse a cached translation\n";

select 99;
select case when DB.DBA.GQL_TRANS_CACHE_KEY ('inline', 'q', 'g') = DB.DBA.GQL_TRANS_CACHE_KEY ('inline', 'q', 'g') then 1 else 0 end;
ECHO $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": K2 the cache key is stable for one flag value\n";

-- T1, T2: the count column is declared as count(*)'s is, INTEGER -- also
-- when the rest of the pattern has a UNION (undirected edges), where the
-- sum was declared ANY and reached ODBC clients as a string.
select 99;
select case when DB.DBA.GQL_CP_T_DTP ('MATCH (a:Person)-[:KNOWS]-(b:Person)-[:KNOWS]-(c:Person)-[:HAS_INTEREST]->(t:Tag) WHERE a <> c RETURN count(*) AS n', 'on')
  = DB.DBA.GQL_CP_T_DTP ('MATCH (a:Person)-[:KNOWS]-(b:Person)-[:KNOWS]-(c:Person)-[:HAS_INTEREST]->(t:Tag) WHERE a <> c RETURN count(*) AS n', 'off') then 1 else 0 end;
ECHO $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": T1 a rewritten count beside a UNION is declared as count(*) is\n";

select 99;
select case when DB.DBA.GQL_CP_T_DTP ('MATCH (:Tag)<-[:HAS_TAG]-(m:Message)-[:HAS_CREATOR]->(cr:Person), (m)<-[:LIKES]-(l:Person), (m)<-[:REPLY_OF]-(cm:Comment) RETURN count(*) AS n', 'on')
  = DB.DBA.GQL_CP_T_DTP ('MATCH (:Tag)<-[:HAS_TAG]-(m:Message)-[:HAS_CREATOR]->(cr:Person), (m)<-[:LIKES]-(l:Person), (m)<-[:REPLY_OF]-(cm:Comment) RETURN count(*) AS n', 'off') then 1 else 0 end;
ECHO $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO ": T2 a rewritten count with no UNION is declared as count(*) is\n";

registry_set ('__gql_count_preagg', 'off');
sparql clear graph <urn:gql:cp>;

ECHO "COMPLETED WITH " $ARGV[0] " FAILED, " $ARGV[1] " PASSED: GQL count pre-aggregation tests\n";
