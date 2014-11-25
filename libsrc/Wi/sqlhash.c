/*
 *  sqlhash.c
 *
 *  $Id$
 *
 *  Dynamic SQL Compiler, part 2
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

#include "libutil.h"
#include "sqlnode.h"
#include "sqlcomp.h"
#include "eqlcomp.h"
#include "lisprdr.h"
#include "xmlnode.h"
#include "sqlpar.h"
#include "sqlpfn.h"
#include "sqlcmps.h"
#include "sqlfn.h"
#include "security.h"
#include "sqlo.h"
#include "sqlofn.h"



int dtp_is_fixed (dtp_t dtp);
int dtp_is_var (dtp_t dtp);


dbe_column_t *
key_col_from_ssl (dbe_key_t * key, state_slot_t * ssl, int quietcast, int op)
{
  NEW_VARZ (dbe_column_t, col);
  col->col_name = box_dv_short_string (SSL_HAS_NAME (ssl) ? ssl->ssl_name : "const");
  col->col_compression = CC_NONE;
  col->col_sqt = ssl->ssl_sqt;
  if (HA_FILL != op)
  col->col_sqt.sqt_non_null = 0;
  if (DV_ARRAY_OF_POINTER == col->col_sqt.sqt_dtp)
    col->col_sqt.sqt_dtp = DV_ANY;
  if (DV_LONG_INT == ssl->ssl_dtp /*&& !ssl->ssl_column*/)
    {
      col->col_sqt.sqt_col_dtp = col->col_sqt.sqt_dtp = DV_INT64; /* temp results of int exprs can be wider */
      col->col_sqt.sqt_precision = 19;
    }
  if (DV_IRI_ID == col->col_sqt.sqt_dtp)
    col->col_sqt.sqt_dtp = DV_IRI_ID_8;
  if (DV_UNKNOWN == col->col_sqt.sqt_dtp
      ||  (!dtp_is_fixed (col->col_sqt.sqt_dtp) && !dtp_is_var (col->col_sqt.sqt_dtp)))
    {
      col->col_sqt.sqt_dtp = quietcast ? DV_ANY : DV_LONG_STRING;
      col->col_sqt.sqt_precision = 0;
    }
  if (DV_ANY == ssl->ssl_dc_dtp && (DV_STRING != ssl->ssl_sqt.sqt_dtp && DV_WIDE != ssl->ssl_sqt.sqt_dtp && DV_BIN != ssl->ssl_sqt.sqt_dtp))
    {
      /* a any dc in a oby temp gets and any except when the ssl is typed so there is a specific colum,column type (varchar, nvarchar, binary).    Else the om ref function in the reader node is for string but the col is any */
      col->col_sqt.sqt_dtp = DV_ANY;
      col->col_sqt.sqt_col_dtp = DV_ANY;
      col->col_sqt.sqt_precision = 0;
    }
  /* turn off length checking for temp cols for now */
  if (col->col_sqt.sqt_dtp == DV_LONG_STRING ||
      col->col_sqt.sqt_dtp == DV_ANY)
    col->col_sqt.sqt_precision = 0;
  if (!col->col_sqt.sqt_col_dtp)
    col->col_sqt.sqt_col_dtp = col->col_sqt.sqt_dtp;
  col->col_id = dk_set_length (key->key_parts) + 1;

  col->col_options = (caddr_t *) box_copy_tree ((box_t) ssl->ssl_sqt.sqt_tree);
  NCONCF1 (key->key_parts, col);
  return col;
}


long
sqt_row_data_length (sql_type_t *sqt)
{
  long len = sqt_fixed_length (sqt);
  if (len == -1)
    {
      switch (sqt->sqt_dtp)
	{
	  case DV_STRING:
	      len = sqt->sqt_precision;
	      if (!len)
		len = 200;
	      break;
	  default:
	      len = 200;
	      break;
	}
    }
  return len;
}


dbe_key_t *
setp_temp_key (setp_node_t * setp, long *row_len_ptr, int quietcast, int op)
{
  dbe_column_t * col;
  NEW_VARZ (dbe_key_t, key);
  key->key_n_significant = dk_set_length (setp->setp_keys);

  key->key_id = KI_TEMP;
  key->key_is_primary = 0;
  key->key_super_id = KI_TEMP;
  DO_SET (state_slot_t *, ssl, &setp->setp_keys)
    {
      col = key_col_from_ssl (key, ssl, quietcast, op);
      if (row_len_ptr)
	*row_len_ptr += sqt_row_data_length (&col->col_sqt);
    }
  END_DO_SET();
  DO_SET (state_slot_t *, ssl, &setp->setp_dependent)
    {
      col = key_col_from_ssl (key, ssl, quietcast, op);
      if (row_len_ptr)
	*row_len_ptr += sqt_row_data_length (&col->col_sqt);
    }
  END_DO_SET();

  dbe_key_layout (key, NULL);
  dk_set_push (&setp->src_gen.src_query->qr_temp_keys, (void*) key);
  return key;
}


