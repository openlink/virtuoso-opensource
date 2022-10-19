SET ARGV[0] 0;
SET ARGV[1] 0;
-- cleanup
drop table tb_ifne;
-- test cases
create table tb_ifne (id integer primary key, data varchar);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": create of non-existing table w/o option : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";
create table tb_ifne (id integer primary key, data varchar);
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": create of existing table w/o option : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";
create table tb_ifne (id integer primary key, data varchar) if not exists;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": create of existing table w/ option : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create index tb_ifne_data on tb_ifne (data);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": create of non-existing index w/o option : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";
create index tb_ifne_data on tb_ifne (data);
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": create of existing index w/o option : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";
create index tb_ifne_data on tb_ifne (data) if not exists;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": create of existing index w/ option : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

drop index tb_ifne_data;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": drop of existing index w/o option : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";
drop index tb_ifne_data;
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": drop of non-existing index w/o option : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";
drop index tb_ifne_data if exists;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": drop of non-existing index w/ option : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

drop table tb_ifne;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": drop of existing table w/o option : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";
drop table tb_ifne;
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": drop of non-existing table w/o option : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";
drop table tb_ifne if exists;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": drop of non-existing table w/ option : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

ECHO BOTH "COMPLETED WITH " $ARGV[0] " FAILED, " $ARGV[1] " PASSED: HTTP server tests\n";
