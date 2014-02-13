/*
 *  numeric.h
 *
 *  $Id$
 *
 *  Numeric data type
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2014 OpenLink Software
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

#ifndef _WI_NUMERIC_H
#define _WI_NUMERIC_H

/* basic data type */
typedef struct numeric_s *numeric_t;

#define NUMERIC_PADDING	4


struct numeric_s
    {
      char n_len;	/* The number of digits before the decimal point. */
      char n_scale;	/* The number of digits after the decimal point. */
      char n_invalid;	/* NDF_NAN or NDF_INF */
      char n_neg;	/* 0 or 1 */
      char n_value[NUMERIC_PADDING];
    };

#define num_is_zero(N)		((N)->n_len + (N)->n_scale == 0)
#define num_is_invalid(N)	((N)->n_invalid)
#define num_is_nan(N)		((N)->n_invalid & NDF_NAN)
#define num_is_inf(N)		((N)->n_invalid & NDF_INF)
#define num_is_plus_inf(N)	(num_is_inf (N) && (N)->n_neg == 0)
#define num_is_minus_inf(N)	(num_is_inf (N) && (N)->n_neg == 1)

/* flags in marshalled number */
#define NDF_INF		0x10	/* Inf */
#define NDF_NAN		0x08	/* NaN */
#define NDF_LEAD0	0x04	/* Leading 0 */
#define NDF_TRAIL0	0x02	/* Trailing 0 */
#define NDF_NEG		0x01	/* Negative */

#define is_dv_negative(X)	((X)[NDV_FLAGS] & NDF_NEG)

/* intrinsics */
#define DV_NUMERIC			219

/* max. values for SQL declarations */
#define NUMERIC_MAX_PRECISION		40
#define NUMERIC_MAX_SCALE		15
#define NUMERIC_EXTRA_SCALE		5

/* internal precision and scale */
#define NUMERIC_MAX_PRECISION_INT	(NUMERIC_MAX_PRECISION + NUMERIC_EXTRA_SCALE)
#define NUMERIC_MAX_SCALE_INT		(NUMERIC_MAX_SCALE + NUMERIC_EXTRA_SCALE)

/* bytes needed for string conversion buffer allocation (+sign, dot, 0) */
#define NUMERIC_MAX_STRING_BYTES	(NUMERIC_MAX_PRECISION + 3)

/* bytes needed to store the number (give some extra for internal overflows) */
#define NUMERIC_MAX_DATA_BYTES		(2 * NUMERIC_MAX_PRECISION_INT + 4)

/* bytes needed for stack allocation (4 = current overhead of numeric_s) */
/* #define NUMERIC_STACK_BYTES		(NUMERIC_MAX_DATA_BYTES + 4) */
/*  (94) -- must be a multiple of 8, because of the way it's used here */
#define NUMERIC_STACK_BYTES		104

/* stack initializer */
#define NUMERIC_VAR(VAR) \
	int64 VAR[NUMERIC_STACK_BYTES/8]
#define NUMERIC_INIT(var) \
  *((int64*)&var) = (int64)0
/*
#define NUMERIC_INIT(var) \
  (*((int64*)&var) = (int64)0, var)*/
/* return codes, error reporting */
#define NUMERIC_STS_SUCCESS	0	/* OK */
#define NUMERIC_STS_OVERFLOW	1	/* Overflow (+Inf) */
#define NUMERIC_STS_UNDERFLOW	2	/* Underflow (-Inf) */
#define NUMERIC_STS_INVALID_NUM	3	/* Number invalid (NaN) */
#define NUMERIC_STS_INVALID_STR	4	/* Invalid string */
#define NUMERIC_STS_DIVIDE_ZERO	5	/* Division by zero */
#define NUMERIC_STS_MARSHALLING	6	/* Marshalling error occurred */

/* initialization - call before everything else */
int numeric_init (void);
void numeric_rc_clear (void);

/* allocation, free */


