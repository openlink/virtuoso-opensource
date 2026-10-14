#!/bin/sh
#
#  tvvec_onnx_export_tool.sh
#
#  The bring-your-own-embedding-model export tool.
#
#  A stock HuggingFace ONNX export cannot be used on the embedding path: it
#  takes three inputs where the helper binds two, and its output is unpooled.
#  virtuoso-export-embedding-model closes that, so this suite is about the artifact it
#  produces being loadable and correct.
#
#  Two parts, because they need different things.
#
#  Part A tests the part most likely to be silently wrong: deciding how a model
#  pools.  Guessing mean-pool for a CLS-pooled model does not fail, it returns
#  plausible embeddings that rank badly -- the exact defect that made an early
#  MiniLM export of ours need re-exporting.  So the plan is read from the
#  model's own sentence-transformers configuration, and that is pure JSON
#  reading: no torch, no network, fixtures written here.  It also asserts the
#  script does not even import torch on this path, by putting a torch that
#  raises on PYTHONPATH.
#
#  Part A also reads which tokenizer the model needs, because the helper
#  implements two -- WordPiece and byte-level BPE -- and an export for any
#  other one can load but never tokenize.
#
#  Part B needs torch and transformers, and SKIPS without them.  It exports the
#  real granite-embedding-30m-english from the local HuggingFace cache and
#  asserts the embedding matches the bundled model, which was exported from
#  that same source.  Reproducing a known-good artifact is the assertion that
#  matters; shape checks alone would not show it.
#
#  Part B also exports with --bf16-weights.  granite publishes bf16 weights,
#  so its fp32 export carries nothing in the low 16 bits of any weight; stored
#  as bf16 the file halves, and the server must then give exactly the vectors
#  the fp32 export gives -- every component equal, not merely close.
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

LOGFILE=`pwd`/tvvec_onnx_export_tool.output
export LOGFILE
. $VIRTUOSO_TEST/testlib.sh

rm -f $LOGFILE

BANNER "STARTED ONNX embedding export tool test"

if [ "$CURRENT_VIRTUOSO_CAPACITY" != "single" ]
then
    LOG "SKIPPED: single-server only"
    BANNER "COMPLETED ONNX embedding export tool test (skipped: not single-server)"
    exit 0
fi

PASS=0
FAIL=0
CHECK()
{
    if [ "$2" = "1" ]; then PASS=`expr $PASS + 1`; LOG "PASSED: $1"
    else FAIL=`expr $FAIL + 1`; LOG "***FAILED: $1"; fi
}

DONE_EARLY()
{
    LOG "+ ONNX export tool: $PASS passed, $FAIL failed"
    CHECK_LOG
    if [ "$FAIL" != "0" ]
    then
        BANNER "COMPLETED ONNX embedding export tool test -- FAILURES PRESENT"
        exit 1
    fi
    BANNER "COMPLETED ONNX embedding export tool test ($1)"
    exit 0
}

#  ---- locate the script ----------------------------------------------------
TOOL=""
for d in "$VIRTUOSO_BUILD/binsrc/hosting/onnx" "$VIRTUOSO_TEST/../../hosting/onnx"
do
    if [ -f "$d/virtuoso-export-embedding-model" ]
    then
        TOOL="$d/virtuoso-export-embedding-model"
        break
    fi
done

if [ -z "$TOOL" ]
then
    CHECK "virtuoso-export-embedding-model is shipped with the plugin source" 0
    DONE_EARLY "tool not found"
fi
CHECK "virtuoso-export-embedding-model is shipped with the plugin source" 1
LOG "+ tool: $TOOL"

if ! python3 -c 'import sys' >/dev/null 2>&1
then
    LOG "SKIPPED: no python3"
    DONE_EARLY "skipped: no python3"
fi

#  ---- Part A: the pooling plan, read not guessed ---------------------------
#
#  Four fixture models.  Only the files the plan is read from are written, so a
#  fixture is a few hundred bytes and needs no weights.

FIXTURES=`pwd`/export_fixtures
rm -rf "$FIXTURES"

