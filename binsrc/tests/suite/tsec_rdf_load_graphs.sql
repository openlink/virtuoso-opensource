--
--  tsec_rdf_load_graphs.sql
--
--  SPARQL LOAD and sponging of TriG and N-Quads documents must honour the
--  graph-level permissions of the graphs the documents name.
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

echo BOTH "STARTED: graph-level security of loaded TriG and N-Quads documents\n";

SET ARGV[0] 0;
SET ARGV[1] 0;

create function TSEC_RDF_LOAD_COUNT (in graph_iri varchar) returns integer
{
  return (select count (*) from DB.DBA.RDF_QUAD where G = iri_to_id (graph_iri, 0));
}
;

DB.DBA.DAV_COL_CREATE ('/DAV/tsec_rdf_load/', '110100100R', 'dav', 'dav', 'dav', 'dav');
DB.DBA.DAV_RES_UPLOAD ('/DAV/tsec_rdf_load/other.trig', '<urn:tsec:load:s> <urn:tsec:load:p> "default graph" .
GRAPH <urn:tsec:load:other> { <urn:tsec:load:s> <urn:tsec:load:p> "named graph" . }
', 'application/x-trig', '110100100R', 'dav', 'dav', 'dav', 'dav');
DB.DBA.DAV_RES_UPLOAD ('/DAV/tsec_rdf_load/other.nq', '<urn:tsec:load:s> <urn:tsec:load:p> "default graph" .
<urn:tsec:load:s> <urn:tsec:load:p> "named graph" <urn:tsec:load:other> .
', 'application/n-quads', '110100100R', 'dav', 'dav', 'dav', 'dav');
DB.DBA.DAV_RES_UPLOAD ('/DAV/tsec_rdf_load/sponge.trig', '<urn:tsec:load:s> <urn:tsec:load:p> "default graph" .
GRAPH <urn:tsec:load:other> { <urn:tsec:load:s> <urn:tsec:load:p> "named graph, sponged" . }
', 'application/x-trig', '110100100R', 'dav', 'dav', 'dav', 'dav');
DB.DBA.DAV_RES_UPLOAD ('/DAV/tsec_rdf_load/own.trig', '<urn:tsec:load:s> <urn:tsec:load:p> "default graph" .
GRAPH <urn:tsec:load:own> { <urn:tsec:load:s> <urn:tsec:load:p> "named graph" . }
', 'application/x-trig', '110100100R', 'dav', 'dav', 'dav', 'dav');

sparql clear graph <urn:tsec:load:other>;
sparql clear graph <urn:tsec:load:own>;
sparql insert data { graph <urn:tsec:load:other> { <urn:tsec:load:s> <urn:tsec:load:p> "already there" } };

-- A user who may update, and a user who may only query and sponge; each may
-- read every graph, and write or sponge only the graphs of its documents.
DB.DBA.USER_CREATE ('TSEC_LOAD_UPD', 'TSEC_LOAD_UPD', vector ('SQL_ENABLE', 1));
grant SPARQL_UPDATE to "TSEC_LOAD_UPD";
DB.DBA.USER_CREATE ('TSEC_LOAD_SPG', 'TSEC_LOAD_SPG', vector ('SQL_ENABLE', 1));
grant SPARQL_SELECT to "TSEC_LOAD_SPG";
grant SPARQL_SPONGE to "TSEC_LOAD_SPG";
DB.DBA.RDF_DEFAULT_USER_PERMS_SET ('TSEC_LOAD_UPD', 1);
DB.DBA.RDF_DEFAULT_USER_PERMS_SET ('TSEC_LOAD_SPG', 1);
DB.DBA.RDF_GRAPH_USER_PERMS_SET ('urn:tsec:load:other', 'TSEC_LOAD_UPD', 1);
DB.DBA.RDF_GRAPH_USER_PERMS_SET ('urn:tsec:load:other', 'TSEC_LOAD_SPG', 1);
DB.DBA.RDF_GRAPH_USER_PERMS_SET ('urn:tsec:load:own', 'TSEC_LOAD_UPD', 7);
DB.DBA.RDF_GRAPH_USER_PERMS_SET ('http://localhost:$U{HTTPPORT}/DAV/tsec_rdf_load/other.trig', 'TSEC_LOAD_UPD', 7);
DB.DBA.RDF_GRAPH_USER_PERMS_SET ('http://localhost:$U{HTTPPORT}/DAV/tsec_rdf_load/other.nq', 'TSEC_LOAD_UPD', 7);
DB.DBA.RDF_GRAPH_USER_PERMS_SET ('http://localhost:$U{HTTPPORT}/DAV/tsec_rdf_load/own.trig', 'TSEC_LOAD_UPD', 7);
DB.DBA.RDF_GRAPH_USER_PERMS_SET ('http://localhost:$U{HTTPPORT}/DAV/tsec_rdf_load/sponge.trig', 'TSEC_LOAD_SPG', 5);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": setup STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

--
--  1. SPARQL LOAD by a user with no write permission on a named graph.
--
RECONNECT TSEC_LOAD_UPD;

sparql insert data { graph <urn:tsec:load:other> { <urn:tsec:load:s> <urn:tsec:load:p> "inserted" } };
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": update user: INSERT DATA into the read-only graph is refused, STATE=" $STATE "\n";

sparql define get:soft "replace" load <http://localhost:$U{HTTPPORT}/DAV/tsec_rdf_load/other.trig>;
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": update user: LOAD of a TriG document naming the read-only graph is refused, STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

sparql define get:soft "replace" load <http://localhost:$U{HTTPPORT}/DAV/tsec_rdf_load/other.nq>;
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": update user: LOAD of an N-Quads document naming the read-only graph is refused, STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

sparql define get:soft "replace" load <http://localhost:$U{HTTPPORT}/DAV/tsec_rdf_load/own.trig>;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": update user: LOAD of a TriG document naming a writable graph succeeds, STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

--
--  2. Sponging by a user who may only query and sponge.
--
RECONNECT TSEC_LOAD_SPG;

select count (*) from (sparql define get:soft "replace" define get:error-recovery "signal" select ?o from <http://localhost:$U{HTTPPORT}/DAV/tsec_rdf_load/sponge.trig> where { ?s ?p ?o }) t;
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": sponge user: sponging a TriG document naming the read-only graph is refused, STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

-- Without get:error-recovery "signal" a failed sponge is not an error, the
-- query runs over what is there: nothing.
select count (*) from (sparql define get:soft "replace" select ?o from <http://localhost:$U{HTTPPORT}/DAV/tsec_rdf_load/sponge.trig> where { ?s ?p ?o }) t;
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": sponge user: the default sponge of that document gives 0 rows, got " $LAST[1] "\n";

--
--  3. Nothing reached the read-only graph or the documents' own graphs.
--
RECONNECT dba;

select TSEC_RDF_LOAD_COUNT ('urn:tsec:load:other');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": the read-only graph still has only its 1 triple, got " $LAST[1] "\n";

select TSEC_RDF_LOAD_COUNT ('http://localhost:$U{HTTPPORT}/DAV/tsec_rdf_load/other.trig') + TSEC_RDF_LOAD_COUNT ('http://localhost:$U{HTTPPORT}/DAV/tsec_rdf_load/other.nq') + TSEC_RDF_LOAD_COUNT ('http://localhost:$U{HTTPPORT}/DAV/tsec_rdf_load/sponge.trig');
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": a refused document loads nothing into its own graph either, got " $LAST[1] "\n";

select TSEC_RDF_LOAD_COUNT ('urn:tsec:load:own');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": the writable named graph got its triple, got " $LAST[1] "\n";

--
--  4. dba loads the same document as before.
--
sparql define get:soft "replace" load <http://localhost:$U{HTTPPORT}/DAV/tsec_rdf_load/other.trig>;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": dba: LOAD of the TriG document succeeds, STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select TSEC_RDF_LOAD_COUNT ('urn:tsec:load:other');
ECHO BOTH $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": dba: the named graph got the triple, got " $LAST[1] "\n";

ECHO BOTH "COMPLETED: graph-level security of loaded TriG and N-Quads documents: " $ARGV[0] " FAILED, " $ARGV[1] " PASSED\n";
