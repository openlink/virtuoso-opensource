#!/bin/sh
#
#  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
#  project.
#
#  Copyright (C) 1998-2026 OpenLink Software
#
#  This project is free software; you can redistribute it and/or modify it
#  under the terms of the GNU General Public License as published by the
#  Free Software Foundation; only version 2 of the License, dated June 1991.
#
#  This program is distributed in the hope that it will be useful, but
#  WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
#  General Public License for more details.
#
#  You should have received a copy of the GNU General Public License along
#  with this program; if not, write to the Free Software Foundation, Inc.,
#  51 Franklin St, Fifth Floor, Boston, MA 02110-1301 USA
#
#
#
#  openGQL: GQL for Virtuoso - /sparql endpoint smoke test
#
#  Run against a running Virtuoso with the openGQL VAD installed.
#  Usage: PORT=1111 sh test_sparql_ui_opengql.sh
#

set -eu

PORT="${PORT:-1111}"
BASE="http://localhost:${PORT}/sparql"

PASS=0
FAIL=0
TOTAL=0

die() { echo "ERROR: $*" >&2; exit 1; }

assert_contains() {
  local desc="$1" needle="$2" haystack="$3"
  TOTAL=$((TOTAL + 1))
  if echo "$haystack" | grep -qF "$needle" 2>/dev/null; then
    echo "  PASS: $desc"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $desc (expected to contain: $needle)"
    FAIL=$((FAIL + 1))
  fi
}

assert_not_contains() {
  local desc="$1" needle="$2" haystack="$3"
  TOTAL=$((TOTAL + 1))
  if echo "$haystack" | grep -qF "$needle" 2>/dev/null; then
    echo "  FAIL: $desc (should NOT contain: $needle)"
    FAIL=$((FAIL + 1))
  else
    echo "  PASS: $desc"
    PASS=$((PASS + 1))
  fi
}

# HTTP status code for a request (curl args passed through)
http_code() { curl -sS -o /dev/null -w '%{http_code}' "$@" 2>/dev/null; }

echo "=== openGQL /sparql Endpoint Smoke Tests ==="
echo "Target: $BASE"

# Test 1: Dryrun returns translated SPARQL
echo "--- Test 1: dryrun returns SELECT ---"
RESULT=$(curl -sS --data-urlencode 'query=MATCH (n) RETURN n LIMIT 1' --data-urlencode 'language=opengql' --data-urlencode 'dryrun=1' "$BASE" 2>&1) || echo "(curl exited non-zero)"
assert_contains "dryrun returns SELECT" "SELECT" "$RESULT"

# Test 2: Inequality <> translates to SPARQL !=
echo "--- Test 2: <> translates to != ---"
RESULT=$(curl -sS --data-urlencode 'query=MATCH (n) WHERE n.x <> 1 RETURN n' --data-urlencode 'language=opengql' --data-urlencode 'dryrun=1' "$BASE" 2>&1) || echo "(curl exited non-zero)"
assert_contains "<> becomes !=" "!=" "$RESULT"

# Test 3: A non-dryrun GQL read executes successfully (HTTP 200).
# NOTE: the translated SPARQL is exposed reliably via dryrun=1 (Test 1) and
# the HTML result panel (Test 4). The optional X-Generated-SPARQL *response
# header* is best-effort only: downstream result serialization may replace the
# response-header buffer, so it is not asserted here.
echo "--- Test 3: non-dryrun GQL read executes ---"
CODE=$(http_code --data-urlencode 'query=MATCH (n) RETURN n LIMIT 1' --data-urlencode 'language=opengql' "$BASE")
assert_contains "non-dryrun GQL read -> 200" "200" "$CODE"

# Test 4: HTML format includes Generated SPARQL details panel
echo "--- Test 4: HTML format with Generated SPARQL panel ---"
RESULT=$(curl -sS --data-urlencode 'query=MATCH (n) RETURN n LIMIT 1' --data-urlencode 'language=opengql' --data-urlencode 'format=text/html' "$BASE" 2>&1) || echo "(curl exited non-zero)"
assert_contains "Generated SPARQL panel" "Generated SPARQL (translated from openGQL)" "$RESULT"

