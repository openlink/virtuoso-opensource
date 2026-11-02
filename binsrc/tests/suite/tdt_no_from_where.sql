--
--  tdt_no_from_where.sql
--
--  A WHERE condition over a derived table that has no FROM of its own, such as
--  (select 1 as x) s, decides which rows come out.
--
--  On develop/7 the condition was moved into the derived table, which had no
--  table to place it with, and was dropped: select x from (select 1 as x) s
--  where x = 2 answered a row, and so did NOT EXISTS of a non-empty table or
--  EXISTS of an empty one.  SPARQL builds such derived tables for a group made
--  only of BIND, so BIND ... FILTER [NOT] EXISTS and a BIND left of MINUS
--  kept rows they should have removed.
--
--  1-16 are tests of the change (each fails before it); 17-24 are guards and
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

ECHO BOTH "STARTED: WHERE over a derived table without FROM (tdt_no_from_where.sql)\n";

sparql clear graph <urn:tdnf:g>;
sparql insert data { graph <urn:tdnf:g> { <urn:tdnf:s> <urn:tdnf:p> "o" . } };
select count (*) from DB.DBA.RDF_QUAD where G = iri_to_id ('urn:tdnf:g');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": one triple loaded: " $LAST[1] "\n";

--  Every row of a query: its columns joined by ',' and each row ended by ';';
--  'ERR <message>' when it fails.
create function TDNF_RUN (in _stmt varchar, in _as varchar := null) returns varchar
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
-- 1-12: SQL
-- ---------------------------------------------------------------------------

select TDNF_RUN ('select count (*) from (select 1 as x) s where x = 2');
ECHO BOTH $IF $EQU $LAST[1] "0;" "PASSED" "***FAILED";
ECHO BOTH ": 1. x = 2 over (select 1 as x): " $LAST[1] "\n";

select TDNF_RUN ('select x from (select 1 as x) s where x = 2');
ECHO BOTH $IF $EQU $LAST[1] "" "PASSED" "***FAILED";
ECHO BOTH ": 2. the rows of the same: [" $LAST[1] "]\n";

select TDNF_RUN ('select count (*) from (select 1 as x) s where x <> 1');
ECHO BOTH $IF $EQU $LAST[1] "0;" "PASSED" "***FAILED";
ECHO BOTH ": 3. x <> 1: " $LAST[1] "\n";

select TDNF_RUN ('select count (*) from (select 1 as x) s where x = 2 or x = 3');
ECHO BOTH $IF $EQU $LAST[1] "0;" "PASSED" "***FAILED";
ECHO BOTH ": 4. x = 2 or x = 3: " $LAST[1] "\n";

select TDNF_RUN ('select count (*) from (select 1 as x) s where not exists (select 1 from DB.DBA.SYS_USERS)');
ECHO BOTH $IF $EQU $LAST[1] "0;" "PASSED" "***FAILED";
ECHO BOTH ": 5. NOT EXISTS of a non-empty table: " $LAST[1] "\n";

select TDNF_RUN ('select count (*) from (select 1 as x) s where exists (select 1 from DB.DBA.SYS_USERS where U_NAME = ''no such user'')');
ECHO BOTH $IF $EQU $LAST[1] "0;" "PASSED" "***FAILED";
ECHO BOTH ": 6. EXISTS of no rows: " $LAST[1] "\n";

select TDNF_RUN ('select count (*) from (select 1 as x) s where exists (select 1 from DB.DBA.SYS_USERS u where u.U_ID = s.x + 100000)');
ECHO BOTH $IF $EQU $LAST[1] "0;" "PASSED" "***FAILED";
ECHO BOTH ": 7. EXISTS correlated with s.x, no rows: " $LAST[1] "\n";

select TDNF_RUN ('select count (*) from (select 1 as x) s where (select count (*) from DB.DBA.SYS_USERS) = 0');
ECHO BOTH $IF $EQU $LAST[1] "0;" "PASSED" "***FAILED";
ECHO BOTH ": 8. a scalar subquery compared: " $LAST[1] "\n";

select TDNF_RUN ('select count (*) from (select 1 as x) s where 1 in (select 2 from DB.DBA.SYS_USERS)');
ECHO BOTH $IF $EQU $LAST[1] "0;" "PASSED" "***FAILED";
ECHO BOTH ": 9. IN a subquery: " $LAST[1] "\n";

select TDNF_RUN ('select count (*) from (select 1 as x) s where s.x > (select count (*) from DB.DBA.SYS_USERS)');
ECHO BOTH $IF $EQU $LAST[1] "0;" "PASSED" "***FAILED";
ECHO BOTH ": 10. s.x against a scalar subquery: " $LAST[1] "\n";

select TDNF_RUN ('select count (*) from (select 1 as x) s, (select 2 as y) t where s.x = t.y');
ECHO BOTH $IF $EQU $LAST[1] "0;" "PASSED" "***FAILED";
ECHO BOTH ": 11. two such derived tables joined on unequal values: " $LAST[1] "\n";

