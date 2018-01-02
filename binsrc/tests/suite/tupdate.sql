--
--  tupdate.sql
--
--  $Id: tupdate.sql,v 1.20.2.4.4.4 2013/01/02 16:15:32 source Exp $
--
--  Update tests
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2018 OpenLink Software
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

echo BOTH "STARTED: UPDATE TEST (this might take long)\n";

CONNECT;

-- Timeout to two hours.
SET TIMEOUT 7200;
set DEADLOCK_RETRIES = 200;
drop table words;
create table words(word varchar, revword varchar, len integer, primary key(word))
  alter index words on words partition (word varchar);
create index revword on words(revword) partition (revword varchar);
create index len on words(len) partition (len int);

load revstr.sql;
load succ.sql;


foreach line in words.esp
 insert into words(word,revword,len) values(?,revstr(?1),length(?1));

select count(*) from words;
ECHO BOTH $IF $EQU $LAST[1] 86061 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Table word contains count(*) " $LAST[1] " lines\n";

alter table words add word2 varchar;



update words table option (index primary key) set word2 = word where len <9;
ECHO BOTH $IF $EQU $STATE "OK" "PASSED" "***FAILED";
ECHO BOTH ": update words set word2 = word; STATE=" $STATE " MESSAGE=" $MESSAGE "\n";
ECHO BOTH $IF $EQU $ROWCNT 42406"PASSED" "***FAILED";
ECHO BOTH ": " $ROWCNT " rows updated\n";

select top 10 revword from words a table option (index words) where not exists (select 1 from words b table option (loop) where a.revword = b.revword);
echo both $if $neq $rowcnt 0 "***FAILED" "PASSED";
echo both ":  revword inx oow 1\n";
select * from words where word = 'a';
echo both $if $neq $rowcnt 1 "***FAILED" "PASSED";
echo both ":  wirds a ck 1\n";



-- check reading inx with mixed vcersions of keys
select count (*) from words where word > 'b';

select count (*) from words a where exists (select 1 from words b table option (loop) where a.word = b.word);
ECHO BOTH $IF $EQU $LAST[1] 86061 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Table word contains count(*) " $LAST[1] " lines, mixed versions\n";



select count (*) from words a where exists (select 1 from words b table option (loop) where b.word >= a.word and b.word < a.word || '0');
ECHO BOTH $IF $EQU $LAST[1] 86061 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Table word contains count(*) " $LAST[1] " lines, mixed versions with range\n";


update words table option (index len) set word2 = word where len >= 9;
ECHO BOTH $IF $EQU $ROWCNT 43655 "PASSED" "***FAILED";
ECHO BOTH ": " $ROWCNT " rows updated by inx len gte 9\n";


update words set word2 = word;
ECHO BOTH $IF $EQU $STATE "OK" "PASSED" "***FAILED";
ECHO BOTH ": update words set word2 = word; STATE=" $STATE " MESSAGE=" $MESSAGE "\n";
ECHO BOTH $IF $EQU $ROWCNT 86061 "PASSED" "***FAILED";
ECHO BOTH ": " $ROWCNT " rows updated\n";


update words set word2 = concat (word2, '-');
ECHO BOTH $IF $EQU $STATE "OK" "PASSED" "***FAILED";
ECHO BOTH ": update words set word2 = concat (word2, '-'); STATE=" $STATE " MESSAGE=" $MESSAGE "\n";
ECHO BOTH $IF $EQU $ROWCNT 86061 "PASSED" "***FAILED";
ECHO BOTH ": " $ROWCNT " rows updated\n";

select top 10 revword from words a table option (index words) where not exists (select 1 from words b table option (loop) where a.revword = b.revword);
echo both $if $neq $rowcnt 0 "***FAILED" "PASSED";
echo both ":  revword inx ck 2\n";


