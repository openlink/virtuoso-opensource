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

SELECT equ(bin2hex(DB.DBA.JSON_CANONICALIZE('
{
    "numbers": [333333333.33333329, 1E30, 4.50,
                2e-3, 0.000000000000000000000000001],
    "string": "\\u20ac\$\\u000F\\u000aA''\\u0042\\u0022\\u005c\\\\\\"\\/",
    "literals": [null, true, false]
}
')), '7b226c69746572616c73223a5b6e756c6c2c747275652c66616c73655d2c226e756d62657273223a5b3333333333333333332e333333333333332c31652b33302c342e352c302e3030322c31652d32375d2c22737472696e67223a22e282ac245c75303030665c6e4127425c225c5c5c5c5c222f227d');
ECHO BOTH $IF $EQU $LAST[1] 1 "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": JSON Canonicalize \n";

ECHO BOTH "COMPLETED WITH " $ARGV[0] " FAILED, " $ARGV[1] " PASSED: JSON parser tests\n";

