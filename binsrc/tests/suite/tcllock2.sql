--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2019 OpenLink Software
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
--

-- 2pc timing special cases
-- Uses tblob table, expects state as after tblob.sql

cl_exec ('__dbf_set (''dbf_cl_blob_autosend_limit'', 100000)');

foreach blob in words.esp update tblob set b1 = ?, b2 = '', b3 = '', b4 = '', e1 = '', e2 = ''  where k between 10000 and 10010;


-- kill during 2pc.


cl_exec ('__dbf_set (''dbf_cl_blob_autosend_limit'', 100000)');

set autocommit manual;

cl_exec ('__dbf_set (''dbf_branch_transact_wait'', 1000)', txn => 1);
__dbf_set ('dbf_branch_transact_wait', 0);
update tblob b1 set b1 = (select b1 from tblob b2 where b2.k = b1.k + 1) where k > 9999;

cl_exec ('registry_set (''kill_id'', ?)', vector (sprintf ('%ld', __cl_txn_id ())), txn => 1);
cl_exec ('__cl_kill_txn  (atod (registry_get (''kill_id'')))', delay => 0.3, hosts => vector (2, 3)) &
delay (0.1);
commit work;
echo both $if $equ $sqlstate "40004" "PASSED" "***FAILED";
echo both ": async deadlock kill in mid 2pc\n";


-- out of log

cl_exec ('__dbf_set (''dbf_branch_transact_wait'', 1000)', txn => 1);
__dbf_set ('dbf_branch_transact_wait', 0);
update tblob b1 set b1 = (select b1 from tblob b2 where b2.k = b1.k + 1) where k > 9999;

cl_exec ('__dbf_set (''dbf_log_no_disk'', 1)', hosts => vector (2, 3));
commit work;
echo both $if $equ $sqlstate "40004" "PASSED" "***FAILED";
echo both ": log out of disk\n";


cl_exec ('__dbf_set (''dbf_log_no_disk'', 0)', hosts => vector (2, 3));


-- checkpoint in 2pc

cl_exec ('__dbf_set (''dbf_branch_transact_wait'', 2000)', txn => 1);
__dbf_set ('dbf_branch_transact_wait', 0);
update tblob b1 set b1 = (select b1 from tblob b2 where b2.k = b1.k + 1) where k > 9999;

cl_exec ('checkpoint', delay => 0.5) &
delay (0.2);
commit work;
echo both $if $equ $sqlstate OK "PASSED" "***FAILED";
echo both ": checkpoint in mid 2pc\n";

-- 2pc recov cycle with blobs.  Ends with committed


cl_exec ('__dbf_set (''dbf_cl_blob_autosend_limit'', 100000)');
cl_exec ('__dbf_set (''dbf_branch_transact_wait'', 1000)', txn => 1);
__dbf_set ('dbf_branch_transact_wait', 0);
update tblob b1 set b1 = (select b1 from tblob b2 where b2.k = b1.k + 1) where k > 9999;

cl_exec ('raw_exit ()', delay => 1.5, hosts => vector (2, 3)) &
delay (0.2);
commit work;
echo both $if $equ $sqlstate OK "PASSED" "***FAILED";
echo both ": OK for 2pc commit with branch failure after prepare.  Recov cycle will say committed\n";


-- 2pc recov cycle with blobs.  Ends with not committed
-- hard to get.  The branches must die after prepare but before the owner dies.  The owner must die before logging the final. The owner must not see the branches die.

cl_exec ('__dbf_set (''dbf_cl_blob_autosend_limit'', 100000)');
cl_exec ('__dbf_set (''dbf_branch_transact_wait'', 1000)', txn => 1);
__dbf_set ('dbf_2pc_prepare_wait', 2000);


update tblob b1 set b1 = (select b1 from tblob b2 where b2.k = b1.k + 1) where k > 9999;

cl_exec ('raw_exit ()', delay => 1.3, hosts => vector (2, 3)) &
cl_exec ('raw_exit ()', delay => 1.7, hosts => vector (1)) &

delay (0.15);
commit work;


