--
--  twords.sql
--
--  $Id$
--
--  Word tests
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

echo BOTH "STARTED: Wordtest (about 7 minutes with Pentium 166Mhz)\n";

CONNECT;

SET ARGV[0] 0;
SET ARGV[1] 0;

-- Timeout to 20 minutes:
set timeout 1200;
load revstr.sql;
load succ.sql;
drop table words;
create table words(word varchar, revword varchar, len integer, primary key(word))
alter index words on words partition (word varchar);

create index revword on words(revword) partition (revword varchar);
create index len on words(len) partition (len int);
foreach line in words.esp
 insert into words(word,revword,len) values(?,revstr(?1),length(?1));

select count(*) from words;
ECHO BOTH $IF $EQU $LAST[1] 86061 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Table word contains count(*) " $LAST[1] " lines\n";

select count(*) from words order by len desc;
ECHO BOTH $IF $EQU $LAST[1] 86061 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Table word contains count(*) " $LAST[1] " lines ordered by desc len\n";

select sum(len) from words;
ECHO BOTH $IF $EQU $LAST[1] 749045 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Total sum of lengths of words, sum(len)=" $LAST[1] "\n";

--
-- Note that 749045 + 86061 (count of lines, for newlines) = 835106
-- the total length of words.esp file in Unix.
--
-- Note that in next avg(len) would produce 8, an integer. We have to
-- explicitly convert the len to double by adding it to 0.0
--
select sprintf ('%.5f', avg(cast (0 as double precision) + len)) from words;
ECHO BOTH $IF $EQU $LAST[1] 8.70365 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Average length of a word, avg(0.0 + len)=" $LAST[1] "\n";

--
-- Let's check these numbers in another way:
--
drop table wordcounts;
create table wordcounts(num integer, totsum integer,
             avg1len double precision, avg2len double precision,
             wholefile long varchar, primary key(num, totsum));
insert into wordcounts(num,totsum,avg1len)
       select count(len),sum(len),avg(sin(pi())+len) from words;
update wordcounts set avg2len = ((sin(pi())+totsum)/num);
select num, totsum, sprintf ('%.5f', avg1len), sprintf ('%.5f', avg2len) from wordcounts;
ECHO BOTH $IF $EQU $LAST[1] 86061 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;2060747611
ECHO BOTH ": Table word contains, num=" $LAST[1] " lines\n";

ECHO BOTH $IF $EQU $LAST[2] 749045 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Total sum of lengths of words, totsum=" $LAST[2] "\n";
ECHO BOTH $IF $EQU $LAST[3] $LAST[4] "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": avg(0.0+len)=" $LAST[3] ", ((0.0+totsum)/num)=" $LAST[4] "\n";

--
-- And check that averages computed with two different ways are really same:
--
select equ(avg1len,avg2len), (avg1len-avg2len), iszero(avg2len - avg1len)
       from wordcounts;
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": equ(avg1len,avg2len)=" $LAST[1] "\n";

-- ECHO BOTH $IF $EQU $LAST[3] 1 "PASSED" "***FAILED";
-- SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
-- ECHO BOTH ": (avg2len-avg1len)=" $LAST[2] ", iszero(avg1len-avg2len)=" $LAST[3] "\n";

--
-- Insert also the whole file words.esp as blob into the table:
--
SET HIDDEN_CRS CLEARED;
foreach blob in words.esp update wordcounts set wholefile = ?;
-- possibly followed by:  where totsum is not null;
--                   or:  where isinteger(totsum);
--
select num+totsum, length(wholefile), equ((num+totsum),length(wholefile)),
iszero((length(wholefile)-num)-totsum) from wordcounts;
ECHO BOTH $IF $EQU $LAST[1] $LAST[2] "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": num+totsum=" $LAST[1] ", length(wholefile)=" $LAST[2] "\n";

ECHO BOTH $IF $EQU $LAST[3] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": equ((num+totsum),length(wholefile))=" $LAST[3] "\n";

ECHO BOTH $IF $EQU $LAST[4] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": iszero((length(wholefile)-num)-totsum)=" $LAST[4] "\n";

select min(word) from words;
ECHO BOTH $IF $EQU $LAST[1] "a" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": min(word)='" $LAST[1] "'\n";

--
-- Then, test sorting order. Words starting with ISO-8859/1 8-bit
-- diacritic letters (ascii value > 128) should be sorted at end,
-- as strings should be compared like they were composed of unsigned bytes.
--
select word from words where word < 'abadejo' order by word;
ECHO BOTH $IF $EQU $ROWCNT 14 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": " $ROWCNT " words before 'abadejo'\n";

ECHO BOTH $IF $EQU $LAST[1] "abada" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Preceding word='" $LAST[1] "'\n";

select max(word) from words;
ECHO BOTH $IF $EQU $LAST[1] "\372vula" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": max(word)='" $LAST[1] "'\n";

select word,revword,len from words where word > 'zuzo' order by word;
ECHO BOTH $IF $EQU $ROWCNT 327 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": " $ROWCNT " words after 'zuzo'\n";

