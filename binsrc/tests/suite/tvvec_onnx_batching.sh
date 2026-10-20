#!/bin/sh
#
#  tvvec_onnx_batching.sh
#
#  How the ONNX helper runs one embedding request of many texts.
#
#  A request is padded to its longest text, so one paragraph in a request of
#  labels makes every label cost a paragraph.  Sorting the texts of a request by
#  token count and running them as sub-batches of similar length removes that
#  padding; the vectors go back to their input positions, so the response does
#  not change.  The helper's compile-time cap of 128 texts per request becomes a
#  per-model max_texts, which the plugin enforces before sending.
#
#  Sections, and which of them hold before the change (guards) and which must
#  fail on a binary without it (the tests of it):
#
#  1. Guard.  Every vector of a mixed request equals the same text embedded
#     alone, and different texts stay apart.  The dangerous failure of
#     sorting is a vector scattered to the wrong position; this is its check.
#  2. A 1,024-text request is served, and sampled positions equal the text
#     alone.  Before: the helper refuses more than 128.
#  3. Labels with paragraphs spread through them: the sorted model is at least
#     2x faster than one loaded with sort=0.  Before: sort is not an option,
#     both loads are the same model and the ratio is about 1.
#  4. Guard.  sort=0 returns the same vectors as the sorted model.
#  5. A model loaded with max_texts=16 refuses 17 texts with 22023 and then
#     still serves 16.  Before: the option is ignored.
#  6. Out-of-range max_texts, sub_batch_rows and tokens_per_batch are refused
#     at load.  Before: ignored.
#  7. ONNX_MODEL_INFO reports real and padded tokens, and the sorted model pads
#     less than the unsorted one.  Before: no such fields.
#  8. The refresh honours __vec_embed_batch_size up to the helper's max_texts.
#     Before: capped at 128.
#  9. A request the helper takes longer than helper_timeout_ms to answer fails
#     with an error that names the timeout, and the model serves the next
#     request.  Before: "died on two consecutive requests", with advice to
#     check that the model files are readable.
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

LOGFILE=`pwd`/tvvec_onnx_batching.output
export LOGFILE
. $VIRTUOSO_TEST/testlib.sh

rm -f $LOGFILE

BANNER "STARTED ONNX request batching test"

if [ "$CURRENT_VIRTUOSO_CAPACITY" != "single" ]
then
    LOG "SKIPPED: single-server only"
    BANNER "COMPLETED ONNX request batching test (skipped: not single-server)"
    exit 0
fi

HOSTING="$VIRTUOSO_BUILD/binsrc/hosting"

PROBE()
{
    echo "$1" | $ISQL $DSN dba dba VERBOSE=OFF PROMPT=OFF ERRORS=STDOUT 2>/dev/null \
        | grep -E '^[0-9.eE+-]+$' | head -1
}

#  A SQLSTATE: five capitals or digits on a line of their own.
PROBE_STATE()
{
    echo "$1" | $ISQL $DSN dba dba VERBOSE=OFF PROMPT=OFF ERRORS=STDOUT 2>/dev/null \
        | grep -E '^[0-9A-Z]{5}$' | head -1
}

