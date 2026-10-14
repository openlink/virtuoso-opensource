/*
 *  onnx_helper.c
 *
 *  $Id$
 *
 *  ONNX Runtime helper process for out-of-process embedding inference.
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2026 OpenLink Software
 *
 *  This project is free software; you can redistribute it and/or modify it
 *  under the terms of the GNU General Public License as published by the
 *  Free Software Foundation; only version 2 of the License, dated June 1991.
 *
 *  This program is distributed in the hope that it will be useful, but
 *  WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
 *  General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License along
 *  with this program; if not, write to the Free Software Foundation, Inc.,
 *  51 Franklin St, Fifth Floor, Boston, MA 02110-1301 USA
 *
 */
/*
 * ONNX helper process for Virtuoso OUTPROC inference.
 * Binary IPC protocol, length-prefixed, supports batching and telemetry.
 */

#include <onnxruntime_c_api.h>

#include <errno.h>
#include <stdarg.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <limits.h>
#include <math.h>
#include <time.h>
#include <signal.h>
#ifndef _WIN32
#include <unistd.h>
#else
#include <windows.h>
#include <io.h>
#endif

#define HELPER_MAX_INPUT (512 * 1024)
/* Texts per request are a runtime limit, --max-texts, under this ceiling; a
   whole request is also bounded in bytes.  Bounds match onnx_plugin.c. */
#define HELPER_MAX_TEXTS_CEILING 16384
#define HELPER_MAX_REQUEST_BYTES (512 * 1024 * 1024)
#define HELPER_TOKENS_PER_BATCH_MIN 16
#define HELPER_TOKENS_PER_BATCH_MAX 1048576
/* The plugin's ONNX_MAX_SEQ_LEN_MIN/_MAX: a row holds at least <s> and </s>. */
#define HELPER_MAX_SEQ_LEN_MIN 2
#define HELPER_MAX_SEQ_LEN_MAX 8192
#define HELPER_MAX_OUTPUT_FLOATS 16384
#define HELPER_MAX_TENSOR_BYTES (32 * 1024 * 1024)

#define ONNX_IPC_MAGIC 0x584E4E4F /* 'ONNX' */
/* Must match ONNX_MAX_TENSOR_RANK in onnx_plugin.c.  NOT the arrays in the
   GLiNER2 encoder readers below, which are about [batch, seq, hidden]. */
#define ONNX_MAX_TENSOR_RANK 8
/* Generic run: N named inputs with their own element types, M named outputs.
   Has its own request parse AND its own response writer, because the response
   format of the older ops is shared with EMBED -- the vector index's path --
   and carries no element type. */
#define ONNX_IPC_OP_RUN_MULTI 5
#define HELPER_MAX_TENSORS 16
#define ONNX_IPC_VERSION 1
#define ONNX_IPC_FLAG_TELEMETRY 0x0001
/* Set by the helper on a telemetry response that also carries token counts:
   real tokens, padded tokens and sub-batches, after the two timings. */
#define ONNX_IPC_FLAG_TOKENS 0x0002
#define ONNX_IPC_OP_EMBED 1
#define ONNX_IPC_OP_RUN_F32 2
#define ONNX_IPC_OP_RUN_I64_2 3
#define ONNX_IPC_OP_GLINER2 4

#define GLINER2_SUB_EXTRACT 1
#define GLINER2_SUB_CLASSIFY 2
#define GLINER2_SUB_EXTRACT_JSON 3
#define GLINER2_SUB_RELATIONS 4
#define GLINER2_SUB_COMBINED 5

#define GLINER2_MAX_SEQ 512
#define GLINER2_MAX_LABELS 64
#define GLINER2_MAX_TEXT_TOKENS 256
#define GLINER2_MAX_WIDTH 8
#define GLINER2_MAX_JSON (256 * 1024)

typedef struct
{
  uint32_t magic;
  uint16_t version;
  uint16_t flags;
  uint32_t batch_count;
  uint32_t payload_len;
  uint32_t status;
} ipc_hdr_t;

static void
fail (const char *fmt, ...)
{
  va_list ap;
  va_start (ap, fmt);
  vfprintf (stderr, fmt, ap);
  fprintf (stderr, "\n");
  va_end (ap);
  exit (1);
}

static uint64_t
mono_ns (void)
{
#ifdef _WIN32
  LARGE_INTEGER freq, counter;
  QueryPerformanceFrequency (&freq);
  QueryPerformanceCounter (&counter);
  return (uint64_t) ((counter.QuadPart * 1000000000ULL) / freq.QuadPart);
#else
  struct timespec ts;
  if (clock_gettime (CLOCK_MONOTONIC, &ts) != 0)
    return 0;
  return (uint64_t) ts.tv_sec * 1000000000ULL + (uint64_t) ts.tv_nsec;
#endif
}

static int
read_exact (void *buf, size_t len)
{
  size_t got = 0;
  while (got < len)
    {
#ifdef _WIN32
      int n = _read (0, (char *) buf + got, (unsigned int) (len - got));
#else
      ssize_t n = read (0, (char *) buf + got, len - got);
#endif
      if (n <= 0)
	return -1;
      got += (size_t) n;
    }
  return 0;
}

static int
write_exact (const void *buf, size_t len)
{
  size_t sent = 0;
  while (sent < len)
    {
#ifdef _WIN32
      int n = _write (1, (const char *) buf + sent, (unsigned int) (len - sent));
#else
      ssize_t n = write (1, (const char *) buf + sent, len - sent);
#endif
      if (n <= 0)
	return -1;
      sent += (size_t) n;
    }
  return 0;
}

static void
check_status (const OrtApi *api, OrtStatus *st, const char *ctx)
{
  if (st)
    {
      const char *msg = api->GetErrorMessage (st);
      api->ReleaseStatus (st);
      fail ("%s: %s", ctx, msg ? msg : "unknown");
    }
}

/* Non-fatal version: returns -1 on error, 0 on success.
   Used in GLiNER2 inference so ONNX errors don't kill the helper. */
static int
check_status_soft (const OrtApi *api, OrtStatus *st, const char *ctx)
{
  if (st)
    {
      const char *msg = api->GetErrorMessage (st);
      fprintf (stderr, "ONNX soft error [%s]: %s\n", ctx, msg ? msg : "unknown");
      api->ReleaseStatus (st);
      return -1;
    }
  return 0;
}

static void
write_error (uint32_t status, const char *msg)
{
  ipc_hdr_t h;
  memset (&h, 0, sizeof (h));
  h.magic = ONNX_IPC_MAGIC;
  h.version = ONNX_IPC_VERSION;
  h.status = status;
  size_t len = strlen (msg);
  uint32_t msg_len = (uint32_t) len;
  h.payload_len = sizeof (uint32_t) + msg_len;
  write_exact (&h, sizeof (h));
  write_exact (&msg_len, sizeof (uint32_t));
  if (msg_len)
    write_exact (msg, msg_len);
}

/* ---------- WordPiece Tokenizer (BERT-compatible, zero Python) ---------- */

#define WP_HASH_SIZE 65536
#define WP_MAX_TOKEN_LEN 256
#define WP_CLS_ID 101
#define WP_SEP_ID 102
#define WP_PAD_ID 0
#define WP_UNK_ID 100

typedef struct wp_entry_s
{
  char *token;
  int32_t id;
  struct wp_entry_s *next;
} wp_entry_t;

typedef struct
{
  wp_entry_t *buckets[WP_HASH_SIZE];
  int32_t vocab_size;
  int max_seq_len;
} wp_tokenizer_t;

static wp_tokenizer_t g_wp = { {0}, 0, 128 };	/* max_seq_len is either tokenizer's */
static const char *g_output_name = NULL;
static int g_wp_trim_pad = 0;

/* How an embedding request is run: its texts in order of token count, as
   sub-batches of at most g_sub_rows rows and g_tokens_per_batch padded tokens
   (--sub-batch-rows, --tokens-per-batch; --no-sort keeps request order). */
static int g_max_texts = 4096;
static int g_sub_rows = 16;
static int g_tokens_per_batch = 8192;
static int g_sort = 1;

/* The token counts wp_cmp_token_count orders by: qsort takes no context, and
   the helper serves one request at a time. */
static const int *g_sort_len = NULL;

/* By token count, then by input position, so texts of one length keep their
   order and the result does not depend on the platform's qsort. */
static int
wp_cmp_token_count (const void *a, const void *b)
{
  uint32_t x = *(const uint32_t *) a, y = *(const uint32_t *) b;
  if (g_sort_len[x] != g_sort_len[y])
    return g_sort_len[x] < g_sort_len[y] ? -1 : 1;
  return x < y ? -1 : (x > y ? 1 : 0);
}

static uint32_t
wp_hash (const char *s, size_t len)
{
  uint32_t h = 2166136261u;
  for (size_t i = 0; i < len; i++)
    {
      h ^= (uint8_t) s[i];
      h *= 16777619u;
    }
  return h;
}

static int32_t
wp_lookup (const char *token, size_t len)
{
  uint32_t h = wp_hash (token, len) & (WP_HASH_SIZE - 1);
  for (wp_entry_t *e = g_wp.buckets[h]; e; e = e->next)
    {
      if (strlen (e->token) == len && !memcmp (e->token, token, len))
        return e->id;
    }
  return -1;
}

static int
wp_load_vocab (const char *path)
{
  FILE *f = fopen (path, "r");
  if (!f)
    return -1;
  char line[WP_MAX_TOKEN_LEN];
  int32_t id = 0;
  while (fgets (line, sizeof (line), f))
    {
      size_t len = strlen (line);
      if (len > 0 && line[len - 1] == '\n')
        line[--len] = 0;
      if (len > 0 && line[len - 1] == '\r')
        line[--len] = 0;
      uint32_t h = wp_hash (line, len) & (WP_HASH_SIZE - 1);
      wp_entry_t *e = (wp_entry_t *) malloc (sizeof (wp_entry_t));
      if (!e)
        { fclose (f); return -1; }
      e->token = strdup (line);
      e->id = id;
      e->next = g_wp.buckets[h];
      g_wp.buckets[h] = e;
      id++;
    }
  g_wp.vocab_size = id;
  fclose (f);
  return 0;
}

static int
wp_is_punct (unsigned char c)
{
  if ((c >= '!' && c <= '/') || (c >= ':' && c <= '@') ||
      (c >= '[' && c <= '`') || (c >= '{' && c <= '~'))
    return 1;
  return 0;
}


/* ---------- Text normalisation, as BERT's BasicTokenizer does it ----------
 *
 * With do_lower_case=True that tokenizer runs, per token:
 *
 *     token = token.lower()
 *     token = NFD(token) with every combining mark (category Mn) dropped
 *
 * which is why it maps cafe, CAFE, cafe-acute and CAFE-ACUTE to one vocabulary
 * entry.  Only the first half used to happen here, and only for A-Z, so
 * accented text was tokenised into pieces the model was never trained on:
 * 'resume' against its accented spelling embedded 0.86 apart, about as far as
 * two unrelated sentences.
 *
 * Covered: ASCII, Latin-1 Supplement and Latin Extended-A (the table below),
 * plus combining marks U+0300-U+036F dropped outright, so text that arrives
 * already decomposed normalises the same way as precomposed text.
 *
 * NOT covered, deliberately: CJK segmentation (BERT puts spaces around CJK
 * codepoints), full Unicode NFD, and Greek/Cyrillic case folding.  Those are
 * separate gaps with separate tests; see lace2/docs/vector-index.
 */

/* Generated by lace2/plans/onnx-tokenizer-accents/gen_fold_table.py
 * from Python's unicodedata -- do not hand-edit.
 *
 * Lowercased and with combining marks removed, exactly as BERT's
 * BasicTokenizer does it with do_lower_case=True.  0 means drop the
 * character entirely.
 *
 * Known limit: a per-codepoint table cannot express a context-dependent
 * fold.  Greek final sigma is the one that matters -- Python lowercases
 * a word-final capital sigma to U+03C2, this maps every capital sigma to
 * U+03C3.  Both are in the vocabulary, so a word ending in sigma may
 * tokenise one piece differently from HuggingFace.
 */

/* Latin-1 Supplement, Latin Extended-A and -B */
#define WP_LATIN_LO 0x00C0
#define WP_LATIN_HI 0x024F
static const unsigned short wp_latin_tab[WP_LATIN_HI - WP_LATIN_LO + 1] = {
  0x0061, 0x0061, 0x0061, 0x0061, 0x0061, 0x0061, 0x00E6, 0x0063,
  0x0065, 0x0065, 0x0065, 0x0065, 0x0069, 0x0069, 0x0069, 0x0069,
  0x00F0, 0x006E, 0x006F, 0x006F, 0x006F, 0x006F, 0x006F, 0x00D7,
  0x00F8, 0x0075, 0x0075, 0x0075, 0x0075, 0x0079, 0x00FE, 0x00DF,
  0x0061, 0x0061, 0x0061, 0x0061, 0x0061, 0x0061, 0x00E6, 0x0063,
  0x0065, 0x0065, 0x0065, 0x0065, 0x0069, 0x0069, 0x0069, 0x0069,
  0x00F0, 0x006E, 0x006F, 0x006F, 0x006F, 0x006F, 0x006F, 0x00F7,
  0x00F8, 0x0075, 0x0075, 0x0075, 0x0075, 0x0079, 0x00FE, 0x0079,
  0x0061, 0x0061, 0x0061, 0x0061, 0x0061, 0x0061, 0x0063, 0x0063,
  0x0063, 0x0063, 0x0063, 0x0063, 0x0063, 0x0063, 0x0064, 0x0064,
  0x0111, 0x0111, 0x0065, 0x0065, 0x0065, 0x0065, 0x0065, 0x0065,
  0x0065, 0x0065, 0x0065, 0x0065, 0x0067, 0x0067, 0x0067, 0x0067,
  0x0067, 0x0067, 0x0067, 0x0067, 0x0068, 0x0068, 0x0127, 0x0127,
  0x0069, 0x0069, 0x0069, 0x0069, 0x0069, 0x0069, 0x0069, 0x0069,
  0x0069, 0x0131, 0x0133, 0x0133, 0x006A, 0x006A, 0x006B, 0x006B,
  0x0138, 0x006C, 0x006C, 0x006C, 0x006C, 0x006C, 0x006C, 0x0140,
  0x0140, 0x0142, 0x0142, 0x006E, 0x006E, 0x006E, 0x006E, 0x006E,
  0x006E, 0x0149, 0x014B, 0x014B, 0x006F, 0x006F, 0x006F, 0x006F,
  0x006F, 0x006F, 0x0153, 0x0153, 0x0072, 0x0072, 0x0072, 0x0072,
  0x0072, 0x0072, 0x0073, 0x0073, 0x0073, 0x0073, 0x0073, 0x0073,
  0x0073, 0x0073, 0x0074, 0x0074, 0x0074, 0x0074, 0x0167, 0x0167,
  0x0075, 0x0075, 0x0075, 0x0075, 0x0075, 0x0075, 0x0075, 0x0075,
  0x0075, 0x0075, 0x0075, 0x0075, 0x0077, 0x0077, 0x0079, 0x0079,
  0x0079, 0x007A, 0x007A, 0x007A, 0x007A, 0x007A, 0x007A, 0x017F,
  0x0180, 0x0253, 0x0183, 0x0183, 0x0185, 0x0185, 0x0254, 0x0188,
  0x0188, 0x0256, 0x0257, 0x018C, 0x018C, 0x018D, 0x01DD, 0x0259,
  0x025B, 0x0192, 0x0192, 0x0260, 0x0263, 0x0195, 0x0269, 0x0268,
  0x0199, 0x0199, 0x019A, 0x019B, 0x026F, 0x0272, 0x019E, 0x0275,
  0x006F, 0x006F, 0x01A3, 0x01A3, 0x01A5, 0x01A5, 0x0280, 0x01A8,
  0x01A8, 0x0283, 0x01AA, 0x01AB, 0x01AD, 0x01AD, 0x0288, 0x0075,
  0x0075, 0x028A, 0x028B, 0x01B4, 0x01B4, 0x01B6, 0x01B6, 0x0292,
  0x01B9, 0x01B9, 0x01BA, 0x01BB, 0x01BD, 0x01BD, 0x01BE, 0x01BF,
  0x01C0, 0x01C1, 0x01C2, 0x01C3, 0x01C6, 0x01C6, 0x01C6, 0x01C9,
  0x01C9, 0x01C9, 0x01CC, 0x01CC, 0x01CC, 0x0061, 0x0061, 0x0069,
  0x0069, 0x006F, 0x006F, 0x0075, 0x0075, 0x0075, 0x0075, 0x0075,
  0x0075, 0x0075, 0x0075, 0x0075, 0x0075, 0x01DD, 0x0061, 0x0061,
  0x0061, 0x0061, 0x00E6, 0x00E6, 0x01E5, 0x01E5, 0x0067, 0x0067,
  0x006B, 0x006B, 0x006F, 0x006F, 0x006F, 0x006F, 0x0292, 0x0292,
  0x006A, 0x01F3, 0x01F3, 0x01F3, 0x0067, 0x0067, 0x0195, 0x01BF,
  0x006E, 0x006E, 0x0061, 0x0061, 0x00E6, 0x00E6, 0x00F8, 0x00F8,
  0x0061, 0x0061, 0x0061, 0x0061, 0x0065, 0x0065, 0x0065, 0x0065,
  0x0069, 0x0069, 0x0069, 0x0069, 0x006F, 0x006F, 0x006F, 0x006F,
  0x0072, 0x0072, 0x0072, 0x0072, 0x0075, 0x0075, 0x0075, 0x0075,
  0x0073, 0x0073, 0x0074, 0x0074, 0x021D, 0x021D, 0x0068, 0x0068,
  0x019E, 0x0221, 0x0223, 0x0223, 0x0225, 0x0225, 0x0061, 0x0061,
  0x0065, 0x0065, 0x006F, 0x006F, 0x006F, 0x006F, 0x006F, 0x006F,
  0x006F, 0x006F, 0x0079, 0x0079, 0x0234, 0x0235, 0x0236, 0x0237,
  0x0238, 0x0239, 0x2C65, 0x023C, 0x023C, 0x019A, 0x2C66, 0x023F,
  0x0240, 0x0242, 0x0242, 0x0180, 0x0289, 0x028C, 0x0247, 0x0247,
  0x0249, 0x0249, 0x024B, 0x024B, 0x024D, 0x024D, 0x024F, 0x024F,
};

/* Greek and Cyrillic */
#define WP_GRCY_LO 0x0370
#define WP_GRCY_HI 0x04FF
static const unsigned short wp_grcy_tab[WP_GRCY_HI - WP_GRCY_LO + 1] = {
  0x0371, 0x0371, 0x0373, 0x0373, 0x02B9, 0x0375, 0x0377, 0x0377,
  0x0378, 0x0379, 0x037A, 0x037B, 0x037C, 0x037D, 0x003B, 0x03F3,
  0x0380, 0x0381, 0x0382, 0x0383, 0x0384, 0x00A8, 0x03B1, 0x00B7,
  0x03B5, 0x03B7, 0x03B9, 0x038B, 0x03BF, 0x038D, 0x03C5, 0x03C9,
  0x03B9, 0x03B1, 0x03B2, 0x03B3, 0x03B4, 0x03B5, 0x03B6, 0x03B7,
  0x03B8, 0x03B9, 0x03BA, 0x03BB, 0x03BC, 0x03BD, 0x03BE, 0x03BF,
  0x03C0, 0x03C1, 0x03A2, 0x03C3, 0x03C4, 0x03C5, 0x03C6, 0x03C7,
  0x03C8, 0x03C9, 0x03B9, 0x03C5, 0x03B1, 0x03B5, 0x03B7, 0x03B9,
  0x03C5, 0x03B1, 0x03B2, 0x03B3, 0x03B4, 0x03B5, 0x03B6, 0x03B7,
  0x03B8, 0x03B9, 0x03BA, 0x03BB, 0x03BC, 0x03BD, 0x03BE, 0x03BF,
  0x03C0, 0x03C1, 0x03C2, 0x03C3, 0x03C4, 0x03C5, 0x03C6, 0x03C7,
  0x03C8, 0x03C9, 0x03B9, 0x03C5, 0x03BF, 0x03C5, 0x03C9, 0x03D7,
  0x03D0, 0x03D1, 0x03D2, 0x03D2, 0x03D2, 0x03D5, 0x03D6, 0x03D7,
  0x03D9, 0x03D9, 0x03DB, 0x03DB, 0x03DD, 0x03DD, 0x03DF, 0x03DF,
  0x03E1, 0x03E1, 0x03E3, 0x03E3, 0x03E5, 0x03E5, 0x03E7, 0x03E7,
  0x03E9, 0x03E9, 0x03EB, 0x03EB, 0x03ED, 0x03ED, 0x03EF, 0x03EF,
  0x03F0, 0x03F1, 0x03F2, 0x03F3, 0x03B8, 0x03F5, 0x03F6, 0x03F8,
  0x03F8, 0x03F2, 0x03FB, 0x03FB, 0x03FC, 0x037B, 0x037C, 0x037D,
  0x0435, 0x0435, 0x0452, 0x0433, 0x0454, 0x0455, 0x0456, 0x0456,
  0x0458, 0x0459, 0x045A, 0x045B, 0x043A, 0x0438, 0x0443, 0x045F,
  0x0430, 0x0431, 0x0432, 0x0433, 0x0434, 0x0435, 0x0436, 0x0437,
  0x0438, 0x0438, 0x043A, 0x043B, 0x043C, 0x043D, 0x043E, 0x043F,
  0x0440, 0x0441, 0x0442, 0x0443, 0x0444, 0x0445, 0x0446, 0x0447,
  0x0448, 0x0449, 0x044A, 0x044B, 0x044C, 0x044D, 0x044E, 0x044F,
  0x0430, 0x0431, 0x0432, 0x0433, 0x0434, 0x0435, 0x0436, 0x0437,
  0x0438, 0x0438, 0x043A, 0x043B, 0x043C, 0x043D, 0x043E, 0x043F,
  0x0440, 0x0441, 0x0442, 0x0443, 0x0444, 0x0445, 0x0446, 0x0447,
  0x0448, 0x0449, 0x044A, 0x044B, 0x044C, 0x044D, 0x044E, 0x044F,
  0x0435, 0x0435, 0x0452, 0x0433, 0x0454, 0x0455, 0x0456, 0x0456,
  0x0458, 0x0459, 0x045A, 0x045B, 0x043A, 0x0438, 0x0443, 0x045F,
  0x0461, 0x0461, 0x0463, 0x0463, 0x0465, 0x0465, 0x0467, 0x0467,
  0x0469, 0x0469, 0x046B, 0x046B, 0x046D, 0x046D, 0x046F, 0x046F,
  0x0471, 0x0471, 0x0473, 0x0473, 0x0475, 0x0475, 0x0475, 0x0475,
  0x0479, 0x0479, 0x047B, 0x047B, 0x047D, 0x047D, 0x047F, 0x047F,
  0x0481, 0x0481, 0x0482, 0x0000, 0x0000, 0x0000, 0x0000, 0x0000,
  0x0488, 0x0489, 0x048B, 0x048B, 0x048D, 0x048D, 0x048F, 0x048F,
  0x0491, 0x0491, 0x0493, 0x0493, 0x0495, 0x0495, 0x0497, 0x0497,
  0x0499, 0x0499, 0x049B, 0x049B, 0x049D, 0x049D, 0x049F, 0x049F,
  0x04A1, 0x04A1, 0x04A3, 0x04A3, 0x04A5, 0x04A5, 0x04A7, 0x04A7,
  0x04A9, 0x04A9, 0x04AB, 0x04AB, 0x04AD, 0x04AD, 0x04AF, 0x04AF,
  0x04B1, 0x04B1, 0x04B3, 0x04B3, 0x04B5, 0x04B5, 0x04B7, 0x04B7,
  0x04B9, 0x04B9, 0x04BB, 0x04BB, 0x04BD, 0x04BD, 0x04BF, 0x04BF,
  0x04CF, 0x0436, 0x0436, 0x04C4, 0x04C4, 0x04C6, 0x04C6, 0x04C8,
  0x04C8, 0x04CA, 0x04CA, 0x04CC, 0x04CC, 0x04CE, 0x04CE, 0x04CF,
  0x0430, 0x0430, 0x0430, 0x0430, 0x04D5, 0x04D5, 0x0435, 0x0435,
  0x04D9, 0x04D9, 0x04D9, 0x04D9, 0x0436, 0x0436, 0x0437, 0x0437,
  0x04E1, 0x04E1, 0x0438, 0x0438, 0x0438, 0x0438, 0x043E, 0x043E,
  0x04E9, 0x04E9, 0x04E9, 0x04E9, 0x044D, 0x044D, 0x0443, 0x0443,
  0x0443, 0x0443, 0x0443, 0x0443, 0x0447, 0x0447, 0x04F7, 0x04F7,
  0x044B, 0x044B, 0x04FB, 0x04FB, 0x04FD, 0x04FD, 0x04FF, 0x04FF,
};

