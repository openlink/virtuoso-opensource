--
--  passt1.sql
--
--  $Id: pass.sql,v 1.14.10.2 2013/01/02 16:14:51 source Exp $
--
--  function pass-trough testsuite
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

--
--  Start the test
--
echo BOTH "\nSTARTED: pass-trough suite (pass.sql)\n";
SET ARGV[0] 0;
SET ARGV[1] 0;

vd_remote_data_source ('$U{PORT}', '', 'dba', 'dba');
rexecute ('$U{PORT}', 'drop table PTT');
rexecute ('$U{PORT}', 'create table PTT (ID integer not null primary key, DATA varchar(20))');
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": creating a remote table PTT : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

drop table PTT;
attach table PTT from '$U{PORT}' user 'dba' password 'dba';
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": attaching back the remote table : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

insert into PTT (ID) values (1);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": inserting a row into it : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

explain ('insert into PTT(ID) values(?,?)');
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": BUG1962: insert with more values than columns : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

explain ('insert into PTT(ID, DATA) values(?)');
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": BUG1962: insert with more columns than values : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create procedure BUG1692COPY(in d any) { return (d); };
explain ('insert into PTT(ID, DATA) values(BUG1692COPY(1))');
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": BUG1962: not-pass insert with more columns than values : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

explain ('insert into PTT(ID, DATA) select 1 from DB.DBA.SYS_USERS');
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": BUG1962: insert/select with more columns than values : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

vd_pass_through_function ('$U{PORT}', 'remchr', 'chr');
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": adding pass-through for sys_connected_server_address : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select right (remchr(ID + 48), 1)  from PTT;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": calling the pass-trough : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select right (chr(49), 1);
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": check native result =" $LAST[1] "\n";

use ANOTHER_SPACE;
select right (remchr(ID + 48), 1)  from DB..PTT;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": calling the pass-trough from a non-defining DB : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";
use DB;



create procedure xmla (in q varchar)
{
  declare st any;
  st := string_output ();
  xml_auto (q, vector (), st);
  result_names (q);
  result (string_output_string (st));
}

-- try for xml pass through with error.
xmla ('select * from PTT where case when ID = 303 then txn_error (1) else 1 end for xml auto');

-- bug #7346
create procedure P7346 ()
{
  declare x any;
  x := vector (1, 2);
  declare cnt integer;
  select 1 into cnt from PTT where id = x[0];
};

P7346 ();
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": BUG7346: aref of PL vars in passthrough goes local : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

-- xmltype pass-through
columns R1.DBA.XMLT / XMLTYPE_DATA;
ECHO BOTH $IF $EQU $LAST[6] XMLType "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": XMLVDB1: XMLTYPE attached as " $LAST[6] " : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

columns R1.DBA.XMLT / LONG_XMLTYPE_DATA;
ECHO BOTH $IF $EQU $LAST[6] XMLType "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": XMLVDB2: LONG XMLTYPE attached as " $LAST[6] " : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

columns R1.DBA.XMLT / LONGXML_DATA;
ECHO BOTH $IF $EQU $LAST[6] XMLType "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": XMLVDB3: LONG XML attached as " $LAST[6] " : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select
	dv_type_title (__tag (XMLTYPE_DATA)),
	dv_type_title (__tag (LONG_XMLTYPE_DATA)),
	dv_type_title (__tag (LONGXML_DATA)) from R1.DBA.XMLT where ID = 1;

ECHO BOTH $IF $EQU $LAST[1] XML_ENTITY "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": XMLVDB4: XMLTYPE VDB data returned as " $LAST[1] " : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";
ECHO BOTH $IF $EQU $LAST[2] XML_ENTITY "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": XMLVDB5: LONG XMLTYPE VDB data returned as " $LAST[2] " : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";
ECHO BOTH $IF $EQU $LAST[3] XML_ENTITY "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": XMLVDB6: LONG XML VDB data returned as " $LAST[3] " : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select x.XMLTYPE_DATA.getClobVal ()[1] from  R1.DBA.XMLT x where id = 2;
--ECHO BOTH $IF $EQU $LAST[1] 1043 "PASSED" "***FAILED";
--SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
--ECHO BOTH ": XMLVDB7: XMLTYPE VDB data passed through unicode char " $LAST[1] " : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

rexecute ('$U{PORT}', 'drop table PTT_FT');
rexecute ('$U{PORT}', 'create table PTT_FT (ID integer not null primary key, DATA long varchar, SDATA VARCHAR)');
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": creating a remote table PTT_FT : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";
rexecute ('$U{PORT}', 'create text index on PTT_FT (DATA) with key ID clustered with (SDATA)');
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": creating a FT index PTT_FT : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

drop table PTT_FT;
attach table PTT_FT from '$U{PORT}' user 'dba' password 'dba';
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": attaching back the remote table : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

insert into PTT_FT (ID, DATA, SDATA) values (1, 'sheep in the big city', 'narator');
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": inserting a row 1 into PTT_FT : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";
insert into PTT_FT (ID, DATA, SDATA) values (2, 'red hot riding hood', 'wolf');
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": inserting a row 2 into PTT_FT : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";
insert into PTT_FT (ID, DATA, SDATA) values (3, 'city slickers', 'ted');
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": inserting a row 3 into PTT_FT : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select SDATA from PTT_FT where contains (DATA, 'city');
ECHO BOTH $IF $EQU $ROWCNT 2 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": simple contains returns " $ROWCNT " rows : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select 1 from PTT where contains (DATA, 'city');
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": simple contains over wrong table : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select SDATA from PTT_FT where contains (DATA, 'city', start_id, 1, end_id, 2);
ECHO BOTH $IF $EQU $ROWCNT 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": limited contains returns " $ROWCNT " rows : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

update PTT X set DATA=data where X.ID = -1;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": update with table alias : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

--
-- End of test
--
ECHO BOTH "COMPLETED: pass-trough suite (pass.sql) WITH " $ARGV[0] " FAILED, " $ARGV[1] " PASSED\n\n";
