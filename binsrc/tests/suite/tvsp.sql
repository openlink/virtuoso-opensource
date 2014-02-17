--
--  tvsp.sql
--
--  $Id: tvsp.sql,v 1.22.10.1 2013/01/02 16:15:33 source Exp $
--
--  Check vsp functions
--  
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--  
--  Copyright (C) 1998-2014 OpenLink Software
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

ECHO BOTH "STARTED: VSP functions checkup\n";

---select encode_base64('peppihinaahippi-penaa') from sys_users;
---ECHO BOTH $IF $EQU $LAST[1] "cGVwcGloaW5hYWhpcHBpLXBlbmFhAA=" "PASSED" "***FAILED";
---SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
---ECHO BOTH ": encode_base64('peppihinaahippi-penaa') produced: " $LAST[1] "\n";

select decode_base64(encode_base64('peppihinaahippipenaa')) from sys_users;
ECHO BOTH $IF $EQU $LAST[1] peppihinaahippipenaa "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": decode_base64(encode_base64('peppihinaahippipenaa')) produced: " $LAST[1] "\n";

select smime_sign ('just a test', file_to_string ('cert.pem'), file_to_string ('pk.pem'), '', vector (), 4*16 + 1);
ECHO BOTH $IF $EQU $ROWCNT 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": S/MIME signing a message produced results STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

-- suite for bug #1469
drop table BUG1469.DBA.TT1;
create table BUG1469.DBA.TT1 (I1 integer identity, VAR1 varchar (10), primary key (I1));
insert into BUG1469.DBA.TT1 (VAR1) values ('aa_1');
SET_IDENTITY_COLUMN ('BUG1469.DBA.TT1', 'I1', 102);
insert into BUG1469.DBA.TT1 (VAR1) values ('aa_2');

select * from BUG1469.DBA.TT1 where I1 > 100;
ECHO BOTH $IF $EQU $ROWCNT 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": BUG1469: SET_IDENTITY_COLUMN for non DB table\n";


-- suite for bug #1379 : GK disabled : this may be sometimes false on systems that have time synchronization
--create procedure B1379(){
--declare ctime,ltime,stime,cnt integer;
--
--result_names(stime,ltime,ctime);
--stime := msec_time();
--ctime := stime;
--ltime := ctime;
--
--cnt := 0;
--
--while(cnt < 2000000){
--    ctime := msec_time();
--    if(ctime < ltime){
--      result(stime,ltime,ctime);
--    };
--    ltime := ctime;
--    cnt := cnt + 1;
--  };
--
--};
--
--B1379();
--ECHO BOTH $IF $EQU $ROWCNT 0 "PASSED" "***FAILED";
--SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
--ECHO BOTH ": BUG1379: " $ROWCNT " non-consecutive times for Win32\n";


select length (0x1213);
ECHO BOTH $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": BUG1844: varbinary length returned " $LAST[1] "\n";

set NO_SYSTEM_TABLES=1;
tables/'SYSTEM TABLE';
ECHO BOTH $IF $EQU $ROWCNT 0 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": BUG2492: no system tables returned " $ROWCNT " system tables\n";

set NO_SYSTEM_TABLES=0;
tables/'SYSTEM TABLE';
ECHO BOTH $IF $NEQ $ROWCNT 0 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": BUG2492: default returned " $ROWCNT " system tables\n";

create procedure B2588 (in id1 integer, in id2 integer := 30)
{
  return id1 + id2;
};

select B2588 (id1 => 1), B2588 (id1 => 1, id2 => 2);
ECHO BOTH $IF $EQU $LAST[1] 31 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": BUG2588-1: KWD param call with a def value returned : " $LAST[1] "\n";
ECHO BOTH $IF $EQU $LAST[2] 3 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": BUG2588-2: KWD param call returned : " $LAST[2] "\n";

drop table B3020;
create table B3020 (ID int primary key, DATA long varchar);
insert into B3020 values (1, repeat (N'abc', 1000));

select isstring (cast (DATA as varchar)) from B3020;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": BUG3020: cast (LONG NVARCHAR as VARCHAR) returns string : " $LAST[1] "\n";

