#!/bin/sh
#
#  tvvec_onnx_bpe.sh
#
#  The bundled embedding model is IBM's granite-embedding-30m-english: a
#  RoBERTa encoder with a byte-level BPE tokenizer, cased, pad id 1, CLS
#  pooling, 512 tokens.  The helper has to tokenize exactly as Hugging Face's
#  tokenizer does -- after sentence-transformers' strip of leading and trailing
#  whitespace -- or every vector drifts from the model's own.
#
#  1. `onnx_helper --tokenize` gives the fixture texts the token ids Hugging
#     Face gives them (tvvec_onnx_bpe_ids.txt, from gen_fixtures.py): case,
#     contractions, digits, whitespace runs, Unicode letters and numbers,
#     emoji, combining marks, the special tokens written into a text, and
#     truncation at 512.
#  2. ONNX_EMBED_BATCH of the same texts matches sentence-transformers'
#     embeddings (the first 16 components, tvvec_onnx_bpe_vecs.txt) to 1e-5.
#     The model's weights are stored as bf16, the precision IBM publishes them
#     in (the export tool's --bf16-weights); this is what shows no vector
#     changed.
#  3. A text embeds the same alone as in a mixed request.
#  4. The bootstrap registers granite-384-local and loads it.
#  5. ONNX_SUMMARIZE, with its default model, works (a guard).
#  6. A vector index built with granite-384-local finds the right document.
#  7. The quickstart's pair scores as the documentation says with the default
#     model: X_SIMILAR ('how to install', 'How do I install virtuoso on
#     Windows?') is 0.8752 (1 - cosine distance / 2; sentence-transformers
#     gives 0.8752, all-MiniLM-L6-v2 gave 0.7246), and a text is at distance 0
#     from itself.
#
#  Skips when vonnx.so is not built.  With the plugin built, the bundled model
#  is expected: its absence is a failure, not a skip.
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

LOGFILE=`pwd`/tvvec_onnx_bpe.output
export LOGFILE
. $VIRTUOSO_TEST/testlib.sh

rm -f $LOGFILE

BANNER "STARTED ONNX byte-level BPE tokenizer and granite model test"

if [ "$CURRENT_VIRTUOSO_CAPACITY" != "single" ]
then
    LOG "SKIPPED: single-server only"
    BANNER "COMPLETED ONNX BPE test (skipped: not single-server)"
    exit 0
fi

HOSTING="$VIRTUOSO_BUILD/binsrc/hosting"
GRANITE="$HOSTING/onnx-models/granite-embedding-30m-english"
TEXTS="$VIRTUOSO_TEST/tvvec_onnx_bpe_texts.txt"
IDS="$VIRTUOSO_TEST/tvvec_onnx_bpe_ids.txt"
VECS="$VIRTUOSO_TEST/tvvec_onnx_bpe_vecs.txt"
NTEXTS=`wc -l < "$TEXTS" | tr -d ' '`

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

if [ ! -f "$HOSTING/vonnx.so" ]
then
    LOG "SKIPPED: vonnx plugin not built"
    BANNER "COMPLETED ONNX BPE test (skipped: vonnx not built)"
    exit 0
fi

for f in model.onnx vocab.json merges.txt LICENSE
do
    CHECK "the bundled granite model has $f" `[ -f "$GRANITE/$f" ] && echo 1 || echo 0`
done

#  --- 1. token ids ------------------------------------------------------------
"$HOSTING/onnx_helper" --vocab "$GRANITE/vocab.json" --max-seq-len 512 --tokenize \
    < "$TEXTS" > tvvec_onnx_bpe_tokens.out 2>tvvec_onnx_bpe_tokens.err
same=`awk 'NR == FNR { want[FNR] = $0; next } { if ($0 == want[FNR]) n++ } END { print n + 0 }' "$IDS" tvvec_onnx_bpe_tokens.out`
CHECK "the helper tokenizes $same of $NTEXTS fixture texts as Hugging Face does" \
    `[ "$same" = "$NTEXTS" ] && echo 1 || echo 0`
awk 'NR == FNR { want[FNR] = $0; next } $0 != want[FNR] { print "+ first differing text, line " FNR ": want [" want[FNR] "] got [" $0 "]"; exit }' \
    "$IDS" tvvec_onnx_bpe_tokens.out >> $LOGFILE
if [ ! -s tvvec_onnx_bpe_tokens.out ]
then
    LOG "+ the helper printed no tokens: `head -1 tvvec_onnx_bpe_tokens.err`"
fi

MAKECFG_FILE $TESTCFGFILE $PORT $CFGFILE
cp "$CFGFILE" "$CFGFILE.pre_onnx"
sed -e "s#^LoadPath[ 	]*=.*#LoadPath = $HOSTING#" "$CFGFILE.pre_onnx" > "$CFGFILE"
rm -f "$CFGFILE.pre_onnx"
printf '\n[ONNX]\nModelRoot  = %s/onnx-models\nHelperPath = %s/onnx_helper\n' \
    "$HOSTING" "$HOSTING" >> "$CFGFILE"

