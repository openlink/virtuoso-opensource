#!/bin/sh
#
#  tvvec_literal_ids.sh
#
#  What a vector index embeds and how it stores it: literals only (never an
#  IRI or blank node as text), one row per subject, RDF_OBJ-id change
#  detection on refresh, a bulk graph rebuilt when it no longer agrees with its
#  data, DV_ARRAY_OF_FLOAT storage and its in-place converter, the vector
#  constructors' length/isvector, an unlogged rebuild that stays unlogged, and
#  -- when the ONNX plugin is built -- the helper's batch bound and error text.
#
#  The plugin is optional: every ONNX assertion degrades to a pass when it is
#  absent, and the rest use an in-core test_embedding model.
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

LOGFILE=`pwd`/tvvec_literal_ids.output
export LOGFILE
. $VIRTUOSO_TEST/testlib.sh

rm -f $LOGFILE

BANNER "STARTED vector index literal identity test (tvvec_literal_ids.sh)"

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

LOG + run tvvec_literal_ids.sql
RUN $ISQL $DSN dba dba $VIRTUOSO_TEST/tvvec_literal_ids.sql VERBOSE=OFF PROMPT=OFF ERRORS=STDOUT
if test $STATUS -ne 0
then
    LOG "***ABORTED: tvvec_literal_ids.sql"
    exit 3
fi

SHUTDOWN_SERVER

CHECK_LOG

BANNER "COMPLETED vector index literal identity test (tvvec_literal_ids.sh)"
