/*
 *  arith.c
 *
 *  $Id$
 *
 *  Arithmetic operators and comparisons.
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2016 OpenLink Software
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

#include "date.h"
#include "datesupp.h"
#include "sqlnode.h"
#include "sqlfn.h"
#include "arith.h"
#include "srvmultibyte.h"
#include "numeric.h"
#include "xmltree.h"
#include "sqlpar.h"
#include "sqlcmps.h"
#include "sqlintrp.h"


void
qst_set_long (caddr_t * state, state_slot_t * sl, boxint lv)
{
#ifdef QST_DEBUG
  if (sl->ssl_index < QI_FIRST_FREE)
    GPF_T1 ("Invalid SSL in qst_set");
  else if (sl->ssl_type == SSL_CONSTANT)
    GPF_T1 ("Invalid constant SSL in qst_set");
  else
    {
#endif
      caddr_t *place, old;
      if (SSL_VEC == sl->ssl_type)
	{
	  QNCAST (query_instance_t, qi, state);
	  dc_set_long (QST_BOX (data_col_t *, state, sl->ssl_index), qi->qi_set, lv);
	  return;
	}
      place = IS_SSL_REF_PARAMETER (sl->ssl_type) ? (caddr_t *) state[sl->ssl_index] : (caddr_t *) & state[sl->ssl_index];
      old = *place;
      if (IS_BOX_POINTER (old))
	{
	  if (DV_LONG_INT == box_tag (old))
	    {
	      *(boxint *) old = lv;
	    }
	  else
	    {
	      ssl_free_data (sl, *place);
	      *place = box_num (lv);
	    }
	}
      else
	{
	  if (IS_BOXINT_POINTER (lv))
	    *place = box_num (lv);
	  else
	    *(ptrlong *) place = lv;
	}
#ifdef QST_DEBUG
    }
#endif
}


void
qst_set_float (caddr_t * state, state_slot_t * sl, float fv)
{
#ifdef QST_DEBUG
  if (sl->ssl_index < QI_FIRST_FREE)
    GPF_T1 ("Invalid SSL in qst_set");
  else if (sl->ssl_type == SSL_CONSTANT)
    GPF_T1 ("Invalid constant SSL in qst_set");
  else
    {
#endif
      caddr_t *place;
      caddr_t old;
      if (SSL_VEC == sl->ssl_type)
	{
	  QNCAST (query_instance_t, qi, state);
	  dc_set_float (QST_BOX (data_col_t *, state, sl->ssl_index), qi->qi_set, fv);
	  return;
	}
      place = IS_SSL_REF_PARAMETER (sl->ssl_type) ? (caddr_t *) state[sl->ssl_index] : (caddr_t *) & state[sl->ssl_index];
      old = *place;
      if (IS_BOX_POINTER (old) && DV_SINGLE_FLOAT == box_tag (old))
	*(float *) old = fv;
      else
	{
	  if (old)
	    ssl_free_data (sl, *place);
	  *place = box_float (fv);
	}
#ifdef QST_DEBUG
    }
#endif
}


void
qst_set_double (caddr_t * state, state_slot_t * sl, double dv)
{
#ifdef QST_DEBUG
  if (sl->ssl_index < QI_FIRST_FREE)
    GPF_T1 ("Invalid SSL in qst_set");
  else if (sl->ssl_type == SSL_CONSTANT)
    GPF_T1 ("Invalid constant SSL in qst_set");
  else
    {
#endif
      caddr_t *place, old;
      if (SSL_VEC == sl->ssl_type)
	{
	  QNCAST (query_instance_t, qi, state);
	  dc_set_double (QST_BOX (data_col_t *, state, sl->ssl_index), qi->qi_set, dv);
	  return;
	}
      place = IS_SSL_REF_PARAMETER (sl->ssl_type) ? (caddr_t *) state[sl->ssl_index] : (caddr_t *) & state[sl->ssl_index];
      old = *place;
      if (IS_BOX_POINTER (old) && DV_DOUBLE_FLOAT == box_tag (old))
	*(double *) old = dv;
      else
	{
	  if (old)
	    ssl_free_data (sl, *place);
	  *place = box_double (dv);
	}
#ifdef QST_DEBUG
    }
#endif
}


void
qst_set_numeric_buf (caddr_t * qst, state_slot_t * sl, db_buf_t xx)
{
#ifdef QST_DEBUG
  if (sl->ssl_index < QI_FIRST_FREE)
    GPF_T1 ("Invalid SSL in qst_set");
  else if (sl->ssl_type == SSL_CONSTANT)
    GPF_T1 ("Invalid constant SSL in qst_set");
  else
    {
#endif
      caddr_t old = NULL;
      old = QST_GET (qst, sl);
      if (DV_NUMERIC != DV_TYPE_OF (old))
	old = NULL;
      if (!old)
	{
	  old = (caddr_t) numeric_allocate ();
	  numeric_from_buf ((numeric_t) old, xx);
	  qst_set (qst, sl, old);
	}
      else
	{
	  numeric_from_buf ((numeric_t) old, xx);
	}
#ifdef QST_DEBUG
    }
#endif
}


int
n_coerce (caddr_t n1, caddr_t n2, dtp_t dtp1, dtp_t dtp2, dtp_t * out_dtp)
{
  boxint tl;
  double td;
  switch (dtp1)
    {
    case DV_LONG_INT:
      {
	switch (dtp2)
	  {
	  case DV_LONG_INT:
	    *out_dtp = DV_LONG_INT;
	    return 1;
	  case DV_SINGLE_FLOAT:
	    *(float *) n1 = (float) *(boxint *) n1;
	    *out_dtp = DV_SINGLE_FLOAT;
	    return 1;
	  case DV_DOUBLE_FLOAT:
	    *(double *) n1 = (double) *(boxint *) n1;
	    *out_dtp = DV_DOUBLE_FLOAT;
	    return 1;
	  case DV_NUMERIC:
	    tl = *(boxint *) n1;
	    numeric_init_static ((numeric_t) n1, NUMERIC_STACK_BYTES);
	    numeric_from_int64 ((numeric_t) n1, (int64) tl);
	    *out_dtp = DV_NUMERIC;
	    return 1;
	  default:
	    return 0;
	  }
      }
    case DV_SINGLE_FLOAT:
      {
	switch (dtp2)
	  {
	  case DV_LONG_INT:
	    *(float *) n2 = (float) *(boxint *) n2;
	    *out_dtp = DV_SINGLE_FLOAT;
	    return 1;
	  case DV_SINGLE_FLOAT:
	    *out_dtp = DV_SINGLE_FLOAT;
	    return 1;
	  case DV_DOUBLE_FLOAT:
	    *(double *) n1 = (double) *(float *) n1;
	    *out_dtp = DV_DOUBLE_FLOAT;
	    return 1;
	  case DV_NUMERIC:
	    td = (double) (*(float *) n1);
	    numeric_init_static ((numeric_t) n1, NUMERIC_STACK_BYTES);
	    numeric_from_double ((numeric_t) n1, td);
	    *out_dtp = DV_NUMERIC;
	    return 1;
	  default:
	    return 0;
	  }
      }
    case DV_DOUBLE_FLOAT:
      {
	switch (dtp2)
	  {
	  case DV_LONG_INT:
	    *(double *) n2 = (double) *(boxint *) n2;
	    *out_dtp = DV_DOUBLE_FLOAT;
	    return 1;
	  case DV_SINGLE_FLOAT:
	    *(double *) n2 = (double) *(float *) n2;
	    *out_dtp = DV_DOUBLE_FLOAT;
	    return 1;
	  case DV_DOUBLE_FLOAT:
	    *out_dtp = DV_DOUBLE_FLOAT;
	    return 1;
	  case DV_NUMERIC:
	    td = *(double *) n1;
	    numeric_init_static ((numeric_t) n1, NUMERIC_STACK_BYTES);
	    numeric_from_double ((numeric_t) n1, td);
	    *out_dtp = DV_NUMERIC;
	    return 1;
	  default:
	    return 0;
	  }
      }
    case DV_NUMERIC:
      {
	switch (dtp2)
	  {
	  case DV_LONG_INT:
	    tl = *(boxint *) n2;
	    numeric_init_static ((numeric_t) n2, NUMERIC_STACK_BYTES);
	    numeric_from_int64 ((numeric_t) n2, (int64) tl);
	    *out_dtp = DV_NUMERIC;
	    return 1;
	  case DV_SINGLE_FLOAT:
	    td = (double) *(float *) n2;
	    numeric_init_static ((numeric_t) n2, NUMERIC_STACK_BYTES);
	    numeric_from_double ((numeric_t) n2, td);
	    *out_dtp = DV_NUMERIC;
	    return 1;
	  case DV_DOUBLE_FLOAT:
	    td = *(double *) n2;
	    numeric_init_static ((numeric_t) n2, NUMERIC_STACK_BYTES);
	    numeric_from_double ((numeric_t) n2, td);
	    *out_dtp = DV_NUMERIC;
	    return 1;
	  case DV_NUMERIC:
	    *out_dtp = DV_NUMERIC;
	    return 1;
	  default:
	    return 0;
	  }
      }
    default:
      return 0;
    }
}


dtp_t
dv_ext_to_num (dtp_t * place, caddr_t to)
{
  switch (*place)
    {
    case DV_SHORT_INT:
      *(boxint *) to = (ptrlong) (((char *) place)[1]);
      return DV_LONG_INT;
    case DV_LONG_INT:
      *(boxint *) to = LONG_REF_NA (place + 1);
      return DV_LONG_INT;
    case DV_INT64:
      *(boxint *) to = INT64_REF_NA (place + 1);
      return DV_LONG_INT;
    case DV_NULL:
      *(boxint *) to = 0;
      return DV_LONG_INT;
    case DV_SINGLE_FLOAT:
      EXT_TO_FLOAT (to, place + 1);
      return DV_SINGLE_FLOAT;
    case DV_DOUBLE_FLOAT:
      EXT_TO_DOUBLE (to, place + 1);
      return DV_DOUBLE_FLOAT;
    case DV_NUMERIC:
      numeric_init_static ((numeric_t) to, NUMERIC_STACK_BYTES);
      numeric_from_dv ((numeric_t) to, place, NUMERIC_STACK_BYTES);
      return DV_NUMERIC;
    case DV_DB_NULL:		/* Added by AK 6-MAR-1997. */
      return DV_DB_NULL;
    default:
      return 0;
    }
}


