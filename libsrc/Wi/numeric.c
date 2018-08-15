/*
 *  numeric.c
 *
 *  $Id$
 *
 *  Implements numeric data type
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

#include "Dk.h"
#include "numeric.h"

/* activates code for divmod, modulo, powmod, pow, sqr */
#define NUMERIC_EXTS	1

/* #define NUMERIC_DEBUG */

/* maximum value for 4 byte integer */
#ifndef INT32_MAX
#define INT32_MAX	2147483647
#endif

/* 8 - sizeof (numeric_s without n_value) */

/* special numbers		   len sc i sgn   data */
static struct numeric_s _num_0	= { 0, 0, 0, 0, { 0	}};	/* 0 */
static struct numeric_s _num_1	= { 1, 0, 0, 0, { 1	}};	/* 1 */
#ifdef NUMERIC_EXTS
static struct numeric_s _num_pt5= { 1, 1, 0, 0, { 0, 5	}};	/* 0.5 */
static struct numeric_s _num_2	= { 1, 0, 0, 0, { 2	}};	/* 2 */
static struct numeric_s _num_10	= { 2, 0, 0, 0, { 1, 0	}};	/* 10 */
#endif

#define NUM_SET_0(n)		*(int64*)n = 0
#define NUM_SET_0_REST(n) {\
    ((int64*)n)[1] = 0; \
    ((int64*)n)[2] = 0; \
    ((int64*)n)[3] = 0; \
    ((int64*)n)[4] = 0; \
    ((int64*)n)[5] = 0; \
}


#define NUM_SET_1(N)		memcpy (N, &_num_1, sizeof (_num_1))
#define NUM_SET_10(N)		memcpy (N, &_num_10, sizeof (_num_10))

#ifdef NUMERIC_DEBUG
# define num_warn(X)	puts(X)
#else
# define num_warn(X)
#endif

/* byte offsets in marshalled value */
#define NDV_TAG		0	/* DV_NUMERIC */
#define NDV_LEN		1	/* #bytes excluding header (TAG+LEN) */
#define NDV_FLAGS	2	/* flags, see below */
#define NDV_L		3	/* #bytes encoding number before . */
#define NDV_DATA	4	/* bcd */

#ifndef TRUE
# define TRUE		1
# define FALSE		0
#endif

/* returned in _numeric_to_string if invalid result */
#define BAD_NUMBER_STR	"?NUMBER?"

/*****************************************************************************
 * Internal
 *****************************************************************************/


/* Compare two bc numbers.  Return value is 0 if equal, -1 if N1 is less
   than N2 and +1 if N1 is greater than N2.  If USE_SIGN is false, just
   compare the magnitudes. */


#define num_static static

int
_numeric_size (void)
{
  return sizeof (struct numeric_s) + NUMERIC_MAX_DATA_BYTES - NUMERIC_PADDING;
}

static int
_num_compare_int (numeric_t n1, numeric_t n2, int use_sign)
{
  char *n1ptr, *n2ptr;
  int count;

  /* First, compare signs. */
  if (use_sign && n1->n_neg != n2->n_neg)
    {
      if (n1->n_neg)
	return (-1);		/* Negative N1 < Positive N1 */
      else
	return (1);		/* Positive N1 > Negative N2 */
    }

  /* Now compare the magnitude. */
  if (n1->n_len != n2->n_len)
    {
      if (n1->n_len > n2->n_len)
	{
	  /* Magnitude of n1 > n2. */
	  if (!use_sign || !n1->n_neg)
	    return (1);
	  else
	    return (-1);
	}
      else
	{
	  /* Magnitude of n1 < n2. */
	  if (!use_sign || !n1->n_neg)
	    return (-1);
	  else
	    return (1);
	}
    }

  /* If we get here, they have the same number of integer digits.
     check the integer part and the equal length part of the fraction. */
  count = n1->n_len + MIN (n1->n_scale, n2->n_scale);
  n1ptr = n1->n_value;
  n2ptr = n2->n_value;

  while ((count > 0) && (*n1ptr == *n2ptr))
    {
      n1ptr++;
      n2ptr++;
      count--;
    }

  if (count != 0)
    {
      if (*n1ptr > *n2ptr)
	{
	  /* Magnitude of n1 > n2. */
	  if (!use_sign || !n1->n_neg)
	    return (1);
	  else
	    return (-1);
	}
      else
	{
	  /* Magnitude of n1 < n2. */
	  if (!use_sign || !n1->n_neg)
	    return (-1);
	  else
	    return (1);
	}
    }

  /* They are equal up to the last part of the equal part of the fraction. */
  if (n1->n_scale != n2->n_scale)
    {
      if (n1->n_scale > n2->n_scale)
	{
	  for (count = n1->n_scale - n2->n_scale; count > 0; count--)
	    if (*n1ptr++ != 0)
	      {
		/* Magnitude of n1 > n2. */
		if (!use_sign || !n1->n_neg)
		  return (1);
		else
		  return (-1);
	      }
	}
      else
	{
	  for (count = n2->n_scale - n1->n_scale; count > 0; count--)
	    if (*n2ptr++ != 0)
	      {
		/* Magnitude of n1 < n2. */
		if (!use_sign || !n1->n_neg)
		  return (-1);
		else
		  return (1);
	      }
	}
    }

  /* They must be equal! */
  return (0);
}


/* For many things, we may have leading zeros in a number NUM.
   _num_normalize just moves the data to the correct
   place and adjusts the length. */

num_static void
_num_normalize (numeric_t num)
{
  char *src;
  int bytes;

  /* Do a quick check to see if we need to do it. */
  if (num->n_value[0] == 0)
    {
      /* The first "digit" is 0, find the first non-zero digit in the second
	or greater "digit" to the left of the decimal place. */
      bytes = num->n_len;
      src = num->n_value;
      while (bytes > 0 && *src == 0)
	{
	  src++;
	  bytes--;
	}
      num->n_len = bytes;
      memmove (num->n_value, src, bytes + num->n_scale);
    }
}


/* Perform addition: N1 is added to N2 and the value is
   returned.  The signs of N1 and N2 are ignored.
   SCALE_MIN is to set the minimum scale of the result. */

num_static void
_num_add_int (numeric_t result, numeric_t n1, numeric_t n2, int scale_min)
{
  numeric_t sum;
  int sum_scale, sum_digits;
  char *n1ptr, *n2ptr, *sumptr;
  int carry, n1bytes, n2bytes;

  /* Prepare sum. */
  sum_scale = MAX (n1->n_scale, n2->n_scale);
  sum_digits = MAX (n1->n_len, n2->n_len) + 1;

  if (result == n1 || result == n2)
    sum = numeric_allocate ();
  else
    {
      sum = result;
      NUM_SET_0 (sum);
    }

  sum->n_len = sum_digits;
  sum->n_scale = MAX (sum_scale, scale_min);

  /* Zero extra digits made by scale_min. */
  if (scale_min > sum_scale)
    {
      NUM_SET_0_REST (sum);
    }

  /* Start with the fraction part.  Initialize the pointers. */
  n1bytes = n1->n_scale;
  n2bytes = n2->n_scale;
  n1ptr = n1->n_value + n1->n_len + n1bytes - 1;
  n2ptr = n2->n_value + n2->n_len + n2bytes - 1;
  sumptr = sum->n_value + sum_scale + sum_digits - 1;
  sum->n_value[0] = 0;

  /* Add the fraction part.  First copy the longer fraction. */
  if (n1bytes != n2bytes)
    {
      if (n1bytes > n2bytes)
	while (n1bytes > n2bytes)
	  {
	    *sumptr-- = *n1ptr--;
	    n1bytes--;
	  }
      else
	while (n2bytes > n1bytes)
	  {
	    *sumptr-- = *n2ptr--;
	    n2bytes--;
	  }
    }

  /* Now add the remaining fraction part and equal size integer parts. */
  n1bytes += n1->n_len;
  n2bytes += n2->n_len;
  carry = 0;
  while (n1bytes > 0 && n2bytes > 0)
    {
      *sumptr = *n1ptr-- + *n2ptr-- + carry;
      if (*sumptr > 9)
	{
	  carry = 1;
	  *sumptr -= 10;
	}
      else
	carry = 0;
      sumptr--;
      n1bytes--;
      n2bytes--;
    }

  /* Now add carry the longer integer part. */
  if (n1bytes == 0)
    {
      n1bytes = n2bytes;
      n1ptr = n2ptr;
    }
  while (n1bytes-- > 0)
    {
      *sumptr = *n1ptr-- + carry;
      if (*sumptr > 9)
	{
	  carry = 1;
	  *sumptr -= 10;
	}
      else
	carry = 0;
      sumptr--;
    }

  /* Set final carry. */
  if (carry == 1)
    *sumptr += 1;

  /* Adjust sum and return. */
  _num_normalize (sum);

  if (sum != result)
    {
      numeric_copy (result, sum);
      numeric_free (sum);
    }
}


/* Perform subtraction: N2 is subtracted from N1 and the value is
   returned.  The signs of N1 and N2 are ignored.  Also, N1 is
   assumed to be larger than N2.  SCALE_MIN is the minimum scale
   of the result. */

