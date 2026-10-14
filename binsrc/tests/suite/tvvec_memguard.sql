--
--  tvvec_memguard.sql
--
--  Regression test for the fast-rebuild memory guard.
--
--  The fast bulk __VEC_INDEX_REBUILD holds all vectors in heap (the caller's
--  arena + the HNSW builder's duplicate, plus per-node adjacency).  Without an
--  upper bound a rebuild on a huge index can OOM the server.  The guard
--  estimates the footprint and, when method='auto', falls back to replay if the
--  estimate exceeds VVEC_FAST_REBUILD_MAX_BYTES.  An explicit 'fast' proceeds
--  but logs a warning.
--
--  The companion .sh sets VVEC_FAST_REBUILD_MAX_BYTES=1000, registers the model,
--  creates the index, and populates it with 10001 vectors (above the AUTO_MIN
--  threshold) before running this file.  This file rebuilds and asserts the
--  results; the .sh greps the server log for the fallback / warning messages.
--
--  Self-contained: uses the 'test_embedding' model type, so it runs without the
--  ONNX plugin.
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

echo BOTH "STARTED: VVEC fast-rebuild memory guard\n";

-- Verify the index was populated by the .sh driver.
select count (*) from DB.DBA.VMG_AUTOX_vec_embeddings;
ECHO BOTH $IF $EQU $LAST[1] 10001 "PASSED" "***FAILED";
ECHO BOTH ": populate count=" $LAST[1] "\n";

-- Rebuild with auto: the memory guard should estimate ~2.2 MB, which exceeds
-- the 1000-byte cap set by the .sh driver, so it must fall back to replay.
-- The rebuild still succeeds (replay works); we assert the row count.  The .sh
-- greps the log for the fallback message.
select __VEC_INDEX_REBUILD ('VMG_AUTOX');
ECHO BOTH $IF $EQU $LAST[1] 10001 "PASSED" "***FAILED";
ECHO BOTH ": auto rebuild (guard -> replay) rows=" $LAST[1] "\n";

-- Rebuild with explicit fast: the guard logs a warning but proceeds.
select __VEC_INDEX_REBUILD ('VMG_AUTOX', 'fast');
ECHO BOTH $IF $EQU $LAST[1] 10001 "PASSED" "***FAILED";
ECHO BOTH ": explicit fast rebuild (guard -> warning) rows=" $LAST[1] "\n";

-- The index is still searchable.
create function DB.DBA.VMG_HITS (in txt varchar) returns integer
{
  return length (__VEC_INDEX_SEARCH ('VMG_AUTOX', __VEC_INDEX_QUERY_TEXT_VECTOR ('VMG_AUTOX', txt), 10, 20));
};
select DB.DBA.VMG_HITS ('alpha 10 11');
ECHO BOTH $IF $GTE $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": index searchable hits=" $LAST[1] "\n";

-- Cleanup.
drop index VMG_AUTOX;
drop table DB.DBA.VMG_T;
drop function DB.DBA.VMG_HITS;
delete from DB.DBA.ONNX_MODELS where model_name = 'vmg-8';
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": cleanup STATE=" $STATE "\n";

echo BOTH "COMPLETED: VVEC fast-rebuild memory guard\n";
