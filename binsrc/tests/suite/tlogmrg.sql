-- tests for mt txn blob operations
set echo on;
__dbf_set ('enable_mt_txn', 1); 
__dbf_set ('qp_thread_min_usec', 0); 
__dbf_set ('dbf_explain_level', 3);

drop table tblob;
drop table tblob2;
create table tblob (id int primary key, bl long varchar);
create table tblob2 (id int primary key, bl long varchar);

create procedure tblob_fill (in n int)
{
  declare i int;
  for (i := 0; i < n; i := i + 1)
    {
      insert into tblob values (i, repeat ('xyz', 8000 + rnd (10000)));
    }
}
;

tblob_fill (10000);

set explain on;
insert into tblob2 select * from tblob;
update tblob2 set bl = subseq (bl, 0, 6000) || repeat ('abc', 100 + rnd (3000)) where exists (select 1 from tblob b where b.id = id + 100);
set explain off;

set autocommit manual;
insert into tblob2 select * from tblob;
commit work;
update tblob2 set bl = subseq (bl, 0, 6000) || repeat ('abc', 100 + rnd (3000)) where exists (select 1 from tblob b where b.id = id + 100);
commit work;
