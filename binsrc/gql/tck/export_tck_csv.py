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
Export TCK results to CSV via isql.
Usage: python3 export_tck_csv.py <port> <user> <pass> <output.csv>
"""
import sys, subprocess, os

def export(port, user, password, output_csv):
    # Honor the ISQL env var (the run harness points it at the Virtuoso isql);
    # fall back to 'isql' on PATH.
    isql = os.environ.get('ISQL', 'isql')
    # Emit each row as one sentinel-prefixed, TAB-joined line. isql output is
    # space-padded (not tab-delimited), so we force our own delimiter in SQL
    # and pick data rows out by the sentinel — robust against isql formatting.
    sql = ("EXEC=SELECT '##ROW##' || CAST(CASE_ID AS VARCHAR) || '\\t' || FEATURE_PATH "
           "|| '\\t' || SCENARIO || '\\t' || STATUS || '\\t' || COALESCE(DETAIL, '') "
           "FROM DB.DBA.OGQL_TCK_RESULTS ORDER BY CASE_ID;")
    cmd = [isql, str(port), user, password, sql]
    result = subprocess.run(cmd, capture_output=True, text=True)
    n = 0
    with open(output_csv, 'w') as f:
        f.write('case_id,feature,scenario,status,detail\n')
        for line in result.stdout.split('\n'):
            i = line.find('##ROW##')
            if i < 0:
                continue
            parts = line[i + len('##ROW##'):].split('\t')
            if len(parts) < 4:
                continue
            quoted = []
            for p in parts[:5]:
                p = p.rstrip()
                if ',' in p or '"' in p or '\n' in p:
                    p = '"' + p.replace('"', '""') + '"'
                quoted.append(p)
            f.write(','.join(quoted) + '\n')
            n += 1
    print(f'Exported {n} rows to {output_csv}')

if __name__ == '__main__':
    if len(sys.argv) < 5:
        print("Usage: python3 export_tck_csv.py <port> <user> <pass> <output.csv>")
        sys.exit(1)
    export(sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4])
