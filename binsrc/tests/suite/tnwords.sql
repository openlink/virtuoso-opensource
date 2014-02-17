--
--  tnwords.sql
--
--  $Id: tnwords.sql,v 1.9.8.2 2013/01/02 16:15:14 source Exp $
--
--  Word tests
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

echo BOTH "STARTED: NVARCHAR Wordtest (about 7 minutes with Pentium 166Mhz)\n";

CONNECT;

SET ARGV[0] 0;
SET ARGV[1] 0;

-- Timeout to 20 minutes:
set timeout 12000;
load revstr.sql;
load succ.sql;
foreach line in words.esp
insert into nwords(word,revword,len) values(?,revstr(?1),length(?1));

select count(*) from nwords;
ECHO BOTH $IF $EQU $LAST[1] 86061 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Table word contains count(*) " $LAST[1] " lines\n";

select count(*) from nwords order by len desc;
ECHO BOTH $IF $EQU $LAST[1] 86061 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Table word contains count(*) " $LAST[1] " lines ordered by desc len\n";

select sum(len) from nwords;
ECHO BOTH $IF $EQU $LAST[1] 749045 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Total sum of lengths of nwords, sum(len)=" $LAST[1] "\n";



select  top 10 *  from nwords a table option (index nwords) where  not exists (select 1 from nwords b table option (hash, index nwords) where a.word = b.word and a.len = b.len);
echo both $if $equ $rowcnt 0 "PASSED" "***FAILED";
echo both ": nwords consistent by hash\n";

select  top 10 *  from nwords a table option (index nwords) where  not exists (select 1 from nwords b table option (loop, index nwords) where a.word = b.word and a.len = b.len);
echo both $if $equ $rowcnt 0 "PASSED" "***FAILED";;
echo both ": nwords consistent by index\n";


--
-- Note that 749045 + 86061 (count of lines, for newlines) = 835106
-- the total length of words.esp file in Unix.
--
-- Note that in next avg(len) would produce 8, an integer. We have to
-- explicitly convert the len to double by adding it to 0.0
--
select sprintf ('%.5f', avg(sin(pi()) + len)) from nwords;
ECHO BOTH $IF $EQU $LAST[1] 8.70365 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Average length of a word, avg(0.0 + len)=" $LAST[1] "\n";

--
-- Let's check these numbers in another way:
--
insert into nwordcounts(num,totsum,avg1len)
       select count(len),sum(len),avg(sin(pi())+len) from nwords;
update nwordcounts set avg2len = (sin(pi()) + totsum)/num;
select num, totsum, sprintf ('%.5f', avg1len), sprintf ('%.5f', avg2len) from nwordcounts;
ECHO BOTH $IF $EQU $LAST[1] 86061 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Table word contains, num=" $LAST[1] " lines\n";

ECHO BOTH $IF $EQU $LAST[2] 749045 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Total sum of lengths of nwords, totsum=" $LAST[2] "\n";
ECHO BOTH $IF $EQU $LAST[3] $LAST[4] "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": avg(0.0+len)=" $LAST[3] ", ((0.0+totsum)/num)=" $LAST[4] "\n";

--
-- Insert also the whole file nwords.esp as blob into the table:
--
SET HIDDEN_CRS CLEARED;
foreach blob in words.esp update nwordcounts set wholefile = ?;
-- possibly followed by:  where totsum is not null;
--                   or:  where isinteger(totsum);
--
select num+totsum, length(wholefile), equ((num+totsum),length(wholefile)),
iszero((length(wholefile)-num)-totsum) from nwordcounts;
ECHO BOTH $IF $EQU $LAST[1] $LAST[2] "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": num+totsum=" $LAST[1] ", length(wholefile)=" $LAST[2] "\n";

ECHO BOTH $IF $EQU $LAST[3] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": equ((num+totsum),length(wholefile))=" $LAST[3] "\n";

ECHO BOTH $IF $EQU $LAST[4] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": iszero((length(wholefile)-num)-totsum)=" $LAST[4] "\n";

select min(word) from nwords;
ECHO BOTH $IF $EQU $LAST[1] "a" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": min(word)='" $LAST[1] "'\n";

--
-- Then, test sorting order. Words starting with ISO-8859/1 8-bit
-- diacritic letters (ascii value > 128) should be sorted at end,
-- as strings should be compared like they were composed of unsigned bytes.
--
select word from nwords where word < 'abadejo' order by word;
ECHO BOTH $IF $EQU $ROWCNT 14 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": " $ROWCNT " nwords before 'abadejo'\n";

ECHO BOTH $IF $EQU $LAST[1] "abada" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Preceding word='" $LAST[1] "'\n";

select max(word) from nwords;
ECHO BOTH $IF $EQU $LAST[1] "\372vula" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": max(word)='" $LAST[1] "'\n";

select word,revword,len from nwords where word > 'zuzo' order by word;
ECHO BOTH $IF $EQU $ROWCNT 327 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": " $ROWCNT " nwords after 'zuzo'\n";

ECHO BOTH $IF $EQU $LAST[1] "\372vula" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Last word='" $LAST[1] "'\n";

ECHO BOTH $IF $EQU $LAST[2] "aluv\372" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Last word reversed='" $LAST[2] "'\n";

ECHO BOTH $IF $EQU $LAST[3] 5 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Last word length=" $LAST[3] "\n";

select max(revword) from nwords;
ECHO BOTH $IF $EQU $LAST[1] "\372yiruc" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": max(revword)='" $LAST[1] "'\n";

select revword from nwords where revword >= 'zuzoro' order by revword;
ECHO BOTH $IF $EQU $ROWCNT 608 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": " $ROWCNT " reversed nwords after and including 'zuzoro'\n";

