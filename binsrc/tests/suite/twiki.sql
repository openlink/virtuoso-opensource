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







