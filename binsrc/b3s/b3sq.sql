--
--  $Id$
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



sparql select ?c count (*) where {?s a ?c} group by ?c order by desc 2 limit 400;
sparql select ?p count (*) where {?s ?p ?o} group by ?p order by desc 2 limit 1000;


--  Text Search - default is semantic web.

sparql
select ?s ?p (bif:search_excerpt (bif:vector ('semantic', 'web'), ?o))
where
  {
    ?s ?p ?o .
    filter (bif:contains (?o, "'semantic web'"))
  }
limit 10
;

-- Which graphs have text pattern x?

sparql
select count (*)
where
  {
    ?s ?p ?o .
    filter (bif:contains (?o, "paris"))
  }
;

sparql
select distinct ?g
where {
  graph ?g
  {
    ?s ?p ?o .
    filter (bif:contains (?o, "paris and moonlight"))
  } }
;



--* Graphs With Text  -- paris and dakar is the sample

sparql
select ?g count (*)
where {
  graph ?g
  {
    ?s ?p ?o .
    filter (bif:contains (?o, "paris and dakar"))
  } } group by ?g order by desc 2 limit 50
;






-- what kinds of objects are there about Paris Hilton
--* Types of Things With Text -- sample is Paris Hilton
sparql
select ?tp count (*)
where
  {
    graph ?g
      {
        ?s ?p ?o .
        ?s a ?tp
        filter (bif:contains (?o, "'paris hilton'"))
      }
  }
group by ?tp
order by desc 2
;

-- most popular interests

sparql
select ?o ?cnt
where
  {
    {
      select ?o (count (*)) as ?cnt
      where
        {
          ?s foaf:interest ?o
        }
      group by ?o
    }
    filter (?cnt > 100)
  }
order by desc 2
;

--* Interests Around  -- sample is  <http://www.livejournal.com/interests.bml?int=harry+potter>

sparql
select ?i2 count (*)
where
  {
    ?p foaf:interest <http://www.livejournal.com/interests.bml?int=harry+potter> .
    ?p foaf:interest ?i2
  }
group by ?i2
order by desc 2
limit 20
;

--  doe not work - Interest Cloud Around -- sample is Harry Potter

sparql
select ?i2 count (*)
where
  {
  ?i1 ?p "Harry Potter"@en .
    ?p foaf:interest ?i1 .
    ?p foaf:interest ?i2
  }
group by ?i2
order by desc 2
limit 20
;






-- common distinctive interests

sparql select ?i ?cnt ?n1 ?n2 ?p1 ?p2
  where {
      {select ?i count (*) as ?cnt
          where {
              ?p foaf:interest ?i}
          group by ?i
      }
      filter ( ?cnt > 1 && ?cnt < 10) .
      ?p1 foaf:interest ?i .
      ?p2 foaf:interest ?i .
      filter  (?p1 != ?p2 &&
               !bif:exists ((select (1) where {?p1 foaf:knows ?p2 })) &&
               !bif:exists ((select (1) where {?p2 foaf:knows ?p1 }))) .
      ?p1 foaf:nick ?n1 .
      ?p2 foaf:nick ?n2 .
    }
  order by ?cnt limit 10
;

-- cliques

sparql
select ?i ?cnt ?n1 ?n2 ?p1 ?p2
  where
    {
      {
        select ?i count (*) as ?cnt
        where
          {
            ?p foaf:interest ?i
          }
        group by ?i
      }
      filter ( ?cnt > 1 && ?cnt < 10) .
      ?p1 foaf:interest ?i .
      ?p2 foaf:interest ?i .
      filter  (?p1 != ?p2 &&
               (bif:exists ((select (1) where {?p1 foaf:knows ?p2 })) ||
                bif:exists ((select (1) where {?p2 foaf:knows ?p1 })))) .
      ?p1 foaf:nick ?n1 .
      ?p2 foaf:nick ?n2 .
    }
order by ?cnt
limit 10
;



-- Most asymmetrically known

sparql
select count (*)
  where
    {
      ?p1 foaf:knows ?p2
    }
;


sparql
select count (*)
  where
    {
      ?p1 foaf:knows ?p2 .
      ?p2 foaf:knows ?p1
    }
;

-- celeb with value subquery

sparql
select ?celeb
  ((select count (*)
   where
     {
       ?xx1 foaf:knows ?celeb .
       filter (!bif:exists ((select (1) where { ?celeb foaf:knows ?xx1 })) )
     }))
