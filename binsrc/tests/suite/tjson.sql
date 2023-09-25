SET ARGV[0] 0;
SET ARGV[1] 0;
ECHO BOTH "STARTED: JSON parser tests\n";
select json_parse ('{ "a":"str", "b":12, "c":null, "d":false, "e":true, "f":[], "f":["a","b"], "g":{ "h":"str" }, "i":[{ "k":"l" } ] }')[2];
ECHO BOTH $IF $EQU $LAST[1] a "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": member a=str " $LAST[1] "\n";

select json_parse ('{ "a":"str", "b":12, "c":null, "d":false, "e":true, "f":[], "f":["a","b"], "g":{ "h":"str" }, "i":[{ "k":"l" } ] }')[3];
ECHO BOTH $IF $EQU $LAST[1] str "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": member a=str " $LAST[1] "\n";

select json_parse ('{ "a":"str", "b":12, "c":null, "d":false, "e":true, "f":[], "f":["a","b"], "g":{ "h":"str" }, "i":[{ "k":"l" } ] }')[4];
ECHO BOTH $IF $EQU $LAST[1] b "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": member b=12 " $LAST[1] "\n";


select json_parse ('{ "a":"str", "b":12, "c":null, "d":false, "e":true, "f":[], "f":["a","b"], "g":{ "h":"str" }, "i":[{ "k":"l" } ] }')[5];
ECHO BOTH $IF $EQU $LAST[1] 12 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": member b=12 " $LAST[1] "\n";

select json_parse ('{ "a":"str", "b":12, "c":null, "d":false, "e":true, "f":[], "f":["a","b"], "g":{ "h":"str" }, "i":[{ "k":"l" } ] }')[6];
ECHO BOTH $IF $EQU $LAST[1] c "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": member c=null " $LAST[1] "\n";

select json_parse ('{ "a":"str", "b":12, "c":null, "d":false, "e":true, "f":[], "f":["a","b"], "g":{ "h":"str" }, "i":[{ "k":"l" } ] }')[7];
ECHO BOTH $IF $EQU $LAST[1] NULL "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": member c=null " $LAST[1] "\n";

select json_parse ('{ "a":"str", "b":12, "c":null, "d":false, "e":true, "f":[], "f":["a","b"], "g":{ "h":"str" }, "i":[{ "k":"l" } ] }')[8];
ECHO BOTH $IF $EQU $LAST[1] d "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": member d=false " $LAST[1] "\n";

select json_parse ('{ "a":"str", "b":12, "c":null, "d":false, "e":true, "f":[], "f":["a","b"], "g":{ "h":"str" }, "i":[{ "k":"l" } ] }')[9];
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": member d=fales " $LAST[1] "\n";

select json_parse ('{ "a":"str", "b":12, "c":null, "d":false, "e":true, "f":[], "f":["a","b"], "g":{ "h":"str" }, "i":[{ "k":"l" } ] }')[10];
ECHO BOTH $IF $EQU $LAST[1] e "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": member e=true " $LAST[1] "\n";

select json_parse ('{ "a":"str", "b":12, "c":null, "d":false, "e":true, "f":[], "f":["a","b"], "g":{ "h":"str" }, "i":[{ "k":"l" } ] }')[11];
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": member e=true " $LAST[1] "\n";

select json_parse ('{ "a":"str", "b":12, "c":null, "d":false, "e":true, "f":[], "f":["a","b"], "g":{ "h":"str" }, "i":[{ "k":"l" } ] }')[12];
ECHO BOTH $IF $EQU $LAST[1] f "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": member f=vector() " $LAST[1] "\n";

select length(json_parse ('{ "a":"str", "b":12, "c":null, "d":false, "e":true, "f":[], "f":["a","b"], "g":{ "h":"str" }, "i":[{ "k":"l" } ] }')[13]);
ECHO BOTH $IF $EQU $LAST[1] 0 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": member f=vector " $LAST[1] "\n";

select json_parse ('{ "a":"str", "b":12, "c":null, "d":false, "e":true, "f":[], "ff":["a","b"], "g":{ "h":"str" }, "i":[{ "k":"l" } ] }')[14];
ECHO BOTH $IF $EQU $LAST[1] ff "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": member ff=[a,b]" $LAST[1] "\n";

select json_parse ('{ "a":"str", "b":12, "c":null, "d":false, "e":true, "f":[], "f":["a","b"], "g":{ "h":"str" }, "i":[{ "k":"l" } ] }')[15][1];
ECHO BOTH $IF $EQU $LAST[1] b "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": member ff=[a,b] " $LAST[1] "\n";

select aref(aref(aref (json_parse ('{ "a":"str", "b":12, "c":null, "d":false, "e":true, "f":[], "f":["a","b"], "g":{ "h":"str" }, "i":[{ "k":"l" } ] }'), 19), 0), 3);
ECHO BOTH $IF $EQU $LAST[1] l "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": member i=[{k:l}] " $LAST[1] "\n";

ECHO BOTH "COMPLETED WITH " $ARGV[0] " FAILED, " $ARGV[1] " PASSED: JSON parser tests\n";

