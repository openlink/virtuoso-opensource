/*
 *  ceins.h
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
#include "date.h"

#define CE_INSERT_GEN ((db_buf_t)-1)

int dbf_ce_insert_mask = 0;

int
ceic_all_dtp (ce_ins_ctx_t * ceic, dtp_t dtp)
{

  int is_32 = DV_LONG_INT == dtp || DV_IRI_ID == dtp;
  it_cursor_t *itc = ceic->ceic_itc;
  dtp_t can_dtp = dtp_canonical[dtp];
  int inx;
  db_buf_t val;
  int n_for_ce = ceic->ceic_n_for_ce, last;
  /* after checking types for a merge insert after a partially done type specific insert it can be that the first set and first range are shifted up.  So ceic_n_for_ce is not the cap.  Must not read past the sets.  No harm in reprting heterogenous types due to reading more sets than actually go to the ce.  */
  if (n_for_ce > itc->itc_range_fill - itc->itc_ce_first_range)
    n_for_ce = itc->itc_range_fill - itc->itc_ce_first_range;
  last = itc->itc_ce_first_set + n_for_ce;
  if (DV_ANY == ceic->ceic_col->col_sqt.sqt_dtp)
    {
  for (inx = itc->itc_ce_first_set; inx < last; inx++)
    {
	val = (db_buf_t) itc->itc_vec_rds[itc->itc_param_order[inx]]->rd_values[ceic->ceic_nth_col];
      if (can_dtp != dtp_canonical[*(db_buf_t) val])
	return 0;
      if ((DV_LONG_INT == dtp && DV_INT64 == *(db_buf_t) val) || (DV_IRI_ID == dtp && DV_IRI_ID_8 == *(db_buf_t) val))
	return 0;
    }
    }
  else
    {
      for (inx = itc->itc_ce_first_set; inx < last; inx++)
	{
	  int64 n;
	  val = (db_buf_t) itc->itc_vec_rds[itc->itc_param_order[inx]]->rd_values[ceic->ceic_nth_col];
	  if (can_dtp != dtp_canonical[DV_TYPE_OF (val)])
	    return 0;
	  if (is_32)
	    {
	      n = unbox_iri_int64 (val);
	      if (IS_64_T (n, can_dtp))
		return 0;
	    }
	}
    }
  ceic->ceic_dtp_checked = 1;
  return 1;
}



#define INS_NAME ce_insert_vec_int
#define ELT_T int
#define SET_NA LONG_SET_CA
#include "cevecins.c"


#define INS_NAME ce_insert_vec_int64
#define ELT_T int64
#define SET_NA INT64_SET_CA
#include "cevecins.c"


#define VEC_DTP_CK(dtp) \
  if ((DV_ANY == ceic->ceic_col->col_sqt.sqt_dtp || DV_LONG_INT == dtp || DV_IRI_ID == dtp ||  !ceic->ceic_col->col_sqt.sqt_non_null) && !ceic_all_dtp (ceic, dtp)) \
    goto general;


db_buf_t
ceic_ins_any_value_ap (ce_ins_ctx_t * ceic, int nth, auto_pool_t * ap, int *from_ap)
{
  caddr_t err, r;
  it_cursor_t *itc = ceic->ceic_itc;
  caddr_t box = itc->itc_vec_rds[itc->itc_param_order[nth]]->rd_values[ceic->ceic_nth_col];
  if (DV_ANY == ceic->ceic_col->col_sqt.sqt_dtp)
    return (db_buf_t) box;
  *from_ap = 1;
  r = box_to_any_1 (box, &err, ap, 0);
  CEIC_FLOAT_INT (ceic->ceic_col->col_sqt.sqt_dtp, r, box_any_dv ((db_buf_t)r), ff_nop);
  return (db_buf_t) r;
}

db_buf_t
ceic_str_value (ce_ins_ctx_t * ceic, int nth, int *len_ret, dtp_t * dtp_ret)
{
  dtp_t dtp;
  it_cursor_t *itc = ceic->ceic_itc;
  db_buf_t box = itc->itc_param_order
      ? (db_buf_t) itc->itc_vec_rds[itc->itc_param_order[nth]]->rd_values[ceic->ceic_nth_col]
      : (db_buf_t) itc->itc_vec_rds[0]->rd_values[ceic->ceic_nth_col];
  if (DV_ANY == ceic->ceic_col->col_sqt.sqt_dtp)
    {
      switch (box[0])
	{
	case DV_SHORT_STRING_SERIAL:
	  *dtp_ret = DV_STRING;
	  *len_ret = box[1];
	  return box + 2;
	case DV_LONG_STRING:
	  *dtp_ret = DV_STRING;
	  *len_ret = LONG_REF_NA (box + 1);
	  return box + 5;
	default:
	  *dtp_ret = dtp_canonical[*(db_buf_t) box];
	  return NULL;
	}
    }
  dtp = DV_TYPE_OF (box);
  if (DV_STRING == dtp)
    {
      *len_ret = box_length (box) - 1;
      return box;
    }
  *dtp_ret = dtp;
  return NULL;
}

#define CET_CHARS_HEAD_LEN(c) \
  (((db_buf_t)(c))[0] < 128 ? 1 : 2)

db_buf_t
ce_insert_rl (ce_ins_ctx_t * ceic, ce_ins_ctx_t ** col_ceic, db_buf_t ce, int space_after, int *split_at)
{
  it_cursor_t *itc = ceic->ceic_itc;
  int rl, new_rl, n_bytes, first_len, rc;
  int set;
  int last = itc->itc_ce_first_set + ceic->ceic_n_for_ce;
  dtp_t flags = ce[0];
  dtp_t ce_dtp = flags & CE_DTP_MASK, val_dtp;
  db_buf_t ce_first;
  db_buf_t ce_first_val;
  int64 first;
  if (CS_NO_RL & dbf_ce_insert_mask)
    return CE_INSERT_GEN;
  if (CE_RL == (flags & CE_TYPE_MASK))
    ce_first = flags & CE_IS_SHORT ? ce + 2 : ce + 3;
  else
    ce_first = flags & CE_IS_SHORT ? ce + 3 : ce + 5;
  CE_FIRST;
  switch (ce_dtp)
    {
    case CET_ANY:
      for (set = itc->itc_ce_first_set; set < last; set++)
	{
	  db_buf_t val;
	  int is_ap = 0;
	  AUTO_POOL (100);
	  val = ceic_ins_any_value_ap (ceic, set, &ap, &is_ap);
	  rc = asc_cmp (ce_first_val, val);
	  if (is_ap && ((caddr_t) val < ap.ap_area || (caddr_t) val > ap.ap_area + ap.ap_fill))
	    dk_free_box (val);
	  if (0 != rc)
	    return CE_INSERT_GEN;
	}
      break;
    case CET_CHARS:
      {
	int len;
	for (set = itc->itc_ce_first_set; set < last; set++)
	  {
	    db_buf_t val = ceic_str_value (ceic, set, &len, &val_dtp);
	    if (!val)
	      return CE_INSERT_GEN;
	    ce_first_val += CET_CHARS_HEAD_LEN (ce_first_val);
	    if (DVC_MATCH != str_cmp_2 (ce_first_val, val, NULL, first_len, len, 0, 0))
	      return CE_INSERT_GEN;
	  }
	break;
      }
    default:
      ce_dtp = flags & CE_IS_IRI ? DV_IRI_ID : DV_LONG_INT;
      for (set = itc->itc_ce_first_set; set < last; set++)
	{
	  int64 value = ceic_int_value (ceic, set, &val_dtp);
	  if (val_dtp != ce_dtp)
	    return CE_INSERT_GEN;
	  if (first != value)
	    return CE_INSERT_GEN;
	}
    }
  rl = flags & CE_IS_SHORT ? ce[1] : SHORT_REF_CA (ce + 1);
  new_rl = rl + ceic->ceic_n_for_ce;
  if (rl + ceic->ceic_n_for_ce > 20000)
    {
      *split_at = new_rl / 2;
      return NULL;
    }
  if ((CE_IS_SHORT & flags) && new_rl > 255)
    {
      n_bytes = ce_1_len (ce + 2, ce[0]);
      ce = ce_extend (ceic, col_ceic, ce, &ce_first, n_bytes, new_rl, &space_after);
      return ce;
    }
  if (flags & CE_IS_SHORT)
    ce[1] = new_rl;
  else
    SHORT_SET_CA (ce + 1, new_rl);
  return ce;
}



