#!/bin/sh
#
#  tvvec.sh
#
#  Driver for the native vector-index test suites (SQL and SPARQL surfaces).
#
#  The suites form one ordered chain that shares state established by
#  tvvec_begin.sql (helper functions and the VVEC_BEGIN_* fixtures), so they
#  are run in sequence against a single server, with a clean restart in the
#  middle to prove the on-disk state survives a checkpoint.
#
#  Three dependency gates decide what actually runs; a missing dependency is
#  SKIPPED, never failed, so a default build stays green:
#
#    * the vonnx plugin (--enable-onnxruntime, off by default). The SQL chain builds
#      its index from real embeddings of the bundled model, granite, so without
#      vonnx the whole chain is skipped. When vonnx.so is present in the build
#      tree, this script points the server's plugin LoadPath at it and
#      configures the model root, then confirms at runtime that the model
#      actually embeds before relying on it.
#    * python3, for the OpenAI-compatible HTTP provider fixture
#      (onnx_embedding_mock.py). That path uses the core HTTP client, not the
#      plugin, so it runs independently of vonnx.
#    * the predicate-precise async trigger feature
#      (DB.DBA.VEC_INDEX_SET_TRIGGERS). tvec_sparql_begin and
#      tvec_sparql_async_general exercise it; it lives in work that is not yet
#      committed on this branch (see vvec-production-readiness prompt 04), so
#      they are skipped until it is built in.
#
#  tvec_sparql_reduce and the durability suite (tvvec_crash_recovery.sh, a
#  separate driver) use the in-core test_embedding model and need none of the
#  above.
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

LOGFILE=`pwd`/tvvec.output
export LOGFILE
. $VIRTUOSO_TEST/testlib.sh

rm -f $LOGFILE

BANNER "STARTED vector index test (tvvec.sh)"

#  Vector indexes are single-server only (see prompt 07); nothing to do on a
#  cluster build.
if [ "$CURRENT_VIRTUOSO_CAPACITY" != "single" ]
then
    LOG "SKIPPED: vector index is single-server only"
    BANNER "COMPLETED vector index test (skipped: not single-server)"
    exit 0
fi

HOSTING="$VIRTUOSO_BUILD/binsrc/hosting"

#  Run one .sql suite, appending its PASSED/FAILED lines to $LOGFILE.
RUN_VEC_SQL()
{
    LOG "+ running $1.sql"
    RUN $ISQL $DSN dba dba $VIRTUOSO_TEST/$1.sql VERBOSE=OFF PROMPT=OFF ERRORS=STDOUT
    if test $STATUS -ne 0
    then
        LOG "***ABORTED: $1.sql did not run to completion"
        SHUTDOWN_SERVER
        exit 3
    fi
}

#  Ask the running server a yes/no question; echoes 1 or 0.
PROBE()
{
    echo "$1" | $ISQL $DSN dba dba VERBOSE=OFF PROMPT=OFF ERRORS=STDOUT 2>/dev/null \
        | grep -E '^[01]$' | head -1
}

MAKECFG_FILE $TESTCFGFILE $PORT $CFGFILE

#  ---- ONNX gate -------------------------------------------------------------
#  The harness template already carries `Load8 = plain, vonnx`, but with
#  `LoadPath = .` and no [ONNX] section it resolves nothing.  If the plugin was
#  built, repoint LoadPath at the build hosting dir and add the model paths.
#  If it was not, leave the config alone: the Load8 line fails as a non-fatal
#  warning and the ONNX suites are skipped below.
ONNX=0
if [ -f "$HOSTING/vonnx.so" ]
then
    cp "$CFGFILE" "$CFGFILE.pre_onnx"
    sed -e "s#^LoadPath[ 	]*=.*#LoadPath = $HOSTING#" "$CFGFILE.pre_onnx" > "$CFGFILE"
    rm -f "$CFGFILE.pre_onnx"
    printf '\n[ONNX]\nModelRoot  = %s/onnx-models\nHelperPath = %s/onnx_helper\n' \
        "$HOSTING" "$HOSTING" >> "$CFGFILE"
    ONNX=1
    LOG "+ vonnx plugin found in $HOSTING; ONNX-backed suites enabled"
else
    LOG "+ vonnx plugin not built; ONNX-backed suites will be SKIPPED"
fi

START_SERVER $PORT 1000

