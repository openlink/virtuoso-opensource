/*
 *  clnode.c
 *
 *  $Id$
 *
 *  Cluster versions of SQL nodes
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
#include "sqlbif.h"
#include "arith.h"
#include "eqlcomp.h"
#include "sqlfn.h"
#include "sqlpar.h"
#include "sqlpfn.h"
#include "sqlcmps.h"
#include "sqlintrp.h"
#include "aqueue.h"


#if 0
#define in_printf(a) printf a
#else
#define in_printf(a)
#endif




uint32
cp_string_hash (col_partition_t * cp, caddr_t bytes, int len, int32 * rem_ret)
{
  uint32 hash = 0;
  if (cp->cp_n_first < 0)
    {
      if (len <= -cp->cp_n_first)
	{
	  *rem_ret = -1;
	}
      else
	{
	  *rem_ret = ((-cp->cp_n_first * 8) << 24) | (SHORT_REF_NA (bytes + len - 2) & N_ONES (8 * -cp->cp_n_first));
	  len = len + cp->cp_n_first;
	}
    }
  else
    {
      *rem_ret = -1;
      if (cp->cp_n_first > 0)
	len = MIN (len, cp->cp_n_first);
    }
  BYTE_BUFFER_HASH (hash, bytes, len);
  return hash & cp->cp_mask;
}


int enable_small_int_part = 0;


uint32
cp_int_any_hash (col_partition_t * cp, unsigned int64 i, int32 * rem_ret)
{
  int shift;
  if (cp->cp_n_first < 0)
    {
      shift = MIN (32, -cp->cp_n_first * 8);
      i = I_PART (i, shift);
      *rem_ret = (shift << 24) | (i & N_ONES (shift));
      return (i >> shift) & cp->cp_mask;
    }
  else if (0 == cp->cp_n_first)
    {
      *rem_ret = -1;
      return i & cp->cp_mask;
    }
  else
    {
      shift = 8 * MAX (0, 8 - cp->cp_n_first);
      *rem_ret = -1;
      return (i >> shift) & cp->cp_mask;
    }
}


uint32
cp_double_hash (col_partition_t * cp, double d, int32 * rem_ret)
{
  /* if d is equal to some int64, then hash like this, else hash otherwise */
  char x[sizeof (double)];
  *rem_ret = -1;
  if (d > MIN_INT_DOUBLE && d < MAX_INT_DOUBLE)
    {
      double t = trunc (d);
      if (t == d)
	{
	  int64 i = (int64) d;
	  if (wi_inst.wi_master->dbs_initial_gen >= 3121)
	    return cp_int_any_hash (cp, i, rem_ret);
	  else
	    return cp_int_hash (cp, i, rem_ret);
	}
    }
  DOUBLE_TO_EXT (&x, &d);
  return cp_string_hash (cp, x, sizeof (double), rem_ret);
}


uint32
cp_numeric_hash (col_partition_t * cp, numeric_t n, int32 * rem_ret)
{
  int l;
  *rem_ret = -1;
  if (0 == n->n_scale && numeric_compare (n, num_int64_max) <= 0 && numeric_compare (n, num_int64_min) >= 0)
    {
      int64 i;
      numeric_to_int64 (n, &i);
      if (wi_inst.wi_master->dbs_initial_gen >= 3121)
	return cp_int_any_hash (cp, i, rem_ret);
      else
	return cp_int_hash (cp, i, rem_ret);
    }
  l = n->n_len + n->n_scale;
  if (l <= 15)
    {
      double d;
      numeric_to_double (n, &d);
      return cp_double_hash (cp, d, rem_ret);
    }
  return cp_string_hash (cp, (char *) &n->n_value, MAX (0, l - 2), rem_ret);
}