#define ASC_CHECK \
  (!inx || (CE_RL_DELTA == ce_type ? values[inx] >= values[inx - 1] : CE_BITS == ce_type ? values[inx] > values[inx - 1] : 1))

int
ce_insert_deltas (ce_ins_ctx_t * ceic, db_buf_t ce, db_buf_t * body_ret, int64 * values)
{
  /* take a rl, rld or bitmap or int delta.  Decode 1st value in ce and return the int differences for the values that go into this ce.
   *   Byte 0 of body is returned body_ret. If any type is incompatible, 0 0 is returned, else the number of values that go into the ce.
   *  if int delta, consider that the last byte of val is length and special case with dv date */
  it_cursor_t *itc = ceic->ceic_itc;
  uint32 delta;
  int inx;
  dtp_t param_dtp, ce_dtp;
  dtp_t col_dtp = dtp_canonical[ceic->ceic_col->col_sqt.sqt_dtp];
  int first_len, rc;
  dtp_t flags = ce[0];
  dtp_t ce_type = flags & CE_TYPE_MASK;
  char is_int_delta = CE_INT_DELTA == ce_type;
  db_buf_t ce_first;
  db_buf_t ce_first_val;
  int64 first;
  db_buf_t dv;
  if (CE_RL == (flags & CE_TYPE_MASK))
    ce_first = flags & CE_IS_SHORT ? ce + 2 : ce + 3;
  else
    ce_first = flags & CE_IS_SHORT ? ce + 3 : ce + 5;
  CE_FIRST;
  if (is_int_delta)
    first &= CLEAR_LOW_BYTE;
  if (DV_IRI_ID == col_dtp || DV_LONG_INT == col_dtp)
    {
      for (inx = 0; inx < ceic->ceic_n_for_ce; inx++)
	{
	  values[inx] = ceic_int_value (ceic, itc->itc_ce_first_set + inx, &param_dtp) - first;
	  if (inx && values[inx] - values[0] >= CE_INT_DELTA_MAX)
	    goto ntype;
	  if (values[inx] < 0 || !ASC_CHECK)
	    goto ntype;
	}
      *body_ret = ce_first;
      return inx;
    }
  else
    {
      ce_dtp = dtp_canonical[ce_first[0]];
      for (inx = 0; inx < ceic->ceic_n_for_ce; inx++)
	{
	  if (CE_INTLIKE (flags))
	    {
	      /* special case for compare of intlike ce with intlike or dv string param */
	      int64 param = ceic_int_value (ceic, itc->itc_ce_first_set + inx, &param_dtp);
	      ce_dtp = (flags & CE_IS_IRI) ? DV_IRI_ID : DV_LONG_INT;
	      if (DV_ANY == col_dtp)
		{
		  if (param_dtp != ce_dtp)
		    goto ntype;
		}
	      values[inx] = param - first;
	      if (values[inx] < 0 || !ASC_CHECK)
		goto ntype;
	    }
	  else if (CET_CHARS == (flags & CE_DTP_MASK))
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
		goto ntype;
	      values[inx] = delta;
	      if (DVC_GREATER == rc)
		goto ntype;
	      if (values[inx] < 0 || !ASC_CHECK)
		goto ntype;
	    }
	  else if (CET_ANY == (flags & CE_DTP_MASK))
	    {
	      int from_ap = 0;
	      AUTO_POOL (200);
	      dv = ceic_ins_any_value_ap (ceic, itc->itc_ce_first_set + inx, &ap, &from_ap);
	      if ((DV_RDF_ID == dv[0] || DV_RDF_ID_8 == dv[0]) && dv[0] != ce_first_val[0])
		goto ntype;	/* rdf ids of different lengths do not go in the same ce even if values close. */
	      rc = asc_cmp_delta (ce_first_val, dv, &delta, is_int_delta);
	      if (from_ap && (dv < (db_buf_t) ap.ap_area || dv > (db_buf_t) ap.ap_area + ap.ap_fill))
		dk_free_box ((caddr_t)dv);
	      if (rc > DVC_GREATER)
		goto ntype;
	      if (DVC_GREATER == rc)
		goto ntype;
	      values[inx] = delta;
	      if (values[inx] < 0 || !ASC_CHECK)
		goto ntype;
	    }
	  else
	    GPF_T1 ("the ce is of no type for delta insert");
	}
      *body_ret = ce_first;
      return inx;
    }
ntype:
  *body_ret = NULL;
  return 0;
}



#define RLDELTA(b) (((dtp_t)b) >> 4)
#define RLRL(b) ((b) & 0xf)

void
ce_inc_n_values (ce_ins_ctx_t * ceic, ce_ins_ctx_t ** col_ceic_ret,
    db_buf_t * ce_ret, db_buf_t * ce_first_ret, db_buf_t * ce_cur_ret, db_buf_t * ce_end_ret, int *space_after, int n_more)
{
  int n_values, n_bytes, new_hl;
  db_buf_t ce = *ce_ret;
  db_buf_t new_ce;
  db_buf_t ce_first, new_ce_first;
  dtp_t flags = *ce;
  CE_2_LENGTH (ce, ce_first, n_bytes, n_values);
  if ((CE_IS_SHORT & flags) && n_values + n_more > 255)
    {
      new_ce_first = ce_first;
      new_ce = ce_extend (ceic, col_ceic_ret, ce, &new_ce_first, n_bytes, n_values + n_more, space_after);
      new_hl = new_ce_first - new_ce;
      *ce_ret = new_ce;
      *ce_first_ret = new_ce_first;
      *ce_cur_ret = new_ce_first + (*ce_cur_ret - ce_first);
      *ce_end_ret = new_ce_first + n_bytes;
      return;
    }
  if (CE_IS_SHORT & flags)
    ce[2] += n_more;
  else
    SHORT_REF_CA (ce + 3) = SHORT_REF_CA (ce + 3) + n_more;
}