#  Belt and suspenders: even with vonnx.so present, confirm the model loads and
#  embeds.  A staged-but-broken plugin (missing runtime lib, unresolved model)
#  must skip, not fail.
if [ $ONNX -eq 1 ]
then
    ok=`PROBE "select case when exists (select 1 from DB.DBA.ONNX_MODELS where model_name = 'granite-384-local' and handle is not null) then 1 else 0 end;"`
    if [ "$ok" != "1" ]
    then
        ONNX=0
        LOG "SKIPPED: vonnx is present but granite-384-local did not load; ONNX-backed suites skipped"
    fi
fi

#  ---- Phase 1: SQL vector chain (needs ONNX) --------------------------------
if [ $ONNX -eq 1 ]
then
    LOG "+ SQL vector chain"
    RUN_VEC_SQL tvvec_begin
    RUN_VEC_SQL tvvec_ann_equiv
    RUN_VEC_SQL tvvec_ann_explain
    RUN_VEC_SQL tvvec_ann_metrics
    RUN_VEC_SQL tvvec_ann_fastlane
    RUN_VEC_SQL tvvec_overflow

    #  Clean restart (checkpoints) to prove the graph and hidden tables persist.
    LOG "+ restarting server to test persistence"
    SHUTDOWN_SERVER
    START_SERVER $PORT 1000

    RUN_VEC_SQL tvvec_begin_reopen
    RUN_VEC_SQL tvvec_overflow_reopen

    #  ANN recall/quality test (prompt 05).  Self-contained -- builds its own
    #  5000-vector graphs from a fixed seed and measures recall against a
    #  brute-force ground truth -- but heavyweight (a few minutes), so it is
    #  gated with the rest of the vector chain rather than run unconditionally.
    RUN_VEC_SQL tvvec_ann_recall

    #  Backfill row-cap / scale test (this fix): builds general + shorthand
    #  indexes over a >10,000-doc corpus (two keyset pages) with the real
    #  granite-384-local model and asserts every doc is indexed (graph_nodes ==
    #  corpus size).  Heavyweight (embeds 10,500 texts), hence gated here.
    RUN_VEC_SQL tvvec_backfill_scale
    #  tvvec_cleanup runs last of all (below): it drops the shared bootstrap
    #  tables ONNX_MODELS and VEC_SQL_QUEUE that the HTTP and SPARQL phases
    #  still need, so it must not run mid-chain.
else
    LOG "SKIPPED: tvvec_begin, tvvec_ann_*, tvvec_overflow, *_reopen (vonnx not built)"
fi

#  ---- Phase 2: HTTP embedding provider (needs python3, not vonnx) -----------
if command -v python3 >/dev/null 2>&1
then
    LOG "+ starting HTTP embedding mock (onnx_embedding_mock.py, 127.0.0.1:19481)"
    python3 $VIRTUOSO_TEST/onnx_embedding_mock.py > tvvec_mock.log 2>&1 &
    MOCKPID=$!
    sleep 2
    if kill -0 $MOCKPID 2>/dev/null
    then
        RUN_VEC_SQL tvvec_http_provider
        kill $MOCKPID 2>/dev/null
        wait $MOCKPID 2>/dev/null
    else
        LOG "SKIPPED: tvvec_http_provider (mock server failed to start; see tvvec_mock.log)"
    fi
else
    LOG "SKIPPED: tvvec_http_provider (python3 not found)"
fi

#  ---- Packed-format delete path (self-contained test_embedding, always) -----
#  Phase 7 regression: deleting rows from a table with a packed vector index
#  must not crash the generic SQL DELETE path.  Self-contained -- creates its own
#  table, test_embedding model and packed index -- so it needs neither vonnx nor
#  the VVEC_BEGIN_* fixtures and runs unconditionally.
RUN_VEC_SQL tvvec_packed_delete

#  Optimizer regression: a native vector index is registered as a secondary key
#  of its base table, so the cost model used to sample it as if it were a
#  B-tree and segfaulted on ANY plain SQL query against that table.  The crash
#  was at compile time, so this needs no embeddings -- self-contained with its
#  own table and test_embedding model, and runs unconditionally.
RUN_VEC_SQL tvvec_optimizer_vector_key

