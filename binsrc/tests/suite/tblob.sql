--  
--  $Id$
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
set deadlock_retries = 10;



drop table tblob
drop table tblob2;
drop table tb_stat;

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

ECHO BOTH $IF $NEQ $SQLSTATE OK "PASSED" "***FAILED";
ECHO BOTH ": row too long check\n";
 

update tblob set b3 = '12345678901234567890';
update tblob set b1 = b3, b2 = b3, b4 = b3;
ECHO BOTH $IF $NEQ $SQLSTATE OK "PASSED" "***FAILED";
ECHO BOTH ": row too long check 2\n";

update tblob set e1 = '123';
ECHO BOTH $IF $NEQ $SQLSTATE OK "PASSED" "***FAILED";
ECHO BOTH ": row too long check 3\n";

update tblob set e2 = make_string (4000);
ECHO BOTH $IF $NEQ $SQLSTATE OK "PASSED" "***FAILED";
ECHO BOTH ": row too long check 4\n";

update tblob set e2 = '1234';

insert into tblob (k, b1, b2, b3) values (2, make_string (1000), make_string (900), make_string (800));



update tblob set b1 = make_string (100), b2 = make_string (200), b3 = make_string (1900), e1 = 'e1-';
update tblob set en = make_string (1900);
update tblob set en = 'en';


delete from tblob2;
insert into tblob2 (k, b1) select k, b3 from tblob where k = 1;


create procedure make_random_wide_string () returns nvarchar
  {
    declare wide_len integer;
    declare wide_ret nvarchar;

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
	e1 = make_string (rnd (1004)),
	e2 = make_string (rnd (1005));
    i := i + 1;
    -- dbg_obj_print (len);
    if (rnd (10) = 1 and mode <> 'rb')
      commit work;
    else if (rnd (10) = 1 and mode <> 'co')
      rollback work;

  }
  if (mode = 'rb')
    rollback work;
}


ECHO BOTH "starting blob random update ...\n";
tb_upd (2000, '');
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": blob random update " $STATE "\n";


insert into tb_stat select k, length (b1), length (b2), length (b3), length (b4), e1, e2 from tblob;


create procedure tb_check (in q integer)
{
  if (exists (select 1 from tblob b where not exists (select 1 from tb_stat c where c.k = b.k
						      and length (b1) = b1_l and length (b2) = b2_l and length (b3) = b3_l
						      and length (b4) = b4_l and b. e1 = c. e1 and b. e2 = c. e2)))
    signal ('BLFWD', 'Bad blob roll forward');
}



tb_check (1);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": blobs rollback / roll forward consistency " $STATE "\n";



ECHO BOTH "starting blob random update ...\n";
tb_upd (2000 , 'rb');
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": rollback blob random update " $STATE "\n";

tb_check (1);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ":  blob check after 2000 rollbacks " $STATE "\n";




-- Bad inserts and updates - should not affect state in table.

insert into tblob (k, b1, b2, b3, e1, e2) values (3, make_string (1000), make_string (1900), make_string (800),
						  make_string (1000), make_string (3200));
update tblob set b1 = make_string (3000), ed = '--';

update tblob set b1 = make_string (2000), ed = 'qq';

tb_check (1);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": blobs rollback / roll forward consistency " $STATE "\n";


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
    select length (_ROW) into len from tblob;
    -- dbg_obj_print (len);
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


ECHO BOTH "starting blob random insert ...\n";
tb_ins (1000, '');
ECHO BOTH "finished blob random insert\n";

select * from tblob where length (blob_to_string (b4)) <> length (b4);
ECHO BOTH $IF $EQU $ROWCNT 0 "PASSED" "***FAILED";
ECHO BOTH ": tblob length check\n";


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

foreach blob in words.esp update tblob set b1 = ?, b2 = '', b3 = '', b4 = '', e1 = '', e2 = ''  where k between 10000 and 10010;


-- subseq done in cluster 
select subseq (b1, 10000, 10500) from tblob where k > 9999;
ECHO BOTH $IF $EQU $ROWCNT 8 "PASSED" "***FAILED";
ECHO BOTH ": b subseq 1\n";
-- subseq in cluster with sql func, then subseq done in coordinator. id_to_iri is a location sequence break. 
create procedure f (in q any) {return q;};
create procedure f_noloc (in q any) { id_to_iri (#i1); return q;};


select subseq (f (b1), 10000, 10500) from tblob where k > 9999;
ECHO BOTH $IF $EQU $ROWCNT 8 "PASSED" "***FAILED";
ECHO BOTH ": b subseq 2\n";


select subseq (f_noloc (b1), 10000, 10100) from tblob where k > 9999;
ECHO BOTH $IF $EQU $ROWCNT 8 "PASSED" "***FAILED";
ECHO BOTH ": b subseq 3\n";


-- master to c2
update tblob set k = 11001 where k = 10000;
-- c2 to c3
update tblob set k = 11002 where k = 10001;

-- c4 to master
update tblob set k = 11000 where k = 10003;

load clexpck.sql;
select explain_check ('select length (blob_to_string (bl)) from (select b1 as bl from tblob order by -k) f', 'cl fref read');
ECHO BOTH $IF $EQU $SQLSTATE OK "PASSED" "***FAILED";
ECHO BOTH ": blob sort compilation\n";

select length (blob_to_string (bl)) from (select b1 as bl from tblob order by -k) f;





delete from tb_stat;
insert into tb_stat select k, length (b1), length (b2), length (b3), length (b4), e1, e2 from tblob;

tb_check (1);
ECHO BOTH $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": tblob insert check " $STATE "\n";

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
ECHO BOTH $IF $EQU $LAST[1] 20000000 "PASSED"  "***FAILED";
ECHO BOTH ": replicated ins replacing of large blob\n";

cl_exec ('backup ''/dev/null''');
