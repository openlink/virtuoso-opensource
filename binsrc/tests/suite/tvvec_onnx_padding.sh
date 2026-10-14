#!/bin/sh
#
#  tvvec_onnx_padding.sh
#
#  How much sequence the ONNX helper feeds the model for a batch of texts.
#
#  The helper tokenizes every text of a batch into a row of
#  max_seq_len tokens -- real tokens, then padding -- and runs the model on the
#  whole [batch, max_seq_len] tensor.  Pads are masked out of attention and out
#  of the pooling, so they change nothing in the result, but the model still
#  does the work for them: a batch of rdfs:labels, three to eight tokens each,
#  costs as much as a batch of abstracts.  A batch need only be as long as its
#  longest text.
#
#  Two properties, then:
#
#  1. The vectors do not depend on how much padding a text gets.  Each short
#     text must embed the same alone, in a batch of other short texts, and in a
#     batch with a text that fills max_seq_len -- three different pad counts
#     once the batch is cut to its longest text.  Holds before and after the
#     change; it is what makes the change safe.
#  2. A batch of short texts costs much less than a batch of long ones.  Before
#     the change both run at max_seq_len and cost about the same.
#  3. max_seq_len is the one in DB.DBA.ONNX_MODELS.  ONNX_MODEL_REFRESH passes
#     the column to ONNX_LOAD_MODEL as max_seq_len=N, but the plugin had no such
#     option: it was dropped without a word, and the helper truncated every text
#     at its built-in 128 whatever the registry said -- 512 for the bundled
#     model, granite-384-local.  Two texts that differ only after a given token
#     must embed the same when that token is past max_seq_len, and differently
#     when it is not.
#  4. So are the thread counts.  ONNX_MODEL_REFRESH built the load options
#     from the row and passed none, so a registered model -- what a vector
#     index, ONNX_SUMMARIZE and the ..._FOR_MODEL functions embed through --
#     always ran one intra- and one inter-op thread per helper.  The row's
#     intra_threads and inter_threads must reach its helpers, survive the
#     re-registration a restart does (ONNX_BOOTSTRAP_MODELS, called here),
#     and, cleared, give back the one-thread model.
#
#  Like the other ONNX-backed suites this SKIPS (never fails) when vonnx.so is
#  not built or the bundled model does not load.
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

LOGFILE=`pwd`/tvvec_onnx_padding.output
export LOGFILE
. $VIRTUOSO_TEST/testlib.sh

rm -f $LOGFILE

BANNER "STARTED ONNX batch padding test"

if [ "$CURRENT_VIRTUOSO_CAPACITY" != "single" ]
then
    LOG "SKIPPED: single-server only"
    BANNER "COMPLETED ONNX batch padding test (skipped: not single-server)"
    exit 0
fi

HOSTING="$VIRTUOSO_BUILD/binsrc/hosting"

