set autocommit on;
str2ck (1);
echo both  $if $equ $state OK "PASSED" "***FAILED";
echo both ": check of read committed of previous t1\n";
