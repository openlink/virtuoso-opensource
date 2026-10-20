#!/bin/sh
#
#  check_test_registration.sh
#
#  Every driver registered in Makefile.am's check_SCRIPTS must either appear in
#  testall.sh's test_set -- the list an actual suite run executes -- or be named
#  in the exclusion list below.
#
#  This exists because two drivers were added to check_SCRIPTS and never to
#  testall.sh, so they silently never ran: tvvec_passthrough_column (e23879b98a)
#  and tvvec_vector_math (b515934029).  The second of those is what covers
#  VEC_INDEX_ABORT_CREATE, so the suite simultaneously had zero coverage of that
#  behaviour and six assertions still expecting the behaviour it replaced.
#  Nothing detected the gap; a full run just quietly did less than it appeared to.
#
#  The exclusion list is the point as much as the check is.  Before this script
#  there was no way to tell a deliberate omission from an accident.
#
#  Usage:  sh check_test_registration.sh          (from binsrc/tests/suite)
#  Exit:   0 = every driver accounted for, 1 = something unregistered
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

#  Harness machinery shipped through check_SCRIPTS but not tests in their own
#  right -- they are sourced or invoked by the harness.
NOT_A_TEST="check_test_registration clean epilog go_functions lowerall prepare_t1 prolog release
            summary testall testlib test_server wtf"

#  Real drivers deliberately not part of a default run: external dependencies
#  (Tcl, JDBC, OLE DB, MS DTC), very long benchmarks, or platform-specific.
#  Moving one of these into testall.sh is a decision, not an oversight -- which
#  is exactly the distinction this list records.
NOT_RUN_BY_DEFAULT="bpel byteorder gtkbench inprocess large_db oledb
                    tblob_recode tcl tclstart tclstop tdatetime tdbp tdconv
                    tdrop test_cluster test_fn test_ldp test_run tjdbc
                    toptiremote tp tproviders treplh tsqllite tstriping tsxml
                    ttpch ttutorial tupgrade_recov tvad2 tvspx twiki"

#  Normalised to a single space-separated line: the lists above span several
#  lines, and `case` patterns match on spaces, not newlines.
EXCLUDED=" $(echo "$NOT_A_TEST $NOT_RUN_BY_DEFAULT" | tr -s ' \t\n' ' ') "

here=`dirname "$0"`
cd "$here" || exit 1

if [ ! -f Makefile.am ] || [ ! -f testall.sh ]
then
    echo "***FAILED: run this from binsrc/tests/suite (Makefile.am and testall.sh not found)"
    exit 1
fi

#  Both lists are backslash-continued.  BS holds a literal backslash so the awk
#  program never has to contain one (command substitution and heredocs mangle it).
BS=$(printf '\134')

#  check_SCRIPTS is one continued assignment in Makefile.am.
registered=$(awk -v bs="$BS" '
  /^check_SCRIPTS[ \t]*=/ { inb = 1 }
  inb {
    line = $0
    sub(/^check_SCRIPTS[ \t]*=/, "", line)
    cont = (substr(line, length(line)) == bs)
    if (cont) line = substr(line, 1, length(line) - 1)
    gsub(/[ \t]+/, "\n", line)
    print line
    if (!cont) exit
  }' Makefile.am | sed 's/\.sh$//' | grep -v '^$' | sort -u)

#  test_set is one continued, double-quoted string in testall.sh.
scheduled=$(awk -v bs="$BS" '
  /^test_set=/ { inb = 1 }
  inb {
    line = $0
    sub(/^test_set=/, "", line)
    gsub(/"/, "", line)
    cont = (substr(line, length(line)) == bs)
    if (cont) line = substr(line, 1, length(line) - 1)
    gsub(/[ \t]+/, "\n", line)
    print line
    if (!cont) exit
  }' testall.sh | grep -v '^$' | sort -u)

#  Space-separated copies for the membership tests below (the lists above are
#  newline-separated, and `case` patterns match on spaces).
registered_sp=" $(echo "$registered" | tr '\n' ' ') "
scheduled_sp=" $(echo "$scheduled" | tr '\n' ' ') "

if [ -z "$registered" ] || [ -z "$scheduled" ]
then
    echo "***FAILED: could not parse check_SCRIPTS or test_set -- has their format changed?"
    exit 1
fi

rc=0

for t in $registered
do
    case "$scheduled_sp" in
        *" $t "*) continue ;;
    esac
    case "$EXCLUDED" in
        *" $t "*) continue ;;
    esac
    echo "***FAILED: $t.sh is in check_SCRIPTS but not in testall.sh's test_set"
    echo "           and is not in this script's exclusion list, so it never runs."
    echo "           Add it to test_set, or to NOT_RUN_BY_DEFAULT with a reason."
    rc=1
done

#  The other direction: scheduled but not registered means the driver will not
#  be distributed, so a release tarball would run a suite that cannot work.
for t in $scheduled
do
    case "$registered_sp" in
        *" $t "*) continue ;;
    esac
    echo "***FAILED: $t is in testall.sh's test_set but not in check_SCRIPTS"
    echo "           (it would be missing from a distribution)."
    rc=1
done

if [ $rc -eq 0 ]
then
    echo "PASSED: every check_SCRIPTS driver is scheduled or explicitly excluded"
fi

exit $rc
