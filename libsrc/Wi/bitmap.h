/*
 *  $Id$
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2015 OpenLink Software
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

typedef int64 bitno_t;
typedef short ce_bit_inx_t;

#define CE_SINGLE 1
#define CE_ARRAY 2
#define CE_BITMAP 3
#define CE_SINGLETON_ROW 4 /* no ce at all  */

typedef struct bm_pos_s
{
  bitno_t	bp_value;
  short		bp_ce_offset; /* the ce offset from the start of bitmap */
  short		bp_pos_in_ce; /* if array ce, index in the array of bit numbers */
  char		bp_ce_type;
  bitf_t        bp_is_pos_valid:1; /* true if bitmap col  was not touched since last time. Offsets inside bm string stay valid.  */
  bitf_t        bp_at_end:1; /* true if itc on a row whose bm has no matches. Next seek must get next row in search order */
  bitf_t        bp_below_start:1; /* itc found a ce with the right range but the search ended up below the first set bit */
  bitf_t        bp_new_on_row:1; /* mecy time in toc_row_check, set the out cols for leading key parts.  Need not set on every iteration */
  bitf_t        bp_just_landed:1;
  bitf_t	bp_transiting:1; /* if set, placeholder is neither here nor there. Busy wait with sleep to wait for final position */
} bitmap_pos_t;

#define CE_N_VALUES 8192
#define CE_MAX_LENGTH 1028 /* 4 byte header and bitmap for 8K bits */

#define CE_OFFSET(ce) \
  (( ((ce)[0] & 0x7f) << 24) | (ce)[1] << 16 | ((ce)[2] & 0xe0) << 8)

#define CE_ARRAY_MASK 0x00001800
#define CE_BITMAP_MASK 0x00001000

#define CE_BITMAP_TO_ARRAY 0x08  /* value to OR to bitmap mask to make it the array flag in byte 2 of a ce */
#define CE_IS_SINGLE(ce)  (*(ce) & 0x80)
#define CE_IS_ARRAY(ce) \
  (CE_ARRAY_MASK == (CE_ARRAY_MASK & LONG_REF_NA (ce)))

#define CE_LENGTH(ce) \
  (CE_IS_SINGLE (ce) ? 4 : (((ce)[3] | ((ce)[2] & 0x7) << 8)))

#define CE_SET_LENGTH(ce, len) \
  ((ce)[3] = (len) & 0xff, (ce)[2] = ((ce)[2] & 0xf8) | (((len) & 0x0700) >> 8))

#define CE_SINGLE_VALUE(ce) (LONG_REF_NA (ce) & 0x7fffffff)

#define CE_SET_OFFSET(ce, off) \
  {  (ce)[0] &= 0x80; (ce)[0] |= (off) >> 24;				\
  (ce)[1] = (off) >> 16; (ce)[2] &= 0x1f; (ce)[2] |= ((off) >> 8) & 0xe0; }


#define IS_64_DTP(dtp) (DV_IRI_ID_8 == (dtp) || DV_INT64 == (dtp))

#define CE_ROUND(n) \
  ((n) & 0xffffffffffffe000LL)

#define CL_SET_LEN(key, cl, row, new_len) \
{ \
  row_ver_t rv = IE_ROW_VERSION (row); \
  if (CL_FIRST_VAR == cl->cl_pos[rv]) \
    SHORT_SET (row + key->key_length_area[rv], key->key_row_var_start[rv] + new_len); \
  else \
    SHORT_SET (row + (- cl->cl_pos[rv]) + 2, new_len + (COL_VAR_LEN_MASK & SHORT_REF (row + (- cl->cl_pos[rv])))); \
}


#define BITS_IN_RANGE(b1, b2) \
  (b1 < b2 ? b2 - b1 < 0x10000000 : b1 - b2 < 0x10000000)

#define BITNO_MAX 0x7fffffffffffffffLL
#define BITNO_MIN  0x8000000000000000LL

#define SA_REF(sa, n) \
  SHORT_REF_NA (((db_buf_t)sa) +  ((n)*2))

#define SA_SET(sa, inx, v) \
  SHORT_SET_NA (((db_buf_t)sa) + ((inx)* 2), v)


#define BIT_COL(v, buf, row, key)		\
{\
  if (IS_64_DTP (key->key_bit_cl->cl_sqt.sqt_dtp))\
    { ROW_INT_COL (buf, row, IE_ROW_VERSION(row), (*key->key_bit_cl), INT64_REF, v); } \
  else  if (DV_IRI_ID == key->key_bit_cl->cl_sqt.sqt_dtp)\
    { ROW_INT_COL (buf, row, IE_ROW_VERSION(row), (*key->key_bit_cl), (int64)(unsigned int32)LONG_REF, v); } \
  else \
    ROW_INT_COL (buf, row, IE_ROW_VERSION(row), (*key->key_bit_cl), LONG_REF, v); \
}
#define ITC_BM_REENTER_CK(itc) \
  while (itc->itc_bp.bp_transiting) { \
    TC (tc_bm_cr_reentry_transit_wait); \
    virtuoso_sleep (0, 100); \
  }
void bm_ck (db_buf_t bm, int len);
