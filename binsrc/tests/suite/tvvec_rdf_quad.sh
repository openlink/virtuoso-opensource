#!/bin/sh
#
#  tvvec_rdf_quad.sh
#
#  Vector indexes over RDF literals (DB.DBA.RDF_OBJ) and knnSimilar / bif:knnSimilar on
#  RDF_QUAD.O.  The Northwind demo tables are mapped to RDF with nwgqmap.sql and copied to a
#  physical graph with RDF_VIEW_SYNC_TO_PHYSICAL, which also keeps it in step with the tables;
#  probe literals are added and removed around it.  An index is created and built in one call,
#  queried, changed, dropped; then created again step by step (define, embed, build).
#
#  The embedding model is the in-core test_embedding, so the test needs no ONNX plugin; the
#  plugin is configured when it is built but nothing depends on it.
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

LOGFILE=`pwd`/tvvec_rdf_quad.output
export LOGFILE
. $VIRTUOSO_TEST/testlib.sh

rm -f $LOGFILE

BANNER "STARTED RDF_OBJ vector index and knnSimilar test (tvvec_rdf_quad.sh)"

NOLITE

MAKECFG_FILE $TESTCFGFILE $PORT $CFGFILE
sed -e "s/^CaseMode[ 	]*=.*/CaseMode = 2/" $CFGFILE > tmp.ini
mv -f tmp.ini $CFGFILE

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
    LOG "+ vonnx not built; the test uses the in-core test_embedding model only"
fi

START_SERVER $PORT 1000

LOG "+ loading Northwind demo data"
RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT -u XENC=$XENCRYPT < $VIRTUOSO_TEST/nwdemo.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: nwdemo.sql: loading northwind data"
    exit 3
fi

LOG "+ defining the Northwind quad maps"
RUN $ISQL $DSN PROMPT=OFF VERBOSE=OFF ERRORS=STDOUT -u XENC=$XENCRYPT < $VIRTUOSO_TEST/nwgqmap.sql
if test $STATUS -ne 0
then
    LOG "***ABORTED: nwgqmap.sql: northwind quad maps"
    exit 3
fi

LOG "+ run tvvec_rdf_quad.sql"
RUN $ISQL $DSN dba dba $VIRTUOSO_TEST/tvvec_rdf_quad.sql VERBOSE=OFF PROMPT=OFF ERRORS=STDOUT
if test $STATUS -ne 0
then
    LOG "***ABORTED: tvvec_rdf_quad.sql"
    exit 3
fi

#  knnSimilar's SIMILARITY and DISTANCE through a hash join: each joined row
#  keeps its own score.  Its own graph, model and index.
LOG "+ run tvvec_rdf_knn_hash.sql"
RUN $ISQL $DSN dba dba $VIRTUOSO_TEST/tvvec_rdf_knn_hash.sql VERBOSE=OFF PROMPT=OFF ERRORS=STDOUT
if test $STATUS -ne 0
then
    LOG "***ABORTED: tvvec_rdf_knn_hash.sql"
    exit 3
fi

#  knnSimilar inside OPTIONAL: a score in the optional part compiles, and
#  the subjects the optional part does not match bind nothing.  Its own
#  graph, model and index.
LOG "+ run tvvec_rdf_knn_optional.sql"
RUN $ISQL $DSN dba dba $VIRTUOSO_TEST/tvvec_rdf_knn_optional.sql VERBOSE=OFF PROMPT=OFF ERRORS=STDOUT
if test $STATUS -ne 0
then
    LOG "***ABORTED: tvvec_rdf_knn_optional.sql"
    exit 3
fi

#  knnSimilar with a small k searches as widely as with a large one.  Its own
#  graph, model and index.
LOG "+ run tvvec_rdf_knn_breadth.sql"
RUN $ISQL $DSN dba dba $VIRTUOSO_TEST/tvvec_rdf_knn_breadth.sql VERBOSE=OFF PROMPT=OFF ERRORS=STDOUT
if test $STATUS -ne 0
then
    LOG "***ABORTED: tvvec_rdf_knn_breadth.sql"
    exit 3
fi

#  bif:vector_search score and distance variables named ?s or ?S.  Here
#  because this driver runs with CaseMode 2, the stock virtuoso.ini's, under
#  which ?s collided too.  Its own graph, model and indexes.
LOG "+ run tvvec_search_score_var.sql"
RUN $ISQL $DSN dba dba $VIRTUOSO_TEST/tvvec_search_score_var.sql VERBOSE=OFF PROMPT=OFF ERRORS=STDOUT
if test $STATUS -ne 0
then
    LOG "***ABORTED: tvvec_search_score_var.sql"
    exit 3
fi

SHUTDOWN_SERVER

CHECK_LOG

BANNER "COMPLETED RDF_OBJ vector index and knnSimilar test (tvvec_rdf_quad.sh)"
