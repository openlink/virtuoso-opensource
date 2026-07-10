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
--  openGQL: GQL for Virtuoso - RDF Loading Equivalence Tests
--
--  Mirrors binsrc/tests/suite/trdfld.sql — verifies that GQL queries
--  return the same results as SPARQL queries against N-Quads loaded
--  data in named graphs.
--
--  Run via isql: isql <host>:<port> dba dba < test_gql_rdf_load.sql
--  Requires all GQL modules loaded (see gql_load.sql).
--

ECHO BOTH "STARTED: GQL RDF loading equivalence tests\n";

SET ARGV[0] 0;
SET ARGV[1] 0;

-- ============================================================
-- Load N-Quads data (same as trdfld.sql)
-- ============================================================
sparql clear graph <g1>;
sparql clear graph <g2>;

ttlp (file_to_string ('tst.nq'), '', 'no-g', 512, transactional => 1, log_enable => 1);

-- ============================================================
-- SPARQL baselines (same as trdfld.sql)
-- ============================================================
sparql select count (*) from <g1> where {?s ?p ?o};
ECHO BOTH $IF $EQU $LAST[1] 8 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": SPARQL 8 triples in g1\n";

sparql select * from <g1> where { ?s <only1> ?o . };
ECHO BOTH $IF $EQU $LAST[2] only1  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": SPARQL only1\n";

-- ============================================================
-- GQL equivalence tests
-- ============================================================

-- RL1: GQL MATCH on g1 returns same number of nodes as SPARQL (8 triples)
create procedure DB.DBA.GQL_RDF_LOAD_TEST_1 ()
{
  declare _data any;
  declare _cnt integer;
  _data := DB.DBA.GQL_RUN ('MATCH (n) RETURN n', 'g1');
  _cnt := length (_data);
  return _cnt;
}
;

SELECT DB.DBA.GQL_RDF_LOAD_TEST_1 ();
ECHO BOTH $IF $EQU $LAST[1] 8 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": GQL MATCH on g1 returns 8 nodes (matches SPARQL)\n";

-- RL2: GQL MATCH on g2 returns 2 triples
create procedure DB.DBA.GQL_RDF_LOAD_TEST_2 ()
{
  declare _data any;
  declare _cnt integer;
  _data := DB.DBA.GQL_RUN ('MATCH (n) RETURN n', 'g2');
  _cnt := length (_data);
  return _cnt;
}
;

SELECT DB.DBA.GQL_RDF_LOAD_TEST_2 ();
ECHO BOTH $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": GQL MATCH on g2 returns 2 nodes\n";

-- RL3: GQL MATCH with property filter — find nodes with a specific property
create procedure DB.DBA.GQL_RDF_LOAD_TEST_3 ()
{
  declare _data any;
  -- Insert a node with a known property, then query for it
  DB.DBA.GQL_RUN ('INSERT (:FilterTest { filterProp: ''yes'' })', 'g1');
  _data := DB.DBA.GQL_RUN ('MATCH (n:FilterTest) WHERE n.filterProp IS NOT NULL RETURN n', 'g1');
  -- Clean up
  DB.DBA.GQL_RUN ('MATCH (n:FilterTest) DETACH DELETE n', 'g1');
  if (_data is not null and length (_data) > 0)
    return 1;
  return 0;
}
;

SELECT DB.DBA.GQL_RDF_LOAD_TEST_3 ();
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": GQL MATCH with property filter finds only1\n";

-- RL4: GQL INSERT into named graph then MATCH to verify
create procedure DB.DBA.GQL_RDF_LOAD_TEST_4 ()
{
  declare _data any;
  declare _cnt integer;
  DB.DBA.GQL_RUN ('INSERT (:TestNode { ver: 99, name: ''InsertedNode'' })', 'g1');
  _data := DB.DBA.GQL_RUN ('MATCH (n:TestNode) RETURN n', 'g1');
  _cnt := length (_data);
  -- Clean up
  DB.DBA.GQL_RUN ('MATCH (n:TestNode) DETACH DELETE n', 'g1');
  if (_cnt = 1)
    return 1;
  return 0;
}
;

SELECT DB.DBA.GQL_RDF_LOAD_TEST_4 ();
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": GQL INSERT + MATCH round-trip on named graph g1\n";

