/*
 *  fuzzy_algorithms.c
 *
 *  $Id$
 *
 *  Fuzzy string similarity algorithms for Virtuoso.
 *
 *  Pure C implementations of:
 *    - Levenshtein edit distance and normalized similarity
 *    - Jaro and Jaro-Winkler similarity
 *    - N-gram cosine similarity
 *
 *  All algorithms operate on Unicode code points.  UTF-8 input is
 *  decoded to uint32_t code-point arrays before comparison.  An
 *  ASCII fast path skips decoding when all bytes are < 0x80, using
 *  the original byte-level implementations directly.
 *
 *  Uses Virtuoso's dk_alloc/dk_free memory allocator since the file is
 *  built into the core engine.  Callable from BIF wrappers (sqlbif_fuzzy.c)
 *  and text.c.
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

#include "fuzzy_algorithms.h"

#include <string.h>
#include <math.h>
#include "Dk.h"		/* dk_alloc / dk_free */

/* ============================================================
 * UTF-8 decoder
 * ============================================================ */

#define FUZZY_MAX_CODEPOINTS 4096
#define UNICODE_REPLACEMENT  0xFFFD

/* Check if a string contains only ASCII (all bytes < 0x80). */
static int
is_ascii (const char *s, int len)
{
  int i;
  for (i = 0; i < len; i++)
    if ((unsigned char) s[i] >= 0x80)
      return 0;
  return 1;
}

/* Decode a UTF-8 string to an array of Unicode code points.
 * Returns the number of code points decoded, or -1 on error
 * (output array too small).  Invalid byte sequences are replaced
 * with U+FFFD. */
static int
utf8_to_codepoints (const char *utf8, int byte_len, uint32_t *codepoints, int max_len)
{
  int cp_count = 0;
  int i = 0;

  if (!utf8 || byte_len <= 0)
    return 0;

  while (i < byte_len)
    {
      unsigned char c = (unsigned char) utf8[i];
      uint32_t cp;

      if (cp_count >= max_len && max_len > 0)
        return -1;

      if (c < 0x80)
        {
          cp = c;
          i++;
        }
      else if ((c & 0xE0) == 0xC0)
        {
          if (i + 1 >= byte_len || ((unsigned char) utf8[i+1] & 0xC0) != 0x80)
            { cp = UNICODE_REPLACEMENT; i++; }
          else
            {
              cp = ((uint32_t)(c & 0x1F) << 6) | ((unsigned char) utf8[i+1] & 0x3F);
              if (cp < 0x80) cp = UNICODE_REPLACEMENT;
              i += 2;
            }
        }
      else if ((c & 0xF0) == 0xE0)
        {
          if (i + 2 >= byte_len || ((unsigned char) utf8[i+1] & 0xC0) != 0x80
              || ((unsigned char) utf8[i+2] & 0xC0) != 0x80)
            { cp = UNICODE_REPLACEMENT; i++; }
          else
            {
              cp = ((uint32_t)(c & 0x0F) << 12)
                 | ((uint32_t)((unsigned char) utf8[i+1] & 0x3F) << 6)
                 | ((unsigned char) utf8[i+2] & 0x3F);
              if (cp < 0x800) cp = UNICODE_REPLACEMENT;
              i += 3;
            }
        }
      else if ((c & 0xF8) == 0xF0)
        {
          if (i + 3 >= byte_len || ((unsigned char) utf8[i+1] & 0xC0) != 0x80
              || ((unsigned char) utf8[i+2] & 0xC0) != 0x80
              || ((unsigned char) utf8[i+3] & 0xC0) != 0x80)
            { cp = UNICODE_REPLACEMENT; i++; }
          else
            {
              cp = ((uint32_t)(c & 0x07) << 18)
                 | ((uint32_t)((unsigned char) utf8[i+1] & 0x3F) << 12)
                 | ((uint32_t)((unsigned char) utf8[i+2] & 0x3F) << 6)
                 | ((unsigned char) utf8[i+3] & 0x3F);
              if (cp < 0x10000 || cp > 0x10FFFF) cp = UNICODE_REPLACEMENT;
              i += 4;
            }
        }
      else
        {
          cp = UNICODE_REPLACEMENT;
          i++;
        }

      if (max_len > 0)
        codepoints[cp_count] = cp;
      cp_count++;
    }

  return cp_count;
}

