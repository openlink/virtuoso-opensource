/*
 *  colin.c
 *
 *  $Id$
 *
 *  Special cases of column ops
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

#include "sqlnode.h"
#include "date.h"
#include "datesupp.h"


/* ce_ <ce type> _ <ce content> _ <sets or range> _ <decode or filter.
  e.g. ce_vec_any_sets_lte, ce_dict_iri_range_decode
  ce_intd_date_range_gte, ce_rld_int_sets_decode

 7 ce types * 5 data types * 2 modes * 6 ops = 420 cases, not all have a dedicated function

lt, gt, eq, decode, in hash, hash_fill

The decodes can set the dtp of the output dc and can optimize according to whether dc is inline or any.

*/




int64
cpo_iri_int64 (col_pos_t * cpo, caddr_t val, dtp_t dtp_wanted, char *dtp_match)
{
  search_spec_t *sp = cpo->cpo_itc->itc_col_spec;
  dtp_t dtp;
  *dtp_match = 1;
  if (DV_ANY == sp->sp_cl.cl_sqt.sqt_col_dtp)
    {
      db_buf_t dv = (db_buf_t) val;
      if (dtp_wanted == dtp_canonical[dv[0]])
	{
	  dtp_t a_dtp = dv[0];
	  if (DV_LONG_INT == a_dtp)
	    return LONG_REF_NA (dv + 1);
	  if (DV_IRI_ID == a_dtp)
	    return (int64)(uint32)LONG_REF_NA (dv + 1);
	  return INT64_REF_NA (dv + 1);
	}
      *dtp_match = 0;
      return -1;
    }
  dtp = DV_TYPE_OF (val);
  if (dtp_wanted == dtp)
    {
      return unbox_iri_int64 (val);
    }
  *dtp_match = 0;
  return -1;
}


int
cpo_match_after (col_pos_t * cpo, int target)
{
  it_cursor_t *itc = cpo->cpo_itc;
  int inx;
  for (inx = itc->itc_match_in; inx < itc->itc_n_matches; inx++)
    if (itc->itc_matches[inx] >= target)
      {
	itc->itc_match_in = inx;
	return itc->itc_matches[inx];
      }
  return CE_AT_END;
}


#define VEC_INX(array, inx) \
  (n_distinct <= 16 ? 0xf & (array[(inx) >> 1] >> (((inx) & 1) << 2)) : array[inx])

#define CE_DICT_INT_FLOAT(value) \
  if (CE_INTLIKE (flags)) {						\
	if (DV_SINGLE_FLOAT ==sp->sp_cl.cl_sqt.sqt_col_dtp) value = LONG_REF_NA (((db_buf_t)value) + 1); \
	else if (DV_DOUBLE_FLOAT ==sp->sp_cl.cl_sqt.sqt_col_dtp) value = INT64_REF_NA (((db_buf_t)value) + 1); \
      } \
    else if (CET_ANY == (flags & CE_DTP_MASK)) { \
      dtp_t tmp[11]; \
      if (DV_DOUBLE_FLOAT == cpo->cpo_cl->cl_sqt.sqt_col_dtp) \
	{ \
          *(int64*)&tmp[1] = *(int64*)(value + 1); \
	  tmp[0] = DV_INT64; \
	  value = (int64)&tmp;			\
	} \
      else if   (DV_SINGLE_FLOAT == cpo->cpo_cl->cl_sqt.sqt_col_dtp)	\
	{ \
          *(int32*)&tmp[1] = *(int32*)(value + 1);	\
	  tmp[0] = DV_LONG_INT; \
	  value = (int64)&tmp;	\
	}  \
      }



#define CE_DICT_NULL_INX \
  if (CET_ANY == (flags & CE_DTP_MASK) && !sp->sp_col->col_sqt.sqt_non_null && CMP_EQ != sp->sp_min_op) \
    { dtp_t dv = DV_DB_NULL; \
      null_v_inx = ce_dict_key (ce, ce_first, (int64)&dv, DV_DB_NULL, &dict, &n_distinct); }



