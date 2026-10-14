#!/bin/sh
#
#  tvvec_simd.sh
#
#  Which distance kernels the vector index runs, and whether they compute what
#  they should.
#
#  libsrc/vvec/vvec_simd.h has NEON kernels (arm64), AVX2+FMA kernels (x86-64)
#  and plain scalar loops.  The AVX2 bodies were compiled only under -mavx2
#  -mfma, which no build passes, so an x86-64 server ran the scalar loops --
#  which compilers do not vectorize at -O2, a float reduction needing
#  -ffast-math.  They are now chosen at start-up from what the CPU supports.
#
#  1. __VEC_SIMD_INFO () reports the kernel family in use, whether the CPU has
#     AVX2 and FMA, and the family the build selected at compile time.
#  2. The family in use matches the machine, which the shell finds out on its
#     own: neon on arm64; on x86-64, avx2 when the CPU lists avx2 and fma,
#     scalar otherwise.  On an x86-64 machine with AVX2 this is the test of the
#     run-time choice; elsewhere it holds either way.
#  3. __VEC_SIMD_SELFTEST (dim) runs all six kernels of the family in use --
#     L2, L1 and inner product, on native and on on-page (big-endian) vectors --
#     against a double-precision oracle, at dimensions 1 .. 1025.
#  4. The same for the scalar family, which x86-64 without AVX2 runs.
#  5. An unknown or unavailable family is refused.
#  6. Guard: L1_DISTANCE, L2_DISTANCE and DOT_PRODUCT of two 20-float vectors
#     equal exact values.  Holds before and after on arm64; on an x86-64 build
#     with the AVX2 L1 kernel, L1_DISTANCE came out 104 instead of 200 -- the
#     first half of every 16-float block summed as zero.
#
#  Needs no plugin.
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

LOGFILE=`pwd`/tvvec_simd.output
export LOGFILE
. $VIRTUOSO_TEST/testlib.sh

rm -f $LOGFILE

BANNER "STARTED vector distance kernel test"

if [ "$CURRENT_VIRTUOSO_CAPACITY" != "single" ]
then
    LOG "SKIPPED: single-server only"
    BANNER "COMPLETED vector distance kernel test (skipped: not single-server)"
    exit 0
fi

PROBE()
{
    echo "$1" | $ISQL $DSN dba dba VERBOSE=OFF PROMPT=OFF ERRORS=STDOUT 2>/dev/null \
        | grep -E '^[0-9.eE+-]+$' | head -1
}

#  A SQLSTATE: five capitals or digits on a line of their own.
PROBE_STATE()
{
    echo "$1" | $ISQL $DSN dba dba VERBOSE=OFF PROMPT=OFF ERRORS=STDOUT 2>/dev/null \
        | grep -E '^[0-9A-Z]{5}$' | head -1
}

PASS=0
FAIL=0
CHECK()
{
    if [ "$2" = "1" ]; then PASS=`expr $PASS + 1`; LOG "PASSED: $1"
    else FAIL=`expr $FAIL + 1`; LOG "***FAILED: $1"; fi
}

#  What this machine should run, found out without asking the server:
#  1 = neon, 2 = avx2, 3 = scalar.
arch=`uname -m`
case "$arch" in
    arm64|aarch64)
        want=1; want_name=neon ;;
    x86_64|amd64)
        if [ -r /proc/cpuinfo ]
        then
            flags=`grep -m1 '^flags' /proc/cpuinfo`
        else
            flags=`sysctl -n machdep.cpu.features machdep.cpu.leaf7_features 2>/dev/null | tr 'A-Z' 'a-z'`
        fi
        if echo "$flags" | grep -q -w avx2 && echo "$flags" | grep -q -w fma
        then
            want=2; want_name=avx2
        else
            want=3; want_name=scalar
        fi ;;
    *)
        want=3; want_name=scalar ;;
esac
LOG "+ this machine is $arch; it should run the $want_name kernels"

MAKECFG_FILE $TESTCFGFILE $PORT $CFGFILE
START_SERVER $PORT 1000

$ISQL $DSN dba dba VERBOSE=OFF PROMPT=OFF ERRORS=STDOUT >/dev/null 2>&1 <<'SQL'
--  1 = neon, 2 = avx2, 3 = scalar, 0 = anything else.
CREATE PROCEDURE tvs_code (IN f VARCHAR) RETURNS INT
{
  IF (f = 'neon') RETURN 1;
  IF (f = 'avx2') RETURN 2;
  IF (f = 'scalar') RETURN 3;
  RETURN 0;
}
;

--  The largest error of the six kernels of FAMILY over dimensions 1 .. MAXD.
CREATE PROCEDURE tvs_worst (IN family VARCHAR, IN maxd INT) RETURNS DOUBLE PRECISION
{
  DECLARE d INT;
  DECLARE worst, e DOUBLE PRECISION;
  worst := 0;
  FOR (d := 1; d <= maxd; d := d + 1)
    {
      e := aref (__VEC_SIMD_SELFTEST (d, family), 1);
      IF (e > worst)
        worst := e;
    }
  RETURN worst;
}
;

CREATE PROCEDURE tvs_state (IN family VARCHAR) RETURNS VARCHAR
{
  DECLARE st, msg VARCHAR;
  DECLARE md, rs ANY;
  st := '00000';
  exec ('select __VEC_SIMD_SELFTEST (8, ?)', st, msg, vector (family), 1, md, rs);
  RETURN st;
}
;

