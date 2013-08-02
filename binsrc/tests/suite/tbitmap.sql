echo both "Bitmap index tests\n";

select sys_stat ('db_default_columnstore');
set U{COLUMNSTORE} $LAST[1];

drop table tb;
create table tb (id int primary key, k1 int, k2 int);

create bitmap index k1 on tb (k1);

create procedure bmck (in n int := 0)
{
  if ((select count (*) from tb table option (index tb)) <> (select count (*) from tb table option (index k1)))
	signal  ('BMFUP', sprintf ('bm inx out of whack %d', n));
}

create procedure bins (in bk int, in start int, in n int, in step int)
{
  declare x, ctr int;
  x := start;
  for (ctr := 0; ctr < n; ctr := ctr + 1)
    {
      insert into tb (id, k1, k2) values (x, bk, 1);
      x := x + step;
    }
}

create procedure bdel (in bk int, in start int, in n int, in step int)
{
  declare x, ctr int;
  x := start;
  for (ctr := 0; ctr < n; ctr := ctr + 1)
    {
      delete from tb where id = x;
      x := x + step;
    }
}

insert into tb values (10, 11, 0);
insert into tb values (9, 11, 0);

select id from tb table option (index k1) where k1 = 11;

select id from tb table option (index k1) where k1 = 11 order by id desc;

insert into tb values (300000000, 11, 0);

insert into tb values (20000, 12, 0);
insert into tb values (1000000, 12, 0);
insert into tb values (1000001, 14, 0);
insert into tb values (3000000, 13, 0);


bmck (0);

bins (12, start => 30000, n => 600, step => 10);
bins (12, start => 30001, n => 600, step => 10);
insert into tb values (10000, 12, 0);

bmck (1);

bins (12, start => 60001, n => 100, step => 10);
bins (12, start => 82000, n => 512, step => 1);

bmck (2);

select count (id) from tb table option (index k1) where k1 = 12;
select count (id) from tb table option (index primary key) where k1 = 12;


select * from tb table option (index k1) where k1 = 12 and id = 32800;

select count (*) from tb a table option (index primary key) where exists (select 1 from tb b table option (index k1) where a.id = b.id and a.k1 = b.k1);

select top 5 * from tb table option (index k1) where id < 15000 and k1 = 12 order by id desc;
select top 5 * from tb table option (index k1) where id > 15000 and k1 = 12 order by id desc;

bmck (3);

select top 5 * from tb table option (index k1) where   id > 32900 and id < 82003 and k1 = 12 order by id desc;
select top 5 * from tb table option (index k1) where   id > 32900 and id < 82003 and k1 = 12 order by id;

select top 5 * from tb table option (index k1) where id < 32800 and k1 = 12 order by id desc;
select top 5000  * from tb table option (index k1) where   id > 32900 and id < 82003 and k1 = 12 order by id desc;
echo both $if $equ $rowcnt 722 "PASSED" "***FAILED";
echo both ": asc order bm range\n";

select top 5000  * from tb table option (index k1) where   id > 32900 and id < 33000 and k1 = 12 order by id desc;


select top 5000  * from tb table option (index k1) where   id > 32900 and id < 82003 and k1 = 12 order by id;
echo both $if $equ $rowcnt 722 "PASSED" "***FAILED";
echo both ": desc order bm range\n";

select id, k1 from tb a table option (index primary  key) where  not exists (select 1 from tb b table option (index k1) where b.k1 = a.k1 and b.id > a.id);

--select id, k1, (select b.id from tb b table option (index k1) where b.k1 = a.k1 and b.id < a.id order by b.id desc)
--from tb a table option (index primary  key);

--*** 2 below do not work because desc bitmap inx is not done in ectored exec
select id, k1, (select b.id from tb b table option (index k1) where b.k1 = a.k1 and b.id < a.id order by b.id desc)
from tb a table option (index primary  key) 
where id - 1 <> (select b.id from tb b table option (index k1) where b.k1 = a.k1 and b.id < a.id order by b.id desc);
--echo both $if $equ $rowcnt 704 "PASSED" "***FAILED";
-- echoln both ": bm select of previous in desc order with lt" $rowcnt 704 "\n";

