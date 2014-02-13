/*
 *  cetop.c
 *
 *  $Id$
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

#include "sqlnode.h"
#include "arith.h"
#include "date.h"
#include "datesupp.h"


extern int64 trap_value[4];
extern int allow_non_unq_range;


int
itc_is_any_key (it_cursor_t * itc, int nth)
{
  /* true if the nth key part is a any type col */
  search_spec_t *sp = itc->itc_key_spec.ksp_spec_array;
  int inx;
  for (inx = 0; sp && inx < nth; inx++)
    sp = sp->sp_next;
  if (!sp)
    return 0;
  return DV_ANY == sp->sp_cl.cl_sqt.sqt_dtp;
}


void
dv_from_iri (db_buf_t ctmp, iri_id_t i)
{
  if ((iri_id_t) i > 0xffffffff)
    {
      ctmp[0] = DV_IRI_ID_8;
      INT64_SET_NA (ctmp + 1, i);
    }
  else
    {
      ctmp[0] = DV_IRI_ID;
      LONG_SET_NA (ctmp + 1, i);
    }
}


void
dv_from_int (db_buf_t ctmp, int64 i)
{
  if (i < INT32_MIN || i > INT32_MAX)
    {
      ctmp[0] = DV_INT64;
      INT64_SET_NA (ctmp + 1, i);
    }
  else if ((i > -128) && (i < 128))
    {
      ctmp[0] = DV_SHORT_INT;
      ctmp[1] = i;
    }
  else
    {
      ctmp[0] = DV_LONG_INT;
      LONG_SET_NA (ctmp + 1, i);
    }
}


int64
dv_if_needed (int64 any_param, dtp_t dtp, db_buf_t tmp)
{
  if (DV_LONG_INT == dtp)
    {
      dv_from_int (tmp, any_param);
      return (ptrlong) tmp;
    }
  if (DV_IRI_ID == dtp)
    {
      dv_from_iri (tmp, any_param);
      return (ptrlong) tmp;
    }
  return (ptrlong) any_param;
}


#define ITC_IS_ANY_COL(itc, nth) \
  (DV_ANY == itc->itc_col_spec->sp_cl.cl_sqt.sqt_dtp)

db_buf_t
itc_dv_param (it_cursor_t * itc, int nth_key, db_buf_t ctmp)
{
  data_col_t *dc = NULL;
  int64 i;
  dtp_t dtp;
  if (!itc->itc_n_sets)
    {
      if (ITC_IS_ANY_COL (itc, nth_key))
	return (db_buf_t) itc->itc_search_params[nth_key];
      i = unbox_iri_int64 (itc->itc_search_params[nth_key]);
      dtp = DV_TYPE_OF (itc->itc_search_params[nth_key]);
      if (!(DV_IRI_ID == dtp || DV_LONG_INT == dtp))
	return (db_buf_t) (uptrlong) itc_anify_param (itc, itc->itc_search_params[nth_key]);
    }
  else
    {
      dc = ITC_P_VEC (itc, nth_key);
      if (!dc)
	{
	  dtp = DV_TYPE_OF (itc->itc_search_params[nth_key]);
	  if (ITC_IS_ANY_COL (itc, nth_key))
	    return (db_buf_t) itc->itc_search_params[nth_key];
	  i = unbox_iri_int64 (itc->itc_search_params[nth_key]);
	  if (!(DV_IRI_ID == dtp || DV_LONG_INT == dtp))
	    return (db_buf_t) (uptrlong) itc_anify_param (itc, itc->itc_search_params[nth_key]);
	}
      else
	{
	  int f;
	  int64 d;
	  int set = itc->itc_param_order[itc->itc_set];
	  dtp = dc->dc_sqt.sqt_dtp;
	  dtp = dtp_canonical[dtp];
	  switch (dtp)
	    {
	    case DV_SINGLE_FLOAT:
	      f = ((int32 *) dc->dc_values)[set];
	      ctmp[0] = DV_SINGLE_FLOAT;
	      LONG_SET_NA (&ctmp[1], f);
	      return ctmp;
	    case DV_DOUBLE_FLOAT:
	      ctmp[0] = DV_DOUBLE_FLOAT;
	      d = ((int64 *) dc->dc_values)[set];
	      INT64_SET_NA (&ctmp[1], d);
	      return ctmp;
	    case DV_DATETIME:
	      ctmp[0] = DV_DATETIME;
	      memcpy (ctmp + 1, dc->dc_values + set * DT_LENGTH, DT_LENGTH);
	      return ctmp;
	    case DV_NUMERIC:
	      numeric_to_dv (((numeric_t *) dc->dc_values)[set], ctmp, MAX_FIXED_DV_BYTES);
	      return ctmp;
	    default:
	      i = ((int64 *) dc->dc_values)[itc->itc_param_order[itc->itc_set]];
	      break;
	    }
	}
    }
  if (DV_IRI_ID == dtp)
    {
      dv_from_iri (ctmp, i);
      return ctmp;
    }
  else if (DV_LONG_INT == dtp)
    {
      dv_from_int (ctmp, i);
      return ctmp;
    }
  else if (DV_DB_NULL == dtp)
    {
      ctmp[0] = DV_DB_NULL;
      return ctmp;
    }
  return (db_buf_t) (ptrlong) i;
}


db_buf_t
itc_string_param (it_cursor_t * itc, int nth_key, int *len_ret, dtp_t * dtp_ret)
{
  db_buf_t str;
  int is_any = 0;
  if (!itc->itc_n_sets)
    {
      str = (db_buf_t) itc->itc_search_params[nth_key];
      *dtp_ret = DV_TYPE_OF (str);
      if (DV_STRING != *dtp_ret)
	return NULL;

      is_any = itc_is_any_key (itc, nth_key);
    }
  else
    {
      data_col_t *dc = ITC_P_VEC (itc, nth_key);
      if (!dc)
	{
	  str = (db_buf_t) itc->itc_search_params[nth_key];
	  *dtp_ret = DV_TYPE_OF (str);
	  if (DV_STRING != *dtp_ret)
	    return NULL;
	  is_any = itc_is_any_key (itc, nth_key);
	}
      else
	{
	  *dtp_ret = dc->dc_sqt.sqt_dtp;
	  str = ((db_buf_t *) dc->dc_values)[itc->itc_param_order[itc->itc_set]];
	  is_any = DV_ANY == dc->dc_sqt.sqt_dtp;
	  if (!is_any && DV_STRING != *dtp_ret)
	    return NULL;
	}
    }
  if (is_any)
    {
      if (DV_SHORT_STRING_SERIAL == str[0])
	{
	  *dtp_ret = DV_STRING;
	  *len_ret = str[1];
	  return str + 2;
	}
      if (DV_STRING == str[0])
	{
	  *dtp_ret = DV_STRING;
	  *len_ret = LONG_REF_NA (str + 1);
	  return str + 5;
	}
      *dtp_ret = str[0];
      return NULL;
    }
  *len_ret = box_length (str) - 1;
  return str;
}


#define CE_END_CK \
{  \
  if (nth_key) \
    { \
      if (set == itc->itc_range_fill) \
	{ \
	  if (SET_LEADING_EQ != set_eq) \
	    return CE_SET_END; \
	} \
      else \
	{ \
	  if (itc->itc_ranges[set].r_first >= row_of_ce + ce_n_values) \
	    return CE_DONE; \
	} \
    } \
}


void
ce_vec_any_val (db_buf_t ce_first, dtp_t flags, int n_values, int nth, db_buf_t * val_ret, short *off_ret)
{
  db_buf_t ce_first_val;
  int first_len;
  ce_vec_nth (ce_first, flags, n_values, nth, &ce_first_val, &first_len, 0);
  if (ce_first_val[0] < DV_ANY_FIRST)
    {
      dtp_t off;
      short inx = ce_first_val[0] <= MAX_1_BYTE_CE_INX ? (off = ce_first_val[1], ce_first_val[0])
	  : (off = ce_first_val[2], (ce_first_val[0] - MAX_1_BYTE_CE_INX - 1) * 256 + ce_first_val[1]);
      int org_len;
      ce_vec_nth (ce_first, flags, n_values, inx, val_ret, &org_len, 0);
      *off_ret = off - (*val_ret)[org_len - 1];
      return;
    }
  *off_ret = 0;
  *val_ret = ce_first_val;
}


int
ce_num_cast_cb (col_pos_t * cpo, int row, dtp_t flags, db_buf_t val, int len, int64 offset, int rl)
{
  dtp_t tmp[COL_MAX_STR_LEN + 20];
  int rc;
  if (CE_INTLIKE (flags))
    {
      dv_from_int (tmp, offset);
    }
  else
    any_add (val, len, offset, tmp, flags);
  rc = ~DVC_NOORDER & dv_compare (tmp, (db_buf_t) cpo->cpo_cmp_min, NULL, 0);
  if (DVC_MATCH == rc)
    {
      if (COL_NO_ROW == cpo->cpo_range->r_first)
	cpo->cpo_range->r_first = row;
    }
  else if (DVC_GREATER == rc)
    {
      cpo->cpo_range->r_end = row;
      return 1000000;
    }
  return row + rl;
}