where
  {
    {
      select distinct ?celeb
      where
        {
          ?xx foaf:knows ?celeb
        }
    }
  }
order by desc 2 limit 10
;
-- cl_exec ('__dbf_set (''cl_res_buffer_bytes'', 300000)');

-- celeb with group by
--* The Most One-Sidedly Known People
sparql select ?celeb, count (*)
where {
    ?claimant foaf:knows ?celeb .
    filter (!bif:exists ((select (1) where { ?celeb foaf:knows ?claimant })))
  } group by ?celeb order by desc 2 limit 10
;

sparql
select count (*)
where
  {
    ?claimant foaf:knows ?celeb .
    filter (!bif:exists ((select (1) where {?celeb foaf:knows ?claimant })))
  }
;

-- Interest profile matches of plaid_skirt

--* People With the Same Interests As X -- sample is "plaid_skirt"@en

sparql
select distinct ?n ((select count (*) where {?p foaf:interest ?i . ?ps foaf:interest ?i}))
   ((select count (*) where { ?p foaf:interest ?i}))
where {
?ps foaf:nick "plaid_skirt"@en .
{select distinct ?p ?psi where {?p foaf:interest ?i . ?psi foaf:interest ?i }} .
  filter (?ps = ?psi)
  ?p foaf:nick ?n
} order by desc 2 limit 50
;




-- how many interests do people have?
sparql
select avg ((select count (*) { ?p foaf:interest ?i }))
where
  {
    {
      select distinct ?p
      where
        {
          ?p foaf:interest ?i2
        }
    }
  }
;

-- does openid connect between graphs?

sparql
select count (*)
where
  {
    graph ?g1
      {
        ?p1 foaf:openid  ?id
      } .
    graph ?g2
      {
        ?p2 foaf:openid ?id
      } .
    filter (?g1 != ?g2)
  }
;

-- most mentioned openids

sparql
select ?id count (distinct ?g)
where
  {
    graph ?g
      {
        ?xx foaf:openid ?id
      }
  }
group by ?id
order by desc 2
limit 100
;

-- what kind of stuff is around Gutman?

sparql
select ?tp count (*)
where
  {
    ?s ?p ?o .
    filter (bif:contains (?o, "gutman")) .
	?s ?p2 ?rel .
	?rel a ?tp
  }
;

sparql
select ?tp ?lbl ?s
where
  {
    ?s ?p ?o .
    filter (bif:contains (?o, "gutman")) .
	?s a ?tp
	optional
	  {
	    ?s rdfs:label ?lbl
	  }
  }
order by ?tp
;

-- type of parties  that claim to know each other

sparql
select distinct ?st ?ot
where
  {
    ?s foaf:knows ?o .
    ?s a ?st .
    ?o a ?ot
  }
;


-- tag cloud of bombing
-- who starts threads about bombing


-- sameAs for identical email sha

insert into rdf_quad (g, s, p, o)
  select iri_to_id ('b3si'), first.s, rdf_sas_iri (), rest.s from
     (select distinct o from rdf_quad where p = iri_to_id ('http://xmlns.com/foaf/0.1/mbox_sha1sum') ) sha,
       (select top 1 s, o from rdf_quad where p = iri_to_id ('http://xmlns.com/foaf/0.1/mbox_sha1sum')) first,
       rdf_quad rest
where   first.o = sha.o
and rest.o = sha.o
and rest.p = iri_to_id ('http://xmlns.com/foaf/0.1/mbox_sha1sum')
and first.s <> rest.s;


-- related tag analysis

create table tag_count (tcn_tag iri_id_8, tcn_count int, primary key (tcn_tag))
alter index tag_count on tag_count partition (tcn_tag int (0hexffff00));

create table tag_coincidence (tc_t1 iri_id_8, tc_t2 iri_id_8, tc_count  int, tc_t1_count int, tc_t2_count int, primary key  (tc_t1, tc_t2))
alter index tag_coincidence on tag_coincidence partition (tc_t1 int (0hexffff00));


insert into tag_count select * from (sparql define output:valmode "LONG" select ?t count (*) as ?cnt where {?s sioc:topic ?t} group by ?t) xx option (quietcast);


update tag_coincidence set tc_t1_count = (select tcn_count from tag_count where tcn_tag = tc_t1),
       tc_t2_count = (select tcn_count from tag_count where tcn_tag = tc_t2);

