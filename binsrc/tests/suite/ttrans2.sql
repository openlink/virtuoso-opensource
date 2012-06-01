--set echo on;

-- transitive dt


ECHO BOTH "SPARQL Triples Transitivity\n";



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
ECHO BOTH $IF $EQU $ROWCNT 3 "PASSED" "***FAILED";
ECHO BOTH ": trans lr\n";

select sparql_to_sql_text ('
select * from <psn1> where { {select * from <psn1> where { ?s <knows> ?o }}
 option (transitive, t_distinct, t_in(?s), t_out(?o)) . filter (?o=<psn://1>)}
');
sparql
select * from <psn1> where { {select * from <psn1> where { ?s <knows> ?o }}
 option (transitive, t_distinct, t_in(?s), t_out(?o)) . filter (?o=<psn://1>)}
;
ECHO BOTH $IF $EQU $ROWCNT 0 "PASSED" "***FAILED";
ECHO BOTH ": trans lr 2\n";


select sparql_to_sql_text ('
select * from <psn1> where { {select * from <psn1> where { ?s <knows> ?o }}
 option (transitive, t_distinct, t_in(?s), t_out(?o)) . filter (?o=<psn://4>)}
');
sparql
select * from <psn1> where { {select * from <psn1> where { ?s <knows> ?o }}
 option (transitive, t_distinct, t_in(?s), t_out(?o)) . filter (?o=<psn://4>)}
;
ECHO BOTH $IF $EQU $ROWCNT 2 "PASSED" "***FAILED";
ECHO BOTH ": trans rl\n";

select sparql_to_sql_text ('
select * from <psn1> where { {select * from <psn1> where { ?s <knows> ?o }}
 option (transitive, t_distinct, t_in(?s), t_out(?o)) . filter (?s=<psn://1> && ?o=<psn://4>)}
');
sparql
select * from <psn1> where { {select * from <psn1> where { ?s <knows> ?o }}
 option (transitive, t_distinct, t_in(?s), t_out(?o)) . filter (?s=<psn://1> && ?o=<psn://4>)}
;
ECHO BOTH $IF $EQU $ROWCNT 1 "PASSED" "***FAILED";
ECHO BOTH ": trans lrrl 1\n";

select sparql_to_sql_text ('
select * from <psn1> where { {select * from <psn1> where { ?s <knows> ?o }} option
 (transitive, t_distinct, t_direction 1, t_in(?s), t_out(?o)) . filter (?s=<psn://1> && ?o=<psn://4>)}
');
sparql
select * from <psn1> where { {select * from <psn1> where { ?s <knows> ?o }}
 option (transitive, t_distinct, t_direction 1, t_in(?s), t_out(?o)) . filter (?s=<psn://1> && ?o=<psn://4>)}
;
ECHO BOTH $IF $EQU $ROWCNT 1 "PASSED" "***FAILED";
ECHO BOTH ": trans lrrl 2\n";

select sparql_to_sql_text ('
select * from <psn1> where { {select * from <psn1> where { ?s <knows> ?o }}
 option (transitive, t_distinct, t_direction 2, t_in(?s), t_out(?o)) . filter (?s=<psn://1> && ?o=<psn://4>)}
');
sparql
select * from <psn1> where { {select * from <psn1> where { ?s <knows> ?o }}
 option (transitive, t_distinct, t_direction 2, t_in(?s), t_out(?o)) . filter (?s=<psn://1> && ?o=<psn://4>)}
;
ECHO BOTH $IF $EQU $ROWCNT 1 "PASSED" "***FAILED";
ECHO BOTH ": trans lrrl 3\n";

select sparql_to_sql_text ('
select * from <psn1> where { {select * from <psn1> where { ?s <knows> ?o }}
 option (transitive, t_distinct, t_direction 3, t_shortest_only, t_in(?s), t_out(?o)) . filter (?s=<psn://1> && ?o=<psn://4>)}
');
sparql
select * from <psn1> where { {select * from <psn1> where { ?s <knows> ?o }}
 option (transitive, t_distinct, t_direction 3, t_shortest_only, t_in(?s), t_out(?o)) . filter (?s=<psn://1> && ?o=<psn://4>)}
;
ECHO BOTH $IF $EQU $ROWCNT 1 "PASSED" "***FAILED";
ECHO BOTH ": trans lrrl 4\n";

select sparql_to_sql_text ('
select * from <psn1> where { {select * from <psn1> where {{?s <knows> ?o} union {?o <knows> ?s}}}
 option (transitive, t_distinct, t_in(?s), t_out(?o)) . filter (?o=<psn://4>)}
');
sparql select * from <psn1> where { {select * from <psn1> where {{?s <knows> ?o} union {?o <knows> ?s}}}
 option (transitive, t_distinct, t_in(?s), t_out(?o)) . filter (?o=<psn://4>)}
;
ECHO BOTH $IF $EQU $ROWCNT 3 "PASSED" "***FAILED";
ECHO BOTH ": trans rl union\n";


select sparql_to_sql_text ('
select * from <psn1> where { {select * from <psn1> where { ?s <knows> ?o }}
 option (transitive, t_distinct, t_direction 1, t_in(?s), t_out(?o), t_step (?s) as ?via, t_step ("path_id") as ?path, t_step ("step_no") as ?step) . filter (?s=<psn://1> && ?o=<psn://4>)}
');
sparql
select * from <psn1> where { {select * from <psn1> where { ?s <knows> ?o }}
 option (transitive, t_distinct, t_direction 1, t_in(?s), t_out(?o), t_step (?s) as ?via, t_step ("path_id") as ?path, t_step ("step_no") as ?step) . filter (?s=<psn://1> && ?o=<psn://4>)}
;
