/*
 *  chash.c
 *
 *  $Id$
 *
 *  Vectored hash join and group by
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
#include "arith.h"
#include "mhash.h"
#include "sqlparext.h"
#include "date.h"


int chash_max_count = 20000000;
int chash_max_key_len = 2000;
int chash_max_partitions = 40000;
int chash_part_size = 7011;
int chash_part_max_fill = 2500;
int chash_look_levels = 10;
int64 chash_max_bytes = 100000000;	/* if total bytes in chash use would exceed, use partitioning */
int enable_chash_join = 1;
int64 chash_min_parallel_fill_rows = 40000;
dk_mutex_t chash_rc_mtx;
dk_mutex_t cha_alloc_mtx;
int64 chash_bytes;		/* bytes used in chash arrays */
int64 chash_space_avail = 1000000000;
resource_t *chash_array_rc;
int cha_stream_gb_flush_pct = 200;

#define CHASH_MAX_COLS 200



#define CHA_PARTITION(cha, h) (cha->cha_n_partitions ? &cha->cha_partitions[h % cha->cha_n_partitions] : cha)
#define CHA_POS_1(cha, hno) ((((uint64)hno) & 0xffffffff) % cha->cha_size)
#define CHA_POS_2(cha, hno) ((((uint64)hno) >> 32) % cha->cha_size)

/*#define CKE(ent) if (0 == memcmp (((char**)ent)[1] + 2, "Supplier#000002039", 18)) bing();*/
#define CKE(ent)

#define MHASH_STEP(h, k) MHASH_ID_STEP (h, k)

/* H_PART is extracts the part of the hash no that is used for hash join partitioning */
#define H_PART(h) (((uint64)h) >> 32)

void hash_source_chash_input_1i (hash_source_t * hs, caddr_t * inst, caddr_t * state);
void setp_chash_fill_1i (setp_node_t * setp, caddr_t * inst);
void hash_source_chash_input_1i_n (hash_source_t * hs, caddr_t * inst, caddr_t * state);
void setp_chash_fill_1i_n (setp_node_t * setp, caddr_t * inst);



#define GB_HAS_VALUE(ha, row, nth) \
  ((db_buf_t)row)[ ha->ha_ch_nn_flags + (nth / 8)] |= 1 << (nth & 7);

#define GB_IS_NULL(ha, row, nth) \
  (!(((db_buf_t)row)[ ha->ha_ch_nn_flags + (nth / 8)] & (1 << (nth & 7))))



int consec_sets[ARTM_VEC_LEN];
dtp_t chash_null_flag_dtps[256];

#define AGG_C(dt, op) (((int)dt << 3) + op)


#define GB_CLR_NULL \
	  if (0 && !not_null) \
	    { \
	      for (inx = 0; inx < n_sets; inx++) \
		GB_HAS_VALUE (ha, groups[sets[inx] + base_set], dep_inx); \
	    }


void
gb_aggregate (setp_node_t * setp, caddr_t * inst, chash_t * cha, int64 ** groups, int first_set, int last_set)
{
  hash_area_t *ha = setp->setp_ha;
  int dep_inx = ha->ha_n_keys;
  DO_SET (gb_op_t *, go, &setp->setp_gb_ops)
  {
    int tmp_sets[ARTM_VEC_LEN];
    int base_set = first_set, inx;
    int n_sets = last_set - first_set;
    state_slot_t *ssl = setp->setp_dependent_box[dep_inx - ha->ha_n_keys];
    dtp_t dtp = cha->cha_sqt[dep_inx].sqt_dtp;
    char not_null = ssl->ssl_sqt.sqt_non_null;
    int *sets;
    data_col_t *dc;
    if (SSL_REF == ssl->ssl_type)
      {
	dc = QST_BOX (data_col_t *, inst, ssl->ssl_index);
	n_sets = sslr_nn_ref (inst, (state_slot_ref_t *) ssl, tmp_sets, first_set, last_set - first_set);
	sets = tmp_sets;
	base_set = 0;
      }
    else if (SSL_VEC == ssl->ssl_type)
      {
	dc = QST_BOX (data_col_t *, inst, ssl->ssl_index);
	if (dc->dc_any_null)
	  {
	    n_sets = dc_nn_sets (dc, tmp_sets, first_set, last_set - first_set);
	    base_set = 0;
	    sets = tmp_sets;
	  }
	else
	  {
	    db_buf_t values = dc->dc_values;
	    sets = consec_sets;
	    n_sets = last_set - first_set;
	    switch (AGG_C (dtp, go->go_op))
	      {
	      case AGG_C (DV_LONG_INT, AMMSC_SUM):
		GB_CLR_NULL;
	      case AGG_C (DV_LONG_INT, AMMSC_COUNTSUM):
		for (inx = 0; 0 && inx <= n_sets - 4; inx += 4)
		  {
		    ((int64 **) groups)[inx][1 + dep_inx] += ((int64 *) values)[inx + base_set];
		    ((int64 **) groups)[inx + 1][1 + dep_inx] += ((int64 *) values)[inx + 1 + base_set];
		    ((int64 **) groups)[inx + 2][1 + dep_inx] += ((int64 *) values)[inx + 2 + base_set];
		    ((int64 **) groups)[inx + 3][1 + dep_inx] += ((int64 *) values)[inx + 3 + base_set];
		  }
		for (inx = inx; inx < n_sets; inx++)
		  ((int64 **) groups)[inx][1 + dep_inx] += ((int64 *) values)[inx + base_set];
		break;
	      case AGG_C (DV_SINGLE_FLOAT, AMMSC_SUM):
		GB_CLR_NULL;
	      case AGG_C (DV_SINGLE_FLOAT, AMMSC_COUNTSUM):
		for (inx = 0; inx < n_sets; inx++)
		  *(float *) &((double **) groups)[inx][1 + dep_inx] += ((float *) dc->dc_values)[inx + base_set];
		break;
	      case AGG_C (DV_DOUBLE_FLOAT, AMMSC_SUM):
		GB_CLR_NULL;
	      case AGG_C (DV_DOUBLE_FLOAT, AMMSC_COUNTSUM):
		for (inx = 0; 0 && inx <= n_sets - 4; inx += 4)
		  {
		    ((double **) groups)[inx][1 + dep_inx] += ((double *) values)[inx + base_set];
		    ((double **) groups)[inx + 1][1 + dep_inx] += ((double *) values)[inx + 1 + base_set];
		    ((double **) groups)[inx + 2][1 + dep_inx] += ((double *) values)[inx + 2 + base_set];
		    ((double **) groups)[inx + 3][1 + dep_inx] += ((double *) dc->dc_values)[inx + 3 + base_set];
		  }
		for (inx = inx; inx < n_sets; inx++)
		  ((double **) groups)[inx][1 + dep_inx] += ((double *) values)[inx + base_set];
		break;
	      }
	    dep_inx++;
	    continue;
	  }
      }
    else
      {
	/* constant corresponds to count * */
	for (inx = 0; inx < last_set - first_set; inx++)
	  ((int64 **) groups)[inx][1 + dep_inx]++;
	dep_inx++;
	continue;
      }
    switch (AGG_C (dtp, go->go_op))
      {
      case AGG_C (DV_LONG_INT, AMMSC_SUM):
	GB_CLR_NULL;
      case AGG_C (DV_LONG_INT, AMMSC_COUNTSUM):
	for (inx = 0; inx < n_sets; inx++)
	  ((int64 **) groups)[inx][1 + dep_inx] += ((int64 *) dc->dc_values)[sets[inx] + base_set];
	break;
      case AGG_C (DV_SINGLE_FLOAT, AMMSC_SUM):
	GB_CLR_NULL;
      case AGG_C (DV_SINGLE_FLOAT, AMMSC_COUNTSUM):
	for (inx = 0; inx < n_sets; inx++)
	  *(float *) &((double **) groups)[inx][1 + dep_inx] += ((float *) dc->dc_values)[sets[inx] + base_set];
	break;
      case AGG_C (DV_DOUBLE_FLOAT, AMMSC_SUM):
	GB_CLR_NULL;
      case AGG_C (DV_DOUBLE_FLOAT, AMMSC_COUNTSUM):
#if 0
	for (inx = 0; inx <= n_sets - 4; inx += 4)
	  {
	    ((double **) groups)[inx][1 + dep_inx] += ((double *) dc->dc_values)[sets[inx] + base_set];
	    ((double **) groups)[inx + 1][1 + dep_inx] += ((double *) dc->dc_values)[sets[inx + 1] + base_set];
	    ((double **) groups)[inx + 2][1 + dep_inx] += ((double *) dc->dc_values)[sets[inx + 2] + base_set];
	    ((double **) groups)[inx + 3][1 + dep_inx] += ((double *) dc->dc_values)[sets[inx + 3] + base_set];
	  }
#endif
	for (inx = 0; inx < n_sets; inx++)
	  ((double **) groups)[inx][1 + dep_inx] += ((double *) dc->dc_values)[sets[inx] + base_set];
	break;
      }
    dep_inx++;
  }
  END_DO_SET ();
}


void
chash_to_any (chash_t * ch, int col)
{
  /* convert the given key col to anies and rehash */
}


void
gb_arr_to_any (int64 * arr, int n, db_buf_t any_temp, int *any_temp_fill)
{
  GPF_T1 ("gb col cast to any not done");
}


void
chash_array (int64 * arr, int64 * hash_no, dtp_t chdtp, int first_set, int last_set, int elt_sz)
{
  int inx;
  if (DV_ANY == chdtp)
    {
      db_buf_t *any_arr = (db_buf_t *) arr;
      for (inx = 0; inx < last_set - first_set - 4; inx += 4)
	{
	  int l1, l2, l3, l4;
	  DB_BUF_TLEN (l1, any_arr[inx][0], any_arr[inx]);
	  DB_BUF_TLEN (l2, any_arr[inx + 1][0], any_arr[inx + 1]);
	  DB_BUF_TLEN (l3, any_arr[inx + 2][0], any_arr[inx + 2]);
	  DB_BUF_TLEN (l4, any_arr[inx + 3][0], any_arr[inx + 3]);
	  MHASH_VAR (hash_no[inx], any_arr[inx], l1);
	  MHASH_VAR (hash_no[inx + 1], any_arr[inx + 1], l2);
	  MHASH_VAR (hash_no[inx + 2], any_arr[inx + 2], l3);
	  MHASH_VAR (hash_no[inx + 3], any_arr[inx + 3], l4);
	}
      for (inx = inx; inx < last_set - first_set; inx++)
	{
	  int l1;
	  DB_BUF_TLEN (l1, any_arr[inx][0], any_arr[inx]);
	  MHASH_VAR (hash_no[inx], any_arr[inx], l1);
	}
      return;
    }
  else
    {
      switch (elt_sz)
	{
	case 4:
	  for (inx = 0; inx < last_set - first_set; inx++)
	    {
	      uint32 d = ((uint32 *) arr)[inx];
	      MHASH_STEP (hash_no[inx], (uint64) d);
	    }
	  break;
	case 8:
	  for (inx = 0; inx < last_set - first_set; inx++)
	    {
	      uint64 d = ((uint64 *) arr)[inx];
	      MHASH_STEP (hash_no[inx], (uint64) d);
	    }
	  break;
	case DT_LENGTH:
	  for (inx = 0; inx < last_set - first_set; inx++)
	    {
	      uint64 d = *(uint64 *) ((db_buf_t) arr + inx * DT_LENGTH);
	      MHASH_STEP (hash_no[inx], (uint64) d);
	    }
	  break;
	}
    }
}


int64 *
gb_values (chash_t * cha, int64 * hash_no, caddr_t * inst, state_slot_t * ssl, int nth, int first_set, int last_set,
    db_buf_t temp_space, db_buf_t any_temp, int *any_temp_fill)
{
  /* accumulate hash nos and optionally change col to anies */
  int64 *temp = NULL;
  int sets[ARTM_VEC_LEN];
  int64 *arr = NULL;
  data_col_t *dc = QST_BOX (data_col_t *, inst, ssl->ssl_index);
  int elt_sz = dc_elt_size (dc), inx;
  dtp_t chdtp = cha->cha_sqt[nth].sqt_dtp;
  if (SSL_VEC == ssl->ssl_type && dc->dc_dtp == chdtp && (DV_ANY == dc->dc_dtp || !dc->dc_any_null))
    arr = (int64 *) (dc->dc_values + first_set * elt_sz);
  else if (SSL_REF == ssl->ssl_type)
    {
      temp = (int64 *) & temp_space[nth * ARTM_VEC_LEN * DT_LENGTH];
      sslr_n_consec_ref (inst, (state_slot_ref_t *) ssl, sets, first_set, last_set - first_set);
      switch (elt_sz)
	{
	case 4:
	  for (inx = 0; inx < last_set - first_set; inx++)
	    ((int32 *) temp)[inx] = ((int32 *) dc->dc_values)[sets[inx]];
	  break;
	case 8:
	  for (inx = 0; inx < last_set - first_set; inx++)
	    ((int64 *) temp)[inx] = ((int64 *) dc->dc_values)[sets[inx]];
	  break;
	case DT_LENGTH:
	  for (inx = 0; inx < last_set - first_set; inx++)
	    memcpy_dt (((db_buf_t) temp) + DT_LENGTH * inx, dc->dc_values + sets[inx] * DT_LENGTH);
	  break;
	}
      arr = (int64 *) temp;
    }
  if (DV_ANY == chdtp && DV_ANY != dc->dc_dtp)
    {
      gb_arr_to_any (arr, last_set - first_set, any_temp, any_temp_fill);
    }
  chash_array (arr, hash_no, chdtp, first_set, last_set, elt_sz);
  return arr;
}


int64 *
cha_new_row (hash_area_t * ha, chash_t * cha, int is_next)
{
  chash_page_t *chp = cha->cha_current, *chp2;
  int off = chp->h.h.chp_fill;
  int len = is_next ? cha->cha_next_len : cha->cha_first_len;
  if (off + len < PAGE_DATA_SZ)
    {
      chp->h.h.chp_fill += len;
      cha->cha_count++;
      return (int64 *) & chp->chp_data[off];
    }
  if (chp->h.h.chp_next && 0 == chp->h.h.chp_next->h.h.chp_fill)
    {
      cha->cha_current = chp->h.h.chp_next;
      return cha_new_row (ha, cha, is_next);
    }
  if (cha->cha_is_parallel)
    mutex_enter (&cha_alloc_mtx);
  chp2 = (chash_page_t *) mp_alloc_box_ni (cha->cha_pool, PAGE_SZ, DV_BIN);
  if (cha->cha_is_parallel)
    mutex_leave (&cha_alloc_mtx);
  memset (chp2, 0, DP_DATA);
  chp2->h.h.chp_next = chp;
  cha->cha_current = chp2;
  return cha_new_row (ha, cha, is_next);
}


db_buf_t
cha_any (chash_t * cha, db_buf_t dv)
{
  chash_page_t *chp = cha->cha_current_data, *chp2;
  int off;
  int len;
  if (!chp)
    {
      if (cha->cha_is_parallel)
	mutex_enter (&cha_alloc_mtx);
      chp = cha->cha_current_data = (chash_page_t *) mp_alloc_box_ni (cha->cha_pool, PAGE_SZ, DV_BIN);
      if (cha->cha_is_parallel)
	mutex_leave (&cha_alloc_mtx);
      memset (chp, 0, DP_DATA);
    }
  off = chp->h.h.chp_fill;
  DB_BUF_TLEN (len, dv[0], dv);
  if (len > chash_max_key_len)
    {
      len = chash_max_key_len;
      cha->cha_error = 1;
    }
  if (off + len < PAGE_DATA_SZ)
    {
      chp->h.h.chp_fill += len;
      memcpy (&chp->chp_data[off], dv, len);
      return &chp->chp_data[off];
    }
  if (chp->h.h.chp_next && !chp->h.h.chp_next->h.h.chp_fill)
    {
      cha->cha_current_data = chp->h.h.chp_next;
      return cha_any (cha, dv);
    }
  if (cha->cha_is_parallel)
    mutex_enter (&cha_alloc_mtx);
  chp2 = (chash_page_t *) mp_alloc_box_ni (cha->cha_pool, PAGE_SZ, DV_BIN);
  if (cha->cha_is_parallel)
    mutex_leave (&cha_alloc_mtx);
  memset (chp2, 0, DP_DATA);
  chp2->h.h.chp_next = chp;
  cha->cha_current_data = chp2;
  return cha_any (cha, dv);
}


db_buf_t
cha_dt (chash_t * cha, db_buf_t dt)
{
  dtp_t hd[2];
  db_buf_t place;
  hd[0] = DV_SHORT_STRING_SERIAL;
  hd[1] = DT_LENGTH - 2;
  place = cha_any (cha, hd);
  memcpy_dt (place, dt);
  return place;
}


