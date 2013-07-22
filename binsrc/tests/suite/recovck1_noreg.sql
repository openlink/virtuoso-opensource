--
--  recovck1_noreg.sql
--
--  $Id$
--
--  Recovery check test
--  
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--  
--  Copyright (C) 1998-2013 OpenLink Software
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

select count(*) from iutest;

--ECHO BOTH $IF $EQU $LAST[1] 30003 "PASSED" "***FAILED";
--ECHO BOTH ": " $LAST[1] " rows in iutest after roll forward.\n";

-- XXX: VJ
--select sum (length (B1)), sum (length (B2)), sum (length (B3)) from BLOBS;

--ECHO BOTH $IF $EQU $LAST[1] 500010 "PASSED" "***FAILED";
--ECHO BOTH ": BLOBS  sum(length (B1))= " $LAST[1] " \n";

--ECHO BOTH $IF $EQU $LAST[2] 250010 "PASSED" "***FAILED";
--ECHO BOTH ": BLOBS  sum(length (B2))= " $LAST[2] " \n";

--ECHO BOTH $IF $EQU $LAST[3] 500020 "PASSED" "***FAILED";
--ECHO BOTH ": BLOBS  sum(length (B3))= " $LAST[3] " \n";

ECHO BOTH "recovck1_noreg check trees\n";

cl_exec ('backup ''/dev/null''');

select count (*) from T2;

ECHO BOTH $IF $EQU $LAST[1] 13 "PASSED" "***FAILED";
ECHO BOTH ": " $LAST[1] " rows in T2 after roll forward.\n";

--XXX: VJ
--reconnect USR1;
--ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
--ECHO BOTH ": there is user USR1\n";

select * from USR_TABLE;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": user USR1 able of reading USR_TABLE\n";

update USR_TABLE set COL1 = COL1, COL2 = COL2;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": user USR1 able of updating USR_TABLE\n";

--XXX: VJ
--reconnect USR2;
--ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
--ECHO BOTH ": there is user USR2 with a changed password\n";

select * from USR_TABLE;
-- XXX: VJ
--ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
--ECHO BOTH ": user USR2 not able of reading USR_TABLE STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select COL1 from USR_TABLE;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": user USR2 able of reading COL1 from USR_TABLE\n";

update USR_TABLE set COL1 = COL1, COL2 = COL2;
-- XXX: VJ
--ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
--ECHO BOTH ": user USR2 not able of updating USR_TABLE STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

update USR_TABLE set COL1 = COL1;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": user USR2 able of updating COL1 in USR_TABLE\n";

reconnect dba;

create procedure tb_check (in q integer)
{
  if (exists (select 1 from tblob b where not exists (select 1 from tb_stat c where c.k = b.k
						      and length (b1) = b1_l and length (b2) = b2_l and length (b3) = b3_l
						      and length (b4) = b4_l and b. e1 = c. e1 and b. e2 = c. e2)))
    signal ('BLFWD', 'Bad blob roll forward');
}
select count (*) from tb_stat;
select count (*) from tblob;
--XXX: VJ
select count (*) from tblob b, tb_stat c where c.k = b.k
  and length (b1) = b1_l and length (b2) = b2_l and length (b3) = b3_l
  and length (b4) = b4_l and b. e1 = c. e1 and b. e2 = c. e2 option (hash);


-- below will cause blobs in hah temp to be forced outlined cause of keng expr for key

select count (*), sum (length (b.b1)) from tb_stat c, tblob b where c.k = b.k
   and length (b1) = b1_l and length (b2) = b2_l and length (b3) = b3_l
  and length (b4) = b4_l and b. e1 || b.e1 = c.e1 || c.e1 and b. e2 = c. e2 option (hash, order);


--XXX: VJ
select k, length (b1), length (b2), length (b3), length (b4), * from tblob b where not exists (select 1 from tb_stat c where c.k = b.k                                                       and length (b1) = b1_l and length (b2) = b2_l and length (b3) = b3_l                                                       and length (b4) = b4_l and b. e1 = c. e1 and b. e2 = c. e2);

tb_check (1);
--ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
--ECHO BOTH ": blobs rollback / roll forward consistency " $STATE "\n";

select * from tblob where length (blob_to_string (b4)) <> length (b4);
ECHO BOTH $IF $EQU $ROWCNT 0 "PASSED" "***FAILED";
ECHO BOTH ": tblob length check 2\n";

insert into B2437 values (1);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": BUG2437: reading _IDN sequence values correctly from the log\n";


select count(*) from ROW_TEST;
ECHO BOTH $IF $EQU $LAST[1] 9 "PASSED" "***FAILED";
ECHO BOTH ": ROW_TEST count(*) = " $LAST[1] " \n";

select count (*) from B5258;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": B5258 select check returned " $LAST[1] " rows\n";


-- GPF: Dkpool.c:388 not supposed to make a tmp pool copy of this copiable dtp
--select T.DATA.PLUS1() from TEST_UDT_DUMP T;
--ECHO BOTH $IF $EQU $LAST[1] 13 "PASSED" "***FAILED";
--ECHO BOTH ": restore of serialized UDT returned " $LAST[1] "\n";

