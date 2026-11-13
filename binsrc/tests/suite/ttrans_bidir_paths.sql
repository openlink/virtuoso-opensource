--
--  ttrans_bidir_paths.sql
--
--  A transitive derived table with both ends bound and t_no_cycles has a
--  result per path from the start to the end, and a search from the start
--  (t_direction 1) and one from the end (t_direction 2) agree on them.  A search
--  from both ends at once (t_direction 3, or the optimizer's choice) reported a
--  path again at every node where the two searches met, and joined halves
--  that share a node: in a -> b -> c, SPARQL "<a> p{2,} <c>" counted 2.
--
--  The last check compares the three directions on random graphs.
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

ECHO BOTH "STARTED: transitive paths searched from both ends\n";

sparql clear graph <urn:tbp:chain>;
sparql insert data { graph <urn:tbp:chain> { <urn:tbp:a> <urn:tbp:p> <urn:tbp:b> . <urn:tbp:b> <urn:tbp:p> <urn:tbp:c> . } };
sparql clear graph <urn:tbp:two>;
sparql insert data { graph <urn:tbp:two> { <urn:tbp:a> <urn:tbp:p> <urn:tbp:b> . <urn:tbp:a> <urn:tbp:p> <urn:tbp:d> . <urn:tbp:d> <urn:tbp:p> <urn:tbp:b> . } };
-- s -> x1..x4 -> y1..y4 -> t: 16 paths of 3 steps
sparql clear graph <urn:tbp:layers>;
sparql insert data { graph <urn:tbp:layers> {
  <urn:tbp:s> <urn:tbp:p> <urn:tbp:x1>, <urn:tbp:x2>, <urn:tbp:x3>, <urn:tbp:x4> .
  <urn:tbp:x1> <urn:tbp:p> <urn:tbp:y1>, <urn:tbp:y2>, <urn:tbp:y3>, <urn:tbp:y4> .
  <urn:tbp:x2> <urn:tbp:p> <urn:tbp:y1>, <urn:tbp:y2>, <urn:tbp:y3>, <urn:tbp:y4> .
  <urn:tbp:x3> <urn:tbp:p> <urn:tbp:y1>, <urn:tbp:y2>, <urn:tbp:y3>, <urn:tbp:y4> .
  <urn:tbp:x4> <urn:tbp:p> <urn:tbp:y1>, <urn:tbp:y2>, <urn:tbp:y3>, <urn:tbp:y4> .
  <urn:tbp:y1> <urn:tbp:p> <urn:tbp:t> . <urn:tbp:y2> <urn:tbp:p> <urn:tbp:t> .
  <urn:tbp:y3> <urn:tbp:p> <urn:tbp:t> . <urn:tbp:y4> <urn:tbp:p> <urn:tbp:t> . } };

create procedure ttrans_paths_count (in g varchar, in opts varchar, in from_iri varchar, in to_iri varchar)
{
  declare st, msg varchar;
  declare meta, rows any;
  st := '00000';
  exec (sprintf ('select count (*) from (select transitive t_in (1) t_out (2) %s S as s, O as o from DB.DBA.RDF_QUAD
      where G = iri_to_id (''%s'') and P = iri_to_id (''urn:tbp:p'')) k
     where k.s = iri_to_id (''%s'') and k.o = iri_to_id (''%s'')', opts, g, from_iri, to_iri),
    st, msg, vector (), 0, meta, rows);
  if (st <> '00000')
    return -1;
  return rows[0][0];
}
;

select ttrans_paths_count ('urn:tbp:chain', 't_direction 3 t_no_cycles', 'urn:tbp:a', 'urn:tbp:c');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": SQL, chain, t_direction 3, t_no_cycles, a to c: 1 path: " $LAST[1] "\n";

select ttrans_paths_count ('urn:tbp:two', 't_direction 3 t_min (2) t_no_cycles', 'urn:tbp:a', 'urn:tbp:b');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": SQL, two routes, t_direction 3, t_min 2, a to b: 1 path: " $LAST[1] "\n";

select ttrans_paths_count ('urn:tbp:layers', 't_direction 3 t_no_cycles', 'urn:tbp:s', 'urn:tbp:t');
ECHO BOTH $IF $EQU $LAST[1] 16 "PASSED" "***FAILED";
ECHO BOTH ": SQL, layers, t_direction 3, t_no_cycles, s to t: 16 paths: " $LAST[1] "\n";

select ttrans_paths_count ('urn:tbp:layers', 't_direction 1 t_no_cycles', 'urn:tbp:s', 'urn:tbp:t');
ECHO BOTH $IF $EQU $LAST[1] 16 "PASSED" "***FAILED";
ECHO BOTH ": guard, SQL, layers, t_direction 1, t_no_cycles, s to t: 16 paths: " $LAST[1] "\n";

select ttrans_paths_count ('urn:tbp:layers', 't_direction 3 t_distinct', 'urn:tbp:s', 'urn:tbp:t');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": guard, SQL, layers, t_direction 3, t_distinct, s to t: 1: " $LAST[1] "\n";

sparql select count (*) from <urn:tbp:chain> where { <urn:tbp:a> <urn:tbp:p>{2,} <urn:tbp:c> };
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": SPARQL, chain, <a> p{2,} <c>: 1: " $LAST[1] "\n";

sparql select count (*) from <urn:tbp:two> where { <urn:tbp:a> <urn:tbp:p>{2,} <urn:tbp:b> };
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": SPARQL, two routes, <a> p{2,} <b>: only a -> d -> b: 1: " $LAST[1] "\n";

sparql select count (*) from <urn:tbp:layers>
 where { ?a <urn:tbp:p> ?b option (transitive, t_no_cycles, t_in (?a), t_out (?b), t_direction 3) .
         filter (?a = <urn:tbp:s> && ?b = <urn:tbp:t>) };
ECHO BOTH $IF $EQU $LAST[1] 16 "PASSED" "***FAILED";
ECHO BOTH ": SPARQL, layers, T_DIRECTION 3, T_NO_CYCLES, s to t: 16 paths: " $LAST[1] "\n";

-- the three directions on random graphs
create table TTBP_E (S integer, O integer, primary key (S, O));

create procedure ttbp_count (in opts varchar, in s int, in t int)
{
  declare st, msg varchar;
  declare meta, rows any;
  st := '00000';
  exec (sprintf ('select count (*) from (select transitive t_in (1) t_out (2) %s S as s, O as o from TTBP_E) k where k.s = %d and k.o = %d', opts, s, t),
    st, msg, vector (), 0, meta, rows);
  if (st <> '00000')
    return -1;
  return rows[0][0];
}
;

create procedure ttbp_differ (in opts varchar)
{
  -- pairs of nodes where the search from both ends counts other than the search from the start
  declare seed, i, vs, vo, s, t, n, bad int;
  n := 8;
  bad := 0;
  for (seed := 1; seed <= 3; seed := seed + 1)
    {
      delete from TTBP_E;
      randomize (seed);
      for (i := 0; i < 18; i := i + 1)
        {
          vs := rnd (n);
          vo := rnd (n);
          if (vs <> vo)
            insert soft TTBP_E values (vs, vo);
        }
      for (s := 0; s < n; s := s + 1)
        for (t := 0; t < n; t := t + 1)
          {
            if (s <> t
                and ttbp_count ('t_direction 1 ' || opts, s, t) <> ttbp_count ('t_direction 3 ' || opts, s, t))
              bad := bad + 1;
          }
    }
  return bad;
}
;

select ttbp_differ ('t_no_cycles t_max (5)');
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": random graphs, t_no_cycles, t_max 5: pairs where t_direction 3 counts other than t_direction 1: " $LAST[1] "\n";

select ttbp_differ ('t_no_cycles t_min (2) t_max (5)');
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": random graphs, t_no_cycles, t_min 2, t_max 5: pairs that differ: " $LAST[1] "\n";

select ttbp_differ ('t_no_cycles');
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": random graphs, t_no_cycles, no t_max: pairs that differ: " $LAST[1] "\n";

select ttbp_differ ('t_distinct');
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": guard, random graphs, t_distinct: pairs that differ: " $LAST[1] "\n";

select ttbp_differ ('t_no_cycles t_shortest_only');
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": guard, random graphs, t_no_cycles, t_shortest_only: pairs that differ: " $LAST[1] "\n";

sparql clear graph <urn:tbp:chain>;
sparql clear graph <urn:tbp:two>;
sparql clear graph <urn:tbp:layers>;
drop procedure ttbp_differ;
drop procedure ttbp_count;
drop table TTBP_E;
drop procedure ttrans_paths_count;

ECHO BOTH "COMPLETED: transitive paths searched from both ends\n";
