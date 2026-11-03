--  test_graph_limits.sql
--
--  Graph analytics: resource limits are enforced while the graph is being
--  read, not after it has been materialised.  Test Group O.
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
--  WHY THIS FILE EXISTS
--
--  [Graph] MaxNodes used to be checked only after the loader had read the
--  whole graph out of RDF_QUAD and built a snapshot from it.  Refusing a
--  120,000-node graph therefore cost the entire scan and its allocations:
--  the limit amplified an over-large request instead of bounding it.  Node
--  count alone also does not bound memory on a dense graph, so there is a
--  companion triple limit.
--
--  GRAPH_SET_LIMIT() adjusts the limits on a running server (DBA only),
--  which is both an operator capability and what lets these run without a
--  purpose-built INI file.

ECHO BOTH "STARTED: graph analytics limits test suite\n";

-- A graph with a known, modest size: 200 nodes / 400 edges.
create procedure GLIM_MAKE ()
{
  declare i int;
  declare gid IRI_ID;
  gid := iri_to_id ('urn:graph:lim:g');
  delete from DB.DBA.RDF_QUAD where G = gid;
  commit work;
  for (i := 0; i < 200; i := i + 1)
    {
      DB.DBA.RDF_QUAD_URI ('urn:graph:lim:g', sprintf ('urn:graph:lim:n%d', i),
                           'urn:graph:lim:e', sprintf ('urn:graph:lim:n%d', mod (i + 1, 200)));
      DB.DBA.RDF_QUAD_URI ('urn:graph:lim:g', sprintf ('urn:graph:lim:n%d', i),
                           'urn:graph:lim:e', sprintf ('urn:graph:lim:n%d', mod (i + 7, 200)));
    }
  commit work;
}
;

create procedure GLIM_STATE (in txt varchar)
{
  declare st, msg varchar;
  declare mdta, rset any;
  st := '00000';
  msg := '';
  exec (txt, st, msg, vector (), 0, mdta, rset);
  return st;
}
;

GLIM_MAKE ();

-- ============================================================================
-- Group O: limits are enforced, and enforced early
-- ============================================================================

-- O.1: within the limits, the graph loads
select GRAPH_SET_LIMIT ('MaxGraphNodes', 100000);
select GRAPH_SET_LIMIT ('MaxGraphTriples', 1000000);
select cast (GRAPH_DEGREE_CENTRALITY ('urn:graph:lim:n0', 'urn:graph:lim:g') as integer);
ECHO BOTH ": O1 degree within limits = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] 4 "PASSED" "***FAILED";

-- O.2: a node limit below the graph refuses it
select GRAPH_SET_LIMIT ('MaxGraphNodes', 50);
select GLIM_STATE ('select GRAPH_DEGREE_CENTRALITY (''urn:graph:lim:n0'', ''urn:graph:lim:g'')');
ECHO BOTH ": O2 node limit exceeded state = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] 42006 "PASSED" "***FAILED";

-- O.3: raising it again lets the same graph through, so the refusal is the
-- limit talking and not a poisoned cache entry
select GRAPH_SET_LIMIT ('MaxGraphNodes', 100000);
select cast (GRAPH_DEGREE_CENTRALITY ('urn:graph:lim:n0', 'urn:graph:lim:g') as integer);
ECHO BOTH ": O3 degree after raising limit = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] 4 "PASSED" "***FAILED";

-- O.4: the triple limit is enforced independently of the node limit
select GRAPH_SET_LIMIT ('MaxGraphTriples', 10);
select GLIM_STATE ('select GRAPH_DEGREE_CENTRALITY (''urn:graph:lim:n0'', ''urn:graph:lim:g'')');
ECHO BOTH ": O4 triple limit exceeded state = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] 42006 "PASSED" "***FAILED";

select GRAPH_SET_LIMIT ('MaxGraphTriples', 1000000);
select cast (GRAPH_DEGREE_CENTRALITY ('urn:graph:lim:n0', 'urn:graph:lim:g') as integer);
ECHO BOTH ": O5 degree after restoring triple limit = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] 4 "PASSED" "***FAILED";

-- O.6: an unknown limit name is rejected rather than silently ignored
select GLIM_STATE ('select GRAPH_SET_LIMIT (''NoSuchLimit'', 1)');
ECHO BOTH ": O6 unknown limit name state = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] 42002 "PASSED" "***FAILED";

-- O.7: GRAPH_SET_LIMIT is DBA-only -- a non-dba user must not be able to
-- raise a limit an administrator has set
select GRAPH_SEC_STATE ('gtest2', 'select GRAPH_SET_LIMIT (''MaxGraphNodes'', 1)');
ECHO BOTH ": O7 GRAPH_SET_LIMIT as non-dba = " $LAST[1] "\n";
ECHO BOTH $IF $NEQ $LAST[1] 00000 "PASSED" "***FAILED";

