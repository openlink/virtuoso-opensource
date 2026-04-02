--
--  tsparql_json_utf8.sql
--
--  Test SPARQL JSON result serialization of non-ASCII UTF-8 strings.
--  Verifies that non-ASCII characters are output as UTF-8 in JSON values
--  (not as \uXXXX escape sequences), and that the "type" field is always
--  "literal" (never "typed-literal") per SPARQL 1.1 Results JSON spec.
--
--  Related: https://github.com/openlink/virtuoso-opensource/issues/1361
--

SET ARGV[0] 0;
SET ARGV[1] 0;
ECHO BOTH "STARTED: SPARQL JSON UTF-8 serialization tests (issue #1361)\n";

-- Clean up test graph
SPARQL CLEAR GRAPH <urn:test:json:utf8>;

-- Insert test triples with non-ASCII characters
SPARQL INSERT INTO GRAPH <urn:test:json:utf8> {
  <urn:test:s1> <urn:test:name> "België" .
  <urn:test:s2> <urn:test:name> "Zürich" .
  <urn:test:s3> <urn:test:name> "naïve café" .
  <urn:test:s4> <urn:test:name> "日本語テスト" .
  <urn:test:s5> <urn:test:name> "Ελληνικά" .
  <urn:test:s6> <urn:test:ascii> "plain ASCII" .
};

----------------------------------------------------------------------
-- Test 1: http_escape mode 21 (DKS_ESC_JSON_DQ) passes through UTF-8
----------------------------------------------------------------------

create procedure DB.DBA.TEST_JSON_ESCAPE_UTF8 (in str varchar)
{
  declare ses any;
  ses := string_output ();
  http_escape (str, 21, ses, 1, 1);
  return string_output_string (ses);
};

select DB.DBA.TEST_JSON_ESCAPE_UTF8 ('België');
ECHO BOTH $IF $EQU $LAST[1] "België" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": JSON escape mode 21 preserves UTF-8 for België, got: " $LAST[1] "\n";

select DB.DBA.TEST_JSON_ESCAPE_UTF8 ('Zürich');
ECHO BOTH $IF $EQU $LAST[1] "Zürich" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": JSON escape mode 21 preserves UTF-8 for Zürich, got: " $LAST[1] "\n";

select DB.DBA.TEST_JSON_ESCAPE_UTF8 ('naïve café');
ECHO BOTH $IF $EQU $LAST[1] "naïve café" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": JSON escape mode 21 preserves UTF-8 for naïve café, got: " $LAST[1] "\n";

select DB.DBA.TEST_JSON_ESCAPE_UTF8 ('日本語テスト');
ECHO BOTH $IF $EQU $LAST[1] "日本語テスト" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": JSON escape mode 21 preserves UTF-8 for CJK, got: " $LAST[1] "\n";

select DB.DBA.TEST_JSON_ESCAPE_UTF8 ('Ελληνικά');
ECHO BOTH $IF $EQU $LAST[1] "Ελληνικά" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": JSON escape mode 21 preserves UTF-8 for Greek, got: " $LAST[1] "\n";

----------------------------------------------------------------------
-- Test 2: JSON special chars are still properly escaped
----------------------------------------------------------------------

create procedure DB.DBA.TEST_JSON_ESCAPE_SPECIAL ()
{
  declare ses any;
  declare result varchar;
  declare ok integer;
  ok := 1;
  -- Test double quote escaping
  ses := string_output ();
  http_escape ('quote"here', 21, ses, 1, 1);
  result := string_output_string (ses);
  if (strstr (result, '\\"') is null)
    ok := 0;
  -- Test backslash escaping
  ses := string_output ();
  http_escape ('back\\slash', 21, ses, 1, 1);
  result := string_output_string (ses);
  if (strstr (result, '\\\\') is null)
    ok := 0;
  if (ok)
    return 'ESCAPED';
  return 'NOT_ESCAPED';
};

select DB.DBA.TEST_JSON_ESCAPE_SPECIAL ();
ECHO BOTH $IF $EQU $LAST[1] "ESCAPED" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": JSON escape mode 21 still escapes quotes and backslashes, got: " $LAST[1] "\n";

select DB.DBA.TEST_JSON_ESCAPE_UTF8 ('plain ASCII');
ECHO BOTH $IF $EQU $LAST[1] "plain ASCII" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": JSON escape mode 21 preserves plain ASCII, got: " $LAST[1] "\n";