int
ce_dict_generic_range_filter (col_pos_t * cpo, db_buf_t ce_first, int n_values, int n_bytes)
{
  it_cursor_t *itc = cpo->cpo_itc;
  search_spec_t *sp = itc->itc_col_spec;
  db_buf_t ce = cpo->cpo_ce;
  dtp_t flags = *ce;
  int fill = itc->itc_match_out, ce_row = cpo->cpo_ce_row_no, null_v_inx = -1;
  int dtp_cmp, inx, n_distinct;
  dtp_t dtp;
  int64 value;
  int last = MIN (n_values, cpo->cpo_to - ce_row);
  db_buf_t dict;
  int lower = -1, upper = 1000;
  CE_DICT_NULL_INX;
  if (CMP_NONE != sp->sp_min_op)
    {

      value = itc_any_param (itc, itc->itc_col_spec->sp_min, &dtp);
      dtp_cmp = ce_dtp_compare (ce, dtp);
      if (dtp_cmp != DVC_MATCH)
	return cpo->cpo_ce_row_no + n_values;
      CE_DICT_INT_FLOAT (value);
      lower = ce_dict_key (ce, ce_first, value, dtp, &dict, &n_distinct);
      if (CMP_EQ == sp->sp_min_op)
	{
	  if (lower & 1)
	    return cpo->cpo_ce_row_no + n_values;
	  lower--;
	  upper = lower + 2;
	}
      if (CMP_GTE == sp->sp_min_op && 0 == (lower & 1))
	lower--;
    }
  if (CMP_NONE != sp->sp_max_op)
    {
      value = itc_any_param (itc, itc->itc_col_spec->sp_max, &dtp);
      dtp_cmp = ce_dtp_compare (ce, dtp);
      if (dtp_cmp != DVC_MATCH)
	return cpo->cpo_ce_row_no + n_values;
      CE_DICT_INT_FLOAT (value);
      upper = ce_dict_key (ce, ce_first, value, dtp, &dict, &n_distinct);
      if (CMP_LTE == sp->sp_max_op && 0 == (upper & 1))
	upper++;
    }

  for (inx = cpo->cpo_skip; inx < last; inx++)
    {
      int v_inx = 2 * VEC_INX (dict, inx);
      if (v_inx > lower && v_inx < upper && v_inx != null_v_inx)
	itc->itc_matches[fill++] = inx + ce_row;
    }
  itc->itc_match_out = fill;
  return ce_row + n_values;
}


int
ce_dict_generic_sets_filter (col_pos_t * cpo, db_buf_t ce_first, int n_values, int n_bytes)
{
  it_cursor_t *itc = cpo->cpo_itc;
  search_spec_t *sp = itc->itc_col_spec;
  db_buf_t ce = cpo->cpo_ce;
  int fill = itc->itc_match_out, ce_row = cpo->cpo_ce_row_no;
  int end_of_ce = ce_row + n_values;
  int dtp_cmp, inx, n_distinct, v_inx, row, null_v_inx = -1;
  dtp_t dtp;
  dtp_t flags = *ce;
  int64 value;
  db_buf_t dict;
  int lower = -1, upper = 1000;
  int n_matches = itc->itc_n_matches;
  row_no_t *matches = itc->itc_matches;
  CE_DICT_NULL_INX;
  if (CMP_NONE != sp->sp_min_op)
    {

      value = itc_any_param (itc, itc->itc_col_spec->sp_min, &dtp);
      dtp_cmp = ce_dtp_compare (ce, dtp);
      if (dtp_cmp != DVC_MATCH)
	return cpo_match_after (cpo, cpo->cpo_ce_row_no + n_values);
      CE_DICT_INT_FLOAT (value);
      lower = ce_dict_key (ce, ce_first, value, dtp, &dict, &n_distinct);
      if (CMP_EQ == sp->sp_min_op)
	{
	  if (lower & 1)
	    return cpo_match_after (cpo, cpo->cpo_ce_row_no + n_values);
	  lower--;
	  upper = lower + 2;
	}
      if (CMP_GTE == sp->sp_min_op && 0 == (lower & 1))
	lower--;
    }
  if (CMP_NONE != sp->sp_max_op)
    {
      value = itc_any_param (itc, itc->itc_col_spec->sp_max, &dtp);
      dtp_cmp = ce_dtp_compare (ce, dtp);
      if (dtp_cmp != DVC_MATCH)
	return cpo_match_after (cpo, cpo->cpo_ce_row_no + n_values);
      CE_DICT_INT_FLOAT (value);

      upper = ce_dict_key (ce, ce_first, value, dtp, &dict, &n_distinct);
      if (CMP_LTE == sp->sp_max_op && 0 == (upper & 1))
	upper++;
    }

  inx = itc->itc_match_in;
  while (inx < n_matches && (row = matches[inx]) < end_of_ce)
    {
      row -= ce_row;
      v_inx = 2 * VEC_INX (dict, row);
      if (v_inx > lower && v_inx < upper && null_v_inx != v_inx)
	itc->itc_matches[fill++] = row + ce_row;
      inx++;
    }
  itc->itc_match_in = inx;
  itc->itc_match_out = fill;
  return inx >= n_matches ? CE_AT_END : matches[inx];
}


