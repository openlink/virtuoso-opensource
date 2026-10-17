--
--  tsec_rdf_star_graph_security.sql
--
--  The RDF 1.2 triple term helpers must honour graph-level security.
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

echo BOTH "STARTED: RDF 1.2 triple term helpers and graph-level security\n";

SET ARGV[0] 0;
SET ARGV[1] 0;

--
--  Setup, as dba: a user denied every private graph; a reification in a
--  private graph and one in a public graph; in the public graph, a note about
--  each reifier, so that a triple term pattern can reach both.
--
delete from DB.DBA.SYS_ROLE_GRANTS
  where GI_SUPER = (select U_ID from DB.DBA.SYS_USERS where U_NAME = 'TSEC_RDFSTAR')
     or GI_SUB = (select U_ID from DB.DBA.SYS_USERS where U_NAME = 'TSEC_RDFSTAR');
delete from DB.DBA.SYS_USERS where U_NAME = 'TSEC_RDFSTAR';
sparql clear graph <urn:tsec:rdfstar:private>;
sparql clear graph <urn:tsec:rdfstar:public>;

DB.DBA.USER_CREATE ('TSEC_RDFSTAR', 'TSEC_RDFSTAR', vector ('SQL_ENABLE', 1));
grant SPARQL_SELECT to "TSEC_RDFSTAR";
sparql insert data { graph <urn:tsec:rdfstar:private> {
  <urn:tsec:rdfstar:reif> <http://www.w3.org/1999/02/22-rdf-syntax-ns#reifies>
    <<( <urn:tsec:rdfstar:s> <urn:tsec:rdfstar:p> <urn:tsec:rdfstar:o> )>> } };
sparql insert data { graph <urn:tsec:rdfstar:public> {
  <urn:tsec:rdfstar:reif-pub> <http://www.w3.org/1999/02/22-rdf-syntax-ns#reifies>
    <<( <urn:tsec:rdfstar:ps> <urn:tsec:rdfstar:pp> <urn:tsec:rdfstar:po> )>> .
  <urn:tsec:rdfstar:reif> <urn:tsec:rdfstar:note> "about a private statement" .
  <urn:tsec:rdfstar:reif-pub> <urn:tsec:rdfstar:note> "about a public statement" } };
DB.DBA.RDF_GRAPH_GROUP_CREATE ('http://www.openlinksw.com/schemas/virtrdf#PrivateGraphs', 1);
DB.DBA.RDF_GRAPH_GROUP_INS ('http://www.openlinksw.com/schemas/virtrdf#PrivateGraphs', 'urn:tsec:rdfstar:private');
DB.DBA.RDF_DEFAULT_USER_PERMS_SET ('TSEC_RDFSTAR', 0, 1);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": setup STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

--
--  1. As dba, the private reification is there and the helpers read it.
--
select coalesce (DB.DBA.RDF_STAR_TT_GET_S ('urn:tsec:rdfstar:reif', null), 'NULL');
ECHO BOTH $IF $EQU $LAST[1] "urn:tsec:rdfstar:s" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": dba: SUBJECT of the private reifier = urn:tsec:rdfstar:s, got " $LAST[1] "\n";

select coalesce (max (t."s"), 'NULL') from (sparql select ?s where { << ?s <urn:tsec:rdfstar:p> ?o >> <urn:tsec:rdfstar:note> ?n }) t;
ECHO BOTH $IF $EQU $LAST[1] "urn:tsec:rdfstar:s" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": dba: triple term pattern over the public note binds the private subject, got " $LAST[1] "\n";

--
--  2. As a user denied the private graph.
--
RECONNECT TSEC_RDFSTAR;

select count (*) from (sparql select ?p ?o where { graph <urn:tsec:rdfstar:private> { <urn:tsec:rdfstar:reif> ?p ?o } }) t;
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": user: reading the private graph directly gives 0 rows, got " $LAST[1] "\n";

select coalesce (DB.DBA.RDF_STAR_TT_GET_S ('urn:tsec:rdfstar:reif', null), 'NULL');
ECHO BOTH $IF $EQU $LAST[1] "NULL" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": user: RDF_STAR_TT_GET_S of the private reifier = NULL, got " $LAST[1] "\n";

select coalesce (DB.DBA.RDF_STAR_TT_GET_P ('urn:tsec:rdfstar:reif', null, null), 'NULL');
ECHO BOTH $IF $EQU $LAST[1] "NULL" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": user: RDF_STAR_TT_GET_P of the private reifier = NULL, got " $LAST[1] "\n";

select coalesce (DB.DBA.RDF_STAR_TT_GET_O ('urn:tsec:rdfstar:reif', null), 'NULL');
ECHO BOTH $IF $EQU $LAST[1] "NULL" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": user: RDF_STAR_TT_GET_O of the private reifier = NULL, got " $LAST[1] "\n";