/* Latin Extended Additional (Vietnamese) */
#define WP_LATEXT_LO 0x1E00
#define WP_LATEXT_HI 0x1EFF
static const unsigned short wp_latext_tab[WP_LATEXT_HI - WP_LATEXT_LO + 1] = {
  0x0061, 0x0061, 0x0062, 0x0062, 0x0062, 0x0062, 0x0062, 0x0062,
  0x0063, 0x0063, 0x0064, 0x0064, 0x0064, 0x0064, 0x0064, 0x0064,
  0x0064, 0x0064, 0x0064, 0x0064, 0x0065, 0x0065, 0x0065, 0x0065,
  0x0065, 0x0065, 0x0065, 0x0065, 0x0065, 0x0065, 0x0066, 0x0066,
  0x0067, 0x0067, 0x0068, 0x0068, 0x0068, 0x0068, 0x0068, 0x0068,
  0x0068, 0x0068, 0x0068, 0x0068, 0x0069, 0x0069, 0x0069, 0x0069,
  0x006B, 0x006B, 0x006B, 0x006B, 0x006B, 0x006B, 0x006C, 0x006C,
  0x006C, 0x006C, 0x006C, 0x006C, 0x006C, 0x006C, 0x006D, 0x006D,
  0x006D, 0x006D, 0x006D, 0x006D, 0x006E, 0x006E, 0x006E, 0x006E,
  0x006E, 0x006E, 0x006E, 0x006E, 0x006F, 0x006F, 0x006F, 0x006F,
  0x006F, 0x006F, 0x006F, 0x006F, 0x0070, 0x0070, 0x0070, 0x0070,
  0x0072, 0x0072, 0x0072, 0x0072, 0x0072, 0x0072, 0x0072, 0x0072,
  0x0073, 0x0073, 0x0073, 0x0073, 0x0073, 0x0073, 0x0073, 0x0073,
  0x0073, 0x0073, 0x0074, 0x0074, 0x0074, 0x0074, 0x0074, 0x0074,
  0x0074, 0x0074, 0x0075, 0x0075, 0x0075, 0x0075, 0x0075, 0x0075,
  0x0075, 0x0075, 0x0075, 0x0075, 0x0076, 0x0076, 0x0076, 0x0076,
  0x0077, 0x0077, 0x0077, 0x0077, 0x0077, 0x0077, 0x0077, 0x0077,
  0x0077, 0x0077, 0x0078, 0x0078, 0x0078, 0x0078, 0x0079, 0x0079,
  0x007A, 0x007A, 0x007A, 0x007A, 0x007A, 0x007A, 0x0068, 0x0074,
  0x0077, 0x0079, 0x1E9A, 0x017F, 0x1E9C, 0x1E9D, 0x00DF, 0x1E9F,
  0x0061, 0x0061, 0x0061, 0x0061, 0x0061, 0x0061, 0x0061, 0x0061,
  0x0061, 0x0061, 0x0061, 0x0061, 0x0061, 0x0061, 0x0061, 0x0061,
  0x0061, 0x0061, 0x0061, 0x0061, 0x0061, 0x0061, 0x0061, 0x0061,
  0x0065, 0x0065, 0x0065, 0x0065, 0x0065, 0x0065, 0x0065, 0x0065,
  0x0065, 0x0065, 0x0065, 0x0065, 0x0065, 0x0065, 0x0065, 0x0065,
  0x0069, 0x0069, 0x0069, 0x0069, 0x006F, 0x006F, 0x006F, 0x006F,
  0x006F, 0x006F, 0x006F, 0x006F, 0x006F, 0x006F, 0x006F, 0x006F,
  0x006F, 0x006F, 0x006F, 0x006F, 0x006F, 0x006F, 0x006F, 0x006F,
  0x006F, 0x006F, 0x006F, 0x006F, 0x0075, 0x0075, 0x0075, 0x0075,
  0x0075, 0x0075, 0x0075, 0x0075, 0x0075, 0x0075, 0x0075, 0x0075,
  0x0075, 0x0075, 0x0079, 0x0079, 0x0079, 0x0079, 0x0079, 0x0079,
  0x0079, 0x0079, 0x1EFB, 0x1EFB, 0x1EFD, 0x1EFD, 0x1EFF, 0x1EFF,
};

/* Decode one UTF-8 sequence.  Malformed input yields the raw byte rather than
   an error: a tokenizer must not fail on whatever a user stored. */
static uint32_t
wp_utf8_next (const char *s, size_t len, size_t *i)
{
  unsigned char c = (unsigned char) s[*i];
  uint32_t cp;
  size_t need;

  if (c < 0x80)		{ (*i)++; return c; }
  else if ((c & 0xE0) == 0xC0)	{ cp = c & 0x1F; need = 1; }
  else if ((c & 0xF0) == 0xE0)	{ cp = c & 0x0F; need = 2; }
  else if ((c & 0xF8) == 0xF0)	{ cp = c & 0x07; need = 3; }
  else				{ (*i)++; return c; }

  /* the continuation bytes live at *i+1 .. *i+need */
  if (*i + need >= len)
    { (*i)++; return c; }
  for (size_t k = 1; k <= need; k++)
    {
      unsigned char cc = (unsigned char) s[*i + k];
      if ((cc & 0xC0) != 0x80)
	{ (*i)++; return c; }
      cp = (cp << 6) | (cc & 0x3F);
    }
  *i += need + 1;
  return cp;
}

static size_t
wp_utf8_put (uint32_t cp, char *out)
{
  if (cp < 0x80)	{ out[0] = (char) cp; return 1; }
  if (cp < 0x800)	{ out[0] = (char) (0xC0 | (cp >> 6));
			  out[1] = (char) (0x80 | (cp & 0x3F)); return 2; }
  if (cp < 0x10000)	{ out[0] = (char) (0xE0 | (cp >> 12));
			  out[1] = (char) (0x80 | ((cp >> 6) & 0x3F));
			  out[2] = (char) (0x80 | (cp & 0x3F)); return 3; }
  out[0] = (char) (0xF0 | (cp >> 18));
  out[1] = (char) (0x80 | ((cp >> 12) & 0x3F));
  out[2] = (char) (0x80 | ((cp >> 6) & 0x3F));
  out[3] = (char) (0x80 | (cp & 0x3F));
  return 4;
}

/* Lowercase and strip the accent from one codepoint.  Returns 0 for a
   codepoint that disappears entirely (a combining mark). */
static uint32_t
wp_fold_cp (uint32_t cp)
{
  if (cp < 0x80)
    return (cp >= 'A' && cp <= 'Z') ? cp + 32 : cp;
  if (cp >= 0x0300 && cp <= 0x036F)
    return 0;			/* combining mark: NFD input, already decomposed */
  if (cp >= WP_LATIN_LO && cp <= WP_LATIN_HI)
    return wp_latin_tab[cp - WP_LATIN_LO];
  if (cp >= WP_GRCY_LO && cp <= WP_GRCY_HI)
    return wp_grcy_tab[cp - WP_GRCY_LO];
  if (cp >= WP_LATEXT_LO && cp <= WP_LATEXT_HI)
    return wp_latext_tab[cp - WP_LATEXT_LO];
  return cp;
}

/* Normalise into OUT (which must hold at least LEN + 1 bytes -- folding never
   grows the text) and return the length written. */
static size_t
wp_normalize (const char *src, size_t len, char *out)
{
  size_t i = 0, w = 0;
  while (i < len)
    {
      uint32_t cp = wp_fold_cp (wp_utf8_next (src, len, &i));
      if (cp)
	w += wp_utf8_put (cp, out + w);
    }
  out[w] = 0;
  return w;
}

static int
wp_tokenize_n (const char *text, size_t text_len, int64_t *ids, int64_t *mask, int max_len)
{
  int pos = 0;
  ids[pos] = WP_CLS_ID;
  mask[pos] = 1;
  pos++;

  /* Lowercase AND strip accents, as BERT does; folding never grows the text. */
  char *lower = (char *) malloc (text_len + 1);
  if (!lower)
    goto finish;
  text_len = wp_normalize (text, text_len, lower);

  size_t ti = 0;
  while (ti < text_len && pos < max_len - 1)
    {
      while (ti < text_len && (lower[ti] == ' ' || lower[ti] == '\t' ||
             lower[ti] == '\n' || lower[ti] == '\r'))
        ti++;
      if (ti >= text_len)
        break;

      if (wp_is_punct ((unsigned char) lower[ti]))
        {
          char buf[2] = { lower[ti], 0 };
          int32_t tid = wp_lookup (buf, 1);
          ids[pos] = (tid >= 0) ? tid : WP_UNK_ID;
          mask[pos] = 1;
          pos++;
          ti++;
          continue;
        }

      size_t wstart = ti;
      while (ti < text_len && lower[ti] != ' ' && lower[ti] != '\t' &&
             lower[ti] != '\n' && lower[ti] != '\r' &&
             !wp_is_punct ((unsigned char) lower[ti]))
        ti++;
      size_t wlen = ti - wstart;

      size_t ws = 0;
      while (ws < wlen && pos < max_len - 1)
        {
          size_t we = wlen;
          int32_t found_id = -1;
          while (we > ws)
            {
              char piece[WP_MAX_TOKEN_LEN];
              size_t plen;
              if (ws == 0)
                {
                  plen = we - ws;
                  if (plen >= WP_MAX_TOKEN_LEN)
                    plen = WP_MAX_TOKEN_LEN - 1;
                  memcpy (piece, lower + wstart + ws, plen);
                  piece[plen] = 0;
                }
              else
                {
                  plen = we - ws + 2;
                  if (plen >= WP_MAX_TOKEN_LEN)
                    plen = WP_MAX_TOKEN_LEN - 1;
                  piece[0] = '#';
                  piece[1] = '#';
                  memcpy (piece + 2, lower + wstart + ws, plen - 2);
                  piece[plen] = 0;
                }
              found_id = wp_lookup (piece, plen);
              if (found_id >= 0)
                break;
              we--;
            }
          if (found_id >= 0)
            {
              ids[pos] = found_id;
              mask[pos] = 1;
              pos++;
              ws = we;
            }
          else
            {
              ids[pos] = WP_UNK_ID;
              mask[pos] = 1;
              pos++;
              break;
            }
        }
    }
  free (lower);

finish:
  if (pos < max_len)
    {
      ids[pos] = WP_SEP_ID;
      mask[pos] = 1;
      pos++;
    }
  int n_tokens = pos;
  while (pos < max_len)
    {
      ids[pos] = WP_PAD_ID;
      mask[pos] = 0;
      pos++;
    }
  return n_tokens;
}

/* ---------- Byte-level BPE Tokenizer (RoBERTa, zero Python) ----------

   What Hugging Face's RobertaTokenizerFast does, as sentence-transformers
   drives it -- GPT-2's byte-level BPE, framed and padded as RoBERTa is:
     1. strip leading and trailing whitespace (str.strip, in the library);
     2. split out the special tokens written into the text -- <s>, </s>,
        <pad>, <unk>, <mask>, of which <mask> also takes the spaces before it;
     3. pre-tokenize each piece with GPT-2's pattern
          's|'t|'re|'ve|'m|'ll|'d| ?\p{L}+| ?\p{N}+| ?[^\s\p{L}\p{N}]+|\s+(?!\S)|\s+
     4. map each pre-token's bytes to the tokens of bytes_to_unicode's
        printable characters and merge adjacent tokens, lowest merges.txt rank
        first and leftmost among equals -- Hugging Face's own merge queue;
     5. <s> ... </s> around at most max_seq_len - 2 tokens, padded with <pad>.
   The character classes of step 3 are the tokenizer's own, generated from it
   into onnx_bpe_classes.h.  vocab.json names the tokens; merges.txt, beside
   it, ranks the merges. */

#include "onnx_bpe_classes.h"

#define BPE_HASH_SIZE 131072
#define BPE_CACHE_MAX 65536	/* pre-tokens remembered before the cache is emptied */
#define BPE_CACHE_WORD 256	/* the longest pre-token worth remembering, in bytes */
/* A pre-token longer than this -- a run with no space and no change between
   letters, digits and the rest -- is merged in pieces this long, and only
   there can the ids differ from Hugging Face's, which merges it whole.  It is
   the longest text the plugin sends, so only a --tokenize text can reach it. */
#define BPE_MAX_WORD HELPER_MAX_INPUT

enum { TOK_NONE = 0, TOK_WORDPIECE, TOK_BPE };
enum { BPE_OTHER = 0, BPE_LETTER, BPE_NUMBER, BPE_SPACE };

typedef struct bpe_entry_s
{
  char *key;
  uint32_t key_len;
  int32_t val;
  struct bpe_entry_s *next;
} bpe_entry_t;

/* One merge: the pair of token ids it joins, its rank, the token it makes. */
typedef struct
{
  uint64_t pair;		/* left id << 32 | right id */
  int32_t rank;
  int32_t new_id;
  int used;
} bpe_merge_t;

/* A merge waiting in the queue, at the position of its left token. */
typedef struct
{
  int32_t rank, pos, new_id;
} bpe_queued_t;

typedef struct bpe_cached_s
{
  char *word;
  uint32_t word_len;
  int32_t n_ids;
  int32_t *ids;
  struct bpe_cached_s *next;
} bpe_cached_t;

static int g_tok_kind = TOK_NONE;
static bpe_entry_t *g_bpe_vocab[BPE_HASH_SIZE];
static bpe_merge_t *g_bpe_merges;	/* open addressing, g_bpe_merge_mask + 1 slots */
static uint64_t g_bpe_merge_mask;
static int g_bpe_merge_shift;
static bpe_cached_t *g_bpe_cache[BPE_HASH_SIZE];
static int g_bpe_cache_count = 0;
static int32_t g_bpe_vocab_size = 0;
static int32_t g_bpe_bos = -1, g_bpe_eos = -1, g_bpe_pad = -1;
static char g_bpe_byte_str[256][2];	/* each byte's printable character, UTF-8 */
static uint8_t g_bpe_byte_len[256];
static int32_t g_bpe_byte_id[256];	/* and its token */
static uint8_t g_bpe_ascii_class[128];
/* One pre-token's tokens as a list, and the merge queue: reused, grown. */
static int32_t *g_bw_sym, *g_bw_prev, *g_bw_next;
static bpe_queued_t *g_bw_queue;
static size_t g_bw_cap = 0;

#define BPE_NRANGES(t) (sizeof (t) / sizeof ((t)[0]))

static int
bpe_in (const uint32_t (*r)[2], size_t n, uint32_t c)
{
  size_t lo = 0, hi = n;
  while (lo < hi)
    {
      size_t mid = (lo + hi) / 2;
      if (c < r[mid][0])
	hi = mid;
      else if (c > r[mid][1])
	lo = mid + 1;
      else
	return 1;
    }
  return 0;
}

static int
bpe_class_slow (uint32_t c)
{
  if (bpe_in (bpe_space_ranges, BPE_NRANGES (bpe_space_ranges), c))
    return BPE_SPACE;
  if (bpe_in (bpe_letter_ranges, BPE_NRANGES (bpe_letter_ranges), c))
    return BPE_LETTER;
  if (bpe_in (bpe_number_ranges, BPE_NRANGES (bpe_number_ranges), c))
    return BPE_NUMBER;
  return BPE_OTHER;
}

static int
bpe_class (uint32_t c)
{
  return c < 128 ? g_bpe_ascii_class[c] : bpe_class_slow (c);
}

/* The code point at s[i], its length in *len.  A byte that does not start a
   well-formed sequence decodes alone, as U+FFFD: it classes as "other" and is
   still carried byte for byte, which is all byte-level BPE needs. */
static uint32_t
bpe_utf8 (const unsigned char *s, size_t n, size_t i, size_t *len)
{
  unsigned char c = s[i];
  uint32_t cp;
  size_t need, k;
  if (c < 0x80)
    {
      *len = 1;
      return c;
    }
  if (c >= 0xC2 && c <= 0xDF)
    { need = 1; cp = c & 0x1F; }
  else if (c >= 0xE0 && c <= 0xEF)
    { need = 2; cp = c & 0x0F; }
  else if (c >= 0xF0 && c <= 0xF4)
    { need = 3; cp = c & 0x07; }
  else
    {
      *len = 1;
      return 0xFFFD;
    }
  for (k = 1; k <= need; k++)
    {
      if (i + k >= n || (s[i + k] & 0xC0) != 0x80)
	{
	  *len = 1;
	  return 0xFFFD;
	}
      cp = (cp << 6) | (s[i + k] & 0x3F);
    }
  if ((need == 2 && cp < 0x800) || (need == 3 && (cp < 0x10000 || cp > 0x10FFFF))
      || (cp >= 0xD800 && cp <= 0xDFFF))
    {
      *len = 1;
      return 0xFFFD;
    }
  *len = need + 1;
  return cp;
}

static int
bpe_strip_char (uint32_t c)
{
  return bpe_in (bpe_strip_ranges, BPE_NRANGES (bpe_strip_ranges), c);
}

/* GPT-2's bytes_to_unicode: the printable bytes stand for themselves, the
   others for 256 + n in byte order. */
static void
bpe_init_bytes (void)
{
  int b, n = 0;
  for (b = 0; b < 256; b++)
    {
      uint32_t cp;
      if ((b >= '!' && b <= '~') || (b >= 0xA1 && b <= 0xAC) || (b >= 0xAE && b <= 0xFF))
	cp = (uint32_t) b;
      else
	cp = 256 + n++;
      if (cp < 0x80)
	{
	  g_bpe_byte_str[b][0] = (char) cp;
	  g_bpe_byte_len[b] = 1;
	}
      else
	{
	  g_bpe_byte_str[b][0] = (char) (0xC0 | (cp >> 6));
	  g_bpe_byte_str[b][1] = (char) (0x80 | (cp & 0x3F));
	  g_bpe_byte_len[b] = 2;
	}
    }
  for (b = 0; b < 128; b++)
    g_bpe_ascii_class[b] = (uint8_t) bpe_class_slow ((uint32_t) b);
}

static void
bpe_put (bpe_entry_t **table, const char *key, size_t len, int32_t val)
{
  uint32_t h = wp_hash (key, len) & (BPE_HASH_SIZE - 1);
  bpe_entry_t *e = (bpe_entry_t *) malloc (sizeof (bpe_entry_t));
  if (!e || !(e->key = (char *) malloc (len + 1)))
    fail ("OOM loading the BPE vocabulary");
  memcpy (e->key, key, len);
  e->key[len] = 0;
  e->key_len = (uint32_t) len;
  e->val = val;
  e->next = table[h];
  table[h] = e;
}

static int32_t
bpe_get (bpe_entry_t *const *table, const char *key, size_t len)
{
  uint32_t h = wp_hash (key, len) & (BPE_HASH_SIZE - 1);
  for (const bpe_entry_t *e = table[h]; e; e = e->next)
    if (e->key_len == len && !memcmp (e->key, key, len))
      return e->val;
  return -1;
}

static size_t
bpe_merge_slot (uint64_t pair)
{
  return (size_t) ((pair * 0x9E3779B97F4A7C15ull) >> g_bpe_merge_shift);
}

/* A pair listed twice keeps its later rank, as Hugging Face's map does. */
static void
bpe_merge_put (int32_t a, int32_t b, int32_t rank, int32_t new_id)
{
  uint64_t pair = ((uint64_t) (uint32_t) a << 32) | (uint32_t) b;
  size_t i = bpe_merge_slot (pair);
  while (g_bpe_merges[i].used && g_bpe_merges[i].pair != pair)
    i = (i + 1) & g_bpe_merge_mask;
  g_bpe_merges[i].pair = pair;
  g_bpe_merges[i].rank = rank;
  g_bpe_merges[i].new_id = new_id;
  g_bpe_merges[i].used = 1;
}

static const bpe_merge_t *
bpe_merge_find (int32_t a, int32_t b)
{
  uint64_t pair = ((uint64_t) (uint32_t) a << 32) | (uint32_t) b;
  size_t i = bpe_merge_slot (pair);
  while (g_bpe_merges[i].used)
    {
      if (g_bpe_merges[i].pair == pair)
	return &g_bpe_merges[i];
      i = (i + 1) & g_bpe_merge_mask;
    }
  return NULL;
}

static char *
bpe_read_file (const char *path, size_t *len)
{
  FILE *f = fopen (path, "rb");
  char *buf;
  long sz;
  if (!f)
    return NULL;
  if (fseek (f, 0, SEEK_END) || (sz = ftell (f)) < 0 || fseek (f, 0, SEEK_SET))
    {
      fclose (f);
      return NULL;
    }
  buf = (char *) malloc ((size_t) sz + 1);
  if (!buf || fread (buf, 1, (size_t) sz, f) != (size_t) sz)
    {
      free (buf);
      fclose (f);
      return NULL;
    }
  buf[sz] = 0;
  fclose (f);
  *len = (size_t) sz;
  return buf;
}

static size_t
bpe_put_utf8 (char *out, uint32_t cp)
{
  if (cp < 0x80)
    { out[0] = (char) cp; return 1; }
  if (cp < 0x800)
    { out[0] = (char) (0xC0 | (cp >> 6)); out[1] = (char) (0x80 | (cp & 0x3F)); return 2; }
  if (cp < 0x10000)
    {
      out[0] = (char) (0xE0 | (cp >> 12));
      out[1] = (char) (0x80 | ((cp >> 6) & 0x3F));
      out[2] = (char) (0x80 | (cp & 0x3F));
      return 3;
    }
  out[0] = (char) (0xF0 | (cp >> 18));
  out[1] = (char) (0x80 | ((cp >> 12) & 0x3F));
  out[2] = (char) (0x80 | ((cp >> 6) & 0x3F));
  out[3] = (char) (0x80 | (cp & 0x3F));
  return 4;
}

static int
bpe_hex4 (const char *p, uint32_t *v)
{
  int k;
  *v = 0;
  for (k = 0; k < 4; k++)
    {
      char c = p[k];
      *v <<= 4;
      if (c >= '0' && c <= '9')
	*v |= (uint32_t) (c - '0');
      else if (c >= 'a' && c <= 'f')
	*v |= (uint32_t) (c - 'a' + 10);
      else if (c >= 'A' && c <= 'F')
	*v |= (uint32_t) (c - 'A' + 10);
      else
	return -1;
    }
  return 0;
}

/* The JSON string at *pp (which points at its opening quote), unescaped into
   out as UTF-8; *pp is left past the closing quote. */
static int
bpe_json_string (const char **pp, const char *end, char *out, size_t cap, size_t *out_len)
{
  const char *p = *pp + 1;
  size_t o = 0;
  while (p < end && *p != '"')
    {
      if (o + 4 >= cap)
	return -1;
      if (*p != '\\')
	{
	  out[o++] = *p++;
	  continue;
	}
      if (++p >= end)
	return -1;
      switch (*p)
	{
	case '"': case '\\': case '/':
	  out[o++] = *p++;
	  break;
	case 'b': out[o++] = '\b'; p++; break;
	case 'f': out[o++] = '\f'; p++; break;
	case 'n': out[o++] = '\n'; p++; break;
	case 'r': out[o++] = '\r'; p++; break;
	case 't': out[o++] = '\t'; p++; break;
	case 'u':
	  {
	    uint32_t cp, lo;
	    if (p + 5 > end || bpe_hex4 (p + 1, &cp))
	      return -1;
	    p += 5;
	    if (cp >= 0xD800 && cp <= 0xDBFF && p + 6 <= end && p[0] == '\\' && p[1] == 'u'
		&& !bpe_hex4 (p + 2, &lo) && lo >= 0xDC00 && lo <= 0xDFFF)
	      {
		cp = 0x10000 + ((cp - 0xD800) << 10) + (lo - 0xDC00);
		p += 6;
	      }
	    o += bpe_put_utf8 (out + o, cp);
	    break;
	  }
	default:
	  return -1;
	}
    }
  if (p >= end)
    return -1;
  *pp = p + 1;
  *out_len = o;
  return 0;
}

/* vocab.json -- one JSON object, token to id -- and merges.txt from the same
   directory, one "left right" pair a line in rank order after a #version line. */
static int
bpe_load (const char *vocab_path)
{
  size_t len, dlen, klen;
  char *buf = bpe_read_file (vocab_path, &len), *mbuf, *merges_path, *line, *nl;
  const char *p, *end, *slash;
  char key[1024];
  int32_t rank = 0;
  int pass;
  if (!buf)
    return -1;
  bpe_init_bytes ();
  p = buf;
  end = buf + len;
  while (p < end && *p != '{')
    p++;
  if (p >= end)
    goto bad;
  p++;
  for (;;)
    {
      long id;
      char *after;
      while (p < end && (*p == ' ' || *p == '\n' || *p == '\r' || *p == '\t' || *p == ','))
	p++;
      if (p >= end)
	goto bad;
      if (*p == '}')
	break;
      if (*p != '"' || bpe_json_string (&p, end, key, sizeof (key), &klen))
	goto bad;
      while (p < end && (*p == ' ' || *p == ':' || *p == '\n' || *p == '\r' || *p == '\t'))
	p++;
      id = strtol (p, &after, 10);
      if (after == p || id < 0 || id > INT32_MAX)
	goto bad;
      p = after;
      bpe_put (g_bpe_vocab, key, klen, (int32_t) id);
      if ((int32_t) id >= g_bpe_vocab_size)
	g_bpe_vocab_size = (int32_t) id + 1;
    }
  free (buf);
  /* Byte-level: every byte has a token, or this is some other BPE. */
  for (int by = 0; by < 256; by++)
    if ((g_bpe_byte_id[by] = bpe_get (g_bpe_vocab, g_bpe_byte_str[by], g_bpe_byte_len[by])) < 0)
      {
	fprintf (stderr, "%s has no token for byte 0x%02X: not a byte-level BPE vocabulary\n", vocab_path, by);
	return -1;
      }

  slash = strrchr (vocab_path, '/');
  dlen = slash ? (size_t) (slash - vocab_path + 1) : 0;
  merges_path = (char *) malloc (dlen + sizeof ("merges.txt"));
  if (!merges_path)
    return -1;
  memcpy (merges_path, vocab_path, dlen);
  strcpy (merges_path + dlen, "merges.txt");
  mbuf = bpe_read_file (merges_path, &len);
  if (!mbuf)
    {
      fprintf (stderr, "No merges.txt beside %s (%s)\n", vocab_path, merges_path);
      free (merges_path);
      return -1;
    }
  /* Size the table for the merges, then fill it: each line names two tokens
     and, joined, the token they make, all three in vocab.json -- else the
     file is not this vocabulary's, and Hugging Face refuses it too. */
  for (pass = 0; pass < 2; pass++)
    {
      if (1 == pass)
	{
	  size_t slots = 1024;
	  while (slots < 2 * (size_t) rank)
	    slots <<= 1;
	  g_bpe_merges = (bpe_merge_t *) calloc (slots, sizeof (bpe_merge_t));
	  if (!g_bpe_merges)
	    fail ("OOM loading the BPE merges");
	  g_bpe_merge_mask = slots - 1;
	  for (g_bpe_merge_shift = 64; slots > 1; slots >>= 1)
	    g_bpe_merge_shift--;
	  rank = 0;
	}
      for (line = mbuf; line < mbuf + len; line = nl + 1)
	{
	  size_t ll;
	  char *sp;
	  int32_t a, b, ab;
	  nl = memchr (line, '\n', (size_t) (mbuf + len - line));
	  if (!nl)
	    nl = mbuf + len;
	  ll = (size_t) (nl - line);
	  if (ll && line[ll - 1] == '\r')
	    ll--;
	  if (!ll || (line == mbuf && ll >= 8 && !strncmp (line, "#version", 8)))
	    continue;
	  if (0 == pass)
	    {
	      rank++;
	      continue;
	    }
	  sp = memchr (line, ' ', ll);
	  if (!sp || sp == line || sp == line + ll - 1 || memchr (sp + 1, ' ', (size_t) (line + ll - sp - 1))
	      || ll - 1 > sizeof (key))
	    {
	      fprintf (stderr, "%s: line %d is not a pair of tokens\n", merges_path, (int) rank + 1);
	      goto bad_merges;
	    }
	  a = bpe_get (g_bpe_vocab, line, (size_t) (sp - line));
	  b = bpe_get (g_bpe_vocab, sp + 1, (size_t) (line + ll - sp - 1));
	  memcpy (key, line, (size_t) (sp - line));
	  memcpy (key + (sp - line), sp + 1, (size_t) (line + ll - sp - 1));
	  ab = bpe_get (g_bpe_vocab, key, ll - 1);
	  if (a < 0 || b < 0 || ab < 0)
	    {
	      fprintf (stderr, "%s: merge %d, %.*s, names a token %s does not have\n", merges_path,
		       (int) rank + 1, (int) ll, line, vocab_path);
	      goto bad_merges;
	    }
	  bpe_merge_put (a, b, rank++, ab);
	}
    }
  free (merges_path);
  free (mbuf);

  g_bpe_bos = bpe_get (g_bpe_vocab, "<s>", 3);
  g_bpe_eos = bpe_get (g_bpe_vocab, "</s>", 4);
  g_bpe_pad = bpe_get (g_bpe_vocab, "<pad>", 5);
  if (g_bpe_bos < 0 || g_bpe_eos < 0 || g_bpe_pad < 0)
    {
      fprintf (stderr, "%s has no <s>, </s> or <pad>\n", vocab_path);
      return -1;
    }
  g_tok_kind = TOK_BPE;
  fprintf (stderr, "Loaded %d BPE tokens and %d merges, max_seq_len=%d\n", (int) g_bpe_vocab_size, (int) rank,
	   g_wp.max_seq_len);
  return 0;
bad:
  fprintf (stderr, "%s is not a JSON object of token ids\n", vocab_path);
  free (buf);
  return -1;
bad_merges:
  free (mbuf);
  free (merges_path);
  return -1;
}