/* ============================================================
 * Byte-level (ASCII) implementations — fast path
 * ============================================================ */

static int
levenshtein_distance_bytes (const char *s1, int len1, const char *s2, int len2)
{
  int i, j;
  int *prev, *curr, *tmp;
  int cost, result;

  if (len1 == 0) return len2;
  if (len2 == 0) return len1;

  if (len1 > len2)
    {
      const char *ts = s1; s1 = s2; s2 = ts;
      int tl = len1; len1 = len2; len2 = tl;
    }

  prev = (int *) dk_alloc (sizeof (int) * (len1 + 1));
  curr = (int *) dk_alloc (sizeof (int) * (len1 + 1));
  if (!prev || !curr)
    {
      if (prev) dk_free (prev, sizeof (int) * (len1 + 1));
      if (curr) dk_free (curr, sizeof (int) * (len1 + 1));
      return len2;
    }

  for (i = 0; i <= len1; i++)
    prev[i] = i;

  for (j = 1; j <= len2; j++)
    {
      curr[0] = j;
      for (i = 1; i <= len1; i++)
        {
          cost = (s1[i - 1] == s2[j - 1]) ? 0 : 1;
          {
            int del = prev[i] + 1;
            int ins = curr[i - 1] + 1;
            int sub = prev[i - 1] + cost;
            int min = del;
            if (ins < min) min = ins;
            if (sub < min) min = sub;
            curr[i] = min;
          }
        }
      tmp = prev; prev = curr; curr = tmp;
    }

  result = prev[len1];
  dk_free (prev, sizeof (int) * (len1 + 1));
  dk_free (curr, sizeof (int) * (len1 + 1));
  return result;
}

static double
jaro_similarity_bytes (const char *s1, int len1, const char *s2, int len2)
{
  int match_distance, matches, transpositions;
  int i, j, start, end;
  char *s1_matches, *s2_matches;
  double result;

  if (len1 == 0 && len2 == 0) return 1.0;
  if (len1 == 0 || len2 == 0) return 0.0;
  if (len1 == len2 && memcmp (s1, s2, len1) == 0) return 1.0;

  match_distance = (len1 > len2 ? len1 : len2) / 2 - 1;
  if (match_distance < 0) match_distance = 0;

  s1_matches = (char *) dk_alloc (len1);
  s2_matches = (char *) dk_alloc (len2);
  if (!s1_matches || !s2_matches)
    {
      if (s1_matches) dk_free (s1_matches, len1);
      if (s2_matches) dk_free (s2_matches, len2);
      return 0.0;
    }
  memset (s1_matches, 0, len1);
  memset (s2_matches, 0, len2);

  matches = 0;
  for (i = 0; i < len1; i++)
    {
      start = i - match_distance; if (start < 0) start = 0;
      end = i + match_distance + 1; if (end > len2) end = len2;
      for (j = start; j < end; j++)
        {
          if (s2_matches[j]) continue;
          if (s1[i] != s2[j]) continue;
          s1_matches[i] = 1; s2_matches[j] = 1; matches++; break;
        }
    }

  if (matches == 0) { dk_free (s1_matches, len1); dk_free (s2_matches, len2); return 0.0; }

  transpositions = 0; j = 0;
  for (i = 0; i < len1; i++)
    {
      if (!s1_matches[i]) continue;
      while (!s2_matches[j]) j++;
      if (s1[i] != s2[j]) transpositions++;
      j++;
    }
  transpositions /= 2;

  { double m = (double) matches;
    result = (m / len1 + m / len2 + (m - transpositions) / m) / 3.0; }

  dk_free (s1_matches, len1); dk_free (s2_matches, len2);
  return result;
}