#define NUM_TO_MEM(mem, dtp, n_box) \
  if (IS_BOX_POINTER(n_box)) {\
    dtp = box_tag (n_box); \
    if (dtp == DV_RDF) { \
      n_box = ((rdf_box_t *) n_box)->rb_box; \
      if  (!IS_BOX_POINTER (n_box)) goto nonboxed##mem; \
      dtp = box_tag (n_box); \
    } \
    if (dtp == DV_LONG_INT) { \
	* (boxint*) &mem = * (boxint*) n_box; \
    } else if (dtp == DV_DOUBLE_FLOAT) \
      * (double *) &mem = * (double *) n_box; \
    else if (dtp == DV_SINGLE_FLOAT) \
      * (float *) &mem = * (float *) n_box; \
    else if (DV_NUMERIC == dtp) { \
      NUMERIC_INIT (mem); \
      numeric_copy ((numeric_t) &mem, (numeric_t) n_box); \
    } \
  } else { \
    nonboxed##mem: \
    * (boxint *)&mem = (boxint)((ptrlong)n_box); \
    dtp = DV_LONG_INT; \
  }


/*
 *  Compare two floating point numbers for equality using the formula:
 *
 *	  fabs (x1 - x2) <= neighborhood (epsilon)
 *
 *  where epsilon is either FLT_EPSILON or DBL_EPSILON (float.h) depending
 *  on the type of the original arguments.
 *
 *  This algorithm is based on:
 *
 *    Knuth, Donald E. (1998). The Art of Computer Programming.
 *    Volume 2: Seminumerical Algorithms. Third edition. Section 4.2.2,
 *    p. 233. Reading, MA: Addison-Wesley.  ISBN 0-201-89684-2.
 *
 *  and taken from the fcmp package which is LGPL.
 */
int
cmp_double (double x1, double x2, double epsilon)
{
  double difference;
  double delta;
  int exponent;

  /*
   *  Get exponent(max(fabs(x1), fabs(x2))) and store it in exponent.
   *
   *  If neither x1 nor x2 is 0,
   *  this is equivalent to max(exponent(x1), exponent(x2)).
   *
   *  If either x1 or x2 is 0, its exponent returned by frexp would be 0,
   *  which is much larger than the exponents of numbers close to 0 in
   *  magnitude. But the exponent of 0 should be less than any number
   *  whose magnitude is greater than 0.
   *
   *  So we only want to set exponent to 0 if both x1 and x2 are 0.
   *  Hence, the following works for all x1 and x2.
   */
  frexp (fabs (x1) > fabs (x2) ? x1 : x2, &exponent);

  /*
   * Scale epsilon.
   *
   * delta = epsilon * pow(2, exponent)
   *
   * Form a neighborhood around x2 of size delta in either direction.
   * If x1 is within this delta neighborhood of x2, x1 == x2.
   * Otherwise x1 > x2 or x1 < x2, depending on which side of
   * the neighborhood x1 is on.
   */
  delta = ldexp (epsilon, exponent);

  difference = x1 - x2;

  if (difference > delta)
    return DVC_GREATER;		/* x1 > x2 */
  else if (difference < -delta)
    return DVC_LESS;		/* x1 < x2 */
  else				/* -delta <= difference <= delta */
    return DVC_MATCH;		/* x1 == x2 */
}


int
numeric_compare_dvc (numeric_t x, numeric_t y)
{
  int rc = numeric_compare (x, y);
  return (rc < 0 ? DVC_LESS : rc == 0 ? DVC_MATCH : DVC_GREATER);
}


/* The following macro added by AK 6-MAR-1997 so that the comparison
   functions shall return consistent results also when another or both
   arguments are NULLs.
   Here it is supposed that NULL is equal to NULL, and everything else
   is less than NULL.
   That is, succ('\377') = NULL
 */


int
cmp_dv_box (caddr_t dv, caddr_t box)
{
  NUMERIC_VAR (dn1);
  NUMERIC_VAR (dn2);
  dtp_t dtp1 = dv_ext_to_num ((db_buf_t) dv, (caddr_t) & dn1);
  dtp_t dtp2;
  dtp_t res_dtp;

  NUM_TO_MEM (dn2, dtp2, box);

  if (dtp1 == DV_DB_NULL || dtp2 == DV_DB_NULL)
    GPF_T1 ("not supposed to be null in comparison");

  if (n_coerce ((caddr_t) & dn1, (caddr_t) & dn2, dtp1, dtp2, &res_dtp))
    {
      switch (res_dtp)
	{
	case DV_LONG_INT:
	  return (NUM_COMPARE (*(boxint *) & dn1, *(boxint *) & dn2));
	case DV_SINGLE_FLOAT:
	  return cmp_double (*(float *) &dn1, *(float *) &dn2, FLT_EPSILON);
	case DV_DOUBLE_FLOAT:
	  return cmp_double (*(double *) &dn1, *(double *) &dn2, DBL_EPSILON);
	case DV_NUMERIC:
	  return (numeric_compare_dvc ((numeric_t) & dn1, (numeric_t) & dn2));
	}
    }
  else
    sqlr_new_error ("22003", "SR082", "Non numeric comparison");
  return 0;
}


int
cmp_boxes_safe (ccaddr_t box1, ccaddr_t box2, collation_t * collation1, collation_t * collation2)
{
  int inx, n1, n2;
  NUMERIC_VAR (dn1);
  NUMERIC_VAR (dn2);
  dtp_t dtp1, dtp2, res_dtp;

  if ((IS_BOX_POINTER (box1) && DV_RDF == box_tag (box1)) || (IS_BOX_POINTER (box2) && DV_RDF == box_tag (box2)))
    return rdf_box_compare (box1, box2);

  NUM_TO_MEM (dn1, dtp1, box1);
  NUM_TO_MEM (dn2, dtp2, box2);

  if (dtp1 == DV_DB_NULL || dtp2 == DV_DB_NULL)
    return DVC_UNKNOWN;
  if (n_coerce ((caddr_t) & dn1, (caddr_t) & dn2, dtp1, dtp2, &res_dtp))
    {
      switch (res_dtp)
	{
	case DV_LONG_INT:
	  return (NUM_COMPARE (*(boxint *) & dn1, *(boxint *) & dn2));
	case DV_SINGLE_FLOAT:
	  return cmp_double (*(float *) &dn1, *(float *) &dn2, FLT_EPSILON);
	case DV_DOUBLE_FLOAT:
	  return cmp_double (*(double *) &dn1, *(double *) &dn2, DBL_EPSILON);
	case DV_NUMERIC:
	  return (numeric_compare_dvc ((numeric_t) & dn1, (numeric_t) & dn2));
	}
      GPF_T1 ("cmp_boxes(): unsupported datatype returned by n_coerce");
    }
  if (!IS_BOX_POINTER (box1) || !IS_BOX_POINTER (box2))
    return DVC_NOORDER;

  if (DV_COMPOSITE == dtp1 && DV_COMPOSITE == dtp2)
    return (dv_composite_cmp ((db_buf_t) box1, (db_buf_t) box2, collation1, 0));
  if (DV_IRI_ID == dtp1 && DV_IRI_ID == dtp2)
    return NUM_COMPARE (unbox_iri_id (box1), unbox_iri_id (box2));
  n1 = box_length (box1);
  n2 = box_length (box2);

  if ((DV_DATETIME == dtp1) || (DV_DATETIME == dtp2))
    {
      if ((dtp1 == DV_BIN) || (dtp2 == DV_BIN))
    dtp1 = dtp2 = DV_DATETIME;
      if ((DV_DATETIME == dtp1) && (DV_DATETIME == dtp2))
	return dt_compare (box1, box2, 1);
    }

  switch (dtp1)
    {
    case DV_STRING:
      n1--;
      break;
	case DV_UNAME:
	  n1--;
	  dtp1 = DV_STRING;
	  collation1 = collation2 = NULL;
	  break;
	case DV_LONG_WIDE:
	  dtp1 = DV_WIDE;
	case DV_WIDE:
	  n1 = n1 / sizeof (wchar_t) - 1;
	  break;
	case DV_LONG_BIN:
	  dtp1 = DV_BIN;
	  collation1 = collation2 = NULL;
	  break;
	case DV_DATETIME:
	  dtp1 = DV_BIN;
	  n1 = DT_COMPARE_LENGTH;
	  collation1 = collation2 = NULL;
	  break;
	default:
	  collation1 = collation2 = NULL;
	}
  switch (dtp2)
	{
    case DV_STRING:
      n2--;
      if (collation1)
	    {
	  if (collation2 && collation1 != collation2)
	    collation1 = default_collation;
	    }
	  else
	    collation1 = collation2;
	  break;
	case DV_UNAME:
	  n2--;
	  dtp2 = DV_STRING;
	  collation1 = NULL;
	  break;
	case DV_LONG_BIN:
	  dtp2 = DV_BIN;
	  collation1 = NULL;
	  break;
	case DV_DATETIME:
	  dtp2 = DV_BIN;
	  n2 = DT_COMPARE_LENGTH;
	  collation1 = NULL;
	  break;
	case DV_LONG_WIDE:
	  dtp2 = DV_WIDE;
	case DV_WIDE:
	  n2 = n2 / sizeof (wchar_t) - 1;
	  break;
	default:
	  collation1 = NULL;
	}

      if (IS_WIDE_STRING_DTP (dtp1) && IS_STRING_DTP (dtp2))
    return compare_wide_to_narrow ((wchar_t *) box1, n1, (unsigned char *) box2, n2);
      if (IS_STRING_DTP (dtp1) && IS_WIDE_STRING_DTP (dtp2))
	{
      int res = compare_wide_to_narrow ((wchar_t *) box2, n2, (unsigned char *) box1, n1);
      return (res == DVC_LESS ? DVC_GREATER : (res == DVC_GREATER ? DVC_LESS : res));
	}
      if (IS_WIDE_STRING_DTP (dtp1) && IS_WIDE_STRING_DTP (dtp2))
	{
          inx = 0;
	  while (1)
	    {
	      if (inx == n1)	/* box1 in end? */
		{
		  if (inx == n2)
		    return DVC_MATCH;  /* box2 of same length */
		  else
		    return DVC_LESS;   /* otherwise box1 is shorter than box2 */
		}

	  if (inx == n2)
	    return DVC_GREATER;	/* box2 in end (but not box1) */

	  if ((((wchar_t *) box1)[inx]) < (((wchar_t *) box2)[inx]))
	    return DVC_LESS;

	  if ((((wchar_t *) box1)[inx]) > (((wchar_t *) box2)[inx]))
	    return DVC_GREATER;

	  inx++;
	}
    }

  if ((IS_STRING_DTP (dtp1) && IS_STRING_DTP (dtp2)) || ((DV_BIN == dtp1) && (DV_BIN == dtp2)))
    {
      inx = 0;
      if (collation1)
	{
	  while (1)
	    {
	      wchar_t xlat1, xlat2;
	      if (inx == n1)	/* box1 in end? */
		{
		  if (inx == n2)
		    return DVC_MATCH;	/* box2 of same length */
		  else
		    return DVC_LESS;	/* otherwise box1 is shorter than box2 */
		}
	      if (inx == n2)
		return DVC_GREATER;	/* box2 in end (but not box1) */
              xlat1 = COLLATION_XLAT_NARROW (collation1, (dtp_t) box1[inx]);
              xlat2 = COLLATION_XLAT_NARROW (collation1, (dtp_t) box2[inx]);
              if (xlat1 < xlat2)
                return DVC_LESS;
              if (xlat1 > xlat2)
                return DVC_GREATER;
	      inx++;
	    }
	}
      else
	{
	  while (1)
	    {
	      if (inx == n1)	/* box1 in end? */
		{
		  if (inx == n2)
		    return DVC_MATCH;	/* box2 of same length */
		  else
		    return DVC_LESS;	/* otherwise box1 is shorter than box2 */
		}

	      if (inx == n2)
		return DVC_GREATER;	/* box2 in end (but not box1) */

	      if (((dtp_t) box1[inx]) < ((dtp_t) box2[inx]))
		return DVC_LESS;

	      if (((dtp_t) box1[inx]) > ((dtp_t) box2[inx]))
		return DVC_GREATER;

	      inx++;
	    }
	}
    }
  if ((DV_REFERENCE == dtp1) && (DV_REFERENCE == dtp2))
    {
      if (box1 == box2)
	return DVC_MATCH;
      return DVC_NOORDER;
    }
  if ((DV_XML_ENTITY == dtp1) && (DV_XML_ENTITY == dtp2))
    {
      if (box1 == box2)
	return DVC_MATCH;
      return xe_compare_content ((xml_entity_t *) box1, (xml_entity_t *) box2, 0 /* do not compare URIs and DTDs */ );
    }
  return DVC_NOORDER;
}


