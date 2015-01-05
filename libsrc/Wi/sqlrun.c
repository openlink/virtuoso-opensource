/*
 *  sqlrun.c
 *
 *  $Id$
 *
 *  SQL query execution
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

#include "sqlnode.h"
#include "xmlnode.h"
#include "sqlfn.h"
#include "sqlcomp.h"
#include "lisprdr.h"
#include "sqlopcod.h"
#include "security.h"
#include "sqlbif.h"
#include "sqltype.h"
#include "libutil.h"

/* dummy defs. USed in commenting out src_state_sem */

caddr_t
qst_get (caddr_t * state, state_slot_t * sl)
{
  return (QST_GET (state, sl));
}


caddr_t
sel_out_get (caddr_t * out_copy, int inx, state_slot_t * sl)
{
  int sl_type = sl->ssl_type;
  if (sl_type == SSL_CONSTANT)
    return (sl->ssl_constant);
  return (out_copy[inx]);
}


caddr_t *
qst_address (caddr_t * state, state_slot_t * sl)
{
  int sl_type = sl->ssl_type;
  if (sl_type == SSL_CONSTANT)
    return NULL;
  if (IS_SSL_REF_PARAMETER (sl->ssl_type))
    return (((caddr_t *) state[sl->ssl_index]));
  else
    return (&state[sl->ssl_index]);
}


void
qst_set_ref (caddr_t * state, state_slot_t * sl, caddr_t * v)
{
  if (!v)
    GPF_T1 ("NULL ref parameter");
  if (!IS_SSL_REF_PARAMETER (sl->ssl_type))
    GPF_T1 ("Not ref parameter in qst_set_ref");

  state[sl->ssl_index] = (caddr_t) v;
}


void
ssl_alias (state_slot_t * alias, state_slot_t * real)
{
  alias->ssl_is_alias = 1;
  alias->ssl_index = real->ssl_index;
  alias->ssl_type = real->ssl_type;
  alias->ssl_sqt = real->ssl_sqt;
  alias->ssl_dtp = real->ssl_dtp;
  alias->ssl_prec = real->ssl_prec;
  alias->ssl_scale = real->ssl_scale;
  alias->ssl_alias_of = real;
}


void
ssl_copy_types (state_slot_t * to, state_slot_t * from)
{
  dk_free_box (to->ssl_name);
  to->ssl_name = box_copy_tree (from->ssl_name);
  to->ssl_sqt = from->ssl_sqt;
  to->ssl_dtp = from->ssl_dtp;
  to->ssl_prec = from->ssl_prec;
  to->ssl_scale = from->ssl_scale;
}


void
ssl_free_data (state_slot_t * sl, caddr_t data)
{
#ifdef DEBUG
  if (!data)
    GPF_T1 ("Do not free NULL");
#endif
  switch (sl->ssl_type)
    {
    case SSL_PLACEHOLDER:
     if (data)
	plh_free ((placeholder_t *) data);
      break;

    case SSL_PARAMETER:
    case SSL_REF_PARAMETER:
    case SSL_REF_PARAMETER_OUT:
    case SSL_VARIABLE:
    case SSL_COLUMN:
      if (IS_BOX_POINTER (data))
	dk_free_tree (data);
      break;

    case SSL_CURSOR:
      lc_free ((local_cursor_t *) data);
      break;

    case SSL_ITC:
      itc_unregister ((it_cursor_t *) data);
      itc_free ((it_cursor_t *) data);
      break;

    case SSL_CONSTANT:
      break;


    default:
      GPF_T;			/* This ssl type should not be here */
    }
}


void
qst_set (caddr_t * state, state_slot_t * sl, caddr_t v)
{
#ifdef QST_DEBUG
  if (sl->ssl_index < QI_FIRST_FREE)
    GPF_T1 ("Invalid SSL in qst_set");
  else if (sl->ssl_type == SSL_CONSTANT)
    GPF_T1 ("Invalid constant SSL in qst_set");
  else
    {
#endif
      caddr_t *place = IS_SSL_REF_PARAMETER (sl->ssl_type)
	  ? (caddr_t *) state[sl->ssl_index]
	  : (caddr_t *) &state[sl->ssl_index];
      if (*place)
	ssl_free_data (sl, *place);
      *place = v;
#ifdef QST_DEBUG
    }
#endif
}


void
qst_swap (caddr_t * state, state_slot_t * sl, caddr_t *v)
{
#ifdef QST_DEBUG
  if (sl->ssl_index < QI_FIRST_FREE)
    GPF_T1 ("Invalid SSL in qst_set");
  else {
#endif
  caddr_t *place = IS_SSL_REF_PARAMETER (sl->ssl_type)
    ? (caddr_t *) state[sl->ssl_index]
    : (caddr_t *) &state[sl->ssl_index];
  caddr_t swap = place[0];
  place[0] = v[0];
  v[0] = swap;
#ifdef QST_DEBUG
  }
#endif
}


int
qst_swap_or_get_copy (caddr_t * state, state_slot_t * sl, caddr_t *v)
{
#ifdef QST_DEBUG
  if (sl->ssl_index < QI_FIRST_FREE)
    {
      GPF_T1 ("Invalid SSL in qst_set");
      return 0;
    }
  else {
#endif
  /* is this a valid output parameter ? */
  caddr_t *place;
  caddr_t swap_val;
  switch (sl->ssl_type)
    {
    case SSL_REF_PARAMETER:
    case SSL_REF_PARAMETER_OUT:
      place = (caddr_t *) state[sl->ssl_index];
      goto swap;
    case SSL_PARAMETER:
    case SSL_VARIABLE:
      place = (caddr_t *) &state[sl->ssl_index];
      goto swap;
    case SSL_CONSTANT:
      place = &(sl->ssl_constant);
      goto get_copy;
    default:
      place = (caddr_t *) &state[sl->ssl_index];
      goto get_copy;
    }
  ;
swap:
  if (sl->ssl_is_observer)
    goto get_copy;
  swap_val = place[0];
  place[0] = v[0];
  v[0] = swap_val;
  return 1;
get_copy:
  dk_free_tree (v[0]);
  v[0] = box_copy_tree (place[0]);
  return 0;
#ifdef QST_DEBUG
  }
#endif
}


caddr_t *
sel_out_copy (state_slot_t ** out_slots, caddr_t * qst, int keep_co)
{
  int inx;
  long len = box_length ((caddr_t) out_slots);
  caddr_t *copy = (caddr_t *) dk_alloc_box ((int) len, DV_ARRAY_OF_LONG);

  DO_BOX (state_slot_t *, sl, inx, out_slots)
  {
    char sl_type = sl->ssl_type;
    if (IS_SSL_REF_PARAMETER (sl_type)
	|| sl_type == SSL_CONSTANT)
      {
	copy[inx] = qst_get (qst, sl);
      }
    else
      {
	if (sl_type == SSL_PLACEHOLDER || sl_type == SSL_ITC)
	  {
	    caddr_t val = qst[sl->ssl_index];
	    copy[inx] = val
	      ? (caddr_t) plh_copy ((placeholder_t *) val) : NULL;
	  }
	else
	  {
	    copy[inx] = box_copy_tree (qst[sl->ssl_index]);
	  }
      }
  }
  END_DO_BOX;
  return (copy);
}


void
sel_out_free (state_slot_t ** out_slots, caddr_t * qst)
{
  caddr_t dt;
  int inx;
  DO_BOX (state_slot_t *, sl, inx, out_slots)
  {
    char sl_type = sl->ssl_type;
    if (sl->ssl_is_alias)
      goto next;
    if ((sl_type == SSL_PLACEHOLDER || sl_type == SSL_ITC))
      {
	placeholder_t *pl = (placeholder_t *) qst[inx];
	if (pl)
	  plh_free (pl);
	continue;
      }
    dt = qst[inx];
    if (dt)
      {
	if (sl->ssl_type == SSL_PLACEHOLDER || sl->ssl_type == SSL_ITC)
	  {
	    plh_free ((placeholder_t *) dt);
	  }
	else
	  {
	    ssl_free_data (sl, dt);
	  }
      }

  next:;
  }
  END_DO_BOX;
  dk_free_box ((caddr_t) qst);
}


void
qi_inst_state_free (caddr_t * qi_box)
{
  query_instance_t *qi = (query_instance_t *) qi_box;
  query_t *qr = qi->qi_query;
  state_slot_t ** slots = qr->qr_freeable_slots;
  int n = slots ? BOX_ELEMENTS (slots) : 0, inx;
  for (inx = 0; inx < n; inx++)
    {
      state_slot_t * sl = slots[inx];
      caddr_t dt = qi_box[sl->ssl_index];
      if (IS_BOX_POINTER (dt))
	ssl_free_data (sl, dt);
    }
}

void
sqlr_error (const char *code, const char *string, ...)
{
  du_thread_t * self;
  static char temp[2000];
  va_list list;
  caddr_t err;
  ASSERT_OUTSIDE_TXN;
  va_start (list, string);
  vsnprintf (temp, sizeof (temp), string, list);
  va_end (list);
  err = srv_make_new_error (code, "SR449", "%s", temp);
  self = THREAD_CURRENT_THREAD;
  thr_set_error_code (self, err);
  longjmp_splice (self->thr_reset_ctx, RST_ERROR);
}


void
sqlr_new_error (const char *code, const char *virt_code, const char *string, ...)
{
  du_thread_t * self;
  static char temp[2000];
  va_list list;
  caddr_t err;
  ASSERT_OUTSIDE_TXN;
  va_start (list, string);
  vsnprintf (temp, sizeof (temp), string, list);
  va_end (list);
  temp[sizeof(temp)-1] = '\0';
  err = srv_make_new_error (code, virt_code, "%s", temp);
  self = THREAD_CURRENT_THREAD;
  thr_set_error_code (self, err);
  longjmp_splice (self->thr_reset_ctx, RST_ERROR);
}

sqw_mode sql_warning_mode = SQW_ON;

void
sqlr_warning (const char *code, const char *virt_code, const char *string, ...)
{
  static char temp[2000];
  va_list list;
  caddr_t err;
  va_start (list, string);
  vsnprintf (temp, sizeof (temp), string, list);
  va_end (list);
  temp[sizeof(temp)-1] = '\0';
  err = srv_make_new_error (code, virt_code, "%s", temp);
  sql_warning_add (err, 0);
}


void
sql_warnings_clear (void)
{
  dk_set_t warnings;

  warnings = sql_warnings_save (NULL);
  if (warnings)
    dk_free_tree (list_to_array (warnings));
}


void
sql_warnings_send_to_cli (void)
{
  dk_set_t warnings;
  client_connection_t *cli;
  int send_warnings = 1;

  cli = GET_IMMEDIATE_CLIENT_OR_NULL;
  if (!cli || cli->cli_version < 2717)
    send_warnings = 0;
  warnings = sql_warnings_save (NULL);
  if (warnings)
    {
      warnings = dk_set_nreverse (warnings);
      while (warnings)
	{
	  caddr_t err = (caddr_t) dk_set_pop (&warnings);
	  if (send_warnings)
	    PrpcAddAnswer (err, DV_ARRAY_OF_POINTER, 1, 0);
	  else
	    log_debug ("Cannot send warning to an older client : [%.5s] %.1000s",
		ERR_STATE (err), ERR_MESSAGE(err));
	  dk_free_tree (err);
	}
    }
}


dk_set_t
sql_warnings_save (dk_set_t new_warnings)
{
  du_thread_t * self;
  dk_set_t warnings;

  self = THREAD_CURRENT_THREAD;
  warnings = (dk_set_t) THR_ATTR (self, TA_SQL_WARNING_SET);
  SET_THR_ATTR (self, TA_SQL_WARNING_SET, new_warnings);
  return warnings;
}


void
itc_sqlr_error (it_cursor_t * itc, buffer_desc_t * buf, const char *code,
    const char *string, ...)
{
  du_thread_t * self = THREAD_CURRENT_THREAD;
  static char temp[2000];
  va_list list;
  caddr_t err;

  va_start (list, string);
  vsnprintf (temp, sizeof (temp), string, list);
  va_end (list);
  err = srv_make_new_error (code, "SR450", "%s", temp);
  if (buf)
    itc_page_leave (itc, buf);
  thr_set_error_code (self, err);
  if (!itc->itc_fail_context)
    GPF_T1 ("No ITC fail context");			/* No fail context */
  longjmp_splice (itc->itc_fail_context, RST_ERROR);
}


void
itc_sqlr_new_error (it_cursor_t * itc, buffer_desc_t * buf, const char *code, const char *virt_code,
    const char *string, ...)
{
  du_thread_t * self = THREAD_CURRENT_THREAD;
  static char temp[2000];
  va_list list;
  caddr_t err;

  va_start (list, string);
  vsnprintf (temp, sizeof (temp), string, list);
  va_end (list);
  err = srv_make_new_error (code, virt_code, "%s", temp);
  if (buf)
    itc_page_leave (itc, buf);
  thr_set_error_code (self, err);
  if (!itc->itc_fail_context)
    GPF_T1 ("No ITC fail context");			/* No fail context */
  longjmp_splice (itc->itc_fail_context, RST_ERROR);
}


void
sqlr_resignal (caddr_t err)
{
  du_thread_t * self;
  if (SQL_SUCCESS == err)
    return;
/*
  if (10000 > ((int)(err)))
    GPF_T1("Error code resignaled instead of error state/message pair");
*/
  self = THREAD_CURRENT_THREAD;
  thr_set_error_code (self, err);
  longjmp_splice (self->thr_reset_ctx, RST_ERROR);
}


void
qi_enter (query_instance_t * qi)
{
  if (qi->qi_caller == CALLER_CLIENT)
    {
      ASSERT_IN_MTX (qi->qi_client->cli_mtx);
      qi->qi_threads++;
    }
  else
    {
      qi->qi_threads++;
    }
}


void
qi_leave (query_instance_t * qi)
{
  if (qi->qi_caller == CALLER_CLIENT)
    {
      mutex_enter (qi->qi_client->cli_mtx);
      qi->qi_threads--;
      mutex_leave (qi->qi_client->cli_mtx);
    }
  else
    qi->qi_threads--;
}


int
qi_kill (query_instance_t * qi, int is_error)
{
  int rc;
  du_thread_t *thr_waiting;
  client_connection_t *cli = qi->qi_client;
  if (qi->qi_caller != CALLER_CLIENT)
    {
      int rc = LTE_OK;
      if (qi->qi_trx->lt_status != LT_PENDING
	  && qi->qi_trx->lt_status != LT_FREEZE)
	rc = qi->qi_trx->lt_error;
      qi_free ((caddr_t *) qi);
      return rc;
    }
  ASSERT_OUTSIDE_MTX (qi->qi_client->cli_mtx);
  ASSERT_OUTSIDE_TXN;


  IN_CLIENT (cli);
  qi_detach_from_stmt (qi);
  thr_waiting = qi->qi_thread_waiting_termination;
  LEAVE_CLIENT (cli);
  IN_TXN;
  if (qi->qi_autocommit)
    {
      rc = lt_close (qi->qi_trx, is_error == QI_DONE ? SQL_COMMIT : SQL_ROLLBACK);
    }
  else
    {
    rc = lt_leave (qi->qi_trx);
  LEAVE_TXN;
    }
  qi_free ((caddr_t *) qi);
  ASSERT_OUTSIDE_MTX (cli->cli_mtx);
  if (thr_waiting)
    semaphore_leave (thr_waiting->thr_sem);
  return rc;
}


int
qi_select_leave (query_instance_t * qi)
{
  lock_trx_t *lt = qi->qi_trx;
  if (qi->qi_caller != CALLER_CLIENT)
    return LTE_OK;
  IN_CLIENT (qi->qi_client);
  if (qi->qi_client->cli_terminate_requested)
    {
      LEAVE_CLIENT (qi->qi_client);
      return (qi_kill (qi, QI_ERROR));
    }

  IN_TXN;
  CHECK_DK_MEM_RESERVE (lt);
  if (LT_PENDING != lt->lt_status)
    {
      LEAVE_TXN;
      qi_detach_from_stmt (qi);
      LEAVE_CLIENT (qi->qi_client);
      return (qi_kill (qi, QI_ERROR));
    }
  lt_leave (lt);
  qi->qi_threads--;
  LEAVE_TXN;
  LEAVE_CLIENT (qi->qi_client);
  return LTE_OK;
}


