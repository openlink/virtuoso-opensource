--
--  tschema1.sql
--
--  $Id$
--
--  Test DDL functionality #1
--  
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--  
--  Copyright (C) 1998-2017 OpenLink Software
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

ECHO BOTH "STARTED: Schema Evolution Test, part 1\n";

--- test schema evolution


--set echo on;

drop table T2;

create table T2 (A integer, B integer, primary key (A))
alter index T2 on T2 partition (A int (0hexffff));
create table T2_1 (under T2, C2_1 integer);
create table T2_2 (under T2, C2_2 integer);

create index C2_1 on T2_1 (C2_1) partition (C2_1 int);

create index C2_2 on T2_2 (C2_2) partition (C2_2 int);


create table T2_1_1 (under T2_1, D2_1_1 integer);
create index D2_1_1 on T2_1_1 (D2_1_1) partition (D2_1_1 int);


insert into T2 values (1, 2);
insert into T2 values (2, 2);
insert into T2 values (3, 02);

insert into T2_1 (A, B, C2_1) values (4, 2, 1);
insert into T2_1 (A, B, C2_1) values (5, 2, 1);
insert into T2_1 (A, B, C2_1) values (6, 2, 1);
insert into T2_1 (A, B, C2_1) values (7, 2, 1);
insert into T2_1 (A, B, C2_1) values (8, 2, 1);

insert into T2_2 (A, B, C2_2) values (10, 2, 1);
insert into T2_2 (A, B, C2_2) values (11, 2, 1);
insert into T2_2 (A, B, C2_2) values (12, 2, 1);
insert into T2_2 (A, B, C2_2) values (13, 2, 1);
insert into T2_2 (A, B, C2_2) values (14, 2, 1);

insert into T2_1_1 (A, B, C2_1, D2_1_1) values (20, 1, 2, 3);
insert into T2_1_1 (A, B, C2_1, D2_1_1) values (21, 1, 2, 3);
insert into T2_1_1 (A, B, C2_1, D2_1_1) values (22, 1, 2, 3);
insert into T2_1_1 (A, B, C2_1, D2_1_1) values (23, 1, 2, 3);
insert into T2_1_1 (A, B, C2_1, D2_1_1) values (24, 1, 2, 3);
insert into T2_1_1 (A, B, C2_1, D2_1_1) values (4, 1, 2, 3);

-- XXX: VJ
--ECHO BOTH $IF $EQU $STATE 23000 "PASSED" "***FAILED";
--ECHO BOTH ": primary key in subtable conflicts with super table.\n";

select count (*) from T2;
ECHO BOTH $IF $EQU $LAST[1] 18 "PASSED" "***FAILED";
ECHO BOTH ": " $LAST[1] " Rows in T2.\n";

alter table T2_1 add D2_1 integer;
select count (*) from T2;
ECHO BOTH $IF $EQU $LAST[1] 18 "PASSED" "***FAILED";
ECHO BOTH ": " $LAST[1] " Rows in T2 after ALTER TABLE of T2_1.\n";

alter table T2 add E integer;
select count (*) from T2;
ECHO BOTH $IF $EQU $LAST[1] 18 "PASSED" "***FAILED";
ECHO BOTH ": " $LAST[1] " Rows in T2 after ALTER TABLE of T2.\n";

update T2_1 set E = 11;
select count (*) from T2 where E = 11;
ECHO BOTH $IF $EQU $LAST[1] 10 "PASSED" "***FAILED";
ECHO BOTH ": " $LAST[1] " rows in T2 with E = 11\n";

update T2 set E = 5555 where E is null;
select count (*) from T2 where E = 5555;
ECHO BOTH $IF $EQU $LAST[1] 8 "PASSED" "***FAILED";
ECHO BOTH ": " $LAST[1] " rows in T2 with E = 5555\n";

alter table T2_1 add F varchar;
select count (*) from T2;
ECHO BOTH $IF $EQU $LAST[1] 18 "PASSED" "***FAILED";
ECHO BOTH ": Cached statement gives " $LAST[1] " in T2 after alter of T2_1\n";

select  count (*) from T2;
ECHO BOTH $IF $EQU $LAST[1] 18 "PASSED" "***FAILED";
ECHO BOTH ": Recompiled statement gives " $LAST[1] " in T2 after alter of T2_1\n";

update T2_1_1 set F = 'T2_1_1';
update T2_1 set F = 'T2_1' where F is null;
select count (*) from T2;
drop table T2_1_1;
select count (*)  from T2;
ECHO BOTH $IF $EQU $LAST[1] 13 "PASSED" "***FAILED";
ECHO BOTH ": Recompiled statement gives " $LAST[1] " in T2 after drop of T2_1_1\n";