int64
cha_fixed (chash_t * cha, data_col_t * dc, int set, int *is_null)
{
  dtp_t tmp[DT_LENGTH + 1];
  if (dc->dc_nulls && dc->dc_any_null && DC_IS_NULL (dc, set))
    {
      *is_null = 1;
      return 0;
    }
  switch (dc->dc_dtp)
    {
    case DV_LONG_INT:
    case DV_IRI_ID:
    case DV_DOUBLE_FLOAT:
      return ((int64 *) dc->dc_values)[set];
    case DV_SINGLE_FLOAT:
      return (int64) ((int32 *) dc->dc_values)[set];
    case DV_DATETIME:
      {
	tmp[0] = DV_DATETIME;
	memcpy_dt (&tmp[1], dc->dc_values + set * DT_LENGTH);
	return (ptrlong) cha_any (cha, tmp) + 1;
      }
    default:
      if (DCT_BOXES & dc->dc_type)
	{
	  caddr_t cp = box_copy_tree (((caddr_t *) dc->dc_values)[set]);
	  mutex_enter (&cha_alloc_mtx);
	  mp_trash (cha->cha_pool, cp);
	  mutex_leave (&cha_alloc_mtx);
	  return (uptrlong) cp;
	}
      GPF_T1 ("bad dc dtp in hash join build");
    }
  return 0;
}


int64
setp_non_agg_dep (setp_node_t * setp, caddr_t * inst, int nth_col, int set)
{
  /* gb has after aggs non-agg non-key dependents.  Set when creating the group */
  state_slot_t *ssl = setp->setp_ha->ha_slots[nth_col];
  data_col_t *dc = QST_BOX (data_col_t *, inst, ssl->ssl_index);
  set = sslr_set_no (inst, ssl, set);
  switch (dc->dc_dtp)
    {
    case DV_ANY:
      return (int64) ((db_buf_t *) dc->dc_values)[set];
    case DV_LONG_INT:
    case DV_DOUBLE_FLOAT:
    case DV_IRI_ID:
    case DV_IRI_ID_8:
      return (int64) ((db_buf_t *) dc->dc_values)[set];
    case DV_SINGLE_FLOAT:
      return ((uint32 *) dc->dc_values)[set];
    case DV_DATETIME:
      return (int64) & dc->dc_values[set * DT_LENGTH];
    default:
      GPF_T1 ("unsupported dc dtp in non-agg dep of setp");
    }
  return 0;
}


int64 *
cha_new_gb (setp_node_t * setp, caddr_t * inst, db_buf_t ** key_vecs, chash_t * cha, uint64 hash_no, int row_no, int base)
{
  hash_area_t *ha = setp->setp_ha;
  int nth_col, n_cols;
  int64 *row = cha_new_row (ha, cha, 0);
  row[0] = hash_no;
  for (nth_col = 0; nth_col < ha->ha_n_keys; nth_col++)
    {
      if (DV_ANY == cha->cha_sqt[nth_col].sqt_dtp)
	{
	  db_buf_t dv = ((db_buf_t **) key_vecs)[nth_col][row_no];
	  row[nth_col + 1] = (ptrlong) cha_any (cha, dv);
	}
      else if (DV_DATETIME == cha->cha_sqt[nth_col].sqt_dtp)
	{
	  db_buf_t dt = &((db_buf_t *) key_vecs)[nth_col][row_no * DT_LENGTH];
	  GB_HAS_VALUE (ha, row, nth_col);
	  row[nth_col + 1] = (ptrlong) cha_dt (cha, dt);
	}
      else
	{
	  GB_HAS_VALUE (ha, row, nth_col);
	  row[nth_col + 1] = ((int64 **) key_vecs)[nth_col][row_no];
	}
    }
  DO_SET (gb_op_t *, go, &setp->setp_gb_ops)
  {
    if (AMMSC_MAX == go->go_op || AMMSC_MIN == go->go_op)
      {
      }
    else
      row[nth_col + 1] = 0;
    GB_HAS_VALUE (ha, row, nth_col);
    nth_col++;
  }
  END_DO_SET ();
  n_cols = ha->ha_n_keys + ha->ha_n_deps;
  for (nth_col = nth_col; nth_col < n_cols; nth_col++)
    {
      int64 val = setp_non_agg_dep (setp, inst, nth_col, row_no + base);
      if (DV_ANY == cha->cha_sqt[nth_col].sqt_dtp)
	{
	  row[nth_col + 1] = (ptrlong) cha_any (cha, val);
	}
      else if (DV_DATETIME == cha->cha_sqt[nth_col].sqt_dtp)
	{
	  db_buf_t dt = &((db_buf_t *) key_vecs)[nth_col][row_no * DT_LENGTH];
	  GB_HAS_VALUE (ha, row, nth_col);
	  row[nth_col + 1] = (ptrlong) cha_dt (cha, val);
	}
      else
	{
	  GB_HAS_VALUE (ha, row, nth_col);
	  row[nth_col + 1] = val;
	}
    }
  return row;
}

#define CHA_IS_NULL(cha, is_cont, row, inx)				\
  (((db_buf_t)row)[(int)cha->cha_null_flags - (is_cont ? cha->cha_n_keys * sizeof (int64) : 0) + ((inx) >> 3)] & (1 << ((inx) & 0x7)))

#define CHA_SET_NULL(cha, is_cont, row, inx)				\
  (((db_buf_t)row)[(int)cha->cha_null_flags - (is_cont ? cha->cha_n_keys * sizeof (int64) : 0) + ((inx) >> 3)] |= (1 << ((inx) & 0x7)))


int64 *
cha_new_hj_row (setp_node_t * setp, caddr_t * inst, db_buf_t ** key_vecs, chash_t * cha, uint64 hash_no, int row_no, int64 * prev)
{
  QNCAST (query_instance_t, qi, inst);
  hash_area_t *ha = setp->setp_ha;
  int nth_col;
  int64 *row = cha_new_row (ha, cha, prev != NULL);
  int fill = 0, nn;
  if ((nn = cha->cha_null_flags))
    {
      if (prev)
	nn -= cha->cha_first_len - cha->cha_next_len;
      memset ((db_buf_t) row + nn, 0, ALIGN_8 (ha->ha_n_deps) / 8);
    }
  if (!prev)
    {
      if (!cha->cha_is_1_int_key)
	row[fill++] = hash_no;
      for (nth_col = 0; nth_col < ha->ha_n_keys; nth_col++)
	{
	  if (DV_ANY == cha->cha_sqt[nth_col].sqt_dtp)
	    {
	      db_buf_t dv = ((db_buf_t **) key_vecs)[nth_col][row_no];
	      row[fill++] = (ptrlong) cha_any (cha, dv);
	    }
	  else if (DV_DATETIME == cha->cha_sqt[nth_col].sqt_dtp)
	    {
	      db_buf_t dt = &((db_buf_t *) key_vecs)[nth_col][row_no * DT_LENGTH];
	      row[fill++] = (ptrlong) cha_dt (cha, dt);
	    }
	  else
	    row[fill++] = ((int64 **) key_vecs)[nth_col][row_no];
	}
    }
  else
    nth_col = ha->ha_n_keys;
  for (nth_col = nth_col; nth_col < ha->ha_n_keys + ha->ha_n_deps; nth_col++)
    {
      state_slot_t *ssl = ha->ha_slots[nth_col];
      data_col_t *dc = QST_BOX (data_col_t *, inst, ssl->ssl_index);
      int set_no = qi->qi_set + row_no;
      if (SSL_REF == ssl->ssl_type)
	set_no = sslr_set_no (inst, ssl, set_no);
      if (DV_ANY == cha->cha_sqt[nth_col].sqt_dtp)
	{
	  row[fill++] = (ptrlong) cha_any (cha, ((db_buf_t *) dc->dc_values)[set_no]);
	}
      else
	{
	  int is_null = 0;
	  row[fill++] = cha_fixed (cha, dc, set_no, &is_null);
	  if (is_null)
	    CHA_SET_NULL (cha, prev != NULL, row, cha->cha_n_keys - nth_col);
	}
    }
  if (prev)
    {
      row[fill + (nn ? 1 : 0)] = prev[cha->cha_next_ptr];
      ((int64 **) prev)[cha->cha_next_ptr] = row;
    }
  else if (cha->cha_next_ptr)
    row[cha->cha_next_ptr] = 0;
  return row;
}


void cha_alloc_int (chash_t * cha, setp_node_t * setp, sql_type_t * new_sqt, chash_t * old_cha);


void
cha_col_copy (chash_t * new_cha, chash_t * cha, int64 ent, int inx, int64 * new_row)
{
  dtp_t tmp[MAX_FIXED_DV_BYTES];
  sql_type_t *new_sqt = &new_cha->cha_sqt[inx];
  sql_type_t *sqt = &cha->cha_sqt[inx];
  if (DV_ANY == new_sqt->sqt_dtp && DV_ANY != sqt->sqt_dtp)
    {
      if (DV_IRI_ID == cha->cha_sqt[0].sqt_dtp)
	dv_from_iri (tmp, ent);
      else
	dv_from_int (tmp, ent);
      new_row[inx + 1] = (uptrlong) cha_any (new_cha, tmp);
    }
  else
    new_row[inx + 1] = ent;
}

int cha_relocate (chash_t * cha, uint64 hash_no, int64 * ent);

void
cha_rehash_add (chash_t * new_cha, uint64 h, int64 ent)
{
  chash_t *cha_p = CHA_PARTITION (new_cha, h);
  int pos1 = CHA_POS_1 (cha_p, h);
  int pos2 = CHA_POS_2 (cha_p, h);
  int64 empty = cha_p->cha_is_1_int ? CHA_EMPTY : 0;
  if (empty == ((int64 *) cha_p->cha_array)[pos1])
    {
      ((int64 *) cha_p->cha_array)[pos1] = ent;
      return;
    }
  if (empty == ((int64 *) cha_p->cha_array)[pos2])
    {
      ((int64 *) cha_p->cha_array)[pos2] = ent;
      return;
    }
  if (!cha_relocate (cha_p, h, (int64 *) ent))
    mp_array_add (cha_p->cha_pool, (caddr_t **) & cha_p->cha_exceptions, &cha_p->cha_exception_fill, (caddr_t) ent);
}


int64 *
cha_copy_row (chash_t * cha_p, uint64 h, int64 * row)
{
  int64 *new_row = cha_new_row (cha_p->cha_ha, cha_p, 0);
  if (!cha_p->cha_is_1_int_key)
    {
      new_row[0] = h;
      memcpy (new_row + 1, row, cha_p->cha_first_len - sizeof (int64));
    }
  else
    memcpy (new_row, row, cha_p->cha_first_len);
  return new_row;
}


void
cha_rehash_insert (chash_t * new_cha, int64 * row)
{
  chash_t *cha_p;
  int64 ent;
  int inx;
  uint64 h = 1;
  if (new_cha->cha_is_1_int)
    {
      MHASH_STEP (h, row[1]);
    }
  else
    {
      for (inx = 0; inx < new_cha->cha_n_keys; inx++)
	{
	  if (DV_ANY == new_cha->cha_sqt[inx].sqt_dtp)
	    {
	      int len;
	      db_buf_t dv = (db_buf_t) row[inx];
	      DB_BUF_TLEN (len, dv[0], dv);
	      MHASH_VAR (h, dv, len);
	    }
	  if (DV_DATETIME == new_cha->cha_sqt[inx].sqt_dtp)
	    {
	      int64 d = ((int64 **) row)[inx][0];
	      MHASH_STEP (h, d);
	    }
	  else
	    {
	      int64 d = ((int64 *) row)[inx];
	      MHASH_STEP (h, d);
	    }
	}
    }
  cha_p = CHA_PARTITION (new_cha, h);
  ent = (int64) cha_copy_row (cha_p, h, row);
  cha_rehash_add (new_cha, h, ent);
}


void
cha_retype (chash_t * cha, setp_node_t * setp)
{
  int n_part, inx;
  int64 new_row[CHASH_MAX_COLS];
  int prev_sz = cha->cha_n_partitions ? cha->cha_partitions[0].cha_size * cha->cha_n_partitions : cha->cha_size;
  int new_sz = 2 * prev_sz;
  chash_t *new_cha = (chash_t *) mp_alloc_box_ni (cha->cha_pool, sizeof (chash_t), DV_BIN);
  memset (new_cha, 0, sizeof (chash_t));
  new_cha->cha_size = new_sz;
  cha_alloc_int (new_cha, setp, cha->cha_new_sqt, cha);
  for (n_part = 0; n_part < MAX (1, cha->cha_n_partitions); n_part++)
    {
      chash_t *cha_p = CHA_PARTITION (cha, n_part);
      if (cha->cha_is_1_int)
	{
	  for (inx = 0; inx < cha_p->cha_size; inx++)
	    {
	      int64 ent = ((int64 *) cha_p->cha_array)[inx];
	      if (CHA_EMPTY == ent)
		continue;
	      cha_col_copy (new_cha, cha, ent, 0, new_row);
	      cha_rehash_insert (new_cha, new_row);
	    }
	  for (inx = 0; inx < cha_p->cha_exception_fill; inx++)
	    {
	      int64 ent = ((int64 *) cha_p->cha_exceptions)[inx];
	      cha_col_copy (new_cha, cha, ent, 0, new_row);
	      cha_rehash_insert (new_cha, new_row);
	    }
	}
    }
}


uint64
cha_ent_h (chash_t * cha, int64 ent)
{
  uint64 h;
  if (cha->cha_is_1_int)
    {
      h = 1;
      MHASH_STEP (h, ent);
    }
  else if (cha->cha_is_1_int_key)
    {
      int64 ik = *(int64 *) ent;
      h = 1;
      MHASH_STEP (h, ik);
    }
  else
    h = *(int64 *) ent;
  return h;
}

void
cha_resize (chash_t * cha, setp_node_t * setp)
{
  int n_part, inx;
  int prev_sz = cha->cha_n_partitions ? cha->cha_partitions[0].cha_size * cha->cha_n_partitions : cha->cha_size;
  int new_sz = MAX (2 * chash_part_max_fill, 2 * prev_sz);
  chash_t *new_cha = (chash_t *) mp_alloc_box_ni (cha->cha_pool, sizeof (chash_t), DV_BIN);
  *new_cha = *cha;
  new_cha->cha_size = new_sz;
  cha_alloc_int (new_cha, setp, cha->cha_new_sqt, cha);
  for (n_part = 0; n_part < MAX (1, cha->cha_n_partitions); n_part++)
    {
      chash_t *cha_p = CHA_PARTITION (cha, n_part);
      uint64 h;
      int64 empty = cha->cha_is_1_int ? CHA_EMPTY : 0;
      for (inx = 0; inx < cha_p->cha_size; inx++)
	{
	  int64 ent = ((int64 *) cha_p->cha_array)[inx];
	  if (empty == ent)
	    continue;
	  CKE (ent);
	  h = cha_ent_h (cha, ent);
	  cha_rehash_add (new_cha, h, ent);
	}
      for (inx = 0; inx < cha_p->cha_exception_fill; inx++)
	{
	  int64 ent = ((int64 *) cha_p->cha_exceptions)[inx];
	  h = cha_ent_h (cha, ent);
	  cha_rehash_add (new_cha, h, ent);
	}
    }
  cha->cha_size = new_sz;
  cha->cha_n_partitions = new_cha->cha_n_partitions;
  cha->cha_partitions = new_cha->cha_partitions;
}


int
cha_n_empty (chash_t * cha)
{
  int n = 0, inx;
  for (inx = 0; inx < cha->cha_size; inx++)
    if (!cha->cha_array[inx])
      n++;
  return n;
}

#define CHA_FREE 0


int
cha_can_move (chash_t * cha, int pos, int level)
{
  int64 **array = cha->cha_array;
  int64 *row = array[pos];
  uint64 hno;
  int pos2, pos3;

  int64 __i;
  if (cha->cha_is_1_int)
    {
      __i = (int64) row;
      hno = 1;
      MHASH_STEP (hno, __i);
    }
  else if (cha->cha_is_1_int_key)
    {
      __i = ((int64 *) row)[0];
      hno = 1;
      MHASH_STEP (hno, __i);
    }
  else
    hno = ((int64 *) row)[0];

  pos2 = CHA_POS_2 (cha, hno);
  if (pos2 == pos)
    return -1;
  if ((cha->cha_is_1_int ? CHA_EMPTY : CHA_FREE) == ((int64 *) cha->cha_array)[pos2])
    return pos2;
  if (!level)
    return -1;
  if (-1 != (pos3 = cha_can_move (cha, pos2, level - 1)))
    {
      array[pos3] = array[pos2];
      return pos2;
    }
  return -1;
}


int
cha_relocate (chash_t * cha, uint64 hash_no, int64 * ent)
{
  int new_1;
  int pos1 = CHA_POS_1 (cha, hash_no);
  int pos2 = CHA_POS_2 (cha, hash_no);
  if (-1 != (new_1 = cha_can_move (cha, pos1, chash_look_levels)))
    {
      ((int64 **) cha->cha_array)[new_1] = ((int64 **) cha->cha_array)[pos1];
      ((int64 **) cha->cha_array)[pos1] = ent;
      return 1;
    }
  if (-1 != (new_1 = cha_can_move (cha, pos2, chash_look_levels)))
    {
      ((int64 **) cha->cha_array)[new_1] = ((int64 **) cha->cha_array)[pos2];
      ((int64 **) cha->cha_array)[pos2] = ent;
      return 1;
    }
  return 0;
}


