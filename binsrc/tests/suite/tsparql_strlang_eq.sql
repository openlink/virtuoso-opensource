--
--  tsparql_strlang_eq.sql
--
--  A literal made by STRLANG (), STRDT () or STRLANGDIR () is the same RDF
--  term as the stored literal with that lexical form and language or datatype.
--
--  On develop/7 the made literal was an RDF box without an RDF_OBJ id, and the
--  stored literal, read from the store or written as a constant, a box with
--  its id.  The two were told apart: = and sameTerm against the constant
--  answered false, and COUNT (DISTINCT), SELECT DISTINCT and GROUP BY counted
--  the literal twice.  (The made value looked up in the O column is
--  tsparql_value_in_o.sql.)
--
--  1-11 are tests of the change (each fails before it); 12-19 are guards and
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

ECHO BOTH "STARTED: STRLANG () / STRDT () literal and the stored literal (tsparql_strlang_eq.sql)\n";

sparql clear graph <urn:tsl:g>;
sparql clear graph <urn:tsl:g2>;
--  m2 and m4 are longer than 50 characters, so RDF_OBJ knows them by digest.
sparql insert data { graph <urn:tsl:g> {
  <urn:tsl:m1> <urn:tsl:id> "1008-00001"@en .
  <urn:tsl:m2> <urn:tsl:id> "a language-tagged literal longer than fifty characters, stored by its digest"@en .
  <urn:tsl:m3> <urn:tsl:id> "abc"^^<urn:tsl:dt> .
  <urn:tsl:m4> <urn:tsl:id> "a typed literal longer than fifty characters, also stored by its digest"^^<urn:tsl:dt> . } };
--  A literal with a base direction, stored through STRLANGDIR () so that this
--  file needs no double minus.
sparql insert { graph <urn:tsl:g> { <urn:tsl:m7> <urn:tsl:id> ?x } } where { bind (strlangdir ("abc", "en", "ltr") as ?x) };
select count (*) from DB.DBA.RDF_QUAD where G = iri_to_id ('urn:tsl:g');
ECHO BOTH $IF $EQU $LAST[1] 5 "PASSED" "***FAILED";
ECHO BOTH ": five triples loaded: " $LAST[1] "\n";

--  Every row of a query: its columns joined by ',' and each row ended by ';',
--  an unbound value empty; 'ERR <message>' when it fails.
create function TSL_RUN (in _stmt varchar, in _as varchar := null) returns varchar
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
-- 1-11: the made literal is the stored literal
-- ---------------------------------------------------------------------------

select TSL_RUN ('sparql select (strlang ("1008-00001", "en") = "1008-00001"@en as ?eq) where { }');
ECHO BOTH $IF $EQU $LAST[1] "1;" "PASSED" "***FAILED";
ECHO BOTH ": 1. STRLANG () = the stored literal: " $LAST[1] "\n";

select TSL_RUN ('sparql select (sameTerm (strlang ("1008-00001", "en"), "1008-00001"@en) as ?eq) where { }');
ECHO BOTH $IF $EQU $LAST[1] "1;" "PASSED" "***FAILED";
ECHO BOTH ": 2. sameTerm of STRLANG () and the stored literal: " $LAST[1] "\n";

select TSL_RUN ('sparql select (strlang ("a language-tagged literal longer than fifty characters, stored by its digest", "en") = "a language-tagged literal longer than fifty characters, stored by its digest"@en as ?eq) where { }');
ECHO BOTH $IF $EQU $LAST[1] "1;" "PASSED" "***FAILED";
ECHO BOTH ": 3. the same for a literal of more than 50 characters: " $LAST[1] "\n";

select TSL_RUN ('sparql select count (distinct ?x) where { { bind (strlang ("1008-00001", "en") as ?x) } union { graph <urn:tsl:g> { <urn:tsl:m1> <urn:tsl:id> ?x } } }');
ECHO BOTH $IF $EQU $LAST[1] "1;" "PASSED" "***FAILED";
ECHO BOTH ": 4. COUNT (DISTINCT) of STRLANG () and the stored literal: " $LAST[1] "\n";

select TSL_RUN ('sparql select count (distinct ?x) where { { bind (strlang ("a language-tagged literal longer than fifty characters, stored by its digest", "en") as ?x) } union { graph <urn:tsl:g> { <urn:tsl:m2> <urn:tsl:id> ?x } } }');
ECHO BOTH $IF $EQU $LAST[1] "1;" "PASSED" "***FAILED";
ECHO BOTH ": 5. the same for a literal of more than 50 characters: " $LAST[1] "\n";

select TSL_RUN ('sparql select count (distinct ?x) where { { bind (strdt ("abc", <urn:tsl:dt>) as ?x) } union { graph <urn:tsl:g> { <urn:tsl:m3> <urn:tsl:id> ?x } } }');
ECHO BOTH $IF $EQU $LAST[1] "1;" "PASSED" "***FAILED";
ECHO BOTH ": 6. COUNT (DISTINCT) of STRDT () and the stored typed literal: " $LAST[1] "\n";

select TSL_RUN ('sparql select count (distinct ?x) where { { bind (strdt ("a typed literal longer than fifty characters, also stored by its digest", <urn:tsl:dt>) as ?x) } union { graph <urn:tsl:g> { <urn:tsl:m4> <urn:tsl:id> ?x } } }');
ECHO BOTH $IF $EQU $LAST[1] "1;" "PASSED" "***FAILED";
ECHO BOTH ": 7. the same for a typed literal of more than 50 characters: " $LAST[1] "\n";