#ifdef CMP_MOREDEBUG
int
cmp_boxes_old (ccaddr_t box1, ccaddr_t box2, collation_t * collation1, collation_t * collation2)
#else
int
cmp_boxes (ccaddr_t box1, ccaddr_t box2, collation_t * collation1, collation_t * collation2)
#endif
{
  NUMERIC_VAR (dn1);
  NUMERIC_VAR (dn2);
  dtp_t dtp1, dtp2, res_dtp;

  if ((IS_BOX_POINTER (box1) && DV_RDF == box_tag (box1)) || (IS_BOX_POINTER (box2) && DV_RDF == box_tag (box2)))
    return rdf_box_compare (box1, box2);

  NUM_TO_MEM (dn1, dtp1, box1);
  NUM_TO_MEM (dn2, dtp2, box2);

  if (dtp1 == DV_DB_NULL || dtp2 == DV_DB_NULL)
    return DVC_UNKNOWN;
  if (n_coerce ((caddr_t) & dn1, (caddr_t) & dn2, dtp1, dtp2, &res_dtp))
    {
      switch (res_dtp)
	{
	case DV_LONG_INT:
	  return (NUM_COMPARE (*(boxint *) & dn1, *(boxint *) & dn2));
	case DV_SINGLE_FLOAT:
	  return cmp_double (*(float *) &dn1, *(float *) &dn2, FLT_EPSILON);
	case DV_DOUBLE_FLOAT:
	  return cmp_double (*(double *) &dn1, *(double *) &dn2, DBL_EPSILON);
	case DV_NUMERIC:
	  return (numeric_compare_dvc ((numeric_t) & dn1, (numeric_t) & dn2));
	}
    }
  else
    {
      int inx = 0, n1, n2;

      if (!IS_BOX_POINTER (box1) || !IS_BOX_POINTER (box2))
	return DVC_LESS;

      if (DV_COMPOSITE == dtp1 && DV_COMPOSITE == dtp2)
	return (dv_composite_cmp ((db_buf_t) box1, (db_buf_t) box2, collation1, 0));
      if (DV_IRI_ID == dtp1 && DV_IRI_ID == dtp2)
	return NUM_COMPARE (unbox_iri_id (box1), unbox_iri_id (box2));
      n1 = box_length (box1);
      n2 = box_length (box2);

      if ((DV_DATETIME == dtp1) || (DV_DATETIME == dtp2))
	{
	  if ((dtp1 == DV_BIN) || (dtp2 == DV_BIN))
	dtp1 = dtp2 = DV_DATETIME;
	  if ((DV_DATETIME == dtp1) && (DV_DATETIME == dtp2))
	    return dt_compare (box1, box2, 0);
	}

      switch (dtp1)
	{
	case DV_STRING:
	  n1--;
	  break;
	case DV_UNAME:
	  n1--;
	  dtp1 = DV_STRING;
	  collation1 = collation2 = NULL;
	  break;
	case DV_LONG_WIDE:
	  dtp1 = DV_WIDE;
	case DV_WIDE:
	  n1 = n1 / sizeof (wchar_t) - 1;
	  break;
	case DV_LONG_BIN:
	  dtp1 = DV_BIN;
	  collation1 = collation2 = NULL;
	  break;
	case DV_DATETIME:
	  dtp1 = DV_BIN;
	  n1 = DT_COMPARE_LENGTH;
	  collation1 = collation2 = NULL;
	  break;
	default:
	  collation1 = collation2 = NULL;
	}
      switch (dtp2)
	{
	case DV_STRING:
	  n2--;
	  if (collation1)
	    {
	      if (collation2 && collation1 != collation2)
		collation1 = default_collation;
	    }
	  else
	    collation1 = collation2;
	  break;
	case DV_UNAME:
	  n2--;
	  dtp2 = DV_STRING;
	  collation1 = NULL;
	  break;
	case DV_LONG_BIN:
	  dtp2 = DV_BIN;
	  collation1 = NULL;
	  break;
	case DV_DATETIME:
	  dtp2 = DV_BIN;
	  n2 = DT_COMPARE_LENGTH;
	  collation1 = NULL;
	  break;
	case DV_LONG_WIDE:
	  dtp2 = DV_WIDE;
	case DV_WIDE:
	  n2 = n2 / sizeof (wchar_t) - 1;
	  break;
	default:
	  collation1 = NULL;
	}

      if (IS_WIDE_STRING_DTP (dtp1) && IS_STRING_DTP (dtp2))
	return compare_wide_to_narrow ((wchar_t *) box1, n1, (unsigned char *) box2, n2);
      else if (IS_STRING_DTP (dtp1) && IS_WIDE_STRING_DTP (dtp2))
	{
	  int res = compare_wide_to_narrow ((wchar_t *) box2, n2, (unsigned char *) box1, n1);
	  return (res == DVC_LESS ? DVC_GREATER : (res == DVC_GREATER ? DVC_LESS : res));
	}
      else if (dtp1 != dtp2)
	return DVC_LESS;

      if (dtp1 == DV_WIDE)
	{
	  while (1)
	    {
	      if (inx == n1)	/* box1 in end? */
		{
		  if (inx == n2)
		    return DVC_MATCH;	/* box2 of same length */
		  else
		    return DVC_LESS;	/* otherwise box1 is shorter than box2 */
		}

	      if (inx == n2)
		return DVC_GREATER;	/* box2 in end (but not box1) */

	      if ((((wchar_t *) box1)[inx]) < (((wchar_t *) box2)[inx]))
		return DVC_LESS;

	      if ((((wchar_t *) box1)[inx]) > (((wchar_t *) box2)[inx]))
		return DVC_GREATER;

	      inx++;
	    }
	}

      if (collation1)
	{
	  while (1)
	    {
	      wchar_t xlat1, xlat2;
	      if (inx == n1)	/* box1 in end? */
		{
		  if (inx == n2)
		    return DVC_MATCH;	/* box2 of same length */
		  else
		    return DVC_LESS;	/* otherwise box1 is shorter than box2 */
		}

	      if (inx == n2)
		return DVC_GREATER;	/* box2 in end (but not box1) */
              xlat1 = COLLATION_XLAT_NARROW (collation1, (dtp_t) box1[inx]);
              xlat2 = COLLATION_XLAT_NARROW (collation1, (dtp_t) box2[inx]);
              if (xlat1 < xlat2)
                return DVC_LESS;
              if (xlat1 > xlat2)
                return DVC_GREATER;
	      inx++;
	    }
	}
      else
	{
	  while (1)
	    {
	      if (inx == n1)	/* box1 in end? */
		{
		  if (inx == n2)
		    return DVC_MATCH;	/* box2 of same length */
		  else
		    return DVC_LESS;	/* otherwise box1 is shorter than box2 */
		}

	      if (inx == n2)
		return DVC_GREATER;	/* box2 in end (but not box1) */

	      if (((dtp_t) box1[inx]) < ((dtp_t) box2[inx]))
		return DVC_LESS;

	      if (((dtp_t) box1[inx]) > ((dtp_t) box2[inx]))
		return DVC_GREATER;

	      inx++;
	    }
	}
    }
  return DVC_LESS;		/* default, should not happen */
}