MKFIXTURE()
{
    #  $1 dir, $2 modules.json body, $3 1_Pooling/config.json body ('' = none)
    mkdir -p "$FIXTURES/$1"
    printf '%s\n' "$2" > "$FIXTURES/$1/modules.json"
    printf '{"hidden_size": 384, "max_position_embeddings": 512}\n' > "$FIXTURES/$1/config.json"
    if [ -n "$3" ]
    then
        mkdir -p "$FIXTURES/$1/1_Pooling"
        printf '%s\n' "$3" > "$FIXTURES/$1/1_Pooling/config.json"
    fi
}

TRANSFORMER='{"idx":0,"name":"0","path":"","type":"sentence_transformers.models.Transformer"}'
POOLING='{"idx":1,"name":"1","path":"1_Pooling","type":"sentence_transformers.models.Pooling"}'
NORMALIZE='{"idx":2,"name":"2","path":"2_Normalize","type":"sentence_transformers.models.Normalize"}'

MKFIXTURE mean_norm "[$TRANSFORMER,$POOLING,$NORMALIZE]" \
  '{"pooling_mode_cls_token":false,"pooling_mode_mean_tokens":true,"pooling_mode_max_tokens":false,"word_embedding_dimension":384}'
MKFIXTURE cls_only "[$TRANSFORMER,$POOLING]" \
  '{"pooling_mode_cls_token":true,"pooling_mode_mean_tokens":false,"pooling_mode_max_tokens":false,"word_embedding_dimension":384}'
MKFIXTURE max_only "[$TRANSFORMER,$POOLING]" \
  '{"pooling_mode_cls_token":false,"pooling_mode_mean_tokens":false,"pooling_mode_max_tokens":true,"word_embedding_dimension":384}'
mkdir -p "$FIXTURES/bare"
printf '{"hidden_size": 384, "max_position_embeddings": 512}\n' > "$FIXTURES/bare/config.json"

#  Tokenizers: a WordPiece vocabulary, a byte-level BPE one (tokenizer.json
#  says so, vocab.json and merges.txt hold it), and a SentencePiece model.
MKFIXTURE wordpiece "[$TRANSFORMER,$POOLING,$NORMALIZE]" \
  '{"pooling_mode_mean_tokens":true,"word_embedding_dimension":384}'
printf '[PAD]\n[UNK]\n[CLS]\n[SEP]\nthe\n' > "$FIXTURES/wordpiece/vocab.txt"
MKFIXTURE bpe "[$TRANSFORMER,$POOLING,$NORMALIZE]" \
  '{"pooling_mode_cls_token":true,"word_embedding_dimension":384}'
printf '{"model":{"type":"BPE","vocab":{},"merges":[]},"pre_tokenizer":{"type":"ByteLevel","add_prefix_space":false}}\n' \
    > "$FIXTURES/bpe/tokenizer.json"
printf '{"<s>": 0, "<pad>": 1, "</s>": 2, "<unk>": 3}\n' > "$FIXTURES/bpe/vocab.json"
printf '#version: 0.2\n' > "$FIXTURES/bpe/merges.txt"
MKFIXTURE spiece "[$TRANSFORMER,$POOLING]" \
  '{"pooling_mode_mean_tokens":true,"word_embedding_dimension":384}'
printf 'not really a sentencepiece model\n' > "$FIXTURES/spiece/spiece.model"

PLAN()
{
    python3 "$TOOL" "$FIXTURES/$1" /dev/null --dry-run 2>/dev/null | grep '^plan:' | head -1
}

p=`PLAN mean_norm`
CHECK "mean+normalize is read from the config (got '$p')" \
    `echo "$p" | grep -q 'pooling=mean' && echo "$p" | grep -q 'normalize=1' && echo "$p" | grep -q 'inferred=0' && echo 1 || echo 0`

p=`PLAN cls_only`
CHECK "CLS pooling is read, and no Normalize module means no normalize (got '$p')" \
    `echo "$p" | grep -q 'pooling=cls' && echo "$p" | grep -q 'normalize=0' && echo 1 || echo 0`

p=`PLAN max_only`
CHECK "max pooling is read (got '$p')" \
    `echo "$p" | grep -q 'pooling=max' && echo 1 || echo 0`

p=`PLAN bare`
CHECK "a model with no sentence-transformers config is marked inferred (got '$p')" \
    `echo "$p" | grep -q 'inferred=1' && echo 1 || echo 0`

p=`PLAN wordpiece`
CHECK "a vocab.txt is a WordPiece tokenizer (got '$p')" \
    `echo "$p" | grep -q 'tokenizer=wordpiece' && echo 1 || echo 0`