uint32
cp_any_hash (col_partition_t * cp, db_buf_t val, int32 * rem_ret)
{
  db_buf_t org_val;
  int is_string = 0, len, known_len = -1;
again:
  switch (val[0])
    {
    case DV_RDF:
      org_val = val;
      if (RBS_EXT_TYPE == val[1])
	return cp_int_any_hash (cp, (RBS_64 & val[1]) ? INT64_REF_NA (val + 4) : LONG_REF_NA (val + 4), rem_ret);
      rbs_hash_range (&val, &len, &is_string);
      if (is_string)
	return cp_string_hash (cp, (char *) val, len, rem_ret);
      if (wi_inst.wi_master->dbs_initial_gen >= 3120)
	{
	  /* the else branch is false but must be there for dbs partitioned wrong */
	  val = org_val + 2;	/* for non-string val, the dtp is at offset 2 */
	  known_len = -1;
	  goto again;
	}
      known_len = len;
      goto again;
    case DV_SHORT_STRING_SERIAL:
      return cp_string_hash (cp, (char *) val + 2, val[1], rem_ret);
    case DV_LONG_STRING:
      return cp_string_hash (cp, (char *) val + 5, LONG_REF_NA (val + 1), rem_ret);
    case DV_SHORT_INT:
      return cp_int_any_hash (cp, ((char *) val)[1], rem_ret);
    case DV_RDF_ID:
    case DV_IRI_ID:
    case DV_LONG_INT:
      return cp_int_any_hash (cp, LONG_REF_NA (val + 1), rem_ret);
    case DV_RDF_ID_8:
    case DV_IRI_ID_8:
    case DV_INT64:
      return cp_int_any_hash (cp, INT64_REF_NA (val + 1), rem_ret);
    case DV_DOUBLE_FLOAT:
      {
	double d;
	EXT_TO_DOUBLE (&d, val + 1);
	return cp_double_hash (cp, d, rem_ret);
      }
    case DV_SINGLE_FLOAT:
      {
	float f;
	EXT_TO_FLOAT (&f, val + 1);
	return cp_double_hash (cp, (double) f, rem_ret);
      }
    case DV_NUMERIC:
      {
	NUMERIC_VAR (num);
	numeric_from_buf ((numeric_t) num, val + 1);
	return cp_numeric_hash (cp, (numeric_t) num, rem_ret);
      }
    case DV_DB_NULL:
      *rem_ret = -1;
      return 0;
    case DV_DATETIME:
      if (wi_inst.wi_master->dbs_initial_gen >= 3120)
	return cp_string_hash (cp, (char *) val + 1, DT_COMPARE_LENGTH, rem_ret);
      /* Pre 3120 uses the dt's non comparing bits hor partition, logically equal vals would get different hashes */
    case DV_BOX_FLAGS:
      val += 5;
      goto again;
    default:
      {
	DB_BUF_TLEN (len, val[0], val);
	return cp_string_hash (cp, (char *)val, len, rem_ret);
      }
    }
}


caddr_t
col_part_cast_rdf (caddr_t val, sql_type_t * sqt, caddr_t * err)
{
  /* An incomplete text or geo box can join to an int id in geo inx.  So a geo box casts to int as its ro id, else error */
  QNCAST (rdf_box_t, rb, val);
  if (RDF_BOX_GEO == rb->rb_type || (rb->rb_serialize_id_only || rdf_no_string_inline))
    return box_num (rb->rb_ro_id);
  *err = srv_make_new_error ("22023", "CL...", "an rdf box is not joinable to an int partition key, except for geo boxes");
  return 0;
}