#ifdef CMP_MOREDEBUG
int
cmp_boxes (ccaddr_t box1, ccaddr_t box2, collation_t * collation1, collation_t * collation2)
{
  int res_safe = cmp_boxes_safe (box1, box2, collation1, collation2);
  int res_old = cmp_boxes_old (box1, box2, collation1, collation2);
  if (res_safe != res_old)
    {
      fprintf (stderr, "\n%s:%d\n*** cmp_box error: now it is %d, safe is %d: ", __FILE__, __LINE__, res_old, res_safe);
      dbg_print_box (box1, stderr);
      fprintf (stderr, ", ");
      dbg_print_box (box2, stderr);
      fprintf (stderr, "\n");
    }
  return res_old;
}
#endif

typedef int (*numeric_bop_t) (numeric_t z, numeric_t x, numeric_t y);


caddr_t
numeric_bin_op (numeric_bop_t num_op, numeric_t x, numeric_t y, caddr_t * qst, state_slot_t * target)
{
  int rc;
  caddr_t res_box = NULL;
  if (target)
    {
      if (SSL_VEC == target->ssl_type)
	{
	  data_col_t *dc = QST_BOX (data_col_t *, qst, target->ssl_index);
	  if (DCT_BOXES & dc->dc_type && ((QI *) qst)->qi_set < dc->dc_n_values)
	    res_box = ((caddr_t *) dc->dc_values)[((QI *) qst)->qi_set];
	}
      else
	res_box = QST_GET (qst, target);
      if (DV_NUMERIC == DV_TYPE_OF (res_box))
	{
	  rc = num_op ((numeric_t) res_box, x, y);
	}
      else
	{
	  res_box = (caddr_t) numeric_allocate ();
	  rc = num_op ((numeric_t) res_box, x, y);
	  qst_set (qst, target, res_box);
	}
    }
  else
    {
      res_box = (caddr_t) numeric_allocate ();
      rc = num_op ((numeric_t) res_box, x, y);
    }
  if (rc != NUMERIC_STS_SUCCESS)
    {
      char state[10];
      char msg[200];
      numeric_error (rc, state, sizeof (state), msg, sizeof (msg));
      sqlr_new_error (state, "SR083", "%s", msg);
    }
  return res_box;
}

#define ARTM_BIN_FUNC(name, opsymbol, op, num_op, dt_op, isdiv) \
caddr_t \
name (ccaddr_t box1, ccaddr_t box2, caddr_t * qst, state_slot_t * target) \
{ \
  NUMERIC_VAR (dn1); \
  NUMERIC_VAR (dn2); \
  dtp_t dtp1, dtp2, res_dtp; \
retry_rdf_boxes: \
  NUM_TO_MEM (dn1, dtp1, box1); \
  NUM_TO_MEM (dn2, dtp2, box2); \
  if (DV_LONG_INT == dtp1 && dtp1 == dtp2) \
    goto int_case; \
  if (dtp1 == DV_DB_NULL || dtp2 == DV_DB_NULL) \
    goto null_result; \
  if (n_coerce ((caddr_t) & dn1, (caddr_t) & dn2, \
	  dtp1, dtp2, &res_dtp)) \
    { \
      switch (res_dtp) \
	{ \
	case DV_LONG_INT: \
	int_case: \
	  if (isdiv && 0 == *(boxint *) &dn2) \
	    sqlr_new_error ("22012", "SR084", "Division by 0."); \
	  if (target) \
	    return (qst_set_long (qst, target, \
		(*(boxint *) &dn1 op * (boxint *) &dn2)), (caddr_t) 0); \
	  return (box_num (*(boxint *) &dn1 op * (boxint *) &dn2)); \
	case DV_SINGLE_FLOAT: \
	  if (isdiv && 0 == *(float *) &dn2) \
	    sqlr_new_error ("22012", "SR085", "Division by 0."); \
	  if (target) \
	    return (qst_set_float (qst, target, \
		(*(float *) &dn1 op * (float *) &dn2)), (caddr_t) 0); \
	  return (box_float (*(float *) &dn1 op * (float *) &dn2)); \
	case DV_DOUBLE_FLOAT: \
	  if (isdiv && 0 == *(double*) &dn2) \
	    sqlr_new_error ("22012", "SR086", "Division by 0."); \
	  if (target) \
	    return (qst_set_double (qst, target, (*(double*) &dn1 op *(double*) &dn2)), (caddr_t) 0); \
	  return (box_double (*(double*) &dn1 op *(double*) &dn2)); \
	case DV_NUMERIC: \
	  return (numeric_bin_op (num_op, (numeric_t) &dn1, (numeric_t) &dn2, qst, target)); \
	} \
    } \
  else \
    { \
      if (dtp1 == DV_RDF || dtp2 == DV_RDF) \
        { \
          if (dtp1 == DV_RDF) \
            box1 = ((rdf_box_t *)(box1))->rb_box; \
          if (dtp2 == DV_RDF) \
            box2 = ((rdf_box_t *)(box2))->rb_box; \
          goto retry_rdf_boxes; \
        } \
      if ((NULL != dt_op) && ((DV_DATETIME == dtp1) || (DV_DATETIME == dtp2))) \
        { \
          caddr_t err = NULL; \
          caddr_t res = ((arithm_dt_operation_t *)(dt_op)) (box1, box2, &err); \
          if (NULL == err) \
            { \
              if (target) \
                return (qst_set (qst, target, res), (caddr_t)0); \
              return res; \
            } \
          if (((query_instance_t *)qst)->qi_query->qr_no_cast_error) \
            { \
              dk_free_tree (err); \
              goto null_result; \
            } \
          sqlr_resignal (err); \
        } \
      if (((query_instance_t *)qst)->qi_query->qr_no_cast_error) \
        goto null_result; \
      sqlr_new_error ("22003", "SR087", "Non numeric argument(s) to arithmetic operation '%s'.", opsymbol); \
    } \
null_result: \
  if (target) \
    { \
      qst_set_null (qst, target); \
      return NULL; \
    } \
  return (dk_alloc_box (0, DV_DB_NULL)); \
}

/* equal to ARTM_BIN_FUNC (box_mod, %, numeric_modulo, 1) with some extensions */
caddr_t
box_mod (ccaddr_t box1, ccaddr_t box2, caddr_t * qst, state_slot_t * target)
{
  NUMERIC_VAR (dn1);
  NUMERIC_VAR (dn2);
  dtp_t dtp1, dtp2, res_dtp;
retry_rdf_boxes:
  NUM_TO_MEM (dn1, dtp1, box1);
  NUM_TO_MEM (dn2, dtp2, box2);
  if (dtp1 == DV_DB_NULL || dtp2 == DV_DB_NULL)
    goto null_result;
  if (n_coerce ((caddr_t) & dn1, (caddr_t) & dn2, dtp1, dtp2, &res_dtp))
    {
      switch (res_dtp)
	{
	case DV_LONG_INT:
	  if (0 == *(boxint *) & dn2)
	    sqlr_new_error ("22012", "SR088", "Division by 0.");
	  if (target)
	    return (qst_set_long (qst, target, (*(boxint *) & dn1 % *(boxint *) & dn2)), (caddr_t) 0);
	  return (box_num (*(boxint *) & dn1 % *(boxint *) & dn2));
	case DV_SINGLE_FLOAT:
	  if (0 == *(float *) &dn2)
	    sqlr_new_error ("22012", "SR089", "Division by 0.");
	  if (target)
	    return (qst_set_float (qst, target, (float) fmod (*(float *) &dn1, *(float *) &dn2)), (caddr_t) 0);
	  return (box_float ((float) fmod (*(float *) &dn1, *(float *) &dn2)));
	case DV_DOUBLE_FLOAT:
	  if (0 == *(double *) &dn2)
	    sqlr_new_error ("22012", "SR090", "Division by 0.");
	  if (target)
	    return (qst_set_double (qst, target, fmod (*(double *) &dn1, *(double *) &dn2)), (caddr_t) 0);
	  return (box_double (fmod (*(double *) &dn1, *(double *) &dn2)));
	case DV_NUMERIC:
	  return (numeric_bin_op (numeric_modulo, (numeric_t) & dn1, (numeric_t) & dn2, qst, target));
	}
    }
  else
    {
      if (dtp1 == DV_RDF || dtp2 == DV_RDF)
	{
	  if (dtp1 == DV_RDF)
	    box1 = ((rdf_box_t *) (box1))->rb_box;
	  if (dtp2 == DV_RDF)
	    box2 = ((rdf_box_t *) (box2))->rb_box;
	  goto retry_rdf_boxes;
	}
      if (((query_instance_t *) qst)->qi_query->qr_no_cast_error)
	goto null_result;	/* see below */
      sqlr_new_error ("22003", "SR087", "Non numeric arguments to arithmetic operation modulo");
    }
null_result:
  if (target)
    {
      qst_set_bin_string (qst, target, NULL, 0, DV_DB_NULL);
      return NULL;
    }
  return (dk_alloc_box (0, DV_DB_NULL));
}

