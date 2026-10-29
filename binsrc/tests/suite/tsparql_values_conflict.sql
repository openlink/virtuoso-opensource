--
--  tsparql_values_conflict.sql
--
--  A group whose fixed values contradict its FILTER, as in
--  { values ?x { 1 } filter (?x = 2) }, has no solutions, whatever the query
--  selects from it.
--
--  On develop/7 the SPARQL compiler saw the contradiction and emptied the
--  group (sparp_gp_produce_nothing ()), but the SQL said "no rows" only
--  through a conflicting variable: selecting ?x gave no rows, while COUNT (*),
--  ASK, a constant in the select list, a group nested or joined to another,
--  and FILTER NOT EXISTS of it all read the group as {}, one solution.  The
--  same cause as patterns no quad map can produce (trdfview_nomatch.sql); its
--  fix covers these forms too.
--
--  1-13 are tests of the change (each fails before it); 14-22 are guards and
--  hold on both sides.
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

ECHO BOTH "STARTED: SPARQL VALUES contradicted by FILTER (tsparql_values_conflict.sql)\n";

sparql clear graph <urn:tvc:g>;
sparql insert data { graph <urn:tvc:g> { <urn:tvc:s> <urn:tvc:p> "o" . } };
select count (*) from DB.DBA.RDF_QUAD where G = iri_to_id ('urn:tvc:g');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": one triple loaded: " $LAST[1] "\n";

--  Every row of a query: its columns joined by ',' and each row ended by ';';
--  'ERR <message>' when it fails.
create function TVC_RUN (in _stmt varchar, in _as varchar := null) returns varchar
{
  declare _st, _msg varchar;
  declare _md, _rows any;
  declare _res varchar;
  declare _i, _j integer;
  _st := '00000';
  if (_as is not null)
    __set_user_id (_as);
  exec (_stmt, _st, _msg, vector (), 1000, _md, _rows);
  if (_as is not null)
    __pop_user_id ();
  if (_st <> '00000' and _st <> 0)
    return 'ERR ' || "LEFT" (coalesce (_msg, cast (_st as varchar)), 60);
  _res := '';
  if (isvector (_rows))
    for (_i := 0; _i < length (_rows); _i := _i + 1)
      {
        for (_j := 0; _j < length (_rows[_i]); _j := _j + 1)
          _res := _res || case when _j > 0 then ',' else '' end
            || coalesce (cast (_rows[_i][_j] as varchar), '');
        _res := _res || ';';
      }
  return _res;
}
;

-- ---------------------------------------------------------------------------
-- 1-13: the contradicted group has no solutions
-- ---------------------------------------------------------------------------

select TVC_RUN ('sparql select (count (*) as ?c) where { values ?x { 1 } filter (?x = 2) }');
ECHO BOTH $IF $EQU $LAST[1] "0;" "PASSED" "***FAILED";
ECHO BOTH ": 1. COUNT (*): " $LAST[1] "\n";

select TVC_RUN ('sparql ask where { values ?x { 1 } filter (?x = 2) }');
ECHO BOTH $IF $EQU $LAST[1] "0;" "PASSED" "***FAILED";
ECHO BOTH ": 2. ASK: " $LAST[1] "\n";

select TVC_RUN ('sparql select (1 as ?one) where { values ?x { 1 } filter (?x = 2) }');
ECHO BOTH $IF $EQU $LAST[1] "" "PASSED" "***FAILED";
ECHO BOTH ": 3. a constant selected: [" $LAST[1] "]\n";

select TVC_RUN ('sparql select (count (*) as ?c) where { { values ?x { 1 } filter (?x = 2) } }');
ECHO BOTH $IF $EQU $LAST[1] "0;" "PASSED" "***FAILED";
ECHO BOTH ": 4. the group nested: " $LAST[1] "\n";

select TVC_RUN ('sparql select (count (*) as ?c) where { values ?x { 1 } filter (?x = 2) . graph <urn:tvc:g> { ?s ?p ?o } }');
ECHO BOTH $IF $EQU $LAST[1] "0;" "PASSED" "***FAILED";
ECHO BOTH ": 5. joined to a stored triple: " $LAST[1] "\n";

select TVC_RUN ('sparql select (count (*) as ?c) where { values ?x { 1.5 } filter (?x = 2.5) }');
ECHO BOTH $IF $EQU $LAST[1] "0;" "PASSED" "***FAILED";
ECHO BOTH ": 6. decimals: " $LAST[1] "\n";

select TVC_RUN ('sparql select (count (*) as ?c) where { values ?x { 1 } filter (sameTerm (?x, 2)) }');
ECHO BOTH $IF $EQU $LAST[1] "0;" "PASSED" "***FAILED";
ECHO BOTH ": 7. sameTerm: " $LAST[1] "\n";

select TVC_RUN ('sparql select (count (*) as ?c) where { values ?x { 1 } filter (?x = 2 && true) }');
ECHO BOTH $IF $EQU $LAST[1] "0;" "PASSED" "***FAILED";
ECHO BOTH ": 8. the equality inside &&: " $LAST[1] "\n";

