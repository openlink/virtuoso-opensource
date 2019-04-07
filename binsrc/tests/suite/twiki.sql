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
registry_set ('wiki-test-type', 'API');

vad_install ('ods_framework_dav.vad');
vad_install ('ods_wiki_dav.vad');

create procedure test_sid ()
{
  return '1b9abd7ecdc3997dbb308536c3ff58cd';
}
;

set triggers off;
insert replacing DB.DBA.VSPX_SESSION (VS_REALM, VS_SID, VS_UID, VS_STATE, VS_EXPIRY)
	  values ('wa', test_sid(), 'dav',
		  serialize ( vector ( 'vspx_user', 'dav' ) ),
		  now());
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": create vspx session : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";
set triggers on;

load "twiki_proc.sql";

upload_test('Main');
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": upload to Main cluster : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

delete_and_upload_test('Main');
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": delete and upload test on Main : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create_cluster_test('Test');
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": create cluster Test : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

upload_test('Test');
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": upload to Test : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

delete_and_upload_test('Test');
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": delete and upload to Test : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

delete_cluster_test('Test');
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": delete Test : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

check_topic ('WelcomeVisitors', 'Test', NULL);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": check nonexistent WelcomeVisitors on Test : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create_cluster_test('Test');
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": create Test again : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

upload_test('Test');
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": upload to Test : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

delete_and_upload_test('Test');
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": delete from and upload to Test : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

delete_cluster_test ('Test');
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": delete Test : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

vad_uninstall_by_name ('Wiki');
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": uninstall wiki vad : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

vad_install ('ods_wiki_dav.vad');
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": install wiki vad : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

load "test_proc.sql";
upload_test('Main');
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": upload to Main : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

delete_and_upload_test('Main');
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": delete from and upload to Main : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create_cluster_test('Test');
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": create Test : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

upload_test('Test');
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": upload to Test : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

delete_and_upload_test('Test');
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": delete from and upload to Test : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

delete_cluster_test('Test');
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": delete Test : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

check_topic ('WelcomeVisitors', 'Test', NULL);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": check nonexistent WelcomeVisitors on Testr : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";


create_cluster_test('Test');
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": create Test : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

upload_test('Test');
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": upload to Test : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

delete_and_upload_test('Test');
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": delete from and upload to Test : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

delete_cluster_test('Test');
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": delete Test : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";