p=`PLAN bpe`
CHECK "tokenizer.json's ByteLevel BPE is a byte-level BPE tokenizer (got '$p')" \
    `echo "$p" | grep -q 'tokenizer=bpe' && echo 1 || echo 0`
p=`PLAN spiece`
CHECK "a SentencePiece model is reported as a tokenizer the helper does not have (got '$p')" \
    `echo "$p" | grep -q 'tokenizer=unsupported' && echo 1 || echo 0`

#  the two input names and the single pooled output are the contract with the
#  helper, which binds exactly two inputs
p=`PLAN mean_norm`
CHECK "the plan names the two inputs the helper binds (got '$p')" \
    `echo "$p" | grep -q 'inputs=input_ids,attention_mask' && echo 1 || echo 0`
CHECK "the plan names one pooled output (got '$p')" \
    `echo "$p" | grep -q 'output=pooled_output' && echo 1 || echo 0`

#  --dry-run must not need torch: it is the only reason this part runs at all
#  on a machine without it
NOTORCH=`pwd`/no_torch
rm -rf "$NOTORCH"; mkdir -p "$NOTORCH"
printf 'raise ImportError("torch must not be imported for --dry-run")\n' > "$NOTORCH/torch.py"
p=`PYTHONPATH="$NOTORCH" python3 "$TOOL" "$FIXTURES/mean_norm" /dev/null --dry-run 2>/dev/null | grep '^plan:' | head -1`
CHECK "--dry-run works with torch unimportable (got '$p')" \
    `echo "$p" | grep -q 'pooling=mean' && echo 1 || echo 0`

#  ---- Part B: a real export, or skip ---------------------------------------
if ! python3 -c 'import torch, transformers, onnx' >/dev/null 2>&1
then
    LOG "+ torch/transformers/onnx not importable; skipping the real export"
    DONE_EARLY "partial: no torch"
fi

#  Which model to export.
#
#  The suite sets HOME to the build tree (TESTS_ENVIRONMENT in Makefile.am), on
#  purpose, so a test cannot read the developer's home directory.  That means
#  the HuggingFace cache under a real ~/.cache is invisible here and the hub id
#  below will not resolve under `make test`.  That is the isolation working, not
#  a fault -- so this asks to be told, rather than reaching around it and
#  passing on a developer machine while skipping in CI.
#
#  To run this part:
#      VIRTUOSO_TEST_EMBED_MODEL=/path/to/granite-embedding-30m-english make test T=tvvec_onnx_export_tool
#  or point HF_HOME at a cache that has it.
MODEL=${VIRTUOSO_TEST_EMBED_MODEL-ibm-granite/granite-embedding-30m-english}

OUT=`pwd`/export_out
rm -rf "$OUT"
LOG "+ exporting $MODEL"
HF_HUB_OFFLINE=1 TRANSFORMERS_OFFLINE=1 python3 "$TOOL" \
    "$MODEL" "$OUT" > export.log 2>&1
rc=$?
if [ $rc -ne 0 ]
then
    if grep -qi "offline\|LocalEntryNotFound\|not found\|couldn't connect\|no such file" export.log
    then
        LOG "+ $MODEL is not available locally, so the real export is skipped."
        LOG "+ Set VIRTUOSO_TEST_EMBED_MODEL to a model directory to run it."
        DONE_EARLY "partial: model not available"
    fi
    LOG "***FAILED: the export failed unexpectedly; see export.log"
    sed -n '1,20p' export.log >> $LOGFILE
    FAIL=`expr $FAIL + 1`
    DONE_EARLY "export failed"
fi

CHECK "the export writes a model" `[ -f "$OUT/model.onnx" ] && echo 1 || echo 0`
CHECK "the export writes the BPE vocabulary and merges beside it" \
    `[ -f "$OUT/vocab.json" ] && [ -f "$OUT/merges.txt" ] && echo 1 || echo 0`

v=`python3 -c "
import onnx, sys
m = onnx.load('$OUT/model.onnx')
ins  = [i.name for i in m.graph.input]
outs = [o.name for o in m.graph.output]
print('%d|%s|%d|%s' % (len(ins), ','.join(ins), len(outs), ','.join(outs)))
" 2>/dev/null`
CHECK "exactly two inputs, named for the helper (got '$v')" \
    `echo "$v" | grep -q '^2|input_ids,attention_mask|' && echo 1 || echo 0`
