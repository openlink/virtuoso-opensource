



ttlp ('
<ic1> a <c1> .
<ic2> a <c2> .
<ic3> a <c3> .
<ic1> <p1> <ic1p1> .
<ic2> <p1> <ic2p1>.
<ic3> <p1> <ic3p1> .
<ic1> <cl2> <c2> .
', '', 'inft');

ttlp ('
<ic1> <icpe> 1 .
<ic2> <icpe> 2 .
<ic3> <icpe> 3 .
<ic4> <icpe> 4 .
', '', 'extra');


ttlp (' @prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .
<c2> rdfs:subClassOf <c1> .
  <c3> rdfs:subClassOf <c2> .
  <c5> rdfs:subClassOf <c4> .
<p1> rdfs:subPropertyOf <p0> .
', '', 'sc');

create procedure f (in q any) {return q;};

rdfs_rule_set ('inft', 'sc');



select id_to_iri (s) from rdf_quad table option (with 'inft') where g = iri_to_id ('inft',0) and p = iri_to_id ('http://www.w3.org/1999/02/22-rdf-syntax-ns#type', 0) and o = iri_to_id ('c1', 0);
echo both $if $equ $rowcnt 3 "PASSED" "***FAILED";
echo both ": 3 inst of c1 with const\n";

select id_to_iri (s) from rdf_quad table option (with 'inft') where g = iri_to_id ('inft',0) and p = f (iri_to_id ('http://www.w3.org/1999/02/22-rdf-syntax-ns#type', 0)) and o = f (iri_to_id ('c1', 0));
echo both $if $equ $rowcnt 3 "PASSED" "***FAILED";
echo both ":  3 inst of c1 with f \n";


select id_to_iri (s), id_to_iri (p), id_to_iri (o) from rdf_quad table option (with 'inft') where g = iri_to_id ('inft', 0);
echo both $if $equ $rowcnt 13 "PASSED" "***FAILED";
echo both ": 13 triples in g inft\n";



select id_to_iri (a.s) from rdf_quad a table option (with 'inft'), rdf_quad b table option (with 'inft ')
where a.g = iri_to_id ('inft', 0) and b.g = iri_to_id ('inft', 0)
	and a.o = iri_to_id ('c1', 0) and b.o = iri_to_id ('c1', 0)
	and a.p = iri_to_id ('http://www.w3.org/1999/02/22-rdf-syntax-ns#type', 0)
	and b.p = iri_to_id ('http://www.w3.org/1999/02/22-rdf-syntax-ns#type', 0)
	and a.s = b.s;

echo both $if $equ $rowcnt 3 "PASSED" "***FAILED";
echo both ": inx int on o = c1 and p = rdfs:type\n";


explain ('select 1 from rdf_quad a table option (with ''inft''), rdf_quad b table option (with ''inft '')
where a.g = iri_to_id (''inft'', 0) and b.g = iri_to_id (''inft'', 0)
	and a.o = iri_to_id (''c1'', 0) and b.o = iri_to_id (''c1'', 0)
	and a.p = iri_to_id (''http://www.w3.org/1999/02/22-rdf-syntax-ns#type'', 0)
	and b.p = iri_to_id (''http://www.w3.org/1999/02/22-rdf-syntax-ns#type'', 0)
	and a.s = b.s', -5);



select s, p from rdf_quad table option (with 'inft') 
where g = iri_to_id ('inft', 0) and o = iri_to_id ('c1', 0);
echo both $if $equ $rowcnt 3 "PASSED" "***FAILED";
echo both ": o = c1 3 rows\n";


create table ps (ps iri_id primary key);

insert into ps values (iri_to_id ('c1', 1));
insert into ps values (iri_to_id ('c4', 1));

select ps, s, p, o from ps left join  rdf_quad table option (with 'inft') on g = iri_to_id ('inft', 0) and  ps  = o;
echo both $if $equ $rowcnt 4 "PASSED" "***FAILED";
echo both ": inf oj rowcnt\n";



--- Complete combinations 
--- fs fp fo
select id_to_iri (s), id_to_iri (p), id_to_iri (o)  from rdf_quad table option (with 'inft') where g = iri_to_id ('inft', 0);
echo both $if $equ $rowcnt 13 "PASSED" "***FAILED";
echo both ": fs fp fp \n";

select id_to_iri (s), id_to_iri (p), id_to_iri (o)  from rdf_quad table option (with 'inft') where g = iri_to_id ('inft', 0) and o = iri_to_id ('c1', 0);
echo both $if $equ $rowcnt 3 "PASSED" "***FAILED";
echo both ": fs fp go = c1 \n";

select id_to_iri (s), id_to_iri (p), id_to_iri (o)  from rdf_quad table option (with 'inft') where g = iri_to_id ('inft', 0) and o = f (iri_to_id ('c1', 0));
echo both $if $equ $rowcnt 3 "PASSED" "***FAILED";
echo both ": fs fp go = f c1 \n";

select id_to_iri (s), id_to_iri (p), id_to_iri (o)  from rdf_quad table option (with 'inft') where g = iri_to_id ('inft', 0) and o = f (iri_to_id ('ic1p1', 0));
echo both $if $equ $rowcnt 2 "PASSED" "***FAILED";
echo both ": fs fp go = f ic1p1 \n";


select id_to_iri (s), id_to_iri (p), id_to_iri (o)  from rdf_quad table option (with 'inft') where g = iri_to_id ('inft', 0) and p = iri_to_id ('http://www.w3.org/1999/02/22-rdf-syntax-ns#type', 0);
echo both $if $equ $rowcnt 6 "PASSED" "***FAILED";
echo both ": fs gp = rdfstype fo \n";

select id_to_iri (s), id_to_iri (p), id_to_iri (o)  from rdf_quad table option (with 'inft') where g = iri_to_id ('inft', 0) and p = f (iri_to_id ('http://www.w3.org/1999/02/22-rdf-syntax-ns#type', 0));
echo both $if $equ $rowcnt 6 "PASSED" "***FAILED";
echo both ": fs gp = f rdfstype fo \n";


select id_to_iri (s), id_to_iri (p), id_to_iri (o)  from rdf_quad table option (with 'inft') where g = iri_to_id ('inft', 0) and p = f (iri_to_id ('p0', 0));
echo both $if $equ $rowcnt 3 "PASSED" "***FAILED";
echo both ": fs gp = f p0 fo \n";

select id_to_iri (s), id_to_iri (p), id_to_iri (o)  from rdf_quad table option (with 'inft') where g = iri_to_id ('inft', 0) and p = iri_to_id ('p0', 0);
echo both $if $equ $rowcnt 3 "PASSED" "***FAILED";
echo both ": fs gp =  p0 fo \n";


-- fs gp go

select id_to_iri (s), id_to_iri (p), id_to_iri (o)  from rdf_quad table option (with 'inft') where g = iri_to_id ('inft', 0) and p = iri_to_id ('p0', 0) and o = iri_to_id ('ic1p1',0);
echo both $if $equ $rowcnt 1 "PASSED" "***FAILED";
echo both ": fs gp =  p0 go = ic1p1  \n";

select id_to_iri (s), id_to_iri (p), id_to_iri (o)  from rdf_quad table option (with 'inft') where g = iri_to_id ('inft', 0) and p = iri_to_id ('http://www.w3.org/1999/02/22-rdf-syntax-ns#type', 0) and o = iri_to_id ('c2',0);
echo both $if $equ $rowcnt 2 "PASSED" "***FAILED";
echo both ": fs gp =  rdfstype  go = c2  \n";


sparql define input:inference  'inft' select ?s ?p from <inft> where { ?s ?p <c1> . };
echo both $if $equ $rowcnt 3 "PASSED" "***FAILED";
echo both ": fs fp go with  sparql\n";

sparql define input:inference  'inft' select * from <inft> where { ?s ?p <c1> . ?s ?p1 <ic2p1> . };
echo both $if $equ $rowcnt 2 "PASSED" "***FAILED";
echo both ": fs fp go join fs fp go with  sparql\n";

sparql define input:inference  'inft' select * from <inft> where { ?s ?p <c1> . ?s ?p1 <ic2p1> option (inference 'none') . };
echo both $if $equ $rowcnt 1 "PASSED" "***FAILED";
echo both ": fs fp go join fs fp go with  sparql inf none\n";

sparql  select * from <inft> where { ?s ?p <c1> option (inference 'inft') . ?s ?p1 <ic2p1> . };
echo both $if $equ $rowcnt 1 "PASSED" "***FAILED";
echo both ": fs fp go join fs fp go with  sparql inf inft\n";

sparql define input:inference 'inft' select count (*) from <inft> where {?s ?p ?o};

sparql define input:inference 'inft' select ?p count (?o) from <inft> where {?s ?p ?o};

sparql define input:inference 'inft' select count (?p) count (?o) count (distinct ?o)  from <inft> where {?s ?p ?o};

select count distinct ?s ?p ?o from <g> where {?s ?p ?o}


sparql define input:inference 'inft' select ?s ?p count  (?o) from <inft> from <extra> where {?s ?p ?o};

sparql define input:inference 'inft' 
select ?icpe ?cl from <inft> from <extra> where { ?icpe <icpe> ?v . optional { ?icpe a ?cl } };
echo both $if $equ $rowcnt 7 "PASSED" "***FAILED";
echo both ": 2 graph oj \n";


ttlp (
'<syn1-c1> <http://www.w3.org/2002/07/owl#same-as> <ic1> .
<ic1> <http://www.w3.org/2002/07/owl#same-as> <syn2-ic1> .
<syn2-ic1> <http://www.w3.org/2002/07/owl#same-as> <syn3-ic1> .
<syn4-ic1> <http://www.w3.org/2002/07/owl#same-as> <syn3-ic1> .
<syn4-ic1> <http://www.w3.org/2002/07/owl#same-as> <ic1> .
<syn2-ic1> <psyn2> 2 .
', '', 'sas', 0);


sparql define input:inference 'inft'
select ?cl from <inft> from <sas> where { <syn3-ic1> a ?cl };
--echo both $if $equ $last[1] c1 "PASSED" "***FAILED";
--echo both ": same-as with class\n";

sparql define input:inference 'inft'
select ?p ?o  from <inft> from <sas> where { <syn3-ic1> ?p ?o };
--echo both $if $equ $rowcnt 10 "PASSED" "***FAILED";
--echo both ": properties following same-as\n";


sparql define input:inference 'inft'
select ?s from <inft> from <sas> where { ?s <p1> <ic1p1> };

