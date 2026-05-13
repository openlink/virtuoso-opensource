#!/usr/bin/env python3
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
"""Export DB.DBA.OPENCYPHER_TCK_CASES and DB.DBA.OPENCYPHER_TCK_RESULTS as CSV."""

from __future__ import annotations

import argparse
import csv
from pathlib import Path

import pyodbc


CASES_COLUMNS = [
    "CASE_ID",
    "FEATURE_PATH",
    "FEATURE_NAME",
    "SCENARIO_LINE",
    "SCENARIO_NAME",
    "QUERY_LINE",
    "BLOCK_INDEX",
    "PHASE",
    "CYPHER_QUERY",
]

RESULTS_COLUMNS = [
    "CASE_ID",
    "FEATURE_PATH",
    "FEATURE_NAME",
    "SCENARIO_LINE",
    "SCENARIO_NAME",
    "QUERY_LINE",
    "BLOCK_INDEX",
    "PHASE",
    "STATUS",
    "SQL_STATE",
    "MESSAGE",
    "SPARQL_TEXT",
]
RESULTS_BASE_COLUMNS = RESULTS_COLUMNS[:-1]


def export_table(cursor: pyodbc.Cursor, table: str, columns: list[str], path: Path) -> int:
    path.parent.mkdir(parents=True, exist_ok=True)
    cursor.execute(f"SELECT {', '.join(columns)} FROM {table} ORDER BY CASE_ID")
    count = 0
    with path.open("w", encoding="utf-8", newline="") as stream:
        writer = csv.writer(stream)
        writer.writerow(columns)
        while True:
            # Larger batches can abort the local Virtuoso ODBC driver when
            # rows include LONG VARCHAR columns such as SPARQL_TEXT.
            rows = cursor.fetchmany(100)
            if not rows:
                break
            writer.writerows(normalize_row(row) for row in rows)
            count += len(rows)
    return count


def export_results(cursor: pyodbc.Cursor, chunk_cursor: pyodbc.Cursor, path: Path) -> int:
    path.parent.mkdir(parents=True, exist_ok=True)
    cursor.execute(
        "SELECT "
        + ", ".join(RESULTS_BASE_COLUMNS)
        + ", coalesce (length (SPARQL_TEXT), 0) AS SPARQL_TEXT_LENGTH "
        + "FROM DB.DBA.OPENCYPHER_TCK_RESULTS ORDER BY CASE_ID"
    )
    count = 0
    with path.open("w", encoding="utf-8", newline="") as stream:
        writer = csv.writer(stream)
        writer.writerow(RESULTS_COLUMNS)
        while True:
            rows = cursor.fetchmany(500)
            if not rows:
                break
            for row in rows:
                normalized = normalize_row(row)
                sparql_len = int(normalized.pop())
                case_id = normalized[0]
                normalized.append(fetch_long_text(chunk_cursor, "SPARQL_TEXT", case_id, sparql_len))
                writer.writerow(normalized)
                count += 1
    return count


def fetch_long_text(cursor: pyodbc.Cursor, column: str, case_id: int, text_len: int) -> str | None:
    if text_len == 0:
        return None
    chunks: list[str] = []
    step = 1000
    for start in range(0, text_len, step):
        cursor.execute(
            f"SELECT subseq ({column}, ?, ?) FROM DB.DBA.OPENCYPHER_TCK_RESULTS WHERE CASE_ID = ?",
            start,
            min(start + step, text_len),
            case_id,
        )
        value = cursor.fetchone()[0]
        chunks.append(value.replace("\x00", "") if isinstance(value, str) else str(value))
    return "".join(chunks)


def normalize_row(row: pyodbc.Row) -> list[object]:
    normalized: list[object] = []
    for value in row:
        if isinstance(value, str):
            # The local Virtuoso ODBC driver requires wideAsUTF16=Y with
            # pyodbc, which can surface VARCHAR data as NUL-padded text.
            value = value.replace("\x00", "")
        normalized.append(value)
    return normalized


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--driver", required=True)
    parser.add_argument("--host", default="localhost")
    parser.add_argument("--port", required=True)
    parser.add_argument("--user", default="dba")
    parser.add_argument("--password", default="dba")
    parser.add_argument("--cases-csv", type=Path)
    parser.add_argument("--results-csv", type=Path)
    args = parser.parse_args()

    conn_str = (
        f"Driver={args.driver};"
        f"HOST={args.host}:{args.port};"
        f"UID={args.user};"
        f"PWD={args.password};"
        "wideAsUTF16=Y"
    )
    if args.cases_csv is None and args.results_csv is None:
        parser.error("at least one of --cases-csv or --results-csv is required")

    if args.cases_csv is not None:
        with pyodbc.connect(conn_str, timeout=30) as conn:
            case_count = export_table(conn.cursor(), "DB.DBA.OPENCYPHER_TCK_CASES", CASES_COLUMNS, args.cases_csv)
        print(f"Wrote TCK cases CSV: {args.cases_csv} ({case_count} rows)")

    if args.results_csv is not None:
        with pyodbc.connect(conn_str, timeout=30) as conn:
            result_count = export_results(conn.cursor(), conn.cursor(), args.results_csv)
        print(f"Wrote TCK results CSV: {args.results_csv} ({result_count} rows)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