num_static void
_num_subtract_int (numeric_t result, numeric_t n1, numeric_t n2, int scale_min)
{
  numeric_t diff;
  int diff_scale, diff_len;
  int min_scale, min_len;
  char *n1ptr, *n2ptr, *diffptr;
  int borrow, count, val;

  /* Allocate temporary storage. */
  diff_len = MAX (n1->n_len, n2->n_len);
  diff_scale = MAX (n1->n_scale, n2->n_scale);
  min_len = MIN (n1->n_len, n2->n_len);
  min_scale = MIN (n1->n_scale, n2->n_scale);
  if (result == n1 || result == n2)
    diff = numeric_allocate ();
  else
    {
      diff = result;
      NUM_SET_0 (diff);
    }
  diff->n_len = diff_len;
  diff->n_scale = MAX (diff_scale, scale_min);

  /* Zero extra digits made by scale_min. */
  if (scale_min > diff_scale)
    {
      diffptr = diff->n_value + diff_len + diff_scale;
      for (count = scale_min - diff_scale; count > 0; count--)
	*diffptr++ = 0;
    }

  /* Initialize the subtract. */
  n1ptr = n1->n_value + n1->n_len + n1->n_scale - 1;
  n2ptr = n2->n_value + n2->n_len + n2->n_scale - 1;
  diffptr = diff->n_value + diff_len + diff_scale - 1;
  diff->n_value[0] = 0;

  /* Subtract the numbers. */
  borrow = 0;

  /* Take care of the longer scaled number. */
  if (n1->n_scale != min_scale)
    {
      /* n1 has the longer scale */
      for (count = n1->n_scale - min_scale; count > 0; count--)
	*diffptr-- = *n1ptr--;
    }
  else
    {
      /* n2 has the longer scale */
      for (count = n2->n_scale - min_scale; count > 0; count--)
	{
	  val = -*n2ptr-- - borrow;
	  if (val < 0)
	    {
	      val += 10;
	      borrow = 1;
	    }
	  else
	    borrow = 0;
	  *diffptr-- = val;
	}
    }

  /* Now do the equal length scale and integer parts. */

  for (count = 0; count < min_len + min_scale; count++)
    {
      val = *n1ptr-- - *n2ptr-- - borrow;
      if (val < 0)
	{
	  val += 10;
	  borrow = 1;
	}
      else
	borrow = 0;
      *diffptr-- = val;
    }

  /* If n1 has more digits then n2, we now do that subtract. */
  if (diff_len != min_len)
    {
      for (count = diff_len - min_len; count > 0; count--)
	{
	  val = *n1ptr-- - borrow;
	  if (val < 0)
	    {
	      val += 10;
	      borrow = 1;
	    }
	  else
	    borrow = 0;
	  *diffptr-- = val;
	}
    }

  /* Clean up and return. */
  _num_normalize (diff);

  if (diff != result)
    {
      numeric_copy (result, diff);
      numeric_free (diff);
    }
}


/* Some utility routines for the divide:  First a one digit multiply.
   NUM (with SIZE digits) is multiplied by DIGIT and the result is
   placed into RESULT.  It is written so that NUM and RESULT can be
   the same pointers.  */

num_static void
_num_multiply_int (unsigned char *result, unsigned char *num, int size, int digit)
{
  int carry, value;
  unsigned char *nptr, *rptr;

  if (digit == 0)
    memset (result, 0, size);
  else
    {
      if (digit == 1)
	memcpy (result, num, size);
      else
	{
	  /* Initialize */
	  nptr = num + size - 1;
	  rptr = result + size - 1;
	  carry = 0;

	  while (size-- > 0)
	    {
	      value = *nptr-- * digit + carry;
	      *rptr-- = value % 10;
	      carry = value / 10;
	    }

	  if (carry != 0)
	    *rptr = carry;
	}
    }
}


#ifdef NUMERIC_EXTS
/* In some places we need to check if the number NUM is zero. */

num_static int
_num_is_near_0 (numeric_t num, int scale)
{
  int count;
  char *nptr;

  if (num_is_zero (num))
    return TRUE;

  /* Initialize */
  count = num->n_len + scale;
  nptr = num->n_value;

  /* The check */
  while ((count > 0) && (*nptr++ == 0))
    count--;

  if (count != 0 && (count != 1 || *--nptr != 1))
    return FALSE;
  else
    return TRUE;
}
#endif


/*****************************************************************************
 * Low level functions
 *****************************************************************************/

/* Here is the full add routine that takes care of negative numbers.
   N1 is added to N2 and the result placed into RESULT.  SCALE_MIN
   is the minimum scale for the result. */

void
num_add (numeric_t sum, numeric_t n1, numeric_t n2, int scale_min)
{
  int cmp_res;
  int res_scale;
  int n1sign, n2sign;

  n1sign = n1->n_neg;
  n2sign = n2->n_neg;

  if (n1sign == n2sign)
    {
      _num_add_int (sum, n1, n2, scale_min);
      sum->n_neg = n1sign;
    }
  else
    {
      /* subtraction must be done. */
      /* Compare magnitudes. */
      cmp_res = _num_compare_int (n1, n2, FALSE);
      switch (cmp_res)
	{
	case -1:
	  /* n1 is less than n2, subtract n1 from n2. */
	  _num_subtract_int (sum, n2, n1, scale_min);
	  sum->n_neg = n2sign;
	  break;
	case 0:
	  /* They are equal! return zero with the correct scale! */
	  res_scale = MAX (scale_min, MAX (n1->n_scale, n2->n_scale));
	  NUM_SET_0 (sum);
	  break;
	case 1:
	default: /* keep cc happy */
	  /* n2 is less than n1, subtract n2 from n1. */
	  _num_subtract_int (sum, n1, n2, scale_min);
	  sum->n_neg = n1sign;
	  break;
	}
    }
}


/* Here is the full subtract routine that takes care of negative numbers.
   N2 is subtracted from N1 and the result placed in RESULT.  SCALE_MIN
   is the minimum scale for the result. */

void
num_subtract (numeric_t diff, numeric_t n1, numeric_t n2, int scale_min)
{
  int res_scale;
  int n1sign, n2sign;

  n1sign = n1->n_neg;
  n2sign = n2->n_neg;

  if (n1sign != n2sign)
    {
      _num_add_int (diff, n1, n2, scale_min);
      diff->n_neg = n1sign;
    }
  else
    {
      /* subtraction must be done. */
      /* Compare magnitudes. */
      switch (_num_compare_int (n1, n2, FALSE))
	{
	case -1:
	  /* n1 is less than n2, subtract n1 from n2. */
	  _num_subtract_int (diff, n2, n1, scale_min);
	  diff->n_neg = 1 - n2sign;
	  break;
	case 0:
	  /* They are equal! return zero! */
	  res_scale = MAX (scale_min, MAX (n1->n_scale, n2->n_scale));
	  NUM_SET_0 (diff);
	  break;
	case 1:
	default: /* keep cc happy */
	  /* n2 is less than n1, subtract n2 from n1. */
	  _num_subtract_int (diff, n1, n2, scale_min);
	  diff->n_neg = n1sign;
	  break;
	}
    }
}


/* The multiply routine.  N2 time N1 is put int RESULT with the scale of
   the result being MIN(N2 scale+N1 scale, MAX (SCALE, N2 scale, N1 scale)).
 */

void
num_multiply (numeric_t result, numeric_t n1, numeric_t n2, int scale)
{
  numeric_t pval;			/* For the working storage. */
  char *n1ptr, *n2ptr, *pvptr;	/* Work pointers. */
  char *n1end, *n2end;		/* To the end of n1 and n2. */
  int indx;
  int len1, len2, total_digits;
  long sum;
  int full_scale, prod_scale;
  int toss;

  /* Initialize things. */
  len1 = n1->n_len + n1->n_scale;
  len2 = n2->n_len + n2->n_scale;
  total_digits = len1 + len2;
  full_scale = n1->n_scale + n2->n_scale;
  prod_scale = MIN (full_scale, MAX (scale, MAX (n1->n_scale, n2->n_scale)));
  toss = full_scale - prod_scale;

  if (result == n1 || result == n2)
    pval = numeric_allocate ();
  else
    {
      pval = result;
      NUM_SET_0 (pval);
    }
  pval->n_len = total_digits - full_scale;
  pval->n_scale = prod_scale;
  pval->n_neg = n1->n_neg ^ n2->n_neg;

  n1end = n1->n_value + len1 - 1;
  n2end = n2->n_value + len2 - 1;
  pvptr = pval->n_value + total_digits - toss - 1;
  sum = 0;

  /* Here are the loops... */
  for (indx = 0; indx < toss; indx++)
    {
      n1ptr = n1end - MAX (0, indx - len2 + 1);
      n2ptr = n2end - MIN (indx, len2 - 1);
      while ((n1ptr >= n1->n_value) && (n2ptr <= n2end))
	sum += *n1ptr-- * *n2ptr++;
      sum = sum / 10;
    }
  for (; indx < total_digits - 1; indx++)
    {
      n1ptr = n1end - MAX (0, indx - len2 + 1);
      n2ptr = n2end - MIN (indx, len2 - 1);
      while ((n1ptr >= n1->n_value) && (n2ptr <= n2end))
	sum += *n1ptr-- * *n2ptr++;
      *pvptr-- = (char) (sum % 10);
      sum = sum / 10;
    }
  *pvptr-- = (char) sum;

  _num_normalize (pval);
  if (num_is_zero (pval))
    pval->n_neg = 0;

  if (pval != result)
    {
      numeric_copy (result, pval);
      numeric_free (pval);
    }
}


/* The full division routine. This computes N1 / N2.  It returns
   0 if the division is ok and the result is in QUOT.  The number of
   digits after the decimal point is SCALE. It returns -1 if division
   by zero is tried.  The algorithm is found in Knuth Vol 2. p237. */

