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

Produces SQL INSERT statements for DB.DBA.OGQL_TCK_CASES.
Usage: python3 extract_tck_cases.py <features_dir>
"""
import sys, os, re

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
                # Find GQL query blocks (""" ... """)
                queries = re.findall(r'"""(.*?)"""', scenario_body, re.DOTALL)
                for q in queries:
                    q = q.strip()
                    if q and ('MATCH' in q.upper() or 'CREATE' in q.upper() or 'INSERT' in q.upper()
                              or 'RETURN' in q.upper() or 'SESSION' in q.upper()):
                        case_id += 1
                        escaped = q.replace("'", "''")
                        print(f"INSERT INTO DB.DBA.OGQL_TCK_CASES (CASE_ID, FEATURE_PATH, SCENARIO, QUERY_TEXT)")
                        print(f"  VALUES ({case_id}, '{feature}', '{scenario_name[:200]}', '{escaped[:4000]}');")

if __name__ == '__main__':
    feature_dir = sys.argv[1] if len(sys.argv) > 1 else '.'
    extract_cases(feature_dir)
