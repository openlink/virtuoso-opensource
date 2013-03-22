/*d6
 *  col.h
 *
 *  $Id$
 *
 *  Column Compression
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

#ifndef __COL_H
#define __COL_H
#define CE_DENSE 0
#define CE_RL 1
#define CE_GAP 2
#define CE_VEC 3
#define CE_BITS   4
#define CE_PREFIX 5
#define CE_DICT 6
#define CE_INTS 7
#define CE_RL_DELTA 8
#define CE_DICT_RL  9
#define CE_INT_DELTA  10
#define CE_DICT_DELTA 11
#define CE_IS_IRI 16
#define CE_IS_64 32
#define CE_IS_STRING 64
#define CE_IS_SHORT 128 /* if both n values and byte length of CE under 256 */

#define CET_CHARS CE_IS_STRING /* All data in the ce are dv_strings */
#define CET_NULL (CE_IS_STRING | 16) /* a run of nulls */
#define CET_ANY (CE_IS_STRING | 32) /* all data are dv serializations */
#define CET_INT 0
#define CET_IRI CE_IS_IRI


#define CE_MAX_CES 1000
#define CE_VEC_MAX_VALUES 2267
#define CS_MAX_VALUES 2267
#define COL_MAX_BYTES ((PAGE_DATA_SZ - 20) / 2) /* max bytes in non-blob col value before compression on column wise dependent part col */

#define CE_TYPE_MASK 0xf
#define CE_DTP_MASK 0x70
#define CE_INTLIKE(flags) (!(flags & CE_IS_STRING))


#define CE_GAP_1 (CE_GAP | 0xf0)
#define CE_SHORT_GAP (CE_GAP | CE_IS_SHORT)

#define CE_GAP_LENGTH(ce, f) \
  (CE_GAP_1 == f ? 1 : CE_SHORT_GAP == f ? (ce)[1] + 2 : CE_GAP == f ? SHORT_REF_CA ((ce) + 1) + 3 : 0)

#define CE_GAP_MAX_BYTES 3

#define CE_INT_DELTA_MAX 0x7ff00000  /* a bit under max int32, some low bits are not used for delta */

typedef struct dist_hash_elt_s
{
  int64 dhe_data;
  struct dist_hash_elt_s *dhe_next;
} dist_hash_elt_t;

#define DHE_EMPTY ((dist_hash_elt_t*)-1)

typedef struct dist_hash_s
{
  dist_hash_elt_t *dh_array;
  int dh_n_buckets;
  int dh_count;
  int dh_fill;
  int dh_max;
  int dh_max_fill;
} dist_hash_t;


typedef struct comp_state_s
{
  char 	cs_head;
  dtp_t	cs_exclude;
  char	cs_all_int;
  char	cs_all_string;
  char		cs_is_asc;
  char		cs_no_dict;
  char		cs_any_64; /* all numbers in 32 bits */
  char		cs_heterogenous;
  dtp_t 	cs_dtp;
  char		cs_for_test;
  int 		cs_n_values;
  int		cs_non_comp_len;
  int		cs_unq_non_comp_len;
  int		cs_unq_delta_non_comp_len;
  mem_pool_t *	cs_mp;
  caddr_t *	cs_values;
  int64 *	cs_numbers;
  dist_hash_t cs_dh;
  id_hash_t *	cs_any_delta_distinct;
  dtp_t **	cs_distinct; /* sorted array of distinct any strings */
  dk_set_t	cs_ready_ces;
  dk_set_t	cs_org_values;
  dk_set_t	cs_prev_ready_ces;
  dk_hash_t *	cs_dict;
  dtp_t *	cs_dict_output;
  int	cs_dict_fill;
  dtp_t *	cs_dict_result;
  dtp_t *	cs_asc_output;
  int		cs_asc_fill;
  int		cs_asc_cutoff; /* if asc representation longer than this, stop doing it, dict is sure to be better */
  jmp_buf_splice *	cs_asc_reset;
  dtp_t *	cs_asc_result;
  } compress_state_t;

#define CS_INT_ONLY 2		/*cs_all_int set to this when the col dtp is iri or int */

/* cs exclude, selective disable of options for testing */
#define CS_NO_BITS 1
#define CS_NO_RLD 2
#define CS_NO_DELTA 4
#define CS_NO_RL 8
#define CS_NO_DENSE 16
#define CS_NO_DICT 32
#define CS_NO_ANY_INT_VEC 64
#define CS_NO_VEC 128

#define CS_ASC_UNQ 1
#define CS_ASC 2

