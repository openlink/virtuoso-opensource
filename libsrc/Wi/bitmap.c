/*
 *  bitmap.c
 *
 *  $Id$
 *
 *  Bitmap Index
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2019 OpenLink Software
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
#include "multibyte.h"
#include "srvmultibyte.h"
#include "xmlnode.h"
#include "sqlbif.h"
#include "srvstat.h"



void
bm_ends (bitno_t bm_start, db_buf_t bm, int bm_len, bitno_t * start, bitno_t * end)
{
  /* Get the range of bits that can be covered by this bm.  The start is the bit no on the containing row.  The end is the start bitno of the last ce.  The values are rounded to ce boundaries.  */
  int inx = 0;
  * start = bm_start;
  inx = CE_LENGTH (bm);
  if (inx == bm_len)
    {
      *end = *start;
      return;
    }
  while (inx < bm_len)
    {
      int len = CE_LENGTH (bm + inx);
      if (len + inx == bm_len)
	{
	  *end = bm_start + CE_OFFSET (bm + inx);
	  return;
	}
      inx += len;
    }
}


void
itc_bm_ends (it_cursor_t * itc, buffer_desc_t * buf, bitno_t * start, bitno_t * end, int * is_single)
{
  dbe_key_t * key = itc->itc_insert_key;
  int off, len;
  bitno_t bm_start;
  itc->itc_row_data = buf->bd_buffer + buf->bd_content_map->pm_entries[itc->itc_map_pos];
  BIT_COL (bm_start, buf, itc->itc_row_data, key);
  KEY_PRESENT_VAR_COL (itc->itc_insert_key, itc->itc_row_data, (*itc->itc_insert_key->key_bm_cl), off, len);
  if (0 == len)
    {
      /* the bm string is 0.  Use the last key part as start and end. */
      *end = *start = bm_start;
      *is_single = 1;
      return;
    }
  *is_single = 0;
  bm_ends (bm_start, itc->itc_row_data + off, len, start, end);
}


int ce_bitmap_value (db_buf_t bits, short value, int is_fwd);


void
bm_print (db_buf_t bm, short bm_len, bitno_t bm_start, int all)
{
  db_buf_t ce = bm;
  while (ce < bm + bm_len)
    {
      int ce_len = CE_LENGTH (ce);
      bitno_t ce_start = bm_start + CE_OFFSET (ce);
      int n_printed = 0;
      if (!ce_len)
	{
	  printf ("Error: 0 length ce\n");
	  break;
	}
      if (CE_IS_SINGLE (ce))
	{
	  printf (" S[%Ld", bm_start + (LONG_REF_NA (ce) & 0x7fffffff));
	}
      else if (CE_IS_ARRAY (ce))
	{
	  int inx;
	  printf (" A[");
	  for (inx = 0; inx < (ce_len - 4) / 2; inx++)
	    {
	      printf (" %Ld ", ce_start + SA_REF (ce + 4, inx));
	      if (!all && ++n_printed > 10)
		{
		  printf ("...");
		  break;
		}
	    }
	  printf ("]\n");
	}
      else
	{
	  short bit = 0;
	  printf ("B[ ");
	  for (;;)
	    {
	      bit = ce_bitmap_value (ce + 4, bit, 1);
	      if (bit == CE_N_VALUES)
		break;
	      printf (" %Ld ", ce_start + bit);
	      bit++;
	      if (!all && ++n_printed > 10)
		{
		  printf ("...");
		  break;
		}
	    }
	  printf ("]\n");
	}
      ce += ce_len;
    }
  printf ("\n");
}


caddr_t *
itc_bm_array (it_cursor_t * itc, buffer_desc_t * buf)
{
  dk_set_t res = NULL;
  db_buf_t bm, ce;
  int off;
  short bm_len;
  bitno_t bm_start;
  dbe_key_t * key = itc->itc_insert_key;
  dtp_t dtp = key->key_bit_cl->cl_sqt.sqt_dtp;
  BIT_COL (bm_start, buf, itc->itc_row_data, key);
  KEY_PRESENT_VAR_COL (itc->itc_insert_key, itc->itc_row_data, (*key->key_bm_cl), off, bm_len);
  ce = bm = itc->itc_row_data + off;
  while (ce < bm + bm_len)
    {
      int ce_len = CE_LENGTH (ce);
      bitno_t ce_start = bm_start + CE_OFFSET (ce);
      if (!ce_len)
	{
	  printf ("Error: 0 length ce\n");
	  break;
	}
      if (CE_IS_SINGLE (ce))
	{
	  dk_set_push (&res, box_iri_int64 (bm_start + (LONG_REF_NA (ce) & 0x7fffffff), dtp));
	}
      else if (CE_IS_ARRAY (ce))
	{
	  int inx;
	  for (inx = 0; inx < (ce_len - 4) / 2; inx++)
	    {
	      dk_set_push (&res, box_iri_int64 (ce_start + SA_REF (ce + 4, inx), dtp));
	    }
	}
      else
	{
	  short bit = 0;
	  for (;;)
	    {
	      bit = ce_bitmap_value (ce + 4, bit, 1);
	      if (bit == CE_N_VALUES)
		break;
	      dk_set_push (&res, box_iri_int64 (ce_start + bit, dtp));
	      bit++;
	    }
	}
      ce += ce_len;
    }
  return (caddr_t*)list_to_array (dk_set_nreverse (res));
}


void
ce_array_to_bitmap (db_buf_t ce)
{
  dtp_t temp[CE_MAX_LENGTH];
  int inx;
  memset (temp, 0, sizeof (temp));
  /* the array bitmap is overflowed by one at the point it converts to bitmap */
  for (inx = 0; inx < 1 + (CE_N_VALUES / 16); inx++)
    {
      short bit = SA_REF (ce + 4, inx);
      if (bit < 0 || bit >= CE_N_VALUES)
	{
	  log_error ("bit value in array bitmap out of range: %d.", (int)bit);
	  continue;
	}
      temp[4 + (bit >> 3)] |= 1 << (bit & 7);
    }
  memcpy (ce + 4, &temp[4], sizeof (temp) - 4);
  ce[2] = ce[2] & 0xf7; /*reset the bit of 8's in byte at inx 2 */
  /* the 4 first bytes stay the same, except one bit is reset to indicate that this is a bitmap and not an array */
  CE_SET_LENGTH (ce, CE_MAX_LENGTH);
  /* it was 2 over the limit when it came in */
}


int
ce_array_bit_inx (db_buf_t ce, int bit)
{
  /* return index of the given bit in the array of the ce.  If the bit itself is not there, return the index of the next higher.  If there is none higher, return the inx of the short after the end */
  int ce_len = CE_LENGTH(ce);
  db_buf_t  arr = ce + 4;
  int n_bits = (ce_len - 4) / 2;
  int low = 0, high = n_bits, guess;
  for (;;)
    {
      if (low == high)
	return low ;
      if (low + 1 == high)
	{
	  if (SA_REF (arr, low) >= bit)
	    return low;
	  return high;
	}
      guess = low + ((high - low) / 2);
      if (bit == SA_REF (arr, guess))
	return guess;
      if (SA_REF (arr, guess) > bit)
	high = guess;
      else
	low = guess;
    }
}


int
ce_array_insert (db_buf_t ce, int bit)
{
  int ce_len = CE_LENGTH (ce);
  int n_bits = (ce_len - 4) / 2;
  db_buf_t arr = (ce + 4);
  int inx = ce_array_bit_inx (ce, bit);
  if (inx >= n_bits)
    {
      SA_SET (arr, inx, bit);
    }
  else if (SA_REF (arr, inx) == bit)
    return ce_len; /* already set */
  else
    {
      memmove (arr + 2 * (inx+1), arr+ 2 * inx, (n_bits - inx) * 2);
      SA_SET (arr, inx, bit);
    }
  CE_SET_LENGTH (ce, ce_len + 2);
  return ce_len + 2;
}


#define BI_FITS 0
#define BI_EXTENDED 2
#define BI_SPLIT 3
void
bm_ck (db_buf_t bm, int bm_len)
{
  int ce_len = CE_LENGTH (bm);
  if (bm_len >0 && ce_len > bm_len) GPF_T1 ("ce longer than bm");
}


int n_bm_ins;

int
bm_insert (bitno_t bm_start, db_buf_t bm, short * bm_len_ret, bitno_t value, int bytes_available, db_buf_t split_ret,
	      short * split_len_ret)
{
  /* adds a bit in place and if the string expands more than bytes_available, returns the result in expanded_ret, otherwise does it in place.  Splits if needed,
   * if there is a split then the left side is in place and the right side in expanded_ret */
  short bm_len = *bm_len_ret;
  dtp_t ext_auto[CE_MAX_LENGTH + 10]; /*margin for overflow */
  db_buf_t ext = ext_auto;
  db_buf_t ce = bm;
  int new_ce_len = 0, old_ce_len = 0, ce_len = 0;
  char ins_at_end = 0;
  n_bm_ins++;
  while (ce < bm + bm_len)
    {
      bitno_t ce_start = bm_start + CE_OFFSET (ce);
      ce_len = CE_LENGTH (ce);
      if (value < ce_start)
	{
	  /* insert a single value ce before this ce */
	  old_ce_len = 0; /* means there is a new ce */
	  LONG_SET_NA (ext, (value - bm_start) | 0x80000000);
	  new_ce_len = 4;
	  break;
	}
      else if (value < ce_start + CE_N_VALUES)
	{
	  /* set the bit in this ce */
	  if (CE_IS_SINGLE (ce))
	    {
	      int offset1 = LONG_REF_NA (ce) & 0x7fffffff;
	      if (value - bm_start== offset1)
		return BI_FITS;
	      LONG_SET_NA (ext, (ce_start - bm_start) | CE_ARRAY_MASK | 6); /* 4 header and 2 content */
	      SHORT_SET_NA (ext + 4, offset1 - (ce_start - bm_start));
	      new_ce_len = ce_array_insert (ext, (value ) -  ce_start);
	      old_ce_len = 4;
	      break;
	    }
	  if (CE_IS_ARRAY(ce))
	    {
	      memcpy (ext, ce, ce_len);
	      old_ce_len = ce_len;
	      new_ce_len = ce_array_insert (ext, value - ce_start);
	      if (new_ce_len > CE_MAX_LENGTH)
		{
		  ce_array_to_bitmap (ext);
		  new_ce_len = CE_MAX_LENGTH;
		}
	      break;
	    }
	  else
	    {
	      int bit = value - ce_start;
	      ce[4 + (bit >> 3)] |= 1 << (bit & 7);
	      return BI_FITS;
	    }
	}
      ce += CE_LENGTH (ce);
    }
  if (!old_ce_len && !new_ce_len)
    {
      /* insert single valued ce at the end */
      LONG_SET_NA (ext, (value - bm_start) | 0x80000000);
      new_ce_len = 4;
      ins_at_end = 1;
    }
  if (bm_len + new_ce_len - old_ce_len > CE_MAX_LENGTH)
    {
      db_buf_t split_ce = bm;
      db_buf_t loop_ce = bm;
      db_buf_t ins_ce = ce;
      if (ins_at_end && ce_len > CE_MAX_LENGTH - 4)
	{
	  /* Full array or array one less than full first. 0 or 2 bytes left at end.  No room.  Gotta split the array on one side and the single on the other */
	  split_ce = ce;
	}
      else if (ce == bm && CE_LENGTH (ce) == CE_MAX_LENGTH)
	split_ce = bm;
      else
	{
	  while (loop_ce < bm + bm_len)
	    {
	      split_ce = loop_ce;
	      if (split_ce > bm + (CE_MAX_LENGTH / 2))
		break;
	      loop_ce += CE_LENGTH (loop_ce);
	    }
	}
      memcpy (split_ret, split_ce, bm_len - (split_ce - bm));
      *bm_len_ret = split_ce - bm;
      *split_len_ret = bm_len - (split_ce - bm);
      if (ins_at_end || ins_ce >= split_ce)
	{
	  ins_ce = split_ret + (ins_ce - split_ce);
	  memmove (ins_ce + new_ce_len, ins_ce + old_ce_len, *split_len_ret - (ins_ce - split_ret) - old_ce_len);
	  memcpy (ins_ce, ext, new_ce_len);
	  *bm_len_ret = split_ce - bm;
	  *split_len_ret = bm_len - (split_ce - bm) + new_ce_len - old_ce_len;
	  return BI_SPLIT;
	}
      else
	{
	  /* the insertion is below the split point */
	  memmove (ins_ce + new_ce_len, ins_ce + old_ce_len, *bm_len_ret - (ins_ce - bm) - old_ce_len);
	  (*bm_len_ret) += new_ce_len - old_ce_len;
	  memcpy (ins_ce, ext, new_ce_len);
	}
      return BI_SPLIT;
    }
  if (old_ce_len > bm_len) GPF_T1 ("ce is longer than containing bm");
  /* will fit without split.  See if fits in place or row must nbe refitted */
  if (new_ce_len - old_ce_len > bytes_available)
    {
      db_buf_t target;
      memcpy (split_ret, bm, ce - bm);
      memcpy (target = split_ret + (ce - bm), ext, new_ce_len);
      memcpy (target + new_ce_len, ce + old_ce_len, bm_len - (ce - bm)- old_ce_len);
      *split_len_ret = *bm_len_ret = bm_len + new_ce_len - old_ce_len;
      return BI_EXTENDED;
    }
  /* will fit.  Move all stuff after the ce forwards by the added length */
  memmove (ce + new_ce_len, ce + old_ce_len, bm_len - (ce - bm) - old_ce_len);
  memcpy (ce, ext, new_ce_len);
  *bm_len_ret = bm_len + new_ce_len - old_ce_len;
  return BI_FITS;
}