static double
jaro_winkler_similarity_bytes (const char *s1, int len1, const char *s2, int len2)
{
  double jaro;
  int prefix_len, i;
  const double winkler_p = 0.1;
  const int max_prefix = 4;

  jaro = jaro_similarity_bytes (s1, len1, s2, len2);
  if (jaro == 0.0) return 0.0;

  prefix_len = 0;
  for (i = 0; i < max_prefix && i < len1 && i < len2; i++)
    { if (s1[i] != s2[i]) break; prefix_len++; }

  return jaro + prefix_len * winkler_p * (1.0 - jaro);
}

/* Byte-level n-gram map */
typedef struct { char *ngram; int count; } byte_ngram_entry_t;
typedef struct { byte_ngram_entry_t *entries; int count; int capacity; int n; } byte_ngram_map_t;

static void
byte_ngram_map_init (byte_ngram_map_t *map, int n)
{
  map->n = n; map->count = 0; map->capacity = 16;
  map->entries = (byte_ngram_entry_t *) dk_alloc (sizeof (byte_ngram_entry_t) * map->capacity);
}

static void
byte_ngram_map_free (byte_ngram_map_t *map)
{
  int i;
  for (i = 0; i < map->count; i++) dk_free (map->entries[i].ngram, map->n + 1);
  dk_free (map->entries, sizeof (byte_ngram_entry_t) * map->capacity);
  map->entries = NULL; map->count = 0;
}

static int
byte_ngram_map_find (byte_ngram_map_t *map, const char *ngram)
{
  int lo = 0, hi = map->count - 1;
  while (lo <= hi)
    {
      int mid = lo + (hi - lo) / 2;
      int cmp = memcmp (map->entries[mid].ngram, ngram, map->n);
      if (cmp == 0) return mid;
      if (cmp < 0) lo = mid + 1; else hi = mid - 1;
    }
  return -(lo + 1);
}

static void
byte_ngram_map_add (byte_ngram_map_t *map, const char *ngram)
{
  int idx;
  if (map->count > 0)
    {
      idx = byte_ngram_map_find (map, ngram);
      if (idx >= 0) { map->entries[idx].count++; return; }
      idx = -(idx + 1);
    }
  else idx = 0;

  if (map->count >= map->capacity)
    {
      int new_cap = map->capacity * 2;
      byte_ngram_entry_t *ne = (byte_ngram_entry_t *) dk_alloc (
          sizeof (byte_ngram_entry_t) * new_cap);
      if (!ne) return;
      memcpy (ne, map->entries, sizeof (byte_ngram_entry_t) * map->count);
      dk_free (map->entries, sizeof (byte_ngram_entry_t) * map->capacity);
      map->entries = ne; map->capacity = new_cap;
    }

  if (idx < map->count)
    memmove (&map->entries[idx + 1], &map->entries[idx],
             sizeof (byte_ngram_entry_t) * (map->count - idx));

  map->entries[idx].ngram = (char *) dk_alloc (map->n + 1);
  if (map->entries[idx].ngram)
    { memcpy (map->entries[idx].ngram, ngram, map->n); map->entries[idx].ngram[map->n] = '\0'; }
  map->entries[idx].count = 1;
  map->count++;
}

static void
byte_ngram_map_build (byte_ngram_map_t *map, const char *s, int len)
{
  int i; char ngram_buf[8]; int n = map->n;
  if (len == 0) return;
  if (len < n)
    {
      int j; char *padded = (char *) dk_alloc (n + 1);
      int pad_left = (n - len) / 2, pad_right = n - len - pad_left;
      if (!padded) return;
      memset (padded, '$', n);
      memcpy (padded + pad_left, s, len);
      padded[n] = '\0';
      byte_ngram_map_add (map, padded);
      dk_free (padded, n + 1);
      return;
    }
  for (i = 0; i <= len - n; i++)
    { memcpy (ngram_buf, s + i, n); ngram_buf[n] = '\0'; byte_ngram_map_add (map, ngram_buf); }
  if (len >= n)
    {
      ngram_buf[0] = '$'; memcpy (ngram_buf + 1, s, n - 1); ngram_buf[n] = '\0';
      byte_ngram_map_add (map, ngram_buf);
      memcpy (ngram_buf, s + len - (n - 1), n - 1); ngram_buf[n - 1] = '$'; ngram_buf[n] = '\0';
      byte_ngram_map_add (map, ngram_buf);
    }
}