uint32
col_part_hash (col_partition_t * cp, caddr_t val, int is_already_cast, int *cast_ret, int32 * rem_ret)
    {
  uint32 hash = 0;
  dtp_t dtp = DV_TYPE_OF (val);
  sql_type_t *sqt = &cp->cp_sqt;
  caddr_t cast_val = NULL;
  if (DV_DB_NULL == dtp)
	{
      if (cast_ret)
	*cast_ret = KS_CAST_NULL;
      return 0;
}
  if (cast_ret)
    *cast_ret = KS_CAST_OK;
  if (CP_NO_CAST != is_already_cast)
{
      if (dtp != sqt->sqt_dtp)
    {
	  caddr_t err = NULL;
	  if (IS_BLOB_DTP (dtp))
	{
	      if (cast_ret && CP_CAST_NO_ERROR == is_already_cast)
	    {
		  *cast_ret = KS_CAST_NULL;
		  return 0;
	}
	      sqlr_new_error ("42000", "CL...", "A lob value cannot be used as a value compared to a partitioning column.");
	}
	  if (DV_ANY == sqt->sqt_dtp)
	    val = cast_val = box_to_any (val, &err);
	  else if (DV_IRI_ID_8 == sqt->sqt_dtp && DV_IRI_ID == dtp)
	    ;
	  else if (DV_INT64 == sqt->sqt_dtp && DV_LONG_INT == dtp)
	    ;
	  else if (DV_RDF == dtp)
	    val = cast_val = col_part_cast_rdf (val, sqt, &err);
      else
	    val = cast_val = box_cast_to (NULL, val, dtp, sqt->sqt_dtp, sqt->sqt_precision, sqt->sqt_scale, &err);
	  if (err)
{
	      if (cast_ret && CP_CAST_NO_ERROR == is_already_cast)
      {
		  *cast_ret = KS_CAST_NULL;
		  dk_free_tree (err);
  return 0;
}
	      sqlr_resignal (err);
	}
    }
}
  switch (cp->cp_type)
{
    case CP_INT:
{
	boxint i = unbox_iri_int64 (val);
	hash = cp_int_hash (cp, i, rem_ret);
	if (cast_val)
	  dk_free_box (cast_val);
	return hash;
}
    case CP_WORD:
{
	int len = box_length (val) - 1;
	if (DV_ANY == cp->cp_sqt.sqt_dtp)
{
	    uint32 res = cp_any_hash (cp, (dtp_t *) val, rem_ret);
	    if (cast_val)
	      dk_free_box (cast_val);
	    return res;
}
	if (DV_DATETIME == cp->cp_sqt.sqt_dtp || DV_DATE == cp->cp_sqt.sqt_dtp)
{
	    uint32 ret = cp_string_hash (cp, cast_val ? cast_val : val, DT_COMPARE_LENGTH, rem_ret);
	    if (cast_val)
	      dk_free_box (cast_val);
	    return ret;
}
	if (cp->cp_n_first < 0)
{
	    if (len > -cp->cp_n_first)
    {
		*rem_ret = ((-cp->cp_n_first * 8) << 24) | (SHORT_REF_NA (val + len - 2) & N_ONES (8 * -cp->cp_n_first));
		len += cp->cp_n_first;
    }
  else
    {
		*rem_ret = -1;
    }
}
	else
	{
	    *rem_ret = -1;
	    if (cp->cp_n_first > 0)
	      len = MIN (len, cp->cp_n_first);
	}
	BYTE_BUFFER_HASH (hash, val, len);
	if (cast_val)
	  dk_free_box (cast_val);
	return hash & cp->cp_mask;
      }
    }
  return 0;
}


caddr_t
ins_value_by_cl (dbe_col_loc_t * cl, dbe_column_t * col_1, char **names, caddr_t * values, int *found)
{
  /* fidn the name by the col id and the value by the name */
  int inx;
  static caddr_t null_box = NULL;
  dbe_column_t *col = col_1 ? col_1 : sch_id_to_column (wi_inst.wi_schema, cl->cl_col_id);
  for (inx = 0; names[inx]; inx++)
    if (!stricmp (col->col_name, names[inx]))
      {
	if (found)
	  *found = 1;
	return values[inx];
      }
  if (!null_box)
    null_box = dk_alloc_box (0, DV_DB_NULL);
  if (found)
    *found = 0;
  return null_box;
}

cl_op_t *
clrg_dml_clo (cl_req_group_t * clrg, dbe_key_t * key, int op)
{
  cl_op_t *clo;
  DO_SET (cl_op_t *, clo, &clrg->clrg_vec_clos)
  {
    if (op == clo->clo_op && key == clo->_.insert.rd->rd_key)
      return clo;
  }
  END_DO_SET ();
  clo = mp_clo_allocate (clrg->clrg_pool, op);
  mp_set_push (clrg->clrg_pool, &clrg->clrg_vec_clos, (void *) clo);
  clo->_.insert.rd = (row_delta_t *) mp_alloc_box (clrg->clrg_pool, sizeof (row_delta_t), DV_BIN);
  clo->_.insert.rd->rd_key = key;
  return clo;
}

#define CL_IS_COL_KEY_REF(cl, key) \
  (key->key_is_col && cl >= key->key_row_var && cl < &key->key_row_var[key->key_n_significant])