ARTM_BIN_FUNC (box_add, "+", +, numeric_add		, arithm_dt_add		, 0)
ARTM_BIN_FUNC (box_sub, "-", -, numeric_subtract	, arithm_dt_subtract	, 0)
ARTM_BIN_FUNC (box_mpy, "*", *, numeric_multiply	, NULL			, 0)
ARTM_BIN_FUNC (box_div, "/", /, numeric_divide		, NULL			, 1)


caddr_t
box_identity (ccaddr_t arg, ccaddr_t ignore, caddr_t * qst, state_slot_t * target)
{
  if (target)
    {
      if (IS_BOX_POINTER (arg))
	qst_set (qst, target, box_copy_tree (arg));
      else
	qst_set_long (qst, target, (ptrlong) arg);
      return NULL;
    }
  return (box_copy_tree (arg));
}


/* Comparison rules for numbers in any collation index:
  The cases are:

  int64, double  - if double has no fract and is in 53 bit int range, compare as int.  Else as double and if they look eq as doubles then int is farther from 0.
int64, decimal -  compare as decimal.
decimal, double - if dec has more than 15 digits and not between min and max 53 bit, dec is farther from 0 if dec and double look equal as doubles.

Operands of the same type compare natively.
*/

#if defined(WIN32) || defined (SOLARIS)
double
trunc (double x)
{
  if (x >= 0)
    return floor (x);
  else
    return ceil (x);
}
#endif


int
dvc_int_double (int64 i, double d)
{
  /* if double is in range where int cast is precise and has zero fraction, it is equal to int.
   * if out of int range, double is opso facto lt or gt.
   * if double is in imprecise int range (1<<53 - 1<<64 -1) and the int cast to double is equal to the double, then the int is seen as farther from zero. */
  int r;
  if (d > MIN_INT_DOUBLE && d < MAX_INT_DOUBLE && trunc (d) == d)
    {
      int64 i2 = (int64) d;
      return NUM_COMPARE (i, i2);
    }
  if (d > -1 && d < 1)
    return NUM_COMPARE (((double) i), d);
  r = NUM_COMPARE ((double) i, d);
  if (DVC_MATCH == r)
    {
      /* if int and double look like eq and the double is outside the int precise int range, then the int is seen as farther from zero */
      if (d > 0)
	return DVC_GREATER;
      return DVC_LESS;
    }
  return r;
}


int
dvc_num_double (numeric_t num1, double d2)
{
  double d1;
  if (d2 > MIN_INT_DOUBLE && d2 < MAX_INT_DOUBLE && trunc (d2) == d2)
    {
      NUMERIC_VAR (num2);
      numeric_from_double ((numeric_t) num2, d2);
      return numeric_compare_dvc ((numeric_t) num1, (numeric_t) num2);
    }
  numeric_to_double (num1, &d1);
  if (d1 == d2)
    {
      if (d2 > MIN_INT_DOUBLE && d2 < MAX_INT_DOUBLE)
	{
	  NUMERIC_VAR (num2);
	  numeric_from_double (num2, d2);
	  return numeric_compare_dvc ((numeric_t) num1, (numeric_t) num2);
	}
      if (num1->n_len + num1->n_scale <= 15)
	return DVC_MATCH;
      if (0 < d2)
	return DVC_GREATER;
      else
	return DVC_LESS;
    }
  if (d1 < d2)
    return DVC_LESS;
  return DVC_GREATER;
}


int
dvc_int_num (int64 i, numeric_t n2)
{
  NUMERIC_VAR (n1);
  numeric_from_int64 ((numeric_t) n1, i);
  return numeric_compare_dvc ((numeric_t) n1, (numeric_t) n2);
}


#define REV(x) \
  { \
    int __r = x; \
    return __r == DVC_LESS ? DVC_GREATER : (__r == DVC_MATCH ? DVC_MATCH : DVC_LESS); \
  }


int
dv_num_compare (numeric_t dn1, numeric_t dn2, dtp_t dtp1, dtp_t dtp2)
{
  if (DV_SINGLE_FLOAT == dtp1)
    {
      *(double *) dn1 = *(float *) dn1;
      dtp1 = DV_DOUBLE_FLOAT;
    }
  if (DV_SINGLE_FLOAT == dtp2)
    {
      *(double *) dn2 = *(float *) dn2;
      dtp2 = DV_DOUBLE_FLOAT;
    }

  if (dtp1 == dtp2)
    {
      switch (dtp1)
	{
	case DV_LONG_INT:
	  return NUM_COMPARE (*(int64 *) dn1, *(int64 *) dn2);
	case DV_DOUBLE_FLOAT:
	  return NUM_COMPARE (*(double *) dn1, *(double *) dn2);
	case DV_NUMERIC:
	  return (numeric_compare_dvc ((numeric_t) dn1, (numeric_t) dn2));
	default:
	  GPF_T;		/* Impossible num type combination */
	}
    }
  switch (dtp1)
    {
    case DV_LONG_INT:
      switch (dtp2)
	{
	case DV_NUMERIC:
	  return dvc_int_num (*(int64 *) dn1, dn2);
	case DV_DOUBLE_FLOAT:
	  return dvc_int_double (*(int64 *) dn1, *(double *) dn2);
	default:
	  GPF_T1 ("bad num compare combination");
	}
    case DV_DOUBLE_FLOAT:
      switch (dtp2)
	{
	case DV_LONG_INT:
	  REV (dvc_int_double (*(int64 *) dn2, *(double *) dn1));
	case DV_NUMERIC:
	  REV (dvc_num_double (dn2, *(double *) dn1));
	default:
	  GPF_T1 ("bad num compare combination");
	}
    case DV_NUMERIC:
      switch (dtp2)
	{
	case DV_LONG_INT:
	  REV (dvc_int_num (*(int64 *) dn2, (numeric_t) dn1));
	case DV_DOUBLE_FLOAT:
	  return dvc_num_double ((numeric_t) dn1, *(double *) dn2);
	default:
	  GPF_T1 ("bad num compare combination");
	}
    default:
      GPF_T1 ("bad num compare combination");
    }
  return 0;
}

/* type specific vectored ops */


#include "simd.h"
#include "date.h"


void
artm_const_cast (double *target, dtp_t target_dtp, caddr_t c, int n, auto_pool_t * ap, caddr_t * allocd_ret)
{
  int inx;
  dtp_t dtp = DV_TYPE_OF (c);
  switch (target_dtp)
    {
    case DV_DOUBLE_FLOAT:
      {
	double dc;
	switch (dtp)
	  {
	  case DV_LONG_INT:
	    dc = (double) unbox_inline (c);
	    break;
	  case DV_SINGLE_FLOAT:
	    dc = (double) unbox_float (c);
	    break;
	  case DV_DOUBLE_FLOAT:
	    dc = unbox_double (c);
	    break;
	  case DV_NUMERIC:
	    numeric_to_double ((numeric_t) c, &dc);
	    break;
	  }
	for (inx = 0; inx < n; inx++)
	  target[inx] = dc;
	break;
      }
    case DV_SINGLE_FLOAT:
      {
	float dc;
	switch (dtp)
	  {
	  case DV_LONG_INT:
	    dc = (float) unbox_inline (c);
	    break;
	  case DV_SINGLE_FLOAT:
	    dc = (double) unbox_float (c);
	    break;
	  }
	for (inx = 0; inx < n; inx++)
	  ((float *) target)[inx] = dc;
	break;
      }
    case DV_LONG_INT:
      {
	int64 dc;
	switch (dtp)
	  {
	  case DV_LONG_INT:
	    dc = unbox_inline (c);
	    break;
	  default:
	    GPF_T1 ("should not cast down in artmm");
	  }
	for (inx = 0; inx < n; inx++)
	  ((int64 *) target)[inx] = dc;
	break;
      }
    case DV_DATETIME:
      {
	for (inx = 0; inx < n; inx++)
	  {
	    db_buf_t tgt = ((db_buf_t)target) + DT_LENGTH * inx;
	    memcpy_dt (tgt, c);
	  }
	break;
      }
    case DV_ANY:
      {
	caddr_t err = NULL;
	caddr_t xx = box_to_any_1 (c, &err, ap, DKS_TO_DC);
	*allocd_ret = xx;
	for (inx = 0; inx < n; inx++)
	  ((caddr_t *) target)[inx] = xx;
      }
    }
}


typedef void (*dc_artm_cast_t) (double *target, data_col_t * dc, int *sets, int first_set, int n);


void
artm_float_to_double (double *target, data_col_t * dc, int *sets, int first_set, int n)
{
  int inx, fill = 0;
  if (sets)
    {
      for (inx = 0; inx < n; inx++)
	target[fill++] = (double) ((float *) dc->dc_values)[sets[inx]];
    }
  else
    {
      n += first_set;
      for (inx = first_set; inx < n; inx++)
	target[fill++] = (double) ((float *) dc->dc_values)[inx];
    }
}


void
artm_int_to_int (double *target, data_col_t * dc, int *sets, int first_set, int n)
{
  int inx, fill = 0;
  if (sets)
    {
      for (inx = 0; inx < n; inx++)
	((int64 *) target)[fill++] = ((int64 *) dc->dc_values)[sets[inx]];
    }
  else
    GPF_T1 ("int to int cast with no sslr");
}


void
artm_date_to_date (double *target, data_col_t * dc, int *sets, int first_set, int n)
{
  int inx, fill = 0;
  if (sets)
    {
      db_buf_t tgt = ((db_buf_t) target);
      for (inx = 0; inx < n; inx++)
	{
	  db_buf_t src = ((db_buf_t) dc->dc_values) + DT_LENGTH * sets[inx];
	  memcpy_dt (tgt, src);
	  tgt += DT_LENGTH;
	}
    }
  else
    GPF_T1 ("int to int cast with no sslr");
}