void
qn_set_local_save (data_source_t * qn, caddr_t * inst)
{
  int n = BOX_ELEMENTS (qn->src_local_save), inx;
  for (inx = 0; inx < n; inx += 2)
    qst_set_over (inst, qn->src_local_save[inx+1], qst_get (inst, qn->src_local_save[inx]));
}


void
qn_restore_local_save (data_source_t * qn, caddr_t * inst)
{
  int n = BOX_ELEMENTS (qn->src_local_save), inx;
  for (inx = 0; inx < n; inx += 2)
    qst_set_over (inst, qn->src_local_save[inx], qst_get (inst, qn->src_local_save[inx+1]));
}

int
err_is_anytime (caddr_t err)
{
  return (DV_ARRAY_OF_POINTER == DV_TYPE_OF (err)
	  && 3 == BOX_ELEMENTS (err)
	  && DV_STRINGP (((caddr_t*)err)[1])
	  && !strcmp (((caddr_t*)err)[1], SQL_ANYTIME));
}


void
cli_anytime_timeout (client_connection_t * cli)
{
  cli->cli_anytime_started = 0;
  cli->cli_terminate_requested = 0;
  cli->cli_anytime_checked = 0;
  sqlr_new_error (SQL_ANYTIME, "RC...", "Returning partial results after anytime timeout");
}


void
cli_terminate_in_itc_fail (client_connection_t * cli, it_cursor_t * itc, buffer_desc_t ** buf)
{
  lock_trx_t * lt = cli->cli_trx;
  /* if cancel in a cluster server thread, signal as anytime so as not to kill the transaction.  Existences etc can be cancelled without affecting the txn */
  if (wi_inst.wi_checkpoint_atomic)
    return;
  if (CLI_RESULT == cli->cli_terminate_requested
      || (CLI_TERMINATE == cli->cli_terminate_requested && cli->cli_clt))
    {
      if (itc)
	{
	  if (buf)
	    itc_page_leave (itc, *buf);
	  itc_unregister (itc); /* could be automatic itc, will have ref to stack in registered if not done here, since this does not go via itc_bust_this_trx */
	  cli->cli_terminate_requested = 0;
	  at_printf (("host %d itc reset for anytime, dp %d inx %s %s\n", local_cll.cll_this_host, itc->itc_page, itc->itc_insert_key->key_name, cl_thr_stat ()));
	  longjmp_splice (itc->itc_fail_context, 1);
	}
      else
	cli_anytime_timeout (lt->lt_client);
    }
  if (CLI_TERMINATE == cli->cli_terminate_requested)
    {
      lt->lt_status = LT_BLOWN_OFF;
      if (itc)
	itc_bust_this_trx (itc, buf, ITC_BUST_THROW);
      sqlr_new_error ("S1T00", "CLI..", "Client cancelled or disconnected");
    }
}


void
qn_input (data_source_t * xx, caddr_t * inst, caddr_t * state)
{
  query_instance_t *qi = (query_instance_t *) inst;
  client_connection_t * cli = qi->qi_client;
  if (cli->cli_ws && cli_check_ws_terminate (cli))
    cli->cli_terminate_requested = CLI_TERMINATE;
  if (cli->cli_terminate_requested)
    {
      if (CLI_RESULT == cli->cli_terminate_requested)
	cli_anytime_timeout (cli);
      longjmp_splice (qi->qi_thread->thr_reset_ctx, RST_KILLED);
    }
  if (!xx)
    return;	/* a cached query recomp'd for schema effect can have a null  head node */
  if (state && xx->src_pre_code)
    code_vec_run (xx->src_pre_code, state);
  if (xx->src_local_save)
    {
      if (state)
	qn_set_local_save (xx, inst);
      else
	qn_restore_local_save (xx, inst);
    }
  xx->src_input (xx, inst, state);
}


/* If some state token was sent to some but not to all,
   send to the rest.
 */


/* The min function for passing state on in the graph */

void
qn_send_output (data_source_t * src, caddr_t * state)
{
  dk_set_t next = src->src_continuations;
  if (src->src_after_test &&
      !code_vec_run (src->src_after_test, state))
    {
      return;
    }
  if (src->src_after_code)
    code_vec_run (src->src_after_code, state);
  SRC_COUNT (src, state);
  if (!next)
    {
      return;
    }
  if (!next->next)
    {
      if (src->src_local_save)
	qn_set_local_save (src, state);
      qn_input ((data_source_t *) next->data, state, state);
      if (src->src_local_save)
	qn_restore_local_save (src, state);
    }
  else
    {
      GPF_T1 ("Node with more than 1 successor");
    }
}


void
qn_ts_send_output (data_source_t * src, caddr_t * state,
    code_vec_t after_join_test)
{
  dk_set_t next = src->src_continuations;
  if (after_join_test
      && !code_vec_run (after_join_test, state))
    {
      return;
    }
  if (src->src_after_code)
    code_vec_run (src->src_after_code, state);
  SRC_COUNT (src, state);
  if (!next)
    {
      return;
    }
  if (!next->next)
    {
      qn_input ((data_source_t *) next->data, state, state);
      if (src->src_local_save)
	qn_restore_local_save (src, state);
    }
  else
    {
      GPF_T1 ("Node with more than 1 successor");
    }
}


caddr_t *
qn_get_in_state (data_source_t * src, caddr_t * inst)
{
  caddr_t *ste;
  ste = SRC_IN_STATE (src, inst);
  if (ste)
    {
      SRC_IN_STATE (src, inst) = NULL;
    }
  return ste;
}


void
qn_record_in_state (data_source_t * src, caddr_t * inst, caddr_t * state)
{
  /* if ( SRC_IN_STATE(src, inst)) GPF_T1 ("Push two states for one ts"); */
  SRC_IN_STATE (src, inst) = state;
}


void
sp_bind_ssl (db_buf_t * place, state_slot_t * ssl, caddr_t * state)
{
  /* if there's a ref count dereference */

  *place = (db_buf_t) qst_get (state, ssl);
}


int
ks_search_param_wide (it_cursor_t * itc, search_spec_t * sp, caddr_t data, dtp_t dtp)
{
  if (DV_DB_NULL ==dtp)
    return KS_CAST_NULL;
  if (dtp != DV_LONG_WIDE && dtp != DV_WIDE)
    {
      caddr_t err = NULL;
      caddr_t utf_data;
      data = box_cast_to (itc->itc_out_state, data, dtp, DV_LONG_WIDE,
			  sp->sp_cl.cl_sqt.sqt_precision, sp->sp_cl.cl_sqt.sqt_scale, &err);
      if (err)
	{
	  query_instance_t * qi = (query_instance_t *) itc->itc_out_state;
	  if (qi->qi_no_cast_error)
	    {
	      /* cast failure and not signaled.  In rdf inx merge, cmp of any and iri
	       * with non-iri param.  Return flag to show whether the ANY in any sort order is below, in which case continue, or above, in which case stop */
	      dk_free_tree (err);
	      if (IS_NUM_DTP (dtp))
		dtp = DV_LONG_INT;
	      return (dtp < DV_LONG_WIDE ? KS_CAST_DTP_LT : KS_CAST_DTP_GT);
	    }
	  else
	    sqlr_resignal (err);
	}
      utf_data = box_wide_as_utf8_char (data, box_length (data) / sizeof (wchar_t) - 1, DV_LONG_STRING);
      dk_free_box (data);
      data = utf_data;
    }
  else
    data = box_wide_as_utf8_char (data, box_length (data) / sizeof (wchar_t) - 1, DV_LONG_STRING);
  ITC_SEARCH_PARAM (itc, data);
  ITC_OWNS_PARAM (itc, data);
  return KS_CAST_OK;
}


#define ITC_COPY_PARAM(itc, data) \
{\
  if (itc->itc_ks && itc->itc_ks->ks_copy_search_pars)\
    {\
      data = box_copy_tree (data);\
      ITC_SEARCH_PARAM (itc, data);\
      ITC_OWNS_PARAM (itc, data);\
    }\
  else\
    {\
      ITC_SEARCH_PARAM (itc, data);\
    } \
}

int
ks_search_param_cast (it_cursor_t * itc, search_spec_t * sp, caddr_t data)
{
  caddr_t err = NULL;
  dtp_t target_dtp = sp->sp_cl.cl_sqt.sqt_dtp;
  dtp_t dtp = DV_TYPE_OF (data);

  if (DV_DB_NULL == dtp)
    return KS_CAST_NULL;

  switch (target_dtp)
    {
      case DV_WIDE:
      case DV_LONG_WIDE:
	  return ks_search_param_wide (itc, sp, data, dtp);
      case DV_INT64:
      case DV_SHORT_INT: target_dtp = DV_LONG_INT; break;
      case DV_IRI_ID_8: target_dtp = DV_IRI_ID;
    }

  if (IS_UDT_DTP (target_dtp))
    {
      char* cl_name = __get_column_name (sp->sp_cl.cl_col_id,
	  itc->itc_insert_key ? itc->itc_insert_key : itc->itc_row_key);
      sqlr_new_error ("22023", "SR446",
	  "User defined type columns cannot be used in the WHERE, HAVING, or ON clause "
	  "except for the IS NULL predicate "
	  "for column '%s'", cl_name);
    }
  else if (dtp == target_dtp)
    {
      ITC_COPY_PARAM (itc, data);
      return KS_CAST_OK;
    }
  else if (DV_ANY == target_dtp)
    {
#if 0
      if (itc_try_inline_any (itc, data))
	return KS_CAST_OK;
#endif
      data = box_to_any (data, &err);
      if (err)
	sqlr_resignal (err);
      ITC_SEARCH_PARAM (itc, data);
      ITC_OWNS_PARAM (itc, data);
      return KS_CAST_OK;
    }
  DTP_NORMALIZE (dtp);
  DTP_NORMALIZE (target_dtp);
  if (CMP_LIKE == sp->sp_min_op)
    {
      switch (target_dtp)
	{
	  case DV_BLOB: target_dtp = DV_STRING; break;
	  case DV_BLOB_WIDE: target_dtp = DV_LONG_WIDE; break;
	}
    }
  if (dtp == target_dtp)
    {
      ITC_COPY_PARAM (itc, data);
      return KS_CAST_OK;
    }
  switch (target_dtp)
    {
    case DV_BLOB: case DV_BLOB_BIN: case DV_BLOB_WIDE: case DV_BLOB_XPER:
      if (dtp != DV_DB_NULL)
	{
	  char* cl_name = __get_column_name (sp->sp_cl.cl_col_id,
	      itc->itc_insert_key ? itc->itc_insert_key : itc->itc_row_key);
	    sqlr_new_error ("22023", "SR347",
		"The long varchar, long varbinary and long nvarchar "
		"data types cannot be used in the WHERE, HAVING, or ON clause, "
		"except with the IS NULL predicate for column '%s'", cl_name);
	}
      break;
	  /* compare different number types.  If col more precise than arg, cast to col here, otherwise the cast is in itc_col_check.
	  * if param is more precise, disable any inlined compare funcs since they do not cast. */
	    case DV_LONG_INT:
      if (!IS_NUM_DTP (dtp))
        break;
	      ITC_COPY_PARAM (itc, data); /* all are more precise, no cast down */
	      itc->itc_key_spec.ksp_key_cmp = NULL;
      return KS_CAST_OK;
	    case DV_SINGLE_FLOAT:
      if ((DV_LONG_INT == dtp) || !IS_NUM_DTP (dtp))
        break;
	      ITC_COPY_PARAM (itc, data);
	      itc->itc_key_spec.ksp_key_cmp = NULL;
      return KS_CAST_OK;
	    case DV_DOUBLE_FLOAT:
      break;
	    case DV_NUMERIC:
      if (DV_DOUBLE_FLOAT != dtp)
        break;
		  ITC_COPY_PARAM (itc, data);
		  itc->itc_key_spec.ksp_key_cmp = NULL;
      return KS_CAST_OK;
/* same is for dates/datetime pair */
    case DV_DATE:
      if (DV_DATETIME != dtp)
        break;
      ITC_COPY_PARAM (itc, data);
      itc->itc_key_spec.ksp_key_cmp = NULL;
      return KS_CAST_OK;
	}
      data = box_cast_to (itc->itc_out_state, data, dtp, target_dtp,
			  sp->sp_cl.cl_sqt.sqt_precision, sp->sp_cl.cl_sqt.sqt_scale, &err);
      if (err || (DV_DB_NULL == DV_TYPE_OF (data)))
	{
	  query_instance_t * qi = (query_instance_t *) itc->itc_out_state;
	  if (qi->qi_no_cast_error)
	    {
	      /* cast failure and not signaled.  In rdf inx merge, cmp of any and iri
	       * with non-iri param.  Return flag to show whether the ANY in any sort order is below, in which case continue, or above, in which case stop */
	      dk_free_tree (err);
	      if (IS_NUM_DTP (dtp))
		dtp = DV_LONG_INT;
	      if (IS_NUM_DTP (target_dtp))
		target_dtp = DV_LONG_INT;
              if (DV_DB_NULL == DV_TYPE_OF (data))
                dk_free_box (data);
	      return (dtp < target_dtp ? KS_CAST_DTP_LT : KS_CAST_DTP_GT);
	    }
	  else
	    sqlr_resignal (err);
	}
      ITC_SEARCH_PARAM (itc, data);
      ITC_OWNS_PARAM (itc, data);

  return KS_CAST_OK;
}

static int
ks_search_param_update (it_cursor_t * itc, search_spec_t * ks_spec, caddr_t itc_val, caddr_t val, int par_inx)
{
  short sav_par_fill = itc->itc_search_par_fill;
  short inx, sav_own_par_fill = -1;
  int res = KS_CAST_OK;

  if (itc_val == val)
    return res;

  /* If the values are different, save the itc_search_par_fill & itc_owned_search_par_fill,
     free the owned one if such and set to NULL
     call  the ks_search_param_cast & restore the fill.
   */
  for (inx = 0 ; inx < itc->itc_owned_search_par_fill; inx ++)
    {
      caddr_t own_par = itc->itc_owned_search_params[inx];
      if (own_par == itc_val)
	{
	  /*fprintf (stderr, "own param=%p, pos=%d, curr_own_fill=%d\n", own_par, inx, itc->itc_owned_search_par_fill);*/
	  itc->itc_owned_search_params[inx] = NULL;
	  dk_free_tree (own_par);
	  sav_own_par_fill = itc->itc_owned_search_par_fill;
	  itc->itc_owned_search_par_fill = inx;
	  break;
	}
      else if (!own_par && sav_own_par_fill < 0)
	{
	  sav_own_par_fill = itc->itc_owned_search_par_fill;
	  itc->itc_owned_search_par_fill = inx;
	}
    }
  itc->itc_search_par_fill = par_inx;
  res = ks_search_param_cast (itc, ks_spec, val);

  /*fprintf (stderr, "itc_val != val rc=%d owned_fill=%d old_own_fill=%d fill=%d old_fill=%d\n",
      res, itc->itc_owned_search_par_fill, sav_own_par_fill, itc->itc_search_par_fill, sav_par_fill); */

  itc->itc_search_par_fill = sav_par_fill;
  if (sav_own_par_fill >= 0 && itc->itc_owned_search_par_fill < sav_own_par_fill)
    itc->itc_owned_search_par_fill = sav_own_par_fill;

  return res;
}

void
ks_check_params_changed (it_cursor_t * itc, key_source_t * ks, caddr_t * state)
{
  search_spec_t * ks_spec = ks->ks_spec.ksp_spec_array;
  while (ks_spec)
    {
      caddr_t val;
      caddr_t itc_val;

      if (ks_spec->sp_min_ssl)
	{
	  itc_val = itc->itc_search_params[ks_spec->sp_min];
	  val = QST_GET (state, ks_spec->sp_min_ssl);
	  ks_search_param_update (itc, ks_spec, itc_val, val, ks_spec->sp_min);
	}
      if (ks_spec->sp_max_ssl)
	{
	  itc_val = itc->itc_search_params[ks_spec->sp_max];
	  val = QST_GET (state, ks_spec->sp_max_ssl);
	  ks_search_param_update (itc, ks_spec, itc_val, val, ks_spec->sp_max);
	}
      ks_spec = ks_spec->sp_next;
    }
}

