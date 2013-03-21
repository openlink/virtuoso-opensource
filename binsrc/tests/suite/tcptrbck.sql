set autocommit on;
str2ck (1);
ECHO BOTH  $IF $EQU $STATE OK "PASSED" "***FAILED";
ECHO BOTH ": check of read committed of previous t1\n";
