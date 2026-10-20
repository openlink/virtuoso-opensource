/*
 *  onnx_plugin.c
 *
 *  $Id$
 *
 *  Virtuoso ONNX Runtime plugin: model loading and embedding inference.
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
 * Virtuoso ONNX Runtime plugin
 *
 * Provides safe ONNX model loading and embedding inference callable from
 * Virtuoso SQL/PL. The implementation follows the gate-based plugin ABI and
 * uses only the ONNX Runtime C API.
 */

#include "import_gate_virtuoso.h"
#include "sqlver.h"

#include <onnxruntime_c_api.h>

#include <errno.h>
#include <ctype.h>
#include <wchar.h>
#include <setjmp.h>
#include <signal.h>
#include <stdarg.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include <limits.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#ifndef _WIN32
#include <sys/types.h>
#include <sys/wait.h>
#include <pthread.h>
#include <poll.h>
#include <fcntl.h>
#endif

#if defined(_WIN32)
#include <windows.h>
#include <io.h>
#define popen _popen
#define pclose _pclose
#else
#include <unistd.h>
#endif

#ifndef THREAD_LOCAL
#if defined(_MSC_VER)
#define THREAD_LOCAL __declspec(thread)
#else
#define THREAD_LOCAL 
#endif
#endif

#if defined(_WIN32)
#define strtok_r strtok_s
#endif

#define ONNX_PLUGIN_TITLE "virtuoso-onnx"
#define ONNX_PLUGIN_VERSION "0.1.0"
#define ONNX_SQLSTATE_RUNTIME "58030"
#define ONNX_SQLSTATE_INPUT "22023"
#define ONNX_SQLSTATE_CONFIG "42000"

typedef enum
{
  ONNX_MODE_INPROC = 0,
  ONNX_MODE_OUTPROC = 1
} onnx_mode_t;

typedef struct
{
  size_t max_input_bytes;
  size_t max_batch;
  size_t max_output_floats;
  size_t max_tensor_bytes;
  int log_level;		/* 0=ERROR,1=WARN,2=INFO,3=DEBUG */
  onnx_mode_t mode;
  char helper_path[512];
  size_t helper_pool_size;
  int telemetry;		/* 0=off,1=on */
  int helper_timeout_ms;	/* per-IPC-read/write timeout; 0 = block forever */
} onnx_limits_t;

/* Respawn backoff: after this many consecutive helper failures, stop respawning
   for the cooldown below and return a clear SQL error instead, so a helper that
   dies on every request (bad model, unusable binary) cannot drive a tight
   fork/exec loop.  A single successful request resets the counter. */
#define ONNX_RESPAWN_MAX 5
#define ONNX_RESPAWN_COOLDOWN_NS (5ULL * 1000 * 1000 * 1000)	/* 5 seconds */
/* How long onnx_helper_acquire waits for a busy pool before giving up.  Sized
   for a queue of callers each running an inference batch, not for a stall: a
   384-d MiniLM batch of 32 takes ~1.1s, so a pool of 8 with 8 waiters drains
   well inside this. */
#define ONNX_HELPER_LEASE_WAIT_MS 120000
/* Slots reserved in a model's helper array, matching the 1..32 that
   ONNX_CONFIG('helper_pool_size') accepts.  The array is allocated at full
   capacity on first use so that raising helper_pool_size later can bring more
   helpers up in place: callers hold raw onnx_helper_proc_t pointers into this
   array for the length of a request, so it must never be reallocated. */
#define ONNX_HELPER_POOL_MAX 32
/* Bounds on a model's max_seq_len load option: the helper's tokenizer
   (WordPiece, or byte-level BPE for a vocab.json) tokenizes into rows of this
   many tokens.  512 is the BERT family's own position limit; the ceiling
   leaves room for long-context encoders without letting a typo size a tensor
   of millions of tokens. */
#define ONNX_MAX_SEQ_LEN_MIN 2
#define ONNX_MAX_SEQ_LEN_MAX 8192
/* How the helper runs one embedding request: up to max_texts texts, ordered by
   token count (sort=0 keeps request order) and cut into sub-batches of at most
   sub_batch_rows texts and tokens_per_batch padded tokens.  Load options,
   passed to the helper; the defaults and bounds are the helper's own
   (onnx_helper.c).  A request is also bounded in bytes, and the plugin checks
   both limits before sending, because a helper that answers with an error is
   closed. */
#define ONNX_MAX_TEXTS_DEFAULT 4096
#define ONNX_MAX_TEXTS_CEILING 16384
#define ONNX_SUB_BATCH_ROWS_DEFAULT 16
#define ONNX_TOKENS_PER_BATCH_DEFAULT 8192
#define ONNX_TOKENS_PER_BATCH_MIN 16
#define ONNX_TOKENS_PER_BATCH_MAX 1048576
#define ONNX_MAX_REQUEST_BYTES (512 * 1024 * 1024)
#define ONNX_OPT_UNSET (INT_MIN + 1)
/* Directories the operator has declared as model locations -- [ONNX] ModelRoot
   and the plugin LoadPath -- pushed in by the bootstrap via
   ONNX_CONFIG('model_root', ...).  See onnx_path_is_permitted. */
#define ONNX_MODEL_ROOT_MAX 8
/* Maximum rank of a tensor on the generic run path.  ONNX itself has no such
   limit; 4 was simply the size of a stack array here and in onnx_helper.c, and
   it refused ordinary shapes -- an NCHW batch of image crops is rank 5.  Both
   sides must agree: a stale helper answers dcount > its own cap with a clean
   "invalid dims_count", and plugin and helper ship together. */
#define ONNX_MAX_TENSOR_RANK 8
/* Feature scaling declared with the model: center= and scale= hold one value
   per feature, so the cap is a feature count, not a byte count. */
#define ONNX_MAX_SCALER 4096

#define ONNX_IPC_MAGIC 0x584E4E4F /* 'ONNX' little endian */
#define ONNX_IPC_VERSION 1
#define ONNX_IPC_FLAG_TELEMETRY 0x0001
/* Set by the helper on a telemetry response that also carries token counts:
   real tokens, padded tokens and sub-batches, after the two timings. */
#define ONNX_IPC_FLAG_TOKENS 0x0002
#define ONNX_IPC_OP_EMBED 1
#define ONNX_IPC_OP_RUN_F32 2
#define ONNX_IPC_OP_RUN_I64_2 3

#define ONNX_IPC_OP_GLINER2 4
/* Generic run: N named inputs with their own element types, M named outputs.
   A NEW op rather than a change to RUN_F32, because the response format of the
   existing ops is shared with EMBED -- the vector index's path -- and carries
   no type tag.  Adding an op leaves those bytes untouched; an older helper
   answers an unknown op with a clean "unsupported op". */
#define ONNX_IPC_OP_RUN_MULTI 5

typedef struct
{
  uint32_t magic;
  uint16_t version;
  uint16_t flags;
  uint32_t batch_count;
  uint32_t payload_len;
  uint32_t status;
} onnx_ipc_hdr_t;

typedef struct
{
  int alive;
#ifdef _WIN32
  HANDLE hProcess;
  HANDLE hRead;
  HANDLE hWrite;
#else
  pid_t pid;
  int fd_read;
  int fd_write;
#endif
  uint64_t last_used_mono;
  int fail_count;		/* consecutive failures; reset on a good request */
  uint64_t last_fail_mono;	/* time of the most recent failure (backoff) */
  int busy;			/* leased to a request; guarded by m->helper_mtx.
				   A helper's pipe carries one request/response at
				   a time, so exactly one thread may hold it. */
} onnx_helper_proc_t;

typedef struct onnx_model_entry_s
{
  long handle;
  char *path;
  char *input_name;
  char *input_name2;
  char *input_name3;
  char *output_name;
  char *vocab_path;
  char *gliner2_dir;		/* if set, this is a GLiNER2 model directory */
  char *gliner2_vocab_path;	/* SentencePiece vocab for GLiNER2 */
  /* What the CALLER asked for, which is NOT the same as the four fields above:
     onnx_detect_io overwrites those with the names it finds in the graph.  Model
     reuse has to be keyed on the request, or a bare load (which supplies no
     names) can never match the entry its own first call created -- and every
     call opens another ORT session.  NULL here means "the caller named nothing";
     onnx_str_eq treats that as equal to "". */
  char *req_input_name;
  char *req_input_name2;
  char *req_input_name3;
  char *req_output_name;
  /* Feature scaling, as declared at load.  Part of the model's identity: two
     loads of one file with different scalers are different requests and must
     not share an entry, or one caller silently gets the other's scaling. */
  float *center;
  size_t center_count;
  float *scale;
  size_t scale_count;
  size_t output_dim;
  OrtSession *session;
  OrtSessionOptions *session_opts;
  dk_mutex_t *mtx;
  long refcnt;
  int closed;
  struct onnx_model_entry_s *next;
  onnx_helper_proc_t *helpers;
  size_t helper_count;
  dk_mutex_t *helper_mtx;
  size_t helper_rr;
  /* Tokens per text for the helper's tokenizer, from the load option
     max_seq_len; 0 leaves the helper's own default (128).  Part of the model's
     identity, like the scalers: reloading with another value must start
     helpers with it, not hand back the entry already running the old one. */
  int max_seq_len;
  /* How the helper runs an embedding request (see ONNX_MAX_TEXTS_DEFAULT);
     effective values, never -1.  Part of the model's identity too. */
  int max_texts;
  int sub_batch_rows;
  int tokens_per_batch;
  int sort;
  /* ONNX Runtime's thread counts and graph-optimisation level, normalised by
     onnx_threads_norm / onnx_opt_level_norm.  Part of the model's identity
     too: a reload that asks for two threads has to get helpers started with
     two, not the entry already running one. */
  int intra_threads;
  int inter_threads;
  int opt_level;
  /* Pre-formatted for execl: building these between fork() and exec() would
     mean calling snprintf there, which is not async-signal-safe. */
  char intra_threads_str[16];
  char inter_threads_str[16];
  char opt_level_str[16];
  char max_seq_len_str[16];
  char max_texts_str[16];
  char sub_batch_rows_str[16];
  char tokens_per_batch_str[16];
  /* What the helpers did with this model's embedding requests, from their
     telemetry: ONNX_MODEL_INFO reports them, and real / padded tokens is how
     much of the work was text.  Guarded by mtx; zero while telemetry is off. */
  int64 st_requests;
  int64 st_texts;
  int64 st_real_tokens;
  int64 st_padded_tokens;
  int64 st_sub_batches;
} onnx_model_entry_t;

typedef struct
{
  const OrtApi *api;
  OrtEnv *env;
  dk_mutex_t *mtx;		/* protects registry/config/env creation */
  onnx_model_entry_t *models;
  long next_handle;
  onnx_limits_t caps;
  /* helper pool shared defaults for OUTPROC */
  dk_mutex_t *helper_mtx;
  onnx_helper_proc_t *helpers;
  size_t helpers_count;
} onnx_global_t;

static char g_model_roots[ONNX_MODEL_ROOT_MAX][1024];
static size_t g_model_root_count = 0;

static onnx_global_t g_ctx = {
  NULL,			/* api */
  NULL,			/* env */
  NULL,			/* mtx */
  NULL,			/* models */
  1,			/* next_handle */
  {			/* caps */
    512 * 1024,		/* max_input_bytes */
    32,			/* max_batch */
    16384,		/* max_output_floats */
    32 * 1024 * 1024,	/* max_tensor_bytes */
    1,			/* log_level (WARN) */
    ONNX_MODE_OUTPROC,	/* default to safest mode */
    "",			/* helper_path (filled later if provided) */
    2,			/* helper_pool_size */
    1,			/* telemetry on by default */
    30000		/* helper_timeout_ms (30s; a wedged helper is killed, not waited on forever) */
  },
  NULL,			/* helper_mtx */
  NULL,			/* helpers */
  0,			/* helpers_count */
};

/* ---------- Synchronous zombie reaper ---------- */

#ifndef _WIN32
static void onnx_helper_kill_reap (pid_t pid);	/* defined below; used by onnx_model_release */

static void
onnx_reap_zombies (void)
{
  int status;
  /* Reap only OUR OWN helper pids -- never waitpid(-1), which would steal the
     exit status of children forked by other Virtuoso subsystems.  Any helper
     that has exited is marked dead and its pipe ends are closed. */
  onnx_model_entry_t *m = g_ctx.models;
  for (; m; m = m->next)
    {
      if (!m->helpers)
	continue;
      for (size_t i = 0; i < m->helper_count; i++)
	{
	  pid_t pid = m->helpers[i].pid;
	  if (pid > 0 && waitpid (pid, &status, WNOHANG) == pid)
	    {
	      m->helpers[i].alive = 0;
	      m->helpers[i].pid = 0;
	      if (m->helpers[i].fd_read >= 0)
		{ close (m->helpers[i].fd_read); m->helpers[i].fd_read = -1; }
	      if (m->helpers[i].fd_write >= 0)
		{ close (m->helpers[i].fd_write); m->helpers[i].fd_write = -1; }
	    }
	}
    }
}
#endif

/* ---------- Logging helpers ---------- */

static void
onnx_log (int level, const char *fmt, ...)
{
  if (level > g_ctx.caps.log_level)
    return;
  char buf[512];
  va_list ap;
  va_start (ap, fmt);
  vsnprintf (buf, sizeof (buf), fmt, ap);
  va_end (ap);
  if (level == 0)
    log_error ("%s", buf);
  else
    log_info ("%s", buf);
}

static void NORETURN
onnx_fail (const char *sqlstate, const char *virt_code, const char *fmt, ...)
{
  va_list ap;
  va_start (ap, fmt);
  char buf[512];
  vsnprintf (buf, sizeof (buf), fmt, ap);
  va_end (ap);
  sqlr_new_error (sqlstate, virt_code, "%s", buf);
}

/* ---------- Unbox a numeric value to float, handling DV_RDF / DV_NUMERIC ---------- */

#ifndef DV_NUMERIC
#define DV_NUMERIC 219
#endif

static dtp_t
onnx_unbox_float (caddr_t elt, float *out)
{
  dtp_t et = DV_TYPE_OF (elt);
  /* Unwrap DV_RDF boxes (from SPARQL BIND results) */
  if (DV_RDF == et)
    {
      rdf_box_t *rb = (rdf_box_t *) elt;
      elt = rb->rb_box;
      et = DV_TYPE_OF (elt);
    }
  if (et == DV_SINGLE_FLOAT)
    *out = *(float *) elt;
  else if (et == DV_DOUBLE_FLOAT)
    *out = (float) *(double *) elt;
  else if (et == DV_NUMERIC)
    {
      double d = 0.0;
      numeric_to_double ((numeric_t) elt, &d);
      *out = (float) d;
    }
  else if (et == DV_LONG_INT || et == DV_SHORT_INT)
    *out = (float) unbox (elt);
  else
    /* Anything else -- a NULL from a nullable column, a string, a date -- used
       to fall through to unbox(), which reinterprets the box contents as a
       number.  That is not a rounding error: a NULL feature came back as
       7767987847168.0 and the model returned a confident, meaningless answer
       with no error anywhere.  Silence is the worst possible response here, so
       report the type instead and let the caller name the element. */
    return (dtp_t) et;
  return 0;
}

/* Human-readable name for the dtp of a rejected tensor element. */
static const char *
onnx_dtp_name (dtp_t dtp)
{
  switch (dtp)
    {
    case DV_DB_NULL:		return "NULL";
    case DV_STRING:		return "a string";
    case DV_SHORT_STRING_SERIAL: return "a string";
    case DV_UNAME:		return "a name";
    case DV_DATETIME:		return "a datetime";
    case DV_ARRAY_OF_POINTER:	return "an array";
    case DV_RDF:		return "an RDF box";
    default:			return "a non-numeric value";
    }
}

/* ---------- Float array to VVEC-compatible vector ---------- */

/* Embeddings leave as DV_ARRAY_OF_FLOAT, which is what vvec stores and reads back
   with a single memcpy.  This used to explode the tensor into a DV_ARRAY_OF_POINTER
   of boxed doubles, which cost one box per dimension on every embedding. */
static caddr_t
onnx_float_to_vector (caddr_t fbox)
{
  return fbox;
}

/* ---------- Guard layer (signals/SEH) ---------- */

#ifndef _WIN32
static const int onnx_guard_sigs[] = {
  SIGSEGV,
#ifdef SIGBUS
  SIGBUS,
#endif
  SIGILL,
  SIGFPE
};
#define ONNX_GUARD_SIG_COUNT (sizeof (onnx_guard_sigs) / sizeof (onnx_guard_sigs[0]))

typedef struct
{
  int active;
  int hit_sig;
  sigjmp_buf env;
  struct sigaction old[ONNX_GUARD_SIG_COUNT];
} onnx_guard_ctx_t;

static THREAD_LOCAL onnx_guard_ctx_t onnx_guard_ctx = { 0, 0, {0}, {{0}} };

static void
onnx_sig_handler (int sig)
{
  if (onnx_guard_ctx.active)
    {
      onnx_guard_ctx.hit_sig = sig;
      siglongjmp (onnx_guard_ctx.env, 1);
    }
  signal (sig, SIG_DFL);
}

static int
onnx_guard_begin (void)
{
  if (onnx_guard_ctx.active)
    return 0;
  onnx_guard_ctx.active = 1;
  onnx_guard_ctx.hit_sig = 0;
  for (size_t i = 0; i < ONNX_GUARD_SIG_COUNT; i++)
    {
      struct sigaction sa;
      memset (&sa, 0, sizeof (sa));
      sa.sa_handler = onnx_sig_handler;
      sigemptyset (&sa.sa_mask);
      sa.sa_flags = SA_NODEFER;
      sigaction (onnx_guard_sigs[i], &sa, &onnx_guard_ctx.old[i]);
    }
  if (sigsetjmp (onnx_guard_ctx.env, 1))
    {
      int sig = onnx_guard_ctx.hit_sig ? onnx_guard_ctx.hit_sig : SIGSEGV;
      for (size_t i = 0; i < ONNX_GUARD_SIG_COUNT; i++)
	sigaction (onnx_guard_sigs[i], &onnx_guard_ctx.old[i], NULL);
      onnx_guard_ctx.active = 0;
      return sig;
    }
  return 0;
}

static void
onnx_guard_end (void)
{
  if (!onnx_guard_ctx.active)
    return;
  for (size_t i = 0; i < ONNX_GUARD_SIG_COUNT; i++)
    sigaction (onnx_guard_sigs[i], &onnx_guard_ctx.old[i], NULL);
  onnx_guard_ctx.active = 0;
}
#else /* _WIN32 */
static int
onnx_guard_run (int (*fn) (void *), void *arg)
{
  int rc = 0;
  __try
  {
    rc = fn (arg);
  }
  __except (EXCEPTION_EXECUTE_HANDLER)
  {
    rc = -1;
  }
  return rc;
}
#endif

/* Is this model path one the server may open?

   DirsAllowed is the general answer, but it is not the whole policy for models:
   DB.DBA.ONNX_RESOLVE_PATH resolves a model against [ONNX] ModelRoot and the
   plugin LoadPath as well, and the shipped virtuoso.ini puts ModelRoot at
   ../hosting/onnx-models while DirsAllowed is only '., ../vad/'.  Checking
   DirsAllowed alone therefore refused the server's OWN bundled model at
   bootstrap -- 'ONNX bootstrap refreshed 0 model(s)' on a default install,
   which takes the vector index's embedding model with it.

   So accept a path under a root the operator has declared for models, and fall
   back to DirsAllowed for everything else.  The roots arrive from the bootstrap
   through ONNX_CONFIG('model_root', ...); an empty list means DirsAllowed is
   the only rule, which is the right behaviour before the bootstrap has run.  */
static int
onnx_path_is_permitted (const char *path)
{
  char resolved[PATH_MAX];
  const char *cand = path;
  size_t i;

  if (!path || '/' != path[0])
    return 0;			/* relative paths are never pre-approved */
  /* Compare resolved paths.  DB.DBA.ONNX_ABSOLUTE_PATH hands us roots like
     '<db dir>/../hosting/onnx-models', so a plain prefix test matches only a
     candidate spelled with the same '..' in it -- the bundled model, and
     nothing a user would type.  If the candidate cannot be resolved (it does
     not exist yet) fall through to the raw comparison and then to
     file_path_assert; the load is about to fail on the missing file anyway,
     and it should fail saying that. */
  if (realpath (path, resolved))
    cand = resolved;
  for (i = 0; i < g_model_root_count; i++)
    {
      size_t rlen = strlen (g_model_roots[i]);
      if (!rlen)
	continue;
      /* prefix match on a directory boundary, so /srv/models-private does not
	 match a root of /srv/models */
      if (!strncmp (cand, g_model_roots[i], rlen)
	  && ('/' == cand[rlen] || 0 == cand[rlen] || '/' == g_model_roots[i][rlen - 1]))
	return 1;
    }
  return 0;
}

/* ---------- ONNX Runtime helpers ---------- */

static void onnx_copy_trunc (char *dst, size_t cap, const char *src);
static void onnx_apply_scaler (struct onnx_model_entry_s *m, float *buf, size_t len, size_t width);

static void NORETURN
onnx_raise_status (OrtStatus *st, const char *context)
{
  /* GetErrorMessage returns a pointer INTO the status object, so it dies with
     ReleaseStatus.  Copy it out before releasing: formatting it afterwards read
     freed memory, and the runtime's own explanation -- the only thing that says
     why a model would not load -- reached the user as a couple of junk bytes.
     A fixed buffer is deliberate; this runs while raising an error and must not
     allocate, and onnx_fail truncates to 512 bytes regardless. */
  char msg[512];
  const char *ort_msg = (g_ctx.api && st) ? g_ctx.api->GetErrorMessage (st) : NULL;
  msg[0] = 0;
  onnx_copy_trunc (msg, sizeof (msg), ort_msg ? ort_msg : "unknown");
  if (g_ctx.api && st)
    g_ctx.api->ReleaseStatus (st);
  onnx_fail (ONNX_SQLSTATE_RUNTIME, "ONNX", "%s: %s", context, msg);
}

static void
onnx_check_status (OrtStatus *st, const char *context)
{
  if (st)
    onnx_raise_status (st, context);
}

static void
onnx_init_api (void)
{
  if (g_ctx.api)
    return;
  const OrtApiBase *base = OrtGetApiBase ();
  g_ctx.api = base->GetApi (ORT_API_VERSION);
  if (!g_ctx.api)
    onnx_fail (ONNX_SQLSTATE_RUNTIME, "ONNX", "Failed to get ONNX Runtime API");
}

static void
onnx_ensure_env (void)
{
  if (g_ctx.env)
    return;
  mutex_enter (g_ctx.mtx);
  if (!g_ctx.env)
    {
      /* The global pools are sized at one thread each and, since sessions no
	 longer call DisablePerSessionThreads, nothing binds to them: each
	 session sizes its own pools from the model's intra_threads /
	 inter_threads options.  The env is still created with global pools so
	 that a session can opt in later without a second env. */
      OrtThreadingOptions *topt = NULL;
      OrtStatus *st = g_ctx.api->CreateThreadingOptions (&topt);
      if (st)
	{
	  mutex_leave (g_ctx.mtx);
	  onnx_check_status (st, "CreateThreadingOptions");
	}
      st = g_ctx.api->SetGlobalIntraOpNumThreads (topt, 1);
      if (st)
	{
	  g_ctx.api->ReleaseThreadingOptions (topt);
	  mutex_leave (g_ctx.mtx);
	  onnx_check_status (st, "SetGlobalIntraOpNumThreads");
	}
      st = g_ctx.api->SetGlobalInterOpNumThreads (topt, 1);
      if (st)
	{
	  g_ctx.api->ReleaseThreadingOptions (topt);
	  mutex_leave (g_ctx.mtx);
	  onnx_check_status (st, "SetGlobalInterOpNumThreads");
	}
      st = g_ctx.api->CreateEnvWithGlobalThreadPools (ORT_LOGGING_LEVEL_WARNING, ONNX_PLUGIN_TITLE, topt, &g_ctx.env);
      g_ctx.api->ReleaseThreadingOptions (topt);
      if (st)
	{
	  mutex_leave (g_ctx.mtx);
	  onnx_check_status (st, "CreateEnvWithGlobalThreadPools");
	}
    }
  mutex_leave (g_ctx.mtx);
}

static void *
onnx_dup_string (const char *src, size_t len)
{
  char *dst = (char *) dk_alloc (len + 1);
  memcpy (dst, src, len);
  dst[len] = 0;
  return dst;
}

static void
onnx_copy_trunc (char *dst, size_t cap, const char *src)
{
  if (!dst || !cap || !src)
    return;
  size_t n = strlen (src);
  if (n >= cap)
    n = cap - 1;
  memcpy (dst, src, n);
  dst[n] = 0;
}

static uint64_t
onnx_time_monotonic_ns (void)
{
#ifdef _WIN32
  LARGE_INTEGER freq, counter;
  QueryPerformanceFrequency (&freq);
  QueryPerformanceCounter (&counter);
  return (uint64_t) ((counter.QuadPart * 1000000000ULL) / freq.QuadPart);
#else
  struct timespec ts;
  clock_gettime (CLOCK_MONOTONIC, &ts);
  return (uint64_t) ts.tv_sec * 1000000000ULL + (uint64_t) ts.tv_nsec;
#endif
}

/* ---------- Model registry ---------- */

static onnx_model_entry_t *
onnx_model_lookup (long handle)
{
  onnx_model_entry_t *cur = g_ctx.models;
  while (cur)
    {
      if (cur->handle == handle)
	return cur;
      cur = cur->next;
    }
  return NULL;
}

static int
onnx_str_eq (const char *a, const char *b)
{
  if (!a)
    a = "";
  if (!b)
    b = "";
  return !strcmp (a, b);
}

static onnx_model_entry_t *
onnx_model_ref (long handle)
{
  mutex_enter (g_ctx.mtx);
  onnx_model_entry_t *m = onnx_model_lookup (handle);
  if (m && !m->closed)
    {
      mutex_enter (m->mtx);
      m->refcnt++;
      mutex_leave (m->mtx);
    }
  else
    m = NULL;
  mutex_leave (g_ctx.mtx);
  return m;
}

static void
onnx_model_unref (onnx_model_entry_t *m)
{
  if (!m)
    return;
  mutex_enter (m->mtx);
  m->refcnt--;
  mutex_leave (m->mtx);
}

