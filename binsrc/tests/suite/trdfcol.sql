--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2015 OpenLink Software
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


-- Try storing rdf column-wise



create table rdf_col (rid int identity primary key, g iri_id, s iri_id, p iri_id, o any);

create bitmap index cg on rdf_col (g);
create bitmap index cs on rdf_col (s);
create bitmap index cp on rdf_col (p);
create bitmap index co on rdf_col (o);

insert into rdf_col (g, s, p, o) select g, s, p, o from rdf_quad table option (index primary key);

select count (*) from rdf_quad a table option (index primary key) where not exists (select 1 from rdf_quad b table option (loop, index rdf_quad_ogps) where a.g = b.g and a.p = b.p and a.o = b.o and a.s = b.s);

select count (*) from rdf_col a table option (index primary key) where not exists (select 1 from rdf_col b table option (loop) where a.g = b.g and a.p = b.p and a.o = b.o and a.s = b.s);

select top 50 * from rdf_col a table option (index primary key) where not exists (select 1 from rdf_col b table option (loop) where a.g = b.g and a.p = b.p and a.o = b.o and a.s = b.s);




create procedure rdck ()
{
declare ct int;
declare gn, sn, pn, _on  any;
result_names (gn,gn, sn, sn, pn, pn, _on, _on);
ct := 0;
for select g as g2, s as s2, p as p2, o as o2  from rdf_col do
{
declare g1, s1, p1, o1 any;
select g, s, p, o into g1, s1, p1, o1 from rdf_col table option (intersect) where g = g2 and s = s2 and p = p2 and o = o2;
if (not (g1 = g2 and s1 = s2 and p1 = p2 and o1 = o2))
{
result (g1, g2, s1, s2, p1, p2, o1, o2);
ct := ct 	+ 1;

if (ct > 10) return ct;}
}
return ct;
}
