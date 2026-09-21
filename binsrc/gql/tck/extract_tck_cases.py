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
"""
Extract GQL TCK cases from Gherkin feature files.

Produces SQL INSERT statements for DB.DBA.OGQL_TCK_CASES, including a parsed
EXPECTED_RESULT so the runner can do golden-row comparison (not just verify
that queries translate/execute).

EXPECTED_RESULT encoding (or NULL when the scenario has no machine-checkable
outcome):
  EMPTY               -> the query must return no rows
  ERROR:<code>        -> executing the query must raise an exception
  ROWS:<canonical>    -> unordered result; compare as a multiset
  ROWSORD:<canonical> -> ordered result (ORDER BY); row order significant

<canonical> serializes the Gherkin result table into the same normalized form
the runner produces from the actual SPARQL result: each row is the
'colname=value' pairs sorted by column name and joined by '|'; rows are joined
by ' ; ' (sorted for the unordered case) and wrapped in [ ].

Value normalization bridges the property-graph <-> SPARQL-over-RDF gap so the
comparison is meaningful: true/false -> 1/0, null -> null, quoted strings are
unquoted. (Scenarios whose expected values are nodes/paths/lists will simply
report RESULT_MISMATCH in the runner rather than a false RESULT_OK.)

Usage: python3 extract_tck_cases.py <features_dir>
"""
import sys, os, re

def norm_cell(s):
    s = s.strip()
    low = s.lower()
    if low == 'true':  return '1'
    if low == 'false': return '0'
    if low == 'null':  return 'null'
    if len(s) >= 2 and s[0] == "'" and s[-1] == "'": return s[1:-1]
    if len(s) >= 2 and s[0] == '"' and s[-1] == '"': return s[1:-1]
    return s

def split_row(line):
    # '| a | b |' -> ['a', 'b']
    parts = [c.strip() for c in line.strip().strip('|').split('|')]
    return parts

def serialize_table(header, rows, ordered):
    row_strs = []
    for r in rows:
        pairs = sorted('%s=%s' % (h, norm_cell(v)) for h, v in zip(header, r))
        row_strs.append('|'.join(pairs))
    if not ordered:
        row_strs = sorted(row_strs)
    return '[' + ' ; '.join(row_strs) + ']'

def parse_expected(body):
    """Return the EXPECTED_RESULT marker string, or None."""
    lines = body.split('\n')
    for idx, raw in enumerate(lines):
        line = raw.strip()
        low = line.lower()
        m = re.match(r'then an exception condition should be raised:\s*(\S+)', low)
        if m:
            return 'ERROR:' + m.group(1).upper()
        if low.startswith('then the result should be empty') or low.startswith('then result should be empty'):
            return 'EMPTY'
        if low.startswith('then the result should be'):
            ordered = ('in any order' not in low)  # 'in order' or bare -> ordered
            # collect the following pipe-table
            tbl = []
            for follow in lines[idx + 1:]:
                fs = follow.strip()
                if fs.startswith('|'):
                    tbl.append(split_row(fs))
                elif fs == '' :
                    if tbl:
                        break
                    continue
                else:
                    break
            if len(tbl) >= 1:
                header = tbl[0]
                data = tbl[1:]
                return ('ROWSORD:' if ordered else 'ROWS:') + serialize_table(header, data, ordered)
            return None
    return None

def extract_cases(features_dir):
    case_id = 0
    print("-- Auto-generated TCK cases")
    for root, dirs, files in os.walk(features_dir):
        for fname in sorted(files):
            if not fname.endswith('.feature'):
                continue
            path = os.path.join(root, fname)
            rel_path = os.path.relpath(path, features_dir)
            feature = rel_path.replace('.feature', '').replace('/', '.')
            with open(path) as f:
                content = f.read()
            # Extract scenarios with their GQL queries
            scenarios = re.split(r'\n\s*(?:Scenario|Scenario Outline):\s*(.*?)\n', content)
            for i in range(1, len(scenarios), 2):
                scenario_name = scenarios[i].strip()
                scenario_body = scenarios[i+1] if i+1 < len(scenarios) else ''
                expected = parse_expected(scenario_body)
                # Find GQL query blocks (""" ... """). A scenario may contain a
                # setup query ('Given having executed the program: ...') before
                # the query under test ('When executing query/program: ...').
                # The Then expectation applies only to the query under test,
                # which is the LAST query block; earlier (setup) blocks get NULL.
                queries = [q.strip() for q in re.findall(r'"""(.*?)"""', scenario_body, re.DOTALL)]
                queries = [q for q in queries
                           if q and ('MATCH' in q.upper() or 'CREATE' in q.upper() or 'INSERT' in q.upper()
                                     or 'RETURN' in q.upper() or 'SESSION' in q.upper())]
                for qi, q in enumerate(queries):
                    is_last = (qi == len(queries) - 1)
                    case_id += 1
                    escaped = q.replace("'", "''")
                    sc_name = scenario_name[:200].replace("'", "''")
                    if expected is None or not is_last:
                        exp_sql = 'NULL'
                    else:
                        exp_sql = "'" + expected.replace("'", "''")[:4000] + "'"
                    print("INSERT INTO DB.DBA.OGQL_TCK_CASES (CASE_ID, FEATURE_PATH, SCENARIO, QUERY_TEXT, EXPECTED_RESULT)")
                    print("  VALUES (%d, '%s', '%s', '%s', %s);" % (
                        case_id, feature, sc_name, escaped[:4000], exp_sql))

if __name__ == '__main__':
    feature_dir = sys.argv[1] if len(sys.argv) > 1 else '.'
    extract_cases(feature_dir)
