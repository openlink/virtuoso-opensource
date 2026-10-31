--
--  tqn_stack.sql
--
--  Each query node calls the next one, so a long chain of nodes uses the
--  thread stack in proportion to its length.  A SPARQL query with many
--  OPTIONALs that match data must give SR178 when the stack runs low.
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

ECHO BOTH "STARTED: a long chain of query nodes and the thread stack\n";

sparql clear graph <urn:tqn_stack>;

create procedure TQN_STACK_FILL ()
{
  declare ses any;
  declare s, p int;
  ses := string_output ();
  for (s := 1; s <= 50; s := s + 1)
    for (p := 0; p <= 100; p := p + 1)
      http (sprintf ('<urn:tqn_stack:s%d> <urn:tqn_stack:p%d> %d .\n', s, p, s * 1000 + p), ses);
  ttlp (string_output_string (ses), '', 'urn:tqn_stack');
}
;

-- the count of ?s with N OPTIONALs, or the state and error code it fails with
create procedure TQN_STACK_RUN (in n int)
{
  declare q, st, msg varchar;
  declare md, rs any;
  declare i int;
  q := 'sparql select count (*) from <urn:tqn_stack> where { ?s <urn:tqn_stack:p0> ?o0 .';
  for (i := 1; i <= n; i := i + 1)
    q := q || sprintf (' optional { ?s <urn:tqn_stack:p%d> ?o%d }', i, i);
  q := q || ' }';
  st := '00000';
  exec (q, st, msg, vector (), 0, md, rs);
  if (st = '00000')
    return cast (rs[0][0] as varchar);
  return st || ' ' || subseq (msg, 0, 5);
}
;

TQN_STACK_FILL ();

sparql select count (*) from <urn:tqn_stack> where { ?s ?p ?o };
ECHO BOTH $IF $EQU $LAST[1] 5050 "PASSED" "***FAILED";
ECHO BOTH ": 50 subjects with 101 predicates each loaded: " $LAST[1] " triples\n";

select TQN_STACK_RUN (10);
ECHO BOTH $IF $EQU $LAST[1] 50 "PASSED" "***FAILED";
ECHO BOTH ": guard, 10 OPTIONALs: " $LAST[1] " subjects\n";

-- with a larger thread stack the query can complete, so the count is also accepted
select case when r = '50' or r = '42000 SR178' then 'OK' else r end from (select TQN_STACK_RUN (80) as r) x;
ECHO BOTH $IF $EQU $LAST[1] OK "PASSED" "***FAILED";
ECHO BOTH ": 80 OPTIONALs give the count or SR178: " $LAST[1] "\n";

select case when r = '50' or r = '42000 SR178' then 'OK' else r end from (select TQN_STACK_RUN (100) as r) x;
ECHO BOTH $IF $EQU $LAST[1] OK "PASSED" "***FAILED";
ECHO BOTH ": 100 OPTIONALs give the count or SR178: " $LAST[1] "\n";

select 1;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": a query after the long chains runs\n";

sparql clear graph <urn:tqn_stack>;
drop procedure TQN_STACK_FILL;
drop procedure TQN_STACK_RUN;

ECHO BOTH "COMPLETED: a long chain of query nodes and the thread stack\n";
