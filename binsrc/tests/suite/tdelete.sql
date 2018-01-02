--
--  tdelete.sql
--
--  $Id: tdelete.sql,v 1.4.6.3.4.4 2013/01/02 16:15:04 source Exp $
--
--  Test delete functions
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

echo BOTH "STARTED: DELETE TEST\n";

CONNECT;

-- Timeout to one hour.
SET TIMEOUT 3600;

-- words has 3 keys, words_1 1 key and words_2 2 keys.
drop table words_1;
drop table words_2;

create table words_1 (word varchar, len integer, primary key (word))
 alter index words_1 on words_1 partition (word varchar);
create table words_2 (word varchar, len integer, revword varchar, primary key (word))
 alter index words_2 on words_2 partition (word varchar);
create index w2_revword on words_2 (revword) partition (revword varchar);
ECHO BOTH $IF $EQU $STATE "OK" "PASSED" "***FAILED";
ECHO BOTH ": create index w2_revword on words_2 (revword); STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

insert into words_1 (word, len) select word, len from words;
ECHO BOTH $IF $EQU $STATE "OK" "PASSED" "***FAILED";
ECHO BOTH ": insert into words_1; STATE=" $STATE " MESSAGE=" $MESSAGE "\n";
ECHO BOTH $IF $EQU $ROWCNT 86061 "PASSED" "***FAILED";
ECHO BOTH ": " $ROWCNT " rows inserted\n";

insert into words_2 (word, len, revword) select word, len, revword from words;
ECHO BOTH $IF $EQU $STATE "OK" "PASSED" "***FAILED";
ECHO BOTH ": insert into words_2; STATE=" $STATE " MESSAGE=" $MESSAGE "\n";
ECHO BOTH $IF $EQU $ROWCNT 86061 "PASSED" "***FAILED";
ECHO BOTH ": " $ROWCNT " rows inserted\n";

checkpoint;

delete from words where word like '%dad';
ECHO BOTH $IF $EQU $STATE "OK" "PASSED" "***FAILED";
ECHO BOTH ": delete from words where word like '%dad'; STATE=" $STATE " MESSAGE=" $MESSAGE "\n";
ECHO BOTH $IF $EQU $ROWCNT 956 "PASSED" "***FAILED";
ECHO BOTH ": " $ROWCNT " rows deleted\n";

delete from words_1 where "RIGHT"(word,3) = 'dad';
ECHO BOTH $IF $EQU $STATE "OK" "PASSED" "***FAILED";
ECHO BOTH ": delete from words_1 where "RIGHT"(word,3) = 'dad'; STATE=" $STATE " MESSAGE=" $MESSAGE "\n";
ECHO BOTH $IF $EQU $ROWCNT 956 "PASSED" "***FAILED";
ECHO BOTH ": " $ROWCNT " rows deleted\n";

delete from words_2 where revword between 'dad' and 'dae';
ECHO BOTH $IF $EQU $STATE "OK" "PASSED" "***FAILED";
ECHO BOTH ": delete from words_2 where revword between 'dad' and 'dae'; STATE=" $STATE " MESSAGE=" $MESSAGE "\n";
ECHO BOTH $IF $EQU $ROWCNT 956 "PASSED" "***FAILED";
ECHO BOTH ": " $ROWCNT " rows deleted\n";

select count(*) from words where revword > ' ';
ECHO BOTH $IF $EQU $STATE "OK" "PASSED" "***FAILED";
ECHO BOTH ": select count(*) from words; STATE=" $STATE " MESSAGE=" $MESSAGE "\n";
ECHO BOTH $IF $EQU $LAST[1] 85105 "PASSED" "***FAILED";
ECHO BOTH ": " $LAST[1] " rows in words after delete\n";

select count (*) from words where word > ' ';
ECHO BOTH $IF $EQU $STATE "OK" "PASSED" "***FAILED";
ECHO BOTH ": select count(*) from words; STATE=" $STATE " MESSAGE=" $MESSAGE "\n";
ECHO BOTH $IF $EQU $LAST[1] 85105 "PASSED" "***FAILED";
ECHO BOTH ": " $LAST[1] " rows in words after delete\n";

select count (*) from words where len > 0;
ECHO BOTH $IF $EQU $STATE "OK" "PASSED" "***FAILED";
ECHO BOTH ": select count(*) from words; STATE=" $STATE " MESSAGE=" $MESSAGE "\n";
ECHO BOTH $IF $EQU $LAST[1] 85105 "PASSED" "***FAILED";
ECHO BOTH ": " $LAST[1] " rows in words after delete\n";