-- O.8: the workspace budget is adjustable, and a call that does not fit
-- reports 42008 rather than running
select GRAPH_SET_LIMIT ('MaxWorkspace', 1048576);
select GLIM_STATE ('select GRAPH_BETWEENNESS (''urn:graph:lim:n0'', ''urn:graph:lim:g'')');
ECHO BOTH ": O8 workspace budget of 1MB, 200 nodes = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] 00000 "PASSED" "***FAILED";

select GRAPH_SET_LIMIT ('MaxWorkspace', 67108864);
ECHO BOTH ": O9 workspace budget restored = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] 67108864 "PASSED" "***FAILED";

-- O.9b - O.9f: the byte-sized limits take the suffixes their INI keys take,
-- and refuse a value they cannot read rather than guess at it.
select GRAPH_SET_LIMIT ('MaxWorkspace', '64m');
ECHO BOTH ": O9b MaxWorkspace '64m' = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] 67108864 "PASSED" "***FAILED";

select GRAPH_SET_LIMIT ('MaxWorkspace', '64MB');
ECHO BOTH ": O9f MaxWorkspace '64MB' = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] 67108864 "PASSED" "***FAILED";

select GRAPH_SET_LIMIT ('CacheMax', '1G');
ECHO BOTH ": O9c CacheMax '1G' = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] 1073741824 "PASSED" "***FAILED";

select GRAPH_SET_LIMIT ('EdgeWeightMax', '2048M');
ECHO BOTH ": O9d EdgeWeightMax '2048M' = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] 2147483648 "PASSED" "***FAILED";

select GLIM_STATE ('select GRAPH_SET_LIMIT (''MaxWorkspace'', ''64XB'')');
ECHO BOTH ": O9e MaxWorkspace '64XB' refused = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] 42002 "PASSED" "***FAILED";

select GRAPH_SET_LIMIT ('CacheMax', '1024M');

-- O.10 - O.12: the names GRAPH_SET_LIMIT accepts and the names it offers
-- when it rejects one must be the same set.
--
-- `MinBatch` was accepted by the code and missing from the message, so the
-- one way to discover it was to read bif_graph.c.  A message that lists the
-- alternatives is the whole interface here -- there is no catalogue of limit
-- names anywhere else -- so a name missing from it does not exist as far as
-- a user is concerned.
--
-- Both directions are checked against one pinned list, and neither check
-- writes a limit: O.10 reads the message once and compares sets, so a name
-- that is accepted but unlisted and a name that is listed but unaccepted
-- both fail.  O.11 then confirms the pinned names are real, using only the
-- switches whose documented default makes setting them a no-op -- so the
-- list cannot drift into fiction without O.11 noticing.

-- The raw list of alternatives GRAPH_SET_LIMIT offers when it rejects a name.
create procedure GLIM_MSG_TEXT ()
{
  declare st, msg varchar;
  declare mdta, rset any;
  declare i int;
  st := '00000';
  msg := '';
  exec ('select GRAPH_SET_LIMIT (''NoSuchLimit'', 1)', st, msg, vector (), 0, mdta, rset);
  i := strstr (msg, 'expected ');
  if (i is null)
    return 'NOLIST';
  return subseq (msg, i + length ('expected '));
}
;

-- Every name the code actually accepts.  Kept beside the strcmp() chain in
-- bif_graph_set_limit(): adding one there means adding it here, and O.10
-- then requires the message to grow too.
create procedure GLIM_REAL_NAMES ()
{
  return vector ('MaxNodes', 'MaxTriples', 'MaxGraphNodes', 'MaxGraphTriples',
                 'MaxWorkspace',
                 'CacheMax', 'CacheTTL', 'EdgeWeightArray', 'MinBatch',
                 'IndexWalk', 'DenseNodeIndex', 'NarrowEdgeIndex',
                 'PageRankGather', 'OnePredStore', 'ParallelBFS',
                 'EdgeWeightMax', 'BetweennessParallel');
}
;

-- 'SAME', or the first name that is in one set and not the other.  No name
-- here is a substring of another, so a containment test is an exact one.
create procedure GLIM_NAME_DIFF ()
{
  declare txt, nm varchar;
  declare known, parts any;
  declare i, j, hit int;
  txt := GLIM_MSG_TEXT ();
  if (txt = 'NOLIST')
    return 'NOLIST';
  known := GLIM_REAL_NAMES ();
  for (i := 0; i < length (known); i := i + 1)
    if (strstr (txt, known[i]) is null)
      return known[i] || ' accepted but not offered';
  parts := split_and_decode (replace (txt, ' or ', ', '), 0, '\0\0,');
  for (i := 0; i < length (parts); i := i + 1)
    {
      nm := trim (parts[i]);
      if (nm <> '')
        {
          hit := 0;
          for (j := 0; j < length (known); j := j + 1)
            if (known[j] = nm)
              hit := 1;
          if (hit = 0)
            return nm || ' offered but not accepted';
        }
    }
  return 'SAME';
}
;