#define name ce_dict_any_range_decode
#define VARS

#define END_TEST \
  if (++row >= last) \
    { dc->dc_n_values = fill; return cpo->cpo_ce_row_no + n_values;}	\
v_inx = VEC_INX (array, row);

#include "cedictad.c"

#define VARS \
  it_cursor_t * itc = cpo->cpo_itc; \
  int end_row = n_values + cpo->cpo_ce_row_no


#define END_TEST \
  if (++itc->itc_match_in >= itc->itc_n_matches) \
    { dc->dc_n_values = fill; return CE_AT_END;} \
  row = itc->itc_matches[itc->itc_match_in]; 	\
if (row >= end_row) \
  {dc->dc_n_values = fill; return row;}		\
 row -= cpo->cpo_ce_row_no; \
  v_inx = VEC_INX (array, row);


#define name ce_dict_any_sets_decode

#include "cedictad.c"




#define ELT_T int32

int
ce_dict_int32_range_decode (col_pos_t * cpo, db_buf_t ce_first, int n_values, int n_bytes)
{
  data_col_t *dc = cpo->cpo_dc;
  dtp_t n_distinct = ce_first[0];
  int last = MIN (n_values, cpo->cpo_to - cpo->cpo_ce_row_no);
  int row = cpo->cpo_skip, v_inx;
  db_buf_t array, dict = ce_first + 1;
  array = dict + n_distinct * sizeof (ELT_T);
  if (!dc->dc_n_values)
    {
      dc_convert_empty (dc, DV_LONG_INT);
    }
  if (DV_LONG_INT != dc->dc_dtp)
    return 0;
  for (row = row; row < last; row++)
    {
      int32 n;
      v_inx = VEC_INX (array, row);
      n = LONG_REF_CA (dict + 4 * v_inx);
      ((int64 *) dc->dc_values)[dc->dc_n_values++] = n;
    }
  return cpo->cpo_ce_row_no + n_values;
}

#undef ELT_T


#define CE_FILTER_BAD_DTP \
{ \
 if (ASC_SHORTER <= dtp_cmp) return 0; \
  if (cpo->cpo_itc->itc_n_matches) return cpo_match_after (cpo, cpo->cpo_ce_row_no + n_values); \
  else return cpo->cpo_ce_row_no + n_values; \
}


#define INTLIKE_FILTER_VAL(nth, value)			\
  itc->itc_nth_key = nth; \
value = itc_ce_value_offset (itc, ce, &ce_first, &dtp_cmp); \
  if (!ce_first) \
    { CE_FILTER_BAD_DTP; }

#define VALUE_VARS \
  int64 value; \
  int dtp_cmp


#define FILTER_VALUES  INTLIKE_FILTER_VAL (itc->itc_col_spec->sp_max, value)

#define CE_I_LTE(data, value, row)		\
  if (data <= value) \
itc->itc_matches[itc->itc_match_out++] = row;


#define ce_name ce_intd_any_range_lte