static double
byte_ngram_cosine (const char *s1, int len1, const char *s2, int len2, int n)
{
  byte_ngram_map_t map1, map2;
  double dot, mag1, mag2, result;
  int i1 = 0, i2 = 0;

  if (n <= 0) n = FUZZY_DEFAULT_N;
  if (n > 7) n = 7;
  if (len1 == 0 && len2 == 0) return 1.0;
  if (len1 == 0 || len2 == 0) return 0.0;

  byte_ngram_map_init (&map1, n);
  byte_ngram_map_init (&map2, n);
  byte_ngram_map_build (&map1, s1, len1);
  byte_ngram_map_build (&map2, s2, len2);

  if (map1.count == 0 || map2.count == 0)
    { byte_ngram_map_free (&map1); byte_ngram_map_free (&map2); return 0.0; }

  dot = 0.0;
  while (i1 < map1.count && i2 < map2.count)
    {
      int cmp = memcmp (map1.entries[i1].ngram, map2.entries[i2].ngram, n);
      if (cmp == 0)
        { dot += (double)(map1.entries[i1].count * map2.entries[i2].count); i1++; i2++; }
      else if (cmp < 0) i1++; else i2++;
    }

  mag1 = 0.0; for (i1 = 0; i1 < map1.count; i1++) mag1 += (double)(map1.entries[i1].count * map1.entries[i1].count);
  mag2 = 0.0; for (i2 = 0; i2 < map2.count; i2++) mag2 += (double)(map2.entries[i2].count * map2.entries[i2].count);
  mag1 = sqrt (mag1); mag2 = sqrt (mag2);

  result = (mag1 == 0.0 || mag2 == 0.0) ? 0.0 : dot / (mag1 * mag2);
  byte_ngram_map_free (&map1); byte_ngram_map_free (&map2);
  if (result < 0.0) result = 0.0;
  if (result > 1.0) result = 1.0;
  return result;
}

/* ============================================================
 * Code-point-aware implementations (for multi-byte UTF-8)
 * ============================================================ */

static int
levenshtein_distance_cp (const uint32_t *s1, int len1,
                         const uint32_t *s2, int len2)
{
  int i, j;
  int *prev, *curr, *tmp;
  int cost, result;

  if (len1 == 0) return len2;
  if (len2 == 0) return len1;

  if (len1 > len2)
    {
      const uint32_t *ts = s1; s1 = s2; s2 = ts;
      int tl = len1; len1 = len2; len2 = tl;
    }

  prev = (int *) dk_alloc (sizeof (int) * (len1 + 1));
  curr = (int *) dk_alloc (sizeof (int) * (len1 + 1));
  if (!prev || !curr)
    {
      if (prev) dk_free (prev, sizeof (int) * (len1 + 1));
      if (curr) dk_free (curr, sizeof (int) * (len1 + 1));
      return len2;
    }

  for (i = 0; i <= len1; i++) prev[i] = i;

  for (j = 1; j <= len2; j++)
    {
      curr[0] = j;
      for (i = 1; i <= len1; i++)
        {
          cost = (s1[i - 1] == s2[j - 1]) ? 0 : 1;
          {
            int del = prev[i] + 1;
            int ins = curr[i - 1] + 1;
            int sub = prev[i - 1] + cost;
            int min = del;
            if (ins < min) min = ins;
            if (sub < min) min = sub;
            curr[i] = min;
          }
        }
      tmp = prev; prev = curr; curr = tmp;
    }

  result = prev[len1];
  dk_free (prev, sizeof (int) * (len1 + 1)); dk_free (curr, sizeof (int) * (len1 + 1));
  return result;
}

