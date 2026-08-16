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
 *  No Virtuoso dependencies — only standard C library.
 *  Callable from BIF wrappers (sqlbif_fuzzy.c) and text.c.
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
#include <stdlib.h>
#include <math.h>

/* ============================================================
 * Levenshtein
 * ============================================================ */

int
levenshtein_distance (const char *s1, const char *s2)
{
  int len1, len2, i, j;
  int *prev, *curr;
  int *tmp;
  int cost;
  int result;

  if (!s1) s1 = "";
  if (!s2) s2 = "";

  len1 = (int) strlen (s1);
  len2 = (int) strlen (s2);

  if (len1 == 0) return len2;
  if (len2 == 0) return len1;

  /* Ensure len1 <= len2 for O(min(m,n)) space */
  if (len1 > len2)
    {
      const char *ts = s1; s1 = s2; s2 = ts;
      int tl = len1; len1 = len2; len2 = tl;
    }

  prev = (int *) malloc (sizeof (int) * (len1 + 1));
  curr = (int *) malloc (sizeof (int) * (len1 + 1));
  if (!prev || !curr)
    {
      if (prev) free (prev);
      if (curr) free (curr);
      return len2;  /* fallback: worst case */
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
            int del = prev[i] + 1;       /* deletion */
            int ins = curr[i - 1] + 1;   /* insertion */
            int sub = prev[i - 1] + cost; /* substitution */
            int min = del;
            if (ins < min) min = ins;
            if (sub < min) min = sub;
            curr[i] = min;
          }
        }
      /* Swap prev and curr */
      tmp = prev; prev = curr; curr = tmp;
    }

  result = prev[len1];
  free (prev);
  free (curr);
  return result;
}

double
levenshtein_similarity (const char *s1, const char *s2)
{
  int dist, max_len;
  int len1, len2;

  if (!s1) s1 = "";
  if (!s2) s2 = "";

  len1 = (int) strlen (s1);
  len2 = (int) strlen (s2);
  max_len = len1 > len2 ? len1 : len2;

  if (max_len == 0)
    return 1.0;

  dist = levenshtein_distance (s1, s2);
  return 1.0 - ((double) dist / (double) max_len);
}

/* ============================================================
 * Jaro / Jaro-Winkler
 * ============================================================ */

double
jaro_similarity (const char *s1, const char *s2)
{
  int len1, len2;
  int match_distance, matches, transpositions;
  int i, j, start, end;
  char *s1_matches, *s2_matches;
  double result;

  if (!s1) s1 = "";
  if (!s2) s2 = "";

  len1 = (int) strlen (s1);
  len2 = (int) strlen (s2);

  if (len1 == 0 && len2 == 0)
    return 1.0;
  if (len1 == 0 || len2 == 0)
    return 0.0;

  /* Quick check for identical strings */
  if (len1 == len2 && memcmp (s1, s2, len1) == 0)
    return 1.0;

  match_distance = (len1 > len2 ? len1 : len2) / 2 - 1;
  if (match_distance < 0)
    match_distance = 0;

  s1_matches = (char *) calloc (len1, 1);
  s2_matches = (char *) calloc (len2, 1);
  if (!s1_matches || !s2_matches)
    {
      if (s1_matches) free (s1_matches);
      if (s2_matches) free (s2_matches);
      return 0.0;
    }

  matches = 0;

  for (i = 0; i < len1; i++)
    {
      start = i - match_distance;
      if (start < 0) start = 0;
      end = i + match_distance + 1;
      if (end > len2) end = len2;

      for (j = start; j < end; j++)
        {
          if (s2_matches[j])
            continue;
          if (s1[i] != s2[j])
            continue;
          s1_matches[i] = 1;
          s2_matches[j] = 1;
          matches++;
          break;
        }
    }

  if (matches == 0)
    {
      free (s1_matches);
      free (s2_matches);
      return 0.0;
    }

  /* Count transpositions */
  transpositions = 0;
  j = 0;
  for (i = 0; i < len1; i++)
    {
      if (!s1_matches[i])
        continue;
      while (!s2_matches[j])
        j++;
      if (s1[i] != s2[j])
        transpositions++;
      j++;
    }
  transpositions /= 2;

  {
    double m = (double) matches;
    result = (m / len1 + m / len2 + (m - transpositions) / m) / 3.0;
  }

  free (s1_matches);
  free (s2_matches);
  return result;
}