static void
bpe_cache_clear (void)
{
  for (int h = 0; h < BPE_HASH_SIZE; h++)
    {
      bpe_cached_t *c = g_bpe_cache[h], *next;
      for (; c; c = next)
	{
	  next = c->next;
	  free (c->word);
	  free (c->ids);
	  free (c);
	}
      g_bpe_cache[h] = NULL;
    }
  g_bpe_cache_count = 0;
}

#define BPE_BEFORE(x, y) ((x).rank < (y).rank || ((x).rank == (y).rank && (x).pos < (y).pos))

static void
bpe_queue_push (size_t *n, int32_t rank, int32_t pos, int32_t new_id)
{
  bpe_queued_t *q = g_bw_queue, e;
  size_t i = (*n)++;
  e.rank = rank;
  e.pos = pos;
  e.new_id = new_id;
  while (i > 0 && BPE_BEFORE (e, q[(i - 1) / 2]))
    {
      q[i] = q[(i - 1) / 2];
      i = (i - 1) / 2;
    }
  q[i] = e;
}

static bpe_queued_t
bpe_queue_pop (size_t *n)
{
  bpe_queued_t *q = g_bw_queue, top = q[0], last = q[--(*n)];
  size_t i = 0, c;
  while ((c = 2 * i + 1) < *n)
    {
      if (c + 1 < *n && BPE_BEFORE (q[c + 1], q[c]))
	c++;
      if (!BPE_BEFORE (q[c], last))
	break;
      q[i] = q[c];
      i = c;
    }
  q[i] = last;
  return top;
}

/* Room for a pre-token of n bytes: n tokens, and at most 3n queued merges --
   the pairs to begin with and two a merge. */
static int
bpe_scratch (size_t n)
{
  size_t cap = g_bw_cap ? g_bw_cap : 256;
  if (n <= g_bw_cap)
    return 1;
  while (cap < n)
    cap *= 2;
  free (g_bw_sym);
  free (g_bw_prev);
  free (g_bw_next);
  free (g_bw_queue);
  g_bw_sym = (int32_t *) malloc (cap * sizeof (int32_t));
  g_bw_prev = (int32_t *) malloc (cap * sizeof (int32_t));
  g_bw_next = (int32_t *) malloc (cap * sizeof (int32_t));
  g_bw_queue = (bpe_queued_t *) malloc (3 * cap * sizeof (bpe_queued_t));
  g_bw_cap = (g_bw_sym && g_bw_prev && g_bw_next && g_bw_queue) ? cap : 0;
  return g_bw_cap != 0;
}

/* The tokens of one pre-token, at most cap of them, into ids and mask.  Its
   bytes start as their byte tokens; then, as Hugging Face's Word::merge_all
   does it, the queued merge of lowest rank -- the leftmost of equals -- joins
   its two tokens, unless one of them has since been merged into another, and
   queues the merges the new token makes with its neighbours. */
static int
bpe_word (const unsigned char *w, size_t wlen, int64_t *ids, int64_t *mask, int cap)
{
  int32_t *sym, *prv, *nxt, p, r;
  size_t k, queued = 0;
  const bpe_merge_t *m;
  bpe_cached_t *c;
  uint32_t h = 0;
  int got = 0, n_out = 0;
  if (!wlen || cap <= 0)
    return 0;
  if (wlen <= BPE_CACHE_WORD)
    {
      h = wp_hash ((const char *) w, wlen) & (BPE_HASH_SIZE - 1);
      for (c = g_bpe_cache[h]; c; c = c->next)
	if (c->word_len == wlen && !memcmp (c->word, w, wlen))
	  {
	    for (; got < c->n_ids && got < cap; got++)
	      {
		ids[got] = c->ids[got];
		mask[got] = 1;
	      }
	    return got;
	  }
    }
  if (!bpe_scratch (wlen))
    fail ("OOM tokenizing a text");
  sym = g_bw_sym;
  prv = g_bw_prev;
  nxt = g_bw_next;
  for (k = 0; k < wlen; k++)
    {
      sym[k] = g_bpe_byte_id[w[k]];
      prv[k] = (int32_t) k - 1;
      nxt[k] = k + 1 < wlen ? (int32_t) k + 1 : -1;
    }
  for (k = 0; k + 1 < wlen; k++)
    if ((m = bpe_merge_find (sym[k], sym[k + 1])))
      bpe_queue_push (&queued, m->rank, (int32_t) k, m->new_id);
  while (queued)
    {
      bpe_queued_t top = bpe_queue_pop (&queued);
      p = top.pos;
      r = nxt[p];
      if (sym[p] < 0 || r < 0)
	continue;
      m = bpe_merge_find (sym[p], sym[r]);
      if (!m || m->new_id != top.new_id)
	continue;		/* a token of the pair has changed since it was queued */
      sym[p] = top.new_id;
      sym[r] = -1;
      nxt[p] = nxt[r];
      if (nxt[r] >= 0)
	prv[nxt[r]] = p;
      if (prv[p] >= 0 && (m = bpe_merge_find (sym[prv[p]], sym[p])))
	bpe_queue_push (&queued, m->rank, prv[p], m->new_id);
      if (nxt[p] >= 0 && (m = bpe_merge_find (sym[p], sym[nxt[p]])))
	bpe_queue_push (&queued, m->rank, p, m->new_id);
    }
  for (p = 0; p >= 0; p = nxt[p])
    {
      if (got < cap)
	{
	  ids[got] = sym[p];
	  mask[got] = 1;
	  got++;
	}
      n_out++;
    }
  if (wlen <= BPE_CACHE_WORD)
    {
      if (g_bpe_cache_count >= BPE_CACHE_MAX)
	bpe_cache_clear ();
      c = (bpe_cached_t *) calloc (1, sizeof (bpe_cached_t));
      if (c && (c->word = (char *) malloc (wlen)) && (c->ids = (int32_t *) malloc ((size_t) n_out * sizeof (int32_t))))
	{
	  memcpy (c->word, w, wlen);
	  c->word_len = (uint32_t) wlen;
	  c->n_ids = n_out;
	  for (p = 0, k = 0; p >= 0; p = nxt[p])
	    c->ids[k++] = sym[p];
	  c->next = g_bpe_cache[h];
	  g_bpe_cache[h] = c;
	  g_bpe_cache_count++;
	}
      else if (c)
	{
	  free (c->word);
	  free (c);
	}
    }
  return got;
}

/* Where the pre-token starting at p[i] ends: GPT-2's alternatives, in order. */
static size_t
bpe_next_pretoken (const unsigned char *p, size_t n, size_t i)
{
  size_t l0, l1, l2, j, k, last;
  uint32_t c = bpe_utf8 (p, n, i, &l0), d;
  int cl;
  /* 's 't 're 've 'm 'll 'd -- lower case only, as the pattern is written. */
  if (c == '\'' && i + 1 < n)
    {
      unsigned char e = p[i + 1];
      if (e == 's' || e == 't' || e == 'm' || e == 'd')
	return i + 2;
      if (i + 2 < n && ((e == 'r' && p[i + 2] == 'e') || (e == 'v' && p[i + 2] == 'e')
			|| (e == 'l' && p[i + 2] == 'l')))
	return i + 3;
    }
  /* One optional ASCII space, then a run of letters, of numbers, or of
     anything but spaces, letters and numbers. */
  j = c == ' ' ? i + 1 : i;
  if (j < n)
    {
      d = bpe_utf8 (p, n, j, &l1);
      cl = bpe_class (d);
      if (cl != BPE_SPACE)
	{
	  k = j + l1;
	  while (k < n && bpe_class (bpe_utf8 (p, n, k, &l2)) == cl)
	    k += l2;
	  return k;
	}
    }
  /* \s+(?!\S), else \s+: a run of spaces, less its last when a non-space
     follows, so that one can lead the next pre-token. */
  if (bpe_class (c) == BPE_SPACE)
    {
      k = last = i;
      while (k < n && bpe_class (bpe_utf8 (p, n, k, &l2)) == BPE_SPACE)
	{
	  last = k;
	  k += l2;
	}
      return (k < n && last > i) ? last : k;
    }
  return i + l0;
}

/* Tokenize p[0..n) -- text with no special token in it -- appending to
   ids/mask from pos, never past limit.  Returns the new pos. */
static int
bpe_piece (const unsigned char *p, size_t n, int64_t *ids, int64_t *mask, int pos, int limit)
{
  size_t i = 0;
  while (i < n && pos < limit)
    {
      size_t e = bpe_next_pretoken (p, n, i);
      while (i < e && pos < limit)
	{
	  size_t cut = e - i;
	  if (cut > BPE_MAX_WORD)
	    {
	      cut = BPE_MAX_WORD;
	      while (cut > 1 && (p[i + cut] & 0xC0) == 0x80)
		cut--;
	    }
	  pos += bpe_word (p + i, cut, ids + pos, mask + pos, limit - pos);
	  i += cut;
	}
      i = e;
    }
  return pos;
}

static int
bpe_tokenize_n (const char *text, size_t text_len, int64_t *ids, int64_t *mask, int max_len)
{
  static const struct { const char *s; size_t len; int lstrip; } specials[] = {
    { "<s>", 3, 0 }, { "</s>", 4, 0 }, { "<pad>", 5, 0 }, { "<unk>", 5, 0 }, { "<mask>", 6, 1 }
  };
  const unsigned char *t = (const unsigned char *) text;
  size_t s = 0, e = text_len, i, l, seg, last_keep;
  int pos = 0, limit = max_len - 1;	/* room for </s> */
  ids[pos] = g_bpe_bos;
  mask[pos++] = 1;

  /* sentence-transformers' str.strip, on both ends. */
  while (s < e && bpe_strip_char (bpe_utf8 (t, e, s, &l)))
    s += l;
  for (i = s, last_keep = s; i < e; i += l)
    if (!bpe_strip_char (bpe_utf8 (t, e, i, &l)))
      last_keep = i + l;
  e = last_keep;

  seg = s;
  for (i = s; i < e && pos < limit; i++)
    {
      int32_t id = -1;
      int k, lstrip = 0;
      size_t tl = 0;
      if (t[i] != '<')
	continue;
      for (k = 0; k < (int) (sizeof (specials) / sizeof (specials[0])); k++)
	if (e - i >= specials[k].len && !memcmp (t + i, specials[k].s, specials[k].len))
	  {
	    id = bpe_get (g_bpe_vocab, specials[k].s, specials[k].len);
	    tl = specials[k].len;
	    lstrip = specials[k].lstrip;
	    break;
	  }
      if (id < 0)
	continue;
      {
	size_t seg_end = i;
	if (lstrip)
	  {
	    /* The piece before keeps only what ends in a non-space. */
	    size_t q, keep = seg;
	    for (q = seg; q < i; q += l)
	      if (bpe_class (bpe_utf8 (t, i, q, &l)) != BPE_SPACE)
		keep = q + l;
	    seg_end = keep;
	  }
	pos = bpe_piece (t + seg, seg_end - seg, ids, mask, pos, limit);
	if (pos < limit)
	  {
	    ids[pos] = id;
	    mask[pos++] = 1;
	  }
	i += tl - 1;
	seg = i + 1;
      }
    }
  if (seg < e)
    pos = bpe_piece (t + seg, e - seg, ids, mask, pos, limit);
  ids[pos] = g_bpe_eos;
  mask[pos++] = 1;
  {
    int n_tokens = pos;
    while (pos < max_len)
      {
	ids[pos] = g_bpe_pad;
	mask[pos] = 0;
	pos++;
      }
    return n_tokens;
  }
}

/* The loaded tokenizer, WordPiece or byte-level BPE. */
static int
tok_tokenize_n (const char *text, size_t text_len, int64_t *ids, int64_t *mask, int max_len)
{
  if (TOK_BPE == g_tok_kind)
    return bpe_tokenize_n (text, text_len, ids, mask, max_len);
  return wp_tokenize_n (text, text_len, ids, mask, max_len);
}

/* ---------- SentencePiece Unigram Tokenizer (GLiNER2/DeBERTa) ---------- */

#define SP_HASH_SIZE 131072
#define SP_MAX_TOKEN_LEN 512

typedef struct sp_entry_s
{
  char *token;
  int32_t id;
  float score;
  struct sp_entry_s *next;
} sp_entry_t;

typedef struct
{
  sp_entry_t *buckets[SP_HASH_SIZE];
  int32_t vocab_size;
  int max_seq_len;
} sp_tokenizer_t;

static sp_tokenizer_t g_sp = { {0}, 0, GLINER2_MAX_SEQ };

/* GLiNER2 special token IDs */
#define SP_PAREN_OPEN 287
#define SP_PAREN_CLOSE 1263
#define SP_TOK_P 128003
#define SP_TOK_E 128005
#define SP_TOK_C 128004
#define SP_TOK_R 128006
#define SP_TOK_L 128007
#define SP_TOK_SEP_TEXT 128002
#define SP_TOK_SEP_STRUCT 128001
#define SP_TOK_DESC 128010
#define SP_TOK_UNK 3

/* GLiNER2 ONNX sessions (loaded at startup if --gliner2-dir given) */
static OrtSession *g_gl2_encoder = NULL;
static OrtSession *g_gl2_span_rep = NULL;
static OrtSession *g_gl2_classifier = NULL;
static OrtSession *g_gl2_count_pred = NULL;
static OrtSession *g_gl2_count_embed = NULL;
static int g_gl2_hidden_size = 768;

static uint32_t
sp_hash (const char *s, size_t len)
{
  uint32_t h = 2166136261u;
  for (size_t i = 0; i < len; i++)
    {
      h ^= (uint8_t) s[i];
      h *= 16777619u;
    }
  return h;
}

static int32_t
sp_lookup (const char *token, size_t len)
{
  uint32_t h = sp_hash (token, len) & (SP_HASH_SIZE - 1);
  for (sp_entry_t *e = g_sp.buckets[h]; e; e = e->next)
    {
      if (strlen (e->token) == len && !memcmp (e->token, token, len))
	return e->id;
    }
  return -1;
}

static int
sp_load_vocab (const char *path)
{
  FILE *f = fopen (path, "r");
  if (!f)
    return -1;
  char line[SP_MAX_TOKEN_LEN * 2];
  while (fgets (line, sizeof (line), f))
    {
      size_t len = strlen (line);
      if (len > 0 && line[len - 1] == '\n')
	line[--len] = 0;
      if (len > 0 && line[len - 1] == '\r')
	line[--len] = 0;
      /* Format: id\ttoken\tscore */
      char *tab1 = strchr (line, '\t');
      if (!tab1)
	continue;
      *tab1 = 0;
      int32_t id = (int32_t) atoi (line);
      char *token = tab1 + 1;
      char *tab2 = strchr (token, '\t');
      if (tab2)
	*tab2 = 0;
      size_t tlen = strlen (token);
      uint32_t h = sp_hash (token, tlen) & (SP_HASH_SIZE - 1);
      sp_entry_t *e = (sp_entry_t *) malloc (sizeof (sp_entry_t));
      if (!e)
	{
	  fclose (f);
	  return -1;
	}
      e->token = strdup (token);
      e->id = id;
      e->score = tab2 ? (float) atof (tab2 + 1) : 0.0f;
      e->next = g_sp.buckets[h];
      g_sp.buckets[h] = e;
      if (id >= g_sp.vocab_size)
	g_sp.vocab_size = id + 1;
    }
  fclose (f);
  return 0;
}

/* Tokenize a single word using greedy longest-match Unigram.
   The word should already have ▁ prepended if it's a word start.
   Returns number of token IDs written. */
static int
sp_tokenize_word (const char *word, size_t wlen, int64_t *ids, int max_ids)
{
  int count = 0;
  size_t pos = 0;
  while (pos < wlen && count < max_ids)
    {
      /* Try longest match first */
      int32_t best_id = -1;
      size_t best_len = 0;
      size_t max_try = wlen - pos;
      if (max_try > SP_MAX_TOKEN_LEN - 1)
	max_try = SP_MAX_TOKEN_LEN - 1;
      for (size_t trylen = max_try; trylen >= 1; trylen--)
	{
	  /* Handle UTF-8: don't split in the middle of a multi-byte char */
	  if (trylen < max_try)
	    {
	      unsigned char c = (unsigned char) word[pos + trylen];
	      if ((c & 0xC0) == 0x80)
		continue;		/* continuation byte, skip */
	    }
	  int32_t tid = sp_lookup (word + pos, trylen);
	  if (tid >= 0)
	    {
	      best_id = tid;
	      best_len = trylen;
	      break;
	    }
	}
      if (best_id >= 0)
	{
	  ids[count++] = best_id;
	  pos += best_len;
	}
      else
	{
	  /* Byte fallback: encode as <0xHH> */
	  unsigned char byte = (unsigned char) word[pos];
	  char hex[8];
	  snprintf (hex, sizeof (hex), "<0x%02X>", byte);
	  int32_t bid = sp_lookup (hex, strlen (hex));
	  ids[count++] = (bid >= 0) ? bid : SP_TOK_UNK;
	  pos++;
	}
    }
  return count;
}

/* Tokenize text for GLiNER2: lowercase, split on whitespace/punct,
   prepend ▁ to each word, tokenize with Unigram.
   Returns number of tokens. Also fills start_map/end_map for char positions. */
static int
sp_tokenize_text (const char *text, size_t text_len,
		  int64_t *ids, int max_ids,
		  int *start_map, int *end_map, int max_words)
{
  int tok_count = 0;
  int word_count = 0;
  /* ▁ is 3 bytes: 0xE2 0x96 0x81 */
  static const char sp_prefix[3] = { (char) 0xE2, (char) 0x96, (char) 0x81 };

  /* Lowercase copy */
  char *lower = (char *) malloc (text_len + 1);
  if (!lower)
    return 0;
  for (size_t i = 0; i < text_len; i++)
    lower[i] = (text[i] >= 'A' && text[i] <= 'Z') ? text[i] + 32 : text[i];
  lower[text_len] = 0;

  size_t i = 0;
  while (i < text_len && tok_count < max_ids && word_count < max_words)
    {
      /* Skip whitespace */
      while (i < text_len && (lower[i] == ' ' || lower[i] == '\t' || lower[i] == '\n' || lower[i] == '\r'))
	i++;
      if (i >= text_len)
	break;

      /* Find word boundary */
      size_t wstart = i;
      if (wp_is_punct ((unsigned char) lower[i]))
	{
	  i++;
	}
      else
	{
	  while (i < text_len && lower[i] != ' ' && lower[i] != '\t' &&
		 lower[i] != '\n' && lower[i] != '\r' &&
		 !wp_is_punct ((unsigned char) lower[i]))
	    i++;
	}
      size_t wlen = i - wstart;

      /* Record char positions for this word */
      if (word_count < max_words)
	{
	  start_map[word_count] = (int) wstart;
	  end_map[word_count] = (int) (wstart + wlen);
	}

      /* Build ▁word for tokenization */
      char buf[SP_MAX_TOKEN_LEN];
      size_t blen = 3 + wlen;
      if (blen >= SP_MAX_TOKEN_LEN)
	blen = SP_MAX_TOKEN_LEN - 1;
      memcpy (buf, sp_prefix, 3);
      memcpy (buf + 3, lower + wstart, blen - 3);
      buf[blen] = 0;

      /* Tokenize this word */
      int64_t word_ids[64];
      int n = sp_tokenize_word (buf, blen, word_ids, 64);

      /* All sub-tokens of this word map to the same word index */
      for (int j = 0; j < n && tok_count < max_ids; j++)
	ids[tok_count++] = word_ids[j];

      word_count++;
    }
  free (lower);
  return tok_count;
}

/* Build GLiNER2 input sequence for entity extraction:
   ( [P] entities ( [E] label1 [E] label2 ... ) ) [SEP_TEXT] text_tokens
   Returns total sequence length. Also fills text_start_idx (index where text tokens begin). */
static int
gliner2_build_entity_input (const char *text, size_t text_len,
			    const char **labels, int num_labels,
			    int64_t *input_ids, int64_t *attention_mask,
			    int max_seq,
			    int *text_token_indices, int *text_start_idx_out,
			    int *start_map, int *end_map, int *num_text_words_out,
			    int *schema_label_indices)
{
  int pos = 0;

  /* Schema prefix: ( [P] entities ( */
  input_ids[pos] = SP_PAREN_OPEN;
  attention_mask[pos] = 1;
  pos++;
  input_ids[pos] = SP_TOK_P;
  attention_mask[pos] = 1;
  pos++;

  /* Tokenize "entities" */
  char ent_buf[32];
  snprintf (ent_buf, sizeof (ent_buf), "\xe2\x96\x81" "entities");
  int32_t ent_id = sp_lookup (ent_buf, strlen (ent_buf));
  input_ids[pos] = (ent_id >= 0) ? ent_id : SP_TOK_UNK;
  attention_mask[pos] = 1;
  pos++;

  input_ids[pos] = SP_PAREN_OPEN;
  attention_mask[pos] = 1;
  pos++;

  /* For each label: [E] label_tokens */
  for (int li = 0; li < num_labels && pos < max_seq - 3; li++)
    {
      input_ids[pos] = SP_TOK_E;
      attention_mask[pos] = 1;
      if (schema_label_indices)
	schema_label_indices[li] = pos;	/* record position of [E] token */
      pos++;

      /* Tokenize the label name with ▁ prefix */
      char lbuf[SP_MAX_TOKEN_LEN];
      size_t llen = strlen (labels[li]);
      if (llen + 3 >= SP_MAX_TOKEN_LEN)
	llen = SP_MAX_TOKEN_LEN - 4;
      memcpy (lbuf, "\xe2\x96\x81", 3);
      /* Lowercase the label */
      for (size_t ci = 0; ci < llen; ci++)
	lbuf[3 + ci] = (labels[li][ci] >= 'A' && labels[li][ci] <= 'Z')
	  ? labels[li][ci] + 32 : labels[li][ci];
      lbuf[3 + llen] = 0;

      int64_t label_ids[16];
      int n = sp_tokenize_word (lbuf, 3 + llen, label_ids, 16);
      for (int j = 0; j < n && pos < max_seq - 3; j++)
	{
	  input_ids[pos] = label_ids[j];
	  attention_mask[pos] = 1;
	  pos++;
	}
    }

  /* Close schema: ) ) */
  input_ids[pos] = SP_PAREN_CLOSE;
  attention_mask[pos] = 1;
  pos++;
  input_ids[pos] = SP_PAREN_CLOSE;
  attention_mask[pos] = 1;
  pos++;

  /* Separator */
  input_ids[pos] = SP_TOK_SEP_TEXT;
  attention_mask[pos] = 1;
  pos++;

  /* Text tokens */
  *text_start_idx_out = pos;
  int text_ids_buf[GLINER2_MAX_TEXT_TOKENS * 4];
  int smap[GLINER2_MAX_TEXT_TOKENS], emap[GLINER2_MAX_TEXT_TOKENS];
  int remaining = max_seq - pos;
  if (remaining > GLINER2_MAX_TEXT_TOKENS * 4)
    remaining = GLINER2_MAX_TEXT_TOKENS * 4;

  int64_t text_tok_ids[GLINER2_MAX_TEXT_TOKENS * 4];
  int ntoks = sp_tokenize_text (text, text_len, text_tok_ids, remaining,
				smap, emap, GLINER2_MAX_TEXT_TOKENS);

  /* Copy text tokens and track which word each token belongs to */
  /* We need word-level mapping: the processor uses "first" token pooling,
     so we track the first token of each word */
  int word_idx = 0;
  int num_text_words = 0;

  /* Re-tokenize to get word boundaries properly */
  {
    char *lower = (char *) malloc (text_len + 1);
    if (!lower)
      {
	*num_text_words_out = 0;
	return pos;
      }
    for (size_t ci = 0; ci < text_len; ci++)
      lower[ci] = (text[ci] >= 'A' && text[ci] <= 'Z') ? text[ci] + 32 : text[ci];
    lower[text_len] = 0;

    size_t ti = 0;
    while (ti < text_len && pos < max_seq && num_text_words < GLINER2_MAX_TEXT_TOKENS)
      {
	while (ti < text_len && (lower[ti] == ' ' || lower[ti] == '\t' || lower[ti] == '\n' || lower[ti] == '\r'))
	  ti++;
	if (ti >= text_len)
	  break;

	size_t wstart = ti;
	if (wp_is_punct ((unsigned char) lower[ti]))
	  ti++;
	else
	  while (ti < text_len && lower[ti] != ' ' && lower[ti] != '\t' &&
		 lower[ti] != '\n' && lower[ti] != '\r' &&
		 !wp_is_punct ((unsigned char) lower[ti]))
	    ti++;
	size_t wlen = ti - wstart;

	start_map[num_text_words] = (int) wstart;
	end_map[num_text_words] = (int) (wstart + wlen);

	/* Tokenize word */
	char buf[SP_MAX_TOKEN_LEN];
	size_t blen = 3 + wlen;
	if (blen >= SP_MAX_TOKEN_LEN)
	  blen = SP_MAX_TOKEN_LEN - 1;
	memcpy (buf, "\xe2\x96\x81", 3);
	memcpy (buf + 3, lower + wstart, blen - 3);
	buf[blen] = 0;

	int64_t wids[64];
	int n = sp_tokenize_word (buf, blen, wids, 64);

	/* First token of this word: record its position in the full sequence */
	text_token_indices[num_text_words] = pos;

	for (int j = 0; j < n && pos < max_seq; j++)
	  {
	    input_ids[pos] = wids[j];
	    attention_mask[pos] = 1;
	    pos++;
	  }
	num_text_words++;
      }
    free (lower);
  }

  *num_text_words_out = num_text_words;

  /* Pad remaining */
  while (pos < max_seq)
    {
      input_ids[pos] = 0;
      attention_mask[pos] = 0;
      pos++;
    }

  return pos;
}

/* ---------- Generalized schema builder ---------- */

/* A single schema block: ( [P] parent_name ( [X] field1 [X] field2 ... ) )
   Multiple blocks are joined with [SEP_STRUCT].
   If descriptions are provided, the prompt becomes:
   ( [P] parent_name [DESCRIPTION] field1: desc1 [DESCRIPTION] field2: desc2 ( [X] field1 [X] field2 ... ) ) */
