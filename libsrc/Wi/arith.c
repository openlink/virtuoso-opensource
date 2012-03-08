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
 *  Copyright (C) 1998-2012 OpenLink Software
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
#include "sqlfn.h"
#include "arith.h"
#include "srvmultibyte.h"
#include "numeric.h"
#include "xmltree.h"

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
  caddr_t *place = IS_SSL_REF_PARAMETER (sl->ssl_type)
    ? (caddr_t *) state[sl->ssl_index]
    : (caddr_t *) & state[sl->ssl_index];
  caddr_t old = *place;
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
  caddr_t *place = IS_SSL_REF_PARAMETER (sl->ssl_type)
    ? (caddr_t *) state[sl->ssl_index]
    : (caddr_t *) & state[sl->ssl_index];
  caddr_t old = *place;
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
  caddr_t *place = IS_SSL_REF_PARAMETER (sl->ssl_type)
    ? (caddr_t *) state[sl->ssl_index]
    : (caddr_t *) & state[sl->ssl_index];
  caddr_t old = *place;
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
	    tl = *(boxint*) n1;
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
	    td = (double) (* (float*) n1);
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
	    td = (double) * (float*)n2;
	    numeric_init_static ((numeric_t) n2, NUMERIC_STACK_BYTES);
	    numeric_from_double ((numeric_t) n2, td);
	    *out_dtp = DV_NUMERIC;
	    return 1;
	  case DV_DOUBLE_FLOAT:
	    td = *(double*)n2;
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
      *(boxint*) to = INT64_REF_NA (place + 1);
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
  frexp(fabs(x1) > fabs(x2) ? x1 : x2, &exponent);

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
    return DVC_GREATER;			/* x1 > x2 */
  else if (difference < -delta)
    return DVC_LESS;			/* x1 < x2 */
  else					/* -delta <= difference <= delta */
    return DVC_MATCH;			/* x1 == x2 */
}


int
numeric_compare_dvc (numeric_t x, numeric_t y)
{
  int rc = numeric_compare (x,y);
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
	  return (NUM_COMPARE (*(boxint *) &dn1, *(boxint *) &dn2));
	case DV_SINGLE_FLOAT:
	  return cmp_double (*(float *) &dn1, *(float *) &dn2, FLT_EPSILON);
	case DV_DOUBLE_FLOAT:
	  return cmp_double (*(double *) &dn1, *(double *) &dn2, DBL_EPSILON);
	case DV_NUMERIC:
	  return (numeric_compare_dvc ((numeric_t) &dn1, (numeric_t) &dn2));
	}
    }
  else
    sqlr_new_error ("22003", "SR082", "Non numeric comparison");
  return 0;
}