insert into tag_coincidence  (tc_t1, tc_t2, tc_count)
select "t1", "t2", cnt from
(select  "t1", "t2", count (*) as cnt from
(sparql define output:valmode "LONG"
select ?t1 ?t2 where {?s sioc:topic ?t1 . ?s sioc:topic ?t2 } ) tags
where  "t1" < "t2" group by "t1", "t2") xx
where isiri_id ("t1") and isiri_id ("t2") option (quietcast)
group by ?t1 ?t2;

--insert into rdf_quad (g, s, p, o)
--  select iri_to_id ('tag_summary'), tc_t1, iri_to_id ('related_tag'), tc_t2
--  from tag_coincidence
--  where tc_count > )


-- what is the link between person 1 and person 2?
-- what is the latest mention of x and y?
-- On what sources does the link between x and y depend?

-- Who is my nearest match of xx?

-- what properties are available for discerning identity of blanks in knows relation?

sparql
select ?s ?n
where
  {
    ?s foaf:knows ?x .
    ?s foaf:name ?n
  }
limit 10
;

-- what graph contains the most knows relations?

sparql
select count (*) ?g
where
  {
    graph ?g
      {
        ?s foaf:knows ?o
      }
  }
group by ?g
order by desc 1
limit 10
;

-- What properties do posts have?

sparql
select ?p count (*)
where
  {
    ?s a sioc:Post .
    ?s ?p ?o
  }
group by ?p
order by desc 2
limit 40
;

-- tag cloud of computer

sparql
select ?lbl count (*)
where
  {
    ?s ?p ?o .
    filter (bif:contains (?o, "computer")) .
    ?s sioc:topic ?tg .
    optional
      {
        ?tg rdfs:label ?lbl
      }
  }
group by ?lbl
order by desc 2
limit 40
;



-- who is most known without knowing in return
sparql
select count (*)
where
  {
    ?claimant foaf:knows ?celeb .
    filter (!bif:exists ((select (1) where {?celeb foaf:knows ?claimant })))
  }
;

-- does something refer to geography outside geonames?