typedef struct
{
  const char *parent;		/* e.g. "entities", "works_for", "sentiment", "product" */
  int64_t child_tok;		/* SP_TOK_E, SP_TOK_R, SP_TOK_L, SP_TOK_C */
  const char **fields;		/* field/label names */
  const char **descriptions;	/* optional per-field descriptions (NULL if none) */
  int num_fields;
} gliner2_schema_block_t;

/* Build GLiNER2 input sequence for any task type.
   Supports multiple schema blocks joined by [SEP_STRUCT].
   Returns total sequence length.
   schema_label_indices[i] = position of i-th child token ([E]/[R]/[L]/[C]) across all blocks.
   block_field_offsets[b] = index into schema_label_indices where block b's fields start.
   num_total_fields_out = total number of child tokens across all blocks. */
static int
gliner2_build_schema_input (const char *text, size_t text_len,
			    gliner2_schema_block_t *blocks, int num_blocks,
			    int64_t *input_ids, int64_t *attention_mask,
			    int max_seq,
			    int *text_token_indices, int *text_start_idx_out,
			    int *start_map, int *end_map, int *num_text_words_out,
			    int *schema_label_indices, int *block_field_offsets,
			    int *num_total_fields_out)
{
  int pos = 0;
  int total_fields = 0;

  for (int bi = 0; bi < num_blocks; bi++)
    {
      if (bi > 0 && pos < max_seq - 1)
	{
	  /* [SEP_STRUCT] between blocks */
	  input_ids[pos] = SP_TOK_SEP_STRUCT;
	  attention_mask[pos] = 1;
	  pos++;
	}

      if (block_field_offsets)
	block_field_offsets[bi] = total_fields;

      gliner2_schema_block_t *blk = &blocks[bi];

      /* ( [P] parent_name ( */
      if (pos >= max_seq - 4)
	break;
      input_ids[pos] = SP_PAREN_OPEN;
      attention_mask[pos] = 1;
      pos++;
      input_ids[pos] = SP_TOK_P;
      attention_mask[pos] = 1;
      pos++;

      /* Tokenize parent name with ▁ prefix */
      {
	char pbuf[SP_MAX_TOKEN_LEN];
	size_t plen = strlen (blk->parent);
	if (plen + 3 >= SP_MAX_TOKEN_LEN)
	  plen = SP_MAX_TOKEN_LEN - 4;
	memcpy (pbuf, "\xe2\x96\x81", 3);
	for (size_t ci = 0; ci < plen; ci++)
	  pbuf[3 + ci] = (blk->parent[ci] >= 'A' && blk->parent[ci] <= 'Z')
	    ? blk->parent[ci] + 32 : blk->parent[ci];
	pbuf[3 + plen] = 0;

	int64_t pids[32];
	int pn = sp_tokenize_word (pbuf, 3 + plen, pids, 32);
	for (int j = 0; j < pn && pos < max_seq - 3; j++)
	  {
	    input_ids[pos] = pids[j];
	    attention_mask[pos] = 1;
	    pos++;
	  }
      }

      /* Emit [DESCRIPTION] tokens for each field that has a description.
	 Python: prompt_str += f" [DESCRIPTION] {label}: {desc}"
	 Tokenized as: [DESCRIPTION](128010) ▁Label : ▁description ▁words ... */
      if (blk->descriptions)
	{
	  for (int fi = 0; fi < blk->num_fields && pos < max_seq - 10; fi++)
	    {
	      if (!blk->descriptions[fi] || !blk->descriptions[fi][0])
		continue;

	      /* [DESCRIPTION] token */
	      input_ids[pos] = SP_TOK_DESC;
	      attention_mask[pos] = 1;
	      pos++;

	      /* Tokenize "▁Label" (field name with ▁ prefix) */
	      char dbuf[SP_MAX_TOKEN_LEN];
	      size_t dlen = strlen (blk->fields[fi]);
	      if (dlen + 3 >= SP_MAX_TOKEN_LEN)
		dlen = SP_MAX_TOKEN_LEN - 4;
	      memcpy (dbuf, "\xe2\x96\x81", 3);
	      memcpy (dbuf + 3, blk->fields[fi], dlen);
	      dbuf[3 + dlen] = 0;

	      int64_t dids[32];
	      int dn = sp_tokenize_word (dbuf, 3 + dlen, dids, 32);
	      for (int j = 0; j < dn && pos < max_seq - 5; j++)
		{
		  input_ids[pos] = dids[j];
		  attention_mask[pos] = 1;
		  pos++;
		}

	      /* Colon ":" token (token ID 294 in DeBERTa vocab) */
	      {
		char cbuf[8];
		memcpy (cbuf, ":", 2);
		int32_t cid = sp_lookup (cbuf, 1);
		input_ids[pos] = (cid >= 0) ? cid : SP_TOK_UNK;
		attention_mask[pos] = 1;
		pos++;
	      }

	      /* Tokenize description text as space-separated words with ▁ prefix */
	      {
		const char *dp = blk->descriptions[fi];
		size_t dp_len = strlen (dp);
		const char *dp_end = dp + dp_len;
		while (dp < dp_end && pos < max_seq - 5)
		  {
		    /* Skip whitespace */
		    while (dp < dp_end && (*dp == ' ' || *dp == '\t'))
		      dp++;
		    if (dp >= dp_end)
		      break;
		    /* Find end of word */
		    const char *ws = dp;
		    while (dp < dp_end && *dp != ' ' && *dp != '\t')
		      dp++;
		    size_t wlen = dp - ws;
		    if (wlen == 0)
		      continue;

		    char wbuf[SP_MAX_TOKEN_LEN];
		    if (wlen + 3 >= SP_MAX_TOKEN_LEN)
		      wlen = SP_MAX_TOKEN_LEN - 4;
		    memcpy (wbuf, "\xe2\x96\x81", 3);
		    for (size_t ci = 0; ci < wlen; ci++)
		      wbuf[3 + ci] = (ws[ci] >= 'A' && ws[ci] <= 'Z')
			? ws[ci] + 32 : ws[ci];
		    wbuf[3 + wlen] = 0;

		    int64_t wids[16];
		    int wn = sp_tokenize_word (wbuf, 3 + wlen, wids, 16);
		    for (int j = 0; j < wn && pos < max_seq - 5; j++)
		      {
			input_ids[pos] = wids[j];
			attention_mask[pos] = 1;
			pos++;
		      }
		  }
	      }
	    }
	}

      input_ids[pos] = SP_PAREN_OPEN;
      attention_mask[pos] = 1;
      pos++;

      /* For each field: [X] field_tokens */
      for (int fi = 0; fi < blk->num_fields && pos < max_seq - 3; fi++)
	{
	  input_ids[pos] = blk->child_tok;
	  attention_mask[pos] = 1;
	  if (schema_label_indices)
	    schema_label_indices[total_fields] = pos;
	  total_fields++;
	  pos++;

	  /* Tokenize field name with ▁ prefix */
	  char lbuf[SP_MAX_TOKEN_LEN];
	  size_t llen = strlen (blk->fields[fi]);
	  if (llen + 3 >= SP_MAX_TOKEN_LEN)
	    llen = SP_MAX_TOKEN_LEN - 4;
	  memcpy (lbuf, "\xe2\x96\x81", 3);
	  for (size_t ci = 0; ci < llen; ci++)
	    lbuf[3 + ci] = (blk->fields[fi][ci] >= 'A' && blk->fields[fi][ci] <= 'Z')
	      ? blk->fields[fi][ci] + 32 : blk->fields[fi][ci];
	  lbuf[3 + llen] = 0;

	  int64_t fids[16];
	  int fn = sp_tokenize_word (lbuf, 3 + llen, fids, 16);
	  for (int j = 0; j < fn && pos < max_seq - 3; j++)
	    {
	      input_ids[pos] = fids[j];
	      attention_mask[pos] = 1;
	      pos++;
	    }
	}

      /* Close: ) ) */
      if (pos < max_seq - 2)
	{
	  input_ids[pos] = SP_PAREN_CLOSE;
	  attention_mask[pos] = 1;
	  pos++;
	  input_ids[pos] = SP_PAREN_CLOSE;
	  attention_mask[pos] = 1;
	  pos++;
	}
    }

  *num_total_fields_out = total_fields;

  /* [SEP_TEXT] */
  if (pos < max_seq)
    {
      input_ids[pos] = SP_TOK_SEP_TEXT;
      attention_mask[pos] = 1;
      pos++;
    }

  /* Text tokens (same logic as gliner2_build_entity_input) */
  *text_start_idx_out = pos;
  int num_text_words = 0;

  {
    char *lower = (char *) malloc (text_len + 1);
    if (!lower)
      {
	*num_text_words_out = 0;
	return pos;
      }
    for (size_t ci = 0; ci < text_len; ci++)
      lower[ci] = (text[ci] >= 'A' && text[ci] <= 'Z') ? text[ci] + 32 : text[ci];
    lower[text_len] = 0;

    size_t ti = 0;
    while (ti < text_len && pos < max_seq && num_text_words < GLINER2_MAX_TEXT_TOKENS)
      {
	while (ti < text_len && (lower[ti] == ' ' || lower[ti] == '\t' || lower[ti] == '\n' || lower[ti] == '\r'))
	  ti++;
	if (ti >= text_len)
	  break;

	size_t wstart = ti;
	if (wp_is_punct ((unsigned char) lower[ti]))
	  ti++;
	else
	  while (ti < text_len && lower[ti] != ' ' && lower[ti] != '\t' &&
		 lower[ti] != '\n' && lower[ti] != '\r' &&
		 !wp_is_punct ((unsigned char) lower[ti]))
	    ti++;
	size_t wlen = ti - wstart;

	start_map[num_text_words] = (int) wstart;
	end_map[num_text_words] = (int) (wstart + wlen);

	char buf[SP_MAX_TOKEN_LEN];
	size_t blen = 3 + wlen;
	if (blen >= SP_MAX_TOKEN_LEN)
	  blen = SP_MAX_TOKEN_LEN - 1;
	memcpy (buf, "\xe2\x96\x81", 3);
	memcpy (buf + 3, lower + wstart, blen - 3);
	buf[blen] = 0;

	int64_t wids[64];
	int n = sp_tokenize_word (buf, blen, wids, 64);

	text_token_indices[num_text_words] = pos;

	for (int j = 0; j < n && pos < max_seq; j++)
	  {
	    input_ids[pos] = wids[j];
	    attention_mask[pos] = 1;
	    pos++;
	  }
	num_text_words++;
      }
    free (lower);
  }

  *num_text_words_out = num_text_words;

  /* Pad remaining */
  while (pos < max_seq)
    {
      input_ids[pos] = 0;
      attention_mask[pos] = 0;
      pos++;
    }

  return pos;
}

/* ---------- GLiNER2 ONNX inference pipeline ---------- */

/* Run encoder: input_ids[1,seq] + attention_mask[1,seq] -> hidden[1,seq,H] */
static float *
gliner2_run_encoder (const OrtApi *api, int64_t *input_ids, int64_t *attention_mask,
		     int seq_len, int *out_hidden_size)
{
  if (!g_gl2_encoder)
    return NULL;

  int64_t shape[2] = { 1, (int64_t) seq_len };
  OrtMemoryInfo *mem = NULL;
  if (check_status_soft (api, api->CreateCpuMemoryInfo (OrtArenaAllocator, OrtMemTypeDefault, &mem), "gl2 CreateCpuMemoryInfo"))
    return NULL;

  OrtValue *inputs[2] = { NULL, NULL };
  if (check_status_soft (api, api->CreateTensorWithDataAsOrtValue (mem, input_ids, seq_len * sizeof (int64_t), shape, 2, ONNX_TENSOR_ELEMENT_DATA_TYPE_INT64, &inputs[0]), "gl2 CreateTensor ids"))
    { api->ReleaseMemoryInfo (mem); return NULL; }
  if (check_status_soft (api, api->CreateTensorWithDataAsOrtValue (mem, attention_mask, seq_len * sizeof (int64_t), shape, 2, ONNX_TENSOR_ELEMENT_DATA_TYPE_INT64, &inputs[1]), "gl2 CreateTensor mask"))
    { api->ReleaseMemoryInfo (mem); api->ReleaseValue (inputs[0]); return NULL; }
  api->ReleaseMemoryInfo (mem);

  const char *in_names[2] = { "input_ids", "attention_mask" };
  const char *out_names[1] = { "last_hidden_state" };
  OrtValue *output = NULL;
  if (check_status_soft (api, api->Run (g_gl2_encoder, NULL, in_names, (const OrtValue *const *) inputs, 2, out_names, 1, &output), "gl2 encoder Run"))
    { api->ReleaseValue (inputs[0]); api->ReleaseValue (inputs[1]); return NULL; }
  api->ReleaseValue (inputs[0]);
  api->ReleaseValue (inputs[1]);

  /* Get output data */
  float *data = NULL;
  if (check_status_soft (api, api->GetTensorMutableData (output, (void **) &data), "gl2 encoder GetData"))
    { api->ReleaseValue (output); return NULL; }

  OrtTensorTypeAndShapeInfo *info = NULL;
  if (check_status_soft (api, api->GetTensorTypeAndShape (output, &info), "gl2 encoder GetShape"))
    { api->ReleaseValue (output); return NULL; }
  size_t dim_count = 0;
  check_status (api, api->GetDimensionsCount (info, &dim_count), "gl2 encoder GetDimsCount");
  /* dim_count comes from the model, and GetDimensions writes that many int64_t
     into an array of four.  This reads dims[1] and dims[2], so rank 3 --
     [batch, seq, hidden] -- is not merely the expected shape but the only one
     the arithmetic below is correct for: rank 5 would write off the end, and
     rank 2 would read the zero from the initialiser and copy nothing.  Refuse
     rather than widen; the callers all handle NULL, and check_status's fail()
     would kill the helper over what is only a wrongly-shaped model.  */
  if (dim_count != 3)
    {
      fprintf (stderr, "ONNX soft error [gl2 encoder]: expected a rank-3 "
	  "output [batch, seq, hidden], got rank %lu\n", (unsigned long) dim_count);
      api->ReleaseTensorTypeAndShapeInfo (info);
      api->ReleaseValue (output);
      return NULL;
    }
  int64_t dims[4] = { 0 };
  check_status (api, api->GetDimensions (info, dims, dim_count), "gl2 encoder GetDims");
  api->ReleaseTensorTypeAndShapeInfo (info);

  *out_hidden_size = (int) dims[2];
  size_t total = (size_t) dims[1] * (size_t) dims[2];
  float *result = (float *) malloc (total * sizeof (float));
  if (result)
    memcpy (result, data, total * sizeof (float));
  api->ReleaseValue (output);
  return result;
}

/* Run span_rep: token_embs[1,N,H] + span_indices[1,N*W,2] -> span_rep[1,N*W,H] */
static float *
gliner2_run_span_rep (const OrtApi *api, float *token_embs, int num_tokens,
		      int hidden_size)
{
  if (!g_gl2_span_rep)
    return NULL;

  /* Build span indices */
  int num_spans = num_tokens * GLINER2_MAX_WIDTH;
  int64_t *span_idx = (int64_t *) calloc (num_spans * 2, sizeof (int64_t));
  if (!span_idx)
    return NULL;

  for (int i = 0; i < num_tokens; i++)
    for (int j = 0; j < GLINER2_MAX_WIDTH; j++)
      {
	int si = i * GLINER2_MAX_WIDTH + j;
	if (i + j < num_tokens)
	  {
	    span_idx[si * 2] = i;
	    span_idx[si * 2 + 1] = i + j;
	  }
	/* else stays 0,0 (padding) */
      }

  int64_t emb_shape[3] = { 1, (int64_t) num_tokens, (int64_t) hidden_size };
  int64_t idx_shape[3] = { 1, (int64_t) num_spans, 2 };

  OrtMemoryInfo *mem = NULL;
  if (check_status_soft (api, api->CreateCpuMemoryInfo (OrtArenaAllocator, OrtMemTypeDefault, &mem), "gl2 span CreateMem"))
    { free (span_idx); return NULL; }

  OrtValue *inputs[2] = { NULL, NULL };
  if (check_status_soft (api, api->CreateTensorWithDataAsOrtValue (mem, token_embs, (size_t) num_tokens * hidden_size * sizeof (float), emb_shape, 3, ONNX_TENSOR_ELEMENT_DATA_TYPE_FLOAT, &inputs[0]), "gl2 span CreateTensor embs"))
    { api->ReleaseMemoryInfo (mem); free (span_idx); return NULL; }
  if (check_status_soft (api, api->CreateTensorWithDataAsOrtValue (mem, span_idx, (size_t) num_spans * 2 * sizeof (int64_t), idx_shape, 3, ONNX_TENSOR_ELEMENT_DATA_TYPE_INT64, &inputs[1]), "gl2 span CreateTensor idx"))
    { api->ReleaseMemoryInfo (mem); api->ReleaseValue (inputs[0]); free (span_idx); return NULL; }
  api->ReleaseMemoryInfo (mem);

  const char *in_names[2] = { "token_embs", "span_indices" };
  const char *out_names[1] = { "span_rep" };
  OrtValue *output = NULL;
  if (check_status_soft (api, api->Run (g_gl2_span_rep, NULL, in_names, (const OrtValue *const *) inputs, 2, out_names, 1, &output), "gl2 span Run"))
    { api->ReleaseValue (inputs[0]); api->ReleaseValue (inputs[1]); free (span_idx); return NULL; }
  api->ReleaseValue (inputs[0]);
  api->ReleaseValue (inputs[1]);
  free (span_idx);

  float *data = NULL;
  if (check_status_soft (api, api->GetTensorMutableData (output, (void **) &data), "gl2 span GetData"))
    { api->ReleaseValue (output); return NULL; }
  size_t total = (size_t) num_spans * hidden_size;
  float *result = (float *) malloc (total * sizeof (float));
  if (result)
    memcpy (result, data, total * sizeof (float));
  api->ReleaseValue (output);
  return result;
}

/* Run count_pred: label_emb[1,H] -> count_logits[1,20] -> argmax -> predicted count */
static int
gliner2_run_count_pred (const OrtApi *api, float *label_emb, int hidden_size)
{
  if (!g_gl2_count_pred)
    return 1;			/* default to 1 if model not loaded */

  int64_t shape[2] = { 1, (int64_t) hidden_size };
  OrtMemoryInfo *mem = NULL;
  if (check_status_soft (api, api->CreateCpuMemoryInfo (OrtArenaAllocator, OrtMemTypeDefault, &mem), "gl2 cp CreateMem"))
    return -1;

  OrtValue *input = NULL;
  if (check_status_soft (api, api->CreateTensorWithDataAsOrtValue (mem, label_emb, (size_t) hidden_size * sizeof (float), shape, 2, ONNX_TENSOR_ELEMENT_DATA_TYPE_FLOAT, &input), "gl2 cp CreateTensor"))
    { api->ReleaseMemoryInfo (mem); return -1; }
  api->ReleaseMemoryInfo (mem);

  const char *in_names[1] = { "label_emb" };
  const char *out_names[1] = { "count_logits" };
  OrtValue *output = NULL;
  if (check_status_soft (api, api->Run (g_gl2_count_pred, NULL, in_names, (const OrtValue *const *) &input, 1, out_names, 1, &output), "gl2 cp Run"))
    { api->ReleaseValue (input); return -1; }
  api->ReleaseValue (input);

  float *data = NULL;
  if (check_status_soft (api, api->GetTensorMutableData (output, (void **) &data), "gl2 cp GetData"))
    { api->ReleaseValue (output); return -1; }
  /* argmax over 20 classes */
  int best = 0;
  float best_val = data[0];
  for (int i = 1; i < 20; i++)
    if (data[i] > best_val)
      {
	best = i;
	best_val = data[i];
      }
  api->ReleaseValue (output);
  return best;
}

/* Run count_embed: pc_emb[M,H] + gold_count(scalar) -> struct_proj[count,M,H]
   Note: M must always be GLINER2_COUNT_EMBED_SLOTS (4). */
#define GLINER2_COUNT_EMBED_SLOTS 4
static float *
gliner2_run_count_embed (const OrtApi *api, float *pc_emb, int num_embs,
			 int gold_count, int hidden_size, int *out_count)
{
  if (!g_gl2_count_embed)
    return NULL;

  int64_t emb_shape[2] = { (int64_t) num_embs, (int64_t) hidden_size };
  int64_t count_val = (int64_t) gold_count;

  OrtMemoryInfo *mem = NULL;
  if (check_status_soft (api, api->CreateCpuMemoryInfo (OrtArenaAllocator, OrtMemTypeDefault, &mem), "gl2 ce CreateMem"))
    return NULL;

  OrtValue *inputs[2] = { NULL, NULL };
  if (check_status_soft (api, api->CreateTensorWithDataAsOrtValue (mem, pc_emb, (size_t) num_embs * hidden_size * sizeof (float), emb_shape, 2, ONNX_TENSOR_ELEMENT_DATA_TYPE_FLOAT, &inputs[0]), "gl2 ce CreateTensor emb"))
    { api->ReleaseMemoryInfo (mem); return NULL; }
  /* gold_count is a scalar int64 */
  int64_t scalar_shape[1] = { 0 };	/* 0-dim = scalar */
  if (check_status_soft (api, api->CreateTensorWithDataAsOrtValue (mem, &count_val, sizeof (int64_t), scalar_shape, 0, ONNX_TENSOR_ELEMENT_DATA_TYPE_INT64, &inputs[1]), "gl2 ce CreateTensor count"))
    { api->ReleaseMemoryInfo (mem); api->ReleaseValue (inputs[0]); return NULL; }
  api->ReleaseMemoryInfo (mem);

  const char *in_names[2] = { "pc_emb", "gold_count" };
  const char *out_names[1] = { "struct_proj" };
  OrtValue *output = NULL;
  if (check_status_soft (api, api->Run (g_gl2_count_embed, NULL, in_names, (const OrtValue *const *) inputs, 2, out_names, 1, &output), "gl2 ce Run"))
    { api->ReleaseValue (inputs[0]); api->ReleaseValue (inputs[1]); return NULL; }
  api->ReleaseValue (inputs[0]);
  api->ReleaseValue (inputs[1]);

  float *data = NULL;
  if (check_status_soft (api, api->GetTensorMutableData (output, (void **) &data), "gl2 ce GetData"))
    { api->ReleaseValue (output); return NULL; }

  OrtTensorTypeAndShapeInfo *info = NULL;
  if (check_status_soft (api, api->GetTensorTypeAndShape (output, &info), "gl2 ce GetShape"))
    { api->ReleaseValue (output); return NULL; }
  size_t dim_count = 0;
  check_status (api, api->GetDimensionsCount (info, &dim_count), "gl2 ce GetDimsCount");
  /* Same bound as the encoder above, and for the same reason: this reads
     dims[0], dims[1] and dims[2] into a four-element array sized by the
     model.  */
  if (dim_count != 3)
    {
      fprintf (stderr, "ONNX soft error [gl2 ce]: expected a rank-3 output, "
	  "got rank %lu\n", (unsigned long) dim_count);
      api->ReleaseTensorTypeAndShapeInfo (info);
      api->ReleaseValue (output);
      return NULL;
    }
  int64_t dims[4] = { 0 };
  check_status (api, api->GetDimensions (info, dims, dim_count), "gl2 ce GetDims");
  api->ReleaseTensorTypeAndShapeInfo (info);

  *out_count = (int) dims[0];
  size_t total = (size_t) dims[0] * (size_t) dims[1] * (size_t) dims[2];
  float *result = (float *) malloc (total * sizeof (float));
  if (result)
    memcpy (result, data, total * sizeof (float));
  api->ReleaseValue (output);
  return result;
}

/* Sigmoid function */
static float
sigmoidf (float x)
{
  return 1.0f / (1.0f + expf (-x));
}

/* Simple JSON string escaping */
static int
json_escape (const char *src, size_t slen, char *dst, size_t dmax)
{
  size_t d = 0;
  for (size_t i = 0; i < slen && d < dmax - 2; i++)
    {
      char c = src[i];
      if (c == '"' || c == '\\')
	{
	  if (d + 2 >= dmax)
	    break;
	  dst[d++] = '\\';
	  dst[d++] = c;
	}
      else if (c == '\n')
	{
	  if (d + 2 >= dmax)
	    break;
	  dst[d++] = '\\';
	  dst[d++] = 'n';
	}
      else if (c == '\r')
	{
	  if (d + 2 >= dmax)
	    break;
	  dst[d++] = '\\';
	  dst[d++] = 'r';
	}
      else if (c == '\t')
	{
	  if (d + 2 >= dmax)
	    break;
	  dst[d++] = '\\';
	  dst[d++] = 't';
	}
      else
	dst[d++] = c;
    }
  dst[d] = 0;
  return (int) d;
}

/* Parse a JSON object of string pairs: {"key1":"val1", "key2":"val2", ...}
   Keys go into keys_out, values into vals_out.  Returns number of pairs parsed.
   If the input starts with '[' instead of '{', returns 0 (caller should use array parser). */
static int
parse_json_object_pairs (const char *json, size_t json_len,
			 char keys_out[][256], char vals_out[][512],
			 int max_pairs)
{
  int count = 0;
  const char *p = json;
  const char *end = json + json_len;

  /* Skip whitespace to find opening brace */
  while (p < end && (*p == ' ' || *p == '\t' || *p == '\n' || *p == '\r'))
    p++;
  if (p >= end || *p != '{')
    return 0;
  p++;

  while (p < end && count < max_pairs)
    {
      /* Skip whitespace and commas */
      while (p < end && (*p == ' ' || *p == '\t' || *p == '\n' || *p == '\r' || *p == ','))
	p++;
      if (p >= end || *p == '}')
	break;
      if (*p != '"')
	{ p++; continue; }

      /* Parse key */
      p++;
      int ki = 0;
      while (p < end && *p != '"' && ki < 255)
	{
	  if (*p == '\\' && p + 1 < end)
	    { p++; keys_out[count][ki++] = *p++; }
	  else
	    keys_out[count][ki++] = *p++;
	}
      keys_out[count][ki] = 0;
      if (p < end && *p == '"')
	p++;

      /* Skip colon */
      while (p < end && (*p == ' ' || *p == '\t' || *p == ':'))
	p++;

      /* Parse value */
      if (p >= end || *p != '"')
	{ vals_out[count][0] = 0; count++; continue; }
      p++;
      int vi = 0;
      while (p < end && *p != '"' && vi < 511)
	{
	  if (*p == '\\' && p + 1 < end)
	    { p++; vals_out[count][vi++] = *p++; }
	  else
	    vals_out[count][vi++] = *p++;
	}
      vals_out[count][vi] = 0;
      if (p < end && *p == '"')
	p++;
      count++;
    }
  return count;
}

/* Parse a simple JSON array of strings: ["label1", "label2", ...]
   Returns number of labels parsed. */
