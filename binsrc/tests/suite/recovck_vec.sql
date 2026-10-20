--
--  recovck_vec.sql
--
--  Vector index recovery check, run by trecov.sh after every restore.
--
--  The point of this script is the *order* of what it asks.  Since a graph that
--  came back behind its data is now repaired automatically on first use
--  (vvec_epoch_reconcile), a search that succeeds proves nothing on its own --
--  it could have been answered by a rebuild that silently replaced a graph the
--  restore failed to bring back.  So the consistency check comes first:
--  __VEC_INDEX_VALIDATE is a diagnostic that deliberately does not repair, so
--  asking it before anything else is what distinguishes "the restore carried the
--  graph" from "the restore lost the graph and a rebuild covered for it".
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

ECHO BOTH "STARTED: VVEC recovery check\n";

--  First, and before any read path can trigger reconciliation.
select DB.DBA.RVEC_KV (__VEC_INDEX_VALIDATE ('DOCS_VEC'), 'consistent');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": restored graph consistent without a rebuild=" $LAST[1] "\n";

select case when DB.DBA.RVEC_KV (__VEC_INDEX_VALIDATE ('DOCS_VEC'), 'graph_epoch')
             = DB.DBA.RVEC_KV (__VEC_INDEX_VALIDATE ('DOCS_VEC'), 'data_epoch')
            then 1 else 0 end;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": restored graph_epoch = data_epoch=" $LAST[1] "\n";

--  Scalar subquery + coalesce so the statement always returns exactly one row:
--  a bare "select VIE_STATE ... where ..." returns none when the catalogue row
--  is missing, and $LAST[1] would then still hold the previous statement's
--  value.  A missing row is a real possible outcome, so report it.
select coalesce ((select VIE_STATE from DB.DBA.VEC_INDEX_EPOCH where VIE_NAME = 'DOCS_VEC'), '<no-catalog-row>');
ECHO BOTH $IF $EQU $LAST[1] "ok" "PASSED" "***FAILED";
ECHO BOTH ": restored catalog state=" $LAST[1] "\n";

select count (*) from DB.DBA.DOCS;
ECHO BOTH $IF $EQU $LAST[1] 3 "PASSED" "***FAILED";
ECHO BOTH ": restored source rows=" $LAST[1] " expected 3\n";

select count (*) from DB.DBA.DOCS_VEC_vec_embeddings;
ECHO BOTH $IF $EQU $LAST[1] 3 "PASSED" "***FAILED";
ECHO BOTH ": restored embeddings rows=" $LAST[1] " expected 3\n";

select DB.DBA.RVEC_KV (__VEC_INDEX_VALIDATE ('DOCS_VEC'), 'embedding_rows');
ECHO BOTH $IF $EQU $LAST[1] 3 "PASSED" "***FAILED";
ECHO BOTH ": restored graph covers embeddings rows=" $LAST[1] " expected 3\n";

--  Now the graph is allowed to answer.
select length (__VEC_INDEX_SEARCH ('DOCS_VEC', __VEC_INDEX_QUERY_TEXT_VECTOR ('DOCS_VEC', 'howto virtuoso macOS'), 3, 40));
ECHO BOTH $IF $EQU $LAST[1] 3 "PASSED" "***FAILED";
ECHO BOTH ": restored index answers ANN hits=" $LAST[1] " expected 3\n";

--  The leading-ANN plan with its SIMILARITY/DISTANCE virtual columns, which is
--  the shape a user actually writes.  TOP is what bounds the ANN search; without
--  it the optimizer cannot place a leading ANN and the virtual columns have no
--  producer.
select top 1000 id, content, SIMILARITY, DISTANCE
  from DB.DBA.DOCS
 where X_SIMILAR (content, 'howto virtuoso macOS') > 0
 order by SIMILARITY;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": restored leading-ANN query STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select count (*) from (select top 1000 id from DB.DBA.DOCS
                        where X_SIMILAR (content, 'howto virtuoso macOS') > 0) x;
ECHO BOTH $IF $EQU $LAST[1] 3 "PASSED" "***FAILED";
ECHO BOTH ": restored leading-ANN query rows=" $LAST[1] " expected 3\n";

ECHO BOTH "COMPLETED: VVEC recovery check\n";