void
key_make_bm_specs (dbe_key_t * key)
{
  search_spec_t * sp = key->key_insert_spec.ksp_spec_array;
  search_spec_t ** bm_ins = &key->key_bm_ins_spec.ksp_spec_array;
  search_spec_t ** bm_leading = &key->key_bm_ins_leading.ksp_spec_array;
  while (sp)
    {
      NEW_VARZ (search_spec_t, sp3);
      memcpy (sp3, sp, sizeof (search_spec_t));
      *bm_ins = sp3;
      bm_ins = &sp3->sp_next;
      if (sp->sp_next)
	{
	  NEW_VARZ (search_spec_t, sp2);
	  memcpy (sp2, sp, sizeof (search_spec_t));
	  *bm_leading = sp2;
	  bm_leading = &sp2->sp_next;
	}
      else
      {
	*bm_leading = NULL;
	sp3->sp_max_op = CMP_LTE;
	sp3->sp_max = sp3->sp_min;
	sp3->sp_min_op = CMP_NONE;
	sp3->sp_min = 0;
      }
      sp = sp->sp_next;
    }
  ksp_cmp_func (&key->key_bm_ins_spec, NULL);
  if (!key->key_bm_ins_spec.ksp_key_cmp)
    key->key_bm_ins_spec.ksp_key_cmp = pg_key_compare;
  ksp_cmp_func (&key->key_bm_ins_leading, NULL);
  if (!key->key_bm_ins_leading.ksp_key_cmp)
    key->key_bm_ins_leading.ksp_key_cmp = pg_key_compare;
}


void
itc_insert_at_lt (it_cursor_t * it, buffer_desc_t * buf, row_delta_t * rd)
{
  row_lock_t * rl_flag = KI_TEMP != it->itc_insert_key->key_id && !it->itc_non_txn_insert ? INS_NEW_RL : NULL;
  rd->rd_keep_together_pos = ITC_AT_END;
  it->itc_row_key = it->itc_insert_key;
  it->itc_lock_mode = PL_EXCLUSIVE;

  if (BUF_NEEDS_DELTA (buf))
    {
      ITC_IN_KNOWN_MAP (it, it->itc_page);
      itc_delta_this_buffer (it, buf, DELTA_MAY_LEAVE);
      ITC_LEAVE_MAP_NC (it);
    }
  if (!buf->bd_is_write)
    GPF_T1 ("insert and no write access to buffer");
  itc_skip_entry (it, buf);
  ITC_AGE_TRX (it, 2);
  itc_insert_dv (it, &buf, rd, 0, rl_flag);
}


void
itc_bm_insert_single (it_cursor_t * itc, buffer_desc_t * buf, row_delta_t * rd, int prev_rc)
{
  /* this makes a singleton entry.  The cursor is on the page.  prev_rc indicates on which side to insert.
   * DVC_LESSS means after the row, DVC_GREATER means before the row, all else means do a new seek */
  dbe_key_t * key = itc->itc_insert_key;
  caddr_t save_param = (caddr_t)(ptrlong) -1;
  row_delta_t upd_rd;
  caddr_t upd_vals[16];
  int rc;

    /* set the length of the bm string field to 0 */
#if SINGLETON
#error singleton bm rows not done
  CL_SET_LEN (key, cl, image + IE_FIRST_KEY, 0);
#else
  {
    bitno_t value = unbox_iri_int64 (rd->rd_values[key->key_bit_cl->cl_nth]);
    bitno_t bm_start = CE_ROUND (value);
    caddr_t box = box_iri_int64 (bm_start, key->key_bit_cl->cl_sqt.sqt_dtp);
    dtp_t bmstr[4];
    upd_rd = *rd;
    upd_rd.rd_values = upd_vals;
    upd_rd.rd_allocated = RD_AUTO;
    if (rd->rd_n_values > 15) GPF_T1 ("bm inx of over 16 parts notrt allowed");
    memcpy (&upd_vals, rd->rd_values, sizeof (caddr_t) * rd->rd_n_values);
    LONG_SET_NA (&bmstr[0], 0x80000000 | (value - bm_start));
    save_param = itc->itc_search_params[key->key_n_significant - 1];
    itc->itc_search_params[key->key_n_significant - 1] = box;
    ITC_OWNS_PARAM (itc, box);
    upd_rd.rd_values[key->key_bit_cl->cl_nth] = box_iri_int64 (bm_start, key->key_bit_cl->cl_sqt.sqt_dtp);
    ITC_OWNS_PARAM (itc, upd_rd.rd_values[key->key_bit_cl->cl_nth]);
    upd_rd.rd_values[key->key_bm_cl->cl_nth] = box_dv_short_nchars ((caddr_t)bmstr, 4);
    ITC_OWNS_PARAM (itc, upd_rd.rd_values[key->key_bm_cl->cl_nth]);
#endif
    if (DVC_LESS == prev_rc
	&& !itc->itc_write_waits)
      {
  upd_rd.rd_itc = itc;
	itc_insert_at_lt (itc, buf, &upd_rd);
	itc->itc_search_params[key->key_n_significant - 1] = save_param;
    	return;
      }
      itc_page_leave  (itc, buf);
      itc->itc_search_mode = SM_INSERT;
  }
  itc->itc_key_spec = itc->itc_insert_key->key_insert_spec; /* have insert specs, there can be other specs from prev seek */
  upd_rd.rd_itc = itc;
  rc = itc_insert_unq_ck (itc, &upd_rd, NULL);
  itc->itc_search_params[key->key_n_significant - 1] = save_param;
  itc->itc_search_mode = SM_INSERT;
}


void
upd_truncate_row (it_cursor_t * itc, buffer_desc_t * buf, int nl)
{
  int bytes_left;
  int ol;
  db_buf_t page, row;
  page_map_t * pm = buf->bd_content_map;
  if (!buf->bd_is_write || ! buf->bd_is_dirty)
    GPF_T1 ("update w/o write access");
  if (ITC_IS_LTRX (itc)
      && (itc->itc_ltrx && (buf->bd_page != itc->itc_page || (!itc->itc_non_txn_insert && itc->itc_page != itc->itc_pl->pl_page))))
    GPF_T1 ("inconsistent pl_page, bd_page and itc_page in upd_refit_row");
  page = buf->bd_buffer;
  row = page + pm->pm_entries[itc->itc_map_pos];
  ol = row_length (row, itc->itc_row_key);
  if (ROW_ALIGN (nl) > ROW_ALIGN (ol))
    GPF_T1 ("row is not supposed to get longer in upd_truncate_row");
  bytes_left = ROW_ALIGN (ol) - ROW_ALIGN (nl);
  if (bytes_left)
    {
      page_write_gap (row + ROW_ALIGN (nl), bytes_left);
      pm->pm_bytes_free += bytes_left;
      if (pm->pm_entries[itc->itc_map_pos] + ROW_ALIGN (ol) == pm->pm_filled_to)
	pm->pm_filled_to -= bytes_left;
    }
}


/* this is bad whichever way one cuts it.
 *  A transit of an itc takes place when the bm row it is registered at splits.  Some goo to the right side.
 * Now this cannot be very well done inside the insert of the  right side because of page map lock order.
 * So it is done after the fact.  But many concurrent inserts can have the itc transiting.
 * So every insert must remember which itc it made to transit.  But because many transits can be going at the same time for one itc,
 * we must count how many transits are in fact going and reset the transiting flag only after the last transit is done.  Hence there is a local and global list of transiting itcs.   Remove the local list from the global list and reset the transit flag for those that are no longer in the list. */


dk_set_t transit_itc_list;
dk_mutex_t * transit_list_mtx;

#define itcs_see_different_version(itc, reg) \
  (ITC_CURSOR == registered->itc_type && itc->itc_ltrx != reg->itc_ltrx && ISO_COMMITTED == reg->itc_isolation)

void
itc_invalidate_bm_crs (it_cursor_t * itc, buffer_desc_t * buf, int is_in_transit, dk_set_t * local_transits)
{
  it_cursor_t * registered;
  registered = buf->bd_registered;
  while (registered)
    {
      if (registered->itc_map_pos == itc->itc_map_pos)
	{
	  if (itc->itc_bp.bp_is_pos_valid && registered->itc_bp.bp_value == itc->itc_bp.bp_value
	      && !itcs_see_different_version (itc, registered))
	    registered->itc_is_on_row = 0; /*marks deletion of the value at which registered was */
	  registered->itc_bp.bp_is_pos_valid = 0;
	  if (is_in_transit)
	    {
	      mutex_enter (transit_list_mtx);
	      dk_set_push (&transit_itc_list, (void*)registered);
	      mutex_leave  (transit_list_mtx);
	      dk_set_push (local_transits, (void*) registered);
	      registered->itc_bp.bp_transiting = 1;
	    }
	}
      registered = registered->itc_next_on_page;
    }
}

void
bm_reset_transits (dk_set_t local_transits)
{
  dk_set_t * prev;
  dk_set_t all_transits;
  mutex_enter (transit_list_mtx);
  DO_SET (it_cursor_t *, transiting, &local_transits)
    {
      prev = &transit_itc_list;
      all_transits = transit_itc_list;
      while (all_transits)
	{
	  if (transiting == (it_cursor_t*) all_transits->data)
	    {
	      if (!dk_set_member (all_transits->next, (void*)transiting))
		transiting->itc_bp.bp_transiting = 0;
	      else
		printf ("bing. itc %p is in more than one local transit lists\n", transiting);
	      *prev = all_transits->next;
	      all_transits->next = NULL;
	      dk_set_free (all_transits);
	      break;
	    }
	  prev = &all_transits->next;
	  all_transits = all_transits->next;
	}
    }
  END_DO_SET();
  mutex_leave (transit_list_mtx);
  dk_set_free (local_transits);
}


