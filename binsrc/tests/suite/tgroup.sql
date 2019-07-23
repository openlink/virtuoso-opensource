--
--  tgroup.sql
--
--  $Id: tgroup.sql,v 1.13.6.2.4.3 2013/01/02 16:15:10 source Exp $
--
--  Group By test
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

echo both "Group By test\n";

select count (word), LEFT (word, 2) from words group by 2 order by count (word);
ECHO BOTH $IF $EQU $ROWCNT 379 "PASSED" "***FAILED";
ECHO BOTH ": " $ROWCNT " distinct word beginning letter pairs\n";
ECHO BOTH $IF $EQU $LAST[1] 4197 "PASSED" "***FAILED";
ECHO BOTH ": most common start " $LAST[2] " " $LAST[1] " occurrences\n";

select  LEFT (word, 2), count (word), avg (length (word)), min (word), max (word) from words group by 1 having count (word) > 1000 order by count (word);
ECHO BOTH $IF $EQU $ROWCNT 21 "PASSED" "***FAILED";
ECHO BOTH ": " $ROWCNT " distinct word beginning over 1000\n";

select  LEFT (word, 2), count (word) as cnt, avg (length (word)), min (word), max (word) from words group by 1 having cnt > 1000 order by cnt;
ECHO BOTH $IF $EQU $ROWCNT 21 "PASSED" "***FAILED";
ECHO BOTH ": " $ROWCNT " distinct word beginning over 1000\n";

select count (*) from (select ROW_NO as R from T1) A, (select distinct ROW_NO from T1) B where B.ROW_NO between R-2 and R+2;
ECHO BOTH $IF $EQU $LAST[1] 94 "PASSED" "***FAILED";
ECHO BOTH ": " $ROWCNT " rows from x join distinct\n";

select STRING1, avg (ROW_NO) from T1 group by STRING1 having avg (ROW_NO) > (select avg (ROW_NO) from T1);
ECHO BOTH $IF $EQU $ROWCNT 10 "PASSED" "***FAILED";
ECHO BOTH ": " $ROWCNT " rows above average in T1\n";



select sum (ROW_NO), upper (STRING1) as str from T1 group by 2 order by cast (str as integer);
ECHO BOTH $IF $EQU $ROWCNT 20 "PASSED" "***FAILED";
ECHO BOTH ": " $ROWCNT " rows T1, gb ob exp\n";

select top 500 word from words order by 1 desc;
echo both $if $equ $last[1] "zoot�cnico" "PASSED" "*** FAILED";
echo both ": 500th from end is " $last[1] "\n";

select top 500 concat (word) from words order by 1 desc;
echo both $if $equ $last[1] "zoot�cnico" "PASSED" "*** FAILED";
echo both ": 500th from end sorted is " $last[1] "\n";

select top (100 + 400) word from words order by 1 desc;
echo both $if $equ $last[1] "zoot�cnico" "PASSED" "*** FAILED";
echo both ": plus exp top 500 is " $last[1] "\n";

select top ('500') word from words order by 1 desc;
echo both $if $equ $last[1] "zoot�cnico" "PASSED" "*** FAILED";
echo both ": cast exp end 500 is " $last[1] "\n";

select top ('500') concat (word) from words order by 1 desc;
echo both $if $equ $last[1] "zoot�cnico" "PASSED" "*** FAILED";
echo both ": cast sorted exp end 500 is " $last[1] "\n";

select top -1 word from words;
echo both $if $NEQ $STATE OK "PASSED" "*** FAILED";
echo both ": negative top yelds STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select top -1,1 word from words;
echo both $if $NEQ $STATE OK "PASSED" "*** FAILED";
echo both ": negative skip part yelds STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select top 1,-2 word from words;
echo both $if $NEQ $STATE OK "PASSED" "*** FAILED";
echo both ": negative top part yelds STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select top (-2) word from words;
echo both $if $NEQ $STATE OK "PASSED" "*** FAILED";
echo both ": negative calc top yelds STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select top (-1,1) word from words;
echo both $if $NEQ $STATE OK "PASSED" "*** FAILED";
echo both ": negative calc skip part yelds STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select top (1,-2) word from words;
echo both $if $NEQ $STATE OK "PASSED" "*** FAILED";
echo both ": negative calc top part yelds STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