int
ks_make_spec_list (it_cursor_t * it, search_spec_t * ks_spec, caddr_t * state)
{
  int res;
  while (ks_spec)
    {
      caddr_t val;
      if (ks_spec->sp_min_ssl)
	{
	  val = QST_GET (state, ks_spec->sp_min_ssl);
	  res = ks_search_param_cast (it, ks_spec, val);
	  if (res)
	    return res;
	}
      if (ks_spec->sp_max_ssl)
	{
	  val = QST_GET (state, ks_spec->sp_max_ssl);
	  res = ks_search_param_cast (it, ks_spec, val);
	  if (res)
	    return res;
	}
      ks_spec = ks_spec->sp_next;
    }
  return KS_CAST_OK;
}


int
itc_from_sort_temp (it_cursor_t * itc, query_instance_t * qi, state_slot_t * it_ssl)
{
  caddr_t * qst = (caddr_t *) qi;
  index_tree_t * it = (index_tree_t *) QST_GET_V (qst, it_ssl);
  if (!it)
    return 0;
  itc_from_it (itc, it);
  itc->itc_isolation = ISO_UNCOMMITTED;
  itc->itc_ltrx = qi->qi_trx;
  return 1;
}


#ifdef DEBUG
void
sp_print_specs (search_spec_t * sp)
{
  while (sp)
    {
      dbg_printf ((" %d", sp->sp_min_op));
      dbg_print_box ((caddr_t) (long) sp->sp_min, stdout);
      sp = sp->sp_next;
    }
  dbg_printf (("\n"));
}
#endif


#ifdef MTX_DEBUG
void
itc_assert_no_reg (it_cursor_t * itc)
{
  buffer_desc_t * buf;
  if (itc->itc_is_registered || itc->itc_buf_registered) GPF_T1 ("itc not supposed to be registered");
  ITC_IN_KNOWN_MAP (itc, itc->itc_page);
  buf = IT_DP_TO_BUF (itc->itc_tree, itc->itc_page);
  if (buf)
    {
      it_cursor_t * reg;
      for (reg  = buf->bd_registered; reg; reg = reg->itc_next_on_page)
	if (itc == reg) GPF_T1 ("itc was supposed not to be registered but was found in the registered list of its buf");
    }
  ITC_LEAVE_MAPS (itc);
}
#endif


int
ks_start_search (key_source_t * ks, caddr_t * inst, caddr_t * state,
    it_cursor_t * itc, buffer_desc_t ** buf_ret, table_source_t * ts,
    int search_mode)
{
  query_t * qr;
  char must_find;
  int is_nulls = 0;
  query_instance_t *qi = (query_instance_t *) inst;

  buffer_desc_t *buf;

  itc->itc_cl_qf_any_passed = 0;
  itc->itc_ks = ks;
  itc->itc_out_state = state;
  itc->itc_key_spec = ks->ks_spec;
  if (ks->ks_from_temp_tree)
    {
      if (! itc_from_sort_temp (itc, qi, ks->ks_from_temp_tree))
	return 0;
    }
  else
    {
      itc_from (itc, ks->ks_key);
      itc->itc_search_mode = search_mode;
      itc->itc_insert_key = ks->ks_key;
      itc->itc_desc_order = ks->ks_descending;
      itc->itc_is_vacuum = ks->ks_is_vacuum;
      itc_free_owned_params (itc);
      ITC_START_SEARCH_PARS (itc);
      is_nulls = ks_make_spec_list (itc, ks->ks_spec.ksp_spec_array, state);
      is_nulls |= ks_make_spec_list (itc, ks->ks_row_spec, state);
      if (is_nulls)
	return 0;
      itc->itc_row_specs = ks->ks_row_spec;
      qr = ts->src_gen.src_query;
      if (qr->qr_select_node
	  && ts->src_gen.src_query->qr_lock_mode != PL_EXCLUSIVE)
	{
	  itc->itc_lock_mode = qi->qi_lock_mode;
	}
      else if (qr->qr_qf_id)
	itc->itc_lock_mode = qr->qr_lock_mode;
      else
	itc->itc_lock_mode = PL_EXCLUSIVE;
	/* if the statement is not a SELECT, take excl. lock */
      itc->itc_isolation = qi->qi_isolation;
    }

  DO_SET (state_slot_t*, ssl, &ks->ks_always_null)
    {
      qst_set_bin_string (itc->itc_out_state, ssl, (db_buf_t) "", 0, DV_DB_NULL);
    }
  END_DO_SET();

  ITC_FAIL (itc)
  {
    if (ks->ks_init_place && !inst[ks->ks_init_used])
      {
	placeholder_t *pl =
	    (placeholder_t *) QST_GET (state, ks->ks_init_place);
	if (!pl)
	  sqlr_new_error ("HY001", "SR196", "No place in from_position clause.");
	buf = itc_set_by_placeholder (itc, pl);
	inst[ks->ks_init_used] = (caddr_t) 1L;
      }
    else
      {
	buf = itc_reset (itc);
      }

    must_find = qi->qi_assert_found;
    qi->qi_assert_found = 0;

    FAILCK (itc);
    if (DVC_MATCH == itc_next (itc, &buf))
      {
	/* Stash the cursor into the state and return */
	*buf_ret = buf;
	ITC_ABORT_FAIL_CTX (itc);
	return 1;
      }
    else
      {
#ifdef DEBUG
	if (0)
	  {
	    sp_print_specs (itc->itc_key_spec.ksp_spec_array);
	  }
#endif
	if (must_find)
	  GPF_T1 ("search missed after __assert_found");
	itc_page_leave (itc, buf);
	return 0;
      }
  }
  ITC_FAILED
    itc_assert_no_reg (itc);
  {
  }
  END_FAIL (itc);
  return 0;			/* never executed */
}


int
ks_main_row (key_source_t * ks, caddr_t * inst, caddr_t * state,
	     it_cursor_t * itc, buffer_desc_t ** buf_ret, table_source_t * ts)
{
  int is_nulls = 0;
  query_instance_t *qi = (query_instance_t *) inst;
  itc->itc_ks = ks;
  itc->itc_out_state = state;
  itc_from (itc, ks->ks_key);
  itc->itc_search_mode = SM_READ_EXACT;
  itc->itc_insert_key = ks->ks_key;
  itc->itc_key_spec = ks->ks_spec;
  itc_free_owned_params (itc);
  ITC_START_SEARCH_PARS (itc);
  is_nulls = ks_make_spec_list (itc, ks->ks_spec.ksp_spec_array, state);
  is_nulls |= ks_make_spec_list (itc, ks->ks_row_spec, state);
  if (is_nulls)
    return 0;
  itc->itc_row_specs = ks->ks_row_spec;
  if (ts->src_gen.src_query->qr_select_node
      && ts->src_gen.src_query->qr_lock_mode != PL_EXCLUSIVE)
    {
      itc->itc_lock_mode = qi->qi_lock_mode;
    }
  else
    itc->itc_lock_mode = PL_EXCLUSIVE;
  /* if the statement is not a SELECT, take excl. lock */
  itc->itc_isolation = qi->qi_isolation;


  DO_SET (state_slot_t*, ssl, &ks->ks_always_null)
    {
      qst_set_bin_string (itc->itc_out_state, ssl, (db_buf_t) "", 0, DV_DB_NULL);
    }
  END_DO_SET();

  ITC_FAIL (itc)
    {
      int rc;
      rc = itc_il_search (itc, buf_ret, state, &ts->ts_il,
			  (placeholder_t*) (ts->ts_current_of ? qst_get (state, ts->ts_current_of) : NULL), 0);

      if (DVC_MATCH == rc)
	{
	ITC_ABORT_FAIL_CTX (itc);
	return 1;
      }
    else
      {
	itc_page_leave (itc, *buf_ret);
	return 0;
      }
  }
  ITC_FAILED
  {
  }
  END_FAIL (itc);
  return 0;			/* never executed */
}


void
ts_set_placeholder (table_source_t * ts, caddr_t * state,
		    it_cursor_t * itc, buffer_desc_t ** buf_ret)
{
  query_instance_t *qi;
  if (ts->ts_current_of)
    {
      inx_locality_t * il = &ts->ts_il;
      int locality = 0;

      if (ts->ts_main_ks)
	{
	  ptrlong n = QST_PLONG (state, il->il_n_read);
	  ptrlong hits = QST_PLONG (state, il->il_n_hits);
	  if (!il->il_n_read) GPF_T;
	  if (n > 3 && n / (hits | 1) < 3)
	    locality = 1;
	}
      qi = (query_instance_t *) QST_INSTANCE (state);
      if (ts->src_gen.src_query->qr_no_co_if_no_cr_name &&
	  !locality &&
	  qi->qi_cursor_name &&
	  ts->ts_no_blobs &&
	  0 == strcmp (qi->qi_stmt->sst_id, qi->qi_cursor_name))
	/* called from client, no blobs, no SQLSetCursorName */
	return;
      {
	placeholder_t *old_pl =
	    (placeholder_t *) QST_GET_V (state, ts->ts_current_of);
	if (old_pl)
	  {
	    old_pl->itc_is_on_row = 1;
	    if (old_pl->itc_page == itc->itc_page)
	      old_pl->itc_map_pos = itc->itc_map_pos;
	    else
	      {
		itc->itc_is_on_row = 1;
		ITC_FAIL (itc)
		  {
		    itc_unregister_while_on_page ((it_cursor_t *) old_pl, itc, buf_ret);
		  }
		ITC_FAILED
		  {
		  }
		END_FAIL (itc);
		old_pl->itc_is_on_row = itc->itc_is_on_row;
		old_pl->itc_page = itc->itc_page;
		old_pl->itc_map_pos = itc->itc_map_pos;
		itc_register ((it_cursor_t *) old_pl, *buf_ret);
	      }
	    old_pl->itc_bp = itc->itc_bp;
	  }
	else
	  {
	    NEW_PLH (pl);
	    memcpy (pl, itc, ITC_PLACEHOLDER_BYTES);
	    pl->itc_type = ITC_PLACEHOLDER;
	    itc_register ((it_cursor_t *) pl, *buf_ret);
	    qst_set (state, ts->ts_current_of, (caddr_t) pl);
	  }
      }
    }
}


void
ts_outer_output (table_source_t * ts, caddr_t * qst)
{
  if (!ts->ts_is_outer)
    return;
  if (ts->ts_inx_op)
    {
      int inx;
      inx_op_t * iop = ts->ts_inx_op;
      DO_BOX (inx_op_t *, term, inx, iop->iop_terms)
	{
	  DO_SET (state_slot_t *, sl, &term->iop_ks->ks_out_slots)
	    {
	      qst_set_bin_string (qst, sl, (db_buf_t) "", 0, DV_DB_NULL);
	    }
	  END_DO_SET ();
	}
      END_DO_BOX;
    }
  else
    {
      DO_SET (state_slot_t *, sl, &ts->ts_order_ks->ks_out_slots)
	{
	  qst_set_bin_string (qst, sl, (db_buf_t) "", 0, DV_DB_NULL);
	}
      END_DO_SET ();
    }
  if (ts->ts_main_ks)
    {
      DO_SET (state_slot_t *, sl, &ts->ts_main_ks->ks_out_slots)
      {
	qst_set_bin_string (qst, sl, (db_buf_t) "", 0, DV_DB_NULL);
      }
      END_DO_SET ();
    }
    qn_ts_send_output ((data_source_t *) ts, qst, ts->ts_after_join_test);
}


void
table_source_input (table_source_t * ts, caddr_t * inst,
    caddr_t * volatile state)
{
  volatile int any_passed = 1;
  query_instance_t *qi = (query_instance_t *) inst;
  int rc, start;
  if (ts->ts_alternate_test && ts->ts_alternate_test (ts, inst, state))
    return;
  if (ts->ts_inx_op)
    {
      inx_op_source_input (ts, inst, state);
      return;
    }
  for (;;)
    {
      buffer_desc_t *order_buf = NULL, *main_buf = NULL;
      it_cursor_t *volatile main_itc = NULL, *volatile order_itc;
      if (!state)
	{
	  start = 0;
	  state = SRC_IN_STATE (ts, inst);
	  if (!state)
	    return;
	}
      else
	start = 1;
      order_itc = TS_ORDER_ITC (ts, state);
      if (start)
	{
	  SRC_IN_STATE (ts, inst) = inst; /* for anytime break, must know if being run */
	  if (!order_itc)
	    {
	      order_itc = itc_create (NULL, qi->qi_trx);
	      TS_ORDER_ITC (ts, state) = order_itc;
	    }
	  any_passed = 0;
	  if (ts->ts_is_random)
	    {
	      static caddr_t rate_name = NULL;
	      static caddr_t est_name = NULL;
	      caddr_t fbox;
	      unsigned int64 row_est = key_count_estimate (ts->ts_order_ks->ks_key, 3, 0);
	      itc_clear_stats (order_itc);
	      if (!est_name)
		{
		  est_name = box_dv_short_string ("row-count-estimate");
		  rate_name = box_dv_short_string ("rnd-stat-rate");
		}
	      fbox = box_float (row_est);
	      connection_set (qi->qi_client, est_name, fbox);
	      dk_free_box (fbox);
	      if (row_est < 1000)
		{
		  fbox = box_float (1);
		  connection_set (qi->qi_client, rate_name, fbox);
		  dk_free_box (fbox);
		}
	      else
		{
		  float pct = (float) (ptrlong) ts->ts_rnd_pcnt;
		  order_itc->itc_random_search = RANDOM_SEARCH_ON;
		  if (pct)
		    pct = 1;
		  if (pct >= 30)
		    pct = 30;
		  order_itc->itc_st.sample_size = (((float) row_est) / 100) * pct;
		  if (order_itc->itc_st.sample_size < 200)
		    order_itc->itc_st.sample_size = 200;
		  else if (order_itc->itc_st.sample_size > 10000)
		    order_itc->itc_st.sample_size = 10000;
		  fbox = box_float ((float) row_est / (float) order_itc->itc_st.sample_size);
		  connection_set (qi->qi_client, rate_name, fbox);
		  dk_free_box (fbox);
		}
	    }
	  else
	    order_itc->itc_random_search = RANDOM_SEARCH_OFF;
	  rc = ks_start_search (ts->ts_order_ks, inst, state,
	      order_itc, &order_buf, ts,
	      ts->ts_is_unique ? SM_READ_EXACT : SM_READ);
	  TS_ORDER_ITC (ts, state) = order_itc;
	  if (!rc)
	    {
	      SRC_IN_STATE ( ts, inst) = NULL;
	      if (ts->ts_order_ks->ks_qf_output && order_itc->itc_cl_qf_any_passed)
		return; /* looks like e,empty set but stuff sent to qf client */
	      ts_outer_output (ts, inst);
	      return;
	    }
#ifndef NDEBUG
	  ITC_IN_KNOWN_MAP (order_itc, order_itc->itc_page);
	  itc_assert_lock (order_itc);
#endif
	  if (ts->ts_need_placeholder)
	    ts_set_placeholder (ts, inst, order_itc, &order_buf);
	  itc_register (order_itc, order_buf);
	  itc_page_leave (order_itc, order_buf);
	}
      else
	{
	  if (order_buf)
	    GPF_T;		/* TS loops back and order buf is set */
	  if (!order_itc->itc_is_registered)
	    {
	      log_error ("cursor not continuable as it is unregistered");
	      SRC_IN_STATE (ts, inst) = NULL;
	      return;
	    }
	  ITC_FAIL (order_itc)
	  {
	    order_buf = page_reenter_excl (order_itc);
	    if (DVC_MATCH == itc_next (order_itc, &order_buf))
	      {
#ifndef NDEBUG
		itc_assert_lock (order_itc);
#endif
		if (ts->ts_need_placeholder)
		  ts_set_placeholder (ts, inst, order_itc, &order_buf);
		itc_register (order_itc, order_buf);
		itc_page_leave (order_itc, order_buf);
	      }
	    else
	      {
		itc_page_leave (order_itc, order_buf);
		SRC_IN_STATE (ts, inst) = NULL;
		if (!any_passed)
		  ts_outer_output (ts, state);
		return;
	      }
	  }
	  ITC_FAILED
	  {
	  }
	  END_FAIL (order_itc);
	}

      if (ts->ts_main_ks)
	{
	  it_cursor_t main_itc_auto;
	  int rc;
	  main_itc = &main_itc_auto;
	  ITC_INIT (main_itc, qi->qi_space, qi->qi_trx);
	  rc = ks_main_row (ts->ts_main_ks, inst, state, main_itc,
			    &main_buf, ts);
#ifndef NDEBUG
	  itc_assert_lock (main_itc);
#endif
	  if (!rc)
	    {
#ifdef DEBUG
	      if (!ts->ts_main_ks->ks_row_spec &&
		  !ts->ts_main_ks->ks_local_test)
		{
		  /* no main row found, yet no special conditions on main rpw.
		     Integrity error */
		  dbg_printf (("Missed join to main row from %s\n",
		      ts->ts_order_ks->ks_key->key_name));
		}
#endif
	      state = NULL;
	      itc_free (main_itc);
	      continue;
	    }
	  else
	    {
	      /* We joined with the primary key row. */
	      ts_set_placeholder (ts, state, main_itc, &main_buf);
		itc_page_leave (main_itc, main_buf);
	      itc_free (main_itc);
	    }
	}
      if (!ts->src_gen.src_after_test
	  || code_vec_run (ts->src_gen.src_after_test, state))
	{
	  any_passed = 1;
#ifndef NDEBUG
	  /* if in state itc must be registered */
	  if (SRC_IN_STATE (ts, inst) != NULL && !order_itc->itc_is_registered)
	    GPF_T;
#endif
	  qn_ts_send_output ((data_source_t *) ts, state, ts->ts_after_join_test);
	}
      state = NULL;
    }
}