create index b on t2 (b) partition (b int);
update t2 set b = a;
select count (*) from t2_2 table option (index b);
ECHO BOTH $IF $EQU $LAST[1] 5 "PASSED" "***FAILED";
ECHO BOTH ": Recompiled statement gives " $LAST[1] " in T2 after drop of T2_1_1\n";



select K1. KEY_NAME, K2.KEY_NAME from SYS_KEY_SUBKEY, SYS_KEYS K1, SYS_KEYS K2 WHERE K1.KEY_ID = SUPER AND K2.KEY_ID = SUB;

ECHO BOTH "COMPLETED: Schema Evolution Test, part 1\n";



create table AI (id integer identity, a integer)
alter index AI on AI partition (ID int);
create table AI_2 (sub_id integer identity, under AI);

insert into AI (A) values (11);
insert into AI_2 (A) values (11);
insert into AI_2 (A) values (11);
insert into AI (A) values (11);

select count (*) from AI;
ECHO BOTH $IF $EQU $LAST[1] 4 "PASSED" "***FAILED";
ECHO BOTH ": rows in inherited IDENTITY test\n";


alter table AI add B long varchar;
update AI set B = '1234567890';
alter table AI drop B;


create table USR_TABLE (COL1 integer, COL2 integer)
alter index USR_TABLE on USR_TABLE partition (_IDN int);
insert into USR_TABLE values (1, 2);
create user USR1;
create user USR2;
create user USR3;
create user USER_GROUP;
set user group USR2 USER_GROUP;

grant select on USR_TABLE to USR1;
grant update on USR_TABLE to USR1;

grant select (COL1) on USR_TABLE to USER_GROUP;
grant update (COL1) on USR_TABLE to USER_GROUP;
grant update (COL2) on USR_TABLE to USER_GROUP;
revoke update (COL2) on USR_TABLE from USER_GROUP;

USER_SET_PASSWORD ('USR3', 'USR3PASS');

create table B2437 (ID integer);
insert into B2437 (ID) values (1);

-- re-update a row make it shorter or longer,
-- test the backup at the end
CREATE TABLE ROW_TEST (ID INTEGER PRIMARY KEY, DT VARCHAR)
alter index ROW_TEST on ROW_TEST partition cluster REPLICATED;

INSERT INTO ROW_TEST VALUES (1, uuid());
INSERT INTO ROW_TEST VALUES (2, uuid());
INSERT INTO ROW_TEST VALUES (3, uuid());
INSERT INTO ROW_TEST VALUES (4, uuid());
INSERT INTO ROW_TEST VALUES (5, uuid());
INSERT INTO ROW_TEST VALUES (6, repeat ('X', 1500));
INSERT INTO ROW_TEST VALUES (7, repeat ('X', 1500));
INSERT INTO ROW_TEST VALUES (8, repeat ('X', 1500));
INSERT INTO ROW_TEST VALUES (9, repeat ('X', 1500));

CREATE PROCEDURE TEST_ROW ()
{
  UPDATE ROW_TEST SET DT = '' WHERE ID = 1;
  UPDATE ROW_TEST SET DT = '' WHERE ID = 1;

  UPDATE ROW_TEST SET DT = repeat ('X', 1500) WHERE ID = 2;
  UPDATE ROW_TEST SET DT = '' WHERE ID = 2;

  UPDATE ROW_TEST SET DT = '' WHERE ID = 3;
  UPDATE ROW_TEST SET DT = repeat ('X', 1000) WHERE ID = 3;

  UPDATE ROW_TEST SET DT = uuid() WHERE ID = 4;
  UPDATE ROW_TEST SET DT = '' WHERE ID = 4;

  UPDATE ROW_TEST SET DT = '' WHERE ID = 5;
  UPDATE ROW_TEST SET DT = '  ' WHERE ID = 5;

  UPDATE ROW_TEST SET DT = '' where ID = 6;
  UPDATE ROW_TEST SET DT = '' where ID = 6;

  UPDATE ROW_TEST SET DT = '' where ID = 7;
  UPDATE ROW_TEST SET DT = uuid() where ID = 7;

  UPDATE ROW_TEST SET DT = uuid() where ID = 8;
  UPDATE ROW_TEST SET DT = uuid() where ID = 8;

  UPDATE ROW_TEST SET DT = '' where ID = 9;
  UPDATE ROW_TEST SET DT = repeat ('X', 1500) where ID = 9;
}

TEST_ROW ();

DROP TABLE B5258;