--  1 .. 20 and 20 .. 1.
CREATE PROCEDURE tvs_up () RETURNS ANY
{
  DECLARE v ANY;
  DECLARE i INT;
  v := make_array (20, 'any');
  FOR (i := 0; i < 20; i := i + 1)
    aset (v, i, cast (i + 1 AS DOUBLE PRECISION));
  RETURN v;
}
;
CREATE PROCEDURE tvs_down () RETURNS ANY
{
  DECLARE v ANY;
  DECLARE i INT;
  v := make_array (20, 'any');
  FOR (i := 0; i < 20; i := i + 1)
    aset (v, i, cast (20 - i AS DOUBLE PRECISION));
  RETURN v;
}
;
SQL

#  --- 1. what the server reports -----------------------------------------
v=`PROBE "select tvs_code (aref (__VEC_SIMD_INFO (), 0));"`
CHECK "__VEC_SIMD_INFO () names a known family in use (code '$v')" \
    `[ "$v" = "1" -o "$v" = "2" -o "$v" = "3" ] && echo 1 || echo 0`
v=`PROBE "select tvs_code (aref (__VEC_SIMD_INFO (), 2));"`
CHECK "__VEC_SIMD_INFO () names the build's family (code '$v')" \
    `[ "$v" = "1" -o "$v" = "2" -o "$v" = "3" ] && echo 1 || echo 0`

#  --- 2. the family matches the machine ------------------------------------
v=`PROBE "select tvs_code (aref (__VEC_SIMD_INFO (), 0));"`
CHECK "the server runs the $want_name kernels on this $arch machine (code '$v', want '$want')" \
    `[ "$v" = "$want" ] && echo 1 || echo 0`
v=`PROBE "select aref (__VEC_SIMD_INFO (), 1);"`
if [ "$want" = "1" ]
then
    CHECK "an arm64 server does not claim AVX2 and FMA (got '$v')" `[ "$v" = "0" ] && echo 1 || echo 0`
else
    CHECK "the server's view of AVX2 and FMA matches the CPU's (got '$v')" \
        `[ "$want" = "2" -a "$v" = "1" -o "$want" = "3" -a "$v" = "0" ] && echo 1 || echo 0`
fi

#  --- 3 and 4. every kernel against a double-precision oracle -------------
for fam in auto scalar
do
    v=`PROBE "select sprintf ('%.9f', tvs_worst ('$fam', 1025));"`
    CHECK "the $fam kernels agree with a double oracle at dims 1..1025 (worst '$v', must be < 0.00001)" \
        `awk -v d="$v" 'BEGIN { if (d == "") exit 1; exit !(d < 0.00001) }' && echo 1 || echo 0`
done
if [ "$want" = "2" ]
then
    v=`PROBE "select sprintf ('%.9f', tvs_worst ('avx2', 1025));"`
    CHECK "the avx2 kernels agree with a double oracle at dims 1..1025 (worst '$v', must be < 0.00001)" \
        `awk -v d="$v" 'BEGIN { if (d == "") exit 1; exit !(d < 0.00001) }' && echo 1 || echo 0`
fi

#  --- 5. an unknown family is refused --------------------------------------
v=`PROBE_STATE "select tvs_state ('sse9');"`
CHECK "an unknown kernel family is refused with 22023 (got '$v')" `[ "$v" = "22023" ] && echo 1 || echo 0`
if [ "$want" = "1" ]
then
    v=`PROBE_STATE "select tvs_state ('avx2');"`
    CHECK "the avx2 family is refused on arm64 (got '$v')" `[ "$v" = "22023" ] && echo 1 || echo 0`
fi

#  --- 6. the distance BIFs on 20 floats -------------------------------------
#  |i - (21 - i)| over 1..20 is 200; the squares sum to 2660; the products to 1540.
v=`PROBE "select sprintf ('%.4f', L1_DISTANCE (tvs_up (), tvs_down ()));"`
CHECK "L1_DISTANCE of 1..20 and 20..1 is 200 (got '$v')" \
    `awk -v d="$v" 'BEGIN { if (d == "") exit 1; exit !(d > 199.999 && d < 200.001) }' && echo 1 || echo 0`
v=`PROBE "select sprintf ('%.4f', L2_DISTANCE (tvs_up (), tvs_down ()));"`
CHECK "L2_DISTANCE of 1..20 and 20..1 is sqrt (2660) (got '$v')" \
    `awk -v d="$v" 'BEGIN { if (d == "") exit 1; t = sqrt (2660); exit !(d > t - 0.001 && d < t + 0.001) }' && echo 1 || echo 0`
v=`PROBE "select sprintf ('%.4f', DOT_PRODUCT (tvs_up (), tvs_down ()));"`
CHECK "DOT_PRODUCT of 1..20 and 20..1 is 1540 (got '$v')" \
    `awk -v d="$v" 'BEGIN { if (d == "") exit 1; exit !(d > 1539.999 && d < 1540.001) }' && echo 1 || echo 0`

SHUTDOWN_SERVER

LOG "+ vector distance kernels: $PASS passed, $FAIL failed"
CHECK_LOG

if [ "$FAIL" != "0" ]
then
    BANNER "COMPLETED vector distance kernel test -- FAILURES PRESENT"
    exit 1
fi

BANNER "COMPLETED vector distance kernel test"
exit 0