select TVC_RUN ('sparql select (count (*) as ?c) where { values ?x { "2020-01-01"^^xsd:date } filter (?x = "2021-01-01"^^xsd:date) }');
ECHO BOTH $IF $EQU $LAST[1] "0;" "PASSED" "***FAILED";
ECHO BOTH ": 9. dates: " $LAST[1] "\n";

select TVC_RUN ('sparql select (count (*) as ?c) where { values ?x { 1 } filter (?x = 2) optional { graph <urn:tvc:g> { ?s ?p ?o } } }');
ECHO BOTH $IF $EQU $LAST[1] "0;" "PASSED" "***FAILED";
ECHO BOTH ": 10. with an OPTIONAL: " $LAST[1] "\n";

select TVC_RUN ('sparql select (count (*) as ?c) where { graph <urn:tvc:g> { ?s ?p ?o } filter not exists { values ?x { 1 } filter (?x = 2) } }');
ECHO BOTH $IF $EQU $LAST[1] "1;" "PASSED" "***FAILED";
ECHO BOTH ": 11. FILTER NOT EXISTS of it keeps the triple: " $LAST[1] "\n";

select TVC_RUN ('sparql select (count (*) as ?c) where { values (?x ?y) { (1 2) } filter (?x = 2) }');
ECHO BOTH $IF $EQU $LAST[1] "0;" "PASSED" "***FAILED";
ECHO BOTH ": 12. a VALUES row of two variables: " $LAST[1] "\n";

select TVC_RUN ('sparql select (count (*) as ?c) where { values ?x { 1 } filter (?x = 2) }', 'SPARQL');
ECHO BOTH $IF $EQU $LAST[1] "0;" "PASSED" "***FAILED";
ECHO BOTH ": 13. 1 as the anonymous account SPARQL: " $LAST[1] "\n";

-- ---------------------------------------------------------------------------
-- 14-22: guards
-- ---------------------------------------------------------------------------

select TVC_RUN ('sparql select (count (*) as ?c) where { values ?x { 1 } filter (?x = 1) }');
ECHO BOTH $IF $EQU $LAST[1] "1;" "PASSED" "***FAILED";
ECHO BOTH ": 14. a FILTER the value meets: " $LAST[1] "\n";

select TVC_RUN ('sparql ask where { values ?x { 1 } filter (?x = 1) }');
ECHO BOTH $IF $EQU $LAST[1] "1;" "PASSED" "***FAILED";
ECHO BOTH ": 15. ASK of it: " $LAST[1] "\n";

select TVC_RUN ('sparql select ?x where { values ?x { 1 } filter (?x = 2) }');
ECHO BOTH $IF $EQU $LAST[1] "" "PASSED" "***FAILED";
ECHO BOTH ": 16. selecting ?x of the contradiction: [" $LAST[1] "]\n";

select TVC_RUN ('sparql select (count (*) as ?c) where { values ?x { 1 2 } filter (?x = 3) }');
ECHO BOTH $IF $EQU $LAST[1] "0;" "PASSED" "***FAILED";
ECHO BOTH ": 17. two values, neither meets the FILTER: " $LAST[1] "\n";

select TVC_RUN ('sparql select (count (*) as ?c) where { values ?x { "a" } filter (?x = "b") }');
ECHO BOTH $IF $EQU $LAST[1] "0;" "PASSED" "***FAILED";
ECHO BOTH ": 18. strings: " $LAST[1] "\n";

select TVC_RUN ('sparql select (count (*) as ?c) where { values ?x { 1 } filter (?x in (2, 3)) }');
ECHO BOTH $IF $EQU $LAST[1] "0;" "PASSED" "***FAILED";
ECHO BOTH ": 19. IN: " $LAST[1] "\n";

select TVC_RUN ('sparql select (count (*) as ?c) where { values ?x { 1 } filter (?x > 2) }');
ECHO BOTH $IF $EQU $LAST[1] "0;" "PASSED" "***FAILED";
ECHO BOTH ": 20. a comparison: " $LAST[1] "\n";

select TVC_RUN ('sparql select (count (*) as ?c) where { { values ?x { 1 } filter (?x = 2) } union { bind (3 as ?y) } }');
ECHO BOTH $IF $EQU $LAST[1] "1;" "PASSED" "***FAILED";
ECHO BOTH ": 21. union with a branch of one row: " $LAST[1] "\n";

select TVC_RUN ('sparql select (count (*) as ?c) where { graph <urn:tvc:g> { ?s ?p ?o } filter exists { values ?x { 1 } filter (?x = 1) } }');
ECHO BOTH $IF $EQU $LAST[1] "1;" "PASSED" "***FAILED";
ECHO BOTH ": 22. FILTER EXISTS of a group with a solution: " $LAST[1] "\n";

-- ---------------------------------------------------------------------------
-- Cleanup
-- ---------------------------------------------------------------------------
sparql clear graph <urn:tvc:g>;
drop function TVC_RUN;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": cleanup STATE=" $STATE "\n";

ECHO BOTH "COMPLETED: SPARQL VALUES contradicted by FILTER (tsparql_values_conflict.sql)\n";
