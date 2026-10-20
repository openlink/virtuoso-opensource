--
--  tvvec_page_log_memory.sql
--
--  The memory side of LOG_VEC_PAGE, run by tvvec_page_log.sh after the log
--  measurement.
--
--  A page's before-image exists so that its release can log a delta instead of
--  a whole page.  It is read exactly once, by the release that follows the
--  vvec_page_delta () that made it, so it has no reason to outlive that pair.
--  Holding it until commit instead costs PAGE_SZ for every page the
--  transaction touches -- and a rebuild touches every page of the graph in one
--  transaction, so on a large index that is the whole graph, resident, on top
--  of the same volume going to the log.
--
--  __vvec_page_image_peak () reports the most before-images any single
--  transaction has held at once since it was last reset, in pages.  The
--  assertion is that a rebuild of a graph with far more pages than the limit
--  still peaks below it: bounded by what is in flight between delta and
--  release, not by the size of the transaction.
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

echo BOTH "STARTED: VVEC page log memory\n";

--  Reset, so the peak below describes the rebuild and not the fixture that
--  built the index in the first place.
select __vvec_page_image_peak (1);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": reset the page image peak, was=" $LAST[1] " STATE=" $STATE "\n";

select __vvec_page_image_peak (0);
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": peak after reset=" $LAST[1] " expected 0\n";

--  One transaction, every page of the graph.  260 nodes is well over the limit
--  asserted below however they are laid out -- one node per page in the legacy
--  format, eight to a page packed -- so a peak that tracked the transaction
--  rather than what is in flight could not come in under it.
select __VEC_INDEX_REBUILD ('VPL_IDX');
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": rebuild VPL_IDX rows=" $LAST[1] " STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

--  Report the number, then assert on it.  The comparison is done in SQL, not
--  with isql's $LT: that compares the values as strings, so "3" < "16" is
--  false and a passing result would be reported as a failure.
select __vvec_page_image_peak (0);
ECHO BOTH ": peak before-images held by one transaction=" $LAST[1] " pages\n";

select case when __vvec_page_image_peak (0) < 16 then 1 else 0 end;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": peak in-flight before-images under 16 pages=" $LAST[1] " expected 1\n";

--  The rebuild has to have actually happened, or the peak above is the peak of
--  nothing.
select count (*) from DB.DBA.VPL_IDX_vec_embeddings;
ECHO BOTH $IF $EQU $LAST[1] 260 "PASSED" "***FAILED";
ECHO BOTH ": embeddings after rebuild=" $LAST[1] " expected 260\n";

select length (__VEC_INDEX_SEARCH ('VPL_IDX', __VEC_INDEX_QUERY_TEXT_VECTOR ('VPL_IDX', 'hot 0 7'), 20, 64));
ECHO BOTH $IF $EQU $LAST[1] 20 "PASSED" "***FAILED";
ECHO BOTH ": search after rebuild hits=" $LAST[1] " expected 20\n";

--  The same bound for the fast rebuild, which frees every legacy page and writes the graph packed.
select __vvec_page_image_peak (1);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": reset the page image peak before the fast rebuild STATE=" $STATE "\n";

select __VEC_INDEX_REBUILD ('VPL_IDX', 'fast');
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": fast rebuild VPL_IDX rows=" $LAST[1] " STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select __vvec_page_image_peak (0);
ECHO BOTH ": peak before-images held by the fast rebuild=" $LAST[1] " pages\n";

select case when __vvec_page_image_peak (0) < 16 then 1 else 0 end;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": fast rebuild peak in-flight before-images under 16 pages=" $LAST[1] " expected 1\n";

select get_keyword ('format', __VEC_INDEX_PAGE_STATS ('VPL_IDX'));
ECHO BOTH $IF $EQU $LAST[1] packed "PASSED" "***FAILED";
ECHO BOTH ": VPL_IDX format after the fast rebuild=" $LAST[1] " expected packed\n";

select length (__VEC_INDEX_SEARCH ('VPL_IDX', __VEC_INDEX_QUERY_TEXT_VECTOR ('VPL_IDX', 'hot 0 7'), 20, 64));
ECHO BOTH $IF $EQU $LAST[1] 20 "PASSED" "***FAILED";
ECHO BOTH ": search after the fast rebuild hits=" $LAST[1] " expected 20\n";

echo BOTH "COMPLETED: VVEC page log memory\n";