drop table B4698.B4698.B4698;
delete user B4698;

create user B4698;
user_set_qualifier ('B4698', 'B4698');

reconnect B4698;

create table B4698 (id int primary key, data int);
create index B4698_I on B4698 (data);

drop index B4698_I B4698;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": BUG 4698: preserving the qualifier across sql_compile STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

reconnect dba;

DROP TABLE B4525;
CREATE TABLE B4525(
  ID                  INTEGER IDENTITY,
  ID2                 INTEGER IDENTITY (START WITH 15),
  FREETEXT_ID         INTEGER NOT NULL IDENTITY,
  FREETEXT_ID2        INTEGER NOT NULL IDENTITY (START WITH 16),
  XML_DATA            LONG VARCHAR     NULL,
  PRIMARY KEY (ID, ID2)
);

INSERT INTO B4525 (XML_DATA) VALUES('<name>test  1 </name>');
select ID,ID2,FREETEXT_ID,FREETEXT_ID2 from B4525;
ECHO BOTH $IF $EQU $ROWCNT 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": BUG4525: rows after insert 1=" $ROWCNT "\n";

ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": BUG4525-1: PK IDENTITY no start 1=" $LAST[1] "\n";

ECHO BOTH $IF $EQU $LAST[2] 15 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": BUG4525-2: PK IDENTITY start 15 =" $LAST[2] "\n";

ECHO BOTH $IF $EQU $LAST[3] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": BUG4525-3: DEP IDENTITY no start 1=" $LAST[3] "\n";

ECHO BOTH $IF $EQU $LAST[4] 16 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": BUG4525-4: DEP IDENTITY start 16 =" $LAST[4] "\n";

-- do it twice to check the identity being reset
DROP TABLE B4525;
CREATE TABLE B4525(
  ID                  INTEGER IDENTITY,
  ID2                 INTEGER IDENTITY (START WITH 15),
  FREETEXT_ID         INTEGER NOT NULL IDENTITY,
  FREETEXT_ID2        INTEGER NOT NULL IDENTITY (START WITH 16),
  XML_DATA            LONG VARCHAR     NULL,
  PRIMARY KEY (ID, ID2)
);

INSERT INTO B4525 (XML_DATA) VALUES('<name>test  1 </name>');
select ID,ID2,FREETEXT_ID,FREETEXT_ID2 from B4525;
ECHO BOTH $IF $EQU $ROWCNT 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": BUG4525: rows after insert 1=" $ROWCNT "\n";

ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": BUG4525-5: PK IDENTITY no start 1=" $LAST[1] "\n";

ECHO BOTH $IF $EQU $LAST[2] 15 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": BUG4525-6: PK IDENTITY start 15 =" $LAST[2] "\n";

ECHO BOTH $IF $EQU $LAST[3] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": BUG4525-7: DEP IDENTITY no start 1=" $LAST[3] "\n";

ECHO BOTH $IF $EQU $LAST[4] 16 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": BUG4525-8: DEP IDENTITY start 16 =" $LAST[4] "\n";

delete from B4525;
alter table B4525 drop FREETEXT_ID2;
alter table B4525 add FREETEXT_ID2 INTEGER NOT NULL IDENTITY (START WITH 16);
INSERT INTO B4525 (XML_DATA) VALUES('<name>test  1 </name>');
select ID,ID2,FREETEXT_ID,FREETEXT_ID2 from B4525;
ECHO BOTH $IF $EQU $ROWCNT 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": BUG4525: rows after insert =" $ROWCNT "\n";

ECHO BOTH $IF $EQU $LAST[1] 2 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": BUG4525-9: PK IDENTITY no start 2=" $LAST[1] "\n";

ECHO BOTH $IF $EQU $LAST[2] 16 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": BUG4525-10: PK IDENTITY start 15 =" $LAST[2] "\n";

ECHO BOTH $IF $EQU $LAST[3] 2 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": BUG4525-11: DEP IDENTITY no start 2=" $LAST[3] "\n";

ECHO BOTH $IF $EQU $LAST[4] 16 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": BUG4525-12: DEP IDENTITY start 16 =" $LAST[4] "\n";

