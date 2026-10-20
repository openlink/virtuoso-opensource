--
--  tlongany_reopen.sql   (phase 2)
--
--  Run after the unclean stop and restart.  Two independent questions, both
--  asked, because passing one and failing the other is the normal state of
--  affairs here:
--
--    1. did roll forward reproduce the rows byte for byte (LA vs LA_EXPECT)?
--       log_insert () logs the row image, and the async batched replayer feeds
--       those images back through an ordinary vectored INSERT, so the insert
--       cast has to be idempotent on its own output;
--    2. is what came back actually correct, or is it faithfully reproduced
--       garbage?
--
--  Stock code passes 1 and fails 2.  A fix that anifies a string on the way in
--  without telling replay the parameters are already images does the reverse.
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS) project.
--  Copyright (C) 1998-2026 OpenLink Software
--  GNU GPL v2, 1991.  See tvvec_rebuild_durable.sql for the full header.
--

echo BOTH "STARTED: LONG ANY roll forward (phase 2)\n";

--------------------------------------------------------------------------------
-- 1. Roll forward fidelity
--------------------------------------------------------------------------------
-- Against the snapshot, not a literal, so the two phases cannot drift apart.
-- The joins below cannot see a row roll forward dropped altogether; this can.
select (select count (*) from DB.DBA.LA) - (select count (*) from DB.DBA.LA_EXPECT);
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": rows lost or gained across roll forward=" $LAST[1] " (expect 0)\n";

select count (*) from DB.DBA.LA;
ECHO BOTH $IF $EQU $LAST[1] 16 "PASSED" "***FAILED";
ECHO BOTH ": row count after roll forward=" $LAST[1] " (expect 16)\n";

select count (*) from DB.DBA.LA where id = 35;
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": post-checkpoint delete survived, id 35 rows=" $LAST[1] " (expect 0)\n";

select count (*) from DB.DBA.LA a, DB.DBA.LA_EXPECT e
  where a.id = e.id and __tag (a.v) <> e.tag;
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": rows whose __tag changed across roll forward=" $LAST[1] " (expect 0)\n";

select count (*) from DB.DBA.LA a, DB.DBA.LA_EXPECT e
  where a.id = e.id and md5 (serialize (a.v)) <> e.digest;
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": rows whose value changed across roll forward=" $LAST[1] " (expect 0)\n";

-- Names the offenders when the two counts above are not 0.
select a.id, e.tag as tag_before, __tag (a.v) as tag_after, e.digest as digest_before,
       md5 (serialize (a.v)) as digest_after
  from DB.DBA.LA a, DB.DBA.LA_EXPECT e
 where a.id = e.id and (__tag (a.v) <> e.tag or md5 (serialize (a.v)) <> e.digest)
 order by a.id;

--------------------------------------------------------------------------------
-- 2. The replayed rows are also correct, not just unchanged
--------------------------------------------------------------------------------
select __tag (v) from DB.DBA.LA where id = 31;
ECHO BOTH $IF $EQU $LAST[1] 182 "PASSED" "***FAILED";
ECHO BOTH ": replayed insert string   __tag=" $LAST[1] " (expect 182)\n";
select case when serialize (v) = serialize ('post ckp string') then 1 else 0 end from DB.DBA.LA where id = 31;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": replayed insert string   value round trip=" $LAST[1] "\n";

select __tag (v) from DB.DBA.LA where id = 32;
ECHO BOTH $IF $EQU $LAST[1] 202 "PASSED" "***FAILED";
ECHO BOTH ": replayed insert fvector  __tag=" $LAST[1] " (expect 202)\n";
select case when serialize (v) = serialize (fvector (7.5, 8.5, 9.5)) then 1 else 0 end from DB.DBA.LA where id = 32;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": replayed insert fvector  value round trip=" $LAST[1] "\n";

select __tag (v) from DB.DBA.LA where id = 33;
ECHO BOTH $IF $EQU $LAST[1] 193 "PASSED" "***FAILED";
ECHO BOTH ": replayed insert vector   __tag=" $LAST[1] " (expect 193)\n";
select case when serialize (v) = serialize (vector (3, 'c', 4.5)) then 1 else 0 end from DB.DBA.LA where id = 33;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": replayed insert vector   value round trip=" $LAST[1] "\n";

select __tag (v) from DB.DBA.LA where id = 34;
ECHO BOTH $IF $EQU $LAST[1] 189 "PASSED" "***FAILED";
ECHO BOTH ": replayed insert integer  __tag=" $LAST[1] " (expect 189)\n";
select case when serialize (v) = serialize (55555) then 1 else 0 end from DB.DBA.LA where id = 34;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": replayed insert integer  value round trip=" $LAST[1] "\n";

select __tag (v) from DB.DBA.LA where id = 41;
ECHO BOTH $IF $EQU $LAST[1] 182 "PASSED" "***FAILED";
ECHO BOTH ": replayed update string   __tag=" $LAST[1] " (expect 182)\n";
select case when serialize (v) = serialize ('post ckp updated') then 1 else 0 end from DB.DBA.LA where id = 41;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": replayed update string   value round trip=" $LAST[1] "\n";

select __tag (v) from DB.DBA.LA where id = 42;
ECHO BOTH $IF $EQU $LAST[1] 202 "PASSED" "***FAILED";
ECHO BOTH ": replayed update fvector  __tag=" $LAST[1] " (expect 202)\n";
select case when serialize (v) = serialize (fvector (0.5, 1.5, 2.5)) then 1 else 0 end from DB.DBA.LA where id = 42;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": replayed update fvector  value round trip=" $LAST[1] "\n";

select __tag (v) from DB.DBA.LA where id = 43;
ECHO BOTH $IF $EQU $LAST[1] 193 "PASSED" "***FAILED";
ECHO BOTH ": replayed update vector   __tag=" $LAST[1] " (expect 193)\n";
select case when serialize (v) = serialize (vector (4, 'd', 5.5)) then 1 else 0 end from DB.DBA.LA where id = 43;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": replayed update vector   value round trip=" $LAST[1] "\n";

select __tag (v) from DB.DBA.LA where id = 44;
ECHO BOTH $IF $EQU $LAST[1] 189 "PASSED" "***FAILED";
ECHO BOTH ": replayed update integer  __tag=" $LAST[1] " (expect 189)\n";
select case when serialize (v) = serialize (99999) then 1 else 0 end from DB.DBA.LA where id = 44;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": replayed update integer  value round trip=" $LAST[1] "\n";

-- The checkpointed rows, for contrast: these never went through replay.
select case when serialize (v) = serialize ('plain string') then 1 else 0 end from DB.DBA.LA where id = 1;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": checkpointed insert string  value round trip=" $LAST[1] "\n";
select case when serialize (v) = serialize (fvector (4.5, 5.5, 6.5)) then 1 else 0 end from DB.DBA.LA where id = 22;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
ECHO BOTH ": checkpointed update fvector value round trip=" $LAST[1] "\n";

select id, __tag (v), md5 (serialize (v)) from DB.DBA.LA order by id;

echo BOTH "COMPLETED: LONG ANY phase 2\n";
