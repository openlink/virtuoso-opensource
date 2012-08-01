-- 
--  $Id$
-- 
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2012 OpenLink Software
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

-- IRI_ID type


drop table it;
drop table at;
drop table it2;
create table it (i IRI_ID_8 primary key);
create table at (i any primary key);


insert into it values (#i1);
insert into it values (#i2);
insert into it values (#i3);
insert into it values (iri_id_from_num (4000000003));
insert into it values (iri_id_from_num (4000003000));


insert into at values (#i1);
insert into at values (#i2);
insert into at values (#i3);
insert into at values (iri_id_from_num (-3));
insert into at values (iri_id_from_num (-3000));


insert into it values (#i1);
ECHO BOTH $IF $EQU $SQLSTATE 23000 "PASSED" "***FAILED";
ECHO BOTH ": IRI_ID IRI_ID unq\n";

insert into at values (#i1);
ECHO BOTH $IF $EQU $SQLSTATE 23000 "PASSED" "***FAILED";
ECHO BOTH ": any IRI_ID unq\n";

select iri_id_num (max (i)) from it;
ECHO BOTH  $IF $EQU $LAST[1] 4000003000 "PASSED" "***FAILED";
ECHO BOTH ": IRI_ID max\n";

select iri_id_num (max (i)) from at;
ECHO BOTH  $IF $EQU $LAST[1] -3 "PASSED" "***FAILED";
ECHO BOTH ": any  IRI_ID max\n";


select count (distinct i) from it;

select * from it a, it b table option (hash) where a.i = b.i option (order);
ECHO BOTH $IF $EQU $ROWCNT 5 "PASSED" "***FAILED";
ECHO BOTH ": IRI_ID hash join\n";


select * from at a, at b table option (hash) where a.i = b.i option (order);
ECHO BOTH $IF $EQU $ROWCNT 5 "PASSED" "***FAILED";
ECHO BOTH ": any IRI_ID hash join\n";





select * from it order by iri_id_num (i);
select * from it a, it b table option (loop) where a.i = b.i option (order);
ECHO BOTH $IF $EQU $ROWCNT 5 "PASSED" "***FAILED";
ECHO BOTH ": IRI_ID loop  join\n";

create table it2 (ik IRI_ID, id IRI_ID, primary key (ik));

insert into it2 select i, i from it;
insert into it2 select iri_id_from_num (iri_id_num (i) + 10), i from it;

select id, count (*) from it2 group by id;
ECHO BOTH $IF $EQU $ROWCNT 5 "PASSED" "***FAILED";
ECHO BOTH ": IRI_ID group by\n";

select * from it2 order by id desc;
ECHO BOTH $IF $EQU $LAST[1] #i11 "PASSED" "**FAILED";
ECHO BOTH ": IRI_ID order by\n";