int
itc_num_cast_search (it_cursor_t * itc, db_buf_t ce, int64 delta, int dtp_cmp, int rc)
{
  dtp_t ctmp[40];
  int set;
  int from, to, row_of_ce = itc->itc_row_of_ce, ce_rows;
  col_pos_t cpo;
  row_range_t range;
  set = itc->itc_set - itc->itc_col_first_set;

  range.r_first = range.r_end = COL_NO_ROW;
  cpo.cpo_range = &range;
  cpo.cpo_value_cb = ce_num_cast_cb;
  cpo.cpo_string = ce;
  cpo.cpo_ce_row_no = 0;
  cpo.cpo_bytes = ce_total_bytes (ce);
  cpo.cpo_cmp_min = (caddr_t) itc_dv_param (itc, itc->itc_nth_key, ctmp);
  ce_rows = ce_n_values (ce);
  if (!itc->itc_nth_key)
    {
      from = 0;
      to = ce_rows;
    }
  else
    {
      if (set == itc->itc_range_fill)
	{
	  /* must be a leading eq situation because end of set and repeat of value are  checked before getting new val */
	  itc_range (itc, itc->itc_ranges[set - 1].r_end, COL_NO_ROW);
	}
      from = itc->itc_ranges[set].r_first - row_of_ce;
      to = itc->itc_ranges[set].r_end - row_of_ce;
      if (from < 0)
	from = 0;
      if (to > ce_rows)
	to = ce_rows;
    }
  cpo.cpo_itc = NULL;
  cpo.cpo_ce_op = NULL;
  cpo.cpo_pm = NULL;
  cs_decode (&cpo, from, to);
  if (CE_FIND_LAST == rc)
    {
      if (COL_NO_ROW == range.r_end)
	{
	  if (itc->itc_ranges[set].r_end > to + row_of_ce)
	    return CE_CONTINUES;
	  return CE_NEXT_SET;
	}
      itc->itc_ranges[set].r_end = itc->itc_row_of_ce + range.r_end;
      return CE_NEXT_SET;
    }
  if (0 == itc->itc_nth_key)
    {
      itc_range (itc, COL_NO_ROW, COL_NO_ROW);
    }
  if (COL_NO_ROW == range.r_first)
    {
      /* no match.  Could be a gt was found */
      if (COL_NO_ROW == range.r_end)
	{
	  if (itc->itc_ranges[set].r_end <= row_of_ce + ce_rows)
	    {
	      itc->itc_ranges[set].r_first = itc->itc_ranges[set].r_end;
	      return CE_NEXT_SET;	/* all are lt, ce continues past range, insert point is end of range, do next set */
	    }
	  else
	    {
	      itc->itc_ranges[set].r_first = COL_NO_ROW;
	      return CE_DONE;	/* no match here, all are lt, look in next */
	    }
	}
      /* a gt was found */
      itc->itc_ranges[set].r_end = itc->itc_row_of_ce + range.r_end;
      if (COL_NO_ROW == range.r_first)
	itc->itc_ranges[set].r_first = itc->itc_row_of_ce + range.r_end;
      return CE_NEXT_SET;
    }
  else
    {
      itc->itc_ranges[set].r_first = range.r_first + itc->itc_row_of_ce;
      if (COL_NO_ROW == range.r_end)
	{
	  /* there was no gt in the scanned part of the ce.  If range extends beyond, contimue search, else leave end unchanged and take next set */
	  if (itc->itc_ranges[set].r_end <= row_of_ce + ce_rows)
	    return CE_NEXT_SET;
	return CE_CONTINUES;
	}
      itc->itc_ranges[set].r_end = range.r_end + itc->itc_row_of_ce;
      return CE_NEXT_SET;
    }
  GPF_T1 ("should have decided by now");
  return 0;
}


int
ce_bad_len_ins_cb (col_pos_t * cpo, int row, dtp_t flags, db_buf_t val, int len, int64 offset, int rl)
{
  uint32 rn;
  dtp_t tail[4];
  memcpy (tail, val + len - 4, 4);
  rn = (uint32) (ptrlong) cpo->cpo_cmp_min;
  if (rn == offset && ASC_SHORTER == cpo->cpo_min_op)
    {
      cpo->cpo_cmp_max = (caddr_t) (ptrlong) row;
      return COL_NO_ROW;
    }
  if (rn < offset)
    {
      cpo->cpo_cmp_max = (caddr_t) (ptrlong) row;
      return COL_NO_ROW;
    }
  return row + rl;
}


int
itc_bad_len_ins (it_cursor_t * itc, db_buf_t ce, int64 delta, int dtp_cmp, int rc)
{
  int set, row;
  int from, to, row_of_ce = itc->itc_row_of_ce, ce_rows;
  col_pos_t cpo;
  if (1 || ASC_NUMBERS == dtp_cmp)
    return itc_num_cast_search (itc, ce, delta, dtp_cmp, rc);
  GPF_T1
      ("not to come here.  All comparisons needing cast or with different length intlike compressed strings go via the general case");
  set = itc->itc_set - itc->itc_col_first_set;
  if (ASC_NUMBERS != dtp_cmp && CE_FIND_LAST == rc)
    {
      itc->itc_ranges[set].r_end = itc->itc_row_of_ce;
      return CE_NEXT_SET;
    }
  if (SM_INSERT != itc->itc_search_mode)
    {
      row = itc->itc_row_of_ce;
      if (!itc->itc_nth_key)
	itc_range (itc, row, row);
      else
	itc->itc_ranges[set].r_end = itc->itc_ranges[set].r_first;
      return CE_NEXT_SET;
    }
  cpo.cpo_min_op = dtp_cmp;
  cpo.cpo_value_cb = ce_bad_len_ins_cb;
  cpo.cpo_string = ce;
  cpo.cpo_ce_row_no = 0;
  cpo.cpo_bytes = ce_total_bytes (ce);
  cpo.cpo_cmp_max = (caddr_t) COL_NO_ROW;
  cpo.cpo_cmp_min = (caddr_t) (ptrlong) delta;
  cpo.cpo_rc = -1;
  ce_rows = ce_n_values (ce);
  if (!itc->itc_nth_key)
    {
      from = 0;
      to = ce_rows;
    }
  else
    {
      from = itc->itc_ranges[set].r_first - row_of_ce;
      to = itc->itc_ranges[set].r_end - row_of_ce;
      if (from < 0)
	from = 0;
      if (to > ce_rows)
	to = ce_rows;
    }
  cpo.cpo_ce_op = NULL;
  cpo.cpo_itc = NULL;
  cpo.cpo_pm = NULL;
  cs_decode (&cpo, from, to);
  row = (ptrlong) cpo.cpo_cmp_max;
  if (COL_NO_ROW != row)
    row = itc->itc_row_of_ce + row;
  if (itc->itc_nth_key)
    {
      if (COL_NO_ROW == row)
	{
	  if (itc->itc_ranges[set].r_end > row_of_ce + ce_rows)
	    {
	      itc->itc_ranges[set].r_first = COL_NO_ROW;
	      return CE_DONE;
	    }
	  itc->itc_ranges[set].r_first = itc->itc_ranges[set].r_end;
	  return CE_NEXT_SET;
	}
      itc->itc_ranges[set].r_first = itc->itc_ranges[set].r_end = row;
      return CE_NEXT_SET;
    }
  else
    {
      itc_range (itc, row, row);
      if (COL_NO_ROW == row)
	return CE_DONE;		/* not here, look in next */
      return CE_NEXT_SET;	/* the insert point was here, there was a gt in the ce */
    }
}


int
dv_bin_equal (db_buf_t dv1, db_buf_t dv2)
{
  int l1, l2;
  if (*dv1 != *dv2)
    return 0;
  DB_BUF_TLEN (l1, *dv1, dv1);
  DB_BUF_TLEN (l2, *dv2, dv2);
  if (l1 != l2)
    return 0;
  memcmp_8 (dv1, dv2, l1, neq);
  return 1;
neq:
  return 0;
}


extern int col_ins_error;

