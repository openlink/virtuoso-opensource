/*
 *  sqlprocc.c
 *
 *  $Id$
 *
 *  SQL Procedure Compiler
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2012 OpenLink Software
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
#include "sqlpar.h"
#include "sqlcmps.h"
#include "sqlfn.h"
#include "sqlintrp.h"
#include "arith.h"
#include "sqlpfn.h"
#include "statuslog.h"
#include "crsr.h"
#include "sqlbif.h"	/* for e.g. bif_find() */
#include "sqlo.h"
#include "sqltype.h"
#include "sqlcstate.h"


void
sqlc_decl_variable_list_const (sql_comp_t * sc, dk_set_t *ref_recs)
{
      t_NEW_VAR (col_ref_rec_t, state_cr);
      t_NEW_VAR (col_ref_rec_t, message_cr);
      memset (state_cr, 0, sizeof (col_ref_rec_t));
      memset (message_cr, 0, sizeof (col_ref_rec_t));
      sc->sc_sqlstate = ssl_new_inst_variable (sc->sc_cc, "__SQL_STATE", DV_ANY);
      sc->sc_sqlmessage = ssl_new_inst_variable (sc->sc_cc, "__SQL_MESSAGE", DV_SHORT_STRING);
      sc->sc_sqlstate->ssl_prec = 5;
      sc->sc_sqlmessage->ssl_prec = DV_STRING_PREC;
      state_cr->crr_col_ref = t_listst (3, COL_DOTTED, NULL, t_sym_string ("__SQL_STATE"));;
      message_cr->crr_col_ref = t_listst (3, COL_DOTTED, NULL, t_sym_string ("__SQL_MESSAGE"));;
      state_cr->crr_ssl = sc->sc_sqlstate;
      message_cr->crr_ssl = sc->sc_sqlmessage;
      t_set_push (ref_recs, (void *) state_cr);
      t_set_push (ref_recs, (void *) message_cr);
}

long sql_warnings_to_syslog = 0;

void
sql_warning_add (caddr_t err, int is_comp)
{
  du_thread_t * self;
  dk_set_t warnings_set;
  if (!err)
    return;

#ifndef NDEBUG
  if (!IS_BOX_POINTER (err) || BOX_ELEMENTS (err) != 3)
    GPF_T1("invalid warning text");
#endif

  if (sql_warning_mode == SQW_OFF
#ifdef NDEBUG
      || (!virtuoso_server_initialized)
#endif
      )
    {
      dk_free_tree (err);
      return;
    }
  else if (sql_warning_mode == SQW_ERROR)
    {
      if (is_comp)
	sqlc_resignal_1 (top_sc->sc_cc, err);
      else
	sqlr_resignal (err);
    }
  if (sql_warnings_to_syslog)
    log_debug ("SQL warning : [%.5s] %s", ERR_STATE (err), ERR_MESSAGE (err));

  ((caddr_t *)err)[0] = (caddr_t) QA_WARNING;
  self = THREAD_CURRENT_THREAD;
  warnings_set = (dk_set_t) THR_ATTR (self, TA_SQL_WARNING_SET);
  dk_set_push (&warnings_set, err);
  SET_THR_ATTR (self, TA_SQL_WARNING_SET, warnings_set);
}


void
sqlc_warning (const char *code, const char *virt_code, const char *string, ...)
{
  dk_set_t sc_code = top_sc ? top_sc->sc_routine_code : NULL;
  static char temp[2000];
  va_list list;
  caddr_t err = NULL;
  va_start (list, string);
  vsnprintf (temp, sizeof (temp), string, list);
  va_end (list);
  temp[sizeof(temp)-1] = '\0';

  DO_SET (instruction_t *, ins, &sc_code)
    {
       if (ins->ins_type == INS_COMPOUND_START &&
	   ins->_.compound_start.l_line_no)
	 {
	   if (top_sc && top_sc->sc_cc->cc_query &&
	       top_sc->sc_cc->cc_query->qr_proc_name)
	     {
	       err = srv_make_new_error (code, virt_code, "%s:%d: %s: %s",
		   ins->_.compound_start.file_name ?
		   ins->_.compound_start.file_name :
		   "<unspec>",
		   (int) ins->_.compound_start.l_line_no,
		   top_sc->sc_cc->cc_query->qr_proc_name,
		   temp);
	     }
	   else
	     {
	       err = srv_make_new_error (code, virt_code, "%s:%d: %s",
		   ins->_.compound_start.file_name ?
		   ins->_.compound_start.file_name :
		   "<unspec>",
		   (int) ins->_.compound_start.l_line_no,
		   temp);
	     }
	   break;
	 }
    }
  END_DO_SET ();

  if (!err)
    err = srv_make_new_error (code, virt_code, "%s", temp);
  sql_warning_add (err, 1);
}


void
sqlc_decl_variable_list_1 (sql_comp_t * sc, ST ** params, int is_arg_list, dk_set_t *ref_recs)
{
  /* procedure argument list or local variable list */
  int inx;

  DO_BOX (ST *, decl, inx, params)
  {
    state_slot_t *var;
    dk_set_t *compound_set = NULL;
    if (!is_arg_list)
      {
	if (!sc->sc_compound_scopes || !sc->sc_compound_scopes->data)
	  SQL_GPF_T1 (sc->sc_cc, "No compound scope");
	compound_set = (dk_set_t *) sc->sc_compound_scopes->data;
      }
    if (sqlc_find_crr (sc, decl->_.var.name))
      {
	sqlc_warning ("01V01", "QW001",
	    "Local declaration of %.*s shadows a definition of the same name",
	    MAX_NAME_LEN, decl->_.var.name->_.col_ref.name);
      }
    if (is_arg_list)
      {
	var = ssl_new_parameter (sc->sc_cc, decl->_.var.name->_.col_ref.name);
      }
    else
      {
	var = ssl_new_inst_variable (sc->sc_cc,
	    decl->_.var.name->_.col_ref.name, DV_SHORT_STRING);
      }
    ddl_type_to_sqt (&(var->ssl_sqt), (caddr_t *) decl->_.var.type);
    if (decl->_.var.mode == INOUT_MODE)
      var->ssl_type = SSL_REF_PARAMETER;
    else if (decl->_.var.mode == OUT_MODE)
      var->ssl_type = SSL_REF_PARAMETER_OUT;
    if (ref_recs)
      {
	t_NEW_VARZ (col_ref_rec_t, cr);
	cr->crr_col_ref = decl->_.var.name;
	cr->crr_ssl = var;
	t_set_push (ref_recs, (void *) cr);
	if (!is_arg_list)
	  t_set_push (compound_set, (void *) cr);
      }
  }
  END_DO_BOX;

  if (is_arg_list)
    {
      if (ref_recs)
	sqlc_decl_variable_list_const (sc, ref_recs);
    }

  if (is_arg_list)
    {
      caddr_t * defs = (caddr_t *) dk_alloc_box (box_length ((caddr_t) params), DV_ARRAY_OF_POINTER);
      caddr_t * alts = (caddr_t *) dk_alloc_box (box_length ((caddr_t) params), DV_ARRAY_OF_POINTER);
      caddr_t * places = (caddr_t *) dk_alloc_box (box_length ((caddr_t) params), DV_ARRAY_OF_POINTER);
      caddr_t * soap_opts = (caddr_t *) dk_alloc_box (box_length ((caddr_t) params), DV_ARRAY_OF_POINTER);
      DO_BOX (ST *, decl, inx, params)
	{
	  caddr_t * alt_type = (caddr_t *)decl->_.var.alt_type; /* array of three elements */
	  defs[inx] = box_copy_tree (decl->_.var.deflt);
	  alts[inx] = alt_type ? box_copy (alt_type[0]) : NULL;
	  places[inx] = alt_type ? box_num ((ptrlong) alt_type[1]) : 0;
	  soap_opts[inx] = alt_type ? box_copy_tree (alt_type[2]) : NULL;
	}
      END_DO_BOX;
      sc->sc_cc->cc_query->qr_parm_default = defs;
      sc->sc_cc->cc_query->qr_parm_alt_types = alts;      /*an alternative to the SQL datatype*/
      sc->sc_cc->cc_query->qr_parm_place = places; 	  /*where is it exposed*/
      sc->sc_cc->cc_query->qr_parm_soap_opts = soap_opts; /* SOAP options for parameters */
    }
}

