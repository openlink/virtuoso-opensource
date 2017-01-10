--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2017 OpenLink Software
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


echo both "Any type collation, rdf boxes and ranges\n";


create table anybl (id int prim,primary key, xx long varchar);

create table anyt (id int primary key, xx long __any);

-- insert into anyt values (2, vector (22, make_string (100000)));

create procedure strs (in s varchjar, in n int)
{
  declare strs any;
 strs := string_output ();
  http (s, strs);
  http (make_string (n), strs);
  return strs;
}

-- insert into anyt values (3, strs ('qwerty', 11));


drop table arn;
create table arn (k any primary key);
insert into arn values (1);
insert into arn values (cast (1.2 as decimal));
insert into arn values (cast (1.3 as double precision));
insert into arn values ('str');
insert into arn values (stringdate ('2001-1-1'));

select * from arn where k > '' and k < 1.23;
echo both $if $equ $rowcnt 0 "PASSED" "***FAILED";
echo both ": het any 1\n";

select * from arn where k > '' and k < 'x';
echo both $if $equ $rowcnt1  "PASSED" "***FAILED";
echo both ": het any 2\n";

-- STop here, rdf boxes are not stored with content any more so the rest does not apply
exit;


insert into arn values (rdf_box (1, 257, 257, 1, 0));
echo both $if $neq $state OK "PASSED" "FAILED";
echo both ": het any unq\n";

insert into arn values (rdf_box (1.1, 257, 257, 1, 0));

insert into arn values (rdf_box ('strl', 258, 257, 1, 0));
insert into arn values (rdf_box ('stra', 259, 257, 1, 0));

select k from arn where k <= 'strl';
echo both $if $equ $rowcnt 1 "PASSED" "***FAILED";
echo both ": het any 3\n";

insert into arn values (rdf_box ('at260', 260, 257, 1, 0));
insert into arn values (rdf_box ('bt260', 260, 257, 1, 0));
insert into arn values (rdf_box ('ct260', 260, 257, 1, 0));

insert into arn values (rdf_box ('at261', 261, 257, 1, 0));
insert into arn values (rdf_box ('bt261', 261, 257, 1, 0));
insert into arn values (rdf_box ('ct261', 261, 257, 1, 0));

insert into arn values (rdf_box ('al260', 257, 260, 1, 0));
insert into arn values (rdf_box ('bl260', 257, 260, 1, 0));
insert into arn values (rdf_box ('cl260', 257, 260, 1, 0));

insert into arn values (rdf_box ('al261', 257, 261, 1, 0));
insert into arn values (rdf_box ('bl261', 257, 261, 1, 0));
insert into arn values (rdf_box ('cl261', 257, 261, 1, 0));



select k from arn where k > 'a';
echo both $if $equ $rowcnt 1 "PASSED" "***FAILED";
echo both ": het any 3\n";

select k from arn where k < rdf_box ('c', 260, 257, 1, 0);
echo both $if $equ $rowcnt 2 "PASSED" "***FAILED";
echo both ": het any 4\n";


select k from arn where k < rdf_box ('c', 257, 260, 1, 0);
echo both $if $equ $rowcnt 2 "PASSED" "***FAILED";
echo both ": het any 5\n";

select count (*) from arn a, arn b where a.k = b.k option (loop);
echo both $if $equ $last[1] 20 "PASSED" "***FAILED";
echo both ": arn x arn loop\m";

select count (*) from arn a, arn b where a.k = b.k option (hash);
echo both $if $equ $last[1] 20 "PASSED" "***FAILED";
echo both ": arn x arn hash\n";


alter table arn add d any;
update arn set d = k;

select * from arn where d > '' and d < 1.23;
echo both $if $equ $rowcnt 0 "PASSED" "***FAILED";
echo both ": het any nk 1\n";



select d from arn where d < rdf_box ('c', 257, 260, 1, 0);
echo both $if $equ $rowcnt 2 "PASSED" "***FAILED";
echo both ": het any nk 5\n";

select d from arn where d > rdf_box ('b', 257, 260, 1, 0);
echo both $if $equ $rowcnt 2 "PASSED" "***FAILED";
echo both ": het any nk 6\n";

select d from arn where d > rdf_box (1, 257, 257, 1, 0);
echo both $if $equ $rowcnt 3 "PASSED" "***FAILED";
echo both ": het any nk 7\n";
