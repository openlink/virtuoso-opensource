

create table tci (id int primary key, dt varchar);
insert into tci values (1, 'dt1');
insert into tci values (2, 'dt2');

set autocommit manual;
insert into tci values (3, 'dt3');
select * from tci where id = 2 for update;
select * from tci where id = 2 &
select * from tci where id = 2 &
select * from tci where id = 2 &

select * from tci where id = 3 &
select * from tci where id = 3 &
sleep 1;
checkpoint &
sleep 3;
commit work;

ECHO BOTH "cpt rb with multiple registered, on and beside rb'd insert\n";