void
sqlc_decl_variable_list (sql_comp_t * sc, ST ** params, int is_arg_list)
{
  sqlc_decl_variable_list_1 (sc, params, is_arg_list, &sc->sc_col_ref_recs);
}

long
sc_name_to_label (sql_comp_t * sc, caddr_t name)
{
  long *place;
  if (!name)
    return -1;
  place = (long *) id_hash_get (sc->sc_name_to_label, (caddr_t) & name);
  if (place)
    {
      return (*place);
    }
  else
    {
      long label = sqlc_new_label (sc);
      id_hash_set (sc->sc_name_to_label, (caddr_t) & name, (caddr_t) & label);
      return label;
    }
}


void
sqlc_set_ref_params (query_t * qr)
{
  DO_SET (state_slot_t *, ssl, &qr->qr_parms)
  {
    if (ssl->ssl_type != SSL_PARAMETER)
      SQL_GPF_T1 (NULL, "Bad parameter in subq compilation. Can't call by reference");
    ssl->ssl_type = SSL_REF_PARAMETER;
  }
  END_DO_SET ();
}


state_slot_t *
qr_current_of_ssl (query_t * qr)
{
  DO_SET (table_source_t *, ts, &qr->qr_nodes)
  {
    if ((qn_input_fn) table_source_input == ts->src_gen.src_input
	|| (qn_input_fn) table_source_input_unique == ts->src_gen.src_input)
      {
	if (0 && !ts->ts_current_of)
	  SQL_GPF_T1 (NULL, "All table sources have a current of at this point");
	return (ts->ts_current_of);
      }
  }
  END_DO_SET ();
  return NULL;
}


void
sqlc_cursor_def (sql_comp_t * sc, ST * stmt)
{
  dbe_table_t *remote_co;
  subq_compilation_t *sqc;

  sc->sc_in_cursor_def = 1;
  if (stmt->_.cr_def.type == _SQL_CURSOR_FORWARD_ONLY &&
      0 != strcmp (stmt->_.cr_def.name, "temp_cr") && ST_P (stmt->_.cr_def.spec, SELECT_STMT) &&
	!SEL_IS_DISTINCT (stmt->_.cr_def.spec) &&
	!sqlp_tree_has_fun_ref (stmt->_.cr_def.spec))
    {
    remote_co = NULL;
    }
  else
    remote_co = NULL;
  if (stmt->_.cr_def.type != _SQL_CURSOR_FORWARD_ONLY)
    {
      state_slot_t *var = ssl_new_inst_variable (sc->sc_cc, stmt->_.cr_def.name, DV_SHORT_STRING);
      t_NEW_VARZ (col_ref_rec_t, cr);

      cr->crr_col_ref = t_listst (3, COL_DOTTED, NULL, stmt->_.cr_def.name);
      cr->crr_ssl = var;
      t_set_push (&sc->sc_col_ref_recs, (void *) cr);

      sqc = sqlc_subquery_1 (sc, NULL, &(stmt->_.cr_def.spec), (int) stmt->_.cr_def.type, stmt->_.cr_def.params);

      cv_call (&sc->sc_routine_code, NULL, __SCROLL_CR_INIT, var,
	  (state_slot_t **) /*list*/ sc_list (1, ssl_new_constant (sc->sc_cc, t_box_num ((ptrlong) sqc->sqc_query))));
    }
  else
    sqc = sqlc_subquery (sc, NULL, &(stmt->_.cr_def.spec));
  sc->sc_in_cursor_def = 0;
  sqc->sqc_remote_co_table = remote_co;
  sqc->sqc_name = stmt->_.cr_def.name;
  sqc->sqc_ssl = qr_current_of_ssl (sqc->sqc_query);
  sqc->sqc_is_cursor = 1;
  sqc->sqc_cr_state_ssl =
      ssl_new_inst_variable (sc->sc_cc, "cr_state", DV_LONG_INT);
}


void
sqlc_remove_unrefd_current_ofs (sql_comp_t * sc)
{
  DO_SET (subq_compilation_t *, sqc, &sc->sc_subq_compilations)
  {
    if (sqc->sqc_is_cursor && !sqc->sqc_is_current_of)
      {
	DO_SET (table_source_t *, ts, &sqc->sqc_query->qr_nodes)
	{
	  if (ts->src_gen.src_input == (qn_input_fn) table_source_input ||
	      ts->src_gen.src_input == (qn_input_fn) table_source_input_unique)
	    ts->ts_current_of = NULL;
	}
	END_DO_SET ();
      }
  }
  END_DO_SET ()
}


