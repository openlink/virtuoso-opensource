--
--  $Id$
--
--  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
--  project.
--
--  Copyright (C) 1998-2018 OpenLink Software
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


-- Test rdf lit range conditions 
-- run against a 1 u loaded lubm db


select count (*) from rdf_quad where o between 'Ass'and 'Ast';

select count (*) from ro_start where rs_start between 'Ass'and 'Ast';

select count (*) from rdf_obj where ro_long is not null;


explain ('select distinct id_to_iri (p)  from rdf_quad where o between ''Ass'' and ''Ast'' ');
explain ('select distinct id_to_iri (p)  from rdf_quad where o between ''Ass'' and ''Ast'' ');

select distinct (id_to_iri (p))  from rdf_quad where __ro2sq (o) between 'Ass'and 'Ast';
echo both $if $equ $rowcnt 2 "PASSED" "***FAILED";
echo both ": distinct p's w o between Ass and Ast\n";


select top 10  (__ro2sq (o))  from rdf_quad where __ro2sq (o) between 'Ass'and 'Ast';


select distinct top 10   (__ro2sq (o))  from rdf_quad where __ro2sq (o) between 'Ass'and 'Ast' and p = iri_to_id ('http://www.lehigh.edu/~zhp2/2004/0401/univ-bench.owl#name');
echo both $if $equ $last[1] "AssistantProfessor9" "PASSED" "***SKIPPED";
echo both ": distinct o range\n";



sparql select * where { ?s ?p "AssistantProfessor9"};
echo both $if $equ $rowcnt 10 "PASSED" "***FAILED";
echo both ": eq match of str lit o\n";


