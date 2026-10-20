#!/bin/sh
#
#  tvvec_onnx_lifecycle.sh
#
#  ONNX helper subprocess lifecycle test (prompt 13).
#
#  Exercises the forked-helper hardening in binsrc/hosting/onnx/onnx_plugin.c by
#  driving a live server and manipulating the helper processes from the shell
#  (pgrep / kill / lsof), which is why this is a shell driver with no companion
#  .sql chain.  It asserts:
#
#    1. an embedding round-trips (a helper is forked and answers);
#    2. lsof on the helper shows NO inherited database files or listener sockets
#       (fd close-on-exec / close-from-child fix);
#    3. SIGKILLing the helper mid-life is transparently recovered by respawn --
#       the next embed succeeds and the server stays up;
#    4. pointing helper_path at a missing binary fails with a clear error and
#       forks NOTHING (no respawn storm);
#    5. reloading the model with other intra_threads, inter_threads or opt
#       gives a new model whose helpers run with those options (they were
#       not part of the reuse key, and opt never reached a helper);
#    6. a wedged (SIGSTOP-ed) helper does not hang a worker forever -- with a
#       short helper_timeout_ms the embed returns rather than blocking;
#    7. a frozen helper does not survive server shutdown as an orphan;
#    8. and none of it touches a helper of another server: a decoy that looks
#       like one (an onnx_helper ... --server command line) is still running,
#       and not stopped, at the end.
#
#  The ONNX plugin is off by default (--enable-onnxruntime), so like the other
#  ONNX-backed suites this SKIPS (never fails) when vonnx.so is not built, and
#  also when the staged plugin is present but the model does not actually load.
#  It uses the bundled granite-384-local model.
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

LOGFILE=`pwd`/tvvec_onnx_lifecycle.output
export LOGFILE
. $VIRTUOSO_TEST/testlib.sh

rm -f $LOGFILE

BANNER "STARTED ONNX helper lifecycle test"

#  Vector/ONNX is single-server only; nothing to do on a cluster build.
if [ "$CURRENT_VIRTUOSO_CAPACITY" != "single" ]
then
    LOG "SKIPPED: single-server only"
    BANNER "COMPLETED ONNX helper lifecycle test (skipped: not single-server)"
    exit 0
fi

HOSTING="$VIRTUOSO_BUILD/binsrc/hosting"

#  Ask the running server a one-line question; echoes the first bare value.
PROBE()
{
    echo "$1" | $ISQL $DSN dba dba VERBOSE=OFF PROMPT=OFF ERRORS=STDOUT 2>/dev/null \
        | grep -E '^[0-9-]+$' | head -1
}

#  Length of an embedding for a text via the loaded model handle.
EMBED_LEN()
{
    PROBE "select length (ONNX_EMBED_TEXT ((select handle from DB.DBA.ONNX_MODELS where model_name = 'granite-384-local'), '$1'));"
}

#  pids of this server's helpers: its children.  Sections 3, 6 and 7 kill and
#  stop what this returns, so it must not reach another server's -- a
#  machine-wide pgrep -f 'onnx_helper .*--server' did.  SERVER_PID is set once
#  the server is up.
HELPER_PIDS()
{
    pgrep -P "$SERVER_PID" -f onnx_helper 2>/dev/null | tr '\n' ' '
}

PASS=0
FAIL=0
CHECK()   #  CHECK "<description>" <ok?0/1>
{
    if [ "$2" = "1" ]; then PASS=`expr $PASS + 1`; LOG "PASSED: $1"
    else FAIL=`expr $FAIL + 1`; LOG "***FAILED: $1"; fi
}

MAKECFG_FILE $TESTCFGFILE $PORT $CFGFILE