void
artm_float_to_float (double *target, data_col_t * dc, int *sets, int first_set, int n)
{
  int inx, fill = 0;
  if (sets)
    {
      for (inx = 0; inx < n; inx++)
	((float *) target)[fill++] = ((float *) dc->dc_values)[sets[inx]];
    }
  else
    GPF_T1 ("int to int cast with no sslr");
}

void
artm_int_to_double (double *target, data_col_t * dc, int *sets, int first_set, int n)
{
  int inx, fill = 0;
  if (sets)
    {
      for (inx = 0; inx < n; inx++)
	target[fill++] = (double) ((int64 *) dc->dc_values)[sets[inx]];
    }
  else
    {
      n += first_set;
      for (inx = first_set; inx < n; inx++)
	target[fill++] = (double) ((int64 *) dc->dc_values)[inx];
    }
}


void
artm_int_to_float (double *target, data_col_t * dc, int *sets, int first_set, int n)
{
  int inx, fill = 0;
  if (sets)
    {
      for (inx = 0; inx < n; inx++)
	((float *) target)[fill++] = (float) ((int64 *) dc->dc_values)[sets[inx]];
    }
  else
    {
      n += first_set;
      for (inx = first_set; inx < n; inx++)
	((float *) target)[fill++] = (float) ((int64 *) dc->dc_values)[inx];
    }
}


dtp_t
ssl_artm_dtp (caddr_t * inst, state_slot_t * ssl)
{
  dtp_t dtp;
  if (SSL_CONSTANT == ssl->ssl_type)
    dtp = DV_TYPE_OF (ssl->ssl_constant);
  else if (SSL_VEC == ssl->ssl_type || SSL_REF == ssl->ssl_type)
    {
      data_col_t *dc = QST_BOX (data_col_t *, inst, ssl->ssl_index);
      if (dc->dc_any_null || !(DCT_NUM_INLINE & dc->dc_type))
	return DV_ANY;
      return dc->dc_dtp;
    }
  else
    {
      caddr_t d = qst_get (inst, ssl);
      dtp = DV_TYPE_OF (d);
    }
  if (DV_LONG_INT == dtp || DV_SINGLE_FLOAT == dtp || DV_DOUBLE_FLOAT == dtp)
    return dtp;
  return DV_ANY;
}

dtp_t
ssl_cmp_dtp (caddr_t * inst, state_slot_t * ssl)
{
  dtp_t dtp;
  if (SSL_CONSTANT == ssl->ssl_type)
    dtp = DV_TYPE_OF (ssl->ssl_constant);
  else if (SSL_VEC == ssl->ssl_type || SSL_REF == ssl->ssl_type)
    {
      data_col_t * dc = QST_BOX (data_col_t *, inst, ssl->ssl_index);
      if ((DCT_BOXES & dc->dc_type) || dc->dc_any_null)
	return DV_ARRAY_OF_POINTER;
      return dc->dc_dtp;
    }
  else 
    {
      caddr_t d = qst_get (inst, ssl);
      dtp = DV_TYPE_OF (d);
    }
  if (DV_LONG_INT == dtp || DV_SINGLE_FLOAT == dtp || DV_DOUBLE_FLOAT == dtp || DV_DATETIME == dtp)
    return dtp;
  if (vec_box_dtps[dtp])
    return DV_ARRAY_OF_POINTER;
  return DV_ANY;
}


#define ACF(target, source)  (target << 8 | source)


dc_artm_cast_t
dc_artm_cast_f (dtp_t target_dtp, dtp_t source_dtp)
{
  switch (ACF (target_dtp, source_dtp))
    {
    case ACF (DV_SINGLE_FLOAT, DV_LONG_INT):
      return artm_int_to_float;
    case ACF (DV_DOUBLE_FLOAT, DV_LONG_INT):
      return artm_int_to_double;
    case ACF (DV_DOUBLE_FLOAT, DV_SINGLE_FLOAT):
      return artm_float_to_double;
#if 8 == SIZEOF_CHAR_P
    case ACF (DV_ANY, DV_ANY):
#endif
    case ACF (DV_LONG_INT, DV_LONG_INT):
    case ACF (DV_DOUBLE_FLOAT, DV_DOUBLE_FLOAT):
      return artm_int_to_int;
#if 4 == SIZEOF_CHAR_P
    case ACF (DV_ANY, DV_ANY):
#endif
    case ACF (DV_SINGLE_FLOAT, DV_SINGLE_FLOAT):
      return artm_float_to_float;
    case ACF (DV_DATETIME, DV_DATETIME):
      return artm_date_to_date;
    }
  return NULL;
}


int64 *
ssl_artm_param (caddr_t * inst, state_slot_t * ssl, int64 * target, dtp_t target_dtp, int set, int n_sets, auto_pool_t * ap,
    caddr_t * allocd_ret)
{
  dc_artm_cast_t f;
  if (SSL_VEC == ssl->ssl_type)
    {
      data_col_t *dc = QST_BOX (data_col_t *, inst, ssl->ssl_index);
      if (target_dtp == dc->dc_dtp)
	{
	  if (DV_SINGLE_FLOAT == target_dtp)
	    return (int64 *) & ((float *) dc->dc_values)[set];
	  if (DV_DATETIME == target_dtp)
	    return (int64 *) (((db_buf_t) dc->dc_values) + DT_LENGTH * set);
	  return &((int64 *) dc->dc_values)[set];
	}
      f = dc_artm_cast_f (target_dtp, dc->dc_dtp);
      f ((double *) target, dc, NULL, set, n_sets);
      return target;
    }
  if (SSL_REF == ssl->ssl_type)
    {
      data_col_t *dc = QST_BOX (data_col_t *, inst, ssl->ssl_index);
      int sets[ARTM_VEC_LEN];
      sslr_n_consec_ref (inst, (state_slot_ref_t *) ssl, sets, set, n_sets);
      f = dc_artm_cast_f (target_dtp, dc->dc_dtp);
      f ((double *) target, dc, sets, 0, n_sets);
      return target;
    }
  artm_const_cast ((double *) target, target_dtp, qst_get (inst, ssl), n_sets, ap, allocd_ret);
  return target;
}


#define ARTM_VEC(name, tp, vect, vec_len, op, is_div) \
void \
name (int64* res, int64 * l, int64* r, int n) \
{ \
  int inx; \
  if (is_div) \
    for (inx = 0; inx < n; inx++) \
      if (0 == ((tp*)r)[inx]) \
	sqlr_new_error ("22012", "SR084", "Division by 0."); \
  for (inx = 0; 0 && inx <= n - 2 * vec_len; inx += 2 * vec_len) \
    { \
      *(vect*)&((tp*)res)[inx] = *(vect*)&((tp*)l)[inx] op  *(vect*)&((tp*)r)[inx]; \
      *(vect*)&((tp*)res)[inx + vec_len] = *(vect*)&((tp*)l)[inx + vec_len] op *(vect*)&((tp*)r)[inx + vec_len]; \
    } \
  for (inx = 0; inx < n; inx++) \
    ((tp*)res)[inx] = ((tp*)l)[inx] op ((tp*)r)[inx]; \
}


ARTM_VEC (artm_add_int, int64, v2di_t, 2, +, 0);
ARTM_VEC (artm_add_float, float, v4sf_t, 4, +, 0);
ARTM_VEC (artm_add_double, double, v2df_t, 2, +, 0);

ARTM_VEC (artm_sub_int, int64, v2di_t, 2, -, 0);
ARTM_VEC (artm_sub_float, float, v4sf_t, 4, -, 0);
ARTM_VEC (artm_sub_double, double, v2df_t, 2, -, 0);

ARTM_VEC (artm_mpy_int, int64, v2di_t, 2, *, 0);
ARTM_VEC (artm_mpy_float, float, v4sf_t, 4, *, 0);
ARTM_VEC (artm_mpy_double, double, v2df_t, 2, *, 0);

ARTM_VEC (artm_div_int, int64, v2di_t, 2, /, 1);
ARTM_VEC (artm_div_float, float, v4sf_t, 4, /, 1);
ARTM_VEC (artm_div_double, double, v2df_t, 2, /, 1);


artm_vec_f vec_adds[3] = { artm_add_int, artm_add_float, artm_add_double };
artm_vec_f vec_subs[3] = { artm_sub_int, artm_sub_float, artm_sub_double };
artm_vec_f vec_mpys[3] = { artm_mpy_int, artm_mpy_float, artm_mpy_double };
artm_vec_f vec_divs[3] = { artm_div_int, artm_div_float, artm_div_double };