-- Was: update words set word2 = subseq (word2, 0, length (word2) - 1);
-- This is more to standard:
update words set word2 = LEFT (word2, length (word2) - 1);
ECHO BOTH $IF $EQU $STATE "OK" "PASSED" "***FAILED";
ECHO BOTH ": update words set word2 = left(word2,length(word2)-1); STATE=" $STATE " MESSAGE=" $MESSAGE "\n";
ECHO BOTH $IF $EQU $ROWCNT 86061 "PASSED" "***FAILED";
ECHO BOTH ": " $ROWCNT " rows updated\n";

select count (*) from words where word2 <> word;
ECHO BOTH $IF $EQU $STATE "OK" "PASSED" "***FAILED";
ECHO BOTH ": select count(*) from words; STATE=" $STATE " MESSAGE=" $MESSAGE "\n";
ECHO BOTH  $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH  ": " $LAST[1] " words where word2 <> word\n";

update words set word2 = 'q' where revword between 'a' and 'b';
ECHO BOTH $IF $EQU $STATE "OK" "PASSED" "***FAILED";
ECHO BOTH ": update words set word2 = 'q' where revword between 'a' and 'b'; STATE=" $STATE " MESSAGE=" $MESSAGE "\n";
ECHO BOTH $IF $EQU $ROWCNT 28810 "PASSED" "***FAILED";
ECHO BOTH ": " $ROWCNT " rows updated\n";

update words set word2 = word where revword between 'a' and 'b';
ECHO BOTH $IF $EQU $STATE "OK" "PASSED" "***FAILED";
ECHO BOTH ": update words set word2 = word where revword between 'a' and 'b'; STATE=" $STATE " MESSAGE=" $MESSAGE "\n";
ECHO BOTH $IF $EQU $ROWCNT 28810 "PASSED" "***FAILED";
ECHO BOTH ": " $ROWCNT " rows updated\n";

update words set word = concat ('-', word);
ECHO BOTH $IF $EQU $STATE "OK" "PASSED" "***FAILED";
ECHO BOTH ": update words set word = concat('-',word); STATE=" $STATE " MESSAGE=" $MESSAGE "\n";
ECHO BOTH $IF $EQU $ROWCNT 86061 "PASSED" "***FAILED";
ECHO BOTH ": " $ROWCNT " rows updated\n";


select top 10 revword from words a table option (index words) where not exists (select 1 from words b table option (loop) where a.revword = b.revword);
echo both $if $neq $rowcnt 0 "***FAILED" "PASSED";
echo both ":  revword inx ck 3\n";

select * from words where word = '-a';
echo both $if $neq $rowcnt 1 "***FAILED" "PASSED";
echo both ":  wirds a ck 1\n";

select count (*) from words where word2 = word;
ECHO BOTH $IF $EQU $STATE "OK" "PASSED" "***FAILED";
ECHO BOTH ": select count (*) from words; STATE=" $STATE " MESSAGE=" $MESSAGE "\n";
ECHO BOTH  $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH  ": " $LAST[1] " words where word2 = word\n";

cl_exec ('checkpoint');

update words set word = word2 where word like '-%';
ECHO BOTH $IF $EQU $STATE "OK" "PASSED" "***FAILED";
ECHO BOTH ": update words set word = word2 where word like '-%'; STATE=" $STATE " MESSAGE=" $MESSAGE "\n";
ECHO BOTH $IF $EQU $ROWCNT 86061 "PASSED" "***FAILED";
ECHO BOTH ": " $ROWCNT " rows updated\n";


select top 10 revword from words a table option (index words) where not exists (select 1 from words b table option (loop) where a.revword = b.revword);
echo both $if $neq $rowcnt 0 "***FAILED" "PASSED";
echo both ":  revword inx ck 3\n";
select * from words where word = 'a';
echo both $if $neq $rowcnt 1 "***FAILED" "PASSED";
echo both ":  wirds a ck 1\n";


select count (*) from words where word <> word2;
ECHO BOTH $IF $EQU $STATE "OK" "PASSED" "***FAILED";
ECHO BOTH ": select count (*) from words; STATE=" $STATE " MESSAGE=" $MESSAGE "\n";
ECHO BOTH  $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH  ": " $LAST[1] " words where word2 <> word\n";