sparql select ?p where {<http://www.Department13.University0.edu/AssistantProfessor1> ?p ?o . ?o bif:contains '"Assi*"'} limit 10;
echo both $if $equ $rowcnt 2 "PASSED" "***FAILED";
echo both ": trailing contains Assi* 2 distinct preds\n";

sparql select distinct ?p where { ?s ?p ?o . ?o bif:contains '"Assi*"'} limit 10;
echo both $if $equ $rowcnt 2 "PASSED" "***FAILED";
echo both ": Leading contains Assi* 2 distinct preds\n";

create function RRC_TEST_STRINGS () returns any
{
  return vector (
    '', 'a', 'b', 'aa', '012345678', '012345678a', '012345678b', '012345678aa', '012345678ab' );
}
;

create procedure RRC_TEST (in strings any := null)
{
  declare rb_ids any;
  declare ctr1, ctr2, scount, passedcount integer;
  declare cmp_report varchar;
  if (strings is null)
    strings := RRC_TEST_STRINGS ();
  scount := length (strings);
  rb_ids := strings;
  for (ctr1 := 0; ctr1 < scount; ctr1 := ctr1 + 1)
    rb_ids[ctr1] := rdf_box_ro_id (RDF_OBJ_ADD (257, strings[ctr1], 257, dict_new(1)));
  result_names (cmp_report);
  passedcount := 0;
  for (ctr1 := 0; ctr1 < scount; ctr1 := ctr1 + 1)
    {
      declare s1, s1begin varchar;
      s1 := strings[ctr1];
      s1begin := case when (length (s1) <= 10) then s1 else subseq (s1, 0, 10) end;
       for (ctr2 := ctr1; ctr2 < scount; ctr2 := ctr2 + 1)
         {
           declare plain_res, range_res integer;
           plain_res := lt (s1, strings[ctr2]);
           range_res := __rdf_range_check (s1begin, rb_ids[ctr1], strings[ctr2], 11, 0, 0);
           if (plain_res <> range_res)
             result (sprintf ('***FAILED: lt (%s, %s) is %d, range check is %d', s1, strings[ctr2], plain_res, range_res));
           else
             result (sprintf ('PASSED: lt (%s, %s) is %d, range check with %s is %d', s1, strings[ctr2], plain_res, s1begin, range_res));
--             passedcount := passedcount + 1;
           plain_res := lte (s1, strings[ctr2]);
           range_res := __rdf_range_check (s1begin, rb_ids[ctr1], strings[ctr2], 12, 0, 0);
           if (plain_res <> range_res)
             result (sprintf ('***FAILED: lte (%s, %s) is %d, range check is %d', s1, strings[ctr2], plain_res, range_res));
           else
             passedcount := passedcount + 1;
           plain_res := equ (s1, strings[ctr2]);
           range_res := __rdf_range_check (s1begin, rb_ids[ctr1], strings[ctr2], 9, 0, 0);
           if (plain_res <> range_res)
             result (sprintf ('***FAILED: lte (%s, %s) is %d, range check is %d', s1, strings[ctr2], plain_res, range_res));
           else
             passedcount := passedcount + 1;
           plain_res := gt (s1, strings[ctr2]);
           range_res := __rdf_range_check (s1begin, rb_ids[ctr1], strings[ctr2], 13, 0, 0);
           if (plain_res <> range_res)
             result (sprintf ('***FAILED: gt (%s, %s) is %d, range check is %d', s1, strings[ctr2], plain_res, range_res));
           else
             passedcount := passedcount + 1;
           plain_res := gte (s1, strings[ctr2]);
           range_res := __rdf_range_check (s1begin, rb_ids[ctr1], strings[ctr2], 14, 0, 0);
           if (plain_res <> range_res)
             result (sprintf ('***FAILED: gte (%s, %s) is %d, range check is %d', s1, strings[ctr2], plain_res, range_res));
           else
             passedcount := passedcount + 1;
         }
    }
  result (sprintf ('PASSED: %d tests', passedcount));
}
;

RRC_TEST()
;

sparql clear graph <http://big1>;
sparql clear graph <http://big2>;
sparql clear graph <http://big3>;
sparql clear graph <http://big4>;
sparql clear graph <http://mix5>;

sparql insert data in <http://big1> { <s1> <p1> 0, 1, 2, 3, 4, 5, 6, 7, 8, 9 };
sparql insert in <http://big2> { <s1> <p1> `?o1 * 10 + ?o2` } where { graph <http://big1> { <s1> <p1> ?o1 , ?o2 }};
sparql select (count (1)) from <http://big2> where { ?s ?p ?o };
echo both $if $equ $last[1] 100 "PASSED" "***FAILED";
echo both ": count in http://big2\n";

sparql insert in <http://big3> { <s1> <p1> `?o1 * 100 + ?o2` } where { graph <http://big2> { <s1> <p1> ?o1 , ?o2 }};
sparql select (count (1)) from <http://big3> where { ?s ?p ?o };
echo both $if $equ $last[1] 10000 "PASSED" "***FAILED";
echo both ": count in http://big3\n";

sparql insert in <http://big4> { <s1> <p1> `?o1 * 10000 + ?o2` } where { graph <http://big1> { <s1> <p1> ?o1 }  graph <http://big3> { <s1> <p1> ?o2 }};
sparql select (count (1)) from <http://big4> where { ?s ?p ?o };
echo both $if $equ $last[1] 100000 "PASSED" "***FAILED";
echo both ": count in http://big4\n";


cl_text_index(1);
DB.DBA.RDF_OBJ_FT_RULE_ADD ('http://mix5', null, 'big_ins_del');
DB.DBA.RDF_OBJ_FT_RULE_ADD ('http://mix6', null, 'big_ins_del');
DB.DBA.RDF_OBJ_FT_RULE_ADD ('http://mix7', null, 'big_ins_del');
DB.DBA.RDF_OBJ_FT_RULE_ADD ('http://mix8', null, 'big_ins_del');

sparql insert in <http://mix5> { <s1> <p1>
  `iri (bif:sprintf ('http://o%d0', ?o1))`,
  `iri (bif:sprintf ('http://o%d1', ?o1))`,
  `iri (bif:sprintf ('http://o%d2', ?o1))`,
  `iri (bif:sprintf ('http://o%d3', ?o1))`,
  `bif:sprintf ('str%d4', ?o1)`,
  `bif:sprintf ('str%d5', ?o1)`,
  `bif:sprintf ('str%d6', ?o1)`,
  `bif:sprintf ('str%d7', ?o1)`,
  `?o1*10+8`,
  `?o1*10+9` }
where { graph <http://big3> { <s1> <p1> ?o1 } };
sparql select (count (1)) from <http://mix5> where { ?s ?p ?o };
echo both $if $equ $last[1] 100000 "PASSED" "***FAILED";
echo both ": count in http://mix5\n";

sparql insert in <http://mix6> { <s1> <p1> ?o1 } where { graph <http://mix5> { <s1> <p1> ?o1 } };
sparql select (count (1)) from <http://mix6> where { ?s ?p ?o };
echo both $if $equ $last[1] 100000 "PASSED" "***FAILED";
echo both ": count in http://mix6\n";

sparql insert in <http://mix7> { <s1> <p1> ?o1 } where { graph `iri(bif:concat ('http://', 'mix6'))` { <s1> <p1> ?o1 } };
sparql select (count (1)) from <http://mix7> where { ?s ?p ?o };
echo both $if $equ $last[1] 100000 "PASSED" "***FAILED";
echo both ": count in http://mix7\n";