static double
jaro_similarity_cp (const uint32_t *s1, int len1,
                    const uint32_t *s2, int len2)
{
  int match_distance, matches, transpositions;
  int i, j, start, end;
  char *s1_matches, *s2_matches;
  double result;

  if (len1 == 0 && len2 == 0) return 1.0;
  if (len1 == 0 || len2 == 0) return 0.0;
  if (len1 == len2 && memcmp (s1, s2, len1 * sizeof (uint32_t)) == 0) return 1.0;

  match_distance = (len1 > len2 ? len1 : len2) / 2 - 1;
  if (match_distance < 0) match_distance = 0;

  s1_matches = (char *) dk_alloc (len1);
  s2_matches = (char *) dk_alloc (len2);
  if (!s1_matches || !s2_matches)
    {
      if (s1_matches) dk_free (s1_matches, len1);
      if (s2_matches) dk_free (s2_matches, len2);
      return 0.0;
    }
  memset (s1_matches, 0, len1);
  memset (s2_matches, 0, len2);

  matches = 0;
  for (i = 0; i < len1; i++)
    {
      start = i - match_distance; if (start < 0) start = 0;
      end = i + match_distance + 1; if (end > len2) end = len2;
      for (j = start; j < end; j++)
        {
          if (s2_matches[j]) continue;
          if (s1[i] != s2[j]) continue;
          s1_matches[i] = 1; s2_matches[j] = 1; matches++; break;
        }
    }

  if (matches == 0) { dk_free (s1_matches, len1); dk_free (s2_matches, len2); return 0.0; }

  transpositions = 0; j = 0;
  for (i = 0; i < len1; i++)
    {
      if (!s1_matches[i]) continue;
      while (!s2_matches[j]) j++;
      if (s1[i] != s2[j]) transpositions++;
      j++;
    }
  transpositions /= 2;

  { double m = (double) matches;
    result = (m / len1 + m / len2 + (m - transpositions) / m) / 3.0; }

  dk_free (s1_matches, len1); dk_free (s2_matches, len2);
  return result;
}

static double
jaro_winkler_similarity_cp (const uint32_t *s1, int len1,
                            const uint32_t *s2, int len2)
{
  double jaro;
  int prefix_len, i;
  const double winkler_p = 0.1;
  const int max_prefix = 4;

  jaro = jaro_similarity_cp (s1, len1, s2, len2);
  if (jaro == 0.0) return 0.0;

  prefix_len = 0;
  for (i = 0; i < max_prefix && i < len1 && i < len2; i++)
    { if (s1[i] != s2[i]) break; prefix_len++; }

  return jaro + prefix_len * winkler_p * (1.0 - jaro);
}

/* Code-point n-gram map */
typedef struct { uint32_t *ngram; int count; } cp_ngram_entry_t;
typedef struct { cp_ngram_entry_t *entries; int count; int capacity; int n; } cp_ngram_map_t;

static void
cp_ngram_map_init (cp_ngram_map_t *map, int n)
{
  map->n = n; map->count = 0; map->capacity = 16;
  map->entries = (cp_ngram_entry_t *) dk_alloc (sizeof (cp_ngram_entry_t) * map->capacity);
}

static void
cp_ngram_map_free (cp_ngram_map_t *map)
{
  int i;
  for (i = 0; i < map->count; i++) dk_free (map->entries[i].ngram, sizeof (uint32_t) * map->n);
  dk_free (map->entries, sizeof (cp_ngram_entry_t) * map->capacity);
  map->entries = NULL; map->count = 0;
}

static int
cp_ngram_cmp (const uint32_t *a, const uint32_t *b, int n)
{
  int i;
  for (i = 0; i < n; i++)
    { if (a[i] < b[i]) return -1; if (a[i] > b[i]) return 1; }
  return 0;
}