int64 *
cha_add_gb (setp_node_t * setp, caddr_t * inst, db_buf_t ** key_vecs, chash_t * cha, uint64 hash_no, int inx, int row_no, int base)
{
  int64 *ent = cha_new_gb (setp, inst, key_vecs, cha, hash_no, row_no, base);
  CKE (ent);
  if (-1 != inx)
    {
      cha->cha_array[inx] = ent;
      return ent;
    }
  if (!cha_relocate (cha, hash_no, ent))
    mp_array_add (cha->cha_pool, (caddr_t **) & cha->cha_exceptions, &cha->cha_exception_fill, (caddr_t) ent);
  return ent;
}


void
cha_add_row (setp_node_t * setp, caddr_t * inst, db_buf_t ** key_vecs, chash_t * cha, uint64 hash_no, int inx, int row_no,
    int64 * prev)
{
  int64 *ent = cha_new_hj_row (setp, inst, key_vecs, cha, hash_no, row_no, prev);
  if (prev)
    {
      cha->cha_unique = CHA_NON_UNQ;
      return;
    }
  if (-1 != inx)
    {
      cha->cha_array[inx] = ent;
      return;
    }
  if (!cha_relocate (cha, hash_no, ent))
    {
      if (!cha->cha_is_parallel || (cha->cha_exceptions && BOX_ELEMENTS (cha->cha_exceptions) > cha->cha_exception_fill))
	{
	  mp_array_add (cha->cha_pool, (caddr_t **) & cha->cha_exceptions, &cha->cha_exception_fill, (caddr_t) ent);
	}
      else
	{
	  mutex_enter (&cha_alloc_mtx);
	  mp_array_add (cha->cha_pool, (caddr_t **) & cha->cha_exceptions, &cha->cha_exception_fill, (caddr_t) ent);
	  mutex_leave (&cha_alloc_mtx);
	}
    }
}


int
dv_eq_f (db_buf_t p1, db_buf_t p2)
{
  db_buf_t dv1 = (db_buf_t) p1, dv2 = (db_buf_t) p2;
  uint64 w1 = *(int64 *) dv1;
  uint64 xo = w1 ^ *(int64 *) dv2;
  int l = db_buf_const_length[(dtp_t) w1];
  if (l < 0)
    {
      l = 2 + (int) (dtp_t) (w1 >> 8);
    }
  else if (l == 0)
    {
      long l2, hl2;
      db_buf_length (dv1, &l2, &hl2);
      l = l2 + hl2;
    }
  if (l >= 8)
    {
      if (xo)
	goto neq;
      dv1 += 8;
      dv2 += 8;
      l -= 8;
      memcmp_8 (dv1, dv2, l, neq);
    }
  else
    {
      if (xo & (((int64) 1 << (l << 3)) - 1))
	goto neq;
    }
  return 1;
neq:
  return 0;
}


#define DV_EQF(a,b,n) if (!dv_eq_f (a,b)) goto n;
#define DV_EQF2(a,b,n) if (DVC_MATCH != dv_compare (a, b, NULL, 0)) goto neq;




int
cha_cmp (chash_t * cha, int64 * ent, db_buf_t ** key_vecs, int row_no)
{
  int inx;
  for (inx = 0; inx < cha->cha_n_keys; inx++)
    {
      db_buf_t k1 = ((db_buf_t *) ent)[inx + 1];
      db_buf_t k2 = ((db_buf_t **) key_vecs)[inx][row_no];
      if (DV_ANY == cha->cha_sqt[inx].sqt_dtp)
	{
#if 1
	  DV_EQ (k1, k2, neq);
#elif 0
	  unsigned short s2 = *(unsigned short *) k2, s1 = *(unsigned short *) k1;
	  if (s1 != s2)
	    return 0;
	  if (-1 == db_buf_const_length[s1 & 0xff])
	    {
	      if (0 == memcmp (k1 + 2, k2 + 2, s1 >> 8))
		continue;
	      else
		return 0;
	    }
#elif 0
	  DB_BUF_TLEN (l1, k1[0], k1);
	  DB_BUF_TLEN (l2, k2[0], k2);
	  if (l1 != l2)
	    return 0;
	  if (memcmp (k1, k2, l1))
	    return 0;
#endif
	}
      else if (DV_DATETIME == cha->cha_sqt[inx].sqt_dtp)
	{
	  k2 = ((db_buf_t *) key_vecs)[inx] + DT_LENGTH * row_no;
	  if (INT64_REF_CA (k1) != INT64_REF_CA (k2))
	    return 0;
	}
      else
	{
	  if (k1 != k2)
	    return 0;
	}
    }
  return 1;
neq:
  return 0;
}


int
cha_cmp_unq_fill (chash_t * cha, int64 * ent, db_buf_t ** key_vecs, int row_no)
{
  return 0;
}


int
cha_cmp_2a (chash_t * cha, int64 * ent, db_buf_t ** key_vecs, int row_no)
{
  int l1, l2, l3, l4;
  db_buf_t k1 = ((db_buf_t *) ent)[1];
  db_buf_t k2 = ((db_buf_t **) key_vecs)[0][row_no];
  db_buf_t k3 = ((db_buf_t *) ent)[2];
  db_buf_t k4 = ((db_buf_t **) key_vecs)[1][row_no];
  DV_EQ (k1, k2, neq);
  DV_EQ (k1, k2, neq);
  return 1;
  DB_BUF_TLEN (l1, *k1, k1);
  DB_BUF_TLEN (l2, *k2, k2);
  DB_BUF_TLEN (l3, *k3, k3);
  DB_BUF_TLEN (l4, *k4, k4);
  if (l1 != l2 || l3 != l4)
    return 0;
  memcmp_8 (k1, k2, l1, neq);
  memcmp_8 (k3, k4, l3, neq);
  return 1;
neq:
  return 0;
}