caddr_t
box_iri_int64 (int64 n, dtp_t dtp)
{
  if (DV_IRI_ID_8 == dtp || DV_IRI_ID == dtp)
    return box_iri_id (n);
  else
    return box_num (n);
}


void
itc_bm_split_move_crs (it_cursor_t * itc, dk_set_t local_transits)
{
  /* the left and right sides are marked by a plh.  Enter left, take the concerned out, enter right, put them there.
   *      As the position of each becomes known, reset the transiting bit */
  bitno_t r_split = unbox_iri_int64 (itc->itc_search_params[itc->itc_search_par_fill - 1]);
  buffer_desc_t * left_buf;
  int fill = 0, inx;
  it_cursor_t * cr_temp[1000];
  placeholder_t * right = itc->itc_bm_split_right_side;
  placeholder_t * left = itc->itc_bm_split_left_side;
  it_cursor_t * registered;

  if (!right)
    {
      log_error ("itc_bm_split_move_crs with no itc_bm_split_right_side");
      bm_reset_transits (local_transits);
      return;
    }

  left->itc_bp.bp_transiting = 0;
  right->itc_bp.bp_transiting = 0;
  left_buf = itc_set_by_placeholder (itc, itc->itc_bm_split_left_side);
  registered = left_buf->bd_registered;
  while (registered)
    {
      if (registered != (it_cursor_t*) left
	  && registered->itc_map_pos == left->itc_map_pos)
	{
	  /* if it is on the split row and above the split point or if it has not yet read the splitting row because it was locked */
	  if (registered->itc_bp.bp_just_landed || registered->itc_bp.bp_value >= r_split)
	    cr_temp[fill++]= registered;
	  if (fill > 999)
	    GPF_T1 ("over 1000 crs registered for bm row split");
	}
      registered = registered->itc_next_on_page;
    }
  for (inx = 0; inx < fill; inx++)
    itc_unregister_inner (cr_temp[inx], left_buf, 1);
  if (right->itc_page != left->itc_page)
    {
      page_leave_outside_map (left_buf);
      left_buf = itc_set_by_placeholder (itc, right);
    }
  for (inx = 0; inx < fill; inx++)
    {
      cr_temp[inx]->itc_to_reset = RWG_WAIT_SPLIT; /*if just landed, this will make it reset the search*/
      cr_temp[inx]->itc_map_pos = right->itc_map_pos;
      cr_temp[inx]->itc_page = right->itc_page;
      cr_temp[inx]->itc_bp.bp_is_pos_valid = 0;
      itc_register (cr_temp[inx], left_buf);
    }
  page_leave_outside_map (left_buf);
  bm_reset_transits (local_transits);
}

int bmck;

void
itc_bm_insert_in_row (it_cursor_t * itc, buffer_desc_t * buf, row_delta_t * rd)
{
  /* the itc is on a row.  It can be a singleton or one with ce's.  If singleton, delete
   * the singleton and make a 2 value row with the singleton and the new row. Otherwise add the value to the ce's on the row, possibly splitting the row */
  row_delta_t upd_rd;
  caddr_t upd_values[16];
  caddr_t save_param = (caddr_t)(ptrlong)-1;
  dk_set_t volatile local_transits = NULL;
  int off, len, rc, row_reserved, row_align_len, inx;
  bitno_t r_start;
  db_buf_t page, row;
  dtp_t ext_auto[CE_MAX_LENGTH + 10]; /* space for overflow */
  db_buf_t ext = ext_auto;
  bitno_t bm_start, last;
  dbe_key_t *key = itc->itc_insert_key;
  bitno_t value = unbox_iri_int64 (rd->rd_values[key->key_bit_cl->cl_nth]);
  db_buf_t loop_ce;
  short bm_len, ext_len = 0, space_at_end;
  int is_single;
  placeholder_t left_pl;
  dbe_col_loc_t * value_cl, *bm_cl = itc->itc_insert_key->key_bm_cl;
  value_cl = key->key_bit_cl;
  bmck++;
  pg_check_map (buf);
  if (!buf->bd_is_write || buf->bd_readers)
    GPF_T1 ("should have excl buffer in bm ins in row");
  itc_bm_ends (itc, buf, &bm_start, &last, &is_single);
  row = buf->bd_buffer + buf->bd_content_map->pm_entries[itc->itc_map_pos];
  if (is_single && !IE_ISSET (row, IEF_DELETE))
    {
      GPF_T1 ("singleton bm not in use");
#if 0
      if (BITS_IN_RANGE (value, bm_start))
	{
	  bitno_t prev_value = bm_start;
	  bm_start = CE_ROUND (MIN (bm_start, value));
	  if (IS_64_DTP (value_cl->cl_sqt.sqt_dtp))
	    {
	      INT64_SET (image + value_cl->cl_pos, bm_start);
	    }
	  else
	    LONG_SET (image + value_cl->cl_pos, bm_start);
	  bm_len = 0;
	  KEY_COL (key, image, (*bm_cl), off, len);
	  bm = image + off;
	  bm_insert (bm_start, bm, &bm_len, value, 100, ext, &ext_len);
	  bm_insert (bm_start, bm, &bm_len, prev_value, 100, ext, &ext_len);
	  CL_SET_LEN (key, bm_cl, image, bm_len);
	  itc_delete (itc, &buf, 0);
	  itc_page_leave  (itc, buf);
	  {
	    caddr_t box = box_iri_int64 (bm_start, itc->itc_insert_key->key_bit_cl->cl_sqt.sqt_dtp);
	    ITC_OWNS_PARAM (itc, box);
	    itc->itc_search_params[itc->itc_search_par_fill - 1] = box;
	    itc->itc_key_spec = itc->itc_insert_key->key_insert_spec;
	    itc->itc_desc_order = 0;
	    rd->rd_itc = itc;
	    itc_insert_unq_ck (itc, image, NULL);
	  }
	}
      else
	{
	  itc_bm_insert_single (itc, buf, image, DVC_INDEX_END);
	}
      return;
#endif
    }
  /* now the row is a collection of ce's. Insert in there.  If the new value would make a new ce in front, make a singleton row so as not to have to reset the offsets of the c's and maybe splitting just because the start bit no changes.  */
  if (!BITS_IN_RANGE (bm_start, value)
      || value < bm_start
      || IE_ISSET (row, IEF_DELETE))
    {
      itc_bm_insert_single (itc, buf, rd, DVC_INDEX_END);
      return;
    }
  KEY_PRESENT_VAR_COL (itc->itc_insert_key, itc->itc_row_data, (*key->key_bm_cl), off, len);
  row_reserved = row_length (row, itc->itc_insert_key);
  row_align_len = ROW_ALIGN (off + len);
  space_at_end = row_space_after (buf, itc->itc_map_pos);
  bm_len = len;
  if (!itc->itc_ltrx->lt_is_excl && !itc->itc_non_txn_insert)
    {
      lt_rb_update (itc->itc_ltrx, buf, row);
    }
  if (!buf->bd_is_dirty)
    {
      ITC_IN_KNOWN_MAP (itc, buf->bd_page);
      itc_delta_this_buffer (itc, buf, DELTA_MAY_LEAVE);
      ITC_LEAVE_MAP_NC (itc);
    }
  if (!buf->bd_is_write || buf->bd_readers)
    GPF_T1 ("should have excl buffer in bm ins in row");

  page = buf->bd_buffer;
  BUF_BOUNDS_CHECK (buf);
  rc = bm_insert (bm_start, itc->itc_row_data + off, &bm_len, value, space_at_end, ext, &ext_len);
  BUF_BOUNDS_CHECK (buf);
  if (BI_FITS == rc)
    bm_ck (row + off, bm_len);
  else if (BI_EXTENDED == rc)
    bm_ck (ext, ext_len);
  if (BI_FITS == rc)
    {
      int new_row_len;
      int row_delta;
      page_map_t * pm = buf->bd_content_map;
      CL_SET_LEN (key, bm_cl, row, bm_len);
      new_row_len = row_length (row, itc->itc_insert_key);
      row_delta = ROW_ALIGN (new_row_len) - ROW_ALIGN (row_reserved);
      buf->bd_content_map->pm_bytes_free -= row_delta;
      if (pm->pm_filled_to == pm->pm_entries[itc->itc_map_pos] + ROW_ALIGN (row_reserved))
	pm->pm_filled_to += row_delta;
      else if (pm->pm_filled_to < pm->pm_entries[itc->itc_map_pos] + row_reserved)
	GPF_T1 ("row in bm passes over fill limit of page");
      space_at_end &= ~1; /* round down to even */
      if (space_at_end - row_delta >= 2)
	page_write_gap (row + ROW_ALIGN (new_row_len), space_at_end - row_delta);
      pg_check_map (buf);
      itc->itc_bp.bp_is_pos_valid = 0;
      itc_invalidate_bm_crs (itc, buf, 0, NULL);
      pa_page_leave (itc, buf, RWG_WAIT_KEY);
      return;
    }
  if (BI_EXTENDED == rc)
    {
      /* make a new row into the rd, same keys as the row here but different bm string and refit that */
      dbe_col_loc_t * cl_array[16];
      memset (&upd_rd, 0, sizeof (upd_rd));
      upd_rd.rd_allocated = RD_ALLOCATED_VALUES;
      upd_rd.rd_values = upd_values;
      if (key->key_bm_cl->cl_nth >= sizeof (cl_array) / sizeof (caddr_t)) GPF_T1 ("too many leading parts in bm inx");
      page_row (buf, itc->itc_map_pos, &upd_rd, RO_LEAF);
      upd_rd.rd_values[key->key_bm_cl->cl_nth] = box_dv_short_nchars ((caddr_t)ext, ext_len);
      upd_rd.rd_n_values++;
      memset (&cl_array, 0, sizeof (caddr_t) * key->key_bm_cl->cl_nth);
      cl_array[key->key_bm_cl->cl_nth] = key->key_bm_cl;
      upd_rd.rd_upd_change = cl_array;
      upd_rd.rd_op = RD_UPDATE_LOCAL;
      upd_rd.rd_leaf = 0;
      if (!buf->bd_is_write || buf->bd_readers)
	GPF_T1 ("should have excl buffer in bm ins in row");
#ifdef MTX_DEBUG
      if (buf->bd_writer != THREAD_CURRENT_THREAD)
	GPF_T1 ("cur thread supposed to be the writer in ins bm row");
#endif
      itc_invalidate_bm_crs (itc, buf, 0, NULL);
      upd_refit_row (itc, &buf, &upd_rd, RD_UPDATE_LOCAL);
      rd_free (&upd_rd);
      return;
    }
  /* we have a split.  The old row gets shorter and we insert the right side row. */
  upd_truncate_row (itc, buf, off + bm_len);
  CL_SET_LEN (key, bm_cl, row, bm_len);
  pg_check_map (buf);
  /* now must make a row for the split part */
  memset (&upd_rd, 0, sizeof (upd_rd));
  upd_rd.rd_allocated = RD_ALLOCATED_VALUES;
      upd_rd.rd_values = upd_values;
  r_start = bm_start + CE_OFFSET (&ext[0]);
  save_param = itc->itc_search_params[key->key_n_significant - 1];
  itc->itc_search_params[key->key_n_significant - 1] = box_iri_int64 (r_start, key->key_bit_cl->cl_sqt.sqt_dtp);
  ITC_OWNS_PARAM (itc, itc->itc_search_params[key->key_n_significant - 1]);
  /* now the right side has a different start bit, so update the offsets of the ce's to the right of the split. */
  loop_ce = ext;
  while (loop_ce < ext + ext_len)
    {
      bitno_t r =  CE_OFFSET (loop_ce) - (r_start - bm_start);
      CE_SET_OFFSET (loop_ce, r);
      loop_ce += CE_LENGTH (loop_ce);
    }
  for (inx = 0; inx < key->key_n_significant; inx++)
    {
      if (inx == key->key_bit_cl->cl_nth)
	upd_rd.rd_values[key->key_bit_cl->cl_nth] = box_iri_int64 (r_start, value_cl->cl_sqt.sqt_dtp);
      else
	upd_rd.rd_values[inx] = box_copy_tree (rd->rd_values[inx]);
    }
  upd_rd.rd_values[key->key_bm_cl->cl_nth] = box_dv_short_nchars ((caddr_t)ext, ext_len);
  upd_rd.rd_n_values = key->key_bm_cl->cl_nth + 1;
  memcpy (&left_pl, itc, sizeof (placeholder_t));
  left_pl.itc_type = ITC_PLACEHOLDER;
  if (left_pl.itc_is_registered) GPF_T1 ("not supposed to be registered while inside bm_ins_on_row");
  itc_register ((it_cursor_t *)&left_pl, buf);
  itc->itc_bm_split_left_side = &left_pl;
  itc->itc_bm_split_right_side = NULL;
  itc->itc_bp.bp_is_pos_valid = 0; /* reset the flag so itc_invalidate_bm_crs does not consider the value it itc_bp.bp_value to be deleted */
  itc_invalidate_bm_crs (itc, buf, 1, (dk_set_t *) &local_transits);
  itc->itc_app_stay_in_buf = ITC_APP_LEAVE;
  itc->itc_search_mode = SM_INSERT;
  ITC_SAVE_FAIL (itc);
  ITC_FAIL (itc)
    {
      itc->itc_key_spec = itc->itc_insert_key->key_insert_spec;
      itc->itc_desc_order = 0;
      upd_rd.rd_key = itc->itc_insert_key;
      upd_rd.rd_make_ins_rbe = rd->rd_make_ins_rbe;
      upd_rd.rd_itc = itc;
      upd_rd.rd_map_pos = itc->itc_map_pos;
      itc_insert_at_lt (itc, buf, &upd_rd);
      itc_bm_split_move_crs (itc, local_transits);
    }
  ITC_FAILED
    {
      bm_reset_transits (local_transits);
      goto after_fail; /* do not exit, free the mem and placeholders, let the next one catch the busted transaction state */
    }
  END_FAIL (itc);

 after_fail:
  rd_free (&upd_rd);
  itc->itc_search_params[key->key_n_significant - 1] = save_param;
  if (itc->itc_bm_split_right_side)
    plh_free (itc->itc_bm_split_right_side);
  itc_unregister ((it_cursor_t *) &left_pl);
  ITC_RESTORE_FAIL (itc);
  /* now we have intercepted any reset and done the clup.  Now can throw if busted */
  CHECK_TRX_DEAD (itc, NULL, ITC_BUST_CONTINUABLE);
}

