/*
 *  fuzzy_algorithms.h
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
 *  These functions have no Virtuoso dependencies and can be
 *  called from both the BIF wrapper layer and the text search
 *  engine (text.c) for contains() integration.
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

#ifndef _FUZZY_ALGORITHMS_H
#define _FUZZY_ALGORITHMS_H

/* Algorithm IDs for dispatch via fuzzy_similarity() */
#define FUZZY_NONE           0
#define FUZZY_JARO_WINKLER   1
#define FUZZY_LEVENSHTEIN    2
#define FUZZY_NGRAM_COSINE   3

/* Default n-gram size for ngram_cosine */
#define FUZZY_DEFAULT_N      2

/* Default similarity threshold for contains() integration */
#define FUZZY_DEFAULT_THRESHOLD 0.7

/*
 * Levenshtein edit distance between two strings.
 * Returns the number of single-character edits (insert, delete,
 * substitute) needed to transform s1 into s2.
 *
 * Uses O(min(m,n)) space (single-row DP).
 *
 * @param s1  First string (UTF-8 bytes)
 * @param s2  Second string (UTF-8 bytes)
 * @return    Edit distance (0 = identical)
 */
int
levenshtein_distance (const char *s1, const char *s2);

/*
 * Normalized Levenshtein similarity.
 * Returns 1.0 - (distance / max(len(s1), len(s2))).
 * Returns 1.0 for identical strings, 0.0 for completely different.
 *
 * @param s1  First string
 * @param s2  Second string
 * @return    Similarity score 0.0..1.0
 */
double
levenshtein_similarity (const char *s1, const char *s2);

/*
 * Jaro similarity.
 * Standard Jaro similarity for short strings (names, typos).
 *
 * @param s1  First string
 * @param s2  Second string
 * @return    Similarity score 0.0..1.0
 */
double
jaro_similarity (const char *s1, const char *s2);

/*
 * Jaro-Winkler similarity.
 * Jaro similarity with a prefix bonus (p=0.1, max prefix=4).
 * Best for short strings where typos tend to be at the end.
 *
 * @param s1  First string
 * @param s2  Second string
 * @return    Similarity score 0.0..1.0
 */
double
jaro_winkler_similarity (const char *s1, const char *s2);

/*
 * N-gram cosine similarity.
 * Extracts all character n-grams from each string (with $ boundary
 * padding), builds frequency vectors, and computes cosine similarity.
 *
 * @param s1  First string
 * @param s2  Second string
 * @param n   N-gram size (2=bigrams, 3=trigrams). 0 defaults to 2.
 * @return    Similarity score 0.0..1.0
 */
double
ngram_cosine_similarity (const char *s1, const char *s2, int n);

/*
 * Dispatch function: compute similarity by algorithm ID.
 * Used by text.c contains() integration.
 *
 * @param s1        First string
 * @param s2        Second string
 * @param algo_id   One of FUZZY_JARO_WINKLER, FUZZY_LEVENSHTEIN, FUZZY_NGRAM_COSINE
 * @param ngram_size  N-gram size (only used for FUZZY_NGRAM_COSINE)
 * @return          Similarity score 0.0..1.0
 */
double
fuzzy_similarity (const char *s1, const char *s2, int algo_id, int ngram_size);

/*
 * Dispatch function: compute edit distance by algorithm ID.
 * Only FUZZY_LEVENSHTEIN has a native edit distance; returns -1 for
 * other algorithms (caller should check before using the result).
 *
 * @param s1        First string
 * @param s2        Second string
 * @param algo_id   Algorithm ID
 * @return          Edit distance (>=0), or -1 if not applicable
 */
int
fuzzy_distance (const char *s1, const char *s2, int algo_id);

/*
 * Parse an algorithm name string into an algorithm ID.
 *
 * @param name  Algorithm name: "jaro_winkler", "levenshtein", "ngram_cosine"
 * @return      Algorithm ID, or FUZZY_NONE if unrecognized
 */
int
fuzzy_algo_id_from_name (const char *name);

#endif /* _FUZZY_ALGORITHMS_H */
