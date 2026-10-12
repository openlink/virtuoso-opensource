/* Inject deterministic interleavings into the cache functions to verify reference ownership. */
#include <assert.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

typedef char *caddr_t;
typedef const char *ccaddr_t;
typedef int32_t int32;
typedef unsigned int id_hashed_key_t;
typedef struct { int ht_count; } id_hash_t;
typedef struct { int unused; } pcre;
typedef struct { int unused; } pcre_extra;

static void *slot, *replacement;
static int locked, swap_on_unlock, compile_race;
static void test_lock (id_hash_t *ht);
static void test_unlock (id_hash_t *ht);
static void *id_hash_get (id_hash_t *ht, caddr_t key);
static void id_hash_set (id_hash_t *ht, caddr_t key, caddr_t value);
static int id_hash_remove_rnd (id_hash_t *ht, int32 rnd, caddr_t key, caddr_t value);
static pcre *pcre_compile (const char *pattern, int options, const char **error, int *offset, int unused);
static pcre_extra *pcre_study (pcre *code, int options, const char **error);
static caddr_t srv_make_new_error (const char *state, const char *code, const char *format, ...);

#define HT_WRLOCK(ht) test_lock (ht)
#define HT_UNLOCK(ht) test_unlock (ht)
#define GPF_T1(message) do { fprintf (stderr, "%s\n", message); abort (); } while (0)
#define ID_HASHED_KEY_MASK 0x7fffffff
#define NTS_BUFFER_HASH(hash, string) ((hash) = (unsigned char)(string)[0])
#define sqlbif_rnd(seed) 0
#define dk_free_box(box) free (box)
#define dk_alloc(size) malloc (size)
#define dk_free(ptr, size) free (ptr)
#define box_dv_short_string(string) strdup (string)
#define pcre_malloc(size) malloc (size)
#define pcre_free(ptr) free (ptr)
#define dbg_printf(args) ((void)0)
#define PCRE_UTF8 0x00000800

/* The runner extracts this file from bif_regexp.c to avoid duplicating the implementation. */
#include REGEXP_CACHE_SOURCE

/* Model the mutex and verify the locking protocol for hash slot access. */
static void test_lock (id_hash_t *ht)
{
  (void)ht;
  assert (!locked);
  locked = 1;
}

/* Model eviction of the bucket head and promotion of an overflow entry after unlock. */
static void test_unlock (id_hash_t *ht)
{
  (void)ht;
  assert (locked);
  locked = 0;
  if (swap_on_unlock)
    {
      compiled_regexp_t *evicted = slot;
      swap_on_unlock = 0;
      evicted->refctr--;
      slot = replacement;
    }
}

/* Return a slot address that eviction can repopulate with another object. */
static void *id_hash_get (id_hash_t *ht, caddr_t key)
{
  (void)ht;
  (void)key;
  assert (locked);
  return slot ? &slot : NULL;
}

/* Provide the insertion operation required by the extracted implementation. */
static void id_hash_set (id_hash_t *ht, caddr_t key, caddr_t value)
{
  (void)key;
  assert (locked);
  memcpy (&slot, value, sizeof (slot));
  ht->ht_count++;
}

/* Exercise the shrink assertion when a wrong release leaves an unreferenced cached object. */
static int id_hash_remove_rnd (id_hash_t *ht, int32 rnd, caddr_t key, caddr_t value)
{
  regexp_key_t removed = {strdup ("replacement"), 0};
  (void)rnd;
  memcpy (key, &removed, sizeof (removed));
  memcpy (value, &slot, sizeof (slot));
  ht->ht_count--;
  return 1;
}

/* Model another thread inserting the same pattern during compilation outside the lock. */
static pcre *pcre_compile (const char *pattern, int options, const char **error, int *offset, int unused)
{
  (void)pattern; (void)options; (void)error; (void)offset; (void)unused;
  assert (!locked);
  if (compile_race)
    {
      slot = calloc (1, sizeof (compiled_regexp_t));
      ((compiled_regexp_t *)slot)->refctr = 1;
      swap_on_unlock = 1;
    }
  return calloc (1, sizeof (pcre));
}

/* Allocate study data independently of the modeled ownership interleaving. */
static pcre_extra *pcre_study (pcre *code, int options, const char **error)
{
  (void)code; (void)error;
  /* Compile-time UTF-8 flags must not be passed to the study API. */
  assert (options == 0);
  return NULL;
}

/* Valid test patterns must not produce compilation errors. */
static caddr_t srv_make_new_error (const char *state, const char *code, const char *format, ...)
{
  (void)state; (void)code; (void)format;
  abort ();
}

/* Cover immediate cache hits and hits following a concurrent duplicate compilation. */
int main (int argc, char **argv)
{
  id_hash_t cache = {1};
  caddr_t error = NULL;
  compiled_regexp_t *result;
  assert (argc == 2);
  compile_race = !strcmp (argv[1], "double-compile");
  replacement = calloc (1, sizeof (compiled_regexp_t));
  ((compiled_regexp_t *)replacement)->refctr = 1;
  if (!compile_race)
    {
      slot = calloc (1, sizeof (compiled_regexp_t));
      ((compiled_regexp_t *)slot)->refctr = 1;
      swap_on_unlock = 1;
    }
  result = get_compiled_regexp (&cache, "original", PCRE_UTF8, &error);
  assert (!error);
  if (result == replacement)
    {
      /* Retain storage to observe incorrect releases without introducing a test-side UAF. */
      result->refctr--;
      pcre_max_cache_sz = 0;
      HT_WRLOCK (&cache);
      pcre_cache_check (&cache);
      abort ();
    }
  assert (result->refctr == 1);
  assert (((compiled_regexp_t *)replacement)->refctr == 1);
  release_compiled_regexp (&cache, result);
  release_compiled_regexp (&cache, replacement);
  printf ("PASS: %s preserves ownership across cache eviction\n", argv[1]);
  return 0;
}
