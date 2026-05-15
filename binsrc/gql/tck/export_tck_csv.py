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
import sys, subprocess

def export(port, user, password, output_csv):
    isql = 'isql'
    sql = "EXEC=SELECT CASE_ID, FEATURE_PATH, SCENARIO, STATUS, COALESCE(DETAIL, '') FROM DB.DBA.OGQL_TCK_RESULTS ORDER BY CASE_ID;"
    cmd = [isql, str(port), user, password, sql]
    result = subprocess.run(cmd, capture_output=True, text=True)
    lines = result.stdout.strip().split('\n')
    with open(output_csv, 'w') as f:
        f.write('case_id,feature,scenario,status,detail\n')
        data_started = False
        for line in lines:
            line = line.strip()
            if not line:
                continue
            if line.startswith('CASE_ID'):
                data_started = True
                continue
            if data_started and line:
                parts = [p.strip() for p in line.split('\t')]
                if len(parts) >= 4:
                    # Quote fields with commas
                    quoted = []
                    for p in parts:
                        if ',' in p or '"' in p:
                            p = '"' + p.replace('"', '""') + '"'
                        quoted.append(p)
                    f.write(','.join(quoted[:5]) + '\n')
    print(f'Exported to {output_csv}')

if __name__ == '__main__':
    if len(sys.argv) < 5:
        print("Usage: python3 export_tck_csv.py <port> <user> <pass> <output.csv>")
        sys.exit(1)
    export(sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4])
