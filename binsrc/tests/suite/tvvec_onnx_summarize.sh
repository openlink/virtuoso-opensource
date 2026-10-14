#!/bin/sh
#
#  tvvec_onnx_summarize.sh
#
#  Extractive summarisation shipped in the ONNX bootstrap.
#
#  DB.DBA.ONNX_SUMMARIZE and DB.DBA.ONNX_SUMMARY_SENTENCES are created by
#  libsrc/Wi/users.sql, like the rest of the ONNX PL, so they are present in
#  every fresh database without anyone loading a file.  That is the first thing
#  this suite asserts, and it is the whole point of the change: the suite's
#  database is created from scratch on every run and has never seen the demo
#  script these procedures grew from.
#
#  The method: embed every sentence, take the document centroid, keep the
#  sentences closest to it, emit them in reading order.  So the assertions about
#  quality are about the one thing the method guarantees -- an off-topic
#  sentence is the furthest from the centroid and must be dropped.
#
#  The ONNX plugin is off by default (--enable-onnxruntime), so like the other
#  ONNX-backed suites this SKIPS (never fails) when vonnx.so is not built, or
#  when the bundled model does not load.  The existence assertions run either
#  way, because the PL is in the bootstrap whether the plugin is built or not.
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

LOGFILE=`pwd`/tvvec_onnx_summarize.output
export LOGFILE
. $VIRTUOSO_TEST/testlib.sh

rm -f $LOGFILE

BANNER "STARTED ONNX summarisation test"

if [ "$CURRENT_VIRTUOSO_CAPACITY" != "single" ]
then
    LOG "SKIPPED: single-server only"
    BANNER "COMPLETED ONNX summarisation test (skipped: not single-server)"
    exit 0
fi

HOSTING="$VIRTUOSO_BUILD/binsrc/hosting"

PROBE()
{
    echo "$1" | $ISQL $DSN dba dba VERBOSE=OFF PROMPT=OFF ERRORS=STDOUT 2>/dev/null \
        | grep -E '^[0-9-]+$' | head -1
}

RAW()
{
    echo "$1" | $ISQL $DSN dba dba VERBOSE=OFF PROMPT=OFF ERRORS=STDOUT 2>&1
}

PASS=0
FAIL=0
CHECK()
{
    if [ "$2" = "1" ]; then PASS=`expr $PASS + 1`; LOG "PASSED: $1"
    else FAIL=`expr $FAIL + 1`; LOG "***FAILED: $1"; fi
}

MAKECFG_FILE $TESTCFGFILE $PORT $CFGFILE

if [ -f "$HOSTING/vonnx.so" ]
then
    cp "$CFGFILE" "$CFGFILE.pre_onnx"
    sed -e "s#^LoadPath[ 	]*=.*#LoadPath = $HOSTING#" "$CFGFILE.pre_onnx" > "$CFGFILE"
    rm -f "$CFGFILE.pre_onnx"
    printf '\n[ONNX]\nModelRoot  = %s/onnx-models\nHelperPath = %s/onnx_helper\n' \
        "$HOSTING" "$HOSTING" >> "$CFGFILE"
    LOG "+ vonnx plugin found in $HOSTING"
else
    LOG "+ vonnx not built; the existence assertions still apply"
fi

START_SERVER $PORT 1000

#  ---- the point of the change: present without anyone loading anything ------
for p in ONNX_SUMMARIZE ONNX_SUMMARY_SENTENCES
do
    v=`PROBE "select case when __proc_exists ('DB.DBA.$p') is null then 0 else 1 end;"`
    CHECK "DB.DBA.$p exists in a fresh database (got '$v')" `[ "$v" = "1" ] && echo 1 || echo 0`
done

#  ---- the splitter ----------------------------------------------------------
v=`PROBE "select length (DB.DBA.ONNX_SUMMARY_SENTENCES ('The first sentence is long enough to survive. The second one also clears the threshold. Too short.'));"`
CHECK "splitter keeps 2 and drops the short fragment (got '$v')" `[ "$v" = "2" ] && echo 1 || echo 0`

#  ---- everything below needs a working embedding model ----------------------
ok=`PROBE "select case when exists (select 1 from DB.DBA.ONNX_MODELS where model_name = 'granite-384-local' and handle is not null) then 1 else 0 end;"`
if [ "$ok" != "1" ]
then
    LOG "+ granite-384-local not loaded; skipping the summarisation assertions"
    LOG "+ ONNX summarisation: $PASS passed, $FAIL failed"
    CHECK_LOG
    SHUTDOWN_SERVER
    [ "$FAIL" != "0" ] && { BANNER "COMPLETED ONNX summarisation test -- FAILURES PRESENT"; exit 1; }
    BANNER "COMPLETED ONNX summarisation test (partial: model not loaded)"
    exit 0
fi

DOC="Virtuoso is a multi-model database system developed by OpenLink Software. It stores relational tables and RDF graphs in the same engine, so one query can span both. The vector index adds semantic search over text columns using HNSW graphs held in native database pages. Embeddings are produced by an ONNX model loaded inside the server process, so no external service is required. Cricket is a bat-and-ball game played between two teams of eleven players. The SPARQL endpoint speaks over HTTP and returns JSON, XML or CSV. Backups capture the vector index along with the rest of the database. The query optimiser costs vector searches alongside ordinary index lookups. Stored procedures written in Virtuoso/PL can be called from SQL and from SPARQL alike."

v=`PROBE "select length (DB.DBA.ONNX_SUMMARY_SENTENCES ('$DOC'));"`
CHECK "the document splits into 9 sentences (got '$v')" `[ "$v" = "9" ] && echo 1 || echo 0`