void
ce_insert_byte (ce_ins_ctx_t * ceic, ce_ins_ctx_t ** col_ceic_ret,
    db_buf_t * ce_ret, db_buf_t * ce_first_ret, db_buf_t * ce_cur_ret, db_buf_t * ce_end_ret,
    int *space_after, int ins_at, dtp_t * ins_value, int ins_bytes, int n_more)
{
  int n_values, n_bytes, new_hl;
  db_buf_t ce = *ce_ret;
  db_buf_t new_ce;
  db_buf_t ce_first, new_ce_first;
  CE_2_LENGTH (ce, ce_first, n_bytes, n_values);
  new_ce_first = ce_first;
  new_ce = ce_extend (ceic, col_ceic_ret, ce, &new_ce_first, n_bytes + ins_bytes, n_values + n_more, space_after);
  new_hl = new_ce_first - new_ce;
  memmove_16 (new_ce_first + ins_at + ins_bytes, new_ce_first + ins_at, n_bytes - ins_at);
  if (1 == ins_bytes)
    new_ce_first[ins_at] = *ins_value;
  else if (2 == ins_bytes)
    *(short *) &new_ce_first[ins_at] = *(short *) ins_value;
  else
    memcpy (&new_ce_first[ins_at], ins_value, ins_bytes);
  *ce_ret = new_ce;
  *ce_first_ret = new_ce_first;
  *ce_cur_ret = new_ce_first + (*ce_cur_ret - ce_first);
  *ce_end_ret = new_ce_first + n_bytes + ins_bytes;
}


void
ce_rld_append (ce_ins_ctx_t * ceic, ce_ins_ctx_t ** col_ceic_ret, db_buf_t * ce_ret, int64 prev, int64 * numbers, int to,
    dtp_t last_byte, int *space_after)
{
  dtp_t temp[3000];
  db_buf_t ce = *ce_ret;
  db_buf_t out = temp, ce_first;
  int inx, rl, fill = 0, n_bytes, n_values;
  int64 prev_delta;
  temp[0] = last_byte;
  prev_delta = last_byte >> 4;
  rl = last_byte & 0xf;
  if (15 == rl)
    {
      fill = 1;
      rl = 0;
      prev_delta = 0;
    }
  else
    fill = 0;
  for (inx = 0; inx < to; inx++)
    {
      int64 n = numbers[inx];
      int64 delta = n - prev;
      if (0 == delta)
	{
	  rl++;
	  if (15 == rl)
	    {
	      for (prev_delta = prev_delta; prev_delta > 15; prev_delta -= 15)
		{
		  out[fill++] = 0xf0;
		  if (fill >= sizeof (temp))
		    GPF_T1 ("rld append overflow");
		}
	      out[fill++] = (prev_delta << 4) | rl;
	      rl = 0;
	      prev_delta = 0;
	    }
	  continue;
	}
      if (0 == rl)
	{
	  rl = 1;
	  prev_delta = delta;
	  prev = n;
	  continue;
	}
      for (prev_delta = prev_delta; prev_delta > 15; prev_delta -= 15)
	{
	  out[fill++] = 0xf0;
	  if (fill >= sizeof (temp))
	    GPF_T1 ("rld append overflow");
	}
      out[fill++] = (prev_delta << 4) | rl;
      if (fill >= sizeof (temp))
	GPF_T1 ("rld append overflow");
      prev = n;
      rl = 1;
      prev_delta = delta;
      for (prev_delta = delta; prev_delta > 15; prev_delta -= 15)
	{
	  out[fill++] = 0xf0;
	  if (fill >= sizeof (temp))
	    GPF_T1 ("rld append overflow");
	}
    }
  if (rl)
    {
      for (prev_delta = prev_delta; prev_delta > 15; prev_delta -= 15)
	{
	  out[fill++] = 0xf0;
	  if (fill >= sizeof (temp))
	    GPF_T1 ("rld append overflow");
	}
      out[fill++] = prev_delta << 4 | rl;
      if (fill >= sizeof (temp))
	GPF_T1 ("rld append overflow");
    }
  CE_2_LENGTH (ce, ce_first, n_bytes, n_values);
  ce = ce_extend (ceic, col_ceic_ret, ce, &ce_first, n_bytes + fill - 1, to + n_values, space_after);
  memcpy_16 (ce_first + n_bytes - 1, temp, fill);
  *ce_ret = ce;
}

#define CE_MAX_INSERT 2048

int
ce_rld_rl (db_buf_t ce, db_buf_t ce_end)
{
  int rl = 0;
  if (ce < ce_end)
    {
      rl = ce[0] & 0x0f;
      ce++;
    }
  while (ce < ce_end)
    {
      if (*ce & 0xf0)
	break;
      rl += *ce & 0x0f;
      ce++;
    }
  return rl;
}


int
ce_rld_n_for_place (ce_ins_ctx_t * ceic, int64 * values, int nth, int lower, int upper)
{
  /* how many consecutive of the same value going to the same row or rl range.  If many rl bytes with -0 delta consider them all and return how many were covered */
  it_cursor_t *itc = ceic->ceic_itc;
  int inx;
  for (inx = nth + 1; inx < ceic->ceic_n_for_ce; inx++)
    {
      int row_no = itc->itc_ranges[inx + itc->itc_ce_first_range].r_first - itc->itc_row_of_ce;
      if (values[inx] == values[nth] && row_no >= lower && row_no < upper)
	continue;
      if (row_no >= lower && row_no < upper - 1)
	return -1;		/* got a fuck that falls in the range but is not eq.  An empty range is marked by uppwe lower and upper being consecutive.  So if row no == upper - 1 this means position after the rl which is not a rl break so - 1 */
      return inx - nth;
    }
  return inx - nth;
}

void
ce_rld_inc_count (db_buf_t ce_cur, db_buf_t ce_end, int n_more, int *n_15s, dtp_t * a15, int *n_skip)
{
  int inx, fill = 0;
  for (inx = 0; inx < ce_end - ce_cur; inx++)
    {
      dtp_t byte = ce_cur[inx];
      if (0xf0 & byte && inx)
	break;
      if (!n_more)
	;
      else if (15 > (byte & 0xf))
	{
	  int avail = 15 - (byte & 0xf);
	  if (avail >= n_more)
	    {
	      ce_cur[inx] += n_more;
	      n_more = 0;
	    }
	  else if (avail)
	    {
	      ce_cur[inx] = (byte & 0xf0) | 15;
	      n_more -= avail;
	    }
	}
    }
  *n_skip = inx;
  while (n_more > 15)
    {
      a15[fill++] = 15;
      n_more -= 15;
      if (fill > 200)
	GPF_T1 ("cannot inc rld count by over 3000");
    }
  if (n_more)
    a15[fill++] = n_more;
  *n_15s = fill;
}

