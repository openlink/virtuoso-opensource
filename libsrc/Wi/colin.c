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
 *  Copyright (C) 1998-2011 OpenLink Software
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
      }

int
ce_dict_generic_range_filter (col_pos_t * cpo, db_buf_t ce_first, int n_values, int n_bytes)
{
  it_cursor_t *itc = cpo->cpo_itc;
  search_spec_t *sp = itc->itc_col_spec;
  db_buf_t ce = cpo->cpo_ce;
  dtp_t flags = *ce;
  int fill = itc->itc_match_out, ce_row = cpo->cpo_ce_row_no;
  int dtp_cmp, inx, n_distinct;
  dtp_t dtp;
  int64 value;
  int last = MIN (n_values, cpo->cpo_to - ce_row);
  db_buf_t dict;
  int lower = -1, upper = 1000;
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
      if (v_inx > lower && v_inx < upper)
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
  int dtp_cmp, inx, n_distinct, v_inx, row;
  dtp_t dtp;
  dtp_t flags = *ce;
  int64 value;
  db_buf_t dict;
  int lower = -1, upper = 1000;
  int n_matches = itc->itc_n_matches;
  row_no_t *matches = itc->itc_matches;
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
	return cpo_match_after (cpo, cpo->cpo_ce_row_no + n_values);;
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
      if (v_inx > lower && v_inx < upper)
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

}
