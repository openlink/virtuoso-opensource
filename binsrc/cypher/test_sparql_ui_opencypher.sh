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
# Phase 14.6 smoke: exercise the /sparql endpoint's openCypher mode
# against a running Virtuoso (defaults to port 1111).
#
# Asserts:
#   1. dryrun returns translated SPARQL as text/plain
#   2. full execution returns HTTP 200
#   3. response carries the X-Generated-SPARQL header
#   4. HTML response embeds the "Generated SPARQL" details panel
#
# Usage: sh binsrc/cypher/test_sparql_ui_opencypher.sh [host:port]

set -eu

endpoint="${1:-http://localhost:1111/sparql/}"
cypher='RETURN 1 AS one, 2 AS two'

fail () { echo "FAIL: $1" >&2; exit 1; }

# 1) dryrun returns translated SPARQL as text/plain
dry=$(curl -fsS -G "$endpoint" \
        --data-urlencode "query=${cypher}" \
        --data-urlencode "language=opencypher" \
        --data-urlencode "dryrun=1")
case "$dry" in
  *SELECT*|*select*) ;;
  *) fail "dryrun did not return SPARQL: $dry" ;;
esac
echo "OK: dryrun translation returned SPARQL"

# 1b) inequality must translate to SPARQL !=, not SQL-style <>
neq_cypher='MATCH (a), (b) WHERE a <> b RETURN a, b'
neq_dry=$(curl -fsS -G "$endpoint" \
        --data-urlencode "query=${neq_cypher}" \
        --data-urlencode "language=opencypher" \
        --data-urlencode "dryrun=1")
case "$neq_dry" in
  *"?a != ?b"*) ;;
  *) fail "inequality dryrun did not emit SPARQL !=: $neq_dry" ;;
esac
case "$neq_dry" in
  *"?a <> ?b"*) fail "inequality dryrun emitted invalid SPARQL <>: $neq_dry" ;;
esac
echo "OK: inequality dryrun uses SPARQL !="

# 2) + 3) full execution returns 200 + X-Generated-SPARQL header
hdr=$(curl -fsS -D - -o /dev/null -G "$endpoint" \
        --data-urlencode "query=${cypher}" \
        --data-urlencode "language=opencypher" \
        --data-urlencode "format=json")
case "$hdr" in
  *"200 OK"*|*"HTTP/1.1 200"*|*"HTTP/1.0 200"*) ;;
  *) fail "expected HTTP 200, got: $(printf '%s' "$hdr" | head -1)" ;;
esac
case "$hdr" in
  *X-Generated-SPARQL:*) ;;
  *) fail "missing X-Generated-SPARQL header in response" ;;
esac
echo "OK: HTTP 200 + X-Generated-SPARQL header present"

# 4) HTML response embeds generated SPARQL panel
html=$(curl -fsS -G "$endpoint" \
         --data-urlencode "query=${cypher}" \
         --data-urlencode "language=opencypher" \
         --data-urlencode "format=html")
case "$html" in
  *"Generated SPARQL"*) ;;
  *) fail "HTML response missing Generated SPARQL panel" ;;
esac
echo "OK: HTML response includes Generated SPARQL panel"

echo "All Phase 14.6 /sparql openCypher smoke checks passed."