db_buf_t
ce_insert_rld (ce_ins_ctx_t * ceic, ce_ins_ctx_t ** col_ceic, db_buf_t ce, int space_after, int *split_at)
{
  dtp_t a15[300];
  it_cursor_t *itc = ceic->ceic_itc;
  db_buf_t ce_first, ce_end, ce_cur;
  int n_values, n_bytes, rl_inc_at_end, n_more, n_15s, n_skip, is_first;
  db_buf_t ce_first_val;
  dtp_t byte, flags = *ce, no_look = 0;
  int64 value, first;
  int n_deltas, first_len, nth, row_no, last_row = 0, delta, rl;
  int64 values[CE_MAX_INSERT];
  if (CS_NO_RLD & dbf_ce_insert_mask)
    return CE_INSERT_GEN;
  CE_2_LENGTH (ce, ce_first, n_bytes, n_values);
  if (ceic->ceic_n_for_ce + n_values > 3000 || n_bytes > 4000)
    {
      *split_at = (n_values + ceic->ceic_n_for_ce) / 2;
      return NULL;
    }
  CE_FIRST;
  n_deltas = ce_insert_deltas (ceic, ce, &ce_first, values);
  if (!n_deltas)
    return CE_INSERT_GEN;
  first_len = ce_first - ce_first_val;
  ce_first = ce_first_val;
  ce_end = ce_first + n_bytes;
  ce_cur = ce_first + first_len;
  nth = 0;
  first = 0;
  row_no = itc->itc_ranges[itc->itc_ce_first_range + nth].r_first - itc->itc_row_of_ce;
  value = values[nth];
  last_row = 0;
  while (ce_cur < ce_end)
    {
      rl_inc_at_end = 0;
      byte = *ce_cur;
      delta = byte >> 4;
      rl = byte & 0xf;
      while (last_row == row_no)
	{
	  if (value == first + delta)
	    goto rl_inc;
	  if (value == first)
	    {
	      if (ce_cur == ce_first + first_len)
		goto ins_1;
	      ce_cur--;
	      rl_inc_at_end = 1;
	      goto rl_inc;
	    }
	  if (value < first)
	    goto no_order;
	  if (value < first + delta)
	    goto ins_1;
	  if (rl && value > first + delta)
	    goto no_order;
	  if (ce_cur == ce_end - 1)
	    goto append;
	  first += delta;
	  ce_cur++;
	  byte = *ce_cur;
	  delta = byte >> 4;
	  rl = byte & 0xf;
	}
      if (last_row < row_no && last_row + rl > row_no)
	{
	  if (first + delta == value)
	    goto rl_inc;
	  goto no_order;
	}
      last_row += rl;
      first += delta;
      ce_cur++;
      if (!no_look && row_no - last_row > 10 && ce_end - ce_cur > 8)
	{
	  unsigned int64 r8 = *(unsigned int64 *) ce_cur;
	  unsigned int64 d8 = r8;
	  r8 &= 0x0f0f0f0f0f0f0f0f;
	  add8 (r8);
	  if (last_row + r8 < row_no)
	    {
	      d8 = d8 >> 4;
	      d8 &= 0x0f0f0f0f0f0f0f0f;
	      add8 (d8);
	      first += d8;
	      ce_cur += 8;
	      last_row += r8;
	      continue;
	    }
	  no_look = 1;
	}
      continue;
    next_v:
      nth++;
      if (nth >= ceic->ceic_n_for_ce)
	return ce;
      row_no = itc->itc_ranges[itc->itc_ce_first_range + nth].r_first - itc->itc_row_of_ce;
      value = values[nth];
      no_look = 0;
      continue;
    }
append:
  if (nth < n_deltas)
    {
      /* inserts at the end */
      int64 last_value = values[n_deltas - 1];
      int inx2, skip_bytes = 0;
      if (value < first || value - first > 160)
	goto no_order;
      if ((last_value - first) / (n_deltas - nth) > 20)
	goto no_order;
      for (inx2 = nth; inx2 < n_deltas - 1; inx2++)
	{
	  int delta =  values[inx2 + 1] - values[inx2];
	  skip_bytes += delta / 15;
	  if (delta > 15 * 15)
	    goto no_order; /* skip of more than 15  bytes */
	}
      if (skip_bytes > 1000)
	goto no_order;
      ce_rld_append (ceic, col_ceic, &ce, first, &values[nth], n_deltas - nth, ce_cur[-1], &space_after);
    }
  return ce;
no_order:
  itc->itc_ce_first_range += nth;
  itc->itc_ce_first_set += nth;
  itc->itc_row_of_ce -= nth;	/* in the merge insert, the ranges are applied this much later.  The row of ce can go negative but this is ok, it is int */
  return CE_INSERT_GEN;
rl_inc:
  if (!rl_inc_at_end)
    rl = ce_rld_rl (ce_cur, ce_end);
  n_more = ce_rld_n_for_place (ceic, values, nth, last_row, rl_inc_at_end ? last_row + 1 : last_row + rl + 1);
  if (-1 == n_more || n_more > 16 * (ce_first + first_len - ce))
    goto no_order;
  ce_rld_inc_count (ce_cur, ce_end, n_more, &n_15s, a15, &n_skip);
  if (-1 == n_15s)
    goto no_order;
  ce_inc_n_values (ceic, col_ceic, &ce, &ce_first, &ce_cur, &ce_end, &space_after, n_more);
  ce_cur += n_skip;
  if (n_15s)
    ce_insert_byte (ceic, col_ceic, &ce, &ce_first, &ce_cur, &ce_end, &space_after, ce_cur - ce_first, a15, n_15s, 0);
  ce_cur += n_15s;
  nth += n_more - 1;
  if (!rl_inc_at_end)
    {
      last_row += rl;
      first += delta;
    }
  goto next_v;

ins_1:
  n_more = ce_rld_n_for_place (ceic, values, nth, last_row, last_row + 1);
  if (-1 == n_more)
    GPF_T1 ("ce insert rld got rl seq break value where there is no rl seq");
  nth += n_more - 1;
  while (value - first > 15)
    {
      byte = 15 << 4;
      ce_insert_byte (ceic, col_ceic, &ce, &ce_first, &ce_cur, &ce_end, &space_after, ce_cur - ce_first, &byte, 1, 0);
      first += 15;
      ce_cur++;
    }
  is_first = 1;
  while (n_more)
    {
      int for_here = MIN (n_more, 15);
      byte = for_here + (is_first ? ((value - first) << 4) : 0);
      ce_insert_byte (ceic, col_ceic, &ce, &ce_first, &ce_cur, &ce_end, &space_after, ce_cur - ce_first, &byte, 1, for_here);
      ce_cur++;
      n_more -= for_here;
      is_first = 0;
    }
  if (ce_cur < ce_end)
    ce_cur[0] -= (value - first) << 4;
  first = value;
  delta = 0;
  goto next_v;
}




