--
--  tpkopt.sql
--
--  $Id: tpkopt.sql,v 1.11.6.1.4.2 2013/01/02 16:15:17 source Exp $
--
--  Test primary keys
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

drop table idt;

create table idt (k1 integer, k2 integer, k3 integer,  d varchar);
create index ni1 on idt (d, k3, k2);
create index ni2 on idt (d);
create unique index prime on idt (k1, k2, k3);
create unique index unq2 on idt (k2, k1);

columns IDT;
echo both $if $equ $rowcnt 4 "PASSED" "***FAILED";
echo both ": column count of idt\n";

statistics IDT;
echo both $if $equ $rowcnt 10 "PASSED" "***FAILED";
echo both ": column count of idt\n";

-- select key_id, key_name, kp_nth, column  from sys_keys, sys_key_parts, sys_cols where key_table = 'DB.DBA.IDT' and kp_key_id = key_id and col_id = kp_col;

-- select key_id, key_name, key_decl_parts, key_n_significant from sys_keys where key_table = 'DB.DBA.IDT';

insert into idt (k1, k2, k3, d) values (1, 2, 3, 'd1');
insert into idt (k1, k2, k3, d) values (1, 2, 3, 'e1');
echo both $if $equ $state 23000 "PASSED" "***FAILED";
echo both ": non unq prime key state " $state "\n";

insert into idt (k1, k2, k3, d) values (1, 2, 3, 'd1');
echo both $if $equ $state 23000 "PASSED" "***FAILED";
echo both ": non unq prime key state " $state "\n";

insert into idt (k1, k2, k3, d) values (1, 2, 4, 'd1');
echo both $if $equ $state 23000 "PASSED" "***FAILED";
echo both ": non unq unique key state " $state "\n";


insert into idt (k1, k2, k3, d) values (1, 3, 3, 'd1');

insert into idt (k1, k2, k3, d) values (1, 4, 3, 'd1');
insert into idt (k1, k2, k3, d) values (4, 2, 3, 'd1');

select count (*) from idt order by k3;
echo both $if $equ $last[1] 4 "PASSED" "***FAILED";
echo both ": " $last[1] " rows in idt\n";

select count (*) from idt order by k2, k1;
echo both $if $equ $last[1] 4 "PASSED" "***FAILED";
echo both ": " $last[1] " rows in idt\n";

select count (*) from idt order by d desc;
echo both $if $equ $last[1] 4 "PASSED" "***FAILED";
echo both ": " $last[1] " rows in idt\n";

select count (*) from idt;
echo both $if $equ $last[1] 4 "PASSED" "***FAILED";
echo both ": " $last[1] " rows in idt\n";

delete from idt;

select count (*) from idt;
echo both $if $equ $last[1] 0 "PASSED" "***FAILED";
echo both ": " $last[1] " rows in idt\n";

insert into idt (k1, k2, k3, d) values (1, 2, 3, 'd1');
insert into idt (k1, k2, k3, d) values (1, 2, 3, 'e1');
echo both $if $equ $state 23000 "PASSED" "***FAILED";
echo both ": non unq prime key state " $state "\n";

insert into idt (k1, k2, k3, d) values (1, 2, 3, 'd1');
echo both $if $equ $state 23000 "PASSED" "***FAILED";
echo both ": non unq prime key state " $state "\n";

insert into idt (k1, k2, k3, d) values (1, 2, 4, 'd1');
insert into idt (k1, k2, k3, d) values (1, 3, 3, 'd1');

insert into idt (k1, k2, k3, d) values (1, 4, 3, 'd1');
insert into idt (k1, k2, k3, d) values (4, 2, 3, 'd1');

-- XXX: was 23000 error check, but cluster gives another error
create unique index d on idt (d);
echo both $if $neq $state OK "PASSED" "***FAILED";
echo both ": make unique index on non unique column, state " $state "\n";

select * from idt order by d;
echo both $if $equ $rowcnt 4 "PASSED" "***FAILED";
echo both ": " $rowcnt " rows in idt\n";

update idt set d = sprintf ('%d-%d-%d', k1, k2, k3);
create unique index d on idt (d);
select * from idt order by d;
echo both $if $equ $rowcnt 4 "PASSED" "***FAILED";
echo both ": " $rowcnt " rows in idt\n";


update idt set d = '11';
echo both $if $equ $state 23000 "PASSED" "***FAILED";
echo both ": update unique column to non-unique " $state "\n";


drop table idt2;
create table idt2 (k1 integer);
alter table idt2 add d varchar;
create unique index unq on idt2 (k1);

select count (*) from SYS_KEYS where KEY_TABLE = 'DB.DBA.IDT2';

alter table idt add e integer;
update idt set d = concat (d, '-');delete from idt;

alter table IDT modify primary key (K1, K2);
primarykeys IDT;
echo both $if $equ $rowcnt 2 "PASSED" "***FAILED";
echo both ": " $rowcnt " pk parts after alter pk.\n";


alter table IDT modify primary key (K1);
echo both $if $equ $state 23000 "PASSED" "***FAILED";
echo both ": state " $state " attempt to alter to non unique pk.\n";

primarykeys IDT;
echo both $if $equ $rowcnt 2 "PASSED" "***FAILED";
echo both ": " $rowcnt " pk parts after alter pk.\n";



alter table idt add foreign key (d) references idt (d);

alter table idt add foreign key (k2, k1) references idt;

alter table idt drop foreign key (d) references idt (d);


-- suite for bug #1569
delete user B1569;
create user B1569;
user_set_qualifier ('B1569', 'B1569');

reconnect B1569;

drop table B1569;
create table B1569(
  ID   integer      not null,
  NAME varchar(100) not null,
  primary key(ID)
);
insert into B1569 values (1, 'a');
alter table B1569 modify primary key (ID, NAME);
primarykeys B1569;
echo both $if $equ $rowcnt 2 "PASSED" "***FAILED";
echo both ": bug 1569: " $rowcnt " pk parts after alter pk.\n";
select * from B1569;
echo both $if $equ $last[2] a "PASSED" "***FAILED";
echo both ": bug 1569: " $last[1] " in select after alter pk.\n";