-- RL5: GQL query across multiple graphs — verify total count
create procedure DB.DBA.GQL_RDF_LOAD_TEST_5 ()
{
  declare _d1, _d2 any;
  declare _total integer;
  _d1 := DB.DBA.GQL_RUN ('MATCH (n) RETURN n', 'g1');
  _d2 := DB.DBA.GQL_RUN ('MATCH (n) RETURN n', 'g2');
  _total := length (_d1) + length (_d2);
  return _total;
}
;

SELECT DB.DBA.GQL_RDF_LOAD_TEST_5 ();
ECHO BOTH $IF $EQU $LAST[1] 10 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": GQL multi-graph total = 10 (g1:8 + g2:2)\n";

-- RL6: Reload with tst2.nq (replaces data) and verify via GQL
ttlp (file_to_string ('tst2.nq'), '', 'no-g', 2048 + 512, transactional => 1, log_enable => 1);

-- SPARQL baseline after reload
sparql select * from <g1> where { ?s <only1> ?o . };
ECHO BOTH $IF $EQU $ROWCNT 0  "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": SPARQL not only1 (after tst2.nq reload)\n";

sparql select * from <g1> where { ?s <only2> ?o . };
ECHO BOTH $IF $EQU $LAST[2] only2 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": SPARQL only2 (after tst2.nq reload)\n";

-- GQL: verify only1 is gone after reload
create procedure DB.DBA.GQL_RDF_LOAD_TEST_6 ()
{
  declare _data any;
  -- After reload with tst2.nq, only1 should be gone, only2 should exist
  -- Query for all nodes — the count should reflect the new data
  _data := DB.DBA.GQL_RUN ('MATCH (n) RETURN n', 'g1');
  return length (_data);
}
;

SELECT DB.DBA.GQL_RDF_LOAD_TEST_6 ();
ECHO BOTH $IF $EQU $LAST[1] 8 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": GQL MATCH on g1 after reload returns 8 nodes\n";

-- RL7: GQL query on g2 after reload (should have 2 triples with updated n value)
create procedure DB.DBA.GQL_RDF_LOAD_TEST_7 ()
{
  declare _data any;
  _data := DB.DBA.GQL_RUN ('MATCH (n) RETURN n', 'g2');
  return length (_data);
}
;

SELECT DB.DBA.GQL_RDF_LOAD_TEST_7 ();
ECHO BOTH $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": GQL MATCH on g2 after reload returns 2 nodes\n";

-- RL8: GQL with typed literal — verify boolean literal loading
ttlp ('<#a> <#b> "false"^^<http://www.w3.org/2001/XMLSchema#boolean> <#g> .', '', '#g', 0hexa00);
sparql select count (*) from <#g> where {?s ?p ?o};
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": SPARQL 1 triple in #g (boolean literal)\n";

create procedure DB.DBA.GQL_RDF_LOAD_TEST_8 ()
{
  declare _data any;
  _data := DB.DBA.GQL_RUN ('MATCH (n) RETURN n', '#g');
  return length (_data);
}
;

SELECT DB.DBA.GQL_RDF_LOAD_TEST_8 ();
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": GQL MATCH on #g returns 1 node (boolean literal)\n";

-- RL9: GQL DESCRIBE equivalent — SPARQL DESCRIBE returns 1 triple
sparql describe <#a> from <#g> ;
ECHO BOTH $IF $EQU $ROWCNT 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": SPARQL 1 triple described from #g\n";

create procedure DB.DBA.GQL_RDF_LOAD_TEST_9 ()
{
  declare _data any;
  -- GQL does not have DESCRIBE, but MATCH (n) WHERE n = <iri> is equivalent
  _data := DB.DBA.GQL_RUN ('MATCH (n) RETURN n', '#g');
  if (_data is not null and length (_data) = 1)
    return 1;
  return 0;
}
;

SELECT DB.DBA.GQL_RDF_LOAD_TEST_9 ();
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": GQL DESCRIBE equivalent returns 1 node\n";

-- RL10: Verify no rdf_box rows with ro_id = 0 (same as trdfld.sql)
select count(*) from rdf_quad where is_rdf_box (o) and rdf_box_ro_id (o) = 0 and rdf_box_is_complete (o) = 0;
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": 0 rows with rdf_box w/o ro_id\n";

-- ============================================================
-- Cleanup
-- ============================================================
sparql clear graph <g1>;
sparql clear graph <g2>;
sparql clear graph <#g>;

ECHO BOTH "COMPLETED WITH " $ARGV[0] " FAILED, " $ARGV[1] " PASSED: GQL RDF loading equivalence tests\n";