void
table_source_input_unique (table_source_t * ts, caddr_t * inst, caddr_t * state)
{
  query_instance_t *qi = (query_instance_t *) inst;
  int rc;

  buffer_desc_t *order_buf = NULL;
  it_cursor_t order_itc_auto;
  it_cursor_t *order_itc = &order_itc_auto;
  ITC_INIT (order_itc, qi->qi_space, qi->qi_trx);
  rc = ks_start_search (ts->ts_order_ks, inst, state,
      order_itc, &order_buf, ts,
      ts->ts_is_unique ? SM_READ_EXACT : SM_READ);
  itc_assert_no_reg (order_itc);
  if (!rc)
    {
      int any_passed = order_itc->itc_cl_qf_any_passed;
      itc_free (order_itc);
      if (ts->ts_order_ks->ks_qf_output && any_passed)
	return;
      ts_outer_output (ts, state);
      return;
    }

  ts_set_placeholder (ts, state, order_itc, &order_buf);

#ifndef NDEBUG
    itc_assert_lock (order_itc);
#endif
    itc_page_leave (order_itc, order_buf);
  qi_check_buf_writers ();
  itc_free (order_itc);

  if (!ts->src_gen.src_after_test ||
      code_vec_run (ts->src_gen.src_after_test, state))
    {
      qn_ts_send_output ((data_source_t *) ts, state, ts->ts_after_join_test);
    }
  else
    ts_outer_output (ts, state);
}


void
insert_node_run (insert_node_t * ins, caddr_t * inst, caddr_t * state)
{
  dbe_table_t *tb = ins->ins_table;

  it_cursor_t auto_itc;
  it_cursor_t *itc;
  LT_CHECK_RW (((query_instance_t *) inst)->qi_trx);

  itc = &auto_itc;
  ITC_INIT (itc, QI_SPACE (inst), QI_TRX (inst));

  ITC_FAIL (itc)
    {
      ins_key_t * prime_ik = ins->ins_keys[0];
      if (DVC_MATCH == key_insert (ins, state, itc, prime_ik))
	{
	  if (ins->ins_mode == INS_NORMAL)
	    {
	      itc_free (itc);
	      sqlr_new_error ("23000", "SR197", "Non unique primary key on %s.", tb->tb_name);
	    }
	}
      else
	{
	  int k;
	  QI_ROW_AFFECTED (inst);
	  itc_free_owned_params (itc);
	  for (k = 1; k < BOX_ELEMENTS_INT (ins->ins_keys); k++)
	    {
	      key_insert (ins, state, itc, ins->ins_keys[k]);
	      itc_free_owned_params (itc);
	    }
	}
    }
  ITC_FAILED
    {
      itc_free (itc);
    }
  END_FAIL (itc);
  itc_free (itc);
}

void
insert_node_input (insert_node_t * ins, caddr_t * inst, caddr_t * state)
{
  if (ins->ins_policy_qr)
    trig_call (ins->ins_policy_qr, inst, ins->ins_trigger_args, ins->ins_table);

  if (ins->ins_trigger_args)
    trig_wrapper (inst, ins->ins_trigger_args, ins->ins_table, TRIG_INSERT,
	(data_source_t *) ins, (qn_input_fn) insert_node_run);
  else
    {
      insert_node_run (ins, inst, state);
      if (cl_run_local_only || !ins->clb.clb_fill)
	{
	  ROW_AUTOCOMMIT (inst);
	}
    }
  if (state)
    qn_send_output ((data_source_t *) ins, inst);
}


int
itc_get_alt_key (it_cursor_t * del_itc, buffer_desc_t ** alt_buf_ret,
		 dbe_key_t * alt_key, row_delta_t * rd)
{
  int n_part = 0, rc;

  FAILCK (del_itc);
  itc_from (del_itc, alt_key);
  del_itc->itc_key_spec =  alt_key->key_insert_spec;
  del_itc->itc_search_mode = SM_INSERT;

  DO_SET (dbe_column_t *, col, &alt_key->key_parts)
  {
    int found = 0;
    caddr_t value = rd_col (rd, col->col_id, &found);
    if (!found)
      {
	if (col->col_non_null && col->col_default)
	  value = box_cast_to (NULL, col->col_default, DV_TYPE_OF (col->col_default), col->col_sqt.sqt_dtp, col->col_precision, col->col_scale, NULL);
        else
	  value = NEW_DB_NULL;
	ITC_OWNS_PARAM (del_itc, value);
      }
#if 0 /* the rb_value if dtp is any is serialized value, no need to serialize again */
    if (DV_ANY == col->col_sqt.sqt_dtp)
      {
	caddr_t err = NULL, any;
	any = box_to_any (value, &err);
	if (err)
	  {
	    /* never happens.  Get an any col value and can't re-serialize it.*/
	    return DVC_LESS;
	  }
	value = any;
	ITC_OWNS_PARAM (del_itc, any);
      }
#endif
    ITC_SEARCH_PARAM (del_itc, value);
    n_part++;
    if (n_part >= alt_key->key_n_significant)
      break;
  }
  END_DO_SET ();
  *alt_buf_ret = itc_reset (del_itc);
  rc = itc_search (del_itc, alt_buf_ret);
  if (rc == DVC_MATCH)
    {
      del_itc->itc_is_on_row = 1;
      itc_set_lock_on_row (del_itc, alt_buf_ret);
      if (!del_itc->itc_is_on_row)
	{
	  if (del_itc->itc_ltrx)
	    del_itc->itc_ltrx->lt_error = LTE_DEADLOCK;
	    /* not really, but just put something there. */
	  itc_bust_this_trx (del_itc, alt_buf_ret, ITC_BUST_THROW);
	}
      del_itc->itc_is_on_row = 1;	/* flag not set in SM_INSERT search */
    }
  return rc;
}


void
itc_delete_this (it_cursor_t * del_itc, buffer_desc_t ** del_buf,
    int res, int maybe_blobs)
{
  if (res == DVC_MATCH)
    {
      itc_delete (del_itc, del_buf, maybe_blobs);
      itc_page_leave (del_itc, *del_buf);
    }
  else
    {
      itc_page_leave (del_itc, *del_buf);
    }
}

void
delete_node_run (delete_node_t * del, caddr_t * inst, caddr_t * state)
{
  volatile int more_keys = 1;
  int res, log_flag = 0;
  placeholder_t *pl = (placeholder_t *) qst_place_get (state, del->del_place);
  query_instance_t *qi = (query_instance_t *) QST_INSTANCE (state);
  dbe_key_t *volatile cr_key = NULL;
  LOCAL_RD (rd);
  QI_CHECK_STACK (qi, &qi, DEL_STACK_MARGIN);
  if (!pl)
    sqlr_new_error ("HY109", "SR198", "Cursor not positioned on delete. %s",
	del->del_place->ssl_name);
  {
    buffer_desc_t *cr_buf, *main_buf, *del_buf;
    it_cursor_t cr_itc_auto;
    it_cursor_t main_itc_auto;
    it_cursor_t del_itc_auto;
    it_cursor_t *cr_itc = &cr_itc_auto;
    it_cursor_t *volatile main_itc = NULL;
    it_cursor_t *volatile del_itc = NULL;
    dbe_table_t *volatile tb = NULL;
    ITC_INIT (cr_itc, NULL, qi->qi_trx);
    ITC_FAIL (cr_itc)
    {

      cr_buf = itc_set_by_placeholder (cr_itc, pl);
      cr_itc->itc_lock_mode = PL_EXCLUSIVE;
      if (!cr_itc->itc_is_on_row)
	{
	  rdbg_printf (("Row to lock deld before coming to delete   T=%d L=%d pos=%d\n",
			TRX_NO (cr_itc->itc_ltrx), cr_itc->itc_page, cr_itc->itc_map_pos));
	  itc_page_leave (cr_itc, cr_buf);
	  sqlr_new_error ("HY109", "SR199",
	      "The cursor in positioned DELETE was not on any row.");
	  itc_free (cr_itc);
	  return;
	}
      /* always true and for update */
	{
	  itc_set_lock_on_row (cr_itc, &cr_buf);
	  if (!cr_itc->itc_is_on_row)
	    {
	      rdbg_printf (("Row to lock deld during wait on delete T=%d L=%d pos=%d\n",
			    TRX_NO (cr_itc->itc_ltrx), cr_itc->itc_page, cr_itc->itc_map_pos));
	      itc_page_leave (cr_itc, cr_buf);
	      itc_free (cr_itc);
	      return;
	    }
	  rdbg_printf (("Lock set on delete\n"));
	}
      cr_key = itc_get_row_key (cr_itc, cr_buf);
      if (!cr_key)
	sqlr_new_error ("42S12", "SR200", "The row being deleted has no valid key.");
      tb = cr_key->key_table;
      log_flag = (cr_key->key_partition || del->del_key_only) ? LOG_KEY_ONLY : 0;
      cr_itc->itc_row_key = cr_key;
      if (del->del_key_only && del->del_key_only->key_super_id != cr_itc->itc_row_key->key_super_id)
	{
	  itc_page_leave (cr_itc, cr_buf);
	  itc_free (cr_itc);
	  sqlr_new_error ("42000", "SR...", "Position of single key delete is not on the right key");
	}

      page_row_bm (cr_buf, cr_itc->itc_map_pos, &rd, RO_ROW, cr_itc);
      if (!tb->tb_keys->next || del->del_key_only)
	  more_keys = 0;
      if (cr_key->key_is_primary || del->del_key_only)
	{
	  log_delete (cr_itc->itc_ltrx, &rd, log_flag);
	}
      cr_itc->itc_insert_key = cr_key;
      itc_delete_this (cr_itc, &cr_buf, DVC_MATCH, MAYBE_BLOBS);
    }
    ITC_FAILED
    {
      itc_free (&cr_itc_auto);
      rd_free (&rd);
    }
    END_FAIL (cr_itc);
    if (del->del_key_only)
      {
	QI_ROW_AFFECTED (inst);
	rd_free (&rd);
	itc_free (cr_itc);
	return;
      }

    if (!cr_key->key_is_primary)
      {
	main_itc = &main_itc_auto;
	ITC_INIT (main_itc, QI_SPACE (inst), QI_TRX (inst));
	main_itc->itc_lock_mode = PL_EXCLUSIVE;
	ITC_LEAVE_MAPS (cr_itc);
	ITC_FAIL (main_itc)
	{
	  res = itc_get_alt_key (main_itc, &main_buf,
	      tb->tb_primary_key, &rd);
	  if (res == DVC_MATCH)
	    {
	      main_itc->itc_insert_key = main_itc->itc_row_key = itc_get_row_key (main_itc, main_buf);
	      tb = main_itc->itc_row_key->key_table;
	      /* the table could be different (subtable) from
		 that of the driving key's */
	      if (tb->tb_keys->next->next)
		{
		  rd_free (&rd);
		  page_row (main_buf, main_itc->itc_map_pos, &rd, RO_ROW);
		}
	      else
		{
		  rd_free (&rd);
		  page_row (main_buf, main_itc->itc_map_pos, &rd, RO_LEAF);
		  more_keys = 0;
		}
	      log_delete (main_itc->itc_ltrx, &rd, 0);
	      itc_delete_this (main_itc, &main_buf, res, MAYBE_BLOBS);
	    }
	  else
	    {
	      itc_page_leave (main_itc, main_buf);
	      rd_free (&rd);
	      sqlr_new_error ("42S12", "SR201", "Primary key not found in delete.");
	    }
	}
	ITC_FAILED
	{
	  rd_free (&rd);
	  itc_free (main_itc);
	  itc_free (cr_itc);
	}
	END_FAIL (main_itc);
      }
    else
      {
	main_itc = cr_itc;
	main_buf = cr_buf;
      }
    QI_ROW_AFFECTED (inst);
    cr_key->key_table->tb_count_delta--;
      if (more_keys)
      {
	del_itc = &del_itc_auto;
	ITC_INIT (del_itc, qi->qi_space, qi->qi_trx);
	del_itc->itc_lock_mode = PL_EXCLUSIVE;
	ITC_FAIL (del_itc)
	{
	  DO_SET (dbe_key_t *, key, &tb->tb_keys)
	  {
	    if (key == cr_key || KEY_PRIMARY == key->key_is_primary
		|| key->key_distinct)
	      goto next_key;
	    res = itc_get_alt_key (del_itc, &del_buf, key, &rd);
	    itc_delete_this (del_itc, &del_buf, res, NO_BLOBS);
	  next_key:;
	  }
	  END_DO_SET ();
	}
	ITC_FAILED
	{
	  if (cr_itc != main_itc)
	    itc_free (cr_itc);
	  itc_free (main_itc);
	  itc_free (&del_itc_auto);
	  rd_free (&rd);
	}
	END_FAIL (del_itc);
	itc_free (del_itc);
      }
    rd_free (&rd);
    itc_free (main_itc);
    if (cr_itc != main_itc)
      itc_free (cr_itc);
  }
}


void
delete_node_input (delete_node_t * del, caddr_t * inst, caddr_t * state)
{
  LT_CHECK_RW (((query_instance_t *) inst)->qi_trx);

  if (del->del_policy_qr)
    trig_call (del->del_policy_qr, inst, del->del_trigger_args, del->del_table);

  if (!del->del_trigger_args)
    {
      QNCAST (query_instance_t, qi, inst);
      delete_node_run (del, inst, state);
      if (ROW_AUTOCOMMIT_DUE (qi, del->del_table, 1000))
	ROW_AUTOCOMMIT (qi);
    }
  else
    trig_wrapper (inst, del->del_trigger_args, del->del_table,
	TRIG_DELETE, (data_source_t *) del, (qn_input_fn) delete_node_run);

  qn_send_output ((data_source_t *) del, state);
}


void
end_node_input (end_node_t * end, caddr_t * inst, caddr_t * state)
{
  qn_send_output ((data_source_t*) end, state);
}



void
op_node_input (op_node_t * op, caddr_t * inst, caddr_t * state)
{
  query_instance_t *qi = (query_instance_t *) inst;
  caddr_t arg_1 = op->op_arg_1 ? qst_get (state, op->op_arg_1) : NULL;

  switch (op->op_code)
    {
    case OP_STORE_TRIGGER:
    case OP_STORE_PROC:
      ddl_store_proc (state, op);
      break;

    case OP_STORE_METHOD:
      ddl_store_method (state, op);
      break;

    case OP_DROP_TRIGGER:
      ddl_drop_trigger (qi, arg_1);
      break;

    case OP_SHUTDOWN:
      sec_check_dba (qi, "SHUTDOWN");
      ddl_commit (qi);
      sf_shutdown (arg_1 ? box_dv_short_string (arg_1) : sf_make_new_log_name (wi_inst.wi_master), qi->qi_trx);
      break;

    case OP_CHECKPOINT:
	{
	  ddl_commit (qi);
	  sf_makecp (arg_1 ? box_dv_short_string (arg_1) : sf_make_new_log_name (wi_inst.wi_master),
	      qi->qi_trx, 0, 0);
	}
      break;

    case OP_BACKUP:
      db_backup (qi, arg_1);
      break;

    case OP_CHECK:
      db_check (qi);
      break;

    default:
      sqlr_new_error ("42000", "SR202", "Bad admin op code.");
    }
}



