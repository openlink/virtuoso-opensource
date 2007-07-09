


create table bint (bi bigint, i int, primary key (bi, i));

insert into bint values ('5000000000', 11);

insert into bint values (1000000 * 1000000, 12);

select * from bint a, bint b where a.bi = b.bi option (hash);
echo both $if $equ $rowcnt 2 "PASSED" "***FAILED";
echo both ": hash join of bigint\n";

select * from bint order by bi + 1;
echo both $if $equ $rowcnt 2 "PASSED" "***FAILED";
echo both ": oby bigint col\n";


select * from bint order by i + 10000000000;
echo both $if $equ $rowcnt 2 "PASSED" "***FAILED";
echo both ": oby large int exp\n";