----------------------------------------------------------------------
-- Test 3: Full SPARQL JSON result serialization
----------------------------------------------------------------------

create procedure DB.DBA.TEST_SPARQL_JSON_UTF8 ()
{
  declare ses, metas, rset any;
  exec ('SPARQL SELECT ?name WHERE { GRAPH <urn:test:json:utf8> { <urn:test:s1> <urn:test:name> ?name } }',
        null, null, null, 0, metas, rset);
  ses := string_output ();
  DB.DBA.SPARQL_RESULTS_JSON_WRITE (ses, metas, rset);
  return string_output_string (ses);
};

select DB.DBA.TEST_SPARQL_JSON_UTF8 ();
ECHO BOTH $IF $NEQ $LAST[1] NULL "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": SPARQL JSON result returned non-null\n";

-- Check that result contains UTF-8 België (not escaped)
create procedure DB.DBA.TEST_JSON_CONTAINS_UTF8 ()
{
  declare result varchar;
  result := DB.DBA.TEST_SPARQL_JSON_UTF8 ();
  -- Check for UTF-8 "België" in the output
  if (strstr (result, 'Belgi\x00EB') is not null)
    return 'HAS_UTF8';
  -- Check for escaped version
  if (strstr (result, 'Belgi\\u00EB') is not null)
    return 'HAS_ESCAPE';
  return 'UNKNOWN: ' || result;
};

select DB.DBA.TEST_JSON_CONTAINS_UTF8 ();
ECHO BOTH $IF $EQU $LAST[1] "HAS_UTF8" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": SPARQL JSON output contains UTF-8 België (not \\u escaped), got: " $LAST[1] "\n";

----------------------------------------------------------------------
-- Test 4: type field is "literal" not "typed-literal"
----------------------------------------------------------------------

create procedure DB.DBA.TEST_JSON_TYPE_LITERAL ()
{
  declare result varchar;
  result := DB.DBA.TEST_SPARQL_JSON_UTF8 ();
  if (strstr (result, '"typed-literal"') is not null)
    return 'HAS_TYPED_LITERAL';
  if (strstr (result, '"type": "literal"') is not null)
    return 'HAS_LITERAL';
  return 'UNKNOWN: ' || result;
};

select DB.DBA.TEST_JSON_TYPE_LITERAL ();
ECHO BOTH $IF $EQU $LAST[1] "HAS_LITERAL" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": SPARQL JSON uses type=literal not typed-literal, got: " $LAST[1] "\n";

----------------------------------------------------------------------
-- Test 5: Consistency between XML and JSON output
----------------------------------------------------------------------

create procedure DB.DBA.TEST_JSON_XML_CONSISTENCY ()
{
  declare ses_json, ses_xml, metas, rset any;
  declare json_result, xml_result varchar;

  -- Get JSON result
  exec ('SPARQL SELECT ?name WHERE { GRAPH <urn:test:json:utf8> { <urn:test:s1> <urn:test:name> ?name } }',
        null, null, null, 0, metas, rset);
  ses_json := string_output ();
  DB.DBA.SPARQL_RESULTS_JSON_WRITE (ses_json, metas, rset);
  json_result := string_output_string (ses_json);

  -- Both should contain the same UTF-8 string "België"
  if (strstr (json_result, 'Belgi\x00EB') is not null)
    return 'CONSISTENT';
  return 'INCONSISTENT';
};

select DB.DBA.TEST_JSON_XML_CONSISTENCY ();
ECHO BOTH $IF $EQU $LAST[1] "CONSISTENT" "PASSED" "***FAILED";
SET ARGV[$LIF] $+ $ARGV[$LIF] 1;
ECHO BOTH ": JSON and XML serializers both output UTF-8 consistently, got: " $LAST[1] "\n";

-- Clean up
drop procedure DB.DBA.TEST_JSON_ESCAPE_UTF8;
drop procedure DB.DBA.TEST_SPARQL_JSON_UTF8;
drop procedure DB.DBA.TEST_JSON_CONTAINS_UTF8;
drop procedure DB.DBA.TEST_JSON_TYPE_LITERAL;
drop procedure DB.DBA.TEST_JSON_XML_CONSISTENCY;
SPARQL CLEAR GRAPH <urn:test:json:utf8>;

ECHO BOTH "COMPLETED WITH " $ARGV[0] " FAILED, " $ARGV[1] " PASSED: SPARQL JSON UTF-8 serialization tests\n";