int
num_divide (numeric_t result, numeric_t n1, numeric_t n2, int scale)
{
  numeric_t qval;
  unsigned char num1[NUMERIC_STACK_BYTES];
  unsigned char num2[NUMERIC_STACK_BYTES];
  unsigned char mval[NUMERIC_STACK_BYTES];
  unsigned char *ptr1, *ptr2, *n2ptr, *qptr;
  int scale1, val;
  unsigned int len1, len2, scale2, qdigits, extra, count;
  unsigned int qdig, qguess, borrow, carry;
  char zero;
  unsigned int norm;

  /* Test for divide by zero. */
  if (num_is_zero (n2))
    return -1;

  /* Set up the divide.  Move the decimal point on n1 by n2's scale.
     Remember, zeros on the end of num2 are wasted effort for dividing. */
  scale2 = n2->n_scale;
  n2ptr = (unsigned char *) n2->n_value + n2->n_len + scale2 - 1;
  while ((scale2 > 0) && (*n2ptr-- == 0))
    scale2--;

  len1 = n1->n_len + scale2;
  scale1 = n1->n_scale - scale2;
  if (scale1 < scale)
    extra = scale - scale1;
  else
    extra = 0;
  assert (n1->n_len + n1->n_scale + extra + 2 <= NUMERIC_STACK_BYTES);
  memset (num1, 0, n1->n_len + n1->n_scale + extra + 2);
  memcpy (num1 + 1, n1->n_value, n1->n_len + n1->n_scale);

  len2 = n2->n_len + scale2;
  assert (len2 + 1 <= NUMERIC_STACK_BYTES);
  memcpy (num2, n2->n_value, len2);
  *(num2 + len2) = 0;
  n2ptr = num2;
  while (*n2ptr == 0)
    {
      n2ptr++;
      len2--;
    }

  /* Calculate the number of quotient digits. */
  if (len2 > len1 + scale)
    {
      qdigits = scale + 1;
      zero = TRUE;
    }
  else
    {
      zero = FALSE;
      if (len2 > len1)
	qdigits = scale + 1;	/* One for the zero integer part. */
      else
	qdigits = len1 - len2 + scale + 1;
    }

  /* Allocate and zero the storage for the quotient. */
  if (result == n1 || result == n2)
    qval = numeric_allocate ();
  else
    {
      qval = result;
      NUM_SET_0 (qval);
    }
  qval->n_len = qdigits - scale;
  qval->n_scale = scale;
  memset (qval->n_value, 0, qdigits);

  assert (len2 + 1 <= NUMERIC_STACK_BYTES);

  /* Now for the full divide algorithm. */
  if (!zero)
    {
      /* Normalize */
      norm = 10 / ((int) *n2ptr + 1);
      if (norm != 1)
	{
	  _num_multiply_int (num1, num1, len1 + scale1 + extra + 1, norm);
	  _num_multiply_int (n2ptr, n2ptr, len2, norm);
	}

      /* Initialize divide loop. */
      qdig = 0;
      if (len2 > len1)
	qptr = (unsigned char *) qval->n_value + len2 - len1;
      else
	qptr = (unsigned char *) qval->n_value;

      /* Loop */
      while (qdig <= len1 + scale - len2)
	{
	  /* Calculate the quotient digit guess. */
	  if (*n2ptr == num1[qdig])
	    qguess = 9;
	  else
	    qguess = (num1[qdig] * 10 + num1[qdig + 1]) / *n2ptr;

	  /* Test qguess. */
	  if (n2ptr[1] * qguess >
	      (num1[qdig] * 10 + num1[qdig + 1] - *n2ptr * qguess) * 10
	      + num1[qdig + 2])
	    {
	      qguess--;
	      /* And again. */
	      if (n2ptr[1] * qguess >
		  (num1[qdig] * 10 + num1[qdig + 1] - *n2ptr * qguess) * 10
		  + num1[qdig + 2])
		qguess--;
	    }

	  /* Multiply and subtract. */
	  borrow = 0;
	  if (qguess != 0)
	    {
	      *mval = 0;
	      _num_multiply_int (mval + 1, n2ptr, len2, qguess);
	      ptr1 = (unsigned char *) num1 + qdig + len2;
	      ptr2 = (unsigned char *) mval + len2;
	      for (count = 0; count < len2 + 1; count++)
		{
		  val = (int) *ptr1 - (int) *ptr2-- - borrow;
		  if (val < 0)
		    {
		      val += 10;
		      borrow = 1;
		    }
		  else
		    borrow = 0;
		  *ptr1-- = val;
		}
	    }

	  /* Test for negative result. */
	  if (borrow == 1)
	    {
	      qguess--;
	      ptr1 = (unsigned char *) num1 + qdig + len2;
	      ptr2 = (unsigned char *) n2ptr + len2 - 1;
	      carry = 0;
	      for (count = 0; count < len2; count++)
		{
		  val = (int) *ptr1 + (int) *ptr2-- + carry;
		  if (val > 9)
		    {
		      val -= 10;
		      carry = 1;
		    }
		  else
		    carry = 0;
		  *ptr1-- = val;
		}
	      if (carry == 1)
		*ptr1 = (*ptr1 + 1) % 10;
	    }

	  /* We now know the quotient digit. */
	  *qptr++ = qguess;
	  qdig++;
	}
    }

  /* Clean up and return the number. */
  qval->n_neg = n1->n_neg ^ n2->n_neg;
  _num_normalize (qval);
  if (num_is_zero (qval))
    qval->n_neg = 0;

  if (qval != result)
    {
      numeric_copy (result, qval);
      numeric_free (qval);
    }

  return 0;			/* Everything is OK. */
}


#ifdef NUMERIC_EXTS

/* Division *and* modulo for numbers.  This computes both NUM1 / NUM2 and
   NUM1 % NUM2  and puts the results in QUOT and REM, except that if QUOT
   is NULL then that store will be omitted.
 */

int
num_divmod (numeric_t quot, numeric_t rem, numeric_t num1, numeric_t num2, int scale)
{
  numeric_t temp;
  int rscale;

  /* Check for correct numbers. */
  if (num_is_zero (num2))
    return -1;

  /* Calculate final scale. */
  rscale = MAX (num1->n_scale, num2->n_scale + scale);
  temp = numeric_allocate ();

  /* Calculate it. */
  num_divide (temp, num1, num2, 0);
  if (quot)
    numeric_copy (quot, temp);

  num_multiply (temp, temp, num2, rscale);
  num_subtract (rem, num1, temp, rscale);
  numeric_free (temp);

  return 0;			/* Everything is OK. */
}


/* Modulo for numbers.  This computes NUM1 % NUM2  and puts the
   result in RESULT.   */

int
num_modulo (numeric_t result, numeric_t num1, numeric_t num2, int scale)
{
  return num_divmod (NULL, result, num1, num2, scale);
}


/* Raise BASE to the EXPO power, reduced modulo MOD.  The result is
   placed in RESULT.  If a EXPO is not an integer,
   only the integer part is used.  */

int
num_powmod (numeric_t result, numeric_t base, numeric_t expo, numeric_t mod, int scale)
{
  numeric_t power, exponent, parity, temp;
  int rscale;

  /* Check for correct numbers. */
  if (num_is_zero (mod))
    return -1;
  if (expo->n_neg)
    return -1;

  /* Set initial values.  */
  power = numeric_allocate ();
  numeric_copy (power, base);

  exponent = numeric_allocate ();
  numeric_copy (exponent, expo);

  temp = numeric_allocate ();
  NUM_SET_1 (temp);

  parity = numeric_allocate ();

  /* Check the exponent for scale digits. */
  if (exponent->n_scale != 0)
    {
      num_warn ("non-zero scale in exponent");
      num_divide (exponent, exponent, &_num_1, 0);	/*truncate */
    }

  /* Check the modulus for scale digits. */
  if (mod->n_scale != 0)
    {
      num_warn ("non-zero scale in modulus");
      num_divide (mod, mod, &_num_1, 0);	/*truncate */
    }

  /* Do the calculation. */
  rscale = MAX (scale, base->n_scale);
  while (!num_is_zero (exponent))
    {
      num_divmod (exponent, parity, exponent, &_num_2, 0);
      if (!num_is_zero (parity))
	{
	  num_multiply (temp, temp, power, rscale);
	  num_modulo (temp, temp, mod, scale);
	}

      num_multiply (power, power, power, rscale);
      num_modulo (power, power, mod, scale);
    }

  numeric_copy (result, temp);

  /* Assign the value. */
  numeric_free (power);
  numeric_free (exponent);
  numeric_free (parity);
  numeric_free (temp);

  return 0;			/* Everything is OK. */
}


/* Raise NUM1 to the NUM2 power.  The result is placed in RESULT.
   Maximum exponent is LONG_MAX.  If a NUM2 is not an integer,
   only the integer part is used.  */

