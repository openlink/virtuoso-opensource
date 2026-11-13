--
--  trdfview_nomatch.sql
--
--  A triple pattern that no quad map can produce -- here a predicate the
--  view graph does not map -- has no solutions, so its group has none either.
--  The compiler empties such a group; it must still read as "no rows" when
--  none of its variables is used outside it (ASK, COUNT, EXISTS, MINUS),
--  not as the one-solution empty group {}.
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

ECHO BOTH "STARTED: patterns no quad map can produce\n";

create table RVN.RVN.T (ID integer primary key, HOURS integer);
insert into RVN.RVN.T values (1, 5);
insert into RVN.RVN.T values (2, 7);

--  The graph is exclusive to this view and maps one predicate only.
sparql create iri class <urn:rvn:iri> "urn:rvn:t/%d" (in id integer not null) .
  alter quad storage virtrdf:DefaultQuadStorage from RVN.RVN.T as t
  { create <urn:rvn:qm> as graph <urn:rvn:g> option (exclusive) { <urn:rvn:iri> (t.ID) <urn:rvn:hours> t.HOURS . } };

sparql select count (*) from <urn:rvn:g> where { ?x <urn:rvn:hours> ?h };
ECHO BOTH $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";
ECHO BOTH ": the view graph has " $LAST[1] " rows\n";

sparql ask from <urn:rvn:g> where { ?x <urn:rvn:hours> 99 };
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": ASK of a mapped predicate with no such value = " $LAST[1] "\n";

sparql select ?x from <urn:rvn:g> where { ?x a <urn:rvn:nope> };
ECHO BOTH $IF $EQU $ROWCNT 0 "PASSED" "***FAILED";
ECHO BOTH ": SELECT of an unmapped pattern gives " $ROWCNT " rows\n";

sparql ask from <urn:rvn:g> where { ?x a <urn:rvn:nope> };
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": ASK of an unmapped pattern = " $LAST[1] "\n";

sparql select count (*) from <urn:rvn:g> where { ?x a <urn:rvn:nope> };
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": COUNT of an unmapped pattern = " $LAST[1] "\n";

sparql select count (*) from <urn:rvn:g> where { ?x a <urn:rvn:nope> . ?x <urn:rvn:hours> ?h };
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": COUNT of an unmapped pattern joined to a mapped one = " $LAST[1] "\n";

sparql select count (*) from <urn:rvn:g> where { { ?x a <urn:rvn:nope> } union { ?x a <urn:rvn:nope2> } };
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": COUNT of a union of two unmapped patterns = " $LAST[1] "\n";

sparql select count (*) from <urn:rvn:g> where { { select ?x where { ?x a <urn:rvn:nope> } } };
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": COUNT over a sub-select of an unmapped pattern = " $LAST[1] "\n";

sparql select count (*) from <urn:rvn:g> where { ?x <urn:rvn:hours> ?h filter exists { ?x a <urn:rvn:nope> } };
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": FILTER EXISTS of an unmapped pattern keeps " $LAST[1] " rows\n";

sparql select count (*) from <urn:rvn:g> where { ?x <urn:rvn:hours> ?h filter not exists { ?x a <urn:rvn:nope> } };
ECHO BOTH $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";
ECHO BOTH ": FILTER NOT EXISTS of an unmapped pattern keeps " $LAST[1] " rows\n";

sparql select count (*) from <urn:rvn:g> where { ?x <urn:rvn:hours> ?h minus { ?x a <urn:rvn:nope> } };
ECHO BOTH $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";
ECHO BOTH ": MINUS of an unmapped pattern keeps " $LAST[1] " rows\n";

sparql select count (*) from <urn:rvn:g> where { ?x <urn:rvn:hours> ?h optional { ?x a <urn:rvn:nope> } };
ECHO BOTH $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";
ECHO BOTH ": OPTIONAL of an unmapped pattern keeps " $LAST[1] " rows\n";

--  The empty group has one solution; that must not change.
sparql ask where { };
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": ASK {} = " $LAST[1] "\n";

sparql select count (*) where { };
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": COUNT over {} = " $LAST[1] "\n";

sparql select count (*) where { values ?v { 1 2 } { } };
ECHO BOTH $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";
ECHO BOTH ": VALUES joined to {} = " $LAST[1] " rows\n";

sparql drop quad map <urn:rvn:qm>;
drop table RVN.RVN.T;

ECHO BOTH "COMPLETED: patterns no quad map can produce\n";