START_SERVER $PORT 1000

$ISQL $DSN dba dba VERBOSE=OFF PROMPT=OFF ERRORS=STDOUT >/dev/null 2>&1 <<SQL
select ONNX_CONFIG ('max_batch', 64);

--  The fixture texts, one a line; the file ends with a newline.
CREATE PROCEDURE tvbpe_texts () RETURNS ANY
{
  DECLARE parts ANY;
  parts := split_and_decode (file_to_string ('$TEXTS'), 0, '\0\0\n');
  RETURN subseq (parts, 0, $NTEXTS);
}
;

CREATE PROCEDURE tvbpe_load () RETURNS INT
{
  RETURN ONNX_LOAD_MODEL ('$GRANITE/model.onnx',
      'input=input_ids;input2=attention_mask;output=pooled_output;vocab=$GRANITE/vocab.json;max_seq_len=512');
}
;

--  The largest difference between the first 16 components of each embedding
--  and the sentence-transformers reference; -1 when anything fails.
CREATE PROCEDURE tvbpe_vs_reference () RETURNS DOUBLE PRECISION
{
  DECLARE h, i, j INT;
  DECLARE texts, got, lines, want ANY;
  DECLARE worst, d DOUBLE PRECISION;
  DECLARE exit handler for sqlstate '*' { RETURN -1; };
  h := tvbpe_load ();
  texts := tvbpe_texts ();
  got := ONNX_EMBED_BATCH (h, texts);
  lines := split_and_decode (file_to_string ('$VECS'), 0, '\0\0\n');
  worst := 0;
  FOR (i := 0; i < length (texts); i := i + 1)
    {
      want := split_and_decode (lines[i], 0, '\0\0 ');
      FOR (j := 0; j < 16; j := j + 1)
        {
          d := abs (cast (aref (got[i], j) AS DOUBLE PRECISION) - cast (want[j] AS DOUBLE PRECISION));
          IF (d > worst)
            worst := d;
        }
    }
  RETURN worst;
}
;

--  The largest difference between a text embedded alone and in the request.
CREATE PROCEDURE tvbpe_alone_vs_batch () RETURNS DOUBLE PRECISION
{
  DECLARE h, i, j INT;
  DECLARE texts, batch, one ANY;
  DECLARE worst, d DOUBLE PRECISION;
  DECLARE exit handler for sqlstate '*' { RETURN -1; };
  h := tvbpe_load ();
  texts := tvbpe_texts ();
  batch := ONNX_EMBED_BATCH (h, texts);
  worst := 0;
  FOR (i := 0; i < length (texts); i := i + 1)
    {
      one := ONNX_EMBED_TEXT (h, texts[i]);
      FOR (j := 0; j < length (one); j := j + 1)
        {
          d := abs (cast (aref (one, j) AS DOUBLE PRECISION) - cast (aref (batch[i], j) AS DOUBLE PRECISION));
          IF (d > worst)
            worst := d;
        }
    }
  RETURN worst;
}
;

CREATE PROCEDURE tvbpe_summary () RETURNS INT
{
  DECLARE s VARCHAR;
  DECLARE exit handler for sqlstate '*' { RETURN 0; };
  s := DB.DBA.ONNX_SUMMARIZE ('Cats are small domesticated felines. The stock market fell sharply today. Kittens are young cats that like to play.', 1);
  RETURN case when s is not null and length (s) > 0 then 1 else 0 end;
}
;

--  1 - cosine distance / 2 between two texts under the default model, as
--  X_SIMILAR scores them; -1 when the model is not loaded.
CREATE PROCEDURE tvbpe_similar (IN a VARCHAR, IN b VARCHAR) RETURNS DOUBLE PRECISION
{
  DECLARE h, i INT;
  DECLARE u, v ANY;
  DECLARE d, na, nb, x, y DOUBLE PRECISION;
  DECLARE exit handler for sqlstate '*' { RETURN -1; };
  h := (SELECT handle FROM DB.DBA.ONNX_MODELS WHERE model_name = 'granite-384-local');
  IF (h IS NULL)
    RETURN -1;
  u := ONNX_EMBED_TEXT (h, a);
  v := ONNX_EMBED_TEXT (h, b);
  d := 0; na := 0; nb := 0;
  FOR (i := 0; i < length (u); i := i + 1)
    {
      x := cast (aref (u, i) AS DOUBLE PRECISION);
      y := cast (aref (v, i) AS DOUBLE PRECISION);
      d := d + x * y; na := na + x * x; nb := nb + y * y;
    }
  RETURN 1 - (1 - d / (sqrt (na) * sqrt (nb))) / 2;
}
;