int enable_pos_bm_ins = 1;

void
key_bm_insert (it_cursor_t * itc, row_delta_t * rd)
{
  /* the itc search params are filled and the rd is the normal insert rd, minus the final bit string field */
  jmp_buf_splice * volatile prev_fail_ctx = itc->itc_fail_context;
  int rc, rc2;
  buffer_desc_t * buf;
  dbe_key_t * key = itc->itc_insert_key;

  FAILCK (itc);
#if 0
  /*code for debug break on a particular triple insert */
  {
    dtp_t tmp[6];
    tmp[0] = DV_IRI_ID;
    LONG_SET_NA (&tmp[1], 1002453);
    /* gspo = #i1000151         #i1000199         #i1017819         #i1002453 */
    if (1017819 == unbox_iri_id (itc->itc_search_params[0])
	&& 1000151 == unbox_iri_id (itc->itc_search_params[1])
	&& !memcmp (tmp, itc->itc_search_params[2], 5)
	/* && 1000199 == unbox_iri_id (itc->itc_search_params[3]) */
	)
      printf ("bing\n");
  }
#endif
  itc->itc_key_spec = key->key_bm_ins_spec;
  itc->itc_no_bitmap = 1; /* all ops here will ignore any bitmap features of the inx */
  itc->itc_lock_mode = PL_EXCLUSIVE;
  itc->itc_isolation = ISO_SERIALIZABLE;
  itc->itc_search_mode = SM_READ;
  itc->itc_desc_order = 1;
  ITC_FAIL (itc)
    {
      buf = itc_reset (itc);
      rc = itc_next (itc, &buf);
      if (!itc->itc_is_on_row)
	{
	  /* There is no row with the leading parts equal and bit field lte with the value being inserted */
	  itc->itc_desc_order = 0;
	  if (DVC_LESS == rc && !itc->itc_write_waits && enable_pos_bm_ins)
	    itc_bm_insert_single (itc, buf, rd, rc);
	  else
	    {
	      itc->itc_key_spec = key->key_bm_ins_leading;
	  rc2 = itc_next (itc, &buf);
	  if (DVC_MATCH != rc2)
	    {
	      /* no previous entry and no next entry.  The leading parts are unique.  Insert a singleton entry */
		  itc_bm_insert_single (itc, buf, rd, DVC_INDEX_END);
	    }
	  else
	    {
	      itc_bm_insert_in_row (itc, buf, rd);
	    }
	}
	}
      else
	itc_bm_insert_in_row (itc, buf, rd);
    }
  ITC_FAILED
    {
      longjmp_splice (prev_fail_ctx, RST_DEADLOCK);
    }
  END_FAIL (itc);
}


int
word_logcount (int word)
{
  int inx, res = 0;
  for (inx = 0; inx < 8 * sizeof (int); inx++)
    {
      res += word & 1;
      word = word >> 1;
    }
  return res;
}


uint32
byte_bits_f (dtp_t b)
{
  int i, fill = 0, res = 0;
  for (i = 0; i < 8; i++)
    {
      if (b & (1 << i))
	{
	  res |= i << fill;
	  fill += 3;
	}
    }
  return res;
}


void
bm_init ()
{
  int inx;
  for (inx = 0; inx < 256; inx++)
    {
    byte_logcount[inx] = word_logcount (inx);
      byte_bits[inx] = byte_bits_f (inx) | (byte_logcount[inx] << 28);
    }
}


int
bits_count (db_buf_t bits, int n_int32, int count_max)
{
  int inx, res = 0;
  for (inx = 0; inx < n_int32 * 4; inx += 4)
    {
      res += byte_logcount[bits[inx]]
	+ byte_logcount[bits[inx + 1]]
	+ byte_logcount[bits[inx + 2]]
	+ byte_logcount[bits[inx + 3]];
      if (res > count_max)
	return res;
    }
  return res;
}


int
bm_count (db_buf_t bm, short bm_len)
{
  int c = 0;
  db_buf_t ce = bm;
  if (0 == bm_len)
    return 1; /* singleton row */
  while (ce < bm + bm_len)
    {
      int ce_len = CE_LENGTH (ce);
      if (CE_IS_SINGLE (ce))
	c++;
      else if (CE_IS_ARRAY (ce))
	c += (ce_len - 4) / 2;
      else
	c += bits_count (ce + 4, CE_N_VALUES / 32, CE_N_VALUES);
      ce += ce_len;
    }
  return c;
}


int
itc_bm_count (it_cursor_t * itc, buffer_desc_t * buf)
{
  int off, len;
  db_buf_t row = buf->bd_buffer + buf->bd_content_map->pm_entries[itc->itc_map_pos];
  KEY_PRESENT_VAR_COL (itc->itc_insert_key, row, (*itc->itc_insert_key->key_bm_cl), off, len);
  return bm_count (row + off, len);
}


void
ce_bitmap_to_array (db_buf_t ce)
{
  dtp_t tmp[CE_MAX_LENGTH];
  db_buf_t res = tmp;
  int fill = 0;
  int bit = 0;
  for (;;)
    {
      bit = ce_bitmap_value (ce + 4, bit, 1);
      if (CE_N_VALUES == bit)
	break;
      SA_SET (res + 4, fill, bit);
      fill++;
      bit++;
      if (fill >= CE_N_VALUES / 16)
	GPF_T1 ("can't convert bitmap with more than 512 ones into an array");
    }
  CE_SET_LENGTH (ce, 4 + 2 * fill);
  ce[2] |= CE_BITMAP_TO_ARRAY;
  memcpy (ce + 4, res + 4, fill * 2);
}

int
bm_delete (bitno_t bm_start, db_buf_t bm, short * bm_len_ret, bitno_t value)
{
  db_buf_t del_at = NULL;
  int del_len = -1; /* will write at addr 0 if not set by accident */
  db_buf_t ce = bm;
  short bm_len = *bm_len_ret;
  while (ce < bm + bm_len)
    {
      bitno_t ce_start = bm_start + CE_OFFSET (ce);
      int ce_len = CE_LENGTH (ce);
      if (value < ce_start)
	{
	  /* not found, the ce with the value should have come up by now */
	  return DVC_LESS;
	}
      if (value < ce_start + CE_N_VALUES)
	{
	  if (CE_IS_SINGLE (ce))
	    {
	      bitno_t single = bm_start + (LONG_REF_NA (ce) & 0x7fffffff);
	      if (single == value)
		{
		  del_at = ce;
		  del_len = 4;
		  break;
		}
	      return DVC_LESS;
	    }
	  if (CE_IS_ARRAY (ce))
	    {
	      int bit = value - ce_start;
	      int inx = ce_array_bit_inx (ce, bit);
	      if (inx == (ce_len - 4) / 2)
		return DVC_LESS; /* was at end */
	      if (bit == SA_REF (ce + 4, inx))
		{
		  if (6 == ce_len)
		    {
		      /* value in a 1 elt array (4 header, 2 value).  Del the ce */
		      del_at = ce;
		      del_len = 6;
		      break;
		    }
		  del_at = ce + 4 + 2 * inx;
		  del_len = 2;
		  CE_SET_LENGTH (ce, ce_len - 2);
		  break;
		}
	      return DVC_LESS;
	    }
	  else
	    {
	      int bit = value - ce_start;
	      db_buf_t bits = ce + 4;
	      if (bits[bit >> 3] & (1 << (bit & 7)))
		{
		  bits[bit >> 3] &= ~(1 << (bit & 7));
		  if (bits_count (bits, CE_N_VALUES / 32, 400) < 400)
		    {
		      int new_len;
		      ce_bitmap_to_array (ce);
		      new_len = CE_LENGTH (ce);
		      del_at = ce + new_len;
		      del_len = CE_MAX_LENGTH - new_len;
		      break;
		    }
		  return DVC_MATCH;
		}
	      return DVC_LESS;
	    }
	}
      ce += ce_len;
    }
  if (del_len < 0)
    GPF_T;
  memmove (del_at, del_at + del_len, bm_len - (del_at - bm) - del_len);
  (*bm_len_ret) -= del_len;
  return DVC_MATCH;
}


