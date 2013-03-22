


ttlp (file_to_string ('tst.nq'), '', 'no-g', 512, transactional => 1, log_enable => 1);

sparql select count (*) from <g1> where {?s ?p ?o};

echo both $if $equ last[1] 8 "PASSED" "***FAILED";
echo both ": 8 triples in g1\n";


sparql select * from <g1> where { ?s <only1> ?o . };
echo both $if $equ $last[2] only1  "PASSED" "***FAILED";
echo both ": only1\n";




ttlp (file_to_string ('tst2.nq'), '', 'no-g', 2048 + 512, transactional => 1, log_enable => 1);

sparql select * from <g1> where { ?s <only1> ?o . };
echo both $if $equ $rowcnt 0  "PASSED" "***FAILED";
echo both ": not only1\n";

sparql select * from <g1> where { ?s <only2> ?o . };
echo both $if $equ $last[2] only2  "PASSED" "***FAILED";
echo both ": only2\n";