#  Index metadata (rdfs:label / rdfs:comment): the CREATE options, the two
#  access gates on VEC_INDEX_SET_METADATA, and the RDF view over the catalogue
#  installed / dropped / re-installed twice.  Self-contained with its own
#  test_embedding model and its own throwaway accounts, so it runs
#  unconditionally.
RUN_VEC_SQL tvvec_index_metadata

#  Multi-index bif:vector_search: option (index (<a>, <b>)), option (index *),
#  and the RANKING option.  Self-contained -- its own graphs, its own
#  test_embedding models and its own throwaway readers -- so it needs neither
#  vonnx nor the VVEC_BEGIN_* fixtures and runs unconditionally.  Its first
#  assertion is the regression that matters: a single named index answers
#  exactly as it did before any of this existed.
#
#  It runs after tvvec_index_metadata on purpose: its wildcard assertions count
#  what `index *` covers, and that is every active index on the instance, so
#  they are written to tolerate another test's leftovers rather than to depend
#  on running first.
RUN_VEC_SQL tvvec_multi_index

#  SQL CREATE VECTOR INDEX over a table that already has rows indexes every
#  row, at the stock virtuoso.ini's vector batch of 1,000 -- not just the
#  first batch.  Self-contained with its own tables and test_embedding model,
#  so it runs unconditionally.
RUN_VEC_SQL tvvec_sql_backfill

#  Embedding-provider API keys (registry names ONNX_API_KEY_*) are readable
#  and writable by DBA accounts and DBA-owned procedures only.  Its own key,
#  account and procedures; needs neither vonnx nor a provider, so it runs
#  unconditionally.
RUN_VEC_SQL tvvec_api_keys

#  CREATE VECTOR INDEX refuses an hnsw_m whose graph node cannot fit on a
#  page (VEC17) whether the dimension is given or taken from the model, and
#  however large hnsw_m is.  Self-contained with its own tables and
#  test_embedding models, so it runs unconditionally.
RUN_VEC_SQL tvvec_page_fit

#  ---- Phase 3: SPARQL reduce (in-core test_embedding, always) ---------------
RUN_VEC_SQL tvec_sparql_reduce

#  FOR PREDICATE <iri> and the RDF 1.2 PREDICATE() built-in share one word.
#  Compile-only -- no model, vonnx or fixtures -- so it runs unconditionally.
RUN_VEC_SQL tvec_sparql_for_predicate

#  ---- Phase 4: SPARQL trigger-pairs suites (need the async trigger feature) -
#  The trigger-pairs procedures are compiled into the server (they load from the
#  built-in sparql_vec_index.sql bootstrap), so they are callable but never land
#  in SYS_PROCEDURES.  Probe with __proc_exists(), which resolves compiled-in
#  procedures too and returns NULL when the name is unknown.
TRIG=`PROBE "select case when __proc_exists ('DB.DBA.VEC_INDEX_SET_TRIGGERS') is not null then 1 else 0 end;"`
if [ "$TRIG" = "1" ] && [ $ONNX -eq 1 ]
then
    RUN_VEC_SQL tvec_sparql_begin
    RUN_VEC_SQL tvec_sparql_async_general
elif [ "$TRIG" != "1" ]
then
    LOG "SKIPPED: tvec_sparql_begin, tvec_sparql_async_general (predicate-precise async trigger feature not built; see prompt 04)"
else
    LOG "SKIPPED: tvec_sparql_begin, tvec_sparql_async_general (vonnx not built)"
fi

#  ---- Last: teardown --------------------------------------------------------
#  Must be last: it drops ONNX_MODELS, VEC_SQL_QUEUE and the VVEC_BEGIN_*
#  fixtures that every phase above depends on.  Harmless when Phase 1 was
#  skipped -- its DROPs are best-effort and ignore "no such object".
if [ $ONNX -eq 1 ]
then
    RUN_VEC_SQL tvvec_cleanup
else
    LOG "SKIPPED: tvvec_cleanup (nothing was created; vonnx not built)"
fi

SHUTDOWN_SERVER

CHECK_LOG

#  The shared harness reports failures via the summary step rather than exit
#  status; make a broken assertion also fail this driver directly, so a CI that
#  keys on exit status catches it.
if egrep -q "^\*\*\* ?FAILED|^\*\*\* ?ABORTED" $LOGFILE
then
    BANNER "COMPLETED vector index test (tvvec.sh) -- FAILURES PRESENT"
    exit 1
fi

BANNER "COMPLETED vector index test (tvvec.sh)"
exit 0
