--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2026 OpenLink Software
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

sparql clear graph 'inft';


ttlp ('
<ic1> a <c1> .
<ic2> a <c2> .
<ic3> a <c3> .
<ic1> <p1> <ic1p1> .
<ic2> <p1> <ic2p1>.
<ic3> <p1> <ic3p1> .
<ic1> <cl2> <c2> .
<subj11-l1> <pd11> <subj11-r1> .
<subj11-r2> <pi11> <subj11-l2> .
<subj11-r3> <pi12> <subj11-l3> .
<subj22-1> <pd22> <subj22-2> .
<subj-t1-1> <pt1> <subj-t1-11> .
<subj-t1-1> <pt1> <subj-t1-12> .
<subj-t1-11> <pt1> <subj-t1-111> .
<subj-t1-11> <pt1> <subj-t1-112> .
<subj-t1-12> <pt1> <subj-t1-121> .
<subj-t1-12> <pt1> <subj-t1-122> .
<subj-t1-111> <pt1> <subj-t1-1111> .
<subj-t1-111> <pt1> <subj-t1-1121> .
<subj-t1-121> <pt1> <subj-t1-1211> .
<subj-t1-121> <pt1> <subj-t1-1221> .
<subj-dt1-1> <pdt1> <subj-dt1-11> .
<subj-dt1-1> <pdt1> <subj-dt1-12> .
<subj-dt1-11> <pdt1> <subj-dt1-111> .
<subj-dt1-11> <pdt1> <subj-dt1-112> .
<subj-dt1-12> <pdt1> <subj-dt1-121> .
<subj-dt1-12> <pdt1> <subj-dt1-122> .
', '', 'inft');

ttlp ('
<ic1> <icpe> 1 .
<ic2> <icpe> 2 .
<ic3> <icpe> 3 .
<ic4> <icpe> 4 .
', '', 'extra');


ttlp (' @prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .
@prefix owl: <http://www.w3.org/2002/07/owl#> .
<c2> rdfs:subClassOf <c1> .
  <c3> rdfs:subClassOf <c2> .
  <c5> rdfs:subClassOf <c4> .
<p1> rdfs:subPropertyOf <p0> .
<pi11> owl:inverseOf <pd11> .
<pi12> owl:inverseOf <pd11> .
<pd11> owl:inverseOf <pi11> .
<pd22> a owl:SymmetricProperty .
<pdt1> a owl:SymmetricProperty, owl:TransitiveProperty .
<pt1> a owl:TransitiveProperty .
', '', 'sc');

ttlp ('<tarzan> <name> \"Tarzan\".', '', 'tarzan');
ttlp ('<tarzan> <name> \"Tarzan\"@en.', '', 'tarzan');
ttlp ('<tarzan> <name> \"Tarzan\"^^<name>.', '', 'tarzan');

sparql select * where {{ ?s ?p "Tarzan"} union { ?s ?p "Tarzan"@en } union { ?s ?p "Tarzan"^^<name> }};
echo both $if $equ $rowcnt 3 "PASSED" "**FAILED";
echo both ": 3 tarzans\n";

sparql select * where {{ ?s ?p "Tarzan"} union { ?s ?p "Tarzan"@en } union { ?s ?p "Tarzan"^^<name> }};
echo both $if $equ $rowcnt 3 "PASSED" "**FAILED";
echo both ": 3 tarzans 2\n";



create procedure f (in q any) {return q;};

rdfs_rule_set ('inft', 'sc');

sparql define input:inference 'inft' select * from <inft> where { ?s <pd11> ?o };
echo both $if $equ $rowcnt 3 "PASSED" "***FAILED";
echo both ": 3 rows with pd11 and 2 inverses, pi11 and pi12\n";

sparql define input:inference 'inft' select * from <inft> where { ?s <pi11> ?o };
echo both $if $equ $rowcnt 2 "PASSED" "***FAILED";
echo both ": 2 rows with pi11 and 1 inverse, pd11\n";

sparql define input:inference 'inft' select * from <inft> where { ?s <pi12> ?o };
echo both $if $equ $rowcnt 2 "PASSED" "***FAILED";
echo both ": 2 rows with pi12 and 1 inverse, pd11\n";

sparql define input:inference 'inft' select * from <inft> where { ?s <pd22> ?o };
echo both $if $equ $rowcnt 2 "PASSED" "***FAILED";
echo both ": 2 rows with symmetric pd22\n";

sparql define input:inference 'inft' select * from <inft> where { ?s  <pt1> ?o . filter (?s = <subj-t1-11>) };
echo both $if $equ $rowcnt 4 "PASSED" "***FAILED";
echo both ": 4 rows with unidirectional transitive pt1\n";

sparql define input:inference 'inft' select * from <inft> where { ?s  <pdt1> ?o option (T_DISTINCT) . filter (?s = <subj-dt1-11>) };
echo both $if $equ $rowcnt 6 "PASSED" "***FAILED";
echo both ": 6 rows with symmetric transitive pdt1\n";

select id_to_iri (s) from rdf_quad table option (with 'inft') where g = iri_to_id ('inft',0) and p = iri_to_id ('http://www.w3.org/1999/02/22-rdf-syntax-ns#type', 0) and o = iri_to_id ('c1', 0);
echo both $if $equ $rowcnt 3 "PASSED" "***FAILED";
echo both ":  3 inst of c1 without f \n";

select id_to_iri (s) from rdf_quad table option (with 'inft') where g = iri_to_id ('inft',0) and p = f (iri_to_id ('http://www.w3.org/1999/02/22-rdf-syntax-ns#type', 0)) and o = f (iri_to_id ('c1', 0));
echo both $if $equ $rowcnt 3 "PASSED" "***FAILED";
echo both ":  3 inst of c1 with f \n";


select id_to_iri (s), id_to_iri (p), id_to_iri (o) from rdf_quad table option (with 'inft') where g = iri_to_id ('inft', 0);
echo both $if $equ $rowcnt 33 "PASSED" "***FAILED";
echo both ": 33 triples in g inft\n";



select id_to_iri (a.s) from rdf_quad a table option (with 'inft'), rdf_quad b table option (with 'inft')
where a.g = iri_to_id ('inft', 0) and b.g = iri_to_id ('inft', 0)
	and a.o = iri_to_id ('c1', 0) and b.o = iri_to_id ('c1', 0)
	and a.p = iri_to_id ('http://www.w3.org/1999/02/22-rdf-syntax-ns#type', 0)
	and b.p = iri_to_id ('http://www.w3.org/1999/02/22-rdf-syntax-ns#type', 0)
	and a.s = b.s;

echo both $if $equ $rowcnt 3 "PASSED" "***FAILED";
echo both ": inx int on o = c1 and p = rdfs:type\n";


explain ('select 1 from rdf_quad a table option (with ''inft''), rdf_quad b table option (with ''inft'')
where a.g = iri_to_id (''inft'', 0) and b.g = iri_to_id (''inft'', 0)
	and a.o = iri_to_id (''c1'', 0) and b.o = iri_to_id (''c1'', 0)
	and a.p = iri_to_id (''http://www.w3.org/1999/02/22-rdf-syntax-ns#type'', 0)
	and b.p = iri_to_id (''http://www.w3.org/1999/02/22-rdf-syntax-ns#type'', 0)
	and a.s = b.s', -5);



select s, p from rdf_quad table option (with 'inft') where g = iri_to_id ('inft', 0) and o = iri_to_id ('c1', 0);
echo both $if $equ $rowcnt 3 "PASSED" "***FAILED";
echo both ": o = c1 3 rows\n";

drop table DB.DBA.ps if exists;

create table ps (ps iri_id primary key);

insert into ps values (iri_to_id ('c1', 1));
insert into ps values (iri_to_id ('c4', 1));

select ps, s, p, o from ps left join  rdf_quad table option (with 'inft') on g = iri_to_id ('inft', 0) and  ps  = o;
echo both $if $equ $rowcnt 4 "PASSED" "***FAILED";
echo both ": inf oj rowcnt\n";



--- Complete combinations
--- fs fp fo
select id_to_iri (s), id_to_iri (p), id_to_iri (o)  from rdf_quad table option (with 'inft') where g = iri_to_id ('inft', 0);
echo both $if $equ $rowcnt 33 "PASSED" "***FAILED";
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
echo both $if $neq $state OK "PASSED" "***FAILED";
echo both ": fs fp go join fs fp go with  sparql inf none STATE=" $state " MESSAGE=" $message "\n" ;

sparql  select * from <inft> where { ?s ?p <c1> option (inference 'inft') . ?s ?p1 <ic2p1> . };
echo both $if $equ $rowcnt 1 "PASSED" "***FAILED";
echo both ": fs fp go join fs fp go with  sparql inf inft\n";

sparql define input:inference 'inft' select count (*) from <inft> where {?s ?p ?o};

sparql define input:inference 'inft' select ?p count (?o) from <inft> where {?s ?p ?o};

sparql define input:inference 'inft' select count (?p) count (?o) count (distinct ?o)  from <inft> where {?s ?p ?o};

sparql select count distinct ?s ?p ?o from <g> where {?s ?p ?o};


sparql define input:inference 'inft' select ?s ?p count  (?o) from <inft> from <extra> where {?s ?p ?o};

sparql define input:inference 'inft'
select ?icpe ?cl from <inft> from <extra> where { ?icpe <icpe> ?v . optional { ?icpe a ?cl } };
echo both $if $equ $rowcnt 7 "PASSED" "***FAILED";
echo both ": 2 graph oj \n";


ttlp (
'<syn1-c1> <http://www.w3.org/2002/07/owl#sameAs> <ic1> .
<ic1> <http://www.w3.org/2002/07/owl#sameAs> <syn2-ic1> .
<syn2-ic1> <http://www.w3.org/2002/07/owl#sameAs> <syn3-ic1> .
<syn4-ic1> <http://www.w3.org/2002/07/owl#sameAs> <syn3-ic1> .
<syn4-ic1> <http://www.w3.org/2002/07/owl#sameAs> <ic1> .
<syn2-ic1> <psyn2> 2 .
', '', 'sas', 0);


sparql define input:inference 'inft' define input:same-as "yes"
select ?cl from <inft> from <sas> where { <syn3-ic1> a ?cl };
echo both $if $equ $last[1] c1 "PASSED" "***FAILED";
echo both ": same-as with class\n";

sparql define input:inference 'inft' define input:same-as "yes"
select ?p ?o  from <inft> from <sas> where { <syn3-ic1> ?p ?o };
echo both $if $equ $rowcnt 10 "PASSED" "***FAILED";
echo both ": properties following same-as\n";


sparql define input:inference 'inft'
select ?s from <inft> from <sas> where { ?s <p1> <ic1p1> };


ttlp (' @prefix owl: <http://www.w3.org/2002/07/owl#> .
 @prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .
<p2> rdfs:subPropertyOf <p1> .
<p1> rdfs:subPropertyOf <p0> .
<sas-p1>  owl:sameAs <p1> .
<sas-p12>  owl:sameAs <sas-p1> .
<ic1> a <c1> .
<ic1> <p1> <ic1p1> .
<ic1> <p2> <ic1p2> .
<ic1> <sas-p1> <ic1sas-p1> .
', '', 'sas-p');

rdfs_rule_set ('sas-p', 'sas-p');

sparql define input:inference 'sas-p' define input:same-as "yes"
select * from <sas-p> where { ?s <p0> ?o };
echo both $if $equ $rowcnt 3 "PASSED" "***FAILED";
echo both ": same-as for super property\n";

sparql define input:inference 'sas-p' define input:same-as "yes"
select distinct * from <sas-p> where { ?s <p1> ?o };
echo both $if $equ $rowcnt 3 "PASSED" "***FAILED";
echo both ": same-as for property\n";

sparql define input:inference 'sas-p' define input:same-as "yes"
select distinct * from <sas-p> where { ?s <sas-p1> ?o };
echo both $if $equ $rowcnt 3 "PASSED" "***FAILED";
echo both ": same-as for sameAs property\n";


create procedure s_list (in ctx varchare, in iri varchar, in axis int)
{
  declare inx, a any;
  a := rdf_super_sub_list (ctx, iri_to_id (iri), axis);
  result_names 	(iri);
  for (inx := 0;	 inx < length (a); inx := inx + 1)
    result (id_to_iri (a[inx]));
}

sparql clear graph <g1>;
sparql clear graph <g2>;
sparql clear graph <g3>;
sparql insert into <g1> { <s1> <p> 1; <q> 10 . };
sparql insert into <g2> { <s2> <p> 2; <q> 20 . };
sparql insert into <g3> { <s3> <p> 3; <q> 30 . };

sparql select * where { graph ?g { ?s ?p ?o . filter (?g = <g3>) }};
echo both $if $equ $rowcnt 2 "PASSED" "***FAILED";
echo both ": 2 rows filter (?g = <g3>) \n";

sparql select * where { graph ?g { ?s <p> ?o . filter (?g = <g1>) }};
echo both $if $equ $rowcnt 1 "PASSED" "***FAILED";
echo both ": 1 row { ?s <p> ?o . filter (?g = <g1>) } \n";

sparql select * where { graph ?g { ?s <p> ?o . filter (?g in (<g1>, <g2>, <g3>)) }};
echo both $if $equ $rowcnt 3 "PASSED" "***FAILED";
echo both ": 3 rows ?s <p> ?o . filter (?g in (<g1>, <g2>, <g3>)) \n";

explain('sparql select * where { graph ?g { ?s ?p ?o . filter (?s in (<s1>, <s2>, <s3>)) }}');
explain('sparql select * where { graph ?g { ?s ?p ?o . filter (?g in (<g1>, <g2>, <g3>)) }}');

sparql select * where { graph ?g { ?s ?p ?o . filter (?s in (<s1>, <s2>, <s3>)) }};
echo both $if $equ $rowcnt 6 "PASSED" "***FAILED";
echo both ": 6 rows ?s in (<s1>, <s2>, <s3>) \n";

sparql select * where { graph ?g { ?s ?p ?o . filter (?g in (<g1>, <g2>, <g3>)) }};
echo both $if $equ $rowcnt 6 "PASSED" "***FAILED";
echo both ": 6 rows ?g in (<g1>, <g2>, <g3>) \n";

select * from DB.DBA.RDF_QUAD table option (index RDF_QUAD) where g in ( __i2id ( UNAME'g3' ) , __i2id ( UNAME'g2' ) , __i2id ( UNAME'g1' ));
echo both $if $equ $rowcnt 6 "PASSED" "***FAILED";
echo both ": 6 rows g in (g1, g2, g3) by PK \n";

select * from DB.DBA.RDF_QUAD table option (index RDF_QUAD) where s in ( __i2id ( UNAME's3' ) , __i2id ( UNAME's2' ) , __i2id ( UNAME's1' ));
echo both $if $equ $rowcnt 6 "PASSED" "***FAILED";
echo both ": 6 rows s in (s1, s2, s3) by PK\n";


select * from DB.DBA.RDF_QUAD table option (index RDF_QUAD_GS) where g in ( __i2id ( UNAME'g3' ) , __i2id ( UNAME'g2' ) , __i2id ( UNAME'g1' ));
echo both $if $equ $rowcnt 6 "PASSED" "***FAILED";
echo both ": 6 rows g in (g1, g2, g3) by GS\n";

select * from DB.DBA.RDF_QUAD table option (index RDF_QUAD_SP) where s in ( __i2id ( UNAME's3' ) , __i2id ( UNAME's2' ) , __i2id ( UNAME's1' ));
echo both $if $equ $rowcnt 6 "PASSED" "***FAILED";
echo both ": 6 rows s in (s1, s2, s3) by SP\n";

explain('sparql select * where { graph ?g { ?s ?p ?o . filter (?o in (10,20,30)) }}');
sparql select * where { graph ?g { ?s ?p ?o . filter (?o in (10,20,30)) }};
explain ('select * from DB.DBA.RDF_QUAD table option (index RDF_QUAD) where o in (10,20,30)');
select * from DB.DBA.RDF_QUAD table option (index RDF_QUAD_OP) where o in (10,20,30);

sparql clear graph <g_param>;
sparql insert into <g_param> { <s_param> <p> 10 ; <r> <o_param> . };

create procedure DB.DBA.RDF_OBJ_SPARQL_PARAM_COUNT (in obj any)
{
  return (sparql select count (*) from <g_param> where { ?s ?p ?o . filter (?o = ?:obj) });
}
;

select DB.DBA.RDF_OBJ_SPARQL_PARAM_COUNT (10);
echo both $if $equ $LAST[1] 1 "PASSED" "***FAILED";
echo both ": 1 row SPARQL ?o = ?:param numeric literal\n";

select DB.DBA.RDF_OBJ_SPARQL_PARAM_COUNT (UNAME'o_param');
echo both $if $equ $LAST[1] 1 "PASSED" "***FAILED";
echo both ": 1 row SPARQL ?o = ?:param IRI\n";

-- ============================================================
-- RDF 1.2 / iri_id_8 parameter regressions in pre-compiled SPARQL.
-- Mirrors the inlined patterns in binsrc/graphql/graphql.sql that
-- commit de30cc0f45 routed through exec() as a workaround.
-- These tests must pass without iri()-wrapping the parameters and
-- without falling back to dynamic SPASQL.
-- ============================================================

sparql clear graph <urn:g_iri12>;

sparql prefix : <urn:rdf12:>
prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#>
prefix gql: <http://www.openlinksw.com/schemas/graphql#>
insert into <urn:g_iri12> {
  :Top    a rdfs:Class .
  :Super  a rdfs:Class ; rdfs:subClassOf :Top .
  :Sub    a rdfs:Class ; rdfs:subClassOf :Super .
  :propA  rdfs:domain :Super ; rdfs:range :Top ; gql:field :fldA ; gql:type :TypeA .
  :propB  rdfs:domain :Top   ; rdfs:range :Top ; gql:field :fldB ; gql:type :TypeB .
};

-- (A) ?o = ?:obj when the parameter slot is declared iri_id_8.
-- Same shape as RDF_OBJ_SPARQL_PARAM_COUNT above, but with the
-- caller-side declaration that GraphQL uses (GQL_IID returns iri_id_8).
create procedure DB.DBA.RDF_GQL_O_PARAM_IID8 (in obj iri_id_8)
{
  return (sparql select count (*) from <urn:g_iri12>
                  where { ?s ?p ?o . filter (?o = ?:obj) });
}
;

select DB.DBA.RDF_GQL_O_PARAM_IID8 (iri_to_id ('urn:rdf12:Top'));
echo both $if $equ $LAST[1] 4 "PASSED" "***FAILED";
echo both ": 4 rows SPARQL ?o = ?:iri_id_8 param (Top is referenced 4x)\n";

select DB.DBA.RDF_GQL_O_PARAM_IID8 (iri_to_id ('urn:rdf12:Super'));
echo both $if $equ $LAST[1] 2 "PASSED" "***FAILED";
echo both ": 2 rows SPARQL ?o = ?:iri_id_8 param (Super is referenced 2x)\n";

-- (B) ?:cls rdfs:subClassOf* ?domain — iri_id_8 parameter at the
-- start of a transitive property path inside a graph block.
create procedure DB.DBA.RDF_GQL_SUBCLS_PARAM (in cls iri_id_8, in fld iri_id_8)
{
  declare cnt int;
  cnt := 0;
  for select "prop"
        from (sparql define input:storage ""
              prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#>
              prefix gql: <http://www.openlinksw.com/schemas/graphql#>
              select ?prop where {
                graph <urn:g_iri12> {
                  ?:cls rdfs:subClassOf* ?domain .
                  ?prop rdfs:domain ?domain ; gql:field ?:fld .
                }}) sub do {
    cnt := cnt + 1;
  }
  return cnt;
}
;

select DB.DBA.RDF_GQL_SUBCLS_PARAM (iri_to_id ('urn:rdf12:Sub'),
                                    iri_to_id ('urn:rdf12:fldA'));
echo both $if $equ $LAST[1] 1 "PASSED" "***FAILED";
echo both ": 1 row SPARQL ?:iid8 rdfs:subClassOf* ?d (Sub->Super matches propA)\n";

select DB.DBA.RDF_GQL_SUBCLS_PARAM (iri_to_id ('urn:rdf12:Sub'),
                                    iri_to_id ('urn:rdf12:fldB'));
echo both $if $equ $LAST[1] 1 "PASSED" "***FAILED";
echo both ": 1 row SPARQL ?:iid8 rdfs:subClassOf* ?d (Sub->Top matches propB)\n";

-- (C) Full GraphQL pattern: subClassOf* + OPTIONAL with shared
-- ?domain/?range across the optional join, all with iri_id_8 params.
-- This is the exact shape from GQL_CONSTRUCT pre-de30cc0f45.
create procedure DB.DBA.RDF_GQL_SUBCLS_OPT (in cls iri_id_8, in arg iri_id_8, in fld iri_id_8)
{
  declare cnt int;
  cnt := 0;
  for select "prop0", "prop1"
        from (sparql define input:storage ""
              prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#>
              prefix gql: <http://www.openlinksw.com/schemas/graphql#>
              select ?prop0 ?prop1 where {
                graph <urn:g_iri12> {
                  ?:cls rdfs:subClassOf* ?domain .
                  ?prop0 rdfs:domain ?domain ; gql:field ?:arg .
                  optional {
                    [] rdfs:domain ?domain ; rdfs:range ?range ; gql:field ?:fld .
                    ?prop1 rdfs:domain ?range ; gql:field ?:arg .
                  }
                }}) sub do {
    cnt := cnt + 1;
  }
  return cnt;
}
;

select DB.DBA.RDF_GQL_SUBCLS_OPT (iri_to_id ('urn:rdf12:Sub'),
                                  iri_to_id ('urn:rdf12:fldA'),
                                  iri_to_id ('urn:rdf12:fldB'));
echo both $if $equ $LAST[1] 1 "PASSED" "***FAILED";
echo both ": 1 row SPARQL subClassOf* + OPTIONAL all-iid8 params\n";

-- (D) Same as (B) but with the graph IRI itself bound from an iri_id_8
-- parameter (?:g rather than the literal <urn:g_iri12>). This is the
-- exact GQL_CONSTRUCT shape: graph ?:g_iid { ?:cls subClassOf* ... }.
create procedure DB.DBA.RDF_GQL_SUBCLS_GPARAM (in g_iid iri_id_8, in cls iri_id_8, in fld iri_id_8)
{
  declare cnt int;
  cnt := 0;
  for select "prop"
        from (sparql define input:storage ""
              prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#>
              prefix gql: <http://www.openlinksw.com/schemas/graphql#>
              select ?prop where {
                graph ?:g_iid {
                  ?:cls rdfs:subClassOf* ?domain .
                  ?prop rdfs:domain ?domain ; gql:field ?:fld .
                }}) sub do {
    cnt := cnt + 1;
  }
  return cnt;
}
;

-- The graph-parameter variant must return the same cardinality as the
-- literal-graph variant (B): SPARQL semantics are identical when ?:g is
-- bound to the same IRI. If this returns more than 1 row, the engine is
-- emitting a duplicating join for `graph ?:g` + property path.
select DB.DBA.RDF_GQL_SUBCLS_GPARAM (iri_to_id ('urn:g_iri12'),
                                     iri_to_id ('urn:rdf12:Sub'),
                                     iri_to_id ('urn:rdf12:fldA'));
echo both $if $equ $LAST[1] 1 "PASSED" "***FAILED";
echo both ": 1 row SPARQL graph ?:iid8 { ?:iid8 subClassOf* } (Sub->Super propA)\n";

select DB.DBA.RDF_GQL_SUBCLS_GPARAM (iri_to_id ('urn:g_iri12'),
                                     iri_to_id ('urn:rdf12:Sub'),
                                     iri_to_id ('urn:rdf12:fldB'));
echo both $if $equ $LAST[1] 1 "PASSED" "***FAILED";
echo both ": 1 row SPARQL graph ?:iid8 { ?:iid8 subClassOf* } (Sub->Top propB)\n";

-- (E) Full GraphQL pattern with graph ?:g_iid AND subClassOf* AND OPTIONAL,
-- four iri_id_8 parameters — the exact shape of the inlined query at
-- graphql.sql:825-832 (pre-de30cc0f45).
create procedure DB.DBA.RDF_GQL_SUBCLS_OPT_GPARAM (in g_iid iri_id_8, in cls iri_id_8, in arg iri_id_8, in fld iri_id_8)
{
  declare cnt int;
  cnt := 0;
  for select "prop0", "prop1"
        from (sparql define input:storage ""
              prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#>
              prefix gql: <http://www.openlinksw.com/schemas/graphql#>
              select ?prop0 ?prop1 where {
                graph ?:g_iid {
                  ?:cls rdfs:subClassOf* ?domain .
                  ?prop0 rdfs:domain ?domain ; gql:field ?:arg .
                  optional {
                    [] rdfs:domain ?domain ; rdfs:range ?range ; gql:field ?:fld .
                    ?prop1 rdfs:domain ?range ; gql:field ?:arg .
                  }
                }}) sub do {
    cnt := cnt + 1;
  }
  return cnt;
}
;

-- Must equal (C) result of 1; same data, same query semantics.
select DB.DBA.RDF_GQL_SUBCLS_OPT_GPARAM (iri_to_id ('urn:g_iri12'),
                                         iri_to_id ('urn:rdf12:Sub'),
                                         iri_to_id ('urn:rdf12:fldA'),
                                         iri_to_id ('urn:rdf12:fldB'));
echo both $if $equ $LAST[1] 1 "PASSED" "***FAILED";
echo both ": 1 row SPARQL graph ?:iid8 + subClassOf* + OPTIONAL all-iid8\n";

-- Diagnostic: dump the rewritten procedure bodies so the SPARQL->SQL
-- emission is visible. Compare RDF_GQL_SUBCLS_PARAM (literal graph) vs
-- RDF_GQL_SUBCLS_GPARAM (graph ?:g_iid) — under correct semantics the
-- inner SQL must produce equal cardinalities for the same data.
-- Literal-graph baseline (B-shape): graph IRI is a literal.
select '--- LITERAL GRAPH (B) ---' as marker;
select cast (sparql_to_sql_text ('
  define input:storage ""
  prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#>
  prefix gql: <http://www.openlinksw.com/schemas/graphql#>
  select ?prop where {
    graph <urn:g_iri12> {
      <urn:rdf12:Sub> rdfs:subClassOf* ?domain .
      ?prop rdfs:domain ?domain ; gql:field <urn:rdf12:fldA> .
    }}') as varchar (10000));

-- Variable-graph (D-shape): graph IRI is a free variable.
-- After rewrite, the SQL shows whether the engine emits a duplicating
-- (cross-product) join between the property-path zero-step and the
-- unconstrained graph-IRI scan.
select '--- VARIABLE GRAPH (D) ---' as marker;
select cast (sparql_to_sql_text ('
  define input:storage ""
  prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#>
  prefix gql: <http://www.openlinksw.com/schemas/graphql#>
  select ?prop where {
    graph ?g {
      <urn:rdf12:Sub> rdfs:subClassOf* ?domain .
      ?prop rdfs:domain ?domain ; gql:field <urn:rdf12:fldA> .
    }}') as varchar (10000));

-- (F) cciso-shaped reproduction: a graph that has rdfs:domain and
-- gql:field triples but NO rdfs:subClassOf triples at all. The
-- transitive `?:cls rdfs:subClassOf* ?domain` zero-step must still
-- bind ?domain := ?:cls (RDF/SPARQL property-path semantics) so that
-- the subsequent `?prop rdfs:domain ?domain ; gql:field ?:fld` can
-- match. If the engine emits a SQL TRANSITIVE whose inner SCAN is
-- filtered by P=subClassOf and that scan is empty, T_MIN(0) must
-- still emit the (input,input) zero-step row.
sparql clear graph <urn:g_iri12b>;

sparql prefix : <urn:rdf12:>
prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#>
prefix gql: <http://www.openlinksw.com/schemas/graphql#>
insert into <urn:g_iri12b> {
  :Country a rdfs:Class .
  :code   rdfs:domain :Country ; gql:field :fldCode ; gql:type :ID .
  :name   rdfs:domain :Country ; gql:field :fldName ; gql:type :String .
};

create procedure DB.DBA.RDF_GQL_SUBCLS_NOSUB (in g_iid iri_id_8, in cls iri_id_8, in fld iri_id_8)
{
  declare cnt int;
  cnt := 0;
  for select "prop"
        from (sparql define input:storage ""
              prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#>
              prefix gql: <http://www.openlinksw.com/schemas/graphql#>
              select ?prop where {
                graph ?:g_iid {
                  ?:cls rdfs:subClassOf* ?domain .
                  ?prop rdfs:domain ?domain ; gql:field ?:fld .
                }}) sub do {
    cnt := cnt + 1;
  }
  return cnt;
}
;

-- The graph has zero subClassOf triples; ?:cls rdfs:subClassOf* ?domain
-- must still bind ?domain := ?:cls via the zero-step, yielding 1 row.
select DB.DBA.RDF_GQL_SUBCLS_NOSUB (iri_to_id ('urn:g_iri12b'),
                                    iri_to_id ('urn:rdf12:Country'),
                                    iri_to_id ('urn:rdf12:fldCode'));
echo both $if $equ $LAST[1] 1 "PASSED" "***FAILED";
echo both ": 1 row SPARQL graph ?:iid8 subClassOf* zero-step (no subClassOf in graph)\n";

select DB.DBA.RDF_GQL_SUBCLS_NOSUB (iri_to_id ('urn:g_iri12b'),
                                    iri_to_id ('urn:rdf12:Country'),
                                    iri_to_id ('urn:rdf12:fldName'));
echo both $if $equ $LAST[1] 1 "PASSED" "***FAILED";
echo both ": 1 row SPARQL graph ?:iid8 subClassOf* zero-step (fldName)\n";

-- Literal-graph control: same data, literal graph IRI. Sanity check
-- that the zero-step works in the simpler case.
create procedure DB.DBA.RDF_GQL_SUBCLS_NOSUB_LIT (in cls iri_id_8, in fld iri_id_8)
{
  declare cnt int;
  cnt := 0;
  for select "prop"
        from (sparql define input:storage ""
              prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#>
              prefix gql: <http://www.openlinksw.com/schemas/graphql#>
              select ?prop where {
                graph <urn:g_iri12b> {
                  ?:cls rdfs:subClassOf* ?domain .
                  ?prop rdfs:domain ?domain ; gql:field ?:fld .
                }}) sub do {
    cnt := cnt + 1;
  }
  return cnt;
}
;

select DB.DBA.RDF_GQL_SUBCLS_NOSUB_LIT (iri_to_id ('urn:rdf12:Country'),
                                        iri_to_id ('urn:rdf12:fldCode'));
echo both $if $equ $LAST[1] 1 "PASSED" "***FAILED";
echo both ": 1 row SPARQL literal-graph subClassOf* zero-step (no subClassOf in graph)\n";

-- Cleanup
drop procedure DB.DBA.RDF_GQL_O_PARAM_IID8;
drop procedure DB.DBA.RDF_GQL_SUBCLS_PARAM;
drop procedure DB.DBA.RDF_GQL_SUBCLS_OPT;
drop procedure DB.DBA.RDF_GQL_SUBCLS_GPARAM;
drop procedure DB.DBA.RDF_GQL_SUBCLS_OPT_GPARAM;
drop procedure DB.DBA.RDF_GQL_SUBCLS_NOSUB;
drop procedure DB.DBA.RDF_GQL_SUBCLS_NOSUB_LIT;
sparql clear graph <urn:g_iri12>;
sparql clear graph <urn:g_iri12b>;

--explain ('delete from rdf_quad table option (index RDF_QUAD) where g in ( __i2id ( UNAME\'g3\' ) , __i2id ( UNAME\'g2\' ) , __i2id ( UNAME\'g1\' ))');
--explain ('delete from rdf_quad table option (index RDF_QUAD_GS) where g in ( __i2id ( UNAME\'g3\' ) , __i2id ( UNAME\'g2\' ) , __i2id ( UNAME\'g1\' ))');
--delete from rdf_quad table option (index RDF_QUAD_GS) where g in ( __i2id ( UNAME'g3' ) , __i2id ( UNAME'g2' ) );
--select * from DB.DBA.RDF_QUAD table option (index RDF_QUAD) where s in ( __i2id ( UNAME's3' ) , __i2id ( UNAME's2' ) , __i2id ( UNAME's1' ));
--echo both $if $equ $rowcnt 2 "PASSED" "***FAILED";
--echo both ": 2 rows s in (s1, s2, s3) by PK\n";


--select * from DB.DBA.RDF_QUAD table option (index RDF_QUAD_GS) where g in ( __i2id ( UNAME'g3' ) , __i2id ( UNAME'g2' ) , __i2id ( UNAME'g1' ));
--echo both $if $equ $rowcnt 2 "PASSED" "***FAILED";
--echo both ": 2 rows g in (g1, g2, g3) by GS\n";
TTLP('
@prefix ex: <http://example.org/> .
@prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
@prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .

# Class definitions
ex:Animal rdf:type rdfs:Class .
ex:Mammal rdf:type rdfs:Class ;
          rdfs:subClassOf ex:Animal .
ex:Bird rdf:type rdfs:Class ;
        rdfs:subClassOf ex:Animal .

# Individuals of Mammals
ex:Lion rdf:type ex:Mammal .
ex:Tiger rdf:type ex:Mammal .
ex:Elephant rdf:type ex:Mammal .

# Individuals of Birds
ex:Eagle rdf:type ex:Bird .
ex:Sparrow rdf:type ex:Bird .
ex:Penguin rdf:type ex:Bird .

# Relationships between individuals
ex:Lion ex:hasFriend ex:Tiger .
ex:Eagle ex:preysOn ex:Sparrow .
ex:Penguin ex:livesWith ex:PenguinGroup .

# A group for Penguins
ex:PenguinGroup rdf:type ex:Bird .
', 'http://example.org/', 'urn:animal:data');
rdfs_rule_set('animal','urn:animal:data');

sparql define input:inference "animal" select ?s ?p ?o from <urn:animal:data> { ?s ?p ?o . filter (?o = <http://example.org/Animal>)};
echo both $if $equ $rowcnt 9 "PASSED" "***FAILED";
echo both ": 9 rows for ex:Animal by ?o=<Animal>\n";
sparql define input:inference "animal" select ?s ?p ?o from <urn:animal:data> { ?s ?p ?o . filter (strends(str(?o), 'Animal') ) };
echo both $if $equ $rowcnt 9 "PASSED" "***FAILED";
echo both ": 9 rows for ex:Animal by post filer by strends(?o,Animal)\n";