int
itc_bm_delete (it_cursor_t * itc, buffer_desc_t ** buf_ret)
{
  /* comes in with itc on the row and buffer deltaed and rb image taken */
  short off, bm_len;
  bitno_t bm_start;
  int rc;
  dbe_key_t * key = itc->itc_insert_key;
  ASSERT_OUTSIDE_MAPS (itc);
  itc->itc_row_data = (*buf_ret)->bd_buffer + (*buf_ret)->bd_content_map->pm_entries[itc->itc_map_pos];
  itc->itc_is_on_row = 0;
  KEY_PRESENT_VAR_COL (itc->itc_insert_key, itc->itc_row_data, (*key->key_bm_cl), off, bm_len);
  if (0 == bm_len)
    return BM_DEL_ROW;  /* was a singleton, del as any other row */
  BIT_COL (bm_start, (*buf_ret), itc->itc_row_data, itc->itc_insert_key);
  rc = bm_delete (bm_start, itc->itc_row_data + off, &bm_len, itc->itc_bp.bp_value);
  if (DVC_MATCH != rc)
      return BM_DEL_DONE; /* the bit was not found, no change */
  upd_truncate_row (itc, *buf_ret, off + bm_len);
  CL_SET_LEN (key, key->key_bm_cl, itc->itc_row_data, bm_len);
  itc->itc_bp.bp_is_pos_valid = 1;
  itc_invalidate_bm_crs (itc, *buf_ret, 0, NULL);
  if (bm_len)
    return BM_DEL_DONE;
  return BM_DEL_ROW; /* went empty, del as a normal row */
}


/*
  itc_init_bm_search
  if there are no conditions for the bm col , the specs stay as they are.
  If there is an indexable condition for the bm col, then:
  itc_bmn_col gets the spec.
  if it is eq, the spec becomes the insert spec and the search is desc, org restored at the end.
  If it is lte/lt desc, the spec stays and desc order stays.
  If it is lt/llte asc, the spec stays and asc order stays.
  If it is gt/gte desc, the becomes the leading parts spec (no spec for bm col)  and desc stays.
  If it is gt/gte asc, the spec becomes the insert spec and order is set to desc for the random lookup.  Set back when landed

  If the spec is altered, the flag itc_bm_spec_replaced is  set.  This will alter the spec again at landing.
*/

void
itc_init_bm_search (it_cursor_t * itc)
{
  search_spec_t * sp = itc->itc_key_spec.ksp_spec_array;
  int n_specs = 0;
  dbe_key_t * key = itc->itc_insert_key;
  search_spec_t * bm_spec = NULL;
  memset (&itc->itc_bp, 0, sizeof (itc->itc_bp));
  itc->itc_bm_spec_replaced = 0;
  while (sp)
    {
      n_specs++;
      if (n_specs == key->key_n_significant)
	bm_spec = itc->itc_bm_col_spec = sp;
      sp = sp->sp_next;
    }
  if (!bm_spec)
    {
      itc->itc_bm_col_spec = NULL;
      return;
    }
  if (CMP_EQ == bm_spec->sp_min_op
      || (CMP_GT == bm_spec->sp_min_op && !itc->itc_desc_order)
      || (CMP_GTE == bm_spec->sp_min_op && !itc->itc_desc_order))
    {
      itc->itc_bm_spec_replaced = 1;
      itc->itc_key_spec = key->key_bm_ins_spec;
      itc->itc_desc_order = 1;
      itc->itc_search_mode = SM_READ;
      return;
    }
  if ((CMP_GT == bm_spec->sp_min_op && CMP_NONE == bm_spec->sp_max_op && itc->itc_desc_order)
      || (CMP_GTE == bm_spec->sp_min_op && CMP_NONE == bm_spec->sp_max_op && itc->itc_desc_order))
    {
      /* only lower limit and desc order.  Start at end and use row check for end. Seek with only leading parts */
      itc->itc_key_spec = itc->itc_insert_key->key_bm_ins_leading;
    }
  else if (itc->itc_desc_order
	   && bm_spec->sp_max_op != CMP_NONE && bm_spec->sp_min_op != CMP_NONE)
    {
      /* range in desc order.  put the lower limit to minint of the right type and save the old one.  The lower limit remains minint but the bm row check will use the copy of the org here added as the last search spec. */
      caddr_t minint = box_iri_int64 (BITNO_MIN, bm_spec->sp_cl.cl_sqt.sqt_dtp);
      ITC_OWNS_PARAM (itc, minint);
      ITC_SEARCH_PARAM (itc, itc->itc_search_params[bm_spec->sp_min]);
      itc->itc_search_params[bm_spec->sp_min] = minint;
    }

}


void
itc_bm_land (it_cursor_t * itc, buffer_desc_t * buf)
{
  /* the cursor is just landed, set the specs and direction to org if changed for the search */
  key_ver_t kv;
  search_spec_t * bm_spec;
  db_buf_t row;
  if ((bm_spec = itc->itc_bm_col_spec))
    {
      if (itc->itc_desc_order && itc->itc_bm_spec_replaced)
	{
	  itc->itc_desc_order = 0;
	  itc->itc_key_spec = itc->itc_insert_key->key_bm_ins_leading;
	}
      else if (itc->itc_desc_order
	       && CMP_NONE != bm_spec->sp_min_op
	       && CMP_NONE == bm_spec->sp_max_op)
	itc->itc_key_spec = itc->itc_insert_key->key_bm_ins_leading; /* when desc order and lower limit, do not compare bm col in landed search because this would sometimes exclude the last bitmap row */
    }
  itc->itc_bp.bp_new_on_row = 1;
  row = buf->bd_buffer + buf->bd_content_map->pm_entries[itc->itc_map_pos];
  kv = IE_KEY_VERSION (row);
  if (kv != itc->itc_insert_key->key_version)
    {
      /* left dummy, down or error */
      itc->itc_bp.bp_at_end = 1; /*row_check will set at first/last when arrives that far */
    }
}


int
byte_bit_after (int byte, int pos)
{
  /* returns the 1 bit in byte that is after pos. 8 if none */
  int n;
  for (n = pos + 1; n < 8; n++)
    {
      if (byte & (1<<n))
	return n;
    }
  return 8;
}

int
byte_bit_before  (int byte, int pos)
{
  /* returns the 1 bit in byte that is before  pos. -1 if none */
  int n;
  for (n = pos - 1; n >= 0; n--)
    {
      if (byte & (1<<n))
	return n;
    }
  return -1;
}


int
ce_bitmap_value (db_buf_t bits, short value, int is_fwd)
{
  /* returns the bit number at value or if value is not set, the next before or after, according to is_forward.  If no one bit is found in the direction given, return CE_N_VALUES
   * the bitmap is always CE_N_VALUES long. */
  int byte = value >> 3;
  int bit = value & 7;
  if (value < 0 || value >= CE_N_VALUES)
    return CE_N_VALUES;
  if (bits[byte] & (1 << bit))
    return value;
  if (bits[byte])
    {
      int after = is_fwd ? byte_bit_after (bits[byte], bit) : byte_bit_before (bits[byte], bit);
      if (after < 8 && after >= 0)
	return (byte << 3)  + after;
    }
  if (is_fwd)
    {
      for (byte = byte + 1; byte < CE_N_VALUES / 8; byte++)
	{
	  if (bits[byte])
	    return (byte << 3) | byte_bit_after (bits[byte], -1);
	}
    }
  else
    {
      for (byte = byte - 1; byte >= 0; byte--)
	{
	  if (bits[byte])
	    return (byte << 3) | byte_bit_before (bits[byte], 8);
	}
    }
  return CE_N_VALUES; /* out of range, no bits set in the given direction from value */
}


int
pl_ce_set (placeholder_t * itc, db_buf_t ce, short ce_len, bitno_t bm_start, bitno_t value, int is_fwd)
{
  /* set the pl at the bit given by value. Return DVC_MATCH if found.
   * if the bit at value is not on, set the pl to the next lower or higher bit, as per is_fwd and return DVC_LESS.
   * If there is no bit at or after value in the dir of is_fwd, set the pl to the lowest or highest of the ce and return DVC_GREATER
   * if below the first or after llast, bp_at_end is set. If below first, bp_below_start is also set.
   * In specific, using BITNO_MIN with fwd=0 and _MAX with fwd = 1 always go to the first and last bits of the ce respectively. */
  bitno_t ce_start = bm_start + CE_OFFSET (ce);
  int bit;
  itc->itc_bp.bp_is_pos_valid = 1;
  itc->itc_bp.bp_at_end = 0;
  itc->itc_bp.bp_below_start = 0;

  if (CE_IS_SINGLE (ce))
    {
      bitno_t ce_value = bm_start + (LONG_REF_NA (ce) & 0x7fffffff);
      itc->itc_bp.bp_value = ce_value;
      itc->itc_bp.bp_ce_type = CE_SINGLE;
      if (value == ce_value)
	return DVC_MATCH;
      else if (ce_value < value)
	{
	  if (is_fwd)
	    {
	      itc->itc_bp.bp_at_end = 1;
	      return DVC_GREATER;
	    }
	  return DVC_LESS;
	}
      itc->itc_bp.bp_below_start = 1;
      if (is_fwd)
	return DVC_LESS;
      itc->itc_bp.bp_at_end = 1;
      return DVC_GREATER;
    }
  if (CE_IS_ARRAY (ce))
    {
      int n_bits = (CE_LENGTH (ce) - 4) /2;
      db_buf_t arr = ce + 4;
      int inx;
      if (value < ce_start)
	{
	  itc->itc_bp.bp_value = ce_start + SA_REF (ce + 4, 0);
	  itc->itc_bp.bp_pos_in_ce = 0;
	  itc->itc_bp.bp_ce_type = CE_ARRAY;
	  itc->itc_bp.bp_at_end = 1;
	  itc->itc_bp.bp_below_start = 1;
	  return DVC_GREATER;
	}
      if (value >= ce_start + CE_N_VALUES)
	{
	  itc->itc_bp.bp_value = ce_start + SA_REF (ce + 4, n_bits - 1);
	  itc->itc_bp.bp_pos_in_ce = n_bits - 1;
	  itc->itc_bp.bp_ce_type = CE_ARRAY;
	  itc->itc_bp.bp_at_end = 1;
	  return DVC_GREATER;
	}
      inx = ce_array_bit_inx (ce, value - ce_start);
      if (inx == n_bits)
	{
	  itc->itc_bp.bp_value = ce_start + SA_REF (arr, n_bits - 1);
	  itc->itc_bp.bp_ce_type = CE_ARRAY;
	  itc->itc_bp.bp_pos_in_ce = n_bits - 1;
	  itc->itc_bp.bp_at_end = 1;
	  return DVC_GREATER;
	}
      if (value == ce_start + SA_REF (arr, inx))
	{
	  itc->itc_bp.bp_value = value;
	  itc->itc_bp.bp_pos_in_ce = inx;
	  itc->itc_bp.bp_ce_type = CE_ARRAY;
	  return DVC_MATCH;
	}
      if (0 == inx)
	{
	  /* all the values in the ce are gt than value */
	  itc->itc_bp.bp_value = ce_start + SA_REF (arr, 0);
	  itc->itc_bp.bp_ce_type = CE_ARRAY;
	  itc->itc_bp.bp_pos_in_ce = 0;
	  itc->itc_bp.bp_at_end = 1;
	  itc->itc_bp.bp_below_start = 1;
	  return DVC_GREATER;
	}
      /* now, we are in range, not off either end and not on row.  If if fwd, inx is the next higher.  So if backward, we decrement the inx */
      if (!is_fwd)
	inx--;
      itc->itc_bp.bp_value = ce_start + SA_REF (arr, inx);
      itc->itc_bp.bp_pos_in_ce = inx;
      itc->itc_bp.bp_ce_type = CE_ARRAY;
      return DVC_LESS;
    }
  else
    {
      db_buf_t bits = ce + 4;
      itc->itc_bp.bp_ce_type = CE_BITMAP;
      if (value < ce_start)
	{
	  int bit = ce_bitmap_value (bits, 0, 1);
	  itc->itc_bp.bp_value = ce_start + bit;
	  itc->itc_bp.bp_at_end = 1;
	  itc->itc_bp.bp_below_start = 1;
	  return DVC_GREATER;
	}
      if (value >= ce_start + CE_N_VALUES)
	{
	  int bit = ce_bitmap_value (bits, CE_N_VALUES - 1, 0);
	  itc->itc_bp.bp_value = ce_start + bit;
	  itc->itc_bp.bp_at_end = 1;
	  return DVC_GREATER;
	}
      bit = ce_bitmap_value (bits, value - ce_start, is_fwd);
      if (bit + ce_start == value)
	{
	  itc->itc_bp.bp_value = value;
	  return DVC_MATCH;
	}
      if (CE_N_VALUES == bit)
	{
	  /* the value is not set and no bit after it.  Set to last if fwd and first if bwd */
	  if (is_fwd)
	    bit = ce_bitmap_value (bits, CE_N_VALUES - 1, 0);
	  else
	    bit = ce_bitmap_value (bits, 0, 1);
	  itc->itc_bp.bp_value = ce_start + bit;
	  itc->itc_bp.bp_at_end = 1;
	  return DVC_GREATER;
	    }
      itc->itc_bp.bp_value = ce_start + bit;
      return DVC_LESS;
    }
}