#define CE_OP  CE_I_LTE (base + (int64)(int)n, value, last_row)
#define CEINTD_INTLIKE 0
#define CEINTD_RANGE

#include "ceintd.c"

int enable_intd_range = 1;
int enable_bits_dec = 1;

#define CE_NAME ce_intd_range_ltgt
#define CEINTD_RANGE
#include "ceintd2.c"


#define CE_NAME ce_intd_sets_ltgt
#undef CEINTD_RANGE
#include "ceintd2.c"



#define range_name ce_vec_int_range_decode
#define sets_name ce_vec_int_sets_decode
#define dict_range_name ce_dict_int_range_decode
#define dict_sets_name ce_dict_int_sets_decode
#define REF LONG_REF_CA
#define VEC_ELT_T int32
#define ELT_DV DV_LONG_INT

#include "ceveci.c"

#define range_name ce_vec_iri_range_decode
#define sets_name ce_vec_iri_sets_decode
#define dict_range_name ce_dict_iri_range_decode
#define dict_sets_name ce_dict_iri_sets_decode
#define REF (unsigned int64)(uint32)LONG_REF_CA
#define VEC_ELT_T uint32
#define ELT_DV DV_IRI_ID

#include "ceveci.c"



#define range_name ce_vec_int64_range_decode
#define sets_name ce_vec_int64_sets_decode
#define dict_range_name ce_dict_int64_range_decode
#define dict_sets_name ce_dict_int64_sets_decode
#define REF INT64_REF_CA
#define VEC_ELT_T int64
#define ELT_DV DV_LONG_INT

#include "ceveci.c"

#define range_name ce_vec_iri64_range_decode
#define sets_name ce_vec_iri64_sets_decode
#define dict_range_name ce_dict_iri64_range_decode
#define dict_sets_name ce_dict_iri64_sets_decode
#define REF INT64_REF_CA
#define VEC_ELT_T unsigned int64
#define ELT_DV DV_IRI_ID

#include "ceveci.c"



