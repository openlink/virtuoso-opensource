--
--  tcoll.sql
--
--  $Id$
--
--  Collation tests
--  
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--  
--  Copyright (C) 1998-2015 OpenLink Software
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

echo BOTH "STARTED: Collation test\n";

CONNECT;

SET ARGV[0] 0;
SET ARGV[1] 0;

collation_define('spanish', 'spanish.coll', 1);

-- Timeout to 20 minutes:
set timeout 1200;
drop table testcoll;
create table testcoll(word varchar, collword varchar collate spanish, primary key(word));
foreach line in words.esp insert into testcoll(word) values(?);
update testcoll set collword = word;
 
select count(*) from testcoll;
ECHO BOTH $IF $EQU $LAST[1] 86061 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Table word contains count(*) " $LAST[1] " lines\n";

--
-- Then, test sorting order. Words starting with ISO-8859/1 8-bit
-- diacritic letters (ascii value > 128) should be sorted at end,
-- as strings should be compared like they were composed of unsigned bytes.
--
select max(collword) from testcoll;
ECHO BOTH $IF $EQU $LAST[1] "zuzón" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": max(collword)='" $LAST[1] "'\n";

select max(cast (collword as varchar)) from testcoll;
ECHO BOTH $IF $EQU $LAST[1] "úvula" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": max(cast (collword as varchar))='" $LAST[1] "'\n";

select max(cast (word as varchar collate spanish)) from testcoll;
ECHO BOTH $IF $EQU $LAST[1] "zuzón" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": max(cast (word as varchar collate spanish))='" $LAST[1] "'\n";

select collword from testcoll where collword >= 'zuzón' order by collword;
ECHO BOTH $IF $EQU $ROWCNT 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": " $ROWCNT " spanish collated words after and including 'zuzón'\n";

ECHO BOTH $IF $EQU $LAST[1] "zuzón" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Last spanish collated word='" $LAST[1] "'\n";

select word from testcoll 
  where cast (word as varchar collate spanish) >= 'zuzón' 
  order by cast (word as varchar collate spanish);
ECHO BOTH $IF $EQU $ROWCNT 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": " $ROWCNT " binary collated (with cast to spanish) words after and including 'zuzón'\n";

ECHO BOTH $IF $EQU $LAST[1] "zuzón" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Last binary collated (with cast to spanish) word='" $LAST[1] "'\n";

select collword from testcoll where collword like 'octu%' order by collword asc;
ECHO BOTH $IF $EQU $ROWCNT 4 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": " $ROWCNT " words beginning with 'octu%'\n";

ECHO BOTH $IF $EQU $LAST[1] "óctuplo" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Last word='" $LAST[1] "'\n";

--
-- The four longest ranks of all words beginning with 'ot'
-- sorted by length.
--
select collword from testcoll where collword between 'os' and 'ov' order by collword desc;
ECHO BOTH $IF $EQU $ROWCNT 160 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": " $ROWCNT " spanish collated words between os and ov\n";

ECHO BOTH $IF $EQU $LAST[1] "os" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Last word of these='" $LAST[1] "'\n";

select word from testcoll 
  where cast (word as varchar collate spanish) between 'os' and 'ov' 
  order by cast (word as varchar collate spanish) desc;
ECHO BOTH $IF $EQU $ROWCNT 160 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": " $ROWCNT " cast (collate spanish) words between os and ov\n";

ECHO BOTH $IF $EQU $LAST[1] "os" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Last word of these='" $LAST[1] "'\n";

--
-- Test IN-predicate.
--
select collword from testcoll 
  where collword in ('abscuro', 'absente', 'abscura', 'ácido', 'émbolo', 'ñuto') 
  order by collword;
ECHO BOTH $IF $EQU $ROWCNT 6 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": " $ROWCNT " spanish collated words in (abscuro, absente, abscura, ácido, émbolo, ñuto)\n";

ECHO BOTH $IF $EQU $LAST[1] "ñuto" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Last spanish collated word in alphabetical order='" $LAST[1] "'\n";

select word from testcoll 
  where cast (word as varchar collate spanish) 
     in ('abscuro', 'absente', 'abscura', 'ácido', 'émbolo', 'ñuto') 
  order by cast (word as varchar collate spanish);
ECHO BOTH $IF $EQU $ROWCNT 6 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": " $ROWCNT " cast (spanish) words in (abscuro, absente, abscura, ácido, émbolo, ñuto)\n";

ECHO BOTH $IF $EQU $LAST[1] "ñuto" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": Last cast (spanish) word in alphabetical order='" $LAST[1] "'\n";

ECHO BOTH "COMPLETED WITH " $ARGV[0] " FAILED, " $ARGV[1] " PASSED: Collation test\n";