select TDNF_RUN ('select count (*) from (select 1 as x, 2 as y) s where x = y');
ECHO BOTH $IF $EQU $LAST[1] "0;" "PASSED" "***FAILED";
ECHO BOTH ": 12. two columns compared: " $LAST[1] "\n";

-- ---------------------------------------------------------------------------
-- 13-16: SPARQL
-- ---------------------------------------------------------------------------

select TDNF_RUN ('sparql select count (*) where { bind (1 as ?one) filter not exists { graph <urn:tdnf:g> { ?s ?p ?o } } }');
ECHO BOTH $IF $EQU $LAST[1] "0;" "PASSED" "***FAILED";
ECHO BOTH ": 13. BIND then FILTER NOT EXISTS of a stored triple: " $LAST[1] "\n";

select TDNF_RUN ('sparql select count (*) where { { bind ("o" as ?x) } minus { graph <urn:tdnf:g> { ?s ?p ?x } } }');
ECHO BOTH $IF $EQU $LAST[1] "0;" "PASSED" "***FAILED";
ECHO BOTH ": 14. BIND MINUS the stored triple with that value: " $LAST[1] "\n";

select TDNF_RUN ('sparql select count (*) where { bind (1 as ?one) filter exists { graph <urn:tdnf:g> { <urn:tdnf:none> ?p ?o } } }');
ECHO BOTH $IF $EQU $LAST[1] "0;" "PASSED" "***FAILED";
ECHO BOTH ": 15. BIND then FILTER EXISTS of nothing: " $LAST[1] "\n";

select TDNF_RUN ('sparql select count (*) where { bind (1 as ?one) filter not exists { graph <urn:tdnf:g> { ?s ?p ?o } } }', 'SPARQL');
ECHO BOTH $IF $EQU $LAST[1] "0;" "PASSED" "***FAILED";
ECHO BOTH ": 16. 13 as the anonymous account SPARQL: " $LAST[1] "\n";

-- ---------------------------------------------------------------------------
-- 17-24: guards
-- ---------------------------------------------------------------------------

select TDNF_RUN ('select x from (select 1 as x) s where x = 1');
ECHO BOTH $IF $EQU $LAST[1] "1;" "PASSED" "***FAILED";
ECHO BOTH ": 17. x = 1 keeps the row: " $LAST[1] "\n";

select TDNF_RUN ('select count (*) from (select 1 as x) s where 1 = 0');
ECHO BOTH $IF $EQU $LAST[1] "0;" "PASSED" "***FAILED";
ECHO BOTH ": 18. a constant false condition: " $LAST[1] "\n";

select TDNF_RUN ('select count (*) from (select 1 as x) s where exists (select 1 from DB.DBA.SYS_USERS) and not exists (select 1 from DB.DBA.SYS_USERS where U_NAME = ''no such user'')');
ECHO BOTH $IF $EQU $LAST[1] "1;" "PASSED" "***FAILED";
ECHO BOTH ": 19. true EXISTS and NOT EXISTS keep the row: " $LAST[1] "\n";

select TDNF_RUN ('select count (*) from (select 1 as x from DB.DBA.SYS_USERS where U_NAME = ''dba'') s where x = 2');
ECHO BOTH $IF $EQU $LAST[1] "0;" "PASSED" "***FAILED";
ECHO BOTH ": 20. the derived table with a FROM: " $LAST[1] "\n";

select TDNF_RUN ('select s.x, t.y from (select 1 as x) s, (select 2 as y) t where t.y = s.x + 1');
ECHO BOTH $IF $EQU $LAST[1] "1,2;" "PASSED" "***FAILED";
ECHO BOTH ": 21. two such derived tables joined on equal values: " $LAST[1] "\n";

select TDNF_RUN ('sparql select count (*) where { bind (1 as ?x) filter (?x = 2) }');
ECHO BOTH $IF $EQU $LAST[1] "0;" "PASSED" "***FAILED";
ECHO BOTH ": 22. BIND then FILTER on the value: " $LAST[1] "\n";

select TDNF_RUN ('sparql select count (*) where { bind (1 as ?one) filter exists { graph <urn:tdnf:g> { ?s ?p ?o } } }');
ECHO BOTH $IF $EQU $LAST[1] "1;" "PASSED" "***FAILED";
ECHO BOTH ": 23. BIND then FILTER EXISTS of a stored triple: " $LAST[1] "\n";

select TDNF_RUN ('sparql select count (*) where { values ?one { 1 } filter not exists { graph <urn:tdnf:g> { ?s ?p ?o } } }');
ECHO BOTH $IF $EQU $LAST[1] "0;" "PASSED" "***FAILED";
ECHO BOTH ": 24. VALUES then FILTER NOT EXISTS of a stored triple: " $LAST[1] "\n";

-- ---------------------------------------------------------------------------
-- Cleanup
-- ---------------------------------------------------------------------------
sparql clear graph <urn:tdnf:g>;
drop function TDNF_RUN;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": cleanup STATE=" $STATE "\n";

ECHO BOTH "COMPLETED: WHERE over a derived table without FROM (tdt_no_from_where.sql)\n";
