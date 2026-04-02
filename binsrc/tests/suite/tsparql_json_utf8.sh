#!/bin/bash
#
#  tsparql_json_utf8.sh
#
#  Standalone test for SPARQL JSON result serialization of non-ASCII UTF-8 strings.
#  Tests that non-ASCII characters are output as UTF-8 (not \uXXXX escapes)
#  and that "type" is "literal" (not "typed-literal").
#
#  Can be run BEFORE and AFTER the fix to demonstrate the difference.
#
#  Related: https://github.com/openlink/virtuoso-opensource/issues/1361
#
#  Usage:
#    ./tsparql_json_utf8.sh [SPARQL_ENDPOINT_URL]
#
#  Default endpoint: http://localhost:8890/sparql
#

ENDPOINT="${1:-http://localhost:8890/sparql}"
GRAPH="urn:test:json:utf8:$(date +%s)"
PASSED=0
FAILED=0
TESTS=0

pass() {
  PASSED=$((PASSED + 1))
  TESTS=$((TESTS + 1))
  echo "  PASSED: $1"
}

fail() {
  FAILED=$((FAILED + 1))
  TESTS=$((TESTS + 1))
  echo "  ***FAILED: $1"
}

echo "=== SPARQL JSON UTF-8 Serialization Test ==="
echo "Endpoint: $ENDPOINT"
echo "Test graph: $GRAPH"
echo ""

# --- Setup: Insert test data ---
echo "--- Setup: Inserting test data ---"
curl -s -X POST "$ENDPOINT" \
  --data-urlencode "query=INSERT INTO GRAPH <$GRAPH> {
    <urn:test:s1> <urn:test:name> \"België\" .
    <urn:test:s2> <urn:test:name> \"Zürich\" .
    <urn:test:s3> <urn:test:name> \"naïve café\" .
    <urn:test:s4> <urn:test:name> \"日本語テスト\" .
    <urn:test:s5> <urn:test:name> \"plain ASCII\" .
  }" > /dev/null 2>&1

# --- Test 1: België in JSON output ---
echo ""
echo "--- Test 1: Non-ASCII string 'België' in JSON ---"
RESULT=$(curl -s -H "Accept: application/sparql-results+json" \
  --data-urlencode "query=SELECT ?name WHERE { GRAPH <$GRAPH> { <urn:test:s1> <urn:test:name> ?name } }" \
  "$ENDPOINT")

echo "  Raw JSON output:"
echo "  $RESULT" | head -20
echo ""

if echo "$RESULT" | grep -q 'België'; then
  pass "JSON contains UTF-8 'België' (not escaped)"
else
  fail "JSON does not contain UTF-8 'België'"
fi

if echo "$RESULT" | grep -q '\\u00EB\|\\u00CB'; then
  fail "JSON contains \\uXXXX escape sequences (should be UTF-8)"
else
  pass "JSON does not contain \\uXXXX escape sequences"
fi

# --- Test 2: Zürich in JSON output ---
echo ""
echo "--- Test 2: Non-ASCII string 'Zürich' in JSON ---"
RESULT=$(curl -s -H "Accept: application/sparql-results+json" \
  --data-urlencode "query=SELECT ?name WHERE { GRAPH <$GRAPH> { <urn:test:s2> <urn:test:name> ?name } }" \
  "$ENDPOINT")

if echo "$RESULT" | grep -q 'Zürich'; then
  pass "JSON contains UTF-8 'Zürich'"
else
  fail "JSON does not contain UTF-8 'Zürich'"
fi

# --- Test 3: naïve café in JSON output ---
echo ""
echo "--- Test 3: Non-ASCII string 'naïve café' in JSON ---"
RESULT=$(curl -s -H "Accept: application/sparql-results+json" \
  --data-urlencode "query=SELECT ?name WHERE { GRAPH <$GRAPH> { <urn:test:s3> <urn:test:name> ?name } }" \
  "$ENDPOINT")

if echo "$RESULT" | grep -q 'naïve café'; then
  pass "JSON contains UTF-8 'naïve café'"
else
  fail "JSON does not contain UTF-8 'naïve café'"
