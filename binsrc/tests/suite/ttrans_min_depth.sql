--
--  ttrans_min_depth.sql
--
--  A transitive derived table with T_MIN above 1 and its end bound recorded
--  the end as a result on a path of any length: in a -> b -> c, SPARQL
--  "<a> p{2,} <b>" was true and "<a> p{3,} <c>" counted 1.  With the end free,
--  T_MIN was applied.  A path of the right length to the same end, found
--  later, must still count.  (A search from both ends can count a path more
--  than once without t_distinct; those counts are checked in ttrans_bidir.sql.)
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

ECHO BOTH "STARTED: transitive derived table, T_MIN with the end bound\n";

-- chain: a -> b -> c
sparql clear graph <urn:tmin:chain>;
sparql insert data { graph <urn:tmin:chain> { <urn:tmin:a> <urn:tmin:p> <urn:tmin:b> . <urn:tmin:b> <urn:tmin:p> <urn:tmin:c> . } };
-- two routes to b: a -> b and a -> d -> b
sparql clear graph <urn:tmin:two>;
sparql insert data { graph <urn:tmin:two> { <urn:tmin:a> <urn:tmin:p> <urn:tmin:b> . <urn:tmin:a> <urn:tmin:p> <urn:tmin:d> . <urn:tmin:d> <urn:tmin:p> <urn:tmin:b> . } };

create procedure ttrans_min_count (in g varchar, in opts varchar, in from_iri varchar, in to_iri varchar)
{
  declare st, msg varchar;
  declare meta, rows any;
  st := '00000';
  exec (sprintf ('select count (*) from (select transitive t_in (1) t_out (2) %s S as s, O as o from DB.DBA.RDF_QUAD
      where G = iri_to_id (''%s'') and P = iri_to_id (''urn:tmin:p'')) k
     where k.s = iri_to_id (''%s'') and k.o = iri_to_id (''%s'')', opts, g, from_iri, to_iri),
    st, msg, vector (), 0, meta, rows);
  if (st <> '00000')
    return -1;
  return rows[0][0];
}
;

sparql select count (*) from <urn:tmin:chain> where { <urn:tmin:a> <urn:tmin:p>{2,} <urn:tmin:b> };
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": SPARQL, chain, <a> p{2,} <b>, b only 1 step away: 0: " $LAST[1] "\n";

sparql select count (*) from <urn:tmin:chain> where { <urn:tmin:a> <urn:tmin:p>{3,} <urn:tmin:c> };
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": SPARQL, chain, <a> p{3,} <c>, c 2 steps away: 0: " $LAST[1] "\n";

sparql select count (*) from <urn:tmin:chain> where { <urn:tmin:a> <urn:tmin:p>{2,3} <urn:tmin:b> };
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": SPARQL, chain, <a> p{2,3} <b>: 0: " $LAST[1] "\n";

sparql select count (*) from <urn:tmin:chain> where { <urn:tmin:a> <urn:tmin:p>{2,} ?o };
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": guard, SPARQL, chain, <a> p{2,} ?o, the end free: 1: " $LAST[1] "\n";

select ttrans_min_count ('urn:tmin:chain', 't_direction 1 t_min (2) t_no_cycles', 'urn:tmin:a', 'urn:tmin:b');
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": SQL, chain, t_direction 1, t_min 2, a to b: 0: " $LAST[1] "\n";

select ttrans_min_count ('urn:tmin:chain', 't_direction 2 t_min (2) t_no_cycles', 'urn:tmin:a', 'urn:tmin:b');
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": SQL, chain, t_direction 2, t_min 2, a to b: 0: " $LAST[1] "\n";

select ttrans_min_count ('urn:tmin:chain', 't_direction 3 t_min (2) t_no_cycles', 'urn:tmin:a', 'urn:tmin:b');
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": SQL, chain, t_direction 3, t_min 2, a to b: 0: " $LAST[1] "\n";

select ttrans_min_count ('urn:tmin:two', 't_direction 1 t_min (2) t_no_cycles', 'urn:tmin:a', 'urn:tmin:b');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": SQL, two routes, t_direction 1, t_min 2, a to b: 1: " $LAST[1] "\n";

select ttrans_min_count ('urn:tmin:two', 't_direction 2 t_min (2) t_no_cycles', 'urn:tmin:a', 'urn:tmin:b');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": SQL, two routes, t_direction 2, t_min 2, a to b: 1: " $LAST[1] "\n";

select ttrans_min_count ('urn:tmin:two', 't_direction 1 t_min (1) t_no_cycles', 'urn:tmin:a', 'urn:tmin:b');
ECHO BOTH $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";
ECHO BOTH ": guard, SQL, two routes, t_direction 1, t_min 1, a to b, both paths: 2: " $LAST[1] "\n";

-- t_distinct visits a node once, at its shortest distance, so t_min applies to that distance:
-- b is 1 step from a, the 2 steps through d do not count, from one end or both
select ttrans_min_count ('urn:tmin:two', 't_direction 1 t_min (2) t_distinct', 'urn:tmin:a', 'urn:tmin:b');
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": SQL, two routes, t_direction 1, t_min 2, t_distinct, a to b, distance 1: 0: " $LAST[1] "\n";

select ttrans_min_count ('urn:tmin:two', 't_direction 2 t_min (2) t_distinct', 'urn:tmin:a', 'urn:tmin:b');
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": SQL, two routes, t_direction 2, t_min 2, t_distinct, a to b, distance 1: 0: " $LAST[1] "\n";

select ttrans_min_count ('urn:tmin:two', 't_direction 3 t_min (2) t_distinct', 'urn:tmin:a', 'urn:tmin:b');
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": SQL, two routes, t_direction 3, t_min 2, t_distinct, a to b, distance 1: 0: " $LAST[1] "\n";

select ttrans_min_count ('urn:tmin:two', 't_direction 3 t_min (1) t_distinct', 'urn:tmin:a', 'urn:tmin:b');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": guard, SQL, two routes, t_direction 3, t_min 1, t_distinct, a to b: 1: " $LAST[1] "\n";

select ttrans_min_count ('urn:tmin:chain', 't_direction 3 t_min (2) t_distinct', 'urn:tmin:a', 'urn:tmin:c');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": guard, SQL, chain, t_direction 3, t_min 2, t_distinct, a to c, distance 2: 1: " $LAST[1] "\n";

select ttrans_min_count ('urn:tmin:two', 't_direction 3 t_min (2) t_no_cycles', 'urn:tmin:a', 'urn:tmin:b');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": SQL, two routes, t_direction 3, t_min 2, t_no_cycles, a to b, the path through d: 1: " $LAST[1] "\n";

sparql clear graph <urn:tmin:chain>;
sparql clear graph <urn:tmin:two>;
drop procedure ttrans_min_count;

ECHO BOTH "COMPLETED: transitive derived table, T_MIN with the end bound\n";
