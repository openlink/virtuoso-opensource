--
--  tvvec_page_log_search.sql
--
--  The measured window of tvvec_page_log.sh: searches, and nothing else.  The
--  driver stats the transaction log either side of this script, so anything
--  added here is charged to the result.
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

echo BOTH "STARTED: VVEC page log measured searches\n";

select DB.DBA.VPL_SEARCH (40);
ECHO BOTH $IF $EQU $LAST[1] 800 "PASSED" "***FAILED";
ECHO BOTH ": measured search hits=" $LAST[1] " expected 800\n";

--  X_SIMILAR too, so the leading-ANN path is measured as well as the
--  __VEC_INDEX_SEARCH one: they reach the graph through different callers and
--  only one of them would be caught otherwise.
select count (*) from DB.DBA.VPL_T where X_SIMILAR (content, 'hot 0 7') > 0.6;
ECHO BOTH $IF $EQU $LAST[1] 260 "PASSED" "***FAILED";
ECHO BOTH ": measured X_SIMILAR count=" $LAST[1] " expected 260\n";

echo BOTH "COMPLETED: VVEC page log measured searches\n";
