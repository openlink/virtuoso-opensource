/*
 *  sqlbif_fuzzy.c
 *
 *  $Id$
 *
 *  BIF wrappers for fuzzy string similarity algorithms.
 *
 *  Registers the following SQL/SPARQL functions:
 *    - levenshtein(str1, str2)              → integer edit distance
 *    - levenshtein_similarity(str1, str2)   → double 0.0..1.0
 *    - jaro_winkler(str1, str2)             → double 0.0..1.0
 *    - jaro_winkler_similarity(str1, str2)  → double 0.0..1.0 (alias)
 *    - ngram_cosine(str1, str2)             → double 0.0..1.0 (bigrams)
 *    - ngram_cosine_n(str1, str2, n)        → double 0.0..1.0 (n-grams of size n)
 *
 *  All functions are automatically available in SPARQL as
 *  bif:levenshtein(), bif:jaro_winkler(), etc. and as
 *  sql:levenshtein(), sql:jaro_winkler(), etc.
 *  No separate SPARQL registration is needed — the SPARQL
 *  compiler resolves bif:/sql: prefixes via find_bif_metadata_by_raw_name().
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

#include "sqlnode.h"
#include "sqlbif.h"
#include "fuzzy_algorithms.h"

/* ============================================================
 * BIF wrappers
 * ============================================================ */

static caddr_t
bif_levenshtein (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t s1 = bif_string_or_null_arg (qst, args, 0, "levenshtein");
  caddr_t s2 = bif_string_or_null_arg (qst, args, 1, "levenshtein");
  if (NULL == s1 || NULL == s2)
    return dk_alloc_box (0, DV_DB_NULL);
  return box_num (levenshtein_distance (s1, s2));
}

static caddr_t
bif_levenshtein_similarity (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t s1 = bif_string_or_null_arg (qst, args, 0, "levenshtein_similarity");
  caddr_t s2 = bif_string_or_null_arg (qst, args, 1, "levenshtein_similarity");
  if (NULL == s1 || NULL == s2)
    return dk_alloc_box (0, DV_DB_NULL);
  return box_double (levenshtein_similarity (s1, s2));
}

static caddr_t
bif_jaro_winkler (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t s1 = bif_string_or_null_arg (qst, args, 0, "jaro_winkler");
  caddr_t s2 = bif_string_or_null_arg (qst, args, 1, "jaro_winkler");
  if (NULL == s1 || NULL == s2)
    return dk_alloc_box (0, DV_DB_NULL);
  return box_double (jaro_winkler_similarity (s1, s2));
}

static caddr_t
bif_jaro_winkler_similarity (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t s1 = bif_string_or_null_arg (qst, args, 0, "jaro_winkler_similarity");
  caddr_t s2 = bif_string_or_null_arg (qst, args, 1, "jaro_winkler_similarity");
  if (NULL == s1 || NULL == s2)
    return dk_alloc_box (0, DV_DB_NULL);
  return box_double (jaro_winkler_similarity (s1, s2));
}

static caddr_t
bif_ngram_cosine (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t s1 = bif_string_or_null_arg (qst, args, 0, "ngram_cosine");
  caddr_t s2 = bif_string_or_null_arg (qst, args, 1, "ngram_cosine");
  if (NULL == s1 || NULL == s2)
    return dk_alloc_box (0, DV_DB_NULL);
  return box_double (ngram_cosine_similarity (s1, s2, FUZZY_DEFAULT_N));
}

static caddr_t
bif_ngram_cosine_n (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t s1 = bif_string_or_null_arg (qst, args, 0, "ngram_cosine_n");
  caddr_t s2 = bif_string_or_null_arg (qst, args, 1, "ngram_cosine_n");
  boxint n = bif_long_arg (qst, args, 2, "ngram_cosine_n");
  if (NULL == s1 || NULL == s2)
    return dk_alloc_box (0, DV_DB_NULL);
  if (n < 1) n = FUZZY_DEFAULT_N;
  if (n > 7) n = 7;
  return box_double (ngram_cosine_similarity (s1, s2, (int) n));
}

/* ============================================================
 * Registration
 * ============================================================ */

void
sqlbif_fuzzy_init (void)
{
  bif_define ("levenshtein", bif_levenshtein);
  bif_define ("levenshtein_similarity", bif_levenshtein_similarity);
  bif_define ("jaro_winkler", bif_jaro_winkler);
  bif_define ("jaro_winkler_similarity", bif_jaro_winkler_similarity);
  bif_define ("ngram_cosine", bif_ngram_cosine);
  bif_define ("ngram_cosine_n", bif_ngram_cosine_n);
}