update words set word = concat ('-', word) where revword between 'a' and 'ad';
ECHO BOTH $IF $EQU $STATE "OK" "PASSED" "***FAILED";
ECHO BOTH ": update words set word = concat('-',word) where ...; STATE=" $STATE " MESSAGE=" $MESSAGE "\n";
ECHO BOTH $ROWCNT " rows updated\n";


select top 10 revword from words a table option (index words) where not exists (select 1 from words b table option (loop) where a.revword = b.revword);
echo both $if $neq $rowcnt 0 "***FAILED" "PASSED";
echo both ":  revword inx ck 4\n";

select * from words where word = '-a';
echo both $if $neq $rowcnt 1 "***FAILED" "PASSED";
echo both ":  wirds a ck 1\n";


update words set word = subseq (word, 1, length (word)) where aref (word, 0) = aref ('-', 0);
ECHO BOTH $IF $EQU $STATE "OK" "PASSED" "***FAILED";
ECHO BOTH ": update words set word = subseq (word, 1, length(word)) where ...; STATE=" $STATE " MESSAGE=" $MESSAGE "\n";
ECHO BOTH $ROWCNT " rows updated\n";


select top 10 revword from words a table option (index words) where not exists (select 1 from words b table option (loop) where a.revword = b.revword);
echo both $if $neq $rowcnt 0 "***FAILED" "PASSED";
echo both ":  revword inx ck 5\n";

update words set word = subseq (word, 1, length (word)) where word like '-%';
ECHO BOTH $IF $EQU $STATE "OK" "PASSED" "***FAILED";
ECHO BOTH ": update words set word = subseq (word, 1, length(word)) where ...; STATE=" $STATE " MESSAGE=" $MESSAGE "\n";
ECHO BOTH $ROWCNT " rows updated\n";

select top 10 revword from words a table option (index words) where not exists (select 1 from words b table option (loop) where a.revword = b.revword);
echo both $if $neq $rowcnt 0 "***FAILED" "PASSED";
echo both ":  revword inx ck 6\n";

select * from words where word = 'a';
echo both $if $neq $rowcnt 1 "***FAILED" "PASSED";
echo both ":  wirds a ck 1\n";


update words set word = word, word2 = word2;
ECHO BOTH $IF $EQU $STATE "OK" "PASSED" "***FAILED";
ECHO BOTH ": update words set word = word, word2 = word2; STATE=" $STATE " MESSAGE=" $MESSAGE "\n";
ECHO BOTH $IF $EQU $ROWCNT 86061 "PASSED" "***FAILED";
ECHO BOTH ": " $ROWCNT " rows updated\n";

select top 10 revword from words a table option (index words) where not exists (select 1 from words b table option (loop) where a.revword = b.revword);
echo both $if $neq $rowcnt 0 "***FAILED" "PASSED";
echo both ":  revword inx ck 7\n";


select * from words where word = 'a';
echo both $if $neq $rowcnt 1 "***FAILED" "PASSED";
echo both ":  wirds a ck 1\n";

exit;
-- Set ROWCNT to some different value, so that we see whether the next
-- update statements have any effect:
SET ROWCNT -12345;

-- The next two produce error messages like these:
-- *** Error .....: Ruling part too long on words.

update words set word = word, word2 = make_string (10000) where word = 'a';
-- ECHO BOTH $IF $EQU $STATE "OK" "PASSED" "***FAILED";
ECHO BOTH "update words set word = word, word2 = make_string(10000) where word = 'a'; STATE=" $STATE " MESSAGE=" $MESSAGE "\n";
ECHO BOTH $ROWCNT " rows updated\n";

update words set word2 = make_string (10000) where word = 'a';
-- ECHO BOTH $IF $EQU $STATE "OK" "PASSED" "***FAILED";
ECHO BOTH "update words set word2 = make_string(10000) where word = 'a'; STATE=" $STATE " MESSAGE=" $MESSAGE "\n";
ECHO BOTH $ROWCNT " rows updated\n";