int
ce_bad_dtp (it_cursor_t * itc, db_buf_t ce, int set, int row_of_ce, int ce_n_values, int nth_key, int rc, int dtp_cmp)
{
  if (ASC_NUMBERS == dtp_cmp)
    {
      dtp_t dtp;
      int64 delta = itc_any_param (itc, nth_key, &dtp);
      return itc_num_cast_search (itc, ce, delta, dtp_cmp, rc);
    }
  if (CE_FIND_LAST == rc)
    {
      if (DVC_DTP_LESS == dtp_cmp && (!(nth_key && itc->itc_ranges[set].r_end <= row_of_ce)))
	{
	  /* if range extends to the ce and the ce is dtp lt the previous ce then the index is out of order */
	  bing ();
	  if (!allow_non_unq_range)
	    {
	      itc->itc_reset_after_seg = col_ins_error = 1;
	      GPF_T1 ("can't have a range that shifts from compatble to less dtp in next ce");
	    }
	}
      itc->itc_ranges[set].r_end = row_of_ce;
      /* could be the same params repeat, so will need to replicate the just closed set for each repeat of nth_key first keys */
      for (;;)
	{
	  if (set + itc->itc_col_first_set + 1 >= itc->itc_n_sets)
	    return CE_SET_END;
	  itc->itc_set = set + 1 + itc->itc_col_first_set;
	  if (SET_ALL_EQ == itc_next_set_cmp (itc, nth_key))
	    {
	      if (set + 1 == itc->itc_range_fill)
		itc_range (itc, itc->itc_ranges[set].r_first, itc->itc_ranges[set].r_end);
	      else
		{
		  itc->itc_ranges[set + 1].r_end = itc->itc_ranges[set].r_end;
		}
	      set++;
	    }
	  else
	    {
	      itc->itc_set = set + itc->itc_col_first_set;
	      break;
	    }
	}
      return CE_NEXT_SET;
    }
  if (!nth_key)
    {
      if (DVC_DTP_LESS == dtp_cmp)
	{
	  itc_range (itc, COL_NO_ROW, COL_NO_ROW);
	  return CE_DONE;
	}
      else
	itc_range (itc, row_of_ce, row_of_ce);
      return CE_NEXT_SET;
    }
  else
    {
      /* non first key.  See if the corresponding range is defined.  Might not be if a leading eqq was present */
      if (itc->itc_range_fill == set)
	{
	  int set_eq = itc_next_set_cmp (itc, nth_key);
	  if (SET_LEADING_EQ == set_eq)
	    {
	      if (DVC_DTP_LESS == dtp_cmp)
		{
		  itc_range (itc, COL_NO_ROW, COL_NO_ROW);
		  return CE_DONE;
		}
	      else
		GPF_T1 ("a lesser dtp cannot follow with leading key parts eq in search params");

	    }
	  return CE_SET_END;
	}
      if (itc->itc_ranges[set].r_first >= row_of_ce + ce_n_values)
	return CE_DONE;
      if (DVC_DTP_GREATER == dtp_cmp)
	{
	  itc->itc_ranges[set].r_end = MAX (itc->itc_ranges[set].r_first, row_of_ce);
	  return CE_NEXT_SET;
	}
      else
	{
	  /* all in this ce are less.  If range extends after the ce, take next ce, else the range starts at its end and we look at next set */
	  if (itc->itc_ranges[set].r_end > row_of_ce + ce_n_values)
	    {
	      itc->itc_ranges[set].r_first = COL_NO_ROW;
	      return CE_DONE;
	    }
	  itc->itc_ranges[set].r_first = itc->itc_ranges[set].r_end;
	  return CE_NEXT_SET;
	}
    }
  GPF_T1 ("itc bad dtp should have decided by now");
  return CE_DONE;
}

#define CE_BAD_DTP \
{ \
  int brc = \
   ce_bad_dtp (itc, ce, set, row_of_ce, ce_n_values,  nth_key,  rc,  dtp_cmp);\
return brc; \
}

#define ce_search_name ce_search_vec_int
#define COL_VAR int col; int64 value; dtp_t dtp; int dtp_cmp
#define CE_LEN CE_INTVEC_LENGTH (ce, ce_first, ce_bytes, ce_n_values, int)
#define CE_DTP DV_LONG_INT
#define NEW_VAL    value = itc_any_param (itc, nth_key, &dtp); \
  dtp_cmp = ce_typed_vec_dtp_compare (ce, dtp); \
  if (dtp_cmp != DVC_MATCH) \
    { CE_BAD_DTP; }

#define CEVC(n) col = LONG_REF_CA (ce_first + (n) * sizeof (int))
#define C_EQ  (col == value)
#define C_GT (col > value)
#define C_LT (col < value)

#include "cesearch.c"

#define ce_search_name ce_search_vec_int64
#define COL_VAR int64 col; int64 value; dtp_t dtp; int dtp_cmp
#define CE_LEN CE_INTVEC_LENGTH (ce, ce_first, ce_bytes, ce_n_values, int64)
#define CE_DTP DV_LONG_INT
#define NEW_VAL    value = itc_any_param (itc, nth_key, &dtp); \
  dtp_cmp = ce_typed_vec_dtp_compare (ce, dtp); \
  if (dtp_cmp != DVC_MATCH) \
    { CE_BAD_DTP; }

#define CEVC(n) col = INT64_REF_CA (ce_first + (n) * sizeof (int64))
#define C_EQ  (col == value)
#define C_GT (col > value)
#define C_LT (col < value)

#include "cesearch.c"




#define ce_search_name ce_search_vec_iri
#define COL_VAR iri_id_t col; iri_id_t value; dtp_t dtp; int dtp_cmp
#define CE_LEN CE_INTVEC_LENGTH (ce, ce_first, ce_bytes, ce_n_values, int)
#define CE_DTP DV_IRI_ID
#define NEW_VAL    value = itc_any_param (itc, nth_key, &dtp); \
  dtp_cmp = ce_typed_vec_dtp_compare (ce, dtp); \
  if (dtp_cmp != DVC_MATCH) \
    { CE_BAD_DTP; }

#define CEVC(n) col = (uint32)LONG_REF_CA (ce_first + (n) * sizeof (int))
#define C_EQ  (col == value)
#define C_GT (col > value)
#define C_LT (col < value)

#include "cesearch.c"

#define ce_search_name ce_search_vec_iri64
#define COL_VAR iri_id_t col; iri_id_t value; dtp_t dtp; int dtp_cmp
#define CE_LEN CE_INTVEC_LENGTH (ce, ce_first, ce_bytes, ce_n_values, iri_id_t)
#define CE_DTP DV_IRI_ID
#define NEW_VAL    value = itc_any_param (itc, nth_key, &dtp); \
  dtp_cmp = ce_typed_vec_dtp_compare (ce, dtp); \
  if (dtp_cmp != DVC_MATCH) \
    { CE_BAD_DTP; }

#define CEVC(n) col = INT64_REF_CA (ce_first + (n) * sizeof (iri_id_t))
#define C_EQ  (col == value)
#define C_GT (col > value)
#define C_LT (col < value)

#include "cesearch.c"


#define ce_search_name  ce_search_vec_any
#define COL_VAR db_buf_t col, value; dtp_t ctmp[MAX_FIXED_DV_BYTES]; short offset; int cmp_rc
#define CE_LEN   CE_2_LENGTH (ce, ce_first, ce_bytes, ce_n_values)
#define NEW_VAL value = itc_dv_param (itc, nth_key, ctmp);
#define CEVC(n)  ce_vec_any_val (ce_first, ce[0], ce_n_values, n, &col, &offset); cmp_rc = dv_compare_so (col, value, NULL, offset) & 0x7

#define C_EQ  (DVC_MATCH == cmp_rc)
#define C_GT (DVC_GREATER == cmp_rc)
#define C_LT (DVC_LESS == cmp_rc)

#include "cesearch.c"


#define ce_search_name ce_dict_1_int
#define COL_VAR int col
#define CEVC(n) col = LONG_REF_CA (ce + (n) * sizeof (int32))
#define C_EQ  (col == value)
#define C_GT (col > value)
#define C_LT (col < value)

#include "cedict1.c"

#define ce_search_name ce_dict_1_int64
#define COL_VAR int64 col
#define CEVC(n) col = INT64_REF_CA (ce + (n) * sizeof (int64))
#define C_EQ  (col == value)
#define C_GT (col > value)
#define C_LT (col < value)

#include "cedict1.c"


#define ce_search_name ce_dict_1_iri
#define COL_VAR iri_id_t col
#define CEVC(n) col = (uint32)LONG_REF_CA (ce + (n) * sizeof (int32))
#define C_EQ  (col == value)
#define C_GT (col > (iri_id_t)value)
#define C_LT (col < (iri_id_t)value)

#include "cedict1.c"


#define ce_search_name ce_dict_1_iri64
#define COL_VAR iri_id_t col
#define CEVC(n) col = INT64_REF_CA (ce + (n) * sizeof (int64))
#define C_EQ  (col == value)
#define C_GT (col > (iri_id_t)value)
#define C_LT (col < (iri_id_t)value)

#include "cedict1.c"


#define ce_search_name  ce_dict_1_any
#define COL_VAR db_buf_t col, value1 = (db_buf_t)(ptrlong)value; int cmp_rc, len
#define CEVC(n)  CE_ANY_NTH (ce, end, n, col, len); cmp_rc = dv_compare (col, value1, NULL, 0) & 0x7

#define C_EQ  (DVC_MATCH == cmp_rc)
#define C_GT (DVC_GREATER == cmp_rc)
#define C_LT (DVC_LESS == cmp_rc)

#include "cedict1.c"


