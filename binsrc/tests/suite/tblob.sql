--
--  $Id: tblob.sql,v 1.13.6.10.4.7 2013/01/02 16:14:59 source Exp $
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
set deadlock_retries = 10;
set echo on;

select sys_stat ('db_default_columnstore');
set U{COLUMNSTORE} $LAST[1];

drop table tblob
drop table tblob2;
drop table tb_stat;
drop table twide;
drop table twide_stat;

create table TBLOB (k integer not null primary key,
            b1 long varchar,
            b2 long varchar,
            b3 long varbinary,
            b4 long nvarchar,
            e1 varchar,
            e2 varchar,
            en varchar,
            ed datetime)
alter index TBLOB on TBLOB partition (k int);


create table twide (wk nvarchar, wka any,  primary key (wk, wka), wd nvarchar, wda any, k int);
alter index twide on twide partition (wk varchar);

create table twide_stat (k int primary key, wk_len int, wka_len int, wd_len int, wda_len int);
alter index twide_stat on twide_stat partition (k int);

create index TB1 on TBLOB (e1) partition (e1 varchar);


create table tblob2 (k integer not null primary key, b1 varchar, b2 varchar)
alter index tblob2 on tblob2 partition (k int);

create table tb_stat (k integer not null primary key,
             b1_l integer, b2_l integer, b3_l integer, b4_l integer,
             e1 varchar, e2 varchar)
alter index tb_stat on tb_stat partition (k int);


insert into tblob (k, e1, e2) values (1, 'e1', 'e2');

create procedure tb_e2 ()
{
  declare ct int;
  ct := 3000;
  while (1)
    {
      update tblob set e2 = make_string (ct);
      commit work;
      ct := ct + 1;
    }
}

tb_e2 ();

echo both $if $neq $sqlstate OK "PASSED" "***FAILED";
echo both ": row too long check\n";
 

update tblob set b3 = '12345678901234567890';
update tblob set b1 = b3, b2 = b3, b4 = b3;
#if $EQU $U{COLUMNSTORE} 1
    echo both $if $equ $sqlstate OK "PASSED" "***FAILED";
    echo both ": row too long check 2\n";
#else
    echo both $if $neq $sqlstate OK "PASSED" "***FAILED";
    echo both ": row too long check 2\n";
#endif

update tblob set e1 = '123';
#if $EQU $U{COLUMNSTORE} 1
	echo both $if $equ $sqlstate OK "PASSED" "***FAILED";
	echo both ": row too long check 3\n";
#else
	echo both $if $neq $sqlstate OK "PASSED" "***FAILED";
	echo both ": row too long check 3\n";
#endif

update tblob set e2 = make_string (4000);
#if $EQU $U{COLUMNSTORE} 1
    echo both $if $equ $sqlstate OK "PASSED" "***FAILED";
    echo both ": row too long check 4\n";
#else
    echo both $if $neq $sqlstate OK "PASSED" "***FAILED";
    echo both ": row too long check 4\n";
#endif

update tblob set e2 = '1234';

insert into tblob (k, b1, b2, b3) values (2, make_string (1000), make_string (900), make_string (800));


update tblob set b1 = make_string (100), b2 = make_string (200), b3 = make_string (1900), e1 = 'e1-';
update tblob set en = make_string (1900);
update tblob set en = 'en';


delete from tblob2;
insert into tblob2 (k, b1) select k, b3 from tblob where k = 1;


create procedure make_random_wide_string (in maxlen int := null) returns nvarchar
{
  declare wide_len integer;
  declare wide_ret nvarchar;
  if (maxlen is not null)
    wide_len := rnd (maxlen);
  else
    wide_len := case rnd (500) when 144 then 1600000 else 2000 end;

  wide_ret := make_wstring (wide_len);
  for (declare _inx integer, _inx := 0; _inx < wide_len; _inx := _inx + 1)
    {
      declare _char_range integer;
      _char_range := rnd (10) + 1;
      wide_ret [_inx] :=
    case
    when _char_range between 1 and 2
    then (rnd (255) + 1)
    when _char_range between 3 and 7
    then (rnd (10000 - 256) + 256)
    when _char_range between 8 and 10
    then (rnd (1000000000 - 10000) + 10000)
    end;
    }
  return wide_ret;
}


create procedure tb_upd (in ct integer, in mode varchar)
{
  declare deadlock_retry_count integer;

  deadlock_retry_count := 100;
  declare exit handler for sqlstate '40001'
    {
      rollback work;
      if (deadlock_retry_count > 0)
    {
      deadlock_retry_count := deadlock_retry_count - 1;
      goto again;
    }
      else
    resignal;
    };

again:
  declare i, len integer;
  i := 0;
  while (i < ct) 
    {
      update tblob set b1 = make_string (rnd (1000)),
    b2 = make_string (rnd (1001)),
    b3 = make_string (rnd (1003)),
    b4 = make_random_wide_string (),
    --e1 = make_random_wide_string (1500), 
    e1 = make_string (rnd (1004)),
    e2 = make_string (rnd (1005));
      i := i + 1;
      -- dbg_obj_print (len);
  if (mode = 'coa')
    commit work;
      else if (rnd (10) = 1 and mode <> 'rb')
    commit work;
      else if (rnd (10) = 1 and mode <> 'co')
    rollback work;
    }
  if (mode = 'rb')
    rollback work;
}


