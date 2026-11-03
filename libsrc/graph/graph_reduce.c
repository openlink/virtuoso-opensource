/*
 *  graph_reduce.c
 *
 *  The two O(V) reductions the convergence tests use
 *
 *  These are what is left of graph_simd.c, which was a vectorisation layer
 *  with no vector instructions in it: a feature enum from SSE2 to AVX512F,
 *  a CPUID probe on x86 and a sysctl on ARM, a string reporting what it
 *  found, and three entry points every one of which fell through to a
 *  scalar loop.  The third entry point, graph_simd_normalize, had no caller
 *  at all.  A layer that advertises AVX512F in front of three scalar loops
 *  invites the reader to believe work has been done that has not, so it is
 *  gone and these two loops are here under their own names.
 *
 *  THEY ARE STILL NOT VECTORISED, AND THAT IS A CONSTRAINT RATHER THAN AN
 *  OMISSION.  Both are reductions; floating-point addition is not
 *  associative; and every technique that makes a reduction fast -- several
 *  accumulators, tree summation, adding vector lanes -- changes the order
 *  the partial sums form in and therefore the rounding.  The residual is
 *  the worse of the two to disturb: its value only feeds a
 *  `residual < epsilon` test, but that test decides the iteration count and
 *  the iteration count decides the answer, so a last-bit difference can end
 *  the loop an iteration early.  Pinned PageRank and eigenvector values are
 *  asserted to the last digit, nineteen of them against another
 *  implementation's published output at 1e-9.  They are also O(V) against
 *  an O(E) gather, so they are the cheap loop even if they could be moved.
 *
 *  THIS FILE IS A TRANSLATION-UNIT BOUNDARY ON PURPOSE.  DO NOT MAKE THESE
 *  `static inline` IN A HEADER.  It was tried: inlining lets the compiler
 *  see through the call, and both pinned eigenvector values moved -- Group
 *  J's weighted one from 0.3865438480412036 to 0.3865438480412035 with
 *  contraction left alone, and Group A's unweighted one from
 *  0.3728480715891352 to 0.3728480715891351 when contraction was turned off
 *  to fix the first.  Neither value is more correct than the other; they are
 *  different legal roundings of the same sum, and a one-bit change in the
 *  norm divides every score by a slightly different number and can move the
 *  iteration count with it.  The pinned values were taken across this
 *  boundary and they hold only across it.
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

#include "graph_reduce.h"
#include <math.h>

double
graph_l1_residual (const double *a, const double *b, uint64_t n)
{
  double sum = 0.0;
  for (uint64_t i = 0; i < n; i++)
    sum += fabs (a[i] - b[i]);
  return sum;
}

double
graph_l2_norm (const double *a, uint64_t n)
{
  double sum = 0.0;
  for (uint64_t i = 0; i < n; i++)
    sum += a[i] * a[i];
  return sqrt (sum);
}