#define ce_search_name  ce_dict_1_ins_any
#define COL_VAR db_buf_t col, value1 = (db_buf_t)(ptrlong)value; int cmp_rc, len
#define HAS_NCAST_EQ
#define CEVC(n) \
  { CE_ANY_NTH (ce, end, n, col, len); cmp_rc = dv_compare (col, value1, NULL, 0) & 0x7; \
    if (DVC_MATCH == cmp_rc && !dv_bin_equal (col, (db_buf_t)value)) *is_ncast_eq = 1; }

#define C_EQ  (DVC_MATCH == cmp_rc)
#define C_GT (DVC_GREATER == cmp_rc)
#define C_LT (DVC_LESS == cmp_rc)

#include "cedict1.c"

#undef HAS_NCAST_EQ

int
ce_dict_dtp_compare (db_buf_t ce, dtp_t dtp)
{
  dtp_t flags = ce[0];
  dtp_t cet = flags & CE_DTP_MASK, ce_dtp;
  if (CET_ANY == cet)
    return DVC_MATCH;
  else if (CET_INT == (cet & ~CE_IS_64))
    {
      if (DV_LONG_INT == dtp)
	return DVC_MATCH;
      if (IS_NUM_DTP (dtp))
	return ASC_NUMBERS;
      ce_dtp = DV_LONG_INT;
      goto ntype;
    }
  else if (CET_IRI == (cet & ~CE_IS_64))
    {
      if (DV_IRI_ID == dtp_canonical[dtp])
	return DVC_MATCH;
      ce_dtp = DV_IRI_ID;
    }
  else
    GPF_T1 ("dict ce of unknown content type");
ntype:
  if (IS_NUM_DTP (dtp))
    dtp = DV_LONG_INT;
  return ce_dtp > dtp ? DVC_DTP_GREATER : DVC_DTP_LESS;
}


db_buf_t
ce_dict_array (db_buf_t ce)
{
  dtp_t flags = ce[0];
  db_buf_t ce_first = CE_IS_SHORT & flags ? ce + 3 : ce + 5;
  int n_dict = ce_first[0];
  switch (flags & CE_DTP_MASK)
    {
    case CET_INT | CE_IS_IRI:
    case CET_INT:
      return ce_first + 1 + n_dict * sizeof (int32);
    case CET_INT | CE_IS_IRI | CE_IS_64:
    case CET_INT | CE_IS_64:
      return ce_first + 1 + n_dict * sizeof (int64);
    case CET_ANY:
      {
	int l;
	db_buf_t dict_ret;
	CE_ANY_NTH (ce_first + 1, n_dict, n_dict - 1, dict_ret, l);
	return dict_ret + l;
      }
    default:
      GPF_T1 ("unsupported dict type");
    }
  return 0;
}

int
ce_dict_key (db_buf_t ce, db_buf_t dict, int64 value, dtp_t dtp, db_buf_t * dict_ret, int *sz_ret)
{
  dtp_t flags = ce[0];
  db_buf_t ce_first = CE_IS_SHORT & flags ? ce + 3 : ce + 5;
  int n_dict = ce_first[0];
  *sz_ret = n_dict;
  switch (flags & CE_DTP_MASK)
    {
    case CET_INT:
      *dict_ret = ce_first + 1 + n_dict * sizeof (int32);
      return ce_dict_1_int (ce_first + 1, n_dict, value, dtp, flags);
    case CET_INT | CE_IS_64:
      *dict_ret = ce_first + 1 + n_dict * sizeof (int64);
      return ce_dict_1_int64 (ce_first + 1, n_dict, value, dtp, flags);
    case CET_INT | CE_IS_IRI:
      *dict_ret = ce_first + 1 + n_dict * sizeof (int32);
      return ce_dict_1_iri (ce_first + 1, n_dict, value, dtp, flags);
    case CET_INT | CE_IS_IRI | CE_IS_64:
      *dict_ret = ce_first + 1 + n_dict * sizeof (int64);
      return ce_dict_1_iri64 (ce_first + 1, n_dict, value, dtp, flags);
    case CET_ANY:
      {
	dtp_t ctmp[MAX_FIXED_DV_BYTES];
	int l;
	CE_ANY_NTH (ce_first + 1, n_dict, n_dict - 1, *dict_ret, l);
	*dict_ret += l;
	return ce_dict_1_any (ce_first + 1, n_dict, dv_if_needed (value, dtp, ctmp), dtp, flags);
      }
    default:
      GPF_T1 ("unsupported dict type");
    }
  return 0;
}


int
ce_dict_ins_any_key (db_buf_t ce, db_buf_t dict, int64 value, dtp_t dtp, db_buf_t * dict_ret, int *sz_ret, int *is_ncast_eq)
{
  dtp_t flags = ce[0];
  db_buf_t ce_first = CE_IS_SHORT & flags ? ce + 3 : ce + 5;
  int n_dict = ce_first[0];
  dtp_t ctmp[MAX_FIXED_DV_BYTES];
  int l;
  *sz_ret = n_dict;
  CE_ANY_NTH (ce_first + 1, n_dict, n_dict - 1, *dict_ret, l);
  *dict_ret += l;
  return ce_dict_1_ins_any (ce_first + 1, n_dict, dv_if_needed (value, dtp, ctmp), dtp, flags, is_ncast_eq);
}


#define ce_search_name ce_search_dict
#define COL_VAR int col; int64 value; dtp_t dtp; int dtp_cmp; \
  db_buf_t dict; int sz

#define CE_LEN CE_2_LENGTH (ce, ce_first, ce_bytes, ce_n_values)

#define NEW_VAL    value = itc_any_param (itc, nth_key, &dtp); \
  dtp_cmp = ce_dict_dtp_compare (ce, dtp); \
  if (dtp_cmp != DVC_MATCH) \
    { CE_BAD_DTP; } \
  value = ce_dict_key (ce, ce_first, value, dtp, &dict, &sz);


#define DICT_REF(d, sz, n)  \
  2 * (sz <= 16 ? ( (n) & 1 ? d[(n)/2] >> 4 : d[(n)/2] &0xf) : d[n])

#define CEVC(n) col = DICT_REF (dict, sz, n)
#define C_EQ  (col == value)
#define C_GT (col > value)
#define C_LT (col < value)

#include "cesearch.c"



db_buf_t
ce_body (db_buf_t ce, db_buf_t ce_first)
{
  int first_len;
  dtp_t flags = ce[0];
  dtp_t cet = flags & CE_DTP_MASK;
  if (CE_INTLIKE (flags))
    return (CE_IS_64 & flags) ? ce_first + 8 : ce_first + 4;
  if (CET_ANY == cet)
    {
      DB_BUF_TLEN (first_len, ce_first[0], ce_first);
      return ce_first + first_len;
    }
  first_len = *(ce_first++);
  if (first_len > 127)
    first_len = (first_len - 128) * 256 + *(ce_first++);
  return ce_first + first_len;
}


int64
itc_ce_value_offset (it_cursor_t * itc, db_buf_t ce, db_buf_t * body_ret, int *dtp_cmp)
{
  /* take a rl, rld or bitmap or int delta.  Decode 1st value in ce and return the int difference between this and the search param.  Byte 0 of body is returned body_ret.  If incomparable, body_ret is 0 and dtp_cmp is the orer of the dtps. *
   *  if int delta, consider that the last byte of val is length and special case with dv date */
  uint32 delta;
  dtp_t ctmp[MAX_FIXED_DV_BYTES];
  dtp_t param_dtp, ce_dtp;
  dtp_t col_dtp = itc->itc_col_spec->sp_cl.cl_sqt.sqt_dtp;
  int first_len, rc;
  dtp_t flags = ce[0];
  char is_int_delta = CE_INT_DELTA == (flags & CE_TYPE_MASK);
  db_buf_t ce_first;
  db_buf_t ce_first_val;
  int64 first;
  db_buf_t dv;
  if (CE_RL == (flags & CE_TYPE_MASK))
    ce_first = flags & CE_IS_SHORT ? ce + 2 : ce + 3;
  else
    ce_first = flags & CE_IS_SHORT ? ce + 3 : ce + 5;
  CE_FIRST;

  if (CE_INTLIKE (flags))
    {
      /* special case for compare of intlike ce with intlike or dv string param */
      int64 param = itc_any_param (itc, itc->itc_nth_key, &param_dtp);
      ce_dtp = (flags & CE_IS_IRI) ? DV_IRI_ID : DV_LONG_INT;
      if (DV_ANY == col_dtp)
	{
	  if (param_dtp != ce_dtp)
	    goto ntype;
	}
      if (is_int_delta)
	first &= CLEAR_LOW_BYTE;
      if (DV_IRI_ID == ce_dtp)
	{
	  if ((iri_id_t) param < (iri_id_t) first)
	    {
	      *body_ret = ce_first;
	      return -1;
	    }
	  if (((iri_id_t) param - (iri_id_t) first) > CE_INT_DELTA_MAX)
	    {
	      *body_ret = NULL;
	      *dtp_cmp = DVC_DTP_LESS;
	      return 0;
	    }
	}
      else
	{
	  if (param < first)
	    {
	      *body_ret = ce_first;
	      return -1;
	    }
	  if ((param - first) > CE_INT_DELTA_MAX)
	    {
	      *body_ret = NULL;
	      *dtp_cmp = DVC_DTP_LESS;
	      return 0;
	    }
	}
      *body_ret = ce_first;
      return param - first;
    }
  if (CET_CHARS == (flags & CE_DTP_MASK))
    {
      int len;
      uint32 delta;
      db_buf_t str = itc_string_param (itc, itc->itc_nth_key, &len, &param_dtp);
      if (DV_STRING != param_dtp)
	{
	  ce_dtp = DV_STRING;
	  goto ntype;
	}
      rc = asc_str_cmp (ce_first_val + (first_len > 127 ? 2 : 1), str, first_len, len, &delta, is_int_delta);
      if (rc > DVC_GREATER)
	{
	  *body_ret = NULL;
	  *dtp_cmp = rc;
	  return delta;
	}
      if (DVC_GREATER == rc)
	return -1;
      *body_ret = ce_first;
      return delta;
    }
  dv = itc_dv_param (itc, itc->itc_nth_key, ctmp);
  rc = asc_cmp_delta (ce_first_val, dv, &delta, is_int_delta);
  if (rc > DVC_GREATER)
    {
      if (DVC_GREATER == rc)
	rc = DVC_DTP_GREATER;
      *body_ret = NULL;
      *dtp_cmp = rc;
      return delta;
    }
  *body_ret = ce_first;
  if (DVC_GREATER == rc)
    return -1;
  return delta;
ntype:
  *body_ret = NULL;
  if (IS_NUM_DTP (ce_dtp) && IS_NUM_DTP (param_dtp))
    {
      *dtp_cmp = ASC_NUMBERS;
      return 0;
    }
  /* Because the range of num dtps is not contiguous, when comparing num to non-num by dtp, consider all nums as ints.
   * could get a < b and b < c and a > c if ,c num and b not num. */
  if (IS_NUM_DTP (ce_dtp))
    ce_dtp = DV_LONG_INT;
  if (IS_NUM_DTP (param_dtp))
    param_dtp = DV_LONG_INT;
  *dtp_cmp = ce_dtp < param_dtp ? DVC_DTP_LESS : DVC_DTP_GREATER;
  return 0;
}