void
num_pow (numeric_t result, numeric_t num1, numeric_t num2, int scale)
{
  numeric_t temp, power;
  int32 exponent;
  int rscale;
  char neg;

  /* Check the exponent for scale digits and convert to a long. */
  if (num2->n_scale != 0)
    {
      num_warn ("non-zero scale in exponent");
      num_divide (num2, num2, &_num_1, 0);	/*truncate */
    }
  numeric_to_int32 (num2, &exponent);

#if 0
  if (exponent == 0 && (num2->n_len > 1 || num2->n_value[0] != 0))
    {
      num_warn ("exponent too large in raise");
      NUM_SET_0 (result);
      return;
    }
#endif

  /* Special case if exponent is a zero. */
  if (exponent == 0)
    {
      NUM_SET_1 (result);
      return;
    }

  /* Other initializations. */
  if (exponent < 0)
    {
      neg = 1;
      exponent = -exponent;
      rscale = scale;
    }
  else
    {
      neg = 0;
      rscale = MIN (num1->n_scale * exponent, MAX (scale, num1->n_scale));
    }

  /* Set initial value of temp.  */
  power = numeric_allocate ();
  numeric_copy (power, num1);
  while ((exponent & 1) == 0)
    {
      num_multiply (power, power, power, rscale);
      exponent = exponent >> 1;
    }
  temp = numeric_allocate ();
  numeric_copy (temp, power);
  exponent = exponent >> 1;

  /* Do the calculation. */
  while (exponent > 0)
    {
      num_multiply (power, power, power, rscale);
      if ((exponent & 1) == 1)
	num_multiply (temp, temp, power, rscale);
      exponent = exponent >> 1;
    }

  /* Assign the value. */
  if (neg)
    num_divide (result, &_num_1, temp, rscale);
  else
    numeric_copy (result, temp);

  numeric_free (power);
  numeric_free (temp);
}


/* Take the square root NUM and return it in NUM with SCALE digits
   after the decimal place. */

int
num_sqr (numeric_t result, numeric_t num, int scale)
{
  int rscale, cmp_res, done;
  int cscale;
  numeric_t guess, guess1, diff;

  /* Initial checks. */
  cmp_res = _num_compare_int (num, &_num_0, TRUE);
  if (cmp_res < 0)
    return -1;			/* error */
  else if (cmp_res == 0)
    {
      NUM_SET_0 (result);
      return 0;
    }

  cmp_res = _num_compare_int (num, &_num_1, TRUE);
  if (cmp_res == 0)
    {
      NUM_SET_1 (result);
      return 0;
    }

  /* Initialize the variables. */
  rscale = MAX (scale, num->n_scale);
  guess = numeric_allocate ();
  guess1 = numeric_allocate ();
  diff = numeric_allocate ();

  /* Calculate the initial guess. */
  if (cmp_res < 0)
    /* The number is between 0 and 1.  Guess should start at 1. */
    NUM_SET_1 (guess);
  else
    {
      /* The number is greater than 1.  Guess should start at 10^(exp/2). */
      NUM_SET_10 (guess);
      numeric_from_int32 (guess1, num->n_len >> 1);
      num_pow (guess, guess, guess1, 0);
    }

  /* Find the square root using Newton's algorithm. */
  done = FALSE;
  cscale = 3;
  while (!done)
    {
      numeric_copy (guess1, guess);
      num_divide (guess, num, guess, cscale);
      num_add (guess, guess, guess1, 0);
      num_multiply (guess, guess, &_num_pt5, cscale);
      num_subtract (diff, guess, guess1, cscale + 1);
      if (_num_is_near_0 (diff, cscale))
	{
	  if (cscale < rscale + 1)
	    cscale = MIN (cscale * 3, rscale + 1);
	  else
	    done = TRUE;
	}
    }

  /* Assign the number and clean up. */
  num_divide (result, guess, &_num_1, rscale);

  numeric_free (guess);
  numeric_free (guess1);
  numeric_free (diff);

  return 0;
}
#endif


/*****************************************************************************
 * Number API implementation
 *****************************************************************************/

num_static resource_t *_numeric_rc;


/*
 *  Constructor for new numbers
 */
num_static void *
_numeric_rc_allocate (void *ignore)
{
  numeric_t n;

  n = (numeric_t) dk_alloc_box (sizeof (struct numeric_s)
      + NUMERIC_MAX_DATA_BYTES - NUMERIC_PADDING, DV_NUMERIC);

  NUM_SET_0 (n);

  return (void *) n;
}


num_static void
_numeric_rc_free (void *ptr)
{
  dk_free_box ((box_t) ptr);
}


num_static void
_numeric_rc_clear (void *ptr)
{
  NUM_SET_0 (ptr);
}



int
numeric_hash_cmp (ccaddr_t n1, ccaddr_t n2)
{
  return 0 == numeric_compare ((numeric_t) n1, (numeric_t) n2);
}


/*
 *  Initialize the number package
 */
int
numeric_init (void)
{
  _numeric_rc = resource_allocate (200,
      _numeric_rc_allocate, _numeric_rc_free, _numeric_rc_clear, 0);
  dk_dtp_register_hash (DV_NUMERIC, (box_hash_func_t) numeric_hash, numeric_hash_cmp, numeric_hash_cmp);
  return NUMERIC_STS_SUCCESS;
}

void
numeric_rc_clear (void)
{
  resource_clear (_numeric_rc, NULL);
}


/*
 *  Constructor for new numbers
 */
numeric_t
DBG_NAME(numeric_allocate) (DBG_PARAMS_0)
{
#ifdef NUM_RC
  /* with thread level dk_alloc cache dk_alloc is faster because of no mtx */
  return resource_get (_numeric_rc);
#else
  numeric_t n;

  n = (numeric_t) DBG_NAME(dk_alloc_box) (DBG_ARGS sizeof (struct numeric_s)
      + NUMERIC_MAX_DATA_BYTES - NUMERIC_PADDING, DV_NUMERIC);

  NUM_SET_0 (n);

  return n;
#endif
}


numeric_t
DBG_NAME(t_numeric_allocate) (DBG_PARAMS_0)
{
#ifdef NUM_RC
  /* with thread level dk_alloc cache dk_alloc is faster because of no mtx */
  return resource_get (_numeric_rc);
#else
  numeric_t n;

  n = (numeric_t) DBG_NAME(t_alloc_box) (sizeof (struct numeric_s)
      + NUMERIC_MAX_DATA_BYTES - NUMERIC_PADDING, DV_NUMERIC);
  memset (n, 0, sizeof (struct numeric_s));

  NUM_SET_0 (n);

  return n;
#endif
}


numeric_t
mp_numeric_allocate (mem_pool_t * mp)
{
  return (numeric_t) mp_alloc_box (mp, sizeof (struct numeric_s)
				    + NUMERIC_MAX_DATA_BYTES - NUMERIC_PADDING, DV_NUMERIC);
}


/*
 *  Destructor for a number
 */
void
numeric_free (numeric_t n)
{
#ifdef NUM_RC
  resource_store (_numeric_rc, (void *) n);
#else
  dk_free_box ((caddr_t) n);
#endif
}


/*
 *  For implementation of the NUMERIC_VAR / NUMERIC_INIT macros
 *  (See numeric.h)
 */
numeric_t
numeric_init_static (numeric_t n, size_t size)
{
  assert (size >= sizeof (struct numeric_s)
      + NUMERIC_MAX_DATA_BYTES - NUMERIC_PADDING);

  NUM_SET_0 (n);

  return n;
}


/*
 *  Sets number to NaN
 */
num_static int
_numeric_nan (numeric_t n)
{
  NUM_SET_0 (n);
  n->n_invalid = NDF_NAN;

  return NUMERIC_STS_INVALID_NUM;
}


/*
 *  Sets number to +/- Inf
 */
num_static int
_numeric_inf (numeric_t n, int neg)
{
  NUM_SET_0 (n);
  n->n_invalid = NDF_INF;
  n->n_neg = neg ? 1 : 0;

  return neg ? NUMERIC_STS_UNDERFLOW : NUMERIC_STS_OVERFLOW;
}


/*
 *  Normalizes a number.
 *  This function gets called after every arithmetic operation.
 *  It checks for overflow on the internal precision/scale.
 */
num_static int
_numeric_normalize (numeric_t n)
{
  int new_scale, scale;
  char *src, *first_frac;

  /* This is inlined code for
   *   numeric_rescale (n, n, NUMERIC_MAX_PRECISION_INT, NUMERIC_MAX_SCALE_INT)
   * slightly optimized for this special case.  */

  /* too big?
   * we cannot use NUMERIC_MAX_PRECISION_INT here, because overflow would
   * then not be detected before numeric_rescale gets called */
  if (n->n_len > NUMERIC_MAX_PRECISION)
    return _numeric_inf (n, 0);

  /* adjust scale if not enough digits available */
  new_scale = MIN (NUMERIC_MAX_PRECISION_INT - n->n_len, NUMERIC_MAX_SCALE_INT);

  /* too much fraction? */
  if (n->n_scale > new_scale)
    {
      /* XXX is banker's rounding necessary for the case we are truncating
       * after the internal max precision? This would in fact use one more
       * digit as the agreed internal scale. If too inaccurate, we should
       * increase NUMERIC_EXTRA_SCALE.
       * Let's decide to do things the quick way.
       */
#if 0
      if (n->n_value[n->n_len + new_scale] >= 5)
	{
	  /* construct .00..5 for bankers rounding */
	  NUMERIC_VAR (temp);
	  NUMERIC_INIT (temp);
	  memset (temp->n_value, 0, new_scale);
	  temp->n_value[new_scale] = 5;
	  temp->n_scale = new_scale + 1;
	  temp->n_neg = n->n_neg;
	  num_add (n, n, temp, new_scale);
	  /* too big after the rounding? */
	  if (n->n_len > new_prec)
	    return _numeric_inf (n, n->n_neg);
	}
#endif
      n->n_scale = new_scale;
    }

  /* Check if we have to remove trailing zeroes. */
  if (n->n_scale)
    {
      scale = n->n_scale;
      first_frac = n->n_value + n->n_len;
	src = n->n_value + n->n_len + scale - 1;
      while (src >= first_frac  && *src == 0)
	src--;
      n->n_scale = (src - first_frac) + 1;
/* IvAn/MinusZeroNormalization/000109 If n is negative, n_len is zero,
n_scale is nonzero and all digits are zeroes, then it is -0 and
n_neg MUST be set to 0.
*/
      if ((0 == n->n_scale) && (0 == n->n_len))
	n->n_neg = 0;
    }

  /* Assumption that should always hold */
  assert (n->n_neg == 0 || !num_is_zero (n));
  assert (n->n_len >= 0);
  assert (n->n_scale >= 0);

  return NUMERIC_STS_SUCCESS;
}


