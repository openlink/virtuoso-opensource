--
--  ttrans_target.sql
--
--  A transitive derived table bound at both ends, its start by an earlier
--  table and its end by a constant, runs from the start with the end as its
--  target.  The target was read for each input row from a slot computed once
--  for the whole query, so every row after the first was compared with a
--  wrong target and its paths were lost: SPARQL "?pa skos:broader* <c>" with
--  FROM gave 1 of 3 rows.
--
--  The rows are checked by a weighted sum, m1 = 1, m2 = 10, m3 = 100,
--  m4 = 1000, m5 = 10000, so a sum names the exact matters found.
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

ECHO BOTH "STARTED: transitive derived table with both ends bound\n";

sparql clear graph <urn:ttrans:target>;
sparql insert data { graph <urn:ttrans:target> {
  <urn:ttrans:mid> <urn:ttrans:broader> <urn:ttrans:root> .
  <urn:ttrans:leaf> <urn:ttrans:broader> <urn:ttrans:mid> .
  <urn:ttrans:side> <urn:ttrans:broader> <urn:ttrans:root> .
  <urn:ttrans:lone> <urn:ttrans:broader> <urn:ttrans:other> .
  <urn:ttrans:m1> <urn:ttrans:area> <urn:ttrans:leaf> ; <urn:ttrans:id> "m1" .
  <urn:ttrans:m2> <urn:ttrans:area> <urn:ttrans:mid> ; <urn:ttrans:id> "m2" .
  <urn:ttrans:m3> <urn:ttrans:area> <urn:ttrans:leaf> ; <urn:ttrans:id> "m3" .
  <urn:ttrans:m4> <urn:ttrans:area> <urn:ttrans:side> ; <urn:ttrans:id> "m4" .
  <urn:ttrans:m5> <urn:ttrans:area> <urn:ttrans:lone> ; <urn:ttrans:id> "m5" . } };

create function ttrans_w (in m varchar) returns integer
{
  return case m when 'urn:ttrans:m1' then 1 when 'urn:ttrans:m2' then 10 when 'urn:ttrans:m3' then 100
    when 'urn:ttrans:m4' then 1000 when 'urn:ttrans:m5' then 10000 else 100000 end;
}
;

create procedure ttrans_both_ends (in dir integer, in min_depth integer, in tgt varchar)
{
  -- the start comes from the matters, scanned first; the end is a constant
  declare st, msg, txt varchar;
  declare meta, rows any;
  txt := sprintf ('select count (*), sum (ttrans_w (id_to_iri (t1.S)))
      from DB.DBA.RDF_QUAD t1,
           (select transitive t_in (1) t_out (2) %s t_min (%d) t_distinct S as s, O as o from DB.DBA.RDF_QUAD
             where G = iri_to_id (''urn:ttrans:target'') and P = iri_to_id (''urn:ttrans:broader'')) dt
     where t1.G = iri_to_id (''urn:ttrans:target'') and t1.P = iri_to_id (''urn:ttrans:area'')
       and dt.s = t1.O and dt.o = iri_to_id (''%s'')
     option (order)',
    case when dir > 0 then sprintf ('t_direction %d', dir) else '' end, min_depth, tgt);
  st := '00000';
  exec (txt, st, msg, vector (), 0, meta, rows);
  if (st <> '00000')
    return vector (-1, st);
  return vector (rows[0][0], rows[0][1]);
}
;

select aref (ttrans_both_ends (1, 0, 'urn:ttrans:mid'), 1);
ECHO BOTH $IF $EQU $LAST[1] 111 "PASSED" "***FAILED";
ECHO BOTH ": SQL, T_DIRECTION 1, T_MIN 0, end mid: m1 m2 m3 (sum 111): " $LAST[1] "\n";

select aref (ttrans_both_ends (0, 0, 'urn:ttrans:mid'), 1);
ECHO BOTH $IF $EQU $LAST[1] 111 "PASSED" "***FAILED";
ECHO BOTH ": SQL, no T_DIRECTION, T_MIN 0, end mid: m1 m2 m3 (sum 111): " $LAST[1] "\n";

select aref (ttrans_both_ends (1, 1, 'urn:ttrans:mid'), 1);
ECHO BOTH $IF $EQU $LAST[1] 101 "PASSED" "***FAILED";
ECHO BOTH ": SQL, T_DIRECTION 1, T_MIN 1, end mid: m1 m3 (sum 101): " $LAST[1] "\n";