#define CS_MAX_BYTES (10 * CS_MAX_VALUES + 100)	/* worst int compression in any vec, 8 b for int, 1 for tag and 1 for offset */


#define CE_MAX_RL_VALUES 256
#define CE_MAX_DICT_VALUES 256




#define CLEAR_LOW_BYTE 0xffffffffffffff00



#define CPO_FETCH 0

typedef struct ce_op_desc_s
{
  int 	ced_op;
} ce_op_desc_t;

typedef struct col_pos_s col_pos_t;

typedef int (*ce_value_cb_t) (col_pos_t * cpo, int row, dtp_t flags, db_buf_t val, int len, int64 offset, int rl);
typedef int (*ce_op_t) (col_pos_t * cpo, db_buf_t ce, int n_values, int n_bytes);

struct col_pos_s
{
  char		cpo_rc;
  char		cpo_min_op;
  char		cpo_max_op;
caddr_t		cpo_cmp_min;
caddr_t		cpo_cmp_max;
  ce_op_t *	cpo_ce_op;
  ce_value_cb_t	cpo_value_cb;
  search_spec_t *	cpo_min_spec;
  data_col_t *	cpo_dc;
  dbe_col_loc_t *	cpo_cl;
  caddr_t *		cpo_inst;
  state_slot_t *	cpo_ssl;
  buffer_desc_t *	cpo_buf;
  db_buf_t		cpo_string;
  db_buf_t 		cpo_ce;
  page_map_t *		cpo_pm;
  short			cpo_pm_pos;
  int			cpo_bytes;
  int			cpo_ce_row_no;
  int			cpo_to;
  int 			cpo_skip;
  row_no_t		cpo_next_pre;
  row_no_t		cpo_clk_inx;
  row_range_t *	cpo_range;
  it_cursor_t * 	cpo_itc;
  struct chash_s *	cpo_chash;
  uint32		cpo_hash_min;
  uint32		cpo_hash_max;
  dtp_t		cpo_chash_dtp;
};


#define VEC_VALUES_PER_LEN 2

int cs_append_any (compress_state_t * cs, dtp_t * out, int *fill_ret, int nth, int clear_last);
int cs_int_type (compress_state_t * cs, int from, int to, int *best);
void cs_append_int (dtp_t * out, int * fill_ret, int64 n, dtp_t dtp);

#define CE_VEC_LENGTHS(n_values) (((n_values) - 1) / 2)
#define CE_VEC_LENGTH_BYTES(n_values) (((n_values) - 1) & 0xffffe)
#define CE_VEC_POS(ce_first, n_values, inx, pos, mod) \
{ \
  if (inx < 2) \
    { \
      pos = CE_VEC_LENGTH_BYTES (n_values); \
      mod = inx & 1; \
    } \
  else \
    { \
      int __off = ((inx) - 2) & 0xffffe; \
      pos = SHORT_REF_CA (ce_first + __off); \
      mod = inx & 1;			     \
    }					     \
}


#define DV_CE_TLEN(len, dtp, ptr) \
  len = db_ce_const_length [dtp]; \
  if ((int)len < 0) len = (ptr) [1] + 2;	\
  else if (len == 0) { \
    long __l, __hl; \
    db_buf_length (ptr, &__hl, &__l); \
    len = (int) (__hl + __l); \
  }


#define CE_ANY_NTH(ce, n_values, inx, start_ret, len_ret) \
{ \
  int __mod, __pos, __ctr; \
  CE_VEC_POS (ce, n_values, (inx), __pos, __mod);	\
  start_ret = ce + __pos; \
  DV_CE_TLEN (len_ret, start_ret[0], start_ret);\
  for (__ctr = 0; __ctr < __mod; __ctr++) \
    { \
      start_ret += len_ret; \
      DV_CE_TLEN (len_ret, start_ret[0], start_ret); \
    } \
}




#define CE_ANY_VEC_N_VALUES(ce) \
  (CE_IS_SHORT & *ce ? ce[2] : SHORT_REF (ce + 3))

#define CE_STR_LEN(ce, prefix, inx, tail) \
    (ce[0] < 128 ? (prefix = 0, ce[0]) \
  : ce[0] < 144 ? (prefix = 0, 256 * (ce[0] - 127) + ce[1]) \
  : ce[0] < 184 ? (prefix = ce[0] - 144, pref_inx = ce[1], tail = ce[2], tail + 3) \
    : ce[0] < 224 ? (prefix = ce[0] - 184, pref_inx = SHORT_REF_CA (ce + 1), tail = ce[3], tail + 4) \
      : ce[0] == 254 ? (prefix = SHORT_REF_CA (ce + 1), inx = SHORT_REF_CA (ce + 3), tail = SHORT_REF_NA (ce + 5), 7 + tail) \
      : ce[0] == 255 ? (prefix = -1, 1) \
	: (GPF_T1 ("bad str len in ce_vec"), 1))