select coalesce (DB.DBA.RDF_STAR_REIFIER_TO_TRIPLE_IRI ('urn:tsec:rdfstar:reif'), 'NULL');
ECHO BOTH $IF $EQU $LAST[1] "NULL" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": user: RDF_STAR_REIFIER_TO_TRIPLE_IRI of the private reifier = NULL, got " $LAST[1] "\n";

select coalesce (DB.DBA.RDF_STAR_REIFIER_IRI ('urn:tsec:rdfstar:reif'), 'NULL');
ECHO BOTH $IF $EQU $LAST[1] "NULL" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": user: RDF_STAR_REIFIER_IRI of the private reifier = NULL, got " $LAST[1] "\n";

select DB.DBA.RDF_STAR_TT_CHECK ('urn:tsec:rdfstar:reif', 'urn:tsec:rdfstar:s', null, null);
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": user: RDF_STAR_TT_CHECK cannot confirm the private statement, got " $LAST[1] "\n";

select coalesce (max (t."x"), 'NULL') from (sparql select (SUBJECT(<urn:tsec:rdfstar:reif>) as ?x) {}) t;
ECHO BOTH $IF $EQU $LAST[1] "NULL" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": user: SPARQL SUBJECT() of the private reifier = NULL, got " $LAST[1] "\n";

select coalesce (max (t."s"), 'NULL') from (sparql select ?s where { << ?s <urn:tsec:rdfstar:p> ?o >> <urn:tsec:rdfstar:note> ?n }) t;
ECHO BOTH $IF $EQU $LAST[1] "NULL" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": user: triple term pattern over the public note does not bind the private subject, got " $LAST[1] "\n";

--
--  3. What the user may read still works.
--
select coalesce (DB.DBA.RDF_STAR_TT_GET_S ('urn:tsec:rdfstar:reif-pub', null), 'NULL');
ECHO BOTH $IF $EQU $LAST[1] "urn:tsec:rdfstar:ps" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": user: SUBJECT of the public reifier = urn:tsec:rdfstar:ps, got " $LAST[1] "\n";

select coalesce (max (t."x"), 'NULL') from (sparql select (PREDICATE(<urn:tsec:rdfstar:reif-pub>) as ?x) {}) t;
ECHO BOTH $IF $EQU $LAST[1] "urn:tsec:rdfstar:pp" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": user: SPARQL PREDICATE() of the public reifier = urn:tsec:rdfstar:pp, got " $LAST[1] "\n";

select coalesce (max (t."s"), 'NULL') from (sparql select ?s where { << ?s <urn:tsec:rdfstar:pp> ?o >> <urn:tsec:rdfstar:note> ?n }) t;
ECHO BOTH $IF $EQU $LAST[1] "urn:tsec:rdfstar:ps" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": user: triple term pattern over the public reification binds its subject, got " $LAST[1] "\n";

--
--  4. A lookup must not add to the IRI dictionary.
--
select case when iri_to_id_nosignal ('urn:tsec:rdfstar:never-interned', 0) is null then 'absent' else 'present' end;
ECHO BOTH $IF $EQU $LAST[1] "absent" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": the probe IRI is not in the dictionary beforehand, got " $LAST[1] "\n";

select coalesce (DB.DBA.RDF_STAR_TT_GET_S ('urn:tsec:rdfstar:never-interned', null), 'NULL');
select case when iri_to_id_nosignal ('urn:tsec:rdfstar:never-interned', 0) is null then 'absent' else 'present' end;
ECHO BOTH $IF $EQU $LAST[1] "absent" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": user: looking an unknown node up does not intern it, got " $LAST[1] "\n";

--
--  Cleanup, as dba.
--
RECONNECT dba;
DB.DBA.RDF_GRAPH_GROUP_DEL ('http://www.openlinksw.com/schemas/virtrdf#PrivateGraphs', 'urn:tsec:rdfstar:private');
DB.DBA.RDF_DEFAULT_USER_PERMS_DEL ('TSEC_RDFSTAR', 1);
sparql clear graph <urn:tsec:rdfstar:private>;
sparql clear graph <urn:tsec:rdfstar:public>;
delete from DB.DBA.SYS_ROLE_GRANTS
  where GI_SUPER = (select U_ID from DB.DBA.SYS_USERS where U_NAME = 'TSEC_RDFSTAR')
     or GI_SUB = (select U_ID from DB.DBA.SYS_USERS where U_NAME = 'TSEC_RDFSTAR');
delete from DB.DBA.SYS_USERS where U_NAME = 'TSEC_RDFSTAR';
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": cleanup STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

ECHO BOTH "COMPLETED: RDF 1.2 triple term helpers and graph-level security: " $ARGV[0] " FAILED, " $ARGV[1] " PASSED\n";