CHECK "exactly one output, pooled (got '$v')" \
    `echo "$v" | grep -q '|1|pooled_output$' && echo 1 || echo 0`

#  The same export with --bf16-weights.  Its failure is recorded, not fatal:
#  the fp32 export above still gets its in-server assertions.
OUT16=`pwd`/export_out_bf16
rm -rf "$OUT16"
LOG "+ exporting $MODEL with --bf16-weights"
HF_HUB_OFFLINE=1 TRANSFORMERS_OFFLINE=1 python3 "$TOOL" --bf16-weights \
    "$MODEL" "$OUT16" > export_bf16.log 2>&1
rc=$?
CHECK "--bf16-weights exports a model (exit $rc)" \
    `[ $rc -eq 0 ] && [ -f "$OUT16/model.onnx" ] && echo 1 || echo 0`
[ $rc -eq 0 ] || sed -n '1,10p' export_bf16.log >> $LOGFILE

s32=`wc -c < "$OUT/model.onnx" | tr -d ' '`
s16=`wc -c < "$OUT16/model.onnx" 2>/dev/null | tr -d ' '`
half=`expr $s32 / 2 + $s32 / 100`
CHECK "--bf16-weights halves the file (${s16:-no} of $s32 bytes)" \
    `[ -n "$s16" ] && [ "$s16" -le $half ] && echo 1 || echo 0`

v=`python3 -c "
import onnx
m = onnx.load('$OUT16/model.onnx')
bf = sum(t.data_type == onnx.TensorProto.BFLOAT16 for t in m.graph.initializer)
ins  = [i.name for i in m.graph.input]
outs = [o.name for o in m.graph.output]
print('%d|%s|%s' % (bf, ','.join(ins), ','.join(outs)))
" 2>/dev/null`
CHECK "its weights are stored as bfloat16 (got '$v')" \
    `echo "$v" | grep -q '^[1-9][0-9]*|' && echo 1 || echo 0`
CHECK "it keeps the two inputs and the pooled output (got '$v')" \
    `echo "$v" | grep -q '|input_ids,attention_mask|pooled_output$' && echo 1 || echo 0`

#  ---- and it must actually work in the server ------------------------------
HOSTING="$VIRTUOSO_BUILD/binsrc/hosting"
MAKECFG_FILE $TESTCFGFILE $PORT $CFGFILE

if [ ! -f "$HOSTING/vonnx.so" ]
then
    LOG "+ vonnx not built; skipping the in-server assertions"
    DONE_EARLY "partial: vonnx not built"
fi

cp "$CFGFILE" "$CFGFILE.pre_onnx"
sed -e "s#^LoadPath[ 	]*=.*#LoadPath = $HOSTING#" "$CFGFILE.pre_onnx" > "$CFGFILE"
rm -f "$CFGFILE.pre_onnx"
printf '\n[ONNX]\nModelRoot  = %s/onnx-models\nHelperPath = %s/onnx_helper\n' \
    "$HOSTING" "$HOSTING" >> "$CFGFILE"

START_SERVER $PORT 1000

PROBE()
{
    echo "$1" | $ISQL $DSN dba dba VERBOSE=OFF PROMPT=OFF ERRORS=STDOUT 2>/dev/null \
        | grep -E '^-?[0-9.]+$' | head -1
}

ok=`PROBE "select case when exists (select 1 from DB.DBA.ONNX_MODELS where model_name = 'granite-384-local' and handle is not null) then 1 else 0 end;"`
if [ "$ok" != "1" ]
then
    LOG "+ granite-384-local not loaded; skipping the comparison"
    SHUTDOWN_SERVER
    DONE_EARLY "partial: bundled model not loaded"
fi

#  The exported model is outside ModelRoot, so make it reachable the documented
#  way rather than by weakening the path policy.  The helper reads merges.txt
#  from beside vocab.json, so the three files keep a directory of their own.
EXPORTED="$HOSTING/onnx-models/exported"
rm -rf "$EXPORTED"; mkdir -p "$EXPORTED"
cp "$OUT/model.onnx" "$OUT/vocab.json" "$OUT/merges.txt" "$EXPORTED/"