void
itc_make_deref_spec (it_cursor_t * itc, caddr_t * loc)
{
  int n_part = 0;
  key_id_t key_id = unbox (loc[0]);
  dbe_key_t * key = sch_id_to_key (wi_inst.wi_schema, key_id);
  itc->itc_row_key = key;
  DO_SET (dbe_column_t *, col, &key->key_parts)
    {
      caddr_t value = loc [1 + key_col_in_layout_seq (key, col)];
      ITC_SEARCH_PARAM (itc, value);
      n_part++;
      if (n_part >= key->key_n_significant)
	break;
    }
  END_DO_SET ();
  itc->itc_key_spec = key->key_insert_spec;
}


void
deref_node_input (deref_node_t * dn, caddr_t * inst, caddr_t * state)
{
  volatile int res = 0;
  query_instance_t *qi = (query_instance_t *) inst;
  it_cursor_t *volatile ref_itc = itc_create (NULL, qi->qi_trx);
  buffer_desc_t *ref_buf;
  caddr_t * id = (caddr_t*) qst_get (state, dn->dn_ref);
  dbe_key_t * key = NULL;

    {
      key_id_t key_id = unbox (id[0]);
      key = sch_id_to_key (wi_inst.wi_schema, key_id);
      if (!key)
	{
	  itc_free (ref_itc);
	  sqlr_new_error ("42000", "SR474", "Unknown key id %d. Skipping the row", (int) key_id);
	}
    }
  ref_itc->itc_lock_mode = qi->qi_lock_mode;
  ref_itc->itc_search_mode = SM_READ;
  itc_from (ref_itc, key);
  itc_make_deref_spec ((ITC) ref_itc,  id);
  ITC_FAIL (ref_itc)
  {
    ref_buf = itc_reset ((ITC) ref_itc);
    res = itc_search ((ITC) ref_itc, &ref_buf);
    if (res == DVC_MATCH)
      {
	if (dn->dn_place)
	  {
	    NEW_PLH (pl);
	    ITC_IN_KNOWN_MAP (ref_itc, ref_itc->itc_page);
	    memcpy (pl, (ITC) ref_itc, ITC_PLACEHOLDER_BYTES);
	    pl->itc_type = ITC_PLACEHOLDER;
	    itc_register ((it_cursor_t *) pl, ref_buf);
	    qst_set (state, dn->dn_place, (caddr_t) pl);
	  }
      }
    ITC_FAIL (ref_itc)
    {
      /* make new fail ctx because ref_itc may have been set above */
      itc_page_leave ((ITC) ref_itc, ref_buf);
    }
    ITC_FAILED
    {
      itc_free ((ITC) ref_itc);
    }
    END_FAIL (ref_itc);
  }
  ITC_FAILED
  {
    itc_free ((ITC) ref_itc);
  }
  END_FAIL (ref_itc);
  itc_free ((ITC) ref_itc);
  if (res == DVC_MATCH)
    {
      qn_send_output ((data_source_t *) dn, state);
    }
}


void
qi_clear_out_box (caddr_t * inst)
{
  query_instance_t *qi = (query_instance_t *) inst;
  query_t *qr = qi->qi_query;
  select_node_t *sel = qr->qr_select_node;
  if (sel)
    {
      caddr_t **box = (caddr_t **) inst[sel->sel_out_box];
      int fill = (int) (ptrlong) inst[sel->sel_out_fill];
      int inx;
      if (!box)
	return;
      for (inx = 0; inx < fill; inx++)
	{
	  if (box[inx])
	    sel_out_free (sel->sel_out_slots, box[inx]);
	}
      inst[sel->sel_out_fill] = NULL;
      inst[sel->sel_current_of] = NULL;
    }
}


void
qi_detach_from_stmt (query_instance_t * qi)
{
  ASSERT_IN_MTX (qi->qi_client->cli_mtx);

  /* must test again inside mtx */
  if (qi->qi_cursor_name)
    {
#ifdef DEBUG
      int rc =
#endif
      id_hash_remove (qi->qi_client->cli_cursors,
	  (caddr_t) &qi->qi_cursor_name);
      dk_free_box (qi->qi_cursor_name);
      qi->qi_cursor_name = NULL;
    }
  if (qi->qi_stmt)
    {
      srv_stmt_t *stmt = qi->qi_stmt;
      stmt->sst_inst = NULL;
      qi->qi_stmt = NULL;
    }
}


void
qi_free (caddr_t * inst)
{
  query_instance_t *qi = (query_instance_t *) inst;
  query_t *qr = qi->qi_query;
  if (qi->qi_lc)
    {
      if (qi->qi_lc->lc_cursor_name)
	{
	  IN_CLIENT (qi->qi_client);
	  id_hash_remove (qi->qi_client->cli_cursors, (caddr_t)&qi->qi_lc->lc_cursor_name);
	  LEAVE_CLIENT (qi->qi_client);
	}
      qi->qi_lc->lc_inst = NULL;
      /* do not re-free when freeing the lc. */
    }

  /* The statement may from now on do what it will.
     This thread has exclusive hand on the dying instance. */
  if ((qi->qi_icc_lock) ||
    ((NULL == qi->qi_caller) && (NULL != qi->qi_client->cli_icc_lock)) )
    {
      icc_lock_t *cli_lock = qi->qi_client->cli_icc_lock;
      icc_lock_release (cli_lock->iccl_name, qi->qi_client);
    }
#ifdef PLDBG
  if (IS_POINTER(qi->qi_client))
    {
      if (IS_POINTER (qi->qi_caller))
	qi->qi_client->cli_pldbg->pd_inst = qi->qi_caller;
      else
	qi->qi_client->cli_pldbg->pd_inst = NULL;
    }
#endif

  if (qr->qr_select_node)
    {
      qi_clear_out_box (inst);
    }
  qi_inst_state_free (inst);
  DO_SET (state_slot_t *, ssl, &qr->qr_temp_spaces)
    {
      index_tree_t *it = (index_tree_t *) QST_GET_V (inst, ssl);
      it_temp_free (it);
    }
  END_DO_SET();
  if (qi->qi_proc_ret)
    dk_free_tree (qi->qi_proc_ret);
  if (NULL != qi->qi_object_space)
    {
      udo_object_space_clear (qi->qi_object_space);
      SET_THR_ATTR (THREAD_CURRENT_THREAD, TA_OBJECT_SPACE_OWNER, NULL);
    }
  if (qi->qi_is_allocated)
    {
      dk_free_box ((caddr_t) inst);
    }
}


caddr_t
qi_out_box (query_instance_t * qi)
{
  return (((caddr_t) qi) + qi->qi_query->qr_instance_length);
}


caddr_t *
qi_alloc (query_t * qr, stmt_options_t * opts, caddr_t * auto_qi,
    int auto_qi_len)
{
  /* alloc the instance length + space for a select out box
     (= n prefetchable rows) */
  caddr_t ret;
  int len = qr->qr_instance_length;
  if (qr->qr_select_node)
    {
      if (opts && opts->so_prefetch > 0)
	    len += (int) (opts->so_prefetch * sizeof (caddr_t));
      else
	len += SELECT_PREFETCH_QUOTA * sizeof (caddr_t);
    }
  if (!auto_qi || len > auto_qi_len)
    {
      ret = dk_alloc_box (len, DV_ARRAY_OF_POINTER);
      memset (ret, 0, qr->qr_instance_length);
      ((query_instance_t *) ret)->qi_is_allocated = 1;
    }
  else
    {
      ret = (caddr_t) auto_qi;
      memset (ret, 0, qr->qr_instance_length);
    }
  return ((caddr_t *) ret);
}


void
skip_node_input (skip_node_t * sk, caddr_t * inst, caddr_t * qst)
{
  int64 rows = unbox (QST_GET_V (qst, sk->sk_row_ctr));
  int64 skip = unbox (QST_GET (qst, sk->sk_top_skip));
  if (skip < 0)
    sqlr_new_error ("22023", "SR349", "SKIP parameter < 0");
  qst_set_long (qst, sk->sk_row_ctr, 1 + rows);
  if (rows < skip)
    return;
  qn_send_output ((data_source_t *)sk, inst);
}

int cn_sets;

int
sel_top_count (select_node_t * sel, caddr_t * qst)
{
  if (sel->sel_row_ctr)
    {
      int64 rows = unbox (QST_GET_V (qst, sel->sel_row_ctr));
      int64 skip = sel->sel_top_skip ? (int64) unbox (QST_GET (qst, sel->sel_top_skip)) : 0;
      int64 top = unbox (QST_GET (qst, sel->sel_top));
      int skip_only = (top == -1 && skip >= 0 ? 1 : 0);
      if (skip < 0)
	sqlr_new_error ("22023", "SR349", "SKIP parameter < 0");
      if (top < 0 && !skip_only)
	sqlr_new_error ("22023", "SR350", "TOP parameter < 0");
      if (top >= 0 && rows - skip >= top)
	{
	  query_instance_t * qi = (query_instance_t *) qst;
	  subq_init (sel->src_gen.src_query, qst);
	  longjmp_splice (qi->qi_thread->thr_reset_ctx, RST_AT_END);
	}
      qst_set_long (qst, sel->sel_row_ctr, 1 + rows);
      if (skip && rows < skip)
	return 0;
    }
  return 1;
}


void
select_node_input_subq (select_node_t * sel, caddr_t * inst, caddr_t * state)
{
  query_instance_t *qi = (query_instance_t *) inst;
  if (sel->sel_set_no)
    {
      int prev_set = unbox (QST_GET_V (inst, sel->sel_prev_set_no));
      int set = unbox (QST_GET_V (inst, sel->sel_set_no));
      if (set != prev_set)
	{
	  qst_set_long (inst, sel->sel_prev_set_no, set);
	  if (sel->sel_row_ctr)
	    qst_set_long (inst, sel->sel_row_ctr, 0);
	}
    }
  if (!sel_top_count (sel, inst))
    return;
  longjmp_splice (qi->qi_thread->thr_reset_ctx, RST_ENOUGH);
}


void
select_node_input_scroll (select_node_t * sel, caddr_t * inst, caddr_t * state)
{
  query_instance_t *qi = (query_instance_t *) inst;
  if (qi->qi_lc)
    qi->qi_lc->lc_position = 0;
  /* initial = -1, no that's how you know if any when using lc. */
  /* Scroll cursors use qi_lc with this select node, not the regular one */
  longjmp_splice (qi->qi_thread->thr_reset_ctx, RST_ENOUGH);
}


void cli_send_row_count (client_connection_t * cli, long n_affected, caddr_t * ret, du_thread_t * thr);


void
select_node_input (select_node_t * sel, caddr_t * inst, caddr_t * state)
{
  int keep_co;
  caddr_t *out_copy;
  query_instance_t *qi = (query_instance_t *) inst;
  query_t *qr = qi->qi_query;
  caddr_t **box;
  volatile int fill = (int) (ptrlong) inst[sel->sel_out_fill];
  int quota = (int) (ptrlong) inst[sel->sel_out_quota];
  volatile int is_full = qi->qi_prefetch_bytes && qi->qi_bytes_selected > qi->qi_prefetch_bytes;
  if (sel->sel_set_no)
    {
      int prev_set = unbox (QST_GET_V (inst, sel->sel_prev_set_no));
      int set = unbox (QST_GET_V (inst, sel->sel_set_no));
      if (set != prev_set)
	{
	  int n, n_ends = prev_set - set;
	  qst_set_long (inst, sel->sel_prev_set_no, set);
	  if (sel->sel_row_ctr)
	    qst_set_long (inst, sel->sel_row_ctr, 0);
	  /* client doing a multistate array select, send a set marker when starting a new set */
	  for (n = 0; n < n_ends; n++)
	    cli_send_row_count (qi->qi_client, 0, NULL, THREAD_CURRENT_THREAD);
	}
    }
  if (!sel_top_count (sel, inst))
    return;
  if (qi->qi_caller == CALLER_CLIENT)
    {
      int slots = sel->sel_n_value_slots;
      int inx;
      volatile int any_blobs = 0;	/*AIX cc */
      volatile OFF_T b1 = 0, b2 = 0;
      PRPC_ANSWER_START (qi->qi_thread, PARTIAL);
      b1 = __ses->dks_bytes_sent;
      dks_array_head (__ses, slots + 1, DV_ARRAY_OF_POINTER);
      print_int (is_full ? QA_ROW_LAST_IN_BATCH : QA_ROW, __ses);
      for (inx = 0; inx < slots; inx++)
	{
	  caddr_t value = QST_GET (state, sel->sel_out_slots[inx]);
	  print_object (value, __ses, NULL, NULL);
	  if (IS_BLOB_HANDLE(value))
	    any_blobs = 1;
	}
      b2 = __ses->dks_bytes_sent;
      PRPC_ANSWER_END (0);
      qi->qi_bytes_selected += b2 - b1;
      if (quota == PREFETCH_ALL)
	return;
      keep_co = qr->qr_no_co_if_no_cr_name
	  ? qi->qi_cursor_name &&
	    0 != strcmp (qi->qi_cursor_name, qi->qi_stmt->sst_id)
	  : 1;
      if (keep_co || any_blobs)
	{
	  out_copy = sel_out_copy (sel->sel_out_slots, state, keep_co);
	}
      else
	out_copy = NULL;
      box = (caddr_t **) inst[sel->sel_out_box];
      if (!box)
	{
	  box = (caddr_t **) qi_out_box (qi);
	  inst[sel->sel_out_box] = (caddr_t) box;
	}
      box[fill++] = out_copy;
      inst[sel->sel_out_fill] = (caddr_t) (ptrlong) fill;
    }
  else
    {
      out_copy = sel_out_copy (sel->sel_out_slots, state, 0);
      box = (caddr_t **) inst[sel->sel_out_box];
      if (!box)
	{
	  box = (caddr_t **) qi_out_box (qi);
	  inst[sel->sel_out_box] = (caddr_t) box;
	}
      box[fill++] = out_copy;
      inst[sel->sel_out_fill] = (caddr_t) (ptrlong) fill;
    }

  if (quota != PREFETCH_ALL
      && (is_full || fill >= quota))
    {
      longjmp_splice (qi->qi_thread->thr_reset_ctx, RST_ENOUGH);
    }
}


int
box_is_string (char **box, char *str, int from, int len)
{
  int inx;
  for (inx = from; inx < len; inx++)
    if (box[inx] && 0 == strcmp (box[inx], str))
      return 1;
  return 0;
}

void
gs_union_node_input (gs_union_node_t * gsu, caddr_t * inst, caddr_t * state)
{
  int inx;
  for (;;)
    {
      dk_set_t out_list = gsu->gsu_cont;
      data_source_t * ds;
      int nth;
      if (!state)
	{
	  state = qn_get_in_state ((data_source_t *) gsu, inst);
	  nth = (int) unbox (qst_get (state, gsu->gsu_nth));
	}
      else
	{
	  qst_set (inst, gsu->gsu_nth, box_num (0));
	  nth = 0;
	}
      for (inx = 0; inx < nth; inx++)
	{
	  if (out_list)
	    out_list = out_list->next;
	  if (!out_list)
	    break;
	}
      if (!out_list)
	{
	  qn_record_in_state ((data_source_t *) gsu, inst, NULL);
	  qst_set (inst, gsu->gsu_nth, box_num (0));
	  return;
	}
      qst_set (inst, gsu->gsu_nth, box_num (nth + 1));
      qn_record_in_state ((data_source_t *) gsu, inst, inst);
      ds = (data_source_t*) out_list->data;
      qn_input (ds, inst, inst);
      state = NULL;
    }
}

void
gs_union_free (gs_union_node_t * gsu)
{
  dk_set_free (gsu->gsu_cont);
}


void
fun_ref_set_defaults_and_counts (fun_ref_node_t *fref, caddr_t * inst, caddr_t * state)
{
  s_node_t *val_set = fref->fnr_default_values;

  DO_SET (state_slot_t *, ct, &fref->fnr_default_ssls)
    {
      caddr_t def = (caddr_t) val_set->data;
      if (-1 == unbox (def))
	qst_set_long (inst, ct, QST_INT (inst, fref->fnr_is_any));
      else if (!QST_INT (inst, fref->fnr_is_any)/* ||
	  (QST_GET (inst, ct) == NULL && DV_DB_NULL == DV_TYPE_OF (def))*/)
	qst_set (state, ct, box_copy_tree (def));
      val_set = val_set->next;
    }
  END_DO_SET ();
}


#define FREF_SINGLE_ANYTIME_FINISH ((caddr_t*)-1)

