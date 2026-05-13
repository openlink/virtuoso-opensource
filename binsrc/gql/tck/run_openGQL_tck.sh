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
#  openGQL TCK Runner
#
#  Extracts GQL TCK cases from Gherkin feature files, loads them into a
#  Virtuoso instance with the openGQL VAD installed, runs translation,
#  and exports results as CSV.
#
#  Usage:
#    TCK_ROOT=/path/to/openGQL/tck  sh run_openGQL_tck.sh
#

set -eu

ISQL="${ISQL:-`which isql 2>/dev/null`}"
PORT="${PORT:-1111}"
DBA_USER="${DBA_USER:-dba}"
DBA_PASS="${DBA_PASS:-dba}"
COMPILE_READS="${COMPILE_READS:-0}"

SCRIPT_DIR=`dirname "$0"`
SCRIPT_DIR=`(cd "$SCRIPT_DIR" && pwd)`
ROOT_DIR=`(cd "$SCRIPT_DIR/../../.." && pwd)`
TCK_ROOT="${TCK_ROOT:-$ROOT_DIR/../openGQL/tck}"

CSV_DIR="${CSV_DIR:-$SCRIPT_DIR/results}"
CASES_CSV="${CSV_DIR}/openGQL_tck_cases.csv"
RESULTS_CSV="${CSV_DIR}/openGQL_tck_results.csv"
TMP_SQL="/tmp/opengql_tck_cases_$$.sql"

echo "=== openGQL TCK Runner ==="
echo "TCK_ROOT: $TCK_ROOT"
echo "Port: $PORT"

# Extract cases from Gherkin features
if [ -x "$SCRIPT_DIR/extract_tck_cases.py" ]; then
  echo "Extracting TCK cases from $TCK_ROOT/features..."
  python3 "$SCRIPT_DIR/extract_tck_cases.py" "$TCK_ROOT/features" > "$TMP_SQL" 2>/dev/null || {
    echo "Warning: case extraction failed (no Python or missing features). Creating empty cases file."
    echo "-- No cases extracted" > "$TMP_SQL"
  }
else
  echo "Warning: extract_tck_cases.py not found. Creating empty cases file."
  echo "-- No cases extracted" > "$TMP_SQL"
fi

# Load runner schema
echo "Loading TCK runner schema..."
"$ISQL" "$PORT" "$DBA_USER" "$DBA_PASS" < "$SCRIPT_DIR/test_tck_full.sql" 2>&1 | tail -3

# Load extracted cases
echo "Loading TCK cases..."
"$ISQL" "$PORT" "$DBA_USER" "$DBA_PASS" < "$TMP_SQL" 2>&1 | tail -1
rm -f "$TMP_SQL"

# Run TCK
echo "Running TCK (compile_reads=$COMPILE_READS)..."
"$ISQL" "$PORT" "$DBA_USER" "$DBA_PASS" "EXEC=SELECT DB.DBA.OGQL_TCK_RUN($COMPILE_READS);" 2>&1 | tail -5

# Show summary
echo "=== TCK Summary ==="
"$ISQL" "$PORT" "$DBA_USER" "$DBA_PASS" "EXEC=SELECT STATUS, COUNT(*) AS CNT FROM DB.DBA.OGQL_TCK_RESULTS GROUP BY STATUS ORDER BY STATUS;" 2>&1

# Export results
if [ -x "$SCRIPT_DIR/export_tck_csv.py" ]; then
  echo "Exporting results to $RESULTS_CSV..."
  python3 "$SCRIPT_DIR/export_tck_csv.py" "$PORT" "$DBA_USER" "$DBA_PASS" "$RESULTS_CSV" 2>/dev/null || \
    echo "Warning: CSV export failed"
fi

echo "=== TCK run complete ==="