db_buf_t
bm_prev_ce (db_buf_t bm, db_buf_t next_ce)
{
  db_buf_t ce = bm;
  if (bm == next_ce)
    return NULL;
  for (;;)
    {
      int len = CE_LENGTH (ce);
      if (ce + len == next_ce)
	return ce;
      ce += len;
      if (!len)
	GPF_T1 ("can't have zero len ce");
      if (ce - bm > CE_MAX_LENGTH )
	GPF_T1 ("in prev_ce, ce lengths go over the bm end ");
    }
}


db_buf_t
bm_last_ce (db_buf_t bm, short bm_len)
{
  db_buf_t ce = bm;
  int off = 0;
  for (;;)
    {
      int len = CE_LENGTH (ce);
      if (off + len >= bm_len)
	return ce;
      off += len;
      ce += len;
      if (!len)
	GPF_T1 ("can't have zero len ce");
      if (ce - bm > CE_MAX_LENGTH )
	GPF_T1 ("in prev_ce, ce lengths go over the bm end ");
    }
}


void
pl_set_at_bit (placeholder_t * pl, db_buf_t bm, short bm_len, bitno_t bm_start, bitno_t value, int is_desc)
{
  /* set the pl tpo the bit.  If the bit is not on,  set at bit right before or after, as per is_desc
   * if no more on bits in the direction, set bp_at_end. If a bit is found, bp_value is set to it.  */
  db_buf_t prev_ce = NULL;
  db_buf_t ce = bm;
  short ce_len;
  pl->itc_bp.bp_is_pos_valid = 1;
  pl->itc_bp.bp_at_end = 0;
  if (is_desc)
    {
      if (0 == bm_len)
	{
	  /* singleton entry */
	  pl->itc_bp.bp_ce_type = CE_SINGLETON_ROW;
	  if (bm_start> value)
	    {
	      pl->itc_bp.bp_at_end = 1;
	      return;
	    }
	  pl->itc_bp.bp_value = bm_start;
	  return;
	}
      ce = bm;
      while (ce < bm + bm_len)
	{
	  bitno_t ce_start = bm_start + CE_OFFSET (ce);
	  ce_len = CE_LENGTH (ce);
	  pl->itc_bp.bp_ce_offset = ce - bm;
	  if (value < ce_start)
	    {
	      if (prev_ce)
		{
		  pl_ce_set (pl, prev_ce, CE_LENGTH (prev_ce), bm_start, BITNO_MAX, 0);
		  pl->itc_bp.bp_ce_offset = prev_ce - bm;
		}
	      else
		pl->itc_bp.bp_at_end = 1;
	      return;
	    }
	  if (value < ce_start + CE_N_VALUES)
	    {
	      pl_ce_set (pl,ce, ce_len, bm_start, value, 0);
	      if (pl->itc_bp.bp_at_end)
		{
		  if (prev_ce)
		    {
		      pl_ce_set (pl, prev_ce, CE_LENGTH (prev_ce), bm_start, BITNO_MAX, 0);
		      pl->itc_bp.bp_ce_offset = prev_ce - bm;
		    }
		  else
		    pl->itc_bp.bp_at_end = 1;
		}
	      return;
	    }
	  prev_ce = ce;
	  ce += ce_len;
	}
      pl->itc_bp.bp_ce_offset = prev_ce - bm;
      pl_ce_set (pl, prev_ce, CE_LENGTH (prev_ce), bm_start, BITNO_MAX, 0);
      return;
    }
  else
    {
      if (0 == bm_len)
	{
	  /* singleton entry */
	  pl->itc_bp.bp_ce_type = CE_SINGLETON_ROW;
	  if (bm_start>= value)
	    {
	      pl->itc_bp.bp_value = bm_start;
	      return;
	    }
	  pl->itc_bp.bp_at_end = 1;
	  return;
	}
      ce = bm;
      while (ce < bm + bm_len)
	{
	  bitno_t ce_start = bm_start + CE_OFFSET (ce);
	  ce_len = CE_LENGTH (ce);
	  pl->itc_bp.bp_ce_offset = ce - bm;
	  if (value >= ce_start && value < ce_start + CE_N_VALUES)
	    {
	      pl_ce_set (pl, ce, ce_len, bm_start, value, 1);
	      if ( pl->itc_bp.bp_below_start)
		{
		  pl->itc_bp.bp_at_end = 0;
		  return;
		}
	      if (!pl->itc_bp.bp_at_end)
		return;
	      ce += ce_len;
	      if (ce >= bm + bm_len)
		{
		  pl->itc_bp.bp_at_end = 1;
		  return;
		}
	      pl->itc_bp.bp_ce_offset = ce - bm;
	      pl_ce_set (pl, ce, CE_LENGTH (ce), bm_start, BITNO_MIN, 1);
	      return;
	    }
	  if (value < ce_start)
	    {
	      pl_ce_set (pl, ce, ce_len, bm_start, BITNO_MIN, 1);
	      pl->itc_bp.bp_at_end = 0;
	      return;
	    }
	  prev_ce = ce;
	  ce += ce_len;
	}
      pl->itc_bp.bp_ce_offset = prev_ce - bm;
      pl_ce_set (pl, prev_ce, CE_LENGTH (prev_ce), bm_start, BITNO_MAX, 1);
    }
}


int
pl_next_bit (placeholder_t * itc, db_buf_t bm, short bm_len, bitno_t bm_start, int is_desc)
{
  db_buf_t ce = bm + itc->itc_bp.bp_ce_offset;
  if (!itc->itc_bp.bp_is_pos_valid)
    {
      log_error ("Invalid bit position on index: %s", itc->itc_tree->it_key->key_name);
      if (itc->itc_type == ITC_CURSOR)
	{
	  it_cursor_t * it = (it_cursor_t *) itc;
	  if (!wi_inst.wi_checkpoint_atomic && it->itc_ltrx)
	    itc_bust_this_trx (it, NULL, ITC_BUST_THROW);
	}
      GPF_T1 ("next/prev of non-valid bit pos");
    }
  switch (itc->itc_bp.bp_ce_type)
    {
    case CE_SINGLETON_ROW:
      itc->itc_bp.bp_at_end = 1;
      return DVC_GREATER;
    case CE_SINGLE:
      if (is_desc)
	goto prev_ce;
      else
	goto next_ce;

    case CE_ARRAY:
      {
	short inx = itc->itc_bp.bp_pos_in_ce, ce_len;
	if (is_desc && 0 == inx)
	  goto prev_ce;
	ce_len = CE_LENGTH (ce);
	if (!is_desc && inx + 1 >= (ce_len - 4) / 2)
	  goto next_ce;
	inx += is_desc ? -1 : 1;
	itc->itc_bp.bp_pos_in_ce = inx;
	itc->itc_bp.bp_value = bm_start + CE_OFFSET (ce) + SA_REF (ce + 4, inx);
	return DVC_MATCH;
      }
    case CE_BITMAP:
      {
	short bit = itc->itc_bp.bp_value - bm_start;
	bit += is_desc ? -1 : 1;
	if (bit < 0)
	  goto prev_ce;
	if (bit >= CE_N_VALUES)
	  goto next_ce;
	bit = ce_bitmap_value (ce + 4, bit, is_desc ? 0 : 1);
	if (CE_N_VALUES == bit)
	  {
	    if (is_desc)
	      goto prev_ce;
	    else
	      goto next_ce;
	  }
	itc->itc_bp.bp_value = bm_start + bit;
	return DVC_MATCH;
      }
    default: GPF_T1 ("unknown ce type in bitmap next/prev");
    }
 next_ce:
  ce += CE_LENGTH (ce);
  if (ce >= bm + bm_len)
    {
      itc->itc_bp.bp_at_end = 1;
      return DVC_GREATER;
    }
  itc->itc_bp.bp_ce_offset = ce - bm;
  pl_ce_set (itc, ce, CE_LENGTH (ce), bm_start, BITNO_MIN, 1);
  itc->itc_bp.bp_at_end = 0;
  return DVC_MATCH;
 prev_ce:
  ce = bm_prev_ce (bm, ce);
  if (!ce)
    {
      itc->itc_bp.bp_at_end = 1;
      return DVC_GREATER;
    }
  itc->itc_bp.bp_ce_offset = ce - bm;
  pl_ce_set (itc, ce, CE_LENGTH (ce), bm_start, BITNO_MAX, 0);
  itc->itc_bp.bp_at_end = 0;
  return DVC_MATCH;
}


int64
unbox_iri_int64 (caddr_t x)
{
  if (!IS_BOX_POINTER (x))
    return ((int64)((ptrlong)x));
  if (DV_LONG_INT == box_tag (x))
    return *(boxint*)x;
  if (DV_IRI_ID == box_tag (x))
    return *(iri_id_t*)x;
  return (int64)((ptrlong)(x));
}


int
itc_bp_cmp (it_cursor_t * itc, int param_inx)
{
  bitno_t n2, n1 = itc->itc_bp.bp_value;
  caddr_t param = itc->itc_search_params[param_inx];
  switch (DV_TYPE_OF (param))
    {
    case DV_LONG_INT:
      n2 = unbox (param);
      return NUM_COMPARE (n1, n2);
    case DV_IRI_ID:
      n2 = unbox_iri_id (param);
      return NUM_COMPARE (n1, n2);
    case DV_SINGLE_FLOAT:
      return cmp_double (((float)n1), *(float*) param, DBL_EPSILON);
    case DV_DOUBLE_FLOAT:
      return cmp_double (((double)n1),  *(double*)param, DBL_EPSILON);
    case DV_NUMERIC:
      {
	NUMERIC_VAR (n);
	numeric_from_int64 ((numeric_t) &n, n1);
	return (numeric_compare_dvc ((numeric_t) &n, (numeric_t) param));
	  }
	default: GPF_T;
    }
  return DVC_GREATER; /*not reached*/
}
int64
dv_to_int64 (box_t x)
{
  switch (DV_TYPE_OF (x))
    {
    case DV_IRI_ID_8:
    case DV_IRI_ID: return *(iri_id_t *)x;
    case DV_LONG_INT: return unbox (x);
    case DV_SINGLE_FLOAT: return unbox_float (x);
    case DV_DOUBLE_FLOAT: return unbox_double (x);
    case DV_NUMERIC:
      {
	int64 res;
	numeric_to_int64 ((numeric_t)x, &res);
	return res;
      }
    default: return 0;
    }
}