static int
parse_json_string_array (const char *json, size_t json_len,
			 char labels[][256], int max_labels)
{
  int count = 0;
  const char *p = json;
  const char *end = json + json_len;

  /* Find opening [ */
  while (p < end && *p != '[')
    p++;
  if (p >= end)
    return 0;
  p++;

  while (p < end && count < max_labels)
    {
      /* Skip whitespace */
      while (p < end && (*p == ' ' || *p == '\t' || *p == '\n' || *p == '\r' || *p == ','))
	p++;
      if (p >= end || *p == ']')
	break;
      if (*p != '"')
	{
	  p++;
	  continue;
	}
      p++;			/* skip opening quote */
      int li = 0;
      while (p < end && *p != '"' && li < 255)
	{
	  if (*p == '\\' && p + 1 < end)
	    {
	      p++;
	      labels[count][li++] = *p++;
	    }
	  else
	    labels[count][li++] = *p++;
	}
      labels[count][li] = 0;
      if (p < end && *p == '"')
	p++;
      count++;
    }
  return count;
}

/* Forward declarations for shared pipeline (defined below) */
typedef struct
{
  float *span_rep;
  float *struct_proj;
  float *text_embs;
  float *label_embs;
  int num_text_words;
  int hidden_size;
  int struct_count;
  int total_P;
  int start_map[GLINER2_MAX_TEXT_TOKENS];
  int end_map[GLINER2_MAX_TEXT_TOKENS];
} gliner2_inference_result_t;

static void gliner2_inference_free (gliner2_inference_result_t *r);
static int gliner2_run_pipeline (const OrtApi *api,
				 const char *text, size_t text_len,
				 gliner2_schema_block_t *blocks, int num_blocks,
				 int *schema_label_indices, int *block_field_offsets,
				 int num_total_fields,
				 gliner2_inference_result_t *result,
				 char **err_out);

/* Process a GLiNER2 entity extraction request.
   Accepts either JSON array: ["Person","Location"]
   or JSON object with descriptions: {"Person":"Names of people","Location":"Countries or cities"}
   Returns a JSON string with the results. */
static char *
gliner2_extract_entities (const OrtApi *api,
			  const char *text, size_t text_len,
			  const char *schema_json, size_t schema_len,
			  float threshold)
{
  /* Parse labels from schema JSON — detect array vs object format */
  char labels[GLINER2_MAX_LABELS][256];
  char descs[GLINER2_MAX_LABELS][512];
  int num_labels = 0;
  int has_descs = 0;

  /* Try object format first: {"Person":"Names of people",...} */
  num_labels = parse_json_object_pairs (schema_json, schema_len, labels, descs, GLINER2_MAX_LABELS);
  if (num_labels > 0)
    has_descs = 1;
  else
    /* Fall back to array format: ["Person","Location",...] */
    num_labels = parse_json_string_array (schema_json, schema_len, labels, GLINER2_MAX_LABELS);

  if (num_labels == 0)
    return strdup ("{\"entities\":{}}");

  const char *label_ptrs[GLINER2_MAX_LABELS];
  const char *desc_ptrs[GLINER2_MAX_LABELS];
  for (int i = 0; i < num_labels; i++)
    {
      label_ptrs[i] = labels[i];
      desc_ptrs[i] = has_descs ? descs[i] : NULL;
    }

  /* Build single schema block: ( [P] entities [DESC]... ( [E] label1 [E] label2 ... ) ) */
  gliner2_schema_block_t block;
  block.parent = "entities";
  block.child_tok = SP_TOK_E;
  block.fields = label_ptrs;
  block.descriptions = has_descs ? desc_ptrs : NULL;
  block.num_fields = num_labels;

  int schema_label_indices[GLINER2_MAX_LABELS];
  int block_field_offsets[1];
  memset (schema_label_indices, 0, sizeof (schema_label_indices));

  gliner2_inference_result_t res;
  memset (&res, 0, sizeof (res));
  char *err = NULL;

  if (gliner2_run_pipeline (api, text, text_len, &block, 1,
			    schema_label_indices, block_field_offsets,
			    num_labels, &res, &err))
    return err ? err : strdup ("{\"error\":\"pipeline failed\"}");

  /* Build JSON output */
  char *json = (char *) malloc (GLINER2_MAX_JSON);
  if (!json)
    { gliner2_inference_free (&res); return strdup ("{\"error\":\"OOM\"}"); }
  int jpos = 0;
  size_t jmax = GLINER2_MAX_JSON;
#define JSON_APPEND(fmt, ...) do { \
  if (jpos < (int)jmax - 1) { \
    int n = snprintf(json + jpos, jmax - jpos, fmt, ##__VA_ARGS__); \
    if (n > 0) jpos += n; \
    if (jpos >= (int)jmax - 1) { \
      gliner2_inference_free(&res); free(json); \
      return strdup("{\"error\":\"JSON buffer overflow\"}"); \
    } \
  } \
} while(0)

  JSON_APPEND ("{\"entities\":{");

  if (res.struct_proj && res.struct_count > 0)
    {
      int L = res.num_text_words;
      int K = GLINER2_MAX_WIDTH;
      int P = res.total_P;
      int H = res.hidden_size;

      for (int li = 0; li < num_labels; li++)
	{
	  if (li > 0)
	    JSON_APPEND (",");

	  char esc_label[512];
	  json_escape (labels[li], strlen (labels[li]), esc_label, sizeof (esc_label));
	  JSON_APPEND ("\"%s\":[", esc_label);

	  int pi = li;
	  if (pi >= P)
	    { JSON_APPEND ("]"); continue; }

	  int first_entity = 1;
	  for (int l = 0; l < L; l++)
	    for (int k = 0; k < K && l + k < L; k++)
	      {
		float dot = 0.0f;
		for (int d = 0; d < H; d++)
		  dot += res.span_rep[(l * K + k) * H + d]
		    * res.struct_proj[(0 * P + pi) * H + d];
		float score = sigmoidf (dot);
		if (score >= threshold)
		  {
		    int char_start = res.start_map[l];
		    int char_end = res.end_map[l + k];
		    if (char_start >= 0 && char_end > char_start && (size_t) char_end <= text_len)
		      {
			char span_text[1024];
			int slen = char_end - char_start;
			if (slen > 1023) slen = 1023;
			memcpy (span_text, text + char_start, slen);
			span_text[slen] = 0;
			while (slen > 0 && (span_text[slen - 1] == ' ' || span_text[slen - 1] == '\t'))
			  span_text[--slen] = 0;
			int trim_start = 0;
			while (trim_start < slen && (span_text[trim_start] == ' ' || span_text[trim_start] == '\t'))
			  trim_start++;
			if (slen - trim_start > 0)
			  {
			    if (!first_entity) JSON_APPEND (",");
			    char esc_span[2048];
			    json_escape (span_text + trim_start, slen - trim_start, esc_span, sizeof (esc_span));
			    JSON_APPEND ("{\"text\":\"%s\",\"score\":%.4f,\"start\":%d,\"end\":%d}",
					 esc_span, score, char_start + trim_start, char_end);
			    first_entity = 0;
			  }
		      }
		  }
	      }
	  JSON_APPEND ("]");
	}
    }
  else
    {
      /* No entities predicted — emit empty arrays for each label */
      for (int li = 0; li < num_labels; li++)
	{
	  if (li > 0) JSON_APPEND (",");
	  char esc_label[512];
	  json_escape (labels[li], strlen (labels[li]), esc_label, sizeof (esc_label));
	  JSON_APPEND ("\"%s\":[]", esc_label);
	}
    }

  JSON_APPEND ("}}");
  json[jpos] = 0;
#undef JSON_APPEND

  gliner2_inference_free (&res);
  return json;
}

/* ---------- Shared inference pipeline ---------- */

static void
gliner2_inference_free (gliner2_inference_result_t *r)
{
  free (r->span_rep);
  free (r->struct_proj);
  free (r->text_embs);
  free (r->label_embs);
}

/* Run the shared inference pipeline: encoder → span_rep → count_pred → count_embed.
   Returns 0 on success, -1 on error (writes error JSON to *err_out). */
static int
gliner2_run_pipeline (const OrtApi *api,
		      const char *text, size_t text_len,
		      gliner2_schema_block_t *blocks, int num_blocks,
		      int *schema_label_indices, int *block_field_offsets,
		      int num_total_fields,
		      gliner2_inference_result_t *result,
		      char **err_out)
{
  int64_t input_ids[GLINER2_MAX_SEQ];
  int64_t attention_mask[GLINER2_MAX_SEQ];
  int text_token_indices[GLINER2_MAX_TEXT_TOKENS];
  int text_start_idx = 0, num_text_words = 0;
  int num_fields_out = 0;

  memset (input_ids, 0, sizeof (input_ids));
  memset (attention_mask, 0, sizeof (attention_mask));

  int seq_len = gliner2_build_schema_input (text, text_len,
					    blocks, num_blocks,
					    input_ids, attention_mask,
					    GLINER2_MAX_SEQ,
					    text_token_indices, &text_start_idx,
					    result->start_map, result->end_map,
					    &num_text_words,
					    schema_label_indices,
					    block_field_offsets,
					    &num_fields_out);

  result->num_text_words = num_text_words;

  /* Find actual sequence length */
  int actual_seq = 0;
  for (int i = seq_len - 1; i >= 0; i--)
    if (attention_mask[i])
      { actual_seq = i + 1; break; }
  if (actual_seq == 0)
    { *err_out = strdup ("{\"error\":\"empty sequence\"}"); return -1; }

  /* Run encoder */
  int hidden_size = 0;
  float *hidden = gliner2_run_encoder (api, input_ids, attention_mask, actual_seq, &hidden_size);
  if (!hidden)
    { *err_out = strdup ("{\"error\":\"encoder failed\"}"); return -1; }
  g_gl2_hidden_size = hidden_size;
  result->hidden_size = hidden_size;

  /* Extract text token embeddings */
  float *text_embs = (float *) malloc ((size_t) num_text_words * hidden_size * sizeof (float));
  if (!text_embs)
    { free (hidden); *err_out = strdup ("{\"error\":\"OOM\"}"); return -1; }
  for (int w = 0; w < num_text_words; w++)
    memcpy (text_embs + (size_t) w * hidden_size,
	    hidden + (size_t) text_token_indices[w] * hidden_size,
	    hidden_size * sizeof (float));
  result->text_embs = text_embs;

  /* Extract [P] embedding (position 1) for count_pred */
  float *p_emb = (float *) malloc ((size_t) hidden_size * sizeof (float));
  if (!p_emb)
    { free (hidden); free (text_embs); *err_out = strdup ("{\"error\":\"OOM\"}"); return -1; }
  memcpy (p_emb, hidden + (size_t) 1 * hidden_size, hidden_size * sizeof (float));

  /* Extract child token embeddings at schema_label_indices */
  float *label_embs = (float *) malloc ((size_t) num_total_fields * hidden_size * sizeof (float));
  if (!label_embs)
    { free (hidden); free (text_embs); free (p_emb); *err_out = strdup ("{\"error\":\"OOM\"}"); return -1; }
  for (int i = 0; i < num_total_fields; i++)
    memcpy (label_embs + (size_t) i * hidden_size,
	    hidden + (size_t) schema_label_indices[i] * hidden_size,
	    hidden_size * sizeof (float));
  free (hidden);
  result->label_embs = label_embs;

  /* Run span_rep */
  float *span_rep = gliner2_run_span_rep (api, text_embs, num_text_words, hidden_size);
  if (!span_rep)
    { free (text_embs); free (label_embs); free (p_emb); *err_out = strdup ("{\"error\":\"span_rep failed\"}"); return -1; }
  result->span_rep = span_rep;

  /* count_pred */
  int pred_count = gliner2_run_count_pred (api, p_emb, hidden_size);
  free (p_emb);
  if (pred_count <= 0)
    {
      result->struct_proj = NULL;
      result->struct_count = 0;
      result->total_P = 0;
      return 0;  /* success but no entities predicted */
    }

  /* count_embed in batches of GLINER2_COUNT_EMBED_SLOTS */
  int slots = GLINER2_COUNT_EMBED_SLOTS;
  int num_batches = (num_total_fields + slots - 1) / slots;
  float *struct_proj = NULL;
  int struct_count = 0;
  int total_P = 0;

  for (int bi = 0; bi < num_batches; bi++)
    {
      int batch_start = bi * slots;
      int batch_nlabels = num_total_fields - batch_start;
      if (batch_nlabels > slots)
	batch_nlabels = slots;

      float *batch_embs = (float *) calloc ((size_t) slots * hidden_size, sizeof (float));
      if (!batch_embs)
	{ free (struct_proj); *err_out = strdup ("{\"error\":\"OOM\"}"); return -1; }
      memcpy (batch_embs, label_embs + (size_t) batch_start * hidden_size,
	      (size_t) batch_nlabels * hidden_size * sizeof (float));

      int batch_count = 0;
      float *batch_proj = gliner2_run_count_embed (api, batch_embs, slots,
						   pred_count, hidden_size, &batch_count);
      free (batch_embs);

      if (!batch_proj)
	{ free (struct_proj); *err_out = strdup ("{\"error\":\"count_embed failed\"}"); return -1; }

      if (bi == 0)
	{
	  struct_proj = batch_proj;
	  struct_count = batch_count;
	  total_P = slots;
	}
      else
	{
	  int new_P = total_P + slots;
	  float *merged = (float *) malloc ((size_t) struct_count * new_P * hidden_size * sizeof (float));
	  if (!merged)
	    { free (batch_proj); free (struct_proj); *err_out = strdup ("{\"error\":\"OOM\"}"); return -1; }
	  for (int b = 0; b < struct_count; b++)
	    {
	      memcpy (merged + (size_t) b * new_P * hidden_size,
		      struct_proj + (size_t) b * total_P * hidden_size,
		      (size_t) total_P * hidden_size * sizeof (float));
	      memcpy (merged + (size_t) (b * new_P + total_P) * hidden_size,
		      batch_proj + (size_t) b * slots * hidden_size,
		      (size_t) slots * hidden_size * sizeof (float));
	    }
	  free (struct_proj);
	  free (batch_proj);
	  struct_proj = merged;
	  total_P = new_P;
	}
    }

  result->struct_proj = struct_proj;
  result->struct_count = struct_count;
  result->total_P = total_P;
  return 0;
}

/* ---------- Relation extraction ---------- */

/* Parse relation names from JSON array: ["works_for","located_in","acquired"]
   Returns number of relations parsed. */
static char *
gliner2_extract_relations (const OrtApi *api,
			   const char *text, size_t text_len,
			   const char *schema_json, size_t schema_len,
			   float threshold)
{
  /* Parse relation names — detect array vs object format.
     Array: ["works_for","located_in"]
     Object: {"works_for":"A person works for a company","located_in":"Located in a place"} */
  char rel_names[GLINER2_MAX_LABELS][256];
  char rel_descs[GLINER2_MAX_LABELS][512];
  int num_rels = 0;
  int has_descs = 0;

  num_rels = parse_json_object_pairs (schema_json, schema_len, rel_names, rel_descs, GLINER2_MAX_LABELS);
  if (num_rels > 0)
    has_descs = 1;
  else
    num_rels = parse_json_string_array (schema_json, schema_len, rel_names, GLINER2_MAX_LABELS);

  if (num_rels == 0)
    return strdup ("{\"relations\":{}}");

  /* Each relation becomes a schema block with [R] token and fields "head","tail".
     For relations, the description goes on the parent (relation name) block.
     Python puts the description in the [P] prompt for the relation block. */
  gliner2_schema_block_t blocks[GLINER2_MAX_LABELS];
  const char *head_tail[2] = { "head", "tail" };
  /* For relation descriptions, we store the single description as a 2-element array
     (one per field: head, tail) but since the description applies to the relation
     itself (the [P] parent), we need a different approach.  Actually, looking at the
     Python code, relation descriptions are NOT passed to _transform_schema — relations
     use the relation name as parent and "head","tail" as fields with no descriptions.
     The description is part of the relation name prompt in the Python API but not
     passed as label_descriptions.  So we skip descriptions for relations for now. */
  for (int i = 0; i < num_rels; i++)
    {
      blocks[i].parent = rel_names[i];
      blocks[i].child_tok = SP_TOK_R;
      blocks[i].fields = head_tail;
      blocks[i].descriptions = NULL;
      blocks[i].num_fields = 2;
    }

  int schema_label_indices[GLINER2_MAX_LABELS * 2];
  int block_field_offsets[GLINER2_MAX_LABELS];
  int num_total_fields = 0;

  memset (schema_label_indices, 0, sizeof (schema_label_indices));
  memset (block_field_offsets, 0, sizeof (block_field_offsets));

  gliner2_inference_result_t res;
  memset (&res, 0, sizeof (res));
  char *err = NULL;

  if (gliner2_run_pipeline (api, text, text_len, blocks, num_rels,
			    schema_label_indices, block_field_offsets,
			    num_rels * 2, &res, &err))
    return err ? err : strdup ("{\"error\":\"pipeline failed\"}");

  if (!res.struct_proj || res.struct_count == 0)
    {
      gliner2_inference_free (&res);
      /* Return empty relations */
      char *json = (char *) malloc (GLINER2_MAX_JSON);
      if (!json)
	return strdup ("{\"error\":\"OOM\"}");
      int jpos = 0;
      jpos += snprintf (json, GLINER2_MAX_JSON, "{\"relations\":{");
      for (int ri = 0; ri < num_rels; ri++)
	{
	  if (ri > 0)
	    json[jpos++] = ',';
	  char esc[512];
	  json_escape (rel_names[ri], strlen (rel_names[ri]), esc, sizeof (esc));
	  jpos += snprintf (json + jpos, GLINER2_MAX_JSON - jpos, "\"%s\":[]", esc);
	}
      jpos += snprintf (json + jpos, GLINER2_MAX_JSON - jpos, "}}");
      return json;
    }

  /* Score spans and extract (head, tail) pairs per relation.
     struct_proj has shape [B, P, H] where B=struct_count (predicted instance count),
     P=total_P (total field slots), H=hidden_size.
     Python iterates: for inst in range(count): scores = span_scores[inst, :, -text_len:]
     For each instance b, find best head span and best tail span (matching Python spans[0]).
     Deduplicate across instances by head+tail text. */
  int L = res.num_text_words;
  int K = GLINER2_MAX_WIDTH;
  int P = res.total_P;
  int H = res.hidden_size;
  int B = res.struct_count;

  char *json = (char *) malloc (GLINER2_MAX_JSON);
  if (!json)
    {
      gliner2_inference_free (&res);
      return strdup ("{\"error\":\"OOM\"}");
    }
  int jpos = 0;
  size_t jmax = GLINER2_MAX_JSON;
#define REL_APPEND(fmt, ...) do { \
  if (jpos < (int)jmax - 1) { \
    int n = snprintf(json + jpos, jmax - jpos, fmt, ##__VA_ARGS__); \
    if (n > 0) jpos += n; \
  } \
} while(0)

  REL_APPEND ("{\"relations\":{");

  for (int ri = 0; ri < num_rels; ri++)
    {
      if (ri > 0)
	REL_APPEND (",");
      char esc_rel[512];
      json_escape (rel_names[ri], strlen (rel_names[ri]), esc_rel, sizeof (esc_rel));
      REL_APPEND ("\"%s\":[", esc_rel);

      int head_pi = block_field_offsets[ri];
      int tail_pi = block_field_offsets[ri] + 1;
      if (head_pi >= P || tail_pi >= P)
	{
	  REL_APPEND ("]");
	  continue;
	}

      int first_pair = 1;
      char seen_keys[64][256];
      int num_seen = 0;

      /* Iterate over each predicted instance (B dimension).
	 Python: for inst in range(count): scores = span_scores[inst, :, -text_len:] */
      for (int bi = 0; bi < B; bi++)
	{
	  /* For this instance, find best head span and best tail span above threshold.
	     Python: spans = self._find_spans(scores[fidx], ...); text_val = spans[0] */
	  int best_h_l = -1, best_h_k = -1;
	  float best_h_score = -1.0f;
	  int best_t_l = -1, best_t_k = -1;
	  float best_t_score = -1.0f;

	  for (int l = 0; l < L; l++)
	    for (int k = 0; k < K && l + k < L; k++)
	      {
		/* Head score: dot(span_rep[l,k,:], struct_proj[bi, head_pi, :]) */
		float dot_h = 0.0f;
		for (int d = 0; d < H; d++)
		  dot_h += res.span_rep[(l * K + k) * H + d]
		    * res.struct_proj[(bi * P + head_pi) * H + d];
		float sh = sigmoidf (dot_h);
		if (sh >= threshold && sh > best_h_score)
		  { best_h_l = l; best_h_k = k; best_h_score = sh; }

		/* Tail score: dot(span_rep[l,k,:], struct_proj[bi, tail_pi, :]) */
		float dot_t = 0.0f;
		for (int d = 0; d < H; d++)
		  dot_t += res.span_rep[(l * K + k) * H + d]
		    * res.struct_proj[(bi * P + tail_pi) * H + d];
		float st = sigmoidf (dot_t);
		if (st >= threshold && st > best_t_score)
		  { best_t_l = l; best_t_k = k; best_t_score = st; }
	      }

	  if (best_h_l < 0 || best_t_l < 0)
	    continue;

	  /* Non-overlapping check */
	  int h_end = best_h_l + best_h_k;
	  int t_end = best_t_l + best_t_k;
	  if (!(best_t_l > h_end || t_end < best_h_l))
	    continue;

	  int hcs = res.start_map[best_h_l];
	  int hce = res.end_map[h_end];
	  int tcs = res.start_map[best_t_l];
	  int tce = res.end_map[t_end];

	  if (hcs < 0 || hce <= hcs || (size_t) hce > text_len ||
	      tcs < 0 || tce <= tcs || (size_t) tce > text_len)
	    continue;

	  char head_text[512], tail_text[512];
	  int hlen = hce - hcs; if (hlen > 511) hlen = 511;
	  int tlen = tce - tcs; if (tlen > 511) tlen = 511;
	  memcpy (head_text, text + hcs, hlen); head_text[hlen] = 0;
	  memcpy (tail_text, text + tcs, tlen); tail_text[tlen] = 0;

	  /* Dedup by lowercased head|tail key */
	  char dedup_key[256];
	  int dk = 0;
	  for (int ci = 0; ci < hlen && dk < 120; ci++)
	    dedup_key[dk++] = (head_text[ci] >= 'A' && head_text[ci] <= 'Z')
	      ? head_text[ci] + 32 : head_text[ci];
	  dedup_key[dk++] = '|';
	  for (int ci = 0; ci < tlen && dk < 250; ci++)
	    dedup_key[dk++] = (tail_text[ci] >= 'A' && tail_text[ci] <= 'Z')
	      ? tail_text[ci] + 32 : tail_text[ci];
	  dedup_key[dk] = 0;

	  int is_dup = 0;
	  for (int si = 0; si < num_seen; si++)
	    if (strcmp (seen_keys[si], dedup_key) == 0)
	      { is_dup = 1; break; }

	  if (!is_dup)
	    {
	      if (num_seen < 64)
		{ memcpy (seen_keys[num_seen], dedup_key, dk + 1); num_seen++; }

	      char esc_h[1024], esc_t[1024];
	      json_escape (head_text, hlen, esc_h, sizeof (esc_h));
	      json_escape (tail_text, tlen, esc_t, sizeof (esc_t));

	      if (!first_pair)
		REL_APPEND (",");
	      REL_APPEND ("[\"%.400s\",\"%.400s\"]", esc_h, esc_t);
	      first_pair = 0;
	    }
	}
      REL_APPEND ("]");
    }

  REL_APPEND ("}}");
  json[jpos] = 0;
#undef REL_APPEND

  gliner2_inference_free (&res);
  return json;
}

/* ---------- Classification ---------- */

/* Parse classification schema: {"task":"sentiment","labels":["positive","negative","neutral"]}
   Returns task name in task_out, labels in labels_out, number of labels. */
static int
parse_classify_schema (const char *json, size_t len,
		       char *task_out, size_t task_max,
		       char labels_out[][256], int max_labels)
{
  /* Find "task":"..." */
  const char *tp = strstr (json, "\"task\"");
  if (!tp)
    return 0;
  tp = strchr (tp + 5, ':');
  if (!tp)
    return 0;
  tp++;
  while (*tp == ' ')
    tp++;
  if (*tp != '"')
    return 0;
  tp++;
  const char *te = strchr (tp, '"');
  if (!te)
    return 0;
  size_t tlen = te - tp;
  if (tlen >= task_max)
    tlen = task_max - 1;
  memcpy (task_out, tp, tlen);
  task_out[tlen] = 0;

  /* Find "labels":[...] */
  const char *lp = strstr (json, "\"labels\"");
  if (!lp)
    return 0;
  lp = strchr (lp + 8, '[');
  if (!lp)
    return 0;
  /* Find matching ] */
  const char *le = strchr (lp, ']');
  if (!le)
    return 0;
  size_t arr_len = le - lp + 1;
  return parse_json_string_array (lp, arr_len, labels_out, max_labels);
}

static char *
gliner2_classify (const OrtApi *api,
		  const char *text, size_t text_len,
		  const char *schema_json, size_t schema_len,
		  float threshold)
{
  char task_name[256];
  char cls_labels[GLINER2_MAX_LABELS][256];
  int num_labels = parse_classify_schema (schema_json, schema_len,
					  task_name, sizeof (task_name),
					  cls_labels, GLINER2_MAX_LABELS);
  if (num_labels == 0)
    return strdup ("{\"error\":\"no labels in classification schema\"}");

  /* Build single schema block: ( [P] task_name ( [L] label1 [L] label2 ... ) ) */
  const char *label_ptrs[GLINER2_MAX_LABELS];
  for (int i = 0; i < num_labels; i++)
    label_ptrs[i] = cls_labels[i];

  gliner2_schema_block_t block;
  block.parent = task_name;
  block.child_tok = SP_TOK_L;
  block.fields = label_ptrs;
  block.descriptions = NULL;
  block.num_fields = num_labels;

  int schema_label_indices[GLINER2_MAX_LABELS];
  int block_field_offsets[1];
  memset (schema_label_indices, 0, sizeof (schema_label_indices));

  gliner2_inference_result_t res;
  memset (&res, 0, sizeof (res));
  char *err = NULL;

  if (gliner2_run_pipeline (api, text, text_len, &block, 1,
			    schema_label_indices, block_field_offsets,
			    num_labels, &res, &err))
    return err ? err : strdup ("{\"error\":\"pipeline failed\"}");

  /* For classification: find the label with the highest max span score.
     Each label li has struct_proj index li. We compute max span score per label. */
  int best_label = -1;
  float best_score = -1.0f;

  if (res.struct_proj && res.struct_count > 0)
    {
      int L = res.num_text_words;
      int K = GLINER2_MAX_WIDTH;
      int P = res.total_P;
      int H = res.hidden_size;

      for (int li = 0; li < num_labels && li < P; li++)
	{
	  float max_score = 0.0f;
	  for (int l = 0; l < L; l++)
	    for (int k = 0; k < K && l + k < L; k++)
	      {
		float dot = 0.0f;
		for (int d = 0; d < H; d++)
		  dot += res.span_rep[(l * K + k) * H + d]
		    * res.struct_proj[(0 * P + li) * H + d];
		float s = sigmoidf (dot);
		if (s > max_score)
		  max_score = s;
	      }
	  if (max_score > best_score)
	    { best_score = max_score; best_label = li; }
	}
    }

  gliner2_inference_free (&res);

  char *json = (char *) malloc (2048);
  if (!json)
    return strdup ("{\"error\":\"OOM\"}");

  if (best_label >= 0)
    {
      char esc_task[512], esc_label[512];
      json_escape (task_name, strlen (task_name), esc_task, sizeof (esc_task));
      json_escape (cls_labels[best_label], strlen (cls_labels[best_label]), esc_label, sizeof (esc_label));
      snprintf (json, 2048, "{\"%s\":{\"label\":\"%s\",\"confidence\":%.4f}}", esc_task, esc_label, best_score);
    }
  else
    {
      char esc_task[512];
      json_escape (task_name, strlen (task_name), esc_task, sizeof (esc_task));
      snprintf (json, 2048, "{\"%s\":{\"label\":null,\"confidence\":0.0}}", esc_task);
    }
  return json;
}