#define CE_1_STR_LEN(ce) \
  (ce[0] < 128 ? ce[0] : (ce[0] - 127) * 256 + ce[2])

#define CE_SET_STR_LEN(ce, len) \
  if (len < 128) *(ce++) == len;			\
  else { ce[0] = 127 + (len >> 8); ce[1] = len; }


#define DV_ANY_FIRST DV_NULL /* first dv that can in an any string */

#define MAX_1_BYTE_CE_INX (DV_ANY_FIRST - (CE_VEC_MAX_VALUES / 256) - 1)
void ce_vec_nth (db_buf_t ce, dtp_t flags, int n_values, int inx, db_buf_t * val_ret, int * len_ret, int len_bias);

#define IS_INTLIKE_DTP(dtp) (IS_IRI_DTP (dtp) || IS_INT_DTP (dtp))

#define VEC_ALL_STRINGS 1
#define VEC_ANY 0

void cs_write_gap (db_buf_t out, int bytes);
void cs_append_header (dtp_t * out, int * fill_ret, int flags, int n_values, int n_bytes);
dtp_t * cs_write_header (dtp_t * out, int flags, int n_values, int n_bytes);
caddr_t cs_org_values (compress_state_t * cs);

typedef struct ce_new_pos_s
{
  struct ce_new_pos_s *	cep_next;
  db_buf_t	cep_org_ce;
  dp_addr_t 	cep_old_dp;
  dp_addr_t 	cep_new_dp;
  short 	cep_old_nth;
  short		cep_new_nth;
} ce_new_pos_t;


typedef struct ceic_result_page_s
{
  page_map_t *	cer_pm;
  db_buf_t	cer_buffer;
  buffer_desc_t *	cer_buf;
  int		cer_spacing;
  int		cer_n_ces;
  int		cer_bytes_free;
  char		cer_after_last_insert;
  struct ceic_result_page_s *	cer_next;
  dk_set_t	cer_ces;
} ceic_result_page_t;


typedef struct ce_ins_ctx_s
{
  it_cursor_t *	ceic_itc;
  mem_pool_t *	ceic_mp;
  dk_set_t	ceic_delta_ce_op; /* insert vs replace the ce at this pos w/ the corresponding delta ce */
  dk_set_t	ceic_delta_ce;
  row_no_t	ceic_end_map_pos; /* if ins/del, thsi is itc map pos, if multiseg compress limited to inside a  leaf page this is the map pos of the last row that is recompressed */
  int		ceic_n_for_ce;
  int		ceic_n_updates;
  int		ceic_nth_col;
  dbe_column_t *	ceic_col;
  ceic_result_page_t *	ceic_cur_out;
  ceic_result_page_t *	ceic_res;
  dk_set_t	ceic_all_ces;
  buffer_desc_t *	ceic_org_buf;
  struct row_delta_s **	ceic_rds;
  db_buf_t	ceic_limit_ce;
  ce_new_pos_t *	ceic_reloc;
  ce_new_pos_t *	ceic_prev_reloc;  /* in 2nd split, ce may be relocd one and then there is 2nd split for which another reloc is done on the original ref.  Remember the reloc rec used for that since it will point too a different place for the post split col page */
  db_buf_t 		ceic_before_rel;
  dp_addr_t	ceic_near;
  int			ceic_first_ce;
  buffer_desc_t *	ceic_out_buf;
  dk_set_t	ceic_dps;
  dk_set_t	ceic_batch;
  struct col_data_ref_s *	ceic_cr;
  compress_state_t *		ceic_cs;
  struct ce_ins_ctx_s *	ceic_top_ceic;
  dk_set_t			ceic_ac_splits;
  dk_set_t		ceic_finalized_rls;
  struct row_delta_s **	ceic_rb_rds;
  row_no_t *	ceic_deletes;
  int 		ceic_batch_bytes;
  dp_addr_t	ceic_last_dp;
  int		ceic_last_nth;
  int 		ceic_after_split;
  int		ceic_n_ces;
  int		ceic_ac_rows;
  int		ceic_nth_rb_rd;
  char		ceic_is_finalize;
  char ceic_is_cpt_restore;
  char		ceic_is_rb;
  char		ceic_finalize_needs_update;
  char		ceic_is_ac;
  char ceic_dtp_checked;
} ce_ins_ctx_t;