static int
cp_ngram_map_find (cp_ngram_map_t *map, const uint32_t *ngram)
{
  int lo = 0, hi = map->count - 1;
  while (lo <= hi)
    {
      int mid = lo + (hi - lo) / 2;
      int cmp = cp_ngram_cmp (map->entries[mid].ngram, ngram, map->n);
      if (cmp == 0) return mid;
      if (cmp < 0) lo = mid + 1; else hi = mid - 1;
    }
  return -(lo + 1);
}

static void
cp_ngram_map_add (cp_ngram_map_t *map, const uint32_t *ngram)
{
  int idx;
  if (map->count > 0)
    {
      idx = cp_ngram_map_find (map, ngram);
      if (idx >= 0) { map->entries[idx].count++; return; }
      idx = -(idx + 1);
    }
  else idx = 0;

  if (map->count >= map->capacity)
    {
      int new_cap = map->capacity * 2;
      cp_ngram_entry_t *ne = (cp_ngram_entry_t *) dk_alloc (
          sizeof (cp_ngram_entry_t) * new_cap);
      if (!ne) return;
      memcpy (ne, map->entries, sizeof (cp_ngram_entry_t) * map->count);
      dk_free (map->entries, sizeof (cp_ngram_entry_t) * map->capacity);
      map->entries = ne; map->capacity = new_cap;
    }

  if (idx < map->count)
    memmove (&map->entries[idx + 1], &map->entries[idx],
             sizeof (cp_ngram_entry_t) * (map->count - idx));

  map->entries[idx].ngram = (uint32_t *) dk_alloc (sizeof (uint32_t) * map->n);
  if (map->entries[idx].ngram)
    memcpy (map->entries[idx].ngram, ngram, sizeof (uint32_t) * map->n);
  map->entries[idx].count = 1;
  map->count++;
}

static void
cp_ngram_map_build (cp_ngram_map_t *map, const uint32_t *s, int len)
{
  int i, j;
  uint32_t ngram_buf[8];
  int n = map->n;

  if (len == 0) return;

  if (len < n)
    {
      uint32_t *padded = (uint32_t *) dk_alloc (n * sizeof (uint32_t));
      int pad_left = (n - len) / 2;
      if (!padded) return;
      for (j = 0; j < n; j++) padded[j] = '$';
      memcpy (padded + pad_left, s, len * sizeof (uint32_t));
      cp_ngram_map_add (map, padded);
      dk_free (padded, n * sizeof (uint32_t));
      return;
    }

  for (i = 0; i <= len - n; i++)
    { memcpy (ngram_buf, s + i, n * sizeof (uint32_t)); cp_ngram_map_add (map, ngram_buf); }

  if (len >= n)
    {
      ngram_buf[0] = '$';
      memcpy (ngram_buf + 1, s, (n - 1) * sizeof (uint32_t));
      cp_ngram_map_add (map, ngram_buf);
      memcpy (ngram_buf, s + len - (n - 1), (n - 1) * sizeof (uint32_t));
      ngram_buf[n - 1] = '$';
      cp_ngram_map_add (map, ngram_buf);
    }
}

