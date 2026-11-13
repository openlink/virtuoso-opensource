--
--  ttrans_bidir.sql
--
--  A transitive derived table with both ends bound may be searched from both
--  ends at once (t_direction 3, or chosen by the optimizer).  With t_distinct
--  every node is visited once, so the two ends are joined once, as they are by a
--  search from one end; the search from both ends gave a row for every node
--  where the two searches met: s to t in a graph of two layers of four gave 8
--  rows where 1 is right.
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

ECHO BOTH "STARTED: transitive derived table searched from both ends\n";

sparql clear graph <urn:tbid:g>;
sparql insert data { graph <urn:tbid:g> {
  <urn:tbid:s> <urn:tbid:p> <urn:tbid:x1>, <urn:tbid:x2>, <urn:tbid:x3>, <urn:tbid:x4> .
  <urn:tbid:x1> <urn:tbid:p> <urn:tbid:y1>, <urn:tbid:y2>, <urn:tbid:y3>, <urn:tbid:y4> .
  <urn:tbid:x2> <urn:tbid:p> <urn:tbid:y1>, <urn:tbid:y2>, <urn:tbid:y3>, <urn:tbid:y4> .
  <urn:tbid:x3> <urn:tbid:p> <urn:tbid:y1>, <urn:tbid:y2>, <urn:tbid:y3>, <urn:tbid:y4> .
  <urn:tbid:x4> <urn:tbid:p> <urn:tbid:y1>, <urn:tbid:y2>, <urn:tbid:y3>, <urn:tbid:y4> .
  <urn:tbid:y1> <urn:tbid:p> <urn:tbid:t> . <urn:tbid:y2> <urn:tbid:p> <urn:tbid:t> .
  <urn:tbid:y3> <urn:tbid:p> <urn:tbid:t> . <urn:tbid:y4> <urn:tbid:p> <urn:tbid:t> .
  <urn:tbid:u> <urn:tbid:p> <urn:tbid:v> . } };

create procedure ttrans_bidir_count (in opts varchar, in from_iri varchar, in to_iri varchar)
{
  declare st, msg varchar;
  declare meta, rows any;
  st := '00000';
  exec (sprintf ('select count (*) from (select transitive t_in (1) t_out (2) %s S as s, O as o from DB.DBA.RDF_QUAD
      where G = iri_to_id (''urn:tbid:g'') and P = iri_to_id (''urn:tbid:p'')) k
     where k.s = iri_to_id (''%s'') and k.o = iri_to_id (''%s'')', opts, from_iri, to_iri),
    st, msg, vector (), 0, meta, rows);
  if (st <> '00000')
    return -1;
  return rows[0][0];
}
;

select ttrans_bidir_count ('t_direction 3 t_distinct', 'urn:tbid:s', 'urn:tbid:t');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": SQL, t_direction 3, t_distinct, s to t: 1 row: " $LAST[1] "\n";

select ttrans_bidir_count ('t_direction 3 t_distinct t_shortest_only', 'urn:tbid:s', 'urn:tbid:t');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": SQL, t_direction 3, t_distinct, t_shortest_only, s to t: 1 row: " $LAST[1] "\n";

select ttrans_bidir_count ('t_direction 3 t_distinct', 'urn:tbid:x2', 'urn:tbid:t');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": SQL, t_direction 3, t_distinct, x2 to t: 1 row: " $LAST[1] "\n";

select ttrans_bidir_count ('t_direction 3 t_distinct', 'urn:tbid:s', 'urn:tbid:v');
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": guard, SQL, t_direction 3, t_distinct, s to v, not connected: 0 rows: " $LAST[1] "\n";

select ttrans_bidir_count ('t_direction 1 t_distinct', 'urn:tbid:s', 'urn:tbid:t');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": guard, SQL, t_direction 1, t_distinct, s to t: 1 row: " $LAST[1] "\n";

select ttrans_bidir_count ('t_direction 2 t_distinct', 'urn:tbid:s', 'urn:tbid:t');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": guard, SQL, t_direction 2, t_distinct, s to t: 1 row: " $LAST[1] "\n";

select count (*) from (select transitive t_in (1) t_out (2) t_direction 3 t_distinct S as s, O as o, t_step ('step_no') as st
    from DB.DBA.RDF_QUAD where G = iri_to_id ('urn:tbid:g') and P = iri_to_id ('urn:tbid:p')) k
 where k.s = iri_to_id ('urn:tbid:s') and k.o = iri_to_id ('urn:tbid:t');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": SQL, t_direction 3, t_distinct, with the step number: 1 row: " $LAST[1] "\n";

sparql select count (*) from <urn:tbid:g>
 where { ?a <urn:tbid:p> ?b option (transitive, t_distinct, t_in (?a), t_out (?b), t_direction 3) .
         filter (?a = <urn:tbid:s> && ?b = <urn:tbid:t>) };
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": SPARQL, T_DIRECTION 3, T_DISTINCT, s to t: 1 row: " $LAST[1] "\n";

sparql select count (*) from <urn:tbid:g> where { <urn:tbid:s> <urn:tbid:p>* <urn:tbid:t> };
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": guard, SPARQL, s p* t, the optimizer's plan: 1 row: " $LAST[1] "\n";

sparql clear graph <urn:tbid:g>;
drop procedure ttrans_bidir_count;

ECHO BOTH "COMPLETED: transitive derived table searched from both ends\n";