sparql
select count (*)
where
  {
    graph <http://sws.geonames.org>
      {
        ?f a geonames:Feature
      } .
    graph ?g
      {
        ?s ?p ?f
      } .
    filter (?g != <http://sws.geonames.org>)
  }
;

sparql
select ?g count (*)
where
  {
    graph <http://sws.geonames.org>
      {
        ?f a geonames:Feature
      } .
    graph ?g
      {
        ?s ?p ?f
      }
  }
group by ?g
order by desc 2
limit 40
;

-- what properties do documents have?
sparql
select ?p count (*)
where
  {
    ?s a foaf:Document .
    ?s ?p ?o
  }
group by ?p
order by desc 2
;

-- what properties do persons have?

sparql
select ?p count (*)
  where
    {
      ?s a foaf:Person .
      ?s ?p ?o
    }
group by ?p
order by desc 2
limit 50
;

-- authors on folksonomy

sparql
select ?auth count (*)
where
  {
    ?d dc:creator ?auth .
    ?d ?p ?o
    filter (bif:contains (?o, "folksonomy"))
  }
group by ?auth
order by desc 2
;




--* Top 100 Authors by Text  --

sparql
select ?auth ?cnt ((select count (distinct ?xx) where { ?xx dc:creator ?auth})) where
{{ select ?auth count (distinct ?d) as ?cnt
where
  {
    ?d dc:creator ?auth .
    ?d ?p ?o
    filter (bif:contains (?o, "semantic and web"))
  }
group by ?auth
order by desc 2 limit 100 }}
;


-- graph vicinity of text hits

-- what types of things surround foaf plaid_skirt?

sparql
select ?tp count(*)
where
  {
    ?s ?p2 ?o2 .
    ?o2 a ?tp .
    ?s foaf:nick ?o .
    filter (bif:contains (?o, "plaid_skirt"))
  }
group by ?tp
order by desc 2
limit 40
;

-- what are they called?

sparql
select ?lbl count(*)
where
  {
    ?s ?p2 ?o2 .
    ?o2 rdfs:label ?lbl .
    ?s foaf:nick ?o .
    filter (bif:contains (?o, "plaid_skirt"))
  }
group by ?lbl
order by desc 2
;

-- more generally called?

--* Cloud Around foaf Person  -- sample is plaid skirt
sparql define input:inference 'b3s'
select ?s ?lbl count(*)
where
  {
    ?s  ?p2 ?o2 .
    ?o2 <http://b3s.openlinksw.com/label> ?lbl .
    ?s  foaf:nick ?o .
    filter (bif:contains (?o, "plaid_skirt"))
  }
group by ?s ?lbl
order by desc 3
;


sparql
select ?lbl count(*)
where
  {
    ?s ?p2 ?o2 .
    ?o2 b3s:label ?lbl .
    ?s foaf:nick ?o .
    filter ( bif:contains (?o, "plaid_skirt"))
  }
group by ?lbl
order by desc 2 limit 100
;



sparql
select ?place count (*) ?lat ?long ?lbl
where
  {
    ?s foaf:based_near ?place .
    ?place geo:lat ?lat .
    ?place geo:long ?long .
    ?place rdfs:label ?lbl
  }
group by ?place ?long ?lat ?lbl
order by desc 2
limit 50
;


-- Social Stefan Decker

sparql
select ?sd count (distinct ?xx)
where
  {
    ?sd a foaf:Person .
    ?sd ?name ?ns .
    filter (bif:contains (?ns, "'Stefan Decker'")) .
    ?sd foaf:knows ?xx
  }
group by ?sd
order by desc 2
;

-- connections of Kingsley Idehen

sparql
select count (*)
where
  {
    {
      select ?s ?o
      where
        {
          ?s foaf:knows ?o
        }
    }
    option (transitive, t_distinct, t_in(?s), t_out(?o), t_min (1)) .
    filter (?s= <http://myopenlink.net/dataspace/person/kidehen#this>)
  }
;

-- Connections of Kingsley Idehen with same as aliases
sparql
define input:same-as "YES" select count (*)
where
  {
    {
      select ?s ?o
      where
        {
          ?s foaf:knows ?o
        }
    }
    option (transitive, t_distinct, t_in(?s), t_out(?o), t_min (1)) .
    filter (?s= <http://myopenlink.net/dataspace/person/kidehen#this>)
  }
;



-- Closest connections of Kingsley Idehen
sparql
select ?o ?dist
where
  {
    {
      select ?s ?o
      where
        {
          ?s foaf:knows ?o
        }
    }
    option (transitive, t_distinct, t_in(?s), t_out(?o), t_min (1), t_step ('step_no') as ?dist) .
    filter (?s= <http://myopenlink.net/dataspace/person/kidehen#this>)
  } limit 50
;


-- LinkedIn style
--* Social Connections a la LinkedIn   sample is http://myopenlink.net/dataspace/person/kidehen#this
sparql
select ?o ?dist ((select count (*) where {?o foaf:knows ?xx}))
where
  {
    {
      select ?s ?o
      where
        {
          ?s foaf:knows ?o
        }
    }
    option (transitive, t_distinct, t_in(?s), t_out(?o), t_min (1), t_max (4), t_step ('step_no') as ?dist) .
    filter (?s= <http://myopenlink.net/dataspace/person/kidehen#this>)
  } order by ?dist desc 3 limit 50
;




select "path", xmlelement ('path', xmlagg (xmlelement ('step', "via"))) from
(sparql select ?o ?via ?dist ?path where
  {
    {select ?s ?o
      where {?s foaf:knows ?o
        }} option (transitive, t_distinct, t_in(?s), t_out(?o), t_min (1), t_max (4), t_step ('step_no') as ?dist, t_step ("path_id") as ?path, t_step (?s) as ?via) .
    filter (?s= <http://myopenlink.net/dataspace/person/kidehen#this>)
  } order by ?dist ) paths group by "path" order by "path";



-- with sas and blank nodes
sparql define input:same-as "yes"
select ?o ?dist ((select count (*) where {{select distinct ?other where {?o foaf:knows ?other}}}))
where
  {
    {
      select ?s ?o
      where
        {
          ?s foaf:knows ?o
        }
    }
    option (transitive, t_distinct, t_in(?s), t_out(?o), t_min (1), t_max (1), t_step ('step_no') as ?dist) .
    filter (?s= <http://richard.cyganiak.de/foaf.rdf#cygri>)
  } order by ?dist desc 3 limit 50
;

-- who claims to know the most distinct, eliminating duplicate sas
sparql
define input:same-as "YES"
  select ?s count (*) where { ?s foaf:knows ?o } group by ?s order by desc 2 limit 10
;


-- What graphs are the principal constituents of Kingsley's network, counting all sameAs aliases?
sparql
define input:same-as "YES" select ?g count (*)
where
  {
    {
      select ?s ?o ?g
      where
        {
          graph ?g {?s foaf:knows ?o }
        }
    }
    option (transitive, t_distinct, t_in(?s), t_out(?o), t_min (1)) .
    filter (?s= <http://myopenlink.net/dataspace/person/kidehen#this>)
  } group by ?g order by desc 2 limit 100
;



-- What connects?
--* Connection Between  samples are http://myopenlink.net/dataspace/person/kidehen#this and http://www.advogato.org/person/mparaz/foaf.rdf#me

sparql
select ?link ?g ?step ?path
where
  {
    {
      select ?s ?o ?g
      where
        {
          graph ?g {?s foaf:knows ?o }
        }
    }
    option (transitive, t_distinct, t_in(?s), t_out(?o), t_no_cycles, T_shortest_only,
       t_step (?s) as ?link, t_step ('path_id') as ?path, t_step ('step_no') as ?step, t_direction 3) .
    filter (?s= <http://myopenlink.net/dataspace/person/kidehen#this>
	&& ?o = <http://www.advogato.org/person/wardv/foaf.rdf#me>)
  } limit 20
;





-- what is being claimed about the location of something called San Francisco?

sparql
select distinct ?sfo ?lat ?long
where
  {
    ?sfo ?sname ?name .
    filter (bif:contains (?name, "'san francisco'")) .
    ?sfo geo:lat ?lat .
    ?sfo geo:long ?long
  }
;


-- types of things which have same as assertions

sparql
select ?tp count (*)
where
  {
    ?s owl:sameAs ?o .
    ?s a ?tp
  }
group by ?tp
order by desc 2
limit 100
;

-- how many really distinct knows relations?

sparql define input:same-as "YES"
select count (*) where
  {{select distinct ?s ?o
where { ?s foaf:knows ?o}}};

sparql
define input:same-as "YES"
select count (*) where
  {{select distinct ?s ?o
where { ?s foaf:knows ?o}}}
;




-- common named entities  that have a dbpedia id
sparql select  ?wp count (*)  where { graph <umbel_ne> { ?n ?p ?ent  } . ?wp owl:sameAs ?ent }  group by ?wp order by desc 2 limit 50;







-- in umbel but refs nothing
sparql
select count (*) where {graph <umbel_ne> {?s ?p ?o} . filter (!bif:exists ((select  (1) where { graph ?g {?s ?p2 ?o2} . filter (?g != <umbel_ne>) })) ) }
;

--

create table sas_attr (sn_name varchar, sn_iri iri_id_8, primary key (sn_name, sn_iri));
alter index sas_attr on sas_attr partition (sn_name varchar);

insert into sas_attr select distinct __ro2sq ("n"), "bn"  from (sparql define output:valmode "LONG" select ?n ?bn where { ?bn foaf:name ?n . filter (bif:length (?n) > 7)}) x;


-- for checking
select top 10 sn_name, sn_iri, min_iri from (
select a.sn_name, a.sn_iri, (select min (sn_iri) from sas_attr b where a.sn_name = b.sn_name) as min_iri
from sas_attr a) x where sn_iri <> min_iri;


-- for making the sas

log_enable (2);
insert soft rdf_quad (g, s, p, o)
select iri_to_id ('b3s_inf_sas'),  sn_iri, rdf_sas_iri (), min_iri from (
select  a.sn_iri, (select min (sn_iri) from sas_attr b where a.sn_name = b.sn_name) as min_iri
from sas_attr a) x where sn_iri <> min_iri;



select iri_to_id ('b3s_inf_sas'),  sn_iri, rdf_sas_iri (), min_iri from (
select  a.sn_iri, (select min (sn_iri) from sas_attr b where a.sn_name = b.sn_name) as min_iri
from sas_attr a) x where sn_iri <> min_iri;

log_enable (2);
insert into rdf_quad (g,s,p, o)
select iri_to_id ('b3s_inf_sas'), min_iri, rdf_sas_iri (), sn_iri from
(select sn_name, min (sn_iri) as min_iri from sas_attr group by sn_name) mn, sas_attr b where b.sn_iri > min_iri and b.sn_name = mn.sn_name;








-- Blank nodes ifp sameness

sparql define input:inference "b3sifp" select distinct ?k where { ?k foaf:name ?n . ?n bif:contains "'Kjetil Kjernsmo'" };

sparql define input:inference "b3sifp"
select distinct ?k ?f1 ?f2 where { ?k foaf:name ?n . ?n bif:contains "'Kjetil Kjernsmo'" . ?k foaf:knows ?f1 . ?f1 foaf:knows ?f2 };

sparql define input:same-as "yes"
select distinct ?k ?f1 ?f2 where { ?k foaf:name ?n . ?n bif:contains "'Kjetil Kjernsmo'" . ?k foaf:knows ?f1 . ?f1 foaf:knows ?f2 };


sparql define input:inference "b3sifp"
select count (*) where { ?x a foaf:Person . ?x foaf:knows ?y};





sparql select distinct ?p where {?p a foaf:Person option (same-as "yes")};

-- What person has the most sameAs aliases?

sparql select ?person count (*) where
{{select distinct ?person where {?person a foaf:Person } limit 1000}
 {select ?x ?alias where {{ ?x owl:sameAs ?alias } union {?alias owl:sameAs ?x}}}
	option (transitive, t_in (?x), t_out (?alias), t_distinct) .
 filter (?x = ?person) .
} group by ?person order by desc 2 limit 20;



-- where the synonyms of Dan York?
sparql select ?g count (*) where {
 {select ?x ?alias ?g where {{ graph ?g {?x owl:sameAs ?alias }} union {graph ?g {?alias owl:sameAs ?x}}}}
	option (transitive, t_in (?x), t_out (?alias), t_distinct, t_min (1)) .
 filter (?x = <http://www.advogato.org/person/dyork/foaf.rdf#me> ) .
} group by ?g order by desc 2 limit 30;


-- Smoosh

create table name_prop (np_name any, np_p iri_id_8, np_o any, primary key (np_name, np_p, np_o));
alter index name_prop on name_prop partition (np_name varchar (-1, 0hexffff));
create table name_iri (ni_name any primary key, ni_s iri_id_8);
alter index name_iri on name_iri partition (ni_name varchar (-1, 0hexffff));
create table pref_iri (i iri_id_8, pref iri_id_8, primary key (i));
alter index pref_iri on pref_iri partition (i int (0hexffff00));

insert soft pref_iri (i, pref) select s, ni_s from name_iri, rdf_quad where o = ni_name and p = iri_to_id ('http://xmlns.com/foaf/0.1/name');


insert soft name_prop select "n", "p", "o" from (sparql define output:valmode "LONG" select ?n ?p ?o where {?x a foaf:Person . ?x foaf:name ?n . ?x ?p ?o}) xx;
insert into name_iri select np_name, (select min (s) from rdf_quad where o = np_name and p = iri_to_id ('http://xmlns.com/foaf/0.1/name')) as mini from name_prop where np_p = iri_to_id ('http://xmlns.com/foaf/0.1/name');



-- count the smoosh before inserting
create table smoosh_ct (s iri_id_8, p iri_id_8, o any, primary key (s,p,o));
alter index smoosh_ct on smoosh_ct partition (s int (0hexffff00));

insert soft smoosh_ct (s, p, o)  select s, np_p, np_o from name_prop, rdf_quad where o = np_name and p = iri_to_id ('http://xmlns.com/foaf/0.1/name');


insert soft rdf_quad (g,s,p,o) select iri_to_id ('psmoosh'), s, np_p, np_o from name_prop, rdf_quad where o = np_name and p = iri_to_id ('http://xmlns.com/foaf/0.1/name') xx;


-- Make smartSmoosh.  When inserting an O, look up the right one.


insert soft rdf_quad (g,s,p,o) select iri_to_id ('psmoosh'), ni_s, np_p,
  coalesce ((select pref from pref_iri where i = np_o), np_o)
from name_prop, name_iri where ni_name = np_name option (loop, quietcast);


-- How many tripoles in the original?

sparql select count (*) where { graph ?g { ?x a foaf:Person . ?x foaf:name ?n . ?x ?p ?o}};

sparql select  count (*) where {{select distinct ?person where {?person a foaf:Person}} . filter (bif:exists ((select (1) where { ?person foaf:name ?nn}))) . ?person ?p ?o};



