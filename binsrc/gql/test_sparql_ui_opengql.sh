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

# Test 3: Execution returns X-Generated-SPARQL header
echo "--- Test 3: X-Generated-SPARQL header ---"
HEADERS=$(curl -sSI --data-urlencode 'query=MATCH (n) RETURN n LIMIT 1' --data-urlencode 'language=opengql' "$BASE" 2>&1) || echo "(curl exited non-zero)"
assert_contains "X-Generated-SPARQL header present" "X-Generated-SPARQL" "$HEADERS"

# Test 4: HTML format includes Generated SPARQL details panel
echo "--- Test 4: HTML format with Generated SPARQL panel ---"
RESULT=$(curl -sS --data-urlencode 'query=MATCH (n) RETURN n LIMIT 1' --data-urlencode 'language=opengql' --data-urlencode 'format=text/html' "$BASE" 2>&1) || echo "(curl exited non-zero)"
assert_contains "Generated SPARQL panel" "Generated SPARQL (translated from openGQL)" "$RESULT"

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