void
setp_chash_run (setp_node_t * setp, caddr_t * inst, index_tree_t * it)
{
  cha_cmp_t cmp = cha_cmp;
  hash_index_t *hi = it->it_hi;
  hash_area_t *ha = setp->setp_ha;
  chash_t *cha = hi->hi_chash;
  int n_sets = QST_INT (inst, setp->src_gen.src_prev->src_out_fill);
  int64 hash_no[ARTM_VEC_LEN];
  int64 *groups[ARTM_VEC_LEN];
  data_col_t *sets_dc = QST_BOX (data_col_t *, inst, setp->setp_ssa.ssa_set_no->ssl_index);
  db_buf_t *key_vecs[CHASH_GB_MAX_KEYS];
  dtp_t temp[CHASH_GB_MAX_KEYS * DT_LENGTH * ARTM_VEC_LEN];
  dtp_t temp_any[9 * CHASH_GB_MAX_KEYS * ARTM_VEC_LEN];
  int first_set, set;
  for (first_set = 0; first_set < n_sets; first_set += ARTM_VEC_LEN)
    {
      int any_temp_fill = 0;
      int key;
      int last_set = MIN (first_set + ARTM_VEC_LEN, n_sets);
      for (key = 0; key < last_set - first_set; key++)
	hash_no[key] = 1;
      for (key = 0; key < ha->ha_n_keys; key++)
	{
	  if (1 == sets_dc->dc_n_values)
	    {
	      key_vecs[key] =
		  (db_buf_t *) gb_values (cha, hash_no, inst, ha->ha_slots[key], key, first_set, last_set, (db_buf_t) temp,
		  temp_any, &any_temp_fill);
	    }
	  else
	    GPF_T1 ("no vectored multiset gb");
	}
      if (2 == ha->ha_n_keys && DV_ANY == cha->cha_sqt[0].sqt_dtp && DV_ANY == cha->cha_sqt[1].sqt_dtp)
	cmp = cha_cmp_2a;
      for (set = first_set; set + 4 <= last_set; set += 4)
	{
	  int inx = set - first_set, e;
	  int pos1_1, pos2_1, pos1_2, pos2_2, pos1_3, pos2_3, pos1_4, pos2_4;
	  chash_t *cha_p_1, *cha_p_2, *cha_p_3, *cha_p_4;
	  uint64 h_1, h_2, h_3, h_4;
	  int64 **array_1, **array_2, **array_3, **array_4;
	  int64 *ent;

#define GB_PRE(n) \
	  h_##n = hash_no[inx + n - 1];\
	  cha_p_##n = CHA_PARTITION (cha, h_##n); \
	  array_##n = cha_p_##n->cha_array; \
	  pos1_##n = CHA_POS_1(cha_p_##n, h_##n);  \
	  pos2_##n = CHA_POS_2(cha_p_##n, h_##n);	\
	  __builtin_prefetch (array_##n[pos1_##n]);

#define GB_CK(n, f)		     \
	  ent = array_##n[pos1_##n]; \
	  if (!ent) \
	    { \
	        cha->cha_distinct_count++;				\
		groups[inx + n - 1] = cha_add_gb (setp, inst, key_vecs, cha_p_##n, h_##n, pos1_##n, inx + n - 1, first_set); \
	      goto done_##n##f; \
	    } \
	  if (h_##n == *ent && cmp (cha, ent, key_vecs, inx + n - 1)) \
	  { \
	    groups[inx + n - 1] = ent; \
	    goto done_##n##f; \
	  } \
	  ent = array_##n[pos2_##n]; \
	  if (!ent) \
	    { \
	      cha->cha_distinct_count++;				\
	      groups[inx + n - 1] = cha_add_gb (setp, inst, key_vecs, cha_p_##n, h_##n, pos2_##n, inx + n - 1, first_set); \
	      goto done_##n##f; \
	    } \
	  if (h_##n == *ent && cmp (cha, ent, key_vecs, inx + n - 1)) \
	    { \
	      groups[inx + n - 1] = ent; \
	      goto done_##n##f; \
	    } \
	  for (e = 0; e < cha_p_##n->cha_exception_fill; e++) \
	    { \
	      int64 * ent = ((int64**)cha_p_##n->cha_exceptions)[e]; \
	      if (h_##n == ent[0] && cmp (cha, ent, key_vecs, inx + n - 1)) \
		{ \
		  groups[inx + n - 1] = ent; \
		  goto done_##n##f; \
		} \
	    } \
	  cha->cha_distinct_count++;					\
	  groups[inx + n - 1] = cha_add_gb (setp, inst, key_vecs, cha_p_##n, h_##n, -1, inx + n - 1, first_set); \
	done_##n##f: ;

	  GB_PRE (1);
	  GB_PRE (2);
	  GB_PRE (3);
	  GB_PRE (4);

	  GB_CK (1, f);
	  GB_CK (2, f);
	  GB_CK (3, f);
	  GB_CK (4, f);

	}
      for (set = set; set < last_set; set++)
	{
	  int inx = set - first_set, e;
	  int pos1_1, pos2_1;
	  chash_t *cha_p_1;
	  uint64 h_1;
	  int64 **array_1;
	  int64 *ent;
	  GB_PRE (1);
	  GB_CK (1, ff);
	}

      gb_aggregate (setp, inst, cha, groups, first_set, last_set);
      if (cha->cha_distinct_count > cha->cha_size * 9 / 16)
	cha_resize (cha, setp);
    }
}

int
dtp_is_chash_inlined (dtp_t dtp)
{
  /* if dtp needs a null flag in chash */
  switch (dtp_canonical[dtp])
    {
    case DV_LONG_INT:
    case DV_IRI_ID:
    case DV_SINGLE_FLOAT:
    case DV_DOUBLE_FLOAT:
      return 1;
    }
  return 0;
}


int
ha_null_flags (hash_area_t * ha)
{
  int n = 0, inx;
  for (inx = ha->ha_n_keys; inx < ha->ha_n_keys + ha->ha_n_deps; inx++)
    if (!ha->ha_key_cols[inx].cl_sqt.sqt_non_null && dtp_is_chash_inlined (ha->ha_key_cols[inx].cl_sqt.sqt_dtp))
      n++;
  return n;
}


void
cha_alloc_int (chash_t * cha, setp_node_t * setp, sql_type_t * new_sqt, chash_t * old_cha)
{
  hash_area_t *ha = setp->setp_ha;
  int old_n_part = old_cha ? MAX (1, old_cha->cha_n_partitions) : 0;
  int n_rows, n_part, inx;

  cha->cha_ha = ha;
  if (HA_GROUP == ha->ha_op)
    {
      cha->cha_first_len = ha->ha_ch_len;
      cha->cha_null_flags = ha->ha_ch_nn_flags;
    }
  else if (HA_FILL == ha->ha_op)
    {
      dtp_t dtp = dtp_canonical[ha->ha_key_cols[0].cl_sqt.sqt_dtp];
      int first_len = 0, next_len = 0, nn;
      cha->cha_unique = ha->ha_ch_unique;
      if (1 == ha->ha_n_keys && (DV_LONG_INT == dtp || DV_IRI_ID == dtp))
	{
	  if (!ha->ha_n_deps && CHA_ALWAYS_UNQ == ha->ha_ch_unique)
	    cha->cha_is_1_int = 1;
	  else
	    cha->cha_is_1_int_key = 1;
	}
      else
	first_len = 1;
      first_len += ha->ha_n_keys;
      next_len = first_len;
      first_len += ha->ha_n_deps;
      nn = ha_null_flags (ha);
      if (nn)
	cha->cha_null_flags = sizeof (int64) * first_len;
      first_len += _RNDUP_PWR2 (nn, 64) / 64;
      if (CHA_ALWAYS_UNQ != cha->cha_unique)
	{
	  cha->cha_next_ptr = first_len;
	  first_len++;
	}
      cha->cha_first_len = first_len;
      cha->cha_next_len = first_len - next_len;
      if (CHA_ALWAYS_UNQ != ha->ha_ch_unique)
	{
	  cha->cha_unique = CHA_UNQ;
	}
      cha->cha_first_len *= sizeof (int64);
      cha->cha_next_len *= sizeof (int64);
    }
  n_rows = cha->cha_size;
  if (n_rows <= 0)
    n_rows = 10000;
  n_part = n_rows / chash_part_max_fill;
  n_part = MIN (n_part, chash_max_partitions);
  if (n_part)
    {
      cha->cha_n_partitions = n_part;
      cha->cha_partitions = (chash_t *) mp_alloc_box_ni (cha->cha_pool, n_part * sizeof (chash_t), DV_BIN);
      memset (cha->cha_partitions, 0, box_length (cha->cha_partitions));
      for (inx = 0; inx < n_part; inx++)
	{
	  chash_t *cha_p = &cha->cha_partitions[inx];
	  *cha_p = *cha;
	  cha_p->cha_size = chash_part_size;
	  cha_p->cha_array = (int64 **) mp_alloc_box_ni (cha->cha_pool, sizeof (int64) * cha_p->cha_size, DV_BIN);
	  int64_fill_nt ((int64 *) cha_p->cha_array, cha->cha_is_1_int ? CHA_EMPTY : 0, cha_p->cha_size);
	  if (inx < old_n_part)
	    {
	      chash_t *oldp = CHA_PARTITION (old_cha, inx);
	      if (oldp->cha_is_parallel)
		dk_mutex_destroy (&oldp->cha_mtx);
	    }
	  if (!cha->cha_is_1_int)
	    {
	      if (inx < old_n_part)
		{
		  chash_t *oldp = CHA_PARTITION (old_cha, inx);
		  cha_p->cha_current = oldp->cha_current;
		  cha_p->cha_current_data = oldp->cha_current_data;
		}
	      else
		{
		  cha_p->cha_current = (chash_page_t *) mp_alloc_box_ni (cha->cha_pool, PAGE_SZ, DV_BIN);
		  memset (cha_p->cha_current, 0, DP_DATA);
		}
	    }
	  if (cha->cha_is_parallel)
	    dk_mutex_init (&cha_p->cha_mtx, MUTEX_TYPE_SHORT);
	}
    }
  else
    {
      cha->cha_size = n_rows * 2;
      cha->cha_array = (int64 **) mp_alloc_box_ni (cha->cha_pool, sizeof (int64) * cha->cha_size, DV_BIN);
      int64_fill_nt ((int64 *) cha->cha_array, cha->cha_is_1_int ? CHA_EMPTY : 0, cha->cha_size);
      if (!cha->cha_is_1_int)
	{
	  cha->cha_current = (chash_page_t *) mp_alloc_box_ni (cha->cha_pool, PAGE_SZ, DV_BIN);
	  memset (cha->cha_current, 0, DP_DATA);
	}
    }
}


index_tree_t *
cha_allocate (setp_node_t * setp, caddr_t * inst, int64 card)
{
  hash_area_t *ha = setp->setp_ha;
  int n_slots = BOX_ELEMENTS (ha->ha_slots), inx;
  index_tree_t *tree = it_temp_allocate (wi_inst.wi_temp);
  hash_index_t *hi;
  chash_t *cha;
  hi = tree->it_hi = hi_allocate ((int) MIN (ha->ha_row_count, (long) chash_max_count), HI_CHASH, ha);
  tree->it_key = ha->ha_key;
  tree->it_shared = HI_PRIVATE;
  qst_set_tree (inst, ha->ha_tree, ha->ha_set_no, tree);
  if (!hi->hi_pool)
    hi->hi_pool = mem_pool_alloc ();
  cha = hi->hi_chash = (chash_t *) mp_alloc (hi->hi_pool, sizeof (chash_t));
  memset (cha, 0, sizeof (chash_t));
  cha->cha_pool = hi->hi_pool;
  cha->cha_pool->mp_block_size = (PAGE_SZ + 32) * 4;
  if (setp->setp_fref && setp->setp_fref->fnr_parallel_hash_fill)
    cha->cha_is_parallel = 1;
  cha->cha_n_keys = ha->ha_n_keys;

  cha->cha_sqt = (sql_type_t *) mp_alloc_box (cha->cha_pool, sizeof (sql_type_t) * n_slots, DV_BIN);
  memset (cha->cha_sqt, 0, box_length (cha->cha_sqt));
  DO_BOX (state_slot_t *, ssl, inx, ha->ha_slots)
  {
    if (SSL_CONSTANT == ssl->ssl_type)
      {
	cha->cha_sqt[inx].sqt_dtp = ssl->ssl_sqt.sqt_dtp;
	cha->cha_sqt[inx].sqt_non_null = 1;
      }
    else
      {
	data_col_t *dc = QST_BOX (data_col_t *, inst, ssl->ssl_index);
	cha->cha_sqt[inx].sqt_dtp = dc->dc_dtp;
	cha->cha_sqt[inx].sqt_non_null = ssl->ssl_sqt.sqt_non_null;
      }
  }
  END_DO_BOX;

  if (HA_GROUP == ha->ha_op)
    cha->cha_size = MIN (2 * ha->ha_row_count, chash_max_count);
  else
    cha->cha_size = card;
  cha_alloc_int (cha, setp, NULL, NULL);
  if (cha->cha_is_parallel)
    dk_mutex_init (&cha->cha_mtx, MUTEX_TYPE_SHORT);
  return tree;
}


void
cha_clear_fill (chash_page_t * chp)
{
  for (chp = chp; chp; chp = chp->h.h.chp_next)
    chp->h.h.chp_fill = 0;
}

void
cha_clear_1 (chash_t * cha)
{
  if (cha->cha_array)
    int64_fill_nt ((int64 *) cha->cha_array, cha->cha_is_1_int ? CHA_EMPTY : 0, cha->cha_size);
  cha->cha_count = cha->cha_distinct_count = 0;
  if (cha->cha_unique != CHA_ALWAYS_UNQ)
    cha->cha_unique = CHA_UNQ;
  if (cha->cha_init_page)
    cha->cha_current = cha->cha_init_page;
  else
    cha->cha_init_page = cha->cha_current;
  if (cha->cha_init_data)
    cha->cha_current_data = cha->cha_init_data;
  else
    cha->cha_init_data = cha->cha_current_data;
  cha_clear_fill (cha->cha_current);
  cha_clear_fill (cha->cha_current_data);
}


void
cha_clear (chash_t * cha)
{
  int inx;
  cha_clear_1 (cha);
  for (inx = 0; inx < cha->cha_n_partitions; inx++)
    cha_clear_1 (&cha->cha_partitions[inx]);
}


void
cha_free (chash_t * cha)
{
  int inx;
  if (cha->cha_is_parallel)
    {
      for (inx = 0; inx < cha->cha_n_partitions; inx++)
	{
	  dk_mutex_destroy (&cha->cha_partitions[inx].cha_mtx);
	}
      dk_mutex_destroy (&cha->cha_mtx);
    }
  mutex_enter (&chash_rc_mtx);
  chash_space_avail += cha->cha_reserved;
  mutex_leave (&chash_rc_mtx);
  mp_free (cha->cha_pool);
}


int enable_chash_gb = 0;


int
setp_stream_breakable (setp_node_t * setp, caddr_t * inst)
{
  /* if streaming setp, a batch of results can be produced whenever only the streaming ts is continuable, i.e. nothing continuable between that and the setp.
   * The point is that since stuff can be reorderd in between the stream ts and the setp, we must know that the last vallue of the stream ts is in fact aggregated in the setp.  Groups with this value will survive as more values may come in for these */
  DO_SET (data_source_t *, qn, &setp->setp_fref->fnr_select_nodes)
  {
    if (qn == (data_source_t *) setp->setp_fref->fnr_stream_ts)
      return 1;
    if (SRC_IN_STATE (qn, inst))
      return 0;
  }
  END_DO_SET ();
  GPF_T1 ("stream setp predecessor nodes out of whack");
  return 0;			/*not reached */
}


int
setp_chash_group (setp_node_t * setp, caddr_t * inst)
{
  dk_set_t ops;
  gb_op_t *go;
  index_tree_t *tree;
  hash_area_t *ha = setp->setp_ha;
  int inx, n_slots = BOX_ELEMENTS (ha->ha_slots);
  data_col_t *sets = QST_BOX (data_col_t *, inst, setp->setp_ssa.ssa_set_no->ssl_index);
  chash_t *cha = NULL;
  QNCAST (query_instance_t, qi, inst);

  if (!enable_chash_gb || (!setp->setp_set_no_in_key && 1 != sets->dc_n_values))
    return 0;
  qi->qi_set = 0;
  tree = qst_tree (inst, ha->ha_tree, setp->setp_ssa.ssa_set_no);
  if (tree)
    {
      cha = tree->it_hi->hi_chash;
      if (!cha)
	return 0;
    }
  ops = setp->setp_gb_ops;
  for (inx = ha->ha_n_keys; inx < n_slots; inx++)
    {
      state_slot_t *ssl = ha->ha_slots[inx];
      data_col_t *dc;
      if (SSL_CONSTANT == ssl->ssl_type)
	continue;
      if (ssl->ssl_type < SSL_VEC)
	goto no;
      dc = QST_BOX (data_col_t *, inst, ssl->ssl_index);
      if (ops && !(DCT_NUM_INLINE & dc->dc_type))
	goto no;
      if (cha && dc->dc_dtp != cha->cha_sqt[inx].sqt_dtp)
	goto no;
      if (ops)
	ops = ops->next;
    }
  if (!cha)
    {
      tree = cha_allocate (setp, inst, 0);
      cha = tree->it_hi->hi_chash;
    }
  setp_chash_run (setp, inst, tree);
  if (setp->setp_is_streaming
      && cha->cha_distinct_count * 100 > (dc_batch_sz * cha_stream_gb_flush_pct) && setp_stream_breakable (setp, inst))
    longjmp_splice (THREAD_CURRENT_THREAD->thr_reset_ctx, RST_GB_ENOUGH);
  return 1;
no:
  if (cha)
    chash_to_memcache (inst, tree, ha);
  return 0;
}


caddr_t
cha_box_col (chash_t * cha, hash_area_t * ha, db_buf_t row, int inx)
{
  if (!cha->cha_sqt[inx].sqt_non_null
      && DV_ANY != cha->cha_sqt[inx].sqt_dtp && !(((db_buf_t) row)[cha->cha_null_flags + (inx >> 3)] & (1 << (inx & 7))))
    return t_alloc_box (0, DV_DB_NULL);
  switch (cha->cha_sqt[inx].sqt_dtp)
    {
    case DV_LONG_INT:
      return t_box_num (((int64 *) row)[inx + 1]);
    case DV_SINGLE_FLOAT:
      return t_box_float (*(float *) &(((int64 *) row)[inx + 1]));
    case DV_DOUBLE_FLOAT:
      return t_box_double (((double *) row)[inx + 1]);
    case DV_DATETIME:
      {
	caddr_t dt = t_alloc_box (DT_LENGTH, DV_DATETIME);
	memcpy_dt (dt, ((caddr_t *) row)[inx + 1]);
	return dt;
      }
    default:
      return mp_box_deserialize_string (cha->cha_pool, *(caddr_t *) (row + sizeof (int64) * (inx + 1)), INT32_MAX, 0);
    }
}

id_hashed_key_t hi_memcache_hash (caddr_t p_data);
int hi_memcache_cmp (caddr_t d1, caddr_t d2);

int mc_sets;

void
chash_to_memcache (caddr_t * inst, index_tree_t * tree, hash_area_t * ha)
{
  hash_index_t *hi = tree->it_hi;
  chash_t *cha = hi->hi_chash;
  hi_memcache_key_t hmk;
  chash_page_t *chp = cha->cha_current;
  int part, n_slots = BOX_ELEMENTS (ha->ha_slots);
  SET_THR_TMP_POOL (cha->cha_pool);
  if (!hi->hi_memcache)
    hi->hi_memcache = t_id_hash_allocate (MIN (400000, cha->cha_distinct_count),
	sizeof (hi_memcache_key_t), sizeof (caddr_t *), hi_memcache_hash, hi_memcache_cmp);
  for (part = 0; part < MAX (cha->cha_n_partitions, 1); part++)
    {
      chash_t *cha_p = CHA_PARTITION (cha, part);
      for (chp = cha_p->cha_current; chp; chp = chp->h.h.chp_next)
	{
	  int pos;
	  for (pos = 0; pos < chp->h.h.chp_fill; pos += cha->cha_first_len)
	    {
	      caddr_t *key = (caddr_t *) mp_alloc_box_ni (cha->cha_pool, sizeof (caddr_t) * ha->ha_n_keys, DV_ARRAY_OF_POINTER);
	      caddr_t *data;
	      uint32 h = HC_INIT;
	      int var_len = 0, inx;
	      CKE ((&chp->chp_data[pos]));
	      for (inx = 0; inx < ha->ha_n_keys; inx++)
		{
		  key[inx] = cha_box_col (cha, ha, &chp->chp_data[pos], inx);
		  h = key_hash_box (key[inx], DV_TYPE_OF (key[inx]), h, &var_len, NULL, ha->ha_key_cols[inx].cl_sqt.sqt_dtp, 1);
		}
	      hmk.hmk_data = key;
	      hmk.hmk_var_len = var_len;
	      hmk.hmk_hash = h & ID_HASHED_KEY_MASK;
	      hmk.hmk_ha = ha;
	      data = (caddr_t *) mp_alloc_box_ni (cha->cha_pool, sizeof (caddr_t) * (n_slots - ha->ha_n_keys), DV_ARRAY_OF_POINTER);
	      for (inx = ha->ha_n_keys; inx < n_slots; inx++)
		data[inx - ha->ha_n_keys] = cha_box_col (cha, ha, &chp->chp_data[pos], inx);
	      mc_sets++;
	      t_id_hash_set (hi->hi_memcache, (caddr_t) & hmk, (caddr_t) & data);
	    }
	}
    }
  SET_THR_TMP_POOL (NULL);
  hi->hi_chash = NULL;
}

int
cha_mrg_cmp (setp_node_t * setp, chash_t * cha1, int64 * ent1, int64 * ent2)
{
  int inx;
  for (inx = 0; inx < cha1->cha_n_keys; inx++)
    {
      switch (cha1->cha_sqt[inx].sqt_dtp)
	{
	case DV_ANY:
	  DV_EQ ((db_buf_t) ent1[inx + 1], (db_buf_t) ent2[inx + 1], neq);
	  break;
	case DV_DATETIME:
	  if (*(int64 *) ent1[inx + 1] != *(int64 *) ent2[inx + 1])
	    return 0;
	  break;
	default:
	  if (ent1[inx + 1] != ent2[inx + 1])
	    return 0;
	}
    }
  return 1;
neq:return 0;
}


void
cha_ent_merge (setp_node_t * setp, chash_t * cha, int64 * tar, int64 * ent)
{
  hash_area_t *ha = setp->setp_ha;
  int inx = cha->cha_n_keys;
  DO_SET (gb_op_t *, go, &setp->setp_gb_ops)
  {
    int op = go->go_op;
    if (GB_IS_NULL (ha, ent, inx))
      continue;
    switch (AGG_C (cha->cha_sqt[inx].sqt_dtp, op))
      {
      case AGG_C (DV_LONG_INT, AMMSC_COUNT):
      case AGG_C (DV_LONG_INT, AMMSC_COUNTSUM):
      case AGG_C (DV_LONG_INT, AMMSC_SUM):
	tar[inx + 1] += ent[inx + 1];
	GB_HAS_VALUE (ha, tar, inx);
	break;
      case AGG_C (DV_DOUBLE_FLOAT, AMMSC_COUNT):
      case AGG_C (DV_DOUBLE_FLOAT, AMMSC_COUNTSUM):
      case AGG_C (DV_DOUBLE_FLOAT, AMMSC_SUM):
	((double *) tar)[inx + 1] += ((double *) ent)[inx + 1];
	GB_HAS_VALUE (ha, tar, inx);
	break;
      case AGG_C (DV_SINGLE_FLOAT, AMMSC_COUNT):
      case AGG_C (DV_SINGLE_FLOAT, AMMSC_COUNTSUM):
      case AGG_C (DV_SINGLE_FLOAT, AMMSC_SUM):
	*(float *) &tar[inx + 1] += *(float *) &ent[inx + 1];
	GB_HAS_VALUE (ha, tar, inx);
	break;

      default:
	GPF_T1 ("op not supportted in chash merge. ");
      }
    inx++;
  }
  END_DO_SET ();
}


int64 *
cha_mrg_copy (chash_t * cha, int64 * ent)
{
  int inx, n_sqt = cha->cha_ha->ha_n_keys + cha->cha_ha->ha_n_deps;
  int64 *cpy = cha_new_row (cha->cha_ha, cha, 0);
  memcpy_16 (cpy, ent, cha->cha_first_len);
  for (inx = 0; inx < n_sqt; inx++)
    {
      if (DV_ANY == cha->cha_sqt[inx].sqt_dtp)
	cpy[inx + 1] = (ptrlong) cha_any (cha, (db_buf_t) (ptrlong) cpy[inx + 1]);
    }
  return cpy;
}

void
chash_merge (setp_node_t * setp, chash_t * cha, chash_t * delta)
{
  /* Merge two group bys.  No need for the fuckwit conversion to memcache and then to pageable in order to merge overlapping partitions of a group by */
  int part;
  chash_t *cha_p;
  int pos1_1, pos2_1, e;
  for (part = 0; part < MAX (1, delta->cha_n_partitions); part++)
    {
      chash_t *de_p = CHA_PARTITION (delta, part);
      chash_page_t *chp = de_p->cha_current;
      for (chp = chp; chp; chp = chp->h.h.chp_next)
	{
	  int row;
	  for (row = 0; row < chp->h.h.chp_fill; row += de_p->cha_first_len)
	    {
	      int64 *ent = (int64 *) & chp->chp_data[row], **array, *tar;
	      uint64 h = ent[0];
	      CKE (ent);
	      cha_p = CHA_PARTITION (cha, h);
	      array = cha_p->cha_array;
	      pos1_1 = CHA_POS_1 (cha_p, h);
	      pos2_1 = CHA_POS_2 (cha_p, h);
	      tar = array[pos1_1];
	      if (!tar)
		{
		  array[pos1_1] = cha_mrg_copy (cha_p, ent);
		  cha->cha_distinct_count++;
		  continue;
		}
	      if (tar[0] == h && cha_mrg_cmp (setp, cha, tar, ent))
		{
		  cha_ent_merge (setp, cha, tar, ent);
		  continue;
		}
	      tar = array[pos2_1];
	      if (!tar)
		{
		  array[pos2_1] = cha_mrg_copy (cha_p, ent);
		  cha->cha_distinct_count++;
		  continue;
		}
	      if (tar[0] == h && cha_mrg_cmp (setp, cha, tar, ent))
		{
		  cha_ent_merge (setp, cha, tar, ent);
		  continue;
		}
	      for (e = 0; e < cha_p->cha_exception_fill; e++)
		{
		  tar = cha_p->cha_exceptions[e];
		  if (h == tar[0] && cha_mrg_cmp (setp, cha, tar, ent))
		    {
		      cha_ent_merge (setp, cha, tar, ent);
		      goto next;
		    }
		}
	      cha->cha_distinct_count++;
	      ent = cha_mrg_copy (cha_p, ent);
	      if (!cha_relocate (cha_p, h, ent))
		mp_array_add (cha->cha_pool, (caddr_t **) & cha_p->cha_exceptions, &cha_p->cha_exception_fill, (caddr_t) ent);
	    next:;
	    }
	  if (cha->cha_distinct_count > cha->cha_size * 9 / 16)
	    cha_resize (cha, setp);
	}
    }
}


void
dc_append_cha (data_col_t * dc, hash_area_t * ha, chash_t * cha, int64 * row, int col)
{
  if (!cha->cha_sqt[col].sqt_non_null
      && DV_ANY != cha->cha_sqt[col].sqt_dtp && !(((db_buf_t) row)[cha->cha_null_flags + (col >> 3)] & (1 << (col & 7))))
    {
      dc_append_null (dc);
      return;
    }
  switch (cha->cha_sqt[col].sqt_dtp)
    {
    case DV_ANY:
      {
	int len;
	db_buf_t dv = (db_buf_t) (ptrlong) row[col + 1];
	DB_BUF_TLEN (len, dv[0], dv);
	dc_append_bytes (dc, dv, len, NULL, 0);
	break;
      }
    case DV_LONG_INT:
    case DV_DOUBLE_FLOAT:
    case DV_IRI_ID:
      ((int64 *) dc->dc_values)[dc->dc_n_values++] = row[col + 1];
      break;
    case DV_SINGLE_FLOAT:
      ((int32 *) dc->dc_values)[dc->dc_n_values++] = *(int32 *) & ((int64 *) row)[col + 1];
      break;
    case DV_DATETIME:
      memcpy_dt (dc->dc_values + DT_LENGTH * dc->dc_n_values, ((db_buf_t *) row)[col + 1]);
      dc->dc_n_values++;
      break;
    }
}

int
cha_check_survival (chash_t * cha, caddr_t * inst, setp_node_t * setp, int64 * ent, int64 surviving)
{
  return 0;
}

void
cha_survival (chash_t * cha, caddr_t * inst, setp_node_t * setp)
{
}


void
chash_read_input (table_source_t * ts, caddr_t * inst, caddr_t * state)
{
  QNCAST (query_instance_t, qi, inst);
  key_source_t *ks = ts->ts_order_ks;
  setp_node_t *setp = ts->ts_order_ks->ks_from_setp;
  hash_area_t *ha = setp->setp_ha;
  fun_ref_node_t *fref = setp->setp_fref;
  index_tree_t *tree;
  chash_t *cha;
  int part;
  chash_page_t *chp;
  int n_results = 0, last_set, row;
  int set, n_sets = QST_INT (inst, ts->src_gen.src_prev->src_out_fill);
  if (ks->ks_set_no_col_ssl)
    n_sets = 1;
  if (state)
    {
      QST_INT (inst, ts->clb.clb_nth_set) = 0;
      QST_INT (inst, ks->ks_nth_cha_part) = 0;
      QST_INT (inst, ks->ks_pos_in_temp) = 0;
      QST_BOX (chash_page_t *, inst, ks->ks_cha_chp) = NULL;
      last_set = QST_INT (inst, ts->clb.clb_nth_set) = 0;
    }
next_batch:
  n_results = 0;
  ks_vec_new_results (ks, inst, NULL);
  last_set = QST_INT (inst, ts->clb.clb_nth_set);
  for (set = last_set; set < n_sets; set++)
    {
      int64 surviving = CHA_EMPTY;
      caddr_t *branch = fref->fnr_current_branch ? QST_BOX (caddr_t *, inst, fref->fnr_current_branch) : inst;
      qi->qi_set = set;
      tree = (index_tree_t *) qst_get (branch, ha->ha_tree);
      if (!tree)
	continue;
      cha = tree->it_hi->hi_chash;
      if (!cha)
	{
	  table_source_input (ts, inst, state);
	  return;
	}
      if (setp->setp_streaming_ssl)
	{
	  data_col_t *dc = QST_BOX (data_col_t *, branch, setp->setp_streaming_ssl->ssl_index);
	  surviving = dc_any_value (dc, dc->dc_n_values - 1);
	}
      part = QST_INT (inst, ks->ks_nth_cha_part);
      chp = QST_BOX (chash_page_t *, inst, ks->ks_cha_chp);
      row = QST_INT (inst, ks->ks_pos_in_temp);
      QST_INT (inst, ts->clb.clb_nth_set) = set;

      for (part = part; part < MAX (1, cha->cha_n_partitions); part++)
	{
	  chash_t *cha_p = CHA_PARTITION (cha, part);
	  if (!chp)
	    {
	      chp = cha_p->cha_current;
	      row = 0;
	    }
	  for (chp = chp; chp; chp = chp->h.h.chp_next)
	    {
	      for (row = row; row < chp->h.h.chp_fill; row += cha->cha_first_len)
		{
		  int k_inx = 0;
		  int64 *ent = (int64 *) & chp->chp_data[row];
		  if (setp->setp_streaming_ssl && cha_check_survival (cha, inst, setp, ent, surviving))
		    continue;
		  DO_SET (state_slot_t *, ssl, &ks->ks_out_slots)
		  {
		    if (SSL_REF == ssl->ssl_type)
		      ssl = ((state_slot_ref_t *) ssl)->sslr_ssl;
		    if (SSL_VEC == ssl->ssl_type)
		      dc_append_cha (QST_BOX (data_col_t *, inst, ssl->ssl_index), ha, cha, ent, k_inx);
		    else
		      GPF_T1 ("need vec ssl in chash read");
		    k_inx++;
		  }
		  END_DO_SET ();
		  if (ks->ks_set_no_col_ssl)
		    {
		      data_col_t *dc = QST_BOX (data_col_t *, inst, ks->ks_set_no_col_ssl->ssl_index);
		      int set_no = ((int64 *) dc->dc_values)[dc->dc_n_values - 1];
		      qn_result ((data_source_t *) ts, inst, set_no);
		    }
		  else
		    qn_result ((data_source_t *) ts, inst, set);
		  QST_INT (inst, ks->ks_pos_in_temp) = row;
		  if (++n_results == dc_batch_sz)
		    {
		      SRC_IN_STATE (ts, inst) = inst;
		      QST_INT (inst, ts->clb.clb_nth_set) = set;
		      QST_BOX (chash_page_t *, inst, ks->ks_cha_chp) = chp;
		      QST_INT (inst, ks->ks_nth_cha_part) = part;
		      if (ks->ks_always_null)
			ts_always_null (ts, inst);
		      qn_send_output ((data_source_t *) ts, inst);
		      state = NULL;
		      goto next_batch;
		    }
		}
	      row = 0;
	    }
	}
      cha_clear (cha);
      cha_survival (cha, inst, setp);
      QST_INT (inst, ks->ks_pos_in_temp) = 0;
    }
  SRC_IN_STATE ((data_source_t *) ts, inst) = NULL;
  if (QST_INT (inst, ts->src_gen.src_out_fill))
    {
      if (ks->ks_always_null)
	ts_always_null (ts, inst);
      qn_ts_send_output ((data_source_t *) ts, inst, ts->ts_after_join_test);
    }
}


/* hash join follows */

void
cha_results (hash_source_t * hs, caddr_t * inst, chash_t * cha, int set, int64 * row, int is_cont)
{
  /* put the matches in output cols.  If batch full, record continue state and return true. */
  hash_area_t *ha = hs->hs_ha;
  int n_dep = ha->ha_n_deps;
  int n_keys = ha->ha_n_keys;
  int cont_next_ptr = cha->cha_next_ptr - ((cha->cha_first_len - cha->cha_next_len) / sizeof (int64));
  int *sets = QST_BOX (int *, inst, hs->src_gen.src_sets), batch_sz;
  if (cha->cha_unique != CHA_NON_UNQ)
    {
      int dep;
      int n_values = 0, inx, out_inx;
      out_inx = 0;
      dep = ha->ha_n_keys + 1 - cha->cha_is_1_int_key;
      for (inx = dep; inx < dep + n_dep; inx++)
	{
	  dtp_t ch_dtp = cha->cha_sqt[out_inx + n_keys].sqt_dtp;
	  data_col_t *dc;
	  state_slot_t *ssl = hs->hs_out_slots[out_inx];
	  if (!ssl)
	    {
	      out_inx++;
	      continue;
	    }
	  dc = QST_BOX (data_col_t *, inst, ssl->ssl_index);
	  n_values = dc->dc_n_values;
	  if (!n_values && DV_ANY == dc->dc_sqt.sqt_col_dtp && DV_ANY != ch_dtp)
	    dc_convert_empty (dc, dv_ce_dtp[ch_dtp]);

	  if (chash_null_flag_dtps[ch_dtp] && !cha->cha_sqt[out_inx + n_keys].sqt_non_null
	      && CHA_IS_NULL (cha, is_cont, row, out_inx))
	    {
	      dc_append_null (dc);
	      n_values++;
	    }
	  else
	    {
	      switch (ch_dtp)
		{
		case DV_ANY:
		case DV_LONG_INT:
		case DV_DOUBLE_FLOAT:
		case DV_IRI_ID:
		  ((int64 *) dc->dc_values)[dc->dc_n_values++] = row[inx];
		  break;
		case DV_SINGLE_FLOAT:
		  ((int32 *) dc->dc_values)[dc->dc_n_values++] = *(int32 *) & ((int64 *) row)[inx];
		  break;
		case DV_DATETIME:
		  memcpy_dt (dc->dc_values + DT_LENGTH * dc->dc_n_values, ((db_buf_t *) row)[inx]);
		  dc->dc_n_values++;
		  break;
		default:
		  if (DCT_BOXES & dc->dc_type)
		    {
		      ((caddr_t *) dc->dc_values)[dc->dc_n_values++] = box_copy_tree (((caddr_t *) row)[inx]);
		      break;
		    }
		  GPF_T1 ("bad non-box out dc for chash join");
		}
	    }
	  out_inx++;
	}
      n_values = QST_INT (inst, hs->src_gen.src_out_fill)++;
      sets[n_values] = set;
      return;
    }

  batch_sz = QST_INT (inst, hs->src_gen.src_batch_size) - 1;
  for (;;)
    {
      int dep;
      int n_values = 0, inx, out_inx;
      out_inx = 0;
      if (is_cont)
	{
	  __builtin_prefetch ((void *) row[cont_next_ptr]);
	  dep = 0;
	}
      else
	{
	  __builtin_prefetch ((void *) row[cha->cha_next_ptr]);
	  dep = ha->ha_n_keys + 1 - cha->cha_is_1_int_key;
	}
      for (inx = dep; inx < dep + n_dep; inx++)
	{
	  dtp_t ch_dtp = cha->cha_sqt[out_inx + n_keys].sqt_dtp;
	  data_col_t *dc;
	  state_slot_t *ssl = hs->hs_out_slots[out_inx];
	  if (!ssl)
	    {
	      out_inx++;
	      continue;
	    }
	  dc = QST_BOX (data_col_t *, inst, ssl->ssl_index);
	  n_values = dc->dc_n_values;
	  if (!n_values && DV_ANY == dc->dc_sqt.sqt_col_dtp && DV_ANY != ch_dtp)
	    dc_convert_empty (dc, dv_ce_dtp[ch_dtp]);

	  if (chash_null_flag_dtps[ch_dtp] && !cha->cha_sqt[out_inx + n_keys].sqt_non_null
	      && CHA_IS_NULL (cha, is_cont, row, out_inx))
	    {
	      dc_append_null (dc);
	      n_values++;
	    }
	  else
	    {
	      switch (ch_dtp)
		{
		case DV_ANY:
		case DV_LONG_INT:
		case DV_DOUBLE_FLOAT:
		case DV_IRI_ID:
		  ((int64 *) dc->dc_values)[dc->dc_n_values++] = row[inx];
		  break;
		case DV_SINGLE_FLOAT:
		  ((int32 *) dc->dc_values)[dc->dc_n_values++] = *(int32 *) & ((int64 *) row)[inx];
		  break;
		case DV_DATETIME:
		  memcpy_dt (dc->dc_values + DT_LENGTH * dc->dc_n_values, ((db_buf_t *) row)[inx]);
		  dc->dc_n_values++;
		  break;
		default:
		  if (DCT_BOXES & dc->dc_type)
		    {
		      ((caddr_t *) dc->dc_values)[dc->dc_n_values++] = box_copy_tree (((caddr_t *) row)[inx]);
		      break;
		    }
		  GPF_T1 ("bad non-box out dc for chash join");
		}
	    }
	  out_inx++;
	}
      n_values = QST_INT (inst, hs->src_gen.src_out_fill)++;
      sets[n_values] = set;
      if (n_values == batch_sz)
	{
	  int64 next;
	  next = row[is_cont ? cont_next_ptr : cha->cha_next_ptr];
	  QST_BOX (ptrlong *, inst, hs->hs_current_inx) = (ptrlong *) next;
	  if (!next)
	    set++;
	  QST_INT (inst, hs->clb.clb_nth_set) = set;
	  SRC_IN_STATE (hs, inst) = inst;
	  qn_send_output ((data_source_t *) hs, inst);
	  QST_INT (inst, hs->src_gen.src_out_fill) = 0;
	  dc_reset_array (inst, (data_source_t *) hs, hs->src_gen.src_continue_reset, -1);
	  dc_reset_array (inst, (data_source_t *) hs, hs->hs_out_slots, -1);
	  batch_sz = QST_INT (inst, hs->src_gen.src_batch_size) - 1;
	  QN_CHECK_SETS (hs, inst, batch_sz + 1);
	  sets = QST_BOX (int *, inst, hs->src_gen.src_sets);
	  is_cont = 1;
	  row = QST_BOX (int64 *, inst, hs->hs_current_inx);
	  if (!row)
	    return;
	  continue;
	}
      else if ((row = (int64 *) row[is_cont ? cont_next_ptr : cha->cha_next_ptr]))
	{
	  is_cont = 1;
	  continue;
	}
      else
	return;
    }
}


void
cha_inline_result (hash_source_t * hs, chash_t * cha, caddr_t * inst, int64 * row, int rl)
{
  hash_area_t *ha = hs->hs_ha;
  int dep = ha->ha_n_keys;
  int n_dep = ha->ha_n_deps, n_keys = ha->ha_n_keys;
  int n_values = 0, inx, out_inx, rlc;
  out_inx = 0;
  for (inx = dep; inx < dep + n_dep; inx++)
    {
      dtp_t ch_dtp = cha->cha_sqt[out_inx + n_keys].sqt_dtp;
      state_slot_t *ssl = hs->hs_out_slots[out_inx];
      data_col_t *dc;
      if (!ssl)
	{
	  out_inx++;
	  continue;
	}
      dc = QST_BOX (data_col_t *, inst, ssl->ssl_index);
      n_values = dc->dc_n_values;
      if (!n_values && DV_ANY == dc->dc_sqt.sqt_col_dtp && DV_ANY != ch_dtp)
	dc_convert_empty (dc, dv_ce_dtp[ch_dtp]);
      else if (dc->dc_n_values >= dc->dc_n_places)
	return;			/* this is called from inside a predicate from itc_col_seg and there the scan may extend past the batch of values to return, so do not overflow the dc */
      if (chash_null_flag_dtps[ch_dtp] && !cha->cha_sqt[out_inx + n_keys].sqt_non_null && CHA_IS_NULL (cha, 0, row, out_inx))
	{
	  for (rlc = 0; rlc < rl; rlc++)
	    {
	      dc_append_null (dc);
	      n_values++;
	    }
	}
      else
	{
	  switch (ch_dtp)
	    {
	    case DV_ANY:
	    case DV_LONG_INT:
	    case DV_DOUBLE_FLOAT:
	    case DV_IRI_ID:
	      for (rlc = 0; rlc < rl; rlc++)
		((int64 *) dc->dc_values)[dc->dc_n_values++] = row[inx];
	      break;
	    case DV_SINGLE_FLOAT:
	      for (rlc = 0; rlc < rl; rlc++)
		((int32 *) dc->dc_values)[dc->dc_n_values++] = *(int32 *) & ((int64 *) row)[inx];
	      break;
	    case DV_DATETIME:
	      for (rlc = 0; rlc < rl; rlc++)
		{
		  memcpy_dt (dc->dc_values + DT_LENGTH * dc->dc_n_values, ((db_buf_t *) row)[inx]);
		  dc->dc_n_values++;
		}
	      break;
	    default:
	      if (DCT_BOXES & dc->dc_type)
		{
		  for (rlc = 0; rlc < rl; rlc++)
		    ((caddr_t *) dc->dc_values)[dc->dc_n_values++] = box_copy_tree (((caddr_t *) row)[inx]);
		  break;
		}
	      GPF_T1 ("bad non-box out dc for chash join");
	    }
	}
      out_inx++;
    }
}


int
cha_hs_cmp (hash_source_t * hs, caddr_t * inst, chash_t * cha, int set, int64 * row)
{
  int inx;
  DO_BOX (state_slot_t *, ref, inx, hs->hs_ref_slots)
  {
    data_col_t *dc = QST_BOX (data_col_t *, inst, ref->ssl_index);
    switch (dc->dc_dtp)
      {
      case DV_ANY:
	DV_EQ (((db_buf_t *) dc->dc_values)[set], (ptrlong) row[inx + 1], neq);
	break;
      neq:return 0;
      case DV_LONG_INT:
      case DV_IRI_ID:
      case DV_DOUBLE_FLOAT:
	if (((int64 *) dc->dc_values)[set] != row[inx + 1])
	  return 0;
	break;
      case DV_SINGLE_FLOAT:
	if (((int32 *) dc->dc_values)[set] != *(int32 *) & row[inx + 1])
	  return 0;
	break;
      case DV_DATETIME:
	memcmp_dt (dc->dc_values + set * DT_LENGTH, (db_buf_t) row[inx + 1], neq);
	break;
	break;
      }
  }
  END_DO_BOX;
  return 1;
}


#define SELF_PARTITION \
  char self_partition = hs->hs_partition_filter_self; \
  uint32 p_min = 0, p_max = 0xffffffff; \
  if (self_partition) {\
    p_min = QST_INT (inst, hs->hs_filler->fnr_hash_part_min); \
    p_max = QST_INT (inst, hs->hs_filler->fnr_hash_part_max); \
    if (0 == p_min && 0xffffffff == p_max) self_partition = 0; }

#define SELF_PARTITION_FILL \
  char self_partition = setp->setp_hash_part_filter == (data_source_t*)setp; \
  uint32 p_min = 0, p_max = 0xffffffff; \
  if (self_partition) {\
    p_min = QST_INT (inst, setp->setp_fref->fnr_hash_part_min); \
    p_max = QST_INT (inst, setp->setp_fref->fnr_hash_part_max); \
    if (0 == p_min && 0xffffffff == p_max) self_partition = 0; } \


void
hash_source_chash_input (hash_source_t * hs, caddr_t * inst, caddr_t * state)
{
  int n_sets, set;
  key_source_t *ks = hs->hs_ks;
  int64 *deps;
  chash_t *cha;
  int inx;
  hash_index_t *hi;
  hash_area_t *ha = hs->hs_ha;
  int batch_sz = QST_INT (inst, hs->src_gen.src_batch_size);
  index_tree_t *it = NULL;
  data_col_t *h_dc = QST_BOX (data_col_t *, inst, hs->hs_hash_no->ssl_index);
  int64 *hash_nos;
  SELF_PARTITION;
  QN_CHECK_SETS (hs, inst, batch_sz);
  it = (index_tree_t *) QST_GET_V (inst, ha->ha_tree);
  if (!it)
    return;
  hi = it->it_hi;
  cha = hi->hi_chash;
  if (state)
    {
      n_sets = QST_INT (inst, hs->src_gen.src_prev->src_out_fill);
      if (QST_INT (inst, hs->hs_done_in_probe) || hs->hs_merged_into_ts)
	{
	  int *sets;
	  SRC_IN_STATE (hs, inst) = NULL;
	  QST_INT (inst, hs->src_gen.src_out_fill) = n_sets;
	  sets = QST_BOX (int *, inst, hs->src_gen.src_sets);
	  int_asc_fill (sets, n_sets, 0);
	  if (hs->hs_ks->ks_last_vec_param)
	    ssl_consec_results (hs->hs_ks->ks_last_vec_param, inst, n_sets);
	  qn_send_output ((data_source_t *) hs, inst);
	  return;
	}
      dc_reset_array (inst, (data_source_t *) hs, hs->hs_out_slots, n_sets);
      QST_INT (inst, hs->clb.clb_nth_set) = 0;
      inst[hs->hs_current_inx] = NULL;
      ks_vec_params (ks, NULL, inst);
      if (ks->ks_last_vec_param)
	n_sets = QST_BOX (data_col_t *, inst, ks->ks_last_vec_param->ssl_index)->dc_n_values;
      else
	n_sets = QST_INT (inst, hs->src_gen.src_prev->src_out_fill);
      DC_CHECK_LEN (h_dc, n_sets - 1);
      if (cha->cha_is_1_int_key)
	{
	  hash_source_chash_input_1i (hs, inst, state);
	  return;
	}
      if (cha->cha_is_1_int)
	{
	  hash_source_chash_input_1i_n (hs, inst, state);
	  return;
	}

      hash_nos = (int64 *) h_dc->dc_values;
      for (inx = 0; inx < n_sets; inx++)
	hash_nos[inx] = 1;
      DO_BOX (state_slot_t *, ssl, inx, hs->hs_ref_slots)
      {
	data_col_t *dc = QST_BOX (data_col_t *, inst, ssl->ssl_index);
	chash_array ((int64 *) dc->dc_values, hash_nos, dc->dc_dtp, 0, n_sets, dc_elt_size (dc));
      }
      END_DO_BOX;
    }
  else
    {
      dc_reset_array (inst, (data_source_t *) hs, hs->hs_out_slots, -1);
      if (cha->cha_is_1_int_key)
	{
	  hash_source_chash_input_1i (hs, inst, state);
	  return;
	}
      if (cha->cha_is_1_int)
	{
	  hash_source_chash_input_1i_n (hs, inst, state);
	  return;
	}

      if (ks->ks_last_vec_param)
	n_sets = QST_BOX (data_col_t *, inst, ks->ks_last_vec_param->ssl_index)->dc_n_values;
      else
	n_sets = QST_INT (inst, hs->src_gen.src_prev->src_out_fill);
      hash_nos = (int64 *) h_dc->dc_values;
    }

  set = QST_INT (inst, hs->clb.clb_nth_set);
  if (set >= n_sets)
    {
      SRC_IN_STATE (hs, inst) = NULL;
      return;
    }
  QST_INT (inst, hs->src_gen.src_out_fill) = 0;
  deps = QST_BOX (int64 *, inst, hs->hs_current_inx);
  if (deps)
    {
      cha_results (hs, inst, cha, set, deps, 1);
      set++;
    }

#define CHA_P(cha, h) &cha->cha_partitions[h % cha->cha_n_partitions]
#define HIT(e) ((elt = e) && elt[0] == h && cha_hs_cmp (hs, inst, cha_p, set, elt))

#define HIT_N(n, e) ((elt = e) && elt[0] == h_##n && cha_hs_cmp (hs, inst, cha_p_##n, set + n - 1, elt))
#define HIT_N_E(n, e) HIT_N(n, e)




  if (self_partition)
    goto singles;
  for (set = set; set + 4 <= n_sets; set += 4)
    {
      int64 *elt, **array_1, **array_2, **array_3, **array_4;
      int pos1_1, pos2_1, pos1_2, pos2_2, pos1_3, pos2_3, pos1_4, pos2_4;
      chash_t *cha_p_1, *cha_p_2, *cha_p_3, *cha_p_4;
      uint64 h_1, h_2, h_3, h_4;

#undef CHA_PRE
#define CHA_PRE(n) \
      h_##n = hash_nos[set + n - 1];  \
      cha_p_##n = CHA_PARTITION(cha, h_##n);  \
      array_##n = cha_p_##n->cha_array; \
	  pos1_##n = CHA_POS_1 (cha_p_##n, h_##n); \
	  pos2_##n = CHA_POS_2 (cha_p_##n, h_##n); \


#define CHA_PREFETCH(n) (__builtin_prefetch (array_##n[pos1_##n]))

#define CHA_CK(n) \
      if (HIT_N (n, array_##n[pos1_##n]))	\
	    { \
	      cha_results (hs, inst, cha, set + n - 1, array_##n[pos1_##n], 0); \
	    } \
	  else if (HIT_N (n, array_##n[pos2_##n]))	\
	    { \
	      cha_results (hs, inst, cha, set + n - 1, array_##n[pos2_##n], 0); \
	    } \
	  else  \
	    { \
	      for (inx = 0; inx < cha_p_##n->cha_exception_fill; inx++) \
		{ \
		  if (HIT_N_E (n, cha_p_##n->cha_exceptions[inx])) \
		    { \
		      cha_results (hs, inst, cha, set + n - 1, cha_p_##n->cha_exceptions[inx], 0); \
		      break; \
		    } \
		} \
	    } \




      CHA_PRE (1);
      CHA_PRE (2);
      CHA_PREFETCH (2);
      CHA_PRE (3);
      CHA_PREFETCH (3);
      CHA_PRE (4);
      CHA_PREFETCH (4);

      CHA_CK (1);
      CHA_CK (2);
      CHA_CK (3);
      CHA_CK (4);
    }

singles:
  for (set = set; set < n_sets; set++)
    {
      int64 **array_1, *elt;
      chash_t *cha_p_1;
      uint64 h_1;
      int pos1_1, pos2_1;
      CHA_PRE (1);
      if (self_partition && !(p_min <= H_PART (hash_nos[inx]) && p_max >= H_PART (hash_nos[inx])))
	continue;
      CHA_CK (1);
    }
  SRC_IN_STATE (hs, inst) = NULL;
  if (QST_INT (inst, hs->src_gen.src_out_fill))
    {
      qn_send_output ((data_source_t *) hs, inst);
    }
}


#define CHAP_ENTER(cha_p) \
  {if (is_parallel)  mutex_enter (&cha_p->cha_mtx);}

#define CHAP_LEAVE(cha_p) \
  {if (is_parallel) { mutex_leave (&cha_p->cha_mtx);}}


void
setp_chash_fill (setp_node_t * setp, caddr_t * inst)
{
  index_tree_t *tree;
  hash_area_t *ha = setp->setp_ha;
  cha_cmp_t cmp = cha_cmp;
  chash_t *cha = NULL;
  QNCAST (query_instance_t, qi, inst);
  int n_sets = QST_INT (inst, setp->src_gen.src_prev->src_out_fill);
  int64 hash_no[ARTM_VEC_LEN];
  db_buf_t *key_vecs[CHASH_GB_MAX_KEYS];
  dtp_t temp[ARTM_VEC_LEN * CHASH_GB_MAX_KEYS * DT_LENGTH];
  dtp_t temp_any[9 * CHASH_GB_MAX_KEYS * ARTM_VEC_LEN];
  int first_set, set;
  char is_parallel;
  SELF_PARTITION_FILL;
  qi->qi_set = 0;
  tree = qst_tree (inst, ha->ha_tree, setp->setp_ssa.ssa_set_no);
  cha = tree->it_hi->hi_chash;
  if (cha->cha_is_1_int_key)
    {
      setp_chash_fill_1i (setp, inst);
      return;
    }
  if (cha->cha_is_1_int)
    {
      setp_chash_fill_1i_n (setp, inst);
      return;
    }
  is_parallel = cha->cha_is_parallel;
  if (CHA_ALWAYS_UNQ == cha->cha_unique)
    cmp = cha_cmp_unq_fill;
  for (first_set = 0; first_set < n_sets; first_set += ARTM_VEC_LEN)
    {
      int any_temp_fill = 0;
      int key;
      int last_set = MIN (first_set + ARTM_VEC_LEN, n_sets);
      for (key = 0; key < last_set - first_set; key++)
	hash_no[key] = 1;
      for (key = 0; key < ha->ha_n_keys; key++)
	{
	  key_vecs[key] =
	      (db_buf_t *) gb_values (cha, hash_no, inst, ha->ha_slots[key], key, first_set, last_set, (db_buf_t) temp, temp_any,
	      &any_temp_fill);
	}
      qi->qi_set = first_set;
      set = first_set;
      if (self_partition)
	goto singles;
      for (set = first_set; set + 4 <= last_set; set += 4)
	{
	  int inx = set - first_set, e;
	  chash_t *cha_p_1, *cha_p_2, *cha_p_3, *cha_p_4;
	  int64 **array_1, **array_2, **array_3, **array_4;
	  uint64 h_1, h_2, h_3, h_4;
	  int64 *ent;
	  int pos1_1, pos2_1, pos1_2, pos2_2, pos1_3, pos2_3, pos1_4, pos2_4;

#undef CHA_PRE
#define CHF_PRE(n) \
	  h_##n = hash_no[inx + n - 1]; \
	  cha_p_##n = CHA_PARTITION (cha, h_##n); \
	  __builtin_prefetch (&cha_p_##n->cha_current->h.h.chp_fill); \
	  array_##n = cha_p_##n->cha_array; \
	  pos1_##n = CHA_POS_1 (cha_p_##n, h_##n); \
	  pos2_##n = CHA_POS_2 (cha_p_##n, h_##n);

	  CHF_PRE (1);
	  CHF_PRE (2);
	  CHA_PREFETCH (2);
	  CHF_PRE (3);
	  CHA_PREFETCH (3);
	  CHF_PRE (4);
	  CHA_PREFETCH (4);

#define CHF_CK(n, f)		     \
	  CHAP_ENTER (cha_p_##n); \
	  ent = array_##n[pos1_##n]; \
	  if (!ent) \
	    { \
	      cha->cha_distinct_count++; \
	      cha_add_row (setp, inst, key_vecs, cha_p_##n, h_##n, pos1_##n, inx + n - 1, NULL); \
	      goto done_##n##f; \
	    } \
	  if (h_##n == *ent && cmp (cha, ent, key_vecs, inx + n -1)) \
	  { \
	    cha_add_row (setp, inst, key_vecs, cha_p_##n, h_##n, pos1_##n, inx + n - 1, ent); \
	    goto done_##n##f; \
	  } \
	  ent = array_##n[pos2_##n]; \
	  if (!ent) \
	    { \
	      cha->cha_distinct_count++; \
	      cha_add_row (setp, inst, key_vecs, cha_p_##n, h_##n, pos2_##n, inx + n - 1, NULL); \
	      goto done_##n##f; \
	    } \
	  if (h_##n == *ent && cmp (cha, ent, key_vecs, inx + n -1)) \
	    {								\
	      cha_add_row (setp, inst, key_vecs, cha_p_##n, h_##n, 0, inx + n - 1, ent); \
	      goto done_##n##f;						\
	    } \
	  for (e = 0; e < cha_p_##n->cha_exception_fill; e++) \
	    { \
	      int64 * ent = ((int64**)cha_p_##n->cha_exceptions)[e]; \
	      if (h_##n == ent[0] && cmp (cha, ent, key_vecs, inx + n - 1)) \
		{ \
		  cha_add_row (setp, inst, key_vecs, cha_p_##n, h_##n, 0, inx + n - 1, ent); \
		  goto done_##n##f; \
		} \
	    } \
	  cha->cha_distinct_count++; \
	  cha_add_row (setp, inst, key_vecs, cha_p_##n, h_##n, -1, inx + n - 1, NULL); \
	done_##n##f : ;  \
	  CHAP_LEAVE (cha_p_##n);

	  CHF_CK (1, f);
	  CHF_CK (2, f);
	  CHF_CK (3, f);
	  CHF_CK (4, f);
	}
    singles:
      for (set = set; set < last_set; set++)
	{
	  int inx = set - first_set, e, pos1_1, pos2_1;
	  uint64 h_1;
	  chash_t *cha_p_1;
	  int64 **array_1;
	  int64 *ent;
	  CHF_PRE (1);
	  if (self_partition && !(p_min <= H_PART (h_1) && p_max >= H_PART (h_1)))
	    continue;
	  CHF_CK (1, ff);
	}
    }
  if (cha->cha_n_partitions)
    cha->cha_count += n_sets;
  /* the count and distinct count comparison is not thread safe.  Can be that a unq is set to non-unq.  Prevent this for one known to be unq from schema since this does not have a next pointer in the dependent part.  The loss of sometimes marknig a happens-to-be unq as non-unq is ok */
  if (cha->cha_count != cha->cha_distinct_count && CHA_ALWAYS_UNQ != cha->cha_unique)
    cha->cha_unique = CHA_NON_UNQ;
}

void
hash_source_chash_input_1i (hash_source_t * hs, caddr_t * inst, caddr_t * state)
{
  int n_sets, set;
  key_source_t *ks = hs->hs_ks;
  int64 *deps;
  chash_t *cha;
  int inx;
  hash_index_t *hi;
  hash_area_t *ha = hs->hs_ha;
  index_tree_t *it = NULL;
  int64 *data;
  SELF_PARTITION;
  it = (index_tree_t *) QST_GET_V (inst, ha->ha_tree);
  hi = it->it_hi;
  cha = hi->hi_chash;
  if (ks->ks_last_vec_param)
    n_sets = QST_BOX (data_col_t *, inst, ks->ks_last_vec_param->ssl_index)->dc_n_values;
  else
    n_sets = QST_INT (inst, hs->src_gen.src_prev->src_out_fill);
  data = (int64 *) QST_BOX (data_col_t *, inst, hs->hs_ref_slots[0]->ssl_index)->dc_values;
  set = QST_INT (inst, hs->clb.clb_nth_set);
  if (set >= n_sets)
    {
      SRC_IN_STATE (hs, inst) = NULL;
      return;
    }
  QST_INT (inst, hs->src_gen.src_out_fill) = 0;
  deps = QST_BOX (int64 *, inst, hs->hs_current_inx);
  if (deps)
    {
      cha_results (hs, inst, cha, set, deps, 1);
      set++;
    }

#undef HIT_N
#undef HIT_N_E

#define HIT_N(n, e) ((elt = e)  && elt[0] == data_##n)
#define HIT_N_E(n, e) HIT_N(n, e)



  if (self_partition)
    goto singles;
  for (set = set; set + 4 <= n_sets; set += 4)
    {
      int64 data_1, data_2, data_3, data_4;
      int64 *elt, **array_1, **array_2, **array_3, **array_4;
      int pos1_1, pos2_1, pos1_2, pos2_2, pos1_3, pos2_3, pos1_4, pos2_4;
      chash_t *cha_p_1, *cha_p_2, *cha_p_3, *cha_p_4;
      uint64 h_1, h_2, h_3, h_4;

#undef CHA_PRE
#define CHA_PRE(n) \
      data_##n = data[set + n - 1]; \
      h_##n = 1; MHASH_STEP (h_##n, data_##n); \
      cha_p_##n = CHA_PARTITION(cha, h_##n);  \
      array_##n = cha_p_##n->cha_array; \
	  pos1_##n = CHA_POS_1 (cha_p_##n, h_##n); \
	  pos2_##n = CHA_POS_2 (cha_p_##n, h_##n); \


      CHA_PRE (1);
      CHA_PRE (2);
      CHA_PREFETCH (2);
      CHA_PRE (3);
      CHA_PREFETCH (3);
      CHA_PRE (4);
      CHA_PREFETCH (4);

      CHA_CK (1);
      CHA_CK (2);
      CHA_CK (3);
      CHA_CK (4);
    }

singles:
  for (set = set; set < n_sets; set++)
    {
      int64 **array_1, *elt;
      chash_t *cha_p_1;
      uint64 h_1;
      int64 data_1;
      int pos1_1, pos2_1;
      CHA_PRE (1);
      if (self_partition && !(p_min <= H_PART (h_1) && p_max >= H_PART (h_1)))
	continue;
      CHA_CK (1);
    }
  SRC_IN_STATE (hs, inst) = NULL;
  if (QST_INT (inst, hs->src_gen.src_out_fill))
    {
      qn_send_output ((data_source_t *) hs, inst);
    }
  SRC_IN_STATE (hs, inst) = NULL;
}


void
setp_chash_fill_1i (setp_node_t * setp, caddr_t * inst)
{
  index_tree_t *tree;
  hash_area_t *ha = setp->setp_ha;
  chash_t *cha = NULL;
  char is_parallel;
  QNCAST (query_instance_t, qi, inst);
  int n_sets = QST_INT (inst, setp->src_gen.src_prev->src_out_fill);
  int64 *data;
  int64 hash_no[ARTM_VEC_LEN];
  db_buf_t *key_vecs[1];
  int64 temp[ARTM_VEC_LEN * CHASH_GB_MAX_KEYS];
  dtp_t temp_any[9 * CHASH_GB_MAX_KEYS * ARTM_VEC_LEN];
  int first_set, set;
  SELF_PARTITION_FILL;
  qi->qi_set = 0;
  tree = qst_tree (inst, ha->ha_tree, setp->setp_ssa.ssa_set_no);
  cha = tree->it_hi->hi_chash;
  is_parallel = cha->cha_is_parallel;
  for (first_set = 0; first_set < n_sets; first_set += ARTM_VEC_LEN)
    {
      int any_temp_fill = 0;
      int key;
      int last_set = MIN (first_set + ARTM_VEC_LEN, n_sets);
      for (key = 0; key < last_set - first_set; key++)
	hash_no[key] = 1;
      for (key = 0; key < ha->ha_n_keys; key++)
	{
	  key_vecs[key] =
	      (db_buf_t *) gb_values (cha, hash_no, inst, ha->ha_slots[key], key, first_set, last_set, (db_buf_t) temp, temp_any,
	      &any_temp_fill);
	}
      data = (int64 *) key_vecs[0];
      qi->qi_set = first_set;
      set = first_set;
      if (self_partition)
	goto singles;
      for (set = first_set; set + 4 <= last_set; set += 4)
	{
	  int inx = set - first_set, e;
	  chash_t *cha_p_1, *cha_p_2, *cha_p_3, *cha_p_4;
	  int64 **array_1, **array_2, **array_3, **array_4;
	  uint64 h_1, h_2, h_3, h_4;
	  int64 *ent, data_1, data_2, data_3, data_4;
	  int pos1_1, pos2_1, pos1_2, pos2_2, pos1_3, pos2_3, pos1_4, pos2_4;

#undef CHF_PRE
#define CHF_PRE(n) \
	  data_##n = data[inx + n - 1]; \
	  h_##n = hash_no[inx + n - 1]; \
	  cha_p_##n = CHA_PARTITION (cha, h_##n); \
	  __builtin_prefetch (&cha_p_##n->cha_current->h.h.chp_fill); \
	  array_##n = cha_p_##n->cha_array; \
	  pos1_##n = CHA_POS_1 (cha_p_##n, h_##n); \
	  pos2_##n = CHA_POS_2 (cha_p_##n, h_##n);

	  CHF_PRE (1);
	  CHF_PRE (2);
	  CHA_PREFETCH (2);
	  CHF_PRE (3);
	  CHA_PREFETCH (3);
	  CHF_PRE (4);
	  CHA_PREFETCH (4);

#undef CHF_CK
#define CHF_CK(n, f)		     \
	  CHAP_ENTER (cha_p_##n); \
	  ent = array_##n[pos1_##n]; \
	  if (!ent) \
	    { \
	      cha->cha_distinct_count++; \
	      cha_add_row (setp, inst, key_vecs, cha_p_##n, h_##n, pos1_##n, inx + n - 1, NULL); \
	      goto done_##n##f; \
	    } \
	  if (data_##n == *ent) \
	  { \
	    cha_add_row (setp, inst, key_vecs, cha_p_##n, h_##n, pos1_##n, inx + n - 1, ent); \
	    goto done_##n##f; \
	  } \
	  ent = array_##n[pos2_##n]; \
	  if (!ent) \
	    { \
	      cha->cha_distinct_count++; \
	      cha_add_row (setp, inst, key_vecs, cha_p_##n, h_##n, pos2_##n, inx + n - 1, NULL); \
	      goto done_##n##f; \
	    } \
	  if (data_##n == *ent) \
	    {								\
	      cha_add_row (setp, inst, key_vecs, cha_p_##n, h_##n, 0, inx + n - 1, ent); \
	      goto done_##n##f;						\
	    } \
	  for (e = 0; e < cha_p_##n->cha_exception_fill; e++) \
	    { \
	      int64 * ent = ((int64**)cha_p_##n->cha_exceptions)[e]; \
	      if (data_##n == ent[0]) \
		{ \
		  cha_add_row (setp, inst, key_vecs, cha_p_##n, h_##n, 0, inx + n - 1, ent); \
		  goto done_##n##f; \
		} \
	    } \
	  cha->cha_distinct_count++; \
	  cha_add_row (setp, inst, key_vecs, cha_p_##n, h_##n, -1, inx + n - 1, NULL); \
	done_##n##f : ; \
	  CHAP_LEAVE (cha_p_##n);

	  CHF_CK (1, f);
	  CHF_CK (2, f);
	  CHF_CK (3, f);
	  CHF_CK (4, f);
	}
    singles:
      for (set = set; set < last_set; set++)
	{
	  int inx = set - first_set, e, pos1_1, pos2_1;
	  uint64 h_1;
	  int64 data_1;
	  chash_t *cha_p_1;
	  int64 **array_1;
	  int64 *ent;
	  CHF_PRE (1);
	  if (self_partition && !(p_min <= H_PART (h_1) && p_max >= H_PART (h_1)))
	    continue;
	  CHF_CK (1, ff);
	}
    }
  if (cha->cha_n_partitions)
    cha->cha_count += n_sets;
  if (cha->cha_count != cha->cha_distinct_count && CHA_ALWAYS_UNQ != cha->cha_unique)
    cha->cha_unique = CHA_NON_UNQ;
}

/* for the single int unq hash, the result just marks the set no in the sets */

#define   cha_results(hs, inst, cha, set, array, ff) \
  { sets[QST_INT (inst, hs->src_gen.src_out_fill)++] = set; }


void
hash_source_chash_input_1i_n (hash_source_t * hs, caddr_t * inst, caddr_t * state)
{
  int n_sets, set;
  key_source_t *ks = hs->hs_ks;
  chash_t *cha;
  int inx;
  hash_index_t *hi;
  hash_area_t *ha = hs->hs_ha;
  int *sets = QST_BOX (int *, inst, hs->src_gen.src_sets);
  index_tree_t *it = NULL;
  int64 *data;
  SELF_PARTITION;
  it = (index_tree_t *) QST_GET_V (inst, ha->ha_tree);
  hi = it->it_hi;
  cha = hi->hi_chash;

  if (ks->ks_last_vec_param)
    n_sets = QST_BOX (data_col_t *, inst, ks->ks_last_vec_param->ssl_index)->dc_n_values;
  else
    n_sets = QST_INT (inst, hs->src_gen.src_prev->src_out_fill);
  data = (int64 *) QST_BOX (data_col_t *, inst, hs->hs_ref_slots[0]->ssl_index)->dc_values;
  set = QST_INT (inst, hs->clb.clb_nth_set);
  if (set >= n_sets)
    {
      SRC_IN_STATE (hs, inst) = NULL;
      return;
    }
  QST_INT (inst, hs->src_gen.src_out_fill) = 0;

#undef HIT_N
#undef HIT_N_E
#define HIT_N(n, e) ( (int64)(e) == data_##n && CHA_EMPTY != data_##n)
#define HIT_N_E(n, e) ( (int64)(ptrlong)e == data_##n)


  if (self_partition)
    goto singles;
  for (set = set; set + 4 <= n_sets; set += 4)
    {
      int64 data_1, data_2, data_3, data_4;
      int64 *array_1, *array_2, *array_3, *array_4;
      int pos1_1, pos2_1, pos1_2, pos2_2, pos1_3, pos2_3, pos1_4, pos2_4;
      chash_t *cha_p_1, *cha_p_2, *cha_p_3, *cha_p_4;
      uint64 h_1, h_2, h_3, h_4;

#undef CHA_PRE
#define CHA_PRE(n) \
      data_##n = data[set + n - 1]; \
      h_##n = 1; MHASH_STEP (h_##n, data_##n); \
      cha_p_##n = CHA_PARTITION(cha, h_##n);  \
      array_##n = (int64*)cha_p_##n->cha_array;	   \
	  pos1_##n = CHA_POS_1 (cha_p_##n, h_##n); \
	  pos2_##n = CHA_POS_2 (cha_p_##n, h_##n); \


      CHA_PRE (1);
      CHA_PRE (2);
      __builtin_prefetch (&array_2[pos1_2]);
      CHA_PRE (3);
      __builtin_prefetch (&array_3[pos1_3]);
      CHA_PRE (4);
      __builtin_prefetch (&array_4[pos1_4]);

      CHA_CK (1);
      CHA_CK (2);
      CHA_CK (3);
      CHA_CK (4);
    }

singles:
  for (set = set; set < n_sets; set++)
    {
      int64 *array_1;
      chash_t *cha_p_1;
      uint64 h_1;
      int64 data_1;
      int pos1_1, pos2_1;
      CHA_PRE (1);
      if (self_partition && !(p_min <= H_PART (h_1) && p_max >= H_PART (h_1)))
	continue;
      CHA_CK (1);
    }
  SRC_IN_STATE (hs, inst) = NULL;
  if (QST_INT (inst, hs->src_gen.src_out_fill))
    {
      qn_send_output ((data_source_t *) hs, inst);
    }
}

#undef cha_results



void
cha_add_1_int (setp_node_t * setp, caddr_t * inst, chash_t * cha_p, uint64 h, int64 data)
{
  if (data == CHA_EMPTY)
    {
      mp_array_add (cha_p->cha_pool, (caddr_t **) & cha_p->cha_exceptions, &cha_p->cha_exception_fill, (caddr_t) data);
      return;
    }
  if (cha_relocate (cha_p, h, (int64 *) (ptrlong) data))
    return;
  mp_array_add (cha_p->cha_pool, (caddr_t **) & cha_p->cha_exceptions, &cha_p->cha_exception_fill, (caddr_t) data);
}


void
cha_1_int_non_unq (setp_node_t * setp, caddr_t * inst, int set)
{
  GPF_T1 ("not impl. Must convert 1 int chash into generic chash");
}

void
setp_chash_fill_1i_n (setp_node_t * setp, caddr_t * inst)
{
  index_tree_t *tree;
  hash_area_t *ha = setp->setp_ha;
  chash_t *cha = NULL;
  QNCAST (query_instance_t, qi, inst);
  int n_sets = QST_INT (inst, setp->src_gen.src_prev->src_out_fill);
  int64 *data;
  int64 hash_no[ARTM_VEC_LEN];
  db_buf_t *key_vecs[1];
  int64 temp[ARTM_VEC_LEN * CHASH_GB_MAX_KEYS];
  dtp_t temp_any[9 * CHASH_GB_MAX_KEYS * ARTM_VEC_LEN];
  int first_set, set;
  char is_parallel;
  SELF_PARTITION_FILL;
  qi->qi_set = 0;
  tree = qst_tree (inst, ha->ha_tree, setp->setp_ssa.ssa_set_no);
  cha = tree->it_hi->hi_chash;
  is_parallel = cha->cha_is_parallel;
  for (first_set = 0; first_set < n_sets; first_set += ARTM_VEC_LEN)
    {
      int any_temp_fill = 0;
      int key;
      int last_set = MIN (first_set + ARTM_VEC_LEN, n_sets);
      for (key = 0; key < last_set - first_set; key++)
	hash_no[key] = 1;
      for (key = 0; key < ha->ha_n_keys; key++)
	{
	  key_vecs[key] =
	      (db_buf_t *) gb_values (cha, hash_no, inst, ha->ha_slots[key], key, first_set, last_set, (db_buf_t) temp, temp_any,
	      &any_temp_fill);
	}
      data = (int64 *) key_vecs[0];
      qi->qi_set = first_set;
      set = first_set;
      if (self_partition)
	goto singles;
      for (set = first_set; set + 4 <= last_set; set += 4)
	{
	  int inx = set - first_set, e;
	  chash_t *cha_p_1, *cha_p_2, *cha_p_3, *cha_p_4;
	  int64 *array_1, *array_2, *array_3, *array_4;
	  uint64 h_1, h_2, h_3, h_4;
	  int64 ent, data_1, data_2, data_3, data_4;
	  int pos1_1, pos2_1, pos1_2, pos2_2, pos1_3, pos2_3, pos1_4, pos2_4;

#undef CHF_PRE
#define CHF_PRE(n) \
	  data_##n = data[inx + n - 1]; \
	  h_##n = hash_no[inx + n - 1]; \
	  cha_p_##n = CHA_PARTITION (cha, h_##n); \
	  array_##n = (int64*)cha_p_##n->cha_array;	\
	  pos1_##n = CHA_POS_1 (cha_p_##n, h_##n); \
	  pos2_##n = CHA_POS_2 (cha_p_##n, h_##n);

#undef CHA_PREFETCH
#define CHA_PREFETCH(n) __builtin_prefetch (&array_##n[pos1_##n])


	  CHF_PRE (1);
	  CHF_PRE (2);
	  CHA_PREFETCH (2);
	  CHF_PRE (3);
	  CHA_PREFETCH (3);
	  CHF_PRE (4);
	  CHA_PREFETCH (4);

#undef CHF_CK
#define CHF_CK(n, f) \
	  {					       \
	    CHAP_ENTER (cha_p_##n); \
	  if (data_##n == CHA_EMPTY) goto exc_##n##f; \
	  ent = array_##n[pos1_##n]; \
	  if (CHA_EMPTY == ent ) \
	    { \
	      cha->cha_distinct_count++; \
	      array_##n[pos1_##n] = data_##n; \
	      goto done_##n##f; \
	    } \
	  if (data_##n == ent) \
	  { \
	    cha_1_int_non_unq (setp, inst, inx); \
	    return; \
	  } \
	  ent = array_##n[pos2_##n]; \
	  if (CHA_EMPTY == ent) \
	    { \
	      cha->cha_distinct_count++; \
	      array_##n[pos2_##n] = data_##n; \
	      goto done_##n##f; \
	    } \
	  if (data_##n == ent) \
	    {								\
	      cha_1_int_non_unq (setp, inst, set); \
	      return; \
	    } \
    exc_##n##f:						      \
	  for (e = 0; e < cha_p_##n->cha_exception_fill; e++) \
	    { \
	      int64  ent = ((int64*)cha_p_##n->cha_exceptions)[e]; \
	      if (data_##n == ent) \
		{ \
		  cha_1_int_non_unq (setp, inst, set); \
		  return; \
		} \
	    } \
	  cha->cha_distinct_count++; \
	  cha_add_1_int (setp, inst, cha_p_##n, h_##n, data_##n); \
    done_##n##f : ; \
	  CHAP_LEAVE (cha_p_##n); }

	  CHF_CK (1, f);
	  CHF_CK (2, f);
	  CHF_CK (3, f);
	  CHF_CK (4, f);
	}
    singles:
      for (set = set; set < last_set; set++)
	{
	  int inx = set - first_set, e, pos1_1, pos2_1;
	  uint64 h_1;
	  int64 data_1;
	  chash_t *cha_p_1;
	  int64 *array_1;
	  int64 ent;
	  CHF_PRE (1);
	  if (self_partition && !(p_min <= H_PART (h_1) && p_max >= H_PART (h_1)))
	    continue;
	  CHF_CK (1, ff);
	}
    }
  if (cha->cha_n_partitions)
    cha->cha_count += n_sets;
}


int
itc_hash_compare (it_cursor_t * itc, buffer_desc_t * buf, search_spec_t * sp)
{
  QNCAST (hash_range_spec_t, hrng, sp->sp_min_ssl);
  caddr_t *inst = itc->itc_out_state;
  hash_source_t *hs = hrng->hrng_hs;
  uint32 min, max, l;
  int pos1_1, pos2_1, e;
  int64 **array, k, *ent;
  chash_t *cha_p;
  uint64 h = 1;
  caddr_t box;
  caddr_t box2 = NULL, err = NULL;
  if (!buf)
    box = box_iri_int64 (itc->itc_bp.bp_value, sp->sp_cl.cl_sqt.sqt_dtp);
  else
    box = itc_box_column (itc, buf, 0, &sp->sp_cl);
  switch (sp->sp_cl.cl_sqt.sqt_dtp)
    {
    case DV_SHORT_INT:
    case DV_LONG_INT:
    case DV_INT64:
    case DV_IRI_ID:
    case DV_IRI_ID_8:
 /* case DV_DOUBLE_FLOAT:*/
      k = IS_BOX_POINTER (box) ? *(int64 *) box : (int64) (ptrlong) box;
      MHASH_STEP (h, k);
      break;
    case DV_SINGLE_FLOAT:
      MHASH_STEP (h, *(int32 *) box);
      break;
    case DV_DATETIME:
    case DV_DATE:
    case DV_TIME:
    case DV_TIMESTAMP:
      MHASH_VAR (h, box, DT_COMPARE_LENGTH);
      break;
    default:;
      box2 = box_to_any (box, &err);
      l = box_length (box2) - 1;
      MHASH_VAR (h, box2, l);
      break;
    }
  min = QST_INT (inst, hrng->hrng_min);
  max = QST_INT (inst, hrng->hrng_max);
  if (!(min <= H_PART (h) && max >= H_PART (h)))
    {
      dk_free_tree (box);
      return DVC_LESS;
    }
  if (hs && sp->sp_max_op != CMP_HASH_RANGE_ONLY)
    {
      index_tree_t *tree = QST_BOX (index_tree_t *, inst, hs->hs_ha->ha_tree->ssl_index);
      chash_t *cha;
      if (!tree)
	goto not_found;
      cha = tree->it_hi->hi_chash;
      cha_p = CHA_PARTITION (cha, h);
      array = cha_p->cha_array;
      pos1_1 = CHA_POS_1 (cha_p, h);
      pos2_1 = CHA_POS_2 (cha_p, h);
      if (cha->cha_is_1_int)
	{
	  k = IS_BOX_POINTER (box) ? *(int64 *) box : (ptrlong) box;
	  if (CHA_EMPTY == k)
	    goto exc;
	  if (k == ((int64 *) array)[pos1_1])
	    goto found;
	  if (k == ((int64 *) array)[pos2_1])
	    goto found;
	exc:
	  for (e = 0; e < cha_p->cha_exception_fill; e++)
	    {
	      if (k == ((int64 *) cha_p->cha_exceptions)[e])
		goto found;
	    }
	  goto not_found;
	}
      if (cha->cha_is_1_int_key)
	{
	  k = IS_BOX_POINTER (box) ? *(int64 *) box : (ptrlong) box;
	  ent = array[pos1_1];
	  if (ent && k == ent[0])
	    goto found_e;
	  ent = array[pos2_1];
	  if (ent && k == ent[0])
	    goto found_e;
	  for (e = 0; e < cha_p->cha_exception_fill; e++)
	    {
	      ent = cha_p->cha_exceptions[e];
	      if (k == ent[0])
		goto found_e;
	    }
	  goto not_found;
	found_e:
	  if (hs->hs_ha->ha_n_deps)
	    cha_inline_result (hs, cha, inst, ent, 1);
	  goto found;
	}
    }
  else
    goto found;
not_found:
  dk_free_tree (box);
  return DVC_LESS;
found:
  dk_free_tree (box);
  return DVC_MATCH;
}


int
ce_int_chash_check (col_pos_t * cpo, db_buf_t val, dtp_t flags, int64 offset, int rl)
{
  caddr_t *inst;
  hash_source_t *hs;
  uint64 h = 1;
  int64 **array, k;
  int pos1_1, pos2_1, e;
  chash_t *cha_p;
  chash_t *cha = cpo->cpo_chash;
  dtp_t cha_dtp = cpo->cpo_chash_dtp;
  if (CET_ANY == (flags & CE_DTP_MASK))
    {
      dtp_t val_dtp = dtp_canonical[*val];
      if (val_dtp != cha_dtp)
	goto filter_done;
      k = dv_int (val, &val_dtp) + offset;
    }
  else
    {
      if (DV_IRI_ID == cha_dtp && !(flags & CE_IS_IRI))
	goto filter_done;
      if (DV_LONG_INT == cha_dtp && (flags & CE_IS_IRI))
	goto filter_done;
      k = offset;
    }
  MHASH_STEP (h, k);
  if (!(cpo->cpo_hash_min <= H_PART (h) && cpo->cpo_hash_max >= H_PART (h)))
    return 0;
  if (CMP_HASH_RANGE_ONLY == cpo->cpo_max_op)
    return 1;
  cha_p = CHA_PARTITION (cha, h);
  array = cha_p->cha_array;
  pos1_1 = CHA_POS_1 (cha_p, h);
  pos2_1 = CHA_POS_2 (cha_p, h);
  if (cha->cha_is_1_int)
    {
      if (CHA_EMPTY == k)
	goto exc;
      if (k == ((int64 *) array)[pos1_1])
	goto found;
      if (k == ((int64 *) array)[pos2_1])
	goto found;
    exc:
      for (e = 0; e < cha_p->cha_exception_fill; e++)
	{
	  if (k == ((int64 *) cha_p->cha_exceptions)[e])
	    goto found;
	}
      goto filter_done;
    }
  if (cha->cha_is_1_int_key)
    {
      int64 *ent = array[pos1_1];
      if (ent && k == ent[0])
	goto found_e;
      ent = array[pos2_1];
      if (ent && k == ent[0])
	goto found_e;
      for (e = 0; e < cha_p->cha_exception_fill; e++)
	{
	  ent = cha_p->cha_exceptions[e];
	  if (k == ent[0])
	    goto found_e;
	}
      goto filter_done;
    found_e:
      hs = (hash_source_t *) cpo->cpo_cmp_max;
      inst = cpo->cpo_itc->itc_out_state;
      if (hs->hs_ha->ha_n_deps)
	cha_inline_result (hs, cha, inst, ent, rl);
      goto found;
    }
filter_done:
  return 0;
found:
  return 1;
}




int
sctr_hash_range_check (caddr_t * inst, search_spec_t * sp)
{
  /* calculate a hash no and see if it is in range of partition.  Not done often, normally filetered at the source */
  uint64 h = 1;
  QNCAST (hash_range_spec_t, hrng, sp->sp_min_ssl);
  int inx;
  uint32 min = QST_INT (inst, hrng->hrng_min);
  uint32 max = QST_INT (inst, hrng->hrng_max);
  if (0 == min && 0xffffffff == max)
    return 1;
  DO_BOX (state_slot_t *, ssl, inx, hrng->hrng_ssls)
  {
    caddr_t val = qst_get (inst, ssl);
    dtp_t dtp = DV_TYPE_OF (val);
    if (DV_LONG_INT == dtp || DV_IRI_ID == dtp)
      {
	int64 i = unbox_iri_int64 (val);
	MHASH_STEP (h, i);
      }
    else
      sqlr_new_error ("42000", "VEC..", "hash partitioning outer check for non-int, non-iri data not supported");
  }
  END_DO_BOX;
  return (min <= H_PART (h) && max >= H_PART (h));
}


int
cha_count (chash_t * cha)
{
  dk_hash_t *ht = hash_table_allocate (100000);
  int nxt = cha->cha_next_ptr - ((cha->cha_first_len - cha->cha_next_len) / sizeof (int64));
  int p, inx, dist = 0, ctr = 0, dups = 0, tail_dups = 0;
  for (p = 0; p < cha->cha_n_partitions; p++)
    {
      chash_t *cha_p = &cha->cha_partitions[p];
      for (inx = 0; inx < cha_p->cha_size; inx++)
	{
	  int64 *ent = cha_p->cha_array[inx];
	  if (ent)
	    {
	      if (gethash ((void *) ent, ht))
		dups++;
	      sethash ((void *) ent, ht, (void *) ent);
	      dist++;
	      ctr++;
	      if (cha->cha_next_ptr)
		{
		  int64 *next = (int64 *) ent[cha->cha_next_ptr];
		  while (next)
		    {
		      if (gethash ((void *) next, ht))
			tail_dups++;
		      sethash ((void *) next, ht, (void *) next);
		      ctr++;
		      next = (int64 *) next[nxt];
		    }
		}
	    }
	}
    }
  printf ("%d distinct %d head dups %d tail dups\n", dist, dups, tail_dups);
  hash_table_free (ht);
  return ctr;
}


search_spec_t *
sp_copy (search_spec_t * sp)
{
  NEW_VAR (search_spec_t, cp);
  memcpy (cp, sp, sizeof (search_spec_t));
  return cp;
}


#define IS_PARTITIONED(inst, hrng) \
  (QST_INT (inst, hrng->hrng_min) != 0 || (uint32)QST_INT (inst, hrng->hrng_max) != (uint32)0xffffffff)

int
ks_add_hash_spec (key_source_t * ks, caddr_t * inst, it_cursor_t * itc)
{
  /* if hash range or hash exists spec, add the spec to row specs.  A known unique hash source that produces a value can be added as last.  */
  search_spec_t **copy, *sp_copy_1 = NULL, *sp;
  int fill = 0, inx, best, best_deps, range_only;
  int64 best_sz;
  search_spec_t *sps[256];
  if (itc->itc_hash_row_spec)
    return 0;
  DO_SET (search_spec_t *, sp, &ks->ks_hash_spec)
  {
    hash_range_spec_t *hrng = (hash_range_spec_t *) sp->sp_min_ssl;
    if (!hrng->hrng_hs && 0 == QST_INT (inst, hrng->hrng_min) && 0xffffffff == (uint32) QST_INT (inst, hrng->hrng_max))
      continue;			/* no partition, no merged hash join */
    sps[fill++] = sp;
    if (fill > 255)
      sqlr_new_error ("420000", "CHA..", "Not more than 255 hash joins allowed per fact table");
  }
  END_DO_SET ();
  if (!fill)
    {
      itc->itc_hash_row_spec = RSP_CHECKED;
      return 0;
    }
  copy = &sp_copy_1;
  for (sp = itc->itc_row_specs; sp; sp = sp->sp_next)
    {
      *copy = sp_copy (sp);
      copy = &(*copy)->sp_next;
    }
  do
    {
      best = -1;
      best_deps = 0;
      range_only = 0;
      for (inx = 0; inx < fill; inx++)
	{
	  index_tree_t *tree;
	  chash_t *cha;
	  hash_source_t *hs;
	  hash_range_spec_t *hrng;
	  if (!sps[inx])
	    continue;
	  hrng = (hash_range_spec_t *) sps[inx]->sp_min_ssl;
	  hs = hrng->hrng_hs;
	  if (!hs)
	    {
	      best = inx;
	      break;
	    }
	  tree = QST_BOX (index_tree_t *, inst, hrng->hrng_hs->hs_ha->ha_tree->ssl_index);
	  cha = tree->it_hi->hi_chash;
	  if (!cha->cha_distinct_count)
	    {
	      /* join with empty chash is like null in search params, always empty */
	      key_free_trail_specs (sp_copy_1);
	      return 1;
	    }
	  if ((!hs->hs_merged_into_ts && CHA_NON_UNQ == cha->cha_unique) || hs->hs_is_outer)
	    {
	      if (IS_PARTITIONED (inst, hrng))
		{
		  best = inx;
		  range_only = 1;
		  break;
		}
	      sps[inx] = NULL;
	      QST_INT (inst, hs->hs_done_in_probe) = 0;
	      continue;
	    }
	  else if (hs->hs_done_in_probe)
	    QST_INT (inst, hs->hs_done_in_probe) = 1;
	  if (-1 == best || best_deps || cha->cha_distinct_count < best_sz)
	    {
	      best = inx;
	      best_deps = hs->hs_ha->ha_n_deps;
	      best_sz = cha->cha_distinct_count;
	    }
	}
      if (-1 != best)
	{
	  *copy = sp_copy (sps[best]);
	  if (range_only)
	    (*copy)->sp_max_op = CMP_HASH_RANGE_ONLY;
	  copy = &(*copy)->sp_next;
	  sps[best] = NULL;
	}
    }
  while (best != -1);
  itc->itc_row_specs = sp_copy_1;
  itc->itc_hash_row_spec = RSP_CHANGED;
  return 0;
}


int
fref_hash_partitions_left (fun_ref_node_t * fref, caddr_t * inst)
{
  DO_SET (fun_ref_node_t *, fill, &fref->fnr_prev_hash_fillers)
  {
    if (fill->fnr_hash_part_min && QST_INT (inst, fill->fnr_nth_part) < QST_INT (inst, fill->fnr_n_part) - 1)
      return 1;
  }
  END_DO_SET ();
  return 0;
}


int64
cha_bytes_est (hash_area_t * ha, int64 * card_ret)
{
  state_slot_t *k1;
  dbe_column_t *col;
  int64 tcard;
  int64 nw;
  float n_reps;
  *card_ret = ha->ha_row_count;
  k1 = ha->ha_slots[0];
  if (SSL_REF == k1->ssl_type)
    k1 = ((state_slot_ref_t *) k1)->sslr_ssl;
  col = k1->ssl_column;
  if (ha->ha_n_keys > 1 || !col || !col->col_defined_in || (col->col_defined_in && TB_IS_RQ (col->col_defined_in)))
    {
      return sizeof (int64) * ha->ha_row_count * (ha->ha_n_keys + ha->ha_n_deps);
    }
  tcard = dbe_key_count (col->col_defined_in->tb_primary_key);
  n_reps = tcard / (float) col->col_n_distinct;
  nw = ((1.0 / n_reps) + (ha->ha_n_deps + 1)) * ha->ha_row_count;
  return nw * sizeof (int64);
}


long tc_part_hash_join;

void
chash_fill_input (fun_ref_node_t * fref, caddr_t * inst, caddr_t * state)
{
  QNCAST (query_instance_t, qi, inst);
  int p, n_part, nth_part;
  setp_node_t *setp = fref->fnr_setp;
  index_tree_t *tree = (index_tree_t *) qst_get (inst, setp->setp_ha->ha_tree);
  chash_t *cha;
  hash_area_t *ha = fref->fnr_setp->setp_ha;
  if (tree && state)
    {
      qn_send_output ((data_source_t *) fref, inst);
      return;
    }
  for (;;)
    {
      if (state)
	{
	  int64 card;
	  int64 size_est = cha_bytes_est (ha, &card);
	  n_part = 1 + (size_est / (chash_space_avail / 3));
	  if (fref->fnr_no_hash_partition && n_part > 1)
	    sqlr_new_error ("42000", "HPART",
		"Hash join would have to be partitioned but occurs in a place where partitioning is not allowed, e.g. probe comes from inside a value/exists subq, oj derived table or such.  Either increase the memory for hash join or use table option (loop) for the table.  See which hash join is marked no partition in the plan to see which table this applies to");
	  mutex_enter (&chash_rc_mtx);
	  chash_space_avail -= size_est / n_part;
	  if (n_part > 1)
	    tc_part_hash_join += n_part;
	  mutex_leave (&chash_rc_mtx);
	  QST_INT (inst, fref->fnr_n_part) = n_part;
	  nth_part = QST_INT (inst, fref->fnr_nth_part) = 0;
	  tree = cha_allocate (setp, inst, card / n_part);
	  cha = tree->it_hi->hi_chash;
	  cha->cha_reserved = size_est / n_part;

	}
      else
	{
	  n_part = QST_INT (inst, fref->fnr_n_part);
	  nth_part = ++QST_INT (inst, fref->fnr_nth_part);
	  if (nth_part == n_part)
	    {
	      SRC_IN_STATE (fref, inst) = NULL;
	      qst_set (inst, fref->fnr_setp->setp_ha->ha_tree, NULL);
	      return;
	    }
	  cha = tree->it_hi->hi_chash;
	  cha_clear (cha);
	}
      cha = tree->it_hi->hi_chash;

      if (fref->fnr_hash_part_min)
	{
	  if (1 == n_part)
	    {
	      QST_INT (inst, fref->fnr_hash_part_min) = 0;
	      QST_INT (inst, fref->fnr_hash_part_max) = (uint32) 0xffffffff;
	    }
	  else
	    {
	      uint32 min = 0, max = 0xffffffff;
	      if (0 == nth_part)
		max = (uint32) 0xffffffff / n_part;
	      else if (nth_part == n_part - 1)
		min = 1 + (((uint32) 0xffffffff / n_part) * nth_part);
	      else
		{
		  min = 1 + (((uint32) 0xffffffff / n_part) * nth_part);
		  max = (((uint32) 0xffffffff / n_part) * (nth_part + 1));
		}
	      QST_INT (inst, fref->fnr_hash_part_min) = min;
	      QST_INT (inst, fref->fnr_hash_part_max) = max;
	    }
	}
      QR_RESET_CTX_T (qi->qi_thread)
      {
	SRC_IN_STATE (fref, inst) = NULL;
	qn_input (fref->fnr_select, inst, inst);
	cl_fref_resume (fref, inst);
      }
      QR_RESET_CODE
      {
	POP_QR_RESET;
	if (RST_ERROR == reset_code)
	  longjmp_splice (THREAD_CURRENT_THREAD->thr_reset_ctx, RST_ERROR);
	GPF_T1 ("hash filler reset for partition over full not implemented");
      }
      END_QR_RESET;
      for (p = 0; p < cha->cha_n_partitions; p++)
	{
	  if (CHA_NON_UNQ == cha->cha_partitions[p].cha_unique)
	    {
	      cha->cha_unique = CHA_NON_UNQ;
	      break;
	    }
	}
      SRC_IN_STATE (fref, inst) = nth_part < n_part - 1 ? inst : NULL;
      qn_send_output ((data_source_t *) fref, inst);
      state = NULL;
    }
}


void
chash_init ()
{
  int inx;
  if (PAGE_SZ != sizeof (chash_page_t))
    GPF_T1 ("chash_page_t must have size equal to page size");
  for (inx = 0; inx < ARTM_VEC_LEN; inx++)
    consec_sets[inx] = inx;
  if (sizeof (int64) != sizeof (caddr_t))
    GPF_T1 ("chash.c expects 64 bit pointers, they are cast to and from int64");
  dk_mutex_init (&cha_alloc_mtx, MUTEX_TYPE_SHORT);
  mutex_option (&cha_alloc_mtx, "chash_alloc", NULL, NULL);
  dk_mutex_init (&chash_rc_mtx, MUTEX_TYPE_SHORT);
  for (inx = 0; inx < 256; inx++)
    chash_null_flag_dtps[inx] = dtp_is_chash_inlined (inx);
}
