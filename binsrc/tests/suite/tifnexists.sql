SET ARGV[0] 0;
SET ARGV[1] 0;

-- cleanup
drop table tb_ifne;


-- test cases: create table
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


-- test cases: create index
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


-- test cases: drop index
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


-- test cases: alter table add column
alter table tb_ifne add column name varchar;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": add non-existing column w/o option : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

alter table tb_ifne add column name varchar;
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": add existing column w/o option : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

alter table tb_ifne add column name varchar if not exists;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": add existing column w/ option : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";


-- test cases: alter table drop column
alter table tb_ifne drop column name; 
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": drop existing column w/o option : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

alter table tb_ifne drop column name; 
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": drop non-existing column w/o option : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

alter table tb_ifne drop column name if exists; 
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": drop non-existing column w/ option : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";


-- test cases: drop table
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

-- done
ECHO BOTH "COMPLETED WITH " $ARGV[0] " FAILED, " $ARGV[1] " PASSED: IF EXISTS tests\n";