#define NEW_VAL \
  value = itc_ce_value_offset (itc, ce, &ce_first, &dtp_cmp);	\
  if (!ce_first) {							\
    if (ASC_SHORTER <= dtp_cmp) \
      {int res = itc_bad_len_ins (itc, ce, value, dtp_cmp, rc); return res; } \
    CE_BAD_DTP; }


int
ce_search_rld (it_cursor_t * itc, db_buf_t ce, row_no_t row_of_ce, int rc, int nth_key)
{
  int set = itc->itc_set - itc->itc_col_first_set;
  int ce_n_values, n_bytes, dtp_cmp;
  int64 first = 0;
  int last_row = 0, at_or_above, below, delta_8 = 5;
  char no_look = 0;
  db_buf_t ce_end, f1, ce_cur;
  db_buf_t ce_first;
  int64 value;
  dtp_t byte, rl, delta;
  CE_2_LENGTH (ce, f1, n_bytes, ce_n_values);
  ce_end = f1 + n_bytes;
  ce_first = ce_body (ce, f1);
  ce_cur = ce_first;
  while (ce_cur < ce_end)
    {
      byte = *ce_cur;
      delta = byte >> 4;
      rl = byte & 0xf;
      if (!rl)
	{
	  first += delta;
	  ce_cur++;
	  continue;
	}
      first += delta;
      break;
    }
  NEW_VAL;
  if (0 == nth_key)
    {
      at_or_above = CE_FIND_FIRST == rc ? 0 : itc->itc_ranges[set].r_first - row_of_ce;
      below = ce_n_values;
    }
  else
    {
      at_or_above = itc->itc_ranges[set].r_first - row_of_ce;
      below = itc->itc_ranges[set].r_end - row_of_ce;
      if (below > ce_n_values)
	below = ce_n_values;
    }
  if (at_or_above < 0)
    at_or_above = 0;
  goto new_val;
  while (ce_cur < ce_end)
    {
      byte = *ce_cur;
      delta = byte >> 4;
      rl = byte & 0xf;
      if (!rl)
	{
	  first += delta;
	  ce_cur++;
	  continue;
	}
      first += delta;
    new_val:
      if (first == value)
	{
	  if (CE_FIND_FIRST == rc)
	    {
	      if (0 == nth_key)
		itc_range (itc, last_row + row_of_ce, COL_NO_ROW);
	      else
		{
		  if (last_row + rl < at_or_above)
		    goto skip;
		  if (last_row >= at_or_above)
		    itc->itc_ranges[set].r_first = MIN (itc->itc_ranges[set].r_end, last_row + row_of_ce);
		  if (below <= last_row + rl)
		    {
		      if (itc->itc_ranges[set].r_end > below + row_of_ce)
			return CE_CONTINUES;
		      itc->itc_ranges[set].r_end = MIN (itc->itc_ranges[set].r_end, row_of_ce + last_row + rl);
		      goto next_set;
		    }
		}
	      rc = CE_FIND_LAST;
	    }
	  else
	    {
	      if (below <= last_row + rl)
		{
		  if (itc->itc_ranges[set].r_end > below + row_of_ce)
		    return CE_CONTINUES;
		  goto next_set;
		}
	    }
	}
      else if (first > value)
	{
	  if (CE_FIND_FIRST == rc)
	    {
	      if (0 == nth_key)
		itc_range (itc, last_row + row_of_ce, last_row + row_of_ce);
	      else
		{
		  if (last_row + rl < at_or_above)
		    {
		      /* gt found before search range.  No hit, insert point below 1st of range. */
		      itc->itc_ranges[set].r_end = itc->itc_ranges[set].r_first;
		    }
		  else
		    {
		      /* if range given and falls in mid of  a gt stretch, the insert point is first of range, else it is start of the gt run */
		      row_no_t end = MAX (itc->itc_ranges[set].r_first, last_row + row_of_ce);
		      if (COL_NO_ROW == end)
			end = last_row + row_of_ce;
		      itc->itc_ranges[set].r_first = itc->itc_ranges[set].r_end = end;
		    }
		}
	      goto next_set;
	    }
	  else
	    {
	      itc->itc_ranges[set].r_end = last_row + row_of_ce;
	      goto next_set;
	    }
	}
    skip:
      if (nth_key > 0 && last_row + rl >= below)
	{
	  /* searched range finishes without eq or gt being found.  Means no hit and insertion point after the last of the range */
	  if (CE_FIND_LAST == rc)
	    {
	      if (below > 0)
		{
		  bing ();
		  if (!allow_non_unq_range)
		    GPF_T1 ("In rld it is suspect to find lt value in range when looking for last match");
		  itc->itc_reset_after_seg = col_ins_error = 1;
		}
	      goto next_set;
	    }
	  if (itc->itc_ranges[set].r_end - row_of_ce > below)
	    {
	      /* the range reaches beyond this ce, return to look in next */
	      itc->itc_ranges[set].r_first = COL_NO_ROW;
	      return CE_DONE;
	    }
	  itc->itc_ranges[set].r_first = itc->itc_ranges[set].r_end;
	  goto next_set;
	}
      last_row += rl;
      ce_cur++;
    recheck_8:
      if (!no_look && value - first > delta_8 && ce_end - ce_cur > 8)
	{
	  unsigned int64 r8 = *(unsigned int64 *) ce_cur;
	  unsigned int64 d8 = r8 >> 4;
	  d8 &= 0x0f0f0f0f0f0f0f0f;
	  add8 (d8);
	  delta_8 = d8;
	  if (first + d8 < value)
	    {
	      first += d8;
	      ce_cur += 8;
	      r8 &= 0x0f0f0f0f0f0f0f0f;
	      add8 (r8);
	      last_row += r8;
	      if (last_row >= below)
		{
		  last_row -= r8;
		  first -= d8;
		  ce_cur -= 8;
		  no_look = 1;
		}
	      else
		goto recheck_8;
	    }
	  no_look = 1;
	}
    }
  if (first == value)
    {
      if (CE_FIND_LAST == rc)
	{
	  if (0 == nth_key)
	    itc->itc_ranges[set].r_end = COL_NO_ROW;
	  return CE_CONTINUES;
	}
      GPF_T1 ("not supposed to hity end with eq still looking for 1st");
    }
  /* reached end without eq or gt.  Means no hit and insertion point after last */
  if (0 == nth_key && CE_FIND_FIRST == rc)
    itc_range (itc, COL_NO_ROW, COL_NO_ROW);
  else
    itc->itc_ranges[set].r_first = COL_NO_ROW;
  return CE_DONE;
next_set:
  {
    int set_eq;
    if (itc->itc_reset_after_seg)
      return CE_DONE;
    no_look = 0;
    rc = CE_FIND_FIRST;
    set++;
    if (itc->itc_n_sets <= set + itc->itc_col_first_set)
      return CE_SET_END;
    itc->itc_set = set + itc->itc_col_first_set;
    set_eq = itc_next_set_cmp (itc, nth_key);
    if (SET_EQ_RESET == set_eq)
      {
	itc->itc_set--;
	itc->itc_reset_after_seg = 1;
	return CE_DONE;
      }
    if (SET_ALL_EQ == set_eq)
      {
	set = itc->itc_set - itc->itc_col_first_set;
	if (0 == nth_key || set == itc->itc_range_fill)
	  itc_range (itc, 0, 0);
	itc->itc_ranges[set].r_first = itc->itc_ranges[set - 1].r_first;
	itc->itc_ranges[set].r_end = itc->itc_ranges[set - 1].r_end;
	goto next_set;
      }
    /* since key did not repeat, next set is to the right of the previous if 1. 1st key or initial range is eq */
    CE_END_CK;
    NEW_VAL;
    if (0 == nth_key)
      {
	at_or_above = 0;
	below = ce_n_values;
	goto new_val;
      }
    if (SET_LEADING_EQ == set_eq && itc->itc_range_fill == set)
      {
	/* non 1st key part opens new range because open ended in previous key parts */
	itc_range (itc, COL_NO_ROW, COL_NO_ROW);
	at_or_above = itc->itc_ranges[set - 1].r_end - row_of_ce;
	if (at_or_above < 0)
	  at_or_above = 0;
	itc->itc_ranges[set].r_first = at_or_above + row_of_ce;	/* sure to be here or later, if were not set, here, we could get a lower number based on last row and rl since a matching run can start below the end of last range.  The last range need not be a match, could also have been a bounded interval determined by prev key part with no match in this ce */
	below = ce_n_values;
	goto new_val;
      }
    at_or_above = itc->itc_ranges[set].r_first - row_of_ce;
    if (at_or_above < 0)
      at_or_above = 0;
    below = itc->itc_ranges[set].r_end - row_of_ce;
    if (below > ce_n_values)
      below = ce_n_values;
    if (at_or_above == below)
      goto next_set;
    goto new_val;
  }
}


