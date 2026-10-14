#!/bin/sh
#
#  tvvec_refresh_ops.sh
#
#  A refresh of an RDF vector index as an operation: it owns its log mode
#  (log_enable (0) unlogged, log_enable (3) neither failing nor logging every
#  graph page touch separately, the caller's mode handed back), a sparse delta
#  re-embeds exactly its rows, the ONNX plugin's server-wide settings are only
#  ever raised, and build = 'bulk' links a small delta instead of rebuilding.
#
#  The plugin is optional: the ONNX assertions pass vacuously without it.
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

LOGFILE=`pwd`/tvvec_refresh_ops.output
export LOGFILE
. $VIRTUOSO_TEST/testlib.sh

rm -f $LOGFILE

BANNER "STARTED vector index refresh operations test (tvvec_refresh_ops.sh)"

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
    LOG "+ vonnx not built; the ONNX assertions pass vacuously"
fi

START_SERVER $PORT 1000

LOG + run tvvec_refresh_ops.sql
RUN $ISQL $DSN dba dba $VIRTUOSO_TEST/tvvec_refresh_ops.sql VERBOSE=OFF PROMPT=OFF ERRORS=STDOUT
if test $STATUS -ne 0
then
    LOG "***ABORTED: tvvec_refresh_ops.sql"
    exit 3
fi

SHUTDOWN_SERVER

CHECK_LOG

BANNER "COMPLETED vector index refresh operations test (tvvec_refresh_ops.sh)"
