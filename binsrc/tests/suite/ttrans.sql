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


-- transitive dt


echo both "SQL Transitivity\n";

create table knows (p1 int, p2 int, primary key (p1, p2))
alter index knows on knows partition (p1 int);
create index knows2 on knows (p2, p1) partition (p2 int);


explain ('select * from (select transitive t_in (1) t_out (2) t_distinct  p1, p2 from knows) k where k.p1 = 1');

explain ('select * from (select transitive t_in (1) t_out (2) t_distinct  p1, p2 from knows union select p2, p1 from knows) k where k.p1 = 1');


insert into knows values (1, 2);
insert into knows values (1, 3);
insert into knows values (2, 4);


select * from (select transitive t_in (1) t_out (2) t_distinct  p1, p2 from knows) k where k.p1 = 1;
echo both $if $equ $rowcnt 3 "PASSED" "***FAILED";
echo both ": trans lr\n";

select * from (select transitive t_in (1) t_out (2) t_distinct  p1, p2 from knows) k where k.p2 = 1;
echo both $if $equ $rowcnt 0 "PASSED" "***FAILED";
echo both ": trans lr 2\n";


select * from (select transitive t_in (1) t_out (2) t_distinct  p1, p2 from knows) k where k.p2 = 4;
echo both $if $equ $rowcnt 2 "PASSED" "***FAILED";
echo both ": trans rl\n";

-- XXX: was 1
select * from (select transitive t_in (1) t_out (2) t_distinct  p1, p2 from knows) k where p1 = 1 and p2 = 4;
echo both $if $gte $rowcnt 1 "PASSED" "***FAILED";
echo both ": trans lrrl 1\n";


select * from (select transitive t_in (1) t_out (2) t_direction 1 t_distinct  p1, p2 from knows) k where p1 = 1 and p2 = 4;
echo both $if $equ $rowcnt 1 "PASSED" "***FAILED";
echo both ": trans lrrl 2\n";

select * from (select transitive t_in (1) t_out (2) t_direction 2 t_distinct  p1, p2 from knows) k where p1 = 1 and p2 = 4;
echo both $if $equ $rowcnt 1 "PASSED" "***FAILED";
echo both ": trans lrrl 3\n";

select * from (select transitive t_in (1) t_out (2) t_direction 3 t_distinct t_shortest_only p1, p2 from knows) k where p1 = 1 and p2 = 4;
echo both $if $equ $rowcnt 1 "PASSED" "***FAILED";
echo both ": trans lrrl 4\n";

select * from (select transitive t_in (1) t_out (2) t_distinct  p1, p2 from (select p1, p2 from knows union all select p2, p1 from knows) k2) k where k.p2 = 4;
echo both $if $equ $rowcnt 3 "PASSED" "***FAILED";
echo both ": trans rl union\n";


select * from (select transitive t_in (1) t_out (2) t_direction 1 t_distinct  p1, p2, t_step (1) as via, t_step ('path_id') as path , t_step ('step_no') as step from knows) k where p1 = 1 and p2 = 4;
echo both $if $equ $rowcnt 3 "PASSED" "***FAILED";
echo both ": trans steps d1\n";

select * from (select transitive t_in (1) t_out (2) t_direction 2 t_distinct  p1, p2, t_step (1) as via, t_step ('path_id') as path , t_step ('step_no') as step from knows) k where p1 = 1 and p2 = 4;
echo both $if $equ $rowcnt 3 "PASSED" "***FAILED";
echo both ": trans steps d2\n";

select * from (select transitive t_in (1) t_out (2) t_direction 3 t_distinct t_shortest_only  p1, p2, t_step (1) as via, t_step ('path_id') as path , t_step ('step_no') as step from knows) k where p1 = 1 and p2 = 4;
echo both $if $equ $rowcnt 3 "PASSED" "***FAILED";
echo both ": trans steps d3\n";


select p2, dist, (select count (*) from knows c where c.p1 = k.p2) from (select transitive t_in (1) t_out (2) t_distinct  p1, p2,  t_step ('step_no') as dist  from knows) k where p1 = 1 order by dist, 3 desc;
echo both $if $equ $rowcnt 3 "PASSED" "***FAILED";
echo both ": trans order dist, friend count\n";