int
ce_vec_any_range_filter (col_pos_t * cpo, db_buf_t ce_first, int n_values, int n_bytes)
{
  it_cursor_t *itc = cpo->cpo_itc;
  search_spec_t *sp = itc->itc_col_spec;
  dtp_t min_op = sp->sp_min_op, max_op = sp->sp_max_op;
  db_buf_t ce = cpo->cpo_ce;
  int lower_len, upper_len;
  db_buf_t lower;
  db_buf_t upper;
  dtp_t flags = *ce;
  int mfill = itc->itc_match_out, ce_row = cpo->cpo_ce_row_no, nth, inx;
  db_buf_t ce_first_val;
  short start[500];
  short len[500];
  short off[500];
  short fill = 0;
  int last = MIN (n_values, cpo->cpo_to - ce_row), first_len;
  if (DV_STRING != sp->sp_cl.cl_sqt.sqt_col_dtp || n_values > 500)
    return 0;
  ce_vec_nth (ce_first, flags, n_values, cpo->cpo_skip, &ce_first_val, &first_len, 0);
  for (nth = cpo->cpo_skip; nth < last; nth++)
    {
      if (ce_first_val[0] < DV_ANY_FIRST)
	{
	  dtp_t off1, len1;
	  short inx = ce_first_val[0] <= MAX_1_BYTE_CE_INX ? (off1 = ce_first_val[1], len1 = 2, ce_first_val[0])
	      : (off1 = ce_first_val[2], len1 = 3, (ce_first_val[0] - MAX_1_BYTE_CE_INX - 1) * 256 + ce_first_val[1]);
	  db_buf_t org;
	  int org_len;
	  ce_vec_nth (ce_first, flags, n_values, inx, &org, &org_len, 0);
	  if (DV_SHORT_STRING_SERIAL == org[0])
	    {
	      start[fill] = (org - ce_first) + 2;
	      len[fill] = org[1];
	    }
	  else if (DV_STRING == org[0])
	    {
	      start[fill] = (org - ce_first) + 5;
	      len[fill] = org_len - 5;
	    }
	  else
	    {
	      start[fill] = org - ce_first;
	      len[fill] = -org_len;
	    }
	  off[fill++] = off1 - org[org_len - 1];
	  ce_first_val += len1;
	}
      else
	{
	  unsigned int len1;
	  if (DV_SHORT_STRING_SERIAL == ce_first_val[0])
	    {
	      start[fill] = (ce_first_val - ce_first) + 2;
	      len[fill] = ce_first_val[1];
	      len1 = ce_first_val[1] + 2;
	    }
	  else if (DV_STRING == ce_first_val[-1])
	    {
	      start[fill] = (ce_first_val - ce_first) + 5;
	      len[fill] = (((uint32) ce_first_val[3]) << 8) + ce_first_val[4];
	      len1 = len[fill] + 5;
	    }
	  else
	    {
	      start[fill] = ce_first_val - ce_first;
	      DB_BUF_TLEN (len1, ce_first_val[0], ce_first_val);
	      len[fill] = -len1;
	    }
	  off[fill++] = 0;
	  ce_first_val += len1;
	}
    }
  mfill = itc->itc_match_out;
  if (max_op != CMP_NONE)
    {
      upper = (db_buf_t) cpo->cpo_cmp_max;
      upper_len = box_length (upper) - 1;
    }
  else
    upper = NULL;
  if (CMP_NONE != min_op)
    {
      lower = (db_buf_t) cpo->cpo_cmp_min;
      lower_len = box_length (lower) - 1;
    }
  else
    lower = NULL;
  if (DV_STRING == itc->itc_col_spec->sp_cl.cl_sqt.sqt_col_dtp)
    {
      for (inx = 0; inx < fill; inx++)
	{
	  if (len[inx] < 0)
	    continue;
	  if (!off[inx])
	    {
	      if (lower && !(min_op & strcmp8 (ce_first + start[inx], lower, len[inx], lower_len)))
		continue;
	      if (upper && !(max_op & strcmp8 (ce_first + start[inx], upper, len[inx], upper_len)))
		continue;
	    }
	  else
	    {
	      if (lower && !(min_op & str_cmp_offset (ce_first + start[inx], lower, len[inx], lower_len, off[inx])))
		continue;
	      if (upper && !(max_op & str_cmp_offset (ce_first + start[inx], upper, len[inx], upper_len, off[inx])))
		continue;
	    }
	  itc->itc_matches[mfill++] = ce_row + inx + cpo->cpo_skip;
	}
    }
  itc->itc_match_out = mfill;
  return ce_row + n_values;
}


#define RANGE_NAME ce_vec_int32_range_filter
#define ELT_T int64
#define VEC_ELT_T int32
#define REF LONG_REF_CA
#define DTP DV_LONG_INT
#define DTP_MIN INT32_MIN
#define DTP_MAX INT32_MAX
#include "cevecf.c"


#define RANGE_NAME ce_vec_int64_range_filter
#define ELT_T int64
#define VEC_ELT_T int64
#define REF INT64_REF_CA
#define DTP DV_LONG_INT
#define DTP_MIN INT64_MIN
#define DTP_MAX INT64_MAX
#include "cevecf.c"

#define IRI_ID_MAX 0xffffffffffffffff

#define RANGE_NAME ce_vec_iri32_range_filter
#define ELT_T iri_id_t
#define VEC_ELT_T uint32
#define REF (iri_id_t)(uint32)LONG_REF_CA
#define DTP DV_IRI_ID
#define DTP_MIN 0
#define DTP_MAX IRI_ID_MAX
#include "cevecf.c"


#define RANGE_NAME ce_vec_iri64_range_filter
#define ELT_T iri_id_t
#define VEC_ELT_T iri_id_t
#define REF INT64_REF_CA
#define DTP DV_IRI_ID
#define DTP_MIN 0
#define DTP_MAX IRI_ID_MAX
#include "cevecf.c"



#define NAME ce_bits_int_range_eq_filter
#define ELT_T int64
#define ELT_DV DV_LONG_INT
#include "cebits.c"

#define NAME ce_bits_iri_range_eq_filter
#define ELT_T iri_id_t
#undef ELT_DV
#define ELT_DV DV_IRI_ID
#include "cebits.c"