#  ---- ONNX gate: repoint LoadPath and add the model/helper paths ------------
ONNX=0
if [ -f "$HOSTING/vonnx.so" ]
then
    cp "$CFGFILE" "$CFGFILE.pre_onnx"
    sed -e "s#^LoadPath[ 	]*=.*#LoadPath = $HOSTING#" "$CFGFILE.pre_onnx" > "$CFGFILE"
    rm -f "$CFGFILE.pre_onnx"
    printf '\n[ONNX]\nModelRoot  = %s/onnx-models\nHelperPath = %s/onnx_helper\n' \
        "$HOSTING" "$HOSTING" >> "$CFGFILE"
    ONNX=1
    LOG "+ vonnx plugin found in $HOSTING"
else
    LOG "SKIPPED: vonnx plugin not built"
    BANNER "COMPLETED ONNX helper lifecycle test (skipped: vonnx not built)"
    exit 0
fi

START_SERVER $PORT 1000
SERVER_PID=`lsof -nP -iTCP:$PORT -sTCP:LISTEN -t 2>/dev/null | head -1`
CHECK "the server's pid is known, so helpers can be told apart (pid '$SERVER_PID')" \
    `[ -n "$SERVER_PID" ] && echo 1 || echo 0`

#  Section 8's decoy: a process that looks like another server's helper.  The
#  owner's server, or another suite run, can have real ones on this machine.
DECOY_DIR=`pwd`/tvvec_onnx_decoy
rm -rf "$DECOY_DIR"; mkdir -p "$DECOY_DIR"
printf '#!/bin/sh\nwhile :; do sleep 1; done\n' > "$DECOY_DIR/onnx_helper"
/bin/sh "$DECOY_DIR/onnx_helper" --model decoy --server &
DECOY_PID=$!

#  Confirm the model actually loads and embeds; a staged-but-broken plugin skips.
ok=`PROBE "select case when exists (select 1 from DB.DBA.ONNX_MODELS where model_name = 'granite-384-local' and handle is not null) then 1 else 0 end;"`
if [ "$ok" != "1" ]
then
    LOG "SKIPPED: granite-384-local did not load; nothing to exercise"
    #  The decoy is ours: section 8 stops it, but a skip never gets there.
    kill -9 $DECOY_PID 2>/dev/null
    rm -rf "$DECOY_DIR"
    SHUTDOWN_SERVER
    BANNER "COMPLETED ONNX helper lifecycle test (skipped: model did not load)"
    exit 0
fi

#  Section 5's comparison: 1 when two handles embed a text to the same vector.
$ISQL $DSN dba dba VERBOSE=OFF PROMPT=OFF ERRORS=STDOUT >/dev/null 2>&1 <<'SQL'
create procedure DB.DBA.TVL_SAME_VECTOR (in a integer, in b integer, in t varchar) returns integer
{
  declare u, v any;
  declare i integer;
  u := ONNX_EMBED_TEXT (a, t);
  v := ONNX_EMBED_TEXT (b, t);
  if (length (u) = 0 or length (u) <> length (v))
    return 0;
  for (i := 0; i < length (u); i := i + 1)
    if (aref (u, i) <> aref (v, i))
      return 0;
  return 1;
};
SQL

#  --- 1. baseline embed forks a helper and answers ---------------------------
n=`EMBED_LEN "hello world"`
CHECK "baseline embed returns 384 (got '$n')" `[ "$n" = "384" ] && echo 1 || echo 0`

hp=`HELPER_PIDS`
LOG "+ helper pids: $hp"

#  --- 2. lsof: no inherited database files or listener sockets ---------------
first=`echo $hp | awk '{print $1}'`
if [ -n "$first" ] && command -v lsof >/dev/null 2>&1
then
    leaked=`lsof -p $first 2>/dev/null | grep -icE 'virtuoso\.(db|trx)|[[:space:]]TCP.*LISTEN'`
    CHECK "helper inherited no db/listener fds (leaked=$leaked)" `[ "$leaked" = "0" ] && echo 1 || echo 0`
else
    LOG "+ lsof unavailable or no helper pid; skipping fd-inheritance check"
fi