/*
 *  Assignment operation
 */
int
numeric_copy (numeric_t result, numeric_t n)
{
  if (result != n)
    {
      int value_bytes = n->n_len + n->n_scale;
      *(int64*)result = *(int64*)n;
      if (value_bytes > 4)
	{
	  ((int64*)result)[1] = ((int64*)n)[1];
	  if (value_bytes > 12)
	    {
	      ((int64*)result)[2] = ((int64*)n)[2];
	      if (value_bytes > 20)
		{
		  ((int64*)result)[3] = ((int64*)n)[3];
		  ((int64*)result)[4] = ((int64*)n)[4];
		  ((int64*)result)[5] = ((int64*)n)[5];
		  if (value_bytes > 44)
		    memcpy (((char *)result) + 48, ((char *)n) + 48, value_bytes - 44);
		}
	    }
	}
    }
  return NUMERIC_STS_SUCCESS;
}


/*
 *  Returns a sqlerror for a return code
 */
int
numeric_error (int code, char *sqlstate, int state_len, char *sqlerror, int error_length)
{
  char *state;
  char *error;

  switch (code)
    {
    case NUMERIC_STS_SUCCESS:
      state = "S0000";
      error = "Success";
      break;
    case NUMERIC_STS_OVERFLOW:		/* +Inf */
    case NUMERIC_STS_UNDERFLOW:		/* -Inf */
    case NUMERIC_STS_INVALID_NUM:	/* NaN */
      state = "22003";
      error = "Numeric value out of range";
      break;
    case NUMERIC_STS_INVALID_STR:	/* string -> number failed */
      state = "37000";
      error = "Syntax error";
      break;
    case NUMERIC_STS_DIVIDE_ZERO:
      state = "22012";
      error = "Division by zero";
      break;
    case NUMERIC_STS_MARSHALLING:
      state = "S1107";
      error = "Row value out of range";
      break;
    default:
      state = "S1000";
      error = "General error";
      break;
    }

  if (sqlstate)
    strcpy_size_ck (sqlstate, state, state_len);

  if (sqlerror && error_length)
    {
      strncpy (sqlerror, error, error_length);
      sqlerror[error_length - 1] = 0;
    }

  return NUMERIC_STS_SUCCESS;
}


/*
 *  Assign a string to a number
 */
int
numeric_from_string (numeric_t n, const char *s)
{
  const char *cp=s;
  const char *dot;
  char *dp;
  int error;
  int neg;
  int exp;
  int scale;
  int first;
  int rc;

  /* strip leading whitespace */
  while (isspace (*cp)) cp++;
  if ('$' == *cp)
    {
      cp++;
      while (isspace (*cp)) cp++;
    }

  /* get sign */
  if (*cp == '-')
    {
      neg = 1;
      cp++;
    }
  else
    {
      neg = 0;
      if (*cp == '+')
	cp++;
    }

  /* accept space between the sign & the digits - as M$ SQL does */
  while (isspace (*cp))
    cp++;

  /* handles cases for numeric_from_double */
  if (!isdigit (cp[0]))
    {
      if (!stricmp (cp, "INF") || !stricmp (cp, "Infinity"))
	{
	  _numeric_inf (n, neg);
	  return NUMERIC_STS_SUCCESS;
	}

      if (!strcmp (cp, "NaN"))
	{
	  _numeric_nan (n);
	  return NUMERIC_STS_SUCCESS;
	}
    }

  NUM_SET_0 (n);

  dot = NULL;
  exp = 0;
  scale = 0;
  first = 1;
  error = NUMERIC_STS_SUCCESS;
  dp = n->n_value;

  for (; *cp; cp++)
    {
      if (toupper (*cp) == 'E')
	{
	  exp = atoi (cp + 1);
	  break;
	}
      else if (*cp == '.')
	{
	  if (dot)
	    {
	      error = NUMERIC_STS_INVALID_STR;
	      break;
	    }
	  dot = cp;
	}
      else if (isdigit (*cp))
	{
	  if (first)
	    {
	      if (*cp != '0')
		first = 0;
	      else if (!dot)
		continue;
	    }
	  if (dp - n->n_value < NUMERIC_MAX_DATA_BYTES)
	    {
	      *dp++ = *cp - '0';
	      if (dot)
		n->n_scale++;
	      else
		n->n_len++;
	    }
	  else if (dot == NULL)
	    {
	      error = _numeric_inf (n, neg);
	      break;
	    }
	}
      else
	{
	  if (*cp && !isspace (*cp))
	    error = NUMERIC_STS_INVALID_STR;
	  break;
	}
    }

  rc = _numeric_normalize (n);

  if (neg && !num_is_zero (n))
    n->n_neg = 1;

  /* handle exponent */
  if (exp && error == NUMERIC_STS_SUCCESS && rc == NUMERIC_STS_SUCCESS)
    {
      if (exp > 0)
	{
	  if (n->n_scale >= exp)
	    {
	      n->n_scale -= exp;
	      n->n_len += exp;
	    }
	  else
	    {
	      exp -= n->n_scale;
	      n->n_len += n->n_scale;
	      n->n_scale = 0;
	      if (n->n_len + exp > NUMERIC_MAX_PRECISION)
		{
		  error = _numeric_inf (n, neg);
		}
	      else
		{
		  memset (n->n_value + n->n_len, 0, exp);
		  n->n_len += exp;
		}
	    }
	}
      else /* exp < 0 */
	{
	  exp = -exp;
	  if (n->n_len >= exp)
	    {
	      n->n_len -= exp;
	      n->n_scale += exp;
	    }
	  else
	    {
	      exp -= n->n_len;
	      n->n_scale += n->n_len;
	      n->n_len = 0;
	      if (exp >= NUMERIC_MAX_SCALE_INT)
		NUM_SET_0 (n);
	      else
		{
		  memmove (n->n_value + exp, n->n_value, n->n_scale);
		  memset (n->n_value, 0, exp);
		  n->n_scale += exp;
		}
	    }
	}
    }

  return (error == NUMERIC_STS_SUCCESS) ? rc : error;
}


/*
 *  Returns NULL if numeric_from_string would return an error, first significant char of the string otherwise
 */
const char *
numeric_from_string_is_ok (const char *s)
{
  const char *cp = s;
  const char *first_significant_char;
  int plain_digits = 0;
  /* strip leading whitespace */
  while (isspace (cp[0])) cp++;
  if ('$' == cp[0])
    {
      cp++;
      while (isspace (cp[0])) cp++;
    }
  first_significant_char = cp;
  /* get sign */
  if ((cp[0] == '-')|| (cp[0] == '+'))
    cp++;
  /* accept space between the sign & the digits - as M$ SQL does */
  while (isspace (cp[0]))
    cp++;
  /* handles cases for numeric_from_double */
  if (!isdigit (cp[0]) && (!stricmp (cp, "INF") || !stricmp (cp, "Infinity") || !stricmp (cp, "NaN")))
    return first_significant_char;
  while (isdigit (cp[0])) { plain_digits++; cp++; }
  if (cp[0] == '.')
    {
      cp++;
      while (isdigit (cp[0])) { plain_digits++; cp++; }
    }
  if (0 == plain_digits)
    return NULL;
  if (('E' == cp[0]) || ('e' == cp[0]))
    {
      int exp_digits = 0;
      cp++;
      if ((cp[0] == '-')|| (cp[0] == '+'))
        cp++;
      while (isdigit (cp[0])) { exp_digits++; cp++; }
      if (!exp_digits)
        return NULL;
    }
  while (isspace (cp[0])) cp++;
  if (cp[0])
    return NULL;
  return first_significant_char;
}


/*
 *  Assign an integer to a number
 */
int
numeric_from_int32 (numeric_t num, int32 val)
{
  char buffer[30];
  char *bptr, *vptr;
  int ix = 1;

  switch (val)
    {
    case -1:
      NUM_SET_1 (num);
      num->n_neg = 1;
      return NUMERIC_STS_SUCCESS;
    case 0:
      NUM_SET_0 (num);
      return NUMERIC_STS_SUCCESS;
    case 1:
      NUM_SET_1 (num);
      return NUMERIC_STS_SUCCESS;
    case ((-INT32_MAX) - 1): /* Cannot change the sign to process! */
      numeric_from_int32 (num, val+1);
      num->n_value[num->n_len-1] += 1;
      return NUMERIC_STS_SUCCESS;
    default:
      break;
    }

  /* Sign. */
  if (val < 0)
    {
      num->n_neg = 1;
      val = -val;
    }
  else
    num->n_neg = 0;

  /* Get things going. */
  bptr = buffer;
  *bptr++ = (char) (val % 10);
  val = val / 10;

  /* Extract remaining digits. */
  while (val != 0)
    {
      *bptr++ = (char) (val % 10);
      val = val / 10;
      ix++;			/* Count the digits. */
    }

  /* Make the number. */
  num->n_len = ix;
  num->n_scale = 0;
  num->n_invalid = 0;

  /* Assign the digits. */
  vptr = num->n_value;
  while (ix-- > 0)
    *vptr++ = *--bptr;

  return NUMERIC_STS_SUCCESS;
}