static double
ngram_cosine_similarity_cp (const uint32_t *s1, int len1,
                            const uint32_t *s2, int len2, int n)
{
  cp_ngram_map_t map1, map2;
  double dot, mag1, mag2, result;
  int i, i1 = 0, i2 = 0;

  if (n <= 0) n = FUZZY_DEFAULT_N;
  if (n > 7) n = 7;
  if (len1 == 0 && len2 == 0) return 1.0;
  if (len1 == 0 || len2 == 0) return 0.0;

  cp_ngram_map_init (&map1, n);
  cp_ngram_map_init (&map2, n);
  cp_ngram_map_build (&map1, s1, len1);
  cp_ngram_map_build (&map2, s2, len2);

  if (map1.count == 0 || map2.count == 0)
    { cp_ngram_map_free (&map1); cp_ngram_map_free (&map2); return 0.0; }

  dot = 0.0;
  while (i1 < map1.count && i2 < map2.count)
    {
      int cmp = cp_ngram_cmp (map1.entries[i1].ngram, map2.entries[i2].ngram, n);
      if (cmp == 0)
        { dot += (double)(map1.entries[i1].count * map2.entries[i2].count); i1++; i2++; }
      else if (cmp < 0) i1++; else i2++;
    }

  mag1 = 0.0; for (i = 0; i < map1.count; i++) mag1 += (double)(map1.entries[i].count * map1.entries[i].count);
  mag2 = 0.0; for (i = 0; i < map2.count; i++) mag2 += (double)(map2.entries[i].count * map2.entries[i].count);
  mag1 = sqrt (mag1); mag2 = sqrt (mag2);

  result = (mag1 == 0.0 || mag2 == 0.0) ? 0.0 : dot / (mag1 * mag2);
  cp_ngram_map_free (&map1); cp_ngram_map_free (&map2);
  if (result < 0.0) result = 0.0;
  if (result > 1.0) result = 1.0;
  return result;
}

/* ============================================================
 * Public API — dispatch between ASCII fast path and _cp variants
 * ============================================================ */

int
levenshtein_distance (const char *s1, const char *s2)
{
  int len1, len2;

  if (!s1) s1 = "";
  if (!s2) s2 = "";
  len1 = (int) strlen (s1);
  len2 = (int) strlen (s2);

  if (len1 == 0) return len2;
  if (len2 == 0) return len1;

  if (is_ascii (s1, len1) && is_ascii (s2, len2))
    return levenshtein_distance_bytes (s1, len1, s2, len2);

  {
    uint32_t cp1[FUZZY_MAX_CODEPOINTS], cp2[FUZZY_MAX_CODEPOINTS];
    int n1 = utf8_to_codepoints (s1, len1, cp1, FUZZY_MAX_CODEPOINTS);
    int n2 = utf8_to_codepoints (s2, len2, cp2, FUZZY_MAX_CODEPOINTS);
    if (n1 < 0 || n2 < 0)
      return len2 > len1 ? len2 : len1;
    return levenshtein_distance_cp (cp1, n1, cp2, n2);
  }
}

double
levenshtein_similarity (const char *s1, const char *s2)
{
  int len1, len2, max_len, dist;

  if (!s1) s1 = "";
  if (!s2) s2 = "";
  len1 = (int) strlen (s1);
  len2 = (int) strlen (s2);

  if (len1 == 0 && len2 == 0) return 1.0;
  max_len = len1 > len2 ? len1 : len2;
  if (max_len == 0) return 1.0;

  if (is_ascii (s1, len1) && is_ascii (s2, len2))
    dist = levenshtein_distance_bytes (s1, len1, s2, len2);
  else
    {
      uint32_t cp1[FUZZY_MAX_CODEPOINTS], cp2[FUZZY_MAX_CODEPOINTS];
      int n1 = utf8_to_codepoints (s1, len1, cp1, FUZZY_MAX_CODEPOINTS);
      int n2 = utf8_to_codepoints (s2, len2, cp2, FUZZY_MAX_CODEPOINTS);
      if (n1 < 0 || n2 < 0) return 0.0;
      max_len = n1 > n2 ? n1 : n2;
      dist = levenshtein_distance_cp (cp1, n1, cp2, n2);
    }
  return 1.0 - ((double) dist / (double) max_len);
}

double
jaro_similarity (const char *s1, const char *s2)
{
  int len1, len2;

  if (!s1) s1 = "";
  if (!s2) s2 = "";
  len1 = (int) strlen (s1);
  len2 = (int) strlen (s2);

  if (len1 == 0 && len2 == 0) return 1.0;
  if (len1 == 0 || len2 == 0) return 0.0;

  if (is_ascii (s1, len1) && is_ascii (s2, len2))
    return jaro_similarity_bytes (s1, len1, s2, len2);

  {
    uint32_t cp1[FUZZY_MAX_CODEPOINTS], cp2[FUZZY_MAX_CODEPOINTS];
    int n1 = utf8_to_codepoints (s1, len1, cp1, FUZZY_MAX_CODEPOINTS);
    int n2 = utf8_to_codepoints (s2, len2, cp2, FUZZY_MAX_CODEPOINTS);
    if (n1 < 0 || n2 < 0) return 0.0;
    return jaro_similarity_cp (cp1, n1, cp2, n2);
  }
}