--  The rank (1-based) of the expected document for a query, 0 if absent,
--  -1 when the index cannot be built or searched.
CREATE PROCEDURE tvbpe_index_rank () RETURNS INT
{
  DECLARE st, msg VARCHAR;
  DECLARE md, rs ANY;
  DECLARE i INT;
  DECLARE exit handler for sqlstate '*' { RETURN -1; };
  DB.DBA.RDF_QUAD_URI_L ('urn:tvbpe:g', 'urn:tvbpe:cat', 'urn:tvbpe:text', 'A cat is a small domesticated feline that purrs and hunts mice.');
  DB.DBA.RDF_QUAD_URI_L ('urn:tvbpe:g', 'urn:tvbpe:stock', 'urn:tvbpe:text', 'The stock market fell sharply after the central bank raised interest rates.');
  DB.DBA.RDF_QUAD_URI_L ('urn:tvbpe:g', 'urn:tvbpe:rain', 'urn:tvbpe:text', 'Heavy rain and strong winds are expected along the coast tonight.');
  DB.DBA.RDF_QUAD_URI_L ('urn:tvbpe:g', 'urn:tvbpe:pasta', 'urn:tvbpe:text', 'Boil the pasta in salted water and serve it with a tomato sauce.');
  DB.DBA.RDF_QUAD_URI_L ('urn:tvbpe:g', 'urn:tvbpe:code', 'urn:tvbpe:text', 'The compiler reported a syntax error on line forty-two of the program.');
  commit work;
  st := '00000';
  exec ('sparql define input:storage "" create vector index <urn:tvbpe:idx> on graph <urn:tvbpe:g> for predicate <urn:tvbpe:text> using model ''granite-384-local'' with (dimensions = 384, distance = ''cosine'', maintenance = ''manual'')',
        st, msg, vector (), 0, md, rs);
  IF (st <> '00000')
    RETURN -1;
  DB.DBA.VEC_INDEX_REFRESH ('urn:tvbpe:idx');
  st := '00000';
  exec ('sparql define input:storage "" select ?doc where { ?doc bif:vector_search "a pet feline that catches mice" option (index <urn:tvbpe:idx>, score ?sc, limit 5) } order by desc(?sc)',
        st, msg, vector (), 0, md, rs);
  IF (st <> '00000')
    RETURN -1;
  FOR (i := 0; i < length (rs); i := i + 1)
    IF (case when isiri_id (rs[i][0]) then id_to_iri (rs[i][0]) else cast (rs[i][0] AS VARCHAR) end = 'urn:tvbpe:cat')
      RETURN i + 1;
  RETURN 0;
}
;
SQL

#  --- 2. embeddings -------------------------------------------------------------
v=`PROBE "select sprintf ('%.9f', tvbpe_vs_reference ());"`
CHECK "ONNX_EMBED_BATCH matches sentence-transformers on the fixture texts (worst '$v', must be < 0.00001)" \
    `awk -v d="$v" 'BEGIN { if (d == "") exit 1; exit !(d >= 0 && d < 0.00001) }' && echo 1 || echo 0`

#  --- 3. alone vs in a request --------------------------------------------------
v=`PROBE "select sprintf ('%.9f', tvbpe_alone_vs_batch ());"`
CHECK "a text embeds as it does alone in a mixed request (worst '$v', must be < 0.000001)" \
    `awk -v d="$v" 'BEGIN { if (d == "") exit 1; exit !(d >= 0 && d < 0.000001) }' && echo 1 || echo 0`

#  --- 4. the bootstrap registration ------------------------------------------------
v=`PROBE "select count (*) from DB.DBA.ONNX_MODELS where model_name = 'granite-384-local' and model_type = 'text_embedding' and handle is not null and output_shape = '1,384' and vocab_path like '%vocab.json' and max_seq_len = 512;"`
CHECK "the bootstrap registers and loads granite-384-local (got '$v')" `[ "$v" = "1" ] && echo 1 || echo 0`

#  --- 5. ONNX_SUMMARIZE's default model -------------------------------------------
v=`PROBE "select tvbpe_summary ();"`
CHECK "ONNX_SUMMARIZE works with its default model (got '$v')" `[ "$v" = "1" ] && echo 1 || echo 0`

#  --- 6. a vector index with the default model ------------------------------------
v=`PROBE "select tvbpe_index_rank ();"`
CHECK "a granite-384-local vector index ranks the right document first (rank '$v')" `[ "$v" = "1" ] && echo 1 || echo 0`

#  --- 7. the quickstart's numbers -------------------------------------------------
v=`PROBE "select sprintf ('%.4f', tvbpe_similar ('how to install', 'How do I install virtuoso on Windows?'));"`
CHECK "the quickstart pair scores 0.8752 with the default model (got '$v')" `[ "$v" = "0.8752" ] && echo 1 || echo 0`
v=`PROBE "select sprintf ('%.6f', tvbpe_similar ('how to install', 'how to install'));"`
CHECK "a text scores 1 against itself (got '$v')" `[ "$v" = "1.000000" ] && echo 1 || echo 0`

SHUTDOWN_SERVER

LOG "+ ONNX byte-level BPE: $PASS passed, $FAIL failed"
CHECK_LOG

if [ "$FAIL" != "0" ]
then
    BANNER "COMPLETED ONNX BPE test -- FAILURES PRESENT"
    exit 1
fi

BANNER "COMPLETED ONNX BPE test"
exit 0