select count (*) from words where word <> word2;
ECHO BOTH $IF $EQU $STATE "OK" "PASSED" "***FAILED";
ECHO BOTH ": select count (*) from words; STATE=" $STATE " MESSAGE=" $MESSAGE "\n";
ECHO BOTH  $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": " $LAST[1] " words where word2 <> word\n";

checkpoint;
set autocommit manual;
update words set len = 'qqqq' where word = 'a';
ECHO BOTH $IF $EQU $STATE 22005 "PASSED" "***FAILED";
ECHO BOTH ": update type error " $STATE $MESSAGE "\n";
rollback work;
update words set word = 'qqqq', len = 'qqqq' where word = 'a';
ECHO BOTH $IF $EQU $STATE 22005 "PASSED" "***FAILED";
ECHO BOTH ": update type error " $STATE $MESSAGE "\n";

rollback work;
set autocommit off;

insert into T1 (ROW_NO, FI2, FREAL, FDOUBLE) values (1, 1, 2, 3);
select FI2, FREAL, FDOUBLE from T1 where ROW_NO = 1;

insert into T1 (ROW_NO, FI2, FREAL, FDOUBLE) values (2, convert (real, 1), convert (real, 1), convert (real, 1));
select FI2, FREAL, FDOUBLE from T1 where ROW_NO = 2;

insert into T1 (ROW_NO, FI2, FREAL, FDOUBLE) values (3, 1.1, 2.2, 3.3);
select FI2, FREAL, FDOUBLE from T1 where ROW_NO = 3;

select distinct internal_type (FI2), internal_type (FREAL), internal_type (FDOUBLE) from T1 where ROW_NO < 4;
ECHO BOTH $IF $EQU $ROWCNT 1 "PASSED" "***FAILED";
ECHO BOTH ": error in numeric type conversion.\n";

-- type error in update_quick w/ new len = old en and new_len > old_len.
update T1 set FDOUBLE = 'abcdefg' where ROW_NO < 4;
update T1 set FDOUBLE = 'abcdefghij' where ROW_NO < 4;
update T1 set FREAL = 12.12, FDOUBLE = 'abd' where ROW_NO < 4;


select * from T1 where ROW_NO < 4;
delete from T1 where ROW_NO < 4;

--
-- Overflows
--
create table u_test (pkstring varchar, skstring varchar, dstring varchar,
	primary key (pkstring));

create index sk on u_test (skstring);

insert into u_test values (repeat ('p', 500), repeat ('k', 500), repeat ('d', 500));

--- XXX: for some reason the upd_recompose_row allows 8K rows, whereas insert_node_run allows only for 4K (half page)
update u_test set dstring = make_string (8000);
update u_test set skstring = skstring, dstring = make_string (8000);
update u_test set skstring = skstring, dstring = make_string (10000);

update u_test set dstring = repeat ('d', 100);

insert into u_test values (repeat ('p', 3000) , repeat ('k', 2000) , 'dd');

select length (pkstring), length (skstring), length (dstring) from u_test;
select count (*) from u_test;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": " $LAST[1] " rows in u_test\n";

select count (*) from u_test where length (pkstring) = 500 and length (skstring) = 500;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": " $LAST[1] " rows in u_test, meets unchanged by errorbeiys updates\n";

select count (*) from u_test where length (pkstring) = 500 and length (skstring) = 500 order by skstring;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": " $LAST[1] " rows in u_test, meets unchanged by errorbeiys updates, key 2\n";


drop table tl;
create table tl (str varchar);
insert into tl values (make_string (300));
insert into tl values (make_string (300));
insert into tl values (make_string (300));
insert into tl values (make_string (300));
insert into tl values (make_string (300));
insert into tl values (make_string (300));
insert into tl values (make_string (300));

update tl set str = '----------';
select sum (length (str)) from tl;

drop table LOCK_TT;
set lock_escalation_pct = 10;
create table LOCK_TT (ID int identity not null primary key, CTR int);
create procedure LOCK_TT_FILL (in N int)
{
  declare _CTR int;
  _CTR := 0;
  while (_CTR < N)
    {
      insert into LOCK_TT (CTR) values (_CTR);
      _CTR := _CTR + 1;
    }
}