int
ce_search_rl (it_cursor_t * itc, db_buf_t ce, row_no_t row_of_ce, int rc, int nth_key)
{
  dtp_t flags = ce[0];
  int set = itc->itc_set - itc->itc_col_first_set;
  int ce_n_values, dtp_cmp;
  int64 first = 0;
  int at_or_above, below;
  db_buf_t ce_first;
  int64 value;
  int rl;
  row_no_t start;
  ce_n_values = rl = flags & CE_IS_SHORT ? ce[1] : SHORT_REF_CA (ce + 1);
  NEW_VAL;
  if (0 == nth_key)
    {
      at_or_above = 0;
      below = ce_n_values;
    }
  else
    {
      at_or_above = itc->itc_ranges[set].r_first - row_of_ce;
      below = itc->itc_ranges[set].r_end - row_of_ce;
      if (below > ce_n_values)
	below = ce_n_values;
    }
  if (at_or_above < 0)
    at_or_above = 0;
  if (at_or_above == below)
    goto next_set;
new_val:
  if (first == value)
    {
      if (CE_FIND_LAST == rc)
	{
	  if (below <= rl && nth_key > 0 && itc->itc_ranges[set].r_end - row_of_ce <= below)
	    {
	      itc->itc_ranges[set].r_end = below + row_of_ce;
	      goto next_set;
	    }
	  return CE_CONTINUES;
	}
      if (0 == nth_key)
	{
	  itc_range (itc, row_of_ce, COL_NO_ROW);
	  return CE_CONTINUES;
	}
      itc->itc_ranges[set].r_first = at_or_above + row_of_ce;
      if (itc->itc_ranges[set].r_end - row_of_ce <= rl)
	goto next_set;		/* range ends in this run with eq */
      return CE_CONTINUES;
    }
  else if (first > value)
    {
      if (CE_FIND_LAST == rc)
	{
	  itc->itc_ranges[set].r_end = row_of_ce;
	  goto next_set;
	}
      if (0 == nth_key)
	{
	  itc_range (itc, row_of_ce, row_of_ce);
	  goto next_set;
	}
      /* gt found before search range.  No hit, insert point below 1st of range. */
      start = row_of_ce;
      if (itc->itc_ranges[set].r_first != COL_NO_ROW)
	start = MAX (start, itc->itc_ranges[set].r_first);
      itc->itc_ranges[set].r_end = itc->itc_ranges[set].r_first = start;
      goto next_set;
    }
  else
    {
      /* ce is less, no match, insert point after or at end of range */
      if (CE_FIND_LAST == rc)
	{
#ifdef DEBUG
	  QNCAST (query_instance_t, qi, itc->itc_out_state);
	  if (itc->itc_insert_key) 
	    log_error ("error looking ce on index %s", itc->itc_insert_key->key_name ? itc->itc_insert_key->key_name : "<temp>");
	  if (qi && qi->qi_query && qi->qi_query->qr_text)
	    log_error ("query text: %s", qi->qi_query->qr_text);  
#endif
	  GPF_T1 ("not supposed to hit lt rl ce if looking for end of range");
	}
      if (0 == nth_key)
	itc_range (itc, COL_NO_ROW, COL_NO_ROW);
      else
	{
	  if (itc->itc_ranges[set].r_end - row_of_ce <= rl)
	    {
	      itc->itc_ranges[set].r_first = itc->itc_ranges[set].r_end;
	      goto next_set;
	    }
	  itc->itc_ranges[set].r_first = COL_NO_ROW;
	}
      return CE_DONE;
    }
next_set:
  {
    int set_eq;
    if (itc->itc_reset_after_seg)
      return CE_DONE;
    rc = CE_FIND_FIRST;
    set++;
    if (itc->itc_n_sets <= set + itc->itc_col_first_set)
      return CE_SET_END;
    itc->itc_set = set + itc->itc_col_first_set;
    set_eq = itc_next_set_cmp (itc, nth_key);
    if (SET_EQ_RESET == set_eq)
      {
	itc->itc_set--;
	itc->itc_reset_after_seg = 1;
	return CE_DONE;
      }
    if (SET_ALL_EQ == set_eq)
      {
	set = itc->itc_set - itc->itc_col_first_set;
	if (0 == nth_key || set == itc->itc_range_fill)
	  itc_range (itc, 0, 0);
	itc->itc_ranges[set].r_first = itc->itc_ranges[set - 1].r_first;
	itc->itc_ranges[set].r_end = itc->itc_ranges[set - 1].r_end;
	goto next_set;
      }
    /* since key did not repeat, next set is to the right of the previous if 1. 1st key or initial range is eq */
    CE_END_CK;
    NEW_VAL;
    if (0 == nth_key)
      {
	at_or_above = 0;
	below = ce_n_values;
	goto new_val;
      }
    if (SET_LEADING_EQ == set_eq && itc->itc_range_fill == set)
      {
	/* non 1st key part opens new range because open ended in previous key parts */
	itc_range (itc, COL_NO_ROW, COL_NO_ROW);
	at_or_above = itc->itc_ranges[set - 1].r_end - row_of_ce;
	itc->itc_ranges[set].r_first = at_or_above + row_of_ce;	/* could have a bounded range not matching followed by leading eq that matched and if so, start is end of last and not start of ce */
	below = ce_n_values;
	goto new_val;
      }
    at_or_above = itc->itc_ranges[set].r_first - row_of_ce;
    if (at_or_above < 0)
      at_or_above = 0;
    below = itc->itc_ranges[set].r_end - row_of_ce;
    if (below > ce_n_values)
      below = ce_n_values;
    if (at_or_above == below)
      goto next_set;
    goto new_val;
  }
}


extern unsigned char byte_logcount[256];

int
ce_bm_nth (db_buf_t bits, int val, int *counted_ret, int *n_ret)
{
  /* return row no within ce of val.  val 0 is 0, val 1 is bit 0 of byte 0. */
  int last, inx, c = 0, in_last, counted_to;
  if (!val)
    return 0;
  val--;
  last = val >> 3;
  counted_to = *counted_ret;
  c = *n_ret;
  if (last < counted_to)
    {
      counted_to = 0;
      c = 0;
    }
  for (inx = counted_to; inx + 8 < last; inx += 8)
    {
      c += byte_logcount[bits[inx]]
	  + byte_logcount[bits[inx + 1]]
	  + byte_logcount[bits[inx + 2]]
	  + byte_logcount[bits[inx + 3]]
	  + byte_logcount[bits[inx + 4]]
	  + byte_logcount[bits[inx + 5]] + byte_logcount[bits[inx + 6]] + byte_logcount[bits[inx + 7]];
    }
  counted_to = inx;
  for (inx = counted_to; inx < last; inx++)
    c += byte_logcount[bits[inx]];
  *counted_ret = inx;
  *n_ret = c;
  in_last = val & 0x7;
  if (in_last)
    {
      int last_mask = (1 << in_last) - 1;
      dtp_t last_byte = bits[last] & last_mask;
      c += byte_logcount[last_byte];
    }
  return c + 1;
}


