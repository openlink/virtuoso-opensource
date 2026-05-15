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
set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/../../.." && pwd)
DEFAULT_TCK_ROOT="$ROOT_DIR/../openCypher-2024.3/tck/features"
TCK_ROOT=${TCK_ROOT:-$DEFAULT_TCK_ROOT}
ISQL=${ISQL:-"$ROOT_DIR/binsrc/tests/isql"}
PORT=${PORT:-1111}
DBA_USER=${DBA_USER:-dba}
DBA_PASSWORD=${DBA_PASSWORD:-dba}
COMPILE_READS=${COMPILE_READS:-0}
TMP_SQL=${TMPDIR:-/tmp}/opencypher_tck_cases_$$.sql
LOAD_LOG=${LOAD_LOG:-"$ROOT_DIR/binsrc/cypher/tck/openCypher_tck_load.log"}
CSV_DIR=${CSV_DIR:-"$ROOT_DIR/binsrc/cypher/tck"}
CASES_CSV=${CASES_CSV:-"$CSV_DIR/openCypher_tck_cases.csv"}
RESULTS_CSV=${RESULTS_CSV:-"$CSV_DIR/openCypher_tck_results.csv"}
ODBC_DRIVER=${ODBC_DRIVER:-"$ROOT_DIR/binsrc/driver/.libs/virtodbc.so"}

cleanup()
{
  rm -f "$TMP_SQL"
}
trap cleanup EXIT INT TERM

if [ ! -d "$TCK_ROOT" ]; then
  echo "TCK_ROOT does not exist: $TCK_ROOT" >&2
  exit 2
fi

case "$COMPILE_READS" in
  0|1) ;;
  *) echo "COMPILE_READS must be 0 or 1" >&2; exit 2 ;;
esac

python3 "$ROOT_DIR/binsrc/cypher/tck/extract_tck_cases.py" "$TCK_ROOT" > "$TMP_SQL"
mkdir -p "$CSV_DIR"

"$ISQL" "$PORT" "$DBA_USER" "$DBA_PASSWORD" < "$ROOT_DIR/binsrc/cypher/tck/test_tck_full.sql"
"$ISQL" "$PORT" "$DBA_USER" "$DBA_PASSWORD" < "$TMP_SQL" > "$LOAD_LOG"
"$ISQL" "$PORT" "$DBA_USER" "$DBA_PASSWORD" <<SQL
SELECT DB.DBA.OPENCYPHER_TCK_RUN ($COMPILE_READS);
SELECT STATUS, COUNT (*) AS CASES FROM DB.DBA.OPENCYPHER_TCK_RESULTS GROUP BY STATUS ORDER BY STATUS;
SELECT FEATURE_PATH, COUNT (*) AS FAILURES
  FROM DB.DBA.OPENCYPHER_TCK_RESULTS
 WHERE STATUS IN ('TRANSLATE_FAIL', 'SPARQL_FAIL')
 GROUP BY FEATURE_PATH
 ORDER BY FAILURES DESC, FEATURE_PATH;
SELECT TOP 100 CASE_ID, FEATURE_PATH, SCENARIO_LINE, QUERY_LINE, PHASE, STATUS, SQL_STATE, MESSAGE
  FROM DB.DBA.OPENCYPHER_TCK_RESULTS
 WHERE STATUS IN ('TRANSLATE_FAIL', 'SPARQL_FAIL')
 ORDER BY CASE_ID;
SQL
python3 "$ROOT_DIR/binsrc/cypher/tck/export_tck_csv.py" \
  --driver "$ODBC_DRIVER" \
  --port "$PORT" \
  --user "$DBA_USER" \
  --password "$DBA_PASSWORD" \
  --cases-csv "$CASES_CSV"
python3 "$ROOT_DIR/binsrc/cypher/tck/export_tck_csv.py" \
  --driver "$ODBC_DRIVER" \
  --port "$PORT" \
  --user "$DBA_USER" \
  --password "$DBA_PASSWORD" \
  --results-csv "$RESULTS_CSV"