#define CE_INSERT 0x10000000
#define CE_REPLACE 0x20000000
#define CE_DELETE 0x40000000


typedef struct col_page_s
{
  buffer_desc_t *	cp_buf;
  page_map_t *	cp_map;
  db_buf_t	cp_string;
  ce_ins_ctx_t *	cp_ceic;
}   col_page_t;

#define CEIC_AC_MULTIPAGE 1
#define CEIC_AC_SINGLE_PAGE 2


#define CPP_FIRST_CE 1
#define CPP_N_CES 3
#define CPP_DP 5


typedef struct col_data_ref_s
{
  char	cr_is_valid; /* bufs and strings refer to this seg? */
  char	cr_is_prefetched;
  char		cr_first_ce_page; /* if 1st ce gets longer, it may move one page ahead.  This can be after del/upd of 1st value which needs a upd of the leaf row.  To find the post upd 1st ce, use this */
  short		cr_n_pages;
  short		cr_first_ce;
  short		cr_limit_ce; /* inx of 1st ce on last page not in this seg */
  int		cr_n_ces; /* for autocompact can exceed range of short */
  uint32	cr_n_access; /* how many segs so far where this col was accessed.  Use to determine read ahead */
  int		cr_pages_sz;

  col_page_t *	cr_pages;
  row_no_t *	cr_ce_row;
  short		cr_nth_ce;
  short 	cr_string;
  short	cr_ce;
  row_no_t 		cr_row;
  col_page_t 	cr_pre_pages[4];
  db_buf_t	cr_top_string; /* in insert w/ more pages or inlined col, the new top string */
} col_data_ref_t;

typedef struct ac_col_stat_s
{
  int 	acs_nth_leaf; /* in multipage ac, this is for this pos in the pr */
  int	acs_row; /* row no of seg on the leaf page */
  int	acs_n_rows;
  int	acs_n_pages;
  int	acs_own_pages;
  int	acs_absent_pages; /* how many are not in buffers */
  int	acs_n_dirty;
  int	acs_ce_bytes;
  int	acs_free_bytes;
  int	acs_ce_overhead;
} ac_col_stat_t;


void  cs_init (compress_state_t * cs, mem_pool_t * mp, int f, int sz);
void ce_head_info (db_buf_t ce, int * r_bytes, int * r_values, dtp_t * r_ce_type, dtp_t * r_flags, int * r_hl);
int  ce_1_len (dtp_t * ce, dtp_t flags);

#define DO_CE(ce, n_bytes, n_values, ce_type, flags, first_ce, total) \
{ \
  dtp_t * ce = first_ce; \
  int __n_bytes, n_bytes, n_values, __hl;	\
  dtp_t flags, ce_type;\
  while (ce < first_ce + total) \
    { \
      ce_head_info (ce, &n_bytes, &n_values, &ce_type, &flags, &__hl); \
      __n_bytes = n_bytes;

#define END_DO_CE(ce, n_bytes)			\
      ce += __n_bytes + __hl;			\
    }}

#define CE_2_LENGTH(ce, ce_first, n_bytes, n_values) \
  { if (!(CE_IS_SHORT & *ce)) {						\
ce_first = ce + 5; n_bytes = SHORT_REF_CA (ce + 1); n_values = SHORT_REF_CA (ce + 3); } \
    else { ce_first = ce + 3; n_bytes = ce[1]; n_values = ce[2]; }}

#define CE_INTVEC_LENGTH(ce, ce_first, n_bytes, n_values, dtp) \
  { if (CE_IS_SHORT & *ce) { ce_first = ce + 2;n_values = ce[1]; n_bytes = n_values * sizeof (dtp);}  \
    else { ce_first = ce + 3; n_values = SHORT_REF_CA (ce + 1); n_bytes = n_values * sizeof (dtp);}}

caddr_t mp_box_to_any (mem_pool_t * mp, caddr_t box);
void cs_compress (compress_state_t * cs, caddr_t any);
void cs_compress_int (compress_state_t * cs, int64 * ints, int n_ints);
void cs_best (compress_state_t * cs, dtp_t ** best, int * len);
void cs_reset (compress_state_t * cs);
int cs_decode (col_pos_t * cpo, int from, int to);

#define COL_NO_ROW 0xffff