PROBE()
{
    echo "$1" | $ISQL $DSN dba dba VERBOSE=OFF PROMPT=OFF ERRORS=STDOUT 2>/dev/null \
        | grep -E '^[0-9.eE+-]+$' | head -1
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
    LOG "SKIPPED: vonnx plugin not built"
    BANNER "COMPLETED ONNX batch padding test (skipped: vonnx not built)"
    exit 0
fi

START_SERVER $PORT 1000

ok=`PROBE "select case when exists (select 1 from DB.DBA.ONNX_MODELS where model_name = 'granite-384-local' and handle is not null) then 1 else 0 end;"`
if [ "$ok" != "1" ]
then
    LOG "SKIPPED: granite-384-local did not load; nothing to exercise"
    SHUTDOWN_SERVER
    BANNER "COMPLETED ONNX batch padding test (skipped: model did not load)"
    exit 0
fi

$ISQL $DSN dba dba VERBOSE=OFF PROMPT=OFF ERRORS=STDOUT >/dev/null 2>&1 <<'SQL'
CREATE PROCEDURE tvvec_pad_h () RETURNS INT
{
  RETURN (SELECT handle FROM DB.DBA.ONNX_MODELS WHERE model_name = 'granite-384-local');
}
;

--  Cosine distance between two vectors.
CREATE PROCEDURE tvvec_pad_dist (IN u ANY, IN v ANY) RETURNS DOUBLE PRECISION
{
  DECLARE i INT;
  DECLARE d, na, nb, x, y DOUBLE PRECISION;
  d := 0; na := 0; nb := 0;
  FOR (i := 0; i < length (u); i := i + 1)
    {
      x := cast (aref (u, i) AS DOUBLE PRECISION);
      y := cast (aref (v, i) AS DOUBLE PRECISION);
      d := d + x * y; na := na + x * x; nb := nb + y * y;
    }
  RETURN 1 - d / (sqrt (na) * sqrt (nb));
}
;

--  Sixteen labels: three to eight tokens each, as rdfs:label values are.
CREATE PROCEDURE tvvec_pad_labels () RETURNS ANY
{
  RETURN vector ('Albert Einstein', 'River Thames', 'Mount Everest', 'Paris',
    'Leonardo da Vinci', 'Great Barrier Reef', 'Pacific Ocean', 'Tokyo Tower',
    'Amazon rainforest', 'Sydney Opera House', 'Beethoven', 'Mona Lisa',
    'Nile', 'Sahara Desert', 'Golden Gate Bridge', 'Isaac Newton');
}
;

--  About 90 tokens: past 64, short of 128.
CREATE PROCEDURE tvvec_pad_part1 () RETURNS VARCHAR
{
  RETURN concat (
    'The river rises in the Cotswold hills and flows east for more than three hundred ',
    'kilometres, through a string of market towns and university cities, past water ',
    'meadows, locks and weirs, until it widens into a tidal estuary and meets the sea. ',
    'For most of recorded history it was the main road of the region: barges carried ',
    'grain, wool, timber and stone downstream, and coal, sugar and tea came back up.');
}
;

--  About 210 tokens: past 128, short of 256.
CREATE PROCEDURE tvvec_pad_part2 () RETURNS VARCHAR
{
  RETURN concat (tvvec_pad_part1 (),
    ' Mills were built wherever the fall of the water allowed, and towns grew around the ',
    'bridges and fords that crossed it.  In the nineteenth century the railways took ',
    'most of the freight, the docks moved towards the estuary, and the upper river ',
    'became a place for rowing, fishing and walking, while engineers built embankments ',
    'and sewers to stop the floods and the smell that had closed parliament in a hot ',
    'summer.  Today a path follows its banks from the source to the flood barrier, and ',
    'the water is clean enough again for salmon, seals and the occasional whale.');
}
;

--  About 620 tokens, well over 512, so it is truncated to max_seq_len and a
--  batch that holds it runs at the full length, whether that is 64 or 512.
CREATE PROCEDURE tvvec_pad_long () RETURNS VARCHAR
{
  RETURN concat (tvvec_pad_part2 (), ' ', tvvec_pad_part2 (), ' ', tvvec_pad_part2 ());
}
;

--  How far apart two texts land that share FILLER and differ only in the
--  words after it.
CREATE PROCEDURE tvvec_pad_tail (IN filler VARCHAR) RETURNS DOUBLE PRECISION
{
  DECLARE h INT;
  h := tvvec_pad_h ();
  RETURN abs (tvvec_pad_dist (
      ONNX_EMBED_TEXT (h, concat (filler, ' In short: cats and dogs.')),
      ONNX_EMBED_TEXT (h, concat (filler, ' In short: quantum field theory.'))));
}
;

--  Set the bundled model's max_seq_len in the registry and reload it.
CREATE PROCEDURE tvvec_pad_set_len (IN n INT) RETURNS INT
{
  UPDATE DB.DBA.ONNX_MODELS SET max_seq_len = n WHERE model_name = 'granite-384-local';
  COMMIT WORK;
  RETURN DB.DBA.ONNX_MODEL_REFRESH ('granite-384-local');
}
;

--  Set the bundled model's thread counts in the registry and reload it.
CREATE PROCEDURE tvvec_pad_set_threads (IN intra INT, IN inter INT) RETURNS INT
{
  UPDATE DB.DBA.ONNX_MODELS SET intra_threads = intra, inter_threads = inter
   WHERE model_name = 'granite-384-local';
  COMMIT WORK;
  RETURN DB.DBA.ONNX_MODEL_REFRESH ('granite-384-local');
}
;

--  About thirty tokens: a batch with it and the labels is cut to its length.
CREATE PROCEDURE tvvec_pad_medium () RETURNS VARCHAR
{
  RETURN 'The river flows east through southern England, past Oxford, Reading and Windsor, before it widens into an estuary below London and meets the North Sea.';
}
;

--  Sixteen long texts, each over max_seq_len.
CREATE PROCEDURE tvvec_pad_long16 () RETURNS ANY
{
  DECLARE v ANY;
  DECLARE i INT;
  v := make_array (16, 'any');
  FOR (i := 0; i < 16; i := i + 1)
    aset (v, i, sprintf ('Part %d. %s', i + 1, tvvec_pad_long ()));
  RETURN v;
}
;

--  The largest distance between a text of TEXTS embedded alone and the same
--  text embedded in one batch of TEXTS followed by EXTRA.
CREATE PROCEDURE tvvec_pad_worst (IN texts ANY, IN extra ANY) RETURNS DOUBLE PRECISION
{
  DECLARE h, i INT;
  DECLARE b ANY;
  DECLARE worst, d DOUBLE PRECISION;
  h := tvvec_pad_h ();
  b := ONNX_EMBED_BATCH (h, vector_concat (texts, extra));
  worst := 0;
  FOR (i := 0; i < length (texts); i := i + 1)
    {
      d := abs (tvvec_pad_dist (ONNX_EMBED_TEXT (h, texts[i]), b[i]));
      IF (d > worst)
        worst := d;
    }
  RETURN worst;
}
;

--  1 when every vector of one batch of TEXTS has 384 elements.
CREATE PROCEDURE tvvec_pad_widths (IN texts ANY) RETURNS INT
{
  DECLARE b ANY;
  DECLARE i INT;
  b := ONNX_EMBED_BATCH (tvvec_pad_h (), texts);
  IF (length (b) <> length (texts))
    RETURN 0;
  FOR (i := 0; i < length (b); i := i + 1)
    IF (length (b[i]) <> 384)
      RETURN 0;
  RETURN 1;
}
;

--  The fastest of REPS runs of one batch of TEXTS, in milliseconds, after two
--  warm-up runs (one per helper of the default pool of two).
CREATE PROCEDURE tvvec_pad_time (IN texts ANY, IN reps INT) RETURNS INT
{
  DECLARE h, r, t0, dt, fastest INT;
  DECLARE b ANY;
  h := tvvec_pad_h ();
  b := ONNX_EMBED_BATCH (h, texts);
  b := ONNX_EMBED_BATCH (h, texts);
  fastest := 1000000000;
  FOR (r := 0; r < reps; r := r + 1)
    {
      t0 := msec_time ();
      b := ONNX_EMBED_BATCH (h, texts);
      dt := msec_time () - t0;
      IF (dt < fastest)
        fastest := dt;
    }
  RETURN fastest;
}
;
SQL

#  TINY "<description>" <select expression>  -- the distance must be below 1e-5.
#  Not exactly zero: a shorter tensor can change the order of the float sums in
#  the softmax and the pooling, which moves the last bits.  Unmasked padding
#  moves a label's vector by 1e-2 and more.
TINY()
{
    v=`PROBE "select sprintf ('%.9f', $2);"`
    CHECK "$1 (distance '$v', must be < 0.00001)" \
        `awk -v d="$v" 'BEGIN { if (d == "") exit 1; if (d < 0) d = -d; exit !(d < 0.00001) }' && echo 1 || echo 0`
}

#  --- 1. the vectors do not depend on the padding --------------------------
TINY "labels embed the same alone and in a batch of labels" \
     "tvvec_pad_worst (tvvec_pad_labels (), vector ())"
TINY "labels embed the same alone and beside a text that fills max_seq_len" \
     "tvvec_pad_worst (tvvec_pad_labels (), vector (tvvec_pad_long ()))"
TINY "labels embed the same alone and beside a medium text" \
     "tvvec_pad_worst (tvvec_pad_labels (), vector (tvvec_pad_medium ()))"
TINY "the long text embeds the same alone and ahead of the labels" \
     "tvvec_pad_worst (vector (tvvec_pad_long ()), tvvec_pad_labels ())"
TINY "the medium text embeds the same alone and ahead of the labels" \
     "tvvec_pad_worst (vector (tvvec_pad_medium ()), tvvec_pad_labels ())"

v=`PROBE "select tvvec_pad_widths (vector_concat (tvvec_pad_labels (), vector (tvvec_pad_medium ())));"`
CHECK "every vector of a mixed batch has 384 elements (got '$v')" `[ "$v" = "1" ] && echo 1 || echo 0`

#  A cut that copied one row over the others would still pass the checks above
#  for the row it copied; different labels must stay different.
v=`PROBE "select sprintf ('%.6f', tvvec_pad_dist (aref (b, 3), aref (b, 10))) from (select ONNX_EMBED_BATCH (tvvec_pad_h (), tvvec_pad_labels ()) as b) x;"`
CHECK "different labels in one batch stay apart (distance '$v' > 0.1)" \
    `awk -v d="$v" 'BEGIN { if (d == "") exit 1; exit !(d > 0.1) }' && echo 1 || echo 0`

#  --- 2. a batch of short texts is cheap -----------------------------------
short_ms=`PROBE "select tvvec_pad_time (tvvec_pad_labels (), 3);"`
long_ms=`PROBE "select tvvec_pad_time (tvvec_pad_long16 (), 3);"`
LOG "+ 16 labels: $short_ms ms; 16 texts at max_seq_len: $long_ms ms (fastest of 3)"
CHECK "16 labels embed at least 3x faster than 16 long texts (labels ${short_ms} ms, long ${long_ms} ms)" \
    `awk -v s="$short_ms" -v l="$long_ms" 'BEGIN { if (s == "" || l == "") exit 1; if (s < 1) s = 1; exit !(l >= 3 * s) }' && echo 1 || echo 0`

#  --- 3. max_seq_len comes from the registry -------------------------------
#  APART "<description>" <select expression>  -- the distance must exceed 1e-3.
APART()
{
    v=`PROBE "select sprintf ('%.9f', $2);"`
    CHECK "$1 (distance '$v', must be > 0.001)" \
        `awk -v d="$v" 'BEGIN { if (d == "") exit 1; exit !(d > 0.001) }' && echo 1 || echo 0`
}

v=`PROBE "select max_seq_len from DB.DBA.ONNX_MODELS where model_name = 'granite-384-local';"`
CHECK "precondition -- the registry holds max_seq_len 512 for the bundled model (got '$v')" `[ "$v" = "512" ] && echo 1 || echo 0`
APART "with max_seq_len 512, texts that differ only after token 128 embed differently" \
      "tvvec_pad_tail (tvvec_pad_part2 ())"

v=`PROBE "select case when tvvec_pad_set_len (64) > 0 then 1 else 0 end;"`
CHECK "max_seq_len set to 64 and the model reloaded (got '$v')" `[ "$v" = "1" ] && echo 1 || echo 0`
TINY "with max_seq_len 64, texts that differ only after token 64 embed the same" \
     "tvvec_pad_tail (tvvec_pad_part1 ())"
APART "with max_seq_len 64, a difference inside the first 64 tokens still shows" \
      "tvvec_pad_tail ('')"

v=`PROBE "select case when tvvec_pad_set_len (512) > 0 then 1 else 0 end;"`
CHECK "max_seq_len back to 512 and the model reloaded (got '$v')" `[ "$v" = "1" ] && echo 1 || echo 0`
APART "back at 512, texts that differ after token 64 embed differently again" \
      "tvvec_pad_tail (tvvec_pad_part1 ())"

#  --- 4. thread counts come from the registry ------------------------------
#  This server's helpers are its children; count those whose command line
#  has $1, after an embedding through the registered model has started them.
SERVER_PID=`lsof -nP -iTCP:$PORT -sTCP:LISTEN -t 2>/dev/null | head -1`
HELPERS_WITH()
{
    PROBE "select length (DB.DBA.ONNX_EMBED_TEXT_FOR_MODEL ('granite-384-local', 'start a helper'));" > /dev/null
    for p in `pgrep -P "$SERVER_PID" -f onnx_helper 2>/dev/null`; do ps -o command= -p $p; done \
        | grep -c -- "$1"
}
HANDLE()
{
    PROBE "select handle from DB.DBA.ONNX_MODELS where model_name = 'granite-384-local';"
}

h1=`HANDLE`
v=`PROBE "select case when tvvec_pad_set_threads (2, 2) > 0 then 1 else 0 end;"`
CHECK "intra_threads and inter_threads set to 2 in the registry and the model reloaded (got '$v')" \
    `[ "$v" = "1" ] && echo 1 || echo 0`
h2=`HANDLE`
CHECK "the reloaded model is a new one (handle '$h1', then '$h2')" \
    `[ -n "$h2" ] && [ "$h2" != "$h1" ] && echo 1 || echo 0`
n=`HELPERS_WITH '--intra-threads 2 --inter-threads 2 '`
CHECK "the registered model's helpers run two intra- and two inter-op threads (found $n)" \
    `[ "$n" -ge 1 ] && echo 1 || echo 0`
TINY "and embed what the one-thread model did" \
     "tvvec_pad_dist (ONNX_EMBED_TEXT ($h1, 'the same text through both'), DB.DBA.ONNX_EMBED_TEXT_FOR_MODEL ('granite-384-local', 'the same text through both'))"

PROBE "select DB.DBA.ONNX_BOOTSTRAP_MODELS ();" > /dev/null
v=`PROBE "select 10 * coalesce (intra_threads, 0) + coalesce (inter_threads, 0) from DB.DBA.ONNX_MODELS where model_name = 'granite-384-local';"`
CHECK "re-registration at start-up keeps them (got '$v', 22 means both are still 2)" \
    `[ "$v" = "22" ] && echo 1 || echo 0`
h3=`HANDLE`
CHECK "and loads the two-thread model again (handle '$h3', '$h2' before)" \
    `[ -n "$h3" ] && [ "$h3" = "$h2" ] && echo 1 || echo 0`

v=`PROBE "select case when tvvec_pad_set_threads (null, null) > 0 then 1 else 0 end;"`
h4=`HANDLE`
CHECK "cleared, the row gives back the one-thread model (handle '$h4', '$h1' at the start)" \
    `[ "$v" = "1" ] && [ "$h4" = "$h1" ] && echo 1 || echo 0`

SHUTDOWN_SERVER

LOG "+ ONNX batch padding: $PASS passed, $FAIL failed"
CHECK_LOG

if [ "$FAIL" != "0" ]
then
    BANNER "COMPLETED ONNX batch padding test -- FAILURES PRESENT"
    exit 1
fi

BANNER "COMPLETED ONNX batch padding test"
exit 0