select TSL_RUN ('sparql select count (distinct ?x) where { { bind (strlangdir ("abc", "en", "ltr") as ?x) } union { graph <urn:tsl:g> { <urn:tsl:m7> <urn:tsl:id> ?x } } }');
ECHO BOTH $IF $EQU $LAST[1] "1;" "PASSED" "***FAILED";
ECHO BOTH ": 8. COUNT (DISTINCT) of STRLANGDIR () and the stored literal: " $LAST[1] "\n";

select TSL_RUN ('sparql select count (*) where { { select distinct ?x where { { bind (strlang ("1008-00001", "en") as ?x) } union { graph <urn:tsl:g> { <urn:tsl:m1> <urn:tsl:id> ?x } } } } }');
ECHO BOTH $IF $EQU $LAST[1] "1;" "PASSED" "***FAILED";
ECHO BOTH ": 9. SELECT DISTINCT of STRLANG () and the stored literal: " $LAST[1] "\n";

select TSL_RUN ('sparql select ?x (count (*) as ?c) where { { bind (strlang ("1008-00001", "en") as ?x) } union { graph <urn:tsl:g> { <urn:tsl:m1> <urn:tsl:id> ?x } } } group by ?x');
ECHO BOTH $IF $EQU $LAST[1] "1008-00001,2;" "PASSED" "***FAILED";
ECHO BOTH ": 10. GROUP BY of STRLANG () and the stored literal: " $LAST[1] "\n";

select TSL_RUN ('sparql select count (distinct ?x) where { { bind (strlang ("1008-00001", "en") as ?x) } union { graph <urn:tsl:g> { <urn:tsl:m1> <urn:tsl:id> ?x } } }', 'SPARQL');
ECHO BOTH $IF $EQU $LAST[1] "1;" "PASSED" "***FAILED";
ECHO BOTH ": 11. 4 as the anonymous account SPARQL: " $LAST[1] "\n";

-- ---------------------------------------------------------------------------
-- 12-19: guards
-- ---------------------------------------------------------------------------

select TSL_RUN ('sparql select (strlang ("not stored anywhere", "en") = "not stored anywhere"@en as ?eq) where { }');
ECHO BOTH $IF $EQU $LAST[1] "1;" "PASSED" "***FAILED";
ECHO BOTH ": 12. STRLANG () = a literal that is not stored: " $LAST[1] "\n";

select TSL_RUN ('sparql select (strlang ("1008-00001", "de") = "1008-00001"@en as ?eq) (sameTerm (strlang ("1008-00001", "de"), "1008-00001"@en) as ?st) where { }');
ECHO BOTH $IF $EQU $LAST[1] "0,0;" "PASSED" "***FAILED";
ECHO BOTH ": 13. another language is another literal: " $LAST[1] "\n";

select TSL_RUN ('sparql select count (distinct ?x) where { { bind (strlang ("1008-00001", "en") as ?x) } union { bind (strlang ("1008-00001", "en") as ?x) } union { bind (strlang ("1008-00001", "de") as ?x) } }');
ECHO BOTH $IF $EQU $LAST[1] "2;" "PASSED" "***FAILED";
ECHO BOTH ": 14. COUNT (DISTINCT) of made literals: " $LAST[1] "\n";

select TSL_RUN ('sparql select (str (?x) as ?s) (lang (?x) as ?l) where { bind (strlang ("1008-00001", "en") as ?x) }');
ECHO BOTH $IF $EQU $LAST[1] "1008-00001,en;" "PASSED" "***FAILED";
ECHO BOTH ": 15. the value of STRLANG (): " $LAST[1] "\n";

select TSL_RUN ('sparql select (str (?x) as ?s) (str (datatype (?x)) as ?d) where { bind (strdt ("abc", <urn:tsl:dt>) as ?x) }');
ECHO BOTH $IF $EQU $LAST[1] "abc,urn:tsl:dt;" "PASSED" "***FAILED";
ECHO BOTH ": 16. the value of STRDT (): " $LAST[1] "\n";

select TSL_RUN ('sparql select (strdt ("12", xsd:integer) = 12 as ?eq) (strdt ("abc", <urn:tsl:dt>) = "abc"^^<urn:tsl:dt> as ?t) where { }');
ECHO BOTH $IF $EQU $LAST[1] "1,1;" "PASSED" "***FAILED";
ECHO BOTH ": 17. STRDT () to a number and to a stored typed literal: " $LAST[1] "\n";

--  A made literal inserted is the stored literal: found by the constant in
--  both graphs, one RDF_OBJ row.
sparql insert { graph <urn:tsl:g2> { <urn:tsl:m6> <urn:tsl:id> ?x } } where { bind (strlang ("1008-00001", "en") as ?x) };
select TSL_RUN ('sparql select ?g where { graph ?g { ?s <urn:tsl:id> "1008-00001"@en } } order by ?g');
ECHO BOTH $IF $EQU $LAST[1] "urn:tsl:g;urn:tsl:g2;" "PASSED" "***FAILED";
ECHO BOTH ": 18. STRLANG () inserted is found as the constant: " $LAST[1] "\n";

select count (*) from DB.DBA.RDF_OBJ where RO_VAL = '1008-00001' and bit_and (RO_DT_AND_LANG, 65535) <> 257;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": 19. one RDF_OBJ row for it: " $LAST[1] "\n";

-- ---------------------------------------------------------------------------
-- Cleanup
-- ---------------------------------------------------------------------------
sparql clear graph <urn:tsl:g>;
sparql clear graph <urn:tsl:g2>;
drop function TSL_RUN;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": cleanup STATE=" $STATE "\n";

ECHO BOTH "COMPLETED: STRLANG () / STRDT () literal and the stored literal (tsparql_strlang_eq.sql)\n";