int ce_filter (col_pos_t * cpo, int row, dtp_t flags, db_buf_t val, int len, int64 offset, int rl);
int ce_result (col_pos_t * cpo, int row, dtp_t flags, db_buf_t val, int len, int64 offset, int rl);
int64 any_num_f (dtp_t * any);
#define any_num(f) any_num_f((dtp_t*)f)
int  any_add (db_buf_t any, int len, int64 delta, db_buf_t res, dtp_t flags);
#define CE_AT_END 100000000
int  ce_n_values (db_buf_t ce);
caddr_t mp_box_n_chars (mem_pool_t * mp, caddr_t b, int l);
int  cr_n_rows (col_data_ref_t * cr);
int  cr_n_bytes (col_data_ref_t * cr);
void  itc_range (it_cursor_t * itc, row_no_t lower, row_no_t upper);
int ce_search (it_cursor_t * itc, db_buf_t ce, row_no_t row_of_ce, int rc, int nth_key);

/* return / rc of ce_search */
#define CE_DONE 1
#define CE_CONTINUES 2
#define CE_FIND_FIRST 3
#define CE_FIND_LAST 4
#define CE_SET_END 5
#define CE_NEXT_SET 6

int itc_next_set_cmp (it_cursor_t * itc, int nth_key);

#define SET_NOT_EQ 0
#define SET_ALL_EQ 1
#define SET_LEADING_EQ 2
#define SET_EQ_RESET 3

int ce_cmp_1 (col_pos_t * cpo, int row, dtp_t flags, db_buf_t val, int len, int64 offset, int rl);
int64 itc_any_param (it_cursor_t * itc, int nth_key, dtp_t * dtp_ret);
caddr_t itc_ce_box_param (it_cursor_t * itc, int nth_key);
int64 itc_ce_search_param (it_cursor_t * itc, int nth_key, dtp_t * dtp_ret);
db_buf_t ce_insert_1 (ce_ins_ctx_t * ceic, ce_ins_ctx_t ** col_ceic, db_buf_t ce, int space_after, int * split_at, int ice);
db_buf_t ce_extend (ce_ins_ctx_t * ceic, ce_ins_ctx_t ** col_ceic_ret, db_buf_t ce, db_buf_t * ce_first_ret, int new_bytes,
    int new_values, int *space_after_ret);
int64 ceic_int_value (ce_ins_ctx_t * ceic, int nth, dtp_t * dtp_ret);
dtp_t any_canonical_dtp (db_buf_t dv);
void  ceic_merge_insert (ce_ins_ctx_t * ceic, buffer_desc_t * buf, int ice, db_buf_t org_ce, int start, int split_at);
int ce_total_bytes (db_buf_t ce);
ce_ins_ctx_t * ceic_col_ceic (ce_ins_ctx_t * ceic);

#define CE_FIRST \
{ \
  ce_first_val = ce_first; \
  if (CE_INTLIKE (flags))\
    {\
      if (CE_IS_64 & flags)\
	{\
	  first = INT64_REF_CA (ce_first);\
	  ce_first += 8;\
	}\
      else \
	{\
	  if (CE_IS_IRI & flags)\
	    first = (iri_id_t)(uint32)LONG_REF_CA (ce_first);	\
	  else							\
	    first = LONG_REF_CA (ce_first);			\
	  ce_first += 4;					\
	}\
    }\
  else \
    {\
      if (CET_ANY == (flags & CE_DTP_MASK))\
	{\
	  DB_BUF_TLEN (first_len, ce_first[0], ce_first);\
	  ce_first += first_len;\
	}\
      else \
	{\
	  first_len = *(ce_first++);\
	  if (first_len > 127)\
	    first_len = (first_len - 128) * 256 + *(ce_first++);	\
	  ce_first += first_len;					\
	}\
      first = 0;\
    }\
}

#define CET_CHARS_LEN(chars, hl, l) \
{ \
  l = *(chars);					\
  if (l > 127){ \
    hl = 2; \
    l = (l - 128) * 256 + (chars)[1];			 \
  } else  \
    hl = 1; \
}


boxint dv_int (db_buf_t dv, dtp_t * dtp_ret);
db_buf_t itc_dv_param (it_cursor_t * itc, int nth_key, db_buf_t ctmp);
#define MAX_FIXED_DV_BYTES 50 /* max bytes in dv representation of fixed len box, e.g. date, decimal */
int ce_dtp_compare (db_buf_t ce, dtp_t dtp);
int ce_typed_vec_dtp_compare (db_buf_t ce, dtp_t dtp);
void bing ();
dtp_t ce_dtp_f (db_buf_t ce);
int  asc_cmp (dtp_t * dv1, dtp_t * dv2);
int  asc_cmp_delta (dtp_t * dv1, dtp_t * dv2, uint32 * num_ret, int is_int_delta);
int asc_str_cmp (db_buf_t dv1, db_buf_t dv2, int len1, int len2, uint32 * num_ret, char is_int_delta);