uint64
bf_get (db_buf_t base, int bit, int n)
{
  uint64 w = *(uint64 *) (base + (bit >> 3));
  int rem = bit & 7;
  w = w >> rem;
  if (n > 64 - rem)
    {
      dtp_t hb = (base + (bit >> 3))[8];
      w |= (uint64) hb << (64 - rem);
    }
  return w;
}


#undef N_ONES
#define N_ONES(n)  (64 == (n) ? (int64)-1 : (((int64)1 << (n)) - 1))

void
bf_set (db_buf_t base, int bit, uint64 val, int val_bits)
{
  /* set val bits low bits of val at bit field base + bit */
  uint64 *tgt = (uint64 *) (base + (bit >> 3));
  int rem = bit & 7;
  int low_mask = N_ONES (rem);
  uint64 field = N_ONES (val_bits) << rem;
  *tgt = (*tgt & ~field) | ((val << rem) & field);
  if (val_bits + rem > 64)
    {
      db_buf_t phb = ((db_buf_t) tgt) + 8;
      dtp_t hb = *phb & ~low_mask;
      *phb = (val >> (64 - rem)) | hb;
    }
}


void
bit_insert (db_buf_t base, int target, int source, int bits)
{
  int64 temp;
  int end = source + (bits & 0x3f);
  if (!bits)
    return;
  source += bits;
  target += bits;
  while (source > end)
    {
      source -= 64;
      target -= 64;
      temp = bf_get (base, source, 64);
      bf_set (base, target, temp, 64);
    }
  bits &= 0x3f;
  source -= bits;
  target -= bits;
  temp = bf_get (base, source, bits);
  bf_set (base, target, temp, bits);
}

void
bit_delete (db_buf_t base, int target, int source, int bits)
{
  int64 temp;
  int end = source + (bits & ~0x3fL);
  if (!bits)
    return;
  while (source < end)
    {
      temp = bf_get (base, source, 64);
      bf_set (base, target, temp, 64);
      source += 64;
      target += 64;
    }
  bits &= 0x3f;
  temp = bf_get (base, source, bits);
  bf_set (base, target, temp, bits);
}

#define IS_GAP(b) (CE_GAP == (b) || CE_GAP_1 == (b) || CE_SHORT_GAP == (b))


db_buf_t
ce_insert_dict (ce_ins_ctx_t * ceic, ce_ins_ctx_t ** col_ceic, db_buf_t ce, int space_after, int *split_at)
{
  it_cursor_t *itc = ceic->ceic_itc;
  db_buf_t ce_first;
  int n_values, n_bytes;
  dtp_t flags = *ce, ce_dtp;
  int n_insert = ceic->ceic_n_for_ce;
  int last_moved, new_bytes;
  dtp_t values[CE_MAX_INSERT];
  db_buf_t dict;
  int n_distinct, dict_offset, inx;
  if (CS_NO_DICT & dbf_ce_insert_mask)
    return CE_INSERT_GEN;
  CE_2_LENGTH (ce, ce_first, n_bytes, n_values);
  if (ceic->ceic_n_for_ce + n_values > 3000 || n_bytes > 4000)
    {
      *split_at = (n_values + ceic->ceic_n_for_ce) / 2;
      return NULL;
    }
  if (CE_INTLIKE (flags))
    ce_dtp = (flags & CE_IS_IRI) ? DV_IRI_ID : DV_LONG_INT;
  else
    ce_dtp = DV_ANY;
  for (inx = 0; inx < n_insert; inx++)
    {
      dtp_t dtp;
      int key;
      int64 param;
      if (CE_INTLIKE (flags))
	{
	  param = ceic_int_value (ceic, inx + itc->itc_ce_first_set, &dtp);
	  if (dtp != ce_dtp)
	    goto ntype;
	  key = ce_dict_key (ce, ce_first + 1, param, dtp, &dict, &n_distinct);
	}
      else
	{
	  int is_ap = 0, is_ncast_eq = 0;
	  db_buf_t val;
	  AUTO_POOL (100);
	  val = ceic_ins_any_value_ap (ceic, inx + itc->itc_ce_first_set, &ap, &is_ap);
	  key = ce_dict_ins_any_key (ce, ce_first + 1, (int64) (ptrlong) val, val[0], &dict, &n_distinct, &is_ncast_eq);
	  if (is_ap && ((caddr_t) val < ap.ap_area || (caddr_t) val > ap.ap_area + ap.ap_fill))
	    dk_free_box (val);
	  if (is_ncast_eq)
	    goto ntype;
	}
      if (key & 1)
	goto ntype;
      values[inx] = key >> 1;
    }
  dict_offset = dict - ce_first;
  new_bytes = n_distinct <= 16 ? ALIGN_2 (n_values + n_insert) / 2 : n_values + n_insert;
  ce = ce_extend (ceic, col_ceic, ce, &ce_first, dict_offset + new_bytes, n_values + n_insert, &space_after);
  dict = ce_first + dict_offset;
  last_moved = n_values;
  for (inx = n_insert - 1; inx >= 0; inx--)
    {
      int row = itc->itc_ranges[inx + itc->itc_ce_first_range].r_first - itc->itc_row_of_ce;
      if (n_distinct > 16)
	{
	  memmove_16 (dict + row + inx + 1, dict + row, last_moved - row);
	  dict[row + inx] = values[inx];
	}
      else
	{
	  bit_insert (dict, 4 * (row + inx + 1), 4 * row, 4 * (last_moved - row));
	  bf_set (dict, 4 * (row + inx), values[inx], 4);
	}
      /*if (ce == org_ce && !IS_GAP (dict[new_bytes])) bing (); */
      last_moved = row;
    }
  return ce;
ntype:
  return CE_INSERT_GEN;
}

void
ce_bm_insert_set (db_buf_t ce_cur, int64 * values, int n_insert)
{
  int nth;
  for (nth = 0; nth < n_insert; nth++)
    {
      int64 value = values[nth] - 1;
      ce_cur[value >> 3] |= 1 << (value & 7);
    }
}