double
jaro_winkler_similarity (const char *s1, const char *s2)
{
  int len1, len2;

  if (!s1) s1 = "";
  if (!s2) s2 = "";
  len1 = (int) strlen (s1);
  len2 = (int) strlen (s2);

  if (len1 == 0 && len2 == 0) return 1.0;
  if (len1 == 0 || len2 == 0) return 0.0;

  if (is_ascii (s1, len1) && is_ascii (s2, len2))
    return jaro_winkler_similarity_bytes (s1, len1, s2, len2);

  {
    uint32_t cp1[FUZZY_MAX_CODEPOINTS], cp2[FUZZY_MAX_CODEPOINTS];
    int n1 = utf8_to_codepoints (s1, len1, cp1, FUZZY_MAX_CODEPOINTS);
    int n2 = utf8_to_codepoints (s2, len2, cp2, FUZZY_MAX_CODEPOINTS);
    if (n1 < 0 || n2 < 0) return 0.0;
    return jaro_winkler_similarity_cp (cp1, n1, cp2, n2);
  }
}

double
ngram_cosine_similarity (const char *s1, const char *s2, int n)
{
  int len1, len2;

  if (!s1) s1 = "";
  if (!s2) s2 = "";
  len1 = (int) strlen (s1);
  len2 = (int) strlen (s2);

  if (n <= 0) n = FUZZY_DEFAULT_N;
  if (n > 7) n = 7;

  if (len1 == 0 && len2 == 0) return 1.0;
  if (len1 == 0 || len2 == 0) return 0.0;

  if (is_ascii (s1, len1) && is_ascii (s2, len2))
    return byte_ngram_cosine (s1, len1, s2, len2, n);

  {
    uint32_t cp1[FUZZY_MAX_CODEPOINTS], cp2[FUZZY_MAX_CODEPOINTS];
    int n1 = utf8_to_codepoints (s1, len1, cp1, FUZZY_MAX_CODEPOINTS);
    int n2 = utf8_to_codepoints (s2, len2, cp2, FUZZY_MAX_CODEPOINTS);
    if (n1 < 0 || n2 < 0) return 0.0;
    return ngram_cosine_similarity_cp (cp1, n1, cp2, n2, n);
  }
}

/* ============================================================
 * Dispatch
 * ============================================================ */

double
fuzzy_similarity (const char *s1, const char *s2, int algo_id, int ngram_size)
{
  switch (algo_id)
    {
    case FUZZY_JARO_WINKLER:
      return jaro_winkler_similarity (s1, s2);
    case FUZZY_LEVENSHTEIN:
      return levenshtein_similarity (s1, s2);
    case FUZZY_NGRAM_COSINE:
      return ngram_cosine_similarity (s1, s2, ngram_size);
    default:
      return 0.0;
    }
}

int
fuzzy_distance (const char *s1, const char *s2, int algo_id)
{
  switch (algo_id)
    {
    case FUZZY_LEVENSHTEIN:
      return levenshtein_distance (s1, s2);
    default:
      return -1;  /* No native distance for Jaro-Winkler or n-gram cosine */
    }
}

int
fuzzy_algo_id_from_name (const char *name)
{
  if (!name)
    return FUZZY_NONE;
  if (0 == strcasecmp (name, "jaro_winkler"))
    return FUZZY_JARO_WINKLER;
  if (0 == strcasecmp (name, "levenshtein"))
    return FUZZY_LEVENSHTEIN;
  if (0 == strcasecmp (name, "ngram_cosine"))
    return FUZZY_NGRAM_COSINE;
  return FUZZY_NONE;
}
