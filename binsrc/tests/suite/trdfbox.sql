--
--  $Id: trdfbox.sql,v 1.1.4.1.4.1 2013/01/02 16:15:19 source Exp $
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2019 OpenLink Software
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

create table trb (rb any primary key);

insert into trb values (rdf_box (11, 0, 0, 0, 1));
insert into trb values (rdf_box (10.5, 0, 0, 0, 1));
insert into trb values (rdf_box ('snaap', 0, 0, 0, 1));
insert into trb values (rdf_box ('snaap', 0, 0, 0, 1));
-- error - exact duplicate

insert into trb values ('pfaal');
insert into trb values (rdf_box ('pfaal', 0, 0, 0, 1));
-- not unq, 0 type 0 lang is eq to untyped
insert into trb values (rdf_box ('pfaal', 2, 0, 0, 1));
insert into trb values (rdf_box ('pfaal', 2, 0, 1111111, 1));
-- not unq, to_id not in cmp of short.

insert into trb values (rdf_box ('12345678901234567890', 0, 0, 222, 1));
insert into trb values (rdf_box ('12345678901234567890', 0, 0, 222, 0));
insert into trb values (rdf_box ('12345678901234567890', 0, 0, 122, 0));


select rdf_box (11.22, 0,0,0,1) + rdf_box (11, 0,0,0,1);


create procedure cmp (in x any, in y any)
{return case when x < y then - 1 when x = y then 0 else 1 end;}

select cmp (rdf_box (11.22, 0, 0, 0, 1), rdf_box (22, 0, 0, 0, 1));
select cmp (rdf_box ('33', 0, 0, 0, 1), rdf_box ('22', 0, 0, 0, 1));
select cmp ('33', rdf_box ('22', 0, 0, 0, 1));


select cmp (rdf_box ('snaap', 0, 3, 0, 1), rdf_box ('snaap', 0, 3, 0, 1));
select cmp (rdf_box ('snaap', 0, 3, 0, 1), rdf_box ('snaap', 0, 4, 0, 1));
select cmp (rdf_box ('snaap', 0, 3, 0, 1), rdf_box ('snaap', 0, 0, 0, 1));

select cmp (rdf_box ('snaap', 1, 3, 0, 1), rdf_box ('snaap', 4, 0, 0, 1));
select cmp (rdf_box ('snaap', 5, 0, 0, 1), rdf_box ('snaap', 4, 0, 0, 1));

select cmp ('snaap', rdf_box ('snaap', 0, 0, 0, 1));


select rdf_box_data (rb), rdf_box_is_complete (rb), rdf_box_ro_id (rb), rdf_box_lang (rb), rdf_box_type (rb) from trb;


select count (*) from trb a where exists (select 1 from trb b table option (loop) where a.rb = b.rb);
select count (*) from trb a where exists (select 1 from trb b table option (hash) where a.rb = b.rb);

select distinct rb from trb;

select rb, count (*) from trb group by rb;