/* Run STMT while holding a reference to model M, and drop that reference even
   if STMT raises.

   Virtuoso signals an error by longjmp, so the `onnx_model_unref (m)` that
   follows every inference call is simply not reached when the inference fails.
   The reference leaked, one per failing call, and because ONNX_UNLOAD_MODEL
   refuses to close a model with references outstanding, a single failed
   inference pinned that model for the life of the server:

     ONNX_RUN_F32 (h, <wrong shape>)   -> Inference failed
     ONNX_UNLOAD_MODEL (h)             -> Model 28 has 1 in-flight calls

   Catch the unwind with the engine's own catcher, release the reference, and
   re-signal the original error unchanged -- the caller sees exactly the error
   the inference produced.  */
#define ONNX_WITH_MODEL_REF(m, stmt)					\
  do {									\
    caddr_t __onnx_unwind = NULL;					\
    QR_RESET_CTX							\
      {									\
	stmt;								\
      }									\
    QR_RESET_CODE							\
      {									\
	__onnx_unwind = thr_get_error_code (__self);			\
	thr_set_error_code (__self, NULL);				\
	/* no POP_QR_RESET: END_QR_RESET does it */			\
      }									\
    END_QR_RESET;							\
    if (NULL != __onnx_unwind)						\
      {									\
	onnx_model_unref (m);						\
	sqlr_resignal (__onnx_unwind);					\
      }									\
  } while (0)

static void
onnx_model_release (onnx_model_entry_t *m)
{
  if (!m)
    return;
  if (m->session)
    g_ctx.api->ReleaseSession (m->session);
  if (m->session_opts)
    g_ctx.api->ReleaseSessionOptions (m->session_opts);
  if (m->path)
    dk_free (m->path, strlen (m->path) + 1);
  if (m->input_name)
    dk_free (m->input_name, strlen (m->input_name) + 1);
  if (m->input_name2)
    dk_free (m->input_name2, strlen (m->input_name2) + 1);
  if (m->input_name3)
    dk_free (m->input_name3, strlen (m->input_name3) + 1);
  if (m->output_name)
    dk_free (m->output_name, strlen (m->output_name) + 1);
  if (m->req_input_name)
    dk_free (m->req_input_name, strlen (m->req_input_name) + 1);
  if (m->req_input_name2)
    dk_free (m->req_input_name2, strlen (m->req_input_name2) + 1);
  if (m->req_input_name3)
    dk_free (m->req_input_name3, strlen (m->req_input_name3) + 1);
  if (m->req_output_name)
    dk_free (m->req_output_name, strlen (m->req_output_name) + 1);
  if (m->center)
    dk_free (m->center, m->center_count * sizeof (float));
  if (m->scale)
    dk_free (m->scale, m->scale_count * sizeof (float));
  if (m->vocab_path)
    dk_free (m->vocab_path, strlen (m->vocab_path) + 1);
  /* Both are onnx_dup_string'd in bif_onnx_load and were the only strings on
     the entry this function did not free.  Reachable from bif_onnx_load's own
     error paths as well as from ONNX_UNLOAD_MODEL, so a GLiNER2 model that
     fails to load repeatedly leaked on every attempt, not only on unload.  */
  if (m->gliner2_dir)
    dk_free (m->gliner2_dir, strlen (m->gliner2_dir) + 1);
  if (m->gliner2_vocab_path)
    dk_free (m->gliner2_vocab_path, strlen (m->gliner2_vocab_path) + 1);
  if (m->mtx)
    mutex_free (m->mtx);
  if (m->helpers)
    {
#ifdef _WIN32
      for (size_t i = 0; i < m->helper_count; i++)
	{
	  onnx_helper_proc_t *hp = &m->helpers[i];
	  if (hp->hWrite)
	    CloseHandle (hp->hWrite);
	  if (hp->hRead)
	    CloseHandle (hp->hRead);
	  if (hp->hProcess)
	    TerminateProcess (hp->hProcess, 0);
	}
#else
      for (size_t i = 0; i < m->helper_count; i++)
	{
	  onnx_helper_proc_t *hp = &m->helpers[i];
	  if (hp->fd_write >= 0)
	    close (hp->fd_write);
	  if (hp->fd_read >= 0)
	    close (hp->fd_read);
	  /* Kill AND reap on teardown: closing the pipes alone leaves a helper
	     that is mid-inference or ignores stdin EOF orphaned (re-parented to
	     init).  A non-blocking WNOHANG would not have waited for it. */
	  onnx_helper_kill_reap (hp->pid);
	  hp->fd_write = hp->fd_read = -1;
	  hp->pid = 0;
	}
#endif
      dk_free (m->helpers, m->helper_count * sizeof (onnx_helper_proc_t));
    }
  if (m->helper_mtx)
    mutex_free (m->helper_mtx);
  dk_free (m, sizeof (*m));
}

static void
onnx_model_register (onnx_model_entry_t *m)
{
  mutex_enter (g_ctx.mtx);
  m->next = g_ctx.models;
  g_ctx.models = m;
  mutex_leave (g_ctx.mtx);
}

static void
onnx_model_remove (long handle)
{
  mutex_enter (g_ctx.mtx);
  onnx_model_entry_t *prev = NULL, *cur = g_ctx.models;
  while (cur)
    {
      if (cur->handle == handle)
	{
	  if (prev)
	    prev->next = cur->next;
	  else
	    g_ctx.models = cur->next;
	  cur->closed = 1;
	  mutex_leave (g_ctx.mtx);
	  onnx_model_release (cur);
	  return;
	}
      prev = cur;
      cur = cur->next;
    }
  mutex_leave (g_ctx.mtx);
}

/* ---------- Option parsing ---------- */

typedef struct
{
  int intra_threads;
  int inter_threads;
  int opt_level;
  char input_name[128];
  char input_name2[128];
  char input_name3[128];
  char output_name[128];
  char vocab_path[512];
  char gliner2_dir[512];
  char gliner2_vocab[512];
  int override_mode;		/* -1 keep default, 0 inproc, 1 outproc */
  int max_seq_len;		/* 0: the helper's default */
  /* ONNX_OPT_UNSET: not given, the default applies; INT_MIN: not a number. */
  int max_texts;
  int sub_batch_rows;
  int tokens_per_batch;
  int sort;
  /* z-scoring applied to the model's own input before inference; see
     onnx_apply_scaler.  NULL when the caller declared none. */
  float *center;
  size_t center_count;
  float *scale;
  size_t scale_count;
} onnx_load_options_t;

static void
onnx_load_options_init (onnx_load_options_t *o)
{
  memset (o, 0, sizeof (*o));
  o->intra_threads = 1;
  o->inter_threads = 1;
  o->opt_level = 99;		/* use ORT_ENABLE_ALL */
  o->override_mode = -1;
  o->max_texts = o->sub_batch_rows = o->tokens_per_batch = o->sort = ONNX_OPT_UNSET;
}

/* An integer option's value, or INT_MIN when it is not one: strtol alone reads
   "abc" as 0, which for sort would be a valid choice nobody made. */
static int
onnx_strict_int (const char *val)
{
  char *end = NULL;
  long v = strtol (val, &end, 10);
  if (end == val || *end || v < -1000000000L || v > 1000000000L)
    return INT_MIN;
  return (int) v;
}

/* Check the request-batching options and put the defaults in, so two loads
   that mean the same thing are the same model.  NULL, or what was wrong. */
static const char *
onnx_batching_options_check (onnx_load_options_t *lo, char *buf, size_t buflen)
{
  if (lo->max_texts == ONNX_OPT_UNSET)
    lo->max_texts = ONNX_MAX_TEXTS_DEFAULT;
  else if (lo->max_texts < 1 || lo->max_texts > ONNX_MAX_TEXTS_CEILING)
    {
      snprintf (buf, buflen, "max_texts must be an integer 1..%d", ONNX_MAX_TEXTS_CEILING);
      return buf;
    }
  if (lo->sub_batch_rows == ONNX_OPT_UNSET)
    lo->sub_batch_rows = ONNX_SUB_BATCH_ROWS_DEFAULT < lo->max_texts ? ONNX_SUB_BATCH_ROWS_DEFAULT : lo->max_texts;
  else if (lo->sub_batch_rows < 1 || lo->sub_batch_rows > lo->max_texts)
    {
      snprintf (buf, buflen, "sub_batch_rows must be an integer 1..%d (the model's max_texts)", lo->max_texts);
      return buf;
    }
  if (lo->tokens_per_batch == ONNX_OPT_UNSET)
    lo->tokens_per_batch = ONNX_TOKENS_PER_BATCH_DEFAULT;
  else if (lo->tokens_per_batch < ONNX_TOKENS_PER_BATCH_MIN || lo->tokens_per_batch > ONNX_TOKENS_PER_BATCH_MAX)
    {
      snprintf (buf, buflen, "tokens_per_batch must be an integer %d..%d",
	  ONNX_TOKENS_PER_BATCH_MIN, ONNX_TOKENS_PER_BATCH_MAX);
      return buf;
    }
  if (lo->sort == ONNX_OPT_UNSET)
    lo->sort = 1;
  else if (lo->sort != 0 && lo->sort != 1)
    {
      snprintf (buf, buflen, "sort must be 0 or 1");
      return buf;
    }
  return NULL;
}

static void
onnx_load_options_free (onnx_load_options_t *o)
{
  if (o->center)
    dk_free (o->center, ONNX_MAX_SCALER * sizeof (float));
  if (o->scale)
    dk_free (o->scale, ONNX_MAX_SCALER * sizeof (float));
  o->center = o->scale = NULL;
  o->center_count = o->scale_count = 0;
}

static void
onnx_parse_kv_options (const char *opt, onnx_load_options_t *opts)
{
  if (!opt || !*opt)
    return;
  char *buf = (char *) dk_alloc (strlen (opt) + 1);
  strcpy (buf, opt);
  char *save = NULL;
  for (char *tok = strtok_r (buf, ";", &save); tok; tok = strtok_r (NULL, ";", &save))
    {
      while (*tok == ' ')
	tok++;
      char *eq = strchr (tok, '=');
      if (!eq)
	continue;
      *eq = 0;
      const char *key = tok;
      const char *val = eq + 1;
      if (!strcmp (key, "center") || !strcmp (key, "scale"))
	{
	  /* A comma-separated list of one value per feature.  Kept beside the
	     model instead of copied into every PL wrapper, where it silently
	     rots the moment anyone retrains. */
	  float *v = (float *) dk_alloc (ONNX_MAX_SCALER * sizeof (float));
	  size_t n = 0;
	  const char *q = val;
	  while (*q && n < ONNX_MAX_SCALER)
	    {
	      char *end = NULL;
	      double d = strtod (q, &end);
	      if (end == q)
		break;
	      v[n++] = (float) d;
	      q = end;
	      while (*q == ' ')
		q++;
	      if (*q == ',')
		q++;
	      else
		break;
	    }
	  if (!strcmp (key, "center"))
	    {
	      if (opts->center)
		dk_free (opts->center, ONNX_MAX_SCALER * sizeof (float));
	      opts->center = v;
	      opts->center_count = n;
	    }
	  else
	    {
	      if (opts->scale)
		dk_free (opts->scale, ONNX_MAX_SCALER * sizeof (float));
	      opts->scale = v;
	      opts->scale_count = n;
	    }
	}
      else if (!strcmp (key, "input"))
	{
	  onnx_copy_trunc (opts->input_name, sizeof (opts->input_name), val);
	}
      else if (!strcmp (key, "input2"))
	{
	  onnx_copy_trunc (opts->input_name2, sizeof (opts->input_name2), val);
	}
      else if (!strcmp (key, "input3"))
	{
	  onnx_copy_trunc (opts->input_name3, sizeof (opts->input_name3), val);
	}
      else if (!strcmp (key, "output"))
	{
	  onnx_copy_trunc (opts->output_name, sizeof (opts->output_name), val);
	}
      else if (!strcmp (key, "intra_threads"))
	{
	  opts->intra_threads = (int) strtol (val, NULL, 10);
	}
      else if (!strcmp (key, "inter_threads"))
	{
	  opts->inter_threads = (int) strtol (val, NULL, 10);
	}
      else if (!strcmp (key, "opt"))
	{
	  opts->opt_level = (int) strtol (val, NULL, 10);
	}
      else if (!strcmp (key, "vocab"))
	{
	  onnx_copy_trunc (opts->vocab_path, sizeof (opts->vocab_path), val);
	}
      else if (!strcmp (key, "max_seq_len"))
	{
	  /* ONNX_MODEL_REFRESH has always sent the registry's max_seq_len as
	     this option; with no case for it, it fell through unparsed and the
	     helper truncated every text at its built-in 128. */
	  opts->max_seq_len = (int) strtol (val, NULL, 10);
	}
      else if (!strcmp (key, "max_texts"))
	opts->max_texts = onnx_strict_int (val);
      else if (!strcmp (key, "sub_batch_rows"))
	opts->sub_batch_rows = onnx_strict_int (val);
      else if (!strcmp (key, "tokens_per_batch"))
	opts->tokens_per_batch = onnx_strict_int (val);
      else if (!strcmp (key, "sort"))
	opts->sort = onnx_strict_int (val);
      else if (!strcmp (key, "gliner2_dir"))
	{
	  onnx_copy_trunc (opts->gliner2_dir, sizeof (opts->gliner2_dir), val);
	}
      else if (!strcmp (key, "gliner2_vocab"))
	{
	  onnx_copy_trunc (opts->gliner2_vocab, sizeof (opts->gliner2_vocab), val);
	}
      else if (!strcmp (key, "mode"))
	{
	  if (!strcmp (val, "inproc"))
	    opts->override_mode = ONNX_MODE_INPROC;
	  else if (!strcmp (val, "outproc"))
	    opts->override_mode = ONNX_MODE_OUTPROC;
	}
    }
  dk_free (buf, strlen (opt) + 1);
}

/* What a load asks ONNX Runtime for, so that two loads meaning the same thing
   compare equal: fewer than one thread is one, and an optimisation level other
   than 0, 1 or 2 is "all" -- the levels onnx_session_apply_options and the
   helper map. */
static int
onnx_threads_norm (int n)
{
  return n > 0 ? n : 1;
}

static int
onnx_opt_level_norm (int lvl)
{
  return (lvl >= 0 && lvl <= 2) ? lvl : 99;
}

static onnx_model_entry_t *
onnx_model_lookup_loaded_by_signature (const char *path, const onnx_load_options_t *lo, onnx_mode_t mode)
{
  onnx_model_entry_t *cur = g_ctx.models;
  while (cur)
    {
      if (!cur->closed
	  && onnx_str_eq (cur->path, path)
	  && onnx_str_eq (cur->req_input_name, lo->input_name)
	  && onnx_str_eq (cur->req_input_name2, lo->input_name2)
	  && onnx_str_eq (cur->req_input_name3, lo->input_name3)
	  && onnx_str_eq (cur->req_output_name, lo->output_name)
	  && onnx_str_eq (cur->vocab_path, lo->vocab_path)
	  && cur->max_seq_len == lo->max_seq_len
	  && cur->max_texts == lo->max_texts
	  && cur->sub_batch_rows == lo->sub_batch_rows
	  && cur->tokens_per_batch == lo->tokens_per_batch
	  && cur->sort == lo->sort
	  && cur->intra_threads == onnx_threads_norm (lo->intra_threads)
	  && cur->inter_threads == onnx_threads_norm (lo->inter_threads)
	  && cur->opt_level == onnx_opt_level_norm (lo->opt_level)
	  && onnx_str_eq (cur->gliner2_dir, lo->gliner2_dir)
	  && onnx_str_eq (cur->gliner2_vocab_path, lo->gliner2_vocab)
	  && cur->center_count == lo->center_count
	  && cur->scale_count == lo->scale_count
	  && (!cur->center_count
	      || !memcmp (cur->center, lo->center, cur->center_count * sizeof (float)))
	  && (!cur->scale_count
	      || !memcmp (cur->scale, lo->scale, cur->scale_count * sizeof (float))))
	{
	  if ((mode == ONNX_MODE_OUTPROC || cur->gliner2_dir) ? (cur->session == NULL) : (cur->session != NULL))
	    return cur;
	}
      cur = cur->next;
    }
  return NULL;
}

/* ---------- ONNX session helpers ---------- */

static OrtStatus *
onnx_session_apply_options (OrtSessionOptions *opts, const onnx_load_options_t *lo)
{
  OrtStatus *st = NULL;
  /* Deliberately NOT DisablePerSessionThreads.  That call binds the session to
     the env's global thread pools, and ONNX Runtime then ignores per-session
     thread counts -- so the intra_threads/inter_threads model options below
     were parsed, applied, and silently unable to do anything.  Sessions size
     their own pools instead, which is what those options promise.  The env's
     global pools stay at one thread each and are now simply unused; see
     onnx_ensure_env. */
  st = g_ctx.api->SetIntraOpNumThreads (opts, lo->intra_threads);
  if (st)
    return st;
  st = g_ctx.api->SetInterOpNumThreads (opts, lo->inter_threads);
  if (st)
    return st;
  GraphOptimizationLevel lvl = ORT_ENABLE_ALL;
  if (lo->opt_level == 0)
    lvl = ORT_DISABLE_ALL;
  else if (lo->opt_level == 1)
    lvl = ORT_ENABLE_BASIC;
  else if (lo->opt_level == 2)
    lvl = ORT_ENABLE_EXTENDED;
  st = g_ctx.api->SetSessionGraphOptimizationLevel (opts, lvl);
  return st;
}

static OrtStatus *
onnx_detect_io (OrtSession *session, onnx_model_entry_t *m)
{
  OrtAllocator *alloc = NULL;
  OrtStatus *st = g_ctx.api->GetAllocatorWithDefaultOptions (&alloc);
  if (st)
    return st;
  size_t in_count = 0;
  st = g_ctx.api->SessionGetInputCount (session, &in_count);
  if (st)
    return st;
  if (!m->input_name)
    {
      char *name = NULL;
      st = g_ctx.api->SessionGetInputName (session, 0, alloc, &name);
      if (st)
	return st;
      if (name)
	{
	  m->input_name = onnx_dup_string (name, strlen (name));
	  alloc->Free (alloc, name);
	}
    }
  if (in_count > 1 && !m->input_name2)
    {
      char *name = NULL;
      st = g_ctx.api->SessionGetInputName (session, 1, alloc, &name);
      if (st)
	return st;
      if (name)
	{
	  m->input_name2 = onnx_dup_string (name, strlen (name));
	  alloc->Free (alloc, name);
	}
    }
  if (in_count > 2 && !m->input_name3)
    {
      char *name = NULL;
      st = g_ctx.api->SessionGetInputName (session, 2, alloc, &name);
      if (st)
	return st;
      if (name)
	{
	  m->input_name3 = onnx_dup_string (name, strlen (name));
	  alloc->Free (alloc, name);
	}
    }
  if (!m->output_name)
    {
      char *name = NULL;
      st = g_ctx.api->SessionGetOutputName (session, 0, alloc, &name);
      if (st)
	return st;
      if (name)
	{
	  m->output_name = onnx_dup_string (name, strlen (name));
	  alloc->Free (alloc, name);
	}
    }
  return NULL;
}

static int
onnx_get_output_elements (OrtSession *session, const char *output_name, size_t *elem_out, OrtStatus **st_out, char *errbuf, size_t errlen)
{
  (void) output_name;
  OrtAllocator *alloc = NULL;
  OrtStatus *st = NULL;
  /* Before the first goto: cleanup releases it when it is set. */
  OrtTypeInfo *type_info = NULL;
  const char *err_ctx = NULL;

  *st_out = NULL;

  st = g_ctx.api->GetAllocatorWithDefaultOptions (&alloc);
  if (st)
    {
      err_ctx = "GetAllocatorWithDefaultOptions";
      goto cleanup;
    }
  st = g_ctx.api->SessionGetOutputTypeInfo (session, 0, &type_info);
  if (st)
    {
      err_ctx = "SessionGetOutputTypeInfo";
      goto cleanup;
    }
  const OrtTensorTypeAndShapeInfo *shape_info = NULL;
  g_ctx.api->CastTypeInfoToTensorInfo (type_info, &shape_info);
  if (!shape_info)
    {
      g_ctx.api->ReleaseTypeInfo (type_info);
      snprintf (errbuf, errlen, "Output is not a tensor");
      return -1;
    }
  size_t dim_count = 0;
  st = g_ctx.api->GetDimensionsCount (shape_info, &dim_count);
  if (st)
    {
      err_ctx = "GetDimensionsCount";
      goto cleanup;
    }
  if (dim_count <= 0)
    {
      g_ctx.api->ReleaseTypeInfo (type_info);
      snprintf (errbuf, errlen, "Output dimension count invalid");
      return -1;
    }
  size_t elem_count = 0;
  st = g_ctx.api->GetTensorShapeElementCount (shape_info, &elem_count);
  if (st)
    {
      err_ctx = "GetTensorShapeElementCount";
      goto cleanup;
    }
  g_ctx.api->ReleaseTypeInfo (type_info);
  *elem_out = elem_count;
  return 0;

cleanup:
  if (type_info)
    g_ctx.api->ReleaseTypeInfo (type_info);
  if (st)
    *st_out = st;
  if (err_ctx)
    onnx_copy_trunc (errbuf, errlen, err_ctx);
  return -1;
}

/* ---------- Wide string (NVARCHAR) to UTF-8 conversion ---------- */

static caddr_t
onnx_wide_to_utf8 (const wchar_t *wide, size_t wchar_count)
{
  /* Worst case: each wchar_t -> 4 UTF-8 bytes */
  size_t max_bytes = wchar_count * 4 + 1;
  caddr_t utf8 = dk_alloc_box (max_bytes, DV_STRING);
  size_t pos = 0;
  for (size_t i = 0; i < wchar_count; i++)
    {
      uint32_t cp = (uint32_t) wide[i];
      if (cp < 0x80)
	utf8[pos++] = (char) cp;
      else if (cp < 0x800)
	{
	  utf8[pos++] = (char) (0xC0 | (cp >> 6));
	  utf8[pos++] = (char) (0x80 | (cp & 0x3F));
	}
      else if (cp < 0x10000)
	{
	  utf8[pos++] = (char) (0xE0 | (cp >> 12));
	  utf8[pos++] = (char) (0x80 | ((cp >> 6) & 0x3F));
	  utf8[pos++] = (char) (0x80 | (cp & 0x3F));
	}
      else if (cp < 0x110000)
	{
	  utf8[pos++] = (char) (0xF0 | (cp >> 18));
	  utf8[pos++] = (char) (0x80 | ((cp >> 12) & 0x3F));
	  utf8[pos++] = (char) (0x80 | ((cp >> 6) & 0x3F));
	  utf8[pos++] = (char) (0x80 | (cp & 0x3F));
	}
    }
  utf8[pos] = 0;
  /* Shrink to actual size */
  if (pos + 1 < max_bytes)
    {
      caddr_t trimmed = dk_alloc_box (pos + 1, DV_STRING);
      memcpy (trimmed, utf8, pos + 1);
      dk_free_box (utf8);
      return trimmed;
    }
  return utf8;
}

/* Get a string argument, accepting both DV_STRING and DV_WIDE/DV_LONG_WIDE.
   For wide strings, converts to UTF-8 and sets *to_free to the allocated box
   (caller must dk_free_box it).  For narrow strings, *to_free is set to NULL. */
static caddr_t
onnx_get_string_arg (caddr_t *qst, caddr_t *err, state_slot_t **args,
		     int nth, const char *func, caddr_t *to_free)
{
  caddr_t val = bif_arg (qst, args, nth, func);
  *to_free = NULL;
  if (!val)
    onnx_fail (ONNX_SQLSTATE_INPUT, "ONNX", "%s: argument %d is NULL", func, nth);
  dtp_t dtp = DV_TYPE_OF (val);
  if (DV_STRING == dtp || DV_UNAME == dtp)
    return val;
  if (DV_WIDE == dtp || DV_LONG_WIDE == dtp)
    {
      size_t wchar_count = (box_length (val) / sizeof (wchar_t)) - 1;
      caddr_t utf8 = onnx_wide_to_utf8 ((const wchar_t *) val, wchar_count);
      *to_free = utf8;
      return utf8;
    }
  onnx_fail (ONNX_SQLSTATE_INPUT, "ONNX",
	    "%s: argument %d must be a string (VARCHAR or NVARCHAR), not type %d",
	    func, nth, (int) dtp);
  return NULL; /* not reached */
}

/* ---------- Input validation ---------- */

static void
onnx_validate_text (const char *func, const char *text, size_t len)
{
  if (!text)
    onnx_fail (ONNX_SQLSTATE_INPUT, "ONNX", "%s: input is NULL", func);
  if (len > g_ctx.caps.max_input_bytes)
    onnx_fail (ONNX_SQLSTATE_INPUT, "ONNX", "%s: input exceeds max_input_bytes (%lu > %lu)", func, (unsigned long) len, (unsigned long) g_ctx.caps.max_input_bytes);
}

static void
onnx_validate_batch (const char *func, size_t count)
{
  if (count == 0)
    onnx_fail (ONNX_SQLSTATE_INPUT, "ONNX", "%s: empty batch", func);
  if (count > g_ctx.caps.max_batch)
    onnx_fail (ONNX_SQLSTATE_INPUT, "ONNX", "%s: batch too large (%lu > %lu)", func, (unsigned long) count, (unsigned long) g_ctx.caps.max_batch);
}

static int
onnx_validate_output_size (size_t elements, char *errbuf, size_t buflen)
{
  size_t bytes = elements * sizeof (float);
  if (elements > g_ctx.caps.max_output_floats)
    {
      snprintf (errbuf, buflen, "Output too large (%lu elements, max %lu)", (unsigned long) elements, (unsigned long) g_ctx.caps.max_output_floats);
      return -1;
    }
  if (bytes > g_ctx.caps.max_tensor_bytes)
    {
      snprintf (errbuf, buflen, "Output exceeds max tensor bytes (%lu > %lu)", (unsigned long) bytes, (unsigned long) g_ctx.caps.max_tensor_bytes);
      return -1;
    }
  return 0;
}

/* ---------- Out-of-process (helper) inference ---------- */

#ifndef _WIN32
/* Wait until fd is ready for events (POLLIN or POLLOUT) within the configured
   helper timeout.  Returns 1 = ready, 0 = timed out, -1 = error.  A timeout is
   how a wedged-but-alive helper is escaped: the caller treats it as a failure,
   which closes (and kills) the helper rather than blocking the DB worker forever.
   EINTR is retried so an unrelated signal does not look like a helper death. */