select sys_stat ('tc_pl_split_while_wait');
echo both " tc_pl_split_while_wait=" $last[1] "\n";


drop table trb;
create table trb (id int, st varchar, primary key (id));

insert into trb values (1, make_string (250));

select length (cast (_ROW as varchar)),aref (cast (_ROW as varchar), 0) from trb;

update trb set st = make_string (234);

create procedure trb ()
{
	update trb set st = make_string (235);
	rollback work;
}

trb ();

select length (cast (_ROW as varchar)),aref (cast (_ROW as varchar), 0) from trb;


create procedure u2 ()
{
  declare deadlock_retry_count integer;

  deadlock_retry_count := 100;
  declare exit handler for sqlstate '40001'
    {
      rollback work;
      if (deadlock_retry_count > 0)
	{
	  deadlock_retry_count := deadlock_retry_count - 1;
	  goto again;
	}
      else
	resignal;
    };

again:
  update words set word2 = '';
  rollback work;

  update words set word2 = concat (word2, '----------');
  update words set word2 = '';
  update words set word2 = word;
  commit work;
  update words set word2 = 'q';
  rollback work;
  delete from words;
  rollback work;
}

u2 ();
ECHO BOTH $IF $EQU $STATE "OK" "PASSED" "***FAILED";
ECHO BOTH ": u2 (); STATE=" $STATE " MESSAGE=" $MESSAGE "\n";


-- suite for bug #1778
drop table BUG1778..TEST;
create table BUG1778..TEST (ID integer not null,
                        VAL LONG VARBINARY,
                        primary key(ID));

create procedure BUG1778..TEST(in op integer){

 declare TEST any;

 if (op = 1)
   {
     INSERT INTO BUG1778..TEST (ID,VAL) values(2,TEST);
   }
 else if (op = 2)
   {
     INSERT INTO BUG1778..TEST (ID,VAL) values(1,null);
     UPDATE BUG1778..TEST SET VAL = TEST WHERE ID = 1;
   }
};

call BUG1778..TEST(1);
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "*** FAILED";
ECHO BOTH ": BUG 1778: set a blob to 0 STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

call BUG1778..TEST(2);
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "*** FAILED";
ECHO BOTH ": BUG 1778-2: set a blob to 0 STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

drop table B3600_T;

CREATE TABLE B3600_T(
  ID               INTEGER        NOT NULL,
  FIELD    	       NVARCHAR       NULL,

  PRIMARY KEY(ID)

);

create procedure B3600_P(){
  if (1 = 2)
    return 'test';
};

INSERT into B3600_T values (1, B3600_P());
ECHO BOTH $IF $EQU $STATE OK "PASSED" "*** FAILED";
ECHO BOTH ": BUG 3600: set NVARCHAR to 0 STATE=" $STATE " MESSAGE=" $MESSAGE "\n";


--suite for bug #3597
drop table B3597;

CREATE TABLE B3597(
    ACCOUNTNO	       NVARCHAR       NOT NULL,
    COMPANY	         NVARCHAR       NULL,
    CONTACT	         NVARCHAR       NULL,
    LASTNAME	       NVARCHAR       NULL,
    DEPARTMENT	     NVARCHAR       NULL,
    TITLE	           NVARCHAR       NULL,
    SECR	           NVARCHAR       NULL,
    PHONE1	         NVARCHAR       NULL,
    PHONE2	         NVARCHAR       NULL,
    PHONE3	         NVARCHAR       NULL,
    FAX	             NVARCHAR       NULL,
    EXT1	           NVARCHAR       NULL,
    EXT2	           NVARCHAR       NULL,
    EXT3	           NVARCHAR       NULL,
    EXT4	           NVARCHAR       NULL,
    ADDRESS1	       NVARCHAR       NULL,
    ADDRESS2	       NVARCHAR       NULL,
    CITY	           NVARCHAR       NULL,
    STATE	           NVARCHAR       NULL,
    ZIP	             NVARCHAR       NULL,
    COUNTRY	         NVARCHAR       NULL,
    DEAR	           NVARCHAR       NULL,
    SOURCE	         NVARCHAR       NULL,
    KEY1	           NVARCHAR       NULL,
    KEY2	           NVARCHAR       NULL,
    KEY3	           NVARCHAR       NULL,
    KEY4	           NVARCHAR       NULL,
    KEY5	           NVARCHAR       NULL,
    STATUS	         NVARCHAR       NULL,
    NOTES	           LONG NVARCHAR  NULL,
    CREATEBY	       NVARCHAR   	  NULL,
    OWNER	           NVARCHAR   	  NULL,
    LASTUSER	       NVARCHAR   	  NULL,
    LASTDATE	       DATETIME	      NULL,
    LASTTIME	       NVARCHAR       NULL,
    RECID	           NVARCHAR       NULL,

PRIMARY KEY(ACCOUNTNO)
    );