#  Every assertion below is written so that a failure of the procedure yields
#  an empty result, not a match: PROBE only reports a bare integer, so an isql
#  error -- which echoes the statement, document text and all -- reports ''.

v=`PROBE "select case when strstr (DB.DBA.ONNX_SUMMARIZE ('$DOC', 3), 'Cricket') is null then 1 else 0 end;"`
CHECK "keep=3 drops the off-topic sentence (got '$v')" `[ "$v" = "1" ] && echo 1 || echo 0`

v=`PROBE "select length (DB.DBA.ONNX_SUMMARY_SENTENCES (DB.DBA.ONNX_SUMMARIZE ('$DOC', 3)));"`
CHECK "keep=3 returns 3 sentences (got '$v')" `[ "$v" = "3" ] && echo 1 || echo 0`

#  Reading order: the first sentence of the summary must sit earlier in the
#  source document than the last one, whichever three were chosen.
v=`PROBE "select case when strstr ('$DOC', aref (DB.DBA.ONNX_SUMMARY_SENTENCES (DB.DBA.ONNX_SUMMARIZE ('$DOC', 3)), 0)) < strstr ('$DOC', aref (DB.DBA.ONNX_SUMMARY_SENTENCES (DB.DBA.ONNX_SUMMARIZE ('$DOC', 3)), 2)) then 1 else 0 end;"`
CHECK "kept sentences stay in reading order (got '$v')" `[ "$v" = "1" ] && echo 1 || echo 0`

v=`PROBE "select length (DB.DBA.ONNX_SUMMARY_SENTENCES (DB.DBA.ONNX_SUMMARIZE ('$DOC')));"`
CHECK "keep defaults to 3 (got '$v')" `[ "$v" = "3" ] && echo 1 || echo 0`

#  keep=1 picks the most central sentence, which here is not the first.  Which
#  one depends on the model: under the bundled granite it is the optimiser
#  sentence, 0.8536 from the centroid against the vector-index sentence's
#  0.8509 (sentence-transformers agrees); all-MiniLM-L6-v2 picked the
#  vector-index one.
v=`PROBE "select case when strstr (DB.DBA.ONNX_SUMMARIZE ('$DOC', 1), 'query optimiser costs vector searches') is not null then 1 else 0 end;"`
CHECK "keep=1 returns the most central sentence (got '$v')" `[ "$v" = "1" ] && echo 1 || echo 0`

#  text with no more sentences than we are asked to keep comes back unchanged
v=`PROBE "select case when DB.DBA.ONNX_SUMMARIZE ('Only one sentence here, and it is long enough to survive.', 3) = 'Only one sentence here, and it is long enough to survive.' then 1 else 0 end;"`
CHECK "text shorter than keep is returned unchanged (got '$v')" `[ "$v" = "1" ] && echo 1 || echo 0`

#  A document longer than one embedding batch.  The plugin refuses a batch over
#  max_batch, 32 by default, so anything that embeds a whole document in one
#  call breaks at the 33rd sentence -- which is a short article, not an edge
#  case.
DOC40=`awk 'BEGIN { for (i = 1; i <= 40; i++) printf "Sentence number %d is here and it is long enough to survive the splitter. ", i }'`

v=`PROBE "select length (DB.DBA.ONNX_SUMMARY_SENTENCES ('$DOC40'));"`
CHECK "the long fixture really is 40 sentences (got '$v')" `[ "$v" = "40" ] && echo 1 || echo 0`

v=`PROBE "select length (DB.DBA.ONNX_SUMMARY_SENTENCES (DB.DBA.ONNX_SUMMARIZE ('$DOC40', 3)));"`
CHECK "a document longer than one batch summarises (got '$v')" `[ "$v" = "3" ] && echo 1 || echo 0`

#  The layer underneath.  ONNX_SUMMARIZE chunks before calling this, so the
#  assertions above pass whether or not the procedure below can take a batch
#  larger than max_batch (32).  Every other caller gets whatever this does, so
#  the assertion belongs here rather than on the summariser.
v=`PROBE "select length (DB.DBA.ONNX_EMBED_BATCH_FOR_MODEL ('granite-384-local', DB.DBA.ONNX_SUMMARY_SENTENCES ('$DOC40')));"`
CHECK "ONNX_EMBED_BATCH_FOR_MODEL takes 40 texts in one call (got '$v')" `[ "$v" = "40" ] && echo 1 || echo 0`

#  and the embeddings it returns are real, not a short or padded array
v=`PROBE "select length (aref (DB.DBA.ONNX_EMBED_BATCH_FOR_MODEL ('granite-384-local', DB.DBA.ONNX_SUMMARY_SENTENCES ('$DOC40')), 39));"`
CHECK "the 40th embedding has the model's width (got '$v')" `[ "$v" = "384" ] && echo 1 || echo 0`

#  An unregistered model must fail clearly, not crash.  ONNXP is the ONNX PL's
#  own error token; it cannot appear in isql's echo of the statement.
n=`RAW "select DB.DBA.ONNX_SUMMARIZE ('$DOC', 3, 'no-such-model');" | grep -c 'ONNXP'`
CHECK "an unregistered model fails with an ONNX error (hits=$n)" `[ "$n" -ge 1 ] && echo 1 || echo 0`
v=`PROBE "select 1;"`
CHECK "server alive after that failure (got '$v')" `[ "$v" = "1" ] && echo 1 || echo 0`

SHUTDOWN_SERVER

LOG "+ ONNX summarisation: $PASS passed, $FAIL failed"
CHECK_LOG

if [ "$FAIL" != "0" ]
then
    BANNER "COMPLETED ONNX summarisation test -- FAILURES PRESENT"
    exit 1
fi

BANNER "COMPLETED ONNX summarisation test"
exit 0