fi

# --- Test 4: CJK characters in JSON output ---
echo ""
echo "--- Test 4: CJK string '日本語テスト' in JSON ---"
RESULT=$(curl -s -H "Accept: application/sparql-results+json" \
  --data-urlencode "query=SELECT ?name WHERE { GRAPH <$GRAPH> { <urn:test:s4> <urn:test:name> ?name } }" \
  "$ENDPOINT")

if echo "$RESULT" | grep -q '日本語テスト'; then
  pass "JSON contains UTF-8 CJK characters"
else
  fail "JSON does not contain UTF-8 CJK characters"
fi

# --- Test 5: type field is "literal" not "typed-literal" ---
echo ""
echo "--- Test 5: type field correctness ---"
RESULT=$(curl -s -H "Accept: application/sparql-results+json" \
  --data-urlencode "query=SELECT ?name WHERE { GRAPH <$GRAPH> { <urn:test:s1> <urn:test:name> ?name } }" \
  "$ENDPOINT")

if echo "$RESULT" | grep -q '"typed-literal"'; then
  fail "JSON uses 'typed-literal' (should be 'literal')"
else
  pass "JSON does not use 'typed-literal'"
fi

if echo "$RESULT" | grep -q '"type": "literal"'; then
  pass "JSON uses 'type': 'literal'"
else
  # Also check without extra space
  if echo "$RESULT" | grep -q '"type":"literal"'; then
    pass "JSON uses 'type':'literal'"
  else
    fail "JSON does not contain type=literal"
  fi
fi

# --- Test 6: plain ASCII still works ---
echo ""
echo "--- Test 6: Plain ASCII string preserved ---"
RESULT=$(curl -s -H "Accept: application/sparql-results+json" \
  --data-urlencode "query=SELECT ?name WHERE { GRAPH <$GRAPH> { <urn:test:s5> <urn:test:name> ?name } }" \
  "$ENDPOINT")

if echo "$RESULT" | grep -q 'plain ASCII'; then
  pass "JSON contains 'plain ASCII' correctly"
else
  fail "JSON does not contain 'plain ASCII'"
fi

# --- Test 7: Compare JSON vs XML for België ---
echo ""
echo "--- Test 7: JSON vs XML consistency for 'België' ---"
JSON_RESULT=$(curl -s -H "Accept: application/sparql-results+json" \
  --data-urlencode "query=SELECT ?name WHERE { GRAPH <$GRAPH> { <urn:test:s1> <urn:test:name> ?name } }" \
  "$ENDPOINT")
XML_RESULT=$(curl -s -H "Accept: application/sparql-results+xml" \
  --data-urlencode "query=SELECT ?name WHERE { GRAPH <$GRAPH> { <urn:test:s1> <urn:test:name> ?name } }" \
  "$ENDPOINT")

XML_HAS_UTF8=0
JSON_HAS_UTF8=0
echo "$XML_RESULT" | grep -q 'België' && XML_HAS_UTF8=1
echo "$JSON_RESULT" | grep -q 'België' && JSON_HAS_UTF8=1

if [ "$XML_HAS_UTF8" -eq 1 ] && [ "$JSON_HAS_UTF8" -eq 1 ]; then
  pass "Both JSON and XML output contain UTF-8 'België'"
elif [ "$XML_HAS_UTF8" -eq 1 ] && [ "$JSON_HAS_UTF8" -eq 0 ]; then
  fail "XML has UTF-8 'België' but JSON does not (inconsistency!)"
else
  fail "Neither JSON nor XML contain UTF-8 'België'"
fi

# --- Cleanup ---
echo ""
echo "--- Cleanup ---"
curl -s -X POST "$ENDPOINT" \
  --data-urlencode "query=CLEAR GRAPH <$GRAPH>" > /dev/null 2>&1
echo "  Test graph cleared."

# --- Summary ---
echo ""
echo "==========================================="
echo "  Results: $PASSED passed, $FAILED failed (out of $TESTS tests)"
echo "==========================================="

if [ "$FAILED" -gt 0 ]; then
  exit 1
fi
exit 0