void
fun_ref_node_input (fun_ref_node_t * fref, caddr_t * inst, caddr_t * state)
{
  if (FREF_SINGLE_ANYTIME_FINISH  == state)
    {
      state = inst;
      goto fref_at_finish;
    }
  if (!state)
    {
      setp_node_t * setp = fref->fnr_setp;
      hash_area_t * ha = setp->setp_ha;
      itc_ha_flush_memcache (ha, inst);
      setp_mem_sort_flush (setp, inst);
      qn_record_in_state ((data_source_t *) fref, inst, NULL);
      return;
    }
  if (fref->fnr_is_any)
    QST_INT (inst, fref->fnr_is_any) = 0;
  DO_SET (state_slot_t *, temp, &fref->fnr_temp_slots)
  {
    qst_set (state, temp, NULL);
  }
  END_DO_SET ();
  if (fref->fnr_is_any)
    fun_ref_set_defaults_and_counts (fref, inst, state);
  if (fref->fnr_setp)
    qn_record_in_state ((data_source_t *) fref, inst, inst);
  qn_input (fref->fnr_select, inst, state);
  qn_record_in_state ((data_source_t *) fref, inst, NULL);
  qr_resume_pending_nodes (fref->src_gen.src_query, inst);
 fref_at_finish:
  if (fref->fnr_setp)
    {
      setp_node_t * setp = fref->fnr_setp;
      hash_area_t * ha = setp->setp_ha;
      if (HA_FILL != ha->ha_op)
	itc_ha_flush_memcache (ha, inst);
      setp_filled (setp, state);
      setp_mem_sort_flush (setp, state);
      if (setp->setp_ordered_gb_fref)
	return;
    }
  DO_SET (setp_node_t *, setp, &fref->fnr_setps)
  {
    hash_area_t * ha = setp->setp_ha;
    itc_ha_flush_memcache (ha, inst);
    setp_filled (setp, state);
    setp_mem_sort_flush (setp, state);
    if (setp->setp_ordered_gb_fref)
      return;
  }
  END_DO_SET();
  if (fref->fnr_is_any)
    fun_ref_set_defaults_and_counts (fref, inst, state);
  qn_send_output ((data_source_t *) fref, state);
}


void
ddl_node_input (ddl_node_t * ddl, caddr_t * inst, caddr_t * state)
{
  query_instance_t *qi = (query_instance_t *) inst;
  caddr_t *stmt = ddl->ddl_stmt;
  int stmt_len = BOX_ELEMENTS (stmt);
  LT_CHECK_RW (qi->qi_trx);

/*  if (qi -> qi_autocommit)
   sqlr_new_error ("42000", "XXX", "DDL not allowed in autocommitting statements.");
 */
  if (!IS_BOX_POINTER (stmt[0]))
    {
      sql_ddl_node_input (ddl, inst, state);
    }
  else if (0 == strcmp (stmt[0], "create_table"))
    {
      ddl_create_table (qi, stmt[1],
	  (caddr_t *) stmt[2]);
    }
  else if (0 == strcmp (stmt[0], "create_sub_table"))
    {
      ddl_create_sub_table (qi, stmt[1],
	  (caddr_t *) stmt[2], (caddr_t *) stmt[3]);

    }
  else if (0 == strcmp (stmt[0], "create_unique_index"))
    {
      ddl_create_primary_key (qi, stmt[1], stmt[3],
	  (char **) stmt[4],
	  box_is_string (stmt, "contiguous", 5, stmt_len),
	  box_is_string (stmt, "object_id", 5, stmt_len)
	  );
    }
  else if (0 == strcmp (stmt[0], "create_index"))
    {
      ddl_create_key (qi, stmt[1], stmt[3],
	  (char **) stmt[4],
	  box_is_string (stmt, "contiguous", 5, stmt_len),
	  box_is_string (stmt, "object_id", 5, stmt_len),
		      box_is_string (stmt, "unique", 5, stmt_len), 0, NULL);
    }
  else if (0 == strcmp (stmt[0], "add_col"))
    ddl_add_col (qi, stmt[1], (caddr_t *) stmt[2]);
  else if (0 == strcmp (stmt[0], "build_index"))
    ddl_build_index (qi, stmt[1], stmt[2], qi->qi_trx->lt_replicate);
  else if (0 == strcmp (stmt[0], "drop_index"))
    ddl_drop_index (state, stmt[1], stmt[2], 1);

  else
    GPF_T;			/* No such DDL statement */

  qn_send_output ((data_source_t *) ddl, state);
}


/* Anytime Result */


#define AT_NOP 0
#define AT_RESET 1
#define AT_CONTINUED 2



void
qi_extend_anytime (caddr_t * inst)
{
  QNCAST (query_instance_t, qi, inst);
  client_connection_t * cli = qi->qi_client;
  cli->cli_activity.da_anytime_result = 0;
  cli->cli_terminate_requested = 0;
  cli->cli_anytime_checked = 0;
  cli->cli_anytime_started = get_msec_real_time ();
}


int
qn_anytime_state (data_source_t * qn, caddr_t * inst)
{
  int rc = AT_NOP, reset = AT_NOP;
  if (!qn)
    return AT_NOP;
  if ((qn_input_fn)fun_ref_node_input == qn->src_input)
    {
      QNCAST (fun_ref_node_t, fref, qn);
      int rc = qn_anytime_state (fref->fnr_select, inst);
      if (AT_RESET == rc || AT_CONTINUED == rc)
	{
	  at_printf (("fref %d was reset and now continuing to get results\n", fref->src_gen.src_in_state));
	  if (!fref->clb.clb_fill)
	    {
	      qi_extend_anytime (inst);
	      fun_ref_node_input ((fun_ref_node_t *)fref, inst, FREF_SINGLE_ANYTIME_FINISH);
	      return AT_CONTINUED;
	    }
	  else
	    {
	      GPF_T;
	    }
	}
      return qn_anytime_state (qn_next (qn), inst);
    }
  else if ((qn_input_fn)query_frag_input == qn->src_input)
    {
      QNCAST (query_frag_t, qf, qn);
      if (qf->qf_is_agg)
	{
	  if (!SRC_IN_STATE (qf, inst))
	    return AT_NOP;
	  at_printf (("mark agg qf %d as not continuable\n", qf->src_gen.src_in_state));
	  SRC_IN_STATE (qf, inst) = NULL;
	  DO_SET (data_source_t *, qfn, &qf->qf_nodes)
	    {
	      SRC_IN_STATE (qfn, inst) = NULL;
	    }
	  END_DO_SET();
	  return AT_RESET;
	}
      if (SRC_IN_STATE (qn, inst))
	{
	  at_printf (("reset value qf %d\n", qf->src_gen.src_in_state));
	  qn_init ((table_source_t*)qn, inst);
	  reset = AT_RESET;
	}
      rc = qn_anytime_state (qn_next (qn), inst);
      return MAX (rc, reset);
    }
  else if ((qn_input_fn)subq_node_input == qn->src_input)
    {
      QNCAST (subq_source_t, sqs, qn);
      if (SRC_IN_STATE  (qn, inst))
	{
	  QR_RESET_CTX
	    {
	      at_printf (("reset subq %d\n", qn->src_in_state));
	      reset = qn_anytime_state (sqs->sqs_query->qr_head_node, inst);
	      POP_QR_RESET;
	      rc = qn_anytime_state (qn_next (qn), inst);
	      at_printf (("Reset of subq %d returned %d, resetting next\n", qn->src_in_state, rc));
	      return MAX (reset,rc);
	    }
	  QR_RESET_CODE
	    {
	      QNCAST (query_instance_t, qi, inst);
	      if (RST_ENOUGH == reset_code)
		{
		  /* the subq produced a row */
		  POP_QR_RESET;
		  qn_send_output (qn, inst);
		  if (SRC_IN_STATE (qn, inst))
		    subq_node_input (sqs, inst, NULL);
		  qr_resume_pending_nodes (qn->src_query, inst);
		}
	      else
		{
		  caddr_t err = subq_handle_reset (qi, reset_code);
		  POP_QR_RESET;
		  if (err_is_anytime (err))
		    {
		      at_printf (("subq %d interrupted by anytime", qn->src_in_state));
		    }
		  if (0 && err_is_anytime (err))
		    SRC_IN_STATE (qn, inst) = NULL; /* timed out when continuing.  No more tries for this subq **/
		  sqlr_resignal (err);
		}
	    }
	  END_QR_RESET;
	  return AT_CONTINUED;
	}
      return qn_anytime_state (qn_next (qn), inst);
    }
    {
      if (SRC_IN_STATE (qn, inst))
	{
	  at_printf (("reset node %d\n", qn->src_in_state));
	  reset = AT_RESET;
	  qn_init ((table_source_t*)qn, inst);
	}
      rc = qn_anytime_state (qn_next (qn), inst);
      return MAX (rc, reset);
    }
  return AT_NOP;
}


caddr_t
cli_anytime_error (client_connection_t * cli)
{
  char msg[200];
  sprintf (msg, "Returning incomplete results, query interrupted by result timeout.  Activity: ");
  da_string ( &cli->cli_activity, &msg[strlen (msg)], sizeof (msg) - strlen (msg));
  return srv_make_new_error (SQL_ANYTIME, "RC...", "%s", msg);
}


void
qr_anytime (query_t * qr, query_instance_t * qi, int reset_code)
{
  /* decide what to reset. If something should be continued, continue it, giving it a new allotment of time. */
  caddr_t err;
  caddr_t * inst = (caddr_t*)qi;
  int rc;
  if (RST_ERROR != reset_code || !qr->qr_select_node)
    return;
  err = qi->qi_thread->thr_reset_code;
  if (!err_is_anytime (err))
    return;
  qi->qi_thread->thr_reset_code = NULL;
  dk_free_tree (err);
  at_printf (("Anytime reset starts\n"));
  qi->qi_is_partial = 1;
  rc = qn_anytime_state (qr->qr_head_node, inst);
  if (AT_CONTINUED == rc)
    {
      qr_resume_pending_nodes (qr, inst);
    }
  qi->qi_thread->thr_reset_code = cli_anytime_error (qi->qi_client);
}


caddr_t
qi_txn_code (int rc, query_instance_t * caller, caddr_t detail)
{
  caddr_t err;
  if (rc == LTE_OK)
    return NULL;
  MAKE_TRX_ERROR (rc, err, detail);
  if (CALLER_CLIENT == caller)
    PrpcAddAnswer (err, DV_ARRAY_OF_POINTER, 1, 1);
  return err;
}


caddr_t
qi_handle_reset (query_instance_t * qi, int reset)
{
  /* Handle a reset into qr_exec or qr_more. Prime thread only */
  query_instance_t *caller = qi->qi_caller;
  caddr_t err = NULL;
  caddr_t detail = box_copy (LT_ERROR_DETAIL (qi->qi_trx));
  int trx_code;
  QI_CHECK_ANYTIME_RST (qi, reset);
  switch (reset)
    {
    case RST_KILLED:
      {
	err = srv_make_new_error ("HY008", "SR203",
	    "Async statement killed by SQLCancel.%s%s",
	    detail ? " : " : "",
	    detail ? detail : "");
	qi_kill (qi, QI_ERROR);
	if (caller == CALLER_CLIENT)
	  PrpcAddAnswer (err, DV_ARRAY_OF_POINTER, 1, 1);
	break;
      }
    case RST_ENOUGH:
      {
	/* A batch of select rows completed. All is OK. */
	int rc = qi_select_leave (qi);
	err = qi_txn_code (rc, caller, detail);
	break;
      }
    case RST_DEADLOCK:
      {
	trx_code = qi_kill (qi, QI_ERROR);
	err = qi_txn_code (trx_code, caller, detail);
	break;
      }
    case RST_ERROR:
      {
	/* Send message */
	caddr_t trx_err;
	err =  thr_get_error_code (THREAD_CURRENT_THREAD);
	if (err_is_anytime (err))
	  {
	    dk_free_tree (err);
	    err = cli_anytime_error (qi->qi_client);
	    if (qi->qi_lc)
	      {
		qi->qi_lc->lc_row_count = qi->qi_n_affected;
		qi->qi_lc->lc_error = err;
		return NULL;
	      }
	  }
	if (err && caller == CALLER_CLIENT)
	  PrpcAddAnswer (err, DV_ARRAY_OF_POINTER, 1, 1);
	trx_code = qi_kill (qi, QI_ERROR);
	trx_err = qi_txn_code (trx_code, caller, detail);
	if (!err)
	  err = trx_err;
	else
	  dk_free_tree (trx_err);
	break;
      }
    default:
      dbg_printf (("Freak reset code %d.\n", reset));
    }
  dk_free_box (detail);
  return err;
}


caddr_t
qr_find_parm (caddr_t * box, char *kwd, int *found)
{
  int inx;
  if (found)
    *found = 0;
  for (inx = 0; ((uint32) inx) < BOX_ELEMENTS (box); inx += 2)
    {
      caddr_t elt = box[inx];
      if (0 == strcmp (elt, kwd))
	{
	  caddr_t ret = box[inx + 1];
	  if (found)
	    *found = 1;
	  box[inx + 1] = NULL;
	  return (ret);
	}
    }
  return NULL;
}


void
qr_free_params (caddr_t * parms)
{
  if (parms)
    {
      int n_pars = BOX_ELEMENTS (parms), inx;
      for (inx = 0; inx < n_pars; inx ++)
	dk_free_tree (parms[inx]);
    }
}


void
cli_send_row_count (client_connection_t * cli, long n_affected, caddr_t * ret,
    du_thread_t * thr)
{
  PRPC_ANSWER_START (thr, PARTIAL);
  if (ret)
    {
      print_object ((caddr_t) ret, __ses, NULL, NULL);
      dk_free_tree ((caddr_t) ret);
    }
  else if (n_affected && cli->cli_support_row_count)
    {
      dks_array_head (__ses, 3, DV_ARRAY_OF_POINTER);

      print_int (QA_ROWS_AFFECTED, __ses);
      print_int (n_affected, __ses);
      print_object (cli->cli_identity_value, __ses, NULL, NULL);
    }
  else
    print_int (SQL_SUCCESS, __ses);
  PRPC_ANSWER_END (0);
}


int autocommit_select_read_only = 1;


void
qi_set_options (query_instance_t * qi, stmt_options_t * opts)
{
  query_t *qr = qi->qi_query;
  if (qr->qr_select_node)
    {
      qi->qi_prefetch_bytes = (long) SO_PREFETCH_BYTES (opts);
      qi->qi_bytes_selected = 0;
      ((ptrlong *) qi)[qr->qr_select_node->sel_out_quota] =
	  opts ? (long) opts->so_prefetch : SELECT_PREFETCH_QUOTA;
    }
  if (opts)
    {
      int conc = (int) opts->so_concurrency;
      qi->qi_isolation = (char) SO_ISOLATION (opts);
      if (qi->qi_query->qr_select_node &&
	  qi->qi_query->qr_select_node->sel_lock_mode == PL_EXCLUSIVE)
	{
	  conc = SQL_CONCUR_LOCK;
	}
      else if (opts->so_autocommit &&
	       qi->qi_query->qr_select_node &&
	  opts->so_concurrency != SQL_CONCUR_LOCK &&
	       autocommit_select_read_only)
	{
	  qi->qi_isolation = ISO_COMMITTED;
	}
      switch (conc)
	{
	case SQL_CONCUR_LOCK:
	  qi->qi_lock_mode = PL_EXCLUSIVE;
	  break;
	case SQL_CONCUR_ROWVER:
	  qi->qi_lock_mode = PL_SHARED;
	  break;
	default:
	  qi->qi_lock_mode = PL_SHARED;
	  break;
	}
    }
  else
    {
      qi->qi_lock_mode = PL_SHARED;
      qi->qi_isolation = default_txn_isolation;
    }
  qi->qi_autocommit = opts ? (long) opts->so_autocommit : 0;
  if (CALLER_CLIENT == qi->qi_caller
      && qi->qi_client->cli_version > 1718)
    qi->qi_rpc_timeout = opts ? (long) opts->so_rpc_timeout : 0;
  else if (CALLER_CLIENT != qi->qi_caller && CALLER_LOCAL != qi->qi_caller)
    qi->qi_rpc_timeout = qi->qi_caller->qi_rpc_timeout;
}


long last_exec_time;		/* used to know when the system is idle */


