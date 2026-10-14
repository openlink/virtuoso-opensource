# granite-embedding-30m-english

This directory contains an ONNX export of IBM's
[granite-embedding-30m-english](https://huggingface.co/ibm-granite/granite-embedding-30m-english)
sentence-embedding model, the default model of the vector-index feature.

`model.onnx` (about 60 MB) is too large to keep in git. The build downloads
it from the OpenLink Nexus server, together with any other file listed in
`SHA256SUMS` that is missing or fails its checksum (see
[Integrity](#integrity)). An installed server ships all the files.

## Model Information

- **Model**: granite-embedding-30m-english, revision r1.1 (Hugging Face commit
  `9b5b096411652ec1189c68fcfb90d0a82c5b45af`)
- **Developers**: Granite Embedding Team, IBM
  ([technical report](https://arxiv.org/abs/2502.20204))
- **License**: Apache 2.0 (see `LICENSE`)
- **Architecture**: RoBERTa encoder, 6 layers, hidden size 384, 12 attention
  heads, 30M parameters
- **Output Dimensions**: 384 (L2-normalized — dot product == cosine similarity)
- **Pooling**: the `<s>` (CLS) token, then L2 normalization, baked into the graph
- **Tokenizer**: byte-level BPE (RoBERTa), cased, 50,265 tokens and 50,000 merges;
  `<s>` 0, `<pad>` 1, `</s>` 2, `<unk>` 3, `<mask>` 50264
- **Max Sequence Length**: 512 tokens

### Training data

From the model card: the training data consists of "(1) unsupervised title-body
paired data scraped from the web, (2) publicly available paired with permissive,
enterprise-friendly license, (3) IBM-internal paired data targeting specific
technical domains, and (4) IBM-generated synthetic data", and "we do not use the
popular MS-MARCO retrieval dataset in our training corpus due to its
non-commercial license".

## Provenance

### Verified from the artifact

| Property | Value |
|---|---|
| SHA-256 (`model.onnx`) | `a07c196ffe53ab19a8b68280a9d80b2ab2ba98924e48e5f102b4558b738cfc58` |
| SHA-256 (`vocab.json`) | `ed19656ea1707df69134c4af35c8ceda2cc9860bf2c3495026153a133670ab5e` |
| SHA-256 (`merges.txt`) | `fe36cab26d4f4421ed725e10a2e9ddb7f799449c603a96e7f29b5a3c82a95862` |
| Size | 60,458,629 bytes (weights stored as bf16, the precision IBM publishes them in; widened to fp32 when the model loads) |
| Producer | `pytorch` 2.6.0 |
| ONNX IR version | 8 |
| Opset | `ai.onnx` v17 |
| Graph inputs | `input_ids`, `attention_mask` |
| Graph outputs | `pooled_output` (CLS + L2-normalized sentence embedding) |

`vocab.json` and `merges.txt` are the published files, byte for byte.

### How it was made

With the export tool that ships with the ONNX plugin:

```sh
virtuoso-export-embedding-model --bf16-weights \
    ibm-granite/granite-embedding-30m-english <outdir>
```

The tool is installed in Virtuoso's `bin` directory. In the source tree it is
`binsrc/hosting/onnx/virtuoso-export-embedding-model`.

The tool reads the pipeline from the model's own sentence-transformers
configuration (`modules.json`: Transformer, CLS Pooling, Normalize), exports a
graph that takes `input_ids` and `attention_mask`, and copies the byte-level BPE
vocabulary and merges beside it (transformers 4.57.3, torch 2.6.0).

`--bf16-weights` then stores 44 of the graph's 101 weights — 30,125,184 of
its 30,147,456 values — as bfloat16, each behind a `Cast` back to float that
ONNX Runtime folds when it loads the model. The weights are published in
bf16, so the low 16 bits of every fp32 value in the export are zero and the
conversion loses nothing; the smaller weights it leaves alone are under 1,024
values each. Without the option the same command writes the fp32 export,
120,704,249 bytes, SHA-256 `614ce305…`.

### Verified against the reference

- The tool's own check, the exported graph against the source model on the same
  tokens: **max abs difference 7.2e-07**.
- Against a float64 run of the source model: 7.5e-08 to 9.6e-08.
- The bf16-stored weights against the fp32 export, through the server's ONNX
  helper (ONNX Runtime 1.25) on 4,000 FiQA passages: **1,536,000 vector
  components, none different**. The tool checks the same on its own texts
  before it keeps the bf16 file.
- sentence-transformers strips leading and trailing whitespace from every text
  before tokenizing it; the helper does the same, since for byte-level BPE a
  trailing space is a token of its own.

## Integrity

`SHA256SUMS` holds the checksums, verified automatically when the ONNX plugin is
built (`binsrc/hosting/onnx/Makefile.am`, target `verify-onnx-model`). The
build runs `binsrc/hosting/onnx/fetch-onnx-model`, which downloads any file
that is missing or fails its checksum from
<https://nexus.openlinksw.com/repository/onnx-models/granite-embedding-30m-english/>
and checks it before putting it in place. A file that still fails the check
fails the build. A directory that already holds good copies is only verified,
so an offline build works once `model.onnx` has been copied in by hand.

This is a correctness control, not packaging hygiene: a truncated or
interrupted download, or a substituted model, does not crash anything at
runtime — it produces confident, wrong vectors.

```bash
cd binsrc/hosting/onnx/onnx-models/granite-embedding-30m-english
shasum -a 256 -c SHA256SUMS     # macOS/BSD
sha256sum -c SHA256SUMS         # GNU coreutils
```

The same check without downloading anything:

```bash
binsrc/hosting/onnx/fetch-onnx-model --verify-only \
    --dir binsrc/hosting/onnx/onnx-models/granite-embedding-30m-english
```

If the model is ever deliberately replaced, update `SHA256SUMS` and this
provenance section **in the same commit**.

## Files

- `model.onnx` — ONNX model (CLS pooling + L2 normalization baked in; weights stored as bf16); not in git, downloaded by the build
- `vocab.json` — byte-level BPE vocabulary (50,265 tokens)
- `merges.txt` — BPE merges (50,000); the helper reads it from beside `vocab.json`
- `SHA256SUMS` — checksums, verified at build time
- `LICENSE` — Apache 2.0

## Usage with the Virtuoso ONNX Plugin

Give **absolute** paths. Inference runs in forked helper processes that inherit
the server's working directory — the database directory, not the build tree — so
a relative path yields a helper that cannot open the model.

```sql
SELECT ONNX_LOAD_MODEL (
  DB.DBA.ONNX_RESOLVE_PATH ('granite-embedding-30m-english/model.onnx', 'GraniteModelPath'),
  'input=input_ids;input2=attention_mask;output=pooled_output;vocab='
    || DB.DBA.ONNX_RESOLVE_PATH ('granite-embedding-30m-english/vocab.json', 'GraniteVocabPath')
    || ';max_seq_len=512'
);

SELECT ONNX_EMBED_TEXT (handle, 'Your text here');
```

The bundled model is registered automatically at bootstrap as `granite-384-local`
(`output_name = 'pooled_output'`, `max_seq_len = 512`); see
`DB.DBA.ONNX_REGISTER_DEFAULT_MODELS`. `[ONNX] GraniteModelPath` and
`GraniteVocabPath` in `virtuoso.ini` say where its files are when they are not
under `ModelRoot`.

Scores are on the model's own scale. On the quickstart's rows, related text
scores 0.86–0.89 with `X_SIMILAR` and unrelated text about 0.73, where
all-MiniLM-L6-v2 gave 0.68–0.73 and 0.50: a threshold set for one model means
nothing for the other.