void
sqlc_opt_fetches (sql_comp_t * sc)
{
  DO_SET (subq_compilation_t *, sqc, &sc->sc_subq_compilations)
  {
    if (sqc->sqc_is_cursor && sqc->sqc_fetches && !sqc->sqc_fetches->next)
      {
	instruction_t *ins = (instruction_t *) sqc->sqc_fetches->data;
	state_slot_t **out_slots =
	    sqc->sqc_query->qr_select_node->sel_out_slots;
	state_slot_t **targets = ins->_.fetch.targets;
	int inx, n_targets = BOX_ELEMENTS (ins->_.fetch.targets);
	int all_targets_remd = 1;

	DO_BOX (state_slot_t *, out_slot, inx, out_slots)
	{
	  if (inx >= n_targets)
	    break;
	  if ((out_slots[inx]->ssl_type == SSL_COLUMN
	       || out_slots[inx]->ssl_type == SSL_VARIABLE))
	    {
	      ssl_alias (out_slot, targets[inx]);
	      targets[inx] = NULL;
	    }
	  else
	    all_targets_remd = 0;
	}
	END_DO_BOX;
	if (all_targets_remd)
	  {
	    dk_free_box ((caddr_t) ins->_.fetch.targets);
	    ins->_.fetch.targets = NULL;
	  }
      }
  }
  END_DO_SET ();
}


void
sqlc_open_stmt (sql_comp_t * sc, ST * stmt)
{
  ST **opts = stmt->_.open_stmt.options;
  subq_compilation_t *sqc = sqlc_subq_compilation_1 (sc, NULL, stmt->_.open_stmt.name, 1);

  stmt->_.open_stmt.options = NULL;
  if (sqc && sqc->sqc_query->qr_cursor_type != _SQL_CURSOR_FORWARD_ONLY)
    {
      ST *cursor_var = t_listst (3, COL_DOTTED, NULL, stmt->_.open_stmt.name);
      state_slot_t **call_params = (state_slot_t **)
	  dk_alloc_box (box_length (sqc->sqc_scroll_params) + sizeof (caddr_t),
	  DV_ARRAY_OF_POINTER);
      call_params[0] = scalar_exp_generate (sc, cursor_var, &sc->sc_routine_code);
      memcpy (&(call_params[1]), sqc->sqc_scroll_params, box_length (sqc->sqc_scroll_params));

      cv_call (&sc->sc_routine_code, NULL, __SCROLL_CR_OPEN, NULL, call_params);
    }
  else
    cv_open (&sc->sc_routine_code, sqc, opts);
}