#define ASC_SHORTER 100
#define ASC_LONGER 101
#define ASC_NUMBERS 102

#define CE_ALL_VARIANTS(ce) \
  ce : case ce | CE_IS_IRI: case ce | CET_ANY: case ce | CET_CHARS:  case ce | CE_IS_64: case ce | CE_IS_IRI | CE_IS_64

int64 dv_if_needed (int64 any_param, dtp_t dtp, db_buf_t tmp);
dtp_t any_ce_dtp (db_buf_t dv);

/* below note that for a dict the short forms of int must be generated because if mixing long and short forms of equal numbers dict compression is not possible */
#define CEIC_FLOAT_INT(col_dtp, str) \
  if (DV_DB_NULL == ((db_buf_t)str)[0])		\
    ; \
  else if (DV_DOUBLE_FLOAT == col_dtp)	       \
    dv_from_int ((db_buf_t)str, INT64_REF_NA (str + 1));	\
  else if (DV_SINGLE_FLOAT == col_dtp)	\
    dv_from_int ((db_buf_t)str, LONG_REF_NA (str + 1));

int ce_like_filter (col_pos_t * cpo, int row, dtp_t flags, db_buf_t val, int len, int64 offset, int rl);
int itc_col_count (it_cursor_t * itc, buffer_desc_t * buf, int * row_match_ctr);
caddr_t * itc_box_col_seg (it_cursor_t * itc, buffer_desc_t * buf, dbe_col_loc_t * cl);
caddr_t * cr_mp_array (col_data_ref_t * cr, mem_pool_t * mp, int from, int to, int print);
void cs_reset_check (compress_state_t * cs);
db_buf_t  ce_skip_gap (db_buf_t ce);
int ce_string_n_values (db_buf_t ce, int len);
void dc_append_rb (data_col_t * dc, caddr_t dat);


#ifdef WORDS_BIGENDIAN
#define SHORT_SET_CA(p, w) SHORT_SET_NA(p, w)
#define LONG_SET_CA(p, w) LONG_SET_NA(p, w)
#define INT64_SET_CA(p, w) INT64_SET_NA(p, w)

#define SHORT_REF_CA(p) SHORT_REF_NA(p)
#define LONG_REF_CA(p) LONG_REF_NA(p)
#define INT64_REF_CA(p) INT64_REF_NA(p)

#else

#define SHORT_SET_CA(p, w)  (*((short*)(p)) = w)
#define LONG_SET_CA(p, w)  (*((int32*)(p)) = w)
#define INT64_SET_CA(p, w)  (*((int64*)(p)) = w)


#define SHORT_REF_CA(p)  (*(unsigned short*)(p))
#define LONG_REF_CA(p)  (*((int32*)(p)))
#define INT64_REF_CA(p)  (*((int64*)(p)))

#endif

extern ce_op_t * ce_op[512];
void ce_op_register (dtp_t ce_type, int op, int is_sets, ce_op_t f);
#define CE_OP_CODE(min, max) (min + (max << 8))
void colin_init ();
db_buf_t  ce_any_dict_array (db_buf_t ce, dtp_t flags);
int  col_find_op (int op);
#define CE_DECODE 255 /* col op for getting values.  must be different from any CMP_* */
#define CE_ALL_LTGT 254		/* op for range with >= > < <= */
void cs_clear (compress_state_t * cs);
void dv_from_int (db_buf_t ctmp, int64 i);
void dv_from_iri (db_buf_t ctmp, iri_id_t i);
int64 itc_ce_value_offset (it_cursor_t * itc, db_buf_t ce, db_buf_t * body_ret, int * dtp_cmp);

int  ce_dict_key (db_buf_t ce, db_buf_t dict, int64 value, dtp_t dtp, db_buf_t * dict_ret, int * sz_ret);
int  ce_dict_any_ins_key (db_buf_t ce, db_buf_t dict, int64 value, dtp_t dtp, db_buf_t * dict_ret, int * sz_ret, int * is_ncast_eq);

