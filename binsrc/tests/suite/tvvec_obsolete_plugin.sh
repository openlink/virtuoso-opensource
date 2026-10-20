#!/bin/sh
#
#  tvvec_obsolete_plugin.sh
#
#  Driver asserting that vvec exists exactly once: in the engine.
#
#  Background.  vvec started life as a loadable plugin under
#  binsrc/hosting/vvec (b2e195eb06) and was later reimplemented inside the
#  engine as libsrc/Wi/vvec.c.  The prototype was never removed, so a build
#  still produced binsrc/hosting/vvec.so, and a virtuoso.ini carrying
#  "Load = plain, vvec" still loaded it.  Loading it is not merely redundant:
#  bif_define () replaces an existing definition, and the two implementations
#  disagree about how a vector is represented, so five names the engine also
#  defines -- VVEC_ADD, VVEC_SUBTRACT, VVEC_SCALAR_MULTIPLY, VVEC_NORMALIZE
#  and VVEC_DIMENSION -- were silently rebound to the prototype's versions and
#  crashed when handed an engine vector.
#
#  Three assertions, all read from the source tree, so this driver needs no
#  server:
#
#    1. no BIF name is defined by both the engine's vvec and a plugin under
#       binsrc/hosting -- the collision itself, whatever its source;
#    2. the obsolete binsrc/hosting/vvec tree is gone and no longer wired into
#       binsrc/hosting/Makefile.am or configure.ac;
#    3. no stale vvec plugin object is left in the LoadPath directory, since
#       that is what an existing ini would actually load.
#
#  The engine's own semantics for the five formerly colliding names are
#  asserted by tvvec_arithmetic.sql, which runs as part of tvvec.sh.
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

LOGFILE=`pwd`/tvvec_obsolete_plugin.output
export LOGFILE
. $VIRTUOSO_TEST/testlib.sh

rm -f $LOGFILE

BANNER "STARTED obsolete vvec plugin test (tvvec_obsolete_plugin.sh)"

WORK=`pwd`/tvvec_obsolete_plugin.work
rm -rf $WORK
mkdir -p $WORK

if test ! -f "$TOP/libsrc/Wi/vvec.c"
then
    LOG "***FAILED: cannot read $TOP/libsrc/Wi/vvec.c (is \$TOP set?)"
    CHECK_LOG
    BANNER "COMPLETED obsolete vvec plugin test (tvvec_obsolete_plugin.sh)"
    exit 0
fi

#  Every name passed to bif_define / bif_define_ex / bif_define_typed in a
#  translation unit.  BIF names are string literals in the first argument.
BIF_NAMES()
{
    cat "$@" 2>/dev/null |
      grep -o 'bif_define[a-z_]*[ 	]*([ 	]*"[^"]*"' |
      sed -e 's/.*"\(.*\)"/\1/' |
      sort -u
}

BIF_NAMES "$TOP/libsrc/Wi/vvec.c" > $WORK/engine.bifs

#
#  1. Engine/plugin BIF name collisions.
#
PLUGIN_SRC=`find "$TOP/binsrc/hosting" -name '*.c' -print 2>/dev/null`
if test "x$PLUGIN_SRC" = "x"
then
    : > $WORK/plugin.bifs
else
    BIF_NAMES $PLUGIN_SRC > $WORK/plugin.bifs
fi

comm -12 $WORK/engine.bifs $WORK/plugin.bifs > $WORK/collisions

if test -s $WORK/collisions
then
    LOG "***FAILED: BIF name(s) defined by both the engine and a binsrc/hosting plugin: `tr '\n' ' ' < $WORK/collisions`"
else
    LOG "PASSED: no BIF name is defined by both the engine and a plugin (`wc -l < $WORK/engine.bifs | tr -d ' '` engine names checked)"
fi

#
#  2. The obsolete plugin tree, and its build wiring, are gone.
#
if test -d "$TOP/binsrc/hosting/vvec"
then
    LOG "***FAILED: obsolete plugin tree $TOP/binsrc/hosting/vvec still exists"
else
    LOG "PASSED: obsolete plugin tree binsrc/hosting/vvec is gone"
fi

if grep -E '^SUBDIRS[^#]*[ 	=]vvec([ 	]|$)' "$TOP/binsrc/hosting/Makefile.am" >/dev/null 2>&1
then
    LOG "***FAILED: binsrc/hosting/Makefile.am still builds the vvec plugin (SUBDIRS)"
else
    LOG "PASSED: binsrc/hosting/Makefile.am no longer builds the vvec plugin"
fi

if grep -E 'binsrc/hosting/vvec/Makefile' "$TOP/configure.ac" >/dev/null 2>&1
then
    LOG "***FAILED: configure.ac still configures binsrc/hosting/vvec/Makefile"
else
    LOG "PASSED: configure.ac no longer configures binsrc/hosting/vvec"
fi

#
#  3. Nothing loadable named vvec is left where the ini's LoadPath points.
#
STALE=`ls -1 "$TOP/binsrc/hosting"/vvec.so "$TOP/binsrc/hosting"/vvec.la \
             "$TOP/binsrc/hosting"/vvec.dylib "$TOP/binsrc/hosting"/vvec.dll 2>/dev/null`
if test "x$STALE" != "x"
then
    LOG "***FAILED: a loadable vvec plugin is still in the plugin LoadPath, remove it: `echo $STALE`"
else
    LOG "PASSED: no loadable vvec plugin in the binsrc/hosting LoadPath"
fi

CHECK_LOG

BANNER "COMPLETED obsolete vvec plugin test (tvvec_obsolete_plugin.sh)"