double
jaro_winkler_similarity (const char *s1, const char *s2)
{
  double jaro;
  int prefix_len, i;
  int len1, len2;
  const double winkler_p = 0.1;
  const int max_prefix = 4;

  if (!s1) s1 = "";
  if (!s2) s2 = "";

  jaro = jaro_similarity (s1, s2);
  if (jaro == 0.0)
    return 0.0;

  /* Count common prefix (up to max_prefix) */
  len1 = (int) strlen (s1);
  len2 = (int) strlen (s2);
  prefix_len = 0;
  for (i = 0; i < max_prefix && i < len1 && i < len2; i++)
    {
      if (s1[i] != s2[i])
        break;
      prefix_len++;
    }

  return jaro + prefix_len * winkler_p * (1.0 - jaro);
}

/* ============================================================
 * N-gram cosine
 * ============================================================ */

/* Simple growable n-gram frequency map */
typedef struct
{
  char *ngram;        /* n-gram string (n+1 bytes including NUL) */
  int   count;        /* frequency count */
} ngram_entry_t;

typedef struct
{
  ngram_entry_t *entries;
  int count;          /* number of distinct n-grams */
  int capacity;       /* allocated capacity */
  int n;              /* n-gram size */
} ngram_map_t;

static void
ngram_map_init (ngram_map_t *map, int n)
{
  map->n = n;
  map->count = 0;
  map->capacity = 16;
  map->entries = (ngram_entry_t *) malloc (sizeof (ngram_entry_t) * map->capacity);
}

static void
ngram_map_free (ngram_map_t *map)
{
  int i;
  for (i = 0; i < map->count; i++)
    free (map->entries[i].ngram);
  free (map->entries);
  map->entries = NULL;
  map->count = 0;
}

/* n-gram size for comparison — set before calling ngram_map_find() */
static int g_ngram_cmp_size = 2;

/* Binary search for n-gram in sorted map. Returns index if found,
 * or -(insertion_point+1) if not found. */
static int
ngram_map_find (ngram_map_t *map, const char *ngram)
{
  int lo = 0, hi = map->count - 1;
  while (lo <= hi)
    {
      int mid = lo + (hi - lo) / 2;
      int cmp = memcmp (map->entries[mid].ngram, ngram, map->n);
      if (cmp == 0)
        return mid;
      if (cmp < 0)
        lo = mid + 1;
      else
        hi = mid - 1;
    }
  return -(lo + 1);
}

static void
ngram_map_add (ngram_map_t *map, const char *ngram)
{
  int idx;
  if (map->count > 0)
    {
      idx = ngram_map_find (map, ngram);
      if (idx >= 0)
        {
          map->entries[idx].count++;
          return;
        }
      idx = -(idx + 1);
    }
  else
    {
      idx = 0;
    }

  /* Grow if needed */
  if (map->count >= map->capacity)
    {
      map->capacity *= 2;
      map->entries = (ngram_entry_t *) realloc (map->entries,
          sizeof (ngram_entry_t) * map->capacity);
      if (!map->entries)
        return;  /* out of memory — skip */
    }

  /* Shift entries to make room at insertion point */
  if (idx < map->count)
    memmove (&map->entries[idx + 1], &map->entries[idx],
             sizeof (ngram_entry_t) * (map->count - idx));

  map->entries[idx].ngram = (char *) malloc (map->n + 1);
  if (map->entries[idx].ngram)
    {
      memcpy (map->entries[idx].ngram, ngram, map->n);
      map->entries[idx].ngram[map->n] = '\0';
    }
  map->entries[idx].count = 1;
  map->count++;
}

