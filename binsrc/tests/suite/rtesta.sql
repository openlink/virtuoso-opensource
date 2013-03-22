--
--  rtesta.sql
--
--  $Id: rtesta.sql,v 1.7.6.2.4.1 2013/01/02 16:14:55 source Exp $
--
--  Remote database testing
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

--
-- Array parameters in VDB
--

ECHO BOTH "REMOTE ARRAY PARAMETER TESTS\n";



create function f (in a any) {return a;};


select count (*) from R1..T1 a inner join R1..T1 b on a.ROW_NO = f(b.ROW_NO) where f (a.string1) = f(b.string1) option (loop);

ECHO BOTH $IF $EQU $LAST[1] 1000 "PASSED" "***FAILED";
ECHO BOTH ": count " $LAST[1] " r1..t1 natural  r1..t1\n";


select count (*) from (select a.row_no from R1..T1 a inner join R1..T1 b on f(a.ROW_NO) = b.ROW_NO) F;

ECHO BOTH $IF $EQU $LAST[1] 1000 "PASSED" "***FAILED";
ECHO BOTH ": count " $LAST[1] " r1..t1 natural  r1..t1\n";


select count (*) from (select * from R1..T1 A natural join R1..T1 B where f(a.row_no) = f (b.row_no) option (loop))f;
ECHO BOTH $IF $EQU $LAST[1] 1000 "PASSED" "***FAILED";
ECHO BOTH ": count " $LAST[1] " r1..t1 natural  r1..t1\n";


select A.ROW_NO, A.STRING1, A.STRING2 from R1..T1 A natural join R1..T1 B where A.ROW_NO < 150;

ECHO BOTH $IF $EQU $LAST[1] 149 "PASSED" "***FAILED";
ECHO BOTH ": " $LAST[1] " r1..t1 natural  r1..t1\n";
ECHO BOTH $IF $EQU $LAST[2] 149 "PASSED" "***FAILED";
ECHO BOTH ": " $LAST[2] " r1..t1 natural  r1..t1\n";
ECHO BOTH $IF $EQU $LAST[3] 151 "PASSED" "***FAILED";
ECHO BOTH ": " $LAST[3] " r1..t1 natural  r1..t1\n";


select A.ROW_NO, A.STRING1, A.STRING2 from R1..T1 A natural join R1..T1 B using (ROW_NO) where f(A.ROW_NO) < 150 option (loop, order);

ECHO BOTH $IF $EQU $LAST[1] 149 "PASSED" "***FAILED";
ECHO BOTH ": " $LAST[1] " r1..t1 natural  r1..t1\n";
ECHO BOTH $IF $EQU $LAST[2] 149 "PASSED" "***FAILED";
ECHO BOTH ": " $LAST[2] " r1..t1 natural  r1..t1\n";
ECHO BOTH $IF $EQU $LAST[3] 151 "PASSED" "***FAILED";
ECHO BOTH ": " $LAST[3] " r1..t1 natural  r1..t1\n";


select count (*) from (select * from R1..T1 A natural join R1..T1 B) F;

delete from misc;
insert into misc (m_id, m_short) select ROW_NO, STRING1 from R1..T1;

create procedure p_mod (in a integer, in b integer)
{
  return (a - ((a / b) * b));
}

update misc set m_long = make_string (5000, '-') where p_mod (m_id, 13) = 0;

delete from r1..misc;

insert into R1..misc (m_id, m_short, m_long) select m_id, m_short, m_long from misc;

select count (*), sum (length (m_long)) from r1..misc;

ECHO BOTH $IF $EQU $LAST[1] 1000 "PASSED" "***FAILED";
ECHO BOTH ": " $LAST[1] " rows in r1..misc\n";
ECHO BOTH $IF $EQU $LAST[2] 385000 "PASSED" "***FAILED";
ECHO BOTH ": " $LAST[1] " blob bytes in r1..misc\n";