int
numeric_from_int64 (numeric_t num, int64 val)
{
  char buffer[30];
  char *bptr, *vptr;
  int ix = 1;

  switch (val)
    {
    case -1:
      NUM_SET_1 (num);
      num->n_neg = 1;
      return NUMERIC_STS_SUCCESS;
    case 0:
      NUM_SET_0 (num);
      return NUMERIC_STS_SUCCESS;
    case 1:
      NUM_SET_1 (num);
      return NUMERIC_STS_SUCCESS;
    case ((-INT64_MAX) - 1): /* Cannot change the sign to process! */
      numeric_from_int64 (num, val+1);
      num->n_value[num->n_len-1] += 1;
      return NUMERIC_STS_SUCCESS;
    default:
      break;
    }

  /* Sign. */
  if (val < 0)
    {
      num->n_neg = 1;
      val = -val;
    }
  else
    num->n_neg = 0;

  /* Get things going. */
  bptr = buffer;
  *bptr++ = (char) (val % 10);
  val = val / 10;

  /* Extract remaining digits. */
  while (val != 0)
    {
      *bptr++ = (char) (val % 10);
      val = val / 10;
      ix++;			/* Count the digits. */
    }

  /* Make the number. */
  num->n_len = ix;
  num->n_scale = 0;
  num->n_invalid = 0;

  /* Assign the digits. */
  vptr = num->n_value;
  while (ix-- > 0)
    *vptr++ = *--bptr;

  return NUMERIC_STS_SUCCESS;
}


/*
 *  Assign a double to a number
 */
int
numeric_from_double (numeric_t n, double d)
{
  char buffer[64];

#if defined (bsdi) || defined (__FreeBSD__) || defined (__APPLE__)
  snprintf (buffer, sizeof (buffer), "%.16g", d);
#else
  gcvt (d, 16, buffer);
#endif

  return numeric_from_string (n, buffer);
}


/*
 *  Assign a marshalled value to a number
 */
int
numeric_from_dv (numeric_t n, dtp_t *buf, int n_bytes)
{
  dtp_t *rp, *ep;
  char *dp;

  assert (buf[0] == DV_NUMERIC);

  n->n_len = buf[NDV_L] << 1;
  n->n_scale = (buf[NDV_LEN] - buf[NDV_L] - 2) << 1;
  n->n_neg = (buf[NDV_FLAGS] & NDF_NEG) ? 1 : 0;
  n->n_invalid = (buf[NDV_FLAGS] & (NDF_NAN | NDF_INF));

  dp = n->n_value;
  rp = buf + NDV_DATA;
  ep = buf + NDV_FLAGS + buf[NDV_LEN];
  if ((ep - rp) * 2 >= (int) (n_bytes - sizeof (numeric_t) + sizeof (n->n_value)))
    return NUMERIC_STS_MARSHALLING;

  if (buf[2] & NDF_LEAD0)
    {
      *dp++ = *rp++ & 0x0F;
      n->n_len--;
    }
  if (buf[NDV_FLAGS] & NDF_TRAIL0)
    n->n_scale--;

  while (rp < ep)
    {
      *dp++ = *rp >> 4;
      *dp++ = *rp++ & 0x0F;
    }

  return NUMERIC_STS_SUCCESS;
}



int
numeric_from_buf (numeric_t n, dtp_t *buf)
{
  dtp_t *rp, *ep;
  char *dp;

  buf--;
  n->n_len = buf[NDV_L] << 1;
  n->n_scale = (buf[NDV_LEN] - buf[NDV_L] - 2) << 1;
  n->n_neg = (buf[NDV_FLAGS] & NDF_NEG) ? 1 : 0;
  n->n_invalid = (buf[NDV_FLAGS] & (NDF_NAN | NDF_INF));

  dp = n->n_value;
  rp = buf + NDV_DATA;
  ep = buf + NDV_FLAGS + buf[NDV_LEN];
  if (buf[2] & NDF_LEAD0)
    {
      *dp++ = *rp++ & 0x0F;
      n->n_len--;
    }
  if (buf[NDV_FLAGS] & NDF_TRAIL0)
    n->n_scale--;
  while (rp < ep)
    {
      *dp++ = *rp >> 4;
      *dp++ = *rp++ & 0x0F;
    }

  return NUMERIC_STS_SUCCESS;
}

/*
 *  Convert a number to a string
 */
num_static int
_numeric_to_string (numeric_t n, char *str, size_t max_str, int new_prec, int new_scale)
{
  NUMERIC_VAR (buf);
  numeric_t temp;
  char *cp;
  char *nptr;
  int index;

  if (num_is_invalid (n))
    {
    failed:
      if (num_is_nan (n))
	{
	  strcpy_size_ck (str, "NaN", max_str);
	  return NUMERIC_STS_INVALID_NUM;
	}
      else if (num_is_plus_inf (n))
	{
	  strcpy_size_ck (str, "INF", max_str);
	  return NUMERIC_STS_OVERFLOW;
	}
      else
	{
	  strcpy_size_ck (str, "-INF", max_str);
	  return NUMERIC_STS_UNDERFLOW;
	}
    }

  if (new_prec)
    {
      NUMERIC_INIT (buf);
      temp = (numeric_t)buf;
      if (numeric_rescale (temp, n, NUMERIC_MAX_PRECISION,
	  NUMERIC_MAX_SCALE) != NUMERIC_STS_SUCCESS)
	{
	  goto failed;
	}
      n = temp;
    }

  /* The negative sign if needed. */
  cp = str;
  if (((size_t)(cp - str)) < max_str - 1)
    {
      if (n->n_neg)
	*cp++ = '-';
    }

  /* Load the whole number */
  nptr = n->n_value;
  if (n->n_len == 0)
    {
      if (((size_t) (cp - str)) < max_str - 1)
	*cp++ = '0';
    }
  else
    {
      for (index = n->n_len; index > 0; index--)
	{
	  if (((size_t) (cp - str)) < max_str - 1)
	    *cp++ = *nptr++ + '0';
	}
    }

  /* Now the fraction. */
  if (n->n_scale > 0)
    {
      if (((size_t) (cp - str)) < max_str - 1)
	*cp++ = '.';
      for (index = 0; index < n->n_scale; index++)
	{
	  if (((size_t) (cp - str)) < max_str - 1)
	    *cp++ = *nptr++ + '0';
	}
    }

  if (((size_t)(cp - str)) < max_str - 1)
    *cp = 0;

  return NUMERIC_STS_SUCCESS;
}


/*
 *  Convert a number to a string
 */
int
numeric_to_string (numeric_t n, char *pvalue, size_t max_pvalue)
{
  return _numeric_to_string (n, pvalue, max_pvalue,
      NUMERIC_MAX_PRECISION, NUMERIC_MAX_SCALE);
}


/*
 *  Convert a number to a 4 byte integer.
 *  The function returns only the integer part of the number.
 *  For numbers that are too large to represent as an int32, this function
 *  returns a zero.
 */
int
numeric_to_int32 (numeric_t n, int32 *pvalue)
{
  char *nptr;
  int index;
  int32 val;

  /* Extract the int value, ignore the fraction. */
  val = 0;
  nptr = n->n_value;
  for (index = n->n_len; index > 0 && val <= (INT32_MAX / 10); index--)
    val = 10 * val + *nptr++;

  /* Check for overflow.  If overflow, return zero. */
  if (index > 0)
    {
      *pvalue = 0;
      return NUMERIC_STS_MARSHALLING;
    }
  else if (val == (- INT32_MAX - 1) )
    val = -val;
  else if (val < 0)
    {
      *pvalue = 0;
      return NUMERIC_STS_MARSHALLING;
    }

  /* Return the value. */
  *pvalue = n->n_neg ? -val : val;

  return NUMERIC_STS_SUCCESS;
}


int
numeric_to_int64 (numeric_t n, int64 *pvalue)
{
  char *nptr;
  int index;
  int64 val;

  /* Extract the int value, ignore the fraction. */
  val = 0;
  nptr = n->n_value;
  for (index = n->n_len; index > 0 && val <= (INT64_MAX / 10); index--)
    val = 10 * val + *nptr++;

  /* Check for overflow.  If overflow, return zero. */
  if (index > 0)
    {
      *pvalue = 0;
      return NUMERIC_STS_MARSHALLING;
    }
  else if (val == (- INT64_MAX - 1) )
    val = -val;
  else if (val < 0)
    {
      *pvalue = 0;
      return NUMERIC_STS_MARSHALLING;
    }

  /* Return the value. */
  *pvalue = n->n_neg ? -val : val;

  return NUMERIC_STS_SUCCESS;
}


/*
 *  Convert a number to a double
 *  This assumes IEEE floats in that in truncates the scale to 15
 */