int
key_cl_count (dbe_col_loc_t * cls)
{
  int inx;
  for (inx = 0; cls[inx].cl_col_id; inx++);
  return inx;
}

void
setp_distinct_hash (sql_comp_t * sc, setp_node_t * setp, uint64 n_rows, int op)
{
  int quietcast = sc->sc_cc->cc_query->qr_no_cast_error;
/* This was:  int quietcast = DFE_DT == sc->sc_so->so_dfe->dfe_type ?
    NULL != sqlo_opt_value (sc->sc_so->so_dfe->_.sub.ot->ot_opts, OPT_SPARQL) : 0;
*/
  int inx;
  int n_keys = dk_set_length (setp->setp_keys);
  int n_deps = dk_set_length (setp->setp_dependent);
  hash_area_t * ha;
  if (op != HA_DISTINCT && n_keys > CHASH_GB_MAX_KEYS)
    sqlc_new_error (sc->sc_cc, "42000", "SQ186", "Over %d keys in group by or hash join", CHASH_GB_MAX_KEYS);
  if  (HA_DISTINCT == op && SETP_DISTINCT_MAX_KEYS <= n_keys)
    sqlc_new_error (sc->sc_cc, "42000", "SQ186", "Over %d keys in distinct", SETP_DISTINCT_MAX_KEYS);
  DO_SET (state_slot_t *, ssl, &setp->setp_keys)
    {
      if (!quietcast && IS_BLOB_DTP (ssl->ssl_sqt.sqt_dtp))
	sqlc_new_error (sc->sc_cc, "42000", "SQ186",
	    "Long data types not allowed for distinct, order, "
	    "group or join condition columns (%s)", ssl->ssl_name);
      else if (DV_OBJECT == ssl->ssl_sqt.sqt_dtp)
	sqlc_new_error (sc->sc_cc, "42000", "SQ187",
	    "user defined data types not allowed for distinct, order, "
	    "group or join condition columns (%s)", ssl->ssl_name);
    }
  END_DO_SET();
  ha = dk_alloc (sizeof (hash_area_t));
  memset (ha, 0, sizeof (hash_area_t));
  ha->ha_row_size = 0;
  ha->ha_key = setp_temp_key (setp, &ha->ha_row_size, quietcast, op);
  setp->setp_ha = setp->setp_reserve_ha = ha;
  ha->ha_ref_itc = ssl_new_itc (sc->sc_cc);
  ha->ha_insert_itc = ssl_new_itc (sc->sc_cc);
#ifdef NEW_HASH
  ha->ha_bp_ref_itc = ssl_new_itc (sc->sc_cc);
#endif
  ha->ha_tree = ssl_new_tree (sc->sc_cc, "DISTINCT HASH"); /* after the ha itc's, so in free the itc 's go first, freeing wired pages on the tree */
  ha->ha_n_keys = n_keys;
  ha->ha_n_deps = n_deps;
  if (enable_chash_join && HA_FILL == op)
    ; /* none of the row count limits for chash */
  else if (n_rows < 1000)
    n_rows = 1000; /* no less than 1000 if overflows memcache, must be at least this much */
  else if (n_rows > 1000000)
    n_rows = 1000000; /* cap on size except for hash join where can be large and/or partitioned */
  ha->ha_row_count = MAX (800, n_rows);
  ha->ha_key_cols = (dbe_col_loc_t *) dk_alloc_box_zero ((n_deps + n_keys + 1) * sizeof (dbe_col_loc_t), DV_BIN);
  for (inx = 0; inx < n_keys + n_deps; inx++)
    {
      dbe_col_loc_t * cl = key_find_cl (ha->ha_key, inx +1);
      ha->ha_key_cols[inx] = cl[0];
      if ((inx >= n_keys) && (cl->cl_fixed_len <= 0))
	ha->ha_memcache_only = 1;
    }
  ha->ha_slots = (state_slot_t **)
    list_to_array (dk_set_conc (dk_set_copy (setp->setp_keys),
				dk_set_copy (setp->setp_dependent)));
  ha->ha_allow_nulls = 1;
  ha->ha_op = op;
  if (setp->setp_any_user_aggregate_gos)
    ha->ha_memcache_only = 1;
  if ((HA_GROUP == op && sqlg_is_vector && !setp->setp_any_user_aggregate_gos
      && !setp->setp_any_distinct_gos
      && ha->ha_n_keys <= CHASH_GB_MAX_KEYS)
      || setp->setp_distinct)
    {
      int n_slots = BOX_ELEMENTS (ha->ha_slots);
      ha->ha_ch_len = sizeof (int64) * (1 + n_slots);
      ha->ha_ch_nn_flags = ha->ha_ch_len;
      ha->ha_ch_len += ALIGN_8(n_slots) / 8;
      ha->ha_ch_len = ALIGN_8 (ha->ha_ch_len);
    }
}


