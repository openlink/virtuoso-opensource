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
 *  Copyright (C) 1998-2017 OpenLink Software
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
#include "sqlfn.h"


key_id_t
sqlc_new_temp_key_id (sql_comp_t * sc)
{
  key_id_t last;
  while (sc->sc_super)
    sc = sc->sc_super;
  last = sc->sc_next_temp_key_id;
  if (!last)
    last = KI_DISTINCT;
  sc->sc_next_temp_key_id = last + 1;
  return last;
}


void
ha_free (hash_area_t * ha)
{
  dk_free_box ((caddr_t) ha->ha_key_cols);
  dk_free_box ((caddr_t) ha->ha_slots);
  dk_free_box ((caddr_t) ha->ha_cols);
  dk_free ((caddr_t)ha, sizeof (hash_area_t));
}

#define SSA_PUSH(s) if (s) dk_set_push (&save, (void*)s)


dk_set_t
ha_save (hash_area_t * ha)
{
  dk_set_t save = NULL;
  SSA_PUSH (ha->ha_tree);
  SSA_PUSH (ha->ha_insert_itc);
  SSA_PUSH (ha->ha_ref_itc);
  SSA_PUSH (ha->ha_bp_ref_itc);

  return save;
}


void
setp_set_ssa (sql_comp_t * sc, setp_node_t * setp, dk_set_t * list_ret)
{
  /* put all the ssls that keep state for the setp into the ssa_save */
  dk_set_t save = NULL;
  hash_area_t * ha = setp->setp_ha;
  SSA_PUSH (ha->ha_tree);
  SSA_PUSH (ha->ha_insert_itc);
  SSA_PUSH (ha->ha_ref_itc);
  SSA_PUSH (ha->ha_bp_ref_itc);
  SSA_PUSH (setp->setp_sorted);
  SSA_PUSH (setp->setp_row_ctr);
  DO_SET (gb_op_t *, go, &setp->setp_gb_ops)
    {
      if (go->go_distinct_ha)
	{
	  hash_area_t * ha = go->go_distinct_ha;
	  SSA_PUSH (ha->ha_tree);
	  SSA_PUSH (ha->ha_insert_itc);
	  SSA_PUSH (ha->ha_ref_itc);
	  SSA_PUSH (ha->ha_bp_ref_itc);
	}
    }
  END_DO_SET();
  if (list_ret)
    *list_ret = dk_set_copy (save);
  setp->setp_ssa.ssa_save = (state_slot_t **) list_to_array (save);
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
  dk_set_free (setp->setp_key_is_desc);
  dk_free_box ((caddr_t) setp->setp_ordered_gb_out);
  if (setp->setp_reserve_ha)
    {
      ha_free (setp->setp_reserve_ha);
    }
  key_free_trail_specs (setp->setp_insert_spec.ksp_spec_array);
  dk_set_free (setp->setp_const_gb_values);
  dk_set_free (setp->setp_const_gb_args);
  dk_free_box ((box_t) setp->setp_last_vals);
  dk_free_box ((box_t)setp->setp_ssa.ssa_save);
}


setp_node_t *
sqlc_add_distinct_node (sql_comp_t * sc, data_source_t ** head,
    state_slot_t ** ssl_out, long nrows)
{
  int inx;
  SQL_NODE_INIT (setp_node_t, setp, setp_node_input, setp_node_free);
  DO_BOX (state_slot_t *, ssl, inx, ssl_out)
  {
    setp->setp_keys = NCONC (setp->setp_keys, CONS (ssl, NULL));
  }
  END_DO_BOX;
  setp->setp_distinct = 1;
  setp->setp_temp_key = sqlc_new_temp_key_id (sc);
  setp_distinct_hash (sc, setp, nrows);
  sql_node_append (head, (data_source_t *) setp);
  return setp;
}


data_source_t *
sqlc_make_sort_out_node (sql_comp_t * sc, dk_set_t out_cols, dk_set_t out_slots, dk_set_t out_always_null)
{
  SQL_NODE_INIT (table_source_t, ts, table_source_input, ts_free);

  ts->ts_order_cursor = ssl_new_itc (sc->sc_cc);

  {
    NEW_VARZ (key_source_t, ks);
    ts->ts_order_ks = ks;
    if (NULL == sc->sc_sort_insert_node->setp_ha)
      sqlc_new_error (sc->sc_cc, "42000", "SQI01", "Internal error in SQL compiler: SqlOrder-232-0912");

    ks->ks_key = sc->sc_sort_insert_node->setp_ha->ha_key;
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
  }
  table_source_om (sc->sc_cc, ts);
  return ((data_source_t *) ts);
}


void
sqlc_copy_ssl_if_constant (sql_comp_t * sc, state_slot_t ** ssl_ret)
{
  state_slot_t *ssl = *ssl_ret;
  if (SSL_CONSTANT == ssl->ssl_type)
    {
      *ssl_ret = ssl_new_variable (sc->sc_cc, "", DV_UNKNOWN);
      ssl_copy_types (*ssl_ret, ssl);
    }
}


