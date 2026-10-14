--
--  tlongany.sql   (phase 1)
--
--  LONG ANY is DV_BLOB + the DB.DBA.__ANY class (sql3.y), and its reader always
--  goes through udt_deserialize_from_blob, so the stored bytes must carry
--  exactly one serialization layer.  This phase writes one of every value shape
--  through both INSERT and UPDATE and checks each one, then arms a roll forward.
--
--  Every value check is "does serialize() of what came back equal serialize()
--  of the literal that went in" -- exact, and the same assertion form works for
--  a string, an fvector, a vector and an integer.  __tag is checked separately
--  so a failure says whether the value was mangled or merely stored under the
--  wrong type:
--
--    DV_STRING           182
--    DV_LONG_INT         189
--    DV_ARRAY_OF_POINTER 193
--    DV_ARRAY_OF_FLOAT   202
--
--  Everything after the checkpoint exists only in the transaction log, so phase
--  2 can only see it if roll forward brings it back.  The expectations are
--  snapshotted into plain INTEGER/VARCHAR columns, which the LONG ANY write
--  path cannot itself corrupt.
--
--  Run via the two-phase driver tlongany.sh: this file, then an unclean stop
--  (raw_exit), restart, then tlongany_reopen.sql.
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS) project.
--  Copyright (C) 1998-2026 OpenLink Software
--  GNU GPL v2, 1991.  See tvvec_rebuild_durable.sql for the full header.
--

echo BOTH "STARTED: LONG ANY insert/update (phase 1)\n";

-- RUN_TEST gives this test its own directory and a fresh database, so there is
-- nothing to drop first -- and a failing DROP would fail the whole script.
create table DB.DBA.LA (id int primary key, v long any);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": create DB.DBA.LA (v long any) STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

--------------------------------------------------------------------------------
-- INSERT
--------------------------------------------------------------------------------
insert into DB.DBA.LA (id, v) values (1, 'plain string');
insert into DB.DBA.LA (id, v) values (2, fvector (1.5, 2.5, 3.5));
insert into DB.DBA.LA (id, v) values (3, vector (1, 'a', 2.5));
insert into DB.DBA.LA (id, v) values (4, 12345);
commit work;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": insert 4 rows STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select __tag (v) from DB.DBA.LA where id = 1;
ECHO BOTH $IF $EQU $LAST[1] 182 "PASSED" "***FAILED";
ECHO BOTH ": insert string     __tag=" $LAST[1] " (expect 182)\n";
select case when serialize (v) = serialize ('plain string') then 1 else 0 end from DB.DBA.LA where id = 1;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": insert string     value round trip=" $LAST[1] "\n";

select __tag (v) from DB.DBA.LA where id = 2;
ECHO BOTH $IF $EQU $LAST[1] 202 "PASSED" "***FAILED";
ECHO BOTH ": insert fvector    __tag=" $LAST[1] " (expect 202)\n";
select case when serialize (v) = serialize (fvector (1.5, 2.5, 3.5)) then 1 else 0 end from DB.DBA.LA where id = 2;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": insert fvector    value round trip=" $LAST[1] "\n";

select __tag (v) from DB.DBA.LA where id = 3;
ECHO BOTH $IF $EQU $LAST[1] 193 "PASSED" "***FAILED";
ECHO BOTH ": insert vector     __tag=" $LAST[1] " (expect 193)\n";
select case when serialize (v) = serialize (vector (1, 'a', 2.5)) then 1 else 0 end from DB.DBA.LA where id = 3;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": insert vector     value round trip=" $LAST[1] "\n";

select __tag (v) from DB.DBA.LA where id = 4;
ECHO BOTH $IF $EQU $LAST[1] 189 "PASSED" "***FAILED";
ECHO BOTH ": insert integer    __tag=" $LAST[1] " (expect 189)\n";
select case when serialize (v) = serialize (12345) then 1 else 0 end from DB.DBA.LA where id = 4;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": insert integer    value round trip=" $LAST[1] "\n";

--------------------------------------------------------------------------------
-- UPDATE.  Fresh rows, so the INSERT rows above stay as evidence.
--------------------------------------------------------------------------------
insert into DB.DBA.LA (id, v) values (21, 'before');
insert into DB.DBA.LA (id, v) values (22, 'before');
insert into DB.DBA.LA (id, v) values (23, 'before');
insert into DB.DBA.LA (id, v) values (24, 'before');
commit work;