/* common header of ssl and ssl ref */
typedef struct ssl_head_s
{
  SSL_FLAGS;
} ssl_head_t;

void
setp_after_deserialize (setp_node_t * setp)
{
  int inx;
  long n_rows = setp->setp_ha->ha_row_count;
  hash_area_t * ha = setp->setp_ha;
  int n_keys = BOX_ELEMENTS (setp->setp_keys_box);
  int n_deps = BOX_ELEMENTS (setp->setp_dependent_box);
  ssl_head_t * ssl_save = NULL;
  ha->ha_slots = (state_slot_t **)
    list_to_array (dk_set_conc (dk_set_copy (setp->setp_keys),
				dk_set_copy (setp->setp_dependent)));
  if (HA_FILL == ha->ha_op)
    {
      ssl_save = (ssl_head_t*)dk_alloc_box (BOX_ELEMENTS (ha->ha_slots) * sizeof (ssl_head_t), DV_BIN);
      DO_BOX (state_slot_t *, ssl, inx, ha->ha_slots)
	{
	  ssl_save[inx] = *(ssl_head_t*)(ha->ha_slots[inx]);
	  ssl->ssl_sqt = ha->ha_key_cols[inx].cl_sqt;
	  if (DV_ANY != ssl->ssl_sqt.sqt_dtp)
	    {
	      ssl->ssl_dc_dtp = 0;
	      ssl_set_dc_type (ssl);
	    }
	}
      END_DO_BOX;
    }
  ha->ha_key = setp_temp_key (setp, &ha->ha_row_size, setp->src_gen.src_query->qr_no_cast_error, ha->ha_op);
  ha->ha_n_keys = n_keys;
  ha->ha_n_deps = n_deps;
  if (n_rows < 0)
    n_rows = 100000; /* count probably overflowed.- Large amount */
  else if (n_rows < 1000)
    n_rows = 1000; /* no less than 1000 if overflows memcache, must be at least this much */
  else if (n_rows > 1000000)
    n_rows = 1000000; /* have a cap on hash size */
  ha->ha_row_count = n_rows;
  if (HA_FILL == ha->ha_op)
    {
      dk_free_box ((caddr_t)ha->ha_key_cols);
      DO_BOX (state_slot_t *, ssl, inx, ha->ha_slots)
	*(ssl_head_t*)ssl = ssl_save[inx];
      END_DO_BOX;
      dk_free_box ((caddr_t)ssl_save);
    }
  ha->ha_key_cols = (dbe_col_loc_t *) dk_alloc_box_zero ((n_deps + n_keys + 1) * sizeof (dbe_col_loc_t), DV_BIN);
  for (inx = 0; inx < n_keys + n_deps; inx++)
    {
      dbe_col_loc_t * cl = key_find_cl (ha->ha_key, inx +1);
      if (DV_NUMERIC == cl->cl_sqt.sqt_dtp)
	{
	  cl->cl_sqt.sqt_precision = 40;
	  cl->cl_sqt.sqt_scale = 15;
	}
      ha->ha_key_cols[inx] = cl[0];
      if ((inx >= n_keys) && (cl->cl_fixed_len < 0))
	ha->ha_memcache_only = 1;
    }
  ha->ha_allow_nulls = 1;
  if (setp->setp_any_user_aggregate_gos || setp->setp_any_distinct_gos)
    ha->ha_memcache_only = 1;
  if (setp->setp_loc_ts)
    setp->setp_loc_ts->ts_order_ks->ks_key = ha->ha_key;
}


