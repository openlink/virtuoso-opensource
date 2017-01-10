/*
 *  sqltrig.c
 *
 *  $Id$
 *
 *  Triggers
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

#include "sqlnode.h"
#include "sqlpar.h"
#include "sqlcmps.h"
#include "sqlfn.h"
#include "sqlintrp.h"
#include "arith.h"
#include "sqlpfn.h"


void
tb_drop_trig_def (dbe_table_t * tb, char *name)
{
  dk_set_t trigs = tb->tb_triggers->trig_list;
  dk_set_t *prev = &tb->tb_triggers->trig_list;
  while (trigs)
    {
      query_t *qr = (query_t *) trigs->data;
      if (0 == strcmp (name, qr->qr_proc_name))
	{
	  *prev = trigs->next;
	  dk_free ((void *) trigs, sizeof (s_node_t));
	  dk_set_pushnew (&global_old_triggers, qr);
	  return;
	}
      prev = &trigs->next;
      trigs = trigs->next;
    }
}


void
trig_set_def (dbe_table_t * tb, query_t * nqr)
{
  dk_set_t *prev;
  dk_set_t list;
  tb_drop_trig_def (tb, nqr->qr_proc_name);
  prev = &tb->tb_triggers->trig_list;
  list = *prev;
  while (list)
    {
      query_t *qr = (query_t *) list->data;
      if (qr->qr_trig_order > nqr->qr_trig_order)
	{
	  *prev = CONS (nqr, list);
	  return;
	}
      prev = &list->next;
      list = list->next;
    }
  *prev = CONS (nqr, NULL);
}


int
tb_has_similar_trigger (dbe_table_t * tb, query_t * qr)
{
  /* a trigger def does not cause recomp of subject table users
   * if there already was a similar trigger.  */
  DO_SET (query_t *, trig, &tb->tb_triggers->trig_list)
  {
    if (trig->qr_trig_event == qr->qr_trig_event)
      {
	if (qr->qr_trig_event == TRIG_UPDATE)
	  {
	    if (!trig->qr_trig_upd_cols)
	      /* unqualified upd trig in place. Table trigger profile not changed */
	      return 1;
	    if (qr->qr_trig_upd_cols
		&& box_equal ((caddr_t) trig->qr_trig_upd_cols,
		    (caddr_t) qr->qr_trig_upd_cols))
	      return 1;
	  }
	else
	  return 1;
      }
  }
  END_DO_SET ();
  return 0;
}

int recursive_trigger_calls = 1;

int
tb_is_trig (dbe_table_t * tb, int event, caddr_t * col_names)
{

  if ((event == TRIG_INSERT && tb->tb_rls_procs[TB_RLS_I]) ||
      (event == TRIG_UPDATE && tb->tb_rls_procs[TB_RLS_U]) ||
      (event == TRIG_DELETE && tb->tb_rls_procs[TB_RLS_D]))
    return 1;

  DO_SET (query_t *, qr, &tb->tb_triggers->trig_list)
  {
    if (qr->qr_trig_event == event)
      return 1;
  }
  END_DO_SET ();
  if (recursive_trigger_calls)
    {
      DO_SET (dbe_key_t *, key, &tb->tb_primary_key->key_supers)
	{
	  if (!key->key_migrate_to && key->key_table)
	    {
	      if (tb_is_trig (key->key_table, event, col_names))
		return 1;
	    }
	}
      END_DO_SET ();
    }
  return 0;
}


int
tb_is_trig_at (dbe_table_t * tb, int event, int trig_time, caddr_t * col_names)
{

  DO_SET (query_t *, qr, &tb->tb_triggers->trig_list)
  {
    if (qr->qr_trig_event == event && qr->qr_trig_time == trig_time)
      return 1;
  }
  END_DO_SET ();
  if (recursive_trigger_calls)
    {
      DO_SET (dbe_key_t *, key, &tb->tb_primary_key->key_supers)
	{
	  if (!key->key_migrate_to && key->key_table)
	    {
	      if (tb_is_trig_at (key->key_table, event, trig_time, col_names))
		return 1;
	    }
	}
      END_DO_SET ();
    }
  return 0;
}