/* ---------- JSON Structure extraction ---------- */

/* Parse structure schema: {"product":["name","price","features"]}
   Also supports field::type::description format: {"person":["name::str","gender::str::male or female"]}
   Returns structure name in struct_name_out, field names in fields_out, number of fields.
   If descs_out is non-NULL and has_descs_out is non-NULL, extracts descriptions from :: format. */
static int
parse_structure_schema (const char *json, size_t len,
			char *struct_name_out, size_t name_max,
			char fields_out[][256], char descs_out[][512],
			int *has_descs_out, int max_fields)
{
  /* Find first key: {"key":["...",...]} */
  const char *p = json;
  while (*p && *p != '"')
    p++;
  if (!*p)
    return 0;
  p++;
  const char *ke = strchr (p, '"');
  if (!ke)
    return 0;
  size_t klen = ke - p;
  if (klen >= name_max)
    klen = name_max - 1;
  memcpy (struct_name_out, p, klen);
  struct_name_out[klen] = 0;

  /* Find the array */
  const char *arr = strchr (ke, '[');
  if (!arr)
    return 0;
  const char *arr_end = strchr (arr, ']');
  if (!arr_end)
    return 0;

  /* Parse raw field strings first */
  char raw_fields[GLINER2_MAX_LABELS][256];
  int nf = parse_json_string_array (arr, arr_end - arr + 1, raw_fields, max_fields);

  /* Split field::type::description format */
  int any_desc = 0;
  for (int i = 0; i < nf; i++)
    {
      /* Find first "::" separator */
      char *sep1 = strstr (raw_fields[i], "::");
      if (sep1)
	{
	  /* field name is before first :: */
	  size_t fname_len = sep1 - raw_fields[i];
	  if (fname_len >= 256) fname_len = 255;
	  memcpy (fields_out[i], raw_fields[i], fname_len);
	  fields_out[i][fname_len] = 0;

	  /* Check for second :: (description) */
	  char *sep2 = strstr (sep1 + 2, "::");
	  if (sep2 && descs_out)
	    {
	      /* Description is after second :: */
	      size_t dlen = strlen (sep2 + 2);
	      if (dlen >= 512) dlen = 511;
	      memcpy (descs_out[i], sep2 + 2, dlen);
	      descs_out[i][dlen] = 0;
	      any_desc = 1;
	    }
	  else if (descs_out)
	    descs_out[i][0] = 0;
	}
      else
	{
	  /* No :: separator, use as-is */
	  strncpy (fields_out[i], raw_fields[i], 255);
	  fields_out[i][255] = 0;
	  if (descs_out)
	    descs_out[i][0] = 0;
	}
    }

  if (has_descs_out)
    *has_descs_out = any_desc;
  return nf;
}

static char *
gliner2_extract_json (const OrtApi *api,
		      const char *text, size_t text_len,
		      const char *schema_json, size_t schema_len,
		      float threshold)
{
  char struct_name[256];
  char field_names[GLINER2_MAX_LABELS][256];
  char field_descs[GLINER2_MAX_LABELS][512];
  int has_descs = 0;
  int num_fields = parse_structure_schema (schema_json, schema_len,
					   struct_name, sizeof (struct_name),
					   field_names, field_descs,
					   &has_descs, GLINER2_MAX_LABELS);
  if (num_fields == 0)
    return strdup ("{\"error\":\"no fields in structure schema\"}");

  const char *field_ptrs[GLINER2_MAX_LABELS];
  const char *desc_ptrs[GLINER2_MAX_LABELS];
  for (int i = 0; i < num_fields; i++)
    {
      field_ptrs[i] = field_names[i];
      desc_ptrs[i] = has_descs ? field_descs[i] : NULL;
    }

  gliner2_schema_block_t block;
  block.parent = struct_name;
  block.child_tok = SP_TOK_C;
  block.fields = field_ptrs;
  block.descriptions = has_descs ? desc_ptrs : NULL;
  block.num_fields = num_fields;

  int schema_label_indices[GLINER2_MAX_LABELS];
  int block_field_offsets[1];
  memset (schema_label_indices, 0, sizeof (schema_label_indices));

  gliner2_inference_result_t res;
  memset (&res, 0, sizeof (res));
  char *err = NULL;

  if (gliner2_run_pipeline (api, text, text_len, &block, 1,
			    schema_label_indices, block_field_offsets,
			    num_fields, &res, &err))
    return err ? err : strdup ("{\"error\":\"pipeline failed\"}");

  /* Build JSON: {"struct_name":[{"field1":"value1","field2":["v1","v2"],...}]} */
  char *json = (char *) malloc (GLINER2_MAX_JSON);
  if (!json)
    {
      gliner2_inference_free (&res);
      return strdup ("{\"error\":\"OOM\"}");
    }
  int jpos = 0;
  size_t jmax = GLINER2_MAX_JSON;
#define JS_APPEND(fmt, ...) do { \
  if (jpos < (int)jmax - 1) { \
    int n = snprintf(json + jpos, jmax - jpos, fmt, ##__VA_ARGS__); \
    if (n > 0) jpos += n; \
  } \
} while(0)

  char esc_sn[512];
  json_escape (struct_name, strlen (struct_name), esc_sn, sizeof (esc_sn));
  JS_APPEND ("{\"%s\":[{", esc_sn);

  if (res.struct_proj && res.struct_count > 0)
    {
      int L = res.num_text_words;
      int K = GLINER2_MAX_WIDTH;
      int P = res.total_P;
      int H = res.hidden_size;

      for (int fi = 0; fi < num_fields; fi++)
	{
	  if (fi > 0)
	    JS_APPEND (",");
	  char esc_fn[512];
	  json_escape (field_names[fi], strlen (field_names[fi]), esc_fn, sizeof (esc_fn));
	  JS_APPEND ("\"%s\":[", esc_fn);

	  int pi = fi;
	  if (pi >= P)
	    { JS_APPEND ("]"); continue; }

	  int first = 1;
	  for (int l = 0; l < L; l++)
	    for (int k = 0; k < K && l + k < L; k++)
	      {
		float dot = 0.0f;
		for (int d = 0; d < H; d++)
		  dot += res.span_rep[(l * K + k) * H + d]
		    * res.struct_proj[(0 * P + pi) * H + d];
		float s = sigmoidf (dot);
		if (s >= threshold)
		  {
		    int cs = res.start_map[l];
		    int ce = res.end_map[l + k];
		    if (cs >= 0 && ce > cs && (size_t) ce <= text_len)
		      {
			char span[1024];
			int slen = ce - cs;
			if (slen > 1023) slen = 1023;
			memcpy (span, text + cs, slen);
			span[slen] = 0;
			char esc_span[2048];
			json_escape (span, slen, esc_span, sizeof (esc_span));
			if (!first)
			  JS_APPEND (",");
			JS_APPEND ("\"%s\"", esc_span);
			first = 0;
		      }
		  }
	      }
	  JS_APPEND ("]");
	}
    }
  else
    {
      /* Empty structure */
      for (int fi = 0; fi < num_fields; fi++)
	{
	  if (fi > 0)
	    JS_APPEND (",");
	  char esc_fn[512];
	  json_escape (field_names[fi], strlen (field_names[fi]), esc_fn, sizeof (esc_fn));
	  JS_APPEND ("\"%s\":[]", esc_fn);
	}
    }

  JS_APPEND ("}]}");
  json[jpos] = 0;
#undef JS_APPEND

  gliner2_inference_free (&res);
  return json;
}

/* ---------- Combined extraction ---------- */

/* Find a JSON key in a JSON object and return pointer to the value.
   Handles: "key": ... where value starts after the colon.
   Returns NULL if key not found. */
static const char *
json_find_key (const char *json, size_t json_len, const char *key)
{
  size_t klen = strlen (key);
  const char *end = json + json_len;
  const char *p = json;
  while (p < end - klen - 3)
    {
      if (*p == '"' && !memcmp (p + 1, key, klen) && p[klen + 1] == '"')
	{
	  p += klen + 2;
	  while (p < end && (*p == ' ' || *p == '\t' || *p == '\n' || *p == '\r'))
	    p++;
	  if (p < end && *p == ':')
	    {
	      p++;
	      while (p < end && (*p == ' ' || *p == '\t' || *p == '\n' || *p == '\r'))
		p++;
	      return p;
	    }
	}
      p++;
    }
  return NULL;
}

/* Find matching bracket/brace. Returns pointer to closing char or NULL. */
static const char *
json_find_matching (const char *start, const char *end, char open, char close)
{
  int depth = 1;
  const char *p = start + 1;
  int in_string = 0;
  while (p < end && depth > 0)
    {
      if (*p == '"' && (p == start + 1 || *(p - 1) != '\\'))
	in_string = !in_string;
      else if (!in_string)
	{
	  if (*p == open) depth++;
	  else if (*p == close) depth--;
	}
      if (depth > 0) p++;
    }
  return (depth == 0) ? p : NULL;
}

/* Parse a JSON array of objects: [{"key":{"head":"","tail":""}}, ...]
   Extract the key names into rel_names_out.  Returns count. */
static int
parse_relation_array (const char *arr_start, const char *arr_end,
		      char rel_names_out[][256], int max_rels)
{
  int count = 0;
  const char *p = arr_start + 1;  /* skip [ */
  while (p < arr_end && count < max_rels)
    {
      while (p < arr_end && *p != '{')
	p++;
      if (p >= arr_end) break;
      /* Find the key name in this object */
      const char *q = p + 1;
      while (q < arr_end && *q != '"')
	q++;
      if (q >= arr_end) break;
      q++;  /* skip opening quote */
      const char *ke = q;
      while (ke < arr_end && *ke != '"')
	ke++;
      if (ke >= arr_end) break;
      size_t klen = ke - q;
      if (klen >= 256) klen = 255;
      memcpy (rel_names_out[count], q, klen);
      rel_names_out[count][klen] = 0;
      count++;
      /* Skip to end of this object */
      const char *obj_end = json_find_matching (p, arr_end, '{', '}');
      if (!obj_end) break;
      p = obj_end + 1;
    }
  return count;
}

/* Combined extraction: entities + relations in a single inference pass.
   Schema JSON format:
   {
     "entities": {"Person":"desc",...} or ["Person","Location"],
     "relations": {"parent_of":"desc",...} or ["parent_of","located_in"]
                  or [{"parent_of":{"head":"","tail":""}}]
   }
   Returns combined JSON result. */
static char *
gliner2_extract_combined (const OrtApi *api,
			  const char *text, size_t text_len,
			  const char *schema_json, size_t schema_len,
			  float threshold)
{
  /* ---- Parse entities section ---- */
  static char ent_labels[GLINER2_MAX_LABELS][256];
  static char ent_descs[GLINER2_MAX_LABELS][512];
  int num_ent = 0;
  int ent_has_descs = 0;

  const char *ent_val = json_find_key (schema_json, schema_len, "entities");
  if (ent_val)
    {
      if (*ent_val == '{')
	{
	  const char *ent_end = json_find_matching (ent_val, schema_json + schema_len, '{', '}');
	  if (ent_end)
	    {
	      num_ent = parse_json_object_pairs (ent_val, ent_end - ent_val + 1,
						 ent_labels, ent_descs, GLINER2_MAX_LABELS);
	      if (num_ent > 0)
		ent_has_descs = 1;
	    }
	}
      else if (*ent_val == '[')
	{
	  const char *ent_end = json_find_matching (ent_val, schema_json + schema_len, '[', ']');
	  if (ent_end)
	    num_ent = parse_json_string_array (ent_val, ent_end - ent_val + 1,
					       ent_labels, GLINER2_MAX_LABELS);
	}
    }

  /* ---- Parse relations section ---- */
  static char rel_names[GLINER2_MAX_LABELS][256];
  int num_rels = 0;

  const char *rel_val = json_find_key (schema_json, schema_len, "relations");
  if (rel_val)
    {
      if (*rel_val == '{')
	{
	  /* Object format: {"parent_of":"desc",...} — keys are relation names */
	  static char rel_descs[GLINER2_MAX_LABELS][512];
	  const char *rel_end = json_find_matching (rel_val, schema_json + schema_len, '{', '}');
	  if (rel_end)
	    {
	      num_rels = parse_json_object_pairs (rel_val, rel_end - rel_val + 1,
						  rel_names, rel_descs, GLINER2_MAX_LABELS);
	    }
	}
      else if (*rel_val == '[')
	{
	  const char *rel_end = json_find_matching (rel_val, schema_json + schema_len, '[', ']');
	  if (rel_end)
	    {
	      /* Check if it's an array of strings or array of objects */
	      const char *peek = rel_val + 1;
	      while (peek < rel_end && (*peek == ' ' || *peek == '\t' || *peek == '\n' || *peek == '\r'))
		peek++;
	      if (peek < rel_end && *peek == '"')
		{
		  /* Array of strings: ["parent_of","married_to"] */
		  num_rels = parse_json_string_array (rel_val, rel_end - rel_val + 1,
						      rel_names, GLINER2_MAX_LABELS);
		}
	      else if (peek < rel_end && *peek == '{')
		{
		  /* Array of objects: [{"parent_of":{"head":"","tail":""}}] */
		  num_rels = parse_relation_array (rel_val, rel_end,
						   rel_names, GLINER2_MAX_LABELS);
		}
	    }
	}
    }

  if (num_ent == 0 && num_rels == 0)
    return strdup ("{\"entities\":{},\"relations\":{}}");

  /* ---- Build schema blocks ---- */
  /* Block 0: entities (if any), Blocks 1..N: one per relation */
  int max_blocks = 1 + num_rels;
  gliner2_schema_block_t blocks[GLINER2_MAX_LABELS + 1];
  int num_blocks = 0;

  /* Entity label pointers */
  const char *ent_label_ptrs[GLINER2_MAX_LABELS];
  const char *ent_desc_ptrs[GLINER2_MAX_LABELS];
  for (int i = 0; i < num_ent; i++)
    {
      ent_label_ptrs[i] = ent_labels[i];
      ent_desc_ptrs[i] = ent_has_descs ? ent_descs[i] : NULL;
    }

  int ent_block_idx = -1;
  if (num_ent > 0)
    {
      ent_block_idx = num_blocks;
      blocks[num_blocks].parent = "entities";
      blocks[num_blocks].child_tok = SP_TOK_E;
      blocks[num_blocks].fields = ent_label_ptrs;
      blocks[num_blocks].descriptions = ent_has_descs ? ent_desc_ptrs : NULL;
      blocks[num_blocks].num_fields = num_ent;
      num_blocks++;
    }

  /* Relation blocks: each relation type is a separate block with [R] head/tail */
  const char *head_tail[2] = { "head", "tail" };
  int rel_block_start = num_blocks;
  for (int i = 0; i < num_rels; i++)
    {
      blocks[num_blocks].parent = rel_names[i];
      blocks[num_blocks].child_tok = SP_TOK_R;
      blocks[num_blocks].fields = head_tail;
      blocks[num_blocks].descriptions = NULL;
      blocks[num_blocks].num_fields = 2;
      num_blocks++;
    }

  /* ---- Compute total fields ---- */
  int num_total_fields = num_ent + num_rels * 2;
  int schema_label_indices[GLINER2_MAX_LABELS * 3];
  int block_field_offsets[GLINER2_MAX_LABELS + 1];
  memset (schema_label_indices, 0, sizeof (schema_label_indices));
  memset (block_field_offsets, 0, sizeof (block_field_offsets));

  /* ---- Run shared pipeline ---- */
  gliner2_inference_result_t res;
  memset (&res, 0, sizeof (res));
  char *err = NULL;

  if (gliner2_run_pipeline (api, text, text_len, blocks, num_blocks,
			    schema_label_indices, block_field_offsets,
			    num_total_fields, &res, &err))
    return err ? err : strdup ("{\"error\":\"pipeline failed\"}");

  /* ---- Build combined JSON output ---- */
  char *json = (char *) malloc (GLINER2_MAX_JSON);
  if (!json)
    { gliner2_inference_free (&res); return strdup ("{\"error\":\"OOM\"}"); }
  int jpos = 0;
  size_t jmax = GLINER2_MAX_JSON;
#define CMB_APPEND(fmt, ...) do { \
  if (jpos < (int)jmax - 1) { \
    int n = snprintf(json + jpos, jmax - jpos, fmt, ##__VA_ARGS__); \
    if (n > 0) jpos += n; \
    if (jpos >= (int)jmax - 1) { \
      gliner2_inference_free(&res); free(json); \
      return strdup("{\"error\":\"JSON buffer overflow\"}"); \
    } \
  } \
} while(0)

  CMB_APPEND ("{");

  /* ---- Entities section ---- */
  CMB_APPEND ("\"entities\":{");
  if (num_ent > 0 && res.struct_proj && res.struct_count > 0)
    {
      int L = res.num_text_words;
      int K = GLINER2_MAX_WIDTH;
      int P = res.total_P;
      int H = res.hidden_size;

      for (int li = 0; li < num_ent; li++)
	{
	  if (li > 0)
	    CMB_APPEND (",");
	  char esc_label[512];
	  json_escape (ent_labels[li], strlen (ent_labels[li]), esc_label, sizeof (esc_label));
	  CMB_APPEND ("\"%s\":[", esc_label);

	  int pi = block_field_offsets[ent_block_idx] + li;
	  if (pi >= P)
	    { CMB_APPEND ("]"); continue; }

	  int first = 1;
	  for (int l = 0; l < L; l++)
	    for (int k = 0; k < K && l + k < L; k++)
	      {
		float dot = 0.0f;
		for (int d = 0; d < H; d++)
		  dot += res.span_rep[(l * K + k) * H + d]
		    * res.struct_proj[(0 * P + pi) * H + d];
		float score = sigmoidf (dot);
		if (score >= threshold)
		  {
		    int cs = res.start_map[l];
		    int ce = res.end_map[l + k];
		    if (cs >= 0 && ce > cs && (size_t) ce <= text_len)
		      {
			char span[1024];
			int slen = ce - cs;
			if (slen > 1023) slen = 1023;
			memcpy (span, text + cs, slen);
			span[slen] = 0;
			int trim = 0;
			while (trim < slen && (span[trim] == ' ' || span[trim] == '\t'))
			  trim++;
			while (slen > trim && (span[slen - 1] == ' ' || span[slen - 1] == '\t'))
			  slen--;
			if (slen > trim)
			  {
			    if (!first) CMB_APPEND (",");
			    char esc[2048];
			    json_escape (span + trim, slen - trim, esc, sizeof (esc));
			    CMB_APPEND ("{\"text\":\"%s\",\"score\":%.4f,\"start\":%d,\"end\":%d}",
					 esc, score, cs + trim, ce);
			    first = 0;
			  }
		      }
		  }
	      }
	  CMB_APPEND ("]");
	}
    }
  else
    {
      for (int li = 0; li < num_ent; li++)
	{
	  if (li > 0) CMB_APPEND (",");
	  char esc[512];
	  json_escape (ent_labels[li], strlen (ent_labels[li]), esc, sizeof (esc));
	  CMB_APPEND ("\"%s\":[]", esc);
	}
    }
  CMB_APPEND ("}");

  /* ---- Relations section ---- */
  CMB_APPEND (",\"relations\":{");
  if (num_rels > 0 && res.struct_proj && res.struct_count > 0)
    {
      int L = res.num_text_words;
      int K = GLINER2_MAX_WIDTH;
      int P = res.total_P;
      int H = res.hidden_size;
      int B = res.struct_count;

      for (int ri = 0; ri < num_rels; ri++)
	{
	  if (ri > 0)
	    CMB_APPEND (",");
	  char esc_rel[512];
	  json_escape (rel_names[ri], strlen (rel_names[ri]), esc_rel, sizeof (esc_rel));
	  CMB_APPEND ("\"%s\":[", esc_rel);

	  int head_pi = block_field_offsets[rel_block_start + ri];
	  int tail_pi = block_field_offsets[rel_block_start + ri] + 1;
	  if (head_pi >= P || tail_pi >= P)
	    { CMB_APPEND ("]"); continue; }

	  int first_pair = 1;
	  char seen_keys[64][256];
	  int num_seen = 0;

	  for (int bi = 0; bi < B; bi++)
	    {
	      int best_h_l = -1, best_h_k = -1;
	      float best_h_score = -1.0f;
	      int best_t_l = -1, best_t_k = -1;
	      float best_t_score = -1.0f;

	      for (int l = 0; l < L; l++)
		for (int k = 0; k < K && l + k < L; k++)
		  {
		    float dot_h = 0.0f;
		    for (int d = 0; d < H; d++)
		      dot_h += res.span_rep[(l * K + k) * H + d]
			* res.struct_proj[(bi * P + head_pi) * H + d];
		    float sh = sigmoidf (dot_h);
		    if (sh >= threshold && sh > best_h_score)
		      { best_h_l = l; best_h_k = k; best_h_score = sh; }

		    float dot_t = 0.0f;
		    for (int d = 0; d < H; d++)
		      dot_t += res.span_rep[(l * K + k) * H + d]
			* res.struct_proj[(bi * P + tail_pi) * H + d];
		    float st = sigmoidf (dot_t);
		    if (st >= threshold && st > best_t_score)
		      { best_t_l = l; best_t_k = k; best_t_score = st; }
		  }

	      if (best_h_l < 0 || best_t_l < 0)
		continue;

	      int h_end = best_h_l + best_h_k;
	      int t_end = best_t_l + best_t_k;
	      if (!(best_t_l > h_end || t_end < best_h_l))
		continue;

	      int hcs = res.start_map[best_h_l];
	      int hce = res.end_map[h_end];
	      int tcs = res.start_map[best_t_l];
	      int tce = res.end_map[t_end];

	      if (hcs < 0 || hce <= hcs || (size_t) hce > text_len ||
		  tcs < 0 || tce <= tcs || (size_t) tce > text_len)
		continue;

	      char head_text[512], tail_text[512];
	      int hlen = hce - hcs; if (hlen > 511) hlen = 511;
	      int tlen = tce - tcs; if (tlen > 511) tlen = 511;
	      memcpy (head_text, text + hcs, hlen); head_text[hlen] = 0;
	      memcpy (tail_text, text + tcs, tlen); tail_text[tlen] = 0;

	      /* Dedup */
	      char dedup_key[256];
	      int dk = 0;
	      for (int ci = 0; ci < hlen && dk < 120; ci++)
		dedup_key[dk++] = (head_text[ci] >= 'A' && head_text[ci] <= 'Z')
		  ? head_text[ci] + 32 : head_text[ci];
	      dedup_key[dk++] = '|';
	      for (int ci = 0; ci < tlen && dk < 250; ci++)
		dedup_key[dk++] = (tail_text[ci] >= 'A' && tail_text[ci] <= 'Z')
		  ? tail_text[ci] + 32 : tail_text[ci];
	      dedup_key[dk] = 0;

	      int is_dup = 0;
	      for (int si = 0; si < num_seen; si++)
		if (strcmp (seen_keys[si], dedup_key) == 0)
		  { is_dup = 1; break; }

	      if (!is_dup)
		{
		  if (num_seen < 64)
		    { memcpy (seen_keys[num_seen], dedup_key, dk + 1); num_seen++; }
		  char esc_h[1024], esc_t[1024];
		  json_escape (head_text, hlen, esc_h, sizeof (esc_h));
		  json_escape (tail_text, tlen, esc_t, sizeof (esc_t));
		  if (!first_pair) CMB_APPEND (",");
		  CMB_APPEND ("[\"%.400s\",\"%.400s\"]", esc_h, esc_t);
		  first_pair = 0;
		}
	    }
	  CMB_APPEND ("]");
	}
    }
  else
    {
      for (int ri = 0; ri < num_rels; ri++)
	{
	  if (ri > 0) CMB_APPEND (",");
	  char esc[512];
	  json_escape (rel_names[ri], strlen (rel_names[ri]), esc, sizeof (esc));
	  CMB_APPEND ("\"%s\":[]", esc);
	}
    }
  CMB_APPEND ("}");

  CMB_APPEND ("}");
  json[jpos] = 0;
#undef CMB_APPEND

  gliner2_inference_free (&res);
  return json;
}

