--
--  rtesta.sql
--
--  $Id$
--
--  Remote database testing
--  
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--  
--  Copyright (C) 1998-2006 OpenLink Software
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
-- Array parameters in VDB
--

ECHO BOTH "REMOTE ARRAY PARAMETER TESTS\n";


select count (*) from R1..T1 a inner join R1..T1 b on a.ROW_NO = b.ROW_NO;

ECHO BOTH $IF $EQU $LAST[1] 1000 "PASSED" "***FAILED";
ECHO BOTH ": count " $LAST[1] " r1..t1 natural  r1..t1\n";


select count (*) from (select a.row_no from R1..T1 a inner join R1..T1 b on a.ROW_NO = b.ROW_NO) F;

ECHO BOTH $IF $EQU $LAST[1] 1000 "PASSED" "***FAILED";
ECHO BOTH ": count " $LAST[1] " r1..t1 natural  r1..t1\n";


select count (*) from (select * from R1..T1 A natural join R1..T1 B) F;

ECHO BOTH $IF $EQU $LAST[1] 1000 "PASSED" "***FAILED";
ECHO BOTH ": count " $LAST[1] " r1..t1 natural  r1..t1\n";


select A.ROW_NO, A.STRING1, A.STRING2 from R1..T1 A natural join R1..T1 B where A.ROW_NO < 150;

ECHO BOTH $IF $EQU $LAST[1] 149 "PASSED" "***FAILED";
ECHO BOTH ": " $LAST[1] " r1..t1 natural  r1..t1\n";
ECHO BOTH $IF $EQU $LAST[2] 149 "PASSED" "***FAILED";
ECHO BOTH ": " $LAST[2] " r1..t1 natural  r1..t1\n";
ECHO BOTH $IF $EQU $LAST[3] 151 "PASSED" "***FAILED";
ECHO BOTH ": " $LAST[3] " r1..t1 natural  r1..t1\n";


select A.ROW_NO, A.STRING1, A.STRING2 from R1..T1 A natural join R1..T1 B using (ROW_NO) where A.ROW_NO < 150;

ECHO BOTH $IF $EQU $LAST[1] 149 "PASSED" "***FAILED";
ECHO BOTH ": " $LAST[1] " r1..t1 natural  r1..t1\n";
ECHO BOTH $IF $EQU $LAST[2] 149 "PASSED" "***FAILED";
ECHO BOTH ": " $LAST[2] " r1..t1 natural  r1..t1\n";
ECHO BOTH $IF $EQU $LAST[3] 151 "PASSED" "***FAILED";
ECHO BOTH ": " $LAST[3] " r1..t1 natural  r1..t1\n";


select count (*) from (select * from R1..T1 A natural join R1..T1 B) F;

insert into misc (m_id, m_short) select ROW_NO, STRING1 from R1..T1;

create procedure mod (in a integer, in b integer)
{
  return (a - ((a / b) * b));
}

update misc set m_long = make_string (5000, '-') where mod (m_id, 13) = 0;

delete from r1..misc;

insert into R1..misc (m_id, m_short, m_long) select m_id, m_short, m_long from misc;

select count (*), sum (length (m_long)) from r1..misc;

ECHO BOTH $IF $EQU $LAST[1] 1000 "PASSED" "***FAILED";
ECHO BOTH ": " $LAST[1] " rows in r1..misc\n";
ECHO BOTH $IF $EQU $LAST[2] 385000 "PASSED" "***FAILED";
ECHO BOTH ": " $LAST[1] " blob bytes in r1..misc\n";


create procedure f (in f integer) { return f; };

update r1..misc set m_short = concat (m_short, 'aa') where mod (m_id, 13) = 1;

select count (*) from misc a natural join r1..misc b using (m_id, m_short);
ECHO BOTH $IF $EQU $LAST[1] 923 "PASSED" "***FAILED";
ECHO BOTH ": " $LAST[1] " rows in r1..misc\n";


update misc set m_short = concat (m_short, 'aa') where mod (m_id, 13) = 1;

select count (*) from misc a natural join r1..misc b using (m_id, m_short);
ECHO BOTH $IF $EQU $LAST[1] 1000 "PASSED" "***FAILED";
ECHO BOTH ": count " $LAST[1] " count heterogenous dtp array join 1\n";


select count (*) from (select b.m_id from misc a natural join r1..misc b using (m_id, m_short)) F;
ECHO BOTH $IF $EQU $LAST[1] 1000 "PASSED" "***FAILED";
ECHO BOTH ": count " $LAST[1] " count heterogenous dtp array join 2\n";


delete from r1..misc where mod (f (m_id), 2) = 1;

select a.m_id, b.m_id from misc a natural left join r1..misc b using (m_id) where a.m_id < 200;

select count (*) from (select a.m_id, b.m_id as joined from misc a natural left join r1..misc b using (m_id)) F where f.joined is null;

ECHO BOTH $IF $EQU $LAST[1] 500 "PASSED" "***FAILED";
ECHO BOTH ": count " $LAST[1] " outer rows in array outer join \n";


select a.row_no, b.row_no from r1..t1 a join r1..t1 b on b.row_no  between a.row_no - 1 and a.row_no + 1 where a.row_no < 120;

ECHO BOTH $IF $EQU $ROWCNT 59 "PASSED" "***FAILED";
ECHO BOTH ": "  $ROWCNT " rows in join with between\n";
