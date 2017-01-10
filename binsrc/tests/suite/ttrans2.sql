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
--
--set echo on;

-- transitive dt


echo both "SPARQL Triples Transitivity\n";



sparql insert in <psn1> { <psn://1> <knows> <psn://2> };
sparql insert in <psn1> { <psn://1> <knows> <psn://3> };
sparql insert in <psn1> { <psn://2> <knows> <psn://4> };

sparql select * from <psn1> where { ?s ?p ?o };

select sparql_to_sql_text ('
select * from <psn1> where { {select * from <psn1> where { ?s <knows> ?o }}
 option (transitive, t_distinct, t_in(?s), t_out(?o)) . filter (?s=<psn://1>)}
');
sparql
select * from <psn1> where { {select * from <psn1> where { ?s <knows> ?o }}
 option (transitive, t_distinct, t_in(?s), t_out(?o)) . filter (?s=<psn://1>)}
;
echo both $if $equ $rowcnt 3 "PASSED" "***FAILED";
echo both ": trans lr\n";

select sparql_to_sql_text ('
select * from <psn1> where { {select * from <psn1> where { ?s <knows> ?o }}
 option (transitive, t_distinct, t_in(?s), t_out(?o)) . filter (?o=<psn://1>)}
');
sparql
select * from <psn1> where { {select * from <psn1> where { ?s <knows> ?o }}
 option (transitive, t_distinct, t_in(?s), t_out(?o)) . filter (?o=<psn://1>)}
;
echo both $if $equ $rowcnt 0 "PASSED" "***FAILED";
echo both ": trans lr 2\n";


select sparql_to_sql_text ('
select * from <psn1> where { {select * from <psn1> where { ?s <knows> ?o }}
 option (transitive, t_distinct, t_in(?s), t_out(?o)) . filter (?o=<psn://4>)}
');
sparql
select * from <psn1> where { {select * from <psn1> where { ?s <knows> ?o }}
 option (transitive, t_distinct, t_in(?s), t_out(?o)) . filter (?o=<psn://4>)}
;
echo both $if $equ $rowcnt 2 "PASSED" "***FAILED";
echo both ": trans rl\n";

select sparql_to_sql_text ('
select * from <psn1> where { {select * from <psn1> where { ?s <knows> ?o }}
 option (transitive, t_distinct, t_in(?s), t_out(?o)) . filter (?s=<psn://1> && ?o=<psn://4>)}
');
sparql
select * from <psn1> where { {select * from <psn1> where { ?s <knows> ?o }}
 option (transitive, t_distinct, t_in(?s), t_out(?o)) . filter (?s=<psn://1> && ?o=<psn://4>)}
;
echo both $if $equ $rowcnt 1 "PASSED" "***FAILED";
echo both ": trans lrrl 1\n";

select sparql_to_sql_text ('
select * from <psn1> where { {select * from <psn1> where { ?s <knows> ?o }} option
 (transitive, t_distinct, t_direction 1, t_in(?s), t_out(?o)) . filter (?s=<psn://1> && ?o=<psn://4>)}
');
sparql
select * from <psn1> where { {select * from <psn1> where { ?s <knows> ?o }}
 option (transitive, t_distinct, t_direction 1, t_in(?s), t_out(?o)) . filter (?s=<psn://1> && ?o=<psn://4>)}
;
echo both $if $equ $rowcnt 1 "PASSED" "***FAILED";
echo both ": trans lrrl 2\n";

select sparql_to_sql_text ('
select * from <psn1> where { {select * from <psn1> where { ?s <knows> ?o }}
 option (transitive, t_distinct, t_direction 2, t_in(?s), t_out(?o)) . filter (?s=<psn://1> && ?o=<psn://4>)}
');
sparql
select * from <psn1> where { {select * from <psn1> where { ?s <knows> ?o }}
 option (transitive, t_distinct, t_direction 2, t_in(?s), t_out(?o)) . filter (?s=<psn://1> && ?o=<psn://4>)}
;
echo both $if $equ $rowcnt 1 "PASSED" "***FAILED";
echo both ": trans lrrl 3\n";

select sparql_to_sql_text ('
select * from <psn1> where { {select * from <psn1> where { ?s <knows> ?o }}
 option (transitive, t_distinct, t_direction 3, t_shortest_only, t_in(?s), t_out(?o)) . filter (?s=<psn://1> && ?o=<psn://4>)}
');
sparql
select * from <psn1> where { {select * from <psn1> where { ?s <knows> ?o }}
 option (transitive, t_distinct, t_direction 3, t_shortest_only, t_in(?s), t_out(?o)) . filter (?s=<psn://1> && ?o=<psn://4>)}
;
echo both $if $equ $rowcnt 1 "PASSED" "***FAILED";
echo both ": trans lrrl 4\n";

select sparql_to_sql_text ('
select * from <psn1> where { {select * from <psn1> where {{?s <knows> ?o} union {?o <knows> ?s}}}
 option (transitive, t_distinct, t_in(?s), t_out(?o)) . filter (?o=<psn://4>)}
');
sparql select * from <psn1> where { {select * from <psn1> where {{?s <knows> ?o} union {?o <knows> ?s}}}
 option (transitive, t_distinct, t_in(?s), t_out(?o)) . filter (?o=<psn://4>)}
;
echo both $if $equ $rowcnt 3 "PASSED" "***FAILED";
echo both ": trans rl union\n";


select sparql_to_sql_text ('
select * from <psn1> where { {select * from <psn1> where { ?s <knows> ?o }}
 option (transitive, t_distinct, t_direction 1, t_in(?s), t_out(?o), t_step (?s) as ?via, t_step ("path_id") as ?path, t_step ("step_no") as ?step) . filter (?s=<psn://1> && ?o=<psn://4>)}
');
sparql
select * from <psn1> where { {select * from <psn1> where { ?s <knows> ?o }}
 option (transitive, t_distinct, t_direction 1, t_in(?s), t_out(?o), t_step (?s) as ?via, t_step ("path_id") as ?path, t_step ("step_no") as ?step) . filter (?s=<psn://1> && ?o=<psn://4>)}
;