int
qi_initial_enter_trx (query_instance_t * qi)
{
  /* stays IN_CLIENT, even if temporarily leaves */
  /* If lt ok, enter.  If not, rollback and silently ignore if autocommit, else report error which may have killed the lt while the client was not in */
  caddr_t detail = NULL;
  int rc = LTE_OK;
  client_connection_t *cli = qi->qi_client;
  lock_trx_t *lt;

  sqlc_set_client (qi->qi_client);
  ASSERT_IN_MTX (qi->qi_client->cli_mtx);
  IN_TXN;
  lt = cli->cli_trx;

  lt_wait_checkpoint ();
  if (!IS_INPROCESS_CLIENT (cli))
    lt_threads_inc_inner (lt);
  if (LT_PENDING == lt->lt_status)
    {
      qi->qi_trx = lt;
      LEAVE_TXN;
      return LTE_OK;
    }
  rc = lt->lt_error ? lt->lt_error : LTE_DEADLOCK;
  detail = lt->lt_error_detail;
  lt->lt_error_detail = NULL;
  lt_rollback (lt, TRX_CONT);
  if (qi->qi_autocommit)
    {
      qi->qi_trx = lt;
      LEAVE_TXN;
      dk_free_box (detail);
      return LTE_OK;
    }
  lt->lt_error_detail = detail;
  lt_threads_dec_inner (lt);
  LEAVE_TXN;
  return rc;
}

#define QI_SERIALIZABLE(qi,qr) \
  if ((qi)->qi_no_cast_error && PL_EXCLUSIVE == (qr)->qr_lock_mode && !(qi)->qi_autocommit && !(qi)->qi_non_txn_insert) \
    (qi)->qi_isolation = ISO_SERIALIZABLE

caddr_t
qr_exec (client_connection_t * cli, query_t * qr,
    query_instance_t * caller, caddr_t cr_name,
    srv_stmt_t * stmt, local_cursor_t ** lc_ret,
    caddr_t * parms, stmt_options_t * opts,
    int named_params)
{
  long n_affected;
  int inx, was_autocommit, is_timeout = LTE_OK;
  volatile int n_actual_params;
  caddr_t ret;
  du_thread_t *self_thread;
  caddr_t *inst = (caddr_t *) qi_alloc (qr, opts, NULL, 0);
  query_instance_t *qi = (query_instance_t *) inst;
  caddr_t *state;

  state = inst;

#ifdef MALLOC_DEBUG
  dk_alloc_assert (qr);
#endif
  qi->qi_query = qr;
  qi->qi_no_cast_error = qr->qr_no_cast_error;
  qi->qi_caller = caller;
  qi->qi_client = cli;
  qi->qi_thread = THREAD_CURRENT_THREAD;
  qi->qi_threads = 1;
  qi_set_options (qi, opts);
  if (caller == CALLER_CLIENT || caller == CALLER_LOCAL)
    {
      if (NULL == THR_ATTR (THREAD_CURRENT_THREAD, TA_OBJECT_SPACE_OWNER))
        {
	  SET_THR_ATTR (THREAD_CURRENT_THREAD, TA_OBJECT_SPACE_OWNER, qi);
	  qi->qi_object_space = OBJECT_SPACE_NOT_SET;
	}
      if (cli->cli_anytime_timeout
	  && (qr->qr_select_node || qr->qr_proc_name))
	{
	  memset (&cli->cli_activity, 0, sizeof (cli->cli_activity));
	  cli->cli_anytime_checked = 0;
	  cli->cli_anytime_started = get_msec_real_time ();
	}
      else
	cli->cli_anytime_started = 0;
      if (cli->cli_user)
	{
	  qi->qi_u_id = cli->cli_user->usr_id;
	  qi->qi_g_id = cli->cli_user->usr_g_id;
	}
    }
  else
    {
      qi->qi_u_id = caller->qi_u_id;
      qi->qi_g_id = caller->qi_g_id;
      qi->qi_isolation = caller->qi_isolation;
      qi->qi_lock_mode = caller->qi_lock_mode;
      qi->qi_no_triggers = caller->qi_no_triggers;
    }
  was_autocommit = qi->qi_autocommit;
  QI_SERIALIZABLE (qi, qr);
  if (stmt)
    {
      is_timeout = qi_initial_enter_trx (qi);
      if (LTE_OK != is_timeout)
	{
	  caddr_t detail = box_copy (LT_ERROR_DETAIL (qi->qi_client->cli_trx)), err;
	  LEAVE_CLIENT (qi->qi_client);
	  qi_free ((caddr_t *) qi);
	  err = qi_txn_code (is_timeout, caller, detail);
	  dk_free_box (detail);
	  PrpcAddAnswer (err, DV_ARRAY_OF_POINTER, 1, 1);
	  return (err);
	}
      stmt->sst_inst = qi;
      if (prof_on)
	stmt->sst_start_msec = get_msec_real_time ();
      else
	stmt->sst_start_msec = approx_msec_real_time ();
      qi->qi_stmt = stmt;
      if (qr->qr_select_node && !cr_name && stmt
	  && !was_autocommit)
	{
	  cr_name = box_string (stmt->sst_id);
	}
      if (cr_name)
	{
	  dbg_cli_printf (("Attach instance %s\n", cr_name));
	  id_hash_set (cli->cli_cursors, (caddr_t) &cr_name, (caddr_t) &qi);
	  qi->qi_cursor_name = cr_name;
	}
      LEAVE_CLIENT (cli);
    }
  else if (CALLER_LOCAL == caller)
    {
      if (!cli->cli_trx)
	GPF_T1 ("internal client must have trx");
      qi->qi_trx = cli->cli_trx;
    }
  else
    {
      qi->qi_trx = caller->qi_trx;
    }

  if (caller == CALLER_CLIENT && qi->qi_trx)
    {
      qi->qi_trx->lt_timeout =
	  opts ?
	  (is_array_of_long (box_tag ((caddr_t) opts))
	  ? (long) opts->so_timeout : (long) unbox ((caddr_t) opts->so_timeout))
	  : 100000;
      last_exec_time = qi->qi_trx->lt_started = approx_msec_real_time ();
    }

  if (lc_ret)
    {
      NEW_VARZ (local_cursor_t, lc);
      lc->lc_is_allocated = 1;
      lc->lc_inst = (caddr_t *) qi;
      qi->qi_lc = lc;
      lc->lc_position = -1;
      *lc_ret = lc;
    }
  inx = 0;
  n_actual_params = parms ? BOX_ELEMENTS (parms) : 0;
  DO_SET (state_slot_t *, parm, &qr->qr_parms)
  {
    int found;
    caddr_t val;
    if (named_params)
      {
	val = qr_find_parm (parms, parm->ssl_name, &found);
	if (!found)
	  {
	    qr_free_params (parms);
	    qi_kill (qi, QI_ERROR);
	    return (srv_make_new_error ("22002", "SR204", "Missing named parameter '%s'", parm->ssl_name));
	  }
      }
    else
      {
	if (inx >= n_actual_params)
	  {
	    n_actual_params = -1;	/* checked later */
	    break;
	  }
	val = parms[inx];
	parms[inx] = NULL;
      }
    inx++;
    if (IS_SSL_REF_PARAMETER (parm->ssl_type))
      qst_set_ref (state, parm, (caddr_t *) val);
    else
      qst_set (state, parm, val);
  }
  END_DO_SET ();
  qr_free_params (parms);

  QR_RESET_CTX_T (qi->qi_thread)
  {
    if (n_actual_params == -1)
      sqlr_new_error ("07001", "SR205", "Not enough actual parameters.");
    qn_input (qr->qr_head_node, inst, state);
    qr_resume_pending_nodes (qr, inst);
  }
  QR_RESET_CODE
  {
    qr_anytime (qr, qi, reset_code);
    POP_QR_RESET;
    QI_BUNION_RESET (qi, qr, 0);
    PLD_SEM_CLEAR(qi)
    return (qi_handle_reset (qi, reset_code));
  }
  END_QR_RESET;
 qr_complete:
  PLD_SEM_CLEAR(qi)
  caller = qi->qi_caller;	/* AIX cc -O  fucks up here. reassign org. value into caller or it won't work */
  if (qi->qi_is_partial)
    ret = cli_anytime_error (qi->qi_client);
  else
    {
      ret = qi->qi_proc_ret;
      qi->qi_proc_ret = NULL;
    }
  n_affected = qi->qi_n_affected;
  self_thread = qi->qi_thread;
  if (qi->qi_lc)
    qi->qi_lc->lc_row_count = n_affected;

  {
    caddr_t detail = box_copy (LT_ERROR_DETAIL (qi->qi_trx));
    if (!qr->qr_select_node || qi->qi_autocommit)
      {
	is_timeout = qi_kill (qi, QI_DONE);
      }
    else
      {
	if (opts && opts->so_prefetch == PREFETCH_ALL)
	  is_timeout = qi_kill (qi, QI_DONE);
	else
	  is_timeout = qi_select_leave (qi);
      }

    if (is_timeout != LTE_OK)
      {
	caddr_t err;
	dk_free_tree (ret);
	err = qi_txn_code (is_timeout, caller, detail);
	dk_free_box (detail);
	if (CALLER_CLIENT == caller)
	  PrpcAddAnswer (err, DV_ARRAY_OF_POINTER, 1, 1);
	return err;
      }
    dk_free_box (detail);
  }
  if (caller == CALLER_CLIENT)
    {
      cli_send_row_count (cli, n_affected, (caddr_t *) ret, self_thread);
    }
  else
    dk_free_tree (ret);

#ifdef WIRE_DEBUG
      list_wired_buffers (__FILE__, __LINE__, "qr_exec finish");
#endif

  return ((caddr_t) SQL_SUCCESS);
}

caddr_t
qr_dml_array_exec (client_connection_t * cli, query_t * qr,
	 query_instance_t * caller, caddr_t cr_name,
	 srv_stmt_t * stmt,
	 caddr_t ** param_array, stmt_options_t * opts)
{
  /* when client exec dml in cluster, pass all param rows as a cluster batch  */
  caddr_t detail = NULL;
  long n_affected;
  int param_inx;
  int inx, was_autocommit, is_timeout = LTE_OK;
  volatile int n_actual_params;
  du_thread_t *self_thread;
  caddr_t *inst = (caddr_t *) qi_alloc (qr, opts, NULL, 0);
  query_instance_t *qi = (query_instance_t *) inst;
  caddr_t *state;

  state = inst;

#ifdef MALLOC_DEBUG
  dk_alloc_assert (qr);
#endif
  qi->qi_query = qr;
  qi->qi_no_cast_error = qr->qr_no_cast_error;
  qi->qi_caller = caller;
  qi->qi_client = cli;
  qi->qi_thread = THREAD_CURRENT_THREAD;
  qi->qi_threads = 1;
  qi_set_options (qi, opts);
  if (caller == CALLER_CLIENT || caller == CALLER_LOCAL)
    {
      if (NULL == THR_ATTR (THREAD_CURRENT_THREAD, TA_OBJECT_SPACE_OWNER))
        {
	  SET_THR_ATTR (THREAD_CURRENT_THREAD, TA_OBJECT_SPACE_OWNER, qi);
	  qi->qi_object_space = OBJECT_SPACE_NOT_SET;
	}
      if (cli->cli_anytime_timeout
	  && (qr->qr_select_node || qr->qr_proc_name))
	{
	  memset (&cli->cli_activity, 0, sizeof (cli->cli_activity));
	  cli->cli_anytime_checked = 0;
	  cli->cli_anytime_started = get_msec_real_time ();
	}
      else
	cli->cli_anytime_started = 0;
      if (cli->cli_user)
	{
	  qi->qi_u_id = cli->cli_user->usr_id;
	  qi->qi_g_id = cli->cli_user->usr_g_id;
	}
    }
  else
    GPF_T1 ("array exec only from client");
  was_autocommit = qi->qi_autocommit;
  QI_SERIALIZABLE (qi, qr);
  if (stmt)
    {
      is_timeout = qi_initial_enter_trx (qi);
      if (LTE_OK != is_timeout)
	{
	  caddr_t detail = box_copy (LT_ERROR_DETAIL (qi->qi_client->cli_trx)), err;
	  LEAVE_CLIENT (qi->qi_client);
	  qi_free ((caddr_t *) qi);
	  err = qi_txn_code (is_timeout, caller, detail);
	  dk_free_box (detail);
	  return (err);
	}
      stmt->sst_inst = qi;
      if (prof_on)
	stmt->sst_start_msec = get_msec_real_time ();
      else
	stmt->sst_start_msec = approx_msec_real_time ();
      qi->qi_stmt = stmt;
      if (qr->qr_select_node && !cr_name && stmt
	  && !was_autocommit)
	{
	  cr_name = box_string (stmt->sst_id);
	}
      if (cr_name)
	{
	  dbg_cli_printf (("Attach instance %s\n", cr_name));
	  id_hash_set (cli->cli_cursors, (caddr_t) &cr_name, (caddr_t) &qi);
	  qi->qi_cursor_name = cr_name;
	}
      LEAVE_CLIENT (cli);
    }
  else if (CALLER_LOCAL == caller)
    {
      if (!cli->cli_trx)
	GPF_T1 ("internal client must have trx");
      qi->qi_trx = cli->cli_trx;
    }
  else
    GPF_T1 ("array exec is cli only");

  if (caller == CALLER_CLIENT && qi->qi_trx)
    {
      qi->qi_trx->lt_timeout =
	opts ?
	(is_array_of_long (box_tag ((caddr_t) opts))
	 ? (long) opts->so_timeout : (long) unbox ((caddr_t) opts->so_timeout))
	: 100000;
      last_exec_time = qi->qi_trx->lt_started = approx_msec_real_time ();
    }
  DO_BOX (caddr_t *, parms, param_inx, param_array)
    {
      inx = 0;
      n_actual_params = parms ? BOX_ELEMENTS (parms) : 0;
      DO_SET (state_slot_t *, parm, &qr->qr_parms)
	{
	  caddr_t val;
	  if (inx >= n_actual_params)
	    {
	      n_actual_params = -1;	/* checked later */
	      break;
	    }
	  val = parms[inx];
	  parms[inx] = NULL;
	  inx++;
	  if (IS_SSL_REF_PARAMETER (parm->ssl_type))
	    qst_set_ref (state, parm, (caddr_t *) val);
	  else
	    qst_set (state, parm, val);
	}
      END_DO_SET ();
      dk_free_box ((caddr_t)parms);
      param_array[param_inx] = NULL;
      QR_RESET_CTX_T (qi->qi_thread)
	{
	  if (n_actual_params == -1)
	    sqlr_new_error ("07001", "SR205", "Not enough actual parameters.");
	  qn_input (qr->qr_head_node, inst, state);
	}
      QR_RESET_CODE
	{
	  qr_anytime (qr, qi, reset_code);
	  POP_QR_RESET;
	  QI_BUNION_RESET (qi, qr, 0);
	  PLD_SEM_CLEAR(qi)
	    dk_free_tree (param_array);
	  return (qi_handle_reset (qi, reset_code));
	}
      END_QR_RESET;
    }
  END_DO_BOX;
  dk_free_tree ((caddr_t) param_array);
  QR_RESET_CTX_T (qi->qi_thread)
    {
      qr_resume_pending_nodes (qr, inst);
    }
  QR_RESET_CODE
    {
      qr_anytime (qr, qi, reset_code);
      POP_QR_RESET;
      QI_BUNION_RESET (qi, qr, 0);
      PLD_SEM_CLEAR(qi)
      return (qi_handle_reset (qi, reset_code));
    }
  END_QR_RESET;

 qr_complete:
  PLD_SEM_CLEAR(qi)
    n_affected = qi->qi_n_affected;
  self_thread = qi->qi_thread;
  detail = box_copy (LT_ERROR_DETAIL (qi->qi_trx));
  is_timeout = qi_kill (qi, QI_DONE);
  if (is_timeout != LTE_OK)
    {
      caddr_t err;
      err = qi_txn_code (is_timeout, caller, detail);
      dk_free_box (detail);
      return err;
    }
  dk_free_box (detail);
  if (CALLER_LOCAL != caller)
    {
      for (inx = 0; inx < param_inx - 1; inx++)
	cli_send_row_count (cli, 0, NULL, self_thread);
      cli_send_row_count (cli, n_affected, NULL, self_thread);
    }
#ifdef WIRE_DEBUG
  list_wired_buffers (__FILE__, __LINE__, "qr_exec finish");
#endif
  return ((caddr_t) SQL_SUCCESS);
}


#ifdef PLDBG
int qi_is_recursive (query_instance_t *qi, query_t * qr)
{
  query_instance_t *caller = qi->qi_caller;
  while (IS_POINTER (caller))
    {
      if (caller->qi_query == qr)
	return 1;
      caller = caller->qi_caller;
    }
  return 0;
}
#endif