static void
ngram_map_build (ngram_map_t *map, const char *s)
{
  int len, i;
  char ngram_buf[8];  /* supports up to 7-grams */
  int n = map->n;

  if (!s) s = "";
  len = (int) strlen (s);

  if (len == 0)
    return;

  if (len < n)
    {
      /* Pad short strings with $ on both sides to form one n-gram */
      int padded_len = n;
      char *padded = (char *) malloc (padded_len + 1);
      int pad_left = (n - len) / 2;
      int pad_right = n - len - pad_left;
      if (!padded) return;
      memset (padded, '$', padded_len);
      memcpy (padded + pad_left, s, len);
      padded[padded_len] = '\0';
      ngram_map_add (map, padded);
      free (padded);
      return;
    }

  /* Build n-grams with boundary padding: $s1s2...sn$ */
  /* For interior n-grams, slide a window of size n */
  for (i = 0; i <= len - n; i++)
    {
      memcpy (ngram_buf, s + i, n);
      ngram_buf[n] = '\0';
      ngram_map_add (map, ngram_buf);
    }

  /* Boundary n-grams with $ padding */
  if (len >= n)
    {
      /* Left boundary: $ + first (n-1) chars */
      ngram_buf[0] = '$';
      memcpy (ngram_buf + 1, s, n - 1);
      ngram_buf[n] = '\0';
      ngram_map_add (map, ngram_buf);

      /* Right boundary: last (n-1) chars + $ */
      memcpy (ngram_buf, s + len - (n - 1), n - 1);
      ngram_buf[n - 1] = '$';
      ngram_buf[n] = '\0';
      ngram_map_add (map, ngram_buf);
    }
}

/* Compute dot product of two sorted n-gram maps */
static double
ngram_dot_product (ngram_map_t *m1, ngram_map_t *m2)
{
  double dot = 0.0;
  int i1 = 0, i2 = 0;

  while (i1 < m1->count && i2 < m2->count)
    {
      int cmp = memcmp (m1->entries[i1].ngram, m2->entries[i2].ngram, m1->n);
      if (cmp == 0)
        {
          dot += (double) (m1->entries[i1].count * m2->entries[i2].count);
          i1++;
          i2++;
        }
      else if (cmp < 0)
        i1++;
      else
        i2++;
    }
  return dot;
}

static double
ngram_magnitude (ngram_map_t *map)
{
  double mag = 0.0;
  int i;
  for (i = 0; i < map->count; i++)
    mag += (double) (map->entries[i].count * map->entries[i].count);
  return sqrt (mag);
}

double
ngram_cosine_similarity (const char *s1, const char *s2, int n)
{
  ngram_map_t map1, map2;
  double dot, mag1, mag2, result;

  if (!s1) s1 = "";
  if (!s2) s2 = "";

  if (n <= 0) n = FUZZY_DEFAULT_N;
  if (n > 7) n = 7;  /* safety cap */

  if (s1[0] == '\0' && s2[0] == '\0')
    return 1.0;
  if (s1[0] == '\0' || s2[0] == '\0')
    return 0.0;

  ngram_map_init (&map1, n);
  ngram_map_init (&map2, n);

  ngram_map_build (&map1, s1);
  ngram_map_build (&map2, s2);

  if (map1.count == 0 || map2.count == 0)
    {
      ngram_map_free (&map1);
      ngram_map_free (&map2);
      return 0.0;
    }

  dot = ngram_dot_product (&map1, &map2);
  mag1 = ngram_magnitude (&map1);
  mag2 = ngram_magnitude (&map2);

  if (mag1 == 0.0 || mag2 == 0.0)
    result = 0.0;
  else
    result = dot / (mag1 * mag2);

  ngram_map_free (&map1);
  ngram_map_free (&map2);

  /* Clamp to 0..1 to handle floating-point rounding */
  if (result < 0.0) result = 0.0;
  if (result > 1.0) result = 1.0;
  return result;
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
