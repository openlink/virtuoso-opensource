--
--  tsparql12_langdir.sql
--
--  SPARQL 1.2 base-direction accessors (LANGDIR, hasLANG, hasLANGDIR) must be
--  callable by the SPARQL endpoint user, not only by dba.
--
--  The SQL these builtins compile to calls DB.DBA.rdf_langdir_impl /
--  rdf_haslang_impl / rdf_haslangdir_impl.  Those were emitted *unqualified*
--  (method 'B' in sparp_bif_descs[]), so under a connection whose default
--  qualifier is not DB.DBA -- which is the case for the anonymous SPARQL
--  endpoint user -- name resolution looked for SPARQL..rdf_langdir_impl and
--  raised SR185 "Undefined procedure".  dba worked only because its default
--  qualifier happens to be DB.DBA.  STRLANGDIR / STRDIR (method 'S') already
--  emitted DB.DBA.-qualified names and were unaffected.
--
--  This driver runs the accessors under the SPARQL qualifier to reproduce the
--  endpoint user's name resolution, then restores DB.DBA.
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

ECHO BOTH "STARTED: SPARQL 1.2 LANGDIR/hasLANG qualifier tests (tsparql12_langdir.sql)\n";

--------------------------------------------------------------------------
-- 1. baseline: the accessors work for dba (default qualifier DB.DBA).
--------------------------------------------------------------------------

SPARQL SELECT (STR(LANGDIR(STRLANGDIR("x", "ar", "rtl"))) AS ?d) WHERE {};
echo both $if $equ $LAST[1] "rtl" "PASSED" "***FAILED";
echo both ": 1a LANGDIR returns the base direction for dba\n";

--------------------------------------------------------------------------
-- 2. the regression: the same accessors under the SPARQL qualifier, which
--    is how the anonymous /sparql endpoint user resolves names.  Each of
--    these raised SR185 "Undefined procedure SPARQL..rdf_*_impl" before the
--    fix.
--------------------------------------------------------------------------

set_qualifier ('SPARQL');

SPARQL SELECT (STR(LANGDIR(STRLANGDIR("x", "ar", "rtl"))) AS ?d) WHERE {};
echo both $if $equ $state "OK" "PASSED" "***FAILED";
echo both ": 2a LANGDIR resolves under the SPARQL qualifier\n";
echo both $if $equ $LAST[1] "rtl" "PASSED" "***FAILED";
echo both ": 2a LANGDIR returns rtl under the SPARQL qualifier\n";

SPARQL SELECT (hasLANG("x"@en) AS ?h) WHERE {};
echo both $if $equ $state "OK" "PASSED" "***FAILED";
echo both ": 2b hasLANG resolves under the SPARQL qualifier\n";
echo both $if $equ $LAST[1] 1 "PASSED" "***FAILED";
echo both ": 2b hasLANG is true for a language-tagged literal\n";

SPARQL SELECT (hasLANGDIR(STRLANGDIR("x", "ar", "rtl")) AS ?h) WHERE {};
echo both $if $equ $state "OK" "PASSED" "***FAILED";
echo both ": 2c hasLANGDIR resolves under the SPARQL qualifier\n";
echo both $if $equ $LAST[1] 1 "PASSED" "***FAILED";
echo both ": 2c hasLANGDIR is true for a dir-tagged literal\n";

-- STRLANGDIR already worked (method 'S'); assert it still does, as a guard.
SPARQL SELECT (STR(STRLANGDIR("x", "ar", "rtl")) AS ?v) WHERE {};
echo both $if $equ $LAST[1] "x" "PASSED" "***FAILED";
echo both ": 2d STRLANGDIR still resolves under the SPARQL qualifier\n";

set_qualifier ('DB.DBA');

ECHO BOTH "COMPLETED: SPARQL 1.2 LANGDIR/hasLANG qualifier tests (tsparql12_langdir.sql)\n";