h=`PROBE "select ONNX_LOAD_MODEL ('$EXPORTED/model.onnx', 'input=input_ids;input2=attention_mask;output=pooled_output;vocab=$EXPORTED/vocab.json;max_seq_len=512');"`
CHECK "the exported model loads (handle '$h')" `[ -n "$h" ] && [ "$h" != "0" ] && echo 1 || echo 0`

v=`PROBE "select length (ONNX_EMBED_TEXT ($h, 'the quick brown fox'));"`
CHECK "it embeds to the model's width (got '$v')" `[ "$v" = "384" ] && echo 1 || echo 0`

#  The decisive one: the bundled model was exported from this very source with
#  CLS pooling + L2, so reproducing it is what proves the tool right.
cat > cmp.sql <<'SQL'
CREATE PROCEDURE tvvec_exp_cos (IN ha INT, IN hb INT, IN t VARCHAR)
{
  DECLARE u, v ANY;
  DECLARE i INT;
  DECLARE d, na, nb, x, y DOUBLE PRECISION;
  u := ONNX_EMBED_TEXT (ha, t);
  v := ONNX_EMBED_TEXT (hb, t);
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

--  How many components of two models' vectors for a text differ at all;
--  -1 when either fails to embed it.
CREATE PROCEDURE tvvec_exp_ndiff (IN ha INT, IN hb INT, IN t VARCHAR)
{
  DECLARE u, v ANY;
  DECLARE i, n INT;
  DECLARE exit handler for sqlstate '*' { RETURN -1; };
  u := ONNX_EMBED_TEXT (ha, t);
  v := ONNX_EMBED_TEXT (hb, t);
  IF (length (u) = 0 OR length (u) <> length (v))
    RETURN -1;
  n := 0;
  FOR (i := 0; i < length (u); i := i + 1)
    {
      IF (aref (u, i) <> aref (v, i))
        n := n + 1;
    }
  RETURN n;
}
;
SQL
$ISQL $DSN dba dba < cmp.sql > /dev/null 2>&1

hb=`PROBE "select handle from DB.DBA.ONNX_MODELS where model_name = 'granite-384-local';"`
for t in "the quick brown fox" "Virtuoso is a multi-model database" "cafe"
do
    d=`PROBE "select sprintf ('%.6f', tvvec_exp_cos ($h, $hb, '$t'));"`
    CHECK "the export reproduces the bundled model on '$t' (distance '$d')" \
        `awk -v x="$d" 'BEGIN { if (x < 0) x = -x; exit !(x < 0.0001) }' && echo 1 || echo 0`
done

#  The bf16 export carries Casts that ONNX Runtime folds into the same fp32
#  weights at load, so its vectors must equal the fp32 export's exactly.
EXPORTED16="$HOSTING/onnx-models/exported_bf16"
rm -rf "$EXPORTED16"; mkdir -p "$EXPORTED16"
cp "$OUT16/model.onnx" "$OUT16/vocab.json" "$OUT16/merges.txt" "$EXPORTED16/" 2>/dev/null
h16=`PROBE "select ONNX_LOAD_MODEL ('$EXPORTED16/model.onnx', 'input=input_ids;input2=attention_mask;output=pooled_output;vocab=$EXPORTED16/vocab.json;max_seq_len=512');"`
CHECK "the bf16 export loads (handle '$h16')" `[ -n "$h16" ] && [ "$h16" != "0" ] && echo 1 || echo 0`
for t in "the quick brown fox" "Virtuoso is a multi-model database" "cafe" \
    "Interest rates rose again this quarter, pushing bond yields higher and putting pressure on growth stocks across most major indices."
do
    n=`PROBE "select tvvec_exp_ndiff ($h, ${h16:-0}, '$t');"`
    CHECK "the bf16 export gives the fp32 export's vector exactly on '$t' (components differing: '$n')" \
        `[ "$n" = "0" ] && echo 1 || echo 0`
done

SHUTDOWN_SERVER
rm -rf "$EXPORTED" "$EXPORTED16"

LOG "+ ONNX export tool: $PASS passed, $FAIL failed"
CHECK_LOG

if [ "$FAIL" != "0" ]
then
    BANNER "COMPLETED ONNX embedding export tool test -- FAILURES PRESENT"
    exit 1
fi

BANNER "COMPLETED ONNX embedding export tool test"
exit 0
