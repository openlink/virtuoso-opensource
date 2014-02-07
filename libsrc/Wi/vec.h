/*
 *  vec.h
 *
 *  $Id$
 *
 *  Vectored execution
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


typedef void (*col_ref_t) (it_cursor_t * itc, buffer_desc_t * buf, dbe_col_loc_t * cl, caddr_t * qst, state_slot_t * target);


typedef struct v_out_map_s
{
  col_ref_t om_ref;
  state_slot_t *om_ssl;		/* the vector */
  state_slot_t *om_row_ssl;	/* the single value for local test/code */
  dbe_col_loc_t om_cl;
  char om_is_null;
  unsigned char om_ce_op;
} v_out_map_t;





#define DCT_FROM_POOL 1
#define DCT_REF 16		/* values are refs to another dc, lengths are copied from the source dc */
#define DCT_BOXES 32		/* the values are dv boxes.  If DCT_REF is not set, then the boxes are owned by this */
#define DCT_NUM_INLINE 64	/* if this dct occurs as search paramm, the param in itc_search_params is a box of the right type (int or iri id) */




typedef int (*dc_cmp_t) (data_col_t * dc, int r1, int r2, int r_prefetch);

struct data_col_s
{
  sql_type_t dc_sqt;
  char dc_any_null;
  char dc_type;
  dtp_t dc_org_dtp;
  int dc_n_values;		/* count of values */
  int dc_n_places;		/* max no of values for which there is space */
  int dc_buf_len;		/* total bytes in var len dc buffer */
  int dc_buf_fill;		/* bytes used from dc_buffer */
  int dc_org_places;		/* allocd element count  of dc_org_values */
  int dc_min_places;		/* when converting between dtps w different elt sz, resulting dc must have at least this many places.  0 means same as dc_n_places */
  db_buf_t dc_values;
  db_buf_t dc_nulls;
  db_buf_t dc_buffer;
  dk_set_t dc_buffers;		/* if extensible var len, this is the data and the pointers are in dc_values */
  dc_cmp_t dc_sort_cmp;		/* func for comparing values inside this column for sorting */
  mem_pool_t *dc_mp;
  db_buf_t dc_org_values;	/* initial values array if values array is assigned by reference to another dc */
  db_buf_t dc_org_nulls;	/* when getting first null for a num inline dc, use this if this is set and large enough */
};

#define dc_dtp dc_sqt.sqt_dtp

typedef struct ts_advice_s
{
  char adv_type;
  char adv_unique;		/* never more than one result per input */
  state_slot_t **adv_results;	/* slots assigned based if not a filter */
  dbe_column_t *adv_col;
  int adv_nth;			/* if many values per input, which one was it at when syspended */
  caddr_t adv_data;
} ts_advice_t;

#define ITC_P_VEC(itc, ip) \
  *((data_col_t**)&itc->itc_search_params[MAX_SEARCH_PARAMS - ip - 1])

#define ITC_VEC_MORE(itc) \
  (itc->itc_set < itc->itc_n_sets && itc->itc_n_results < itc->itc_batch_size)

typedef int (*dc_cast_t) (caddr_t * inst, data_col_t * target, data_col_t * source, int nth);

/* single value cast functions */
typedef int (*dc_val_cast_t) (data_col_t * target_dc, data_col_t * source_dc, int row, caddr_t * err_ret);

int vc_intnn_int (data_col_t * target, data_col_t * source, int row, caddr_t * err_ret);
int vc_anynn_iri (data_col_t * target, data_col_t * source, int row, caddr_t * err_ret);
int vc_irinn_any (data_col_t * target, data_col_t * source, int row, caddr_t * err_ret);
int vc_anynn_any (data_col_t * target, data_col_t * source, int row, caddr_t * err_ret);
int vc_anynn_generic (data_col_t * target, data_col_t * source, int row, caddr_t * err_ret);
int vc_anynn (data_col_t * target, data_col_t * source, int row, caddr_t * err_ret);
int vc_generic (data_col_t * target, data_col_t * source, int row, caddr_t * err_ret);
int vc_box_copy (data_col_t * target, data_col_t * source, int row, caddr_t * err_ret);
int vc_date_date (data_col_t * target, data_col_t * source, int row, caddr_t * err_ret);




void dc_get_buffer (data_col_t * dc, int bytes);
void dc_reset (data_col_t * dc);
void dc_append_bytes (data_col_t * dc, db_buf_t bytes, int len, db_buf_t pref, int pref_len);
void dc_append_chars (data_col_t * dc, char *field, int field_lem);
void dc_append (data_col_t * target, data_col_t * source, int inx);
void dc_append_box (data_col_t * dc, caddr_t box);
void dc_append_null (data_col_t * dc);
void dc_append_float (data_col_t * dc, float n);
int dc_is_nulll (data_col_t * dc, int set);
/* use as value in inlined num dcs to indicate that null check is to be made. 32 bit and ff at both ends  */
#define DC_MAY_BE_NULL 0xffabcdff
void dc_set_null (data_col_t * dc, int set);
void dc_append_int64 (data_col_t * dc, int64 n);