static int
onnx_wait_fd (int fd, short events)
{
  int timeout_ms = g_ctx.caps.helper_timeout_ms > 0 ? g_ctx.caps.helper_timeout_ms : -1;
  if (timeout_ms < 0)
    return 1;			/* blocking mode: let read()/write() wait */
  for (;;)
    {
      struct pollfd pfd;
      int pr;
      pfd.fd = fd;
      pfd.events = events;
      pfd.revents = 0;
      pr = poll (&pfd, 1, timeout_ms);
      if (pr > 0)
	return 1;
      if (pr == 0)
	return 0;		/* timeout */
      if (errno == EINTR)
	continue;
      return -1;
    }
}

static ssize_t
onnx_read_exact (int fd, void *buf, size_t len)
{
  size_t got = 0;
  while (got < len)
    {
      ssize_t n;
      int ready = onnx_wait_fd (fd, POLLIN);
      if (ready <= 0)
	return ready ? -1 : -2;	/* poll error, or -2: helper_timeout_ms passed with no answer */
      n = read (fd, (char *) buf + got, len - got);
      if (n < 0 && errno == EINTR)
	continue;
      if (n <= 0)
	return -1;
      got += (size_t) n;
    }
  return (ssize_t) got;
}

static ssize_t
onnx_write_exact (int fd, const void *buf, size_t len)
{
  size_t sent = 0;
  while (sent < len)
    {
      ssize_t n;
      if (onnx_wait_fd (fd, POLLOUT) <= 0)
	return -1;		/* wedged helper not draining its stdin -> fail, don't hang */
      n = write (fd, (const char *) buf + sent, len - sent);
      if (n < 0 && errno == EINTR)
	continue;
      if (n <= 0)
	return -1;
      sent += (size_t) n;
    }
  return (ssize_t) sent;
}
#else
static int
onnx_read_exact (HANDLE h, void *buf, size_t len)
{
  DWORD got = 0, total = 0;
  while (total < len)
    {
      if (!ReadFile (h, (char *) buf + total, (DWORD) (len - total), &got, NULL) || got == 0)
	return -1;
      total += got;
    }
  return (int) total;
}

static int
onnx_write_exact (HANDLE h, const void *buf, size_t len)
{
  DWORD sent = 0, total = 0;
  while (total < len)
    {
      if (!WriteFile (h, (const char *) buf + total, (DWORD) (len - total), &sent, NULL))
	return -1;
      total += sent;
    }
  return (int) total;
}
#endif

#ifndef _WIN32
/* Terminate a helper and REAP it, so it is never left an orphan or a zombie:
   SIGTERM, wait up to ~100 ms, then SIGKILL and a blocking wait.  Bounded, and
   the common case (an already-dead helper being replaced) returns immediately on
   the first WNOHANG.  Used on respawn (helper died) and on shutdown (helper may
   still be alive or wedged mid-inference). */
static void
onnx_helper_kill_reap (pid_t pid)
{
  int st, k;
  if (pid <= 0)
    return;
  kill (pid, SIGTERM);
  for (k = 0; k < 100; k++)
    {
      if (waitpid (pid, &st, WNOHANG) != 0)
	return;			/* reaped (or gone) */
      {
	struct timespec ts = { 0, 1000000 };	/* 1 ms */
	nanosleep (&ts, NULL);
      }
    }
  kill (pid, SIGKILL);
  waitpid (pid, &st, 0);	/* blocking: SIGKILL cannot be caught, so this returns promptly */
}

/* Registered with atexit() at plugin load.  Virtuoso's `shutdown;` exits the
   process without unloading plugins (vonnx_disconnect does not run), so this is
   the reliable point to make sure no helper is left orphaned on a normal exit --
   including a wedged/frozen helper that never observes its stdin closing.
   (A SIGKILL-ed server cannot run atexit; there, responsive helpers still
   self-exit when their stdin pipe hits EOF as the parent dies.)  kill() is
   async-signal-safe; this is best-effort, so it takes no locks and does not
   waitpid -- the exiting process's children are reaped by init. */
static void
onnx_atexit_kill_helpers (void)
{
  onnx_model_entry_t *m = g_ctx.models;
  for (; m; m = m->next)
    {
      size_t i;
      if (!m->helpers)
	continue;
      for (i = 0; i < m->helper_count; i++)
	if (m->helpers[i].pid > 0)
	  kill (m->helpers[i].pid, SIGKILL);
    }
}
#endif

static void
onnx_helper_close (onnx_helper_proc_t *hp)
{
  if (!hp)
    return;
#ifdef _WIN32
  if (hp->hWrite)
    CloseHandle (hp->hWrite);
  if (hp->hRead)
    CloseHandle (hp->hRead);
  if (hp->hProcess)
    TerminateProcess (hp->hProcess, 0);
  hp->hWrite = hp->hRead = hp->hProcess = NULL;
#else
  if (hp->fd_write >= 0)
    close (hp->fd_write);
  if (hp->fd_read >= 0)
    close (hp->fd_read);
  onnx_helper_kill_reap (hp->pid);	/* always reap: never leak a zombie/orphan */
  hp->fd_write = hp->fd_read = -1;
  hp->pid = 0;
#endif
  hp->alive = 0;
}

static int
onnx_spawn_helper (onnx_model_entry_t *m, onnx_helper_proc_t *hp)
{
  if (!g_ctx.caps.helper_path[0])
    return -1;
#ifndef _WIN32
  onnx_reap_zombies ();
#endif
#ifdef _WIN32
  SECURITY_ATTRIBUTES sa = { sizeof (SECURITY_ATTRIBUTES), NULL, TRUE };
  HANDLE hStdinRead = NULL, hStdinWrite = NULL, hStdoutRead = NULL, hStdoutWrite = NULL;
  if (!CreatePipe (&hStdinRead, &hStdinWrite, &sa, 0))
    return -1;
  if (!CreatePipe (&hStdoutRead, &hStdoutWrite, &sa, 0))
    {
      CloseHandle (hStdinRead);
      CloseHandle (hStdinWrite);
      return -1;
    }
  SetHandleInformation (hStdinWrite, HANDLE_FLAG_INHERIT, 0);
  SetHandleInformation (hStdoutRead, HANDLE_FLAG_INHERIT, 0);
  char cmd[1024];
  if (m->vocab_path)
    snprintf (cmd, sizeof (cmd), "\"%s\" --model \"%s\" --vocab \"%s\" --server", g_ctx.caps.helper_path, m->path, m->vocab_path);
  else
    snprintf (cmd, sizeof (cmd), "\"%s\" --model \"%s\" --server", g_ctx.caps.helper_path, m->path);
  STARTUPINFOA si;
  PROCESS_INFORMATION pi;
  ZeroMemory (&si, sizeof (si));
  ZeroMemory (&pi, sizeof (pi));
  si.cb = sizeof (si);
  si.hStdInput = hStdinRead;
  si.hStdOutput = hStdoutWrite;
  si.hStdError = hStdoutWrite;
  si.dwFlags |= STARTF_USESTDHANDLES;
  if (!CreateProcessA (NULL, cmd, NULL, NULL, TRUE, 0, NULL, NULL, &si, &pi))
    {
      CloseHandle (hStdinRead);
      CloseHandle (hStdinWrite);
      CloseHandle (hStdoutRead);
      CloseHandle (hStdoutWrite);
      return -1;
    }
  CloseHandle (hStdinRead);
  CloseHandle (hStdoutWrite);
  hp->hWrite = hStdinWrite;
  hp->hRead = hStdoutRead;
  hp->hProcess = pi.hProcess;
  CloseHandle (pi.hThread);
#else
  int to_child[2] = { -1, -1 }, from_child[2] = { -1, -1 };
  long maxfd;
  /* Build the helper's argv here, in the parent: the child may only call
     async-signal-safe functions between fork() and exec(), which rules out the
     snprintf that formatting the thread counts would need.  The array lives on
     this frame and is inherited by the child. */
  const char *hargv[32];
  int hargc = 0;
  hargv[hargc++] = g_ctx.caps.helper_path;
  if (m->gliner2_dir)
    {
      hargv[hargc++] = "--gliner2-dir";
      hargv[hargc++] = m->gliner2_dir;
      if (m->gliner2_vocab_path)
	{
	  hargv[hargc++] = "--gliner2-vocab";
	  hargv[hargc++] = m->gliner2_vocab_path;
	}
    }
  else
    {
      hargv[hargc++] = "--model";
      hargv[hargc++] = m->path;
      if (m->vocab_path)
	{
	  hargv[hargc++] = "--vocab";
	  hargv[hargc++] = m->vocab_path;
	}
      if (m->output_name)
	{
	  hargv[hargc++] = "--output";
	  hargv[hargc++] = m->output_name;
	}
      /* Only the tokenizer reads it, and only with a vocab. */
      if (m->vocab_path && m->max_seq_len > 0)
	{
	  hargv[hargc++] = "--max-seq-len";
	  hargv[hargc++] = m->max_seq_len_str;
	}
      hargv[hargc++] = "--intra-threads";
      hargv[hargc++] = m->intra_threads_str;
      hargv[hargc++] = "--inter-threads";
      hargv[hargc++] = m->inter_threads_str;
      hargv[hargc++] = "--opt-level";
      hargv[hargc++] = m->opt_level_str;
      hargv[hargc++] = "--max-texts";
      hargv[hargc++] = m->max_texts_str;
      /* Sub-batches are the tokenizer path's, like --max-seq-len. */
      if (m->vocab_path)
	{
	  hargv[hargc++] = "--sub-batch-rows";
	  hargv[hargc++] = m->sub_batch_rows_str;
	  hargv[hargc++] = "--tokens-per-batch";
	  hargv[hargc++] = m->tokens_per_batch_str;
	  if (!m->sort)
	    hargv[hargc++] = "--no-sort";
	}
    }
  hargv[hargc++] = "--server";
  hargv[hargc] = NULL;
  if (pipe (to_child) || pipe (from_child))
    return -1;
  /* _SC_OPEN_MAX is read in the parent: it is not guaranteed async-signal-safe,
     so it must not be called between fork() and execl().  The value is inherited
     by the child on the stack. */
  maxfd = sysconf (_SC_OPEN_MAX);
  if (maxfd < 0 || maxfd > 65536)
    maxfd = 65536;
  pid_t pid = fork ();
  if (pid == 0)
    {
      long fd;
      dup2 (to_child[0], STDIN_FILENO);
      dup2 (from_child[1], STDOUT_FILENO);
      /* stderr left as-is (goes to Virtuoso log, NOT the IPC pipe).  Close every
         OTHER inherited descriptor before exec -- database files, listening and
         client sockets, and other helpers' pipe ends -- so none leak into the
         helper (an inherited listener keeps the port bound after a restart; an
         inherited DB fd is a corruption vector).  This runs after the dup2s, so
         fds 0/1/2 survive; close() is async-signal-safe.  It also subsumes the
         four raw pipe ends, which are all >= 3. */
      for (fd = 3; fd < maxfd; fd++)
	close ((int) fd);
      execv (g_ctx.caps.helper_path, (char *const *) hargv);
      _exit (127);
    }
  if (pid < 0)
    {
      close (to_child[0]); close (to_child[1]);
      close (from_child[0]); close (from_child[1]);
      return -1;
    }
  close (to_child[0]);
  close (from_child[1]);
  /* Mark the ends we keep close-on-exec so a subsequently forked helper (or any
     other exec in the server) does not inherit this helper's pipe ends -- an
     inherited write end would keep the peer from ever seeing EOF. */
  fcntl (to_child[1], F_SETFD, FD_CLOEXEC);
  fcntl (from_child[0], F_SETFD, FD_CLOEXEC);
  hp->pid = pid;
  hp->fd_write = to_child[1];
  hp->fd_read = from_child[0];
#endif
  hp->alive = 1;
  hp->last_used_mono = onnx_time_monotonic_ns ();
  return 0;
}

/* Record that a helper failed to serve a request (dead pipe, timeout, bad
   response).  Drives the respawn backoff in onnx_helper_try_respawn. */
static void
onnx_helper_note_fail (onnx_helper_proc_t *hp)
{
  if (!hp)
    return;
  hp->fail_count++;
  hp->last_fail_mono = onnx_time_monotonic_ns ();
}

/* A successful request clears the failure streak. */
static void
onnx_helper_note_ok (onnx_helper_proc_t *hp)
{
  if (hp)
    hp->fail_count = 0;
}

/* Respawn a helper, but refuse (return -1 without forking) once it has failed
   ONNX_RESPAWN_MAX times in a row and we are still inside the cooldown window.
   This is what turns a helper that dies on every request into a bounded "spawn a
   few times, then return a clean SQL error for a few seconds" instead of an
   unbounded fork/exec loop.  Returns 0 if a live helper is now spawned. */
static int
onnx_helper_try_respawn (onnx_model_entry_t *m, onnx_helper_proc_t *hp)
{
  if (hp->fail_count >= ONNX_RESPAWN_MAX
      && (onnx_time_monotonic_ns () - hp->last_fail_mono) < ONNX_RESPAWN_COOLDOWN_NS)
    return -1;			/* in backoff: do not fork */
  if (onnx_spawn_helper (m, hp))
    {
      onnx_helper_note_fail (hp);
      return -1;
    }
  return 0;
}

/* Lease a helper for the duration of one request/response exchange.
   A helper is a single process behind a single pair of pipes: two threads that
   write requests to it interleave on the same descriptor and then read each
   other's response headers, which surfaces as a nonsense element count
   ("Output too large (1261159000 elements)") and a killed helper.  Round-robin
   alone does not prevent that -- it only spreads the *choice*, and a caller
   that lags a full cycle collides with one that does not.  So a lease is
   mandatory, not an optimisation: acquire marks the helper busy and only an
   idle one is ever handed out.

   Every acquire must be matched by onnx_helper_release, including on the error
   paths -- onnx_fail is NORETURN (it longjmps out through sqlr_new_error), so a
   fail with the lease still held would retire that helper from the pool for the
   life of the process.

   Waits, bounded, if the whole pool is busy: callers are rate-limited by the
   pool rather than falling back to an unsafe share. */
static onnx_helper_proc_t *
onnx_helper_acquire (onnx_model_entry_t *m)
{
  int waited_ms = 0;
  if (!m->helpers || !m->helper_mtx || !m->helper_count)
    return NULL;
  for (;;)
    {
      int any_alive = 0;
      mutex_enter (m->helper_mtx);
      if (!m->helper_count)
	{
	  mutex_leave (m->helper_mtx);
	  return NULL;
	}
      size_t start = m->helper_rr % m->helper_count;
      for (size_t i = 0; i < m->helper_count; i++)
	{
	  size_t idx = (start + i) % m->helper_count;
	  onnx_helper_proc_t *hp = &m->helpers[idx];
	  if (!hp->alive)
	    continue;
	  any_alive = 1;
	  if (hp->busy)
	    continue;
	  hp->busy = 1;
	  m->helper_rr = idx + 1;
	  mutex_leave (m->helper_mtx);
	  return hp;
	}
      mutex_leave (m->helper_mtx);
      if (!any_alive)
	return NULL;		/* pool is dead: let the caller respawn */
      /* Every live helper is serving someone.  Wait for one rather than
	 doubling up on a pipe. */
      if (waited_ms >= ONNX_HELPER_LEASE_WAIT_MS)
	return NULL;
      poll (NULL, 0, 1);
      waited_ms++;
    }
}

/* Return a leased helper to the pool.  Safe to call with NULL. */
static void
onnx_helper_release (onnx_model_entry_t *m, onnx_helper_proc_t *hp)
{
  if (!hp || !m || !m->helper_mtx)
    return;
  mutex_enter (m->helper_mtx);
  hp->busy = 0;
  mutex_leave (m->helper_mtx);
}

/* Lease a helper, restarting a dead one if the pool has no live member.
   The respawn takes the lease *first*, so it can never close the descriptors of
   a helper another thread is mid-request on -- which is what respawning
   m->helpers[0] unconditionally used to risk. */
static onnx_helper_proc_t *
onnx_helper_acquire_or_respawn (onnx_model_entry_t *m)
{
  onnx_helper_proc_t *hp = onnx_helper_acquire (m);
  if (hp)
    return hp;
  if (!m->helpers || !m->helper_mtx)
    return NULL;
  mutex_enter (m->helper_mtx);
  for (size_t i = 0; i < m->helper_count; i++)
    {
      onnx_helper_proc_t *cand = &m->helpers[i];
      if (cand->busy || cand->alive)
	continue;
      cand->busy = 1;
      mutex_leave (m->helper_mtx);
      if (onnx_helper_try_respawn (m, cand))
	{
	  onnx_helper_release (m, cand);
	  return NULL;		/* in respawn backoff */
	}
      return cand;
    }
  mutex_leave (m->helper_mtx);
  return NULL;
}

/* Bring this model's helper pool up to the configured size.
   Serialised on g_ctx.mtx, the registry/creation lock.  An unguarded
   "if (m->helpers) return 0;" let concurrent first-callers each build a pool
   and overwrite m->helpers, m->helper_mtx and m->helper_count, leaking the
   previous arrays, orphaning their helper processes, and leaving threads that
   had already captured an hp pointer using a descriptor from a replaced array.
   Measured with the default pool size of 2: the first concurrent load took the
   server from 2 live helpers to 10.

   Also grows in place when helper_pool_size is raised after the model is
   already in use -- the common case, since a caller only knows it is about to
   run a parallel load once the model is loaded.  The array is allocated at
   ONNX_HELPER_POOL_MAX capacity precisely so growth spawns into existing slots:
   callers hold raw pointers into it across a request, so it is never
   reallocated.  It does not shrink; that would mean killing helpers that other
   threads may be mid-request on. */
static int
onnx_helper_ensure_pool (onnx_model_entry_t *m)
{
  size_t want, i;

  if (!g_ctx.caps.helper_path[0])
    return -1;
  want = g_ctx.caps.helper_pool_size ? g_ctx.caps.helper_pool_size : 1;
  if (want > ONNX_HELPER_POOL_MAX)
    want = ONNX_HELPER_POOL_MAX;
  if (m->helpers && m->helper_count >= want)
    return 0;			/* fast path */
  mutex_enter (g_ctx.mtx);
  if (!m->helpers)
    {
      onnx_helper_proc_t *pool =
	  (onnx_helper_proc_t *) dk_alloc (ONNX_HELPER_POOL_MAX * sizeof (onnx_helper_proc_t));
      memset (pool, 0, ONNX_HELPER_POOL_MAX * sizeof (onnx_helper_proc_t));
      for (i = 0; i < ONNX_HELPER_POOL_MAX; i++)
	{
#ifndef _WIN32
	  pool[i].fd_read = -1;
	  pool[i].fd_write = -1;
#endif
	}
      m->helper_mtx = mutex_allocate ();
      m->helper_count = 0;
      /* Publish the (empty) array before spawning: helper_count is what bounds
	 every scan, so an array with count 0 is inert but valid. */
      m->helpers = pool;
    }
  for (i = m->helper_count; i < want; i++)
    {
      if (onnx_spawn_helper (m, &m->helpers[i]))
	{
	  onnx_log (0, "Failed to spawn helper %lu for model %s", (unsigned long) i, m->path);
	  m->helpers[i].alive = 0;
	}
      /* Publish one slot at a time: a concurrent acquire may scan up to
	 helper_count, and every slot below it is fully initialised. */
      mutex_enter (m->helper_mtx);
      m->helper_count = i + 1;
      mutex_leave (m->helper_mtx);
    }
  mutex_leave (g_ctx.mtx);
  return 0;
}

static int
onnx_ipc_send_request (onnx_helper_proc_t *hp, const onnx_ipc_hdr_t *hdr, const void *payload, size_t payload_len)
{
#ifdef _WIN32
  if (onnx_write_exact (hp->hWrite, hdr, sizeof (*hdr)) < 0)
    return -1;
  if (payload_len && onnx_write_exact (hp->hWrite, payload, payload_len) < 0)
    return -1;
#else
  if (onnx_write_exact (hp->fd_write, hdr, sizeof (*hdr)) < 0)
    return -1;
  if (payload_len && onnx_write_exact (hp->fd_write, payload, payload_len) < 0)
    return -1;
#endif
  return 0;
}

/* Copy the helper's error text out of the response buffer.  Two reasons it
   cannot be used in place: write_error () frames it as [uint32 len][len bytes]
   with no terminator, and every caller frees `resp` before it throws. */
static void
onnx_helper_err_text (char *out, size_t out_sz, const onnx_ipc_hdr_t *rhdr,
    const char *resp, size_t resp_cap)
{
  size_t avail, n;
  uint32_t msg_len = 0;
  strncpy (out, "helper error", out_sz - 1);
  out[out_sz - 1] = 0;
  if (!resp || rhdr->payload_len <= sizeof (uint32_t) || resp_cap <= sizeof (uint32_t))
    return;
  avail = rhdr->payload_len - sizeof (uint32_t);
  if (avail > resp_cap - sizeof (uint32_t))
    avail = resp_cap - sizeof (uint32_t);
  memcpy (&msg_len, resp, sizeof (uint32_t));
  if (msg_len > avail)
    msg_len = (uint32_t) avail;
  n = strnlen (resp + sizeof (uint32_t), msg_len);
  if (!n)
    return;
  if (n >= out_sz)
    n = out_sz - 1;
  memcpy (out, resp + sizeof (uint32_t), n);
  out[n] = 0;
}

/* 0 when a response is in; 2 when the helper did not answer within
   helper_timeout_ms; -1 for anything else (the helper died, or sent garbage). */
static int
onnx_ipc_recv_response (onnx_helper_proc_t *hp, onnx_ipc_hdr_t *hdr, void *payload, size_t payload_cap)
{
#ifdef _WIN32
  if (onnx_read_exact (hp->hRead, hdr, sizeof (*hdr)) < 0)
    return -1;
#else
  ssize_t r = onnx_read_exact (hp->fd_read, hdr, sizeof (*hdr));
  if (r < 0)
    return -2 == r ? 2 : -1;
#endif
  if (hdr->magic != ONNX_IPC_MAGIC || hdr->version != ONNX_IPC_VERSION)
    return -1;
  if (hdr->payload_len > payload_cap)
    return -1;
  if (hdr->payload_len)
    {
#ifdef _WIN32
      if (onnx_read_exact (hp->hRead, payload, hdr->payload_len) < 0)
	return -1;
#else
      r = onnx_read_exact (hp->fd_read, payload, hdr->payload_len);
      if (r < 0)
	return -2 == r ? 2 : -1;
#endif
    }
  return 0;
}

/* Decode `count` float vectors from a helper response.

   collapse_single returns the bare vector instead of a one-element array when
   count is 1.  That is what a single-value entry point like ONNX_EMBED_TEXT
   wants, and what this function used to do unconditionally -- which silently
   broke every batch entry point on a batch of one: ONNX_EMBED_BATCH with one
   text returned a bare 384-float vector where the caller expected an array of
   one, so a length check saw 384 elements for 1 input.  It also disagreed with
   the in-process path, which always returns an array.  Batch callers now pass
   0 and get an array of `count` whatever count is. */