/* delta like ce decode */



#define CED_ANY_VARS \
  char is_date = 0; \
uint32 any_base = 0;

#define CED_ANY_CHECK \
{ \
  if (first_len < 5) return 0; \
  if (!ced_any_dc_check (cpo, ce_first_val)) return 0; \
  if (DV_DATETIME == ce_first_val[0]) \
    { \
      is_date = 1; \
      any_base = DT_DAY (ce_first_val + 1); \
    } \
  else  \
    any_base = LONG_REF_NA (ce_first_val + first_len - 4); \
}


#define CED_ANY_OUT(ce_first_val, first_len, off)	\
{ \
  if (is_date) \
    { \
      db_buf_t tgt = dc->dc_values + DT_LENGTH * dc->dc_n_values; \
      memcpy_dt (tgt, ce_first_val + 1); \
      dc->dc_n_values++; \
      DT_SET_DAY (tgt, any_base + off); \
    } \
  else \
    { \
      db_buf_t tgt; \
      int buf_fill = dc->dc_buf_fill, buf_len = dc->dc_buf_len; \
      if (buf_fill + first_len + DC_STR_MARGIN <= buf_len) \
	{ \
	  tgt = ((db_buf_t*)dc->dc_values)[dc->dc_n_values++] = dc->dc_buffer + buf_fill; \
	  memcpy_16 (tgt, ce_first_val, first_len); \
	  dc->dc_buf_fill += first_len; \
	} \
      else \
	{ \
	  dc_append_bytes (dc, ce_first_val, first_len, NULL, 0); \
	  tgt = ((db_buf_t*)dc->dc_values)[dc->dc_n_values - 1]; \
	} \
      LONG_SET_NA (tgt + first_len - 4, any_base + off); \
    } \
}


#define CED_INT_OUT(i1, i2, off) \
  ((int64*)dc->dc_values)[dc->dc_n_values++] = off

int 
ced_any_dc_check (col_pos_t * cpo, db_buf_t ce_first_val)
{
  data_col_t * dc = cpo->cpo_dc;
  if (DV_DATETIME == dc->dc_sqt.sqt_dtp && DV_DATETIME == ce_first_val[0])
    return 1;
  if (DV_DATETIME == ce_first_val[0])
    {
      if (dc->dc_n_values || DV_ANY != dc->dc_sqt.sqt_col_dtp)
	return 0;
      dc_convert_empty (dc, DV_DATETIME);
      return 1;
    }
  if (DV_ANY != dc->dc_sqt.sqt_col_dtp)
    return 0;
  if (DV_ANY != dc->dc_sqt.sqt_dtp)
    dc_heterogenous (dc);
  return 1;
}


int
ced_intlike_dc_check (col_pos_t * cpo, dtp_t flags)
{
  data_col_t * dc = cpo->cpo_dc;
  if (((CE_IS_IRI & flags) ? DV_IRI_ID : DV_LONG_INT) == dtp_canonical[dc->dc_dtp])
    return 1;
  if (DV_ANY == dc->dc_sqt.sqt_col_dtp)
    {
      if (!dc->dc_n_values)
	{
	  dc_convert_empty (dc, (CE_IS_IRI &flags) ? DV_IRI_ID : DV_LONG_INT);
	  return 1;
	}
      else
	return 0;
    }
  return 0;
}




#define CE_NAME ce_intd_any_range_decode 
#define IS_INTD_ANY 1
#define CEINTD_RANGE
#define CED_VARS CED_ANY_VARS
#define CED_CHECK CED_ANY_CHECK
#define CE_OUT(first_val,first_len,off) CED_ANY_OUT (first_val,first_len,off)
#include "ceintddec.c"

#define CE_NAME ce_intd_any_sets_decode 
#define IS_INTD_ANY 1
#define CED_VARS CED_ANY_VARS
#define CED_CHECK CED_ANY_CHECK
#define CE_OUT(first_val,first_len,off) CED_ANY_OUT (first_val,first_len,off)
#include "ceintddec.c"


