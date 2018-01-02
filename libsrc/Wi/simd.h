/*
 *  simd.h
 *
 *  $Id$
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2018 OpenLink Software
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

#if defined(__GNUC__)
typedef long v2di_t __attribute__ ((vector_size (16)));
typedef double v2df_t __attribute__ ((vector_size (16)));
typedef float v4sf_t __attribute__ ((vector_size (16)));
typedef int v4si_t __attribute__ ((vector_size (16)));
typedef char v16qi_t __attribute__ ((vector_size (16)));
#else
typedef long v2di_t;
typedef double v2df_t;
typedef float v4sf_t;
typedef int v4si_t;
typedef char v16qi_t;
#endif

typedef union
{
  v2di_t v;
  int64 l[2];
} v2di_u_t;


typedef union {
  v2di_t v[ARTM_VEC_LEN / 2];
  int64 i[ARTM_VEC_LEN];
  unsigned char 	dt[ARTM_VEC_LEN][DT_LENGTH];
} vn_temp_t;


/*  Operation flags for sse 4.2 string instructions */

#define PSTR_EQUAL_ANY 0	/*         = 0000b */
#define PSTR_RANGES 4		/* = 0100b */
#define PSTR_EQUAL_EACH 8	/*    = 1000b */
#define PSTR_EQUAL_ORDERED 10	/* = 1100b */
#define PSTR_NEGATIVE_POLARITY 0x20	/* = 010000b */
#define PSTR_BYTE_MASK 0x40	 = 1000000b