INSERT INTO B3597
    (ACCOUNTNO,
     COMPANY,
     CONTACT,
     LASTNAME,
     DEPARTMENT,
     TITLE,
     SECR,
     PHONE1,
     PHONE2,
     PHONE3,
     FAX,
     EXT1,
     EXT2,
     EXT3,
     EXT4,
     ADDRESS1,
     ADDRESS2,
     CITY,
     STATE,
     ZIP,
     COUNTRY,
     DEAR,
     SOURCE,
     KEY1,
     KEY2,
     KEY3,
     KEY4,
     KEY5,
     STATUS,
     NOTES,
     CREATEBY,
     OWNER,
     LASTUSER,
     LASTDATE,
     LASTTIME,
     RECID)
     VALUES
     ('ACCOUNTNO',
      'COMPANY',
      'CONTACT',
      'LASTNAME',
      'DEPARTMENT',
      'TITLE',
      'SECR',
      'PHONE1',
      'PHONE2',
      'PHONE3',
      'FAX',
      'EXT1',
      'EXT2',
      'EXT3',
      'EXT4',
      'ADDRESS1',
      'ADDRESS2',
      'CITY',
      'STATE',
      'ZIP',
      'COUNTRY',
      'DEAR',
      'SOURCE',
      'KEY1',
      'KEY2',
      'KEY3',
      'KEY4',
      'KEY5',
      'STATUS',
      'NOTES',
      'CREATEBY',
      'OWNER',
      'LASTUSER',
      now(),
      'LASTTIME',
      'RECID');
ECHO BOTH $IF $EQU $STATE OK "PASSED" "*** FAILED";
ECHO BOTH ": BUG 3597: more than 20 casts STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

drop table B7752_TB;
create table B7752_TB (K varchar primary key, V varchar);

create procedure B7752_P()
  {
    declare i integer;
    i := 0;
    while (i < 20000)
      {
	insert into B7752_TB values (cast (i as varchar), cast (space(i) as varchar));
	i := i+1;
      }
  };

B7752_P ();
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "*** FAILED";
ECHO BOTH ": BUG 7752: wrong max row len check STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

echo BOTH "COMPLETED: UPDATE TEST\n";



echo BOTH "STARTED: keyset update tests\n";
CONNECT;

--set echo on;

SET ARGV[0] 0;
SET ARGV[1] 0;

use B12964;

create procedure f (in x any)
{
  return x + 1;
};

drop table XX;
drop table XX_upd_log;

create table XX (a integer primary key, b int);
create table XX_upd_log (x int identity primary key, oa int, ob int, na int, nb int, dt varchar);

create trigger XX_U_B before update on XX referencing old as O, new as N {
  dbg_obj_print ('before update', O.a, N.a, N.b);
  insert into XX_upd_log (oa,ob,na,nb,dt) values (O.a, O.b, N.a, N.b, 'bu');
};

create trigger XX_U_INST instead of update on XX referencing old as O, new as N {
  dbg_obj_print ('instead update' , O.a, N.a, N.b);
  insert into XX_upd_log (oa,ob,na,nb,dt) values (O.a, O.b, N.a, N.b, 'iu');
};