void
sqlc_fetch_stmt (sql_comp_t * sc, ST * stmt)
{
  subq_compilation_t *sqc = sqlc_subq_compilation_1 (sc, NULL, (caddr_t) stmt->_.fetch.cursor, 1);
  ST **targets = stmt->_.fetch.targets;
  int inx, inx2;
  state_slot_t **ssl_box;
  state_slot_t **src_ssls = sqc->sqc_query->qr_select_node->sel_out_slots;
  int n_slots = sqc->sqc_query->qr_select_node->sel_n_value_slots;
  dk_set_t asg_set = NULL;
  const char *aref_name = (CM_UPPER == case_mode ? "AREF" : "aref");

  if (sqc->sqc_remote_co_table)
    n_slots -= sqc->sqc_remote_co_table->tb_primary_key->key_n_significant;

  if (n_slots != BOX_ELEMENTS (targets))
    sqlc_new_error (sc->sc_cc, "42000", "SQ130",
	"The count of supplied parameters to Virtuoso/PL FETCH "
	"statement does not match the count of selected columns: %d parameters, %d columns", n_slots, BOX_ELEMENTS (targets));
  /**/
  DO_BOX_FAST (ST *, ref, inx, targets)
    {
      char tmp_name[50];
      state_slot_t *tmp_var;
      col_ref_rec_t * tmp_cr;
      int src_is_duped = 0, actual_inx = inx;
      int tgt_is_aref = (ST_P (ref, CALL_STMT) &&
		IS_BOX_POINTER (ref->_.call.name) &&
		DV_TYPE_OF (ref->_.call.name) != DV_ARRAY_OF_POINTER &&
		!CASEMODESTRCMP (ref->_.call.name, aref_name) &&
		IS_BOX_POINTER (ref->_.call.params) && BOX_ELEMENTS (ref->_.call.params) == 2) ;
      ST *var_to_be = (tgt_is_aref ? NULL : sqlo_udt_is_mutator (sc->sc_so, sc, ref));
      _DO_BOX_FAST (inx2, targets)
	{
          if (inx == inx2)
            continue;
	  if (src_ssls[inx]->ssl_index == src_ssls[inx2]->ssl_index)
	    {
	      src_is_duped = 1;
	      if (inx2 < inx)
	        actual_inx = inx2;
	      break;
	    }
        }
      END_DO_BOX_FAST;
      if (tgt_is_aref || (NULL != var_to_be) || (src_is_duped && (actual_inx == inx)))
        {
	  snprintf (tmp_name, sizeof (tmp_name), "__fetch%p_c%d", (void *)stmt, inx);
	  tmp_var = ssl_new_inst_variable (sc->sc_cc, t_sym_string (tmp_name), DV_UNKNOWN);
	  tmp_cr = (col_ref_rec_t *) t_alloc (sizeof (col_ref_rec_t));
          memset (tmp_cr, 0, sizeof (col_ref_rec_t));
	  tmp_cr->crr_col_ref = t_listst (3, COL_DOTTED, NULL, t_sym_string (tmp_name));
	  tmp_cr->crr_ssl = tmp_var;
	  t_set_push (&sc->sc_col_ref_recs, (void *) tmp_cr);
	  targets[inx] = (ST *) t_box_copy_tree ( (caddr_t) tmp_cr->crr_col_ref);
        }
      if (tgt_is_aref)
	t_set_push (&asg_set,
	  t_listst (3, CALL_STMT, t_sqlp_box_id_upcase ("aset"),
	    t_listst (3, ref->_.call.params[0], ref->_.call.params[1],
	      t_box_copy_tree ((caddr_t)(targets[actual_inx])) ) ) );
      else if (NULL != var_to_be)
	t_set_push (&asg_set,
	  sqlo_udt_make_mutator (sc->sc_so, sc, ref,
	    (ST *) t_box_copy_tree ((caddr_t)(targets[actual_inx])), var_to_be));
      else if (src_is_duped)
	t_set_push (&asg_set,
	  t_listst (3, ASG_STMT, ref, (ST *) t_box_copy_tree ((caddr_t)(targets[actual_inx]))) );
    }
  END_DO_BOX_FAST;

  if (sqc && sqc->sqc_query->qr_cursor_type != _SQL_CURSOR_FORWARD_ONLY)
    {
      ST *cursor_var = t_listst (3, COL_DOTTED, NULL, stmt->_.fetch.cursor);
      ssl_box = (state_slot_t **)
	  dk_alloc_box (box_length (targets) + 3 * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
      DO_BOX (ST *, ref, inx, targets)
	{
	  col_ref_rec_t *crr = sqlc_col_ref_rec (sc, ref, 1);
	  ssl_box[inx + 3] = crr->crr_ssl;
	  cv_bop_params (crr->crr_ssl, sqc->sqc_query->qr_select_node->sel_out_slots[inx], "FETCH");
	}
      END_DO_BOX;
      ssl_box[0] = scalar_exp_generate (sc, cursor_var, &sc->sc_routine_code);
      ssl_box[1] = ssl_new_constant (sc->sc_cc, stmt->_.fetch.scroll_type);
      ssl_box[2] = scalar_exp_generate (sc, stmt->_.fetch.row_count, &sc->sc_routine_code);
      cv_call (&sc->sc_routine_code, NULL, __SCROLL_CR_FETCH, NULL, ssl_box);
    }
  else
    {
      if (stmt->_.fetch.scroll_type != (caddr_t) _SQL_FETCH_NEXT)
	sqlc_new_error (sc->sc_cc, "09000", "SQ087",
	    "Forward only cursor called not with FETCH NEXT");
      ssl_box =(state_slot_t **) box_copy ((caddr_t) targets);
      DO_BOX (ST *, ref, inx, targets)
	{
	  col_ref_rec_t *crr = sqlc_col_ref_rec (sc, ref, 1);
	  ssl_box[inx] = crr->crr_ssl;
	}
      END_DO_BOX;
      cv_fetch (&sc->sc_routine_code, sqc, ssl_box);
    }
  asg_set = dk_set_nreverse (asg_set);
  DO_SET (ST *, asg, &asg_set)
    { /* this is a local var, but the asg_set is discarded in it's completeness */
      sqlc_proc_stmt (sc, &asg);
    }
  END_DO_SET();
}


void
sqlc_close_stmt (sql_comp_t * sc, ST * stmt)
{
  subq_compilation_t *sqc = sqlc_subq_compilation_1 (sc, NULL, stmt->_.op.arg_1, 1);
  if (sqc && sqc->sqc_query->qr_cursor_type != _SQL_CURSOR_FORWARD_ONLY)
    {
      ST *cursor_var = t_listst (3, COL_DOTTED, NULL, stmt->_.op.arg_1);
      cv_call (&sc->sc_routine_code, NULL, __SCROLL_CR_CLOSE, NULL,
	  (state_slot_t **)
	    /*list*/ sc_list (1,
	    scalar_exp_generate (sc, cursor_var, &sc->sc_routine_code)));
    }
  cv_close (&sc->sc_routine_code, sqc->sqc_cr_state_ssl);
}


void
sqlc_handler_decl (sql_comp_t * sc, ST * stmt)
{
  long end_label = sqlc_new_label (sc);
  char throw_loc_name[20], nest_name[20];
  state_slot_t *loc, *nest;

  snprintf (throw_loc_name, sizeof (throw_loc_name), "throw_%ld", end_label);
  snprintf (nest_name, sizeof (nest_name), "nest_%ld", end_label);
  loc = sqlc_new_temp (sc, throw_loc_name, DV_LONG_INT);
  nest = sqlc_new_temp (sc, nest_name, DV_LONG_INT);

  cv_handler (&sc->sc_routine_code, stmt->_.handler.sql_states, end_label, loc, nest,
      sc->sc_sqlstate, sc->sc_sqlmessage);
  if (stmt->_.handler.code)
      sqlc_proc_stmt (sc, &(stmt->_.handler.code));
  cv_handler_end (&sc->sc_routine_code, stmt->_.handler.type, loc, nest);
  cv_label (&sc->sc_routine_code, end_label);
}


void
sqlc_compound_stmt (sql_comp_t * sc, ST * tree)
{
  ST **body = tree->_.compound.body;
  int inx, skip;
  dk_set_t compound_recs = NULL;

  t_set_push (&sc->sc_compound_scopes, &compound_recs);
  {
    NEW_INSTR (proc_start, INS_COMPOUND_START, &sc->sc_routine_code);
    proc_start->_.compound_start.line_no = (int) (BOX_ELEMENTS (tree) > 2 ? unbox (tree->_.compound.line_no) : 0);
    proc_start->_.compound_start.l_line_no = (int) (BOX_ELEMENTS (tree) > 3 ? unbox (tree->_.compound.l_line_no) : 0);
    if (parse_pldbg)
      {
	proc_start->_.compound_start.file_name =
	    (BOX_ELEMENTS (tree) > 4 ? box_string (tree->_.compound.file_name) : NULL);
      }
    skip = (int) (BOX_ELEMENTS (tree) > 5 ? 1 : 0);
    proc_start->_.compound_start.skip = skip;
  }

  DO_BOX (ST *, stmt, inx, body)
  {
    switch (stmt->type)
      {
      case LABELED_STMT:
	{
	  if (!id_hash_get (sc->sc_decl_name_to_label, (caddr_t) & stmt->_.op.arg_1))
	    {
	      long label = sc_name_to_label (sc, stmt->_.op.arg_1);
	      id_hash_set (sc->sc_decl_name_to_label, (caddr_t) & stmt->_.op.arg_1, (caddr_t) &label);
	      cv_label (&sc->sc_routine_code, label);
	      sqlc_proc_stmt (sc, (ST **) &(stmt->_.op.arg_2));
	      break;
	    }
	  else
	    sqlc_new_error (sc->sc_cc, "42000", "SQ135", "Duplicate label name %s", stmt->_.op.arg_1);
	}
      default:
	sqlc_proc_stmt (sc, &(body[inx]));
	stmt = body[inx];
      }
  }
  END_DO_BOX;
  {
    NEW_INSTR (proc_start, INS_COMPOUND_END, &sc->sc_routine_code);
    proc_start->_.compound_start.skip = skip;
  }
  t_set_pop (&sc->sc_compound_scopes);
  DO_SET (col_ref_rec_t *, crr, &compound_recs)
    {
      t_set_delete (&sc->sc_col_ref_recs, crr);
    }
  END_DO_SET();
}


void
sqlc_goto_stmt (sql_comp_t * sc, ST * stmt)
{
  jmp_label_t label = sc_name_to_label (sc, stmt->_.op.arg_1);
  cv_jump (&sc->sc_routine_code, label);
}


void
sqlc_if_stmt (sql_comp_t * sc, ST * stmt)
{
  jmp_label_t end_label = sqlc_new_label (sc);
  int inx;
  DO_BOX (ST *, clause, inx, stmt->_.if_stmt.elif_list)
  {
    jmp_label_t then_l = sqlc_new_label (sc);
    jmp_label_t else_l = sqlc_new_label (sc);
    sqlc_mark_pred_deps (sc, NULL, clause->_.elseif.cond);
    pred_gen_1 (sc, clause->_.elseif.cond, &sc->sc_routine_code,
	then_l, else_l, else_l);
    cv_label (&sc->sc_routine_code, then_l);
    sqlc_proc_stmt (sc, &(clause->_.elseif.then));
    cv_jump (&sc->sc_routine_code, end_label);
    cv_label (&sc->sc_routine_code, else_l);
  }
  if (stmt->_.if_stmt.else_clause)
    {
      sqlc_proc_stmt (sc, &(stmt->_.if_stmt.else_clause));
    }
  END_DO_BOX;
  cv_label (&sc->sc_routine_code, end_label);
}


void
sqlc_while_stmt (sql_comp_t * sc, ST * stmt)
{
  jmp_label_t loop = sqlc_new_label (sc);
  jmp_label_t end_label = sqlc_new_label (sc);
  jmp_label_t next_l = sqlc_new_label (sc);

  cv_label (&sc->sc_routine_code, loop);
  sqlc_mark_pred_deps (sc, NULL, stmt->_.while_stmt.cond);
  pred_gen_1 (sc, stmt->_.while_stmt.cond, &sc->sc_routine_code,
      next_l, end_label, end_label);
  cv_label (&sc->sc_routine_code, next_l);
  sqlc_proc_stmt (sc, &(stmt->_.while_stmt.body));
  cv_jump (&sc->sc_routine_code, loop);
  cv_label (&sc->sc_routine_code, end_label);

}


void
sqlc_subq_stmt (sql_comp_t * sc, ST ** pstmt)
{
  /* searched insert/delete/update */
  subq_compilation_t *sqc = sqlc_subquery (sc, NULL, pstmt);
  sqlc_set_ref_params (sqc->sqc_query);
  cv_subq (&sc->sc_routine_code, sqc);
}


void
sqlc_qnode_stmt (sql_comp_t * sc)
{
  cv_qnode (&sc->sc_routine_code, sc->sc_cc->cc_query->qr_head_node);
  sc->sc_cc->cc_query->qr_head_node = NULL;
}


void
sqlc_return_stmt (sql_comp_t * sc, ST * stmt)
{
  state_slot_t *ret = NULL;
  if (stmt->_.op.arg_1)
    {
      sqlc_mark_pred_deps (sc, NULL, (ST *) stmt->_.op.arg_1);
      ret = scalar_exp_generate (sc, (ST *) stmt->_.op.arg_1,
				 &sc->sc_routine_code);
    }
  cv_vret (&sc->sc_routine_code, ret);
}


state_slot_t *
sqlc_asg_stmt (sql_comp_t * sc, ST * stmt, dk_set_t * code)
{
  ST *rtree = (ST *) stmt->_.op.arg_2;
  state_slot_t *left, *right;
  left = scalar_exp_generate (sc, (ST *) stmt->_.op.arg_1, code);
  if (ST_P (rtree, CALL_STMT))
      stmt->_.op.arg_2 = (caddr_t) (rtree = sqlo_udt_check_method_call (sc->sc_so, sc, rtree));
  if (!sc->sc_so)
    sqlc_mark_pred_deps (sc, NULL, stmt->_.bin_exp.right);
  if (ST_P (rtree, CALL_STMT))
    {
      sqlc_call_exp (sc, code, left, (ST *) stmt->_.op.arg_2);
    }
  else if (BIN_EXP_P (rtree))
    {
      state_slot_t * lhs = scalar_exp_generate (sc, rtree->_.bin_exp.left, code);
      state_slot_t * rhs = scalar_exp_generate (sc, rtree->_.bin_exp.right, code);
      state_slot_t *op_left, *op_right;
      /* Generate operands BEFORE op instruction (NEW_INSTR). */
      NEW_INSTR (ins, bop_to_artm_code ((int) rtree->type), code);
      op_left = lhs;
      op_right = rhs;
      ins->_.artm.left = op_left;
      ins->_.artm.right = op_right;
      ins->_.artm.result = left;
      cv_artm_set_type ((instruction_t *)(*code)->data);
    }
  else
    {
      right = scalar_exp_generate (sc, (ST *) stmt->_.op.arg_2, code);
      cv_artm (code, box_identity, left, right, NULL);
    }
  return left;
}

int
sqlc_set_brk (query_t *qr, long line1, int what, caddr_t * inst)
{
  int rc = 0;
  if (!qr && !line1 && inst && *inst)
    {
      instruction_t * instr = (instruction_t *) (*inst);
      if (instr->ins_type == INS_BREAKPOINT)
	{
	  instr->_.breakpoint.brk_set = what;
	  *inst = NULL;
          return instr->_.breakpoint.line_no;
	}
      else
	return 0;
    }
  else if (!qr || !qr->qr_head_node)
    return 0;
  DO_INSTR (instr, 0, qr->qr_head_node->src_pre_code)
    {
	if (instr->ins_type == INS_BREAKPOINT)
	  {
	    if ((line1 > 0 && instr->_.breakpoint.line_no >= line1) || line1 <= 0)
	      {
		if (line1 >= 0)
		  instr->_.breakpoint.brk_set = what;
		else
		  instr->_.breakpoint.brk_set = (instr->_.breakpoint.brk_set & 2) | (what & 1);
/*		fprintf (stderr, "Set Brkp %p at (%ld)\n", instr, instr->_.breakpoint.line_no);*/
		rc++;
		if (line1 >= 0)
		  {
		    rc = instr->_.breakpoint.line_no;
		    if (inst)
		      *inst = (caddr_t) instr;
		    break;
		  }
	      }
	  }
    }
  END_DO_INSTR;
  return rc;
}


void
sqlc_proc_cost (sql_comp_t * sc, ST * stmt)
{
  query_t * qr = sc->sc_cc->cc_query;
  caddr_t * numbers = (caddr_t*) stmt->_.op.arg_1;
  int n_nums = BOX_ELEMENTS (numbers);
  float * floats = (float*) dk_alloc_box_zero (sizeof (float) * (n_nums < 2 ? 2 : n_nums), DV_ARRAY_OF_FLOAT);
  int inx;
  DO_BOX (caddr_t, n, inx, numbers)
    {
      floats[inx] = unbox_float (n);
    }
  END_DO_BOX;
  qr->qr_proc_cost = floats;
}

void
sqlc_proc_stmt (sql_comp_t * sc, ST ** pstmt)
{
  ST *stmt = *pstmt;
  subq_compilation_t *cursor_sqc;

  switch (stmt->type)
    {

    case VARIABLE_DECL:
      sqlc_decl_variable_list (sc, (ST **) stmt->_.op.arg_1, 0);
      break;

    case CURSOR_DEF:
      sqlc_cursor_def (sc, stmt);
      break;

    case HANDLER_DECL:
      sqlc_handler_decl (sc, stmt);
      break;

    case COMPOUND_STMT:
      sqlc_compound_stmt (sc, stmt);
      break;

    case GOTO_STMT:
      sqlc_goto_stmt (sc, stmt);
      break;

    case IF_STMT:
      sqlc_if_stmt (sc, stmt);
      break;

    case WHILE_STMT:
      sqlc_while_stmt (sc, stmt);
      break;

    case OPEN_STMT:
      sqlc_open_stmt (sc, stmt);
      break;

    case FETCH_STMT:
      sqlc_fetch_stmt (sc, stmt);
      break;

    case CALL_STMT:
      stmt = sqlo_udt_check_method_call (sc->sc_so, sc, stmt);
      sqlc_mark_pred_deps (sc, NULL, stmt);
      sqlc_call_exp (sc, &sc->sc_routine_code, NULL, stmt);
      break;

    case RETURN_STMT:
      if (sc->sc_is_trigger_decl && stmt->_.op.arg_1)
	sqlc_new_error (sc->sc_cc, "37000", "SR321",
	    "A RETURN statement with a return status can only be used in a stored procedure");
      sqlc_return_stmt (sc, stmt);
      break;

    case CLOSE_STMT:
      sqlc_close_stmt (sc, stmt);
      break;

    case INSERT_STMT:
      if (ST_P (stmt->_.insert.vals, SELECT_STMT))
	{
	  sqlc_subq_stmt (sc, pstmt);
	  stmt = *pstmt;
	}
      else
	{
	  sqlc_insert (sc, stmt);
	  sqlc_qnode_stmt (sc);
	}
      break;

    case UPDATE_POS:
      cursor_sqc = sqlc_subq_compilation (sc, NULL, stmt->_.update_pos.cursor);
      cursor_sqc->sqc_is_current_of = 1;
      sqlc_update_pos (sc, stmt, cursor_sqc);
      sqlc_qnode_stmt (sc);
      break;

    case DELETE_POS:
      cursor_sqc = sqlc_subq_compilation (sc, NULL, stmt->_.delete_pos.cursor);
      cursor_sqc->sqc_is_current_of = 1;
      sqlc_delete_pos (sc, stmt, cursor_sqc);
      sqlc_qnode_stmt (sc);
      break;

    case UPDATE_SRC:
    case DELETE_SRC:
      sqlc_subq_stmt (sc, pstmt);
      stmt = *pstmt;
      break;

    case ASG_STMT:
	{
	  ST *new_stmt = sqlo_udt_check_mutator (sc->sc_so, sc, stmt);
	  if (new_stmt != stmt)
	    {
	      *pstmt = new_stmt;
	      stmt = new_stmt;
	      sqlc_proc_stmt (sc, pstmt);
	    }
	  else
	    sqlc_asg_stmt (sc, stmt, &sc->sc_routine_code);
	}
      break;

    case NULL_STMT:
      break;

#ifdef PLDBG
    case BREAKPOINT_STMT:
      if (sc->sc_cc->cc_query->qr_brk)
	{
	  NEW_INSTR (breakpoint, INS_BREAKPOINT, &sc->sc_routine_code);
	  breakpoint->_.breakpoint.line_no = (short) unbox(stmt->_.op.arg_1);
	  DO_SET (col_ref_rec_t *, elm,  &sc->sc_col_ref_recs)
	    {
	      dk_set_push (&(breakpoint->_.breakpoint.scope), (void *)(elm->crr_ssl));
	    }
	  END_DO_SET();
	}
      break;
#endif

    case PROC_COST:
      sqlc_proc_cost (sc, stmt);
      break;
    default:
      sqlc_new_error (sc->sc_cc, "39000", "SQ088", "Statement not supported in a procedure context.");
    }
}

id_hash_t * ua_func_to_ua;

query_t *
sch_ua_func_ua (caddr_t name)
{
  query_t ** place;
  if (!ua_func_to_ua)
    return NULL;
  place = (query_t**)id_hash_get (ua_func_to_ua, (caddr_t)&name);
  return place ? *place : NULL;
}


void
sch_set_ua_func_ua (caddr_t name, query_t * qr)
{
  if (!ua_func_to_ua)
    ua_func_to_ua = id_casemode_hash_create (23);
  name = box_copy (name);
  id_hash_set (ua_func_to_ua, (caddr_t)&name, (caddr_t)&qr);
}


bif_t
bif_ua_find (caddr_t name)
{
  bif_t bif = bif_find (name);
  if (bif)
    bif_set_is_aggregate (bif);
  return bif;
}


void
sqlc_user_aggregate_decl (sql_comp_t * sc, ST * tree)
{
  int o_sc_trig_decl = 0;
  ST *stub;
  user_aggregate_t *aggr;
  sc->sc_cc->cc_query->qr_proc_name = box_string (tree->_.user_aggregate.name);
  sc->sc_cc->cc_query->qr_proc_ret_type = NULL;
  sc->sc_cc->cc_query->qr_proc_alt_ret_type = NULL;
  sc->sc_cc->cc_query->qr_proc_place = 0;
  sc->sc_name_to_label = id_str_hash_create (4);
  sc->sc_decl_name_to_label = id_str_hash_create (4);
  sqlc_decl_variable_list (sc, tree->_.user_aggregate.params, 1);
  o_sc_trig_decl = sc->sc_is_trigger_decl; /* save old value and go */
  sc->sc_is_trigger_decl = 0;
  stub = t_listst (5, COMPOUND_STMT,
    t_list (1,
      t_list (3, CALL_STMT, t_sqlp_box_id_upcase ("signal"),
	t_list (2, t_box_string ("42000"),
	  t_box_string ("User-defined aggregate is called as a plain function") ) ) ),
    t_box_num (1),
    t_box_num (1),
    NULL
      );
  sqlc_proc_stmt (sc, &stub);
  sc->sc_is_trigger_decl = o_sc_trig_decl;
  sqlc_routine_qr (sc);
  sqlc_remove_unrefd_current_ofs (sc);
  sqlc_opt_fetches (sc);
  sc->sc_cc->cc_query->qr_aggregate = aggr = (user_aggregate_t *) dk_alloc (sizeof (user_aggregate_t));
  aggr->ua_name = box_copy (tree->_.user_aggregate.name);
  aggr->ua_init.uaf_name = box_copy (tree->_.user_aggregate.init_name);
  aggr->ua_acc.uaf_name = box_copy (tree->_.user_aggregate.acc_name);
  sch_set_ua_func_ua (aggr->ua_acc.uaf_name, sc->sc_cc->cc_query);
  aggr->ua_final.uaf_name = box_copy (tree->_.user_aggregate.final_name);
  aggr->ua_merge.uaf_name = box_copy (tree->_.user_aggregate.merge_name);
  aggr->ua_init.uaf_bif = box_num ((ptrlong) bif_ua_find (aggr->ua_init.uaf_name));
  aggr->ua_acc.uaf_bif = box_num ((ptrlong) bif_find (aggr->ua_acc.uaf_name));
  aggr->ua_final.uaf_bif = box_num ((ptrlong) bif_find (aggr->ua_final.uaf_name));
  if (aggr->ua_merge.uaf_name)
    aggr->ua_merge.uaf_bif = box_num ((ptrlong) bif_find (aggr->ua_merge.uaf_name));
  else
    aggr->ua_merge.uaf_bif = NULL;
  aggr->ua_need_order = tree->_.user_aggregate.need_order;
}


void
sqlc_routine_decl (sql_comp_t * sc, ST * tree)

{
  int o_sc_trig_decl = 0;
  caddr_t *alt_type = (caddr_t *) tree->_.routine.alt_ret;
  sc->sc_cc->cc_query->qr_proc_name = box_string (tree->_.routine.name);
  sc->sc_cc->cc_query->qr_proc_ret_type =
      box_copy_tree ((caddr_t) tree->_.routine.ret);
  sc->sc_cc->cc_query->qr_proc_alt_ret_type = alt_type ? box_copy(alt_type[0]): NULL;
  sc->sc_cc->cc_query->qr_proc_place = alt_type ? ((long) (ptrlong) alt_type[1]) : 0;
  sc->sc_cc->cc_query->qr_proc_soap_opts = alt_type ? (caddr_t *) box_copy_tree (alt_type[2]) : NULL;
                                              /*an alternative return type and SOAP options */
  if (BOX_ELEMENTS (tree) > 7)
    { /* UDT method */
      sc->sc_cc->cc_query->qr_udt_mtd_info = (caddr_t *) box_copy_tree ((box_t) tree->_.routine.udt_mtd_info);
    }

  sc->sc_name_to_label = id_str_hash_create (4);
  sc->sc_decl_name_to_label = id_str_hash_create (4);
  sqlc_decl_variable_list (sc, tree->_.routine.params, 1);
  o_sc_trig_decl = sc->sc_is_trigger_decl; /* save old value and go */
  sc->sc_is_trigger_decl = 0;
  sqlc_proc_stmt (sc, &(tree->_.routine.body));
  sc->sc_is_trigger_decl = o_sc_trig_decl;
  sqlc_routine_qr (sc);
  sqlc_remove_unrefd_current_ofs (sc);
  sqlc_opt_fetches (sc);
}


void
sqlc_module_decl (sql_comp_t * sc, ST * tree)
{
  int inx;
  dk_set_t qr_set = NULL;
  caddr_t err = NULL;

  sc->sc_cc->cc_query->qr_proc_name = box_string (tree->_.module.name);
  sc->sc_cc->cc_query->qr_module = (query_t *) 1;

  if (sch_module_def (sc->sc_cc->cc_schema, tree->_.module.name))
    {
      err = srv_make_new_error ("37000", "SQ140",
	  "Module declaration tries to overwrite a module"
	  " with the same name. Drop the module %s first", tree->_.module.name);
      goto error;
    }

  DO_BOX (ST *, sc_proc, inx, tree->_.module.procs)
    {
      query_t *qr;
      caddr_t old_name = sc_proc->_.routine.name;
      char buff[4*MAX_NAME_LEN + 4];

      snprintf (buff, sizeof (buff), "%s.%s", tree->_.module.name, old_name);
      sc_proc->_.routine.name = t_alloc_box (strlen (buff) + 1, DV_TYPE_OF (old_name));
      strcpy_box_ck (sc_proc->_.routine.name, buff);

      qr = sql_compile_st (&(tree->_.module.procs[inx]), sc->sc_client, &err, sc);
      sc_proc = tree->_.module.procs[inx];
      if (err)
	goto error;
      qr->qr_module = sc->sc_cc->cc_query;
      if (sc->sc_client->cli_user)
	qr->qr_proc_owner = sc->sc_client->cli_user->usr_id;
#if 0
      /* no longer needed as top condition for module must handle such situation */
      if (sch_proc_def (sc->sc_cc->cc_schema, qr->qr_proc_name))
	{
	    err = srv_make_new_error ("37000", "SQ140",
		"Module procedure declaration tries to overwrite a procedure"
		" with the same name. Drop the procedure %s (or the module containing it) first.",
		qr->qr_proc_name);
	    goto error;
	}
#endif
#ifdef PLDBG
      if (sc->sc_cc->cc_query->qr_brk)
	{ /* source & line are from qr_module */
	  qr->qr_line_counts = hash_table_allocate (100);
	  qr->qr_call_counts = id_str_hash_create (101);
	  qr->qr_stats_mtx = mutex_allocate ();
	}
#endif

      sch_set_proc_def (sc->sc_cc->cc_schema, qr->qr_proc_name, qr);
      t_set_push (&qr_set, qr);
    }
  END_DO_BOX;
  return;

error:
  DO_SET (query_t *, qr, &qr_set)
    {
      sch_set_proc_def (sc->sc_cc->cc_schema, qr->qr_proc_name, NULL);
    }
  END_DO_SET();
  sqlc_resignal_1 (sc->sc_cc, err);
}


state_slot_t *
sqlc_trig_param (sql_comp_t * sc, char *prefix, char *name)
{
  state_slot_t *ssl;
  char tmp[300];
  ST *ref = (ST *) t_list (3, COL_DOTTED, prefix ? t_box_string (prefix) : NULL, t_box_string (name));
  t_NEW_VARZ (col_ref_rec_t, crr);
  if (prefix)
    snprintf (tmp, sizeof (tmp), "%s.%s", prefix, name);
  else
    snprintf (tmp, sizeof (tmp), "%s", name);
  ssl = ssl_new_parameter (sc->sc_cc, tmp);
  ssl->ssl_type = SSL_REF_PARAMETER;
  crr->crr_ssl = ssl;
  crr->crr_col_ref = ref;
  t_set_push (&sc->sc_col_ref_recs, (void *) crr);
  return ssl;
}


dk_set_t
sqlc_trig_params (sql_comp_t * sc, ST * tree, dbe_table_t * tb)
{
  query_t *qr = sc->sc_cc->cc_query;
  dbe_key_t *key = tb->tb_primary_key;
  int inx;
  caddr_t n_prefix = NULL, o_prefix = NULL;
  /* int n_cols = dk_set_length (tb->tb_primary_key->key_parts); */
  if (tree->_.trigger.old_alias)
    {
      DO_BOX (ST *, alias, inx, tree->_.trigger.old_alias)
	{
	  switch (alias->type)
	    {
	    case OLD_ALIAS:
	      if (qr->qr_trig_event == TRIG_INSERT)
		sqlc_new_error (sc->sc_cc, "S0022", "SQ151",
		  "Invalid alias declaration: insert trigger cannot reference old values.");
	      o_prefix = alias->_.op.arg_1;
	      break;
	    case NEW_ALIAS:
	      if (qr->qr_trig_event == TRIG_DELETE)
		sqlc_new_error (sc->sc_cc, "S0022", "SQ152",
		  "Invalid alias declaration: delete trigger cannot reference new values.");
	      n_prefix = alias->_.op.arg_1;
	      break;
	    default:
	      SQL_GPF_T (sc->sc_cc);
	    }
	}
      END_DO_BOX;
    }
  else
    {
      if (qr->qr_trig_event == TRIG_UPDATE)
	{
	  if (tree->_.trigger.time != TRIG_AFTER)
	    n_prefix = box_string ("N");
	  else
	    o_prefix = box_string ("O");
	}
    }
  if ((NULL != n_prefix) && (NULL != o_prefix) && !CASEMODESTRCMP(n_prefix, o_prefix))
    sqlc_new_error (sc->sc_cc, "S0022", "SQ149",
      "An alias %s is used in both 'referencing old as' and 'referencing new as' declarations.", n_prefix);
  if (qr->qr_trig_event != TRIG_INSERT)
    {
      DO_SET (dbe_column_t *, col, &key->key_parts)
	{
	  sqlc_trig_param (sc, o_prefix, col->col_name);
	}
      END_DO_SET ();
    }
  if (qr->qr_trig_event != TRIG_DELETE)
    {
      DO_SET (dbe_column_t *, col, &key->key_parts)
      {
	sqlc_trig_param (sc, n_prefix, col->col_name);
      }
      END_DO_SET ();
    }
  return NULL;
}


void
sqlc_trigger_scope (sql_comp_t * sc, ST * tree)
{
  query_t *qr = sc->sc_cc->cc_query;

  sqlc_trig_params (sc, tree, qr->qr_trig_dbe_table);
}


ST ** box_add_prime_keys (ST ** selection, dbe_table_t * tb);


void
sqlc_qr_trig_event (sql_comp_t * sc, query_t * qr, ST * tree)
{
  int inx;
  caddr_t *event = tree->_.trigger.event;
  if (IS_BOX_POINTER (event))
    {
      qr->qr_trig_event = TRIG_UPDATE;
      if (0 != BOX_ELEMENTS (event))
	{
	  qr->qr_trig_upd_cols = (oid_t *) dk_alloc_box (
	      sizeof (oid_t) * BOX_ELEMENTS (event), DV_ARRAY_OF_LONG);
	  DO_BOX (caddr_t, cname, inx, event)
	  {
	    dbe_column_t *col = tb_name_to_column (qr->qr_trig_dbe_table, cname);
	    if (!col)
	      sqlc_new_error (sc->sc_cc, "S0022", "SQ089",
		  "Bad column %s  in trigger column list", cname);
	    qr->qr_trig_upd_cols[inx] = col->col_id;
	  }
	  END_DO_BOX;
	}
    }
  else
    qr->qr_trig_event = (char) (ptrlong) event;
}


void
sqlc_trigger_decl (sql_comp_t * sc, ST * tree)
{
  int has_similar, o_sc_trig_decl = 0;
  query_t *qr = sc->sc_cc->cc_query;
  user_t * usr = sc->sc_client->cli_user;
  dbe_table_t *tb = sch_name_to_table (sc->sc_cc->cc_schema,
      tree->_.trigger.table);
  if (!tb)
    sqlc_new_error (sc->sc_cc, "42S02", "SQ090", "Bad table %s in trigger %s definition",
	tree->_.trigger.table, tree->_.trigger.name);
  if (usr && !sec_tb_check (tb, usr->usr_id, usr->usr_id, GR_SELECT)) /*XXX: let check is the all columns granted to the creator */
    sqlc_new_error (sc->sc_cc, "42000", "SQ092", "Access denied for table %s", tb->tb_name);
  qr->qr_trig_dbe_table = tb;
  qr->qr_proc_name = box_string (tree->_.trigger.name);
  qr->qr_trig_time = (char) tree->_.trigger.time;

  sqlc_qr_trig_event (sc, qr, tree);
  if (sch_view_def (sc->sc_cc->cc_schema, tb->tb_name))
    {
      if (((char) tree->_.trigger.time) != TRIG_INSTEAD &&
       !tb_is_trig_at (tb, qr->qr_trig_event, TRIG_INSTEAD, NULL))
	  sqlc_new_error (sc->sc_cc, "42000", "SQ091",
	      "In order to have triggers, a view %s must first have an INSTEAD OF trigger.",
	      tb->tb_name);
    }
  qr->qr_trig_order = (int) unbox (tree->_.trigger.order);

  sc->sc_name_to_label = id_str_hash_create (4);
  sc->sc_decl_name_to_label = id_str_hash_create (4);
  sqlc_trigger_scope (sc, tree);
  qr->qr_trig_table = box_string (qr->qr_trig_dbe_table->tb_name);

  sqlc_decl_variable_list_const (sc, &sc->sc_col_ref_recs);

  has_similar = tb_has_similar_trigger (tb, qr);
  trig_set_def (qr->qr_trig_dbe_table, qr);
  o_sc_trig_decl = sc->sc_is_trigger_decl; /* save old value and go */
  sc->sc_is_trigger_decl = 1;
  sqlc_proc_stmt (sc, &(tree->_.trigger.body));
  sc->sc_is_trigger_decl = o_sc_trig_decl;
  sqlc_routine_qr (sc);

  sqlc_table_used (sc, qr->qr_trig_dbe_table);
  if (!has_similar)
    tb_mark_affected (qr->qr_trig_dbe_table->tb_name);
  qr->qr_to_recompile = 0;
  qr->qr_parse_tree_to_reparse = 0;

  if (DO_LOG(LOG_DDL))
    {
      log_info ("DDLC_8 %s Create trigger %.*s (%.*s)", GET_USER,
	  LOG_PRINT_STR_L, tree->_.trigger.name, LOG_PRINT_STR_L, tree->_.trigger.table);
    }
}