cl_op_t *
cl_key_insert_op_vec (caddr_t * qst, dbe_key_t * key, int ins_mode,
    char **col_names, caddr_t * values, cl_req_group_t * clrg, int seq, int nth_set)
    {
  cl_op_t *clo = clrg_dml_clo (clrg, key, CLO_INSERT);
  int is_first = 0, fill = 0;
  row_delta_t *rd = clo->_.insert.rd;
  if (!clo->_.insert.rd->rd_values)
    {
      state_slot_t col_ssl;
      memzero (&col_ssl, sizeof (col_ssl));
      col_ssl.ssl_type = SSL_VEC;
      rd->rd_n_values = dk_set_length (key->key_parts);
      rd->rd_key = key;
      rd->rd_values = (caddr_t *) mp_alloc_box (clrg->clrg_pool, rd->rd_n_values * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
      rd->rd_op = RD_INSERT;
      rd->rd_make_ins_rbe = 1;
      rd->rd_non_comp_len = key->key_row_var_start[0];
      rd->rd_non_comp_max = MAX_ROW_BYTES;
      if (!key->key_parts)
	sqlr_new_error ("42S11", "SR119", "Key %s has 0 parts. Create index probably failed", key->key_name);

      clo->_.insert.ins_mode = ins_mode;
      clo->clo_seq_no = seq;
      clo->clo_nth_param_row = nth_set;
      clo->_.insert.is_autocommit = clrg->clrg_no_txn;
      DO_ALL_CL (cl, key)
	{
	if (cl == key->key_bm_cl || CL_IS_COL_KEY_REF (cl, key))
      continue;
	col_ssl.ssl_sqt = cl->cl_sqt;
	col_ssl.ssl_sqt.sqt_dtp = dtp_canonical[col_ssl.ssl_sqt.sqt_col_dtp];
	col_ssl.ssl_dc_dtp = 0;
	ssl_set_dc_type (&col_ssl);
	rd->rd_values[fill++] = (caddr_t) mp_data_col (clo->clo_pool, &col_ssl, 1000);
      }
      END_DO_ALL_CL;
      clo->_.insert.non_txn = clrg->clrg_no_txn;
      is_first = 1;
    }
  rd = clo->_.insert.rd;
  fill = 0;
  DO_ALL_CL (cl, key)
      {
    caddr_t data;
    if (cl == key->key_bm_cl || CL_IS_COL_KEY_REF (cl, key))
      continue;
    data = ins_value_by_cl (cl, NULL, col_names, values, NULL);
    if (DV_RDF == DV_TYPE_OF (data))
      dc_append_dv_rdf_box ((data_col_t *) rd->rd_values[fill], data);
    else
      dc_append_box ((data_col_t *) rd->rd_values[fill], data);
    fill++;
  }
  END_DO_ALL_CL;
  return is_first ? clo : NULL;
}


cl_op_t *
cl_key_delete_op_vec (caddr_t * qst, dbe_key_t * key,
    char **col_names, caddr_t * values, cl_req_group_t * clrg, int seq, int nth_set)
      {
  cl_op_t *clo = clrg_dml_clo (clrg, key, CLO_DELETE);
  int is_first = 0, fill = 0;
  row_delta_t *rd = clo->_.delete.rd;
  if (!clo->_.delete.rd->rd_values)
    {
      state_slot_t col_ssl;
      memzero (&col_ssl, sizeof (col_ssl));
      col_ssl.ssl_type = SSL_VEC;
      rd->rd_n_values = key->key_n_significant;
      rd->rd_key = key;
      rd->rd_values = (caddr_t *) mp_alloc_box (clrg->clrg_pool, rd->rd_n_values * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
      rd->rd_op = RD_DELETE;
      rd->rd_non_comp_len = key->key_row_var_start[0];
      rd->rd_non_comp_max = MAX_ROW_BYTES;
      if (!key->key_parts)
	sqlr_new_error ("42S11", "SR119", "Key %s has 0 parts. Create index probably failed", key->key_name);

      clo->clo_seq_no = seq;
      clo->clo_nth_param_row = nth_set;
      DO_SET (dbe_column_t *, col, &key->key_parts)
      {
	col_ssl.ssl_sqt = col->col_sqt;
	col_ssl.ssl_sqt.sqt_dtp = dtp_canonical[col_ssl.ssl_sqt.sqt_col_dtp];
	col_ssl.ssl_dc_dtp = 0;
	ssl_set_dc_type (&col_ssl);
	rd->rd_values[fill++] = (caddr_t) mp_data_col (clo->clo_pool, &col_ssl, 1000);
	if (fill == key->key_n_significant)
	  break;
      }
      END_DO_SET ();
      is_first = 1;
    }
  rd = clo->_.delete.rd;
  fill = 0;
  DO_SET (dbe_column_t *, col, &key->key_parts)
  {
    caddr_t data;
    data = ins_value_by_cl (NULL, col, col_names, values, NULL);
    if (DV_RDF == DV_TYPE_OF (data))
      dc_append_dv_rdf_box ((data_col_t *) rd->rd_values[fill], data);
    else
      dc_append_box ((data_col_t *) rd->rd_values[fill], data);
    fill++;
    if (fill == key->key_n_significant)
      break;
	  }
	  END_DO_SET ();
  return is_first ? clo : NULL;
}


void
itc_delete_rd (it_cursor_t * itc, row_delta_t * rd)
{
  buffer_desc_t * buf;
  int inx, rc;
  dbe_key_t * key = itc->itc_insert_key;
  itc_from (itc, itc->itc_insert_key, QI_NO_SLICE);
  for (inx = 0; inx < key->key_n_significant; inx++)
    ITC_SEARCH_PARAM (itc, rd->rd_values[key->key_part_in_layout_order[inx]]);
  itc->itc_search_mode = SM_INSERT;
  itc->itc_key_spec = key->key_insert_spec;
  itc->itc_lock_mode = PL_EXCLUSIVE;
  buf = itc_reset (itc);
  rc = itc_search (itc, &buf);
  if (rc == DVC_MATCH)
    {
      itc->itc_is_on_row = 1;
      itc_set_lock_on_row (itc, &buf);
      if (!itc->itc_is_on_row)
	{
	  if (itc->itc_ltrx)
	    itc->itc_ltrx->lt_error = LTE_DEADLOCK;
	    /* not really, but just put something there. */
	  itc_bust_this_trx (itc, &buf, ITC_BUST_THROW);
	}
      itc->itc_is_on_row = 1;	/* flag not set in SM_INSERT search */
      itc_delete (itc, &buf, NO_BLOBS);
      itc_page_leave (itc, buf);
      log_delete (itc->itc_ltrx, rd, LOG_KEY_ONLY);
    }
  else
    itc_page_leave (itc, buf);
}


caddr_t
cl_ddl (query_instance_t * qi, lock_trx_t * lt, caddr_t name, int type, caddr_t trig_table)
	    {
  return NULL;
}


void
lt_expedite_1pc (lock_trx_t * lt)
  {
  GPF_T;
}


itc_cluster_t *
itcl_allocate (lock_trx_t * lt, caddr_t * inst)
  {
  NEW_VARZ (itc_cluster_t, itcl);
  itcl->itcl_qst = inst;
  itcl->itcl_pool = mem_pool_alloc ();
  return itcl;
}


void
dpipe_node_input (dpipe_node_t * dp, caddr_t * inst, caddr_t * state)
{
  NO_CL;
}


void
query_frag_input (query_frag_t * qf, caddr_t * inst, caddr_t * state)
{
  NO_CL;
}

void
qf_select_node_input (qf_select_node_t * qfs, caddr_t * inst, caddr_t * state)
{
  NO_CL;
}

#define CL_INIT_BATCH_SIZE 1

void
cl_select_save_env (table_source_t * ts, itc_cluster_t * itcl, caddr_t * inst, cl_op_t * clo, int nth)
{
  caddr_t **array = (caddr_t **) itcl->itcl_param_rows;
  caddr_t *row;
  int n_save;
  if (!array)
    {
      itcl->itcl_param_rows = (cl_op_t ***) (array =
	  (caddr_t **) mp_alloc_box_ni (itcl->itcl_pool, CL_INIT_BATCH_SIZE * sizeof (caddr_t), DV_ARRAY_OF_POINTER));
    }
  else if (BOX_ELEMENTS (array) <= nth)
    {
      if (!IS_QN (ts, trans_node_input))
	GPF_T1 ("vectored cl does not pass through here");
      else
	{
	  caddr_t new_array = mp_alloc_box_ni (itcl->itcl_pool,  MIN (dc_max_batch_sz, nth * 2) * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
      memcpy (new_array, array, box_length (array));
      itcl->itcl_param_rows = (cl_op_t ***) (array = (caddr_t **) new_array);
    }
    }
  n_save = 0;
  row = (caddr_t *) mp_alloc_box_ni (itcl->itcl_pool, sizeof (caddr_t) * (1 + n_save), DV_ARRAY_OF_POINTER);
  row[0] = (caddr_t) clo;
  array[nth] = row;
}

void
cl_node_init (table_source_t * ts, caddr_t * inst)
{
};
