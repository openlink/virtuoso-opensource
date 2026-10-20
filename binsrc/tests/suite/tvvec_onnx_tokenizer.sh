#!/bin/sh
#
#  tvvec_onnx_tokenizer.sh
#
#  Text normalisation in the ONNX helper's WordPiece tokenizer, which is what
#  a BERT-family model registered with a vocab.txt sees of every row and every
#  query of a vector index.
#
#  BERT's own tokenizer, with do_lower_case=True, lowercases AND strips accents
#  (NFD, then drop combining marks).  So it maps cafe, CAFE, café and CAFÉ to
#  one token id, and a model trained that way expects nothing else.  This suite
#  asserts that the helper agrees with Hugging Face's BertTokenizerFast, id for
#  id, on the texts of tvvec_onnx_wordpiece_texts.txt, with a vocabulary of the
#  suite's own in BERT's layout ([PAD] 0, [UNK] 100, [CLS] 101, [SEP] 102):
#  tvvec_onnx_wordpiece_vocab.txt.  The expected ids,
#  tvvec_onnx_wordpiece_ids.txt, come from Hugging Face with that vocabulary
#  (gen_wordpiece_fixtures.py).  Then, for each fold that matters, that the two
#  spellings which must meet do tokenize the same.
#
#  It used to assert the folds as embedding distances through the bundled
#  all-MiniLM-L6-v2, because no BIF shows token ids.  `onnx_helper --tokenize`
#  shows them, and the bundled model is now granite, whose tokenizer is
#  byte-level BPE and cased (tvvec_onnx_bpe).
#
#  Only what the tokenizer is meant to do is here.  Its known gaps -- CJK
#  characters as words of their own, among others -- are documented with the
#  embedding models.
#
#  The ONNX plugin is off by default (--enable-onnxruntime), so like the other
#  ONNX-backed suites this SKIPS (never fails) when the helper is not built.
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

LOGFILE=`pwd`/tvvec_onnx_tokenizer.output
export LOGFILE
. $VIRTUOSO_TEST/testlib.sh

rm -f $LOGFILE

BANNER "STARTED ONNX tokenizer normalisation test"

if [ "$CURRENT_VIRTUOSO_CAPACITY" != "single" ]
then
    LOG "SKIPPED: single-server only"
    BANNER "COMPLETED ONNX tokenizer test (skipped: not single-server)"
    exit 0
fi

HOSTING="$VIRTUOSO_BUILD/binsrc/hosting"
VOCAB="$VIRTUOSO_TEST/tvvec_onnx_wordpiece_vocab.txt"
TEXTS="$VIRTUOSO_TEST/tvvec_onnx_wordpiece_texts.txt"
IDS="$VIRTUOSO_TEST/tvvec_onnx_wordpiece_ids.txt"
NTEXTS=`wc -l < "$TEXTS" | tr -d ' '`
GOT=tvvec_onnx_wordpiece_tokens.out

PASS=0
FAIL=0
CHECK()
{
    if [ "$2" = "1" ]; then PASS=`expr $PASS + 1`; LOG "PASSED: $1"
    else FAIL=`expr $FAIL + 1`; LOG "***FAILED: $1"; fi
}

if [ ! -x "$HOSTING/onnx_helper" ]
then
    LOG "SKIPPED: the ONNX helper is not built"
    BANNER "COMPLETED ONNX tokenizer test (skipped: vonnx not built)"
    exit 0
fi

#  --- every text, id for id --------------------------------------------------
"$HOSTING/onnx_helper" --vocab "$VOCAB" --max-seq-len 128 --tokenize \
    < "$TEXTS" > $GOT 2>tvvec_onnx_wordpiece_tokens.err
same=`awk 'NR == FNR { want[FNR] = $0; next } { if ($0 == want[FNR]) n++ } END { print n + 0 }' "$IDS" $GOT`
CHECK "the helper tokenizes $same of $NTEXTS texts as Hugging Face does" \
    `[ "$same" = "$NTEXTS" ] && echo 1 || echo 0`
awk 'NR == FNR { want[FNR] = $0; next } $0 != want[FNR] { print "+ first differing text, line " FNR ": want [" want[FNR] "] got [" $0 "]"; exit }' \
    "$IDS" $GOT >> $LOGFILE
if [ ! -s $GOT ]
then
    LOG "+ the helper printed no tokens: `head -1 tvvec_onnx_wordpiece_tokens.err`"
fi

#  SAME "<description>" <line> <line>  -- the two texts tokenize the same.
#  Line numbers are those of tvvec_onnx_wordpiece_texts.txt.
SAME()
{
    a=`sed -n "${2}p" $GOT`
    b=`sed -n "${3}p" $GOT`
    CHECK "$1 (lines $2 and $3: '$a' and '$b')" `[ -n "$a" ] && [ "$a" = "$b" ] && echo 1 || echo 0`
}

#  --- control: ASCII case folding already works and must not regress --------
SAME "ASCII case folds" 1 2

#  --- accents: BERT strips them, so these are the same token ---------------
SAME "a precomposed accent is stripped" 1 3
SAME "accents are stripped with case" 2 4
SAME "several accents in a word" 5 6
SAME "diaeresis is stripped" 7 8
SAME "accents across several words" 9 10

#  --- ranges beyond Latin-1 ------------------------------------------------
SAME "Vietnamese accents are stripped" 11 12
SAME "Vietnamese, one word" 13 14
SAME "Cyrillic case folds" 15 16
SAME "Greek case folds" 17 18

#  --- already-decomposed input normalises the same way ---------------------
#  line 19 is 'cafe' + U+0301 COMBINING ACUTE ACCENT
SAME "a combining mark is dropped" 3 19

#  --- and nothing may collapse to [UNK] ------------------------------------
#  A fix that mapped everything to the unknown token would satisfy every
#  assertion above, so assert that unrelated words stay apart and that an
#  accented word is not [UNK] (100).
a=`sed -n 1p $GOT`
b=`sed -n 20p $GOT`
CHECK "unrelated words stay apart (cafe '$a', tea '$b')" `[ -n "$a" ] && [ "$a" != "$b" ] && echo 1 || echo 0`
v=`sed -n 6p $GOT`
CHECK "an accented word keeps its tokens (résumé '$v')" \
    `[ -n "$v" ] && ! echo " $v " | grep -q ' 100 ' && echo 1 || echo 0`

LOG "+ ONNX tokenizer: $PASS passed, $FAIL failed"
CHECK_LOG

if [ "$FAIL" != "0" ]
then
    BANNER "COMPLETED ONNX tokenizer test -- FAILURES PRESENT"
    exit 1
fi

BANNER "COMPLETED ONNX tokenizer test"
exit 0
