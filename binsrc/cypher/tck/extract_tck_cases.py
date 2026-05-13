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
"""Extract executable query blocks from the openCypher TCK feature corpus.

The output is a SQL script that populates DB.DBA.OPENCYPHER_TCK_CASES.  This is
intentionally lightweight: it expands Scenario Outline examples and extracts
the Cypher blocks used by "having executed" and "executing query" steps.
"""

from __future__ import annotations

import argparse
import base64
from dataclasses import dataclass, field
import os
from pathlib import Path
import re
import signal
from typing import Iterable


QUERY_STEP_RE = re.compile(r"\b(having executed|executing query):\s*$", re.I)
SCENARIO_RE = re.compile(r"^\s*Scenario(?: Outline)?:\s*(.*)\s*$")
FEATURE_RE = re.compile(r"^\s*Feature:\s*(.*)\s*$")
SKIP_SENTINEL = "__OPENCYPHER_TCK_QUERY_TOO_LARGE__"


@dataclass
class QueryBlock:
    phase: str
    query: str
    line: int


@dataclass
class Scenario:
    name: str
    line: int
    outline: bool
    blocks: list[QueryBlock] = field(default_factory=list)
    examples: list[dict[str, str]] = field(default_factory=list)


def sql_string(value: str) -> str:
    return "'" + value.replace("'", "''") + "'"


def sql_base64_string(value: str) -> str:
    encoded = base64.b64encode(value.encode("utf-8")).decode("ascii")
    return f"decode_base64('{encoded}')"


def parse_table_row(line: str) -> list[str] | None:
    stripped = line.strip()
    if not (stripped.startswith("|") and stripped.endswith("|")):
        return None
    return [cell.strip() for cell in stripped[1:-1].split("|")]


def parse_feature(path: Path) -> tuple[str, list[Scenario]]:
    lines = path.read_text(encoding="utf-8").splitlines()
    feature_name = path.stem
    scenarios: list[Scenario] = []
    current: Scenario | None = None
    i = 0

    while i < len(lines):
        line = lines[i]
        feature_match = FEATURE_RE.match(line)
        if feature_match:
            feature_name = feature_match.group(1)
            i += 1
            continue

        scenario_match = SCENARIO_RE.match(line)
        if scenario_match:
            current = Scenario(
                name=scenario_match.group(1),
                line=i + 1,
                outline="Scenario Outline:" in line,
            )
            scenarios.append(current)
            i += 1
            continue

        if current is not None and QUERY_STEP_RE.search(line):
            phase = "setup" if "having executed" in line.lower() else "query"
            j = i + 1
            while j < len(lines) and lines[j].strip() != '"""':
                j += 1
            if j >= len(lines):
                i += 1
                continue
            start_line = j + 2
            j += 1
            body: list[str] = []
            while j < len(lines) and lines[j].strip() != '"""':
                body.append(lines[j])
                j += 1
            current.blocks.append(QueryBlock(phase=phase, query="\n".join(body).strip(), line=start_line))
            i = j + 1
            continue

        if current is not None and line.strip().startswith("Examples:"):
            j = i + 1
            while j < len(lines) and not lines[j].strip():
                j += 1
            headers = parse_table_row(lines[j]) if j < len(lines) else None
            if headers:
                j += 1
                while j < len(lines):
                    if SCENARIO_RE.match(lines[j]) or FEATURE_RE.match(lines[j]):
                        break
                    row = parse_table_row(lines[j])
                    if row is None:
                        if lines[j].strip() and not lines[j].startswith((" ", "\t")):
                            break
                        j += 1
                        continue
                    if len(row) == len(headers):
                        current.examples.append(dict(zip(headers, row)))
                    j += 1
                i = j
                continue

        i += 1

    return feature_name, scenarios


def expand_placeholders(query: str, example: dict[str, str]) -> str:
    out = query
    for key, value in example.items():
        out = out.replace("<" + key + ">", value)
    return out


def iter_cases(root: Path) -> Iterable[tuple[str, str, int, str, int, int, str]]:
    feature_paths = sorted(root.rglob("*.feature"))
    case_id = 0
    for path in feature_paths:
        feature_name, scenarios = parse_feature(path)
        rel_path = path.relative_to(root).as_posix()
        for scenario in scenarios:
            examples = scenario.examples or [None]
            for example_index, example in enumerate(examples, start=1):
                for block_index, block in enumerate(scenario.blocks, start=1):
                    case_id += 1
                    query = expand_placeholders(block.query, example) if example else block.query
                    scenario_name = scenario.name
                    if example is not None:
                        scenario_name = f"{scenario_name} [example {example_index}]"
                    yield (
                        case_id,
                        rel_path,
                        feature_name,
                        scenario.line,
                        scenario_name,
                        block.line,
                        block_index,
                        block.phase,
                        query,
                    )


def main() -> int:
    signal.signal(signal.SIGPIPE, signal.SIG_DFL)
    parser = argparse.ArgumentParser()
    parser.add_argument("tck_root", type=Path, help="Path to openCypher-2024.3/tck/features")
    parser.add_argument(
        "--max-inline-query",
        type=int,
        default=int(os.environ.get("OPENCYPHER_TCK_MAX_INLINE_QUERY", "8000")),
        help="Store longer query blocks as harness skips to keep isql loading reliable.",
    )
    args = parser.parse_args()

    root = args.tck_root.resolve()
    if not root.is_dir():
        raise SystemExit(f"TCK feature directory not found: {root}")

    print("set echo off;")
    print("DELETE FROM DB.DBA.OPENCYPHER_TCK_RESULTS;")
    print("DELETE FROM DB.DBA.OPENCYPHER_TCK_CASES;")
    for case in iter_cases(root):
        (
            case_id,
            rel_path,
            feature_name,
            scenario_line,
            scenario_name,
            query_line,
            block_index,
            phase,
            query,
        ) = case
        stored_query = query
        if len(query) > args.max_inline_query:
            stored_query = f"{SKIP_SENTINEL}: length={len(query)}"
        print(
            "INSERT INTO DB.DBA.OPENCYPHER_TCK_CASES "
            "(CASE_ID, FEATURE_PATH, FEATURE_NAME, SCENARIO_LINE, SCENARIO_NAME, "
            "QUERY_LINE, BLOCK_INDEX, PHASE, CYPHER_QUERY) VALUES "
            f"({case_id}, {sql_string(rel_path)}, {sql_string(feature_name)}, "
            f"{scenario_line}, {sql_string(scenario_name)}, {query_line}, "
            f"{block_index}, {sql_string(phase)}, {sql_base64_string(stored_query)});"
        )

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
