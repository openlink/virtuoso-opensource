--
--  tvvec_backup_pages.sql
--
--  Run against a database restored from a page-image online backup
--  (backup_online () + virtuoso-t -r).  That form copies pages, so unlike the
--  logical dumps it carries the DPF_VEC graph itself: the index has to answer
--  immediately, with no rebuild.  Asserted separately from
--  tvvec_backup_verify.sql, which rebuilds before it searches.
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

echo BOTH "STARTED: VVEC page-image restore verification\n";

select count (*) from DB.DBA.BK_T;
ECHO BOTH $IF $EQU $LAST[1] 80 "PASSED" "***FAILED";
ECHO BOTH ": page-restored source rows=" $LAST[1] " expected 80\n";

select length (__VEC_INDEX_SEARCH ('BK_IDX', __VEC_INDEX_QUERY_TEXT_VECTOR ('BK_IDX', 'hot 0 1'), 20, 40));
ECHO BOTH $IF $EQU $LAST[1] 20 "PASSED" "***FAILED";
ECHO BOTH ": graph survived the page-image restore, no rebuild, hits=" $LAST[1] " expected 20\n";

select count (*) from DB.DBA.BK_T where X_SIMILAR (content, 'hot 0 1') > 0.6;
ECHO BOTH $IF $EQU $LAST[1] 80 "PASSED" "***FAILED";
ECHO BOTH ": page-restored index answers X_SIMILAR count=" $LAST[1] " expected 80\n";

select length (__VEC_INDEX_SEARCH ('BK_P_IDX', __VEC_INDEX_QUERY_TEXT_VECTOR ('BK_P_IDX', 'hot 0 1'), 20, 40));
ECHO BOTH $IF $EQU $LAST[1] 20 "PASSED" "***FAILED";
ECHO BOTH ": packed graph survived the page-image restore, no rebuild, hits=" $LAST[1] " expected 20\n";

select get_keyword ('format', __VEC_INDEX_PAGE_STATS ('BK_P_IDX'));
ECHO BOTH $IF $EQU $LAST[1] packed "PASSED" "***FAILED";
ECHO BOTH ": page-restored BK_P_IDX format=" $LAST[1] " expected packed\n";

echo BOTH "COMPLETED: VVEC page-image restore verification\n";