create trigger XX_U_A after update on XX referencing old as O, new as N {
  dbg_obj_print ('after update' , O.a, N.a, N.b);
  insert into XX_upd_log (oa,ob,na,nb,dt) values (O.a, O.b, N.a, N.b, 'au');
};


insert into XX (a) values (1);
insert into XX (a) values (2);
insert into XX (a) values (3);

select * from XX;
echo both $if $equ $rowcnt 3 "PASSED" "***FAILED";
set argv[$lif] $+ $argv[$lif] 1;
echo both " " $rowcnt " rows after insert \n";


update XX set a = a + 2 where a > 1;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": update ... where a > 1 : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select * from XX where a > 3;
echo both $if $equ $rowcnt 0 "PASSED" "***FAILED";
set argv[$lif] $+ $argv[$lif] 1;
echo both " " $rowcnt " rows with a > 3 after update with instead of trigger \n";

select * from XX_upd_log where dt = 'bu';
echo both $if $equ $rowcnt 2 "PASSED" "***FAILED";
set argv[$lif] $+ $argv[$lif] 1;
echo both " " $rowcnt " rows logged to be updated in before update trigger \n";

select * from XX_upd_log where dt = 'iu';
echo both $if $equ $rowcnt 2 "PASSED" "***FAILED";
set argv[$lif] $+ $argv[$lif] 1;
echo both " " $rowcnt " rows logged to be updated in instead of update trigger \n";

select * from XX_upd_log where dt = 'au';
echo both $if $equ $rowcnt 2 "PASSED" "***FAILED";
set argv[$lif] $+ $argv[$lif] 1;
echo both " " $rowcnt " rows logged to be updated in after update trigger \n";

drop trigger XX_U_INST;
delete from XX_upd_log;

update XX set a = a + 2, b = f(a) where a > 1;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": update ... where a > 1 : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select * from XX where a > 3;
echo both $if $equ $rowcnt 2 "PASSED" "***FAILED";
set argv[$lif] $+ $argv[$lif] 1;
echo both " " $rowcnt " rows with a > 3 after update w/o instead of trigger \n";

select * from XX_upd_log where dt = 'bu';
echo both $if $equ $rowcnt 2 "PASSED" "***FAILED";
set argv[$lif] $+ $argv[$lif] 1;
echo both " " $rowcnt " rows logged to be updated in before update trigger \n";

select * from XX_upd_log where dt = 'iu';
echo both $if $equ $rowcnt 0 "PASSED" "***FAILED";
set argv[$lif] $+ $argv[$lif] 1;
echo both " " $rowcnt " rows logged to be updated in instead of update trigger \n";

select * from XX_upd_log where dt = 'au';
echo both $if $equ $rowcnt 2 "PASSED" "***FAILED";
set argv[$lif] $+ $argv[$lif] 1;
echo both " " $rowcnt " rows logged to be updated in after update trigger \n";

delete from XX;
delete from XX_upd_log;

insert into XX (a) values (1);
insert into XX (a) values (2);
insert into XX (a) values (3);

select * from XX;
echo both $if $equ $rowcnt 3 "PASSED" "***FAILED";
set argv[$lif] $+ $argv[$lif] 1;
echo both " " $rowcnt " rows after insert \n";

create trigger XX_U_B before update on XX referencing old as O, new as N {
  dbg_obj_print ('before update - signal', O.a, N.a, N.b);
  insert into XX_upd_log (oa,ob,na,nb,dt) values (O.a, O.b, N.a, N.b, 'bu');
  commit work;
  signal ('TESTX', 'Some test signal in before trigger');
};


update XX set a = a + 2, b = f (a) where a > 1;
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": update ... where a > 1 : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select * from XX where a > 3;
echo both $if $equ $rowcnt 0 "PASSED" "***FAILED";
set argv[$lif] $+ $argv[$lif] 1;
echo both " " $rowcnt " rows with a > 3 after update with signal in before update trigger \n";

select * from XX_upd_log where dt = 'bu';
echo both $if $equ $rowcnt 1 "PASSED" "***FAILED";
set argv[$lif] $+ $argv[$lif] 1;
echo both " " $rowcnt " rows logged to be updated in before update trigger \n";