int
numeric_to_double (numeric_t n, double *pvalue)
{
  char res[NUMERIC_MAX_STRING_BYTES];
  int rc;
  res[0] = 0;
  rc = _numeric_to_string (n, res, sizeof (res), NUMERIC_MAX_PRECISION, 15);

  if (rc == NUMERIC_STS_SUCCESS)
    *pvalue = strtod (res, NULL);
  else
    {
      if ('I' == res[0])
        *pvalue = DBL_POS_INF;
      else if ('-' == res[0] && 'I' == res[1])
        *pvalue = DBL_NEG_INF;
      else if ('N' == res[0])
        *pvalue = DBL_NAN;
      else
        *pvalue = 0.0;
    }
  return rc;
}


/*
 *  Convert a number to a marshalled value
 */

int
numeric_dv_len (numeric_t n)
{
  dtp_t res[255];
  numeric_to_dv (n, res, sizeof (res));
  return 2 + res[1];
}


int
numeric_to_dv (numeric_t n, dtp_t *res, size_t reslength)
{
  int n1, n2, x1;
  char *cp, *ep;
  dtp_t *rp;

  n1 = n->n_len;
  n2 = n->n_scale;
  cp = n->n_value;
  ep = cp + n1 + n2;
  rp = res;

  /* TAG  */
  res[NDV_TAG] = DV_NUMERIC;

  /* FLAGS (Lead padding | Trail padding | Sign) */
  res[NDV_FLAGS] =
      (n->n_neg ? NDF_NEG : 0) |
      ((n1 & 1) ? NDF_LEAD0 : 0) |
      ((n2 & 1) ? NDF_TRAIL0 : 0) |
      n->n_invalid;	/* can contain NDF_NAN or NDF_INF */

  /* L (# bytes encoding digits before decimal point)
   * Note that #leading digits = 2 * L (-1 if FLAGS.L is set)
   *
   * The # bytes encoding digits after decimal point can be calculated
   * from the LENGTH and the L bytes so that the #trailing digits is:
   * 2 * (LENGTH - 2 {1 for FLAGS, 1 for L} - L) (-1 if FLAGS.T is set)
   */
  res[NDV_L] = (n1 + 1) >> 1;

  rp = res + NDV_DATA;

  /* Pad leading */
  if (n1 & 1)
    {
      *rp++ = *cp++;
      n1--;
    }

  /* Encode everything we have */
  for (x1 = n1 + n2; x1 > 0; x1 -= 2)
    {
      *rp = (cp >= ep) ? 0 : (*cp++ << 4);
      *rp++ |= (cp >= ep) ? 0 : *cp++;
    }

  /* Fix length byte */
  res[NDV_LEN] = (dtp_t) (unsigned int) (rp - res - 2);

  if (rp - res - 2 > 0xff)
    return NUMERIC_STS_MARSHALLING;

  return NUMERIC_STS_SUCCESS;
}


/*
 *  Very similar to _numeric_normalize
 *
 *  "Resizes" n from x to a new precision and a new scale.
 *  Returns NUMERIC_STS_UNDERFLOW / NUMERIC_STS_OVERFLOW on failure.
 *
 *  NOTE: new_prec here is SQL precision (n_len + n_scale)
 */
int
numeric_rescale_noround (numeric_t n, numeric_t x, int new_prec, int new_scale)
{
  char *src;

  if (num_is_invalid (x))
    return numeric_copy (n, x);

  new_prec = MAX (0, MIN (NUMERIC_MAX_PRECISION, new_prec));
  new_scale = MAX (0, MIN (NUMERIC_MAX_SCALE, new_scale));

  /* too big? */
  if (x->n_len > new_prec)
    return _numeric_inf (n, x->n_neg);

  /* adjust scale if not enough digits available */
  if (x->n_len + new_scale > new_prec + ((1 == x->n_len && 0 == x->n_value[0])?1:0))
    new_scale = new_prec - x->n_len;

  /* too much fraction? */
  if (x->n_scale > new_scale)
    {
      numeric_copy (n, x);
      n->n_scale = new_scale;
      /* Check if we have to remove trailing zeroes. */
      if (n->n_scale)
        {
          src = n->n_value + n->n_len + n->n_scale;
          while (n->n_scale > 0 && *--src == 0)
            n->n_scale--;
        }
    }
  else
    numeric_copy (n, x);

  return NUMERIC_STS_SUCCESS;
}


/*
 *  Very similar to _numeric_normalize
 *
 *  Rounds n from x to a new precision and a new scale.
 *  Returns NUMERIC_STS_UNDERFLOW / NUMERIC_STS_OVERFLOW on failure.
 *
 *  NOTE: new_prec here is SQL precision (n_len + n_scale)
 */
int
numeric_rescale (numeric_t n, numeric_t x, int new_prec, int new_scale)
{
  char *src;

  if (num_is_invalid (x))
    return numeric_copy (n, x);

  new_prec = MAX (0, MIN (NUMERIC_MAX_PRECISION, new_prec));
  new_scale = MAX (0, MIN (NUMERIC_MAX_SCALE, new_scale));

  /* too big? */
  if (x->n_len > new_prec)
    return _numeric_inf (n, x->n_neg);

  /* adjust scale if not enough digits available */
  if (x->n_len + new_scale > new_prec + ((1 == x->n_len && 0 == x->n_value[0])?1:0))
    new_scale = new_prec - x->n_len;

  /* too much fraction? */
  if (x->n_scale > new_scale)
    {
      if (x->n_value[x->n_len + new_scale] >= 5)
	{
	  /* construct .00..5 for bankers rounding */
	  NUMERIC_VAR (buf);
	  numeric_t temp;
	  NUMERIC_INIT (buf);
	  temp = (numeric_t)buf;
	  memset (temp->n_value, 0, new_scale);
	  temp->n_value[new_scale] = 5;
	  temp->n_scale = new_scale + 1;
	  temp->n_neg = x->n_neg;
	  num_add (n, x, temp, new_scale);
	  /* too big after the rounding? */
	  if (n->n_len > new_prec)
	    return _numeric_inf (n, n->n_neg);
	}
      else
	numeric_copy (n, x);
      n->n_scale = new_scale;

      /* Check if we have to remove trailing zeroes. */
      if (n->n_scale)
	{
	  src = n->n_value + n->n_len + n->n_scale;
	  while (n->n_scale > 0 && *--src == 0)
	    n->n_scale--;
	}
    }
  else
    numeric_copy (n, x);

  return NUMERIC_STS_SUCCESS;
}


/*
 *  Compare two numbers.
 *  Returns -1, 0 or 1
 */
int
numeric_compare (numeric_t n1, numeric_t n2)
{
  if (num_is_invalid (n1))
    {
      if (num_is_plus_inf (n1))
	{
	  if (num_is_plus_inf (n2))
	    return 0;
	  return +1;
	}
      if (num_is_minus_inf (n1))
	{
	  if (num_is_minus_inf (n2))
	    return 0;
	  return -1;
	}
      if (num_is_nan (n2))
	return 0;
      return +1;
    }
  else if (num_is_invalid (n2))
    {
      if (num_is_plus_inf (n2))
	return -1;
      if (num_is_minus_inf (n2))
	return +1;
      return -1;
    }

  return _num_compare_int (n1, n2, TRUE);
}


/*
 *  Calculates z = x + y
 */
int
numeric_add (numeric_t z, numeric_t x, numeric_t y)
{
  if (num_is_invalid (x))
    {
      if (num_is_plus_inf (x))
	{
	  if (num_is_minus_inf (y) || num_is_nan (y))
	    _numeric_nan (z);
	  else
	    _numeric_inf (z, 0);
	}
      else if (num_is_minus_inf (x))
	{
	  if (num_is_plus_inf (y) || num_is_nan (y))
	    _numeric_nan (z);
	  else
	    _numeric_inf (z, 1);
	}
      else
	_numeric_nan (z);
      return NUMERIC_STS_SUCCESS;
    }
  else if (num_is_invalid (y))
    {
      if (num_is_nan (y))
	_numeric_nan (z);
      else
	_numeric_inf (z, y->n_neg);
      return NUMERIC_STS_SUCCESS;
    }
  num_add (z, x, y, 0);
  return _numeric_normalize (z);
}


/*
 *  Calculates z = x - y
 */
int
numeric_subtract (numeric_t z, numeric_t x, numeric_t y)
{
  if (num_is_invalid (x))
    {
      if (num_is_plus_inf (x))
	{
	  if (num_is_plus_inf (y) || num_is_nan (y))
	    _numeric_nan (z);
	  else
	    _numeric_inf (z, 0);
	}
      else if (num_is_minus_inf (x))
	{
	  if (num_is_minus_inf (y) || num_is_nan (y))
	    _numeric_nan (z);
	  else
	    _numeric_inf (z, 1);
	}
      else
	_numeric_nan (z);
      return NUMERIC_STS_SUCCESS;
    }
  else if (num_is_invalid (y))
    {
      if (num_is_nan (y))
	_numeric_nan (z);
      else
	_numeric_inf (z, 1 - y->n_neg);
      return NUMERIC_STS_SUCCESS;
    }
  num_subtract (z, x, y, NUMERIC_MAX_SCALE_INT);
  return _numeric_normalize (z);
}


/*
 *  Calculates z = x * y
 */
int
numeric_multiply (numeric_t z, numeric_t x, numeric_t y)
{
  if (num_is_invalid (x))
    {
      if (num_is_nan (x) || num_is_nan (y))
	_numeric_nan (z);
      else
	_numeric_inf (z, x->n_neg ^ y->n_neg);
      return NUMERIC_STS_SUCCESS;
    }
  else if (num_is_invalid (y))
    {
      if (num_is_nan (y))
	_numeric_nan (z);
      else
	_numeric_inf (z, x->n_neg ^ y->n_neg);
      return NUMERIC_STS_SUCCESS;
    }
  num_multiply (z, x, y, NUMERIC_MAX_SCALE_INT);
  return _numeric_normalize (z);
}