int
itc_bp_col_check (it_cursor_t * itc, search_spec_t * spec)
{
  int res, op = spec->sp_min_op;
  if (op != CMP_NONE)
    {
      short sp_min = spec->sp_min;
      /* trick here.  When reading range in desc order, the lower limit is set to minint of the appropriate type so that the lowest row whose bit col is likely below the lower limit will not be excluded.  So here use another value for the actual lower limit.  The last search param, an extra one is added by init search */
      if (itc->itc_desc_order && CMP_NONE != spec->sp_max_op)
	sp_min = itc->itc_search_par_fill - 1;
      res = itc_bp_cmp (itc, sp_min);
      /* The min operation is 1. EQ. 2 GTE, 3 GT */
      switch (op)
	{
	case CMP_EQ:
	  return res;
	case CMP_GT:
	  if (res != DVC_GREATER)
	    return DVC_LESS;
	  break;
	case CMP_GTE:
	  if (res == DVC_MATCH)
	    return res;
	  if (res == DVC_GREATER);
	  else
	    return DVC_LESS;
	  break;
	case CMP_HASH_RANGE:
	  if (DVC_MATCH != itc_hash_compare (itc, NULL, spec))
	    return DVC_LESS;
	  break;
	default:
	  GPF_T;	 /* Bad min op in search  spec */
	  return 0;	/* dummy */
	}
    }

  /* The lower boundary matches. Now check the upper */
  op = spec->sp_max_op;
  if (op != CMP_NONE)
    {
      int res;
      if (op == CMP_NONE)
	return DVC_MATCH;
      res = itc_bp_cmp (itc, spec->sp_max);
      switch (op)
	{
	case CMP_LT:
	  if (res == DVC_LESS)
	    return DVC_MATCH;
	  else
	    return DVC_GREATER;
	case CMP_LTE:
	  if (res == DVC_MATCH || res == DVC_LESS)
	    return DVC_MATCH;
	  else
	    return DVC_GREATER;
	default:
	  GPF_T;	 /* Bad max op in search  spec */
	  return 0;	/* dummy */
	}
    }
  return DVC_MATCH;
}


int
itc_bm_land_seek (it_cursor_t * itc, db_buf_t bm, short bm_len, bitno_t bm_start,
		  buffer_desc_t * buf)
{
  /* if eq, bm in range and not found, DVC_GREATER.
   * If no specs, set bp_at_end and let the next part handle this
   * if lower limit and  asc, set at lowest match, at end if none ret DVC_LESS to indicate going to next row.
   * if no lower limit and asc, go to start
   * if upper limit and desc, go to highest match, at end if none, ret dvc_less if none to go to prev row.
   * if no upper limit and desc, go to highest bit.
   * ret dvc_greater to mean end of search, dvc_match to continue checking, dvc_less to get the next row
   */
  int64 min = 0, max;
  search_spec_t * sp = itc->itc_bm_col_spec;
  if (!sp)
    {
      pl_set_at_bit ((placeholder_t *) itc, bm, bm_len, bm_start, itc->itc_desc_order ? BITNO_MAX : BITNO_MIN, itc->itc_desc_order);
      itc->itc_bp.bp_at_end = 0;
      return DVC_MATCH;
    }
  if (!itc->itc_desc_order)
    {
      if (CMP_NONE != sp->sp_min_op)
	min = dv_to_int64 (itc->itc_search_params[sp->sp_min]);
      switch (sp->sp_min_op)
	{
	case CMP_NONE:
	  pl_ce_set ((placeholder_t *) itc, bm, CE_LENGTH (bm), bm_start, BITNO_MIN, 0);
	  itc->itc_bp.bp_at_end = 0; /* it is on first bit  of first row, not at end of the anything even though technically below the first bit of the first row */
	  return DVC_MATCH;
	case CMP_EQ:
	  pl_set_at_bit ((placeholder_t *) itc, bm, bm_len, bm_start, min, 0);
	  if (!itc->itc_bp.bp_at_end && min == itc->itc_bp.bp_value)
	    return DVC_MATCH;
	  else
	    return DVC_GREATER; /* no eq, stop looking */

	case CMP_GT:
	  min++;
	case CMP_GTE:
	  pl_set_at_bit ((placeholder_t *) itc, bm, bm_len, bm_start, min, 0);
	  return DVC_MATCH;
	}
      GPF_T; /* should not have this min op */
    }
  if (CMP_NONE != sp->sp_max_op)
    max = dv_to_int64 (itc->itc_search_params[sp->sp_max]);
  else
    {
      pl_set_at_bit ((placeholder_t *) itc, bm, bm_len, bm_start, BITNO_MAX, 1);
      itc->itc_bp.bp_at_end = 0; /* on last bit of last row, even though technically placed above it */
      return DVC_MATCH;
    }
  if (CMP_LT == sp->sp_max_op)
    max--;
  pl_set_at_bit ((placeholder_t *)itc, bm, bm_len, bm_start, max, 1);
  if (itc->itc_bp.bp_value > max)
    return DVC_LESS; /* if the max was below the first bit in bm, the bp_value is set to the first bit and at_end is set.  Return DVC_LESS to cause caller to get the next row in desc order */
  itc->itc_bp.bp_at_end = 0;
  /* we can be at a value or above the highest of the bm.  They match lt/lte */
  return DVC_MATCH;
}



int
itc_bm_row_check (it_cursor_t * itc, buffer_desc_t * buf)
{
  key_source_t *ks;
  /* For bm inx row.  The key is the right key because no alters in non pk inx */
  search_spec_t *sp;
  db_buf_t bm;
  int off;
  short bm_len;
  bitno_t bm_start;
  dbe_key_t * key = itc->itc_insert_key;
  BIT_COL (bm_start, buf, itc->itc_row_data, key);
  KEY_PRESENT_VAR_COL (itc->itc_insert_key, itc->itc_row_data, (*key->key_bm_cl), off, bm_len);
  bm = itc->itc_row_data + off;
  if (itc->itc_bp.bp_just_landed)
    {
      itc_bm_land (itc, buf);
    }
  if (0 == bm_len)
    {
      itc->itc_bp.bp_at_end = 1;
      itc->itc_bp.bp_ce_type = CE_SINGLETON_ROW;
      itc->itc_bp.bp_value = bm_start;
      itc->itc_bp.bp_just_landed = 0;
      itc->itc_bp.bp_is_pos_valid = 1;
    }
  else
    {
      if (itc->itc_bp.bp_just_landed)
	{
	  /* row found, find the first bit based on search criteria */
	  int rc = itc_bm_land_seek (itc, bm, bm_len, bm_start, buf);
	  itc->itc_bp.bp_just_landed = 0;
	  if (DVC_GREATER == rc)
	    return DVC_GREATER;
	  if (itc->itc_bp.bp_at_end)
	    return DVC_LESS;
	}
      if (!itc->itc_bp.bp_is_pos_valid)
	{
	  if (itc->itc_bp.bp_new_on_row)
	    {
	      itc->itc_bp.bp_at_end = 1; /* this will call next case below */
	    }
	  else
	    {
	      pl_set_at_bit ((placeholder_t *) itc, itc->itc_row_data + off, bm_len,
		  bm_start, itc->itc_bp.bp_value, itc->itc_desc_order);
	  if (itc->itc_bp.bp_at_end)
	    return DVC_LESS; /* no more bits above / below the value, get the next row */
	}
	}
      if (itc->itc_bp.bp_at_end)
	{
	  if (!itc->itc_desc_order)
	    {
	      itc->itc_bp.bp_ce_offset = 0;
	      pl_ce_set  ((placeholder_t*) itc, bm, CE_LENGTH (bm), bm_start, BITNO_MIN, 1);
	    }
	  else
	    {
	      /* set at the end of the bitmap &*/
	      db_buf_t last_ce = bm_last_ce (bm, bm_len);
	      itc->itc_bp.bp_ce_offset = last_ce - bm;
	      pl_ce_set ((placeholder_t*)itc, last_ce, CE_LENGTH (last_ce), bm_start, BITNO_MAX, 0);
	    }
	  itc->itc_bp.bp_at_end = 0;
	}
    }

  for (;;)
    {
      if ((sp = itc->itc_bm_col_spec))
	{
	  /* this is the last key part spec, applied to the bitmapped value */
	  int res = itc_bp_col_check (itc, sp);
	  if (DVC_GREATER == res)
	    return res;
	  if (DVC_LESS == res)
	    goto next_bit;
	}

      sp = itc->itc_row_specs;
      if (sp)
	{
	  do
	    {
	      int op = sp->sp_min_op;
	      if (sp->sp_cl.cl_col_id == key->key_bit_cl->cl_col_id)
		{
		  /* the test on the bitmapped cl is special.  Use bp_valeu for that */
		  int res = itc_bp_col_check (itc, sp);
		  if (DVC_MATCH != res)
		    goto next_bit;
		}
	      else
		{
		  if (ITC_NULL_CK (itc, sp->sp_cl))
		    return DVC_LESS;
		  if (DVC_CMP_MASK & op)
		    {
		      int res = page_col_cmp (buf, itc->itc_row_data, &sp->sp_cl, itc->itc_search_params[sp->sp_min]);
		      if (0 == (op & res) || (DVC_NOORDER & res))
			{
			  itc->itc_bp.bp_at_end = 1;
			  return DVC_LESS;
			}
		    }
		  else if (op == CMP_LIKE)
		    {
		      if (DVC_MATCH != itc_like_compare (itc, buf, itc->itc_search_params[sp->sp_min], sp))
			{
			  itc->itc_bp.bp_at_end = 1;
			  return DVC_LESS;
			}

		      goto next_sp;
		    }
		  if (sp->sp_max_op != CMP_NONE)
		    {
		      int res = page_col_cmp (buf, itc->itc_row_data, &sp->sp_cl, itc->itc_search_params[sp->sp_max]);
		      if ( (0 == (sp->sp_max_op & res)) || (res & DVC_NOORDER))
			{
			  itc->itc_bp.bp_at_end = 1;
			  return DVC_LESS;
			}
		    }
		}
	    next_sp:
	      sp = sp->sp_next;
	    } while (sp);
	}

      ks = itc->itc_ks;
      if (ks)
	{
	  if (ks->ks_out_slots)
	    {
	      int inx = 0;
	      out_map_t * om = itc->itc_ks->ks_out_map;
	      DO_SET (state_slot_t *, ssl, &ks->ks_out_slots)
		{
		  if (om[inx].om_is_null)
		    {
		      if (OM_BM_COL == om[inx].om_is_null)
			{
			  /* we set the bitmapped col.  Note both iri ids are 64 bit boxes.  An int is 32 bit */
			  if (DV_IRI_ID == key->key_bit_cl->cl_sqt.sqt_dtp || DV_IRI_ID_8 == key->key_bit_cl->cl_sqt.sqt_dtp)
			    qst_set_bin_string (itc->itc_out_state, ssl, (db_buf_t) &itc->itc_bp.bp_value, sizeof (iri_id_t), DV_IRI_ID);
			  else
			    qst_set_long (itc->itc_out_state, ssl, itc->itc_bp.bp_value);
			}
		      else if (OM_NULL == om[inx].om_is_null)
			qst_set_bin_string (itc->itc_out_state, ssl, (db_buf_t) "", 0, DV_DB_NULL);
		      else
			qst_set (itc->itc_out_state, ssl, itc_box_row (itc, buf));
		    }
		  else
		    {
		      /* for leading key part of bitmap inx, set them only when first time on row.  If non last ks in cluster, next ones can switch the ssls around, so then set always.  */
		      if (itc->itc_bp.bp_new_on_row
			  || (!ks->ks_is_last && CL_RUN_CLUSTER == cl_run_local_only))
			itc_qst_set_column (itc, buf, &om[inx].om_cl, itc->itc_out_state, ssl);
		    }
		  inx++;
		}
	      END_DO_SET();
	      /*itc->itc_bp.bp_new_on_row = 0;*/
	    }
	  if (ks->ks_local_test
	      && !code_vec_run_no_catch (ks->ks_local_test, itc))
	    goto next_bit;
	  if (ks->ks_local_code)
	    code_vec_run_no_catch (ks->ks_local_code, itc);
	  if (ks->ks_setp)
	    {
	      KEY_TOUCH (ks->ks_key);
	      if (setp_node_run (ks->ks_setp, itc->itc_out_state, itc->itc_out_state, 0))
		{
		  if (ks->ks_is_last)
		    goto next_bit;
		  return DVC_MATCH;
		}
	      else
		goto next_bit;
	    }
	}
      itc->itc_bp.bp_new_on_row = 0;
      KEY_TOUCH (itc->itc_insert_key);
      if (!ks || !ks->ks_is_last)
	return DVC_MATCH;
    next_bit:
      pl_next_bit ((placeholder_t*) itc, bm, bm_len, bm_start, itc->itc_desc_order);
      if (itc->itc_bp.bp_at_end)
	{
	  itc->itc_bp.bp_new_on_row = 1;
	  return DVC_LESS;
	}
      ITC_MARK_ROW (itc);
    }
}


