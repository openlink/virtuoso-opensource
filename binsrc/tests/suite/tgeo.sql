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


echo both "Geometry index test\n";

drop table GEO;
drop table GEO_INX;

create table GEO (ID bigint, GEO any, primary key (ID))
  alter index geo on geo partition (id int);

create table GEO_INX (X real no compress, Y real no compress, X2 real no compress, Y2 real no compress, id bigint no compress,
  primary key (X, Y, X2, Y2, id) not column)
  alter index geo_inx on geo_inx partition (id int);




insert into sys_vt_index (vi_table, vi_index, vi_col, vi_id_col, vi_index_table, vi_id_is_pk, vi_options)
  values ('DB.DBA.GEO', 'GEO', 'GEO', 'ID', 'DB.DBA.GEO_INX', 1, 'G');

__ddl_changed ('DB.DBA.GEO');

create procedure CL_GEO_INS (in id int, in g any)
{
  geo_insert ('DB.DBA.GEO_INX', g, id);
}

create procedure cl_geo_insert (in id int, inout g any)
{
  declare daq any;
  if (1 = sys_stat ('cl_run_local_only'))
    {
      geo_insert ('DB.DBA.GEO_INX', g, id);
      return;
    }
  daq := daq (1);
  daq_call (daq, 'DB.DBA.GEO', 'GEO', 'DB.DBA.CL_GEO_INS', vector (id, g), 1);
  daq_results (daq);
}

create procedure rndf (in r1 float, in r2 float)
{
  declare i int;
 i := rnd (1000000);
  return r1 + (i * (r2 - r1)) / 1e6;
}

create procedure gt1 (in n int, in srid int := 0, in delay int := 0)
{
  declare c, id, pt any;
  delay (delay);
  for (c := 0; c < n; c := c + 1)
    {
    id := sequence_next ('geo');
    pt := st_setsrid (st_point (rndf (0, 3), rndf (0, 4)), srid);
      insert into geo (id, geo) values (id, pt);
      cl_geo_insert (id, pt);
    id := sequence_next ('geo');
    pt := st_setsrid (st_point (rndf (10, 23), rndf (20, 40)), srid);
      insert into geo (id, geo) values (id, pt);
      cl_geo_insert (id, pt);
    }
}




select a.id, b.id from geo a, geo b where st_intersects (a.geo, b.geo) and b.id = 20;


explain ('select id, st_distance (st_point (1.4, 1.4), geo), geo from geo where st_intersects (geo, st_point (1.4, 1.4), 0.2) order by 2 desc');

select top 10 id, st_distance (st_point (1.4, 1.4), geo), geo from geo where st_intersects (geo, st_point (1.4, 1.4), 0.2) order by 2;

select top 10 a.id, a.geo  from geo a where not exists (select 1 from geo b where st_intersects (b.geo, a.geo));
select top 10 a.id, b.id, st_distance (a.geo, b.geo) from geo a, geo b where st_intersects (b.geo, a.geo);



set autocommit manual;
gt1 (500);
checkpoint &
wait_for_children;
select top 10 a.id, a.geo  from geo a where not exists (select 1 from geo b where st_intersects (b.geo, a.geo));
echo both $if $equ $rowcnt 0 "PASSED" "***FAILED";
echo both ": geo self not exists\n";

rollback work;

gt1 (10000);
select top 10 a.id, a.geo  from geo a where not exists (select 1 from geo b where st_intersects (b.geo, a.geo));
echo both $if $equ $rowcnt 0 "PASSED" "***FAILED";
echo both ": geo self not exists 2\n";

select count (geo_delete ('DB.DBA.GEO_INX', geo, id)) from geo;
echo both $if $equ $last[1] 20000 "PASSED" "***FAILED";
echo both ":geo deleted\n";

select count (*) from geo_inx;
echo both $if $equ $last[1] 0 "PASSED" "***FAILED";
echo both ":geo deleted 2\n";

rollback work;

set autocommit off;

gt1 (10000);

create procedure read_geo (in is_rc int)
{
  if (is_rc)
    set isolation = 'committed';
  else
    set isolation = 'repeatable';
  for select id from geo where st_intersects (geo, st_setsrid (st_point (1, 1), 0), 20) do
    {
      delay	 (0.01);
    }
}


__dbf_set ('dc_batch_sz', 10);

gt1 (10000, delay => 0.4) &
read_geo (0);
echo both $if $equ $sqlstate 40001 "PASSED" "***FAILED";
echo both ": read busted by geo split\n";
wait_for_children;
__dbf_set ('dc_batch_sz', 10000);