void
trig_call (query_t * qr, caddr_t * qst, state_slot_t ** args, dbe_table_t *calling_tb)
{
  query_instance_t *qi = (query_instance_t *) qst;
  char auto_qi[AUTO_QI_DEFAULT_SZ];
  caddr_t err = NULL;
  int inx;
  caddr_t *pars;
  int n_args = BOX_ELEMENTS (args);
  dbe_key_t *calling_key = calling_tb->tb_primary_key;
  dbe_key_t *trig_key = qr->qr_trig_dbe_table->tb_primary_key;
  int calling_key_n_parts = dk_set_length (calling_key->key_parts);
  int trig_key_n_parts = dk_set_length (trig_key->key_parts);
  int n_total_pars = 0;

  if (!qr->qr_is_complete)
    /* a trigger being compiled is defined but must not be called */
    return;
  if (qr->qr_to_recompile)
    { /* if qr need to be recompiled do it first, otherwise new cols may not be passed */
      qr = qr_recompile (qr, NULL);
      trig_key = qr->qr_trig_dbe_table->tb_primary_key;
      trig_key_n_parts = dk_set_length (trig_key->key_parts);
    }

  if (n_args == calling_key_n_parts * 2)
    n_total_pars = trig_key_n_parts * 2;
  else if (n_args == calling_key_n_parts)
    n_total_pars = trig_key_n_parts;
  else
    GPF_T;

  pars = (caddr_t *) dk_alloc_box (
      n_total_pars * sizeof (caddr_t *), DV_ARRAY_OF_POINTER);

  inx = 0;
  DO_SET (dbe_column_t *, col, &trig_key->key_parts)
    {
      pars[inx] = (caddr_t) qst_address (qst, args[inx]);
      if (n_total_pars > trig_key_n_parts)
	{
	  caddr_t cast_value = row_set_col_cast (QST_GET (qst,
		args[inx + calling_key_n_parts]), &col->col_sqt, &err,
	        col->col_id, trig_key, qst);

	  if (cast_value)
	    qst_set (qst, args[inx + calling_key_n_parts], cast_value);

	  pars[inx + trig_key_n_parts] = (caddr_t) qst_address (qst, args[inx + calling_key_n_parts]);
	}
      inx = inx + 1;
    }
  END_DO_SET ();
  err = qr_subq_exec (qi->qi_client, qr, qi,
      (caddr_t *) & auto_qi, sizeof (auto_qi), NULL, pars, NULL);
  dk_free_box ((caddr_t) pars);
  if (err != (caddr_t) SQL_SUCCESS && err != (caddr_t) SQL_NO_DATA_FOUND)
    sqlr_resignal (err);
}


int
trig_call_check (query_t * qr, int event, data_source_t * qn)
{
  int inx, sinx, n_sensitive;
  oid_t *upd_col_ids;
  if (qr->qr_trig_event != event)
    return 0;
  if (event != TRIG_UPDATE)
    return 1;
  if ((qn_input_fn) update_node_input == qn->src_input)
    upd_col_ids = ((update_node_t *) qn)->upd_col_ids;
  else if ((qn_input_fn) remote_table_source_input == qn->src_input)
    upd_col_ids = ((remote_table_source_t *) qn)->rts_trigger_cols;
  else if ((qn_input_fn) query_frag_input == qn->src_input)
    upd_col_ids = ((query_frag_t *) qn)->qf_trigger_cols;
  else
    {
      GPF_T;			/* update trigger event and non-update qn */
      upd_col_ids = NULL;	/* keep cc happy */
    }

  if (!qr->qr_trig_upd_cols)
    return 1;
  n_sensitive = BOX_ELEMENTS (qr->qr_trig_upd_cols);
  DO_BOX (oid_t, col, inx, upd_col_ids)
  {
    for (sinx = 0; sinx < n_sensitive; sinx++)
      if (qr->qr_trig_upd_cols[sinx] == col)
	return 1;
  }
  END_DO_BOX;
  return 0;
}

#define MAX_TRIGS 100

void
trig_copy_trigger_qrs (dbe_table_t * tb, dbe_table_t *calling_tb,
    int event, data_source_t * qn, query_t *trigs[], int *fill)
{
  /* copy the applicable trigger list to temp since recompile may alter the list */
  if (recursive_trigger_calls)
    {
      DO_SET (dbe_key_t *, key, &tb->tb_primary_key->key_supers)
	{
	  if (!key->key_migrate_to && key->key_table)
	    trig_copy_trigger_qrs (key->key_table, calling_tb, event, qn, trigs, fill);
	}
      END_DO_SET ();
    }

  DO_SET (query_t *, qr, &tb->tb_triggers->trig_list)
  {
    if (trig_call_check (qr, event, qn))
      {
	trigs[*fill] = qr;
	*fill = *fill + 1;
      }
    if (*fill >= MAX_TRIGS)
      sqlr_new_error ("42000", "SR215", "Too many triggers on %s", calling_tb->tb_name);
  }
  END_DO_SET ();
}

void
cl_trig_flush (qn_input_fn qn_run, data_source_t * qn, caddr_t * qst)
{
}


void
trig_wrapper (caddr_t * qst, state_slot_t ** args, dbe_table_t * tb,
    int event, data_source_t * qn, qn_input_fn qn_run)
{
  int fill = 0, inx;
  query_t *trigs[MAX_TRIGS];
  int instead = 0;
  query_instance_t *qi = (query_instance_t *) qst;

  if (qi->qi_no_triggers
      || qi->qi_client->cli_no_triggers)
    {
      qn_run (qn, qst, qst);
      ROW_AUTOCOMMIT (qi);
      return;
    }

  trig_copy_trigger_qrs (tb, tb, event, qn, trigs, &fill);

  for (inx = 0; inx < fill; inx++)
    if (trigs[inx]->qr_trig_time == TRIG_BEFORE)
      trig_call (trigs[inx], qst, args, tb);

  for (inx = 0; inx < fill; inx++)
    if (trigs[inx]->qr_trig_time == TRIG_INSTEAD)
      {
	trig_call (trigs[inx], qst, args, tb);
	instead = 1;
      }

  if (!instead)
    {
      qn_run (qn, qst, qst);
      cl_trig_flush (qn_run, qn, qst);
      ROW_AUTOCOMMIT (qi);
    }
  for (inx = 0; inx < fill; inx++)
    if (trigs[inx]->qr_trig_time == TRIG_AFTER)
      trig_call (trigs[inx], qst, args, tb);
}