db_buf_t
ce_insert_bm (ce_ins_ctx_t * ceic, ce_ins_ctx_t ** col_ceic, db_buf_t ce, int space_after, int *split_at)
{
  it_cursor_t *itc = ceic->ceic_itc;
  db_buf_t ce_first, ce_end, ce_cur;
  int n_values, n_bytes, new_n_bytes;
  db_buf_t ce_first_val;
  dtp_t flags = *ce;
  int64 value, first, top_val;
  int n_deltas, first_len, nth, row_no, last_row = 0;
  int64 values[CE_MAX_INSERT];
  int counted_to = 0, n_counted = 0;
  if (CS_NO_BITS & dbf_ce_insert_mask)
    return CE_INSERT_GEN;
  CE_2_LENGTH (ce, ce_first, n_bytes, n_values);
  if (ceic->ceic_n_for_ce + n_values > 3000 || n_bytes > 4000)
    {
      *split_at = (n_values + ceic->ceic_n_for_ce) / 2;
      return NULL;
    }
  CE_FIRST;
  n_deltas = ce_insert_deltas (ceic, ce, &ce_first, values);
  if (!n_deltas)
    return CE_INSERT_GEN;
  first_len = ce_first - ce_first_val;
  ce_first = ce_first_val;
  ce_end = ce_first + n_bytes;
  ce_cur = ce_first + first_len;
  nth = 0;
  first = 0;
  last_row = 0;
  top_val = (n_bytes - first_len) * 8;
  if (!values[0])
    goto no_order;
  for (nth = 0; nth < n_deltas; nth++)
    {
      value = values[nth];
      row_no = itc->itc_ranges[itc->itc_ce_first_range + nth].r_first - itc->itc_row_of_ce;
      if (value > top_val)
	{
	  if (row_no == n_values)
	    goto append;
	  goto no_order;
	}
      last_row = ce_bm_nth (ce_cur, value, &counted_to, &n_counted);
      if (ce_cur[(value - 1) >> 3] & 1 << ((value - 1) & 7))
	goto no_order;
      if (row_no != last_row)
	goto no_order;
    }
append:
  if (nth < n_deltas)
    {
      /* inserts at the end */
      int64 last_value = values[n_deltas - 1];
      if ((last_value - top_val) / (n_deltas - nth) > 8)
	goto no_order;
      new_n_bytes = first_len + (ALIGN_8 ((last_value)) / 8);
      ce = ce_extend (ceic, col_ceic, ce, &ce_first, new_n_bytes, n_values + n_deltas, &space_after);
      ce_cur = ce_first + first_len;
      memset (ce_first + n_bytes, 0, new_n_bytes - n_bytes);
      ce_bm_insert_set (ce_cur, values, n_deltas);
    }
  else
    {
      ce_bm_insert_set (ce_cur, values, nth);
      ce_inc_n_values (ceic, col_ceic, &ce, &ce_first, &ce_cur, &ce_end, &space_after, nth);
    }
  return ce;
no_order:
  ce_bm_insert_set (ce_cur, values, nth);
  ce_inc_n_values (ceic, col_ceic, &ce, &ce_first, &ce_cur, &ce_end, &space_after, nth);
  itc->itc_ce_first_range += nth;
  itc->itc_ce_first_set += nth;
  itc->itc_row_of_ce -= nth;	/* in the merge insert, the ranges are applied this much later.  The row of ce can go negative but this is ok, it is int */
  return CE_INSERT_GEN;
}


db_buf_t
ce_insert_int_delta (ce_ins_ctx_t * ceic, ce_ins_ctx_t ** col_ceic, db_buf_t ce, int space_after, int *split_at)
{
  it_cursor_t *itc = ceic->ceic_itc;
  db_buf_t rl_ptr, run_ptr, last_moved;
  db_buf_t ce_first, ce_end, ce_cur;
  int n_values, n_bytes, n_for_run, value_ctr;
  db_buf_t ce_first_val;
  dtp_t flags = *ce;
  int64 first, base, base_1;
  int n_deltas, first_len, nth, inx, ins_inx, run_off, rl_off, more, row_no, last_row = 0;
  int64 values[CE_MAX_INSERT];
  uint32 d, run, run1;
  if (CS_NO_DELTA & dbf_ce_insert_mask)
    return CE_INSERT_GEN;
  CE_2_LENGTH (ce, ce_first, n_bytes, n_values);
  if (ceic->ceic_n_for_ce + n_values > 1000 || n_bytes + (2 * ceic->ceic_n_for_ce) > 2030)
    {
      *split_at = (n_values + ceic->ceic_n_for_ce) / 2;
      return NULL;
    }
  CE_FIRST;
  value_ctr = n_values;
  n_deltas = ce_insert_deltas (ceic, ce, &ce_first, values);
  if (!n_deltas)
    return CE_INSERT_GEN;
  first_len = ce_first - ce_first_val;
  ce_first = ce_first_val;
  ce_end = ce_first + n_bytes;
  ce_cur = ce_first + first_len;
  run_ptr = ce_first + first_len;
  nth = 0;

  if (!CE_INTLIKE (flags))
    {
      if (DV_DATE == any_ce_dtp (ce_first_val))
	{
	  base = DT_UDAY (ce_first_val + 1);
	  run1 = run = base & 0xff;
	  rl_ptr = ce_first_val + 3;
	  base_1 = base = (base & CLEAR_LOW_BYTE) - base + run1;
	}
      else
	{
	  first = LONG_REF_NA (run_ptr - 4);
	  rl_ptr = run_ptr - 1;
	  base = base_1 = 0;
	  run1 = run = first & 0xff;
	}
    }
  else
    {
      base_1 = base = first & CLEAR_LOW_BYTE;
      run1 = run = first & 0xff;
#if WORDS_BIGENDIAN
      rl_ptr = run_ptr - 1;
#else
      rl_ptr = ce_first_val;
#endif
    }
  ce_end = ce_first + n_bytes;
  while (nth < n_deltas)
    {
      for (inx = nth; inx < n_deltas; inx++)
	{
	  row_no = itc->itc_ranges[inx + itc->itc_ce_first_range].r_first - itc->itc_row_of_ce;
	  if (row_no >= last_row && (row_no <= last_row + run || last_row + run == n_values))
	    {
	      /* if falls inside run or run is last, check magnitude to see if fits */
	      if (values[inx] - (base - base_1) > 0xff00 || values[inx] - (base - base_1) < 0 || values[inx] >= CE_INT_DELTA_MAX)
		goto no_order;
	    }
	  if (row_no > last_row + run)
	    break;
	}
      n_for_run = inx - nth;
      if (n_for_run > 100)
	goto no_order;
      more = 2 * (inx - nth) + (run + inx - nth > 255 ? 4 : 0);
      rl_off = rl_ptr - ce_first;
      run_off = run_ptr - ce_first;
      value_ctr += inx - nth;
      ce = ce_extend (ceic, col_ceic, ce, &ce_first, n_bytes + more, value_ctr, &space_after);
      rl_ptr = ce_first + rl_off;
      run_ptr = ce_first + run_off;
      last_moved = ce_first + n_bytes;
      n_bytes += more;
      ce_end = ce_first + n_bytes;
      for (ins_inx = n_for_run - 1; ins_inx >= 0; ins_inx--)
	{
	  int row = itc->itc_ranges[ins_inx + nth + itc->itc_ce_first_range].r_first - itc->itc_row_of_ce - last_row;
	  memmove_16 (run_ptr + 2 * (row + ins_inx + 1), run_ptr + 2 * row, last_moved - (run_ptr + 2 * row));
	  SHORT_SET_CA (run_ptr + 2 * (row + ins_inx), values[ins_inx + nth] - (base - base_1));
	  last_moved = run_ptr + 2 * row;
	}
      if (n_for_run + run > 255)
	{
	  int half = (run + n_for_run) / 2;
	  memmove_16 (run_ptr + 2 * half + 4, run_ptr + 2 * half, ce_end - 4 - (run_ptr + 2 * half));
	  *rl_ptr = half;
	  LONG_SET_NA (run_ptr + 2 * half, base - base_1);
	  run_ptr[2 * half + 3] = run + n_for_run - half;
	  run_ptr += 4 + 2 * (run + n_for_run);
	}
      else
	{
	  *rl_ptr = n_for_run + run;
	  run_ptr += 2 * (run + n_for_run);
	}
      last_row += run;
      nth += n_for_run;
      if (run_ptr == ce_end)
	break;
      d = LONG_REF_NA (run_ptr);
      run = d & 0xff;
      base = base_1 + (d & CLEAR_LOW_BYTE);
      run_ptr += 4;
      rl_ptr = run_ptr - 1;
    }
  return ce;
no_order:
  itc->itc_ce_first_range += nth;
  itc->itc_ce_first_set += nth;
  itc->itc_row_of_ce -= nth;	/* in the merge insert, the ranges are applied this much later.  The row of ce can go negative but this is ok, it is int */
  return CE_INSERT_GEN;
}