select * from XX_upd_log where dt = 'iu';
echo both $if $equ $rowcnt 0 "PASSED" "***FAILED";
set argv[$lif] $+ $argv[$lif] 1;
echo both " " $rowcnt " rows logged to be updated in instead of update trigger \n";

select * from XX_upd_log where dt = 'au';
echo both $if $equ $rowcnt 0 "PASSED" "***FAILED";
set argv[$lif] $+ $argv[$lif] 1;
echo both " " $rowcnt " rows logged to be updated in after update trigger \n";

drop trigger XX_U_B;
create trigger XX_U_B before update on XX referencing old as O, new as N {
  dbg_obj_print ('before update - recreated', O.a, N.a, N.b);
  insert into XX_upd_log (oa,ob,na,nb,dt) values (O.a, O.b, N.a, N.b, 'bu');
};

delete from XX;
delete from XX_upd_log;

insert into XX (a) values (1);
insert into XX (a) values (2);
insert into XX (a) values (3);

select * from XX;
echo both $if $equ $rowcnt 3 "PASSED" "***FAILED";
set argv[$lif] $+ $argv[$lif] 1;
echo both " " $rowcnt " rows after insert \n";

create trigger XX_U_A after update on XX referencing old as O, new as N {
  dbg_obj_print ('after update with signal' , O.a, N.a, N.b);
  insert into XX_upd_log (oa,ob,na,nb,dt) values (O.a, O.b, N.a, N.b, 'au');
  commit work;
  signal ('TESTX', 'Some test signal in after trigger');
};

update XX set a = a + 2, b = f (a) where a > 1;
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": update ... where a > 1 error in after trigger : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select * from XX where a > 3;
echo both $if $equ $rowcnt 1 "PASSED" "***FAILED";
set argv[$lif] $+ $argv[$lif] 1;
echo both " " $rowcnt " rows with a > 3 after update with signal in after update trigger \n";

select * from XX_upd_log where dt = 'bu';
echo both $if $equ $rowcnt 1 "PASSED" "***FAILED";
set argv[$lif] $+ $argv[$lif] 1;
echo both " " $rowcnt " rows logged to be updated in before update trigger \n";

select * from XX_upd_log where dt = 'iu';
echo both $if $equ $rowcnt 0 "PASSED" "***FAILED";
set argv[$lif] $+ $argv[$lif] 1;
echo both " " $rowcnt " rows logged to be updated in instead of update trigger \n";

select * from XX_upd_log where dt = 'au';
echo both $if $equ $rowcnt 1 "PASSED" "***FAILED";
set argv[$lif] $+ $argv[$lif] 1;
echo both " " $rowcnt " rows logged to be updated in after update trigger \n";

delete from XX;
delete from XX_upd_log;

create index bidx on XX (b);

insert into XX (a) values (1);
insert into XX (a) values (2);
insert into XX (a) values (3);

select * from XX;
echo both $if $equ $rowcnt 3 "PASSED" "***FAILED";
set argv[$lif] $+ $argv[$lif] 1;
echo both " " $rowcnt " rows after insert \n";

create trigger XX_U_A after update on XX referencing old as O, new as N {
  dbg_obj_print ('after update - recreated' , O.a, N.a, N.b);
  insert into XX_upd_log (oa,ob,na,nb,dt) values (O.a, O.b, N.a, N.b, 'au');
};

create procedure update_in_loop ()
{
  for (declare i int, i := 0; i < 1000; i := i + 1)
    {
      update XX table option (index bidx) set a = a + 1, b = rnd (100) where b >= 0;
    }
};

ECHO BOTH "starting update keyset in a loop with function call before cursor \n";
update_in_loop ();
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": update keyset in a loop with function call before cursor : STATE=" $STATE " MESSAGE=" $MESSAGE "\n";


ECHO BOTH "COMPLETED WITH " $ARGV[0] " FAILED, " $ARGV[1] " PASSED: keyset update tests\n";
