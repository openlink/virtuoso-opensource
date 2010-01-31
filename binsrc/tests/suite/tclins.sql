

-- replacing and soft inserts in cluster 

echo both "Cluster insert replacing and soft\n";
drop table ko;
drop table kd;

create table ko (k1 int, k2 int, primary key (k1, k2));
alter index ko on ko partition (k1  int);
create index ko2 on ko (k2, k1) partition (k2 int);

create table kd (k1 int, ku int,nu int, primary key (k1));
alter index kd on kd partition (k1 int);
create unique index ku on kd (ku) partition (ku int);
create index nu on kd (nu) partition (nu int);


insert into kd values (4, 5, 6);
insert into kd values (5, 6, 7);
insert into kd values (6, 7, 8);

insert replacing kd select * from kd;
insert soft kd select * from kd;

insert soft kd select k1 + 1, ku + 1, nu + 1 from kd where k1 < 7;

select * from kd;
echo both $if $equ $last[1] 7 "PASSED" "***FAILED";
echo both ": ins repl + soft no1\n";


set autocommit manual;
insert replacing kd values (4, 6, 7);
echo both $if $neq $sqlstate OK "PASSED" "***FAILED";
echo both ": non unq 2nd in ins repl\n";

rollback work;
set autocommit off;

insert replacing kd values (5, 7, 8);
echo both $if $neq $sqlstate OK "PASSED" "***FAILED";
echo both ": non unq 2nd in ins repl 2\n";

rollback work;
insert replacing kd values (4, 10, 11);

select * from kd where k1 = 4;
echo both $if $equ $last[3] 11 "PASSED" "***FAILED";
echo both ": ins repl ok\n";


insert soft kd values (5, 10, 11);
select * from kd where k1 = 5;
echo both $if $equ $last[3] 7 "PASSED" "***FAILED";
echo both ": ins soft ok\n";
