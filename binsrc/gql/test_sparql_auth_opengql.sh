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
#  openGQL: GQL for Virtuoso - /sparql authorization matrix test
#
#  Verifies that GQL over the /sparql endpoint inherits the SPARQL
#  endpoint's authorization model:
#    * the anonymous SPARQL account (default: read-only) can run GQL reads
#      but is DENIED GQL writes, exactly as it is denied native SPARQL
#      updates;
#    * a `dryrun` translation performs no write and needs no update right;
#    * an authenticated account with update rights (via /sparql-auth) can
#      perform GQL writes.
#
#  This relies only on the default Virtuoso security posture — no extra
#  grants. Run against a running Virtuoso with the openGQL support loaded.
#  Usage: PORT=1111 DBA_USER=dba DBA_PASS=dba sh test_sparql_auth_opengql.sh
#

set -u

PORT="${PORT:-1111}"
DBA_USER="${DBA_USER:-dba}"
DBA_PASS="${DBA_PASS:-dba}"
BASE="http://localhost:${PORT}/sparql"
AUTH="http://localhost:${PORT}/sparql-auth"
G="urn:opengql:authtest"

PASS=0
FAIL=0
TOTAL=0

ok()   { echo "  PASS: $1"; PASS=$((PASS + 1)); TOTAL=$((TOTAL + 1)); }
bad()  { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); TOTAL=$((TOTAL + 1)); }

# Count triples in the test graph via an anonymous SPARQL read (reads are
# permitted for the anonymous account). Prints an integer (0 if empty).
gcount() {
  curl -sS \
    --data-urlencode "query=SELECT (COUNT(*) AS ?c) WHERE { GRAPH <${G}> { ?s ?p ?o } }" \
    --data-urlencode 'format=text/csv' "$BASE" 2>/dev/null \
    | tr -d '\r' | sed -n '2p' | tr -dc '0-9'
}

# HTTP status only
status() { curl -sS -o /dev/null -w '%{http_code}' "$@" 2>/dev/null; }

echo "=== openGQL /sparql Authorization Matrix ==="
echo "Anon endpoint : $BASE"
echo "Auth endpoint : $AUTH"

# Start from a clean graph (needs update rights -> authenticated).
curl -sS --digest -u "${DBA_USER}:${DBA_PASS}" \
  --data-urlencode "query=CLEAR GRAPH <${G}>" "$AUTH" >/dev/null 2>&1

# --- 1. Anonymous GQL write must be DENIED and must not change the store ----
echo "--- 1: anonymous GQL write is denied ---"
code=$(status --data-urlencode 'query=INSERT (:Thing { name: "x" })' \
              --data-urlencode 'language=opengql' \
              --data-urlencode "graph=${G}" "$BASE")
after=$(gcount); after=${after:-0}
if [ "$code" != "200" ] && [ "$after" = "0" ]; then
  ok "anon GQL INSERT rejected (HTTP $code) and graph unchanged (0 triples)"
else
  bad "anon GQL INSERT NOT blocked (HTTP $code, triples=$after)"
fi

# --- 2. Baseline parity: anonymous native SPARQL write is denied too -------
echo "--- 2: anonymous native SPARQL write is denied (parity) ---"
code=$(status --data-urlencode "query=INSERT DATA { GRAPH <${G}> { <urn:n> <urn:p> 1 } }" "$BASE")
after=$(gcount); after=${after:-0}
if [ "$code" != "200" ] && [ "$after" = "0" ]; then
  ok "anon native SPARQL INSERT rejected (HTTP $code) — same posture as GQL"
else
  bad "anon native SPARQL INSERT NOT blocked (HTTP $code, triples=$after)"
fi

# --- 3. Anonymous GQL read is allowed --------------------------------------
echo "--- 3: anonymous GQL read is allowed ---"
code=$(status --data-urlencode 'query=MATCH (n) RETURN n LIMIT 1' \
              --data-urlencode 'language=opengql' \
              --data-urlencode "graph=${G}" "$BASE")
if [ "$code" = "200" ]; then
  ok "anon GQL read allowed (HTTP 200)"
else
  bad "anon GQL read blocked (HTTP $code)"
fi

# --- 4. Anonymous GQL dryrun writes nothing and needs no update right ------
echo "--- 4: anonymous GQL dryrun translates without writing ---"
body=$(curl -sS --data-urlencode 'query=INSERT (:Thing { name: "y" })' \
              --data-urlencode 'language=opengql' \
              --data-urlencode "graph=${G}" \
              --data-urlencode 'dryrun=1' "$BASE" 2>/dev/null)
after=$(gcount); after=${after:-0}
if echo "$body" | grep -qF 'INSERT' && [ "$after" = "0" ]; then
  ok "anon GQL dryrun returned translated SPARQL and wrote nothing"
else
  bad "anon GQL dryrun unexpected (wrote triples=$after)"
fi

# --- 5. Authenticated GQL write is allowed ---------------------------------
echo "--- 5: authenticated GQL write is allowed ---"
code=$(curl -sS --digest -u "${DBA_USER}:${DBA_PASS}" -o /dev/null -w '%{http_code}' \
              --data-urlencode 'query=INSERT (:Thing { name: "z" })' \
              --data-urlencode 'language=opengql' \
              --data-urlencode "graph=${G}" "$AUTH" 2>/dev/null)
after=$(gcount); after=${after:-0}
if [ "$code" = "200" ] && [ "$after" != "0" ]; then
  ok "authenticated GQL INSERT succeeded (HTTP 200, triples=$after)"
else
  bad "authenticated GQL INSERT failed (HTTP $code, triples=$after)"
fi

# Cleanup (authenticated).
curl -sS --digest -u "${DBA_USER}:${DBA_PASS}" \
  --data-urlencode "query=CLEAR GRAPH <${G}>" "$AUTH" >/dev/null 2>&1

echo ""
echo "=== Results ==="
echo "TOTAL: $TOTAL  PASS: $PASS  FAIL: $FAIL"
[ "$FAIL" -gt 0 ] && { echo "SOME TESTS FAILED"; exit 1; } || { echo "All tests passed."; exit 0; }