caddr_t dc_box (data_col_t * dc, int inx);

#define DC_SET_NULL(dc, inx)				\
  {  dc->dc_any_null = 1; \
    dc->dc_nulls[(inx) >> 3] |= (1 << ((inx) & 7)); }

#define DC_CLR_NULL(dc, inx)				\
  {if (dc->dc_any_null) dc->dc_nulls[(inx) >> 3] &= ~(1 << ((inx) & 7));}

#define DC_IS_NULL(dc, inx)				\
  (dc->dc_any_null && dc->dc_nulls[(inx) >> 3] & (1 << ((inx) & 7)))



#define DC_ANY_IS_NULL(dc, inx)				\
  ((dc->dc_nulls) ? (dc->dc_nulls[(inx) >> 3] & (1 << ((inx) & 7))) \
   : DCT_BOXES & dc->dc_type ? DV_DB_NULL == DV_TYPE_OF (((caddr_t*)dc->dc_values)[inx]) \
   : DV_DB_NULL == ((db_buf_t*)dc->dc_values)[inx][0])


extern int dc_str_buf_unit;
int64 dc_any_value (data_col_t * dc, int inx);
int64  dc_any_value_n (data_col_t * dc, int inx, char * nf);
int64 dc_any_value_prefetch (data_col_t * dc, int inx, int inx2);
int64  dc_any_value_n_prefetch (data_col_t * dc, int inx, int inx2, char * nf);
#define dc_int(dc, inx)  ((int64*)(dc)->dc_values)[inx]
caddr_t dc_mp_box_for_rd (mem_pool_t * mp, data_col_t * dc, int inx);
caddr_t sslr_qst_get (caddr_t * inst, state_slot_ref_t * sslr, int row_no);

int dc_cmp (data_col_t * dc, int64 v1, int64 v2);
void ks_vec_params (key_source_t * ks, it_cursor_t * itc, caddr_t * inst);
void itc_param_sort (key_source_t * ks, it_cursor_t * itc, int del_with_nulls);
col_ref_t col_ref_func (dbe_key_t * key, dbe_column_t * col, state_slot_t * ssl);

int itc_vec_next (it_cursor_t * it, buffer_desc_t ** buf_ret);
int itc_vec_row_check (it_cursor_t * itc, buffer_desc_t * buf);
void itc_vec_box (it_cursor_t * itc, dtp_t dtp, int nth, data_col_t * dc);
extern int32 dc_batch_sz;
extern int32 dc_max_batch_sz;
extern int qp_thread_min_usec;
int itc_param_cmp (int r1, int r2, void *cd);
void itc_set_param_row (it_cursor_t * itc, int nth);
void itc_set_row_spec_param_row (it_cursor_t * itc, int nth);
data_col_t *mp_data_col (mem_pool_t * mp, state_slot_t * ssl, int n_sets);
dtp_t sqt_dc_dtp (sql_type_t * sqt);

/* wen looping over search pars, need to know type of col.  Look it up in the sp.  One sp can cover 2 params and some can be key spec and some row spec.  So check this */
#define NEXT_SP_COL \
{ \
  if (sp2nd || sp->sp_min_op == CMP_NONE || sp->sp_max_op == CMP_NONE) \
    {\
      sp = sp->sp_next; \
      sp2nd = 0;\
    }\
  else \
    sp2nd = 1;\
  if (!sp)\
    {sp = itc->itc_row_specs; is_row_sp = 1; }	\
}

caddr_t itc_temp_any_box (it_cursor_t * itc, int inx, db_buf_t dv);
void dc_set_long (data_col_t * dc, int set, boxint lv);
void dc_set_float (data_col_t * dc, int set, float df);
void dc_set_double (data_col_t * dc, int set, double df);

#define DC_CHECK_LEN(dc, l)					\
  {if (l >= dc->dc_n_places || !dc->dc_values) dc_extend_2 (dc, l);}

void dc_extend_2 (data_col_t * dc, int l);
void dc_pop_last (data_col_t * dc);
int64 qst_vec_get_int64 (caddr_t * inst, state_slot_t * ssl, int row_no);
void qst_set_all (caddr_t * inst, state_slot_t * ssl, caddr_t val);
int sslr_set_no (caddr_t * inst, state_slot_t * ssl, int row_no);
void sslr_n_ref (caddr_t * inst, state_slot_ref_t * sslr, int *sets, int n_sets);
void sslr_n_consec_ref (caddr_t * inst, state_slot_ref_t * sslr, int *sets, int set, int n_sets);
int sslr_nn_ref (caddr_t * inst, state_slot_ref_t * sslr, int *sets, int set, int n_sets);
int dc_nn_sets (data_col_t * dc, int *sets, int first_set, int n_sets);

void dc_set_all_null (data_col_t * dc, int n_sets, db_buf_t set_mask);
extern char vec_box_dtps[256];
void dc_copy (data_col_t * target, data_col_t * source);
int dc_value_len (data_col_t * dc);
void dc_reserve_bytes (data_col_t * dc, int len);