int
itc_bm_vec_row_check (it_cursor_t * itc, buffer_desc_t * buf)
{
  key_source_t *ks;
  /* For bm inx row.  The key is the right key because no alters in non pk inx */
  search_spec_t *sp;
  db_buf_t bm;
  int off;
  short bm_len;
  bitno_t bm_start;
  dbe_key_t * key = itc->itc_insert_key;
  caddr_t * inst = itc->itc_out_state;
 reset_after_del:
  BIT_COL (bm_start, buf, itc->itc_row_data, key);
  KEY_PRESENT_VAR_COL (itc->itc_insert_key, itc->itc_row_data, (*key->key_bm_cl), off, bm_len);
  bm = itc->itc_row_data + off;
  if (itc->itc_bp.bp_just_landed)
    {
      itc_bm_land (itc, buf);
    }
  if (0 == bm_len)
    {
      itc->itc_bp.bp_at_end = 1;
      itc->itc_bp.bp_ce_type = CE_SINGLETON_ROW;
      itc->itc_bp.bp_value = bm_start;
      itc->itc_bp.bp_just_landed = 0;
      itc->itc_bp.bp_is_pos_valid = 1;
    }
  else
    {
      if (itc->itc_bp.bp_just_landed)
	{
	  /* row found, find the first bit based on search criteria */
	  int rc = itc_bm_land_seek (itc, bm, bm_len, bm_start, buf);
	  itc->itc_bp.bp_just_landed = 0;
	  if (DVC_GREATER == rc)
	    return DVC_GREATER;
	  if (itc->itc_bp.bp_at_end)
	    return DVC_LESS;
	}
      if (!itc->itc_bp.bp_is_pos_valid)
	{
	  if (itc->itc_bp.bp_new_on_row)
	    {
	      itc->itc_bp.bp_at_end = 1; /* this will call next case below */
	    }
	  else
	    {
	      pl_set_at_bit ((placeholder_t *) itc, itc->itc_row_data + off, bm_len,
		  bm_start, itc->itc_bp.bp_value, itc->itc_desc_order);
	  if (itc->itc_bp.bp_at_end)
	    return DVC_LESS; /* no more bits above / below the value, get the next row */
	}
	}
      if (itc->itc_bp.bp_at_end)
	{
	  if (!itc->itc_desc_order)
	    {
	      itc->itc_bp.bp_ce_offset = 0;
	      pl_ce_set  ((placeholder_t*) itc, bm, CE_LENGTH (bm), bm_start, BITNO_MIN, 1);
	    }
	  else
	    {
	      /* set at the end of the bitmap &*/
	      db_buf_t last_ce = bm_last_ce (bm, bm_len);
	      itc->itc_bp.bp_ce_offset = last_ce - bm;
	      pl_ce_set ((placeholder_t*)itc, last_ce, CE_LENGTH (last_ce), bm_start, BITNO_MAX, 0);
	    }
	  itc->itc_bp.bp_at_end = 0;
	}
    }

  for (;;)
    {
      if ((sp = itc->itc_bm_col_spec))
	{
	  /* this is the last key part spec, applied to the bitmapped value */
	  int res = itc_bp_col_check (itc, sp);
	  if (DVC_GREATER == res)
	    return res;
	  if (DVC_LESS == res)
	    goto next_bit;
	}

      sp = itc->itc_row_specs;
      if (sp)
	{
	  do
	    {
	      int op = sp->sp_min_op;
	      if (sp->sp_cl.cl_col_id == key->key_bit_cl->cl_col_id)
		{
		  /* the test on the bitmapped cl is special.  Use bp_valeu for that */
		  int res = itc_bp_col_check (itc, sp);
		  if (DVC_MATCH != res)
		    goto next_bit;
		}
	      else
		{
		  if (ITC_NULL_CK (itc, sp->sp_cl))
		    return DVC_LESS;
		  if (DVC_CMP_MASK & op)
		    {
		      int res = page_col_cmp (buf, itc->itc_row_data, &sp->sp_cl, itc->itc_search_params[sp->sp_min]);
		      if (0 == (op & res) || (DVC_NOORDER & res))
			{
			  itc->itc_bp.bp_at_end = 1;
			  return DVC_LESS;
			}
		    }
		  else if (op == CMP_LIKE)
		    {
		      if (DVC_MATCH != itc_like_compare (itc, buf, itc->itc_search_params[sp->sp_min], sp))
			{
			  itc->itc_bp.bp_at_end = 1;
			  return DVC_LESS;
			}
		      goto next_sp;
		    }
		  else if (CMP_HASH_RANGE == op)
		    {
		      if (DVC_MATCH != itc_hash_compare (itc, buf, sp))
			{
			  itc->itc_bp.bp_at_end = 1;
			  return DVC_LESS;
			}
		      goto next_sp;
		    }
		  if (sp->sp_max_op != CMP_NONE)
		    {
		      int res = page_col_cmp (buf, itc->itc_row_data, &sp->sp_cl, itc->itc_search_params[sp->sp_max]);
		      if ( (0 == (sp->sp_max_op & res)) || (res & DVC_NOORDER))
			{
			  itc->itc_bp.bp_at_end = 1;
			  return DVC_LESS;
			}
		    }
		}
	    next_sp:
	      sp = sp->sp_next;
	    } while (sp);
	}

      ks = itc->itc_ks;
      if (ks)
	{
	  table_source_t * ts = ks->ks_ts;
	  if (ks->ks_v_out_map)
	    {
	      int inx = 0;
	      v_out_map_t * om = itc->itc_ks->ks_v_out_map;
	      int n_out = box_length (om) / sizeof (v_out_map_t);
	      for (inx = 0; inx < n_out; inx++)
		om[inx].om_ref (itc, buf, &om[inx].om_cl, itc->itc_out_state, om[inx].om_ssl);
	    }
	  itc->itc_n_results++;
	  qn_result ((data_source_t*)itc->itc_ks->ks_ts, inst, itc->itc_param_order[itc->itc_set]);
	  if (ks->ks_local_test)
	    {
	      QNCAST (query_instance_t, qi, inst);
	      qi->qi_set_mask = NULL;
	      qi->qi_set = itc->itc_n_results - 1;
	      if (!code_vec_run_no_catch (ks->ks_local_test, itc))
		{
		  QST_INT (inst, ts->src_gen.src_out_fill)--;
		  itc->itc_n_results--;
		  itc_pop_last_out (itc, inst, ks->ks_v_out_map, buf);
		  goto next_bit;
		}
	    }
	}
      itc->itc_bp.bp_new_on_row = 0;
      KEY_TOUCH (itc->itc_insert_key);
      if (1 == ks->ks_ts->ts_max_rows)
	return DVC_GREATER;
      if (itc->itc_n_results == itc->itc_batch_size)
	return DVC_MATCH;
    next_bit:
      if (itc->itc_bm_row_deleted)
	{
	  itc->itc_bm_row_deleted = 0;
	  return DVC_LESS;
	}
      if (!itc->itc_bp.bp_is_pos_valid)
	goto reset_after_del;
      pl_next_bit ((placeholder_t*) itc, bm, bm_len, bm_start, itc->itc_desc_order);
      if (itc->itc_bp.bp_at_end)
	{
	  itc->itc_bp.bp_new_on_row = 1;
	  return DVC_LESS;
	}
      ITC_MARK_ROW (itc);
    }
}


void
itc_next_bit (it_cursor_t * itc, buffer_desc_t *buf)
{
  key_ver_t kv;
  int off, len;
  bitno_t bm_start;
  db_buf_t row = buf->bd_buffer + buf->bd_content_map->pm_entries[itc->itc_map_pos];
  dbe_key_t *key = itc->itc_insert_key;
  kv = IE_KEY_VERSION (row);
  if (!kv || KV_LEFT_DUMMY == kv)
    {
      return; /* it can be that the itc has been moved as a result of deletes to the dummy or to a leaf pointer. If so, proceed as if no bitmap */
    }
  KEY_PRESENT_VAR_COL (key, row, (*key->key_bm_cl), off, len);
  /* where this is called, at start of search in itc_next, itc_row_data is not up to date. */
  itc->itc_row_data = row;
  BIT_COL (bm_start, buf, row, key);
  if (!itc->itc_bp.bp_is_pos_valid)
    pl_set_at_bit ((placeholder_t *) itc, itc->itc_row_data + off, len, bm_start, itc->itc_bp.bp_value, itc->itc_desc_order);
  pl_next_bit ((placeholder_t*)itc, row + off, len, bm_start, itc->itc_desc_order);
}


int
itc_bm_land_lock (it_cursor_t * itc, buffer_desc_t ** buf_ret)
{
  /* the idea is that the itc can land on a bm row that is locked amd while waiting the row can split.  If so, the itc has to restart the search cause it can't know which side it wants unless it is already landed
   * the itc_to_reset is set by itc_keep_together when inserting the right hand half of the split. */
  if (itc->itc_is_col)
    return RWG_NO_WAIT;
  itc->itc_to_reset = RWG_NO_WAIT;
  if (itc->itc_isolation < min_iso_that_waits && PL_EXCLUSIVE != itc->itc_lock_mode)
    return RWG_NO_WAIT;
  if (ITC_IS_LTRX (itc))
    itc_landed_lock_check (itc, buf_ret);
  return itc->itc_to_reset;
}



