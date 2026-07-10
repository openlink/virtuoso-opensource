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
--  openGQL: GQL for Virtuoso - RDF Equivalence Test Runner
--
--  Loads and runs all GQL RDF equivalence test suites in order.
--  Each suite mirrors a corresponding SPARQL/RDF test from
--  binsrc/tests/suite/ and verifies that the GQL implementation
--  produces equivalent results.
--
--  Run via isql: isql <host>:<port> dba dba < test_gql_rdf_runner.sql
--  Requires all GQL modules loaded (see gql_load.sql).
--

ECHO BOTH "STARTED: GQL RDF equivalence test runner\n";
ECHO BOTH "=============================================\n";

-- ============================================================
-- Suite 1: RDF API equivalence (mirrors trdfapi.sql)
-- ============================================================
ECHO BOTH "\n--- Suite 1: RDF API equivalence ---\n";
LOAD binsrc/gql/test_gql_rdf_api.sql;

-- ============================================================
-- Suite 2: RDF inference & reasoning (mirrors trdfinf.sql)
-- ============================================================
ECHO BOTH "\n--- Suite 2: RDF inference & reasoning ---\n";
LOAD binsrc/gql/test_gql_rdf_inference.sql;

-- ============================================================
-- Suite 3: RDF loading (mirrors trdfld.sql)
-- ============================================================
ECHO BOTH "\n--- Suite 3: RDF loading ---\n";
LOAD binsrc/gql/test_gql_rdf_load.sql;

-- ============================================================
-- Suite 4: ACID transactions (mirrors tsparql_acid.sql)
-- ============================================================
ECHO BOTH "\n--- Suite 4: ACID transactions ---\n";
LOAD binsrc/gql/test_gql_rdf_acid.sql;

ECHO BOTH "\n=============================================\n";
ECHO BOTH "COMPLETED: GQL RDF equivalence test runner\n";