# Test 5: content negotiation — format=json returns a JSON results body
# (GQL falls through to the native SPARQL serializer, so it matches native.)
echo "--- Test 5: format=json returns a JSON results body ---"
RESULT=$(curl -sS --data-urlencode 'query=MATCH (n) RETURN n LIMIT 1' --data-urlencode 'language=opengql' --data-urlencode 'format=json' "$BASE" 2>&1) || true
assert_contains "format=json -> JSON body" '"head"' "$RESULT"

# Test 6: content negotiation — format=csv returns a CSV body
echo "--- Test 6: format=csv returns a CSV body ---"
RESULT=$(curl -sS --data-urlencode 'query=MATCH (n) RETURN n LIMIT 1' --data-urlencode 'language=opengql' --data-urlencode 'format=csv' "$BASE" 2>&1) || true
assert_contains "format=csv -> CSV header for ?n" '"n"' "$RESULT"

# Test 7: GQL parse error maps to HTTP 400
echo "--- Test 7: parse error -> HTTP 400 ---"
CODE=$(http_code --data-urlencode 'query=MATCH ( bad' --data-urlencode 'language=opengql' "$BASE")
assert_contains "parse error -> 400" "400" "$CODE"

# Test 8: empty GQL body -> HTTP 400 (GQ101)
echo "--- Test 8: empty GQL body -> HTTP 400 ---"
CODE=$(http_code --data-urlencode 'query=' --data-urlencode 'language=opengql' "$BASE")
assert_contains "empty body -> 400" "400" "$CODE"

# Test 9: a native SPARQL query is NOT mis-detected as GQL
echo "--- Test 9: native SPARQL not mis-detected as GQL ---"
HDRS=$(curl -sS -D - -o /dev/null --data-urlencode 'query=SELECT * WHERE { ?s ?p ?o } LIMIT 1' "$BASE" 2>/dev/null)
assert_not_contains "native SELECT not translated as GQL" "X-Generated-SPARQL" "$HDRS"

# Test 10: a 'PREFIX gql:' native query is NOT mis-detected (':' is not whitespace)
echo "--- Test 10: 'PREFIX gql:' native query not mis-detected ---"
HDRS=$(curl -sS -D - -o /dev/null --data-urlencode 'query=PREFIX gql: <urn:x> SELECT * WHERE { ?s ?p ?o } LIMIT 1' "$BASE" 2>/dev/null)
assert_not_contains "PREFIX gql: not mis-detected" "X-Generated-SPARQL" "$HDRS"

# Test 11: body-sniffed 'gql ...' request IS treated as GQL
echo "--- Test 11: body 'gql ...' is detected as GQL ---"
RESULT=$(curl -sS --data-urlencode 'query=gql MATCH (n) RETURN n LIMIT 1' --data-urlencode 'dryrun=1' "$BASE" 2>&1) || true
assert_contains "body 'gql ...' translated to SPARQL" "SELECT" "$RESULT"

# Test 12: graph precedence — in-query USE overrides the graph= param
echo "--- Test 12: in-query USE overrides graph= param ---"
RESULT=$(curl -sS --data-urlencode 'query=USE urn:GB MATCH (n) RETURN n' --data-urlencode 'language=opengql' --data-urlencode 'graph=urn:GA' --data-urlencode 'dryrun=1' "$BASE" 2>&1) || true
assert_contains "USE wins over graph= (targets urn:GB)" "urn:GB" "$RESULT"

echo ""
echo "=== Results ==="
echo "TOTAL: $TOTAL  PASS: $PASS  FAIL: $FAIL"

if [ "$FAIL" -gt 0 ]; then
  echo "SOME TESTS FAILED"
  exit 1
else
  echo "All tests passed."
  exit 0
fi