update r1..misc set m_short = concat (m_short, 'aa') where p_mod (m_id, 13) = 1;

select count (*) from misc a natural join r1..misc b using (m_id, m_short);
ECHO BOTH $IF $EQU $LAST[1] 923 "PASSED" "***FAILED";
ECHO BOTH ": " $LAST[1] " rows in r1..misc\n";


update misc set m_short = concat (m_short, 'aa') where p_mod (m_id, 13) = 1;

select count (*) from misc a natural join r1..misc b using (m_id, m_short);
ECHO BOTH $IF $EQU $LAST[1] 1000 "PASSED" "***FAILED";
ECHO BOTH ": count " $LAST[1] " count heterogenous dtp array join 1\n";


select count (*) from (select b.m_id from misc a natural join r1..misc b using (m_id, m_short)) F;
ECHO BOTH $IF $EQU $LAST[1] 1000 "PASSED" "***FAILED";
ECHO BOTH ": count " $LAST[1] " count heterogenous dtp array join 2\n";


delete from r1..misc where p_mod (f (m_id), 2) = 1;

select a.m_id, b.m_id from misc a natural left join r1..misc b using (m_id) where a.m_id < 200;

select count (*) from (select a.m_id, b.m_id as joined from misc a natural left join r1..misc b using (m_id)) F where f.joined is null;

ECHO BOTH $IF $EQU $LAST[1] 500 "PASSED" "***FAILED";
ECHO BOTH ": count " $LAST[1] " outer rows in array outer join \n";


select a.row_no, b.row_no from r1..t1 a join r1..t1 b on b.row_no  between a.row_no - 1 and a.row_no + 1 where a.row_no < 120;
ECHO BOTH $IF $EQU $ROWCNT 59 "PASSED" "***FAILED";
ECHO BOTH ": "  $ROWCNT " rows in join with between\n";


select count (*), sum (a.row_no + b.row_no + c.row_no + d.row_no) 
from r1..t1 a, 
	(select row_no, count (*) as ct  from r1..t1 table option (loop) group by row_no) b,
	r1..t1 c table option (hash), r1..t1 d table option (loop)
where b.row_no = f(a.row_no) and c.row_no = f (b.row_no) and c.row_no = f(b.row_no) and d.row_no = f(c.row_no)
option (order);

echo both $if $equ $last[2] 2398000 "PASSED" "***FAILED";
echo both ": sum of row_no in 4 way dt, hash,loop join of r1..t1.\n";

select count (*)  from (select * from r1..t1 union select * from r1..t1) f where row_no < (select max (row_no) from t1) - 2900;
ECHO BOTH $IF $EQU $LAST[1] 999 "PASSED" "***FAILED";
ECHO BOTH ": count " $LAST[1] " count union   r1..t1, r1..t1 where row_no < max subq\n";


select count (*)  from (select * from r1..t1 intersect    select * from r1..t1) f;
ECHO BOTH $IF $EQU $LAST[1] 1000 "PASSED" "***FAILED";
ECHO BOTH ": count " $LAST[1] " count intersect  r1..t1, r1..t1\n";

select count (*)  from (select * from r1..t1 except     select * from r1..t1) f;
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
ECHO BOTH ": count " $LAST[1] " count except   r1..t1, r1..t1\n";

select count (*)  from (select * from r1..t1 union   select * from r1..t1) f;
ECHO BOTH $IF $EQU $LAST[1] 1000 "PASSED" "***FAILED";
ECHO BOTH ": count " $LAST[1] " count union r1..t1, r1..t1\n";

select top 10 a.row_no, b.row_no from r1..t1 a, (select top 1 row_no from r1..t1) b where b.row_no between f (a.row_no - 1) and f (a.row_no + 1) option (order, loop);
echo both $if $equ $rowcnt 3 "PASSED" "***FAILED";
echo both ": arrayed subq with top\n";