select id, k1, (select b.id from tb b table option (index k1) where b.k1 = a.k1 and b.id < a.id order by b.id + 0 desc)
from tb a table option (index primary  key) 
where id - 1 <> (select b.id from tb b table option (index k1) where b.k1 = a.k1 and b.id < a.id order by b.id + 0 desc);
--echo both $if $equ $rowcnt 704 "PASSED" "***FAILED";
--echo both ": bm select of previous in desc order with lt sorted desc oby\n";

#if $NEQ $U{COLUMNSTORE} 1
select id, k1, (select b.id from tb b table option (index primary key) where b.k1 = a.k1 and b.id < a.id order by b.id desc)
from tb a table option (index primary  key) 
where id - 1 <> (select b.id from tb b table option (index primary key) where b.k1 = a.k1 and b.id < a.id order by b.id desc);
--XXX echo both $if $equ $rowcnt 704 "PASSED" "***FAILED";
--echo both ": bm select of previous in desc order with lt : double check with pk\n";
#endif

select id, k1 from tb a table option (index primary  key) where   id - 1 <> (select b.id from tb b table option (index k1) where b.k1 = a.k1 and b.id <= a.id - 1 order by b.id desc);
--XXX echo both $if $equ $rowcnt 704 "PASSED" "***FAILED";
--echo both ": bm select of previous in desc order with lte\n";

select id, k1 from tb a table option (index primary  key) where   id + 1 <> (select b.id from tb b table option (index k1) where b.k1 = a.k1 and b.id > a.id order by b.id);
echo both $if $equ $rowcnt 704 "PASSED" "***FAILED";
echo both ": bm select of next in  order with gt\n";


bmck (4);

select id, k1 from tb a table option (index primary  key) where   id + 1 <> (select b.id from tb b table option (index k1) where b.k1 = a.k1 and b.id >= a.id + 1 and b.id < a.id + 10  order by b.id);
echo both $if $equ $rowcnt 599 "PASSED" "***FAILED";
echo both ": bm select of next in  order with gte and range\n";


select top 10 id, k1 from tb a table option (index primary  key) where   id + 1 <> (select b.id from tb b table option (index k1) where b.k1 = a.k1 and b.id >= a.id + 1 and b.id < a.id + 2100000    order by b.id);
echo both $if $equ $last[1] 30071 "PASSED" "***FAILED";
echo both ": last of select next in bm order with range.\n";

select top 10 id, k1 from tb a table option (index primary  key) where   id + 1 <> (select b.id from tb b table option (index k1) where b.k1 = a.k1 and b.id >= a.id + 1     order by b.id);
echo both $if $equ $last[1] 30061 "PASSED" "***FAILED";
echo both ": last of select next in bm order.\n";

bmck (5);


set autocommit manual;
delete from tb;
rollback work;

bmck (6);

update tb set k1 = 20;
select distinct k1 from tb table option (index k1);
echo both $if $equ $rowcnt 1 "PASSED" "***FAILED";
echo both ": distinct k1 after update.\n";

bmck (7);
rollback work;

bmck (9);
select distinct k1 from tb table option (index k1);

--echo both $if $equ $rowcnt 4 "PASSED" "***FAILED";
--echo both ": distinct k1 after rollback.\n";

set autocommit off;

explain ('select count (id) from tb table option (index k1) where id = 30010 and k1 = 12', -5);

create procedure tb1 ()
{
  declare n int;
  declare cr cursor for select id from tb where k1 = 12 and id > 30002;
  open cr;
  fetch cr into n;
  if (n <> 30010) sigmal ('TB001','');
  delete from tb where k1 = 12 and id = 30010;
  fetch cr into n;
  if (n <> 30011) signal ('TB002', '');
  rollback work;
}

tb1();
echo both $if $equ  $sqlstate OK "PASSED" "***FAILED";
echo both ": bm inx cursor maint over delete\n";