/*
 *  Calculates z = x / y
 */
int
numeric_divide (numeric_t z, numeric_t x, numeric_t y)
{
  if (num_is_invalid (x))
    {
      if (num_is_nan (x) || num_is_invalid (y))
	_numeric_nan (z);
      else
	_numeric_inf (z, x->n_neg ^ y->n_neg);
      return NUMERIC_STS_SUCCESS;
    }
  else if (num_is_invalid (y))
    {
      if (num_is_nan (y))
	_numeric_nan (z);
      else
	NUM_SET_0 (z);
      return NUMERIC_STS_SUCCESS;
    }

  if (num_divide (z, x, y, NUMERIC_MAX_SCALE_INT) == -1)
    {
      _numeric_inf (z, x->n_neg);
      return NUMERIC_STS_DIVIDE_ZERO;
    }

  return _numeric_normalize (z);
}


/*
 *  Calculates y = 0 - x
 */
int
numeric_negate (numeric_t y, numeric_t x)
{
  if (num_is_invalid (x))
    {
      if (num_is_nan (x))
	_numeric_nan (y);
      _numeric_inf (y, 1 - x->n_neg);
      return NUMERIC_STS_SUCCESS;
    }

  numeric_copy (y, x);
  if (!num_is_zero (y))
    y->n_neg = 1 - y->n_neg;

  return NUMERIC_STS_SUCCESS;
}


#if NUMERIC_EXTS
/*
 *  Calculates z = x % y
 *  XXX does not work correctly
 */
int
numeric_modulo (numeric_t z, numeric_t x, numeric_t y)
{
  if (num_is_invalid (x) || num_is_invalid (y) ||
      num_modulo (z, x, y, NUMERIC_MAX_SCALE_INT) == -1)
    {
      _numeric_nan (z);
      return NUMERIC_STS_DIVIDE_ZERO;
    }

  return _numeric_normalize (z);
}


/*
 *  Calculates z = square_root (x)
 */
int
numeric_sqr (numeric_t z, numeric_t x)
{
  if (num_is_invalid (x))
    return numeric_copy (z, x);

  if (num_sqr (z, x, NUMERIC_MAX_SCALE_INT) == -1)
    return _numeric_nan (z);

  return _numeric_normalize (z);
}
#endif


/*
 *  Marshalls a number to an XDR stream
 */
int
numeric_serialize (numeric_t n, dk_session_t *session)
{
  dtp_t res[258];

  if (numeric_to_dv (n, res, sizeof (res)) != NUMERIC_STS_SUCCESS)
    {
      session_buffered_write_char (DV_DB_NULL, session);
      return NUMERIC_STS_MARSHALLING;
    }

  session_buffered_write (session, (char *) res, res[1] + 2);

  return NUMERIC_STS_SUCCESS;
}


/*
 *  Unmarshalls a number from an XDR stream
 */
void *
numeric_deserialize (dk_session_t *session, dtp_t macro)
{
  dtp_t res[258];
  numeric_t n;

  res[0] = DV_NUMERIC;
  res[1] = session_buffered_read_char (session);
  session_buffered_read (session, (char *) (res + 2), res[1]);

  n = numeric_allocate ();
  if (numeric_from_dv (n, res, box_length ((caddr_t) n)) != NUMERIC_STS_SUCCESS)
    numeric_from_int32 (n, 0);

  return n;
}


/*
 *  Compares two marshalled numbers
 */
int
numeric_dv_compare (dtp_t *x, dtp_t *y)
{
  dtp_t *n1, *n2;
  size_t f1, f2;
  int i;

  assert (x[0] == DV_NUMERIC);
  assert (y[0] == DV_NUMERIC);

  /* quickly compare signs */
  if (is_dv_negative (x))
    {
      if (!is_dv_negative (y))
	return -1;
    }
  else
    {
      if (is_dv_negative (y))
	return +1;
    }

  /* compare digits before decimal point */
  n1 = x + 3;	/* @ L */
  n2 = y + 3;	/* @ L */
  if ((i = memcmp (n1, n2, 1 + MIN (*n1, *n2))) != 0)
    return (i > 0) ? +1 : -1;

  /* skip leading part */
  n1 += 1 + *n1;
  n2 += 1 + *n2;

  /* compare fraction */
  f1 = x + 2 + x[1] /* LENGTH */ - n1;
  f2 = y + 2 + y[1] /* LENGTH */ - n2;
  if ((i = memcmp (n1, n2, MIN (f1, f2))) != 0)
    return (i > 0) ? +1 : -1;

  /* match - check remaining */
  if ((i = (int) (f1 - f2)) != 0)
    return (i > 0) ? +1 : -1;

  return 0;
}


int
numeric_precision (numeric_t n)
{
  int i;

  i = n->n_len + n->n_scale;
  return i ? i : 1;
}


int
numeric_raw_precision (numeric_t n)
{
  return n->n_len + n->n_scale;
}


int
numeric_scale (numeric_t n)
{
  return n->n_scale;
}


#ifdef NUMERIC_DEBUG
/*
 *  Print a number
 */
void
numeric_print (FILE *fd, char *name, numeric_t n)
{
  char res[NUMERIC_MAX_STRING_BYTES];

  if (!fd)
    fd = stderr;

  if (name)
    fprintf (fd, "%s: ", name);

  numeric_to_string (n, res, NUMERIC_MAX_STRING_BYTES);
  fprintf (fd, "%s\n", res);
}


/*
 *  Print a number with the full internal precision/scale
 */
void
numeric_debug (FILE *fd, char *name, numeric_t n)
{
  char res[NUMERIC_MAX_STRING_BYTES];

  if (name)
    fprintf (fd, "%s: ", name);

  _numeric_to_string (n, res, NUMERIC_MAX_STRING_BYTES, 0, 0);
  fprintf (fd, "%s {%d.%d} %s\n", res, n->n_len, n->n_scale,
      num_is_invalid (n) ? "NaN" : "");
}


/*
 *  Print a marshalled number
 */
void
numeric_dv_debug (FILE *fd, char *name, dtp_t *res)
{
  dtp_t *r, *ep;

  if (name)
    fprintf (fd, "%s: ", name);

  r = res;
  ep = r + res[1] + 2;
  for (; r < ep; r++)
    fprintf (fd, " %02X", *r);
  fprintf (fd, " (");
  if (res[2] & NDF_LEAD0)
    fprintf (fd, "L");
  if (res[2] & NDF_TRAIL0)
    fprintf (fd, "T");
  if (res[2] & NDF_NEG)
    fprintf (fd, "S");
  if (res[2] & NDF_NAN)
    fprintf (fd, "N");
  fprintf (fd, ")\n");
}
#endif


uint32
numeric_hash (numeric_t n)
{
  int value_bytes = n->n_len + n->n_scale;
  int inx;
  uint32 code = 0xa3e2731b;
    for (inx = 0; inx < value_bytes; inx++)
      {
	uint32 b = n->n_value[inx];
	code = (code * (b + 3 + inx)) ^ (code >> 24);
    }
  return code;
}


int
numeric_sign (numeric_t n)
{
  return (int) (n->n_neg);
}

int
numeric_to_hex_array (numeric_t n, unsigned char * arr)
{
  numeric_t cnt = NULL;
  numeric_t div256 = NULL;
  numeric_t res = NULL;
  int32 ires = 0;
  int i;

  cnt = numeric_allocate ();
  div256 = numeric_allocate ();
  res = numeric_allocate ();

  numeric_copy (cnt, n);

  cnt->n_neg = 0;
  cnt->n_len = numeric_precision (n);
  cnt->n_scale = 0;

  numeric_from_int32 (div256, 256);
  i = 0;
  for (;;)
    {
      if (-1 == numeric_compare (cnt, div256))
	{
	  numeric_to_int32 (cnt, &ires);
	  arr [i] = (unsigned char) ires;
	  i++;
	  break;
	}
      num_modulo (res, cnt, div256, 0);
      numeric_to_int32 (res, &ires);
      arr [i] = (unsigned char) ires;
      i++;
      num_divide (res, cnt, div256, 0);
      numeric_copy (cnt, res);
    }
  numeric_free (cnt);
  numeric_free (res);
  numeric_free (div256);
  return i;
}

void
numeric_from_hex_array (numeric_t n, char len, char scale, char sign,
    unsigned char * arr, int a_len)
{
  int i;
  numeric_t mul = numeric_allocate ();
  numeric_t part = numeric_allocate ();
  numeric_t m256 = numeric_allocate ();
  numeric_t z = numeric_allocate ();

  numeric_from_int32 (m256, 256);
  numeric_from_int32 (mul, 1);
  for (i = 0; i < a_len; i++)
    {
      numeric_from_int32 (part, arr[i]);
      numeric_multiply (z, part, mul);
      numeric_copy (part, z);
      numeric_add (z, n, part);
      numeric_copy (n, z);
      numeric_multiply (z, mul, m256);
      numeric_copy (mul, z);
    }
  numeric_free (z);
  numeric_free (mul);
  numeric_free (m256);
  numeric_free (part);
  n->n_len = n->n_len - scale;
  n->n_scale = scale;
  n->n_neg = sign;
}