#  --- 3. SIGKILL the helper(s); the next embed must recover via respawn ------
kill -9 $hp 2>/dev/null
sleep 1
n=`EMBED_LEN "after kill"`
CHECK "embed recovers after helper SIGKILL (got '$n')" `[ "$n" = "384" ] && echo 1 || echo 0`
alive=`PROBE "select 1;"`
CHECK "server alive after helper kill" `[ "$alive" = "1" ] && echo 1 || echo 0`

#  --- 4. bad helper_path: clear error, and NOTHING forked --------------------
before=`HELPER_PIDS | wc -w | tr -d ' '`
err=`echo "ONNX_CONFIG ('helper_path', '/nonexistent/dir/onnx_helper');" \
        | $ISQL $DSN dba dba VERBOSE=OFF PROMPT=OFF ERRORS=STDOUT 2>&1 \
        | grep -ic 'not executable'`
CHECK "bad helper_path is rejected with a clear error" `[ "$err" -ge 1 ] && echo 1 || echo 0`
sleep 1
after=`HELPER_PIDS | wc -w | tr -d ' '`
CHECK "bad helper_path forked no new helper (before=$before after=$after)" `[ "$after" -le "$before" ] && echo 1 || echo 0`
#  the good path must be intact -- embeds still work
n=`EMBED_LEN "still ok"`
CHECK "working helper_path preserved after a bad config (got '$n')" `[ "$n" = "384" ] && echo 1 || echo 0`

#  --- 5. reloading with other thread or optimisation options ----------------
#  A load hands back the running model when it asks for the same model in the
#  same way.  intra_threads, inter_threads and opt are part of the way, but
#  were not compared: a reload with intra_threads=2 got the running entry, and
#  its single-threaded helpers, back.  And opt never reached a helper at all.
#  Each variant gets one helper (the pool size is lowered for the section and
#  put back) and is unloaded as soon as it is checked.
MODEL="$HOSTING/onnx-models/granite-embedding-30m-english"
OPTS="input=input_ids;input2=attention_mask;output=pooled_output;vocab=$MODEL/vocab.json;max_seq_len=512"
LOAD()
{
    PROBE "select ONNX_LOAD_MODEL ('$MODEL/model.onnx', '$OPTS$1');"
}
#  How many of this server's helpers have $1 on their command line, after
#  one embedding through handle $2 has started them.
HELPERS_WITH()
{
    PROBE "select length (ONNX_EMBED_TEXT ($2, 'start a helper'));" > /dev/null
    for p in `HELPER_PIDS`; do ps -o command= -p $p; done | grep -c -- "$1"
}
UNLOAD()
{
    [ -n "$1" ] && [ "$1" != "$h_base" ] && PROBE "select ONNX_UNLOAD_MODEL ($1);" > /dev/null
}

pool=`PROBE "select ONNX_CONFIG ('helper_pool_size');"`
PROBE "select ONNX_CONFIG ('helper_pool_size', 1);" > /dev/null

h_base=`LOAD ""`
h_same=`LOAD ";intra_threads=1"`
CHECK "an explicit intra_threads=1 is the default, so the same model (base=$h_base got=$h_same)" \
    `[ -n "$h_base" ] && [ "$h_same" = "$h_base" ] && echo 1 || echo 0`

h=`LOAD ";intra_threads=2"`
CHECK "intra_threads=2 is a different model (base=$h_base got=$h)" \
    `[ -n "$h" ] && [ "$h" != "$h_base" ] && echo 1 || echo 0`
n=`HELPERS_WITH '--intra-threads 2 ' $h`
CHECK "its helper runs with --intra-threads 2 (found $n)" `[ "$n" -ge 1 ] && echo 1 || echo 0`
same=`PROBE "select DB.DBA.TVL_SAME_VECTOR ($h_base, $h, 'the same text through both models');"`
CHECK "and embeds the same vector as the single-threaded model (same=$same)" `[ "$same" = "1" ] && echo 1 || echo 0`
UNLOAD $h

h=`LOAD ";inter_threads=2"`
CHECK "inter_threads=2 is a different model (base=$h_base got=$h)" \
    `[ -n "$h" ] && [ "$h" != "$h_base" ] && echo 1 || echo 0`