delete from B4525;
alter table B4525 drop FREETEXT_ID;
alter table B4525 add FREETEXT_ID INTEGER NOT NULL IDENTITY;
INSERT INTO B4525 (XML_DATA) VALUES('<name>test  1 </name>');
select ID,ID2,FREETEXT_ID,FREETEXT_ID2 from B4525;
ECHO BOTH $IF $EQU $ROWCNT 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": BUG4525: rows after insert 1=" $ROWCNT "\n";

ECHO BOTH $IF $EQU $LAST[1] 3 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": BUG4525-13: PK IDENTITY no start 3=" $LAST[1] "\n";

ECHO BOTH $IF $EQU $LAST[2] 17 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": BUG4525-14: PK IDENTITY start 17 =" $LAST[2] "\n";

ECHO BOTH $IF $EQU $LAST[3] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": BUG4525-15: DEP IDENTITY no start 1=" $LAST[3] "\n";

ECHO BOTH $IF $EQU $LAST[4] 17 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": BUG4525-16: DEP IDENTITY start 17 =" $LAST[4] "\n";

select charset_recode (N'\x412', '_WIDE_', 'CP1251') ;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": bug 4918: cs aliases set correctly STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select top 1 U_ID from SYS_USERS order by 'a';
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": bug 4916: top order by <constant> STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create procedure B4998_1 () { declare arr any; arr := vector (12); arr[0] := 13; return arr[0]; };
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": bug 4998_1: arr[x]=<val> compile STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create procedure B4998_2 () { declare arr any; arr := vector (vector(12)); arr[0] := vector (12); arr[0][0] := 13; return arr[0][0]; };
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": bug 4998_ERR_2: arr[x][y]=<val> compile STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create procedure B4998_3 () { declare arr any; arr := vector (12); select top 1 13 as M into arr[0] from DB.DBA.SYS_KEYS; return arr[0]; };
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": bug 4998_3: INTO arr[x] compile STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create procedure B4998_ERR_4 () { declare arr any; arr := vector (12); arr[0] := vector (12);  select top 1 13 as M into arr[0][0] from DB.DBA.SYS_KEYS; return arr[0][0]; };
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": bug 4998_ERR_4: arr[x][y]=<val> will not compile STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select B4998_1();
ECHO BOTH $IF $EQU $LAST[1] 13 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": bug 4998_5: arr[x]=<val> works RET=" $LAST[1] "\n";

select B4998_2();
ECHO BOTH $IF $EQU $LAST[1] 13 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": bug 4998_5: arr[x][y]=<val> works RET=" $LAST[1] "\n";

select B4998_3();
ECHO BOTH $IF $EQU $LAST[1] 13 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": bug 4998_6: INTO arr[x] works RET=" $LAST[1] "\n";

drop table B5793;
create table B5793 (ID int primary key, ND int null, NONND int not null);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": bug 5793: table created STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

insert into B5793 values (1, null, null);
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": bug 5793: null to non-null col STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

alter table B5793 modify NONND integer null;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": bug 5793: nullability on STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

insert into B5793 values (1, null, null);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": bug 5793: null to null col STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

alter table B5793 modify NONND varchar null;
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": bug 5793: changing col type STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

alter table B5793 modify NONND integer CHECK (MONND > 12);
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": bug 5793: CHECK in alter table modify col STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

call ('qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq.wwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwww.eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee') ();
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": overflow in call w/ constant STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

backup;
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": bug 5990: backup with no file specified STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create procedure B7386_P1 ()
 {
   log_enable (0);
   log_enable (1);
 };

create procedure B7386_P2 ()
 {
   log_enable (0);
   B7386_P1();
   log_enable (1);
 };

B7386_P2 ();
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": B7386: log_enable(0) not nestable STATE=" $STATE " MESSAGE=" $MESSAGE "\n";


ECHO BOTH "COMPLETED: VSP functions checkup (tvsp.sql) WITH " $ARGV[0] " FAILED, " $ARGV[1] " PASSED\n\n";