echo both "starting blob random update ...\n";
tb_upd (2000, '');
echo both $if $equ $state OK "PASSED" "***FAILED";
echo both ": blob random update " $state "\n";

create procedure record_tb ()
{
  delete from tb_stat;
  insert into tb_stat select k, length (b1), length (b2), length (b3), length (b4), e1, e2 from tblob;
}


create procedure tb_check (in q integer := null)
{
  if (exists (select 1 from tblob b where not exists (select 1 from tb_stat c where c.k = b.k
                              and length (b1) = b1_l and length (b2) = b2_l and length (b3) = b3_l
                              and length (b4) = b4_l and b. e1 = c. e1 and b. e2 = c. e2)))
    signal ('BLFWD', 'Bad blob roll forward');
}


record_tb ();
tb_check (1);
echo both $if $equ $state OK "PASSED" "***FAILED";
echo both ": blobs rollback / roll forward consistency " $state "\n";



echo both "starting blob random update ...\n";
tb_upd (2000 , 'rb');
echo both $if $equ $state OK "PASSED" "***FAILED";
echo both ": rollback blob random update " $state "\n";

tb_check (1);
echo both $if $equ $state OK "PASSED" "***FAILED";
echo both ":  blob check after 2000 rollbacks " $state "\n";




-- Bad inserts and updates - should not affect state in table.
#if $NEQ $U{COLUMNSTORE} 1

insert into tblob (k, b1, b2, b3, e1, e2) values (3, make_string (1000), make_string (1900), make_string (800),
  make_string (1000), make_string (3200));
#endif

update tblob set b1 = make_string (3000), ed = '--';

update tblob set b1 = make_string (2000), ed = 'qq';

tb_check (1);
echo both $if $equ $state OK "PASSED" "***FAILED";
echo both ": blobs rollback / roll forward consistency " $state "\n";


create procedure tb_ins (in ct integer, in mode varchar)
{
  declare i, len integer;
  i := 0;
  while (i < ct) {
    insert into tblob (k, b1, b2, b3, e1, e2, b4)
      values (i + 10, make_string (rnd (1000)), make_string (rnd (1000)),
          make_string (rnd (1000)), make_string (rnd (1000)), make_string (rnd (1000)),
          make_random_wide_string ());
    i := i + 1;
    if (rnd (10) = 1 and mode <> 'rb')
      commit work;
    else if (rnd (10) = 1 and mode <> 'co')
      rollback work;

  }
  if (mode = 'rb')
    rollback work;
}


create procedure no_error (in txt varchar)
{
  declare err, msg varchar;
  exec (txt, err, msg, vector (), 0, NULL, NULL);
}



create procedure bad_ins_1 (in q integer)
{
  no_error ('insert into tblob (k, b1) values (1, make_string (10000))');
  no_error ('insert into tblob (k, b1) values (1111, make_string (20000))');
}


bad_ins_1 (1);

create procedure bad_upd_1 (in q integer)
{
  insert into tblob (k, b1) values (1111, make_string (10000));
  update tblob set k = 1, b2 = b1 where k = 1111;
}

--XXX: VJ
--bad_upd_1 (1);


echo both "starting blob random insert ...\n";
tb_ins (1000, '');
echo both "finished blob random insert\n";

create procedure fill_twide ()
{
  declare ctr, len int;
  for (ctr := 0; ctr < 1000; ctr := ctr + 1)
    { 
    len := case when rnd (10) = 0 then 3 when  rnd (10) = 2 then 4 else 260 end;
      insert replacing  twide (wk, wka, wd, wda, k) values (make_random_wide_string (len), make_random_wide_string (len), make_random_wide_string (len), make_random_wide_string (len), ctr); 
    }
}


create procedure record_twide ()
{
  delete from twide_stat;
  insert into twide_stat select k, length (wk), length (wka), length (wd), length (wda) from twide;
}

create procedure check_twide ()
{
  declare badinx, badlen int;
  badinx := (select count (*) from tblob where length (blob_to_string (b4)) <> length (b4));
 badlen := (select count (*) from twide a where not exists (select 1 from twide_stat b where b.k = a.k and wd_len = length (wd) and wda_len = length (wda) and wk_len = length (wk) and wka_len = length (wka)));
  if (badinx) signal ('TWOOW', 'twide out of order');
  if (badlen) signal ('TWLEN', 'twide length wrong');
}
 

fill_twide ();

select top 10 * from twide a where not exists (select 1 from twide b table option (hash) where a.wk = b.wk and a.wka = b.wka);
echo both $if $equ $rowcnt 0  "PASSED" "***FAILED";
echo both ":  twide consistent by hash\n";

select top 10 * from twide a where not exists (select 1 from twide b table option (loop) where a.wk = b.wk and a.wka = b.wka);
echo both $if $equ $rowcnt 0  "PASSED" "***FAILED";
echo both ":  twide consistent by index\n";