select top 1,1 word from words order by 1 desc;
echo both $if $equ $last[1] "�vea" "PASSED" "*** FAILED";
echo both ": 2nd from end is " $last[1] "\n";

select top 1,1 concat (word) from words order by 1 desc;
echo both $if $equ $last[1] "�vea" "PASSED" "*** FAILED";
echo both ": 2nd from end sorted is " $last[1] "\n";

select top 1,1 concat (word) from words order by word;
echo both $if $equ $last[1] "aar�nica" "PASSED" "*** FAILED";
echo both ": 2nd skip exp from start " $last[1] "\n";


select top 5 len, word from words order by 1 desc;

-- XXX: with ties sorted oby not supported
--select top 5 with ties len, word from words order by 1 desc;
--echo both $if $equ $rowcnt 304 "PASSED" "*** FAILED";
--echo both ": " $rowcnt " top 5 length desc with ties\n";

-- suite for bug 2094
DROP TABLE B2094;
CREATE TABLE B2094(
 ID            integer PRIMARY KEY,
 DT            DATETIME     NULL
);

INSERT INTO B2094 (ID,DT) VALUES( 1,(cast('2002-01-21 17:05:18' as datetime)));
INSERT INTO B2094 (ID,DT) VALUES( 2,(cast('2002-01-22 12:38:00' as datetime)));
INSERT INTO B2094 (ID,DT) VALUES( 3,(cast('2001-01-23 11:38:00' as datetime)));
INSERT INTO B2094 (ID,DT) VALUES( 4,(cast('2001-01-24 1:38:00'  as datetime)));
INSERT INTO B2094 (ID,DT) VALUES( 5,(cast('2001-01-25 2:38:00'  as datetime)));
INSERT INTO B2094 (ID,DT) VALUES( 6,(cast('1999-01-26 01:48:00' as datetime)));
INSERT INTO B2094 (ID,DT) VALUES( 7,(cast('1999-01-27 14:38:00' as datetime)));
INSERT INTO B2094 (ID,DT) VALUES( 8,(cast('1988-01-28 2:00:00'  as datetime)));
INSERT INTO B2094 (ID,DT) VALUES( 9,(cast('1988-01-29 1:59:00'  as datetime)));
INSERT INTO B2094 (ID,DT) VALUES(10,(cast('1978-01-20 00:00:00' as datetime)));


SELECT year(DT),count(year(DT)) FROM B2094 where year(DT) = 2001 group BY year(DT);
ECHO BOTH $IF $EQU $LAST[1] 2001 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": BUG2094-1: GROUP BY in select STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

SELECT year(DT) FROM B2094 where year(DT) = 2001 group BY year(DT);
ECHO BOTH $IF $EQU $LAST[1] 2001 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": BUG2094-2: GROUP BY in select STATE=" $STATE " MESSAGE=" $MESSAGE "\n";

SELECT count(year(DT)),year(DT) FROM B2094 where year(DT) = 2001 group BY year(DT);
ECHO BOTH $IF $EQU $LAST[2] 2001 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": BUG2094-3: GROUP BY in select STATE=" $STATE " MESSAGE=" $MESSAGE "\n";
ECHO BOTH $IF $EQU $ROWCNT 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": BUG2094-4: GROUP BY in select STATE=" $STATE " MESSAGE=" $MESSAGE "\n";


SELECT TOP 10 ROW_NO, COUNT(ROW_NO) FROM T1 GROUP BY ROW_NO;
ECHO BOTH $IF $EQU $ROWCNT 10 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": GROUP BY switch from chash to memcache in select COUNT=" $ROWCNT "\n";