/* Handle GLiNER2 IPC request */
static void
process_gliner2 (const OrtApi *api, ipc_hdr_t *hdr, char *payload, size_t payload_len)
{
  size_t pos = sizeof (uint32_t);	/* skip op (already consumed) */

  if (pos + sizeof (uint32_t) > payload_len)
    {
      write_error (40, "gliner2: missing sub_op");
      return;
    }
  uint32_t sub_op = 0;
  memcpy (&sub_op, payload + pos, sizeof (uint32_t));
  pos += sizeof (uint32_t);

  /* Read text */
  if (pos + sizeof (uint32_t) > payload_len)
    {
      write_error (41, "gliner2: missing text_len");
      return;
    }
  uint32_t text_len = 0;
  memcpy (&text_len, payload + pos, sizeof (uint32_t));
  pos += sizeof (uint32_t);
  if (pos + text_len > payload_len)
    {
      write_error (42, "gliner2: text truncated");
      return;
    }
  const char *text = payload + pos;
  pos += text_len;

  /* Read schema JSON */
  if (pos + sizeof (uint32_t) > payload_len)
    {
      write_error (43, "gliner2: missing schema_len");
      return;
    }
  uint32_t schema_len = 0;
  memcpy (&schema_len, payload + pos, sizeof (uint32_t));
  pos += sizeof (uint32_t);
  if (pos + schema_len > payload_len)
    {
      write_error (44, "gliner2: schema truncated");
      return;
    }
  const char *schema_json = payload + pos;
  pos += schema_len;

  /* Read options JSON */
  if (pos + sizeof (uint32_t) > payload_len)
    {
      write_error (45, "gliner2: missing opts_len");
      return;
    }
  uint32_t opts_len = 0;
  memcpy (&opts_len, payload + pos, sizeof (uint32_t));
  pos += sizeof (uint32_t);
  if (pos + opts_len > payload_len)
    {
      write_error (45, "gliner2: options truncated");
      return;
    }
  const char *options_json = payload + pos;
  pos += opts_len;

  /* Confidence cutoff for accepting spans / labels / relations.  The caller can
     tune it by passing a "threshold" number in [0,1] in the options JSON (the
     plugin forwards the options arg verbatim); an absent or out-of-range value
     keeps the 0.5 default.  Before this the option was received and silently
     discarded, so the documented knob had no effect. */
  float threshold = 0.5f;
  if (opts_len > 0)
    {
      const char *tv = json_find_key (options_json, opts_len, "threshold");
      if (tv)
	{
	  float t = strtof (tv, NULL);
	  if (t >= 0.0f && t <= 1.0f)
	    threshold = t;
	}
    }

  if (!g_gl2_encoder || !g_gl2_span_rep || !g_gl2_classifier)
    {
      write_error (46, "gliner2: models not loaded (use --gliner2-dir)");
      return;
    }

  char *result = NULL;
  if (sub_op == GLINER2_SUB_EXTRACT)
    result = gliner2_extract_entities (api, text, text_len, schema_json, schema_len, threshold);
  else if (sub_op == GLINER2_SUB_CLASSIFY)
    result = gliner2_classify (api, text, text_len, schema_json, schema_len, threshold);
  else if (sub_op == GLINER2_SUB_EXTRACT_JSON)
    result = gliner2_extract_json (api, text, text_len, schema_json, schema_len, threshold);
  else if (sub_op == GLINER2_SUB_RELATIONS)
    result = gliner2_extract_relations (api, text, text_len, schema_json, schema_len, threshold);
  else if (sub_op == GLINER2_SUB_COMBINED)
    result = gliner2_extract_combined (api, text, text_len, schema_json, schema_len, threshold);
  else
    {
      write_error (47, "gliner2: unsupported sub_op");
      return;
    }

  if (!result)
    {
      write_error (48, "gliner2: extraction failed");
      return;
    }

  /* Send JSON response */
  size_t rlen = strlen (result);
  ipc_hdr_t rh;
  memset (&rh, 0, sizeof (rh));
  rh.magic = ONNX_IPC_MAGIC;
  rh.version = ONNX_IPC_VERSION;
  rh.batch_count = 1;
  rh.payload_len = (uint32_t) rlen;
  rh.status = 0;
  write_exact (&rh, sizeof (rh));
  write_exact (result, rlen);
  free (result);
}


static size_t
rm_width (uint32_t dtype)
{
  switch ((ONNXTensorElementDataType) dtype)
    {
    case ONNX_TENSOR_ELEMENT_DATA_TYPE_FLOAT: return sizeof (float);
    case ONNX_TENSOR_ELEMENT_DATA_TYPE_INT64: return sizeof (int64_t);
    case ONNX_TENSOR_ELEMENT_DATA_TYPE_INT32: return sizeof (int32_t);
    case ONNX_TENSOR_ELEMENT_DATA_TYPE_BOOL:  return 1;
    default:                                  return 0;
    }
}

/*  op 5: N named inputs of declared element types -> M named outputs.
 *
 *  request   uint32 n_inputs
 *              per input: uint32 name_len, name, uint32 dtype,
 *                         uint32 dims_count, int64 dims[], uint32 bytes, data
 *            uint32 n_outputs
 *              per output: uint32 name_len, name    (empty name = output 0)
 *
 *  response  [uint64 infer_ns, uint64 ser_ns]       if the telemetry flag is set
 *            uint32 n_outputs
 *              per output: uint32 dtype, uint32 dims_count, int64 dims[],
 *                          uint32 elem_count, data
 */
static void
process_run_multi (const OrtApi *api, OrtSession *session, ipc_hdr_t *hdr,
    char *payload, size_t payload_len)
{
  OrtMemoryInfo *mem = NULL;
  OrtAllocator *alloc = NULL;
  OrtValue *in_vals[HELPER_MAX_TENSORS];
  OrtValue *out_vals[HELPER_MAX_TENSORS];
  char *in_names[HELPER_MAX_TENSORS];
  char *out_names[HELPER_MAX_TENSORS];
  char *detected_out = NULL;
  int64_t dims[HELPER_MAX_TENSORS][ONNX_MAX_TENSOR_RANK];
  uint32_t dcounts[HELPER_MAX_TENSORS];
  uint32_t n_in = 0, n_out = 0;
  uint32_t i, j;
  size_t pos = sizeof (uint32_t);	/* the op word */
  char *resp = NULL;

  memset (in_vals, 0, sizeof (in_vals));
  memset (out_vals, 0, sizeof (out_vals));
  memset (in_names, 0, sizeof (in_names));
  memset (out_names, 0, sizeof (out_names));

  if (!session)
    { write_error (40, "no session"); return; }
  if (pos + sizeof (uint32_t) > payload_len)
    { write_error (41, "missing n_inputs"); return; }
  memcpy (&n_in, payload + pos, sizeof (uint32_t)); pos += sizeof (uint32_t);
  if (n_in == 0 || n_in > HELPER_MAX_TENSORS)
    { write_error (42, "invalid n_inputs"); return; }

  api->GetAllocatorWithDefaultOptions (&alloc);
  if (check_status_soft (api, api->CreateCpuMemoryInfo (OrtArenaAllocator, OrtMemTypeDefault, &mem),
			 "CreateCpuMemoryInfo"))
    { write_error (43, "CreateCpuMemoryInfo"); return; }

  for (i = 0; i < n_in; i++)
    {
      uint32_t nl = 0, dtype = 0, dc = 0, bytes = 0;
      if (pos + sizeof (uint32_t) > payload_len) { write_error (44, "truncated input"); goto done; }
      memcpy (&nl, payload + pos, sizeof (uint32_t)); pos += sizeof (uint32_t);
      if (nl == 0 || pos + nl > payload_len) { write_error (45, "bad input name"); goto done; }
      in_names[i] = (char *) malloc (nl + 1);
      if (!in_names[i]) { write_error (46, "OOM"); goto done; }
      memcpy (in_names[i], payload + pos, nl); in_names[i][nl] = 0; pos += nl;

      if (pos + 2 * sizeof (uint32_t) > payload_len) { write_error (47, "truncated input"); goto done; }
      memcpy (&dtype, payload + pos, sizeof (uint32_t)); pos += sizeof (uint32_t);
      memcpy (&dc, payload + pos, sizeof (uint32_t)); pos += sizeof (uint32_t);
      if (!rm_width (dtype)) { write_error (48, "unsupported input dtype"); goto done; }
      if (dc == 0 || dc > ONNX_MAX_TENSOR_RANK) { write_error (49, "invalid dims_count"); goto done; }
      if (pos + dc * sizeof (int64_t) + sizeof (uint32_t) > payload_len)
	{ write_error (50, "truncated dims"); goto done; }
      size_t expect = 1;
      for (j = 0; j < dc; j++)
	{
	  memcpy (&dims[i][j], payload + pos, sizeof (int64_t)); pos += sizeof (int64_t);
	  if (dims[i][j] <= 0 || expect > (SIZE_MAX / (size_t) dims[i][j]))
	    { write_error (51, "invalid dims"); goto done; }
	  expect *= (size_t) dims[i][j];
	}
      dcounts[i] = dc;
      memcpy (&bytes, payload + pos, sizeof (uint32_t)); pos += sizeof (uint32_t);
      if (bytes != expect * rm_width (dtype)) { write_error (52, "data length mismatch"); goto done; }
      if (pos + bytes > payload_len) { write_error (53, "data truncated"); goto done; }
      if (check_status_soft (api, api->CreateTensorWithDataAsOrtValue (mem, payload + pos, bytes,
	      dims[i], dc, (ONNXTensorElementDataType) dtype, &in_vals[i]), "CreateTensor"))
	{ write_error (54, "CreateTensor"); goto done; }
      pos += bytes;
    }

  if (pos + sizeof (uint32_t) > payload_len) { write_error (55, "missing n_outputs"); goto done; }
  memcpy (&n_out, payload + pos, sizeof (uint32_t)); pos += sizeof (uint32_t);
  if (n_out == 0 || n_out > HELPER_MAX_TENSORS) { write_error (56, "invalid n_outputs"); goto done; }
  for (i = 0; i < n_out; i++)
    {
      uint32_t nl = 0;
      if (pos + sizeof (uint32_t) > payload_len) { write_error (57, "truncated output name"); goto done; }
      memcpy (&nl, payload + pos, sizeof (uint32_t)); pos += sizeof (uint32_t);
      if (pos + nl > payload_len) { write_error (58, "truncated output name"); goto done; }
      if (nl == 0)
	{
	  /* empty means "whatever output 0 is" */
	  if (!detected_out
	      && check_status_soft (api, api->SessionGetOutputName (session, 0, alloc, &detected_out),
				    "SessionGetOutputName"))
	    { write_error (59, "SessionGetOutputName"); goto done; }
	  out_names[i] = NULL;	/* not owned; points at detected_out below */
	}
      else
	{
	  out_names[i] = (char *) malloc (nl + 1);
	  if (!out_names[i]) { write_error (46, "OOM"); goto done; }
	  memcpy (out_names[i], payload + pos, nl); out_names[i][nl] = 0;
	}
      pos += nl;
    }

  const char *run_out[HELPER_MAX_TENSORS];
  for (i = 0; i < n_out; i++)
    run_out[i] = out_names[i] ? out_names[i] : detected_out;

  uint64_t t0 = mono_ns ();
  if (check_status_soft (api, api->Run (session, NULL, (const char * const *) in_names,
	  (const OrtValue * const *) in_vals, n_in, run_out, n_out, out_vals), "Run"))
    { write_error (60, "Run failed"); goto done; }
  uint64_t infer_ns = mono_ns () - t0;

  /* size the response, then fill it */
  uint64_t t1 = mono_ns ();
  size_t rlen = 0;
  if (hdr->flags & ONNX_IPC_FLAG_TELEMETRY)
    rlen += 2 * sizeof (uint64_t);
  rlen += sizeof (uint32_t);
  size_t counts[HELPER_MAX_TENSORS], widths[HELPER_MAX_TENSORS], odc[HELPER_MAX_TENSORS];
  uint32_t otypes[HELPER_MAX_TENSORS];
  int64_t odims[HELPER_MAX_TENSORS][ONNX_MAX_TENSOR_RANK];
  void *odata[HELPER_MAX_TENSORS];
  for (i = 0; i < n_out; i++)
    {
      OrtTensorTypeAndShapeInfo *info = NULL;
      ONNXTensorElementDataType et;
      size_t ec = 0, dc = 0;
      if (check_status_soft (api, api->GetTensorTypeAndShape (out_vals[i], &info), "GetShape"))
	{ write_error (61, "GetTensorTypeAndShape"); goto done; }
      api->GetTensorElementType (info, &et);
      api->GetTensorShapeElementCount (info, &ec);
      api->GetDimensionsCount (info, &dc);
      if (!rm_width ((uint32_t) et) || dc > ONNX_MAX_TENSOR_RANK)
	{ api->ReleaseTensorTypeAndShapeInfo (info); write_error (62, "unsupported output tensor"); goto done; }
      api->GetDimensions (info, odims[i], dc);
      api->ReleaseTensorTypeAndShapeInfo (info);
      if (ec > HELPER_MAX_OUTPUT_FLOATS || ec * rm_width ((uint32_t) et) > HELPER_MAX_TENSOR_BYTES)
	{ write_error (63, "output too large"); goto done; }
      if (check_status_soft (api, api->GetTensorMutableData (out_vals[i], &odata[i]), "GetData"))
	{ write_error (64, "GetTensorMutableData"); goto done; }
      otypes[i] = (uint32_t) et; counts[i] = ec; widths[i] = rm_width ((uint32_t) et); odc[i] = dc;
      rlen += 3 * sizeof (uint32_t) + dc * sizeof (int64_t) + ec * widths[i];
    }
  resp = (char *) malloc (rlen ? rlen : 1);
  if (!resp) { write_error (46, "OOM"); goto done; }
  size_t w = 0;
  if (hdr->flags & ONNX_IPC_FLAG_TELEMETRY)
    {
      uint64_t ser_ns = mono_ns () - t1;
      memcpy (resp + w, &infer_ns, sizeof (uint64_t)); w += sizeof (uint64_t);
      memcpy (resp + w, &ser_ns, sizeof (uint64_t)); w += sizeof (uint64_t);
    }
  uint32_t u = n_out; memcpy (resp + w, &u, sizeof (uint32_t)); w += sizeof (uint32_t);
  for (i = 0; i < n_out; i++)
    {
      u = otypes[i];          memcpy (resp + w, &u, sizeof (uint32_t)); w += sizeof (uint32_t);
      u = (uint32_t) odc[i];  memcpy (resp + w, &u, sizeof (uint32_t)); w += sizeof (uint32_t);
      memcpy (resp + w, odims[i], odc[i] * sizeof (int64_t)); w += odc[i] * sizeof (int64_t);
      u = (uint32_t) counts[i]; memcpy (resp + w, &u, sizeof (uint32_t)); w += sizeof (uint32_t);
      memcpy (resp + w, odata[i], counts[i] * widths[i]); w += counts[i] * widths[i];
    }

  ipc_hdr_t rh;
  memset (&rh, 0, sizeof (rh));
  rh.magic = ONNX_IPC_MAGIC;
  rh.version = ONNX_IPC_VERSION;
  rh.flags = hdr->flags;
  rh.batch_count = hdr->batch_count;
  rh.payload_len = (uint32_t) w;
  rh.status = 0;
  write_exact (&rh, sizeof (rh));
  write_exact (resp, w);

done:
  free (resp);
  for (i = 0; i < n_in; i++)
    {
      if (in_vals[i]) api->ReleaseValue (in_vals[i]);
      free (in_names[i]);
    }
  for (i = 0; i < n_out; i++)
    {
      if (out_vals[i]) api->ReleaseValue (out_vals[i]);
      free (out_names[i]);
    }
  if (detected_out && alloc) alloc->Free (alloc, detected_out);
  if (mem) api->ReleaseMemoryInfo (mem);
}

static void
process_request (const OrtApi *api, OrtSession *session, ipc_hdr_t *hdr, char *payload, size_t payload_len)
{
  /* Early check: dispatch GLiNER2 ops before touching session (which may be NULL) */
  if (payload_len >= sizeof (uint32_t))
    {
      uint32_t peek_op = 0;
      memcpy (&peek_op, payload, sizeof (uint32_t));
      if (peek_op == ONNX_IPC_OP_GLINER2)
	{
	  process_gliner2 (api, hdr, payload, payload_len);
	  return;
	}
      /* The generic run answers for itself; it shares no code with the path
	 below, which is the embedding path's. */
      if (peek_op == ONNX_IPC_OP_RUN_MULTI)
	{
	  process_run_multi (api, session, hdr, payload, payload_len);
	  return;
	}
    }

  const char *input_names[2] = { NULL, NULL };
  const char *output_names[1] = { NULL };
  OrtAllocator *alloc = NULL;
  check_status (api, api->GetAllocatorWithDefaultOptions (&alloc), "GetAllocatorWithDefaultOptions");
  if (g_output_name)
    output_names[0] = g_output_name;
  else
    check_status (api, api->SessionGetOutputName (session, 0, alloc, (char **) &output_names[0]), "SessionGetOutputName");

  size_t pos = 0;
  if (payload_len < sizeof (uint32_t))
    {
      write_error (2, "payload too short");
      goto cleanup_names;
    }
  uint32_t op = 0;
  memcpy (&op, payload + pos, sizeof (uint32_t));
  pos += sizeof (uint32_t);
  uint32_t batch = hdr->batch_count;
  if (batch == 0 || batch > (uint32_t) g_max_texts)
    {
      write_error (4, "invalid batch");
      goto cleanup_names;
    }
  const char **strings = NULL;
  size_t *lengths = NULL;
  /* Declared before the first jump to the cleanup labels, which free them. */
  int64_t *tok_ids = NULL, *tok_mask = NULL;
  int64_t *grp_ids = NULL, *grp_mask = NULL;
  int *tok_len = NULL;
  uint32_t *order = NULL;
  float *assembled = NULL;
  size_t assembled_per = 0;
  uint64_t real_tokens = 0, padded_tokens = 0, sub_batches = 0;
  OrtMemoryInfo *emb_mem = NULL;
  const float *f32_data = NULL;
  const int64_t *i64_data1 = NULL;
  const int64_t *i64_data2 = NULL;
  /* Receives up to dcount dimensions from the request, so it is sized by the
     rank cap, not by 4.  The EMBED and RUN_I64_2 branches only ever set the
     first two. */
  int64_t shape[ONNX_MAX_TENSOR_RANK] = { 0 };
  uint32_t dcount = 0;
  size_t elem_count = 0;

  if (op == ONNX_IPC_OP_EMBED)
    {
      strings = (const char **) malloc (batch * sizeof (char *));
      lengths = (size_t *) malloc (batch * sizeof (size_t));
      if (!strings || !lengths)
	fail ("OOM");
      for (uint32_t i = 0; i < batch; i++)
	{
	  if (pos + sizeof (uint32_t) > payload_len)
	    {
	      write_error (5, "truncated text length");
	      goto cleanup_bufs;
	    }
	  uint32_t l = 0;
	  memcpy (&l, payload + pos, sizeof (uint32_t));
	  pos += sizeof (uint32_t);
	  if (l > HELPER_MAX_INPUT || pos + l > payload_len)
	    {
	      write_error (6, "text too long");
	      goto cleanup_bufs;
	    }
	  strings[i] = payload + pos;
	  lengths[i] = l;
	  pos += l;
	}
    }
  else if (op == ONNX_IPC_OP_RUN_F32)
    {
      if (pos + sizeof (uint32_t) > payload_len)
	{
	  write_error (10, "missing dims_count");
	  goto cleanup_bufs;
	}
      memcpy (&dcount, payload + pos, sizeof (uint32_t));
      pos += sizeof (uint32_t);
      if (dcount == 0 || dcount > ONNX_MAX_TENSOR_RANK)
	{
	  write_error (11, "invalid dims_count");
	  goto cleanup_bufs;
	}
      if (pos + dcount * sizeof (int64_t) > payload_len)
	{
	  write_error (12, "dims truncated");
	  goto cleanup_bufs;
	}
      int64_t dims_local[ONNX_MAX_TENSOR_RANK] = { 0 };
      for (uint32_t i = 0; i < dcount; i++)
	{
	  memcpy (&dims_local[i], payload + pos, sizeof (int64_t));
	  pos += sizeof (int64_t);
	}
      if (pos + sizeof (uint32_t) > payload_len)
	{
	  write_error (13, "missing data_len");
	  goto cleanup_bufs;
	}
      uint32_t bytes = 0;
      memcpy (&bytes, payload + pos, sizeof (uint32_t));
      pos += sizeof (uint32_t);
      size_t expected = 1;
      for (uint32_t i = 0; i < dcount; i++)
	{
	  if (dims_local[i] <= 0 || expected > (SIZE_MAX / (size_t) dims_local[i]))
	    {
	      write_error (15, "invalid dims");
	      goto cleanup_bufs;
	    }
	  expected *= (size_t) dims_local[i];
	}
      if (bytes != expected * sizeof (float))
	{
	  write_error (16, "data length mismatch");
	  goto cleanup_bufs;
	}
      if (pos + bytes > payload_len)
	{
	  write_error (14, "data truncated");
	  goto cleanup_bufs;
	}
      elem_count = bytes / sizeof (float);
      f32_data = (const float *) (payload + pos);
      for (uint32_t i = 0; i < dcount; i++)
	shape[i] = dims_local[i];
      if (dcount == 1)
	shape[1] = 1;
      batch = (dcount > 1) ? (uint32_t) dims_local[0] : 1;
    }
  else if (op == ONNX_IPC_OP_RUN_I64_2)
    {
      if (pos + sizeof (uint32_t) > payload_len)
	{
	  write_error (20, "missing dims_count");
	  goto cleanup_bufs;
	}
      memcpy (&dcount, payload + pos, sizeof (uint32_t));
      pos += sizeof (uint32_t);
      if (dcount != 2)
	{
	  write_error (21, "dims_count must be 2");
	  goto cleanup_bufs;
	}
      if (pos + 2 * sizeof (int64_t) > payload_len)
	{
	  write_error (22, "dims truncated");
	  goto cleanup_bufs;
	}
      memcpy (&shape[0], payload + pos, sizeof (int64_t)); pos += sizeof (int64_t);
      memcpy (&shape[1], payload + pos, sizeof (int64_t)); pos += sizeof (int64_t);
      if (pos + sizeof (uint32_t) > payload_len)
	{
	  write_error (23, "missing data_len");
	  goto cleanup_bufs;
	}
      uint32_t bytes1 = 0;
      memcpy (&bytes1, payload + pos, sizeof (uint32_t)); pos += sizeof (uint32_t);
      size_t expected = (size_t) shape[0] * (size_t) shape[1] * sizeof (int64_t);
      if (bytes1 != expected)
	{
	  write_error (28, "data length mismatch");
	  goto cleanup_bufs;
	}
      if (pos + bytes1 > payload_len)
	{
	  write_error (24, "data truncated");
	  goto cleanup_bufs;
	}
      i64_data1 = (const int64_t *) (payload + pos);
      pos += bytes1;
      if (pos + sizeof (uint32_t) > payload_len)
	{
	  write_error (25, "missing data_len 2");
	  goto cleanup_bufs;
	}
      uint32_t bytes2 = 0;
      memcpy (&bytes2, payload + pos, sizeof (uint32_t)); pos += sizeof (uint32_t);
      if (bytes2 != expected)
	{
	  write_error (29, "data2 length mismatch");
	  goto cleanup_bufs;
	}
      if (pos + bytes2 > payload_len)
	{
	  write_error (26, "data2 truncated");
	  goto cleanup_bufs;
	}
      i64_data2 = (const int64_t *) (payload + pos);
      elem_count = bytes1 / sizeof (int64_t);
      if (bytes1 != bytes2)
	{
	  write_error (27, "input sizes mismatch");
	  goto cleanup_bufs;
	}
      batch = (uint32_t) shape[0];
    }
  else
    {
      write_error (3, "unsupported op");
      goto cleanup_bufs;
    }

  check_status (api, api->SessionGetInputName (session, 0, alloc, (char **) &input_names[0]), "SessionGetInputName");
  if (op == ONNX_IPC_OP_RUN_I64_2 || (op == ONNX_IPC_OP_EMBED && g_tok_kind != TOK_NONE))
    check_status (api, api->SessionGetInputName (session, 1, alloc, (char **) &input_names[1]), "SessionGetInputName");

  if (op == ONNX_IPC_OP_EMBED && g_tok_kind == TOK_NONE)
    {
      shape[0] = (int64_t) batch;
      shape[1] = 1;
    }
  OrtValue *input = NULL, *output = NULL;
  OrtTensorTypeAndShapeInfo *info = NULL;
  uint64_t t_inf_start = mono_ns ();
  if (op == ONNX_IPC_OP_EMBED && g_tok_kind != TOK_NONE)
    {
      /* Tokenize every text into a row of max_seq_len tokens, then run the
	 texts in order of token count, as sub-batches of at most g_sub_rows
	 rows and g_tokens_per_batch padded tokens.  One run of the whole
	 request is padded to its longest text, so a paragraph among labels made
	 every label cost a paragraph; texts of similar length together pad
	 almost nothing.  Pads are masked out of attention and pooling, so a
	 text's vector does not depend on the sub-batch it lands in, and every
	 vector goes back to its text's position in the request. */
      size_t msl = (size_t) g_wp.max_seq_len;
      size_t grp_rows = (size_t) (g_sub_rows < (int) batch ? g_sub_rows : (int) batch);
      uint32_t g0 = 0;
      tok_ids = (int64_t *) calloc ((size_t) batch * msl, sizeof (int64_t));
      tok_mask = (int64_t *) calloc ((size_t) batch * msl, sizeof (int64_t));
      tok_len = (int *) malloc ((size_t) batch * sizeof (int));
      order = (uint32_t *) malloc ((size_t) batch * sizeof (uint32_t));
      grp_ids = (int64_t *) malloc (grp_rows * msl * sizeof (int64_t));
      grp_mask = (int64_t *) malloc (grp_rows * msl * sizeof (int64_t));
      if (!tok_ids || !tok_mask || !tok_len || !order || !grp_ids || !grp_mask)
	{
	  write_error (30, "OOM tokenize");
	  goto cleanup_all;
	}
      for (uint32_t bi = 0; bi < batch; bi++)
	{
	  tok_len[bi] = tok_tokenize_n (strings[bi], lengths[bi], tok_ids + (size_t) bi * msl,
					tok_mask + (size_t) bi * msl, g_wp.max_seq_len);
	  order[bi] = bi;
	}
      if (g_sort && batch > 1)
	{
	  g_sort_len = tok_len;
	  qsort (order, batch, sizeof (uint32_t), wp_cmp_token_count);
	}
      check_status (api, api->CreateCpuMemoryInfo (OrtArenaAllocator, OrtMemTypeDefault, &emb_mem), "CreateCpuMemoryInfo");
      const char *names2[2] = { input_names[0], input_names[1] };
      while (g0 < batch)
	{
	  /* A sub-batch runs as wide as its longest text -- or at max_seq_len
	     when the model cannot be cut -- so that is what the budget counts. */
	  uint32_t g1 = g0 + 1, rows, r;
	  int longest = tok_len[order[g0]], seq;
	  while (g1 < batch && (int) (g1 - g0) < g_sub_rows)
	    {
	      int wide = tok_len[order[g1]] > longest ? tok_len[order[g1]] : longest;
	      int run_len = g_wp_trim_pad ? wide : g_wp.max_seq_len;
	      if ((size_t) (g1 - g0 + 1) * (size_t) run_len > (size_t) g_tokens_per_batch)
		break;
	      longest = wide;
	      g1++;
	    }
	  rows = g1 - g0;
	  seq = (g_wp_trim_pad && longest < g_wp.max_seq_len) ? longest : g_wp.max_seq_len;
	  for (r = 0; r < rows; r++)
	    {
	      memcpy (grp_ids + (size_t) r * seq, tok_ids + (size_t) order[g0 + r] * msl, seq * sizeof (int64_t));
	      memcpy (grp_mask + (size_t) r * seq, tok_mask + (size_t) order[g0 + r] * msl, seq * sizeof (int64_t));
	      real_tokens += (uint64_t) tok_len[order[g0 + r]];
	    }
	  padded_tokens += (uint64_t) rows * (uint64_t) seq;
	  sub_batches++;
	  shape[0] = (int64_t) rows;
	  shape[1] = (int64_t) seq;
	  OrtValue *inputs[2] = { NULL, NULL };
	  check_status (api, api->CreateTensorWithDataAsOrtValue (emb_mem, grp_ids, (size_t) rows * seq * sizeof (int64_t), shape, 2, ONNX_TENSOR_ELEMENT_DATA_TYPE_INT64, &inputs[0]), "CreateTensor ids");
	  check_status (api, api->CreateTensorWithDataAsOrtValue (emb_mem, grp_mask, (size_t) rows * seq * sizeof (int64_t), shape, 2, ONNX_TENSOR_ELEMENT_DATA_TYPE_INT64, &inputs[1]), "CreateTensor mask");
	  check_status (api, api->Run (session, NULL, names2, (const OrtValue * const *) inputs, 2, output_names, 1, &output), "Run");
	  api->ReleaseValue (inputs[0]);
	  api->ReleaseValue (inputs[1]);

	  /* This sub-batch's vectors, each to its text's position. */
	  ONNXTensorElementDataType sub_et;
	  size_t sub_elems = 0, sub_per;
	  float *sub_out = NULL;
	  check_status (api, api->GetTensorTypeAndShape (output, &info), "GetTensorTypeAndShape");
	  check_status (api, api->GetTensorElementType (info, &sub_et), "GetTensorElementType");
	  check_status (api, api->GetTensorShapeElementCount (info, &sub_elems), "GetTensorShapeElementCount");
	  api->ReleaseTensorTypeAndShapeInfo (info);
	  info = NULL;
	  if (sub_et != ONNX_TENSOR_ELEMENT_DATA_TYPE_FLOAT)
	    {
	      write_error (7, "output not float");
	      goto cleanup_all;
	    }
	  if (sub_elems % rows != 0)
	    {
	      write_error (9, "output not divisible by batch");
	      goto cleanup_all;
	    }
	  sub_per = sub_elems / rows;
	  if (!assembled)
	    {
	      /* Per vector, matching the plugin's onnx_validate_output_size; the
		 whole response is bounded by HELPER_MAX_TENSOR_BYTES. */
	      if (sub_per > HELPER_MAX_OUTPUT_FLOATS
		  || (size_t) batch * sub_per * sizeof (float) > HELPER_MAX_TENSOR_BYTES)
		{
		  write_error (8, "output too large");
		  goto cleanup_all;
		}
	      assembled_per = sub_per;
	      assembled = (float *) malloc ((size_t) batch * sub_per * sizeof (float));
	      if (!assembled)
		fail ("OOM");
	    }
	  else if (sub_per != assembled_per)
	    {
	      write_error (9, "sub-batch outputs differ in width");
	      goto cleanup_all;
	    }
	  check_status (api, api->GetTensorMutableData (output, (void **) &sub_out), "GetTensorMutableData");
	  for (r = 0; r < rows; r++)
	    memcpy (assembled + (size_t) order[g0 + r] * sub_per, sub_out + (size_t) r * sub_per,
		    sub_per * sizeof (float));
	  api->ReleaseValue (output);
	  output = NULL;
	  g0 = g1;
	}
    }
  else if (op == ONNX_IPC_OP_EMBED)
    {
      check_status (api, api->CreateTensorAsOrtValue (alloc, shape, 1, ONNX_TENSOR_ELEMENT_DATA_TYPE_STRING, &input), "CreateTensorAsOrtValue");
      check_status (api, api->FillStringTensor (input, strings, batch), "FillStringTensor");
      check_status (api, api->Run (session, NULL, input_names, (const OrtValue * const *) &input, 1, output_names, 1, &output), "Run");
    }
  else if (op == ONNX_IPC_OP_RUN_F32)
    {
      OrtMemoryInfo *mem = NULL;
      if (check_status_soft (api, api->CreateCpuMemoryInfo (OrtArenaAllocator, OrtMemTypeDefault, &mem), "CreateCpuMemoryInfo"))
	{ write_error (10, "CreateCpuMemoryInfo failed"); goto cleanup_all; }
      if (check_status_soft (api, api->CreateTensorWithDataAsOrtValue (mem, (void *) f32_data, elem_count * sizeof (float), shape, dcount, ONNX_TENSOR_ELEMENT_DATA_TYPE_FLOAT, &input), "CreateTensorWithDataAsOrtValue"))
	{ api->ReleaseMemoryInfo (mem); write_error (11, "CreateTensorWithDataAsOrtValue failed"); goto cleanup_all; }
      api->ReleaseMemoryInfo (mem);
      if (check_status_soft (api, api->Run (session, NULL, input_names, (const OrtValue * const *) &input, 1, output_names, 1, &output), "Run"))
	{ write_error (12, "Run failed"); goto cleanup_all; }
    }
  else if (op == ONNX_IPC_OP_RUN_I64_2)
    {
      OrtMemoryInfo *mem = NULL;
      check_status (api, api->CreateCpuMemoryInfo (OrtArenaAllocator, OrtMemTypeDefault, &mem), "CreateCpuMemoryInfo");
      OrtValue *inputs[2] = { NULL, NULL };
      check_status (api, api->CreateTensorWithDataAsOrtValue (mem, (void *) i64_data1, elem_count * sizeof (int64_t), shape, 2, ONNX_TENSOR_ELEMENT_DATA_TYPE_INT64, &inputs[0]), "CreateTensorWithDataAsOrtValue");
      check_status (api, api->CreateTensorWithDataAsOrtValue (mem, (void *) i64_data2, elem_count * sizeof (int64_t), shape, 2, ONNX_TENSOR_ELEMENT_DATA_TYPE_INT64, &inputs[1]), "CreateTensorWithDataAsOrtValue");
      api->ReleaseMemoryInfo (mem);
      const char *names[2] = { input_names[0], input_names[1] };
      check_status (api, api->Run (session, NULL, names, (const OrtValue * const *) inputs, 2, output_names, 1, &output), "Run");
      api->ReleaseValue (inputs[0]);
      api->ReleaseValue (inputs[1]);
    }
  uint64_t t_inf_end = mono_ns ();

  size_t per;
  float *out = NULL;
  if (assembled)
    {
      /* The WordPiece EMBED path ran sub-batches and checked each of them. */
      per = assembled_per;
      out = assembled;
    }
  else
    {
      check_status (api, api->GetTensorTypeAndShape (output, &info), "GetTensorTypeAndShape");
      ONNXTensorElementDataType et;
      check_status (api, api->GetTensorElementType (info, &et), "GetTensorElementType");
      if (et != ONNX_TENSOR_ELEMENT_DATA_TYPE_FLOAT)
	{
	  write_error (7, "output not float");
	  goto cleanup_all;
	}
      elem_count = 0;
      check_status (api, api->GetTensorShapeElementCount (info, &elem_count), "GetTensorShapeElementCount");
      if (elem_count % batch != 0)
	{
	  write_error (9, "output not divisible by batch");
	  goto cleanup_all;
	}
      per = elem_count / batch;
      /* Per vector, matching the plugin's onnx_validate_output_size; the whole
	 batch is bounded by HELPER_MAX_TENSOR_BYTES, not by this count. */
      if (per > HELPER_MAX_OUTPUT_FLOATS || elem_count * sizeof (float) > HELPER_MAX_TENSOR_BYTES)
	{
	  write_error (8, "output too large");
	  goto cleanup_all;
	}
      check_status (api, api->GetTensorMutableData (output, (void **) &out), "GetTensorMutableData");
    }

  uint64_t t_ser_start = mono_ns ();
  size_t payload_out_len = 0;
  /* Token counts ride with the timings, and only where they exist. */
  int with_tokens = (hdr->flags & ONNX_IPC_FLAG_TELEMETRY) && assembled;
  if (hdr->flags & ONNX_IPC_FLAG_TELEMETRY)
    payload_out_len += 2 * sizeof (uint64_t);
  if (with_tokens)
    payload_out_len += 3 * sizeof (uint64_t);
  payload_out_len += batch * (sizeof (uint32_t) + per * sizeof (float));
  char *resp = (char *) malloc (payload_out_len);
  if (!resp)
    fail ("OOM");
  size_t wpos = 0;
  if (hdr->flags & ONNX_IPC_FLAG_TELEMETRY)
    {
      uint64_t infer_ns = t_inf_end - t_inf_start;
      uint64_t ser_ns = mono_ns () - t_ser_start;
      memcpy (resp + wpos, &infer_ns, sizeof (uint64_t)); wpos += sizeof (uint64_t);
      memcpy (resp + wpos, &ser_ns, sizeof (uint64_t)); wpos += sizeof (uint64_t);
    }
  if (with_tokens)
    {
      memcpy (resp + wpos, &real_tokens, sizeof (uint64_t)); wpos += sizeof (uint64_t);
      memcpy (resp + wpos, &padded_tokens, sizeof (uint64_t)); wpos += sizeof (uint64_t);
      memcpy (resp + wpos, &sub_batches, sizeof (uint64_t)); wpos += sizeof (uint64_t);
    }
  for (uint32_t i = 0; i < batch; i++)
    {
      uint32_t elems = (uint32_t) per;
      memcpy (resp + wpos, &elems, sizeof (uint32_t));
      wpos += sizeof (uint32_t);
      memcpy (resp + wpos, out + (size_t) i * per, per * sizeof (float));
      wpos += per * sizeof (float);
    }

  ipc_hdr_t rh;
  memset (&rh, 0, sizeof (rh));
  rh.magic = ONNX_IPC_MAGIC;
  rh.version = ONNX_IPC_VERSION;
  rh.flags = hdr->flags | (with_tokens ? ONNX_IPC_FLAG_TOKENS : 0);
  rh.batch_count = batch;
  rh.payload_len = (uint32_t) wpos;
  rh.status = 0;
  write_exact (&rh, sizeof (rh));
  write_exact (resp, wpos);
  free (resp);

cleanup_all:
  if (info)
    api->ReleaseTensorTypeAndShapeInfo (info);
  if (input)
    api->ReleaseValue (input);
  if (output)
    api->ReleaseValue (output);
cleanup_bufs:
  if (emb_mem)
    api->ReleaseMemoryInfo (emb_mem);
  free (assembled);
  free (grp_ids);
  free (grp_mask);
  free (tok_len);
  free (order);
  free (tok_ids);
  free (tok_mask);
  free (strings);
  free (lengths);
cleanup_names:
  if (alloc && input_names[0])
    alloc->Free (alloc, (void *) input_names[0]);
  if (alloc && input_names[1])
    alloc->Free (alloc, (void *) input_names[1]);
  if (alloc && output_names[0] && !g_output_name)
    alloc->Free (alloc, (void *) output_names[0]);
}