ECHO BOTH $IF $EQU $LAST[1] "\372yiruc" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Last reversed word='" $LAST[1] "'\n";

select word,len from nwords where len > 11 and subseq(word, 0, 4) = 'otor'
order by len asc;
ECHO BOTH $IF $EQU $ROWCNT 3 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": " $ROWCNT " nwords longer than 11 chars, beginning with 'otor'\n";

ECHO BOTH $IF $EQU $LAST[1] "otorrinolaringolog\355a" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Last word='" $LAST[1] "'\n";

--
-- The four longest ranks of all nwords beginning with 'ot'
-- sorted by length.
--
select a.* from nwords a where a.word between 'ot' and 'ou'
       and 4 > (select count(*) from nwords b
                where b.word between 'ot' and 'ou' and b.len > a.len)
       order by a.len desc, a.word desc;
ECHO BOTH $IF $EQU $ROWCNT 8 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": " $ROWCNT " 'ot%' nwords belonging to four longest ranks\n";

ECHO BOTH $IF $EQU $LAST[1] "otacústica" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Last word of these='" $LAST[1] "'\n";

--
-- Same in more sensible way.
--
select * from nwords where len > 19 order by len, word;
ECHO BOTH $IF $EQU $ROWCNT 16 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": " $ROWCNT " nwords longer than 19 letters\n";

ECHO BOTH $IF $EQU $LAST[1] "electroencefalograf\355a" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Longest and last word in alphabetical order='" $LAST[1] "'\n";

select len, revword from nwords where len > 19 order by len, word;
ECHO BOTH $IF $EQU $ROWCNT 16 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": " $ROWCNT " nwords longer than 19, be len, w/o pk cols in order key\n";

--
-- Test IN-predicate.
--
select * from nwords where len in (20,21,22,23,24,25) order by len, word;
ECHO BOTH $IF $EQU $ROWCNT 16 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": " $ROWCNT " nwords longer than 19 letters, where len in (20,21,22,23,24,25)\n";

ECHO BOTH $IF $EQU $LAST[1] "electroencefalograf\355a" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Longest and last word in alphabetical order='" $LAST[1] "'\n";

--
-- Show all palindromic nwords:
--
select word, revword from nwords where word = revword
and length(word) > 3;
ECHO BOTH $IF $EQU $ROWCNT 23 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": " $ROWCNT " palindromic nwords of more than three letters\n";

ECHO BOTH $IF $EQU $LAST[1] "yatay" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Last word in alphabetical order='" $LAST[1] "'\n";

--
-- Show all palindromic nwords in length order. Test IN-predicate.
--
select * from nwords where len > 3 and word in (revword) order by len;
ECHO BOTH $IF $EQU $ROWCNT 23 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": " $ROWCNT " palindromic nwords of more than three letters\n";

ECHO BOTH $IF $EQU $LAST[1] "reconocer" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Last word in length order='" $LAST[1] "'\n";

--
-- Test IN-predicate again.
--
select * from nwords where word in ('mano',12345,'cabeza','pie','nariz','klyyvari') order by word;
ECHO BOTH $IF $EQU $ROWCNT 4 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;

ECHO BOTH ": " $ROWCNT " nwords belonging to set ('mano',12345,'cabeza','pie','nariz','klyyvari')\n";
ECHO BOTH $IF $EQU $LAST[1] "pie" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Last word in alphabetical order='" $LAST[1] "'\n";

--
-- Show all word - revword pairs where both ones are nwords, excluding
-- palindromes and duplicates:
--
select v1.word, v2.word from nwords v1, nwords v2 where v1.revword > v1.word
and length(v1.word) > 3 and v2.word = v1.revword order by 1;
ECHO BOTH $IF $EQU $ROWCNT 72 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": " $ROWCNT " halfpalindromic word pairs of more than three letters\n";

ECHO BOTH $IF $EQU $LAST[1] "rapaz" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Last word='" $LAST[1] "'\n";

ECHO BOTH $IF $EQU $LAST[2] "zapar" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Last word reversed='" $LAST[2] "'\n";

--
-- Show all nwords which have been formed like by doubling another word:
--
select v1.word, v2.word from nwords v1, nwords v2
where length(v1.word) >= 3 and v2.word = concat(v1.word,v1.word);
ECHO BOTH $IF $EQU $ROWCNT 25 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": " $ROWCNT " doubled nwords of more than two letters\n";

ECHO BOTH $IF $EQU $LAST[1] "vira" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Last word='" $LAST[1] "'\n";

ECHO BOTH $IF $EQU $LAST[2] "viravira" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Last word doubled='" $LAST[2] "'\n";

select word, len from nwords where word between 'ac' and 'al' order by len desc, word asc;
ECHO BOTH $IF $EQU $LAST [1] al "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": " $LAST [1] " was last in desc len, asc word select / order by cols.\n";

select concatenate (word, '-'), len from nwords where word between 'ac' and 'al' order by 2 desc, 1 asc;
ECHO BOTH $IF $EQU $LAST [1] al- "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": " $LAST [1] " was last in desc len, asc word select / order by col numbers.\n";

select count (distinct word), count (distinct len) from nwords;
ECHO BOTH $IF $EQU $LAST [1] 86061 "PASSED" "***FAILED";
ECHO BOTH ": " $LAST [1] " distinct nwords.\n";
ECHO BOTH $IF $EQU $LAST [2] 21 "PASSED" "***FAILED";
ECHO BOTH ": " $LAST [2] " distinct word lengths.\n";


ECHO BOTH "COMPLETED WITH " $ARGV[0] " FAILED, " $ARGV[1] " PASSED: Wordtest\n";
