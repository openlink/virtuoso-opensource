/*
 *  sqlorder.c
 *
 *  $Id$
 *
 *  SQL ORDER BY
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

#include "libutil.h"
#include "sqlnode.h"
#include "eqlcomp.h"
#include "sqlpar.h"
#include "sqlpfn.h"
#include "sqlcmps.h"
#include "sqlo.h"
#include "sqlfn.h"
#include "arith.h"
#include "sqlintrp.h"

void
ha_free (hash_area_t * ha)
{
  dk_free_box ((caddr_t) ha->ha_key_cols);
  dk_free_box ((caddr_t) ha->ha_slots);
  dk_free_box (ha->ha_non_null);
  dk_free_box ((caddr_t) ha->ha_cols);
  dk_free ((caddr_t)ha, sizeof (hash_area_t));
}




void
setp_node_free (setp_node_t * setp)
{
  dk_set_free (setp->setp_keys);
  dk_set_free (setp->setp_dependent);
  DO_SET (gb_op_t *, go, &setp->setp_gb_ops)
    {
      if (go->go_distinct_ha)
	ha_free (go->go_distinct_ha);
      dk_free_box ((caddr_t)go->go_ua_arglist);
      cv_free (go->go_ua_init_setp_call);
      cv_free (go->go_ua_acc_setp_call);
      dk_free ((caddr_t)go, sizeof (gb_op_t));
    }
  END_DO_SET();
  dk_set_free (setp->setp_gb_ops);
  setp->setp_gb_ops = NULL;
  dk_free_box ((box_t) setp->setp_keys_box);
  dk_free_box ((box_t) setp->setp_dependent_box);
  dk_free_box ((box_t) setp->setp_org_slots);
  dk_set_free (setp->setp_key_is_desc);
  dk_free_box ((caddr_t) setp->setp_ordered_gb_out);
  dk_free_box ((box_t) setp->setp_merge_temps);
  if (setp->setp_reserve_ha)
    {
      ha_free (setp->setp_reserve_ha);
    }
  key_free_trail_specs (setp->setp_insert_spec.ksp_spec_array);
  dk_set_free (setp->setp_const_gb_values);
  dk_set_free (setp->setp_const_gb_args);
  dk_free_box ((box_t) setp->setp_last_vals);
}


setp_node_t *
sqlc_add_distinct_node (sql_comp_t * sc, data_source_t ** head,
			state_slot_t ** ssl_out, long nrows, dk_set_t * code, ptrlong * dist_pos)
{
  state_slot_t * cnst = NULL;

  state_slot_t * set_no;
  int inx;
  SQL_NODE_INIT (setp_node_t, setp, setp_node_input, setp_node_free);
  if (dist_pos && 1 != (ptrlong)dist_pos)
    {
      DO_BOX (ptrlong, pos, inx, dist_pos)
	{
	  state_slot_t * ssl = ssl_out[pos];
	  if (SSL_CONSTANT == ssl->ssl_type)
	    {
	      cnst = ssl;
	      continue;
	    }
	  setp->setp_keys = NCONC (setp->setp_keys, CONS (ssl, NULL));
	}
      END_DO_BOX;
    }
  else
    {
      DO_BOX (state_slot_t *, ssl, inx, ssl_out)
	{
	  if (SSL_CONSTANT == ssl->ssl_type)
	    {
	      cnst = ssl;
	      continue;
	    }
	  setp->setp_keys = NCONC (setp->setp_keys, CONS (ssl, NULL));
	}
      END_DO_BOX;
    }
  if (!setp->setp_keys && cnst)
    setp->setp_keys = CONS (cnst, NULL);
  setp->setp_set_no_in_key = sqlg_is_multistate_gb (sc->sc_so);
  if (setp->setp_set_no_in_key)
    {
      dk_set_push (&setp->setp_keys, (void*) sc->sc_set_no_ssl);
    }

  setp->setp_distinct = 1;
  setp_distinct_hash (sc, setp, nrows, HA_DISTINCT);
  set_no = sqlg_set_no_if_needed (sc, head);
  if (set_no)
    {
      ssa_init (sc, &setp->setp_ssa, set_no);
    }
  if (code && *code)
    {
      setp->src_gen.src_pre_code = code_to_cv (sc, *code);
      *code = NULL;
    }
  setp->setp_keys_box = (state_slot_t **) dk_set_to_array (setp->setp_keys);
  sql_node_append (head, (data_source_t *) setp);
  return setp;
}


data_source_t *
sqlc_make_sort_out_node (sql_comp_t * sc, dk_set_t out_cols, dk_set_t out_slots, dk_set_t out_always_null, int is_gb)
{
  setp_node_t * setp = sc->sc_sort_insert_node;
  SQL_NODE_INIT (table_source_t, ts, table_source_input, ts_free);
  ts->ts_order_cursor = ssl_new_itc (sc->sc_cc);

  if (is_gb)
    setp->setp_merge_temps = (state_slot_t**) dk_set_to_array (out_slots);
  {
    NEW_VARZ (key_source_t, ks);
    ts->ts_order_ks = ks;
    if (NULL == sc->sc_sort_insert_node->setp_ha)
      sqlc_new_error (sc->sc_cc, "42000", "SQI01", "Internal error in SQL compiler: SqlOrder-232-0912");

    ks->ks_key = sc->sc_sort_insert_node->setp_ha->ha_key;
    ks->ks_row_check = itc_row_check;
    ks->ks_set_no = sc->sc_set_no_ssl;
    if (setp->setp_set_no_in_key)
      {
	dk_set_t iter;
	ks->ks_set_no_col_ssl = ssl_new_variable (sc->sc_cc, "gb_set_no", DV_LONG_INT);
	dk_set_push (&out_slots, (void*)ks->ks_set_no_col_ssl);
	for (iter = out_cols; iter; iter = iter->next)
	  *(ptrlong*)&iter->data += 1;
	t_set_push (&out_cols, (void*)0);
      }
    if (enable_vec)
      {
	DO_SET (state_slot_t *, ssl, &out_slots)
	  {
	    ssl->ssl_type = SSL_VEC;
	    ssl->ssl_always_vec = 1;
	  }
	END_DO_SET();
      }
    DO_SET (ptrlong, nth, &out_cols)
      {
	NCONCF1 (ks->ks_out_cols, dk_set_nth (ks->ks_key->key_parts, (int) nth));
      }
    END_DO_SET();
    ks->ks_out_slots = out_slots;
    ks->ks_from_temp_tree = sc->sc_sort_insert_node->setp_ha->ha_tree;
    ks->ks_from_setp = sc->sc_sort_insert_node;
    ks->ks_always_null = out_always_null;
    if (sc->sc_grouping)
      ks->ks_grouping = sc->sc_grouping;
    if (is_gb && enable_chash_gb)
      {
	ts->src_gen.src_input = (qn_input_fn)chash_read_input;
	ts->clb.clb_nth_set = cc_new_instance_slot (sc->sc_cc);
	ks->ks_pos_in_temp = cc_new_instance_slot (sc->sc_cc);
	ks->ks_nth_cha_part = cc_new_instance_slot (sc->sc_cc);
	ks->ks_cha_chp = cc_new_instance_slot (sc->sc_cc);
      }
  }
  if (setp->setp_any_user_aggregate_gos)
    {
      int nth = 0;
      int len = setp->setp_ha->ha_n_deps;
      ts->ts_sort_read_mask = dk_alloc_box_zero (len, DV_BIN);
      DO_SET (gb_op_t *, go, &setp->setp_gb_ops)
	{
	  if (AMMSC_USER == go->go_op)
	    ts->ts_sort_read_mask[nth] = 1;
	  nth++;
	}
      END_DO_SET ();
    }
  table_source_om (sc->sc_cc, ts);
  if (is_gb)
    ts->ts_order_ks->ks_proc_set_ctr = ssl_new_variable (sc->sc_cc, "hash_iter", DV_BIN);
  return ((data_source_t *) ts);
}


void
sqlc_copy_ssl_if_constant (sql_comp_t * sc, state_slot_t ** ssl_ret, dk_set_t * asg_code, setp_node_t * setp)
{
  state_slot_t *ssl = *ssl_ret;
  if (SSL_CONSTANT == ssl->ssl_type || ssl->ssl_qr_global)
    {
      state_slot_t * v = ssl_new_variable (sc->sc_cc, "", DV_UNKNOWN);
      ssl_copy_types (v, ssl);
      if (setp)
	{
	  dk_set_replace (setp->setp_keys, ssl, v);
	  dk_set_replace (setp->setp_dependent, ssl, v);
	}
      if (asg_code)
	cv_artm (asg_code, (ao_func_t)box_identity, v, ssl, NULL);
      *ssl_ret = v;
    }
}


