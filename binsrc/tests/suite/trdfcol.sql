

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
