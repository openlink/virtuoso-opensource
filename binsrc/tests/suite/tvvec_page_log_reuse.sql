--
--  tvvec_page_log_reuse.sql
--
--  Many sequential write transactions on ONE connection, run by
--  tvvec_page_log.sh last.
--
--  A transaction object is cleared and reused, not destroyed, between the
--  transactions of a connection: lt_clear () (lock.c) empties it and hands the
--  same lock_trx_t to the next one.  Anything per-transaction that vvec hangs
--  off it therefore has to be released AND forgotten there, not just released;
--  a pointer left behind is used by the next transaction, which is a
--  use-after-free on the write path rather than a leak.
--
--  `commit work' inside the loop is the point: it ends each transaction and
--  starts the next on the same connection, so the graph is written, the
--  transaction is cleared, and the graph is written again through whatever
--  state the clear left.
--
--  This is a shape test, not a detector -- freed memory usually still reads
--  back plausibly, so it cannot be relied on to fail when the bug is present.
--  What it does do is exercise the path under the assertions that would catch
--  a graph corrupted by it.
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

echo BOTH "STARTED: VVEC page log transaction reuse\n";

create procedure DB.DBA.VPL_KV (in kv any, in key_name varchar) returns any
{
  declare inx integer;
  if (not isvector (kv))
    return null;
  for (inx := 0; inx < length (kv); inx := inx + 2)
    {
      if (aref (kv, inx) = key_name)
        return aref (kv, inx + 1);
    }
  return null;
};

create procedure DB.DBA.VPL_REUSE (in first_id integer, in last_id integer)
{
  declare i integer;
  for (i := first_id; i <= last_id; i := i + 1)
    {
      insert into DB.DBA.VPL_T values (i, 'hot 0 ' || cast (1 + mod (i, 40) as varchar));
      commit work;
    }
};

--  tvvec_page_log_memory.sql left the graph packed, so these transactions link into packed records.
select get_keyword ('format', __VEC_INDEX_PAGE_STATS ('VPL_IDX'));
ECHO BOTH $IF $EQU $LAST[1] packed "PASSED" "***FAILED";
ECHO BOTH ": precondition -- VPL_IDX format=" $LAST[1] " expected packed\n";

DB.DBA.VPL_REUSE (301, 340);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": 40 sequential write transactions STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select DB.DBA.VEC_SQL_QUEUE_DRAIN (100);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": drain after reuse drained=" $LAST[1] " STATE=" $STATE "\n";

select count (*) from DB.DBA.VPL_T;
ECHO BOTH $IF $EQU $LAST[1] 300 "PASSED" "***FAILED";
ECHO BOTH ": rows after reuse=" $LAST[1] " expected 300\n";

select count (*) from DB.DBA.VPL_IDX_vec_embeddings;
ECHO BOTH $IF $EQU $LAST[1] 300 "PASSED" "***FAILED";
ECHO BOTH ": embeddings after reuse=" $LAST[1] " expected 300\n";

--  The graph has to describe the rows all 40 transactions put in it.
select DB.DBA.VPL_KV (__VEC_INDEX_VALIDATE ('VPL_IDX'), 'consistent');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": consistent after reuse=" $LAST[1] " expected 1\n";

select length (__VEC_INDEX_SEARCH ('VPL_IDX', __VEC_INDEX_QUERY_TEXT_VECTOR ('VPL_IDX', 'hot 0 3'), 20, 64));
ECHO BOTH $IF $EQU $LAST[1] 20 "PASSED" "***FAILED";
ECHO BOTH ": search after reuse hits=" $LAST[1] " expected 20\n";

select count (*) from DB.DBA.VPL_T where X_SIMILAR (content, 'hot 0 3') > 0.6;
ECHO BOTH $IF $EQU $LAST[1] 300 "PASSED" "***FAILED";
ECHO BOTH ": X_SIMILAR after reuse=" $LAST[1] " expected 300\n";

echo BOTH "COMPLETED: VVEC page log transaction reuse\n";
