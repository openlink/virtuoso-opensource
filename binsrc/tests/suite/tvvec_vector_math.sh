#!/bin/sh
#
#  tvvec_vector_math.sh
#
#  Driver for the vector math and DDL-shorthand suites.
#
#  Unlike tvvec.sh these need no ONNX plugin: the math suites operate on
#  literal vectors, and the shorthand suite registers a test_embedding model
#  for its DDL.  So they run in a default build, where the rest of the vector
#  chain is skipped for want of vonnx.
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

LOGFILE=`pwd`/tvvec_vector_math.output
export LOGFILE
. $VIRTUOSO_TEST/testlib.sh

rm -f $LOGFILE

BANNER "STARTED vector math and DDL shorthand test"

#  Generate this run's virtuoso.ini.  The suite-level copy is produced only by
#  testall.sh's prologue and is deleted by clean.sh (so `make clean` removes it),
#  while testlib.sh's RUN_TEST copies it into every test directory -- which means
#  `make test T=<this>` after a clean would otherwise start with no config and
#  hang in START_SERVER waiting for a server that can never come up.  tvvec.sh and
#  tvvec_onnx_lifecycle.sh already do this; the rest of the vvec drivers did not.
MAKECFG_FILE $TESTCFGFILE $PORT $CFGFILE

START_SERVER $PORT 1000

for suite in tvvec_dot_product tvvec_arithmetic tvvec_create_shorthand tvvec_general_from tvvec_create_abort
do
    LOG "+ running $suite.sql"
    RUN $ISQL $DSN dba dba $VIRTUOSO_TEST/$suite.sql VERBOSE=OFF PROMPT=OFF ERRORS=STDOUT
    if test $STATUS -ne 0
    then
        LOG "***ABORTED: $suite.sql did not run to completion"
        SHUTDOWN_SERVER
        exit 3
    fi
done

SHUTDOWN_SERVER

CHECK_LOG

BANNER "COMPLETED vector math and DDL shorthand test"