ECHO BOTH $IF $EQU $LAST[1] "\372vula" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Last word='" $LAST[1] "'\n";

ECHO BOTH $IF $EQU $LAST[2] "aluv\372" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Last word reversed='" $LAST[2] "'\n";

ECHO BOTH $IF $EQU $LAST[3] 5 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Last word length=" $LAST[3] "\n";

select max(revword) from words;
ECHO BOTH $IF $EQU $LAST[1] "\372yiruc" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": max(revword)='" $LAST[1] "'\n";

select revword from words where revword >= 'zuzoro' order by revword;
ECHO BOTH $IF $EQU $ROWCNT 608 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": " $ROWCNT " reversed words after and including 'zuzoro'\n";

ECHO BOTH $IF $EQU $LAST[1] "\372yiruc" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Last reversed word='" $LAST[1] "'\n";

select word,len from words where len > 11 and word like 'otor%'
order by len asc;
ECHO BOTH $IF $EQU $ROWCNT 3 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": " $ROWCNT " words longer than 11 chars, beginning with 'otor'\n";

ECHO BOTH $IF $EQU $LAST[1] "otorrinolaringolog\355a" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Last word='" $LAST[1] "'\n";

--
-- The four longest ranks of all words beginning with 'ot'
-- sorted by length.
--
select a.* from words a where a.word between 'ot' and 'ou'
       and 4 > (select count(*) from words b
                where b.word between 'ot' and 'ou' and b.len > a.len)
       order by a.len desc;
ECHO BOTH $IF $EQU $ROWCNT 8 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": " $ROWCNT " 'ot%' words belonging to four longest ranks\n";

ECHO BOTH $IF $EQU $LAST[3] 10 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Last word of these " $LAST[3] " chars long\n";

--
-- Same in more sensible way.
--
select * from words where len > 19 order by len, word;
ECHO BOTH $IF $EQU $ROWCNT 16 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": " $ROWCNT " words longer than 19 letters\n";

ECHO BOTH $IF $EQU $LAST[1] "electroencefalograf\355a" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Longest and last word in alphabetical order='" $LAST[1] "'\n";

select DB.DBA.words.len, revword from words where len > 19 order by len, word;
ECHO BOTH $IF $EQU $ROWCNT 16 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": " $ROWCNT " words longer than 19, be len, w/o pk cols in order key\n";

--
-- Test IN-predicate.
--
select * from words where len in (20,21,22,23,24,25) order by len, word;
ECHO BOTH $IF $EQU $ROWCNT 16 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": " $ROWCNT " words longer than 19 letters, where len in (20,21,22,23,24,25)\n";

ECHO BOTH $IF $EQU $LAST[1] "electroencefalograf\355a" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Longest and last word in alphabetical order='" $LAST[1] "'\n";

--
-- Show all palindromic words:
--
select word, revword from words where ucase(word) = ucase(revword)
and length(word) > 3;
ECHO BOTH $IF $EQU $ROWCNT 23 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": " $ROWCNT " palindromic words of more than three letters\n";

ECHO BOTH $IF $EQU $LAST[1] "yatay" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Last word in alphabetical order='" $LAST[1] "'\n";

--
-- Show all palindromic words in length order. Test IN-predicate.
--
select * from words where len > 3 and word in (revword) order by len;
ECHO BOTH $IF $EQU $ROWCNT 23 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": " $ROWCNT " palindromic words of more than three letters\n";

ECHO BOTH $IF $EQU $LAST[1] "reconocer" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Last word in length order='" $LAST[1] "'\n";

--
-- Test IN-predicate again.
--
select * from words where word in ('mano',12345,'cabeza','pie','nariz','klyyvari') order by word;
ECHO BOTH $IF $EQU $ROWCNT 4 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;

ECHO BOTH ": " $ROWCNT " words belonging to set ('mano',12345,'cabeza','pie','nariz','klyyvari')\n";
ECHO BOTH $IF $EQU $LAST[1] "pie" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Last word in alphabetical order='" $LAST[1] "'\n";

--
-- Show all word - revword pairs where both ones are words, excluding
-- palindromes and duplicates:
--
select v1.word, v2.word from words v1, words v2 where v1.revword > v1.word
and length(v1.word) > 3 and v2.word = lcase(v1.revword) order by 1;
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
-- Show all words which have been formed like by doubling another word:
--
select v1.word, v2.word from words v1, words v2
where length(v1.word) >= 3 and v2.word = concat(v1.word,lcase(v1.word)) order by v1.word;
ECHO BOTH $IF $EQU $ROWCNT 25 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": " $ROWCNT " doubled words of more than two letters\n";

ECHO BOTH $IF $EQU $LAST[1] "vira" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Last word='" $LAST[1] "'\n";

ECHO BOTH $IF $EQU $LAST[2] "viravira" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Last word doubled='" $LAST[2] "'\n";

-- ibid with dt and sort, test placing of funcs in place of lowest card 
select v1.word, v2.word from words v1, (select distinct word from words where length (word) > 2) v2
where length(v1.word) >= 3 and v2.word = concat(v1.word,lcase(v1.word)) order by ucase (v1.word);