select CS_NAME from DB.DBA.SYS_CHARSETS;
select count (*) from DB.DBA.SYS_CHARSETS where CS_NAME = 'PLOVDIVSKI';
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": " $LAST[1] " user defined charsets\n";

select COLL_NAME from DB.DBA.SYS_COLLATIONS;
select count (*) from DB.DBA.SYS_COLLATIONS where COLL_NAME = 'DB.DBA.PLOVDIVSKI';
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": " $LAST[1] " user defined collations\n";

statistics INX_LARGE_TB;
ECHO BOTH $IF $EQU $ROWCNT 2 "PASSED" "***FAILED";
ECHO BOTH ": " $LAST[1] " INX_LARGE_TB has index\n";
ECHO BOTH $IF $EQU $LAST[6] INX_LARGE "PASSED" "***FAILED";
ECHO BOTH ": " $LAST[1] " INX_LARGE_TB has index INX_LARGE\n";

statistics INX_SMALL_TB;
ECHO BOTH $IF $EQU $ROWCNT 2 "PASSED" "***FAILED";
ECHO BOTH ": " $LAST[1] " INX_SMALL_TB has index\n";
ECHO BOTH $IF $EQU $LAST[6] INX_SMALL "PASSED" "***FAILED";
ECHO BOTH ": " $LAST[1] " INX_SMALL_TB has index INX_SMALL\n";

statistics INX_LARGE_TB2;
-- XXX: VJ
--ECHO BOTH $IF $EQU $ROWCNT 2 "PASSED" "***FAILED";
--ECHO BOTH ": " $LAST[1] " INX_LARGE_TB2 has index\n";
--ECHO BOTH $IF $EQU $LAST[6] INX2_LARGE_2 "PASSED" "***FAILED";
--ECHO BOTH ": " $LAST[1] " INX_LARGE_TB2 has index INX2_LARGE_2\n";

statistics INX_SMALL_TB2;
ECHO BOTH $IF $EQU $ROWCNT 2 "PASSED" "***FAILED";
ECHO BOTH ": " $LAST[1] " INX_SMALL_TB2 has index\n";
ECHO BOTH $IF $EQU $LAST[6] INX2_SMALL_2 "PASSED" "***FAILED";
ECHO BOTH ": " $LAST[1] " INX_SMALL_TB2 has index INX2_SMALL_2\n";


foreignkeys FK_OK1;
ECHO BOTH $IF $EQU $LAST[3] FK_OK1 "PASSED" "***FAILED";
ECHO BOTH ": FKRFWD1 " $LAST[3] " FK defined\n";

foreignkeys AFK_OK1;
ECHO BOTH $IF $EQU $LAST[3] AFK_OK1 "PASSED" "***FAILED";
ECHO BOTH ": FKRFWD2 " $LAST[3] " FK defined\n";

foreignkeys AFK_BAD1;
ECHO BOTH $IF $EQU $ROWCNT 0 "PASSED" "***FAILED";
ECHO BOTH ":  FKRFWD3 AFK_BAD1 no FK STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

delete from FK_OK2 where ID = 100;
insert into FK_OK2 values (100, 100);
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": FKRFWD4 FK_OK2 stoped STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

delete from AFK_OK2 where ID = 100;
insert into AFK_OK2 values (100, 100);
ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": FKRFWD5 AFK_OK2 stoped STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

delete from AFK_BAD2 where ID = 100;
insert into AFK_BAD2 values (100, 100);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": FKRFWD6 FK_BAD2 allowed STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

-- rename

tables REN_TB1_TO;
ECHO BOTH $IF $NEQ $ROWCNT 1 "***FAILED" $IF $EQU $LAST[3] REN_TB1_TO "PASSED" "***FAILED";
ECHO BOTH ": REN_TB1_TO present.\n";

select * from REN_TB1_TO;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": REN_TB1_TO selectable.\n";

tables REN_TB1_FROM;
ECHO BOTH $IF $EQU $ROWCNT 0 "PASSED" "***FAILED";
ECHO BOTH ": REN_TB1_FROM not present.\n";

--select * from REN_TB1_FROM;
--ECHO BOTH $IF $NEQ $STATE OK "PASSED" "***FAILED";
--ECHO BOTH ": REN_TB1_FROM not selectable.\n";

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

select * from B6978_2;
ECHO BOTH $IF $EQU $COLCNT 2 "PASSED" "***FAILED";
ECHO BOTH ": B6978-7 table copied has all cols. COLCNT=" $COLCNT "\n";
ECHO BOTH $IF $EQU $ROWCNT 0 "PASSED" "***FAILED";
ECHO BOTH ": B6978-8 table copied does not have data. ROWCNT=" $ROWCNT "\n";

select * from B6978_3;
ECHO BOTH $IF $EQU $COLCNT 2 "PASSED" "***FAILED";
ECHO BOTH ": B6978-9 table with data copied has all cols. COLCNT=" $COLCNT "\n";
ECHO BOTH $IF $EQU $ROWCNT 1 "PASSED" "***FAILED";
ECHO BOTH ": B6978-10 table with data copied does have data. ROWCNT=" $ROWCNT "\n";

select length (b) from rep_blob;
ECHO BOTH $IF $EQU $LAST[1] 20000000 "PASSED"  "***FAILED";
ECHO BOTH ": replicated ins replacing of large blob\n";