#define QR_POP_USER(qi, cli, saved_user, saved_qual, caller)  \
			        if (qi->qi_pop_user) \
				  { \
				    cli->cli_user = saved_user; \
				    dk_free_box (cli->cli_qualifier); \
				    cli->cli_qualifier = saved_qual; \
				  } \
				else if (qi->qi_u_id != caller->qi_u_id) \
   				  { \
				    caller->qi_u_id = qi->qi_u_id; \
				    caller->qi_g_id = qi->qi_g_id; \
				    dk_free_box (saved_qual); \
				  } \
 				else \
				  { \
				    dk_free_box (saved_qual); \
				  }

caddr_t
qr_subq_exec (client_connection_t * cli, query_t * qr,
    query_instance_t * caller,
    caddr_t * auto_qi, int auto_qi_len,
    local_cursor_t * lc,
    caddr_t * parms, stmt_options_t * opts)
{
  long n_affected;
  int inx;
  volatile int n_actual_params;
  caddr_t ret;
  caddr_t *inst = (caddr_t *) qi_alloc (qr, opts, auto_qi, auto_qi_len);
  query_instance_t *qi = (query_instance_t *) inst;
  caddr_t *state;
  user_t * saved_user = cli->cli_user;
  caddr_t saved_qual = box_string (cli->cli_qualifier);
#ifdef PLDBG
  long start_time = ((qr->qr_proc_name && qr->qr_brk) ? get_msec_real_time () : 0);
  long end_time;
#endif

  QI_CHECK_STACK (caller, &ret, CALL_STACK_MARGIN);
  state = inst;

#ifdef MALLOC_DEBUG
  dk_alloc_assert (qr);
#endif
  qi->qi_query = qr;

  qi->qi_caller = caller;
  qi->qi_client = cli;
  qi_set_options (qi, opts);

  qi->qi_threads = 1;
  qi->qi_thread = caller->qi_thread;

  qi->qi_u_id = caller->qi_u_id;
  qi->qi_g_id = caller->qi_g_id;

  qi->qi_trx = caller->qi_trx;
  qi->qi_no_triggers = caller->qi_no_triggers;
  qi->qi_isolation = caller->qi_isolation;
  qi->qi_lock_mode = caller->qi_lock_mode;
  QI_SERIALIZABLE (qi, qr);
  if (lc)
    {
      memset (lc, 0, sizeof (local_cursor_t));
      lc->lc_inst = (caddr_t *) qi;
      qi->qi_lc = lc;
      lc->lc_position = -1;
    }
  inx = 0;
  n_actual_params = parms ? BOX_ELEMENTS (parms) : 0;
  DO_SET (state_slot_t *, parm, &qr->qr_parms)
  {
    caddr_t val;
    if (inx >= n_actual_params)
      {
	n_actual_params = -1;	/* checked later */
	break;
      }
    val = parms[inx];
    inx++;
    if (IS_SSL_REF_PARAMETER (parm->ssl_type))
      qst_set_ref (state, parm, (caddr_t *) val);
    else
      qst_set (state, parm, val);
  }
  END_DO_SET ();

  QR_RESET_CTX_T (qi->qi_thread)
  {
    if (n_actual_params == -1)
      sqlr_new_error ("07001", "SR206", "Not enough actual parameters.");
    qn_input (qr->qr_head_node, inst, state);
  }
  QR_RESET_CODE
  {
    POP_QR_RESET;
    QR_POP_USER(qi, cli, saved_user, saved_qual, caller);
    QI_BUNION_RESET (qi, qr, 0);
    return (qi_handle_reset (qi, reset_code));
  }
  END_QR_RESET;

  QR_POP_USER(qi, cli, saved_user, saved_qual, caller);
#ifdef PLDBG
  if (start_time > 0)
    {
      end_time = get_msec_real_time ();
      if (!qi_is_recursive (qi, qr))
	qr->qr_time_cumulative += (end_time - start_time);
      if (IS_POINTER (caller))
	caller->qi_child_time += (end_time - start_time);
      qr->qr_self_time += ((end_time - start_time) - qi->qi_child_time);
    }
#endif
 qr_complete:
  ret = qi->qi_proc_ret;
  qi->qi_proc_ret = NULL;
  n_affected = qi->qi_n_affected;
  dk_free_tree (ret);

  if (!qr->qr_select_node)
    {
      qi_kill (qi, 1);
    }
  else
    {
      if (opts && opts->so_prefetch == PREFETCH_ALL)
	qi_kill (qi, 1);
      else
	qi->qi_threads = 0;
    }
  return ((caddr_t) SQL_SUCCESS);
}


int
qi_enter_trx (query_instance_t * qi, caddr_t *detail_ptr)
{
  lock_trx_t *lt = qi->qi_trx;
  int rc = LTE_OK;

  sqlc_set_client (qi->qi_client);

  IN_TXN;
  lt_wait_checkpoint ();
  ASSERT_IN_TXN;
#ifdef INPROCESS_CLIENT
  if (!IS_INPROCESS_CLIENT (lt->lt_client))
#endif
    {
      lt_threads_inc_inner (lt);
    }
  CHECK_DK_MEM_RESERVE (lt);
  if (lt->lt_status != LT_PENDING)
    {
      LEAVE_TXN;
      LEAVE_CLIENT (qi->qi_client);
      if (detail_ptr)
	*detail_ptr = box_copy (LT_ERROR_DETAIL (qi->qi_trx));
      rc = qi_kill (qi, QI_ERROR);
      if (rc == LTE_OK)
	rc = LTE_DEADLOCK;
      return rc;
    }

  LEAVE_TXN;
  return LTE_OK;
}


/* qr_more. Find last node with an in or out state. Advance this.
   Repeat until there are no nodes with state or the query resets. */

caddr_t
qr_more (caddr_t * inst)
{
  du_thread_t * self;
  query_instance_t *qi = (query_instance_t *) inst;
  query_instance_t *caller = qi->qi_caller;
  int is_timeout = 0;
  query_t *qr = qi->qi_query;
  caddr_t err;

  if (qi->qi_stmt)
    {
      caddr_t detail = NULL;
      ASSERT_IN_MTX (qi->qi_client->cli_mtx);
      is_timeout = qi_enter_trx (qi, &detail);
      if (LTE_OK != is_timeout)
	{
	  caddr_t err;
	  err = qi_txn_code (is_timeout, caller, detail);
	  dk_free_box (detail);
	  return err;
	}
      dk_free_box (detail);
      LEAVE_CLIENT (qi->qi_client);
    }
  else
    {
      qi_enter (qi);
    }
  if (caller == CALLER_CLIENT || caller == CALLER_LOCAL)
    {
      if (NULL == THR_ATTR (THREAD_CURRENT_THREAD, TA_OBJECT_SPACE_OWNER))
        {
	  SET_THR_ATTR (THREAD_CURRENT_THREAD, TA_OBJECT_SPACE_OWNER, qi);
	}
    }
  qi->qi_thread = self = THREAD_CURRENT_THREAD;
  qi->qi_bytes_selected = 0;
  qi_clear_out_box (inst);
  QR_RESET_CTX_T (qi->qi_thread)
  {
    qr_resume_pending_nodes (qr, inst);
  }
  QR_RESET_CODE
  {
    POP_QR_RESET;
    QI_BUNION_RESET (qi, qr, 0);
    return (qi_handle_reset (qi, reset_code));
  }
  END_QR_RESET;

 qr_complete:
  caller = qi->qi_caller;
  err = qi->qi_is_partial ? cli_anytime_error (qi->qi_client) : NULL;
  {
    caddr_t detail = box_copy (LT_ERROR_DETAIL (qi->qi_trx));
    if (qi->qi_autocommit)
      is_timeout = qi_kill (qi, QI_DONE);
    else
      is_timeout = qi_select_leave (qi);

    if (LTE_OK != is_timeout)
      {
	caddr_t err = qi_txn_code (is_timeout, caller, detail);
	dk_free_box (detail);
	return err;
      }
    dk_free_box (detail);
  }
  if (caller == CALLER_CLIENT)
    {
      PRPC_ANSWER_START (self, PARTIAL);
      if (!err)
	print_int (SQL_SUCCESS, __ses);
      else
	print_object (err, __ses, NULL, NULL);
      PRPC_ANSWER_END (0);
    }
  return SQL_SUCCESS;
}


/* Local API */

caddr_t
qr_quick_exec (query_t * qr, client_connection_t * cli, char *id,
    local_cursor_t ** lc_ret, long n_pars,...)
{
  caddr_t ret;
  caddr_t *parms = (caddr_t *) dk_alloc_box (2 * n_pars * sizeof (caddr_t),
      DV_ARRAY_OF_POINTER);
  va_list ap;
  int inx;

  va_start (ap, n_pars);
  for (inx = 0; inx < 2 * n_pars; inx += 2)
    {
      caddr_t arg;
      parms[inx] = box_string (va_arg (ap, char *));
      arg = va_arg (ap, caddr_t);
      switch (va_arg (ap, long))
	{
	case QRP_INT:
	  parms[inx + 1] = box_num ((ptrlong) arg);
	  break;
	case QRP_STR:
	  parms[inx + 1] = box_dv_short_string (arg);
	  break;
	case QRP_RAW:
	  parms[inx + 1] = arg;
	  break;
	default:
	  GPF_T;		/* Bad arg type to quick exec */
	}
    }
  va_end (ap);
  ret = qr_exec (cli, qr, CALLER_LOCAL, NULL, NULL, lc_ret, parms, NULL, 1);
  dk_free_box ((box_t) parms);
  return ret;
}


client_connection_t *
qi_client (caddr_t * qis)
{
  query_instance_t *qi = (query_instance_t *) qis;
  return (qi->qi_client);
}


caddr_t
qr_rec_exec (query_t * qr, client_connection_t * cli, local_cursor_t ** lc_ret,
    query_instance_t * caller, stmt_options_t * opts, long n_pars, ...)
{
  caddr_t ret;
  caddr_t *parms = (caddr_t *) dk_alloc_box (2 * n_pars * sizeof (caddr_t),
      DV_ARRAY_OF_POINTER);
  int inx;
  va_list ap;

  va_start (ap, n_pars);
  for (inx = 0; inx < 2 * n_pars; inx += 2)
    {
      caddr_t arg;
      parms[inx] = box_string (va_arg (ap, char *));
      arg = va_arg (ap, caddr_t);
      switch (va_arg (ap, long))
	{
	case QRP_INT:
	  parms[inx + 1] = box_num ((ptrlong) arg);
	  break;
	case QRP_STR:
	  parms[inx + 1] = box_dv_short_string (arg);
	  break;
	case QRP_RAW:
	  parms[inx + 1] = arg;
	  break;
	default:
	  GPF_T;		/* Bad arg type to quick exec */
	}
    }
  va_end (ap);
  ret = qr_exec (cli, qr, caller, NULL, NULL, lc_ret, parms, opts, 1);
  dk_free_box ((box_t) parms);
  return ret;
}


long
lc_next (local_cursor_t * lc)
{
  int fill;
  query_t *qr;
  select_node_t *sel;
  query_instance_t *qi = (query_instance_t *) lc->lc_inst;
  caddr_t *inst = lc->lc_inst;
  if (!inst)
    {
      return 0;
    }
  qr = qi->qi_query;
  sel = qr->qr_select_node;
  if (!sel)
    return 0;

  lc->lc_position++;
  fill = (int) (ptrlong) inst[sel->sel_out_fill];
  if (lc->lc_position >= fill)
    {
      caddr_t state;
      if (lc->lc_error)
	return 0;
      state = qr_more (inst);
      lc->lc_error = state;
      if (state != (caddr_t) SQL_SUCCESS)
	{
	  return 0;
	}
      fill = (int) (ptrlong) inst[sel->sel_out_fill];
      if (fill == 0)
	{
	  qi_free (lc->lc_inst);
	  lc->lc_inst = NULL;
	  return 0;
	}
      lc->lc_position = 0;
      return 1;
    }
  else
    {
      return 1;
    }
}


void
lc_free (local_cursor_t * lc)
{
  if (lc->lc_inst && lc->lc_error == SQL_SUCCESS)
    /* There's an instance and the instance wasn't killed by an error */
    qi_free (lc->lc_inst);

  dk_free_box (lc->lc_cursor_name);
  dk_free_tree (lc->lc_proc_ret);
  if (lc->lc_is_allocated)
    dk_free (lc, sizeof (local_cursor_t));
}


caddr_t
lc_get_col (local_cursor_t * lc, char *name)
{
  int inx;
  query_instance_t *qi = (query_instance_t *) lc->lc_inst;
  caddr_t *inst = lc->lc_inst;
  query_t *qr = qi->qi_query;
  select_node_t *sel = qr->qr_select_node;
  int fill = (int) (ptrlong) inst[sel->sel_out_fill];
  caddr_t **box = (caddr_t **) inst[sel->sel_out_box];
  caddr_t *out_copy = box[lc->lc_position];
  if (lc->lc_position >= fill)
    {
      return NULL;
    }
  DO_BOX (state_slot_t *, sl, inx, sel->sel_out_slots)
  {
    if (sl->ssl_name && 0 == strcmp (name, sl->ssl_name))
      return (sel_out_get (out_copy, inx, sl));
  }
  END_DO_BOX;
  return NULL;
}


caddr_t
qi_nth_col (query_instance_t * qi, int current_of, int n)
{
  caddr_t *inst = (caddr_t *) qi;
  query_t *qr = qi->qi_query;
  select_node_t *sel = qr->qr_select_node;
  if (!sel)
    return NULL;
  {
    int n_out = BOX_ELEMENTS (sel->sel_out_slots);
    int fill = (int) (ptrlong) inst[sel->sel_out_fill];
    caddr_t **box = (caddr_t **) inst[sel->sel_out_box];
    caddr_t *out_copy = box[current_of];
    if (n >= n_out)
      return NULL;
    if (current_of >= fill)
      {
	return NULL;
      }
    return (sel_out_get (out_copy, n, sel->sel_out_slots[n]));
  }
}


caddr_t
lc_nth_col (local_cursor_t * lc, int n)
{
  query_instance_t *qi = (query_instance_t *) lc->lc_inst;
  caddr_t *inst = lc->lc_inst;
  query_t *qr = qi->qi_query;
  select_node_t *sel = qr->qr_select_node;
  int n_out = BOX_ELEMENTS (sel->sel_out_slots);
  int fill = (int) (ptrlong) inst[sel->sel_out_fill];
  caddr_t **box = (caddr_t **) inst[sel->sel_out_box];
  caddr_t *out_copy = box[lc->lc_position];
  if (n >= n_out)
    return NULL;
  if (lc->lc_position >= fill)
    {
      return NULL;
    }
  return (sel_out_get (out_copy, n, sel->sel_out_slots[n]));
}


caddr_t
lc_take_or_copy_nth_col (local_cursor_t * lc, int n)
{
  query_instance_t *qi = (query_instance_t *) lc->lc_inst;
  caddr_t *inst = lc->lc_inst;
  query_t *qr = qi->qi_query;
  select_node_t *sel = qr->qr_select_node;
  int n_out = BOX_ELEMENTS (sel->sel_out_slots);
  state_slot_t *ssl;
  int fill = (int) (ptrlong) inst[sel->sel_out_fill];
  caddr_t **box = (caddr_t **) inst[sel->sel_out_box];
  caddr_t *out_copy = box[lc->lc_position];
  if (n >= n_out)
    return NULL;
  if (lc->lc_position >= fill)
    {
      return NULL;
    }
  ssl = sel->sel_out_slots[n];
  if (ssl->ssl_type == SSL_COLUMN)
    {
      caddr_t data = out_copy[n];
      out_copy[n] = NULL;
      return data;
    }
  else
    return (box_copy_tree (sel_out_get (out_copy, n, ssl)));
}

#ifdef DEBUG
void
qi_check_stack (query_instance_t *qi, void *addr, ptrlong margin)
{
  if (THR_IS_STACK_OVERFLOW (qi->qi_thread, addr, margin))
    sqlr_new_error ("42000", "SR178", "Stack overflow (stack size is %ld, more than %ld is in use)", (long)(qi->qi_thread->thr_stack_size), (long)(qi->qi_thread->thr_stack_size - margin));
  if (DK_MEM_RESERVE)
    {
      SET_DK_MEM_RESERVE_STATE(qi->qi_trx);
      qi_signal_if_trx_error (qi);
    }
}
#endif