ECHO BOTH $IF $EQU $LAST[2] "viravira" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Last word doubled='" $LAST[2] "' with dt and sort\n";



--
-- Nothing new in the following two examples, commented out:
--
-- Show all s[word] - revword pairs where the first one is a word beginning
-- with the letter s, and second one is that word reversed without the
-- plural ending:
--
-- select v1.word, v2.word from words v1, words v2 where v1.word >= 's' and
-- v1.word < 't' and v2.word = subseq(v1.revword,0,length(v1.revword)-1);
--
-- Show all se[word] - revword pairs where the first one is a word
-- beginning with the letters se, and second one is that word reversed
-- without the plural ending -es (of the words ending with consonant,
-- like azul - azules):
-- select v1.word, v2.word from words v1, words v2 where v1.word >= 'se' and
-- v1.word < 'sf' and v2.word = subseq(v1.revword,0,length(v1.revword)-2);
--
-- Show all spanish compound words of the style:
-- limpiar + bota = limpiabotas
-- cortar + pluma = cortaplumas
--
select v1.word, v3.word, v2.word from words v1, words v2, words v3
where v1.revword >= 'r' and v1.revword < 's' and v1.revword like 'r[aei]__*'
and v2.word > subseq(v1.word,0,length(v1.word)-1) and
v2.word < succ(subseq(v1.word,0,length(v1.word)-1)) and
v2.word like '*s' and
v3.word = subseq(v2.word,length(v1.word)-1,length(v2.word)-1)
and length(v3.word) > 2
order by v1.word, v3.word;
ECHO BOTH $IF $EQU $ROWCNT 248 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": " $ROWCNT " compound words of at least seven letters\n";

ECHO BOTH $IF $EQU $LAST[1] "zampar" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Last word, first part='" $LAST[1] "'\n";

ECHO BOTH $IF $EQU $LAST[2] "torta" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Last word, second part='" $LAST[2] "'\n";

ECHO BOTH $IF $EQU $LAST[3] "zampatortas" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Last word, whole='" $LAST[3] "'\n";

--
-- With   order by v1.word, v3.word;   will fail, producing many spurious
-- pairings, e.g.:
-- ablandar  breva   ablandabrevas    (Correct, but the following are not)
-- ablandar  breña   ablandabrevas
-- albar     tío     albatros
-- Note that the central column (v3.word) although can be totally spurious
-- seems to be anyway always of the same length than what is required.
--
-- Show all spanish compound words of the style:
-- vagar + mundo = vagamundo (or Catalan rodar + mo'n = rodamo'n)
-- Produces a lot's of noise, commented out:
--
-- select v1.word, v3.word, v2.word from words v1, words v2, words v3
-- where v1.revword >= 'r' and v1.revword < 's' and
-- v2.word > subseq(v1.word,0,length(v1.word)-1) and
-- v2.word < succ(subseq(v1.word,0,length(v1.word)-1)) and
-- v3.word = subseq(v2.word,length(v1.word)-1,length(v2.word));
--
-- Show all words for which there exists another word prefixed with one
-- letter:
-- select v2.word, v1.word from words v1, words v2 where
-- v2.word = subseq(v1.word,1,length(v1.word));
--
-- THIS WILL KILL Virtuoso BECAUSE OF ORDER BY (not anymore, but takes eternity)
-- Show all words for which there exists another word prefixed with one
-- letter:
-- select v2.word, v1.word from words v1, words v2 where
-- v2.word = subseq(v1.word,1,length(v1.word)) order by v2.word;
--

select word, len from words where word between 'ac' and 'al' order by len desc, word asc;
ECHO BOTH $IF $EQU $LAST [1] al "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": " $LAST [1] " was last in desc len, asc word select / order by cols.\n";

select concatenate (word, '-'), len from words where word between 'ac' and 'al' order by 2 desc, 1 asc;
ECHO BOTH $IF $EQU $LAST [1] al- "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": " $LAST [1] " was last in desc len, asc word select / order by col numbers.\n";

select count (distinct word), count (distinct len) from words;
ECHO BOTH $IF $EQU $LAST [1] 86061 "PASSED" "***FAILED";
ECHO BOTH ": " $LAST [1] " distinct words.\n";
ECHO BOTH $IF $EQU $LAST [2] 21 "PASSED" "***FAILED";
ECHO BOTH ": " $LAST [2] " distinct word lengths.\n";


select count (*) from words wherre word like 'burro';
ECHO BOTH $IF $EQU $LAST[1]  "PASSED" "***FAILED";
ECHO BOTH ": exact like OK.\n";


select count (*) from words where word like '%';
ECHO BOTH $IF $EQU $LAST[1]  86061 "PASSED" "***FAILED";
ECHO BOTH ": % like OK.\n";


select count (*) from words where word like 'bur%';
ECHO BOTH $IF $EQU $LAST[1]  90  "PASSED" "***FAILED";
ECHO BOTH ": prefix % like OK.\n";


ECHO BOTH "COMPLETED WITH " $ARGV[0] " FAILED, " $ARGV[1] " PASSED: Wordtest\n";