create procedure tb2 ()
{
  declare n int;
  declare cr cursor for select id from tb where k1 = 20 and id < 60000 order by id desc;
  bins (20, start => 17000, n => 400, step => 2);
  bins (20, start => 50000, n => 50, step => 2);
  open cr;
  fetch cr into n;
  if (n <> 50098) signal ('TB003', '');
  bins (20, start => 50001, n => 500, step => 2);
  -- the row splitcs and the upper ce becomes bitmap from array ;
  fetch cr into n;
  if (n <> 50097) signal ('TB004', '');
  rollback work;
}

--tb2();
echo both $if $equ  $sqlstate OK "PASSED" "***FAILED";
echo both ": bm inx cursor maint over bm row split\n";

bins (100,1024000, 511, 2);
bins (100,1024000 + 9000, 1, 2);
echo both $if $equ $sqlstate OK "PASSED" "***FAILED";
echo both ": ins at end of one less than full array\n";

bins (100,1024000 + 8000, 1, 2);
echo both $if $equ $sqlstate OK "PASSED" "***FAILED";
echo both ": ins at end of one less than full array 2\n";

bmck (10);

select count (*) from tb where k1 = 100;
echo both $if $equ $last[1] 513 "PASSED" "***FAILED";
echo both ": rows w k1 100\n";

bmck (11);

-- delete on bitmap index
drop table bmdel;
create table bmdel (id1 int, id2 int, id3 int, primary key (id1, id2, id3));
create bitmap index bminx on bmdel (id3, id1, id2);
insert into bmdel values (1,1,1);
insert into bmdel values (2,5,1);
insert into bmdel values (3,3,1);
select * from bmdel;
echo both $if $equ $rowcnt 3 "PASSED" "***FAILED";
echo both " table with bitmap contains " $rowcnt " rows\n";
delete from bmdel where id3 = 1;
select * from bmdel;
echo both $if $equ $rowcnt 0 "PASSED" "***FAILED";
echo both " after delete on bitmap index table contains " $rowcnt " rows\n";

bmck (12);

update tb set k1 = (select min (id) from tb);

bmck (13);

set autocommit manual;
update tb set k1 = id;
bmck (14);
rollback work;

bmck (15);

set autocommit manual;
update tb set k1 = id;
bmck (16);
update tb set k1 = 9;
bmck (17);
rollback work;

bmck (18);
-- XXX
--echo both $if $equ $sqlstate OK "PASSED" "***FAILED";
--echo both ": bm and pk consistency\n";

-- Now for deletes at end of page 
#if $NEQ $U{COLUMNSTORE} 1

delete from tb;
bins (10, 100, 100, 1);
bins (11, 100, 102, 1);
bins (12, 100, 102, 1);
insert into tb (id, k1) values (5000, 10);
echoln both $if $equ $ROWCNT 1 "PASSED" "***FAILED" ": row with id = 5000 inserted. STATE=" $STATE " MESSAGE=" $MESSAGE;

delete from  tb where id = 5000;
echoln both $if $equ $ROWCNT 1 "PASSED" "***FAILED" ": row with id = 5000 deleted. STATE=" $STATE " MESSAGE=" $MESSAGE;

select id from tb where id = 5000;
echoln both $if $equ $ROWCNT 0 "PASSED" "***FAILED" ": row with id = 5000 is not present.";

insert into tb (id, k1) values (10000, 10);
echoln both $if $equ $ROWCNT 1 "PASSED" "***FAILED" ": row with id = 10000 inserted. STATE=" $STATE " MESSAGE=" $MESSAGE;

delete from  tb where id = 10000;
echoln both $if $equ $ROWCNT 1 "PASSED" "***FAILED" ": row with id = 10000 deleted. STATE=" $STATE " MESSAGE=" $MESSAGE;

select id from tb where id = 10000;
echoln both $if $equ $ROWCNT 0 "PASSED" "***FAILED" ": row with id = 10000 is not present.";

#endif