select aref (ttrans_both_ends (1, 1, 'urn:ttrans:root'), 1);
ECHO BOTH $IF $EQU $LAST[1] 1111 "PASSED" "***FAILED";
ECHO BOTH ": SQL, T_DIRECTION 1, T_MIN 1, end root, paths of 1 and 2 steps: m1 m2 m3 m4 (sum 1111): " $LAST[1] "\n";

select aref (ttrans_both_ends (1, 1, 'urn:ttrans:root'), 0);
ECHO BOTH $IF $EQU $LAST[1] 4 "PASSED" "***FAILED";
ECHO BOTH ": SQL, T_DIRECTION 1, T_MIN 1, end root: 4 rows: " $LAST[1] "\n";

select aref (ttrans_both_ends (2, 0, 'urn:ttrans:mid'), 1);
ECHO BOTH $IF $EQU $LAST[1] 111 "PASSED" "***FAILED";
ECHO BOTH ": guard, SQL, T_DIRECTION 2 (from the end): m1 m2 m3 (sum 111): " $LAST[1] "\n";

-- SPARQL in the written order and with the direction given, so the plan does not depend on the cost model
sparql define sql:select-option "order" select ?id from <urn:ttrans:target>
 where { ?m <urn:ttrans:area> ?pa ; <urn:ttrans:id> ?id .
         ?pa <urn:ttrans:broader> ?top option (transitive, t_distinct, t_in (?pa), t_out (?top), t_min (0), t_direction 1) .
         filter (?top = <urn:ttrans:mid>) } order by ?id;
ECHO BOTH $IF $EQU $ROWCNT 3 "PASSED" "***FAILED";
ECHO BOTH ": SPARQL, T_DIRECTION 1, T_MIN 0, end mid: 3 rows: " $ROWCNT "\n";
ECHO BOTH $IF $EQU $LAST[1] "m3" "PASSED" "***FAILED";
ECHO BOTH ": SPARQL, T_DIRECTION 1, T_MIN 0, end mid: last m3: " $LAST[1] "\n";

sparql define sql:select-option "order" select ?id from <urn:ttrans:target>
 where { ?m <urn:ttrans:area> ?pa ; <urn:ttrans:id> ?id .
         ?pa <urn:ttrans:broader> ?top option (transitive, t_distinct, t_in (?pa), t_out (?top), t_min (1), t_direction 1) .
         filter (?top = <urn:ttrans:root>) } order by ?id;
ECHO BOTH $IF $EQU $ROWCNT 4 "PASSED" "***FAILED";
ECHO BOTH ": SPARQL, T_DIRECTION 1, T_MIN 1, end root: 4 rows: " $ROWCNT "\n";
ECHO BOTH $IF $EQU $LAST[1] "m4" "PASSED" "***FAILED";
ECHO BOTH ": SPARQL, T_DIRECTION 1, T_MIN 1, end root: last m4: " $LAST[1] "\n";

-- the reported form: a property path with FROM
sparql select (count (*) as ?n) from <urn:ttrans:target>
 where { ?m <urn:ttrans:area> ?pa ; <urn:ttrans:id> ?id . ?pa <urn:ttrans:broader>* <urn:ttrans:mid> };
ECHO BOTH $IF $EQU $LAST[1] 3 "PASSED" "***FAILED";
ECHO BOTH ": SPARQL with FROM, ?pa broader* mid: 3 matters: " $LAST[1] "\n";

select count (*), sum (ttrans_w (id_to_iri (x."m")))
  from (sparql select ?m where { graph <urn:ttrans:target> { ?pa <urn:ttrans:broader>* <urn:ttrans:mid> . ?m <urn:ttrans:area> ?pa } }) x;
ECHO BOTH $IF $EQU $LAST[2] 111 "PASSED" "***FAILED";
ECHO BOTH ": guard, SPARQL from the end: m1 m2 m3 (sum 111): " $LAST[2] "\n";

sparql clear graph <urn:ttrans:target>;
drop procedure ttrans_both_ends;
drop function ttrans_w;

ECHO BOTH "COMPLETED: transitive derived table with both ends bound\n";
