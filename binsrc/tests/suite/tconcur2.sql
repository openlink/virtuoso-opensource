--
--  tconcur2.sql
--
--  $Id: tconcur2.sql,v 1.4.6.2.4.1 2013/01/02 16:15:01 source Exp $
--
--  Concurrency test #2
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

--
-- Test for concurrent insertions, version two, using automatic timestamp
-- primary key. By AK 31-MAR-1997.
--

echo BOTH "STARTED: Concurrent inserts with timestamp key\n";

drop table iutest;
create table iutest(num integer,txt varchar,ts timestamp,primary key(ts))
alter index iutest on iutest partition (ts varchar);

-- Spawn two isql's to background each to insert ten thousand and one items:
CONNECT; SET AUTOCOMMIT=ON; FOREACH INTEGER BETWEEN 100001 110000 insert into iutest(num,txt) values(?,'Proc1'); insert into iutest(num,txt) values(1,'Proc1 Last') &
CONNECT; SET AUTOCOMMIT=ON; FOREACH INTEGER BETWEEN 200001 210000 insert into iutest(num,txt) values(?,'Proc2'); insert into iutest(num,txt) values(1,'Proc2 Last') &

-- But run the third insertion from this isql, not in background:
SET AUTOCOMMIT=ON;
FOREACH INTEGER BETWEEN 300001 310000
  insert into iutest(num,txt) values(?,'Proc3');
insert into iutest(num,txt) values(1,'Proc3 Last');
SET AUTOCOMMIT=OFF;

-- Then wait for all wee children to finish
WAIT_FOR_CHILDREN;

-- And sleep one second more as WAIT above might not be perfect...
SLEEP 1;

-- We can clear the passed and failed counts only after the spawning:
SET ARGV[0] 0;
SET ARGV[1] 0;

-- Before checking the count, which should be 30003:
select count(*) from iutest;
ECHO BOTH $IF $EQU $LAST[1] 30003 "PASSED" "***FAILED";
SET ARGV[$NEQ $LWE "PASSED"] $+ $ARGV[$NEQ $LWE "PASSED"] 1;
ECHO BOTH ": Concurrent Inserting with timestamp primary key and insert, table contains " $LAST[1] " lines\n";


create table tn (id int primary key);
foreach integer between 1 4000  insert into tn values (?);

select count (*) from tn;
ECHO BOTH $IF $EQU $LAST[1] 4000  "PASSED" "***FAILED";
SET ARGV[$NEQ $LWE "PASSED"] $+ $ARGV[$NEQ $LWE "PASSED"] 1;
ECHO BOTH ": min row length insert, table contains " $LAST[1] " lines\n";



ECHO BOTH "COMPLETED WITH " $ARGV[1] " FAILED, " $ARGV[0] " PASSED: Concurrency test #2, Run " $ARGV[$I] "\n";