-- O.10: the two sets agree
select GLIM_NAME_DIFF ();
ECHO BOTH ": O10 accepted names == names the message offers = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] SAME "PASSED" "***FAILED";

-- O.11: and the pinned names are real.  Only the switches are exercised,
-- each set to the default it already holds, so this asserts without
-- disturbing any limit the rest of the suite depends on.
create procedure GLIM_SWITCHES_REAL ()
{
  declare names any;
  declare i int;
  declare st, msg varchar;
  declare mdta, rset any;
  names := vector ('EdgeWeightArray', 'IndexWalk', 'DenseNodeIndex',
                   'NarrowEdgeIndex', 'OnePredStore', 'ParallelBFS',
                   'PageRankGather');
  for (i := 0; i < length (names); i := i + 1)
    {
      st := '00000';
      msg := '';
      exec (sprintf ('select GRAPH_SET_LIMIT (''%s'', 1)', names[i]),
            st, msg, vector (), 0, mdta, rset);
      if (st <> '00000')
        return names[i] || ' rejected';
    }
  -- MinBatch is the one that regressed; 64 is its default.
  st := '00000';
  msg := '';
  exec ('select GRAPH_SET_LIMIT (''MinBatch'', 64)', st, msg, vector (), 0, mdta, rset);
  if (st <> '00000')
    return 'MinBatch rejected';
  return 'ALLREAL';
}
;

select GLIM_SWITCHES_REAL ();
ECHO BOTH ": O11 pinned switch names are accepted = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] ALLREAL "PASSED" "***FAILED";

-- O.12: MinBatch by name, since that is the one the message forgot
select case when strstr (GLIM_MSG_TEXT (), 'MinBatch') is null
       then 'ABSENT' else 'LISTED' end;
ECHO BOTH ": O12 MinBatch is offered by the message = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] LISTED "PASSED" "***FAILED";

-- ============================================================================
-- Group AU: the limits answer to the names [Graph] gives them
--
-- The INI keys are MaxNodes and MaxTriples, and the refusals name them that
-- way ("exceeds [Graph] MaxTriples").  GRAPH_SET_LIMIT knew the two only as
-- MaxGraphNodes and MaxGraphTriples, so the name an operator reads in the
-- ini file or in the error was "unknown limit".  Both spellings must set
-- the same limit; the older one stays for scripts already written with it.
-- ============================================================================

-- AU.1: the INI name is accepted, and returns the value in effect
select GLIM_STATE ('select GRAPH_SET_LIMIT (''MaxNodes'', 50)');
ECHO BOTH ": AU1 GRAPH_SET_LIMIT ('MaxNodes') state = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] 00000 "PASSED" "***FAILED";

-- AU.2: and it is the node limit: the 200-node graph is now refused
select GLIM_STATE ('select GRAPH_DEGREE_CENTRALITY (''urn:graph:lim:n0'', ''urn:graph:lim:g'')');
ECHO BOTH ": AU2 refused under MaxNodes 50 = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] 42006 "PASSED" "***FAILED";

select GRAPH_SET_LIMIT ('MaxGraphNodes', 100000);

-- AU.3: the same for the triple limit
select GLIM_STATE ('select GRAPH_SET_LIMIT (''MaxTriples'', 10)');
ECHO BOTH ": AU3 GRAPH_SET_LIMIT ('MaxTriples') state = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] 00000 "PASSED" "***FAILED";

select GLIM_STATE ('select GRAPH_DEGREE_CENTRALITY (''urn:graph:lim:n0'', ''urn:graph:lim:g'')');
ECHO BOTH ": AU4 refused under MaxTriples 10 = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] 42006 "PASSED" "***FAILED";

select GRAPH_SET_LIMIT ('MaxGraphTriples', 1000000);

-- AU.5: lowered through the old name and raised through the INI name, the
-- graph loads again -- so the two spellings write one limit, not two that
-- happen to share a default
select GRAPH_SET_LIMIT ('MaxGraphNodes', 50);
select GLIM_STATE ('select GRAPH_SET_LIMIT (''MaxNodes'', 100000)');
select GLIM_STATE ('select GRAPH_DEGREE_CENTRALITY (''urn:graph:lim:n0'', ''urn:graph:lim:g'')');
ECHO BOTH ": AU5 loads after raising through MaxNodes = " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[1] 00000 "PASSED" "***FAILED";

select GRAPH_SET_LIMIT ('MaxGraphNodes', 100000);

ECHO BOTH "COMPLETED: graph analytics limits test suite\n";