SPARQL PREFIX ex: <http://example.org/> PREFIX geo: <http://www.w3.org/2003/01/geo/wgs84_pos#> INSERT DATA INTO <http://test.org> {ex:p02 geo:geometry "POINT(25.466665 35.15)"^^virtrdf:Geometry};
SPARQL PREFIX ex: <http://example.org/> PREFIX geo: <http://www.w3.org/2003/01/geo/wgs84_pos#> INSERT DATA INTO <http://test.org> {ex:p01 geo:geometry "POINT(25.4666665 35.15)"^^virtrdf:Geometry};
SPARQL PREFIX ex: <http://example.org/> PREFIX geo: <http://www.w3.org/2003/01/geo/wgs84_pos#> SELECT ?s1 ?s2 FROM <http://test.org> WHERE {?s1 geo:geometry ?g1. ?s2 geo:geometry ?g2. FILTER(bif:st_intersects(?g1, ?g2, 0.001))};

echo both $if $equ $rowcnt 4 "PASSED" "***FAILED";
echo both ": in st_intersects\n";
exit;

sparql select count (*) where { ?s <http://example.org/sparql/geo/hasGeography1> ?g1 . filter (!bif:exists ((select (1) where {?s1 <http://example.org/sparql/geo/hasGeography1> ?g2 . filter (bif:st_intersects (?g1, ?g2, 0) ) })))};

sparql select ?m count (*) where { ?m a <http://dbpedia.org/class/yago/RomanCatholicChurchesInParis> .
 ?m geo:geometry ?geo . filter (bif:st_intersects (?geo, bif:st_point (0, 52), 100))}


sparql select ?c count (*) where {  ?m geo:geometry ?geo . ?m a ?c . filter (bif:st_intersects (?geo, bif:st_point (0, 52), 100))} group by ?c order by desc 2;

sparql select ?m (bif:st_distance (?geo, bif:st_point (0, 52)))
where {  ?m geo:geometry ?geo . ?m a <http://dbpedia.org/ontology/City> . filter (bif:st_intersects (?geo, bif:st_point (0, 52), 30))} order by desc 2 limit 20;

sparql select ?m (bif:st_distance (?geo, bif:st_point (0, 52)))
where {  ?m geo:geometry ?geo . ?m a <http://dbpedia.org/ontology/City> . filter (bif:st_intersects (?geo, bif:st_point (0, 52), 100))} order by desc 2 limit 20;


-- text or geo?
sparql select ?m (bif:st_distance (?geo, bif:st_point (0, 52))) where { ?m ?p ?o2 .  ?m geo:geometry ?geo . ?m a <http://dbpedia.org/ontology/City> . filter (bif:st_intersects (?geo, bif:st_point (0, 52), 100) && bif:contains (?o2, "london")) } order by  2 limit 20

sparql select ?m (bif:st_distance (?geo, bif:st_point (0, 52))) where { ?m ?p ?o2 .  ?m geo:geometry ?geo . ?m a <http://dbpedia.org/ontology/City> . filter (bif:st_intersects (?geo, bif:st_point (0, 52), 10) && bif:contains (?o2, "london")) } order by  2 limit 20




sparql select ?c count (*) where { ?s geo:geometry ?geo . filter (bif:st_intersects (bif:st_point (2.3498, 48.853), 5)) . ?s a ?c} group by ?c order by desc 2 limit 50;

sparql
http://linkedgeodata.org/vocabulary#cafe


sparql select ?c count (*) where ?s a ?c . ?s geo:geometry ?geo . filter (bif:st_intersecs (?geo, st_point (2.3498, 48.853), 0.group by ?c order by desc 2 limit 20;


-- Stuff around Notre Dame de Paris
sparql select ?c count (*) where {?s a ?c . ?s geo:geometry ?geo . filter (bif:st_intersects (?geo, bif:st_point (2.3498, 48.853), 0.3)) } group by ?c order by desc 2 limit 20;

sparql prefix lgv: <http://linkedgeodata.org/vocabulary#> select ?c count (*) where {?s a ?c . ?s a lgv:place_of_worship . ?s geo:geometry ?geo . filter (bif:st_intersects (?geo, bif:st_point (2.3498, 48.853), 10)) } group by ?c order by desc 2 limit 200;

sparql prefix lgv: <http://linkedgeodata.org/vocabulary#>
select ?cn where {?s lgv:name ?cn  . ?s geo:geometry ?geo . filter (bif:st_intersects (?geo, bif:st_point (2.3498, 48.853), 0.3)) } limit 20;




-- churches with the most bars
sparql prefix lgv: <http://linkedgeodata.org/vocabulary#>
select ?churchname ?cafename (bif:st_distance (?churchgeo, ?cafegeo))
where { ?church a lgv:place_of_worship . ?church geo:geometry ?churchgeo . ?church lgv:name ?churchname . ?cafe a lgv:cafe . ?cafe lgv:name ?cafename . ?cafe geo:geometry ?cafegeo .
filter (bif:st_intersects (?churchgeo, bif:st_point (2.3498, 48.853), 5)
&& bif:st_intersects (?cafegeo, ?churchgeo, 0.2)) } limit 100;

-- big cities with a lot of geo items
sparql select ?s (sql:num_or_null (?p))  count (*) where { ?s <http://dbpedia.org/ontology/populationTotal> ?p . filter ( sql:num_or_null (?p) > 6000000)  . ?s geo:geometry ?geo . filter (bif:st_intersects (?pt, ?geo,2)) . ?xx geo:geometry ?pt } group by ?s (sql:num_or_null (?p))order by desc 3 limit 20;

-- Bug 16316

sparql clear graph <http://www.example.com/ontology>;

DB.DBA.TTLP ('
<http://www.example.com/id/Object/0> <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://www.example.com/ontology#Feature> .
<http://www.example.com/id/Object/0> <http://www.w3.org/2003/01/geo/wgs84_pos#geometry> "point(-90 40)"^^<http://www.openlinksw.com/schemas/virtrdf#Geometry> .

<http://www.example.com/id/Object/1> <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://www.example.com/ontology#Feature> .
<http://www.example.com/id/Object/1> <http://www.w3.org/2003/01/geo/wgs84_pos#geometry> "point(-91 40)"^^<http://www.openlinksw.com/schemas/virtrdf#Geometry> .

<http://www.example.com/id/Object/2> <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://www.example.com/ontology#Feature> .
<http://www.example.com/id/Object/2> <http://www.w3.org/2003/01/geo/wgs84_pos#geometry> "point(-92 40)"^^<http://www.openlinksw.com/schemas/virtrdf#Geometry> .

<http://www.example.com/id/Object/3> <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://www.example.com/ontology#Feature> .
<http://www.example.com/id/Object/3> <http://www.w3.org/2003/01/geo/wgs84_pos#geometry> "point(-93 40)"^^<http://www.openlinksw.com/schemas/virtrdf#Geometry> .

<http://www.example.com/id/Object/4> <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://www.example.com/ontology#Feature> .
<http://www.example.com/id/Object/4> <http://www.w3.org/2003/01/geo/wgs84_pos#geometry> "point(-94 40)"^^<http://www.openlinksw.com/schemas/virtrdf#Geometry> .

<http://www.example.com/id/Object/5> <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://www.example.com/ontology#Feature> .
<http://www.example.com/id/Object/5> <http://www.w3.org/2003/01/geo/wgs84_pos#geometry> "point(-95 40)"^^<http://www.openlinksw.com/schemas/virtrdf#Geometry> .

<http://www.example.com/id/Object/10> <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://www.example.com/ontology#Feature> .
<http://www.example.com/id/Object/10> <http://www.w3.org/2003/01/geo/wgs84_pos#geometry> "point(-90 41)"^^<http://www.openlinksw.com/schemas/virtrdf#Geometry> .

<http://www.example.com/id/Object/11> <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://www.example.com/ontology#Feature> .
<http://www.example.com/id/Object/11> <http://www.w3.org/2003/01/geo/wgs84_pos#geometry> "point(-91 41)"^^<http://www.openlinksw.com/schemas/virtrdf#Geometry> .

<http://www.example.com/id/Object/12> <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://www.example.com/ontology#Feature> .
<http://www.example.com/id/Object/12> <http://www.w3.org/2003/01/geo/wgs84_pos#geometry> "point(-92 41)"^^<http://www.openlinksw.com/schemas/virtrdf#Geometry> .

<http://www.example.com/id/Object/13> <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://www.example.com/ontology#Feature> .
<http://www.example.com/id/Object/13> <http://www.w3.org/2003/01/geo/wgs84_pos#geometry> "point(-93 41)"^^<http://www.openlinksw.com/schemas/virtrdf#Geometry> .

<http://www.example.com/id/Object/14> <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://www.example.com/ontology#Feature> .
<http://www.example.com/id/Object/14> <http://www.w3.org/2003/01/geo/wgs84_pos#geometry> "point(-94 41)"^^<http://www.openlinksw.com/schemas/virtrdf#Geometry> .

<http://www.example.com/id/Object/15> <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://www.example.com/ontology#Feature> .
<http://www.example.com/id/Object/15> <http://www.w3.org/2003/01/geo/wgs84_pos#geometry> "point(-95 41)"^^<http://www.openlinksw.com/schemas/virtrdf#Geometry> .

<http://www.example.com/id/Object/20> <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://www.example.com/ontology#Feature> .
<http://www.example.com/id/Object/20> <http://www.w3.org/2003/01/geo/wgs84_pos#geometry> "point(-90 42)"^^<http://www.openlinksw.com/schemas/virtrdf#Geometry> .

<http://www.example.com/id/Object/21> <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://www.example.com/ontology#Feature> .
<http://www.example.com/id/Object/21> <http://www.w3.org/2003/01/geo/wgs84_pos#geometry> "point(-91 42)"^^<http://www.openlinksw.com/schemas/virtrdf#Geometry> .

<http://www.example.com/id/Object/22> <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://www.example.com/ontology#Feature> .
<http://www.example.com/id/Object/22> <http://www.w3.org/2003/01/geo/wgs84_pos#geometry> "point(-92 42)"^^<http://www.openlinksw.com/schemas/virtrdf#Geometry> .

<http://www.example.com/id/Object/23> <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://www.example.com/ontology#Feature> .
<http://www.example.com/id/Object/23> <http://www.w3.org/2003/01/geo/wgs84_pos#geometry> "point(-93 42)"^^<http://www.openlinksw.com/schemas/virtrdf#Geometry> .

<http://www.example.com/id/Object/24> <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://www.example.com/ontology#Feature> .
<http://www.example.com/id/Object/24> <http://www.w3.org/2003/01/geo/wgs84_pos#geometry> "point(-94 42)"^^<http://www.openlinksw.com/schemas/virtrdf#Geometry> .

<http://www.example.com/id/Object/25> <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://www.example.com/ontology#Feature> .
<http://www.example.com/id/Object/25> <http://www.w3.org/2003/01/geo/wgs84_pos#geometry> "point(-95 42)"^^<http://www.openlinksw.com/schemas/virtrdf#Geometry> .

<http://www.example.com/id/Object/30> <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://www.example.com/ontology#Feature> .
<http://www.example.com/id/Object/30> <http://www.w3.org/2003/01/geo/wgs84_pos#geometry> "point(-90 43)"^^<http://www.openlinksw.com/schemas/virtrdf#Geometry> .

<http://www.example.com/id/Object/31> <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://www.example.com/ontology#Feature> .
<http://www.example.com/id/Object/31> <http://www.w3.org/2003/01/geo/wgs84_pos#geometry> "point(-91 43)"^^<http://www.openlinksw.com/schemas/virtrdf#Geometry> .

<http://www.example.com/id/Object/32> <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://www.example.com/ontology#Feature> .
<http://www.example.com/id/Object/32> <http://www.w3.org/2003/01/geo/wgs84_pos#geometry> "point(-92 43)"^^<http://www.openlinksw.com/schemas/virtrdf#Geometry> .

<http://www.example.com/id/Object/33> <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://www.example.com/ontology#Feature> .
<http://www.example.com/id/Object/33> <http://www.w3.org/2003/01/geo/wgs84_pos#geometry> "point(-93 43)"^^<http://www.openlinksw.com/schemas/virtrdf#Geometry> .

<http://www.example.com/id/Object/34> <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://www.example.com/ontology#Feature> .
<http://www.example.com/id/Object/34> <http://www.w3.org/2003/01/geo/wgs84_pos#geometry> "point(-94 43)"^^<http://www.openlinksw.com/schemas/virtrdf#Geometry> .

<http://www.example.com/id/Object/35> <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://www.example.com/ontology#Feature> .
<http://www.example.com/id/Object/35> <http://www.w3.org/2003/01/geo/wgs84_pos#geometry> "point(-95 43)"^^<http://www.openlinksw.com/schemas/virtrdf#Geometry> .

<http://www.example.com/id/Object/40> <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://www.example.com/ontology#Feature> .
<http://www.example.com/id/Object/40> <http://www.w3.org/2003/01/geo/wgs84_pos#geometry> "point(-90 44)"^^<http://www.openlinksw.com/schemas/virtrdf#Geometry> .

<http://www.example.com/id/Object/41> <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://www.example.com/ontology#Feature> .
<http://www.example.com/id/Object/41> <http://www.w3.org/2003/01/geo/wgs84_pos#geometry> "point(-91 44)"^^<http://www.openlinksw.com/schemas/virtrdf#Geometry> .

<http://www.example.com/id/Object/42> <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://www.example.com/ontology#Feature> .
<http://www.example.com/id/Object/42> <http://www.w3.org/2003/01/geo/wgs84_pos#geometry> "point(-92 44)"^^<http://www.openlinksw.com/schemas/virtrdf#Geometry> .

<http://www.example.com/id/Object/43> <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://www.example.com/ontology#Feature> .
<http://www.example.com/id/Object/43> <http://www.w3.org/2003/01/geo/wgs84_pos#geometry> "point(-93 44)"^^<http://www.openlinksw.com/schemas/virtrdf#Geometry> .

<http://www.example.com/id/Object/44> <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://www.example.com/ontology#Feature> .
<http://www.example.com/id/Object/44> <http://www.w3.org/2003/01/geo/wgs84_pos#geometry> "point(-94 44)"^^<http://www.openlinksw.com/schemas/virtrdf#Geometry> .

<http://www.example.com/id/Object/45> <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://www.example.com/ontology#Feature> .
<http://www.example.com/id/Object/45> <http://www.w3.org/2003/01/geo/wgs84_pos#geometry> "point(-95 44)"^^<http://www.openlinksw.com/schemas/virtrdf#Geometry> .

<http://www.example.com/id/Object/50> <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://www.example.com/ontology#Feature> .
<http://www.example.com/id/Object/50> <http://www.w3.org/2003/01/geo/wgs84_pos#geometry> "point(-90 45)"^^<http://www.openlinksw.com/schemas/virtrdf#Geometry> .

<http://www.example.com/id/Object/51> <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://www.example.com/ontology#Feature> .
<http://www.example.com/id/Object/51> <http://www.w3.org/2003/01/geo/wgs84_pos#geometry> "point(-91 45)"^^<http://www.openlinksw.com/schemas/virtrdf#Geometry> .

<http://www.example.com/id/Object/52> <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://www.example.com/ontology#Feature> .
<http://www.example.com/id/Object/52> <http://www.w3.org/2003/01/geo/wgs84_pos#geometry> "point(-92 45)"^^<http://www.openlinksw.com/schemas/virtrdf#Geometry> .

<http://www.example.com/id/Object/53> <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://www.example.com/ontology#Feature> .
<http://www.example.com/id/Object/53> <http://www.w3.org/2003/01/geo/wgs84_pos#geometry> "point(-93 45)"^^<http://www.openlinksw.com/schemas/virtrdf#Geometry> .

<http://www.example.com/id/Object/54> <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://www.example.com/ontology#Feature> .
<http://www.example.com/id/Object/54> <http://www.w3.org/2003/01/geo/wgs84_pos#geometry> "point(-94 45)"^^<http://www.openlinksw.com/schemas/virtrdf#Geometry> .

<http://www.example.com/id/Object/55> <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://www.example.com/ontology#Feature> .
<http://www.example.com/id/Object/55> <http://www.w3.org/2003/01/geo/wgs84_pos#geometry> "point(-95 45)"^^<http://www.openlinksw.com/schemas/virtrdf#Geometry> .
', 'http://www.example.com/graph/test', 'http://www.example.com/graph/test' );


DB.DBA.RDF_GEO_FILL ();

SPARQL PREFIX geo: <http://www.w3.org/2003/01/geo/wgs84_pos#>
PREFIX ex: <http://www.example.com/ontology#>
PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
SELECT count(1) from <http://www.example.com/graph/test>
WHERE {
   ?feature rdf:type ex:Feature .
   ?feature geo:geometry ?geo . } ;


SPARQL PREFIX geo: <http://www.w3.org/2003/01/geo/wgs84_pos#>
PREFIX ex: <http://www.example.com/ontology#>
PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
SELECT ?feature ?geo  from <http://www.example.com/graph/test>
WHERE {
   ?feature rdf:type ex:Feature .
   ?feature geo:geometry ?geo .
   FILTER (bif:st_intersects (?geo,
       bif:st_ewkt_read("POLYGON((-95 40, -94 41, -93 42, -92 43, -91 44, -90 45, -90 40, -95 40))"))) } ;

echo both $if $equ $rowcnt 21 "PASSED" "***FAILED";
echo both ": Bug 16316: select points inside a triangle by bif:st_intersects() filter\n";