record_twide ();
check_twide ();
echo both $if $equ $sqlstate OK "PASSED" "***FAILED";
echo both ": twide check 1 " $state "\n";;

delete from twide where k between 200 and 220;
update twide set wd = make_random_wide_string (length (wd)), wda = make_random_wide_string (length (wda)) where k between 300 and 330;
record_twide ();
check_twide ();
echo both $if $equ $sqlstate OK "PASSED" "***FAILED";
echo both ": twide check 2 " $state "\n";;

set autocommit manual;
update twide set wd = make_random_wide_string (length (wd)), wda = make_random_wide_string (length (wda)) where k between 100 and 330;
record_twide ();
check_twide ();
echo both $if $equ $sqlstate OK "PASSED" "***FAILED";
echo both ": twide uncommitted check  " $state "\n";;

rollback work;
set autocommit off;

check_twide ();
echo both $if $equ $sqlstate OK "PASSED" "***FAILED";
echo both ": twide rollback check  " $state "\n";;




select * from tblob where length (blob_to_string (b4)) <> length (b4);
echo both $if $equ $rowcnt 0 "PASSED" "***FAILED";
echo both ": tblob length check\n";


cl_exec ('__dbf_set (''dbf_cl_blob_autosend_limit'', 100000)');

-- 2 blobs per cluster node

foreach blob in words.esp insert into tblob (k, b1) values (10000, ?);
foreach blob in words.esp insert into tblob (k, b1) values (10001, ?);
foreach blob in words.esp insert into tblob (k, b1) values (10002, ?);
foreach blob in words.esp insert into tblob (k, b1) values (10003, ?);
foreach blob in words.esp insert into tblob (k, b1) values (10004, ?);
foreach blob in words.esp insert into tblob (k, b1) values (10005, ?);
foreach blob in words.esp insert into tblob (k, b1) values (10006, ?);
foreach blob in words.esp insert into tblob (k, b1) values (10007, ?);


foreach blob in words.esp update tblob set b1 = ? where k = 10000;
foreach blob in words.esp update tblob set b1 = ? where k = 10001;
foreach blob in words.esp update tblob set b1 = ? where k = 10002 and cl_idn (1, e1) = 1;

foreach blob in words.esp update tblob set b1 = ?, b2 = '', b3 = '', b4 = '', e1 = '', e2 = ''  where k between 10000 and 10010;


-- subseq done in cluster 
select subseq (b1, 10000, 10500) from tblob where k > 9999;
echo both $if $equ $rowcnt 8 "PASSED" "***FAILED";
echo both ": b subseq 1\n";
-- subseq in cluster with sql func, then subseq done in coordinator. id_to_iri is a location sequence break. 
create procedure f (in q any) {return q;};
create procedure f_noloc (in q any) { cl_idn (1); return q;};


select subseq (f (b1), 10000, 10500) from tblob where k > 9999;
echo both $if $equ $rowcnt 8 "PASSED" "***FAILED";
echo both ": b subseq 2\n";


select subseq (f_noloc (b1), 10000, 10100) from tblob where k > 9999;
echo both $if $equ $rowcnt 8 "PASSED" "***FAILED";
echo both ": b subseq 3\n";


-- master to c2
update tblob set k = 11001 where k = 10000;
-- c2 to c3
update tblob set k = 11002 where k = 10001;

-- c4 to master
update tblob set k = 11000 where k = 10003;

load clexpck.sql;
select explain_check ('select length (blob_to_string (bl)) from (select b1 as bl from tblob order by -k) f', 'cl fref read');
echo both $if $equ $sqlstate OK "PASSED" "***FAILED";
echo both ": blob sort compilation\n";

select length (blob_to_string (bl)) from (select b1 as bl from tblob order by -k) f;

select k, length (blob_to_string (bl)) from (select k, concat ('pfaal-', cast (b1 as varchar)) as bl long varchar  from tblob order by -k) f;




record_tb ();

tb_check (1);
echo both $if $equ $state OK "PASSED" "***FAILED";
echo both ": tblob insert check " $state "\n";

create table rep_blob (id int primary key, b long varchar);
alter index rep_blob on rep_blob partition cluster replicated;

create procedure large_repl () 
{ 
  declare strs any;
 strs := string_output (); 
  http (make_string (10000000), strs);
  http (make_string (10000000), strs); 
  insert replacing rep_blob values (1, strs);
}

large_repl ();
large_repl ();
select length (b) from rep_blob;
echo both $if $equ $last[1] 20000000 "PASSED"  "***FAILED";
echo both ": replicated ins replacing of large blob\n";

cl_exec ('backup ''/dev/null''');



create table tainc (ainc int identity (start with 10, increment by  10), ts timestamp, d varchar);

insert into tainc (d) values ('a1');
insert into tainc (d) values ('a2');
insert into tainc (d) values ('a3');

create table tainc_ck (ainc int, ts datetime, d varchar);

insert into tainc_ck select * from tainc;