#  A text: the query returns it behind 'TXT:', which nothing else isql prints
#  begins with.
PROBE_TEXT()
{
    echo "$1" | $ISQL $DSN dba dba VERBOSE=OFF PROMPT=OFF ERRORS=STDOUT 2>/dev/null \
        | grep '^TXT:' | head -1 | sed 's/^TXT://'
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
    BANNER "COMPLETED ONNX request batching test (skipped: vonnx not built)"
    exit 0
fi

START_SERVER $PORT 1000

ok=`PROBE "select case when exists (select 1 from DB.DBA.ONNX_MODELS where model_name = 'granite-384-local' and handle is not null) then 1 else 0 end;"`
if [ "$ok" != "1" ]
then
    LOG "SKIPPED: granite-384-local did not load; nothing to exercise"
    SHUTDOWN_SERVER
    BANNER "COMPLETED ONNX request batching test (skipped: model did not load)"
    exit 0
fi

$ISQL $DSN dba dba VERBOSE=OFF PROMPT=OFF ERRORS=STDOUT >/dev/null 2>&1 <<'SQL'
--  Requests here are larger than the default admission limit of 32.
select ONNX_CONFIG ('max_batch', 2048);

CREATE PROCEDURE tvb_h () RETURNS INT
{
  RETURN (SELECT handle FROM DB.DBA.ONNX_MODELS WHERE model_name = 'granite-384-local');
}
;

--  Load the bundled model the way ONNX_MODEL_REFRESH does, plus EXTRA options.
CREATE PROCEDURE tvb_load (IN extra VARCHAR) RETURNS INT
{
  DECLARE mp, vp, outn VARCHAR;
  DECLARE msl INT;
  SELECT model_path, vocab_path, output_name, max_seq_len INTO mp, vp, outn, msl
    FROM DB.DBA.ONNX_MODELS WHERE model_name = 'granite-384-local';
  mp := DB.DBA.ONNX_RESOLVE_PATH (mp, 'GraniteModelPath');
  vp := DB.DBA.ONNX_RESOLVE_PATH (vp, 'GraniteVocabPath');
  RETURN ONNX_LOAD_MODEL (mp, concat ('input=input_ids;input2=attention_mask;output=', outn,
      ';vocab=', vp, ';max_seq_len=', cast (msl AS VARCHAR), extra));
}
;

--  The SQLSTATE of loading with EXTRA options ('00000' when it loads).
CREATE PROCEDURE tvb_load_state (IN extra VARCHAR) RETURNS VARCHAR
{
  DECLARE st, msg VARCHAR;
  DECLARE md, rs ANY;
  st := '00000';
  exec ('select tvb_load (?)', st, msg, vector (extra), 1, md, rs);
  RETURN st;
}
;

--  The largest difference between two vectors, component by component.
CREATE PROCEDURE tvb_maxdiff (IN u ANY, IN v ANY) RETURNS DOUBLE PRECISION
{
  DECLARE i INT;
  DECLARE worst, d DOUBLE PRECISION;
  IF (length (u) <> length (v) OR length (u) = 0)
    RETURN 1;
  worst := 0;
  FOR (i := 0; i < length (u); i := i + 1)
    {
      d := abs (cast (aref (u, i) AS DOUBLE PRECISION) - cast (aref (v, i) AS DOUBLE PRECISION));
      IF (d > worst)
        worst := d;
    }
  RETURN worst;
}
;

CREATE PROCEDURE tvb_dist (IN u ANY, IN v ANY) RETURNS DOUBLE PRECISION
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

CREATE PROCEDURE tvb_label (IN i INT) RETURNS VARCHAR
{
  DECLARE l ANY;
  l := vector ('Albert Einstein', 'River Thames', 'Mount Everest', 'Paris',
    'Leonardo da Vinci', 'Great Barrier Reef', 'Pacific Ocean', 'Tokyo Tower',
    'Amazon rainforest', 'Sydney Opera House', 'Beethoven', 'Mona Lisa',
    'Nile', 'Sahara Desert', 'Golden Gate Bridge', 'Isaac Newton',
    'Marie Curie', 'Lake Baikal', 'Kilimanjaro', 'Venice', 'Charles Darwin',
    'Grand Canyon', 'Atlantic Ocean', 'Eiffel Tower', 'Danube', 'Ada Lovelace',
    'Mont Blanc', 'Rio de Janeiro', 'Taj Mahal', 'Galileo Galilei', 'Iceland',
    'Victoria Falls');
  RETURN sprintf ('%s %d', aref (l, mod (i, 32)), i);
}
;

--  About 90 tokens.
CREATE PROCEDURE tvb_paragraph (IN i INT) RETURNS VARCHAR
{
  RETURN sprintf ('Part %d. %s', i, concat (
    'The river rises in the Cotswold hills and flows east for more than three hundred ',
    'kilometres, through a string of market towns and university cities, past water ',
    'meadows, locks and weirs, until it widens into a tidal estuary and meets the sea. ',
    'For most of recorded history it was the main road of the region: barges carried ',
    'grain, wool, timber and stone downstream, and coal, sugar and tea came back up.'));
}
;

CREATE PROCEDURE tvb_medium (IN i INT) RETURNS VARCHAR
{
  RETURN sprintf ('Note %d: the river flows east through southern England, past Oxford and Reading, and meets the North Sea.', i);
}
;

--  N texts: a paragraph at every PARA_EVERY-th position, a medium text at
--  every MED_EVERY-th (0: none), labels elsewhere.
CREATE PROCEDURE tvb_mix (IN n INT, IN para_every INT, IN med_every INT) RETURNS ANY
{
  DECLARE v ANY;
  DECLARE i INT;
  v := make_array (n, 'any');
  FOR (i := 0; i < n; i := i + 1)
    {
      IF (mod (i, para_every) = 0)
        aset (v, i, tvb_paragraph (i));
      ELSE IF (med_every > 0 AND mod (i, med_every) = 3)
        aset (v, i, tvb_medium (i));
      ELSE
        aset (v, i, tvb_label (i));
    }
  RETURN v;
}
;

--  Worst component difference between position J of one batch of TEXTS on
--  model H and TEXTS[J] embedded alone, over positions J of POSITIONS (all
--  positions when POSITIONS is empty); 1 when the batch is the wrong size.
CREATE PROCEDURE tvb_worst (IN h INT, IN texts ANY, IN positions ANY) RETURNS DOUBLE PRECISION
{
  DECLARE b ANY;
  DECLARE i, j INT;
  DECLARE worst, d DOUBLE PRECISION;
  b := ONNX_EMBED_BATCH (h, texts);
  IF (length (b) <> length (texts))
    RETURN 1;
  worst := 0;
  IF (length (positions) = 0)
    {
      FOR (j := 0; j < length (texts); j := j + 1)
        {
          d := tvb_maxdiff (ONNX_EMBED_TEXT (h, texts[j]), b[j]);
          IF (d > worst)
            worst := d;
        }
      RETURN worst;
    }
  FOR (i := 0; i < length (positions); i := i + 1)
    {
      j := positions[i];
      d := tvb_maxdiff (ONNX_EMBED_TEXT (h, texts[j]), b[j]);
      IF (d > worst)
        worst := d;
    }
  RETURN worst;
}
;

--  The SQLSTATE of one ONNX_EMBED_BATCH ('00000' when it is served).
CREATE PROCEDURE tvb_embed_state (IN h INT, IN texts ANY) RETURNS VARCHAR
{
  DECLARE st, msg VARCHAR;
  DECLARE md, rs ANY;
  st := '00000';
  exec ('select length (ONNX_EMBED_BATCH (?, ?))', st, msg, vector (h, texts), 1, md, rs);
  RETURN st;
}
;

--  The error message of one ONNX_EMBED_BATCH, '' when it is served.
CREATE PROCEDURE tvb_embed_msg (IN h INT, IN texts ANY) RETURNS VARCHAR
{
  DECLARE st, msg VARCHAR;
  DECLARE md, rs ANY;
  st := '00000';
  msg := '';
  exec ('select length (ONNX_EMBED_BATCH (?, ?))', st, msg, vector (h, texts), 1, md, rs);
  IF (st = '00000')
    RETURN '';
  RETURN msg;
}
;

--  The fastest of REPS runs of one batch of TEXTS on model H, in milliseconds,
--  after two warm-up runs (one per helper of the default pool of two).
CREATE PROCEDURE tvb_time (IN h INT, IN texts ANY, IN reps INT) RETURNS INT
{
  DECLARE r, t0, dt, fastest INT;
  DECLARE b ANY;
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

--  The number after "KEY": in ONNX_MODEL_INFO (H); -1 when there is none.
CREATE PROCEDURE tvb_info_num (IN h INT, IN k VARCHAR) RETURNS INT
{
  DECLARE s VARCHAR;
  DECLARE p INT;
  s := ONNX_MODEL_INFO (h);
  p := strstr (s, concat ('"', k, '":'));
  IF (p IS NULL)
    RETURN -1;
  RETURN atoi (subseq (s, p + length (k) + 3));
}
;

--  Worst component difference between one batch of TEXTS on model H1 and the
--  same batch on model H2, position by position.
CREATE PROCEDURE tvb_pair_worst (IN h1 INT, IN h2 INT, IN texts ANY) RETURNS DOUBLE PRECISION
{
  DECLARE a, b ANY;
  DECLARE j INT;
  DECLARE worst, d DOUBLE PRECISION;
  a := ONNX_EMBED_BATCH (h1, texts);
  b := ONNX_EMBED_BATCH (h2, texts);
  IF (length (a) <> length (texts) OR length (b) <> length (texts))
    RETURN 1;
  worst := 0;
  FOR (j := 0; j < length (texts); j := j + 1)
    {
      d := tvb_maxdiff (a[j], b[j]);
      IF (d > worst)
        worst := d;
    }
  RETURN worst;
}
;

--  VEC_INDEX_EMBED_BATCH_SIZE () with the registry key set to N, which is
--  cleared again before returning.
CREATE PROCEDURE tvb_batch_size_with (IN n VARCHAR) RETURNS INT
{
  DECLARE r INT;
  registry_set ('__vec_embed_batch_size', n);
  r := DB.DBA.VEC_INDEX_EMBED_BATCH_SIZE ();
  registry_set ('__vec_embed_batch_size', '');
  RETURN r;
}
;

--  Real tokens per padded token over one batch of TEXTS on model H, from the
--  counters; -1 when the model has no counters.
CREATE PROCEDURE tvb_efficiency (IN h INT, IN texts ANY) RETURNS DOUBLE PRECISION
{
  DECLARE r0, p0, r1, p1 INT;
  DECLARE b ANY;
  r0 := tvb_info_num (h, 'real_tokens');
  p0 := tvb_info_num (h, 'padded_tokens');
  IF (r0 < 0 OR p0 < 0)
    RETURN -1;
  b := ONNX_EMBED_BATCH (h, texts);
  r1 := tvb_info_num (h, 'real_tokens');
  p1 := tvb_info_num (h, 'padded_tokens');
  IF (p1 <= p0)
    RETURN -1;
  RETURN cast (r1 - r0 AS DOUBLE PRECISION) / cast (p1 - p0 AS DOUBLE PRECISION);
}
;
SQL

#  SMALL "<description>" <select expression>  -- must be below 2e-6.  Not zero:
#  a different sub-batch shape changes the order of the float sums in the
#  attention and the pooling, which moves the last bits (1.3e-7 measured when
#  padding was cut to the longest text).  A vector at the wrong position is off
#  by 1e-2 and more.
SMALL()
{
    v=`PROBE "select sprintf ('%.9f', $2);"`
    CHECK "$1 (difference '$v', must be < 0.000002)" \
        `awk -v d="$v" 'BEGIN { if (d == "") exit 1; if (d < 0) d = -d; exit !(d < 0.000002) }' && echo 1 || echo 0`
}

#  --- 1. a mixed request embeds exactly as its texts do alone -------------
SMALL "every text of a mixed 40-text request embeds as it does alone" \
      "tvb_worst (tvb_h (), tvb_mix (40, 5, 7), vector ())"
v=`PROBE "select sprintf ('%.6f', tvb_dist (aref (b, 1), aref (b, 2))) from (select ONNX_EMBED_BATCH (tvb_h (), tvb_mix (40, 5, 7)) as b) x;"`
CHECK "two different labels of one request stay apart (distance '$v' > 0.1)" \
    `awk -v d="$v" 'BEGIN { if (d == "") exit 1; exit !(d > 0.1) }' && echo 1 || echo 0`

#  --- 2. a request of 1,024 texts ------------------------------------------
v=`PROBE_STATE "select tvb_embed_state (tvb_h (), tvb_mix (1024, 16, 0));"`
CHECK "a 1,024-text request is served (SQLSTATE '$v')" `[ "$v" = "00000" ] && echo 1 || echo 0`
SMALL "sampled texts of a 1,024-text request embed as they do alone" \
      "tvb_worst (tvb_h (), tvb_mix (1024, 16, 0), vector (0, 1, 15, 16, 17, 255, 256, 511, 1000, 1023))"

#  --- 3. sorting pays on labels mixed with paragraphs ----------------------
#  128 texts, a paragraph at every 8th: in request order every sub-batch holds
#  two, so every label costs a paragraph; sorted, the labels run together.
$ISQL $DSN dba dba VERBOSE=OFF PROMPT=OFF ERRORS=STDOUT >/dev/null 2>&1 <<'SQL'
registry_set ('tvb_h_sorted', cast (tvb_h () AS VARCHAR));
registry_set ('tvb_h_unsorted', cast (tvb_load (';sort=0') AS VARCHAR));
SQL
hs=`PROBE "select registry_get ('tvb_h_sorted');"`
hu=`PROBE "select registry_get ('tvb_h_unsorted');"`
LOG "+ sorted model handle $hs, sort=0 model handle $hu"
sorted_ms=`PROBE "select tvb_time ($hs, tvb_mix (128, 8, 0), 3);"`
unsorted_ms=`PROBE "select tvb_time ($hu, tvb_mix (128, 8, 0), 3);"`
LOG "+ 128 texts, a paragraph at every 8th: sorted $sorted_ms ms, sort=0 $unsorted_ms ms (fastest of 3)"
CHECK "sorting a request by length is at least 2x faster than sort=0 (sorted ${sorted_ms} ms, unsorted ${unsorted_ms} ms)" \
    `awk -v s="$sorted_ms" -v u="$unsorted_ms" 'BEGIN { if (s == "" || u == "") exit 1; if (s < 1) s = 1; exit !(u >= 2 * s) }' && echo 1 || echo 0`

#  --- 4. sort=0 returns the same vectors -----------------------------------
SMALL "the sort=0 model returns the vectors the sorted model does" \
      "tvb_pair_worst ($hs, $hu, tvb_mix (128, 8, 0))"

#  --- 5. max_texts is a per-model limit ------------------------------------
$ISQL $DSN dba dba VERBOSE=OFF PROMPT=OFF ERRORS=STDOUT >/dev/null 2>&1 <<'SQL'
registry_set ('tvb_h_16', cast (tvb_load (';max_texts=16') AS VARCHAR));
SQL
h16=`PROBE "select registry_get ('tvb_h_16');"`
v=`PROBE_STATE "select tvb_embed_state ($h16, tvb_mix (17, 5, 0));"`
CHECK "a model with max_texts=16 refuses 17 texts with 22023 (got '$v')" `[ "$v" = "22023" ] && echo 1 || echo 0`
v=`PROBE_STATE "select tvb_embed_state ($h16, tvb_mix (16, 5, 0));"`
CHECK "and still serves 16 afterwards (got '$v')" `[ "$v" = "00000" ] && echo 1 || echo 0`

#  --- 6. out-of-range options are refused at load -------------------------
for opt in "max_texts=0" "max_texts=20000" "sub_batch_rows=0" "tokens_per_batch=4"
do
    v=`PROBE_STATE "select tvb_load_state (';$opt');"`
    CHECK "loading with $opt is refused with 22023 (got '$v')" `[ "$v" = "22023" ] && echo 1 || echo 0`
done

#  --- 7. the counters say how much was padding -----------------------------
es=`PROBE "select sprintf ('%.3f', tvb_efficiency ($hs, tvb_mix (128, 8, 0)));"`
eu=`PROBE "select sprintf ('%.3f', tvb_efficiency ($hu, tvb_mix (128, 8, 0)));"`
LOG "+ real tokens per padded token: sorted $es, sort=0 $eu"
CHECK "ONNX_MODEL_INFO reports real and padded tokens (sorted '$es', sort=0 '$eu')" \
    `awk -v s="$es" -v u="$eu" 'BEGIN { if (s == "" || u == "") exit 1; exit !(s > 0 && u > 0 && s <= 1 && u <= 1) }' && echo 1 || echo 0`
CHECK "the sorted model pads at least 0.3 less than the unsorted one (sorted '$es', sort=0 '$eu')" \
    `awk -v s="$es" -v u="$eu" 'BEGIN { if (s == "" || u == "") exit 1; exit !(s >= u + 0.3) }' && echo 1 || echo 0`

#  --- 8. the refresh can ask for more than 128 texts ------------------------
v=`PROBE "select tvb_batch_size_with ('1024');"`
CHECK "__vec_embed_batch_size 1024 is honoured (got '$v')" `[ "$v" = "1024" ] && echo 1 || echo 0`

#  --- 9. a request slower than helper_timeout_ms says so -------------------
#  The plugin stops a helper that has not answered within helper_timeout_ms --
#  how a wedged helper is escaped -- and larger requests reach that honestly:
#  256 texts of 256 tokens take about 20 s here, against the default of 30 s.
#  64 paragraphs under a 200 ms timeout.
$ISQL $DSN dba dba VERBOSE=OFF PROMPT=OFF ERRORS=STDOUT >/dev/null 2>&1 <<'SQL'
select ONNX_CONFIG ('helper_timeout_ms', 200);
registry_set ('tvb_timeout_msg', tvb_embed_msg (tvb_h (), tvb_mix (64, 1, 0)));
select ONNX_CONFIG ('helper_timeout_ms', 30000);
SQL
msg=`PROBE_TEXT "select concat ('TXT:', registry_get ('tvb_timeout_msg'));"`
LOG "+ the slow request's error: $msg"
CHECK "a request slower than helper_timeout_ms fails, naming the timeout" \
    `echo "$msg" | grep -q 'helper_timeout_ms' && echo 1 || echo 0`
CHECK "and does not blame the model files" \
    `[ -n "$msg" ] && ! echo "$msg" | grep -q 'readable' && echo 1 || echo 0`
v=`PROBE_STATE "select tvb_embed_state (tvb_h (), tvb_mix (8, 4, 0));"`
CHECK "the model serves the next request (got '$v')" `[ "$v" = "00000" ] && echo 1 || echo 0`

SHUTDOWN_SERVER

LOG "+ ONNX request batching: $PASS passed, $FAIL failed"
CHECK_LOG

if [ "$FAIL" != "0" ]
then
    BANNER "COMPLETED ONNX request batching test -- FAILURES PRESENT"
    exit 1
fi

BANNER "COMPLETED ONNX request batching test"
exit 0