int
artm_vec (caddr_t * inst, instruction_t * ins, artm_vec_f * ops)
{
  data_col_t *res_dc = QST_BOX (data_col_t *, inst, ins->_.artm.result->ssl_index);
  state_slot_t *l = ins->_.artm.left;
  state_slot_t *r = ins->_.artm.right;
  artm_vec_f op;
  QNCAST (query_instance_t, qi, inst);
  vn_temp_t vn_temp_1;
  vn_temp_t vn_temp_2;
  int inx;
  dtp_t target_dtp;
  dtp_t l_dtp = ssl_artm_dtp (inst, l);
  dtp_t r_dtp = ssl_artm_dtp (inst, r);
  int n_sets = qi->qi_n_sets;
  if (DV_ANY == l_dtp || DV_ANY == r_dtp || SSL_VEC != ins->_.artm.result->ssl_type)
    return 0;
  target_dtp = MAX (l_dtp, r_dtp);
  DC_CHECK_LEN (res_dc, n_sets - 1);
  switch (target_dtp)
    {
    case DV_LONG_INT:
      op = ops[0];
      break;
    case DV_SINGLE_FLOAT:
      op = ops[1];
      break;
    case DV_DOUBLE_FLOAT:
      op = ops[2];
      break;
    default:
      return 0;
    }
  if (DCT_BOXES & res_dc->dc_type)
    return 0;
  if (DV_ANY == res_dc->dc_dtp)
    {
      dc_reset (res_dc);
      dc_convert_empty (res_dc, target_dtp);
    }
  for (inx = 0; inx < n_sets; inx += ARTM_VEC_LEN)
    {
      int n = MIN (ARTM_VEC_LEN, n_sets - inx);
      int64 *la, *ra;
      int64 *res = (DV_SINGLE_FLOAT == target_dtp) ? (int64 *) & ((float *) res_dc->dc_values)[inx]
	  : &((int64 *) res_dc->dc_values)[inx];
      if (!inx || (SSL_VEC == l->ssl_type || SSL_REF == l->ssl_type))
	la = ssl_artm_param (inst, l, (int64 *) & vn_temp_1.i, target_dtp, inx, n, NULL, NULL);
      if (!inx || (SSL_VEC == r->ssl_type || SSL_REF == r->ssl_type))
	ra = ssl_artm_param (inst, r, (int64 *) & vn_temp_2.i, target_dtp, inx, n, NULL, NULL);

      op (res, la, ra, n);
    }
  res_dc->dc_n_values = n_sets;
  return 1;
}


ins_dc_artm_t dc_artm_funcs[20];
ins_dc_artm_t dc_artm_1_funcs[20];
ins_dc_cmp_t dc_cmp_funcs[10];
ins_dc_cmp_1_t dc_cmp_1_funcs[10];


void
dc_add_int_1 (instruction_t * ins, caddr_t * inst)
{
  QNCAST (query_instance_t, qi, inst);
  data_col_t *dc1 = QST_BOX (data_col_t *, inst, ins->_.artm.left->ssl_index);
  data_col_t *dc2 = QST_BOX (data_col_t *, inst, ins->_.artm.right->ssl_index);
  data_col_t *res = QST_BOX (data_col_t *, inst, ins->_.artm.result->ssl_index);
  int set1, set2;
  set1 = set2 = qi->qi_set;
  DC_CHECK_LEN (res, qi->qi_n_sets);
  if (!res->dc_any_null && (dc1->dc_any_null || dc2->dc_any_null))
    dc_ensure_null_bits (res);

  if (SSL_REF == ins->_.artm.left->ssl_type)
    set1 = sslr_set_no (inst, ins->_.artm.left, set1);
  if (SSL_REF == ins->_.artm.right->ssl_type)
    set2 = sslr_set_no (inst, ins->_.artm.right, set2);
  if ((dc1->dc_nulls && DC_IS_NULL (dc1, set1)) || (dc2->dc_nulls && DC_IS_NULL (dc2, set2)))
    {
      DC_SET_NULL (res, qi->qi_set);
    }
  else
    {
      ((int64 *) res->dc_values)[qi->qi_set] = ((int64 *) dc1->dc_values)[set1] + ((int64 *) dc2->dc_values)[set2];
    }
  res->dc_n_values = MAX (res->dc_n_values, qi->qi_set + 1);
}


void
dc_add_int (instruction_t * ins, caddr_t * inst)
{
  QNCAST (query_instance_t, qi, inst);
  data_col_t *dc1 = QST_BOX (data_col_t *, inst, ins->_.artm.left->ssl_index);
  data_col_t *dc2 = QST_BOX (data_col_t *, inst, ins->_.artm.right->ssl_index);
  data_col_t *res = QST_BOX (data_col_t *, inst, ins->_.artm.result->ssl_index);
  int set1, set2, last = -1;
  int set, first_set = 0, n_sets = qi->qi_n_sets;
  db_buf_t set_mask = qi->qi_set_mask;
  DC_CHECK_LEN (res, n_sets);
  if ((dc1->dc_any_null || dc2->dc_any_null) && !res->dc_nulls)
    dc_ensure_null_bits (res);
  SET_LOOP
  {
    last = set1 = set2 = set;
    if (SSL_REF == ins->_.artm.left->ssl_type)
      set1 = sslr_set_no (inst, ins->_.artm.left, set1);
    if (SSL_REF == ins->_.artm.right->ssl_type)
      set2 = sslr_set_no (inst, ins->_.artm.right, set2);
    if ((dc1->dc_nulls && DC_IS_NULL (dc1, set1)) || (dc2->dc_nulls && DC_IS_NULL (dc2, set2)))
      {
	DC_SET_NULL (res, qi->qi_set);
      }
    else
      {
	((int64 *) res->dc_values)[qi->qi_set] = ((int64 *) dc1->dc_values)[set1] + ((int64 *) dc2->dc_values)[set2];
      }
  }
  END_SET_LOOP;
  res->dc_n_values = MAX (res->dc_n_values, last + 1);
}


int
dc_cmp_int_1 (instruction_t * ins, caddr_t * inst)
{
  QNCAST (query_instance_t, qi, inst);
  data_col_t *dc1 = QST_BOX (data_col_t *, inst, ins->_.cmp.left->ssl_index);
  data_col_t *dc2 = QST_BOX (data_col_t *, inst, ins->_.cmp.right->ssl_index);
  int set1, set2;
  int64 i1, i2;
  set1 = set2 = qi->qi_set;
  if (SSL_REF == ins->_.cmp.left->ssl_type)
    set1 = sslr_set_no (inst, ins->_.cmp.left, set1);
  if (SSL_REF == ins->_.cmp.right->ssl_type)
    set2 = sslr_set_no (inst, ins->_.cmp.right, set2);
  if ((dc1->dc_nulls && DC_IS_NULL (dc1, set1)) || (dc2->dc_nulls && DC_IS_NULL (dc2, set2)))
    return DVC_UNKNOWN;
  i1 = ((int64 *) dc1->dc_values)[set1];
  i2 = ((int64 *) dc2->dc_values)[set2];
  return NUM_COMPARE (i1, i2);
}


int
dc_cmp_int (instruction_t * ins, caddr_t * inst, db_buf_t bits)
{
  int unk_is_fail = ins->_.cmp.unkn == ins->_.cmp.fail, flag;
  QNCAST (query_instance_t, qi, inst);
  data_col_t *dc1 = QST_BOX (data_col_t *, inst, ins->_.cmp.left->ssl_index);
  data_col_t *dc2 = QST_BOX (data_col_t *, inst, ins->_.cmp.right->ssl_index);
  int n_true = 0, n_false = 0;
  int set1, set2;
  int64 i1, i2;
  int set, n_sets = qi->qi_n_sets, first_set = 0;
  db_buf_t set_mask = qi->qi_set_mask;
  SET_LOOP
  {
    set1 = set2 = set;
    if (SSL_REF == ins->_.cmp.left->ssl_type)
      set1 = sslr_set_no (inst, ins->_.cmp.left, set1);
    if (SSL_REF == ins->_.cmp.right->ssl_type)
      set2 = sslr_set_no (inst, ins->_.cmp.right, set2);
    if ((dc1->dc_nulls && DC_IS_NULL (dc1, set1)) || (dc2->dc_nulls && DC_IS_NULL (dc2, set2)))
      flag = unk_is_fail ? 0 : ins->_.cmp.op;
    else
      {
	i1 = ((int64 *) dc1->dc_values)[set1];
	i2 = ((int64 *) dc2->dc_values)[set2];
	flag = NUM_COMPARE (i1, i2);
      }
    if (flag & ins->_.cmp.op)
      {
	SET_MASK_SET (bits, set);
	n_true++;
      }
    else
      n_false++;
  }
  END_SET_LOOP;
  return n_true && n_false ? 2 : n_true ? 1 : 0;
}


void
dc_asg_64_1 (instruction_t * ins, caddr_t * inst)
{
  QNCAST (query_instance_t, qi, inst);
  data_col_t *dc1 = QST_BOX (data_col_t *, inst, ins->_.artm.left->ssl_index);
  data_col_t *res = QST_BOX (data_col_t *, inst, ins->_.artm.result->ssl_index);
  int set1;
  DC_CHECK_LEN (res, qi->qi_n_sets);
  set1 = qi->qi_set;
  if (SSL_REF == ins->_.artm.left->ssl_type)
    set1 = sslr_set_no (inst, ins->_.artm.left, set1);
  if (dc1->dc_nulls && DC_IS_NULL (dc1, set1))
    {
      if (!res->dc_nulls)
	dc_ensure_null_bits (res);
      DC_SET_NULL (res, qi->qi_set);
    }
  else
    {
      ((int64 *) res->dc_values)[qi->qi_set] = ((int64 *) dc1->dc_values)[set1];
    }
  res->dc_n_values = MAX (res->dc_n_values, qi->qi_set + 1);
}

void
dc_asg_64 (instruction_t * ins, caddr_t * inst)
{
  QNCAST (query_instance_t, qi, inst);
  data_col_t *dc1 = QST_BOX (data_col_t *, inst, ins->_.artm.left->ssl_index);
  data_col_t *res = QST_BOX (data_col_t *, inst, ins->_.artm.result->ssl_index);
  int set1, last = -1;
  int set, first_set = 0, n_sets = qi->qi_n_sets;
  db_buf_t set_mask = qi->qi_set_mask;
  DC_CHECK_LEN (res, qi->qi_n_sets - 1);
  if (dc1->dc_any_null && !res->dc_any_null)
    dc_ensure_null_bits (res);
  SET_LOOP
  {
    last = set1 = set;
    if (SSL_REF == ins->_.artm.left->ssl_type)
      set1 = sslr_set_no (inst, ins->_.artm.left, set1);
    if (dc1->dc_nulls && DC_IS_NULL (dc1, set1))
      {
	DC_SET_NULL (res, qi->qi_set);
      }
    else
      {
	((int64 *) res->dc_values)[qi->qi_set] = ((int64 *) dc1->dc_values)[set1];
      }
  }
  END_SET_LOOP;
  res->dc_n_values = MAX (res->dc_n_values, last + 1);
}