static caddr_t
onnx_ipc_parse_float_response (size_t count, const onnx_ipc_hdr_t *rhdr, const char *resp, size_t resp_len,
			       int collapse_single)
{
  size_t pos = 0;
  if (rhdr->flags & ONNX_IPC_FLAG_TELEMETRY)
    {
      size_t tel = (rhdr->flags & ONNX_IPC_FLAG_TOKENS ? 5 : 2) * sizeof (uint64_t);
      if (resp_len < tel)
	onnx_fail (ONNX_SQLSTATE_RUNTIME, "ONNX", "Telemetry payload too short");
      pos += tel;
    }
  caddr_t *res_arr = (caddr_t *) dk_alloc_box (count * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
  for (size_t i = 0; i < count; i++)
    {
      if (pos + sizeof (uint32_t) > resp_len)
	{
	  dk_free_box ((caddr_t) res_arr);
	  onnx_fail (ONNX_SQLSTATE_RUNTIME, "ONNX", "Response truncated");
	}
      uint32_t elems = 0;
      memcpy (&elems, resp + pos, sizeof (uint32_t));
      pos += sizeof (uint32_t);
      char errbuf[128];
      if (onnx_validate_output_size (elems, errbuf, sizeof (errbuf)))
	{
	  dk_free_box ((caddr_t) res_arr);
	  onnx_fail (ONNX_SQLSTATE_RUNTIME, "ONNX", "%s", errbuf);
	}
      size_t bytes = (size_t) elems * sizeof (float);
      if (pos + bytes > resp_len)
	{
	  dk_free_box ((caddr_t) res_arr);
	  onnx_fail (ONNX_SQLSTATE_RUNTIME, "ONNX", "Response payload truncated");
	}
      caddr_t vec = dk_alloc_box (bytes, DV_ARRAY_OF_FLOAT);
      memcpy (vec, resp + pos, bytes);
      pos += bytes;
      res_arr[i] = onnx_float_to_vector (vec);
    }
  if (count == 1 && collapse_single)
    {
      caddr_t single = res_arr[0];
      dk_free_box ((caddr_t) res_arr);
      return single;
    }
  return (caddr_t) res_arr;
}

static caddr_t
onnx_outproc_embed (onnx_model_entry_t *m, caddr_t *arr, size_t count, int collapse_single)
{
  /* The request, sized by its texts: the op, then each text as a length and
     its bytes.  Checked before a helper is leased -- nothing to give back. */
  size_t payload_cap = sizeof (uint32_t) + 32;
  for (size_t i = 0; i < count; i++)
    payload_cap += sizeof (uint32_t) + (box_length (arr[i]) - 1);
  if (payload_cap > ONNX_MAX_REQUEST_BYTES)
    onnx_fail (ONNX_SQLSTATE_INPUT, "ONNX",
	"onnx_embed_batch: a request of %lu texts is %lu bytes, over the helper's %lu; split the batch",
	(unsigned long) count, (unsigned long) payload_cap, (unsigned long) ONNX_MAX_REQUEST_BYTES);
  if (onnx_helper_ensure_pool (m))
    onnx_fail (ONNX_SQLSTATE_RUNTIME, "ONNX", "Helper pool not initialized");
  onnx_helper_proc_t *hp = onnx_helper_acquire_or_respawn (m);
  if (!hp)
    onnx_fail (ONNX_SQLSTATE_RUNTIME, "ONNX",
	"No live helper available for model %s: the helper repeatedly failed to start. "
	"Check helper_path and that the model/vocab files are readable by the server.",
	m->path ? m->path : "<unknown>");

  /* Build payload (sized above; reserving max_input_bytes for every text put
     64 MB behind a 128-text request of labels, and would put 512 MB behind
     1,024). */
  char *payload = (char *) dk_alloc (payload_cap);
  size_t off = 0;
  uint32_t op = ONNX_IPC_OP_EMBED;
  memcpy (payload + off, &op, sizeof (uint32_t));
  off += sizeof (uint32_t);
  for (size_t i = 0; i < count; i++)
    {
      size_t len = box_length (arr[i]) - 1;
      uint32_t l32 = (uint32_t) len;
      memcpy (payload + off, &l32, sizeof (uint32_t));
      off += sizeof (uint32_t);
      memcpy (payload + off, arr[i], len);
      off += len;
    }
  onnx_ipc_hdr_t hdr;
  memset (&hdr, 0, sizeof (hdr));
  hdr.magic = ONNX_IPC_MAGIC;
  hdr.version = ONNX_IPC_VERSION;
  hdr.flags = g_ctx.caps.telemetry ? ONNX_IPC_FLAG_TELEMETRY : 0;
  hdr.batch_count = (uint32_t) count;
  hdr.payload_len = (uint32_t) off;
  hdr.status = 0;

  uint64_t t_start = onnx_time_monotonic_ns ();
  if (onnx_ipc_send_request (hp, &hdr, payload, off))
    {
      onnx_helper_note_fail (hp);
      onnx_helper_close (hp);
      /* retry once with a fresh helper (respects the respawn backoff) */
      if (onnx_helper_try_respawn (m, hp) || onnx_ipc_send_request (hp, &hdr, payload, off))
	{
	  dk_free (payload, payload_cap);
	  onnx_helper_release (m, hp);
	  onnx_fail (ONNX_SQLSTATE_RUNTIME, "ONNX",
	      "Failed to send request to helper for model %s.",
	      m->path ? m->path : "<unknown>");
	}
    }
  /* payload is deliberately kept until the response is in: the receive path
     below retries the request on a fresh helper and needs it intact. */

  /* Receive response */
  size_t resp_cap = g_ctx.caps.max_tensor_bytes + 64 + count * sizeof (uint32_t);
  char *resp = (char *) dk_alloc (resp_cap);
  onnx_ipc_hdr_t rhdr;
  if (onnx_ipc_recv_response (hp, &rhdr, resp, resp_cap))
    {
      /* The helper died mid-request.  Respawn and retry the request once,
	 rather than reporting "restarted, retry" and leaving the caller to do
	 it: a caller that retries hits the same code path, so if the cause is
	 persistent -- an unreadable model, say -- the old behaviour looped
	 forever on an error that named neither the model nor the reason.
	 Retrying here makes a genuinely transient helper death invisible, and
	 makes a persistent one fail with a diagnosis on the second attempt. */
      onnx_helper_note_fail (hp);
      onnx_helper_close (hp);
      if (onnx_helper_try_respawn (m, hp))
	{
	  dk_free (payload, payload_cap);
	  dk_free (resp, resp_cap);
	  onnx_helper_release (m, hp);
	  onnx_fail (ONNX_SQLSTATE_RUNTIME, "ONNX",
	      "Helper for model %s died and could not be restarted "
	      "(it may be in a restart backoff after repeated failures; "
	      "check the model/vocab files and helper_path).",
	      m->path ? m->path : "<unknown>");
	}
      int rr = onnx_ipc_send_request (hp, &hdr, payload, off) ? -1
	  : onnx_ipc_recv_response (hp, &rhdr, resp, resp_cap);
      if (rr)
	{
	  onnx_helper_note_fail (hp);
	  onnx_helper_close (hp);
	  dk_free (payload, payload_cap);
	  dk_free (resp, resp_cap);
	  onnx_helper_release (m, hp);
	  /* A helper that is only slow is stopped the same way as a wedged one,
	     and a larger request is slower: 256 texts of 256 tokens take about
	     20 s on one core, against the default of 30 s.  Blaming the model
	     files for that sends the operator the wrong way. */
	  if (2 == rr)
	    onnx_fail (ONNX_SQLSTATE_RUNTIME, "ONNX",
		"Helper for model %s did not answer a request of %lu texts within "
		"helper_timeout_ms (%d ms) and was stopped.  A larger request takes longer: "
		"raise the timeout with ONNX_CONFIG ('helper_timeout_ms', ms), or send fewer "
		"texts at a time -- for a vector index, a smaller __vec_embed_batch_size.",
		m->path ? m->path : "<unknown>", (unsigned long) count, g_ctx.caps.helper_timeout_ms);
	  onnx_fail (ONNX_SQLSTATE_RUNTIME, "ONNX",
	      "Helper for model %s died on two consecutive requests. "
	      "The helper cannot service this model -- check that the model and vocab "
	      "files are readable by the server process and that the paths are absolute.",
	      m->path ? m->path : "<unknown>");
	}
    }
  dk_free (payload, payload_cap);
  uint64_t t_recv = onnx_time_monotonic_ns ();
  if (rhdr.status != 0)
    {
      char emsg[512];
      onnx_helper_err_text (emsg, sizeof (emsg), &rhdr, resp, resp_cap);
      onnx_helper_close (hp);
      dk_free (resp, resp_cap);
      onnx_helper_release (m, hp);
      onnx_fail (ONNX_SQLSTATE_RUNTIME, "ONNX", "Helper error: %s", emsg);
    }
  onnx_helper_note_ok (hp);	/* a good response clears the respawn-backoff streak */

  uint64_t helper_infer_ns = 0, helper_ser_ns = 0;
  if (rhdr.flags & ONNX_IPC_FLAG_TELEMETRY && rhdr.payload_len >= 2 * sizeof (uint64_t))
    {
      memcpy (&helper_infer_ns, resp, sizeof (uint64_t));
      memcpy (&helper_ser_ns, resp + sizeof (uint64_t), sizeof (uint64_t));
    }
  if ((rhdr.flags & ONNX_IPC_FLAG_TELEMETRY) && (rhdr.flags & ONNX_IPC_FLAG_TOKENS)
      && rhdr.payload_len >= 5 * sizeof (uint64_t))
    {
      uint64_t tk[3];
      memcpy (tk, resp + 2 * sizeof (uint64_t), sizeof (tk));
      mutex_enter (m->mtx);
      m->st_requests++;
      m->st_texts += (int64) count;
      m->st_real_tokens += (int64) tk[0];
      m->st_padded_tokens += (int64) tk[1];
      m->st_sub_batches += (int64) tk[2];
      mutex_leave (m->mtx);
    }
  /* The exchange is over and everything below reads only `resp`, so the helper
     goes back to the pool here -- before the parse, which can itself longjmp
     out on a malformed response. */
  hp->last_used_mono = t_recv;
  onnx_helper_release (m, hp);
  caddr_t ret = onnx_ipc_parse_float_response (count, &rhdr, resp, rhdr.payload_len, collapse_single);
  dk_free (resp, resp_cap);
  if (g_ctx.caps.telemetry && g_ctx.caps.log_level >= 3)
    {
      uint64_t ipc_ns = t_recv - t_start;
      onnx_log (3, "OUTPROC batch=%lu ipc_ns=%llu helper_infer_ns=%llu helper_ser_ns=%llu",
		(unsigned long) count,
		(unsigned long long) ipc_ns,
		(unsigned long long) helper_infer_ns,
		(unsigned long long) helper_ser_ns);
    }
  return ret;
}

static caddr_t
onnx_outproc_run_f32 (onnx_model_entry_t *m, const float *data, size_t data_len, const int64_t *dims, size_t dims_count, size_t batch)
{
  if (data_len * sizeof (float) > g_ctx.caps.max_tensor_bytes)
    onnx_fail (ONNX_SQLSTATE_INPUT, "ONNX", "Input tensor exceeds max_tensor_bytes");
  if (onnx_helper_ensure_pool (m))
    onnx_fail (ONNX_SQLSTATE_RUNTIME, "ONNX", "Helper pool not initialized");
  onnx_helper_proc_t *hp = onnx_helper_acquire_or_respawn (m);
  if (!hp)
    onnx_fail (ONNX_SQLSTATE_RUNTIME, "ONNX", "No live helper available");

  size_t payload_len = sizeof (uint32_t) + sizeof (uint32_t) + dims_count * sizeof (int64_t) + sizeof (uint32_t) + data_len * sizeof (float);
  char *payload = (char *) dk_alloc (payload_len);
  size_t off = 0;
  uint32_t op = ONNX_IPC_OP_RUN_F32;
  memcpy (payload + off, &op, sizeof (uint32_t));
  off += sizeof (uint32_t);
  uint32_t dcount = (uint32_t) dims_count;
  memcpy (payload + off, &dcount, sizeof (uint32_t));
  off += sizeof (uint32_t);
  for (size_t i = 0; i < dims_count; i++)
    {
      memcpy (payload + off, &dims[i], sizeof (int64_t));
      off += sizeof (int64_t);
    }
  uint32_t bytes = (uint32_t) (data_len * sizeof (float));
  memcpy (payload + off, &bytes, sizeof (uint32_t));
  off += sizeof (uint32_t);
  memcpy (payload + off, data, bytes);

  onnx_ipc_hdr_t hdr;
  memset (&hdr, 0, sizeof (hdr));
  hdr.magic = ONNX_IPC_MAGIC;
  hdr.version = ONNX_IPC_VERSION;
  hdr.flags = g_ctx.caps.telemetry ? ONNX_IPC_FLAG_TELEMETRY : 0;
  hdr.batch_count = (uint32_t) batch;
  hdr.payload_len = (uint32_t) payload_len;

  if (onnx_ipc_send_request (hp, &hdr, payload, payload_len))
    {
      onnx_helper_close (hp);
      dk_free (payload, payload_len);
      onnx_helper_release (m, hp);
      onnx_fail (ONNX_SQLSTATE_RUNTIME, "ONNX", "Failed to send to helper");
    }
  dk_free (payload, payload_len);

  size_t resp_cap = g_ctx.caps.max_tensor_bytes + 64;
  char *resp = (char *) dk_alloc (resp_cap);
  onnx_ipc_hdr_t rhdr;
  if (onnx_ipc_recv_response (hp, &rhdr, resp, resp_cap))
    {
      onnx_helper_close (hp);
      dk_free (resp, resp_cap);
      onnx_helper_release (m, hp);
      onnx_fail (ONNX_SQLSTATE_RUNTIME, "ONNX", "Failed to read from helper");
    }
  if (rhdr.status != 0)
    {
      char emsg[512];
      onnx_helper_err_text (emsg, sizeof (emsg), &rhdr, resp, resp_cap);
      dk_free (resp, resp_cap);
      onnx_helper_release (m, hp);
      onnx_fail (ONNX_SQLSTATE_RUNTIME, "ONNX", "Helper error: %s", emsg);
    }
  onnx_helper_release (m, hp);	/* exchange done; the parse below can longjmp */
  caddr_t ret = onnx_ipc_parse_float_response (batch, &rhdr, resp, rhdr.payload_len, 1);
  dk_free (resp, resp_cap);
  return ret;
}

static caddr_t
onnx_outproc_run_i64_2 (onnx_model_entry_t *m, const int64_t *ids, const int64_t *mask, size_t elem_count, size_t batch, size_t seq_len)
{
  if (elem_count * sizeof (int64_t) > g_ctx.caps.max_tensor_bytes)
    onnx_fail (ONNX_SQLSTATE_INPUT, "ONNX", "Input tensor exceeds max_tensor_bytes");
  if (onnx_helper_ensure_pool (m))
    onnx_fail (ONNX_SQLSTATE_RUNTIME, "ONNX", "Helper pool not initialized");
  onnx_helper_proc_t *hp = onnx_helper_acquire_or_respawn (m);
  if (!hp)
    onnx_fail (ONNX_SQLSTATE_RUNTIME, "ONNX", "No live helper available");

  uint32_t op = ONNX_IPC_OP_RUN_I64_2;
  uint32_t dcount = 2;
  int64_t d0 = (int64_t) batch;
  int64_t d1 = (int64_t) seq_len;
  uint32_t bytes = (uint32_t) (elem_count * sizeof (int64_t));
  size_t payload_len = sizeof (uint32_t) + sizeof (uint32_t) + 2 * sizeof (int64_t) + sizeof (uint32_t) + bytes + sizeof (uint32_t) + bytes;
  char *payload = (char *) dk_alloc (payload_len);
  size_t off = 0;
  memcpy (payload + off, &op, sizeof (uint32_t)); off += sizeof (uint32_t);
  memcpy (payload + off, &dcount, sizeof (uint32_t)); off += sizeof (uint32_t);
  memcpy (payload + off, &d0, sizeof (int64_t)); off += sizeof (int64_t);
  memcpy (payload + off, &d1, sizeof (int64_t)); off += sizeof (int64_t);
  memcpy (payload + off, &bytes, sizeof (uint32_t)); off += sizeof (uint32_t);
  memcpy (payload + off, ids, bytes); off += bytes;
  memcpy (payload + off, &bytes, sizeof (uint32_t)); off += sizeof (uint32_t);
  memcpy (payload + off, mask, bytes);

  onnx_ipc_hdr_t hdr;
  memset (&hdr, 0, sizeof (hdr));
  hdr.magic = ONNX_IPC_MAGIC;
  hdr.version = ONNX_IPC_VERSION;
  hdr.flags = g_ctx.caps.telemetry ? ONNX_IPC_FLAG_TELEMETRY : 0;
  hdr.batch_count = (uint32_t) batch;
  hdr.payload_len = (uint32_t) payload_len;

  if (onnx_ipc_send_request (hp, &hdr, payload, payload_len))
    {
      onnx_helper_close (hp);
      dk_free (payload, payload_len);
      onnx_helper_release (m, hp);
      onnx_fail (ONNX_SQLSTATE_RUNTIME, "ONNX", "Failed to send to helper");
    }
  dk_free (payload, payload_len);

  size_t resp_cap = g_ctx.caps.max_tensor_bytes + 64 + batch * sizeof (uint32_t);
  char *resp = (char *) dk_alloc (resp_cap);
  onnx_ipc_hdr_t rhdr;
  if (onnx_ipc_recv_response (hp, &rhdr, resp, resp_cap))
    {
      onnx_helper_close (hp);
      dk_free (resp, resp_cap);
      onnx_helper_release (m, hp);
      onnx_fail (ONNX_SQLSTATE_RUNTIME, "ONNX", "Failed to read from helper");
    }
  if (rhdr.status != 0)
    {
      char emsg[512];
      onnx_helper_err_text (emsg, sizeof (emsg), &rhdr, resp, resp_cap);
      dk_free (resp, resp_cap);
      onnx_helper_release (m, hp);
      onnx_fail (ONNX_SQLSTATE_RUNTIME, "ONNX", "Helper error: %s", emsg);
    }
  onnx_helper_release (m, hp);	/* exchange done; the parse below can longjmp */
  caddr_t ret = onnx_ipc_parse_float_response (batch, &rhdr, resp, rhdr.payload_len, 1);
  dk_free (resp, resp_cap);
  return ret;
}

/* ---------- In-process inference ---------- */

typedef struct
{
  onnx_model_entry_t *model;
  const char *text;
  caddr_t result;
  OrtStatus *err_status;
  char err_msg[128];
} onnx_embed_ctx_t;

typedef struct
{
  onnx_model_entry_t *model;
  caddr_t *arr;
  size_t count;
  caddr_t result;
  OrtStatus *err_status;
  char err_msg[128];
} onnx_batch_ctx_t;

static int
onnx_embed_body (void *arg)
{
  onnx_embed_ctx_t *ctx = (onnx_embed_ctx_t *) arg;
  onnx_model_entry_t *m = ctx->model;
  const char *input_names[] = { m->input_name };
  const char *output_names[] = { m->output_name };
  OrtValue *input = NULL;
  OrtValue *output = NULL;
  OrtTensorTypeAndShapeInfo *info = NULL;
  OrtAllocator *alloc = NULL;
  OrtStatus *st = NULL;
  const char *err_ctx = NULL;
  char errbuf[128];
  int rc = 0;

  st = g_ctx.api->GetAllocatorWithDefaultOptions (&alloc);
  if (st)
    {
      err_ctx = "GetAllocatorWithDefaultOptions";
      goto cleanup;
    }
  int64_t shape[1] = { 1 };
  st = g_ctx.api->CreateTensorAsOrtValue (alloc, shape, 1, ONNX_TENSOR_ELEMENT_DATA_TYPE_STRING, &input);
  if (st)
    {
      err_ctx = "CreateTensorAsOrtValue";
      goto cleanup;
    }
  st = g_ctx.api->FillStringTensor (input, &ctx->text, 1);
  if (st)
    {
      err_ctx = "FillStringTensor";
      goto cleanup;
    }
  st = g_ctx.api->Run (m->session, NULL, input_names, (const OrtValue * const *) &input, 1, output_names, 1, &output);
  if (st)
    {
      err_ctx = "OrtRun";
      goto cleanup;
    }
  st = g_ctx.api->GetTensorTypeAndShape (output, &info);
  if (st)
    {
      err_ctx = "GetTensorTypeAndShape";
      goto cleanup;
    }
  ONNXTensorElementDataType et;
  st = g_ctx.api->GetTensorElementType (info, &et);
  if (st)
    {
      err_ctx = "GetTensorElementType";
      goto cleanup;
    }
  if (et != ONNX_TENSOR_ELEMENT_DATA_TYPE_FLOAT)
    {
      err_ctx = "Output is not float";
      goto cleanup;
    }
  size_t elem_count = 0;
  st = g_ctx.api->GetTensorShapeElementCount (info, &elem_count);
  if (st)
    {
      err_ctx = "GetTensorShapeElementCount";
      goto cleanup;
    }
  if (onnx_validate_output_size (elem_count, errbuf, sizeof (errbuf)))
    {
      err_ctx = errbuf;
      goto cleanup;
    }
  float *out = NULL;
  st = g_ctx.api->GetTensorMutableData (output, (void **) &out);
  if (st)
    {
      err_ctx = "GetTensorMutableData";
      goto cleanup;
    }
  caddr_t fbox = dk_alloc_box (elem_count * sizeof (float), DV_ARRAY_OF_FLOAT);
  memcpy (fbox, out, elem_count * sizeof (float));
  ctx->result = onnx_float_to_vector (fbox);
  rc = 0;

cleanup:
  if (info)
    g_ctx.api->ReleaseTensorTypeAndShapeInfo (info);
  if (input)
    g_ctx.api->ReleaseValue (input);
  if (output)
    g_ctx.api->ReleaseValue (output);
  if (err_ctx)
    {
      onnx_copy_trunc (ctx->err_msg, sizeof (ctx->err_msg), err_ctx);
      ctx->err_status = st;
      return -1;
    }
  ctx->err_status = NULL;
  return rc;
}

static caddr_t
onnx_do_embed (onnx_model_entry_t *m, const char *text)
{
  onnx_embed_ctx_t ctx = { m, text, NULL, NULL, {0} };
#ifndef _WIN32
  int sig = onnx_guard_begin ();
  if (sig)
    onnx_fail (ONNX_SQLSTATE_RUNTIME, "ONNX", "Native fault (signal %d) during inference", sig);
  int rc = onnx_embed_body (&ctx);
  onnx_guard_end ();
  if (rc)
    onnx_fail (ONNX_SQLSTATE_RUNTIME, "ONNX", "Inference failed");
#else
  int rc = onnx_guard_run (onnx_embed_body, &ctx);
  if (rc != 0)
    onnx_fail (ONNX_SQLSTATE_RUNTIME, "ONNX", "Native fault during inference");
#endif
  if (ctx.err_status)
    onnx_raise_status (ctx.err_status, ctx.err_msg[0] ? ctx.err_msg : "onnx_embed");
  if (ctx.err_msg[0])
    onnx_fail (ONNX_SQLSTATE_CONFIG, "ONNX", "%s", ctx.err_msg);
  return ctx.result;
}

/* ---------- Numeric inference (float32) ---------- */

typedef struct
{
  onnx_model_entry_t *model;
  const float *data;
  size_t data_len;
  int64_t *dims;
  size_t dims_count;
  size_t batch;
  caddr_t result;
  OrtStatus *err_status;
  char err_msg[128];
} onnx_f32_ctx_t;

static caddr_t
onnx_output_to_box (OrtValue *output, size_t batch)
{
  OrtTensorTypeAndShapeInfo *info = NULL;
  OrtStatus *st = g_ctx.api->GetTensorTypeAndShape (output, &info);
  onnx_check_status (st, "GetTensorTypeAndShape");
  ONNXTensorElementDataType et;
  st = g_ctx.api->GetTensorElementType (info, &et);
  onnx_check_status (st, "GetTensorElementType");
  if (et != ONNX_TENSOR_ELEMENT_DATA_TYPE_FLOAT)
    onnx_fail (ONNX_SQLSTATE_CONFIG, "ONNX", "Output is not float");
  size_t elem_count = 0;
  st = g_ctx.api->GetTensorShapeElementCount (info, &elem_count);
  onnx_check_status (st, "GetTensorShapeElementCount");
  char errbuf[128];
  if (onnx_validate_output_size (elem_count, errbuf, sizeof (errbuf)))
    onnx_fail (ONNX_SQLSTATE_CONFIG, "ONNX", "%s", errbuf);
  float *out = NULL;
  st = g_ctx.api->GetTensorMutableData (output, (void **) &out);
  onnx_check_status (st, "GetTensorMutableData");

  size_t dims_count = 0;
  st = g_ctx.api->GetDimensionsCount (info, &dims_count);
  onnx_check_status (st, "GetDimensionsCount");
  if (batch > 1 && dims_count > 0 && elem_count % batch == 0)
    {
      int64_t dims[8];
      if (dims_count <= 8)
	{
	  st = g_ctx.api->GetDimensions (info, dims, dims_count);
	  onnx_check_status (st, "GetDimensions");
	  if (dims[0] == (int64_t) batch)
	    {
	      size_t per = elem_count / batch;
	      caddr_t *res = (caddr_t *) dk_alloc_box (batch * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
	      for (size_t i = 0; i < batch; i++)
		{
		  caddr_t vec = dk_alloc_box (per * sizeof (float), DV_ARRAY_OF_FLOAT);
		  memcpy (vec, out + i * per, per * sizeof (float));
		  res[i] = onnx_float_to_vector (vec);
		}
	      g_ctx.api->ReleaseTensorTypeAndShapeInfo (info);
	      return (caddr_t) res;
	    }
	}
    }
  caddr_t vec = dk_alloc_box (elem_count * sizeof (float), DV_ARRAY_OF_FLOAT);
  memcpy (vec, out, elem_count * sizeof (float));
  g_ctx.api->ReleaseTensorTypeAndShapeInfo (info);
  return onnx_float_to_vector (vec);
}

static int
onnx_run_f32_body (void *arg)
{
  onnx_f32_ctx_t *ctx = (onnx_f32_ctx_t *) arg;
  onnx_model_entry_t *m = ctx->model;
  OrtMemoryInfo *mem = NULL;
  OrtValue *input = NULL;
  OrtValue *output = NULL;
  OrtStatus *st = NULL;

  st = g_ctx.api->CreateCpuMemoryInfo (OrtArenaAllocator, OrtMemTypeDefault, &mem);
  if (st)
    goto fail;
  st = g_ctx.api->CreateTensorWithDataAsOrtValue (mem, (void *) ctx->data,
						  ctx->data_len * sizeof (float),
						  ctx->dims, ctx->dims_count,
						  ONNX_TENSOR_ELEMENT_DATA_TYPE_FLOAT, &input);
  if (st)
    goto fail;
  const char *input_names[] = { m->input_name };
  const char *output_names[] = { m->output_name };
  st = g_ctx.api->Run (m->session, NULL, input_names, (const OrtValue * const *) &input, 1, output_names, 1, &output);
  if (st)
    goto fail;
  ctx->result = onnx_output_to_box (output, ctx->batch);
  ctx->err_status = NULL;
  g_ctx.api->ReleaseMemoryInfo (mem);
  g_ctx.api->ReleaseValue (input);
  g_ctx.api->ReleaseValue (output);
  return 0;

fail:
  ctx->err_status = st;
  onnx_copy_trunc (ctx->err_msg, sizeof (ctx->err_msg), "onnx_run_f32");
  if (mem)
    g_ctx.api->ReleaseMemoryInfo (mem);
  if (input)
    g_ctx.api->ReleaseValue (input);
  if (output)
    g_ctx.api->ReleaseValue (output);
  return -1;
}

static caddr_t
onnx_run_f32_inproc (onnx_model_entry_t *m, const float *data, size_t data_len, int64_t *dims, size_t dims_count, size_t batch)
{
  onnx_f32_ctx_t ctx = { m, data, data_len, dims, dims_count, batch, NULL, NULL, {0} };
#ifndef _WIN32
  int sig = onnx_guard_begin ();
  if (sig)
    onnx_fail (ONNX_SQLSTATE_RUNTIME, "ONNX", "Native fault (signal %d) during inference", sig);
  int rc = onnx_run_f32_body (&ctx);
  onnx_guard_end ();
  if (rc)
    onnx_fail (ONNX_SQLSTATE_RUNTIME, "ONNX", "Inference failed");
#else
  int rc = onnx_guard_run (onnx_run_f32_body, &ctx);
  if (rc != 0)
    onnx_fail (ONNX_SQLSTATE_RUNTIME, "ONNX", "Native fault during inference");
#endif
  if (ctx.err_status)
    onnx_raise_status (ctx.err_status, ctx.err_msg[0] ? ctx.err_msg : "onnx_run_f32");
  if (ctx.err_msg[0])
    onnx_fail (ONNX_SQLSTATE_CONFIG, "ONNX", "%s", ctx.err_msg);
  return ctx.result;
}

/* ---------- Tokenized inference (int64 input_ids + attention_mask) ---------- */

typedef struct
{
  onnx_model_entry_t *model;
  const int64_t *ids;
  const int64_t *mask;
  size_t elem_count;
  int64_t dims[2];
  size_t batch;
  caddr_t result;
  OrtStatus *err_status;
  char err_msg[128];
} onnx_tok_ctx_t;

static int
onnx_run_tokens_body (void *arg)
{
  onnx_tok_ctx_t *ctx = (onnx_tok_ctx_t *) arg;
  onnx_model_entry_t *m = ctx->model;
  OrtMemoryInfo *mem = NULL;
  OrtValue *input_ids = NULL;
  OrtValue *attention = NULL;
  OrtValue *output = NULL;
  OrtStatus *st = NULL;

  if (!m->input_name2)
    {
      onnx_copy_trunc (ctx->err_msg, sizeof (ctx->err_msg), "Model missing second input");
      return -1;
    }
  st = g_ctx.api->CreateCpuMemoryInfo (OrtArenaAllocator, OrtMemTypeDefault, &mem);
  if (st)
    goto fail;
  st = g_ctx.api->CreateTensorWithDataAsOrtValue (mem, (void *) ctx->ids,
						  ctx->elem_count * sizeof (int64_t),
						  ctx->dims, 2,
						  ONNX_TENSOR_ELEMENT_DATA_TYPE_INT64, &input_ids);
  if (st)
    goto fail;
  st = g_ctx.api->CreateTensorWithDataAsOrtValue (mem, (void *) ctx->mask,
						  ctx->elem_count * sizeof (int64_t),
						  ctx->dims, 2,
						  ONNX_TENSOR_ELEMENT_DATA_TYPE_INT64, &attention);
  if (st)
    goto fail;
  const char *input_names[] = { m->input_name, m->input_name2 };
  const OrtValue *inputs[] = { input_ids, attention };
  const char *output_names[] = { m->output_name };
  st = g_ctx.api->Run (m->session, NULL, input_names, inputs, 2, output_names, 1, &output);
  if (st)
    goto fail;
  ctx->result = onnx_output_to_box (output, ctx->batch);
  ctx->err_status = NULL;
  g_ctx.api->ReleaseMemoryInfo (mem);
  g_ctx.api->ReleaseValue (input_ids);
  g_ctx.api->ReleaseValue (attention);
  g_ctx.api->ReleaseValue (output);
  return 0;

fail:
  ctx->err_status = st;
  onnx_copy_trunc (ctx->err_msg, sizeof (ctx->err_msg), "onnx_run_tokens");
  if (mem)
    g_ctx.api->ReleaseMemoryInfo (mem);
  if (input_ids)
    g_ctx.api->ReleaseValue (input_ids);
  if (attention)
    g_ctx.api->ReleaseValue (attention);
  if (output)
    g_ctx.api->ReleaseValue (output);
  return -1;
}

static caddr_t
onnx_run_tokens_inproc (onnx_model_entry_t *m, const int64_t *ids, const int64_t *mask, size_t elem_count, size_t batch, size_t seq_len)
{
  onnx_tok_ctx_t ctx;
  memset (&ctx, 0, sizeof (ctx));
  ctx.model = m;
  ctx.ids = ids;
  ctx.mask = mask;
  ctx.elem_count = elem_count;
  ctx.dims[0] = (int64_t) batch;
  ctx.dims[1] = (int64_t) seq_len;
  ctx.batch = batch;
#ifndef _WIN32
  int sig = onnx_guard_begin ();
  if (sig)
    onnx_fail (ONNX_SQLSTATE_RUNTIME, "ONNX", "Native fault (signal %d) during inference", sig);
  int rc = onnx_run_tokens_body (&ctx);
  onnx_guard_end ();
  if (rc)
    onnx_fail (ONNX_SQLSTATE_RUNTIME, "ONNX", "Inference failed");
#else
  int rc = onnx_guard_run (onnx_run_tokens_body, &ctx);
  if (rc != 0)
    onnx_fail (ONNX_SQLSTATE_RUNTIME, "ONNX", "Native fault during inference");
#endif
  if (ctx.err_status)
    onnx_raise_status (ctx.err_status, ctx.err_msg[0] ? ctx.err_msg : "onnx_run_tokens");
  if (ctx.err_msg[0])
    onnx_fail (ONNX_SQLSTATE_CONFIG, "ONNX", "%s", ctx.err_msg);
  return ctx.result;
}

static caddr_t
bif_onnx_embed (caddr_t * qst, caddr_t * err, state_slot_t ** args)
{
  long handle = bif_long_arg (qst, args, 0, "onnx_embed");
  caddr_t txt = bif_string_arg (qst, args, 1, "onnx_embed");
  size_t len = box_length (txt) - 1;
  onnx_validate_text ("onnx_embed", txt, len);
  onnx_model_entry_t *m = onnx_model_ref (handle);
  if (!m)
    onnx_fail (ONNX_SQLSTATE_INPUT, "ONNX", "Unknown or closed model handle %ld", handle);
  caddr_t res = NULL;
  if (g_ctx.caps.mode == ONNX_MODE_OUTPROC)
    {
      if (!g_ctx.caps.helper_path[0])
	onnx_fail (ONNX_SQLSTATE_CONFIG, "ONNX", "Out-of-process mode enabled but helper_path not set via ONNX_CONFIG");
      caddr_t arr[1] = { txt };
      ONNX_WITH_MODEL_REF (m, res = onnx_outproc_embed (m, arr, 1, 1));   /* single value: bare vector */
    }
  else
    ONNX_WITH_MODEL_REF (m, res = onnx_do_embed (m, txt));
  onnx_model_unref (m);
  return res;
}

/* ---------- Batch embedding ---------- */

static int
onnx_do_embed_batch (onnx_batch_ctx_t *ctx)
{
  onnx_model_entry_t *m = ctx->model;
  caddr_t *arr = ctx->arr;
  size_t count = ctx->count;
  const char *output_names[] = { m->output_name };
  const char *input_names[] = { m->input_name };
  OrtAllocator *alloc = NULL;
  OrtStatus *st = NULL;
  const char *err_ctx = NULL;
  char errbuf[128];
  OrtValue *input = NULL, *output = NULL;
  OrtTensorTypeAndShapeInfo *info = NULL;
  const char **strings = NULL;
  caddr_t *res = NULL;

  st = g_ctx.api->GetAllocatorWithDefaultOptions (&alloc);
  if (st)
    {
      err_ctx = "GetAllocatorWithDefaultOptions";
      goto cleanup;
    }
  int64_t shape[1] = { (int64_t) count };
  st = g_ctx.api->CreateTensorAsOrtValue (alloc, shape, 1, ONNX_TENSOR_ELEMENT_DATA_TYPE_STRING, &input);
  if (st)
    {
      err_ctx = "CreateTensorAsOrtValue";
      goto cleanup;
    }
  strings = (const char **) dk_alloc (count * sizeof (char *));
  for (size_t i = 0; i < count; i++)
    {
      strings[i] = arr[i];
    }
  st = g_ctx.api->FillStringTensor (input, strings, count);
  if (st)
    {
      err_ctx = "FillStringTensor";
      goto cleanup;
    }
  st = g_ctx.api->Run (m->session, NULL, input_names, (const OrtValue * const *) &input, 1, output_names, 1, &output);
  if (st)
    {
      err_ctx = "OrtRun";
      goto cleanup;
    }
  st = g_ctx.api->GetTensorTypeAndShape (output, &info);
  if (st)
    {
      err_ctx = "GetTensorTypeAndShape";
      goto cleanup;
    }
  ONNXTensorElementDataType et;
  st = g_ctx.api->GetTensorElementType (info, &et);
  if (st)
    {
      err_ctx = "GetTensorElementType";
      goto cleanup;
    }
  if (et != ONNX_TENSOR_ELEMENT_DATA_TYPE_FLOAT)
    {
      err_ctx = "Output is not float";
      goto cleanup;
    }
  size_t elem_count = 0;
  st = g_ctx.api->GetTensorShapeElementCount (info, &elem_count);
  if (st)
    {
      err_ctx = "GetTensorShapeElementCount";
      goto cleanup;
    }
  if (onnx_validate_output_size (elem_count, errbuf, sizeof (errbuf)))
    {
      err_ctx = errbuf;
      goto cleanup;
    }
  if (elem_count % count != 0)
    {
      err_ctx = "Output element count not divisible by batch";
      goto cleanup;
    }
  size_t per = elem_count / count;
  float *out = NULL;
  st = g_ctx.api->GetTensorMutableData (output, (void **) &out);
  if (st)
    {
      err_ctx = "GetTensorMutableData";
      goto cleanup;
    }
  res = (caddr_t *) dk_alloc_box (count * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
  for (size_t i = 0; i < count; i++)
    {
      caddr_t vec = dk_alloc_box (per * sizeof (float), DV_ARRAY_OF_FLOAT);
      memcpy (vec, out + i * per, per * sizeof (float));
      res[i] = vec;
    }
  ctx->result = (caddr_t) res;
  res = NULL;

cleanup:
  if (strings)
    dk_free ((caddr_t) strings, count * sizeof (char *));
  if (info)
    g_ctx.api->ReleaseTensorTypeAndShapeInfo (info);
  if (input)
    g_ctx.api->ReleaseValue (input);
  if (output)
    g_ctx.api->ReleaseValue (output);
  if (err_ctx)
    {
      onnx_copy_trunc (ctx->err_msg, sizeof (ctx->err_msg), err_ctx);
      ctx->err_status = st;
      return -1;
    }
  ctx->err_status = NULL;
  return 0;
}

static int
onnx_embed_batch_body (void *arg)
{
  onnx_batch_ctx_t *ctx = (onnx_batch_ctx_t *) arg;
  return onnx_do_embed_batch (ctx);
}

static caddr_t
onnx_run_embed_batch (onnx_model_entry_t *m, caddr_t *arr, size_t count)
{
  onnx_batch_ctx_t ctx = { m, arr, count, NULL, NULL, {0} };
#ifndef _WIN32
  int sig = onnx_guard_begin ();
  if (sig)
    onnx_fail (ONNX_SQLSTATE_RUNTIME, "ONNX", "Native fault (signal %d) during batch inference", sig);
  int rc = onnx_embed_batch_body (&ctx);
  onnx_guard_end ();
  if (rc)
    onnx_fail (ONNX_SQLSTATE_RUNTIME, "ONNX", "Batch inference failed");
#else
  int rc = onnx_guard_run (onnx_embed_batch_body, &ctx);
  if (rc != 0)
    onnx_fail (ONNX_SQLSTATE_RUNTIME, "ONNX", "Native fault during batch inference");
#endif
  if (ctx.err_status)
    onnx_raise_status (ctx.err_status, ctx.err_msg[0] ? ctx.err_msg : "onnx_embed_batch");
  if (ctx.err_msg[0])
    onnx_fail (ONNX_SQLSTATE_CONFIG, "ONNX", "%s", ctx.err_msg);
  return ctx.result;
}

static caddr_t
bif_onnx_embed_batch (caddr_t * qst, caddr_t * err, state_slot_t ** args)
{
  long handle = bif_long_arg (qst, args, 0, "onnx_embed_batch");
  caddr_t arr = bif_array_arg (qst, args, 1, "onnx_embed_batch");
  if (DV_ARRAY_OF_POINTER != DV_TYPE_OF (arr))
    onnx_fail (ONNX_SQLSTATE_INPUT, "ONNX", "Second argument must be array of strings");
  size_t count = BOX_ELEMENTS (arr);
  onnx_validate_batch ("onnx_embed_batch", count);
  caddr_t *elts = (caddr_t *) arr;
  for (size_t i = 0; i < count; i++)
    {
      if (DV_STRING != DV_TYPE_OF (elts[i]))
	onnx_fail (ONNX_SQLSTATE_INPUT, "ONNX", "Batch item %lu is not a string", (unsigned long) i);
      size_t len = box_length (elts[i]) - 1;
      onnx_validate_text ("onnx_embed_batch", elts[i], len);
    }
  onnx_model_entry_t *m = onnx_model_ref (handle);
  if (!m)
    onnx_fail (ONNX_SQLSTATE_INPUT, "ONNX", "Unknown or closed model handle %ld", handle);
  caddr_t res = NULL;
  if (g_ctx.caps.mode == ONNX_MODE_OUTPROC)
    {
      /* Refused here, not by the helper: a helper that answers with an error
	 is closed, and this is the caller's mistake, not the helper's. */
      if (count > (size_t) m->max_texts)
	{
	  int mt = m->max_texts;
	  onnx_model_unref (m);
	  onnx_fail (ONNX_SQLSTATE_INPUT, "ONNX",
	      "onnx_embed_batch: %lu texts exceed this model's max_texts (%d); "
	      "split the batch, or load the model with a larger max_texts",
	      (unsigned long) count, mt);
	}
      ONNX_WITH_MODEL_REF (m, res = onnx_outproc_embed (m, elts, count, 0));   /* always an array of count */
    }
  else
    ONNX_WITH_MODEL_REF (m, res = onnx_run_embed_batch (m, elts, count));
  onnx_model_unref (m);
  return res;
}

/* ---------- Numeric BIFs ---------- */

static caddr_t
bif_onnx_run_f32 (caddr_t * qst, caddr_t * err, state_slot_t ** args)
{
  long handle = bif_long_arg (qst, args, 0, "onnx_run_f32");
  caddr_t data_box = bif_array_arg (qst, args, 1, "onnx_run_f32");
  caddr_t dims_box = bif_array_arg (qst, args, 2, "onnx_run_f32");
  /* Accept DV_ARRAY_OF_FLOAT, DV_ARRAY_OF_DOUBLE, or DV_ARRAY_OF_POINTER (from vector()) */
  dtp_t data_dtp = DV_TYPE_OF (data_box);
  float *f32_buf = NULL;
  size_t data_len = 0;
  if (DV_ARRAY_OF_FLOAT == data_dtp)
    {
      data_len = box_length (data_box) / sizeof (float);
      f32_buf = (float *) data_box;
    }
  else if (DV_ARRAY_OF_DOUBLE == data_dtp)
    {
      data_len = box_length (data_box) / sizeof (double);
      f32_buf = (float *) dk_alloc (data_len * sizeof (float));
      for (size_t i = 0; i < data_len; i++)
	f32_buf[i] = (float) ((double *) data_box)[i];
    }
  else if (DV_ARRAY_OF_POINTER == data_dtp)
    {
      data_len = BOX_ELEMENTS (data_box);
      f32_buf = (float *) dk_alloc (data_len * sizeof (float));
      for (size_t i = 0; i < data_len; i++)
	{
	  caddr_t elt = ((caddr_t *) data_box)[i];
	  dtp_t bad = onnx_unbox_float (elt, &f32_buf[i]);
	  if (bad)
	    {
	      dk_free ((void *) f32_buf, data_len * sizeof (float));
	      onnx_fail (ONNX_SQLSTATE_INPUT, "ONNX",
		  "Input data element [%lu] is %s, not a number",
		  (unsigned long) i, onnx_dtp_name (bad));
	    }
	}
    }
  else
    onnx_fail (ONNX_SQLSTATE_INPUT, "ONNX", "Input data must be numeric array");
  if (DV_ARRAY_OF_LONG != DV_TYPE_OF (dims_box) &&
      DV_ARRAY_OF_FLOAT != DV_TYPE_OF (dims_box) &&
      DV_ARRAY_OF_POINTER != DV_TYPE_OF (dims_box))
    {
      if (f32_buf != (float *) data_box)
	dk_free ((void *) f32_buf, data_len * sizeof (float));
      onnx_fail (ONNX_SQLSTATE_INPUT, "ONNX", "Dims must be array of int");
    }
  size_t dims_count = 0;
  if (DV_ARRAY_OF_LONG == DV_TYPE_OF (dims_box))
    dims_count = box_length (dims_box) / sizeof (boxint);
  else if (DV_ARRAY_OF_FLOAT == DV_TYPE_OF (dims_box))
    dims_count = box_length (dims_box) / sizeof (float);
  else
    dims_count = BOX_ELEMENTS (dims_box);
  if (dims_count == 0 || dims_count > ONNX_MAX_TENSOR_RANK)
    {
      if (f32_buf != (float *) data_box)
	dk_free ((void *) f32_buf, data_len * sizeof (float));
      onnx_fail (ONNX_SQLSTATE_INPUT, "ONNX", "dims_count must be 1..%d", ONNX_MAX_TENSOR_RANK);
    }
  int64_t dims[ONNX_MAX_TENSOR_RANK];
  size_t expected = 1;
  for (size_t i = 0; i < dims_count; i++)
    {
      boxint d = 0;
      if (DV_ARRAY_OF_LONG == DV_TYPE_OF (dims_box))
	d = ((boxint *) dims_box)[i];
      else if (DV_ARRAY_OF_FLOAT == DV_TYPE_OF (dims_box))
	d = (boxint) ((float *) dims_box)[i];
      else
	{
	  float df = 0;
	  dtp_t bad = onnx_unbox_float (((caddr_t *) dims_box)[i], &df);
	  if (bad)
	    {
	      if (f32_buf != (float *) data_box)
		dk_free ((void *) f32_buf, data_len * sizeof (float));
	      onnx_fail (ONNX_SQLSTATE_INPUT, "ONNX",
		  "Dimension [%lu] is %s, not a number",
		  (unsigned long) i, onnx_dtp_name (bad));
	    }
	  d = (boxint) df;
	}
      if (d <= 0)
	{
	  if (f32_buf != (float *) data_box)
	    dk_free ((void *) f32_buf, data_len * sizeof (float));
	  onnx_fail (ONNX_SQLSTATE_INPUT, "ONNX", "Invalid dimension");
	}
      dims[i] = (int64_t) d;
      if (expected > (SIZE_MAX / (size_t) d))
	{
	  if (f32_buf != (float *) data_box)
	    dk_free ((void *) f32_buf, data_len * sizeof (float));
	  onnx_fail (ONNX_SQLSTATE_INPUT, "ONNX", "Dimension overflow");
	}
      expected *= (size_t) d;
    }
  if (expected != data_len)
    {
      if (f32_buf != (float *) data_box)
	dk_free ((void *) f32_buf, data_len * sizeof (float));
      onnx_fail (ONNX_SQLSTATE_INPUT, "ONNX", "dims product (%lu) != data length (%lu)", (unsigned long) expected, (unsigned long) data_len);
    }
  size_t batch = (dims_count > 1) ? (size_t) dims[0] : 1;
  if (batch > 1)
    onnx_validate_batch ("onnx_run_f32", batch);
  onnx_model_entry_t *m = onnx_model_ref (handle);
  if (!m)
    {
      if (f32_buf != (float *) data_box)
	dk_free ((void *) f32_buf, data_len * sizeof (float));
      onnx_fail (ONNX_SQLSTATE_INPUT, "ONNX", "Unknown or closed model handle %ld", handle);
    }
  caddr_t res = NULL;
  if (m->center_count || m->scale_count)
    {
      /* Scale a private copy: f32_buf may alias the caller's box when the data
	 arrived as DV_ARRAY_OF_FLOAT, and inference must not rewrite it. */
      size_t width = dims[dims_count - 1];
      if (f32_buf == (float *) data_box)
	{
	  float *copy = (float *) dk_alloc (data_len * sizeof (float));
	  memcpy (copy, f32_buf, data_len * sizeof (float));
	  f32_buf = copy;
	}
      ONNX_WITH_MODEL_REF (m, onnx_apply_scaler (m, f32_buf, data_len, width));
    }
  if (g_ctx.caps.mode == ONNX_MODE_OUTPROC)
    ONNX_WITH_MODEL_REF (m, res = onnx_outproc_run_f32 (m, f32_buf, data_len, dims, dims_count, batch));
  else
    ONNX_WITH_MODEL_REF (m, res = onnx_run_f32_inproc (m, f32_buf, data_len, dims, dims_count, batch));
  if (f32_buf != (float *) data_box)
    dk_free ((void *) f32_buf, data_len * sizeof (float));
  onnx_model_unref (m);
  return res;
}

static caddr_t
bif_onnx_run_tokens (caddr_t * qst, caddr_t * err, state_slot_t ** args)
{
  long handle = bif_long_arg (qst, args, 0, "onnx_run_tokens");
  caddr_t ids_box = bif_array_arg (qst, args, 1, "onnx_run_tokens");
  caddr_t mask_box = bif_array_arg (qst, args, 2, "onnx_run_tokens");
  long seq_len = bif_long_arg (qst, args, 3, "onnx_run_tokens");
  if ((DV_ARRAY_OF_LONG != DV_TYPE_OF (ids_box) && DV_ARRAY_OF_POINTER != DV_TYPE_OF (ids_box)) ||
      (DV_ARRAY_OF_LONG != DV_TYPE_OF (mask_box) && DV_ARRAY_OF_POINTER != DV_TYPE_OF (mask_box)))
    onnx_fail (ONNX_SQLSTATE_INPUT, "ONNX", "input_ids and attention_mask must be int arrays");
  if (seq_len <= 0)
    onnx_fail (ONNX_SQLSTATE_INPUT, "ONNX", "seq_len must be > 0");
  size_t ids_len = (DV_ARRAY_OF_LONG == DV_TYPE_OF (ids_box)) ? (box_length (ids_box) / sizeof (boxint)) : BOX_ELEMENTS (ids_box);
  size_t mask_len = (DV_ARRAY_OF_LONG == DV_TYPE_OF (mask_box)) ? (box_length (mask_box) / sizeof (boxint)) : BOX_ELEMENTS (mask_box);
  if (ids_len != mask_len)
    onnx_fail (ONNX_SQLSTATE_INPUT, "ONNX", "input_ids and attention_mask length mismatch");
  if (ids_len % (size_t) seq_len != 0)
    onnx_fail (ONNX_SQLSTATE_INPUT, "ONNX", "input_ids length not divisible by seq_len");
  size_t batch = ids_len / (size_t) seq_len;
  onnx_validate_batch ("onnx_run_tokens", batch);
  int64_t *ids = (int64_t *) dk_alloc (ids_len * sizeof (int64_t));
  int64_t *mask = (int64_t *) dk_alloc (mask_len * sizeof (int64_t));
  for (size_t i = 0; i < ids_len; i++)
    ids[i] = (int64_t) ((DV_ARRAY_OF_LONG == DV_TYPE_OF (ids_box)) ? ((boxint *) ids_box)[i] : unbox (((caddr_t *) ids_box)[i]));
  for (size_t i = 0; i < mask_len; i++)
    mask[i] = (int64_t) ((DV_ARRAY_OF_LONG == DV_TYPE_OF (mask_box)) ? ((boxint *) mask_box)[i] : unbox (((caddr_t *) mask_box)[i]));
  onnx_model_entry_t *m = onnx_model_ref (handle);
  if (!m)
    {
      dk_free (ids, ids_len * sizeof (int64_t));
      dk_free (mask, mask_len * sizeof (int64_t));
      onnx_fail (ONNX_SQLSTATE_INPUT, "ONNX", "Unknown or closed model handle %ld", handle);
    }
  caddr_t res = NULL;
  if (g_ctx.caps.mode == ONNX_MODE_OUTPROC)
    ONNX_WITH_MODEL_REF (m, res = onnx_outproc_run_i64_2 (m, ids, mask, ids_len, batch, (size_t) seq_len));
  else
    ONNX_WITH_MODEL_REF (m, res = onnx_run_tokens_inproc (m, ids, mask, ids_len, batch, (size_t) seq_len));
  onnx_model_unref (m);
  dk_free (ids, ids_len * sizeof (int64_t));
  dk_free (mask, mask_len * sizeof (int64_t));
  return res;
}


/* Apply the model's declared z-scoring in place, one value per feature.
   WIDTH is the trailing dimension -- the feature count -- so a batch of rows is
   scaled row-wise with the same vector.  A no-op when the model declared no
   scaler, which is every model loaded before this existed. */
static void
onnx_apply_scaler (struct onnx_model_entry_s *m, float *buf, size_t len, size_t width)
{
  size_t i, n = m->center_count ? m->center_count : m->scale_count;
  if (!n)
    return;
  if (n != width)
    onnx_fail (ONNX_SQLSTATE_INPUT, "ONNX",
	"model declares a scaler of %lu values but the input has %lu per row",
	(unsigned long) n, (unsigned long) width);
  for (i = 0; i < len; i++)
    {
      size_t j = i % width;
      float v = buf[i];
      if (m->center_count)
	v -= m->center[j];
      if (m->scale_count)
	v /= m->scale[j];
      buf[i] = v;
    }
}

/* ---------- Generic run: N inputs, M outputs, real element types ---------- */

/* ONNX_RUN_F32 is float-in/float-out and stays that way; its name is its
   contract.  ONNX_RUN is the general entry point: each input carries its own
   name, shape and element type, any number of outputs can be read in one call,
   and a non-float output is returned rather than refused. */

static int
onnx_dtype_from_name (const char *name, ONNXTensorElementDataType *out)
{
  if (!name || !name[0] || !strcmp (name, "float32") || !strcmp (name, "float"))
    *out = ONNX_TENSOR_ELEMENT_DATA_TYPE_FLOAT;
  else if (!strcmp (name, "int64"))
    *out = ONNX_TENSOR_ELEMENT_DATA_TYPE_INT64;
  else if (!strcmp (name, "int32"))
    *out = ONNX_TENSOR_ELEMENT_DATA_TYPE_INT32;
  else if (!strcmp (name, "bool"))
    *out = ONNX_TENSOR_ELEMENT_DATA_TYPE_BOOL;
  else
    return -1;
  return 0;
}

static const char *
onnx_dtype_label (ONNXTensorElementDataType t)
{
  switch (t)
    {
    case ONNX_TENSOR_ELEMENT_DATA_TYPE_FLOAT:  return "float32";
    case ONNX_TENSOR_ELEMENT_DATA_TYPE_DOUBLE: return "float64";
    case ONNX_TENSOR_ELEMENT_DATA_TYPE_INT64:  return "int64";
    case ONNX_TENSOR_ELEMENT_DATA_TYPE_INT32:  return "int32";
    case ONNX_TENSOR_ELEMENT_DATA_TYPE_BOOL:   return "bool";
    case ONNX_TENSOR_ELEMENT_DATA_TYPE_STRING: return "string";
    default:                                   return "an unsupported type";
    }
}

/* As onnx_unbox_float, for integral targets: returns 0, or the offending dtp. */
static dtp_t
onnx_unbox_int (caddr_t elt, int64_t *out)
{
  dtp_t et = DV_TYPE_OF (elt);
  if (DV_RDF == et)
    {
      rdf_box_t *rb = (rdf_box_t *) elt;
      elt = rb->rb_box;
      et = DV_TYPE_OF (elt);
    }
  if (DV_LONG_INT == et || DV_SHORT_INT == et)
    *out = (int64_t) unbox (elt);
  else if (DV_SINGLE_FLOAT == et)
    *out = (int64_t) *(float *) elt;
  else if (DV_DOUBLE_FLOAT == et)
    *out = (int64_t) *(double *) elt;
  else if (DV_NUMERIC == et)
    {
      double d = 0.0;
      numeric_to_double ((numeric_t) elt, &d);
      *out = (int64_t) d;
    }
  else
    return (dtp_t) et;
  return 0;
}

typedef struct
{
  char *name;			/* dk_alloc'd, NUL-terminated */
  size_t name_bytes;		/* strlen + 1, for dk_free */
  void *data;			/* dk_alloc'd element buffer */
  size_t data_bytes;
  size_t elems;
  int64_t dims[ONNX_MAX_TENSOR_RANK];
  size_t dims_count;
  ONNXTensorElementDataType dtype;
} onnx_in_t;

static void
onnx_inputs_free (onnx_in_t *ins, size_t n)
{
  size_t i;
  if (!ins)
    return;
  for (i = 0; i < n; i++)
    {
      if (ins[i].name)
	dk_free (ins[i].name, ins[i].name_bytes);
      if (ins[i].data)
	dk_free (ins[i].data, ins[i].data_bytes);
    }
  dk_free (ins, n * sizeof (onnx_in_t));
}

static size_t
onnx_dtype_width (ONNXTensorElementDataType t)
{
  switch (t)
    {
    case ONNX_TENSOR_ELEMENT_DATA_TYPE_FLOAT: return sizeof (float);
    case ONNX_TENSOR_ELEMENT_DATA_TYPE_INT64: return sizeof (int64_t);
    case ONNX_TENSOR_ELEMENT_DATA_TYPE_INT32: return sizeof (int32_t);
    case ONNX_TENSOR_ELEMENT_DATA_TYPE_BOOL:  return 1;
    default:                                  return 0;
    }
}

/* Turn one SQL result tensor into a box, whatever its element type.  Mirrors
   onnx_output_to_box's batch rule: when the leading dimension is the batch the
   caller asked for, the rows come back separately. */
static caddr_t
onnx_typed_output_to_box (OrtValue *output, size_t batch, char *errbuf, size_t errlen)
{
  OrtTensorTypeAndShapeInfo *info = NULL;
  ONNXTensorElementDataType et;
  size_t elem_count = 0, dims_count = 0, i;
  void *raw = NULL;
  OrtStatus *st;

  errbuf[0] = 0;
  st = g_ctx.api->GetTensorTypeAndShape (output, &info);
  if (st)
    {
      onnx_copy_trunc (errbuf, errlen, "GetTensorTypeAndShape");
      g_ctx.api->ReleaseStatus (st);
      return NULL;
    }
  g_ctx.api->GetTensorElementType (info, &et);
  if (!onnx_dtype_width (et))
    {
      snprintf (errbuf, errlen, "Output is %s, which cannot be returned to SQL",
	  onnx_dtype_label (et));
      g_ctx.api->ReleaseTensorTypeAndShapeInfo (info);
      return NULL;
    }
  g_ctx.api->GetTensorShapeElementCount (info, &elem_count);
  if (onnx_validate_output_size (elem_count, errbuf, errlen))
    {
      g_ctx.api->ReleaseTensorTypeAndShapeInfo (info);
      return NULL;
    }
  g_ctx.api->GetDimensionsCount (info, &dims_count);
  g_ctx.api->GetTensorMutableData (output, &raw);

  size_t per = elem_count;
  size_t rows = 1;
  if (batch > 1 && dims_count > 0 && dims_count <= ONNX_MAX_TENSOR_RANK
      && elem_count % batch == 0)
    {
      int64_t d[ONNX_MAX_TENSOR_RANK];
      g_ctx.api->GetDimensions (info, d, dims_count);
      if (d[0] == (int64_t) batch)
	{
	  rows = batch;
	  per = elem_count / batch;
	}
    }
  g_ctx.api->ReleaseTensorTypeAndShapeInfo (info);

  caddr_t *rowv = (rows > 1)
      ? (caddr_t *) dk_alloc_box (rows * sizeof (caddr_t), DV_ARRAY_OF_POINTER)
      : NULL;
  caddr_t res = NULL;
  size_t r;
  for (r = 0; r < rows; r++)
    {
      caddr_t *vec = (caddr_t *) dk_alloc_box (per * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
      for (i = 0; i < per; i++)
	{
	  size_t k = r * per + i;
	  switch (et)
	    {
	    case ONNX_TENSOR_ELEMENT_DATA_TYPE_FLOAT:
	      vec[i] = box_double ((double) ((float *) raw)[k]); break;
	    case ONNX_TENSOR_ELEMENT_DATA_TYPE_INT64:
	      vec[i] = box_num ((boxint) ((int64_t *) raw)[k]); break;
	    case ONNX_TENSOR_ELEMENT_DATA_TYPE_INT32:
	      vec[i] = box_num ((boxint) ((int32_t *) raw)[k]); break;
	    default:	/* BOOL is one byte per element */
	      vec[i] = box_num (((unsigned char *) raw)[k] ? 1 : 0); break;
	    }
	}
      if (rowv)
	rowv[r] = (caddr_t) vec;
      else
	res = (caddr_t) vec;
    }
  return rowv ? (caddr_t) rowv : res;
}

typedef struct
{
  onnx_model_entry_t *model;
  onnx_in_t *ins;
  size_t n_in;
  const char **out_names;
  size_t n_out;
  size_t batch;
  caddr_t result;
  char err_msg[256];
} onnx_multi_ctx_t;

static int
onnx_run_multi_body (void *arg)
{
  onnx_multi_ctx_t *ctx = (onnx_multi_ctx_t *) arg;
  OrtMemoryInfo *mem = NULL;
  OrtValue **in_vals = NULL, **out_vals = NULL;
  const char **in_names = NULL;
  OrtStatus *st = NULL;
  size_t i;
  int rc = -1;

  st = g_ctx.api->CreateCpuMemoryInfo (OrtArenaAllocator, OrtMemTypeDefault, &mem);
  if (st)
    {
      onnx_copy_trunc (ctx->err_msg, sizeof (ctx->err_msg), "CreateCpuMemoryInfo");
      g_ctx.api->ReleaseStatus (st);
      return -1;
    }
  in_vals = (OrtValue **) dk_alloc (ctx->n_in * sizeof (OrtValue *));
  memset (in_vals, 0, ctx->n_in * sizeof (OrtValue *));
  in_names = (const char **) dk_alloc (ctx->n_in * sizeof (char *));
  out_vals = (OrtValue **) dk_alloc (ctx->n_out * sizeof (OrtValue *));
  memset (out_vals, 0, ctx->n_out * sizeof (OrtValue *));

  for (i = 0; i < ctx->n_in; i++)
    {
      in_names[i] = ctx->ins[i].name;
      st = g_ctx.api->CreateTensorWithDataAsOrtValue (mem, ctx->ins[i].data,
	  ctx->ins[i].data_bytes, ctx->ins[i].dims, ctx->ins[i].dims_count,
	  ctx->ins[i].dtype, &in_vals[i]);
      if (st)
	{
	  snprintf (ctx->err_msg, sizeof (ctx->err_msg),
	      "CreateTensor for input '%s'", ctx->ins[i].name);
	  g_ctx.api->ReleaseStatus (st);
	  goto done;
	}
    }
  st = g_ctx.api->Run (ctx->model->session, NULL, in_names,
      (const OrtValue * const *) in_vals, ctx->n_in,
      ctx->out_names, ctx->n_out, out_vals);
  if (st)
    {
      const char *m = g_ctx.api->GetErrorMessage (st);
      onnx_copy_trunc (ctx->err_msg, sizeof (ctx->err_msg), m ? m : "Run failed");
      g_ctx.api->ReleaseStatus (st);
      goto done;
    }
  if (1 == ctx->n_out)
    {
      ctx->result = onnx_typed_output_to_box (out_vals[0], ctx->batch,
	  ctx->err_msg, sizeof (ctx->err_msg));
      if (!ctx->result)
	goto done;
    }
  else
    {
      caddr_t *all = (caddr_t *) dk_alloc_box (ctx->n_out * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
      memset (all, 0, ctx->n_out * sizeof (caddr_t));
      for (i = 0; i < ctx->n_out; i++)
	{
	  all[i] = onnx_typed_output_to_box (out_vals[i], ctx->batch,
	      ctx->err_msg, sizeof (ctx->err_msg));
	  if (!all[i])
	    {
	      dk_free_tree ((box_t) all);
	      goto done;
	    }
	}
      ctx->result = (caddr_t) all;
    }
  rc = 0;

done:
  for (i = 0; i < ctx->n_in; i++)
    if (in_vals && in_vals[i])
      g_ctx.api->ReleaseValue (in_vals[i]);
  for (i = 0; i < ctx->n_out; i++)
    if (out_vals && out_vals[i])
      g_ctx.api->ReleaseValue (out_vals[i]);
  if (in_vals)
    dk_free (in_vals, ctx->n_in * sizeof (OrtValue *));
  if (in_names)
    dk_free ((void *) in_names, ctx->n_in * sizeof (char *));
  if (out_vals)
    dk_free (out_vals, ctx->n_out * sizeof (OrtValue *));
  g_ctx.api->ReleaseMemoryInfo (mem);
  return rc;
}


/* One output tensor out of an op-5 response: dtype, shape, then the elements. */
static caddr_t
onnx_ipc_parse_one_output (const char *resp, size_t resp_len, size_t *pos, size_t batch,
    char *errbuf, size_t errlen)
{
  uint32_t dtype = 0, dcount = 0, elems = 0;
  int64_t dims[ONNX_MAX_TENSOR_RANK];
  size_t i, width;

  if (*pos + 2 * sizeof (uint32_t) > resp_len)
    { onnx_copy_trunc (errbuf, errlen, "truncated output header"); return NULL; }
  memcpy (&dtype, resp + *pos, sizeof (uint32_t)); *pos += sizeof (uint32_t);
  memcpy (&dcount, resp + *pos, sizeof (uint32_t)); *pos += sizeof (uint32_t);
  if (dcount > ONNX_MAX_TENSOR_RANK || *pos + dcount * sizeof (int64_t) + sizeof (uint32_t) > resp_len)
    { onnx_copy_trunc (errbuf, errlen, "truncated output shape"); return NULL; }
  for (i = 0; i < dcount; i++)
    { memcpy (&dims[i], resp + *pos, sizeof (int64_t)); *pos += sizeof (int64_t); }
  memcpy (&elems, resp + *pos, sizeof (uint32_t)); *pos += sizeof (uint32_t);
  width = onnx_dtype_width ((ONNXTensorElementDataType) dtype);
  if (!width)
    { onnx_copy_trunc (errbuf, errlen, "unsupported output element type"); return NULL; }
  if (*pos + (size_t) elems * width > resp_len)
    { onnx_copy_trunc (errbuf, errlen, "truncated output data"); return NULL; }
  if (onnx_validate_output_size (elems, errbuf, errlen))
    return NULL;
  const char *raw = resp + *pos;
  *pos += (size_t) elems * width;

  /* Same batch rule as in-process: split only when the leading dimension is
     the batch the caller asked for. */
  size_t rows = 1, per = elems;
  if (batch > 1 && dcount > 0 && elems % batch == 0 && dims[0] == (int64_t) batch)
    { rows = batch; per = elems / batch; }

  caddr_t *rowv = (rows > 1)
      ? (caddr_t *) dk_alloc_box (rows * sizeof (caddr_t), DV_ARRAY_OF_POINTER) : NULL;
  caddr_t res = NULL;
  size_t r;
  for (r = 0; r < rows; r++)
    {
      caddr_t *vec = (caddr_t *) dk_alloc_box (per * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
      for (i = 0; i < per; i++)
	{
	  size_t k = r * per + i;
	  switch ((ONNXTensorElementDataType) dtype)
	    {
	    case ONNX_TENSOR_ELEMENT_DATA_TYPE_FLOAT:
	      vec[i] = box_double ((double) ((const float *) raw)[k]); break;
	    case ONNX_TENSOR_ELEMENT_DATA_TYPE_INT64:
	      vec[i] = box_num ((boxint) ((const int64_t *) raw)[k]); break;
	    case ONNX_TENSOR_ELEMENT_DATA_TYPE_INT32:
	      vec[i] = box_num ((boxint) ((const int32_t *) raw)[k]); break;
	    default:
	      vec[i] = box_num (((const unsigned char *) raw)[k] ? 1 : 0); break;
	    }
	}
      if (rowv) rowv[r] = (caddr_t) vec; else res = (caddr_t) vec;
    }
  return rowv ? (caddr_t) rowv : res;
}

static caddr_t
onnx_outproc_run_multi (onnx_model_entry_t *m, onnx_in_t *ins, size_t n_in,
    const char **names, size_t n_out, size_t batch)
{
  /* op word + n_inputs word + n_outputs word; the per-tensor sizes follow. */
  size_t i, payload_len = 3 * sizeof (uint32_t), off = 0, total_in = 0;
  char errbuf[256];

  for (i = 0; i < n_in; i++)
    {
      payload_len += sizeof (uint32_t) + strlen (ins[i].name)	/* name */
	+ sizeof (uint32_t)					/* dtype */
	+ sizeof (uint32_t) + ins[i].dims_count * sizeof (int64_t)
	+ sizeof (uint32_t) + ins[i].data_bytes;
      total_in += ins[i].data_bytes;
    }
  for (i = 0; i < n_out; i++)
    payload_len += sizeof (uint32_t) + (names[i] ? strlen (names[i]) : 0);
  if (total_in > g_ctx.caps.max_tensor_bytes)
    onnx_fail (ONNX_SQLSTATE_INPUT, "ONNX", "Input tensors exceed max_tensor_bytes");
  if (onnx_helper_ensure_pool (m))
    onnx_fail (ONNX_SQLSTATE_RUNTIME, "ONNX", "Helper pool not initialized");
  onnx_helper_proc_t *hp = onnx_helper_acquire_or_respawn (m);
  if (!hp)
    onnx_fail (ONNX_SQLSTATE_RUNTIME, "ONNX", "No live helper available");

  char *payload = (char *) dk_alloc (payload_len);
  uint32_t u;
  u = ONNX_IPC_OP_RUN_MULTI; memcpy (payload + off, &u, sizeof (u)); off += sizeof (u);
  u = (uint32_t) n_in;       memcpy (payload + off, &u, sizeof (u)); off += sizeof (u);
  for (i = 0; i < n_in; i++)
    {
      size_t nl = strlen (ins[i].name);
      u = (uint32_t) nl;            memcpy (payload + off, &u, sizeof (u)); off += sizeof (u);
      memcpy (payload + off, ins[i].name, nl); off += nl;
      u = (uint32_t) ins[i].dtype;  memcpy (payload + off, &u, sizeof (u)); off += sizeof (u);
      u = (uint32_t) ins[i].dims_count; memcpy (payload + off, &u, sizeof (u)); off += sizeof (u);
      memcpy (payload + off, ins[i].dims, ins[i].dims_count * sizeof (int64_t));
      off += ins[i].dims_count * sizeof (int64_t);
      u = (uint32_t) ins[i].data_bytes; memcpy (payload + off, &u, sizeof (u)); off += sizeof (u);
      memcpy (payload + off, ins[i].data, ins[i].data_bytes); off += ins[i].data_bytes;
    }
  u = (uint32_t) n_out; memcpy (payload + off, &u, sizeof (u)); off += sizeof (u);
  for (i = 0; i < n_out; i++)
    {
      size_t nl = names[i] ? strlen (names[i]) : 0;
      u = (uint32_t) nl; memcpy (payload + off, &u, sizeof (u)); off += sizeof (u);
      if (nl) { memcpy (payload + off, names[i], nl); off += nl; }
    }

  onnx_ipc_hdr_t hdr;
  memset (&hdr, 0, sizeof (hdr));
  hdr.magic = ONNX_IPC_MAGIC;
  hdr.version = ONNX_IPC_VERSION;
  hdr.flags = g_ctx.caps.telemetry ? ONNX_IPC_FLAG_TELEMETRY : 0;
  hdr.batch_count = (uint32_t) batch;
  hdr.payload_len = (uint32_t) payload_len;
  if (onnx_ipc_send_request (hp, &hdr, payload, payload_len))
    {
      onnx_helper_close (hp);
      dk_free (payload, payload_len);
      onnx_helper_release (m, hp);
      onnx_fail (ONNX_SQLSTATE_RUNTIME, "ONNX", "Failed to send to helper");
    }
  dk_free (payload, payload_len);

  size_t resp_cap = g_ctx.caps.max_tensor_bytes + 1024
      + n_out * (4 * sizeof (uint32_t) + ONNX_MAX_TENSOR_RANK * sizeof (int64_t));
  char *resp = (char *) dk_alloc (resp_cap);
  onnx_ipc_hdr_t rhdr;
  if (onnx_ipc_recv_response (hp, &rhdr, resp, resp_cap))
    {
      onnx_helper_close (hp);
      dk_free (resp, resp_cap);
      onnx_helper_release (m, hp);
      onnx_fail (ONNX_SQLSTATE_RUNTIME, "ONNX", "Failed to read from helper");
    }
  if (rhdr.status != 0)
    {
      char msg[256];
      onnx_copy_trunc (msg, sizeof (msg),
	  (rhdr.payload_len > sizeof (uint32_t)) ? resp + sizeof (uint32_t) : "helper error");
      dk_free (resp, resp_cap);
      onnx_helper_release (m, hp);
      onnx_fail (ONNX_SQLSTATE_RUNTIME, "ONNX", "Helper error: %s", msg);
    }
  onnx_helper_release (m, hp);	/* exchange done; the parse below can longjmp */

  size_t pos = 0, resp_len = rhdr.payload_len;
  if (rhdr.flags & ONNX_IPC_FLAG_TELEMETRY)
    pos += 2 * sizeof (uint64_t);
  uint32_t got = 0;
  errbuf[0] = 0;
  if (pos + sizeof (uint32_t) > resp_len)
    { dk_free (resp, resp_cap); onnx_fail (ONNX_SQLSTATE_RUNTIME, "ONNX", "Helper response truncated"); }
  memcpy (&got, resp + pos, sizeof (uint32_t)); pos += sizeof (uint32_t);
  if (got != (uint32_t) n_out)
    { dk_free (resp, resp_cap);
      onnx_fail (ONNX_SQLSTATE_RUNTIME, "ONNX", "Helper returned %u outputs, expected %lu",
	  got, (unsigned long) n_out); }

  caddr_t single = NULL;
  caddr_t *all = (n_out > 1)
      ? (caddr_t *) dk_alloc_box (n_out * sizeof (caddr_t), DV_ARRAY_OF_POINTER) : NULL;
  if (all)
    memset (all, 0, n_out * sizeof (caddr_t));
  for (i = 0; i < n_out; i++)
    {
      caddr_t one = onnx_ipc_parse_one_output (resp, resp_len, &pos, batch, errbuf, sizeof (errbuf));
      if (!one)
	{
	  if (all) dk_free_tree ((box_t) all);
	  dk_free (resp, resp_cap);
	  onnx_fail (ONNX_SQLSTATE_RUNTIME, "ONNX", "onnx_run: %s",
	      errbuf[0] ? errbuf : "bad helper response");
	}
      if (all) all[i] = one; else single = one;
    }
  dk_free (resp, resp_cap);
  return all ? (caddr_t) all : single;
}

/* Choose the execution path and run.  Returns the boxed result, or raises. */
static caddr_t
onnx_run_multi (onnx_model_entry_t *m, onnx_in_t *ins, size_t n_in,
    caddr_t *out_boxes, size_t n_out, const char *default_out, size_t batch)
{
  onnx_multi_ctx_t ctx;
  const char **names = NULL;
  size_t n = n_out ? n_out : 1;
  size_t i;
  caddr_t res = NULL;

  names = (const char **) dk_alloc (n * sizeof (char *));
  if (n_out)
    for (i = 0; i < n_out; i++)
      names[i] = (const char *) out_boxes[i];
  else
    names[0] = default_out;	/* the output detected at load */

  memset (&ctx, 0, sizeof (ctx));
  ctx.model = m;
  ctx.ins = ins;
  ctx.n_in = n_in;
  ctx.out_names = names;
  ctx.n_out = n;
  ctx.batch = batch;

  if (m->session)
    {
#ifndef _WIN32
      int sig = onnx_guard_begin ();
      if (sig)
	{
	  dk_free ((void *) names, n * sizeof (char *));
	  onnx_fail (ONNX_SQLSTATE_RUNTIME, "ONNX", "Native fault (signal %d) during inference", sig);
	}
      int rc = onnx_run_multi_body (&ctx);
      onnx_guard_end ();
#else
      int rc = onnx_guard_run (onnx_run_multi_body, &ctx);
#endif
      if (rc)
	{
	  char msg[256];
	  onnx_copy_trunc (msg, sizeof (msg), ctx.err_msg[0] ? ctx.err_msg : "Inference failed");
	  dk_free ((void *) names, n * sizeof (char *));
	  onnx_fail (ONNX_SQLSTATE_RUNTIME, "ONNX", "onnx_run: %s", msg);
	}
      res = ctx.result;
    }
  else
    {
      res = onnx_outproc_run_multi (m, ins, n_in, names, n, batch);
    }
  dk_free ((void *) names, n * sizeof (char *));
  return res;
}
static caddr_t
bif_onnx_run (caddr_t * qst, caddr_t * err, state_slot_t ** args)
{
  long handle = bif_long_arg (qst, args, 0, "onnx_run");
  caddr_t ins_box = bif_array_arg (qst, args, 1, "onnx_run");
  onnx_in_t *ins = NULL;
  const char **out_names = NULL;
  caddr_t *out_name_boxes = NULL;
  size_t n_in = 0, n_out = 0, i;

  if (DV_ARRAY_OF_POINTER != DV_TYPE_OF (ins_box) || 0 == BOX_ELEMENTS (ins_box))
    onnx_fail (ONNX_SQLSTATE_INPUT, "ONNX",
	"onnx_run: inputs must be a non-empty vector of vector (name, data, dims [, dtype])");
  n_in = BOX_ELEMENTS (ins_box);
  ins = (onnx_in_t *) dk_alloc (n_in * sizeof (onnx_in_t));
  memset (ins, 0, n_in * sizeof (onnx_in_t));

  for (i = 0; i < n_in; i++)
    {
      caddr_t d = ((caddr_t *) ins_box)[i];
      size_t nelt = (d && DV_ARRAY_OF_POINTER == DV_TYPE_OF (d)) ? BOX_ELEMENTS (d) : 0;
      if (nelt < 3 || nelt > 4)
	{
	  onnx_inputs_free (ins, n_in);
	  onnx_fail (ONNX_SQLSTATE_INPUT, "ONNX",
	      "onnx_run: input [%lu] must be vector (name, data, dims [, dtype])",
	      (unsigned long) i);
	}
      caddr_t nm = ((caddr_t *) d)[0];
      caddr_t data = ((caddr_t *) d)[1];
      caddr_t dims = ((caddr_t *) d)[2];
      if (!nm || (DV_STRING != DV_TYPE_OF (nm) && DV_UNAME != DV_TYPE_OF (nm)))
	{
	  onnx_inputs_free (ins, n_in);
	  onnx_fail (ONNX_SQLSTATE_INPUT, "ONNX", "onnx_run: input [%lu] name must be a string",
	      (unsigned long) i);
	}
      ONNXTensorElementDataType dt = ONNX_TENSOR_ELEMENT_DATA_TYPE_FLOAT;
      if (4 == nelt)
	{
	  caddr_t tb = ((caddr_t *) d)[3];
	  if (!tb || (DV_STRING != DV_TYPE_OF (tb) && DV_UNAME != DV_TYPE_OF (tb))
	      || onnx_dtype_from_name (tb, &dt))
	    {
	      onnx_inputs_free (ins, n_in);
	      onnx_fail (ONNX_SQLSTATE_INPUT, "ONNX",
		  "onnx_run: input [%lu] dtype must be float32, int64, int32 or bool",
		  (unsigned long) i);
	    }
	}
      ins[i].dtype = dt;
      ins[i].name_bytes = strlen (nm) + 1;
      ins[i].name = (char *) dk_alloc (ins[i].name_bytes);
      memcpy (ins[i].name, nm, ins[i].name_bytes);

      /* shape */
      if (!dims || DV_ARRAY_OF_POINTER != DV_TYPE_OF (dims)
	  || 0 == BOX_ELEMENTS (dims) || BOX_ELEMENTS (dims) > ONNX_MAX_TENSOR_RANK)
	{
	  onnx_inputs_free (ins, n_in);
	  onnx_fail (ONNX_SQLSTATE_INPUT, "ONNX",
	      "onnx_run: input [%lu] dims must be a vector of 1..%d positive integers",
	      (unsigned long) i, ONNX_MAX_TENSOR_RANK);
	}
      ins[i].dims_count = BOX_ELEMENTS (dims);
      size_t expect = 1, k;
      for (k = 0; k < ins[i].dims_count; k++)
	{
	  int64_t dv = 0;
	  dtp_t bad = onnx_unbox_int (((caddr_t *) dims)[k], &dv);
	  if (bad || dv <= 0)
	    {
	      onnx_inputs_free (ins, n_in);
	      onnx_fail (ONNX_SQLSTATE_INPUT, "ONNX",
		  "onnx_run: input [%lu] dimension [%lu] is not a positive integer",
		  (unsigned long) i, (unsigned long) k);
	    }
	  ins[i].dims[k] = dv;
	  expect *= (size_t) dv;
	}
      /* elements */
      if (!data || DV_ARRAY_OF_POINTER != DV_TYPE_OF (data))
	{
	  onnx_inputs_free (ins, n_in);
	  onnx_fail (ONNX_SQLSTATE_INPUT, "ONNX",
	      "onnx_run: input [%lu] data must be a vector of numbers", (unsigned long) i);
	}
      size_t n_elt = BOX_ELEMENTS (data);
      if (n_elt != expect)
	{
	  onnx_inputs_free (ins, n_in);
	  onnx_fail (ONNX_SQLSTATE_INPUT, "ONNX",
	      "onnx_run: input '%s' dims product (%lu) != data length (%lu)",
	      ins[i].name, (unsigned long) expect, (unsigned long) n_elt);
	}
      size_t w = onnx_dtype_width (dt);
      ins[i].elems = n_elt;
      ins[i].data_bytes = n_elt * w;
      ins[i].data = dk_alloc (ins[i].data_bytes ? ins[i].data_bytes : 1);
      for (k = 0; k < n_elt; k++)
	{
	  caddr_t elt = ((caddr_t *) data)[k];
	  dtp_t bad;
	  if (ONNX_TENSOR_ELEMENT_DATA_TYPE_FLOAT == dt)
	    bad = onnx_unbox_float (elt, &((float *) ins[i].data)[k]);
	  else
	    {
	      int64_t v = 0;
	      bad = onnx_unbox_int (elt, &v);
	      if (!bad)
		{
		  if (ONNX_TENSOR_ELEMENT_DATA_TYPE_INT64 == dt)
		    ((int64_t *) ins[i].data)[k] = v;
		  else if (ONNX_TENSOR_ELEMENT_DATA_TYPE_INT32 == dt)
		    ((int32_t *) ins[i].data)[k] = (int32_t) v;
		  else
		    ((unsigned char *) ins[i].data)[k] = v ? 1 : 0;
		}
	    }
	  if (bad)
	    {
	      char nmbuf[128];
	      onnx_copy_trunc (nmbuf, sizeof (nmbuf), ins[i].name);
	      onnx_inputs_free (ins, n_in);
	      onnx_fail (ONNX_SQLSTATE_INPUT, "ONNX",
		  "onnx_run: input '%s' element [%lu] is %s, not a number",
		  nmbuf, (unsigned long) k, onnx_dtp_name (bad));
	    }
	}
    }

  /* Requested outputs: omitted/NULL is output 0, a string is one, a vector is
     several, returned in the order asked for. */
  caddr_t out_arg = (BOX_ELEMENTS (args) > 2 && args[2])
      ? bif_arg (qst, args, 2, "onnx_run") : NULL;
  if (!out_arg || DV_DB_NULL == DV_TYPE_OF (out_arg))
    n_out = 0;
  else if (DV_STRING == DV_TYPE_OF (out_arg) || DV_UNAME == DV_TYPE_OF (out_arg))
    {
      n_out = 1;
      out_name_boxes = (caddr_t *) dk_alloc (sizeof (caddr_t));
      out_name_boxes[0] = out_arg;
    }
  else if (DV_ARRAY_OF_POINTER == DV_TYPE_OF (out_arg) && BOX_ELEMENTS (out_arg) > 0)
    {
      n_out = BOX_ELEMENTS (out_arg);
      out_name_boxes = (caddr_t *) dk_alloc (n_out * sizeof (caddr_t));
      for (i = 0; i < n_out; i++)
	{
	  caddr_t o = ((caddr_t *) out_arg)[i];
	  if (!o || (DV_STRING != DV_TYPE_OF (o) && DV_UNAME != DV_TYPE_OF (o)))
	    {
	      dk_free (out_name_boxes, n_out * sizeof (caddr_t));
	      onnx_inputs_free (ins, n_in);
	      onnx_fail (ONNX_SQLSTATE_INPUT, "ONNX",
		  "onnx_run: output [%lu] must be a tensor name", (unsigned long) i);
	    }
	  out_name_boxes[i] = o;
	}
    }
  else
    {
      onnx_inputs_free (ins, n_in);
      onnx_fail (ONNX_SQLSTATE_INPUT, "ONNX",
	  "onnx_run: outputs must be NULL, a name, or a vector of names");
    }

  size_t batch = (ins[0].dims_count > 1) ? (size_t) ins[0].dims[0] : 1;
  if (batch > 1)
    {
      if (batch > g_ctx.caps.max_batch)
	{
	  if (out_name_boxes)
	    dk_free (out_name_boxes, (n_out ? n_out : 1) * sizeof (caddr_t));
	  onnx_inputs_free (ins, n_in);
	  onnx_fail (ONNX_SQLSTATE_INPUT, "ONNX", "onnx_run: batch too large (%lu > %lu)",
	      (unsigned long) batch, (unsigned long) g_ctx.caps.max_batch);
	}
    }

  onnx_model_entry_t *m = onnx_model_ref (handle);
  if (!m)
    {
      if (out_name_boxes)
	dk_free (out_name_boxes, (n_out ? n_out : 1) * sizeof (caddr_t));
      onnx_inputs_free (ins, n_in);
      onnx_fail (ONNX_SQLSTATE_INPUT, "ONNX", "Unknown or closed model handle %ld", handle);
    }

  /* Scale the model's own input, if it declared a scaler.  Only that input:
     the scaler describes the feature vector, not every tensor the graph takes. */
  if (m->center_count || m->scale_count)
    for (i = 0; i < n_in; i++)
      if (ONNX_TENSOR_ELEMENT_DATA_TYPE_FLOAT == ins[i].dtype
	  && (!m->input_name || !strcmp (ins[i].name, m->input_name)))
	{
	  ONNX_WITH_MODEL_REF (m, onnx_apply_scaler (m, (float *) ins[i].data,
		ins[i].elems, (size_t) ins[i].dims[ins[i].dims_count - 1]));
	  break;
	}

  /* Default output: whatever the model reported at load. */
  const char *default_out = m->output_name;
  caddr_t res = NULL;
  ONNX_WITH_MODEL_REF (m, res = onnx_run_multi (m, ins, n_in, out_name_boxes, n_out,
					        default_out, batch));
  onnx_model_unref (m);
  if (out_name_boxes)
    dk_free (out_name_boxes, (n_out ? n_out : 1) * sizeof (caddr_t));
  onnx_inputs_free (ins, n_in);
  return res;
}

/* ---------- Persistent ORT worker thread ---------- */
/* ONNX Runtime's CreateSession crashes when called from Virtuoso
   worker threads but works on the main thread. We spawn a persistent
   worker thread during vonnx_connect (which runs on the main thread)
   and dispatch all CreateSession calls to it. */

#ifndef _WIN32
typedef struct
{
  OrtEnv *env;
  const char *path;
  OrtSessionOptions *opts;
  OrtSession **out_session;
  OrtStatus *result;
} onnx_cs_req_t;

static struct
{
  pthread_t tid;
  pthread_mutex_t mtx;
  pthread_cond_t req_cond;
  pthread_cond_t done_cond;
  onnx_cs_req_t *req;
  int shutdown;
  int started;
} onnx_worker = { 0, PTHREAD_MUTEX_INITIALIZER, PTHREAD_COND_INITIALIZER, PTHREAD_COND_INITIALIZER, NULL, 0, 0 };

static void *
onnx_worker_fn (void *arg)
{
  (void) arg;
  pthread_mutex_lock (&onnx_worker.mtx);
  for (;;)
    {
      while (!onnx_worker.req && !onnx_worker.shutdown)
	pthread_cond_wait (&onnx_worker.req_cond, &onnx_worker.mtx);
      if (onnx_worker.shutdown)
	break;
      onnx_cs_req_t *r = onnx_worker.req;
      r->result = g_ctx.api->CreateSession (r->env, r->path, r->opts, r->out_session);
      onnx_worker.req = NULL;
      pthread_cond_signal (&onnx_worker.done_cond);
    }
  pthread_mutex_unlock (&onnx_worker.mtx);
  return NULL;
}

static void
onnx_worker_start (void)
{
  if (onnx_worker.started)
    return;
  onnx_worker.shutdown = 0;
  onnx_worker.req = NULL;
  pthread_create (&onnx_worker.tid, NULL, onnx_worker_fn, NULL);
  onnx_worker.started = 1;
}

static void
onnx_worker_stop (void)
{
  if (!onnx_worker.started)
    return;
  pthread_mutex_lock (&onnx_worker.mtx);
  onnx_worker.shutdown = 1;
  pthread_cond_signal (&onnx_worker.req_cond);
  pthread_mutex_unlock (&onnx_worker.mtx);
  pthread_join (onnx_worker.tid, NULL);
  onnx_worker.started = 0;
}

static OrtStatus *
onnx_create_session_safe (OrtEnv *env, const char *path, OrtSessionOptions *opts, OrtSession **out)
{
  onnx_cs_req_t req;
  req.env = env;
  req.path = path;
  req.opts = opts;
  req.out_session = out;
  req.result = NULL;
  *out = NULL;

  pthread_mutex_lock (&onnx_worker.mtx);
  onnx_worker.req = &req;
  pthread_cond_signal (&onnx_worker.req_cond);
  while (onnx_worker.req)
    pthread_cond_wait (&onnx_worker.done_cond, &onnx_worker.mtx);
  pthread_mutex_unlock (&onnx_worker.mtx);
  return req.result;
}
#else
static void onnx_worker_start (void) {}
static void onnx_worker_stop (void) {}
static OrtStatus *
onnx_create_session_safe (OrtEnv *env, const char *path, OrtSessionOptions *opts, OrtSession **out)
{
  return g_ctx.api->CreateSession (env, path, opts, out);
}
#endif

/* ---------- Model load/unload/info ---------- */

static caddr_t
bif_onnx_load (caddr_t * qst, caddr_t * err, state_slot_t ** args)
{
  /* Loading a model runs a caller-named file through the ONNX Runtime inside
     the server process, so it is an administrative operation, not a query.
     Without this any account that could open a session could do it. */
  sec_check_dba ((query_instance_t *) qst, "onnx_load_model");
  caddr_t path_box = bif_string_arg (qst, args, 0, "onnx_load_model");
  const char *path = path_box;
  if (!path || !*path)
    onnx_fail (ONNX_SQLSTATE_INPUT, "ONNX", "Model path required");
  /* ...and even for the DBA the path is checked, because what used to stop a
     non-model path was the ONNX parser failing to parse it, which is not an
     authorization boundary. */
  if (!onnx_path_is_permitted (path))
    file_path_assert (path_box, NULL, 0);
  size_t path_len = box_length (path_box) - 1;
  if (path_len > 4096)
    onnx_fail (ONNX_SQLSTATE_INPUT, "ONNX", "Model path too long");
  onnx_load_options_t lo;
  onnx_load_options_init (&lo);
  if (BOX_ELEMENTS (args) > 1 && args[1])
    {
      caddr_t opt_box = bif_arg (qst, args, 1, "onnx_load_model");
      if (opt_box && DV_STRING == DV_TYPE_OF (opt_box))
	onnx_parse_kv_options (opt_box, &lo);
    }
  if (lo.max_seq_len
      && (lo.max_seq_len < ONNX_MAX_SEQ_LEN_MIN || lo.max_seq_len > ONNX_MAX_SEQ_LEN_MAX))
    {
      int bad = lo.max_seq_len;
      onnx_load_options_free (&lo);
      onnx_fail (ONNX_SQLSTATE_INPUT, "ONNX", "max_seq_len %d is out of range (%d..%d)",
	  bad, ONNX_MAX_SEQ_LEN_MIN, ONNX_MAX_SEQ_LEN_MAX);
    }
  {
    char why[128];
    if (onnx_batching_options_check (&lo, why, sizeof (why)))
      {
	onnx_load_options_free (&lo);
	onnx_fail (ONNX_SQLSTATE_INPUT, "ONNX", "%s", why);
      }
  }
  /* Same rule for every other file the options can name. */
  if (lo.vocab_path[0] && !onnx_path_is_permitted (lo.vocab_path))
    file_path_assert (box_dv_short_string (lo.vocab_path), NULL, 1);
  if (lo.gliner2_dir[0] && !onnx_path_is_permitted (lo.gliner2_dir))
    file_path_assert (box_dv_short_string (lo.gliner2_dir), NULL, 1);
  if (lo.gliner2_vocab[0] && !onnx_path_is_permitted (lo.gliner2_vocab))
    file_path_assert (box_dv_short_string (lo.gliner2_vocab), NULL, 1);
  onnx_mode_t cur_mode;
  cur_mode = (lo.override_mode >= 0) ? (onnx_mode_t) lo.override_mode : g_ctx.caps.mode;
  mutex_enter (g_ctx.mtx);
  onnx_model_entry_t *existing = onnx_model_lookup_loaded_by_signature (path, &lo, cur_mode);
  if (existing)
    {
      long existing_handle = existing->handle;
      mutex_leave (g_ctx.mtx);
      onnx_load_options_free (&lo);
      return box_num (existing_handle);
    }
  long handle = g_ctx.next_handle++;
  if (lo.override_mode >= 0)
    g_ctx.caps.mode = (onnx_mode_t) lo.override_mode;
  mutex_leave (g_ctx.mtx);

  onnx_model_entry_t *m = (onnx_model_entry_t *) dk_alloc (sizeof (*m));
  memset (m, 0, sizeof (*m));
  m->handle = handle;
  m->path = onnx_dup_string (path, strlen (path));
  if (lo.input_name[0])
    m->input_name = onnx_dup_string (lo.input_name, strlen (lo.input_name));
  if (lo.input_name2[0])
    m->input_name2 = onnx_dup_string (lo.input_name2, strlen (lo.input_name2));
  if (lo.input_name3[0])
    m->input_name3 = onnx_dup_string (lo.input_name3, strlen (lo.input_name3));
  if (lo.output_name[0])
    m->output_name = onnx_dup_string (lo.output_name, strlen (lo.output_name));
  /* Keep the request itself, before onnx_detect_io fills the blanks in above.
     This is what onnx_model_lookup_loaded_by_signature matches on. */
  if (lo.input_name[0])
    m->req_input_name = onnx_dup_string (lo.input_name, strlen (lo.input_name));
  if (lo.input_name2[0])
    m->req_input_name2 = onnx_dup_string (lo.input_name2, strlen (lo.input_name2));
  if (lo.input_name3[0])
    m->req_input_name3 = onnx_dup_string (lo.input_name3, strlen (lo.input_name3));
  if (lo.output_name[0])
    m->req_output_name = onnx_dup_string (lo.output_name, strlen (lo.output_name));
  if (lo.center_count)
    {
      m->center_count = lo.center_count;
      m->center = (float *) dk_alloc (lo.center_count * sizeof (float));
      memcpy (m->center, lo.center, lo.center_count * sizeof (float));
    }
  if (lo.scale_count)
    {
      m->scale_count = lo.scale_count;
      m->scale = (float *) dk_alloc (lo.scale_count * sizeof (float));
      memcpy (m->scale, lo.scale, lo.scale_count * sizeof (float));
      size_t si;
      for (si = 0; si < m->scale_count; si++)
	if (0.0f == m->scale[si])
	  {
	    onnx_model_release (m);
	    onnx_fail (ONNX_SQLSTATE_INPUT, "ONNX", "scale[%lu] is zero", (unsigned long) si);
	  }
    }
  if (m->center_count && m->scale_count && m->center_count != m->scale_count)
    {
      size_t cc = m->center_count, sc = m->scale_count;
      onnx_model_release (m);
      onnx_fail (ONNX_SQLSTATE_INPUT, "ONNX",
	  "center has %lu values but scale has %lu", (unsigned long) cc, (unsigned long) sc);
    }
  onnx_load_options_free (&lo);	/* copied onto the entry above */
  if (lo.vocab_path[0])
    m->vocab_path = onnx_dup_string (lo.vocab_path, strlen (lo.vocab_path));
  if (lo.gliner2_dir[0])
    m->gliner2_dir = onnx_dup_string (lo.gliner2_dir, strlen (lo.gliner2_dir));
  if (lo.gliner2_vocab[0])
    m->gliner2_vocab_path = onnx_dup_string (lo.gliner2_vocab, strlen (lo.gliner2_vocab));
  m->refcnt = 0;
  m->mtx = mutex_allocate ();
  m->helper_mtx = NULL;
  m->helpers = NULL;
  m->helper_count = 0;
  m->helper_rr = 0;
  m->intra_threads = onnx_threads_norm (lo.intra_threads);
  m->inter_threads = onnx_threads_norm (lo.inter_threads);
  m->opt_level = onnx_opt_level_norm (lo.opt_level);
  snprintf (m->intra_threads_str, sizeof (m->intra_threads_str), "%d", m->intra_threads);
  snprintf (m->inter_threads_str, sizeof (m->inter_threads_str), "%d", m->inter_threads);
  snprintf (m->opt_level_str, sizeof (m->opt_level_str), "%d", m->opt_level);
  m->max_seq_len = lo.max_seq_len;
  snprintf (m->max_seq_len_str, sizeof (m->max_seq_len_str), "%d", lo.max_seq_len);
  m->max_texts = lo.max_texts;
  m->sub_batch_rows = lo.sub_batch_rows;
  m->tokens_per_batch = lo.tokens_per_batch;
  m->sort = lo.sort;
  snprintf (m->max_texts_str, sizeof (m->max_texts_str), "%d", lo.max_texts);
  snprintf (m->sub_batch_rows_str, sizeof (m->sub_batch_rows_str), "%d", lo.sub_batch_rows);
  snprintf (m->tokens_per_batch_str, sizeof (m->tokens_per_batch_str), "%d", lo.tokens_per_batch);

  if (cur_mode == ONNX_MODE_OUTPROC || m->gliner2_dir)
    {
      /* OUTPROC or GLiNER2: helper processes create their own ORT sessions.
	 We only need the model path and I/O names.

	 Because no session is created here, nothing else in this path would
	 notice an unreadable model or vocab: the load reports success, and the
	 first failure appears much later as a helper that dies on every
	 request ("Helper restarted; retry call"), naming neither the file nor
	 the reason.  Check readability up front so a bad path is reported as a
	 bad path, at the point the caller can still act on it.  */
      if (access (m->path, R_OK))
	{
	  int e = errno;
	  onnx_model_release (m);
	  onnx_fail (ONNX_SQLSTATE_RUNTIME, "ONNX",
	      "Model file is not readable: %s (%s). "
	      "Helpers resolve paths relative to the server's working directory, "
	      "so give an absolute path.",
	      path, strerror (e));
	}
      if (m->vocab_path && access (m->vocab_path, R_OK))
	{
	  int e = errno;
	  onnx_model_release (m);
	  onnx_fail (ONNX_SQLSTATE_RUNTIME, "ONNX",
	      "Vocab file is not readable: %s (%s). "
	      "Helpers resolve paths relative to the server's working directory, "
	      "so give an absolute path.",
	      m->vocab_path, strerror (e));
	}
      if (m->gliner2_vocab_path && access (m->gliner2_vocab_path, R_OK))
	{
	  int e = errno;
	  onnx_model_release (m);
	  onnx_fail (ONNX_SQLSTATE_RUNTIME, "ONNX",
	      "GLiNER2 vocab file is not readable: %s (%s).",
	      m->gliner2_vocab_path, strerror (e));
	}
      m->session = NULL;
      m->session_opts = NULL;
      m->output_dim = 0;
      onnx_model_register (m);
      return box_num (handle);
    }

  /* INPROC: create ORT session via persistent worker thread */
  OrtSessionOptions *opts = NULL;
  OrtSession *session = NULL;
  OrtStatus *err_st = NULL;
  const char *err_ctx = NULL;
  int success = 0;
  size_t elem_count = 0;
  char errbuf[128];

  err_st = g_ctx.api->CreateSessionOptions (&opts);
  if (err_st)
    {
      err_ctx = "CreateSessionOptions";
      goto cleanup;
    }
  err_st = onnx_session_apply_options (opts, &lo);
  if (err_st)
    {
      err_ctx = "SetSessionOptions";
      goto cleanup;
    }
  err_st = onnx_create_session_safe (g_ctx.env, path, opts, &session);
  if (err_st)
    {
      err_ctx = "CreateSession";
      goto cleanup;
    }
  m->session = session;
  m->session_opts = opts;
  err_st = onnx_detect_io (session, m);
  if (err_st)
    {
      err_ctx = "DetectIO";
      goto cleanup;
    }
  OrtStatus *shape_st = NULL;
  int shape_rc = onnx_get_output_elements (session, m->output_name, &elem_count, &shape_st, errbuf, sizeof (errbuf));
  if (shape_rc)
    {
      err_st = shape_st;
      err_ctx = errbuf[0] ? errbuf : "GetOutputElements";
      goto cleanup;
    }
  m->output_dim = elem_count;
  if (onnx_validate_output_size (elem_count, errbuf, sizeof (errbuf)))
    {
      err_ctx = errbuf;
      goto cleanup;
    }
  onnx_model_register (m);
  success = 1;

cleanup:
  if (!success)
    {
      if (session)
	{
	  g_ctx.api->ReleaseSession (session);
	  m->session = NULL;
	}
      if (opts)
	{
	  g_ctx.api->ReleaseSessionOptions (opts);
	  m->session_opts = NULL;
	}
      onnx_model_release (m);
      if (err_st)
	onnx_raise_status (err_st, err_ctx ? err_ctx : "onnx_load_model");
      if (err_ctx)
	onnx_fail (ONNX_SQLSTATE_RUNTIME, "ONNX", "%s", err_ctx);
      onnx_fail (ONNX_SQLSTATE_RUNTIME, "ONNX", "onnx_load_model failed");
    }
  return box_num (handle);
}

static caddr_t
bif_onnx_unload (caddr_t * qst, caddr_t * err, state_slot_t ** args)
{
  /* Closing a model out from under other sessions is administrative. */
  sec_check_dba ((query_instance_t *) qst, "onnx_unload_model");
  long handle = bif_long_arg (qst, args, 0, "onnx_unload_model");
  onnx_model_entry_t *m = onnx_model_ref (handle);
  if (!m)
    onnx_fail (ONNX_SQLSTATE_INPUT, "ONNX", "Unknown model handle %ld", handle);
  mutex_enter (m->mtx);
  long inflight = m->refcnt - 1;	/* subtract our own ref */
  mutex_leave (m->mtx);
  onnx_model_unref (m);
  if (inflight > 0)
    onnx_fail (ONNX_SQLSTATE_RUNTIME, "ONNX", "Model %ld has %ld in-flight calls", handle, inflight);
  onnx_model_remove (handle);
  return box_num (1);
}

static caddr_t
bif_onnx_info (caddr_t * qst, caddr_t * err, state_slot_t ** args)
{
  /* The reply carries filesystem paths, which is disclosure. */
  sec_check_dba ((query_instance_t *) qst, "onnx_model_info");
  caddr_t arg = bif_arg (qst, args, 0, "onnx_model_info");
  /* If NULL or omitted, return all models */
  if (arg == NULL || DV_DB_NULL == DV_TYPE_OF (arg))
    {
      mutex_enter (g_ctx.mtx);
      onnx_model_entry_t *m = g_ctx.models;
      if (!m)
	{
	  mutex_leave (g_ctx.mtx);
	  caddr_t res = dk_alloc_box (3, DV_STRING);
	  res[0] = '[';
	  res[1] = ']';
	  res[2] = 0;
	  return res;
	}
      /* Build JSON array of all models */
      size_t buf_cap = 4096;
      char *buf = (char *) dk_alloc (buf_cap);
      size_t buf_pos = 0;
      buf[buf_pos++] = '[';
      int first = 1;
      while (m)
	{
	  char item[512];
	  snprintf (item, sizeof (item),
		    "{\"handle\":%ld,\"path\":\"%s\",\"input\":\"%s\",\"input2\":\"%s\",\"input3\":\"%s\",\"output\":\"%s\",\"out_elems\":%lu}",
		    m->handle, m->path ? m->path : "", m->input_name ? m->input_name : "",
		    m->input_name2 ? m->input_name2 : "", m->input_name3 ? m->input_name3 : "",
		    m->output_name ? m->output_name : "", (unsigned long) m->output_dim);
	  size_t item_len = strlen (item);
	  size_t needed = buf_pos + (first ? 0 : 1) + item_len + 2;
	  if (needed > buf_cap)
	    {
	      size_t new_cap = buf_cap;
	      while (new_cap < needed)
		new_cap *= 2;
	      char *new_buf = (char *) dk_alloc (new_cap);
	      memcpy (new_buf, buf, buf_pos);
	      dk_free (buf, buf_cap);
	      buf = new_buf;
	      buf_cap = new_cap;
	    }
	  if (!first)
	    buf[buf_pos++] = ',';
	  memcpy (buf + buf_pos, item, item_len);
	  buf_pos += item_len;
	  first = 0;
	  m = m->next;
	}
      mutex_leave (g_ctx.mtx);
      buf[buf_pos++] = ']';
      buf[buf_pos] = 0;
      caddr_t res = dk_alloc_box (buf_pos + 1, DV_STRING);
      memcpy (res, buf, buf_pos + 1);
      dk_free (buf, buf_cap);
      return res;
    }

  /* Specific handle requested */
  long handle = bif_long_arg (qst, args, 0, "onnx_model_info");
  onnx_model_entry_t *m = onnx_model_ref (handle);
  if (!m)
    onnx_fail (ONNX_SQLSTATE_INPUT, "ONNX", "Unknown model handle %ld", handle);
  char buf[2048];
  int64 st[5];
  mutex_enter (m->mtx);
  st[0] = m->st_requests;
  st[1] = m->st_texts;
  st[2] = m->st_real_tokens;
  st[3] = m->st_padded_tokens;
  st[4] = m->st_sub_batches;
  mutex_leave (m->mtx);
  snprintf (buf, sizeof (buf),
	    "{\"handle\":%ld,\"path\":\"%s\",\"input\":\"%s\",\"input2\":\"%s\",\"input3\":\"%s\",\"output\":\"%s\",\"out_elems\":%lu,"
	    "\"max_texts\":%d,\"sub_batch_rows\":%d,\"tokens_per_batch\":%d,\"sort\":%d,"
	    "\"requests\":%lld,\"texts\":%lld,\"real_tokens\":%lld,\"padded_tokens\":%lld,\"sub_batches\":%lld}",
	    m->handle, m->path ? m->path : "", m->input_name ? m->input_name : "",
	    m->input_name2 ? m->input_name2 : "", m->input_name3 ? m->input_name3 : "",
	    m->output_name ? m->output_name : "", (unsigned long) m->output_dim,
	    m->max_texts, m->sub_batch_rows, m->tokens_per_batch, m->sort,
	    (long long) st[0], (long long) st[1], (long long) st[2], (long long) st[3], (long long) st[4]);
  onnx_model_unref (m);
  size_t len = strlen (buf);
  caddr_t res = dk_alloc_box (len + 1, DV_STRING);
  memcpy (res, buf, len + 1);
  return res;
}

static caddr_t
bif_onnx_config (caddr_t * qst, caddr_t * err, state_slot_t ** args)
{
  /* Server-global, and 'helper_path' names an executable the server will run,
     so this is the most privileged entry point the plugin has. */
  sec_check_dba ((query_instance_t *) qst, "onnx_config");
  caddr_t key_box = bif_string_arg (qst, args, 0, "onnx_config");
  const char *key = key_box;
  /* ONNX_CONFIG (key), with no value, reads a numeric setting back.  These
     are server-wide limits, so anything that raises one for its own work --
     a vector-index refresh sizing max_batch and helper_pool_size to its batch
     and concurrency -- has to know the current value, or it lowers whatever an
     operator had set above its own need. */
  if (BOX_ELEMENTS (args) < 2)
    {
      if (!strcmp (key, "log"))
	return box_num (g_ctx.caps.log_level);
      if (!strcmp (key, "max_input_bytes"))
	return box_num ((boxint) g_ctx.caps.max_input_bytes);
      if (!strcmp (key, "max_batch"))
	return box_num ((boxint) g_ctx.caps.max_batch);
      if (!strcmp (key, "max_output_floats"))
	return box_num ((boxint) g_ctx.caps.max_output_floats);
      if (!strcmp (key, "max_tensor_bytes"))
	return box_num ((boxint) g_ctx.caps.max_tensor_bytes);
      if (!strcmp (key, "helper_pool_size"))
	return box_num ((boxint) g_ctx.caps.helper_pool_size);
      if (!strcmp (key, "helper_timeout_ms"))
	return box_num (g_ctx.caps.helper_timeout_ms);
      if (!strcmp (key, "telemetry"))
	return box_num (g_ctx.caps.telemetry ? 1 : 0);
      onnx_fail (ONNX_SQLSTATE_INPUT, "ONNX",
	  "ONNX_CONFIG ('%s') cannot be read back; only numeric settings can", key);
    }
  if (!strcmp (key, "mode"))
    {
      const char *val = bif_string_arg (qst, args, 1, "onnx_config");
      mutex_enter (g_ctx.mtx);
      if (!strcmp (val, "inproc"))
	g_ctx.caps.mode = ONNX_MODE_INPROC;
      else if (!strcmp (val, "outproc"))
	g_ctx.caps.mode = ONNX_MODE_OUTPROC;
      else
	onnx_fail (ONNX_SQLSTATE_INPUT, "ONNX", "mode must be inproc|outproc");
      mutex_leave (g_ctx.mtx);
    }
  else if (!strcmp (key, "log"))
    {
      long lvl = bif_long_arg (qst, args, 1, "onnx_config");
      if (lvl < 0 || lvl > 3)
	onnx_fail (ONNX_SQLSTATE_INPUT, "ONNX", "log level must be 0-3");
      g_ctx.caps.log_level = (int) lvl;
    }
  else if (!strcmp (key, "model_root"))
    {
      /* Declared by the operator in [ONNX] ModelRoot / [Plugins] LoadPath and
	 pushed in by DB.DBA.ONNX_REGISTER_DEFAULT_MODELS.  DBA-only, like the
	 rest of ONNX_CONFIG. */
      const char *val = bif_string_arg (qst, args, 1, "onnx_config");
      size_t vlen = val ? strlen (val) : 0;
      size_t i;
      if (!vlen || '/' != val[0])
	onnx_fail (ONNX_SQLSTATE_INPUT, "ONNX", "model_root must be an absolute path");
      if (vlen >= sizeof (g_model_roots[0]))
	onnx_fail (ONNX_SQLSTATE_INPUT, "ONNX", "model_root is too long");
      /* Store it resolved, so onnx_path_is_permitted compares like with like. */
      char rroot[PATH_MAX];
      if (realpath (val, rroot))
	val = rroot;
      mutex_enter (g_ctx.mtx);
      for (i = 0; i < g_model_root_count; i++)
	if (!strcmp (g_model_roots[i], val))
	  break;
      if (i == g_model_root_count)
	{
	  if (g_model_root_count >= ONNX_MODEL_ROOT_MAX)
	    {
	      mutex_leave (g_ctx.mtx);
	      onnx_fail (ONNX_SQLSTATE_CONFIG, "ONNX", "too many model roots (max %d)", ONNX_MODEL_ROOT_MAX);
	    }
	  onnx_copy_trunc (g_model_roots[g_model_root_count], sizeof (g_model_roots[0]), val);
	  g_model_root_count++;
	}
      mutex_leave (g_ctx.mtx);
    }
  else if (!strcmp (key, "max_input_bytes"))
    g_ctx.caps.max_input_bytes = (size_t) bif_long_arg (qst, args, 1, "onnx_config");
  else if (!strcmp (key, "max_batch"))
    g_ctx.caps.max_batch = (size_t) bif_long_arg (qst, args, 1, "onnx_config");
  else if (!strcmp (key, "max_output_floats"))
    g_ctx.caps.max_output_floats = (size_t) bif_long_arg (qst, args, 1, "onnx_config");
  else if (!strcmp (key, "max_tensor_bytes"))
    g_ctx.caps.max_tensor_bytes = (size_t) bif_long_arg (qst, args, 1, "onnx_config");
  else if (!strcmp (key, "helper_path"))
    {
      caddr_t hp = bif_string_arg (qst, args, 1, "onnx_config");
      size_t len = box_length (hp) - 1;
      /* Reject an over-long path rather than silently truncating it -- a
	 truncated path would validate and store as a different file than the
	 caller named. */
      if (len >= sizeof (g_ctx.caps.helper_path))
	onnx_fail (ONNX_SQLSTATE_INPUT, "ONNX",
	    "helper_path is too long (%lu bytes; max %lu).",
	    (unsigned long) len, (unsigned long) (sizeof (g_ctx.caps.helper_path) - 1));
      /* Reject an unusable helper here rather than at spawn time.  The path is
	 handed to execl() in a forked child, whose failure is invisible to the
	 parent -- it surfaces only as a helper that dies on every request.  A
	 relative path is the common trap: the child inherits the server's
	 working directory, which is the database directory, not wherever the
	 build tree happens to be.  */
      {
	char probe[512];
	memcpy (probe, hp, len);
	probe[len] = 0;
	if (access (probe, X_OK))
	  {
	    int e = errno;
	    onnx_fail (ONNX_SQLSTATE_INPUT, "ONNX",
		"Helper is not executable: %s (%s). "
		"The helper is exec'd from a child process that inherits the server's "
		"working directory, so give an absolute path.",
		probe, strerror (e));
	  }
      }
      memcpy (g_ctx.caps.helper_path, hp, len);
      g_ctx.caps.helper_path[len] = 0;
    }
  else if (!strcmp (key, "helper_pool_size"))
    {
      long sz = bif_long_arg (qst, args, 1, "onnx_config");
      if (sz < 1 || sz > 32)
	onnx_fail (ONNX_SQLSTATE_INPUT, "ONNX", "helper_pool_size must be 1..32");
      g_ctx.caps.helper_pool_size = (size_t) sz;
    }
  else if (!strcmp (key, "helper_timeout_ms"))
    {
      long t = bif_long_arg (qst, args, 1, "onnx_config");
      /* 0 disables the timeout (block forever, old behaviour); otherwise a
	 wedged helper is escaped after this many ms and killed. */
      if (t < 0 || t > 3600000)
	onnx_fail (ONNX_SQLSTATE_INPUT, "ONNX", "helper_timeout_ms must be 0..3600000");
      g_ctx.caps.helper_timeout_ms = (int) t;
    }
  else if (!strcmp (key, "telemetry"))
    {
      long t = bif_long_arg (qst, args, 1, "onnx_config");
      g_ctx.caps.telemetry = (t != 0);
    }
  else
    onnx_fail (ONNX_SQLSTATE_INPUT, "ONNX", "Unknown config key %s", key);
  return box_num (1);
}

/* ---------- GLiNER2 out-of-process inference ---------- */

static caddr_t
onnx_outproc_gliner2 (onnx_model_entry_t *m, uint32_t sub_op,
		      const char *text, size_t text_len,
		      const char *schema_json, size_t schema_len,
		      const char *options_json, size_t options_len)
{
  if (onnx_helper_ensure_pool (m))
    onnx_fail (ONNX_SQLSTATE_RUNTIME, "ONNX", "Helper pool not initialized");
  onnx_helper_proc_t *hp = onnx_helper_acquire_or_respawn (m);
  if (!hp)
    onnx_fail (ONNX_SQLSTATE_RUNTIME, "ONNX", "No live helper available");

  /* Payload: [4B op=GLINER2] [4B sub_op] [4B text_len] [text] [4B schema_len] [schema] [4B opts_len] [opts] */
  size_t payload_cap = sizeof (uint32_t) * 4 + text_len + schema_len + options_len + 32;
  char *payload = (char *) dk_alloc (payload_cap);
  size_t off = 0;
  uint32_t op = ONNX_IPC_OP_GLINER2;
  memcpy (payload + off, &op, sizeof (uint32_t)); off += sizeof (uint32_t);
  memcpy (payload + off, &sub_op, sizeof (uint32_t)); off += sizeof (uint32_t);
  uint32_t tl = (uint32_t) text_len;
  memcpy (payload + off, &tl, sizeof (uint32_t)); off += sizeof (uint32_t);
  memcpy (payload + off, text, text_len); off += text_len;
  uint32_t sl = (uint32_t) schema_len;
  memcpy (payload + off, &sl, sizeof (uint32_t)); off += sizeof (uint32_t);
  memcpy (payload + off, schema_json, schema_len); off += schema_len;
  uint32_t ol = (uint32_t) options_len;
  memcpy (payload + off, &ol, sizeof (uint32_t)); off += sizeof (uint32_t);
  if (options_len > 0)
    {
      memcpy (payload + off, options_json, options_len);
      off += options_len;
    }

  onnx_ipc_hdr_t hdr;
  memset (&hdr, 0, sizeof (hdr));
  hdr.magic = ONNX_IPC_MAGIC;
  hdr.version = ONNX_IPC_VERSION;
  hdr.flags = 0;
  hdr.batch_count = 1;
  hdr.payload_len = (uint32_t) off;

  if (onnx_ipc_send_request (hp, &hdr, payload, off))
    {
      onnx_helper_note_fail (hp);
      onnx_helper_close (hp);
      if (onnx_helper_try_respawn (m, hp) || onnx_ipc_send_request (hp, &hdr, payload, off))
	{
	  dk_free (payload, payload_cap);
	  onnx_helper_release (m, hp);
	  onnx_fail (ONNX_SQLSTATE_RUNTIME, "ONNX", "Failed to send GLiNER2 request to helper");
	}
    }
  dk_free (payload, payload_cap);

  /* Receive response: helper returns JSON string in payload */
  size_t resp_cap = g_ctx.caps.max_input_bytes + 64;
  char *resp = (char *) dk_alloc (resp_cap);
  onnx_ipc_hdr_t rhdr;
  if (onnx_ipc_recv_response (hp, &rhdr, resp, resp_cap))
    {
      onnx_helper_note_fail (hp);
      onnx_helper_close (hp);
      dk_free (resp, resp_cap);
      onnx_helper_release (m, hp);
      onnx_fail (ONNX_SQLSTATE_RUNTIME, "ONNX", "Failed to read GLiNER2 response from helper");
    }
  if (rhdr.status != 0)
    {
      char emsg[512];
      onnx_helper_err_text (emsg, sizeof (emsg), &rhdr, resp, resp_cap);
      dk_free (resp, resp_cap);
      onnx_helper_release (m, hp);
      onnx_fail (ONNX_SQLSTATE_RUNTIME, "ONNX", "GLiNER2 helper error: %s", emsg);
    }
  onnx_helper_note_ok (hp);	/* a good response clears the respawn-backoff streak */
  onnx_helper_release (m, hp);

  /* Response payload is a JSON string */
  size_t json_len = rhdr.payload_len;
  caddr_t res = dk_alloc_box (json_len + 1, DV_STRING);
  memcpy (res, resp, json_len);
  res[json_len] = 0;
  dk_free (resp, resp_cap);
  return res;
}

/* ---------- GLiNER2 BIFs ---------- */

static caddr_t
bif_onnx_extract (caddr_t * qst, caddr_t * err, state_slot_t ** args)
{
  long handle = bif_long_arg (qst, args, 0, "ONNX_EXTRACT");
  caddr_t text_free = NULL, schema_free = NULL;
  caddr_t text = onnx_get_string_arg (qst, err, args, 1, "ONNX_EXTRACT", &text_free);
  caddr_t schema = onnx_get_string_arg (qst, err, args, 2, "ONNX_EXTRACT", &schema_free);
  caddr_t options = NULL;
  if (BOX_ELEMENTS (args) > 3 && args[3])
    {
      caddr_t opt_box = bif_arg (qst, args, 3, "ONNX_EXTRACT");
      dtp_t opt_dtp = DV_TYPE_OF (opt_box);
      if (opt_box && (DV_STRING == opt_dtp || DV_UNAME == opt_dtp))
	options = opt_box;
    }
  size_t text_len = box_length (text) - 1;
  size_t schema_len = box_length (schema) - 1;
  size_t options_len = options ? (box_length (options) - 1) : 0;
  onnx_validate_text ("ONNX_EXTRACT", text, text_len);

  onnx_model_entry_t *m = onnx_model_ref (handle);
  if (!m)
    {
      dk_free_box (text_free);
      dk_free_box (schema_free);
      onnx_fail (ONNX_SQLSTATE_INPUT, "ONNX", "Unknown model handle %ld", handle);
    }
  caddr_t res = NULL;
  ONNX_WITH_MODEL_REF (m, res = onnx_outproc_gliner2 (m, 1, text, text_len, schema, schema_len, options, options_len));
  onnx_model_unref (m);
  dk_free_box (text_free);
  dk_free_box (schema_free);
  return res;
}

static caddr_t
bif_onnx_classify (caddr_t * qst, caddr_t * err, state_slot_t ** args)
{
  long handle = bif_long_arg (qst, args, 0, "ONNX_CLASSIFY");
  caddr_t text_free = NULL, schema_free = NULL;
  caddr_t text = onnx_get_string_arg (qst, err, args, 1, "ONNX_CLASSIFY", &text_free);
  caddr_t schema = onnx_get_string_arg (qst, err, args, 2, "ONNX_CLASSIFY", &schema_free);
  caddr_t options = NULL;
  if (BOX_ELEMENTS (args) > 3 && args[3])
    {
      caddr_t opt_box = bif_arg (qst, args, 3, "ONNX_CLASSIFY");
      dtp_t opt_dtp = DV_TYPE_OF (opt_box);
      if (opt_box && (DV_STRING == opt_dtp || DV_UNAME == opt_dtp))
	options = opt_box;
    }
  size_t text_len = box_length (text) - 1;
  size_t schema_len = box_length (schema) - 1;
  size_t options_len = options ? (box_length (options) - 1) : 0;
  onnx_validate_text ("ONNX_CLASSIFY", text, text_len);

  onnx_model_entry_t *m = onnx_model_ref (handle);
  if (!m)
    {
      dk_free_box (text_free);
      dk_free_box (schema_free);
      onnx_fail (ONNX_SQLSTATE_INPUT, "ONNX", "Unknown model handle %ld", handle);
    }
  caddr_t res = NULL;
  ONNX_WITH_MODEL_REF (m, res = onnx_outproc_gliner2 (m, 2, text, text_len, schema, schema_len, options, options_len));
  onnx_model_unref (m);
  dk_free_box (text_free);
  dk_free_box (schema_free);
  return res;
}

static caddr_t
bif_onnx_extract_batch (caddr_t * qst, caddr_t * err, state_slot_t ** args)
{
  long handle = bif_long_arg (qst, args, 0, "ONNX_EXTRACT_BATCH");
  caddr_t arr = bif_array_arg (qst, args, 1, "ONNX_EXTRACT_BATCH");
  caddr_t schema_free = NULL;
  caddr_t schema = onnx_get_string_arg (qst, err, args, 2, "ONNX_EXTRACT_BATCH", &schema_free);
  caddr_t options = NULL;
  if (BOX_ELEMENTS (args) > 3 && args[3])
    {
      caddr_t opt_box = bif_arg (qst, args, 3, "ONNX_EXTRACT_BATCH");
      dtp_t opt_dtp = DV_TYPE_OF (opt_box);
      if (opt_box && (DV_STRING == opt_dtp || DV_UNAME == opt_dtp))
	options = opt_box;
    }
  if (DV_ARRAY_OF_POINTER != DV_TYPE_OF (arr))
    {
      dk_free_box (schema_free);
      onnx_fail (ONNX_SQLSTATE_INPUT, "ONNX", "Second argument must be array of strings");
    }
  size_t count = BOX_ELEMENTS (arr);
  onnx_validate_batch ("ONNX_EXTRACT_BATCH", count);
  caddr_t *elts = (caddr_t *) arr;
  for (size_t i = 0; i < count; i++)
    {
      dtp_t edtp = DV_TYPE_OF (elts[i]);
      if (DV_STRING != edtp && DV_WIDE != edtp && DV_LONG_WIDE != edtp && DV_UNAME != edtp)
	{
	  dk_free_box (schema_free);
	  onnx_fail (ONNX_SQLSTATE_INPUT, "ONNX", "Batch item %lu is not a string", (unsigned long) i);
	}
    }
  size_t schema_len = box_length (schema) - 1;
  size_t options_len = options ? (box_length (options) - 1) : 0;

  onnx_model_entry_t *m = onnx_model_ref (handle);
  if (!m)
    {
      dk_free_box (schema_free);
      onnx_fail (ONNX_SQLSTATE_INPUT, "ONNX", "Unknown model handle %ld", handle);
    }

  /* Accumulate JSON results: build "[result0,result1,...]" */
  size_t buf_cap = 4096;
  char *buf = (char *) dk_alloc (buf_cap);
  size_t buf_pos = 0;
  buf[buf_pos++] = '[';

  for (size_t i = 0; i < count; i++)
    {
      caddr_t elt_free = NULL;
      caddr_t elt_text = elts[i];
      dtp_t edtp = DV_TYPE_OF (elt_text);
      if (DV_WIDE == edtp || DV_LONG_WIDE == edtp)
	{
	  size_t wchar_count = (box_length (elt_text) / sizeof (wchar_t)) - 1;
	  elt_text = onnx_wide_to_utf8 ((const wchar_t *) elt_text, wchar_count);
	  elt_free = elt_text;
	}
      size_t text_len = box_length (elt_text) - 1;
      onnx_validate_text ("ONNX_EXTRACT_BATCH", elt_text, text_len);
      caddr_t one = NULL;
      ONNX_WITH_MODEL_REF (m, one = onnx_outproc_gliner2 (m, 1, elt_text, text_len, schema, schema_len, options, options_len));
      dk_free_box (elt_free);
      size_t one_len = box_length (one) - 1;

      /* Grow buffer if needed: current + comma + result + closing bracket + null */
      size_t needed = buf_pos + 1 + one_len + 2;
      if (needed > buf_cap)
	{
	  size_t new_cap = buf_cap;
	  while (new_cap < needed)
	    new_cap *= 2;
	  char *new_buf = (char *) dk_alloc (new_cap);
	  memcpy (new_buf, buf, buf_pos);
	  dk_free (buf, buf_cap);
	  buf = new_buf;
	  buf_cap = new_cap;
	}

      if (i > 0)
	buf[buf_pos++] = ',';
      memcpy (buf + buf_pos, one, one_len);
      buf_pos += one_len;
      dk_free_box (one);
    }

  buf[buf_pos++] = ']';
  buf[buf_pos] = 0;

  onnx_model_unref (m);
  dk_free_box (schema_free);

  caddr_t res = dk_alloc_box (buf_pos + 1, DV_STRING);
  memcpy (res, buf, buf_pos + 1);
  dk_free (buf, buf_cap);
  return res;
}

static caddr_t
bif_onnx_extract_json (caddr_t * qst, caddr_t * err, state_slot_t ** args)
{
  long handle = bif_long_arg (qst, args, 0, "ONNX_EXTRACT_JSON");
  caddr_t text_free = NULL, schema_free = NULL;
  caddr_t text = onnx_get_string_arg (qst, err, args, 1, "ONNX_EXTRACT_JSON", &text_free);
  caddr_t schema = onnx_get_string_arg (qst, err, args, 2, "ONNX_EXTRACT_JSON", &schema_free);
  caddr_t options = NULL;
  if (BOX_ELEMENTS (args) > 3 && args[3])
    {
      caddr_t opt_box = bif_arg (qst, args, 3, "ONNX_EXTRACT_JSON");
      dtp_t opt_dtp = DV_TYPE_OF (opt_box);
      if (opt_box && (DV_STRING == opt_dtp || DV_UNAME == opt_dtp))
	options = opt_box;
    }
  size_t text_len = box_length (text) - 1;
  size_t schema_len = box_length (schema) - 1;
  size_t options_len = options ? (box_length (options) - 1) : 0;
  onnx_validate_text ("ONNX_EXTRACT_JSON", text, text_len);

  onnx_model_entry_t *m = onnx_model_ref (handle);
  if (!m)
    {
      dk_free_box (text_free);
      dk_free_box (schema_free);
      onnx_fail (ONNX_SQLSTATE_INPUT, "ONNX", "Unknown model handle %ld", handle);
    }
  caddr_t res = NULL;
  ONNX_WITH_MODEL_REF (m, res = onnx_outproc_gliner2 (m, 3, text, text_len, schema, schema_len, options, options_len));
  onnx_model_unref (m);
  dk_free_box (text_free);
  dk_free_box (schema_free);
  return res;
}

static caddr_t
bif_onnx_extract_relations (caddr_t * qst, caddr_t * err, state_slot_t ** args)
{
  long handle = bif_long_arg (qst, args, 0, "ONNX_EXTRACT_RELATIONS");
  caddr_t text_free = NULL, schema_free = NULL;
  caddr_t text = onnx_get_string_arg (qst, err, args, 1, "ONNX_EXTRACT_RELATIONS", &text_free);
  caddr_t schema = onnx_get_string_arg (qst, err, args, 2, "ONNX_EXTRACT_RELATIONS", &schema_free);
  caddr_t options = NULL;
  if (BOX_ELEMENTS (args) > 3 && args[3])
    {
      caddr_t opt_box = bif_arg (qst, args, 3, "ONNX_EXTRACT_RELATIONS");
      dtp_t opt_dtp = DV_TYPE_OF (opt_box);
      if (opt_box && (DV_STRING == opt_dtp || DV_UNAME == opt_dtp))
	options = opt_box;
    }
  size_t text_len = box_length (text) - 1;
  size_t schema_len = box_length (schema) - 1;
  size_t options_len = options ? (box_length (options) - 1) : 0;
  onnx_validate_text ("ONNX_EXTRACT_RELATIONS", text, text_len);

  onnx_model_entry_t *m = onnx_model_ref (handle);
  if (!m)
    {
      dk_free_box (text_free);
      dk_free_box (schema_free);
      onnx_fail (ONNX_SQLSTATE_INPUT, "ONNX", "Unknown model handle %ld", handle);
    }
  caddr_t res = NULL;
  ONNX_WITH_MODEL_REF (m, res = onnx_outproc_gliner2 (m, 4, text, text_len, schema, schema_len, options, options_len));
  onnx_model_unref (m);
  dk_free_box (text_free);
  dk_free_box (schema_free);
  return res;
}

static caddr_t
bif_onnx_extract_combined (caddr_t * qst, caddr_t * err, state_slot_t ** args)
{
  long handle = bif_long_arg (qst, args, 0, "ONNX_EXTRACT_COMBINED");
  caddr_t text_free = NULL, schema_free = NULL;
  caddr_t text = onnx_get_string_arg (qst, err, args, 1, "ONNX_EXTRACT_COMBINED", &text_free);
  caddr_t schema = onnx_get_string_arg (qst, err, args, 2, "ONNX_EXTRACT_COMBINED", &schema_free);
  caddr_t options = NULL;
  if (BOX_ELEMENTS (args) > 3 && args[3])
    {
      caddr_t opt_box = bif_arg (qst, args, 3, "ONNX_EXTRACT_COMBINED");
      dtp_t opt_dtp = DV_TYPE_OF (opt_box);
      if (opt_box && (DV_STRING == opt_dtp || DV_UNAME == opt_dtp))
	options = opt_box;
    }
  size_t text_len = box_length (text) - 1;
  size_t schema_len = box_length (schema) - 1;
  size_t options_len = options ? (box_length (options) - 1) : 0;
  onnx_validate_text ("ONNX_EXTRACT_COMBINED", text, text_len);

  onnx_model_entry_t *m = onnx_model_ref (handle);
  if (!m)
    {
      dk_free_box (text_free);
      dk_free_box (schema_free);
      onnx_fail (ONNX_SQLSTATE_INPUT, "ONNX", "Unknown model handle %ld", handle);
    }
  caddr_t res = NULL;
  ONNX_WITH_MODEL_REF (m, res = onnx_outproc_gliner2 (m, 5, text, text_len, schema, schema_len, options, options_len));
  onnx_model_unref (m);
  dk_free_box (text_free);
  dk_free_box (schema_free);
  return res;
}

/* ---------- Plugin lifecycle ---------- */

static void
vonnx_disconnect (void *appdata)
{
  onnx_worker_stop ();
  mutex_enter (g_ctx.mtx);
  onnx_model_entry_t *cur = g_ctx.models;
  while (cur)
    {
      onnx_model_entry_t *next = cur->next;
      onnx_model_release (cur);
      cur = next;
    }
  g_ctx.models = NULL;
  if (g_ctx.env)
    g_ctx.api->ReleaseEnv (g_ctx.env);
  g_ctx.env = NULL;
  if (g_ctx.mtx)
    {
      mutex_leave (g_ctx.mtx);
      mutex_free (g_ctx.mtx);
      g_ctx.mtx = NULL;
    }
}

static void
vonnx_connect (void *appdata)
{
  if (!g_ctx.mtx)
    g_ctx.mtx = mutex_allocate ();
  onnx_init_api ();
  onnx_ensure_env ();
  onnx_worker_start ();
#ifndef _WIN32
  atexit (onnx_atexit_kill_helpers);	/* no orphaned helpers on a normal exit */
#endif
  bif_define_typed ("ONNX_LOAD_MODEL", bif_onnx_load, bt_integer);
  bif_define_typed ("ONNX_UNLOAD_MODEL", bif_onnx_unload, bt_integer);
  bif_define_typed ("ONNX_MODEL_INFO", bif_onnx_info, bt_varchar);
  bif_define_typed ("ONNX_EMBED_TEXT", bif_onnx_embed, bt_any);
  bif_define_typed ("ONNX_EMBED_BATCH", bif_onnx_embed_batch, bt_any);
  bif_define_typed ("ONNX_RUN_F32", bif_onnx_run_f32, bt_any);
  bif_define_typed ("ONNX_RUN_TOKENS", bif_onnx_run_tokens, bt_any);
  bif_define_typed ("ONNX_RUN", bif_onnx_run, bt_any);
  bif_define_typed ("ONNX_CONFIG", bif_onnx_config, bt_integer);
  /* GLiNER2 BIFs */
  bif_define_typed ("ONNX_EXTRACT", bif_onnx_extract, bt_varchar);
  bif_define_typed ("ONNX_EXTRACT_BATCH", bif_onnx_extract_batch, bt_varchar);
  bif_define_typed ("ONNX_CLASSIFY", bif_onnx_classify, bt_varchar);
  bif_define_typed ("ONNX_EXTRACT_JSON", bif_onnx_extract_json, bt_varchar);
  bif_define_typed ("ONNX_EXTRACT_RELATIONS", bif_onnx_extract_relations, bt_varchar);
  bif_define_typed ("ONNX_EXTRACT_COMBINED", bif_onnx_extract_combined, bt_varchar);
}

static unit_version_t vonnx_version = {
  PLAIN_PLUGIN_TYPE,
  DBMS_SRV_GEN_MAJOR DBMS_SRV_GEN_MINOR,
  "OpenLink Software",
  "ONNX runtime plugin",
  0,
  0,
  vonnx_connect,
  vonnx_disconnect,
  0,
  0,
  &_gate
};

unit_version_t *CALLBACK
vonnx_check (unit_version_t * in, void *appdata)
{
  return &vonnx_version;
}