int ce_dict_generic_range_filter (col_pos_t * cpo, db_buf_t ce_first, int n_values, int n_bytes);
int ce_dict_generic_sets_filter (col_pos_t * cpo, db_buf_t ce_first, int n_values, int n_bytes);


int itc_first_col_lock (it_cursor_t * itc, col_row_lock_t ** clk_ret, buffer_desc_t * buf);
#define CLK_NO_WAIT 0
#define CLK_WAIT_LANDED 1
#define CLK_WAIT_RND 2
void rl_col_release (row_lock_t * rl, lock_trx_t * lt);
void itc_col_wait (it_cursor_t * itc, buffer_desc_t ** buf_ret, col_row_lock_t * clk, int wait);
void ceic_split_locks (ce_ins_ctx_t * ceic, int * splits, int n_splits, row_delta_t ** rds);
col_row_lock_t * itc_clk_at (it_cursor_t * itc, row_no_t pos, row_no_t * point, row_no_t * next_ret);
void ceic_del_ins_rbe (ce_ins_ctx_t * ceic, int nth_range, db_buf_t dv);
void ceic_del_ins_rbe_int (ce_ins_ctx_t * ceic, int nth_range, int64 i, dtp_t dtp);
void clk_free (col_row_lock_t * clk);
int itc_rows_in_seg (it_cursor_t * itc, buffer_desc_t * buf);
void mp_conc1 (mem_pool_t * mp, dk_set_t * r, void* v);
extern int dbf_compress_mask;
void ceic_cs_flags (ce_ins_ctx_t * ceic, compress_state_t * cs, dtp_t dcdtp);
void cs_distinct_ces (compress_state_t * cs);
row_delta_t * ceic_1st_changed (ce_ins_ctx_t * ceic);
void  ceic_no_split (ce_ins_ctx_t * ceic, buffer_desc_t * buf, int * action);
#define CEIC_ON_PAGE 1
#define CEIC_DONE 2
#define CEIC_REENTER 3


void pl_col_finalize_page (page_lock_t * pl, it_cursor_t * itc, int is_rb);
#define RB_CPT 2
void itc_asc_ck (it_cursor_t * itc);
int itc_is_own_del_clk (it_cursor_t * itc, row_no_t row, col_row_lock_t ** clk_ret, row_no_t * point, row_no_t * next);
void itc_col_ins_locks (it_cursor_t * itc, buffer_desc_t * buf);
col_row_lock_t * itc_new_clk (it_cursor_t * itc, int row);
void itc_make_rl (it_cursor_t * itc);
int  ceic_pl_more (ce_ins_ctx_t * ceic, page_lock_t * pl, it_cursor_t * itc, int is_rb);
int itc_col_serializable (it_cursor_t * itc, buffer_desc_t ** buf_ret);
void itc_col_lock (it_cursor_t * itc, buffer_desc_t * buf, int n_rows, int may_delete);
row_lock_t * rl_col_allocate ();
db_buf_t  ceic_ins_any_value (ce_ins_ctx_t * ceic, int nth);
db_buf_t itc_string_param (it_cursor_t * itc, int nth_key, int * len_ret, dtp_t * dtp_ret);
int ce_bm_nth (db_buf_t bits, int val, int * counted_ret, int * n_ret);

#define add8(v)  \
  v = v + (v >> 32); \
v = v + (v >> 16); \
  v = v + (v >> 8);				\
  v &= 0x7f;

int ceic_split (ce_ins_ctx_t * ceic, buffer_desc_t * buf);
void ce_recompress (ce_ins_ctx_t * ceic, compress_state_t * cs, data_col_t * dc);
void rl_add_clk (row_lock_t * rl, col_row_lock_t * clk, int inx, int is_ins);
db_buf_t  cr_limit_ce (col_data_ref_t * cr, short * inx_ret);
db_buf_t ceic_updated_col (ce_ins_ctx_t * ceic, buffer_desc_t * buf, int row, dbe_col_loc_t * cl);

#define ITC_DELTA(itc, buf) \
  if (BUF_NEEDS_DELTA (buf)) \
    { \
      ITC_IN_KNOWN_MAP (itc, buf->bd_page); \
      itc_delta_this_buffer (itc, buf, DELTA_MAY_LEAVE); \
      ITC_LEAVE_MAP_NC (itc); \
    } \

#define COL_PAGE_MAX_ROWS (PAGE_DATA_SZ / 15) /* min col row is 9 for the col str and 6 for overhead */