int
ceic_ins_len (ce_ins_ctx_t * ceic)
{
  it_cursor_t *itc = ceic->ceic_itc;
  row_delta_t **rds = itc->itc_vec_rds;
  int l = 0, inx, set = itc->itc_ce_first_set;
  if (!itc->itc_param_order)
    {
      caddr_t x = rds[0]->rd_values[ceic->ceic_nth_col];
      return IS_BOX_POINTER (x) ? box_col_len (x) : 4;
    }
  for (inx = set; inx < set + ceic->ceic_n_for_ce; inx++)
    {
      caddr_t x = rds[itc->itc_param_order[inx]]->rd_values[ceic->ceic_nth_col];
      l += IS_BOX_POINTER (x) ? box_col_len (x) : 4;
    }
  return l;
}


int
ceic_guess_split (ce_ins_ctx_t * ceic, db_buf_t ce)
{
  /* see how much coming in, see density and guess where to split */
  dtp_t ce_type, flags;
  int bytes, n_values, hl;
  float bpv;
  ce_head_info (ce, &bytes, &n_values, &ce_type, &flags, &hl);
  if (n_values + ceic->ceic_n_for_ce > 2048)
    {
      if (ceic->ceic_n_for_ce > 2047)
	return n_values + ceic->ceic_n_for_ce - 200;
      return (n_values + ceic->ceic_n_for_ce) / 2;
    }
  bpv = (float) bytes / n_values;
  /*ins_bytes = ceic_ins_len (ceic); */
  if (bytes + (bpv * ceic->ceic_n_for_ce) > 2000)
    return (n_values + ceic->ceic_n_for_ce) / 2;
  return -1;
}

caddr_t *
ce_box (db_buf_t ce, int extra)
{
  it_cursor_t itc_auto;
  it_cursor_t *itc = &itc_auto;
  int inx;
  mem_pool_t *mp = mem_pool_alloc ();
  int n_values = ce_n_values (ce);
  caddr_t *res = (caddr_t *) dk_alloc_box_zero (sizeof (caddr_t) * (n_values + extra), DV_ARRAY_OF_POINTER);
  col_pos_t cpo;
  data_col_t dc;
  memset (&cpo, 0, sizeof (cpo));
  memset (&dc, 0, sizeof (data_col_t));
ITC_INIT (itc, NUL:NULL, NULL);
  itc->itc_n_matches = 0;
  cpo.cpo_itc = itc;
  cpo.cpo_string = ce;
  cpo.cpo_bytes = ce_total_bytes (ce);

  dc.dc_type = DCT_BOXES;
  dc.dc_mp = mp;
  dc.dc_n_places = n_values;
  dc.dc_values = (db_buf_t) mp_alloc (mp, sizeof (caddr_t) * n_values);
  cpo.cpo_dc = &dc;
  cpo.cpo_value_cb = ce_result;
  cpo.cpo_ce_op = NULL;
  cpo.cpo_pm = NULL;
  cs_decode (&cpo, 0, n_values);
  for (inx = 0; inx < n_values; inx++)
    {
      res[inx] = ((caddr_t *) dc.dc_values)[inx];
    }
  mp_free (mp);
  return res;
}

caddr_t
ceic_ins_box (ce_ins_ctx_t * ceic, int nth)
{
  it_cursor_t *itc = ceic->ceic_itc;
  caddr_t box = itc->itc_param_order
      ? itc->itc_vec_rds[itc->itc_param_order[nth]]->rd_values[ceic->ceic_nth_col]
      : itc->itc_vec_rds[0]->rd_values[ceic->ceic_nth_col];
  if (DV_ANY == ceic->ceic_col->col_sqt.sqt_dtp)
    return box_deserialize_string (box, INT32_MAX, 0);
  return box_copy_tree (box);
}


caddr_t *
ceic_reference_insert (ce_ins_ctx_t * ceic, caddr_t * res, int n_ins)
{
  /* used in double check mode to generate the correct insert result */
  it_cursor_t *itc = ceic->ceic_itc;
  int ins_offset = 0, inx;
  int len = BOX_ELEMENTS (res);
  for (inx = 0; inx < n_ins; inx++)
    {
      caddr_t val = ceic_ins_box (ceic, itc->itc_ce_first_set + inx);
      int pos = itc->itc_ranges[inx + itc->itc_ce_first_range].r_first - itc->itc_row_of_ce;
      memmove (&res[pos + ins_offset + 1], &res[pos + ins_offset], sizeof (caddr_t) * (len - (pos + ins_offset + 1)));
      res[pos + ins_offset] = val;
      ins_offset++;
    }
  return res;
}


void
ce_compare_ins (ce_ins_ctx_t * ceic, caddr_t * res, db_buf_t ce2, int len)
{
  caddr_t *res2 = ce_box (ce2, 0);
  int inx;
  for (inx = 0; inx < len; inx++)
    {
      if (!box_equal (res[inx], res2[inx]))
	bing ();
    }
  dk_free_tree (res);
  dk_free_tree (res2);
}

int dbf_ce_ins_check = 0;