#define CE_NAME ce_bits_int_range_decode 
#define CE_BITS_RANGE
#define CED_CHECK if (!ced_intlike_dc_check (cpo, flags)) return 0;
#define CED_VARS
#define CE_OUT(first_val, first_len, off) CED_INT_OUT (first_val, first_len, off)
#include "cebitsdec.c"


#define CE_NAME ce_bits_int_sets_decode 
#define CED_CHECK if (!ced_intlike_dc_check (cpo, flags)) return 0;
#define CED_VARS
#define CE_OUT(first_val, first_len, off) CED_INT_OUT (first_val, first_len, off)
#include "cebitsdec.c"



int enable_vecf = 1;


void
ce_intd_register (flags)
{
  ce_op_register (CE_INT_DELTA | flags, CE_ALL_LTGT, 0, ce_intd_range_ltgt);
  ce_op_register (CE_INT_DELTA | flags, CE_ALL_LTGT, 1, ce_intd_sets_ltgt);
  ce_op_register (CE_INT_DELTA | flags, CMP_EQ, 0, ce_intd_range_ltgt);
  ce_op_register (CE_INT_DELTA | flags, CMP_EQ, 1, ce_intd_sets_ltgt);
}

int ce_hash_range_filter (col_pos_t * cpo, db_buf_t ce_first, int n_values, int n_bytes);
int ce_hash_sets_filter (col_pos_t * cpo, db_buf_t ce_first, int n_values, int n_bytes);

void
ce_hash_register ()
{
  dtp_t cets[] = { CE_RL, CE_BITS, CE_VEC, CE_DICT, CE_RL_DELTA, CE_INT_DELTA};
  dtp_t dtps[] = {0, 16, 32, 48, 64, 80, 96};
  int i1, i2;
  for (i1 = 0; i1 < sizeof (cets); i1++)
    {
      for (i2 = 0; i2 < sizeof (dtps); i2++)
	{
	  dtp_t cet = cets[i1] | dtps[i2];
	  ce_op_register (cet, CE_OP_CODE (CMP_HASH_RANGE, CMP_NONE), 0, ce_hash_range_filter);
	  ce_op_register (cet, CE_OP_CODE (CMP_HASH_RANGE, CMP_NONE), 1, ce_hash_sets_filter);
	}
    }
}