int
ce_search_bm (it_cursor_t * itc, db_buf_t ce, row_no_t row_of_ce, int rc, int nth_key)
{
  int counted_to = 0, n_counted = 0;
  int set = itc->itc_set - itc->itc_col_first_set;
  int bit, offset, ce_n_values, n_bytes, bm_bytes, dtp_cmp;
  int nth, at_or_above, below;
  db_buf_t ce_first, ce_first_val;
  int64 value;
  CE_2_LENGTH (ce, ce_first, n_bytes, ce_n_values);
  ce_first_val = ce_first;
  NEW_VAL;
  bm_bytes = n_bytes - (ce_first - ce_first_val);
  if (0 == nth_key)
    {
      at_or_above = CE_FIND_FIRST == rc ? 0 : itc->itc_ranges[set].r_first - row_of_ce;
      below = ce_n_values;
    }
  else
    {
      at_or_above = itc->itc_ranges[set].r_first - row_of_ce;
      below = itc->itc_ranges[set].r_end - row_of_ce;
      if (below > ce_n_values)
	below = ce_n_values;
    }
  if (at_or_above < 0)
    at_or_above = 0;
new_val:
  if (value < 0)
    {
      if (CE_FIND_LAST == rc)
	{
	  itc->itc_ranges[set].r_end = row_of_ce;
	  goto next_set;
	}
      if (0 == nth_key)
	itc_range (itc, row_of_ce, row_of_ce);
      else
	itc->itc_ranges[set].r_first = itc->itc_ranges[set].r_end = at_or_above + row_of_ce;
      goto next_set;
    }
  if (0 == value)
    goto found;
  offset = (value - 1) >> 3;
  bit = (value - 1) & 0x7;
  if (offset >= bm_bytes)
    goto not_found;
  if (ce_first[offset] & (1 << bit))
    goto found;
not_found:
  if (CE_FIND_LAST == rc)
    {
      itc->itc_ranges[set].r_end = row_of_ce;
      goto next_set;
    }
  if (offset >= bm_bytes)
    nth = ce_n_values;
  else
    nth = ce_bm_nth (ce_first, value, &counted_to, &n_counted);
  if (0 == nth_key)
    {
      if (nth == ce_n_values)
	{
	  itc_range (itc, COL_NO_ROW, COL_NO_ROW);
	  return CE_DONE;
	}
      else
	itc_range (itc, nth + row_of_ce, nth + row_of_ce);
      goto next_set;
    }
  if (nth < at_or_above)
    itc->itc_ranges[set].r_first = itc->itc_ranges[set].r_end = at_or_above + row_of_ce;
  else if (nth >= below)
    {
      itc->itc_ranges[set].r_first = below + row_of_ce;
      if (below == ce_n_values)
	{
	  itc->itc_ranges[set].r_first = COL_NO_ROW;
	  return CE_DONE;
	}
    }
  else
    {
      /* bit not set and in range on non 1st key. */
      itc->itc_ranges[set].r_first = itc->itc_ranges[set].r_end = row_of_ce + nth;
      goto next_set;
    }
  goto next_set;
found:
  nth = ce_bm_nth (ce_first, value, &counted_to, &n_counted);
  if (nth >= at_or_above && nth < below)
    {
      if (CE_FIND_LAST == rc)
	{
	  if (nth + 1 == ce_n_values)
	    return CE_CONTINUES;
	  itc->itc_ranges[set].r_end = row_of_ce + nth + 1;
	  goto next_set;
	}
      if (0 == nth_key)
	itc_range (itc, nth + row_of_ce, nth + row_of_ce + 1);
      else
	itc->itc_ranges[set].r_first = nth + row_of_ce;
      if (nth + 1 == ce_n_values)
	{
	  if (0 == nth_key)
	    itc->itc_ranges[set].r_end = COL_NO_ROW;
	  return CE_CONTINUES;
	}
      itc->itc_ranges[set].r_end = nth + row_of_ce + 1;
      goto next_set;
    }
  else
    {
      if (0 == nth_key)
	{
	  if (CE_FIND_LAST == rc)
	    {
	      /* can be batch became full last time, now getting rest of the matches but position one after the hit, so the range ends at its start */
	      itc->itc_ranges[set].r_end = itc->itc_ranges[set].r_first;
	      goto next_set;
	    }
	  GPF_T1 ("bm match not in range yet 1st key part, so range is the whole bm");
	}
      if (CE_FIND_LAST == rc)
	{
	  if (nth >= itc->itc_ranges[set].r_end - row_of_ce)
	    goto next_set;
	  itc->itc_ranges[set].r_end = 1 == ce_n_values ? COL_NO_ROW : MAX (itc->itc_ranges[set].r_first, row_of_ce + 1);	/* if 1 in ce and eq, continues, if more in ce, then 1st matched but 2nd always gt */
	  goto next_set;
	}
      if (nth < at_or_above)
	{
	  itc->itc_ranges[set].r_first = itc->itc_ranges[set].r_end = at_or_above + row_of_ce;
	  goto next_set;
	}
      else if (nth >= below)
	{
	  itc->itc_ranges[set].r_first = below + row_of_ce;
	  if (below == ce_n_values)
	    {
	      itc->itc_ranges[set].r_first = COL_NO_ROW;
	      return CE_CONTINUES;
	    }
	  goto next_set;
	}
    }
next_set:
  {
    int set_eq;
    if (itc->itc_reset_after_seg)
      return CE_DONE;
    rc = CE_FIND_FIRST;
    set++;
    if (itc->itc_n_sets <= set + itc->itc_col_first_set)
      return CE_SET_END;
    itc->itc_set = set + itc->itc_col_first_set;
    set_eq = itc_next_set_cmp (itc, nth_key);
    if (SET_EQ_RESET == set_eq)
      {
	itc->itc_set--;
	itc->itc_reset_after_seg = 1;
	return CE_DONE;
      }
    if (SET_ALL_EQ == set_eq)
      {
	set = itc->itc_set - itc->itc_col_first_set;
	if (0 == nth_key || set == itc->itc_range_fill)
	  itc_range (itc, 0, 0);
	itc->itc_ranges[set].r_first = itc->itc_ranges[set - 1].r_first;
	itc->itc_ranges[set].r_end = itc->itc_ranges[set - 1].r_end;
	goto next_set;
      }
    /* since key did not repeat, next set is to the right of the previous if 1. 1st key or initial range is eq */
    CE_END_CK;
    NEW_VAL;
    bm_bytes = n_bytes - (ce_first - ce_first_val);
    if (0 == nth_key)
      {
	at_or_above = 0;
	below = ce_n_values;
	goto new_val;
      }
    if (SET_LEADING_EQ == set_eq && itc->itc_range_fill == set)
      {
	/* non 1st key part opens new range because open ended in previous key parts */
	itc_range (itc, COL_NO_ROW, COL_NO_ROW);
	at_or_above = itc->itc_ranges[set - 1].r_end - row_of_ce;
	if (at_or_above < 0)
	  at_or_above = 0;
	below = ce_n_values;
	goto new_val;
      }
    at_or_above = itc->itc_ranges[set].r_first - row_of_ce;
    if (at_or_above < 0)
      at_or_above = 0;
    below = itc->itc_ranges[set].r_end - row_of_ce;
    if (below > ce_n_values)
      below = ce_n_values;
    if (at_or_above == below)
      goto next_set;
    goto new_val;
  }
}

int
ce_int_delta_bin_search (db_buf_t ce_first, int skip, int last, int64 base, int64 value)
{
  int64 first;
  if (last - skip < 4)
    return skip;
  for (;;)
    {
      int guess;
      uint32 n;
      if (last - skip < 2)
	return skip;
      guess = (last + skip) / 2;
      n = SHORT_REF_CA (ce_first + 2 * guess);
      first = base + n;
      if (first < value)
	skip = guess;
      else
	last = guess;
    }
}