#define BYTE_N_LOW(byte, n) \
  (byte & ~(0xff << (n)))


#define SET_LOOP_FAST(set, n_sets, set_mask) \
{ \
  int set, byte, bytes = ALIGN_8 (n_sets) / 8; \
  int bits_in_last = n_sets - (bytes - 1) * 8; \
  for (byte = 0; byte < bytes; byte++) \
    { \
      uint32 binx, bits, cnt; \
      dtp_t sbits = set_mask[byte]; \
      if (byte == bytes - 1) \
	sbits = BYTE_N_LOW (sbits, bits_in_last); \
      bits = byte_bits[sbits]; \
      cnt = bits >> 28; \
      for (binx = 0; binx < cnt; binx++) \
	{ \
	  set = (byte * 8) + (bits & 7); \
	  bits = bits >> 3;



#define END_SET_LOOP_FAST  }}}



typedef void (*vec_cmp_t)  (int64 * l, int64 * r, int n_sets, dtp_t * set_mask, dtp_t * res_bits, char * mix_ret);


#define CMP_VEC(name, dtp, op) \
  void name  (dtp * l, dtp * r, int n_sets, dtp_t * set_mask, dtp_t * res_bits, char * mix_ret) \
{ \
  int set; \
  char mix = *mix_ret; \
  if (!set_mask) \
    { \
      for (set = 0; set < n_sets; set++) \
	{ \
	  if (l[set] op r[set]) \
	    { BIT_SET (res_bits, set); mix |= 2;}	\
	  else mix |= 1; \
	} \
    } \
  else \
    { \
      SET_LOOP_FAST  (set, n_sets, set_mask) \
	{ \
	  if (l[set] op r[set]) \
	    { BIT_SET (res_bits, set); mix |= 2;}	\
	  else mix |= 1; \
	} \
      END_SET_LOOP_FAST; \
    } \
  *mix_ret = mix; \
}


#define CMPOP(op) (l[set] op r[set])


CMP_VEC (cmp_vec_int_eq, int64, ==)
CMP_VEC (cmp_vec_int_lt, int64, <)
CMP_VEC (cmp_vec_int_lte, int64, <=)

CMP_VEC (cmp_vec_sf_eq, float, ==)
CMP_VEC (cmp_vec_sf_lt, float, <)
CMP_VEC (cmp_vec_sf_lte, float, <=)

CMP_VEC (cmp_vec_dbl_eq, double, ==)
CMP_VEC (cmp_vec_dbl_lt, double, <)
CMP_VEC (cmp_vec_dbl_lte, double, <=)



vec_cmp_t int_cmp_ops[] = {NULL, cmp_vec_int_eq, cmp_vec_int_lt, cmp_vec_int_lte};
vec_cmp_t sf_cmp_ops[] = {NULL, cmp_vec_sf_eq, cmp_vec_sf_lt, cmp_vec_sf_lte};
vec_cmp_t dbl_cmp_ops[] = {NULL, cmp_vec_dbl_eq, cmp_vec_dbl_lt, cmp_vec_dbl_lte};





#define CMP_VEC_OP(name, dtp, op) \
void name  (dtp * l, dtp * r, int n_sets, dtp_t * set_mask, dtp_t * res_bits, dtp_t cmp_op, char * mix_ret) \
{ \
  int set; \
  char mix = *mix_ret; \
  if (!set_mask) \
    { \
      for (set = 0; set < n_sets; set++) \
	{ \
	  if (op)				\
	    { BIT_SET (res_bits, set); mix |= 2;}	\
	  else mix |= 1;				\
	}						\
      } \
  else \
    { \
      SET_LOOP_FAST  (set, n_sets, set_mask) \
	{ \
	  if (op) \
	    { BIT_SET (res_bits, set); mix |= 2;}	\
	  else mix |= 1; \
	} \
      END_SET_LOOP_FAST; \
    } \
  *mix_ret = mix; \
}

int
dt_cmp_fl (db_buf_t dt1, db_buf_t dt2)
{
  int inx;
  for (inx = 0; inx < DT_COMPARE_LENGTH; inx++)
    {
      dtp_t d1 = dt1[inx], d2 = dt2[inx];
      if (d1 < d2) 
	return DVC_LESS;
      if (d1 > d2)
	return DVC_GREATER;
    }
  return DVC_MATCH;
}


CMP_VEC_OP (cmp_vec_dt, dtp_t *, cmp_op & dt_cmp_fl (((db_buf_t)l) + DT_LENGTH * set, ((db_buf_t)r) + DT_LENGTH * set))
CMP_VEC_OP (cmp_vec_any, dtp_t **, cmp_op & dv_compare (((db_buf_t*)l)[set], ((db_buf_t*)r)[set], NULL, 0))
#define SWAP(t, l, r) { t tmp; tmp = r; r = l; l = tmp;}
#define CMP_REV(new_op) \
  { cmp_op = new_op; SWAP (dtp_t, l_dtp, r_dtp); SWAP (state_slot_t *, l, r);}
     int cmp_vec (caddr_t * inst, instruction_t * ins, dtp_t * set_mask, dtp_t * res_bits)
{
  state_slot_t * l = ins->_.cmp.left;
  state_slot_t * r = ins->_.cmp.right;
  unsigned char cmp_op;
  vec_cmp_t op;
  char mix = 0;
  QNCAST (query_instance_t, qi, inst);
  vn_temp_t vn_temp_1;
  vn_temp_t vn_temp_2;
  int inx;
  dtp_t target_dtp;
  dtp_t l_dtp = ssl_cmp_dtp (inst, l);
  dtp_t r_dtp = ssl_cmp_dtp (inst, r);
  int n_sets = qi->qi_n_sets;
  if (DV_ARRAY_OF_POINTER == l_dtp || DV_ARRAY_OF_POINTER == r_dtp)
    return CMP_VEC_NA;
  cmp_op = ins->_.cmp.op;
  if (CMP_GT == cmp_op)
    {
      CMP_REV (CMP_LT);
    }
  else if (CMP_GTE == cmp_op)
    {
      CMP_REV (CMP_LTE);
    }
  if (IS_NUM_DTP (l_dtp) && IS_NUM_DTP (r_dtp))
    {
      target_dtp = MAX (l_dtp, r_dtp);
      switch (target_dtp)
	{
	case DV_LONG_INT:
	  op = int_cmp_ops[cmp_op];
	  break;
	case DV_SINGLE_FLOAT:
	  op = sf_cmp_ops[cmp_op];
	  break;
	case DV_DOUBLE_FLOAT:
	  op = dbl_cmp_ops[cmp_op];
	  break;
	default:
	  return CMP_VEC_NA;
	}
      for (inx = 0; inx < n_sets; inx += ARTM_VEC_LEN)
	{
	  int n = MIN (ARTM_VEC_LEN, n_sets - inx);
	  int64 * la, *ra;
	  if (!inx || (SSL_VEC == l->ssl_type || SSL_REF == l->ssl_type))
	    la = ssl_artm_param (inst, l, (int64 *) & vn_temp_1.i, target_dtp, inx, n, NULL, NULL);
	  if (!inx || (SSL_VEC == r->ssl_type || SSL_REF == r->ssl_type))
	    ra = ssl_artm_param (inst, r, (int64 *) & vn_temp_2.i, target_dtp, inx, n, NULL, NULL);
	  
	  op (la, ra, n, set_mask ? &set_mask[inx / 8] : NULL, &res_bits[inx / 8], &mix);
	}
      return mix - 1;
    }
  if (DV_DATETIME == l_dtp && DV_DATETIME == r_dtp)
    {
      for (inx = 0; inx < n_sets; inx += ARTM_VEC_LEN)
	{
	  int n = MIN (ARTM_VEC_LEN, n_sets - inx);
	  int64 * la, *ra;
	  if (!inx || (SSL_VEC == l->ssl_type || SSL_REF == l->ssl_type))
	    la = ssl_artm_param (inst, l, (int64 *) & vn_temp_1.i, DV_DATETIME, inx, n, NULL, NULL);
	  if (!inx || (SSL_VEC == r->ssl_type || SSL_REF == r->ssl_type))
	    ra = ssl_artm_param (inst, r, (int64 *) & vn_temp_2.i, DV_DATETIME, inx, n, NULL, NULL);
	  cmp_vec_dt ((db_buf_t)la, (db_buf_t)ra, n, set_mask ? &set_mask[inx / 8] : NULL, &res_bits[inx / 8], cmp_op, &mix);
	}
      return mix - 1;
    }
  else if (DV_ANY == l_dtp && DV_ANY == r_dtp)
    {
      caddr_t allocd = NULL;
      AUTO_POOL (500);
      for (inx = 0; inx < n_sets; inx += ARTM_VEC_LEN)
	{
	  int n = MIN (ARTM_VEC_LEN, n_sets - inx);
	  int64 * la, *ra;
	  if (!inx || (SSL_VEC == l->ssl_type || SSL_REF == l->ssl_type))
	    la = ssl_artm_param (inst, l, (int64 *) & vn_temp_1.i, DV_ANY, inx, n, &ap, &allocd);
	  if (!inx || (SSL_VEC == r->ssl_type || SSL_REF == r->ssl_type))
	    ra = ssl_artm_param (inst, r, (int64 *) & vn_temp_2.i, DV_ANY, inx, n, &ap, &allocd);
	  cmp_vec_any (la, ra, n, set_mask ? &set_mask[inx / 8] : NULL, &res_bits[inx / 8], cmp_op, &mix);
	}
      if (allocd && (allocd < ap.ap_area || allocd > ap.ap_area + ap.ap_fill))
	dk_free_box (allocd);
      return mix - 1;
    }
  return CMP_VEC_NA;
}