void
colin_init ()
{
  ce_op_register (CE_INT_DELTA | CET_ANY, CE_OP_CODE (CMP_NONE, CMP_LTE), 0, ce_intd_any_range_lte);
  ce_op_register (CE_DICT | CET_ANY, CE_DECODE, 0, ce_dict_any_range_decode);
  ce_op_register (CE_DICT | CET_ANY, CE_DECODE, 1, ce_dict_any_sets_decode);

  ce_op_register (CE_VEC | 0, CE_DECODE, 0, ce_vec_int_range_decode);
  ce_op_register (CE_VEC | 0, CE_DECODE, 1, ce_vec_int_sets_decode);
  ce_op_register (CE_DICT | 0, CE_DECODE, 0, ce_dict_int_range_decode);
  ce_op_register (CE_DICT | 0, CE_DECODE, 1, ce_dict_int_sets_decode);

  ce_op_register (CE_VEC | CE_IS_IRI, CE_DECODE, 0, ce_vec_iri_range_decode);
  ce_op_register (CE_VEC | CE_IS_IRI, CE_DECODE, 1, ce_vec_iri_sets_decode);
  ce_op_register (CE_DICT | CE_IS_IRI, CE_DECODE, 0, ce_dict_iri_range_decode);
  ce_op_register (CE_DICT | CE_IS_IRI, CE_DECODE, 1, ce_dict_iri_sets_decode);

  ce_op_register (CE_VEC | CE_IS_64, CE_DECODE, 0, ce_vec_int64_range_decode);
  ce_op_register (CE_VEC | CE_IS_64, CE_DECODE, 1, ce_vec_int64_sets_decode);
  ce_op_register (CE_DICT | CE_IS_64, CE_DECODE, 0, ce_dict_int64_range_decode);
  ce_op_register (CE_DICT | CE_IS_64, CE_DECODE, 1, ce_dict_int64_sets_decode);

  ce_op_register (CE_VEC | CE_IS_IRI | CE_IS_64, CE_DECODE, 0, ce_vec_iri64_range_decode);
  ce_op_register (CE_VEC | CE_IS_IRI | CE_IS_64, CE_DECODE, 1, ce_vec_iri64_sets_decode);
  ce_op_register (CE_DICT | CE_IS_IRI | CE_IS_64, CE_DECODE, 0, ce_dict_iri64_range_decode);
  ce_op_register (CE_DICT | CE_IS_IRI | CE_IS_64, CE_DECODE, 1, ce_dict_iri64_sets_decode);


  if (enable_vecf)
    {
      ce_op_register (CE_VEC | CET_ANY, CE_ALL_LTGT, 0, ce_vec_any_range_filter);
      ce_op_register (CE_VEC, CE_ALL_LTGT, 0, ce_vec_int32_range_filter);
      ce_op_register (CE_VEC | CE_IS_64, CE_ALL_LTGT, 0, ce_vec_int64_range_filter);
      ce_op_register (CE_VEC | CE_IS_IRI, CE_ALL_LTGT, 0, ce_vec_iri32_range_filter);
      ce_op_register (CE_VEC | CE_IS_64 | CE_IS_IRI, CE_ALL_LTGT, 0, ce_vec_iri64_range_filter);
      ce_op_register (CE_VEC, CMP_EQ, 0, ce_vec_int32_range_filter);
      ce_op_register (CE_VEC | CE_IS_64, CMP_EQ, 0, ce_vec_int64_range_filter);
      ce_op_register (CE_VEC | CE_IS_IRI, CMP_EQ, 0, ce_vec_iri32_range_filter);
      ce_op_register (CE_VEC | CE_IS_64 | CE_IS_IRI, CMP_EQ, 0, ce_vec_iri64_range_filter);
    }
  ce_op_register (CE_BITS, CMP_EQ, 0, ce_bits_int_range_eq_filter);
  ce_op_register (CE_BITS | CE_IS_64, CMP_EQ, 0, ce_bits_int_range_eq_filter);
  ce_op_register (CE_BITS | CE_IS_IRI, CMP_EQ, 0, ce_bits_iri_range_eq_filter);
  ce_op_register (CE_BITS | CE_IS_IRI | CE_IS_64, CMP_EQ, 0, ce_bits_iri_range_eq_filter);
  ce_hash_register ();
  ce_intd_register (CET_ANY);
  ce_intd_register (0);
  ce_intd_register (CE_IS_64);
  ce_intd_register (CE_IS_IRI);
  ce_intd_register (CE_IS_IRI | CE_IS_64);


  ce_op_decode = col_find_op (CE_DECODE);
  ce_op_hash = col_find_op (CMP_HASH_RANGE);
  


  ce_op_register (CE_INT_DELTA | CET_ANY, CE_DECODE, 0, ce_intd_any_range_decode);
  ce_op_register (CE_INT_DELTA | CET_ANY, CE_DECODE, 1, ce_intd_any_sets_decode);

  ce_op_register (CE_BITS | CET_INT, CE_DECODE, 0, ce_bits_int_range_decode);
  ce_op_register (CE_BITS | CET_INT, CE_DECODE, 1, ce_bits_int_sets_decode);
  ce_op_register (CE_BITS | CET_INT | CE_IS_64, CE_DECODE, 0, ce_bits_int_range_decode);
  ce_op_register (CE_BITS | CET_INT | CE_IS_64, CE_DECODE, 1, ce_bits_int_sets_decode);

  ce_op_register (CE_BITS | CE_IS_IRI, CE_DECODE, 0, ce_bits_int_range_decode);
  ce_op_register (CE_BITS | CE_IS_IRI, CE_DECODE, 1, ce_bits_int_sets_decode);
  ce_op_register (CE_BITS | CE_IS_IRI | CE_IS_64, CE_DECODE, 0, ce_bits_int_range_decode);
  ce_op_register (CE_BITS | CE_IS_IRI | CE_IS_64, CE_DECODE, 1, ce_bits_int_sets_decode);

}