int64 itc_anify_param (it_cursor_t * itc, caddr_t box);
void cs_free_allocd_parts (compress_state_t * cs);
void cpt_col_uncommitted (dbe_storage_t * dbs);
void cpt_col_restore_uncommitted ();
int col_ac_set_dirty (caddr_t * qst, state_slot_t ** args, it_cursor_t * itc, buffer_desc_t * buf, int first, int n_last);
void itc_ensure_col_refs (it_cursor_t * itc);
void itc_col_page_free (it_cursor_t * itc, buffer_desc_t * buf, int col);
void itc_fetch_col_dps (it_cursor_t * itc, buffer_desc_t * buf, dbe_col_loc_t * cl, dk_hash_t * dps);
void itc_col_insert_rows (it_cursor_t * itc, buffer_desc_t * buf, int is_update);
/* is_update */
#define COL_UPDATE 1
#define COL_CPT_RESTORE 2
#define COL_CPT_RB 3
void pl_cpt_col_page (page_lock_t * pl, it_cursor_t * itc, buffer_desc_t * buf, int is_restore);
#define COL_UPD_NO_CHANGE ((caddr_t)-1)
int blob_col_inlined (caddr_t * val_ret, dtp_t col_dtp, mem_pool_t * mp);
#define COL_MAX_STR_LEN ((PAGE_DATA_SZ / 2) - 14)	/* 2 single value ces with max len string per page */

void itc_ce_check (it_cursor_t * itc, buffer_desc_t * buf, int leave);
void buf_ce_check (buffer_desc_t * buf);
void ce_del_array (ce_ins_ctx_t * ceic, db_buf_t array, int n_elt, int elt_sz);
int ce_del_int_delta (ce_ins_ctx_t * ceic, db_buf_t ce, int *len_ret);
int ce_del_dict (ce_ins_ctx_t * ceic, db_buf_t ce, int *len_ret);
void bit_delete (db_buf_t base, int target, int source, int bits);
db_buf_t ce_dict_array (db_buf_t ce);
int ce_head_len (db_buf_t ce);
buffer_desc_t *it_new_col_page (index_tree_t * it, dp_addr_t near_dp, it_cursor_t * has_hold, dbe_column_t * col);
void itc_delete_blob_array (it_cursor_t * itc, caddr_t * blobs, int fill);
int ce_space_after (buffer_desc_t * buf, db_buf_t ce);
caddr_t mp_box_any_dv (mem_pool_t * mp, db_buf_t dv);
void itc_col_ins_locks_nti (it_cursor_t * itc, buffer_desc_t * buf);
extern int ce_op_decode;
caddr_t *ce_box (db_buf_t ce, int extra);
void itc_extend_array (it_cursor_t * itc, int *sz, int elt_sz, void ***arr);

#define N4_REF_NA(p, l) \
  (l > 3 ? LONG_REF_NA ((p))  \
  : 3 == l ? ((((dtp_t*)(p))[1] << 16) + (((dtp_t*)(p))[2] << 8) + ((dtp_t*)(p))[3]) \
 : 2 == l ? SHORT_REF_NA ((p) + 2) : (uint32)((dtp_t*)(p))[3])

int strcmp8 (unsigned char *s1, unsigned char *s2, int l1, int l2);
int str_cmp_offset (db_buf_t dv1, db_buf_t dv2, int n1, int n2, int64 offset);
int ceic_all_dtp (ce_ins_ctx_t * ceic, dtp_t dtp);
void itc_clear_col_refs (it_cursor_t * itc);
int ce_dict_ins_any_key (db_buf_t ce, db_buf_t dict, int64 value, dtp_t dtp, db_buf_t * dict_ret, int *sz_ret, int *is_ncast_eq);
void key_col_check (dbe_key_t * key);
int cr_new_size (col_data_ref_t * cr, int *bytes_ret);
void itc_set_sp_stat (it_cursor_t * itc);

#if WORDS_BIGENDIAN

#define ce_first_int_low_byte (ce, ce_first) \
  ce_first[-1]
#else
#define ce_first_int_low_byte(ce, ce_first) \
  ce[ce[0] & CE_IS_SHORT ? 3 : 5]
#endif


#if WORDS_BIGENDIAN
#define ce_first_int_low_byte (ce, ce_first) \
  ce_first[-1]
#else
#define ce_first_int_low_byte(ce, ce_first) \
  ce[ce[0] & CE_IS_SHORT ? 3 : 5]
#endif
extern int dbf_ignore_uneven_col;
void ceic_upd_rd (ce_ins_ctx_t * ceic, int map_pos, int nth_col, db_buf_t str);

#endif