delete from words_1 where word like '%dad';
ECHO BOTH $IF $EQU $STATE "OK" "PASSED" "***FAILED";
ECHO BOTH ": delete from words_1 where word like '%dad'; STATE=" $STATE " MESSAGE=" $MESSAGE "\n";
ECHO BOTH $IF $EQU $ROWCNT 0 "PASSED: " "***FAILED: ";
ECHO BOTH $ROWCNT " rows deleted\n";

select count (*) from words_1;
ECHO BOTH $IF $EQU $LAST[1] 85105 "PASSED" "***FAILED";
ECHO BOTH ": " $LAST[1] " rows in words_1 after delete\n";

delete from words where revword between 'ra' and 'rb';
ECHO BOTH $IF $EQU $STATE "OK" "PASSED" "***FAILED";
ECHO BOTH ": delete from words where revword between 'ra' and 'rb'; STATE=" $STATE " MESSAGE=" $MESSAGE "\n";
ECHO BOTH $IF $EQU $ROWCNT 8636 "PASSED: " "***FAILED: ";
ECHO BOTH $ROWCNT " rows deleted\n";

select count (*) from words where word > ' ';
ECHO BOTH $IF $EQU $STATE "OK" "PASSED" "***FAILED";
ECHO BOTH ": select count (*) from words; STATE=" $STATE " MESSAGE=" $MESSAGE "\n";
ECHO BOTH $IF $EQU $LAST[1] 76469 "PASSED" "***FAILED";
ECHO BOTH ": " $LAST[1] " rows in words after delete\n";

select count (*) from words where len > 0;
ECHO BOTH $IF $EQU $STATE "OK" "PASSED" "***FAILED";
ECHO BOTH ": select count (*) from words; STATE=" $STATE " MESSAGE=" $MESSAGE "\n";
ECHO BOTH $IF $EQU $LAST[1] 76469 "PASSED" "***FAILED";
ECHO BOTH ": " $LAST[1] " rows in words after delete\n";

delete from words_2 where revword between 'ra' and 'rb';
ECHO BOTH $IF $EQU $STATE "OK" "PASSED" "***FAILED";
ECHO BOTH ": delete from words_2 where revword between 'ra' and 'rb'; STATE=" $STATE " MESSAGE=" $MESSAGE "\n";
ECHO BOTH $IF $EQU $ROWCNT 8636 "PASSED: " "***FAILED: ";
ECHO BOTH $ROWCNT " rows deleted\n";

select count (*) from words where word > ' ';
ECHO BOTH $IF $EQU $STATE "OK" "PASSED" "***FAILED";
ECHO BOTH ": select count (*) from words; STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select count (*) from words where len > 0;
ECHO BOTH $IF $EQU $STATE "OK" "PASSED" "***FAILED";
ECHO BOTH ": select count (*) from words; STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select count (*) from words_2 where len > 0;
ECHO BOTH $IF $EQU $STATE "OK" "PASSED" "***FAILED";
ECHO BOTH ": select count (*) from words_2; STATE=" $STATE " MESSAGE=" $MESSAGE "\n";
ECHO BOTH $IF $EQU $LAST[1] 76469 "PASSED" "***FAILED";
ECHO BOTH ": " $LAST[1] " rows_1 in words_2 after delete\n";

select count (*) from words_2 where revword > ' ';
ECHO BOTH $IF $EQU $STATE "OK" "PASSED" "***FAILED";
ECHO BOTH ": select count (*) from words_2; STATE=" $STATE " MESSAGE=" $MESSAGE "\n";
ECHO BOTH $IF $EQU $LAST[1] 76469 "PASSED" "***FAILED";
ECHO BOTH ": " $LAST[1] " rows_1 in words_2 after delete\n";

--delete from words table option (index primary key) where len > 7 option (index len);
--echo both $if $equ $state 42000 "PASSED" "***FAILED";
--echo both ": error with different inx for single key del and the search\n";


create procedure fidn (in q int) { id_to_iri (#i1); return q;}


select sys_stat ('cluster_enable');

#if $equ $last[1] 1

set autocommit manual;

delete from words table option (index len, no cluster) where len > 7 option (index len);
echo both $if $equ $sqlstate OK "PASSED" "***FAILED";
echo both ": del single key\n";


delete from words table option (index len, no cluster) where len > 5 and fidn (len) = 6  option (index len);

select (select count (*) from words table option (index primary key)) - (select count (*) from words table option (index len));
echo both $if $neq $last[1] 0 "PASSED" "***FAILED";
echo both ": count after single key del\n";


select count (*) from words table option (index primary key);
echo both $if $equ $last[1] 76469 "PASSED" "***FAILED";
echo both ": pk count after single key del\n";

rollback work;
set autocommit off;
#endif

echo BOTH "COMPLETED: DELETE TEST\n";