update DB.DBA.LA set v = 'after string'            where id = 21;
update DB.DBA.LA set v = fvector (4.5, 5.5, 6.5)   where id = 22;
update DB.DBA.LA set v = vector (2, 'b', 3.5)      where id = 23;
update DB.DBA.LA set v = 67890                     where id = 24;
commit work;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": update 4 rows STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select __tag (v) from DB.DBA.LA where id = 21;
ECHO BOTH $IF $EQU $LAST[1] 182 "PASSED" "***FAILED";
ECHO BOTH ": update string     __tag=" $LAST[1] " (expect 182)\n";
select case when serialize (v) = serialize ('after string') then 1 else 0 end from DB.DBA.LA where id = 21;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": update string     value round trip=" $LAST[1] "\n";

select __tag (v) from DB.DBA.LA where id = 22;
ECHO BOTH $IF $EQU $LAST[1] 202 "PASSED" "***FAILED";
ECHO BOTH ": update fvector    __tag=" $LAST[1] " (expect 202)\n";
select case when serialize (v) = serialize (fvector (4.5, 5.5, 6.5)) then 1 else 0 end from DB.DBA.LA where id = 22;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": update fvector    value round trip=" $LAST[1] "\n";

select __tag (v) from DB.DBA.LA where id = 23;
ECHO BOTH $IF $EQU $LAST[1] 193 "PASSED" "***FAILED";
ECHO BOTH ": update vector     __tag=" $LAST[1] " (expect 193)\n";
select case when serialize (v) = serialize (vector (2, 'b', 3.5)) then 1 else 0 end from DB.DBA.LA where id = 23;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": update vector     value round trip=" $LAST[1] "\n";

select __tag (v) from DB.DBA.LA where id = 24;
ECHO BOTH $IF $EQU $LAST[1] 189 "PASSED" "***FAILED";
ECHO BOTH ": update integer    __tag=" $LAST[1] " (expect 189)\n";
select case when serialize (v) = serialize (67890) then 1 else 0 end from DB.DBA.LA where id = 24;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": update integer    value round trip=" $LAST[1] "\n";

--------------------------------------------------------------------------------
-- Arm the replay.  Everything below the checkpoint lives only in the log, so
-- roll forward is the only thing that can bring it back.
--------------------------------------------------------------------------------
checkpoint;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": checkpoint (rows above are durable) STATE=" $STATE "\n";

insert into DB.DBA.LA (id, v) values (31, 'post ckp string');
insert into DB.DBA.LA (id, v) values (32, fvector (7.5, 8.5, 9.5));
insert into DB.DBA.LA (id, v) values (33, vector (3, 'c', 4.5));
insert into DB.DBA.LA (id, v) values (34, 55555);
insert into DB.DBA.LA (id, v) values (35, 'to be deleted');
insert into DB.DBA.LA (id, v) values (41, 'before');
insert into DB.DBA.LA (id, v) values (42, 'before');
insert into DB.DBA.LA (id, v) values (43, 'before');
insert into DB.DBA.LA (id, v) values (44, 'before');

update DB.DBA.LA set v = 'post ckp updated'         where id = 41;
update DB.DBA.LA set v = fvector (0.5, 1.5, 2.5)    where id = 42;
update DB.DBA.LA set v = vector (4, 'd', 5.5)       where id = 43;
update DB.DBA.LA set v = 99999                      where id = 44;
delete from DB.DBA.LA where id = 35;
commit work;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": post-checkpoint insert/update/delete STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

-- Snapshot what every row looks like now, in plain INTEGER/VARCHAR columns that
-- the LONG ANY bug cannot itself corrupt.  Phase 2 compares against this.
create table DB.DBA.LA_EXPECT (id int primary key, tag int, digest varchar);
insert into DB.DBA.LA_EXPECT (id, tag, digest)
  select id, __tag (v), md5 (serialize (v)) from DB.DBA.LA;
commit work;
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": snapshot expectations STATE=" $STATE "\n";

-- 17 inserted (1-4, 21-24, 31-35, 41-44), 1 deleted (35).
select count (*) from DB.DBA.LA;
ECHO BOTH $IF $EQU $LAST[1] 16 "PASSED" "***FAILED";
ECHO BOTH ": row count before crash=" $LAST[1] " (expect 16)\n";

select id, __tag (v), md5 (serialize (v)) from DB.DBA.LA order by id;

echo BOTH "COMPLETED: LONG ANY phase 1\n";