db_buf_t
ceic_ice_string_no_trunc (ce_ins_ctx_t * ceic, int ice)
{
  dk_set_t last = dk_set_last (ceic->ceic_delta_ce_op);
  if (!last || ((ptrlong) last->data) != (CE_REPLACE | ice))
    return NULL;
  return (db_buf_t) dk_set_last (ceic->ceic_delta_ce)->data;
}


int ce_ins_spec[16];
int ce_ins_gen[16];

db_buf_t
ce_insert_1 (ce_ins_ctx_t * ceic, ce_ins_ctx_t ** col_ceic, db_buf_t ce, int space_after, int *split_at, int ice)
{
  caddr_t *org = NULL;
  it_cursor_t *itc = ceic->ceic_itc;
  db_buf_t ce2;
  dtp_t flags = ce[0];
  mem_pool_t *mp = NULL;
  ce_ins_ctx_t tmp_ceic;
  int initial_len = ce_total_bytes (ce), org_set, org_count;
  int split;
  ceic->ceic_dtp_checked = 0;
  if (ceic->ceic_n_for_ce > 1000 && (CE_RL != (flags & CE_TYPE_MASK)))
    goto general;
  if (ceic->ceic_n_updates)
    goto general;
  if (dbf_ce_ins_check)
    {
      org_count = ce_n_values (ce);
      org_set = itc->itc_ce_first_set;
      org = ce_box (ce, ceic->ceic_n_for_ce);
    }
  switch (flags & ~CE_IS_SHORT)
    {
    case CE_VEC:
      VEC_DTP_CK (DV_LONG_INT);
      ce2 = ce_insert_vec_int (ceic, col_ceic, ce, space_after, split_at);
      break;
    case CE_VEC | CE_IS_IRI:
      VEC_DTP_CK (DV_IRI_ID);
      ce2 = ce_insert_vec_int (ceic, col_ceic, ce, space_after, split_at);
      break;
    case CE_VEC | CE_IS_64:
      VEC_DTP_CK (DV_INT64);
      ce2 = ce_insert_vec_int64 (ceic, col_ceic, ce, space_after, split_at);
      break;
    case CE_VEC | CE_IS_IRI | CE_IS_64:
      VEC_DTP_CK (DV_IRI_ID_8);
      ce2 = ce_insert_vec_int64 (ceic, col_ceic, ce, space_after, split_at);
      break;
    case CE_ALL_VARIANTS (CE_RL):
      ce2 = ce_insert_rl (ceic, col_ceic, ce, space_after, split_at);
      break;
    case CE_ALL_VARIANTS (CE_RL_DELTA):
      ce2 = ce_insert_rld (ceic, col_ceic, ce, space_after, split_at);
      break;
    case CE_ALL_VARIANTS (CE_BITS):
      ce2 = ce_insert_bm (ceic, col_ceic, ce, space_after, split_at);
      break;
    case CE_ALL_VARIANTS (CE_DICT):
      ce2 = ce_insert_dict (ceic, col_ceic, ce, space_after, split_at);
      break;
    case CE_ALL_VARIANTS (CE_INT_DELTA):
      ce2 = ce_insert_int_delta (ceic, col_ceic, ce, space_after, split_at);
      break;
    default:
      if (dbf_ce_ins_check)
	dk_free_tree ((caddr_t) org);
    general:
      split = ceic_guess_split (ceic, ce);
      if (*col_ceic)
	{
	  (*col_ceic)->ceic_n_for_ce = ceic->ceic_n_for_ce;
	  ceic_merge_insert (*col_ceic, ceic->ceic_org_buf, ice, ce, 0, split);
	}
      else
	{
	  memset (&tmp_ceic, 0, sizeof (tmp_ceic));
	  if (!ceic->ceic_mp)
	    {
	      mp = mem_pool_alloc ();
	      tmp_ceic.ceic_mp = mp;
	    }
	  else
	    tmp_ceic.ceic_mp = ceic->ceic_mp;
	  tmp_ceic.ceic_top_ceic = ceic;
	  tmp_ceic.ceic_itc = ceic->ceic_itc;
	  tmp_ceic.ceic_is_cpt_restore = ceic->ceic_is_cpt_restore;
	  tmp_ceic.ceic_col = ceic->ceic_col;
	  tmp_ceic.ceic_nth_col = ceic->ceic_nth_col;
	  tmp_ceic.ceic_n_for_ce = ceic->ceic_n_for_ce;
	  ceic_merge_insert (&tmp_ceic, ceic->ceic_org_buf, ice, ce, 0, split);
	  if (!tmp_ceic.ceic_delta_ce->next)
	    {
	      int new_len = ce_total_bytes ((db_buf_t) tmp_ceic.ceic_delta_ce->data);
	      if (new_len - initial_len <= space_after)
		{
		  memcpy_16 (ce, tmp_ceic.ceic_delta_ce->data, new_len);
		  cs_write_gap (ce + new_len, space_after - (new_len - initial_len));
		  if (mp)
		    {
		      cs_free_allocd_parts (ceic->ceic_cs);
		      ceic->ceic_cs = NULL;
		      mp_free (mp);
		    }
		  return ce;
		}
	    }
	  if (mp)
	    ceic->ceic_mp = mp;
	  if (!*col_ceic)
	    *col_ceic = ceic_col_ceic (ceic);
	  (*col_ceic)->ceic_delta_ce = tmp_ceic.ceic_delta_ce;
	  (*col_ceic)->ceic_delta_ce_op = tmp_ceic.ceic_delta_ce_op;
	}
      return NULL;
    }
  if (CE_INSERT_GEN == ce2)
    {
      ce_ins_gen[flags & 0xf]++;
      if (dbf_ce_ins_check)
	{
	  /* verify partial insert. Note that ce first set and row of ce are shifted, so shift back for the reference insert */
	  db_buf_t ce3 = *col_ceic ? ceic_ice_string_no_trunc (*col_ceic, ice) : NULL;
	  int n_done = itc->itc_ce_first_set - org_set;
	  caddr_t *res;
	  itc->itc_row_of_ce += n_done;
	  itc->itc_ce_first_set -= n_done;
	  itc->itc_ce_first_range -= n_done;
	  res = ceic_reference_insert (ceic, org, n_done);
	  itc->itc_row_of_ce -= n_done;
	  itc->itc_ce_first_set += n_done;
	  itc->itc_ce_first_range += n_done;
	  ce_compare_ins (ceic, res, ce3 ? ce3 : ce, org_count + n_done);
	}
      goto general;
    }
  if (dbf_ce_ins_check && ce2)
    {
      caddr_t *res = ceic_reference_insert (ceic, org, ceic->ceic_n_for_ce);
      ce_compare_ins (ceic, res, ce2, org_count + ceic->ceic_n_for_ce);
    }
  if (!ce2 && dbf_ce_ins_check)
    dk_free_tree ((caddr_t) org);
  if (!ce2)
    ce_ins_gen[flags & 0xf]++;
  else
    ce_ins_spec[flags & 0xf]++;
  return ce2;
}