static void
server_loop (const OrtApi *api, OrtSession *session)
{
  while (1)
    {
      ipc_hdr_t hdr;
      if (read_exact (&hdr, sizeof (hdr)) < 0)
	break;
      if (hdr.magic != ONNX_IPC_MAGIC || hdr.version != ONNX_IPC_VERSION)
	{
	  write_error (100, "bad magic/version");
	  break;
	}
      /* In size_t: HELPER_MAX_INPUT * batch_count wraps in 32 bits once a
	 request may carry 8,192 texts. */
      if ((size_t) hdr.payload_len > (size_t) HELPER_MAX_INPUT * hdr.batch_count + 16
	  || hdr.payload_len > HELPER_MAX_REQUEST_BYTES)
	{
	  write_error (101, "payload too large");
	  break;
	}
      char *payload = (char *) malloc (hdr.payload_len ? hdr.payload_len : 1);
      if (!payload)
	fail ("OOM");
      if (hdr.payload_len && read_exact (payload, hdr.payload_len) < 0)
	{
	  free (payload);
	  break;
	}
      if (hdr.batch_count == 0)
	{
	  write_error (102, "batch count zero");
	  free (payload);
	  continue;
	}
      process_request (api, session, &hdr, payload, hdr.payload_len);
      free (payload);
    }
}

/* Rank of a session input or output, and the size of its dimension 1; -1 for either when unknown. */
static void
session_io_shape (const OrtApi *api, OrtSession *session, int is_input, size_t inx, int64_t *rank, int64_t *dim1)
{
  OrtTypeInfo *ti = NULL;
  const OrtTensorTypeAndShapeInfo *tsi = NULL;
  size_t dc = 0;
  *rank = -1;
  *dim1 = -1;
  OrtStatus *st = is_input ? api->SessionGetInputTypeInfo (session, inx, &ti) : api->SessionGetOutputTypeInfo (session, inx, &ti);
  if (st)
    {
      api->ReleaseStatus (st);
      return;
    }
  if (!api->CastTypeInfoToTensorInfo (ti, &tsi) && tsi && !api->GetDimensionsCount (tsi, &dc) && dc >= 2 && dc <= 8)
    {
      int64_t dims[8];
      if (!api->GetDimensions (tsi, dims, dc))
	{
	  *rank = (int64_t) dc;
	  *dim1 = dims[1];
	}
    }
  api->ReleaseTypeInfo (ti);
}

/* Trimming is safe only if the sequence axis is symbolic and the output has one vector per text, not one per token. */
static int
wp_model_allows_trim (const OrtApi *api, OrtSession *session)
{
  OrtAllocator *alloc = NULL;
  size_t n_out = 0, out_inx = 0;
  int64_t rank, dim1;
  session_io_shape (api, session, 1, 0, &rank, &dim1);
  if (rank != 2 || dim1 >= 0)
    return 0;
  if (g_output_name)
    {
      if (api->GetAllocatorWithDefaultOptions (&alloc) || api->SessionGetOutputCount (session, &n_out))
	return 0;
      for (out_inx = 0; out_inx < n_out; out_inx++)
	{
	  char *name = NULL;
	  int same;
	  if (api->SessionGetOutputName (session, out_inx, alloc, &name))
	    return 0;
	  same = !strcmp (name, g_output_name);
	  alloc->Free (alloc, name);
	  if (same)
	    break;
	}
      if (out_inx == n_out)
	return 0;
    }
  session_io_shape (api, session, 0, out_inx, &rank, &dim1);
  return rank == 2;
}

/* --tokenize, --tokenize0: the ids of each text on stdin -- one a line, or
   NUL-terminated -- as one line of ids a text, from <s> or [CLS] to </s> or
   [SEP], without the pads.  What a check of the tokenizer against the model's
   own compares. */
static int
tokenize_stdin (int delim)
{
  size_t len = 0, cap = 1 << 16, s, e;
  char *buf = (char *) malloc (cap);
  int msl = g_wp.max_seq_len;
  int64_t *ids = (int64_t *) malloc ((size_t) msl * sizeof (int64_t));
  int64_t *mask = (int64_t *) malloc ((size_t) msl * sizeof (int64_t));
  if (!buf || !ids || !mask)
    fail ("OOM");
  for (;;)
    {
      size_t got;
      if (len == cap && !(buf = (char *) realloc (buf, cap *= 2)))
	fail ("OOM");
      got = fread (buf + len, 1, cap - len, stdin);
      if (!got)
	break;
      len += got;
    }
  for (s = 0; s < len; s = e + 1)
    {
      const char *d = (const char *) memchr (buf + s, delim, len - s);
      int n, k;
      e = d ? (size_t) (d - buf) : len;
      n = tok_tokenize_n (buf + s, e - s, ids, mask, msl);
      for (k = 0; k < n; k++)
	printf (k ? " %lld" : "%lld", (long long) ids[k]);
      putchar ('\n');
    }
  free (buf);
  free (ids);
  free (mask);
  return (fflush (stdout) || ferror (stdout)) ? 1 : 0;
}

int
main (int argc, char **argv)
{
  const char *model_path = NULL;
  const char *vocab_path = NULL;
  const char *gliner2_dir = NULL;
  const char *gliner2_vocab = NULL;
  int server = 0;
  /* One thread per operator by default: a helper pool gets its parallelism
     from running several helpers at once, and an intra-op pool per helper on
     top of that would oversubscribe the box and fight Virtuoso's own threads.
     Raise these only for a single-helper, latency-sensitive setup. */
  int intra_threads = 1;
  int inter_threads = 1;
  /* The plugin's `opt` load option: 0 none, 1 basic, 2 extended, anything
     else all -- the levels onnx_session_apply_options maps in-process. */
  int opt_level = 99;
  int pad_to_max = 0;
  int tokenize_delim = -1;
  for (int i = 1; i < argc; i++)
    {
      if (!strcmp (argv[i], "--model") && i + 1 < argc)
	model_path = argv[++i];
      else if (!strcmp (argv[i], "--intra-threads") && i + 1 < argc)
	intra_threads = atoi (argv[++i]);
      else if (!strcmp (argv[i], "--inter-threads") && i + 1 < argc)
	inter_threads = atoi (argv[++i]);
      else if (!strcmp (argv[i], "--opt-level") && i + 1 < argc)
	opt_level = atoi (argv[++i]);
      else if (!strcmp (argv[i], "--vocab") && i + 1 < argc)
	vocab_path = argv[++i];
      else if (!strcmp (argv[i], "--max-seq-len") && i + 1 < argc)
	g_wp.max_seq_len = atoi (argv[++i]);
      else if (!strcmp (argv[i], "--output") && i + 1 < argc)
	g_output_name = argv[++i];
      else if (!strcmp (argv[i], "--gliner2-dir") && i + 1 < argc)
	gliner2_dir = argv[++i];
      else if (!strcmp (argv[i], "--gliner2-vocab") && i + 1 < argc)
	gliner2_vocab = argv[++i];
      else if (!strcmp (argv[i], "--server"))
	server = 1;
      else if (!strcmp (argv[i], "--pad-to-max"))
	pad_to_max = 1;
      else if (!strcmp (argv[i], "--max-texts") && i + 1 < argc)
	g_max_texts = atoi (argv[++i]);
      else if (!strcmp (argv[i], "--sub-batch-rows") && i + 1 < argc)
	g_sub_rows = atoi (argv[++i]);
      else if (!strcmp (argv[i], "--tokens-per-batch") && i + 1 < argc)
	g_tokens_per_batch = atoi (argv[++i]);
      else if (!strcmp (argv[i], "--no-sort"))
	g_sort = 0;
      else if (!strcmp (argv[i], "--tokenize"))
	tokenize_delim = '\n';
      else if (!strcmp (argv[i], "--tokenize0"))
	tokenize_delim = 0;
    }
  if (!model_path && !gliner2_dir && tokenize_delim < 0)
    fail ("--model or --gliner2-dir is required");
  /* The plugin refuses these at load; a hand-started helper gets the same bounds. */
  if (g_max_texts < 1 || g_max_texts > HELPER_MAX_TEXTS_CEILING)
    fail ("--max-texts must be 1..%d", HELPER_MAX_TEXTS_CEILING);
  if (g_sub_rows < 1 || g_sub_rows > g_max_texts)
    fail ("--sub-batch-rows must be 1..%d (--max-texts)", g_max_texts);
  if (g_tokens_per_batch < HELPER_TOKENS_PER_BATCH_MIN || g_tokens_per_batch > HELPER_TOKENS_PER_BATCH_MAX)
    fail ("--tokens-per-batch must be %d..%d", HELPER_TOKENS_PER_BATCH_MIN, HELPER_TOKENS_PER_BATCH_MAX);
  if (g_wp.max_seq_len < HELPER_MAX_SEQ_LEN_MIN || g_wp.max_seq_len > HELPER_MAX_SEQ_LEN_MAX)
    fail ("--max-seq-len must be %d..%d", HELPER_MAX_SEQ_LEN_MIN, HELPER_MAX_SEQ_LEN_MAX);
  if (vocab_path)
    {
      /* vocab.json (and merges.txt beside it) is byte-level BPE; anything
	 else is a WordPiece vocab.txt. */
      size_t vl = strlen (vocab_path);
      if (vl >= 5 && !strcmp (vocab_path + vl - 5, ".json"))
	{
	  if (bpe_load (vocab_path))
	    fail ("Failed to load the BPE vocabulary from %s", vocab_path);
	}
      else
	{
	  if (wp_load_vocab (vocab_path))
	    fail ("Failed to load vocab from %s", vocab_path);
	  g_tok_kind = TOK_WORDPIECE;
	  fprintf (stderr, "Loaded %d vocab entries, max_seq_len=%d\n", g_wp.vocab_size, g_wp.max_seq_len);
	}
    }
  if (tokenize_delim >= 0)
    {
      if (TOK_NONE == g_tok_kind)
	fail ("--tokenize needs --vocab");
      return tokenize_stdin (tokenize_delim);
    }
  const OrtApi *api = OrtGetApiBase ()->GetApi (ORT_API_VERSION);
  if (!api)
    fail ("Failed to get ONNX Runtime API");
  OrtEnv *env = NULL;
  check_status (api, api->CreateEnv (ORT_LOGGING_LEVEL_WARNING, "onnx-helper", &env), "CreateEnv");
  OrtSessionOptions *opts = NULL;
  check_status (api, api->CreateSessionOptions (&opts), "CreateSessionOptions");
  if (intra_threads < 1)
    intra_threads = 1;
  if (inter_threads < 1)
    inter_threads = 1;
  /* This env has no global thread pools and the session does not call
     DisablePerSessionThreads, so these counts are the ones ONNX Runtime
     actually uses -- unlike the in-process path in the plugin, where sessions
     are bound to the global pools. */
  check_status (api, api->SetIntraOpNumThreads (opts, intra_threads), "SetIntraOpNumThreads");
  check_status (api, api->SetInterOpNumThreads (opts, inter_threads), "SetInterOpNumThreads");
  {
    GraphOptimizationLevel lvl = ORT_ENABLE_ALL;
    if (opt_level == 0)
      lvl = ORT_DISABLE_ALL;
    else if (opt_level == 1)
      lvl = ORT_ENABLE_BASIC;
    else if (opt_level == 2)
      lvl = ORT_ENABLE_EXTENDED;
    check_status (api, api->SetSessionGraphOptimizationLevel (opts, lvl), "SetSessionGraphOptimizationLevel");
  }
  OrtSession *session = NULL;
  if (model_path)
    {
      OrtStatus *st = api->CreateSession (env, model_path, opts, &session);
      if (st)
	{
	  const char *msg = api->GetErrorMessage (st);
	  api->ReleaseStatus (st);
	  fail ("CreateSession: %s", msg ? msg : "unknown");
	}
    }
  if (session && g_tok_kind != TOK_NONE && !pad_to_max)
    {
      g_wp_trim_pad = wp_model_allows_trim (api, session);
      fprintf (stderr, "Padding: %s; requests of up to %d texts, %s, in sub-batches of up to %d texts and %d tokens\n",
	       g_wp_trim_pad ? "to longest text in batch" : "to max_seq_len", g_max_texts,
	       g_sort ? "ordered by length" : "in request order", g_sub_rows, g_tokens_per_batch);
    }

  /* Load GLiNER2 models if --gliner2-dir specified */
  if (gliner2_dir)
    {
      char path_buf[1024];
      OrtStatus *gst;

      /* Load GLiNER2 vocab */
      if (gliner2_vocab)
	{
	  if (sp_load_vocab (gliner2_vocab))
	    fail ("Failed to load GLiNER2 vocab from %s", gliner2_vocab);
	  fprintf (stderr, "GLiNER2: loaded %d vocab entries\n", g_sp.vocab_size);
	}
      else
	{
	  snprintf (path_buf, sizeof (path_buf), "%s/gliner2_vocab.txt", gliner2_dir);
	  if (sp_load_vocab (path_buf))
	    fail ("Failed to load GLiNER2 vocab from %s", path_buf);
	  fprintf (stderr, "GLiNER2: loaded %d vocab entries\n", g_sp.vocab_size);
	}

      /* Load encoder */
      snprintf (path_buf, sizeof (path_buf), "%s/gliner2_encoder.onnx", gliner2_dir);
      gst = api->CreateSession (env, path_buf, opts, &g_gl2_encoder);
      if (gst)
	{
	  const char *msg = api->GetErrorMessage (gst);
	  api->ReleaseStatus (gst);
	  fail ("GLiNER2 encoder: %s", msg ? msg : "unknown");
	}
      fprintf (stderr, "GLiNER2: encoder loaded\n");

      /* Load span_rep */
      snprintf (path_buf, sizeof (path_buf), "%s/gliner2_span_rep.onnx", gliner2_dir);
      gst = api->CreateSession (env, path_buf, opts, &g_gl2_span_rep);
      if (gst)
	{
	  const char *msg = api->GetErrorMessage (gst);
	  api->ReleaseStatus (gst);
	  fail ("GLiNER2 span_rep: %s", msg ? msg : "unknown");
	}
      fprintf (stderr, "GLiNER2: span_rep loaded\n");

      /* Load classifier */
      snprintf (path_buf, sizeof (path_buf), "%s/gliner2_classifier.onnx", gliner2_dir);
      gst = api->CreateSession (env, path_buf, opts, &g_gl2_classifier);
      if (gst)
	{
	  const char *msg = api->GetErrorMessage (gst);
	  api->ReleaseStatus (gst);
	  fail ("GLiNER2 classifier: %s", msg ? msg : "unknown");
	}
      fprintf (stderr, "GLiNER2: classifier loaded\n");

      /* Load count_pred (optional) */
      snprintf (path_buf, sizeof (path_buf), "%s/gliner2_count_pred.onnx", gliner2_dir);
      gst = api->CreateSession (env, path_buf, opts, &g_gl2_count_pred);
      if (gst)
	{
	  fprintf (stderr, "GLiNER2: count_pred not loaded (optional)\n");
	  api->ReleaseStatus (gst);
	}
      else
	fprintf (stderr, "GLiNER2: count_pred loaded\n");

      /* Load count_embed (optional) */
      snprintf (path_buf, sizeof (path_buf), "%s/gliner2_count_embed.onnx", gliner2_dir);
      gst = api->CreateSession (env, path_buf, opts, &g_gl2_count_embed);
      if (gst)
	{
	  fprintf (stderr, "GLiNER2: count_embed not loaded (optional)\n");
	  api->ReleaseStatus (gst);
	}
      else
	fprintf (stderr, "GLiNER2: count_embed loaded\n");

      fprintf (stderr, "GLiNER2: all models ready\n");
    }

  if (server)
    server_loop (api, session);
  else
    {
      /* one-shot stdin line for debug */
      char buf[4096];
      if (!fgets (buf, sizeof (buf), stdin))
	fail ("no input");
      size_t len = strlen (buf);
      if (len && buf[len - 1] == '\n')
	buf[len - 1] = 0;
      ipc_hdr_t hdr;
      memset (&hdr, 0, sizeof (hdr));
      hdr.magic = ONNX_IPC_MAGIC;
      hdr.version = ONNX_IPC_VERSION;
      hdr.batch_count = 1;
      hdr.payload_len = (uint32_t) (sizeof (uint32_t) + strlen (buf));
      char *payload = (char *) malloc (hdr.payload_len);
      uint32_t op = ONNX_IPC_OP_EMBED;
      memcpy (payload, &op, sizeof (uint32_t));
      memcpy (payload + sizeof (uint32_t), buf, strlen (buf));
      process_request (api, session, &hdr, payload, hdr.payload_len);
      free (payload);
    }

  if (session)
    api->ReleaseSession (session);
  if (opts)
    api->ReleaseSessionOptions (opts);
  if (env)
    api->ReleaseEnv (env);
  return 0;
}
