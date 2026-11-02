--
--  tsparql_value_in_o.sql
--
--  A SPARQL value computed by an expression and then looked up in the O
--  column (MINUS, FILTER [NOT] EXISTS, = on a bound subject) finds the stored
--  literal it equals.
--
--  On develop/7 such a value was turned into its stored form by
--  DB.DBA.RDF_OBJ_OF_LONG (), declared returns any: the result was held in an
--  any-typed vector column written with its content, and as the O index key it
--  missed the stored O, which is the RDF_OBJ id alone.  A stored string literal
--  passed through COALESCE () or IF () no longer found itself, and neither did a
--  STRLANG () or STRDT () value.
--
--  1-10 are tests of the change (each fails before it); 11-15 are guards and
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

ECHO BOTH "STARTED: a computed value looked up in the O column (tsparql_value_in_o.sql)\n";

sparql clear graph <urn:tok:g>;
--  m5 is longer than 50 characters, so RDF_OBJ knows it by digest.
sparql insert data { graph <urn:tok:g> {
  <urn:tok:m1> <urn:tok:id> "1008-00001"@en .
  <urn:tok:m3> <urn:tok:id> "abc"^^<urn:tok:dt> .
  <urn:tok:m5> <urn:tok:id> "a plain literal longer than fifty characters, stored by its digest as well" .
  <urn:tok:m8> <urn:tok:id> "short" .
  <urn:tok:m9> <urn:tok:id> 42 . } };
select count (*) from DB.DBA.RDF_QUAD where G = iri_to_id ('urn:tok:g');
ECHO BOTH $IF $EQU $LAST[1] 5 "PASSED" "***FAILED";
ECHO BOTH ": five triples loaded: " $LAST[1] "\n";

--  Every row of a query: its columns joined by ',' and each row ended by ';',
--  an unbound value empty; 'ERR <message>' when it fails.
create function TOK_RUN (in _stmt varchar, in _as varchar := null) returns varchar
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
-- 1-10: the computed value finds the stored literal
-- ---------------------------------------------------------------------------

select TOK_RUN ('sparql select count (*) where { graph <urn:tok:g> { <urn:tok:m1> <urn:tok:id> ?y } bind (strlang ("1008-00001", "en") as ?x) minus { graph <urn:tok:g> { <urn:tok:m1> <urn:tok:id> ?x } } }');
ECHO BOTH $IF $EQU $LAST[1] "0;" "PASSED" "***FAILED";
ECHO BOTH ": 1. MINUS the stored literal removes STRLANG (): " $LAST[1] "\n";

select TOK_RUN ('sparql select count (*) where { graph <urn:tok:g> { <urn:tok:m1> <urn:tok:id> ?y } bind (strlang ("1008-00001", "en") as ?x) filter not exists { graph <urn:tok:g> { <urn:tok:m1> <urn:tok:id> ?x } } }');
ECHO BOTH $IF $EQU $LAST[1] "0;" "PASSED" "***FAILED";
ECHO BOTH ": 2. FILTER NOT EXISTS of the stored literal removes STRLANG (): " $LAST[1] "\n";

select TOK_RUN ('sparql select count (*) where { graph <urn:tok:g> { <urn:tok:m1> <urn:tok:id> ?y } bind (strdt ("abc", <urn:tok:dt>) as ?x) filter exists { graph <urn:tok:g> { <urn:tok:m3> <urn:tok:id> ?x } } }');
ECHO BOTH $IF $EQU $LAST[1] "1;" "PASSED" "***FAILED";
ECHO BOTH ": 3. FILTER EXISTS of the stored typed literal keeps STRDT (): " $LAST[1] "\n";

select TOK_RUN ('sparql select count (*) where { graph <urn:tok:g> { <urn:tok:m1> <urn:tok:id> ?x } . filter (?x = strlang ("1008-00001", "en")) }');
ECHO BOTH $IF $EQU $LAST[1] "1;" "PASSED" "***FAILED";
ECHO BOTH ": 4. FILTER (?x = STRLANG ()) on the subject's value: " $LAST[1] "\n";

select TOK_RUN ('sparql select count (*) where { graph <urn:tok:g> { <urn:tok:m1> <urn:tok:id> ?o } bind (coalesce (?o, 1) as ?x) filter exists { graph <urn:tok:g> { <urn:tok:m1> <urn:tok:id> ?x } } }');
ECHO BOTH $IF $EQU $LAST[1] "1;" "PASSED" "***FAILED";
ECHO BOTH ": 5. a stored language-tagged literal through COALESCE () finds itself: " $LAST[1] "\n";

select TOK_RUN ('sparql select count (*) where { graph <urn:tok:g> { <urn:tok:m3> <urn:tok:id> ?o } bind (coalesce (?o, 1) as ?x) filter exists { graph <urn:tok:g> { <urn:tok:m3> <urn:tok:id> ?x } } }');
ECHO BOTH $IF $EQU $LAST[1] "1;" "PASSED" "***FAILED";
ECHO BOTH ": 6. the same for a typed literal: " $LAST[1] "\n";