n=`HELPERS_WITH '--inter-threads 2 ' $h`
CHECK "its helper runs with --inter-threads 2 (found $n)" `[ "$n" -ge 1 ] && echo 1 || echo 0`
UNLOAD $h

h=`LOAD ";opt=1"`
CHECK "opt=1 is a different model (base=$h_base got=$h)" \
    `[ -n "$h" ] && [ "$h" != "$h_base" ] && echo 1 || echo 0`
n=`HELPERS_WITH '--opt-level 1' $h`
CHECK "its helper runs with --opt-level 1 (found $n)" `[ "$n" -ge 1 ] && echo 1 || echo 0`
UNLOAD $h

PROBE "select ONNX_CONFIG ('helper_pool_size', ${pool:-2});" > /dev/null
n=`EMBED_LEN "after the reloads"`
CHECK "the registered model still embeds after the reloads (got '$n')" `[ "$n" = "384" ] && echo 1 || echo 0`

#  --- 6. wedged (SIGSTOP-ed) helper must not hang a worker forever -----------
PROBE "select case when ONNX_CONFIG ('helper_timeout_ms', 3000) is null then 0 else 0 end;" >/dev/null 2>&1
echo "ONNX_CONFIG ('helper_timeout_ms', 3000);" | $ISQL $DSN dba dba VERBOSE=OFF PROMPT=OFF ERRORS=STDOUT >/dev/null 2>&1
kill -STOP `HELPER_PIDS` 2>/dev/null
#  run the embed in the background and give it a generous deadline; if the
#  timeout works it finishes in a few seconds, if it hangs we time out at 30s.
( EMBED_LEN "frozen" > tvvec_onnx_frozen.out 2>&1 ) &
qpid=$!
waited=0
while kill -0 $qpid 2>/dev/null && [ $waited -lt 30 ]; do sleep 1; waited=`expr $waited + 1`; done
if kill -0 $qpid 2>/dev/null
then
    kill -9 $qpid 2>/dev/null
    CHECK "wedged helper did not hang the worker (still blocked after ${waited}s)" 0
else
    fn=`cat tvvec_onnx_frozen.out 2>/dev/null`
    CHECK "wedged helper escaped by timeout in ${waited}s (embed='$fn')" `[ "$fn" = "384" ] && echo 1 || echo 0`
fi
rm -f tvvec_onnx_frozen.out

#  --- 7. shutdown leaves no orphaned helpers (even the frozen one) -----------
pre_shutdown=`HELPER_PIDS`
kill -STOP `HELPER_PIDS` 2>/dev/null   #  ensure at least one wedged helper at exit
SHUTDOWN_SERVER
sleep 3
orphans=0
for p in $pre_shutdown; do
    if ps -p $p >/dev/null 2>&1; then orphans=`expr $orphans + 1`; kill -9 $p 2>/dev/null; fi
done
CHECK "no orphaned helpers after shutdown (orphans=$orphans)" `[ "$orphans" = "0" ] && echo 1 || echo 0`

#  --- 8. another server's helper was left alone -------------------------------
#  A decoy that was killed is a zombie until this shell reaps it, so ps still
#  lists it: Z is dead, T is stopped, and an empty state is gone.
st=`ps -o state= -p $DECOY_PID 2>/dev/null | tr -d ' '`
case "$st" in ""|T*|Z*) ok=0 ;; *) ok=1 ;; esac
CHECK "a helper of another server is still running and not stopped (state '$st')" $ok
kill -CONT $DECOY_PID 2>/dev/null
kill -9 $DECOY_PID 2>/dev/null
rm -rf "$DECOY_DIR"

LOG "+ ONNX helper lifecycle: $PASS passed, $FAIL failed"
CHECK_LOG

if [ "$FAIL" != "0" ]
then
    BANNER "COMPLETED ONNX helper lifecycle test -- FAILURES PRESENT"
    exit 1
fi

BANNER "COMPLETED ONNX helper lifecycle test"
exit 0
