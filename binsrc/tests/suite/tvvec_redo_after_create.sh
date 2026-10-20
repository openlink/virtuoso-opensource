#!/bin/sh
#
#  tvvec_redo_after_create.sh
#
#  Roll forward over a log that holds a database's first vector index --
#  CREATE, metadata view, rows, graph page images -- none of it checkpointed.
#
#    1. tvvec_redo_after_create.sql checkpoints, then creates and fills the
#       index (which installs the metadata view);
#    2. raw_exit (), so nothing after the checkpoint reached the database file;
#    3. restart: roll forward replays the log;
#    4. this script counts how often recovery logged a refused graph page --
#       once per index is the contract, not once per page;
#    5. tvvec_redo_after_create_reopen.sql asserts the index was rebuilt and
#       answers, the metadata view is installed once with every IRI id it uses
#       still named, and the bundled model's max_seq_len survived.
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

LOGFILE=`pwd`/tvvec_redo_after_create.output
export LOGFILE
. $VIRTUOSO_TEST/testlib.sh

rm -f $LOGFILE

BANNER "STARTED vector index redo-after-create test (tvvec_redo_after_create.sh)"

MAKECFG_FILE $TESTCFGFILE $PORT $CFGFILE

HOSTING="$VIRTUOSO_BUILD/binsrc/hosting"
if [ -f "$HOSTING/vonnx.so" ]
then
    cp "$CFGFILE" "$CFGFILE.pre_onnx"
    sed -e "s#^LoadPath[ 	]*=.*#LoadPath = $HOSTING#" "$CFGFILE.pre_onnx" > "$CFGFILE"
    rm -f "$CFGFILE.pre_onnx"
    printf '\n[ONNX]\nModelRoot  = %s/onnx-models\nHelperPath = %s/onnx_helper\n' \
        "$HOSTING" "$HOSTING" >> "$CFGFILE"
    LOG "+ vonnx plugin found in $HOSTING"
else
    LOG "+ vonnx not built; the max_seq_len assertion passes vacuously"
fi

START_SERVER $PORT 1000

LOG + phase 1: first vector index, created and filled after the last checkpoint
RUN $ISQL $DSN dba dba $VIRTUOSO_TEST/tvvec_redo_after_create.sql VERBOSE=OFF PROMPT=OFF ERRORS=STDOUT
if test $STATUS -ne 0
then
    LOG "***ABORTED: tvvec_redo_after_create.sql"
    exit 3
fi

LOG + stopping the server with raw_exit -- no checkpoint
STOP_SERVER
sleep 5

LOG + restarting: roll forward replays the index
START_SERVER $PORT 1000

#  Recovery refuses the graph's page images -- their pages are in no
#  checkpointed extent map -- and rebuilds the graph from the embeddings.  One
#  refusal is logged; the rest of the index's records are dead work.
refused=`LC_ALL=C grep -a -c "Skipping the record" virtuoso.log`
LOG "+ recovery logged $refused refused LOG_VEC_PAGE record(s)"
if [ "$refused" -ge 1 ]
then
    LOG "PASSED: precondition -- recovery did refuse the new index's page images ($refused)"
else
    LOG "***FAILED: precondition -- recovery refused no page image, so this run tests nothing"
fi
if [ "$refused" -le 2 ]
then
    LOG "PASSED: a condemned index's remaining redo is skipped without a line per page ($refused)"
else
    LOG "***FAILED: recovery logged one line per refused page ($refused), not one per index"
fi

LOG + phase 2: what roll forward made of it
RUN $ISQL $DSN dba dba $VIRTUOSO_TEST/tvvec_redo_after_create_reopen.sql VERBOSE=OFF PROMPT=OFF ERRORS=STDOUT
if test $STATUS -ne 0
then
    LOG "***ABORTED: tvvec_redo_after_create_reopen.sql"
    exit 3
fi

SHUTDOWN_SERVER

CHECK_LOG

BANNER "COMPLETED vector index redo-after-create test (tvvec_redo_after_create.sh)"