CREATE TABLE B5258(
        BI_BLOG_ID VARCHAR NOT NULL,
        BI_OWNER INTEGER,
        BI_HOME VARCHAR,
        BI_P_HOME VARCHAR,
        BI_DEFAULT_PAGE VARCHAR,
        BI_TITLE VARCHAR,
        BI_COPYRIGHTS VARCHAR,
        BI_DISCLAIMER VARCHAR,
        BI_WRITERS VARCHAR,
        BI_READERS VARCHAR,
        BI_PINGS VARCHAR,
        BI_ABOUT VARCHAR,
        BI_E_MAIL VARCHAR,
        BI_TZ INTEGER,
        BI_SHOW_CONTACT INTEGER,
        BI_SHOW_REGIST INTEGER,
        BI_COMMENTS INTEGER,
        BI_QUOTA INTEGER,
        BI_HOME_PAGE VARCHAR,
        BI_FILTER VARCHAR,
        BI_PHOTO VARCHAR,
        BI_KEYWORDS VARCHAR,
        BI_COMMENTS_NOTIFY INTEGER,
        PRIMARY KEY(BI_BLOG_ID));

INSERT INTO B5258
        (
        BI_BLOG_ID,
        BI_OWNER,
        BI_HOME,
        BI_P_HOME,
        BI_DEFAULT_PAGE,
        BI_TITLE,
        BI_COPYRIGHTS,
        BI_DISCLAIMER,
        BI_WRITERS,
        BI_READERS,
        BI_PINGS,
        BI_ABOUT,
        BI_E_MAIL,
        BI_TZ,
        BI_SHOW_CONTACT,
        BI_SHOW_REGIST,
        BI_COMMENTS,
        BI_QUOTA,
        BI_HOME_PAGE,
        BI_FILTER,
        BI_PHOTO,
        BI_KEYWORDS,
        BI_COMMENTS_NOTIFY)
        VALUES('103',103,'/blog/imitko/blog/','/DAV/imitko/blog/',NULL,'Mitko
Iliev\47s Weblog','copy','disc',NULL,NULL,'','private
blog','imitko@yahoo.com',0,1,NULL,1,NULL,'/blog/','*default*','','tehnology
software odbc',NULL);


alter table B5258 add dt long varchar;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": B5258 1st alter STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

alter table B5258 drop dt;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": B5258 2nd alter STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select count (*) from B5258;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": B5258 1st select check returned " $LAST[1] " rows\n";

drop table TEST_UDT_DUMP;
drop type TEST_UDT_DUMP_T;

create type TEST_UDT_DUMP_T as (D integer default 12)
method PLUS1 () returns integer;

create method PLUS1 () for TEST_UDT_DUMP_T
  {
    return SELF.D + 1;
  };

create table TEST_UDT_DUMP (ID integer primary key, DATA TEST_UDT_DUMP_T)
alter index TEST_UDT_DUMP on TEST_UDT_DUMP partition (ID int);

insert into TEST_UDT_DUMP values (1, new TEST_UDT_DUMP_T ());

charset_define ('PLOVDIVSKI', N'\x1\x2\x3\x4\x5\x6\x7\x8\x9\xA\xB\xC\xD\xE\xF\x10\x11\x12\x13\x14\x15\x16\x17\x18\x19\x1A\x1B\x1C\x1D\x1E\x1F\x20\x21\x22\x23\x24\x25\x26\x27\x28\x29\x2A\x2B\x2C\x2D\x2E\x2F\x30\x31\x32\x33\x34\x35\x36\x37\x38\x39\x3A\x3B\x3C\x3D\x3E\x3F\x40\x41\x42\x43\x44\x45\x46\x47\x48\x49\x4A\x4B\x4C\x4D\x4E\x4F\x50\x51\x52\x53\x54\x55\x56\x57\x58\x59\x5A\x5B\x5C\x5D\x5E\x5F\x60\x61\x62\x63\x64\x65\x66\x67\x68\x69\x6A\x6B\x6C\x6D\x6E\x6F\x70\x71\x72\x73\x74\x75\x76\x77\x78\x79\x7A\x7B\x7C\x7D\x7E\x7F\x402\x403\x201A\x453\x201E\x2026\x2020\x2021\x20AC\x2030\x409\x2039\x40A\x40C\x40B\x40F\x452\x2018\x2019\x201C\x201D\x2022\x2013\x2014\x98\x2122\x459\x203A\x45A\x45C\x45B\x45F\xA0\x40E\x45E\x408\xA4\x490\xA6\xA7\x401\xA9\x404\xAB\xAC\xAD\xAE\x407\xB0\xB1\x406\x456\x491\xB5\xB6\xB7\x451\x2116\x454\xBB\x458\x405\x455\x457\x410\x411\x412\x413\x414\x415\x416\x417\x418\x419\x41A\x41B\x41C\x41D\x41E\x41F\x420\x421\x422\x423\x424\x425\x426\x427\x428\x429\x42A\x42B\x42C\x42D\x42E\x42F\x430\x431\x432\x433\x434\x435\x436\x437\x438\x439\x43A\x43B\x43C\x43D\x43E\x43F\x440\x441\x442\x443\x444\x445\x446\x447\x448\x449\x44A\x44B\x44C\x44D\x44E\x44F', vector ('KARSHASKI', 'MARASHKI', 'TRAKIISKI', 'PROSLAVSKI', 'GAGARINSKI', 'CENTRALEN', 'SMIRNENSI', 'KOMATEVSKI', 'IZGREVSKI'));


collation_define('PLOVDIVSKI', 'spanish.coll', 1);

drop table INX_LARGE_TB;
create table INX_LARGE_TB (ID integer, DATA varchar (50))
alter index INX_LARGE_TB on INX_LARGE_TB partition (ID int);
foreach integer between 1 100000 insert into INX_LARGE_TB values (?, 'data');

update inx_large_tb set data = cast  (id as varchar) || data;
create index INX_LARGE on INX_LARGE_TB ("DATA") partition ("DATA" varchar);
create index INX_LARGE_2 on INX_LARGE_TB ("DATA") partition ("DATA" varchar);
drop index INX_LARGE_2;

drop table INX_SMALL_TB;
create table INX_SMALL_TB (ID integer, DATA varchar (50))
alter index INX_SMALL_TB on INX_SMALL_TB partition (_IDN int);

foreach integer between 1 100 insert into INX_SMALL_TB values (?, 'data');
create index INX_SMALL on INX_SMALL_TB ("DATA") partition ("DATA" varchar);
create index INX_SMALL_2 on INX_SMALL_TB ("DATA") partition ("DATA" varchar);
drop index INX_SMALL_2;

drop table INX_LARGE_TB2;
create table INX_LARGE_TB2 (ID integer, DATA varchar (50))
alter index INX_LARGE_TB2 on INX_LARGE_TB2 partition (_IDN int);

foreach integer between 1 100000 insert into INX_LARGE_TB2 values (?, 'data');

create unique index INX2_LARGE on INX_LARGE_TB2 (DATA) partition ("DATA" varchar);
create unique index INX2_LARGE_2 on INX_LARGE_TB2 (ID);

drop table INX_SMALL_TB2;
create table INX_SMALL_TB2 (ID integer, DATA varchar (50));
foreach integer between 1 100 insert into INX_SMALL_TB2 values (?, 'data');
create unique index INX2_SMALL on INX_SMALL_TB2 (DATA);
create unique index INX2_SMALL_2 on INX_SMALL_TB2 (ID);

-- FK checks
drop table FK_OK2;
drop table FK_OK1;
create table FK_OK1 (ID integer primary key, DATA varchar(50))
 alter index FK_OK1 on FK_OK1 partition (ID int);
create table FK_OK2 (ID integer primary key, FK_OK1_ID integer,
	constraint FK_OK1_FK foreign key (FK_OK1_ID) references FK_OK1 (ID));
IF_CLUSTER ('alter index FK_OK2 on FK_OK2 partition cluster C2 (ID int (0hexffff00))');
foreignkeys FK_OK1;

drop table AFK_OK2;
drop table AFK_OK1;
create table AFK_OK1 (ID integer primary key, DATA varchar(50));
IF_CLUSTER ('alter index FK_OK1 on FK_OK1 partition cluster C2 (ID int (0hexffff00))');
create table AFK_OK2 (ID integer primary key, FK_OK1_ID integer);
IF_CLUSTER ('alter index FK_OK2 on FK_OK2 partition cluster C2 (ID int (0hexffff00))');

insert into AFK_OK1 (ID, DATA) values (1, 'a');
insert into AFK_OK2 (ID, FK_OK1_ID) values (1, 1);

alter table AFK_OK2 add constraint AFK_OK1_ID foreign key (FK_OK1_ID) references AFK_OK1 (ID);
foreignkeys AFK_OK1;

drop table AFK_BAD2;
drop table AFK_BAD1;
create table AFK_BAD1 (ID integer primary key, DATA varchar(50));
IF_CLUSTER ('alter index AFK_BAD1 on AFK_BAD1 partition cluster C2 (ID int (0hexffff00))');
create table AFK_BAD2 (ID integer primary key, FK_BAD1_ID integer);
IF_CLUSTER ('alter index AFK_BAD2 on AFK_BAD2 partition cluster C2 (ID int (0hexffff00))');

insert into AFK_BAD1 (ID, DATA) values (1, 'a');
insert into AFK_BAD2 (ID, FK_BAD1_ID) values (1, 2);

alter table AFK_BAD2 add constraint AFK_BAD1_ID foreign key (FK_BAD1_ID) references AFK_BAD1 (ID);
foreignkeys AFK_BAD1;

-- rename
drop table REN_TB1_FROM;
drop table REN_TB1_TO;

create table REN_TB1_FROM (ID integer primary key)
alter index REN_TB1_FROM on REN_TB1_FROM partition (ID int);
alter table REN_TB1_FROM rename REN_TB1_TO;

tables REN_TB1_TO;
ECHO BOTH $IF $NEQ $ROWCNT 1 "***FAILED" $IF $EQU $LAST[3] REN_TB1_TO "PASSED" "***FAILED";
ECHO BOTH ": REN_TB1_TO present.\n";

select * from REN_TB1_TO;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": REN_TB1_TO selectable.\n";

tables REN_TB1_FROM;
ECHO BOTH $IF $EQU $ROWCNT 0 "PASSED" "***FAILED";
ECHO BOTH ": REN_TB1_FROM not present.\n";

select * from REN_TB1_FROM;
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": REN_TB1_FROM not selectable.\n";


drop table REN_TB2_FROM;
drop table REN_TB2_BAD;

create table REN_TB2_FROM (ID integer primary key)
 alter index REN_TB2_FROM on REN_TB2_FROM partition (ID int);
create table REN_TB2_BAD (ID integer primary key)
alter index REN_TB2_BAD on REN_TB2_BAD partition cluster C2 (ID int);

alter table REN_TB2_FROM rename REN_TB2_BAD;

tables REN_TB2_BAD;
ECHO BOTH $IF $NEQ $ROWCNT 1 "***FAILED" $IF $EQU $LAST[3] REN_TB2_BAD "PASSED" "***FAILED";
ECHO BOTH ": REN_TB2_BAD present.\n";

select * from REN_TB2_BAD;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": REN_TB2_BAD selectable.\n";

tables REN_TB2_FROM;
ECHO BOTH $IF $NEQ $ROWCNT 1 "***FAILED" $IF $EQU $LAST[3] REN_TB2_FROM "PASSED" "***FAILED";
ECHO BOTH ": REN_TB2_FROM present.\n";

select * from REN_TB2_FROM;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": REN_TB2_FROM selectable.\n";

drop table B6978_1;
drop table B6978_2;
drop table B6978_3;

create table B6978_1 (ID int primary key, DATA long varchar);
 alter index B6978_1 on B6978_1 partition (ID int);
insert into B6978_1 (ID, DATA) values (1, repeat ('n', 20000));

create table B6978_2 as select ID, DATA from B6978_1 without data;
ECHO BOTH $IF $EQU $STATE 'OK' "PASSED" "***FAILED";
ECHO BOTH ": B6978-1 table copied without data. STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

create table B6978_3 as select ID + 12, DATA from B6978_1 with data;
ECHO BOTH $IF $EQU $STATE 'OK' "PASSED" "***FAILED";
ECHO BOTH ": B6978-2 table copied with data. STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select * from B6978_2;
ECHO BOTH $IF $EQU $COLCNT 2 "PASSED" "***FAILED";
ECHO BOTH ": B6978-3 table copied has all cols. COLCNT=" $COLCNT "\n";
ECHO BOTH $IF $EQU $ROWCNT 0 "PASSED" "***FAILED";
ECHO BOTH ": B6978-4 table copied does not have data. ROWCNT=" $ROWCNT "\n";

select * from B6978_3;
ECHO BOTH $IF $EQU $COLCNT 2 "PASSED" "***FAILED";
ECHO BOTH ": B6978-5 table with data copied has all cols. COLCNT=" $COLCNT "\n";
ECHO BOTH $IF $EQU $ROWCNT 1 "PASSED" "***FAILED";
ECHO BOTH ": B6978-6 table with data copied does have data. ROWCNT=" $ROWCNT "\n";

-- should be in casemode 2
drop table B9948;

create table B9948(
	ID integer not null,
	ID2 integer not null,
	primary key (id, id2)
);

columns B9948;
ECHO BOTH $IF $EQU $ROWCNT 2 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": B9948 test case returns " $ROWCNT " cols STATE=" $STATE " MESSAGE=" $MESSAGE "\n";


ECHO BOTH "tschema1 check trees\n";
cl_exec ('backup ''/dev/null''');
