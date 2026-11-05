/*
 *  graph_reduce.h
 *
 *  The two O(V) reductions the convergence tests use
 *
 *  Declarations only.  graph_reduce.c explains why these must stay out of
 *  line: the pinned convergence values were taken across this call
 *  boundary and inlining them moves the last bits.
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

#ifndef GRAPH_REDUCE_H
#define GRAPH_REDUCE_H

#include <stdint.h>

#ifdef __cplusplus
extern "C"
{
#endif

/* sum |a[i] - b[i]|, the convergence residual. */
  double graph_l1_residual (const double *a, const double *b, uint64_t n);

/* sqrt (sum a[i]^2). */
  double graph_l2_norm (const double *a, uint64_t n);

#ifdef __cplusplus
}
#endif

#endif				/* GRAPH_REDUCE_H */