int
cmp_boxes_safe (ccaddr_t box1, ccaddr_t box2, collation_t *collation1, collation_t *collation2)
{
  int inx, n1, n2;
  NUMERIC_VAR (dn1);
  NUMERIC_VAR (dn2);
  dtp_t dtp1, dtp2, res_dtp;

  if ((IS_BOX_POINTER (box1) && DV_RDF == box_tag (box1))  || (IS_BOX_POINTER (box2) && DV_RDF == box_tag (box2)))
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
	  return (NUM_COMPARE (*(boxint *) &dn1, *(boxint *) &dn2));
	case DV_SINGLE_FLOAT:
	  return cmp_double (*(float *) &dn1, *(float *) &dn2, FLT_EPSILON);
	case DV_DOUBLE_FLOAT:
	  return cmp_double (*(double *) &dn1, *(double *) &dn2, DBL_EPSILON);
	case DV_NUMERIC:
	  return (numeric_compare_dvc ((numeric_t) &dn1, (numeric_t) &dn2));
	}
      GPF_T1("cmp_boxes(): unsupported datatype returned by n_coerce");
    }
      if (!IS_BOX_POINTER (box1) || !IS_BOX_POINTER (box2))
	return DVC_NOORDER;

      if (DV_COMPOSITE == dtp1 && DV_COMPOSITE == dtp2)
	return (dv_composite_cmp ((db_buf_t) box1, (db_buf_t) box2, collation1));
      if (DV_IRI_ID == dtp1 && DV_IRI_ID == dtp2)
	return NUM_COMPARE (unbox_iri_id (box1), unbox_iri_id (box2));
      n1 = box_length (box1);
      n2 = box_length (box2);

      if ((dtp1 == DV_DATETIME && dtp2 == DV_BIN) ||
	(dtp2 == DV_DATETIME && dtp1 == DV_BIN))
	dtp1 = dtp2 = DV_DATETIME;

      switch (dtp1)
	{
	case DV_STRING:
	  n1--;
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
        {
          if (box_flags (box2) & (BF_IRI | BF_UTF8))
            return compare_wide_to_utf8_with_collation ((wchar_t *) box1, n1, (utf8char *) box2, n2, NULL);
          else
            return compare_wide_to_latin1 ((wchar_t *) box1, n1, (unsigned char *) box2, n2);
        }
      if (IS_STRING_DTP (dtp1) && IS_WIDE_STRING_DTP (dtp2))
	{
          int res;
          if (box_flags (box2) & (BF_IRI | BF_UTF8))
	    res = compare_wide_to_utf8_with_collation ((wchar_t *)box2, n2, (utf8char *) box1, n1, NULL);
          else
	    res = compare_wide_to_latin1 ((wchar_t *)box2, n2, (unsigned char *) box1, n1);
	  return (res == DVC_LESS ? DVC_GREATER :
	      (res == DVC_GREATER ? DVC_LESS : res));
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
      if (collation1 && !collation1->co_is_wide)
	{
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

	      if (collation1->co_table[(dtp_t) box1[inx]] < collation1->co_table[(dtp_t) box2[inx]])
		return DVC_LESS;

	      if (collation1->co_table[(dtp_t) box1[inx]] > collation1->co_table[(dtp_t) box2[inx]])
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
		    return DVC_MATCH;  /* box2 of same length */
		  else
		    return DVC_LESS;   /* otherwise box1 is shorter than box2 */
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
      return xe_compare_content ((xml_entity_t *)box1, (xml_entity_t *)box2, 0 /* do not compare URIs and DTDs */);
    }
  return DVC_NOORDER;
}

#ifdef CMP_MOREDEBUG
int
cmp_boxes_old (ccaddr_t box1, ccaddr_t box2, collation_t *collation1, collation_t *collation2)
#else
int
cmp_boxes (ccaddr_t box1, ccaddr_t box2, collation_t *collation1, collation_t *collation2)
#endif
{
  NUMERIC_VAR (dn1);
  NUMERIC_VAR (dn2);
  dtp_t dtp1, dtp2, res_dtp;

  if ((IS_BOX_POINTER (box1) && DV_RDF == box_tag (box1))  || (IS_BOX_POINTER (box2) && DV_RDF == box_tag (box2)))
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
	  return (NUM_COMPARE (*(boxint *) &dn1, *(boxint *) &dn2));
	case DV_SINGLE_FLOAT:
	  return cmp_double (*(float *) &dn1, *(float *) &dn2, FLT_EPSILON);
	case DV_DOUBLE_FLOAT:
	  return cmp_double (*(double *) &dn1, *(double *) &dn2, DBL_EPSILON);
	case DV_NUMERIC:
	  return (numeric_compare_dvc ((numeric_t) &dn1, (numeric_t) &dn2));
	}
    }
  else
    {
      int inx = 0, n1, n2;

      if (!IS_BOX_POINTER (box1) || !IS_BOX_POINTER (box2))
	return DVC_LESS;

      if (DV_COMPOSITE == dtp1 && DV_COMPOSITE == dtp2)
	return (dv_composite_cmp ((db_buf_t) box1, (db_buf_t) box2, collation1));
      if (DV_IRI_ID == dtp1 && DV_IRI_ID == dtp2)
	return NUM_COMPARE (unbox_iri_id (box1), unbox_iri_id (box2));
      n1 = box_length (box1);
      n2 = box_length (box2);

      if ((dtp1 == DV_DATETIME && dtp2 == DV_BIN) ||
	(dtp2 == DV_DATETIME && dtp1 == DV_BIN))
	dtp1 = dtp2 = DV_DATETIME;

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
        {
          if (box_flags (box2) & (BF_IRI | BF_UTF8))
            return compare_wide_to_utf8_with_collation ((wchar_t *) box1, n1, (utf8char *) box2, n2, NULL);
          else
            return compare_wide_to_latin1 ((wchar_t *) box1, n1, (unsigned char *) box2, n2);
        }
      if (IS_STRING_DTP (dtp1) && IS_WIDE_STRING_DTP (dtp2))
	{
          int res;
          if (box_flags (box2) & (BF_IRI | BF_UTF8))
	    res = compare_wide_to_utf8_with_collation ((wchar_t *)box2, n2, (utf8char *) box1, n1, NULL);
          else
	    res = compare_wide_to_latin1 ((wchar_t *)box2, n2, (unsigned char *) box1, n1);
	  return (res == DVC_LESS ? DVC_GREATER :
	      (res == DVC_GREATER ? DVC_LESS : res));
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

      if (collation1 && !collation1->co_is_wide)
	{
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

	      if (collation1->co_table[(dtp_t) box1[inx]] < collation1->co_table[(dtp_t) box2[inx]])
		return DVC_LESS;

	      if (collation1->co_table[(dtp_t) box1[inx]] > collation1->co_table[(dtp_t) box2[inx]])
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
		    return DVC_MATCH;  /* box2 of same length */
		  else
		    return DVC_LESS;   /* otherwise box1 is shorter than box2 */
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
cmp_boxes (ccaddr_t box1, ccaddr_t box2, collation_t *collation1, collation_t *collation2)
{
  int res_safe = cmp_boxes_safe (box1, box2, collation1, collation2);
  int res_old = cmp_boxes_old (box1, box2, collation1, collation2);
  if (res_safe != res_old)
    {
      fprintf (stderr, "\n%s:%d\n*** cmp_box error: now it is %d, safe is %d: ",
      __FILE__, __LINE__, res_old, res_safe );
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
numeric_bin_op (numeric_bop_t num_op, numeric_t x, numeric_t y, caddr_t * qst,
    state_slot_t * target)
{
  int rc;
  caddr_t res_box = NULL;
  if (target)
    {
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


#define ARTM_BIN_FUNC(name, op, num_op, isdiv) \
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
      if (((query_instance_t *)qst)->qi_query->qr_no_cast_error) \
        goto null_result; \
      sqlr_new_error ("22003", "SR087", "Non numeric argument(s) to arithmetic operation."); \
    } \
null_result: \
  if (target) \
    { \
      qst_set_bin_string (qst, target, NULL, 0, DV_DB_NULL); \
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
    goto null_result; \
  if (n_coerce ((caddr_t) & dn1, (caddr_t) & dn2,
	  dtp1, dtp2, &res_dtp))
    {
      switch (res_dtp)
	{
	case DV_LONG_INT:
	  if (0 == *(boxint *) &dn2)
	    sqlr_new_error ("22012", "SR088", "Division by 0.");
	  if (target)
	    return (qst_set_long (qst, target,
		(*(boxint *) &dn1 % * (boxint *) &dn2)), (caddr_t) 0);
	  return (box_num (*(boxint *) &dn1 % * (boxint *) &dn2));
	case DV_SINGLE_FLOAT:
	  if (0 == *(float *) &dn2)
	    sqlr_new_error ("22012", "SR089", "Division by 0.");
	  if (target)
	    return (qst_set_float (qst, target,
		(float) fmod (*(float *) &dn1,  * (float *) &dn2)), (caddr_t) 0);
	  return (box_float ((float) fmod (*(float *) &dn1, * (float *) &dn2)));
	case DV_DOUBLE_FLOAT:
	  if (0 == *(double*) &dn2)
	    sqlr_new_error ("22012", "SR090", "Division by 0.");
	  if (target)
	    return (qst_set_double (qst, target, fmod (*(double*) &dn1, *(double*) &dn2)), (caddr_t) 0);
	  return (box_double (fmod (*(double*) &dn1, *(double*) &dn2)));
	case DV_NUMERIC:
	  return (numeric_bin_op (numeric_modulo, (numeric_t) &dn1, (numeric_t) &dn2, qst, target));
	}
    }
  else
    {
      if (dtp1 == DV_RDF || dtp2 == DV_RDF)
        {
          if (dtp1 == DV_RDF)
            box1 = ((rdf_box_t *)(box1))->rb_box;
          if (dtp2 == DV_RDF)
            box2 = ((rdf_box_t *)(box2))->rb_box;
          goto retry_rdf_boxes;
        }
      if (((query_instance_t *)qst)->qi_query->qr_no_cast_error)
        goto null_result; /* see below */
      sqlr_new_error ("22003", "SR087", "Non numeric arguments to arithmetic operation modulo");
    }
null_result: \
  if (target) \
    { \
      qst_set_bin_string (qst, target, NULL, 0, DV_DB_NULL); \
      return NULL; \
    } \
  return (dk_alloc_box (0, DV_DB_NULL)); \
}

ARTM_BIN_FUNC (box_add, +, numeric_add, 0)
ARTM_BIN_FUNC (box_sub, -, numeric_subtract, 0)
ARTM_BIN_FUNC (box_mpy, *, numeric_multiply, 0)
ARTM_BIN_FUNC (box_div, /, numeric_divide, 1)


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
double trunc (double x)
{
  if (x >= 0)
    return floor(x);
  else
    return ceil(x);
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
      int64 i2 = (int64)d;
      return NUM_COMPARE (i, i2);
    }
  if (d > -1 && d< 1)
    return NUM_COMPARE (((double)i), d);
  r = NUM_COMPARE ((double)i, d);
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
      numeric_from_double ((numeric_t)num2, d2);
      return numeric_compare_dvc ((numeric_t)num1, (numeric_t)num2);
    }
  numeric_to_double (num1, &d1);
  if (d1 == d2)
    {
      if (num1->n_len + num1->n_scale < 15)
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
  numeric_from_int64 ((numeric_t)n1, i);
  return numeric_compare_dvc ((numeric_t)n1, (numeric_t)n2);
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
      *(double *)dn1 = *(float *)dn1;
      dtp1 = DV_DOUBLE_FLOAT;
    }
  if (DV_SINGLE_FLOAT == dtp2)
    {
      *(double *)dn2 = *(float *)dn2;
      dtp2 = DV_DOUBLE_FLOAT;
    }

  if (dtp1 == dtp2)
    {
      switch (dtp1)
	{
	case DV_LONG_INT:
	  return NUM_COMPARE (*(int64*)dn1, *(int64*)dn2);
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
	  return dvc_int_num (*(int64*)dn1, dn2);
	case DV_DOUBLE_FLOAT:
	  return dvc_int_double (*(int64*)dn1, *(double*)dn2);
	default: GPF_T1 ("bad num compare combination");
	}
    case DV_DOUBLE_FLOAT:
      switch (dtp2)
	{
	case DV_LONG_INT:
	  REV (dvc_int_double (*(int64*)dn2,  *(double*) dn1));
	case DV_NUMERIC:
	  REV (dvc_num_double (dn2, *(double*)dn1));
	default: GPF_T1 ("bad num compare combination");
	}
    case DV_NUMERIC:
      switch (dtp2)
	{
	case DV_LONG_INT:
	  REV (dvc_int_num (*(int64*)dn2, (numeric_t)dn1));
	case DV_DOUBLE_FLOAT:
	  return dvc_num_double ((numeric_t)dn1, *(double*)dn2);
	default: GPF_T1 ("bad num compare combination");
	}
    default: GPF_T1 ("bad num compare combination");
    }
  return 0;
}

