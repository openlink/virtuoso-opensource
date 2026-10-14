#!/bin/sh
#
#  tvvec_hidden_guard.sh
#
#  Driver for tvvec_hidden_guard.sql: the hidden-embedding-table write guard
#  (vision rules 3/4 -- public DML must not inject arbitrary vectors into a
#  model-bound index; the managed embedding table is server-owned).
#
#  Single server lifetime; self-contained (in-core 'test_embedding' model), so it
#  needs neither the ONNX plugin nor the SPARQL backfill bootstrap.
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

LOGFILE=`pwd`/tvvec_hidden_guard.output
export LOGFILE
. $VIRTUOSO_TEST/testlib.sh

rm -f $LOGFILE

BANNER "STARTED vector index hidden-table guard test"

#  Generate this run's virtuoso.ini.  The suite-level copy is produced only by
#  testall.sh's prologue and is deleted by clean.sh (so `make clean` removes it),
#  while testlib.sh's RUN_TEST copies it into every test directory -- which means
#  `make test T=<this>` after a clean would otherwise start with no config and
#  hang in START_SERVER waiting for a server that can never come up.  tvvec.sh and
#  tvvec_onnx_lifecycle.sh already do this; the rest of the vvec drivers did not.
MAKECFG_FILE $TESTCFGFILE $PORT $CFGFILE

START_SERVER $PORT 1000

RUN $ISQL $DSN dba dba $VIRTUOSO_TEST/tvvec_hidden_guard.sql VERBOSE=OFF PROMPT=OFF ERRORS=STDOUT
if test $STATUS -ne 0
then
    LOG "***ABORTED: tvvec_hidden_guard.sql did not run to completion"
    SHUTDOWN_SERVER
    exit 3
fi

SHUTDOWN_SERVER

CHECK_LOG

BANNER "COMPLETED vector index hidden-table guard test"