int
ce_search_int_delta (it_cursor_t * itc, db_buf_t ce, row_no_t row_of_ce, int rc, int nth_key)
{
  int64 base = 0, base_1 = 0;
  uint32 d, run, run1, resume_run;
  dtp_t flags = ce[0];
  int hl = CE_IS_SHORT & flags ? 3 : 5;
  int set = itc->itc_set - itc->itc_col_first_set;
  int ce_n_values, n_bytes, dtp_cmp;
  int64 first = 0;
  int last_row = 0, at_or_above, below, to, skip, resume_last_row;
  db_buf_t ce_end, f1, ce_cur, ce_init_first, ce_first_val;
  db_buf_t ce_first, resume_ce_first;
  int64 value;
  CE_2_LENGTH (ce, f1, n_bytes, ce_n_values);
  ce_first_val = ce + hl;
  ce_end = f1 + n_bytes;
  ce_init_first = ce_first = ce_body (ce, f1);
  NEW_VAL;
  if (0 == nth_key)
    {
      at_or_above = CE_FIND_FIRST == rc ? 0 : itc->itc_ranges[set].r_first - row_of_ce;
      below = ce_n_values;
    }
  else
    {
      at_or_above = itc->itc_ranges[set].r_first - row_of_ce;
      below = itc->itc_ranges[set].r_end - row_of_ce;
      if (below > ce_n_values)
	below = ce_n_values;
    }
  if (at_or_above < 0)
    at_or_above = 0;
  ce_cur = ce_first;
  ce_first = ce_init_first;
  last_row = 0;
  if (!CE_INTLIKE (flags))
    {
      if (DV_DATE == any_ce_dtp (ce_first_val))
	{
	  run1 = run = ce_first_val[3];
	  base_1 = 0;
	}
      else
	{
	  base_1 = 0;
	  run1 = run = (dtp_t) ce_first[-1];
	}
    }
  else
    {
      base_1 = 0;
      run1 = run = ce_first_int_low_byte (ce, ce_first);
    }
  base = base_1;
  ce_end = ce + hl + n_bytes;
  first = 0;
  to = below;
  skip = at_or_above;
  ce_first = ce_init_first;
  resume_ce_first = ce_first;
  resume_last_row = 0;
  resume_run = run;
  if (at_or_above == below)
    goto next_set;
new_val:

  while (ce_first < ce_end)
    {
      if (!run)
	;
      else if (skip >= run)
	{
	  skip -= run;
	  last_row += run;
	}
      else
	{
	  /* get values from this run */
	  int last = MIN (run, to - last_row), inx;
	  if (CE_FIND_FIRST == rc)
	    skip = ce_int_delta_bin_search (ce_first, skip, last, base, value);
	  last_row += skip;

	  for (inx = skip; inx < last; inx++)
	    {
	      uint32 n = SHORT_REF_CA (ce_first + 2 * inx);
	      if (0 && !CE_INTLIKE (flags))
		n -= run1;	/* the 1st run length is the last byte of the base val so compensate */

	      first = base + n;

	      if (first == value)
		{
		  if (CE_FIND_FIRST == rc)
		    {
		      if (0 == nth_key)
			itc_range (itc, last_row + row_of_ce, COL_NO_ROW);
		      else
			{
			  itc->itc_ranges[set].r_first = MIN (itc->itc_ranges[set].r_end, last_row + row_of_ce);
			}
		      rc = CE_FIND_LAST;
		    }
		  else
		    {
		      if (below <= last_row + 1)
			{
			  if (itc->itc_ranges[set].r_end > below + row_of_ce)
			    return CE_CONTINUES;
			  goto next_set;
			}
		    }
		}
	      else if (first > value)
		{
		  if (CE_FIND_FIRST == rc)
		    {
		      if (0 == nth_key)
			itc_range (itc, last_row + row_of_ce, last_row + row_of_ce);
		      else
			{
			  itc->itc_ranges[set].r_first = itc->itc_ranges[set].r_end = last_row + row_of_ce;
			}
		      goto next_set;
		    }
		  else
		    {
		      itc->itc_ranges[set].r_end = last_row + row_of_ce;
		      goto next_set;
		    }
		}

	      last_row++;
	      if (last_row == below)
		{
		  if (!nth_key)
		    break;
		  if (below < itc->itc_ranges[set].r_end - row_of_ce)
		    {
		      if (CE_FIND_LAST == rc)
			return CE_CONTINUES;
		      itc->itc_ranges[set].r_first = COL_NO_ROW;
		      return CE_DONE;
		    }
		  if (CE_FIND_LAST == rc)
		    goto next_set;
		  itc->itc_ranges[set].r_first = itc->itc_ranges[set].r_end;
		  goto next_set;
		  break;
		}
	    }
	  skip = 0;
	}
      ce_first += run * 2;
      if (ce_first >= ce_end)
	break;
      if (last_row >= to)
	{
	  if (!nth_key)
	    GPF_T1 ("normally not here for 1st key");
	  if (CE_FIND_FIRST == rc && value < first)
	    itc->itc_ranges[set].r_first = itc->itc_ranges[set].r_end;
	  goto next_set;
	}
      d = LONG_REF_NA (ce_first);
      ce_first += 4;
      run = d & 0xff;
      base = base_1 + (d & CLEAR_LOW_BYTE);
      resume_ce_first = ce_first;
      resume_last_row = last_row;
      resume_run = run;
    }
  /* reached end without finding. */
  if (first == value)
    {
      if (CE_FIND_LAST == rc)
	{
	  itc->itc_ranges[set].r_end = COL_NO_ROW;
	  return CE_CONTINUES;
	}
      GPF_T1 ("not supposed to hity end with eq still looking for 1st");
    }
  if (0 == nth_key && CE_FIND_FIRST == rc)
    itc_range (itc, COL_NO_ROW, COL_NO_ROW);
  else
    itc->itc_ranges[set].r_first = COL_NO_ROW;
  return CE_DONE;

next_set:
  {
    int set_eq;
    if (itc->itc_reset_after_seg)
      return CE_DONE;
    rc = CE_FIND_FIRST;
    set++;
    if (itc->itc_n_sets <= set + itc->itc_col_first_set)
      return CE_SET_END;
    itc->itc_set = set + itc->itc_col_first_set;
    set_eq = itc_next_set_cmp (itc, nth_key);
    if (SET_EQ_RESET == set_eq)
      {
	itc->itc_set--;
	itc->itc_reset_after_seg = 1;
	return CE_DONE;
      }
    if (SET_ALL_EQ == set_eq)
      {
	set = itc->itc_set - itc->itc_col_first_set;
	if (0 == nth_key || set == itc->itc_range_fill)
	  itc_range (itc, 0, 0);
	itc->itc_ranges[set].r_first = itc->itc_ranges[set - 1].r_first;
	itc->itc_ranges[set].r_end = itc->itc_ranges[set - 1].r_end;
	goto next_set;
      }
    /* since key did not repeat, next set is to the right of the previous if 1. 1st key or initial range is eq */
    CE_END_CK;
    NEW_VAL;
    if (0 == nth_key)
      {
	at_or_above = 0;
	to = below = ce_n_values;
	last_row = resume_last_row;
	ce_first = resume_ce_first;
	skip = itc->itc_ranges[set - 1].r_end - row_of_ce - resume_last_row;
	goto new_val;
      }
    if (SET_LEADING_EQ == set_eq && itc->itc_range_fill == set)
      {
	/* non 1st key part opens new range because open ended in previous key parts */
	itc_range (itc, COL_NO_ROW, COL_NO_ROW);
	at_or_above = itc->itc_ranges[set - 1].r_end - row_of_ce;
	if (at_or_above < 0)
	  at_or_above = 0;
	to = below = ce_n_values;
	last_row = resume_last_row;
	ce_first = resume_ce_first;
	skip = at_or_above - resume_last_row;
	goto new_val;
      }
    at_or_above = itc->itc_ranges[set].r_first - row_of_ce;
    if (at_or_above < 0)
      at_or_above = 0;
    below = itc->itc_ranges[set].r_end - row_of_ce;
    if (below > ce_n_values)
      below = ce_n_values;
    if (at_or_above == below)
      goto next_set;
    to = below;
    ce_first = resume_ce_first;
    last_row = resume_last_row;
    skip = at_or_above > resume_last_row ? at_or_above - resume_last_row : 0;
    goto new_val;
  }
}


int
ce_search (it_cursor_t * itc, db_buf_t ce, row_no_t row_of_ce, int rc, int nth_key)
{
  switch (*ce & ~CE_IS_SHORT)
    {
    case CE_VEC | CE_IS_64:
      return ce_search_vec_int64 (itc, ce, row_of_ce, rc, nth_key);
    case CE_VEC | CE_IS_IRI:
      return ce_search_vec_iri (itc, ce, row_of_ce, rc, nth_key);
    case CE_VEC | CE_IS_IRI | CE_IS_64:
      return ce_search_vec_iri64 (itc, ce, row_of_ce, rc, nth_key);

    case CE_VEC:
      return ce_search_vec_int (itc, ce, row_of_ce, rc, nth_key);
    case CE_VEC | CET_ANY:
      return ce_search_vec_any (itc, ce, row_of_ce, rc, nth_key);
    case CE_ALL_VARIANTS (CE_RL_DELTA):
      return ce_search_rld (itc, ce, row_of_ce, rc, nth_key);
    case CE_ALL_VARIANTS (CE_RL):
      return ce_search_rl (itc, ce, row_of_ce, rc, nth_key);
    case CE_ALL_VARIANTS (CE_BITS):
      return ce_search_bm (itc, ce, row_of_ce, rc, nth_key);
    case CE_ALL_VARIANTS (CE_DICT):
      return ce_search_dict (itc, ce, row_of_ce, rc, nth_key);
    case CE_ALL_VARIANTS (CE_INT_DELTA):
      return ce_search_int_delta (itc, ce, row_of_ce, rc, nth_key);

    default:
      GPF_T1 ("unsupported ce type in ce_search_vec");
    }
  return 0;
}
