--
--  tvvec_rollback_undo_crash.sql
--
--  A rollback with no graph write after it: the log holds its marker but
--  never the pages again, so roll forward has to rebuild the index.
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

echo BOTH "STARTED: vector index rollback undo -- rollback, then crash\n";

create procedure DB.DBA.VRU_ROLLED_BACK_2 ()
{
  DB.DBA.VRU_ADD (131, 150);
  __VEC_INDEX_DELETE_ROW ('VRU_IDX', 7);
  rollback work;
}
;

DB.DBA.VRU_ROLLED_BACK_2 ();
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": insert 20, delete 1, roll back STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

echo BOTH "COMPLETED: vector index rollback undo -- rollback, then crash\n";
