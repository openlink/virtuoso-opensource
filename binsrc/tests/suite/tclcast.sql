



create table ot (o any primary key);
alter index ot on ot partition (o varchar (-1, 0hexffff));

insert into ot values (22);
insert into ot values (cast (22 as decimal));
insert into ot values (rdf_box (cast (22 as decimal), 257, 257, 0, 1));


insert into ot values (stringdate ('2001-1-1'));
insert into ot values (rdf_box (stringdate ('2001-1-1'), 257, 257, 0, 1));

select * from ot;
echo both $if $equ $rowcnt 2 "PASSED" "***FAILED";
echo both ": rows in ot after non-unq inserts with different dtps and rdf boxes\n";