numeric_t mp_numeric_allocate (mem_pool_t * mp);

#ifdef MALLOC_DEBUG
#define numeric_allocate() dbg_numeric_allocate (__FILE__, __LINE__)
#define t_numeric_allocate() dbg_t_numeric_allocate (__FILE__, __LINE__)
numeric_t dbg_numeric_allocate (DBG_PARAMS_0);	/* dynamic allocation */
numeric_t dbg_t_numeric_allocate (DBG_PARAMS_0);	/* thread space dynamic allocation */
#else
numeric_t numeric_allocate (void);		/* dynamic allocation */
numeric_t t_numeric_allocate (void);		/* thread space dynamic allocation */
#endif
void numeric_free (numeric_t n);
int numeric_copy (numeric_t y, numeric_t x);
numeric_t numeric_init_static (numeric_t n, size_t size);/* stack allocation */

/* error reporting */
int numeric_error (int code, char *sqlstate, int state_len, char *sqlerror, int error_length);

/* conversion */
int numeric_from_string (numeric_t n, const char *s);
const char *numeric_from_string_is_ok (const char *s);
int numeric_from_int32 (numeric_t n, int32 i);
int numeric_from_int64 (numeric_t n, int64 i);
int numeric_from_double (numeric_t n, double d);
int numeric_from_dv (numeric_t n, dtp_t *buf, int n_bytes);
int numeric_from_buf (numeric_t n, dtp_t *buf);
int numeric_to_hex_array (numeric_t n, unsigned char * arr);
void numeric_from_hex_array (numeric_t n, char len, char scale, char sign, unsigned char * arr, int a_len);
int numeric_sign (numeric_t n);
/* int numeric_to_string_box (numeric_t n, char **pvalue); */
int numeric_to_string (numeric_t n, char *pvalue, size_t max_pvalue);
int numeric_to_int32 (numeric_t n, int32 *pvalue);
int numeric_to_int64 (numeric_t n, int64 *pvalue);
int numeric_to_double (numeric_t n, double *pvalue);
int numeric_to_dv (numeric_t n, dtp_t *res, size_t reslength);

int numeric_rescale (numeric_t y, numeric_t x, int prec, int scale);
int numeric_rescale_noround (numeric_t y, numeric_t x, int prec, int scale);

/* arithmetic & comparison */
int numeric_compare (numeric_t x, numeric_t y);
int numeric_add (numeric_t z, numeric_t x, numeric_t y);
int numeric_subtract (numeric_t z, numeric_t x, numeric_t y);
int numeric_multiply (numeric_t z, numeric_t x, numeric_t y);
int numeric_divide (numeric_t z, numeric_t x, numeric_t y);
int numeric_negate (numeric_t y, numeric_t x);
int numeric_modulo (numeric_t z, numeric_t x, numeric_t y);
int numeric_sqr (numeric_t z, numeric_t x);

/* marshalling */
int numeric_serialize (numeric_t n, dk_session_t *session);
void *numeric_deserialize (dk_session_t *session, dtp_t macro);
int numeric_dv_compare (dtp_t *x, dtp_t *y);

/* debugging */
#ifdef NUMERIC_DEBUG
void numeric_print (FILE *fd, char *what, numeric_t n);
void numeric_debug (FILE *fd, char *what, numeric_t n);
void numeric_dv_debug (FILE *fd, char *name, dtp_t *res);
#endif

/* Note: returns internal precision (!) */
int numeric_precision (numeric_t n);
int numeric_raw_precision (numeric_t n);
int numeric_scale (numeric_t n);
int _numeric_size (void);
uint32 numeric_hash (numeric_t n);

/* Internals listed below are not for common use.
Functions that use them outside numeric.c should probably be splitted and low-level parts should be added to numeric.c API. */
extern void num_add (numeric_t sum, numeric_t n1, numeric_t n2, int scale_min);

#endif /* _WI_NUMERIC_H */