select TOK_RUN ('sparql select count (*) where { graph <urn:tok:g> { <urn:tok:m5> <urn:tok:id> ?o } bind (coalesce (?o, 1) as ?x) filter exists { graph <urn:tok:g> { <urn:tok:m5> <urn:tok:id> ?x } } }');
ECHO BOTH $IF $EQU $LAST[1] "1;" "PASSED" "***FAILED";
ECHO BOTH ": 7. the same for a plain literal of more than 50 characters: " $LAST[1] "\n";

select TOK_RUN ('sparql select count (*) where { graph <urn:tok:g> { <urn:tok:m8> <urn:tok:id> ?o } bind (coalesce (?o, 1) as ?x) filter exists { graph <urn:tok:g> { <urn:tok:m8> <urn:tok:id> ?x } } }');
ECHO BOTH $IF $EQU $LAST[1] "1;" "PASSED" "***FAILED";
ECHO BOTH ": 8. the same for a short plain literal: " $LAST[1] "\n";

select TOK_RUN ('sparql select count (*) where { graph <urn:tok:g> { <urn:tok:m1> <urn:tok:id> ?o } bind (if (bound (?o), ?o, 1) as ?x) minus { graph <urn:tok:g> { <urn:tok:m1> <urn:tok:id> ?x } } }');
ECHO BOTH $IF $EQU $LAST[1] "0;" "PASSED" "***FAILED";
ECHO BOTH ": 9. MINUS the stored literal removes it after IF (): " $LAST[1] "\n";

select TOK_RUN ('sparql select count (*) where { graph <urn:tok:g> { <urn:tok:m1> <urn:tok:id> ?o } bind (coalesce (?o, 1) as ?x) filter exists { graph <urn:tok:g> { <urn:tok:m1> <urn:tok:id> ?x } } }', 'SPARQL');
ECHO BOTH $IF $EQU $LAST[1] "1;" "PASSED" "***FAILED";
ECHO BOTH ": 10. 5 as the anonymous account SPARQL: " $LAST[1] "\n";

-- ---------------------------------------------------------------------------
-- 11-15: guards
-- ---------------------------------------------------------------------------

select TOK_RUN ('sparql select count (*) where { graph <urn:tok:g> { <urn:tok:m9> <urn:tok:id> ?o } bind (coalesce (?o, 1) as ?x) filter exists { graph <urn:tok:g> { <urn:tok:m9> <urn:tok:id> ?x } } }');
ECHO BOTH $IF $EQU $LAST[1] "1;" "PASSED" "***FAILED";
ECHO BOTH ": 11. a stored number through COALESCE () finds itself: " $LAST[1] "\n";

select TOK_RUN ('sparql select count (*) where { graph <urn:tok:g> { <urn:tok:m1> <urn:tok:id> ?o } bind (coalesce (?o, 1) as ?x) graph <urn:tok:g> { <urn:tok:m1> <urn:tok:id> ?x } }');
ECHO BOTH $IF $EQU $LAST[1] "1;" "PASSED" "***FAILED";
ECHO BOTH ": 12. the same value joined to the pattern: " $LAST[1] "\n";

select TOK_RUN ('sparql select count (*) where { graph <urn:tok:g> { ?s ?p ?o } filter (?o = "1008-00001"@en) }');
ECHO BOTH $IF $EQU $LAST[1] "1;" "PASSED" "***FAILED";
ECHO BOTH ": 13. FILTER (?o = constant) over the graph: " $LAST[1] "\n";

select TOK_RUN ('sparql select count (*) where { graph <urn:tok:g> { <urn:tok:m1> <urn:tok:id> ?x } . { select ?x where { bind (strlang ("1008-00001", "en") as ?x) } } }');
ECHO BOTH $IF $EQU $LAST[1] "1;" "PASSED" "***FAILED";
ECHO BOTH ": 14. the stored literal joined to STRLANG (): " $LAST[1] "\n";

select TOK_RUN ('sparql select count (*) where { graph <urn:tok:g> { ?s ?p ?o } filter (?o = strlang ("1008-00001", "en")) }');
ECHO BOTH $IF $EQU $LAST[1] "1;" "PASSED" "***FAILED";
ECHO BOTH ": 15. FILTER (?o = STRLANG ()) over the graph: " $LAST[1] "\n";

-- ---------------------------------------------------------------------------
-- Cleanup
-- ---------------------------------------------------------------------------
sparql clear graph <urn:tok:g>;
drop function TOK_RUN;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": cleanup STATE=" $STATE "\n";

ECHO BOTH "COMPLETED: a computed value looked up in the O column (tsparql_value_in_o.sql)\n";
