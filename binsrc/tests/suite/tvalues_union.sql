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

-- VALUES as a member of a UNION keeps its rows
ECHO BOTH "STARTED: VALUES in UNION tests\n";
SET ARGV[0] 0;
SET ARGV[1] 0;

-- a VALUES block as a UNION member keeps its rows
SPARQL SELECT (COUNT (*) AS ?n) WHERE { { BIND ("x" AS ?label) BIND (1 AS ?t) }
UNION { VALUES (?label ?t) { ("lit" 5) ("iri" <urn:tvalues_union:i>) } } };
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": rows of BIND UNION VALUES state\n";
ECHO BOTH $IF $EQU $LAST[1] "3" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": rows of BIND UNION VALUES = " $LAST[1] " (expected 3)\n";
SPARQL SELECT (COUNT (*) AS ?n) WHERE {
{ VALUES ?o { <urn:tvalues_union:o> } BIND (<<( <urn:tvalues_union:s> <urn:tvalues_union:p> ?o )>> AS ?t) BIND ("tt" AS ?label) }
UNION { VALUES (?label ?t) { ("lit" 5) ("iri" <urn:tvalues_union:i>) } } };
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": rows of triple term UNION VALUES state\n";
ECHO BOTH $IF $EQU $LAST[1] "3" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": rows of triple term UNION VALUES = " $LAST[1] " (expected 3)\n";
SPARQL SELECT (COUNT (*) AS ?n) WHERE { { VALUES ?x { 1 2 } } UNION { VALUES ?x { 3 4 } } };
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": rows of one-variable VALUES UNION VALUES state\n";
ECHO BOTH $IF $EQU $LAST[1] "4" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": rows of one-variable VALUES UNION VALUES = " $LAST[1] " (expected 4)\n";
SPARQL SELECT (COUNT (*) AS ?n) WHERE { { BIND (1 AS ?x) } UNION { VALUES ?x { 3 4 } } };
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": rows of BIND UNION one-variable VALUES state\n";
ECHO BOTH $IF $EQU $LAST[1] "3" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": rows of BIND UNION one-variable VALUES = " $LAST[1] " (expected 3)\n";


ECHO BOTH "COMPLETED WITH " $ARGV[0] " FAILED, " $ARGV[1] " PASSED: VALUES in UNION tests\n";