void dc_itc_delete (it_cursor_t * itc, buffer_desc_t * buf, dbe_col_loc_t * cl,
		    caddr_t * inst, state_slot_t * ssl);
void dc_itc_bm_delete (it_cursor_t * itc, buffer_desc_t * buf, dbe_col_loc_t * cl,
		    caddr_t * inst, state_slot_t * ssl);
void dc_itc_placeholder (it_cursor_t * itc, buffer_desc_t * buf, dbe_col_loc_t * cl,
			 caddr_t * inst, state_slot_t * ssl);
void dc_itc_append_row (it_cursor_t * itc, buffer_desc_t * buf, dbe_col_loc_t * cl,
		    caddr_t * inst, state_slot_t * ssl);

int dc_elt_size (data_col_t * dc);
void dc_assign (caddr_t * inst, state_slot_t * ssl_to, int row_to, state_slot_t * ssl_from, int row_FROM);
db_buf_t dc_alloc (data_col_t * dc, int bytes);
void dc_reset_alloc (data_col_t * dc);
int qi_sets_identical (caddr_t * inst, state_slot_t * ssl);

#define DC_FILL_TO(dc, dtp, to) \
{ int __inx; \
  for (__inx = dc->dc_n_values; __inx < to; __inx++) \
    ((dtp*)dc->dc_values)[__inx] = 0; \
}

dc_val_cast_t vc_to_any (dtp_t dtp);
void sslr_dc_copy (caddr_t * inst, state_slot_ref_t * sslr, data_col_t * target_dc, data_col_t * source_dc, int n_sets, int dc_elt_len, int copy_anies);
void dc_heterogenous (data_col_t * dc);
void dc_convert_empty (data_col_t * dc, dtp_t dtp);
void dc_set_flags (data_col_t * dc, sql_type_t * sqt, dtp_t dcdtp);
int dc_any_cmp (data_col_t * dc, int r1, int r2, int r_prefetch);
int dtp_is_chash_inlined (dtp_t dtp);
void vec_ssl_assign (caddr_t * inst, state_slot_t * to, state_slot_t * from);
void vec_qst_set_temp_box (caddr_t * qst, state_slot_t * ssl, caddr_t data);

#define DC_HAS_NULL_BITS(dc) \
  ((DCT_NUM_INLINE & (dc)->dc_type) || DV_DATETIME == dtp_canonical[(dc)->dc_dtp])

void dc_ensure_null_bits (data_col_t * dc);
db_buf_t itcp (it_cursor_t * itc, int ip, int set);
caddr_t box_mt_copy_tree (caddr_t box);
int dc_is_null (data_col_t * dc, int set);
caddr_t box_deserialize_reusing (db_buf_t string, caddr_t box);

#define DC_ELT_CPY(target, target_row, source, source_row, l) \
  {if (8 == l) {((int64*)target->dc_values)[target_row] = ((int64*)source->dc_values)[source_row]; \
      if (DCT_BOXES & target->dc_type) ((caddr_t*)target->dc_values)[target_row] = box_copy_tree (((caddr_t*)target->dc_values)[target_row]); } \
    else if (4 == l) ((float*)target->dc_values)[target_row] = ((float*)source->dc_values)[source_row]; \
  else memcpy (target->dc_values + (l) * (target_row), source->dc_values + (source_row) * (l), l);}

#define DC_ELT_MT_CPY(target, target_row, source, source_row, l) \
  {if (8 == l) {((int64*)target->dc_values)[target_row] = ((int64*)source->dc_values)[source_row]; \
      if (DCT_BOXES & target->dc_type) ((caddr_t*)target->dc_values)[target_row] = box_mt_copy_tree (((caddr_t*)target->dc_values)[target_row]); } \
    else if (4 == l) ((float*)target->dc_values)[target_row] = ((float*)source->dc_values)[source_row]; \
  else memcpy (target->dc_values + (l) * (target_row), source->dc_values + (source_row) * (l), l);}



#define NEXT_SET_INL_NULL(dc, set, nth_par)		\
  if (dc->dc_any_null) { \
    box_tag_aux (itc->itc_search_params[nth_par]) = DC_IS_NULL (dc, set) ? DV_DB_NULL : dc->dc_dtp; }

#define NEXT_SET_INL_NULL_ALWAYS(dc, set, nth_par)		\
  if (!dc->dc_sqt.sqt_non_null) { \
    box_tag_aux (itc->itc_search_params[nth_par]) = DC_IS_NULL (dc, set) ? DV_DB_NULL : dc->dc_dtp; }

extern dk_hash_t * cl_dc_func_id;
extern dk_hash_t * cl_id_dc_func;
void  cl_dcf_id (col_ref_t f);

void dc_append_dv_rdf_box (data_col_t * dc, caddr_t box);
caddr_t dc_mp_insert_copy_any (mem_pool_t * mp, data_col_t * dc, int inx, dbe_column_t * col);
void qst_set_with_ref (caddr_t * inst, state_slot_t * ssl, caddr_t val);
extern size_t c_max_large_vec;


